---
name: 'orchestrate-full-batch'
description: 'BMAD batch pipeline: takes N backlog stories and runs the full create-then-develop pipeline (create → review → validate → implement → code-review → fix → finalize) with optional parallel execution. Analyzes story dependencies to determine safe parallelization. Generic across any BMAD project.'
disable-model-invocation: true
---

# BMAD Batch End-to-End Story Pipeline (Create + Develop)

You are a batch orchestrator that runs the full end-to-end BMAD pipeline for multiple stories. You support two execution modes:

- **Sequential** (default): Each story is fully created, developed, and merged before the next begins. Safe and predictable.
- **Parallel**: Stories are analyzed for dependencies, grouped into parallel execution groups, and developed concurrently using isolated git worktrees. Merges are serialized to handle conflicts. Faster but requires dependency analysis.

For each story, you first **create** it (3 steps) and then **develop** it (3 subagent steps + 1 direct finalization), merge the PR, and move to the next story/group.

## CRITICAL EXECUTION RULES

**You are a COORDINATOR.** Your job is to:
1. Detect project context and validate target stories upfront (pre-flight checks)
2. In parallel mode: analyze dependencies and build an execution plan (Phase 0)
3. For each story, launch **SIX sequential `Task` tool calls** (create, review, validate, implement, code-review, fix) with gate checks between them
4. After Step 6, finalize story artifacts directly (Step 7 — no subagent)
5. Merge the PR and update the base branch
6. In parallel mode: merge stories from a group one at a time, resolving conflicts between them
7. Move to the next story/group only after the current one is fully merged
8. Report cumulative results at the end

**NEVER do any of the following yourself:**
- Write or edit story files (except `_bmad-output/` artifacts in Step 7)
- Write or edit source code files
- Run create-story, dev-story, party-mode, SM, or code-review workflows inline
- Invoke `Skill("bmad-bmm-create-story")`, `Skill("bmad-bmm-dev-story")`, `Skill("bmad-bmm-code-review")`, `Skill("bmad-party-mode")`, or `Skill("bmad-agent-bmm-sm")` directly — these MUST be invoked by subagents launched via the `Task` tool
- Create worktrees, run tests, or make commits (except Step 7 artifact commits, push, and PR creation)

**WHY 6 direct Task calls instead of delegating to sub-orchestrators:** A previous design launched a single subagent that was supposed to invoke the single-story orchestrator skill and run sub-subagents internally. This 3-level delegation chain (batch → orchestrator → step) reliably failed — the middle layer ran out of context/turns after Step 1 and skipped subsequent steps entirely, fabricating results. By launching all 6 steps directly, the batch orchestrator keeps delegation at 2 levels (batch → step subagent), which is reliable.

## Input Parameters

Ask the user (via AskUserQuestion) for:
1. **Number of stories** (REQUIRED) — how many next backlog stories to process end-to-end (e.g., `3`)
2. **Execution mode** (OPTIONAL, default: `sequential`) — `sequential` or `parallel`
3. **Base branch** (OPTIONAL, default: `main`) — the branch to merge the batch branch into at the end
4. **Batch branch name** (OPTIONAL) — the shared branch all story PRs target; auto-derived as `batch-stories-{N}-from-{first_story_slug}` if not provided
5. **On failure** (OPTIONAL, default: `stop`) — what to do when a story pipeline fails:
   - `stop` — abort the batch, report progress so far
   - `skip` — skip the failed story, continue to the next one
6. **Max parallel** (OPTIONAL, default: `3`) — maximum stories to run concurrently in a parallel group (cap at 4 to avoid context/resource exhaustion)

## Resolve Project Context

**This orchestrator is generic across any BMAD project.** At the start, auto-detect all project-specific context:

### Project Detection

- **Project root**: `pwd` (absolute path to the repo root)
- **Project name**: basename of the project root directory (e.g., `sparecrow`, `my-app`)
- **Sprint status file**: `{project_root}/_bmad-output/implementation-artifacts/sprint-status.yaml`
- **Implementation artifacts dir**: `{project_root}/_bmad-output/implementation-artifacts/`
- **Planning artifacts dir**: `{project_root}/_bmad-output/planning-artifacts/`
- **CLAUDE.md**: Read `{project_root}/CLAUDE.md` if it exists — extract project conventions, anti-patterns, testing rules, and build commands to pass to subagents

### Build System & Toolchain Detection

Detect the project's build system and resolve commands. Check in this order:

