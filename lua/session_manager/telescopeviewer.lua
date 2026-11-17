-- lua/session_manager/telescopeviewer.lua
-- Integracja z Telescope: podgląd, wyszukiwanie i akcje
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")

local M = {}

local HELP_LINES = {
	"╭──────────────────────────────────────────────╮",
	"│         💾 Session Manager - Pomoc           │",
	"├──────────────────────────────────────────────┤",
	"│  Enter        │ Wczytaj sesję                │",
	"│  Ctrl+S       │ Nadpisz zaznaczoną sesję     │",
	"│  Ctrl+Shift+S │ Zapisz jako nową sesję       │",
	"│  Ctrl+D       │ Usuń zaznaczoną sesję        │",
	"│  Ctrl+R       │ Zmień nazwę sesji            │",
	"│  ?            │ Przełącz to okno pomocy      │",
	"│  Esc / q      │ Zamknij listę sesji          │",
	"╰──────────────────────────────────────────────╯",
}

local _float_win = nil
local _preview_show_help = false

local function help_float_close()
	if _float_win and vim.api.nvim_win_is_valid(_float_win) then
		pcall(vim.api.nvim_win_close, _float_win, true)
	end
	_float_win = nil
end

local function help_float_toggle()
	if _float_win and vim.api.nvim_win_is_valid(_float_win) then
		help_float_close()
		return
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, HELP_LINES)
	vim.bo[buf].modifiable = false
	vim.bo[buf].buftype = "nofile"

	local width = 48
	local height = #HELP_LINES
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	_float_win = vim.api.nvim_open_win(buf, false, {
		relative = "editor",
		row = row,
		col = col,
		width = width,
		height = height,
		style = "minimal",
		border = "rounded",
		zindex = 200,
	})

	vim.keymap.set("n", "q", help_float_close, { buffer = buf, nowait = true })
	vim.keymap.set("n", "<Esc>", help_float_close, { buffer = buf, nowait = true })
end

local function make_help_previewer()
	return previewers.new_buffer_previewer({
		title = "Informacje o sesji / Pomoc",
		define_preview = function(self, entry)
			if _preview_show_help then
				vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, HELP_LINES)
			else
				local lines = {
					"Sesja:       " .. (entry and entry.value or ""),
					"Ścieżka:     " .. (entry and entry.data and entry.data.path or ""),
					"Modyfikacja: " .. (entry and entry.data and entry.data.modified or ""),
					"",
					"Naciśnij '?' aby wyświetlić skróty klawiszowe.",
				}
				vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
			end
		end,
	})
end

--- Główna funkcja wywołująca picker Telescope
function M.sessions(opts)
	opts = opts or {}
	local SM = require("session_manager")

	local help_mode = (SM.options and SM.options.help_mode) or "notify"
	local session_data = SM.get_all_sessions()

	if #session_data == 0 then
		vim.notify("❌ Nie znaleziono żadnych sesji w skonfigurowanych katalogach.", vim.log.levels.WARN)
		return
	end

	_float_win = nil
	_preview_show_help = false

	local previewer_obj = (help_mode == "preview") and make_help_previewer() or conf.file_previewer(opts)
	local picker_ref = nil

	local picker = pickers.new(opts, {
		prompt_title = "💾 Session Manager",
		finder = finders.new_table({
			results = session_data,
			entry_maker = function(entry)
				return {
					value = entry.name,
					display = entry.display,
					ordinal = entry.name .. " " .. entry.path,
					data = entry,
				}
			end,
		}),
		sorter = conf.generic_sorter(opts),
		previewer = previewer_obj,
		attach_mappings = function(prompt_bufnr, map)
			-- ENTER -> Wczytaj sesję
			actions.select_default:replace(function()
				local entry = action_state.get_selected_entry()
				help_float_close()
				actions.close(prompt_bufnr)
				if entry and entry.data then
					SM.restore(entry.data)
				end
			end)

			-- CTRL+D -> Usuń sesję
			local function delete_session()
				local entry = action_state.get_selected_entry()
				if not entry or not entry.data then
					return
				end
				local confirm = vim.fn.confirm(
					string.format("Czy na pewno usunąć sesję '%s'?", entry.value),
					"&Tak\n&Nie",
					2
				)
				if confirm == 1 then
					help_float_close()
					SM.delete_session(entry.data)
					vim.schedule(function()
						M.sessions(opts)
					end)
				end
			end

			-- CTRL+S -> Nadpisz zaznaczoną sesję
			local function save_session()
				local entry = action_state.get_selected_entry()
				if not entry then
					return
				end
				local confirm = vim.fn.confirm(
					string.format("Nadpisać sesję '%s' bieżącym stanem?", entry.value),
					"&Tak\n&Nie",
					2
				)
				if confirm == 1 then
					help_float_close()
					actions.close(prompt_bufnr)
					SM.save(entry.value)
					SM.save_small_marks(entry.value)
					vim.schedule(function()
						M.sessions(opts)
					end)
				end
			end

			-- CTRL+SHIFT+S -> Zapisz jako nową sesję
			local function save_new_session()
				local new_name = vim.fn.input("Nazwa nowej sesji: ")
				if not new_name or new_name:match("^%s*$") then
					vim.notify("❌ Zapis anulowany lub pusta nazwa.", vim.log.levels.WARN)
					return
				end
				if not new_name:match("^[%w_%-]+$") then
					vim.notify(
						"❌ Nazwa może zawierać tylko litery, cyfry, podkreślenia i myślniki.",
						vim.log.levels.ERROR
					)
					return
				end

				-- Sprawdź duplikaty
				for _, session in ipairs(SM.get_all_sessions()) do
					if session.name == new_name then
						vim.notify("❌ Sesja '" .. new_name .. "' już istnieje.", vim.log.levels.ERROR)
						return
					end
				end

				help_float_close()
				actions.close(prompt_bufnr)
				SM.save(new_name)
				SM.save_small_marks(new_name)
				vim.schedule(function()
					M.sessions(opts)
				end)
			end

			-- CTRL+R -> Zmień nazwę sesji
			local function rename_session_action()
				local entry = action_state.get_selected_entry()
				if not entry then
					return
				end
				local new_name = vim.fn.input("Nowa nazwa sesji: ", entry.value)
				if not new_name or new_name:match("^%s*$") or new_name == entry.value then
					return
				end

				local ok, msg = SM.rename_session(entry.value, new_name)
				vim.notify((ok and "✅ " or "❌ ") .. msg, ok and vim.log.levels.INFO or vim.log.levels.ERROR)
				vim.schedule(function()
					help_float_close()
					M.sessions(opts)
				end)
			end

			-- Pomoc (?)
			local function toggle_help()
				if help_mode == "float" then
					help_float_toggle()
				elseif help_mode == "preview" then
					_preview_show_help = not _preview_show_help
					if picker_ref and picker_ref.previewer then
						local entry = action_state.get_selected_entry()
						if entry then
							picker_ref.previewer:preview(entry)
						end
					end
				else
					vim.notify(table.concat(HELP_LINES, "\n"), vim.log.levels.INFO)
				end
			end

			local function close_all()
				help_float_close()
				actions.close(prompt_bufnr)
			end

			map("i", "?", toggle_help)
			map("n", "?", toggle_help)
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
			map("n", "q", close_all)
			map("n", "<C-c>", close_all)

			return true
		end,
	})

	picker_ref = picker
	picker:find()
end

return M
