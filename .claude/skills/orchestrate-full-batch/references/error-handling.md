# Error Handling

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
| Merge | Conflict auto-resolution fails | Mark `CONFLICT`; apply `on_failure` (stop -> HALT for manual, skip -> skip story) |
| Merge | Tests fail after conflict resolution | Mark `CONFLICT`; apply `on_failure` |
| Merge | `git pull` after merge fails | Abort — local state inconsistent |

---

# Story Result Recording

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

## Failure Policies

- **`on_failure = stop`**: Stop batch, jump to report.
- **`on_failure = skip`**: Log failure, mark `FAILED`, continue to next story from last merged state. If failure was in Phase A (creation), skip Phase B entirely for this story.
- **Parallel mode conflict**: If a story in a parallel round can't be merged due to conflicts, subsequent stories in the SAME round should still attempt merge (they branched from the same base). Mark the conflicting story as `CONFLICT` and note it in the report.

---

# Batch Completion Report

```
## Batch End-to-End Pipeline Complete

### Summary
- **Project**: {project_name}
- **Execution mode**: {execution_mode}
- **Auto-merge**: {auto_merge}
- **Stories processed**: {processed}/{total}
- **Succeeded & merged into batch branch**: {success_count}
- **Failed**: {failed_count}
- **Skipped**: {skipped_count}
- **Conflicts**: {conflict_count} (parallel mode only)
- **Batch branch**: {batch_branch}
- {if auto_merge on: "**Batch -> base**: #{batch_pr_number} — MERGED into {base_branch} at {final_sha}"}
- {if auto_merge off: "**Batch -> base**: #{batch_pr_number} — PR OPEN, awaiting human review"}
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
| 1 | 7.6 | agent-feedback | R1 | OK (SM 14/15) | OK (5/5 fixed) | #80 (-> batch) | 8 tests | 5 found / 5 fixed | PASS | PASS | MERGED | done |
| 2 | 8.1 | wsl-detection | R1 | OK (SM 15/15) | OK | #81 (-> batch) | skipped | 4 found / 4 fixed | PASS | N/A | MERGED | done |
| 3 | 9.1 | cors-fix | R1 | OK | OK | #82 (-> batch) | skipped | 3 found / 3 fixed | PASS | PASS | AUTO_RESOLVED | done |
| 4 | 8.2 | wsl-preview | R2 | OK | FAILED (Step 4) | — | — | — | FAIL | — | — | draft |

### Batch Branch PR
- **{batch_branch} -> {base_branch}**: #{batch_pr_number} — {MERGED | PR_OPEN | FAILED | SKIPPED (no successes)}
{if auto_merge off: "Review the batch PR to see the combined diff of all stories before merging."}
{if meta_repo and auto_merge off: "Subrepo batch PRs also open — merge subrepo PRs before the meta-repo PR. Merge library subrepos before consumer subrepos."}

### Conflict Resolutions (Parallel Mode Only)
- **9-1**: Auto-resolved — import ordering in `packages/server/src/middleware/cors.ts` (1 file, trivial)

### Failed Stories
- **8.2**: Tests failed during implementation (Step 4) — {failure_details}

### Skipped Stories
- **8.3-8.6**: Skipped due to previous failure (on_failure=stop)

### Remaining Worktrees to Clean Up
git worktree remove ../{project_name}-story-8-2
```
