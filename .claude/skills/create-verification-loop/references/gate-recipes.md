# Gate recipes by ecosystem

## Any ecosystem: the procedure (the sections below are worked examples, not a dependency)

1. **Commands come from the repo.** The gate's `check` lines wrap what the manifest, Makefile,
   README or CI already run: its lint, its type check, its tests, its build. Add nothing but the
   scans. Unknown tool: read its `--help` for a JSON/JUnit/XML reporter flag, or capture its
   stdout to `.verify/<name>.txt`.
2. **Figures come from the runner's own output.** `figures.sh` reads JUnit XML (most runners can
   emit it), vitest/jest JSON, lcov, cobertura and istanbul. For anything else use the two generic
   readers: `count-regex FILE ERE` (sum of a captured number, e.g. `'([0-9]+) passed'`) and
   `pct-regex FILE ERE` (the last captured number, e.g. `'TOTAL.* ([0-9.]+)%'`). No new reader
   needs to be written into the skill for a new language.
3. **Scans are text.** `scan-gate.sh` with POSIX ERE patterns for this language's skip, focus,
   todo and retry spellings; `max-lines.sh`. Find the spellings with `grep -rn skip <test dir>`
   and the runner's docs.
4. **The rest is identical everywhere**: fingerprint, ratchet, hooks, init stamp, PR path, CI.

What counts as an existing check: any command whose tool is already a dependency or config of the
repo (ruff installed → `ruff format --check` is existing, even if no script names it), plus the
scans. A new tool (knip, vulture, brakeman) is a follow-up unless the interview found it.

What goes into `fast_checks()`, `full_checks()` and `figures()` in `scripts/verify.sh`, and
what `init.sh`, the init guard and the fingerprint need, per ecosystem. Use what the repo
already has; add a tool only when the interview found nothing for a column. Every test command
writes a machine-readable report into `.verify/` so `figures()` can count it.

Columns: **lint**, **types**, **tests** (with report), **coverage** (with report), **dead
code / boundaries**, **build**, **test count**, **coverage figure**.

## Node (npm, pnpm, yarn, bun)

```bash
# fast
check lint      <pm> run -s lint                       # eslint / biome check --error-on-warnings .
check typecheck <pm> run -s typecheck                  # tsc --noEmit / tsc -b
check tests     npx vitest run --reporter=default --reporter=json --outputFile=.verify/tests.json
#               npx jest --ci --json --outputFile=.verify/tests.json
check knip      npx knip                               # dead exports/files/deps, held at zero
check boundaries npx depcruise --config .dependency-cruiser.cjs --output-type err src
# full
check coverage  npx vitest run --coverage --coverage.reporter=json-summary --coverage.reportsDirectory=.verify/coverage --reporter=json --outputFile=.verify/tests.json
check build     <pm> run -s build
check e2e       npx playwright test --reporter=list,json   # PLAYWRIGHT_JSON_OUTPUT_NAME=.verify/playwright.json
# figures
floor tests.total     "$(scripts/figures.sh count-vitest .verify/tests.json)"
floor coverage.lines  "$(scripts/figures.sh coverage-istanbul .verify/coverage/coverage-summary.json lines)"
```
`<pm>` is `npm`, `pnpm`, `yarn` or `bun` as the lockfile says (`package-lock.json`,
`pnpm-lock.yaml`, `yarn.lock`, `bun.lock*`). Install exactly: `npm ci`, `pnpm install
--frozen-lockfile`, `yarn install --immutable` (Berry) or `--frozen-lockfile` (classic), `bun
install --frozen-lockfile`. Pin: `.nvmrc` or `mise.toml`, and `engines.node`. Fingerprint
machine inputs: `.env`, `node_modules/.package-lock.json` (npm) or `node_modules/.modules.yaml`
(pnpm), `node --version`. Retry patterns to scan: `retry`, `retries` in vitest, jest, Playwright
configs and `--retry`/`--retries` on commands.

