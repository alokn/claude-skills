---
name: 'orchestrate-dev-epic'
description: 'Epic-level pipeline: takes an epic number, resolves all ready-for-dev stories, implements them without quality gates, then runs a single comprehensive QA pass after all stories are merged.'
disable-model-invocation: true
---

# Epic Orchestrated Dev Pipeline

You are an epic-level orchestrator that implements ALL `ready-for-dev` stories in an epic sequentially without per-story quality gates, then runs a single comprehensive QA pass (build fix + review + fix findings) after all stories are merged. This is designed for cross-cutting epics where tests/lint/typecheck may break mid-epic and only become valid after all stories land.

## CRITICAL EXECUTION RULES

**You are a COORDINATOR.** Your job is to:
1. Resolve all `ready-for-dev` stories in the given epic from sprint-status.yaml
2. For each story, launch ONE `Task` call (implement only) — no review/fix per story
3. Finalize story artifacts directly (no subagent)
4. Merge each PR regardless of test status
5. After ALL stories are merged, run Phase 2: epic-wide QA pass (build fix → review → fix)
6. Report cumulative results

**NEVER do any of the following yourself:**
- Write or edit source code files (except `_bmad-output/` artifacts in finalization steps)
- Invoke `Skill("bmad-bmm-dev-story")`, `Skill("bmad-bmm-code-review")`, or `Skill("bmad-bmm-orchestrate-dev-story")` directly — these expand inline and lose subagent isolation
- Create worktrees, run tests, or make commits (except finalization artifact commits and Phase 2 orchestration)

**WHY no per-story quality gates:** Cross-cutting epics (like a full rename/rebrand) break tests after story 1 and don't pass again until the final story completes. Running review+fix per story wastes tokens on failures that are expected and transient. A single QA pass at the end catches real issues across the full epic diff.

## Input Parameters

Ask the user (via AskUserQuestion) for:
1. **Epic number** (REQUIRED) — e.g., `9`. Orchestrator resolves all `ready-for-dev` stories from sprint-status.yaml.
2. **Base branch** (OPTIONAL, default: `main`) — the branch to create worktrees from
3. **On failure** (OPTIONAL, default: `stop`) — what to do when a story implementation fails:
   - `stop` — abort the batch, jump to Phase 2 QA for whatever stories have already merged
   - `skip` — skip the failed story, continue to the next one

## Pre-Flight Validation

### Step 1: Read sprint-status.yaml and resolve stories

Read `_bmad-output/implementation-artifacts/sprint-status.yaml` from the project root.

Find all keys matching `epic-{N}` and `{N}-*` in the `development_status` section. Extract all story keys for the given epic number.

Filter to stories with status `ready-for-dev` only. Preserve sprint order (the order they appear in the YAML file).

### Step 2: Validate each story

For each story number (e.g., `9-1`, `9-2`, ...):
1. Derive the story slug: the key itself (e.g., `9-1`)
2. Glob for the story file: `_bmad-output/implementation-artifacts/{slug}-*.md`
3. Verify exactly one match exists
4. Read the first 10 lines to confirm the story status is `ready-for-dev`

**Store resolved paths** — for each story, record:
- `story_number`: dotted form (e.g., `9.1`)
- `story_slug`: dashed form (e.g., `9-1`)
- `story_file_path`: absolute path to the story file in the main repo
- `story_file_name`: filename only (e.g., `9-1-package-metadata-and-readme-rename.md`)
- `story_name`: extracted from filename (e.g., `package-metadata-and-readme-rename`)
- `worktree_branch`: `worktree-story-{slug}-{story_name}`
- `worktree_path`: `../sparecrow-story-{slug}` (absolute)
- `worktree_story_file`: `{worktree_path}/_bmad-output/implementation-artifacts/{story_file_name}`
- `project_root`: absolute path from `pwd`

### Step 3: Environment checks

- Base branch exists: `git log --oneline {base_branch} -1`
- No conflicting worktrees: `git worktree list`
- GitHub CLI authenticated: `gh auth status`

### Step 4: Record pre-epic SHA

