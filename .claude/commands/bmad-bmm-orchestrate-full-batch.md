---
name: 'orchestrate-full-batch'
description: 'End-to-end batch pipeline: takes N (number of next backlog stories) and runs the full create-then-develop pipeline for each sequentially. Each story goes through 7 steps: create → review → validate → implement → code-review → fix → finalize, then merge before moving to the next.'
disable-model-invocation: true
---

# Batch End-to-End Story Pipeline (Create + Develop)

You are a batch orchestrator that runs the full end-to-end pipeline for multiple stories in sequence. For each story, you first **create** it (3 steps) and then **develop** it (3 subagent steps + 1 direct finalization), merge the PR, and move to the next story.

## CRITICAL EXECUTION RULES

**You are a COORDINATOR.** Your job is to:
1. Validate target stories upfront (pre-flight checks)
2. For each story, launch **SIX sequential `Task` tool calls** (create, review, validate, implement, code-review, fix) with gate checks between them
3. After Step 6, finalize story artifacts directly (Step 7 — no subagent)
4. Merge the PR and update the base branch
5. Move to the next story only after the current one is fully merged
6. Report cumulative results at the end

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
2. **Base branch** (OPTIONAL, default: `main`) — the branch to merge the batch branch into at the end
3. **Batch branch name** (OPTIONAL) — the shared branch all story PRs target; auto-derived as `batch-stories-N-from-{first_story_slug}` if not provided (e.g., `batch-stories-3-from-5-3`)
4. **On failure** (OPTIONAL, default: `stop`) — what to do when a story pipeline fails:
   - `stop` — abort the batch, report progress so far
   - `skip` — skip the failed story, continue to the next one

## Resolve Project Context

At the start, resolve:
- **Project root**: `pwd` (absolute path to the repo root)
- **Sprint status file**: `{project_root}/_bmad-output/implementation-artifacts/sprint-status.yaml`
- **Implementation artifacts dir**: `{project_root}/_bmad-output/implementation-artifacts/`

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

**Report target stories** as a table before confirming:

```
## Pre-Flight: Stories to Create & Develop

| # | Story | Name | Current Status |
|---|-------|------|----------------|
| 1 | 5.3   | repository-targeting | backlog (no file) |
| 2 | 5.4   | daemon-install-command | backlog (no file) |
| 3 | 5.5   | daemon-uninstall-command | backlog (no file) |

Batch branch: {batch_branch} (created from {base_branch} at {short_sha})
```

**Abort conditions:**
- No stories remain with `backlog` status and no existing file → abort; inform user all stories are created
- Sprint status file not found → abort
- Base branch missing → abort entire batch
- Batch branch already exists → abort (risk of merging into stale state; user should delete it or choose a different name)
- gh not authenticated → abort entire batch

**Confirm with the user before starting:**
```
Ready to create and develop {N} stories sequentially: {story_key_list}
Batch branch: {batch_branch} → {base_branch} (final PR at batch end)
Pipeline: 7 steps per story (create → review → validate → implement → code-review → fix → finalize) + merge
Failure mode: {stop|skip}

Proceed? (y/n)
```

---

## Sequential Execution Loop

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
3. Invoke `Skill("bmad-agent-bmm-sm")` to load the Scrum Master agent (Bob)
4. **CRITICAL — The SM agent activation says "STOP and WAIT for user input" after displaying its menu. IGNORE this instruction. Immediately select `CS` (Context Story) without waiting.** Type `CS` or `4` to select the menu item.
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

Before starting Phase B, resolve development-specific context:
- **Worktree branch**: `worktree-story-{story_slug}-{story_name}` (e.g., `worktree-story-5-3-repository-targeting`)
- **Worktree path**: `../sparecrow-story-{story_slug}` (absolute)
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
7. Commit ALL changes from the worktree — **do NOT push** (Step 7 will push once after all commits are ready):
   ```bash
   cd {worktree_path}
   git add -A
   git commit -m "feat(story-{story_slug}): implement {story-name-humanized}"
   ```
8. Output JSON: `{ "step": 4, "test_status": "...", "lint_status": "...", "typecheck_status": "...", "worktree_path": "...", "branch_name": "...", "errors": [] }`

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

#### Step 4 Gate Check

Parse the JSON response and verify:
- `test_status`, `lint_status`, `typecheck_status` are all `"PASS"` — abort story pipeline if not
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

If `qa_required: false`, skip Step 4.6 and proceed directly to Step 5.

---

