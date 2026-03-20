# Token Estimation Heuristics

## Basic Conversion

- **English text**: ~4 characters per token, or ~0.75 tokens per word
- **Code**: ~3.5 characters per token (more symbols, shorter variable names)
- **Quick formula**: `word_count * 1.33 ≈ token_count` for English prose
- **Inverse**: `token_count * 0.75 ≈ word_count`

## Skill/Agent Token Budget

### Always-Loaded (every conversation)
- **Frontmatter `description`**: Loaded into skill registry for matching. Budget: <75 words (~100 tokens). Every word here taxes *all* conversations.
- **CLAUDE.md contents**: Loaded into every conversation in the project. Keep concise.

### Loaded on Trigger
- **SKILL.md body**: Full content loaded when skill activates. Target: <2000 words (~2600 tokens). Exceeding this compresses useful context.
- **Reference files**: Loaded on demand via `Read` tool calls. No inherent limit, but each load costs a tool round-trip plus the file's token count.

### Agent Context Costs
- **Tool descriptions**: Each tool adds ~200-500 tokens to agent context. An `Explore` agent (5-6 tools) costs ~1500 fewer tokens than `general-purpose` (12+ tools).
- **Subagent prompt**: The prompt you write, plus system instructions, plus tool descriptions. Budget the prompt itself at <500 words for simple tasks.
- **Conversation history**: Subagents started fresh have no history cost. Resumed agents carry full prior context.

## Sizing Guidelines

| Artifact | Target | Max | Tokens |
|----------|--------|-----|--------|
| Frontmatter description | 40 words | 75 words | 50-100 |
| SKILL.md body | 1500 words | 2000 words | 2000-2600 |
| Single reference file | 500-1000 words | 2000 words | 700-2600 |
| Subagent prompt (simple) | 50-100 words | 200 words | 70-260 |
| Subagent prompt (complex) | 200-400 words | 500 words | 260-650 |

## Measuring Actual Usage

When execution data is available:
- **Task tool results** report `total_tokens` — compare against expected budget
- **Rule of thumb**: A well-optimized skill should consume <5000 tokens for its instructions (SKILL.md + referenced files), leaving the rest of context for actual work
- **Red flag**: If skill instructions exceed 30% of total tokens in a typical run, optimization is needed
- **Comparison**: Token spend should be proportionate to output complexity — a skill that spends 8000 tokens on instructions to produce a 200-token output has a poor ratio

## Quick Audit Checklist

1. Count words in SKILL.md body → multiply by 1.33 → is it under 2600 tokens?
2. Count words in frontmatter description → is it under 75?
3. Count reference files → sum their word counts → are any over 2000 words?
4. Count subagents spawned → sum their tool descriptions → is the total tool overhead justified?
5. Check for content that could move from SKILL.md to references/ (loaded on demand)
