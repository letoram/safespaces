-- placeholder, may be set if we need to wait for a specific display
local display_action = function() end
WM = {};
local debugf = print;
local debug_verbose = DEBUGLEVEL > 0;
local SYMTABLE;
local wait_for_display;

function safespaces(args)
	system_load("suppl.lua")();
	local vrsetup = system_load("vrsetup.lua")();

-- map config to keybindings, and load keymap (if specified)
	local config = system_load("config.lua")();
	SYMTABLE = system_load("symtable.lua")();
	SYMTABLE.bindings = config.bindings;
	SYMTABLE.meta_1 = config.meta_1 and config.meta_1 or "COMPOSE";
	SYMTABLE.meta_2 = config.meta_2 and config.meta_2 or "RSHIFT";
	SYMTABLE.mstate = {false, false};

-- just map the args into a table and look for
	local argtbl = {};
	for k,v in ipairs(args) do
		local a = string.split(v, "=");
		if (a and a[1] and a[2]) then
			argtbl[a[1]] = a[2];
		end
	end

-- pick device profile from args or config
	local device = argtbl.device and argtbl.device or config.device;
	if (not device) then
		return shutdown(
			"No device specified (in config.lua or device=... arg)", EXIT_FAILURE);
	end
	warning("using device profile: " .. device);
	local dev = system_load("devices/" .. device .. ".lua")();
	if (not dev) then
		return shutdown(
			"Device map (" .. device .. ") didn't load", EXIT_FAILURE);
	end

-- project device specific bindings, warn on conflict
	if (dev.bindings) then
		for k,v in pairs(dev.bindings) do
			if (SYMTABLE.bindings[k]) then
				warning("igoring conflicting device binding (" .. k .. ")");
			else
				SYMTABLE.bindings[k] = v;
			end
		end
	end

-- just need a container pipeline, resize this if monoscopic 'normal 3D' output
-- is needed, otherwise the setup_vr callback will provide a combiner rendertarget
-- to map to displays, or the individual left/right eye paths.
	local preview;
	if (dev.disable_vrbridge) then
		preview = alloc_surface(VRESW, VRESH);
		show_image(preview);
	else
		preview = alloc_surface(32, 32);
	end

-- reuild the WM context to add the basic VR setup / management functions
	vrsetup(WM, preview, config);

-- append the menu tree for accessing / manipulating the VR setup
	WM.menu = (system_load("vrmenus.lua")())(WM, prefix);
	WM.mouse_mode = "direct";
	(system_load("ssmenus.lua")())(WM);

-- function call hidden inside vrmenus, needed for sharing codebase with durden
	dispatch_symbol = function(sym)
		sym = string.sub(sym, 2);
		suppl_run_menu(WM.menu, sym, debugf, debug_verbose)
	end

-- load the default space or whatever was provided as the argument
	local space = argtbl.space and argtbl.space or "default.lua";
	suppl_run_menu(WM.menu, "space=" .. space, debugf, debug_verbose);

-- wait for device display to become available, in that case we want a combiner
-- stage, otherwise we might be running in windowed mode and want to compose on
-- the window we already have
	if (dev.display) then

-- Nolock option spawns the vr_bridge first, THEN waits for the display to
-- appear. This is needed for devices where the display requires some kind
-- of activation command that is driver dependent.
		if (not dev.prelaunch) then
			wait_for_display(dev);
		else
			WM:setup_vr(
			function(device, comb, l, r)
				warning("VR device activated");
				wait_for_display(dev, comb);
			end, dev);
		end

	elseif (not dev.disable_vrbridge) then
		WM:setup_vr(
		function(dev, comb, l, r)
-- things are set up as is, just a good spot for adding more processing
		end, dev);
	end

-- just hook for custom things
	if (resource("autorun.lua", APPL_RESOURCE)) then
		system_load("autorun.lua")();
	end

	WM.dev = dev;
end

wait_for_display = function(dev, dstid)
	warning("waiting for display: " .. dev.display);
	local old_tick = safespaces_clock_pulse;
	local refresh_timer = 200;

-- not all platforms have automatic hotplug, periodically scan
	safespaces_clock_pulse = function()
		refresh_timer = refresh_timer - 1;
		if (refresh_timer == 0) then
			video_displaymodes();
			refresh_timer = 200;
		end
	end

-- when a display arrives that match the known/desired display,
-- map the VR combiner stage to it
	display_action = function(name, id)
		warning(string.format("display(%s): detected", name));
		if (string.match(name, dev.display)) then
			safespaces_clock_pulse = old_tick;
			if (dstid) then
				map_video_display(dstid, id);
			else
				WM:setup_vr(
				function(ctx, vid, a, b)
					if (not ctx) then
						return shutdown("VR bridge setup failed, missing / incorrect arcan_vr?", EXIT_FAILURE);
					end
					map_video_display(vid, id);
				end, dev);
			end
		end
	end
end

function safespaces_input(iotbl)
-- don't care about plug/unplug
	if (iotbl.kind == "status") then
		return;
	end

-- find our destination
	local model = (WM.selected_layer and WM.selected_layer.selected);
	local target = model and model.external;

	if (iotbl.mouse) then
		if (WM.mouse_handler) then
			WM:mouse_handler(iotbl);
			return;
		end

-- apply keymap, check binding state
	elseif (iotbl.translated) then
		local sym, lutsym = SYMTABLE:patch(iotbl);
		if (sym == SYMTABLE.meta_1) then
			SYMTABLE.mstate[1] = iotbl.active;
		elseif (sym == SYMTABLE.meta_2) then
			SYMTABLE.mstate[2] = iotbl.active;
		else
			sym = (iotbl.active and "" or "r") .. sym;
			local path = SYMTABLE.bindings[sym];
			if (path and (SYMTABLE.mstate[1] or SYMTABLE.mstate[2])) then
				suppl_run_menu(WM.menu, path, debugf, debug_verbose);
				return;
			end
		end
	end

-- and forward if valid
	if (not valid_vid(target, TYPE_FRAMESERVER)) then
		return;
	end

	iotbl = model:preprocess_input(iotbl);
	target_input(target, iotbl);
end

function safespaces_display_state(action, id)
	if (action == "reset") then
		SYMTABLE.mstate = {false, false};

	elseif (action == "added") then
-- if we are waiting for this display, then go for it
		display_action( suppl_display_name(id), id );

	elseif (action == "removed") then
	end
end

-- handler for when running in a nested mode via arcan_lwa,
-- used to make sure that window resizes gets reflected in
-- the windowed output etc. (if relevant)
function VRES_AUTORES(w, h, vppcm, flags, source)
	SYMTABLE.mstate[1] = false;
	SYMTABLE.mstate[2] = false;

	if (WM.dev) then
		resize_video_canvas(w, h);
		if (valid_vid(WM.vr_pipe)) then
			image_resize_storage(WM.vr_pipe, w, h);
			move_image(WM.vr_pipe, 0, 0);
		end
		camtag_model(
			WM.camera, 0.01, 100.0, 45.0, w/h, true, true, 0, surf);
	end
end
