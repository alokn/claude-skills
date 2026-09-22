# Corpus schema and editorial rules

This corpus is retrieval ground truth for one question: **"Is it a good idea to use jev for X?"**
Every file must let a model answer that question for a specific X with a verdict, the reason, the shape of
the solution, what stays in code, the numbers with sources, and when the verdict flips.

## Directory layout

| Path | Contents |
|---|---|
| `00-ground-truth/` | Facts about jev: what it is, API, primitives, limits, price, confidence, failure modes, training, evals, company, ecosystem. Verbatim quotes with URLs. No opinions |
| `10-decision-framework/` | How to decide: fit test, alternatives comparison, rewrites, cost model, rollout, FAQ |
| `20-use-cases/<domain>/` | One file per validated use case where jev fits (verdict strong / good / conditional) |
| `30-anti-use-cases/` | One file per case where jev does not fit or is the wrong tool (verdict weak / no), each with the rewrite if one exists |
| `40-cookbooks/` | One file per official TypeSafe cookbook: task, decomposition, numbers, lessons |
| `50-sources/` | Every source URL with access date and what it supports; changelog of corpus edits |
| `index.json` | Machine-readable index of every entry (id, path, title, verdict, tags, evidence level) |

## Verdict scale (use exactly these words)

| Verdict | Meaning |
|---|---|
| **strong** | Passes the fit test AND a task-matched measurement exists with labelled ground truth and a stated sample size (an independent benchmark, or one of the few official cookbooks that report task accuracy on a labelled dataset). Still shadow-evaluate on your own data before acting |
| **good** | Passes the fit test; the shape is demonstrated by an official cookbook or docs example, or the mechanism is clear, but no task-matched labelled measurement exists. A demonstration proves API feasibility, not accuracy. Do it as a shadow trial first |
| **conditional** | Fits only after a rewrite or with a constraint (code does the arithmetic, candidates pre-parsed, English only, deterministic gate stays). State the condition |
| **weak** | Technically possible but a better tool exists or the gain is negligible. Say what to use instead |
| **no** | Not a System One task (generation, math, dates, images, multi-hop, sole safety gate) or determinism is correct. Say why and what to do instead |

## Evidence levels (use exactly these words)

`evidence_level` records **provenance**, not strength: `official-cookbook`, `official-docs`,
`independent-benchmark`, `community-report`, `inferred`. An entry's level is the *weakest* link in its
chain of claims, and `inferred` entries must say so in the first paragraph. Evidential **strength** is a
separate judgement that the Numbers section must make explicit: task match, sample size, whether labels
were human ground truth or another model's output, preregistration, reproducibility, and conflict of
interest. A vendor demonstration on one document does not outrank a preregistered independent benchmark
because it is "official". `Field evidence` bullets appended under Numbers are supporting context and do
not change `evidence_level`; the level tracks only the claims the verdict rests on. If field evidence
contradicts the verdict, change the verdict and record why in `50-sources/changelog.md`.

### Optional field: `verdict_as_asked`

When the question people actually ask ("use jev to decide X") gets a different verdict from the
labelled proposal the entry describes ("code decides X; jev advises"), the frontmatter carries both:
`verdict_as_asked: no` (the literal question) and `verdict: conditional` (the proposal). The Verdict
paragraph leads with the as-asked answer. The FAQ shows both. Retrieval on `verdict` alone must never
be read as an answer to the literal question when `verdict_as_asked` is present.

## Use-case / anti-use-case entry template

