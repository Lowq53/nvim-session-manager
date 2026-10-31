# Development Plan for nvim-session-manager

This document outlines a comprehensive development approach for the `nvim-session-manager` plugin, from the perspective of a senior Neovim plugin developer. It covers initial review, potential enhancements, testing, and documentation strategies.

## Project Analysis Summary

*   **Purpose:** `nvim-session-manager` is a Neovim plugin designed for managing editor sessions, including saving and loading sessions (`.mks`) and shada files (`.shada`), and handling Neovim's small marks. It integrates with `telescope.nvim` for an interactive session viewer.
*   **Core Functionality:**
    *   **Session Management:** Save, load, and delete functionality for user-defined sessions.
    *   **Shada Integration:** Saves and restores Neovim's shada (history, registers, etc.) along with sessions.
    *   **Small Marks:** Custom logic for saving and restoring small marks (a-z) per buffer.
    *   **User Command:** Provides the `:Smgr` command with subcommands: `save`, `load`, `delete`, `list`, `current`.
    *   **User Prompts:** Safely handles modified buffers before session restoration by prompting the user.
    *   **Session Listing:** Integrates with `telescope.nvim` to provide a searchable list of available sessions.
    *   **Configuration:** Allows setting a base directory for sessions and additional search directories.
    *   **Persisted.nvim Support:** Includes logic to discover and integrate sessions from `persisted.nvim`.

*   **Key Files:**
    *   `init.lua`: Main module, responsible for core logic, configuration, session handling, shada, marks, and setup.
    *   `commands.lua`: Defines the `:Smgr` user command and implements its subcommand logic.
    *   `telescopeviewer.lua`: (Assumed) Handles the `telescope.nvim` integration for session selection.
    *   `utils.lua`: (Assumed) Contains helper functions.

*   **Observations & Initial Impressions:**
    *   The project demonstrates clear intent and provides essential session management features.
    *   Error and warning notifications are handled using `vim.notify`.
    *   The use of `vim.fn.mkdir` and `vim.fs.normalize` indicates attention to cross-platform compatibility.
    *   Some strings are currently in Polish, suggesting a potential need for internationalization (i18n) if broader audience reach is desired.
    *   The binary `analize.doc` file cannot be directly processed and should ideally be converted to a readable format (e.g., Markdown) or its content moved into code comments or dedicated documentation if relevant.

---

## Action-Oriented Development Roadmap

Here is a revised, action-oriented roadmap for elevating `nvim-session-manager` to a best-in-class Neovim plugin.


### Phase 1: Foundational Improvements (Code Quality & Testing)

The first priority is to solidify the existing codebase and establish a robust testing framework. This ensures long-term stability and maintainability.

*   **1.1. Implement a Linter:**
    *   **Action:** Integrate `luacheck` into the development workflow.
    *   **Goal:** Enforce consistent coding standards, catch syntax errors early, and improve overall code health.
*   **1.2. Refactor for Consistency & Clarity:**
    *   **Action:** Standardize naming conventions across all modules (e.g., adopt `snake_case` universally). Refactor path handling to exclusively use `vim.fs` functions for better cross-platform reliability.
    *   **Goal:** Create a clean, readable, and idiomatic Lua codebase.
*   **1.3. Establish a Unit & Integration Test Suite:**
    *   **Action:** Write unit tests for all core utility functions using `plenary.nvim/test`. Develop integration tests for the complete session lifecycle: `save`, `restore`, `delete`.
    *   **Goal:** Guarantee that core functionality works as expected and prevent future regressions.
*   **1.4. Set Up Continuous Integration (CI):**
    *   **Action:** Create a GitHub Actions workflow that automatically runs the linter and the full test suite on every push and pull request.
    *   **Goal:** Automate quality assurance and ensure the `main` branch is always stable.
*del* *   **1.5. New entry checking 

### Phase 2: Feature Expansion & User Experience (UX)

With a solid foundation, focus shifts to high-impact features and improving the user workflow.

*   **2.1. Enhance Session Management Commands:**
    *   **Action:** Implement `:Smgr rename <old> <new>` to rename a session's files.
    *   **Action:** Create `:Smgr last` to quickly switch back to the previously active session.
*   **2.2. Implement Intelligent Automation:**
    *   **Action:** Introduce `setup` options for auto-saving the current session on `VimLeavePre` and auto-loading a session on `VimEnter`.
    *   **Action:** Improve automatic session naming by detecting project root markers (e.g., `.git`, `init.lua`).
