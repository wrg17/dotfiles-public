local wezterm = require("wezterm")

local config = {
	-- Prepend Homebrew paths so tmux is found when WezTerm is launched as a GUI app
	-- (macOS GUI apps inherit a minimal PATH that excludes /usr/local/bin and /opt/homebrew/bin)
	set_environment_variables = {
		PATH = "/opt/homebrew/bin:/usr/local/bin:" .. (os.getenv("PATH") or ""),
	},
	default_prog = { "tmux", "new-session", "-A", "-s", "main" },
	-- Font
	font = wezterm.font({
		family = "FiraCode Nerd Font Mono",
		weight = "Regular",
	}),
	font_size = 12.0,

	-- Rendering (front_end omitted — let WezTerm default to WebGpu/Metal/Vulkan)
	enable_wayland = false, -- more stable on Plasma/X11
	line_height = 1.1,
	cell_width = 1.0,

	-- Cursor
	default_cursor_style = "BlinkingBar",
	cursor_blink_rate = 500,

	-- Colors / theme
	color_scheme = "Dracula (Official)",
	window_background_opacity = 1.0,

	-- UI
	hide_tab_bar_if_only_one_tab = true,
	use_fancy_tab_bar = false,
	window_decorations = "TITLE | RESIZE",
	scrollback_lines = 10000,

	-- Behavior
	adjust_window_size_when_changing_font_size = false,
	check_for_updates = false,

	-- Keybindings (using WezTerm defaults)
	disable_default_key_bindings = false,

	harfbuzz_features = { "calt=1", "clig=1", "liga=2" },
}

-- Per-machine overrides: drop ~/.config/wezterm/wezterm.lua.local returning a
-- table to override any of the above (e.g. {front_end = "OpenGL"} on a machine
-- where WebGpu glitches). File is gitignored via the repo's *.local pattern.
local ok, local_config = pcall(dofile, os.getenv("HOME") .. "/.config/wezterm/wezterm.lua.local")
if ok and type(local_config) == "table" then
	for k, v in pairs(local_config) do
		config[k] = v
	end
end

return config
