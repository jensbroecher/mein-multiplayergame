extends Node
## Dresses the Lakeside Course (res://levels/LakesideLevel.tscn, the Bloombay GP's first stage) as an RC race
## meeting: the paddock, race control, the camera and lap towers, catch fences hung with sponsor
## boards, tyre walls and hay round the first corner, the grandstand across it, a campsite on the
## hill, and the big orange kicker after the long bridge. Run headless:
##   Godot --headless --path . res://regenerate_lakeside.tscn [-- rebake]
##
## The level's terrain, road and grass are TerrainGenerator's (generate_world). This script grades
## flat pads for the paddock, the grandstand and the campsite into it (TerrainGenerator.flat_pads)
## and mows the verges and the venue (grass_clearings), and re-bakes the world only when those
## change (or with `rebake`): a bake takes several minutes. Everything else it builds lives under
## LakesideDressing, which it replaces on every run.
##
## People-sized things (gazebos, furniture, barriers, the booth, vehicles, tyres) are laid out at life
## size and built PROP_SCALE (1.6) times larger, like Bloombay's seafront: at life size a person
## would be shorter than a cart. Names keep clear of the words PlayerCart counts as road ("track",
## "road", "ramp", "bridge", "deck", "jump", "curb", "pier", "gate", "loop", "checkpoint") except
## the kicker's deck, which is meant to be driven on, and of Level.gd's trimesh-baking parents
## ("Props", "Environment", "Obstacles", "Buildings", "Vegetation").

const PropKit = preload("res://PropKit.gd")
const Woodland = preload("res://WoodlandBuilder.gd")
const CampKit = preload("res://CampKit.gd")
const LEVEL_PATH := "res://levels/LakesideLevel.tscn"
const RES_PREFIX := "lakeside_"
const DRESSING := "LakesideDressing"
const PROP_SCALE := 1.6
const ROAD_HALF := 7.5
## The curb's outer edge (TerrainGenerator.curb_outer_width / 2).
const VERGE := 8.0
## Terrain grid, as TerrainGenerator builds it for this level (terrain_size 2000, resolution 1000).
const GRID_RES := 1000
const GRID_START := -1000.0
const GRID_STEP := 2.0

# --- The venue, in road coordinates: s (metres along the TrackPath) and lateral (right of travel +).
## The start straight runs north from the grid (s ~3200) to the first corner at s = 0 (the origin,
## a sharp right-hander with the lake outside it); the east leg leaves it at 67 degrees.
const S_GANTRY := 3209.0
const BOOTH := Vector2(3216.0, -11.3)
const CAMERA_TOWER := Vector2(3229.0, -10.9)
const LAP_TOWER_CORNER := Vector2(3302.0, -15.5)
const LAP_TOWER_STRAIGHT := Vector2(3238.0, 15.6)
## Paddock: gazebos along the straight's left side, past the gantry.
const PADDOCK_S := Vector2(3222.0, 3292.0)
const PADDOCK_LAT := Vector2(-43.0, -21.0)
const BARRIER_LAT := -12.6
const FENCE_LAT := 11.8
const TYRE_LAT := 9.45
## Grandstand: across the first corner, north of the east leg.
const STAND_S := Vector2(36.0, 74.0)
const STAND_FRONT_LAT := -17.5
## The campsite terraces on the hill east of the straight (world x, z), half sizes, yaw.
const CAMP_TERRACE := [Vector2(62.0, 68.0), Vector2(17.0, 13.0), -1.45]
const CAMP_UPPER := [Vector2(59.0, 33.0), Vector2(9.0, 8.0), -1.3]

# --- The kicker that replaces the old orange curl (Ramps/NewRamp) after the long bridge.
const KICKER_S0 := 2012.4
const KICKER_ANGLE := 0.4363   # 25 degrees at the lip
const KICKER_ARC_H := 8.2      # height where the transition reaches the lip angle
const KICKER_LIP := 2.4        # straight run at the lip angle, along the slope
const KICKER_HALF_W := 4.8

## Sponsors for StadiumAds (fictional): [name, line, background, text, accent, layout].
const ADS := [
	["RC VIBE", "GRAND PRIX", Color(0.06, 0.10, 0.22), Color(1, 1, 1), Color(0.98, 0.55, 0.10), 0],
	["SPEED", "HOBBY & MODEL SHOP", Color(0.98, 0.80, 0.12), Color(0.08, 0.08, 0.10), Color(0.85, 0.15, 0.12), 2],
	["TURBO", "LIPO BATTERIES", Color(0.14, 0.08, 0.24), Color(1, 1, 1), Color(0.95, 0.20, 0.25), 1],
	["BLOOMBAY GP", "LAKESIDE COURSE", Color(0.05, 0.45, 0.55), Color(1, 1, 1), Color(0.98, 0.80, 0.20), 0],
	["RC VIBE", "", Color(0.97, 0.97, 0.95), Color(0.16, 0.55, 0.92), Color(0.95, 0.30, 0.55), 3],
	["GRIPMAX", "RACING TYRES", Color(0.07, 0.07, 0.08), Color(0.98, 0.80, 0.12), Color(0.70, 0.70, 0.70), 0],
	["NITRO FIZZ", "ICE COLD LEMONADE", Color(0.80, 0.10, 0.12), Color(1, 1, 1), Color(0.98, 0.82, 0.20), 1],
	["SERVO PRO", "PRECISION PARTS", Color(0.90, 0.91, 0.92), Color(0.08, 0.18, 0.42), Color(0.95, 0.45, 0.10), 2],
	["LAKESIDE FM", "97.4  THE VIBE", Color(0.25, 0.62, 0.92), Color(1, 1, 1), Color(0.98, 0.40, 0.60), 1],
	["HOBBY HANGAR", "KITS  PARTS  PAINT", Color(0.95, 0.45, 0.08), Color(1, 1, 1), Color(0.06, 0.14, 0.32), 0],
	["SPARK RADIO", "2.4 GHZ CONTROL", Color(0.06, 0.32, 0.18), Color(1, 1, 1), Color(0.65, 0.95, 0.25), 2],
	["ALPENHOF", "FRESH FROM THE FARM", Color(1, 1, 1), Color(0.10, 0.35, 0.70), Color(0.85, 0.15, 0.15), 1],
	["PEAK OIL", "SHOCK & DIFF FLUID", Color(0.95, 0.72, 0.15), Color(0.08, 0.08, 0.08), Color(0.78, 0.12, 0.10), 0],
	["VOLTCELL", "", Color(0.08, 0.10, 0.08), Color(0.55, 0.85, 0.20), Color(0.05, 0.55, 0.30), 3],
	["QUICKBITE", "BURGERS & FRIES", Color(0.88, 0.30, 0.10), Color(0.99, 0.88, 0.30), Color(1, 1, 1), 1],
	["ZOOM CAM", "ACTION CAMERAS", Color(0.10, 0.10, 0.12), Color(1, 1, 1), Color(0.20, 0.80, 0.95), 2],
]
## The order boards take their adverts in along a run: the concept's RC VIBE / SPEED / TURBO lead.
const AD_CYCLE := [0, 1, 2, 4, 5, 3, 6, 0, 1, 7, 2, 8, 9, 4, 10, 11, 0, 12, 13, 14, 1, 15, 2]

const WHITE := CampKit.WHITE
const GALV := CampKit.GALV
const STEEL := Color(0.22, 0.23, 0.25)
const KICKER_ORANGE := Color(0.96, 0.46, 0.10)

