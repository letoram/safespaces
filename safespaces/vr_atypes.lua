--
-- This contains the behavior profiles for the different permitted
-- segment types and their respective subsegments.
--

local client_log = suppl_add_logfn("client");

local clut = {
};

-- in any of the external event handlers, we do this on terminated
-- to make sure that the object gets reactivated properly
local function apply_connrole(layer, model, source)
	local rv = false;

	if (model.ext_name) then
		delete_image(source);
		model:set_connpoint(model.ext_name, model.ext_kind);
		rv = true;
	end

	if (model.ext_kind) then
		if (model.ext_kind == "reveal" or model.ext_kind == "reveal-focus") then
			model.active = false;
			blend_image(model.vid, 0, model.ctx.animation_speed);
			model.layer:relayout();
			rv = true;

		elseif (model.ext_kind == "temporary" and valid_vid(model.source)) then
			model:set_display_source(model.source);
			rv = true;
		end
	end

	return rv;
end

local function model_eventhandler(ctx, model, source, status)
	client_log("kind=event:type=" .. status.kind);

	if (status.kind == "terminated") then
-- need to check if the model is set to reset to last set /
-- open connpoint or to die on termination
		if (not apply_connrole(model.layer, model, source)) then
			model:destroy(EXIT_FAILURE, status.last_words);
		end

	elseif (status.kind == "segment_request") then
		local kind = clut[status.segkind];

		if (not kind) then
			return;
		end

		local new_model =
			model.layer:add_model("rectangle",
				string.format("%s_ext_%s_%s",
				model.name, tostring(model.extctr), status.segkind)
			);

		if (not new_model) then
			return;
		end

		local vid = accept_target(
		function(source, status)
			return kind(model.layer.ctx, new_model, source, status);
		end);

		model.extctr = model.extctr + 1;
		new_model:set_external(vid);
		new_model.parent = model.parent and model.parent or model;

	elseif (status.kind == "registered") then
		model:set_external(source);

	elseif (status.kind == "resized") then
		image_texfilter(source, FILTER_BILINEAR);
		model:set_external(source, status.origo_ll);
		if (status.width > status.height) then
			model:scale(1, status.height / status.width, 1);
		else
			model:scale(status.width / status.height, 1, 1);
		end
		model:show();
	end
end

clut["multimedia"] = model_eventhandler;
clut["game"] = model_eventhandler;

clut["hmd-l"] = function(ctx, model, source, status)
	if (status.kind == "segment_request") then
		if (status.segkind == "hmd-r") then
-- don't do anything here, let the primary segment determine behavior,
-- just want the separation and control
			local props = image_storage_properties(source);
			local vid = accept_target(props.width, props.height, function(...) end)
			if (not valid_vid(vid)) then
				return;
			end

--			image_framesetsize(source, 2, FRAMESET_MULTITEXTURE);
--			set_image_as_frame(source, vid, 1);
		end
	end

	return model_eventhandler(ctx, model, source, status);
end

-- terminal eventhandler behaves similarly to the default, but also send fonts
clut.terminal =
function(ctx, model, source, status)
	if (status.kind == "preroll") then
		target_fonthint(source, ctx.terminal_font, ctx.terminal_font_sz * FONT_PT_SZ, 2);
		target_graphmode(source, 1, ctx.terminal_opacity);
	else
		return model_eventhandler(ctx, model, source, status);
	end
end
clut.tui = clut.terminal;

-- This is for the bridge connection that probes basic display properties
-- subsegment requests here map to actual wayland surfaces.
local wlut = {};
local function default_alloc_handler(ctx, model, source, status)
	local width, height = model:get_displayhint_size();
	target_displayhint(source, width, height,
		TD_HINT_MAXIMIZED, {ppcm = ctx.display_density});

	local new_model = model.layer:add_model("rectangle",
		string.format("%s_ext_wl_%s",
		model.name, tostring(model.extctr))
	);

	new_model:set_display_source(source);
	link_image(source, new_model.vid);
	new_model.external = source;
	new_model.parent = model.parent and model.parent or model;
	new_model:swap_parent();
	new_model:show();
end

wlut["application"] =
function(ctx, model, source, status)
	if status.kind == "allocated" then
		default_alloc_handler(ctx, model, source, status);
	elseif status.kind == "message" then

	end
-- this corresponds to a 'toplevel', there can be multiple of these, and it is
-- the 'set_toplevel that is the most recent which should be active on the model
end

wlut["multimedia"] =
function(ctx, model, source, status)
-- subsurface on the existing application, a fucking pain, we need to switch to
-- composited mode and the display-hint sizes etc. account for it all
end

