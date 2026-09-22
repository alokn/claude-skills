---
id: uc-realtime-voice-command-intent-risk-scaled-thresholds
title: Classify in-session intent for a voice or command interface with risk-scaled confidence thresholds
verdict: good
domain: realtime
decision_shapes: [classification, routing]
primitives: [choice, noul]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/patterns/confidence-routing.md  (worked voice-banking example: Choice over check_balance / approve_transfer / other; 0.6 floor to a human; check_balance acts at 0.6; approve_transfer needs > 0.85 or the user is asked to confirm)
  - https://docs.typesafe.ai/confidence.md  ("Thresholds scale with risk"; the same example with a 0.5 floor and 0.9 on the destructive branch; "Start with conservative thresholds, test with your own data")
  - https://docs.typesafe.ai/demos/smart-home.md  (speculative fan-out over a command interface; Noul detects a compound request so an LLM can split it; LLM fallback for conversation)
  - https://docs.typesafe.ai/models.md  (text only — "Pre-process non-text inputs (images, audio, video, binaries) into text"; $0.042 per Mtok, output free)
  - https://docs.typesafe.ai/patterns/fan-out.md  (speculative questions add tokens, not latency)
  - https://github.com/2001Y/jev-axi  (a public CLI reporting a 3-option Choice at "318in/38out 402ms jev-1.13.0 $0.00001")
related: [uc-realtime-live-chat-moderation, uc-realtime-ui-component-selection, uc-realtime-game-decision-from-structured-state, df-fit-test, df-rollout, cb-function_calling]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to work out what a voice command means?" Also asked as "can
jev route our smart-speaker intents?", "should the command palette use jev instead of fuzzy
matching?", and "how do we stop the assistant from transferring money when it misheard?".

## Verdict

**Good** — the shape is demonstrated by the confidence-routing pattern page and the
confidence page; no task-matched labelled accuracy is published; shadow-evaluate against
the incumbent before acting. This is the example TypeSafe uses to teach confidence
itself. The confidence-routing pattern page builds a voice banking interface: a Choice
over `check_balance`, `approve_transfer` and `other`, a 0.6 floor below which everything
goes to a human, `check_balance` acting at that 0.6 because "the worst case is the user
having to listen to the balance read-out", and `approve_transfer` requiring confidence
above 0.85 or else asking the user to confirm. The confidence page carries the same
example with a 0.5 floor and 0.9 on the destructive branch — the two pages differ on the
constants precisely because, as the docs say, "the correct threshold values depend on
your domain". The decision is one semantic read of one short utterance into a small
closed set; code owns every side effect. The closest jaggedness failure mode is #1,
literal reading: a command interface lives on boundary cases ("cancel that" — the
transfer, or the conversation?), so those cases belong in the criteria, not in your
head.

## What jev decides

The input is the **transcript**, not audio: jev is text only and the docs tell you to
"pre-process non-text inputs (images, audio, video, binaries) into text" first. Pass the
transcript plus the minimum session context the disambiguation needs.

```
{"utterance": "go ahead and send it",
 "last_system_prompt": "You have a pending transfer of 400 to M. Okafor. Approve it?",
 "pending": {"kind": "transfer", "present": true}}
```

```
intent: Choice
  instructions: {question: "What action is the user requesting in `utterance`?",
                 focus: "Interpret it against `last_system_prompt`.",
                 compare: ["`utterance`", "`last_system_prompt`"]}
  criteria:
    check_balance:    {what: "Read out the balance of an account",
                       not_for: "Anything that moves money",
                       examples: ["how much have I got", "what's in savings"]}
    approve_transfer: {what: "Confirm the pending transfer described in `last_system_prompt`",
                       not_for: "Agreeing with a statement, or confirming a read-only action",
                       examples: ["yes, send it", "go ahead"]}
    cancel_pending:   {what: "Abandon the pending action",
                       not_for: "Ending the conversation without touching the pending action",
                       examples: ["no, stop", "forget the transfer"]}
    other:            {what: "Anything none of the above describes"}

is_compound: Noul
  instructions: {question: "Does `utterance` ask for more than one distinct action?",
                 focus: "Two actions, not one action with two details."}
  criteria: {true:  {what: "Two or more separable actions",
                     examples: ["check my balance and pay the card"]},
             false: {what: "A single action", not_for: "One action with several parameters",
                     examples: ["turn off all the lights in the house"]}}

transcript_is_garbled: Noul
  instructions: "Does `utterance` read as a mis-transcription rather than a sentence the user said?"
```

