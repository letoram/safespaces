return {
	device = "monoscopic",
	keymap = "default.lua",
	layer_distance = 0.2,
	near_layer_sz = 1280,
	display_density = 33,
	curve = 0.9,
	layer_falloff = 0.9,
	terminal_font = "hack.ttf",
	terminal_font_sz = 28,
	animation_speed = 10,
	prefix = "",

-- input
	meta_1 = "RALT", -- "COMPOSE" or META on some platforms
	meta_2 = "RSHIFT",

	bindings = {
		["RETURN"] = "layers/current/terminal",
		["LEFT"] = "layers/current/cycle=-1",
		["RIGHT"] = "layers/current/cycle=1",
		["UP"] = "layers/current/models/selected/child_swap=1",
		["DOWN"] = "layers/current/models/selected/child_swap=-1",
		["."] = "layers/current/models/selected/split=1",
		[","] = "layers/current/models/selected/split=-1",
		["F5"] = "hmd/reset",
		["F9"] = "hmd/step_ipd=-0.01",
		["F10"] = "hmd/step_ipd=0.01",

--		["DELETE"] = "layers/current/models/selected/destroy",
		["BACKSPACE"] = "layers/current/models/selected/destroy",

-- terribly aggressive, should perhaps have a modifier or UI based solution
		["ESCAPE"] = "shutdown",
	}
};
