local function add_model_menu(wnd, layer)

-- deal with the 180/360 transition shader-wise
	local lst = {
		pointcloud = "Point Cloud",
		sphere = "Sphere",
		hemisphere = "Hemisphere",
		rectangle = "Rectangle",
		cylinder = "Cylinder",
		halfcylinder = "Half-Cylinder",
		cube = "Cube",
	};

	local res = {};
	for k,v in pairs(lst) do
		table.insert(res,
		{
		label = v, name = k, kind = "value",
		validator = function(val)
			return val and string.len(val) > 0;
		end,
		handler = function(ctx, val)
			layer:add_model(k, val);
			layer:relayout();
		end,
		description = string.format("Add a %s to the layer", v)
		}
	);
	end
	return res;
end

-- global hook for hooking into notification or t2s
if (not vr_system_message) then
vr_system_message = function(str)
	print(str);
end
end

local function get_layer_settings(wnd, layer)
	return {
	{
		name = "depth",
		label = "Depth",
		description = "Set the default layer thickness",
		kind = "value",
		hint = "(0.001..99)",
		initial = tostring(layer.depth),
		validator = gen_valid_num(0.001, 99.0),
		handler = function(ctx, val)
			layer.depth = tonumber(val);
		end
	},
	{
		name = "radius",
		label = "Radius",
		description = "Set the layouting radius",
		kind = "value",
		hint = "(0.001..99)",
		initial = tostring(layer.radius),
		validator = gen_valid_num(0.001, 99.0),
		handler = function(ctx, val)
			layer.radius = tonumber(val);
			layer:relayout();
		end
	},
	{
		name = "spacing",
		label = "Spacing",
		initial = tostring(layer.spacing),
		kind = "value",
		hint = "(-10..10)",
		description = "Radius/Depth/Width dependent model spacing",
		validator = gen_valid_float(-10.0, 10.0),
		handler = function(ctx, val)
			layer.spacing = tonumber(val);
		end
	},
	{
		name = "vspacing",
		label = "Vertical Spacing",
		initial = tostring(layer.spacing),
		kind = "value",
		hint = "(-10..10)",
		description = "Laying spacing for vertical children",
		validator = gen_valid_float(-10.0, 10.0),
		handler = function(ctx, val)
			layer.vspacing = tonumber(val);
		end
	},
	{
		name = "active_scale",
		label = "Active Scale",
		description = "Default focus slot scale factor for new models",
		initial = tostring(layer.active_scale),
		kind = "value",
		validator = gen_valid_float(0.0, 100.0),
		handler = function(ctx, val)
			layer.active_scale = tonumber(val);
		end
	},
	{
		name = "inactive_scale",
		label = "Inactive Scale",
		description = "Default inactive slot scale factor for new models",
		initial = tostring(layer.inactive_scale),
		kind = "value",
		validator = gen_valid_float(0.0, 100.0),
		handler = function(ctx, val)
			layer.inactive_scale = tonumber(val);
		end
	},
	{
		name = "fixed",
		label = "Fixed",
		initial = layer.fixed and "true" or "false",
		set = {"true", "false"},
		kind = "value",
		description = "Lock the layer in place",
		handler = function(ctx, val)
			layer:set_fixed(val == "true");
		end
	},
	{
		name = "ignore",
		label = "Ignore",
		description = "This layer will not be considered for relative selection",
		set = {"true", "false"},
		kind = "value",
		handler = function(ctx, val)
			layer.ignore = val == "true";
		end
	},
	};
end

local function set_source_asynch(wnd, layer, model, subid, source, status)
	if (status.kind == "load_failed" or status.kind == "terminated") then
		blend_image(model.vid, model.opacity, model.ctx.animation_speed, model.ctx.animation_interp);
		delete_image(source);
		return;
	elseif (status.kind == "loaded") then
		blend_image(model.vid, model.opacity, model.ctx.animation_speed, model.ctx.animation_interp);
		if (subid) then
			set_image_as_frame(model.vid, source, subid);
		else
			image_sharestorage(source, model.vid);
		end
		image_texfilter(source, FILTER_BILINEAR);
		model.source = source;
	end
end

