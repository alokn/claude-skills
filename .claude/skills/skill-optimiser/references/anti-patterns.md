# Skill Anti-Patterns

Wasteful patterns organized by dimension. Each has a before/after and estimated impact.

---

## Token Efficiency

### T1. Imperative Stacking
Saying the same rule multiple ways for emphasis. The model understands on first read.

**Before** (~90 tokens):
```
You MUST always validate user input before processing.
Never skip input validation — this is critical.
Important: All user inputs require validation before any processing occurs.
```

**After** (~25 tokens):
```
Validate all user input before processing.
```
Impact: ~65 tokens per instance.

### T2. Defensive Over-constraining
ALL CAPS NEVER/ALWAYS/CRITICAL when a clear explanation produces better compliance.

**Before** (~120 tokens):
```
CRITICAL: You must NEVER EVER use console.log in production code.
IMPORTANT: ALWAYS use the structured logger. This is ABSOLUTELY REQUIRED.
WARNING: Failure to use the logger is STRICTLY FORBIDDEN.
```

**After** (~40 tokens):
```
Use the structured logger from `src/utils/logger.ts` instead of console.log — it ensures consistent format and log levels.
```
Impact: ~80 tokens. The "after" explains *why*, which improves compliance more than caps lock.

### T3. Example Bloat
6+ examples when 2-3 demonstrate the pattern. Diminishing returns after the third.

**Before** (~200 tokens): 6 naming examples
**After** (~70 tokens): 2 examples covering the pattern

Impact: ~130 tokens.

### T4. Frontmatter Novels
Description over 75 words. Loaded into skill registry for *every* conversation — bloat here taxes all sessions.

Impact: ~100-200 tokens on every conversation, not just triggered ones.

### T5. Inlined Reference Material
3000+ words of reference content in SKILL.md instead of `references/` files loaded on demand.

Impact: ~500-800 tokens on every trigger. References load only when needed.

### T6. Redundant Context Loading
Re-reading files already in context, or re-stating available information.

Impact: ~40 tokens per instance plus wasted tool call.

---

## Execution Speed

### S1. Sequential When Parallel Is Possible
Multiple independent file reads, searches, or agent spawns done one at a time when they have no dependencies.

**Before**: Read file A → Read file B → Read file C → analyze all three
**After**: Read files A, B, C in parallel → analyze

Impact: 2-3x faster for I/O-bound steps. Look for: multiple `Read` calls where results don't depend on each other, independent `Grep` searches, agent spawns that don't share state.

### S2. Heavy Model for Light Work
Using Opus or Sonnet for tasks Haiku handles equally well. Larger models have higher latency per token.

**Before**: `model: opus` for "find all files importing module X"
**After**: `model: haiku` with `subagent_type: Explore`

Impact: 2-5x faster response time for search/extraction tasks.

### S3. Unnecessary File Re-reads
Reading the same file multiple times across workflow steps instead of reading once and referencing.

Impact: One tool call round-trip (~1-3s) per eliminated re-read.

---

## Turn Depth

### D1. Single-Purpose Agent Spawning
Spawning an agent to do one simple operation that could be a direct tool call.

**Before**: Spawn Explore agent → "read package.json and return the version"
**After**: Direct `Read` of `package.json`, extract version inline

Impact: Eliminates agent startup overhead (~2-5s) and tool description tokens.

### D2. Waterfall Confirmation Steps
Requiring user confirmation between every minor step. Reserve confirmation for destructive actions or ambiguous choices.

**Before**: Read file → confirm → analyze → confirm → suggest → confirm → apply
**After**: Read file → analyze → present all findings → confirm per group → apply

Impact: Reduces turn count by 50-70%, dramatically faster end-to-end.

### D3. Read-Before-Read Chains
Instructions like "read file A to find which file to read, then read that file to find..."  when a Grep could find the target directly.

**Before**: Read index.ts → find import path → read that file → find re-export → read final file
**After**: Grep for the symbol directly across the codebase

Impact: 3-4 sequential tool calls reduced to 1.

---

## Reliability

### R1. Ambiguous Branching
Instructions with unclear conditions that produce different behavior across runs.

**Before**:
```
If the code looks complex, do a deeper analysis. Otherwise, do a quick scan.
```

**After**:
```
If the file exceeds 200 lines or contains more than 3 levels of nesting, run deep analysis. Otherwise, quick scan.
```

Impact: Eliminates run-to-run variance from subjective judgment.

### R2. Missing Fallback Paths
Workflow assumes happy path without handling what happens when a step fails or returns empty results.

**Before**:
```
Read the config file at ~/.config/app/config.yaml and extract the API key.
```

**After**:
```
Read ~/.config/app/config.yaml. If the file doesn't exist or has no API key field, report this to the user and stop — don't guess or use defaults.
```

Impact: Prevents silent failures and hallucinated fallbacks.

### R3. Implicit State Assumptions
Assuming prior steps succeeded without checking, or assuming files/directories exist.

Impact: Each unchecked assumption is a potential silent failure point.

---

## Output Quality

### Q1. Underspecified Output Format
Telling the model to "provide a summary" without defining structure, length, or content expectations.

**Before**:
```
Summarize your findings.
```

**After**:
```
Present findings as a numbered list. Each item: file:line, one-sentence problem, one-sentence fix. No preamble.
```

Impact: Eliminates follow-up correction rounds (~1-3 extra turns per run).

### Q2. Missing Negative Examples
Showing what good output looks like but not what bad output looks like. The model benefits from both.

Impact: Reduces off-target outputs by ~30-50% for format-sensitive tasks.

### Q3. Inconsistent Terminology
Using different words for the same concept across the skill (e.g., "finding" vs "issue" vs "problem" vs "result").

Impact: Reduces model confusion and output inconsistency. Pick one term, use it everywhere.

---

## Cost

### C1. Opus Inheritance
Child agent inherits Opus from parent when the child's task is simple. Each inherited Opus call costs 5-15x more than explicit Haiku.

**Before**: Parent runs at Opus, spawns file-search child with no `model` field
**After**: Explicitly set `model: haiku` on the child

Impact: 5-15x cost reduction per agent call.

### C2. Uncacheable Context Structure
Prompt structure that prevents Anthropic's prompt caching from working. Changing content early in the prompt invalidates cache for everything after it.

**Before**: Dynamic timestamp at top of prompt, then 2000 tokens of static instructions
**After**: Static instructions first, dynamic content at the end

Impact: Up to 90% cost reduction on cached prompt portions.

### C3. High Output-to-Value Ratio
Skill produces verbose output (explanations, caveats, summaries) when the user only needs the actionable result.

**Before**: 500-token analysis paragraph per finding
**After**: 50-token structured finding (location + problem + fix)

Impact: Output tokens are more expensive than input tokens on some tiers. Reduces both cost and time.
