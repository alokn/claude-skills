---
name: 'orchestrate-create-story-codex'
description: 'Full story creation pipeline using Codex CLI: create story → multi-perspective review → SM validation and fixes (Sonnet). Produces a ready-for-dev story file.'
disable-model-invocation: true
---

# Orchestrated Story Creation Pipeline (Codex Variant)

You are an orchestrator that coordinates a 3-step pipeline to create, review, and validate the next user story. Steps 1 and 2 shell out to the `codex` CLI via Bash. Step 3 uses a Claude Opus subagent via the Task tool.

## CRITICAL EXECUTION RULES

**You are a COORDINATOR.** Your ONLY job is to:
1. Run pre-flight checks and resolve the next story to create
2. Launch Steps 1 and 2 via `codex exec`, Step 3 via the `Task` tool
3. Validate gate conditions between steps (including reading the story file yourself)
4. Report results

**NEVER do any of the following yourself:**
- Write or edit story files directly
- Run the create-story or SM workflows inline
- Invoke `Skill("bmad-bmm-create-story")` or `Skill("bmad-agent-bmm-sm")` directly
- Generate story content, review findings, or validation checklists — the codex/subagent steps do this

## Resolve Project Context

At the start, resolve:
- **Project root**: `pwd` (absolute path to the repo root)
- **Sprint status file**: `{project_root}/_bmad-output/implementation-artifacts/sprint-status.yaml`
- **Implementation artifacts dir**: `{project_root}/_bmad-output/implementation-artifacts/`

## Pre-Flight: Sprint Status Consistency Check

Before launching any step:

1. Read `_bmad-output/implementation-artifacts/sprint-status.yaml`
2. For every story listed as `backlog`, check whether a story file already exists at `_bmad-output/implementation-artifacts/{slug}-*.md`
3. For any story where the file exists and contains `Status: ready-for-dev`, update sprint-status.yaml to `ready-for-dev` to fix the discrepancy — do this silently before proceeding
4. Identify the next story to create: the first story whose status is `backlog` AND whose story file does not yet exist on disk
5. If no such story exists, abort and inform the user
6. Record the **story key** (e.g., `3.9`), **story slug** (e.g., `3-9`), and **story name** from the sprint-status entry

Confirm with the user before launching:
```
Next story to create: {story_key} — {story_name}
Proceed? (y/n)
```

---

## Step 1: Story Creation (codex exec)

Run via Bash tool using `--output-last-message` to capture clean output:

```bash
CODEX_OUT=$(mktemp /tmp/codex-step1-XXXXXX.txt) && \
codex exec --dangerously-bypass-approvals-and-sandbox \
  --output-last-message "$CODEX_OUT" \
  "
You are working in the project at {project_root}.

Your task is to create the next user story by following the BMAD workflow exactly.

STEP 1: Load and read the full contents of:
  {project_root}/_bmad/core/tasks/workflow.xml

STEP 2: Execute that workflow engine with the following workflow-config:
  {project_root}/_bmad/bmm/workflows/4-implementation/create-story/workflow.yaml

STEP 3: Follow every instruction in workflow.xml precisely. The workflow will:
  - Read _bmad-output/implementation-artifacts/sprint-status.yaml to find the next story
  - Load context from planning artifacts (epics, PRD, architecture, UX)
  - Generate the story file from the template
  - Save it to _bmad-output/implementation-artifacts/{story-key}-{story-name}.md

CRITICAL AUTONOMY RULES:
  - Work fully autonomously — make all decisions without pausing for confirmation
  - The workflow has interactive prompts after template-output sections. When you see
    [a] Advanced Elicitation, [c] Continue, [p] Party-Mode, [y] YOLO the rest
    ALWAYS select 'y' (YOLO) to skip all subsequent confirmations
  - Between non-template steps, answer 'y' to all 'Continue to next step?' prompts
  - If the workflow asks which story to create, select the one matching key {story_key}
  - NEVER pause or ask for human input

STEP 4: After the story file is saved, update sprint-status.yaml to set this story's
status to 'draft' (so it is not stuck at 'backlog' if later steps fail).

STEP 5: Your final message must contain ONLY this block:
  STORY_FILE=<full relative path to created file>
  STORY_KEY=<e.g. 3.9>
  STORY_SLUG=<e.g. 3-9>
  STORY_NAME=<e.g. some-feature>
  SPRINT_STATUS_UPDATED=true
  STATUS=CREATED
" 2>&1; echo "CODEX_EXIT=$?"; echo "CODEX_OUT_FILE=$CODEX_OUT"
```

