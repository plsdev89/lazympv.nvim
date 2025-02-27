local M = {}
local config = require "lazympv.config"

local playlists = config.get_playlists()
local socket_path = "/tmp/mpvsocket"

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
  vim.fn.jobstart("socat - " .. socket_path, {
    on_stdout = function(_, data)
      if data and data[1] ~= "" then
        local response = vim.fn.json_decode(data[1])
        if response.event == "end-file" and response.reason == "eof" then
          vim.schedule(function()
            M.next()
          end)
        end
      end
    end,
  })
end

M.send_command = function(command)
  local json = vim.fn.json_encode(command)
  local cmd = string.format("echo '%s' | socat - %s", json, socket_path)
  vim.fn.system(cmd)
end

M.play = function(url)
  if not url then
    M.send_command { ["command"] = { "cycle", "pause" } }
    return
  end

  M.send_command { ["command"] = { "loadfile", url } }
end

M.next = function()
  local last_played_index = config.get_last_played_index()
  local index_to_play = last_played_index == #playlists and 1 or last_played_index + 1
  M.play(playlists[index_to_play].url)
  config.set_last_played_index(index_to_play)
end

M.prev = function()
  local last_played_index = config.get_last_played_index()
  local index_to_play = last_played_index == 1 and #playlists or last_played_index - 1
  M.play(playlists[index_to_play].url)
  config.set_last_played_index(index_to_play)
end

return M
