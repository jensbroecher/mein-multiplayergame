extends Node
## Dresses the Lakeside Course (res://levels/LakesideLevel.tscn, the Bloombay GP's first stage) as an RC race
## meeting: the paddock, race control and its observer tower, the lap towers, catch fences hung with sponsor
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
const WindTurbineBuilder = preload("res://WindTurbineBuilder.gd")
const MeadowGrass = preload("res://MeadowGrass.gd")
const TyreStacks = preload("res://TyreStacks.gd")
const VenueKit = preload("res://VenueKit.gd")
const CrowdPlacer = preload("res://CrowdPlacer.gd")
const CarPaint = preload("res://CarPaint.gd")
const RowboatCSG = preload("res://RowboatCSG.gd")
const ParkKit = preload("res://ParkKit.gd")
const WOODEN_RAMP := preload("res://WoodenRamp.tscn")
const BOOST_PAD := preload("res://BoostPad.tscn")
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
const OBSERVER_TOWER := Vector2(3229.0, -10.9)
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
	["BLOOMBAY GP", "LAKESIDE MEADOWS", Color(0.05, 0.45, 0.55), Color(1, 1, 1), Color(0.98, 0.80, 0.20), 0],
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
var _venue: VenueKit
## Gazebos ([frame, has a show car]) and the grandstand's sections (frames), for the spectators.
var _gazebo_frames: Array = []
var _stand_frames: Array = []
var _heights := PackedFloat32Array()
var _materials := {}
var _footprints: Array = []   # [name, centre Vector2, radius, clearance]
var _stamps: Array = []       # [mesh, transforms]: the woods' and boulders' instances, for _build_meadow
var _hit_mask := PackedByteArray()    # _build_meadow: texels under something, and their list
var _hits := PackedInt32Array()
var _ad_k := 0
var _rng := RandomNumberGenerator.new()
## Where the crowd barriers stand ([middle, along]), for the spectators behind them.
var _barrier_spots: Array = []
## The observer on the tower by race control: [feet, facing].
var _observer_spot: Array = []


func _ready() -> void:
	print("=== Lakeside Meadows dressing ===")
	var t0 := Time.get_ticks_msec()
	_kit = PropKit.new()
	_kit.material_for = _material
	_camp = CampKit.new(_kit)
	_venue = VenueKit.new(_kit)
	_venue.bark_material = _save_res(Woodland.new().bark_material("oak", 0), "bark_logs")
	_venue.logwall_material = _save_res(_logwall_material(), "logwall")
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
	var gaps := _plan_road_gaps()
	var saved_gaps: PackedFloat32Array = _tg.get_meta(&"baked_road_gaps", PackedFloat32Array())
	_tg.set("flat_pads", pads)
	_tg.set("grass_clearings", clearings)
	_tg.set("road_gaps", gaps)
	var rebake: bool = "rebake" in OS.get_cmdline_user_args() or pads != saved_pads or clearings != saved_clear \
			or gaps != saved_gaps or not FileAccess.file_exists("res://generated/terrain_visual.res")
	if rebake:
		print("  re-baking the terrain, road and grass (%d pads, %d clearings)..." % [pads.size() / 7, clearings.size() / 6])
		_tg.call("generate_world")
		_tg.set_meta(&"baked_pads", pads)
		_tg.set_meta(&"baked_clearings", clearings)
		_tg.set_meta(&"baked_road_gaps", gaps)
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
	_build_bridge_jumps(root)
	_build_paddock(root)
	_build_race_control(root)
	_build_observer_tower(root)
	_build_lap_towers(root)
	_build_fences(root)
	_build_barriers(root)
	_build_tyre_walls(root)
	_build_drop_rails(root)
	_build_hay_and_cones(root)
	_build_grandstand(root)
	_build_campsite(root)
	_move_old_props()
	_fit_loop()
	_build_loop_apron(root)
	_lay_shortcuts()
	_build_venue(root)
	_build_lookout(root)
	_build_playground(root)
	_plan_trails()
	_build_trails(root)
	_build_spectators(root)
	_build_airship(root)
	_build_loop_sign(root)
	_build_banked_turn(root)
	var boat := _start_rowboat()
	_build_wind_turbines(root)
	_build_woodland(root)
	_build_boulders(root)
	_build_backdrop(root)
	_build_ads(root)
	# The loop's and the boat's CSG build their meshes on the next frame; the meadow reads them.
	await get_tree().process_frame
	_finish_rowboat(root, boat)
	_build_meadow(root)
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
	env.fog_depth_begin = BACK_FOG.x
	env.fog_depth_end = BACK_FOG.y
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
	_update_water_surface()


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
	var pg := _playground_frame()
	var pc: Vector2 = pg[0]
	_add_pad(out, [pc.x, pc.y, PLAYGROUND_HALF.x, PLAYGROUND_HALF.y, float(pg[1])], PLAYGROUND_BLEND)
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
	var pg := _playground_frame()
	var pc: Vector2 = pg[0]
	rects.append([[pc.x, pc.y, PLAYGROUND_HALF.x + 2.0, PLAYGROUND_HALF.y + 2.0, float(pg[1])], 5.0])
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
		"hay":
			var hm := ShaderMaterial.new()
			hm.shader = load("res://hay_bale.gdshader")
			m = hm
		"straw_loose":
			var lm := StandardMaterial3D.new()
			lm.vertex_color_use_as_albedo = true
			lm.vertex_color_is_srgb = true
			lm.cull_mode = BaseMaterial3D.CULL_DISABLED
			lm.roughness = 0.9
			m = lm
		"tyre":
			var tm := ShaderMaterial.new()
			tm.shader = load("res://tyre_wall.gdshader")
			m = tm
		"timber", "lapboards", "battens", "painted":
			# VenueKit's sawn wood (hut_wood.gdshader's styles: 2 grain along v, 1 lapped boards, 0 upright
			# boards with battens, 3 painted boards).
			var wm := ShaderMaterial.new()
			wm.shader = load("res://hut_wood.gdshader")
			wm.set_shader_parameter("style", {"timber": 2, "lapboards": 1, "battens": 0, "painted": 3}[key])
			wm.set_shader_parameter("weathering", 0.55)
			m = wm
		"boardtrack":
			var bm := ShaderMaterial.new()
			bm.shader = load("res://board_track.gdshader")
			m = bm
		"endgrain":
			m = CampKit.make_material("wood")
		"iron":
			m = CampKit.make_material("steel")
		"stone":
			m = CampKit.make_material("matte")
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


# ======================================================================================
#  The long bridge's ramps and boost pads
# ======================================================================================

## Wooden ramps (WoodenRamp.tscn) curb to curb on the climb to the long bridge and on it, each [s of the
## toe, length, height, curve, table, tail]: two rollers on the climb (s 955-1000), a kicker where the
## bridge leaves the shore (it lands on the straight before the bend at 1360), and a table-top on the far
## straight after the bend. None near a checkpoint (737, 1106, 1475, 1844) or in the bend.
const BRIDGE_RAMPS := [
	[955.0, 5.0, 0.9, 0.7, 0.0, 5.0],
	[985.0, 5.0, 0.9, 0.7, 0.0, 5.0],
	[1215.0, 7.0, 1.4, 0.6, 0.0, 0.0],
	[1570.0, 6.0, 1.2, 0.5, 5.0, 6.0],
]
## Boost pads along the same run, [s, lateral]: one after the rollers, a staggered pair after Halfway2,
## one straight into the kicker and one into the table-top.
const BRIDGE_PADS := [[1040.0, 0.0], [1145.0, -3.2], [1165.0, 3.2], [1195.0, 0.0], [1545.0, 0.0]]

func _build_bridge_jumps(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "BridgeJumps"
	root.add_child(node)
	var track_path := _level.get_node("TrackPath")
	var lips: Array = (track_path.get_meta(&"jump_lips", []) as Array).duplicate()
	for r in BRIDGE_RAMPS:
		var ramp := WOODEN_RAMP.instantiate() as WoodenRamp
		ramp.name = "WoodenRamp_%d" % int(r[0])
		ramp.length = r[1]
		ramp.height = r[2]
		ramp.curve = r[3]
		ramp.table_length = r[4]
		ramp.tail_length = r[5]
		ramp.width = ROAD_HALF * 2.0
		ramp.transform = _road_frame(r[0], 0.0, ramp.run())
		node.add_child(ramp)
		lips.append(ramp.lip_info())
	for pd in BRIDGE_PADS:
		var pad := BOOST_PAD.instantiate() as Node3D
		pad.name = "BoostPad_%d" % int(pd[0])
		pad.transform = _road_frame(pd[0] - 3.0, pd[1], 6.0).translated_local(Vector3(0.0, 0.0, -3.0))
		node.add_child(pad)
	track_path.set_meta(&"jump_lips", lips)
	print("  bridge: %d wooden ramps, %d boost pads" % [BRIDGE_RAMPS.size(), BRIDGE_PADS.size()])


## A frame on the road's surface at `s`, `lat` right of the centreline, its -z along the lap with the
## road's grade over the next `ahead` metres, y up.
func _road_frame(s: float, lat: float, ahead: float) -> Transform3D:
	var fr := _frame(s)
	var right: Vector3 = fr["right"]
	var p0: Vector3 = (fr["pos"] as Vector3) + right * lat + Vector3(0.0, _road_y, 0.0)
	var p1: Vector3 = _curve.sample_baked(fposmod(s + ahead, _length)) + right * lat + Vector3(0.0, _road_y, 0.0)
	return Transform3D(Basis.looking_at((p1 - p0).normalized(), Vector3.UP), p0)


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
## The gazebos and team tents are built bigger than CampKit's and _team_tent's own (GAZEBO_GROW, TENT_GROW,
## on top of PROP_SCALE), so a race car fits on the display table under each; the furniture stays
## PROP_SCALE. The cars on show are the game's own (SHOW_CARS: the lighter models), at race size, on every
## other gazebo's table and in each team tent; the rest keep the 1/8 buggies.
const GAZEBO_GROW := Vector3(1.3, 1.1, 1.3)
const TENT_GROW := Vector3(1.25, 1.12, 1.4)
const SHOW_CARS := ["Mudrunner", "Zephyr", "Mirage", "Centurion", "Shadow", "Phantom"]
## The cars' meshes aren't drawn past this (they are 37-51k triangles each).
const SHOW_CAR_RANGE := 130.0

func _build_paddock(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Paddock"
	root.add_child(node)
	var cars := Node3D.new()
	cars.name = "ShowCars"
	node.add_child(cars)
	var kit := {}
	var clutter := {}
	var boxes: Array = []
	var shown := 0
	var n := 7
	for i in range(n):
		var s: float = PADDOCK_S.x + 6.0 + (PADDOCK_S.y - PADDOCK_S.x - 14.0) * i / (n - 1)
		var lat: float = -27.0 + (1.6 if i % 2 == 1 else 0.0)
		var fr := _frame(s)
		var at := _at(s, lat)
		var yaw := _yaw_to(fr["right"]) + _rng.randf_range(-0.05, 0.05)
		var canopy: Color = CANOPIES[i % CANOPIES.size()]
		_kit.set_frame(_grown(at, yaw, GAZEBO_GROW))
		_camp.gazebo(kit, canopy, i % 3 == 2)
		_kit.set_frame(_place(at, yaw))
		var car: String = SHOW_CARS[shown] if i % 2 == 0 and shown < SHOW_CARS.size() else ""
		var spot: Array = _pit_set(clutter, i, yaw, car != "")
		if car != "":
			_show_car(cars, car, spot[0], spot[1], yaw, boxes)
			shown += 1
		_gazebo_frames.append([_place(at, yaw), car != ""])
		_note("Gazebo%d" % i, at, 2.6 * PROP_SCALE * GAZEBO_GROW.x, 4.0)
		# Legs, as thin posts carts bump.
		for sx in [-1.47, 1.47]:
			for sz in [-1.47, 1.47]:
				var leg := Transform3D(Basis(Vector3.UP, yaw), at) * Vector3(sx * PROP_SCALE * GAZEBO_GROW.x, 1.6, sz * PROP_SCALE * GAZEBO_GROW.z)
				boxes.append([leg, Vector3(0.12, 3.2, 0.12), Basis(Vector3.UP, yaw)])
	# Behind the row: two big team tents and a line of portable toilets between them.
	for j in range(2):
		var s2: float = PADDOCK_S.x + 18.0 + j * 30.0
		var at2 := _at(s2, -39.0)
		var yaw2 := _yaw_to(_frame(s2)["right"])
		var col: Color = [Color(0.93, 0.93, 0.91), Color(0.06, 0.10, 0.22)][j]
		_kit.set_frame(_grown(at2, yaw2, TENT_GROW))
		_team_tent(kit, col)
		_kit.set_frame(_place(at2, yaw2))
		var spot2: Array = _team_tent_inside(clutter, _tent_accent(col), yaw2)
		if shown < SHOW_CARS.size():
			_show_car(cars, SHOW_CARS[shown], spot2[0], spot2[1], yaw2, boxes)
			shown += 1
		_gazebo_frames.append([_place(at2, yaw2) * Transform3D(Basis(), Vector3(-1.7, 0.0, 0.0)), true])
		_note("TeamTent%d" % j, at2, 3.4 * PROP_SCALE * TENT_GROW.x, 6.0)
	for t in range(4):
		var s3: float = PADDOCK_S.x + 28.0 + t * 2.0
		var at3 := _at(s3, -40.5)
		var yaw3 := _yaw_to(_frame(s3)["right"])
		_kit.set_frame(_place(at3, yaw3))
		_toilet(kit, [Color(0.16, 0.36, 0.72), Color(0.16, 0.36, 0.72), Color(0.18, 0.52, 0.30), Color(0.16, 0.36, 0.72)][t])
		boxes.append([at3 + Vector3(0, 1.15 * PROP_SCALE, 0), Vector3(1.2, 2.3, 1.2) * PROP_SCALE, Basis(Vector3.UP, yaw3)])
	_commit(node, kit, "PaddockTents")
	_commit(node, clutter, "PaddockGear", 260.0)
	_boxes_body(node, "PaddockBody", boxes)
	print("  paddock: %d cars on show" % shown)


## A frame at `at` turned `yaw`, grown by `grow` (local axes) on top of PROP_SCALE.
func _grown(at: Vector3, yaw: float, grow: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(grow * PROP_SCALE), at)


func _tent_accent(col: Color) -> Color:
	return Color(0.84, 0.16, 0.12) if col.v > 0.5 else Color(0.96, 0.68, 0.12)


## The gear under gazebo `i` (turned `yaw`): a display table with a car on its stand (`show_car`: the
## car itself is _show_car's), or a folding table with a charger; chairs, a
## rolling tool chest, toolboxes, a cool box and a generator out the back. Returns [where the car's
## wheels go (world), the way its nose points (yaw)] for a show car.
func _pit_set(kit: Dictionary, i: int, yaw: float, show_car: bool) -> Array:
	var k := _kit
	var base := k.xf
	var rng := RandomNumberGenerator.new()
	rng.seed = 400 + i * 17
	var sub := func(x: float, z: float, a: float) -> void:
		k.set_frame(base * Transform3D(Basis(Vector3.UP, a), Vector3(x, 0, z)))
	var spot: Array = []
	if show_car:
		sub.call(0.0, 0.7, 0.0)
		var top: float = _venue.display_table(kit, Color(0.90, 0.90, 0.88))
		# Along the table, its nose turned a little toward the paddock's lane.
		spot = [base * Vector3(0.0, top, 0.7), yaw - PI * 0.5 + rng.randf_range(-0.3, 0.3)]
		sub.call(1.55, 1.05, PI * 0.5 + rng.randf_range(-0.2, 0.2))
		_tool_chest(kit, CHEST_COLS[i % CHEST_COLS.size()])
		sub.call(1.62, 0.92, -0.2)
		_charger(kit, 1.22)
	else:
		sub.call(0.1, 0.55, 0.0)
		_camp.folding_table(kit, Color(0.90, 0.90, 0.88))
		sub.call(0.75, 0.62, 0.1)
		_charger(kit, 0.74)
		sub.call(1.55, 1.05, PI * 0.5 + rng.randf_range(-0.2, 0.2))
		_tool_chest(kit, CHEST_COLS[i % CHEST_COLS.size()])
	for c in range(2):
		sub.call(-0.75 + c * 1.1 + rng.randf_range(-0.1, 0.1), -0.55 + rng.randf_range(-0.15, 0.15), PI + rng.randf_range(-0.4, 0.4))
		_camp.camp_chair(kit, CHAIR_COLS[(i + c * 2) % CHAIR_COLS.size()])
	sub.call(-1.15, -1.05 + rng.randf_range(0, 0.4), rng.randf_range(0, TAU))
	_camp.cooler(kit, [Color(0.80, 0.10, 0.10), Color(0.10, 0.30, 0.70), Color(0.92, 0.92, 0.90)][i % 3], WHITE)
	sub.call(-1.35, 1.0, rng.randf_range(-0.5, 0.5))
	_toolbox(kit, [Color(0.08, 0.12, 0.30), Color(0.12, 0.12, 0.13), Color(0.75, 0.08, 0.07)][i % 3])
	sub.call(-1.35, 0.45, rng.randf_range(-0.5, 0.5))
	_toolbox(kit, Color(0.08, 0.12, 0.30))
	sub.call(2.5, 1.9 + rng.randf_range(-0.3, 0.3), rng.randf_range(0, TAU))
	_generator(kit, [Color(0.85, 0.12, 0.08), Color(0.95, 0.75, 0.08)][i % 2])
	k.set_frame(base)
	return spot


## A team tent's inside (frame: the tent's, at PROP_SCALE): a display table for a show car, a workbench
## with a charger, a rolling tool chest and a cool box. Returns the show car's spot (as
## _pit_set's).
func _team_tent_inside(kit: Dictionary, accent: Color, yaw: float) -> Array:
	var k := _kit
	var b0 := k.xf
	k.set_frame(b0 * Transform3D(Basis(), Vector3(-1.7, 0, 0.8)))
	var top: float = _venue.display_table(kit, WHITE)
	var spot := [b0 * Vector3(-1.7, top, 0.8), yaw - PI * 0.5 + 0.35]
	k.set_frame(b0 * Transform3D(Basis(), Vector3(1.6, 0, 0.7)))
	_camp.folding_table(kit, WHITE)
	k.set_frame(b0 * Transform3D(Basis(Vector3.UP, -0.25), Vector3(2.0, 0, 0.66)))
	_charger(kit, 0.74)
	k.set_frame(b0 * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-3.15, 0, 1.1)))
	_tool_chest(kit, accent)
	k.set_frame(b0 * Transform3D(Basis(Vector3.UP, 0.2), Vector3(3.0, 0, 1.3)))
	_camp.cooler(kit, accent, WHITE)
	k.set_frame(b0)
	return spot


## One of the game's cars on show at race size (its scene's meshes under a DisplayCar node, which paints
## it at load in the car's factory colours), wheels at `at`, nose along `nose_yaw`; with box colliders
## for it and its table (turned `table_yaw`).
func _show_car(parent: Node3D, car: String, at: Vector3, nose_yaw: float, table_yaw: float, boxes: Array) -> void:
	var src: Node3D = (load("res://generated/cars/%s.tscn" % car) as PackedScene).instantiate()
	var holder := Node3D.new()
	holder.name = "ShowCar%s" % car
	holder.set_script(load("res://DisplayCar.gd"))
	holder.set("paint", CarPaint.factory(car))
	# The scene's Model undoes PlayerCart's x2 and half turn: the same here.
	holder.transform = Transform3D(Basis(Vector3.UP, nose_yaw + PI).scaled(Vector3.ONE * 2.0), at)
	parent.add_child(holder)
	var model := src.get_node("Model") as Node3D
	var m2 := Node3D.new()
	m2.name = "Model"
	m2.transform = model.transform
	holder.add_child(m2)
	for c in model.get_children():
		if c is MeshInstance3D:
			var mi := MeshInstance3D.new()
			mi.name = c.name
			mi.mesh = (c as MeshInstance3D).mesh
			mi.transform = (c as MeshInstance3D).transform
			mi.set_meta(&"car_shader", true)
			mi.visibility_range_end = SHOW_CAR_RANGE
			m2.add_child(mi)
	src.free()
	var tb := Basis(Vector3.UP, table_yaw)
	boxes.append([at + Vector3(0, 0.45, 0), Vector3(1.3, 0.9, 2.2), Basis(Vector3.UP, nose_yaw)])
	boxes.append([at - Vector3(0, VenueKit.DISPLAY_TOP * PROP_SCALE * 0.5, 0), Vector3(VenueKit.DISPLAY_HL * 2.0, VenueKit.DISPLAY_TOP, VenueKit.DISPLAY_HW * 2.0) * PROP_SCALE, tb])


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


func _charger(kit: Dictionary, y: float) -> void:
	var k := _kit
	k.block(kit, "plastic", Vector3(-0.1, y, -0.07), Vector3(0.1, y + 0.05, 0.07), Color(0.12, 0.12, 0.13))
	k.block(kit, "lamp", Vector3(-0.07, y + 0.051, -0.04), Vector3(0.0, y + 0.055, 0.02), Color(0.2, 0.7, 0.9))
	k.block(kit, "plastic", Vector3(0.12, y, -0.04), Vector3(0.24, y + 0.04, 0.04), Color(0.9, 0.55, 0.1))


## A 6 x 3 m race team marquee tent: two portal-framed bays under a ridged roof with gable vents,
## Georgian-style windowed side walls and tied-back front entrance drapes (the workshop inside is
## _team_tent_inside's, built at PROP_SCALE while the tent is grown).
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
#  Race control, the observer tower, the lap towers
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


## The observer's tower beside race control: the scaffold with a race observer on its platform (it
## carried a broadcast camera on a tripod).
func _build_observer_tower(root: Node3D) -> void:
	var fr := _frame(OBSERVER_TOWER.x)
	var at := _at(OBSERVER_TOWER.x, OBSERVER_TOWER.y)
	at.y = _ground_min(at.x, at.z, 1.8)
	var yaw := _yaw_to(fr["right"])
	var kit := {}
	_kit.set_frame(_place(at, yaw))
	var plat := 3.3
	_scaffold(kit, 2.0, 2.0, plat)
	_commit(root, kit, "ObserverTower")
	# A race observer stands at the platform's front, watching the straight (_build_spectators).
	_observer_spot = [_place(at, yaw) * Vector3(0.1, plat + 0.05, -0.3), Basis(Vector3.UP, yaw + 0.5) * Vector3(0, 0, -1)]
	var hx := 1.0 * PROP_SCALE
	var boxes: Array = []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			boxes.append([Transform3D(Basis(Vector3.UP, yaw), at) * Vector3(sx * hx, 2.6, sz * hx), Vector3(0.14, 5.2, 0.14), Basis(Vector3.UP, yaw)])
	boxes.append([at + Vector3(0, (plat + 0.03) * PROP_SCALE, 0), Vector3(2.0, 0.1, 2.0) * PROP_SCALE, Basis(Vector3.UP, yaw)])
	_boxes_body(root, "ObserverTowerBody", boxes)
	_note("ObserverTower", at, 1.45 * PROP_SCALE, 1.0)


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
		var pieces := _trim_run(_offset_run(float(r[0]), float(r[1]), float(r[2]), 0.5), String(r[3]))
		for k in range(pieces.size()):
			_fence(node, pieces[k], -signf(float(r[2])), String(r[3]) + ("" if k == 0 else str(k)))


## Fences, barriers and tyre walls stand on ground near the road's height that isn't steep, and end where
## it falls away down a bank: they had run on down the slopes round the start. A run comes back in pieces
## of at least RUN_MIN, the rest left out (printed).
const RUN_MAX_DROP := 1.2
const RUN_MAX_SLOPE := 0.32
const RUN_MIN := 6.0

func _trim_run(pts: PackedVector3Array, what: String) -> Array:
	var pieces: Array = []
	var cur := PackedVector3Array()
	var dropped := 0.0
	var total := 0.0
	for i in range(pts.size()):
		var p: Vector3 = pts[i]
		var step: float = 0.0 if i == 0 else Vector2(p.x - pts[i - 1].x, p.z - pts[i - 1].z).length()
		total += step
		if absf(p.y - _road_surface(p)) < RUN_MAX_DROP and _slope(p.x, p.z) < RUN_MAX_SLOPE:
			cur.append(p)
			continue
		dropped += step
		dropped += _keep_piece(pieces, cur)
		cur = PackedVector3Array()
	dropped += _keep_piece(pieces, cur)
	if dropped > 0.5:
		print("  %s: %.0fm of %.0fm left out on banks, %d piece(s)" % [what, dropped, total, pieces.size()])
	return pieces


