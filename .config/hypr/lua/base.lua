-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

-- MONITORS
hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@100", position = "auto", transform = 3, })
hl.monitor({ output = "DP-1", mode = "2560x1440@180", position = "auto", })

-- ENV
-- Nvidia cache limit set to 20 GB
hl.env("__GL_SHADER_DISK_CACHE_SIZE", "21474836480")
hl.env("__GL_SHADER_DISK_CACHE_SKIP_CLEANUP", "1")

-- CURSOR
hl.env("HYPRCURSOR_THEME", "GoogleDot-Black")
hl.env("XCURSOR_THEME", "GoogleDot-Black")
hl.env("HYPRCURSOR_SIZE", "6")
hl.env("XCURSOR_SIZE", "6")

-- AUTOSTART
hl.on("hyprland.start", function()
	hl.exec_cmd("wl-paste --type image --watch cliphist store")
	hl.exec_cmd("wl-paste --type text --watch cliphist store")
	hl.exec_cmd("dbus-update-activation-environment --all")
	hl.exec_cmd("systemctl --user start hyprpolkitagent")
	hl.exec_cmd("wl-clip-persist --clipboard regular")
	hl.exec_cmd("xrandr --output DP-1 --primary")
	hl.exec_cmd("foot --server")
	hl.exec_cmd("hypridle")
	hl.exec_cmd("waybar")
	hl.exec_cmd("mako")
end)

hl.config({
	misc = {
		font_family = "0xProto Nerd Font",
		disable_splash_rendering = true,
		close_special_on_empty = true,
		disable_hyprland_logo = true,
		background_color = 0x000000,
		middle_click_paste = false,
	},

	ecosystem = {
		no_donation_nag = true,
	},

	input = {
		accel_profile = "flat",
		sensitivity = -0.6,
		repeat_delay = 200,
		repeat_rate = 35,
	},

	general = {
		col = {
			inactive_border = "rgba(155, 191, 191, 0.3)",
			active_border = "rgba(155, 191, 191, 0.6)",
		},
		gaps_out = 4,
		gaps_in = -1,
		snap = {
			enabled = true,
		},
	},

	dwindle = {
		preserve_split = true,
	},
    scrolling = {
        column_width = 0.95,
        focus_fit_method = 0,
    },
	master = {
		orientation = "center",
	},

	decoration = {
		dim_special = 0.8,
		blur = {
            enabled = false
		},
		shadow = {
			enabled = false,
		},
	},

	group = {
		col = {
			border_locked_inactive = "rgba(155, 191, 191, 0.3)",
			border_locked_active = "rgba(231, 130, 132, 1)",
			border_inactive = "rgba(155, 191, 191, 0.3)",
			border_active = "rgba(200, 164, 224, 1)",
		},
		groupbar = {
			text_color_inactive = "rgba(223, 223, 221, 1)",
			col = {
				locked_active = "rgba(231, 130, 132, 1)",
				locked_inactive = "rgba(32, 36, 42, 1)",
				active = "rgba(200, 164, 224, 1)",
				inactive = "rgba(32, 36, 42, 1)",
			},
			font_family = "0xProto Nerd Font",
			text_color = "rgba(0, 0, 0, 1)",
			font_weight_active = "bold",
			indicator_height = 0,
			gradients = true,
			font_size = 14,
			gaps_out = 0,
			rounding = 0,
			gaps_in = 0,
			height = 24,
		},
	},

	animations = {
		enabled = false,
	},

	binds = {
		hide_special_on_workspace_change = true,
		scroll_event_delay = 0,
	},
})
