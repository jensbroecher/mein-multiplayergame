extends Node

# Renders a stage's menu tile (images/menu/tile_*.jpg, 1376x768): the stage from a bit far off and at an angle, every
# tile framed the same way. Run windowed, one stage a run (scratch/render_menu_tiles.sh runs them all):
#   Godot --path . res://scratch/menu_tile_shot.tscn -- <level.tscn> <out.jpg> [key=value ...]
#
# The camera stands up at ELEV degrees over the lap's middle, as far back as the whole lap needs to fit the frame
# (with MARGIN to spare), tipped up by LIFT so the lap sits a little low and the country shows above it. Its bearing is
# the one (of every 15 degrees) that frames the lap nearest, as long as it looks across the sun's light, not into it:
# the light falls from behind or beside the camera (`sun_ok`: within SUN_MAX degrees of the way the camera looks).
# Fog is eased by how far back the camera stands, so the lap is as hazy as from a few hundred metres, not from 2km.
# The menu draws a tile cropped to about 5:3 (STRETCH_KEEP_ASPECT_COVERED), so the fit keeps clear of the sides.
#
# Overrides, per stage in STAGES (by the level's file name) or on the command line as key=value:
#   az       bearing the camera looks along, degrees (0 north/-z, 90 east/+x), instead of the search
#   sun_max  how far off the sun's direction the search may look (default SUN_MAX)
#   fog      share of the camera's distance the fog is pushed back by (default FOG_EASE; 0 leaves it)
#   elev     the camera's height angle over the framed middle, degrees
#   fov      vertical field of view, degrees
#   lift     how far the view is tipped up from the middle, as a share of half the frame's height
#   margin   share of the frame the lap may fill
#   focus    x,y,z: frame a disc round this point (with radius) instead of the whole lap
#   radius   the disc's radius, metres
#   zoom     scales the fitted distance (under 1 nearer)
#   pad      scales the room left round the lap (PAD)
#   hide     node names to hide, comma-separated (FallingSnow and DustWall always are)
#   weather  pins Northlight's blizzard, Msitu's rain or Mina's haboob (default 0: clear)
#   clock    holds the wall clock's trains, planes and boats at this many seconds into the day (Train/Airliners)

const SIZE := Vector2i(1376, 768)
const SUPERSAMPLE := 2
const MENU_ASPECT := 5.0 / 3.0
const ELEV := 30.0
const FOV := 40.0
const LIFT := 0.2
const MARGIN := 0.88
const SUN_MAX := 100.0
## Room left round the lap: this share of its size, within PAD_MIN..PAD_MAX metres.
const PAD := 0.06
const PAD_MIN := 18.0
const PAD_MAX := 70.0
## The camera's distance whose share the fog is pushed back by.
const FOG_EASE := 0.75

## Per-stage overrides, by the level's file name (without .tscn).
const STAGES := {
	# Point-to-point routes run kilometres: frame where they're busiest (Mina's pit and its ramp, Kronburg's old town).
	"MinaLevel": {"focus": "0,-20,180", "radius": 430},
	"StadtrallyeLevel": {"focus": "-420,34,-60", "radius": 640},
	"GlacierHighwayLevel": {"zoom": 0.8},
	"RamlatHamraLevel": {"zoom": 0.85},
	"FrostfallGorgeLevel": {"zoom": 0.85},
	# Tianqiao: the towers, the spiral and the mall, from the supertall down (the city fills the rest).
	"TianqiaoLevel": {"focus": "300,70,330", "radius": 330, "zoom": 0.85},
	# Panlong Interchange: the coil, the ring expressway over it.
	"PanlongLevel": {"focus": "-20,10,-20", "radius": 380},
}

