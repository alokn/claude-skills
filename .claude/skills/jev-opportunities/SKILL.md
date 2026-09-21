---
name: jev-opportunities
description: >
  Use when asked where jev (TypeSafe AI's System One model) could be used in a codebase, to audit or scan a
  repo for jev / TypeSafe opportunities, to assess replacing LLM calls, regex heuristics, keyword rules,
  embedding thresholds, or manual review queues with typed AI decisions, or to find AI-powered product
  features and SDLC/CI automation a repo could add. Works on any repo and language; produces a ranked,
  evidence-cited report file.
argument-hint: "[path] [--quick|--deep] [--focus replace|feature|sdlc] [--out file.md]"
---

# Jev opportunity scan

You are the **orchestrator and judge**. Parallel scanner subagents find candidates; a validator script
checks their evidence; you apply the fit rubric, rank, and write one report file. The reader must be able
to open any cited line and see exactly what the finding describes, paste any primitive sketch into the
TypeSafe Playground, and trust that nothing proposed is a task jev cannot do.

Jev in one line: text state in, typed calibrated decisions out (Choice / Score / Noul), ~100 ms,
$0.042 per million input tokens, output free, no generation, no math, no dates. Full facts:
`references/jev-primer.md`. Read it before dispatching anything.

## Why this process exists (observed failures without it)

An unguided agent asked the same question produced: a top "replace" recommendation for a value that was a
user-supplied request parameter, not an AI output (it never opened the call site); jev proposed for
day-count archiving and HTTP-status retry routing (arithmetic and deterministic logic, both explicit jev
failure modes); file paths with no line numbers or snippets; no question designs; no ranking; no cost
inputs; no rejected-candidates section; nothing written to disk; the search endpoint and an existing
duplicate-tracking field missed entirely. Every step below closes one of those gaps. Do not skip steps.

## Arguments

`$ARGUMENTS` may contain: a repo path (default: cwd), `--quick` (one scanner, hotspots only, ~10 min),
`--deep` (Opus scanners, module split, more time), `--focus replace|feature|sdlc` (single lens),
`--out <file>` (default `<repo>/jev-opportunities.md`; this report is the only file the run writes
into the target repo, and scanners write nothing there), `--probe` (offer a live smoke test; see step 6).
Depth default is standard: three Sonnet scanners, one per lens.

## Workflow

### Step 0: Setup

```bash
SKILL_DIR=<absolute path of this skill directory>
REPO=<absolute repo path>
WORK=<scratchpad dir>/jev-scan-$(date +%s); mkdir -p "$WORK"
# files this run produces: $WORK/orient.md, $WORK/domain.md, $WORK/findings-<lens>.json, $WORK/findings.validated.json
```
Read `references/jev-primer.md` and `references/fit-rubric.md` yourself now. You will judge with them.
If WebFetch is available, apply the primer's freshness rule: fetch the live models and jaggedness pages and
note the current jev version for the report. If the official TypeSafe plugin is installed
(`~/.claude/plugins/**/typesafe-ai/SKILL.md` exists), scanners may read it too; it does not replace steps 1-5.

### Step 1: Orient (deterministic, ~1-2 min; slower without ripgrep)

```bash
bash "$SKILL_DIR/scripts/orient.sh" "$REPO" > "$WORK/orient.md"
for L in A B C; do bash "$SKILL_DIR/scripts/orient.sh" "$REPO" --lens $L > "$WORK/orient-$L.md"; done
```
The `--lens` files are ready-to-paste excerpts for the scanner prompts. Speed: the script uses ripgrep
only if the `rg` binary is on PATH inside bash (a zsh alias does not count); `brew install ripgrep`
makes it about 10x faster on large repos.
Then read `$WORK/orient.md` and the repo's README / CLAUDE.md / AGENTS.md (first ~150 lines each).
Write a **mental model** paragraph in `$WORK/domain.md`: what the product does, who uses it, which
objects carry free text and their lifecycle (create -> triage -> resolve), existing AI/ML with file
references, existing review/approval queues, CI shape. This paragraph goes into every scanner prompt and
into the report. If the orientation shows the repo is a library or CLI with no user text flowing through
it, say so; lenses B and C still apply (SDLC almost always does).

### Step 2: Plan the fan-out

| Repo size (tracked source files) | Standard | `--deep` | `--quick` |
|---|---|---|---|
| < 1,500 | 3 agents: A, B, C | 3 agents, Opus | 1 agent, all lenses, hotspots only |
| 1,500 - 6,000 | 3 agents | A and B split by top 2 module groups + C = 5 agents, Opus | 1 agent |
| > 6,000 | A, B split by module group (max 3 each) + C = up to 7 agents | same, Opus | 1 agent |

Lenses: **A replace** (existing LLM calls, heuristics, rules, queues, search, dedup), **B feature**
(free-text surfaces with no judgement applied), **C sdlc** (CI, PR/issue flow, tests, logs, agent
harness including the repo's own `.claude/` skills and hooks, i18n, docs). Module groups come from the second-level directory list in `orient.md`; give each
scanner explicit `SCOPE_PATHS`. Scanner model: Sonnet by default, Opus for `--deep`.

### Step 3: Dispatch scanners in parallel

Build each prompt from `references/scanner-prompt.md`, filling every placeholder:
`{LENS}`, `{LENS_DESCRIPTION}`, `{LENS_CODE}` (A/B/C), `{SCOPE_PATHS}`, `{REPO_ROOT}`, `{SKILL_DIR}`,
`{ORIENT_EXCERPT}` (paste `$WORK/orient-<lens>.md`), `{DOMAIN_SUMMARY}`
(your paragraph), `{OUT_FILE}` (`$WORK/findings-<lens>[-<group>].json`), `{BUDGET_MINUTES}` (15 standard,
25 deep, 10 quick). Send all Agent calls in **one message** so they run concurrently. Do not scan
yourself while they run. Do not spin on no-op turns either: arm the Monitor tool (or a background
`until [ -f "$WORK/findings-C.json" ]; do sleep 20; done` loop) on the output files and yield until the
completion notifications arrive.

### Step 4: Validate (mechanical, non-negotiable)

```bash
python3 "$SKILL_DIR/scripts/validate_findings.py" "$REPO" "$WORK"/findings-*.json --out "$WORK/findings.validated.json"
```
Read the report it prints. It drops findings whose file/line/snippet do not exist in the repo, whose
primitive sketch is malformed (Choice < 2 or > 255 options, Score outside 2-10 levels), or whose
*question instructions* ask jev to generate, count, or compare dates with no `rewrite`. Disqualifier words
in the prose produce `ADJUDICATE` warnings, not drops: you decide in Step 5.2 whether that part is done in
code. It also merges near-duplicate findings (same primary file within 10 lines, across lenses; the merged
ids are kept under `_merged_ids`) and downgrades confidence when some evidence failed. Where a snippet
was found near but not at the cited line, the validator rewrites the line number and warns; the report
must use the corrected number. The
output JSON has three arrays: `findings`, `validator_rejected`, and `scanner_rejected` (the candidates the
scanners themselves turned down); the last two feed the "Considered and rejected" table.
If a scanner's output was mostly dropped for fixable reasons (wrong line numbers, malformed sketches),
**resume that same scanner with SendMessage** and paste the validator's warnings; do not spawn a fresh
full scan. Tell it to fix evidence, not to reword prose around the disqualifier screen.

### Step 5: Judge and write

For every accepted finding, before it enters the report:

1. **Open the primary evidence line yourself** (Read the file around it). Re-derive the exact line
   number for every snippet you cite; the validator tolerates a 3-line window, the report must not.
   Confirm the mechanism and the input-vs-output direction. A finding that proposes replacing a
   user-supplied parameter is deleted.
2. **Re-run the fit test** from `fit-rubric.md`. Check the counter-signals: lexical match, arithmetic,
   temporal, generation, safety invariant, correct deterministic rule already present. Move failures to
   "Considered and rejected" with the reason.
3. **Check the primitive sketch**: one judgement per question, contrastive criteria, `other`/`none` where
   needed, state limited to needed fields, a stated low-confidence path. Fix or tighten it; you may improve
   scanner sketches but not invent evidence.
4. **Check the numbers**: cost line has inputs and method; volume is sourced or marked unknown; no
   accuracy claims. If a finding replaces an existing **priced API call whose provider and model are
   fixed in the repo**, look up that provider's current price (provider docs, or the `claude-api` skill
   for Anthropic models); never recall prices from memory. If the provider is instance-configurable, or
   the incumbent is an agent session or a heuristic, write "incumbent price not fixed by the repo" and
   stop; do not spend tokens pricing a hypothetical.
5. **Merge** findings that share a state into one speculative fan-out call; note the merge.
6. **Assign the bucket** with the rules in `fit-rubric.md` (Do first / Plan / Quick wins / Later).
7. **Cut to size.** A standard run ships 8-12 findings. Merge shared-state findings first; then drop the
   weakest by impact and fit, moving them to "Considered and rejected" with the reason "lower priority
   than the shipped set". A page of one-liners is a failure; so is 25 findings nobody will read.

Then write the report to the output path following `references/report-template.md` **exactly**: summary,
top table, mental model, findings by bucket, mandatory "Considered and rejected" table, cross-cutting
recommendations (where question constants live, labelled data for calibration, batching, what stays
deterministic), coverage and limits, next steps. Cite only validated evidence.

### Step 6: Optional live probe (`--probe`, or if the user asks)

Only if `TYPESAFE_API_KEY` is set **and** the user confirms sending sample data to api.typesafe.ai: pick
the top 1-2 findings, take 5-10 real examples from the repo's fixtures or test data (never production
secrets or PII), run the sketch with the Python or JS SDK, and add an "Observed" line (answers, confidence
spread, latency, input tokens) to those findings. Otherwise skip this step and say so in the report.

