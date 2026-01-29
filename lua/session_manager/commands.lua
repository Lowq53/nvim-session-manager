-- lua/session_manager/commands.lua
local M = require("session_manager")

-- Helper: auto session name
local function get_auto_session_name()
    local cwd = vim.fn.getcwd()
    return vim.fn.fnamemodify(cwd, ":t")
end

-- Helper: find session by name
local function find_session_by_name(name)
    local sessions = M.get_all_sessions()
    for _, sess in ipairs(sessions) do
        if sess.name == name then
            return sess
        end
    end
    return nil
end

-- Main command: :Smgr
vim.api.nvim_create_user_command("Smgr", function(opts)
    local sub = opts.fargs[1]
    local arg = opts.fargs[2]

    if not sub then
        vim.notify("Użycie: :Smgr {save|load|delete|list|current} [nazwa]", vim.log.levels.WARN)
        return
    end

    sub = sub:lower()

    if sub == "save" or sub == "s" then
        local session_name
        if arg then
            session_name = arg
        elseif M.current_session then
            session_name = M.current_session
            vim.notify("Zapisuję do aktualnej sesji: " .. session_name, vim.log.levels.INFO)
        else
            session_name = get_auto_session_name()
            vim.notify("Brak aktywnej sesji – zapisuję jako: " .. session_name, vim.log.levels.WARN)
        end
        M.save(session_name)

    elseif sub == "load" or sub == "l" or sub == "restore" or sub == "r" then
        if not arg then
            vim.notify("Podaj nazwę: :Smgr load <nazwa>", vim.log.levels.ERROR)
            return
        end
        M.restore(arg)

    elseif sub == "delete" or sub == "d" or sub == "del" then
        if not arg then
            vim.notify("Podaj nazwę: :Smgr delete <nazwa>", vim.log.levels.ERROR)
            return
        end
        local session = find_session_by_name(arg)
        if session then
            M.delete_session(session)
        else
            vim.notify("Sesja nie znaleziona: " .. arg, vim.log.levels.ERROR)
        end

    elseif sub == "current" or sub == "c" then
        if M.current_session then
            vim.notify("Aktualna sesja: " .. M.current_session, vim.log.levels.INFO)
        else
            vim.notify("Brak aktywnej sesji", vim.log.levels.WARN)
        end

    elseif sub == "list" or sub == "ls" then
        require("session_manager.telescopeviewer").sessions()

    else
        vim.notify("Nieznana akcja: " .. sub, vim.log.levels.WARN)
    end
end, {
    nargs = "*",
    desc = "Session Manager: save/load/delete/list/current",
    complete = function(arglead, line)
        local parts = vim.split(line, "%s+")
        if #parts == 2 then
            return { "save", "load", "delete", "list", "current", "s", "l", "d", "ls", "c", "restore", "r", "del" }
        end
        return {}
    end,
})