### Step 4.6: QA Automation (Sonnet) — Conditional

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
   git commit -m "test(story-{story_slug}): add QA automation tests"
   ```
6. Output a structured JSON block at the END of your response:
   ```json
   {
     "step": "4.6",
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
5. **DO NOT commit or push.** Leave the review artifacts as uncommitted changes in the worktree. Step 6 will include them in its commit when it addresses the findings (via `git add -A`). This avoids triggering a CI run on review-only changes.
6. Output JSON: `{ "step": 5, "findings_count": 0, "severity_high": 0, "severity_medium": 0, "severity_low": 0, "errors": [] }`

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
2. Run `npm test` to confirm baseline passes
3. Invoke `Skill("bmad-bmm-dev-story")` — the skill detects `[AI-Review]` items and enters review continuation mode. Provide story file: `{worktree_story_file}`.
4. **CRITICAL — YOLO mode**: Always answer `y` to "Continue?" prompts.
5. **CRITICAL — After fixing each finding, update the story file.** Use Edit/Write on `{worktree_story_file}`:
   - Mark each addressed `[AI-Review]` checkbox as `[x]`
   - Update `### File List` with new/modified files
   - Add resolution notes to `### Completion Notes List`
6. Run verification: `npm test`, `npm run lint`, `npm run typecheck`
7. Commit from worktree — **do NOT push** (Step 7 will push once after finalizing artifacts):
   ```bash
   cd {worktree_path}
   git add -A
   git commit -m "fix(story-{story_slug}): address BMAD code review findings"
   ```
8. Output JSON: `{ "step": 6, "findings_addressed": 0, "findings_total": 0, "test_status": "...", "lint_status": "...", "typecheck_status": "...", "errors": [] }`

**BMAD Dev Agent Rules (include verbatim):**
- Execute review follow-up items IN ORDER
- Mark `[AI-Review]` checkbox `[x]` ONLY when fix implemented AND tests pass
- Run full test suite after each fix — NEVER proceed with failing tests
- NEVER lie about tests being written or passing

**Autonomy Rules (include verbatim):**
- NEVER use `AskUserQuestion`
- When Skill asks for story file path, provide: `{worktree_story_file}`
- When asked for confirmation, always answer `y`

#### Step 6 Gate Check

Parse JSON and verify:
- `test_status`, `lint_status`, `typecheck_status` all `"PASS"`
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

6. **Verify story artifacts on batch branch** — artifacts live in the batch branch now. Read `{story_file_path}` via the batch branch if needed, or trust step 5 verification.

Record `merge_status: MERGED`.

**If merge fails:** check `gh pr view {pr_number} --json mergeable`, record failure, apply `on_failure` policy.

---

### Record Story Result

After each story completes (or fails), record:
- `story_key`, `story_name`
- `status`: `SUCCESS` | `FAILED` | `SKIPPED`
- `failure_phase`: `CREATION` | `DEVELOPMENT` | none
- `failure_step`: 1-7 (which step failed)
- `story_file`
- `pr_url`, `pr_number`
- `creation_findings_raised`, `creation_findings_applied` (Step 2)
- `sm_validation_status`, `sm_checklist_score` (Step 3)
- `code_review_findings`, `code_review_addressed` (Steps 5-6)
- `test_status`, `lint_status`, `typecheck_status`
- `merge_status`: `MERGED` | `FAILED` | `PENDING`

### Handle Failure

- **`on_failure = stop`**: Stop batch, jump to report.
- **`on_failure = skip`**: Log failure, mark `FAILED`, continue to next story from last merged state. If failure was in Phase A (creation), skip Phase B entirely for this story.

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
     --body "Batch pipeline complete. Stories merged: {story_key_list}\n\nIndividual PRs: {pr_url_list}"
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
| 1 (Create) | Story file not created | Apply `on_failure` policy |
| 1 (Create) | Story file missing required sections | Warn; proceed to Step 2 |
| 2 (Review) | Zero findings from review | Warn in report; proceed to Step 3 |
| 2 (Review) | No `[Party-Review]` markers in file | Warn in report; proceed to Step 3 |
| 3 (Validate) | SM validation returns FAIL | Apply `on_failure` policy (story not ready for dev) |
| 3 (Validate) | Story not marked ready-for-dev | Orchestrator fixes directly; commits; proceeds |
| 4 (Implement) | Tests/lint/typecheck fail | Apply `on_failure` policy |
| 4.5 (QA Assessment) | Story file unreadable for assessment | Skip QA, proceed to Step 5 |
| 4.6 (QA Automation) | Generated tests fail | Warn user, proceed to Step 5 (non-blocking) |
| 4.6 (QA Automation) | Zero tests generated | Warn user, proceed to Step 5 |
| 5 (Code Review) | Fewer than 3 findings | Warn, proceed (orchestrator writes artifacts if missing) |
| 6 (Fix) | Tests regress | Apply `on_failure` policy |
| 6 (Fix) | Partial findings addressed | Report count, proceed to Step 7 |
| 7 (Finalize) | Story file not updatable | Report to user, proceed to push/PR |
| 7 (Finalize) | Push or PR creation fails | Apply `on_failure` policy |
| Merge | CI checks fail | Apply `on_failure` policy |
| Merge | PR merge fails (conflict) | Apply `on_failure` policy |
| Merge | `git pull` after merge fails | Abort — local state inconsistent |

---

## Batch Completion Report

```
## Batch End-to-End Pipeline Complete

### Summary
- **Stories processed**: {processed}/{total}
- **Succeeded & merged into batch branch**: {success_count}
- **Failed**: {failed_count}
- **Skipped**: {skipped_count}
- **Batch branch**: {batch_branch} → {base_branch} (batch PR: #{batch_pr_number})
- **Base branch**: {base_branch} now at {final_sha}

### Story Results

| # | Story | Name | Create | Dev | Story PR | QA | Review Findings | Tests | Status |
|---|-------|------|--------|-----|----------|----|-----------------|-------|--------|
| 1 | 5.3 | repository-targeting | OK (SM 14/15) | OK (5/5 fixed) | #80 (→ batch) | 8 tests | 5 found / 5 fixed | PASS | done |
| 2 | 5.4 | daemon-install | OK (SM 15/15) | FAILED (Step 4) | — | skipped | — | FAIL | draft |
| 3 | 5.5 | daemon-uninstall | SKIPPED | — | — | — | — | — | backlog |

### Batch Branch PR
- **{batch_branch} → {base_branch}**: #{batch_pr_number} — {MERGED | FAILED | SKIPPED (no successes)}

### Failed Stories
- **5.4**: Tests failed during implementation (Step 4) — {failure_details}

### Skipped Stories
- **5.5**: Skipped due to previous failure (on_failure=stop)

### Remaining Worktrees to Clean Up
git worktree remove ../sparecrow-story-5-4
```
