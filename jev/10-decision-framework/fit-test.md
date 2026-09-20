---
id: df-fit-test
title: The System One fit test — deciding whether a task belongs to jev
last_verified: 2026-09-19
jev_version: jev-1.13.0
sources:
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  (design steps; "use code when you can")
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (nine failure modes)
  - https://docs.typesafe.ai/models.md  (limits: text only, 64k/32k context, 255 options)
  - https://docs.typesafe.ai/primitives.md  (Score 2-10 levels; question independence)
  - https://docs.typesafe.ai/confidence.md  (three bands; thresholds scale with risk)
related: [df-rewrites, df-alternatives, df-cost-model, df-rollout, gt-failure-modes]
---

## What this is

Seven yes/no questions that decide whether "use jev for X" is a good idea. They are derived from
TypeSafe's own design guidance and published failure modes, plus the pattern of independent evaluations
that rejected jev for lexical or arithmetic work. Answer them in order; the first hard "no" usually
settles it.

Seven yeses mean the task has the right *shape* and the verdict is at least **good**; **strong** needs,
in addition, a task-matched labelled measurement with a stated sample size (see the scoring table). One
"no" that a rewrite in `rewrites.md` can fix makes it **conditional**. A "no" with no rewrite makes it
**weak** or **no**.

## Question 0: may this service be used here at all?

Before fit, an eligibility gate that the rest of the test assumes is passed. Jev is a hosted, US-hosted,
early-access API (waitlist at the time of writing) with dynamic rate limits, zero data retention on
enterprise plans only, no published SLA, status page, security certification, or data-residency
commitment, and no self-hosted or on-premises offering documented. So ask: Is API access available to
this team? May this data leave the environment, and under which retention tier and DPA? Is US-hosted
processing acceptable for the data's jurisdiction? Can the workflow tolerate 429/529 responses and
regional latency with a tested fallback? Does the required throughput fit 250k tokens/s and 1,200
requests/min, or has an enterprise limit been agreed? Is offline or air-gapped operation required (if so,
the answer is **no** regardless of fit)? Any other "no" here makes the verdict **conditional pending
governance** at best; see `00-ground-truth/limits-pricing-versions.md` and documented don't-adopt decisions in
`00-ground-truth/evidence-independent.md`.

## The seven fit questions

### 1. Is the input text, and does it fit after code has filtered it?

Jev accepts a string, a JSON object, or an array of text values. No images, audio, or video. The limit
is 64k tokens per request and 32k for the state plus the longest single question, roughly 150,000
characters of English. More importantly, accuracy falls as irrelevant material grows ("context rot",
failure mode 5), so the question is not "does it fit" but "after code selects only the relevant fields,
does it fit comfortably."

Yes looks like: a ticket, a record, a diff excerpt, a list of up to a few hundred short candidates.
No looks like: a scanned PDF, a screenshot, a raw log stream, "the whole document."

### 2. Is the output a bounded decision?

Three shapes exist: one option from a set you define (Choice, 2 to 255 options), a position on an
ordered rubric you define (Score, 2 to 10 levels), or a probability that a yes/no statement holds
(Noul). Anything else, including a summary, a rewritten sentence, a free-form extracted value, or a list
of unknown length, is generation and is not what jev does (failure mode 9).

Yes looks like: which queue, how severe, does it request a refund, which of these 40 candidates.
No looks like: what does it say, write a reply, extract the address.

### 3. Is the judgement semantic and single-hop?

Jev is strong at reading comprehension and common-sense judgement over the text in front of it. It is
documented as unreliable at arithmetic, counting, numeric closeness, date ordering and intervals (modes
2 and 3), and at chained inference or double negatives (mode 4).

Yes looks like: does this message express urgency; does the sender name conflict with the email domain;
is this passage relevant to that query.
No looks like: is this older than 30 days; how many items; is 0x3F close to 0x40; would a reasonable
person infer from A and B that C.

### 4. Can the instruction be written so a literal reader gets it right?

Jev "answers the question you wrote, not the one you meant" (mode 1). If you cannot state the exact
condition and put the boundary cases into the criteria, the question is not ready. The test: when you
imagine a wrong answer, can you explain what you really meant? That explanation is the missing half of
the instruction.

### 5. Does code keep control?

TypeSafe's architecture is "AI-powered software": code owns the workflow, filters the state, asks the
questions, combines the answers, owns thresholds and side effects. Jev *selecting* a bounded next action
from a list code enumerated (a function, a skill, a route) is fine and is a documented cookbook pattern.
What fails this question is an open loop: jev choosing its own next step repeatedly with no code-owned
termination, authority, or fallback. The distinction is who owns the loop and the side effects.

