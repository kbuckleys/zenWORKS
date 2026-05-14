-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

local layouts = { "dwindle", "scrolling", "master" }
local state = {}

hl.bind("SUPER + L", function()
	local ws = hl.get_active_workspace().id
	local current = state[ws] or "dwindle"
	local next = layouts[1]
	for i, v in ipairs(layouts) do
		if v == current then
			next = layouts[i % #layouts + 1]
			break
		end
	end
	state[ws] = next
	hl.workspace_rule({ workspace = tostring(ws), layout = next })
end)
