# md_table_formatter.nvim Architecture

## 1. Design goals

The implementation should keep Markdown parsing/formatting logic independently testable while minimizing Neovim-buffer side effects.

Primary architectural properties:

- clear responsibility boundaries;
- one canonical parser/table representation;
- one canonical formatter;
- structural editing implemented as table-model transformations;
- one atomic buffer replacement per successful operation;
- no external runtime dependency;
- CJK-aware width calculation through Neovim.

## 2. Conceptual flow

```text
Neovim command / public Lua API
            |
            v
     operation coordinator
            |
            v
        detector
            |
            v
         parser
            |
            v
        validator
            |
            v
       table model
            |
     +------+------+
     |             |
 formatter       editor
     |        add/delete row
     |        add/delete column
     |             |
     +------v------+
            |
        formatter
            |
            v
   atomic buffer replace
            |
            v
     cursor restoration
```

The exact filenames may differ. Preserve the repository's current module structure if it already expresses these responsibilities cleanly.

## 3. Responsibilities

### Detector

Responsibilities:

- identify the contiguous table candidate containing the cursor;
- provide start/end buffer rows;
- reject obvious non-table lines/candidates;
- avoid any mutation.

Possible module:

```text
lua/table-formatter/detector.lua
```

### Parser / validator

Responsibilities:

- split rows into logical cells under the project's deliberately simple pipe grammar;
- normalize outer structural details without losing empty cells;
- parse separator alignment semantics;
- verify row column counts;
- verify required header/separator structure;
- return explicit structured errors rather than mutate editor state.

Possible module:

```text
lua/table-formatter/parser.lua
```

If parser and validator are currently separate modules, keep them separate.

### Table model

Structural editing benefits from a representation that does not depend on raw buffer strings. Conceptually:

```lua
---@class TableModel
---@field rows string[][]
---@field alignments Alignment[]
---@field explicit_left boolean[]|nil
```

The actual current model should be reused rather than replaced without need.

Important invariant:

```text
#row == column_count
```

for every row in a valid model.

The separator may be represented separately from content rows if that better matches the current implementation.

### Formatter

Responsibilities:

- compute maximum display width per column;
- use `vim.fn.strdisplaywidth()`;
- align header/body cells from separator semantics;
- regenerate valid separator cells;
- produce canonical rows;
- remain deterministic/idempotent;
- avoid buffer mutation.

Possible module:

```text
lua/table-formatter/formatter.lua
```

### Editor

Structural changes should be pure or near-pure transformations of a validated table model.

Recommended interface shape:

```lua
editor.add_row(model, row_index)
editor.delete_row(model, row_index)
editor.add_column(model, column_index)
editor.delete_column(model, column_index)
```

Exact signatures should follow existing repository conventions.

The editor should not:

- calculate padding;
- duplicate separator-rendering code;
- call `nvim_buf_set_lines()` directly;
- notify users directly.

After editing, pass the changed model to the common formatter.

Possible module:

```text
lua/table-formatter/editor.lua
```

## 4. Current row editing

Row add/delete are already implemented capabilities and should be treated as the reference for integrating column editing.

Before changing them:

- inspect the existing modules and tests;
- preserve their public behavior;
- extract shared helpers only when doing so reduces duplication without broad refactoring.

Column editing should reuse the same detection, validation, mutation orchestration, write, notification, and cursor patterns used by row editing.

## 5. Column identification from the cursor

Column operations need a mapping from the Neovim cursor byte column to the logical parsed table cell.

Recommended approach:

1. Read the raw current table row.
2. Identify delimiter boundaries according to the same parsing grammar used by the parser.
3. Map cursor byte position to the cell interval.
4. Normalize edge positions, such as cursor on a pipe or structural space, deterministically.

Important: escaped pipes are not supported, so every pipe remains a delimiter. This makes cursor-to-cell resolution consistent with parsing.

A helper should be shared by add/delete-column rather than duplicating boundary logic.

Suggested deterministic boundary rule if not already defined by the repository:

- cursor inside cell content/padding -> that cell;
- cursor directly on an interior delimiter -> prefer the cell to the right, except the trailing delimiter maps to the last cell;
- cursor on the leading delimiter -> first cell.

If the current code/tests already define another rule, preserve it and document it.

## 6. Add-column transformation

Given valid model `M` and current zero/one-based column `c`:

1. Compute insertion index `c + 1` (right side).
2. Insert an empty header cell.
3. Insert an empty cell in every body row.
4. Insert a new alignment descriptor for plain left alignment.
5. Preserve all existing alignment descriptors unchanged.
6. Format the resulting table with the common formatter.

The transformation must not manually construct padded Markdown strings.

## 7. Delete-column transformation

Given valid model `M` and current column `c`:

1. Reject if `column_count == 1`.
2. Remove cell `c` from the header and every body row.
3. Remove the corresponding alignment descriptor.
4. Format the resulting model using the common formatter.

Failure must occur before any buffer write.

## 8. Editor integration / orchestration

The public operation coordinator should perform approximately:

```lua
local range = detector.detect(bufnr, cursor)
local parsed = parser.parse(lines)
local valid = validator.validate(parsed)
local edited = editor.operation(valid, logical_position)
local output = formatter.format(edited)
replace_once(bufnr, range, output)
restore_cursor(...)
```

Use the project's actual error convention (for example `nil, err`, result objects, etc.). Avoid replacing an established pattern without a concrete need.

## 9. Atomic write

Use one buffer operation for the complete table range, for example the appropriate `vim.api.nvim_buf_set_lines()` call.

Do not write header/body/separator lines separately.

This guarantees that validation/editor/formatting errors cannot leave half-edited tables behind.

## 10. Cursor restoration

Capture before mutation:

- logical table row relative to table start;
- logical column when useful;
- raw byte column as fallback.

After mutation:

- restore the same logical row where possible;
- for add-column, prefer the inserted/new column or a position immediately adjacent according to current UX conventions;
- for delete-column, prefer the nearest remaining column;
- clamp byte column to a valid location.

Cursor computation belongs in integration/orchestration code, not the pure editor or formatter.

## 11. Commands and public API

Command registration should remain thin. Commands should call public Lua functions rather than own implementation logic.

Expected set after column editing is complete:

```text
:TableFormat
:TableAddRow
:TableDeleteRow
:TableAddColumn
:TableDeleteColumn
```

Corresponding API shape:

```lua
local table_formatter = require("table-formatter")

table_formatter.format()
table_formatter.add_row()
table_formatter.delete_row()
table_formatter.add_column()
table_formatter.delete_column()
```

Names should match the repository's existing row-editing APIs if they differ.

## 12. Error boundary

Pure/internal modules should return errors rather than notify directly where practical.

The Neovim-facing layer translates expected errors into concise notifications such as:

```text
No Markdown table found at cursor.
Invalid Markdown table.
Cannot delete the last table column.
```

Expected input errors must not produce an uncontrolled stack trace.

## 13. Testing architecture

### Pure/unit tests

Prefer unit tests for:

- row parsing;
- separator/alignment parsing;
- validation;
- formatter output;
- editor model transformations;
- add-column at first/middle/last current column;
- delete-column at first/middle/last column;
- cannot delete sole column;
- preservation of explicit left/center/right alignment metadata;
- formatter idempotency after transformations.

### Headless Neovim integration tests

Use integration tests for:

- command registration;
- public Lua API;
- cursor-to-column identification;
- correct target table detection when multiple tables exist;
- one-range buffer replacement;
- no mutation on invalid input;
- same logical cursor row after operation;
- CJK display-width formatting after structural editing.

## 14. Change strategy for column editing

Keep the feature reviewable. A sensible implementation sequence is:

1. Add/verify a shared cursor-to-logical-column helper with tests.
2. Add pure add-column/delete-column model transformations with tests.
3. Wire public Lua APIs and commands through existing orchestration.
4. Add integration and cursor tests.
5. Update README and agent/specification documentation.
6. Run the full existing suite and repository lint/format/static checks.

Avoid unrelated refactors. If current architecture already has equivalent helpers, extend them instead of creating parallel abstractions.