var _level: Node3D
var _tg: Node3D
var _curve: Curve3D
var _length := 0.0
var _road_y := 0.4
var _kit: PropKit
var _camp: CampKit
var _heights := PackedFloat32Array()
var _materials := {}
var _footprints: Array = []   # [name, centre Vector2, radius, clearance]
var _ad_k := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	print("=== Lakeside Course dressing ===")
	var t0 := Time.get_ticks_msec()
	_kit = PropKit.new()
	_kit.material_for = _material
	_camp = CampKit.new(_kit)
	_level = (load(LEVEL_PATH) as PackedScene).instantiate()
	add_child(_level)
	_tg = _level.get_node("TerrainGenerator")
	_curve = (_level.get_node("TrackPath") as Path3D).curve
	_length = _curve.get_baked_length()
	_road_y = float(_tg.get("road_y_offset"))
	var old := _level.get_node_or_null(DRESSING)
	if old:
		_level.remove_child(old)
		old.free()

	# 1. Grading. Pad heights come from the natural ground, so they're the same on every run.
	_tg.set("flat_pads", PackedFloat32Array())
	var pads := _plan_pads()
	var clearings := _plan_clearings()
	var saved_pads: PackedFloat32Array = _level.get_node("TerrainGenerator").get_meta(&"baked_pads", PackedFloat32Array())
	var saved_clear: PackedFloat32Array = _level.get_node("TerrainGenerator").get_meta(&"baked_clearings", PackedFloat32Array())
	_tg.set("flat_pads", pads)
	_tg.set("grass_clearings", clearings)
	var rebake: bool = "rebake" in OS.get_cmdline_user_args() or pads != saved_pads or clearings != saved_clear \
			or not FileAccess.file_exists("res://generated/terrain_visual.res")
	if rebake:
		print("  re-baking the terrain, road and grass (%d pads, %d clearings)..." % [pads.size() / 7, clearings.size() / 6])
		_tg.call("generate_world")
		_tg.set_meta(&"baked_pads", pads)
		_tg.set_meta(&"baked_clearings", clearings)
		_heights = (_tg.get("_visual_heights") as PackedFloat32Array).duplicate()
		print("  baked (%.0fs)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	else:
		_heights = _load_heights()
		print("  terrain unchanged, kept the baked world")

	# 2. The dressing.
	var root := Node3D.new()
	root.name = DRESSING
	_level.add_child(root)
	_rng.seed = 7311
	_build_kicker(root)
	_build_paddock(root)
	_build_race_control(root)
	_build_camera_tower(root)
	_build_lap_towers(root)
	_build_fences(root)
	_build_barriers(root)
	_build_tyre_walls(root)
	_build_hay_and_cones(root)
	_build_grandstand(root)
	_build_campsite(root)
	_move_old_props()
	_build_woodland(root)
	_build_boulders(root)
	_build_ads(root)
	_verify_clear()

	# 3. The concept's fair-weather sky.
	_build_sky()

	# 4. Save.
	_set_owner_recursive(_level, _level)
	remove_child(_level)
	var packed := PackedScene.new()
	var err := packed.pack(_level)
	if err != OK:
		push_error("Failed to pack LakesideLevel.tscn: %d" % err)
	else:
		err = ResourceSaver.save(packed, LEVEL_PATH)
		if err != OK:
			push_error("Failed to save LakesideLevel.tscn: %d" % err)
		else:
			print("Saved %s (%.0fs)" % [LEVEL_PATH, (Time.get_ticks_msec() - t0) / 1000.0])
	_level.free()
	get_tree().quit()


# ======================================================================================
#  Sky and sun
# ======================================================================================

const HAZE := Color(0.72, 0.80, 0.88)

## A summer sky over the lake: deep blue overhead, fair-weather cumulus, a light haze on the far
## hills, and the sun from the south-west, so the run from the grid to the first corner is lit from
## behind the cars. It replaces the shared weather system (GodotWeatherSystem), whose fog washed the
## sky out; the sky shader is Msitu Falls' static cumulus (no TIME, see CLAUDE.md).
func _build_sky() -> void:
	for n in ["WeatherController", "WorldEnvironment", "SunLight"]:
		var old := _level.get_node_or_null(n)
		if old:
			_level.remove_child(old)
			old.free()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://sky_tropical_cumulus.gdshader")
	sm.set_shader_parameter("sky_top", Color(0.17, 0.41, 0.82))
	sm.set_shader_parameter("sky_horizon", Color(0.70, 0.82, 0.93))
	sm.set_shader_parameter("ground_horizon", HAZE)
	sm.set_shader_parameter("ground_bottom", Color(0.34, 0.42, 0.38))
	sm.set_shader_parameter("sky_curve", 0.32)
	sm.set_shader_parameter("horizon_haze", HAZE)
	sm.set_shader_parameter("haze_strength", 0.7)
	sm.set_shader_parameter("haze_height", 0.16)
	sm.set_shader_parameter("sun_tint", Color(1.0, 0.95, 0.84))
	sm.set_shader_parameter("sun_disc_degrees", 1.0)
	sm.set_shader_parameter("sun_glow", 0.5)
	sm.set_shader_parameter("cloud_lit", Color(1.0, 0.99, 0.96))
	sm.set_shader_parameter("cloud_shade", Color(0.52, 0.60, 0.72))
	sm.set_shader_parameter("cloud_coverage", 0.36)
	sm.set_shader_parameter("cloud_opacity", 0.95)
	sm.set_shader_parameter("cloud_scale", 1.9)
	sm.set_shader_parameter("wind_dir", Vector2(0.82, 0.57))
	sm.set_shader_parameter("cloud_seed", 27.9)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_bloom = 0.06
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = HAZE
	env.fog_sun_scatter = 0.2
	env.fog_density = 1.0
	env.fog_depth_begin = 220.0
	env.fog_depth_end = 1600.0
	env.fog_depth_curve = 1.2
	env.fog_sky_affect = 0.05
	env.fog_aerial_perspective = 0.3
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	_level.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = Vector3(-50.0, -45.0, 0.0)
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220.0
	_level.add_child(sun)
	# The ground fades into the haze at the map's edge in the same colour.
	var tv := _level.get_node_or_null("TerrainGenerator/Terrain_Visual") as MeshInstance3D
	if tv and tv.material_override is ShaderMaterial:
		(tv.material_override as ShaderMaterial).set_shader_parameter("edge_fade_color", HAZE)


# ======================================================================================
#  Ground, road frames, grading
# ======================================================================================

## The terrain's vertex heights from the saved mesh, in grid order (TerrainGenerator._generate_mesh).
func _load_heights() -> PackedFloat32Array:
	var mesh: ArrayMesh = load("res://generated/terrain_visual.res")
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var out := PackedFloat32Array()
	out.resize(verts.size())
	for i in range(verts.size()):
		out[i] = verts[i].y
	return out


## Ground height on the terrain's own triangles: each 2m cell is split along the diagonal from
## (x + 1, z) to (x, z + 1), as TerrainGenerator indexes it.
func _ground(x: float, z: float) -> float:
	var gx: float = (x - GRID_START) / GRID_STEP
	var gz: float = (z - GRID_START) / GRID_STEP
	var x0: int = clampi(floori(gx), 0, GRID_RES - 1)
	var z0: int = clampi(floori(gz), 0, GRID_RES - 1)
	var fx: float = gx - float(x0)
	var fz: float = gz - float(z0)
	var stride := GRID_RES + 1
	var h00: float = _heights[z0 * stride + x0]
	var h10: float = _heights[z0 * stride + x0 + 1]
	var h01: float = _heights[(z0 + 1) * stride + x0]
	var h11: float = _heights[(z0 + 1) * stride + x0 + 1]
	if fx + fz <= 1.0:
		return h00 + fx * (h10 - h00) + fz * (h01 - h00)
	return h11 + (1.0 - fx) * (h01 - h11) + (1.0 - fz) * (h10 - h11)


## Lowest ground under a circle (for things that mustn't float).
func _ground_min(x: float, z: float, r: float) -> float:
	var lo := _ground(x, z)
	for k in range(8):
		var a := TAU * k / 8.0
		lo = minf(lo, _ground(x + cos(a) * r, z + sin(a) * r))
	return lo


func _natural(x: float, z: float) -> float:
	return float(_tg.call("_sample_cached_height", x, z))


## The road at `s`: centre (on the curve), forward and right (horizontal).
func _frame(s: float) -> Dictionary:
	var ss := fposmod(s, _length)
	var p := _curve.sample_baked(ss)
	var a := _curve.sample_baked(fposmod(ss - 0.6, _length))
	var b := _curve.sample_baked(fposmod(ss + 0.6, _length))
	var f := b - a
	f.y = 0.0
	f = f.normalized()
	return {"pos": p, "fwd": f, "right": Vector3(-f.z, 0.0, f.x)}


## A point `lat` metres right of the road at `s`, on the ground.
func _at(s: float, lat: float) -> Vector3:
	var fr := _frame(s)
	var w: Vector3 = (fr["pos"] as Vector3) + (fr["right"] as Vector3) * lat
	w.y = _ground(w.x, w.z)
	return w


## Yaw that turns a prop's front (-z) toward `d` (horizontal).
static func _yaw_to(d: Vector3) -> float:
	return atan2(-d.x, -d.z)


## A rotated rectangle aligned with the road: [centre x, centre z, half along, half across, yaw].
func _road_rect(s0: float, s1: float, lat0: float, lat1: float) -> Array:
	var sm := (s0 + s1) * 0.5
	var fr := _frame(sm)
	var c: Vector3 = (fr["pos"] as Vector3) + (fr["right"] as Vector3) * ((lat0 + lat1) * 0.5)
	var f: Vector3 = fr["fwd"]
	# Basis(UP, yaw) takes the rectangle's local x to world (cos yaw, 0, -sin yaw): along the road.
	return [c.x, c.z, absf(s1 - s0) * 0.5, absf(lat1 - lat0) * 0.5, atan2(-f.z, f.x)]


## Pads (TerrainGenerator.flat_pads): the paddock, the grandstand's footing, the campsite terraces.
func _plan_pads() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	# The paddock sits a little above the straight beside it, the grandstand's footing level with
	# the east leg, the terraces where the hill already is.
	var road_p: float = _curve.sample_baked((PADDOCK_S.x + PADDOCK_S.y) * 0.5).y
	var paddock := _road_rect(PADDOCK_S.x, PADDOCK_S.y, PADDOCK_LAT.x, PADDOCK_LAT.y)
	_add_pad(out, paddock, 12.0, NAN, Vector2(road_p + 0.6, road_p + 2.2))
	var road_s: float = _curve.sample_baked((STAND_S.x + STAND_S.y) * 0.5).y
	var stand := _road_rect(STAND_S.x - 4.0, STAND_S.y + 4.0, STAND_FRONT_LAT - 12.0, STAND_FRONT_LAT + 1.0)
	_add_pad(out, stand, 7.0, road_s + _road_y - 0.25)
	for t in [CAMP_TERRACE, CAMP_UPPER]:
		var c: Vector2 = t[0]
		var h: Vector2 = t[1]
		_add_pad(out, [c.x, c.y, h.x, h.y, float(t[2])], 11.0)
	return out


## Adds a pad at `height`, or (NAN) at the mean natural ground height under it, held within
## `limits` if given; rounded to 5cm.
func _add_pad(out: PackedFloat32Array, r: Array, blend: float, height := NAN, limits := Vector2(-INF, INF)) -> void:
	var h := height
	if is_nan(h):
		var sum := 0.0
		var n := 0
		var c := cos(float(r[4]))
		var sn := sin(float(r[4]))
		for i in range(-4, 5):
			for j in range(-4, 5):
				var lx: float = float(r[2]) * i / 4.0
				var lz: float = float(r[3]) * j / 4.0
				# Local to world: Basis(UP, yaw) * (lx, 0, lz).
				sum += _natural(float(r[0]) + lx * c + lz * sn, float(r[1]) - lx * sn + lz * c)
				n += 1
		h = clampf(sum / n, limits.x, limits.y)
	h = snappedf(h, 0.05)
	print("  pad at (%.0f, %.0f), %.0f x %.0f m, height %.2f" % [r[0], r[1], float(r[2]) * 2.0, float(r[3]) * 2.0, h])
	out.append_array(PackedFloat32Array([r[0], r[1], r[2], r[3], r[4], h, blend]))


## Mown ground (TerrainGenerator.grass_clearings): the venue's verges, the spectator banks, the
## paddock and the terraces, so the tall meadow grass doesn't swallow the boards and furniture.
func _plan_clearings() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var rects: Array = [
		# Both verges of the straight, from behind the grid to the corner.
		[_road_rect(3125.0, 3318.0, -26.0, -VERGE), 5.0],
		[_road_rect(3125.0, 3318.0, VERGE, 16.0), 4.0],
		[_road_rect(PADDOCK_S.x - 4.0, PADDOCK_S.y + 4.0, PADDOCK_LAT.x - 3.0, PADDOCK_LAT.y), 6.0],
		# Round the corner and along the east leg past the grandstand.
		[_road_rect(0.0, 112.0, -32.0, -VERGE), 4.0],
		[_road_rect(0.0, 60.0, VERGE, 14.0), 4.0],
		[_road_rect(3290.0, 3318.0, VERGE, 16.0), 4.0],
	]
	for t in [CAMP_TERRACE, CAMP_UPPER]:
		var c: Vector2 = t[0]
		var h: Vector2 = t[1]
		rects.append([[c.x, c.y, h.x + 2.0, h.y + 2.0, float(t[2])], 6.0])
	for r in rects:
		var q: Array = r[0]
		out.append_array(PackedFloat32Array([q[0], q[1], q[2], q[3], q[4], r[1]]))
	return out


## A one-sided offset of the centreline from s0 to s1 (wrapping past the lap's end), `lat` metres to
## the side, on the ground, every `step` metres. Round joins on the outside of a corner (the first
## corner is a single sharp point), so a run wraps round it instead of jumping.
func _offset_run(s0: float, s1: float, lat: float, step: float) -> PackedVector3Array:
	var span := fposmod(s1 - s0, _length)
	var n := maxi(2, ceili(span / 0.5))
	var cl: Array = []
	for i in range(n + 1):
		cl.append(_curve.sample_baked(fposmod(s0 + span * i / n, _length)))
	var pts := PackedVector3Array()
	var prev_n := Vector3.ZERO
	for i in range(cl.size() - 1):
		var a: Vector3 = cl[i]
		var b: Vector3 = cl[i + 1]
		var d := b - a
		d.y = 0.0
		if d.length_squared() < 1e-8:
			continue
		d = d.normalized()
		var nrm := Vector3(-d.z, 0.0, d.x)
		if prev_n != Vector3.ZERO:
			var turn := prev_n.signed_angle_to(nrm, Vector3.UP)
			# Outside of the turn: sweep round the corner point.
			if absf(turn) > 0.05 and signf(turn) == signf(lat):
				var steps := ceili(absf(turn) / 0.12)
				for k in range(1, steps):
					var nn := prev_n.rotated(Vector3.UP, turn * k / steps)
					pts.append(a + nn * lat)
		pts.append(a + nrm * lat)
		prev_n = nrm
	pts.append((cl[cl.size() - 1] as Vector3) + prev_n * lat)
	# Resample by length.
	var out := PackedVector3Array()
	var acc := 0.0
	out.append(pts[0])
	for i in range(1, pts.size()):
		var seg := pts[i - 1].distance_to(pts[i])
		acc += seg
		while acc >= step:
			acc -= step
			var t := 1.0 - acc / maxf(seg, 1e-5)
			out.append(pts[i - 1].lerp(pts[i], t))
	for i in range(out.size()):
		var v := out[i]
		v.y = _ground(v.x, v.z)
		out[i] = v
	return out


## The road's distance from (x, z): the centreline's nearest point, on the lap or a shortcut.
func _road_distance(x: float, z: float) -> float:
	var p := _curve.get_closest_point(Vector3(x, 0.0, z))
	return Vector2(p.x - x, p.z - z).length()


## Records a footprint for _verify_clear: things must stand `clearance` past the road's edge.
func _note(what: String, at: Vector3, radius: float, clearance: float) -> void:
	_footprints.append([what, Vector2(at.x, at.z), radius, clearance])


func _verify_clear() -> void:
	var bad := 0
	for f in _footprints:
		var c: Vector2 = f[1]
		var gap: float = _road_distance(c.x, c.y) - float(f[2]) - ROAD_HALF
		if gap < float(f[3]):
			push_error("Lakeside: %s is %.1fm off the road's edge (wants %.1fm)" % [f[0], gap, f[3]])
			bad += 1
	print("  %d footprints checked, %d too close to the road" % [_footprints.size(), bad])


# ======================================================================================
#  Materials, saving
# ======================================================================================

func _save_res(res: Resource, res_name: String) -> Resource:
	var path := "res://generated/" + RES_PREFIX + res_name + ".res"
	res.take_over_path(path)
	ResourceSaver.save(res, path)
	return load(path)


## The material for a kit key, made once and saved, so every mesh of the level shares it.
func _material(key: String) -> Material:
	if _materials.has(key):
		return _materials[key]
	var m: Material
	match key:
		"boards":
			var sm := ShaderMaterial.new()
			sm.shader = load("res://stadium_boards.gdshader")
			m = sm
		"chainlink":
			var cm := StandardMaterial3D.new()
			cm.albedo_texture = _chainlink_texture()
			cm.albedo_color = Color(0.80, 0.82, 0.84)
			cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			cm.cull_mode = BaseMaterial3D.CULL_DISABLED
			cm.metallic = 0.6
			cm.roughness = 0.4
			cm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			cm.uv1_scale = Vector3(1.0 / 0.085, 1.0 / 0.085, 1.0)
			m = cm
		"straw":
			var hm := StandardMaterial3D.new()
			hm.albedo_texture = _straw_texture()
			hm.vertex_color_use_as_albedo = true
			hm.vertex_color_is_srgb = true
			hm.uv1_triplanar = true
			hm.uv1_world_triplanar = true
			hm.uv1_scale = Vector3(0.7, 0.7, 0.7)
			hm.roughness = 0.95
			m = hm
		_:
			m = CampKit.make_material(key)
	m = _save_res(m, "mat_" + key)
	_materials[key] = m
	return m


## A tiling chain-link mesh: wires running both diagonals with the twist where they cross, alpha
## outside the wire, so the fence reads as a grey veil from afar (the mipmaps average it out).
func _chainlink_texture() -> Texture2D:
	const N := 128
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	for y in range(N):
		for x in range(N):
			var u := float(x) + 0.5
			var v := float(y) + 0.5
			# Distance to the nearest wire on each diagonal (period N on both).
			var d1 := absf(fposmod(u + v, float(N)) - N * 0.5)
			var d2 := absf(fposmod(u - v, float(N)) - N * 0.5)
			var w1 := clampf(4.2 - (N * 0.5 - d1), 0.0, 1.0) if d1 > N * 0.5 - 5.0 else 0.0
			var w2 := clampf(4.2 - (N * 0.5 - d2), 0.0, 1.0) if d2 > N * 0.5 - 5.0 else 0.0
			var a := maxf(w1, w2)
			var shade := 0.75 + 0.25 * (w1 if w1 > w2 else w2)
			img.set_pixel(x, y, Color(shade, shade, shade, a))
	img.generate_mipmaps()
	return _save_res(ImageTexture.create_from_image(img), "chainlink")


## Straw for the hay bales: short strands, mostly lying one way, gold with pale and dark ones mixed.
func _straw_texture() -> Texture2D:
	const N := 256
	var rng := RandomNumberGenerator.new()
	rng.seed = 818
	var lum := PackedFloat32Array()
	lum.resize(N * N)
	lum.fill(0.55)
	for k in range(5200):
		var x0 := rng.randf() * N
		var y0 := rng.randf() * N
		var ang := rng.randf_range(-0.5, 0.5) + (PI * 0.5 if rng.randf() < 0.2 else 0.0)
		var length := rng.randf_range(6.0, 22.0)
		var l := rng.randf_range(0.35, 1.0)
		for t in range(int(length * 2.0)):
			var px := posmod(int(x0 + cos(ang) * t * 0.5), N)
			var py := posmod(int(y0 + sin(ang) * t * 0.5), N)
			lum[py * N + px] = l
	var img := Image.create(N, N, false, Image.FORMAT_RGB8)
	for y in range(N):
		for x in range(N):
			var l: float = lum[y * N + x]
			img.set_pixel(x, y, Color(0.62 + 0.38 * l, 0.50 + 0.36 * l, 0.22 + 0.20 * l))
	img.generate_mipmaps()
	return _save_res(ImageTexture.create_from_image(img), "straw")


## Commits a kit to a MeshInstance3D under `parent`, saving the mesh.
func _commit(parent: Node3D, kit: Dictionary, node_name: String, vis_range := 0.0) -> MeshInstance3D:
	_kit.reset_frame()
	var mesh := _kit.commit(kit)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = _save_res(mesh, node_name.to_snake_case())
	if vis_range > 0.0:
		mi.visibility_range_end = vis_range
		mi.visibility_range_end_margin = 20.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(mi)
	return mi


## A static body holding boxes: [centre, size, basis] each (world).
func _boxes_body(parent: Node3D, node_name: String, boxes: Array) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	parent.add_child(body)
	for b in boxes:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = b[1]
		cs.shape = shape
		cs.transform = Transform3D(b[2] if b.size() > 2 else Basis(), b[0])
		body.add_child(cs)
	return body


## A box collider between two ground points: `h` tall, `w` thick (for runs of tyres and walls).
func _wall_box(a: Vector3, b: Vector3, w: float, h: float, lift := 0.0) -> Array:
	var d := b - a
	d.y = 0.0
	var length := d.length()
	var z := d / maxf(length, 1e-4)
	var x := Vector3.UP.cross(z).normalized()
	var mid := (a + b) * 0.5
	mid.y = (a.y + b.y + h) * 0.5 + lift
	return [mid, Vector3(w, h + absf(a.y - b.y), length), Basis(x, Vector3.UP, z)]


## The placement frame of a life-size prop: on the ground at `at`, turned `yaw`, scaled up.
func _place(at: Vector3, yaw: float, s := PROP_SCALE) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), at)


# ======================================================================================
#  The kicker
# ======================================================================================

