---
id: uc-browser-automation-action-selection-from-accessibility-tree
title: Pick the next browser action from a code-serialised accessibility tree
verdict: good
domain: browser-automation
decision_shapes: [classification, routing, ranking]
primitives: [choice, noul]
evidence_level: community-report
sources:
  - https://github.com/browser-use/jev-ultrafast  (jev as the action selector in a browser agent: median 9.450 s -> 7.092 s, protocol calls 1,092 -> 101, 3/3 passes; small LLM writes text only for TYPE_TEXT)
  - https://github.com/nekuda-ai/WindTunnel  (49 tasks, 3,087 attempts, 21 configurations; "WebMCP configs beat all screen-driving approaches")
  - https://github.com/RINNECODER/jev-behavior-study  (option position: correct option first 95/108 vs fourth 62/108)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 5 large state full of irrelevant detail; mode 6 adversarial content)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free; text-only input; 70-500 ms)
related: [uc-devices-control-mobile-action-selection-accessibility-tree, uc-browser-automation-page-clutter-element-removal, uc-realtime-ui-component-selection, uc-agents-harness-function-call-argument-filling, au-real-time-from-raw-pixels, au-open-ended-agent-loop]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to drive a browser agent?" Also: "can jev replace the vision
model that decides what to click?", "our agent takes 30 seconds a step — can a System One
model pick the element?", "can jev do computer use?".

## Verdict

**Good** — for the *selection* step only, and only when code has already turned the page into a
numbered list of interactable elements. Jev cannot see a screenshot (text input only), cannot
write the text it types, and cannot plan a multi-step task. What it can do is answer "which of
these 40 enumerated elements, and which of these 5 action verbs" in about 100 ms, which is the
step a frontier model was being paid seconds to do. A public browser-agent fork reports median
task time falling "9.450 s -> 7.092 s" (25%) with "3/3 passes" on its suite. It is `good` and
not `strong` because that is 3 tasks with no accuracy measurement, not a benchmark.

## What jev decides

Code walks the accessibility tree, drops anything invisible, disabled or off-screen, and emits a
stable, deterministically ordered list: `[0] button "Add to cart"`, `[1] input "Search"`, and so
on, with role, accessible name and a short text excerpt. That list plus the task goal and the
last action's outcome is the whole state. Filtering is not an optimisation here, it is the
design: a raw DOM is failure mode 5 (large state full of irrelevant detail) in its purest form.

```
action_verb: Choice
  instructions: {question: "What should the agent do next to make progress on `goal`?"}
  criteria:
    click:      {what: "A single element must be activated to advance"}
    type_text:  {what: "A field must receive text before anything else can happen"}
    scroll:     {what: "The element that would advance the goal is not in `elements` yet"}
    go_back:    {what: "This page cannot advance the goal and the previous one could"}
    done:       {what: "`goal` is already satisfied by what `page_summary` shows"}

target_element: Choice over the enumerated element ids (only when action_verb != scroll/done)
  instructions: {focus: "Choose by what the element does, not by where it sits on the page."}

page_is_blocked: Noul
  instructions: "Does `page_summary` show a login wall, captcha, cookie gate or error?"
```

A small generative model writes the string for `TYPE_TEXT`. That split — jev chooses, a
generative model writes — is the whole architecture, and it is why the protocol call count in
the public fork fell "1,092 -> 101".

Bands: below your fitted floor, hand the step to the frontier model you were using anyway. That
fallback is what makes the speed-up safe to take.

## What stays in code

Tree extraction, visibility and enabled checks, the element numbering and its *stable ordering*,
scroll position, navigation, retries, the loop itself and its step budget, and every
verification that an action had the effect it claimed. Never ask jev for a coordinate, a count
of results, or a price comparison. `done` is a proposal; code confirms it against a URL, a
selector or an order id.

## Numbers

From https://github.com/browser-use/jev-ultrafast: median task time "9.450 s -> 7.092 s", a 25%
reduction; "protocol calls 1,092 -> 101"; "3/3 passes". No accuracy figure, no task list length,
no per-step latency published. Cost method: `input_tokens ~= chars/4`,
`cost = tokens x $0.042 / 1e6`, output free. A 40-element list serialised at ~70 characters each
(2,800) plus goal and criteria (~1,500) is about 1,075 tokens, **~$0.000045 per step**; a
30-step task is therefore about a tenth of a cent in selection.

Position sensitivity is the measured risk that bites hardest here: a synthetic probe over 11,621
requests found the correct option chosen "95/108" when it was listed first against "62/108" when
listed fourth (https://github.com/RINNECODER/jev-behavior-study). Order your element list by DOM
order every time so the bias is at least constant, and never re-sort by a heuristic between
steps.

Closest failure mode: **5, large state full of irrelevant detail** — avoided by sending a
filtered, numbered element list rather than HTML. Runner-up is **6, adversarial content**: page
text is attacker-controlled, so pair this with a prompt-injection flag.

## When the verdict flips

- **The site exposes a machine interface.** WindTunnel ran 21 configurations over 49 tasks and
  3,087 attempts and found "WebMCP configs beat all screen-driving approaches"; jev + Mercury 2.5
  was one config among them. If there is an API, an MCP server or a feed, use it — this entry
  becomes irrelevant, not merely weak.
- **The decision needs pixels.** Canvas apps, maps, image pickers, drag targets. Jev takes text
  only; see the raw-pixels anti-use-case.
- **The step is a plan, not a pick.** "Book the cheapest flight under 6 hours" is multi-hop with
  arithmetic. Decompose in code or keep the frontier model.
- **The action is irreversible.** Purchases, sends, deletes. Gate those on a confirmation, not
  on a probability.

## Alternatives considered

- **Deterministic selectors / recorded scripts.** Free, exact, fastest. They are right whenever
  the page is yours or stable. Jev is for the long tail that breaks weekly.
- **Vision-language computer-use models.** Handle canvas and unlabelled UI; seconds per step and
  cents per step. The measured gain above is precisely against this baseline.
- **Frontier LLM over the same text tree.** The direct competitor and better at planning; the
  fork kept one in the loop for text generation and the low-confidence path.
- **Embeddings over element names.** Cheap and reasonable for "which element is the search box";
  no way to express "which action advances *this* goal".
- **WebMCP / site APIs.** Measured better than all screen driving. Prefer it.

## Sources

- https://github.com/browser-use/jev-ultrafast — accessed 2026-09-19
- https://github.com/nekuda-ai/WindTunnel — accessed 2026-09-19
- https://github.com/RINNECODER/jev-behavior-study — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
