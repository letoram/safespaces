return {
"layers/add=bg",

-- wallpaper layer
"layers/layer_bg/settings/depth=40.0",
"layers/layer_bg/settings/fixed=false",
"layers/layer_bg/settings/ignore=false",
"layers/layer_bg/add_model/halfcylinder=bg",
"layers/layer_bg/models/bg/flip=true",
"layers/layer_bg/models/bg/source=wallpapers/180sbs/tracks.jpg",
"layers/layer_bg/models/bg/connpoint/temporary=video",
"layers/layer_bg/models/bg/spin=0 0 -180",
"layers/layer_bg/models/bg/stereoscopic=sbs",
--"layers/layer_bg/models/bg/curvature=0",

-- an interactive foreground layer with a transparent terminal
"layers/add=fg",
"layers/layer_fg/settings/active_scale=3",
"layers/layer_fg/settings/inactive_scale=1",
"layers/layer_fg/settings/depth=2.0",
"layers/layer_fg/settings/radius=10.0",
"layers/layer_fg/settings/spacing=0.0",
"layers/layer_fg/settings/vspacing=0.1",
"layers/layer_fg/terminal=bgalpha=128",
"layers/layer_fg/focus"
};