local function build_connpoint(wnd, layer, model)
	return {
		{
			name = "replace",
			label = "Replace",
			kind = "value",
			description = "Replace model source with contents provided by an external connection",
			validator = function(val) return val and string.len(val) > 0; end,
			hint = "(connpoint name)",
			handler = function(ctx, val)
				model:set_connpoint(val, "replace");
			end
		},
		{
			name = "temporary",
			label = "Temporary",
			kind = "value",
			hint = "(connpoint name)",
			description = "Swap out model source whenever there is a connection active",
			validator = function(val) return val and string.len(val) > 0; end,
			handler = function(ctx, val)
				model:set_connpoint(val, "temporary");
			end
		},
		{
			name = "reveal",
			label = "Reveal",
			kind = "value",
			hint = "(connpoint name)",
			description = "Model is only visible when there is a connection active",
			validator = function(val) return val and string.len(val) > 0; end,
			handler = function(ctx, val)
				model:set_connpoint(val, "reveal");
			end
		},
		{
			name = "reveal_focus",
			label = "Reveal-Focus",
			kind = "value",
			hint = "(connpoint name)",
			description = "Similar to reveal (show model on connect), but also set to focus slot",
			validator = function(val) return val and string.len(val) > 0; end,
			handler = function(ctx, val)
				model:set_connpoint(val, "reveal-focus");
			end
		}
	};
end

local function add_mapping_options(tbl, wnd, layer, model, subid)
	table.insert(tbl,
	{
		name = "connpoint",
		label = "Connection Point",
		description = "Allow external clients to connect and map to this model",
		submenu = true,
		kind = "action",
		handler = function()
			return build_connpoint(wnd, layer, model);
		end
	});
	local load_handler = function(ctx, res, flip)
		if (not resource(res)) then
			return;
		end
		if (flip) then
			switch_default_imageproc(IMAGEPROC_FLIPH);
		end
		local vid = load_image_asynch(res,
			function(...)
				set_source_asynch(wnd, layer, model, subid, ...);
			end
		);
		switch_default_imageproc(IMAGEPROC_NORMAL);

-- link so life cycle matches model
		if (valid_vid(vid)) then
			link_image(vid, model.vid);
		end
	end

	table.insert(tbl,
	{
		name = "source_inv",
		label = "Source-flip",
		kind = "value",
		description = "Specify the path to a resource that should be mapped to the model",
		validator =
		function(str)
			return str and string.len(str) > 0;
		end,
		handler = function(ctx, res)
			load_handler(ctx, res, false);
		end
	});
	table.insert(tbl,
	{
		name = "source",
		label = "Source",
		kind = "value",
		description = "Specify the path to a resource that should be mapped to the model",
		validator =
		function(str)
			return str and string.len(str) > 0;
		end,
		handler = function(ctx, res)
			load_handler(ctx, res, true);
		end
	});
	table.insert(tbl,
	{
		name = "source_right",
		label = "Source(Right)",
		kind = "value",
		description = "Sepcify the path to a resource that should be mapped to the right-eye view of the model",
		validator =
			function(str)
				return str and #str > 0;
			end,
		handler = function(ctx, res)
			load_handler(ctx, res, true);
		end
	});
	table.insert(tbl,
	{
		name = "map",
		label = "Map",
		description = "Map the contents of another window to the model",
		kind = "value",
		set = function()
			local lst = {};
			for wnd in all_windows(nil, true) do
				table.insert(lst, wnd:identstr());
			end
			return lst;
		end,
		eval = function()
			if (type(durden) ~= "function" or subid ~= nil) then
				return false;
			end
			for wnd in all_windows(nil, true) do
				return true;
			end
		end,
		handler = function(ctx, val)
			for wnd in all_windows(nil, true) do
				if wnd:identstr() == val then
					model.external = wnd.external;
					image_sharestorage(wnd.canvas, model.vid);
					model:show();
					return;
				end
			end
		end
	});
	table.insert(tbl,
	{
		name = "browse",
		label = "Browse",
		description = "Browse for a source image or video to map to the model",
		kind = "action",

-- eval so that we can present it in WMs that have it
		eval = function() return type(browse_file) == "function"; end,
		handler = function()
			local loadfn = function(res)
				local vid = load_image_asynch(res,
					function(...)
						set_source_asynch(wnd, layer, model, nil, ...);
					end
				);
				if (valid_vid(vid)) then
					link_image(vid, model.vid);
				end
			end
			browse_file({},
				{png = loadfn, jpg = loadfn, bmp = loadfn}, SHARED_RESOURCE, nil);
		end
	});
