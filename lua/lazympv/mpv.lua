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
  local handle = io.popen "pgrep -x mpv"
  if handle then
    local result = handle:read "*a"
    handle:close()

    if result == "" then
      vim.fn.jobstart({
        "mpv",
        "--input-ipc-server=" .. socket_path,
        "--no-video",
        "--log-file=/dev/null",
        "--no-terminal",
        "--idle=yes",
      }, { detach = true })
    end
  else
    print "Failed to check if MPV is running."
  end
end

M.quit = function()
  -- Stop monitoring before quitting
  if M.monitoring_job then
    vim.fn.jobstop(M.monitoring_job)
    M.monitoring_job = nil
  end

  local handle = io.popen "pgrep -x mpv"
  if handle then
    local result = handle:read "*a"
    handle:close()

    if result ~= "" then
      local ipc = io.popen("echo 'quit' | socat - UNIX-CONNECT:" .. socket_path)

      if ipc then
        ipc:close()
      else
        print "Failed to send quit command to MPV."
      end
    else
      print "MPV is not running."
    end
  else
    print "Failed to check if MPV is running."
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
  -- Check if mpv is running
  local handle = io.popen "pgrep -x mpv"
  if not handle then
    vim.notify("Failed to check mpv status", vim.log.levels.ERROR)
    return false
  end

  local result = handle:read "*a"
  handle:close()

  if result == "" then
    vim.notify("mpv is not running. Starting mpv...", vim.log.levels.WARN)
    M.start()
    -- Give mpv a moment to start
    vim.fn.sleep(1)
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
