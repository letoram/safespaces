--
-- basic "no-op" vr-bridge default windowed composition
--
return {
	no_combiner = true,
	width = VRESW,
	height = VRESH,
	prelaunch = true,
--	headless = true,
	oversample_w = 1.0,
	oversample_h = 1.0,
	hmdarg = "ohmd_index=0",
	bindings = {
	}
};
