
What emerged when The Naked Ape (already deep into the process of software development) discovered Neovim and gained access to the collective wisdom—the simulated intelligence—created by other clever Naked Apes?

💾 nvim-session-manager
A minimal, cross-platform session and shada manager for Neovim, built in Lua.

This plugin allows users to quickly save and restore specific workspace states (buffers, window layout, marks, and command history) by naming and storing them in a dedicated directory.

✨ Features
Named Sessions: Easily save and restore your workspace using a short, memorable name (e.g., :Ss temp).

Integrated Shada: Automatically saves and restores the corresponding Shada (viminfo) file, ensuring your command history, search history, and registers are preserved with the session.

Cross-Platform Paths: Uses Neovim's standard data directory (stdpath("data")) for reliable operation on Windows, Linux, and macOS.

User Commands: Provides simple Ex-commands for fast interaction within Neovim.

<img width="1918" height="1139" alt="image" src="https://github.com/user-attachments/assets/2799da50-fde8-47ea-9a13-6f7a673eb82a" />


📦 Installation
Use your favorite package manager. This example uses Lazy.nvim.
```lua
Lua
{
    'Lowq53/nvim-session-manager',
    dependencies = {
        'nvim-lua/plenary.nvim',
        'nvim-telescope/telescope.nvim',
    },
    cmd = { 'Ss', 'Sr', 'Sl' },
    config = function()
        require('session_manager').setup({
            -- Automatically resolved to:
            -- Windows: C:\Users\<User>\AppData\Local\nvim-data\sessions
            -- Linux:   ~/.local/share/nvim-data/sessions
            base_dir = vim.fs.normalize(vim.fn.stdpath("data") .. '/sessions'),
        })
    end,
    keys = {
        { "<leader>sm", ":Ss main<CR>", desc = "Save Main Session" },
        { "<leader>rm", ":Sr main<CR>", desc = "Restore Main Session" },
        { "<leader>sl", ":Sl<CR>", desc = "List Sessions" },
    },
}
```
🚀 Usage Overview
```lua
-- Save a session
:Ss my_session

-- Restore a session
:Sr my_session

-- Open Telescope session list
:Sl
```