### 6. Is there an acceptable low-confidence path, where the answer drives an action?

Choice and Score answers carry a confidence value; Noul answers are probabilities. TypeSafe's guidance is
three bands: act automatically, proceed with caution (confirm, flag, gather more), do not act (human,
clarification, fallback). If an answer triggers an action and the product has no place to put the
uncertain cases, the design is not finished. This question does not apply when the answers are consumed
as *signals* rather than actions: features for a downstream model (autoresearch cookbook), an advisory
ranking, or a score a human reads. There, uncertainty is information, not a routing problem.

### 7. Does volume, latency, or brittleness make the current approach painful?

Jev's advantages are speed (about 100 ms typical in TypeSafe's examples, 264-455 ms medians in
independent runs, more from Europe; not an SLA), price ($0.042 per million input tokens, output free),
schema safety, and a confidence value trained to be calibrated that your code can route on. They matter when the decision runs per request, per event,
or per row; when an LLM's seconds or cents are the blocker; when a keyword list keeps growing; or when
humans review everything. If a human already looks at ten items a day with no latency pressure, the
economic case is weak; jev might still earn a place as a cheap second opinion, for 24/7 coverage, or as a
consistency check, but that is a different and smaller argument.

## Scoring shortcut

| Answers | Verdict |
|---|---|
| 7 yes | good; strong only if a task-matched measurement with labelled ground truth and a stated sample size exists |
| One no on Q1-Q3 with a known rewrite | conditional |
| No on Q2 or Q3 without a rewrite | no |
| No on Q5 or Q6 | no until the design changes |
| No on Q7 only | weak (works, not worth it) |

## Counter-signals that override a "yes"

- **Lexical decision.** Exact token, id, path, status code, enum equality. Deterministic code wins on
  every axis. Independent evaluations rejected jev for grep-line ranking, keyword-frequency tool
  prediction, and status-code routing on this basis (see `00-ground-truth/evidence-independent.md`).
- **A correct deterministic rule already exists.** Do not replace working determinism with judgement.
- **Safety, legal, or money invariant** that must hold every time. Keep it authoritative in code; jev
  can add a second semantic check, never replace the gate. State is not treated as hostile by default
  (mode 6).
- **Non-English at scale** without your own evaluation. English is the primary training language;
  other languages are accepted with lower accuracy.
- **Accuracy is the only argument.** TypeSafe's own workflow evals place jev mid-table (67.8%) on
  *agreement with a two-model reference* (GPT-6 Astra and Claude Fable 5.1 averaged), not on human
  ground truth, under a vendor-written harness. The one independent head-to-head with a small LLM tied on
  accuracy (66.0% each on 149 rows) and differed mainly in how often jev fell below the chosen threshold
  (34.7% vs 2.7%), which is a coverage trade-off, not a virtue in itself. If the incumbent is already
  accurate and cheap, "more accurate" is not a reason to switch.

## Worked examples

| Proposal | Q failed | Verdict | Why |
|---|---|---|---|
| Route support tickets to billing / technical / sales | none | good | Quickstart demonstrates the shape; no labelled accuracy published. Shadow-evaluate against the incumbent |
| Archive issues with no activity for 30 days using jev | Q3 | no | Date arithmetic; the existing rule is correct |
| Detect whether a PR description explains why the change was made | none | good | Noul on (title, body, diff summary); advisory first |
| Summarise the ticket for the agent | Q2 | no | Generation; use an LLM, let jev decide whether a summary is needed |
| Extract the invoice total | Q2 | conditional | Regex finds candidate amounts; jev selects the right one (pre-parsed extraction cookbook) |
| Rerank 30 BM25 hits per query | none | strong for the measured recipe, conditional beyond it | Official 40-query CLERC result (top-1 5% -> 18%) was measured as one Noul per (query, candidate) pair, 30 calls per query, about $0.0016 per query, on legal retrieval over a weak keyword shortlist; that exact recipe is `strong`. A single batched call with one Score per candidate, a strong dense retriever as the incumbent, or another domain is a different, unmeasured design: independent results range from a fused-signal win (+0.064 NDCG@10 with bge-m3) to no standalone gain. Run your own NDCG test before acting |
| Block prompt injection as the only gate | counter-signal | **no** as asked | Adversarial state moves answers (mode 6); injected authority claims collapsed confidence margins in one field test. Separate proposal, jev as an advisory tripwire behind authoritative deterministic controls: conditional (guardrails cookbook) |
| Grade 500 essays 1-10 | Q3 partly | conditional | Score levels must describe concrete situations; use a 4-6 level rubric per dimension, not a 1-10 number |
