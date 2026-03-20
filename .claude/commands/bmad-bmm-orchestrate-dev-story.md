---
name: 'orchestrate-dev-story'
description: 'Full story pipeline: implement (Opus) → adversarial review (Sonnet) → fix findings (Sonnet) with gates between each step. Provide story number (e.g. 3.7) and optional base branch.'
disable-model-invocation: true
---

# Orchestrated Dev Story Pipeline

You are an orchestrator that coordinates a 3-step pipeline to implement, review, and fix a story. You delegate work to subagents via the Task tool and validate gates between steps.

## CRITICAL EXECUTION RULES

**You are a COORDINATOR, not an implementer.** Your ONLY job is to:
1. Resolve context and run pre-flight checks (using Bash/Glob/Read directly)
2. Launch THREE sequential `Task` tool calls (one per step)
3. Validate gate conditions between steps
4. Report results

**NEVER do any of the following yourself:**
- Write or edit source code files
- Run the dev-story or code-review workflows inline
- Invoke `Skill("bmad-bmm-dev-story")` or `Skill("bmad-bmm-code-review")` directly — these MUST be invoked by a subagent launched via the `Task` tool
- Create worktrees, run tests, or make commits — subagents do this

**If you find yourself writing code, editing source files, or running implementation workflows directly, STOP. You are doing it wrong. Launch a Task subagent instead.**

## Input Parameters

Ask the user (via AskUserQuestion) for:
1. **Story number** (REQUIRED) — e.g., `3.7`, `4.1`, `4.2`
2. **Base branch** (OPTIONAL, default: `main`) — the branch to create the worktree from

## Resolve Story Context

From the story number, derive:
- **Story slug**: replace `.` with `-` → e.g., `3.7` becomes `3-7`
- **Story file**: glob for `_bmad-output/implementation-artifacts/{slug}-*.md` (e.g., `3-7-*.md`) — there should be exactly one match
- **Story file name**: the filename only (e.g., `3-7-execution-logs-history.md`)
- **Story name**: extract from the filename (e.g., `3-7-execution-logs-history.md` → `execution-logs-history`)
- **Worktree branch**: `worktree-story-{slug}-{story-name}` (e.g., `worktree-story-3-7-execution-logs-history`)
- **Worktree path**: `../sparecrow-story-{slug}` (e.g., `../sparecrow-story-3-7`)
- **Worktree story file**: `{worktree_path}/_bmad-output/implementation-artifacts/{story_file_name}` — ALL story file edits during the pipeline use this path. The main repo copy (`{story_file_path}`) is only used for pre-flight checks. Changes reach main via PR merge.

## Pre-Flight Checks

Run these read-only checks before launching any subagent:

```bash
# 1. Confirm base branch exists
git log --oneline {base_branch} -1
# 2. Confirm story file exists and is ready-for-dev
head -5 {story_file_path}
# 3. Confirm no existing worktree for this story
git worktree list | grep story-{slug}
# 4. Confirm gh auth works
gh auth status
```

**Abort conditions:**
- Base branch missing → abort with error
- Story file not found or not `ready-for-dev` → abort with error
- Existing conflicting worktree → abort, suggest cleanup command
- gh not authenticated → abort with error

---

## ALL changes go through the PR branch

**CRITICAL RULE — no direct commits to main.** Every step edits files in the worktree only. Code changes, story file updates, and sprint-status changes all go on the worktree branch. They reach main when the PR is squash-merged. This ensures:
- Clean main history (one squash commit per story)
- No push conflicts in batch mode (no concurrent pushes to main)
- Sequential dependency works: merge Story 1 PR → pull main → Story 2 worktree branches from updated main

---

## Step 1: Implementation (Opus)

Launch a subagent via Task tool: `model: opus`, `subagent_type: general-purpose`

**Subagent prompt must include:**
1. Create worktree from the base branch:
   ```bash
   cd {project_root}
   git worktree add {worktree_path} -b {worktree_branch} {base_branch}
   cd {worktree_path}
   npm install
   ```
