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
	animation_speed = 10,
	prefix = "",

-- console logging
	console_preview = true,
	console_lines = 30,

-- Special application settings
	terminal_font = "hack.ttf",
	terminal_font_sz = 28,

-- Input Controls
	meta_1 = "RALT", -- "COMPOSE" or META on some platforms
	meta_2 = "RSHIFT",

-- Paths to always run on startup AFTER a space has been setup
	autorun = {
	},

-- Global keybindings, regardless of device profile,
-- valid prefixes: m1_ m2_ release_ and these can be combined.
	bindings = {
-- kill everything, shut down now
		["m1_ESCAPE"] = "shutdown",
		["m2_ESCAPE"] = "shutdown",

-- mouse device input controls
		["m1_F1"] = "mouse=Selected",
		["m1_F2"] = "mouse=View",
		["m1_F3"] = "mouse=Scale",
		["m1_F4"] = "mouse=Rotate",
		["m1_F5"] = "mouse=Position",
		["m1_F6"] = "mouse=IPD",

-- window management
		["m1_RETURN"] = "layers/current/terminal",
		["m1_LEFT"] = "layers/current/cycle=-1",
		["m1_RIGHT"] = "layers/current/cycle=1",
		["m1_UP"] = "layers/current/models/selected/child_swap=1",
		["m1_DOWN"] = "layers/current/models/selected/child_swap=-1",
		["m1_."] = "layers/current/models/selected/split=1",
		["m1_,"] = "layers/current/models/selected/split=-1",
		["m1_BACKSPACE"] = "layers/current/models/selected/destroy",

-- device control
		["m1_r"] = "hmd/reset",
		["m1_INSERT"] = "toggle_grab"
	},
};
