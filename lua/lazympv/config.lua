local M = {}

local function create_directory(path)
  local success, err = os.execute("mkdir -p " .. path)
  if not success then
    print("Error creating directory: " .. err)
  end
end

M.get_last_played_index = function()
  local xdg_config_home = os.getenv "XDG_CONFIG_HOME" or os.getenv "HOME" .. "/.config"

  local file_path = xdg_config_home .. "/lazympv/last_played_index.txt"

  local file, err = io.open(file_path, "r")
  if not file then
    print("Error opening file: " .. err)
    return 1
  end

  local state = file:read "*all"
  file:close()

  return tonumber(state)
end

M.set_last_played_index = function(state)
  local xdg_config_home = os.getenv "XDG_CONFIG_HOME" or os.getenv "HOME" .. "/.config"

  local directory_path = xdg_config_home .. "/lazympv"
  local file_path = directory_path .. "/last_played_index.txt"

  create_directory(directory_path)

  local file, err = io.open(file_path, "w")
  if not file then
    print("Error opening file: " .. err)
    return
  end

  file:write(state)
  file:close()
end

local load_playlists = function()
  local xdg_config_home = os.getenv "XDG_CONFIG_HOME" or os.getenv "HOME" .. "/.config"

  local file_path = xdg_config_home .. "/lazympv/playlists.txt"

  local file = io.open(file_path, "r")
  if not file then
    return nil
  end

  local loaded_playlists = {}
  for line in file:lines() do
    local title, url = line:match '^"([^"]+)"="([^"]+)"$'
    if title and url then
      table.insert(loaded_playlists, { title = title, url = url })
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
  local xdg_config_home = os.getenv "XDG_CONFIG_HOME" or os.getenv "HOME" .. "/.config"

  local directory_path = xdg_config_home .. "/lazympv"
  local file_path = directory_path .. "/playlists.txt"

  create_directory(directory_path)

  local file = io.open(file_path, "w")
  if not file then
    return
  end

  for _, playlist in ipairs(new_playlists) do
    file:write('"' .. playlist.title .. '"="' .. playlist.url .. '"\n')
  end

  file:close()
end

return M
