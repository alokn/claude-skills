---
id: df-rollout
title: Rollout and calibration — shipping a jev decision safely
last_verified: 2026-09-19
jev_version: jev-1.13.0
sources:
  - https://docs.typesafe.ai/confidence.md  (three bands; thresholds scale with risk; "start with conservative thresholds, test with your own data")
  - https://docs.typesafe.ai/models.md  (aliases move; pin the versioned id once thresholds are tuned; response reports the versioned model)
  - https://docs.typesafe.ai/agent-skill.md  ("put the constants (questions and thresholds) in a single place")
  - https://docs.typesafe.ai/cookbooks/consistency_noul_cookbook.md  (explicit "uncertain" outcome routed to review; run-to-run stability)
  - https://docs.typesafe.ai/cookbooks/classification_using_confidence.md  (fall back to a broader level when confidence is low)
  - https://docs.typesafe.ai/introduction/machine-learning-primer.md  (calibration is a property of groups of predictions, not single answers)
related: [df-fit-test, df-cost-model, gt-confidence-and-calibration]
---

## The sequence

1. **Write the questions and thresholds in one module.** Humans review questions, not call sites.
   TypeSafe's own advice: agents are not great at writing questions; expect to edit them by hand.
2. **Smoke-test the questions on ten real examples in the Playground** before writing code. This is a
   prompt sanity check, not an evaluation. If you find yourself explaining what you meant, put that into
   the instructions or criteria.
3. **Shadow mode.** Run jev beside the incumbent logic. Log `{state_hash, model (versioned id from the
   response), answers, probabilities, confidence, incumbent_decision, timestamp}`. Change nothing.
4. **Calibrate on data you already have, after auditing it.** Past human decisions, resolved tickets,
   merged labels, approved/rejected queue items are a labelled set, but check label noise and policy
   drift before trusting them. Plot confidence against agreement with the label per class and per
   confidence band; choose thresholds per action by stakes. Size the evaluation from class prevalence and
   the confidence interval you need on the error rate at each threshold, not from a round number; one
   public deployment chose ~100 rows as its advisory-to-active gate, which is adequate only for common
   classes and cheap errors.
5. **Flip the high-confidence band only.** Medium band suggests or asks for confirmation; low band keeps
   the old path or goes to a human. Different actions get different thresholds: reading a balance at 0.6
   is fine, approving a transfer needs more than 0.85 (TypeSafe's own example).
6. **Retire only what jev made redundant, and only after gates are met.** Deterministic invariants
   (security, money, legal, dates, ids) stay permanently authoritative. A tested timeout/error fallback and
   a rollback switch stay for as long as the API is in the path, because 429/529 responses are documented
   and limits change without notice. What you may retire is the redundant heuristic *classification*
   (the keyword list, the regex label), and only after explicit gates: measured error and coverage at
   the live thresholds, drift monitoring in place, and availability observed over a meaningful period.
   Until then the old classifier is the fallback, not dead code.
7. **Pin the model version before calibrating, not after.** `jev-latest` moves when a release ships.
   Send `jev-1.13.0` (or the version you are calibrating on) from the first shadow-mode call, so every
   logged answer is attributable, and re-calibrate deliberately on upgrades.

## What calibration means and does not mean

Calibration is a statement about groups: among answers given probability 0.8, about 80% should be
correct. It is not a guarantee about any single answer. So thresholds are tuned per question and per
domain, and a threshold tuned on a Noul does not transfer to a Choice, nor from one phrasing to another.

Independent measurements show calibration is **dataset-dependent**: one pre-registered benchmark
reported ECE 0.045 on 20 Newsgroups and 0.242 on Amazon ESCI, and a routing study found the same default
threshold said "route" on Banking77 and "do not route" on Web of Science ("a default threshold would be
wrong roughly as often as it was right"). See `00-ground-truth/evidence-independent.md`. Never ship a
threshold you did not measure on your own data.

Confidence is also **not a correctness gate under adversarial input**: one field report found plausible
authority claims injected into the state moved confidence margins from 1.000 to 0.05-0.24. The same
sensitivity makes a sudden confidence collapse a useful tamper signal, but only if a deterministic layer
still owns the decision.

## Monitoring after launch

- **Band shares.** Track the fraction of items landing in each confidence band. A drift toward the low
  band means the input distribution moved or the question no longer fits.
- **Agreement sampling.** Keep sending a random slice through the human path and compare.
- **Version in every log line.** The response's `model` field tells you which version answered.
- **Explicit uncertain outcome.** Rather than forcing a label at 0.5, surface "uncertain" as its own
  outcome and route it; the consistency cookbooks show this pattern (raw label agreement 90.8% became
  99.2% once answers whose **maximum option probability** was under 0.60 were routed to review, with 74.2%
  of items still handled automatically). Note the statistic: that experiment thresholds the winning
  option's probability, not the API's `confidence` field; the two differ (autoformat's example shows
  winning probability 0.53 with confidence 0.43). Name the exact field in every threshold you set.

## Failure signatures and what they mean

| Symptom | Likely cause | Fix |
|---|---|---|
| Confident wrong answers on a class of inputs | Literal reading; boundary case not in criteria | Add the case to `criteria`; split the question |
| Confidence uniformly low | State too large or off-topic; options overlap | Filter state; make Choice options contrastive; add `other` |
| Answers flip between two options for similar inputs | Options are not distinct | Rewrite option descriptions with `what` / `not_for` / `examples` |
| Great in the Playground, worse in production | Production state includes noise the Playground did not | Log real state; trim to the fields used |
| Non-English inputs underperform | English is the primary training language | Route by language in code; evaluate separately |
| Sudden shift after a date | Alias moved to a new version | Pin the version; re-calibrate |
