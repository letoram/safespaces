return {
	distortion_model = "basic",
	headless = true,
	oversample_w = 1.0,
	oversample_h = 1.0,
	no_combiner = true,
	width = VRESW,
	height = VRESH,
	bindings = {
		["F1"] = "mouse=Selected",
		["F2"] = "mouse=View",
		["F3"] = "mouse=Scale",
		["F4"] = "hmd/distortion=basic",
		["F5"] = "hmd/distortion=none",
	}
};
