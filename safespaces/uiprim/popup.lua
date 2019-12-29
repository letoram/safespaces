-- Copyright 2019, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: UI primitive for spawning a simple popup menu.
-- Dependencies: assumes builtin/mouse.lua is loaded and active.
-- Limitations:
--  * Does not implement scrolling, assumes all entries fits inside buffer,
--    (though could be added using the step_group setup)
--  * Menu contents is static, activation collapses all.
--  * Does not implement submenu spawning or positioning
-- Notes:
--  * suppl_setup_mousegrab can be used to capture mouse input outside
local spawn_popup

-- entry point used for testing as an appl of its own,
-- and an example of how to set it up and use it
if (APPLID == "uiprim_popup_test") then
_G[APPLID] = function (arguments)
	system_load("builtin/mouse.lua")()
	local cursor = fill_surface(8, 8, 0, 255, 0);
	mouse_setup(cursor, 65535, 1, true);

	system_defaultfont("default.ttf", 12, 1)
	local list = {
		{
			label  = "this",
			kind = "action",
			eval = function()
				return true
			end,
			handler = function()
				print("this entered");
			end
		},
		{
			label = "is not",
			kind = "action",
			handler = function()
				return {
					{
						label = "an exit",
						kind = "action",
						eval = function()
							return false
						end,
						handler = function()
							print("ebichuman")
						end
					}
				}
			end,
			submenu = true
		}
	}

	if #arguments > 0 then
		for i,v in ipairs(arguments) do
			table.insert(list, {
				name = string.lower(v),
				label = v,
				kind = "action",
				eval = function()
					return i % 2 ~= 0
				end,
				handler = function()
					print(v)
				end
			})
		end
	end

	SYMTABLE = system_load("builtin/keyboard.lua")()

-- simple border example, just adds a fill-rate burning double+ csurf
	local popup = spawn_popup(list, {
		border_attach = function(tbl, anchor)
			local bw = 1
			local props = image_surface_resolve(anchor)
			local frame = color_surface(
				props.width + 4 * bw, props.height + 4 * bw, 0xaa, 0xaa, 0xaa)
			local bg = color_surface(
				props.width + 2 * bw, props.height + 2 * bw, 0x22, 0x22, 0x22)
			show_image({frame, bg})
			link_image(frame, anchor)
			link_image(bg, anchor)
			move_image(frame, -2 * bw, -2 * bw)
			move_image(bg, -bw, -bw)
			image_inherit_order(frame, true)
			image_inherit_order(bg, true)
			order_image(frame, -2)
			order_image(bg, -1)
			image_mask_set(frame, MASK_UNPICKABLE)
			image_mask_set(bg, MASK_UNPICKABLE)
			order_image(anchor, 10)
		end
	})

	move_image(popup.anchor, 50, 50)

	if not popup then
		return shutdown("couldn't build popup", EXIT_FAILURE)
	end

	local dispatch = {
		["UP"] = function()
			popup:step_up()
		end,
		["DOWN"] = function()
			popup:step_down()
		end,
		["ESCAPE"] = function()
			shutdown()
		end
	}

	uiprim_popup_test_input = function(iotbl)
		if iotbl.mouse then
			mouse_iotbl_input(iotbl);
		elseif iotbl.translated and iotbl.active then
			local sym, _ = SYMTABLE:patch(iotbl)
			if (dispatch[sym]) then
				dispatch[sym]()
			end
		end
	end
end
end

-- manual / button triggered cursor navigation, just step up
-- until we reach the last active item and stay there, if not
-- possible the cursor will be hidden
local function step_up(ctx)
	for i=1,#ctx.menu do
		ctx.index = ctx.index - 1
		if ctx.index == 0 then
			ctx.index = #ctx.menu
		end
		if ctx.menu[ctx.index].active then
			ctx:set_index(ctx.index)
			return
		end
	end
	ctx:set_index(1)
end

local function step_dn(ctx)
	for i=1,#ctx.menu do
		ctx.index = ctx.index + 1
		if ctx.index > #ctx.menu then
			ctx.index = 1
		end
		if ctx.menu[ctx.index].active then
			ctx:set_index(ctx.index)
			return
		end
	end
	ctx:set_index(1)
end

