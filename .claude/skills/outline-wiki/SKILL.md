---
name: outline-wiki
description: Use this skill when the user asks about Outline, the wiki, docs, or wants to search/read/create/update documents in the Outline wiki. Uses MCP tools from the `outline` MCP server.
---

# Outline Wiki

Read and write documents in the self-hosted Outline wiki at `docs.wobbit.com.au` via MCP tools.

## Instance

- **URL**: https://docs.wobbit.com.au
- **MCP server**: `outline` (registered at user scope)
- **Delete disabled**: `OUTLINE_DISABLE_DELETE=true` — deletion tools are not available

## Available MCP Tools

### Reading
- `outline:read_document` — read document by ID
- `outline:export_document` — export document content

### Searching
- `outline:search_documents` — full-text search across all documents
- `outline:list_collections` — list all collections
- `outline:get_collection_structure` — get document tree for a collection
- `outline:get_document_id_from_title` — find document ID by title

### Writing
- `outline:create_document` — create a new document (requires `title` and `collection_id`)
- `outline:update_document` — update an existing document's title or content
- `outline:add_comment` — add a comment to a document

### Organization
- `outline:move_document` — move document to a different collection or parent
- `outline:archive_document` / `outline:unarchive_document`
- `outline:restore_document` — restore from trash

### Collections
- `outline:export_collection` / `outline:export_all_collections`
- `outline:create_collection` / `outline:update_collection`

### Collaboration
- `outline:list_document_comments` / `outline:get_comment`
- `outline:get_document_backlinks`

### Batch Operations
- `outline:batch_archive_documents`
- `outline:batch_move_documents`
- `outline:batch_update_documents`
- `outline:batch_create_documents`

### AI
- `outline:ask_ai_about_documents` — ask questions answered by document content

## Workflow Patterns

### Finding a document
1. Use `search_documents` with a query to find relevant docs
2. Use `read_document` with the returned ID to get full content

### Creating a document
1. Use `list_collections` to find the right collection ID
2. Use `create_document` with `title`, `collection_id`, and markdown `text`

### Updating a document
1. Use `search_documents` or `get_document_id_from_title` to find the doc ID
2. Use `read_document` to get current content
3. Use `update_document` with the modified content

### Always
- Include the document URL in responses so the user can open it in their browser
- Document content is markdown — use standard markdown formatting
- Search before creating to avoid duplicates