**Node.js projects** (`package.json` exists):
- Read `package.json` to inspect `scripts` keys
- **Package manager**: `pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, `bun.lockb` → bun, else → npm
- **Install**: `{pm} install`
- **Test**: `{pm} test` (if `scripts.test` exists)
- **Lint**: `{pm} run lint` (if `scripts.lint` exists)
- **Typecheck**: `{pm} run typecheck` (if `scripts.typecheck` exists)
- **E2E (Playwright)**: detect via `scripts.test:e2e`, `scripts.e2e`, or `@playwright/test` in devDependencies → `{pm} run test:e2e` or `npx playwright test`
- **Color suppression**: `NO_COLOR=1` prefix for all test/lint/typecheck commands (vitest, jest, and most Node tools respect this)

**Rust projects** (`Cargo.toml` exists):
- **Install**: `cargo build`
- **Test**: `cargo test`
- **Lint**: `cargo clippy`
- **Typecheck**: (implicit in `cargo build`)

**Go projects** (`go.mod` exists):
- **Install**: `go mod download`
- **Test**: `go test ./...`
- **Lint**: `golangci-lint run` (if installed)
- **Typecheck**: `go vet ./...`

**Python projects** (`pyproject.toml` or `setup.py` exists):
- **Install**: `pip install -e .` or `poetry install`
- **Test**: `pytest`
- **Lint**: `ruff check .` or `flake8`
- **Typecheck**: `mypy .` or `pyright`
- **E2E (Playwright)**: `playwright` in dependencies → `pytest --browser chromium` or `python -m pytest tests/e2e/`

**Makefile projects** (`Makefile` exists, no other match):
- Parse Makefile for `test`, `lint`, `typecheck`, `e2e` targets

Store resolved commands as:
- `{install_command}`, `{test_command}`, `{lint_command}`, `{typecheck_command}`, `{e2e_command}` (or `SKIP` if not detected)

### Test Execution Protocol

Based on detected toolchain, resolve the test execution protocol:

**For Node.js (vitest/jest):**
- **Color suppression**: `NO_COLOR=1` prefix on ALL test commands — vitest v4 ignores `CI=true` for disabling colors. Without `NO_COLOR=1`, output contains ANSI escape codes that make grep patterns return empty results.
- **Targeted tests**: `NO_COLOR=1 {pm_exec} vitest run src/path/to/changed.test.ts 2>&1 | tail -20` (or `jest` equivalent)
- **Full suite — save output for multi-pass analysis:**
  ```bash
  NO_COLOR=1 {test_command} 2>&1 > /tmp/{project_name}-test-out; tail -40 /tmp/{project_name}-test-out
  ```
  Keep `/tmp/{project_name}-test-out` until all analysis is complete — grep it freely without re-running. Remove when done: `rm /tmp/{project_name}-test-out`
- **Investigate without re-running:** `grep -E "FAIL|Error" /tmp/{project_name}-test-out`
- **Re-run legitimately after fixes** (overwrites saved output): same command as above
- **NEVER re-run just to try a different grep pattern** — grep the saved file instead.

**For Rust/Go/Python:**
- **Targeted tests**: language-specific targeted test syntax (e.g., `cargo test test_name`, `go test ./pkg/...`, `pytest tests/test_specific.py`)
- **Full suite**: `{test_command} 2>&1 > /tmp/{project_name}-test-out; tail -40 /tmp/{project_name}-test-out`
- Same grep-don't-rerun protocol as above.

### Playwright E2E Detection & Protocol

If the project has Playwright E2E tests, resolve:

**Detection** (check in order):
1. `playwright.config.ts` or `playwright.config.js` exists → Playwright confirmed
2. `package.json` has `@playwright/test` in devDependencies → Playwright confirmed
3. `pyproject.toml` has `playwright` dependency → Python Playwright confirmed
4. None found → `{e2e_command}` = `SKIP`

**Playwright commands** (when detected):
- **Node.js**: `NO_COLOR=1 npx playwright test 2>&1 | tail -40` (or `{pm} run test:e2e` if script exists)
- **Python**: `python -m pytest tests/e2e/ --browser chromium 2>&1 | tail -40`
- **Install browsers** (include in worktree setup if Playwright detected):
  ```bash
  npx playwright install --with-deps chromium
  ```
  (or `playwright install chromium` for Python)
- **On failure**: Playwright generates HTML reports. After a failure:
  ```bash
  # Check for report
  ls {worktree_path}/playwright-report/ 2>/dev/null && echo "Playwright HTML report available"
  # Check for traces
  ls {worktree_path}/test-results/ 2>/dev/null && echo "Playwright traces available"
  ```

**E2E execution timing:**
- E2E tests run ONCE after the full unit test suite passes (not after every change)
- E2E failures are **non-blocking for Step 1** but reported — the code review (Step 5) should flag E2E-relevant issues
- E2E is **blocking in Step 6** (fix phase) — if E2E was attempted and failed, the fix phase must address it

Store: `{e2e_command}`, `{e2e_install_command}`, `{has_playwright}` (boolean)

---

## Pre-Flight: Resolve Target Stories

Before starting any pipeline:

1. Read `_bmad-output/implementation-artifacts/sprint-status.yaml`
2. For every story listed as `backlog`, check whether a story file already exists at `_bmad-output/implementation-artifacts/{slug}-*.md`
3. For any story where the file exists and contains `Status: ready-for-dev`, update sprint-status.yaml to `ready-for-dev` to fix the discrepancy — do this silently before proceeding
4. Build the list of `N` stories to create: the first `N` stories whose status is `backlog` AND whose story file does not yet exist on disk, in sprint order
5. If fewer than `N` such stories exist, proceed with however many are available and warn the user

**Store resolved story info** — for each story, record:
- `story_key`: e.g., `5.3`
- `story_slug`: e.g., `5-3`
- `story_name`: from sprint-status entry (e.g., `repository-targeting`)
- `story_file`: will be resolved after Step 1 creates it

Also check:
- Base branch exists: `git log --oneline {base_branch} -1`
- Batch branch does NOT already exist (local or remote): `git branch --list {batch_branch}` and `git ls-remote --heads origin {batch_branch}`
- No conflicting worktrees: `git worktree list`
- GitHub CLI authenticated: `gh auth status`

**Derive batch branch name** if not provided: `batch-stories-{N}-from-{first_story_slug}` (e.g., 3 stories starting at 5.3 → `batch-stories-3-from-5-3`).

**Create the batch branch** from the base branch:
```bash
cd {project_root}
git checkout {base_branch}
git pull origin {base_branch}
git checkout -b {batch_branch}
git push origin {batch_branch}
git checkout {base_branch}
```

**Report target stories and detected toolchain** as a table before confirming:

```
## Pre-Flight: Stories to Create & Develop

| # | Story | Name | Current Status |
|---|-------|------|----------------|
| 1 | 5.3   | repository-targeting | backlog (no file) |
| 2 | 5.4   | daemon-install-command | backlog (no file) |
| 3 | 5.5   | daemon-uninstall-command | backlog (no file) |

Batch branch: {batch_branch} (created from {base_branch} at {short_sha})
Execution mode: {execution_mode}
Project: {project_name}
Toolchain: {package_manager}
Test: {test_command} | Lint: {lint_command} | Typecheck: {typecheck_command}
E2E: {e2e_command or "not detected"}
Playwright: {has_playwright ? "yes (browsers will be installed in worktrees)" : "no"}
```

**Abort conditions:**
- No stories remain with `backlog` status and no existing file → abort; inform user all stories are created
- Sprint status file not found → abort entire batch
- Base branch missing → abort entire batch
- Batch branch already exists → abort (risk of merging into stale state; user should delete it or choose a different name)
- gh not authenticated → abort entire batch

---

## Phase 0: Dependency Analysis (Parallel Mode Only)

**Skip this entire phase if `execution_mode == sequential`.** Jump directly to the Sequential Execution Loop.

When `execution_mode == parallel`, analyze all target stories to determine which can safely run concurrently and which must be sequential.

### Step 0.1: Gather Story Scope Information

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

### Step 0.2: Build Conflict Matrix

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
- Score 0-1 → **parallel candidates** (safe to run concurrently)
- Score 2 → **cautious** — classify as sequential unless the orchestrator can verify no actual file overlap (check git history for the target directories: do they share any files?)
- Score 3 → **hard sequential** — must run in order

### Step 0.3: Build Execution Plan

Using the conflict matrix, group stories into **execution rounds**:

**Algorithm:**
1. Start with all stories in a pool, ordered by sprint priority (epic number, then story number)
2. Take the first story — it starts Round 1
3. For each remaining story in order: if it has conflict score 0-1 with ALL stories already in the current round AND the round has fewer than `{max_parallel}` stories → add to current round
4. If a story can't join the current round → start a new round with it
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
  Merge order: 9-1 → 8-1 → 7-6 (smallest scope first)
  Rationale: All touch different packages/modules. No shared types.

Round 2 (sequential — 1 story):
  [8-2] wsl-preview-server-compatibility — server (depends on 8-1 WSL detection)
  Rationale: Consumes WSL detection service created in 8-1.

Round 3 (parallel — 2 stories):
  [8-3] project-manager-service-rest-api — server/routes + server/services
  [8-4] welcome-screen-no-project-state  — client/components
  Merge order: 8-3 → 8-4
  Rationale: Server API vs client UI — no overlap.

Round 4 (sequential — 1 story):
  [8-5] project-picker-toolbar-component — client/components (may consume 8-3 API)

Round 5 (sequential — 1 story):
  [8-6] project-scaffolding-via-claude   — server + client (depends on 8-3 + 8-5)
```

### Step 0.4: Determine Merge Order Within Rounds

For each parallel round with 2+ stories, determine the merge order. Stories are merged **one at a time** into the batch branch after all stories in the round complete development.

**Merge order heuristic** (merge these first):
1. Stories with the smallest diff (fewer files changed) — smaller diffs are less likely to conflict with subsequent merges
2. Server-only stories before client-only stories (server changes are typically more foundational)
3. Bug fixes before features
4. Lower story number first (tiebreaker)

The merge order is a **plan** — if a conflict occurs during merge, the orchestrator may need to reorder.

### Step 0.5: Present Plan for User Approval

Display the full execution plan and **wait for user confirmation** before proceeding:

