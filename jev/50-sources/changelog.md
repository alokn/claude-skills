# Changelog

## 2026-09-19 · initial build (jev-1.13.0)

- Corpus created from docs.typesafe.ai (111 pages fetched via `llms.txt`), the launch post and its
  embedded FAQ, evals.typesafe.ai, the manifesto and team pages, PyPI/npm SDK metadata, and third-party
  coverage and field reports (see `sources.md`).
- 18 official cookbooks digested. Three (`entity_alignment`, `classification_using_confidence`,
  `llm_guardrails`) appeared in `llms.txt` during the day; the docs are moving quickly.
- Editorial rule added after the cookbook digest: run-to-run consistency is not a claimable
  differentiator (self-consistency choices cookbook: `claude-haiku-4-5` at temperature 0 was 100%
  repeatable vs jev 90.8% raw).
- Known source quirks recorded: `cookbooks.md` on the docs site is a duplicate of the nouls
  consistency cookbook rather than an index; `autoformat` states $0.0015 in prose and $0.0003 in its
  appendix; several cookbook numbers exist only in images and are recorded as "not reported"; 14 of 18
  cookbooks pin `jev-1.12` in their code.
- Number discrepancy recorded: the parallel-questions cookbook reports 12.2x cheaper / 10.0x faster for
  batching 13 questions; the primitives page summarises the same experiment as 11.5x / 9.6x. Both are
  TypeSafe's figures; entries cite the cookbook and note the other.
- Adversarial review: see the entry below once complete.

## 2026-09-20 · adversarial review round 1 (Codex GPT-6 Astra and GPT-5.6 Sol) and fixes

Both reviews are archived verbatim in this directory. Their shared conclusion: the corpus was rich and
candid in its evidence layer but its decision layer was more confident than the evidence supported.
Findings triaged and applied:

- **Calibration promoted from training objective to property** (both): every unqualified "calibrated
  confidence" / "abstention" claim rewritten as "probabilities trained to be calibrated; calibration
  measured on the target distribution (independent ECE 0.045-0.242); abstention is a developer-defined
  threshold policy". Schema rule 2, fit test, cost model, README, alternatives.
- **`strong` granted because a cookbook exists** (both): verdict scale tightened; strong now requires a
  task-matched labelled measurement with stated sample size. 41 strong entries re-graded to 7, then 6
  (see next section). Evidence levels redefined as provenance, not strength.
- **"Delete the incumbent" rollout advice** (both): replaced with retire-only-redundant-classification
  after measured gates; invariants, fallback and rollback stay. Same fix in the jev-opportunities skill.
- **"Mid-tier accuracy with far better abstention"** (both): rewritten as mid-table agreement with a
  two-model reference; the abstention figure attributed to the one 149-row study as a coverage trade-off.
- **Deployment eligibility missing from the fit test** (both): Question 0 added (access, residency, ZDR
  tier, DPA, SLA, rate limits, regional latency, offline requirement).
- **SDE-cascade digest claimed empty extractions escalate** (Astra): false per the cookbook's own code;
  digest and the three dependent entries now state the defect and require deterministic parse-failure
  handling in code.
- **Confidence vs max-option-probability conflation** (Astra): rollout file and autoformat digest
  corrected; the consistency experiments threshold winning-option probability, not the API confidence.
- **Arithmetic error "1,200x cheaper" in alternatives** (Astra): corrected to about 1.24x.
- **Standard-deviation comparison omitted Haiku 4.5 (0.0012 < jev 0.0098)** (Astra): corrected.
- **107 invented use-case ids in cookbook digests** (Astra): all mapped to canonical ids or removed;
  cookbooks now carry `related:` and `source_model_version:` (16 of 18 measured on jev-1.12).
- **Absence claims unscoped** (both): "no independent evaluation", "no ECE published" scoped to
  first-party; links to evidence-independent.md.
- **Editorial verdicts inside ground truth** (Sol): moved to a labelled "Reviewer interpretation"
  section; table cells rewritten as measured facts; claim-adjacent URLs added.
