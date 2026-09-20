---
id: au-semantic-predicate-in-hot-query
title: Do not call jev as a predicate inside a live SQL query
verdict: no
domain: data-ml
decision_shapes: [classification, detection, retrieval]
primitives: [noul, choice, score]
evidence_level: community-report
sources:
  - https://github.com/kylemclaren/jevql  (Postgres extension exposing jev as a SQL function; no numbers published)
  - https://github.com/colliber/duckdb-jev  (DuckDB extension)
  - https://github.com/mgaitan/sqlite-jev  (SQLite extension)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free; 70-500 ms per call)
related: [uc-data-ml-semantic-predicates-in-sql, au-numeric-thresholds-and-arithmetic, uc-data-ml-map-reduce-corpus-labelling, au-availability-and-rate-limits]
last_verified: 2026-09-20
jev_version: jev-1.13.0
---

## The question

"Can I write `WHERE is_complaint(body)` in Postgres?" Also: "can we put `jev_noul(...)` in a
`WHERE` clause over our tickets table?", "can analysts just add a semantic filter to their
dashboards?", "can jev go in a `JOIN` condition?".

## Verdict

**No**, as a predicate in a hot query. The bindings exist and the SQL is valid — that is the
problem. A network call inside a `WHERE` clause is invisible to the query planner, so the
number of calls, the runtime and the bill are all chosen by the optimiser rather than by you,
and the same query that ran over 800 rows in staging can run over 50 million in production.
The objection is a database one, not a model one. The same function used as a
**materialisation step** — `UPDATE ... SET flag = jev(...)` over a bounded batch, then query
the column — is a good fit and has its own entry:
`uc-data-ml-semantic-predicates-in-sql` (`good`).

## What jev would get wrong

Nothing, per row, that it would not also get right in a batch job. The failure is
operational. Three ways it bites:

**Cost set by the planner.** `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`: a
2,000-character row extract plus one question is about 700 tokens, ≈ $0.0000294 per row. A
sequential scan of a 50,000,000-row table is therefore ≈ **$1,470** and 50 million HTTP calls
for a query someone expected to take a second. In a `JOIN` condition the pair count is the
product of two table sizes.

**Latency and locks.** Each call is 70-500 ms and they are serialised by the plan, not
parallelised by you. Inside a transaction, those milliseconds are lock time per row.

**No fallback path.** A rate limit, a 429 or a timeout mid-scan leaves a half-evaluated
query with no retry story and no partial result you can trust
(`au-availability-and-rate-limits`). None of the five published bindings reports numbers,
concurrency behaviour, or a spend cap.

Also wrong by construction: putting a lexical or numeric test in the question. `LIKE`, a
regex, a range and a `tsvector` are exact, free and indexable.

## What stays in code (and in the planner)

Every deterministic predicate — tenant, date window, status, language, `LIMIT` — and proof
that it is evaluated *first*: a `MATERIALIZED` CTE or a staged temp table rather than trust in
the optimiser. All arithmetic, aggregation, `GROUP BY`, joins and date maths. Batching,
concurrency, retries, the per-run spend cap, and caching by a hash of the state so an
unchanged row is never re-billed.

## Numbers

**No published numbers exist for any of the five bindings** (jevql, pg-jev, pg_typesafe,
duckdb-jev, sqlite-jev) — no accuracy, no throughput, no cost. The only sourced figures are
the price ($0.042 per million input tokens, output free) and the latency range (70-500 ms)
from the models page; everything above is arithmetic over those, with the row counts stated
as the assumption they are.

## When the verdict flips

- To **good** when the call is a materialisation over a bounded set: `UPDATE ... SET
  is_complaint = jev(...) WHERE flag IS NULL AND created_at > now() - interval '1 day'`, then
  index and query the column. Store the probability **and** the confidence as columns so the
  threshold is retunable without re-calling. See `uc-data-ml-semantic-predicates-in-sql`.
- To **good** when an application worker runs the pass with its own concurrency and spend
  controls and writes the column back — the honest default above a few thousand rows.
- It does not flip for an unbounded `WHERE`, and never for a `JOIN` condition.

## Alternatives considered

- **Deterministic SQL (`LIKE`, regex, full-text, ranges).** Exact, free, indexable. First choice.
- **Materialised column, written by a batch pass.** The rewrite above; same ergonomics for the
  analyst, bounded cost.
- **External batch job writing the column back.** Best control over concurrency, retries and spend.
- **`pgvector` + embeddings.** Good for similarity in-database; cannot express a written criterion.
- **An LLM-in-SQL extension.** The same planner problem, orders of magnitude more cost and
  latency per row, and an untyped return.

## Sources

- https://github.com/kylemclaren/jevql — accessed 2026-09-20
- https://github.com/colliber/duckdb-jev — accessed 2026-09-20
- https://github.com/mgaitan/sqlite-jev — accessed 2026-09-20
- https://docs.typesafe.ai/models.md — accessed 2026-09-20
