---
id: draft-community-use-cases
title: Community use cases and anti-use cases for jev (research draft)
status: draft — input for 20-use-cases/ and 30-anti-use-cases/
last_verified: 2026-09-19
jev_version: jev-1.13.0
note: >
  Verdicts below are SUGGESTIONS for the writers of 20-use-cases and 30-anti-use-cases,
  using the schema scale (strong/good/conditional/weak/no) and evidence levels
  (official-cookbook > official-docs > independent-benchmark > community-report > inferred).
  "community-report" means someone built it and said it worked; it is not a measurement.
---

# Use cases people actually built or evaluated

## A. Support, inbox and triage

1. **Signup spam filtering** — probability a new signup is spam, advisory then enforced after 100 logged rows. Integration: signup handler write path. Numbers: $0.042/MTok, ~600 ms, $1/packet spend cap. https://github.com/Nishfleet/0509/issues/3542 — *good, community-report*
2. **Support-inbox department + urgency triage** — Choice for department, Score for urgency, Noul for frustration. Same issue as above; also the canonical pattern in Anil-matcha's list. https://github.com/Anil-matcha/awesome-jev-by-typesafe — *strong, community-report* (official cookbook likely exists; check 40-cookbooks)
3. **Email spam / phishing three-way classification** — ham vs spam vs phishing with enriched evidence (Reply-To, link hostnames, attachments). 98.64% on 5,733 msgs vs TF-IDF 98.87%; 98.38% phishing recall; 95.31% on 2024-25 phishing; ~$1.35 for 19,772 requests. https://github.com/bitnovus/jev-spam-eval — *strong, independent-benchmark*
4. **Email intent routing (invoice vs general inquiry)** — LangGraph workflow. https://github.com/GiesN/typesafe-jev-workflow — *good, community-report*
5. **Booking-inquiry routing across 4 languages** — 60 synthetic cases, 3 rounds, vs gpt-4o-mini and claude-sonnet-4.5; main run ~$0.03 vs ~$0.62. Single annotator, synthetic data. https://github.com/Shogo-nfrealmusic/jev-eval — *conditional, community-report*
6. **Reply-bot intent classification** — one of 5+ decision points in the Genfeed typed-decision epic; ≤600 ms budget, 0.85 default confidence threshold, every migration must carry its own labelled set. https://github.com/genfeedai/genfeed.ai/issues/4863 — *good, community-report*
7. **Alert-worthiness / digest gating** — Score 0-3 "worth_alert" to fix alert fatigue (551 → 18 monthly alerts). Advisory only. https://github.com/Nishfleet/0509/issues/3539 — *good, community-report*
8. **Brand-mention ingest labelling** — is_about_brand, sentiment, category, self/competitor, all stored with probabilities behind a flag; mentions under 0.5 brand confidence flagged but retained. https://github.com/Nishfleet/0509/issues/3536 — *good, community-report*

## B. Model, tool and skill routing

