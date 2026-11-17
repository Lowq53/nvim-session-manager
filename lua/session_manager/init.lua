-- lua/session_manager/init.lua
-- Główny moduł zarządzania sesjami Neovim z obsługą shada i markerów
local utils = require("session_manager.utils")

local M = {}
M.current_session = nil

-- Domyślne opcje kompatybilne z Linux / Windows / macOS
local default_opts = {
	base_dir = utils.join_path(vim.fn.stdpath("data"), "sessions"),
	extra_dirs = {
		utils.join_path(vim.fn.stdpath("data"), "auto-sessions"),
		utils.join_path(vim.fn.stdpath("data"), "persisted"),
	},
	help_mode = "notify", -- "notify" | "float" | "preview"
}

M.options = vim.deepcopy(default_opts)

--- Zwraca ścieżkę bazową dla danej sesji (bez rozszerzenia)
--- Jeśli sesja już istnieje w którymś z katalogów w M.search_dirs (np. w extra_dirs),
--- funkcja zwraca jej oryginalną lokalizację, zapobiegając powstawaniu duplikatów.
--- @param name string|table
--- @return string
local function get_session_base_path(name)
	if type(name) == "table" then
		name = name.filename or name.name or tostring(name)
	end

	local clean_name = tostring(name)

	-- Sprawdź czy sesja już istnieje w znanych katalogach wyszukiwania
	if M.search_dirs then
		for _, dir in ipairs(M.search_dirs) do
			local test_file = utils.join_path(dir, clean_name .. ".mks")
			if vim.fn.filereadable(test_file) == 1 then
				return utils.join_path(dir, clean_name)
			end
		end
	end

	-- W przeciwnym razie użyj katalogu bazowego (base_dir)
	local session_dir = utils.normalize_path(M.options.base_dir)
	vim.fn.mkdir(session_dir, "p")

	return utils.join_path(session_dir, clean_name)
end

--- Zwraca pełną ścieżkę do pliku z małymi markerami dla danej sesji (.marks.json)
--- Zapisuje markery w podfolderze 'marks' w katalogu, w którym znajduje się sesja.
--- @param session_name string
--- @return string
local function get_marks_file(session_name)
	local base_path = get_session_base_path(session_name)
	local dir = vim.fn.fnamemodify(base_path, ":h")
	local name = vim.fn.fnamemodify(base_path, ":t")

	local marks_dir = utils.join_path(dir, "marks")
	vim.fn.mkdir(marks_dir, "p")

	return utils.join_path(marks_dir, name .. ".marks.json")
end

--- Zwraca ścieżkę do starszego pliku markerów (.marks.lua) dla zachowania kompatybilności
--- @param session_name string
--- @return string
local function get_legacy_marks_file(session_name)
	local base_path = get_session_base_path(session_name)
	return base_path .. ".marks.lua"
end

--- Zapisuje małe markery (a-z) dla WSZYSTKICH załadowanych buforów
--- @param session_name string
function M.save_small_marks(session_name)
	if not session_name or session_name == "" then
		return
	end

	local file = get_marks_file(session_name)
	local all_marks = {}

	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
			local buf_name = vim.api.nvim_buf_get_name(bufnr)
			if buf_name ~= "" and vim.bo[bufnr].buflisted then
				local buf_marks = {}
				for c = string.byte("a"), string.byte("z") do
					local m = string.char(c)
					local pos = vim.api.nvim_buf_get_mark(bufnr, m)
					if pos and pos[1] > 0 then
						buf_marks[m] = { pos[1], pos[2] }
					end
				end
				if next(buf_marks) ~= nil then
					local norm_buf_name = utils.normalize_path(buf_name)
					all_marks[norm_buf_name] = buf_marks
				end
			end
		end
	end

	utils.write_json_file(file, all_marks)
end

--- Przywraca małe markery dla wszystkich otwartych buforów (obsługuje JSON oraz wstecznie .marks.lua)
--- @param session_name string
function M.restore_small_marks(session_name)
	if not session_name or session_name == "" then
		return
	end

	local file = get_marks_file(session_name)
	local all_marks = utils.read_json_file(file)

	-- Sprawdź również alternatywną lokalizację w base_dir/marks jeśli sesja była w extra_dirs
	if not all_marks then
		local fallback_marks_file = utils.join_path(M.options.base_dir, "marks", session_name .. ".marks.json")
		all_marks = utils.read_json_file(fallback_marks_file)
	end

	-- Kompatybilność wsteczna ze starym formatem .marks.lua
	if not all_marks then
		local legacy_file = get_legacy_marks_file(session_name)
		if vim.fn.filereadable(legacy_file) == 1 then
			local ok, data = pcall(dofile, legacy_file)
			if ok and type(data) == "table" then
				all_marks = data
			end
		end
	end

	if not all_marks then
		return
	end

	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
			local raw_buf_name = vim.api.nvim_buf_get_name(bufnr)
			local norm_buf_name = utils.normalize_path(raw_buf_name)
			local marks = all_marks[norm_buf_name] or all_marks[raw_buf_name]
			if marks then
				for mark_char, pos in pairs(marks) do
					pcall(vim.api.nvim_buf_set_mark, bufnr, mark_char, pos[1], pos[2], {})
				end
			end
		end
	end
