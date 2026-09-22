---
id: df-faq
title: FAQ and routing table — "should I use jev for X?" answered in one line, with the entry to read next
last_verified: 2026-09-20
jev_version: jev-1.13.0
sources:
  - index.json  (every entry id, path, verdict and summary in this corpus; the routing table below is generated against it)
  - 10-decision-framework/fit-test.md  (Question 0 eligibility gate, the seven fit questions, the counter-signals)
  - 10-decision-framework/rewrites.md  (the labelled rewrite for each task jev cannot do directly)
related: [df-fit-test, df-rewrites, df-alternatives, df-cost-model, df-rollout]
---

## How to answer any "should I use jev for X?" question

1. Start with **Question 0** from `df-fit-test`: may this service be used here at all? Jev is a hosted, US-hosted, early-access API with dynamic rate limits, enterprise-only zero data retention, no published SLA and no self-hosted build. Distinguish two kinds of failure here. A hard incompatibility — an air-gapped, on-premises or offline requirement — is a **`no`**: no self-hosted or open-weights build is documented, so there is nothing to evaluate (`au-air-gapped-or-self-hosted`). Every other governance gap (ZDR tier, DPA, residency, SLA, rate limits) caps the verdict at *conditional pending governance* whatever the task looks like.
2. Then run the **seven fit questions**: text input after code has filtered it; a bounded decision (Choice, Score, Noul); semantic and single-hop; an instruction a literal reader gets right; code keeps the loop and the side effects; an acceptable low-confidence path; and volume, latency or brittleness that makes the incumbent painful.
3. Look up the closest entry in the table below and open it. The entry, not this file, carries the state shape, the numbers with sources, and the conditions that flip the verdict.
4. Answer **for the question as asked**, verdict word first — strong, good, conditional, weak, or no.
5. If a rewrite exists, offer it afterwards as a separate, labelled proposal with its own verdict ("as asked: no; as a Choice over candidates your regex found: conditional"). Never let a rewrite silently soften a "no"; `df-rewrites` has the table.
6. Never claim jev is more accurate or more consistent than the incumbent. Accuracy is claimable only where a named source measured that task, and run-to-run repeatability is not a differentiator.
7. Where an answer drives an action, name the low-confidence path — human, coarser label, second question, or bigger model. Where answers are features for a downstream model or advisory rankings, there is no branch to name: say instead how uncertainty is consumed (as a column the model sees, as a sort key, as a review-queue filter). Either way, always name **what stays in code**: arithmetic, dates, lookups, filters, thresholds, side effects, and any authoritative safety, money or legal rule.
8. Close with how to find out: a shadow-mode trial against the incumbent on your own labelled rows, thresholds fitted on that sample, before anything acts. See `df-rollout`.

## Quick answers by question

Verdict words are copied from each entry's frontmatter. Open the entry before quoting anything from this table.

### Support and triage

| People ask | Verdict | One-line reason | Entry id |
|---|---|---|---|
| "Can jev route inbound tickets to the right team?" | good | TypeSafe's own worked `triage_ticket` Choice teaches this shape; no labelled accuracy published, so shadow-run it | uc-support-ticket-team-routing |
| "Should we use TypeSafe to set priority instead of our `URGENT!!` rule?" | good | Urgency is intent; a keyword list encodes vocabulary and keeps growing | uc-support-urgency-detection |
| "Can jev tell which billing tickets are asking for money back?" | good | One Noul on the message; the refund itself stays a code-owned action | uc-support-refund-request-detection |
| "Is jev good at choosing between code, an LLM, and a human?" | good | Bounded handler set, with code owning dispatch and the confidence floor | uc-support-intent-routing-handlers |
| "Replace our sentiment API for how angry a customer is?" | good | A rubric you wrote beats a vendor's label — rank and threshold on it, never read it as a magnitude | uc-support-frustration-scoring |
| "Can jev predict churn from support tickets?" | **no as asked; conditional for churn-signal features** | Churn depends on usage, billing, tenure and renewal dates, none of which is in the ticket. Conditional for the rewrite: jev reads what the customer *said*, a trained model or a rule computes the risk | au-churn-prediction-from-tickets / uc-support-churn-risk-signal |
| "Can jev write the one-line summary for the agent?" | no | Generation. Let jev decide a summary is needed and an LLM write it | au-generate-ticket-summaries |
| "Should we use TypeSafe to draft the reply?" | no | No primitive emits prose a person reads | au-write-customer-replies |
| "Eight applications a week, a manager reads each — add jev?" | weak | Low volume weakens the *automation* case, but item count alone does not settle it: price the reading time, the error cost, the backlog and the latency first. A conditional pilot is reasonable where eight items consume hours of expert attention | au-tiny-volume-human-reviewed-workflow |

