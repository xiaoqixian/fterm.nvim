-- Date:   Wed Jul 17 22:42:47 2024
-- Mail:   lunar_ubuntu@qq.com
-- Author: https://github.com/xiaoqixian

local utils = require("fterm.utils")

local Term = {}

local function new_buf(bufnr)
  return {
    bufnr = bufnr,
  }
end

function Term:new()
  return setmetatable({
    win = nil,
    buflist = {},
    index = 0,
    terminal = nil,
    config = utils.defaults,
  }, { __index = self })
end

function Term:setup(config)
  if not config then
    return vim.notify("fterm: setup() is optional. Please remove it!",
      vim.log.levels.WARN)
  end

  self.config = vim.tbl_deep_extend("force", self.config, config)

  return self
end

function Term:open_term()
  self.terminal = vim.fn.termopen(utils.is_cmd(self.config.cmd), {
    clear_env = self.config.clear_env,
    env = self.config.env,
    on_stdout = self.config.on_stdout,
    on_stdin = self.config.on_stdin,
    on_exit = function(...)
      self:on_exit(...)
    end
  })
end

function Term:create_win(buf)
  local cfg = self.config

  local dim = utils.get_dimension(cfg.dimensions)

  local win = vim.api.nvim_open_win(buf, true, {
      border = cfg.border,
      relative = 'editor',
      style = 'minimal',
      width = dim.width,
      height = dim.height,
      col = dim.col,
      row = dim.row,
  })

  vim.api.nvim_win_set_option(win, 'winhl', ('Normal:%s'):format(cfg.hl))
  vim.api.nvim_win_set_option(win, 'winblend', cfg.blend)

  return win
end

-- return a bool represents if a new buf
function Term:win_buf()
  local is_new_buf = false
  if self.index == 0 then
    self:create_buf()
    self.index = 1
    is_new_buf = true
  end

  local bufnr = self.buflist[self.index].bufnr
  if not utils.is_buf_valid(bufnr) then
    utils.filter(self.buflist, function(buf_info)
      utils.echoerr(("Buf %d is invalid"):format(buf_info.bufnr))
      return utils.is_buf_valid(buf_info.bufnr)
    end)
    -- reset the index
    self.index = 1
  else
    utils.echo(("Buf %d is still valid"):format(bufnr))
  end
  return self.buflist[self.index], is_new_buf
end

function Term:create_buf()
  local bufnr = vim.api.nvim_create_buf(false, true)
  self.buflist[#self.buflist+1] = new_buf(bufnr)
  self:set_keymap(bufnr)
end

function Term:open()
  if utils.is_win_valid(self.win) then
    return vim.api.nvim_set_current_win(self.win)
  end

  local buf, is_new_buf = self:win_buf()
  self.win = self:create_win(buf.bufnr)
  if is_new_buf then
    self:open_term()
  end

  return self
end

function Term:close(force)
  if not utils.is_win_valid(self.win) then
    return self
  end

  vim.api.nvim_win_close(self.win, force)

  self.win = nil

  if force then
    for _, buf in ipairs(self.buflist) do
      if utils.is_buf_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end

    self.buflist = {}
    self.index = 0
  end

  return self
end

function Term:toggle()
  if utils.is_win_valid(self.win) then
    self:close()
  else
    self:open()
  end
end

function Term:update_index(index)
  assert(index > 0, "Invalid index 0")
  -- utils.echo(("Update index to %d"):format(index))
  -- utils.echo(("Target buf: %d"):format(self.buflist[index]))
  self.index = index
  if utils.is_win_valid(self.win) then
    local buf = self.buflist[index]
    vim.api.nvim_win_set_buf(self.win, buf.bufnr)
  end
end

function Term:new_tab()
  self:create_buf()
  if utils.is_win_valid(self.win) then
    self:update_index(#self.buflist)
  end
  self:open_term()
end

function Term:switch_tab(updater)
  local n = #self.buflist
  if n <= 1 then
    return
  end

  self:remove_deleted()

  local index = updater(self.index)
  self:update_index(index)
end

function Term:remove_deleted()
  self.buflist = utils.filter(self.buflist, function(buf_info)
    return utils.is_buf_valid(buf_info.bufnr)
  end)
end

function Term:prev_tab()
  local n = #self.buflist
  self:switch_tab(function(index)
    if index == 1 then return n else return index-1 end
  end)
end

function Term:next_tab()
  local n = #self.buflist
  self:switch_tab(function(index)
    if index == n then return 1 else return index+1 end
  end)
end

function Term:on_exit(...)
  local curr_buf = self.buflist[self.index]
  self.buflist = utils.filter(self.buflist, function(buf_info)
    return buf_info.bufnr ~= curr_buf.bufnr
  end)

  local n = #self.buflist
  if n == 0 then
    self.index = 0
    self:close(true)
  else
    local index = self.index
    if index > #self.buflist then
      index = 1
    end
    self:update_index(index)
  end
end

function Term:set_keymap(bufnr)
  local keymap = self.config.keymap
  if keymap then
    for name, key in pairs(keymap) do
      local func = Term[name]
      if type(func) == "function" then
        vim.keymap.set("n", key,
          function()
            func(self)
          end,
          {
            desc = "fterm: "..name,
            noremap = true,
            silent = true,
            nowait = true,
            buffer = bufnr
          }
        )
      end
    end
  end
end

return Term
