---
id: cb-index
title: Official TypeSafe cookbooks, indexed
url: https://docs.typesafe.ai/llms.txt
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

# Official TypeSafe cookbooks

One file per official cookbook at `https://docs.typesafe.ai/cookbooks/<slug>.md`. Each entry
records the task and dataset, the exact decomposition (state, questions, thresholds), every
number the cookbook reports, the caveats the cookbook itself states, and the transferable
pattern. Numbers below are verbatim from the sources; where a cookbook reports no number for a
category, the entry says "not reported" rather than estimating.

## Index

`source_model_version` is the model the cookbook's own code and published run used. It is not the
same as the corpus-verification `jev_version: jev-1.13.0` that every entry carries in frontmatter:
most of these numbers were produced on `jev-1.12` and have not been re-run on 1.13.

| slug | title | source_model_version | decision shapes | primitives | headline number | lesson |
|---|---|---|---|---|---|---|
| [autoformat](autoformat.md) | Structure recovery | `jev-1.12` | classification, detection, feature-extraction | choice, noul | Two round trips, 10,211 tokens, 0.8s; cost stated inconsistently ($0.0015 prose / $0.0003 appendix) | Companion questions asked up front, read only when relevant |
| [autoresearch_feature_discovery](autoresearch_feature_discovery.md) | Autoresearch feature discovery | `jev-1.12` | feature-extraction, scoring | score, noul | Held-out RMSE 3.09 baseline -> 1.77 with 38 questions (spearman 0.799) | jev as featurizer; a supervised model does the regression |
| [citation_check](citation_check.md) | Double-checking citations | `jev-1.12` | verification, classification | choice | 4 verified at conf 0.93+; all 4 planted failures caught (0.27 and 0.56 to review) | Deterministic quote match first, one Choice judges support |
| [classification_using_confidence](classification_using_confidence.md) | Classification using confidence | `jev-1.12` | classification, routing | choice | 39/60 forced; 48/60 useful when the unsure half answers one level up | Low confidence answers one taxonomy level up, no second call |
| [classifying_rag_passages](classifying_rag_passages.md) | Classifying RAG passages | `jev-1.12` | classification, routing, detection | noul | 72 passages routed on injection 0.70 / contradicts 0.70 / relevant 0.45 / evidence 0.55 | Fan out four Nouls per passage; code owns the routing |
| [consistency_choice_cookbook](consistency_choice_cookbook.md) | Self-consistency: choices | `jev-1.13.0` | classification, routing | choice | Raw agreement 90.8% -> policy agreement 99.2% at 0.60, 25.8% uncertain; 114ms per call | An abstain band converts near-ties into one stable route |
| [consistency_noul_cookbook](consistency_noul_cookbook.md) | Self-consistency: nouls | `jev-1.13.0` | classification, verification, routing | noul | Mean per-question probability std dev 0.0102; 111ms, $0.000043 per 14-question call | A 0.30-0.70 review band absorbs wobble around 0.5 |
| [date_extraction_cookbook](date_extraction_cookbook.md) | Date extraction | `jev-1.12` | extraction, classification | choice | 6 of 6 matched expected; 5 auto-accept, 1 to review at conf 0.46 | Model reads date parts; code does all calendar maths |
| [entity_alignment](entity_alignment.md) | Knowledge graph entity alignment | `jev-1.12` | classification, routing, scoring | score, noul | 450 pairs: 40 sameAs (8.9%), 50 curator (11.1%), 360 unlinked (80.0%) | One Score level per action; rounding is the routing rule |
| [function_calling](function_calling.md) | Function calling | `jev-1.12` | routing, classification, extraction | choice, noul | 10 functions, 28 fillable arguments, 54 questions per command; 14 commands at conf 0.53-1.00 | Closed-set Choices make every tool argument valid by construction |
| [hierarchical_classification](hierarchical_classification.md) | Hierarchical classification | `jev-1.12` | classification, search, ranking | choice | Beam search matched 4 of 4 expected leaves; greedy matched 2 of 4 (K=3) | Beam search over Choice probabilities recovers early ambiguous turns |
| [llm_guardrails](llm_guardrails.md) | Guardrails for LLMs | `jev-1.12` | detection, classification, scoring, routing | score, noul | 15 messages routed under strict (review >= 0.35, action >= 0.70, severity_block 2.0) | Split a vague predicate into narrow hazards; code owns thresholds |
| [parallel_questions](parallel_questions.md) | Parallel questions | `jev-1.12` | verification, classification, scoring | choice, score, noul | 13 questions in 1 call $0.000497 / 0.27s vs 13 calls $0.006090 / 2.71s: 12.2x cheaper, 10.0x faster | Batching questions into one call changes cost, not answers |
| [pre_parsed_value_extraction_cookbook](pre_parsed_value_extraction_cookbook.md) | Pre-parsed value extraction | `jev-1.12` | extraction, classification | choice, noul | 3 worked cases, selected span returned verbatim at conf 0.90-1.00; Choice limit 255 options | Select from regex candidates; never generate the value |
| [rerank_typesafe](rerank_typesafe.md) | Re-ranking | `jev-1.12` | ranking, search, scoring | noul | top-1 5% -> 18%, top-5 15% -> 35%, top-10 38% -> 62%; 1200 calls, $0.0645 | One Noul per pair becomes a sort key; BM25 keeps recall |
| [sde_cascade](sde_cascade.md) | SDE cascade | `jev-1.12` | verification, detection, routing | noul | Gate FIRE_T 0.7: hallucinated 0.95 fires where the holistic judge reads 0.56 | Per-field nouls localise errors a holistic judge misses |
| [semantic_find](semantic_find.md) | Line-by-line search | `jev-1.12` | search, ranking, detection | choice, noul | 218 lines, 43,980 characters in one request; exists 0.98 / 0.14 / 0.46 at FOUND 0.7, ABSENT 0.35 | Choice ranks; a separate Noul says whether an answer exists |
| [skill_suggestion](skill_suggestion.md) | Skill suggestion | `jev-1.12` | ranking, routing, classification, detection | choice, noul | Wrong loads 16.8% -> 7.3%, needless loads 9.8% -> 4.0% over 488 requests | Rank all cheaply, then reread the top three properly |

