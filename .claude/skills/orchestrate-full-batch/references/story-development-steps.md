# Phase B: Story Development (Steps 4-7)

*In sequential mode, these run one story at a time. In parallel mode, Steps 4-6 run concurrently for all stories in a round, then Step 7 + merge run sequentially.*

Before starting Phase B, resolve development-specific context:

### Single-Repo Context
- **Worktree branch**: `worktree-story-{story_slug}-{story_name}` (e.g., `worktree-story-5-3-repository-targeting`)
- **Worktree path**: `../{project_name}-story-{story_slug}` (absolute)
- **Worktree story file**: `{worktree_path}/_bmad-output/implementation-artifacts/{story_file_name}`
- **Worktree source branch**: `{batch_branch}` — worktrees are created from the batch branch (not `{base_branch}`) so each story builds on the previous story's merged changes

### Meta-Repo Context (when `{is_meta_repo}` is `true`)

After Step 3, the story file exists and the orchestrator can determine which subrepos this story targets. Resolve `{affected_subrepos}` by reading the story file's `## Dev Notes` and `## Tasks / Subtasks` for directory paths matching known subrepo names.

- **Story worktree branch**: `worktree-story-{story_slug}-{story_name}` (same naming as single-repo)
- **Meta-repo story branch**: same as worktree branch — but meta-repo uses in-place branch (no worktree) for artifact changes
- **Per-subrepo worktree paths**: for each affected subrepo, create a worktree:
  - Path: `../{project_name}-{subrepo_name}-story-{story_slug}` (e.g., `../my-stack-my-app-story-16-3`)
  - Branch: `worktree-story-{story_slug}-{story_name}` (same branch name in each subrepo)
- **Worktree story file**: `{project_root}/_bmad-output/implementation-artifacts/{story_file_name}` — story file lives in the meta-repo (which is checked out on the batch branch), NOT in any subrepo worktree
- **Per-subrepo CLAUDE.md**: read `{subrepo_path}/CLAUDE.md` and include in subagent prompts alongside the meta-repo CLAUDE.md

**Key principle**: the meta-repo holds planning artifacts; subrepos hold code. Worktrees are only needed in subrepos (for code isolation). The meta-repo stays on the batch branch and receives artifact commits directly.

## Step 4: Implementation (Opus)

Launch via `Task` tool: `model: opus`, `subagent_type: general-purpose`

The subagent prompt MUST include all of the following:

1. **Create worktree(s)** from the **batch branch** (not base branch):

   **Single-repo:**
   ```bash
   cd {project_root}
   git fetch origin {batch_branch}
   git worktree add {worktree_path} -b {worktree_branch} origin/{batch_branch}
   cd {worktree_path}
   {install_command}
   ```

   **Meta-repo** — create worktrees in each affected subrepo. The meta-repo stays on the batch branch (no worktree needed for artifacts):
   ```bash
   # Ensure meta-repo is on the batch branch
   cd {project_root}
   git checkout {batch_branch}
   git pull origin {batch_branch}

   # Create worktree in each affected subrepo
   for subrepo in {affected_subrepos}; do
     cd {project_root}/$subrepo
     git fetch origin {batch_branch}
     git worktree add ../../{project_name}-${subrepo}-story-{story_slug} -b {worktree_branch} origin/{batch_branch}
     cd ../../{project_name}-${subrepo}-story-{story_slug}
     {subrepos[$subrepo].install_command}
   done
   ```

   If `{has_playwright}` is true (check per-subrepo in meta-repo mode), also install browsers:
   ```bash
   cd {worktree_path}  # or each subrepo worktree path
   {e2e_install_command}
   ```
   **In parallel mode**, worktrees may already exist (created by the orchestrator in Phase B setup). In that case, skip worktree creation and just navigate to them:
   ```bash
   cd {worktree_path}  # or each subrepo worktree path
   {install_command}
   ```