end

--- Pobiera listę sesji utworzonych przez plugin persisted.nvim
--- @return table
local function get_persisted_sessions()
	local persisted_dir = utils.join_path(vim.fn.stdpath("data"), "persisted")
	local sessions = {}

	if vim.fn.isdirectory(persisted_dir) == 0 then
		return sessions
	end

	local glob_pattern = utils.join_path(persisted_dir, "*.vim"):gsub("\\", "/")
	local session_files = vim.fn.glob(glob_pattern, 1, 1)

	for _, file_path in ipairs(session_files) do
		local name = vim.fn.fnamemodify(file_path, ":t:r")
		if name:match("@@") then
			local parts = vim.split(name, "@@")
			table.remove(parts, 1) -- usuń pierwszy pusty element

			local branch = nil
			if #parts > 0 and not parts[#parts]:match("[/\\]") then
				branch = table.remove(parts)
			end

			local path = table.concat(parts, "/")
			local display_name = branch and string.format("%s (%s)", path, branch) or path

			table.insert(sessions, {
				name = display_name,
				path = utils.normalize_path(file_path),
				is_persisted = true,
				modified_time = vim.fn.getftime(file_path),
				modified = os.date("%Y-%m-%d %H:%M", vim.fn.getftime(file_path)),
				display = string.format("%-25s [persisted]", display_name),
			})
		end
	end

	return sessions
end

--- Pobiera wszystkie dostępne sesje ze wszystkich skonfigurowanych katalogów (base_dir + extra_dirs)
--- @return table
function M.get_all_sessions()
	local session_names = {}
	local sessions_data = {}

	local search_dirs = M.search_dirs or { M.options.base_dir }

	for _, dir in ipairs(search_dirs) do
		local norm_dir = utils.normalize_path(dir)
		if vim.fn.isdirectory(norm_dir) == 1 then
			-- Wzorcowy glob Neovim działający bezbłędnie na Linux, Windows i macOS
			local glob_pattern = utils.join_path(norm_dir, "*.mks"):gsub("\\", "/")
			local session_files = vim.fn.glob(glob_pattern, 1, 1)

			for _, file_path in ipairs(session_files) do
				local norm_file = utils.normalize_path(file_path)
				local file_name = vim.fn.fnamemodify(norm_file, ":t")
				local session_name = file_name:gsub("%.mks$", "")

				if not session_names[session_name] then
					session_names[session_name] = true

					local timestamp = vim.fn.getftime(norm_file)
					local formatted_date = os.date("%Y-%m-%d %H:%M", timestamp)
					local dir_name = vim.fn.fnamemodify(norm_dir, ":t")

					table.insert(sessions_data, {
						name = session_name,
						path = norm_file,
						dir = norm_dir,
						is_persisted = false,
						modified_time = timestamp,
						modified = formatted_date,
						display = string.format("%-20s %-16s (%s)", session_name, formatted_date, dir_name),
					})
				end
			end
		end
	end

	-- Dodanie unikalnych sesji z persisted.nvim
	for _, ps in ipairs(get_persisted_sessions()) do
		if not session_names[ps.name] then
			session_names[ps.name] = true
			table.insert(sessions_data, ps)
		end
	end

	return sessions_data
end

