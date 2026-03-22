# Meta-Repo Detection

Before detecting build systems, determine whether the project is a **meta-repo** — a parent git repo that contains independent child git repos as subdirectories.

## Detection Algorithm

1. Check `.gitignore` for directory entries (lines ending in `/` that are not `node_modules/`, `.vscode/`, etc.)
2. For each gitignored directory, check if it contains a `.git` directory (indicating an independent repo)
3. If 1+ such directories are found -> **meta-repo confirmed**

```bash
# Quick detection: find gitignored subdirs with their own .git
for dir in $(grep -E '^[a-zA-Z].*/$' {project_root}/.gitignore | sed 's|/$||'); do
  if [ -d "{project_root}/$dir/.git" ]; then
    echo "SUBREPO: $dir"
  fi
done
```

## Meta-Repo Context Resolution

When meta-repo is detected, store:

- `{is_meta_repo}`: `true`
- `{meta_repo_root}`: absolute path to the parent repo (same as `{project_root}`)
- `{subrepos}`: list of detected subrepo objects, each containing:
  - `name`: directory name (e.g., `my-app`, `shared-lib`)
  - `path`: absolute path (e.g., `{project_root}/my-app`)
  - `remote_url`: from `git -C {path} remote get-url origin`
  - `default_branch`: from `git -C {path} symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||'` (fallback to `main`)
  - `current_branch`: from `git -C {path} branch --show-current`
  - `has_claude_md`: whether `{path}/CLAUDE.md` exists
  - `toolchain`: per-subrepo build system detection (run the standard detection below inside each subrepo)

## Meta-Repo Branch Strategy

In a meta-repo, branches must be coordinated across repos:

- **Meta-repo branch**: holds planning artifact changes (`_bmad-output/`, `docs/`)
- **Subrepo branches**: hold code changes (one branch per affected subrepo)

Branch naming convention:
- Meta-repo: `{batch_branch}` (e.g., `batch-stories-3-from-5-3`)
- Subrepo: `{batch_branch}` (same name, created independently in each affected subrepo)

## Meta-Repo Worktree Strategy

Git worktrees are **per-repo** — you cannot create a single worktree spanning the meta-repo and its subrepos.

**For sequential mode**: work in-place on branches (no worktrees). This is simpler because:
- Subrepos are gitignored by the parent, so parent branch operations don't affect subrepos
- Each repo switches branches independently