## Keeps `cur` as a piece if it's long enough; returns its length if not (left out).
func _keep_piece(pieces: Array, cur: PackedVector3Array) -> float:
	if cur.size() < 2:
		return 0.0
	var length := 0.0
	for i in range(1, cur.size()):
		length += Vector2(cur[i].x - cur[i - 1].x, cur[i].z - cur[i - 1].z).length()
	if length < RUN_MIN:
		return length
	pieces.append(cur)
	return 0.0


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
## at race control, the observer tower and the paddock's entrance.
func _build_barriers(root: Node3D) -> void:
	var kit := {}
	var length := 2.3 * PROP_SCALE
	var gaps := [Vector2(BOOTH.x - 3.5, BOOTH.x + 3.0), Vector2(OBSERVER_TOWER.x - 3.0, OBSERVER_TOWER.x + 3.0), Vector2(3288.0, 3294.0)]
	var boxes: Array = []
	for pts in _trim_run(_offset_run(3140.0, 3300.0, BARRIER_LAT, 0.25), "CrowdBarriers"):
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
			_barrier_spots.append([mid, (b - a).normalized()])
	_commit(root, kit, "CrowdBarriers")
	_boxes_body(root, "CrowdBarriersBody", boxes)


## Tyre walls: stacks of three, red, white and black in turn, along the curb behind the grid on the
## right and round the outside of the first corner. The stacks give when a cart hits the wall
## (TyreStacks.gd, SpringProps.gd); the wall's boxes stop the cart.
func _build_tyre_walls(root: Node3D) -> void:
	var designs: Array = TyreStacks.meshes(_kit, "tyre", 2027)
	for d in range(designs.size()):
		designs[d] = _save_res(designs[d], "tyre_stack_%d" % d)
	var runs := [[3132.0, 3204.0, TYRE_LAT, "TyreWallGrid"], [3289.0, 27.0, -TYRE_LAT, "TyreWallCorner"]]
	for r in runs:
		var pieces := _trim_run(_offset_run(float(r[0]), float(r[1]), float(r[2]), 0.995 * PROP_SCALE * 0.62), String(r[3]))
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(String(r[3]))
		for k in range(pieces.size()):
			var pts: PackedVector3Array = pieces[k]
			var nm: String = String(r[3]) + ("" if k == 0 else str(k))
			var stacks: Array = []
			var boxes: Array = []
			for i in range(pts.size()):
				var p: Vector3 = pts[i]
				stacks.append([_place(p, rng.randf() * TAU), TyreStacks.design(i, rng)])
				if i > 0 and (i % 4 == 0 or i == pts.size() - 1):
					boxes.append(_wall_box(pts[maxi(i - 4, 4 * ((i - 1) / 4))], p, 0.62 * PROP_SCALE, 0.6 * PROP_SCALE))
			root.add_child(TyreStacks.spring_node(nm, designs, stacks, PROP_SCALE))
			_boxes_body(root, nm + "Body", boxes)
			for p in pts:
				_note(nm, p, 0.5, 1.2)


## W-beam guardrails along the deck's edges where the road crosses the inlet after the loop: the ground falls 15-18m
## just past the curbs there, inside the 60 degree corner that follows the loop's exit. With the road running on through
## the loop (no grass gap to slow them), bots left the loop at full speed and ran off that deck into the hollow. Each
## run is [s0, s1, sides]; on each side named (-1 left, 1 right) a rail stands where the ground DROP_RAIL_OUT past the deck's edge is more than
## DROP_RAIL_DEPTH under the road, posts on the curb's outer strip (DROP_RAIL_LAT), the beam facing the road.
const DROP_RAILS := [[2690.0, 2805.0, [-1.0, 1.0]], [3270.0, 45.0, [-1.0]]]
const DROP_RAIL_LAT := 7.75
const DROP_RAIL_OUT := 2.5
const DROP_RAIL_DEPTH := 2.0
const DROP_RAIL_STEP := 2.5
const DROP_RAIL_LEAD := 4

func _build_drop_rails(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Guardrails"
	root.add_child(node)
	var kit := {}
	var k := _kit
	k.reset_frame()
	var boxes: Array = []
	var rail_col := Color(0.76, 0.78, 0.80)
	var post_col := Color(0.30, 0.32, 0.35)
	var total := 0.0
	for r in DROP_RAILS:
		for side in r[2]:
			var pts := _offset_run(float(r[0]), float(r[1]), float(side) * DROP_RAIL_LAT, DROP_RAIL_STEP)
			# Which posts stand over a drop, the rail led in DROP_RAIL_LEAD posts before it (carts running wide reach the
			# drop from the bank before it) and one past it, so it starts and ends on firm ground.
			var over: Array[bool] = []
			for p in pts:
				var cp := _curve.get_closest_point(p)
				var out := Vector3(p.x - cp.x, 0.0, p.z - cp.z).normalized()
				var g := _ground(p.x + out.x * DROP_RAIL_OUT, p.z + out.z * DROP_RAIL_OUT)
				over.append(_road_surface(p) - g > DROP_RAIL_DEPTH)
			var keep: Array[bool] = []
			for i in range(pts.size()):
				var near := false
				for j in range(maxi(i - 1, 0), mini(i + DROP_RAIL_LEAD, pts.size() - 1) + 1):
					near = near or over[j]
				keep.append(near)
			for i in range(pts.size()):
				if not keep[i]:
					continue
				var p: Vector3 = pts[i]
				p.y = _road_surface(p)
				k.beam(kit, "steel", p - Vector3(0, 0.3, 0), p + Vector3(0, 1.08, 0), 0.14, 0.12, post_col)
				k.block(kit, "plastic", p + Vector3(-0.05, 1.08, -0.05), p + Vector3(0.05, 1.18, 0.05),
						Color(0.92, 0.14, 0.10) if float(side) > 0.0 else Color(0.95, 0.95, 0.92))
				_note("Guardrail", p, 0.15, -1.0)
				if i == 0 or not keep[i - 1]:
					continue
				var q: Vector3 = pts[i - 1]
				q.y = _road_surface(q)
				var seg := p - q
				seg.y = 0.0
				if seg.length_squared() < 1e-4:
					continue
				var along := seg.normalized()
				# Toward the road: the run is on side `side`, so the road is the other way.
				var face: Vector3 = Vector3(-along.z, 0.0, along.x) * -float(side)
				# Double corrugated W-beam: two ridges and the groove between, on the road's side of the posts.
				k.beam(kit, "metal", q + Vector3(0, 0.88, 0) + face * 0.12, p + Vector3(0, 0.88, 0) + face * 0.12, 0.07, 0.14, rail_col, face)
				k.beam(kit, "metal", q + Vector3(0, 0.72, 0) + face * 0.09, p + Vector3(0, 0.72, 0) + face * 0.09, 0.06, 0.12, rail_col.darkened(0.12), face)
				k.beam(kit, "metal", q + Vector3(0, 0.56, 0) + face * 0.12, p + Vector3(0, 0.56, 0) + face * 0.12, 0.07, 0.14, rail_col, face)
				boxes.append(_wall_box(q, p, 0.35, 1.15))
				total += q.distance_to(p)
	_commit(node, kit, "WBeamGuardrails", 600.0)
	_boxes_body(node, "GuardrailBody", boxes)
	print("  guardrails over the drops: %.0fm" % total)


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
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 1717
	for b in bales:
		var at: Vector3 = b[0]
		at.y = _ground_min(at.x, at.z, 1.7) - 0.03
		var yaw: float = b[1]
		_kit.set_frame(_place(at, yaw))
		_hay_bale(kit, rng_b)
		# A bale is 2m long along its own x, 1m wide.
		boxes.append([at + Vector3(0, 0.45 * PROP_SCALE, 0), Vector3(2.0, 0.9, 1.0) * PROP_SCALE, Basis(Vector3.UP, yaw)])
		_note("HayBale", at, 1.1 * PROP_SCALE, 1.5)
	# A stack: two bales with one on top, beside the corner's lap tower.
	var st := _at(3306.0, -19.5)
	st.y = _ground_min(st.x, st.z, 2.0) - 0.03
	var yaw2 := _yaw_to(_frame(3306.0)["fwd"])
	for p in [Vector3(0, 0, -0.55), Vector3(0, 0, 0.55), Vector3(0.0, 0.9, 0.0)]:
		_kit.set_frame(_place(st, yaw2) * Transform3D(Basis(Vector3.UP, PI * 0.5 + rng_b.randf_range(-0.04, 0.04)), p))
		_hay_bale(kit, rng_b)
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
## A big square bale at life size (2 x 0.9 x 1m, length along x, standing on y = 0): a rounded box
## bulging a little between its edges and lumpy, in hay_bale.gdshader's straw (UV in metres along
## the faces, COLOR r weathering, g a random, b the face), four orange twines running round it
## lengthwise and pressed into it, and loose straws sticking out of its edges.
const BALE := Vector3(1.0, 0.9, 0.5)   # half length, height, half width
const BALE_ROUND := 0.07

func _hay_bale(kit: Dictionary, rng: RandomNumberGenerator) -> void:
	var k := _kit
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 1.6
	noise.fractal_octaves = 2
	var seed_v := rng.randf()
	var weather := rng.randf_range(0.35, 1.0)
	# Faces: [normal, u axis, v axis, u span, v span, segments u, v, face kind]. The bottom isn't seen.
	var faces := [
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0), 2.0, 0.9, 16, 7, 0.0],
		[Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 1, 0), 2.0, 0.9, 16, 7, 0.0],
		[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1), 2.0, 1.0, 16, 8, 0.5],
		[Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0), 1.0, 0.9, 8, 7, 1.0],
		[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0), 1.0, 0.9, 8, 7, 1.0],
	]
	for f in faces:
		var n: Vector3 = f[0]
		var au: Vector3 = f[1]
		var av: Vector3 = f[2]
		var su: int = f[5]
		var sv: int = f[6]
		var col := Color(weather, seed_v, float(f[7]), 1.0)
		var grid: Array = []
		for i in range(su + 1):
			var row: Array = []
			# Rows bunch up toward the edges, where the rounding is.
			var tu := 0.5 - 0.5 * cos(PI * float(i) / su)
			for j in range(sv + 1):
				var tv := 0.5 - 0.5 * cos(PI * float(j) / sv)
				var on := Vector3(n.x * BALE.x, BALE.y * 0.5 + n.y * BALE.y * 0.5, n.z * BALE.z)
				on += au * (tu - 0.5) * float(f[3]) + av * (tv - 0.5) * float(f[4])
				var pn := _bale_surface(on, noise)
				# UVs in metres: along the bale on its long faces, across it on the ends.
				row.append([pn[0], pn[1], Vector2(tu * float(f[3]), tv * float(f[4]))])
			grid.append(row)
		for i in range(su):
			for j in range(sv):
				var a: Array = grid[i][j]
				var b: Array = grid[i + 1][j]
				var c: Array = grid[i + 1][j + 1]
				var d: Array = grid[i][j + 1]
				k.tri(kit, "hay", a[0], b[0], c[0], a[1], b[1], c[1], col, n, a[2], b[2], c[2])
				k.tri(kit, "hay", a[0], c[0], d[0], a[1], c[1], d[1], col, n, a[2], c[2], d[2])
	# Twine: four strings running round the bale lengthwise, over the top and down the ends.
	var twine := Color(0.93, 0.42, 0.07) if rng.randf() < 0.7 else Color(0.16, 0.36, 0.78)
	for z in [-0.33, -0.11, 0.11, 0.33]:
		var path: Array = []
		for i in range(9):
			path.append(Vector3(-BALE.x, BALE.y * float(i) / 8.0, z))
		for i in range(1, 24):
			path.append(Vector3(-BALE.x + 2.0 * BALE.x * float(i) / 24.0, BALE.y, z))
		for i in range(8, -1, -1):
			path.append(Vector3(BALE.x, BALE.y * float(i) / 8.0, z))
		var prev: Array = []
		for q in path:
			var pn := _bale_surface(q, noise)
			var p: Vector3 = (pn[0] as Vector3) + (pn[1] as Vector3) * 0.003
			var w := Vector3(0, 0, 0.007)
			if not prev.is_empty():
				k.quad(kit, "matte", [prev[0] - w, p - w, p + w, prev[0] + w], ((pn[1] as Vector3) + (prev[1] as Vector3)).normalized(), twine)
			prev = [p, pn[1]]
	# Loose straws poking out, most along the top edges.
	var straw_cols := [Color(0.86, 0.72, 0.40), Color(0.94, 0.86, 0.60), Color(0.62, 0.50, 0.26)]
	for i in range(70):
		var on := Vector3(rng.randf_range(-1, 1) * BALE.x, rng.randf_range(0.15, 1.0) * BALE.y, rng.randf_range(-1, 1) * BALE.z)
		# Onto the surface, often at an edge.
		match rng.randi() % 4:
			0, 1:
				on.y = BALE.y
				if rng.randf() < 0.6:
					on.z = signf(on.z) * BALE.z
			2:
				on.z = signf(on.z) * BALE.z
			3:
				on.x = signf(on.x) * BALE.x
		var pn := _bale_surface(on, noise)
		var root: Vector3 = (pn[0] as Vector3) - (pn[1] as Vector3) * 0.01
		var dir: Vector3 = ((pn[1] as Vector3) * rng.randf_range(0.3, 1.0) + Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 0.6), rng.randf_range(-1, 1)) * 0.8).normalized()
		var tip: Vector3 = root + dir * rng.randf_range(0.05, 0.16)
		var side: Vector3 = dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT).normalized() * 0.0035
		var sc: Color = straw_cols[rng.randi() % straw_cols.size()]
		k.tri(kit, "straw_loose", root - side, root + side, tip, pn[1], pn[1], pn[1], sc, side.cross(dir))


## A point of the bale's surface (`on` on the plain box) and its normal: the box's edges rounded,
## its faces bulging out between them, and lumps all over.
func _bale_surface(on: Vector3, noise: FastNoiseLite) -> Array:
	var lo := Vector3(-BALE.x, 0.0, -BALE.z) + Vector3.ONE * BALE_ROUND
	var hi := Vector3(BALE.x, BALE.y, BALE.z) - Vector3.ONE * BALE_ROUND
	var q := on.clamp(lo, hi)
	var d := on - q
	var n := d.normalized() if d.length() > 1e-6 else Vector3.UP
	var p := q + n * BALE_ROUND
	var fx := 1.0 - pow(on.x / BALE.x, 2.0)
	var fy := 1.0 - pow((on.y - BALE.y * 0.5) / (BALE.y * 0.5), 2.0)
	var fz := 1.0 - pow(on.z / BALE.z, 2.0)
	p += Vector3(n.x * 0.02 * fy * fz, n.y * 0.018 * fx * fz, n.z * 0.035 * fx * fy)
	p += n * noise.get_noise_3dv(on) * 0.014
	return [p, n]


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
		var yaw := _yaw_to(right)
		# On the highest ground under its footprint (the pad). The lowest ground within 3m of the front edge
		# reached down the pad's blend toward the road, which falls along the leg: the sections stood 0.15,
		# 0.63 and 2.62m sunk into the pad, the front rows' feet under the ground.
		var foot := _footprint_heights(_place(at, yaw), width * 0.5, rows * 0.75)
		at.y = foot.y
		if foot.y - foot.x > 0.4:
			push_error("Lakeside grandstand %d: the ground under it falls %.2fm, its front posts hang in the air" % [i, foot.y - foot.x])
		print("  grandstand %d at %.2f (ground under it %.2f to %.2f)" % [i, at.y, foot.x, foot.y])
		_kit.set_frame(_place(at, yaw))
		var hull := _bleacher(kit, width, rows)
		var pts := PackedVector3Array()
		var xf := _place(at, yaw)
		_stand_frames.append(xf)
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


## The lowest and highest ground (x, y) under a prop's rectangle, `half_w` either side of its x and from its
## front (z = 0) back to `depth`, in the life-size frame `xf`, on a 5 x 5 grid.
func _footprint_heights(xf: Transform3D, half_w: float, depth: float) -> Vector2:
	var lo := INF
	var hi := -INF
	for i in range(5):
		for j in range(5):
			var w: Vector3 = xf * Vector3(lerpf(-half_w, half_w, i / 4.0), 0.0, depth * j / 4.0)
			var g := _ground(w.x, w.z)
			lo = minf(lo, g)
			hi = maxf(hi, g)
	return Vector2(lo, hi)


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
## A tree's collider reaches this share of its branches' spread at a cart's height (the tips give).
const TREE_SOLID_SHARE := 0.7
## 3 modern animated wind turbines on the scenic ridge overlooking the large bridge.
func _build_wind_turbines(parent: Node3D) -> void:
	var container := Node3D.new()
	container.name = "WindTurbines"
	parent.add_child(container)

	# Shared mesh resources saved into res://generated/
	var tower_mesh: Mesh = _save_res(WindTurbineBuilder.build_tower_mesh(), "turbine_tower")
	var nacelle_mesh: Mesh = _save_res(WindTurbineBuilder.build_nacelle_mesh(), "turbine_nacelle")
	var rotor_mesh: Mesh = _save_res(WindTurbineBuilder.build_rotor_mesh(), "turbine_rotor")

	var specs := [
		{"name": "WindTurbine_West", "x": -510.0, "z": -740.0, "yaw": -15.0, "speed": 42.0, "angle": 25.0},
		{"name": "WindTurbine_Summit", "x": -470.0, "z": -750.0, "yaw": -22.0, "speed": 38.0, "angle": 95.0},
		{"name": "WindTurbine_East", "x": -430.0, "z": -720.0, "yaw": -30.0, "speed": 45.0, "angle": 190.0},
	]

	for i in range(specs.size()):
		var s: Dictionary = specs[i]
		var px: float = s["x"]
		var pz: float = s["z"]
		var gy: float = _ground(px, pz)
		var turbine: Node3D = WindTurbineBuilder.build_turbine(
			float(s["speed"]), float(s["angle"]), float(s["yaw"]),
			tower_mesh, nacelle_mesh, rotor_mesh
		)
		turbine.name = s["name"]
		turbine.position = Vector3(px, gy, pz)
		container.add_child(turbine)
		_note("WindTurbine_%d" % (i + 1), turbine.position, 6.0, 4.0)

	print("  3 modern animated wind turbines built on ridge overlooking large bridge")


## Expands the water surface to 12000x12000 and ensures seamless horizon fade. The ripples are
## scaled back to their size on the 1600m plane they were tuned on (TerrainGenerator._generate_water).
func _update_water_surface() -> void:
	var water := _level.get_node_or_null("TerrainGenerator/Water_Surface") as MeshInstance3D
	if not water:
		return
	var plane := PlaneMesh.new()
	plane.size = Vector2(12000.0, 12000.0)
	water.mesh = plane
	water.position = Vector3(0.0, -10.0, 0.0)
	water.set_meta("water_surface_y", -10.0)
	if water.material_override is ShaderMaterial:
		var wm := water.material_override as ShaderMaterial
		wm.set_shader_parameter("enable_water_edge_fade", true)
		wm.set_shader_parameter("water_fade_start", 1000.0)
		wm.set_shader_parameter("water_fade_end", 3500.0)
		wm.set_shader_parameter("sky_tint", HAZE)
		wm.set_shader_parameter("wave_scale", plane.size.x / 1600.0)


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
	var band_r: Array = near_meshes.map(func(m: Mesh) -> float: return Woodland.band_radius(m, 0.3, 2.0))
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
			if not alt_ok or _kept_out(keep_out, px, pz, 4.0) or _on_trail(px, pz, 3.5):
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
				# Out to the branches at a cart's height (a spruce's skirt), not just the trunk.
				var reach_r: float = TREE_SOLID_SHARE * float(band_r[mi]) * sc
				trunks.append([Vector3(px, y, pz), maxf(maxf(tr * 1.25, 0.35), reach_r), 5.0 * sc])
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
			if _slope(cx, cz) > 0.65 or _road_distance(cx, cz) < 14.0 or _kept_out(keep_out, cx, cz, 3.0) or _on_shortcut(cx, cz, 4.0) \
					or _on_trail(cx, cz, 3.0):
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
	if _slope(px, pz) > 0.7 or _road_distance(px, pz) < 11.0 or _kept_out(keep_out, px, pz, 2.0) or _on_trail(px, pz, 2.0):
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
	for n in ["Ramps/ConcreteRamp", "Ramps/LoopCSG", "LevelDesign/ConcreteFootbridge", "LevelDesign/Box", "LevelDesign/Box2",
			"LevelDesign/Bush"]:
		var p := _level.get_node_or_null(n) as Node3D
		if p:
			out.append([p.position.x, p.position.z, 22.0])
	# Where the boat and the two hay FBX stood, as before they went, so the woods grow as they did.
	for c in [BOAT_AT, Vector3(160.84, 0.0, -49.51), Vector3(152.01, 0.0, -39.01)]:
		out.append([c.x, c.z, 22.0])
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
	# The far and shadow stand-ins repeat the near cells' instances.
	if not ("Far" in node_name or "Shadow" in node_name):
		_stamps.append([mesh, transforms])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	return mmi


# ======================================================================================
#  Meadow grass
# ======================================================================================

const MEADOW_STEP := 0.5       # the grass map's texel (m)
const MEADOW_SIDE := 4000      # its texels a side, from GRID_START
const GRASS_TOP := 1.5         # geometry lower than this over the ground keeps the grass off
const GRASS_ROAD := 8.7        # no grass this close to a road's centreline (the curb ends at 8)
const GRASS_VERGE := 15.0      # from short to full height out to here
const GRASS_WATER := -9.85     # no grass below this (the lake is at -10)
const MOWN := 0.24             # the mown grass on the venue's verges and pads, as a share of full height

