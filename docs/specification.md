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

### 8.5 Reset row contents

New capability.

#### Command

`:TableResetRow`

#### Lua API

```lua
require("table-formatter").reset\_row()
```

Requirements:

* Operate on the valid table containing the cursor.
* Allow the operation only when the cursor is on a body row.
* Replace the content of every cell in the current body row with an empty cell.
* Preserve the row itself and preserve the table's column count.
* Do not modify the header row or separator row.
* Preserve all separator alignment semantics.
* Reformat the complete table through the common canonical formatter after resetting the row.
* Keep the cursor on the same logical body row and, where practical, in the same logical column.
* Perform the complete table replacement atomically so the operation can be undone as one change.
* If the cursor is on the header or separator row, report a controlled warning and leave the buffer unchanged.
* If the table is invalid, report a controlled warning and leave the buffer unchanged.

`TableResetRow` is distinct from deleting a line with Neovim's `dd`: it preserves the body row and clears only its cell contents.

### 8.6 Create blank table

New capability.

#### Command

`:TableCreate {rows}x{columns}`

Example:

```vim
:TableCreate 2x3
```

The example creates one header row, one separator row, and two empty body rows with three columns:

```markdown
|   |   |   |
| --- | --- | --- |
|   |   |   |
|   |   |   |
```

#### Lua API

```lua
require("table-formatter").create(rows, columns)
```

Requirements:

* Parse the command argument in the form `{rows}x{columns}`.
* Treat `rows` as the number of body rows, excluding the header and separator rows.
* Treat `columns` as the number of table columns.
* Require both values to be positive base-10 integers.
* Reject zero, negative, missing, non-numeric, or malformed values with a controlled warning.
* Create one empty header row.
* Create one valid separator row using plain left alignment for every column.
* Create exactly the requested number of empty body rows.
* Generate the table through the common table model and canonical formatter rather than constructing a separate formatting path.
* Insert the complete generated table at the current cursor line using one atomic buffer operation.
* Do not require a Markdown filetype.
* Place the cursor in the first header cell after successful creation.
* Do not add a default key mapping.
* Add no external runtime dependency.

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

## 14. Additional structural editing tests

The automated test suite must also cover row reset and blank-table creation.

Row-reset tests:

* reset a body row at the first, middle, and last body position;
* replace every cell in the target row with an empty cell;
* preserve the row count and column count;
* preserve header content, other body rows, and separator alignment semantics;
* reject reset attempts on the header or separator row;
* leave invalid tables unchanged;
* preserve the logical cursor row and column where practical;
* verify integration through `:TableResetRow` and `reset\_row()`;
* verify post-operation canonical formatting and one-step undo behavior;
* cover CJK content in the reset row and unaffected rows.

Blank-table creation tests:

* create tables with representative dimensions, including `1x1`, `1x3`, and `3x1`;
* verify that `rows` counts body rows and `columns` counts table columns;
* verify empty header and body cells;
* verify plain-left separator semantics for every column;
* reject zero, negative, missing, non-numeric, and malformed dimensions;
* confirm that failed creation leaves the buffer unchanged;
* verify insertion at the cursor line and cursor placement in the first header cell;
* verify integration through `:TableCreate` and `create(rows, columns)`;
* verify canonical formatting, CJK-aware formatter compatibility, filetype independence, and one-step undo behavior.

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

## 16. Acceptance criteria for row reset

Row reset is complete when all of the following are true:

* `:TableResetRow` and `reset\_row()` are available.
* The current body row remains present and all of its cells become empty.
* The header, separator, other body rows, column count, and alignment semantics remain unchanged.
* Header-row and separator-row reset attempts are rejected without buffer modification.
* Invalid tables remain unchanged.
* The complete table is replaced atomically and formatted canonically.
* Cursor behavior is controlled and tested.
* No runtime dependency is added.
* README and agent documentation reflect the public behavior.

## 17. Acceptance criteria for blank-table creation

Blank-table creation is complete when all of the following are true:

* `:TableCreate {rows}x{columns}` and `create(rows, columns)` are available.
* The command creates exactly one header row, one separator row, and the requested number of body rows.
* Every generated row has exactly the requested number of columns.
* All header and body cells are empty.
* Every separator cell uses valid plain-left alignment.
* Invalid dimensions are rejected without buffer modification.
* The generated table uses the common table model and canonical formatter.
* The table is inserted atomically at the cursor line and can be undone in one change.
* The cursor moves to the first header cell.
* The operation is independent of buffer filetype.
* No runtime dependency is added.
* README and agent documentation reflect the public behavior.

