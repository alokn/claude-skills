# Merge Story PR into Batch Branch

*In sequential mode, this runs immediately after Step 7 for each story. In parallel mode, this runs as part of Phase C (Sequential Merge) after all stories in a round complete development.*

**CRITICAL — this step ensures each subsequent story builds on the previous one (all within the batch branch).**

## Single-Repo Merge

**Story-to-batch merges always happen automatically** regardless of the `{auto_merge}` setting. The `{auto_merge}` parameter only controls the final batch-to-base-branch merge.

1. **Wait for CI checks** (if configured):
   ```bash
   gh pr checks {pr_number} --watch --fail-fast
   ```
   If no checks are configured (exit code 1 with "no checks reported"), proceed to merge.

2. **Check for merge conflicts** (parallel mode — may have conflicts from earlier merges in the same round):
   ```bash
   gh pr view {pr_number} --json mergeable --jq '.mergeable'
   ```
   If `CONFLICTING` -> apply Conflict Resolution Protocol (see below).
   If `MERGEABLE` or sequential mode -> proceed.

3. **Merge the story PR into the batch branch**:
   ```bash
   gh pr merge {pr_number} --squash --delete-branch
   ```

4. **Update local batch branch** (so the next story worktree starts from it):
   ```bash
   cd {project_root}
   git fetch origin {batch_branch}
   git branch -f {batch_branch} origin/{batch_branch}
   ```

5. **Clean up worktree**:
   ```bash
   git worktree remove {worktree_path}
   ```

6. **Verify merge landed**:
   ```bash
   git log --oneline {batch_branch} -3
   ```

7. **Verify story artifacts on batch branch** — artifacts live in the batch branch now.

Record `merge_status: MERGED`.

**If merge fails:** check `gh pr view {pr_number} --json mergeable`, record failure, apply `on_failure` policy.

## Meta-Repo Merge (when `{is_meta_repo}` is `true`)

Story-to-batch merges always happen automatically. Merge PRs in this order:

1. **Merge subrepo PRs first** (code before artifacts):

   For each subrepo in `{story_prs}`:
   ```bash
   # Wait for CI (if configured for this subrepo)
   gh pr checks {subrepo_prs[$subrepo].pr_number} --repo {subrepos[$subrepo].remote_url} --watch --fail-fast

   # Check mergeability
   gh pr view {subrepo_prs[$subrepo].pr_number} --repo {subrepos[$subrepo].remote_url} --json mergeable --jq '.mergeable'

   # Merge
   gh pr merge {subrepo_prs[$subrepo].pr_number} --repo {subrepos[$subrepo].remote_url} --squash --delete-branch

   # Update local subrepo batch branch
   cd {project_root}/{subrepo}
   git fetch origin {batch_branch}
   git branch -f {batch_branch} origin/{batch_branch}
   ```

2. **Clean up subrepo worktrees**:
   ```bash
   for subrepo in {affected_subrepos}; do
     cd {project_root}/{subrepo}
     git worktree remove {subrepo_worktree_paths[$subrepo]}
   done
   ```

3. **Verify all subrepo merges landed**:
   ```bash
   for subrepo in {affected_subrepos}; do
     echo "=== $subrepo ==="
     git -C {project_root}/$subrepo log --oneline {batch_branch} -3
   done
   ```

4. **Meta-repo artifacts** were already pushed directly to the batch branch in Step 7i — no separate merge needed. Verify:
   ```bash
   cd {project_root}
   git log --oneline {batch_branch} -3
   ```

5. **Verify story artifacts on batch branch** — artifacts live in the meta-repo batch branch.

Record per-subrepo: `{subrepo_merge_statuses}` — dict of `{ subrepo_name: "MERGED" | "FAILED" | "CONFLICT" }`.
Record overall: `merge_status: MERGED` only if ALL subrepo PRs merged successfully.

**If any subrepo merge fails**: the story is partially merged. Apply `on_failure` policy. If `skip`, mark the story as `PARTIAL_MERGE` and note which subrepos merged and which didn't. **Do NOT continue to the next story** until the partial merge is resolved — subsequent stories may depend on the code that wasn't merged.

