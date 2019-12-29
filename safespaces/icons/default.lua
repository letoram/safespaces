-- icon set definition format
--
-- indexed by unique identifier, referenced with icon_ prefix
-- search path is prefixed icons/setname (same as lua file)
--
-- source to the synthesizers and builtin shaders are in icon.lua
--
-- 1. static image:
-- ["myicon"] = {
-- [24] = "myicon_24px.png",
-- [16] = "myicon_16px.png"
-- }
--
-- 2. postprocessed (custom color, SDFs, ...)
-- ["myicon"] = {
-- [24] = function()
--	return icon_synthesize_src("myicon_24px.png", 24,
--	   icon_colorize, {color = {"fff", 1.0, 0.0, 0.0}});
-- end
-- }
--
-- 3. synthesized
-- ["myicon"] = {
--   generator =
--   function(px)
--    return icon_synthesize(px,
--    	icon_unit_circle, {radius = {"f", 0.5}, color = {"fff", 1.0, 0.0, 0.0}})
--   end
-- }
--
-- and they can be mixed, i.e. if there is no direct match for a certain px size,
-- the generator will be invoked. This is to allow both a SDF based vector synth
-- as well as hand drawn overrides
--
return {
["cli"] =
{
	[24] = function()
		return icon_synthesize_src("cli_24px.png", 24,
			icon_colorize, {color = {"fff", 0.0, 1.0, 1.0}});
	end,
}
};
