# Phase 0: Dependency Analysis (Parallel Mode Only)

**Skip this entire phase if `execution_mode == sequential`.**

When `execution_mode == parallel`, analyze all target stories to determine which can safely run concurrently and which must be sequential.

## Step 0.1: Gather Story Scope Information

For each target story, collect scope signals from available sources:

**If story file exists** (`ready-for-dev` or `draft`):
1. Read the full story file
2. Extract from `## Dev Notes`: target files, modules, directories mentioned
3. Extract from `## Tasks / Subtasks`: specific files/components being created or modified
4. Extract from `## Acceptance Criteria`: integration points with other features

**If story is `backlog`** (no file yet):
1. Read the epic description from `{planning_artifacts}/*epic*.md`
2. Extract the story's scope description, dependencies mentioned, and target areas
3. Read `sprint-status.yaml` `sequencing:` field for the story's epic

**For each story, record:**
- `target_packages`: which packages are touched (e.g., `client`, `server`, `shared`)
- `target_modules`: specific directories/files (e.g., `packages/server/src/services/wsl.ts`, `packages/client/src/components/chat/`)
- `target_stores`: Zustand stores referenced or modified (e.g., `usePreviewStore`)
- `target_apis`: REST endpoints or WebSocket events created or consumed
- `target_shared_types`: types in `packages/shared` created or modified
- `explicit_dependencies`: other stories explicitly mentioned as prerequisites
- `epic_number`: which epic the story belongs to

## Step 0.2: Build Conflict Matrix

For every pair of stories (A, B), compute a **conflict score**:

| Signal | Score | Rationale |
|--------|-------|-----------|
| Different packages, no shared types | 0 | Completely isolated — safe |
| Same package but different modules/directories | 1 | Low risk — likely safe |
| Same module or directory | 2 | Moderate risk — may touch same files |
| Both modify `packages/shared` types | 2 | Type changes can cascade |
| Story B consumes an API/store that Story A creates | 3 | Hard dependency — must be sequential |
| Story B explicitly depends on Story A | 3 | Explicit dependency — must be sequential |
| Same epic, sequential numbering (A=X.N, B=X.N+1) with no explicit "parallel OK" | 2 | Intra-epic stories typically build on each other |
| Same epic but `sequencing:` field says "independent" or "can run in parallel" | 0 | Explicit override — trust it |
| Cross-epic stories with `sequencing:` saying "Independent" | 0 | Explicitly independent |

**Conflict decision:**
- Score 0-1 -> **parallel candidates** (safe to run concurrently)
- Score 2 -> **cautious** — classify as sequential unless the orchestrator can verify no actual file overlap (check git history for the target directories: do they share any files?)
- Score 3 -> **hard sequential** — must run in order

## Step 0.3: Build Execution Plan

Using the conflict matrix, group stories into **execution rounds**:

**Algorithm:**
1. Start with all stories in a pool, ordered by sprint priority (epic number, then story number)
2. Take the first story — it starts Round 1
3. For each remaining story in order: if it has conflict score 0-1 with ALL stories already in the current round AND the round has fewer than `{max_parallel}` stories -> add to current round
4. If a story can't join the current round -> start a new round with it
5. Repeat until all stories are assigned

**Dependencies create ordering constraints:**
- If Story B depends on Story A (score 3), B must be in a later round than A
- If Stories A and B are both score 2 with Story C, but score 0 with each other, A and B can be in the same round, and C goes in a later round

**Example output:**
```
## Execution Plan (Parallel Mode)

Round 1 (parallel — 3 stories):
  [7-6] agent-working-state-feedback     — client/components (UX)
  [8-1] wsl-detection-path-translation   — server/lib (WSL)
  [9-1] cors-cross-origin-request-fix    — server/middleware (CORS)
  Merge order: 9-1 -> 8-1 -> 7-6 (smallest scope first)
  Rationale: All touch different packages/modules. No shared types.

Round 2 (sequential — 1 story):
  [8-2] wsl-preview-server-compatibility — server (depends on 8-1 WSL detection)
  Rationale: Consumes WSL detection service created in 8-1.
```

## Step 0.4: Determine Merge Order Within Rounds

For each parallel round with 2+ stories, determine the merge order. Stories are merged **one at a time** into the batch branch after all stories in the round complete development.

**Merge order heuristic** (merge these first):
1. Stories with the smallest diff (fewer files changed) — smaller diffs are less likely to conflict with subsequent merges
2. Server-only stories before client-only stories (server changes are typically more foundational)
3. Bug fixes before features
4. Lower story number first (tiebreaker)

The merge order is a **plan** — if a conflict occurs during merge, the orchestrator may need to reorder.

## Step 0.5: Present Plan for User Approval

Display the full execution plan and **wait for user confirmation** before proceeding:

```
## Execution Plan

Mode: parallel
Total stories: {N}
Rounds: {round_count}
Estimated speedup: {N} sequential -> {round_count} rounds

{execution_plan_table}

Conflict matrix:
| Story | 7-6 | 8-1 | 9-1 | 8-2 | ... |
|-------|-----|-----|-----|-----|-----|
| 7-6   |  -  |  0  |  0  |  1  | ... |
| 8-1   |  0  |  -  |  0  |  3  | ... |
| 9-1   |  0  |  0  |  -  |  0  | ... |
| 8-2   |  1  |  3  |  0  |  -  | ... |

Proceed with this plan? (y/n/edit)
- y: Execute the plan as shown
- n: Abort
- edit: Modify groupings (e.g., "move 8-4 to round 2", "make all sequential")
```

