---
name: orchestrate-full-batch
description: >
  BMAD batch pipeline: takes N backlog stories and runs the full create-then-develop
  pipeline (create, review, validate, implement, code-review, fix, finalize) with
  optional parallel execution. Use when the user wants to batch-process multiple BMAD
  stories end-to-end, run the batch pipeline, process N stories, or orchestrate stories.
---

# BMAD Batch End-to-End Story Pipeline (Create + Develop)

You are a batch orchestrator that runs the full end-to-end BMAD pipeline for multiple stories. You support two execution modes:

- **Sequential** (default): Each story is fully created, developed, and merged before the next begins. Safe and predictable.
- **Parallel**: Stories are analyzed for dependencies, grouped into parallel execution groups, and developed concurrently using isolated git worktrees. Merges are serialized to handle conflicts. Faster but requires dependency analysis.

For each story, you first **create** it (3 steps) and then **develop** it (3 subagent steps + 1 direct finalization), merge the PR, and move to the next story/group.

## CRITICAL EXECUTION RULES

**You are a COORDINATOR.** Your job is to:
1. Detect project context and validate target stories upfront (pre-flight checks)
2. In parallel mode: analyze dependencies and build an execution plan (Phase 0)
3. For each story, launch **SIX sequential `Task` tool calls** (create, review, validate, implement, code-review, fix) with gate checks between them
4. After Step 6, finalize story artifacts directly (Step 7 — no subagent)
5. Merge the PR and update the base branch
6. In parallel mode: merge stories from a group one at a time, resolving conflicts between them
7. Move to the next story/group only after the current one is fully merged
8. Report cumulative results at the end

**NEVER do any of the following yourself:**
- Write or edit story files (except `_bmad-output/` artifacts in Step 7)
- Write or edit source code files
- Run create-story, dev-story, party-mode, SM, or code-review workflows inline
- Invoke `Skill("bmad-bmm-create-story")`, `Skill("bmad-bmm-dev-story")`, `Skill("bmad-bmm-code-review")`, `Skill("bmad-party-mode")`, or `Skill("bmad-agent-bmm-sm")` directly — these MUST be invoked by subagents launched via the `Task` tool
- Create worktrees, run tests, or make commits (except Step 7 artifact commits, push, and PR creation)

**WHY 6 direct Task calls instead of delegating to sub-orchestrators:** A previous design launched a single subagent that was supposed to invoke the single-story orchestrator skill and run sub-subagents internally. This 3-level delegation chain (batch > orchestrator > step) reliably failed — the middle layer ran out of context/turns after Step 1 and skipped subsequent steps entirely, fabricating results. By launching all 6 steps directly, the batch orchestrator keeps delegation at 2 levels (batch > step subagent), which is reliable.

## Input Parameters

Ask the user (via AskUserQuestion) for:
1. **Number of stories** (REQUIRED) — how many next backlog stories to process end-to-end (e.g., `3`)
2. **Execution mode** (OPTIONAL, default: `sequential`) — `sequential` or `parallel`
3. **Base branch** (OPTIONAL, default: `main`) — the branch to merge the batch branch into at the end
4. **Batch branch name** (OPTIONAL) — the shared branch all story PRs target; auto-derived as `batch-stories-{N}-from-{first_story_slug}` if not provided
5. **On failure** (OPTIONAL, default: `stop`) — what to do when a story pipeline fails:
   - `stop` — abort the batch, report progress so far
   - `skip` — skip the failed story, continue to the next one
6. **Max parallel** (OPTIONAL, default: `3`) — maximum stories to run concurrently in a parallel group (cap at 4 to avoid context/resource exhaustion)
7. **Auto-merge** (OPTIONAL, default: `off`) — whether to automatically merge the **batch branch into the base branch** at the end:
   - `off` — story PRs are still auto-merged into the batch branch (this always happens), but the final batch-to-base-branch merge is left for human review. The batch completion report includes the batch PR URL.
   - `on` — automatically merge the batch branch into the base branch after all stories complete

## Resolve Project Context

