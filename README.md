# Safespaces
This is the development / prototyping environment for 'Safespaces', a 3D/VR
desktop environment for the Arcan display server.

Note that this is a highly experimental young project. Prolonged use is quite
likely unhealthy in a number of ways, eye strain guaranteed while debugging.
Tread carefully and try with non-VR device profiles first. Keep a vomit-bucket
nearby.

# Contact
The project and related development is discussed in the #arcan IRC channel on
the freenode IRC network. Some of the development here is also done within the
related project [durden](http://durden.arcan-fe.com) as part of the 'VRviewer'
tool. Most of the codebase here is actually shared with that tool.

# Getting Started
You need a working build / installation of [Arcan](https://github.com/letoram/arcan)
so follow those instructions first. then read the following sections carefully.

## VR Bridge (device support)
Arcan does not enable VR device support by default, so you need to build the
'arcan_vr' tool that is in the main arcan source repository as 'src/tools/vrbridge'.
You should also be able to run that tool from the command-line to test the rotation
tracking and control of your head mounted display (HMD).

This usually requires some kind of adjustments to permissions, as it requires
direct access to USB device control. When you have that tool working, you need
to tell arcan to use it for VR support:

    arcan_db add_appl_kv arcan ext_vr /path/to/arcan_vr

This tool act as our device control interface, so if there are more sensor devices
you want to add, this is where it can be done. The idea is that each vr-bridge
instance exposes a skeletal model (joints, eyes, ...) that you populate with
whatever devices you happen to have. These are advertised to the active scripts
(safespaces here) which then determine react accordingly by mapping to models,
cameras, gesture classifiers and other abstract objects.

## Device Profile
There is great variety in how HMD devices work, behave, and what extra controls
you might need. On top of the VR Bridge that gives us access to the devices
themselves, we then need the integration with the visual aspects of the desktop.

You can find the current profiles (or add your own) in the devices/ folder, and
they are normal .lua scripts that gets loaded immediately on startup. An example
looks like this:

    return {
        display = 'MyScreenName',
        prelaunch = true,
        oversample_w = 1.0,
        oversample_h = 1.0,
        distortion_model = "basic",
        display_rotate = 'cw90',
        width = 2560,
        height = 1440,
        hmdarg = "ohmd_index=-1",
        bindings = [
            ["F1"] = "mouse=selected"
        ]
    }

The values herein takes precedence over whatever the VR bridge might have set,
so you can have your custom overrides here. The 'bindings' complement input
configuration with special ones you might want for a certain device only.

For all the options, see devices/README.md

Some properties are extra important, such as 'display' - the profile will only
ever get activated when a display with that specific name (can be a lua pattern)
gets detected.

There are some special built-in profiles:

* 'desktop'    : 3D desktop only, no vr devices or stereoscopic rendering
* 'basic'      : Just draw to the default display
* 'headless'   : Stereoscopic rendering, no VR devices

'Basic' is useful if you are trying to run arcan as a normal client with an
outer display server like Xorg or on OS X. It draws as a normal window and
you get to use whatever controls the display server provides to move it to
the HMD display.

## Configuration

WM, Input, Device Profiles, Default 'space' - all of it is set in the
config.lua file. Look at it. Especially the 'Input Controls' section with
its meta keys and its bindings as it will tell you how to shutdown, which
is quite important.

The binding format is simply:

    ["modifiers_SYMBOL"] = "api/path"

and the API paths are how everything in safespaces is controlled. Everything
is organised like a filesystem, and the API.md file describes how these
filesystem paths are generated.

## Spaces

The next thing to consider is a 'space'. These are simply collections of
paths that gets started synchronously in one batch, and is basically your
current environment/scene preset.

The default space gives you a skybox and a terminal in the middle. *This
terminal is configured so that if you destroy or exit it, safespaces itself
will shut down*. This is a safety measure to save you if the keybindings
are broken or you do not know how to exit.

To remove that feature, edit the default space and remove the:

    layers/current/terminal/models/selected/events/on_destroy=shutdown

line.

## Starting

Now that the basic concept sare introduced and you should know where to go
for modifying your controls, device and setting up your first space.

    arcan ./safespaces

Or

    arcan /path/to/safespaces-git/safespaces

Depending on where it is located. Some values in your config.lua can be
overridden on the commandline, particularly the space and the device.
You can do this by adding them last on the list of arguments, like this:

    arcan ./safespaces space=myspace device=vive

# Clients

Now you might just want to run more things than terminal. To do that,
you will want to understand 'connection points'. These are basically things
in the vr environment that listens for external connections under some name.

The terminal emulator happens to set one up for you, so anything started
from the terminal emulator will be spawned as a new rectangle child to the
terminal itself.

Underneath the surface, a client built using the arcan client APIs look
for the environment:

    ARCAN_CONNPATH=name

This is used heavily here to let the desktop understand what is going on
based on where a client connects to. As an example, the default space has
a 'show on activation' connection point:

    ARCAN_CONNPATH=moviescreen afsrv_terminal

Would activate this hidden screen and spawn a terminal there. There are some
clients that come with arcan and there are some opt-in tools you can build
yourself.

## Built-in

With an arcan build comes support for three clients that are interesting
here, terminal, libretro-loader and video decoder (built on VLC). These
are prefixed with afsrv\_ (terminal, game, decode). To run a
[libretro](https://www.libretro.com) core for instance:

    ARCAN_ARG=core=/path/to/core.so:resource=/path/to/gamedata afsrv_game

or indeed direct it to the moviescreen connection point as shown before.

    ARCAN_CONNPATH=moviescreen ARCAN_ARG=file=myfile.mkv afsrv_decode

should give you some movieplayback.

## Supportive

In the arcan source repository, there is 'aloadimage', which is a simple
image loader that also has support for stereoscopic sources:

    aloadimage --vr l:left_eye.png r:right_eye.png

The source for this tool can be found in src/tools/aloadimage, and should
work as a template for writing your own arcan/safespaces compliant VR
clients.

## X, Wayland

To support running legacy applications using the X or Wayland protocols,
there are two paths. One is [Xarcan](https://github.com/letoram/xarcan)
which is a modified X server. You start it, attach a window manager and
use it as a 'contained in a surface' kind of mode.

For Wayland, there is another tool in the arcan source repository, in the
src/tools/waybridge folder, which implements the server side of the Wayland
protocol. Normally, it should simply be runnable via:

    arcan-wayland -exec my_wayland_client

## Roadmap

There is a long road ahead of us to make sure that Safespaces is the definitive
desktop for productive work in the VR/AR/MR space. Here follows a checklist
of some of those steps:

Milestone 1:

- [ ] Devices
  - [x] Simulated (3D-SBS)
  - [x] Simple (Monoscopic 3D)
  - [x] Single HMD
  - [ ] Distortion Model
    - [p] Shader Based
    - [ ] Mesh Based
    - [ ] Validation
  - [x] Mouse
  - [x] Keyboard
	- [ ] Front-Camera composition

- [ ] Models
  - [x] Primitives
    - [ ] Cube
      - [x] Basic mesh
      - [x] 1 map per face
      - [ ] cubemapping
    - [x] Sphere
      - [x] Basic mesh
      - [x] Hemisphere
    - [x] Cylinder
      - [x] Basic mesh
      - [x] half-cylinder
    - [x] Rectangle
		  - [ ] Border/Background
		- [x] Custom Mesh (.ctm)
    - [ ] GlTF2
      - [ ] Simple/Textured Mesh
      - [ ] Skinning/Morphing/Animation
      - [ ] Physically Based Rendering
    - [x] Stereoscopic Mapping
      - [x] Side-by-Side
      - [x] Over-and-Under
      - [x] Swap L/R Eye
			- [ ] Split (left- right sources)
 - [ ] Events
      - [ ] On Destroy

- [x] Layouters
  - Tiling / Auto
    - [x] Circular Layers
    - [x] Swap left / right
    - [x] Cycle left / right
    - [x] Transforms (spin, nudge, scale)
    - [x] Curved Planes
    - [x] Billboarding
    - [x] Fixed "infinite" Layers
    - [x] Vertical hierarchies
    - [x] Connection- activated models

 - Staatic / Manual
		- [ ] Curved Plane
    - [ ] Drag 'constraint' solver (collision avoidance)
    - [ ] Draw to Spawn

- [ ] Clients
  - [x] Built-ins (terminal/external connections)
	- [ ] Launch targets
  - [x] Xarcan
  - [x] Wayland-simple (toplevel/fullscreen only)

- [ ] Tools
  - [ ] Basic 'listview' popup

Milestone 2:

- [ ] Advanced Layouters
  - [ ] Room Scale
  - [ ] Portals / Space Switching

- [ ] Improved Rendering
  - [ ] Equi-Angular Cubemaps
  - [ ] Stencil-masked Composition
  - [ ] Surface- projected mouse cursor

- [ ] Devices
  - [ ] Gloves
  - [ ] Eye Tracker
  - [ ] Video Capture Analysis
  - [ ] Positional Tracking / Tools
  - [ ] Dedicated Handover/Leasing
  - [ ] Reprojection
	- [ ] Mouse
	  - [ ] Gesture Detection
		- [ ] Sensitivity Controls
	- [ ] Keyboard
	  - [ ] Repeat rate controls
		- [ ] Runtime keymap switching
  - [ ] Multiple- HMDs
    - [ ] Passive
    - [ ] Active

- [ ] Clients
  - [ ] Full Wayland-XDG
    - [ ] Custom cursors
    - [ ] Multiple toplevels
    - [ ] Popups
    - [ ] Positioners
  - [ ] Full LWA (3D and subsegments)
    - [ ] Native Nested 3D Clients
    - [ ] Adoption (Crash Recovery, WM swapping)
    - [ ] Clipboard support

- [ ] Convenience
  - [ ] Streaming / Recording

Milestone 3:

- [ ] Devices
  - [ ] Haptics
  - [ ] Multiple, Concurrent HMDs
  - [ ] Advanced Gesture Detection
  - [ ] Kinematics Predictive Sensor Fusion

- [ ] Networking
  - [ ] Share Space
	- [ ] Dynamic Resource Streaming
	- [ ] Avatar Synthesis
	- [ ] Filtered sensor state to avatar mapping
	- [ ] Voice Chat

- [ ] Clients
  - [ ] Alternate Representations
  - [ ] Dynamic LoD

- [ ] Rendering
  - [ ] Culling
  - [ ] Physics / Collision Response
  - [ ] Multi-Channel Signed Distance Fields