## The meadow (MeadowGrass.gd, meadow_grass.gdshader): tufts of real blades in three tiers that the
## shader stands on the ground and grows as the grass map says. The map (0.5m) is drawn here: the
## meadow thinner and shorter in the woods, mown on the clearings and pads, short along the verges,
## none on the roads (except under the bridge), in the lake or on cliffs, and none under anything
## standing on the ground: every prop's triangles near the ground, the trunks, boulders and hazel.
## It replaces TerrainGenerator's picture cards (no_grass), which took most of a re-bake's 13 minutes.
func _build_meadow(root: Node3D) -> void:
	var t0 := Time.get_ticks_msec()
	var node := Node3D.new()
	node.name = "Meadow"
	node.set_script(load("res://MeadowDetail.gd"))
	root.add_child(node)
	var data := _meadow_base()
	print("  meadow: base map (%.1fs)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	_meadow_roads(data)
	print("  meadow: roads (%.1fs)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	var blocked := _meadow_blockers(data)
	print("  meadow: %d texels under props (%.1fs)" % [blocked, (Time.get_ticks_msec() - t0) / 1000.0])
	var grass_tex: Texture2D = _save_res(MeadowGrass.grass_texture(data, MEADOW_SIDE), "meadow_map")
	var ht: Array = MeadowGrass.height_texture(_heights, GRID_RES + 1)
	var height_tex: Texture2D = _save_res(ht[0], "meadow_heights")
	var height_grid := Vector4(GRID_START, GRID_START, GRID_STEP, GRID_RES + 1)
	var grass_grid := Vector3(GRID_START, GRID_START, MEADOW_SIDE * MEADOW_STEP)
	var mats: Array[ShaderMaterial] = []
	var mms: Array[MultiMesh] = []
	var cells := 0
	for tier in range(MeadowGrass.TIERS.size()):
		var t: Dictionary = MeadowGrass.TIERS[tier]
		var mesh: Mesh = _save_res(MeadowGrass.tuft_mesh(tier, 1301 + tier), "meadow_tuft_%d" % tier)
		var mm: MultiMesh = _save_res(MeadowGrass.cell_multimesh(tier, mesh, 2203 + tier), "meadow_cells_%d" % tier)
		var mat: ShaderMaterial = _save_res(MeadowGrass.material(tier, height_tex, ht[1], grass_tex, height_grid, grass_grid), "meadow_mat_%d" % tier)
		mats.append(mat)
		mms.append(mm)
		var size: float = t["cell"]
		var fade_end: float = (t["fade"] as Vector2).y
		var reach: float = size * 0.71
		var n := int(MEADOW_SIDE * MEADOW_STEP / size)
		for cj in range(n):
			for ci in range(n):
				var x0: float = GRID_START + ci * size
				var z0: float = GRID_START + cj * size
				var hr := _meadow_cell(data, x0, z0, size)
				if hr.x > hr.y:
					continue
				var mmi := MultiMeshInstance3D.new()
				mmi.name = "Grass%d_%d_%d" % [tier, ci, cj]
				mmi.multimesh = mm
				mmi.material_override = mat
				mmi.position = Vector3(x0, 0.0, z0)
				# The tufts are at y = 0 in the MultiMesh; the shader lifts them onto the ground.
				mmi.custom_aabb = AABB(Vector3(-1.5, hr.x - 1.0, -1.5), Vector3(size + 3.0, hr.y - hr.x + 3.5, size + 3.0))
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mmi.visibility_range_end = fade_end + reach
				mmi.set_meta(&"fade_end", fade_end)
				mmi.set_meta(&"reach", reach)
				node.add_child(mmi)
				cells += 1
	node.set("materials", mats)
	node.set("multimeshes", mms)
	# TerrainGenerator's own grass is gone for good: a re-bake no longer grows it.
	_tg.set("no_grass", true)
	var old := _tg.get_node_or_null("GrassContainer")
	if old:
		_tg.remove_child(old)
		old.free()
	if DirAccess.dir_exists_absolute("res://generated/grass"):
		for f in DirAccess.get_files_at("res://generated/grass"):
			DirAccess.remove_absolute("res://generated/grass/" + f)
		DirAccess.remove_absolute("res://generated/grass")
	print("  meadow: %d cells in %d tiers (%.1fs)" % [cells, mms.size(), (Time.get_ticks_msec() - t0) / 1000.0])


## The meadow before the roads and props, on the terrain's 2m grid and blown up to the map's 0.5m:
## R how much grass, G how tall.
func _meadow_base() -> PackedByteArray:
	var forest := FastNoiseLite.new()
	forest.seed = 4711
	forest.frequency = 0.0045
	forest.fractal_octaves = 3
	var tallness := FastNoiseLite.new()
	tallness.seed = 5150
	tallness.frequency = 0.018
	tallness.fractal_octaves = 2
	var cl: PackedFloat32Array = _tg.get("grass_clearings")
	var pads: PackedFloat32Array = _tg.get("flat_pads")
	var mown_rects: Array = []
	for o in range(0, cl.size() - 5, 6):
		mown_rects.append([cl[o], cl[o + 1], cl[o + 2], cl[o + 3], cl[o + 4], maxf(cl[o + 5], 1.0)])
	for o in range(0, pads.size() - 6, 7):
		mown_rects.append([pads[o], pads[o + 1], pads[o + 2], pads[o + 3], pads[o + 4], 3.0])
	var n := GRID_RES
	var stride := GRID_RES + 1
	var base := PackedByteArray()
	base.resize(n * n * 2)
	for j in range(n):
		var z: float = GRID_START + (j + 0.5) * GRID_STEP
		for i in range(n):
			var x: float = GRID_START + (i + 0.5) * GRID_STEP
			var k := (j * n + i) * 2
			var h00: float = _heights[j * stride + i]
			var h11: float = _heights[(j + 1) * stride + i + 1]
			var h10: float = _heights[j * stride + i + 1]
			var h01: float = _heights[(j + 1) * stride + i]
			var g: float = (h00 + h11 + h10 + h01) * 0.25
			var steep: float = maxf(absf(h10 - h00), maxf(absf(h01 - h00), absf(h11 - h00))) / GRID_STEP
			if g < GRASS_WATER or steep > 1.65:
				continue
			var amount := 1.0
			var height: float = lerpf(0.68, 1.0, tallness.get_noise_2d(x, z) * 0.5 + 0.5)
			# Thinner and shorter where the woods are thick (the woods' own noise).
			var f: float = forest.get_noise_2d(x, z) + clampf((g - 4.0) * 0.012, -0.1, 0.15)
			var wood: float = smoothstep(0.35, 0.85, lerpf(0.035, 0.9, smoothstep(-0.02, 0.28, f)))
			amount *= lerpf(1.0, 0.45, wood)
			height *= lerpf(1.0, 0.75, wood)
			var mown := 0.0
			for r in mown_rects:
				var dx: float = x - float(r[0])
				var dz: float = z - float(r[1])
				var reach: float = float(r[2]) + float(r[3]) + float(r[5])
				if dx * dx + dz * dz > reach * reach:
					continue
				var c: float = cos(float(r[4]))
				var sn: float = sin(float(r[4]))
				var qx: float = absf(dx * c - dz * sn) - float(r[2])
				var qz: float = absf(dx * sn + dz * c) - float(r[3])
				var outside: float = Vector2(maxf(qx, 0.0), maxf(qz, 0.0)).length() + minf(maxf(qx, qz), 0.0)
				mown = maxf(mown, 1.0 - smoothstep(0.0, float(r[5]), outside))
			height = lerpf(height, MOWN, mown)
			base[k] = int(round(amount * 255.0))
			base[k + 1] = int(round(clampf(height, 0.0, 1.0) * 255.0))
	var img := Image.create_from_data(n, n, false, Image.FORMAT_RG8, base)
	img.resize(MEADOW_SIDE, MEADOW_SIDE, Image.INTERPOLATE_BILINEAR)
	return img.get_data()


## The roads in the map: no grass on the lap and the shortcuts (unless they're up on the bridge),
## short grass along their verges. Cross-sections every 0.4m, 0.25m apart across.
func _meadow_roads(data: PackedByteArray) -> void:
	var paths: Array = [_level.get_node("TrackPath")]
	var alts := _level.get_node_or_null("AlternativePaths")
	if alts:
		paths.append_array(alts.get_children().filter(func(c): return c is Path3D))
	var lap: Node = paths[0]
	for pth in paths:
		var c: Curve3D = (pth as Path3D).curve
		var xf: Transform3D = (pth as Path3D).global_transform
		var length := c.get_baked_length()
		var s := 0.0
		while s < length:
			var p: Vector3 = xf * c.sample_baked(s)
			var fwd: Vector3 = xf * c.sample_baked(minf(s + 0.6, length)) - xf * c.sample_baked(maxf(s - 0.6, 0.0))
			# Where the lap's road narrows into a gap (round the loop) mown grass grows up to the asphalt.
			var road_w: float = float(_tg.call("_road_gap_width", s)) if pth == lap else 1.0
			var road_lim: float = GRASS_ROAD if road_w >= 1.0 else (0.0 if road_w <= 0.0 else ROAD_HALF * road_w + 1.2)
			s += 0.4
			fwd.y = 0.0
			if fwd.length_squared() < 1e-6:
				continue
			fwd = fwd.normalized()
			var lat := -GRASS_VERGE - 0.25
			while lat < GRASS_VERGE:
				lat += 0.25
				var px: float = p.x - fwd.z * lat
				var pz: float = p.z + fwd.x * lat
				var ti := int((px - GRID_START) / MEADOW_STEP)
				var tj := int((pz - GRID_START) / MEADOW_STEP)
				if ti < 0 or tj < 0 or ti >= MEADOW_SIDE or tj >= MEADOW_SIDE:
					continue
				# Up on the bridge: the grass grows on under it.
				if p.y - _ground(px, pz) > 2.4:
					continue
				var k := (tj * MEADOW_SIDE + ti) * 2
				var a := absf(lat)
				if a < road_lim:
					data[k] = 0
				elif a < GRASS_ROAD:
					data[k + 1] = mini(data[k + 1], int(round(MOWN * 255.0)))
				else:
					data[k + 1] = mini(data[k + 1], int(round(lerpf(MOWN, 1.0, smoothstep(GRASS_ROAD, GRASS_VERGE, a)) * 255.0)))


## Clears the grass from under everything standing on the ground: the triangles of every prop in
## the dressing, the level's own props, the loop and the bridge's supports within GRASS_TOP of the
## ground, and the trunks, boulders and shrubs (their meshes' footprints at each instance).
## Each hit clears its texel and the eight round it. Returns the texels cleared.
func _meadow_blockers(data: PackedByteArray) -> int:
	var geometry: Array = []
	for n in [DRESSING, "LevelDesign", "Ramps", "FinishLine", "Checkpoints"]:
		var nd := _level.get_node_or_null(n)
		if nd:
			_meadow_geometry(nd, geometry)
	for c in _tg.get_children():
		if str(c.name).begins_with("BridgeSupport"):
			_meadow_geometry(c, geometry)
	_hit_mask.resize(MEADOW_SIDE * MEADOW_SIDE)
	_hit_mask.fill(0)
	_hits.clear()
	for g in geometry:
		_meadow_block_mesh(g[0], g[1])
	var footprints := {}
	for st in _stamps:
		var mesh: Mesh = st[0]
		if not footprints.has(mesh):
			footprints[mesh] = _meadow_footprint(mesh)
		var pts: PackedVector3Array = footprints[mesh]
		for xf in st[1]:
			for q in pts:
				_meadow_hit((xf as Transform3D) * q)
	for key in _hits:
		var ti: int = key % MEADOW_SIDE
		var tj: int = key / MEADOW_SIDE
		for dj in range(-1, 2):
			for di in range(-1, 2):
				var i := ti + di
				var j := tj + dj
				if i >= 0 and j >= 0 and i < MEADOW_SIDE and j < MEADOW_SIDE:
					data[(j * MEADOW_SIDE + i) * 2] = 0
	return _hits.size()


## [mesh, global transform] of every visible mesh under `node` (generated parts included), and the
## CSG roots' meshes (the loop). The woods, boulders and the meadow itself are left out.
func _meadow_geometry(node: Node, out: Array) -> void:
	var nm := str(node.name)
	if nm == "Woodland" or nm == "Boulders" or nm == "Meadow":
		return
	if node is MeshInstance3D and (node as MeshInstance3D).mesh and (node as MeshInstance3D).is_visible_in_tree():
		out.append([(node as MeshInstance3D).mesh, (node as MeshInstance3D).global_transform])
	elif node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh:
		var mm := (node as MultiMeshInstance3D).multimesh
		var gx := (node as MultiMeshInstance3D).global_transform
		var buf := mm.buffer
		var xfs: Array = []
		for i in range(mm.instance_count):
			var o := i * (12 + (4 if mm.use_colors else 0) + (4 if mm.use_custom_data else 0))
			xfs.append(gx * Transform3D(Vector3(buf[o], buf[o + 4], buf[o + 8]), Vector3(buf[o + 1], buf[o + 5], buf[o + 9]),
					Vector3(buf[o + 2], buf[o + 6], buf[o + 10]), Vector3(buf[o + 3], buf[o + 7], buf[o + 11])))
		if mm.mesh and not xfs.is_empty():
			_stamps.append([mm.mesh, xfs])
	elif node is CSGShape3D and (node as CSGShape3D).is_root_shape():
		var got: Array = (node as CSGShape3D).get_meshes()
		if got.size() >= 2 and got[1] is Mesh:
			out.append([got[1], (node as CSGShape3D).global_transform])
	for c in node.get_children(true):
		_meadow_geometry(c, out)


func _meadow_block_mesh(mesh: Mesh, xf: Transform3D) -> void:
	for si in range(mesh.get_surface_count()):
		if mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_primitive_type(si) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arr := mesh.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var w := PackedVector3Array()
		w.resize(v.size())
		for i in range(v.size()):
			w[i] = xf * v[i]
		var count := idx.size() / 3 if not idx.is_empty() else v.size() / 3
		for t in range(count):
			var a: Vector3 = w[idx[t * 3]] if not idx.is_empty() else w[t * 3]
			var b: Vector3 = w[idx[t * 3 + 1]] if not idx.is_empty() else w[t * 3 + 1]
			var c: Vector3 = w[idx[t * 3 + 2]] if not idx.is_empty() else w[t * 3 + 2]
			var g := _ground((a.x + b.x + c.x) / 3.0, (a.z + b.z + c.z) / 3.0)
			var lo := minf(a.y, minf(b.y, c.y))
			var hi := maxf(a.y, maxf(b.y, c.y))
			if lo > g + GRASS_TOP + 3.0 or hi < g - 1.0:
				continue
			var e := maxf(a.distance_to(b), maxf(b.distance_to(c), c.distance_to(a)))
			var n := clampi(ceili(e / 0.35), 1, 300)
			for i in range(n + 1):
				for j in range(n + 1 - i):
					_meadow_hit(a + (b - a) * (float(i) / n) + (c - a) * (float(j) / n))


## Marks the texel under `p` if `p` is near the ground there.
func _meadow_hit(p: Vector3) -> void:
	var ti := int((p.x - GRID_START) / MEADOW_STEP)
	var tj := int((p.z - GRID_START) / MEADOW_STEP)
	if ti < 0 or tj < 0 or ti >= MEADOW_SIDE or tj >= MEADOW_SIDE:
		return
	var k := tj * MEADOW_SIDE + ti
	if _hit_mask[k] != 0:
		return
	var g := _ground(p.x, p.z)
	if p.y > g + GRASS_TOP or p.y < g - 0.6:
		return
	_hit_mask[k] = 1
	_hits.append(k)


## Points over a mesh's triangles near its foot (local y under 2m), 0.25m apart: a trunk's or a
## boulder's footprint, to be stamped at each instance.
func _meadow_footprint(mesh: Mesh) -> PackedVector3Array:
	var seen := {}
	var out := PackedVector3Array()
	for si in range(mesh.get_surface_count()):
		var arr := mesh.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := idx.size() / 3 if not idx.is_empty() else v.size() / 3
		for t in range(count):
			var a: Vector3 = v[idx[t * 3]] if not idx.is_empty() else v[t * 3]
			var b: Vector3 = v[idx[t * 3 + 1]] if not idx.is_empty() else v[t * 3 + 1]
			var c: Vector3 = v[idx[t * 3 + 2]] if not idx.is_empty() else v[t * 3 + 2]
			if minf(a.y, minf(b.y, c.y)) > 2.0:
				continue
			var e := maxf(a.distance_to(b), maxf(b.distance_to(c), c.distance_to(a)))
			var n := clampi(ceili(e / 0.25), 1, 200)
			for i in range(n + 1):
				for j in range(n + 1 - i):
					var p := a + (b - a) * (float(i) / n) + (c - a) * (float(j) / n)
					if p.y > 2.0:
						continue
					var key := Vector3i(floori(p.x / 0.25), floori(p.y / 0.5), floori(p.z / 0.25))
					if not seen.has(key):
						seen[key] = true
						out.append(p)
	return out


## The ground's height range under a cell (min, max), or an empty range if no grass grows in it.
func _meadow_cell(data: PackedByteArray, x0: float, z0: float, size: float) -> Vector2:
	var t0i := int((x0 - GRID_START) / MEADOW_STEP)
	var t0j := int((z0 - GRID_START) / MEADOW_STEP)
	var span := int(size / MEADOW_STEP)
	var any := false
	var j := 0
	while j < span and not any:
		var i := 0
		while i < span:
			if data[((t0j + j) * MEADOW_SIDE + t0i + i) * 2] > 0:
				any = true
				break
			i += 3
		j += 3
	if not any:
		return Vector2(INF, -INF)
	var lo := INF
	var hi := -INF
	var stride := GRID_RES + 1
	var g0i := int((x0 - GRID_START) / GRID_STEP)
	var g0j := int((z0 - GRID_START) / GRID_STEP)
	var gs := int(size / GRID_STEP)
	for gj in range(g0j, mini(g0j + gs + 1, stride)):
		for gi in range(g0i, mini(g0i + gs + 1, stride)):
			var h: float = _heights[gj * stride + gi]
			lo = minf(lo, h)
			hi = maxf(hi, h)
	return Vector2(lo, hi + 1.5)


# ======================================================================================
#  Old props, ownership
# ======================================================================================

## The loop (Ramps/LoopCSG) was placed facing against the lap: the race drove into its exit lane and
## out through its entry, and since the road falls 1.2m across it, the lane the carts left by ended a
## metre above the road. Its lanes were 11m wide and only 6.5m apart, so the underside of the loop's
## last quarter hung over the entry lane down to its floor, and carts following the road drove into
## it. Now: lanes 8.5m wide, 10.5m apart (clear of each other with their walls), the loop's axis along
## the road and centred on it, and both lane ends 25cm under the road at the road's grade, so the
## carts roll on and off it. Exit lane 30m, gentler, and no boost pad on it.
# ======================================================================================
#  The woodcutter's yard and the marquee
# ======================================================================================

## The FBX the dressing replaced (removed from the level on every run, if still there): the yard's cart,
## logs and festival tent; the rowing boat (RowboatCSG.gd) and a stray copy of it at 1/18 the size that
## hung 37m over the lake's western arm, filed under Checkpoints; and two hay bales by the concrete ramp,
## gone for good. With them the course loads no FBX.
const OLD_FBX := ["WoodenCart", "LevelDesign/Logs", "LevelDesign/FestivalTent", "LevelDesign/Boat",
	"Checkpoints/be10e042cec0f40d5041acdc304a0ac3", "LevelDesign/Hay", "LevelDesign/Hay2"]
## [what, near (x, z), footprint radius in the level]: inside the long bend after the hill (s 500-626),
## where the cart stood as the old shortcut's ramp, and the marquee where the festival tent was.
const YARD := [
	["cabin", Vector2(250.0, -394.0), 6.0],
	["cart", Vector2(270.0, -398.0), 4.1],
	["logs", Vector2(266.0, -410.0), 3.9],
	["marquee", Vector2(-83.2, -511.6), 6.9],
]

func _build_venue(root: Node3D) -> void:
	for n in OLD_FBX:
		var old := _level.get_node_or_null(n)
		if old:
			old.get_parent().remove_child(old)
			old.free()
	var node := Node3D.new()
	node.name = "Woodyard"
	root.add_child(node)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var boxes: Array = []
	for item in YARD:
		var what: String = item[0]
		var radius: float = item[2]
		var at := _free_spot(item[1], radius)
		var yaw := _yaw_to(_curve.get_closest_point(at) - at)
		if what == "cart" or what == "logs":
			yaw += rng.randf_range(-0.9, 0.9)
		var xf := _place(at, yaw)
		var b := Basis(Vector3.UP, yaw)
		var kit := {}
		_kit.set_frame(xf)
		match what:
			"cabin":
				_venue.log_cabin(kit, rng)
				_venue.woodpile(kit, rng, -2.4, 1.75, -VenueKit.CABIN_HZ - VenueKit.CABIN_LOG_R)
				boxes.append([xf * Vector3(0, 1.3, 0), Vector3(VenueKit.CABIN_HX * 2.0 + 0.6, 2.6, VenueKit.CABIN_HZ * 2.0 + 0.6) * PROP_SCALE, b])
				boxes.append([xf * Vector3(VenueKit.CABIN_HX + 0.42, 2.2, 0.5), Vector3(0.75, 4.4, 0.9) * PROP_SCALE, b])
				boxes.append([xf * Vector3(-1.55, 0.5, -VenueKit.CABIN_HZ - 0.45), Vector3(1.9, 1.0, 0.6) * PROP_SCALE, b])
			"cart":
				_venue.hay_cart(kit, rng)
				_kit.set_frame(xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.0, 1.0, -0.15)))
				_hay_bale(kit, rng)
				boxes.append([xf * Vector3(0, 0.95, -0.2), Vector3(1.9, 1.9, 2.9) * PROP_SCALE, b])
				boxes.append([xf * Vector3(0, 0.3, -2.4), Vector3(1.0, 0.6, 1.9) * PROP_SCALE, b])
			"logs":
				_venue.log_stack(kit, rng)
				boxes.append([xf * Vector3(0, 0.8, 0), Vector3(2.6, 1.6, 4.3) * PROP_SCALE, b])
			"marquee":
				_venue.marquee(kit, Color(0.10, 0.28, 0.66), rng)
				for sx in [-1.0, 1.0]:
					for sz in [-1.0, 1.0]:
						boxes.append([xf * Vector3(sx * 3.0, 1.2, sz * 3.0), Vector3(0.2, 2.4, 0.2) * PROP_SCALE, b])
				# The two beer-table sets (VenueKit.beer_set at z = -1.2 and 1.2): table and benches as one block.
				for z in [-1.2, 1.2]:
					boxes.append([xf * Vector3(0.0, 0.39, z), Vector3(2.2, 0.78, 1.35) * PROP_SCALE, b])
		_kit.reset_frame()
		var mi := MeshInstance3D.new()
		mi.name = {"cabin": "LogCabin", "cart": "HayCart", "logs": "LogStack", "marquee": "Marquee"}[what]
		mi.mesh = _save_res(_venue.finish(kit), "venue_" + what)
		node.add_child(mi)
		_note(what, at, radius, 5.0)
		print("  %s at (%.0f, %.1f, %.0f), %.0fm off the road" % [what, at.x, at.y, at.z, _road_distance(at.x, at.z)])
	_boxes_body(node, "WoodyardBody", boxes)


## The nearest level place to `near` for something `radius` across: clear of the road, the shortcuts,
## the water and everything noted, on ground that doesn't fall more than 0.9m under it and isn't down a
## bank (3m+ under the road nearby); the lowest ground there, so it doesn't float.
func _free_spot(near: Vector2, radius: float) -> Vector3:
	for ring in range(0, 16):
		var rr := ring * 2.5
		var n := maxi(1, int(TAU * rr / 2.5))
		for k in range(n):
			var a := TAU * k / n
			var x := near.x + cos(a) * rr
			var z := near.y + sin(a) * rr
			if _spot_ok(x, z, radius):
				return Vector3(x, _ground_min(x, z, radius * 0.7), z)
	push_error("no free spot within 40m of %s for %.1fm" % [near, radius])
	return Vector3(near.x, _ground(near.x, near.y), near.y)


func _spot_ok(x: float, z: float, radius: float) -> bool:
	# _verify_clear's rule for what _build_venue notes (5m past the road's edge), and a little more.
	if _road_distance(x, z) < ROAD_HALF + radius + 5.5 or _on_shortcut(x, z, radius + 2.0):
		return false
	var lo := _ground(x, z)
	var hi := lo
	for k in range(8):
		var a := TAU * k / 8.0
		var g := _ground(x + cos(a) * radius * 0.8, z + sin(a) * radius * 0.8)
		lo = minf(lo, g)
		hi = maxf(hi, g)
	if hi - lo > 0.9 or lo < -9.0 or lo < _road_surface(Vector3(x, 0.0, z)) - 3.0:
		return false
	for f in _footprints:
		var c: Vector2 = f[1]
		if Vector2(x, z).distance_to(c) < radius + float(f[2]) + 1.5:
			return false
	return true


## The cabin's logs: tree_bark.gdshader set for weathered, debarked wood (pale, faint checks along it).
func _logwall_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://tree_bark.gdshader")
	m.set_shader_parameter("bark_color", Color(0.60, 0.53, 0.44))
	m.set_shader_parameter("fissure_color", Color(0.33, 0.28, 0.23))
	m.set_shader_parameter("fissure_width", 0.12)
	m.set_shader_parameter("fissure_depth", 0.008)
	m.set_shader_parameter("plate_stretch", 7.0)
	m.set_shader_parameter("roughness_value", 0.85)
	m.set_shader_parameter("lod_mode", 0)
	return m


# ======================================================================================
#  The rowing boat
# ======================================================================================

## Where the FBX boat lay, on the lake north of the woodyard's bend (its waterline), and the way its bow points.
const BOAT_AT := Vector3(175.13, -10.0, -496.62)
const BOAT_YAW := 0.085
## Life size times this: a little over PROP_SCALE, as big as the boat it replaced reads from the road.
const BOAT_SCALE := 2.0

## Builds the boat's CSG tree (RowboatCSG.gd) in the generator's own tree: it updates on the next frame.
func _start_rowboat() -> CSGCombiner3D:
	var csg := RowboatCSG.build()
	add_child(csg)
	return csg


## Bakes the updated tree into the boat's mesh and moors it where the FBX was.
func _finish_rowboat(root: Node3D, csg: CSGCombiner3D) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Rowboat"
	mi.mesh = _save_res(RowboatCSG.bake(csg, _material), "rowboat")
	mi.transform = Transform3D(Basis(Vector3.UP, BOAT_YAW).scaled(Vector3.ONE * BOAT_SCALE), BOAT_AT)
	root.add_child(mi)
	remove_child(csg)
	csg.free()
	# Solid as its hull's convex shape (the boat is open, but nothing gets in it). DressingColliders.gd
	# skips everything under LakesideDressing ("lake" is one of its water words), so it needs its own.
	var hull := mi.mesh.create_convex_shape(true, true)
	var pts := PackedVector3Array()
	for q in hull.points:
		pts.append(q * BOAT_SCALE)
	hull.points = pts
	var body := StaticBody3D.new()
	body.name = "RowboatBody"
	body.set_meta(&"surface", "wood")
	body.transform = Transform3D(Basis(Vector3.UP, BOAT_YAW), BOAT_AT)
	root.add_child(body)
	var cs := CollisionShape3D.new()
	cs.shape = _save_res(hull, "rowboat_collision")
	body.add_child(cs)
	print("  rowboat: %d surfaces, %.1fm long" % [mi.mesh.get_surface_count(), mi.mesh.get_aabb().size.z * BOAT_SCALE])


# ======================================================================================
#  The banked board turn
# ======================================================================================

## The bend round the woodyard (s 465-690: 125 degrees to the left, over both arms of the lake) is a
## banked board track. A timber deck lies over the road from curb to curb: level with it at both ends,
## it tilts up about its inner edge to BANK_ANGLE through the corner, its outer edge 4.9m over the road.
## A boarded wall runs along the top, sponsor boards on its inside, posts and battens outside, and on
## down to the road's edge so nothing gets in under the deck. The deck is its own body, "BankedDeck"
## (road to PlayerCart, `surface` wood); the wall is "BankedWall". Each holds its mesh, so
## DressingColliders leaves them be. The planks, paint and rubber are board_track.gdshader's.
const BANK_S := [465.0, 505.0, 650.0, 690.0]   # s where the bank starts to rise, is full, eases off, ends
const BANK_ANGLE := 0.2967                     # 17 degrees
const BANK_EDGE := 8.0                         # the deck's half width: the curb's outer edge
const BANK_LIFT := 0.06                        # the deck's inner edge over the road (0.02 at its ends)
const BANK_WALL_H := 1.4                       # the wall over the deck's outer edge
const BANK_WALL_T := 0.16
const BANK_WALL_FOOT := 0.35                   # how far the wall reaches under the road's surface
## Painted bands up the deck: [from, to] (m from its inner edge, in plan), colour. The rest is bare wood.
const BANK_PAINT := [
	[0.0, 1.1, Color(0.36, 0.62, 0.86)],   # the blue apron along the inside
	[1.5, 1.68, Color(0.08, 0.08, 0.09)],
	[3.3, 3.48, Color(0.82, 0.12, 0.10)],
	[7.6, 7.78, Color(0.12, 0.30, 0.72)],
]
const BANK_TIMBER := Color(0.60, 0.47, 0.34)
## The side of the road the bend's inside is on (-1 left), from the lap's turn.
var _bank_inner := -1.0