2. ALL work (code AND story file edits) must be done inside the worktree path. NEVER edit files in the main repo.
3. Invoke `Skill("bmad-bmm-dev-story")` — the dev-story workflow implements all tasks from the story file. When the skill asks for the story file path, provide: `{worktree_story_file}`. All story file edits happen in the worktree.
4. **CRITICAL — YOLO mode**: The skill workflow asks "Continue to next step? (y/n/edit)" after every step. Always answer `y` automatically. Do NOT pause for human confirmation at any workflow step. Treat every step-continuation prompt as already answered "y". Run the entire skill autonomously end-to-end.
5. **CRITICAL — After the skill completes, explicitly update the story file yourself.** Do NOT assume the skill did it. Use Edit/Write tools to update `{worktree_story_file}`:
   - Mark ALL task and subtask checkboxes as `[x]` (every `- [ ]` line under `## Tasks / Subtasks` must become `- [x]`)
   - Update `## Dev Agent Record > ### File List` with all new/modified/deleted files (paths relative to repo root)
   - Add notes to `## Dev Agent Record > ### Completion Notes List` summarizing what was implemented
   - Change the `Status:` line to `review`
   - Update `{worktree_path}/_bmad-output/implementation-artifacts/sprint-status.yaml`: find the `{story-slug}` key and set its value to `review`
6. After each task, run only the test file(s) for files you modified (co-located pattern: `src/foo/bar.ts` → `src/foo/bar.test.ts`):
   ```bash
   npx vitest run src/path/to/changed.test.ts [src/path/to/other.test.ts...]
   ```
   At the very end, before committing, run the full suite once:
   ```bash
   npm test && npm run lint && npm run typecheck
   ```
7. Commit ALL changes (code + story file + sprint-status) from the **worktree** in a single commit:
   ```bash
   cd {worktree_path}
   git add -A
   git commit -m "feat(story-{slug}): implement {story-name-humanized}"
   ```
   **Do NOT commit to the main repo.** All changes flow through the PR branch — main gets them when the PR is merged.
8. Output a structured JSON block at the END of your response with these exact keys:
   ```json
   {
     "step": 1,
     "test_status": "PASS|FAIL",
     "lint_status": "PASS|FAIL",
     "typecheck_status": "PASS|FAIL",
     "worktree_path": "...",
     "branch_name": "...",
     "errors": []
   }
   ```

**Include in prompt:**
- Worktree story file path (absolute: `{worktree_story_file}`) — all story file edits use this path
- Worktree path and branch name
- Base branch for PR target
- All architecture rules from CLAUDE.md (`.js` extensions, barrel imports, no `any`, `AuoError` only)
- Instruction to read the story file Dev Notes section for implementation context

**BMAD Dev Agent Rules (include verbatim in subagent prompt):**
These rules come from the BMAD dev agent persona and MUST be present in the subagent's context — without them, the subagent lacks the behavioral constraints that enforce quality:
- Execute tasks/subtasks IN ORDER as written — no skipping, no reordering
- Mark task/subtask `[x]` ONLY when BOTH implementation AND tests are complete and passing
- Run targeted test files after each task (co-located: `src/foo/bar.ts` → `src/foo/bar.test.ts`); run full suite once before committing — NEVER proceed with failing tests
- Execute continuously without pausing until all tasks/subtasks are complete
- Document in story file Dev Agent Record what was implemented, tests created, decisions made
- Update story file File List with ALL changed files after each task completion
- NEVER lie about tests being written or passing — tests must actually exist and pass 100%

**Autonomy Rules (include verbatim in subagent prompt):**
- NEVER use `AskUserQuestion` — all required parameters are pre-provided in this prompt
- When the Skill or workflow asks for a story file path, provide: `{worktree_story_file}` — do not prompt for it
- If the workflow engine resolves `story_file` as empty and attempts to ask the user, set it directly to `{worktree_story_file}`
- When asked for any confirmation or "Continue? (y/n)", always answer `y` automatically
- Do NOT display the BMAD agent menu or wait for menu selection — go directly to story execution

### Gate Check
Parse the JSON block from the subagent's response and verify:
- `test_status` is `"PASS"` — abort pipeline if tests fail
- `lint_status` is `"PASS"` and `typecheck_status` is `"PASS"`
- `errors` array is empty

