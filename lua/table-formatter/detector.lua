local parser = require("table-formatter.parser")

local M = {}

function M.find(lines, cursor_row)
  if not lines[cursor_row] or not parser.is_candidate(lines[cursor_row]) then
    return nil, "No Markdown table found at cursor."
  end

  local first, last = cursor_row, cursor_row
  while first > 1 and parser.is_candidate(lines[first - 1]) do
    first = first - 1
  end
  while last < #lines and parser.is_candidate(lines[last + 1]) do
    last = last + 1
  end
  return first, last
end

return M