## Python (uv, poetry, pip)

```bash
# fast
check lint      uv run ruff check .                    # or: flake8 / pylint
check format    uv run ruff format --check .
check types     uv run mypy                            # or: uv run pyright
check tests     uv run pytest -q --junitxml=.verify/junit.xml
# full
check coverage  env COVERAGE_FILE=.verify/.coverage uv run pytest -q --junitxml=.verify/junit.xml --cov --cov-report=xml:.verify/coverage.xml --cov-report=term
#               COVERAGE_FILE keeps coverage.py's data file out of the tree (it would move the fingerprint)
# figures
floor tests.total     "$(scripts/figures.sh count-junit .verify/junit.xml)"
floor coverage.lines  "$(scripts/figures.sh coverage-cobertura .verify/coverage.xml)"
```
Runner prefix: `uv run`, `poetry run`, or the venv's bin. Install exactly: `uv sync --frozen`,
`poetry install --sync`, `pip install -r requirements.txt` (with a lock or `pip-compile`
output). Pin: `.python-version`, `requires-python`. Fingerprint: `.env`, `uv.lock`/`poetry.lock`
are tracked already; add `python3 --version` and the venv's marker (`.venv/pyvenv.cfg`).
Markers to scan: `@pytest.mark.skip`, `pytest.skip(`, `@unittest.skip`, `xfail`. Note `uv run` and
`poetry run` install dependencies on their own, so a fresh worktree can skip `init.sh` without the
init guard seeing an install; the guard still catches `uv sync`, `uv add` and `pip install`, and
AGENTS.md says `init.sh` first. Don't try to block `uv run`: the gate itself uses it. Retries:
`pytest-rerunfailures` (`--reruns`, `flaky`), `@pytest.mark.flaky`. Dead code: `vulture`
(treat as a ceiling at first).

## Ruby (Bundler, Rails)

```bash
# fast
check lint      bundle exec rubocop --format simple
check security  bundle exec brakeman -q --no-pager --skip-checks EOLRails   # Rails. Never bin/brakeman: its --ensure-latest
#               hits the network, and EOLRails is a date check: both break P4. Run them on a schedule, not in the gate
check tests     bundle exec rspec --format progress --format RspecJunitFormatter --out .verify/junit.xml
#               bash -c 'bin/rails test 2>&1 | tee .verify/minitest.txt'   # minitest: the summary line is the report
# full
check coverage  COVERAGE=1 bundle exec rspec ...       # simplecov writes coverage/.last_run.json and coverage/lcov/*.info with simplecov-lcov
check migrations bin/rails db:migrate:status           # or a check that schema.rb matches the migrations
check assets    bin/rails assets:precompile            # when the app ships assets
# figures
floor tests.total     "$(scripts/figures.sh count-junit .verify/junit.xml)"      # rspec
floor tests.total     "$(scripts/figures.sh count-minitest .verify/minitest.txt)" # minitest
floor coverage.lines  "$(scripts/figures.sh coverage-lcov coverage/lcov/project.lcov)"
```
Install exactly: `bundle install` (the lockfile is authoritative) and `yarn install
--frozen-lockfile` when the app has a JS side. Fingerprint exclusions: Rails tracks `tmp/`,
`log/`, `storage/` and may track `db/*.sqlite3`; exclude them or no run matches its start. Services: `bin/rails db:prepare` after Postgres
or MySQL is reachable; per-worktree database names via `DATABASE_URL` or `database.yml` ERB.
Pin: `.ruby-version`, `Gemfile` `ruby` line. Markers: `skip`, `pending`, `xit`, `fit`,
`focus: true`. Retries: `rspec-retry`, `retry:` metadata, `Minitest::Retry`. Note the
gate must set `RAILS_ENV=test`; a test that needs a browser (system tests) belongs to the full
tier only.

## Go

