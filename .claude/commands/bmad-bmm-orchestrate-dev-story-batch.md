---
name: 'orchestrate-dev-story-batch'
description: 'Batch pipeline: takes a list of story numbers (e.g. 4.1, 4.2, 4.3) and runs the 3-step pipeline (implement → review → fix) for each sequentially. Reports cumulative results at the end.'
disable-model-invocation: true
---

# Batch Orchestrated Dev Story Pipeline

You are a batch orchestrator that runs the full implement → review → fix pipeline for multiple stories in sequence. Each story goes through 3 subagent steps plus a direct finalization step before being merged and moving to the next story.

## CRITICAL EXECUTION RULES

**You are a COORDINATOR.** Your job is to:
1. Validate all stories upfront (pre-flight checks)
2. For each story, launch THREE sequential `Task` tool calls (implement, review, fix) with gate checks between them
3. After Step 3, finalize story artifacts directly (Step 4 — no subagent)
4. Merge the PR and update the base branch
5. Report cumulative results

**NEVER do any of the following yourself:**
- Write or edit source code files (except `_bmad-output/` artifacts in Step 4)
- Run dev-story or code-review workflows inline
- Invoke `Skill("bmad-bmm-dev-story")`, `Skill("bmad-bmm-code-review")`, or `Skill("bmad-bmm-orchestrate-dev-story")` directly — these expand inline and lose subagent isolation
- Create worktrees, run tests, or make commits (except Step 4 artifact commits)

**WHY 3 direct Task calls instead of 1 delegated orchestrator:** A previous design launched a single subagent that was supposed to invoke the single-story orchestrator skill and run 3 sub-subagents internally. This 3-level delegation chain (batch → orchestrator → step) reliably failed — the middle layer ran out of context/turns after Step 1 and skipped Steps 2 and 3 entirely, fabricating 0-findings results. By launching the 3 steps directly, the batch orchestrator keeps delegation at 2 levels (batch → step subagent), which is reliable.

## Input Parameters

Ask the user (via AskUserQuestion) for:
1. **Story numbers** (REQUIRED) — comma-separated list, e.g., `4.1, 4.2, 4.3`
2. **Base branch** (OPTIONAL, default: `main`) — the branch to merge the batch branch into at the end
3. **Batch branch name** (OPTIONAL) — the shared branch all story PRs target; auto-derived as `batch-stories-{slug_list}` if not provided (e.g., `batch-stories-4-1-4-2-4-3`)
4. **On failure** (OPTIONAL, default: `stop`) — what to do when a story pipeline fails:
   - `stop` — abort the batch, report progress so far
   - `skip` — skip the failed story, continue to the next one

Parse the story numbers into an ordered list. Validate that each looks like a valid story number (digits separated by a dot, e.g., `3.7`, `4.1`, `4.12`).

**Derive batch branch name** if not provided: join story slugs with `-` and prefix with `batch-stories-` (e.g., stories `4.1, 4.2, 4.3` → `batch-stories-4-1-4-2-4-3`).

## Pre-Flight Validation

Before starting any story pipeline, validate ALL stories upfront:

For each story number in the list:
1. Derive the story slug: replace `.` with `-` (e.g., `4.1` → `4-1`)
2. Glob for the story file: `_bmad-output/implementation-artifacts/{slug}-*.md`
3. Verify exactly one match exists
4. Read the first 10 lines to check the story status is `ready-for-dev`

**Store resolved paths** — for each story, record:
- `story_file_path`: absolute path to the story file in the main repo
- `story_file_name`: filename only (e.g., `4-1-daemon-lifecycle-management-command.md`)
- `story_name`: extracted from filename (e.g., `daemon-lifecycle-management-command`)
- `worktree_branch`: `worktree-story-{slug}-{story_name}`
- `worktree_path`: `../sparecrow-story-{slug}` (absolute)
- `worktree_story_file`: `{worktree_path}/_bmad-output/implementation-artifacts/{story_file_name}`
- `project_root`: absolute path from `pwd`

Also check:
- Base branch exists: `git log --oneline {base_branch} -1`
- Batch branch does NOT already exist (local or remote): `git branch --list {batch_branch}` and `git ls-remote --heads origin {batch_branch}`
- No conflicting worktrees: `git worktree list`
- GitHub CLI authenticated: `gh auth status`

**Create the batch branch** from the base branch:
```bash
cd {project_root}
git checkout {base_branch}
git pull origin {base_branch}
git checkout -b {batch_branch}
git push origin {batch_branch}
git checkout {base_branch}
```

**Report validation results** as a summary table before proceeding:

```
## Pre-Flight Validation

| # | Story | File | Status | Ready |
|---|-------|------|--------|-------|
| 1 | 4.1   | 4-1-daemon-lifecycle.md | ready-for-dev | YES |
| 2 | 4.2   | 4-2-polling-engine.md | ready-for-dev | YES |
| 3 | 4.3   | 4-3-usage-provider.md | draft | NO — not ready-for-dev |

Batch branch: {batch_branch} (created from {base_branch} at {short_sha})
```

**Abort conditions:**
- Base branch missing → abort entire batch
- Batch branch already exists → abort (risk of merging into stale state; user should delete it or choose a different name)
- gh not authenticated → abort entire batch
- ANY story file not found → abort entire batch (user should fix the list)
- Story not `ready-for-dev` → remove from the batch and warn the user, then proceed with remaining stories

After validation, confirm with the user before starting:
```
Ready to run {N} stories sequentially: {story_list}
Batch branch: {batch_branch} → {base_branch} (final PR at batch end)
Pipeline: 3 subagent steps + finalize + merge per story
Failure mode: {stop|skip}

Proceed? (y/n)
```

---

## Sequential Execution Loop

Stories are executed **sequentially and cumulatively** — each story builds on top of the merged result of the previous one.

For each story number in the validated list, in order:

### Announce Current Story

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Story {current}/{total}: {story_number} — {story_name}
Base branch: {base_branch} (at {short_sha})
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

### Step 1: Implementation (Opus)

Launch via `Task` tool: `model: opus`, `subagent_type: general-purpose`

The subagent prompt MUST include all of the following:

1. Create worktree from the **batch branch** (not base branch), so each story builds on previous merged changes:
   ```bash
   cd {project_root}
   git fetch origin {batch_branch}
   git worktree add {worktree_path} -b {worktree_branch} origin/{batch_branch}
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
   - Change `Status:` to `review`
   - Update `{worktree_path}/_bmad-output/implementation-artifacts/sprint-status.yaml`: set `{story_slug_key}` to `review`
6. After each task, run only the test file(s) for files modified (co-located: `src/foo/bar.ts` → `src/foo/bar.test.ts`):
   ```bash
   npx vitest run src/path/to/changed.test.ts [src/path/to/other.test.ts...]
   ```
   At the very end, before committing, run the full suite once:
   ```bash
   npm test && npm run lint && npm run typecheck
   ```
7. Commit ALL changes from the worktree:
   ```bash
   cd {worktree_path}
   git add -A
   git commit -m "feat(story-{slug}): implement {story-name-humanized}"
   ```
8. Output JSON: `{ "step": 1, "test_status": "...", "lint_status": "...", "typecheck_status": "...", "worktree_path": "...", "branch_name": "...", "errors": [] }`

**BMAD Dev Agent Rules (include verbatim):**
- Execute tasks/subtasks IN ORDER — no skipping, no reordering
- Mark checkbox `[x]` ONLY when BOTH implementation AND tests pass
- Run targeted test files after each task (co-located: `src/foo/bar.ts` → `src/foo/bar.test.ts`); run full suite once before committing — NEVER proceed with failing tests
- Execute continuously without pausing until all tasks complete
- NEVER lie about tests being written or passing

**Autonomy Rules (include verbatim):**
- NEVER use `AskUserQuestion` — all parameters pre-provided
- When Skill asks for story file path, provide: `{worktree_story_file}`
- When asked for confirmation, always answer `y`
- Do NOT display BMAD agent menus

#### Step 1 Gate Check

Parse the JSON response and verify:
- `test_status`, `lint_status`, `typecheck_status` are all `"PASS"` — abort story pipeline if not
- `errors` array is empty

**Story File Verification (orchestrator reads directly — do NOT trust subagent claims):**
Read `{worktree_story_file}` and verify:
1. `Status:` is `review`
2. ALL checkboxes `[x]` (no remaining `- [ ]`)
3. `### File List` is non-empty
4. `### Completion Notes List` is non-empty

If verification fails: **fix the story file directly** using Edit tool and commit. Then proceed to Step 1.5.

---

### Step 1.5: QA Assessment (Orchestrator Direct)

**The orchestrator performs this assessment directly — no subagent.** Using the story file already read during Step 1 verification, decide whether QA automation adds value for this story.

#### Scoring

Award +1 for each true statement:
1. Story title or summary contains feature keywords (`add`, `implement`, `new`, `command`, `endpoint`, `provider`, `integration`, `flow`) without fix/refactor intent
2. `## Acceptance Criteria` has 4 or more items
3. `## Dev Notes` references integration paths, cross-module interactions, or E2E scenarios
4. `git diff --name-only origin/{batch_branch}...HEAD` in the worktree shows at least one **newly created** `src/` file (not just modified)

