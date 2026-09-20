---
id: gt-evidence-independent
title: Independent evidence base for jev (non-TypeSafe sources)
evidence_level: independent-benchmark
decision_shapes: [classification, detection, scoring, routing, ranking, verification, extraction, search, feature-extraction]
primitives: [choice, score, noul]
last_verified: 2026-09-19
jev_version: jev-1.13.0
sources:
  - https://openchamber.dev/blog/jev-typesafe-ai/  (12,759-tweet survey; median 7x speed / 30x cost vs claimed 193x / 444x)
  - https://github.com/wotai-dev/typesafe-jev-tools  (149-row head-to-head vs Claude Haiku 4.5; abstention gap)
  - https://empryo.com/blog/jev-and-the-harness  (8 harness jobs, 5 shipped, 3 rejected; regex bug)
  - https://github.com/zhuyansen/jev-search-rerank-eval  (33,047-entry rerank eval; judge-circularity bias)
  - https://github.com/bitnovus/jev-spam-eval  (spam/phishing vs TF-IDF)
  - https://github.com/yodablocks/jev-orderby-bench  (pre-registered ranking gates; ESCI failure)
  - https://github.com/4esv/jev-eval  (Banking77 / SST-5 / IMDB vs GPT-5.6 Terra)
  - https://github.com/AbdelStark/jev-benchmarks  (vs fastino/gliner2.5-multi-v1)
  - https://github.com/FirasSX914/Janus  (routing thresholds do not transfer across datasets)
  - https://github.com/mahlernim/jev-korean-benchmark  (Korean vs English)
  - https://github.com/RINNECODER/jev-behavior-study  (framing / position sensitivity, 11,621 requests)
  - https://github.com/anessbelbati/jev-rerank-bench  (14 datasets vs Cohere Rerank 4, zerank-2)
  - https://lindfors.no/blog/a-first-look-at-typesafes-jev/  (24 Norwegian documents, calibration)
  - https://agentjournal.dev/blog/llm-judge-vs-feature-extraction/  (single judge call vs 12-14 dimensions)
  - https://backnotprop.com/blog/jev-poker/  (solver-verified negative result)
  - https://github.com/bestdan/workflow-skills/pull/757  (7 decision points assessed; injection tripwire)
  - https://github.com/abhixhek/jevcal  (threshold-fitting tool; states the customer agreement restricts publishing jev performance numbers)
  - https://typesafe.ai/legal/mca  (first-party: MCA §2.3(f) prohibits publishing benchmarks or performance information)
  - https://arize.com/blog/typesafe-jev-llm-judge/  (aggregation of early independent tests)
  - https://news.ycombinator.com/item?id=49717558  (launch thread, 498 comments)
related: [gt-failure-modes, gt-evals-official, gt-limits-pricing-versions]
---

## Scope

Everything below is from sources outside TypeSafe AI, read 2026-09-19, four days after launch
(2026-09-15). Treat all of it as early: the largest independent labelled run found is 19,772 API
requests (spam), the largest head-to-head is 1,617 scored questions (reranking), and almost every
author says "first look, not a benchmark". Nothing here is peer reviewed.

## Measured benchmarks

