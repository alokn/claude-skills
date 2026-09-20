# Jev primer (verified against docs.typesafe.ai, 2026-09-19)

**Freshness rule.** This file is a pinned snapshot for offline use. When WebFetch is available, fetch these
three pages first and prefer them over anything below that disagrees:
`https://docs.typesafe.ai/models.md` (price, limits, current version),
`https://docs.typesafe.ai/model-jaggedness/<current-version>.md` (failure modes; find the slug in
`https://docs.typesafe.ai/llms.txt`), and `https://docs.typesafe.ai/concepts/use-case-map.md`. Note the
version you used in the report's "Coverage and limits" section.

Table of contents: What jev is · API shape · Primitives · Confidence · Limits and pricing · Failure modes · Patterns · Cookbooks · Decision shapes · Current-code equivalents · Sources

## What jev is

Jev is TypeSafe AI's hosted **System One model**: a frontier-intelligence function call that takes unstructured
`state` in and returns **typed, calibrated probabilistic decisions** out. It does not generate text, code, or
explanations. It is trained with RLCD (Reinforcement Learning for Calibrated Decisions) so probabilities are
optimised to reflect real uncertainty.

It is NOT: a fine-tuning service, a "compile a model from examples" tool, an agent framework, or a small LLM.
One set of weights serves every account; you shape behaviour purely through `state`, `instructions`, and `criteria`.