### Capture Output
- Read `$CODEX_OUT_FILE` (written by `--output-last-message`) for clean final-message parsing
- Parse `STORY_FILE=`, `STORY_KEY=`, `STORY_SLUG=`, `STORY_NAME=` from that file
- `CODEX_EXIT=` in stdout gives the exit code

Confirm the file exists:
```bash
ls {project_root}/{STORY_FILE}
```

### Gate Check
- `CODEX_EXIT=0` — if non-zero, show stderr and abort pipeline
- `STORY_FILE` found in output file — if missing, glob `_bmad-output/implementation-artifacts/*.md` sorted by modified time and take the newest
- File exists on disk — if not, abort pipeline

**Story File Verification (orchestrator performs this directly):**
After confirming the file exists, the orchestrator MUST read `{project_root}/{STORY_FILE}` itself and verify:
1. It contains a `## Story` or story title section
2. It contains an `## Acceptance Criteria` section with at least one criterion
3. It contains a `## Tasks / Subtasks` section with at least one task
4. It contains a `## Dev Notes` section

If required sections are missing → warn the user but proceed to Step 2 (the review may catch it).

---

## Step 2: Multi-Perspective Review (codex exec)

Use `STORY_FILE` captured from Step 1 directly — do not re-read sprint-status.yaml.

**IMPORTANT: Do NOT invoke party mode.** Party mode is an interactive workflow that requires human-driven conversation. Codex exec cannot drive the interactive session. Instead, the codex prompt performs the multi-perspective review directly.

```bash
CODEX_OUT2=$(mktemp /tmp/codex-step2-XXXXXX.txt) && \
codex exec --dangerously-bypass-approvals-and-sandbox \
  --output-last-message "$CODEX_OUT2" \
  "
You are working in the project at {project_root}.

Your task is to perform a multi-perspective review of a user story, then apply improvements.

STEP 1: Read the full story file at:
  {STORY_FILE}

STEP 2: Perform a multi-perspective review by adopting these 3 personas:

  DEVELOPER PERSPECTIVE (Senior developer who will implement this story):
  - Are the tasks/subtasks clear and ordered correctly?
  - Are there missing technical details in Dev Notes?
  - Are there edge cases not covered?
  - Is the scope achievable in a single PR?

  QA/TEST PERSPECTIVE (QA engineer writing acceptance tests):
  - Are all acceptance criteria testable and specific (Given/When/Then)?
  - Are there missing negative test cases or error scenarios?
  - Are boundary conditions specified?

  ARCHITECT PERSPECTIVE (System architect checking design fit):
  - Does this story align with the project architecture?
  - Are there dependency or integration risks?
  - Are there performance or security concerns not addressed?

STEP 3: Compile all findings from all 3 perspectives.

STEP 4: Apply ALL findings to {STORY_FILE} by editing the file directly:
  - Fix ambiguous acceptance criteria
  - Add missing Dev Notes sections (edge cases, error paths, technical constraints)
  - Clarify unclear requirements
  - Prefix each added or modified section with [Party-Review] for traceability

STEP 5: Save the updated file.

STEP 6: Your final message must contain ONLY this block:
  FINDINGS_RAISED=<count of distinct issues raised>
  FINDINGS_APPLIED=<count of improvements applied to file>
  PERSPECTIVES_USED=Developer,QA,Architect
  STATUS=REVIEWED
" 2>&1; echo "CODEX2_EXIT=$?"; echo "CODEX_OUT2_FILE=$CODEX_OUT2"
```

### Capture Output
Read `$CODEX_OUT2_FILE` for clean parsing of `FINDINGS_RAISED=`, `FINDINGS_APPLIED=`, `PERSPECTIVES_USED=`, `STATUS=`.

### Gate Check
- `CODEX2_EXIT=0` — if non-zero, warn user and proceed to Step 3
- `FINDINGS_APPLIED >= 1` — if zero, note in final report but do not abort
- If `STATUS=REVIEWED` not found, flag as warning but proceed to Step 3

