local U = require('fterm.utils')

local A = vim.api
local fn = vim.fn
local cmd = A.nvim_command

---@alias WinId number Floating Window's ID
---@alias BufId number _Terminal Buffer's ID

---@class _Term
---@field win WinId
---@field buf BufId
---@field terminal? number _Terminal's job id
---@field config Config
local _Term = {}

---_Term:new creates a new terminal instance
function _Term:new()
    return setmetatable({
        win = nil,
        buf = nil,
        terminal = nil,
        config = U.defaults,
    }, { __index = self })
end

---_Term:setup overrides the terminal windows configuration ie. dimensions
---@param cfg Config
---@return _Term
function _Term:setup(cfg)
    if not cfg then
        return vim.notify('fterm: setup() is optional. Please remove it!', vim.log.levels.WARN)
    end

    self.config = vim.tbl_deep_extend('force', self.config, cfg)

    return self
end

---_Term:store adds the given floating windows and buffer to the list
---@param win WinId
---@param buf BufId
---@return _Term
function _Term:store(win, buf)
    self.win = win
    self.buf = buf

    return self
end

---_Term:create_buf creates a scratch buffer for floating window to consume
---@return BufId
function _Term:create_buf()
    -- If previous buffer exists then return it
    local prev = self.buf

    if U.is_buf_valid(prev) then
        return prev
    end

    local buf = A.nvim_create_buf(false, true)

    -- this ensures filetype is set to Fterm on first run
    A.nvim_buf_set_option(buf, 'filetype', self.config.ft)

    return buf
end

---_Term:create_win creates a new window with a given buffer
---@param buf BufId
---@return WinId
function _Term:create_win(buf)
    local cfg = self.config

    local dim = U.get_dimension(cfg.dimensions)

    local win = A.nvim_open_win(buf, true, {
        border = cfg.border,
        relative = 'editor',
        style = 'minimal',
        width = dim.width,
        height = dim.height,
        col = dim.col,
        row = dim.row,
    })

    A.nvim_win_set_option(win, 'winhl', ('Normal:%s'):format(cfg.hl))
    A.nvim_win_set_option(win, 'winblend', cfg.blend)

    return win
end

---_Term:handle_exit gracefully closed/kills the terminal
---@private
function _Term:handle_exit(job_id, code, ...)
    if self.config.auto_close and code == 0 then
        self:close(true)
    end
    if self.config.on_exit then
        self.config.on_exit(job_id, code, ...)
    end
end

---_Term:prompt enters into prompt
---@return _Term
function _Term:prompt()
    -- cmd('startinsert')
    return self
end

---_Term:term opens a terminal inside a buffer
---@return _Term
function _Term:open_term()
    -- NOTE: `termopen` will fails if the current buffer is modified
    self.terminal = fn.termopen(U.is_cmd(self.config.cmd), {
        clear_env = self.config.clear_env,
        env = self.config.env,
        on_stdout = self.config.on_stdout,
        on_stderr = self.config.on_stderr,
        on_exit = function(...)
            self:handle_exit(...)
        end,
    })

    -- This prevents the filetype being changed to `term` instead of `F_Term` when closing the floating window
    A.nvim_buf_set_option(self.buf, 'filetype', self.config.ft)

    return self:prompt()
end

---_Term:open does all the magic of opening terminal
---@return _Term
function _Term:open()
    -- Move to existing window if the window already exists
    if U.is_win_valid(self.win) then
        return A.nvim_set_current_win(self.win)
    end

    -- Create new window and terminal if it doesn't exist
    local buf = self:create_buf()
    local win = self:create_win(buf)

    -- This means we are just toggling the terminal
    -- So we don't have to call `:open_term()`
    if self.buf == buf then
        return self:store(win, buf):prompt()
    end

    return self:store(win, buf):open_term()
end

---_Term:close does all the magic of closing terminal and clearing the buffers/windows
---@param force? boolean If true, kill the terminal otherwise hide it
---@return _Term
function _Term:close(force)
    if not U.is_win_valid(self.win) then
        return self
    end
    
    A.nvim_win_close(self.win, {})

    self.win = nil

    if force then
        if U.is_buf_valid(self.buf) then
            A.nvim_buf_delete(self.buf, { force = true })
        end

        fn.jobstop(self.terminal)

        self.buf = nil
        self.terminal = nil
    end

    return self
end

---_Term:toggle is used to toggle the terminal window
---@return _Term
function _Term:toggle()
    -- If window is stored and valid then it is already opened, then close it
    if U.is_win_valid(self.win) then
        self:close()
    else
        self:open()
    end

    return self
end

---_Term:run is used to (open and) run commands to terminal window
---@param command Command
---@return _Term
function _Term:run(command)
    self:open()

    local exec = U.is_cmd(command)

    A.nvim_chan_send(
        self.terminal,
        table.concat({
            type(exec) == 'table' and table.concat(exec, ' ') or exec,
            A.nvim_replace_termcodes('<CR>', true, true, true),
        })
    )

    return self
end

return _Term
