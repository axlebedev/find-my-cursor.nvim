local M = {}

-- Configurable callbacks and defaults
local FindCursorPre = vim.g.FindCursorPre or function() end
local FindCursorPost = vim.g.FindCursorPost or function() end
local FindCursorDefaultColor = vim.g.FindCursorDefaultColor or '#FF00FF'

local isActivated = false
local timer_id = 0
local savedCursorlineBg, savedCursorcolumnBg

-- Return highlight attribute value for a group
local function return_highlight_term(group, term)
  local output = vim.api.nvim_exec2('highlight ' .. group, true)
  local pattern = term .. '=\\zs\\S*'
  return string.match(output.output, pattern) or ''
end

-- Save window-local cursorline/cursorcolumn settings
local function save_window_local_settings()
  local bufs = vim.api.nvim_list_bufs()
  for _, bufnr in ipairs(bufs) do
    local winnr = vim.fn.bufwinnr(bufnr)
    if winnr > 0 then
      local saved = vim.api.nvim_win_get_var(winnr, 'savedSettings', {
        cursorline = vim.wo[winnr].cursorline,
        cursorcolumn = vim.wo[winnr].cursorcolumn,
      })
      vim.api.nvim_win_set_var(winnr, 'savedSettings', saved)
      vim.wo[winnr].cursorline = false
      vim.wo[winnr].cursorcolumn = false
    end
  end
end

-- Save global settings and prepare
local function save_settings()
  FindCursorPre()
  isActivated = true
  
  save_window_local_settings()
  
  if not savedCursorlineBg then
    savedCursorlineBg = return_highlight_term('CursorLine', 'guibg')
  end
  if not savedCursorcolumnBg then
    savedCursorcolumnBg = return_highlight_term('CursorColumn', 'guibg')
  end
end

-- Restore window-local settings
local function restore_window_local_settings()
  local bufs = vim.api.nvim_list_bufs()
  for _, bufnr in ipairs(bufs) do
    local winnr = vim.fn.bufwinnr(bufnr)
    if winnr > 0 then
      local saved_settings = vim.api.nvim_win_get_var(winnr, 'savedSettings', {})
      if saved_settings.cursorline ~= nil then
        vim.wo[winnr].cursorline = saved_settings.cursorline
      end
      if saved_settings.cursorcolumn ~= nil then
        vim.wo[winnr].cursorcolumn = saved_settings.cursorcolumn
      end
    end
  end
end

-- Restore all settings
local function restore_settings()
  vim.fn.timer_stop(timer_id)
  timer_id = 0
  
  if isActivated then
    isActivated = false
    
    if savedCursorlineBg then
      vim.cmd('highlight CursorLine guibg=' .. savedCursorlineBg)
    end
    if savedCursorcolumnBg then
      vim.cmd('highlight CursorColumn guibg=' .. savedCursorcolumnBg)
    end
    
    savedCursorlineBg = nil
    savedCursorcolumnBg = nil
    
    restore_window_local_settings()
    
    -- Clear autocmds
    vim.cmd('augroup findcursor')
    vim.cmd('autocmd!')
    vim.cmd('augroup END')
    
    FindCursorPost()
  end
  
  -- Ensure augroup is cleared
  vim.cmd('augroup findcursor')
  vim.cmd('autocmd!')
  vim.cmd('augroup END')
end

-- Main function: highlight cursor position temporarily
function M.find_cursor(color, auto_clear_timeout_ms)
  color = color or FindCursorDefaultColor
  auto_clear_timeout_ms = auto_clear_timeout_ms or 0
  
  if not isActivated then
    save_settings()
    vim.wo.cursorline = true
    vim.wo.cursorcolumn = true
  end
  
  if color:match('^#') then
    vim.cmd('highlight CursorLine guibg=' .. color)
    vim.cmd('highlight CursorColumn guibg=' .. color)
  end
  
  -- Setup autocmds to auto-restore
  vim.cmd('augroup findcursor')
  vim.cmd('autocmd!')
  vim.cmd([[
    autocmd BufNew,CursorMoved,CursorMovedI,BufLeave,CmdlineEnter,
    \ InsertEnter,InsertLeave * lua require('findcursor').restore_settings()
  ]])
  vim.cmd('augroup END')
  
  -- Auto-clear timer
  if auto_clear_timeout_ms > 0 then
    timer_id = vim.fn.timer_start(auto_clear_timeout_ms, function()
      restore_settings()
    end)
  end
end

-- Restore on module unload
vim.api.nvim_create_autocmd({"VimLeave"}, {
  callback = restore_settings
})

return M
