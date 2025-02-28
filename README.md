# lazympv.nvim

A Neovim plugin for controlling MPV media player directly from your editor. Perfect for developers who enjoy background music while coding, especially designed for macOS users.

A personal project to explore Neovim plugin development, inspired by tools like lazygit, before transitioning to using Cursor editor.
A Vim-inspired interface for controlling MPV directly from your editor, bringing media control to your fingertips.

## Screenshots

![Plugin UI](./screenshots/plugin-ui.png)

## Features

- Control MPV player directly from Neovim
- Manage and play YouTube playlists
- Persistent playlist storage
- Simple and intuitive keybindings
- Seamless integration with your coding workflow

## Prerequisites

- macOS (plugin is currently tested only on macOS)
- mpv player (`brew install mpv`)
- socat (`brew install socat`)
- Neovim

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

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
    'plsdev89/lazympv.nvim',
    config = function()
        require('lazympv').setup()
    end
}
```

## Default Keybindings

- `<leader>pp` - Toggle MPV player UI
- `<leader>pq` - Quit MPV player
- `<leader>pn` - Play next track
- `<leader>pN` - Play previous track

## Configuration

The plugin stores its configuration in `~/.config/lazympv/` directory, including:

- `playlists.txt` - Stores your playlist information
- `last_played_index.txt` - Remembers your last played track

Default playlist includes:

- "3 AM Coding Session - Lofi Hip Hop Mix [Study & Coding Beats]"

You can modify the playlists by editing the configuration file or through the plugin's interface.

## File Structure

lua/lazympv/
├── init.lua # Plugin initialization and setup
├── config.lua # Configuration management
├── mpv.lua # MPV player control
├── ui.lua # User interface components
└── util.lua # Utility functions

## Usage

1. Install the plugin using your preferred package manager
2. Use the keybindings to control MPV player:
   - Toggle the player with `<leader>pp`
   - Navigate through tracks with `<leader>pn` and `<leader>pN`
   - Quit the player with `<leader>pq`
3. Add new playlist entries by editing `~/.config/lazympv/playlists.txt` and adding lines in the format "title"="url".

## Notes

- This plugin is currently tested only on macOS
- Requires both `mpv` and `socat` to be installed
- Playlist state is persisted between sessions

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Author

[plsdev89](https://github.com/plsdev89)
