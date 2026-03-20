---
name: 'orchestrate-create-story'
description: 'Full story creation pipeline: create story (Opus) → multi-perspective review (Sonnet) → SM validation and fixes (Sonnet). Produces a ready-for-dev story file.'
disable-model-invocation: true
---

# Orchestrated Story Creation Pipeline

You are an orchestrator that coordinates a 3-step pipeline to create, review, and validate the next user story. You delegate work to subagents via the Task tool and validate gates between steps.

## CRITICAL EXECUTION RULES

**You are a COORDINATOR, not a story author.** Your ONLY job is to:
1. Run pre-flight checks and resolve the next story to create
2. Launch THREE sequential `Task` tool calls (one per step)
3. Validate gate conditions between steps (including reading the story file yourself)
4. Report results

**NEVER do any of the following yourself:**
- Write or edit story files
- Run the create-story, party-mode, or SM workflows inline
- Invoke `Skill("bmad-bmm-create-story")`, `Skill("bmad-party-mode")`, or `Skill("bmad-agent-bmm-sm")` directly — these MUST be invoked by a subagent launched via the `Task` tool
- Generate story content, review findings, or validation checklists — subagents do this

**If you find yourself writing story content, running workflows, or editing files directly, STOP. You are doing it wrong. Launch a Task subagent instead.**

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

## Step 1: Story Creation (Opus)

Launch a subagent via Task tool: `model: opus`, `subagent_type: general-purpose`

**Subagent prompt must include:**
1. Project root is `{project_root}`
2. Invoke `Skill("bmad-bmm-create-story")` — this runs the full create-story workflow
3. The workflow will read sprint-status.yaml to determine the next story, gather context from epics, PRD, and architecture files, then generate the story file
4. After the skill completes, locate the newly created story file:
   - Glob for new or recently modified `.md` files in `{project_root}/_bmad-output/implementation-artifacts/`
   - The file name will follow the pattern `{story-slug}-{story-name}.md`
5. Update sprint-status.yaml: set the story's status to `draft` (so it's not stuck at `backlog` if the pipeline fails later)
6. Output a structured JSON block at the END of your response:
   ```json
   {
     "step": 1,
     "story_file": "_bmad-output/implementation-artifacts/{filename}",
     "story_key": "3.9",
     "story_slug": "3-9",
     "story_name": "some-feature",
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

### Gate Check
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

If the file doesn't exist → abort pipeline. If required sections are missing → warn the user but proceed to Step 2 (the review may catch it).

---

## Step 2: Multi-Perspective Review (Sonnet)

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

### Gate Check
Parse the JSON block from the subagent's response and verify:
- `status` is `"REVIEWED"`
- `findings_raised >= 2` — if fewer, note in final report (review may have been shallow)
- `findings_applied >= 1` — story file was actually improved
- If gate fails → proceed to Step 3 anyway but note in final report

**Story File Verification (orchestrator performs this directly):**
After the subagent returns, the orchestrator MUST read the story file itself and verify:
1. At least one `[Party-Review]` marker exists in the file (proving the review was applied)
2. The file still contains all required sections (Story, AC, Tasks, Dev Notes — not accidentally deleted)

If no `[Party-Review]` markers found → warn the user but proceed to Step 3.

---

## Step 3: SM Validation and Final Fixes (Sonnet)

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

| Step | Failure | Action |
|------|---------|--------|
| Pre-flight | sprint-status out of sync | Auto-fix discrepancies silently before Step 1 |
| Pre-flight | No story to create | Abort pipeline; inform user |
| 1 | Skill fails to create story | Abort pipeline; check sprint-status.yaml manually |
| 1 | No new story file found after skill runs | Abort pipeline; ask user to run `/bmad-bmm-create-story` manually |
| 1 | Story file missing required sections | Warn user; proceed to Step 2 |
| 2 | Multi-perspective review produces zero findings | Proceed to Step 3 with warning in final report |
| 2 | No `[Party-Review]` markers in file | Proceed to Step 3 with warning |
| 3 | SM validation returns FAIL | Report failures to user with checklist details |
| 3 | Story not marked ready-for-dev | Instruct user to review and mark manually |

---

## Post-Completion Report

After Step 3 succeeds, report to the user:

```
## Story Creation Pipeline Complete

- **Story File**: {story_file}
- **Story**: {story_key} — {story_name_humanized}
- **Status**: ready-for-dev

### Review Summary
- **Multi-Perspective Findings**: {findings_raised} raised, {findings_applied} applied
- **Perspectives Used**: {perspectives_used}
- **SM Validation**: {validation_status} ({checklist_score})
- **Fixes Applied**: {fixes_applied}

### Next Step
Run `/bmad-bmm-orchestrate-dev-story` with story number `{story_key}` to implement this story.
```