*   **2.3. Deepen Telescope Integration:**
    *   **Action:** Allow users to customize the session display format.
    *   **Action:** Add features for tagging, grouping, and advanced filtering of sessions within the Telescope picker.
*   **2.4. Build an Extensibility Framework:**
    *   **Action:** Introduce user-configurable callback hooks for key events (`on_pre_save`, `on_post_restore`).
    *   **Action:** Formally document a public API to allow other plugins to interact with `nvim-session-manager`.

### Phase 3: Polish & Documentation

The final phase focuses on making the plugin accessible, performant, and easy to use for a global audience.

*   **3.1. Create Comprehensive Documentation:**
    *   **Action:** Write a complete `README.md` with installation guides, configuration examples, and command references.
    *   **Action:** Generate a `doc/session-manager.txt` help file for in-editor access via `:h session-manager`.
*   **3.2. Implement Internationalization (i18n):**
    *   **Action:** Externalize all user-facing strings into a configuration table.
    *   **Action:** Add a mechanism to load translations based on a user's language setting.
*   **3.3. Profile and Optimize Performance:**
    *   **Action:** Ensure all non-essential modules are lazy-loaded.
    *   **Action:** If needed, profile `get_all_sessions` and implement caching to keep session listing instantaneous, even with a large number of session files.

---

This structured approach ensures that `nvim-session-manager` evolves into a robust, feature-rich, and user-friendly plugin that adheres to high development standards.

---

## Code Review for Neovim 0.11.5 - Bugs, Fixes, Improvements

### 1. Critical Bug: `vim.fn.confirm` - Wrong Separator

The `vim.fn.confirm` function expects `\n` as a separator for choices, but the current code uses `\\`.

```lua
-- ❌ BUG: \\ is a literal backslash, not a newline
local choices = "&Yes\\&No\\&Abort"

-- ✅ FIX: vim.fn.confirm expects \n as a separator
local choices = "&Yes\n&No\n&Abort"
```

The same error occurs in the second `confirm` call:

```lua
-- ❌
vim.fn.confirm("Buffer ... modified. Save it?", "&Yes\\&No\\&Abort", 1)
-- ✅
vim.fn.confirm("Buffer ... modified. Save it?", "&Yes\n&No\n&Abort", 1)
```

### 2. `choice == 2` Logic - Dead Loop and Incorrect Semantics

The current logic for handling `choice == 2` in `save_modified_buffers` is flawed. The `for` loop is redundant, and `wall` executes only once. Additionally, the labels do not match the behavior.

```lua
-- ❌ CURRENT CODE: The for loop is pointless - wall will execute once and return
elseif choice == 2 then
    for _, buf_info in ipairs(modified_buffers) do  -- <-- what's the loop for?
        vim.cmd("silent! wall")
        print("✅ All modified buffers saved.")
        return true
    end

-- ✅ FIX:
elseif choice == 1 then  -- "Yes" = Save All (changed semantics)
    vim.cmd("silent! wall")
    vim.notify("✅ All modified buffers saved.", vim.log.levels.INFO)
    return true
```

Furthermore, the labels do not match the actual behavior:
*   `Yes` → iterates through buffers (behaves like "Confirm each")
*   `No` → saves everything (behaves like "Save All")

### 3. Fully Rewritten `save_modified_buffers` Function - Neovim 0.11.5

