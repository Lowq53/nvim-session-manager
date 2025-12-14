-- lua/session_manager/utils.lua

local M = {}

-- checking is any floating window open
function M.has_floating_windows()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local config = vim.api.nvim_win_get_config(win)
    if config.relative ~= "" then
      return true, win
    end
  end
  return false, nil
end

-- Bezpieczne wywołanie restore z sprawdzeniem floating windows

return M
