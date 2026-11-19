# md_table_formatter.nvim Specification

## 1. Purpose

`md_table_formatter.nvim` formats and structurally edits the GitHub Flavored Markdown pipe table containing the current cursor in Neovim.

The plugin is designed for Normal-mode editing and keeps Markdown table manipulation predictable, atomic, CJK-aware, and testable.

## 2. Target environment

- Neovim: 0.12.6
- Implementation language: Lua
- Primary development environment: WSL2 / Ubuntu 24.04
- Runtime external dependencies: none

## 3. Supported table form

A valid table contains:

1. One header row.
2. One separator row immediately after the header.
3. Zero or more body rows.
4. The same number of cells in every row.
5. At least one column.

Leading/trailing pipes may be accepted in input where the parser supports them, but canonical output uses both leading and trailing pipes.

### Separator syntax

Supported separator semantics:

- `---`: plain left alignment
- `:---`: explicit left alignment
- `:---:`: center alignment
- `---:`: right alignment

Additional hyphens are valid. A separator representation must contain at least three hyphens, excluding colons.

## 4. Canonical formatting

Canonical rows use the form:

```text
| content | content |
```

Requirements:

- Emit leading and trailing pipes.
- Use one structural space inside delimiters.
- Trim irrelevant surrounding whitespace from parsed cell content.
- Pad cells according to display width and separator-defined alignment.
- Preserve empty cells.
- Regenerate the existing separator row while preserving alignment semantics.
- Never modify lines outside the detected target table.

### Alignment

Left:

- content first
- remaining padding on the right

Right:

- padding first
- content at the right edge

Center:

- split padding between left and right
- when padding is odd, put the extra space on the right

Thus `left_padding <= right_padding`.

## 5. Display width and CJK

All visual-width calculations must use Neovim display-width semantics, preferably:

```lua
vim.fn.strdisplaywidth(text)
```

Do not use `#text` to calculate visual cell widths.

Japanese, Chinese, Korean, and mixed ASCII/CJK cells must produce aligned pipe columns in Neovim.

## 6. Table detection and validation

When a table operation is invoked:

1. Start from the current cursor line.
2. Identify the contiguous candidate block containing the cursor; each candidate line must contain at least two `|` characters.
3. Stop at blank lines or lines with fewer than two `|` characters. Prose with two or more pipes may be included in the candidate.
4. Parse the candidate rows.
5. Validate the complete table.
6. Do not modify the buffer if validation fails.

Do not classify arbitrary prose containing a single pipe as a table solely because `|` appears.

A table is invalid when, for example:

- the separator row is missing or invalid;
- row column counts differ;
- there are zero columns;
- parsing otherwise violates the supported grammar.

Invalid input must produce a controlled warning/structured error and leave the buffer unchanged.

## 7. Formatting operation

### Command

```vim
:TableFormat
```

### Lua API

```lua
require("table-formatter").format()
```

The command delegates to the same public workflow used by the Lua API.

Formatting must be idempotent:

```text
format(format(T)) == format(T)
```

## 8. Structural editing

Structural editing operates on the valid table containing the cursor and reuses common detection, parsing, validation, formatting, and buffer-replacement logic.

After a successful structural change, the table must be passed through the canonical formatter before the single buffer replacement.

### 8.1 Add row

Current capability.

Expected semantics:

- Insert a new body row relative to the logical row containing the cursor according to the current repository behavior.
- The inserted row has exactly the table's current column count.
- New body cells are empty.
- Do not create a malformed table.
- Reformat the complete table afterward.

Header/separator edge behavior must remain consistent with the existing implementation and tests.

### 8.2 Delete row

Current capability.

Expected semantics:

- Delete the intended logical body row according to the current repository behavior.
- Do not allow an operation that would violate the required header/separator structure.
- Reformat the remaining table afterward.
- Preserve current documented error behavior for attempts to delete non-deletable structural rows.

### 8.3 Add column

Current capability.

Requirements:

- Determine the logical column containing the cursor.
- Insert one new column immediately to the right of that column.
- Insert a cell into every table row.
- Header cell: empty.
- Body cells: empty.
- Separator cell: plain left alignment by default.
- Preserve all existing columns' content and separator alignment semantics.
- Reformat the complete table after insertion.
- Preserve cursor location as closely as practical, preferably placing it in or near the newly inserted column while keeping the same logical row.