```lua
local function save_modified_buffers()
  -- Collect modified, listed, and loaded buffers
  local modified = vim.iter(vim.api.nvim_list_bufs())
    :filter(function(buf)
      return vim.bo[buf].modified
          and vim.bo[buf].buflisted
          and vim.api.nvim_buf_is_loaded(buf)
    end)
    :map(function(buf)
      local name = vim.api.nvim_buf_get_name(buf)
      return {
        bufnr = buf,
        fname = name,
        display = name ~= "" and vim.fn.fnamodify(name, ":~:.") or "[No Name]",
      }
    end)
    :totable()

  if #modified == 0 then
    return true
  end

  -- ── Prompt ──────────────────────────────────────────────
  -- 1 = Save All | 2 = Confirm Each | 3 = Discard All | 4 = Abort
  local choice = vim.fn.confirm(
    string.format("⚠️  %d modified buffer(s). What to do?", #modified),
    "&Save All\n&Confirm Each\n&Discard All\n&Abort",
    1 -- default: Save All
  )

  -- Abort
  if choice == 0 or choice == 4 then
    vim.notify("❌ Session restore aborted.", vim.log.levels.WARN)
    return false
  end

  -- Discard All — discard changes
  if choice == 3 then
    for _, buf in ipairs(modified) do
      vim.bo[buf.bufnr].modified = false
    end
    vim.notify("🗑️  All changes discarded.", vim.log.levels.WARN)
    return true
  end

  -- Save All
  if choice == 1 then
    -- Check if any buffer has no name
    local unnamed = vim.iter(modified):filter(function(b) return b.fname == "" end):totable()
    if #unnamed > 0 then
      vim.notify(
        string.format("⚠️  %d buffer(s) have no filename. Save them manually first.", #unnamed),
        vim.log.levels.ERROR
      )
      -- Jump to the first unnamed
      vim.api.nvim_set_current_buf(unnamed[1].bufnr)
      return false
    end
    vim.cmd("silent! wall")
    vim.notify("✅ All modified buffers saved.", vim.log.levels.INFO)
    return true
  end

  -- Confirm Each (choice == 2)
  for _, buf in ipairs(modified) do
    vim.api.nvim_set_current_buf(buf.bufnr)
    vim.cmd("redraw")

    local answer = vim.fn.confirm(
      string.format("Save buffer [%s]?", buf.display),
      "&Yes\n&No\n&Abort",
      1
    )

    if answer == 0 or answer == 3 then
      vim.notify("❌ Session restore aborted.", vim.log.levels.WARN)
      return false
    end

    if answer == 1 then -- Yes
      if buf.fname == "" then
        vim.notify("⚠️  Buffer has no filename. Use :w <path> manually.", vim.log.levels.ERROR)
        return false
      end
      vim.cmd("silent write")
      vim.notify("✅ Saved: " .. buf.display, vim.log.levels.INFO)
    end
    -- answer == 2 (No) → skip, continue loop
  end

  return true
end
```

### 4. API Changes Specific to Neovim 0.10+ / 0.11.5

| Old Pattern                             | New Pattern (0.11.5)                       | Notes                                      |
| :-------------------------------------- | :----------------------------------------- | :----------------------------------------- |
| `vim.api.nvim_get_option_value("modified", {buf=b})` | `vim.bo[b].modified`                       | Shorter, more idiomatic                    |
| `vim.api.nvim_get_option_value("buflisted", {buf=b})` | `vim.bo[b].buflisted`                      | Same as above                              |
| `vim.fn.buflisted(b) == 1`              | `vim.bo[b].buflisted`                      | Returns boolean, no need for `== 1`        |
| `vim.fn.bufloaded(b) == 1`              | `vim.api.nvim_buf_is_loaded(b)`            | Native API, returns boolean                |
| `for loop + table.insert + filter`       | `vim.iter(...):filter():map():totable()`   | `vim.iter` stable since 0.10               |
| `print("✅ ...")`                       | `vim.notify("✅ ...", vim.log.levels.INFO)` | Integrates with `nvim-notify`, `fidget` etc. |
| `vim.cmd("silent! w " .. fname)`        | `vim.cmd("silent write")`                  | Safer - buffer is already active           |
| Manual `gsub` on paths                  | `vim.fs.joinpath() / vim.fs.normalize()`   | Stable since 0.10                          |
| `vim.fn.fnamodify(cwd, ":t")`         | `vim.fs.basename(cwd)`                     | Newer API (if available)                   |

### 5. Additional Fixes and Suggestions

#### 5.1 `choice == 0` - User Pressed `<Esc>`

```lua
-- ❌ No handling - Esc returns 0, code falls into else (iteration)
if choice == 3 then ...
elseif choice == 2 then ...
else -- ← choice == 0 also lands here!

-- ✅ Always handle 0
if choice == 0 or choice == 4 then
    return false
end
```

#### 5.2 `silent!` Masks Save Errors

```lua
-- ❌ If save fails, the user won't know why
vim.cmd("silent! wall")

-- ✅ Use pcall + handle error
local ok, err = pcall(vim.cmd, "wall")
if not ok then
    vim.notify("❌ Save failed: " .. err, vim.log.levels.ERROR)
    return false
end
```

