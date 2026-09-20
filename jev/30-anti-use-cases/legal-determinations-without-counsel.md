---
id: au-legal-determinations-without-counsel
title: Do not use jev to make a legal determination without counsel in the loop
verdict: no
domain: legal
decision_shapes: [classification, verification]
primitives: [noul, choice, score]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/system-one.md  (calibration does not guarantee an individual answer)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 4, indirection; failure mode 1, literal reading; failure mode 5, large state)
  - https://docs.typesafe.ai/models.md  ("Jev is not fine-tuned or LoRA-adapted with customer data"; language support)
  - https://docs.typesafe.ai/confidence.md  ("Low confidence: Do not act")
related: [au-payments-and-access-control-decision, au-private-knowledge-not-in-state, au-multi-hop-and-double-negatives, au-whole-document-in-state]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to decide whether this contract clause is enforceable?" Also "have jev tell
us if this DSAR is in scope for GDPR", "use jev to judge whether the notice period was validly served",
"auto-classify which documents fall under the litigation hold".

## Verdict

**No** as the determination; **conditional** as triage that a lawyer reviews. A legal conclusion is
multi-hop by construction — identify the governing instrument, locate the operative clause, establish the
facts, apply the law, weigh the exceptions — and failure mode 4 says "A question about a property of a
property or something that requires multiple hops of reasoning costs accuracy." Add that "Calibration is
measured across groups of predictions; it does not guarantee that an individual answer is correct", and
the individual case is exactly what a legal determination concerns.

## What jev would get wrong

Legal text is written to be read with intent, and failure mode 1 says jev "answers the question you wrote,
not the one you meant. Scoping words, negations, and implied conditions are read at face value" — which
describes a `notwithstanding` clause, a carve-out, or a double-negative proviso precisely. Jurisdiction
is not in the state unless you put it there, and the models page is clear that "Jev is not fine-tuned or
LoRA-adapted with customer data", so it does not know your governing law, your precedents, or your
counsel's positions. Non-English instruments compound this: "Other languages, including CJK scripts, are
handled but not equally well." A wrong determination arrives as a clean typed answer with a confidence
number, which is worse than an obviously hedged paragraph because it invites reliance.

## What stays in code

Retrieval, scoping, chain of custody, and the record of who decided. Code selects the governing clause
and puts *only that clause* in the state — the whole agreement is a context-rot problem and a multi-hop
problem at once. Code enforces the hold, applies the retention schedule, and logs the human decision.

Jev's defensible role is bounded, single-hop, evidence-locating triage over pre-selected text: a Noul
"Does `clause` state a cap on liability?"; a Noul "Does `clause` name a governing jurisdiction?"; a
Choice over `mutual`, `one_way`, `not_stated` for an NDA's direction; a Score over described levels of
"how clearly does `clause` match the template wording". Each answer points a lawyer at a document; none
of them concludes anything.

## Numbers

A clause-level fan-out over 1,500 tokens with ten questions is roughly 2,200 input tokens, about
$0.00009 at $0.042 per million input tokens with output free (https://docs.typesafe.ai/models.md),
typically about 100 ms. No published source measures jev on legal determinations. TypeSafe's own workflow
evals report 67.8% combined accuracy against Opus 5's 73.1% (https://evals.typesafe.ai, read 2026-09-19);
neither figure is a basis for unsupervised legal conclusions.

## When the verdict flips

It flips to **conditional** when three things hold: the questions are single-hop properties of a
code-selected clause rather than conclusions about a matter; counsel reviews every output before it has
any effect; and the low-confidence band routes to a person rather than to a default, per the confidence
doc's "Low confidence: Do not act. Route to a human, request clarification, or fall back to a different
system." A good conditional use is prioritising a review queue of ten thousand contracts so counsel reads
the risky ones first. **No rewrite exists** for "is this enforceable" as an unattended answer.

## Alternatives considered

- **Regex / deterministic**: clause headings, defined-term detection, signature-block presence, retention
  dates. Exact and free; do these first.
- **Small LLM**: worse at nuance, same accountability problem.
- **Frontier LLM**: better at drafting a memo for counsel to correct; still not the determiner.
- **Fine-tuned classifier**: contract-analytics models trained on labelled clause types are strong for
  clause tagging at scale.
- **Embeddings**: retrieve the governing clause and find near-duplicate language across a portfolio.
- **Human (counsel)**: the decision-maker. Everything above exists to shorten their reading list.

## Sources

- https://docs.typesafe.ai/concepts/system-one.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
- https://docs.typesafe.ai/confidence.md — accessed 2026-09-19
- https://evals.typesafe.ai — accessed 2026-09-19
