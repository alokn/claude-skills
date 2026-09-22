---
id: df-alternatives
title: Choose between jev and the other ways to make a decision on text
decision_shapes: [classification, detection, scoring, routing, ranking, verification, extraction, search, feature-extraction]
primitives: [choice, score, noul]
evidence_level: independent-benchmark
sources:
  - https://docs.typesafe.ai/models  (jev price, context, rate limits, no fine-tuning, English-first)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13  (published failure modes)
  - https://docs.typesafe.ai/cookbooks/consistency_choice_cookbook  (114 ms mean round trip, run-to-run spread vs LLMs)
  - https://docs.typesafe.ai/cookbooks/autoresearch_feature_discovery  (jev as feature extractor into CatBoost)
  - https://docs.typesafe.ai/cookbooks/hierarchical_classification.md  (beam search over Choice probabilities; the >255-option rewrite)
  - https://github.com/nibzard/decision-model-benchmark  (independent accuracy, p50, 255-option cap, ECE 0.246)
  - https://github.com/ickma2311/jev-baselines-eval  (supervised encoder 0.933 vs jev 0.832 on Banking77)
  - https://github.com/bitnovus/jev-spam-eval  (TF-IDF logistic regression beats jev zero-shot on spam)
  - https://empryo.com/blog/jev-and-the-harness  (three decisions where deterministic code won)
  - https://platform.claude.com/docs/en/about-claude/pricing  (Claude prices)
  - https://developers.openai.com/api/docs/pricing  (OpenAI prices)
  - https://ai.google.dev/gemini-api/docs/pricing  (Gemini prices)
  - https://arxiv.org/abs/2408.02442  (format restriction degrades reasoning)
  - https://arxiv.org/abs/2408.04667  (non-determinism at temperature 0)
related: [df-fit-test, df-cost-model, df-rewrites, gt-evidence-independent, au-numeric-thresholds-and-arithmetic, au-date-ordering-and-overdue, cb-autoresearch_feature_discovery, cb-hierarchical_classification]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## What this file is for

You have a decision-shaped task on text: classification, detection, scoring, routing, ranking,
verification, or bounded extraction. jev is one of ten families of tool that can do it. This file
gives the numbers for each family, the pair of conditions that flips the choice, and a decision tree.