func _build_banked_turn(root: Node3D) -> void:
	var turn := (_frame(BANK_S[0])["fwd"] as Vector3).cross(_frame(BANK_S[3])["fwd"] as Vector3).y
	_bank_inner = -1.0 if turn > 0.0 else 1.0
	var node := Node3D.new()
	node.name = "BankedTurn"
	root.add_child(node)
	var width := BANK_EDGE * 2.0
	var s0: float = BANK_S[0]
	var s3: float = BANK_S[3]
	# Strips across the deck: [from, to, paint (alpha 0: bare wood)].
	var strips: Array = []
	var d := 0.0
	for b in BANK_PAINT:
		if float(b[0]) > d:
			strips.append([d, float(b[0]), Color(1, 1, 1, 0)])
		var pc: Color = b[2]
		strips.append([float(b[0]), float(b[1]), Color(pc.r, pc.g, pc.b, 1.0)])
		d = float(b[1])
	strips.append([d, width, Color(1, 1, 1, 0)])

	# The deck: a row of points across every metre, planar across, its normal from its neighbours.
	_kit.reset_frame()
	var n := ceili(s3 - s0)
	var rows: Array = []   # [s, points at the strips' edges, normal, cos of the bank]
	for i in range(n + 1):
		var s := lerpf(s0, s3, float(i) / n)
		var pts: Array = [_bank_point(s, 0.0)]
		for st in strips:
			pts.append(_bank_point(s, float(st[1])))
		var along := _bank_point(s + 0.5, BANK_EDGE) - _bank_point(s - 0.5, BANK_EDGE)
		var nrm := along.cross((pts[-1] as Vector3) - (pts[0] as Vector3)).normalized()
		if nrm.y < 0.0:
			nrm = -nrm
		rows.append([s, pts, nrm, cos(_bank_angle(s))])
	var deck := {}
	var faces := PackedVector3Array()
	for i in range(n):
		var r0: Array = rows[i]
		var r1: Array = rows[i + 1]
		var n0: Vector3 = r0[2]
		var n1: Vector3 = r1[2]
		for k in range(strips.size()):
			var st: Array = strips[k]
			var a: Vector3 = r0[1][k]
			var b: Vector3 = r0[1][k + 1]
			var c: Vector3 = r1[1][k + 1]
			var e: Vector3 = r1[1][k]
			var ua := Vector2(r0[0] - s0, float(st[0]) / r0[3])
			var ub := Vector2(r0[0] - s0, float(st[1]) / r0[3])
			var uc := Vector2(r1[0] - s0, float(st[1]) / r1[3])
			var ue := Vector2(r1[0] - s0, float(st[0]) / r1[3])
			_kit.tri(deck, "boardtrack", a, b, c, n0, n0, n1, st[2], n0, ua, ub, uc)
			_kit.tri(deck, "boardtrack", a, c, e, n0, n1, n1, st[2], n0, ua, uc, ue)
		# Collision: one quad across, wound like the kicker's deck (l on the left of travel).
		var l0: Vector3 = r0[1][0] if _bank_inner < 0.0 else r0[1][-1]
		var rr0: Vector3 = r0[1][-1] if _bank_inner < 0.0 else r0[1][0]
		var l1: Vector3 = r1[1][0] if _bank_inner < 0.0 else r1[1][-1]
		var rr1: Vector3 = r1[1][-1] if _bank_inner < 0.0 else r1[1][0]
		faces.append_array(PackedVector3Array([l0, rr1, rr0, l0, l1, rr1]))
	var deck_body := StaticBody3D.new()
	deck_body.name = "BankedDeck"
	deck_body.set_meta(&"surface", "wood")
	node.add_child(deck_body)
	var dcs := CollisionShape3D.new()
	var dshape := ConcavePolygonShape3D.new()
	dshape.set_faces(faces)
	dcs.shape = _save_res(dshape, "bank_deck_collision")
	deck_body.add_child(dcs)
	_commit(deck_body, deck, "BankedDeckBoards")

	# The wall, where the deck's outer edge is 0.3m or more over the road. Built at life size through
	# the kit's frame (PROP_SCALE), so the boards and timbers come out at the venue's scale.
	var w0 := s0
	while _bank_rise(w0) < 0.3:
		w0 += 0.5
	var w1 := s3
	while _bank_rise(w1) < 0.3:
		w1 -= 0.5
	var inv := 1.0 / PROP_SCALE
	_kit.set_frame(Transform3D(Basis().scaled(Vector3.ONE * PROP_SCALE), Vector3.ZERO))
	var kit := {}
	var wall_faces := PackedVector3Array()
	var m := ceili((w1 - w0) / 2.0)
	var prev: Dictionary = {}
	for i in range(m + 1):
		var s := lerpf(w0, w1, float(i) / m)
		var fr := _frame(s)
		var out: Vector3 = (fr["right"] as Vector3) * -_bank_inner
		var q: Vector3 = (fr["pos"] as Vector3) + out * BANK_EDGE
		var foot: float = (fr["pos"] as Vector3).y + _road_y - BANK_WALL_FOOT
		var deck_y := _bank_point(s, width).y
		var top := deck_y + lerpf(0.5, BANK_WALL_H, clampf(minf(s - w0, w1 - s) / 5.0, 0.0, 1.0))
		var cur := {"s": s, "out": out, "fwd": fr["fwd"],
				"if": Vector3(q.x, foot, q.z), "id": Vector3(q.x, deck_y, q.z), "it": Vector3(q.x, top, q.z),
				"of": Vector3(q.x, foot, q.z) + out * BANK_WALL_T, "ot": Vector3(q.x, top, q.z) + out * BANK_WALL_T}
		if i == 0 or i == m:
			# The wall's ends, boarded.
			var end_n: Vector3 = (cur["fwd"] as Vector3) * (-1.0 if i == 0 else 1.0)
			_wall_quad(kit, "battens", [cur["if"], cur["of"], cur["ot"], cur["it"]], end_n, s, inv)
			wall_faces.append_array(PackedVector3Array([cur["if"], cur["of"], cur["ot"], cur["if"], cur["ot"], cur["it"]]))
		if i % 2 == 0:
			# Posts outside, every 4m.
			var pq: Vector3 = (cur["of"] as Vector3) + out * 0.11
			_venue.timber(kit, Vector3(pq.x, foot - 0.05, pq.z) * inv, Vector3(pq.x, top + 0.12, pq.z) * inv, 0.22 * inv, 0.2 * inv,
					BANK_TIMBER.darkened(0.08), out)
		if not prev.is_empty():
			var pout: Vector3 = ((prev["out"] as Vector3) + out).normalized()
			# Inside, above the deck: boards along the wall. Outside: upright boards.
			_wall_quad(kit, "lapboards", [prev["id"], cur["id"], cur["it"], prev["it"]], -pout, s, inv, prev["s"])
			_wall_quad(kit, "battens", [prev["of"], cur["of"], cur["ot"], prev["ot"]], pout, s, inv, prev["s"])
			# A cap along the top and a wale outside where the deck meets the wall.
			var cap := pout * (BANK_WALL_T * 0.5) + Vector3(0, 0.06, 0)
			_venue.timber(kit, ((prev["it"] as Vector3) + cap) * inv, ((cur["it"] as Vector3) + cap) * inv, (BANK_WALL_T + 0.14) * inv,
					0.12 * inv, BANK_TIMBER, pout)
			var wale := pout * (BANK_WALL_T + 0.06) + Vector3(0, -0.25, 0)
			_venue.timber(kit, ((prev["id"] as Vector3) + wale) * inv, ((cur["id"] as Vector3) + wale) * inv, 0.26 * inv, 0.1 * inv,
					BANK_TIMBER.darkened(0.15), Vector3.UP)
			for f in [["if", "it"], ["of", "ot"], ["it", "ot"]]:
				var a: Vector3 = prev[f[0]]
				var b: Vector3 = cur[f[0]]
				var c: Vector3 = cur[f[1]]
				var e: Vector3 = prev[f[1]]
				wall_faces.append_array(PackedVector3Array([a, b, c, a, c, e]))
		prev = cur
	# Sponsor boards on the inside of the wall through the full bank, 8m each, 12m apart.
	var sb: float = float(BANK_S[1]) + 4.0
	while sb + 8.0 < float(BANK_S[2]) - 2.0:
		var ends: Array = []
		var face := Vector3.ZERO
		for sa in [sb, sb + 8.0]:
			var fr2 := _frame(sa)
			var out2: Vector3 = (fr2["right"] as Vector3) * -_bank_inner
			var q2: Vector3 = (fr2["pos"] as Vector3) + out2 * BANK_EDGE
			ends.append(Vector3(q2.x, _bank_point(sa, width).y + 0.3, q2.z))
			face -= out2
		_ad_board(kit, (ends[0] as Vector3) * inv, (ends[1] as Vector3) * inv, 1.0 * inv, face.normalized(), _next_ad())
		sb += 12.0
	# The deck's inner edge: a painted fascia down over the curb.
	var apron: Color = BANK_PAINT[0][2]
	for i in range(n):
		var r0: Array = rows[i]
		var r1: Array = rows[i + 1]
		var a: Vector3 = r0[1][0]
		var b: Vector3 = r1[1][0]
		var lo := -0.25 + _road_y
		var a_lo := Vector3(a.x, _curve.sample_baked(r0[0]).y + lo, a.z)
		var b_lo := Vector3(b.x, _curve.sample_baked(r1[0]).y + lo, b.z)
		var inward: Vector3 = (_frame(r0[0])["right"] as Vector3) * _bank_inner
		_wall_quad(kit, "painted", [a_lo, b_lo, b, a], inward, r1[0], inv, r0[0], apron)
	var wall_body := StaticBody3D.new()
	wall_body.name = "BankedWall"
	wall_body.set_meta(&"surface", "wood")
	node.add_child(wall_body)
	var wcs := CollisionShape3D.new()
	var wshape := ConcavePolygonShape3D.new()
	wshape.set_faces(wall_faces)
	wshape.backface_collision = true
	wcs.shape = _save_res(wshape, "bank_wall_collision")
	wall_body.add_child(wcs)
	_commit(wall_body, kit, "BankedWallTimber")
	print("  banked turn: s %.0f..%.0f at %d deg, the outer edge up to %.1fm over the road, its wall s %.0f..%.0f" % [
		s0, s3, int(round(rad_to_deg(BANK_ANGLE))), _bank_rise((s0 + s3) * 0.5), w0, w1])


## A wall quad (world points) facing `nrm`, through the life-size frame, with UVs in life metres:
## along the wall from `s_a` to `s` and up it.
func _wall_quad(kit: Dictionary, key: String, p: Array, nrm: Vector3, s: float, inv: float, s_a := NAN, col := BANK_TIMBER) -> void:
	var sa := s if is_nan(s_a) else s_a
	var uv: Array = []
	var lp: Array = []
	for k in range(4):
		var w: Vector3 = p[k]
		lp.append(w * inv)
		# Points 0 and 3 are at the segment's start, 1 and 2 at its end (end caps: all at `s`).
		var su := sa if (k == 0 or k == 3) else s
		uv.append(Vector2(su, w.y) * inv)
	if is_nan(s_a):
		# An end cap: across it instead of along.
		for k in range(4):
			uv[k] = Vector2(float(k == 1 or k == 2) * BANK_WALL_T, (p[k] as Vector3).y) * inv
	_kit.quad(kit, key, lp, nrm, col, uv)


## The deck at `s`, `d` metres across (in plan) from its inner edge, in the world.
func _bank_point(s: float, d: float) -> Vector3:
	var fr := _frame(s)
	var c: Vector3 = fr["pos"]
	var p: Vector3 = c + (fr["right"] as Vector3) * (_bank_inner * (BANK_EDGE - d))
	var lift := lerpf(0.02, BANK_LIFT, clampf(minf(s - float(BANK_S[0]), float(BANK_S[3]) - s) / 4.0, 0.0, 1.0))
	p.y = c.y + _road_y + lift + d * tan(_bank_angle(s))
	return p


## How far the deck's outer edge stands over its inner edge at `s`.
func _bank_rise(s: float) -> float:
	return BANK_EDGE * 2.0 * tan(_bank_angle(s))


func _bank_angle(s: float) -> float:
	var t := 1.0
	if s < float(BANK_S[1]):
		t = _smoother((s - float(BANK_S[0])) / (float(BANK_S[1]) - float(BANK_S[0])))
	elif s > float(BANK_S[2]):
		t = _smoother((float(BANK_S[3]) - s) / (float(BANK_S[3]) - float(BANK_S[2])))
	return BANK_ANGLE * t


static func _smoother(x: float) -> float:
	var t := clampf(x, 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


# ======================================================================================
#  Spectators
# ======================================================================================

## The start's crowd (CrowdPlacer.gd, Nyota Stadium's people at this level's 1.6 times life size): along
## the crowd barriers by the straight, filling the grandstand at the first corner, and round the
## paddock's tables. A European venue: SPECTATOR_SKIN weights crowd_common's groups.
const SPECTATOR_SCALE := PROP_SCALE / 1.86
const SPECTATOR_SKIN := [0.10, 0.08, 0.70, 0.07, 0.05]
## Of the grandstand's taken seats, the share whose spectator stands.
const STAND_UP_SHARE := 0.11

func _build_spectators(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7781
	var spots: Array = []
	# Behind the barriers, facing the road: a front row along them and a looser one behind.
	for b in _barrier_spots:
		var mid: Vector3 = b[0]
		var along: Vector3 = b[1]
		var cp := _curve.get_closest_point(mid)
		var away := Vector3(mid.x - cp.x, 0.0, mid.z - cp.z).normalized()
		for k in range(3):
			var u := rng.randf_range(-1.6, 1.6)
			var back := rng.randf_range(1.0, 1.6) if k < 2 else rng.randf_range(2.3, 3.4)
			if rng.randf() < (0.25 if k < 2 else 0.55):
				continue
			var p := mid + along * u + away * back
			p.y = _ground(p.x, p.z)
			spots.append([p, -away + along * rng.randf_range(-0.35, 0.35), false])
	# The grandstand: a seat every 0.55m on each of the seven rows (_bleacher: the seat boards' tops 0.72 +
	# 0.4 a row up, 0.57 + 0.75 a row back, life size), about two in three taken. A few stand up on the foot
	# board in front of their seat (its top 0.3 + 0.4 a row up, 0.16 + 0.75 a row back); only they wave
	# flags, since nothing hangs over the stand.
	var seated := 0
	for xf in _stand_frames:
		var fx: Transform3D = xf
		var face: Vector3 = fx.basis * Vector3(0, 0, -1)
		for r in range(7):
			var x := -2.8
			while x <= 2.81:
				if rng.randf() < 0.66:
					var xs := x + rng.randf_range(-0.05, 0.05)
					if rng.randf() < STAND_UP_SHARE:
						spots.append([fx * Vector3(xs, 0.3 + r * 0.4, r * 0.75 + 0.16), face, false, true])
					else:
						spots.append([fx * Vector3(xs, 0.72 + r * 0.4, r * 0.75 + 0.57), face, true, true])
						seated += 1
				x += 0.55
	# Round the paddock: a pair at each show car's table, looking at it, and a few more about.
	for g in _gazebo_frames:
		var gx: Transform3D = g[0]
		if g[1]:
			# At the table's ends, so they don't hide the car from the lane.
			for k in range(2):
				var p := gx * Vector3((1.0 if k == 0 else -1.0) * rng.randf_range(1.15, 1.45), 0.0, rng.randf_range(0.2, 0.9))
				p.y = _ground(p.x, p.z)
				var look: Vector3 = gx * Vector3(0.0, 0.0, 0.7) - p
				spots.append([p, look, false])
		if rng.randf() < 0.7:
			var q := gx * Vector3(rng.randf_range(-2.0, 2.0), 0.0, -2.6 - rng.randf_range(0.0, 1.5))
			q.y = _ground(q.x, q.z)
			spots.append([q, Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) + 0.01 * Vector3.RIGHT, false])
	# The race observer on the tower by race control, arms crossed.
	if not _observer_spot.is_empty():
		spots.append([_observer_spot[0], _observer_spot[1], false, false, CrowdPlacer.POSE_ARMS_CROSSED])
	# The playground's children and parents and the walkers on the footpaths (CrowdPlacer spots with a size).
	spots.append_array(_park_spots)
	CrowdPlacer.build(root, spots, SPECTATOR_SCALE, SPECTATOR_SKIN, 7781, func(res: Resource, n: String) -> Resource: return _save_res(res, n))
	print("  spectators: %d (%d seated)" % [spots.size(), seated])


const LOOP_EXIT_LENGTH := 30.0
## The loop stands on a platform of its own (_build_loop_apron): the road stops square at its ends (a road gap from
## LOOP_APRON_LEAD before the entry lane's start to LOOP_APRON_LEAD past the exit lane's end, tapering over
## LOOP_GAP_TAPER), and the concrete slab, flush with the road there, flares out to LOOP_APRON_HALF under both lanes,
## whose ends lie on it LOOP_END_LIP up. Before, the road either tapered to a point into the grass either side of the
## loop (the user found it ugly), or ran on under it with the lanes sinking into the asphalt, half on it (also ugly).
const LOOP_APRON_LEAD := 5.0
const LOOP_APRON_HALF := 11.2
const LOOP_APRON_FLARE := 9.0
const LOOP_APRON_DEPTH := 0.4
const LOOP_GAP_TAPER := 0.05
const LOOP_END_LIP := 0.05
## The road's edge (its curbs' outer edge) where the platform meets it.
const LOOP_APRON_ROAD_HALF := 8.0
const LOOP_TRACK_WIDTH := 8.5
const LOOP_SPIRAL_OFFSET := 10.5

## The gap in the road under the loop's platform, as TerrainGenerator.road_gaps: [s0, s1] along the lap, from the loop's
## saved place (which _fit_loop only slides onto the road), so it's the same on every run. Also sets the gap's square
## end, the curbs stopping there and the ground graded under the platform's whole width.
func _plan_road_gaps() -> PackedFloat32Array:
	var loop := _level.get_node_or_null("Ramps/LoopCSG") as Node3D
	if loop == null:
		return PackedFloat32Array()
	_tg.set("road_gap_taper", LOOP_GAP_TAPER)
	_tg.set("curbs_stop_at_gaps", true)
	_tg.set("road_gap_half_width", LOOP_APRON_HALF + 1.5)
	var ends := _loop_apron_span(loop)
	return PackedFloat32Array([snappedf(ends.x, 0.1), snappedf(ends.y, 0.1)])


## The platform's ends along the lap: LOOP_APRON_LEAD past the lanes' far ends.
func _loop_apron_span(loop: Node3D) -> Vector2:
	var z_in: float = -5.0 - float(loop.get("approach_length"))
	var z_out: float = -5.0 + LOOP_EXIT_LENGTH
	var a := _curve.get_closest_offset(loop.transform * Vector3(0.0, 0.0, z_in))
	var b := _curve.get_closest_offset(loop.transform * Vector3(0.0, 0.0, z_out))
	return Vector2(minf(a, b) - LOOP_APRON_LEAD, maxf(a, b) + LOOP_APRON_LEAD)


func _fit_loop() -> void:
	var loop := _level.get_node_or_null("Ramps/LoopCSG") as Node3D
	if loop == null:
		return
	var off := _curve.get_closest_offset(loop.position)
	var axis := _curve.sample_baked(fposmod(off + 25.0, _length)) - _curve.sample_baked(fposmod(off - 25.0, _length))
	axis.y = 0.0
	var on_road := _curve.sample_baked(off)
	# Basis.looking_at points -z at its target: the loop's lanes run toward +z.
	loop.transform = Transform3D(Basis.looking_at(-axis.normalized(), Vector3.UP), Vector3(on_road.x, loop.position.y, on_road.z))
	loop.set("track_width", LOOP_TRACK_WIDTH)
	loop.set("spiral_offset", LOOP_SPIRAL_OFFSET)
	# A 60 degree corner follows 55m after the exit: the exit pad boosted carts off it into the lake.
	loop.set("exit_boost", false)
	var half_shift: float = float(loop.get("spiral_offset")) * 0.5
	var z_in: float = -5.0 - float(loop.get("approach_length"))
	var z_out: float = -5.0 + LOOP_EXIT_LENGTH
	var road_in := _road_surface(loop.transform * Vector3(-half_shift, 0.0, z_in))
	var road_out := _road_surface(loop.transform * Vector3(half_shift, 0.0, z_out))
	loop.set("exit_length", LOOP_EXIT_LENGTH)
	# On the platform, a lip up (it is level with the road along its line).
	loop.set("entry_end_y", road_in - loop.position.y + LOOP_END_LIP)
	loop.set("exit_end_y", road_out - loop.position.y + LOOP_END_LIP)
	loop.set("road_grade", (road_out - road_in) / (z_out - z_in))
	# The pylons down into the ground beside the road, which falls away there: they started at the origin.
	var foot := 0.0
	for spot in loop.call("support_spots"):
		var w: Vector3 = loop.transform * Vector3(spot.x, 0.0, spot.y)
		foot = minf(foot, _ground_min(w.x, w.z, 1.0) - loop.position.y - 0.4)
	loop.set("support_foot_y", foot)
	loop.call("_rebuild")
	print("  loop ends: entry %.2f, exit %.2f under the origin, grade %.3f; pylons down to %.2f" % [loop.get("entry_end_y"),
			loop.get("exit_end_y"), loop.get("road_grade"), foot])


## The loop's platform: a slab LOOP_APRON_DEPTH thick along the lap over the road gap, its top level with the road's
## surface along the lap's line (so flush with the road at both ends), flat across, flaring from the road's edge
## (LOOP_APRON_ROAD_HALF) to LOOP_APRON_HALF over LOOP_APRON_FLARE; sides and ends down into the graded ground. Drawn by
## loop_apron.gdshader; solid ("LoopApronDeck": track, paved).
func _build_loop_apron(root: Node3D) -> void:
	var loop := _level.get_node_or_null("Ramps/LoopCSG") as Node3D
	if loop == null:
		return
	var span := _loop_apron_span(loop)
	var s0: float = span.x - 0.2
	var s1: float = span.y + 0.2
	# Rows about a metre apart along the lap, from end to end.
	var rows: Array = []
	var n := maxi(2, ceili(s1 - s0))
	for i in range(n + 1):
		var s: float = lerpf(s0, s1, float(i) / float(n))
		var fr := _frame(s)
		var t: float = minf(s - s0, s1 - s)
		var hw: float = lerpf(LOOP_APRON_ROAD_HALF, LOOP_APRON_HALF, smoothstep(0.0, LOOP_APRON_FLARE, t))
		var c: Vector3 = fr["pos"]
		c.y += _road_y
		rows.append([c, fr["right"], hw, s - s0])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := 9
	# The top.
	var top_rows: Array = []
	for r in rows:
		var c: Vector3 = r[0]
		var rt: Vector3 = r[1]
		var hw: float = r[2]
		var row := PackedVector3Array()
		for k in range(cols):
			var lat: float = lerpf(-hw, hw, float(k) / float(cols - 1))
			row.append(c + rt * lat)
		top_rows.append(row)
	var quad := func(a: Vector3, b: Vector3, c2: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, hw_a: float, hw_c: float, out: Vector3) -> void:
		# Two triangles a-b-c, a-c-d wound to face `out` (Godot's front faces: (c - a) x (b - a) along it).
		for tri in [[a, b, c2, ua, ub, uc, hw_a, hw_a, hw_c], [a, c2, d, ua, uc, ud, hw_a, hw_c, hw_c]]:
			var p0: Vector3 = tri[0]
			var p1: Vector3 = tri[1]
			var p2: Vector3 = tri[2]
			var order := [0, 1, 2]
			if (p2 - p0).cross(p1 - p0).dot(out) < 0.0:
				order = [0, 2, 1]
			for o in order:
				st.set_uv(tri[3 + o])
				st.set_uv2(Vector2(float(tri[6 + o]), 0.0))
				st.set_normal(out)
				st.add_vertex(tri[o])
	for i in range(rows.size() - 1):
		var r0: Array = rows[i]
		var r1: Array = rows[i + 1]
		var a_row: PackedVector3Array = top_rows[i]
		var b_row: PackedVector3Array = top_rows[i + 1]
		for k in range(cols - 1):
			var u0: float = lerpf(-float(r0[2]), float(r0[2]), float(k) / float(cols - 1))
			var u1: float = lerpf(-float(r0[2]), float(r0[2]), float(k + 1) / float(cols - 1))
			var w0: float = lerpf(-float(r1[2]), float(r1[2]), float(k) / float(cols - 1))
			var w1: float = lerpf(-float(r1[2]), float(r1[2]), float(k + 1) / float(cols - 1))
			quad.call(a_row[k], a_row[k + 1], b_row[k + 1], b_row[k], Vector2(u0, r0[3]), Vector2(u1, r0[3]), Vector2(w1, r1[3]), Vector2(w0, r1[3]),
					float(r0[2]), float(r1[2]), Vector3.UP)
		# The sides, down into the ground.
		for side in [0, cols - 1]:
			var pa: Vector3 = a_row[side]
			var pb: Vector3 = b_row[side]
			var rt0: Vector3 = r0[1]
			var out: Vector3 = rt0 * (1.0 if side > 0 else -1.0)
			var down := Vector3.DOWN * LOOP_APRON_DEPTH
			quad.call(pa, pb, pb + down, pa + down, Vector2(0, r0[3]), Vector2(0, r1[3]), Vector2(-LOOP_APRON_DEPTH, r1[3]), Vector2(-LOOP_APRON_DEPTH, r0[3]),
					0.0, 0.0, out)
	# The ends, down into the ground (hidden by the road but for a seam).
	for e in [[0, -1.0], [rows.size() - 1, 1.0]]:
		var row: PackedVector3Array = top_rows[e[0]]
		var fr2 := _frame(span.x - 0.2 if e[0] == 0 else span.y + 0.2)
		var out2: Vector3 = (fr2["fwd"] as Vector3) * float(e[1])
		var down2 := Vector3.DOWN * LOOP_APRON_DEPTH
		quad.call(row[0], row[cols - 1], row[cols - 1] + down2, row[0] + down2, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, 0.0, 0.0, out2)
	st.generate_tangents()
	var slab: ArrayMesh = st.commit()
	var node := Node3D.new()
	node.name = "LoopApron"
	root.add_child(node)
	var mi := MeshInstance3D.new()
	mi.name = "LoopApronSlab"
	mi.mesh = _save_res(slab, "loop_apron")
	var mat := ShaderMaterial.new()
	mat.shader = load("res://loop_apron.gdshader")
	mat.set_shader_parameter("concrete_tex", load("res://materials/concrete.png"))
	mat.set_shader_parameter("concrete_normal", load("res://materials/concrete_normal.png"))
	mat.set_shader_parameter("road_half", LOOP_APRON_ROAD_HALF)
	# A mid grey between the asphalt and the lanes' black: the texture's own brightness drew it almost white.
	mat.set_shader_parameter("concrete_tint", Color(0.50, 0.50, 0.48))
	# The entry lane's line across the platform and where it starts along it.
	var half_shift: float = float(loop.get("spiral_offset")) * 0.5
	var z_in: float = -5.0 - float(loop.get("approach_length"))
	var lane_start: Vector3 = loop.transform * Vector3(-half_shift, 0.0, z_in)
	var s_lane := _curve.get_closest_offset(lane_start)
	var fl := _frame(s_lane)
	var lat_lane: float = (lane_start - (fl["pos"] as Vector3)).dot(fl["right"])
	mat.set_shader_parameter("entry_lat", lat_lane)
	mat.set_shader_parameter("entry_v", s_lane - s0)
	mat.set_shader_parameter("lane_half", float(loop.get("track_width")) * 0.5)
	mi.material_override = _save_res(mat, "mat_loop_apron")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "LoopApronDeck"
	body.set_meta("surface", "asphalt")
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(slab.get_faces())
	shape.backface_collision = true
	cs.shape = shape
	body.add_child(cs)
	node.add_child(body)
	print("  loop platform: s %.0f-%.0f, %.1fm wide at most, entry lane %.1fm %s of the line" % [s0, s1, LOOP_APRON_HALF * 2.0, absf(lat_lane),
			"left" if lat_lane < 0.0 else "right"])


## A warning sign before the loop, right of the road: a yellow board on two posts with a black loop
## drawn on it (the road running in flat, round the loop a little further on, and out) and LOOP AHEAD under
## it. Life size, at PROP_SCALE; its front faces the carts coming. Its layers stand 2cm apart (3cm at
## PROP_SCALE): closer, the mobile renderer can't keep them apart.
const LOOP_SIGN_BEFORE := 75.0   # metres before the entry lane's start
const LOOP_SIGN_LAT := 12.5

func _build_loop_sign(root: Node3D) -> void:
	var loop := _level.get_node_or_null("Ramps/LoopCSG") as Node3D
	if loop == null:
		return
	var s_in := _curve.get_closest_offset(loop.transform * Vector3(0.0, 0.0, -5.0 - float(loop.get("approach_length"))))
	var s := s_in - LOOP_SIGN_BEFORE
	var fr := _frame(s)
	var at := _at(s, LOOP_SIGN_LAT)
	at.y = _ground_min(at.x, at.z, 1.2)
	# Facing the carts coming, turned a little toward the road.
	var yaw := _yaw_to(-(fr["fwd"] as Vector3)) - 0.18
	var xf := _place(at, yaw)
	var kit := {}
	_kit.set_frame(xf)
	var k := _kit
	var yellow := Color(1.0, 0.84, 0.12)
	var black := Color(0.05, 0.05, 0.06)
	var hw := 1.0
	var y0 := 1.5
	var y1 := 3.0
	for sx in [-0.7, 0.7]:
		k.tube(kit, "metal", Vector3(sx, 0.0, 0.05), Vector3(sx, y1 - 0.05, 0.05), 0.045, 0.045, 8, GALV)
	# The board: a black rim round a yellow face, its back grey.
	k.block(kit, "paint", Vector3(-hw, y0, -0.01), Vector3(hw, y1, 0.02), Color(0.55, 0.56, 0.58))
	k.quad(kit, "paint", [Vector3(-hw, y0, -0.03), Vector3(hw, y0, -0.03), Vector3(hw, y1, -0.03), Vector3(-hw, y1, -0.03)], Vector3.FORWARD, black)
	var e := 0.06
	k.quad(kit, "paint", [Vector3(-hw + e, y0 + e, -0.05), Vector3(hw - e, y0 + e, -0.05), Vector3(hw - e, y1 - e, -0.05), Vector3(-hw + e, y1 - e, -0.05)],
			Vector3.FORWARD, yellow)
	# The loop on the board's upper part: the road in along the bottom, round a circle shifted on a little
	# like the corkscrew, and out, left to right seen from the front (its -z: the board's local +x is the
	# viewer's left, so x is drawn negated; unflipped, the arrow pointed back at the carts).
	var r := 0.36
	var lead := 0.7
	var shift := 0.28
	var pts: Array[Vector2] = []
	for i in range(9):
		pts.append(Vector2(lead - lead * i / 8.0, 0.0))
	for i in range(1, 73):
		var t := TAU * i / 72.0
		pts.append(Vector2(-(shift * t / TAU + r * sin(t)), r * (1.0 - cos(t))))
	for i in range(1, 9):
		pts.append(Vector2(-(shift + lead * i / 8.0), 0.0))
	var n := pts.size() - 1
	var mid_x := (pts[0].x + pts[n].x) * 0.5
	var base := Vector2(-mid_x, y0 + 0.62)
	var w := 0.055
	var z := -0.07
	for i in range(n):
		var a: Vector2 = pts[i] + base
		var b: Vector2 = pts[i + 1] + base
		var na := _stroke_normal(pts, i) * w
		var nb := _stroke_normal(pts, i + 1) * w
		k.quad(kit, "paint", [Vector3(a.x - na.x, a.y - na.y, z), Vector3(b.x - nb.x, b.y - nb.y, z), Vector3(b.x + nb.x, b.y + nb.y, z),
				Vector3(a.x + na.x, a.y + na.y, z)], Vector3.FORWARD, black)
	# An arrowhead on the way out.
	var tip: Vector2 = pts[n] + base
	var dir: Vector2 = (pts[n] - pts[n - 3]).normalized()
	var side := Vector2(-dir.y, dir.x)
	var tip_end := tip + dir * 0.14
	var tz := z
	k.tri(kit, "paint", Vector3(tip_end.x, tip_end.y, tz), Vector3(tip.x + side.x * 0.12, tip.y + side.y * 0.12, tz),
			Vector3(tip.x - side.x * 0.12, tip.y - side.y * 0.12, tz), Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, black, Vector3.FORWARD)
	_commit(root, kit, "LoopSign")
	var label := Label3D.new()
	label.name = "LoopSignText"
	label.text = "LOOP AHEAD"
	label.font = _bold_font()
	label.font_size = 64
	label.pixel_size = 0.0036 * PROP_SCALE
	label.modulate = black
	label.outline_size = 0
	label.double_sided = false
	label.transform = xf * Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE / PROP_SCALE), Vector3(0.0, y0 + 0.3, -0.09))
	root.add_child(label)
	var b := Basis(Vector3.UP, yaw)
	_boxes_body(root, "LoopSignBody", [[xf * Vector3(0.0, (y0 + y1) * 0.5, 0.0), Vector3(hw * 2.0, y1 - y0, 0.1) * PROP_SCALE, b],
			[xf * Vector3(-0.7, y0 * 0.5, 0.05), Vector3(0.12, y0, 0.12) * PROP_SCALE, b],
			[xf * Vector3(0.7, y0 * 0.5, 0.05), Vector3(0.12, y0, 0.12) * PROP_SCALE, b]])
	_note("LoopSign", at, 1.2 * PROP_SCALE, 1.0)
	print("  loop sign at s %.0f, %.0fm off the road" % [s, _road_distance(at.x, at.z)])


