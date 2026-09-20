---
id: au-archive-after-n-days-rule
title: Do not replace a correct deterministic rule such as "archive after 30 days of inactivity"
verdict: no
domain: sdlc
decision_shapes: [classification]
primitives: [noul]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  ("Use code when you can"; "Keep deterministic work in code. It is reliable and cheap")
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 3, dates; "Asking the model something code can compute exactly")
  - https://github.com/wotai-dev/typesafe-jev-tools  ("If your code does not branch on the confidence value, none of this matters and you should use what you already have")
related: [au-date-ordering-and-overdue, au-http-status-enum-routing, au-tiny-volume-human-reviewed-workflow]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to decide which issues to auto-archive instead of our 30-day rule?" Also
"make our stale-branch cleanup smarter with AI", "replace the inactivity cron with a jev call", "let jev
decide which records to purge".

## Verdict

**No.** The rule is already correct, and it is made of a date subtraction — the one operation jev is
documented as unreliable at ("`jev-1.13` reads dates as text, not as ordered quantities") and one the
closing reminder tells you not to outsource ("Asking the model something code can compute exactly"). The
first step of TypeSafe's own design guide is "Use code when you can — keep deterministic work in code. It
is reliable and cheap", and its worked example is a `days_overdue` computation in Python.

## What jev would get wrong

The arithmetic, at the boundary, where the rule is defined. Day 29 versus day 31 is the entire semantics
of "30 days", and a model that reads dates as text has no ordered quantity to compare. Beyond the
arithmetic there is a governance cost: a deterministic archival rule is auditable, reproducible, and
explainable to whoever asks why their issue disappeared. Replacing it with a model makes the answer
"the probability was 0.83", moves the policy out of your repository, and makes it liable to change when
the `jev-latest` alias moves to a new version.

## What stays in code

The rule, unchanged. `if (now - record.last_activity).days > 30: archive(record)`. Also the exclusion
list, the dry-run mode, the notification, and the undo window — every part of this workflow is
deterministic and already right.

Jev's only defensible role is as an *exception detector* that runs beside the rule, never instead of it.
Over the records the rule is about to archive, ask a Noul "Does `issue.body` or the last comment describe
work that is blocked on someone else rather than abandoned?", a Noul "Does the thread state a date in the
future by which it will be revisited?", and a Score over described levels of "how costly would archiving
this be to reopen". Code archives everything except the small set jev flags, and a person sees that set.
That design adds value only if someone actually reviews the flagged set.

## Numbers

The cron rule costs $0 and is exact. Screening 500 candidate records at roughly 800 tokens each is about
400,000 input tokens, roughly $0.017 in total at $0.042 per million input tokens with output free
(https://docs.typesafe.ai/models.md) — cheap, but the relevant question is whether the flags change any
outcome. The wotai-dev evaluation puts the test bluntly: "If your code does not branch on the confidence
value, none of this matters and you should use what you already have."
(https://github.com/wotai-dev/typesafe-jev-tools)

## When the verdict flips

It flips to **conditional** when the archival policy stops being a date rule and becomes a judgement —
for example "archive threads that are resolved", where resolution is a semantic property of the text and
no field records it. Conditions: code still computes every date and still owns the final action; jev
answers only the semantic half; there is a review path for the uncertain band; and the change is shadowed
against the existing rule for a period so you can see which records the two disagree on before switching.
If the rule is correct and nobody is complaining about it, **no rewrite is needed** — the honest answer is
to leave it alone.

## Alternatives considered

- **Regex / deterministic**: the incumbent. Correct, free, auditable. Keep it.
- **Small LLM**: adds cost and non-determinism to a solved problem.
- **Frontier LLM**: same, more expensive.
- **Fine-tuned classifier**: only if you have labels for "should have been archived", which you probably
  do not.
- **Embeddings**: no role.
- **Human**: reviews the exceptions jev flags, if and only if someone will.

## Sources

- https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://github.com/wotai-dev/typesafe-jev-tools — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
