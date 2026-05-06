local wezterm = require("wezterm")

return {
	default_prog = { "tmux", "new-session", "-A", "-s", "main" },
	-- Font
	font = wezterm.font({
		family = "FiraCode Nerd Font Mono",
		weight = "Regular",
	}),
	font_size = 12.0,

	-- Rendering
	front_end = "OpenGL", -- smoother on modern GPUs
	enable_wayland = false, -- more stable on Plasma/X11
	line_height = 1.1,
	cell_width = 1.0,

	-- Cursor
	default_cursor_style = "BlinkingBar",
	cursor_blink_rate = 500,

	-- Colors / theme
	color_scheme = "Tokyo Night",
	window_background_opacity = 1.0,

	-- UI
	hide_tab_bar_if_only_one_tab = true,
	use_fancy_tab_bar = false,
	window_decorations = "RESIZE",
	scrollback_lines = 10000,

	-- Behavior
	adjust_window_size_when_changing_font_size = false,
	check_for_updates = false,

	-- Keybindings (Neovim-friendly)
	disable_default_key_bindings = false,

	harfbuzz_features = { "calt=1", "clig=1", "liga=2" },

	enable_kitty_keyboard = true,
}
