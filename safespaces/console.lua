--
-- This provides a 'default' non-VR user-console,
-- although it could possibly be mapped to a surface in 3D space as well.
--
local console_rt;
local log_message = {
};
local log_limit = 10;
local font_sz = 12;
local console_vid;

local function update_console()
	if not valid_vid(console_rt) then
		return
	end

	local list = {"\\ffonts/hack.ttf," .. tostring(font_sz)}
	for k,v in ipairs(log_message) do
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

	rendertarget_attach(console_rt, console_vid, RENDERTARGET_DETACH)
	show_image(console_vid)
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