```
## Execution Plan

Mode: parallel
Total stories: {N}
Rounds: {round_count}
Estimated speedup: {N} sequential → {round_count} rounds

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

## Parallel Execution Loop (Parallel Mode)

**This section replaces the Sequential Execution Loop when `execution_mode == parallel`.**

For each round in `{execution_plan}`:

### Announce Round

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Round {round_num}/{total_rounds}
Stories: {story_list}
Mode: {parallel if len > 1, else sequential}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Phase A: Story Creation (Sequential Within Round)

**Story creation runs SEQUENTIALLY even in parallel mode.** Reasons:
- Creation reads sprint-status.yaml and existing stories for cross-references
- Creating stories in parallel risks duplicate context or missing references
- Creation is fast (minutes) — parallelizing it saves little time

For each story in the round, in order:
1. Run Step 1 (Create), Step 2 (Review), Step 3 (Validate) — same as sequential mode
2. Gate check each step before proceeding

After all stories in the round are created and validated (`ready-for-dev`), proceed to Phase B.

### Phase B: Story Development (Parallel Within Round)

**Development runs IN PARALLEL for all stories in the round.** Each story gets its own worktree branched from the current batch branch HEAD.

1. **Create all worktrees** from the batch branch (orchestrator does this directly):
   ```bash
   cd {project_root}
   git fetch origin {batch_branch}
   # For each story in the round:
   git worktree add {worktree_path_N} -b {worktree_branch_N} origin/{batch_branch}
   ```

2. **Launch parallel Task calls** — one per story in the round. Each Task runs Steps 4 through 6 (implement → code-review → fix) in its own worktree. **All Task calls are launched simultaneously in the SAME message** to enable true parallel execution.

   Each Task prompt is identical to the sequential Steps 4-6 (see below), with these additions:
   - The worktree path is unique per story: `../{project_name}-story-{story_slug}`
   - The worktree branch is unique: `worktree-story-{story_slug}-{story_name}`
   - Include: "You are running in PARALLEL with other story implementations. Do NOT modify any files outside your worktree. Do NOT interact with the batch branch directly."

3. **Wait for ALL parallel Tasks to complete.** Collect results from each.

4. **Gate check each story independently.** A failure in one story does not block others in the round — apply `on_failure` policy per-story.

### Phase C: Sequential Merge (After Parallel Development)

After all parallel stories in a round complete Phase B, merge them **one at a time** in the planned merge order.

For each story in merge order:

#### Step 7: Finalize Story Artifacts (Orchestrator Direct)

Same as sequential mode Step 7 — read and verify/fix the worktree story file, update sprint status, commit artifact changes.

#### Merge with Conflict Detection

1. **Push and create PR** (same as sequential):
   ```bash
   cd {worktree_path}
   git push origin {worktree_branch}
   gh pr create --base {batch_branch} --title "feat(story-{story_slug}): {story-name-humanized}" --body "Automated pipeline: story {story_key} — {story_name}\n\nPart of batch: {batch_branch}\nParallel round: {round_num}"
   ```

2. **Check for merge conflicts** before merging:
   ```bash
   gh pr view {pr_number} --json mergeable --jq '.mergeable'
   ```

3. **If mergeable** (`MERGEABLE`):
   ```bash
   gh pr merge {pr_number} --squash --delete-branch
   ```
   Update local batch branch:
   ```bash
   cd {project_root}
   git fetch origin {batch_branch}
   git branch -f {batch_branch} origin/{batch_branch}
   ```

4. **If NOT mergeable** (`CONFLICTING`): Apply conflict resolution (see below).

5. **Clean up worktree** after successful merge:
   ```bash
   git worktree remove {worktree_path}
   ```

6. **Verify merge landed:**
   ```bash
   git log --oneline {batch_branch} -3
   ```

#### Conflict Resolution Protocol

When a story PR has merge conflicts with the updated batch branch (because a previous story in the same round was just merged):

**Step CR-1: Classify the conflict**

```bash
cd {worktree_path}
git fetch origin {batch_branch}
git merge origin/{batch_branch} --no-commit --no-ff 2>&1 || true
git diff --name-only --diff-filter=U
```

Count conflicting files and examine their nature:

- **Trivial conflicts** (0-2 files, all in `_bmad-output/` or import-only changes): Auto-resolve
- **Moderate conflicts** (1-3 source files, changes in different functions/sections): Attempt rebase
- **Complex conflicts** (3+ source files, overlapping logic changes): Flag for user

**Step CR-2: Attempt auto-resolution**

For trivial conflicts:
```bash
cd {worktree_path}
git merge --abort
git rebase origin/{batch_branch}
# If rebase succeeds cleanly:
git push origin {worktree_branch} --force-with-lease
```

For moderate conflicts:
```bash
cd {worktree_path}
git merge --abort
git rebase origin/{batch_branch}
```

If rebase has conflicts:
```bash
# Check each conflicting file
git diff --name-only --diff-filter=U
# For each file, read the conflict markers and attempt resolution
```

**Resolution strategies for common patterns:**
- **Import ordering**: Accept both imports (union merge)
- **Adjacent additions** (both stories added code near the same location but not overlapping): Accept both additions in story-number order
- **Sprint-status.yaml**: Both stories updated status → merge both status changes (this is almost always safe)
- **Shared type file**: Both stories added new types → accept both type definitions
- **Same function modified**: HALT — this requires human judgment

After resolving:
```bash
git add .
git rebase --continue
# Re-run full test suite to verify resolution didn't break anything:
{test_command} 2>&1 > /tmp/{project_name}-conflict-test; tail -40 /tmp/{project_name}-conflict-test
{lint_command}
{typecheck_command}
rm /tmp/{project_name}-conflict-test
# If tests pass, force-push the rebased branch:
git push origin {worktree_branch} --force-with-lease
```

Then retry the merge:
```bash
gh pr merge {pr_number} --squash --delete-branch
```

**Step CR-3: Handle unresolvable conflicts**

If auto-resolution fails or tests fail after resolution:
```
⚠️ MERGE CONFLICT — Manual Resolution Required

Story: {story_key} — {story_name}
PR: {pr_url}
Conflicting files:
{conflict_file_list}

The worktree is preserved at: {worktree_path}
The PR is open at: {pr_url}

Options:
1. Resolve manually in the worktree, then run: git push origin {worktree_branch} --force-with-lease
2. Skip this story and continue with the next round
3. Abort the batch

