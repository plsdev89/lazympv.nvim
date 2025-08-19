local M = {}
local mpv = require("lazympv.mpv")
local config = require("lazympv.config")
local buf, win

M.toggle = function()
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_close(win, true)
		win = nil
		return
	end

	mpv.start()
	mpv.start_monitoring()
	buf = vim.api.nvim_create_buf(false, true) -- No file, no swap

	local width = 65
	local playlists = config.get_playlists()
	local height = math.min(#playlists + 2, 10)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
	})

	local lines = { "LazyMPV", "-----------------------------------------------------------------" }
	for i, playlist in ipairs(playlists) do
		table.insert(lines, string.format("%d. %s", i, playlist.title))
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	vim.bo[buf].modifiable = false -- Make buffer read-only
	vim.bo[buf].bufhidden = "wipe" -- Remove buffer when not in use
	vim.bo[buf].buftype = "nofile" -- Set buffer type to 'nofile'

	vim.wo[win].cursorline = true
	-- Hide cursor
	-- Mose cursor to 3th line
	local current_playlist_index = config.get_last_played_index()
	if current_playlist_index <= #playlists then
		vim.api.nvim_win_set_cursor(win, { current_playlist_index + 2, 0 })
	else
		vim.api.nvim_win_set_cursor(win, { 3, 0 })
		config.set_last_played_index(3)
	end

	vim.api.nvim_buf_set_keymap(
		buf,
		"n",
		"<CR>",
		":lua require('lazympv.ui').play_selected()<CR>",
		{ noremap = true, silent = true, nowait = true, desc = "Start" }
	)
	vim.api.nvim_buf_set_keymap(
		buf,
		"n",
		"q",
		":lua require('lazympv.ui').toggle()<CR>",
		{ noremap = true, silent = true, nowait = true, desc = "Close" }
	)
	vim.api.nvim_buf_set_keymap(
		buf,
		"n",
		"a",
		":lua require('lazympv.ui').add_song()<CR>",
		{ noremap = true, silent = true, nowait = true, desc = "Add Song" }
	)
end

M.play_selected = function()
	if not win or not vim.api.nvim_win_is_valid(win) then
		return
	end

	local cursor = vim.api.nvim_win_get_cursor(win)
	local line = cursor[1] - 2 -- Adjust for title and separator lines

	local playlists = config.get_playlists()
	if line > 0 and line <= #playlists then
		vim.api.nvim_win_close(win, true)
		mpv.play(playlists[line].url)
		config.set_last_played_index(line)
	end
end

M.add_song = function()
	-- Prompt for title
	local title = vim.fn.input("Enter song title: ")
	if title == "" then
		vim.api.nvim_echo({ { "Cancelled: No title provided", "WarningMsg" } }, true, {})
		return
	end

	-- Prompt for URL
	local url = vim.fn.input("Enter song URL: ")
	if url == "" then
		vim.api.nvim_echo({ { "Cancelled: No URL provided", "WarningMsg" } }, true, {})
		return
	end

	-- Save the song
	local success = config.add_song(title, url)
	if success then
		vim.api.nvim_echo({ { "Song added successfully!", "String" } }, true, {})
		-- Refresh the playlist window if it's open
		if win and vim.api.nvim_win_is_valid(win) then
			M.refresh_playlist()
		end
	else
		vim.api.nvim_echo({ { "Failed to add song", "ErrorMsg" } }, true, {})
	end
end

M.refresh_playlist = function()
	if not win or not vim.api.nvim_win_is_valid(win) then
		return
	end

	local playlists = config.get_playlists()
	local lines = { "LazyMPV", "-----------------------------------------------------------------" }
	for i, playlist in ipairs(playlists) do
		table.insert(lines, string.format("%d. %s", i, playlist.title))
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

return M
