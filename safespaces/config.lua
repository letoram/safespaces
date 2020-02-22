return {
	device = "desktop",

-- Applied if it exists, devmaps/keyboard/ prefix
	keymap = "default.lua",

-- WM options
	layer_distance = 0.2,
	near_layer_sz = 1280,
	display_density = 33,
	curve = 0.9,
	layer_falloff = 0.9,
	animation_speed = 30,
	preview_w = 2560,
	preview_h = 1440,
	prefix = "",

-- composition rt- set to -1.0 to invert
	scale_y = -1.0,

-- safety-connection point
-- fallback = "durden"

-- external control
	control_path = "control",
	allow_ipc = true,

-- Special application settings
	terminal_font = "hack.ttf",
	terminal_font_sz = 24,
	terminal_opacity = 0.9,

-- icon set to be used
	icon_set = "default",

-- Input Controls
	meta_1 = "LMETA", -- "COMPOSE" or META on some platforms
	meta_2 = "RMETA"
};