**Merge order for multi-subrepo stories**: if a story touches both a library subrepo (e.g., `shared-lib`) and a consumer subrepo (e.g., `my-app`), merge the library first, then the consumer. This ensures the consumer's CI can pull the updated library.

---

# Conflict Resolution Protocol (Parallel Mode)

When a story PR has merge conflicts with the updated batch branch (because a previous story in the same round was just merged):

## Step CR-1: Classify the conflict

```bash
cd {worktree_path}
git fetch origin {batch_branch}
git merge origin/{batch_branch} --no-commit --no-ff 2>&1 || true
git diff --name-only --diff-filter=U
```

Count conflicting files and examine their nature:

- **Trivial conflicts** (0-2 files, all in `_bmad-output/` or import-only changes): Auto-resolve
- **Moderate conflicts** (1-3 source files, changes in different functions/sections): Attempt rebase
- **Complex conflicts** (3+ source files, overlapping logic changes): Flag for user

## Step CR-2: Attempt auto-resolution

For trivial conflicts:
```bash
cd {worktree_path}
git merge --abort
git rebase origin/{batch_branch}
# If rebase succeeds cleanly:
git push origin {worktree_branch} --force-with-lease
```

For moderate conflicts:
```bash
cd {worktree_path}
git merge --abort
git rebase origin/{batch_branch}
```

If rebase has conflicts:
```bash
# Check each conflicting file
git diff --name-only --diff-filter=U
# For each file, read the conflict markers and attempt resolution
```

**Resolution strategies for common patterns:**
- **Import ordering**: Accept both imports (union merge)
- **Adjacent additions** (both stories added code near the same location but not overlapping): Accept both additions in story-number order
- **Sprint-status.yaml**: Both stories updated status -> merge both status changes (this is almost always safe)
- **Shared type file**: Both stories added new types -> accept both type definitions
- **Same function modified**: HALT — this requires human judgment

After resolving:
```bash
git add .
git rebase --continue
# Re-run full test suite to verify resolution didn't break anything:
{test_command} 2>&1 > /tmp/{project_name}-conflict-test; tail -40 /tmp/{project_name}-conflict-test
{lint_command}
{typecheck_command}
rm /tmp/{project_name}-conflict-test
# If tests pass, force-push the rebased branch:
git push origin {worktree_branch} --force-with-lease
```

Then retry the merge:
```bash
gh pr merge {pr_number} --squash --delete-branch
```

## Step CR-3: Handle unresolvable conflicts

If auto-resolution fails or tests fail after resolution:
```
Warning: MERGE CONFLICT — Manual Resolution Required

Story: {story_key} — {story_name}
PR: {pr_url}
Conflicting files:
{conflict_file_list}

The worktree is preserved at: {worktree_path}
The PR is open at: {pr_url}

Options:
1. Resolve manually in the worktree, then run: git push origin {worktree_branch} --force-with-lease
2. Skip this story and continue with the next round
3. Abort the batch

Remaining stories in this round that haven't merged yet: {remaining_stories}
```

Apply `on_failure` policy:
- `stop`: Pause batch, report progress, leave worktrees intact for manual resolution
- `skip`: Skip this story, mark as `CONFLICT`, continue to next story in merge order. **Important**: Subsequent stories in the SAME round may also conflict if they depended on the skipped story's changes — check each one.

---

# Merge Batch Branch into Base Branch

**This step runs ONCE after all stories in the batch have been processed (or after stopping on failure).**

**If `{auto_merge}` is `off` (default):** create the batch-to-base PR but do NOT merge it. Report the PR URL so the human can review the combined diff of all stories and merge manually.

```bash
# Single-repo or meta-repo: create the PR, then stop
gh pr create \
  --base {base_branch} \
  --head {batch_branch} \
  --title "batch: merge {batch_branch} into {base_branch}" \
  --body "Batch pipeline complete. Stories merged into batch: {story_key_list}\n\nExecution mode: {execution_mode}\nAuto-merge: off — awaiting human review"
```
Record `batch_pr_url`, `batch_pr_number`, and `batch_merge_status: PR_OPEN`. For meta-repos, create a batch PR in each subrepo that has commits on the batch branch, plus one in the meta-repo. Skip the merge steps below.

