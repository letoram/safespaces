--
-- basic "no-op" vr-bridge default windowed composition
--
return {
	width = VRESW,
	height = VRESH,
	headless = true,
	oversample_w = 1.0,
	oversample_h = 1.0,
	hmdarg = "ohmd_index=0",
	bindings = {
	}
};