## The unit normal of a polyline stroke at point `i` (the average of its two segments').
static func _stroke_normal(pts: Array[Vector2], i: int) -> Vector2:
	var a: Vector2 = pts[maxi(i - 1, 0)]
	var b: Vector2 = pts[mini(i + 1, pts.size() - 1)]
	var d := (b - a).normalized()
	return Vector2(-d.y, d.x)


## The road's surface height at `at`: the lap's nearest centreline point, raised by the road offset.
func _road_surface(at: Vector3) -> float:
	return _curve.get_closest_point(at).y + _road_y


## The AI's shortcuts (AlternativePaths/*): [node, s0, s1, leave, join]. Each leaves the lap's centreline
## at s0 and rejoins it at s1, a cubic across the inside of the bend laid on the ground; `leave` and `join`
## say how far its end handles turn from the lap's heading toward the chord (0 along the lap, 1 straight
## at the other end), so it parts from the road and merges back at a shallow angle. Hand-drawn, they were
## three straight legs meeting the lap side on just before a lake, where carts coming off them ran into
## the water. There was a second, AlternativePath2 (s 506-622), a jump off the high road onto the island
## inside that bend with the tilted wooden cart FBX as its ramp; the island is 5-22m under the road but for
## 70m of gentle bend, so there's no cut to drive, and _lay_shortcuts removes any path not listed here.
const SHORTCUTS := [
	["AlternativePath1", 2948.0, 3066.0, 0.55, 0.3],
]
const SHORTCUT_LIFT := 0.3
const SHORTCUT_HALF := 4.0
var _shortcut_curves: Array = []


func _lay_shortcuts() -> void:
	var holder := _level.get_node_or_null("AlternativePaths")
	if holder == null:
		holder = Node3D.new()
		holder.name = "AlternativePaths"
		_level.add_child(holder)
	for old in holder.get_children():
		if not SHORTCUTS.any(func(sc: Array) -> bool: return String(sc[0]) == String(old.name)):
			print("  shortcut %s removed" % old.name)
			holder.remove_child(old)
			old.free()
	# The level's own list of them (Level.alternative_paths) mustn't keep the removed one.
	var listed: Array[Path3D] = []
	for p in _level.get("alternative_paths"):
		if is_instance_valid(p):
			listed.append(p)
	_level.set("alternative_paths", listed)
	for sc in SHORTCUTS:
		var f0 := _frame(float(sc[1]))
		var f1 := _frame(float(sc[2]))
		var p0: Vector3 = f0["pos"]
		var p3: Vector3 = f1["pos"]
		var chord := p3 - p0
		chord.y = 0.0
		var span := chord.length()
		var cd := chord / span
		var d0: Vector3 = (f0["fwd"] as Vector3).lerp(cd, float(sc[3])).normalized()
		var d3: Vector3 = (f1["fwd"] as Vector3).lerp(cd, float(sc[4])).normalized()
		var p1 := p0 + d0 * span * 0.36
		var p2 := p3 - d3 * span * 0.36
		var curve := Curve3D.new()
		var n := ceili(span / 3.0)
		var lowest := INF
		var steepest := 0.0
		var widest := 0.0
		for i in range(n + 1):
			var t := float(i) / n
			var u := 1.0 - t
			var q := p0 * (u * u * u) + p1 * (3.0 * u * u * t) + p2 * (3.0 * u * t * t) + p3 * (t * t * t)
			var g := _ground(q.x, q.z)
			var rd := _road_distance(q.x, q.z)
			# On the road at its ends, on the ground between.
			q.y = (maxf(g, _road_surface(q)) if rd < ROAD_HALF + 1.0 else g) + SHORTCUT_LIFT
			curve.add_point(q)
			lowest = minf(lowest, g)
			steepest = maxf(steepest, _slope(q.x, q.z))
			widest = maxf(widest, rd)
		var path := holder.get_node_or_null(String(sc[0])) as Path3D
		if path == null:
			path = Path3D.new()
			path.name = String(sc[0])
			holder.add_child(path)
		path.transform = Transform3D.IDENTITY
		path.curve = curve
		_shortcut_curves.append(curve)
		var leave := rad_to_deg((f0["fwd"] as Vector3).angle_to(d0))
		var join := rad_to_deg((f1["fwd"] as Vector3).angle_to(d3))
		print("  shortcut %s: %.0fm for %.0fm of lap, parts at %.0f deg and joins at %.0f, up to %.0fm off the road, steepest %.2f" % [
			sc[0], curve.get_baked_length(), float(sc[2]) - float(sc[1]), leave, join, widest, steepest])
		if lowest < -9.6:
			push_error("shortcut %s runs into the lake (ground %.1f)" % [sc[0], lowest])
		if steepest > 0.45:
			push_error("shortcut %s climbs a %.2f slope" % [sc[0], steepest])


## Whether (x, z) is within `margin` of a shortcut's line (nothing that stops a cart stands there).
func _on_shortcut(x: float, z: float, margin: float) -> bool:
	for c in _shortcut_curves:
		var cp: Vector3 = (c as Curve3D).get_closest_point(Vector3(x, 0.0, z))
		if Vector2(cp.x - x, cp.z - z).length() < SHORTCUT_HALF + margin:
			return true
	return false


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


# ======================================================================================
#  The country round the Lakeside Meadows and Bloombay on its horizon
# ======================================================================================
# The terrain falls into the sea from 880m out (TerrainGenerator's edge falloff), which made the stage an island. Past it a
# ring of ground (BACK_R0 to BACK_R1) carries the land on away from the lake: across LAND_HALF either side of LAND_BEARING
# (opposite the big lake and the long bridge, which lie to the north-west) the country rolls on into farmland and woods,
# rising to ranges on the horizon, with Bloombay's skyline on a plain CITY_DIST out; elsewhere it falls into the sea and
# a low far shore closes the horizon. The first ring takes the terrain's own heights; inside BACK_NEAR it is drawn in
# the terrain's grass material (its UVs are world x and z, as the terrain's), so where the two overlap round the rim
# nothing shows; past it in vertex colour. Solid where land, out to BACK_SOLID.
const BACK_R0 := 830.0
const BACK_R1 := 3800.0
const BACK_SEGS := 480
const BACK_NEAR := 1300.0
const BACK_SOLID := 1500.0
const LAND_BEARING := 48.0
const LAND_HALF := 105.0
const CITY_DIST := 2350.0
const CITY_R := 620.0
## The fog now runs out past the city and the ranges (it ended at 1.6km, where the island's rim was).
const BACK_FOG := Vector2(300.0, 4600.0)

var _back_hills: FastNoiseLite
var _back_ridge: FastNoiseLite
var _back_patch: FastNoiseLite
var _back_rim := PackedFloat32Array()


## 1 across the land, 0 over the sea, by bearing (x = cos, z = sin, degrees).
func _land_weight(x: float, z: float) -> float:
	var d: float = absf(wrapf(rad_to_deg(atan2(z, x)) - LAND_BEARING, -180.0, 180.0))
	return 1.0 - smoothstep(LAND_HALF - 30.0, LAND_HALF + 10.0, d)


func _city_centre() -> Vector2:
	var a := deg_to_rad(LAND_BEARING)
	return Vector2(cos(a), sin(a)) * CITY_DIST


func _city_weight(x: float, z: float) -> float:
	return 1.0 - smoothstep(CITY_R * 0.75, CITY_R * 1.35, Vector2(x, z).distance_to(_city_centre()))


## The country's own height (rolling farmland, woods on the rises, ranges far out), the city's plain flattened in.
func _country(x: float, z: float, r: float) -> float:
	var h: float = 4.0 + _back_hills.get_noise_2d(x, z) * 34.0
	h += smoothstep(2300.0, 3500.0, r) * (70.0 + 170.0 * clampf(_back_ridge.get_noise_2d(x, z) + 0.5, 0.0, 1.5))
	return lerpf(h, 9.0, _city_weight(x, z))


## The ground at (x, z), r from the centre, `rim` the terrain's height at BACK_R0 on that bearing.
func _back_height(x: float, z: float, r: float, rim: float) -> float:
	var w := _land_weight(x, z)
	var land: float = lerpf(rim, _country(x, z, r), smoothstep(BACK_R0, 1250.0, r))
	var sea: float = lerpf(rim - 1.0, -34.0, smoothstep(BACK_R0, 1000.0, r))
	# The far shore across the water: low hills from 2.9km.
	sea = lerpf(sea, 6.0 + 60.0 * clampf(_back_ridge.get_noise_2d(x * 1.3, z * 1.3) + 0.5, 0.0, 1.2), smoothstep(2900.0, 3500.0, r))
	return lerpf(sea, land, w)


func _back_colour(p: Vector3, n: Vector3, r: float, grass: Color) -> Color:
	var slope := 1.0 - n.y
	var c := grass
	var fp: float = _back_patch.get_noise_2d(p.x, p.z)
	# Fields in a patchwork (squares of the patch noise sampled on a coarse grid), woods where the hills' noise is high.
	var cell := Vector2(floor(p.x / 140.0), floor(p.z / 110.0))
	var fh: float = fposmod(sin(cell.dot(Vector2(12.9898, 78.233))) * 43758.5453, 1.0)
	if fh < 0.35:
		c = c.lerp(Color(0.58, 0.56, 0.30), 0.55)
	elif fh < 0.5:
		c = c.lerp(Color(0.40, 0.50, 0.20), 0.5)
	if _back_hills.get_noise_2d(p.x, p.z) > 0.12 or fp > 0.35:
		c = Color(0.13, 0.22, 0.11)
	c = c.lerp(Color(0.42, 0.40, 0.36), smoothstep(0.35, 0.7, slope))
	c = c.lerp(Color(0.46, 0.45, 0.43), _city_weight(p.x, p.z) * 0.85)
	if p.y < -9.0:
		c = Color(0.36, 0.34, 0.28)
	return c


## The grass texture's mean colour (times the material's tint), so the far ground meets the near in the same green.
func _grass_mean() -> Color:
	var gm := _tg.get("grass_material") as ShaderMaterial
	var fallback := Color(0.30, 0.44, 0.17)
	if gm == null:
		return fallback
	var tex := gm.get_shader_parameter("albedo_texture") as Texture2D
	var img: Image = tex.get_image() if tex else null
	if img == null or img.is_empty():
		return fallback
	if img.is_compressed():
		img.decompress()
	img.resize(8, 8, Image.INTERPOLATE_BILINEAR)
	var acc := Color(0, 0, 0)
	for y in 8:
		for x in 8:
			acc += img.get_pixel(x, y)
	acc /= 64.0
	var tint: Color = gm.get_shader_parameter("albedo")
	return Color(acc.r * tint.r, acc.g * tint.g, acc.b * tint.b)


func _build_backdrop(root: Node3D) -> void:
	var t0 := Time.get_ticks_msec()
	_back_hills = FastNoiseLite.new()
	_back_hills.seed = 5501
	_back_hills.frequency = 1.0 / 620.0
	_back_hills.fractal_octaves = 4
	_back_ridge = FastNoiseLite.new()
	_back_ridge.seed = 5502
	_back_ridge.frequency = 1.0 / 1100.0
	_back_ridge.fractal_octaves = 3
	_back_patch = FastNoiseLite.new()
	_back_patch.seed = 5503
	_back_patch.frequency = 1.0 / 380.0
	_back_patch.fractal_type = FastNoiseLite.FRACTAL_NONE
	var node := Node3D.new()
	node.name = "Countryside"
	root.add_child(node)
	var radii := PackedFloat32Array()
	var r := BACK_R0
	while r < 1300.0:
		radii.append(r)
		r += 6.0
	while r < BACK_R1:
		radii.append(r)
		r *= 1.035
	radii.append(BACK_R1)
	var nr := radii.size()
	_back_rim.resize(BACK_SEGS)
	for j in range(BACK_SEGS):
		var a := TAU * j / BACK_SEGS
		_back_rim[j] = _ground(cos(a) * BACK_R0, sin(a) * BACK_R0)
	var pts := PackedVector3Array()
	pts.resize(nr * BACK_SEGS)
	for i in range(nr):
		for j in range(BACK_SEGS):
			var a := TAU * j / BACK_SEGS
			var x := cos(a) * radii[i]
			var z := sin(a) * radii[i]
			var h := _back_height(x, z, radii[i], _back_rim[j])
			# The first ring a hair under the terrain's own surface, which it meets.
			if i == 0:
				h -= 0.1
			pts[i * BACK_SEGS + j] = Vector3(x, h, z)
	var grass := _grass_mean()
	var near_st := SurfaceTool.new()
	near_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var far_st := SurfaceTool.new()
	far_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	for i in range(nr):
		for j in range(BACK_SEGS):
			var p := pts[i * BACK_SEGS + j]
			var pl := pts[i * BACK_SEGS + (j + BACK_SEGS - 1) % BACK_SEGS]
			var pr := pts[i * BACK_SEGS + (j + 1) % BACK_SEGS]
			var pi := pts[maxi(i - 1, 0) * BACK_SEGS + j]
			var po := pts[mini(i + 1, nr - 1) * BACK_SEGS + j]
			var n := (po - pi).cross(pr - pl).normalized()
			if n.y < 0.0:
				n = -n
			var c := _back_colour(p, n, radii[i], grass)
			for st2 in [near_st, far_st]:
				st2.set_normal(n)
				st2.set_color(c)
				st2.set_uv(Vector2(p.x, p.z))
				st2.add_vertex(p)
	for i in range(nr - 1):
		for j in range(BACK_SEGS):
			var ia := i * BACK_SEGS + j
			var ib := i * BACK_SEGS + (j + 1) % BACK_SEGS
			var ic := (i + 1) * BACK_SEGS + j
			var id := (i + 1) * BACK_SEGS + (j + 1) % BACK_SEGS
			for tri in [[ia, ib, ic], [ib, id, ic]]:
				var pa := pts[tri[0]]
				var pb := pts[tri[1]]
				var pc := pts[tri[2]]
				# Front faces wind clockwise seen from above: (c - a) x (b - a) points up.
				if (pc - pa).cross(pb - pa).y < 0.0:
					tri = [tri[0], tri[2], tri[1]]
				var st: SurfaceTool = near_st if radii[i + 1] <= BACK_NEAR else far_st
				for k in tri:
					st.add_index(k)
				var mid: Vector3 = (pa + pb + pc) / 3.0
				if radii[i + 1] <= BACK_SOLID and _land_weight(mid.x, mid.z) > 0.15 and mid.y > -12.0:
					faces.append(pts[tri[0]])
					faces.append(pts[tri[1]])
					faces.append(pts[tri[2]])
	var mesh := near_st.commit()
	mesh.surface_set_material(0, _tg.get("grass_material"))
	far_st.commit(mesh)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.95
	mesh.surface_set_material(1, _save_res(mat, "country_mat"))
	var body := StaticBody3D.new()
	body.name = "CountryGround"
	body.set_meta(&"surface", "grass")
	node.add_child(body)
	var mi := MeshInstance3D.new()
	mi.name = "CountryGroundMesh"
	mi.mesh = _save_res(mesh, "country_ground")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.shape = _save_res(shape, "country_collision")
	body.add_child(cs)
	_build_country_woods(node)
	_build_bloombay(node)
	print("  countryside: %d rings x %d, %.1fs" % [nr, BACK_SEGS, (Time.get_ticks_msec() - t0) / 1000.0])


