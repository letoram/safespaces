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
direct access to USB device control. When you have that tool working, you will
want to tell arcan to use it for VR support:

    arcan_db add_appl_kv arcan ext_vr /path/to/arcan_vr

If you don't, it will still try to find the arcan\_vr binary in the regular bin
folders (for system- technical reasons it does not rely on PATH but rather hard
priority of usr/local/bin then usr/bin before giving up).

This tool act as our device control interface, so if there are more sensor devices
you want to add, this is where it can be done. The idea is that each vr-bridge
instance exposes a skeletal model (joints, eyes, ...) that you populate with
whatever devices you happen to have. These are advertised to the active scripts
(safespaces here) which then react accordingly by mapping to models, cameras,
gesture classifiers and other abstract objects.

## Device Profile
There is great variety in how HMD devices work, behave, and what extra controls
you might need. On top of the VR Bridge that gives us access to the devices
themselves, we then need the integration with the visual aspects of the desktop.

You can find the current profiles (or add your own) in the devices/ folder, and
they are normal .lua scripts that gets loaded immediately on startup. An example
looks like this:

    return {
        display = 'MyScreenName',
        oversample_w = 1.0,
        oversample_h = 1.0,
        distortion_model = "basic",
        display_rotate = 'cw90',
        width = 2560,
        height = 1440,
				map_hint = MAP_FLIP,
        hmdarg = "ohmd_index=0",
        bindings = [
            ["F1"] = "mouse=selected"
        ]
    }

The values herein takes precedence over whatever the VR bridge might have set,
so you can have your custom overrides here. The 'bindings' complement input
configuration with special ones you might want for a certain device only.

The key options are as follows:

display = 'pattern' : This checks for a display EDID matching the lua pattern
presented by the string rather than going for the first one available. If this
is set, setup won't progress until the correct display has been found.

display\_rotate = cw90 | ccw90 | 180 | cw90ccw90 : This specifies the base
orientation of the display.

distortion\_model = basic, none : Using the universal distortion shader from the
OpenHMD project or disable barrel distortion altogether.

headless = true | false : This mode does not expect to be mapped to a display
but rather outputs to whatever arcan happens to pick based on the video platform
in use. This is mainly for windowed like modes.

There are some special built-in profiles:

* 'desktop'    : 3D desktop only, no vr devices or stereoscopic rendering
* 'basic'      : Just draw to the default display and treat it as the VR display
* 'simulated'  : 'Headless' operation: stereo with distortion and no combiner stage

'Basic' is useful if you are trying to run arcan as a normal client with an
outer display server like Xorg or on OS X. It draws as a normal window and
you get to use whatever controls the display server provides to move it to
the HMD display.

## Configuration

WM, Input, Device Profiles, Default 'space' - all of it is set in the
config.lua file. Look at it. Especially the 'Input Controls' section with
its meta keys and its bindings as it will tell you how to shutdown, which
is quite important.

In fact, to save you from not being able to shutdown properly before knowing
the keybinding, we have made it so that when the initial terminal surface is
destroyed, by exiting from within the shell or through a keybinding, safespaces
will exit. When you feel comfortable, see the section on 'spaces' below for
instructions on how to remove that feature.

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

## Troubleshooting

Chances are that safespaces will only give you a black screen or return to the
command-line. This comes from how complex and varying the lower layer graphics
system actually works, combined with the 'display but not a normal display'
properties of the HMD itself. Some tips for getting further:

1. Start with the device=test profile and a normal monitor (no HMD connected)

Assuming no X server or worse yet, display manager, is running and that you
only work from the TTY. Make sure to pipe the arcan output to a log file as
the normal stdout text has to be disabled for graphics to work, and the log
might contain valuable clues.

    arcan safespaces device=test &> log

