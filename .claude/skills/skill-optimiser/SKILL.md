---
name: skill-optimiser
description: >
  Use when the user asks to "optimise a skill", "review a skill", "profile an agent",
  "speed up a skill", "reduce token usage", "improve reliability", or wants to analyze
  any Claude Code skill or agent across token efficiency, speed, cost, reliability,
  quality, and turn depth. Can review past sessions to inform analysis.
  Use proactively when reviewing skills or agents for efficiency.
---

# Skill Optimiser

Analyzes Claude Code skills and agents across 7 dimensions: **token efficiency**, **execution speed**, **turn depth**, **reliability**, **output quality**, **cost**, and **session-informed insights**. Identifies concrete improvements with estimated impact per dimension.

## Quick Start

Provide a path or name of any skill or agent:
- `optimise the outline-wiki skill` → reads `~/.claude/skills/outline-wiki/`
- `optimise this agent file` → reads the specified `.md` file
- `review my PR skill with last session` → reads skill + analyzes session data

If no path is obvious, ask the user which skill or agent to analyze.

## Dimensions

### 1. Token Efficiency
Instruction bloat, redundancy, progressive disclosure failures. How many tokens the skill's instructions consume vs useful work done.

### 2. Execution Speed
Wall-clock time from trigger to output. Model choice (Haiku < Sonnet < Opus), sequential vs parallel tool calls, unnecessary agent hops.

### 3. Turn Depth
Shape of the execution graph. Sequential chains vs parallel fan-out. A skill doing 12 sequential reads when 4 parallel reads suffice is slow regardless of token count.

### 4. Reliability
Edge case handling, instruction clarity, failure modes. Ambiguous instructions cause divergent behavior. Missing error paths cause silent failures. A skill that fails 30% of the time isn't optimised.

### 5. Output Quality Consistency
How tightly output format is specified. Vague format instructions cause follow-up corrections — each correction round wastes more time and tokens than a precise spec would have cost.

### 6. Cost
Monetary spend per run. Model routing, input/output token ratio, cacheability. Distinct from token count — a 1000-token Opus prompt costs more than a 2000-token Haiku prompt.

### 7. Session-Informed Insights
Patterns visible only in real execution data: actual token consumption vs budget, time spent, tool calls that returned nothing useful, reasoning loops, unused skill sections.

## Workflow

### Step 1: Identify and Read

Determine artifact type:
- **Skill**: Has `SKILL.md` with frontmatter. May have `references/` directory. Read all files.
- **Agent**: A standalone `.md` file or prompt template. Read it and any referenced files.

Use Glob to discover all files in the skill/agent directory. Read every `.md` and `.yaml` file found.

### Step 2: Static Analysis (Dimensions 1–6)

Analyze across dimensions 1–6. For each finding, record:
- **Dimension** and specific anti-pattern (see `references/anti-patterns.md`)
- **Location** (file:lines)
- **Problem** (1-2 sentences)
- **Suggestion** (concrete change — show before/after text)
- **Impact** in dimension-appropriate units:
  - Token efficiency: tokens saved
  - Speed: tool calls eliminated or parallelism gained
  - Turn depth: sequential steps removed
  - Reliability: failure mode closed
  - Quality: ambiguity removed (cite the vague text)
  - Cost: model tier reduction or caching opportunity

Read `references/anti-patterns.md` for pattern matching across all dimensions.
Read `references/token-estimation.md` for token budgeting heuristics.
Read `references/model-routing.md` for cost and model selection analysis.

### Step 3: Session Replay Analysis (Dimension 7)

If the user provides session data, analyze it per `references/session-replay.md`:
- **Session JSONL** from `~/.claude/projects/*/sessions/`
- **Pasted transcript** — conversation excerpt showing the skill in action
- **Token/timing data** — `total_tokens` and `duration_ms` from Task tool results
- **Multiple sessions** — compare across runs for variance

If no session data is provided, ask once whether they'd like to include it. If not, skip.

### Step 4: Present Findings

Group by dimension. For each:
- Dimension name, finding count, headline impact metric
- Each finding with location, problem, suggestion, and impact

```
## Analysis: [artifact-name]

### Token Efficiency (N findings, ~X tokens saved)
1. **[file:lines] — [short description]**
   [concrete before/after]
   Impact: ~Y tokens saved

> Approve this group? [Y/n/discuss]
```

Present one dimension at a time. Wait for user response before the next.

### Step 5: User Approves/Rejects Per Group

For each dimension group:
- **Y** — apply these changes
- **n** — skip this group
- **discuss** — explain reasoning, adjust, re-present

### Step 6: Apply Approved Changes

Apply all approved changes. Show:
- Changes made per file
- Before/after metrics for each dimension
- Overall improvement summary

## References

- `references/anti-patterns.md` — Wasteful patterns across all 7 dimensions
- `references/token-estimation.md` — Token counting heuristics and budget guidelines
- `references/model-routing.md` — Sonnet/Opus/Haiku decision framework
- `references/session-replay.md` — Past session analysis framework
