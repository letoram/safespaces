This will soon be completed with the real API documentation,
for now, dig through vrmenus.lua and ssmenus.lua for the raw
definition.

Keybindings, device configuration, workspace definitions etc.
all follow the same file-system like structure, known from
Durden and so on.

Add a layer:
    "layers/add=mylayer"

Then modify its settings:
    "layers/layer_bg/settings/depth=50.0",
    "layers/layer_bg/settings/radius=50.0",
    "layers/layer_bg/settings/fixed=true",
    "layers/layer_bg/settings/ignore=true"

Adding a cube model in the background layer with individually
textured faces:

    "layers/layer_bg/add_model/cube=bg",
    "layers/layer_bg/models/bg/faces/1/source=box/0.png", -- +x
    "layers/layer_bg/models/bg/faces/2/source=box/1.png", -- -x
    "layers/layer_bg/models/bg/faces/3/source=box/2.png", -- +y
    "layers/layer_bg/models/bg/faces/4/source=box/3.png", -- -y
    "layers/layer_bg/models/bg/faces/5/source=box/4.png", -- +z
    "layers/layer_bg/models/bg/faces/6/source=box/5.png", -- -z

Adding a foreground layer where we do our work:

		"layers/add=fg",
    "layers/layer_fg/settings/active_scale=3",
    "layers/layer_fg/settings/inactive_scale=1",
    "layers/layer_fg/settings/depth=2.0",
    "layers/layer_fg/settings/radius=10.0",
    "layers/layer_fg/settings/spacing=0.0",
    "layers/layer_fg/settings/vspacing=0.1",

Spawn a terminal:

    "layers/layer_fg/terminal",

Set it to focus:

		"layers/layer_fg/focus"

A hidden model that only gets activated and swapped into focus on
connect/disconnect and uses side by side stereoscopic separation

    "layers/layer_fg/add_model/rectangle=sbsvid",
    "layers/layer_fg/models/sbsvid/connpoint/reveal=sbsvid",
    "layers/layer_fg/models/sbsvid/stereoscopic=sbs"
