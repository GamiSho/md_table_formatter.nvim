local detector = require("table-formatter.detector")
local formatter = require("table-formatter.formatter")
local parser = require("table-formatter.parser")

local M = {}

function M.create(rows, columns)
  local function positive_integer(value)
    return type(value) == "number" and value > 0 and value < math.huge and value == math.floor(value)
  end

  if not positive_integer(rows) or not positive_integer(columns) then
    vim.notify("Table dimensions must be positive integers.", vim.log.levels.WARN)
    return false
  end

  local table_rows = {}
  for row = 1, rows + 2 do
    local cells = {}
    for column = 1, columns do
      cells[column] = row == 2 and "---" or ""
    end
    table_rows[row] = cells
  end

  local output, err = formatter.format_rows(table_rows)
  if not output then
    vim.notify(err, vim.log.levels.WARN)
    return false
  end

  local buffer = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local ok = pcall(vim.api.nvim_buf_set_lines, buffer, cursor[1] - 1, cursor[1] - 1, false, output)
  if not ok then
    vim.notify("Could not create Markdown table.", vim.log.levels.WARN)
    return false
  end
  vim.api.nvim_win_set_cursor(0, { cursor[1], 2 })
  return true
end

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

function M.add_column()
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

  local row = cursor[1] - first + 1
  local column = parser.column_at(lines[cursor[1]], cursor[2])
  local insertion = column + 1
  for row_index, cells in ipairs(table_data.rows) do
    table.insert(cells, insertion, row_index == 2 and "---" or "")
  end

  local output
  output, err = formatter.format_rows(table_data.rows)
  if not output then
    vim.notify(err, vim.log.levels.WARN)
    return false
  end
  local ok = pcall(vim.api.nvim_buf_set_lines, buffer, first - 1, last, false, output)
  if not ok then
    vim.notify("Could not edit Markdown table.", vim.log.levels.WARN)
    return false
  end

  local pipe = 0
  for _ = 1, insertion do
    pipe = output[row]:find("|", pipe + 1, true)
  end
  vim.api.nvim_win_set_cursor(0, { cursor[1], pipe + 1 })
  return true
end

function M.delete_column()
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

  local column = parser.column_at(lines[cursor[1]], cursor[2])
  if #table_data.rows[1] == 1 then
    vim.notify("Cannot delete the last table column.", vim.log.levels.WARN)
    return false
  end

  for _, row in ipairs(table_data.rows) do
    table.remove(row, column)
  end

  local output
  output, err = formatter.format_rows(table_data.rows)
  if not output then
    vim.notify(err, vim.log.levels.WARN)
    return false
  end
  local ok = pcall(vim.api.nvim_buf_set_lines, buffer, first - 1, last, false, output)
  if not ok then
    vim.notify("Could not edit Markdown table.", vim.log.levels.WARN)
    return false
  end

  local row = cursor[1] - first + 1
  local remaining_column = math.min(column, #table_data.rows[1])
  local pipe = 0
  for _ = 1, remaining_column do
    pipe = output[row]:find("|", pipe + 1, true)
  end
  vim.api.nvim_win_set_cursor(0, { cursor[1], pipe + 1 })
  return true
end

function M.add_row()
  return edit_row(true)
end

function M.delete_row()
  return edit_row(false)
end

return M
