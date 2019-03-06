# API

Similarly to how configuration works in [Durden](http://durden.arcan-fe.com),
configuration, scripting and scene definitions in _Safespaces_ work via a
simple virtual filesystem, and all user actions point into this filesystem
in one way or another. All of the paths except for the "System Windows"
category are also _shared_ with the _vrviewer_ tool in Durden.

Conceptually, Safespaces is divided into one or many _spaces_ where only
one _space_ can be active at any one time. Each space have zero or many
layers.

To map to normal window management concepts, a space can be thought of as
a more radical 'workspace', and a layer as a 'tag' or group of addressable
windows.

# System Windows

     /toggle_grab : when arcan is running in windowed mode, activating
                   this path toggles mouse grab on / off which might be
                   needed in som environments.

     /shutdown : immediately kill all clients and terminate

     /mouse=
          selected : input forwarded to selected model
          view : input modifies camera orientation
          scale : input modifies focus selected model scale
          rotate : input modifies selected model orientation
					ipd : input modifies eye- distance and distortion
					      parameters, repeated calls cycles which parameter
								that is targeted

# Device Control ( /hmd )

This path has controls for dynamically tuning active HMD devices.

    /hmd/reset : resets the orientation and marks your current position
                 as the "origo / looking straight ahead" state
    /hmd/ipd=f : override the IPD setting (distance between eyes)
    /hmd/step_ipd=f : adjust the IPD relative to its current value
		/hmd/distortion=
                    none : disable distortion step
                    basic : shader based OpenHMD distortion model

# Space Control ( /space )

This path is special, and populated by globbing the spaces subdirectory
for matching profiles. To load, specify /space/spacename.lua and it will
activate.

# Layer Creation ( /layers )

Layers provide a positional anchor to which you attach and group models.
Only one layer can be selected at a time, with one model as input focus.  A
layouter determines the positioning and window management strategy for the
models attached to the layer.

    /layers/grow_shrink=f : increment or decrement the layouter spacing
    /layers/push_pull=f : move the anchor closer or further away
    /layers/add=name : create a new layer with the specified (unique) name
    /layers/layer_name : name comes from the add=name call and is a submenu
    /layers/current : refers to the currently selected layer.

# Layer Access

Each individual layer accessed through /layers/layer\_name or /layers/current
has the following possible submenus, actions and values:

    focus : set the layer as having input focus
    add_model (see Model Creation below)
    terminal : add a rectangle model tied to a new terminal group
    swap=i : swap model to the left (< 0) or to the right (> 0) into focus
    cycle=i : rotate models n steps on the left (< 0) or right (> 0) side
    destroy : delete the layer and all associated models
    opacity=f : (0..1) set the layer relative opacity, default=1 (opaque)
    nudge=f : move the layer anchor relative to the current position
    models/ : subdirectory of all attached models
    settings/ : parameters that affect layout and model attachment

# Layer Settings

    depth=f : set the distance from the anchor to the viewer
    radius=f : set the circle that windows will be positioned through
    spacing=f : set the spacing between window along the longitude
    vspacing=f : set the spacing between windows along the y axis
    active_scale=f : set the scale factor for the selected window
    inactive_scale=f : set the scale factor for the inactive windows
    fixed=b : (true | false) disable (=true) or enable autolayouting
    ignore : ignore this layer when stepping input focus

# Model Creation

These paths are relative to layers/layer\_name where name is what you
specified when adding it (e.g. /layers/add=background) would become:

    /layers/layer_background/add_model/primitive=

You can also specify them relative to the currently selected layer:

    /layers/current/add_model/primitive=

Substitute primitive with one out of:

    pointcloud, sphere, hemisphere, rectangle, cylinder, halfcylinder, cube

And a unique name in order to reference the model later, similarly to how
layers were created and referenced.

# Model Access

The model is accessed via a layer (/layers/current/ or /layers/layer\_name)
within the models subdirectory (/layers/current/models/model_n) either by
the model name /layers/current/models/name/ or relative to the current
selection via /layers/current/models/selected/

    child_swap=i
    destroy
    rotate=fff
    spin=fff
    scale=f
    opacity=f
    curvature=f
    merge_collapse
    flip=b (true | false)
    stereoscopic=
                 none, sbs, sbs-rl, oau, oau-rl
    faces/
    connpoint/
    source_inv=s
    source=s
		 set a resource path as the source texture map for the model

# Connection Points

Any model can have its contents (map) be defined dynamically via a 'connection
point' that an external client can access via ARCAN\_CONNPOINT=name. This is
activated via the model access (see above) connpoint subdirectory.

    replace=s : the connection point contents will permanently map to the model
    temporary=s : when the connection point closes, the previous map will return
    reveal=s : auto hide/show the model based on if aonyone is connected to the
		           connection point or not
    reveal_focus=s : like reveal, but automatically set input focus