9. **LLM difficulty-tier routing (NeMo Switchyard)** — 4 tiers, 40 calls, 0.643–0.674 s median, $0.000025/call vs Gemini 3.5 Flash 2.1 s and DeepSeek V4 Flash 7.2 s. No accuracy measured. https://dev.classmethod.jp/en/articles/jev-for-llm-model-routing/ — *good, community-report*
10. **Confidence-threshold routing Jev → frontier fallback** — Banking77: threshold 0.67, 80.2% acc, −53% cost, p50 302 ms, 11.6% escalation. Web of Science: no threshold beat the single best model. https://github.com/FirasSX914/Janus — *conditional, independent-benchmark* (condition: fit the threshold per dataset)
11. **Cheapest-capable-model routing for coding turns** — https://github.com/gargpratyush/jev-router, https://github.com/prismhq/jev-router, https://github.com/0xNatoshi/jev-codex-router — *good, community-report*
12. **Per-request routing for the Pi agent** — https://github.com/mejiasd3v/pi-jev-router, https://github.com/jekozyra/pi-typesafe-router — *good, community-report*
13. **Claude model + reasoning-effort selection per message** — https://github.com/adarshmishra07/jcm-router — *good, community-report*
14. **Agent skill suggestion from a large installed catalog** — 136 skills (Empryo), shipped; also https://github.com/GodsBoy/jev-agent-skill-router. https://empryo.com/blog/jev-and-the-harness — *strong, community-report*
15. **HTTP semantic routing middleware** — https://github.com/yusukebe/hono-jev-router — *good, community-report*
16. **Policy-bounded model tiering** — https://github.com/iamvatsalpatel/tiershift, https://github.com/nidhi-singh02/agent-router — *good, community-report*
17. **Tool selection ahead of the LLM (100 mocked tools, distractors, Portuguese prompts)** — measures steps-to-completion vs LLM picking. Numbers not published in README. https://github.com/vinilana/jev-eval-agent — *conditional, community-report*
18. **Typed function/tool dispatch over a closed argument set** — https://github.com/Anil-matcha/awesome-jev-by-typesafe — *good, community-report*
19. **Difficulty-based subagent delegation** — https://github.com/aaronshaf/opencode-jev-orchestrator — *good, community-report*

## C. Search, ranking and retrieval

20. **Reciprocal-rank fusion of Jev scores with a dense retriever** — rrf(bge-m3, jev@30) NDCG@10 0.864 vs bge-m3 0.774, +0.064 even under independent labels; ~$0.0002/query. https://github.com/zhuyansen/jev-search-rerank-eval — *strong, independent-benchmark*
21. **Reranking a weak keyword ranker's top-30** — Jev beat bge-m3 by +0.060 when the candidate list came from the shipped keyword ranker. Same source — *good, independent-benchmark*
22. **General-purpose reranking as a Cohere/zerank substitute** — 0.692 NDCG@10 vs Cohere Rerank 4 Pro 0.691 at $0.45 vs $2.51 per 1k queries. https://github.com/anessbelbati/jev-rerank-bench — *good, independent-benchmark*
23. **Negation-sensitive reranking** — 71% vs Cohere 67% on NevIR pairs. Same source — *good, independent-benchmark*
24. **Search re-ranking inside an agent harness (shipped, shadow/apply modes)** — https://empryo.com/blog/jev-and-the-harness — *strong, community-report*
25. **RAG passage relevance + contradiction filtering** — official cookbook exists (classifying_rag_passages); community adapter https://github.com/WiktorB2004/llama-index-jev — *strong, official-cookbook*
26. **Semantic code search / function-match ranking** — https://github.com/sufianetaouil/every, https://github.com/ellipsis-dev/blink, https://github.com/kyu1204/jgrep — *good, community-report*
27. **Shell-history ranking** — https://github.com/mrnugget/jev-shell-history — *good, community-report*
28. **Skill/plugin catalog ranking** — https://github.com/Dicklesworthstone/skillranker — *good, community-report*
29. **Web-search source selection and result ranking** — https://github.com/superagents-lab/jev-search — *good, community-report*
30. **Wikipedia link-path search by ranking** — https://github.com/komikat/jev-bfs — *weak, community-report* (graph search belongs in code)

## D. Guardrails, gates and verification

