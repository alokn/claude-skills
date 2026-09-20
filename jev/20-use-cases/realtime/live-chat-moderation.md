---
id: uc-realtime-live-chat-moderation
title: Moderate live chat messages in the send path with severity and confidence bands
verdict: good
domain: realtime
decision_shapes: [detection, scoring, routing, classification]
primitives: [noul, score, choice]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (Moderation and trust and safety: "Combine severity and confidence to allow, warn, review, or block content."; Gaming: "Moderate chat and detect abuse, toxicity, or suspicious behavior.")
  - https://docs.typesafe.ai/cookbooks/consistency_choice_cookbook.md  (an 8-question moderation rubric over one borderline post; 114 ms mean round trip, $0.000046 per call, sampled 2026-09-11)
  - https://docs.typesafe.ai/cookbooks/llm_guardrails.md  (semantic checks on every input and output; deterministic filters stay authoritative)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 6: "State is data, and `jev-1.13` does not treat it as hostile by default")
  - https://docs.typesafe.ai/models.md  (English is the primary training language; $0.042 per Mtok, output free; 1,200 requests per minute)
related: [uc-realtime-voice-command-intent-risk-scaled-thresholds, uc-realtime-ui-component-selection, df-fit-test, df-rollout, cb-consistency_choice_cookbook, cb-llm_guardrails]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to moderate live chat?" Also asked as "can jev replace our
toxicity library in game chat?", "should every message go through jev before it is
broadcast?", and "can we drop the Perspective API call in the send path?".

## Verdict

**Good.** The use-case map names this shape twice — "Combine severity and confidence to
allow, warn, review, or block content" under moderation, and "Moderate chat and detect
abuse, toxicity, or suspicious behavior" under gaming — and the choice-consistency cookbook
runs exactly this rubric, eight moderation Choices over one borderline post, at a 114 ms
mean round trip. It is good rather than strong for one reason: **jev must never be the sole
gate.** Jaggedness failure mode #6 is the governing one here — "State is data, and
`jev-1.13` does not treat it as hostile by default" — and chat is adversarial by
construction. Your deterministic blocklist stays authoritative and runs first; jev covers
the long tail of meaning that a word list cannot.

## What jev decides

State: the message, a little conversational context, and the author's standing. Not the
whole channel history — failure mode #5.

```
{"message": "<the text being sent>",
 "reply_to": "<the message it answers, or null>",
 "author": {"account_age_days": 38, "prior_strikes": 1}}
```

One Noul per policy dimension (multi-label, so Nouls not a Choice), plus one severity Score,
all in one call:

```
targets_a_person: Noul
  instructions: {question: "Does `message` attack or demean a specific person?",
                 focus: "Require a target, not general profanity."}
  criteria: {true:  {what: "Insults, demeans or threatens an identifiable person",
                     examples: ["you're worthless, uninstall"]},
             false: {what: "No identifiable target",
                     not_for: "Swearing at the game, the map, or the situation",
                     examples: ["this map is garbage"]}}

protected_characteristic: Noul
  instructions: "Does `message` attack someone on the basis of a protected characteristic?"

credible_threat: Noul
  instructions: {question: "Does `message` threaten physical harm to a person?",
                 focus: "Judge in-fiction game violence as false."}
  criteria: {true:  {what: "Threatens real-world harm", examples: ["I know where you live"]},
             false: {what: "In-game violence or hyperbole", examples: ["I'm going to destroy you next round"]}}

off_platform_solicitation: Noul
  instructions: "Does `message` push the reader to a private channel, invite link, or external site?"

scam_or_account_theft: Noul
  instructions: "Does `message` ask for credentials, account details, or payment?"

severity: Score
  instructions: {question: "How severe is the policy problem in `message`?",
                 focus: "Judge harm to the reader, not rudeness."}
  criteria: ["None: nothing a moderator would act on.",
             "Low: rude or mildly hostile; a warning is proportionate.",
             "Medium: sustained harassment, slurs, or a scam attempt.",
             "High: credible threat, child-safety concern, or coordinated abuse."]
```

Code combines them on two axes, severity × confidence, as the use-case map describes.
Sketch: `severity.score >= 2.5 and severity.confidence >= 0.8` → block; `>= 1.5` → hold for
review; `>= 0.5` → deliver with a warning to the author; otherwise allow. Any Noul above
0.85 on `credible_threat` or `scam_or_account_theft` forces the review queue regardless of
the Score. `severity.confidence < 0.5` is the low-confidence path: deliver the message and
queue it for a human, or hold it, depending on which error your product can absorb.

