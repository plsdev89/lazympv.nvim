local M = {}
local config = require "lazympv.config"
local mpv = require "lazympv.mpv"
local util = require "lazympv.util"

local playlists = config.get_playlists()

M.setup = function()
  if not util.is_command_available "mpv" then
    vim.api.nvim_err_writeln "Error: 'mpv' is not installed. Please install 'mpv'."
    return
  end

  if not util.is_command_available "socat" then
    vim.api.nvim_err_writeln "Error: 'socat' is not installed. Please install 'socat'."
    return
  end

  -- Ensure plugin is only used on macOS
  if not util.is_mac() then
    vim.api.nvim_err_writeln "Warning: This plugin is only tested on macOS. It may not work correctly on other systems."
    return
  end

  config.set_playlists(playlists)
  mpv.start()
  mpv.start_monitoring()

  vim.api.nvim_set_keymap(
    "n",
    "<leader>pp",
    ":lua require('lazympv.ui').toggle()<CR>",
    { noremap = true, silent = true, desc = "Toggle MPV" }
  )
  vim.api.nvim_set_keymap(
    "n",
    "<leader>pq",
    ":lua require('lazympv.mpv').quit()<CR>",
    { noremap = true, silent = true, desc = "Quit MPV" }
  )
  vim.api.nvim_set_keymap(
    "n",
    "<leader>pn",
    ":lua require('lazympv.mpv').next()<CR>",
    { noremap = true, silent = true, desc = "Play Next" }
  )
  vim.api.nvim_set_keymap(
    "n",
    "<leader>pN",
    ":lua require('lazympv.mpv').prev()<CR>",
    { noremap = true, silent = true, desc = "Play Previous" }
  )
end

return M