31. **Shell-command safety scoring before execution** — 44/44 on 24 block / 20 allow, 375–402 ms, $0.00001–0.00004. https://github.com/shiftynick/jev-axi — *strong, community-report*
32. **Prompt-injection / canary detection in tool results** — flags at directed ≥0.6; hidden-div curl caught at p=0.99; 662 skills scanned with no false flags (max legit 0.74). https://github.com/leepokai/jev-guard — *good, community-report*
33. **Destructive-action approval guard in a UI agent** — shipped in Empryo, 800 ms timeout then fallback. — *strong, community-report*
34. **Tool-call gate for a coding agent** — https://github.com/y0usaf/pi-jev, https://github.com/Nyarlathoteppppp/pi-heed, https://github.com/vercel-labs/fx — *good, community-report*
35. **Pre-commit / pre-push diff screening** — https://github.com/AkashPriyadarshii/jev-git; message↔diff alignment, blocks only on credential detection https://github.com/valentynkit/jev-commit — *good, community-report*
36. **CI PR triage (ready / needs_human / broken)** — one batched Choice+Noul call, fails only when readiness==broken AND confidence or high_risk ≥0.8; skipped when the key is absent so forks stay green. https://github.com/learn-ukrainian/learn-ukrainian.github.io/issues/8232 + PR 8233 — *conditional, community-report* (condition: advisory or high-threshold only)
37. **CI failure triage before auto-rerun (RUNNER-GONE / CONCURRENCY-BLOCKED / flaky / real)** — advisory-first, $0.042/MTok, ~600 ms, $1/packet cap. https://github.com/Nishfleet/fleet-ops/issues/7392 — *good, community-report*
38. **API error transient-vs-permanent triage** — 102/102 vs GPT-5.6 Terra 102/102 (1,387 ms, $0.0025) and Claude Haiku 4.5 101/102. Caveat: the fixed regex also scores 102/102 for free. https://empryo.com/blog/jev-and-the-harness — *conditional, independent-benchmark*
39. **Security-finding triage and rebuttal gating** — Jev priors are display-only and "cannot dismiss findings"; 428 tests pass on Linux. https://github.com/SathiaAI/adversarial-review/pull/69 — *conditional, community-report*
40. **Supply-chain "is this package malicious" screening** — https://github.com/luantak/is-malicious — *good, community-report*
41. **Agent "done" claim verification (Stop hook)** — https://github.com/valentynkit/jev-belay, https://github.com/noplan-inc/limpet, https://github.com/thruwire/foreman — *conditional, community-report* (false negatives are the risk; see anti-use case 8)
42. **Project-rule / preference linting against a diff** — https://github.com/doeixd/jev-pref, https://github.com/coldteadotai/abide, https://github.com/Kelbie/hunch, https://github.com/lakeday-org/perch — *good, community-report*
43. **Prose linting (ten Boolean conditions per paragraph)** — https://github.com/DanRWilloughby/snifftest — *good, community-report*
44. **Deferral detection in review text** — 94% vs 33% for the existing lexical scanner on 18 sentences. https://github.com/bestdan/workflow-skills/pull/757 — *good, community-report*
45. **Skill-description collision detection** — zero collisions across 22+ runs over 16 descriptions. Same PR — *good, community-report*
46. **Redundancy detection in PR review comments** — 7 of 8 on real cases. Same PR — *good, community-report*
47. **Confidence-as-tampering-tripwire** — injected authority claims collapsed margins 1.000 → 0.05–0.24; unusable as a correctness gate, usable to detect pressure. Same PR — *conditional, community-report* (novel; flag to writers)
48. **Content moderation with an abstain band** — Discord scoring + escalation https://github.com/brainstormity/Jev-Moderation-Bot; Mastra input processor https://github.com/CodeAlive-AI/mastra-jev-moderation — *good, community-report*

## E. Evals, judging and observability