## Replaces the old curled ramp with a straight steel kicker in its place: a transition that rises
## from flush with the road into a 25 degree lip, cut off square at the top, on a braced frame
## with solid sides. The deck is its own body named "KickerJump" (PlayerCart drives on it as road);
## the sides and back are "KickerFrame". The three boost pads that sat on the old ramp move onto
## the new deck, and the TrackPath records the lip for scratch/nyota_jump_test (level=...).
func _build_kicker(root: Node3D) -> void:
	var old := _level.get_node_or_null("Ramps/NewRamp")
	if old:
		old.get_parent().remove_child(old)
		old.free()
	var R := KICKER_ARC_H / (1.0 - cos(KICKER_ANGLE))
	var a_arc := R * sin(KICKER_ANGLE)
	var a_end := a_arc + KICKER_LIP * cos(KICKER_ANGLE)
	var h_end := KICKER_ARC_H + KICKER_LIP * sin(KICKER_ANGLE)
	var s0 := KICKER_S0
	var p0 := _curve.sample_baked(s0) + Vector3(0, _road_y + 0.02, 0)
	var p1 := _curve.sample_baked(s0 + a_end) + Vector3(0, _road_y + 0.02, 0)
	var fwd := p1 - p0
	var grade := fwd.y / Vector2(fwd.x, fwd.z).length()
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var hw := KICKER_HALF_W
	var prof := func(a: float) -> float:
		if a <= a_arc:
			return R - sqrt(maxf(R * R - a * a, 0.0))
		return KICKER_ARC_H + (a - a_arc) * tan(KICKER_ANGLE)
	var kp := func(a: float, lat: float, h: float) -> Vector3:
		return p0 + fwd * a + right * lat + Vector3(0.0, grade * a + h, 0.0)
	var deck_n := func(a: float) -> Vector3:
		var slope: float = (a / sqrt(maxf(R * R - a * a, 1e-4)) if a <= a_arc else tan(KICKER_ANGLE)) + grade
		return (Vector3.UP - fwd * slope).normalized()
	var kit := {}
	var faces := PackedVector3Array()
	var frame_faces := PackedVector3Array()
	var steps: Array = []
	var n_arc := ceili(a_arc / 0.5)
	for i in range(n_arc + 1):
		steps.append(a_arc * i / n_arc)
	steps.append(a_end)
	var deck_col := KICKER_ORANGE
	var side_col := KICKER_ORANGE.darkened(0.08)
	for i in range(steps.size() - 1):
		var a0: float = steps[i]
		var a1: float = steps[i + 1]
		var h0: float = prof.call(a0)
		var h1: float = prof.call(a1)
		var n0: Vector3 = deck_n.call(a0)
		var n1: Vector3 = deck_n.call(a1)
		var l0: Vector3 = kp.call(a0, -hw, h0)
		var r0: Vector3 = kp.call(a0, hw, h0)
		var l1: Vector3 = kp.call(a1, -hw, h1)
		var r1: Vector3 = kp.call(a1, hw, h1)
		# The deck: one strip across, with the anti-slip panel joints as slight colour steps.
		var shade: Color = deck_col.darkened(0.04 if (int(a0 / 2.4) % 2) == 0 else 0.0)
		_kit.tri(kit, "paint", l0, r0, r1, n0, n0, n1, shade, n0)
		_kit.tri(kit, "paint", l0, r1, l1, n0, n1, n1, shade, n0)
		faces.append_array(PackedVector3Array([l0, r1, r0, l0, l1, r1]))
		# The sides, down to the road.
		for side in [-1.0, 1.0]:
			var lat: float = hw * side
			var t0: Vector3 = kp.call(a0, lat, h0)
			var t1: Vector3 = kp.call(a1, lat, h1)
			var b0: Vector3 = kp.call(a0, lat, -0.4)
			var b1: Vector3 = kp.call(a1, lat, -0.4)
			var sn: Vector3 = right * side
			_kit.quad(kit, "paint", [b0, b1, t1, t0], sn, side_col)
			frame_faces.append_array(PackedVector3Array([b0, t1, b1, b0, t0, t1]))
	# The back: a square-cut wall under the lip.
	var lb: Vector3 = kp.call(a_end, -hw, -0.4)
	var rb: Vector3 = kp.call(a_end, hw, -0.4)
	var lt: Vector3 = kp.call(a_end, -hw, h_end)
	var rt: Vector3 = kp.call(a_end, hw, h_end)
	_kit.quad(kit, "steel", [lb, rb, rt, lt], fwd, STEEL)
	frame_faces.append_array(PackedVector3Array([lb, rt, rb, lb, lt, rt]))
	# Steel frame on the sides and the back: posts every 3m, braces between, a chord along the top.
	var post_a := 3.0
	while post_a < a_end - 0.3:
		var ph: float = prof.call(post_a)
		for side in [-1.0, 1.0]:
			var lat2: float = (hw + 0.06) * side
			_kit.beam(kit, "steel", kp.call(post_a, lat2, -0.3), kp.call(post_a, lat2, ph - 0.05), 0.16, 0.12, STEEL, right)
			var na := post_a + 3.0
			if na < a_end and ph > 1.2:
				var nh: float = prof.call(na)
				_kit.beam(kit, "steel", kp.call(post_a, lat2, 0.1), kp.call(minf(na, a_end - 0.1), lat2, nh - 0.25), 0.10, 0.08, STEEL, right)
		post_a += 3.0
	for side in [-1.0, 1.0]:
		var lat3: float = (hw + 0.07) * side
		var prev: Vector3 = kp.call(0.0, lat3, 0.0)
		for i in range(1, steps.size()):
			var aa: float = steps[i]
			var cur: Vector3 = kp.call(aa, lat3, prof.call(aa) - 0.08)
			_kit.beam(kit, "steel", prev, cur, 0.14, 0.18, STEEL, right)
			prev = cur
	for k in range(-2, 3):
		var lat4: float = k * hw * 0.45
		_kit.beam(kit, "steel", kp.call(a_end + 0.08, lat4, -0.3), kp.call(a_end + 0.08, lat4, h_end - 0.05), 0.18, 0.16, STEEL, fwd)
	for k in range(-2, 2):
		var la: float = k * hw * 0.45
		var lb2: float = (k + 1) * hw * 0.45
		_kit.beam(kit, "steel", kp.call(a_end + 0.1, la, 0.2), kp.call(a_end + 0.1, lb2, h_end - 0.6), 0.1, 0.08, STEEL, fwd)
	# The lip: a steel nose along the edge, hazard stripes before it, white edge lines up the deck.
	var lip_n: Vector3 = deck_n.call(a_end)
	_kit.beam(kit, "steel", (kp.call(a_end - 0.06, -hw, h_end) as Vector3) - lip_n * 0.075, (kp.call(a_end - 0.06, hw, h_end) as Vector3) - lip_n * 0.075, 0.14, 0.12, STEEL.lightened(0.15), lip_n)
	var band := 0.9
	var stripes := 12
	for k in range(stripes):
		var la0 := -hw + 2.0 * hw * k / stripes
		var la1 := -hw + 2.0 * hw * (k + 1) / stripes
		var c: Color = Color(0.98, 0.80, 0.10) if k % 2 == 0 else Color(0.08, 0.08, 0.08)
		var a0b := a_end - band
		var q: Array = [kp.call(a0b, la0, prof.call(a0b)) + lip_n * 0.012, kp.call(a0b, la1, prof.call(a0b)) + lip_n * 0.012,
				kp.call(a_end - 0.12, la1 + 0.3, h_end - 0.05) + lip_n * 0.012, kp.call(a_end - 0.12, la0 + 0.3, h_end - 0.05) + lip_n * 0.012]
		_kit.quad(kit, "paint", q, lip_n, c)
	for side in [-1.0, 1.0]:
		var e0: float = (hw - 0.45) * side
		var e1: float = (hw - 0.25) * side
		for i in range(steps.size() - 1):
			var aa0: float = steps[i]
			var aa1: float = steps[i + 1]
			if aa1 > a_end - band:
				break
			var na0: Vector3 = deck_n.call(aa0)
			var na1: Vector3 = deck_n.call(aa1)
			_kit.quad(kit, "paint", [kp.call(aa0, e0, prof.call(aa0)) + na0 * 0.01, kp.call(aa0, e1, prof.call(aa0)) + na0 * 0.01,
					kp.call(aa1, e1, prof.call(aa1)) + na1 * 0.01, kp.call(aa1, e0, prof.call(aa1)) + na1 * 0.01], na0, WHITE)
	# Sponsor boards on both sides.
	for side in [-1.0, 1.0]:
		var lat5: float = (hw + 0.15) * side
		_ad_board(kit, kp.call(18.0, lat5, 0.35), kp.call(26.0, lat5, 0.35), 1.0, right * side, 0)
		_ad_board(kit, kp.call(27.0, lat5, 0.5), kp.call(35.0, lat5, 0.5), 1.0, right * side, 4 if side > 0.0 else 3)
	_commit(root, kit, "OrangeKicker")
	# Collision: the deck as road, the sides and back as a solid frame.
	var deck_body := StaticBody3D.new()
	deck_body.name = "KickerJump"
	root.add_child(deck_body)
	var dcs := CollisionShape3D.new()
	var dshape := ConcavePolygonShape3D.new()
	dshape.set_faces(faces)
	dcs.shape = _save_res(dshape, "kicker_deck_collision")
	deck_body.add_child(dcs)
	var frame_body := StaticBody3D.new()
	frame_body.name = "KickerFrame"
	root.add_child(frame_body)
	var fcs := CollisionShape3D.new()
	var fshape := ConcavePolygonShape3D.new()
	fshape.set_faces(frame_faces)
	fshape.backface_collision = true
	fcs.shape = _save_res(fshape, "kicker_frame_collision")
	frame_body.add_child(fcs)
	# The boost pads that rode the old ramp: one on the run-in, two side by side up the face.
	var pads := {"BoostPads/BoostPad7": Vector2(13.0, 0.0), "BoostPads/BoostPad5": Vector2(29.0, -2.25), "BoostPads/BoostPad6": Vector2(29.0, 2.25)}
	for path in pads:
		var bp := _level.get_node_or_null(path) as Node3D
		if bp == null:
			continue
		var at: Vector2 = pads[path]
		var n: Vector3 = deck_n.call(at.x)
		var along := (fwd + Vector3(0, (prof.call(at.x + 0.5) - prof.call(at.x - 0.5)) + grade, 0)).normalized()
		var bz := -along
		var bx := n.cross(bz).normalized()
		bp.transform = Transform3D(Basis(bx, n, bz), (kp.call(at.x, at.y, prof.call(at.x)) as Vector3) + n * 0.06)
	# The lip, for the jump test.
	var lip: Vector3 = kp.call(a_end, 0.0, h_end)
	var track_path := _level.get_node("TrackPath")
	track_path.set_meta(&"jump_lips", [{"name": "Kicker", "lip": lip, "dir": (fwd + Vector3(0, grade, 0)).normalized()}])
	print("  kicker: %.1fm long, lip %.1fm over the road at %d deg (s %.0f..%.0f)" % [a_end, h_end, int(rad_to_deg(KICKER_ANGLE)), s0, s0 + a_end])