Remaining stories in this round that haven't merged yet: {remaining_stories}
```

Apply `on_failure` policy:
- `stop`: Pause batch, report progress, leave worktrees intact for manual resolution
- `skip`: Skip this story, mark as `CONFLICT`, continue to next story in merge order. **Important**: Subsequent stories in the SAME round may also conflict if they depended on the skipped story's changes — check each one.

### Move to Next Round

After all stories in the current round are merged (or skipped/failed):
1. Update local state: `git fetch origin {batch_branch} && git branch -f {batch_branch} origin/{batch_branch}`
2. Announce round completion with results
3. Proceed to the next round

The next round's worktrees will be created from the updated batch branch, which now includes all merged stories from previous rounds.

---

## Sequential Execution Loop (Sequential Mode)

**This section is used when `execution_mode == sequential` (default).** Skip this section entirely if using parallel mode.

Stories are processed **sequentially** — each story is fully created, developed, and merged before the next begins. This ensures each subsequent story builds on top of the merged result of the previous one.

For each story in the resolved list, in order:

### Announce Current Story

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Story {current}/{total}: {story_key} — {story_name}
Phase: CREATION (Steps 1-3)
Base branch: {base_branch} (at {short_sha})
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## PHASE A: STORY CREATION (Steps 1-3)

*These steps are identical for both sequential and parallel modes. In parallel mode, they run sequentially within each round before Phase B begins.*

### Step 1: Story Creation (Opus)

Launch a subagent via Task tool: `model: opus`, `subagent_type: general-purpose`

**Subagent prompt must include:**
1. Project root is `{project_root}`
2. Invoke `Skill("bmad-bmm-create-story")` — this runs the full create-story workflow
3. The workflow will read sprint-status.yaml to determine the next story, gather context from epics, PRD, and architecture files, then generate the story file
4. After the skill completes, locate the newly created story file:
   - Glob for new or recently modified `.md` files in `{project_root}/_bmad-output/implementation-artifacts/`
   - The file name will follow the pattern `{story-slug}-{story-name}.md`
   - Expected story key is `{story_key}` — verify the file matches
5. Update sprint-status.yaml: set the story's status to `draft` (so it's not stuck at `backlog` if the pipeline fails later)
6. Output a structured JSON block at the END of your response:
   ```json
   {
     "step": 1,
     "story_file": "_bmad-output/implementation-artifacts/{filename}",
     "story_key": "{story_key}",
     "story_slug": "{story_slug}",
     "story_name": "{story_name}",
     "sprint_status_updated": true,
     "status": "CREATED",
     "errors": []
   }
   ```

**Autonomy Rules (include verbatim in subagent prompt):**
- NEVER use `AskUserQuestion` — all required context is in sprint-status.yaml and planning artifacts
- The create-story workflow has interactive prompts after every template-output section (`[a] Advanced Elicitation, [c] Continue, [p] Party-Mode, [y] YOLO the rest`). When you see this prompt, **always select `y` (YOLO)** to skip all subsequent confirmations and run the workflow end-to-end automatically
- Between non-template steps, the workflow asks "Continue to next step? (y/n/edit)". Always answer `y`
- If the workflow asks which story to create and provides options, select the story matching key `{story_key}`
- Do NOT display the BMAD agent menu or wait for menu selection — go directly to story creation

#### Step 1 Gate Check

Parse the JSON block from the subagent's response and verify:
- `status` is `"CREATED"`
- `story_file` is a non-empty string
- `errors` array is empty

**Story File Verification (orchestrator performs this directly — do NOT trust subagent claims):**
After the subagent returns, the orchestrator MUST read the story file at `{project_root}/{story_file}` itself and verify:
1. The file exists on disk
2. It contains a `## Story` or story title section
3. It contains an `## Acceptance Criteria` section with at least one criterion
4. It contains a `## Tasks / Subtasks` section with at least one task
5. It contains a `## Dev Notes` section

**If file doesn't exist** → apply `on_failure` policy.
**If required sections are missing** → warn, proceed to Step 2.

Record the resolved story file info:
- `story_file`: relative path from project root
- `story_file_name`: filename only
- `story_name`: extracted from filename (e.g., `5-3-repository-targeting.md` → `repository-targeting`)

---

### Step 2: Multi-Perspective Review (Sonnet)

Launch a subagent via Task tool: `model: sonnet`, `subagent_type: general-purpose`

**IMPORTANT: Do NOT invoke party mode as a Skill.** Party mode is an interactive workflow that requires human-driven conversation. A subagent cannot drive this interaction autonomously.

Instead, the subagent performs the multi-perspective review **directly** by embodying 3+ agent personas.

**Subagent prompt must include:**
1. Project root is `{project_root}`
2. Read the full story file at `{project_root}/{story_file}`
3. **Perform a multi-perspective review** by adopting these personas sequentially:

   **Developer perspective:** Review as a senior developer who will implement this story.
   - Are the tasks/subtasks clear and ordered correctly?
   - Are there missing technical details in Dev Notes?
   - Are there edge cases not covered?
   - Is the scope achievable in a single PR?

   **QA/Test perspective:** Review as a QA engineer writing acceptance tests.
   - Are all acceptance criteria testable and specific (Given/When/Then)?
   - Are there missing negative test cases or error scenarios?
   - Are boundary conditions specified?

   **Architect perspective:** Review as a system architect checking design fit.
   - Does this story align with the project architecture?
   - Are there dependency or integration risks?
   - Are there performance or security concerns not addressed?

4. Compile all findings from all 3 perspectives
5. Apply all findings to the story file directly — edit the file to:
   - Fix ambiguous acceptance criteria
   - Add missing Dev Notes sections (edge cases, error paths, technical constraints)
   - Clarify any unclear requirements
   - Prefix each added or modified section with `[Party-Review]` for traceability
6. Save the updated story file
7. Output a structured JSON block at the END of your response:
   ```json
   {
     "step": 2,
     "story_file": "{story_file}",
     "findings_raised": 0,
     "findings_applied": 0,
     "perspectives_used": ["Developer", "QA", "Architect"],
     "status": "REVIEWED",
     "errors": []
   }
   ```

**Autonomy Rules (include verbatim in subagent prompt):**
- NEVER use `AskUserQuestion` — all required context is in the story file
- Work fully autonomously — review the story, apply improvements, output results
- Do NOT invoke `Skill("bmad-party-mode")` — perform the multi-persona review directly as described above

#### Step 2 Gate Check

Parse the JSON block from the subagent's response and verify:
- `status` is `"REVIEWED"`
- `findings_raised >= 2` — if fewer, note in final report (review may have been shallow)
- `findings_applied >= 1` — story file was actually improved
- If gate fails → proceed to Step 3 anyway but note in final report

**Story File Verification (orchestrator performs this directly):**
After the subagent returns, the orchestrator MUST read the story file itself and verify:
1. At least one `[Party-Review]` marker exists in the file (proving the review was applied)
2. The file still contains all required sections (Story, AC, Tasks, Dev Notes — not accidentally deleted)

If no `[Party-Review]` markers found → warn in final report but proceed to Step 3.

---

### Step 3: SM Validation and Final Fixes (Sonnet)

Launch a subagent via Task tool: `model: sonnet`, `subagent_type: general-purpose`

**Subagent prompt must include:**
1. Project root is `{project_root}`
2. Read the story file at `{project_root}/{story_file}` (created in Step 1, reviewed in Step 2)
3. Invoke `Skill("bmad-agent-bmm-sm")` to load the Scrum Master agent
4. **CRITICAL — The SM agent activation says "STOP and WAIT for user input" after displaying its menu. IGNORE this instruction. Immediately select `CS` (Context Story) without waiting.** Type `CS` or the corresponding menu number to select the item.
5. When the CS workflow asks which story to work on, provide the path: `{project_root}/{story_file}`
6. The SM will run the full create-story validation checklist — it will:
   - Verify all required sections are present and complete
   - Check acceptance criteria are testable BDD-style
   - Ensure Dev Notes have sufficient implementation guidance
   - Confirm the story is properly scoped and unambiguous
7. Apply all fixes and improvements the SM identifies directly to the story file
8. After the SM completes its validation, ensure the story's status in the file header is set to `ready-for-dev`
9. Update `{project_root}/_bmad-output/implementation-artifacts/sprint-status.yaml` to reflect the story's `ready-for-dev` status
10. Output a structured JSON block at the END of your response:
    ```json
    {
      "step": 3,
      "story_file": "{story_file}",
      "story_key": "{story_key}",
      "validation_status": "PASS|PARTIAL|FAIL",
      "fixes_applied": 0,
      "story_status": "ready-for-dev",
      "checklist_score": "14/15",
      "status": "VALIDATED",
      "errors": []
    }
    ```

