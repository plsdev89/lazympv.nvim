local M = {}
local config = require "lazympv.config"
local util = require "lazympv.util"
local socket_path = "/tmp/mpvsocket"

-- Ensure mpv and socat are installed
if not util.is_command_available "mpv" then
  vim.notify("Error: 'mpv' is not installed. Please install 'mpv'.", vim.log.levels.ERROR)
  return
end

if not util.is_command_available "socat" then
  vim.notify("Error: 'socat' is not installed. Please install 'socat'.", vim.log.levels.ERROR)
  return
end

-- Ensure plugin is only used on macOS
if not util.is_mac() then
  vim.notify(
    "Warning: This plugin is only tested on macOS. It may not work correctly on other systems.",
    vim.log.levels.ERROR
  )
  return
end

M.start = function()
  -- Check if MPV is already running with the correct socket
  local handle = io.popen("pgrep -f 'mpv.*input-ipc-server=" .. socket_path .. "'")
  if handle then
    local result = handle:read "*a"
    handle:close()

    if result == "" then
      -- No MPV instance with our socket is running, start one
      vim.fn.jobstart({
        "mpv",
        "--input-ipc-server=" .. socket_path,
        "--no-video",
        "--log-file=/dev/null",
        "--no-terminal",
        "--idle=yes",
      }, { detach = true })

      -- Give MPV a moment to start and create the socket
      vim.defer_fn(function()
        -- MPV should be ready now
      end, 1000)
    else
      -- MPV is already running with our socket, just ensure monitoring is active
      if not M.monitoring_job then
        M.start_monitoring()
      end
    end
  else
    vim.notify("Failed to check if MPV is running", vim.log.levels.ERROR)
  end
end

M.quit = function()
  -- Stop monitoring before quitting
  if M.monitoring_job then
    vim.fn.jobstop(M.monitoring_job)
    M.monitoring_job = nil
  end

  -- Find and kill all MPV processes with our socket
  local handle = io.popen("pgrep -f 'mpv.*input-ipc-server=" .. socket_path .. "'")
  if handle then
    local result = handle:read "*a"
    handle:close()

    if result ~= "" then
      -- Try to send quit command first
      local ipc = io.popen('echo \'{"command": ["quit"]}\' | socat - ' .. socket_path .. " 2>/dev/null")
      if ipc then
        ipc:close()
        -- Give MPV a moment to quit gracefully
        vim.defer_fn(function()
          -- MPV should have quit gracefully by now
        end, 500)
      end

      -- Force kill if still running
      local kill_handle = io.popen("pkill -f 'mpv.*input-ipc-server=" .. socket_path .. "'")
      if kill_handle then
        kill_handle:close()
      end

      vim.notify("MPV stopped", vim.log.levels.INFO)
    else
      vim.notify("MPV is not running", vim.log.levels.INFO)
    end
  else
    vim.notify("Failed to check if MPV is running", vim.log.levels.ERROR)
  end
end

M.start_monitoring = function()
  -- Kill any existing monitoring job
  if M.monitoring_job then
    vim.fn.jobstop(M.monitoring_job)
  end

  -- Start monitoring mpv events
  M.monitoring_job = vim.fn.jobstart("socat - " .. socket_path, {
    on_stdout = function(_, data)
      if data and data[1] ~= "" then
        local success, response = pcall(vim.fn.json_decode, data[1])
        if success and response then
          -- Handle end-file event (song finished)
          if response.event == "end-file" and response.reason == "eof" then
            vim.schedule(function()
              M.next()
            end)
          end
          -- Handle file-loaded event (new song started)
        elseif response.event == "file-loaded" then
          vim.schedule(function()
            -- Update UI if it's open
            local ui = require "lazympv.ui"
            if ui.win and vim.api.nvim_win_is_valid(ui.win) then
              ui.refresh_playlist()
            end
          end)
        end
      end
    end,
    on_stderr = function(_, data)
      -- Handle any errors silently
    end,
    on_exit = function(_, exit_code)
      if exit_code ~= 0 then
        -- Restart monitoring if it exits unexpectedly
        vim.defer_fn(function()
          M.start_monitoring()
        end, 1000)
      end
    end,
  })

  -- Subscribe to mpv events
  vim.defer_fn(function()
    M.send_command { ["command"] = { "client_name", "lazympv" } }
  end, 100)
end

M.send_command = function(command)
  local json = vim.fn.json_encode(command)
  local cmd = string.format("echo '%s' | socat - %s", json, socket_path)
  vim.fn.system(cmd)
end

M.play = function(url)
  -- Ensure MPV is running with our socket
  M.start()

  -- Test socket connection before proceeding
  local test_handle = io.popen('echo \'{"command": ["get_property", "pause"]}\' | socat - ' .. socket_path .. " 2>&1")
  if not test_handle then
    vim.notify("Failed to test MPV socket connection", vim.log.levels.ERROR)
    return false
  end

  local test_result = test_handle:read "*a"
  test_handle:close()

  if test_result:match "Connection refused" or test_result:match "No such file" then
    vim.notify("MPV socket not available. Please restart MPV.", vim.log.levels.ERROR)
    return false
  end

  if not url then
    M.send_command { ["command"] = { "cycle", "pause" } }
    return true
  end

  M.send_command { ["command"] = { "loadfile", url } }
  return true
end

M.next = function()
  local playlists = config.get_playlists()
  local last_played_index = config.get_last_played_index()
  local index_to_play = last_played_index >= #playlists and 1 or last_played_index + 1
  if M.play(playlists[index_to_play].url) then
    config.set_last_played_index(index_to_play)
  end
end

M.prev = function()
  local playlists = config.get_playlists()
  local last_played_index = config.get_last_played_index()
  local index_to_play = last_played_index == 1 and #playlists or last_played_index - 1
  if M.play(playlists[index_to_play].url) then
    config.set_last_played_index(index_to_play)
  end
end

return M