49. **Rubric scoring as a cheap LLM-judge replacement** — 6,003 checks: $160/M verdicts at 91.5% agreement with Claude Fable 5.1, vs Fable $33,000/M, GPT-5.6 Luna $400/M, DeepSeek V4.1 Flash $260/M at 93.5%. https://langfuse.com/blog/2026-09-18-using-typesafes-jev-for-evals — *good, independent-benchmark*
50. **Judge every trace, sample failures to an LLM judge** — the hybrid Arize recommends. https://arize.com/blog/typesafe-jev-llm-judge/ — *good, community-report*
51. **AI-writing / slop detection across a corpus** — 37 docs × 21 questions = 777 judgments in <0.7 s for ~$0.0025; Dan Shipper's run caught 6/7 planted defects vs Fable 7/7. https://every.to/also-true-for-humans/mini-vibe-check-typesafe-s-jev-judged-everything-i-ve-written-in-0-7-seconds; https://github.com/TKY-27/JevSlop — *conditional, community-report*
52. **User-disagreement detection in chat traces** — Langfuse worked example — *good, community-report*
53. **Multi-dimension feature extraction feeding a small trained model** — +9.0 pt on weak-cue classification, +7.0 pt on Japanese NLI (8,000 rows), 40.0% → 91.1% on a 7,008-row ledger task; $0.042/1k rows for 12 dimensions. https://agentjournal.dev/blog/llm-judge-vs-feature-extraction/ — *strong, independent-benchmark*
54. **Confidence-threshold fitting per question** — needs ~100+ labelled rows per question; reports accepted accuracy, coverage, ECE. https://github.com/abhixhek/jevcal — *strong, community-report*
55. **Agent-trace observability: permission and completion review** — https://github.com/qkal/Canny, https://github.com/different-ai/openwork — *good, community-report*

## F. Data, documents and extraction

56. **Structured extraction over a known, bounded field set** — https://github.com/Anil-matcha/awesome-jev-by-typesafe — *conditional, official-docs* (bounded fields only; see anti-use case 3)
57. **Citation / claim verification against sources** — official cookbook `citation_check`; community https://github.com/MarissaFamularo/citation-verifier — *strong, official-cookbook*
58. **Synthetic-dataset curation (filter JSONL/Parquet rows)** — https://github.com/AkashPriyadarshii/jev-curate — *good, community-report*
59. **Tax / IRS form-type classification** — https://github.com/kyotofin/tax-doc-classifier — *conditional, community-report*
60. **Invoice matching against POs, contracts and prior invoices** — note TypeSafe's own invoice number is 61.8% vs Terra 74.7% (pearpages) — *conditional, official-docs*
61. **Semantic filtering and ranking inside SQL** — Postgres https://github.com/kylemclaren/jevql, https://github.com/realZachi/pg-jev, https://github.com/giuliosmall/pg_typesafe; DuckDB https://github.com/colliber/duckdb-jev; SQLite https://github.com/mgaitan/sqlite-jev — *good, community-report*
62. **ORDER BY over Jev probabilities on topic membership** — ECE 0.045, inversion 0.036, passes gates on 20 Newsgroups. https://github.com/yodablocks/jev-orderby-bench — *conditional, independent-benchmark* (passes on easy membership only; see anti-use case 5)
63. **OpenTelemetry log triage** — https://github.com/reachjalil/jevlogs — *good, community-report*
64. **Hierarchical / high-cardinality classification via staged Choices** — https://github.com/reachjalil/jev-tree — *good, community-report*
65. **Knowledge-graph entity alignment and deduplication** — HN commenter vintermann's genealogy matching case (100,000² pairs makes per-pair LLM infeasible; blocking still required per RobinL). https://news.ycombinator.com/item?id=49717558 — *conditional, community-report*
66. **Commit-message / diff classification** — https://github.com/devanshbatham/commit-miner — *weak, community-report* (62.9% agreement, overconfident by 16 pts — bestdan PR 757)

## G. Agent context management

67. **Tool-history pruning / compaction** — https://github.com/tamaratran/fast-jev-compaction, https://github.com/joelhooks/pi-fast-jev-compaction, https://github.com/compozy/yoshi, https://github.com/GhalebDweikat/winnow, https://github.com/Nyarlathoteppppp/pi-jev-context — *conditional, community-report* (publicly contested; Theo: "This is a terrible compaction strategy" https://x.com/theo/status/2100762304862384257)
68. **Wake/sleep gating for long-running agents** — https://github.com/shitianfang/wakegate — *good, community-report*
69. **Deciding how much conversation history to keep** — https://github.com/compozy/yoshi — *conditional, community-report*