```markdown
---
id: uc-<domain>-<slug>            # anti-use-cases: au-<slug>
title: <imperative, specific>
verdict: strong | good | conditional | weak | no
domain: <support | trust-safety | search | sdlc | agents | finance | ... >
decision_shapes: [classification, detection, scoring, routing, ranking, verification, extraction, search, retrieval, feature-extraction]
primitives: [choice, score, noul]
evidence_level: official-cookbook | official-docs | independent-benchmark | community-report | inferred
sources:
  - <url>  (<what it supports>)
related: [<ids>]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question
"Is it a good idea to use jev to <X>?" plus the 2-3 phrasings people actually use.

## Verdict
One paragraph. Verdict word first, **for the question as asked**. The single most important reason. If a
different design would fit (deterministic gate kept, candidates pre-parsed), give the verdict for the
question as asked first, then introduce the rewrite explicitly as a separate proposal with its own verdict.
Never let a silent rewrite soften a "no".

## What jev decides
(Anti-use-cases title this section "## What jev would get wrong" instead.)
State shape (only the fields needed). 2-8 questions with type, instructions, criteria. Which answer
drives which branch. Confidence bands and the low-confidence path.

## What stays in code
Filtering, arithmetic, dates, lookups, side effects, the authoritative rule if any.

## Numbers
Per-call tokens and cost (method shown), latency, any measured accuracy or agreement WITH SOURCE.
Never a monthly figure without a sourced volume. Never an accuracy claim without a source.

## When the verdict flips
Concrete conditions that turn this into weak/no (or, for anti-use-cases, into conditional).

## Alternatives considered
Regex / deterministic, small LLM, frontier LLM, fine-tuned classifier, embeddings, human. One line each: why jev wins or loses here.

## Sources
Repeat of frontmatter sources with access date.
```

## Cookbook entry template

```markdown
---
id: cb-<slug>
title: <cookbook title>
url: https://docs.typesafe.ai/cookbooks/<slug>.md
decision_shapes: [...]
primitives: [...]
last_verified: 2026-09-19
---
## Task
## Decomposition (state, questions, how answers are combined)
## Numbers reported (verbatim, with what they compare against and the run date if given)
## Caveats the cookbook itself states
## Lessons transferable to other use cases
## Use-case entries this supports
```

## Editorial rules

1. **Verbatim or paraphrase, never invent.** Numbers, limits, and prices are quoted with a URL. If you
   cannot find a source, write "not published" rather than estimating.
2. **Direction of claims.** Jev's claimable properties: typed output (schema cannot be violated);
   probabilities that are *trained to be* calibrated (RLCD), with calibration to be measured on the
   target distribution because independent ECE ranges from 0.045 to 0.242 by dataset; a confidence value
   your code can route on (jev does not "abstain"; abstention is a developer-defined threshold policy);
   about 100 ms typical latency as reported in TypeSafe's examples and several independent medians
   (264-455 ms), not an SLA; $0.042 per million input tokens with free output; many questions per call
   with low incremental latency. **Accuracy is not a claimable
   property** unless a specific source measured it for a specific task; TypeSafe's own evals place jev
   mid-table (67.8%) on agreement with a two-model reference, not on human ground truth, and publish no
   abstention curve. **Run-to-run consistency is not a differentiator
   either**: TypeSafe's own self-consistency (choices) cookbook shows `claude-haiku-4-5` at temperature 0
   more repeatable than jev (100.0% vs 90.8% raw), and notes repeatability does not imply correctness.
   Most cookbooks are worked demonstrations, not benchmarks; only five report task accuracy on a real
   dataset. Say which kind a cited cookbook is.
3. **Failure modes are first-class.** Every use case names which of the nine jaggedness failure modes
   is closest and how the design avoids it.
4. **Alternatives are named honestly.** Where a regex, a fine-tuned encoder, or a deterministic rule
   wins, say so. Public evaluations rejected several jev proposals on exactly this basis.
5. **Freshness.** Every file carries `last_verified` and `jev_version`. Facts are pinned to the docs as
   read on that date. `50-sources/changelog.md` records re-verification.
6. **One idea per file; link with `related`.** Retrieval works on focused chunks.
7. **No marketing language.** "Two orders of magnitude" is a quote from a source or it is not written.
8. **British or American spelling is fine; be consistent within a file.**