If the user says `edit`, apply their modifications and re-display the plan for confirmation.

**Store the approved plan as `{execution_plan}` — a list of rounds, each containing an ordered list of stories and a merge order.**

---

# Parallel Execution Loop

**This section replaces the Sequential Execution Loop when `execution_mode == parallel`.**

For each round in `{execution_plan}`:

## Announce Round

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Round {round_num}/{total_rounds}
Stories: {story_list}
Mode: {parallel if len > 1, else sequential}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Phase A: Story Creation (Sequential Within Round)

**Story creation runs SEQUENTIALLY even in parallel mode.** Reasons:
- Creation reads sprint-status.yaml and existing stories for cross-references
- Creating stories in parallel risks duplicate context or missing references
- Creation is fast (minutes) — parallelizing it saves little time

For each story in the round, in order:
1. Run Step 1 (Create), Step 2 (Review), Step 3 (Validate) — same as sequential mode
2. Gate check each step before proceeding

After all stories in the round are created and validated (`ready-for-dev`), proceed to Phase B.

## Phase B: Story Development (Parallel Within Round)

**Development runs IN PARALLEL for all stories in the round.** Each story gets its own worktree branched from the current batch branch HEAD.

### Single-Repo Worktree Setup

1. **Create all worktrees** from the batch branch (orchestrator does this directly):
   ```bash
   cd {project_root}
   git fetch origin {batch_branch}
   # For each story in the round:
   git worktree add {worktree_path_N} -b {worktree_branch_N} origin/{batch_branch}
   ```

### Meta-Repo Worktree Setup

1. **Create meta-repo worktrees** (one per story — for artifact access and skill invocation):
   ```bash
   cd {project_root}
   git fetch origin {batch_branch}
   # For each story in the round:
   git worktree add ../{project_name}-story-{story_slug} -b {worktree_branch} origin/{batch_branch}
   ```

2. **Create subrepo worktrees** (one per affected subrepo per story):
   ```bash
   # For each story in the round, for each affected subrepo:
   cd {project_root}/{subrepo}
   git fetch origin {batch_branch}
   git worktree add ../../{project_name}-{subrepo}-story-{story_slug} -b {worktree_branch} origin/{batch_branch}
   ```

**CRITICAL — Subagent working directory for meta-repos**: The subagent's primary working directory MUST be the **meta-repo worktree** (`../{project_name}-story-{story_slug}`), NOT a child subrepo worktree. This is because:
- BMAD skills/commands (`Skill("bmad-bmm-dev-story")` etc.) reference `_bmad/` which only exists in the meta-repo
- The story file is at `{meta_worktree}/_bmad-output/implementation-artifacts/{story_file_name}`
- The subagent navigates to child subrepo worktrees only for code changes (e.g., `cd ../../{project_name}-{subrepo}-story-{story_slug}`)

### Launch Parallel Tasks

2. **Launch parallel Task calls** — one per story in the round. Each Task runs Steps 4 through 6 (implement -> code-review -> fix) in its own worktree. **All Task calls are launched simultaneously in the SAME message** to enable true parallel execution.

   Each Task prompt is identical to the sequential Steps 4-6 (see `references/story-development-steps.md`), with these additions:
   - The worktree path is unique per story: `../{project_name}-story-{story_slug}`
   - The worktree branch is unique: `worktree-story-{story_slug}-{story_name}`
   - Include: "You are running in PARALLEL with other story implementations. Do NOT modify any files outside your worktree. Do NOT interact with the batch branch directly."
   - **Meta-repo addition**: "Your primary working directory is the meta-repo worktree at `{meta_worktree_path}`. Child subrepo worktrees are at `{subrepo_worktree_paths}`. Invoke all BMAD skills from the meta-repo worktree. Navigate to child worktrees only for code changes."

3. **Wait for ALL parallel Tasks to complete.** Collect results from each.

4. **Gate check each story independently.** A failure in one story does not block others in the round — apply `on_failure` policy per-story.

## Phase C: Sequential Merge (After Parallel Development)

After all parallel stories in a round complete Phase B, merge them **one at a time** in the planned merge order.

For each story in merge order:

### Step 7: Finalize Story Artifacts (Orchestrator Direct)

Same as sequential mode Step 7 — read and verify/fix the worktree story file, update sprint status, commit artifact changes.

### Merge with Conflict Detection

See `references/merge-and-conflict.md` for the full merge and conflict resolution protocol.

## Move to Next Round

After all stories in the current round are merged (or skipped/failed):

**Single-repo:**
1. Update local state: `git fetch origin {batch_branch} && git branch -f {batch_branch} origin/{batch_branch}`

**Meta-repo:**
1. Update meta-repo: `cd {project_root} && git fetch origin {batch_branch} && git branch -f {batch_branch} origin/{batch_branch}`
2. Update each subrepo: `for subrepo in {all_affected_subrepos}; do cd {project_root}/$subrepo && git fetch origin {batch_branch} && git branch -f {batch_branch} origin/{batch_branch}; done`

Then:
3. Announce round completion with results
4. Proceed to the next round

The next round's worktrees will be created from the updated batch branch, which now includes all merged stories from previous rounds.