end

local function gen_face_menu(wnd, layer, model)
	local res = {};
	for i=1, model.n_sides do
		table.insert(res, {
			name = tostring(i),
			label = tostring(i),
			kind = "action",
			submenu = true,
			handler = function()
				local res = {};
				add_mapping_options(res, wnd, layer, model, i-1);
				return res;
			end
		});
	end
	return res;
end

local function gen_event_menu(wnd, layer, model)
	return {
		{
			name = "destroy",
			label = "Destroy",
			kind = "value",
			hint = "action/path/to/bind",
			description = "Trigger this path on model destruction",
			handler = function(ctx, val)
				print("on destroy set to ", val)
				table.insert(model.on_destroy, val);
			end
		}
	};
end

local stereo_tbl = {
	none = {0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0},
	sbs = {0.0, 0.0, 0.5, 1.0, 0.5, 0.0, 0.5, 1.0},
	["sbs-rl"] = {0.5, 0.0, 0.5, 1.0, 0.0, 0.0, 0.5, 1.0},
	["oau-rl"] = {0.0, 0.5, 1.0, 0.5, 0.0, 0.0, 1.0, 0.5},
	oau = {0.0, 0.0, 1.0, 0.5, 0.0, 0.5, 1.0, 0.5}
};
local function model_stereo(model, val)
	if (stereo_tbl[val]) then
		model:set_stereo(stereo_tbl[val]);
	else
		console_log("missing stereoscopic mode: " .. val);
	end
end