**For parallel mode**: create separate worktrees per-repo:
- Meta-repo worktree: `../{project_name}-story-{story_slug}` (for artifact changes only)
- Subrepo worktrees: `../{project_name}-story-{story_slug}/{subrepo_name}` — but this is complex. **Preferred approach**: in parallel mode with meta-repos, create worktrees only in the affected subrepos:
  ```bash
  # For each affected subrepo:
  cd {project_root}/{subrepo_name}
  git worktree add ../../{project_name}-{subrepo_name}-story-{story_slug} -b {worktree_branch} origin/{batch_branch}
  ```
  The meta-repo artifact changes go into a single branch (no worktree needed — artifacts don't conflict between parallel stories because each story writes to its own file).

## Story-to-Subrepo Mapping

Each story targets one or more subrepos. Determine this from:

1. **Story file `## Dev Notes`**: look for directory paths matching known subrepo names (e.g., `my-app/src/...`, `shared-lib/src/...`)
2. **Story file `## Tasks / Subtasks`**: specific file references
3. **Epic scope**: some epics are scoped to a single subrepo (e.g., "Epic 16: Infrastructure" -> `my-infra`)
4. **Sprint-status.yaml**: may have `repo:` or `package:` annotations

Store per-story:
- `affected_subrepos`: list of subrepo names this story modifies (e.g., `["my-app", "shared-lib"]`)
- If empty after analysis, default to asking the user or inferring from epic context

## Per-Subrepo Toolchain

For each subrepo in `{subrepos}`, run the standard build system detection (below) independently:
- `cd {subrepo_path}` and check for `package.json`, `Cargo.toml`, etc.
- Store results as `{subrepos[name].install_command}`, `{subrepos[name].test_command}`, etc.

The meta-repo itself typically has no build system (or just a `package.json` with convenience scripts). Its toolchain detection result is stored separately as `{meta_toolchain}`.

## Single-Repo Fallback

If meta-repo detection finds 0 subrepos -> set `{is_meta_repo}: false` and proceed with standard single-repo behavior. All subsequent meta-repo-specific logic is skipped.

---

# Build System & Toolchain Detection

Detect the project's build system and resolve commands. Check in this order:

## Node.js projects (`package.json` exists)

- Read `package.json` to inspect `scripts` keys
- **Package manager**: `pnpm-lock.yaml` -> pnpm, `yarn.lock` -> yarn, `bun.lockb` -> bun, else -> npm
- **Install**: `{pm} install`
- **Test**: `{pm} test` (if `scripts.test` exists)
- **Lint**: `{pm} run lint` (if `scripts.lint` exists)
- **Typecheck**: `{pm} run typecheck` (if `scripts.typecheck` exists)
- **E2E (Playwright)**: detect via `scripts.test:e2e`, `scripts.e2e`, or `@playwright/test` in devDependencies -> `{pm} run test:e2e` or `npx playwright test`
- **Color suppression**: `NO_COLOR=1` prefix for all test/lint/typecheck commands (vitest, jest, and most Node tools respect this)

## Rust projects (`Cargo.toml` exists)

- **Install**: `cargo build`
- **Test**: `cargo test`
- **Lint**: `cargo clippy`
- **Typecheck**: (implicit in `cargo build`)

## Go projects (`go.mod` exists)

- **Install**: `go mod download`
- **Test**: `go test ./...`
- **Lint**: `golangci-lint run` (if installed)
- **Typecheck**: `go vet ./...`

## Python projects (`pyproject.toml` or `setup.py` exists)

- **Install**: `pip install -e .` or `poetry install`
- **Test**: `pytest`
- **Lint**: `ruff check .` or `flake8`
- **Typecheck**: `mypy .` or `pyright`
- **E2E (Playwright)**: `playwright` in dependencies -> `pytest --browser chromium` or `python -m pytest tests/e2e/`

## Makefile projects (`Makefile` exists, no other match)

- Parse Makefile for `test`, `lint`, `typecheck`, `e2e` targets

Store resolved commands as:
- `{install_command}`, `{test_command}`, `{lint_command}`, `{typecheck_command}`, `{e2e_command}` (or `SKIP` if not detected)

---

# Test Execution Protocol

Based on detected toolchain, resolve the test execution protocol:

## For Node.js (vitest/jest)

- **Color suppression**: `NO_COLOR=1` prefix on ALL test commands — vitest v4 ignores `CI=true` for disabling colors. Without `NO_COLOR=1`, output contains ANSI escape codes that make grep patterns return empty results.
- **Targeted tests**: `NO_COLOR=1 {pm_exec} vitest run src/path/to/changed.test.ts 2>&1 | tail -20` (or `jest` equivalent)
- **Full suite — save output for multi-pass analysis:**
  ```bash
  NO_COLOR=1 {test_command} 2>&1 > /tmp/{project_name}-test-out; tail -40 /tmp/{project_name}-test-out
  ```
  Keep `/tmp/{project_name}-test-out` until all analysis is complete — grep it freely without re-running. Remove when done: `rm /tmp/{project_name}-test-out`
- **Investigate without re-running:** `grep -E "FAIL|Error" /tmp/{project_name}-test-out`
- **Re-run legitimately after fixes** (overwrites saved output): same command as above
- **NEVER re-run just to try a different grep pattern** — grep the saved file instead.

## For Rust/Go/Python

- **Targeted tests**: language-specific targeted test syntax (e.g., `cargo test test_name`, `go test ./pkg/...`, `pytest tests/test_specific.py`)
- **Full suite**: `{test_command} 2>&1 > /tmp/{project_name}-test-out; tail -40 /tmp/{project_name}-test-out`
- Same grep-don't-rerun protocol as above.

---

# Playwright E2E Detection & Protocol

## Detection (check in order)

1. `playwright.config.ts` or `playwright.config.js` exists -> Playwright confirmed
2. `package.json` has `@playwright/test` in devDependencies -> Playwright confirmed
3. `pyproject.toml` has `playwright` dependency -> Python Playwright confirmed
4. None found -> `{e2e_command}` = `SKIP`

## Playwright commands (when detected)

- **Node.js**: `NO_COLOR=1 npx playwright test 2>&1 | tail -40` (or `{pm} run test:e2e` if script exists)
- **Python**: `python -m pytest tests/e2e/ --browser chromium 2>&1 | tail -40`
- **Install browsers** (include in worktree setup if Playwright detected):
  ```bash
  npx playwright install --with-deps chromium
  ```
  (or `playwright install chromium` for Python)
- **On failure**: Playwright generates HTML reports. After a failure:
  ```bash
  # Check for report
  ls {worktree_path}/playwright-report/ 2>/dev/null && echo "Playwright HTML report available"
  # Check for traces
  ls {worktree_path}/test-results/ 2>/dev/null && echo "Playwright traces available"
  ```

## E2E execution timing

- E2E tests run ONCE after the full unit test suite passes (not after every change)
- E2E failures are **non-blocking for Step 4** but reported — the code review (Step 5) should flag E2E-relevant issues
- E2E is **blocking in Step 6** (fix phase) — if E2E was attempted and failed, the fix phase must address it

Store: `{e2e_command}`, `{e2e_install_command}`, `{has_playwright}` (boolean)
