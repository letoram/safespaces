-- compatibility workaround
if not TD_HINT_FULLSCREEN then
	TD_HINT_FULLSCREEN = 16;
end

if not TD_HINT_MAXIMIZED then
	TD_HINT_MAXIMIZED = 8;
end

local vert = [[
uniform mat4 modelview;
uniform mat4 projection;

attribute vec2 texcoord;
attribute vec4 vertex;

/* for sbs- ou- remapping */
uniform vec2 ofs_leye;
uniform vec2 ofs_reye;
uniform vec2 scale_leye;
uniform vec2 scale_reye;

uniform int rtgt_id;
uniform bool flip;
uniform float curve;

varying vec2 texco;

void main()
{
	vec2 tc = texcoord;

	if (flip){
		tc.t = 1.0 - tc.t;
	}

	vec4 vert = vertex;

	if (rtgt_id == 0){
		tc *= scale_leye;
		tc += ofs_leye;
	}
	else {
		tc *= scale_reye;
		tc += ofs_reye;
	}

	if (curve > 0.0){
		vert.z -= sin(3.14 * tc.s) * curve;
	}

	texco = tc;
	gl_Position = (projection * modelview) * vert;
}
]];

local frag = [[
uniform sampler2D map_tu0;
uniform float obj_opacity;
varying vec2 texco;

void main()
{
	vec4 col = texture2D(map_tu0, texco);
	gl_FragColor = vec4(col.rgb, col.a * obj_opacity);
}
]];

local modelconn_eventhandler;

-- shader used on each eye, one possible place for distortion but
-- probably better to just use image_tesselation to displace the
-- vertices on l_eye and r_eye once, and use the shader stage for
-- variable vignette using obj_opacity as strength.
local distort = [[
uniform sampler2D map_tu0;
uniform float obj_opacity;

uniform vec2 lens_center;
uniform vec2 viewport_scale;
uniform float warp_scale;
uniform vec4 distortion;
uniform vec3 aberration;

varying vec2 texco;

void main()
{
	vec2 r = (texco * viewport_scale - lens_center);
	r /= warp_scale;
	float r_mag = length(r);

	vec2 r_displaced = r * (
		distortion.w +
		distortion.z * r_mag +
		distortion.y * r_mag * r_mag +
		distortion.x * r_mag * r_mag * r_mag
	);
	r_displaced *= warp_scale;

	vec2 tc_r = (lens_center + aberration.r * r_displaced) / viewport_scale;
	vec2 tc_g = (lens_center + aberration.g * r_displaced) / viewport_scale;
	vec2 tc_b = (lens_center + aberration.b * r_displaced) / viewport_scale;

	float cr = texture2D(map_tu0, tc_r).r;
	float cg = texture2D(map_tu0, tc_g).g;
	float cb = texture2D(map_tu0, tc_b).b;

	if (tc_g.x < 0.0 || tc_g.x > 1.0 || tc_g.y < 0.0 || tc_g.y > 1.0)
		discard;

	gl_FragColor = vec4(cr, cg, cb, 1.0);
}
]];

local vrshaders = {
	geom = build_shader(vert, frag, "vr_geom"),
	distortion = build_shader(nil, distort, "vr_distortion")
};

local function set_model_uniforms(shid,
	leye_x, leye_y, leye_ss, leye_st, reye_x, reye_y, reye_ss, reye_st, flip, curve)
	shader_uniform(shid, "ofs_leye", "ff", leye_x, leye_y);
	shader_uniform(shid, "scale_leye", "ff", leye_ss, leye_st);
	shader_uniform(shid, "ofs_reye", "ff", reye_x, reye_y);
	shader_uniform(shid, "scale_reye", "ff", reye_ss, reye_st);
	shader_uniform(shid, "flip", "b", flip);
	shader_uniform(shid, "curve", "f", curve);
end

local function shader_defaults()
	set_model_uniforms(
		vrshaders.geom, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0, true, 0.1);

	vrshaders.geom_inv = shader_ugroup(vrshaders.geom);
	vrshaders.rect = shader_ugroup(vrshaders.geom);
	vrshaders.rect_inv = shader_ugroup(vrshaders.geom);

	shader_uniform(vrshaders.geom_inv, "flip", "b", false);
	shader_uniform(vrshaders.rect_inv, "flip", "b", false);
	shader_uniform(vrshaders.rect, "curve", "f", 0.5);
	shader_uniform(vrshaders.rect_inv, "curve", "f", 0.5);
end
shader_defaults();

-- when the VR bridge is active, we still want to be able to tune the
-- distortion, fov, ...
local function set_vr_defaults(ctx, opts)
	local tbl = {
		oversample_w = 1.4,
		oversample_h = 1.4,
		hmdarg = "",
	};
	for k,v in pairs(tbl) do
		ctx[k] = (opts[k] and opts[k]) or tbl[k];
	end
end