| Source | Task | n | Jev result | Compared against (verbatim) | Measured outcome |
|---|---|---|---|---|---|
| bitnovus/jev-spam-eval | 3-way ham/spam/phishing, enriched evidence | 5,733 msgs | 98.64% acc; 98.38% phishing recall | TF-IDF logistic regression trained on ~4,600 labels/fold: 98.87% | Matched a TF-IDF logistic-regression baseline trained on ~4,600 labels per fold, zero-shot: 98.64% vs 98.87% |
| bitnovus/jev-spam-eval | binary spam | 18,514 msgs | 98.33% (106 missed, 203 FP) | TF-IDF LR 98.39%; 50/50 ensemble 99.22% | 98.33% vs 98.39%; the 50/50 ensemble scored highest at 99.22% |
| bitnovus/jev-spam-eval | text-only (no enrichment) | 5,733 | 93.62%; 85.71% phishing recall | enriched TF-IDF 98.87% | Removing the enrichment cost 5.02 points of accuracy (98.64% -> 93.62%) and 12.67 points of phishing recall |
| 4esv/jev-eval | Banking77 intent, 77 classes | 300 | 0.78 acc, 0.20s, $0.04/1k | GPT-5.6 Terra 0.85, 1.04s, $2.02/1k | 6.7 points below Terra on 77-class intent, 5.2x faster, ~50x cheaper |
| 4esv/jev-eval | SST-5 sentiment | 300 | 0.57 | GPT-5.6 Terra 0.59 | 0.57 vs 0.59 |
| 4esv/jev-eval | IMDB polarity | 300 | 0.97 | GPT-5.6 Terra 0.97 | 0.97 vs 0.97 at $0.04 vs $2.02 per 1k |
| AbdelStark/jev-benchmarks | AG News / Banking77 / DAIR Emotion | 300 | 0.910 / 0.870 / 0.480 | fastino/gliner2.5-multi-v1: 0.700 / 0.610 / 0.440 | Higher accuracy on all three; worse Brier on Emotion, 0.846 vs 0.668 |
| wotai-dev/typesafe-jev-tools | "does this decision need an LLM?" | 149 rows, 2026-09-18 | 66.0% acc, ECE 0.121, p50 455 ms, abstains 34.7% | Claude Haiku 4.5: 66.0%, ECE 0.122, 631 ms, abstains 2.7% | Accuracy equal (66.0% both), ECE within 0.001, abstention rate 34.7% vs 2.7% |
| wotai-dev/typesafe-jev-tools | business categorisation / commit classification | (secondary) | 79.9% / 50.0% | Claude Haiku 4.5 83.2% / 42.0% | 79.9% vs 83.2% on categorisation; 50.0% vs 42.0% on commit classification |
| zhuyansen/jev-search-rerank-eval | rerank 33,047 skills, 164 zh/en queries, 9,831 graded pairs | 164 queries | jev-score(bge-m3@30) NDCG@10 0.785; **rrf(bge-m3, jev@30) 0.864** | bge-m3 0.774; bm25 0.633; ash-0.4.0 0.609 | Standalone jev rerank +0.011 NDCG@10 over bge-m3; rrf fusion +0.090 |
| zhuyansen (same) | judge-circularity check | same | jev-rerank minus bge-m3 = **−0.028 [−0.052, −0.004]** under Haiku-only labels; +0.053 under Jev-only labels | Claude Haiku 4.5 as independent judge | The sign of the rerank gain flips with the judge: -0.028 under Haiku labels, +0.053 under jev labels |
| anessbelbati/jev-rerank-bench | 8 English IR datasets | 1,617 questions | Jev rubric NDCG@10 0.692, 74% top-pick, $0.45/1k | Cohere Rerank 4 Pro 0.691 @ $2.51/1k; zerank-2 0.682 @ $0.22/1k | 0.692 vs 0.691, CI −0.009..+0.012, at $0.45 vs $2.51 per 1k |
| anessbelbati (same) | NevIR negation pairs | subset | 71% | Cohere Rerank 4 Pro 67% | 71% vs 67%; subset size not stated |
| yodablocks/jev-orderby-bench | 20 Newsgroups ORDER BY | 360 labelled rows | ECE 0.045, inversion 0.036 — passes pre-registered gates | none (gates, not models) | Both pre-registered gates passed (ECE 0.045, inversion 0.036) |
| yodablocks (same) | Amazon ESCI product relevance | 306 pairs | ECE 0.242, inversion 0.255 — **fails**; 23/30 queries over threshold | same gates | Both gates failed (ECE 0.242, inversion 0.255); 23/30 queries over threshold |
| FirasSX914/Janus | confidence routing Jev→DeepSeek v4 Pro | 500 + 500 | Banking77: threshold 0.67, 80.2% (+1.4 pt), −53% cost, p50 302 ms, 11.6% escalation. Web of Science: **"DO NOT ROUTE"** | DeepSeek v4 Pro fallback | The 0.67 threshold was fitted on Banking77; the same procedure on Web of Science returned "DO NOT ROUTE" |
| mahlernim/jev-korean-benchmark | Belebele / PAWS-X / MedQA vs KorMedMCQA | 100 per condition | EN 97 / 80 / 89; KO 96 / 76 / 80 | gpt-5.6-luna: 98 / 83 / 84 (EN), 95 / 72 / 88 (KO) | KO minus EN for jev: −1 / −4 / −9; on KorMedMCQA jev 80 vs Luna 88. Author states ±8 points at n=100 |
| lindfors.no | Norwegian hearing responses, stance + substance | 24 docs | stance 20/24, substance 19/24, $0.22/1k docs, p50 0.32 s; 0.9+ bin agreed 14/15 | DeepSeek V4.1 Flash: 20/24 & 14/24 (off), 22/24 (reasoning on), $1.31–$3.08/1k, 2.7 s / 26 s | Stance 20/24, equal to DeepSeek with reasoning off; substance 19/24 against 14/24 (off) and 22/24 (on). 14/15 agreement on 24 documents; too small to establish calibration |
| iammrduncan/typesafe-ai-benchmark | 7 synthetic scenes, 100-item batches | ~700 | p50 176 ms, p95 336 ms, $0.01 | Qwen 3.8 27B on Cerebras: 215/452 ms, $0.31; Needle 3 local | p50 176 ms vs 215 ms, $0.01 vs $0.31; pairwise agreement 75–100% in both directions; no ground-truth labels |
| agentjournal.dev | single judge question vs 12–14 dimensions | 200 / 300 / 8,000 / 7,008 rows | synthetic B2B 100% vs 98.0% (single wins); weak-cue 64.7% → 74.0%; Japanese NLI 83.7% → 90.8%; ledger 40.0% → 91.1% | itself, both configurations | Dimensions scored above the single call on three of four datasets and below it on synthetic B2B (98.0% vs 100%) |
| agentjournal.dev | hard-benign security docs | 339 | dimensions flag **37.2%** vs direct call **1.5%** | itself | 24.8x the false-positive rate of the single call on this set |
| RINNECODER/jev-behavior-study | framing and position sensitivity | 11,621 requests | "5-minute walk"→"5-minute drive" moved correct answers 0/20 → 20/20; correct option first 95/108 vs fourth 62/108; counting 'r' in "raven" wrong 18/18 | itself | Measured effect sizes: 0/20 -> 20/20 on a one-word change; 95/108 vs 62/108 by answer position |
| backnotprop.com | Texas hold'em spot selection | 30 solved spots | matched solver top action 63%; on a nut hand chose all-in 62% (16/16 runs) where solver is 100% check | TexasSolver at 0.59% exploitability | 63% agreement with solver-verified ground truth; 16/16 runs chose all-in on a spot the solver checks 100% of the time |
| openchamber.dev | survey of public reports | 12,759 tweets, 3,105 from people who tried it | median speed-up **7x** (Q1 2x, Q3 20x, n=215); median cost reduction **30x** (Q1 5x, Q3 85x, n=180); median latency 76 ms (n=333) | TypeSafe homepage 193.6x / 444.6x | Medians 7x / 30x against the homepage's 193.6x / 444.6x. Survey limitations, stated by the authors: only 3,105 of 12,759 posts (24%) came from people classified as having tried jev; the speed medians rest on 215 figures and the cost medians on 180; distinguishing trial from production use was "the least reliable judgement, with 64% agreement against manual labels" and was excluded from usage counts; "This is a survey of public reports, not an independent benchmark. We did not rerun the experiments." (https://openchamber.dev/blog/jev-typesafe-ai/) |