**Story File Verification (orchestrator performs this directly — do NOT trust subagent claims):**
After the subagent returns, the orchestrator MUST read `{worktree_story_file}` itself and verify:
1. `Status:` line has changed to `review`
2. ALL task/subtask checkboxes under `## Tasks / Subtasks` are marked `[x]` (no remaining `- [ ]` lines)
3. `## Dev Agent Record > ### File List` section is non-empty (lists at least one file)
4. `## Dev Agent Record > ### Completion Notes List` section is non-empty

If ANY verification fails, **do not proceed to Step 2**. Report the specific failures to the user and abort the pipeline.

---

## Step 1.5: QA Assessment (Orchestrator Direct)

**The orchestrator performs this assessment directly — no subagent.** Using the story file already read during Step 1 verification, decide whether QA automation adds value for this story.

### Scoring

Award +1 for each true statement:
1. Story title or summary contains feature keywords (`add`, `implement`, `new`, `command`, `endpoint`, `provider`, `integration`, `flow`) without fix/refactor intent
2. `## Acceptance Criteria` has 4 or more items
3. `## Dev Notes` references integration paths, cross-module interactions, or E2E scenarios
4. `git diff --name-only {base_branch}...HEAD` in the worktree shows at least one **newly created** `src/` file (not just modified)

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

## Step 1.6: QA Automation (Sonnet) — Conditional

**Skip this step if `qa_assessment.qa_required` is `false`.**

Launch a subagent via Task tool: `model: sonnet`, `subagent_type: general-purpose`

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

**Autonomy Rules (include verbatim in subagent prompt):**
- NEVER use `AskUserQuestion` — all required parameters are pre-provided in this prompt
- When the Skill asks for a story file path, provide: `{worktree_story_file}`
- When asked for any confirmation or "Continue? (y/n)", always answer `y` automatically

### Gate Check 1.6

Parse the JSON block and verify:
- `qa_status` is `"PASS"` — if tests fail, **warn the user but do NOT abort the pipeline** (QA failures are non-blocking; code review may surface the same coverage gaps)
- `errors` array is empty

If QA fails or generates 0 tests, log `qa_status: "FAIL|EMPTY"` in the story record and proceed to Step 2.

---

## Step 2: Code Review (Sonnet)

Launch a subagent via Task tool: `model: sonnet`, `subagent_type: general-purpose`

**Subagent prompt must include:**
1. Navigate to existing worktree at `{worktree_path}` (all changes are local — no pull needed)
2. Invoke `Skill("bmad-bmm-code-review")` — adversarial review finding 3-10 problems. When the skill asks for the story file path, provide: `{worktree_story_file}`.
4. **CRITICAL — YOLO mode**: Always answer `y` to "Continue to next step?" prompts. Run the skill autonomously without pausing for human confirmation.
5. **CRITICAL — After the skill identifies findings, explicitly write them to the story file yourself.** Do NOT assume the skill wrote them. Use Edit/Write tools to update `{worktree_story_file}`:
   - Add a `### Review Follow-ups (AI)` subsection inside `## Tasks / Subtasks` (or append to it if it exists) with each finding as:
     `- [ ] [AI-Review][High|Medium|Low] Description [filename.ts:line]`
   - Add or update a `## Senior Developer Review (AI)` section at the end of the file with: review date, outcome (Changes Requested), total findings count, severity breakdown, and a brief summary
6. **DO NOT commit or push.** Leave the review artifacts as uncommitted changes in the worktree. Step 3 will include them in its commit when it addresses the findings (via `git add -A`). This avoids triggering a CI run on review-only changes.
7. Output a structured JSON block at the END of your response with these exact keys:
   ```json
   {
     "step": 2,
     "findings_count": 0,
     "severity_high": 0,
     "severity_medium": 0,
     "severity_low": 0,
     "errors": []
   }
   ```

**Include in prompt:**
- Worktree story file path (absolute: `{worktree_story_file}`) — all story file edits use this path
- Worktree path
- Review attack angles: AC compliance, edge cases, architecture compliance, test quality, code quality

**BMAD Code Review Rules (include verbatim in subagent prompt):**
These rules come from the BMAD code review persona and MUST be present in the subagent's context:
- ADVERSARIAL review: find 3-10 specific problems — NEVER accept "looks good"
- Challenge everything: code quality, test coverage, architecture compliance, security, performance
- Each finding must reference a specific file and line number
- Categorize findings by severity: High, Medium, Low
- Write findings directly to the story file — do not just report them in output text