local function vr_distortion(vrctx, model)
	if (not model or model == "none") then
		image_shader(vrctx.rt_l, "DEFAULT");
		image_shader(vrctx.rt_r, "DEFAULT");
		image_set_txcos_default(vrctx.rt_l);
		image_set_txcos_default(vrctx.rt_r);
	else
		local md = vrctx.meta;
		local shid = vrctx.shid;
		local viewport = {md.horizontal * 0.5, md.vertical};
		local center_l = {viewport[1] - 0.5 * md.hsep, md.vpos};
		local center_r = {md.hsep * 0.5, md.vpos};
		local warp_scale = center_l[1] > center_r[1] and center_l[1] or center_r[1];
		local dst = md.distortion;
		local abb = md.abberation;

		shader_uniform(shid, "lens_center", "ff", center_l[1], center_l[2]);
		shader_uniform(shid, "warp_scale", "f", warp_scale);
		shader_uniform(shid, "viewport_scale", "ff", viewport[1], viewport[2]);
		shader_uniform(shid, "distortion", "ffff", dst[1], dst[2], dst[3], dst[4]);
		shader_uniform(shid, "aberration", "fff", abb[1], abb[2], abb[3]);

		local rsh = shader_ugroup(shid);
		shader_uniform(rsh, "lens_center", "ff", center_r[1], center_r[2]);

		image_shader(vrctx.rt_l, shid);
		image_shader(vrctx.rt_r, rsh);
		image_set_txcos_default(vrctx.rt_l);
		image_set_txcos_default(vrctx.rt_r);
	end
end

local function setup_vr_display(wnd, callback, opts)
	set_vr_defaults(wnd, opts);

-- no need for rendertarget redirection if we're going monoscopic/windowed
	if (not valid_vid(wnd.vr_pipe)) then
		return;
	end

-- or make these status messages into some kind of logging console,
-- probably best when we can make internal TUI connections and do
-- it that way

-- ideally, we'd get a display with two outputs so that we could map
-- the rendertargets directly to the outputs, getting rid of one step
--
-- this currently leaks one shader_ugroup per invocation
--
	local setup_vrpipe =
	function(bridge, md, neck)
		for k,v in pairs(opts) do
			if (opts[k]) then
				md[k] = opts[k];
			end
		end


		local dispw = md.width > 0 and md.width or 1920;
		local disph = md.height > 0 and md.height or 1024;
		dispw = math.clamp(dispw, 256, MAX_SURFACEW);
		disph = math.clamp(disph, 256, MAX_SURFACEH);
		local eyew = math.clamp(dispw * wnd.oversample_w, 256, MAX_SURFACEW);
		local eyeh = math.clamp(disph * wnd.oversample_h, 256, MAX_SURFACEH);
		local halfw = dispw * 0.5;
		local halfh = disph * 0.5;
		local diff = dispw - halfh;

		local invert_eye_dimension = false;
		local rotation = 0;
		local pos_l_eye_x = 0;
		local pos_l_eye_y = 0;
		local pos_r_eye_x = halfw;
		local pos_r_eye_y = 0;
		local eye_w = halfw;
		local eye_h = disph;

		if ("ccw90" == opts.display_rotate ) then
			rotation = 90;
			invert_eye_dimension = true;
			pos_l_eye_x = diff / 2;
			pos_l_eye_y = -diff / 2;
			pos_r_eye_x = diff / 2;
			pos_r_eye_y = halfh - (diff /2);
			eye_w = halfh;
			eye_h = dispw;
		elseif ("cw90" == opts.display_rotate) then
			rotation = -90;
			invert_eye_dimension = true;
			pos_l_eye_x = diff / 2;
			pos_l_eye_y = halfh - (diff /2);
			pos_r_eye_x = diff / 2;
			pos_r_eye_y = -diff / 2;
			eye_w = halfh;
			eye_h = dispw;
		elseif ("180" == opts.display_rotate) then
			rotation = 180;
			pos_l_eye_x = halfw;
			pos_l_eye_y = 0;
			pos_r_eye_x = 0;
			pos_r_eye_y = 0;
		end

		local l_eye = alloc_surface(eyew, eyeh);
		local r_eye = alloc_surface(eyew, eyeh);

		show_image({l_eye, r_eye});

		define_linktarget(l_eye, wnd.vr_pipe);
		define_linktarget(r_eye, wnd.vr_pipe);
		rendertarget_id(l_eye, 0);
		rendertarget_id(r_eye, 1);

		move_image(l_eye, pos_l_eye_x, pos_l_eye_y);
		move_image(r_eye, pos_r_eye_x, pos_r_eye_y);

		resize_image(l_eye, eye_w, eye_h);
		resize_image(r_eye, eye_w, eye_h);

		rotate_image(l_eye, rotation, 0);
		rotate_image(r_eye, rotation, 0);

-- Assume SBS configuration, L/R, combiner is where we apply distortion
-- and the rendertarget we bind to a preview window as well as map to
-- the display.
--
-- A few things are missing here, the big one is being able to set MSAA
-- sampling and using the correct shader / sampler for that in the combiner
-- stage.
--
-- The second is actual distortion parameters via a mesh.
--
-- The third is a stencil mask over the rendertarget (missing Lua API).
		local combiner;
		if (not opts.no_combiner) then
			combiner = alloc_surface(dispw, disph);
			show_image(combiner);
			if (valid_vid(wnd.anchor)) then
				link_image(combiner, wnd.anchor);
			end
		end

-- since we don't show any other models, this is fine without a depth buffer
		if (combiner) then
			define_rendertarget(combiner, {l_eye, r_eye});
		end

		local cam_l = null_surface(1, 1);
		local cam_r = null_surface(1, 1);
		scale3d_model(cam_l, 1.0, -1.0, 1.0);
		scale3d_model(cam_r, 1.0, -1.0, 1.0);

		local l_fov = math.deg(md.left_fov);
		local r_fov = math.deg(md.right_fov);

		if (md.left_ar < 0.01) then
			md.left_ar = eye_w / eye_h;
		end

		if (md.right_ar < 0.01) then
			md.right_ar = eye_w / eye_h;
		end

		camtag_model(cam_l, 0.01, 100.0, l_fov, md.left_ar, true, true, 0, l_eye);
		camtag_model(cam_r, 0.01, 100.0, r_fov, md.right_ar, true, true, 0, r_eye);

		local dshader = shader_ugroup(vrshaders.distortion);