## H. Browser, device and real-time control

70. **Browser action selection from a DOM/accessibility tree** — 9.450 s → 7.092 s median (25%), protocol calls 1,092 → 101, 3/3 passes. Small LLM writes text only for TYPE_TEXT. https://github.com/browser-use/jev-ultrafast — *good, community-report*
71. **Jev + reasoning-model pairing in a browser benchmark** — Jev + Mercury 2.5 among 21 configs over 49 tasks / 3,087 attempts; WebMCP configs beat all screen-driving approaches. https://github.com/nekuda-ai/WindTunnel — *conditional, independent-benchmark*
72. **Ad / clutter element removal in the page** — https://github.com/kitze/unclutter, https://github.com/realZachi/typesafe-adblock — *good, community-report*
73. **YouTube sponsor-segment detection from captions** — 77% of crowd-marked sponsor seconds, 34 s/hour false positives, $0.0008/video, 0.9 s; weaker on non-English captions. https://github.com/valentynkit/jev-skip — *conditional, community-report*
74. **Home Assistant household questions and voice routing** — ~$0.0001/command at 20 entities, ~$0.0007 at 150; latency worse than published from Europe. https://github.com/AboveColin/HA-Jev — *conditional, community-report* (author excludes locks, heaters, alarms)
75. **Android / mobile action selection from accessibility trees** — https://github.com/antiyro/jevdroid, https://github.com/droidrun/mobile-jev — *good, community-report*
76. **Robot arm action selection (SO-101)** — https://github.com/grmkris/robo-harness — *conditional, community-report*
77. **Quadrotor tactical decisions at 2.5 Hz with control in code** — https://github.com/RomanSlack/jev-drone — *conditional, community-report*

## I. Domain applications

78. **CV / candidate screening against an editable policy** — https://github.com/gtaras7/typesafe-jev — *conditional, community-report*
79. **PR risk routing before review** — https://github.com/raihankhan-rk/diffjury — *good, community-report*
80. **Stance and substance scoring of public-consultation documents (Norwegian)** — stance 20/24 (tie with DeepSeek V4.1 Flash off), substance 19/24 vs 14/24, $0.22 vs $1.31/1k docs, p50 0.32 s vs 2.7 s. https://lindfors.no/blog/a-first-look-at-typesafes-jev/ — *conditional, independent-benchmark*
81. **Event-listing moderation** — 96% vs Gemini Flash-Lite 86%, "58x cheaper per decision", 85 vs 910 tokens (reported via Arize; nearhere.events returns 403). https://arize.com/blog/typesafe-jev-llm-judge/ — *good, community-report* (primary source unverified)
82. **Page / SEO section grading** — https://github.com/kitze/pagegrade, https://github.com/AkashPriyadarshii/jev-seo — *good, community-report*
83. **Startup-idea evaluation** — https://github.com/monteduro/killmyidea — *weak, community-report*
84. **Clinical/medical multiple choice** — KorMedMCQA 80 vs Luna 88; MedQA 89 vs 84. https://github.com/mahlernim/jev-korean-benchmark — *weak, independent-benchmark* (sample check only, ±8 pts)
85. **Federal motion-to-dismiss outcome forecasting** — 91 cases, Cycle 1; Jev results not yet published. https://github.com/johnhughes3/LegalForecastBench — *inferred* (no numbers yet)
86. **Security incident / SOC triage pipelines** — 7 SOC stages implemented; author warns thresholds are not production-ready and "a wrong but valid label is still possible". https://github.com/kenhuangus/jev-usecases — *conditional, community-report*
87. **Game-state action selection with legal moves generated in code** — Mario https://github.com/fhshaik/typesafe-mario; StarCraft https://github.com/phyous/tsai-sc; Pokémon Red https://github.com/valentynkit/jev-plays-pokemon-red (~1.3 decisions/s, median 621 ms, ~$0.14/hr) — *conditional, community-report*