var opts := {}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var level_path: String = args[0]
	var out_path: String = args[1]
	var key: String = level_path.get_file().get_basename()
	if STAGES.has(key):
		for k in STAGES[key]:
			opts[k] = STAGES[key][k]
	for a in args.slice(2):
		var eq := a.find("=")
		if eq > 0:
			opts[a.substr(0, eq)] = a.substr(eq + 1)
	AudioServer.set_bus_mute(0, true)
	var vp := SubViewport.new()
	vp.size = SIZE * SUPERSAMPLE
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var level: Node3D = load(level_path).instantiate()
	vp.add_child(level)
	MusicManager.set_shadow_quality(3, false)
	MusicManager.set_grass_setting(5, false)
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		n.visible = false
	var cam := Camera3D.new()
	cam.near = 0.5
	cam.far = 9000.0
	vp.add_child(cam)
	cam.make_current()
	for i in 4:
		await get_tree().physics_frame
	# Snow falling round the lens drew blotches across the picture; Mina's dust wall hides the plateau.
	var hide: Array = ["FallingSnow", "DustWall"]
	if opts.has("hide"):
		hide.append_array(str(opts["hide"]).split(","))
	for h in hide:
		for n in level.find_children(h, "Node3D", true, false):
			(n as Node3D).visible = false
	var w := float(_opt("weather", 0.0))
	for wname in ["NorthlightWeather", "JungleRain", "HaboobWeather"]:
		var wn := level.get_node_or_null(wname)
		if wn:
			wn.force_intensity = w

	var pts := _frame_points(level)
	var sun := _sun(level)
	var fall := Vector3.FORWARD
	if sun:
		fall = -sun.global_basis.z
	var fall_bearing := atan2(fall.x, -fall.z)
	var elev := deg_to_rad(float(_opt("elev", ELEV)))
	cam.fov = float(_opt("fov", FOV))
	var lift := float(_opt("lift", LIFT))
	var margin := float(_opt("margin", MARGIN))
	var tv := tan(deg_to_rad(cam.fov) * 0.5)
	# The menu's crop takes the sides off: fit inside the 5:3 the tile shows.
	var th_shown := tv * MENU_ASPECT
	var bearings: Array = []
	if opts.has("az"):
		bearings.append(deg_to_rad(float(opts["az"])))
	else:
		var sun_max := deg_to_rad(float(_opt("sun_max", SUN_MAX)))
		for i in 24:
			var b := TAU * float(i) / 24.0
			if absf(angle_difference(b, fall_bearing)) <= sun_max:
				bearings.append(b)
	var best := {}
	for b in bearings:
		var framed := _frame(pts, b, elev, lift, tv, th_shown * margin, tv * margin)
		if best.is_empty() or framed["dist"] < best["dist"]:
			best = framed
	var bearing: float = best["bearing"]
	var hdir: Vector3 = best["hdir"]
	var centre: Vector3 = best["centre"]
	var dist: float = best["dist"]
	dist *= float(_opt("zoom", 1.0))
	var view := _view(centre, hdir, elev, lift, dist, tv)
	cam.global_transform = view
	# Shadows reach across the whole view (a race camera's 200-400m left the far lap unshaded).
	if sun:
		sun.directional_shadow_max_distance = maxf(sun.directional_shadow_max_distance, dist * 2.2)
	_ease_fog(level, dist * float(_opt("fog", FOG_EASE)))
	if opts.has("clock"):
		var c := float(opts["clock"])
		for n in level.find_children("*", "Node", true, false):
			if "clock_override" in n:
				n.clock_override = c
	print("TILE %s bearing=%.0f elev=%.0f dist=%.0f centre=%s cam=%s" % [key, rad_to_deg(bearing), rad_to_deg(elev), dist, centre, view.origin])
	# Shaders for the far meshes compile in the background and draw nothing until they're ready.
	for i in 150:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
	var err := img.save_png(out_path) if out_path.ends_with(".png") else img.save_jpg(out_path, 0.93)
	if err != OK:
		push_error("SCRIPT ERROR: could not save %s (%s)" % [out_path, error_string(err)])
	else:
		print("SAVED ", out_path)
	get_tree().quit()


## Frames the lap from bearing `b`: the distance it needs and the middle the camera looks at, centred across the frame.
func _frame(pts: Array, b: float, elev: float, lift: float, tv: float, tx: float, ty: float) -> Dictionary:
	var hdir := Vector3(sin(b), 0.0, -cos(b))
	var centre := Vector3.ZERO
	for p in pts:
		centre += p
	centre /= float(pts.size())
	var dist := 100.0
	for it in 5:
		dist = _fit(pts, centre, hdir, elev, lift, tv, tx, ty)
		var view := _view(centre, hdir, elev, lift, dist, tv)
		var inv := view.affine_inverse()
		var lo := INF
		var hi := -INF
		for p in pts:
			var v: Vector3 = inv * p
			var x := v.x / -v.z
			lo = minf(lo, x)
			hi = maxf(hi, x)
		centre += view.basis.x * (lo + hi) * 0.5 * (centre - view.origin).length()
	dist = _fit(pts, centre, hdir, elev, lift, tv, tx, ty)
	return {"bearing": b, "hdir": hdir, "centre": centre, "dist": dist}