Bands, scaled to the action exactly as the pattern page does: below 0.6 confidence on
`intent`, route to a human regardless of which option won; at or above 0.6,
`check_balance` executes; `approve_transfer` executes only above 0.85 and otherwise
triggers "Just to confirm: you would like to approve this transfer, is that correct?";
`cancel_pending` is cheap and reversible, so it shares the 0.6 bar; `other` goes to the
human or the conversational LLM. `is_compound` above 0.6 sends the utterance to an LLM to be
split into atomic commands, each re-classified — the smart-home demo's pattern.
`transcript_is_garbled` above 0.7 asks the user to repeat rather than guessing.

## What stays in code

Every side effect and every invariant: authentication, the pending-action state machine,
the money movement, limits, two-factor, the audit record. The thresholds themselves, per
action, in one module. Wake-word detection, endpointing and ASR. Exact matches short-circuit
the call — if the user said a registered command name verbatim, that is lexical and code
answers it. The confirmation prompt is generated by your templating, not by jev, which does
not generate text.

## Numbers

Method: `input_tokens ≈ chars(state + questions) / 4`; `cost = tokens × $0.042 / 1e6`,
output free. A 60-character utterance plus session context (~150) plus this Choice with
contrastive criteria (~1,100) and two Nouls (~450) is ≈ 440 tokens ≈ **$0.000018 per
utterance**. A public CLI wrapping the same API reports a three-option Choice on a
one-sentence state as "318in/38out 402ms jev-1.13.0 $0.00001", which is the same order for
both cost and latency. Docs latency: 70–500 ms, "most queries about 100 ms"; the consistency
cookbooks measured 114 ms (8 Choices) and 111 ms (14 Nouls) mean round trips on 2026-09-11.
Against a spoken-turn budget that is negligible next to ASR and TTS. Volume is your session
rate; do not multiply until you have counted it. No accuracy figure exists for your intent
set — calibrate on your own logged sessions, where the user's next action (accepted,
corrected, repeated) is a free label.

- Field evidence (community-report): a Home Assistant integration reports "~$0.0001 per voice command at 20 exposed entities" rising to "~$0.0007 at 150", and latency "slower from Europe than the published 70 to 500 ms"; the author's own guidance excludes locks, heaters, alarms and tight control loops, 2026-09. Source: https://github.com/AboveColin/HA-Jev

## When the verdict flips

- **ASR is the bottleneck, not intent.** If the transcripts are wrong, a better classifier
  changes nothing. Measure word error rate first; this is the usual limiting factor.
- **The utterance is a fixed grammar** ("play <track>", a command palette of registered
  names). That is lexical; a parser or fuzzy match wins. Flips to weak.
- **The intent is the sole gate on an irreversible action.** Then the Choice is an input,
  never the authority — the pattern page's own design confirms before transferring even at
  high confidence.
- **Mostly non-English speech**, without your own evaluation.
- **The product has nowhere to put an uncertain utterance.** With no confirm step and no
  human path, forcing everything through the high band throws away the property that makes
  this safe.

## Alternatives considered

- **Deterministic grammar / fuzzy match on registered commands.** Exact, free, and correct
  for verbatim commands — run it first and only call jev on what it misses.
- **Small LLM.** Comparable labels at roughly 600–3,900 ms in the public measurements, plus
  a parse-failure path; and the sub-second public comparison found the small LLM flagged
  uncertainty on 2.7% of rows against jev's 34.7%, which is the signal the risk-scaled
  thresholds run on.
- **Frontier LLM.** Better on genuinely ambiguous phrasing, at seconds per turn. Keep it for
  the conversational fallback the smart-home demo describes, not the command path.
- **Fine-tuned intent classifier (Rasa, DIET).** The traditional answer and a good one when
  the intent set is frozen and you have labelled utterances; jev wins while the intent set
  is still changing, because a new intent is an edited string.
- **Embeddings + nearest utterance.** Needs threshold tuning and confuses `approve` with
  `cancel` on short confirmations, which is the dangerous failure here.
- **Human.** The low-confidence path. Not the default path.

## Sources

Accessed 2026-09-19. `patterns/confidence-routing.md` (voice-banking worked example; 0.6
floor, 0.85 on approve_transfer), `confidence.md` ("Thresholds scale with risk"; the same
example at 0.5 / 0.9; "Start with conservative thresholds, test with your own data"),
`demos/smart-home.md` (speculative fan-out, compound-request Noul, LLM fallback),
`patterns/fan-out.md`, `models.md` (text only; price), `cookbooks/consistency_choice_cookbook.md`
and `cookbooks/consistency_noul_cookbook.md` (114 ms / 111 ms, 2026-09-11),
`github.com/2001Y/jev-axi` (318 input tokens, 402 ms, $0.00001 for a 3-option Choice — a
public report, not a controlled benchmark), `github.com/wotai-dev/typesafe-jev-tools`
(2026-09-18 run: jev flagged 34.7% of rows unsure against Claude Haiku 4.5's 2.7%).
