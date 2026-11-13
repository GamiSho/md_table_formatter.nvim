local parser = require("table-formatter.parser")

local M = {}

-- Format parsed rows while preserving each column's alignment.
function M.format(lines)
  local table_data, err = parser.parse(lines)
  if not table_data then
    return nil, err
  end

  local rows, alignments = table_data.rows, table_data.alignments
  local widths = {}
  -- Measure the widest cell in each column, excluding the separator row.
  for i, alignment in ipairs(alignments) do
    widths[i] = 3 + (alignment.left and 1 or 0) + (alignment.right and 1 or 0)
    for row_index, row in ipairs(rows) do
      if row_index ~= 2 then
        widths[i] = math.max(widths[i], vim.fn.strdisplaywidth(row[i]))
      end
    end
  end

  local output = {}
  for row_index, row in ipairs(rows) do
    local cells = {}
    for i, cell in ipairs(row) do
      local alignment = alignments[i]
      if row_index == 2 then
        -- Keep the separator wide enough for the column and its alignment markers.
        local colon_width = (alignment.left and 1 or 0) + (alignment.right and 1 or 0)
        cells[i] = (alignment.left and ":" or "")
          .. string.rep("-", widths[i] - colon_width)
          .. (alignment.right and ":" or "")
      else
        local padding = widths[i] - vim.fn.strdisplaywidth(cell)
        local left_padding = 0
        -- Center alignment splits padding; right alignment puts it all before the cell.
        if alignment.right then
          left_padding = alignment.left and math.floor(padding / 2) or padding
        end
        cells[i] = string.rep(" ", left_padding) .. cell .. string.rep(" ", padding - left_padding)
      end
    end
    output[row_index] = "| " .. table.concat(cells, " | ") .. " |"
  end
  return output
end

return M
