# lazympv.nvim

A Neovim plugin for controlling MPV media player directly from your editor.

## Prerequisites

- macOS
- mpv player (`brew install mpv`)
- socat (`brew install socat`)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "plsdev89/lazympv.nvim",
    lazy = false,
    config = function()
        require("lazympv").setup()
    end,
}
```

## Default Keybindings

From editor

- `<leader>pp` - Toggle MPV
- `<leader>pq` - Quit MPV
- `<leader>pn` - Play Next
- `<leader>pN` - Play Previous
- `<leader>pa` - Add Song
- `<leader>pr` - Reset Playlist

From LazyMPV UI

- `<CR>` - Play selected song
- `q` - Toggle MPV
- `a` - Add Song
- `d` - Delete Song
- `r` - Edit Song

## Usage Tips

**Getting Started:**

- Open LazyMPV UI with `<leader>pp`
- Navigate songs using `j`/`k` (standard vim navigation)
- Play selected song with `<Enter>`
- Close UI with `q` (When you hit Enter, it closes automatically)

**Managing Playlist:**

- Add new song with `a` (prompts for title and URL)
- Delete song with `d` (cannot delete if you have only 1)
- Edit song with `r` (rename title/URL)
- Reset entire playlist with `<leader>pr` from editor

**Quick Controls:**

- Use `<leader>pn`/`<leader>pN` to skip tracks from anywhere
- Use `<leader>pq` to quit MPV from anywhere
- Playlist state persists between sessions
