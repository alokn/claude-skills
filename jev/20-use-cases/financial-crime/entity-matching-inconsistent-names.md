---
id: uc-financial-crime-entity-matching-inconsistent-names
title: Decide whether two records with inconsistent names are the same entity
verdict: conditional
domain: financial-crime
decision_shapes: [classification, verification, scoring]
primitives: [score, noul]
evidence_level: official-cookbook
sources:
  - https://docs.typesafe.ai/cookbooks/entity_alignment.md  (450 candidate pairs, one 3-level Score plus three field Nouls per pair, jev-1.12 on 2026-08-11, outcome split and cut-point crowding)
  - https://docs.typesafe.ai/concepts/use-case-map.md  (financial crime: "Match entities across inconsistent names, profiles, and records"; "Route ambiguous cases to investigators for review")
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (numbers are arithmetic; Score levels are weak in numerical calibration)
  - https://docs.typesafe.ai/primitives/score.md  (ordered rubric, 2 to 10 levels)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free; 70-500 ms)
related: [uc-financial-crime-kyc-document-classification, uc-financial-crime-alert-prioritisation-by-evidence-quality, cb-entity_alignment, df-rewrites, df-cost-model]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to match customer records with inconsistent names?" Also asked
as "can jev deduplicate our KYC entities?", "can jev replace our fuzzy-name matcher?", and
"can jev do sanctions screening?" — the last of which has a different answer.

## Verdict

**Conditional**, on two constraints. First, code must block: jev judges a shortlist of
candidate pairs that a cheap deterministic pass has already produced, never the cross
product. Second, the merge must be curator-gated, because merging is the expensive,
hard-to-undo mistake. Inside those constraints this is an official cookbook, run end to end:
TypeSafe's knowledge-graph entity alignment "decides which of 450 candidate pairs from two
beer catalogues describe the same product", using "one TypeSafe `Score` question" whose
"three levels are the three things you can do with a pair: merge it, leave it unlinked, or
hand it to a curator." The shape transfers directly to customer records. What does *not*
transfer is the domain: beer catalogues are not sanctions lists, and **sanctions and PEP
screening must stay deterministic and authoritative** — that is a legal invariant, and jev
can only add a second semantic check beside it, never replace it. The closest failure mode is
2: the cookbook itself gives alcohol content no question at all, "because comparing two
numbers is arithmetic; compute it in code if you want it."

## What jev decides

State: the two records side by side as `entity_a` and `entity_b`, carrying only the fields
the questions name, "so the questions are about the *pair* and not about either side on its
own."

```
link_state: Score
  instructions: "How do the two customer records relate?"
  criteria:
    - "They describe two different parties."
    - "They describe closely related parties that may or may not be the same one: a
       relative sharing a surname and address, a former name, a trading style of the same
       company, or a name that could plausibly refer to either."
    - "They describe one and the same party."

same_legal_name: Noul  "Do the two records state the same legal name, allowing for
                        transliteration, initials, and name order?"
same_date_of_birth_as_written: Noul  "Do the two records state the same date of birth as
                        written? Do not compute anything; compare the strings as given."
same_address: Noul     "Do the two records describe the same postal address?"
same_identifier_family: Noul  "Do the two records cite the same kind of official identifier
                        for the same issuing country?"
```

Routing is the rounding, with no threshold constant to fit:

```python
OUTCOME = {0: "leave unlinked", 1: "curator queue", 2: "assert sameAs"}
def route(score_value): return OUTCOME[min(int(score_value + 0.5), 2)]
```

The cookbook's point about the middle level is the one to copy: "The middle level is the one
worth writing carefully," because its wording "is what moves pairs between the curator and
the pairs left unlinked." The three field Nouls ride along in the same request and exist to
tell the curator *which* field the sources disagree on — they are not inputs to the route.

## What stays in code