local function menu_to_fmtstr(menu, options)
	local text_list = {}
	local sym_list = {}

	local text_valid = options.text_valid or "\\f,0\\#ffffff"
	local text_invalid = options.text_invalid or "\\f,0\\#999999"
	local text_menu = options.text_menu or "\f,0\\#aaaaaa"

	for i,v in ipairs(menu) do
		local fmt_suffix = i > 1 and [[\n\r]] or ""
		local prefix
		local suffix = ""

		if not v.active then
			prefix = text_invalid
		elseif v.submenu then
			prefix = text_menu
			suffix = options.text_menu_suf and options.text_menu_suf or ""
		else
			prefix = text_valid
		end

		if v.format then
			prefix = prefix .. v.format
		end

		table.insert(text_list, prefix .. fmt_suffix)
		table.insert(text_list, v.label .. suffix)
		table.insert(sym_list, v.shortcut and v.shortcut or "")
	end

	return text_list, sym_list
end

local function set_index(ctx, i)
	if i < 1 or i > #ctx.menu then
		return
	end

	ctx.index = i
-- it would possibly be nicer to have the 'invert' effect that some
-- toolkits provide, but it is a bit of a hassle unless we can do it
-- with a shader setting start-end s,t and simply modulate the color
-- there.
	if ctx.menu[i].active then
		local h = ctx.index == #ctx.menu
			and ctx.max_h - ctx.line_pos[i] or (ctx.line_pos[i+1] - ctx.line_pos[i])

		if (valid_vid(ctx.cursor)) then
			blend_image(ctx.cursor, 0.5)
			move_image(ctx.cursor, 0, ctx.line_pos[i])
			resize_image(ctx.cursor, ctx.max_w, h)
		end

		if ctx.options.cursor_at then
			ctx.options.cursor_at(ctx, ctx.cursor, 0, ctx.line_pos[i], ctx.max_w, h);
		end
	elseif valid_vid(ctx.cursor) then
		hide_image(ctx.cursor)
	end
end

local function drop(ctx)
	if ctx.animation_out > 0 then
		blend_image(ctx.anchor, 0, ctx.animation_out)
		expire_image(ctx.anchor, ctx.animation_out)
	else
		delete_image(ctx.anchor);
	end
end

local function cancel(ctx)
	if not valid_vid(ctx.anchor) then
		return
	end

	drop(ctx);

	if not ctx.in_finish and ctx.options.on_finish then
		ctx.options.on_finish(ctx);
	end
end

local function trigger(ctx)
	if not ctx.menu[ctx.index].active then
		return
	end

-- let the handler determine if we are done and should be closed or not
	if ctx.options.on_finish then
		if ctx.options.on_finish(ctx, ctx.menu[ctx.index]) then
			return
		end
	end

-- otherwise we can run it (and decide if we handle a new menu or not,
-- and what method, i.e. replace current or reposition)
	drop(ctx);

-- submenu spawn / positioning is advanced and up to the parent
	if ctx.menu[ctx.index].handler and not ctx.menu[ctx.index].submenu then
		ctx.menu[ctx.index].handler()
	end
end

local function tbl_copy(tbl)
	local res = {}
	for k,v in pairs(tbl) do
		if type(v) == "table" then
			res[k] = tbl_copy(v)
		else
			res[k] = v
		end
	end
	return res
end

