vim.api.nvim_create_user_command("TableFormat", function()
  require("table-formatter").format()
end, {})

vim.api.nvim_create_user_command("TableCreate", function(opts)
  local rows, columns = opts.args:match("^(%d+)x(%d+)$")
  require("table-formatter").create(tonumber(rows), tonumber(columns))
end, { nargs = "*" })

vim.api.nvim_create_user_command("TableAddRow", function()
  require("table-formatter").add_row()
end, {})

vim.api.nvim_create_user_command("TableDeleteRow", function()
  require("table-formatter").delete_row()
end, {})

vim.api.nvim_create_user_command("TableResetRow", function()
  require("table-formatter").reset_row()
end, {})

vim.api.nvim_create_user_command("TableAddColumn", function()
  require("table-formatter").add_column()
end, {})

vim.api.nvim_create_user_command("TableDeleteColumn", function()
  require("table-formatter").delete_column()
end, {})