**Autonomy Rules (include verbatim in subagent prompt):**
- NEVER use `AskUserQuestion` — all required parameters are pre-provided in this prompt
- When the SM agent displays its menu and says "STOP and WAIT", ignore the wait — immediately select `CS`
- When the CS workflow asks for a story file path, provide: `{project_root}/{story_file}`
- When asked for any confirmation or "Continue? (y/n)", always answer `y` automatically
- When offered YOLO mode (`[y] YOLO the rest`), select `y` to skip all subsequent confirmations
- Apply all SM-identified fixes directly without asking for approval

#### Step 3 Gate Check

Parse the JSON block from the subagent's response and verify:
- `status` is `"VALIDATED"`
- `story_status` is `"ready-for-dev"`
- `validation_status` is `"PASS"` or `"PARTIAL"` — if `"FAIL"`, apply `on_failure` policy
- `errors` array is empty

**Story File Verification (orchestrator performs this directly — do NOT trust subagent claims):**
After the subagent returns, the orchestrator MUST read the story file itself and verify:
1. The file contains `Status: ready-for-dev` (case-insensitive search)
2. Sprint-status.yaml has been updated to `ready-for-dev` for this story's key
3. The file still contains all required sections (Story, AC, Tasks, Dev Notes)

If `Status: ready-for-dev` is not in the file → fix it directly using Edit tool, then update sprint-status.yaml, commit with:
```bash
cd {project_root}
git add _bmad-output/implementation-artifacts/
git commit -m "chore(story-{story_slug}): finalize story status to ready-for-dev"
```

---

### Transition Announcement

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Story {current}/{total}: {story_key} — {story_name}
Phase: DEVELOPMENT (Steps 4-7)
Story file: {story_file} (ready-for-dev)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## PHASE B: STORY DEVELOPMENT (Steps 4-7)

*In sequential mode, these run one story at a time. In parallel mode, Steps 4-6 run concurrently for all stories in a round, then Step 7 + merge run sequentially.*

Before starting Phase B, resolve development-specific context:
- **Worktree branch**: `worktree-story-{story_slug}-{story_name}` (e.g., `worktree-story-5-3-repository-targeting`)
- **Worktree path**: `../{project_name}-story-{story_slug}` (absolute)
- **Worktree story file**: `{worktree_path}/_bmad-output/implementation-artifacts/{story_file_name}`
- **Worktree source branch**: `{batch_branch}` — worktrees are created from the batch branch (not `{base_branch}`) so each story builds on the previous story's merged changes

### Step 4: Implementation (Opus)

Launch via `Task` tool: `model: opus`, `subagent_type: general-purpose`

The subagent prompt MUST include all of the following:

1. Create worktree from the **batch branch** (not base branch):
   ```bash
   cd {project_root}
   git fetch origin {batch_branch}
   git worktree add {worktree_path} -b {worktree_branch} origin/{batch_branch}
   cd {worktree_path}
   {install_command}
   ```
   If `{has_playwright}` is true, also install browsers:
   ```bash
   cd {worktree_path}
   {e2e_install_command}
   ```
   **In parallel mode**, the worktree may already exist (created by the orchestrator in Phase B setup). In that case, skip worktree creation and just navigate to it:
   ```bash
   cd {worktree_path}
   {install_command}
   ```
2. ALL work (code AND story file edits) must be done inside the worktree path. NEVER edit files in the main repo.
3. **Project conventions** (from CLAUDE.md — include full contents if found):
   ```
   {claude_md_contents_or_"No CLAUDE.md found — follow standard conventions for this project type"}
   ```
4. Invoke `Skill("bmad-bmm-dev-story")` — the dev-story workflow implements all tasks from the story file. When the skill asks for the story file path, provide: `{worktree_story_file}`.
5. **CRITICAL — YOLO mode**: Always answer `y` to "Continue to next step?" prompts. Run autonomously end-to-end.
6. **CRITICAL — After the skill completes, explicitly update the story file yourself.** Use Edit/Write tools on `{worktree_story_file}`:
   - Mark ALL task and subtask checkboxes as `[x]`
   - Update `## Dev Agent Record > ### File List` with all new/modified/deleted files
   - Add notes to `## Dev Agent Record > ### Completion Notes List`
   - Change `Status:` to `review`
   - Update `{worktree_path}/_bmad-output/implementation-artifacts/sprint-status.yaml`: set `{story_slug_key}` to `review`