### Step 7: Report back

Tell the user: the report path, the top 3-5 findings in one line each (ID, title, bucket, why), how many
candidates were rejected and the most instructive rejection, and what was not verified. No restating of
the process.

## Judgement rules you apply as orchestrator

- **Evidence or it does not exist.** File paths without line numbers, snippets you did not see, or files
  you did not open never reach the report.
- **Direction check.** Before any "replace" finding: is the value an output the code decides, or an input
  someone provides? Only outputs are replaceable.
- **Jev is not a better LLM.** Do not propose it for generation. Do not propose it for arithmetic, counting,
  or date comparison. Do not propose it to replace a correct deterministic rule. Do not claim accuracy
  gains or consistency gains (Haiku 4.5 at temperature 0 out-repeated jev in TypeSafe's own cookbook);
  claim speed, cost, schema safety, calibrated confidence, and validate accuracy in rollout.
- **Every finding has a low-confidence path.** If the scanner did not design one, you do.
- **Every finding has a rollout** that starts in shadow mode, keeps the fallback and any deterministic
  invariant, and retires only the redundant heuristic once measured gates are met.
- **Fewer, deeper findings** beat a long list. Ten well-evidenced findings with sketches are the target for
  a standard run; a page of one-liners is a failure.
- **"Considered and rejected" is mandatory** and should teach the reader where jev does not fit in their
  code.
- **No repo has zero findings.** If lenses A and B are genuinely empty (pure library, no text), lens C
  still yields CI, PR, issue, and agent-harness opportunities; say clearly that product lenses were empty.

## Red flags: stop and correct

| Thought | Reality |
|---|---|
| "The scanner's file paths look right, skip the validator" | Baseline hallucinated a file and mis-read an input as an output. Run it. |
| "Jev is 100x cheaper, so every LLM call should move" | Generation calls stay. Only the decision-shaped parts move. |
| "Smarter staleness / overdue / retry logic" | Dates, arithmetic, status codes are code. Rejected table. |
| "No LLM calls here, nothing to find" | Lenses B and C do not need existing AI. Heuristics, queues, CI, intake. |
| "I'll estimate monthly savings" | Not without a sourced volume and a looked-up current price. Per-call otherwise. |
| "Jev will be more accurate than the regex" | Unknown until shadow mode. Public evals: mid-tier accuracy, superior abstention. |
| "The report is long enough, skip rejected" | The rejected table is the credibility of the whole report. |
| "Write findings in chat, the user can copy" | The deliverable is the file at the output path. |

## Files in this skill

| File | Purpose |
|---|---|
| `references/jev-primer.md` | Verified facts: API, primitives, limits, price, failure modes, patterns, cookbooks |
| `references/detection-signals.md` | Code signals per lens, counter-signals, grep cheatsheet |
| `references/fit-rubric.md` | Fit test, disqualifier rewrites, scoring, buckets, estimation, rollout, evidence rules |
| `references/scanner-prompt.md` | Subagent prompt template and findings JSON schema |
| `references/report-template.md` | Exact report and finding format |
| `scripts/orient.sh` | Deterministic repo survey and hotspot greps |
| `scripts/validate_findings.py` | Evidence, schema, disqualifier, and dedupe gate |

This skill finds and ranks; it does not build. TypeSafe's own example prompt ("explore the project and
find opportunities for intelligent judgement") run through their knowledge skill gives a brainstorm; this
skill gives an audit with verified evidence, a rejected table, and a written report. Implementation after
the scan is a different job: the official TypeSafe skill
(`claude plugin marketplace add typesafe-ai/skills` then `claude plugin install typesafe@typesafe-ai`)
carries live docs, SDK usage, and cookbooks. Point the user there for building.