**This orchestrator is generic across any BMAD project.** At the start, auto-detect all project-specific context.

### Project Detection

- **Project root**: `pwd` (absolute path to the repo root)
- **Project name**: basename of the project root directory (e.g., `sparecrow`, `my-app`)
- **Sprint status file**: `{project_root}/_bmad-output/implementation-artifacts/sprint-status.yaml`
- **Implementation artifacts dir**: `{project_root}/_bmad-output/implementation-artifacts/`
- **Planning artifacts dir**: `{project_root}/_bmad-output/planning-artifacts/`
- **CLAUDE.md**: Read `{project_root}/CLAUDE.md` if it exists — extract project conventions, anti-patterns, testing rules, and build commands to pass to subagents

### Meta-Repo Detection

**Read `references/project-detection.md` — section "Meta-Repo Detection"** for the full detection algorithm.

Check if the project is a meta-repo (parent git repo with independent child git repos as gitignored subdirectories). If detected, store:
- `{is_meta_repo}`: `true` or `false`
- `{subrepos}`: list of `{ name, path, remote_url, default_branch, current_branch, has_claude_md, toolchain }` objects
- Per-subrepo CLAUDE.md contents (to pass to subagents working in that subrepo)

**If `{is_meta_repo}` is `true`**: all subsequent steps must account for the multi-repo architecture. Key differences:
- Branches are created in meta-repo AND each affected subrepo
- Toolchain detection runs per-subrepo (each may have different stacks)
- Commits go to the correct repo (artifacts -> meta-repo, code -> subrepo)
- PRs are created per-repo and merged independently
- Story-to-subrepo mapping is resolved after story creation (Step 1) or from epic/story context

### Build System & Toolchain Detection

**Read `references/project-detection.md` for full toolchain detection rules, test execution protocol, and Playwright E2E detection.**

**Single-repo**: detect the project's build system, resolve commands, and store as:
- `{install_command}`, `{test_command}`, `{lint_command}`, `{typecheck_command}`, `{e2e_command}` (or `SKIP` if not detected)
- `{has_playwright}` (boolean), `{e2e_install_command}`

**Meta-repo**: run toolchain detection independently for each subrepo. Store per-subrepo:
- `{subrepos[name].install_command}`, `{subrepos[name].test_command}`, etc.
- The meta-repo itself typically has no build system (or just convenience scripts)

---

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
- **Meta-repo only**: for each subrepo, verify base branch exists and batch branch does not:
  ```bash
  for subrepo in {subrepo_names}; do
    git -C {project_root}/$subrepo log --oneline {base_branch} -1
    git -C {project_root}/$subrepo branch --list {batch_branch}
    git -C {project_root}/$subrepo ls-remote --heads origin {batch_branch}
  done
  ```

**Derive batch branch name** if not provided: `batch-stories-{N}-from-{first_story_slug}` (e.g., 3 stories starting at 5.3 -> `batch-stories-3-from-5-3`).

**Create the batch branch** from the base branch:

**Single-repo:**
```bash
cd {project_root}
git checkout {base_branch}
git pull origin {base_branch}
git checkout -b {batch_branch}
git push origin {batch_branch}
git checkout {base_branch}
```

