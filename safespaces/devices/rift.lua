return {
	display = '^Rift/WMHD',
	oversample_w = 1.0,
	oversample_h = 1.0,
	distortion_model = "basic",
	prelaunch = true,
-- rift returns a larger width, causing the positions to be wrong
-- metadata overrides
-- width = .. (0.5width*oversample_w)
-- height = ..
-- center = ..
-- horizontal = ..
-- vertical = ..,
-- left_fov = ..
-- right_fov = ..
-- left_ar = ..
-- right_ar = ..
-- hsep = ..
-- vpos = ..
-- lens_distance = ..
-- eye_display = ..
	ipd = 1.029,
-- rotate_display = {"cw90", "ccw90", "180"}
-- distortion = {v1, v2, v3, v4}
-- abberation = {v1, v2, v3}
};
