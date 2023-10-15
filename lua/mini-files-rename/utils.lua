local M = {}
local Path = require("plenary").path

-- needed for globs like `**/`
local ensure_dir_trailing_slash = function(path, is_dir)
 if is_dir and not path:match "/$" then return path .. "/" end
 return path
end

local get_absolute_path = function(name)
 local path = Path:new(name)
 local is_dir = path:is_dir()
 local absolute_path = ensure_dir_trailing_slash(path:absolute(), is_dir)
 return absolute_path, is_dir
end

local get_regex = function(pattern)
 local regex = vim.fn.glob2regpat(pattern.glob)
 if pattern.options and pattern.options.ignorecase then return "\\c" .. regex end
 return regex
end

-- filter: FileOperationFilter
local match_filter = function(filter, name, is_dir)
 local pattern = filter.pattern
 local match_type = pattern.matches
 if not match_type or (match_type == "folder" and is_dir) or (match_type == "file" and not is_dir) then
  local regex = get_regex(pattern)
  local previous_ignorecase = vim.o.ignorecase
  vim.o.ignorecase = false
  local matched = vim.fn.match(name, regex) ~= -1
  vim.o.ignorecase = previous_ignorecase
  return matched
 end

 return false
end

M.get_nested_path = function(table, keys)
 if #keys == 0 then return table end
 local key = keys[1]
 if table[key] == nil then return nil end
 return M.get_nested_path(table[key], { unpack(keys, 2) })
end

local matches_filters = function(filters, name)
 local absolute_path, is_dir = get_absolute_path(name)
 for _, filter in pairs(filters) do
  if match_filter(filter, absolute_path, is_dir) then return true end
 end
 return false
end

local function getWorkspaceEdit(client, old_name, new_name)
 local will_rename_params = {
  files = {
   {
    oldUri = "file://" .. old_name,
    newUri = "file://" .. new_name,
   },
  },
 }
 local timeout_ms = 1000
 local success, resp = pcall(client.request_sync, "workspace/willRenameFiles", will_rename_params, timeout_ms)
 if not success then return nil end
 if resp == nil or resp.result == nil then return nil end
 return resp.result
end

M.callback = function(data)
 for _, client in pairs(vim.lsp.get_active_clients()) do
  local will_rename =
      M.get_nested_path(client, { "server_capabilities", "workspace", "fileOperations", "willRename" })
  if will_rename ~= nil then
   local filters = will_rename.filters or {}
   if matches_filters(filters, data.old_name) then
    local edit = getWorkspaceEdit(client, data.old_name, data.new_name)
    if edit ~= nil then vim.lsp.util.apply_workspace_edit(edit, client.offset_encoding) end
   end
  end
 end
end
return M
