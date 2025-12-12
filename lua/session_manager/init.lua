-- Session Manager init.lua
-- Main module for managing Neovim sessions with shada support

local M = {} -- Main module table

local default_opts = {
  -- Set the default base directory for sessions using the Neovim data path
  -- e.g., ~/.local/share/nvim/sessions or C:\Users\User\AppData\Local\nvim\sessions
  base_dir = vim.fs.normalize(vim.fn.stdpath("data") .. "/sessions"),
  extra_dirs = {
    'C:\\code_data\\nvimSessions',
    'C:\\my_old_sessions',
  },
}

-- Helper function: Checks and creates the directory, returns the session path
local function get_session_path(name)
  -- Save version uses only the base directory
  local session_dir = M.options.base_dir
  -- Ensure the base path exists ('p' flag creates parent directories if needed)
  vim.fn.mkdir(session_dir, 'p')

  -- Return the full base path for the session file (using '/' works cross-platform in Lua/Vim)
  return session_dir .. '/' .. name
end

---
-- Retrieves a list of all available sessions across all search directories.
-- @return table: List of session data {name, path, modified_time, display}
---
function M.get_all_sessions()
  -- Local tables, cleared on each call
  local session_names = {}
  local sessions_data = {} -- Final list for Telescope

  -- Use M.search_dirs (or default options)
  local search_dirs = M.search_dirs or { M.options.base_dir }

  for _, dir in ipairs(search_dirs) do
    -- STEP 1: Normalize path for Windows
    -- Use format that works: Double backslashes
    local win_dir = dir:gsub("/", "\\\\")
    local full_path_glob = win_dir .. '\\*.mks'

    -- Get list of paths to session files
    -- Use of vim.fn.glob is sensitive to backslashes, so we must provide them
    local session_files = vim.fn.glob(full_path_glob, 1, 1)

    -- If nothing found, continue to next directory
    if vim.tbl_isempty(session_files) then
      goto continue
    end

    for _, file_path in ipairs(session_files) do
      -- 1. Extract session name (e.g. 'main' from '.../main.mks')
      -- Use pattern that works with '/' OR '\' as separator
      local file_name = file_path:match("([^/\\\\]+)$")
      local session_name = file_name:gsub('%.mks$', '')

      -- 2. Check for duplicate (important if extra_dirs overlap)
      if not session_names[session_name] then
        session_names[session_name] = true

        -- 3. Get modification date
        local timestamp = vim.fn.getftime(file_path)
        local formatted_date = os.date("%Y-%m-%d %H:%M", timestamp)

        -- Get only directory name for better display
        -- Look for last path segment (considering / or \)
        local dir_name = dir:match("([^/\\\\]+)$") or dir

        -- 4. Add data to result list (Telescope format)
        table.insert(sessions_data, {
          name = session_name, -- KEY 1: Used by SM.restore(name)
          path = file_path,    -- KEY 2: Full path to session file (ordinal)
          dir = dir,
          modified = formatted_date,

          -- KEY 3: Format for Telescope view
          display = string.format("%-20s %-20s (%s)",
            session_name,
            formatted_date,
            dir_name
          )
        })
      end
    end
    ::continue::
  end

  -- Guarantee: Always return table (sessions_data)
  return sessions_data
end

---
-- Iterates through modified buffers and prompts the user for action.
---
local function save_modified_buffers()
  local modified_buffers = {}

  -- 1. Find all modified buffers that are listed (ls)
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_get_option_value('modified', { buf = buffer }) then
      -- Get buffer name/path, use 'No Name' if path is empty
      local bufnr = buffer
      local fname = vim.api.nvim_buf_get_name(bufnr)
      local display_name = fname ~= "" and fname or "No Name"

      -- Only consider buffers that are readable and listed
      if vim.fn.buflisted(bufnr) == 1 and vim.fn.bufloaded(bufnr) == 1 then
        table.insert(modified_buffers, {
          bufnr = bufnr,
          fname = fname,
          display_name = display_name
        })
      end
    end
  end

  if #modified_buffers == 0 then
    return true -- All clean, continue restoring session
  end

  -- 2. Ask the user what to do
  -- Command: Confirm (save one), All (save all), Abort (cancel restore)
  local choices = { '&Save', '&All', '&Abort' }
  local choice = vim.fn.confirm("⚠️ There are " .. #modified_buffers ..
    " modified buffers. Save before closing?",
    choices, 2) -- Default is All

  if choice == 3 then
    print("❌ Session restore aborted.")
    return false -- Abort restore
  elseif choice == 2 then
    -- Choice: Save All
    for _, buf_info in ipairs(modified_buffers) do
      -- Use 'silent! wall' to save all modified, then return
      vim.cmd('silent! wall')
      print("✅ All modified buffers saved.")
      return true
    end
  else
    -- Choice: Save (Iterate and confirm one by one)
    for _, buf_info in ipairs(modified_buffers) do
      -- Switch to the buffer to show it to the user
      vim.api.nvim_set_current_buf(buf_info.bufnr)

      local confirm_save = vim.fn.confirm("Buffer " .. buf_info.display_name ..
        " is modified. Save it?",
        { '&Yes', '&No', '&Abort' }, 1) -- Default is Yes

      if confirm_save == 1 then         -- Yes
        if buf_info.fname == "" then
          -- If 'No Name', ask user to choose a path
          print("⚠️ Buffer has no file name. Please save it manually (e.g. :w /path/to/file) or choose No.")
          vim.fn.input('Press ENTER to continue...')
          return false -- Force user to save manually
        else
          vim.cmd('silent! w ' .. buf_info.fname)
          print('✅ Saved: ' .. buf_info.display_name)
        end
      elseif confirm_save == 3 then -- Abort
        print("❌ Session restore aborted.")
        return false
      end
      -- If 'No', continue to the next buffer without saving
    end
    return true -- Finished iterating, continue restoring
  end
