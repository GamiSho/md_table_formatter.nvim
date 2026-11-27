# md_table_formatter.nvim

Format the Markdown pipe table under the cursor in Neovim, with column alignment
and display-width-aware padding for Japanese and other CJK text. The plugin
targets Neovim 0.12.6 and has no external runtime dependencies.

## Installation

Install with any Neovim plugin manager, for example:

```lua
-- lazy.nvim
{ "GamiSho/md_table_formatter.nvim" }
```

No setup call is required. With lazy-loading enabled, configure the manager to
load the plugin for the commands you use or load it before using the Lua API.

## Usage

Place the cursor on a table row and run `:TableFormat` in Normal mode, or call:

```lua
require("table-formatter").format()
```

No default mapping is installed. To add one:

```lua
vim.keymap.set(
  "n",
  "<leader>tf",
  "<cmd>TableFormat<CR>",
  { desc = "Format Markdown table" }
)
```

The command works regardless of buffer filetype. It formats only the contiguous
table under the cursor, preserves the cursor's row, and leaves invalid tables
unchanged with a warning.

### Creating a table

`:TableCreate 2x3` inserts a blank table before the current line, with two body
rows and three columns, plus a header and separator. Both dimensions must be
positive decimal integers no greater than 25. The cursor moves to the first
header cell.

The equivalent Lua API is:

```lua
require("table-formatter").create(2, 3)
```

Creation works with any filetype and can be undone with one `u`. Invalid
dimensions leave the buffer unchanged with a warning.

### Editing rows

`:TableAddRow` inserts an empty row below the current body row. From the header
or separator it inserts the first body row. The cursor moves into its first
cell.

`:TableDeleteRow` deletes the current body row; the header and separator cannot
be deleted. The cursor moves to the next body row, the previous body row if
there is no next row, or the header if no body rows remain.

The corresponding Lua APIs are:

```lua
require("table-formatter").add_row()
require("table-formatter").delete_row()
```

Both operations validate the existing table, format the entire result, and can
each be undone with one `u`. Invalid tables are left unchanged with a warning.
No default mappings are installed; optional mappings include:

```lua
vim.keymap.set("n", "<leader>tr", "<cmd>TableAddRow<CR>", {
  desc = "Add Markdown table row",
})
vim.keymap.set("n", "<leader>tdr", "<cmd>TableDeleteRow<CR>", {
  desc = "Delete Markdown table row",
})
```

### Editing columns

`:TableAddColumn` inserts an empty column immediately to the right of the
column containing the cursor. The new column is left-aligned, and the cursor
moves into it on the same table row.

`:TableDeleteColumn` deletes the column containing the cursor. It cannot delete
the only remaining column; after deletion, the cursor stays on the same row and
moves to the nearest remaining column.

The corresponding Lua API is:

```lua
require("table-formatter").add_column()
require("table-formatter").delete_column()
```

Both operations validate and reformat the entire table before replacing it,
preserve the unaffected columns' alignment, and can each be undone with one
`u`. Invalid tables and attempts to delete the last column are left unchanged
with a warning. No default mappings are installed; optional mappings are:

```lua
vim.keymap.set("n", "<leader>tac", "<cmd>TableAddColumn<CR>", {
  desc = "Add Markdown table column",
})
vim.keymap.set("n", "<leader>tdc", "<cmd>TableDeleteColumn<CR>", {
  desc = "Delete Markdown table column",
})
```

## Supported syntax

A table has a header, an immediately following separator, and zero or more body
rows, all with the same number of cells. Each separator cell requires at least
three hyphens; `---` and `:---` mean left, `:---:` means center, and `---:`
means right. Explicit left colons are preserved. Each candidate row must contain
at least two pipes; outer pipes can be omitted when this condition is met.
Output always has outer pipes and one structural space on each side of a cell.
Widths include the minimum separator width; center padding puts any extra space
on the right. Reformatting the result does not change it.

## Limitations

- Every pipe is a delimiter, including an escaped pipe (`\|`); escaped pipes
  inside cells are not supported.
- Missing separators or cells are not created, and inconsistent column counts
  are not repaired.
- Multiline cells, colspan, and rowspan are not supported.
- Textile, reStructuredText, and HTML tables are not supported.
- Visual ranges and formatting all tables at once are not supported.

## Tests

From the repository root, run the dependency-free headless suite with Neovim:

```sh
nvim --headless -u NONE -c 'luafile tests/run.lua'
```

The suite covers the formatting core and editor integration, including CJK
display columns and idempotency.