## What stays in code

The deterministic blocklist and the regexes for slurs, invite links and known scam domains
— they run **before** jev, they are authoritative, and jev can only tighten their outcome,
never loosen it. Also: rate limiting, mute and ban state, strike arithmetic, repeat-offender
escalation, the appeal path, the audit log, and the timeout with a fail-open-or-fail-closed
policy you choose per surface. The thresholds live in one module so they can be reviewed
without reading call sites.

## Numbers

Method: `input_tokens ≈ chars(state + questions) / 4`; `cost = tokens × $0.042 / 1e6`,
output free. A 200-character message plus the five Nouls with criteria and the Score
(~2,200 characters of questions) is ≈ 600 tokens ≈ **$0.000025 per message**. The
choice-consistency cookbook's comparable eight-question moderation call cost $0.000046 and
took a 114 ms mean round trip over 15 repeats sampled 2026-09-11; the noul-consistency
cookbook's 14-question call was 111 ms and $0.000043. Rate limits, not cost, are the
constraint at chat scale: 1,200 requests per minute is 20 messages per second per account
by default. Volume is your message rate; do not multiply until you have counted it.
Stability, which matters when the same borderline message can be re-sent: jev's mean
per-label probability standard deviation over those 15 repeats was 0.0098, and under a 0.60
policy its plurality agreement rose from 90.8% to 99.2% with 25.8% of answers routed as
uncertain. No accuracy figure exists for your policy — that is what the shadow run is for.

- Field evidence (community-report): a Discord moderation bot scores messages and escalates on an explicit abstain band, and a Mastra input processor runs the same decision as a pipeline stage before the model sees the message; neither publishes accuracy, 2026-09. Source: https://github.com/brainstormity/Jev-Moderation-Bot

## When the verdict flips

- **Jev is the only gate.** Flips to no. Failure mode #6 is explicit, and a chat user who
  learns the phrasing that scores low has defeated you.
- **Chat is mostly non-English or heavily coded/leetspeak.** English is the primary training
  language; without your own per-language evaluation this flips to conditional at best.
- **Images, voice, emotes, or links whose payload is the content.** Text only. Pre-process
  or route elsewhere.
- **A legal obligation requires a guaranteed outcome** (child-safety reporting, court order).
  Keep that deterministic and authoritative.
- **Your existing classifier is already accurate and cheap on your traffic.** "More
  accurate" is not a claimable property; if the incumbent works, the case is latency, cost
  and your own criteria — measure those or do not switch.

## Alternatives considered

- **Deterministic blocklist / regex.** Exact on the tokens it knows, blind to everything
  else. Keep it; it stays authoritative and it is the reason jev can be advisory.
- **Toxicity library (Perspective, Detoxify).** Fixed taxonomy that is not your policy, and
  no place to express "in-game violence is fine, real threats are not". Jev's criteria are
  your criteria.
- **Small LLM.** 992–3,860 ms per rubric call in the consistency cookbooks, with occasional
  parse failures — too slow for the send path. Uncertainty is not the differentiator: a small
  LLM exposing logprobs can carry the same below-threshold route, and in one 149-row public
  test the difference was only how often each fell below the chosen threshold (jev 34.7%,
  Haiku 2.7%), which is a coverage trade-off.
- **Frontier LLM.** Better judgement, seconds of latency, cents per message. Reserve it for
  the appeal path and the escalated review queue.
- **Fine-tuned classifier.** Strong if you have tens of thousands of labelled moderation
  decisions and a stable policy; brittle the day the policy changes.
- **Human moderators.** Stay, for the review band only — which is the whole point of the
  design.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md` (moderation and gaming chat),
`cookbooks/consistency_choice_cookbook.md` (8-question moderation rubric; 114 ms,
$0.000046, std dev 0.0098, 90.8% → 99.2% agreement, 25.8% uncertain; sampled 2026-09-11),
`cookbooks/consistency_noul_cookbook.md` (111 ms, $0.000043),
`cookbooks/llm_guardrails.md`, `model-jaggedness/jev-1.13.md` (adversarial content),
`models.md` (language support, price, rate limits).
