---
id: uc-data-ml-semantic-predicates-in-sql
title: Materialise a jev answer as a column with SQL, rather than calling it in a live predicate
verdict: good
verdict_as_asked: no
domain: data-ml
decision_shapes: [classification, detection, feature-extraction]
primitives: [noul, choice, score]
evidence_level: community-report
sources:
  - https://github.com/kylemclaren/jevql  (Postgres extension exposing jev as a SQL function; no numbers published)
  - https://github.com/realZachi/pg-jev  (Postgres binding)
  - https://github.com/giuliosmall/pg_typesafe  (Postgres binding)
  - https://github.com/colliber/duckdb-jev  (DuckDB extension)
  - https://github.com/mgaitan/sqlite-jev  (SQLite extension)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free; 70-500 ms)
related: [au-semantic-predicate-in-hot-query, uc-data-ml-order-by-probability-topic-membership, uc-data-ml-map-reduce-corpus-labelling, uc-data-ml-dataset-curation-row-filtering, au-numeric-thresholds-and-arithmetic]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to call jev from SQL?" Also: "can I write `WHERE is_complaint(body)` in
Postgres?", "is there a DuckDB extension for jev?", "can our analysts ask semantic questions
without a pipeline?".

## Verdict

The literal question — "can I write `WHERE is_complaint(body)` in Postgres?", a live
predicate over a hot query — is answered **no**, in `au-semantic-predicate-in-hot-query`: a
network call inside a query plan is invisible to the planner, so the call count, the runtime
and the bill are chosen by the optimiser rather than by you.

**This entry describes the materialisation step, and its verdict is good.** Bindings exist
for Postgres (three independent ones), DuckDB and SQLite, and none publishes numbers. The
ergonomic win is real: an analyst who can write SQL can now write a semantic filter without a
Python job, and the typed return means the column has a type. The shape that earns the `good`
is `UPDATE ... SET flag = jev(...)` over a bounded batch, or a materialised view — never
`SELECT ... WHERE jev(...)` against a live table. What keeps it out of `strong` is that no
binding publishes a number of any kind.

## What jev decides

One row, one call, the question written in the SQL. Keep the state to the columns the question
needs — passing `SELECT *` into the function is jaggedness mode 5 written in SQL.

```sql
-- materialise, do not predicate
ALTER TABLE tickets ADD COLUMN is_complaint real, ADD COLUMN complaint_conf real;

UPDATE tickets t SET (is_complaint, complaint_conf) = (
  SELECT p, confidence FROM jev_noul(
    state      => jsonb_build_object('subject', t.subject, 'body', left(t.body, 4000)),
    question   => 'Is the customer complaining about something that already happened?',
    true_when  => 'The message reports a problem the customer has already experienced.',
    false_when => 'The message asks a question, requests a feature, or reports a problem
                   someone else had.')
) WHERE t.is_complaint IS NULL AND t.created_at > now() - interval '1 day';

-- then query normally, for free, forever
SELECT * FROM tickets WHERE is_complaint > 0.8 AND complaint_conf > 0.7;
```

Store the probability **and** the confidence as columns. Once they are columns, every
subsequent query is a plain index scan, the threshold is retunable without re-calling, and
the low-confidence band is `WHERE complaint_conf < 0.7` — a review queue in one line.

## What stays in code (and in the planner)

Every deterministic predicate goes first and must be provably evaluated first: tenant, date
window, status, language, `LIMIT`. Use a CTE with `MATERIALIZED` or a staged temp table rather
than trusting the optimiser not to push the function down. All arithmetic, aggregation,
`GROUP BY`, date maths and joins — jaggedness modes 2 and 3, and SQL is better at them anyway.
Batching, concurrency, retries and the per-run spend cap. Caching by a hash of the state, so
an unchanged row is never re-billed.

**Never put jev in a JOIN condition.** The pair count is the product of two table sizes and
the planner will happily ask for all of it.

## Numbers

**No published numbers exist for any of these bindings.** Cost by method:
`input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. A 2,000-character row
extract plus one question with criteria (~800 characters) is about 700 tokens, **≈ $0.0000294
per row**. The number that should frighten you is not the unit cost but the row count a
careless plan produces: a sequential scan of a 50,000,000-row table at that rate is **≈
$1,470** and 50 million HTTP calls for a query someone expected to take a second. Latency from
the models page is "70 to 500 ms" per call, so a synchronous scan is also bounded by round
trips, not by the database.

## When the verdict flips

- **The function appears in a `WHERE` on an unbounded table.** Then it is `no`: cost and
  runtime are set by the planner, not by you — `au-semantic-predicate-in-hot-query`.
- **It appears in a `JOIN` condition.** Same, squared.
- **The question is lexical or numeric.** `LIKE`, a regex, a range or a `tsvector` is exact
  and free.
- **You need transactional consistency.** A network call inside a transaction holds locks for
  hundreds of milliseconds per row.
- **Your database cannot make outbound connections** (and most hardened production ones should
  not). Run the pass from an application worker and write the column back.

## Alternatives considered

- **Deterministic SQL (`LIKE`, regex, full-text, ranges).** Exact, free, indexable. First choice
  whenever it can express the question.
- **An external batch job writing the column back.** The same result with better control over
  concurrency, retries and spend — and the honest default for anything above a few thousand rows.
- **`pgvector` + embeddings.** Good for similarity and clustering in-database; cannot express a
  written criterion or return a calibrated yes/no.
- **An LLM-in-SQL extension.** Same ergonomics, orders of magnitude more cost and latency per
  row, and an untyped return you then have to parse.
- **dbt model with a Python step.** More machinery, but the place this belongs once it is more
  than an analyst's ad-hoc question.

## Sources

- https://github.com/kylemclaren/jevql — accessed 2026-09-19
- https://github.com/realZachi/pg-jev — accessed 2026-09-19
- https://github.com/giuliosmall/pg_typesafe — accessed 2026-09-19
- https://github.com/colliber/duckdb-jev — accessed 2026-09-19
- https://github.com/mgaitan/sqlite-jev — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
