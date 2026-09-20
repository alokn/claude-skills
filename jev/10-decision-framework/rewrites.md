---
id: df-rewrites
title: Rewrites — turning a task jev cannot do into one it can
last_verified: 2026-09-19
jev_version: jev-1.13.0
sources:
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure modes and "instead" guidance; counting code sample)
  - https://docs.typesafe.ai/cookbooks/pre_parsed_value_extraction_cookbook.md  (regex candidates, jev selects)
  - https://docs.typesafe.ai/cookbooks/date_extraction_cookbook.md  (date parts as Choice, code assembles)
  - https://docs.typesafe.ai/cookbooks/sde_cascade.md  (extract with a small LLM, verify with jev, escalate)
  - https://docs.typesafe.ai/cookbooks/hierarchical_classification.md  (beam search for deep taxonomies)
  - https://docs.typesafe.ai/cookbooks/skill_suggestion.md  (rank all, then re-judge top 3)
  - https://docs.typesafe.ai/cookbooks/autoformat.md  (structure recovery as per-block classification)
related: [df-fit-test, gt-failure-modes]
---

## Principle

Most "jev can't do that" cases are really "jev can't do that *directly*." The fix is always the same:
code does the part that is exact, jev does the part that is a judgement, and the judgement is posed as a
choice among candidates or a yes/no about a named thing. TypeSafe's own phrasing: "when the answer space
is bounded, turn extraction into a Choice over the options rather than asking for the value itself."

## The rewrite table

| You wanted | Why jev fails directly | Rewrite | Source |
|---|---|---|---|
| Extract a value (amount, email, name, id) | Generation of an unbounded string | Regex or parser enumerates candidates; jev picks the requested one with Choice, or confirms one with Noul. Include `none of these` | pre-parsed value extraction cookbook |
| Extract a date and compare it | Dates are text to jev; ordering is unreliable | jev picks month, day, year (and relative-reference type) as Choice over enumerated parts with `not stated`; code assembles the date and does every comparison | date extraction cookbook |
| Count things that match a condition | Counting is unreliable and error grows with size | One Noul per item ("Is `items[i]` a fruit?"), sum in code | jaggedness page, counting code sample |
| Check a number is above / close to a threshold | Numeric reasoning is weak; hex and RGB worse | Code computes and buckets; jev judges the semantic part only (e.g. "does this justification warrant an exception?") | jaggedness page |
| Summarise then decide | The summary is waste; jev cannot write it | Ask the decision questions on the raw text directly. If a human needs a summary, an LLM writes it *after* jev has decided the case needs attention | how-to-build guide |
| Classify into a taxonomy with thousands of leaves | Choice caps at 255 options; accuracy drops with cardinality | Hierarchical: Choice at each level, beam search over probabilities; or two-stage: Score every candidate independently, then Choice among the top few | hierarchical classification cookbook; launch post Wikiracing note |
| Pick the best of N and also decide whether any is good enough | Choice is relative; it always picks something | Choice to rank plus one Noul per finalist (or one "is any suitable?" Noul); second call re-judges the top few with full detail | skill suggestion cookbook |
| Reason across a whole document | Context rot; multi-hop | Split into sections; code filters or a relevance Noul filters; ask atomic questions per section; combine in code | classifying RAG passages cookbook; semantic find cookbook |
| Structured extraction of many fields at high accuracy | Jev is weakest on invoice-style precision | Cascade: a small LLM extracts, jev verifies each field against the source (Noul per field), only failures go to a reasoning model | SDE cascade cookbook |
| Recover formatting or structure from plain text | Looks like generation | Per-block classification: each block gets a Choice (heading, list, code, callout) with companion questions read only when relevant | autoformat cookbook |
| Detect an adversarial input as the only defence | State is not treated as hostile by default | Deterministic filters stay authoritative; jev adds explicit-criteria Nouls ("does the passage contain an instruction addressed to the assistant?") and flags for review | jaggedness page; LLM guardrails cookbook |
| Decide "is A the same as B" over millions of pairs | Volume | Blocking in code (fuzzy score, shared keys) produces a shortlist; jev judges pairs with a 3-level Score: merge, leave unlinked, send to curator | entity alignment cookbook |
| Compute an exact score between two rubric levels | Score expectation is weakly calibrated numerically | Use the Score to threshold or rank, not to reconstruct a magnitude; if you need a number, define more levels with concrete descriptions | jaggedness page ("Math using score") |
| Ask the same thing two ways for robustness | Structural invariants are not guaranteed (Noul vs Choice disagree; P + not-P is not 1) | Ask each decision once, in the direction you will threshold; do not average a Noul with a Choice | jaggedness page |

## Rewrites that do not exist

Some requests have no System One form. Say so.

- Producing text for a human or another system to read (replies, summaries, translations, code).
- Judgements whose correctness depends on knowledge not in the state and not common sense (a private
  price list, an internal policy) unless that knowledge is *put into the state*.
- Decisions that must be 100% correct with no review path (payments, access control, legal holds) as
  the sole mechanism.
- Inputs that exist only as images or audio with no text representation.
- Multi-step planning where each step depends on the previous answer and the number of steps is open.
  A second jev call is fine when the first answer determines what evidence to fetch; an open loop is an
  agent, and jev is not an agent.