2. **Work location rules:**
   - **Single-repo**: ALL work (code AND story file edits) must be done inside the worktree path. NEVER edit files in the main repo.
   - **Meta-repo**: The subagent's **primary working directory must be the meta-repo** (either `{project_root}` in sequential mode, or the meta-repo worktree in parallel mode). This is critical because:
     - BMAD commands/skills (`Skill("bmad-bmm-dev-story")` etc.) are project-level commands in `.claude/commands/` that reference `_bmad/` — this directory only exists in the meta-repo, NOT in child subrepo worktrees
     - The story file lives in the meta-repo at `_bmad-output/implementation-artifacts/{story_file_name}`
     - The subagent navigates to child subrepo worktrees ONLY for source code changes (reading/writing code, running tests)
   - Pass these paths to the subagent:
     - `{meta_repo_path}` — primary working directory (meta-repo root or meta-repo worktree)
     - `{subrepo_worktree_paths}` — dict of `{ subrepo_name: worktree_path }` for code changes
     - Tell the subagent: "Your primary working directory is `{meta_repo_path}`. Invoke all BMAD skills from here. Story file is at `{meta_repo_path}/_bmad-output/implementation-artifacts/{story_file_name}`. For source code changes, navigate to the child subrepo worktree(s): `{subrepo_worktree_paths}`. Always return to `{meta_repo_path}` before invoking BMAD skills."

3. **Project conventions** (from CLAUDE.md — include full contents if found):
   ```
   {claude_md_contents_or_"No CLAUDE.md found — follow standard conventions for this project type"}
   ```
   **Meta-repo**: include BOTH the meta-repo CLAUDE.md and the subrepo-specific CLAUDE.md:
   ```
   ## Meta-repo conventions ({project_name}/CLAUDE.md):
   {meta_claude_md_contents}

   ## Subrepo conventions ({subrepo_name}/CLAUDE.md):
   {subrepo_claude_md_contents}
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
8. **Commit** ALL changes — **do NOT push** (Step 7 will push once after all commits are ready):

   **Single-repo:**
   ```bash
   cd {worktree_path}
   git add -A
   git commit -m "feat(story-{story_slug}): implement {story-name-humanized}"
   ```

   **Meta-repo** — commit separately in each repo:
   ```bash
   # Commit code changes in each affected subrepo worktree
   for subrepo in {affected_subrepos}; do
     cd {subrepo_worktree_paths[$subrepo]}
     git add -A
     git commit -m "feat(story-{story_slug}): implement {story-name-humanized}"
   done

   # Commit artifact/story file changes in the meta-repo
   cd {project_root}
   git add _bmad-output/implementation-artifacts/
   git commit -m "feat(story-{story_slug}): update story artifacts for {story-name-humanized}"
   ```

9. Output JSON:
   - **Single-repo**: `{ "step": 4, "test_status": "...", "lint_status": "...", "typecheck_status": "...", "e2e_status": "PASS|FAIL|SKIPPED", "worktree_path": "...", "branch_name": "...", "errors": [] }`
   - **Meta-repo**: `{ "step": 4, "test_status": {"subrepo_name": "PASS", ...}, "lint_status": {"subrepo_name": "PASS", ...}, "typecheck_status": {"subrepo_name": "PASS", ...}, "e2e_status": {"subrepo_name": "PASS|FAIL|SKIPPED", ...}, "subrepo_worktree_paths": {"subrepo_name": "...", ...}, "meta_repo_root": "...", "branch_name": "...", "errors": [] }`

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

### Step 4 Gate Check

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

## Step 4.5: QA Assessment (Orchestrator Direct)

**The orchestrator performs this assessment directly — no subagent.** Using the story file already read during Step 4 verification, decide whether QA automation adds value for this story.

**Before scoring:** Run this Bash command directly in the orchestrator to get the actual changed-file list (the worktree still exists at this point):
```bash
git -C {worktree_path} diff --name-only origin/{batch_branch}...HEAD
```
Use this output for criterion #4 — do not rely on the subagent's self-reported file list.

### Scoring

Award +1 for each true statement:
1. Story title or summary contains feature keywords (`add`, `implement`, `new`, `command`, `endpoint`, `provider`, `integration`, `flow`) without fix/refactor intent
2. `## Acceptance Criteria` has 4 or more items
3. `## Dev Notes` references integration paths, cross-module interactions, or E2E scenarios
4. The `git diff` output above shows at least one **newly created** `src/` file (not just modified)

