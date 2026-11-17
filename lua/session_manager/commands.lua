-- lua/session_manager/commands.lua
-- Definicja komend Neovim: :Smgr oraz aliasów :Ss, :Sr, :Sl
local SM = require("session_manager")
local utils = require("session_manager.utils")

local function get_auto_session_name()
	local cwd = vim.fn.getcwd()
	return vim.fn.fnamemodify(cwd, ":t")
end

local function find_session_by_name(name)
	for _, sess in ipairs(SM.get_all_sessions()) do
		if sess.name == name then
			return sess
		end
	end
	return nil
end

-- ====================================================================
-- Główna komenda: :Smgr {save|load|delete|list|current|rename}
-- ====================================================================
vim.api.nvim_create_user_command("Smgr", function(opts)
	local sub = opts.fargs[1]
	local arg = opts.fargs[2]

	if not sub then
		vim.notify("Użycie: :Smgr {save|load|delete|list|current|rename} [nazwa]", vim.log.levels.WARN)
		return
	end

	sub = sub:lower()

	if sub == "save" or sub == "s" then
		local session_name = arg or SM.current_session or get_auto_session_name()
		SM.save(session_name)
		SM.save_small_marks(session_name)

	elseif sub == "load" or sub == "l" or sub == "restore" or sub == "r" then
		if not arg then
			vim.notify("Podaj nazwę sesji: :Smgr load <nazwa>", vim.log.levels.ERROR)
			return
		end
		local session = find_session_by_name(arg)
		if session then
			SM.restore(session)
		else
			SM.restore(arg)
		end

	elseif sub == "delete" or sub == "d" or sub == "del" then
		if not arg then
			vim.notify("Podaj nazwę sesji: :Smgr delete <nazwa>", vim.log.levels.ERROR)
			return
		end
		local session = find_session_by_name(arg)
		if session then
			SM.delete_session(session)
		else
			SM.delete_session(arg)
		end

	elseif sub == "current" or sub == "c" then
		if SM.current_session then
			vim.notify("Aktualna sesja: " .. SM.current_session, vim.log.levels.INFO)
		else
			vim.notify("Brak aktywnej sesji", vim.log.levels.WARN)
		end

	elseif sub == "list" or sub == "ls" then
		require("session_manager.telescopeviewer").sessions()

	elseif sub == "rename" or sub == "rn" then
		local old_name = arg
		local new_name = opts.fargs[3]
		if not old_name or not new_name then
			vim.notify("Użycie: :Smgr rename <stara_nazwa> <nowa_nazwa>", vim.log.levels.ERROR)
			return
		end
		local ok, msg = SM.rename_session(old_name, new_name)
		vim.notify((ok and "✅ " or "❌ ") .. msg, ok and vim.log.levels.INFO or vim.log.levels.ERROR)

	else
		vim.notify("Nieznana akcja: " .. sub, vim.log.levels.WARN)
	end
end, {
	nargs = "*",
	desc = "Session Manager: save, load, delete, list, current, rename",
	complete = function(_, line)
		local parts = vim.split(line, "%s+")
		if #parts == 2 then
			return { "save", "load", "delete", "list", "current", "rename", "s", "l", "d", "ls", "c", "r", "rn", "del" }
		elseif #parts == 3 then
			local subcmd = parts[2]:lower()
			if
				subcmd == "load"
				or subcmd == "l"
				or subcmd == "restore"
				or subcmd == "r"
				or subcmd == "delete"
				or subcmd == "d"
				or subcmd == "del"
				or subcmd == "rename"
				or subcmd == "rn"
			then
				local names = {}
				for _, s in ipairs(SM.get_all_sessions()) do
					table.insert(names, s.name)
				end
				return names
			end
		end
		return {}
	end,
})

-- ====================================================================
-- Wsteczna kompatybilność i szybkie aliasy: :Ss, :Sr, :Sl
-- ====================================================================

-- :Ss [nazwa] -> Zapis sesji
vim.api.nvim_create_user_command("Ss", function(cmd_opts)
	local name = cmd_opts.fargs[1] or SM.current_session or get_auto_session_name()
	SM.save(name)
	SM.save_small_marks(name)
end, { nargs = "?", desc = "Zapisz bieżącą sesję" })

-- :Sr <nazwa> -> Przywrócenie sesji
vim.api.nvim_create_user_command("Sr", function(cmd_opts)
	if #cmd_opts.fargs == 0 then
		vim.notify("Podaj nazwę sesji: :Sr <nazwa>", vim.log.levels.WARN)
		return
	end
	local session = find_session_by_name(cmd_opts.fargs[1])
	if session then
		SM.restore(session)
	else
		SM.restore(cmd_opts.fargs[1])
	end
end, {
	nargs = 1,
	desc = "Przywróć sesję",
	complete = function()
		local names = {}
		for _, s in ipairs(SM.get_all_sessions()) do
			table.insert(names, s.name)
		end
		return names
	end,
})

-- :Sl -> Otwórz listę w Telescope
vim.api.nvim_create_user_command("Sl", function()
	require("session_manager.telescopeviewer").sessions()
end, { desc = "Otwórz listę sesji w Telescope" })