#### 5.3 `vim.cmd("redraw")` Before Each `confirm`

Without this, the buffer might not be visible before the dialog is displayed:

```lua
vim.api.nvim_set_current_buf(buf.bufnr)
vim.cmd("redraw") -- ← important!
local answer = vim.fn.confirm(...)
```

#### 5.4 Emojis in Terminals Without Unicode

Not all terminals render emojis. Consider a configuration option:

```lua
-- config
M.options = {
    icons = true, -- false → ASCII fallback
}

local function icon(emoji, fallback)
    return M.options.icons and emoji or fallback
end

-- usage
vim.notify(icon("✅", "[OK]") .. " All saved.", vim.log.levels.INFO)
```

### 6. Summary of Changes in Table

| # | Problem                               | Importance  | Status         |
| : | :------------------------------------ | :---------- | :------------- |
| 1 | `\\` instead of `\n` in `confirm`     | 🔴 Critical | Separator not working |
| 2 | Dead loop with `wall`                 | 🟡 Bug      | Redundant iteration |
| 3 | No handling for `choice == 0` (`Esc`) | 🟡 Bug      | Unexpected behavior |
| 4 | Labels don't match logic              | 🟡 UX       | Confusing for user |
| 5 | `print` instead of `vim.notify`       | 🟢 Style    | No `notify` integration |
| 6 | Old API instead of `vim.bo[]`         | 🟢 Modernization | Works, but verbose |
| 7 | Missing `vim.iter`                    | 🟢 Modernization | Idiomatic in 0.11 |
| 8 | `silent!` masks errors                | 🟡 Reliability | Silent fail      |
| 9 | No `redraw` before `confirm`          | 🟢 UX       | Buffer not visible |

### 7. Similar Plugins - Comparison

