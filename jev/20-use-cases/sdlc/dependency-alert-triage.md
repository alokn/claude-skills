---
id: uc-sdlc-dependency-alert-triage
title: Triage dependency and security alerts as advisory, never as an auto-dismiss gate
verdict: conditional
domain: sdlc
decision_shapes: [classification, scoring, routing]
primitives: [choice, noul, score]
evidence_level: inferred
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (Risk assessment: "Score severity and prioritize review"; LLM guardrails)
  - https://docs.typesafe.ai/patterns/composite-scoring.md  (atomic scores, weights owned by code)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 2 numbers; mode 3 dates; mode 6 adversarial content)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free)
  - https://github.com/genfeedai/genfeed.ai/issues/4863  ("THE SYSTEM SHALL keep every existing deterministic security gate authoritative; a typed decision may only tighten (e.g. force review), never loosen, an approval outcome")
related: [uc-sdlc-api-error-log-triage, uc-sdlc-pr-risk-tier-review-routing, uc-agents-harness-pre-tool-use-destructiveness, df-fit-test, df-rollout]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to triage Dependabot and CodeQL alerts?" Also: "can a model tell
which CVEs actually affect us?", "can we auto-dismiss the test-only findings?", "our security
backlog is 400 alerts nobody reads".

## Verdict

**Conditional**, and the condition is absolute: **jev may raise priority, never dismiss an
alert**. Ordering a backlog is a judgement and a good fit; deciding that a vulnerability does
not apply is a security invariant, and the fit test's counter-signal list puts safety
invariants outside the model's remit. A public PRD for a jev integration states the same rule
as a requirement: a typed decision "may only tighten (e.g. force review), never loosen, an
approval outcome". This entry is `inferred` — no cookbook or measurement covers alert triage.
**Advisory first, gate later**, where "later" means a higher-priority label, not an
auto-close.

## What jev decides

Reachability is the question everyone wants answered and the one jev must not answer alone:
it is a multi-hop property of the call graph (failure mode 4), and static analysis computes
it properly. What jev can judge is the *description* against the *usage you show it*.

State, assembled in code: `{advisory: {summary, affected_functions, attack_vector}, our_usage:
{import_sites: [<file:line with 3 lines of context>], package_role: "runtime|build|test"}}`.

```
usage_matches_advisory: Noul
  instructions: {question: "Do the import sites in `our_usage` use the functionality
                            `advisory.affected_functions` describes?",
                 compare: ["`advisory.affected_functions`", "`our_usage.import_sites`"]}
  criteria:
    true:  {what: "At least one import site calls or configures the affected functionality"}
    false: {what: "The package is imported but the affected functionality is not used here",
            not_for: "Uncertainty about transitive callers — answer only about what is shown"}

exposure_path: Choice
  criteria:
    untrusted_input: {what: "The advisory's attack vector requires attacker-controlled input,
                             and the shown usage handles input from outside the system"}
    local_only:      {what: "Exploitation requires local access or developer-machine execution"}
    build_time_only: {what: "The affected code runs only during build or test, never in production"}
    unclear:         {what: "The evidence shown does not settle which path applies"}

advisory_severity_claim: Score
  criteria: ["Denial of service or information disclosure only.",
             "Privilege escalation within the application.",
             "Remote code execution or authentication bypass."]
```

Bands: any `exposure_path == untrusted_input` at `confidence >= 0.6` → raise to the top of the
queue. `unclear`, or any confidence below 0.6 → leave the alert exactly where the
deterministic policy put it. There is no band that closes anything.

## What stays in code

Version-range matching — "is 4.17.20 inside `< 4.17.21`" is semver arithmetic, and both
numeric comparison (failure mode 2) and date/window comparison (failure mode 3) are documented
weaknesses. The CVSS score, the EPSS percentile, the patch availability, whether a fix exists,
the SLA clock, the dependency graph and reachability analysis, and the dismissal action
itself. The advisory text is third-party content in your state; failure mode 6 says state is
not treated as hostile by default, so an advisory that argues for its own dismissal must not
be able to move a gate — which is another reason the gate is not here.

## Numbers

Method: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. An advisory
summary (~1,200 characters) plus six import sites with context (~1,800 characters) plus three
questions with criteria (~1,900 characters) is about 1,230 tokens, **≈ $0.000052 per alert**.
A 400-alert backlog re-scored in full is **≈ $0.021**, which makes re-running the whole queue
after every dependency change affordable. Latency is irrelevant here; this is a batch job.
Accuracy: not published, and no public evaluation of jev on vulnerability triage exists.
Labelled data for calibration: your own closed alerts and their dismissal reasons
(`not-used`, `no-bandwidth`, `fixed`), plus any alert that later became an incident — the last
group is small and is the only class where a false negative costs anything.

- Field evidence (community-report): an adversarial-review pipeline wires jev priors into security-finding triage as display-only - "Jev output cannot dismiss findings" - with 428 tests passing on Linux; the design is the point, not an accuracy number, 2026-09. Source: https://github.com/SathiaAI/adversarial-review/pull/69

## When the verdict flips

- To **no**, the moment an answer auto-dismisses or auto-closes. That is the sole-safety-gate
  counter-signal.
- To **weak**, if your SCA tool already does reachability analysis well for your language.
  Then the ordering it produces is better grounded than a text judgement.
- If you feed it the raw advisory with no usage context. The question becomes "is this CVE
  scary", which the CVSS score already answers deterministically and better.
- Ecosystems where "affected functions" are not stated in advisories; there is then nothing
  to compare the usage against.

## Alternatives considered

- **CVSS / EPSS ordering.** Free, standard, deterministic; it knows nothing about whether you
  use the affected call. Keep it as the base order and let jev perturb it upward.
- **Reachability analysis (SCA with call-graph support).** The correct tool for the core
  question. Where it exists for your language, it wins outright.
- **Frontier LLM.** Reads the advisory and the code properly and can follow one hop of the call
  graph; seconds and cents per alert, which is fine at 400 alerts and not at 40,000. Escalate
  jev's `untrusted_input` band to it.
- **Small LLM.** Comparable judgement, higher latency. On a security queue a confident wrong
  "not affected" is the worst possible output, so set an explicit below-threshold route on
  whichever model you use — logprobs are enough to build one; in one 149-row public run the
  two differed only in how often they fell below the threshold (34.7% against 2.7%).
- **Fine-tuned classifier.** Your dismissal history is biased by bandwidth, not by truth, so
  the labels are poor training data.
- **Embeddings.** No.
- **Security engineer triage.** Stays, and stays the authority. The goal is to put the right
  alert in front of them first.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md`, `patterns/composite-scoring.md`,
`model-jaggedness/jev-1.13.md` (modes 2, 3, 4, 6), `models.md`. Field report:
https://github.com/genfeedai/genfeed.ai/issues/4863 (deterministic security gates stay
authoritative; tighten never loosen; shadow mode with a labelled offline set before going
live).
