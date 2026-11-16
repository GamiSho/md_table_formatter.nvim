vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.cmd("runtime plugin/table-formatter.lua")

local formatter = require("table-formatter.formatter")
local parser = require("table-formatter.parser")
local api = require("table-formatter")
local tests = {}

local function equal(actual, expected)
  assert(vim.deep_equal(actual, expected),
    "expected " .. vim.inspect(expected) .. ", got " .. vim.inspect(actual))
end

local function formatted(lines)
  local result, err = formatter.format(lines)
  assert(result, err)
  return result
end

local function assert_pipes_align(lines)
  local expected
  for _, line in ipairs(lines) do
    local positions, start = {}, 1
    while true do
      local position = line:find("|", start, true)
      if not position then
        break
      end
      positions[#positions + 1] = vim.fn.strdisplaywidth(line:sub(1, position - 1))
      start = position + 1
    end
    if expected then
      equal(positions, expected)
    else
      expected = positions
    end
  end
end

local basic = { "|Name|Age|", "|---|---|", "|Alice|20|" }
local cjk = { "|Language|Greeting|", "|---|---|", "|日本語|こんにちは|", "|English|Hello|" }
local example = {
  "|-            || update | commit | checkout |",
  "|---|---|:---|:---:|---:|",
  "git||pull / fetch > merge|commit / push|clone",
  "hg ||pull > update|commit / push|clone",
}

function tests.basic()
  equal(formatted(basic), { "| Name  | Age |", "| ----- | --- |", "| Alice | 20  |" })
end

function tests.alignment()
  equal(formatted({ "|Name|", "|:---|", "|Alice|" }), {
    "| Name  |", "| :---- |", "| Alice |",
  })
  equal(formatted({ "|ab|", "|:---:|", "|x|" }), {
    "|  ab   |", "| :---: |", "|   x   |",
  })
  equal(formatted({ "|Price|", "|---:|", "|100|" }), {
    "| Price |", "| ----: |", "|   100 |",
  })
end

function tests.empty_cells()
  equal(formatted({ "|A||C|", "|---|---|---|", "|1||3|" }), {
    "| A   |     | C   |", "| --- | --- | --- |", "| 1   |     | 3   |",
  })
end

function tests.cjk()
  assert_pipes_align(formatted(cjk))
end

function tests.invalid_tables()
  local invalid = {
    { "|A|B|C|", "|---|---|---|", "|1|2|" },
    { "|A|B|", "|1|2|" },
    { "|A|", "|--|" },
    { "|A|", "|:---::|" },
    { "|A|", "|---|" , "|1|2|" },
  }
  for _, lines in ipairs(invalid) do
    local before = vim.deepcopy(lines)
    local result, err = formatter.format(lines)
    equal(result, nil)
    equal(err, "Invalid Markdown table.")
    equal(lines, before)
  end
end

function tests.header_only()
  equal(formatted({ "|A|B|", "|---|---|" }), { "| A   | B   |", "| --- | --- |" })
end

function tests.escaped_pipe_is_delimiter()
  equal(parser.parse_row([[|a\|b|]]), { [[a\]], "b" })
  local result = formatted({ [[|a\|b|]], "|---|---|" })
  equal(result, { [[| a\  | b   |]], "| --- | --- |" })
end

function tests.idempotency()
  for _, fixture in ipairs({ basic, cjk, example, { "|ab||X|", "|:---:|:---|---:|", "|z||1|" } }) do
    local once = formatted(fixture)
    equal(formatted(once), once)
  end
end

function tests.required_example_conflict()
  local original = vim.deepcopy(example)
  original[2] = "|-||:-|:-:|-:|"
  local result, err = formatter.format(original)
  equal(result, nil)
  equal(err, "Invalid Markdown table.")

  local output = formatted(example)
  assert_pipes_align(output)
  local parsed = assert(parser.parse(output))
  equal(parsed.alignments, {
    { left = false, right = false }, { left = false, right = false },
    { left = true, right = false }, { left = true, right = true },
    { left = false, right = true },
  })
  equal(parsed.rows[3], { "git", "", "pull / fetch > merge", "commit / push", "clone" })
  equal(parsed.rows[4], { "hg", "", "pull > update", "commit / push", "clone" })
end

local function set_buffer(lines, row, col)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, { row, col or 0 })
end