```bash
git rev-parse {base_branch}
```

Store as `pre_epic_sha` — this is the baseline for Phase 2's epic-wide diff.

### Step 5: Create epic branch

Create an isolated branch for all epic work — `main` stays clean until QA passes:

```bash
cd {project_root}
git checkout {base_branch}
git checkout -b epic-{N}
git push -u origin epic-{N}
```

Store as `epic_branch` (value: `epic-{N}`). All story worktrees will branch from this, all story PRs will target this. Only the final post-QA PR will merge `epic_branch` → `{base_branch}`.

### Step 6: Report and confirm

```
## Pre-Flight Validation — Epic {N}

| # | Story | File | Status | Ready |
|---|-------|------|--------|-------|
| 1 | 9.1   | 9-1-package-metadata-and-readme-rename.md | ready-for-dev | YES |
| 2 | 9.2   | 9-2-platform-paths-rename.md | ready-for-dev | YES |
...

Pre-epic SHA: {pre_epic_sha}
```

**Abort conditions:**
- Base branch missing → abort entire batch
- gh not authenticated → abort entire batch
- ANY story file not found → abort entire batch (user should fix story files first)
- Story not `ready-for-dev` → remove from the batch and warn the user, then proceed with remaining stories

After validation, confirm with the user:
```
Ready to run Epic {N}: {story_count} stories sequentially
Stories: {story_list}
Epic branch: {epic_branch} (created from {base_branch})
Phase 1: Implement + merge each to {epic_branch} (no quality gates)
Phase 2: Epic-wide QA pass, then merge {epic_branch} → {base_branch}
Failure mode: {stop|skip}

Proceed? (y/n)
```

---

## Phase 1: Sequential Implementation

Stories are executed **sequentially and cumulatively** — each story builds on top of the merged result of the previous one.

For each story in the validated list, in order:

### Announce Current Story

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Phase 1 — Story {current}/{total}: {story_number} — {story_name}
Epic branch: {epic_branch} (at {short_sha})
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

### Step 1: Implementation (Opus)

Launch via `Task` tool: `model: opus`, `subagent_type: general-purpose`

The subagent prompt MUST include all of the following:

1. Create worktree from the epic branch:
   ```bash
   cd {project_root}
   git worktree add {worktree_path} -b {worktree_branch} {epic_branch}
   cd {worktree_path}
   npm install
   ```
2. ALL work (code AND story file edits) must be done inside the worktree path. NEVER edit files in the main repo.
3. Invoke `Skill("bmad-bmm-dev-story")` — the dev-story workflow implements all tasks from the story file. When the skill asks for the story file path, provide: `{worktree_story_file}`.
4. **CRITICAL — YOLO mode**: Always answer `y` to "Continue to next step?" prompts. Run autonomously end-to-end.
5. **CRITICAL — After the skill completes, explicitly update the story file yourself.** Use Edit/Write tools on `{worktree_story_file}`:
   - Mark ALL task and subtask checkboxes as `[x]`
   - Update `## Dev Agent Record > ### File List` with all new/modified/deleted files
   - Add notes to `## Dev Agent Record > ### Completion Notes List`
   - Change `Status:` to `done`
   - Update `{worktree_path}/_bmad-output/implementation-artifacts/sprint-status.yaml`: set `{story_slug_key}` to `done`
6. After skill completes, run: `npm test`, `npm run lint`, `npm run typecheck` in the worktree. **Record results but DO NOT abort on failure** — these are warnings only.
7. Commit ALL changes from the worktree:
   ```bash
   cd {worktree_path}
   git add -A
   git commit -m "feat(story-{slug}): implement {story-name-humanized}"
   ```
8. Output JSON: `{ "step": 1, "test_status": "...", "lint_status": "...", "typecheck_status": "...", "worktree_path": "...", "branch_name": "...", "errors": [] }`

**BMAD Dev Agent Rules (include verbatim):**
- Execute tasks/subtasks IN ORDER — no skipping, no reordering
- Mark checkbox `[x]` ONLY when implementation is complete for that task
- Execute continuously without pausing until all tasks complete
- NEVER lie about tests being written or passing