-- menu : normal compliant menu table, assumed to have passed
-- the rules in menu.lua:menu_validate. fields used:
--  label (text string to present)
--  eval (determine if an action on it is valid or not)
--  submenu (tag with an icon to indicate a submenu to trigger
--  shortcut (text- str for right column)
--
-- valid options:
--  anchor        - parent vid to attach to
--  text_valid    - string prefix to use for a line of valid output
--  text_invalid  - string prefix to use for a line of inactive output
--  text_menu     - string prefix to use for a line of a menu
--  text_menu_suf - string suffix to use for a line of a menu
--  animation_in  - time for fade / animate in
--  animation_out - time for fade / animate out
--  border_attach - function(ctx : tbl, src : vid, width, height)
--                  end
--                  called on spawn, attach with border vid, inherit
--                  order and re-order to -1. Nudge the anchor or the
--                  border / background region itself, your choice.
--                  image_mask_set(vid, MASK_UNPICKABLE) as well.
--
--  cursor_at     - function(ctx : tbl, cursor: vid, x, y, width, height)
--                  end
--                  Updated when the cursor has moved (and on spawn),
--                  implement to override default cursor
--
--
--  on_finish     - function(ctx, entry(=nil))
--                  end
--                  triggered on valid 'select' or on cancel.
--
-- returns table:
-- attributes:
--  anchor : vid
--  cursor : vid (unless cursor_at is set)
--  max_w  : highest width recorded from text groups
--  max_h  : highest height recorded from text groups
--
-- methods:
--  step_up
--  step_down
--  set_index(i)
--  trigger -> menu entry
--  cancel()
--
-- as well as a closure that needs to be invoked to clean up dangling
-- resources, useful if the mouse_grab layer is attached.
--
spawn_popup =
function(menu, options)
	local res = {
		step_up = step_up,
		step_down = step_dn,
		set_index = set_index,
		trigger = trigger,
		cancel = cancel,
		anchor = null_surface(1, 1),
		max_w = 0,
		max_h = 0,
		index = 1,
		options = options
	}

-- out of VIDs?
	if not valid_vid(res.anchor) then
		return
	end

	show_image(res.anchor)
	options = options and options or {}

	local animation_in = options.animation_in and options.animation_in or 10
	res.animation_out = options.animation_out and options.animation_out or 20

-- use a copy where eval switches into active
	local lmenu = {}
	local active = #menu

	for _,v in ipairs(menu) do
		if not v.alias then
			table.insert(lmenu, tbl_copy(v));
			local i = #lmenu
			lmenu[i].active = true
			if lmenu[i].eval ~= nil then
				if lmenu[i].eval == false or
					(type(lmenu[i].eval) == "function" and lmenu[i].eval() ~= true) then
				lmenu[i].active = false
				active = active - 1
				end
			end
		end
	end

	res.menu = lmenu

-- no point in providing a menu that can't be selected
	if active == 0 then
		return
	end

-- build string table
	local text_list, symbol_list = menu_to_fmtstr(lmenu, options)
	if not text_list then
		return
	end

-- render failure is bad font or out of VIDs, drop the group
	local vid, lh, width, height, ascent = render_text(text_list)
	if not valid_vid(vid) then
		return
	end
	res.line_pos = lh
	res.cursor_h = ascent

-- disable mouse handling, we do that for the anchor surface
	image_mask_set(vid, MASK_UNPICKABLE)
	local props = image_surface_resolve(vid)

	res.max_w = res.max_w > props.width and res.max_w or props.width
	res.max_h = res.max_h + props.height

	link_image(vid, res.anchor);
	image_inherit_order(vid, true)
	show_image(vid)
	resize_image(res.anchor, res.max_w, res.max_h)

	local mh = {
		name = "popup_mouse",
		own = function(ctx, vid)
			return vid == res.anchor
		end,
		motion = function(ctx, vid, x, y)
			local props = image_surface_resolve(res.anchor);
			local row = y - props.y;
-- cheap optimization here would be to simply check from < last_n or > last_n
-- based on dy from last time, but cursors can be jumpy.
			local last_i = 1;
			for i=1,#lh do
				if row < lh[i] then
					break;
				else
					last_i = i;
				end
			end
			res:set_index(last_i)
		end,
		button = function(ctx, vid, ind, act)
			if (not act or ind > MOUSE_WHEELNX or ind < MOUSE_WHEELPY) then
				return;
			end
			if (ind == MOUSE_WHEELNX or ind == MOUSE_WHEELNY) then
				res:step_down();
			else
				res:step_up();
			end
		end,
		click = function(ctx)
			res:trigger()
		end
	};
	mouse_addlistener(mh, {"motion", "click", "button"})

	if (not options.cursor_at) then
		local cursor = color_surface(64, 64, 255, 255, 255);
		link_image(cursor, res.anchor)
		blend_image(cursor, 0.5)
		force_image_blend(cursor, BLEND_ADD);
		image_inherit_order(cursor, true)
		order_image(cursor, 2)
		image_mask_set(cursor, MASK_UNPICKABLE)
		res.cursor = cursor
	end

-- all the other resources are in place, size the anchor surface and
-- register it as the mouse handler

-- run border attach to allow a custom look and field, typically color
-- surface with some shader arranged around
	if options.border_attach then
		options.border_attach(res, res.anchor, res.max_w, res.max_h)
	end

	local function closure()
		if mh.name then
			mh.name = nil
			mouse_droplistener(mh);
		end
	end

-- resize the cursor and find the first valid entry
	res.index = #res.menu
	res:step_down()

	return res, closure
end

-- normal constructor function that returns a table of operations
return spawn_popup