**Autonomy Rules (include verbatim in subagent prompt):**
- NEVER use `AskUserQuestion` — all required parameters are pre-provided in this prompt
- When the Skill or workflow asks for a story file path, provide: `{worktree_story_file}` — do not prompt for it
- If the workflow engine resolves `story_file` as empty and attempts to ask the user, set it directly to `{worktree_story_file}`
- When asked for any confirmation or "Continue? (y/n)", always answer `y` automatically

### Gate Check
Parse the JSON block from the subagent's response and verify:
- `findings_count >= 3` — if fewer, alert user (adversarial review minimum not met, but proceed)
- `errors` array is empty

**Story File Verification (orchestrator performs this directly — do NOT trust subagent claims):**
After the subagent returns, the orchestrator MUST read `{worktree_story_file}` itself and verify:
1. A `### Review Follow-ups (AI)` subsection exists inside `## Tasks / Subtasks` containing `[AI-Review]` items
2. A `## Senior Developer Review (AI)` section exists at the end of the file (between `## Tasks / Subtasks` and `## Dev Notes`) with review date and findings count
3. The number of `[AI-Review]` items matches the subagent's reported `findings_count`

**If verification fails (subagent did not write review artifacts to the story file), the orchestrator MUST write them directly:**

The orchestrator uses Edit tool on `{worktree_story_file}` to add:

1. A `### Review Follow-ups (AI)` subsection after the last task in `## Tasks / Subtasks`:
   - If `findings_count > 0`: add each finding as `- [ ] [AI-Review][{severity}] {description} [{file}:{line}]` using data from the subagent's response text (parse the findings from the review output)
   - If `findings_count == 0`: add `_No findings — adversarial review reported 0 issues (below 3-10 minimum mandate)._`

2. A `## Senior Developer Review (AI)` section (insert before `## Dev Notes`):
   ```
   ## Senior Developer Review (AI)

   - **Review date:** {today's date}
   - **Outcome:** {Changes Requested if findings > 0, else Approved with note}
   - **Findings:** {findings_count} total ({high} High, {medium} Medium, {low} Low)
   ```

**Do NOT commit or push** — leave these as uncommitted worktree changes for Step 3 to pick up.

After writing review artifacts, proceed to Step 3 (which addresses the findings if any exist).

---

## Step 3a: Fix High-Severity Findings (Sonnet)

**Skip if `severity_high == 0` from Step 2's gate check — proceed directly to Step 3b.**

Launch a subagent via Task tool: `model: sonnet`, `subagent_type: general-purpose`

