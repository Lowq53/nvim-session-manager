-- lua/session_manager/utils.lua
-- Moduł narzędziowy: detekcja platformy, obsługa ścieżek i okien pływających
local M = {}

-- Detekcja systemu operacyjnego
M.is_win = vim.fn.has("win32") == 1
M.is_mac = vim.fn.has("mac") == 1
M.is_wsl = vim.fn.has("wsl") == 1
M.is_linux = vim.fn.has("unix") == 1 and not M.is_mac

-- Separator ścieżki
M.path_sep = M.is_win and "\\" or "/"

--- Normalizuje ścieżkę do standardowego formatu z ukośnikami /
--- Działa bezbłędnie na Windows, Linux i macOS
--- @param path string
--- @return string
function M.normalize_path(path)
	if not path or path == "" then
		return ""
	end
	-- Rozwiń ~ do katalogu domowego
	local expanded = vim.fn.expand(path)
	-- Normalizuj ukośniki
	local normalized = expanded:gsub("\\", "/")
	-- Usuń podwójne ukośniki (z wyjątkiem np. protocol:// jeśli by wystąpił)
	normalized = normalized:gsub("//+", "/")
	-- Usuń końcowy ukośnik (chyba że to root /)
	if #normalized > 1 and normalized:sub(-1) == "/" then
		normalized = normalized:sub(1, -2)
	end
	return normalized
end

--- Bezpiecznie łączy segmenty ścieżki
--- @param ... string
--- @return string
function M.join_path(...)
	local parts = { ... }
	local valid_parts = {}
	for _, p in ipairs(parts) do
		if p and p ~= "" then
			table.insert(valid_parts, p)
		end
	end
	local raw = table.concat(valid_parts, "/")
	return M.normalize_path(raw)
end

--- Bezpiecznie escapuje ścieżkę pliku dla komend Vimscript (:mksession, :source itp.)
--- @param path string
--- @return string
function M.escape(path)
	return vim.fn.fnameescape(path)
end

--- Sprawdza, czy w Neovimie otwarte jest jakiekolwiek okno pływające (floating window)
--- @return boolean, number|nil
function M.has_floating_windows()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_is_valid(win) then
			local config = vim.api.nvim_win_get_config(win)
			if config.relative and config.relative ~= "" then
				return true, win
			end
		end
	end
	return false, nil
end

--- Bezpiecznie zamyka wszystkie okna pływające
function M.close_all_floating_windows()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_is_valid(win) then
			local config = vim.api.nvim_win_get_config(win)
			if config.relative and config.relative ~= "" then
				pcall(vim.api.nvim_win_close, win, true)
			end
		end
	end
end

--- Bezpieczny zapis danych do pliku w formacie JSON
--- @param filepath string
--- @param data table
--- @return boolean, string|nil
function M.write_json_file(filepath, data)
	local ok, json_str = pcall(vim.json.encode, data)
	if not ok then
		return false, "Błąd serializacji JSON: " .. tostring(json_str)
	end

	local f, err = io.open(filepath, "w")
	if not f then
		return false, "Nie można otworzyć pliku do zapisu: " .. tostring(err)
	end

	f:write(json_str)
	f:close()

	-- Na Linuksie ustawiamy restrykcyjne uprawnienia (0600 - tylko właściciel)
	if not M.is_win then
		pcall(vim.uv.fs_chmod, filepath, 384)
	end

	return true, nil
end

--- Bezpieczny odczyt pliku JSON
--- @param filepath string
--- @return table|nil
function M.read_json_file(filepath)
	if vim.fn.filereadable(filepath) ~= 1 then
		return nil
	end

	local f = io.open(filepath, "r")
	if not f then
		return nil
	end

	local content = f:read("*a")
	f:close()

	if not content or content == "" then
		return nil
	end

	local ok, data = pcall(vim.json.decode, content)
	if ok and type(data) == "table" then
		return data
	end
	return nil
end

return M