end

---
-- Saves the current session and shada data.
-- @param name (string) The name of the session file base (e.g., 'main')
---
function M.save(name)
  local base_path = get_session_path(name)
  local session_file = base_path .. '.mks'
  local shada_file = base_path .. '.shada'

  -- Save session and shada (using '!' ensures overwrite)
  vim.cmd('mksession! ' .. session_file)
  vim.cmd('wshada! ' .. shada_file)

  print('✅ Session saved to: ' .. session_file)
end

---
-- Restores the session and shada data.
-- @param name (string) The name of the session file base (e.g., 'main')
---
function M.restore(name)
  local base_path = get_session_path(name)
  local session_file = base_path .. '.mks'
  local shada_file = base_path .. '.shada'

  -- 1. Check if files exist
  if vim.fn.filereadable(session_file) == 1 and vim.fn.filereadable(shada_file) == 1 then
    -- Clear the current session buffers before restoring
    -- silent! 1bdelete | only closes all but the first buffer, then leaves only the first buffer
    vim.cmd('silent! 1bdelete | only')

    -- 2. Load shada (history/registers). Must be done BEFORE the session file.
    vim.cmd('rshada ' .. shada_file)

    -- 3. Load the session
    vim.cmd('source ' .. session_file)

    print('✅ Session restored from: ' .. session_file)
  else
    print('❌ Session or shada file not found for: ' .. name)
  end
end

---
-- Deletes a session and its associated shada file.
-- @param session (table) Session data with 'name' and 'path' fields
---
function M.delete_session(session)
  -- Safety check: ensure session is a table
  if type(session) ~= "table" then
    print("❌ Error: delete_session expected table, got:", type(session))
    return
  end

  local mks = session.path
  local shada = mks:gsub("%.mks$", ".shada")

  -- Delete .mks file if it exists
  if vim.fn.filereadable(mks) == 1 then
    os.remove(mks)
  end

  -- Delete .shada file if it exists
  if vim.fn.filereadable(shada) == 1 then
    os.remove(shada)
  end

  -- Single line message
  print("✅ Session deleted: " .. session.name .. " (.mks and .shada)")
end

---
-- Main configuration function, called by Lazy.nvim.
-- @param opts (table|nil) User-provided options
---
function M.setup(opts)
  -- Merge user options with defaults
  M.options = vim.tbl_deep_extend("force", {}, default_opts, opts or {})

  M.search_dirs = {}
  table.insert(M.search_dirs, M.options.base_dir)

  -- 2. Add all additional directories from configuration
  if M.options.extra_dirs and type(M.options.extra_dirs) == 'table' then
    for _, dir in ipairs(M.options.extra_dirs) do
      -- Make sure to use only existing directories (optional, but good UX)
      if vim.fn.isdirectory(dir) == 1 then
        table.insert(M.search_dirs, dir)
      else
        -- You can add logging here if directory doesn't exist
        -- print("Warning: Session search directory not found: " .. dir)
      end
    end
  end

  -- Create user commands (for command mode)

  -- Command: :Ss <name>
  vim.api.nvim_create_user_command('Ss', function(cmd_opts)
    -- Check for required argument
    if #cmd_opts.fargs == 0 then
      print('❌ Usage: :Ss <name>')
      return
    end
    M.save(cmd_opts.fargs[1])
  end, { nargs = 1, complete = 'file', desc = 'Session Manager: Save current workspace session & shada.' })

  -- Command: :Sr <name>
  vim.api.nvim_create_user_command('Sr', function(cmd_opts)
    -- Check for required argument
    if #cmd_opts.fargs == 0 then
      print('❌ Usage: :Sr <name>')
      return
    end
    M.restore(cmd_opts.fargs[1])
  end, { nargs = 1, complete = 'file', desc = 'Session Manager: Restore workspace session & shada.' })

  -- Command: :Sl (List Sessions)
  vim.api.nvim_create_user_command('Sl', function()
    -- Require telescopeviewer only when this command is called
    require("session_manager.telescopeviewer").sessions()
  end, { desc = 'Session Manager: List and restore sessions using Telescope.' })
end

return M
