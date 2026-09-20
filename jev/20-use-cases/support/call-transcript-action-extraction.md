---
id: uc-support-call-transcript-action-extraction
title: Pull follow-up actions out of a support call transcript as bounded choices
verdict: conditional
domain: support
decision_shapes: [extraction, classification, detection]
primitives: [noul, choice]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (customer support: "Process call transcripts to extract customer issues, commitments, and follow-up actions")
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 9: "when the answer space is bounded, turn extraction into a Choice over the options rather than asking for the value itself")
  - https://docs.typesafe.ai/cookbooks/function_calling.md  (natural language to a function name as Choice plus closed-set arguments, with per-argument confidence)
  - https://docs.typesafe.ai/cookbooks/pre_parsed_value_extraction_cookbook.md  (regex enumerates candidates; jev picks; code copies verbatim)
related: [uc-support-response-quality-check, uc-support-refund-request-detection, uc-commerce-attribute-extraction]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to extract follow-up actions from call transcripts?" Also
"can jev write the call wrap-up?", "can we auto-create tasks from what the agent promised?",
and "can jev list the commitments made on this call?".

## Verdict

**Conditional**, and the condition is the whole design: jev must not be asked to *list*
actions, only to decide, for each action your system can actually perform, whether the call
committed to it. "List the follow-ups" is generation — failure mode 9, the hardest
disqualifier in the model — and the published rewrite is to turn extraction into a Choice or
a set of Nouls over an enumerated answer space. With a fixed catalogue of, say, 15 follow-up
types, this becomes 15 independent Nouls in one call and is a good fit. Without one, use an
LLM to generate the wrap-up and jev to verify it.

## What jev decides

Code splits the transcript into the segments where the agent speaks (and, for long calls,
into windows), because a 45-minute call exceeds the useful state size long before it exceeds
the 32k limit, and irrelevant turns are failure mode 5.

```
state = {"transcript": [ {"speaker": "agent", "text": "..."}, ... ],
         "actions": ["send_replacement", "issue_refund", "schedule_callback",
                     "escalate_to_engineering", "update_billing_details", ...]}

action_send_replacement: Noul
  instructions: "Did the agent commit to sending a replacement item in `transcript`?"
  criteria:
    true:  {what: "The agent stated a replacement will be sent",
            examples: ["I'll get a new one out to you today"]}
    false: {what: "No such commitment",
            not_for: "The customer asking for one, or the agent saying they will check"}
... one Noul per catalogue entry ...

unresolved: Noul
  instructions: "Did the call end with the customer's issue unresolved and no next step agreed?"

primary_issue: Choice
  criteria: { <your existing issue taxonomy>, other: "Not one of the above" }
```

Values that ride with an action (a date for a callback, an amount for a credit) are
*separate* problems: the date-extraction cookbook's shape is Choice over enumerated month,
day and year with a `not stated` option, assembled in code; the amount is Choice over regex
candidates. Never ask for either as free text.

## What stays in code

Task creation, the catalogue itself, deduplication against tasks already open, and every
value that must be exact. Diarisation, segmenting, and deciding which segments to send are
code. The transcript's own errors are yours to handle: jev reads what the ASR produced.

## Numbers

Method: `(chars(state) + chars(questions)) / 4 × $0.042/1e6`. A 12,000-character agent-side
transcript plus 15 short Nouls and one Choice (~3,000 characters) is ≈ 3,750 tokens,
**≈ $0.00016 per call**. Adding the fifteenth question costs tokens and little extra latency ("barely changes" in the
docs, not zero): the
parallel-questions cookbook measured 13 questions in one request at 12.2x cheaper and 10.0x
faster than 13 sequential requests, with means identical on 11 of 13 questions and within
0.01 on the other two. For a long call, two or three windowed requests, still under
$0.0005. Latency 70–500 ms per request. The function-calling cookbook is the closest
published measurement of this shape (natural language to a bounded call): it reports per-
command confidences from 0.53 to 1.00 across 14 commands and 54 questions per command, and
explicitly reports no ground-truth accuracy scorecard.

## When the verdict flips

- The set of possible actions is open-ended, or the value of the output is a readable
  summary. Then it is generation: **no**, use an LLM, and consider jev to verify the LLM's
  wrap-up field by field (the SDE cascade shape).
- You need a verbatim quote of the promise. Have code locate the span (the Noul tells you
  which action; a keyword or an LLM locates it) — jev selects, it does not copy.
- Audio only, no transcript. Text only.
- Calls in many languages, without a per-language evaluation.

## Alternatives considered

- **Frontier LLM summariser.** The right tool for the human-readable wrap-up, and the wrong
  one for structured task creation, because a hallucinated commitment becomes a real task.
  Best combined: LLM writes, jev verifies each extracted field against the transcript.
- **Keyword spotting on agent phrases.** Catches scripted language, misses everything else,
  and agents do not speak in templates.
- **Small LLM with a JSON schema.** Closest competitor and genuinely capable here; costs
  seconds per call and can still emit an action not in your catalogue. Jev structurally cannot.
- **Fine-tuned span tagger.** Best precision if you have thousands of annotated calls; the
  annotation is the project.
- **Agent fills in a wrap-up form.** Accurate, and the thing everyone is trying to stop doing.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md`, `model-jaggedness/jev-1.13.md` (mode 9 and
its rewrite), `cookbooks/function_calling.md` (confidences 0.53–1.00; no accuracy scorecard),
`cookbooks/pre_parsed_value_extraction_cookbook.md`, `cookbooks/date_extraction_cookbook.md`,
`cookbooks/parallel_questions.md` (12.2x / 10.0x), `cookbooks/sde_cascade.md`, `models.md`.
