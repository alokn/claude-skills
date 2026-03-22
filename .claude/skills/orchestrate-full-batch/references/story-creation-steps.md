# Phase A: Story Creation (Steps 1-3)

*These steps are identical for both sequential and parallel modes. In parallel mode, they run sequentially within each round before Phase B begins.*

## Step 1: Story Creation (Opus)

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

### Step 1 Gate Check

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

**If file doesn't exist** -> apply `on_failure` policy.
**If required sections are missing** -> warn, proceed to Step 2.

Record the resolved story file info:
- `story_file`: relative path from project root
- `story_file_name`: filename only
- `story_name`: extracted from filename (e.g., `5-3-repository-targeting.md` -> `repository-targeting`)

---

## Step 2: Multi-Perspective Review (Sonnet)

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

### Step 2 Gate Check

Parse the JSON block from the subagent's response and verify:
- `status` is `"REVIEWED"`
- `findings_raised >= 2` — if fewer, note in final report (review may have been shallow)
- `findings_applied >= 1` — story file was actually improved
- If gate fails -> proceed to Step 3 anyway but note in final report

**Story File Verification (orchestrator performs this directly):**
After the subagent returns, the orchestrator MUST read the story file itself and verify:
1. At least one `[Party-Review]` marker exists in the file (proving the review was applied)
2. The file still contains all required sections (Story, AC, Tasks, Dev Notes — not accidentally deleted)

If no `[Party-Review]` markers found -> warn in final report but proceed to Step 3.

---

## Step 3: SM Validation and Final Fixes (Sonnet)

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

### Step 3 Gate Check

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

If `Status: ready-for-dev` is not in the file -> fix it directly using Edit tool, then update sprint-status.yaml, commit with:
```bash
cd {project_root}
git add _bmad-output/implementation-artifacts/
git commit -m "chore(story-{story_slug}): finalize story status to ready-for-dev"
```
