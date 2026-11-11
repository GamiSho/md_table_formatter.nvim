local detector = require("table-formatter.detector")
local formatter = require("table-formatter.formatter")

local M = {}

function M.format()
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
  local output, err = formatter.format(table_lines)
  if not output then
    vim.notify(err, vim.log.levels.WARN)
    return false
  end

  local ok = pcall(vim.api.nvim_buf_set_lines, buffer, first - 1, last, false, output)
  if not ok then
    vim.notify("Could not format Markdown table.", vim.log.levels.WARN)
    return false
  end
  vim.api.nvim_win_set_cursor(0, { cursor[1], math.min(cursor[2], #output[cursor[1] - first + 1]) })
  return true
end

return M