- **Publication-restriction claim unsourced** (Sol): now cites MCA §2.3(f) verbatim
  (https://typesafe.ai/legal/mca) and the jevcal README; the bias consequence labelled as inference.
- **Survey medians presented as a realistic range** (both): 7x/30x now shown with the survey's own
  limitations (24% of posts from users; n=215/180) as retrospective anecdotes.
- **Categorical exclusions** (Astra): non-English and >255 options made conditional with the documented
  rewrites; Q5/Q6 softened so bounded action selection and feature extraction without abstention pass.
- **Verdict-as-asked** (Sol): schema rule added; five conditional entries rewritten to answer the question
  as asked before offering the rewrite; fit-test worked examples corrected (prompt-injection sole gate
  is `no` as asked).
- Minor: 64k/32k context adjudication note; Choice-criteria schema authority note; parallel-questions
  "identical" -> "near-identical (0.804 vs 0.814)"; autoformat cost not headlined; glossary aliases;
  cookbook README counts.

Not applied: trimming alternatives.md to 4,500 words (every paragraph carries sourced numbers; left at
~7,500 words and noted).

## 2026-09-20 · verdict re-grade after adversarial review

An adversarial review found `strong` was being granted because an official cookbook or docs example
existed. A demonstration proves API feasibility, not accuracy. The verdict scale was tightened:
`strong` now requires a task-matched measurement with labelled ground truth and a stated sample
size. Every `20-use-cases/` entry was re-graded against that rule. Only five official cookbooks
report task accuracy on a labelled dataset (`rerank_typesafe`, `classification_using_confidence`,
`skill_suggestion`, `autoresearch_feature_discovery`, and arguably `hierarchical_classification`).

### strong kept (7 — snapshot during the re-grade on 2026-09-20, superseded)

This table records the state *at the moment of the re-grade*. It is not current: the beam-search
entry was demoted later the same day (see the index note below), and the round-2 review demoted
two more (`uc-trust-safety-spam-phishing-atomic-signals` and
`uc-search-retrieval-rrf-fusion-with-dense-retriever`), leaving **four** strong entries. See the
2026-09-20 round-2 section at the end of this file for the current totals.

| id | why it survives |
|---|---|
| uc-search-retrieval-rerank-keyword-shortlist | `rerank_typesafe` is the entry's own task; 40 labelled CLERC queries, plus two independent reranking benchmarks |
| uc-search-retrieval-rrf-fusion-with-dense-retriever | independent-benchmark: 164 queries, 9,831 graded pairs, task-matched |
| uc-search-retrieval-confidence-fallback-broader-level | `classification_using_confidence` is the entry's own recipe; 60 labelled filings, 39/60 -> 48/60 |
| uc-search-retrieval-hierarchical-taxonomy-beam-search | `hierarchical_classification` is the entry's own task; beam 4/4 vs greedy 2/4 on labelled leaves (n=4 — the weakest of the seven) |
| uc-agents-harness-skill-or-tool-selection | `skill_suggestion` is the entry's own task; 488 labelled requests |
| uc-data-ml-text-features-for-tabular-model | `autoresearch_feature_discovery` is the entry's own task; RMSE on 800 held-out rows, plus agentjournal 15,508 rows |
| uc-trust-safety-spam-phishing-atomic-signals | appended field evidence is a measured same-task comparison: bitnovus, 98.64% on 5,733 messages against a TF-IDF baseline |

### strong -> good (34)

Reason in every case: the shape is demonstrated by a cookbook or a docs page, but no task-matched
labelled accuracy is published, so the entry now says so and tells the reader to shadow-evaluate
against the incumbent. The specific gap per entry:

- uc-commerce-catalog-entity-dedup — `entity_alignment` reports an outcome split, not precision/recall.
- uc-commerce-listing-category-normalisation — cookbook accuracy is on Shopify/SEC data, not listings; entry's own Numbers say unmeasured.
- uc-data-ml-kg-relationship-typing-and-entity-alignment — `entity_alignment`; accuracy against `known_same_as` not reported.
- uc-data-ml-map-reduce-corpus-labelling — official-docs; economics only, no accuracy.
- uc-data-ml-structure-recovery-autoformat — `autoformat`; one memo, accuracy not reported.
- uc-trust-safety-opt-out-request-detection — official-docs; no published accuracy.
- uc-trust-safety-policy-violation-bands — `llm_guardrails`; 15 routing decisions, no aggregate metric.
- uc-trust-safety-toxicity-harassment-detection — consistency cookbook measures repeatability, not correctness.
- uc-trust-safety-user-report-triage — same; the cookbook states three times that accuracy was not measured.
- uc-sales-marketing-icp-fit-scoring — official-docs; no accuracy figure.
- uc-search-retrieval-document-answers-query-gate — `semantic_find` is four illustrative queries; `skill_suggestion` measures a different task.
- uc-search-retrieval-rag-passage-gating — `classifying_rag_passages`; no precision/recall.
- uc-search-retrieval-semantic-find-in-document — four queries, no labelled evaluation.
- uc-realtime-voice-command-intent-risk-scaled-thresholds — docs pattern page; no accuracy for any intent set.
- uc-verification-citation-supports-claim — `citation_check` is eight hand-built citations, not one of the accuracy-reporting five.
- uc-verification-document-completeness-checklist — `parallel_questions` measures batching; no gold label.
- uc-verification-extraction-field-verification — `sde_cascade`; per-case accuracy not reported.
- uc-verification-llm-output-policy-check — `llm_guardrails`; precision and recall not reported.
- uc-verification-structured-extraction-cascade — `sde_cascade`; cascade cost/quality points exist only in a chart.
- uc-observability-evals-confidence-threshold-calibration-fitting — community-report; the Janus numbers are not an independent benchmark of this workflow.
- uc-support-frustration-scoring — official-docs; no published accuracy.
- uc-support-intent-routing-handlers — official-docs; economics only.
- uc-support-policy-supports-request — official-docs; unmeasured on policy text.
- uc-support-refund-request-detection — official-docs; no accuracy figure.
- uc-support-ticket-team-routing — official-docs; no accuracy on any taxonomy.
- uc-agents-harness-agent-trace-classification — official-docs; throughput and cost only.
- uc-agents-harness-function-call-argument-filling — `function_calling`; 14 commands, accuracy not reported.
- uc-agents-harness-model-difficulty-routing — official-docs; no published router accuracy.
- uc-hr-recruiting-resume-composite-scoring — official-docs; no validity figure, and none should be inferred.
- uc-insurance-rubric-claim-triage-uncertain-band — `consistency_noul_cookbook` measures stability, not correctness.
- uc-legal-compliance-document-type-classification — the cookbook's 60 labelled filings measure SIC industry group, not document type.
- uc-legal-compliance-regulatory-briefing-parallel-questions — `parallel_questions` measures batching, not accuracy.
- uc-legal-compliance-regulatory-requirement-verification — `citation_check`, eight rows, not one of the five.
- uc-risk-forecasting-demand-signal-feature-extraction — `autoresearch_feature_discovery` measured wine reviews; predictive lift here is not published.

### other verdict and level changes

- uc-sdlc-api-error-log-triage — `good` -> `conditional`. Condition: only where no stable
  error-string table exists, and only after fixing the regex you already have. Empryo's own
  incumbent regex reached 102/102 for free once `429` was digit-bounded.
- uc-sdlc-commit-type-classification — `conditional` -> `weak`, and moved (below).
- uc-agents-harness-context-compaction-relevance — `conditional` -> `weak`, and moved (below).
- uc-observability-evals-rubric-scoring-llm-judge-replacement — `evidence_level`
  `independent-benchmark` -> `community-report`. The source is a vendor-integration post rated high
  bias risk, and agreement with Claude Fable 5.1 is not accuracy. Verdict stays `good`.
- Field-evidence prefixes audited corpus-wide: all 15 `- Field evidence (independent-benchmark):`
  bullets carry a measured comparison with method and sample size, so none was demoted to
  `(community-report)`. The six the community-evidence writer named (bitnovus spam ×3, zhuyansen
  rerank ×2, anessbelbati rerank, Empryo 102-item triage, agentjournal feature extraction) stay.

### files moved

- `20-use-cases/sdlc/commit-type-classification.md` ->
  `30-anti-use-cases/commit-type-classification-unattended.md`, id
  `uc-sdlc-commit-type-classification` -> `au-commit-type-classification-unattended`, verdict
  `weak`, retitled to the unattended-changelog framing, `## What jev decides` converted to
  `## What jev would get wrong`. All numbers kept: 62.9% agreement over 43 commits at 0.79 mean
  confidence; jev 50.0% vs Claude Haiku 4.5 42.0% on 100 rows.
- `20-use-cases/agents-harness/context-compaction-relevance.md` ->
  `30-anti-use-cases/context-compaction-by-relevance-scoring.md`, id
  `uc-agents-harness-context-compaction-relevance` -> `au-context-compaction-by-relevance-scoring`,
  verdict `weak`, same section conversion. Reason: five shipped implementations, zero retention or
  answer-quality measurements, and the strategy is publicly contested.
- `related:` references to both old ids updated in `context-selection-for-downstream-ai`,
  `skill-or-tool-selection`, `wake-sleep-gating`, `release-notes-bucketing`, `pr-title-matches-diff`.

### verdict-as-asked rewrites (5, verdict field unchanged)

The schema now requires the verdict for the question **as asked** first, with any rewrite
introduced explicitly as a separate proposal. Five conditionals were silently answering a different
question; each now leads with `no` for the question as asked and then labels the proposal. Each is
flagged here as belonging in `30-anti-use-cases/` on the as-asked reading, and kept in
`20-use-cases/` because the labelled proposal is the entry's actual subject.

- uc-insurance-straight-through-vs-adjuster-routing — asked "decide which claims can be paid
  straight through"; answer is `no` (payment is the irreversible action). Proposal: jev may only
  move a claim *out* of STP.
- uc-sdlc-reviewer-and-label-routing — asked "pick reviewers" / "replace CODEOWNERS"; answer is
  `no` (ownership is a recorded fact). Proposal: labels and *additional* reviewers only.
- uc-agents-harness-pre-tool-use-destructiveness — asked "decide whether a shell command is safe";
  answer is `no` (`au-sole-security-gate`). Proposal: a hazard battery that only ever adds a
  confirmation.
- uc-verification-invoice-three-way-match — asked "do our three-way match"; answer is `no` (the
  match is arithmetic). Proposal: the semantic residue, advisory.
- uc-support-churn-risk-signal — asked "predict churn"; answer is `no` (the judgement is not in the
  state). Proposal: jev as featuriser for a model trained on outcomes.

### new anti-use-case entries (3)

- `au-open-web-navigation-as-a-feature` (weak) — Wikipedia link-path / open-web navigation as a
  product feature. The launch Wikiracing demo exists but is a demo and TypeSafe discounts its own
  comparison; the cardinality caveat ("hundreds to thousands of links", Choice caps at 255) forces
  a two-stage Score-then-Choice with an extra round trip per hop; `komikat/jev-bfs` publishes no
  numbers at all. Draft item C30.
- `au-startup-idea-and-business-plan-evaluation` (weak) — no ground truth, high-stakes personal
  advice, and what users want back is generation, which jev cannot produce. Draft item I83.
- `au-clinical-medical-answering-for-care` (no) — care guidance is a safety invariant. Recorded as
  `no` rather than the draft's `weak` on that basis. The only independent medical measurement is
  KorMedMCQA jev 80 vs gpt-5.6-luna 88 and MedQA jev 89 vs 84, 100 items per condition, author's
  stated margin ±8 points — the two exams disagree and neither result separates from noise. Draft
  item I84.

### SDE-cascade escalation defect (second adversarial review)

The `sde_cascade` cookbook's code does not escalate an unparseable or empty extraction: it iterates
`record.items()`, so `{}` produces no field checks and the gate stays false; missing required keys
evade the per-field checks the same way; and a `P(wrong)` of 0.5 does not escalate under the `>0.7`
gate. `uc-verification-structured-extraction-cascade`,
`uc-verification-extraction-field-verification` and `uc-agents-harness-model-difficulty-routing`
(the three entries whose Numbers cite the cookbook) now require deterministic handling of parse
failures and missing required fields *before* verification, plus a separate uncertainty policy for
middling error probabilities, and record in "When the verdict flips" that copying the cookbook's
escalation gate verbatim is a known defect. The cascade entry's claim that the fail-safe is
automatic was corrected in place.

### index

`scripts/build_index.py` now skips `adversarial-review-prompt.md`. After the re-grade, as a
**snapshot taken at that time**: 227 entries — strong 7, good 91, conditional 36, weak 14, no 43.
Those numbers were already stale when written (the index held 228 entries with strong 6 after the
beam-search demotion below) and are superseded again by round 2; current totals are recorded at the
end of this file and regenerated by `scripts/build_index.py`.
- uc-search-retrieval-hierarchical-taxonomy-beam-search: strong -> good (orchestrator ruling after re-grade: the only measurement is 4 labelled documents; does not meet the sample-size bar for strong).

## 2026-09-20 · adversarial review round 2 (fix verification) and fixes

Two second-pass reviews are archived verbatim in this directory:
`adversarial-review-2026-09-20-pass2-gpt-5.6-sol.md` and
`adversarial-review-2026-09-20-pass2-gpt-6-astra.md` (prompt:
`adversarial-review-pass2-prompt.md`). Both verified the round-1 fixes and both reached the same
top finding: the round-1 "verdict as asked" repair had created records with two verdicts — a body
saying **no** under frontmatter saying `conditional` — so metadata retrieval answered a different
question from the prose. Both also found evidence attached to designs it did not measure. Applied
below.

### 1. As-asked / proposal conflicts split into two entries each

Each pair is now: a new `30-anti-use-cases/` entry answering the literal question with
`verdict: no`, plus the existing use-case entry retitled to the proposal it actually describes,
carrying `verdict_as_asked` in frontmatter and a Verdict paragraph whose first sentence names the
literal question and points at the anti-use-case.

| New anti-use-case (verdict) | Existing entry: title and verdict change |
|---|---|
| `au-straight-through-claim-payment-decision` (no) — 30-anti-use-cases/straight-through-claim-payment-decision.md | `uc-insurance-straight-through-vs-adjuster-routing`: "Route a claim to straight-through processing or a human adjuster on confidence" -> "Flag claims to remove from straight-through processing"; verdict conditional (unchanged) + `verdict_as_asked: no` |
| `au-reviewer-assignment-replacing-codeowners` (no) — 30-anti-use-cases/reviewer-assignment-replacing-codeowners.md | `uc-sdlc-reviewer-and-label-routing`: "Suggest reviewers and labels for a change by its meaning rather than its file paths" -> "Label a change by meaning and suggest one additional reviewer beside the required ones"; verdict conditional (unchanged) + `verdict_as_asked: no` |
| `au-shell-command-safety-hook-gate` (no) — 30-anti-use-cases/shell-command-safety-hook-gate.md | `uc-agents-harness-pre-tool-use-destructiveness`: "Score how destructive a shell command is before a coding agent runs it" -> "Add a confirmation prompt when a shell command looks destructive, inside the deterministic controls"; verdict conditional (unchanged) + `verdict_as_asked: no` |
| `au-invoice-three-way-match-by-jev` (no) — 30-anti-use-cases/invoice-three-way-match-by-jev.md | `uc-verification-invoice-three-way-match`: "Match an invoice to its purchase order and contract, with every amount compared in code" -> "Advise on the invoice lines a deterministic three-way match could not clear"; verdict conditional (unchanged) + `verdict_as_asked: no` |
| `au-churn-prediction-from-tickets` (no) — 30-anti-use-cases/churn-prediction-from-tickets.md | `uc-support-churn-risk-signal`: "Extract a churn-risk signal from support conversations" -> "Extract churn-signal features from support messages for a downstream risk model"; verdict conditional (unchanged) + `verdict_as_asked: no` |
| `au-semantic-predicate-in-hot-query` (no) — 30-anti-use-cases/semantic-predicate-in-hot-query.md | `uc-data-ml-semantic-predicates-in-sql`: "Expose jev as a SQL function so a query can ask a semantic question about a row" -> "Materialise a jev answer as a column with SQL, rather than calling it in a live predicate"; verdict good (unchanged) + `verdict_as_asked: no` |
| `au-ai-authorship-detection` (no) — 30-anti-use-cases/ai-authorship-detection.md | `uc-media-content-ai-writing-slop-detection`: "Flag AI-writing tells and prose defects across a corpus for a human editor" -> "Flag concrete prose defects across a corpus for a human editor"; verdict conditional (unchanged) + `verdict_as_asked: no` |

Reviewer routing additionally de-escalated an over-correction both reviews flagged (Astra, Major:
"Over-correction assumes all reviewer selection is CODEOWNERS lookup"). The split now distinguishes
**required ownership** — CODEOWNERS is authoritative, jev must never pick, remove or satisfy a
required approver: `no` — from **advisory suggestion of one additional expert reviewer** where
ownership is unspecified: `conditional`. The unsourced "removing the boring 80%" coverage promise
was removed from that entry's alternatives.

### 2. Re-evidenced the strong entries (6 -> 4)

- `uc-trust-safety-spam-phishing-atomic-signals`: **strong -> good**. The 98.64% on 5,733 messages
  (bitnovus/jev-spam-eval) was measured on a three-way ham/spam/phishing **Choice** with enriched
  evidence, not on the weighted-Noul decomposition the entry prescribes; the decomposition is
  unmeasured and the entry now says so in the Verdict and in Numbers. "No published accuracy for
  spam" -> "no first-party accuracy ... Independent: ..." with the result, its shape and its label
  provenance. https://github.com/bitnovus/jev-spam-eval promoted from a body bullet to a
  frontmatter source and added to the Sources section.
- `uc-search-retrieval-rrf-fusion-with-dense-retriever`: **strong -> good**. The measured
  implementation (zhuyansen/jev-search-rerank-eval) was **batched `Score` reranking, one API call
  per query**, not one Noul per pair; the primitive sketch was rewritten to the measured design and
  the Noul-per-pair variant is now explicitly labelled unmeasured for fusion. Demotion reason
  recorded in the Verdict: only **30 of 164 queries were hand-adjudicated**, the rest carry
  model-written labels. Removed "Any internal evaluation where jev both ranks and judges should be
  discounted by roughly that much"; the +0.053 / -0.028 circularity figures are kept as a single
  measurement on one corpus. Fixed "pairwise questions cannot share a call".
- `uc-search-retrieval-rerank-keyword-shortlist`: stays **strong**, scoped. First sentence now reads
  "strong for the measured recipe: one `Noul` per pair, 30 calls per query, legal retrieval over a
  weak keyword shortlist". Fixed "pairwise questions cannot share a call" (they can, given a state
  structured to hold several candidates — the measured recipe simply did not). Added CLERC label
  provenance (n = 40; the gold passage is the precedent the excerpt actually cited, documentary
  ground truth, not human adjudication and not model labels).
