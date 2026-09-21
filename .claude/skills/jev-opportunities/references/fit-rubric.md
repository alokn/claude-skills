# Fit rubric: is this a System One task, and how much is it worth?

Contents: Fit test · Disqualifiers and rewrites · Scoring · Priority buckets · Estimating cost and latency ·
Rollout pattern · Evidence rules · Question-design checklist

## The System One fit test

A candidate is a **strong** fit only if every answer is yes. One "no" that can be fixed by a rewrite
(see below) makes it **ok**. A "no" that cannot be rewritten makes it **weak** or disqualified.

| # | Question | Yes looks like |
|---|---|---|
| 1 | Is the input text (string / JSON / array of text) that fits in ~32k tokens *after* code filters it? | A message, record, diff excerpt, list of candidates. Not an image, not a 200-page PDF unfiltered |
| 2 | Is the output a **bounded decision**: one of N (N <= 255), a position on a 2-10 level rubric, or a yes/no probability? | "Which queue", "how severe", "does it request a refund" |
| 3 | Is the judgement **semantic and single-hop**? | Reading comprehension, common sense, comparing two named things. Not arithmetic, counting, date math, or chained inference |
| 4 | Can the instruction be written so a **literal** reader gets it right? | The exact condition is statable; boundary cases go in criteria |
| 5 | Does code keep control? | Code filters state, asks the question, combines answers, owns thresholds, side effects, and the low-confidence path |
| 6 | Is there a **low-confidence path** that is acceptable? | Human review, ask the user, fall back to existing logic, escalate to a reasoning model |
| 7 | Does the **volume, latency, or brittleness** make the current approach painful? | Runs per request/event/row; LLM cost or seconds of latency; keyword list keeps growing; humans review everything |

## Disqualifiers and their rewrites

| Proposal smells like | Why jev fails | Rewrite that makes it a System One task |
|---|---|---|
| "Generate / summarise / rewrite / draft ..." | Jev does not produce text | Keep the generator; add jev to *route to* it, *verify* its output, or *decide whether* to call it |
| "Extract the <unbounded value>" (name, amount, date, address) | Free-form extraction is generation | Regex/parser produces candidates; jev **selects** the right one (Choice) or confirms a candidate (Noul) |
| "Count / total / how many / percentage" | Jev does not count | One Noul per item, sum in code |
| "Older than / overdue / within N days / before / after" | Dates are text to jev | Compute in code. If the date is buried in prose, jev picks month/day/year as Choice over enumerated parts |
| "Is this number close to / above ..." | Numeric reasoning is weak | Compute in code; ask jev only the semantic part (e.g. "does this reason justify an exception?") |
| "Classify this image / screenshot / audio" | Text only | Only if a text representation (OCR, alt text, structured state) already exists |
| "Understand the full document and reason about ..." | Multi-hop; context rot | Split into atomic questions over filtered excerpts; or let jev decide *which* items need a reasoning model |
| "Block the request if malicious" as the sole gate | Adversarial input can move the answer | Deterministic rules stay authoritative; jev adds a semantic layer and flags for review |
| Replacing a correct deterministic rule with judgement | Determinism was right | Do not propose. Say so in "considered and rejected" |

## Scoring each finding

| Field | Scale | How to decide |
|---|---|---|
| **impact** | 1-5 | 5 = touches every request/item, or unlocks a headline feature, or removes a human queue. 3 = meaningful but bounded. 1 = nice-to-have. State the *unit* of impact: $/month, hours/week of review, p95 latency, error rate, or user value |
| **effort** | S / M / L | S = one call site, < 1 day, no schema change. M = new code path + threshold tuning + shadow mode, days. L = new feature surface, UI, data model, weeks |
| **confidence** | verified / inferred / speculative | verified = you read the code and every claim is backed by file:line. inferred = mechanism confirmed, volume or cost estimated. speculative = plausible from names/structure only. The validator downgrades verified to inferred if any evidence fails |
| **jev_fit** | strong / ok / weak | From the fit test above |

## Priority buckets (report ordering)