If you have an NVIDIA card and not AMD or Intel, chances are their driver is
still such a steaming pile that it is not worth pursuing further until they
clean up their act. We are fine with them requiring EGLStreams and binary blobs
and custom scanout paths, but if they do, at the very least these layers should
work reliably and robustly, which is far from the truth currently. As a user,
ask the developers of their unix driver for help debugging / troubleshooting.

This makes sure that the 3D pipeline, normal display scanout, etc. is working
correctly. You can also test your keys and keybindings here so it is a useful
feature to know about. If this stage is not working, the problem can be with
your kernel, graphics driver, permissions and so on. In order to switch the

2. Use the device=desktop profile and a normal monitor (no HMD connected)

This just makes sure that the 3D pipeline also works when it is uniquely
mapped to a display and not composited like with the test profile. If this does
not work, the troubleshooting is the same as with 1. A debug build of arcan
itself (cmake with -DCMAKE\_BUILD\_TYPE=Debug will produce a more verbose log,
as will starting with multiple -g arguments on the command line.

3. Try the device=basic profile with your hmd and normal monitor connected.

This will give you a stereoscopic view on your normal monitor, but it will
try to get the orientation from the HMD. Try rotating the HMD, and look on
your monitor, does the tracking work?

If not, the problem is either that arcan\_vr is not running correctly, your
HMD is not supported or your user do not have permission to access the
device. Try running arcan\_vr separately, do you get proper rotation output
there? If it does, then it is probably the case that arcan did not find the
arcan\_vr binary correctly, see if a process with that name is running.
If you do not get proper results from arcan\_vr, the problem likely lies
with OpenHMD.

Check the status with their git repository, check if you have built arcan\_vr
statically with an in-source OpenHMD or through the shared version as our
version is slightly patched.

4. Finally use the device profile for your actual HMD.

There are a few reasons why, after everything, this stage still refuses to
work. The reason being that there is a big difference between what display is
found "first" and if that is your HMD or not. The kernel driver typically
blocks VR headsets from taking this spot, but this is through a hardcoded list
in the driver itself. So for some configurations you might have success with no
screen plugged in, only your HMD. In others, plugging in your HMD after you
have started safespaces might help.

Part of the reason why this might be a problem is that some displays behave in
one way when plugged in 'as normal', then act as a 'hotplug' when the VR bridge
sends a wakeup command. Then safespaces need to pair the display being plugged
with displays that 'appear', which might not actually be the HMD in question
when you have more complicated setups.

## X, Wayland

To support running legacy applications using the X or Wayland protocols,
there are two paths. One is [Xarcan](https://github.com/letoram/xarcan)
which is a modified X server. You start it, attach a window manager and
use it as a 'contained in a surface' kind of mode.

For Wayland, there is another tool in the arcan source repository, in the
src/tools/waybridge folder, which implements the server side of the Wayland
protocol. Normally, it should simply be runnable via:

    arcan-wayland -exec my_wayland_client

You can also run X clients 'rootless' via Xwayland. You do that like this:

    arcan-wayland -xwl -exec my_x_client

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
    - [ ] GlTF2 (.bin)
      - [ ] Simple/Textured Mesh
      - [ ] Skinning/Morphing/Animation
      - [ ] Physically Based Rendering
    - [x] Stereoscopic Mapping
      - [x] Side-by-Side
      - [x] Over-and-Under
      - [x] Swap L/R Eye
      - [ ] Split (left- right sources)
 - [x] Events
      - [x] On Destroy

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

 - Static / Manual
    - [ ] Curved Plane
    - [ ] Drag 'constraint' solver (collision avoidance)
    - [ ] Draw to Spawn

- [ ] Clients
  - [x] Built-ins (terminal/external connections)
  - [ ] Launch targets
  - [x] Xarcan
  - [x] Wayland-simple (toplevel/fullscreen only)
	  - [ ] Xwayland
		- [ ] full xdg-toplevel

- [ ] Tools
  - [ ] Basic 'listview' popup
  - [x] Console
  - [ ] Button-grid / Streamdeck
	- [x] Socket- control IPC

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

