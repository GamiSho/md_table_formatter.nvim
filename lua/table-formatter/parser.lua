local M = {}

function M.is_candidate(line)
  -- Require at least two pipes before treating a line as part of a table.
  local _, pipes = line:gsub("|", "")
  return pipes >= 2
end

function M.parse_row(line)
  line = vim.trim(line)
  -- Ignore optional outer pipes so both Markdown table styles parse alike.
  if line:sub(1, 1) == "|" then
    line = line:sub(2)
  end
  if line:sub(-1) == "|" then
    line = line:sub(1, -2)
  end

  local cells = {}
  for cell in (line .. "|"):gmatch("(.-)|") do
    cells[#cells + 1] = vim.trim(cell)
  end
  return cells
end

function M.column_at(line, cursor_col)
  local trimmed = vim.trim(line)
  local pipe_positions = {}
  local start = 1
  while true do
    local position = line:find("|", start, true)
    if not position then
      break
    end
    pipe_positions[#pipe_positions + 1] = position
    start = position + 1
  end

  local has_leading_pipe = trimmed:sub(1, 1) == "|"
  local has_trailing_pipe = trimmed:sub(-1) == "|"
  local cursor_position = cursor_col + 1
  if has_leading_pipe and cursor_position <= pipe_positions[1] then
    return 1
  end
  if has_trailing_pipe and cursor_position >= pipe_positions[#pipe_positions] then
    return #pipe_positions - (has_leading_pipe and 1 or 0)
  end

  local column = 1
  for _, position in ipairs(pipe_positions) do
    if position <= cursor_position then
      if not (has_leading_pipe and position == pipe_positions[1]) then
        column = column + 1
      end
    end
  end
  return column
end

function M.validate(rows)
  if #rows < 2 then
    return nil, "Invalid Markdown table."
  end

  for i, row in ipairs(rows) do
    if #row == 0 or (i > 1 and #row ~= #rows[1]) then
      return nil, "Invalid Markdown table."
    end
  end

  local alignments = {}
  for i, cell in ipairs(rows[2]) do
    -- The second row defines alignment and must have at least three hyphens.
    local left = cell:sub(1, 1) == ":"
    local right = cell:sub(-1) == ":"
    local hyphens = cell:sub(left and 2 or 1, right and -2 or -1)
    if #hyphens < 3 or not hyphens:match("^%-+$") then
      return nil, "Invalid Markdown table."
    end
    alignments[i] = { left = left, right = right }
  end

  return { rows = rows, alignments = alignments }
end

function M.parse(lines)
  local rows = {}
  for i, line in ipairs(lines) do
    rows[i] = M.parse_row(line)
  end
  return M.validate(rows)
end

return M