wlut["bridge-x11"] =
function(ctx, model, source, status)
-- xwayland surface, so this has its own set of messages
	if status.kind == "allocated" then
		default_alloc_handler(ctx, model, source, status);
	end
end

wlut["cursor"] =
function(ctx, model, source, status)
-- mouse cursor, if visible we need to compose or de-curvature and position, and
-- on the composition we might want to alpha- out possible "space"
end

wlut["popup"] =
function(ctx, model, source, status)
-- popup, if visible we need to compose or de-curvature and position
end

wlut["clipboard"] =
function(ctx, model, source, status)
-- clipboard, nothing for the time being
end

clut["bridge-wayland"] =
function(ctx, model, source, status)
	client_log("kind=wayland:type=wayland-bridge:event=" .. status.kind);

-- our model display corresponds to a wayland 'output'
	if (status.kind == "preroll") then
		local width, height = model:get_displayhint_size();
		target_displayhint(source, width, height, 0, {ppcm = ctx.display_density});
		target_flags(source, TARGET_ALLOWGPU);

	elseif (status.kind == "segment_request") then

-- use our default "size" and forward to the handler with a new event type
		if wlut[status.segkind] then
			client_log(string.format(
				"kind=status:source=%d:model=%s:segment_request=%s",
				source, model.name, status.segkind)
			);

			local vid = accept_target(source,
			function(source, inner_status)
				return wlut[status.segkind](ctx, model, source, inner_status);
			end);
			if valid_vid(vid) then
				target_flags(source, TARGET_ALLOWGPU);
				wlut[status.segkind](ctx, model, vid, {kind = "allocated"});
			end
		else
			client_log(string.format(
				"kind=error:source=%d:model=%s:message=no handler for %s",
				source, model.name, status.segkind)
			);
		end

	elseif (status.kind == "terminated") then
		delete_image(source);
	end
end

-- can be multiple bridges so track them separately
local wayland_bridges = {};
local function add_wayland_bridge(ctx, model, source, status)
	table.insert(wayland_bridges, source);
	target_updatehandler(source,
	function(source, inner_status)
		return clut["bridge-wayland"](ctx, model, source, inner_status);
	end);
end

clut.default =
function(ctx, model, source, status)
	local layer = model.layer;

	if (status.kind == "registered") then
-- based on segment type, install a new event-handler and tie to a new model
		local dstfun = clut[status.segkind];
		if (dstfun == nil) then
			client_log(string.format(
				"kind=segment_request:name=%s:source=%d:status=rejected:type=%s",
				model.name, source, status.segkind));

			delete_image(source);
			return;

-- there is an external connection handler that takes over whatever this model was doing
		elseif (model.ext_kind ~= "child") then
			target_updatehandler(source, function(source, status)
				return dstfun(ctx, model, source, status);
			end);
			model.external_old = model.external;
			model.external = source;

-- or it should be bound to a new model that is a child of the current one
		else

-- but special handling for the allocation bridge
			if status.segkind == "bridge-wayland" then
				add_wayland_bridge(ctx, model, source, status);
				return;
			end

--action if a child has been spawned, other is to 'swap in' and swallow as a proxy
			local new_model =
				layer:add_model("rectangle", model.name .. "_ext_" .. tostring(model.extctr));

			model.extctr = model.extctr + 1;
			target_updatehandler(source, function(source, status)
				return dstfun(ctx, new_model, source, status);
			end);

			local parent = model.parent and model.parent or model;
			new_model.parent = parent;

--trigger when the client actually is ready
			local fun;
			fun = function()
				table.remove_match(new_model.on_show, fun);
				if new_model.swap_parent then
					new_model:swap_parent();
				end
			end
			table.insert(new_model.on_show, fun);

			dstfun(ctx, new_model, source, status);
		end

-- local visibility, anchor / space can still be hidden
	elseif (status.kind == "resized") then
		model:show();

	elseif (status.kind == "terminated") then
-- connection point died, should we bother allocating a new one?
		delete_image(source);
		if not (apply_connrole(model.layer, model, source)) then
			model:destroy(EXIT_FAILURE, status.last_words);
		end
	end
end

-- primary-segment to handler mapping
return function(model, source, kind)
	client_log(string.format(
		"kind=get_handler:type=%s:model=%s:source=%d", kind, model.name, source));

	if clut[kind] then
		client_log(string.format("kind=get_handler:" ..
			"type=%s:handler=custom:model=%s:source=%d", kind, model.name, source));

		return function(source, status)
			clut[kind](model.layer.ctx, model, source, status)
		end
	else
		client_log(string.format("kind=get_handler:" ..
			"type=%s:handler=default:model=%s:source=%d", kind, model.name, source));

		return function(source, status)
			clut.default(model.layer.ctx, model, source, status)
		end
	end
end
