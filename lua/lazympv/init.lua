local M = {}
local config = require "lazympv.config"

M.setup = function(user_config)
  -- Setup configuration
  config.setup(user_config)

  -- Initialize playlists
  local playlists = config.get_playlists()
  if not config.set_playlists(playlists) then
    vim.notify("Failed to initialize playlists", vim.log.levels.ERROR)
    return
  end

  -- Setup keybindings from config
  local keybindings = config.config.keybindings

  vim.api.nvim_set_keymap(
    "n",
    keybindings.toggle,
    ":lua require('lazympv.ui').toggle()<CR>",
    { noremap = true, silent = true, desc = "Toggle MPV" }
  )
  vim.api.nvim_set_keymap(
    "n",
    keybindings.quit,
    ":lua require('lazympv.mpv').quit()<CR>",
    { noremap = true, silent = true, desc = "Quit MPV" }
  )
  vim.api.nvim_set_keymap(
    "n",
    keybindings.next,
    ":lua require('lazympv.mpv').next()<CR>",
    { noremap = true, silent = true, desc = "Play Next" }
  )
  vim.api.nvim_set_keymap(
    "n",
    keybindings.prev,
    ":lua require('lazympv.mpv').prev()<CR>",
    { noremap = true, silent = true, desc = "Play Previous" }
  )
  vim.api.nvim_set_keymap(
    "n",
    keybindings.add_song,
    ":lua require('lazympv.ui').add_song()<CR>",
    { noremap = true, silent = true, desc = "Add Song" }
  )
  vim.api.nvim_set_keymap(
    "n",
    keybindings.reset_playlist,
    ":lua require('lazympv.ui').reset_playlist()<CR>",
    { noremap = true, silent = true, desc = "Reset Playlist" }
  )
end

return M