**Autonomy Rules (include verbatim):**
- NEVER use `AskUserQuestion` — all parameters pre-provided
- When Skill asks for story file path, provide: `{worktree_story_file}`
- When asked for confirmation, always answer `y`
- Do NOT display BMAD agent menus

#### Step 1 Gate Check (RELAXED — warnings only)

Parse the JSON response and verify:
- `errors` array is empty (or only contains expected test/lint/typecheck failures)
- `test_status`, `lint_status`, `typecheck_status` — **LOG as warnings, do NOT abort**. Record them in the story result.

**Story File Verification (orchestrator reads directly — do NOT trust subagent claims):**
Read `{worktree_story_file}` and verify:
1. `Status:` is `done`
2. ALL checkboxes `[x]` (no remaining `- [ ]`)
3. `### File List` is non-empty
4. `### Completion Notes List` is non-empty

If verification fails: **fix the story file directly** using Edit tool and commit. Then proceed to Step 2.

---

### Step 2: Finalize Story Artifacts (Orchestrator Direct)

**The orchestrator performs this step directly — no subagent.** Use Read and Edit tools on the worktree files.

Read `{worktree_story_file}` in full and verify/fix ALL of the following:

**2a. Task checkboxes** — ALL `- [ ]` under `## Tasks / Subtasks` must be `- [x]`. Use `replace_all` Edit to bulk-fix.

**2b. Status line** — must be `done`. Change if not.

**2c. Story Completion Status** — update `### Story Completion Status` section: story status `done`, PR number, date. Skip test count (tests may be broken mid-epic).

**2d. Change Log** — add entry: `- **{date}** — Implementation: {summary}. PR #{pr_number}. (QA deferred to epic-level Phase 2)`

**2e. Dev Agent Record** — verify:
- `### Agent Model Used` — `Claude Opus (implementation)`
- `### Completion Notes List` — must have implementation entries
- `### File List` — get from `git diff --name-only {epic_branch}...HEAD` in worktree, filtering `_bmad-output/` and `.claude/`

**2f. Sprint status** — read `{worktree_path}/_bmad-output/implementation-artifacts/sprint-status.yaml`, set story key to `done`.

**2g. Commit** (if any edits made):
```bash
cd {worktree_path}
git add _bmad-output/implementation-artifacts/
git commit -m "chore(story-{slug}): finalize story artifacts"
```

**2h. Push and create PR** — this is the ONLY push per story. All prior steps committed locally.
```bash
cd {worktree_path}
git push origin {worktree_branch}
gh pr create --base {epic_branch} --title "feat(story-{slug}): {story-name-humanized}" --body "Epic {N} — Story {story_number} — {story_name}"
```
Record `pr_url` and `pr_number` from the output for the merge step.

---

### Merge PR and Update Epic Branch

**CRITICAL — Skip CI checks. Cross-cutting epic changes will likely fail CI until all stories land.**

1. **Merge the PR immediately** (skip `gh pr checks --watch`):
   ```bash
   gh pr merge {pr_number} --squash --delete-branch
   ```

2. **Update local epic branch**:
   ```bash
   cd {project_root}
   git checkout {epic_branch}
   git pull origin {epic_branch}
   ```
   If pull fails due to unstaged changes, stash first: `git stash && git pull --rebase origin {epic_branch} && git stash pop`

3. **Clean up worktree**:
   ```bash
   git worktree remove {worktree_path}
   ```

4. **Verify merge landed**:
   ```bash
   git log --oneline {epic_branch} -3
   ```

5. **Verify story artifacts on epic branch** — read `{story_file_path}` and `sprint-status.yaml` on `{epic_branch}` to confirm `Status: done`. If not, fix directly on `{epic_branch}`, commit and push.

Record `merge_status: MERGED`.

**If merge fails:** check `gh pr view {pr_number} --json mergeable`, record failure, apply `on_failure` policy.

### Record Phase 1 Result

