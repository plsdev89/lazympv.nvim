local M = {}
local mpv = require("lazympv.mpv")
local config = require("lazympv.config")
local buf, win

-- Expose win variable for external access
M.win = win

M.toggle = function()
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_close(win, true)
		win = nil
		M.win = nil
		-- Stop monitoring when UI is closed
		if mpv.monitoring_job then
			vim.fn.jobstop(mpv.monitoring_job)
			mpv.monitoring_job = nil
		end
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
	M.win = win

	local lines = { "LazyMPV", "-----------------------------------------------------------------" }
	for i, playlist in ipairs(playlists) do
		table.insert(lines, string.format("%d. %s", i, playlist.title))
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	vim.bo[buf].modifiable = false -- Make buffer read-only
	vim.bo[buf].bufhidden = "wipe" -- Remove buffer when not in use
	vim.bo[buf].buftype = "nofile" -- Set buffer type to 'nofile'

	vim.wo[win].cursorline = true
	-- Move cursor to current track
	local current_playlist_index = config.get_last_played_index()
	if current_playlist_index <= #playlists then
		vim.api.nvim_win_set_cursor(win, { current_playlist_index + 2, 0 })
	else
		vim.api.nvim_win_set_cursor(win, { 3, 0 })
		config.set_last_played_index(1)
	end

	vim.api.nvim_buf_set_keymap(
		buf,
		"n",
		"<CR>",
		":lua require('lazympv.ui').play_selected()<CR>",
		{ noremap = true, silent = true, nowait = true, desc = "Play selected song" }
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
	vim.api.nvim_buf_set_keymap(
		buf,
		"n",
		"d",
		":lua require('lazympv.ui').delete_song()<CR>",
		{ noremap = true, silent = true, nowait = true, desc = "Delete Song" }
	)
	vim.api.nvim_buf_set_keymap(
		buf,
		"n",
		"r",
		":lua require('lazympv.ui').edit_song()<CR>",
		{ noremap = true, silent = true, nowait = true, desc = "Edit Song" }
	)
end

M.play_selected = function()
	if not win or not vim.api.nvim_win_is_valid(win) then
		vim.notify("UI window is not available", vim.log.levels.WARN)
		return
	end

	local cursor = vim.api.nvim_win_get_cursor(win)
	local line = cursor[1] - 2 -- Adjust for title and separator lines

	local playlists = config.get_playlists()
	if not playlists or #playlists == 0 then
		vim.notify("No playlists available", vim.log.levels.WARN)
		return
	end

	if line > 0 and line <= #playlists then
		vim.api.nvim_win_close(win, true)
		win = nil
		M.win = nil
		buf = nil

		if mpv.play(playlists[line].url) then
			config.set_last_played_index(line)
		else
			vim.notify("Failed to play track", vim.log.levels.ERROR)
		end
	else
		vim.notify("Invalid track selection", vim.log.levels.WARN)
	end
end

M.add_song = function()
	-- Prompt for title
	local title = vim.fn.input("Enter song title: ")
	if title == "" then
		vim.notify("Cancelled: No title provided", vim.log.levels.WARN)
		return
	end

	-- Prompt for URL
	local url = vim.fn.input("Enter song URL: ")
	if url == "" then
		vim.notify("Cancelled: No URL provided", vim.log.levels.WARN)
		return
	end

	-- Save the song (validation happens in config.add_song)
	local success = config.add_song(title, url)
	if success then
		vim.notify("Song added successfully!", vim.log.levels.INFO)
		-- Refresh the playlist window if it's open
		if win and vim.api.nvim_win_is_valid(win) then
			M.refresh_playlist()
		end
	else
		vim.notify("Failed to add song", vim.log.levels.ERROR)
	end
end

M.delete_song = function()
	if not win or not vim.api.nvim_win_is_valid(win) then
		vim.notify("UI window is not available", vim.log.levels.WARN)
		return
	end

	local cursor = vim.api.nvim_win_get_cursor(win)
	local line = cursor[1] - 2 -- Adjust for title and separator lines

	local playlists = config.get_playlists()
	if not playlists or #playlists == 0 then
		vim.notify("No playlists available to delete from", vim.log.levels.WARN)
		return
	end

	-- Prevent deletion if only one song remains
	if #playlists == 1 then
		vim.notify("Cannot delete the last song in playlist", vim.log.levels.WARN)
		return
	end

	if line > 0 and line <= #playlists then
		local song_title = playlists[line].title
		
		-- Confirm deletion
		local confirm = vim.fn.input("Delete '" .. song_title .. "'? (y/N): ")
		if confirm:lower() == "y" or confirm:lower() == "yes" then
			local success = config.delete_song(line)
			if success then
				vim.notify("Song deleted successfully!", vim.log.levels.INFO)
				-- Refresh the playlist window
				M.refresh_playlist()
				-- Adjust cursor position if needed
				local new_playlists = config.get_playlists()
				if new_playlists and #new_playlists > 0 then
					if line > #new_playlists then
						vim.api.nvim_win_set_cursor(win, { #new_playlists + 2, 0 })
					end
				else
					-- No songs left, close the window
					vim.api.nvim_win_close(win, true)
					win = nil
					M.win = nil
					buf = nil
				end
			else
				vim.notify("Failed to delete song", vim.log.levels.ERROR)
			end
		else
			vim.notify("Deletion cancelled", vim.log.levels.INFO)
		end
	else
		vim.notify("Invalid track selection for deletion", vim.log.levels.WARN)
	end
end

M.edit_song = function()
	if not win or not vim.api.nvim_win_is_valid(win) then
		vim.notify("UI window is not available", vim.log.levels.WARN)
		return
	end

	local cursor = vim.api.nvim_win_get_cursor(win)
	local line = cursor[1] - 2 -- Adjust for title and separator lines

	local playlists = config.get_playlists()
	if not playlists or #playlists == 0 then
		vim.notify("No playlists available to edit", vim.log.levels.WARN)
		return
	end

	if line > 0 and line <= #playlists then
		local current_song = playlists[line]
		
		-- Prompt for new title (with current title as default)
		local new_title = vim.fn.input("Enter new title: ", current_song.title)
		if new_title == "" then
			vim.notify("Cancelled: No title provided", vim.log.levels.WARN)
			return
		end

		-- Prompt for new URL (with current URL as default)
		local new_url = vim.fn.input("Enter new URL: ", current_song.url)
		if new_url == "" then
			vim.notify("Cancelled: No URL provided", vim.log.levels.WARN)
			return
		end

		-- Edit the song
		local success = config.edit_song(line, new_title, new_url)
		if success then
			vim.notify("Song edited successfully!", vim.log.levels.INFO)
			-- Refresh the playlist window
			M.refresh_playlist()
		else
			vim.notify("Failed to edit song", vim.log.levels.ERROR)
		end
	else
		vim.notify("Invalid track selection for editing", vim.log.levels.WARN)
	end
end

M.reset_playlist = function()
	-- Confirm reset
	local confirm = vim.fn.input("Reset playlist to default? This will remove all current songs. (y/N): ")
	if confirm:lower() == "y" or confirm:lower() == "yes" then
		local success = config.reset_playlist()
		if success then
			vim.notify("Playlist reset to default successfully!", vim.log.levels.INFO)
			-- Refresh the playlist window if it's open
			if win and vim.api.nvim_win_is_valid(win) then
				M.refresh_playlist()
				-- Reset cursor to first song
				vim.api.nvim_win_set_cursor(win, { 3, 0 })
			end
		else
			vim.notify("Failed to reset playlist", vim.log.levels.ERROR)
		end
	else
		vim.notify("Playlist reset cancelled", vim.log.levels.INFO)
	end
end

M.refresh_playlist = function()
	if not win or not vim.api.nvim_win_is_valid(win) then
		vim.notify("UI window is not available for refresh", vim.log.levels.WARN)
		return
	end

	local playlists = config.get_playlists()
	if not playlists or #playlists == 0 then
		vim.notify("No playlists available for refresh", vim.log.levels.WARN)
		return
	end

	local lines = { "LazyMPV", "-----------------------------------------------------------------" }
	for i, playlist in ipairs(playlists) do
		table.insert(lines, string.format("%d. %s", i, playlist.title))
	end

	-- Temporarily make buffer modifiable for refresh
	local was_modifiable = vim.bo[buf].modifiable
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = was_modifiable
end

return M
