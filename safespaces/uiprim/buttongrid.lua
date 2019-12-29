-- Copyright 2016-2019, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: Simple tightly packed grid of uniform buttons

-- arguments:
--   rows, cols : the distribution of buttons
--   cellw, cellh : forced dimension of each button
--   xp, yp : pad between buttons
--   opts:
--    borderw (default: 0) padding from anchor
--    fmt: format string for label rendering
--    autodestroy: call destroy on the first button trigger
--
-- buttons should be rows * cols number of tables with:
--   color (0..1, 0..1, 0..1) normal color
--   color_hi (0..1, 0..1, 0..1) highlight color
--   label (optional) string
--   path  (optional) menu path on activation
--
-- returns a table with the members:
--   destroy() - use to deallocate mouse handlers
--   anchor - clipping / attachment anchor
--   run(x, y) - trigger the button at the end of run
--
local function destroy(ctx)
	if (valid_vid(ctx.anchor)) then
		delete_image(ctx.anchor);
	end
	mouse_droplistener(ctx);
	ctx.destroy = nil;
end

local function own(ctx, vid)
	return ctx.vids[vid] ~= nil;
end

local function over(ctx, vid)
	local tbl = ctx.vids[vid];
	image_color(vid,
		tbl.color_hi[1] * 255,
		tbl.color_hi[2] * 255,
		tbl.color_hi[3] * 255
	);
end

local function click(ctx, vid)
	if (not ctx.vids[vid].cmd) then
		return;
	end
	ctx.vids[vid].cmd();
	if (ctx.autodestroy) then
		ctx:destroy();
	end
end

local function rclick(ctx, vid)
	if (not ctx.vids[vid].cmd) then
		return;
	end

	ctx.vids[vid].cmd(true);

	if (ctx.autodestroy) then
		ctx:destroy();
	end
end

local function out(ctx, vid)
	local tbl = ctx.vids[vid];
	image_color(vid,
		tbl.color[1] * 255, tbl.color[2] * 255, tbl.color[3] * 255);
end

function uiprim_buttongrid(rows, cols, cellw, cellh, xp, yp, buttons, opts)
	if (#buttons ~= rows * cols or rows <= 0 or cols <= 0 or cellw == 0) then
		return;
	end

	opts = opts and opts or {};

	local res = {
-- methods
		destroy = destroy,

-- tracking members
		vids = {},
		autodestroy = opts.autodestroy,

-- returned table match the interface of the mouse handler:
		own = own,
		over = over,
		click = click,
		rclick = rclick,
		out = out,
		name = "gridbtn_mh"
	};

	local bw = opts.borderw and opts.borderw or 0;

	res.anchor = null_surface(cols * cellw + bw + bw, rows * cellh + bw + bw);
	if (not valid_vid(res.anchor)) then
		return;
	end
	image_inherit_order(res.anchor, true);
	show_image(res.anchor);
	image_tracetag(res.anchor, "butongrid_anchor");

	local
	function build_btn(tbl)
		local bg = color_surface(cellw, cellh,
			tbl.color[1] * 255, tbl.color[2] * 255, tbl.color[3] * 255);
		if (not valid_vid(bg)) then
			return;
		end
		image_tracetag(bg, "buttongrid_button_bg");
		link_image(bg, res.anchor);
		image_inherit_order(bg, true);
		order_image(bg, 1);
		show_image(bg);

		if (tbl.label) then
			local vid = render_text({opts.fmt and opts.fmt or "", tbl.label});
			if (valid_vid(vid)) then
				link_image(vid, bg);
				image_inherit_order(vid, true);
				order_image(vid, 1);
				show_image(vid);
				image_mask_set(vid, MASK_UNPICKABLE);
				image_clip_on(vid, CLIP_SHALLOW);
				center_image(vid, bg, ANCHOR_C);
				image_tracetag(vid, "buttongrid_button_label");
			end
		end

		return bg;
	end

	local ind = 1;
	for y=1,rows do
		for x=1,cols do
			local btn = build_btn(buttons[ind]);
			if (not btn) then
				delete_image(anchor);
				return;
			else
				res.vids[btn] = buttons[ind];
				move_image(btn, (x-1) * (xp + cellw), (y-1) * (yp + cellh));
			end
			ind = ind + 1;
		end
	end

	mouse_addlistener(res, {"click", "rclick", "over", "out"});
	return res;
end