- `uc-search-retrieval-confidence-fallback-broader-level`: stays **strong**. Numbers now state
  sample size and label provenance explicitly (n = 60 filings; labels are the filers' own EDGAR SIC
  codes, pre-existing and human-authored, pre-filtered by the cookbook). Fixed "jev ships calibrated
  probabilities" -> "returns probabilities trained to be calibrated (measure it on your data —
  independent ECE 0.045 to 0.242 by dataset)".
- `uc-agents-harness-skill-or-tool-selection`: stays **strong**. Numbers now state n = 488 over a
  182-skill roster and that requests and labels are **synthetic** (written by Claude Sonnet 5 from
  each skill's own `SKILL.md`, correct by construction, easier than real traffic).
- `uc-data-ml-text-features-for-tabular-model`: stays **strong**. Numbers now state n = 800 held-out
  rows and that the target is the reviewer's own published 80-98 score (human, pre-existing, not
  synthetic), plus the missing TF-IDF/embedding baseline.

Qualifying-measurement URLs were confirmed present in frontmatter `sources` for all four remaining
strong entries.

### 3. FAQ (`df-faq`)

- Method step 1: air-gapped / on-premises / offline requirement is now **`no`**
  (`au-air-gapped-or-self-hosted`), and only other governance gaps cap at *conditional pending
  governance*.
