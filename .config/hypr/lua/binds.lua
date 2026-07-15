-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

-- DEFAULTS
local term = "footclient"
local web = "helium-browser"
local fman = term .. " -e yazi"

-- MISC
hl.bind("SUPER + M", hl.dsp.exec_cmd(term .. " -T 'ZENU' -e ~/.config/scripts/ZENU.lua"))
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd(term .. " -T sysmon -e btop"))
hl.bind("SUPER + SHIFT + ESCAPE", hl.dsp.exec_cmd("hyprshutdown"))
hl.bind("SUPER + CONTROL + P", hl.dsp.exec_cmd("hyprpicker -a"))
hl.bind("SUPER + Y", hl.dsp.exec_cmd("killall -SIGUSR1 waybar"))
hl.bind("SUPER + SHIFT + Y", hl.dsp.exec_cmd("killall waybar && waybar"))
hl.bind("SUPER + RETURN", hl.dsp.exec_cmd(term))
hl.bind("SUPER + E", hl.dsp.exec_cmd(fman))
hl.bind("SUPER + B", hl.dsp.exec_cmd(web))

-- ROFI
hl.bind("SUPER + ESCAPE", hl.dsp.exec_cmd('rofi -show power-menu -modi "power-menu:~/.config/rofi/scripts/session.lua" -theme ~/.config/rofi/session.rasi'))
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("rofi -show calc -modi calc -no-show-match -no-sort -calc-command \"echo '{result}' | cliphist store\" -theme ~/.config/rofi/calc.rasi"))
hl.bind("SUPER + C", hl.dsp.exec_cmd("cliphist list | rofi -i -dmenu -theme ~/.config/rofi/cliphist.rasi | cliphist decode | wl-copy"))
hl.bind("SUPER + S", hl.dsp.exec_cmd("rofi -i -show recursivebrowser -disable-history -theme ~/.config/rofi/rootsearch.rasi"))   
hl.bind("SUPER + J", hl.dsp.exec_cmd('rofimoji -a type copy --selector-args="-theme ~/.config/rofi/rofimoji.rasi"'))
hl.bind("SUPER + V", hl.dsp.exec_cmd('rofi-rbw --selector-args="-theme rbw"'))
hl.bind("SUPER + K", hl.dsp.exec_cmd("~/.config/rofi/scripts/PKILL.lua"))
hl.bind("SUPER + D", hl.dsp.exec_cmd("~/.config/rofi/scripts/dict.lua"))
hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("rofi -show drun"))

-- WORKSPACES
hl.bind("SUPER + GRAVE", hl.dsp.workspace.toggle_special("special"))
hl.bind("SUPER + 1", hl.dsp.focus({ workspace = 1 }))
hl.bind("SUPER + 2", hl.dsp.focus({ workspace = 2 }))
hl.bind("SUPER + 3", hl.dsp.focus({ workspace = 3 }))
hl.bind("SUPER + 4", hl.dsp.focus({ workspace = 4 }))
hl.bind("SUPER + 5", hl.dsp.focus({ workspace = 5 }))

hl.bind("SUPER + SHIFT + GRAVE", hl.dsp.window.move({ workspace = "special:special" }))
hl.bind("SUPER + SHIFT + 1", hl.dsp.window.move({ workspace = 1 }))
hl.bind("SUPER + SHIFT + 2", hl.dsp.window.move({ workspace = 2 }))
hl.bind("SUPER + SHIFT + 3", hl.dsp.window.move({ workspace = 3 }))
hl.bind("SUPER + SHIFT + 4", hl.dsp.window.move({ workspace = 4 }))
hl.bind("SUPER + SHIFT + 5", hl.dsp.window.move({ workspace = 5 }))

-- WINDOW MANIPULATION
hl.bind("SUPER + Z", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen())
hl.bind("SUPER + SHIFT + W", hl.dsp.window.center())
hl.bind("SUPER + X", hl.dsp.layout("togglesplit"))
hl.bind("SUPER + SHIFT + Q", hl.dsp.window.kill())
hl.bind("SUPER + W", hl.dsp.window.pseudo())
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + F", function()
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
    hl.dispatch(hl.dsp.window.center())
end)

-- Mouse
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Focus
hl.bind("SUPER + RIGHT", hl.dsp.focus({ direction = "r" }))
hl.bind("SUPER + LEFT", hl.dsp.focus({ direction = "l" }))
hl.bind("SUPER + UP", hl.dsp.focus({ direction = "u" }))
hl.bind("SUPER + DOWN", hl.dsp.focus({ direction = "d" }))

