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

function M.parse(lines)
  if #lines < 2 then
    return nil, "Invalid Markdown table."
  end

  local rows = {}
  for i, line in ipairs(lines) do
    rows[i] = M.parse_row(line)
    if #rows[i] == 0 or (i > 1 and #rows[i] ~= #rows[1]) then
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

return M
