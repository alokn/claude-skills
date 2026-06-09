<!--
  Developer documentation — NOT read by the agent.

  Claude only loads SKILL.md (its frontmatter `description` is always in context;
  the body loads when the skill is invoked) and the references/*.md files that
  SKILL.md explicitly names. This README is never referenced by SKILL.md, so it
  has zero impact on the agent's context or behavior. Keep usage/maintenance
  notes here; keep runtime instructions in SKILL.md and references/.
-->

# orchestrate-full-batch

A BMAD batch orchestrator skill for Claude Code. It takes the next *N* backlog
stories and runs each one through the **full create-then-develop pipeline** —
create, review, validate, implement, QA, code-review, fix, finalize — then
opens/merges PRs. It supports sequential and parallel execution, single-repo and
meta-repo layouts.

This is a coordinator skill: it never writes story files or source code itself.
It launches subagents (via the `Task` tool) that invoke the underlying BMAD
workflow skills, and gates between each step by reading the artifacts on disk.

---

## Prerequisites

This skill drives the **BMAD method**, so a BMAD-initialized project is required:

- **BMAD installed in the repo** — the `_bmad/` directory plus the BMAD command
  skills this orchestrator delegates to:
  - `bmad-bmm-create-story` (Step 1)
  - `bmad-agent-bmm-sm` (Step 3, Scrum Master validation)
  - `bmad-bmm-dev-story` (Steps 4 & 6)
  - `bmad-bmm-code-review` (Step 5)
  - `bmad-bmm-qa-automate` (Step 4.6, conditional)
- **Sprint status file** at `_bmad-output/implementation-artifacts/sprint-status.yaml`
  with stories in `backlog` status.
- **Planning artifacts** under `_bmad-output/planning-artifacts/` (epics, PRD,
  architecture) — used as story-creation context.
- **Git** repo with a clean working tree and a base branch (default `main`).
- **GitHub CLI** (`gh`) authenticated — the pipeline opens and merges PRs.
- A **toolchain** the skill can auto-detect (Node/pnpm-yarn-npm-bun, Rust, Go,
  Python, or Makefile). Playwright is auto-detected for E2E.

If your project isn't a BMAD project, this skill won't do anything useful — it
expects the BMAD artifacts and workflows above.

---

## Invoking it

It's a Claude Code skill, so trigger it in natural language, e.g.:

- "Batch-process the next 3 BMAD stories end-to-end."
- "Run the full batch pipeline on 5 stories in parallel mode."
- "Orchestrate the next 4 backlog stories, skip on failure."

Claude will load the skill and ask (via `AskUserQuestion`) for any parameters you
didn't specify. There's also a command-style equivalent in this repo at
`.claude/commands/orchestrate-full-batch.md` if you prefer a slash entry point.

---

## Input parameters

| Parameter | Required | Default | Notes |
|---|---|---|---|
| **Number of stories** | ✅ | — | How many `backlog` stories to process, in sprint order. |
| **Execution mode** | — | `sequential` | `sequential` or `parallel`. |
| **Base branch** | — | `main` | Branch the batch branch merges back into. |
| **Batch branch name** | — | auto | Shared branch all story PRs target. Auto-derived as `batch-stories-{N}-from-{first_story_slug}`. |
| **On failure** | — | `stop` | `stop` (abort, report progress) or `skip` (skip failed story, continue). |
| **Max parallel** | — | `3` | Max concurrent stories per round (capped at 4). Parallel mode only. |
| **Auto-merge** | — | `off` | `off`: leave the final batch→base PR open for human review. `on`: auto-merge it. Story→batch merges always happen automatically regardless. |

---

## The pipeline (per story)

Each story runs through **7 steps** (6 subagent `Task` calls + 1 direct
finalization), with an orchestrator-verified gate between each. The orchestrator
re-reads the artifacts on disk after every step rather than trusting subagent
self-reports.

| Step | Phase | Who | Model | What |
|---|---|---|---|---|
| 1. Create | Creation | subagent | Opus | `bmad-bmm-create-story` generates the story file. |
| 2. Review | Creation | subagent | Sonnet | Multi-perspective review (Developer / QA / Architect personas) edits the story in place, tagging changes `[Party-Review]`. |
| 3. Validate | Creation | subagent | Sonnet | Scrum Master (`bmad-agent-bmm-sm` CS) runs the validation checklist; marks story `ready-for-dev`. |
| 4. Implement | Development | subagent | Opus | `bmad-bmm-dev-story` implements tasks in an isolated worktree; runs tests/lint/typecheck. |
| 4.5. QA assessment | Development | orchestrator | — | Scores whether QA automation adds value (feature vs. fix/refactor heuristic). |
| 4.6. QA automation | Development | subagent | Sonnet | *Conditional* — `bmad-bmm-qa-automate` generates tests. Skipped if 4.5 says no. Non-blocking. |
| 5. Code review | Development | subagent | Sonnet | Adversarial `bmad-bmm-code-review` finds 3–10 issues, written to the story as `[AI-Review]` follow-ups. |
| 6. Fix | Development | subagent | Sonnet | `bmad-bmm-dev-story` (review continuation) addresses findings; E2E is blocking here. |
| 7. Finalize | Development | orchestrator | — | Verifies/fixes story artifacts, sets status `done`, updates sprint status, pushes once, opens the PR. |

After Step 7 the story PR is merged into the **batch branch** (always automatic),
the local batch branch is updated, and the worktree is cleaned up. The next story
branches from the updated batch branch, so each builds on the last.

**Model usage note:** steps reference the generic tier aliases `opus` and
`sonnet` (not pinned model IDs), so they always resolve to the current
generation. Opus for generative/implementation work, Sonnet for
review/validation/QA/fix.

---

## Execution modes

### Sequential (default)

Each story is fully created → developed → merged before the next begins. Safe and
predictable. This is the right default unless you've confirmed your stories are
independent.

### Parallel

Adds a **Phase 0 dependency analysis**: every pair of target stories gets a
conflict score (0 = isolated, 3 = hard dependency) based on which packages,
modules, shared types, and APIs they touch. Stories are grouped into **execution
rounds** (up to `max_parallel` each), and the plan is shown for your approval
before anything runs.

Within a round:
- **Creation (Steps 1–3) runs sequentially** — it reads shared sprint state.
- **Development (Steps 4–6) runs in parallel**, each story in its own worktree.
- **Merge (Phase C) runs sequentially**, one story at a time in a planned merge
  order, with an automatic conflict-resolution protocol (auto-resolves trivial
  conflicts like import ordering and `sprint-status.yaml`; halts for human help on
  overlapping logic).

---

## Meta-repo support

The skill auto-detects a **meta-repo** — a parent git repo with independent child
git repos as gitignored subdirectories. When detected:

- The batch branch is created in the meta-repo **and** every subrepo.
- Toolchain detection runs **per-subrepo** (each can have a different stack).
- **Planning artifacts** (`_bmad-output/`) commit to the meta-repo; **code**
  commits to the relevant subrepo.
- BMAD skills always run from the meta-repo (where `_bmad/` lives); subagents
  navigate into subrepo worktrees only for code changes.
- PRs are created **per repo** and merged independently — libraries before
  consumers, meta-repo artifacts last.

If no subrepos are found, it falls back to standard single-repo behavior.

---

## What it produces

- A **batch branch** (`batch-stories-{N}-from-{slug}`) containing every merged
  story.
- One **PR per story** targeting the batch branch (squash-merged).
- A final **batch→base PR** — left open for review (`auto-merge: off`) or
  auto-merged (`auto-merge: on`).
- Updated **story files** and **`sprint-status.yaml`** (`done` for completed
  stories; epic marked `done` when all its stories are).
- A **batch completion report** summarizing per-story results, findings counts,
  test/lint/E2E status, merge status, and any conflicts or skipped stories.

---

## Failure handling

Every step has a gate; failures route through the `on_failure` policy:

- **`stop`** — halt the batch and report progress so far.
- **`skip`** — mark the story `FAILED`, continue from the last merged state.

Some failures are **non-blocking** by design: E2E failures in Step 4 (re-checked
in Step 6, where they *are* blocking), and QA automation failures in Step 4.6.
See `references/error-handling.md` for the full failure table.

---

## File structure & how the agent loads it

```
orchestrate-full-batch/
├── SKILL.md                  # Entry point. Frontmatter description is always
│                             # in context; body loads on invocation.
├── README.md                 # ← this file. Never loaded by the agent.
└── references/
    ├── project-detection.md      # Meta-repo + toolchain + Playwright detection
    ├── parallel-mode.md          # Phase 0 dependency analysis + parallel loop
    ├── story-creation-steps.md   # Steps 1–3 (subagent prompts + gates)
    ├── story-development-steps.md # Steps 4–7 (subagent prompts + gates)
    ├── merge-and-conflict.md      # Merge protocol + conflict resolution
    └── error-handling.md          # Error table + completion report template
```

`SKILL.md` is intentionally thin — it routes to the `references/*.md` files by
**exact name** (no globs) and the agent reads a reference only when SKILL.md tells
it to. This keeps the per-session context small. When editing:

- Put **agent runtime instructions** in `SKILL.md` or a `references/*.md` file
  (and add an explicit `Read references/<file>.md` line in SKILL.md so it loads).
- Put **developer/maintenance docs** here in `README.md` (or a `docs/` folder) —
  do **not** reference them from `SKILL.md`, or they'll be pulled into context.
- Keep the SKILL.md frontmatter `description` lean — it's loaded into *every*
  session for skill discovery.

---

## Design notes

**Why 6 direct `Task` calls instead of a single sub-orchestrator?** An earlier
design delegated through a middle "single-story orchestrator" layer (batch →
orchestrator → step). That 3-level chain reliably failed: the middle layer ran out
of context/turns after Step 1 and silently skipped the rest, fabricating results.
Launching all 6 steps directly keeps delegation at 2 levels (batch → step
subagent), which is reliable.

**Why orchestrator-side verification after every step?** Subagents sometimes claim
success without writing the expected artifacts. The orchestrator re-reads the
story file and sprint status from disk after each step and fixes/commits directly
when something is missing, rather than trusting the subagent's JSON report.
