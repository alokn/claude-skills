# jev-opportunities (developer notes)

A Claude Code skill that scans any repository and produces a ranked, evidence-cited report of where
**jev** (TypeSafe AI's System One model) could (a) replace existing logic to be faster, cheaper, or more
robust, (b) power new product features, and (c) improve the SDLC. The deliverable is a Markdown file in
the target repo; nothing in the repo is modified.

## Usage

```
/jev-opportunities                          # scan cwd, standard depth, writes ./jev-opportunities.md
/jev-opportunities ../other-repo --deep     # Opus scanners, module split
/jev-opportunities --quick --focus sdlc     # one scanner, CI/dev-workflow only
/jev-opportunities --out docs/jev.md --probe
```
Or in prose: "find jev opportunities in this repo", "where could we use TypeSafe here".

Prerequisites: `python3` for the validator. `ripgrep` is optional but makes the orientation survey ~10x
faster on large repos. `TYPESAFE_API_KEY` is only needed for the optional `--probe` step, which asks for
confirmation before sending any sample data to the API.

## How it works

```
orient.sh  ->  mental model  ->  N parallel scanners (Sonnet/Opus)  ->  validate_findings.py  ->  judge  ->  report
 (grep)        (orchestrator)     one per lens: replace/feature/sdlc     evidence + schema gate    (orchestrator)
```

- **Orchestrator** (the model running the skill) owns judgement: fit test, direction check, ranking, the
  rejected table, and the final write. It re-reads the primary evidence line of every accepted finding.
- **Scanners** are disposable subagents with a strict JSON contract (`references/scanner-prompt.md`).
  They must open every file they cite and record a verbatim snippet.
- **Validator** is the anti-hallucination gate: it drops findings whose `file:line:snippet` does not
  exist in the repo, whose primitive sketch is malformed, or whose proposal smells like generation, math,
  or date comparison without a bounded rewrite. It also merges near-duplicates.

## Why it looks like this

Built with the TDD-for-skills process (superpowers:writing-skills). The RED baseline ran a Sonnet agent on
the Plane repo (makeplane/plane, Django + Next.js, ~5,200 files) with a plain "find jev opportunities"
prompt and no skill. Observed failures, each of which maps to a step or rule in `SKILL.md`:

| Baseline failure | Counter in this skill |
|---|---|
| Top "replace" finding targeted `casual_score`, a request parameter the user sets, not an LLM output | Direction check in Step 5; evidence rule in `fit-rubric.md`; validator requires a real snippet |
| Proposed jev for archive-after-N-days and webhook retry-vs-drop on HTTP status | Disqualifier table and counter-signals; validator screens date/math words without a `rewrite` |
| File paths only, no line numbers or snippets | JSON evidence schema; validator rejects unverifiable evidence |
| No question designs, no confidence gating, no rollout | Required `primitive_sketch`, `confidence_gating`, `rollout` fields; question-design checklist |
| No ranking, no effort, no cost inputs; repeated "40-200x" from the launch post | Scoring fields, priority buckets, estimation method that requires inputs and forbids accuracy claims |
| No rejected-candidates section | Mandatory "Considered and rejected" table fed by scanner rejects + validator drops |
| Missed the search endpoint and the existing `duplicate_to` intake field | `orient.sh` hotspot greps for search/ranking and review/triage queues; lens B scanner |
| Report only in chat | Report written to a file; chat gets a short summary |

## Measured against alternatives (Plane repo, 2026-09-19/20)

Four runs on the same repo, citations checked by script against the source, not self-reported.

| | No skill (Sonnet) | Official TypeSafe skill + their prompt (Sonnet) | Official skill + their prompt (Opus) | This skill, v1 (Opus + 3 Sonnet scanners) | This skill, after fixes (same) |
|---|---|---|---|---|---|
| Wall time | 2 min | 7 min | 14 min | 25 min | 25 min |
| Findings shipped | ~13 ideas | 7 | ~25 | 16 | 9 (12 validated, 3 merges) |
| File paths cited, all exist | 10/10 | 17/17 | 58/58 | 40/40 | 34/34 |
| Line refs in range | 0 | 8/8 | 44/44 | 42/42 | 31/31 |
| Verbatim snippet verified at the line | 0 | 0/2 | 0/2 (off by up to 15 lines) | 42/42 | 26/26 |
| Input-vs-output errors | 1 | 0 | 0 | 0 | 0 (caught one in judging) |
| Jev failure-mode proposals (math/dates/generation) | 2 | 0 | 0 | 0 | 0 |
| Question designs | 0 | 0 | 5 | 30 | 18 |
| Impact/effort/fit/confidence per finding | none | effort only | effort only | all | all |
| Cost with inputs and method | none | 1 figure | 8 figures | 33, per-call | 21, per-call |
| Rollout / shadow-mode plan | none | none | 1 paragraph | every finding | every finding |
| "Considered and rejected" | 1 item | 0 | 9 items | 28 | 28 |
| Found search rerank, unused `duplicate_to`, i18n QA gap | no / no / no | yes / yes / no | yes / yes / yes | yes / yes / yes | yes / yes / yes |
| Found the NL-to-filter-AST feature, repo bugs | no | no | yes | no | no |
| Validator passes needed | n/a | n/a | n/a | 2 (dates regex bug) | 1 |

Reading: with Opus, TypeSafe's knowledge skill produces a strong, insightful report and found two things this
skill did not. This skill wins on verification (every snippet checked), decision-readiness (scoring,
gating, cost inputs, rollout, rejected table), a stable format, and robustness with cheaper scanner models.
The two compose: run this to find and rank, the official skill to build.

## Maintenance

- `references/jev-primer.md` pins facts to **jev-1.13.0 as of 2026-09-19** (price $0.042/Mtok input,
  64k/32k context, 255 Choice options, 2-10 Score levels, nine failure modes). When TypeSafe ships a new
  version, re-read `https://docs.typesafe.ai/llms.txt`, `/models.md`, and
  `/model-jaggedness/<version>.md` and update the primer and the validator's disqualifier list.
- Cookbook slugs in the primer were verified live against `docs.typesafe.ai/cookbooks/<slug>.md`.
- `scripts/orient.sh` patterns are heuristics; tighten them when a signal is noisy on a new stack (the
  Plane run exposed `import` and `permission` as too broad, since removed).
- Re-run the GREEN test after any edit to `SKILL.md`: scan the same repo with and without the change and
  compare the rejected table and evidence verification counts.

## Relationship to the official TypeSafe skill

TypeSafe publishes `typesafe-ai/skills` (a Claude Code plugin) for *building* with jev: live docs, SDKs,
cookbooks. This skill is for *finding and prioritising* opportunities in an existing codebase and hands
off to the official skill for implementation. They do not overlap; install both.