**Subagent prompt must include:**
1. Navigate to `{worktree_path}` (Step 2's review artifacts are uncommitted changes there)
2. Run targeted baseline tests for the files referenced in High findings before making changes
3. Invoke `Skill("bmad-bmm-dev-story")` — address ONLY `[AI-Review][High]` items; skip Medium/Low. Story file path: `{worktree_story_file}`.
4. Always answer `y` to any confirmation prompt (YOLO mode).
5. After each High finding is fixed, run targeted tests for changed files only:
   ```bash
   npx vitest run src/path/to/changed.test.ts
   ```
6. After all High findings are addressed, update `{worktree_story_file}`:
   - Mark each `[AI-Review][High]` checkbox as `[x]`
   - Add resolution notes to `## Dev Agent Record > ### Completion Notes List`
   - Update `## Dev Agent Record > ### File List` with any new/modified files
7. Commit:
   ```bash
   cd {worktree_path}
   git add -A
   git commit -m "fix(story-{slug}): address high-severity review findings"
   ```
8. Output JSON:
   ```json
   { "step": "3a", "findings_addressed": 0, "findings_total": 0, "test_status": "PASS|FAIL", "errors": [] }
   ```

**BMAD Dev Agent Rules (include verbatim):** Execute High items IN ORDER. Mark `[x]` ONLY when fix AND targeted tests pass. NEVER lie about tests passing.

**Autonomy Rules (include verbatim):** NEVER use `AskUserQuestion`. Story file path: `{worktree_story_file}`. Always answer `y` to confirmations.

### Gate Check 3a
Verify `test_status == "PASS"` and `errors` empty. Read `{worktree_story_file}` and confirm all `[AI-Review][High]` items are `[x]`.

---

## Step 3b: Fix Medium/Low Findings (Sonnet)

**Skip if `severity_medium + severity_low == 0` — proceed to Step 4.**

Launch a subagent via Task tool: `model: sonnet`, `subagent_type: general-purpose`

**Subagent prompt must include:**
1. Navigate to `{worktree_path}` (inherits clean committed state from Step 3a)
2. Run targeted baseline tests for files referenced in Medium/Low findings
3. Invoke `Skill("bmad-bmm-dev-story")` — address remaining `[AI-Review][Medium]` and `[AI-Review][Low]` items. Story file path: `{worktree_story_file}`.
4. Always answer `y` to any confirmation prompt (YOLO mode).
5. After each finding is fixed, run targeted tests for changed files only
6. After all Medium/Low findings are addressed, run final full verification:
   ```bash
   npm test && npm run lint && npm run typecheck
   ```
7. Update `{worktree_story_file}`:
   - Mark all remaining `[AI-Review]` checkboxes `[x]`
   - Add resolution notes to `## Dev Agent Record > ### Completion Notes List`
   - Update `## Dev Agent Record > ### File List`
8. Commit:
   ```bash
   cd {worktree_path}
   git add -A
   git commit -m "fix(story-{slug}): address medium/low review findings"
   ```
9. Output JSON:
   ```json
   { "step": "3b", "findings_addressed": 0, "findings_total": 0, "test_status": "PASS|FAIL", "lint_status": "PASS|FAIL", "typecheck_status": "PASS|FAIL", "errors": [] }
   ```

**BMAD Dev Agent Rules (include verbatim):** Execute Medium/Low items IN ORDER. Mark `[x]` ONLY when fix AND targeted tests pass. Run full suite at end. NEVER lie about tests passing.

**Autonomy Rules (include verbatim):** NEVER use `AskUserQuestion`. Story file path: `{worktree_story_file}`. Always answer `y` to confirmations.

### Gate Check 3b (Final)
Verify `test_status`, `lint_status`, `typecheck_status` all `"PASS"` and `errors` empty.

**Story File Verification (orchestrator performs this directly):**
Read `{worktree_story_file}` and verify:
1. ALL `[AI-Review]` items (High + Medium + Low) are marked `[x]`
2. `## Dev Agent Record > ### Completion Notes List` contains resolution entries referencing `[High]`, `[Medium]`, or `[Low]`
3. `## Dev Agent Record > ### File List` updated with any new files from fixes

Total `findings_addressed` = Step 3a + Step 3b values. If fewer than Step 2's `findings_count`, report to user (partial completion acceptable — report, don't abort).

---

## Step 4: Finalize Story Artifacts (Orchestrator Direct)

**The orchestrator performs this step directly — no subagent.** Subagent chains reliably skip story file updates, so the orchestrator owns this responsibility. Use Read and Edit tools directly on the worktree files.

After Step 3's gate check passes, the orchestrator MUST read `{worktree_story_file}` in full and verify/fix ALL of the following:

### 4a. Task checkboxes
- ALL `- [ ]` lines under `## Tasks / Subtasks` must be `- [x]` (including subtasks)
- Use `replace_all` Edit to bulk-fix if needed

### 4b. Status line
- `Status:` line must be `done` — if not, change it

### 4c. Story Completion Status section
- Find the `### Story Completion Status` section (usually near the end, inside `## Dev Notes`)
- Update it to reflect completion: story status `done`, test count, date
- Example: `- Story status: \`done\`\n- All N ACs implemented and verified.\n- {test_count} tests passing, typecheck/lint/format all clean.`

### 4d. Change Log section
- If a `## Change Log` section exists, add an entry. If it doesn't exist, create one before `## Dev Agent Record`
- Entry format: `- **{date}** — Implementation: {brief summary of what was built}.`

### 4e. Review artifacts
Verify the code review from Step 2 is recorded in the story file:

