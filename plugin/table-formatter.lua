vim.api.nvim_create_user_command("TableFormat", function()
  require("table-formatter").format()
end, {})