The blocking pass that produces candidate pairs (fuzzy score, shared identifier, shared
postcode, phonetic key) and the cap on how many pairs a new record generates. All numeric
and date comparison: the cookbook excludes ABV from the questions on exactly this ground, so
exclude date of birth *arithmetic*, age, and identifier checksums too — ask only whether the
strings say the same thing, and compute the rest. Sanctions, PEP and adverse-media screening
against official lists stay deterministic and authoritative and run independently of this
path. The `sameAs` write, its reversal, and the audit record are code.

## Numbers

Verbatim from `https://docs.typesafe.ai/cookbooks/entity_alignment.md`, 450 candidate pairs
from the Magellan Beer collection, one request per pair, "Numbers below came from `jev-1.12`
on 2026-08-11":

```
assert sameAs      40  ( 8.9%)
curator queue      50  (11.1%)
leave unlinked    360  (80.0%)
```

"Nine pairs sit within 0.1 of the upper one, at 1.5, which is the one deciding what gets
merged into the graph. Forty-seven sit that close to the lower one, at 0.5, which only
decides whether a curator sees the pair." Worked pairs include `c446` at score 1.94 /
confidence 0.92 → assert sameAs, `c427` at 0.03 / 0.95 → leave unlinked, and `c100` at 1.30 /
0.27 → curator queue. Precision and recall against the benchmark's own `known_same_as`
labels are **not reported in the cookbook**, so this is not an accuracy claim; the 8.9% /
11.1% / 80.0% split is an outcome distribution.

Your cost: `input_tokens ≈ (chars(state) + chars(questions)) / 4`; `cost = tokens × $0.042 /
1e6`, output free. Two customer records at ~350 characters each plus one Score and four Nouls
(~1,300 characters) is about 2,000 / 4 ≈ 500 tokens, so **≈ $0.000021 per pair**. Calls scale
with pairs, not records — "what you spend follows the number of pairs you were handed rather
than the size of either source" — so the blocking pass is also the cost control. Latency
70-500 ms per pair; at 1,200 requests per minute a large backfill needs a throttle.

## When the verdict flips

- To `no` as a replacement for sanctions screening. A screening hit must be reproducible and
  auditable and must hold every time.
- To `no` if a merge cannot be reversed or if there is no curator queue. The cookbook's
  design exists because "merging two entities inappropriately is the more expensive mistake".
- To `weak` if your records share a reliable identifier (national ID, LEI, verified tax
  number). Then matching is a join and deterministic code wins on every axis.
- To `conditional` on a per-script evaluation for transliterated names (Arabic, Cyrillic,
  Han). This is the hardest part of real name matching and the cookbook's English beer names
  say nothing about it.
- Watch the 11.1%. If your curator queue cannot absorb the middle level, the design does not
  fit yet; widening the middle makes it worse, not better.

## Alternatives considered

- **Deterministic join on an identifier.** Wins outright wherever an identifier exists.
- **Fuzzy string matching (Levenshtein, rapidfuzz, Jaro-Winkler).** Cheap, fast, and the
  right blocking tool; it produces the shortlist. It cannot tell a former name from a
  different person with a similar name, which is the judgement being bought here.
- **Embeddings + cosine threshold.** Replaces judgement with threshold tuning and gives no
  vocabulary for "related but not the same".
- **Commercial entity-resolution engines.** Mature, auditable, tuned for names and addresses,
  and usually the right incumbent in a regulated firm; jev is a supplement to their review
  queue, not a replacement for the engine.
- **Frontier LLM per pair.** Far too expensive at pair volumes and no better on this shape.
- **Human curator on every pair.** The baseline; the design sends 11.1% of the cookbook's
  pairs there instead of 100%.

## Sources

Accessed 2026-09-19. `cookbooks/entity_alignment.md` (450 pairs, level wording, route
function, outcome split, cut-point crowding, ABV exclusion, jev-1.12 on 2026-08-11),
`concepts/use-case-map.md` (entity matching across inconsistent names),
`model-jaggedness/jev-1.13.md` (numbers; Score calibration), `primitives/score.md`,
`models.md` (price, latency, rate limits).
