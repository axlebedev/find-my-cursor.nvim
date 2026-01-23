local M = {}

local defaultOpts = {
  FindCursorHookPre = function() end,
  FindCursorHookPost = function() end,
  FindCursorDefaultColor = '#FF00FF',
}
M.config = defaultOpts

local isActivated = false
local timer_id = false
local savedCursorlineBg = nil
local savedCursorcolumnBg = nil

M.setup = function(opts)
  M.config = vim.tbl_deep_extend("force", defaultOpts, opts or {})
end

local function update_hl_bg(group_name, bg_val)
  vim.api.nvim_set_hl(
    0,
    group_name,
    vim.tbl_deep_extend(
      "force",
      vim.api.nvim_get_hl(0, { link = false, name = group_name }),
      { bg = bg_val }
    )
  )
end

-- Return highlight attribute value for a group
local function return_highlight_term(group, term)
    return vim.api.nvim_get_hl(0, { name = group })[term]
end

-- Save window-local cursorline/cursorcolumn settings
local function save_window_local_settings()
  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    vim.api.nvim_win_set_var(winid, 'savedSettings', {
      cursorline = vim.wo[winid].cursorline,
      cursorcolumn = vim.wo[winid].cursorcolumn,
    })
    vim.wo[winid].cursorline = false
    vim.wo[winid].cursorcolumn = false
  end
end

-- Save global settings and prepare
local function save_settings()
  M.config.FindCursorHookPre()
  isActivated = true

  save_window_local_settings()

  if (not savedCursorlineBg) then
    savedCursorlineBg = return_highlight_term('CursorLine', 'bg')
  end
  if (not savedCursorcolumnBg) then
    savedCursorcolumnBg = return_highlight_term('CursorColumn', 'bg')
  end
end

-- Restore window-local settings
local function restore_window_local_settings()
  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local savedSettings = vim.api.nvim_win_get_var(winid, 'savedSettings')
    if (savedSettings['cursorline'] ~= nil) then
      vim.wo[winid].cursorline = savedSettings['cursorline']
    end
    if (savedSettings['cursorcolumn'] ~= nil) then
      vim.wo[winid].cursorcolumn = savedSettings['cursorcolumn']
    end
  end
end

local function restore_settings(...)
    if timer_id then vim.loop.timer_stop(timer_id) end
    timer_id = false
    if (isActivated == true) then
      isActivated = false
      if savedCursorlineBg then
        update_hl_bg('CursorLine', savedCursorlineBg)
        savedCursorlineBg = nil
      end
      if savedCursorcolumnBg then
        update_hl_bg('CursorColumn', savedCursorcolumnBg)
        savedCursorcolumnBg = nil
      end
      restore_window_local_settings()
      M.config.FindCursorHookPost()
    end

    vim.api.nvim_clear_autocmds({ group = 'au_findcursor' })
end

M.FindCursor = function(...)
    local args = {...}
    local color = args[1] or M.config.FindCursorDefaultColor
    local autoClearTimeoutMs = args[2] or 0
    if not isActivated then
      save_settings()
      vim.opt_local.cursorline = true
      vim.opt_local.cursorcolumn = true
    end

    if (color:sub(1, 1) == '#') then
      update_hl_bg('CursorLine', color)
      update_hl_bg('CursorColumn', color)
    end

    local au_findcursor = vim.api.nvim_create_augroup("au_findcursor", { clear = true })
    vim.api.nvim_create_autocmd({
      "BufNew",
      "CursorMoved",
      "CursorMovedI",
      "BufLeave",
      "CmdlineEnter",
      "InsertEnter",
      "InsertLeave",
    }, {
      pattern = "*",
      group = au_findcursor,
      callback = function()
        restore_settings()
      end,
    })
    if autoClearTimeoutMs > 0 then
      timer_id = vim.loop.timer_start(autoClearTimeoutMs, function() restore_settings() end)
    end
end

vim.api.nvim_create_user_command(
  'FindCursor',
  function(opts)
    M.FindCursor(unpack(opts.fargs) or nil)
  end,
  {
    nargs = '*', -- Zero or more argumentsbar = true,
  }
)

return M