- **`### Review Follow-ups (AI)`** subsection must exist inside `## Tasks / Subtasks` (after the last task). It should contain `[AI-Review]` items from the adversarial code review. If missing entirely, create it using the review data from Step 2's subagent response:
  - If `findings_count > 0`: list each finding as `- [x] [AI-Review][{severity}] {description} [{file}:{line}]`
  - If `findings_count == 0`: add a note that the review reported 0 findings (this is a process concern — the adversarial review mandates 3-10 findings minimum)
- **`## Senior Developer Review (AI)`** section must exist (typically between `## Tasks / Subtasks` and `## Dev Notes`, or after the tasks section). It should contain: review date, outcome, findings count with severity breakdown. If missing, create it using Step 2 data.
- If Step 3 addressed findings, verify the `[AI-Review]` items are marked `[x]` and resolution notes are in the completion notes.

### 4f. Dev Agent Record sections
Verify these subsections exist and have implementation-level content (not just the create-story boilerplate):

- **`### Agent Model Used`** — update to reflect actual models used. If QA ran (Step 1.6): `Claude Opus (implementation), Claude Sonnet (QA automation, review)`. If QA was skipped: `Claude Opus (implementation), Claude Sonnet (review)`.
- **`### Completion Notes List`** — must contain entries describing what was implemented, files created, tests added. If only create-story boilerplate is present, add implementation notes based on the PR diff and subagent reports from Steps 1-3.
- **`### File List`** — must list ALL new/modified source files from the implementation (not just the story file itself). Get the list from `git diff --name-only {base_branch}...HEAD` in the worktree, filtering out `_bmad-output/` and `.claude/` paths. Format: `- \`path/to/file.ts\` (NEW|MODIFIED)`

### 4g. Sprint status
- Read `{worktree_path}/_bmad-output/implementation-artifacts/sprint-status.yaml`
- The story key (e.g., `5-3-repository-targeting-daemon-installation`) must be `done` — fix if not
- If ALL stories in the story's epic are now `done`, also update the epic key to `done`

### 4h. Commit
If ANY edits were made in steps 4a–4g:
```bash
cd {worktree_path}
git add _bmad-output/implementation-artifacts/
git commit -m "chore(story-{slug}): finalize story artifacts and sprint status"
```

### 4i. Push and create PR
This is the ONLY push in the pipeline. All prior steps committed locally.
```bash
cd {worktree_path}
git push origin {worktree_branch}
gh pr create --base {base_branch} --title "feat(story-{slug}): {story-name-humanized}" --body "Story {story_number} — {story_name}"
```
Record `pr_url` and `pr_number` from the output.

**This step is NOT optional.** The PR must include the complete story artifacts so that when merged, main reflects the correct story state with full traceability.

---

## Error Handling

| Step | Failure | Action |
|------|---------|--------|
| 1 | Tests/lint/typecheck fail | Abort pipeline, report to user with output |
| 1.5 | Story file unreadable for assessment | Skip QA, proceed to Step 2 |
| 1.6 | Generated tests fail | Warn user, proceed to Step 2 (non-blocking) |
| 1.6 | Zero tests generated | Warn user, proceed to Step 2 |
| 2 | Worktree missing | Instruct subagent to recreate from remote branch |
| 2 | Fewer than 3 findings | Alert user — review may need re-run |
| 3a | Tests regress after High fix | Subagent must fix before proceeding |
| 3b | Tests regress after Medium/Low fix | Subagent must fix before proceeding |
| 3a/3b | Partial findings addressed | Report count to user, they complete manually |
| 4 | Story/sprint status not updatable | Report to user — manual fix needed |
| 4 | Push or PR creation fails | Check `gh auth status`, report |

---

## Post-Completion Report

After Step 4 succeeds, report to the user:

```
## Pipeline Complete

- **PR**: {pr_url} — ready for human review
- **Story**: {story_number} — {story_name_humanized}
- **Status**: done (story file and sprint-status.yaml updated in PR)
- **QA**: {skipped (not required) | {tests_generated} tests generated — {qa_status}}
- **Findings**: {findings_count} found, {findings_addressed} addressed
- **Tests**: {test_count} passing
- **Lint**: {lint_status}
- **Typecheck**: {typecheck_status}

### Cleanup
git worktree remove {worktree_path}
```
