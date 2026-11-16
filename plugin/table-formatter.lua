vim.api.nvim_create_user_command("TableFormat", function()
  require("table-formatter").format()
end, {})

vim.api.nvim_create_user_command("TableAddRow", function()
  require("table-formatter").add_row()
end, {})

vim.api.nvim_create_user_command("TableDeleteRow", function()
  require("table-formatter").delete_row()
end, {})