Two conventions run through the file. **The reference task** is a short decision: about 600 input
tokens of state plus one question, one typed answer out (about 20 output tokens for anything that
generates). Cost per 1,000 decisions is computed from published per-token prices on that basis and
the arithmetic is shown. **Accuracy is never assumed.** jev's claimable properties are typed output,
probabilities trained to be calibrated (RLCD) — calibration measured, not assumed; independent ECE
0.045-0.242 by dataset — speed and price (not run-to-run stability: Claude Haiku 4.5 at temperature 0 was more repeatable than jev in TypeSafe's own choices cookbook). Accuracy is a per-task
measurement, and where a published measurement puts jev behind another tool this file says so.

---

## Decision matrix

| Alternative | Latency (short decision) | Cost / 1k decisions | Training data | Calibrated confidence | Schema guarantee | Generation | Multi-hop reasoning | Self-hostable | Best for |
|---|---|---|---|---|---|---|---|---|---|
| **jev 1.13** | 114 ms mean (vendor cookbook); p50 264-422 ms (independent) | **$0.025** computed; $0.046-$0.07 measured | none | trained to be calibrated (RLCD); calibration measured, not assumed; independent ECE 0.045-0.242 by dataset | yes, structural | no | weak (documented) | none documented | high-volume typed judgement on the request path |
| Frontier LLM + structured output | 0.69-1.12 s TTFT; 8-52 s with reasoning on | $1.40 (Sonnet 5) - $7.00 (GPT-6 Astra) | none | poor; verbalized confidence overconfident | yes, with strict JSON schema | yes | strong | no | ambiguous, multi-hop, or explanation-needed decisions |
| Small/fast LLM | 0.16-0.85 s TTFT | $0.04 (GPT-5-nano) - $0.70 (Haiku 4.5) | none | poor-to-fair | yes | yes | fair | some (open weights) | cheap decisions that also need a sentence of text |
| Fine-tuned encoder (SetFit / ModernBERT / DeBERTa) | 10 ms median measured; 2.76-121 ms CPU | <$0.001 marginal + GPU hour + labelling | 8-10,000 per class | yes, trainable; standard calibration methods apply | yes, fixed label set | no | none | yes | a stable label set where you already have labels |
| Zero-shot NLI / GLiClass / GLiNER | 163 ms CPU (GLiNER2, 20 labels); 6,758 ms for NLI cross-encoder at 20 labels | <$0.001 marginal + compute | none | weak, uncalibrated | yes | no | none | yes | on-prem / air-gapped zero-shot with no per-call cost |
| Embeddings + threshold / reranker | 0.01-0.5 s | $0.012 (embed) / $2.00 (Cohere Rerank on Bedrock) | none (thresholds need a dev set) | no; similarity is not probability | yes (it is a number) | no | none | yes | narrowing millions of candidates to tens |
| Regex / rules / deterministic code | microseconds | **$0** | none | n/a (exact) | yes | no | n/a | yes | lexical, arithmetic, dates, IDs, exact policy |
| Classical ML on structured features | sub-ms | ~$0 at inference | hundreds to thousands of rows | yes | yes | no | none | yes | tabular signal; jev can supply the text features |
| Distillation / fine-tuning service | ~small-LLM latency | serving + $0.34-$40 per 1M training tokens | 50 to thousands of examples | trainable | yes | yes | fair | yes on open-weight hosts | a frozen, high-volume task worth owning weights for |
| Constrained decoding library (Outlines / Instructor / BAML / AI SDK `Output`) | inherits the model, +0 to +2x per output token by engine | inherits the model | none | no | schema only, and only Outlines-class engines constrain decoding | inherits | inherits | inherits | a signal the codebase is already shaped for jev |
| Human review queue | median 5.83 h (TikTok DSA disclosure) | ~$190 **derived, not published** | n/a | n/a (Fleiss kappa 0.50 among trained annotators) | no | yes | strong | n/a | the tail that no model should decide alone |

---

## 1. Frontier LLM with structured output

**Prices, per million tokens, in/out, accessed 2026-09-19.** Claude Opus 5 $5 / $25, Claude Sonnet 5
$2 / $10, Claude Fable 5.1 $10 / $50 ([platform.claude.com pricing](https://platform.claude.com/docs/en/about-claude/pricing)).
GPT-6 Astra $10 / $50 ([developers.openai.com pricing](https://developers.openai.com/api/docs/pricing)).
Gemini 3.1 Pro Preview $2 / $12 ([ai.google.dev pricing](https://ai.google.dev/gemini-api/docs/pricing)).
Batch halves all three; cache hits are 10% of input on Claude and OpenAI.

**Cost on the reference task.** Sonnet 5: 600k in x $2/M = $1.20, plus 20k out x $10/M = $0.20, so
**$1.40 per 1,000**. Opus 5: $3.00 + $0.50 = **$3.50**. GPT-6 Astra: $6.00 + $1.00 = **$7.00**. jev on
the same basis is $0.025, so Sonnet 5 is 56x, Opus 5 140x and GPT-6 Astra 280x the price. Reasoning
modes break the arithmetic entirely, because thinking tokens bill as output.

**Latency.** Measured client-side on 1,024-token input / 256-token output, 10,000 probes per pairing
over 90 days, April 2026: Claude Sonnet 4.6 p50 0.74 s / p95 1.61 s; Claude Opus 4.7 standard p50
0.85 s / p95 1.83 s; GPT-5.5 standard p50 1.12 s / p95 2.41 s; Gemini 3 Pro default p50 0.93 s
([digitalapplied benchmark](https://www.digitalapplied.com/blog/ai-model-latency-benchmarks-2026-ttft-throughput)).
With reasoning on, the same source measures GPT-5.5 Pro medium at p50 8.4 s and Claude Opus 4.7
extended thinking at p50 28 s / p95 67 s. TypeSafe's own comparison reports 826 ms to 13.0 s per call
across its LLM conditions against 114 ms for jev
([consistency_choice cookbook](https://docs.typesafe.ai/cookbooks/consistency_choice_cookbook)).

**Schema guarantees.** OpenAI's Structured Outputs with `strict: true` constrains sampling to the
supplied JSON Schema and OpenAI reports 100% compliance on its complex-schema eval for
gpt-4o-2024-08-06, against roughly 86% for plain function calling
([OpenAI announcement, via secondary reporting](https://openai.com/index/introducing-structured-outputs-in-the-api/) —
the first-party page returned HTTP 403 on 2026-09-19, so treat the 100% / 86% pair as reported rather
than re-verified). This closes the *shape* gap with jev but not the *probability* gap: a schema-valid
answer is still an unlabelled guess.

**Weaknesses.** Overconfidence is measured: across MMLU, TriviaQA, ARC and HellaSwag, Gemini 2.5 Pro
stated 99.5% mean confidence at 80.9% accuracy (ECE 0.185), Gemini 2.5 Flash 97.9% at 70.9% (ECE
0.272), Kimi K2 95.7% at 23.3% (ECE 0.726); Claude Haiku 4.5 was best at 86.0% stated / 75.4% actual,
ECE 0.122 ([arXiv:2603.09985](https://arxiv.org/html/2603.09985)). Temperature 0 is not determinism:
five models over eight tasks with ten runs each showed "accuracy variations up to 15% across
naturally occurring runs with a gap of best possible performance to worst possible performance up to
70%" ([arXiv:2408.04667](https://arxiv.org/abs/2408.04667)). And format restriction itself costs
reasoning: "we observe a significant decline in LLMs reasoning abilities under format restrictions"
([arXiv:2408.02442](https://arxiv.org/abs/2408.02442), EMNLP 2024 Industry Track) — though the same
paper found format restriction *helped* classification accuracy, which is the shape of task in scope
here. See section 10 for the full state of that argument.

**Choose a frontier LLM over jev when** the decision needs several hops of inference, the state is
adversarial or unusual enough that common-sense judgement is not enough, or you need a written
justification alongside the verdict.

Two further conditions are **conditional, not automatic**:

- **More than 255 candidate options.** jev returns `400 Too many choices` at 256
  ([nibzard DMB](https://github.com/nibzard/decision-model-benchmark)), but TypeSafe publishes its own
  rewrites for exactly this: hierarchical Choice with beam search over the probabilities
  ([hierarchical_classification cookbook](https://docs.typesafe.ai/cookbooks/hierarchical_classification.md),
  which matched 4 of 4 expected leaves against greedy's 2 of 4 at K=3); shortlist-then-Choice, where
  BM25 or an embedding index narrows to tens first; and two-stage Score-every-candidate-then-Choice
  among the top few (`df-rewrites`). Compare those designs against a frontier LLM on your own data
  rather than rejecting jev on the cap alone.
- **Non-English input.** TypeSafe says it is supported at lower accuracy: "English is the primary
  training language and where accuracy is currently best. Other languages, including CJK scripts, are
  handled but not equally well; test on your own content before relying on Jev for a non-English
  workload" ([models](https://docs.typesafe.ai/models)). No per-language accuracy figure is published,
  and the independent evidence is mixed by language *and* task — Korean reading held (Belebele 96 KO
  against 97 EN) while Korean medical QA fell to 80 against gpt-5.6-luna's 88, and a 24-document
  Norwegian first look scored stance 20/24 and substance 19/24 (`gt-evidence-independent`). Evaluate
  the language you actually have.

On TypeSafe's own eval harness Opus 5 scores 73% against jev's 68%
([evals.typesafe.ai](https://evals.typesafe.ai/), restated in
[Arize](https://arize.com/blog/typesafe-jev-llm-judge/)), and note that TypeSafe's own scoring uses
the average of GPT-6 Astra and Fable 5.1 as the reference answer, so it measures agreement with
frontier models rather than ground truth.

**Choose jev over a frontier LLM when** the decision is single-hop, the option set is bounded, the
call sits on a user-facing request path, and volume makes a 56-280x price difference material. The
second-order win is the probability. In the cited experiments the LLM's verbalized confidence was
badly miscalibrated — Gemini 2.5 Pro stated 99.5% at 80.9% accuracy, Gemini 2.5 Flash 97.9% at 70.9%
([arXiv:2603.09985](https://arxiv.org/html/2603.09985)) — so in those setups a confidence gate on the
LLM's stated number would not hold. That is a result on those models and benchmarks, not a general
law; measure it on yours.

---

## 2. Small and fast LLMs

**Prices per million tokens in/out, accessed 2026-09-19.** Claude Haiku 4.5 $1 / $5. GPT-5.6 Luna
$0.20 / $1.20; GPT-5.4-mini $0.75 / $4.50; GPT-5-nano $0.05 / $0.40. Gemini 3.8 Flash $0.75 / $3.75;
Gemini 3.5 Flash-Lite $0.30 / $2.50. deepseek-flash $0.30 / $1.20 peak, half that off-peak
([DeepSeek pricing](https://api-docs.deepseek.com/quick_start/pricing)). Groq GPT-OSS-20B
$0.075 / $0.30 and GPT-OSS-120B $0.15 / $0.60 ([console.groq.com/docs/models](https://console.groq.com/docs/models));
Groq moved Llama 3.1 8B and Llama 3.3 70B to enterprise-only pricing on 2026-08-26.

**Cost on the reference task.** Haiku 4.5 **$0.70 / 1k**; Gemini 3.8 Flash **$0.53**; Flash-Lite
**$0.23**; deepseek-flash **$0.20**; GPT-5.6 Luna **$0.14**; Groq GPT-OSS-20B **$0.05**; GPT-5-nano
**$0.038**. Against jev's $0.025 the gap narrows to roughly 1.5-28x. **Price alone stops being the
argument at this tier.**

**Latency.** Claude Haiku 4.5 TTFT 0.69 s on the Anthropic endpoint at 10k input tokens
([Artificial Analysis](https://artificialanalysis.ai/models/claude-4-5-haiku/providers)); GPT-5.5
Mini p50 0.61 s; Groq Llama 4 405B p50 0.18 s and Cerebras Llama 4 70B p50 0.16 s
([digitalapplied](https://www.digitalapplied.com/blog/ai-model-latency-benchmarks-2026-ttft-throughput)).
LPU/wafer-scale hosts are the one family that beats jev's measured p50 of 264-422 ms.

**Accuracy against jev, independently measured.** On Banking77 intent (77 labels): jev 0.832, GPT-5.6
Terra 0.875, gpt-5.4-nano 0.793 ([ickma2311](https://github.com/ickma2311/jev-baselines-eval),
n=208). On CLINC150: jev 0.870, Terra 0.915, nano 0.795. On a separate 5-suite benchmark, gpt-oss-120b
scored 81.3% and glm-5.3 80.4% on banking intent against jev's 76.3%, and GLM led spam 94.9% to 93.0%
([nibzard DMB](https://github.com/nibzard/decision-model-benchmark)). So jev sits between nano-class
and frontier-class on accuracy, and above nano-class on speed and price.

**Choose a small LLM over jev when** you need one sentence of text with the decision (a reason, a
draft reply, a normalised value), or when you are already on Groq/Cerebras and the 160-180 ms p50
matters more than the price. A label set over 255 and non-English content are reasons to *check*,
not to switch automatically: see the two conditional cases at the end of section 1.

**Choose jev over a small LLM when** you want the probability to mean something. This is the clean
differentiator at this tier: jev returns a full distribution over the option set whose probabilities
are trained to be calibrated (RLCD) — calibration measured, not assumed; independent ECE 0.045-0.242
by dataset — and its run-to-run probability standard deviation is 0.0098, lower than five of the six
LLM conditions TypeSafe measured (0.0245-0.0543). The sixth is the counter-result: `claude-haiku-4-5`
at temperature 0 came in at **0.0012**, an order of magnitude *below* jev, and also repeated its
plurality label 100% of the time against jev's 90.8% raw. The cookbook's own caveat: "None of this
shows accuracy or superiority"
([consistency_choice cookbook](https://docs.typesafe.ai/cookbooks/consistency_choice_cookbook)).
Also when many questions share one state: batching 13 questions over a 54,000-character document into
one jev call was "12.2x cheaper and 10.0x faster" than 13 calls, 0.27 s against 2.71 s
([parallel_questions cookbook](https://docs.typesafe.ai/cookbooks/parallel_questions)).

---

## 3. Fine-tuned encoder classifiers

**Training data.** SetFit claims usable results from 8 labelled examples per class: "With only 8
labeled examples per class on the Customer Reviews (CR) sentiment dataset, SetFit is competitive with
fine-tuning RoBERTa Large on the full training set of 3k examples", trained in 30 seconds on a V100
for about $0.025 ([HuggingFace SetFit blog](https://huggingface.co/blog/setfit);
[arXiv:2209.11055](https://arxiv.org/abs/2209.11055)). Cohere Classify requires "at least 2 examples"
per label and caps at 2,500 examples ([docs.cohere.com/reference/classify](https://docs.cohere.com/reference/classify)),
but since January 2025 it requires a fine-tuned Embed model
([Cohere deprecations](https://docs.cohere.com/docs/deprecations)), and **Cohere no longer publishes a
per-classification price** — cohere.com/pricing carries only Model Vault hourly rates as of
2026-09-19.

**Latency.** ModernBERT-base is 149M parameters with an 8,192-token window, "twice as fast as
DeBERTa - in fact, up to 4x faster in the more common situation where inputs are mixed length"
([Answer.AI](https://www.answer.ai/posts/2024-12-19-modernbert.html)). Measured throughput on an RTX
4090 at 512 tokens, fixed / variable length, thousands of tokens per second: ModernBERT-base
148.1 / 147.3, DeBERTaV3 70.2 / 35.1, BERT 180.4 / 90.2 ([arXiv:2412.13663](https://arxiv.org/abs/2412.13663)).
On CPU, a DistilBERT fine-tune averaged 121 ms per item on a 13th-gen Intel i7 at 384 tokens
([arXiv:2505.22937](https://arxiv.org/pdf/2505.22937)). The most directly comparable number is from
the head-to-head against jev: a frozen bge-small-en-v1.5 plus logistic regression ran at **0.01 s
median / 0.10 s p95 on an M4 Max laptop** ([ickma2311](https://github.com/ickma2311/jev-baselines-eval)).

**Cost.** No vendor publishes $/1k classifications for self-hosted encoders — **not published**. It
must be derived: an AWS g5.xlarge is $1.006/hr on-demand
([Vantage mirror of AWS pricing](https://instances.vantage.sh/aws/ec2/g5.xlarge)), which against
ModernBERT-base throughput puts 1,000 short classifications well under $0.001 of GPU time. The real
cost is labelling and maintenance, not inference.

**Where they beat zero-shot outright.** With labels in hand, they win decisively. Banking77: encoder
0.933 against jev 0.832, a paired difference of **+10.1 points [+5.3, +15.4]**, at zero per-call cost
and 9 ms ([ickma2311](https://github.com/ickma2311/jev-baselines-eval)). Spam: TF-IDF plus logistic
regression 98.87% against jev's best zero-shot configuration 98.64% on a 5,733-email set, and 96.39%
against 95.76% on a fresh set ([bitnovus](https://github.com/bitnovus/jev-spam-eval)) — the one place
jev won was recall on 2024-25 phishing, 95.31% against 75.26%, which is exactly the drift case.

**Maintenance and drift.** Nothing published quantifies retraining cadence — **not published**. The
qualitative trade is fixed: an encoder is a snapshot of a label set and must be retrained when the
taxonomy or the distribution moves; jev takes the new label in a string and needs no retraining.
Multi-label is native to encoders (independent sigmoid heads) and awkward for jev, which needs one
Noul per label.

**Choose a fine-tuned encoder over jev when** you already have a few thousand labels, the taxonomy is
stable, the volume is large enough that a fixed GPU bill beats a per-call bill, latency below 50 ms
matters, or the workload must run on-prem.

**Choose jev over a fine-tuned encoder when** you have no labels, the label set changes monthly, you
need many different questions against the same state rather than one head, or you want probabilities
that were trained to be calibrated rather than fitted. That last one does not remove the held-out set:
jev's calibration still has to be validated on a labelled sample of *your* workload, exactly as an
encoder's would, because independent ECE runs 0.045-0.242 by dataset. What you save is the *fitting*
step, not the *validation* step. Also when the class is rare and novel — the phishing
recall gap above is the shape of that argument.

---

## 4. Zero-shot NLI, GLiClass, GLiNER

**Mechanism and cost scaling.** An NLI zero-shot pipeline builds "a hypothesis from each candidate
label" ([facebook/bart-large-mnli](https://huggingface.co/facebook/bart-large-mnli)) — one forward
pass per label, so compute is linear in the label count. The measured blow-up: at 20 candidate
labels a DeBERTa cross-encoder took **6,758 ms against GLiNER2's 163 ms on CPU**
([arXiv:2507.18546](https://arxiv.org/html/2507.18546v1)); DeBERTa-v3-base throughput falls from
24.55 to 0.47 examples/sec going from 1 to 128 labels
([GLiClass paper, arXiv:2508.07662](https://arxiv.org/html/2508.07662v1)). jev takes all 255 options
in one pass; so does GLiClass, whose throughput "degrades only 7-20% going from 1 to 128 labels".

**Accuracy.** On a zero-shot benchmark spanning topic, sentiment, intent and emotion, macro-F1:
BART-Large-MNLI 0.51, DeBERTa-v3-large-nli-triplet 0.60, GTE-large-en-v1.5 embedding 0.62,
Mistral-Nemo-12B 0.67, Qwen3-Reranker-8B 0.72 ([arXiv:2603.11991](https://arxiv.org/html/2603.11991)).
GLiClass zero-shot F1 averages: Large 0.7193, Base 0.6764, Edge 0.4900, with model sizes 32.7M to
439M. GLiNER-L (0.3B) reaches 60.9 average F1 on 7 out-of-domain NER datasets against ChatGPT's 47.5
([arXiv:2311.08526](https://arxiv.org/abs/2311.08526)), trained in 5 hours on one A100.

**Calibration.** None of these publish calibration metrics — **not published**. NLI entailment scores
and GLiClass logits are scores, not probabilities of correctness.

**Choose a zero-shot encoder over jev when** the deployment must be on-prem, air-gapped or
zero-marginal-cost; when the task is span extraction rather than judgement (GLiNER is purpose-built
for NER and jev must be handed pre-parsed candidates —
[pre_parsed_value_extraction cookbook](https://docs.typesafe.ai/cookbooks/pre_parsed_value_extraction_cookbook));
or when licensing matters (GLiNER2 and GLiClass are Apache 2.0, jev is a hosted API only).

**Choose jev over a zero-shot encoder when** the judgement needs world knowledge rather than label
similarity, when you need a calibrated probability to gate on, or when the state is long
(jev takes 32k tokens of state; GLiClass and GLiNER inherit encoder-length limits).

---

## 5. Embeddings, vector search and cross-encoder rerankers

**Prices, accessed 2026-09-19.** OpenAI text-embedding-3-small $0.02 / 1M tokens, 3-large $0.13
([OpenAI pricing](https://developers.openai.com/api/docs/pricing)). Voyage voyage-3.5-lite $0.02,
voyage-3.5 $0.06, rerank-2.5 $0.05 per 1M tokens ([docs.voyageai.com/docs/pricing](https://docs.voyageai.com/docs/pricing)).
Gemini Embedding 2 text $0.20 / 1M ([ai.google.dev pricing](https://ai.google.dev/gemini-api/docs/pricing)).
Cohere Rerank 3.5 is **$2.00 per 1,000 queries**, where "a query is a single call to the reranker
model that can contain up to 100 document chunks"
([AWS Bedrock pricing](https://aws.amazon.com/bedrock/pricing/);
[unit definition](https://docs.aws.amazon.com/bedrock/latest/userguide/rerank-pricing.html)).
Cohere's own pricing page publishes no per-search Rerank 4 price — **not published**.

**Cost on the reference task.** Embedding 600 tokens at $0.02/M is **$0.012 per 1,000** plus vector
store. That is half of jev's $0.025 and it buys you a number, not a judgement.

**Latency.** Cohere Rerank 3.5 measured at 171.5 ms +/- 106.8 on a 12 KB payload and 459.2 ms +/- 87.9
on 150 KB, NDCG@10 0.7091 ([ZeroEntropy](https://zeroentropy.dev/articles/lightning-fast-reranking-with-zerank-1/) —
a competitor's benchmark, read it as such). PLAID cut ColBERTv2 search latency from 287 ms to 58 ms on
MS MARCO dev on a TITAN V, and reports 2.5-7x on GPU and 9-45x on CPU against vanilla ColBERTv2
([arXiv:2205.09707](https://arxiv.org/abs/2205.09707)); ColBERTv2 itself reduced the late-interaction
footprint "by 6-10x" against v1, not against single-vector indexes
([arXiv:2112.01488](https://arxiv.org/abs/2112.01488)).

**Where each wins.** Retrieval at scale is not a jev task: you cannot put a million candidates in a
32k-token state, and a 255-option Choice caps the shortlist. TypeSafe's own reranking recipe puts jev
*after* BM25, reranking 30-passage shortlists for 40 CLERC legal queries and lifting top-1 accuracy
from 5% to 18% and top-10 from 38% to 62%, at 1,200 calls costing $0.0645 total — $0.0645 / 40 =
**about $0.0016 per query** ([rerank_typesafe cookbook](https://docs.typesafe.ai/cookbooks/rerank_typesafe)).
Cohere Rerank 3.5 on Bedrock is $0.002 per query at up to 100 documents, so jev is roughly **1.24x
cheaper (about 19%)** on this comparison — not an order of magnitude — and the two are not
like-for-like anyway, since jev reranked 30 candidates per query and the Cohere unit allows up to 100.
The choice turns on whether the judgement is semantic similarity or a criterion, not on price.

**Choose embeddings or a reranker over jev when** the job is "find the nearest N of a million" or
"order these by topical similarity", when you need a durable index, or when the judgement is
genuinely about surface semantics.

**Choose jev over embeddings when** the question is a criterion rather than a similarity — "does this
passage actually answer the question", "are these two records the same entity", "is this a
contradiction". Cosine distance has no opinion about those. Note the honest gap: TypeSafe's entity
alignment cookbook reports only the routing split (40 merged, 50 to curator queue, 360 unlinked of
450 pairs) and publishes **no F1 against a string-similarity or embedding baseline**
([entity_alignment cookbook](https://docs.typesafe.ai/cookbooks/entity_alignment)).

---

## 6. Regex, rules, keyword lists, deterministic code

**Cost $0. Latency microseconds. Accuracy on the tasks they cover: exact.**

TypeSafe's own failure-mode page tells you to use code, repeatedly: "Jev is not a calculator. We
strongly recommend implementing any mathematical logic in code"; "jev-1.13 does not count reliably...
the error grows with the size of the thing being counted"; "jev-1.13 reads dates as text, not as
ordered quantities. Asking which of two dates comes first, how far apart they are, or whether one
falls inside a window is unreliable"
([model-jaggedness/jev-1.13](https://docs.typesafe.ai/model-jaggedness/jev-1.13), last reviewed
2026-09-17). The date cookbook's rule is the general one: "The model reads what the text says and
never does the calendar math" ([date_extraction cookbook](https://docs.typesafe.ai/cookbooks/date_extraction_cookbook)).

**The public evaluations where jev lost to deterministic code.** Empryo tested jev inside a coding
harness and discarded three decisions: "Ranking individual text match lines with Jev dropped top-3
accuracy from 78.6% to 74.1%"; the review-loop pass/fail check "agreed with human reviewer
classifications in 12 of 20 ambiguous cases"; and for next-tool prediction "Simple keyword counting on
the prompt outperformed both Jev (26% vs. 15%) and frontier models"
([Empryo](https://empryo.com/blog/jev-and-the-harness)). On failure triage jev scored 102/102 at
273 ms and $0.00002 against a regex baseline's 98/102 at zero cost and zero latency — and the four-case
gap turned out to be a bug: the status regex was matching `429` inside tool version identifiers such
as `text_editor_20250429`; digit-bounding the pattern took the free deterministic classifier to
102/102 too. A separate benchmark's deterministic keyword baseline scored **100% on the lexical
"code word" suite at $0 and 0 ms**, tying jev
([nibzard DMB](https://github.com/nibzard/decision-model-benchmark)). A behaviour study of 11,621
requests found arithmetic 95/108 correct when the answer was listed first but 62/108 when last, letter
counting 117/216, and on a pathfinding task "direct 0/32, guarded 3/32, pathfinding baseline 27/32"
([RINNECODER](https://github.com/RINNECODER/jev-behavior-study)).

**Choose deterministic code over jev when** the signal is lexical, numeric, calendrical, an
identifier, or an exact written policy; when the rule is auditable and must not move; when position
in a string is the evidence. Before concluding jev beat your regex, check the regex for the
`20250429` class of bug.

**Choose jev over rules when** the rule list has grown past the point where anyone can enumerate the
cases, when paraphrase defeats keywords, or when you need a graded answer rather than a boolean. The
strongest pattern is both: regex finds candidate spans, jev picks the right one, code normalises it.

---

## 7. Classical ML on structured features

Logistic regression and gradient-boosted trees need labels and a feature table, and give you
sub-millisecond inference, native calibration and full auditability. The interesting configuration is
not jev *versus* them but jev *inside* them.

TypeSafe's autoresearch cookbook runs exactly this. 2,000 wine reviews, 1,200 dev / 800 held out,
predicting critic scores 80-100. An LLM proposes questions, `jev-1.12` answers them per review, and
**CatBoost** (a GBM, not logistic regression) trains on the resulting table: 29 Score questions at two
columns each plus 9 Noul questions at one column = 67 numeric features. Held-out RMSE by arm:
predict the mean 3.088; bag-of-words into the same CatBoost 2.466; ask jev for the score directly
2.145; 18 questions from round 1 = 1.869; **38 questions after five rounds = 1.772**. The loop gain
from round 1 to round 5 is "-0.097 points, 95% CI [-0.147, -0.050]"
([autoresearch_feature_discovery cookbook](https://docs.typesafe.ai/cookbooks/autoresearch_feature_discovery)).
Two things to carry: jev-as-features beat both bag-of-words and asking jev for the answer directly;
and TypeSafe names this as the supported substitute for fine-tuning, since "Jev is not fine-tuned or
LoRA-adapted with customer data" and "the same weights serve every account"
([models](https://docs.typesafe.ai/models)).

**Choose classical ML over jev when** the predictive signal is already in your columns — price,
tenure, counts, timestamps — and the text is incidental.

**Choose jev over classical ML when** the signal is in the prose and you have no way to featurise it.
**Choose both** when you have outcome labels but the inputs are text: jev turns the text into
calibrated numbers and the GBM learns the weighting.

---

## 8. Humans and review queues

**Cost — and the honest admission that almost nobody publishes one.** Per-decision prices from Scale
([scale.com/docs/rapid-or-pricing](https://scale.com/docs/rapid-or-pricing) gives only a three-component
formula and an in-dashboard estimator), Surge and Labelbox are **not published**; Labelbox's pricing
page returned 404 on 2026-09-19. SageMaker Ground Truth's per-object table renders client-side and
serves no dollar values. Amazon Mechanical Turk — the one marketplace with a public rate card, at
"20% fee on the reward and bonus amount", a further 20% on HITs with ten or more assignments, and a
$0.01 per-assignment minimum ([mturk.com/pricing](https://www.mturk.com/pricing)) — **closes on
2026-09-30**, eleven days after this file's verification date
([mturk.com](https://www.mturk.com/); [CNBC](https://www.cnbc.com/2026/08/25/amazon-service-that-jeff-bezos-called-artificial-ai-is-shutting-down.html)).

What is published is labour rates: "$8 - $22 per hour for offshore and nearshore delivery, while
U.S.-based moderation commonly falls around $30 - $75 per hour", with a worked example of 45 seconds
per review and six productive hours in an eight-hour shift
([1840 & Co](https://www.1840andco.com/blog/guide-to-content-moderation-outsourcing), a vendor blog).
At $15/hr and 45 s that is 80 decisions per hour, **about $0.19 per decision or $190 per 1,000** —
a division of an hourly rate by a throughput assumption, which is a modelling choice and not a
published fact. Treat the matrix cell accordingly.

**Latency.** Queue SLAs are **not published** by any labelling vendor. The only public figures are
regulatory: TikTok's DSA Article 15 disclosure for Jul-Dec 2025 reports 714,523 notices of allegedly
illegal content actioned in a **median of 5.83 hours**, 0.98 hours for trusted flaggers, against
220,217,619 actions taken solely by automated means and 14,874,341 involving human review
([aggregated DSA reporting](https://socialmediatransparency.org/blog/what-the-latest-dsa-transparency-reports-reveal-2025-26)).
Hours, not milliseconds, and a roughly 15:1 automation-to-human ratio already.

**Humans are not an oracle.** On 540,000 tweets each labelled independently by three trained native
speakers, three-way hate / offensive / neutral agreement was **Fleiss' kappa 0.50**, range 0.36-0.65
by language; the narrower violent-vs-non-violent split reached pooled Cohen's kappa 0.65
([arXiv:2604.12289](https://arxiv.org/abs/2604.12289)). Any comparison that treats the review queue as
ground truth is comparing a model against a noisy label.

**The gate is the point.** jev's published recipe is to act automatically on high confidence and route
low confidence to a human ([confidence](https://docs.typesafe.ai/confidence)), and the measured payoff
is in the SEC filings cookbook: at a 0.9 cutoff the confident half of 60 filings was right 90% of the
time at the specific group level, while the unconfident half was only 40% right if forced to a group
but 70% right if reported at the coarser division level, turning "39/60 right" into "48/60 useful
answers" ([classification_using_confidence cookbook](https://docs.typesafe.ai/cookbooks/classification_using_confidence)).
Apply that shape to a review queue and you deflect the confident majority at $0.025 per 1,000 and
spend $0.19 each on the rest.

**The caution.** jev's confidence is not uniformly a good triage signal. One benchmark measured
"jev admits [ignorance] on 49.7%, with the worst calibration error measured (ECE 0.246; the LLMs range
0.039-0.122)" on forced-uncertainty items ([nibzard DMB](https://github.com/nibzard/decision-model-benchmark));
another found "Jev's confidence did not rank its own errors better than an LLM's verbalized confidence
on CLINC150 (AUROC 0.734 vs 0.816)" and that "Jev returns confidence exactly 1.0 on 102 of 200 items,
6 of which are wrong" ([ickma2311](https://github.com/ickma2311/jev-baselines-eval)). A third
measured ECE 0.0712 and 0.0505 ([themsquared](https://github.com/themsquared/jev-benchmark)). Calibrate
the threshold on your own data before you size the queue.

**Choose humans over jev when** the decision is the sole safety gate, legally consequential, or so
rare that no model has seen its shape. **Choose confidence-gated jev plus humans over either alone**
when volume is high and the error cost is asymmetric.

---

## 9. Distillation and fine-tuning services

**Read this section's first fact before the prices: this option is harder to buy than it was a year
ago.** OpenAI is winding the platform down. Per its
[deprecations page](https://developers.openai.com/api/docs/deprecations): from 2026-05-07 "Creating
fine-tuning jobs or training is not available to organizations that have not previously run
fine-tuning"; from 2026-07-02 it closed to organisations that had not run fine-tuned inference in the
previous 60 days; and on 2027-01-06 "Active existing customers will no longer be able to create new
fine-tuning jobs". The Evals platform goes read-only 2026-10-31 and shuts down 2026-11-30. The
distillation guide now redirects into
[supervised fine-tuning](https://developers.openai.com/api/docs/guides/supervised-fine-tuning#distilling-from-a-larger-model)
and itself says the platform is winding down. **If you have never fine-tuned on OpenAI, you cannot
start today.** Predibase went the same way by acquisition: it was bought by Rubrik (announced
2025-06-25, [press release](https://www.rubrik.com/company/newsroom/press-releases/25/rubrik-to-acquire-predibase-to-accelerate-agentic-ai-adoption)),
and predibase.com/pricing and docs.predibase.com now redirect to rubrik.com — current Predibase
pricing is **not published**.

**What the remaining vendors cost.** Fireworks Managed Training, per 1M training tokens: models up to
16B $0.50 LoRA SFT / $1.00 LoRA DPO / $1.00 full SFT / $2.00 full DPO; 16.1-80B $3.00-$12.00;
80-300B $6.00-$24.00; above 300B $10.00-$40.00. Crucially Fireworks says it will "serve fine-tuned
models for the same price as base models" — **no inference premium** — against serverless base rates
of $0.10 per 1M for models under 4B and $0.20 for 4-16B
([fireworks.ai/pricing](https://fireworks.ai/pricing); [serverless rates](https://docs.fireworks.ai/serverless/pricing)).
Minimum 3 training examples, maximum 3M, $3 minimum charge
([fine-tuning docs](https://docs.fireworks.ai/fine-tuning/fine-tuning-models)). Together AI charges
$0.34 SFT / $0.84 DPO per 1M training tokens for 0.8-9B models, rising to $5.60-$17.50 for 397B+,
with a $4.00 minimum, and serves Llama 3.1 8B Instruct Lite at $0.14 in / $0.14 out per 1M
([together.ai/pricing](https://www.together.ai/pricing)); a dedicated endpoint for a fine-tune is
billed separately by the minute. OpenAI, for as long as it lasts, charges $1.50 per 1M training
tokens on gpt-4.1-nano and then **2x base rates at inference** ($0.20 / $0.80 against $0.10 / $0.40);
the multiplier is 2x on mini too and 1.5x on gpt-4.1
([OpenAI pricing](https://developers.openai.com/api/docs/pricing)). Labelled-data floors are low on
paper — OpenAI's guide recommends starting with 50 demonstrations, Fireworks accepts 3 — but the
published evidence that small fine-tunes beat frontier models rests on real datasets: LoRA Land
trained 310 models over 31 tasks and reports that "4-bit LoRA fine-tuned models outperform base models
by 34 points and GPT-4 by 10 points on average"
([arXiv:2405.00732](https://arxiv.org/abs/2405.00732)).

**What they offer that jev does not.** Custom weights. A model that has actually seen your taxonomy,
your jargon and your edge cases, that you can version and — on open-weight platforms — export and run
on-prem. jev rules out the customisation: no fine-tuning, no LoRA, no per-customer weights
([models](https://docs.typesafe.ai/models)). On deployment it makes no promise either way — **no
self-hosted or on-premises offering is documented**, which is an absence in the docs rather than a
stated policy against it. A community project exists solely because there is no first-party option
([logan-markewich/jeff](https://github.com/logan-markewich/jeff)).

**What jev offers that they do not.** Zero training data, zero training time, zero retraining when the
taxonomy changes, and probabilities trained to be calibrated (RLCD) rather than fitted on a held-out
calibration set you have to build and maintain. You still need a held-out, workload-specific
validation sample to check that calibration holds — for jev exactly as for a distilled model — because
independent ECE runs 0.045-0.242 by dataset.

**Choose distillation over jev when** the task is frozen, high-volume, and you have or can buy several
thousand labels; when residency or latency forces on-prem; when you need the asset rather than the
service. Prefer an open-weight host (Fireworks, Together) over OpenAI here, both because the weights
are portable and because Fireworks charges no serving premium where OpenAI charges 2x.

**Choose jev over distillation when** the taxonomy is still moving, when the project must ship this
week, or when the questions are many and heterogeneous over the same state — you would need a separate
distilled head per question, and jev takes them all in one call.

---

## 10. Constrained decoding and typed-output libraries

Instructor, Outlines, BAML, Vercel AI SDK `generateObject` and Zod schemas are not competitors so much
as a diagnosis. A codebase that has wrapped its LLM calls in a schema has already admitted that what
it wanted from the model was a typed value, not prose. That is the jev-shaped signal.

**What each actually guarantees, which is not the same thing.**
[Outlines](https://github.com/dottxt-ai/outlines) constrains generation with a finite-state machine
over the tokenizer's vocabulary so an invalid token cannot be sampled, at claimed O(1) per token
([arXiv:2307.09702](https://arxiv.org/abs/2307.09702)).
[Instructor](https://github.com/567-labs/instructor) does **not** constrain decoding: it validates
with Pydantic after the fact and reasks on failure ("Automatic Retries: Built-in retry logic when
validation fails"), so its guarantee is "eventually valid or an exception", bought with extra
round-trips. [BAML](https://github.com/BoundaryML/baml)'s Schema-Aligned Parsing is also post-hoc —
"least cost edit needed to make the model's output parseable by a schema" — and it publishes a BFCL
comparison where SAP beats both native function calling and a Python AST parser on every model
tested, most dramatically gpt-4o-mini at 92.4% SAP against 19.8% function calling
([boundaryml.com](https://www.boundaryml.com/blog/schema-aligned-parsing)).
[Zod](https://zod.dev/) constrains nothing at the model; it is the type the others consume.
**Vercel's `generateObject` is deprecated** as of AI SDK 7 (2026-06-25) in favour of `generateText`
with an `Output` specification, and the swap is not lossless: the maintainers' own tracker records
that `generateObject` requested provider JSON mode while `Output.object()` parses free-form text
client-side, measured at 20/20 against 17/20 over 20 runs of the same prompt
([vercel/ai#12491](https://github.com/vercel/ai/issues/12491)). Note what AI SDK 7 added in its place:
`Output.choice()`, documented as "Useful for classification tasks or fixed-enum answers"
([ai-sdk.dev](https://ai-sdk.dev/docs/ai-sdk-core/generating-structured-data)). That is a Choice
question with an LLM underneath it.

Provider-native modes are the strongest of the family. Anthropic's structured outputs are now out of
beta and explicitly constrained-decoding: "Structured outputs guarantee schema-compliant responses
through constrained decoding: Always valid... Type safe... Reliable: No retries needed for schema
violations"
([platform.claude.com](https://platform.claude.com/docs/en/build-with-claude/structured-outputs)) —
with the caveats that recursive schemas, numeric bounds, string length and regex `pattern` are
unsupported, the first request pays grammar-compilation latency, and an injected system prompt makes
"your input token count slightly higher". OpenAI's `strict: true` reports 100% schema compliance
against under 40% for gpt-4-0613 on its complex-schema eval, but the current docs are hedged — a
refusal, a token-limit truncation or a content filter all break compliance, and "a refusal does not
necessarily follow the schema you have supplied"
([OpenAI structured outputs guide](https://developers.openai.com/api/docs/guides/structured-outputs)).
The independent measurement is harsher still: on real-world schemas, OpenAI's json_schema mode had
empirical coverage of 0.89 on GlaiveAI but **0.29 on GitHub-Easy and 0.12 on GitHub-Medium** — it
refuses most real schemas outright, while complying perfectly with the ones it accepts
([JSONSchemaBench, arXiv:2501.10868](https://arxiv.org/abs/2501.10868)).

**Does the constraint cost accuracy? The published evidence is split, and the split matters here.**
The EMNLP 2024 paper is the origin of the worry — "a significant decline in LLMs reasoning abilities
under format restrictions" ([arXiv:2408.02442](https://arxiv.org/abs/2408.02442)) — but the same paper
found format restriction *improved* classification accuracy. Two follow-ups push the other way.
JSONSchemaBench measured downstream accuracy going **up** under constraint: Last Letter 50.7% to 54.0%
with Guidance, Shuffle Objects 52.6% to 55.9%, GSM8K 80.1% to 83.8%, concluding "constrained decoding
consistently improves the performance of downstream tasks up to 4%"; it also found engine choice
dominates, with Guidance at 6.37-7.57 ms per output token against an unconstrained baseline of
15.40-16.68 and Outlines at 30.3-46.6 ([arXiv:2501.10868](https://arxiv.org/abs/2501.10868)). A 2026
reconciliation attributes the damage to spare capacity: Claude Sonnet lost nothing on MATH-Hard
(88.7% JSON against 89.3% chain-of-thought) while **Claude Haiku lost 36.2 points and GPT-4o-mini
28.0 points** under JSON, with 80-87% recoverable by reasoning first and formatting after
([arXiv:2606.09410](https://arxiv.org/abs/2606.09410)). Read that as the warning it is: **the format
tax lands hardest on exactly the small, cheap models a cost-driven design would reach for.**

**What none of them guarantee.** That the value is right, that any probability attached to it means
anything, or that the same input gives the same output tomorrow.

**jev's guarantee is the superset on three of four axes**: the schema cannot be violated structurally
rather than by decoding constraint, the probabilities are trained to be calibrated (RLCD) — measured,
not assumed; independent ECE 0.045-0.242 by dataset — and the latency is
114 ms mean / 264-422 ms p50 rather than the host model's. The fourth axis it loses: it cannot
generate, so any field in your Zod schema that holds free text has to stay on an LLM or come from
code. One independent evaluation makes the "no hallucinations" claim precise: it was "true for all
1,800 Jev calls; also true for all 1,800 Terra calls under a strict JSON schema"
([4esv/jev-eval](https://github.com/4esv/jev-eval)), and TypeSafe itself says of its 0% hallucination
plot that "Our number is not empirical."

**Choose the library over jev when** the object has any generated string field, or when you need one
call to both decide and write. **Choose jev over the library when** every field in the schema is an
enum, a level or a boolean — at which point the LLM underneath is being paid 56-280x to do arithmetic
on logits you could get calibrated.

---

## Decision tree

Start with the output, not the model.

**Is the answer computable?** If the decision reduces to a comparison of dates, a sum, a count, a
pattern match, an identifier check or a written policy, write code. It is free, instant, exact and
auditable, and the published record shows jev losing to exactly these baselines. Only if the code
cannot see the signal do you continue.

**Does the answer contain text you have to generate?** If any part of the output is a sentence a human
will read, you need a generative model. Size it by how hard the reasoning is: small LLM if the
judgement is easy, frontier if it is not. jev is out of scope entirely — it does not generate.

**Do you have labels?** If you have a few thousand labelled examples, a stable taxonomy and enough
volume to justify a GPU, fine-tune an encoder. The measured gap is large in your favour: +10.1 points
over jev on Banking77 at 10 ms and no marginal cost. If the taxonomy changes monthly, or you have 8
examples rather than 8,000, skip this branch — retraining cadence is the hidden cost.

**Is it retrieval?** If the job is narrowing thousands or millions of candidates, that is embeddings
and a vector index, full stop. jev's state is 32k tokens and Choice caps at 255 options. Once the
shortlist is down to tens, the reranking question reopens: a reranker for topical similarity, jev for
a criterion.

**What is left is jev's territory**: a single-hop semantic judgement, bounded output, no labels, on a
request path, at volume, where you want to act on the confident cases automatically. Now check one
disqualifier and two conditions.

- **Disqualifier — multi-hop or double negatives.** The docs say accuracy falls. No rewrite recovers
  this within a single question.
- **Condition — non-English.** Supported at lower accuracy, and the docs say test on your own content
  first ([models](https://docs.typesafe.ai/models)). Independent results are mixed by language and
  task (Korean reading held at 96 against 97 English; Korean medical QA dropped to 80 against
  gpt-5.6-luna's 88; 24 Norwegian documents scored 20/24 stance and 19/24 substance —
  `gt-evidence-independent`). Evaluate per language rather than treating jev as English-only.
- **Condition — more than 255 options.** The API returns `400 Too many choices` at 256, and TypeSafe
  publishes three rewrites around it: hierarchical Choice with beam search, shortlist-then-Choice
  (retrieval narrows first), and two-stage Score-then-Choice (`df-rewrites`,
  [hierarchical_classification cookbook](https://docs.typesafe.ai/cookbooks/hierarchical_classification.md)).
  Compare those against the frontier-LLM option instead of auto-rejecting jev.

**Then decide what to do with the confidence.** If you can define a low-confidence path (a coarser
label, a second question, a human), jev's calibration is the reason to prefer it over a same-priced
nano model. If everything must be decided automatically with no escape hatch, the calibration buys you
less, and the choice collapses to accuracy and price on your own eval — which you should run, because
the independent measurements disagree with each other and with the vendor.

**Finally, shadow it.** Every number in this file was measured on someone else's data.

---

## Sources

All URLs accessed **2026-09-19** unless otherwise noted.

**jev, first-party**
- https://docs.typesafe.ai/models — price $42/Btok, $0.042/Mtok, output free; 64k context / 32k state; 250,000 tokens/s and 1,200 req/min; no fine-tuning; English primary
- https://docs.typesafe.ai/model-jaggedness/jev-1.13 — failure modes (last reviewed 2026-09-17)
- https://docs.typesafe.ai/primitives/choice — 255-option cap
- https://docs.typesafe.ai/primitives/score — 2 to 10 levels
- https://docs.typesafe.ai/confidence — confidence-band policy guidance
- https://docs.typesafe.ai/cookbooks/consistency_choice_cookbook — 114 ms mean; probability SD 0.0098 vs 0.0245-0.0543
- https://docs.typesafe.ai/cookbooks/parallel_questions — 12.2x cheaper, 10.0x faster batched (primitives.md states 11.5x / 9.6x for the same run)
- https://docs.typesafe.ai/cookbooks/hierarchical_classification.md — beam search matched 4 of 4 expected leaves, greedy 2 of 4 at K=3
- https://docs.typesafe.ai/cookbooks/rerank_typesafe — BM25 + jev, top-1 5%→18%, top-10 38%→62%, $0.0645/1,200 calls
- https://docs.typesafe.ai/cookbooks/classification_using_confidence — 0.9 cutoff, 48/60 vs 39/60
- https://docs.typesafe.ai/cookbooks/autoresearch_feature_discovery — jev features + CatBoost, RMSE 3.088 → 1.772
- https://docs.typesafe.ai/cookbooks/date_extraction_cookbook — model reads, code computes
- https://docs.typesafe.ai/cookbooks/entity_alignment — routing split only, no baseline F1
- https://evals.typesafe.ai/ — vendor eval, 67.8%, $0.0004, 0.4 s (agreement with frontier average, not ground truth)

**jev, independent**
- https://github.com/nibzard/decision-model-benchmark — 76.3% banking77, p50 264-276 ms, `400 Too many choices` at 256, ECE 0.246, 13% position-bias flips
- https://github.com/ickma2311/jev-baselines-eval — encoder 0.933 vs jev 0.832 (+10.1pp), 0.01 s vs 0.44 s median
- https://github.com/bitnovus/jev-spam-eval — TF-IDF logistic regression 98.87% vs jev 98.64%
- https://github.com/4esv/jev-eval — ECE 0.11/0.20/0.04 vs Terra 0.08/0.30/0.02; 1.7-3.3% non-determinism
- https://github.com/RINNECODER/jev-behavior-study — arithmetic 95/108 vs 62/108 by answer position; counting 117/216
- https://github.com/themsquared/jev-benchmark — p50 421.6 ms / p95 542.0 ms, ECE 0.0712
- https://empryo.com/blog/jev-and-the-harness — three decisions discarded to deterministic code; 78.6% → 74.1%; keyword counting 26% vs jev 15%
- https://arize.com/blog/typesafe-jev-llm-judge/ — restatement of vendor eval against Opus 5 and GPT-5.6 Terra

**Model prices**
- https://platform.claude.com/docs/en/about-claude/pricing
- https://developers.openai.com/api/docs/pricing
- https://ai.google.dev/gemini-api/docs/pricing
- https://api-docs.deepseek.com/quick_start/pricing
- https://console.groq.com/docs/models
- https://fireworks.ai/pricing and https://docs.fireworks.ai/serverless/pricing and https://docs.fireworks.ai/fine-tuning/fine-tuning-models
- https://www.together.ai/pricing
- https://developers.openai.com/api/docs/deprecations (fine-tuning wind-down dates; Evals shutdown 2026-11-30)
- https://www.rubrik.com/company/newsroom/press-releases/25/rubrik-to-acquire-predibase-to-accelerate-agentic-ai-adoption (Predibase acquisition; current pricing **not published**)
- https://arxiv.org/abs/2405.00732 (LoRA Land: +34 points over base, +10 over GPT-4 on average)
- https://docs.voyageai.com/docs/pricing
- https://aws.amazon.com/bedrock/pricing/ and https://docs.aws.amazon.com/bedrock/latest/userguide/rerank-pricing.html
- https://cohere.com/pricing (Classify and Rerank 4 per-call prices **not published** as of this date)
- https://instances.vantage.sh/aws/ec2/g5.xlarge
- https://www.mturk.com/pricing and https://www.mturk.com/ (MTurk closes 2026-09-30)
- https://www.cnbc.com/2026/08/25/amazon-service-that-jeff-bezos-called-artificial-ai-is-shutting-down.html
- https://scale.com/docs/rapid-or-pricing (formula only, no dollar figures)
- https://www.1840andco.com/blog/guide-to-content-moderation-outsourcing (vendor blog; hourly rates and a 45 s/review worked example)
- https://arxiv.org/abs/2604.12289 (Fleiss kappa 0.50 among three trained annotators, 540,000 tweets)
- https://socialmediatransparency.org/blog/what-the-latest-dsa-transparency-reports-reveal-2025-26 (TikTok median 5.83 h; 220M automated vs 14.9M human-reviewed actions)

**Latency benchmarks**
- https://www.digitalapplied.com/blog/ai-model-latency-benchmarks-2026-ttft-throughput (April 2026; 1,024-token input, 256-token output, 10,000 probes per pairing)
- https://artificialanalysis.ai/models/claude-4-5-haiku/providers (10,000-token input methodology)
- https://zeroentropy.dev/articles/lightning-fast-reranking-with-zerank-1/ (competitor benchmark of Cohere Rerank 3.5)

**Classifiers, encoders, retrieval**
- https://huggingface.co/blog/setfit and https://arxiv.org/abs/2209.11055
- https://www.answer.ai/posts/2024-12-19-modernbert.html and https://arxiv.org/abs/2412.13663
- https://arxiv.org/pdf/2505.22937 (DistilBERT CPU latency)
- https://docs.cohere.com/reference/classify and https://docs.cohere.com/docs/deprecations
- https://huggingface.co/facebook/bart-large-mnli
- https://arxiv.org/html/2603.11991 (zero-shot classification benchmark)
- https://arxiv.org/html/2508.07662v1 (GLiClass)
- https://arxiv.org/abs/2311.08526 (GLiNER) and https://arxiv.org/html/2507.18546v1 (GLiNER2)
- https://arxiv.org/abs/2112.01488 (ColBERTv2) and https://arxiv.org/abs/2205.09707 (PLAID)

**Calibration, determinism, structured output**
- https://arxiv.org/html/2603.09985 (LLM overconfidence, ECE by model)
- https://arxiv.org/abs/2408.04667 (non-determinism at temperature 0)
- https://arxiv.org/abs/2408.02442 (format restriction degrades reasoning, improves classification)
- https://arxiv.org/abs/2501.10868 (JSONSchemaBench: constraints improve downstream tasks up to 4%; per-engine coverage and ms/token)
- https://arxiv.org/abs/2606.09410 (format tax concentrated in small models: Haiku -36.2 pp, GPT-4o-mini -28.0 pp)
- https://blog.dottxt.ai/say-what-you-mean.html (rebuttal to the EMNLP paper; structured wins on all three tasks re-run)
- https://openai.com/index/introducing-structured-outputs-in-the-api/ (100% schema compliance; HTTP 403 on direct fetch 2026-09-19, figures reported via secondary sources)
- https://developers.openai.com/api/docs/guides/structured-outputs (hedged current wording; refusals and truncation break compliance)
- https://platform.claude.com/docs/en/build-with-claude/structured-outputs (constrained decoding guarantee; unsupported schema keywords; grammar-compilation latency)
- https://github.com/dottxt-ai/outlines and https://arxiv.org/abs/2307.09702 (FSM-guided generation)
- https://github.com/567-labs/instructor (retry-based validation, not constrained decoding)
- https://www.boundaryml.com/blog/schema-aligned-parsing (BFCL: SAP vs function calling vs AST parser)
- https://ai-sdk.dev/docs/ai-sdk-core/generating-structured-data and https://github.com/vercel/ai/issues/12491 (`generateObject` deprecated in AI SDK 7; `Output.choice()`; 20/20 vs 17/20 regression)
- https://zod.dev/ (schema definition only, no model-side guarantee)

**Explicitly not published**
TypeSafe p50/p95 latency; any TypeSafe ECE or Brier figure; a TypeSafe region list or data-residency
page; jev self-hosting or on-prem; Cohere Classify pricing and latency; Cohere Rerank 4 per-query
price; Cohere-published Rerank latency of any version; BAAI bge-reranker official latency; a $/1k
figure for self-hosted encoder inference from any vendor; current Predibase pricing (redirects to
Rubrik); Together's LoRA serverless inference price; Fireworks first-party latency figures; per-label
prices from Scale, Surge or Labelbox; SageMaker Ground Truth per-object labour prices (rendered
client-side); any human review queue SLA; a per-decision content-moderation price from an independent
published report.

**Two traps.** TypeSafe's headline 67.8% is agreement with the average of GPT-6 Astra and Fable 5.1,
not ground truth — their own words. And the autoresearch cookbook is widely described as "jev plus
logistic regression"; it is CatBoost, and it ran on jev-1.12, not the current 1.13.
