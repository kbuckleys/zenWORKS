-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

return {
  "folke/snacks.nvim",
  opts = {
    dashboard = {
      width = 60,
      preset = {
        header = [[
┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
└─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
]],
      },
      formats = {
        header = { "%s", align = "center" },
      },
      sections = {
        { section = "header" },
        { section = "keys", gap = 1, padding = 1 },
        { section = "startup" },
      },
    },
  },
}