Apply in order; the first matching rule wins, so every finding lands somewhere.

1. **Do first**: impact >= 4, effort S or M, fit strong, confidence verified or inferred
2. **Quick wins**: impact 2-3, effort S, fit strong, confidence verified or inferred
3. **Plan**: impact >= 3, effort M or L, fit strong or ok, confidence verified or inferred
4. **Later / validate**: everything else (fit ok needing a rewrite, fit weak, confidence speculative, impact <= 2 with effort M or L)
5. **Considered and rejected**: failed the fit test or a counter-signal applies. **Always include this section**;
   it is the reader's main defence against over-selling

## Estimating cost and latency honestly

State the method in the finding. Never present a ratio without the inputs.

```
jev cost per call   = input_tokens x $0.042 / 1,000,000      (output is free)
                      input_tokens ~= chars(state + all questions) / 4
                      e.g. 1,500-token ticket + 6 questions ~= 1,700 tokens ~= $0.00007
jev latency         = 70-500 ms typical (~100 ms common); one call regardless of question count
volume              = from code/config (cron schedule, queue size, request handler) or "unknown: measure"
current LLM cost    = look up the provider's current price for the model in the code; do NOT quote from memory
current heuristics  = $0 compute; the cost is maintenance, misroutes, and human review time. Say which
```

Report as: `current: <what you can source>  |  proposed: <jev estimate>  |  method: <one line>`.
If volume is unknown, write "per-call: X; volume unknown" rather than inventing a monthly figure.
Accuracy: do not claim jev is more accurate than the incumbent. Public evals put jev roughly at mid-tier LLM
accuracy with far better abstention. Claim what you can show: calibrated confidence with an honest low-confidence signal,
schema safety, speed, cost. Do not claim run-to-run consistency either: TypeSafe's own choices
cookbook found Claude Haiku 4.5 at temperature 0 more repeatable than jev. Accuracy is validated in the rollout, not asserted in the report.

## Rollout pattern (include in every "Do first" finding)

1. **Question constants in one file**, thresholds beside them, so humans review questions not call sites.
2. **Shadow mode**: run jev alongside the current logic; log `{state_hash, answers, probabilities, model,
   current_decision}`; no behaviour change.
3. **Calibrate** on what you already have: past human decisions, resolved tickets, merged labels. Plot
   confidence vs agreement; pick thresholds per action by stakes.
4. **Flip the gate** for the high-confidence band only; medium band suggests; low band keeps the old path.
5. **Retire only the redundant heuristic classification, after gates** (measured error and coverage at
   the live thresholds, drift monitoring, observed availability). Deterministic invariants, the
   timeout/error fallback, and a rollback switch stay while the API is in the path.
6. **Pin** `jev-1.13.0` once thresholds are tuned; re-calibrate on version bumps.

## Evidence rules (enforced by scripts/validate_findings.py)

- Every finding cites at least one `{file, line, snippet}` where the snippet is a verbatim line from the
  repo. Findings with no verifiable evidence are dropped.
- Cite the line that *makes the decision today* (the regex, the `if`, the LLM call, the queue query), not
  the file header.
- For "feature" findings the evidence is the surface: the model field, the create endpoint, the form
  component, the list query.
- Do not cite a file you have not opened. Do not paraphrase a snippet.
- A claim about what the code does that turns out to be an *input* rather than an *output* (a request
  parameter, a user-chosen option) is a hard failure. Read the call site both ways before proposing a swap.

## Question-design checklist (for the primitive sketch in each finding)

- One judgement per question; instructions say exactly what to compare, naming state paths with backticks.
- Choice: 2-255 options, each with a contrastive description (`what`, `not_for`, `examples`); include `other`
  or `none` when the list may not cover the input.
- Score: 2-10 levels, each a concrete, distinct situation, low to high.
- Noul: `true` means yes; add `criteria.true/false` for boundary cases.
- Speculative questions are fine (ask severity even if it may not be a bug); code ignores what is irrelevant.
- State contains only what the questions need; code filters first.
- Say which answer field drives which branch, and the threshold band for each action.
