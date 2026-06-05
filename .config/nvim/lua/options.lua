-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

vim.opt.termguicolors = true
vim.g.netrw_banner = 0
vim.g.mapleader = " "
vim.opt.fillchars = { eob = " " }

vim.opt.nu = true
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

vim.opt.wrap = true
vim.opt.smartindent = true
vim.opt.inccommand = "split"
vim.opt.statuscolumn = "%=%l %s"

vim.opt.splitbelow = true
vim.opt.splitright = true

vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.laststatus = 3

vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = vim.fn.stdpath("data") .. "/undodir"
vim.opt.undofile = true

vim.opt.completeopt = "menuone,noselect,fuzzy,nosort"
vim.opt.shortmess:append("c")
vim.opt.clipboard:append("unnamedplus")
vim.opt.isfname:append("@-@")
vim.opt.scrolloff = 8

vim.opt.colorcolumn = "0"
vim.opt.signcolumn = "yes"

vim.opt.cmdheight = 0

-- Better Yazi borders
vim.api.nvim_set_hl(0, "FloatBorder", { fg = "#20242a" })
require("yazi").setup({
  yazi_floating_window_border = "single",
})

-- Command bar pushes the Statusline upwards instead of overlapping it
require('vim._core.ui2').enable({
  enable = true,
  msg = {
    targets = {
      [''] = 'msg',
      bufwrite = 'msg',
      echo = 'msg',
      echomsg = 'msg',
    },
    msg = {
      timeout = 5000,
    },
  },
})   

-- Highlight yanked text
vim.api.nvim_create_autocmd("TextYankPost", {
    callback = function()
        vim.hl.on_yank()
    end,
})

-- Retain cursor position post-buffer closure
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- 1. Set completeopt to include 'popup'
vim.opt.completeopt = { "menuone", "noselect", "popup" }

-- 2. Enable the new native completion engine on LSP attach
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("lsp_completion", { clear = true }),
  callback = function(args)
    local client_id = args.data.client_id
    local client = vim.lsp.get_client_by_id(client_id)
    
    if client and client:supports_method("textDocument/completion") then
      -- This is the critical line for 0.12+
      vim.lsp.completion.enable(true, client_id, args.buf, {
        autotrigger = true, 
      })
    end
  end,
})
