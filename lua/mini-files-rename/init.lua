local u = require(".utils")


local M = {}

M.config = function()
 vim.api.nvim_create_autocmd("User", {
  pattern = "MiniFilesActionRename",
  callback = function(args)
   local old_name = args.data.from
   local new_name = args.data.to
   u.callback { old_name = old_name, new_name = new_name }
  end,
 })
end
