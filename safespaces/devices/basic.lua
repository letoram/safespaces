--
-- basic "no-op" vr-bridge default windowed composition
--
return {
--	distortion_model = "basic",
	no_combiner = true,
	width = 0.5 * VRESW,
	height = VRESH,
	oversample_w = 1.4,
	oversample_h = 1.4,
	hmdarg = "ohmd_index=-1",
	bindings = {
	["R"] = "hmd/reset"
	}
};