## The ground of the countryside at (x, z), from the same function its mesh was built with.
func _country_ground(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	var j := int(round(fposmod(atan2(z, x), TAU) / TAU * BACK_SEGS)) % BACK_SEGS
	return _back_height(x, z, r, _back_rim[j])


## The woods carried on over the countryside: the woods' own far stand-ins (cards: oak, lime, birch, spruce), clumped
## by the hills' noise, thinning out to 2.6km, kept off the city, the water and the steep.
func _build_country_woods(node: Node3D) -> void:
	var kinds := ["oak", "lime", "birch", "spruce"]
	var meshes: Array = []
	for k in kinds:
		meshes.append(load("res://generated/" + RES_PREFIX + "tree_%s_0_far.res" % k))
	var rng := RandomNumberGenerator.new()
	rng.seed = 8821
	var cells := {}
	var count := 0
	var step := 15.0
	var x := -2700.0
	while x < 2700.0:
		var z := -2700.0
		while z < 2700.0:
			var px := x + rng.randf_range(-0.45, 0.45) * step
			var pz := z + rng.randf_range(-0.45, 0.45) * step
			var roll := rng.randf()
			z += step
			var r := Vector2(px, pz).length()
			if r < 870.0 or r > 2600.0:
				continue
			var w := _land_weight(px, pz)
			if w < 0.6 or _city_weight(px, pz) > 0.05:
				continue
			var woods: float = smoothstep(0.02, 0.22, _back_hills.get_noise_2d(px, pz)) + smoothstep(0.3, 0.5, _back_patch.get_noise_2d(px, pz))
			var dens: float = clampf(woods, 0.0, 1.0) * 0.8 * (1.0 - smoothstep(1500.0, 2600.0, r) * 0.6)
			if roll > dens:
				continue
			var g := _country_ground(px, pz)
			if g < -8.5:
				continue
			var slope := absf(_country_ground(px + 4.0, pz) - g) / 4.0 + absf(_country_ground(px, pz + 4.0) - g) / 4.0
			if slope > 0.9:
				continue
			var kind: int = 3 if (g > 40.0 or rng.randf() < 0.3) else rng.randi() % 3
			var sc := rng.randf_range(0.9, 1.3)
			var key := Vector3i(int(floor(px / 500.0)), int(floor(pz / 500.0)), kind)
			if not cells.has(key):
				cells[key] = []
			cells[key].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.9, 1.1), sc)), Vector3(px, g - 0.4, pz)))
			count += 1
		x += step
	# Named as the woods' deep far cells, so a JungleDetail of its own thins them with the Detail Level (its DEEP
	# shares: none at Off and Low, 30% at Medium, 70% at High, all at Ultra; 2.3ms of an M1's frame at 4320x2700 drawn
	# whole), each cell's instances shuffled so the first N are spread evenly.
	for key in cells.keys():
		var xfs: Array = cells[key]
		for i in range(xfs.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = xfs[i]
			xfs[i] = xfs[j]
			xfs[j] = tmp
		var mmi := _multimesh(meshes[key.z], xfs, "TreeDeepFar_country_%d_%d_%d" % [key.x, key.y, key.z])
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 3200.0
		node.add_child(mmi)
	var detail := Node3D.new()
	detail.name = "CountryDetail"
	detail.set_script(load("res://JungleDetail.gd"))
	node.add_child(detail)
	print("  country woods: %d trees in %d cells" % [count, cells.size()])


## Bloombay on its plain: blocks of three to seven storeys in a grid along the bearing, taller toward the middle,
## downtown's glass towers in the middle (BloombayCity.gd), a few landmark towers. Drawn to the far plane.
func _build_bloombay(node: Node3D) -> void:
	var city = load("res://BloombayCity.gd").new()
	city.begin()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2408
	var c := _city_centre()
	var a := deg_to_rad(LAND_BEARING)
	var along := Vector2(cos(a), sin(a))
	var across := Vector2(-along.y, along.x)
	var yaw := atan2(along.x, along.y)
	var bx := 78.0
	var bz := 64.0
	var u := -CITY_R * 1.2
	while u < CITY_R * 1.2:
		var v := -CITY_R * 1.2
		while v < CITY_R * 1.2:
			var p: Vector2 = c + along * (u + bx * 0.5) + across * (v + bz * 0.5)
			v += bz
			var cw := _city_weight(p.x, p.y)
			if cw < 0.15 or rng.randf() > cw * 1.1:
				continue
			var dt: float = exp(-pow(p.distance_to(c) / (CITY_R * 0.42), 2.0))
			if rng.randf() < dt * 0.55:
				var g0 := _country_ground(p.x, p.y)
				city.tower(p.x, p.y, g0, rng.randf_range(24.0, 36.0), rng.randi_range(14, 34), rng)
				continue
			# A block of two to four buildings round its edge.
			var lots := rng.randi_range(2, 4)
			for l in range(lots):
				var lw: float = (bx - 12.0) / float(lots)
				var q: Vector2 = p + along * ((float(l) + 0.5) * lw - (bx - 12.0) * 0.5) + across * rng.randf_range(-8.0, 8.0)
				var g := _country_ground(q.x, q.y)
				var storeys: int = rng.randi_range(3, 6) + int(dt * 6.0)
				var col: Color = city.WALL_PAINTS[rng.randi() % city.WALL_PAINTS.size()]
				city.building(q.x, q.y, g, lw - rng.randf_range(2.0, 5.0), rng.randf_range(24.0, 40.0), yaw, storeys, col,
						2 if storeys > 7 else rng.randi() % 2, rng.randi() % 4)
		u += bx
	var mesh: ArrayMesh = city.commit(_save_res(city.wall_material(Color(0.17, 0.41, 0.82), Color(0.70, 0.82, 0.93), Color(0.34, 0.40, 0.32),
			Color(1.0, 0.99, 0.96)), "city_walls_mat"), _save_res(city.roof_material(), "city_roofs_mat"))
	var mi := MeshInstance3D.new()
	mi.name = "BloombaySkyline"
	mi.mesh = _save_res(mesh, "bloombay_skyline")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	print("  Bloombay: %d buildings %.0fm out" % [city.count, CITY_DIST])


# ======================================================================================
#  The lookout tower (the user's models/lookout_tower.blend)
# ======================================================================================
# A timber fire-lookout tower (about 30m, a glazed cabin on a braced frame with stairs) on a rise beside the course:
# the best-scoring free spot (_spot_ok: clear of the road, the shortcut and every footprint, level ground) by how far it
# stands over the ground round it, within LOOKOUT_REACH of the road. The .blend's own ground pad, lights and cameras are
# left out; its meshes are merged per material, the glass drawn front faces only (Blender exports double-sided), and
# its frame's own triangles are its collider.
const LOOKOUT_MODEL := "res://models/lookout_tower.blend"
const LOOKOUT_REACH := Vector2(30.0, 140.0)
const LOOKOUT_SCALE := 1.0
## How far the tower keeps from the start/finish gantry: it is a landmark out on the lap, not part of the venue.
const LOOKOUT_FINISH_CLEAR := 450.0

## Whether (x, z) is within `margin` of a graded pad or its blend (the paddock, the grandstand's footing, the camp's
## terraces: the upper terrace's pitches note no footprints, and the tower first stood among its motorhomes).
func _on_pad(x: float, z: float, margin: float) -> bool:
	var pads: PackedFloat32Array = _tg.get("flat_pads")
	for o in range(0, pads.size() - 6, 7):
		var c := cos(pads[o + 4])
		var sn := sin(pads[o + 4])
		var dx := x - pads[o]
		var dz := z - pads[o + 1]
		# World to local: the inverse of Basis(UP, yaw).
		var lx := dx * c - dz * sn
		var lz := dx * sn + dz * c
		var m: float = margin + pads[o + 6]
		if absf(lx) < pads[o + 2] + m and absf(lz) < pads[o + 3] + m:
			return true
	return false


func _build_lookout(root: Node3D) -> void:
	var best := Vector3.ZERO
	var best_score := -INF
	var finish := _level.get_node_or_null("FinishLine") as Node3D
	var finish_xz := Vector2(finish.position.x, finish.position.z) if finish else Vector2.ZERO
	var x := -900.0
	while x < 900.0:
		var z := -900.0
		while z < 900.0:
			z += 12.0
			if Vector2(x, z).length() > 780.0 or Vector2(x, z).distance_to(finish_xz) < LOOKOUT_FINISH_CLEAR:
				continue
			var rd := _road_distance(x, z)
			if rd < LOOKOUT_REACH.x or rd > LOOKOUT_REACH.y:
				continue
			if not _spot_ok(x, z, 8.0) or _on_pad(x, z, 10.0):
				continue
			var g := _ground(x, z)
			if g < -6.0:
				continue
			var ring := 0.0
			for k in range(12):
				var ang := TAU * k / 12.0
				ring += _ground(x + cos(ang) * 45.0, z + sin(ang) * 45.0)
			var score: float = g - ring / 12.0 - rd * 0.02
			if score > best_score:
				best_score = score
				best = Vector3(x, g, z)
		x += 12.0
	if best_score == -INF:
		push_error("lookout tower: no free spot")
		return
	var y := _ground_min(best.x, best.z, 6.0)
	var p := _curve.get_closest_point(Vector3(best.x, 0.0, best.z))
	var face := atan2(p.x - best.x, p.z - best.z)
	var src: Node3D = (load(LOOKOUT_MODEL) as PackedScene).instantiate()
	var groups := {}
	var mats := {}
	var faces := PackedVector3Array()
	for m in src.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m
		if String(mi.name).begins_with("ground_pad"):
			continue
		var t := Transform3D.IDENTITY
		var n: Node = mi
		while n != src and n != null:
			if n is Node3D:
				t = (n as Node3D).transform * t
			n = n.get_parent()
		var nb := t.basis.inverse().transposed()
		for si in mi.mesh.get_surface_count():
			var mat: Material = mi.get_active_material(si)
			var mk: String = String(mat.resource_name) if mat else "none"
			if not mats.has(mk):
				var mm: Material = mat.duplicate() if mat else StandardMaterial3D.new()
				if mm is StandardMaterial3D and mk.to_lower().contains("glass"):
					(mm as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_BACK
				mats[mk] = _save_res(mm, "lookout_mat_" + mk.to_lower())
			var arr: Array = mi.mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var norms = arr[Mesh.ARRAY_NORMAL]
			var uvs = arr[Mesh.ARRAY_TEX_UV]
			var idx = arr[Mesh.ARRAY_INDEX]
			if not groups.has(mk):
				groups[mk] = [PackedVector3Array(), PackedVector3Array(), PackedVector2Array(), PackedInt32Array()]
			var g: Array = groups[mk]
			var base: int = (g[0] as PackedVector3Array).size()
			for k in range(verts.size()):
				g[0].append(t * verts[k])
				g[1].append((nb * (norms[k] as Vector3)).normalized() if norms != null and k < (norms as PackedVector3Array).size() else Vector3.UP)
				g[2].append((uvs as PackedVector2Array)[k] if uvs != null and k < (uvs as PackedVector2Array).size() else Vector2.ZERO)
			var ids: PackedInt32Array = idx if idx != null and (idx as PackedInt32Array).size() > 0 else PackedInt32Array(range(verts.size()))
			for k2 in ids:
				g[3].append(base + k2)
			if not mk.to_lower().contains("glass"):
				for k3 in ids:
					faces.append(t * verts[k3])
	src.free()
	var mesh := ArrayMesh.new()
	for mk in groups.keys():
		var g: Array = groups[mk]
		var arrs := []
		arrs.resize(Mesh.ARRAY_MAX)
		arrs[Mesh.ARRAY_VERTEX] = g[0]
		arrs[Mesh.ARRAY_NORMAL] = g[1]
		arrs[Mesh.ARRAY_TEX_UV] = g[2]
		arrs[Mesh.ARRAY_INDEX] = g[3]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrs)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mats[mk])
	var xf := Transform3D(Basis(Vector3.UP, face).scaled(Vector3.ONE * LOOKOUT_SCALE), Vector3(best.x, y, best.z))
	var body := StaticBody3D.new()
	body.name = "LookoutTower"
	body.transform = xf
	root.add_child(body)
	var tmi := MeshInstance3D.new()
	tmi.name = "LookoutTowerMesh"
	tmi.mesh = _save_res(mesh, "lookout_tower")
	body.add_child(tmi)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var cs := CollisionShape3D.new()
	cs.shape = _save_res(shape, "lookout_collision")
	body.add_child(cs)
	_note("lookout", Vector3(best.x, y, best.z), 8.0 * LOOKOUT_SCALE, 5.0)
	print("  lookout tower at (%.0f, %.1f, %.0f), %.0fm from the road, %.1fm over the ground round it" % [best.x, y, best.z,
			_road_distance(best.x, best.z), best_score + _road_distance(best.x, best.z) * 0.02])


# ======================================================================================
#  The playground by the marquee
# ======================================================================================
# On a pad of its own (graded with the others before the bake) PLAYGROUND_AWAY past the marquee's anchor, away from the
# road, its front (local -z) toward the road: ParkKit's swing set, slide tower, seesaw, roundabout, climbing dome and
# sandpit inside a rail fence with a gate at the front, benches for the parents, a bin, safety mats, a fingerpost by the
# gate where the footpath starts. Children (CrowdPlacer's people at PLAYGROUND_CHILD of their size) on the swings, the
# slide, the seesaw, the roundabout and round the sandpit; parents on the benches and watching. Positions in the pad's
# frame are world metres; the props are life size at PROP_SCALE. Each piece has its own box colliders (DressingColliders
# skips the dressing: "lake").
const PLAYGROUND_FROM := Vector2(-83.2, -511.6)
const PLAYGROUND_AWAY := 34.0
const PLAYGROUND_HALF := Vector2(14.0, 12.0)
const PLAYGROUND_BLEND := 8.0
const PLAYGROUND_CHILD := 0.58
const PLAYGROUND_CLIPS := ["res://sounds/playground_ambience.wav", "res://sounds/playground_ambience2.wav"]
const PLAYGROUND_RMS := [-36.9, -42.1]
const PLAYGROUND_LEVEL := -27.0
const PLAYGROUND_SOUND_UNIT := 10.0

var _park: ParkKit
## People for _build_spectators: the playground's and the walkers' (CrowdPlacer spots, with a size).
var _park_spots: Array = []
## The playground's gate (world) and its frame, for the footpath that starts there.
var _playground_gate := Vector3.ZERO
var _playground_xf := Transform3D.IDENTITY


## [centre (x, z), yaw] of the playground's pad: its front (-z) faces the road past the marquee.
func _playground_frame() -> Array:
	var cp := _curve.get_closest_point(Vector3(PLAYGROUND_FROM.x, 0.0, PLAYGROUND_FROM.y))
	var away := Vector2(PLAYGROUND_FROM.x - cp.x, PLAYGROUND_FROM.y - cp.z).normalized()
	var c := PLAYGROUND_FROM + away * PLAYGROUND_AWAY
	return [c, atan2(away.x, away.y)]


func _build_playground(root: Node3D) -> void:
	if _park == null:
		_park = ParkKit.new(_kit, _venue)
	var fr := _playground_frame()
	var c: Vector2 = fr[0]
	var yaw: float = fr[1]
	var y := _ground(c.x, c.y)
	var base := Transform3D(Basis(Vector3.UP, yaw), Vector3(c.x, y, c.y))
	_playground_xf = base
	var b := base.basis
	var node := Node3D.new()
	node.name = "Playground"
	root.add_child(node)
	var kit := {}
	var boxes: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var s := PROP_SCALE
	# [world position in the pad's frame, turn]: each item's frame.
	var at := func(p: Vector3, turn: float) -> Transform3D:
		return base * Transform3D(Basis(Vector3.UP, turn).scaled(Vector3.ONE * s), p)
	var spots: Array = []
	var child := PLAYGROUND_CHILD
	# Safety mats under the swings, the slide's foot and the dome.
	_kit.set_frame(base)
	_park.safety_mat(kit, Vector2(-11.0, 1.5), Vector2(-2.0, 7.5), Color(0.62, 0.16, 0.12))
	_park.safety_mat(kit, Vector2(3.4, -9.6), Vector2(10.6, -4.2), Color(0.18, 0.42, 0.20))
	# The swing set.
	var sw: Transform3D = at.call(Vector3(-6.5, 0.0, 4.5), 0.0)
	_kit.set_frame(sw)
	var seats: Array = _park.swing_set(kit, Color(0.10, 0.45, 0.25), [Color(0.95, 0.75, 0.10), Color(0.15, 0.45, 0.90)])
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			boxes.append([sw * Vector3(sx * 2.4, 1.1, sz * 0.5), Vector3(0.2, 2.3, 1.2) * s, b])
	boxes.append([sw * Vector3(0.0, 2.35, 0.0), Vector3(5.0, 0.15, 0.15) * s, b])
	for i in range(seats.size()):
		var seat: Vector3 = sw * (seats[i] as Vector3)
		if i == 0:
			spots.append([seat, b * Vector3(0, 0, -1), true, false, [0, 1, 5][rng.randi() % 3], child])
		else:
			# A parent pushing the other swing, behind it.
			spots.append([sw * Vector3(seats[i].x, 0.0, 0.85), b * Vector3(0, 0, -1), false, false, 7, 1.0])
			spots.append([seat, b * Vector3(0, 0, -1), true, false, 5, child])
	# The slide tower, its slide toward the front.
	var sl: Transform3D = at.call(Vector3(6.5, 0.0, 4.0), 0.0)
	_kit.set_frame(sl)
	var deck: Vector3 = sl * _park.slide_tower(kit, Color(0.85, 0.20, 0.15), Color(0.98, 0.70, 0.08))
	boxes.append([sl * Vector3(0.0, 1.4, 0.0), Vector3(1.5, 2.8, 1.5) * s, b])
	boxes.append([sl * Vector3(0.0, 0.5, -2.4), Vector3(0.7, 1.0, 3.4) * s, b])
	boxes.append([sl * Vector3(0.0, 0.8, 1.1), Vector3(0.7, 1.6, 0.8) * s, b])
	spots.append([deck + b * Vector3(0.0, 0.0, -0.3), b * Vector3(0, 0, -1), false, false, 9, child])
	spots.append([sl * Vector3(0.0, 0.0, -4.6), b * Vector3(0, 0, 1), false, false, 14, child])
	# The seesaw, along x.
	var ss: Transform3D = at.call(Vector3(-6.5, 0.0, -6.0), 0.0)
	_kit.set_frame(ss)
	var ends: Array = _park.seesaw(kit, Color(0.20, 0.55, 0.95))
	boxes.append([ss * Vector3(0.0, 0.45, 0.0), Vector3(3.6, 0.5, 0.45) * s, b])
	for i in range(ends.size()):
		var e: Vector3 = ends[i]
		spots.append([ss * e, b * Vector3(-signf(e.x), 0, 0), true, false, [0, 5][i], child])
	# The roundabout.
	var rb: Transform3D = at.call(Vector3(0.0, 0.0, -1.5), 0.0)
	_kit.set_frame(rb)
	_park.roundabout(kit, Color(0.95, 0.45, 0.10), Color(0.15, 0.35, 0.80))
	boxes.append([rb * Vector3(0.0, 0.2, 0.0), Vector3(2.0, 0.4, 2.0) * s, b])
	for a in [0.4, 2.6]:
		spots.append([rb * Vector3(cos(a) * 0.62, 0.3, sin(a) * 0.62), b * Vector3(-sin(a), 0, cos(a)), false, false, [9, 14][rng.randi() % 2], child])
	# The climbing dome.
	var dm: Transform3D = at.call(Vector3(7.0, 0.0, -7.0), 0.0)
	_kit.set_frame(dm)
	_park.climbing_dome(kit, Color(0.85, 0.15, 0.55))
	boxes.append([dm * Vector3(0.0, 0.8, 0.0), Vector3(2.4, 1.6, 2.4) * s, b])
	spots.append([dm * Vector3(1.9, 0.0, 0.6), b * Vector3(-1, 0, 0), false, false, 14, child])
	# The sandpit, children round it.
	var sp: Transform3D = at.call(Vector3(-0.5, 0.0, 8.0), 0.0)
	_kit.set_frame(sp)
	_park.sandpit(kit, rng)
	boxes.append([sp * Vector3(0.0, 0.1, 0.0), Vector3(3.4, 0.2, 3.4) * s, b])
	spots.append([sp * Vector3(-1.6, 0.24, 0.3), b * Vector3(1, 0, 0), true, false, 3, child])
	spots.append([sp * Vector3(0.4, 0.24, -1.6), b * Vector3(0, 0, 1), true, false, 0, child])
	spots.append([sp * Vector3(0.6, 0.12, 0.5), b * Vector3(-1, 0, -0.3), false, false, 7, child * 0.92])
	# Benches along the sides, facing in, with parents on them; a bin by the gate.
	for e in [[Vector3(-12.6, 0.0, -1.0), PI * 0.5], [Vector3(12.6, 0.0, 1.0), -PI * 0.5], [Vector3(4.0, 0.0, 10.9), PI]]:
		var bx: Transform3D = at.call(e[0], e[1])
		_kit.set_frame(bx)
		_park.park_bench(kit)
		boxes.append([bx * Vector3(0.0, 0.45, 0.0), Vector3(1.9, 0.9, 0.6) * s, b * Basis(Vector3.UP, e[1])])
		var face: Vector3 = (b * Basis(Vector3.UP, float(e[1]))) * Vector3(0, 0, -1)
		spots.append([bx * Vector3(rng.randf_range(-0.5, 0.5), 0.45, -0.05), face, true, false, [0, 3, 6][rng.randi() % 3], 1.0])
	var bn: Transform3D = at.call(Vector3(3.0, 0.0, -11.2), 0.0)
	_kit.set_frame(bn)
	_park.bin(kit)
	boxes.append([bn * Vector3(0.0, 0.5, 0.0), Vector3(0.45, 1.0, 0.45) * s, b])
	# Parents watching from inside the fence, and two chatting at the gate.
	spots.append([base * Vector3(-3.0, 0.0, 1.0), b * Vector3(-0.6, 0, 1), false, false, 11, 1.0])
	spots.append([base * Vector3(2.0, 0.0, -5.5), b * Vector3(0.5, 0, -1), false, false, 13, 1.0])
	spots.append([base * Vector3(-1.2, 0.0, -13.6), b * Vector3(1, 0, 0.2), false, false, 7, 1.0])
	spots.append([base * Vector3(0.0, 0.0, -13.7), b * Vector3(-1, 0, 0.1), false, false, 15, 1.0])
	spots.append([base * Vector3(-0.6, 0.0, -14.4), b * Vector3(0.2, 0, 1), false, false, 7, child])
	# The fence round the pad's edge, a gate gap at the front, and the fingerpost outside it.
	var fx := PLAYGROUND_HALF.x - 1.0
	var fz := PLAYGROUND_HALF.y - 1.0
	_kit.set_frame(base * Transform3D(Basis.from_scale(Vector3.ONE), Vector3.ZERO))
	var fence_col := Color(0.55, 0.42, 0.28)
	var runs := [[Vector3(-fx, 0, -fz), Vector3(-1.6, 0, -fz)], [Vector3(1.6, 0, -fz), Vector3(fx, 0, -fz)], [Vector3(fx, 0, -fz), Vector3(fx, 0, fz)],
			[Vector3(fx, 0, fz), Vector3(-fx, 0, fz)], [Vector3(-fx, 0, fz), Vector3(-fx, 0, -fz)]]
	for r in runs:
		_park.fence_run(kit, r[0], r[1], fence_col)
		boxes.append(_wall_box(base * (r[0] as Vector3), base * (r[1] as Vector3), 0.15, 1.0))
	var post: Transform3D = at.call(Vector3(-2.6, 0.0, -fz - 1.2), 0.0)
	_kit.set_frame(post)
	_park.fingerpost(kit, [0.6, -1.9])
	boxes.append([post * Vector3(0.0, 1.0, 0.0), Vector3(0.2, 2.2, 0.2) * s, b])
	_playground_gate = base * Vector3(0.0, 0.0, -fz - 2.0)
	_kit.reset_frame()
	var mi := MeshInstance3D.new()
	mi.name = "PlaygroundKit"
	mi.mesh = _save_res(_venue.finish(kit), "playground")
	mi.visibility_range_end = 420.0
	node.add_child(mi)
	_boxes_body(node, "PlaygroundBody", boxes)
	# Children playing: the user's two recordings from two corners (the swings and slide, the seesaw and sandpit), each
	# levelled by its RMS to PLAYGROUND_LEVEL at PLAYGROUND_SOUND_UNIT metres.
	for k in range(PLAYGROUND_CLIPS.size()):
		var amb := AudioStreamPlayer3D.new()
		amb.name = "PlaygroundSound%d" % k
		amb.stream = load(PLAYGROUND_CLIPS[k])
		amb.volume_db = PLAYGROUND_LEVEL - float(PLAYGROUND_RMS[k])
		amb.unit_size = PLAYGROUND_SOUND_UNIT
		amb.max_distance = 160.0
		amb.bus = &"SFX"
		amb.autoplay = true
		amb.position = base * ([Vector3(0.0, 2.0, 5.0), Vector3(-4.0, 2.0, -4.0)][k] as Vector3)
		node.add_child(amb)
	_note("playground", Vector3(c.x, y, c.y), 4.0, 5.0)
	_park_spots.append_array(spots)
	print("  playground at (%.0f, %.1f, %.0f), %.0fm off the road, %d people" % [c.x, y, c.y, _road_distance(c.x, c.y), spots.size()])