### Trust and safety

| People ask | Verdict | One-line reason | Entry id |
|---|---|---|---|
| "Can jev catch the phishing our filter misses?" | good | The 98.64% over 5,733 messages (phishing recall 98.38%, TF-IDF baseline 98.87%) was measured on a three-way **Choice**, not on the weighted-Noul decomposition the entry prescribes; the decomposition is unmeasured. No first-party accuracy exists | uc-trust-safety-spam-phishing-atomic-signals |
| "Can jev replace Perspective API for toxicity?" | good | You write the community standard instead of inheriting one; removal stays code's call | uc-trust-safety-toxicity-harassment-detection |
| "Should we use TypeSafe to decide allow / warn / review / block?" | good | Severity Score plus hazard Nouls, with the ladder and thresholds owned by code | uc-trust-safety-policy-violation-bands |
| "Can jev triage the moderation report queue?" | good | Queue choice is reversible and advisory; auto-closure is not | uc-trust-safety-user-report-triage |
| "Score new signups for spam from the registration form?" | good | Metadata you already store is text; a blocklist is always a week behind | uc-trust-safety-signup-spam-scoring |
| "Can jev replace our PII scanner?" | conditional | Detecting exposure fits; listing the actual values is free-form extraction | uc-trust-safety-pii-exposure-detection |

### Search, retrieval and RAG

