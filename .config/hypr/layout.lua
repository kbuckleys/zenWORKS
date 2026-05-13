-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

local layouts = { "dwindle", "scrolling", "master" }
local current_index = 0

hl.bind("SUPER + L", function()
	current_index = (current_index % #layouts) + 1
	hl.config({ general = { layout = layouts[current_index] } })
end)