- Method step 7: "Always name the low-confidence path" -> "where an answer drives an action, name
  the low-confidence path; where answers are features or advisory rankings, say how uncertainty is
  consumed instead".
- Dual-display rows added or rewritten for every split entry: straight-through claims, reviewer
  routing, shell-command safety, invoice matching, churn, SQL predicates, AI-writing. The SQL row
  now reads "**no in a hot query; good as materialisation**"; the AI-writing row is split into an
  authorship row (`no`) and a prose-defect row (`conditional`).
- Verdict words updated for the two demotions (spam, RRF) and the three strong rows now carry sample
  size and label provenance in the reason column; the rerank row is scoped to the measured recipe.
- Tiny-volume row no longer concludes "no economic case" from item count alone: it now says to price
  reading time, error cost, backlog and latency, and allows a conditional pilot.
- "Questions the corpus cannot answer" per-language line now reports the Korean measurements that do
  exist (mahlernim/jev-korean-benchmark, 100 items per condition, ±8-point margin: Belebele 96 KO
  against 97 EN; KorMedMCQA 80 against gpt-5.6-luna's 88) instead of "Only that English is primary".

### index after these fixes

`python3 scripts/build_index.py jev` reports **233 entries — strong 4, good 94, conditional 36,
weak 14, no 50** (plus 35 non-verdict entries: ground truth, decision framework, cookbooks), zero
PROBLEM lines. Seven anti-use-case entries were added by this round. These totals are a snapshot of
this commit; regenerate rather than quote them.

### Round 2, part B (residue and design fixes across entries)

- Calibration residue: 36 edits; "has calibrated confidence" -> "probabilities trained to be calibrated;
  measured on your data"; comparative claims against alternatives rewritten to "no typed per-item
  probability unless logprobs are read".
- Abstention residue: 11 edits; abstention stated as a developer-defined threshold policy any
  probability-returning model can implement; 34.7% vs 2.7% framed as a coverage trade-off from one study.
- "Mid-tier accuracy": 3 edits -> mid-table agreement with a two-model reference.
- Zero-latency claims: 22 edits -> low incremental latency ("barely changes").
- Consistency-superiority claims: 10 edits scoped to the tested configuration with the Haiku 4.5
  temperature-0 counter-result.
- SDE-cascade text removed from model-difficulty-routing and replaced with router-specific failure
  handling; extraction-field-verification no longer calls `{}` a fail-safe default.
- Seven invented monthly/annual dollar totals removed; per-call cost and formula kept.
- Design fixes: contract-clause absence bounded by retrieval coverage; compaction predicate that could
  not see its evidence removed; commitlint syntax vs message-vs-diff semantics separated; open-web
  navigation compounding relabelled as a policy assumption; tiny-volume reasoning made conditional on
  effort per item; alternatives compared as equivalently thresholded implementations.
- Failure-mode line added to 35 entries that named none (8 use cases, 27 anti-use-cases, of which 15
  are deployment / economic / governance vetoes rather than model failures).
- Framework: fit-test rerank example reconciled with the entry (strong for the measured legal-retrieval
  recipe, conditional beyond it); schema gained the optional `verdict_as_asked` field; index excludes
  50-sources/ so archived reviews are not retrieved as guidance.