Deduct 2 if any of these are true (short-circuits to `qa_required: false`):
- Story title contains `fix`, `refactor`, `rename`, `cleanup`, `remove` with no new feature work
- `## Dev Notes` contains `qa: skip`
- All changes are in `_bmad-output/`, config, or documentation files only (no `src/` changes)

**Decision:** score ≥ 2 → `qa_required: true`; score < 2 → `qa_required: false`

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

If `qa_required: false`, skip Step 1.6 and proceed directly to Step 2.

---

### Step 1.6: QA Automation (Sonnet) — Conditional

**Skip this step if `qa_assessment.qa_required` is `false`.**

Launch via `Task` tool: `model: sonnet`, `subagent_type: general-purpose`

**Subagent prompt must include:**
1. Navigate to existing worktree at `{worktree_path}` — do NOT pull or create a new worktree
2. Invoke `Skill("bmad-bmm-qa-automate")` — generates automated API and E2E tests using the project's existing test framework (Vitest). Provide story file path: `{worktree_story_file}`.
3. **CRITICAL — YOLO mode**: Always answer `y` to "Continue to next step?" prompts. Run the skill autonomously end-to-end.
4. After the skill completes, run the full suite to verify generated tests pass:
   ```bash
   cd {worktree_path}
   npm test && npm run lint && npm run typecheck
   ```
5. Commit the generated tests:
   ```bash
   cd {worktree_path}
   git add -A
   git commit -m "test(story-{slug}): add QA automation tests"
   ```
6. Output a structured JSON block at the END of your response:
   ```json
   {
     "step": "1.6",
     "qa_status": "PASS|FAIL",
     "tests_generated": 0,
     "test_files_created": [],
     "errors": []
   }
   ```

**Autonomy Rules (include verbatim):**
- NEVER use `AskUserQuestion` — all required parameters are pre-provided in this prompt
- When the Skill asks for a story file path, provide: `{worktree_story_file}`
- When asked for any confirmation or "Continue? (y/n)", always answer `y` automatically

#### Step 1.6 Gate Check

Parse the JSON block and verify:
- `qa_status` is `"PASS"` — if tests fail, **warn the user but do NOT abort the pipeline** (QA failures are non-blocking; code review may surface the same coverage gaps)
- `errors` array is empty

If QA fails or generates 0 tests, log `qa_status: "FAIL|EMPTY"` in the story record and proceed to Step 2.

---

### Step 2: Adversarial Code Review (Sonnet)

Launch via `Task` tool: `model: sonnet`, `subagent_type: general-purpose`

The subagent prompt MUST include:

1. Navigate to worktree at `{worktree_path}` (all changes are local — no pull needed)
2. Invoke `Skill("bmad-bmm-code-review")` — adversarial review finding 3-10 problems. Provide story file: `{worktree_story_file}`.
3. **CRITICAL — YOLO mode**: Always answer `y` to "Continue?" prompts. Run autonomously.
4. **CRITICAL — After the skill identifies findings, explicitly write them to the story file.** Use Edit/Write on `{worktree_story_file}`:
   - Add `### Review Follow-ups (AI)` subsection inside `## Tasks / Subtasks` with each finding as: `- [ ] [AI-Review][High|Medium|Low] Description [filename.ts:line]`
   - Add `## Senior Developer Review (AI)` section (before `## Dev Notes`) with: review date, outcome (Changes Requested), total findings count, severity breakdown
5. **DO NOT commit or push.** Leave the review artifacts as uncommitted changes in the worktree. Step 3 will include them in its commit when it addresses the findings (via `git add -A`). This avoids triggering a CI run on review-only changes.
6. Output JSON: `{ "step": 2, "findings_count": 0, "severity_high": 0, "severity_medium": 0, "severity_low": 0, "errors": [] }`

**BMAD Code Review Rules (include verbatim):**
- ADVERSARIAL review: find 3-10 specific problems — NEVER accept "looks good"
- Challenge everything: code quality, test coverage, architecture compliance, security, performance
- Each finding must reference a specific file and line number
- Categorize by severity: High, Medium, Low
- Write findings directly to the story file

**Autonomy Rules (include verbatim):**
- NEVER use `AskUserQuestion`
- When Skill asks for story file path, provide: `{worktree_story_file}`
- When asked for confirmation, always answer `y`

#### Step 2 Gate Check

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
- **Do NOT commit or push** — leave as uncommitted worktree changes for Step 3 to pick up

---

