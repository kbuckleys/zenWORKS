-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

hl.window_rule({ match = { class = "xdg-desktop-portal-gtk" }, float = true, size = { 1000, 1000 }})
hl.window_rule({ match = { class = "steam", title = "Steam Settings" }, float = true})
hl.window_rule({ match = { class = "kitty", title = "termfilechooser" }, float = true, size = {1000, 450}})
hl.window_rule({ match = { title = "bandwhich" }, float = true, size = { 1000, 800 }})
hl.window_rule({ match = { title = "SongRec" }, float = true, size = { 800, 1100 }})
hl.window_rule({ match = { title = "sysmon" }, float = true, size = { 1000, 1100 }})
hl.window_rule({ match = { title = "Wiremix" }, float = true, size = { 650, 650 }})
hl.window_rule({ match = { title = "ZENU" }, float = true, size = { 1000, 1100 }})
hl.window_rule({ match = { class = "swayimg" }, float = true })
hl.window_rule({ match = { class = "mpv" }, float = true, })

-- Temp workaround for Helium
hl.window_rule({ match = { class = "helium" }, suppress_event = "maximize" })

-- BORDERS
hl.window_rule({ match = { float = true }, border_color = "rgba(182, 224, 164, 0.6)"})
hl.window_rule({ match = { fullscreen = true }, border_color = "rgba(250, 179, 135, 0.6)"})

-- SPECIAL WORKSPACE
hl.workspace_rule({ workspace = "special:special", gaps_out = 30 })