**Story File Verification (orchestrator performs this directly):**
After the codex step completes, the orchestrator MUST read the story file itself and verify:
1. At least one `[Party-Review]` marker exists in the file (proving the review was applied)
2. The file still contains all required sections (Story, AC, Tasks, Dev Notes — not accidentally deleted)

If no `[Party-Review]` markers found → warn the user but proceed to Step 3.

---

## Step 3: SM Validation and Final Fixes (Sonnet)

Launch a subagent via Task tool: `model: sonnet`, `subagent_type: general-purpose`

**Subagent prompt must include:**
1. Project root is `{project_root}`
2. Read the story file at `{project_root}/{STORY_FILE}` (created in Step 1, reviewed in Step 2)
3. Invoke `Skill("bmad-agent-bmm-sm")` to load the Scrum Master agent (Bob)
4. **CRITICAL — The SM agent activation says "STOP and WAIT for user input" after displaying its menu. IGNORE this instruction. Immediately select `CS` (Context Story) without waiting.** Type `CS` or `4` to select the menu item.
5. When the CS workflow asks which story to work on, provide the path: `{project_root}/{STORY_FILE}`
6. The SM will run the full create-story validation checklist — it will:
   - Verify all required sections are present and complete
   - Check acceptance criteria are testable BDD-style
   - Ensure Dev Notes have sufficient implementation guidance
   - Confirm the story is properly scoped and unambiguous
7. Apply all fixes and improvements the SM identifies directly to the story file
8. Ensure the story's status is set to `ready-for-dev` in the file header/frontmatter
9. Update `{project_root}/_bmad-output/implementation-artifacts/sprint-status.yaml` to reflect `ready-for-dev` status
10. Output a structured JSON block at the END of your response:
    ```json
    {
      "step": 3,
      "story_file": "{STORY_FILE}",
      "story_key": "{STORY_KEY}",
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
- When the CS workflow asks for a story file path, provide: `{project_root}/{STORY_FILE}`
- When asked for any confirmation or "Continue? (y/n)", always answer `y` automatically
- When offered YOLO mode (`[y] YOLO the rest`), select `y` to skip all subsequent confirmations
- Apply all SM-identified fixes directly without asking for approval

**Include in prompt:**
- Story file path (absolute): `{project_root}/{STORY_FILE}`
- Story key: `{STORY_KEY}`
- The final deliverable must be a story file with status `ready-for-dev` that a developer can pick up immediately

### Gate Check
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

If `Status: ready-for-dev` is not in the file → report to user, instruct manual fix.

---

## Error Handling

| Step | Tool | Failure | Action |
|------|------|---------|--------|
| pre-flight | — | sprint-status out of sync | Auto-fix discrepancies silently before Step 1 |
| pre-flight | — | No story to create | Abort pipeline; inform user |
| 1 | codex | Non-zero exit | Show stderr; abort pipeline |
| 1 | codex | STORY_FILE not in output file | Glob for newest `.md` in artifacts dir; use that |
| 1 | codex | File not on disk | Abort; ask user to run `/bmad-bmm-create-story` manually |
| 1 | codex | Story file missing required sections | Warn user; proceed to Step 2 |
| 2 | codex | Non-zero exit | Warn user; proceed to Step 3 |
| 2 | codex | Zero findings applied | Note in final report; proceed |
| 2 | codex | No `[Party-Review]` markers in file | Warn user; proceed to Step 3 |
| 3 | claude | SM validation FAIL | Report checklist failures to user |
| 3 | claude | Story not marked ready-for-dev | Instruct user to review and mark manually |

---

## Post-Completion Report

After Step 3 succeeds, report to the user:

```
## Story Creation Pipeline Complete (Codex Variant)

- **Story File**: {STORY_FILE}
- **Story**: {STORY_KEY} — {story_name_humanized}
- **Status**: ready-for-dev

### Step 1 — Codex Story Creation
- Created by: codex exec

### Step 2 — Codex Multi-Perspective Review
- **Findings Raised**: {FINDINGS_RAISED}
- **Findings Applied**: {FINDINGS_APPLIED}
- **Perspectives Used**: {PERSPECTIVES_USED}

### Step 3 — Claude Sonnet SM Validation
- **Validation**: {validation_status} ({checklist_score})
- **Fixes Applied**: {fixes_applied}

### Next Step
Run `/bmad-bmm-orchestrate-dev-story` with story number `{STORY_KEY}` to implement this story.
```