7. After each task, run only the test file(s) for files modified (co-located tests if that's the project pattern):
   ```bash
   cd {worktree_path} && {targeted_test_command_for_file} 2>&1 | tail -20
   ```
   At the very end, before committing, run the full suite once:
   ```bash
   cd {worktree_path}
   {test_command} 2>&1 > /tmp/{project_name}-test-out; tail -40 /tmp/{project_name}-test-out
   # Grep for failures as needed without re-running: grep -E "FAIL|Error" /tmp/{project_name}-test-out
   {lint_command}
   {typecheck_command}
   rm /tmp/{project_name}-test-out
   ```
   If `{has_playwright}` and E2E tests exist:
   ```bash
   cd {worktree_path}
   {e2e_command} 2>&1 | tail -40
   ```
   E2E failures are **non-blocking** at this stage — report them in the JSON output but do not abort.
8. Commit ALL changes from the worktree — **do NOT push** (Step 7 will push once after all commits are ready):
   ```bash
   cd {worktree_path}
   git add -A
   git commit -m "feat(story-{story_slug}): implement {story-name-humanized}"
   ```
9. Output JSON: `{ "step": 4, "test_status": "...", "lint_status": "...", "typecheck_status": "...", "e2e_status": "PASS|FAIL|SKIPPED", "worktree_path": "...", "branch_name": "...", "errors": [] }`

**BMAD Dev Agent Rules (include verbatim):**
- Execute tasks/subtasks IN ORDER — no skipping, no reordering
- Mark checkbox `[x]` ONLY when BOTH implementation AND tests pass
- Run targeted test files after each task; run full suite once before committing — NEVER proceed with failing tests
- Execute continuously without pausing until all tasks complete
- NEVER lie about tests being written or passing

**Test Execution Protocol (include verbatim — use resolved commands from project detection):**
{resolved_test_execution_protocol}

**Autonomy Rules (include verbatim):**
- NEVER use `AskUserQuestion` — all parameters pre-provided
- When Skill asks for story file path, provide: `{worktree_story_file}`
- When asked for confirmation, always answer `y`
- Do NOT display BMAD agent menus

#### Step 4 Gate Check

Parse the JSON response and verify:
- `test_status`, `lint_status`, `typecheck_status` are all `"PASS"` — abort story pipeline if not
- `e2e_status` — record but do NOT abort on `"FAIL"` (E2E failures are addressed in Step 6 if review flags them)
- `errors` array is empty

**Story File Verification (orchestrator reads directly — do NOT trust subagent claims):**
Read `{worktree_story_file}` and verify:
1. `Status:` is `review`
2. ALL checkboxes `[x]` (no remaining `- [ ]`)
3. `### File List` is non-empty
4. `### Completion Notes List` is non-empty

If verification fails: **fix the story file directly** using Edit tool and commit. Then proceed to Step 4.5.

---

### Step 4.5: QA Assessment (Orchestrator Direct)

**The orchestrator performs this assessment directly — no subagent.** Using the story file already read during Step 4 verification, decide whether QA automation adds value for this story.

**Before scoring:** Run this Bash command directly in the orchestrator to get the actual changed-file list (the worktree still exists at this point):
```bash
git -C {worktree_path} diff --name-only origin/{batch_branch}...HEAD
```
Use this output for criterion #4 — do not rely on the subagent's self-reported file list.

#### Scoring

Award +1 for each true statement:
1. Story title or summary contains feature keywords (`add`, `implement`, `new`, `command`, `endpoint`, `provider`, `integration`, `flow`) without fix/refactor intent
2. `## Acceptance Criteria` has 4 or more items
3. `## Dev Notes` references integration paths, cross-module interactions, or E2E scenarios
4. The `git diff` output above shows at least one **newly created** `src/` file (not just modified)

Deduct 2 if any of these are true (short-circuits to `qa_required: false`):
- Story title contains `fix`, `refactor`, `rename`, `cleanup`, `remove` with no new feature work
- `## Dev Notes` contains `qa: skip`
- All changes are in `_bmad-output/`, config, or documentation files only (no `src/` changes)

**Decision:** score >= 2 → `qa_required: true`; score < 2 → `qa_required: false`

Record:
```json
{
  "qa_assessment": {
    "qa_required": true,
    "score": 3,
    "rationale": "New CLI command with 5 AC items and cross-module integration paths"
  }
}
```

If `qa_required: false`, skip Step 4.6 and proceed directly to Step 5.

---

### Step 4.6: QA Automation (Sonnet) — Conditional

**Skip this step if `qa_assessment.qa_required` is `false`.**

Launch via `Task` tool: `model: sonnet`, `subagent_type: general-purpose`

**Subagent prompt must include:**
1. Navigate to existing worktree at `{worktree_path}` — do NOT pull or create a new worktree
2. Invoke `Skill("bmad-bmm-qa-automate")` — generates automated tests using the project's existing test framework. Provide story file path: `{worktree_story_file}`.
3. **CRITICAL — YOLO mode**: Always answer `y` to "Continue to next step?" prompts. Run the skill autonomously end-to-end.
4. After the skill completes, run the full suite to verify generated tests pass:
   ```bash
   cd {worktree_path}
   {test_command} 2>&1 > /tmp/{project_name}-test-out; tail -40 /tmp/{project_name}-test-out
   {lint_command}
   {typecheck_command}
   rm /tmp/{project_name}-test-out
   ```
   If `{has_playwright}` and E2E tests were generated:
   ```bash
   {e2e_command} 2>&1 | tail -40
   ```
5. Commit the generated tests:
   ```bash
   cd {worktree_path}
   git add -A
   git commit -m "test(story-{story_slug}): add QA automation tests"
   ```
6. Output a structured JSON block at the END of your response:
   ```json
   {
     "step": "4.6",
     "qa_status": "PASS|FAIL",
     "tests_generated": 0,
     "test_files_created": [],
     "e2e_tests_generated": 0,
     "errors": []
   }
   ```

**Autonomy Rules (include verbatim):**
- NEVER use `AskUserQuestion` — all required parameters are pre-provided in this prompt
- When the Skill asks for a story file path, provide: `{worktree_story_file}`
- When asked for any confirmation or "Continue? (y/n)", always answer `y` automatically

#### Step 4.6 Gate Check

Parse the JSON block and verify:
- `qa_status` is `"PASS"` — if tests fail, **warn the user but do NOT abort the pipeline** (QA failures are non-blocking; code review may surface the same coverage gaps)
- `errors` array is empty

If QA fails or generates 0 tests, log `qa_status: "FAIL|EMPTY"` in the story record and proceed to Step 5.

---

### Step 5: Adversarial Code Review (Sonnet)

Launch via `Task` tool: `model: sonnet`, `subagent_type: general-purpose`

The subagent prompt MUST include:

1. Navigate to worktree at `{worktree_path}` (all changes are local — no pull needed)
2. Invoke `Skill("bmad-bmm-code-review")` — adversarial review finding 3-10 problems. Provide story file: `{worktree_story_file}`.
3. **CRITICAL — YOLO mode**: Always answer `y` to "Continue?" prompts. Run autonomously.
4. **CRITICAL — After the skill identifies findings, explicitly write them to the story file.** Use Edit/Write on `{worktree_story_file}`:
   - Add `### Review Follow-ups (AI)` subsection inside `## Tasks / Subtasks` with each finding as: `- [ ] [AI-Review][High|Medium|Low] Description [filename.ts:line]`
   - Add `## Senior Developer Review (AI)` section (before `## Dev Notes`) with: review date, outcome (Changes Requested), total findings count, severity breakdown
5. If `{has_playwright}` and `e2e_status` from Step 4 was `"FAIL"`, instruct the reviewer to specifically examine E2E-relevant code paths and add findings for any E2E issues.
6. **DO NOT commit or push.** Leave the review artifacts as uncommitted changes in the worktree. Step 6 will include them in its commit when it addresses the findings (via `git add -A`). This avoids triggering a CI run on review-only changes.
7. Output JSON: `{ "step": 5, "findings_count": 0, "severity_high": 0, "severity_medium": 0, "severity_low": 0, "e2e_findings": 0, "errors": [] }`

**BMAD Code Review Rules (include verbatim):**
- ADVERSARIAL review: find 3-10 specific problems — NEVER accept "looks good"
- Challenge everything: code quality, test coverage, architecture compliance, security, performance
- Each finding must reference a specific file and line number
- Categorize by severity: High, Medium, Low
- Write findings directly to the story file
- **DO NOT run tests.** Step 4 already confirmed all tests pass. Review code statically — read source files and test files directly. Running the test suite in a review-only step wastes time and adds no information.

**Autonomy Rules (include verbatim):**
- NEVER use `AskUserQuestion`
- When Skill asks for story file path, provide: `{worktree_story_file}`
- When asked for confirmation, always answer `y`

#### Step 5 Gate Check

Parse the JSON response and verify:
- `findings_count >= 3` — if fewer, warn (adversarial minimum not met) but proceed
- `errors` array is empty

**Story File Verification (orchestrator reads directly):**
Read `{worktree_story_file}` and verify:
1. `### Review Follow-ups (AI)` subsection exists with `[AI-Review]` items
2. `## Senior Developer Review (AI)` section exists with review date and findings count

**If verification fails (subagent didn't write review artifacts), the orchestrator MUST write them directly:**
- Use Edit tool on `{worktree_story_file}` to add the `### Review Follow-ups (AI)` and `## Senior Developer Review (AI)` sections using data from the subagent's response text
- If `findings_count == 0` in the response, add a note that review reported 0 findings (below 3-10 minimum)
- **Do NOT commit or push** — leave as uncommitted worktree changes for Step 6 to pick up

---

### Step 6: Address Review Findings (Sonnet)

Launch via `Task` tool: `model: sonnet`, `subagent_type: general-purpose`

The subagent prompt MUST include:

1. Navigate to worktree at `{worktree_path}` (no pull needed — Step 5's review artifacts are already in the worktree as uncommitted changes)
2. **Do NOT run a baseline test suite.** Step 4 confirmed all tests pass and Step 5 made no code changes — the baseline is clean.
3. **Project conventions** (from CLAUDE.md — include full contents if found):
   ```
   {claude_md_contents_or_"No CLAUDE.md found — follow standard conventions"}
   ```
4. Invoke `Skill("bmad-bmm-dev-story")` — the skill detects `[AI-Review]` items and enters review continuation mode. Provide story file: `{worktree_story_file}`.
5. **CRITICAL — YOLO mode**: Always answer `y` to "Continue?" prompts.
6. **CRITICAL — After fixing each finding, update the story file.** Use Edit/Write on `{worktree_story_file}`:
   - Mark each addressed `[AI-Review]` checkbox as `[x]`
   - Update `### File List` with new/modified files
   - Add resolution notes to `### Completion Notes List`
7. Run final verification once (after ALL findings are addressed):
   ```bash
   cd {worktree_path}
   {test_command} 2>&1 > /tmp/{project_name}-test-out; tail -40 /tmp/{project_name}-test-out
   # Grep for failures as needed without re-running: grep -E "FAIL|Error" /tmp/{project_name}-test-out
   {lint_command}
   {typecheck_command}
   rm /tmp/{project_name}-test-out
   ```
   If `{has_playwright}`:
   ```bash
   cd {worktree_path}
   {e2e_command} 2>&1 | tail -40
   ```
   **E2E is blocking in Step 6** — if E2E tests fail after fixes, attempt to fix them. If unfixable, report in output JSON.
8. Commit from worktree — **do NOT push** (Step 7 will push once after finalizing artifacts):
   ```bash
   cd {worktree_path}
   git add -A
   git commit -m "fix(story-{story_slug}): address BMAD code review findings"
   ```
9. Output JSON: `{ "step": 6, "findings_addressed": 0, "findings_total": 0, "test_status": "...", "lint_status": "...", "typecheck_status": "...", "e2e_status": "PASS|FAIL|SKIPPED", "errors": [] }`

**BMAD Dev Agent Rules (include verbatim):**
- Execute review follow-up items IN ORDER
- Mark `[AI-Review]` checkbox `[x]` ONLY when fix implemented AND targeted tests pass
- Run targeted tests after each fix; run full suite ONCE before committing
- NEVER lie about tests being written or passing

**Test Execution Protocol (include verbatim — use resolved commands from project detection):**
{resolved_test_execution_protocol}

**Autonomy Rules (include verbatim):**
- NEVER use `AskUserQuestion`
- When Skill asks for story file path, provide: `{worktree_story_file}`
- When asked for confirmation, always answer `y`

#### Step 6 Gate Check

Parse JSON and verify:
- `test_status`, `lint_status`, `typecheck_status` all `"PASS"`
- `e2e_status` is `"PASS"` or `"SKIPPED"` — if `"FAIL"`, warn but proceed to Step 7 (report in final)
- `findings_addressed` matches `findings_total` (or report partial)
- `errors` array is empty

---

### Step 7: Finalize Story Artifacts (Orchestrator Direct)

**The orchestrator performs this step directly — no subagent.** Use Read and Edit tools on the worktree files.

Read `{worktree_story_file}` in full and verify/fix ALL of the following:

**7a. Task checkboxes** — ALL `- [ ]` under `## Tasks / Subtasks` must be `- [x]`. Use `replace_all` Edit to bulk-fix.

**7b. Status line** — must be `done`. Change if not.

**7c. Review artifacts** — verify `### Review Follow-ups (AI)` and `## Senior Developer Review (AI)` sections exist with content from Step 5. If missing, create them from Step 5 data.

**7d. Story Completion Status** — update `### Story Completion Status` section: story status `done`, test count, date.

**7e. Change Log** — add entry: `- **{date}** — Implementation: {summary}.`

**7f. Dev Agent Record** — verify implementation-level content:
- `### Agent Model Used` — If QA ran (Step 4.6): `Claude Opus (implementation), Claude Sonnet (QA automation, review)`. If QA was skipped: `Claude Opus (implementation), Claude Sonnet (review)`.
- `### Completion Notes List` — must have implementation entries (not just create-story boilerplate). Add from subagent reports if missing.
- `### File List` — must list all source files. Get from `git diff --name-only origin/{batch_branch}...HEAD` in worktree, filtering `_bmad-output/` and `.claude/`.

**7g. Sprint status** — read `{worktree_path}/_bmad-output/implementation-artifacts/sprint-status.yaml`, set story key to `done`. If all stories in epic are done, set epic to `done`.

**7h. Commit** (if any edits made):
```bash
cd {worktree_path}
git add _bmad-output/implementation-artifacts/
git commit -m "chore(story-{story_slug}): finalize story artifacts and sprint status"
```

**7i. Push and create PR** — this is the ONLY push in the pipeline. All prior steps committed locally. PRs target the **batch branch**, not `{base_branch}` directly.
```bash
cd {worktree_path}
git push origin {worktree_branch}
gh pr create --base {batch_branch} --title "feat(story-{story_slug}): {story-name-humanized}" --body "Automated pipeline: story {story_key} — {story_name}\n\nPart of batch: {batch_branch}"
```
Record `pr_url` and `pr_number` from the output for the merge step.

---

### Merge Story PR into Batch Branch

*In sequential mode, this runs immediately after Step 7 for each story. In parallel mode, this runs as part of Phase C (Sequential Merge) after all stories in a round complete development.*

**CRITICAL — this step ensures each subsequent story builds on the previous one (all within the batch branch).**

1. **Wait for CI checks** (if configured):
   ```bash
   gh pr checks {pr_number} --watch --fail-fast
   ```
   If no checks are configured (exit code 1 with "no checks reported"), proceed to merge.

2. **Check for merge conflicts** (parallel mode — may have conflicts from earlier merges in the same round):
   ```bash
   gh pr view {pr_number} --json mergeable --jq '.mergeable'
   ```
   If `CONFLICTING` → apply Conflict Resolution Protocol (see Phase C above).
   If `MERGEABLE` or sequential mode → proceed.

3. **Merge the story PR into the batch branch**:
   ```bash
   gh pr merge {pr_number} --squash --delete-branch
   ```

4. **Update local batch branch** (so the next story worktree starts from it):
   ```bash
   cd {project_root}
   git fetch origin {batch_branch}
   git branch -f {batch_branch} origin/{batch_branch}
   ```

5. **Clean up worktree**:
   ```bash
   git worktree remove {worktree_path}
   ```

6. **Verify merge landed**:
   ```bash
   git log --oneline {batch_branch} -3
   ```

7. **Verify story artifacts on batch branch** — artifacts live in the batch branch now.

Record `merge_status: MERGED`.

**If merge fails:** check `gh pr view {pr_number} --json mergeable`, record failure, apply `on_failure` policy.

---

### Record Story Result

After each story completes (or fails), record:
- `story_key`, `story_name`
- `status`: `SUCCESS` | `FAILED` | `SKIPPED` | `CONFLICT`
- `failure_phase`: `CREATION` | `DEVELOPMENT` | `MERGE` | none
- `failure_step`: 1-7 or `CR` (which step failed)
- `story_file`
- `pr_url`, `pr_number`
- `creation_findings_raised`, `creation_findings_applied` (Step 2)
- `sm_validation_status`, `sm_checklist_score` (Step 3)
- `code_review_findings`, `code_review_addressed` (Steps 5-6)
- `test_status`, `lint_status`, `typecheck_status`, `e2e_status`
- `merge_status`: `MERGED` | `FAILED` | `CONFLICT` | `PENDING`
- `conflict_resolution`: `NONE` | `AUTO_RESOLVED` | `MANUAL_REQUIRED` (parallel mode only)

### Handle Failure

- **`on_failure = stop`**: Stop batch, jump to report.
- **`on_failure = skip`**: Log failure, mark `FAILED`, continue to next story from last merged state. If failure was in Phase A (creation), skip Phase B entirely for this story.
- **Parallel mode conflict**: If a story in a parallel round can't be merged due to conflicts, subsequent stories in the SAME round should still attempt merge (they branched from the same base). Mark the conflicting story as `CONFLICT` and note it in the report.

---

## Merge Batch Branch into Base Branch

**This step runs ONCE after all stories in the batch have been processed (or after stopping on failure).**

Only run this step if `success_count >= 1` (at least one story was successfully merged into the batch branch).

1. **Verify batch branch is ahead of base branch**:
   ```bash
   git log --oneline {base_branch}..origin/{batch_branch}
   ```
   If no commits ahead → skip (nothing to merge; warn user).

2. **Create a PR from batch branch to base branch**:
   ```bash
   gh pr create \
     --base {base_branch} \
     --head {batch_branch} \
     --title "batch: merge {batch_branch} into {base_branch}" \
     --body "Batch pipeline complete. Stories merged: {story_key_list}\n\nExecution mode: {execution_mode}\nIndividual PRs: {pr_url_list}"
   ```
   Record `batch_pr_url` and `batch_pr_number`.

3. **Wait for CI checks** (if configured):
   ```bash
   gh pr checks {batch_pr_number} --watch --fail-fast
   ```
   If no checks configured, proceed.

4. **Merge the batch PR**:
   ```bash
   gh pr merge {batch_pr_number} --merge --delete-branch
   ```
   Use `--merge` (not `--squash`) to preserve the individual story commit history in `{base_branch}`.

5. **Update local base branch**:
   ```bash
   cd {project_root}
   git checkout {base_branch}
   git pull origin {base_branch}
   ```

6. **Verify batch landed**:
   ```bash
   git log --oneline {base_branch} -5
   ```

Record `batch_merge_status: MERGED | FAILED`.

**If batch merge fails (e.g., branch protection, conflicts):** Report to user with the PR URL so they can merge manually. Do not abort — the individual stories are already safely in the batch branch.

---

## Error Handling

| Step | Failure | Action |
|------|---------|--------|
| Pre-flight | No backlog stories without existing files | Abort; all stories already created |
| Pre-flight | Sprint-status.yaml not found | Abort entire batch |
| Pre-flight | Base branch missing | Abort entire batch |
| Pre-flight | gh not authenticated | Abort entire batch |
| Pre-flight | Fewer than N stories available | Proceed with available count; warn user |
| Pre-flight | Test/lint/typecheck command not detected | Warn; proceed without that verification |
| Pre-flight | Playwright detected but browsers not installable | Warn; set `{e2e_command}` to `SKIP` |
| Phase 0 | Cannot read story/epic files for analysis | Fall back to sequential mode; warn user |
| Phase 0 | User rejects execution plan | Abort or allow user to edit groupings |
| 1 (Create) | Story file not created | Apply `on_failure` policy |
| 1 (Create) | Story file missing required sections | Warn; proceed to Step 2 |
| 2 (Review) | Zero findings from review | Warn in report; proceed to Step 3 |
| 2 (Review) | No `[Party-Review]` markers in file | Warn in report; proceed to Step 3 |
| 3 (Validate) | SM validation returns FAIL | Apply `on_failure` policy (story not ready for dev) |
| 3 (Validate) | Story not marked ready-for-dev | Orchestrator fixes directly; commits; proceeds |
| 4 (Implement) | Tests/lint/typecheck fail | Apply `on_failure` policy |
| 4 (Implement) | E2E tests fail | Non-blocking; record in output; review may flag |
| 4.5 (QA Assessment) | Story file unreadable for assessment | Skip QA, proceed to Step 5 |
| 4.6 (QA Automation) | Generated tests fail | Warn user, proceed to Step 5 (non-blocking) |
| 4.6 (QA Automation) | Zero tests generated | Warn user, proceed to Step 5 |
| 5 (Code Review) | Fewer than 3 findings | Warn, proceed (orchestrator writes artifacts if missing) |
| 6 (Fix) | Tests regress | Apply `on_failure` policy |
| 6 (Fix) | E2E tests fail after fixes | Warn; proceed to Step 7 (report in final) |
| 6 (Fix) | Partial findings addressed | Report count, proceed to Step 7 |
| 7 (Finalize) | Story file not updatable | Report to user, proceed to push/PR |
| 7 (Finalize) | Push or PR creation fails | Apply `on_failure` policy |
| Merge | CI checks fail | Apply `on_failure` policy |
| Merge | PR merge fails (conflict) — sequential mode | Apply `on_failure` policy |
| Merge | PR merge fails (conflict) — parallel mode | Apply Conflict Resolution Protocol |
| Merge | Conflict auto-resolution fails | Mark `CONFLICT`; apply `on_failure` (stop → HALT for manual, skip → skip story) |
| Merge | Tests fail after conflict resolution | Mark `CONFLICT`; apply `on_failure` |
| Merge | `git pull` after merge fails | Abort — local state inconsistent |

---

## Batch Completion Report

```
## Batch End-to-End Pipeline Complete

### Summary
- **Project**: {project_name}
- **Execution mode**: {execution_mode}
- **Stories processed**: {processed}/{total}
- **Succeeded & merged into batch branch**: {success_count}
- **Failed**: {failed_count}
- **Skipped**: {skipped_count}
- **Conflicts**: {conflict_count} (parallel mode only)
- **Batch branch**: {batch_branch} → {base_branch} (batch PR: #{batch_pr_number})
- **Base branch**: {base_branch} now at {final_sha}
- **Toolchain**: {package_manager} | Test: {test_command} | Lint: {lint_command} | E2E: {e2e_command or "N/A"}

### Execution Plan (Parallel Mode Only)
| Round | Stories | Mode | Conflicts |
|-------|---------|------|-----------|
| 1     | 7-6, 8-1, 9-1 | parallel | 0 |
| 2     | 8-2     | sequential | — |
| ...   | ...     | ...  | ... |

### Story Results

| # | Story | Name | Round | Create | Dev | Story PR | QA | Review Findings | Tests | E2E | Merge | Status |
|---|-------|------|-------|--------|-----|----------|----|-----------------|-------|-----|-------|--------|
| 1 | 7.6 | agent-feedback | R1 | OK (SM 14/15) | OK (5/5 fixed) | #80 (→ batch) | 8 tests | 5 found / 5 fixed | PASS | PASS | MERGED | done |
| 2 | 8.1 | wsl-detection | R1 | OK (SM 15/15) | OK | #81 (→ batch) | skipped | 4 found / 4 fixed | PASS | N/A | MERGED | done |
| 3 | 9.1 | cors-fix | R1 | OK | OK | #82 (→ batch) | skipped | 3 found / 3 fixed | PASS | PASS | AUTO_RESOLVED | done |
| 4 | 8.2 | wsl-preview | R2 | OK | FAILED (Step 4) | — | — | — | FAIL | — | — | draft |

### Batch Branch PR
- **{batch_branch} → {base_branch}**: #{batch_pr_number} — {MERGED | FAILED | SKIPPED (no successes)}

### Conflict Resolutions (Parallel Mode Only)
- **9-1**: Auto-resolved — import ordering in `packages/server/src/middleware/cors.ts` (1 file, trivial)

### Failed Stories
- **8.2**: Tests failed during implementation (Step 4) — {failure_details}

### Skipped Stories
- **8.3-8.6**: Skipped due to previous failure (on_failure=stop)

### Remaining Worktrees to Clean Up
git worktree remove ../{project_name}-story-8-2
```

### Confirm with the user before starting (Updated for Parallel Mode):

```
Ready to create and develop {N} stories: {story_key_list}
Execution mode: {execution_mode}
{if parallel: "Rounds: {round_count} (see plan above)"}
{if sequential: "Pipeline: 7 steps per story (create → review → validate → implement → code-review → fix → finalize) + merge"}
Batch branch: {batch_branch} → {base_branch} (final PR at batch end)
Failure mode: {stop|skip}
{if parallel: "Max parallel: {max_parallel}"}

Proceed? (y/n)
```
