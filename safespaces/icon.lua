-- icon loading, caching and resolution management
--
-- eventually this should be generalizable to a uiprim/ script
-- as manual icon handling, covering all the bases for different
-- displays, optimizing for caching, atlas-slicing etc. is quite
-- hairy.
--
-- For now, we just do the minimal placeholder stuff needed to
-- refactor the icon/font label parts of durden, then see what
-- happens from there. The support sheet used for picking/binding
-- should also be moved from the icons widget to here.
--
-- In that direction, there are three classes of icons - labels
-- textual and client defined. The first one need to be loaded
-- and kept.
--
-- The second needs rasterization against the target display.
--
-- The third needs caching.
--
local setname = gconfig_get("icon_set");

-- it is almost always useful having a circle primitive to
-- build with, both for generating single colored round icons
-- or to use as a mask together with resample_image
icon_unit_circle = build_shader(
	nil,
	[[
		uniform float radius;
		uniform vec3 color;
		varying vec2 texco;

		void main()
		{
			float vis = length(texco * 2.0 - vec2(1.0)) - radius;
			float step = fwidth(vis);
			vis = smoothstep(step, -step, vis);
			gl_FragColor = vec4(color.rgb, vis);
		}
	]],
	"iconmgr_circle"
);

icon_colorize = build_shader(
	nil,
	[[
		uniform vec3 color;
		uniform sampler2D map_tu0;
		varying vec2 texco;

		void main()
		{
			vec4 col = texture2D(map_tu0, texco);
			float intens = max(max(col.r, col.g), col.b);
			gl_FragColor = vec4(color * intens, col.a);
		}
	]],
	"iconmgr_colorize"
);

shader_uniform(icon_unit_circle, "radius", "f", 0.5);
local function synthesize_icon(w, shader)
	local icon = alloc_surface(w, w);
	if not valid_vid(icon) then
		return;
	end
	resample_image(icon, shader, w, w);
	return icon;
end

function icon_synthesize_src(name, w, shader, argtbl)
	local fn = string.format("icons/%s/%s", setname, name);
	local img = load_image(fn);
	if not valid_vid(img) then
		return;
	end
	for k,v in pairs(argtbl) do
		shader_uniform(shader, k, unpack(v));
	end
	resample_image(img, shader, w, w);
	return img;
end

function icon_synthesize(w, shader, argtbl)
	for k,v in pairs(argtbl) do
		shader_uniform(shader, k, unpack(v));
	end
	return synthesize_icon(w, shader);
end

-- The nametable mainly contains the active caches of vids based
-- on a base width. Normally icons are square, though it is not
-- a given.
--
-- For icons where we don't need to scale but can use a function
-- to generate the icon in question, the generate function is
-- provided.
local nametable = {
};

-- take a vsym that passed validation from suppl_valid_vsym and
-- return a vid that can be used for an image_sharestorage into
-- a caller controlled allocation, as well as a possible shader
-- identifier. An open question is if we should allow SDFs. The
-- problem comes with shader used for highlights etc.
function icon_lookup(vsym, px_w)
	if not nametable[vsym] then
		vsym = "placeholder";
	end
	local ent = nametable[vsym];

-- do we have a direct match since before?
	if ent.widths[px_w] then
		return ent.widths[px_w];
	end

-- can we build one with it?
	if ent.generate then
		local res = ent.generate(px_w);
		if valid_vid(res) then
			ent.widths[px_w] = res;
			return res;
		end
	end

-- find one with the least error
	local errv = px_w;
	local closest = 0;

	for k,v in pairs(ent) do
		if type(k) == "number" then
			local dist = math.abs(px_w - k);
			if dist < errv then
				errv = dist;
				closest = k;
			end
		end
	end

-- apparently wasn't one for this specific size, fallback generator(s)?
	if errv > 0 and ent.generator then
		ent.widths[px_w] = ent.generator(px_w);
	end

-- no solution at all? return placeholder, this shouldn't infinitely
-- recurse as we always override placeholder with our own definition that
-- has a synthesis option
	if closest == 0 then
		return icon_lookup("placeholder", px_w);
	end

-- do we need to load or generate?
	local vid = ent.widths[closest];
	if not ent.widths[closest] then
		if type(ent[closest]) == "string" then
			local fn = string.format("icons/%s/%s", setname, ent[closest]);
			ent.widths[closest] = load_image(fn);

-- or provide some visual indicator that the icon reference was bad
			if (not valid_vid(ent.widths[closest])) then
				ent.widths[closest] = icon_lookup("placeholder", px_w);
			end

		elseif type(ent[closest]) == "function" then
			ent.widths[closest] = ent[closest]();
		else
-- missing handler / malformed
			warning("icon_synth:bad_type=" .. type(ent[closest]));
		end
		vid = ent.widths[closest];
	end

-- or really panic so we don't return a broken vid
	return valid_vid(vid) and vid or WORLDID;
end

-- use a unicode symbol reference (or nametable override)
-- to get an iconic or rastered representation matching the
-- intended display. The display is needed as the rendertarget
-- attachment for the datastore, as that covers the density.
local last_u8;
function icon_lookup_u8(u8, display_rt)
	if valid_vid(last_u8) then
		delete_image(last_u8);
	end

	local rt = set_context_attachment(display_rt);
	last_u8 = render_text({"\\f,0", u8});
	set_context_attachment(rt);
	if not valid_vid(last_u8) then
		return icon_lookup("placeholder", 32);
	end
	return last_u8;
end

function icon_known(vsym)
	return vsym ~= nil and #vsym > 0 and nametable[vsym] ~= nil;
end

-- the enforcement on location isn't strict here, traversal
-- protection is implemented on a much lower level so this is fine
nametable = system_load(string.format("icons/%s.lua", setname))();

-- make sure we have some standard names
if not nametable.destroy then
	nametable.destroy = {
		generate = function(w)
			return icon_synthesize(w, icon_unit_circle, {color = {"fff", 1.0, 0.1, 0.15}});
		end
	};
end

-- make sure we always have these
if not nametable.minimize then
	nametable.minimize = {
		generate = function(w)
			return icon_synthesize(w, icon_unit_circle, {color = {"fff", 0.94, 0.7, 0.01}});
		end,
		widths = {}
	};
end

if not nametable.maximize then
	nametable.maximize = {
		generate = function(w)
			return icon_synthesize(w, icon_unit_circle, {color = {"fff", 0.1, 0.6, 0.1}});
		end,
		widths = {}
	};
end

-- reserve this one for ourselves so we always have a valid fallback
nametable.placeholder = {
	generate =
	function(w)
		return icon_synthesize(w, icon_unit_circle, {color = {"fff", 1.0, 1.0, 1.0}});
	end
};

-- and safeguard so we have the width cache table
for _, v in pairs(nametable) do
	if not v.widths then
		v.widths = {};
	end
end
