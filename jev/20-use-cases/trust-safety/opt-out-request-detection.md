---
id: uc-trust-safety-opt-out-request-detection
title: Detect an opt-out or do-not-contact request in a free-text reply
verdict: good
domain: trust-safety
decision_shapes: [detection]
primitives: [noul, choice]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (moderation and trust and safety: "Detect ... opt-out requests"; "Moderate user content and automated conversations across communities, customer support, and SDR workflows")
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 1: write the exact condition; failure mode 8: ask each decision one way)
  - https://docs.typesafe.ai/patterns/confidence-routing.md  (thresholds scale with the stakes of the action)
  - https://docs.typesafe.ai/models.md  (price, latency, English strongest)
related: [uc-sales-marketing-buyer-intent-detection, uc-trust-safety-policy-violation-bands, uc-support-refund-request-detection]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to catch unsubscribe requests in replies?" Also "can jev
detect do-not-contact in an SMS or an SDR reply?", "can we stop emailing people who told us
to stop?", and "can jev handle 'take me off your list' when there is no link click?".

## Verdict

**Good** — the shape is demonstrated by the use-case map's opt-out entry and the
jaggedness page; no task-matched labelled accuracy is published; shadow-evaluate against
the incumbent before acting. This is a single-hop, absolute yes/no about one short text,
the use-case map names opt-out detection explicitly, and the asymmetry of the errors
makes calibration genuinely useful: continuing to contact someone who asked you to stop
is a compliance and reputation failure, while suppressing someone who did not is a small
commercial cost. Set the threshold low, act on it, and you have a materially better
control than the keyword list almost everyone runs. Two disciplines: write the exact
condition (failure mode 1 — "take me off this thread" is not "take me off your list"),
and ask it as one Noul in the direction you will threshold, not as a Noul and a mirrored
Choice (failure mode 8).

## What jev decides

State: the inbound reply text only, plus the channel name if your criteria differ by channel.
Strip quoted history and signatures in code — an old footer containing "unsubscribe" is the
classic false positive, and it is failure mode 5 in miniature.

```
opt_out_requested: Noul
  instructions: {question: "Does the sender ask to stop receiving messages from us?",
                 inspect: "`reply.text`",
                 focus: "Require a request to stop contact, not merely disinterest."}
  criteria:
    true:  {what: "Asks to be removed, unsubscribed, or not contacted again",
            examples: ["Take me off your list", "Please don't contact me again",
                       "Remove this address", "STOP"]}
    false: {what: "Does not ask to stop contact",
            not_for: "Declining this offer, saying it is bad timing, or asking to be
                      contacted less often or later",
            examples: ["Not interested right now", "Try me next quarter",
                       "Can you take me off this thread?"]}

opt_out_scope: Choice
  instructions: "What does the sender ask to stop?"
  criteria: {all_contact: "Any contact from the company, any channel",
             this_channel: "Only this channel, such as SMS or email",
             this_campaign: "Only this campaign, thread, or topic",
             frequency_only: "Wants fewer messages, not none",
             not_an_opt_out: "No request to stop"}

hostile_or_legal_threat: Noul
  instructions: "Does the reply threaten legal action, a regulator complaint, or a spam report?"

wrong_recipient: Noul
  instructions: "Does the sender say they are not the intended recipient?"
```

The scope Choice matters: honouring a channel-specific request as a global suppression loses
contactable customers, and doing the reverse is the compliance failure. Bands: act on
`opt_out_requested >= 0.3` (deliberately low), and treat `hostile_or_legal_threat >= 0.5` as
an immediate global suppression plus a human ticket regardless of scope.

## What stays in code

The suppression list, and everything about it: writing the record, the scope mapping, the
timestamp, the audit trail, and the pre-send check. A statutory keyword ("STOP" on SMS in
many jurisdictions) must be honoured by an exact string rule that runs first and does not
depend on a model. Jev widens coverage beyond that rule; it never narrows it.

## Numbers

Method: `(chars(state) + chars(questions)) / 4 × $0.042/1e6`. A 500-character reply plus
these four questions (~1,300 characters) is ≈ 450 tokens, **≈ $0.000019 per reply**, and
replies are a small fraction of sends, so this is among the cheapest controls available.
Latency 70–500 ms — fast enough to suppress before the next message in a sequence is queued,
which is the actual requirement. No published accuracy for opt-out detection. Build the
evaluation from your own reply archive: label a few hundred replies, and report recall at
your chosen threshold, because recall is the number that has legal consequences.

## When the verdict flips

- The channel has a mandated keyword and your only obligation is to honour it. Then the rule
  is authoritative and jev is a supplement, not a replacement.
- Replies are mostly non-English and unvalidated. Phrasing for "leave me alone" is idiomatic
  and English is `jev-1.13`'s strongest language.
- You make jev the sole gate on a legal obligation. The fit test's counter-signal on legal
  invariants: keep the deterministic rule.
- Volume is low enough that a person reads every reply. Then nothing is gained.

## Alternatives considered

- **Keyword list ("unsubscribe", "stop", "remove me").** Necessary, and insufficient: it
  misses "please stop emailing me, this is the third one" only if badly written, but it fires
  on quoted footers and on "stop by the booth". Keep it, run jev after it.
- **Link-click unsubscribe only.** Handles the compliant path and ignores everyone who replies
  instead, which on SMS and on SDR sequences is most of them.
- **Frontier LLM.** Trivially capable; seconds and cents for a decision you want in the send
  loop.
- **Small LLM.** Fine, at roughly an order of magnitude more latency and cost per call based
  on the consistency cookbooks' measurements.
- **Fine-tuned classifier.** Overkill for a task whose criteria fit on one screen and change
  whenever a new channel is added.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md`, `model-jaggedness/jev-1.13.md` (modes 1, 5, 8),
`patterns/confidence-routing.md`, `models.md`, `jev/10-decision-framework/fit-test.md`
(legal-invariant counter-signal).