Recommended command/API names:

```vim
:TableAddColumn
```

```lua
require("table-formatter").add_column()
```

### 8.4 Delete column

Current capability.

Requirements:

- Determine the logical column containing the cursor.
- Delete that cell index from header, separator, and every body row.
- Do not allow deleting the last remaining column.
- Preserve other column content and alignment semantics.
- Reformat the complete table after deletion.
- Keep the cursor on the same logical row and move it to the next column when
  available, or the previous column when deleting the last column.

Recommended command/API names:

```vim
:TableDeleteColumn
```

```lua
require("table-formatter").delete_column()
```

## 9. Cursor behavior

After a successful operation:

- Keep the cursor inside the same logical table.
- For formatting and column edits, keep it on the same logical row when possible; row edits retain their operation-specific cursor behavior.
- Clamp the byte column to a valid line position if output becomes shorter.
- For structural edits, keep the cursor close to the affected row/column.

Exact character preservation is desirable but not required unless existing tests/documentation require it.

## 10. Atomicity

For every operation, perform all work before mutation:

```text
Detect
  -> Parse
  -> Validate
  -> Apply pure table transformation (if editing)
  -> Calculate widths / format
  -> Build full output
  -> Replace target table once
```

No partial table modification is allowed on failure.

## 11. Error handling

Operations must not expose uncontrolled Lua errors for expected invalid-input cases.

Examples of controlled failures:

- no Markdown table at cursor;
- invalid separator;
- inconsistent column counts;
- attempts to delete a protected structural row;
- attempts to delete the sole remaining column.

Use concise Neovim notifications, normally at warning level, while keeping the buffer unchanged.

## 12. Filetype behavior

Do not gate functionality on `filetype`.

A valid supported pipe table may be formatted/edited in buffers such as:

- `markdown`
- `text`
- `gitcommit`

## 13. Unsupported behavior / non-goals

The current scope does not include:

- Textile tables.
- reStructuredText grid/simple tables.
- HTML tables.
- Automatic separator-row creation.
- Automatic insertion of missing cells to repair invalid input.
- Automatic repair of inconsistent column counts.
- Escape-aware pipe parsing. `\|` is still split at the pipe.
- Colspan or rowspan.
- Multiline cells.
- Visual-mode range operations.
- Whole-buffer table formatting.
- Default key mappings.

## 14. Test requirements

The automated test suite should continue to cover formatting behavior including:

- basic formatting;
- plain and explicit left alignment;
- center alignment and odd padding;
- right alignment;
- empty cells;
- CJK display width;
- invalid column count;
- missing separator;
- cursor outside a table;
- multiple tables and surrounding text isolation;
- idempotency;
- header-only table;
- filetype independence;
- documented escaped-pipe limitation.

Structural editing tests must cover each row/column operation, including:

- successful mutation;
- first/middle/last applicable positions;
- preservation of other cell content;
- alignment preservation;
- empty-cell creation for add operations;
- invalid/protected delete operations;
- atomic no-change behavior on failure;
- cursor behavior;
- integration through user command and Lua API;
- post-edit canonical formatting;
- CJK tables where relevant.

## 15. Acceptance criteria for column editing

Column editing is complete when all of the following are true:

- [x] Cursor column can be resolved reliably for a supported valid table.
- [x] Add-column inserts immediately to the right of the current column.
- [x] New header/body cells are empty.
- [x] The new separator cell has valid plain-left alignment.
- [x] Delete-column deletes the current logical column from all rows.
- [x] The only remaining column cannot be deleted.
- [x] Existing alignment semantics in unaffected columns remain unchanged.
- [x] CJK-aware formatter behavior remains correct.
- [x] The complete table is replaced atomically.
- [x] Invalid operations leave the buffer unchanged.
- [x] Cursor behavior is controlled and tested.
- [x] Public commands and Lua APIs delegate to common implementation paths.
- [x] Existing format and row-edit tests still pass.
- [x] No runtime dependency is added.
- [x] README/agent documentation reflects public behavior.