Two design facts to record alongside the numbers. Only one source measures **judge circularity**:
in the rerank eval the jev-rerank gain over bge-m3 is +0.053 when jev supplies the relevance labels
and −0.028 when Claude Haiku 4.5 supplies them, on the same 164 queries
(https://github.com/zhuyansen/jev-search-rerank-eval). Only one source pre-registered its pass/fail
gates before scoring: the orderby bench, which ran the same primitive and the same model version on
two datasets and measured ECE 0.045 on 20 Newsgroups topics and 0.242 on Amazon ESCI product
relevance (https://github.com/yodablocks/jev-orderby-bench).

The spam eval states its own supervision cost: its author writes that "no task-specific fitting is
not no supervision" — the detailed criteria that lifted Jev from 93.62% to 98.64% came out of
labelled error analysis, and the enrichment (Reply-To, link hostnames, attachment metadata) was
engineering rather than model capability. Its learning-curve estimate: TF-IDF needs roughly 10,000
labels to match Jev on the 18,514-message binary task, ~200 on Ling-Spam, ~100 on the three-way
text-only task (https://github.com/bitnovus/jev-spam-eval).

## Field reports with numbers

**Empryo harness (ProxySoul, 2026-09-16)** — https://empryo.com/blog/jev-and-the-harness. Eight jobs
tested, five shipped: skill suggestion over 136 installed skills, search re-ranking, failure triage,
an action-approval guard, and a UI pilot. Failure triage: Jev 102/102, latency 70–300 ms (median
260–273), $0.00002 per decision, against GPT-5.6 Terra 102/102 at 1,387 ms and $0.00250, Claude Haiku
4.5 101/102 at 602 ms and $0.00125, and Union Alpha 96/97 at 8,685 ms. The original regex baseline
scored 98/102; the four failures were `429` matching inside `text_editor_20250429`. Digit-bounding the
status code brought the free deterministic classifier to 102/102, at zero cost and zero latency
(https://empryo.com/blog/jev-and-the-harness).

**dev.classmethod.jp (Morinaga Taishi, 2026-09-17)** — *(exact article URL not captured; domain
dev.classmethod.jp)*. Jev as the classifier in NVIDIA NeMo Switchyard model routing. 40 calls, 10 per
tier. Median 0.643–0.674 s, $0.000025–0.000027 per call, confidence 1.0 on simple/complex/reasoning
tiers and 0.57–0.67 on the medium tier. Against "Gemini 3.5 Flash" (2.1 s, $0.70/session) and
"DeepSeek V4 Flash" (7.2 s). Never integrated into Switchyard; no accuracy benchmark at all. Latency
evidence only.

**Every (Mike Taylor, 2026-09-15)** — *(exact article URL not captured; domain every.to)*. 37
documents × 21 questions = 777 judgments in under 0.7 s for about $0.0025. Dan Shipper's companion
run: 4 writing checks over 12 passages, Jev 0.35 s average vs Fable 5.1 at 8.83 s (~25x), ~580x
cheaper, Jev caught 6 of 7 planted defects and Fable caught 7. The miss was an "unexplained action",
missed across three attempts. No ground truth beyond the authors' own judgement.

**Langfuse (Annabell, 2026-09-18) citing Good Start Labs** — *(exact article URL not captured; domain
langfuse.com)*. 6,003 rubric checks: Jev $160 per million verdicts agreeing with Claude Fable 5.1
91.5% of the time; Fable 5.1 $33,000/M; GPT-5.6 Luna $400/M; DeepSeek V4.1 Flash $260/M at 93.5%
agreement. Agreement with Fable 5.1 is not accuracy, and the cheaper LLM agreed more.

**jev-axi (shiftynick)** — https://github.com/shiftynick/jev-axi. 44 labelled tool calls (24 block,
20 allow): 44/44. 375–402 ms, $0.00001–0.00004 per call. On a 390k-line repo the file-ranking skill
"showed inconsistent results across sessions (appearing as either 25% savings or 29% penalty)" and
agents rarely invoked it unprompted.

**jev-guard (leepokai)** — https://github.com/leepokai/jev-guard. 21-call calibration run: p50
~580 ms, ~$0.00004 per tool call. Scanned 662 installed skills, none flagged, highest legitimate
score 0.74; injected hidden-div curl flagged at p=0.99. No false-positive/negative rate published.

**jev-skip (valentynkit)** — https://github.com/valentynkit/jev-skip. 23 videos: catches 77% of the
sponsor seconds SponsorBlock's crowd marked, 34 seconds/hour of false positives, $0.0008 per video,
0.9 s. Explicitly: "non-English captions perform weaker."

**HA-Jev (AboveColin)** — https://github.com/AboveColin/HA-Jev. Home Assistant. Reports latency
"slower from Europe than the published 70 to 500 ms"; ~$0.0001 per voice command at 20 exposed
entities rising to ~$0.0007 at 150. Author's own guidance: not for locks, heaters, alarms, or tight
loops.

**jev-plays-pokemon-red (valentynkit)** — https://github.com/valentynkit/jev-plays-pokemon-red. ~1.3
decisions/sec, median 621 ms (mean 759, n=6, range 479–1470), ~$0.14/hour at ~725 input tokens/call.
Calibration deliberately unpublished: "n=5 turns with wide confidence intervals" under rate limiting.

**TechCrunch (Tim Fernholz, 2026-09-18)** — *(exact article URL not captured; domain techcrunch.com)*.
Vercel's Pranit Sharma replacing "ChatGPT Luna 5.6" for safety classification: "5 to 18 times" faster
with greater accuracy. Bryo AI's Nikhil Mudholkar on business email classification vs Gemini: "10 to
20 times" less expensive — "it is the only one that hands back a real probability." These are
self-reported vendor-adjacent anecdotes, not measurements.

**jevcal (abhixhek)** — https://github.com/abhixhek/jevcal. A confidence-threshold fitting tool. It
publishes no jev performance numbers, and its README states the reason verbatim: *"TypeSafe's
customer agreement restricts publishing performance numbers for Jev, so this README contains none, on
purpose."* That is one tool author's account, and the underlying clause is first-party and verifiable.
TypeSafe's Master Customer Agreement, section 2.3 ("License Restrictions"), opens *"Customer will not
do (and will not attempt to do), and will not allow Customer Applications, or any of Customer's
directors, officers, employees, agents or contractors to do, any of the following:"* and lists at
**(f) "publish benchmarks or performance information about the Services"**
(https://typesafe.ai/legal/mca, accessed 2026-09-20). What follows for the evidence base — that
unfavourable independent results are under-reported — is an **inference**, not a measurement; it is
recorded under "Reviewer interpretation". The same README gives two other figures: *"A threshold is
only as good as your sample. Under ~100 labeled rows per question, expect it not to hold"* and *"The
API returns probabilities rounded to two decimals, and identical requests can occasionally return a
different answer."*

## Negative results and rejected use cases

- **Lost to lexical position.** Empryo dropped Jev from ordering raw grep lines: top-3 accuracy fell
  from 78.6% to 74.1% (https://empryo.com/blog/jev-and-the-harness).
- **Lost to keyword counting.** Empryo's next-tool-call prediction: "keyword counting on the prompt
  outperformed both Jev (26% vs. 15%)" and frontier models (https://empryo.com/blog/jev-and-the-harness).
- **Lost to a hardened regex.** Empryo's failure triage: once the `429` digit-boundary bug was fixed
  the free classifier matched Jev at 102/102 and zero cost (https://empryo.com/blog/jev-and-the-harness).
- **Lost to a good embedding ranker.** Standalone Jev reranking is −0.028 NDCG@10 against bge-m3 under
  independent labels; only reciprocal-rank fusion improved on bge-m3, at +0.090
  (https://github.com/zhuyansen/jev-search-rerank-eval).
- **Failed a pre-registered ranking gate.** Amazon ESCI: ECE 0.242, inversion 0.255, and the
  "Complement" grade ranked *below* "Irrelevant" (https://github.com/yodablocks/jev-orderby-bench).
- **Failed against a solver.** 63% agreement with GTO on 30 spots and a 62% all-in on the nuts where
  the solver checks 100% (https://backnotprop.com/blog/jev-poker/).
- **Failed a verification gate.** Empryo's review-loop pass/fail: 60% agreement (12/20) on ambiguous
  cases; the author reports false negatives as unacceptable for that gate (https://empryo.com/blog/jev-and-the-harness).
- **Overconfident on commit type.** bestdan/workflow-skills: 62.9% agreement at 0.79 mean confidence
  — "overconfident by 16 points", with `feat` misread as `fix` 18 times in 43 misses
  (https://github.com/bestdan/workflow-skills/pull/757).
- **Arithmetic re-entered by the back door.** Same PR, task-scope forecasting: restating counts
  numerically hit 40/40 "at which point it is arithmetic, so rule 4 gives it to code"
  (https://github.com/bestdan/workflow-skills/pull/757).
- **Prompt injection moves the answer.** Same PR: "Injection attacks via plausible authority claims
  collapsed margins from 1.000 to 0.05–0.24", and their stated conclusion is that confidence is
  "useless as correctness gate" but "sharply responsive to injected pressure", i.e. usable as a
  *tampering tripwire*, not a correctness gate (https://github.com/bestdan/workflow-skills/pull/757).
  This matches the official jaggedness mode "Adversarial content … can move the answer."
- **Decomposition backfires on benign-looking security text.** 37.2% false-positive rate vs 1.5% for
  a single question on 339 hard-benign documents
  (https://agentjournal.dev/blog/llm-judge-vs-feature-extraction/).
- **Framing and option order dominate.** 0/20 → 20/20 on a one-word change; 95/108 vs 62/108 by answer
  position; counting failures 117/216 (https://github.com/RINNECODER/jev-behavior-study).
- **Non-determinism.** 4esv measured 1.7–3.3% label variance across runs
  (https://github.com/4esv/jev-eval); bestdan saw confidence swing 0.16–0.48 between runs on the same
  item (https://github.com/bestdan/workflow-skills/pull/757); jevcal's README states "The API returns
  probabilities rounded to two decimals, and identical requests can occasionally return a different
  answer" (https://github.com/abhixhek/jevcal).
- **Explicit don't-adopt decisions.** `qte77/doc-pipeline-engine#196`
  (https://github.com/qte77/doc-pipeline-engine/issues/196, 2026-09-19) records "don't
  adopt": proprietary API-only, no self-hosting or open weights, conflicts with an air-gapped local
  design goal, and the pipeline needs open-ended extraction rather than bounded label sets.
  `fdsimms/todo#2781` (https://github.com/fdsimms/todo/issues/2781, 2026-09-17) concluded "no
  integration now": of 15 AI features, 5 need images
  (Jev cannot), 7 generate text (Jev cannot), and the 2 that fit already had solutions; the two
  conditions that would flip it are zero-data-retention on all tiers (currently enterprise-only) and
  a genuine sub-second latency requirement. `betmoar/cc-operator-plugin#151`
  (https://github.com/betmoar/cc-operator-plugin/issues/151) framed a probe with a kill condition and
  listed Jev's counting, date and state-size limits as directly in the way.
  `SocialGouv/iterion#1316` (https://github.com/SocialGouv/iterion/issues/1316) will not touch code
  until independent calibration evidence exists.
- **Availability.** TechCrunch: the company "briefly lost the ability to serve users from its API
  because demand was so high" *(exact article URL not captured; domain techcrunch.com)*. The
  openchamber survey counted 507 waitlist complaints against 13 price complaints
  (https://openchamber.dev/blog/jev-typesafe-ai/). jev-plays-pokemon-red's calibration study was cut
  short by rate limiting (https://github.com/valentynkit/jev-plays-pokemon-red).
- **Supply chain.** `jon-devlapaz/jev-me#7` (https://github.com/jon-devlapaz/jev-me/issues/7) flags
  that the official skill instructs agents to fetch an unpinned `main`-branch SKILL.md from
  `typesafe-ai/skills` before the first call.

## Community critique themes

**"Can't hallucinate" is a category error.** The dominant HN theme. jacobgold: *"it can still emit a
completely wrong valid value. You can enforce structured output from an LLM too."* 8note: *"if it
puts a high confidence value on a wrong answer, thats still hallucinating, no?"* resonious: *"maybe
we should stop saying 'can't hallucinate' when it can by definition."* TrueFoundry, in print: *"A
model constrained to three allowed categories can still confidently pick the wrong one."*
(https://news.ycombinator.com/item?id=49717558, https://www.truefoundry.com/blog/typesafe-ai-jev)

**Calibration is asserted, not shown.** elil17: *"If the value is 0.9 for 1000 different answers, then
approximately 900 of those answers should be correct."* ActivePattern asked for exactly the eval that
would matter: *"What % of decisions can we automate to achieve 90% accuracy?"* Pere Pages names the
missing artefact — a calibration curve "from someone other than TypeSafe". devthejo
(SocialGouv/iterion#1316) calls calibration "the only claim that matters". The three independent
calibration numbers that do exist disagree by task: ECE 0.045 (newsgroups), 0.121 (decision triage),
0.242 (ESCI).

**Circular evals.** TypeSafe's own numbers "compare model outputs against reference probabilities
from other models, rather than human-labeled ground truth" (Arize). Pages: "two-frontier-model
consensus". The rerank eval put a number on the same problem for community evals.

**It's a switch statement / you're building an LLM out of if statements.** The most-viewed critical
post (590,000 views) called Jev *"a really smart switch statement"*
(https://x.com/NathanFlurry/status/2100036101809619314). bigglebear on HN: *"you're building an LLM
out of if statements"*, and *"If you don't perfectly represent the distributions of possible answers
then you'll likely get garbage results."*

**Glue-layer ergonomics.** leobuskin: *"this is a wild hybrid of code logic, textual definitions, and
AI blackbox … the 'glue' layer is too boilerplate-ish."*

**The demos are cooked.** bigglebear on the Home Assistant / Doom demos: *"the enemies must be being
served to the model as coordinates … So they've severely cooked this."*

**Reproducibility.** bigglebear predicted a week; a replica appeared in two hours. ramoz pointed at
GLiClass as an existing open zero-shot classifier "in the same ballpark". By 2026-09-19 the awesome
lists carry 15+ open reimplementations (openjev, NanoJev, Laya, kev, jevlike, LitJev, SemIf, reflex,
Verdict-open-jev). NanoJev (0.6B, Qwen3-0.6B backbone) reports 95% (19/20) on 4×4 navigation and a
50×50 maze solved in 244 attempts with 36 collisions against "Jev's 2,738 attempts with 1,044
collisions" — self-reported, task-specific, and worth treating as category evidence only. openjev's
author states plainly: "No matched performance comparison against Jev … has been completed."

**No explanation.** Universal. Arize: System One models produce "much less directional signal of how
to improve." Langfuse adds two more: forced answers with no abstention option in their setup, and
"context rot" — accuracy drops with irrelevant input, which is jaggedness mode 5.

**Privacy and locality.** VladVladikoff on HN: *"I don't really want to bounce all my home automation
commands to the cloud."* Two of the four don't-adopt decisions cite hosting/retention.

## Adoption and distribution signals

Jev is listed on Vercel AI Gateway as `typesafe-ai/jev` behind AI SDK
7's `experimental_evaluate` with Zero Data Retention and No Training options (changelog 2026-09-16);
on Cloudflare Workers AI as `typesafe/jev` with a documented 32,000-token context; and on OpenRouter
as `typesafe/jev-1.13`. LangChain shipped a `TypeSafeClassifier` plus routing and AutoMode
middlewares (Runkle & Lovell, 2026-09-17). Langfuse and Arize both published evaluator integrations
within three days.

Ecosystem breadth: yibie/awesome-jev lists 100+ projects across routing (17), verification and
guardrails (16), scoring and ranking (10), agent decisions (21), evaluation (12), calibration and
open replicas (16), SDKs and infra (28), games (6), finance (3), moderation (3);
cobanov/awesome-jev and AbdelStark/awesome-typesafe add community SDKs for Go, Rust, Java, Scala,
Elixir, Ruby, R, Haskell and Swift plus Postgres, DuckDB, SQLite and n8n extensions. TypeSafe raised
$40M seed led by DCVC at roughly $200M valuation (Forkast, 2026-09-17); the HN launch thread reached
1,902 points and 498 comments. Forkast states: "No named production customers or revenue disclosed."

Counter-signal on breadth, from the openchamber survey's own stated limitations
(https://openchamber.dev/blog/jev-typesafe-ai/): 26,896 tweets were collected and 12,759 retained;
only 3,105 of those (24%, from 2,172 unique accounts) came from authors classified as having tried
Jev; the speed medians rest on 215 figures, the cost medians on 180 and the latency median on 333;
labelling reached "98% agreement on 50 manually labelled tweets" overall but only "64% agreement
against manual labels" on distinguishing a one-off trial from production use, which the authors
therefore excluded from usage counts; and 4.3% of posts were explicitly negative against 507 waitlist
complaints. The authors' summary: "This is a survey of public reports, not an independent benchmark.
We did not rerun the experiments."

## Reliability of each source

| Source | Type | Sample size | Bias risk |
|---|---|---|---|
| bitnovus/jev-spam-eval | independent benchmark, reproducible | 19,772 requests / 5,733 + 18,514 msgs | Medium — criteria tuned on labelled errors; public corpora may be in pretraining |
| zhuyansen/jev-search-rerank-eval | independent benchmark, artefacts frozen | 164 queries, 9,831 pairs | Low-medium — measures its own judge bias; only 30 hand-adjudicated queries; 80/164 queries Chinese |
| yodablocks/jev-orderby-bench | pre-registered gates | 360 + 306 rows | Low — gates set before scoring; single English domain |
| anessbelbati/jev-rerank-bench | independent benchmark | 1,617 questions, 14 datasets | Medium — BM25 top-30 candidates only, 2,000-char truncation, no multiple-comparison adjustment |
| 4esv/jev-eval | independent benchmark | 900 rows | Medium — single run, single machine, no prompt tuning |
| AbdelStark/jev-benchmarks | independent pilot | 300 held-out | Medium-high — pilot scale, hosted vs local latency not normalised |
| wotai-dev/typesafe-jev-tools | tool + benchmark by the tool's author | 149 rows | High — author built a hook that recommends Jev |
| FirasSX914/Janus | routing study | 2 × 500 | Medium — ECE/Brier mentioned but not tabulated |
| mahlernim/jev-korean-benchmark | sample check | 100/condition | High — author states ±8 points; two medical exams not comparable |
| RINNECODER/jev-behavior-study | synthetic probe | 11,621 requests | Medium — synthetic tasks; post-hoc design decisions disclosed |
| lindfors.no | first look | 24 documents | High — n=24, reference labels from one frontier model |
| agentjournal.dev | independent experiment | 15,508 rows total | Medium — hand-written dimensions; noisy Japanese NLI labels |
| empryo.com | vendor field report (harness author) | 8 jobs, 102-item triage set | Medium — ships the integration, but publishes its 3 rejections and its own regex fix |
| backnotprop.com | adversarial probe with ground truth | 30 spots | Medium — narrow domain, solver ground truth is genuine |
| bestdan/workflow-skills#757 | internal assessment, merged | 16 skills / 18 sentences / 43 commits | Medium — small n per test, but reports rejections and injection results |
| dev.classmethod.jp | latency field report | 40 calls | High — no accuracy measurement, not integrated |
| every.to | field report | 777 judgments | High — no ground truth beyond author judgement |
| Langfuse / Good Start Labs | vendor-integration post | 6,003 rubric checks | High — agreement with Fable 5.1 is not accuracy |
| Arize | aggregation + commentary | secondary | Medium — states it has not run its own benchmark yet |
| openchamber.dev | survey of public posts | 12,759 tweets | High — explicit selection bias, no reruns; 98% label agreement on 50 tweets |
| news.ycombinator.com#49717558 | discussion | 498 comments | High — opinion, not measurement; founder participates as CompleteSkeptic |
| TechCrunch / Forkast / DataCamp | press | n/a | High — vendor-sourced numbers; DataCamp says so explicitly |
| yibie / cobanov / AbdelStark awesome lists | indexes | 100+ entries each | Medium — inclusion is not validation |

## Reviewer interpretation

Everything above this heading is measurement or quotation. The judgements below are the corpus
editor's, not the sources'.

- The rerank eval and the orderby bench are the two most careful designs here, because each
  anticipated a specific failure: one measured the bias of its own judge, the other fixed its
  pass/fail gates before scoring. The rerank eval is the reason to be suspicious of any evaluation in
  which jev grades its own output — on that one task, with those labels, the measured gain was +0.053
  under jev-supplied labels and −0.028 under Haiku-supplied labels. That is a single measurement on a
  single task; it is not a correction factor to apply elsewhere. Where it matters, measure the judge.
- The orderby bench is the clearest evidence that "it passed on my data" does not transfer: same
  primitive, same model version, ECE 0.045 on one dataset and 0.242 on another.
- The spam eval is the strongest positive result collected here, and the most explicit about what it
  cost to get: the lift from 93.62% to 98.64% came from labelled error analysis and evidence
  enrichment, not from the model. Read its learning curve as saying jev buys a cold start rather than
  a ceiling.
- The Empryo harness report is the most instructive field report collected here, because the value it
  delivered was a bug found in the incumbent regex rather than a replacement for it.
- The lindfors.no calibration observation (14/15 in the 0.9+ bin) is too small to support any
  calibration claim either way; it is reported here only because so few independent calibration
  numbers exist.
- **Inference, not measurement:** the evidence base is probably biased towards favourable results.
  TypeSafe's Master Customer Agreement §2.3(f) prohibits customers from "publish[ing] benchmarks or
  performance information about the Services" (https://typesafe.ai/legal/mca), and at least one tool
  author says this is why their repository carries no numbers. Nothing here measures how much evidence
  that clause suppresses, or in which direction; the expectation that suppressed results skew
  unfavourable is a judgement, not a finding.

## Sources

All accessed **2026-09-19**; the 18 primary sources are in the frontmatter. Also cited inline, same
access date: techcrunch.com (09-18), forkast.news (09-17), datacamp.com (09-16), truefoundry.com,
pearpages.com (09-16), latent.space AINews, langchain.com (09-17), langfuse.com (09-18), every.to
(09-15), dev.classmethod.jp (09-17); vercel.com changelog (09-16), Cloudflare Workers AI model page,
OpenRouter listing; GitHub repos shiftynick/jev-axi, leepokai/jev-guard, valentynkit/jev-skip,
AboveColin/HA-Jev, valentynkit/jev-plays-pokemon-red, iammrduncan/typesafe-ai-benchmark,
nekuda-ai/WindTunnel, browser-use/jev-ultrafast, kenhuangus/jev-usecases, devagrawal09/jev-code,
zhihz/openjev, TianyuCodings/NanoJev, and the four awesome lists; GitHub issues
genfeedai/genfeed.ai#4863, Nishfleet/fleet-ops#7392, Nishfleet/0509#3536/#3539/#3542,
learn-ukrainian.github.io#8232 (+PR 8233), SathiaAI/adversarial-review#69,
qte77/doc-pipeline-engine#196, fdsimms/todo#2781, betmoar/cc-operator-plugin#151,
SocialGouv/iterion#1316, microsoft/SkillOpt#283, jon-devlapaz/jev-me#7. First-party, cited only for
the nine jaggedness modes: docs.typesafe.ai/model-jaggedness/jev-1.13.