-- ipd is set by moving l_eye to -sep, r_eye to +sep
		if (md.ipd) then
			move3d_model(cam_l, md.ipd * 0.5, 0, 0);
			move3d_model(cam_r, -md.ipd * 0.5, 0, 0);
		end


-- the distortion model has three options, no distortion, fragment shader
-- distortion and (better) mesh distortion that can be configured with
-- image_tesselation (not too many subdivisions, maybe 30, 40 something

		wnd.vr_state = {
			l = cam_l, r = cam_r, meta = md,
			rt_l = l_eye, rt_r = r_eye,
			set_distortion = vr_distortion,
			vid = bridge, shid = dshader,
			wnd = wnd
		};
		wnd.vr_state:set_distortion(md.distortion_model);

		if (not opts.headless) then
			vr_map_limb(bridge, cam_l, neck, false, true);
			vr_map_limb(bridge, cam_r, neck, false, true);
			wnd:message("HMD active");
			callback(wnd, combiner, l_eye, r_eye);
		else
			link_image(cam_l, wnd.camera);
			link_image(cam_r, wnd.camera);
			callback(wnd, combiner, l_eye, r_eye);
		end
	end

-- debugging, fake a hmd and set up a pipe for that, use rift- like distortion vals
	if (opts.headless) then
		setup_vrpipe(nil, {
			width = VRESW*0.5, height = VRESH,
			horizontal = 0.126, vertical = 0.07100,
			hsep = 0.063500, center = 0.049694,
			left_fov = 1.80763751, right_fov = 1.80763751,
			left_ar = 0.888885, right_ar = 0.88885,
			vpos = 0.046800,
			distortion = {0.247, -0.145, 0.103, 0.795},
			abberation = {0.985, 1.000, 1.015}
		}, nil);
		return;
	end

	vr_setup(opts.hmdarg, function(source, status)
		link_image(source, wnd.camera);

		if (status.kind == "terminated") then
			wnd:message("VR Bridge shut down (no devices/no permission)");
			callback(nil);
			wnd.vr_state = nil;
			delete_image(source);
		end
		if (status.kind == "limb_removed") then
			if (status.name == "neck") then
				delete_image(source);
				callback(nil);
			end
		elseif (status.kind == "limb_added") then
			if (status.name == "neck") then
				if (not wnd.vr_state) then
					local md = vr_metadata(source);
					setup_vrpipe(source, md, status.id);
				else
					warning("vr bridge reported neck limb twice");
				end
			end
		end
	end);

end

local function layer_rebalance(layer, ind)
	local nexti = function(ind)
		for i=ind+1,#layer.models do
			if (layer.models[i].parent == nil) then
				return i;
			end
		end
	end

	local ind = nexti(ind);
	while (ind) do
		local swap = nexti(ind);
		if (not swap) then
			break;
		end
		local old = layer.models[ind];
		layer.models[ind] = layer.models[swap];
		layer.models[swap] = old;
		ind = nexti(swap);
	end
end

local function model_display_source(model, vid)
	if (model.display_index) then
		set_image_as_frame(model.vid, vid, model.display_index);
	else
		image_sharestorage(vid, model.vid);
	end
end

local function model_scale_factor(model, factor, relative)
	if (relative) then
		model.scale_factor = model.scale_factor + factor;
	else
		model.scale_factor = factor;
	end
end

local function model_scale(model, sx, sy, sz)
	if (not sx or not sy or not sz) then
		return;
	end

	model.scalev = {
		sx,
		sy and sy or model.scalev[2],
		sz and sz or model.scalev[3]
	};
end

local function model_external(model, vid, flip)
	if (not valid_vid(vid, TYPE_FRAMESERVER)) then
		if (model.external) then
			model.external = nil;
		end
		return;
	end

-- it would probably be better to go with projecting the bounding
-- vertices unto the screen and use the display+oversample factor

-- note: this will be sent during the preload stage, where the
-- displayhint property for selection/visibility will be ignored.
-- note: The HMD panels tend to have other LED configurations,
-- though the data doesn't seem to be propagated via the VR bridge
-- meaning that subpixel hinting will be a bad idea (which it kindof
-- is regardless in this context).
	if (model.external ~= vid) then
		local w, h = model:get_displayhint_size();
		target_displayhint(vid, w, h, 0, {ppcm = model.ctx.display_density});
	end

	model.external = vid;
	model:set_display_source(vid);

-- gets updated on_resize with origo_ll
	if (model.force_flip ~= nil) then
		image_shader(model.vid,
				model.force_flip and model.shader.flip or model.shader.normal);
	else
		model.flip = flip;
		image_shader(model.vid,
			flip and model.shader.flip or model.shader.normal);
	end
end

local function model_getscale(model)
	local sf;

	if (model.layer.selected == model) then
		sf = model.scale_factor;
	else
		sf = model.layer.inactive_scale;
	end

	return
		model.scalev[1] * sf, model.scalev[2] * sf, model.scalev[3] * sf;
end

local function model_getsize(model, noscale)
	local sx = 1.0;
	local sy = 1.0;
	local sz = 1.0;

	if (not noscale) then
		sx, sy, sz = model_getscale(model);
	end

	return
		sx * model.size[1],
		sy * model.size[2],
		sz * model.size[3];
end

local function model_destroy(model)
	local layer = model.layer;

-- reparent any children
	local dst;
	local dst_i;

	for i,v in ipairs(layer.models) do
		if (v.parent == model) then
			if (dst) then
				v.parent = dst;
			else
				dst = v;
				dst_i = i;
				dst.parent = nil;
			end
		end
	end

-- inherit any selected state
	if (layer.selected == model) then
		layer.selected = nil;
		if (dst) then
			dst:select();
		end
	end

-- switch in the new child in this slot
	if (dst) then
		table.remove(layer.models, dst_i);
		local i = table.find_i(layer.models, model);
		layer.models[i] = dst;
	else
-- rebalance by swapping slot for every parentless node
		local ind = table.find_i(layer.models, model);
		if (ind) then
			table.remove(layer.models, ind);
			ind = ind - 1;

			layer_rebalance(layer, ind);
		end
	end

-- clean up rendering resources, but defer on animation
	local destroy = function(tmpmodel)
	if (model.custom_shaders) then
		for i,v in ipairs(model.custom_shaders) do
			delete_shader(v);
		end
	end

	delete_image(model.vid);
	if (valid_vid(model.external) and not model.external_protect) then
		delete_image(model.external);
	end

-- custom shader? these are derived with shader_ugroup so delete is simple
	if (model.shid) then
		delete_shader(model.shid);
	end

	if (valid_vid(model.ext_cp)) then
		delete_image(model.ext_cp);
	end

-- make it easier to detect dangling references
	for k,_ in pairs(model) do
		model[k] = nil;
	end
	end

-- animate fade out if desired, this has ugly subtle asynch races as the
-- different event handlers that may be attached to objects that are linked to
-- the vid MAY invoke members during this time.. including destroy ..
	if (model.ctx.animation_speed > 0) then
		for k,v in pairs(model) do
			if (type(v) == "function") then
				model[k] = function() end
			end
		end
		blend_image(model.vid, 0.0, 0.5* model.ctx.animation_speed);
		tag_image_transform(model.vid, MASK_OPACITY, destroy);
	else
		destroy();
	end

-- and rebalance / reposition
	layer:relayout();
end

-- in any of the external event handlers, we do this on terminated to make sure
-- that the object gets reactivated properly
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

local function model_show(model)
	model.active = true;
	if (image_surface_properties(model.vid).opacity == model.opacity) then
		return;
	end

-- special case, swap in on reveal
	if (model.ext_kind and model.ext_kind == "reveal-focus") then
		local ind;
		for i=1,#model.layer.models do
			if (model.layer.models[i].active) then
				ind = i;
				break;
			end
		end

		if (ind and model.layer.models[ind] ~= model) then
			local mind = table.find_i(model.layer.models, model);
			local foc = model.layer.models[ind];
			model.layer.models[ind] = model;
			model.layer.models[mind] = foc;
			model:select();
		end

	elseif (not model.layer.selected) then
		model:select();
	end

-- note: this does not currently set INVISIBLE state, only FOCUS
	if (valid_vid(model.external, TYPE_FRAMESERVER)) then
		if (model.layer.selected ~= model) then
			target_displayhint(model.external, 0, 0,
				bit.bor(TD_HINT_UNFOCUSED, TD_HINT_MAXIMIZED));
		else
			target_displayhint(model.external, 0, 0, TD_HINT_MAXIMIZED);
		end
	end

	local as = model.ctx.animation_speed;
	scale3d_model(model.vid, 0.01, 0.01, 1, 0);
	blend_image(model.vid, model.opacity, as);
	local sx, sy, sz = model:get_scale();
	scale3d_model(model.vid, sx, sy, 1, as);
	model.layer:relayout();
end

local function model_split_shader(model)
	if (not model.custom_shaders) then
		model.custom_shaders = {
			shader_ugroup(model.shader.normal),
			shader_ugroup(model.shader.flip)
		};
		model.shader.normal = model.custom_shaders[1];
		model.shader.flip = model.custom_shaders[2];
		image_shader(model.vid, model.custom_shaders[model.flip and 2 or 1]);
	end
end

local function model_stereo(model, args)
	if (#args ~= 8) then
		return;
	end

	model_split_shader(model);

	for i,v in ipairs(model.custom_shaders) do
		shader_uniform(v, "ofs_leye", "ff", args[1], args[2]);
		shader_uniform(v, "scale_leye", "ff", args[3], args[4]);
		shader_uniform(v, "ofs_reye", "ff", args[5], args[6]);
		shader_uniform(v, "scale_reye", "ff", args[7], args[8]);
	end
end

local function model_curvature(model, curv)
	model_split_shader(model);
	for i,v in ipairs(model.custom_shaders) do
		shader_uniform(v, "curve", "f", curv);
	end
end

local function model_select(model)
	local layer = model.layer;

	if (layer.selected == model) then
		return;
	end

	if (layer.selected and
		valid_vid(layer.selected.external, TYPE_FRAMESERVERE)) then
		target_displayhint(layer.selected.external, 0, 0,
			bit.bor(TD_HINT_UNFOCUSED, TD_HINT_MAXIMIZED));
	end

	if (valid_vid(model.external, TYPE_FRAMESERVER)) then
		target_displayhint(model.external, 0, 0, TD_HINT_MAXIMIZED);
	end

	layer.selected = model;
end

local function model_mergecollapse(model)
	model.merged = not model.merged;
	model.layer:relayout();
end

-- same as the terminal spawn setup, just tag the kind so that
-- we can deal with the behavior response in ext_kind
local function model_connpoint(model, name, kind, nosw)
	local cp = target_alloc(name,
	function(source, status)
		if (status.kind == "connected") then
			target_updatehandler(source, function(...)
				return modelconn_eventhandler(model.layer, model, ...);
			end);

		if (kind == "child") then
			return model_connpoint(model, name, kind, true);
		end

-- this should only happen in rare (OOM) circumstances, then it is
-- probably better to do nother here or spawn a timer
		elseif (status.kind == "terminated") then
			delete_image(source);
		end
	end);

-- there might be a current connection point that we override
	if (not nosw and valid_vid(model.ext_cp, TYPE_FRAMESERVER)) then
		delete_image(model.ext_cp);
		model.ext_cp = nil;
	end

	if (not valid_vid(cp)) then
		return;
	end

	link_image(cp, model.vid);
	model.ext_kind = kind;
	model.ext_name = name;
	model.ext_cp = cp;

-- special behavior: on termination, just set inactive and relaunch
	if (kind == "reveal" or kind == "reveal-focus") then
		model.active = false;
		model.layer:relayout();

	elseif (kind == "temporary") then
	end
end

local function model_swapparent(model)
	local parent = model.parent;

	if (not parent) then
		return;
	end

-- swap index slots so they get the same position on layout
	local parent_ind = table.find_i(model.layer.models, parent);
	local child_ind = table.find_i(model.layer.models, model);
	model.layer.models[parent_ind] = model;
	model.layer.models[child_ind] = parent;

-- and take over the parent role for all affected nodes
	for i,v in ipairs(model.layer.models) do
		if (v.parent == parent) then
			v.parent = model;
		end
	end
	parent.parent = model;
	model.parent = nil;

-- swap selection as well
	if (model.layer.selected == parent) then
		model:select();
	end

	model.layer:relayout();
end

local function model_input(model, iotbl)
-- missing, track LABEL translations and apply for default keybindings
-- and or game specific devices
	return iotbl;
end

local function model_vswap(model, step)
	local lst = {};
	for i,v in ipairs(model.layer.models) do
		if (v.parent == model) then
			table.insert(lst, v);
		end
	end

	local start = step < 0 and 2 or 1;
	step = math.abs(step);

	for i=start,#lst,2 do
		step = step - 1;
		if (step == 0) then
			lst[i]:swap_parent();
			return;
		end
	end
end

local function model_get_displayhint_size(model)
	local bw = model.ctx.near_layer_sz * (model.layer.index > 1 and
		((model.layer.index-1) * model.ctx.layer_falloff) or 1);

	return bw * model.scalev[1], bw * model.scalev[2];
end

local function build_model(layer, kind, name, ref)
	local res = {
		active = true, -- inactive are exempt from layouting
		name = name, -- unique global identifier
		ctx = layer.ctx,
		extctr = 0, -- external windows spawned via this model
		parent = nil,

-- positioning / sizing, drawing
		opacity = 1.0,

-- normalized scale values that accounts for the aspect ratio
		scalev = {1, 1, 1},

-- an 'in focus' scale factor, the 'out of focus' scale factor is part of the layer
		scale_factor = layer.active_scale,

-- cached layouter values to measure change
		layer_ang = 0,
		layer_pos = {0, 0, 0},
		rel_ang = {0, 0, 0},
		rel_pos = {0, 0, 0},

-- method vtable
		destroy = model_destroy,
		set_external = model_external,
		select = model_select,
		scale = model_scale,
		show = model_show,
		vswap = model_vswap,
		swap_parent = model_swapparent,
		get_size = model_getsize,
		get_scale = model_getscale,
		get_displayhint_size = model_get_displayhint_size,
		mergecollapse = model_mergecollapse,
		set_connpoint = model_connpoint,
		release_child = model_release,
		adopt_child = model_adopt,
		set_stereo = model_stereo,
		set_curvature = model_curvature,
		set_scale_factor = model_scale_factor,
		set_display_source = model_display_source,
		preprocess_input = model_input
	};

	local model;
	local depth = layer.depth;
	local h_depth = depth * 0.5;
	local shader = vrshaders.geom;
	local shader_inv = vrshaders.geom_inv;
	local size = {depth, depth, depth};

	if (kind == "cylinder") then
		model = build_cylinder(h_depth, depth, 360, 1);
	elseif (kind == "halfcylinder") then
		model = build_cylinder(h_depth, depth, 360, 1, "half");
	elseif (kind == "sphere") then
		model = build_sphere(h_depth, 360, 360, 1, false);
	elseif (kind == "hemisphere") then
		model = build_sphere(h_depth, 360, 180, 1, true);
	elseif (kind == "cube") then
		model = build_3dbox(depth, depth, depth, 1, true);
		image_framesetsize(model, 6, FRAMESET_SPLIT);
		res.n_sides = 6;
	elseif (kind == "rectangle") then
		res.scalev[2] = 0.5625;
		shader = vrshaders.rect;
		shader_inv = vrshaders.rect_inv;
		model = build_3dplane(
			-h_depth, -h_depth, h_depth, h_depth, 0,
			(depth / 20) * layer.ctx.subdiv_factor[1],
			(depth / 20) * layer.ctx.subdiv_factor[2], 1, true
		);
	elseif (kind == "custom") then
		if (not valid_vid(ref)) then
			warning("custom model specified but invalid ref");
			return;
		end
		model = ref;
		size = {2, 2, 2}; -- assuming -1..1 in all dimensions
	end

	if (not valid_vid(model)) then
		return;
	end

	res.shader = {normal = shader, flip = shader_inv};
	res.size = size;
	res.vid = model;

	if (kind ~= "custom") then
		swizzle_model(model);
		image_shader(model, shader);
	end

	if (valid_vid(layer.ctx.vr_pipe)) then
		rendertarget_attach(layer.ctx.vr_pipe, model, RENDERTARGET_DETACH);
	end
	link_image(model, layer.anchor);

	return res;
end

local function set_defaults(ctx, opts)
	local tbl = {
		layer_distance = 0.2,
		near_layer_sz = 1280,
		display_density = 33,
		layer_falloff = 0.9,
		terminal_font = "hack.ttf",
		terminal_font_sz = 18,
		animation_speed = 5,
		curve = 0.5,
		subdiv_factor = {1.0, 0.4},
	};

	for k,v in pairs(tbl) do
		ctx[k] = (opts[k] and opts[k]) or tbl[k];
	end
end

local function reindex_layers(ctx)
	local li = 1;
	for i,v in ipairs(ctx.layers) do
		if (not v.fixed) then
			v.index = li;
			li = li + 1;
		end
	end
	for i,v in ipairs(ctx.layers) do
		v:relayout();
	end
end

local function layer_zpos(layer)
	return layer.dz;
end

local function layer_add_model(layer, kind, name, ...)
	for k,v in ipairs(layer.models) do
		if (v.name == name) then
			return;
		end
	end

	local model = build_model(layer, kind, name, ...);
	if (not model) then
		return;
	end

	if (layer.models[1] and layer.models[1].active == false) then
		table.insert(layer.models, 1, model);
	else
		table.insert(layer.models, model);
	end
	model.layer = layer;

	return model;
end

-- this only changes the offset, the radius stays the same so no need to relayout
local function layer_step(layer, dx, dy)
	layer.dz = layer.dz + 0.001 * dy + 0.001 * dx;
	move3d_model(layer.anchor, layer.dx, layer.dy, layer:zpos());
end

local function layer_select(layer)
	if (layer.ctx.selected_layer) then
		if (layer.ctx.selected_layer == layer) then
			return;
		end
		layer.ctx.selected_layer = nil;
	end

	layer.ctx.selected_layer = layer;
	move3d_model(layer.anchor, 0, 0, layer:zpos(), layer.ctx.animation_speed);
-- here we can set alpha based on distance as well
end

local clut;
local function model_eventhandler(wnd, model, source, status)
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

-- terminal eventhandler behaves similarly to the default, but also send fonts
local function terminal_eventhandler(wnd, model, source, status)
	if (status.kind == "preroll") then
		target_fonthint(source,
			wnd.terminal_font, wnd.terminal_font_sz * FONT_PT_SZ, 2);
	else
		return model_eventhandler(wnd, model, source, status);
	end
end

-- This is for the bridge connection that probes basic display properties
-- subsegment requests here map to actual wayland surfaces.
local function wayland_eventhandler(wnd, model, source, status)
	if (status.kind == "preroll") then
		local width, height = model:get_displayhint_size();
		target_displayhint(source, width, height, 0, {ppcm = wnd.display_density});
		target_flags(source, TARGET_ALLOWGPU);

	elseif (status.kind == "segment_request") then
		if (status.segkind == "multimedia") then
-- subsurface, let default-reject apply
		elseif (status.segkind == "cursor") then
-- cursor, don't reject but allow only one
			if (model.mouse_cursor) then
				delete_image(model.mouse_cursor);
			end
			model.mouse_cursor = accept_target(function(...) end);
			if (not valid_vid(model.mouse_cursor)) then
				return;
			end
			link_image(model.mouse_cursor, model.vid);
		elseif (status.segkind == "popup") then
-- popup, default reject
		elseif (status.segkind == "clipboard") then
-- clipboard, default reject
		elseif (status.segkind == "application") then
-- actual toplevel, first assign to this model, wait with the splitting
-- out, linking etc. actions until we're later with the project
			if (valid_vid(model.toplevel)) then
				delete_image(model.toplevel);
			end
			model.toplevel = accept_target(
			function(source, status)
				return model_eventhandler(model.ctx, model, source, status);
			end);
			if (not valid_vid(model.toplevel)) then
				return;
			end

-- recall that the bridge is technically still alive, but we don't
-- want it to be the input handler for the model anymore, so replace
-- that..
			local width, height = model:get_displayhint_size();
			target_displayhint(source, width, height,
				TD_HINT_MAXIMIZED, {ppcm = wnd.display_density});
			model:set_display_source(model.toplevel);
			link_image(model.toplevel, model.vid);

-- yet we still need to relink to the model anchor so we get the cascade
-- deletion cleanup goodness
			if (model.external == source) then
				model.external = model.toplevel;
				link_image(source, model.vid);
			end
		end
	elseif (status.kind == "terminated") then
		if (model.destroy) then
			model:destroy();
		else
			delete_image(source);
		end
	end
end

clut = {
	application = model_eventhandler,
	terminal = terminal_eventhandler,
	tui = terminal_eventhandler,
	game = model_eventhandler,
	multimedia = model_eventhandler,
	["lightweight arcan"] = model_eventhandler,
	["bridge-x11"] = model_eventhandler,
	browser = model_eventhandler,

-- handlers to types that we don't accept as primary now
	["bridge-wayland"] = wayland_eventhandler,
	clipboard = nil, -- no clipboard managers
	popup = nil,
	icon = nil,
	titlebar = nil,
	sensor = nil,
	service = nil,
	debug = nil,
	widget = nil,
	accessibility = nil,
	clipboard_paste = nil,
	handover = nil
};

modelconn_eventhandler = function(layer, model, source, status)
	if (status.kind == "registered") then
-- based on segment type, install a new event-handler and tie to a new model
		local dstfun = clut[status.segkind];
		if (dstfun == nil) then
			delete_image(source);
			return;

-- there is an external connection handler that takes over whatever this model was doing
		elseif (model.ext_kind ~= "child") then
			target_updatehandler(source, function(source, status)
				return dstfun(layer.ctx, model, source, status);
			end);
			model.external_old = model.external;
			model.external = source;

-- or it should be bound to a new model
		else
			local new_model =
				layer:add_model("rectangle", model.name .. "_ext_" .. tostring(model.extctr));

			model.extctr = model.extctr + 1;
			target_updatehandler(source, function(source, status)
				return dstfun(layer.ctx, new_model, source, status);
			end);

			local parent = model.parent and model.parent or model;
			new_model.parent = parent;
			new_model:swap_parent();

			dstfun(layer.ctx, new_model, source, status);
		end
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

local term_counter = 0;
local function layer_add_terminal(layer, opts)
	opts = opts and opts or "";
	term_counter = term_counter + 1;
	local model = layer:add_model("rectangle", "term_" .. tostring(term_counter));
	if (not model) then
		return;
	end

-- setup a new connection point that will bridge connections based on this model
		local cp = "vr_term_";
		for i=1,8 do
			cp = cp .. string.char(string.byte("a") + math.random(1, 10));
		end
	local vid = launch_avfeed("env=ARCAN_CONNPATH="..cp..":"..opts, "terminal",
	function(...)
		return terminal_eventhandler(layer.ctx, model, ...);
	end
	);

	if (not valid_vid(vid)) then
		model:destroy();
		return;
	end

-- special case, we both have an external vid and a means of connecting
	model:set_external(vid, true);
	link_image(vid, model.vid);
	model:set_connpoint(cp, "child");
end

local function layer_set_fixed(layer, fixed)
	layer.fixed = fixed;
	reindex_layers(layer.ctx);
end

-- these functions are partially dependent on the layout scheme
local function layer_swap(layer, left, count)
	count = count and count or 1;

	if (count < 1) then
		return;
	end

-- swap with index[1], BUT only select if it can receive input and is active
	local set = {};

-- just grab the root nodes
	for i,v in ipairs(layer.models) do
		if (not v.parent) then
			table.insert(set, {i, v});
		end
	end

-- find the matching relative index using count
	local sc = #set;
	if (sc == 1) then
		return;
	end

-- make sure that the starting search index is active
	local ind = (left and 2) or 3;
	while (set[ind] and not set[ind][2].active) do
		ind = ind + 2;
	end

	while (count > 2 and set[ind]) do
		ind = ind + 2;
		if (set[ind][2].active) then
			count = count - 1;
		end
	end

	if (not set[ind]) then
		return;
	end

	local focus = layer.models[1];
	local new = set[ind][2];
	layer.models[set[ind][1]] = focus;
	layer.models[1] = new;

-- offset the old focus point slightly so their animation path doesn't collide
	if (focus.layer_pos) then
		move3d_model(focus.vid, focus.layer_pos[1],
			focus.layer_pos[2], focus.layer_pos[3] + 0.1, 0.5 * layer.ctx.animation_speed);
	end

-- only the focus- window gets to run a >1 scale
	new:scale();
	focus:scale();
	new:select();

	layer:relayout();
end

local function layer_merge(layer, left, step)
end

-- same as _swap, but more movement
local function layer_cycle(layer, left, step)
	if (step == 0) then
		layer:relayout();
		return;
	end

-- this should really be reworked to handle both directions
-- (change the recurse stage and the step_index)
	step = math.abs(step);

	local step_index = function(ind, n, step)
		step = step and step or 1;
		ind = ind + step;

		while (n > 0 and layer.models[ind]) do
			if (not layer.models[ind].parent and layer.models[ind].active) then
				n = n - 1;
				if (n == 0) then
					break;
				end
			end
			ind = ind + step;
		end
		return layer.models[ind] and ind or nil;
	end

	local rooti = step_index(0, 1);
	local startv = layer.models[rooti];

-- left starts 1 from root, right 2, then alternate left/right
	local firsti = left and step_index(rooti, 1) or step_index(rooti, 2);
	local starti = firsti;

	local lasti;
	while (starti) do
		lasti = starti;
		starti = step_index(starti, 2);
	end

	if (not lasti) then
		return;
	end

-- bubble-step towards start
	starti = lasti;
	local carryv = layer.models[rooti];

	while(starti and starti >= firsti) do
		assert(carryv.parent == nil);
		local nextv = layer.models[starti];
		layer.models[starti] = carryv;
		carryv = nextv;
		starti = step_index(starti, 2, -1);
	end

	layer.models[rooti] = carryv;

-- tail recurse if more than one step
	if (step > 1) then
		layer_cycle(layer, left, step - 1);
	else
		layer.models[rooti]:select();
		layer:relayout();
	end
end

local function layer_destroy(layer)

	for i,v in ipairs(layer.ctx.layers) do
		if (v == layer) then
			table.remove(layer.ctx.layers, i);
			break;
		end
	end
	if (layer.ctx.selected_layer == layer) then
		layer.ctx.selected_layer = layer.ctx.layers[1];
	end

-- rest will cascade
	delete_image(layer.anchor);

	for k,v in pairs(layer) do
		layer[k] = nil;
	end
end

local function dump(ctx, outf)
	local node_string = function(j)
		local pos = image_surface_resolve(j.vid);
		return string.format(
			"name='%s' active='%s' scale_factor='%.2f' scale='%.2f %.2f %.2f' opacity='%.2f'" ..
			"pos='%.2f %.2f %.2f' parent='%s'",
			j.name, j.active and "yes" or "no", j.scale_factor,
			j.scalev[1], j.scalev[2], j.scalev[3], j.opacity,
			pos.x, pos.y, pos.z, j.parent and j.parent.name or "no"
		);
	end

	local dump_children = function(layer, model)
		for i,j in ipairs(layer.models) do
			if (j.parent == model) then
				outf(string.format("\t\t<child index='%d' %s/>", i, node_string(j)));
			end
		end
	end

	for k,v in ipairs(ctx.layers) do
		outf(string.format(
			"<layer name='%s' index='%d' radius='%.2f' depth='%.2f' spacing='%.2f' opacity='%.2f'" ..
			" inactive_scale='%.2f'>", v.name, k, v.radius, v.depth, v.spacing, v.opacity,
			v.inactive_scale));

		for i,j in ipairs(v.models) do
			if (not j.parent) then
				outf(string.format("\t<node index='%d' %s/>", i, node_string(j)));
				dump_children(v, j);
			end
		end

		outf("</layer>");
	end
end

local function layer_count_root(layer)
	local cnt = 0;
	for i,v in ipairs(layer.models) do
		if (v.parent == nil) then
			cnt = cnt + 1;
		end
	end
	return cnt;
end

local function layer_count_children(layer, model)
	local cnt = 0;
	for i,v in ipairs(layer.models) do
		if (v.parent == model) then
			cnt = cnt + 1;
		end
	end
	return cnt;
end

local function model_release(model, ind, top)
	if (not layer.selected) then
		return;
	end

	local in_top = true;

	table.remove(layer.models, children[ind]);
	layer.models[dsti].parent = nil;
	layer_rebalance(layer, dsti);
end

local function layer_add(ctx, tag)
	for k,v in ipairs(ctx.layers) do
		if (v.name == tag) then
			return;
		end
	end

	local layer = {
		ctx = ctx,
		anchor = null_surface(1, 1),
		models = {},

		add_model = layer_add_model,
		add_terminal = layer_add_terminal,

		count_root = layer_count_root,
		count_children = layer_count_children,

		swap = layer_swap,
		swapv = layer_swap_vertical,
		cycle = layer_cycle,

		step = layer_step,
		zpos = layer_zpos,
		set_fixed = layer_set_fixed,
		select = layer_select,
		relayout = function(...)
			return ctx.default_layouter(...);
		end,
		destroy = layer_destroy,

		name = tag,

		dx = 0, dy = 0, dz = 0,
		radius = 0.5,
		depth = 0.1,
		vspacing = 0.2,
		spacing = 0.05,
		opacity = 1.0,
		active_scale = 1.2,
		inactive_scale = 0.8,
	};

	show_image(layer.anchor);
	table.insert(ctx.layers, layer);
	reindex_layers(ctx);
	layer:select();

	return layer;
end

local function vr_input(ctx, iotbl, multicast)
	if (not ctx.selected_layer or not ctx.selected_layer.selected) then
		return;
	end
	local dst = ctx.selected_layer.selected.external;
	if (not valid_vid(dst, TYPE_FRAMESERVER)) then
		return;
	end
	target_input(dst, iotbl);
end

return function(ctx, surf, opts)
	set_defaults(ctx, opts);

-- render to texture, so flip y, camera is also used as a resource
-- anchor for destroying everything else
	local cam = null_surface(1, 1);
	scale3d_model(cam, 1.0, -1.0, 1.0);

-- we may need to use the default 'render to world' when running
-- monoscopic in a windowed mode
	if (valid_vid(surf)) then
		define_rendertarget(surf, {cam},
			RENDERTARGET_DETACH, RENDERTARGET_NOSCALE, -1, RENDERTARGET_FULL);

-- special case, always take the left eye view on stereoscopic sources,
-- the real stereo pipe takes the right approach of course
		rendertarget_id(surf, 0);
	end

	camtag_model(cam, 0.01, 100.0, 45.0, VRESW/VRESH, true, true, 0, surf);

	local prefix = opts.prefix and opts.prefix or "";

-- actual vtable and properties
	ctx.default_layouter = system_load(prefix .. "/layouters/default.lua")();
	ctx.add_layer = layer_add;
	ctx.camera = cam;
	ctx.vr_pipe = surf;
	ctx.setup_vr = setup_vr_display;
	ctx.reindex_layers = reindex_layer;
	ctx.input_table = vr_input;
	ctx.dump = dump;
	ctx.message = function(ctx, msg) print(msg); end;

-- this is actually shared global state, should move to instance into ctx
	shader_uniform(vrshaders.rect, "curve", "f", opts.curve);
	shader_uniform(vrshaders.rect_inv, "curve", "f", opts.curve);

-- all UI is arranged into layers of models
	ctx.layers = {};
end
