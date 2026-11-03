-- lua/session_manager/telescopeviewer.lua
-- Session Manager - Telescope picker
-- Help modes: "notify" | "float" | "preview"  (set in setup opts)

local pickers    = require("telescope.pickers")
local finders    = require("telescope.finders")
local conf       = require("telescope.config").values
local actions    = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")

local M = {}

----------------------------------------------------------------------
-- Help content (single source of truth)
----------------------------------------------------------------------
local HELP_LINES = {
  "╭──────────────────────────────────────╮",
  "│     💾 Session Manager - Help        │",
  "├──────────────────────────────────────┤",
  "│  Enter    │ Restore session          │",
  "│  Ctrl+S   │ Save session             │",
  "│  Ctrl+Shift+S │ Save as new session  │",
  "│  Ctrl+D   │ Delete session           │",
  "│  Ctrl+R   │ Rename session           │",
  "│  ?        │ Toggle this help         │",
  "│  Esc / q  │ Close picker             │",
  "╰──────────────────────────────────────╯",
}

----------------------------------------------------------------------
-- Help mode: "notify"  (vim.notify, toggle = close on second press)
----------------------------------------------------------------------
local _notify_win = nil  -- track if help is "shown" logically

local function help_notify_show()
  vim.notify(table.concat(HELP_LINES, "\n"), vim.log.levels.INFO)
  _notify_win = true
end

local function help_notify_toggle()
  -- vim.notify cant be closed programmatically - we just skip second call
  if _notify_win then
    _notify_win = false
    vim.notify("Help closed (press ? to show again)", vim.log.levels.INFO)
  else
    help_notify_show()
  end
end

----------------------------------------------------------------------
-- Help mode: "float"  (floating window, real toggle)
----------------------------------------------------------------------
local _float_win = nil  -- track floating window id

local function help_float_close()
  if _float_win and vim.api.nvim_win_is_valid(_float_win) then
    vim.api.nvim_win_close(_float_win, true)
  end
  _float_win = nil
end

