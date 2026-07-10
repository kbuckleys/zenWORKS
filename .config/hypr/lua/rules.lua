-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

hl.window_rule({ match = { title = "System Update" }, float = true, center = true, size = { 1000, 1100 }})
hl.window_rule({ match = { title = "SongRec" }, float = true, center = true, size = { 800, 1100 }})
hl.window_rule({ match = { title = "sysmon" }, float = true, center = true, size = { 1000, 1100 }})
hl.window_rule({ match = { title = "Wiremix" }, float = true, center = true, size = { 650, 650 }})
hl.window_rule({ match = { title = "PARUZ" }, float = true, center = true, size = { 1000, 1100 }})
hl.window_rule({ match = { class = "steam", title = "Steam Settings" }, float = true})
hl.window_rule({ match = { title = "bandwhich" }, float = true, size = { 850, 850 }})
hl.window_rule({ match = { class = "swayimg" }, float = true, center = true})
hl.window_rule({ match = { initial_title = "Friends List" }, float = true})
hl.window_rule({ match = { class = "mpv" }, float = true, center = true})

-- HELIUM
hl.window_rule({ match = { class = "xdg-desktop-portal-gtk", title = "Open Files" }, float = true, size = { 950, 850 }})
hl.window_rule({ match = { class = "xdg-desktop-portal-gtk", title = "All Files" }, float = true, size = { 950, 850 }})
hl.window_rule({ match = { class = "xdg-desktop-portal-gtk", title = "Save File" }, float = true, size = { 950, 850 }})
hl.window_rule({ match = { class = "xdg-desktop-portal-gtk", title = "Open File" }, float = true, size = { 950, 850 }})
hl.window_rule({ match = { class = "xdg-desktop-portal-gtk", title = "&Print…" }, float = true, size = { 950, 850 }})
hl.window_rule({ match = { class = "xdg-desktop-portal-gtk", title = "Print" }, float = true, size = { 950, 850 }})

-- BORDERS
hl.window_rule({ match = { fullscreen = true }, border_color = "rgba(250, 179, 135, 0.6)"})
hl.window_rule({ match = { float = true }, border_color = "rgba(182, 224, 164, 0.6)"})
