--
-- This provides a 'default' non-VR user-console,
-- although it could possibly be mapped to a surface in 3D space as well.
--
local console_rt;
local log_message = {
};

local log_limit = 1000;
local font_sz = 12;
local font_fmt_line = "\\ffonts/hack.ttf," .. tostring(font_sz);
local font_height = font_sz;

local console_vid;

-- most of this is quick and dirty rather than useful, each new line will
-- cause a full reraster, which with the current font backend is expensive.
local function update_console()
	if not valid_vid(console_rt) then
		return
	end

-- show the last n lines that fits the set console size
	local rtp = image_storage_properties(console_rt)
	local nl = math.floor(rtp.height / font_height);
	local list = {font_fmt_line}
	local si = #log_message < nl and 1 or #log_message - nl

-- build the table for rastering
	for i=si,#log_message do
		local v= log_message[i];
		table.insert(list, v)
		table.insert(list, "\\r\\n")
	end

	if (valid_vid(console_vid)) then
		render_text(console_vid, list)
	else
		console_vid = render_text(list)
	end

	if not valid_vid(console_vid) then
		return
	end

-- make sure it actually is attached to the right rendertarget (might be a no-op)
-- and that it is currently visible, re-show every update to survive bugs in the
-- scripts given that the purpose of the console is mainly debugging
	rendertarget_attach(console_rt, console_vid, RENDERTARGET_DETACH)
	show_image(console_vid)

-- reposition to make sure the last lines are visible even if our other vals
-- would, for some reason, be incorrect
	move_image(console_vid, 0, rtp.height - image_surface_properties(console_vid).height)
end

function console_resize(neww, newh)
	if not valid_vid(console_rt) then
		return
	end

	image_resize_storage(console_rt, neww, newh)
	local props = image_storage_properties(console_rt);
end

function console_add_view(vid)
	if not valid_vid(console_vid) then
		warning("trying to add view without working console")
		return
	end

	move_image(vid, VRESW - image_surface_properties(vid).width, 0)
	rendertarget_attach(console_rt, vid, RENDERTARGET_DETACH)
	show_image(vid)
end

function console_setup(opts)
	local vids = {}
	opts = opts and opts or {}

	if preview then
		table.insert(vids, preview)
	end

	console_rt = alloc_surface(
		opts.console_width and opts.console_width or VRESW,
		opts.console_height and opts.console_height or VRESH
	)

	image_tracetag(console_rt, "console_output")
	define_rendertarget(console_rt,
		vids, RENDERTARGET_DETACH, RENDERTARGET_NOSCALE, -1, RENDERTARGET_COLOR)

-- test the console font-size output in order to determine number of visible lines
	local vid, lh, _, _, asc = render_text({font_fmt_line, "ijgq"});
	if valid_vid(vid) then
		font_height = asc;
		delete_image(vid);
	end

-- replace the history limit
	if opts.console_lines and opts.console_lines > 10 then
		log_limit = opts.console_lines
	end

	console_log("system", "started")
end

function console_output()
	return console_rt
end

function console_log(source, message)
	print(source, message);
	table.insert(log_message,
		string.format("[%d] %s: %s", benchmark_timestamp(), source, message))

	if #log_message > log_limit then
		table.remove(log_message, 1)
	end
	update_console()
end
