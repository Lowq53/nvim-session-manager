-- C:\dev\nvimdev\nvim-session-manager\lua\session_manager\telescopeviewer.lua
-- Telescope viewer for session_manager
-- Clean, minimal, fully working version with delete support (Ctrl+D)

local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"

local M = {}

----------------------------------------------------------------------
-- Main Telescope session picker
-- Opens a list of sessions with support for restore + delete
----------------------------------------------------------------------
M.sessions = function(opts)
  opts = opts or {}
  local SM = require("session_manager")
  local session_data = SM.get_all_sessions()

  if #session_data == 0 then
    vim.notify("❌ No sessions found in configured directories.", vim.log.levels.WARN)
    return
  end

  pickers.new(opts, {
    prompt_title = "💾 Session Manager",
    -- Telescope finder that lists each session entry
    finder = finders.new_table({
      results = session_data,
      entry_maker = function(entry)
        return {
          value = entry.name,                 -- session name
          display = entry.display,            -- formatted display string
          ordinal = entry.name .. entry.path, -- for search/filter
          data = entry,                       -- full entry table for deletion
        }
      end,
    }),
    sorter = conf.generic_sorter(opts),

    ------------------------------------------------------------------
    -- Keybindings for picker
    ------------------------------------------------------------------
    attach_mappings = function(prompt_bufnr, map)
      ----------------------------------------------------------------
      -- ENTER → Restore session
      ----------------------------------------------------------------
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if entry then
          SM.restore(entry.value)
        end
      end)

      ----------------------------------------------------------------
      -- CTRL+D → Delete session
      ----------------------------------------------------------------
      local function delete_session()
        local entry = action_state.get_selected_entry()
        if not entry then return end

        actions.close(prompt_bufnr)
        SM.delete_session(entry.data) -- correct full-data delete

        -- Refresh picker after delete
        vim.schedule(function()
          M.sessions(opts)
        end)
      end
        -- ? → Show help
  local function show_help()
    vim.notify([[
Session Manager - Keybindings:
  Enter     - Restore session
  Ctrl+D    - Delete session
  Esc/q     - Close picker
  ?         - Show this help\
]], vim.log.levels.INFO)
  end
      map("i", "?", show_help)
      map("n", "?", show_help)
      map("i", "<C-d>", delete_session)
      map("n", "<C-d>", delete_session)

      ----------------------------------------------------------------
      -- Close picker shortcuts
      ----------------------------------------------------------------
      map("i", "<esc>", actions.close)
      map("n", "q", actions.close)
      map("n", "<C-c>", actions.close)

      return true
    end,
  }):find()
end

----------------------------------------------------------------------
-- Return module
----------------------------------------------------------------------
return M