```bash
check vet       go vet ./...
check lint      golangci-lint run                     # when configured
check build     go build ./...
check tests     bash -c 'go test -json ./... > .verify/go-test.json'
check coverage  bash -c 'go test -coverprofile=.verify/cover.out ./... && go tool cover -func=.verify/cover.out | tail -1 > .verify/cover.txt'
floor tests.total     "$(scripts/figures.sh count-go .verify/go-test.json)"
floor coverage.lines  "$(sed -nE 's/.*total:.*[[:space:]]([0-9.]+)%/\1/p' .verify/cover.txt)"
```
Install: `go mod download`; pin: `go` line in `go.mod`, `toolchain`. Markers: `t.Skip(`,
`t.Skipf(`. Retries: `-count` greater than 1 for flake hunting is fine; a retry wrapper is not.

## Rust

```bash
check fmt       cargo fmt --check
check clippy    cargo clippy --all-targets -- -D warnings
check tests     bash -c 'cargo test 2>&1 | tee .verify/cargo-test.txt'
check coverage  cargo llvm-cov --lcov --output-path .verify/lcov.info   # when installed
floor tests.total     "$(scripts/figures.sh count-cargo .verify/cargo-test.txt)"
floor coverage.lines  "$(scripts/figures.sh coverage-lcov .verify/lcov.info)"
```
Pin: `rust-toolchain.toml`. Markers: `#[ignore]`, `todo!(`, `unimplemented!(`.

## JVM (Maven, Gradle)

```bash
check build-and-tests ./mvnw -q -B verify             # surefire writes target/surefire-reports/*.xml
#                     ./gradlew check                   # build/test-results/test/*.xml
floor tests.total "$(for f in target/surefire-reports/TEST-*.xml; do scripts/figures.sh count-junit "$f"; done | awk '{s+=$1} END{print s}')"
floor coverage.lines "$(scripts/figures.sh coverage-cobertura target/site/cobertura/coverage.xml)"   # or jacoco's XML via a small python line
```
Markers: `@Disabled`, `@Ignore`. Retries: surefire `rerunFailingTestsCount`, gradle
`retry` plugin.

## .NET

```bash
check build     dotnet build --nologo -warnaserror
check tests     dotnet test --no-build --logger "junit;LogFilePath=.verify/junit.xml"   # JunitXml.TestLogger
check coverage  dotnet test --no-build --collect:"XPlat Code Coverage" --results-directory .verify/coverage   # cobertura XML
```
Markers: `[Skip`, `Skip =`. Retries: `[Retry(` attributes.

## PHP (Composer; Laravel, Symfony)

```bash
# fast
check lint      vendor/bin/pint --test                    # Laravel; or: vendor/bin/php-cs-fixer fix --dry-run --diff
check types     vendor/bin/phpstan analyse --no-progress  # or: vendor/bin/psalm --no-progress
check tests     vendor/bin/phpunit --log-junit .verify/junit.xml
#               php artisan test --log-junit .verify/junit.xml   # Laravel wrapper (same report)
# full
check coverage  bash -c 'XDEBUG_MODE=coverage vendor/bin/phpunit --log-junit .verify/junit.xml --coverage-cobertura .verify/coverage.xml'
#               needs xdebug or pcov; without either, list coverage as a follow-up
check deps      composer validate --strict
# figures
floor tests.total     "$(scripts/figures.sh count-junit .verify/junit.xml)"
floor coverage.lines  "$(scripts/figures.sh coverage-cobertura .verify/coverage.xml)"
```
Install exactly: `composer install --no-interaction --prefer-dist` (the lockfile is
authoritative). Pin: `composer.json` `config.platform.php`, `.tool-versions`/`mise.toml`.
Services: `php artisan migrate --force` (Laravel) or `bin/console doctrine:migrations:migrate -n`
(Symfony) after the database answers; per-worktree database via `DB_DATABASE`/`DATABASE_URL`.
Markers: `markTestSkipped(`, `markTestIncomplete(`, `@group skip`, `#[Skip`. Retries: a
`@retry` annotation or `phpunit-retry` package. Machine inputs: `.env`, `vendor/composer/installed.json`.
Note: the gate must run with `APP_ENV=testing` (Laravel) or `APP_ENV=test` (Symfony).

