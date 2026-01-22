vim.api.nvim_create_user_command('FindCursor', function(opts)
  require('findcursor').find_cursor(opts.args ~= '' and opts.args or nil)
end, {
  nargs = '*',  -- Zero or more arguments
  bar = true,   -- Allow | line continuation
})

