local M = {}

M.is_command_available = function(command)
  local result = vim.fn.system("command -v " .. command)
  return vim.fn.empty(result) == 0 -- returns true if command is found
end

-- Function to check if the system is macOS
M.is_mac = function()
  local os_type = vim.fn.system "uname"
  return os_type:match "Darwin" ~= nil -- checks if it's macOS
end

return M