-- Resize
hl.bind("SUPER + CONTROL + LEFT", hl.dsp.window.resize({ x = -100, y = 0, relative = true }), { repeating = true })
hl.bind("SUPER + CONTROL + RIGHT", hl.dsp.window.resize({ x = 100, y = 0, relative = true }), { repeating = true })
hl.bind("SUPER + CONTROL + DOWN", hl.dsp.window.resize({ x = 0, y = 100, relative = true }), { repeating = true })
hl.bind("SUPER + CONTROL + UP", hl.dsp.window.resize({ x = 0, y = -100, relative = true }), { repeating = true })

-- Swap Window
hl.bind("SUPER + ALT + RIGHT", hl.dsp.window.swap({ direction = "r" }), { description = "Swap window to the right" })
hl.bind("SUPER + ALT + LEFT", hl.dsp.window.swap({ direction = "l" }), { description = "Swap window to the left" })
hl.bind("SUPER + ALT + DOWN", hl.dsp.window.swap({ direction = "d" }), { description = "Swap window down" })
hl.bind("SUPER + ALT + UP", hl.dsp.window.swap({ direction = "u" }), { description = "Swap window up" })

-- Cycle & Z-Order
hl.bind("SUPER + TAB", function()
    hl.dispatch(hl.dsp.window.cycle_next())
    hl.dispatch(hl.dsp.window.bring_to_top())
end)

hl.bind("SUPER + SHIFT + TAB", function()
    hl.dispatch(hl.dsp.window.cycle_next({ next = false }))
    hl.dispatch(hl.dsp.window.bring_to_top())
end)   

-- GROUPING
hl.bind("SUPER + G", hl.dsp.group.lock_active({ action = "toggle" }))
hl.bind("SUPER + SHIFT + G", hl.dsp.group.toggle())

hl.bind("ALT + SHIFT + TAB", hl.dsp.group.prev(), { repeating = true })
hl.bind("ALT + TAB", hl.dsp.group.next(), { repeating = true })

hl.bind("SUPER + SHIFT + ALT + RIGHT", hl.dsp.window.move({ into_group = "r" }))
hl.bind("SUPER + SHIFT + ALT + LEFT", hl.dsp.window.move({ into_group = "l" }))
hl.bind("SUPER + SHIFT + ALT + DOWN", hl.dsp.window.move({ into_group = "d" }))
hl.bind("SUPER + SHIFT + ALT + UP", hl.dsp.window.move({ into_group = "u" }))

hl.bind("SUPER + SHIFT + CONTROL + RIGHT", hl.dsp.window.move({ out_of_group = true }))
hl.bind("SUPER + SHIFT + CONTROL + LEFT", hl.dsp.window.move({ out_of_group = true }))
hl.bind("SUPER + SHIFT + CONTROL + DOWN", hl.dsp.window.move({ out_of_group = true }))
hl.bind("SUPER + SHIFT + CONTROL + UP", hl.dsp.window.move({ out_of_group = true }))

-- AUDIO
hl.bind("SUPER + EQUAL", hl.dsp.exec_cmd("pamixer -i 1"), { repeating = true })
hl.bind("SUPER + MINUS", hl.dsp.exec_cmd("pamixer -d 1"), { repeating = true })
hl.bind("SUPER + 9", hl.dsp.exec_cmd(term .. " -T Wiremix -e wiremix"))
hl.bind("SUPER + 0", hl.dsp.exec_cmd("pamixer -t"))

hl.bind("SUPER + SHIFT + MINUS", hl.dsp.exec_cmd("playerctl play-pause"), { repeating = true })
hl.bind("SUPER + SHIFT + 0", hl.dsp.exec_cmd("playerctl previous"))
hl.bind("SUPER + SHIFT + EQUAL", hl.dsp.exec_cmd("playerctl next"))

-- SCREEN ZOOM
local MAX_ZOOM = 10
local ZOOM_TOGGLE_FACTOR = 0.5

local function zoom(offset)
    local current = hl.get_config("cursor.zoom_factor")
    if offset ~= nil then
        if current == 0 then
            current = 1
        end
        current = current + offset
    elseif current ~= 0 then
        current = 0
    else
        current = ZOOM_TOGGLE_FACTOR
    end
    if current <= 1 then
        current = 0
    else
        current = math.min(MAX_ZOOM, current)
    end
    hl.config({ cursor = { zoom_factor = current } })
end

hl.bind("SUPER + CTRL + 0", zoom)
hl.bind("SUPER + CTRL + EQUAL", function()
    zoom(0.2)
end, { repeating = true })
hl.bind("SUPER + CTRL + MINUS", function()
    zoom(-0.2)
end, { repeating = true })

hl.bind("SUPER + CTRL + mouse:274", zoom)
hl.bind("SUPER + CTRL + mouse_down", function()
    zoom(0.2)
end)
hl.bind("SUPER + CTRL + mouse_up", function()
    zoom(-0.2)
end)