## A sponsor board from a to b (its bottom edge, world), `h` tall, its face toward `face`, showing
## advert `ad` (StadiumAds atlas), with a dark back and frame.
func _ad_board(kit: Dictionary, a: Vector3, b: Vector3, h: float, face: Vector3, ad: int) -> void:
	var up := Vector3(0, h, 0)
	var f := face.normalized()
	var off := f * 0.02
	var col := Color(float(ad) / 64.0, 0.0, 0.0, 1.0)
	# Text reads left to right for someone facing the board: the bottom-left corner is on their left.
	var left_to_right := (b - a)
	var p0 := a
	var p1 := b
	if f.cross(Vector3.UP).dot(left_to_right) > 0.0:
		p0 = b
		p1 = a
	_kit.quad(kit, "boards", [p0 + off, p1 + off, p1 + up + off, p0 + up + off], f, col,
			[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	_kit.quad(kit, "steel", [p1 - f * 0.02, p0 - f * 0.02, p0 + up - f * 0.02, p1 + up - f * 0.02], -f, Color(0.12, 0.12, 0.13))
	# Frame round the edge.
	_kit.beam(kit, "steel", p0 + up + f * 0.0, p1 + up + f * 0.0, 0.05, 0.06, Color(0.14, 0.14, 0.15), f)
	_kit.beam(kit, "steel", p0, p1, 0.05, 0.06, Color(0.14, 0.14, 0.15), f)


func _next_ad() -> int:
	var ad: int = AD_CYCLE[_ad_k % AD_CYCLE.size()]
	_ad_k += 1
	return ad


## The StadiumAds node that draws the sponsors into the boards' material at load.
func _build_ads(root: Node3D) -> void:
	if not _materials.has("boards"):
		return
	var ads := Node.new()
	ads.name = "SponsorArt"
	ads.set_script(load("res://StadiumAds.gd"))
	var targets: Array[ShaderMaterial] = [_materials["boards"] as ShaderMaterial]
	ads.set("targets", targets)
	ads.set("ads", ADS)
	root.add_child(ads)


# ======================================================================================
#  The paddock
# ======================================================================================

const CANOPIES := [Color(0.80, 0.11, 0.09), Color(0.10, 0.28, 0.66), Color(0.10, 0.28, 0.66), Color(0.93, 0.93, 0.91),
		Color(0.95, 0.62, 0.08), Color(0.12, 0.45, 0.22), Color(0.80, 0.11, 0.09), Color(0.93, 0.93, 0.91)]
const CHEST_COLS := [Color(0.75, 0.08, 0.07), Color(0.75, 0.08, 0.07), Color(0.08, 0.10, 0.25), Color(0.12, 0.12, 0.13)]
const CHAIR_COLS := CampKit.CHAIR_COLS

## Team gazebos in a row facing the straight past the gantry, each with a table, chairs, a tool chest,
## a cool box, toolboxes and a generator; portable toilets and two big team tents behind them.
func _build_paddock(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Paddock"
	root.add_child(node)
	var kit := {}
	var clutter := {}
	var boxes: Array = []
	var n := 7
	for i in range(n):
		var s: float = PADDOCK_S.x + 6.0 + (PADDOCK_S.y - PADDOCK_S.x - 14.0) * i / (n - 1)
		var lat: float = -27.0 + (1.6 if i % 2 == 1 else 0.0)
		var fr := _frame(s)
		var at := _at(s, lat)
		var yaw := _yaw_to(fr["right"]) + _rng.randf_range(-0.05, 0.05)
		var canopy: Color = CANOPIES[i % CANOPIES.size()]
		_kit.set_frame(_place(at, yaw))
		_camp.gazebo(kit, canopy, i % 3 == 2)
		_kit.set_frame(_place(at, yaw))
		_pit_set(clutter, i)
		_note("Gazebo%d" % i, at, 2.6 * PROP_SCALE, 4.0)
		# Legs, as thin posts carts bump.
		for sx in [-1.47, 1.47]:
			for sz in [-1.47, 1.47]:
				var leg := Transform3D(Basis(Vector3.UP, yaw), at) * Vector3(sx * PROP_SCALE, 1.6, sz * PROP_SCALE)
				boxes.append([leg, Vector3(0.12, 3.2, 0.12), Basis(Vector3.UP, yaw)])
	# Behind the row: two big team tents (6 x 3) and a line of portable toilets.
	for j in range(2):
		var s2: float = PADDOCK_S.x + 18.0 + j * 30.0
		var at2 := _at(s2, -38.5)
		var yaw2 := _yaw_to(_frame(s2)["right"])
		_kit.set_frame(_place(at2, yaw2))
		_team_tent(kit, [Color(0.93, 0.93, 0.91), Color(0.06, 0.10, 0.22)][j])
		_note("TeamTent%d" % j, at2, 3.4 * PROP_SCALE, 6.0)
	for t in range(4):
		var s3: float = PADDOCK_S.x + 36.0 + t * 2.0
		var at3 := _at(s3, -40.5)
		var yaw3 := _yaw_to(_frame(s3)["right"])
		_kit.set_frame(_place(at3, yaw3))
		_toilet(kit, [Color(0.16, 0.36, 0.72), Color(0.16, 0.36, 0.72), Color(0.18, 0.52, 0.30), Color(0.16, 0.36, 0.72)][t])
		boxes.append([at3 + Vector3(0, 1.15 * PROP_SCALE, 0), Vector3(1.2, 2.3, 1.2) * PROP_SCALE, Basis(Vector3.UP, yaw3)])
	_commit(node, kit, "PaddockTents")
	_commit(node, clutter, "PaddockGear", 260.0)
	_boxes_body(node, "PaddockBody", boxes)


## The gear under gazebo `i`: a table with a car on its stand, a transmitter and a charger, chairs, a
## rolling tool chest, toolboxes, a cool box and a generator out the back.
func _pit_set(kit: Dictionary, i: int) -> void:
	var k := _kit
	var base := k.xf
	var rng := RandomNumberGenerator.new()
	rng.seed = 400 + i * 17
	var sub := func(x: float, z: float, yaw: float) -> void:
		k.set_frame(base * Transform3D(Basis(Vector3.UP, yaw), Vector3(x, 0, z)))
	sub.call(0.1, 0.55, 0.0)
	_camp.folding_table(kit, Color(0.90, 0.90, 0.88))
	sub.call(-0.25, 0.55, 0.15)
	_rc_buggy(kit, CAR_COLS[i % CAR_COLS.size()], 0.74)
	sub.call(0.45, 0.48, -0.4)
	_transmitter(kit, 0.74)
	sub.call(0.75, 0.62, 0.1)
	_charger(kit, 0.74)
	for c in range(2):
		sub.call(-0.75 + c * 1.1 + rng.randf_range(-0.1, 0.1), -0.55 + rng.randf_range(-0.15, 0.15), PI + rng.randf_range(-0.4, 0.4))
		_camp.camp_chair(kit, CHAIR_COLS[(i + c * 2) % CHAIR_COLS.size()])
	sub.call(1.05, 1.05, PI * 0.5 + rng.randf_range(-0.2, 0.2))
	_tool_chest(kit, CHEST_COLS[i % CHEST_COLS.size()])
	sub.call(-1.15, -1.05 + rng.randf_range(0, 0.4), rng.randf_range(0, TAU))
	_camp.cooler(kit, [Color(0.80, 0.10, 0.10), Color(0.10, 0.30, 0.70), Color(0.92, 0.92, 0.90)][i % 3], WHITE)
	sub.call(-1.0, 1.0, rng.randf_range(-0.5, 0.5))
	_toolbox(kit, [Color(0.08, 0.12, 0.30), Color(0.12, 0.12, 0.13), Color(0.75, 0.08, 0.07)][i % 3])
	sub.call(-0.6, 1.1, rng.randf_range(-0.5, 0.5))
	_toolbox(kit, Color(0.08, 0.12, 0.30))
	sub.call(1.9, 1.9 + rng.randf_range(-0.3, 0.3), rng.randf_range(0, TAU))
	_generator(kit, [Color(0.85, 0.12, 0.08), Color(0.95, 0.75, 0.08)][i % 2])
	k.set_frame(base)


const CAR_COLS := [Color(0.85, 0.10, 0.10), Color(0.20, 0.75, 0.25), Color(0.30, 0.25, 0.85), Color(0.95, 0.75, 0.10),
		Color(0.95, 0.45, 0.10), Color(0.10, 0.65, 0.85)]


func _tool_chest(kit: Dictionary, body: Color) -> void:
	var k := _kit
	var dark := Color(0.08, 0.08, 0.09)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			k.tube(kit, "rubber", Vector3(sx * 0.28 - 0.02, 0.045, sz * 0.17), Vector3(sx * 0.28 + 0.02, 0.045, sz * 0.17), 0.045, 0.045, 8, dark)
	k.block(kit, "paint", Vector3(-0.345, 0.09, -0.23), Vector3(0.345, 0.86, 0.23), body)
	k.block(kit, "paint", Vector3(-0.345, 0.87, -0.21), Vector3(0.345, 1.18, 0.21), body)
	k.block(kit, "paint", Vector3(-0.35, 1.18, -0.215), Vector3(0.35, 1.22, 0.215), body.darkened(0.15))
	var chrome := Color(0.85, 0.86, 0.88)
	# Drawer fronts: proud of the body, with a pull along each.
	var rows := [[0.12, 0.30], [0.32, 0.46], [0.48, 0.60], [0.62, 0.73], [0.75, 0.84], [0.90, 0.99], [1.01, 1.08], [1.10, 1.16]]
	for r in rows:
		var zf: float = -0.23 if r[0] < 0.86 else -0.21
		k.block(kit, "paint", Vector3(-0.32, r[0], zf - 0.012), Vector3(0.32, r[1], zf), body.lightened(0.06))
		k.block(kit, "chrome", Vector3(-0.26, r[1] - 0.035, zf - 0.03), Vector3(0.26, r[1] - 0.02, zf - 0.012), chrome)
	k.tube(kit, "chrome", Vector3(0.36, 0.55, -0.15), Vector3(0.36, 0.55, 0.15), 0.012, 0.012, 6, chrome)


func _toolbox(kit: Dictionary, col: Color) -> void:
	var k := _kit
	k.block(kit, "plastic", Vector3(-0.25, 0.0, -0.12), Vector3(0.25, 0.17, 0.12), col)
	k.block(kit, "plastic", Vector3(-0.255, 0.17, -0.125), Vector3(0.255, 0.23, 0.125), col.lightened(0.08))
	var h := Color(0.1, 0.1, 0.1)
	k.beam(kit, "plastic", Vector3(-0.12, 0.23, 0), Vector3(-0.1, 0.29, 0), 0.03, 0.03, h)
	k.beam(kit, "plastic", Vector3(0.12, 0.23, 0), Vector3(0.1, 0.29, 0), 0.03, 0.03, h)
	k.beam(kit, "plastic", Vector3(-0.11, 0.29, 0), Vector3(0.11, 0.29, 0), 0.03, 0.03, h)
	k.block(kit, "chrome", Vector3(-0.21, 0.13, -0.13), Vector3(-0.17, 0.19, -0.12), Color(0.8, 0.8, 0.82))
	k.block(kit, "chrome", Vector3(0.17, 0.13, -0.13), Vector3(0.21, 0.19, -0.12), Color(0.8, 0.8, 0.82))


func _generator(kit: Dictionary, col: Color) -> void:
	var k := _kit
	var fr := Color(0.08, 0.08, 0.09)
	var hx := 0.31
	var hz := 0.22
	var top := 0.48
	# The cage: a tube box.
	var pts := [Vector3(-hx, 0.02, -hz), Vector3(hx, 0.02, -hz), Vector3(hx, 0.02, hz), Vector3(-hx, 0.02, hz)]
	for i in range(4):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % 4]
		k.tube(kit, "metal", a, b, 0.014, 0.014, 5, fr)
		k.tube(kit, "metal", a + Vector3(0, top, 0), b + Vector3(0, top, 0), 0.014, 0.014, 5, fr)
		k.tube(kit, "metal", a, a + Vector3(0, top, 0), 0.014, 0.014, 5, fr)
	k.block(kit, "paint", Vector3(-0.27, 0.04, -0.17), Vector3(0.02, 0.33, 0.17), Color(0.25, 0.26, 0.28))
	k.tube(kit, "paint", Vector3(0.02, 0.2, 0), Vector3(0.27, 0.2, 0), 0.13, 0.12, 10, col)
	k.block(kit, "paint", Vector3(-0.27, 0.35, -0.18), Vector3(0.27, 0.46, 0.18), col)
	k.tube(kit, "plastic", Vector3(-0.1, 0.46, 0.0), Vector3(-0.1, 0.5, 0.0), 0.035, 0.035, 8, fr)
	k.block(kit, "plastic", Vector3(0.12, 0.08, -0.235), Vector3(0.26, 0.30, -0.22), fr.lightened(0.1))


## A 1/8 buggy on its stand on a table top `y` high: chassis, a shell, a wing and four wheels.
func _rc_buggy(kit: Dictionary, col: Color, y: float) -> void:
	var k := _kit
	var dark := Color(0.07, 0.07, 0.08)
	k.block(kit, "plastic", Vector3(-0.05, y, -0.05), Vector3(0.05, y + 0.07, 0.05), dark)
	var cy := y + 0.11
	k.block(kit, "metal", Vector3(-0.09, cy - 0.01, -0.21), Vector3(0.09, cy + 0.005, 0.2), Color(0.2, 0.2, 0.22))
	# Shell: a low wedge.
	var shell := PackedVector2Array([Vector2(-0.2, cy), Vector2(0.17, cy), Vector2(0.21, cy + 0.02), Vector2(0.08, cy + 0.075), Vector2(-0.12, cy + 0.085), Vector2(-0.2, cy + 0.05)])
	var b := k.xf
	k.set_frame(b * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO))
	k.extrude(kit, "plastic", shell, -0.075, 0.075, 0.015, col)
	k.set_frame(b)
	k.block(kit, "plastic", Vector3(-0.11, cy + 0.12, 0.17), Vector3(0.11, cy + 0.13, 0.24), col.darkened(0.2))
	k.block(kit, "plastic", Vector3(-0.01, cy + 0.03, 0.18), Vector3(0.01, cy + 0.12, 0.2), dark)
	for wx in [-1.0, 1.0]:
		for wz in [-0.15, 0.15]:
			k.tube(kit, "rubber", Vector3(wx * 0.1, cy, wz), Vector3(wx * 0.15, cy, wz), 0.05, 0.05, 10, dark)
			k.tube(kit, "plastic", Vector3(wx * 0.151, cy, wz), Vector3(wx * 0.152, cy, wz), 0.03, 0.03, 8, Color(0.85, 0.85, 0.85))


func _transmitter(kit: Dictionary, y: float) -> void:
	var k := _kit
	var dark := Color(0.08, 0.08, 0.09)
	k.block(kit, "plastic", Vector3(-0.05, y, -0.09), Vector3(0.05, y + 0.06, 0.09), dark)
	k.block(kit, "plastic", Vector3(-0.03, y + 0.06, -0.05), Vector3(0.03, y + 0.1, 0.02), Color(0.75, 0.1, 0.08))
	k.tube(kit, "plastic", Vector3(0, y + 0.1, 0.05), Vector3(0, y + 0.22, 0.07), 0.006, 0.004, 4, dark)


func _charger(kit: Dictionary, y: float) -> void:
	var k := _kit
	k.block(kit, "plastic", Vector3(-0.1, y, -0.07), Vector3(0.1, y + 0.05, 0.07), Color(0.12, 0.12, 0.13))
	k.block(kit, "lamp", Vector3(-0.07, y + 0.051, -0.04), Vector3(0.0, y + 0.055, 0.02), Color(0.2, 0.7, 0.9))
	k.block(kit, "plastic", Vector3(0.12, y, -0.04), Vector3(0.24, y + 0.04, 0.04), Color(0.9, 0.55, 0.1))


## A 6 x 3 m race team marquee tent: two portal-framed bays under a ridged roof with gable vents,
## Georgian-style windowed side walls, tied-back front entrance drapes, and a pit workshop inside.
func _team_tent(kit: Dictionary, col: Color) -> void:
	var k := _kit
	var hw := 2.95
	var hd := 1.47
	var eave := 2.12
	var ridge := 2.90
	var fr := Color(0.80, 0.82, 0.84)
	var joint := Color(0.11, 0.11, 0.12)
	var under := col.darkened(0.32)
	var seam := col.darkened(0.15)
	var accent := Color(0.84, 0.16, 0.12) if col.v > 0.5 else Color(0.96, 0.68, 0.12)
	var stripe2 := WHITE if col.v <= 0.5 else Color(0.08, 0.18, 0.42)
	# Portal frame legs, footplates, sandbags, eave beams and portal rafters.
	for x in [-hw, 0.0, hw]:
		for sz in [-1.0, 1.0]:
			var z: float = sz * hd
			k.block(kit, "metal", Vector3(x - 0.024, 0.0, z - 0.024), Vector3(x + 0.024, eave, z + 0.024), fr)
			k.block(kit, "metal", Vector3(x - 0.085, 0.0, z - 0.085), Vector3(x + 0.085, 0.018, z + 0.085), fr.darkened(0.22))
			k.block(kit, "plastic", Vector3(x - 0.032, eave - 0.08, z - 0.032), Vector3(x + 0.032, eave, z + 0.032), joint)
			k.box(kit, "canvas", Transform3D(Basis(), Vector3(x, 0.085, z)), Vector3(0.36, 0.17, 0.20), Color(0.09, 0.09, 0.10))
		# Portal rafters up to the ridge and horizontal collar tie.
		k.beam(kit, "metal", Vector3(x, eave - 0.03, -hd), Vector3(x, ridge - 0.04, 0.0), 0.035, 0.035, fr)
		k.beam(kit, "metal", Vector3(x, eave - 0.03, hd), Vector3(x, ridge - 0.04, 0.0), 0.035, 0.035, fr)
		k.beam(kit, "metal", Vector3(x, eave + 0.12, -hd * 0.72), Vector3(x, eave + 0.12, hd * 0.72), 0.024, 0.024, fr)
	for sz in [-1.0, 1.0]:
		k.beam(kit, "metal", Vector3(-hw, eave - 0.03, sz * hd), Vector3(hw, eave - 0.03, sz * hd), 0.035, 0.035, fr)
		k.beam(kit, "metal", Vector3(-hw, (eave + ridge) * 0.5 - 0.04, sz * hd * 0.5), Vector3(hw, (eave + ridge) * 0.5 - 0.04, sz * hd * 0.5), 0.024, 0.024, fr)
	k.beam(kit, "metal", Vector3(-hw, ridge - 0.04, 0.0), Vector3(hw, ridge - 0.04, 0.0), 0.038, 0.038, fr)
	# Overhead LED tube lights on the two bays.
	for bx in [-hw * 0.5, hw * 0.5]:
		k.block(kit, "lamp", Vector3(bx - 0.65, eave + 0.08, -0.03), Vector3(bx + 0.65, eave + 0.11, 0.03), Color(1.0, 0.97, 0.88))
	# Roof slopes with raised seam welts and ridge cap.
	var e := 0.05
	var l0 := Vector3(-hw - e, eave, -hd - e)
	var r0 := Vector3(hw + e, eave, -hd - e)
	var l1 := Vector3(-hw - e, eave, hd + e)
	var r1 := Vector3(hw + e, eave, hd + e)
	var t0 := Vector3(-hw - e, ridge, 0)
	var t1 := Vector3(hw + e, ridge, 0)
	var nf := (r0 - l0).cross(t0 - l0).normalized()
	if nf.y < 0.0:
		nf = -nf
	var nb := Vector3(nf.x, nf.y, -nf.z)
	k.panel(kit, "canvas", [l0, r0, t1, t0], nf, col, under)
	k.panel(kit, "canvas", [r1, l1, t0, t1], nb, col, under)
	for rx in [-hw - e, -hw * 0.5, 0.0, hw * 0.5, hw + e]:
		k.beam(kit, "canvas", Vector3(rx, eave, -hd - e) + nf * 0.01, Vector3(rx, ridge, 0) + nf * 0.01, 0.04, 0.018, seam, nf)
		k.beam(kit, "canvas", Vector3(rx, eave, hd + e) + nb * 0.01, Vector3(rx, ridge, 0) + nb * 0.01, 0.04, 0.018, seam, nb)
	k.beam(kit, "canvas", t0 + Vector3(0, 0.015, 0), t1 + Vector3(0, 0.015, 0), 0.12, 0.035, accent, Vector3.UP)
	# Gable triangles with louvred gable vents at both ends.
	k.tri(kit, "canvas", l0, t0, l1, Vector3.LEFT, Vector3.LEFT, Vector3.LEFT, col, Vector3.LEFT)
	k.tri(kit, "canvas", l0, l1, t0, Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT, under, Vector3.RIGHT)
	k.tri(kit, "canvas", r0, r1, t1, Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT, col, Vector3.RIGHT)
	k.tri(kit, "canvas", r0, t1, r1, Vector3.LEFT, Vector3.LEFT, Vector3.LEFT, under, Vector3.LEFT)
	for sx: float in [-1.0, 1.0]:
		var gx := sx * (hw + e + 0.012)
		var gn := Vector3(sx, 0, 0)
		k.tri(kit, "matte", Vector3(gx, ridge - 0.42, -0.35), Vector3(gx, ridge - 0.14, 0.0), Vector3(gx, ridge - 0.42, 0.35), gn, gn, gn, Color(0.14, 0.15, 0.17), gn)
	# Valance round all four sides with team racing stripes.
	var vh := 0.28
	for i in range(4):
		var a: Vector3 = [l0, r0, r1, l1][i]
		var b: Vector3 = [r0, r1, l1, l0][i]
		var outn := Vector3((a + b).x, 0.0, (a + b).z).normalized()
		k.panel(kit, "canvas", [a, b, b - Vector3(0, vh, 0), a - Vector3(0, vh, 0)], outn, col.lightened(0.03), under)
		k.quad(kit, "canvas", [a - Vector3(0, 0.14, 0) + outn * 0.006, b - Vector3(0, 0.14, 0) + outn * 0.006,
				b - Vector3(0, 0.20, 0) + outn * 0.006, a - Vector3(0, 0.20, 0) + outn * 0.006], outn, accent)
		k.quad(kit, "canvas", [a - Vector3(0, 0.21, 0) + outn * 0.006, b - Vector3(0, 0.21, 0) + outn * 0.006,
				b - Vector3(0, 0.245, 0) + outn * 0.006, a - Vector3(0, 0.245, 0) + outn * 0.006], outn, stripe2)
	# Back wall with interior pit livery stripe.
	var bz := hd + 0.03
	k.panel(kit, "canvas", [Vector3(-hw, 0.03, bz), Vector3(hw, 0.03, bz), Vector3(hw, eave, bz), Vector3(-hw, eave, bz)],
			Vector3(0, 0, 1), col.lightened(0.04), under.lightened(0.12))
	k.quad(kit, "canvas", [Vector3(-hw + 0.06, 0.92, bz - 0.008), Vector3(hw - 0.06, 0.92, bz - 0.008),
			Vector3(hw - 0.06, 1.22, bz - 0.008), Vector3(-hw + 0.06, 1.22, bz - 0.008)], Vector3(0, 0, -1), accent)
	k.quad(kit, "canvas", [Vector3(-hw + 0.06, 0.85, bz + 0.008), Vector3(hw - 0.06, 0.85, bz + 0.008),
			Vector3(hw - 0.06, 1.12, bz + 0.008), Vector3(-hw + 0.06, 1.12, bz + 0.008)], Vector3(0, 0, 1), accent)
	# Side walls with 3-pane marquee PVC windows and white mullions.
	for sx: float in [-1.0, 1.0]:
		var wx := sx * (hw + 0.03)
		var sn := Vector3(sx, 0, 0)
		k.panel(kit, "canvas", [Vector3(wx, 0.03, -hd), Vector3(wx, 0.03, hd), Vector3(wx, eave, hd), Vector3(wx, eave, -hd)],
				sn, col.lightened(0.04), under.lightened(0.12))
		var gx := wx + sx * 0.012
		var fx := wx + sx * 0.018
		for pane in range(3):
			var z0 := -0.88 + pane * 0.60
			var z1 := z0 + 0.52
			k.quad(kit, "glass", [Vector3(gx, 0.86, z0), Vector3(gx, 0.86, z1), Vector3(gx, 1.72, z1), Vector3(gx, 1.72, z0)],
					sn, Color(0.14, 0.24, 0.36, 0.72))
			for edge in [[z0, 0.86, z1, 0.86], [z0, 1.72, z1, 1.72], [z0, 0.86, z0, 1.72], [z1, 0.86, z1, 1.72], [z0, 1.29, z1, 1.29], [(z0 + z1) * 0.5, 0.86, (z0 + z1) * 0.5, 1.72]]:
				k.beam(kit, "paint", Vector3(fx, float(edge[1]), float(edge[0])), Vector3(fx, float(edge[3]), float(edge[2])), 0.028, 0.016, WHITE, sn)
	# Front entrance: tied-back curtain drapes on the three front posts.
	for px in [-hw, 0.0, hw]:
		var dx := -signf(px) * 0.14 if absf(px) > 0.1 else 0.0
		var fz := -hd - 0.02
		k.tube(kit, "canvas", Vector3(px + dx, eave - 0.24, fz), Vector3(px + dx * 0.35, 1.05, fz), 0.18, 0.075, 7, col.lightened(0.06))
		k.tube(kit, "canvas", Vector3(px + dx * 0.35, 1.05, fz), Vector3(px + dx * 0.75, 0.05, fz), 0.075, 0.15, 7, col.lightened(0.06))
		k.tube(kit, "canvas", Vector3(px + dx * 0.35, 1.02, fz), Vector3(px + dx * 0.35, 1.08, fz), 0.084, 0.084, 7, accent)
	# Inside: two workbenches, an RC buggy on a stand, a rolling tool chest, and a charger.
	var b0 := k.xf
	k.set_frame(b0 * Transform3D(Basis(), Vector3(-1.35, 0, 0.55)))
	_camp.folding_table(kit, WHITE)
	k.set_frame(b0 * Transform3D(Basis(Vector3.UP, 0.18), Vector3(-1.45, 0, 0.55)))
	_rc_buggy(kit, accent, 0.74)
	k.set_frame(b0 * Transform3D(Basis(Vector3.UP, -0.25), Vector3(-0.95, 0, 0.52)))
	_charger(kit, 0.74)
	k.set_frame(b0 * Transform3D(Basis(), Vector3(1.25, 0, 0.55)))
	_camp.folding_table(kit, WHITE)
	k.set_frame(b0 * Transform3D(Basis(Vector3.UP, -0.15), Vector3(1.15, 0, 0.55)))
	_rc_buggy(kit, Color(0.15, 0.55, 0.88), 0.74)
	k.set_frame(b0 * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-2.45, 0, 0.75)))
	_tool_chest(kit, accent)
	k.set_frame(b0 * Transform3D(Basis(Vector3.UP, 0.2), Vector3(2.35, 0, 0.85)))
	_camp.cooler(kit, accent, WHITE)
	k.set_frame(b0)


