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