--- Obsługa niezapisanych buforów przed zamknięciem sesji
--- @return boolean
local function save_modified_buffers()
	local modified_buffers = {}
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
			if vim.bo[bufnr].modified and vim.bo[bufnr].buflisted then
				local fname = vim.api.nvim_buf_get_name(bufnr)
				table.insert(modified_buffers, {
					bufnr = bufnr,
					fname = fname,
					display_name = fname ~= "" and vim.fn.fnamemodify(fname, ":~:.") or "[Brak nazwy]",
				})
			end
		end
	end

	if #modified_buffers == 0 then
		return true
	end

	local choices = "&Zapisz wszystko\n&Pytaj o każdy\n&Odrzuć zmiany\n&Anuluj"
	local choice = vim.fn.confirm(
		string.format("⚠️  Masz %d niezapisanych buforów. Co chcesz zrobić?", #modified_buffers),
		choices,
		1
	)

	if choice == 0 or choice == 4 then -- Anuluj / Esc
		vim.notify("❌ Przywracanie sesji przerwane.", vim.log.levels.WARN)
		return false
	elseif choice == 3 then -- Odrzuć zmiany
		for _, b in ipairs(modified_buffers) do
			vim.bo[b.bufnr].modified = false
		end
		vim.notify("🗑️  Niezapisane zmiany zostały odrzucone.", vim.log.levels.INFO)
		return true
	elseif choice == 1 then -- Zapisz wszystko
		local ok, err = pcall(vim.cmd, "silent! wall")
		if not ok then
			vim.notify("❌ Błąd zapisu buforów: " .. tostring(err), vim.log.levels.ERROR)
			return false
		end
		vim.notify("✅ Wszystkie zmodyfikowane bufory zapisane.", vim.log.levels.INFO)
		return true
	else -- Pytaj o każdy bufor
		for _, b in ipairs(modified_buffers) do
			vim.api.nvim_set_current_buf(b.bufnr)
			vim.cmd("redraw")
			local ans = vim.fn.confirm(string.format("Zapisać bufor [%s]?", b.display_name), "&Tak\n&Nie\n&Anuluj", 1)
			if ans == 0 or ans == 3 then
				vim.notify("❌ Przywracanie sesji przerwane.", vim.log.levels.WARN)
				return false
			elseif ans == 1 then
				if b.fname == "" then
					vim.notify("⚠️  Bufor nie ma nazwy pliku. Zapisz go ręcznie (:w <ścieżka>).", vim.log.levels.ERROR)
					return false
				end
				vim.cmd("silent! write " .. utils.escape(b.fname))
			end
		end
		return true
	end
end

--- Zapisuje bieżącą sesję, shada i markery
--- @param name string
function M.save(name)
	assert(name and name ~= "", "Nazwa sesji jest wymagana!")

	local base_path = get_session_base_path(name)
	local session_file = base_path .. ".mks"
	local shada_file = base_path .. ".shada"

	-- Bezpieczne wykonanie komend z escapowaniem ścieżek
	vim.cmd("mksession! " .. utils.escape(session_file))
	vim.cmd("wshada! " .. utils.escape(shada_file))

	-- Na Linuksie zabezpieczamy plik shada
	if not utils.is_win then
		pcall(vim.uv.fs_chmod, shada_file, 384)
	end

	M.current_session = name
	vim.opt.title = true
	vim.opt.titlestring = "Nvim: " .. tostring(name)

	vim.notify("✅ Sesja zapisana: " .. name, vim.log.levels.INFO)
end

--- Przywraca wskazaną sesję (ze standardowego katalogu lub z extra_dirs)
--- @param session_or_name string|table
function M.restore(session_or_name)
	if not save_modified_buffers() then
		return
	end

	local session_file = nil
	local shada_file = nil
	local session_name = nil

	if type(session_or_name) == "table" then
		session_name = session_or_name.name or session_or_name.value
		session_file = session_or_name.path
		if not session_or_name.is_persisted then
			shada_file = session_file:gsub("%.mks$", ".shada")
		end
	else
		session_name = tostring(session_or_name)
		local base_path = get_session_base_path(session_name)
		session_file = base_path .. ".mks"
		shada_file = base_path .. ".shada"

		-- Jeśli plik nie istnieje bezpośrednio, sprawdź czy jest w innych katalogach sesji
		if vim.fn.filereadable(session_file) == 0 then
			for _, s in ipairs(M.get_all_sessions()) do
				if s.name == session_name then
					session_file = s.path
					if not s.is_persisted then
						shada_file = session_file:gsub("%.mks$", ".shada")
					else
						shada_file = nil
					end
					break
				end
			end
		end
	end

	if session_file and vim.fn.filereadable(session_file) == 1 then
		M.current_session = session_name
		vim.opt.title = true
		vim.opt.titlestring = "Nvim: " .. session_name

		-- Zamykamy okna pływające
		utils.close_all_floating_windows()

		-- Czyste wyczyszczenie wszystkich starych buforów przed załadowaniem sesji
		vim.cmd("silent! %bdelete!")

		-- Wczytanie shada przed plikiem sesji
		if shada_file and vim.fn.filereadable(shada_file) == 1 then
			vim.cmd("rshada " .. utils.escape(shada_file))
		end

		-- Wczytanie pliku sesji
		vim.cmd("source " .. utils.escape(session_file))

		-- Przywrócenie małych markerów
		M.restore_small_marks(session_name)

		vim.notify("✅ Sesja przywrócona: " .. session_name, vim.log.levels.INFO)
	else
		vim.notify("❌ Nie znaleziono pliku sesji: " .. tostring(session_file or session_or_name), vim.log.levels.ERROR)
	end
end

--- Usuwa sesję i wszystkie powiązane z nią pliki (.mks, .shada, .marks.json, .marks.lua)
--- @param session table|string
function M.delete_session(session)
	local path = type(session) == "table" and session.path or nil
	local name = type(session) == "table" and session.name or session

	if not path then
		local base = get_session_base_path(name)
		path = base .. ".mks"
	end

	local mks = path
	local shada = mks:gsub("%.mks$", ".shada")
	local marks_json = get_marks_file(name)
	local marks_lua = get_legacy_marks_file(name)

	if vim.fn.filereadable(mks) == 1 then
		os.remove(mks)
	end
	if vim.fn.filereadable(shada) == 1 then
		os.remove(shada)
	end
	if vim.fn.filereadable(marks_json) == 1 then
		os.remove(marks_json)
	end
	if vim.fn.filereadable(marks_lua) == 1 then
		os.remove(marks_lua)
	end

	if M.current_session == name then
		M.current_session = nil
		vim.opt.titlestring = ""
	end

	vim.notify("✅ Usunięto sesję: " .. tostring(name), vim.log.levels.INFO)
end

--- Zmienia nazwę sesji
--- @param old_name string
--- @param new_name string
--- @return boolean, string
function M.rename_session(old_name, new_name)
	assert(old_name and new_name, "Wymagana jest stara i nowa nazwa!")

	local old_base = get_session_base_path(old_name)
	local old_mks = old_base .. ".mks"

	if vim.fn.filereadable(old_mks) == 0 then
		return false, "Sesja '" .. old_name .. "' nie istnieje."
	end

	-- Nowa sesja powstanie w tym samym katalogu co stara sesja
	local dir = vim.fn.fnamemodify(old_base, ":h")
	local new_base = utils.join_path(dir, new_name)
	local new_mks = new_base .. ".mks"

	if vim.fn.filereadable(new_mks) == 1 then
		return false, "Sesja '" .. new_name .. "' już istnieje."
	end

	local function try_rename(old_path, new_path)
		if vim.fn.filereadable(old_path) == 1 then
			local ok, err = os.rename(old_path, new_path)
			if not ok then
				return false, "Błąd zmiany nazwy " .. old_path .. ": " .. tostring(err)
			end
		end
		return true, nil
	end

	local ok, err = try_rename(old_mks, new_mks)
	if not ok then
		return false, err
	end

	ok, err = try_rename(old_base .. ".shada", new_base .. ".shada")
	if not ok then
		return false, err
	end

	ok, err = try_rename(get_marks_file(old_name), get_marks_file(new_name))
	if not ok then
		return false, err
	end

	ok, err = try_rename(get_legacy_marks_file(old_name), get_legacy_marks_file(new_name))
	if not ok then
		return false, err
	end

	if M.current_session == old_name then
		M.current_session = new_name
		vim.opt.titlestring = "Nvim: " .. new_name
	end

	return true, "Sesja '" .. old_name .. "' została zmieniona na '" .. new_name .. "'."
end

--- Inicjalizacja pluginu (setup)
--- @param opts table|nil
function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", {}, default_opts, opts or {})

	-- Normalizacja ścieżki base_dir
	M.options.base_dir = utils.normalize_path(M.options.base_dir)

	-- Przygotowanie katalogu bazowego
	vim.fn.mkdir(M.options.base_dir, "p")

	-- Przygotowanie katalogów wyszukiwania (unikalne)
	local seen = { [M.options.base_dir] = true }
	M.search_dirs = { M.options.base_dir }

	if M.options.extra_dirs and type(M.options.extra_dirs) == "table" then
		for _, raw_dir in ipairs(M.options.extra_dirs) do
			local norm = utils.normalize_path(raw_dir)

			-- Sprawdź alternatywną ścieżkę jeśli zaczyna się od "share/" i nie istnieje lokalnie
			if norm ~= "" and vim.fn.isdirectory(norm) == 0 and norm:match("^share/") then
				local candidate = utils.join_path(vim.fn.expand("~/.local"), norm)
				if vim.fn.isdirectory(candidate) == 1 then
					norm = candidate
				end
			end

			-- Dodaj jeśli katalog istnieje na dysku
			if norm ~= "" and vim.fn.isdirectory(norm) == 1 and not seen[norm] then
				seen[norm] = true
				table.insert(M.search_dirs, norm)
			end
		end
	end

	-- Rejestracja komend
	require("session_manager.commands")
end

return M