## A portable toilet at life size: a moulded cabin with a door at the front, a pale roof and a vent.
func _toilet(kit: Dictionary, col: Color) -> void:
	var k := _kit
	k.block(kit, "plastic", Vector3(-0.6, 0.0, -0.6), Vector3(0.6, 0.12, 0.6), col.darkened(0.25))
	k.block(kit, "plastic", Vector3(-0.56, 0.12, -0.56), Vector3(0.56, 2.15, 0.56), col)
	k.block(kit, "plastic", Vector3(-0.6, 2.15, -0.6), Vector3(0.6, 2.24, 0.6), Color(0.92, 0.92, 0.88))
	k.lathe(kit, "plastic", Vector3(0, 2.24, 0), [Vector2(0.55, 0.0), Vector2(0.45, 0.06), Vector2(0.2, 0.1), Vector2(0.0, 0.11)], 10, Color(0.92, 0.92, 0.88))
	k.tube(kit, "plastic", Vector3(0.38, 2.2, 0.38), Vector3(0.38, 2.55, 0.38), 0.05, 0.05, 8, Color(0.2, 0.2, 0.22))
	# The door: a moulded panel, a handle, the vacant flag and a vent.
	k.block(kit, "plastic", Vector3(-0.4, 0.16, -0.575), Vector3(0.4, 2.0, -0.56), col.lightened(0.06))
	k.block(kit, "plastic", Vector3(0.28, 1.0, -0.6), Vector3(0.33, 1.12, -0.575), Color(0.15, 0.15, 0.16))
	k.block(kit, "plastic", Vector3(0.22, 1.18, -0.59), Vector3(0.34, 1.23, -0.575), Color(0.2, 0.75, 0.25))
	for r in range(3):
		k.block(kit, "plastic", Vector3(-0.25, 1.75 + r * 0.06, -0.59), Vector3(0.25, 1.78 + r * 0.06, -0.575), col.darkened(0.3))


# ======================================================================================
#  Race control, the camera tower, the lap towers
# ======================================================================================

## A race-control booth by the gantry: a cream cabin on a plinth, tinted windows on three sides, a
## dark overhanging roof with a RACE CONTROL fascia, its door and steps at the back.
func _build_race_control(root: Node3D) -> void:
	var fr := _frame(BOOTH.x)
	var at := _at(BOOTH.x, BOOTH.y)
	at.y = _ground_min(at.x, at.z, 1.6)
	var yaw := _yaw_to(fr["right"])
	var kit := {}
	_kit.set_frame(_place(at, yaw))
	var k := _kit
	var wall := Color(0.86, 0.80, 0.66)
	var trim := Color(0.95, 0.95, 0.93)
	var glass := Color(0.20, 0.38, 0.62, 0.78)
	var h := 2.35
	k.block(kit, "paint", Vector3(-1.08, -0.3, -1.08), Vector3(1.08, 0.14, 1.08), Color(0.55, 0.55, 0.53))
	k.block(kit, "paint", Vector3(-1.0, 0.14, -1.0), Vector3(1.0, h, 1.0), wall)
	# Windows: tinted glass with white frames, on the front and both sides.
	var wins := [[Vector3(0, 0, -1), Vector3(1, 0, 0), 1.5, 1.0], [Vector3(-1, 0, 0), Vector3(0, 0, -1), 1.1, 1.0], [Vector3(1, 0, 0), Vector3(0, 0, 1), 1.1, 1.0]]
	for w in wins:
		var n: Vector3 = w[0]
		var r: Vector3 = w[1]
		var ww: float = w[2]
		var c: Vector3 = n * 1.0 + Vector3(0, 1.45, 0)
		var hw2: float = ww * 0.5
		var hh: float = float(w[3]) * 0.5
		k.quad(kit, "glass", [c - r * hw2 - Vector3(0, hh, 0) + n * 0.012, c + r * hw2 - Vector3(0, hh, 0) + n * 0.012,
				c + r * hw2 + Vector3(0, hh, 0) + n * 0.012, c - r * hw2 + Vector3(0, hh, 0) + n * 0.012], n, glass)
		for e in [[-hw2, -hh, hw2, -hh], [-hw2, hh, hw2, hh], [-hw2, -hh, -hw2, hh], [hw2, -hh, hw2, hh]]:
			k.beam(kit, "paint", c + r * float(e[0]) + Vector3(0, float(e[1]), 0) + n * 0.03, c + r * float(e[2]) + Vector3(0, float(e[3]), 0) + n * 0.03, 0.07, 0.05, trim, n)
		k.beam(kit, "paint", c - r * hw2 + Vector3(0, -hh, 0) + n * 0.03, c + r * hw2 + Vector3(0, -hh, 0) + n * 0.03, 0.06, 0.03, trim, n)
	# Door, its window and the steps at the back.
	k.block(kit, "paint", Vector3(0.1, 0.16, 1.0), Vector3(0.88, 2.05, 1.022), Color(0.30, 0.32, 0.36))
	k.quad(kit, "glass", [Vector3(0.3, 1.45, 1.024), Vector3(0.68, 1.45, 1.024), Vector3(0.68, 1.85, 1.024), Vector3(0.3, 1.85, 1.024)], Vector3(0, 0, 1), glass)
	k.block(kit, "chrome", Vector3(0.18, 1.0, 1.022), Vector3(0.24, 1.04, 1.06), Color(0.8, 0.8, 0.82))
	k.block(kit, "paint", Vector3(0.0, -0.3, 1.08), Vector3(1.0, 0.1, 1.5), Color(0.55, 0.55, 0.53))
	# Roof: a dark slab overhanging all round, deeper over the front, a fascia carrying the name.
	k.block(kit, "paint", Vector3(-1.22, h, -1.4), Vector3(1.22, h + 0.16, 1.18), Color(0.20, 0.21, 0.23))
	k.block(kit, "paint", Vector3(-1.24, h - 0.06, -1.42), Vector3(1.24, h + 0.2, -1.38), Color(0.06, 0.10, 0.22))
	k.block(kit, "paint", Vector3(0.55, h + 0.16, 0.2), Vector3(0.95, h + 0.4, 0.8), Color(0.75, 0.76, 0.78))
	k.tube(kit, "metal", Vector3(-0.8, h + 0.16, 0.7), Vector3(-0.8, h + 1.4, 0.7), 0.02, 0.012, 5, GALV)
	_commit(root, kit, "RaceControl")
	var label := Label3D.new()
	label.name = "RaceControlSign"
	label.text = "RACE CONTROL"
	label.font = _bold_font()
	label.font_size = 64
	label.pixel_size = 0.0042 * PROP_SCALE
	label.modulate = Color(1, 1, 1)
	label.outline_size = 0
	label.double_sided = false
	label.transform = _place(at, yaw) * Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE / PROP_SCALE), Vector3(0, h + 0.07, -1.43))
	root.add_child(label)
	_boxes_body(root, "RaceControlBody", [[at + Vector3(0, 1.2 * PROP_SCALE, 0), Vector3(2.1, 2.6, 2.1) * PROP_SCALE, Basis(Vector3.UP, yaw)]])
	_note("RaceControl", at, 1.5 * PROP_SCALE, 1.2)


var _font: SystemFont

func _bold_font() -> SystemFont:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["Arial Black", "Impact", "Helvetica Neue", "Arial", "sans-serif"])
		_font.font_weight = 900
	return _font


## A scaffold tower `w` x `d` with its working platform at `plat`: standards, ledgers, facade braces,
## boards with toe boards and guard rails, a ladder up the back.
func _scaffold(kit: Dictionary, w: float, d: float, plat: float) -> void:
	var k := _kit
	var r := 0.024
	var hx := w * 0.5
	var hz := d * 0.5
	var top := plat + 1.05
	var cs := [Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz)]
	for c in cs:
		k.tube(kit, "metal", c, c + Vector3(0, top, 0), r, r, 6, GALV)
		k.block(kit, "metal", c - Vector3(0.08, 0, 0.08), c + Vector3(0.08, 0.012, 0.08), GALV.darkened(0.2))
	var levels: Array = [0.18, plat * 0.5, plat - 0.02, plat + 0.5, plat + 1.0]
	for y in levels:
		for i in range(4):
			var a: Vector3 = cs[i]
			var b: Vector3 = cs[(i + 1) % 4]
			k.tube(kit, "metal", a + Vector3(0, y, 0), b + Vector3(0, y, 0), r, r, 6, GALV)
	for i in range(4):
		var a: Vector3 = cs[i]
		var b: Vector3 = cs[(i + 1) % 4]
		var flip := i % 2 == 0
		for lift in range(2):
			var y0: float = levels[lift]
			var y1: float = levels[lift + 1]
			if flip:
				k.tube(kit, "metal", a + Vector3(0, y0, 0), b + Vector3(0, y1, 0), r * 0.85, r * 0.85, 5, GALV)
			else:
				k.tube(kit, "metal", b + Vector3(0, y0, 0), a + Vector3(0, y1, 0), r * 0.85, r * 0.85, 5, GALV)
			flip = not flip
	# Platform boards, toe boards.
	var wood := Color(0.62, 0.48, 0.30)
	var nb := 5
	for b in range(nb):
		var z0 := -hz + d * b / nb + 0.01
		var z1 := -hz + d * (b + 1) / nb - 0.01
		k.block(kit, "wood", Vector3(-hx, plat, z0), Vector3(hx, plat + 0.05, z1), wood.darkened(0.06 * (b % 2)))
	var toe := Color(0.95, 0.75, 0.12)
	k.block(kit, "paint", Vector3(-hx, plat + 0.05, -hz - 0.03), Vector3(hx, plat + 0.2, -hz), toe)
	k.block(kit, "paint", Vector3(-hx, plat + 0.05, hz), Vector3(hx, plat + 0.2, hz + 0.03), toe)
	k.block(kit, "paint", Vector3(-hx - 0.03, plat + 0.05, -hz), Vector3(-hx, plat + 0.2, hz), toe)
	k.block(kit, "paint", Vector3(hx, plat + 0.05, -hz), Vector3(hx + 0.03, plat + 0.2, hz), toe)
	# Ladder up the back.
	var lz := hz + 0.12
	for sx in [-0.22, 0.22]:
		k.tube(kit, "metal", Vector3(sx, 0, lz), Vector3(sx, plat + 0.9, lz), 0.02, 0.02, 5, GALV)
	var y := 0.3
	while y < plat + 0.6:
		k.tube(kit, "metal", Vector3(-0.22, y, lz), Vector3(0.22, y, lz), 0.014, 0.014, 5, GALV)
		y += 0.3


func _build_camera_tower(root: Node3D) -> void:
	var fr := _frame(CAMERA_TOWER.x)
	var at := _at(CAMERA_TOWER.x, CAMERA_TOWER.y)
	at.y = _ground_min(at.x, at.z, 1.8)
	var yaw := _yaw_to(fr["right"])
	var kit := {}
	_kit.set_frame(_place(at, yaw))
	var plat := 3.3
	_scaffold(kit, 2.0, 2.0, plat)
	# A broadcast camera on its tripod at the front of the platform, aimed down the straight.
	var base := _kit.xf
	_kit.set_frame(base * Transform3D(Basis(Vector3.UP, 0.5), Vector3(0.1, plat + 0.05, -0.35)))
	_camera_rig(kit)
	_kit.set_frame(base)
	_commit(root, kit, "CameraTower")
	var hx := 1.0 * PROP_SCALE
	var boxes: Array = []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			boxes.append([Transform3D(Basis(Vector3.UP, yaw), at) * Vector3(sx * hx, 2.6, sz * hx), Vector3(0.14, 5.2, 0.14), Basis(Vector3.UP, yaw)])
	boxes.append([at + Vector3(0, (plat + 0.03) * PROP_SCALE, 0), Vector3(2.0, 0.1, 2.0) * PROP_SCALE, Basis(Vector3.UP, yaw)])
	_boxes_body(root, "CameraTowerBody", boxes)
	_note("CameraTower", at, 1.45 * PROP_SCALE, 1.0)


## A broadcast camera on a tripod (life size, lens toward -z).
func _camera_rig(kit: Dictionary) -> void:
	var k := _kit
	var dark := Color(0.08, 0.08, 0.09)
	var head := Vector3(0, 1.35, 0)
	for i in range(3):
		var a := TAU * i / 3.0 + 0.3
		k.tube(kit, "metal", head - Vector3(0, 0.08, 0), Vector3(cos(a) * 0.42, 0.0, sin(a) * 0.42), 0.016, 0.012, 5, dark)
	k.block(kit, "plastic", head + Vector3(-0.12, 0.0, -0.3), head + Vector3(0.12, 0.26, 0.28), Color(0.15, 0.15, 0.16))
	k.tube(kit, "plastic", head + Vector3(0, 0.13, -0.3), head + Vector3(0, 0.13, -0.7), 0.09, 0.075, 12, dark)
	k.tube(kit, "glass", head + Vector3(0, 0.13, -0.7), head + Vector3(0, 0.13, -0.705), 0.074, 0.074, 12, Color(0.2, 0.3, 0.45, 0.9))
	k.block(kit, "plastic", head + Vector3(0.12, 0.12, -0.05), head + Vector3(0.28, 0.24, 0.12), dark)
	k.tube(kit, "metal", head + Vector3(-0.05, 0.05, 0.28), head + Vector3(-0.25, -0.05, 0.6), 0.012, 0.012, 5, dark)
	k.tube(kit, "metal", head + Vector3(0.05, 0.05, 0.28), head + Vector3(0.25, -0.05, 0.6), 0.012, 0.012, 5, dark)