## Pushes the stage's depth fog back by `push` metres (or thins exponential fog to match), so the lap seen from far off
## is no hazier than from nearby.
func _ease_fog(level: Node, push: float) -> void:
	if push <= 0.0:
		return
	for n in level.find_children("*", "WorldEnvironment", true, false):
		var env: Environment = (n as WorldEnvironment).environment
		if env == null or not env.fog_enabled:
			continue
		if env.fog_mode == Environment.FOG_MODE_DEPTH:
			env.fog_depth_begin += push
			env.fog_depth_end += push
		else:
			env.fog_density *= clampf(400.0 / (400.0 + push), 0.1, 1.0)
	# JungleRain and HaboobWeather set the fog every frame from what they read at load.
	for n in level.find_children("*", "Node", true, false):
		if "_fog_begin" in n and "_fog_end" in n:
			n._fog_begin += push
			n._fog_end += push


func _opt(k: String, def):
	return opts[k] if opts.has(k) else def


## What the tile frames: the lap (and its shortcuts), or a disc round `focus`.
func _frame_points(level: Node) -> Array:
	var pts: Array = []
	if opts.has("focus"):
		var f: PackedStringArray = str(opts["focus"]).split(",")
		var c := Vector3(float(f[0]), float(f[1]), float(f[2]))
		var r := float(_opt("radius", 200.0))
		for i in 32:
			var a := TAU * float(i) / 32.0
			pts.append(c + Vector3(cos(a) * r, 0.0, sin(a) * r))
		return pts
	var paths: Array = []
	var tp := level.find_child("TrackPath", true, false)
	if tp:
		paths.append(tp)
	var alts := level.get_node_or_null("AlternativePaths")
	if alts:
		for c in alts.get_children():
			if c is Path3D:
				paths.append(c)
	for p in paths:
		var path := p as Path3D
		var baked: PackedVector3Array = path.curve.get_baked_points()
		var step: int = maxi(1, baked.size() / 400)
		for i in range(0, baked.size(), step):
			pts.append(path.global_transform * baked[i])
	# Room round the lap for what stands beside it (stands, buildings, the loop): PAD of the lap's size.
	var box := AABB(pts[0], Vector3.ZERO)
	for q in pts:
		box = box.expand(q)
	var pad := clampf(maxf(box.size.x, box.size.z) * PAD, PAD_MIN, PAD_MAX) * float(_opt("pad", 1.0))
	var padded: Array = []
	for q in pts:
		for o in [Vector3(pad, 0, 0), Vector3(-pad, 0, 0), Vector3(0, 0, pad), Vector3(0, 0, -pad)]:
			padded.append(q + o)
	return padded


## The stage's sun (or moon): the shadowed directional light, else the brightest.
func _sun(level: Node) -> DirectionalLight3D:
	var best: DirectionalLight3D = null
	for n in level.find_children("*", "DirectionalLight3D", true, false):
		var d := n as DirectionalLight3D
		if not d.visible:
			continue
		if best == null or (d.shadow_enabled and not best.shadow_enabled) or (d.shadow_enabled == best.shadow_enabled and d.light_energy > best.light_energy):
			best = d
	return best


## The camera `dist` back from `centre` at `elev` over it along `hdir`, tipped up by `lift` of half the frame's height.
func _view(centre: Vector3, hdir: Vector3, elev: float, lift: float, dist: float, tv: float) -> Transform3D:
	var pos := centre - hdir * cos(elev) * dist + Vector3.UP * sin(elev) * dist
	var t := Transform3D(Basis(), pos).looking_at(centre, Vector3.UP)
	var tip := atan(lift * tv)
	t.basis = t.basis.rotated(t.basis.x, tip)
	return t


## The nearest distance at which every point lies inside the frame (half extents `tx`, `ty` in tangent units).
func _fit(pts: Array, centre: Vector3, hdir: Vector3, elev: float, lift: float, tv: float, tx: float, ty: float) -> float:
	var lo := 5.0
	var hi := 40000.0
	for i in 40:
		var mid := sqrt(lo * hi)
		var view := _view(centre, hdir, elev, lift, mid, tv)
		var inv := view.affine_inverse()
		var ok := true
		for p in pts:
			var v: Vector3 = inv * p
			if v.z > -1.0:
				ok = false
				break
			var x := v.x / -v.z
			var y := v.y / -v.z
			if absf(x) > tx or absf(y) > ty:
				ok = false
				break
		if ok:
			hi = mid
		else:
			lo = mid
	return hi
