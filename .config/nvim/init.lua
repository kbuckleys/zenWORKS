------------------------------------------------------------
--  | |__  _   _  ___| | ____      _____  _ __| | _____   --
--  | '_ \| | | |/ __| |/ /\ \ /\ / / _ \| '__| |/ / __|  --
--  | |_) | |_| | (__|   <  \ V  V / (_) | |  |   <\__ \  --
--  |_.__/ \__,_|\___|_|\_\  \_/\_/ \___/|_|  |_|\_\___/  --
--                                                        --
--             https://github.com/kbuckleys/              --
------------------------------------------------------------

require("config.lazy")

local function set_transparency()
  vim.cmd([[
    hi Normal guibg=NONE ctermbg=NONE
    hi NormalNC guibg=NONE ctermbg=NONE
    hi SignColumn guibg=NONE ctermbg=NONE
    hi StatusLine guibg=NONE ctermbg=NONE
    hi StatusLineNC guibg=NONE ctermbg=NONE
    hi VertSplit guibg=NONE ctermbg=NONE
    hi TabLine guibg=NONE ctermbg=NONE
    hi TabLineFill guibg=NONE ctermbg=NONE
    hi TabLineSel guibg=NONE ctermbg=NONE
    hi Pmenu guibg=NONE ctermbg=NONE
    hi PmenuSel guibg=NONE ctermbg=NONE
    hi NeoTreeNormal guibg=NONE ctermbg=NONE
    hi NeoTreeNormalNC guibg=NONE ctermbg=NONE
    hi NeoTreeWinSeparator guibg=NONE ctermbg=NONE
    hi NeoTreeEndOfBuffer guibg=NONE ctermbg=NONE
    hi EndOfBuffer guibg=NONE ctermbg=NONE
  ]])
end

set_transparency()

vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "*",
  callback = set_transparency,
})

vim.cmd([[colorscheme vague]])

vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.cmd([[
      hi NormalFloat guibg=NONE ctermbg=NONE
      hi FloatBorder guibg=NONE ctermbg=NONE
    ]])
    vim.o.winblend = 20
  end,
})

vim.defer_fn(function()
  if pcall(require, "cmp") then
    require("cmp").setup({
      window = {
        completion = {
          border = "none",
          winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder",
          winblend = 20,
        },
        documentation = {
          border = "none",
          winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder",
          winblend = 20,
        },
      },
    })
  end
end, 100)
