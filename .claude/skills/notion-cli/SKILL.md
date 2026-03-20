---
name: notion-cli
description: Use this skill when the user asks about Notion, wants to search/read/create/update/delete Notion pages, databases, blocks, or comments. Invoke the `notion` CLI tool via Bash.
---

# Notion CLI

A CLI tool for the Notion API. Use `notion` commands via Bash.

## Auth

The API key is stored in `~/.config/notion-cli/config.json`. If not set, run:
```bash
notion config set-token <key>
```

## Commands

Always use `--json` flag when calling from Claude Code for structured output.

### Search
```bash
notion --json search "<query>"
notion --json search "<query>" --filter pages|databases --limit N
```

### Pages
```bash
notion --json page get <id> --content --md    # Read page with markdown content
notion --json page create --parent <id> --title "Title" --body "# Markdown content"
notion --json page update <id> --title "New Title" --props '{"key": "value"}'
notion --json page delete <id>
notion --json page append <id> --body "More content"
```

### Databases
```bash
notion --json db get <id>
notion --json db query <id> --filter '{"property":"Status","select":{"equals":"Done"}}' --limit 10
notion --json db create --parent <id> --title "DB" --schema '{"Name":{"title":{}}}'
notion --json db update <id> --title "New Name"
notion --json db delete <id>
```

### Blocks
```bash
notion --json block get <id> --md
notion --json block children <id> --md
notion --json block append <id> --body "Content"
notion --json block update <id> --data '{"paragraph":{"rich_text":[{"text":{"content":"Updated"}}]}}'
notion --json block delete <id>
```

### Users
```bash
notion --json user list
notion --json user get <id>
notion --json user me
```

### Comments
```bash
notion --json comment list --page <id>
notion --json comment create --page <id> --body "Comment text"
```

### Config
```bash
notion config set-token <key>
notion config show --json
notion config path
```

## ID Formats

IDs accept: full Notion URLs, hyphenated UUIDs, or raw 32-char hex strings.

## Output Modes

- `--json`: Structured JSON (use this from Claude Code)
- `--raw`: Full API response
- Default: Human-readable summary
