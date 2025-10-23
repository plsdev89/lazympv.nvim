local M = {}

-- Default configuration
local default_config = {
  socket_path = "/tmp/mpvsocket",
  config_dir = nil, -- Will be set to XDG_CONFIG_HOME/lazympv
  keybindings = {
    toggle = "<leader>pp",
    quit = "<leader>pq",
    next = "<leader>pn",
    prev = "<leader>pN",
    add_song = "<leader>pa",
    reset_playlist = "<leader>pr",
  },
}

-- Merge user config with defaults
M.config = vim.tbl_deep_extend("force", default_config, {})

local function create_directory(path)
  local success, err = os.execute("mkdir -p " .. path)
  if not success then
    vim.notify("Error creating directory: " .. (err or "unknown error"), vim.log.levels.ERROR)
    return false
  end
  return true
end

local function get_config_dir()
  if M.config.config_dir then
    return M.config.config_dir
  end
  local xdg_config_home = os.getenv "XDG_CONFIG_HOME" or os.getenv "HOME" .. "/.config"
  return xdg_config_home .. "/lazympv"
end

local function validate_url(url)
  -- Basic URL validation
  if not url or url == "" then
    return false, "URL cannot be empty"
  end

  -- Check for common URL patterns
  local patterns = {
    "^https?://", -- HTTP/HTTPS
    "^ftp://", -- FTP
    "^file://", -- Local file
    "^/", -- Absolute path
  }

  for _, pattern in ipairs(patterns) do
    if url:match(pattern) then
      return true
    end
  end

  return false, "Invalid URL format"
end

local function sanitize_title(title)
  if not title or title == "" then
    return nil, "Title cannot be empty"
  end

  -- Remove potentially problematic characters
  local sanitized = title:gsub('["\n\r\t]', "")
  if sanitized == "" then
    return nil, "Title contains only invalid characters"
  end

  return sanitized
end

M.get_last_played_index = function()
  local config_dir = get_config_dir()
  local file_path = config_dir .. "/last_played_index.txt"

  local file, err = io.open(file_path, "r")
  if not file then
    vim.notify("Error opening last played index file: " .. (err or "unknown error"), vim.log.levels.WARN)
    return 1
  end

  local state = file:read "*all"
  file:close()

  local index = tonumber(state)
  if not index or index < 1 then
    vim.notify("Invalid last played index, resetting to 1", vim.log.levels.WARN)
    return 1
  end

  return index
end

M.set_last_played_index = function(state)
  if not state or state < 1 then
    vim.notify("Invalid state value for last played index", vim.log.levels.ERROR)
    return false
  end

  local config_dir = get_config_dir()
  local file_path = config_dir .. "/last_played_index.txt"

  if not create_directory(config_dir) then
    return false
  end

  local file, err = io.open(file_path, "w")
  if not file then
    vim.notify("Error opening last played index file for writing: " .. (err or "unknown error"), vim.log.levels.ERROR)
    return false
  end

  file:write(tostring(state))
  file:close()
  return true
end

local load_playlists = function()
  local config_dir = get_config_dir()
  local file_path = config_dir .. "/playlists.txt"

  local file = io.open(file_path, "r")
  if not file then
    return nil
  end

  local loaded_playlists = {}
  local line_count = 0

  for line in file:lines() do
    line_count = line_count + 1
    local title, url = line:match '^"([^"]+)"="([^"]+)"$'
    if title and url then
      -- Validate the loaded data
      local valid_url, url_err = validate_url(url)
      local sanitized_title, title_err = sanitize_title(title)

      if valid_url and sanitized_title then
        table.insert(loaded_playlists, { title = sanitized_title, url = url })
      else
        vim.notify(
          string.format("Skipping invalid playlist entry at line %d: %s", line_count, url_err or title_err),
          vim.log.levels.WARN
        )
      end
    else
      vim.notify(string.format("Skipping malformed playlist entry at line %d", line_count), vim.log.levels.WARN)
    end
  end

  file:close()

  return #loaded_playlists > 0 and loaded_playlists or nil
end

M.get_playlists = function()
  return load_playlists()
    or {
      {
        title = "3 AM Coding Session - Lofi Hip Hop Mix [Study & Coding Beats]",
        url = "https://www.youtube.com/watch?v=_ITiwPMUzho",
      },
    }