# ======================================================================================
#  The paths: the bike path round the country south and east of the lap, the footpaths in the meadows north of it
# ======================================================================================
# Each path is routed between anchors (TRAILS: [name, kind, anchors (x, z), closed]) on a TRAIL_CELL grid by AStarGrid2D:
# solid in the water (and a shore margin), on the road and its verges (only under a bridge high over the ground may a
# path pass), on the pads, the footprints and the shortcut, past TRAIL_REACH and on ground steeper than TRAIL_MAX_SLOPE;
# dearer on slopes and near the road. An anchor in a solid cell moves to the nearest open one. The cells are smoothed
# (Chaikin) and resampled every metre, and a ribbon (trail_path.gdshader, "Trail_*": no collider, DressingColliders'
# "trail") lies on the ground along each, its vertices on the ground across it. The woods, shrubs and boulders keep off
# them (_on_trail). Riders (Cyclists.gd) ride the closed bike path both ways; walkers (CrowdPlacer) stand along the
# footpaths in ones and twos, and sit on benches at the viewpoints (ParkKit.park_bench beside the path).
const TRAIL_CELL := 6.0
const TRAIL_REACH := 790.0
const TRAIL_MAX_SLOPE := 0.85
const TRAIL_WATER := -8.6
const TRAIL_ROAD_CLEAR := 9.0
const BIKE_PATH_WIDTH := 4.2
const FOOTPATH_WIDTH := 2.4
const TRAILS := [
	["BikeEast", 1, [Vector2(-560.0, 560.0), Vector2(-180.0, 430.0), Vector2(170.0, 400.0), Vector2(430.0, 250.0), Vector2(560.0, -60.0),
			Vector2(590.0, -320.0), Vector2(720.0, -140.0), Vector2(710.0, 260.0), Vector2(500.0, 520.0), Vector2(200.0, 720.0),
			Vector2(-160.0, 780.0), Vector2(-430.0, 690.0)], true],
	["BikeSouth", 1, [Vector2(-520.0, 600.0), Vector2(-260.0, 470.0), Vector2(-206.0, 318.0), Vector2(-94.0, 318.0), Vector2(-30.0, 322.0),
			Vector2(40.0, 324.0), Vector2(60.0, 430.0), Vector2(300.0, 560.0), Vector2(120.0, 760.0),
			Vector2(-240.0, 740.0)], true],
	["MeadowWalk", 0, [Vector2(-110.0, -640.0), Vector2(60.0, -640.0), Vector2(210.0, -770.0), Vector2(20.0, -850.0), Vector2(-200.0, -760.0),
			Vector2(-230.0, -650.0)], true],
	["PlaygroundWalk", 0, [Vector2.INF, Vector2(-110.0, -640.0)], false],
	["CampWalk", 0, [Vector2(95.0, 40.0), Vector2(250.0, 120.0), Vector2(430.0, 250.0)], false],
]
## Legs of a path that are bridges, not routed ([path, leg]: anchor `leg` to the next): straight between their anchors,
## level from one bank to the other (the deck at the banks' heights, LERP along it), built by _build_trail_bridge. The
## south bike loop crosses the pond beside the lap's own bridge over it (s ~2700) on a 112m trestle, 18m from the road's
## middle, and runs on along the bottom straight 25-30m off it, so the riders pass close by the race (the loops had kept
## 150m off it).
const TRAIL_BRIDGES := [["BikeSouth", 2]]
## Walkers along the footpaths: one group every so many metres.
const WALKER_EVERY := 70.0
const BENCH_EVERY := 260.0
const RIDERS := 14

var _trails: Array = []       # [name, kind, points (PackedVector3Array, on the ground), closed]
var _trail_hash := {}         # Vector2i(10m cell) -> PackedVector3Array of (x, z, half width + margin) along the paths


func _plan_trails() -> void:
	var t0 := Time.get_ticks_msec()
	var n := int(ceil(TRAIL_REACH * 2.0 / TRAIL_CELL)) + 1
	var org := -TRAIL_REACH
	# The road's distance and height over each cell, from samples along the lap.
	var rd := PackedFloat32Array()
	rd.resize(n * n)
	rd.fill(1e9)
	var ry := PackedFloat32Array()
	ry.resize(n * n)
	var s := 0.0
	var reach := int(ceil(60.0 / TRAIL_CELL))
	while s < _length:
		var p := _curve.sample_baked(s)
		var ci := int(round((p.x - org) / TRAIL_CELL))
		var cj := int(round((p.z - org) / TRAIL_CELL))
		for j in range(maxi(cj - reach, 0), mini(cj + reach, n - 1) + 1):
			for i in range(maxi(ci - reach, 0), mini(ci + reach, n - 1) + 1):
				var x := org + i * TRAIL_CELL
				var z := org + j * TRAIL_CELL
				var d := Vector2(x - p.x, z - p.z).length()
				var k := j * n + i
				if d < rd[k]:
					rd[k] = d
					ry[k] = p.y + _road_y
		s += 2.0
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, n, n)
	astar.cell_size = Vector2(TRAIL_CELL, TRAIL_CELL)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	astar.update()
	var keep := _woodland_keep_out()
	var solid := 0
	var why := {"out": 0, "water": 0, "road": 0, "kept": 0, "slope": 0}
	for j in range(n):
		for i in range(n):
			var x := org + i * TRAIL_CELL
			var z := org + j * TRAIL_CELL
			var cell := Vector2i(i, j)
			var g := _ground(x, z)
			var blocked := x * x + z * z > TRAIL_REACH * TRAIL_REACH
			if blocked:
				why["out"] += 1
			if not blocked:
				for o in [Vector2(0, 0), Vector2(4.5, 0), Vector2(-4.5, 0), Vector2(0, 4.5), Vector2(0, -4.5), Vector2(3.2, 3.2), Vector2(-3.2, 3.2),
						Vector2(3.2, -3.2), Vector2(-3.2, -3.2)]:
					if _ground(x + o.x, z + o.y) < TRAIL_WATER:
						blocked = true
						why["water"] += 1
						break
			var k := j * n + i
			var weight := 1.0
			if not blocked and rd[k] < ROAD_HALF + TRAIL_ROAD_CLEAR:
				# Under a bridge (the road well over the ground) a path may pass; anywhere else it may not cross.
				if ry[k] - g > 5.5:
					weight += 6.0
				else:
					blocked = true
					why["road"] += 1
			if not blocked and (_kept_out(keep, x, z, 2.0) or _on_shortcut(x, z, 3.0)):
				blocked = true
				why["kept"] += 1
			var sl := 0.0
			if not blocked:
				sl = maxf(absf(_ground(x + 3.0, z) - _ground(x - 3.0, z)), absf(_ground(x, z + 3.0) - _ground(x, z - 3.0))) / 6.0
				if sl > TRAIL_MAX_SLOPE:
					blocked = true
					why["slope"] += 1
			if blocked:
				astar.set_point_solid(cell, true)
				solid += 1
				continue
			weight += 14.0 * sl * sl
			if rd[k] < 45.0:
				weight += 2.5 * (45.0 - rd[k]) / 45.0
			astar.set_point_weight_scale(cell, weight)
	print("  paths: grid %d x %d, %d solid %s (%.1fs)" % [n, n, solid, why, (Time.get_ticks_msec() - t0) / 1000.0])
	# The open cells' connected regions (8-neighbour, as the paths move), so a path's anchors can all be put in one.
	var label := PackedInt32Array()
	label.resize(n * n)
	label.fill(-1)
	var sizes: Array[int] = []
	for j0 in range(n):
		for i0 in range(n):
			if label[j0 * n + i0] >= 0 or astar.is_point_solid(Vector2i(i0, j0)):
				continue
			var id := sizes.size()
			var count := 0
			var stack: Array[Vector2i] = [Vector2i(i0, j0)]
			label[j0 * n + i0] = id
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				count += 1
				for dj in range(-1, 2):
					for di in range(-1, 2):
						var q := c + Vector2i(di, dj)
						if q.x < 0 or q.y < 0 or q.x >= n or q.y >= n or label[q.y * n + q.x] >= 0 or astar.is_point_solid(q):
							continue
						# Diagonal steps only where both sides are open (AStarGrid2D's ONLY_IF_NO_OBSTACLES).
						if di != 0 and dj != 0 and (astar.is_point_solid(Vector2i(c.x + di, c.y)) or astar.is_point_solid(Vector2i(c.x, c.y + dj))):
							continue
						label[q.y * n + q.x] = id
						stack.append(q)
			sizes.append(count)
	_trail_label = label
	_trail_sizes = sizes
	_trails.clear()
	_trail_hash.clear()
	var used := {}
	for t in TRAILS:
		var anchors: Array = (t[2] as Array).duplicate()
		for a in range(anchors.size()):
			if anchors[a] == Vector2.INF:
				anchors[a] = Vector2(_playground_gate.x, _playground_gate.z)
		var closed: bool = t[3]
		# The region most of the anchors' nearest open cells lie in (the bigger one on a tie); every anchor goes to
		# its nearest cell there.
		var votes := {}
		for a in anchors:
			var lab: int = label[_trail_cell_id(_trail_open(astar, a, org, n, -1), n)]
			votes[lab] = int(votes.get(lab, 0)) + 1
		var region := -1
		for lab in votes:
			if region < 0 or int(votes[lab]) > int(votes[region]) or (int(votes[lab]) == int(votes[region]) and sizes[lab] > sizes[region]):
				region = lab
		var moved := PackedStringArray()
		for a in anchors:
			var c := _trail_open(astar, a, org, n, region)
			var w := Vector2(org + c.x * TRAIL_CELL, org + c.y * TRAIL_CELL)
			if w.distance_to(a) > 25.0:
				moved.append("%s->%s" % [a, w])
		if not moved.is_empty():
			print("  path %s (region of %d cells): anchors moved %s" % [t[0], sizes[region], ", ".join(moved)])
		var cells: Array[Vector2i] = []
		var legs := anchors.size() if closed else anchors.size() - 1
		var ok := true
		var bridges: Array = []
		var cur_region := region
		for a in range(legs):
			var b_anchor: Vector2 = anchors[(a + 1) % anchors.size()]
			if TRAIL_BRIDGES.has([t[0], a]):
				# A bridge: straight across, every cell on the line (no routing: it crosses the water). The legs after it
				# are routed in the region its far end lies in (the far bank can be land of its own).
				var wa: Vector2 = anchors[a]
				var steps := maxi(1, ceili(wa.distance_to(b_anchor) / (TRAIL_CELL * 0.5)))
				for k in range(steps + 1):
					var q2: Vector2 = wa.lerp(b_anchor, float(k) / float(steps))
					var cq := Vector2i(clampi(int(round((q2.x - org) / TRAIL_CELL)), 0, n - 1), clampi(int(round((q2.y - org) / TRAIL_CELL)), 0, n - 1))
					if cells.is_empty() or cells[cells.size() - 1] != cq:
						cells.append(cq)
				bridges.append([Vector3(wa.x, _ground(wa.x, wa.y), wa.y), Vector3(b_anchor.x, _ground(b_anchor.x, b_anchor.y), b_anchor.y)])
				var end_cell := _trail_open(astar, b_anchor, org, n, -1)
				cur_region = label[_trail_cell_id(end_cell, n)]
				continue
			var from := _trail_open(astar, anchors[a], org, n, cur_region)
			var to := _trail_open(astar, b_anchor, org, n, cur_region)
			var leg := astar.get_id_path(from, to)
			if leg.is_empty():
				push_error("Lakeside path %s: no way from %s to %s" % [t[0], anchors[a], anchors[(a + 1) % anchors.size()]])
				ok = false
				break
			for c in leg:
				if cells.is_empty() or cells[cells.size() - 1] != c:
					cells.append(c)
			# Later legs (and later paths) keep off the ground this one took: an out-and-back to an anchor ran
			# down the same corridor twice and the two ribbons overlapped.
			for c in leg:
				for dj in range(-3, 4):
					for di in range(-3, 4):
						var q := c + Vector2i(di, dj)
						if q.x < 0 or q.y < 0 or q.x >= n or q.y >= n or used.has(q) or astar.is_point_solid(q):
							continue
						used[q] = true
						astar.set_point_weight_scale(q, astar.get_point_weight_scale(q) + 12.0)
		if not ok:
			continue
		if closed and cells.size() > 1 and cells[0] == cells[cells.size() - 1]:
			cells.remove_at(cells.size() - 1)
		cells = _trail_cut_excursions(cells, closed)
		var pts := PackedVector2Array()
		for c in cells:
			pts.append(Vector2(org + c.x * TRAIL_CELL, org + c.y * TRAIL_CELL))
		pts = _trail_smooth(pts, closed)
		if not closed and (t[2] as Array)[0] == Vector2.INF:
			# From the playground's gate itself (inside the pad's keep-out, so the grid starts outside it).
			var gate := Vector2(_playground_gate.x, _playground_gate.z)
			var lead := PackedVector2Array()
			var steps := int(gate.distance_to(pts[0]))
			for k in range(steps):
				lead.append(gate.lerp(pts[0], float(k) / maxf(steps, 1)))
			lead.append_array(pts)
			pts = lead
		var width: float = BIKE_PATH_WIDTH if int(t[1]) == 1 else FOOTPATH_WIDTH
		var p3 := PackedVector3Array()
		var flags := PackedByteArray()
		var wet := 0
		var on_road := 0
		var under := 0
		for p in pts:
			var g := _ground(p.x, p.y)
			# On a bridge: its deck, level from bank to bank, above the ground under it.
			var on_bridge := false
			for br in bridges:
				var w3: Vector3 = br[0]
				var e3: Vector3 = br[1]
				var ab := Vector2(e3.x - w3.x, e3.z - w3.z)
				var tt: float = clampf(Vector2(p.x - w3.x, p.y - w3.z).dot(ab) / maxf(ab.length_squared(), 1e-4), 0.0, 1.0)
				var on := Vector2(w3.x, w3.z) + ab * tt
				if on.distance_to(p) < 3.0 and tt > 0.0 and tt < 1.0:
					g = maxf(lerpf(w3.y, e3.y, tt), g)
					on_bridge = true
			flags.append(1 if on_bridge else 0)
			# Under the water (its plane at -10, Water_Surface) or within 30cm of it.
			if g < -9.7 and not on_bridge:
				wet += 1
			var cp := _curve.get_closest_point(Vector3(p.x, g, p.y))
			if Vector2(cp.x - p.x, cp.z - p.y).length() < ROAD_HALF + 3.0:
				if cp.y + _road_y - g > 5.0:
					under += 1
				else:
					on_road += 1
			p3.append(Vector3(p.x, g, p.y))
		var bad := wet + on_road
		var length := 0.0
		for i in range(1, p3.size()):
			length += p3[i].distance_to(p3[i - 1])
		_trails.append([t[0], int(t[1]), p3, closed, width, flags, bridges])
		for p in p3:
			var key := Vector2i(floori(p.x / 10.0), floori(p.z / 10.0))
			if not _trail_hash.has(key):
				_trail_hash[key] = PackedVector3Array()
			(_trail_hash[key] as PackedVector3Array).append(Vector3(p.x, p.z, width * 0.5))
		print("  path %s: %.0fm, %d points under a bridge%s" % [t[0], length, under, (", %d in the water, %d on the road" % [wet, on_road]) if bad > 0 else ""])
		if bad > 0:
			push_error("Lakeside path %s: %d points in the water or on the road" % [t[0], bad])


## Cuts out-and-back excursions from a path's cells: where the sequence comes back to within a cell of where it was,
## the stretch between goes (an anchor in a cul-de-sac between lakes was reached and left by the same strip, and the
## two ribbons overlapped). A closed loop is turned half round first, so its join is looked at too.
static func _trail_cut_excursions(cells: Array[Vector2i], closed: bool) -> Array[Vector2i]:
	var cur: Array[Vector2i] = cells.duplicate()
	if closed and cur.size() > 8:
		var half := cur.size() / 2
		var rot: Array[Vector2i] = []
		rot.append_array(cur.slice(half))
		rot.append_array(cur.slice(0, half))
		cur = rot
	var i := 0
	while i < cur.size():
		var cut := -1
		var j := cur.size() - 1
		while j > i + 4:
			# On a loop the cells either side of its join are neighbours too: only a return far both ways round counts.
			if closed and cur.size() - (j - i) <= 4:
				j -= 1
				continue
			var d: Vector2i = cur[j] - cur[i]
			if absi(d.x) <= 1 and absi(d.y) <= 1:
				cut = j
				break
			j -= 1
		if cut > 0:
			var keep: Array[Vector2i] = []
			keep.append_array(cur.slice(0, i + 1))
			keep.append_array(cur.slice(cut))
			cur = keep
		i += 1
	return cur


var _trail_label := PackedInt32Array()
var _trail_sizes: Array[int] = []


func _trail_cell_id(c: Vector2i, n: int) -> int:
	return c.y * n + c.x


## The grid cell of (x, z), or the nearest open one to it (in region `region`, if not -1).
func _trail_open(astar: AStarGrid2D, at: Vector2, org: float, n: int, region: int) -> Vector2i:
	var c := Vector2i(clampi(int(round((at.x - org) / TRAIL_CELL)), 0, n - 1), clampi(int(round((at.y - org) / TRAIL_CELL)), 0, n - 1))
	for r in range(0, 80):
		for dj in range(-r, r + 1):
			for di in range(-r, r + 1):
				if maxi(absi(di), absi(dj)) != r:
					continue
				var q := c + Vector2i(di, dj)
				if q.x >= 0 and q.y >= 0 and q.x < n and q.y < n and not astar.is_point_solid(q) \
						and (region < 0 or _trail_label[q.y * n + q.x] == region):
					return q
	return c


## Chaikin's corner cutting (four rounds), then resampled every metre and eased by a running mean.
func _trail_smooth(pts: PackedVector2Array, closed: bool) -> PackedVector2Array:
	var cur := pts
	for round_i in range(4):
		var nxt := PackedVector2Array()
		var m := cur.size()
		if not closed:
			nxt.append(cur[0])
		for i in range(m if closed else m - 1):
			var a := cur[i]
			var b := cur[(i + 1) % m]
			nxt.append(a.lerp(b, 0.25))
			nxt.append(a.lerp(b, 0.75))
		if not closed:
			nxt.append(cur[m - 1])
		cur = nxt
	# Resample every metre.
	var out := PackedVector2Array()
	var m2 := cur.size()
	var acc := 0.0
	out.append(cur[0])
	for i in range(1, m2 + (1 if closed else 0)):
		var a := cur[i - 1]
		var b := cur[i % m2]
		var seg := a.distance_to(b)
		var t := 1.0 - acc
		while t <= seg:
			out.append(a.lerp(b, t / maxf(seg, 1e-5)))
			t += 1.0
		acc = seg - (t - 1.0)
	if closed and out.size() > 2 and out[out.size() - 1].distance_to(out[0]) < 0.5:
		out.remove_at(out.size() - 1)
	# A running mean over 9m takes the grid's last kinks out.
	var eased := PackedVector2Array()
	eased.resize(out.size())
	var w := 4
	for i in range(out.size()):
		var sum := Vector2.ZERO
		var cnt := 0
		for d in range(-w, w + 1):
			var j := i + d
			if closed:
				j = posmod(j, out.size())
			elif j < 0 or j >= out.size():
				continue
			sum += out[j]
			cnt += 1
		eased[i] = sum / cnt
	return eased


## Places where two stretches of path (of one path more than 30m apart along it, or of two paths away from where one
## joins the other) come closer than their half widths: overlapping ribbons fight and leave holes. Prints and returns them.
func _trail_overlaps() -> int:
	var grid := {}
	for ti in range(_trails.size()):
		var pts: PackedVector3Array = _trails[ti][2]
		for i in range(pts.size()):
			var key := Vector2i(floori(pts[i].x / 6.0), floori(pts[i].z / 6.0))
			if not grid.has(key):
				grid[key] = []
			grid[key].append(Vector2i(ti, i))
	var hits := 0
	var where := PackedStringArray()
	for ti in range(_trails.size()):
		var pts: PackedVector3Array = _trails[ti][2]
		var closed: bool = _trails[ti][3]
		var w: float = _trails[ti][4]
		for i in range(0, pts.size(), 3):
			var p := pts[i]
			var key := Vector2i(floori(p.x / 6.0), floori(p.z / 6.0))
			var found := false
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					for o in grid.get(key + Vector2i(dx, dz), []):
						var other: Vector2i = o
						var q: Vector3 = (_trails[other.x][2] as PackedVector3Array)[other.y]
						var reach: float = (w + float(_trails[other.x][4])) * 0.5 + 0.3
						if Vector2(q.x - p.x, q.z - p.z).length() > reach:
							continue
						if other.x == ti:
							var gap := absi(other.y - i)
							if closed:
								gap = mini(gap, pts.size() - gap)
							if gap < 30:
								continue
						elif i < 40 or i > pts.size() - 40 or other.y < 40 or other.y > (_trails[other.x][2] as PackedVector3Array).size() - 40:
							# Where a spur leaves or joins another path.
							continue
						found = true
			if found:
				hits += 1
				if where.size() < 6:
					where.append("%s@(%.0f, %.0f)" % [_trails[ti][0], p.x, p.z])
	print("  paths overlapping: %d%s" % [hits, (" at " + ", ".join(where)) if hits > 0 else ""])
	return hits


## Whether (x, z) is within `margin` of a path's edge.
func _on_trail(x: float, z: float, margin: float) -> bool:
	var cx := floori(x / 10.0)
	var cz := floori(z / 10.0)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key := Vector2i(cx + dx, cz + dz)
			if not _trail_hash.has(key):
				continue
			for q in (_trail_hash[key] as PackedVector3Array):
				var d := Vector2(q.x - x, q.y - z).length()
				if d < q.z + margin:
					return true
	return false


func _trail_material() -> ShaderMaterial:
	if _materials.has("trail"):
		return _materials["trail"]
	var m := ShaderMaterial.new()
	m.shader = load("res://trail_path.gdshader")
	m.set_shader_parameter("dirt_tex", load("res://materials/dirt.png"))
	m.set_shader_parameter("dirt_normal", load("res://materials/dirt_normal.png"))
	m = _save_res(m, "mat_trail")
	_materials["trail"] = m
	return m