After each story completes (or fails), record:
- `story_number`, `story_name`
- `status`: `SUCCESS` | `FAILED` | `SKIPPED`
- `pr_url`, `pr_number`
- `test_status`, `lint_status`, `typecheck_status` (warnings only)
- `failure_reason`, `failure_step` (if failed)
- `merge_status`: `MERGED` | `FAILED` | `PENDING`

### Handle Failure

- **`on_failure = stop`**: Stop Phase 1, proceed to Phase 2 QA for whatever stories have already merged.
- **`on_failure = skip`**: Log failure, mark `FAILED`, continue to next story from last merged state.

---

## Phase 2: Epic QA Pass

**This phase runs ONCE after all Phase 1 stories are merged (or as many as succeeded).** It brings the codebase back to a green state.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Phase 2: Epic QA Pass
Epic diff: {pre_epic_sha}...{epic_branch}
Stories merged: {merged_count}/{total_count}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Step A: Build & Test Fix (Opus)

Launch via `Task` tool: `model: opus`, `subagent_type: general-purpose`

The subagent prompt MUST include:

1. Create worktree from epic branch (all Phase 1 stories now merged into it):
   ```bash
   cd {project_root}
   git worktree add ../sparecrow-epic-{N}-qa -b worktree-epic-{N}-qa {epic_branch}
   cd ../sparecrow-epic-{N}-qa
   npm install
   ```
2. Run baseline diagnostics and record results:
   ```bash
   npm test 2>&1 || true
   npm run lint 2>&1 || true
   npm run typecheck 2>&1 || true
   ```
3. **Fix ALL build/test/lint/typecheck failures.** This is the primary job — make the codebase green.
   - Read error output carefully, fix each issue
   - Re-run after each batch of fixes to confirm progress
   - Iterate until all three pass: `npm test`, `npm run lint`, `npm run typecheck`
4. Commit all fixes:
   ```bash
   git add -A
   git commit -m "fix(epic-{N}): resolve build/test/lint failures after epic implementation"
   ```
5. Push and create PR:
   ```bash
   git push -u origin worktree-epic-{N}-qa
   gh pr create --base {epic_branch} --title "fix(epic-{N}): QA pass — build and test fixes" --body "Fixes all test/lint/typecheck failures introduced during Epic {N} implementation."
   ```
6. Output JSON: `{ "step": "A", "test_status": "...", "lint_status": "...", "typecheck_status": "...", "pr_url": "...", "pr_number": 0, "fixes_applied": 0, "errors": [] }`

**Autonomy Rules (include verbatim):**
- NEVER use `AskUserQuestion` — work autonomously
- Fix all failures — do not stop at the first fix
- If a test is genuinely wrong (testing old behavior that was intentionally changed), update the test

#### Step A Gate Check

Parse JSON and verify:
- `test_status`, `lint_status`, `typecheck_status` should ideally all be `"PASS"`
- If not all passing, **warn but proceed** — Step C will have another chance to fix

Store `qa_worktree_path`, `qa_branch`, `qa_pr_number`, `qa_pr_url` for subsequent steps.

---

### Step B: Adversarial Code Review (Sonnet)

Launch via `Task` tool: `model: sonnet`, `subagent_type: general-purpose`

The subagent prompt MUST include:

1. Navigate to the QA worktree: `cd {qa_worktree_path}`, pull latest: `git pull origin {qa_branch}`
2. Generate the full epic diff for review:
   ```bash
   git diff {pre_epic_sha}...HEAD
   ```
3. Invoke `Skill("bmad-bmm-code-review")` — adversarial review of the combined epic changes. When the skill asks for a story file, explain this is an **epic-level QA review** covering all stories in Epic {N}. Provide the list of story files for reference.
4. **CRITICAL — YOLO mode**: Always answer `y` to "Continue?" prompts. Run autonomously.
5. Post the review findings as a comment on the QA PR:
   ```bash
   gh pr comment {qa_pr_number} --body "## Epic {N} Code Review Findings

   {findings_formatted_as_markdown}
   "
   ```
6. Output JSON: `{ "step": "B", "findings_count": 0, "severity_high": 0, "severity_medium": 0, "severity_low": 0, "errors": [] }`

