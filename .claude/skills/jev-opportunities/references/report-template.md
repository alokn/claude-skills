# Report template

Write the report to the output path (default `<repo>/jev-opportunities.md`). Follow this structure exactly.
Keep prose tight; the tables carry the ranking, the finding sections carry the design.

```markdown
# Jev opportunity assessment: <repo name>

<date> · scope: <paths or "whole repo"> · depth: <quick|standard|deep> · scanners: <n> · jev model assumed: jev-1.13.0

## Summary

<3-6 sentences: what the product does, where unstructured text flows, how much AI/heuristic logic exists
today, and the headline: the 2-3 opportunities worth doing first and why.>

**Top opportunities**

| # | ID | Title | Category | Impact | Effort | Fit | Confidence | Bucket |
|---|----|-------|----------|--------|--------|-----|------------|--------|
| 1 | A-02 | ... | replace | 5 | S | strong | verified | Do first |
| ... |

## How this repo works (mental model)

<1 paragraph: stack, main modules, the free-text objects and their lifecycle, existing AI/ML usage with
file references, existing review/triage queues, CI shape. This is what the findings are anchored to.>

## Findings

### Do first
<one subsection per finding, format below>

### Plan
<...>

### Quick wins
<...>

### Later / validate first
<...>

## Considered and rejected

| Candidate | Where | Why not (counter-signal or disqualifier) |
|---|---|---|
| Archive-after-N-days automation | `apps/.../issue_automation_task.py:44` | Date arithmetic; correct deterministic rule already exists |
| ... |

## Cross-cutting recommendations

- Where to put question constants and thresholds (one module), and the shadow-mode logging shape
- Existing labelled data usable for calibration (tables/columns/exports), per finding
- Batching: which findings share a state and should be one fan-out call
- What stays deterministic and authoritative (security, money, dates)

## Coverage and limits

- [ ] Paths scanned / skipped; scanner time budget; anything the scanners flagged as unfinished
- [ ] Jev version and facts relied on (price, latency, limits) with source date, live-fetched or snapshot
- [ ] Not verified: volumes, current LLM prices, accuracy on this domain, anything else
- [ ] Probe step run or skipped

## Next steps

1. Pick 1-2 "Do first" items; paste the primitive sketch into the TypeSafe Playground with 10 real examples
2. Shadow-mode for one of them (see rollout in the finding)
3. Optional: install the official TypeSafe skill for implementation guidance
   (`claude plugin marketplace add typesafe-ai/skills`, `claude plugin install typesafe@typesafe-ai`)
```

## Finding format (one per finding, under its bucket)

```markdown
#### <ID> · <Title>

**Category** replace | feature | sdlc · **Shape** <decision_shape> · **Impact** n/5 · **Effort** S/M/L · **Fit** strong/ok/weak · **Confidence** verified/inferred/speculative
_Merged from: <ids>, same state / call site_  (only when Step 5.5 merged findings)

**Evidence**
- `path/to/file.py:123` — `verbatim snippet`
- `path/to/other.ts:45` — `verbatim snippet`

**Today** <current_behavior>

**With jev** <proposed; for features: who benefits and where it fires>

**Primitive sketch**
```json
{ "state": {...}, "questions": {...} }
```
**Decision logic** <which answer drives which branch; confidence bands; what stays in code>

**Cost / latency** current: ... · proposed: ... · method: ...  ·  **Volume** <value> (<source>)

**Rollout** <shadow -> audit + calibrate on <data> -> flip high band, fallback kept -> retire <redundant heuristic> after gates>  ·  **Risks** <...>  ·  **Cookbook** `<slug>`
```

Rules for the writer:
- Every evidence line must have survived `validate_findings.py`. Do not add unvalidated file references in prose.
- No accuracy claims and no run-to-run consistency claims. Speed, cost, schema safety, and calibrated confidence with an honest low-confidence signal are the claimable properties.
- If two findings share a state (e.g. several questions about a new issue), say so and merge them into one
  fan-out call in the sketch.
- The "Considered and rejected" table is mandatory and should contain at least the disqualified candidates
  from the scanners.
