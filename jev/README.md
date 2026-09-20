# jev corpus: ground truth for "is it a good idea to use jev for X?"

This directory is a retrieval corpus about **jev**, TypeSafe AI's System One model. It exists so that an
assistant can answer "should I use jev for X?" with a verdict, the reason, the shape of the solution,
what stays in code, honest numbers, and the conditions under which the verdict flips. It is not
documentation for building with jev (TypeSafe's docs and official skill do that) and it is not marketing.

Built 2026-09-19 against **jev-1.13.0** and the docs as they stood that day. Jev launched publicly on
2026-09-15; facts here will age. Every file carries `last_verified` and `jev_version`.

## How to use it

- **For a specific question** ("use jev to triage support tickets?"): search `20-use-cases/` and
  `30-anti-use-cases/` by title, `decision_shapes`, `domain`, and the phrasings under "The question".
  `index.json` carries every entry's id, path, verdict, tags, and a one-paragraph summary for retrieval.
- **For a question no entry covers**: apply `10-decision-framework/fit-test.md` (seven questions),
  then `rewrites.md` if a question fails, then `alternatives.md` to compare against the other tools,
  then `cost-model.md` to estimate. The answer should cite the failure mode it is closest to
  (`00-ground-truth/failure-modes.md`).
- **For a factual claim** (price, limit, latency, what jev cannot do): `00-ground-truth/` only. Those
  files quote the source with a URL and say "not published" where TypeSafe has not published.
- **For "what has been measured"**: `00-ground-truth/evals-official.md` (TypeSafe's own numbers with
  their stated biases) and `00-ground-truth/evidence-independent.md` (third-party measurements,
  including negative results). `40-cookbooks/README.md` says which cookbooks are benchmarks and which
  are demonstrations.

## Layout

| Path | Contents | Count |
|---|---|---|
| `CORPUS-SCHEMA.md` | Entry templates, verdict scale, evidence levels, editorial rules | 1 |
| `00-ground-truth/` | What jev is, API and primitives, limits and pricing, confidence and calibration, failure modes, how to build and patterns, RLCD and training, official evals, independent evidence, company and ecosystem, glossary | 11 |
| `10-decision-framework/` | FAQ and routing table, fit test (with a deployment-eligibility gate), rewrites, alternatives comparison, cost model, rollout and calibration | 6 |
| `20-use-cases/<domain>/` | One use case per file across 19 domains; verdict strong, good, or conditional | 134 |
| `30-anti-use-cases/` | One case per file where jev is the wrong tool; verdict weak or no; with the rewrite where one exists | 64 |
| `40-cookbooks/` | One digest per official TypeSafe cookbook with verbatim numbers, caveats, source model version, and links to the entries it supports | 18 + index |
| `50-sources/` | `sources.md` (every frontmatter-cited URL, grouped, with liveness), `url-check.md`, `changelog.md`, four Codex adversarial reviews (two passes, two models) and the prompts that produced them | 9 |
| `index.json` | Machine-readable index generated from frontmatter (id, path, verdict, domain, shapes, primitives, evidence level, sources, related, summary) | 1 |
| `scripts/` | `build_index.py` (index + schema validation), `check_sources.py` (URL liveness), `build_sources.py` (sources index) | 3 |

## Verdict vocabulary

`strong` · `good` · `conditional` · `weak` · `no`. Definitions in `CORPUS-SCHEMA.md`. An entry's
`evidence_level` is the weakest link in its chain: `official-cookbook` > `official-docs` >
`independent-benchmark` > `community-report` > `inferred`.

## What the corpus will not say

- That jev is more accurate than an incumbent, unless a named source measured it for that task.
  TypeSafe's own workflow evals place it mid-table (67.8%) on agreement with a two-model reference, not
  on human ground truth. "Abstention" is a threshold policy the developer writes, not a model behaviour.
- That jev's confidence is calibrated for your task. It is trained to be; independent ECE ranges from
  0.045 to 0.242 by dataset, so calibration is measured, not assumed.
- That jev is more consistent run to run than an LLM at temperature 0. TypeSafe's own cookbook shows
  the opposite for Claude Haiku 4.5.
- That "zero hallucination" means "always right". It means the output cannot leave the schema.
- Monthly savings without a sourced volume, or the launch post's headline multipliers as an expectation.
- That a `conditional` verdict answers the literal question. Where the question people ask gets a
  different answer from the labelled proposal, the entry carries `verdict_as_asked` and a sibling
  anti-use-case answers the literal question; the FAQ shows both.
- That the public evidence base is complete. At least one independent tool author states TypeSafe's
  customer agreement restricts publishing jev performance numbers, so unfavourable results may be
  under-reported. Independent evidence is weighed accordingly in `00-ground-truth/evidence-independent.md`.

## Maintenance

```
python3 scripts/build_index.py          # regenerate index.json; prints schema problems
python3 scripts/check_sources.py --write 50-sources/url-check.md
```
When TypeSafe ships a new jev version: re-read `https://docs.typesafe.ai/llms.txt`, `models.md`, and
the new `model-jaggedness/<version>.md`; update `00-ground-truth/`, bump `jev_version` on entries you
re-verify, and record it in `50-sources/changelog.md`.

## Provenance

Compiled by Claude (Fable 5.1 orchestrating Opus and Sonnet research and writing agents) from
TypeSafe's public documentation, launch post, evals site, and third-party sources, then adversarially
reviewed in two passes with OpenAI Codex (GPT-6 Astra and GPT-5.6 Sol; the second pass verified the
first pass's fixes and sampled entries). All four reviews are archived verbatim in `50-sources/`; what
changed as a result is in `50-sources/changelog.md`. The second pass's residual verdict was "fit with
caveats" (Sol) and "not yet" (Astra); the items both named were then fixed (verdict splits, two `strong`
demotions, residue propagation, invented volumes removed, failure-mode lines added). Treat every verdict
as a hypothesis to validate in shadow mode on your own data, which is also what the entries say.
