-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

vim.pack.add({
  'https://github.com/lukas-reineke/indent-blankline.nvim.git',
  'https://github.com/brenoprata10/nvim-highlight-colors.git',
  'https://github.com/nvim-treesitter/nvim-treesitter.git',
  'https://github.com/nvim-tree/nvim-web-devicons.git',
  'https://github.com/nvim-lualine/lualine.nvim.git',
  "https://github.com/rafamadriz/friendly-snippets",
  'https://github.com/akinsho/bufferline.nvim.git',
  'https://github.com/nvim-lua/plenary.nvim.git',
  'https://github.com/mikavilpas/yazi.nvim.git',
  "https://github.com/neovim/nvim-lspconfig",
  "https://github.com/mason-org/mason.nvim",
  "https://github.com/MunifTanjim/nui.nvim",
  'https://github.com/ibhagwan/fzf-lua.git',
  "https://github.com/folke/which-key.nvim",
  "https://github.com/chentoast/marks.nvim",
  "https://github.com/nvim-mini/mini.nvim",
  "https://github.com/tpope/vim-fugitive",
  "https://github.com/folke/noice.nvim",
  "https://github.com/windwp/nvim-autopairs",
})

-- Load and configure nvim-autopairs
vim.cmd("packadd nvim-autopairs")
local status_ok, npairs = pcall(require, "nvim-autopairs")
if status_ok then
  npairs.setup({
    check_ts = true, -- Enable Treesitter integration
    disable_filetype = { "TelescopePrompt", "spectre_panel" },
    fast_wrap = {}
  })
end

-- Update
vim.api.nvim_create_user_command("PackUpdate", function()
    vim.pack.update()
end, { desc = "Update all plugins" })

require('marks').setup()
require("mini.surround").setup()

require("noice").setup({
  cmdline = {
    enabled = false
  },
  messages = {
    enabled = true,
    view_search = "virtualtext"
  },
  popupmenu = {
    enabled = false
  }
})   

require('nvim-highlight-colors').setup({
  render = 'background',
})   

require("ibl").setup({
  indent = { char = "│" },
  scope = {
    enabled = true,
    show_start = true,
    show_end = true
  }
})   

require("mini.notify").setup({
	-- only show messages
    content = {
        format = function(notif)
            return notif.msg
        end
    }
})

require("mini.cmdline").setup({
    autocorrect = { enable = false }
})

require("mini.completion").setup({
    lsp_completion = {
        auto_setup = true
    }
})