Deduct 2 if any of these are true (short-circuits to `qa_required: false`):
- Story title contains `fix`, `refactor`, `rename`, `cleanup`, `remove` with no new feature work
- `## Dev Notes` contains `qa: skip`
- All changes are in `_bmad-output/`, config, or documentation files only (no `src/` changes)

**Decision:** score >= 2 -> `qa_required: true`; score < 2 -> `qa_required: false`

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

## Step 4.6: QA Automation (Sonnet) — Conditional

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

### Step 4.6 Gate Check

Parse the JSON block and verify:
- `qa_status` is `"PASS"` — if tests fail, **warn the user but do NOT abort the pipeline** (QA failures are non-blocking; code review may surface the same coverage gaps)
- `errors` array is empty

If QA fails or generates 0 tests, log `qa_status: "FAIL|EMPTY"` in the story record and proceed to Step 5.

---

## Step 5: Adversarial Code Review (Sonnet)

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

### Step 5 Gate Check

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

## Step 6: Address Review Findings (Sonnet)

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

### Step 6 Gate Check

Parse JSON and verify:
- `test_status`, `lint_status`, `typecheck_status` all `"PASS"`
- `e2e_status` is `"PASS"` or `"SKIPPED"` — if `"FAIL"`, warn but proceed to Step 7 (report in final)
- `findings_addressed` matches `findings_total` (or report partial)
- `errors` array is empty

---

## Step 7: Finalize Story Artifacts (Orchestrator Direct)

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

**7i. Push and create PR(s)** — this is the ONLY push in the pipeline. All prior steps committed locally. PRs target the **batch branch**, not `{base_branch}` directly.

**Single-repo:**
```bash
cd {worktree_path}
git push origin {worktree_branch}
gh pr create --base {batch_branch} --title "feat(story-{story_slug}): {story-name-humanized}" --body "Automated pipeline: story {story_key} — {story_name}\n\nPart of batch: {batch_branch}"
```
Record `pr_url` and `pr_number` from the output for the merge step.

**Meta-repo** — push and create PRs in each affected subrepo AND the meta-repo:
```bash
# Push and create PR in each affected subrepo
for subrepo in {affected_subrepos}; do
  cd {subrepo_worktree_paths[$subrepo]}
  git push origin {worktree_branch}
  gh pr create --repo {subrepos[$subrepo].remote_url} --base {batch_branch} \
    --title "feat(story-{story_slug}): {story-name-humanized}" \
    --body "Automated pipeline: story {story_key} — {story_name}\n\nSubrepo: $subrepo\nPart of batch: {batch_branch}\nMeta-repo: {meta_repo_remote_url}"
done

# Push and create PR in the meta-repo (artifact changes)
cd {project_root}
git push origin {batch_branch}
# Meta-repo artifact changes are pushed directly to the batch branch (no separate PR needed —
# artifacts are committed directly to the batch branch since the meta-repo stays checked out on it).
# Alternatively, if you want a PR for traceability:
# git checkout -b artifact-story-{story_slug}
# git push origin artifact-story-{story_slug}
# gh pr create --base {batch_branch} --title "chore(story-{story_slug}): story artifacts" --body "..."
```

Record per-subrepo: `{subrepo_prs}` — dict of `{ subrepo_name: { pr_url, pr_number } }`.
For the meta-repo, artifact changes are committed directly to the batch branch (no PR needed since artifacts don't need CI review).

**Meta-repo PR tracking**: store all PR references so the merge step knows what to merge:
```json
{
  "story_prs": {
    "my-app": { "pr_url": "...", "pr_number": 42 },
    "shared-lib": { "pr_url": "...", "pr_number": 15 }
  },
  "meta_repo_artifacts": "pushed directly to batch branch"
}
```