**If `{auto_merge}` is `on`:** proceed with the merge steps below.

Only run this step if `success_count >= 1` (at least one story was successfully merged into the batch branch).

## Single-Repo

1. **Verify batch branch is ahead of base branch**:
   ```bash
   git log --oneline {base_branch}..origin/{batch_branch}
   ```
   If no commits ahead -> skip (nothing to merge; warn user).

2. **Create a PR from batch branch to base branch**:
   ```bash
   gh pr create \
     --base {base_branch} \
     --head {batch_branch} \
     --title "batch: merge {batch_branch} into {base_branch}" \
     --body "Batch pipeline complete. Stories merged: {story_key_list}\n\nExecution mode: {execution_mode}\nIndividual PRs: {pr_url_list}"
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

## Meta-Repo Batch Merge

In a meta-repo, the batch branch exists in the meta-repo AND each subrepo that was touched. Create a final PR in each repo.

**Merge order**: subrepos first (libraries before consumers), meta-repo last.

1. **For each subrepo that has commits on the batch branch**:
   ```bash
   cd {project_root}/{subrepo}
   # Verify batch branch is ahead
   git fetch origin
   git log --oneline {base_branch}..origin/{batch_branch} | head -5

   # Create batch PR (only if there are commits ahead)
   gh pr create --repo {subrepos[$subrepo].remote_url} \
     --base {base_branch} \
     --head {batch_branch} \
     --title "batch: merge {batch_branch} into {base_branch}" \
     --body "Batch pipeline complete.\nSubrepo: $subrepo\nStories merged: {story_key_list_for_subrepo}\n\nExecution mode: {execution_mode}"

   # Wait for CI and merge
   gh pr checks {subrepo_batch_pr_number} --repo {subrepos[$subrepo].remote_url} --watch --fail-fast
   gh pr merge {subrepo_batch_pr_number} --repo {subrepos[$subrepo].remote_url} --merge --delete-branch

   # Update local
   git checkout {base_branch}
   git pull origin {base_branch}
   ```

2. **For the meta-repo** (after all subrepo batch PRs are merged):
   ```bash
   cd {project_root}
   git fetch origin
   git log --oneline {base_branch}..origin/{batch_branch} | head -5

   gh pr create \
     --base {base_branch} \
     --head {batch_branch} \
     --title "batch: merge {batch_branch} into {base_branch}" \
     --body "Batch pipeline complete.\nStories merged: {story_key_list}\nSubrepo PRs: {subrepo_batch_pr_urls}\n\nExecution mode: {execution_mode}"

   gh pr checks {batch_pr_number} --watch --fail-fast
   gh pr merge {batch_pr_number} --merge --delete-branch

   git checkout {base_branch}
   git pull origin {base_branch}
   ```

3. **Verify all repos are on base branch at expected state**:
   ```bash
   echo "=== Meta-repo ==="
   git log --oneline {base_branch} -5
   for subrepo in {all_affected_subrepos}; do
     echo "=== $subrepo ==="
     git -C {project_root}/$subrepo log --oneline {base_branch} -5
   done
   ```

Record per-repo: `{batch_merge_statuses}` — dict of `{ repo_name: "MERGED" | "FAILED" }`.
Record overall: `batch_merge_status: MERGED` only if ALL repo batch PRs merged.

**If any subrepo batch merge fails**: report to user with the PR URL. The meta-repo batch PR should NOT be merged until all subrepo batch PRs are in — otherwise the meta-repo artifacts would reference code that hasn't landed yet.

**Cleanup**: delete the batch branch in any subrepo where it was created but never used (no stories targeted that subrepo):
```bash
for subrepo in {unused_subrepos}; do
  cd {project_root}/$subrepo
  git branch -d {batch_branch} 2>/dev/null
  git push origin --delete {batch_branch} 2>/dev/null
done
```
