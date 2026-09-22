---
id: uc-trust-safety-security-alert-triage-pipeline
title: Enrich and prioritise a SOC alert queue in stages, without ever closing an alert
verdict: conditional
domain: trust-safety
decision_shapes: [classification, scoring, routing, detection]
primitives: [choice, score, noul]
evidence_level: community-report
sources:
  - https://github.com/kenhuangus/jev-usecases  (7 SOC stages implemented; author warns thresholds are not production-ready and "a wrong but valid label is still possible")
  - https://github.com/SathiaAI/adversarial-review/pull/69  (jev priors are display-only; "Jev output cannot dismiss findings"; 428 tests pass on Linux)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 6 adversarial content can move the answer)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free)
related: [uc-observability-evals-alert-worthiness-gating, uc-sdlc-dependency-alert-triage, uc-financial-crime-alert-prioritisation-by-evidence-quality, uc-risk-forecasting-incident-report-risk-indicators, au-sole-security-gate, au-payments-and-access-control-decision]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev in our SOC triage pipeline?" Also: "can jev tell a true positive
from a false positive in our SIEM queue?", "can we auto-close the noisy detections?", "which
stages of incident response can a typed model take?"

## Verdict

**Conditional**, and the condition is hard: **jev may order and enrich the queue; it may never
close, dismiss, or downgrade an alert.** A public catalogue implements seven SOC stages with
jev and its own author is explicit that the thresholds are **"not production-ready"** and that
**"a wrong but valid label is still possible"** (github.com/kenhuangus/jev-usecases). A second
project designed to the same constraint from the start and states it as a rule: the jev priors
are display-only and **"Jev output cannot dismiss findings"**
(github.com/SathiaAI/adversarial-review/pull/69). Build it that way and the shape is sound —
a bounded label set over text you already collect, a reversible action, and a human at the
end. Build it as a filter and it becomes `au-sole-security-gate`.

## What jev decides

Per alert, one call, on a state assembled in code: `detection_rule_name`,
`alert_description`, `asset_role` (from your CMDB), `observed_indicators` as a short list of
strings, and `analyst_notes` if any. Not the raw packet capture, not the full log — mode 5.

```
alert_category: Choice
  criteria:
    credential_access: {what: "Authentication abuse: brute force, token theft, MFA fatigue."}
    lateral_movement:  {what: "Movement between hosts or accounts after an initial foothold."}
    data_movement:     {what: "Unusual volume or destination for data leaving a system."}
    malware_execution: {what: "Code executed that the endpoint tooling names as malicious."}
    policy_noise:      {what: "A control firing on sanctioned activity: a scanner, a backup,
                               an admin doing their job."}
    unclear:           {what: "The description does not say enough to categorise. Use this
                               rather than guessing."}

business_impact_if_real: Score
  criteria: ["Single low-value asset.", "A team's workflow.",
             "Customer data or a production system.", "Whole-estate or regulatory."]

evidence_quality: Score
  instructions: {question: "How much of the evidence an analyst would need is already here?",
                 focus: "Judge completeness of the write-up, not whether the alert is true."}

names_a_sanctioned_process: Noul
  instructions: "Does `alert_description` name a process, scanner or account that
                 `known_sanctioned_tools` lists?"
```

`unclear` is load-bearing: without it the Choice is relative and will label a half-written
alert. Bands drive **order and enrichment only** — high impact plus high confidence sorts to
the top of the analyst queue; `policy_noise` at high confidence sorts to the bottom *and stays
in the queue*.

Closest jaggedness mode: **6, adversarial content can move the answer.** An attacker can write
the strings your detection quotes. Because no alert is ever closed on the label, the worst
case is a bad sort order rather than a missed intrusion.

## What stays in code

The detection rules themselves, correlation, deduplication, asset criticality lookups,
enrichment from threat intel, the SLA clock, the escalation policy, the ticket write, and the
audit trail. Every suppression rule you already trust stays deterministic and authoritative.
And the closure: only an analyst closes an alert, and the record stores the jev label and its
probability as *context shown to that analyst*, never as a state transition.

## Numbers

None published for accuracy on this task by anyone. The catalogue publishes an implementation
across seven stages and a warning, not a benchmark
(github.com/kenhuangus/jev-usecases). The adversarial-review PR publishes a design constraint
and a test count — "428 tests pass on Linux" — which is a statement about the integration, not
about label quality (github.com/SathiaAI/adversarial-review/pull/69).

Cost method: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. An
assembled alert of ~1,500 characters plus four questions with criteria (~2,600 characters) is
about 1,025 tokens, **≈ $0.000043 per alert**. Multiply by your own alert volume — this entry
supplies no volume. At any plausible triage volume the cost is not the objection here. The
objection is the miss.

Labelled data arrives free from the analysts' own dispositions. Fit thresholds per the
calibration workflow before you let the label change *anything* beyond sort order, and treat
"alerts an analyst escalated that jev sorted to the bottom" as the metric that matters.

## When the verdict flips

- **jev closes or downgrades an alert.** Verdict becomes **no**. Both public sources say this
  in their own words.
- **It is the only detection layer.** jev reads the alert your rules produced; it cannot
  detect what nothing fired on.
- **Regulatory reporting depends on the label.** A wrong-but-valid category on a reportable
  incident is a compliance failure with no audit trail to explain it; see
  `au-legal-determinations-without-counsel` for the shape of that argument.
- **The alert body is mostly structured fields.** Then the routing is a lookup table and jev
  is a network call in the way.
- **You cannot show the analyst the probability.** If the UI hides it, the analyst cannot
  discount it, and a display-only prior becomes a silent gate.

## Alternatives considered

- **SIEM correlation rules and risk scores.** The incumbent, exact, and the reason the queue
  exists. They cannot read the free-text half of an alert.
- **Deterministic suppression lists.** Right answer for known-sanctioned scanners. Keep them;
  they run before the call.
- **Frontier LLM.** Can write the incident summary and explain the reasoning, which jev cannot
  and which SOC work genuinely needs. Slower and far more expensive per alert, but the volume
  after jev's sort is small enough to afford.
- **Fine-tuned classifier on your disposition history.** Strong candidate; SOCs have years of
  labelled dispositions, which is more than most teams can say.
- **Analyst triage rota.** Stays. This design changes the order they work in, not who decides.

## Sources

- https://github.com/kenhuangus/jev-usecases — accessed 2026-09-19 (7 SOC stages; thresholds
  "not production-ready"; "a wrong but valid label is still possible")
- https://github.com/SathiaAI/adversarial-review/pull/69 — accessed 2026-09-19 (display-only
  priors; "Jev output cannot dismiss findings"; 428 tests pass on Linux)
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