### Step 3: Address Review Findings (Sonnet)

Launch via `Task` tool: `model: sonnet`, `subagent_type: general-purpose`

The subagent prompt MUST include:

1. Navigate to worktree at `{worktree_path}` (no pull needed — Step 2's review artifacts are already in the worktree as uncommitted changes)
2. Run `npm test` to confirm baseline passes
3. Invoke `Skill("bmad-bmm-dev-story")` — the skill detects `[AI-Review]` items and enters review continuation mode. Provide story file: `{worktree_story_file}`.
4. **CRITICAL — YOLO mode**: Always answer `y` to "Continue?" prompts.
5. **CRITICAL — After fixing each finding, update the story file.** Use Edit/Write on `{worktree_story_file}`:
   - Mark each addressed `[AI-Review]` checkbox as `[x]`
   - Update `### File List` with new/modified files
   - Add resolution notes to `### Completion Notes List`
6. Run verification: `npm test`, `npm run lint`, `npm run typecheck`
7. Commit from worktree — **do NOT push** (Step 4 will push once after all commits are ready):
   ```bash
   cd {worktree_path}
   git add -A
   git commit -m "fix(story-{slug}): address BMAD code review findings"
   ```
8. Output JSON: `{ "step": 3, "findings_addressed": 0, "findings_total": 0, "test_status": "...", "lint_status": "...", "typecheck_status": "...", "errors": [] }`

**BMAD Dev Agent Rules (include verbatim):**
- Execute review follow-up items IN ORDER
- Mark `[AI-Review]` checkbox `[x]` ONLY when fix implemented AND tests pass
- Run full test suite after each fix — NEVER proceed with failing tests
- NEVER lie about tests being written or passing

**Autonomy Rules (include verbatim):**
- NEVER use `AskUserQuestion`
- When Skill asks for story file path, provide: `{worktree_story_file}`
- When asked for confirmation, always answer `y`

#### Step 3 Gate Check

Parse JSON and verify:
- `test_status`, `lint_status`, `typecheck_status` all `"PASS"`
- `findings_addressed` matches `findings_total` (or report partial)
- `errors` array is empty

---

### Step 4: Finalize Story Artifacts (Orchestrator Direct)

**The orchestrator performs this step directly — no subagent.** Use Read and Edit tools on the worktree files.

Read `{worktree_story_file}` in full and verify/fix ALL of the following:

**4a. Task checkboxes** — ALL `- [ ]` under `## Tasks / Subtasks` must be `- [x]`. Use `replace_all` Edit to bulk-fix.

**4b. Status line** — must be `done`. Change if not.

**4c. Review artifacts** — verify `### Review Follow-ups (AI)` and `## Senior Developer Review (AI)` sections exist with content from Step 2. If missing, create them from Step 2 data.

**4d. Story Completion Status** — update `### Story Completion Status` section: story status `done`, test count, date.

**4e. Change Log** — add entry: `- **{date}** — Implementation: {summary}.`

**4f. Dev Agent Record** — verify implementation-level content:
- `### Agent Model Used` — If QA ran (Step 1.6): `Claude Opus (implementation), Claude Sonnet (QA automation, review)`. If QA was skipped: `Claude Opus (implementation), Claude Sonnet (review)`.
- `### Completion Notes List` — must have implementation entries (not just create-story boilerplate). Add from subagent reports if missing.
- `### File List` — must list all source files. Get from `git diff --name-only origin/{batch_branch}...HEAD` in worktree, filtering `_bmad-output/` and `.claude/`.

**4g. Sprint status** — read `{worktree_path}/_bmad-output/implementation-artifacts/sprint-status.yaml`, set story key to `done`. If all stories in epic are done, set epic to `done`.

**4h. Commit** (if any edits made):
```bash
cd {worktree_path}
git add _bmad-output/implementation-artifacts/
git commit -m "chore(story-{slug}): finalize story artifacts and sprint status"
```

**4i. Push and create PR** — this is the ONLY push in the pipeline. All prior steps committed locally. PRs target the **batch branch**, not `{base_branch}` directly.
```bash
cd {worktree_path}
git push origin {worktree_branch}
gh pr create --base {batch_branch} --title "feat(story-{slug}): {story-name-humanized}" --body "Story {story_number} — {story_name}\n\nPart of batch: {batch_branch}"
```
Record `pr_url` and `pr_number` from the output for the merge step.

---

### Merge Story PR into Batch Branch

**CRITICAL — this step ensures each subsequent story builds on the previous one (all within the batch branch).**

1. **Wait for CI checks** (if configured):
   ```bash
   gh pr checks {pr_number} --watch --fail-fast
   ```
   If no checks are configured (exit code 1 with "no checks reported"), proceed to merge.

2. **Merge the story PR into the batch branch**:
   ```bash
   gh pr merge {pr_number} --squash --delete-branch
   ```

3. **Update local batch branch** (so the next story worktree starts from it):
   ```bash
   cd {project_root}
   git fetch origin {batch_branch}
   git branch -f {batch_branch} origin/{batch_branch}
   ```

4. **Clean up worktree**:
   ```bash
   git worktree remove {worktree_path}
   ```

5. **Verify merge landed**:
   ```bash
   git log --oneline {batch_branch} -3
   ```

6. **Verify story artifacts on batch branch** — read `{story_file_path}` (in main repo checkout — note: main repo is checked out to `{base_branch}`, so check via the batch branch ref or just trust step 5). If artifacts are missing, fix directly, commit, and push to `{batch_branch}`.

**Note:** The next story's worktree MUST be created from `{batch_branch}` (not `{base_branch}`) so it includes the previous story's changes. Update `{base_branch}` variable in the per-story context to use `{batch_branch}` as the worktree source for all subsequent steps.

Record `merge_status: MERGED`.

**If merge fails:** check `gh pr view {pr_number} --json mergeable`, record failure, apply `on_failure` policy.

### Record Result

After each story completes (or fails), record:
- `story_number`, `story_name`
- `status`: `SUCCESS` | `FAILED` | `SKIPPED`
- `pr_url`, `pr_number`
- `findings_count`, `findings_addressed`
- `test_status`, `lint_status`, `typecheck_status`
- `failure_reason`, `failure_step` (1-4)
- `merge_status`: `MERGED` | `FAILED` | `PENDING`

### Handle Failure

- **`on_failure = stop`**: Stop batch, jump to report.
- **`on_failure = skip`**: Log failure, mark `FAILED`, continue to next story from last merged state.

---

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
     --body "Batch pipeline complete. Stories merged: {story_list}\n\nIndividual PRs: {pr_url_list}"
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

## Batch Completion Report

```
## Batch Pipeline Complete

### Summary
- **Stories processed**: {processed}/{total}
- **Succeeded & merged into batch branch**: {success_count}
- **Failed**: {failed_count}
- **Skipped**: {skipped_count}
- **Batch branch**: {batch_branch} → {base_branch} (batch PR: #{batch_pr_number})
- **Base branch**: {base_branch} now at {final_sha}

### Story Results

| # | Story | Pipeline | Story PR | QA | Findings | Tests | Lint | Types |
|---|-------|----------|----------|----|----------|-------|------|-------|
| 1 | 4.1 — daemon lifecycle | SUCCESS | #34 (→ batch) | 8 tests | 5/5 | PASS | PASS | PASS |
| 2 | 4.2 — polling engine | FAILED (Step 1) | — | skipped | — | FAIL | — | — |
| 3 | 4.3 — usage provider | SKIPPED | — | — | — | — | — | — |

### Batch Branch PR
- **{batch_branch} → {base_branch}**: #{batch_pr_number} — {MERGED | FAILED | SKIPPED (no successes)}

### Failed Stories
- **4.2**: Tests failed during implementation — {failure_details}

### Remaining Worktrees to Clean Up
git worktree remove ../sparecrow-story-4-2
```

---

## Error Handling

| Scenario | Action |
|----------|--------|
| Pre-flight: base branch missing | Abort entire batch |
| Pre-flight: gh not authenticated | Abort entire batch |
| Pre-flight: story file not found | Abort entire batch |
| Pre-flight: story not ready-for-dev | Remove from list, warn user |
| Step 1: tests/lint/typecheck fail | Record failure, apply on_failure policy |
| Step 1.5: story file unreadable for assessment | Skip QA, proceed to Step 2 |
| Step 1.6: generated tests fail | Warn user, proceed to Step 2 (non-blocking) |
| Step 1.6: zero tests generated | Warn user, proceed to Step 2 |
| Step 2: fewer than 3 findings | Warn, proceed (orchestrator writes artifacts if missing) |
| Step 3: tests regress | Record failure, apply on_failure policy |
| Step 3: partial findings addressed | Report count, proceed to Step 4 |
| Step 4: story file not updatable | Report to user, proceed to push/PR |
| Step 4: push or PR creation fails | Record failure, apply on_failure policy |
| CI checks fail | Record failure, apply on_failure policy |
| PR merge fails (conflict) | Record failure, apply on_failure policy |
| PR merge fails (branch protection) | Report to user — may need manual merge |
| `git pull` after merge fails | Abort — local state inconsistent |