local function help_float_open()
  -- Create a scratch buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, HELP_LINES)
  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype = "nofile"

  local width  = 44
  local height = #HELP_LINES

  -- Center on screen
  local row = math.floor((vim.o.lines   - height) / 2)
  local col = math.floor((vim.o.columns - width)  / 2)

  _float_win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    row      = row,
    col      = col,
    width    = width,
    height   = height,
    style    = "minimal",
    border   = "rounded",
    zindex   = 200,       -- above telescope
  })

  -- Close with q or Esc inside the float
  vim.keymap.set("n", "q",   help_float_close, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<Esc>", help_float_close, { buffer = buf, nowait = true })
end

local function help_float_toggle()
  if _float_win and vim.api.nvim_win_is_valid(_float_win) then
    help_float_close()
  else
    help_float_open()
  end
end

----------------------------------------------------------------------
-- Help mode: "preview"  (shown in Telescope's preview panel)
-- The previewer is always rendering help content instead of file preview.
-- Toggle = show/hide the help text inside the preview window.
----------------------------------------------------------------------
local _preview_show_help = false  -- state: is help shown in preview?

-- Creates a Telescope previewer that shows help when toggled, empty otherwise
local function make_help_previewer()
  return previewers.new_buffer_previewer({
    title = "Session Info / Help",
    define_preview = function(self, entry)
      if _preview_show_help then
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, HELP_LINES)
      else
        -- Show session metadata when help is not toggled
        local lines = {
          "Session:  " .. (entry and entry.value or ""),
          "Path:     " .. (entry and entry.data and entry.data.path or ""),
          "Modified: " .. (entry and entry.data and entry.data.modified or ""),
          "",
          "Press ? to toggle help",
        }
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      end
    end,
  })
end

----------------------------------------------------------------------
-- Unified toggle dispatcher - called by "?" keymap
----------------------------------------------------------------------
local function make_help_toggle(mode, picker_obj)
  if mode == "float" then
    return help_float_toggle

  elseif mode == "preview" then
    return function()
      _preview_show_help = not _preview_show_help
      -- Force previewer to re-render current entry
      if picker_obj then
        local entry = action_state.get_selected_entry()
        if entry and picker_obj.previewer then
          picker_obj.previewer:preview(entry)
        end
      end
    end

  else -- "notify" (default)
    return help_notify_toggle
  end
end

----------------------------------------------------------------------
-- Main Telescope session picker
----------------------------------------------------------------------
M.sessions = function(opts)
  opts = opts or {}

  local SM = require("session_manager")

  -- Read help_mode from plugin config (default: "notify")
  local help_mode = (SM.options and SM.options.help_mode) or "notify"

  local session_data = SM.get_all_sessions()

  if #session_data == 0 then
    vim.notify("❌ No sessions found in configured directories.", vim.log.levels.WARN)
    return
  end

  -- Reset float state when opening a fresh picker
  _float_win   = nil
  _notify_win  = false
  _preview_show_help = false

  -- Build previewer only for "preview" mode
  local previewer_obj = (help_mode == "preview") and make_help_previewer() or conf.file_previewer(opts)

  -- We need a reference to the picker for the preview-toggle
  local picker_ref = nil

  local picker = pickers.new(opts, {
    prompt_title = "💾 Session Manager",

    finder = finders.new_table({
      results = session_data,
      entry_maker = function(entry)
        return {
          value   = entry.name,
          display = entry.display,
          ordinal = entry.name .. entry.path,
          data    = entry,
        }
      end,
    }),

    sorter   = conf.generic_sorter(opts),
    previewer = previewer_obj,

    attach_mappings = function(prompt_bufnr, map)

      -- ENTER → Restore session
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        -- Close float help if open before leaving telescope
        help_float_close()
        actions.close(prompt_bufnr)
        if entry then
          SM.restore(entry.value)
          SM.restore_small_marks(entry.value)
        end
      end)

      -- CTRL+D → Delete session
      local function delete_session()
        local entry = action_state.get_selected_entry()
        if not entry then return end
        SM.delete_session(entry.data)
        vim.schedule(function()
          help_float_close()
          M.sessions(opts)
        end)
      end

      -- CTRL+S → Save session
      local function save_session()
        local entry = action_state.get_selected_entry()
        if not entry then return end
        help_float_close()
        actions.close(prompt_bufnr)
        SM.save(entry.value)
        SM.save_small_marks(entry.value)
        vim.schedule(function() M.sessions(opts) end)
      end

      -- CTRL+SHIFT+S → Save the current workspace as a new session
      local function save_new_session()
        local new_name = vim.fn.input("New session name: ")
        if not new_name or new_name:match("^%s*$") then
          vim.notify("❌ Save cancelled or empty name.", vim.log.levels.WARN)
          return
        end
        if not new_name:match("^[%w_%-]+$") then
          vim.notify("❌ Use only letters, numbers, underscores, and hyphens in session names.", vim.log.levels.ERROR)
          return
        end
        for _, session in ipairs(SM.get_all_sessions()) do
          if session.name == new_name then
            vim.notify("❌ Session '" .. new_name .. "' already exists.", vim.log.levels.ERROR)
            return
          end
        end

        help_float_close()
        actions.close(prompt_bufnr)
        SM.save(new_name)
        SM.save_small_marks(new_name)
        vim.notify("✅ New session saved: " .. new_name, vim.log.levels.INFO)
        vim.schedule(function() M.sessions(opts) end)
      end

      -- CTRL+R → Rename session
      local function rename_session_action()
        local entry = action_state.get_selected_entry()
        if not entry then return end

        local new_name = vim.fn.input("New session name: ", entry.value)
        if not new_name or new_name:match("^%s*$") then
          vim.notify("❌ Rename cancelled or empty name.", vim.log.levels.WARN)
          return
        end

        local ok, msg = SM.rename_session(entry.value, new_name)
        vim.notify((ok and "✅ " or "❌ ") .. msg, ok and vim.log.levels.INFO or vim.log.levels.ERROR)

        vim.schedule(function()
          help_float_close()
          M.sessions(opts)
        end)
      end

      -- ESC / q → Close (also close float help)
      local function close_all()
        help_float_close()
        actions.close(prompt_bufnr)
      end

      -- ? → Help toggle (mode-aware, wired after picker is created)
      local function help_toggle()
        local toggle_fn = make_help_toggle(help_mode, picker_ref)
        toggle_fn()
      end

      map("i", "?",     help_toggle)
      map("n", "?",     help_toggle)
      map("i", "<C-d>", delete_session)
      map("n", "<C-d>", delete_session)
      map("i", "<C-s>", save_session)
      map("n", "<C-s>", save_session)
      map("i", "<C-S-s>", save_new_session)
      map("n", "<C-S-s>", save_new_session)
      map("i", "<C-r>", rename_session_action)
      map("n", "<C-r>", rename_session_action)
      map("i", "<Esc>", close_all)
      map("n", "<Esc>", close_all)
      map("n", "q",     close_all)
      map("n", "<C-c>", close_all)

      return true
    end,
  })

  picker_ref = picker  -- give preview toggle a reference
  picker:find()
end

return M
