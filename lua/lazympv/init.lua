local M = {}
local config = require("lazympv.config")

M.setup = function()
	local playlists = config.get_playlists()
	config.set_playlists(playlists)
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
