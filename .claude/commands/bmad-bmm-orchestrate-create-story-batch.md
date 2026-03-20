---
name: 'orchestrate-create-story-batch'
description: 'Batch story creation pipeline: takes N (number of next stories to create) and runs the 3-step pipeline (create → review → SM validate) for each sequentially. Produces N ready-for-dev story files.'
disable-model-invocation: true
---

# Batch Orchestrated Story Creation Pipeline

You are a batch orchestrator that runs the full create → review → validate pipeline for multiple stories in sequence. Each story goes through 3 subagent steps before moving to the next.

## CRITICAL EXECUTION RULES

**You are a COORDINATOR.** Your job is to:
1. Validate all target stories upfront (pre-flight checks)
2. For each story, launch THREE sequential `Task` tool calls (create, review, validate) with gate checks between them
3. Verify story file integrity directly between steps (do not trust subagent claims)
4. Report cumulative results at the end

**NEVER do any of the following yourself:**
- Write or edit story files
- Run the create-story, party-mode, or SM workflows inline
- Invoke `Skill("bmad-bmm-create-story")`, `Skill("bmad-party-mode")`, or `Skill("bmad-agent-bmm-sm")` directly — these MUST be invoked by a subagent launched via the `Task` tool
- Generate story content, review findings, or validation checklists — subagents do this

**WHY 3 direct Task calls instead of 1 delegated orchestrator:** A previous design launched a single subagent that was supposed to invoke the single-story orchestrator skill and run 3 sub-subagents internally. This 3-level delegation chain (batch → orchestrator → step) reliably failed — the middle layer ran out of context/turns after Step 1 and skipped Steps 2 and 3 entirely, fabricating 0-findings results. By launching the 3 steps directly, the batch orchestrator keeps delegation at 2 levels (batch → step subagent), which is reliable.

## Input Parameters

Ask the user (via AskUserQuestion) for:
1. **Number of stories** (REQUIRED) — how many next backlog stories to create (e.g., `3`)
2. **On failure** (OPTIONAL, default: `stop`) — what to do when a story pipeline fails:
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
- `story_key`: e.g., `3.9`
- `story_slug`: e.g., `3-9`
- `story_name`: from sprint-status entry (e.g., `cli-help-command`)
- `story_file`: the expected output path `_bmad-output/implementation-artifacts/{story_slug}-{story_name}.md` (may not exist yet)

**Report target stories** as a table before confirming:

```
## Pre-Flight: Stories to Create

| # | Story | Name | Status |
|---|-------|------|--------|
| 1 | 3.9   | cli-help-command | backlog (no file) |
| 2 | 3.10  | audit-log-retention | backlog (no file) |
| 3 | 4.1   | daemon-lifecycle | backlog (no file) |
```

**Abort conditions:**
- No stories remain with `backlog` status and no existing file → abort; inform user all stories are created
- Sprint status file not found → abort

**Confirm with the user before starting:**
```
Ready to create {N} stories sequentially: {story_key_list}
Pipeline: 3 subagent steps (Opus create, Sonnet review, Sonnet SM validate) per story
Failure mode: {stop|skip}

Proceed? (y/n)
```

---

## Sequential Execution Loop

Stories are created **sequentially** — each story is fully validated before the next begins.

For each story in the resolved list, in order:

### Announce Current Story

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Story {current}/{total}: {story_key} — {story_name}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

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

Record the resolved absolute story file path: `{project_root}/{story_file}` (use this in Steps 2 and 3).

---

### Step 2: Multi-Perspective Review (Sonnet)

Launch a subagent via Task tool: `model: sonnet`, `subagent_type: general-purpose`

**IMPORTANT: Do NOT invoke party mode as a Skill.** Party mode is an interactive workflow that requires human-driven conversation (loading agents, waiting for `[C]`, processing user messages, exiting with `*exit`). A subagent cannot drive this interaction autonomously.

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

**Include in prompt:**
- Story file path (absolute): `{project_root}/{story_file}`
- Story key: `{story_key}`

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

**Include in prompt:**
- Story file path (absolute): `{project_root}/{story_file}`
- Story key: `{story_key}`
- The final deliverable must be a story file with status `ready-for-dev` that a developer can pick up immediately

#### Step 3 Gate Check

Parse the JSON block from the subagent's response and verify:
- `status` is `"VALIDATED"`
- `story_status` is `"ready-for-dev"`
- `validation_status` is `"PASS"` or `"PARTIAL"` — if `"FAIL"`, report to user with details
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

### Record Story Result

After each story completes (or fails), record:
- `story_key`, `story_name`
- `status`: `SUCCESS` | `FAILED` | `SKIPPED`
- `story_file`
- `findings_raised`, `findings_applied`
- `validation_status`, `checklist_score`
- `failure_reason`, `failure_step` (1-3)

### Handle Failure

- **`on_failure = stop`**: Stop batch, jump to report.
- **`on_failure = skip`**: Log failure, mark `FAILED`, continue to next story.

---

## Error Handling

| Step | Failure | Action |
|------|---------|--------|
| Pre-flight | No backlog stories without existing files | Abort; all stories already created |
| Pre-flight | Sprint-status.yaml not found | Abort entire batch |
| Pre-flight | Fewer than N stories available | Proceed with available count; warn user |
| 1 | Story file not created | Apply `on_failure` policy |
| 1 | Story file missing required sections | Warn; proceed to Step 2 |
| 2 | Zero findings from review | Warn in report; proceed to Step 3 |
| 2 | No `[Party-Review]` markers in file | Warn in report; proceed to Step 3 |
| 3 | SM validation returns FAIL | Report with checklist details; apply `on_failure` policy |
| 3 | Story not marked ready-for-dev | Orchestrator fixes directly; commits; proceeds |

---

## Batch Completion Report

```
## Batch Story Creation Pipeline Complete

### Summary
- **Stories processed**: {processed}/{total}
- **Succeeded (ready-for-dev)**: {success_count}
- **Failed**: {failed_count}
- **Skipped**: {skipped_count}

### Results

| # | Story | Name | Pipeline | Findings | SM Score | Status |
|---|-------|------|----------|----------|----------|--------|
| 1 | 3.9  | cli-help-command | SUCCESS | 4 raised / 4 applied | 14/15 | ready-for-dev |
| 2 | 3.10 | audit-log-retention | SUCCESS | 3 raised / 3 applied | 15/15 | ready-for-dev |
| 3 | 4.1  | daemon-lifecycle | FAILED (Step 1) | — | — | draft |

### Failed Stories
- **4.1**: Story file not created — {failure_details}

### Next Step
Run `/bmad-bmm-orchestrate-dev-story-batch` with the created story numbers to implement them.
```