## The lap boards: lattice towers carrying an RC VIBE panel over an LED display (LapBoard.gd), one
## at the corner's outside by the lake and one beside the straight, both facing the run to the line.
func _build_lap_towers(root: Node3D) -> void:
	var specs := [[LAP_TOWER_CORNER, "LapBoardCorner"], [LAP_TOWER_STRAIGHT, "LapBoardStraight"]]
	for sp in specs:
		var v: Vector2 = sp[0]
		var fr := _frame(v.x)
		var at := _at(v.x, v.y)
		at.y = _ground_min(at.x, at.z, 1.2)
		# Face back down the straight, toward the grid, turned a little toward the road.
		var face: Vector3 = (-(fr["fwd"] as Vector3) + (fr["right"] as Vector3) * (-signf(v.y)) * 0.55).normalized()
		var yaw := _yaw_to(face)
		var kit := {}
		_kit.set_frame(_place(at, yaw))
		var tops := _lap_tower(kit)
		var node := Node3D.new()
		node.name = String(sp[1])
		node.set_script(load("res://LapBoard.gd"))
		root.add_child(node)
		var xf := _place(at, yaw)
		node.transform = Transform3D(Basis(Vector3.UP, yaw), at)
		_commit(root, kit, String(sp[1]) + "Mesh")
		var brand := Label3D.new()
		brand.name = "Brand"
		brand.text = "RC VIBE"
		brand.font = _bold_font()
		brand.font_size = 96
		brand.pixel_size = 0.0068
		brand.outline_size = 0
		brand.double_sided = false
		brand.modulate = Color(1, 1, 1)
		brand.transform = Transform3D(Basis(Vector3.UP, PI), (tops[0] as Vector3) * PROP_SCALE)
		node.add_child(brand)
		var lap := Label3D.new()
		lap.name = "Lap"
		lap.text = "LAP 1"
		lap.font = _bold_font()
		lap.font_size = 96
		lap.pixel_size = 0.0088
		lap.outline_size = 0
		lap.shaded = false
		lap.double_sided = false
		lap.modulate = Color(1.0, 0.70, 0.16)
		lap.transform = Transform3D(Basis(Vector3.UP, PI), (tops[1] as Vector3) * PROP_SCALE)
		node.add_child(lap)
		node.set("label_path", NodePath("Lap"))
		var boxes: Array = []
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				boxes.append([xf * Vector3(sx * 0.6, 0.0, sz * 0.6) + Vector3(0, 2.9, 0), Vector3(0.16, 5.8, 0.16), Basis(Vector3.UP, yaw)])
		_boxes_body(root, String(sp[1]) + "Body", boxes)
		_note(String(sp[1]), at, 1.0 * PROP_SCALE, 1.5)


## A lattice tower (life size, 1.2m square, 3.6m tall) under a sign box 2.6 x 1.9m. Returns the
## centres (local, on the front face) for the brand and the lap text.
func _lap_tower(kit: Dictionary) -> Array:
	var k := _kit
	var leg := Color(0.30, 0.31, 0.33)
	var h := 3.6
	var hx := 0.6
	var cs := [Vector3(-hx, 0, -hx), Vector3(hx, 0, -hx), Vector3(hx, 0, hx), Vector3(-hx, 0, hx)]
	for c in cs:
		k.box(kit, "steel", Transform3D(Basis(Vector3.UP, PI * 0.25), c + Vector3(0, h * 0.5, 0)), Vector3(0.07, h, 0.07), leg)
		k.block(kit, "paint", c + Vector3(-0.16, -0.25, -0.16), c + Vector3(0.16, 0.06, 0.16), Color(0.55, 0.55, 0.53))
	var lv := [0.3, 1.1, 1.9, 2.7, 3.5]
	for y in lv:
		for i in range(4):
			var a: Vector3 = cs[i]
			var b: Vector3 = cs[(i + 1) % 4]
			k.beam(kit, "steel", a + Vector3(0, y, 0), b + Vector3(0, y, 0), 0.045, 0.045, leg)
	for i in range(4):
		var a: Vector3 = cs[i]
		var b: Vector3 = cs[(i + 1) % 4]
		for j in range(lv.size() - 1):
			var y0: float = lv[j]
			var y1: float = lv[j + 1]
			k.beam(kit, "steel", a + Vector3(0, y0, 0), b + Vector3(0, y1, 0), 0.03, 0.03, leg)
			k.beam(kit, "steel", b + Vector3(0, y0, 0), a + Vector3(0, y1, 0), 0.03, 0.03, leg)
	# The sign box: a steel frame, the RC VIBE panel over the LED display, a grey back.
	var y0 := h
	var y1 := h + 1.95
	var hw := 1.3
	k.block(kit, "steel", Vector3(-hw, y0, -0.2), Vector3(hw, y1, 0.2), Color(0.18, 0.19, 0.21))
	var navy := Color(0.07, 0.10, 0.18)
	k.block(kit, "paint", Vector3(-hw + 0.08, y0 + 0.95, -0.215), Vector3(hw - 0.08, y1 - 0.08, -0.2), navy)
	k.block(kit, "paint", Vector3(-hw + 0.08, y0 + 0.08, -0.215), Vector3(hw - 0.08, y0 + 0.88, -0.2), Color(0.02, 0.02, 0.025))
	k.block(kit, "steel", Vector3(-hw - 0.05, y1, -0.25), Vector3(hw + 0.05, y1 + 0.06, 0.25), Color(0.14, 0.14, 0.15))
	return [Vector3(0, y0 + 1.42, -0.225), Vector3(0, y0 + 0.47, -0.225)]


# ======================================================================================
#  Fences, barriers, tyre walls, hay, cones
# ======================================================================================

## Catch fences: chain link on posts with sponsor boards along their foot on the road side. One runs
## up the straight's right side; another round the corner's outside and along the east leg in front
## of the grandstand.
func _build_fences(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "CatchFences"
	root.add_child(node)
	var runs := [
		[3134.0, 3294.0, FENCE_LAT, "FenceStraight"],
		[3294.0, 108.0, -12.2, "FenceCorner"],
	]
	for r in runs:
		var pts := _offset_run(float(r[0]), float(r[1]), float(r[2]), 0.5)
		_fence(node, pts, -signf(float(r[2])), String(r[3]))


## A fence along `pts` (ground points), the road on side `road_side` of its direction (+1 right).
func _fence(parent: Node3D, pts: PackedVector3Array, road_side: float, node_name: String) -> void:
	var kit := {}
	var k := _kit
	k.reset_frame()
	var spacing := 3.0 * PROP_SCALE
	var height := 2.0 * PROP_SCALE
	# Posts every `spacing` by length along the run.
	var posts: Array = []
	var acc := 0.0
	posts.append(pts[0])
	for i in range(1, pts.size()):
		acc += Vector2(pts[i].x - pts[i - 1].x, pts[i].z - pts[i - 1].z).length()
		if acc >= spacing - 0.25:
			posts.append(pts[i])
			acc = 0.0
	var boxes: Array = []
	for i in range(posts.size()):
		var p: Vector3 = posts[i]
		k.tube(kit, "metal", p - Vector3(0, 0.4, 0), p + Vector3(0, height + 0.05, 0), 0.05, 0.05, 8, GALV)
		k.lathe(kit, "metal", p + Vector3(0, height + 0.05, 0), [Vector2(0.065, 0.0), Vector2(0.06, 0.04), Vector2(0.0, 0.07)], 8, GALV)
		if i == 0:
			continue
		var q: Vector3 = posts[i - 1]
		var d := p - q
		d.y = 0.0
		var dl := d.length()
		var along := d / maxf(dl, 1e-4)
		var face := Vector3(-along.z, 0.0, along.x) * road_side
		k.tube(kit, "metal", q + Vector3(0, height, 0), p + Vector3(0, height, 0), 0.03, 0.03, 6, GALV)
		k.tube(kit, "metal", q + Vector3(0, 0.12, 0), p + Vector3(0, 0.12, 0), 0.008, 0.008, 4, GALV)
		# The mesh: UVs in metres (the material tiles it).
		var u0 := 0.0
		var u1 := dl
		k.quad(kit, "chainlink", [q + Vector3(0, 0.06, 0), p + Vector3(0, 0.06, 0), p + Vector3(0, height, 0), q + Vector3(0, height, 0)], face, WHITE,
				[Vector2(u0, height), Vector2(u1, height), Vector2(u1, 0.06), Vector2(u0, 0.06)])
		boxes.append(_wall_box(q, p, 0.3, height))
		_note(node_name, (p + q) * 0.5, 0.1, 2.5)
	# Sponsor boards along the foot on the road side: across two bays where the fence runs straight
	# on (8:1, the artwork's shape), across one round a bend.
	var i2 := 1
	while i2 < posts.size():
		var q2: Vector3 = posts[i2 - 1]
		var p2: Vector3 = posts[i2]
		var span := 1
		if i2 + 1 < posts.size():
			var p3: Vector3 = posts[i2 + 1]
			var d1 := Vector2(p2.x - q2.x, p2.z - q2.z).normalized()
			var d2 := Vector2(p3.x - p2.x, p3.z - p2.z).normalized()
			if d1.dot(d2) > 0.9986:
				span = 2
				p2 = p3
		var dd := p2 - q2
		dd.y = 0.0
		var al := dd.normalized()
		var face2 := Vector3(-al.z, 0.0, al.x) * road_side
		var off := face2 * 0.09
		var lo := minf(q2.y, p2.y)
		_ad_board(kit, Vector3(q2.x, lo, q2.z) + off + Vector3(0, 0.14, 0), Vector3(p2.x, lo, p2.z) + off + Vector3(0, 0.14, 0), 1.2, face2, _next_ad())
		i2 += span
	_commit(parent, kit, node_name)
	_boxes_body(parent, node_name + "Body", boxes)


## Crowd barriers along the straight's left side, from behind the grid to the corner, leaving gaps
## at race control, the camera tower and the paddock's entrance.
func _build_barriers(root: Node3D) -> void:
	var kit := {}
	var pts := _offset_run(3140.0, 3300.0, BARRIER_LAT, 0.25)
	var length := 2.3 * PROP_SCALE
	var gaps := [Vector2(BOOTH.x - 3.5, BOOTH.x + 3.0), Vector2(CAMERA_TOWER.x - 3.0, CAMERA_TOWER.x + 3.0), Vector2(3288.0, 3294.0)]
	var boxes: Array = []
	var i := 0
	var acc := 0.0
	var start: Vector3 = pts[0]
	while i < pts.size() - 1:
		i += 1
		acc = Vector2(pts[i].x - start.x, pts[i].z - start.z).length()
		if acc < length:
			continue
		var a: Vector3 = start
		var b: Vector3 = pts[i]
		start = b
		var mid := (a + b) * 0.5
		var s_mid := _curve.get_closest_offset(Vector3(mid.x, 0, mid.z))
		var skip := false
		for g in gaps:
			if s_mid > g.x and s_mid < g.y:
				skip = true
		if skip:
			continue
		# A frame from foot to foot, sheared to the slope so the uprights stay vertical.
		var x := (b - a) / 2.3
		var z := Vector3(-x.z, 0, x.x).normalized() * PROP_SCALE
		var bx := Basis(x, Vector3(0, PROP_SCALE, 0), z)
		_kit.set_frame(Transform3D(bx, (a + b) * 0.5))
		_camp.crowd_barrier(kit)
		boxes.append(_wall_box(a, b, 0.25, 1.1 * PROP_SCALE))
	_commit(root, kit, "CrowdBarriers")
	_boxes_body(root, "CrowdBarriersBody", boxes)


const TYRE_COLS := [Color(0.80, 0.10, 0.09), Color(0.92, 0.92, 0.90), Color(0.07, 0.07, 0.08)]

## Tyre walls: stacks of three, red, white and black in turn, along the curb behind the grid on the
## right and round the outside of the first corner.
func _build_tyre_walls(root: Node3D) -> void:
	var runs := [[3132.0, 3204.0, TYRE_LAT, "TyreWallGrid"], [3289.0, 27.0, -TYRE_LAT, "TyreWallCorner"]]
	for r in runs:
		var pts := _offset_run(float(r[0]), float(r[1]), float(r[2]), 0.995 * PROP_SCALE * 0.62)
		var kit := {}
		var boxes: Array = []
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(String(r[3]))
		for i in range(pts.size()):
			var p: Vector3 = pts[i]
			_kit.set_frame(_place(p, rng.randf() * TAU))
			var col: Color = TYRE_COLS[i % 3]
			for t in range(3):
				var j := Vector3(rng.randf_range(-0.02, 0.02), 0.0, rng.randf_range(-0.02, 0.02))
				_kit.tyre(kit, "rubber", Vector3(0, 0.1 + t * 0.2, 0) + j, 0.19, 0.31, 0.2, 14, col.darkened(rng.randf_range(0.0, 0.12)))
			if i > 0 and (i % 4 == 0 or i == pts.size() - 1):
				boxes.append(_wall_box(pts[maxi(i - 4, 4 * ((i - 1) / 4))], p, 0.62 * PROP_SCALE, 0.6 * PROP_SCALE))
		_commit(root, kit, String(r[3]))
		_boxes_body(root, String(r[3]) + "Body", boxes)
		for p in pts:
			_note(String(r[3]), p, 0.5, 1.2)


## Big square bales round the first corner and loose cones along the verges by the gantry.
func _build_hay_and_cones(root: Node3D) -> void:
	var kit := {}
	var boxes: Array = []
	# Inside the corner they stand along its bisector, clear of both legs; one on the outside.
	var apex := _curve.sample_baked(0.0)
	var into := (_curve.sample_baked(_length - 6.0) - apex)
	var out_of := (_curve.sample_baked(6.0) - apex)
	into.y = 0.0
	out_of.y = 0.0
	var bis := (into.normalized() + out_of.normalized()).normalized()
	var bales: Array = []
	for d in [[16.5, 0.0, 0.0], [19.5, -1.4, 0.5], [19.0, 1.6, -0.3], [23.0, 0.2, 1.1]]:
		var p: Vector3 = apex + bis * float(d[0]) + Vector3(-bis.z, 0, bis.x) * float(d[1])
		bales.append([p, _yaw_to(Vector3(-bis.z, 0, bis.x)) + float(d[2])])
	bales.append([_at(3297.0, -13.4), _yaw_to(_frame(3297.0)["fwd"]) + 0.1])
	for b in bales:
		var at: Vector3 = b[0]
		at.y = _ground_min(at.x, at.z, 1.2)
		var yaw: float = b[1]
		_kit.set_frame(_place(at, yaw))
		_hay_bale(kit)
		boxes.append([at + Vector3(0, 0.45 * PROP_SCALE, 0), Vector3(1.0, 0.9, 2.0) * PROP_SCALE, Basis(Vector3.UP, yaw)])
		_note("HayBale", at, 1.1 * PROP_SCALE, 1.5)
	# A stack: two bales with one on top, beside the corner's lap tower.
	var st := _at(3306.0, -19.5)
	var yaw2 := _yaw_to(_frame(3306.0)["fwd"])
	for p in [Vector3(0, 0, -0.55), Vector3(0, 0, 0.55), Vector3(0.0, 0.9, 0.0)]:
		_kit.set_frame(_place(st, yaw2) * Transform3D(Basis(Vector3.UP, PI * 0.5), p))
		_hay_bale(kit)
	boxes.append([st + Vector3(0, 0.9 * PROP_SCALE, 0), Vector3(2.0, 1.8, 2.1) * PROP_SCALE, Basis(Vector3.UP, yaw2)])
	_commit(root, kit, "HayBales")
	_boxes_body(root, "HayBalesBody", boxes)
	# Cones: knocked flying by any cart.
	var spots := [[3221.0, -9.4], [3223.0, -9.7], [3225.0, -9.3], [3234.0, -9.5], [3236.5, -9.8], [3239.0, -9.4],
			[3205.0, -9.6], [3210.0, 10.2], [3245.0, 9.6], [3201.5, -9.4]]
	var xfs: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 51
	var cone_at: Array = []
	for c in spots:
		cone_at.append(_at(float(c[0]), float(c[1])))
	# Two marking the first corner's apex, on its bisector just past the curb.
	for d in [11.2, 12.6]:
		var q: Vector3 = apex + bis * d
		q.y = _ground(q.x, q.z)
		cone_at.append(q)
	for p in cone_at:
		xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p))
		_note("Cone", p, 0.3, 0.4)
	var ck := {}
	_kit.set_frame(Transform3D(Basis().scaled(Vector3.ONE * PROP_SCALE), Vector3.ZERO))
	_camp.cone(ck)
	var mesh: Mesh = _save_res(_kit.commit(ck), "cone")
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	mm.buffer = PropKit.transform_buffer(xfs)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Cones"
	mmi.set_script(load("res://KnockableProps.gd"))
	var typed: Array[Transform3D] = []
	for t in xfs:
		typed.append(t)
	mmi.set("prop_transforms", typed)
	mmi.set("boxes", [[Vector3(0, 0.03, 0) * PROP_SCALE, Vector3(0.38, 0.06, 0.38) * PROP_SCALE], [Vector3(0, 0.36, 0) * PROP_SCALE, Vector3(0.2, 0.62, 0.2) * PROP_SCALE]])
	mmi.set("prop_mass", 6.0)
	mmi.set("push_speed", 1.5)
	mmi.set("release_radius", 3.2)
	mmi.set("centre_of_mass_y", 0.06)
	mmi.multimesh = mm
	root.add_child(mmi)


