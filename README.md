# 💾 nvim-session-manager

A minimal, lightning-fast, and cross-platform session, ShaDa, and buffer marks manager for Neovim, written in Lua.

Designed to work out-of-the-box on **Linux (native & WSL)**, **macOS**, and **Windows**.

This plugin allows users to quickly save and restore workspace states (window layouts, listed buffers, ShaDa command history/registers, and small buffer marks `a-z`) by naming and storing them in dedicated directories.

---

## ✨ Features

- **Named Sessions:** Easily save and restore your workspace using memorable names (e.g., `:Smgr save main` or `:Ss main`).
- **Integrated ShaDa:** Automatically saves and restores the corresponding `.shada` file, ensuring command history, search history, and registers are preserved per session.
- **Buffer Marks (a-z) Persistence:** Safely preserves local buffer marks (`'a` - `'z`) across all loaded buffers into structured JSON (`.marks.json`).
- **Cross-Platform & Safe Paths:** Native support for Linux XDG standards, macOS, and Windows. Automatically handles permissions (`0600` on Unix), spaces, and path normalization.
- **Telescope Integration:** Interactive session picker with shortcuts to save, overwrite, delete, rename, and preview sessions.
- **Automatic Buffer Protection:** Detects modified buffers before restoring sessions and prompts for safe handling (`Save all`, `Ask each`, `Discard`, `Cancel`).
- **Multi-Directory & Persisted Support:** Discovers sessions in custom directories as well as sessions created by `persisted.nvim`.

<img width="1918" height="1139" alt="image" src="https://github.com/user-attachments/assets/2799da50-fde8-47ea-9a13-6f7a673eb82a" />

---

## 📦 Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "Lowq53/nvim-session-manager",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-telescope/telescope.nvim",
    },
    cmd = { "Smgr", "Ss", "Sr", "Sl" },
    config = function()
        require("session_manager").setup({
            -- Base directory (defaults to stdpath("data") .. "/sessions"):
            -- Linux:   ~/.local/share/nvim/sessions
            -- Windows: C:\Users\<User>\AppData\Local\nvim-data\sessions
            base_dir = vim.fn.stdpath("data") .. "/sessions",
            extra_dirs = {
                vim.fn.stdpath("data") .. "/auto-sessions",
                vim.fn.stdpath("data") .. "/persisted",
            },
            help_mode = "notify", -- "notify" | "float" | "preview"
        })
    end,
    keys = {
        { "<leader>ss", "<cmd>Ss<CR>", desc = "Save Current Session" },
        { "<leader>sr", "<cmd>Sr ", desc = "Restore Session" },
        { "<leader>sl", "<cmd>Sl<CR>", desc = "List Sessions (Telescope)" },
    },
}
```

---

## 🚀 Commands

### Unified Command (`:Smgr`)

| Command | Shorthand | Description |
| :--- | :--- | :--- |
| `:Smgr save [name]` | `:Smgr s [name]` | Save current workspace and buffer marks to session |
| `:Smgr load <name>` | `:Smgr l <name>` | Restore session, shada, and marks |
| `:Smgr delete <name>` | `:Smgr d <name>` | Delete session files (`.mks`, `.shada`, `.marks.json`) |
| `:Smgr rename <old> <new>` | `:Smgr rn <old> <new>` | Rename session and all associated files |
| `:Smgr current` | `:Smgr c` | Show currently active session |
| `:Smgr list` | `:Smgr ls` | Open interactive Telescope session picker |

### Quick Aliases

| Alias | Description |
| :--- | :--- |
| `:Ss [name]` | Save current session (defaults to current session name or directory name) |
| `:Sr <name>` | Restore session by name |
| `:Sl` | Open Telescope session picker |

---

## ⌨️ Telescope Picker Shortcuts

When inside the `:Sl` picker:

| Keybinding | Action |
| :--- | :--- |
| `<CR>` | Restore selected session |
| `<C-s>` | Overwrite selected session with current workspace |
| `<C-S-s>` | Save current workspace as a new session |
| `<C-d>` | Delete selected session (with confirmation) |
| `<C-r>` | Rename selected session |
| `?` | Toggle help window (float / preview / notify) |
| `<Esc>` / `q` | Close session picker |

---

## 📄 Documentation

For full in-editor documentation and Lua API reference:

```vim
:help session-manager
```

---

## 📜 License

MIT License.