local function model_settings_menu(wnd, layer, model)
	local res = {
	{
		name = "child_swap",
		label = "Child Swap",
		kind = "value",
		hint = "(<0 -y, >0 +y)",
		description = "Switch parent slot with a relative child",
		handler = function(ctx, val)
			model:vswap(tonumber(val));
		end
	},
	{
		name = "destroy",
		label = "Destroy",
		kind = "action",
		description = "Delete the model and all associated/mapped resources",
		handler = function(ctx, res)
			model:destroy();
		end
	},
	{
		name = "rotate",
		label = "Rotate",
		description = "Set the current model-layer relative rotation",
		kind = "value",
		validator = suppl_valid_typestr("fff", -359, 359, 0),
		handler = function(ctx, val)
			local res = suppl_unpack_typestr("fff", val, -359, 359);
			model.rel_ang[1] = res[1];
			model.rel_ang[2] = res[2];
			model.rel_ang[3] = res[3];
			rotate3d_model(model.vid, model.rel_ang[1], model.rel_ang[2], model.rel_ang[3]);
		end,
	},
	{
		name = "flip",
		label = "Flip",
		description = "Force- override t-coordinate space (vertical flip)",
		kind = "value",
		set = {"true", "false"},
		handler = function(ctx, val)
			if (val == "true") then
				model.force_flip = true;
			else
				model.force_flip = false;
			end
			image_shader(model.vid,
				model.force_flip and model.shader.flip or model.shader.normal);
		end
	},
	{
		name = "spin",
		label = "Spin",
		description = "Increment or decrement the current model-layer relative rotation",
		kind = "value",
		validator = suppl_valid_typestr("fff", -359, 359, 0),
		handler = function(ctx, val)
			local res = suppl_unpack_typestr("fff", val, -359, 359);
			if (res) then
				model.rel_ang[1] = math.fmod(model.rel_ang[1] + res[1], 360);
				model.rel_ang[2] = math.fmod(model.rel_ang[2] + res[2], 360);
				model.rel_ang[3] = math.fmod(model.rel_ang[3] + res[3], 360);
				rotate3d_model(model.vid, model.rel_ang[1], model.rel_ang[2], model.rel_ang[3]);
			end
		end,
	},
	{
		name = "scale",
		label = "Scale Factor",
		description = "Set model-focus (center slot) scale factor",
		kind = "value",
		validator = gen_valid_num(0.1, 100.0),
		handler = function(ctx, val)
			model:set_scale_factor(tonumber(val));
			model.layer:relayout();
		end
	},
	{
		name = "opacity",
		label = "Opacity",
		description = "Set model opacity",
		kind = "value",
		hint = "(0: hidden .. 1: opaque)",
		initial = tostring(model.opacity),
		handler = function(ctx, val)
			model.opacity = suppl_apply_num(val, model.opacity);
			blend_image(model.vid, model.opacity);
		end
	},
	{
		name = "merge_collapse",
		label = "Merge/Collapse",
		description = "Toggle between Merged(stacked) and Collapsed child layouting",
		kind = "action",
		handler = function(ctx)
			model.merged = not model.merged;
			model.layer:relayout();
		end
	},
	{
		name = "curvature",
		label = "Curvature",
		kind = "value",
		description = "Set the model curvature z- distortion",
		handler = function(ctx, val)
			model:set_curvature(tonumber(val));
		end,
		validator = gen_valid_num(-0.5, 0.5),
	},
	{
		name = "events",
		label = "Events",
		kind = "action",
		submenu = true,
		description = "Bind event triggers",
		handler = function()
			return gen_event_menu(wnd, layer, model);
		end
	},
	{
		name = "nudge",
		label = "Nudge",
		kind = "value",
		validator = suppl_valid_typestr("fff", -10, 10, 0),
		description = "Move Relative (x y z)",
		handler = function(ctx, val)
			local res = suppl_unpack_typestr("fff", val, -10, 10);
			if (res) then
				model:nudge(res[1], res[2], res[3]);
			end
		end
	},
	{
		name = "move",
		label = "Move",
		kind = "value",
		validator = suppl_valid_typestr("fff", -10000, 10000, 0),
		description = "Set layer anchor-relative position",
		handler = function(ctx, val)
			local res = suppl_unpack_typestr("fff", val, -10, 10);
			if (res) then
				model:move(res[1], res[2], res[3]);
			end
		end
	},
	{
		name = "layout_block",
		label = "Layout Block",
		kind = "value",
		initial = function()
			return model.layout_block and "yes" or "no"
		end,
		set = {"true", "false"},
		handler = function(ctx, val)
			model.layout_block = val == "true"
		end
	},
	{
		name = "stereoscopic",
		label = "Stereoscopic Model",
		description = "Mark the contents as stereoscopic and apply a view dependent mapping",
		kind = "value",
		set = {"none", "sbs", "sbs-rl", "oau", "oau-rl"},

		handler = function(ctx, val)
			model_stereo(model, val);
		end
	},
	{
		name = "cycle_stereo",
		label = "Cycle Stereo",
		kind = "action",
		description = "Cycle between the different stereo-scopic modes",
		handler = function(ctx)
			if not model.last_stereo then
				model.last_stereo = "none";
			end
			local set = {"none", "sbs", "sbs-rl", "oau", "oau-rl"};
			local ind = table.find_i(set, model.last_stereo);
			ind = ind + 1;
			if (ind > #set) then
				ind = 1;
			end
			model.last_stereo = set[ind];
			model_stereo(model, set[ind]);
		end
	},
	{
		name = "mesh_type",
		label = "Mesh Type",
		kind = "value",
		description = "Set a specific mesh type, will reset scale and some other parameters",
		set = {"cylinder", "halfcylinder", "sphere", "hemisphere", "cube", "rectangle"},
		eval = function()
			return model.mesh_kind ~= "custom";
		end,
		handler = function(ctx, val)
			model:switch_mesh(val);
		end
	},
	{
		name = "cycle_mesh",
		label = "Cycle Mesh",
		kind = "action",
		description = "Switch between the different mesh types",
		eval = function()
			return model.mesh_kind ~= "custom";
		end,
		handler = function(ctx)
			local set = {"cylinder", "halfcylinder", "sphere", "hemisphere", "cube", "rectangle"};
			local i = table.find_i(set, model.mesh_kind);
			i = i + 1 <= #set and i + 1 or 1;
			local props = image_surface_properties(model.vid);

			model:switch_mesh(set[i]);

			console_log("model", "mesh type set to " .. set[i]);
			blend_image(model.vid, props.opacity);
			move3d_model(model.vid, props.x, props.y, props.z);
			scale3d_model(model.vid, props.scale.x, props.scale.y, props.scale.z);
		end
	}
	};

-- if the source is in cubemap state, we need to work differently
	add_mapping_options(res, wnd, layer, model, nil);
	if (model.n_sides and model.n_sides > 1) then
		table.insert(res, {
			name = "faces",
			label = "Faces",
			kind = "action",
			submenu = true,
			description = "Map data sources to individual model faces",
			handler = function() return gen_face_menu(wnd, layer, model); end
		});
	end

	return res;
end

local function change_model_menu(wnd, layer)
	local res = {
	{
		name = "selected",
		kind = "action",
		submenu = true,
		label = "Selected",
		handler = function()
			return model_settings_menu(wnd, layer, layer.selected);
		end,
		eval = function()
			return layer.selected ~= nil;
		end
	}
	};

	for i,v in ipairs(layer.models) do
		table.insert(res,
		{
			name = v.name,
			kind = "action",
			submenu = true,
			label = v.name,
			handler = function()
				return model_settings_menu(wnd, layer, v);
			end,
		});
	end

	return res;
end

local term_counter = 0;
local function get_layer_menu(wnd, layer)
	return {
		{
			name = "add_model",
			label = "Add Model",
			description = "Add a new mappable model to the layer",
			submenu = true,
			kind = "action",
			handler = function() return add_model_menu(wnd, layer); end,
		},
		{
			label = "Open Terminal",
			description = "Add a terminal premapped model to the layer",
			kind = "value",
			name = "terminal",
			handler = function(ctx, val)
				layer:add_terminal(val);
			end
		},
		{
			name = "models",
			label = "Models",
			description = "Manipulate individual models",
			submenu = true,
			kind = "action",
			handler = function()
				return change_model_menu(wnd, layer);
			end,
			eval = function() return #layer.models > 0; end,
		},
		{
			name = "swap",
			label = "Swap",
			eval = function()
				return layer:count_root() > 1;
			end,
			kind = "value",
			validator = function(val) --not exact
				local cnt = layer:count_root();
				return (gen_valid_num(-cnt,cnt))(val);
			end,
			hint = "(< 0: left, >0: right)",
			description = "Switch center/focus window with one to the left or right",
			handler = function(ctx, val)
				val = tonumber(val);
				if (val < 0) then
					layer:swap(true, -1*val);
				elseif (val > 0) then
					layer:swap(false, val);
				end
			end
		},
		{
			name = "cycle",
			label = "Cycle",
			eval = function()
				return #layer.models > 1;
			end,
			kind = "value",
			validator = function(val)
				return (
					gen_valid_num(-1*(#layer.models),1*(#layer.models))
				)(val);
			end,
			hint = "(< 0: left, >0: right)",
			description = "Cycle windows on left or right side",
			handler = function(ctx, val)
				val = tonumber(val);
				if (val < 0) then
					layer:cycle(true, -1*val);
				else
					layer:cycle(false, val);
				end
			end
		},
		{
			name = "destroy",
			label = "Destroy",
			description = "Destroy the layer and all associated models and connections",
			kind = "value",
			set = {"true", "false"},
			handler = function(ctx, val)
				if (val == "true") then
					layer:destroy();
				end
			end
		},
		{
			name = "switch",
			label = "Switch",
			description = "Switch layer position with another layer",
			kind = "value",
			set = function()
				local lst = {};
				local i;
				for j, v in ipairs(wnd.layers) do
					if (v.name ~= layer.name) then
						table.insert(lst, v.name);
					end
				end
				return lst;
			end,
			eval = function() return #wnd.layers > 1; end,
			handler = function(ctx, val)
				local me;
				for me, v in ipairs(wnd.layers) do
					if (v == layer.name) then
						break;
					end
				end

				local src;
				for src, v in ipairs(wnd.layers) do
					if (v.name == val) then
						break;
					end
				end

				wnd.layers[me] = wnd.layers[src];
				wnd.layers[src] = layer;
				wnd:reindex_layers();
			end,
		},
		{
			name = "opacity",
			label = "Opacity",
			kind = "value",
			description = "Set the layer opacity",
			validator = gen_valid_num(0.0, 1.0),
			handler = function(ctx, val)
				blend_image(layer.anchor, tonumber(val), wnd.animation_speed, wnd.animation_interp);
			end
		},
		{
			name = "focus",
			label = "Focus",
			description = "Set this layer as the active focus layer",
			kind = "action",
			eval = function()
				return #wnd.layers > 1 and wnd.selected_layer ~= layer;
			end,
			handler = function()
				wnd.selected_layer = layer;
			end,
		},
		{
			name = "nudge",
			label = "Nudge",
			description = "Move the layer anchor relative to its current position",
			hint = "(x y z dt)",
			kind = "value",
			eval = function(ctx, val)
				return not layer.fixed;
			end,
			validator = suppl_valid_typestr("ffff", 0.0, 359.0, 0.0),
			handler = function(ctx, val)
				local res = suppl_unpack_typestr("ffff", val, -10, 10);
				instant_image_transform(layer.anchor);
				layer.dx = layer.dx + res[1];
				layer.dy = layer.dy + res[2];
				layer.dz = layer.dz + res[3];
				move3d_model(layer.anchor, layer.dx, layer.dy, layer:zpos(), res[4]);
			end,
		},
		{
			name = "settings",
			label = "Settings",
			description = "Layer specific controls for layouting and window management";
			kind = "action",
			submenu = true,
			handler = function()
				return get_layer_settings(wnd, layer);
			end
		},
	};
end


local function layer_menu(wnd)
	local res = {
	};

	if (wnd.selected_layer) then
		table.insert(res, {
			name = "current",
			submenu = true,
			kind = "action",
			description = "Currently focused layer",
			eval = function() return wnd.selected_layer ~= nil; end,
			label = "Current",
			handler = function() return get_layer_menu(wnd, wnd.selected_layer); end
		});

		table.insert(res, {
			name = "grow_shrink",
			label = "Grow/Shrink",
			description = "Increment (>0) or decrement (<0) the layout radius of all layers",
			kind = "value",
			validator = gen_valid_float(-10, 10),
			handler = function(ctx, val)
				local step = tonumber(val);
				for i,v in ipairs(wnd.layers) do
					instant_image_transform(v.anchor);
					v.radius = v.radius + step;
					v:relayout();
				end
			end
		});
		table.insert(res, {
			name = "push_pull",
			label = "Push/Pull",
			description = "Move all layers relatively closer (>0) or farther away (<0)",
			kind = "value",
			validator = gen_valid_float(-10, 10),
			handler = function(ctx, val)
				local step = tonumber(val);
				for i,v in ipairs(wnd.layers) do
					instant_image_transform(v.anchor);
					v.dz = v.dz + step;
					move3d_model(v.anchor, v.dx, v.dy, v:zpos(), wnd.animation_speed, wnd.animation_interp);
				end
			end
		});
	end

	table.insert(res, {
	label = "Add",
	description = "Add a new model layer";
	kind = "value",
	name = "add",
	hint = "(tag name)",
-- require layer to be unique
	validator = function(str)
		if (str and string.len(str) > 0) then
			for _,v in ipairs(wnd.layers) do
				if (v.tag == str) then
					return false;
				end
			end
			return true;
		end
		return false;
	end,
	handler = function(ctx, val)
		wnd:add_layer(val);
	end
	});

	for k,v in ipairs(wnd.layers) do
		table.insert(res, {
			name = "layer_" .. v.name,
			submenu = true,
			kind = "action",
			label = v.name,
			handler = function() return get_layer_menu(wnd, v); end
		});
	end

	table.insert(res, {
		name = "dump",
		kind = "action",
		label = "Dump",
		description = "Dump all layer configuration to stdout",
		handler = function()
			wnd:dump(print);
		end
	});

	return res;
end


local function load_space(wnd, prefix, path)
	local lst = system_load(prefix .. "spaces/" .. path, false);
	if (not lst) then
		warning("vr-load space (" .. path .. ") couldn't load/parse script");
		return;
	end
	local cmds = lst();
	if (not type(cmds) == "table") then
		warning("vr-load space (" .. path .. ") script did not return a table");
	end

-- defer layouter until all has been loaded
	local dispatch = wnd.default_layouter;
	wnd.default_layouter = function() end;
	for i,v in ipairs(cmds) do
		dispatch_symbol(v);
	end

	wnd.default_layouter = dispatch;
	for _,v in ipairs(wnd.layers) do
		v:relayout();
	end
end

local function hmd_config(wnd, opts)
	return {
	{
	name = "reset",
	label = "Reset Orientation",
	description = "Set the current orientation as the new base reference",
	kind = "action",
	handler = function()
		reset_target(wnd.vr_state.vid);
	end
	},
	{
	name = "ipd",
	label = "IPD",
	description = "Override the 'interpupilary distance'",
	kind = "value",
	validator = gen_valid_num(0.0, 1.0),
	handler = function(ctx, val)
		local num = tonumber(val);
		wnd.vr_state.meta.ipd = num;
		move3d_model(wnd.vr_state.l, -wnd.vr_state.meta.ipd * 0.5, 0, 0);
		move3d_model(wnd.vr_state.r, wnd.vr_state.meta.ipd * 0.5, 0, 0);
		warning(string.format("change ipd: %f", wnd.vr_state.meta.ipd));
	end
	},
	{
		name = "step_ipd",
		label = "Step IPD",
		kind = "value",
		description = "relatively nudge the 'interpupilary distance'",
		validator = gen_valid_num(-1.0, 1.0),
		handler = function(ctx, val)
			local num = tonumber(val);
			wnd.vr_state.meta.ipd = wnd.vr_state.meta.ipd + num;
			move3d_model(wnd.vr_state.l, -wnd.vr_state.meta.ipd * 0.5, 0, 0);
			move3d_model(wnd.vr_state.r, wnd.vr_state.meta.ipd * 0.5, 0, 0);
			warning(string.format("change ipd: %f", wnd.vr_state.meta.ipd));
		end
	},
	{
	name = "distortion",
	label = "Distortion",
	description = "Override the distortion model used",
	kind = "value",
	set = {"none", "basic"},
	handler = function(ctx, val)
		wnd.vr_state:set_distortion(val);
	end
	}
};
end


local function global_settings(wnd, opts)
	return {
	{
		name = "vr_settings",
		kind = "value",
		label = "VR Bridge Config",
		description = "Set the arguments that will be passed to the VR device",
		handler = function(ctx, val)
			wnd.hmd_arg = val;
		end
	}
	};
end

return
function(wnd, opts)
	opts = opts and opts or {};
	if (not opts.prefix) then
		opts.prefix = "";
	end

	system_load(opts.prefix .. "vrsetup.lua")(ctx, opts);

local res = {{
	name = "close_vr",
	description = "Terminate the current VR session and release the display",
	kind = "action",
	label = "Close VR",
	eval = function()
		return wnd.in_vr ~= nil and type(durden) == "function";
	end,
	handler = function()
		wnd:drop_vr();
	end
},
{
	name = "settings",
	submenu = true,
	kind = "action",
	description = "Layer/device configuration",
	label = "Config",
	eval = function() return type(durden) == "function"; end,
	handler = function(ctx)
		return global_settings(wnd, opts);
	end
},
{
	name = "layers",
	kind = "action",
	submenu = true,
	label = "Layers",
	description = "Model layers for controlling models and data sources",
	handler = function()
		return layer_menu(wnd, opts);
	end
},
{
	name = "space",
	label = "Space",
	kind = "value",
	set =
	function()
		local set = glob_resource(opts.prefix .. "spaces/*.lua", APPL_RESOURCE);
		return set;
	end,
	eval = function()
		local set = glob_resource(opts.prefix .. "spaces/*.lua", APPL_RESOURCE);
		return set and #set > 0;
	end,
	handler = function(ctx, val)
		load_space(wnd, opts.prefix, val);
	end,
},
{
	name = "hmd",
	label = "HMD Configuration",
	kind = "action",
	submenu = true,
	eval = function()
		return wnd.vr_state ~= nil;
	end,
	handler = function() return hmd_config(wnd, opts); end
},
{
	name = "setup_vr",
	label = "Setup VR",
	kind = "value",
	set = function()
		local res = {};
		display_bytag("VR", function(disp) table.insert(res, disp.name); end);
		return res;
	end,
	eval = function()
		local res;
		display_bytag("VR", function(disp) res = true; end);
		return res and type(durden) == "function";
	end,
	handler = function(ctx, val)
		wnd:setup_vr(wnd, val);
	end
}};
	return res;
end
