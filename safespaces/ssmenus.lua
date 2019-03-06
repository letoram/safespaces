--
-- local extensions to the action tree from the [shared] vrmenus.
-- extends with features for mouse control, system shutdown etc.
--

local function rotate_camera(WM, iotbl)
	if (iotbl.digital) then
		return;
	end

	if (iotbl.subid == 0) then
		rotate3d_model(WM.camera, 0, 0, iotbl.samples[iotbl.relative and 1 or 2], 0, ROTATE_RELATIVE);
	elseif (iotbl.subid == 1) then
		rotate3d_model(WM.camera, 0, iotbl.samples[iotbl.relative and 1 or 2], 0, 0, ROTATE_RELATIVE);
	end
	return;
end

local function get_fact(base, ext, min, m1, m2)
	local res = base;
	if (m1) then
		res = res * ext;
	end
	if (m2) then
		res = res * min;
	end
	return res;
end

local ipd_modes = {
	{"IPD",
function(WM, vr_state, delta, m1, m2)
		vr_state.meta.ipd = vr_state.meta.ipd + delta * get_fact(0.1, 10, 0.01, m1, m2);
		move3d_model(vr_state.l, vr_state.meta.ipd * 0.5, 0, 0);
		move3d_model(vr_state.r, -vr_state.meta.ipd * 0.5, 0, 0);
end},
	{"distort w",
function(WM, vr_state, delta, m1, m2)
	vr_state.meta.distortion[1] = vr_state.meta.distortion[1] + delta * get_fact(0.01, 10, 0.1, m1, m2);
end},
	{"distort x",
function(WM, vr_state, delta, m1, m2)
	vr_state.meta.distortion[2] = vr_state.meta.distortion[2] + delta * get_fact(0.01, 10, 0.1, m1, m2);
end},
	{"distort y",
function(WM, vr_state, delta, m1, m2)
	vr_state.meta.distortion[3] = vr_state.meta.distortion[3] + delta * get_fact(0.01, 10, 0.1, m1, m2);
end},
	{"distort z",
function(WM, vr_state, delta, m1, m2)
	vr_state.meta.distortion[4] = vr_state.meta.distortion[4] + delta * get_fact(0.01, 10, 0.1, m1, m2);
end},
	{"abberation r",
function(WM, vr_state, delta, m1, m2)
	vr_state.meta.distortion[4] = vr_state.meta.distortion[4] + delta * get_fact(0.001, 10, 0.1, m1, m2);
end
	},
	{"abberation g",
function(WM, vr_state, delta, m1, m2)
	vr_state.meta.distortion[4] = vr_state.meta.distortion[4] + delta * get_fact(0.001, 10, 0.1, m1, m2);
end},
	{"abberation b",
function(WM, vr_state, delta, m1, m2)
	vr_state.meta.distortion[4] = vr_state.meta.distortion[4] + delta * get_fact(0.001, 10, 0.1, m1, m2);
end},
};

local function step_ipd_distort(WM, iotbl)
	local vr_state = WM.vr_state;
	if not vr_state.ipd_target then
		vr_state.ipd_target = 0;
	end

	if (iotbl.digital) then
		return;
	end

	local step = iotbl.samples[iotbl.relative and 1 or 2];

-- just take one axis, both is a bit too noisy
	if (iotbl.subid == 0) then
		local ent = ipd_modes[vr_state.ipd_target + 1];
		if (ent) then
			ent[2](WM, vr_state, step, dispatch_meta());
			vr_state:set_distortion(vr_state.meta.distortion_model);
		end
	end
end

local function scale_selected(WM, iotbl)
	if (iotbl.digital or iotbl.subid ~= 0 or
		not WM.selected_layer or not WM.selected_layer.selected) then
		return;
	end

	local model = WM.selected_layer.selected;
	local tot = 0.01 * iotbl.samples[iotbl.relative and 1 or 2];
	model:set_scale_factor(tot, true);
	local as = WM.animation_speed;
	WM.animation_speed = 0.0;
	model.layer:relayout();
	WM.animation_speed = as;
end

local function rotate_selected(WM, iotbl)
	if (iotbl.digital or iotbl.subid ~= 0 or
		not WM.selected_layer or not WM.selected_layer.selected) then
		return;
	end

	local model = WM.selected_layer.selected;
	local tot = iotbl.samples[iotbl.relative and 1 or 2];
	local di = 2;
	if (iotbl.subid == 1) then
		di = 3;
	end

	model.rel_ang[di] = model.rel_ang[di] + tot;
	rotate3d_model(model.vid,
		model.rel_ang[1], model.rel_ang[2], model.rel_ang[3] + model.layer_ang);
end

return function(WM)
	table.insert(WM.menu,
{
	name = "mouse",
	kind = "value",
	description = "Change the mouse mapping behavior",
	label = "Mouse",
	set = {"Selected", "View", "Scale", "Rotate", "IPD"},
	handler = function(ctx, val)
		val = string.lower(val);
		if (val == "selected") then
			vr_system_message("selected window mouse mode");
			WM.mouse_handler = nil;
		elseif (val == "view") then
			vr_system_message("view mouse mode");
			WM.mouse_handler = rotate_camera;
		elseif (val == "scale") then
			vr_system_message("scale mouse mode");
			WM.mouse_handler = scale_selected;
		elseif (val == "rotate") then
			vr_system_message("routate mouse mode");
			WM.mouse_handler = rotate_selected;
		elseif (val == "ipd") then
			if (WM.mouse_handler == step_ipd_distort) then
				WM.vr_state.ipd_target = (WM.vr_state.ipd_target + 1) % (#ipd_modes);
			else
				WM.vr_state.ipd_target = 0;
				WM.mouse_handler = step_ipd_distort;
			end
			vr_system_message("mouse-mode: " .. ipd_modes[WM.vr_state.ipd_target+1][1]);
		end
	end
});

	table.insert(WM.menu,
	{
		name = "toggle_grab",
		label = "Toggle Grab",
		kind = "action",
		description = "Toggle device grab on/off",
		handler = function()
			toggle_mouse_grab();
		end
	}
	);

	table.insert(WM.menu,
{
	name = "shutdown",
	kind = "action",
	description = "Shutdown Safespaces (invoke twice in a row)",
	handler = function()
		return shutdown("", EXIT_SUCCESS);
	end
});
end