## React Native (Expo or bare; a Node repo with platform builds)

```bash
# fast (what the Stop hook runs: no simulator, no native build)
check lint      <pm> run -s lint                          # eslint
check typecheck npx tsc --noEmit
check tests     npx jest --ci --json --outputFile=.verify/tests.json
check doctor    npx expo-doctor                           # Expo only; checks dependency compatibility
# full
check coverage  npx jest --ci --coverage --coverageReporters=json-summary --coverageDirectory=.verify/coverage --json --outputFile=.verify/tests.json
check bundle    npx expo export --platform ios --output-dir .verify/export   # Expo: the JS bundle builds
#               npx react-native bundle --platform android --dev false --entry-file index.js --bundle-output .verify/android.bundle   # bare
check e2e       maestro test .maestro/                    # or: detox test -c ios.sim.release; needs a simulator: full tier only, and
#                                                         # CI only where a macOS runner exists; otherwise "proposed, not run" in the PR
# figures
floor tests.total     "$(scripts/figures.sh count-vitest .verify/tests.json)"     # jest's JSON has the same numPassedTests field
floor coverage.lines  "$(scripts/figures.sh coverage-istanbul .verify/coverage/coverage-summary.json lines)"
```
Install as for Node; `init.sh` also runs `npx pod-install` (bare, macOS) and, for Expo,
`npx expo install --check` is a check, not an install. Markers: `it.skip`, `xit`, `xdescribe`,
`test.todo`. Retries: `jest.retryTimes(`, Detox `--retries`, Maestro `retry` blocks; the
no-retries pattern should include `retryTimes\(`. Native builds (`xcodebuild`, `gradlew
assemble`) are slow and machine-specific: keep them out of `fast`, put the JS bundle export in
`full`, and leave the real build to CI or a release workflow. The verify (drive-the-app) skill
drives a simulator with Maestro or Detox and keeps screenshots; `pstack:create-verification-skill`
handles that when installed.

## Any ecosystem: the scans

```bash
check no-markers scripts/scan-gate.sh no-markers '<pattern for this language, above>' <src dirs> <test dirs>
check no-retries scripts/scan-gate.sh no-retries '(^|[^[:alnum:]_])(retry|retries|reruns|flaky)[[:space:]]*[:=(]|retryTimes\(|--(retry|retries|reruns)([^[:alnum:]_]|$)' '*.config.*' package.json pyproject.toml pytest.ini .github/workflows
check no-sleeps  scripts/scan-gate.sh no-sleeps 'time\.sleep\(|Thread\.sleep\(|setTimeout\([^,]*,[[:space:]]*[0-9]{3,}|sleep [0-9]' <test dirs>
# POSIX ERE only: no \b, \s, \d (Apple's git grep matches nothing for them; scan-gate.sh refuses them).
# Date- and network-dependent checks (EOL warnings, --ensure-latest, audit databases) are not gate
# checks: run them on a schedule and fail the gate on nothing a calendar or a server can change.
check max-lines  scripts/max-lines.sh 400 <src dirs> <test dirs>
ceiling markers      "$(scripts/figures.sh count-problems .verify/no-markers.json)"   # when hits exist today, a ceiling; else a hard check
```

## Services the gate needs

Probe before running and start when local (`docker compose up -d <svc>`), with a bounded wait;
report a remote one. Per worktree: derive the database name or data directory from the
checkout path (a short hash), so two checkouts verify at once. Never a paid credential inside
the gate: the extractor, the LLM, the third-party API get a fixture or stub provider forced by
`verify.sh` whatever `.env` says.

## Pre-commit hooks (optional, fast only)

lefthook or pre-commit on staged files: the formatter and a secrets scan (`gitleaks protect
--staged`). Never the full gate in pre-commit; the Stop hook and CI own that.
