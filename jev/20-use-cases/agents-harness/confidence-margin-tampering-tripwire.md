---
id: uc-agents-harness-confidence-margin-tampering-tripwire
title: Alarm when the margin between jev's top two options collapses on an input that is normally decisive
verdict: conditional
domain: agents-harness
decision_shapes: [detection, verification, scoring]
primitives: [choice, noul]
evidence_level: community-report
sources:
  - https://github.com/bestdan/workflow-skills/pull/757  ("Injection attacks via plausible authority claims collapsed margins from 1.000 to 0.05-0.24"; confidence "useless as correctness gate" but "sharply responsive to injected pressure"; confidence swing 0.16-0.48 between runs)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 6: adversarial content "can move the answer")
  - https://github.com/leepokai/jev-guard  ("Not a sandbox ... Jev can be wrong"; 662 skills scanned, highest legitimate score 0.74)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free)
related: [uc-agents-harness-prompt-injection-semantic-flag, uc-agents-harness-pre-tool-use-destructiveness, uc-observability-evals-confidence-threshold-calibration-fitting, uc-agents-harness-agent-trace-classification, au-zero-hallucination-means-always-right, au-sole-security-gate]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev's confidence to detect prompt injection?" Also: "can a drop in
confidence tell us someone is tampering with our inputs?", "our injection classifier misses
novel attacks — is there a model-agnostic signal?", "what is confidence actually good for if
it is not correctness?"

## Verdict

**Conditional — and only for the inverted reading of confidence.** The finding this rests on
is unusual and worth stating in full. A public assessment tried jev's confidence as a
correctness gate and rejected it outright: **"useless as correctness gate."** The same
assessment then found that confidence was **"sharply responsive to injected pressure"** —
**"Injection attacks via plausible authority claims collapsed margins from 1.000 to
0.05-0.24"** (github.com/bestdan/workflow-skills/pull/757).

So the signal is real, but it points at the wrong axis for most people's intent. A collapsed
margin does not mean the answer is wrong; it means *something in this input is arguing with
the criteria*. That is a tampering tripwire, not a verifier.

Three conditions make it conditional rather than good. First, you need a per-question baseline
distribution of margins on known-clean traffic before a collapse means anything — the effect is
"1.000 to 0.05" only on a question that is normally decisive. Second, the same source measured
confidence swinging **0.16-0.48 between runs on the same item**, so one low margin is noise;
alarm on repeated or aggregate collapse, not a single call. Third, it detects pressure, not
correctness, and never belongs on the blocking path alone.

## What jev decides

Nothing is added to the schema. You are instrumenting a question you already ask — preferably a
question about the task, not about safety, because an attacker tuning against your injection
detector is not tuning against your routing classifier.

```
# the production question, unchanged
action: Choice
  instructions: {question: "Which action does this request ask for?", focus: "..."}
  criteria: {...}
```

The tripwire is arithmetic over the returned distribution, and it lives in code:

```
p = sorted(action.probabilities, reverse=True)
margin = p[0] - p[1]
if margin < BASELINE_P01[question_id] and normally_decisive(question_id):
    flag_for_review(trace)      # never: block, dismiss, or auto-approve
```

`BASELINE_P01` is the 1st percentile of margins observed on clean traffic for that specific
question. Fit it per question; a question that is inherently ambiguous has low margins all the
time and carries no signal.

Optionally pair it with a directed injection Noul, as one shipped guard does — but treat the
two as independent detectors and require neither to trust the other.

Closest jaggedness mode: **6, adversarial content** — the official wording is that adversarial
content "can move the answer." This use case is the only one in the corpus that treats that
movement as the output rather than the failure.

## What stays in code

The margin arithmetic, the baseline percentiles and the job that recomputes them. The repeat
policy (call twice, alarm only if both collapse) that absorbs the 0.16-0.48 run-to-run swing.
The alert routing, the rate limit on alerts, and the trace store. Every real security control:
sandboxing, allowlists, credential scoping, the tool-call gate. None of those may consult this
signal.

## Numbers

From github.com/bestdan/workflow-skills/pull/757, accessed 2026-09-19:

- Margins under injected authority claims: **collapsed from 1.000 to 0.05-0.24**.
- Confidence on the same item across runs: **swung 0.16-0.48**.
- Elsewhere in the same assessment, confidence as correctness: **62.9% agreement at 0.79 mean
  confidence** on commit-type classification, described as "overconfident by 16 points".

No false-positive rate and no detection rate are published for the tripwire itself; the sample
is small and the attacks were the author's own. Treat this as a mechanism with one supporting
observation, not a measured detector.

For scale, a related guard reports a p50 of about 580 ms and about $0.00004 per tool call, and
scanned 662 installed skills with none flagged and a highest legitimate score of 0.74 — also
with no false-positive or false-negative rate published (github.com/leepokai/jev-guard).

Marginal cost of the tripwire itself: **zero**. You are reading a field on a response you were
already paying for. The repeat policy doubles the cost of the questions you choose to double —
method: `input_tokens = chars/4`, `cost = tokens x $0.042 / 1e6`, output free.

## When the verdict flips

- **You block on it.** Then it is `no`. Both the source and the shipped guard are explicit:
  confidence is not a correctness gate, and a jev-based guard is "not a sandbox".
- **You have no clean baseline.** Without the per-question margin distribution you are alarming
  on ambiguity, which is most of your traffic.
- **The question is inherently close.** Two labels that legitimately compete will sit at low
  margin permanently and produce nothing but noise.
- **You alarm on single calls.** The 0.16-0.48 run-to-run swing is larger than many real
  collapses.
- **An attacker learns the tripwire exists.** It is a heuristic on a public model's behaviour; a
  quieter injection that does not invoke authority may not move the margin at all. Nothing here
  bounds the false-negative rate.
- **You upgrade the model.** Margin distributions are version-specific. Refit on every version
  change, including a silent one.

## Alternatives considered

- **A directed injection-detection Noul.** The obvious complement, shipped in at least one
  guard, and it catches known attack shapes this misses. It is also the thing an attacker tunes
  against. Run both; neither alone.
- **Deterministic canary tokens in tool results.** Free, exact, zero false positives, and it
  catches exfiltration patterns this cannot see. Strictly better where it applies.
- **Frontier LLM reviewing the input.** Can explain what it found, which jev cannot — there is
  no chain of thought to read. Seconds and cents per check; viable for the flagged tail, not
  for every call.
- **Self-consistency across reworded prompts.** Also detects pressure, at N times the cost, and
  a behaviour study showed a one-word framing change moving correct answers from 0/20 to 20/20
   — rewording is itself a large perturbation, which muddies the signal.
- **Human review of flagged traces.** Where the flags should go. This produces a queue, not a
  decision.
- **Logging margins and looking at them weekly.** The zero-risk version, and the right first
  step: you need the baseline anyway.

## Sources

- https://github.com/bestdan/workflow-skills/pull/757 — accessed 2026-09-19 ("Injection attacks
  via plausible authority claims collapsed margins from 1.000 to 0.05-0.24"; "useless as
  correctness gate"; "sharply responsive to injected pressure"; confidence swing 0.16-0.48;
  62.9% at 0.79 mean confidence, "overconfident by 16 points")
- https://github.com/leepokai/jev-guard — accessed 2026-09-19 (p50 ~580 ms, ~$0.00004 per tool
  call, 662 skills scanned, highest legitimate score 0.74, "Not a sandbox ... Jev can be wrong")
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19 (mode 6)
- https://github.com/RINNECODER/jev-behavior-study — accessed 2026-09-19 (framing change moved
  correct answers 0/20 to 20/20)
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