---

# Candidate anti-use cases

1. **Ranking raw grep lines / single text lines.** Top-3 accuracy fell 78.6% → 74.1%; lexical position beat semantics because one line carries too little context. https://empryo.com/blog/jev-and-the-harness — *no*
2. **Predicting the next tool call from the initial prompt.** Keyword counting on the prompt beat Jev 26% vs 15% and beat frontier models too; intent only emerges after inspection. Same source — *no*
3. **Open-ended extraction from unbounded text (NER, schema-templated extraction).** System One needs a bounded, known answer set. Explicit don't-adopt. https://github.com/qte77/doc-pipeline-engine/issues/196 — *no*
4. **Standalone reranking on top of a good dense retriever.** −0.028 NDCG@10 under independent labels; use RRF fusion instead. https://github.com/zhuyansen/jev-search-rerank-eval — *weak*
5. **Graded commercial product relevance / ORDER BY on e-commerce search.** ESCI: ECE 0.242, inversion 0.255, 23/30 queries over threshold, "Complement" ranked below "Irrelevant". https://github.com/yodablocks/jev-orderby-bench — *no*
6. **Error-code classification where a regex already exists.** Fix the regex: digit-bounding `429` took the free classifier from 98/102 to 102/102, matching Jev at zero cost. https://empryo.com/blog/jev-and-the-harness — *weak*
7. **Sole blocking safety gate in CI.** "Never blocking, never mandatory"; adding network calls and secrets breaks a hermetic check. https://github.com/bestdan/workflow-skills/pull/757 — *no*
8. **Pass/fail verdict on a code review loop.** 60% agreement (12/20) on ambiguous cases; false negatives unacceptable for verification. https://empryo.com/blog/jev-and-the-harness — *no*
9. **Any decision that is really arithmetic.** Task-scope forecasting hit 40/40 only once counts were restated numerically — "at which point it is arithmetic". Also official jaggedness modes 2 and 3 (math, dates). https://github.com/bestdan/workflow-skills/pull/757 — *no*
10. **Counting characters or tokens.** 117/216 correct across spacing variants; the letter 'r' in "raven" miscounted 18/18. https://github.com/RINNECODER/jev-behavior-study — *no*
11. **Date ordering / recency comparison.** Official jaggedness: "Reads dates as text, not as ordered quantities." https://docs.typesafe.ai/model-jaggedness/jev-1.13 — *no*
12. **Game-theoretic optimal play / any task with a solver.** 63% agreement over 30 solved spots; chose all-in 62% on the nuts where the solver checks 100%. https://backnotprop.com/blog/jev-poker/ — *no*
13. **Long multi-hop logical chains.** 32-link tasks 7/18 vs 8-link 12/18; jaggedness mode 4 (indirection). https://github.com/RINNECODER/jev-behavior-study — *no*
14. **Anything requiring an explanation or audit trail.** No chain of thought, "nothing to read that explains why". Arize, Langfuse, DataCamp, HA-Jev all say it independently. — *no*
15. **Text generation, summarisation, code writing.** Jaggedness mode 9; Langfuse: "entirely unsuitable". Also 7 of fdsimms' 15 features. https://github.com/fdsimms/todo/issues/2781 — *no*
16. **Image, audio, video or PDF-page input.** Not supported; 5 of fdsimms' 15 features needed images. Same source — *no*
17. **Air-gapped or self-hosted deployments.** API-only, no open weights, no published SLA. https://github.com/qte77/doc-pipeline-engine/issues/196 — *no*
18. **Workloads needing zero data retention outside enterprise.** ZDR is enterprise-only; that plus a real sub-second requirement were the two conditions fdsimms set before reconsidering. https://github.com/fdsimms/todo/issues/2781 — *conditional at best*
19. **Reusing a confidence threshold across datasets.** Banking77 said ROUTE at 0.67; Web of Science said DO NOT ROUTE. "A default threshold would therefore be wrong roughly as often as it was right." https://github.com/FirasSX914/Janus — *conditional* (refit per dataset)
20. **Trusting confidence as a correctness gate.** "Useless as correctness gate"; commit-type classification 62.9% correct at 0.79 mean confidence. https://github.com/bestdan/workflow-skills/pull/757 — *no*
21. **Sole defence against prompt injection.** Injected authority claims collapsed decision margins from 1.000 to 0.05–0.24; jaggedness mode 6 says adversarial content "can move the answer"; jev-guard's own README: "Not a sandbox … Jev can be wrong." — *no*
22. **Decomposing into many dimensions when a single question already works.** 37.2% vs 1.5% false positives on 339 hard-benign security documents; synthetic B2B replies 98.0% vs 100%. https://agentjournal.dev/blog/llm-judge-vs-feature-extraction/ — *weak*
23. **High-cardinality intent routing where an LLM is affordable.** Banking77 (77 classes): 0.78 vs GPT-5.6 Terra 0.85. https://github.com/4esv/jev-eval — *conditional* (only if the 6.7-pt gap is affordable)
24. **Fine-grained emotion classification.** DAIR Emotion 0.480 with Brier 0.846 (worse than GLiNER2.5's 0.668). https://github.com/AbdelStark/jev-benchmarks — *weak*
25. **Non-English captions / weakly-resourced text without a per-language check.** jev-skip: "non-English captions perform weaker"; Korean medical −8 vs Luna; Norwegian tokenises at 2.06 chars/token vs ~2.5 English, raising cost. — *conditional*
26. **Safety-critical home automation (locks, heaters, alarms) and tight control loops.** The integration author's own exclusion list. https://github.com/AboveColin/HA-Jev — *no*
27. **Genealogy / entity matching without blocking.** 100,000² pairs is infeasible regardless of per-call cost; HN commenters agree blocking strategies remain mandatory. https://news.ycombinator.com/item?id=49717558 — *conditional*
28. **Compaction of agent context.** Publicly contested as a strategy; no measured retention/quality numbers found. https://x.com/theo/status/2100762304862384257 — *weak*
29. **Replacing a reconciler that needs reasoning.** "The co-review-reconciler needs reasoning Jev cannot do, so Jev must not replace it." (surfaced via search over bestdan/workflow-skills assessment) — *no*
30. **Dismissing security findings.** Explicitly designed against: "Jev output cannot dismiss findings." https://github.com/SathiaAI/adversarial-review/pull/69 — *no*
31. **Trusting an eval where Jev is both system and judge.** Self-preference measured at up to +0.081 NDCG@10 swing. https://github.com/zhuyansen/jev-search-rerank-eval — *no*
32. **Deployments that cannot tolerate waitlist/rate-limit risk.** API outage at launch (TechCrunch), 507 waitlist complaints in 12,759 posts (openchamber), calibration study cut short by rate limiting (jev-plays-pokemon-red). — *conditional*
33. **Fetching agent instructions unpinned from an upstream repo.** Supply-chain / prompt-injection risk in the official skill. https://github.com/jon-devlapaz/jev-me/issues/7 — *no*

## Gaps for the writers

- No source found measuring jev against a **fine-tuned encoder trained on in-domain data** (only TF-IDF, GLiNER2.5 and BM25). The spam eval's learning-curve estimates (~100 / ~200 / ~10,000 labels) are the closest proxy.
- No independent **multi-turn or production-scale reliability** data. Forkast: "No named production customers or revenue disclosed."
- **nearhere.events** (96% vs Gemini Flash-Lite 86%) could not be verified at source — 403. Cited only via Arize.
- **LegalForecastBench** Cycle 1 results not yet published.
- **jev-eval-agent** and **jev-eval (Shogo)** publish methods but not headline numbers in the README.