**BMAD Code Review Rules (include verbatim):**
- ADVERSARIAL review: find 3-10 specific problems — NEVER accept "looks good"
- Challenge everything: code quality, test coverage, architecture compliance, security, performance
- Each finding must reference a specific file and line number
- Categorize by severity: High, Medium, Low
- Focus on the FULL epic diff, not just the QA fix PR

**Autonomy Rules (include verbatim):**
- NEVER use `AskUserQuestion`
- When asked for confirmation, always answer `y`

#### Step B Gate Check

Parse JSON and verify:
- `findings_count >= 3` — if fewer, warn (adversarial minimum not met) but proceed
- `errors` array is empty

---

### Step C: Address Review Findings (Sonnet)

Launch via `Task` tool: `model: sonnet`, `subagent_type: general-purpose`

The subagent prompt MUST include:

1. Navigate to QA worktree: `cd {qa_worktree_path}`, pull latest: `git pull origin {qa_branch}`
2. Read the PR comments to get review findings:
   ```bash
   gh pr view {qa_pr_number} --comments
   ```
3. Address each finding:
   - Read the referenced file and line
   - Apply the fix
   - Verify with targeted test runs
4. After all findings addressed, run full verification:
   ```bash
   npm test
   npm run lint
   npm run typecheck
   ```
5. **HARD GATE: All three MUST pass.** If they don't, keep fixing until they do.
6. Commit and push:
   ```bash
   git add -A
   git commit -m "fix(epic-{N}): address QA code review findings"
   git push origin {qa_branch}
   ```
7. Post completion comment on PR:
   ```bash
   gh pr comment {qa_pr_number} --body "All review findings addressed. Tests/lint/typecheck passing."
   ```
8. Output JSON: `{ "step": "C", "findings_addressed": 0, "findings_total": 0, "test_status": "...", "lint_status": "...", "typecheck_status": "...", "errors": [] }`

**Autonomy Rules (include verbatim):**
- NEVER use `AskUserQuestion`
- When asked for confirmation, always answer `y`
- Do NOT stop until all three quality checks pass

#### Step C Gate Check

Parse JSON and verify:
- `test_status`, `lint_status`, `typecheck_status` all `"PASS"` — **HARD GATE, do not proceed if failing**
- `findings_addressed` should match `findings_total` (warn if partial)

If the hard gate fails, **inform the user and stop** — manual intervention needed.

---

### Step D: Finalize & Merge (Orchestrator Direct)

The orchestrator performs this step directly. Two merges happen: QA PR → epic branch, then epic branch → base branch.

1. **Verify quality checks pass** — run in QA worktree:
   ```bash
   cd {qa_worktree_path}
   npm test && npm run lint && npm run typecheck
   ```
   If any fail, stop and inform the user.

2. **Update epic status** — read `{qa_worktree_path}/_bmad-output/implementation-artifacts/sprint-status.yaml`:
   - If all stories in the epic are `done`, set `epic-{N}` to `done`
   - Commit and push if changed:
     ```bash
     cd {qa_worktree_path}
     git add _bmad-output/implementation-artifacts/sprint-status.yaml
     git commit -m "chore(epic-{N}): mark epic as done"
     git push origin {qa_branch}
     ```

3. **Merge QA PR into epic branch**:
   ```bash
   gh pr checks {qa_pr_number} --watch --fail-fast
   gh pr merge {qa_pr_number} --squash --delete-branch
   ```
   If no checks are configured (exit code 1 with "no checks reported"), proceed to merge.

4. **Create epic PR** — merge the complete epic into the base branch:
   ```bash
   cd {project_root}
   git checkout {epic_branch}
   git pull origin {epic_branch}
   gh pr create --base {base_branch} --head {epic_branch} --title "feat(epic-{N}): {epic_name}" --body "Merges all Epic {N} stories and QA fixes into {base_branch}."
   ```
   Store the PR number as `epic_pr_number` and URL as `epic_pr_url`.

5. **Wait for CI and merge epic PR**:
   ```bash
   gh pr checks {epic_pr_number} --watch --fail-fast
   gh pr merge {epic_pr_number} --squash --delete-branch
   ```
   If no checks are configured (exit code 1 with "no checks reported"), proceed to merge.

