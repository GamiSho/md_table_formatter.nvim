local detector = require("table-formatter.detector")
local formatter = require("table-formatter.formatter")
local parser = require("table-formatter.parser")

local M = {}

function M.format()
  local buffer = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
  -- Locate the table around the cursor before attempting to format it.
  local first, last = detector.find(lines, cursor[1])
  if not first then
    vim.notify(last, vim.log.levels.WARN)
    return false
  end

  local table_lines = {}
  for i = first, last do
    table_lines[#table_lines + 1] = lines[i]
  end
  local output, err = formatter.format(table_lines)
  if not output then
    vim.notify(err, vim.log.levels.WARN)
    return false
  end

  -- Report buffer update errors rather than leaving the user without feedback.
  local ok = pcall(vim.api.nvim_buf_set_lines, buffer, first - 1, last, false, output)
  if not ok then
    vim.notify("Could not format Markdown table.", vim.log.levels.WARN)
    return false
  end
  vim.api.nvim_win_set_cursor(0, { cursor[1], math.min(cursor[2], #output[cursor[1] - first + 1]) })
  return true
end

local function edit_row(add)
  local buffer = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
  local first, last = detector.find(lines, cursor[1])
  if not first then
    vim.notify(last, vim.log.levels.WARN)
    return false
  end

  local table_lines = {}
  for i = first, last do
    table_lines[#table_lines + 1] = lines[i]
  end
  local table_data, err = parser.parse(table_lines)
  if not table_data then
    vim.notify(err, vim.log.levels.WARN)
    return false
  end

  local rows = table_data.rows
  local row = cursor[1] - first + 1
  if add then
    row = math.max(row, 2) + 1
    local cells = {}
    for i = 1, #rows[1] do
      cells[i] = ""
    end
    table.insert(rows, row, cells)
  else
    if row <= 2 then
      vim.notify("Cannot delete the header or separator row.", vim.log.levels.WARN)
      return false
    end
    table.remove(rows, row)
    row = #rows == 2 and 1 or math.min(row, #rows)
  end

  local output
  output, err = formatter.format_rows(rows)
  if not output then
    vim.notify(err, vim.log.levels.WARN)
    return false
  end
  local ok = pcall(vim.api.nvim_buf_set_lines, buffer, first - 1, last, false, output)
  if not ok then
    vim.notify("Could not edit Markdown table.", vim.log.levels.WARN)
    return false
  end
  vim.api.nvim_win_set_cursor(0, { first + row - 1, 2 })
  return true
end

function M.add_row()
  return edit_row(true)
end

function M.delete_row()
  return edit_row(false)
end

return M
