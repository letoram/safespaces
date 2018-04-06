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
	set = {"Selected", "View", "Scale", "Rotate"},
	handler = function(ctx, val)
		if (val == "Selected") then
			WM.mouse_handler = nil;
		elseif (val == "View") then
			WM.mouse_handler = rotate_camera;
		elseif (val == "Scale") then
			WM.mouse_handler = scale_selected;
		elseif (val == "Rotate") then
			WM.mouse_handler = rotate_selected;
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
