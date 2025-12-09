-- C:\dev\nvimdev\nvim-session-manager\lua\session_manager\telescopeviewer.lua

-- Wymagamy niezbędnych modułów Telescope
local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
local telescope = require "telescope"
-- Wymagamy utils, jeśli chcemy zaawansowanej konfiguracji, ale na razie pomijamy
local sessions = {}
local M = {} -- Tabela, która będzie naszym modułem



--
-- Wywołuje Telescope picker z listą dostępnych sesji.
-- @param opts (table|nil) Opcje konfiguracji dla pickera.
---
M.sessions = function(opts)
  local SM = require("session_manager")

  local session_data = SM.get_all_sessions()

  if #session_data == 0 then
    vim.notify("❌ No sessions found in configured directories.", vim.log.levels.WARN)
    return
  end

  -- Ustawiamy opcje na puste, jeśli nie zostały podane
  opts = opts or {}

  -- 2. Tworzymy nowy picker Telescope
  pickers.new(opts, {
    -- Tytuł wyświetlany na górze okna Telescope
    prompt_title = "💾 Session Manager",

    -- Finder (Wyszukiwarka): Używamy findera dla tabeli z sesjami
    finder = finders.new_table {
      results = session_data,
      -- Klucz, który Telescope ma wyświetlać
      entry_maker = function(entry)
        return {
          value = entry.name,      -- NAZWA sesji -> używane przez restore
          display = entry.display, -- Tekst wyświetlany w Telescope
          ordinal = entry.name .. " " .. entry.modified .. " " .. entry.path,
          path = entry.path,
          data = entry,
        }
      end,
    },

    -- Sorter: Używamy domyślnego sortowania
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if selection then
          SM.restore(selection.value)
        end
      end)
      return true
    end,

    -- 3. Definicja Akcji (co się dzieje po naciśnięciu ENTER)
    actions = {
      ["<cr>"] = function(prompt_bufnr)
        -- Pobieramy wybrany wpis
        local selection = action_state.get_selected_entry()

        if selection then
          -- Wywołujemy funkcję M.restore z wybraną nazwą sesji
          -- To odpali logikę 'save_modified_buffers' (jeśli jest w M.restore)
          SM.restore(selection.value)
        end

        -- Zamykamy okno Telescope
        actions.close(prompt_bufnr)
      end,
      -- Dodaj domyślne akcje zamknięcia
      ["q"] = actions.close,
      ["<esc>"] = actions.close,
      ["C-c"] = actions.close,
    },

    -- Uruchamiamy pickera
  }):find()
end

-- Creates the entry structure for Telescope.
-- Jest to funkcja pomocnicza, dlatego jest lokalna (local function)
-- @param session (table) Single session data entry from M.get_all_sessions()
-- @returns table Telescope entry
---
local function make_session_entry(session)
  -- Używamy telescope.make_entry, jeśli potrzebna jest rozbudowana logika,
  -- ale prościej jest stworzyć tabelę, która spełnia wymagania Telescope.
  return {
    -- Wartość, która jest wyświetlana użytkownikowi
    display = session.display,
    -- Wartość, która zostanie zwrócona do akcji (nazwa sesji)
    value = session.name,
    -- Krótki opis/ścieżka wyświetlana w dolnym panelu podglądu (np. full path)
    ordinal = session.path,
    -- Dodatkowe metadane (dostępne w akcji)
    data = session,
  }
end

---
-- Custom action: Restores the selected session using M.restore()
---
local function restore_session_action(prompt_bufnr)
  -- Pobierz aktualnie wybrany wpis (entry)
  local entry = action_state.get_selected_entry()

  -- Zamknij okno Telescope
  actions.close(prompt_bufnr)

  if entry and entry.value then
    -- Sprawdź, czy bufor został już zmodyfikowany

    -- Wywołaj Twoją funkcję restore
    M.restore(entry.value)
  else
    vim.notify("Session restore failed: No session selected.", vim.log.levels.WARN)
  end
end

---
-- Główna funkcja picker'a. Wyświetla listę sesji.
---
function sessions.sessions(opts)
  opts = opts or {}

  -- 1. Pobierz dane z Twojego modułu
  local session_data = M.get_all_sessions()

  if not session_data or vim.tbl_isempty(session_data) then
    vim.notify("Session Manager: No sessions found.", vim.log.levels.INFO)
    return
  end

  -- 2. Przekształć dane na format oczekiwany przez Telescope
  local entries = {}
  for _, session in ipairs(session_data) do
    -- Wykorzystaj lokalną funkcję make_session_entry
    table.insert(entries, make_session_entry(session))
  end

  telescope.nvim.pick(
    {
      finder = finders.new_table({
        results = entries,
        -- Możemy użyć entries bez podawania entry_maker, jeśli są już w formacie Telescope
      }),
      -- conf.default.file_previewer()
      -- Jeśli chcesz podgląd zawartości pliku sesji (.mks), użyj tego:
      previewer = conf.file_previewer(),
      sorter = conf.generic_sorter(opts),

      -- Konfiguracja mapowań klawiszy (keymaps)
      attach_mappings = function(prompt_bufnr, map)
        -- Dodaj akcję przy wyborze (np. ENTER)
        actions.select_default:enhance(restore_session_action)
        return true
      end,

      -- Ustawienia wyglądu
      prompt_title = ' Session Manager ',
      layout_strategy = 'vertical',
      layout_config = {
        height = 0.5,
      },
    }
  )
end

M.colors = function(opts)
  -- Ustawiamy opcje na puste, jeśli nie zostały podane
  opts = opts or {}
  -- Tworzymy nowy picker Telescope
  pickers.new(opts, {
    -- Tytuł wyświetlany na górze okna Telescope
    prompt_title = "Dostępne Kolory (TEST)",

    -- Finder (Wyszukiwarka): Używamy prostego findera dla tabeli
    finder = finders.new_table {
      -- Dane, które będą wyszukiwane i wyświetlane
      results = {
        "red",
        "green",
        "blue",
        "yellow",
        "cyan",
        "magenta",
        "tokyonight (Twój motyw!)"
      }
    },

    -- Sorter: Używamy domyślnego sortowania dla wyników
    sorter = conf.generic_sorter(opts),

    -- Możemy dodać funkcję action (co się dzieje po wyborze), np.
    -- actions = {
    --   ["<cr>"] = function(prompt_bufnr)
    --       print("Wybrano: " .. action_state.get_selected_entry().value)
    --       require('telescope.actions').close(prompt_bufnr)
    --   end,
    -- },

    -- Uruchamiamy pickera
  }):find()
end

-- 🚨 To jest absolutnie KRYTYCZNE:
-- Moduł musi ZWRÓCIĆ tabelę M, aby require("...") nie zwróciło boolean.
return M
