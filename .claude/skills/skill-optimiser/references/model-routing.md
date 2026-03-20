# Model Routing Decision Framework

## Model Comparison

| Model | Cost | Speed | Use When |
|-------|------|-------|----------|
| Haiku | Cheapest | Fastest | File discovery, pattern matching, simple extraction, formatting, quick lookups |
| Sonnet | Mid | Mid | Code review, code generation, moderate reasoning, most analysis tasks, standard workflows |
| Opus | Highest | Slowest | Complex multi-step reasoning, architectural decisions, nuanced judgment, tasks where Sonnet demonstrably struggles |

## Key Heuristics

**Default to `sonnet`** unless there's a clear reason not to. Sonnet handles 80%+ of typical skill/agent work at a fraction of Opus cost and latency.

**Use `haiku`** for agents that primarily search, filter, or transform. If the job is "find files matching X" or "extract value Y from config Z", haiku is sufficient and dramatically cheaper/faster. The `Explore` subagent type is designed for this.

**Use `opus`** only for deep reasoning across large codebases, nuanced quality judgment, or complex multi-step planning where Sonnet demonstrably produces worse results. If you can't articulate *why* Sonnet would fail, it probably won't.

**`inherit`** is fine when the parent model matches the child's needs. Flag it when the child's task is clearly simpler — an opus parent spawning a file-search child should set `model: "haiku"`, not inherit opus.

## Correct Routing Examples

### File Discovery
```yaml
# CORRECT — Haiku + Explore for search tasks
subagent_type: Explore
model: haiku
prompt: "Find all test files that import from the auth module"
```

### Code Review
```yaml
# CORRECT — Sonnet for standard analysis
subagent_type: general-purpose
model: sonnet
prompt: "Review this PR for bugs and style issues..."
```

### Architecture Planning
```yaml
# CORRECT — Opus justified for complex reasoning
subagent_type: Plan
model: opus
prompt: "Design the migration strategy for moving from REST to GraphQL across 40 services..."
```

## Red Flags

- Simple search/extraction set to `opus` or inheriting from an opus parent
- Complex architectural review set to `haiku`
- Every subagent set to the same model regardless of task complexity
- No `model` field when parent runs at opus (implicit expensive inheritance)
- `general-purpose` agent type when `Explore` (read-only, lighter) suffices

## Cost Multipliers

Approximate relative cost per output token (for budgeting):
- Haiku: 1x (baseline)
- Sonnet: ~5x Haiku
- Opus: ~15x Haiku

A single Opus agent call doing simple file search costs roughly the same as 15 Haiku calls doing the same work — but slower.