| People ask | Verdict | One-line reason | Entry id |
|---|---|---|---|
| "Can jev re-rank our BM25 results?" | strong | Strong for the measured recipe — one Noul per pair, 30 calls/query, legal retrieval over a weak keyword shortlist: CLERC, 40 queries, top-1 5% → 18%, top-10 38% → 62%. It reorders the shortlist and cannot add what retrieval missed | uc-search-retrieval-rerank-keyword-shortlist |
| "Will a jev rerank improve our bge-m3 vector search?" | good | Measured over 164 queries and 9,831 graded pairs: `rrf(bge-m3, jev@30)` NDCG@10 0.864 against bge-m3's 0.774, while standalone reranking lost ground under independent labels. Good rather than strong: only 30 of the 164 queries were hand-adjudicated, and the measured implementation was batched Score reranking, one call per query | uc-search-retrieval-rrf-fusion-with-dense-retriever |
| "What do we do with the half the classifier is unsure about?" | strong | Measured on 60 10-K filings (labels are the filers' own EDGAR SIC codes, pre-filtered to filings whose text supports them): a 0.9 cutoff splits them in half, the unsure half is right 12/30 at group level, and reporting one level up turns 40% into 70% | uc-search-retrieval-confidence-fallback-broader-level |
| "Can jev drop the poisoned chunk before our RAG prompt?" | good | Relevance, premise conflict and injection as separate Nouls per passage | uc-search-retrieval-rag-passage-gating |
| "Is jev good at finding the clause that answers my question?" | good | Line-by-line Nouls return a quotable location, not a generated answer | uc-search-retrieval-semantic-find-in-document |
| "Classify query intent before we run the query?" | good | Intent is a small closed set; the routing table stays in code | uc-search-retrieval-query-intent-classification |
| "Can we drop the vector database and rank with jev?" | weak | Cost and latency are linear in candidates, and a strong dense retriever is not the part to remove | au-replace-vector-retrieval-with-jev-rerank |
| "Rerank the lines `ripgrep` returned?" | weak | Lexical match; one harness measured top-3 accuracy falling from 78.6% to 74.1% | au-grep-line-ranking |
| "We have 40k tokens — can we just put the whole document in state?" | no | Context rot: accuracy falls as irrelevant material grows | au-whole-document-in-state |
| "Can our 4,000-leaf taxonomy be one Choice?" | no | Choice caps at 255 options; use the hierarchical beam search | au-flat-choice-over-255-options |

### Agents, tools and harnesses

| People ask | Verdict | One-line reason | Entry id |
|---|---|---|---|
| "Can jev pick which skill or tool the agent loads?" | strong | Measured over 182 skills and 488 requests — synthetic requests written by Claude Sonnet 5 from each skill's own `SKILL.md`, so labels are correct by construction and the inputs are easier than real ones: wrong loads 16.8% → 7.3%, needless loads 9.8% → 4.0%; must stay advisory | uc-agents-harness-skill-or-tool-selection |
| "Can jev fill function-call arguments without JSON repair?" | good | Closed-set arguments cannot be schema-violated, so the retry loop disappears | uc-agents-harness-function-call-argument-filling |
| "Route prompts to the cheapest model that can handle them?" | good | Intent and difficulty are bounded reads; the routing table stays in code | uc-agents-harness-model-difficulty-routing |
| "Can jev tell us the agent stopped before it finished?" | good | A completion check against the enumerated task items, before the user sees it | uc-agents-harness-premature-completion-check |
| "Is jev good at catching prompt injection?" | conditional | Second layer only: positives escalate, negatives clear nothing | uc-agents-harness-prompt-injection-semantic-flag |
| "Can jev decide whether a shell command is safe to run?" | **no as asked; conditional for adding a confirmation prompt** | The allowlist, denylist, sandbox and credential scope are the safety decision and stay in code. Conditional only inside them: the hazard battery may *add* a confirmation, never remove one | au-shell-command-safety-hook-gate / uc-agents-harness-pre-tool-use-destructiveness |
| "Can jev be our agent's planner?" | no | An open loop with no code-owned termination fails fit question 5 | au-open-ended-agent-loop |
| "Predict the next tool call so we can prefetch?" | weak | The signal is keyword frequency, which code already has | au-predict-next-tool-call |
| "Compact the agent's context by scoring relevance?" | weak | It drops the one constraint that mattered, and the failure is silent | au-context-compaction-by-relevance-scoring |
| "Fetch jev's `SKILL.md` from the upstream branch at runtime?" | no | An unpinned fetch puts a third party inside your decision path; vendor and pin it | au-unpinned-upstream-skill-fetch |
| "Ship Wikiracing-style open-web navigation as a feature?" | weak | Each hop compounds error with no termination owner; a demo is not a product shape | au-open-web-navigation-as-a-feature |
| "Let jev decide whether the fix-and-retry loop can stop?" | no | Pass/fail has an authoritative source — the runner's exit code | au-review-loop-pass-fail-gate |
| "Can question two use question one's answer in one request?" | no | Questions are answered independently; chain across two calls with code between | au-chain-questions-in-one-request |

### Verification and guardrails

| People ask | Verdict | One-line reason | Entry id |
|---|---|---|---|
| "Can jev check our extraction instead of paying reasoning-model prices?" | good | Cascade: cheap model extracts, jev verifies each field, only failures escalate | uc-verification-structured-extraction-cascade |
| "Does the cited passage actually support the claim?" | good | Claim plus cited span in a small state is the cleanest single-hop verification | uc-verification-citation-supports-claim |
| "Screen what our LLM just said before we show it?" | good | Policy breaks, drift and source contradiction as parallel Nouls in the response path | uc-verification-llm-output-policy-check |
| "Can jev do our invoice three-way match?" | **no as asked; conditional for advising on the lines code could not clear** | Amounts, tax, totals, tolerances and dates are failure modes 2 and 3 and stay in the matcher. Conditional for the semantic residue on exception lines only, advisory, never the approval | au-invoice-three-way-match-by-jev / uc-verification-invoice-three-way-match |
| "Can jev replace the frontier LLM judge in our eval suite?" | good | A fixed rubric over every row instead of a sample, if the levels describe concrete situations | uc-observability-evals-rubric-scoring-llm-judge-replacement |
| "What confidence threshold should we use — 0.8?" | good | No default exists; fit per question on your own rows and quote coverage with accuracy | uc-observability-evals-confidence-threshold-calibration-fitting |
| "Score our jev ranker with a jev rubric?" | no | Self-preference measured at +0.053 NDCG@10 under jev labels against −0.028 under Claude Haiku 4.5 labels | au-jev-as-its-own-judge |
| "Auto-approve anything above 0.9 confidence?" | no | Confidence describes the distribution's shape; injected authority claims collapsed margins from 1.000 to 0.05–0.24 | au-confidence-as-correctness-gate |
| "It can't hallucinate, so can we drop human review?" | no | The type guarantee says well-formed, not right | au-zero-hallucination-means-always-right |
| "We must tell the customer why — can jev explain?" | no | There is no rationale field; the reason must come from code or a model that writes one | au-decisions-that-need-an-explanation |
| "It looked right on twenty examples — ship it?" | no | Answers move with wording and option order; vary the framing and re-measure | au-single-question-framing-sensitivity |
| "More dimensions is always better, right?" | weak | Past the point one question handles, decomposition multiplies false positives | au-over-decompose-when-one-question-works |
| "Reuse the 0.8 cut-off from tickets on the new model?" | no | Calibration is a property of a distribution; refit per question and per domain | au-copy-calibration-thresholds-across-domains |
| "Ask it as a Noul and a Choice and average for robustness?" | no | P and not-P need not sum to 1, and the two are not on the same scale | au-average-noul-with-choice |
| "Show the score in the UI as '87% match'?" | no | A Score is an ordinal position on your rubric, not a magnitude | au-show-score-as-a-number-to-users |
| "Read a Score of 1.45 on a three-level rubric as 4.8 out of 10?" | no | Score expectation is not numerically calibrated; threshold or rank instead | au-interpolate-magnitude-from-score |

### Data, extraction and ML features

| People ask | Verdict | One-line reason | Entry id |
|---|---|---|---|
| "Can jev featurize our free-text column for the GBM?" | strong | Measured on 800 held-out wine reviews, target is the reviewer's own published 80-98 score (human, pre-existing): 38 jev features into CatBoost gave RMSE 1.77, against 2.15 for asking jev for the number and 2.47 for word counts; no TF-IDF or embedding baseline was run | uc-data-ml-text-features-for-tabular-model |
| "Which of the four amounts on this invoice is the total?" | conditional | Only after a parser enumerates candidates and jev picks one, with `none of these` | uc-data-ml-pre-parsed-value-selection |
| "Can jev extract the contract's expiry date?" | conditional | Month, day and year as Choices over enumerated parts; code assembles and compares | uc-data-ml-date-part-extraction |
| "Can I write `WHERE is_complaint(body)` in Postgres?" | **no in a hot query; good as materialisation** | In a live `WHERE` (or a `JOIN` condition) the planner chooses the call count and the bill — a 50M-row scan is ~$1,470 and 50M HTTP calls. As `UPDATE ... SET flag = jev(...)` over a bounded batch, then an index scan on the column, it is good | au-semantic-predicate-in-hot-query / uc-data-ml-semantic-predicates-in-sql |
| "Label all four million rows instead of a 200-row sample?" | good | Row-by-row labelling with aggregation in code is the shape the price supports | uc-data-ml-map-reduce-corpus-labelling |
| "How likely is this account to churn next quarter?" | no | A prediction about the future, not a judgement about text; extract features, fit a model | au-predict-outcome-instead-of-features |
| "Does jev know our pricing policy and SLA tiers?" | no | Knowledge not in the state and not common sense is unavailable; put the policy in the state | au-private-knowledge-not-in-state |

### Commerce, HR, sales

| People ask | Verdict | One-line reason | Entry id |
|---|---|---|---|
| "Can jev deduplicate our product catalogue?" | good | Blocking in code makes the shortlist; jev returns merge / leave / curator, never an unattended merge | uc-commerce-catalog-entity-dedup |
| "Map a seller's messy title into our taxonomy?" | good | Normalisation is intent, which is where keyword rules keep failing | uc-commerce-listing-category-normalisation |
| "Classify the return reason when the dropdown says 'other'?" | good | The comment box is the free text the dropdown lost | uc-commerce-return-reason-classification |
| "Should we use TypeSafe to score resumes against job criteria?" | good | Independent weighted dimensions combined in code, as an ordering aid for a reviewer | uc-hr-recruiting-resume-composite-scoring |
| "Does this CV evidence they have shipped a mobile app?" | good | A named, checkable experience is a clean Noul; a boolean search string is not | uc-hr-recruiting-relevant-experience-detection |
| "Route a speculative application to the right req?" | good | Bounded destinations with a human queue under the confidence floor | uc-hr-recruiting-candidate-routing |
| "Should we use TypeSafe to route leads?" | good | Team, track and response speed are three bounded choices in one call | uc-sales-marketing-lead-routing |
| "Score a company against our ICP from its website?" | good | Firmographic rules cannot read positioning; the score orders outbound, it does not disqualify | uc-sales-marketing-icp-fit-scoring |
| "Detect buying intent in an inbound message?" | good | Demo request versus support question is single-hop with an obvious uncertain path | uc-sales-marketing-buyer-intent-detection |
| "Can jev enforce our house style guide?" | good | Rules you can describe but not regex become parallel Boolean conditions per paragraph | uc-media-content-prose-style-linting |
| "Can jev detect AI-generated writing / establish authorship?" | no | Authorship is not in the text, nothing measures jev on it, and a false positive accuses a person of not writing their own work | au-ai-authorship-detection |
| "Flag concrete prose defects across our archive for an editor?" | conditional | Advisory flags on observable defects (unexplained action, claim without source), human editor decides, no `is_ai_generated` question anywhere | uc-media-content-ai-writing-slop-detection |
| "Sift the CV pile and auto-reject the bottom?" | no | An irreversible adverse decision, no rationale, no review path | au-resume-auto-rejection |
| "Rank inbound startup pitches for the committee?" | weak | The judgement depends on knowledge not in the state and has no ground truth | au-startup-idea-and-business-plan-evaluation |
| "Award the final mark, or set the performance rating?" | no | High-stakes exact grades need a magnitude and an explanation; a Score gives neither | au-exact-grade-prediction-high-stakes |

### Regulated industries

| People ask | Verdict | One-line reason | Entry id |
|---|---|---|---|
| "Check an inbound MSA for the clauses we require?" | good | One Noul per required clause, as a first pass before counsel reads it | uc-legal-compliance-contract-clause-presence |
| "Verify our filing against the rule's checklist?" | good | One Noul per explicit requirement, with the requirement text in the state | uc-legal-compliance-regulatory-requirement-verification |
| "Detect breaches of our internal T&E policy?" | conditional | Only with the policy text in the state, and only as a flag for a reviewer | uc-legal-compliance-policy-violation-detection |
| "Read payment narratives for laundering signals?" | good | Named suspicious characteristics as separate Nouls, replacing a memo keyword list | uc-financial-crime-transaction-narrative-suspicious-characteristics |
| "Order the AML alert queue by evidence quality?" | good | Ordering is advisory and reversible; auto-closing an alert stays out | uc-financial-crime-alert-prioritisation-by-evidence-quality |
| "Pick the peril code from an FNOL description?" | good | A small closed set over one short narrative, retiring the keyword table | uc-insurance-fnol-classification |
| "Can jev decide which claims are paid straight through?" | **no as asked; conditional for flagging claims to remove from STP** | A probability may not release money and STP eligibility is a contractual invariant. Conditional only in the safe direction: deterministic rules stay authoritative and jev may move a claim *out* of STP, never into it | au-straight-through-claim-payment-decision / uc-insurance-straight-through-vs-adjuster-routing |
| "Turn incident narratives into underwriting risk indicators?" | good | Probabilistic indicators plus a severity Score, combined by code | uc-risk-forecasting-incident-report-risk-indicators |
| "Rate free-text answers in a vendor security questionnaire?" | good | Independent risk dimensions scored per answer and weighted in code | uc-risk-forecasting-vendor-assessment-scoring |

### SDLC and CI

| People ask | Verdict | One-line reason | Entry id |
|---|---|---|---|
| "Triage new GitHub issues into bug / feature / question?" | good | A small closed set on creation, with labels advisory | uc-sdlc-issue-triage-bot |
| "Check in CI that the PR description explains why?" | good | A Noul over title, body and diff summary; advisory before it ever blocks | uc-sdlc-pr-description-explains-why |
| "Classify a CI failure before the rerun bot fires?" | good | Infrastructure versus flake versus real regression, so minutes stop going to regressions | uc-sdlc-ci-failure-triage-before-rerun |
| "Run the half of our style guide ESLint cannot express?" | good | Conventions written in English become semantic lints reported as review comments | uc-sdlc-semantic-lint-team-conventions |
| "Score a PR's risk tier to decide review depth?" | good | Risk is semantic and path globs miss it; the merge rule stays in branch protection | uc-sdlc-pr-risk-tier-review-routing |
| "Can jev pick the reviewers for a PR, or replace CODEOWNERS?" | **no as asked; conditional for labels and one additional reviewer** | Required reviewership is an ownership fact in a file and an access-control invariant. Conditional for labelling by meaning and for suggesting one *extra* expert beside the required approvers, advisory only | au-reviewer-assignment-replacing-codeowners / uc-sdlc-reviewer-and-label-routing |
| "Rank functions for a plain-language code search?" | good | Whole functions are the right unit; raw matched lines are not | uc-sdlc-semantic-code-search-ranking |
| "Classify commits as feat/fix/chore for an automatic version bump?" | weak | One assessment measured 62.9% agreement over 43 commits at 0.79 mean confidence | au-commit-type-classification-unattended |
| "Replace the 30-day inactivity cron with a jev call?" | no | Date arithmetic, and the deterministic rule is already correct | au-archive-after-n-days-rule |
| "Decide how to handle a 429 versus a 503?" | no | Enum equality is lexical; a `switch` wins on every axis | au-http-status-enum-routing |
| "Match this order line to a SKU, or resolve an error code?" | no | Exact lookup belongs to an index or a dictionary join | au-exact-lookup-and-id-matching |
| "Replace our optimiser or solver with a jev call?" | no | Where an exact algorithm defines the answer, judgement can only be worse | au-solver-verifiable-decisions |

### Real-time, browser and devices

| People ask | Verdict | One-line reason | Entry id |
|---|---|---|---|
| "Moderate live game chat in the send path?" | good | Severity plus confidence bands inside a budget a frontier LLM cannot meet | uc-realtime-live-chat-moderation |
| "Route voice intents without transferring money on a mishearing?" | good | Risk-scaled thresholds per action, with a confirmation on the destructive ones | uc-realtime-voice-command-intent-risk-scaled-thresholds |
| "Use jev as routing middleware in the request path?" | good | After the routing table has done its job, the remaining fan-out is a meaning question | uc-realtime-http-request-route-selection |
| "Can jev replace the vision model that decides what to click?" | good | A code-serialised accessibility tree is text and the action set is enumerated | uc-browser-automation-action-selection-from-accessibility-tree |
| "Drive an Android phone from the accessibility tree?" | conditional | Only behind a code-owned action allowlist and a step budget | uc-devices-control-mobile-action-selection-accessibility-tree |
| "The demo played Doom — can jev read our video feed at 10 Hz?" | no | No image input; the demo fed a code-serialised state, not pixels | au-real-time-from-raw-pixels |

### Things jev cannot do (generation, math, dates, images, multi-hop)

| People ask | Verdict | One-line reason | Entry id |
|---|---|---|---|
| "Generate the fix for this failing test, or write the SQL?" | no | Code is generation; jev emits a typed decision only | au-generate-code-and-patches |
| "Rewrite this in plain English, or translate our help centre?" | no | Text production, which no primitive supports | au-rewrite-and-translate-text |
| "Pull the invoice total and vendor name out of this email?" | no | An unbounded string; the rewrite is regex candidates plus a Choice | au-free-form-value-extraction |
| "How many action items are in this transcript?" | no | Counting is unreliable and error grows with size; one Noul per item, sum in code | au-count-items-in-text |
| "Does this refund exceed our $200 auto-approval limit?" | no | Arithmetic and threshold tests belong in code | au-numeric-thresholds-and-arithmetic |
| "Are `#E03A3A` and `#DC2626` the same red?" | no | Numeric closeness, with hex and RGB the documented worst case | au-numeric-closeness-hex-rgb |
| "Flag invoices more than 30 days overdue?" | no | Dates are text to jev; extract parts and compare in code | au-date-ordering-and-overdue |
| "Moderate uploaded images, or classify scanned invoices?" | no | Text only — no image, audio or video input exists | au-image-audio-video-input |
| "Is there no reason we shouldn't refund, given their plan's policy?" | no | Chained inference and double negatives are a named failure mode | au-multi-hop-and-double-negatives |

### Things jev should not be trusted with alone

| People ask | Verdict | One-line reason | Entry id |
|---|---|---|---|
| "Can jev be our prompt-injection filter?" | no | State is not hostile by default, so the attacker optimises against the judge; deterministic controls stay authoritative | au-sole-security-gate |
| "Can jev approve refunds, payouts, or admin access?" | no | A money or access invariant must hold every time; keep the gate in code | au-payments-and-access-control-decision |
| "Is this clause enforceable? Is this DSAR in scope?" | no | A legal determination needs counsel and a reasoned record | au-legal-determinations-without-counsel |
| "Can jev triage symptoms in our patient app?" | no | Clinical answers informing care are not a System One decision | au-clinical-medical-answering-for-care |

### Operational and procurement questions

| People ask | Verdict | One-line reason | Entry id |
|---|---|---|---|
| "Can we self-host jev, or run it air-gapped?" | no | No self-hosted, on-prem or open-weights offering is documented | au-air-gapped-or-self-hosted |
| "Can we run patient notes or card data through jev?" | weak | Zero data retention is enterprise-only and no residency commitment is published | au-zero-data-retention-regulated-data |
| "Can jev be a hard dependency of checkout or login?" | weak | Dynamic rate limits, a waitlist and no SLA mean you need a tested 429/529 fallback | au-availability-and-rate-limits |
| "Can we promise 200 ms end to end from Frankfurt?" | weak | Published figures are US-West measurements, not an SLA; measure from your own egress | au-latency-slo-outside-us |
| "Can we turn it on for our Japanese and German queues?" | weak | English is the primary training language; evaluate each language yourself first | au-non-english-at-scale-unevaluated |
| "Can we put '193x faster, 444x cheaper' in the business case?" | weak | Headline multipliers come from one comparison and do not transfer to your workload | au-expect-headline-speed-cost-multipliers |
| "Can we fine-tune jev on our labelled tickets?" | no | No fine-tuning and no learning from feedback; you adapt questions, not weights | au-expect-fine-tuning-from-feedback |
| "Is jev deterministic — can we snapshot-test it?" | no | Identical inputs can return different answers; test with tolerances, not equality | au-expect-identical-results-across-runs |
| "Should we standardise our AI roadmap on jev?" | no | Screen the backlog first: images and generated text are out before the fit test starts | au-whole-ai-feature-backlog |

## Questions the corpus cannot answer yet

- **How accurate will jev be on our data and our taxonomy?** No entry can say. Shadow-run it against the incumbent on a few hundred labelled rows of your own; see `df-rollout`.
- **Can we get access, and what is the waitlist status?** Access was early-access and waitlisted. Ask TypeSafe; check the live models page before you plan a launch date.
- **Is there an SLA, an uptime commitment, or a status page?** None published. A procurement question for TypeSafe, not a corpus question.
- **What is the accuracy per language?** Mostly unmeasured — but not entirely. One independent Korean benchmark (mahlernim/jev-korean-benchmark, 100 items per condition, author-stated ±8-point margin) found reading comprehension holding up (Belebele **96 Korean against 97 English**) while domain knowledge fell (KorMedMCQA **80 against gpt-5.6-luna's 88**). Read that as: parity is plausible on reading-shaped tasks, not on knowledge-shaped ones, at n=100. For any other language, sample and label rows and measure each separately (`au-non-english-at-scale-unevaluated`).
- **How well calibrated is jev on our distribution?** Independent ECE measurements differ widely by dataset. Measure it yourself, per question.
- **Does a hosting region other than US-West exist?** No residency policy was found. Ask TypeSafe and get it into the DPA.
- **Which certifications exist (SOC 2, ISO 27001, a HIPAA BAA)?** Not published. Ask TypeSafe's security contact.
- **What enterprise rate limits can we negotiate?** Only the published defaults are documented. Ask, with your peak requests-per-minute in hand.
- **What p95 and p99 latency will we see from our region?** Only typical figures and independent medians exist. Measure from your own egress over a week.
- **Is the price still current?** Prices here are pinned to each entry's `last_verified`. Check the live models page before quoting a cost.
- **What changes in the next version, and what is the alias deprecation policy?** Not documented. Pin the versioned model id and re-measure thresholds after any move.
- **How robust is jev under adaptive attack?** No published benchmark measures this. Keep deterministic controls authoritative.
- **Does jev beat our specific incumbent — Cohere Rerank, a fine-tuned encoder, our regex?** Only a head-to-head on your data answers this.
- **Will a cookbook's numbers reproduce on our corpus?** Most cookbooks are worked demonstrations on curated data. Re-run the shape on your rows.
- **What will this cost at our volume?** No monthly number without a counted volume. Use the per-call method in `df-cost-model`.

## Vocabulary the retriever should map

| People say | Canonical term or entry |
|---|---|
| boolean, yes/no question, binary classifier, predicate, probability | **Noul** — `gt-api-and-primitives`, `gt-glossary` |
| enum, label, category, one-of, dropdown value, class | **Choice** (2–255 options) — `gt-api-and-primitives` |
| rubric, rating, severity, 1–5 scale, grade, tier | **Score** (2–10 ordered levels) — `gt-api-and-primitives`, `au-interpolate-magnitude-from-score` |
| abstain, abstention, "I don't know", reject option | developer-defined confidence routing; jev never abstains — `gt-confidence-and-calibration`, `uc-observability-evals-confidence-threshold-calibration-fitting` |
| System 1, System-1, fast model, instinct model | **System One** — `gt-what-jev-is` |
| TypeSafe, TypeSafe AI, `jev-latest`, `jev-preview` | aliases resolving to the pinned model id — `gt-limits-pricing-versions` |
| rerank, re-ranking, cross-encoder replacement | `uc-search-retrieval-rerank-keyword-shortlist` |
| hybrid search, fusion, RRF, combine with embeddings | `uc-search-retrieval-rrf-fusion-with-dense-retriever` |
| judge, grader, LLM-as-judge, eval scorer | `uc-observability-evals-rubric-scoring-llm-judge-replacement`, `au-jev-as-its-own-judge` |
| guardrail, output filter, safety check on a reply | `uc-verification-llm-output-policy-check` |
| jailbreak, prompt injection, WAF for LLMs | `uc-agents-harness-prompt-injection-semantic-flag`, `au-sole-security-gate` |
| dedupe, entity resolution, record linkage, fuzzy match | `uc-commerce-catalog-entity-dedup`, `uc-data-ml-kg-relationship-typing-and-entity-alignment`, `uc-financial-crime-entity-matching-inconsistent-names` |
| NER, field extraction, "parse the document" | `au-free-form-value-extraction` first, then `uc-data-ml-pre-parsed-value-selection` |
| OCR, scanned PDF, screenshot, audio clip | `au-image-audio-video-input` |
| summarise, TL;DR, condense the thread | `au-generate-ticket-summaries` |
| translate, localise, paraphrase, "make it punchier" | `au-rewrite-and-translate-text` |
| text-to-SQL, codegen, autofix, generate the patch | `au-generate-code-and-patches` |
| propensity, churn score, conversion probability, lead score | `au-predict-outcome-instead-of-features`, then `uc-data-ml-text-features-for-tabular-model` |
| triage, queue assignment, ticket routing, intent detection | `uc-support-ticket-team-routing`, `uc-support-intent-routing-handlers` |
| model router, cascade, escalate to a bigger model | `uc-agents-harness-model-difficulty-routing`, `uc-agents-harness-confidence-escalation-to-frontier-model` |
| tool selection, skill selection, "which tool should the agent use" | `uc-agents-harness-skill-or-tool-selection` |
| function calling, structured output, JSON mode, schema repair | `uc-agents-harness-function-call-argument-filling` |
| taxonomy, deep category tree, thousands of leaves | `uc-search-retrieval-hierarchical-taxonomy-beam-search`, `au-flat-choice-over-255-options` |
| threshold, cut-off, "gate at 0.8", auto-approve band | `uc-observability-evals-confidence-threshold-calibration-fitting`, `au-copy-calibration-thresholds-across-domains` |
| determinism, reproducible, snapshot test, caching the answer | `au-expect-identical-results-across-runs` |
| ZDR, data residency, DPA, on-prem, VPC deployment | `au-zero-data-retention-regulated-data`, `au-air-gapped-or-self-hosted` |
| rate limit, 429, 529, quota, waitlist, backfill capacity | `au-availability-and-rate-limits` |
| fine-tune, train on our data, active learning, "learns from corrections" | `au-expect-fine-tuning-from-feedback` |
| explainability, rationale, audit trail, chain of thought | `au-decisions-that-need-an-explanation` |
