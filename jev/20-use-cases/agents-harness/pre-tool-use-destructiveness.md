---
id: uc-agents-harness-pre-tool-use-destructiveness
title: Add a confirmation prompt when a shell command looks destructive, inside the deterministic controls
verdict: conditional
verdict_as_asked: no
domain: agents-harness
decision_shapes: [scoring, detection, routing]
primitives: [score, noul]
evidence_level: inferred
sources:
  - https://docs.typesafe.ai/cookbooks/llm_guardrails.md  (hazard Nouls + one severity Score in one call; HAZARD_ACTION, PRECEDENCE, per-policy thresholds)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 6: state is data, not treated as hostile by default)
  - https://docs.typesafe.ai/concepts/use-case-map.md  (Harness Engineering; LLM guardrails)
  - https://docs.typesafe.ai/models.md  (70-500 ms; $0.042 per million input tokens)
related: [au-shell-command-safety-hook-gate, uc-agents-harness-tool-call-trace-verification, uc-agents-harness-prompt-injection-semantic-flag, uc-verification-llm-output-policy-check, au-sole-security-gate]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev in a pre-tool-use hook to decide whether a shell command is
safe?" Also: "can jev catch `rm -rf` variants our regex misses?", "should the agent ask before
running this?", "how do we stop approving every command by hand without opening the door?"

**This entry is `inferred`.** No cookbook covers shell-command risk scoring. The shape is the
guardrails cookbook's hazard battery pointed at a command string; the numbers below are the
mechanism's economics, not a measured result.

## Verdict

Asked literally — "can jev decide whether a shell command is safe to run?" — the answer is
**no**, and it has its own entry: `au-shell-command-safety-hook-gate`. The allowlist, the
denylist, the sandbox boundary and the credential scope *are* the safety decision and they
stay authoritative in code — "State is data, and `jev-1.13` does not treat it as hostile by
default", and a command string is text an attacker or a confused agent can write. As the
gate, this is also `au-sole-security-gate`.

**This entry describes a different proposal, and its verdict is conditional:** inside those
deterministic controls, a hazard battery is a good way to turn "prompt the human on
everything" into "prompt the human on the commands that warrant it". Jev scores how
destructive the command looks and the score may only ever *add* a confirmation, never remove
one; the latency (about 100 ms) fits in a hook. The share of prompts you remove is something
to measure on your own command log, not a figure this entry supplies.

## What jev decides

State is the command and the context needed to judge it — nothing more:

```json
{"command": "find . -name '*.log' -mtime +7 -delete",
 "cwd": "/repo/services/api", "repo_is_dirty": true,
 "stated_intent": "clean up old log files"}
```

Four Nouls plus one Score, all in one call, framed so `true` is the hazard:

```python
"destroys_data":  Noul("Does this command delete, overwrite, or truncate files, tables, or branches?",
   true="Data that existed before the command would no longer exist after it.",
   false="The command only reads, lists, or creates.")
"affects_outside_workspace": Noul("Does this command act on paths, hosts, or accounts outside the stated working directory?")
"not_reversible": Noul("Would undoing this command's effect require a backup or a remote copy?")
"exceeds_stated_intent": Noul("Does the command do something the stated intent does not call for?")
"blast_radius": Score("How much would be affected if this command did the worst thing it plausibly could?",
   criteria=["A single file or a scratch directory",
             "One project or one local database",
             "A shared environment or a remote branch others use",
             "Production data, credentials, or a published artifact"])
```

Routing follows the guardrails cookbook literally: a `HAZARD_ACTION` map, two thresholds per
policy (`review_threshold` and `action_threshold`), a severity override that promotes a review
to a block, and a `PRECEDENCE` list so the most protective action wins.

## What stays in code

The denylist (`rm -rf /`, `:(){ :|:& };:`, force-push to a protected branch), the allowlist of
commands that never prompt, the sandbox or container boundary, credential scoping, the dry-run
flag, the approval UI, and the thresholds. Also the deterministic facts the question should not
re-derive: whether the path is inside the workspace, whether the branch is protected, whether
the target host is in the allowlist. Compute those; put the booleans in state.

## Numbers

Per-call cost: a command plus context plus five questions is roughly 400-700 input tokens,
about $0.00002-$0.00003 at $0.042 per million input tokens with free output. Latency 70-500 ms,
"most queries about 100 ms" — acceptable in a pre-tool hook, though it is added to every
command, so cache or skip for allowlisted commands.

The closest measured analogue is the guardrails cookbook's input battery, `jev-1.12` on
2026-08-15, 15 routed messages: `lockpick_burglary` harmful_request 0.95 / severity 2.4 ->
BLOCK; `dan` jailbreak 0.98 -> BLOCK; `melatonin_dose` medical_advice 0.55 / severity 0.3 ->
review; ordinary messages 0.02-0.04 -> pass. No precision or recall is reported there either —
"the cookbook shows 15 individual routing decisions, not an aggregate metric" — and none exists
for shell commands. Collect your own labelled command log before trusting a threshold.

Closest jaggedness modes: **2, math and numbers** (never ask "does this delete more than 100
files" — count in code) and **6, adversarial content**, which is the whole reason for the
"conditional".

- Field evidence (community-report): jev-axi scored 44/44 on a labelled set of 24 block and 20 allow tool calls at 375-402 ms and $0.00001-$0.00004 per call; the same project's file-ranking skill "showed inconsistent results across sessions (appearing as either 25% savings or 29% penalty)" on a 390k-line repo and agents rarely invoked it unprompted, 2026-09. Source: https://github.com/shiftynick/jev-axi
- Field evidence (community-report): a destructive-action approval guard shipped in the Empryo UI agent with an 800 ms timeout and a fallback path when jev does not answer in time, one of five accepted jobs out of eight tested, 2026-09-16. Source: https://empryo.com/blog/jev-and-the-harness

## When the verdict flips

- **The command set is enumerable.** A CI runner that only ever runs six commands needs an
  allowlist, not a model. **Weak**.
- **You remove the deterministic gate, or the score is allowed to skip a confirmation.** Then
  it is **no** — `au-shell-command-safety-hook-gate`. An agent whose prompt was poisoned can
  also write a command whose framing argues for its own safety.
- **Risk is decidable from the path or the flag** — `--force`, a production hostname, a path
  outside the workspace. Assert those; they are exact and jev may read them literally (mode 1).
- **Per-command latency matters** (tight inner loops, hundreds of commands per task). Skip the
  hook for allowlisted reads.
- **The agent is already fully sandboxed and disposable.** Nothing it can do is destructive;
  the check buys nothing.

## Alternatives considered

- **Regex / denylist on command strings** — the incumbent, exact and free, and it must stay. It
  is brittle across quoting, aliases, `xargs`, and equivalent commands it has never seen, which
  is the gap jev fills.
- **Sandbox, container, read-only mount, least-privilege credentials** — strictly better where
  available, because they make the question moot. Prefer these; use jev where the agent
  legitimately needs write access.
- **Ask the human every time** — safe and the reason people turn agents off; the point of this
  entry is to make the prompt rare enough to stay meaningful.
- **A frontier LLM as the reviewer** — more nuanced and adds a full call of latency to every
  command, and it can be talked past the same way.
- **Static shell parser (shellcheck-style AST rules)** — genuinely good and underused: an AST
  can prove what a command touches. Combine — parser for facts, jev for intent mismatch.

## Sources

- https://docs.typesafe.ai/cookbooks/llm_guardrails.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/concepts/use-case-map.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
