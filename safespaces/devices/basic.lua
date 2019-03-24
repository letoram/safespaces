--
-- basic "no-op" vr-bridge default windowed composition
--
return {
	no_combiner = true,
	width = 0.5 * VRESW,
	height = VRESH,
	oversample_w = 1.0,
	oversample_h = 1.0,
	hmdarg = "ohmd_index=-1",
	bindings = {
	}
};