## What each cookbook actually measures

Most cookbooks are worked demonstrations, not benchmarks. Use this before citing one as
evidence for a claim.

| slug | task accuracy figure | cost figure | latency figure | named-LLM comparison |
|---|---|---|---|---|
| autoformat | no | cost stated inconsistently ($0.0015 prose / $0.0003 appendix) | yes (0.8s) | no |
| autoresearch_feature_discovery | yes (RMSE, spearman) | no | no | proposer `claude-sonnet-5` only |
| citation_check | 8 hand-built citations | no | no | no |
| classification_using_confidence | yes (60 10-K sections) | no | no | no |
| classifying_rag_passages | no | no | no | `claude-sonnet-5` as downstream generator only |
| consistency_choice_cookbook | no (repeatability only) | yes | yes (114ms) | yes |
| consistency_noul_cookbook | no (repeatability only) | yes | yes (111ms) | yes |
| date_extraction_cookbook | 6 examples | no | no | no |
| entity_alignment | no | no | no | no |
| function_calling | 14 commands | no | no | no |
| hierarchical_classification | 4 labelled documents | no | no | no |
| llm_guardrails | 15 messages | no | no | no |
| parallel_questions | no | yes | yes | no |
| pre_parsed_value_extraction_cookbook | 3 examples | no | no | no |
| rerank_typesafe | yes (40 CLERC queries) | yes ($0.0645) | no | no |
| sde_cascade | image-only frontier | partial | no | yes |
| semantic_find | no | no | no | no |
| skill_suggestion | yes (488 requests) | no | yes | `claude-haiku-4-5-20251001` as the agent |

## Cross-cutting notes

- **Model version.** Sixteen of the eighteen pin `jev-1.12` in their own code. Only the two
  consistency cookbooks pin `jev-latest`, which resolved to `jev-1.13.0`, sampled 2026-09-11. Each
  entry records this in frontmatter as `source_model_version`; the corpus-wide `jev_version`
  frontmatter stays `jev-1.13.0`, the version the corpus was verified against. No cookbook leaves the
  model unstated.
- **Prices are historical.** Several cookbooks carry `TYPESAFE_PRICE = (0.042, 0.00)` marked
  "as of 2026-08" or "as of 2026-09", and LLM prices marked "as of 2026-07". The consistency
  cookbooks state the figures "are not verified `jev-latest` prices or current billing
  amounts". The SDE cascade calls its 100-prompt results "a historical snapshot; its costs
  have not been recalculated at the current Jev rate".
- **Consistency is not accuracy.** The choice cookbook annotates its own counter-result:
  `claude-haiku-4-5` at temperature 0 reaches 100.0% repeatability against jev's 90.8% raw /
  99.2% policy agreement, and the cookbook adds "100% repeatability does not imply
  correctness. This experiment does not measure accuracy."
- **Known source defects.** `docs.typesafe.ai/cookbooks.md` served a byte-identical copy of the
  `consistency_noul_cookbook` page rather than an index, so the index above was reconstructed
  from `llms.txt`. The `consistency_noul_cookbook` page cites a mean std dev of `0.0102` but
  contains no per-condition std-dev table. `autoformat` states its cost inconsistently: `$0.0003` in its appendix code
  block against `$0.0015` twice in prose, and this index headlines neither figure alone. Several aggregate results in `sde_cascade` and
  `hierarchical_classification` exist only inside rendered images and were recorded as
  "not reported".

## Anti-use-cases these cookbooks imply

`au-confidence-as-correctness-gate`, `au-date-ordering-and-overdue`,
`au-exact-lookup-and-id-matching`, `au-expect-identical-results-across-runs`,
`au-flat-choice-over-255-options`, `au-free-form-value-extraction`, `au-numeric-thresholds-and-arithmetic`,
`au-open-ended-agent-loop`, `au-predict-outcome-instead-of-features`,
`au-replace-vector-retrieval-with-jev-rerank`, `au-rewrite-and-translate-text`,
`au-sole-security-gate`, `au-whole-document-in-state`.

One shape has no corpus entry: per-question request fan-out over the same large document
(`parallel_questions`), which the cookbook argues against but no anti-use-case file covers.
