---
id: au-confidence-as-correctness-gate
title: Do not use jev's confidence as a gate on whether the answer is correct
verdict: no
domain: trust-safety
decision_shapes: [verification, routing, detection]
primitives: [choice, score]
evidence_level: independent-benchmark
sources:
  - https://github.com/bestdan/workflow-skills/pull/757  (margins 1.000 to 0.05-0.24 under injection; "useless as correctness gate"; commit type 62.9% at 0.79 confidence)
  - https://docs.typesafe.ai/confidence.md  ("This describes the model's answer, not a guarantee that the answer is correct")
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 6, adversarial content can move the answer)
  - https://github.com/wotai-dev/typesafe-jev-tools  (ECE 0.121 at 66.0% accuracy, 149 rows)
related: [au-sole-security-gate, au-zero-hallucination-means-always-right, au-copy-calibration-thresholds-across-domains, uc-agents-harness-prompt-injection-semantic-flag]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to auto-approve anything jev returns at confidence above 0.9?" Also "use high
confidence as our correctness check", "if confidence is 1.0 we can skip review", "gate the agent on the
margin between the top two options".

## Verdict

**No.** Confidence describes the shape of a probability distribution, not the truth of the answer. The
docs say it directly: "In these examples, confidence 1.0 means the returned distribution puts all its
probability on one level. This describes the model's answer, not a guarantee that the answer is
correct", and "Calibration is measured across groups of predictions; it does not guarantee that an
individual answer is correct." bestdan/workflow-skills#757, which assessed seven decision points and
merged the ones that worked, reached the same conclusion from measurement: confidence is "useless as
correctness gate".

## What jev would get wrong

Two failure shapes. Ordinary overconfidence: on commit-type classification the same assessment measured
62.9% agreement at 0.79 mean confidence — "overconfident by 16 points" — with `feat` misread as `fix` 18
times in 43 misses. A 0.79 gate would wave through a decision wrong more than a third of the time. And
the adversarial one: "Injection attacks via plausible authority claims collapsed margins from 1.000 to
0.05-0.24." Whoever can write into the state moves the margin, so the gate is under the attacker's
control — jaggedness mode 6, "text that argues for its own classification, can move the answer".

## What stays in code

The correctness check, and it must be something an attacker cannot move: a deterministic rule, a second
independent system, a checksum against source data, or a human. Confidence stays in code as an
*abstention* signal only — "Low confidence: Do not act. Route to a human, request clarification, or fall
back to a different system" — a one-way valve. Low confidence may stop an action; high confidence never
authorises one.

## The legitimate rewrite

There is one, and it is the interesting part of the finding. The same PR notes confidence is "sharply
responsive to injected pressure", and its recommended use is a **tamper tripwire**: run the decision
twice, once over the raw content and once over a sanitised or truncated version, or simply watch the
margin distribution over time, and raise an alert when a margin that normally sits near 1.000 collapses
into the 0.05-0.24 band. The alert must have a deterministic owner and a deterministic action — quarantine
the document, drop the tool call, page the on-call — because the tripwire detects that *something moved*,
not what the right answer was. Used this way the verdict is **good**; used as a correctness gate it stays
**no**.

## Numbers

Margins 1.000 → 0.05-0.24 under injected authority claims; commit type 62.9% agreement at 0.79 mean
confidence, 43 misses over 43 commits assessed, 18 of them `feat` read as `fix`
(https://github.com/bestdan/workflow-skills/pull/757, 2026-09-19). Independently, 66.0% accuracy at ECE
0.121 over 149 rows, tied with Claude Haiku 4.5 at 66.0% and ECE 0.122
(https://github.com/wotai-dev/typesafe-jev-tools, run 2026-09-18) — calibration that good still leaves a
third of high-confidence answers unverified. The tripwire's duplicate call doubles cost: two calls over a
1,500-token state is roughly 3,400 input tokens, about $0.00014 at $0.042 per million input tokens with
output free (https://docs.typesafe.ai/models.md).

## When the verdict flips

It flips to **conditional** for *automation coverage* rather than correctness: with the
accuracy-versus-confidence curve measured on your own labelled sample, a high-confidence band can be
automated at an error rate you have accepted in writing, with sampling audits. That is an error-budget
decision, not a correctness guarantee, and it does not survive adversarial input — there, no rewrite
exists.

## Alternatives considered

- **Regex / deterministic**: the only real correctness gate for anything checkable.
- **Small LLM**: a second opinion, not a gate; correlated errors.
- **Frontier LLM**: better on hard cases, still not a guarantee, too slow per item.
- **Fine-tuned classifier**: same caveat after the same calibration work.
- **Embeddings**: no correctness signal at all.
- **Human**: the gate for the low-confidence band and anything irreversible.

## Sources

- https://github.com/bestdan/workflow-skills/pull/757 — accessed 2026-09-19
- https://docs.typesafe.ai/confidence.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://github.com/wotai-dev/typesafe-jev-tools — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
