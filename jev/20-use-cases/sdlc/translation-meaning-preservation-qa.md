---
id: uc-sdlc-translation-meaning-preservation-qa
title: QA machine-translated UI strings for preserved meaning while code checks the placeholders
verdict: conditional
domain: sdlc
decision_shapes: [verification, detection, scoring]
primitives: [noul, score]
evidence_level: inferred
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (Universal Verification: verify the output of any other AI at a fraction of the cost of the LLM call)
  - https://docs.typesafe.ai/cookbooks/parallel_questions.md  (many questions over one state in a single call: 12.2x cheaper, 10.0x faster than sequential, same answers)
  - https://docs.typesafe.ai/models.md  (English strongest; other languages accepted with lower accuracy; $0.042 per million input tokens, output free)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 9 generation; mode 2 counting)
  - https://docs.typesafe.ai/cookbooks/sde_cascade.md  (cheap model produces, jev verifies each field, only failures escalate)
related: [uc-sdlc-semantic-lint-team-conventions, uc-verification-llm-output-policy-check, cb-sde_cascade, cb-parallel_questions, df-rewrites]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to check AI translations of our UI strings?" Also: "can we catch
a translation that changed the meaning before it ships?", "how do we QA 4,000 locale strings
without a native speaker for each?", "did the translator break the interpolation?".

## Verdict

**Conditional**, on two things. First, **code checks the placeholders** — `{count}`,
`%s`, `<b>…</b>`, ICU plural arms — with a parser, not the model; that is exact, and a
model is the wrong instrument for it. Second, **the target language is one you have evaluated**:
the docs state plainly that English is the strongest language and others are accepted with
lower accuracy, and a meaning-preservation question is read *in* the target language. This
entry is `inferred` — no cookbook or field report covers translation QA. The cascade shape it
follows (cheap model produces, jev verifies each item, failures escalate) is documented.
**Advisory first, gate later:** flag strings for a reviewer; hold the release only on the
deterministic placeholder check, which can be a gate from day one.

## What jev decides

One call per string pair, many questions batched:

```
meaning_preserved: Noul
  instructions: {question: "Does `target` convey the same meaning as `source`?",
                 compare: ["`source`", "`target`"],
                 focus: "Judge meaning, not style or word order."}
  criteria:
    true:  {what: "A reader of the target language would understand the same instruction,
                   claim, or label as a reader of the source"}
    false: {what: "Adds, drops, negates, or changes the subject of the statement",
            not_for: "A natural idiomatic rendering that keeps the meaning",
            examples: ["Source: 'This cannot be undone.' Target: 'This can be undone.'"]}

register_matches:    Noul  "Does `target` use the same level of formality as `source`?"
terminology_kept:    Noul  "Are the product terms listed in `glossary` used in `target`
                            exactly as the glossary specifies?"
is_untranslated:     Noul  "Is `target` still in the same language as `source`?"
truncation_risk: Score
  criteria: ["Similar length to the source.",
             "Noticeably longer; may wrap in a narrow control.",
             "Much longer; will not fit a button or a label."]
```

Put the glossary in the state — it is your private knowledge, and the model must not be asked
to recall it. `truncation_risk` is a judgement about *reading* length, not a character count:
counting is failure mode 2 and code does it exactly, so use the Score only as a soft signal
alongside the exact length the code already measured.

Bands: `meaning_preserved < 0.5` → reviewer queue; `0.5-0.8` → flag in the translation tool;
`>= 0.8` with all other checks passing → ship. The Noul is absolute, so do not assume
`P(preserved) + P(broken) = 1` (failure mode 8); threshold the one direction you wrote.

## What stays in code

**The placeholder check, authoritatively.** Parse both strings, extract the placeholder set and
their order, compare exactly, and fail the build on a mismatch — no probability involved.
Likewise: ICU plural-category coverage for the locale, HTML tag balance and nesting, escaping,
maximum rendered length against the control width, and the locale file schema. Also in code:
which strings changed since the last run, batching, and the reviewer queue.

## Numbers

Method: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. A source and
target of ~120 characters each plus a short glossary excerpt plus five questions with criteria
(~1,500 characters) is about 440 tokens, **≈ $0.000018 per string**. A 4,000-string locale is
**≈ $0.074 per language per full pass**, one call per string, parallelised under the published
rate limits. Batching matters: the parallel-questions cookbook measured 13 questions in one
call at "12.2x cheaper, 10.0x faster" than 13 separate calls with no change in answers, which
is the argument for asking all five checks together rather than five times. Accuracy: not
published, and specifically not published for non-English targets — this is the number you
must generate yourself. Labelled data for calibration: your translation memory's rejected or
corrected segments, and any past locale bug reports, which give you real negatives.

## When the verdict flips

- To **no**, if it is the only gate on a legal, medical, or safety-critical string. Those need
  a qualified human translator; a probability is not a substitute.
- To **weak**, if you already pay for human review of every string. Then jev only reorders a
  queue someone empties anyway.
- Right-to-left, low-resource, or heavily inflected target languages where you have not
  measured. The documented weakness is exactly here.
- If you ask jev to *fix* the translation. That is generation (failure mode 9) and not
  a System One task; route the flagged string to a translation model or a person.

## Alternatives considered

- **Placeholder and schema linters.** Mandatory, free, exact, and they catch the most common
  real defect. Not optional, not replaceable.
- **Round-trip translation (translate back and diff).** Cheap and popular; it flags style
  differences as meaning changes and misses meaning changes that survive the round trip.
- **Frontier LLM as judge.** Better on nuance and it can explain the defect; seconds and cents
  per string, and 4,000 strings per language per release makes that the binding constraint.
  Use it on the band jev flags — the cascade shape from the SDE cookbook.
- **Small LLM.** Comparable and slower. Set the same below-threshold review route on both —
  logprobs are enough to build one — rather than treating "unsure" as jev-only.
- **Fine-tuned quality-estimation model (COMET-style).** The specialist tool for exactly this
  task and a genuinely strong alternative; it produces a score, not a typed set of reasons,
  and it needs per-language training data. If you already run one, keep it.
- **Embeddings (multilingual cosine).** Poor at negation, which is the failure you most want
  to catch.
- **Native-speaker review.** Stays for the flagged band and for anything user-facing and legal.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md` (universal verification),
`cookbooks/parallel_questions.md` (12.2x cheaper, 10.0x faster batched, identical answers),
`cookbooks/sde_cascade.md` (verify-then-escalate), `model-jaggedness/jev-1.13.md` (modes 2, 8,
9), `models.md` (English strongest; other languages lower accuracy).
