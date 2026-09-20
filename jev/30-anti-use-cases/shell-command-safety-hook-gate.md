---
id: au-shell-command-safety-hook-gate
title: Do not let a jev hook decide whether a shell command is safe to run
verdict: no
domain: agents-harness
decision_shapes: [detection, routing, scoring]
primitives: [noul, score]
evidence_level: inferred
sources:
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 6: "State is data, and `jev-1.13` does not treat it as hostile by default"; mode 2, math and numbers)
  - https://docs.typesafe.ai/cookbooks/llm_guardrails.md  (hazard Nouls plus one severity Score in one call; 15 routed messages, no aggregate metric)
  - https://docs.typesafe.ai/concepts/use-case-map.md  (Harness Engineering; LLM guardrails)
  - https://docs.typesafe.ai/models.md  (70-500 ms; $0.042 per million input tokens)
  - https://github.com/shiftynick/jev-axi  (44/44 on a labelled set of 24 block and 20 allow tool calls, 375-402 ms, $0.00001-$0.00004 per call, 2026-09)
related: [uc-agents-harness-pre-tool-use-destructiveness, au-sole-security-gate, au-numeric-thresholds-and-arithmetic, uc-agents-harness-prompt-injection-semantic-flag]
last_verified: 2026-09-20
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev in a pre-tool-use hook to decide whether a shell command is
safe?" Also: "can jev be the thing that approves commands so we can stop clicking yes?",
"can it replace our denylist?", "can the agent self-approve when jev says the command is
harmless?"

**This entry is `inferred`.** No cookbook covers shell-command risk scoring; the objection is
the security model, not a measured failure.

## Verdict

**No**, where the hook's answer is what permits the command. The allowlist, the denylist, the
sandbox boundary and the credential scope *are* the safety decision, and a command string is
text that an attacker or a confused agent writes. The jaggedness page is explicit: "State is
data, and `jev-1.13` does not treat it as hostile by default." Making the model the gate is
the general anti-pattern in `au-sole-security-gate`, applied to the most destructive surface
an agent has. The design that does fit — jev *adding* a confirmation prompt inside those
deterministic controls, never removing one — is `uc-agents-harness-pre-tool-use-destructiveness`
(`conditional`).

## What jev would get wrong

A command that argues for its own safety. The `stated_intent` field, the comment in the
script, and the command's own naming are all inputs the caller controls, and failure mode 6
covers exactly "text that argues for its own classification". An agent whose context has been
poisoned will write both the command and the justification.

It would also get the quantities wrong. "Does this delete more than 100 files?", "is this
path inside the workspace?", "is this host on the allowlist?" are counting, path arithmetic
and set membership — failure mode 2 and plain lookups. Compute them in code and put the
booleans in state. And the hook has to resolve a 429, a timeout or a network blip to
something: if that resolution is "block" it is a denylist with extra latency, and if it is
"allow" the gate was never a gate.

## What stays in code

The denylist (`rm -rf /`, fork bombs, force-push to a protected branch), the allowlist of
commands that never prompt, the sandbox or container boundary, credential scoping, the
dry-run flag, the approval UI, the thresholds, and the timeout policy. Also the deterministic
facts: whether the path is inside the workspace, whether the branch is protected, whether the
target host is allowlisted.

## Numbers

A command plus context plus five questions is roughly 400-700 input tokens, about
**$0.00002-$0.00003** per call at $0.042 per million input tokens with free output; latency
70-500 ms, added to every command. The closest measured analogue is the guardrails cookbook's
input battery, `jev-1.12`, 2026-08-15, **15 routed messages** with no precision or recall
reported — "the cookbook shows 15 individual routing decisions, not an aggregate metric".
Field evidence (community-report): jev-axi scored **44/44 on a labelled set of 24 block and
20 allow tool calls** at 375-402 ms (github.com/shiftynick/jev-axi, 2026-09) — encouraging
for an advisory layer, far too small a set to license unattended authority, and measured on
non-adversarial commands. **No published benchmark measures jev under adaptive attack.**

## When the verdict flips

- To **conditional** when the deterministic controls stay authoritative and jev may only ever
  *add* a confirmation: `uc-agents-harness-pre-tool-use-destructiveness`.
- To **weak** when the command set is enumerable — a CI runner with six commands needs an
  allowlist, not a model.
- It never flips to jev approving commands unsupervised; a sandboxed, disposable agent makes
  the question moot instead, which is the better fix where it is available.

## Alternatives considered

- **Denylist / allowlist on command strings.** The incumbent, exact and free; brittle across
  quoting and aliases, which is the gap an advisory layer fills.
- **Sandbox, container, read-only mount, least privilege.** Strictly better: they make the
  question unnecessary. Prefer these.
- **Static shell parser (shellcheck-style AST rules).** Can prove what a command touches.
- **Ask the human every time.** Safe, and the reason people disable agents.
- **Frontier LLM reviewer.** More nuanced, a full call of latency, talked past the same way.

## Sources

- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-20
- https://docs.typesafe.ai/cookbooks/llm_guardrails.md — accessed 2026-09-20
- https://docs.typesafe.ai/concepts/use-case-map.md — accessed 2026-09-20
- https://docs.typesafe.ai/models.md — accessed 2026-09-20
- https://github.com/shiftynick/jev-axi — accessed 2026-09-20
