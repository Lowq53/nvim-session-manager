local M = {} -- Main module table
local default_opts = {
  -- Set the default base directory for sessions using the Neovim data path
  -- e.g., ~/.local/share/nvim/sessions or C:\Users\User\AppData\Local\nvim\sessions
  base_dir = vim.fn.stdpath("data") .. '/sessions',
}

-- Helper function: Checks and creates the directory, returns the session path
local function get_session_path(name)
  local session_dir = M.options.base_dir
  -- Ensure the base path exists ('p' flag creates parent directories if needed)
  vim.fn.mkdir(session_dir, 'p')

  -- Return the full base path for the session file (using '/' works cross-platform in Lua/Vim)
  return session_dir .. '/' .. name
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
-- Main configuration function, called by Lazy.nvim.
-- @param opts (table|nil) User-provided options
---
function M.setup(opts)
  -- Merge user options with defaults
  M.options = vim.tbl_deep_extend("force", {}, default_opts, opts or {})

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
end

return M
