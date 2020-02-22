return {
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

-- window management, both arrows and hjkl for the same thing
	["m1_RETURN"] = "layers/current/terminal",
	["m1_LEFT"] = "layers/current/cycle=-1",
	["m1_h"] = "layers/current/cycle=-1",
	["m1_RIGHT"] = "layers/current/cycle=1",
	["m1_h"] = "layers/current/cycle=1",
	["m1_UP"] = "layers/current/models/selected/child_swap=1",
	["m1_k"] = "layers/current/models/selected/child_swap=1",
	["m1_DOWN"] = "layers/current/models/selected/child_swap=-1",
	["m1_j"] = "layers/current/models/selected/child_swap=-1",
	["m1_."] = "layers/current/models/selected/split=1",
	["m1_,"] = "layers/current/models/selected/split=-1",
	["m1_BACKSPACE"] = "layers/current/models/selected/destroy",
	["m1_m2_UP"] = "layers/cycle_input=1",
	["m1_m2_k"] = "layers/cycle_input=1",
	["m1_m2_DOWN"] = "layers/cycle_input=-1",
	["m1_m2_j"] = "layers/cycle_input=-1",
	["m1_m2_s"] = "layers/current/models/selected/cycle_stereo",
	["m1_m2_t"] = "layers/current/hide_show",

-- device control
	["m1_r"] = "hmd/reset",
	["m1_INSERT"] = "toggle_grab"
};
