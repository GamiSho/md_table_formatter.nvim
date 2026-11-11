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

```lua
-- packer.nvim
use "GamiSho/md_table_formatter.nvim"
```

No setup call is required. With lazy-loading enabled, configure the manager to
load the plugin for `TableFormat` or load it before using the Lua API.

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