| Plugin              | Description                                                                                             | Link                                             |
| :------------------ | :------------------------------------------------------------------------------------------------------ | :----------------------------------------------- |
| `auto-session`      | Automatic save/restore sessions based on CWD. Telescope integration.                                    | [github.com/rmagatti/auto-session](https://github.com/rmagatti/auto-session) |
| `persisted.nvim`    | Session management with auto-save, per-branch, per-directory. Telescope picker.                       | [github.com/olimorris/olimorris/persisted.nvim](https://github.com/olimorris/persisted.nvim) |
| `neovim-session-manager` | Popular solution by Shatur. Telescope, auto-save, `git branch` support.                                | [github.com/Shatur/neovim-session-manager](https://github.com/Shatur/neovim-session-manager) |
| `possession.nvim`   | Sessions as JSON files with metadata. Telescope. Pre/post hooks.                                        | [github.com/jedrzejboczar/possession.nvim](https://github.com/jedrzejboczar/possession.nvim) |
| `resession.nvim`    | Sessions as Lua tables - full control over what is saved. Extensible API.                               | [github.com/stevearc/resession.nvim](https://github.com/stevearc/resession.nvim) |
| `mini.sessions`     | Minimalist module from `mini.nvim`. Simple, zero dependencies, read/write/delete.                     | [github.com/echasnovski/mini.sessions](https://github.com/echasnovski/mini.sessions) |
| `scope.nvim`        | Not sessions per se, but tab-scoped buffers. Complementary plugin.                                      | [github.com/tiagovla/scope.nvim](https://github.com/tiagovla/scope.nvim) |
| `vim-obsession`     | Classic by tpope (Vim). Continuous session saving. Lightweight, zero configuration.                     | [github.com/tpope/vim-obsession](https://github.com/tpope/vim-obsession) |
| `vim-prosession`    | Extends `vim-obsession` with per-directory and per-git-branch sessions.                                | [github.com/dhruvasagar/vim-prosession](https://github.com/dhruvasagar/vim-prosession) |
| `vim-startify`      | Startscreen + session manager. Classic Vim, works in Neovim.                                            | [github.com/mhinz/vim-startify](https://github.com/mhinz/vim-startify) |

#### How Your Plugin Could Stand Out:

*   **Shada + Small Marks Integration:** None of the above do this out-of-the-box.
*   **`persisted.nvim` Migration Support:** A unique feature.
*   **Granular Per-Buffer Prompt:** Most only offer `wall` or abort.

Rekomendacja "Senior" (Zastosowanie):
Jeśli pracujesz w monorepo i zmieniasz branche: Wybierz persisted.nvim. Jego integracja z git-branch jest bezkonkurencyjna.
Jeśli potrzebujesz pełnej programowalności (Infrastructure as Code): Wybierz resession.nvim. Dzięki zapisowi w Lua możesz napisać logikę, która przy starcie sesji automatycznie konfiguruje środowisko pod konkretne zadanie.
Jeśli chcesz najwyższego porządku w buforach: Połącz dowolny manager sesji z scope.nvim. To rozwiązuje problem "bałaganu w liście buforów", który jest zmorą przy pracy nad wieloma komponentami jednocześnie.
Jeśli cenisz analizę danych (Data Science/Research): Wybierz possession.nvim. Przechoowywanie sesji w JSON pozwala na łatwe wersjonowanie ich w Git i współdzielenie z zespołem.
C:\dev\nvimdev\nvim-session-manager\lua\session_manager\development_plan.md
Głęboka Analiza Pluginów Sesji Neovim
Co oznacza "Granular Per-Buffer Prompt"?
text

┌─────────────────────────────────────────────────────────────────┐
│  STANDARDOWE PODEJŚCIE (wall or abort):                        │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  "Masz niezapisane zmiany. Zapisać WSZYSTKO? [Y/N]"     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  GRANULAR PER-BUFFER PROMPT:                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Buffer: init.lua        [Save] [Discard] [Skip]        │   │
│  │  Buffer: config.lua      [Save] [Discard] [Skip]        │   │
│  │  Buffer: plugins.lua     [Save] [Discard] [Skip]        │   │
│  └─────────────────────────────────────────────────────────┘   │
│  = Decyzja dla KAŻDEGO bufora osobno                           │
└─────────────────────────────────────────────────────────────────┘
Analiza Kodu - 3 Unikalne Cechy Każdego Pluginu
1. auto-session
Lua

-- UNIKALNA CECHA 1: CWD-based Auto-Detection
-- Źródło: lua/auto-session/init.lua
local function get_session_name()
  -- Automatycznie tworzy nazwę z bieżącego katalogu
  local cwd = vim.fn.getcwd()
  return cwd:gsub("/", "%%") -- /home/user/project -> %home%user%project
end

-- UNIKALNA CECHA 2: Session Lens (Telescope natywna integracja)
-- Źródło: lua/auto-session/session-lens/init.lua
require("telescope").load_extension("session-lens")
-- Można wyszukiwać sesje z preview okien/buforów

-- UNIKALNA CECHA 3: Pre/Post Command Hooks z CWD context
-- Źródło: lua/auto-session/config.lua
{
  pre_save_cmds = { "NvimTreeClose", "TroubleClose" },
  post_save_cmds = { },
  pre_restore_cmds = { },
  post_restore_cmds = { "NvimTreeOpen" }, -- Auto-reopen po restore
}
PRO Senior Ocena:

Cecha	Ocena	Powód
CWD Auto-Detection	⭐⭐⭐⭐⭐	Zero konfiguracji, "just works"
Session Lens	⭐⭐⭐⭐	Fuzzy search z preview
Hook System	⭐⭐⭐	Tylko commands, nie full Lua callbacks
2. persisted.nvim
Lua

-- UNIKALNA CECHA 1: Git Branch Awareness (automatyczna)
-- Źródło: lua/persisted/init.lua
local function get_branch()
  local branch = vim.fn.system("git branch --show-current 2>/dev/null")
  if vim.v.shell_error == 0 then
    return branch:gsub("\n", "")
  end
  return nil
end

-- Sesja: /project@main.vim vs /project@feature-x.vim

-- UNIKALNA CECHA 2: Allowed/Ignored Directories Pattern
-- Źródło: lua/persisted/config.lua
{
  allowed_dirs = { "~/projects" },      -- TYLKO te katalogi
  ignored_dirs = { "~/projects/temp" }, -- Wyklucz te
  -- Regex pattern matching!
  allowed_dirs = { "~/projects/.*" },
}

-- UNIKALNA CECHA 3: Autoload z warunkami
-- Źródło: lua/persisted/init.lua
{
  autoload = true,
  on_autoload_no_session = function()
    -- Callback gdy brak sesji - np. pokaż dashboard
    vim.cmd("Alpha")
  end,
}
PRO Senior Ocena:

Cecha	Ocena	Powód
Git Branch Sessions	⭐⭐⭐⭐⭐	Killer feature dla multi-branch work
Directory Patterns	⭐⭐⭐⭐	Elastyczna kontrola
Autoload Callbacks	⭐⭐⭐⭐⭐	Pełna integracja z workflow
3. neovim-session-manager
Lua

-- UNIKALNA CECHA 1: Autosave Modes (Granularne)
-- Źródło: lua/session_manager/config.lua
{
  autoload_mode = {
    require('session_manager.config').AutoloadMode.LastSession,
    require('session_manager.config').AutoloadMode.CurrentDir,
    require('session_manager.config').AutoloadMode.Disabled,
  },
  autosave_last_session = true,
  autosave_only_in_session = true, -- Nie twórz nowych automatycznie
}

-- UNIKALNA CECHA 2: Session Events (Autocmd integration)
-- Źródło: lua/session_manager/init.lua
vim.api.nvim_create_autocmd("User", {
  pattern = "SessionLoadPost", -- CUSTOM EVENT!
  callback = function()
    -- Po załadowaniu sesji - np. refresh LSP
    vim.cmd("LspRestart")
  end,
})
-- Dostępne: SessionSavePost, SessionLoadPost, SessionDeletePost

-- UNIKALNA CECHA 3: Session Path Customization
-- Źródło: lua/session_manager/config.lua
{
  sessions_dir = require('plenary.path'):new(
    vim.fn.stdpath('data'), 'sessions'
  ),
  path_replacer = '__', -- /home/user -> home__user
  colon_replacer = '++',
}
PRO Senior Ocena:

Cecha	Ocena	Powód
Autosave Modes	⭐⭐⭐⭐	Trzy różne tryby
Custom Events	⭐⭐⭐⭐⭐	Najlepsza integracja z autocmds


4. possession.nvim
Lua

-- UNIKALNA CECHA 1: JSON Metadata (Rozszerzalny format)
-- Źródło: lua/possession/session.lua
-- Plik sesji example.json:
{
  "name": "my-project",
  "cwd": "/home/user/project",
  "user_data": {
    "git_branch": "main",
    "last_file": "init.lua",
    "custom_field": "anything"  -- DOWOLNE DANE!
  },
  "vimscript": "...(session content)..."
}

-- UNIKALNA CECHA 2: Plugin Hooks System (Pre/Post dla wszystkiego)
-- Źródło: lua/possession/config.lua
{
  hooks = {
    before_save = function(name)
      -- Return false = cancel save
      return vim.fn.confirm("Save " .. name .. "?", "&Yes\n&No") == 1
    end,
    after_save = function(name, user_data)
      vim.notify("Saved: " .. name)
    end,
    before_load = function(name) return true end,
    after_load = function(name, user_data) end,
  },
}

-- UNIKALNA CECHA 3: Migrate from other plugins
-- Źródło: lua/possession/migrate.lua
require('possession').migrate({
  source = 'auto-session',  -- Importuj z auto-session!
  -- lub: 'persisted', 'neovim-session-manager'
})
PRO Senior Ocena:

Cecha	Ocena	Powód
JSON + User Data	⭐⭐⭐⭐⭐	Jedyny z metadata extensibility
Full Hook System	⭐⭐⭐⭐⭐	Lua callbacks dla wszystkiego
Migration Tool	⭐⭐⭐⭐⭐	UNIKALNY - łatwa migracja
5. resession.nvim
Lua

-- UNIKALNA CECHA 1: Lua Tables (Nie Vimscript!)
-- Źródło: lua/resession/init.lua
-- Sesja jako pure Lua - PEŁNA KONTROLA
{
  buffers = {
    { file = "/path/to/file.lua", cursor = {10, 5} },
  },
  tabs = { ... },
  options = { ... },
  -- Custom extension data:
  extensions = {
    quickfix = { ... },
    scope = { ... },  -- Tab-scoped buffers!
  },
}

-- UNIKALNA CECHA 2: Extensions API (Pluginy mogą dodawać własne dane)
-- Źródło: lua/resession/extensions/quickfix.lua
require("resession").add_extension({
  name = "quickfix",
  save = function()
    return vim.fn.getqflist()
  end,
  load = function(data)
    vim.fn.setqflist(data)
  end,
})

-- UNIKALNA CECHA 3: Tab-scoped Sessions
-- Źródło: lua/resession/init.lua
require("resession").save_tab("tab-name") -- Zapisz tylko aktualny tab!
require("resession").load_tab("tab-name")
PRO Senior Ocena:

Cecha	Ocena	Powód
Lua Tables	⭐⭐⭐⭐⭐	Programmatic control, no vimscript
Extensions API	⭐⭐⭐⭐⭐	Najbardziej extensible
Tab Sessions	⭐⭐⭐⭐⭐	UNIKALNY - per-tab save/restore
6. mini.sessions
Lua

-- UNIKALNA CECHA 1: Zero Dependencies (Pure Lua, standalone)
-- Źródło: lua/mini/sessions.lua
-- CAŁY PLUGIN TO JEDEN PLIK ~400 linii
-- Nie wymaga: plenary, telescope, nic

-- UNIKALNA CECHA 2: Detected Sessions (Auto-discovery)
-- Źródło: lua/mini/sessions.lua
local sessions = require('mini.sessions')
sessions.setup({
  directory = '~/.vim/sessions',
  autoread = true,
  autowrite = true,
})
-- sessions.detected = { "session1", "session2", ... }
-- Auto-refresh przy każdej operacji

-- UNIKALNA CECHA 3: Minimal API (3 funkcje)
sessions.read(session_name)   -- Load
sessions.write(session_name)  -- Save  
sessions.delete(session_name) -- Delete
-- To wszystko! Prostota = mniej bugów
PRO Senior Ocena:

Cecha	Ocena	Powód
Zero Deps	⭐⭐⭐⭐⭐	Najbardziej portable
Auto-Discovery	⭐⭐⭐⭐	Proste ale effective
Minimal API	⭐⭐⭐⭐⭐	Easy to wrap/extend
7. scope.nvim
Lua

-- UNIKALNA CECHA 1: Tab-Scoped Buffer Lists (NIE SESJE!)
-- Źródło: lua/scope/init.lua
-- Każdy tab ma WŁASNĄ listę buforów
-- Tab 1: [file1.lua, file2.lua]
-- Tab 2: [other.py, main.py]  -- Inne bufory!

-- UNIKALNA CECHA 2: Hooks dla Buffer Lifecycle
-- Źródło: lua/scope/init.lua
require("scope").setup({
  hooks = {
    post_tab_enter = function()
      -- Po wejściu do taba - np. refresh statusline
    end,
  },
})

-- UNIKALNA CECHA 3: Telescope/Bufferline Integration
-- Źródło: lua/telescope/_extensions/scope.lua
require("telescope").load_extension("scope")
-- :Telescope scope buffers - bufory TYLKO z current tab
PRO Senior Ocena:

Cecha	Ocena	Powód
Tab Buffer Isolation	⭐⭐⭐⭐⭐	UNIKALNY koncept
Lifecycle Hooks	⭐⭐⭐⭐	Dobra integracja
Telescope Extension	⭐⭐⭐⭐⭐	Seamless UX
8. vim-obsession
Lua

-- UWAGA: To Vimscript plugin, nie Lua

-- UNIKALNA CECHA 1: Continuous Auto-Save (Ciągły zapis)
-- Źródło: plugin/obsession.vim
" Po każdej zmianie layoutu - automatyczny zapis
autocmd BufEnter,VimLeavePre * call s:Persist()
" NIE trzeba pamiętać o :mksession

-- UNIKALNA CECHA 2: Session Status w Statusline
" g:obsession_status - zmienna dla statusline
" Pokazuje czy sesja jest aktywna/paused

-- UNIKALNA CECHA 3: Pause/Resume
:Obsession       " Toggle
:Obsession!      " Stop tracking
:Obsession file  " Zapisz do konkretnego pliku
PRO Senior Ocena:

Cecha	Ocena	Powód
Continuous Save	⭐⭐⭐⭐⭐	"Set and forget"
Statusline Integration	⭐⭐⭐⭐	Visual feedback
Simplicity	⭐⭐⭐⭐⭐	Najprostrzy ze wszystkich
9. vim-prosession
Lua

-- UWAGA: Vimscript, rozszerza vim-obsession

-- UNIKALNA CECHA 1: Per-Directory Auto-Switch
-- Źródło: plugin/prosession.vim
" cd ~/project-a -> automatycznie ładuje project-a session
" cd ~/project-b -> switch to project-b session
let g:prosession_per_branch = 1

-- UNIKALNA CECHA 2: Tmux Integration
" Źródło: plugin/prosession.vim
" Zmienia nazwę panelu tmux na nazwę sesji
let g:prosession_tmux_title = 1

-- UNIKALNA CECHA 3: Session z obsession + branch + directory
" Hierarchia: ~/.vim/sessions/home%user%project@@branch.vim
" Kombinacja trzech kontekstów
PRO Senior Ocena:

Cecha	Ocena	Powód
Auto-Switch on CD	⭐⭐⭐⭐⭐	Seamless workflow
Tmux Integration	⭐⭐⭐⭐	Terminal power users
Branch+Dir+Obsession	⭐⭐⭐⭐	Kompletne rozwiązanie Vim
10. vim-startify
Lua

-- UWAGA: Vimscript

-- UNIKALNA CECHA 1: Start Screen z Sessions
-- Źródło: autoload/startify.vim
" Wizualny ekran startowy:
" [1] Session: project-a
" [2] Session: project-b
" [3] Recent: ~/.config/nvim/init.lua
" [4] Bookmarks: ~/notes/todo.md

-- UNIKALNA CECHA 2: Custom ASCII Art Header
let g:startify_custom_header = [
  \ '   ███╗   ██╗██╗   ██╗██╗███╗   ███╗',
  \ '   ████╗  ██║██║   ██║██║████╗ ████║',
  \ ]

-- UNIKALNA CECHA 3: Session Persistence + MRU + Bookmarks
" Wszystko w jednym interfejsie
let g:startify_lists = [
  \ { 'type': 'sessions',  'header': ['   Sessions']  },
  \ { 'type': 'files',     'header': ['   MRU']       },
  \ { 'type': 'bookmarks', 'header': ['   Bookmarks'] },
  \ ]
PRO Senior Ocena:

Cecha	Ocena	Powód
Visual Start Screen	⭐⭐⭐⭐⭐	UX excellence
Custom Headers	⭐⭐⭐⭐	Personalizacja
All-in-One UI	⭐⭐⭐⭐⭐	Sessions + MRU + Bookmarks
Matryca Porównawcza - Unikalne Cechy
text

┌─────────────────────┬─────────────────┬──────────────────┬─────────────────┐
│ Plugin              │ Cecha 1         │ Cecha 2          │ Cecha 3         │
├─────────────────────┼─────────────────┼──────────────────┼─────────────────┤
│ auto-session        │ CWD Auto-Name   │ Session Lens     │ Command Hooks   │
│ persisted.nvim      │ Git Branch      │ Dir Patterns     │ Autoload CB     │
│ neovim-session-mgr  │ Autosave Modes  │ Custom Events    │ Path Custom     │
│ possession.nvim     │ JSON Metadata   │ Full Hooks       │ Migration       │
│ resession.nvim      │ Lua Tables      │ Extensions API   │ Tab Sessions    │
│ mini.sessions       │ Zero Deps       │ Auto-Discovery   │ Minimal API     │
│ scope.nvim          │ Tab Buffers     │ Lifecycle Hooks  │ Telescope Ext   │
│ vim-obsession       │ Continuous Save │ Statusline       │ Pause/Resume    │
│ vim-prosession      │ Auto-Switch CD  │ Tmux Title       │ Branch+Dir      │
│ vim-startify        │ Start Screen    │ ASCII Art        │ All-in-One UI   │
└─────────────────────┴─────────────────┴──────────────────┴─────────────────┘
Rekomendacja PRO Senior
text

┌──────────────────────────────────────────────────────────────────────────┐
│  USE CASE → PLUGIN                                                       │
├──────────────────────────────────────────────────────────────────────────┤
│  "Just works, zero config"     → auto-session                            │
│  "Git branch workflows"        → persisted.nvim                          │
│  "Maximum extensibility"       → resession.nvim + scope.nvim             │
│  "Migrate from other plugin"   → possession.nvim                         │
│  "Minimalist, no deps"         → mini.sessions                           │
│  "Classic Vim, simple"         → vim-obsession                           │
│  "Visual start screen"         → vim-startify                            │
│  "Tab-based workflows"         → resession.nvim (tab sessions)           │
└──────────────────────────────────────────────────────────────────────────┘
Czy chcesz żebym przeanalizował konkretny aspekt kodu głębiej?