## A big square bale at life size: 2.0 long (x), 1.0 wide, 0.9 high, its edges rounded off, three
## twine bands round it.
func _hay_bale(kit: Dictionary) -> void:
	var k := _kit
	var outline := PackedVector2Array([Vector2(-1.0, 0.04), Vector2(-0.96, 0.0), Vector2(0.96, 0.0), Vector2(1.0, 0.04),
			Vector2(1.0, 0.84), Vector2(0.95, 0.9), Vector2(-0.95, 0.9), Vector2(-1.0, 0.84)])
	k.extrude(kit, "straw", outline, -0.5, 0.5, 0.05, Color(1, 1, 1))
	var tw := Color(0.30, 0.22, 0.12)
	for x in [-0.55, 0.0, 0.55]:
		k.block(kit, "matte", Vector3(x - 0.012, -0.002, -0.508), Vector3(x + 0.012, 0.906, -0.5), tw)
		k.block(kit, "matte", Vector3(x - 0.012, -0.002, 0.5), Vector3(x + 0.012, 0.906, 0.508), tw)
		k.block(kit, "matte", Vector3(x - 0.012, 0.9, -0.5), Vector3(x + 0.012, 0.908, 0.5), tw)


# ======================================================================================
#  The grandstand
# ======================================================================================

## Three aluminium bleacher sections across the first corner, north of the east leg, on their own
## graded footing, facing the corner and the start straight beyond it.
func _build_grandstand(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Grandstand"
	root.add_child(node)
	var kit := {}
	var boxes: Array = []
	var width := 6.2
	var rows := 7
	var sections := 3
	var span := STAND_S.y - STAND_S.x
	for i in range(sections):
		var s: float = STAND_S.x + span * (i + 0.5) / sections
		var fr := _frame(s)
		var right: Vector3 = fr["right"]
		# Front edge on STAND_FRONT_LAT; the stand climbs away from the road (to the left).
		var at := _at(s, STAND_FRONT_LAT)
		at.y = _ground_min(at.x, at.z, 3.0)
		var yaw := _yaw_to(right)
		_kit.set_frame(_place(at, yaw))
		var hull := _bleacher(kit, width, rows)
		var pts := PackedVector3Array()
		var xf := _place(at, yaw)
		for p in hull:
			pts.append(xf * p)
		var body := StaticBody3D.new()
		body.name = "GrandstandBody%d" % i
		node.add_child(body)
		var cs := CollisionShape3D.new()
		var shape := ConvexPolygonShape3D.new()
		shape.points = pts
		cs.shape = shape
		body.add_child(cs)
		_note("Grandstand%d" % i, at + (xf.basis * Vector3(0, 0, 2.6)), 4.0 * PROP_SCALE, 0.5)
	_commit(node, kit, "GrandstandSeats")


## One bleacher section at life size, front toward -z, rows climbing toward +z. Returns the corners
## of its wedge for the collision hull.
func _bleacher(kit: Dictionary, width: float, rows: int) -> Array:
	var k := _kit
	var rd := 0.75
	var rh := 0.4
	var hw := width * 0.5
	var alu := Color(0.78, 0.79, 0.80)
	var steel := Color(0.36, 0.37, 0.40)
	var foot0 := 0.3
	for r in range(rows):
		var z0 := r * rd
		var yf := foot0 + r * rh
		var ys := yf + 0.42
		k.block(kit, "metal", Vector3(-hw, yf - 0.05, z0), Vector3(hw, yf, z0 + 0.32), alu.darkened(0.08))
		k.block(kit, "metal", Vector3(-hw, ys - 0.05, z0 + 0.42), Vector3(hw, ys, z0 + 0.72), alu)
		k.block(kit, "metal", Vector3(-hw, yf, z0 + 0.39), Vector3(hw, ys - 0.05, z0 + 0.41), steel.lightened(0.15))
	var depth := rows * rd
	var top_foot := foot0 + (rows - 1) * rh
	# Frames under it: a stringer following the rows, posts down to the ground, braces.
	var nf := 5
	for f in range(nf):
		var x := -hw + 0.08 + (width - 0.16) * f / (nf - 1)
		k.beam(kit, "steel", Vector3(x, foot0 - 0.12, 0.0), Vector3(x, top_foot + 0.32, depth), 0.08, 0.14, steel)
		var zs := [0.1, depth * 0.33, depth * 0.66, depth - 0.1]
		var prev := Vector3.ZERO
		for zi in range(zs.size()):
			var z: float = zs[zi]
			var y: float = foot0 - 0.12 + (top_foot + 0.44 - foot0) * z / depth
			k.tube(kit, "steel", Vector3(x, -0.3, z), Vector3(x, y, z), 0.045, 0.045, 6, steel)
			k.block(kit, "steel", Vector3(x - 0.1, 0.0, z - 0.1), Vector3(x + 0.1, 0.02, z + 0.1), steel.darkened(0.2))
			if zi > 0:
				k.tube(kit, "steel", Vector3(x, 0.15, prev.z), Vector3(x, y - 0.15, z), 0.025, 0.025, 5, steel)
			prev = Vector3(x, y, z)
	# Guard rails: along the back and down both ends.
	var rail_y := top_foot + 1.05
	for x in [-hw, -hw * 0.33, hw * 0.33, hw]:
		k.tube(kit, "metal", Vector3(x, top_foot, depth - 0.04), Vector3(x, rail_y, depth - 0.04), 0.025, 0.025, 6, alu)
	k.tube(kit, "metal", Vector3(-hw, rail_y, depth - 0.04), Vector3(hw, rail_y, depth - 0.04), 0.025, 0.025, 6, alu)
	k.tube(kit, "metal", Vector3(-hw, rail_y - 0.5, depth - 0.04), Vector3(hw, rail_y - 0.5, depth - 0.04), 0.02, 0.02, 6, alu)
	for sx in [-1.0, 1.0]:
		var x2: float = sx * (hw + 0.03)
		k.tube(kit, "metal", Vector3(x2, foot0 + 0.95, 0.05), Vector3(x2, rail_y, depth - 0.04), 0.022, 0.022, 6, alu)
		k.tube(kit, "metal", Vector3(x2, foot0, 0.05), Vector3(x2, foot0 + 0.95, 0.05), 0.022, 0.022, 6, alu)
		for r in range(1, rows, 2):
			var zr := r * rd + 0.1
			var yr := foot0 + r * rh
			k.tube(kit, "metal", Vector3(x2, yr, zr), Vector3(x2, yr + 0.95, zr), 0.018, 0.018, 5, alu)
	# A kick board along the front.
	k.block(kit, "steel", Vector3(-hw, 0.0, -0.03), Vector3(hw, foot0, 0.0), steel)
	return [Vector3(-hw, 0.0, 0.0), Vector3(hw, 0.0, 0.0), Vector3(-hw, 0.0, depth), Vector3(hw, 0.0, depth),
			Vector3(-hw, foot0 + 0.4, 0.0), Vector3(hw, foot0 + 0.4, 0.0), Vector3(-hw, rail_y, depth), Vector3(hw, rail_y, depth)]


# ======================================================================================
#  The campsite
# ======================================================================================

## Fans' camp on the hill east of the straight: motorhomes, caravans, a pop-top campervan and an
## overland SUV parked on two graded terraces, with a gazebo, dome/tunnel/ridge tents, chairs and a
## barbecue overlooking the race track. The layouts are CampKit's (LAYOUT_MAIN, LAYOUT_PAIR): each
## pitch is placed from its measured footprint, and build_layout reports any two closer than
## CAMP_GAP or off the terrace.
func _build_campsite(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Campsite"
	root.add_child(node)
	var kit := {}
	var gear := {}
	var boxes: Array = []
	# The terrace's +z faces West toward the start straight, -z East toward the hillside woods.
	for t in [[CAMP_TERRACE, CampKit.LAYOUT_MAIN, "main terrace"], [CAMP_UPPER, CampKit.LAYOUT_PAIR, "upper terrace"]]:
		var terrace: Array = t[0]
		var res: Dictionary = _camp.build_layout(kit, gear, t[1], terrace[0], float(terrace[2]), _ground, PROP_SCALE)
		boxes.append_array(res["boxes"])
		if t[0] == CAMP_TERRACE:
			for n in res["notes"]:
				_note(String(n[0]), n[1], float(n[2]), 10.0)
		for pair in res["bad"]:
			push_error("Lakeside camp (%s): %s" % [t[2], pair])
		print("  camp %s: %d pitches, %d too close or off the pad" % [t[2], (res["placed"] as Array).size(), (res["bad"] as PackedStringArray).size()])
	_commit(node, kit, "CampVehicles")
	_commit(node, gear, "CampGear", 240.0)
	_boxes_body(node, "CampsiteBody", boxes)


# ======================================================================================
#  The woods
# ======================================================================================

const FOREST_CELL := 100.0
const FAR_CELL := 250.0
## Trees whose trunk is within this of a road get a collider.
const TRUNK_COLLIDE_REACH := 40.0
## How close to the centreline each kind may stand: its crown must keep off the road (and off the
## decks where the lap runs on bridges).
const TREE_ROAD_CLEAR := {"oak": 19.0, "lime": 17.0, "birch": 14.0, "spruce": 16.0}
const KINDS := ["oak", "lime", "birch", "spruce"]

## Woods on the hills and singles in the meadows: oak, lime, birch and spruce (WoodlandBuilder.gd),
## in Msitu Falls' layers so JungleDetail.gd scales them with the detail level: detailed trees
## near the camera crossfading into their stand-ins (Tree_, TreeFar_), shadow-only stand-ins for the
## detailed ones (TreeShadow_), the deep woods well off the road (TreeDeep_, TreeDeepFar_) and hazel
## along the woods' edges (Plants_). Trunks near the road are solid ("Tree" in the body's name: the
## AI steers round them).
func _build_woodland(root: Node3D) -> void:
	var t0 := Time.get_ticks_msec()
	var node := Node3D.new()
	node.name = "Woodland"
	root.add_child(node)
	var w = Woodland.new()
	w.save_res = func(res: Resource, n: String) -> Resource: return _save_res(res, n)
	var leaf_near: ShaderMaterial = _save_res(w.leaf_material(1, 0.14, 18.0), "leaf_near")
	var leaf_far: ShaderMaterial = _save_res(w.leaf_material(2, 0.14, 18.0), "leaf_far")
	var near_meshes: Array = []
	var far_meshes: Array = []
	var lod_mats: Array[ShaderMaterial] = [leaf_near, leaf_far]
	for kind in KINDS:
		var bn: ShaderMaterial = _save_res(w.bark_material(kind, 1), "bark_%s_near" % kind)
		var bf: ShaderMaterial = _save_res(w.bark_material(kind, 2), "bark_%s_far" % kind)
		lod_mats.append(bn)
		lod_mats.append(bf)
		for v in range(2):
			var nm: ArrayMesh
			var fm: ArrayMesh
			if kind == "spruce":
				nm = w.spruce_mesh(v, 0, bn, leaf_near)
				fm = w.spruce_mesh(v, 1, bf, leaf_far)
			else:
				nm = w.broadleaf_mesh(kind, v, 0, bn, leaf_near)
				fm = w.broadleaf_mesh(kind, v, 1, bf, leaf_far)
			near_meshes.append(_save_res(nm, "tree_%s_%d" % [kind, v]))
			far_meshes.append(_save_res(fm, "tree_%s_%d_far" % [kind, v]))
	var hazel_bark: ShaderMaterial = _save_res(w.bark_material("hazel", 0), "bark_hazel")
	var hazel_leaf: ShaderMaterial = _save_res(w.leaf_material(0, 0.08, 4.0), "leaf_shrub")
	var shrubs: Array = [_save_res(w.shrub_mesh(0, hazel_bark, hazel_leaf), "shrub_hazel_0"), _save_res(w.shrub_mesh(1, hazel_bark, hazel_leaf), "shrub_hazel_1")]
	print("  tree meshes built (%.1fs)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	var forest := FastNoiseLite.new()
	forest.seed = 4711
	forest.frequency = 0.0045
	forest.fractal_octaves = 3
	var kind_noise := FastNoiseLite.new()
	kind_noise.seed = 1913
	kind_noise.frequency = 0.011
	kind_noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var keep_out := _woodland_keep_out()
	var alts: Array = []
	for ap in ["AlternativePaths/AlternativePath1", "AlternativePaths/AlternativePath2"]:
		var pth := _level.get_node_or_null(ap) as Path3D
		if pth:
			alts.append(pth.curve)
	var near := {}
	var far := {}
	var deep_near := {}
	var deep_far := {}
	var plants := {}
	var trunks: Array = []
	var counts := {"oak": 0, "lime": 0, "birch": 0, "spruce": 0, "deep": 0, "shrub": 0}
	var step := 9.5
	var r_max := 845.0
	var x := -r_max
	while x <= r_max:
		var z := -r_max
		while z <= r_max:
			var px: float = x + rng.randf_range(-0.45, 0.45) * step
			var pz: float = z + rng.randf_range(-0.45, 0.45) * step
			z += step
			var roll := rng.randf()
			if px * px + pz * pz > r_max * r_max:
				continue
			var g := _ground(px, pz)
			if g < -9.3:
				continue
			# Woods where the noise is high, thicker on the hills; a scatter of singles elsewhere.
			var f: float = forest.get_noise_2d(px, pz) + clampf((g - 4.0) * 0.012, -0.1, 0.15)
			var dens: float = lerpf(0.035, 0.9, smoothstep(-0.02, 0.28, f))
			if roll > dens:
				# Hazel on the woods' edges.
				if roll < dens + 0.08 and f > -0.12 and f < 0.2:
					_plant_shrub(px, pz, g, rng, keep_out, alts, plants, counts)
				continue
			if _slope(px, pz) > 0.8:
				continue
			# The kind: spruce up high and in stands, birch by water and on the woods' edges, oak and
			# lime between.
			var kn: float = kind_noise.get_noise_2d(px, pz)
			var kind: String = "lime"
			if g > 13.0 and kn > -0.2 or kn > 0.42:
				kind = "spruce"
			elif g < -5.5 or (dens < 0.5 and rng.randf() < 0.45):
				kind = "birch"
			elif kn < -0.12:
				kind = "oak"
			elif rng.randf() < 0.35:
				kind = "oak"
			var rd := _road_distance(px, pz)
			if rd < float(TREE_ROAD_CLEAR[kind]):
				continue
			var alt_ok := true
			for c in alts:
				var cp: Vector3 = (c as Curve3D).get_closest_point(Vector3(px, 0.0, pz))
				if Vector2(cp.x - px, cp.z - pz).length() < float(TREE_ROAD_CLEAR[kind]):
					alt_ok = false
			if not alt_ok or _kept_out(keep_out, px, pz, 4.0):
				continue
			var ki: int = KINDS.find(kind)
			var v: int = rng.randi() % 2
			var mi: int = ki * 2 + v
			var sc: float = rng.randf_range(0.82, 1.18)
			# On a slope the downhill roots would hang in the air: sink the tree a little.
			var y: float = g - 0.2 - minf(_relief(px, pz, 2.5) * 0.6, 1.0)
			var lean := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.04))
			var xf := Transform3D(lean * Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.92, 1.1), sc)), Vector3(px, y, pz))
			var deep: bool = rd > 150.0 and rng.randf() < 0.6
			if deep:
				_add_to_cells(deep_near, _cell(px, pz, FOREST_CELL, mi), xf)
				_add_to_cells(deep_far, _cell(px, pz, FAR_CELL, mi), xf)
				counts["deep"] += 1
			else:
				_add_to_cells(near, _cell(px, pz, FOREST_CELL, mi), xf)
				_add_to_cells(far, _cell(px, pz, FAR_CELL, mi), xf)
			counts[kind] += 1
			if rd < TRUNK_COLLIDE_REACH:
				var tr: float = (0.52 if kind == "oak" else (0.46 if kind == "lime" else (0.21 if kind == "birch" else 0.36))) * sc
				trunks.append([Vector3(px, y, pz), maxf(tr * 1.25, 0.35), 5.0 * sc])
		x += step
	print("  woods: %s (%.1fs)" % [str(counts), (Time.get_ticks_msec() - t0) / 1000.0])
	var near_end: float = Woodland.TREE_NEAR + Woodland.TREE_FADE * 0.5 + Woodland.TREE_FADE_JITTER + FOREST_CELL * 0.72
	for k in near.keys():
		var mmi := _multimesh(near_meshes[k.z], near[k], "Tree_%d_%d_%d" % [k.x, k.y, k.z])
		mmi.visibility_range_end = near_end
		mmi.visibility_range_end_margin = 10.0
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mmi)
		var proxy := _multimesh(far_meshes[k.z], near[k], "TreeShadow_%d_%d_%d" % [k.x, k.y, k.z])
		proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		proxy.visibility_range_end = near_end
		proxy.visibility_range_end_margin = 10.0
		node.add_child(proxy)
	var far_begin: float = maxf(0.0, Woodland.TREE_NEAR - Woodland.TREE_FADE * 0.5 - Woodland.TREE_FADE_JITTER - FAR_CELL * 0.72)
	for k in far.keys():
		var mmi2 := _multimesh(far_meshes[k.z], far[k], "TreeFar_%d_%d_%d" % [k.x, k.y, k.z])
		mmi2.visibility_range_begin = far_begin
		mmi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mmi2)
	for k in deep_near.keys():
		var mmi3 := _multimesh(near_meshes[k.z], deep_near[k], "TreeDeep_%d_%d_%d" % [k.x, k.y, k.z])
		mmi3.visibility_range_end = near_end
		mmi3.visibility_range_end_margin = 10.0
		mmi3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mmi3)
	for k in deep_far.keys():
		var mmi4 := _multimesh(far_meshes[k.z], deep_far[k], "TreeDeepFar_%d_%d_%d" % [k.x, k.y, k.z])
		mmi4.visibility_range_begin = far_begin
		mmi4.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mmi4)
	for k in plants.keys():
		var mmi5 := _multimesh(shrubs[k.z], plants[k], "Plants_%d_%d_%d" % [k.x, k.y, k.z])
		mmi5.visibility_range_end = 150.0 + FOREST_CELL * 0.72
		mmi5.visibility_range_end_margin = 10.0
		mmi5.set_meta(&"base_range", mmi5.visibility_range_end)
		mmi5.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mmi5)
	var bodies := {}
	for t in trunks:
		var p3: Vector3 = t[0]
		var bk := Vector2i(floori(p3.x / FOREST_CELL), floori(p3.z / FOREST_CELL))
		if not bodies.has(bk):
			var body := StaticBody3D.new()
			body.name = "TreeTrunks_%d_%d" % [bk.x, bk.y]
			node.add_child(body)
			bodies[bk] = body
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = t[1]
		cyl.height = t[2]
		cs.shape = cyl
		cs.position = p3 + Vector3(0, cyl.height * 0.5 - 0.4, 0)
		bodies[bk].add_child(cs)
	var detail := Node3D.new()
	detail.name = "JungleDetail"
	detail.set_script(load("res://JungleDetail.gd"))
	detail.set("lod_materials", lod_mats)
	detail.set("tree_fade", Woodland.TREE_FADE)
	detail.set("tree_fade_jitter", Woodland.TREE_FADE_JITTER)
	detail.set("forest_cell", FOREST_CELL)
	node.add_child(detail)
	print("  woodland: %d near cells, %d far, %d deep, %d shrub cells, %d trunk colliders (%.1fs)" % [near.size(), far.size(),
			deep_near.size(), plants.size(), trunks.size(), (Time.get_ticks_msec() - t0) / 1000.0])