func _build_trails(root: Node3D) -> void:
	if _park == null:
		_park = ParkKit.new(_kit, _venue)
	_trail_overlaps()
	var node := Node3D.new()
	node.name = "Paths"
	root.add_child(node)
	var mat := _trail_material()
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var bench_kit := {}
	var boxes: Array = []
	var walkers := 0
	var benches := 0
	for t in _trails:
		var tname: String = t[0]
		var kind: int = t[1]
		var pts: PackedVector3Array = t[2]
		var closed: bool = t[3]
		var width: float = t[4]
		var flags: PackedByteArray = t[5]
		var m := pts.size()
		# The ribbon, in pieces of `chunk` points (a closed path comes back round to its first point); none where a bridge's
		# deck carries the path.
		var order := PackedInt32Array()
		for i in range(m):
			order.append(i)
		if closed:
			order.append(0)
		var chunk := 120
		var piece := 0
		var start := 0
		while start < order.size() - 1:
			var end := mini(start + chunk, order.size() - 1)
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var across := 5
			for oi in range(start, end + 1):
				var i: int = order[oi]
				var p := pts[i]
				var pa := pts[(i - 1 + m) % m] if (closed or i > 0) else p
				var pb := pts[(i + 1) % m] if (closed or i < m - 1) else p
				var d := Vector3(pb.x - pa.x, 0.0, pb.z - pa.z)
				if d.length_squared() < 1e-6:
					d = Vector3(0, 0, 1)
				d = d.normalized()
				var right := Vector3(-d.z, 0.0, d.x)
				for a in range(across):
					var u := float(a) / float(across - 1)
					var w := p + right * (u - 0.5) * width
					w.y = _ground(w.x, w.z) + 0.035
					st.set_color(Color(float(kind), 0.0, 0.0))
					st.set_uv(Vector2(u, float(oi)))
					st.set_normal(Vector3.UP)
					st.add_vertex(w)
			var rows := end - start + 1
			for r in range(rows - 1):
				if flags[order[start + r]] == 1 and flags[order[start + r + 1]] == 1:
					continue
				for a in range(across - 1):
					var i0 := r * across + a
					var i1 := i0 + 1
					var i2 := i0 + across
					var i3 := i2 + 1
					# Clockwise seen from above (Godot's front faces: (c - a) x (b - a) points up). The columns run
					# from the path's left (+right * -w/2) to its right, the rows along it.
					st.add_index(i0); st.add_index(i2); st.add_index(i1)
					st.add_index(i1); st.add_index(i2); st.add_index(i3)
			st.generate_normals()
			st.generate_tangents()
			var mi := MeshInstance3D.new()
			mi.name = "Trail_%s_%d" % [tname, piece]
			mi.mesh = _save_res(st.commit(), "trail_%s_%d" % [tname.to_snake_case(), piece])
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = 400.0
			mi.visibility_range_end_margin = 20.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			node.add_child(mi)
			start = end
			piece += 1
		# The bridges: each run of the path's bridge points.
		var span_pts := PackedVector3Array()
		for oi in range(order.size()):
			var i: int = order[oi]
			if flags[i] == 1:
				span_pts.append(pts[i])
			elif span_pts.size() > 1:
				_build_trail_bridge(node, span_pts, width, "%s%d" % [tname, oi])
				span_pts = PackedVector3Array()
			else:
				span_pts = PackedVector3Array()
		if span_pts.size() > 1:
			_build_trail_bridge(node, span_pts, width, "%sEnd" % tname)
		if kind == 1:
			continue
		# Footpaths: walkers in ones and twos, benches with people at the viewpoints.
		var next_walk := rng.randf_range(20.0, WALKER_EVERY)
		var next_bench := rng.randf_range(80.0, BENCH_EVERY)
		var run := 0.0
		for i in range(1, m - 1):
			run += pts[i].distance_to(pts[i - 1])
			var d := pts[i + 1] - pts[i - 1]
			d.y = 0.0
			d = d.normalized()
			var right := Vector3(-d.z, 0.0, d.x)
			if run >= next_walk:
				next_walk = run + rng.randf_range(WALKER_EVERY * 0.6, WALKER_EVERY * 1.4)
				var way := d if rng.randf() < 0.5 else -d
				var count := 1 if rng.randf() < 0.45 else 2
				for k in range(count):
					var p := pts[i] + right * ((k - 0.5 * (count - 1)) * 0.75 + rng.randf_range(-0.2, 0.2)) * PROP_SCALE * 0.6
					p.y = _ground(p.x, p.z)
					var size := 1.0 if rng.randf() > 0.15 else PLAYGROUND_CHILD
					_park_spots.append([p, way, false, false, [7, 7, 7, 10, 13, 15, 11][rng.randi() % 7], size])
					walkers += 1
			if run >= next_bench:
				next_bench = run + rng.randf_range(BENCH_EVERY * 0.7, BENCH_EVERY * 1.3)
				var side := 1.0 if rng.randf() < 0.5 else -1.0
				var at := pts[i] + right * side * (width * 0.5 + 1.6)
				if _ground_min(at.x, at.z, 1.5) < TRAIL_WATER + 0.8 or _road_distance(at.x, at.z) < ROAD_HALF + 8.0:
					continue
				at.y = _ground_min(at.x, at.z, 1.4)
				# Its back to the path, looking out.
				var face := right * side
				var yaw := _yaw_to(face)
				var bx := _place(at, yaw)
				_kit.set_frame(bx)
				_park.park_bench(bench_kit)
				boxes.append([bx * Vector3(0.0, 0.45, 0.0), Vector3(1.9, 0.9, 0.6) * PROP_SCALE, Basis(Vector3.UP, yaw)])
				_note("bench", at, 1.6, 2.0)
				benches += 1
				if rng.randf() < 0.75:
					var who := 1 if rng.randf() < 0.5 else 2
					for k in range(who):
						_park_spots.append([bx * Vector3(-0.35 + 0.7 * k, 0.45, -0.05), face, true, false, [0, 3, 6, 4][rng.randi() % 4], 1.0])
						walkers += 1
	# A fingerpost where the camp's path leaves.
	for t in _trails:
		if t[0] == "CampWalk":
			var p0: Vector3 = (t[2] as PackedVector3Array)[3]
			var post := _place(Vector3(p0.x + 2.2, _ground(p0.x + 2.2, p0.z), p0.z), 0.4)
			_kit.set_frame(post)
			_park.fingerpost(bench_kit, [0.3, 2.2])
			boxes.append([post * Vector3(0.0, 1.0, 0.0), Vector3(0.2, 2.2, 0.2) * PROP_SCALE, Basis()])
	_kit.reset_frame()
	if not bench_kit.is_empty():
		var bm := MeshInstance3D.new()
		bm.name = "PathBenches"
		bm.mesh = _save_res(_venue.finish(bench_kit), "path_benches")
		bm.visibility_range_end = 300.0
		node.add_child(bm)
		_boxes_body(node, "PathBenchesBody", boxes)
	print("  paths: %d walkers and sitters, %d benches" % [walkers, benches])
	_build_cyclists(node)


## The riders' sounds (the user's recordings, levelled by their measured RMS in dBFS to a level at BIKE_SOUND_UNIT
## metres): the tyres rolling on the path, one clip each in turn, and the pedalling under it.
const BIKE_ROLL_CLIPS := ["res://sounds/bicycle1.wav", "res://sounds/bicycle2.wav"]
const BIKE_ROLL_RMS := [-43.9, -47.2]
const BIKE_ROLL_LEVEL := -30.0
const BIKE_PEDAL_CLIP := "res://sounds/bicycle_pedalling.wav"
const BIKE_PEDAL_RMS := -45.2
const BIKE_PEDAL_LEVEL := -33.0
const BIKE_SOUND_UNIT := 7.0

## A wooden trestle bridge carrying a path along `pts` (its deck's middle, the riders' line): planks across three
## stringers, a trestle bent every BRIDGE_BENT metres down to the ground under it (the pond's bed), braced across, and a
## railing either side; ends a little onto the banks. Life-size timbers in world metres (hut_wood.gdshader, "timber").
## Solid: the deck and the railings as boxes ("PondBoardwalk": no track word, off-road wood).
const BRIDGE_BENT := 6.0
const BRIDGE_RAIL_H := 1.35

func _build_trail_bridge(parent: Node3D, pts: PackedVector3Array, width: float, tag: String) -> void:
	var kit := {}
	_kit.reset_frame()
	var boxes: Array = []
	var deck_w: float = width + 0.6
	var hw: float = deck_w * 0.5
	var wood := Color(0.56, 0.45, 0.33)
	var dark := Color(0.40, 0.31, 0.22)
	# Extend the deck 1.5m onto each bank along the line.
	var d0 := (pts[1] - pts[0])
	d0.y = 0.0
	d0 = d0.normalized()
	var d1 := (pts[pts.size() - 1] - pts[pts.size() - 2])
	d1.y = 0.0
	d1 = d1.normalized()
	var line := PackedVector3Array([pts[0] - d0 * 1.5])
	line.append_array(pts)
	line.append(pts[pts.size() - 1] + d1 * 1.5)
	# Cumulative length, for planks, bents and posts at even spacings.
	var cum := PackedFloat32Array([0.0])
	for i in range(1, line.size()):
		cum.append(cum[i - 1] + line[i].distance_to(line[i - 1]))
	var total: float = cum[cum.size() - 1]
	var at := func(dist: float) -> Array:
		var k := 1
		while k < line.size() - 1 and cum[k] < dist:
			k += 1
		var seg: float = maxf(cum[k] - cum[k - 1], 1e-4)
		var u: float = clampf((dist - cum[k - 1]) / seg, 0.0, 1.0)
		var p: Vector3 = line[k - 1].lerp(line[k], u)
		var f: Vector3 = line[k] - line[k - 1]
		f.y = 0.0
		f = f.normalized()
		return [p, f, Vector3(-f.z, 0.0, f.x)]
	# Planks across.
	var x := 0.15
	while x < total - 0.1:
		var a: Array = at.call(x)
		var p: Vector3 = a[0]
		var r: Vector3 = a[2]
		_venue.timber(kit, p - r * hw + Vector3.DOWN * 0.035, p + r * hw + Vector3.DOWN * 0.035, 0.28, 0.07, wood.darkened(randf() * 0.12), Vector3.UP)
		x += 0.32
	# Stringers under them, a piece every 3m.
	x = 0.0
	while x < total - 0.01:
		var x1: float = minf(x + 3.0, total)
		var a0: Array = at.call(x)
		var a1: Array = at.call(x1)
		for lat in [-hw + 0.45, 0.0, hw - 0.45]:
			var pa: Vector3 = (a0[0] as Vector3) + (a0[2] as Vector3) * lat + Vector3.DOWN * 0.24
			var pb: Vector3 = (a1[0] as Vector3) + (a1[2] as Vector3) * lat + Vector3.DOWN * 0.24
			_venue.timber(kit, pa, pb, 0.22, 0.32, dark, Vector3.UP)
		boxes.append(_wall_box((a0[0] as Vector3) + Vector3.DOWN * 0.3, (a1[0] as Vector3) + Vector3.DOWN * 0.3, deck_w, 0.3))
		x = x1
	# Trestle bents: two posts down to the ground, a cap, crossed braces in tiers.
	x = BRIDGE_BENT * 0.5
	while x < total:
		var a: Array = at.call(x)
		var p: Vector3 = a[0]
		var r: Vector3 = a[2]
		var lowest := INF
		for lat in [-hw + 0.3, hw - 0.3]:
			var q: Vector3 = p + r * lat
			lowest = minf(lowest, _ground(q.x, q.z))
		if p.y - lowest > 0.9:
			var top: float = p.y - 0.42
			var foot: float = lowest - 0.6
			var posts: Array = []
			for lat in [-hw + 0.3, hw - 0.3]:
				var q2: Vector3 = p + r * lat
				posts.append(Vector3(q2.x, 0.0, q2.z))
				_venue.timber(kit, Vector3(q2.x, foot, q2.z), Vector3(q2.x, top, q2.z), 0.3, 0.3, dark, r)
			_venue.timber(kit, p - r * (hw + 0.2) + Vector3.UP * (top - p.y), p + r * (hw + 0.2) + Vector3.UP * (top - p.y), 0.3, 0.26, dark, Vector3.UP)
			var y0: float = top
			while y0 - foot > 1.5:
				var y1: float = maxf(y0 - 4.0, foot + 0.3)
				var pl: Vector3 = posts[0]
				var pr: Vector3 = posts[1]
				_venue.timber(kit, Vector3(pl.x, y0 - 0.2, pl.z), Vector3(pr.x, y1, pr.z), 0.16, 0.08, wood, Vector3.UP.cross(r))
				_venue.timber(kit, Vector3(pr.x, y0 - 0.2, pr.z), Vector3(pl.x, y1, pl.z), 0.16, 0.08, wood, Vector3.UP.cross(r))
				_venue.timber(kit, Vector3(pl.x, y1, pl.z), Vector3(pr.x, y1, pr.z), 0.18, 0.1, wood, Vector3.UP)
				y0 = y1
		x += BRIDGE_BENT
	# The railings: posts every 2.4m, a top rail and a middle one, each side.
	for sgn in [-1.0, 1.0]:
		var prev: Vector3 = Vector3.INF
		x = 0.3
		while x <= total - 0.2:
			var a: Array = at.call(x)
			var q: Vector3 = (a[0] as Vector3) + (a[2] as Vector3) * (sgn * (hw - 0.08))
			_venue.timber(kit, q + Vector3.DOWN * 0.3, q + Vector3.UP * BRIDGE_RAIL_H, 0.12, 0.12, dark, a[2])
			if prev != Vector3.INF:
				for h in [BRIDGE_RAIL_H, BRIDGE_RAIL_H * 0.5]:
					_venue.timber(kit, prev + Vector3.UP * h, q + Vector3.UP * h, 0.13, 0.07, wood, Vector3.UP)
				boxes.append(_wall_box(prev, q, 0.15, BRIDGE_RAIL_H))
			prev = q
			x += 2.4
	var mi := MeshInstance3D.new()
	mi.name = "BikeBoardwalk_%s" % tag
	mi.mesh = _save_res(_venue.finish(kit), "bike_boardwalk_%s" % tag.to_snake_case())
	mi.visibility_range_end = 700.0
	parent.add_child(mi)
	var body := _boxes_body(parent, "PondBoardwalk_%s" % tag, boxes)
	body.set_meta("surface", "wood")
	var mid: Vector3 = line[line.size() / 2]
	print("  bike bridge %s: %.0fm, deck %.1fm over the ground at most, %.0fm from the road's middle" % [tag, total,
			_max_drop(line), _road_distance(mid.x, mid.z)])


func _max_drop(line: PackedVector3Array) -> float:
	var m := 0.0
	for p in line:
		m = maxf(m, p.y - _ground(p.x, p.z))
	return m


## Riders on the bike paths (Cyclists.gd): in ones, twos and threes, both ways round each loop (shared by their length),
## each in its own colours.
func _build_cyclists(parent: Node3D) -> void:
	var loops: Array = []
	for t in _trails:
		if int(t[1]) == 1 and t[3]:
			loops.append(t)
	if loops.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 3131
	var lengths: Array[float] = []
	var total := 0.0
	for t in loops:
		var route: PackedVector3Array = t[2]
		var length := 0.0
		for i in range(route.size()):
			length += route[i].distance_to(route[(i + 1) % route.size()])
		lengths.append(length)
		total += length
	var node := Node3D.new()
	node.name = "Cyclists"
	node.set_script(load("res://Cyclists.gd"))
	var routes: Array[PackedVector3Array] = []
	for t in loops:
		var on := PackedVector3Array()
		for p in (t[2] as PackedVector3Array):
			on.append(p + Vector3(0, 0.035, 0))
		routes.append(on)
	var riders: Array[Vector4] = []
	var bodies: Array[Mesh] = []
	var thighs: Array[Mesh] = []
	var shins: Array[Mesh] = []
	var jerseys := [Color(0.90, 0.15, 0.12), Color(0.12, 0.40, 0.85), Color(0.98, 0.80, 0.10), Color(0.10, 0.60, 0.35), Color(0.95, 0.95, 0.95),
			Color(0.95, 0.45, 0.10), Color(0.55, 0.20, 0.70), Color(0.10, 0.75, 0.80), Color(0.95, 0.40, 0.65), Color(0.20, 0.22, 0.25)]
	var frames := [Color(0.85, 0.10, 0.10), Color(0.08, 0.08, 0.09), Color(0.90, 0.90, 0.92), Color(0.10, 0.30, 0.75), Color(0.20, 0.55, 0.30),
			Color(0.95, 0.55, 0.05)]
	var skins := [Color(0.93, 0.78, 0.66), Color(0.86, 0.66, 0.52), Color(0.72, 0.52, 0.38), Color(0.45, 0.30, 0.20), Color(0.96, 0.84, 0.74)]
	var hairs := [Color(0.20, 0.13, 0.08), Color(0.55, 0.38, 0.18), Color(0.85, 0.70, 0.40), Color(0.08, 0.07, 0.06)]
	var wheel_kit := {}
	_kit.reset_frame()
	_park.bike_wheel(wheel_kit, Color(0.75, 0.76, 0.78))
	var wheel := _save_res(_kit.commit(wheel_kit), "bike_wheel")
	var crank_kit := {}
	_park.bike_crank(crank_kit)
	var crank := _save_res(_kit.commit(crank_kit), "bike_crank")
	var group_at := 0.0
	var i := 0
	var route_i := 0
	var placed_on := 0.0
	while i < RIDERS:
		var size := 1 + (1 if rng.randf() < 0.45 else 0) + (1 if rng.randf() < 0.2 else 0)
		var speed := rng.randf_range(5.0, 7.5) * (1.0 if rng.randf() < 0.55 else -1.0)
		# Each loop gets riders in proportion to its length.
		if placed_on >= float(RIDERS) * lengths[route_i] / total and route_i < loops.size() - 1:
			route_i += 1
			placed_on = 0.0
			group_at = 0.0
		var length: float = lengths[route_i]
		group_at += length / 4.0 * rng.randf_range(0.6, 1.3)
		for k in range(size):
			if i >= RIDERS:
				break
			var jersey: Color = jerseys[i % jerseys.size()]
			var shorts := Color(0.08, 0.08, 0.10) if rng.randf() < 0.7 else Color(0.15, 0.20, 0.35)
			var skin: Color = skins[rng.randi() % skins.size()]
			var female := rng.randf() < 0.45
			var bk := {}
			_park.cyclist_body(bk, frames[rng.randi() % frames.size()], jersey, shorts, skin, [Color(0.95, 0.95, 0.95), jersey, Color(0.1, 0.1, 0.1)][rng.randi() % 3],
					hairs[rng.randi() % hairs.size()], female)
			bodies.append(_save_res(_kit.commit(bk), "cyclist_%d" % i))
			var tk := {}
			_park.bike_thigh(tk, shorts, skin)
			thighs.append(_save_res(_kit.commit(tk), "cyclist_thigh_%d" % i))
			var sk := {}
			var shoe: Color = [Color(0.95, 0.95, 0.95), Color(0.1, 0.1, 0.1), jersey][rng.randi() % 3]
			_park.bike_shin(sk, skin, Color(0.95, 0.95, 0.95), shoe)
			shins.append(_save_res(_kit.commit(sk), "cyclist_shin_%d" % i))
			# Single file, a bike length and a half apart.
			riders.append(Vector4(float(route_i), fposmod(group_at - k * 4.2 * signf(speed), length), speed, 1.05 * PROP_SCALE * 0.7))
			placed_on += 1.0
			i += 1
	node.set("routes", routes)
	node.set("riders", riders)
	node.set("body_meshes", bodies)
	node.set("thigh_meshes", thighs)
	node.set("shin_meshes", shins)
	node.set("wheel_mesh", wheel)
	node.set("crank_mesh", crank)
	node.set("prop_scale", PROP_SCALE)
	var rolls: Array[AudioStream] = []
	var roll_db: Array[float] = []
	for k in range(BIKE_ROLL_CLIPS.size()):
		rolls.append(load(BIKE_ROLL_CLIPS[k]))
		roll_db.append(BIKE_ROLL_LEVEL - float(BIKE_ROLL_RMS[k]))
	node.set("roll_sounds", rolls)
	node.set("roll_db", roll_db)
	node.set("pedal_sound", load(BIKE_PEDAL_CLIP))
	node.set("pedal_db", BIKE_PEDAL_LEVEL - BIKE_PEDAL_RMS)
	node.set("sound_unit", BIKE_SOUND_UNIT)
	parent.add_child(node)
	print("  cyclists: %d on %d bike loops (%.0fm)" % [riders.size(), loops.size(), total])


# ======================================================================================
#  The airship
# ======================================================================================
# ParkKit.airship at AIRSHIP_SCALE, flying an ellipse round the course (Airship.gd, on the wall clock) with RC VIBE GP on
# both sides of its envelope (Label3Ds, alpha cut) and its propellers spinning.
const AIRSHIP_SCALE := 1.1
const AIRSHIP_CENTRE := Vector3(-160.0, 0.0, -120.0)
const AIRSHIP_RADII := Vector2(560.0, 470.0)
const AIRSHIP_ALTITUDE := 165.0
const AIRSHIP_ENGINE_CLIP := "res://sounds/airship_engine.wav"
const AIRSHIP_ENGINE_RMS := -15.8
const AIRSHIP_ENGINE_LEVEL := -17.0
const AIRSHIP_ENGINE_UNIT := 120.0
const AIRSHIP_ENGINE_REACH := 800.0

## Where the logo lies on the envelope (ParkKit's frame, h toward the nose): between the orange bands (h -14 to -11.5
## and 17 to 19), centred a little above the side's middle (the gondola hangs below), its height from the picture's.
const AIRSHIP_LOGO_H := Vector2(-10.5, 15.5)
const AIRSHIP_LOGO_UP := 0.12
const AIRSHIP_LOGO_PROUD := 0.18

## The logo's picture (images/logo_transparent.png) halved, its transparent edge pixels given their neighbours' colour
## (or the mipmaps fringe it dark), mipmapped, saved lossless.
func _airship_logo_texture() -> Texture2D:
	var img: Image = (load("res://images/logo_transparent.png") as Texture2D).get_image()
	img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(1024, int(round(1024.0 * float(img.get_height()) / float(img.get_width()))), Image.INTERPOLATE_LANCZOS)
	img.fix_alpha_edges()
	img.generate_mipmaps()
	var tex := PortableCompressedTexture2D.new()
	# Kept, or a headless save writes the texture empty (CLAUDE.md, procedural cars).
	tex.keep_compressed_buffer = true
	tex.create_from_image(img, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
	return _save_res(tex, "airship_logo_tex")


## The logo's patch on one side (`side` +1 the +x side) of the envelope at scale 1: a grid following the envelope's
## radius AIRSHIP_LOGO_PROUD out, across AIRSHIP_LOGO_H along it and as far round as the picture's proportions ask,
## reading left to right seen from that side (toward the nose on +x, the tail on -x), front faces outward.
func _airship_logo_mesh(side: float) -> ArrayMesh:
	var aspect := 2247.0 / 860.0
	var h0: float = AIRSHIP_LOGO_H.x
	var h1: float = AIRSHIP_LOGO_H.y
	var r_mid := ParkKit.ship_radius((h0 + h1) * 0.5)
	var span: float = (h1 - h0) / aspect / r_mid
	var nu := 32
	var nv := 14
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(nv + 1):
		var v := float(j) / nv
		var phi: float = AIRSHIP_LOGO_UP + (v - 0.5) * span
		for i in range(nu + 1):
			var u := float(i) / nu
			# Left to right as seen from this side: toward the nose (h up) on +x, toward the tail on -x.
			var h: float = lerpf(h0, h1, u) if side > 0.0 else lerpf(h1, h0, u)
			var r := ParkKit.ship_radius(h) + AIRSHIP_LOGO_PROUD
			var out := Vector3(side * cos(phi), sin(phi), 0.0)
			st.set_normal(out)
			st.set_uv(Vector2(u, 1.0 - v))
			# The nose is toward -z: h along -z.
			st.add_vertex(out * r + Vector3(0.0, 0.0, -h))
	for j in range(nv):
		for i in range(nu):
			var a := j * (nu + 1) + i
			var b := a + 1
			var c := a + (nu + 1)
			var d := c + 1
			for t in [[a, b, c], [b, d, c]]:
				st.add_index(t[0])
				st.add_index(t[1])
				st.add_index(t[2])
	var arrays := st.commit_to_arrays()
	# Godot's front faces wind clockwise ((c - a) x (b - a) along the outside): wind every triangle to face out.
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for k in range(0, idx.size(), 3):
		var pa := verts[idx[k]]
		var pb := verts[idx[k + 1]]
		var pc := verts[idx[k + 2]]
		if (pc - pa).cross(pb - pa).dot(norms[idx[k]]) < 0.0:
			var tmp := idx[k + 1]
			idx[k + 1] = idx[k + 2]
			idx[k + 2] = tmp
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_airship(root: Node3D) -> void:
	if _park == null:
		_park = ParkKit.new(_kit, _venue)
	var node := Node3D.new()
	node.name = "Airship"
	node.set_script(load("res://Airship.gd"))
	node.set("centre", AIRSHIP_CENTRE)
	node.set("radii", AIRSHIP_RADII)
	node.set("altitude", AIRSHIP_ALTITUDE)
	node.set("speed", 13.0)
	node.set("phase", 1.3)
	root.add_child(node)
	var white := Color(0.94, 0.95, 0.96)
	var navy := Color(0.06, 0.12, 0.30)
	var orange := Color(0.98, 0.50, 0.10)
	var kit := {}
	_kit.reset_frame()
	_park.airship(kit, white, orange, navy)
	var body := MeshInstance3D.new()
	body.name = "Envelope"
	body.mesh = _save_res(_kit.commit(kit), "airship")
	body.scale = Vector3.ONE * AIRSHIP_SCALE
	node.add_child(body)
	var pk := {}
	_park.ship_prop(pk, navy)
	var prop_mesh := _save_res(_kit.commit(pk), "airship_prop")
	var k := 0
	for c in ParkKit.ship_prop_centres():
		var pr := MeshInstance3D.new()
		pr.name = "Prop%d" % k
		pr.mesh = prop_mesh
		pr.position = (c as Vector3) * AIRSHIP_SCALE
		pr.scale = Vector3.ONE * AIRSHIP_SCALE
		node.add_child(pr)
		k += 1
	# The RC Vibe GP logo on both sides, between the orange bands, laid on the envelope's curve.
	var logo_mat := StandardMaterial3D.new()
	logo_mat.albedo_texture = _airship_logo_texture()
	logo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	logo_mat.roughness = 0.35
	logo_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	logo_mat = _save_res(logo_mat, "airship_logo_mat")
	for side in [-1.0, 1.0]:
		var lm := MeshInstance3D.new()
		lm.name = "Logo%s" % ("L" if side < 0.0 else "R")
		lm.mesh = _save_res(_airship_logo_mesh(side), "airship_logo_%s" % ("l" if side < 0.0 else "r"))
		lm.material_override = logo_mat
		lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lm.scale = Vector3.ONE * AIRSHIP_SCALE
		node.add_child(lm)
	# The engines: the user's recording, levelled so it is AIRSHIP_ENGINE_LEVEL at AIRSHIP_ENGINE_UNIT metres: about
	# -20 dBFS as it passes 165m overhead, a drone heard across the course, gone past AIRSHIP_ENGINE_REACH. No distance
	# low-pass (Godot's default muffles it -24 dB at the top): at -38 dBFS and filtered the user heard nothing under it.
	var eng := AudioStreamPlayer3D.new()
	eng.name = "EngineSound"
	eng.stream = load(AIRSHIP_ENGINE_CLIP)
	eng.volume_db = AIRSHIP_ENGINE_LEVEL - AIRSHIP_ENGINE_RMS
	eng.unit_size = AIRSHIP_ENGINE_UNIT
	eng.max_distance = AIRSHIP_ENGINE_REACH
	eng.bus = &"SFX"
	eng.attenuation_filter_db = 0.0
	eng.autoplay = true
	eng.position = (ParkKit.ship_prop_centres()[0] as Vector3) * Vector3(0.0, 1.0, 1.0) * AIRSHIP_SCALE
	node.add_child(eng)
	print("  airship: %.0fm long, %.0fm up, round %.0f x %.0fm" % [ParkKit.SHIP_LENGTH * AIRSHIP_SCALE, AIRSHIP_ALTITUDE, AIRSHIP_RADII.x * 2.0, AIRSHIP_RADII.y * 2.0])