function tests.integration()
  equal(vim.fn.exists(":TableFormat"), 2)
  equal(type(api.format), "function")
  equal(vim.fn.maparg("<leader>tf", "n"), "")
  local input = {
    "Before", "", "|X|", "|---|", "|Y|", "", "Text",
    "|Name|Age|", "|---|---|", "|Alice|20|", "", "After",
  }
  for row = 8, 10 do
    set_buffer(input, row, 0)
    vim.cmd("TableFormat")
    equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), {
      "Before", "", "|X|", "|---|", "|Y|", "", "Text",
      "| Name  | Age |", "| ----- | --- |", "| Alice | 20  |", "", "After",
    })
    equal(vim.api.nvim_win_get_cursor(0)[1], row)
  end

  for _, filetype in ipairs({ "markdown", "text", "gitcommit" }) do
    set_buffer(cjk, 3, 0)
    vim.bo.filetype = filetype
    assert(api.format())
    equal(vim.api.nvim_win_get_cursor(0)[1], 3)
    assert_pipes_align(vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end

  set_buffer({ "|A               |", "|---|", "|x|" }, 1, 15)
  assert(api.format())
  equal(vim.api.nvim_win_get_cursor(0), { 1, 6 })
end

function tests.integration_errors()
  local notifications = {}
  local original_notify = vim.notify
  vim.notify = function(message, level)
    notifications[#notifications + 1] = { message, level }
  end
  local ok, err = pcall(function()
    local outside = { "prose | more prose", "", "|A|", "|---|" }
    set_buffer(outside, 1)
    assert(not api.format())
    equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), outside)
    equal(notifications[#notifications], { "No Markdown table found at cursor.", vim.log.levels.WARN })

    for _, invalid in ipairs({
      { "|A|B|C|", "|---|---|---|", "|1|2|" },
      { "|A|B|", "|1|2|" },
      { "|A|", "|--|" },
    }) do
      set_buffer(invalid, #invalid)
      assert(not api.format())
      equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), invalid)
      equal(notifications[#notifications], { "Invalid Markdown table.", vim.log.levels.WARN })
    end
  end)
  vim.notify = original_notify
  assert(ok, err)
end

function tests.add_rows()
  equal(vim.fn.exists(":TableAddRow"), 2)
  equal(type(api.add_row), "function")
  local input = { "|Name|Age|", "|:---|---:|", "|Alice|20|", "|Bob|30|" }
  for _, row in ipairs({ 1, 2, 3, 4 }) do
    set_buffer(input, row)
    if row == 1 then
      vim.cmd("TableAddRow")
    else
      assert(api.add_row())
    end
    local result = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local inserted = math.max(row, 2) + 1
    equal(vim.api.nvim_win_get_cursor(0), { inserted, 2 })
    local parsed = assert(parser.parse(result))
    equal(parsed.rows[inserted], { "", "" })
    equal(parsed.alignments, {
      { left = true, right = false }, { left = false, right = true },
    })
    equal(formatted(result), result)
  end

  set_buffer({ "|A|B|", "|---|---|" }, 1)
  assert(api.add_row())
  equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), {
    "| A   | B   |", "| --- | --- |", "|     |     |",
  })
  equal(vim.api.nvim_win_get_cursor(0), { 3, 2 })
end

function tests.delete_rows()
  equal(vim.fn.exists(":TableDeleteRow"), 2)
  equal(type(api.delete_row), "function")
  local input = { "|A|", "|---|", "|first|", "|middle|", "|last|" }
  for _, case in ipairs({
    { row = 3, expected = { "A", "middle", "last" }, cursor = 3 },
    { row = 4, expected = { "A", "first", "last" }, cursor = 4 },
    { row = 5, expected = { "A", "first", "middle" }, cursor = 4 },
  }) do
    set_buffer(input, case.row)
    if case.row == 3 then
      vim.cmd("TableDeleteRow")
    else
      assert(api.delete_row())
    end
    local result = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local parsed = assert(parser.parse(result))
    local cells = {}
    for i, row in ipairs(parsed.rows) do
      if i ~= 2 then
        cells[#cells + 1] = row[1]
      end
    end
    equal(cells, case.expected)
    equal(vim.api.nvim_win_get_cursor(0), { case.cursor, 2 })
    equal(formatted(result), result)
  end

  set_buffer({ "|A|", "|---|", "|only|" }, 3)
  assert(api.delete_row())
  equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "| A   |", "| --- |" })
  equal(vim.api.nvim_win_get_cursor(0), { 1, 2 })
end

function tests.row_edit_errors()
  local original_notify = vim.notify
  local notifications = {}
  vim.notify = function(message, level)
    notifications[#notifications + 1] = { message, level }
  end
  local ok, err = pcall(function()
    local valid = { "|A|", "|---|", "|x|" }
    for _, row in ipairs({ 1, 2 }) do
      set_buffer(valid, row)
      assert(not api.delete_row())
      equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), valid)
      equal(notifications[#notifications], {
        "Cannot delete the header or separator row.", vim.log.levels.WARN,
      })
    end
    for _, operation in ipairs({ api.add_row, api.delete_row }) do
      for _, invalid in ipairs({
        { "|A|B|", "|---|---|", "|1|" },
        { "|A|", "|--|", "|x|" },
      }) do
        set_buffer(invalid, #invalid)
        assert(not operation())
        equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), invalid)
        equal(notifications[#notifications], { "Invalid Markdown table.", vim.log.levels.WARN })
      end
      set_buffer({ "outside" }, 1)
      assert(not operation())
      equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "outside" })
      equal(notifications[#notifications], { "No Markdown table found at cursor.", vim.log.levels.WARN })
    end
  end)
  vim.notify = original_notify
  assert(ok, err)
end

function tests.row_edit_isolation_and_undo()
  local input = {
    "Before", "|X|", "|---|", "|Y|", "", "Text",
    "|Name|Age|", "|---|---|", "|Alice|20|", "", "After",
  }
  for _, command in ipairs({ "TableAddRow", "TableDeleteRow" }) do
    set_buffer(input, 9)
    vim.cmd("let &undolevels = &undolevels")
    vim.cmd(command)
    local result = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    equal(vim.list_slice(result, 1, 6), vim.list_slice(input, 1, 6))
    equal(result[#result - 1], "")
    equal(result[#result], "After")
    vim.cmd("undo")
    equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), input)
    vim.cmd(command)
    local before_format = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert(api.format())
    equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), before_format)
  end
end

local names = {}
for name in pairs(tests) do
  names[#names + 1] = name
end
table.sort(names)
local failed = 0
for _, name in ipairs(names) do
  local ok, err = xpcall(tests[name], debug.traceback)
  if ok then
    print("PASS " .. name)
  else
    failed = failed + 1
    print("FAIL " .. name .. "\n" .. err)
  end
end
print(("%d tests, %d failures"):format(#names, failed))
if failed > 0 then
  vim.cmd("cquit 1")
else
  vim.cmd("qa!")
end
