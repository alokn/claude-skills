# Session Replay Analysis

How to analyze past skill/agent executions to find real-world optimization opportunities that static analysis misses.

## Data Sources

### Claude Code Session Files
Location: `~/.claude/projects/*/sessions/*.jsonl`

Each line is a JSON object representing a conversation turn. Look for:
- `tool_use` entries — what tools were called and in what order
- `total_tokens` — actual token consumption per turn
- `duration_ms` — wall-clock time per turn
- Content of agent prompts and their results

### Task Tool Results
When skills spawn agents via the Task/Agent tool, results include:
- `total_tokens` — total tokens consumed by the subagent
- `tool_uses` — count of tool invocations
- `duration_ms` — wall-clock time for the agent run

### User-Provided Transcripts
Pasted conversation excerpts. Parse for tool call patterns, token counts mentioned in output, and visible timing gaps.

## Analysis Framework

### 1. Token Budget Comparison
Compare actual consumption against expected budget from `token-estimation.md`:
- Skill instructions should be <5000 tokens (SKILL.md + referenced files)
- If instructions exceed 30% of total run tokens, the skill is instruction-heavy
- Calculate output-to-instruction ratio: `output_tokens / instruction_tokens`

### 2. Tool Call Efficiency
Map the sequence of tool calls and look for:
- **Redundant reads**: Same file read multiple times across the session
- **Empty searches**: Grep/Glob calls that returned no results (bad patterns or wrong paths)
- **Sequential independence**: Adjacent tool calls with no data dependency → should be parallel
- **Agent overhead**: Subagents spawned for single-operation tasks

### 3. Timing Analysis
From `duration_ms` data:
- Identify the slowest steps — are they inherently slow (large codebase search) or unnecessarily slow (wrong model, sequential when parallel)?
- Compare model time: Opus calls vs Sonnet calls for similar-complexity tasks
- Look for idle gaps — time between tool calls where the model is reasoning without progress

### 4. Reasoning Loop Detection
Patterns that indicate the model is stuck:
- Reading the same file more than twice
- Alternating between two approaches without committing
- Long text output between tool calls (verbose reasoning that doesn't lead to action)
- Retrying the same tool call with minor variations

### 5. Unused Skill Sections
Cross-reference the skill's instructions with actual execution:
- Which reference files were loaded? Were any loaded but never used?
- Which workflow steps were executed? Were any skipped or repeated?
- Which analysis categories produced findings? Were empty categories worth checking?

### 6. Variance Analysis (Multiple Sessions)
When data from 2+ runs is available:
- Token consumption range — high variance suggests unreliable instructions
- Different tool call sequences for the same input — ambiguous workflow
- Output format differences — underspecified format
- Success/failure rate — reliability signal

## What to Report

For each finding from session replay:
- **Dimension** it maps to (token, speed, turn depth, reliability, quality, cost)
- **Evidence** from the session data (specific tool calls, token counts, timing)
- **Estimated impact** if fixed
- **Whether static analysis could have caught it** — helps prioritize static analysis improvements too

## Quick Checklist

1. Total tokens: within budget? (< 5000 for instructions, reasonable total)
2. Tool calls: any redundant reads or empty searches?
3. Parallelism: any sequential calls that could be parallel?
4. Model routing: any Opus/Sonnet calls that Haiku could handle?
5. Timing: where did the time go? Any single step dominating?
6. Loops: any file read more than twice? Any back-and-forth reasoning?
7. Unused sections: any reference files loaded but never referenced in output?