6. **Update local base branch**:
   ```bash
   cd {project_root}
   git checkout {base_branch}
   git pull origin {base_branch}
   ```

7. **Clean up QA worktree**:
   ```bash
   git worktree remove {qa_worktree_path}
   ```

8. **Final verification**:
   ```bash
   git log --oneline {base_branch} -5
   ```

---

## Completion Report

```
## Epic {N} Pipeline Complete

### Summary
- **Epic**: {N} — {epic_name}
- **Phase 1 stories processed**: {processed}/{total}
- **Succeeded & merged**: {success_count}
- **Failed**: {failed_count}
- **Skipped**: {skipped_count}
- **Pre-epic SHA**: {pre_epic_sha}
- **Post-epic SHA**: {final_sha}
- **Epic branch**: {epic_branch}
- **Base branch**: {base_branch}
- **Epic PR**: #{epic_pr_number} ({epic_pr_url})

### Phase 1: Story Implementation Results

| # | Story | Implementation | Test | Lint | Types | Merge | PR |
|---|-------|---------------|------|------|-------|-------|----|
| 1 | 9.1 — package metadata rename | SUCCESS | WARN:FAIL | WARN:FAIL | WARN:FAIL | MERGED | #101 |
| 2 | 9.2 — platform paths rename | SUCCESS | WARN:FAIL | WARN:PASS | WARN:FAIL | MERGED | #102 |
| 3 | 9.3 — CLI strings rename | SUCCESS | WARN:FAIL | WARN:PASS | WARN:PASS | MERGED | #103 |
| 4 | 9.4 — test suite updates | SUCCESS | WARN:PASS | WARN:PASS | WARN:PASS | MERGED | #104 |
| 5 | 9.5 — planning artifacts update | SUCCESS | PASS | PASS | PASS | MERGED | #105 |

### Phase 2: Epic QA Results

| Step | Description | Status | Details |
|------|-------------|--------|---------|
| A | Build & Test Fix | PASS | {fixes_applied} fixes applied |
| B | Code Review | DONE | {findings_count} findings ({high}H/{medium}M/{low}L) |
| C | Address Findings | PASS | {addressed}/{total} findings fixed |
| D | Finalize & Merge | MERGED | QA PR #{qa_pr_number}, Epic PR #{epic_pr_number} |

### Final Quality Status
- **Tests**: {final_test_status}
- **Lint**: {final_lint_status}
- **Typecheck**: {final_typecheck_status}
- **Epic status**: {epic_status}

### Failed Stories (if any)
- **{story}**: {failure_reason}

### Remaining Worktrees to Clean Up (if any)
git worktree remove {path}
```

---

## Error Handling

| Scenario | Action |
|----------|--------|
| Pre-flight: base branch missing | Abort entire pipeline |
| Pre-flight: gh not authenticated | Abort entire pipeline |
| Pre-flight: story file not found | Abort entire pipeline |
| Pre-flight: story not ready-for-dev | Remove from list, warn user |
| Phase 1 Step 1: implementation fails | Record failure, apply on_failure policy |
| Phase 1 Step 1: tests/lint/typecheck fail | **WARNING only** — record and proceed |
| Phase 1 Step 2: push or PR creation fails | Record failure, apply on_failure policy |
| Phase 1 merge fails | Record failure, apply on_failure policy |
| Phase 2 Step A: can't fix all failures | Warn, proceed to Step B |
| Phase 2 Step B: fewer than 3 findings | Warn, proceed to Step C |
| Phase 2 Step C: quality checks fail | **HARD GATE** — stop and inform user |
| Phase 2 Step D: QA PR CI fails | Report to user — may need manual fix |
| Phase 2 Step D: QA PR merge fails | Report to user — may need manual merge |
| Phase 2 Step D: Epic PR CI fails | Report to user — may need manual fix |
| Phase 2 Step D: Epic PR merge fails | Report to user — may need manual merge |
| `git pull` after merge fails | Abort — local state inconsistent |
