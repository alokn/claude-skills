---
id: uc-devices-control-mobile-action-selection-accessibility-tree
title: Pick the next mobile UI action from an Android accessibility tree, behind an action allowlist
verdict: conditional
domain: devices-control
decision_shapes: [classification, routing]
primitives: [choice, noul]
evidence_level: community-report
sources:
  - https://github.com/antiyro/jevdroid  (jev selecting Android actions from the accessibility tree; no numbers published)
  - https://github.com/droidrun/mobile-jev  (mobile agent using jev for action selection; no numbers published)
  - https://github.com/AboveColin/HA-Jev  (integration author's own exclusion list: not for locks, heaters, alarms, or tight loops)
  - https://github.com/RINNECODER/jev-behavior-study  (option position: correct option first 95/108 vs fourth 62/108)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 5 large state; mode 6 adversarial content)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free; text-only input; 70-500 ms)
related: [uc-browser-automation-action-selection-from-accessibility-tree, uc-agents-harness-pre-tool-use-destructiveness, uc-realtime-voice-command-intent-risk-scaled-thresholds, au-payments-and-access-control-decision, au-real-time-from-raw-pixels]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to drive an Android phone?" Also: "can jev pick the next tap from
the accessibility tree?", "can we build a mobile agent without a vision model?", "is this safe
enough to let loose on my banking app?".

## Verdict

**Conditional.** Mechanically this is the browser case with a different tree, and the same
argument holds: code enumerates the interactable nodes, jev picks one and an action verb in
about 100 ms. The condition is that **the set of actions jev may name is an allowlist defined in
code, per app**, and anything that spends money, sends a message, deletes data or grants a
permission requires an explicit human confirmation regardless of confidence. Nothing has been
measured on mobile — both public projects publish a design, no accuracy, no latency, no cost —
and the action surface on a phone reaches real money and real people in one tap. Without the
allowlist this is not conditional, it is reckless.

## What jev decides

Code flattens the `AccessibilityNodeInfo` tree to visible, enabled, clickable nodes and emits a
deterministically ordered, numbered list: index, class, content description or text, and whether
it is focusable or scrollable. The current app package, the task goal and the last action's
result complete the state. Nothing else — a full node dump is failure mode 5.

```
action_verb: Choice over the per-app allowlist
  instructions: {question: "What should the agent do next to advance `goal` on this screen?"}
  criteria:
    tap:        {what: "One listed element must be activated to advance"}
    set_text:   {what: "A listed input must receive text first"}
    scroll:     {what: "The element that would advance the goal is not listed yet"}
    back:       {what: "This screen cannot advance the goal"}
    done:       {what: "`goal` is already satisfied by what this screen shows"}
    ask_user:   {what: "The next step is irreversible, ambiguous, or outside the allowlist"}

target_index: Choice over the enumerated node indices
  instructions: {focus: "Choose by what the control does, not by where it appears."}

is_sensitive_screen: Noul
  instructions: "Does this screen show a payment, a message composer, a permission prompt, an
                 account deletion, or a credential field?"
```

`ask_user` must exist as a first-class option. Without it a Choice is relative and will name the
least-bad tap on a screen where the honest answer is "stop".

Bands: act only above the floor you fitted on your own labelled traces, and only when
`is_sensitive_screen` is low and the verb is on the allowlist. Anything else goes to
confirmation. On timeout or low confidence the agent stops and asks — never guesses.

## What stays in code

The allowlist itself, per app package. Tree extraction, visibility filtering, node ordering,
the gesture dispatch, the step budget, screenshots for the audit log, and the post-action check
that the screen actually changed. Every irreversible action — pay, send, delete, uninstall,
grant permission, change a password — is a code-side confirmation dialogue, not a probability.
Amounts, balances and dates are read by code and never compared inside a question (modes 2 and
3).

## Numbers

**None published.** Neither https://github.com/antiyro/jevdroid nor
https://github.com/droidrun/mobile-jev reports accuracy, latency or cost, so no measured claim
belongs here. What transfers is the shape and the price. Cost method: `input_tokens ~= chars/4`,
`cost = tokens x $0.042 / 1e6`, output free. A 25-node screen at ~60 characters per node (1,500)
plus goal, app context and criteria (~1,800) is about 825 tokens, **~$0.000035 per step**.
Published latency envelope: "70 to 500 ms", "most queries about 100 ms" — but the Home Assistant
integration author reports latency "slower from Europe than the published 70 to 500 ms", so
measure from where the device actually is.

The measured risk that transfers directly is option position: a synthetic probe over 11,621
requests found the correct option chosen "95/108" when listed first versus "62/108" when listed
fourth (https://github.com/RINNECODER/jev-behavior-study). Order nodes by traversal order every
time.

Closest failure mode: **6, adversarial content.** A phone screen renders text from notifications,
ads and messages written by other people; "tap here to continue" inside an interstitial is an
injection. The allowlist plus `is_sensitive_screen` is the mitigation. Runner-up is **5**, handled
by filtering the tree.

## When the verdict flips

- **No allowlist, or the allowlist includes an irreversible verb.** Then it is a `no`. The Home
  Assistant author drew the same line for locks, heaters and alarms.
- **The screen needs pixels** — a canvas, a map, a captcha, an unlabelled icon grid with no
  content descriptions. Jev takes text only.
- **The app deliberately obscures its accessibility tree.** Garbage in.
- **You need an audit trail of reasoning.** There is no chain of thought to log; log the state,
  the options and the probabilities instead, and accept that they are not an explanation.

## Alternatives considered

- **Recorded UI scripts / Appium selectors.** Exact, free, fast, and correct until the app
  updates. Keep them for the paths that matter.
- **Vision-language mobile agents.** Handle unlabelled UI and canvas; seconds and cents per
  step. The reason to try jev at all.
- **Frontier LLM over the same tree.** Better at planning and recovery; too slow and too
  expensive per tap for a long task, and it is the natural low-confidence fallback.
- **On-device small model.** Keeps screen contents off the network, which matters more on a
  phone than in a datacentre; no published head-to-head on this task.
- **Ask the user.** The correct answer for every sensitive screen, and the reason `ask_user` is
  in the option set.

## Sources

- https://github.com/antiyro/jevdroid — accessed 2026-09-19
- https://github.com/droidrun/mobile-jev — accessed 2026-09-19
- https://github.com/AboveColin/HA-Jev — accessed 2026-09-19
- https://github.com/RINNECODER/jev-behavior-study — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
