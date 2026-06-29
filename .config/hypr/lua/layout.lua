-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

local layouts = { "dwindle", "scrolling", "master" }
local state = {}

hl.bind("SUPER + SHIFT + L", function()
	local ws = hl.get_active_workspace().id
	local current = state[ws] or "dwindle" -- Assume first time
	local next_layout = layouts[1]
	for i, v in ipairs(layouts) do
		if v == current then
			next_layout = layouts[i % #layouts + 1]
			break
		end
	end
	state[ws] = next_layout
	hl.workspace_rule({ workspace = tostring(ws), layout = next_layout })
end)