end

M.set_playlists = function(new_playlists)
  if not new_playlists or type(new_playlists) ~= "table" or #new_playlists == 0 then
    vim.notify("Invalid playlists data", vim.log.levels.ERROR)
    return false
  end

  local config_dir = get_config_dir()
  local file_path = config_dir .. "/playlists.txt"

  if not create_directory(config_dir) then
    return false
  end

  local file = io.open(file_path, "w")
  if not file then
    vim.notify("Error opening playlists file for writing", vim.log.levels.ERROR)
    return false
  end

  for _, playlist in ipairs(new_playlists) do
    if playlist.title and playlist.url then
      file:write('"' .. playlist.title .. '"="' .. playlist.url .. '"\n')
    end
  end

  file:close()
  return true
end

M.add_song = function(title, url)
  -- Validate inputs
  local sanitized_title, title_err = sanitize_title(title)
  if not sanitized_title then
    vim.notify("Invalid title: " .. title_err, vim.log.levels.ERROR)
    return false
  end

  local valid_url, url_err = validate_url(url)
  if not valid_url then
    vim.notify("Invalid URL: " .. url_err, vim.log.levels.ERROR)
    return false
  end

  local config_dir = get_config_dir()
  local file_path = config_dir .. "/playlists.txt"

  if not create_directory(config_dir) then
    return false
  end

  local file = io.open(file_path, "a")
  if not file then
    vim.notify("Error opening playlists file for appending", vim.log.levels.ERROR)
    return false
  end

  file:write('"' .. sanitized_title .. '"="' .. url .. '"\n')
  file:close()
  return true
end

M.delete_song = function(index)
  if not index or index < 1 then
    vim.notify("Invalid song index for deletion", vim.log.levels.ERROR)
    return false
  end

  local playlists = M.get_playlists()
  if not playlists or #playlists == 0 then
    vim.notify("No playlists available to delete from", vim.log.levels.WARN)
    return false
  end

  if index > #playlists then
    vim.notify("Song index out of range", vim.log.levels.ERROR)
    return false
  end

  -- Remove the song at the specified index
  table.remove(playlists, index)

  -- Update the last played index if necessary
  local last_played_index = M.get_last_played_index()
  if last_played_index >= index then
    if last_played_index > 1 then
      M.set_last_played_index(last_played_index - 1)
    else
      M.set_last_played_index(1)
    end
  end

  -- Save the updated playlists
  return M.set_playlists(playlists)
end

M.edit_song = function(index, new_title, new_url)
  if not index or index < 1 then
    vim.notify("Invalid song index for editing", vim.log.levels.ERROR)
    return false
  end

  local playlists = M.get_playlists()
  if not playlists or #playlists == 0 then
    vim.notify("No playlists available to edit", vim.log.levels.WARN)
    return false
  end

  if index > #playlists then
    vim.notify("Song index out of range", vim.log.levels.ERROR)
    return false
  end

  -- Validate new inputs
  local sanitized_title, title_err = sanitize_title(new_title)
  if not sanitized_title then
    vim.notify("Invalid title: " .. title_err, vim.log.levels.ERROR)
    return false
  end

  local valid_url, url_err = validate_url(new_url)
  if not valid_url then
    vim.notify("Invalid URL: " .. url_err, vim.log.levels.ERROR)
    return false
  end

  -- Update the song at the specified index
  playlists[index].title = sanitized_title
  playlists[index].url = new_url

  -- Save the updated playlists
  return M.set_playlists(playlists)
end

M.reset_playlist = function()
  -- Default playlist with the "3 AM Coding Session" song
  local default_playlist = {
    {
      title = "3 AM Coding Session - Lofi Hip Hop Mix [Study & Coding Beats]",
      url = "https://www.youtube.com/watch?v=_ITiwPMUzho",
    },
  }

  -- Reset last played index to 1
  M.set_last_played_index(1)

  -- Save the default playlist
  return M.set_playlists(default_playlist)
end

-- Setup function to merge user configuration
M.setup = function(user_config)
  if user_config then
    M.config = vim.tbl_deep_extend("force", default_config, user_config)
  end
end

return M