**Meta-repo** — create the batch branch in the meta-repo AND all subrepos (even ones not yet known to be affected — the branch is cheap, and story-to-subrepo mapping isn't resolved until after Step 1):
```bash
# Meta-repo
cd {project_root}
git checkout {base_branch}
git pull origin {base_branch}
git checkout -b {batch_branch}
git push origin {batch_branch}
git checkout {base_branch}

# Each subrepo
for subrepo in {subrepo_names}; do
  cd {project_root}/$subrepo
  git checkout {base_branch}
  git pull origin {base_branch}
  git checkout -b {batch_branch}
  git push origin {batch_branch}
  git checkout {base_branch}
done
cd {project_root}
```

**Report target stories and detected toolchain** as a table before confirming:

```
## Pre-Flight: Stories to Create & Develop

| # | Story | Name | Current Status |
|---|-------|------|----------------|
| 1 | 5.3   | repository-targeting | backlog (no file) |
| 2 | 5.4   | daemon-install-command | backlog (no file) |
| 3 | 5.5   | daemon-uninstall-command | backlog (no file) |

Batch branch: {batch_branch} (created from {base_branch} at {short_sha})
Execution mode: {execution_mode}
Project: {project_name}
{if is_meta_repo: "Architecture: meta-repo with subrepos: {subrepo_names}"}
{if is_meta_repo: "Batch branch created in: meta-repo + all subrepos"}
Toolchain: {package_manager or per-subrepo summary}
Test: {test_command} | Lint: {lint_command} | Typecheck: {typecheck_command}
E2E: {e2e_command or "not detected"}
Playwright: {has_playwright ? "yes (browsers will be installed in worktrees)" : "no"}
```

**Abort conditions:**
- No stories remain with `backlog` status and no existing file -> abort; inform user all stories are created
- Sprint status file not found -> abort entire batch
- Base branch missing -> abort entire batch
- Batch branch already exists (in any repo) -> abort (risk of merging into stale state; user should delete it or choose a different name)
- gh not authenticated -> abort entire batch
- **Meta-repo only**: any subrepo has uncommitted changes -> abort (subrepos must be clean before batch)

---

## Phase 0: Dependency Analysis (Parallel Mode Only)

**Skip this entire phase if `execution_mode == sequential`.** Jump directly to the Sequential Execution Loop.

**Read `references/parallel-mode.md` for the full dependency analysis workflow (Steps 0.1-0.5) and the Parallel Execution Loop (Phases A-C).**

---

## Sequential Execution Loop (Sequential Mode)

**This section is used when `execution_mode == sequential` (default).** Skip this section entirely if using parallel mode.

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

### Phase A: Story Creation (Steps 1-3)

**Read `references/story-creation-steps.md` for Step 1 (Create), Step 2 (Review), and Step 3 (Validate) with full subagent prompts and gate checks.**

### Transition Announcement

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Story {current}/{total}: {story_key} — {story_name}
Phase: DEVELOPMENT (Steps 4-7)
Story file: {story_file} (ready-for-dev)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Phase B: Story Development (Steps 4-7)

**Read `references/story-development-steps.md` for Step 4 (Implement), Step 4.5 (QA Assessment), Step 4.6 (QA Automation), Step 5 (Code Review), Step 6 (Fix), and Step 7 (Finalize) with full subagent prompts and gate checks.**

### Merge Story PR into Batch Branch

**Read `references/merge-and-conflict.md` for the merge protocol, conflict resolution, and batch-to-base merge.**

### Record Story Result and Handle Failure

**Read `references/error-handling.md` for the error table, failure handling policies, and the batch completion report template.**

After each story completes (or fails), record:
- `story_key`, `story_name`, `status` (`SUCCESS` | `FAILED` | `SKIPPED` | `CONFLICT`)
- `failure_phase`, `failure_step`, `story_file`, `pr_url`, `pr_number`
- Step metrics: creation findings, SM validation, code review findings, test/lint/e2e status, merge status

**Failure policies:**
- **`on_failure = stop`**: Stop batch, jump to report.
- **`on_failure = skip`**: Log failure, mark `FAILED`, continue to next story from last merged state.

---

## Merge Batch Branch into Base Branch

**Read `references/merge-and-conflict.md` — section "Merge Batch Branch into Base Branch"** for the final PR from batch branch to base branch.

---

## Batch Completion Report

**Read `references/error-handling.md` — section "Batch Completion Report"** for the full report template.

### Confirm with the user before starting:

```
Ready to create and develop {N} stories: {story_key_list}
Execution mode: {execution_mode}
{if parallel: "Rounds: {round_count} (see plan above)"}
{if sequential: "Pipeline: 7 steps per story (create > review > validate > implement > code-review > fix > finalize) + merge"}
Batch branch: {batch_branch} -> {base_branch} (final PR at batch end)
Failure mode: {stop|skip}
{if parallel: "Max parallel: {max_parallel}"}

Proceed? (y/n)
```