Design philosophy (TypeSafe's words): "build a normal software workflow and insert System One only where AI is
needed. Keep control flow, deterministic rules, and side effects in code." Code owns the workflow; jev supplies
programmable common sense at the points where code needs semantic understanding.

## API shape

```http
POST https://api.typesafe.ai/v1/systemone
Authorization: Bearer <TYPESAFE_API_KEY>
```
```json
{
  "state": "string | JSON object | array of text",
  "model": "jev-latest",
  "questions": {
    "<your_id>": { "type": "noul|choice|score", "instructions": "...", "criteria": ... }
  }
}
```
Response: `answers` keyed by the same ids, plus `usage.input_tokens`. Question ids are NOT sent to the model.

SDKs: `pip install typesafe-sdk` (`from typesafe_sdk import TypeSafeClient, Choice, Score, Noul`;
`client.system_one(state, questions)`), `npm install @typesafe-ai/sdk` (`client.systemOne({state, questions})`,
helpers `choice()`, `score()`, `noul()`). Both read `TYPESAFE_API_KEY`, default to `jev-latest`, retry 429/529.

## The three primitives

| Primitive | Question shape | Criteria | Answer fields |
|---|---|---|---|
| **Noul** | yes/no: "Does this message request a refund?" | optional `{true: "...", false: "..."}` | `noul` = P(yes) in 0..1. No confidence field. |
| **Choice** | pick one of N: "Which team should handle this?" | map option -> description (or null). **Up to 255 options.** Add `other`/`none` when list may not cover input. | `choice`, `probabilities` (sum to 1), `confidence` |
| **Score** | position on an ordered rubric: "How frustrated is the customer?" | ordered array of level descriptions, **2 to 10 levels** | `score` (probability-weighted, can fall between levels), `legend`, `probabilities`, `confidence` |

Rules of thumb:
- Multi-label ("which of these apply") = one Noul per label, not a Choice.
- Choice is relative (which option wins); Noul is absolute (each can be low). Use both when you need "pick the
  best" AND "is any good enough".
- Every question sees the same `state` and is evaluated **independently and in parallel**; adding questions adds
  ~no latency. One answer never becomes context for another (chaining needs a second request).
- `instructions` and `criteria` accept JSON structure (`{question, focus, compare, examples, not_for}`) for
  contrastive definitions. Reference nested state with backticked paths: `` `ticket.messages[0].text` ``.

## Confidence

`confidence` (Choice/Score) collapses the probability distribution into one 0..1 number. Standard use is three
bands: high -> act automatically; medium -> confirm / flag for review; low -> route to human or a reasoning model.
Thresholds scale with the stakes of the action and must be tuned on your own data. Pin `jev-1.13.0` (not the
alias) once thresholds are tuned. Don't carry a Noul threshold to a Choice or assume P(x) + P(not x) = 1.

## Limits, pricing, speed (jev-1.13.0)

| | |
|---|---|
| Input | Text only: string, JSON object, array of text. No images/audio/video. English strongest; other languages accepted with lower accuracy. |
| Context | 64k tokens per request total; 32k for `state` + longest single question (about 150k chars of English). |
| Price | **$0.042 per million input tokens** ($42 per billion). **Output tokens free.** |
| Latency | 70 to 500 ms end-to-end; "most queries about 100 ms". Suitable for request paths and UI. |
| Rate limits | 250k tokens/s, 1,200 requests/min (dynamic; enterprise higher). |
| Hosting | Cloud only (US West). Zero data retention for enterprise. Not trained on customer data. |
| Accuracy (TypeSafe's own workflow evals, evals.typesafe.ai) | Roughly Sonnet-5 / mid-tier class on decomposed workflows (~68% vs Opus-5 ~73%), at 2 to 3 orders of magnitude lower cost and 25 to 100x lower latency. Weakest on invoice-style precise extraction. Treat as directional; run your own eval. |

## Known failure modes (jev-1.13 "jaggedness" page). These are DISQUALIFIERS or REWRITE triggers

| # | Failure | Rewrite |
|---|---|---|
| 1 | Literal reading of instructions | Write the exact condition; put boundary cases in criteria |
| 2 | Math, counting, numeric representations (hex, RGB, assembly) | Compute in code; ask one Noul per item and sum in code |
| 3 | Date/time comparison and arithmetic | Extract components as Choice over enumerated parts; compare in code |
| 4 | Multi-hop indirection, double negatives | One hop per question; name the state path |
| 5 | Large state with irrelevant detail (context rot) | Filter in code first; send only fields the question needs |
| 6 | Adversarial / injected content in state | Explicit criteria; test edge cases; don't make jev the sole security gate |
| 7 | Contradictory instructions vs criteria | Align wording; true means yes |
| 8 | Structural invariants not guaranteed (Noul vs Choice, P + not-P) | Ask each decision one way |
| 9 | **Generation** (summaries, replies, code, free-form extraction) | Not a jev task. Bounded extraction = Choice over code-produced candidates |

## Architectural patterns

- **Speculative fan-out**: ask every question the decision tree might need in one call (e.g. category AND
  bug_severity AND refund_requested); code ignores irrelevant answers. Cost: tokens only; latency: none.
- **Confidence-gated routing**: the answer says what; confidence says whether to act. Per-action thresholds.
- **Composite scoring**: several atomic Scores, weights in code. Reusable, tunable without re-inference.
- **Intent routing**: jev classifies intent/complexity first; route to deterministic code, a specialist LLM, or a
  human. Expensive resources only for cases that need them.
- **Select, don't generate**: regex/parser produces candidates; jev picks the right one.
- **Cascade / verify**: cheap model extracts, jev verifies each field, only failures go to a reasoning model.

## Cookbooks (docs.typesafe.ai/cookbooks/<slug>.md). Cite the closest one in each finding

| Slug | What it shows |
|---|---|
| `parallel_questions` | 13 questions batched in one call: 12.2x cheaper, 10x faster, same answers |
| `rerank_typesafe` | BM25 shortlist + one jev question per (query, candidate): top-1 5% -> 18%, top-10 38% -> 62% |
| `semantic_find` | Score 218 line ids against a plain-language query in one request; Noul "does the doc answer it at all" |
| `classifying_rag_passages` | Score retrieved passages; drop injected/irrelevant ones before the answering LLM |
| `citation_check` | Choice: does the quoted context support the claim; confidence flags for review |
| `sde_cascade` | mini-LLM extract -> jev verify each field -> reasoning model only on failures |
| `pre_parsed_value_extraction_cookbook` | regex finds candidate emails/phones/amounts; jev selects the requested one |
| `date_extraction_cookbook` | date parts as Choice over enumerated components; code assembles and compares |
| `function_calling` | NL request -> function name (Choice) + closed-set args (Choice/Noul) with confidence |
| `hierarchical_classification` | beam search over Choice probabilities through deep taxonomies |
| `skill_suggestion` | rank 182 agent skills in one call; second call re-judges top 3 and may reject all |
| `autoformat` | recover Markdown structure: classify every block (heading/list/code/callout) |
| `consistency_noul_cookbook`, `consistency_choice_cookbook` | run-to-run stability with an explicit "uncertain" outcome routed to review (raw agreement 90.8% -> 99.2% when the winning option's *probability* was under 0.60; that threshold is on max option probability, not the API `confidence` field). Note: Haiku 4.5 at temp 0 was *more* repeatable (100%); repeatability is not accuracy |
| `autoresearch_feature_discovery` | jev probabilities as features for a CatBoost model with ground-truth outcomes |
| Also in official skill: knowledge-graph entity alignment (450 candidate pairs, 3-level Score merge/leave/curator); classification-with-confidence fallback to broader taxonomy level; LLM guardrails |

## Decision shapes jev is built for (from the use-case map)

Classification · Detection (probability a property is present) · Scoring on an ordered rubric · Routing ·
Search · Retrieval · Ranking · Verification (citations, policy, tool calls, response quality) ·
ML feature extraction · Structured extraction over a bounded answer space.

Headline categories: AI automation software (run a million times with no human copilot); real-time apps
(sub-500 ms in the request path or UI); AI map-reduce over big data; universal verification of other AIs'
inputs/outputs/tool calls; harness engineering (model routing, context selection, trace classification,
semantic CI lints).

## What existing code usually looks like where jev fits

| Existing mechanism | Typical weakness | Jev shape |
|---|---|---|
| LLM call whose prompt asks for a label / yes-no / 1-5 / JSON enum | slow (seconds), $0.2-$10/Mtok in + 5x out, parse failures, overconfident | Choice / Noul / Score, ~100 ms, $0.042/Mtok in, output free, cannot violate schema |
| Keyword lists, regex on free text for intent/spam/urgency/PII/sentiment | brittle, no confidence, endless maintenance | one Noul per property |
| if/switch chains on string content, rule engines with "contains" conditions | same | Choice + confidence gate |
| Embedding cosine threshold for classify / dedup / route | threshold tuning, no semantics of "same" | Noul per candidate pair, or rerank |
| Fuzzy string match (levenshtein, rapidfuzz) for entity dedup | false merges | code shortlists, jev Score merge/leave/review |
| Manual review / moderation queue with no triage | human cost, latency | jev pre-scores; confidence routes only uncertain items to humans |
| Search: ILIKE / tsvector / BM25 with no rerank | relevance | rerank top-k with one question per candidate |
| Sentiment / language / toxicity library | fixed taxonomy, low accuracy | Score / Noul with your own criteria |
| LLM-as-judge for evals, guardrails, tool-call validation | cost, latency, overconfidence | Noul per check with calibrated abstention |
| Free-text parsing of dates/amounts/ids by regex | edge cases | regex candidates + jev Choice |

## Sources

Blog: typesafe.ai/blog/introducing-system-one-models-and-jev · Docs index: docs.typesafe.ai/llms.txt ·
Key pages: /concepts/how-to-build-with-system-one.md, /concepts/use-case-map.md, /patterns/*.md, /confidence.md,
/models.md, /api.md, /model-jaggedness/jev-1.13.md · Evals: evals.typesafe.ai · Official agent skill:
github.com/typesafe-ai/skills (install: `claude plugin marketplace add typesafe-ai/skills` then
`claude plugin install typesafe@typesafe-ai`) · Playground: console.typesafe.ai/playground
