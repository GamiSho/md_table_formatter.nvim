# AGENTS.md

## Project

`md_table_formatter.nvim` is a Lua-based Neovim plugin for formatting and structurally editing GitHub Flavored Markdown pipe tables.

This file is the entry point for coding agents. Read this file first, then read `docs/specification.md` and `docs/architecture.md` before changing code.

## Current capabilities

Implemented and expected to remain working:

- Detect the Markdown table containing the cursor.
- Format valid pipe tables into the canonical layout.
- Preserve left, center, and right column alignment semantics.
- Calculate padding with Neovim display width so Japanese/CJK text aligns visually.
- Preserve empty cells.
- Reject invalid tables without partial buffer modification.
- Keep formatting idempotent.
- Add a table row.
- Delete a table row.
- Reset a header or body row to empty cells; the separator row cannot be reset.
- Add a table column.
- Delete a table column.
- Create a blank table with `:TableCreate {rows}x{columns}` or
  `require("table-formatter").create(rows, columns)`.

## Important design rules

- Runtime external dependencies must remain zero.
- Use Neovim APIs, the Neovim Lua runtime, and the standard Lua library at runtime.
- Keep table detection, parsing/validation, formatting/editing, and buffer mutation separated.
- Parse and validate the complete target table before modifying the buffer.
- Successful operations should replace the complete selected table atomically rather than modifying individual lines incrementally.
- Reuse the common formatter after structural edits so formatting/alignment logic is not duplicated.
- Use `vim.fn.strdisplaywidth()` for visual width. Do not use Lua string length for layout decisions.
- Preserve separator alignment semantics, including explicit left alignment (`:---`), center (`:---:`), and right (`---:`).
- Do not silently repair invalid input by inventing missing cells or a separator row.
- Formatting must remain idempotent.
- Do not add default key mappings.
- Do not restrict supported operations by buffer `filetype`.

## Command/API expectations

Existing formatting entry points:

- `:TableFormat`
- `require("table-formatter").format()`

Structural editing should follow the same architecture and expose commands and corresponding public Lua APIs. Row add/delete/reset and column add/delete are current capabilities. Row reset is available through `:TableResetRow` and `require("table-formatter").reset_row()`.

## Column deletion behavior

- Delete the column containing the cursor from header, separator, and every body row.
- Do not allow deleting the only remaining column.
- Determine the current logical cell/column from the cursor position rather than requiring a numeric column argument.
- After a successful structural edit, run the common canonical formatting path.
- Preserve the cursor inside the same logical table and as close as practical to the edited column.

## Unsupported/non-goal behavior

Unless a later specification explicitly changes them, these remain unsupported:

- Textile, reStructuredText, or HTML tables.
- Escaped-pipe-aware parsing. Every `|` is a delimiter in the current grammar.
- Missing separator-row repair.
- Missing-cell repair or inconsistent-column-count repair.
- Colspan/rowspan.
- Multiline cells.
- Visual-mode range formatting.
- Formatting every table in the buffer at once.
- Default key mappings.

## Tests

Before reporting completion:

1. Run the existing full test suite.
2. Add focused unit tests for any new table-model/editor behavior.
3. Add integration tests for user commands and public Lua APIs.
4. Cover invalid input and confirm the buffer remains unchanged.
5. Cover cursor behavior.
6. Cover alignment preservation and CJK display-width behavior where structural edits interact with formatting.
7. Verify formatting idempotency still holds.

Use the repository's existing test commands and conventions. If they differ from documentation, prefer the repository configuration and update the documentation accordingly.

## Definition of done for an agent change

A change is not complete until:

- The requested behavior is implemented.
- Existing behavior has not regressed.
- Automated tests pass.
- Documentation is updated when public behavior changes.
- No external runtime dependency has been added.
- Any unmet requirement or assumption is explicitly reported.

In the final implementation report, summarize changed files, test commands/results, acceptance-criteria status, and any remaining limitation.