## Grey granite boulders in twos and threes about the meadows (the concept's rock clusters), more
## along the lake shores, bedded a third into the ground; moss at their feet, lichen on top
## (granite_rock.gdshader). Those near the road are solid ("Boulders": the AI steers round them).
func _build_boulders(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Boulders"
	root.add_child(node)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://granite_rock.gdshader")
	mat.set_shader_parameter("dust_color", Color(0.30, 0.36, 0.18))
	mat = _save_res(mat, "mat_granite")
	var meshes: Array = []
	var hulls: Array = []
	var shapes := [Vector3(1.0, 0.75, 0.9), Vector3(1.4, 0.55, 1.0), Vector3(0.8, 0.95, 0.75), Vector3(1.1, 0.7, 1.2)]
	for v in range(shapes.size()):
		var res := _rock_mesh(v, shapes[v], mat)
		meshes.append(_save_res(res[0], "boulder_%d" % v))
		hulls.append(res[1])
	var rng := RandomNumberGenerator.new()
	rng.seed = 2468
	var keep_out := _woodland_keep_out()
	var cells := {}
	var solid: Array = []
	var count := 0
	var step := 38.0
	var x := -820.0
	while x <= 820.0:
		var z := -820.0
		while z <= 820.0:
			var cx: float = x + rng.randf_range(-0.45, 0.45) * step
			var cz: float = z + rng.randf_range(-0.45, 0.45) * step
			z += step
			if cx * cx + cz * cz > 830.0 * 830.0:
				continue
			var g := _ground(cx, cz)
			var shore: bool = g > -10.4 and g < -8.6
			if rng.randf() > (0.5 if shore else 0.13) or g < -10.4:
				continue
			if _slope(cx, cz) > 0.65 or _road_distance(cx, cz) < 14.0 or _kept_out(keep_out, cx, cz, 3.0):
				continue
			var n: int = rng.randi_range(2, 5)
			for k in range(n):
				var px: float = cx + rng.randf_range(-3.5, 3.5)
				var pz: float = cz + rng.randf_range(-3.5, 3.5)
				var sc: float = rng.randf_range(0.7, 1.9) * (1.0 if k == 0 else rng.randf_range(0.45, 0.85))
				var v: int = rng.randi() % shapes.size()
				var gy: float = _ground_min(px, pz, sc * 0.9)
				var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.25))
				var xf := Transform3D(basis.scaled(Vector3.ONE * sc), Vector3(px, gy - sc * 0.22, pz))
				_add_to_cells(cells, _cell(px, pz, FOREST_CELL * 2.0, v), xf)
				count += 1
				if _road_distance(px, pz) < 30.0:
					solid.append([Transform3D(basis, xf.origin), v, sc])
		x += step
	for k in cells.keys():
		var mmi := _multimesh(meshes[k.z], cells[k], "Boulders_%d_%d_%d" % [k.x, k.y, k.z])
		mmi.visibility_range_end = 420.0
		mmi.visibility_range_end_margin = 20.0
		node.add_child(mmi)
	var body := StaticBody3D.new()
	body.name = "BouldersBody"
	node.add_child(body)
	for sv in solid:
		var cs := CollisionShape3D.new()
		var shape := ConvexPolygonShape3D.new()
		# The scale goes into the points: physics wants its shapes unscaled.
		var hp := PackedVector3Array()
		for q in (hulls[sv[1]] as PackedVector3Array):
			hp.append(q * float(sv[2]))
		shape.points = hp
		cs.shape = shape
		cs.transform = sv[0]
		body.add_child(cs)
	print("  boulders: %d in %d cells, %d solid" % [count, cells.size(), solid.size()])


## A boulder: an icosphere pushed about by noise and smoothed, `size` its radii, its colour the
## occlusion (r, dark where it meets the ground) and the height above its foot (g) that
## granite_rock.gdshader reads. Returns [mesh, hull points].
func _rock_mesh(variant: int, size: Vector3, mat: Material) -> Array:
	var noise := FastNoiseLite.new()
	noise.seed = 300 + variant * 17
	noise.frequency = 0.8
	var t := (1.0 + sqrt(5.0)) / 2.0
	var verts: Array = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var faces: Array = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4],
		[11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	for i in range(verts.size()):
		verts[i] = (verts[i] as Vector3).normalized()
	for _sd in range(3):
		var cache := {}
		var nf: Array = []
		for f in faces:
			var m: Array = []
			for e in [[f[0], f[1]], [f[1], f[2]], [f[2], f[0]]]:
				var key := "%d_%d" % [mini(e[0], e[1]), maxi(e[0], e[1])]
				if not cache.has(key):
					verts.append(((verts[e[0]] as Vector3) + (verts[e[1]] as Vector3)).normalized())
					cache[key] = verts.size() - 1
				m.append(cache[key])
			nf.append([f[0], m[0], m[2]])
			nf.append([f[1], m[1], m[0]])
			nf.append([f[2], m[2], m[1]])
			nf.append([m[0], m[1], m[2]])
		faces = nf
	var pts := PackedVector3Array()
	for v in verts:
		var d: Vector3 = v
		var r: float = 1.0 + 0.24 * noise.get_noise_3dv(d * 1.2) + 0.07 * noise.get_noise_3dv(d * 3.5)
		var p: Vector3 = d * r
		# Weathered flat on top, and its bed flattened where it sits in the ground.
		p.y = clampf(p.y, -0.7, 0.62 + 0.1 * noise.get_noise_3dv(d * 2.0))
		pts.append(p * size)
	var y_min := INF
	for p in pts:
		y_min = minf(y_min, p.y)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(pts.size()):
		var h: float = pts[i].y - y_min
		st.set_color(Color(clampf(0.35 + h * 0.9, 0.35, 1.0), clampf(h / 1.5, 0.0, 1.0), 0.0))
		st.add_vertex(pts[i])
	for f in faces:
		var a: Vector3 = pts[f[0]]
		var b: Vector3 = pts[f[1]]
		var c: Vector3 = pts[f[2]]
		# Wound to face out (Godot's front faces: (c - a) x (b - a) outward).
		if (c - a).cross(b - a).dot((a + b + c) / 3.0) > 0.0:
			st.add_index(f[0])
			st.add_index(f[1])
			st.add_index(f[2])
		else:
			st.add_index(f[0])
			st.add_index(f[2])
			st.add_index(f[1])
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, mat)
	return [mesh, pts]


func _plant_shrub(px: float, pz: float, g: float, rng: RandomNumberGenerator, keep_out: Array, alts: Array, plants: Dictionary, counts: Dictionary) -> void:
	if _slope(px, pz) > 0.7 or _road_distance(px, pz) < 11.0 or _kept_out(keep_out, px, pz, 2.0):
		return
	for c in alts:
		var cp: Vector3 = (c as Curve3D).get_closest_point(Vector3(px, 0.0, pz))
		if Vector2(cp.x - px, cp.z - pz).length() < 11.0:
			return
	var sc: float = rng.randf_range(0.7, 1.2)
	var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(px, g - 0.1 - minf(_relief(px, pz, 1.8) * 0.6, 0.6), pz))
	_add_to_cells(plants, _cell(px, pz, FOREST_CELL, rng.randi() % 2), xf)
	counts["shrub"] += 1


## Where no tree grows: the venue (paddock, grandstand, terraces, the mown verges), the kicker, and
## the old hand-placed props. Rectangles [centre x, centre z, half x, half z, yaw] and circles
## [centre x, centre z, radius].
func _woodland_keep_out() -> Array:
	var out: Array = []
	var cl: PackedFloat32Array = _tg.get("grass_clearings")
	for o in range(0, cl.size() - 5, 6):
		out.append([cl[o], cl[o + 1], cl[o + 2], cl[o + 3], cl[o + 4]])
	var pads: PackedFloat32Array = _tg.get("flat_pads")
	for o in range(0, pads.size() - 6, 7):
		out.append([pads[o], pads[o + 1], pads[o + 2] + 4.0, pads[o + 3] + 4.0, pads[o + 4]])
	out.append(_road_rect(KICKER_S0 - 15.0, KICKER_S0 + 60.0, -14.0, 14.0))
	for n in ["Ramps/ConcreteRamp", "Ramps/LoopCSG", "LevelDesign/ConcreteFootbridge", "LevelDesign/FestivalTent", "LevelDesign/Boat",
			"LevelDesign/Logs", "LevelDesign/Hay", "LevelDesign/Hay2", "WoodenCart", "LevelDesign/Box", "LevelDesign/Box2", "LevelDesign/Bush"]:
		var p := _level.get_node_or_null(n) as Node3D
		if p:
			out.append([p.position.x, p.position.z, 22.0])
	for f in _footprints:
		var c: Vector2 = f[1]
		out.append([c.x, c.y, float(f[2]) + 2.0])
	return out


func _kept_out(zones: Array, x: float, z: float, margin: float) -> bool:
	for zn in zones:
		if zn.size() == 3:
			if Vector2(x - float(zn[0]), z - float(zn[1])).length() < float(zn[2]) + margin:
				return true
			continue
		var dx: float = x - float(zn[0])
		var dz: float = z - float(zn[1])
		var reach: float = float(zn[2]) + float(zn[3]) + margin
		if dx * dx + dz * dz > reach * reach:
			continue
		var c: float = cos(float(zn[4]))
		var sn: float = sin(float(zn[4]))
		if absf(dx * c - dz * sn) < float(zn[2]) + margin and absf(dx * sn + dz * c) < float(zn[3]) + margin:
			return true
	return false


func _slope(x: float, z: float) -> float:
	var sx := _ground(x + 1.5, z) - _ground(x - 1.5, z)
	var sz := _ground(x, z + 1.5) - _ground(x, z - 1.5)
	return Vector2(sx, sz).length() / 3.0


## How far the ground falls from (x, z) to the lowest point on a ring of radius `reach` round it.
func _relief(x: float, z: float, reach: float) -> float:
	var h0 := _ground(x, z)
	var low := h0
	for k in range(8):
		var a := TAU * k / 8.0
		low = minf(low, _ground(x + cos(a) * reach, z + sin(a) * reach))
	return h0 - low


func _cell(x: float, z: float, size: float, v: int) -> Vector3i:
	return Vector3i(floori(x / size), floori(z / size), v)


func _add_to_cells(cells: Dictionary, key: Vector3i, xf: Transform3D) -> void:
	if not cells.has(key):
		cells[key] = []
	cells[key].append(xf)


## A MultiMeshInstance3D of `mesh` at `transforms`, stored in an order shuffled by the node's name,
## so drawing the first N (JungleDetail's lower levels of detail) thins a cell evenly.
func _multimesh(mesh: Mesh, transforms: Array, node_name: String) -> MultiMeshInstance3D:
	var order: Array = transforms.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(node_name)
	for i in range(order.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = order.size()
	mm.buffer = PropKit.transform_buffer(order)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	return mmi


# ======================================================================================
#  Old props, ownership
# ======================================================================================

## Moves the two hand-placed plants by the start out of the barrier and fence lines.
func _move_old_props() -> void:
	var moves := {"Plant2": Vector2(3212.0, -15.0), "Plant": Vector2(3224.0, 25.0)}
	for n in moves:
		var p := _level.get_node_or_null(n) as Node3D
		if p == null:
			continue
		var v: Vector2 = moves[n]
		var at := _at(v.x, v.y)
		p.position = at


func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	if node != scene_root:
		node.owner = scene_root
	for child in node.get_children():
		if child.owner != null and child.owner != scene_root:
			continue
		_set_owner_recursive(child, scene_root)
