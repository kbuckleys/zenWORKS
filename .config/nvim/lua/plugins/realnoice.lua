-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

return {
  {
    "folke/noice.nvim",
    opts = function(_, opts)
      -- Use native cmdline UI but no popup floating with minimal float styling
      opts.cmdline = {
        view = "cmdline", -- use the regular commandline window, not popup
        format = {}, -- default format
      }
      opts.routes = {
        -- example route to disable message that pushes statusline
        {
          filter = { event = "msg_showmode" },
          opts = { skip = true },
        },
      }
      opts.views = {
        cmdline_popup = {
          -- Remove border and background from popup to simulate minimal overlay
          border = nil,
          win_options = {
            winblend = 100, -- fully transparent
            winhighlight = "NormalFloat:Normal",
          },
        },
      }
      -- Position the cmdline to overlay at bottom row (statusline position)
      opts.position = {
        cmdline = { row = "99%", col = "50%" },
      }
      return opts
    end,
  },
}
