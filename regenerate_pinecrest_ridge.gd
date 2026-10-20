@tool
extends Node

## Standalone scene generator for Pinecrest Ridge (Stage 4).
## Run headless:
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://regenerate_pinecrest_ridge.tscn
##
## Builds the terrain/road via TerrainGenerator and dresses the stage under `PinecrestDressing`
## with procedural alpine trees (Scots/mountain pine, subalpine silver fir, alpine larch, birch,
## alder), dwarf mountain shrubs, ferns, wildflower drifts, meadow grass tufts, fallen deadwood
## logs, granite cliff-cut outcrops & boulders, W-beam steel guardrails, chain-link catch fences
## with sponsor boards, wooden marshal booths, tyre walls, and spectator camps.
## Respects the Options Menu Detail Level via `JungleDetail.gd` (`vegetation_detail` group).

const Woodland = preload("res://WoodlandBuilder.gd")
const PropKit = preload("res://PropKit.gd")
const CampKit = preload("res://CampKit.gd")

const LEVEL_PATH := "res://levels/PinecrestRidgeLevel.tscn"
const MESH_DIR := "res://levels/pinecrest_ridge_meshes"
const RES_PREFIX := "pinecrest_"

const TERRAIN_SIZE := 950.0
const GRID_RES := 450
const GRID_START := -TERRAIN_SIZE * 0.5
const GRID_STEP := TERRAIN_SIZE / float(GRID_RES)

const ROAD_HALF := 7.5
const VERGE := 8.5
const PROP_SCALE := 1.85

const LAKE_CENTER := Vector2(-150.0, 140.0)
const LAKE_RADIUS := 90.0
const WATER_Y := -2.5

const WHITE := Color(0.93, 0.93, 0.91)
const GALV := Color(0.72, 0.74, 0.76)
const STEEL := Color(0.32, 0.34, 0.37)
const HAZE := Color(0.74, 0.84, 0.94)

## Control points of the closed 28-point mountain loop (matches _setup_track_curve).
const P_START := Vector3(0.0, 0.0, 160.0)
const P_STR_END := Vector3(0.0, 0.0, 80.0)
const P_VALLEY_NW := Vector3(-40.0, 1.5, 25.0)
const P_JUMP1_TAKEOFF := Vector3(-70.0, 10.0, -50.0)
const P_JUMP1_LAND := Vector3(-75.0, 20.0, -90.0)
const P_SB1 := Vector3(-55.0, 31.0, -160.0)
const P_SB2 := Vector3(50.0, 53.0, -175.0)
const P_SB3 := Vector3(-65.0, 74.0, -240.0)
const P_SUMMIT_W := Vector3(-15.0, 78.0, -250.0)
const P_SUMMIT_CREST := Vector3(45.0, 77.0, -235.0)
const P_JUMP2_TAKEOFF := Vector3(85.0, 75.0, -205.0)
const P_JUMP2_LAND := Vector3(98.0, 56.0, -160.0)
const P_SB4 := Vector3(75.0, 40.0, -80.0)
const P_SB5 := Vector3(45.0, 24.0, -15.0)
const P_DESCENT_S := Vector3(70.0, 17.0, 25.0)
const P_JUMP3_TAKEOFF := Vector3(75.0, 14.0, 60.0)
const P_JUMP3_LAND := Vector3(65.0, 1.5, 105.0)
const P_VALLEY_SE := Vector3(50.0, 0.0, 165.0)
const P_VALLEY_SW := Vector3(22.0, 0.0, 215.0)

## Graded level terraces for the paddock and spectator camps: [centre Vector2, half Vector2, yaw, target_y]
const PADDOCK_TERRACE := [Vector2(-29.0, 122.0), Vector2(32.0, 12.0), PI * 0.5, 0.0]
const MEADOW_CAMP := [Vector2(94.0, 148.0), Vector2(18.0, 14.0), -PI * 0.5, 0.5]
const SWITCHBACK_CAMP := [Vector2(-112.0, -145.0), Vector2(14.0, 11.0), 0.45, 26.0]

## Pinecrest Ridge Grand Prix sponsor artwork (16 cells for StadiumAds.gd).
const ADS := [
	["APEX GP", "PINECREST RIDGE STAGE", Color(0.84, 0.14, 0.12), Color(1, 1, 1), Color(0.98, 0.82, 0.18), 0],
	["PINECREST", "ALPINE GRAND PRIX", Color(0.06, 0.28, 0.18), Color(0.98, 0.96, 0.90), Color(0.92, 0.48, 0.12), 1],
	["RC VIBE GP", "MOUNTAIN CHAMPIONSHIP", Color(0.12, 0.22, 0.48), Color(1, 1, 1), Color(0.98, 0.76, 0.16), 2],
	["BARABARA TYRES", "ALL-WEATHER GRIP", Color(0.08, 0.08, 0.09), Color(0.98, 0.80, 0.12), Color(0.88, 0.18, 0.14), 0],
	["KILELE ENERGY", "HIGH OCTANE RACING", Color(0.96, 0.78, 0.10), Color(0.08, 0.08, 0.08), Color(0.88, 0.22, 0.10), 2],
	["ALPEN OPTIK", "PRECISION TIMING", Color(0.95, 0.96, 0.98), Color(0.08, 0.24, 0.46), Color(0.86, 0.18, 0.16), 0],
	["FIRESTORM RC", "TURBO BOOST SYSTEMS", Color(0.76, 0.12, 0.10), Color(1, 1, 1), Color(0.98, 0.82, 0.20), 1],
	["GLACIER PURE", "ALPINE SPRING WATER", Color(0.68, 0.86, 0.98), Color(0.05, 0.20, 0.48), Color(0.12, 0.52, 0.86), 0],
	["EDELWEISS AIR", "FLY THE PEAKS", Color(0.20, 0.48, 0.82), Color(1, 1, 1), Color(0.98, 0.84, 0.22), 2],
	["SUMMIT LUBE", "SYNTHETIC MOTOR OIL", Color(0.10, 0.42, 0.22), Color(1, 1, 1), Color(0.98, 0.80, 0.14), 0],
	["SIMBA MOTORS", "RALLY HERITAGE", Color(0.42, 0.07, 0.09), Color(0.98, 0.84, 0.36), Color(0.98, 0.84, 0.36), 1],
	["KAHAWA ROAST", "MOUNTAIN ESPRESSO", Color(0.94, 0.89, 0.78), Color(0.28, 0.16, 0.08), Color(0.64, 0.36, 0.14), 2],
	["APEX TELECOM", "5G RIDGE COVERAGE", Color(0.96, 0.96, 0.95), Color(0.08, 0.50, 0.24), Color(0.95, 0.75, 0.10), 0],
	["TIMBERLINE", "OUTDOOR GEAR CO.", Color(0.24, 0.18, 0.12), Color(0.98, 0.88, 0.68), Color(0.88, 0.44, 0.12), 1],
	["VALLEY DAIRY", "SWISS ALPINE CHEESE", Color(0.98, 0.84, 0.18), Color(0.14, 0.12, 0.10), Color(0.82, 0.16, 0.12), 2],
	["NITRO X", "STAGE 4 OFFICIAL SPONSOR", Color(0.26, 0.12, 0.48), Color(1, 1, 1), Color(0.98, 0.72, 0.20), 0],
]
const AD_CYCLE := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]

var _level: Node3D
var _tg: Node3D
var _curve: Curve3D
var _length := 0.0
var _heights := PackedFloat32Array()
var _road_samples := PackedVector3Array()
var _jump_zones: Array = []
var _footprints: Array = []
var _materials := {}
var _kit: PropKit
var _camp: CampKit
var _ad_k := 0
var _font: SystemFont


func _ready() -> void:
	if Engine.is_editor_hint() and get_tree().edited_scene_root == self:
		return
	var t0 := Time.get_ticks_msec()
	print("--- Regenerating Pinecrest Ridge Level ---")

	_level = Node3D.new()
	_level.name = "PinecrestRidgeLevel"
	var level_script: Script = load("res://levels/Level.gd")
	_level.set_script(level_script)

	var players_node := Node3D.new()
	players_node.name = "Players"
	_level.add_child(players_node)

	var p_spawner := MultiplayerSpawner.new()
	p_spawner.name = "PlayerSpawner"
	p_spawner.set("_spawnable_scenes", PackedStringArray(["uid://cart123"]))
	p_spawner.spawn_path = NodePath("../Players")
	p_spawner.spawn_limit = 6
	_level.add_child(p_spawner)

	add_child(_level)

	# 1. Environment & SunLight
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	_level.add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = Vector3(-42.0, 35.0, 0.0)
	sun.light_color = Color(1.0, 0.98, 0.90)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 450.0
	sun.directional_shadow_split_1 = 0.1
	sun.directional_shadow_split_2 = 0.25
	sun.directional_shadow_split_3 = 0.55
	_level.add_child(sun)

	# 2. TrackPath & Curve3D (~1650m full-scale circuit)
	var track_path := Path3D.new()
	track_path.name = "TrackPath"
	_setup_track_curve(track_path)
	_level.add_child(track_path)
	_curve = track_path.curve
	_length = _curve.get_baked_length()

	# 3. TerrainGenerator Setup
	_tg = Node3D.new()
	_tg.name = "TerrainGenerator"
	var tg_script: Script = load("res://TerrainGenerator.gd")
	_tg.set_script(tg_script)
	_tg.set("level_prefix", "pinecrest_ridge")
	_tg.set("track_layout_type", 0)
	_tg.set("terrain_resolution", GRID_RES)
	_tg.set("terrain_size", Vector2(TERRAIN_SIZE, TERRAIN_SIZE))
	_tg.set("hill_height", 14.0)
	_tg.set("road_width", 15.0)
	_tg.set("curb_outer_width", 17.0)
	_tg.set("road_y_offset", 0.06)
	_tg.set("curb_y_offset", 0.06)
	_tg.set("terrain_recession_collision", 0.12)
	_tg.set("terrain_recession_visual", 0.18)
	_tg.set("no_water", false)
	_tg.set("no_grass", false)
	_tg.set("terrain_grass_count", 0)
	_tg.set("generate_bridge_supports", false)
	_tg.set("flat_pads", _plan_pads())
	_tg.set("grass_clearings", _plan_clearings())

	var grass_tex: Texture2D = load("res://materials/grass.png") as Texture2D
	var asphalt_tex: Texture2D = load("res://materials/asphalt.png") as Texture2D
	if grass_tex:
		var grass_mat := ShaderMaterial.new()
		grass_mat.shader = load("res://terrain_grass_varied.gdshader")
		grass_mat.set_shader_parameter("grass_tex", grass_tex)
		grass_mat.set_shader_parameter("dirt_tex", load("res://materials/dirt.png"))
		grass_mat.set_shader_parameter("dirt_normal", load("res://materials/dirt_normal.png"))
		_tg.set("grass_material", grass_mat)
	if asphalt_tex:
		var road_mat := StandardMaterial3D.new()
		road_mat.albedo_texture = asphalt_tex
		road_mat.albedo_color = Color(0.92, 0.92, 0.92)
		road_mat.uv1_scale = Vector3(0.2, 0.2, 0.2)
		road_mat.roughness = 0.75
		_tg.set("road_material", road_mat)

	_level.add_child(_tg)
	_tg.set("track_path", track_path)
	print("Calling tg.generate_world()...")
	_tg.call("generate_world")

	# Re-read curve length in case TerrainGenerator closed the loop
	_curve = track_path.curve
	_length = _curve.get_baked_length()
	_heights = _tg.get("_visual_heights")
	_cache_road_samples()

	_kit = PropKit.new()
	_kit.material_for = _material
	_camp = CampKit.new(_kit)

	print("Placing gameplay track features...")
	_place_track_features(track_path)

	print("Upgrading alpine sky and atmosphere...")
	_build_sky()

	var dressing := Node3D.new()
	dressing.name = "PinecrestDressing"
	_level.add_child(dressing)

	print("Building trackside W-beam guardrails, catch fences, marshal posts, tyre walls & camps...")
	_build_guardrails(dressing)
	_build_fences(dressing)
	_build_marshal_posts(dressing)
	_build_tyre_walls_and_props(dressing)
	_build_chevrons(dressing)
	_build_lap_towers(dressing)
	_build_paddock(dressing)
	_build_campsites(dressing)
	_build_ads(dressing)

	print("Building granite cliff-cut outcrops, exposed root banks & alpine boulders...")
	_build_boulders(dressing)

	print("Building procedural alpine woodland, shrubs, ferns, wildflowers & deadwood...")
	_build_woodland(dressing)

	for c_name in ["Props", "AlternativePaths"]:
		var c := Node3D.new()
		c.name = c_name
		_level.add_child(c)

	_verify_clear()
	_set_owner_recursive(_level, _level)

	remove_child(_level)
	var new_packed := PackedScene.new()
	var err := new_packed.pack(_level)
	if err == OK:
		err = ResourceSaver.save(new_packed, LEVEL_PATH)
		if err == OK:
			print("SUCCESS! Saved Pinecrest Ridge in %.1fs to %s" % [(Time.get_ticks_msec() - t0) / 1000.0, LEVEL_PATH])
		else:
			push_error("Failed to save scene: " + str(err))
	else:
		push_error("Failed to pack scene: " + str(err))

	get_tree().quit(0)


# ======================================================================================
#  Track Curve, Ground & Road Frames
# ======================================================================================

func _setup_track_curve(track_path: Path3D) -> void:
	var curve := Curve3D.new()
	curve.bake_interval = 0.25

	var curve_pts := [
		# --- TIER 0: VALLEY FLOOR & PADDOCK SPRINT (Y = 0m -> 4m) ---
		[Vector3(0, 0, 25), Vector3(0, 0, -25), Vector3(0.0, 0.0, 160.0)],
		[Vector3(0, 0, 30), Vector3(0, 0, -30), Vector3(0.0, 0.0, 80.0)],
		[Vector3(18, 0, 25), Vector3(-20, 0.5, -25), Vector3(-40.0, 1.5, 25.0)],
		[Vector3(-10, -0.5, 22), Vector3(10, 1.8, -22), Vector3(-62.0, 5.5, -15.0)],

		# --- TIER 1: JUMP 1 (Forest Ravine Leap, Y = 10m -> 20m) ---
		[Vector3(-2, -0.5, 15), Vector3(2, 2.5, -18), Vector3(-70.0, 10.0, -50.0)],
		[Vector3(0, 2.0, 18), Vector3(0, 0.8, -18), Vector3(-75.0, 20.0, -90.0)],

		# --- TIER 2: SERPENTINE SWITCHBACKS (Climbing mountain face) ---
		[Vector3(0, -0.8, 18), Vector3(2, 1.2, -18), Vector3(-80.0, 25.0, -125.0)],
		[Vector3(-16, -1.0, 2), Vector3(20, 1.0, -2), Vector3(-55.0, 31.0, -160.0)],
		[Vector3(-20, -1.0, -4), Vector3(20, 1.0, 4), Vector3(-5.0, 38.0, -155.0)],
		[Vector3(-18, -1.0, 4), Vector3(15, 1.0, -6), Vector3(35.0, 45.0, -150.0)],
		[Vector3(10, -1.2, 16), Vector3(-12, 1.2, -18), Vector3(50.0, 53.0, -175.0)],
		[Vector3(22, -1.0, 6), Vector3(-22, 1.0, -6), Vector3(15.0, 61.0, -200.0)],
		[Vector3(18, -1.0, 4), Vector3(-16, 1.0, -8), Vector3(-35.0, 68.0, -210.0)],
		[Vector3(-15, -1.0, 4), Vector3(20, 0.8, -4), Vector3(-65.0, 74.0, -240.0)],

		# --- TIER 3: SUMMIT RIDGE & JUMP 2 (High Vista Super-Jump, Y = 78m -> 58m) ---
		[Vector3(-20, -0.5, 4), Vector3(25, 0.0, -4), Vector3(-15.0, 78.0, -250.0)],
		[Vector3(-18, 0.0, -4), Vector3(18, -0.5, 6), Vector3(45.0, 77.0, -235.0)],
		[Vector3(-10, 0.8, -10), Vector3(10, -3.5, 16), Vector3(85.0, 75.0, -205.0)],
		[Vector3(0, 4.0, -18), Vector3(2, -1.2, 18), Vector3(98.0, 56.0, -160.0)],

		# --- TIER 4: DOWNHILL SERPENTINE DESCENT (Y = 54m -> 16m) ---
		[Vector3(-8, 1.2, -16), Vector3(8, -1.2, 16), Vector3(105.0, 48.0, -120.0)],
		[Vector3(16, 1.2, -4), Vector3(-18, -1.2, 4), Vector3(75.0, 40.0, -80.0)],
		[Vector3(16, 1.0, -12), Vector3(-16, -1.0, 12), Vector3(30.0, 32.0, -45.0)],
		[Vector3(-14, 1.0, -6), Vector3(16, -1.0, 6), Vector3(45.0, 24.0, -15.0)],
		[Vector3(-8, 1.0, -15), Vector3(6, -0.8, 16), Vector3(70.0, 17.0, 25.0)],

		# --- TIER 5: JUMP 3 (Forest Creek Launch Ramp & Valley Sprint) ---
		[Vector3(-2, 0.8, -12), Vector3(0, 2.2, 16), Vector3(75.0, 14.0, 60.0)],
		[Vector3(0, 3.0, -16), Vector3(-4, -0.5, 18), Vector3(65.0, 1.5, 105.0)],
		[Vector3(12, 0.0, -16), Vector3(-12, 0.0, 18), Vector3(50.0, 0.0, 165.0)],
		[Vector3(16, 0.0, -8), Vector3(-16, 0.0, 8), Vector3(22.0, 0.0, 215.0)],
		[Vector3(8, 0.0, 10), Vector3(0, 0.0, -15), Vector3(0.0, 0.0, 205.0)],
	]
	for pt in curve_pts:
		curve.add_point(pt[2], pt[0], pt[1])
	track_path.curve = curve


func _cache_road_samples() -> void:
	_road_samples.clear()
	var n := int(ceilf(_length))
	for i in range(n):
		_road_samples.append(_curve.sample_baked(float(i)))
	_jump_zones = [
		Vector2(_d_at_point(P_JUMP1_TAKEOFF) - 10.0, _d_at_point(P_JUMP1_LAND) + 12.0),
		Vector2(_d_at_point(P_JUMP2_TAKEOFF) - 10.0, _d_at_point(P_JUMP2_LAND) + 12.0),
		Vector2(_d_at_point(P_JUMP3_TAKEOFF) - 10.0, _d_at_point(P_JUMP3_LAND) + 12.0),
	]


func _d_at_point(target: Vector3) -> float:
	var best_d := 0.0
	var best_dist2 := INF
	var d := 0.0
	while d <= _length:
		var p: Vector3 = _curve.sample_baked(d)
		var d2: float = p.distance_squared_to(target)
		if d2 < best_dist2:
			best_dist2 = d2
			best_d = d
		d += 1.0
	return best_d


func _in_jump_zone(d: float, pad := 0.0) -> bool:
	var dw: float = fposmod(d, _length)
	for jz in _jump_zones:
		var z: Vector2 = jz
		if dw >= z.x - pad and dw <= z.y + pad:
			return true
	return false


func _ground(x: float, z: float) -> float:
	if _heights.is_empty():
		return _tg.call("_get_height_at", x, z)
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


func _ground_min(x: float, z: float, r: float) -> float:
	var lo := _ground(x, z)
	for k in range(8):
		var a := TAU * k / 8.0
		lo = minf(lo, _ground(x + cos(a) * r, z + sin(a) * r))
	return lo


func _ground_normal(x: float, z: float) -> Vector3:
	var e := 1.2
	var hL: float = _ground(x - e, z)
	var hR: float = _ground(x + e, z)
	var hD: float = _ground(x, z - e)
	var hU: float = _ground(x, z + e)
	return Vector3(hL - hR, 2.0 * e, hD - hU).normalized()


func _slope(x: float, z: float) -> float:
	var sx := _ground(x + 1.5, z) - _ground(x - 1.5, z)
	var sz := _ground(x, z + 1.5) - _ground(x, z - 1.5)
	return Vector2(sx, sz).length() / 3.0


func _relief(x: float, z: float, reach: float) -> float:
	var h0 := _ground(x, z)
	var low := h0
	for k in range(8):
		var a := TAU * k / 8.0
		low = minf(low, _ground(x + cos(a) * reach, z + sin(a) * reach))
	return h0 - low


func _frame(s: float) -> Dictionary:
	var ss := fposmod(s, _length)
	var p := _curve.sample_baked(ss)
	var a := _curve.sample_baked(fposmod(ss - 0.6, _length))
	var b := _curve.sample_baked(fposmod(ss + 0.6, _length))
	var f := b - a
	f.y = 0.0
	f = f.normalized()
	return {"pos": p, "fwd": f, "right": Vector3(-f.z, 0.0, f.x)}


func _at(s: float, lat: float) -> Vector3:
	var fr := _frame(s)
	var w: Vector3 = (fr["pos"] as Vector3) + (fr["right"] as Vector3) * lat
	w.y = _ground(w.x, w.z)
	return w


static func _yaw_to(d: Vector3) -> float:
	return atan2(-d.x, -d.z)


func _road_distance(x: float, z: float) -> float:
	var best2 := INF
	for i in range(0, _road_samples.size(), 2):
		var rp: Vector3 = _road_samples[i]
		var dx: float = x - rp.x
		var dz: float = z - rp.z
		var d2: float = dx * dx + dz * dz
		if d2 < best2:
			best2 = d2
	return sqrt(best2)


func _plan_pads() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for t in [PADDOCK_TERRACE, MEADOW_CAMP, SWITCHBACK_CAMP]:
		var c: Vector2 = t[0]
		var h: Vector2 = t[1]
		var yaw: float = float(t[2])
		var ty: float = float(t[3])
		out.append_array(PackedFloat32Array([c.x, c.y, h.x, h.y, yaw, ty, 11.0]))
	return out


func _plan_clearings() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for t in [PADDOCK_TERRACE, MEADOW_CAMP, SWITCHBACK_CAMP]:
		var c: Vector2 = t[0]
		var h: Vector2 = t[1]
		var yaw: float = float(t[2])
		out.append_array(PackedFloat32Array([c.x, c.y, h.x + 3.0, h.y + 3.0, yaw, 6.0]))
	return out


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
			if absf(turn) > 0.05 and signf(turn) == signf(lat):
				var steps := ceili(absf(turn) / 0.12)
				for k in range(1, steps):
					var nn := prev_n.rotated(Vector3.UP, turn * k / steps)
					pts.append(a + nn * lat)
		pts.append(a + nrm * lat)
		prev_n = nrm
	pts.append((cl[cl.size() - 1] as Vector3) + prev_n * lat)
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


## Like _offset_run, but splits the line wherever it gets closer to the road than `lat` (e.g. where the
## inside of a hairpin folds back on itself or the line crosses an adjacent switchback leg), so barriers
## never bridge over or sit on the asphalt. Returns an Array of PackedVector3Array sub-runs.
func _offset_runs(s0: float, s1: float, lat: float, step: float) -> Array:
	var pts := _offset_run(s0, s1, lat, step)
	var need := absf(lat) - 0.8
	var runs: Array = []
	var cur := PackedVector3Array()
	for p in pts:
		if _road_distance(p.x, p.z) >= need:
			cur.append(p)
		else:
			if cur.size() >= 2:
				runs.append(cur)
			cur = PackedVector3Array()
	if cur.size() >= 2:
		runs.append(cur)
	return runs

## Returns `lat` if a prop of the given footprint radius at (s, lat) stays clear of every road leg,
## otherwise tries the opposite side of the road, else 0.0 (skip the prop).
func _safe_lat(s: float, lat: float, radius: float) -> float:
	for cand in [lat, -lat]:
		var p := _at(s, cand)
		if _road_distance(p.x, p.z) - radius - ROAD_HALF >= 0.6:
			return cand
	return 0.0


func _note(what: String, at: Vector3, radius: float, clearance: float) -> void:
	_footprints.append([what, Vector2(at.x, at.z), radius, clearance])


func _verify_clear() -> void:
	var bad := 0
	for f in _footprints:
		var c: Vector2 = f[1]
		var gap: float = _road_distance(c.x, c.y) - float(f[2]) - ROAD_HALF
		if gap < float(f[3]):
			push_warning("Pinecrest: %s is %.1fm off the road's edge (wants %.1fm)" % [f[0], gap, f[3]])
			bad += 1
	print("  %d footprints checked, %d closer than target" % [_footprints.size(), bad])


# ======================================================================================
#  Materials, Saving & Kit Helpers
# ======================================================================================

func _save_res(res: Resource, res_name: String) -> Resource:
	return _tg.call("_save_resource", res, RES_PREFIX + res_name)


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
		_:
			m = CampKit.make_material(key)
	m = _save_res(m, "mat_" + key)
	_materials[key] = m
	return m


func _chainlink_texture() -> Texture2D:
	const N := 128
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	for y in range(N):
		for x in range(N):
			var u := float(x) + 0.5
			var v := float(y) + 0.5
			var d1 := absf(fposmod(u + v, float(N)) - N * 0.5)
			var d2 := absf(fposmod(u - v, float(N)) - N * 0.5)
			var w1 := clampf(4.2 - (N * 0.5 - d1), 0.0, 1.0) if d1 > N * 0.5 - 5.0 else 0.0
			var w2 := clampf(4.2 - (N * 0.5 - d2), 0.0, 1.0) if d2 > N * 0.5 - 5.0 else 0.0
			var a := maxf(w1, w2)
			var shade := 0.75 + 0.25 * (w1 if w1 > w2 else w2)
			img.set_pixel(x, y, Color(shade, shade, shade, a))
	img.generate_mipmaps()
	return _save_res(ImageTexture.create_from_image(img), "chainlink")


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


func _wall_box(a: Vector3, b: Vector3, w: float, h: float, lift := 0.0) -> Array:
	var d := b - a
	d.y = 0.0
	var length := d.length()
	var z := d / maxf(length, 1e-4)
	var x := Vector3.UP.cross(z).normalized()
	var mid := (a + b) * 0.5
	mid.y = (a.y + b.y + h) * 0.5 + lift
	return [mid, Vector3(w, h + absf(a.y - b.y), length), Basis(x, Vector3.UP, z)]


func _place(at: Vector3, yaw: float, s := PROP_SCALE) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), at)


func _bold_font() -> SystemFont:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["Arial Black", "Impact", "Helvetica Neue", "Arial", "sans-serif"])
		_font.font_weight = 900
	return _font


# ======================================================================================
#  Gameplay Track Features (Gantry, Boosts, Item Boxes, Checkpoints)
# ======================================================================================

func _place_track_features(track_path: Path3D) -> void:
	# 4. Finish Line & Starting Grid
	var gate_scene: PackedScene = load("res://CheckpointGate.tscn")
	var spawn_scene: PackedScene = load("res://SpawnIndicator.tscn")

	var finish_line: Node3D = gate_scene.instantiate()
	finish_line.name = "FinishLine"
	finish_line.position = Vector3(0.0, 0.06, 160.0)
	finish_line.rotation_degrees = Vector3(0, 0, 0)
	finish_line.set("is_finish_line", true)
	_level.add_child(finish_line)

	var spawn_points := Node3D.new()
	spawn_points.name = "SpawnPoints"
	finish_line.add_child(spawn_points)

	var grid_coords := [
		Vector3(-2.8, 0.05, 5.0),
		Vector3(2.8, 0.05, 5.0),
		Vector3(-2.8, 0.05, 12.0),
		Vector3(2.8, 0.05, 12.0),
		Vector3(-2.8, 0.05, 19.0),
		Vector3(2.8, 0.05, 19.0),
	]
	for i in range(grid_coords.size()):
		var sp := Marker3D.new()
		sp.name = "Spawn%d" % (i + 1)
		sp.position = grid_coords[i]
		sp.gizmo_extents = 0.3
		spawn_points.add_child(sp)
		if spawn_scene:
			var si = spawn_scene.instantiate()
			si.name = "SpawnIndicator"
			sp.add_child(si)

	# 5. Checkpoints Container (6 cleanly spaced milestone gates)
	var checkpoints_container := Node3D.new()
	checkpoints_container.name = "Checkpoints"
	_level.add_child(checkpoints_container)

	var cp_count := 6
	var cp_step := _length / float(cp_count + 1)
	for i in range(cp_count):
		var dist_along := cp_step * float(i + 1)
		var cp_pos := _curve.sample_baked(dist_along)
		var next_pos := _curve.sample_baked(minf(_length, dist_along + 1.0))
		var forward := (next_pos - cp_pos).normalized()
		var rot_y := rad_to_deg(atan2(-forward.x, -forward.z))

		var gate: Node3D = gate_scene.instantiate()
		gate.name = "Checkpoint_%d" % (i + 1)
		gate.position = cp_pos + Vector3(0, 0.1, 0)
		gate.rotation_degrees = Vector3(0, rot_y, 0)
		checkpoints_container.add_child(gate)

	# 7. Boost Pads
	var boost_scene: PackedScene = load("res://BoostPad.tscn")
	var boost_container := Node3D.new()
	boost_container.name = "BoostPads"
	_level.add_child(boost_container)

	if boost_scene:
		var bp_defs := [
			["Boost_Jump1_L", Vector3(-67.0, 10.1, -48.0), 165.0],
			["Boost_Jump1_R", Vector3(-73.0, 10.1, -48.0), 165.0],
			["Boost_Jump2_L", Vector3(81.2, 75.1, -205.9), -164.0],
			["Boost_Jump2_M", Vector3(85.0, 75.1, -207.0), -164.0],
			["Boost_Jump2_R", Vector3(88.8, 75.1, -208.1), -164.0],
			["Boost_Jump3_L", Vector3(72.1, 14.1, 57.3), 167.5],
			["Boost_Jump3_R", Vector3(77.9, 14.1, 58.7), 167.5],
			["Boost_StartStraight", Vector3(0.0, 0.08, 110.0), 0.0],
			["Boost_MidClimb", Vector3(-5.0, 38.1, -155.0), -80.0],
			["Boost_SummitRidge", Vector3(45.0, 77.1, -235.0), -100.0],
		]
		for bp_info in bp_defs:
			var bp: Node3D = boost_scene.instantiate()
			bp.name = bp_info[0]
			bp.position = bp_info[1]
			bp.rotation_degrees = Vector3(0, bp_info[2], 0)
			boost_container.add_child(bp)

	# 8. Item Boxes
	var item_scene: PackedScene = load("res://ItemBox.tscn")
	var item_container := Node3D.new()
	item_container.name = "ItemBoxes"
	_level.add_child(item_container)

	if item_scene:
		var item_rows := [
			[Vector3(-4.0, 1.2, 60.0), Vector3(0.0, 1.2, 60.0), Vector3(4.0, 1.2, 60.0)],
			[Vector3(11.0, 61.2, -200.0), Vector3(15.0, 61.2, -200.0), Vector3(19.0, 61.2, -200.0)],
			[Vector3(16.0, 77.5, -240.0), Vector3(20.0, 77.5, -240.0), Vector3(24.0, 77.5, -240.0)],
			[Vector3(66.0, 17.2, 25.0), Vector3(70.0, 17.2, 25.0), Vector3(74.0, 17.2, 25.0)],
		]
		var item_idx := 1
		for row in item_rows:
			for pos in row:
				var ib: Node3D = item_scene.instantiate()
				ib.name = "ItemBox_%d" % item_idx
				ib.position = pos
				item_container.add_child(ib)
				item_idx += 1

	_level.set("track_path", track_path)
	_level._setup_checkpoints()


# ======================================================================================
#  Alpine Sky & Atmosphere
# ======================================================================================

func _build_sky() -> void:
	var we := _level.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we == null:
		we = WorldEnvironment.new()
		we.name = "WorldEnvironment"
		_level.add_child(we)

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://sky_tropical_cumulus.gdshader")
	sm.set_shader_parameter("sky_top", Color(0.14, 0.36, 0.76))
	sm.set_shader_parameter("sky_horizon", Color(0.68, 0.82, 0.94))
	sm.set_shader_parameter("ground_horizon", HAZE)
	sm.set_shader_parameter("ground_bottom", Color(0.28, 0.36, 0.30))
	sm.set_shader_parameter("sky_curve", 0.32)
	sm.set_shader_parameter("horizon_haze", HAZE)
	sm.set_shader_parameter("haze_strength", 0.65)
	sm.set_shader_parameter("haze_height", 0.16)
	sm.set_shader_parameter("sun_tint", Color(1.0, 0.95, 0.84))
	sm.set_shader_parameter("sun_disc_degrees", 1.0)
	sm.set_shader_parameter("sun_glow", 0.5)
	sm.set_shader_parameter("cloud_lit", Color(1.0, 0.99, 0.96))
	sm.set_shader_parameter("cloud_shade", Color(0.50, 0.58, 0.72))
	sm.set_shader_parameter("cloud_coverage", 0.38)
	sm.set_shader_parameter("cloud_opacity", 0.94)
	sm.set_shader_parameter("cloud_scale", 1.85)
	sm.set_shader_parameter("cloud_seed", 41.3)
	sky.sky_material = _save_res(sm, "alpine_sky_mat")
	env.sky = _save_res(sky, "alpine_sky")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.64
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = HAZE
	env.fog_sun_scatter = 0.2
	env.fog_density = 1.0
	env.fog_depth_begin = 210.0
	env.fog_depth_end = 1450.0
	env.fog_depth_curve = 1.2
	env.fog_sky_affect = 0.05
	env.fog_aerial_perspective = 0.32
	we.environment = _save_res(env, "alpine_env")

	var tv := _level.get_node_or_null("TerrainGenerator/Terrain_Visual") as MeshInstance3D
	if tv and tv.material_override is ShaderMaterial:
		(tv.material_override as ShaderMaterial).set_shader_parameter("edge_fade_color", HAZE)


# ======================================================================================
#  1. Corrugated W-Beam Steel Guardrails (Concept Art 1)
# ======================================================================================

func _build_guardrails(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Guardrails"
	root.add_child(node)

	var kit := {}
	var k := _kit
	k.reset_frame()
	var boxes: Array = []

	var d_p3 := _d_at_point(P_VALLEY_NW)
	var d_j1_t := _d_at_point(P_JUMP1_TAKEOFF)
	var d_sb1 := _d_at_point(P_SB1)
	var d_sb2 := _d_at_point(P_SB2)
	var d_sb3 := _d_at_point(P_SB3)
	var d_sum_w := _d_at_point(P_SUMMIT_W)
	var d_sum_c := _d_at_point(P_SUMMIT_CREST)
	var d_j2_t := _d_at_point(P_JUMP2_TAKEOFF)
	var d_sb4 := _d_at_point(P_SB4)
	var d_sb5 := _d_at_point(P_SB5)
	var d_des := _d_at_point(P_DESCENT_S)
	var d_j3_t := _d_at_point(P_JUMP3_TAKEOFF)
	var d_vse := _d_at_point(P_VALLEY_SE)

	# [d_start, d_end, lat_offset]
	var runs := [
		[d_p3 - 15.0, d_j1_t - 14.0, -(VERGE + 0.55)],
		[d_sb1 - 44.0, d_sb1 + 42.0, VERGE + 0.55],
		[d_sb2 - 42.0, d_sb2 + 44.0, -(VERGE + 0.55)],
		[d_sb3 - 42.0, d_sb3 + 42.0, VERGE + 0.55],
		[d_sum_w - 40.0, d_j2_t - 16.0, -(VERGE + 0.55)],
		[d_sum_c - 22.0, d_j2_t - 18.0, VERGE + 0.55],
		[d_sb4 - 30.0, d_sb4 + 40.0, -(VERGE + 0.55)],
		[d_sb5 - 34.0, d_sb5 + 34.0, VERGE + 0.55],
		[d_des - 24.0, d_j3_t - 16.0, -(VERGE + 0.55)],
		[d_vse - 38.0, d_vse + 38.0, -(VERGE + 0.55)],
	]

	var rail_col := Color(0.76, 0.78, 0.80)
	var post_col := Color(0.28, 0.30, 0.33)
	var red_refl := Color(0.92, 0.14, 0.10)
	var wht_refl := Color(0.95, 0.95, 0.92)

	var sub_runs: Array = []
	for r in runs:
		for sr in _offset_runs(float(r[0]), float(r[1]), float(r[2]), 2.8):
			sub_runs.append([sr, -signf(float(r[2]))])

	for sub in sub_runs:
		var pts: PackedVector3Array = sub[0]
		var road_side: float = sub[1]
		for i in range(pts.size()):
			var p: Vector3 = pts[i]
			var s_near := _curve.get_closest_offset(p)
			if _in_jump_zone(s_near, 4.0):
				continue
			# Steel I-post + reflector tab
			k.beam(kit, "steel", p - Vector3(0, 0.45, 0), p + Vector3(0, 1.08, 0), 0.14, 0.12, post_col)
			var rcol := red_refl if road_side < 0.0 else wht_refl
			k.block(kit, "paint", p + Vector3(-0.05, 1.08, -0.05), p + Vector3(0.05, 1.18, 0.05), rcol)
			_note("Guardrail", p, 0.15, 0.7)

			if i == 0:
				continue
			var q: Vector3 = pts[i - 1]
			if _in_jump_zone(_curve.get_closest_offset(q), 4.0):
				continue
			var seg := p - q
			seg.y = 0.0
			if seg.length_squared() < 1e-4:
				continue
			var along := seg.normalized()
			var face := Vector3(-along.z, 0.0, along.x) * road_side
			# Double corrugated W-beam profile (upper and lower flange ridges + recessed groove)
			k.beam(kit, "metal", q + Vector3(0, 0.88, 0) + face * 0.06, p + Vector3(0, 0.88, 0) + face * 0.06, 0.07, 0.14, rail_col, face)
			k.beam(kit, "metal", q + Vector3(0, 0.72, 0) + face * 0.03, p + Vector3(0, 0.72, 0) + face * 0.03, 0.06, 0.12, rail_col.darkened(0.12), face)
			k.beam(kit, "metal", q + Vector3(0, 0.56, 0) + face * 0.06, p + Vector3(0, 0.56, 0) + face * 0.06, 0.07, 0.14, rail_col, face)
			boxes.append(_wall_box(q, p, 0.35, 1.15))

	_commit(node, kit, "WBeamGuardrails")
	_boxes_body(node, "GuardrailBarrierBody", boxes)


# ======================================================================================
#  2. Chain-Link Catch Fences & Sponsor Boards (Concept Art 1 & 2)
# ======================================================================================

func _ad_board(kit: Dictionary, a: Vector3, b: Vector3, h: float, face: Vector3, ad: int) -> void:
	var up := Vector3(0, h, 0)
	var f := face.normalized()
	var off := f * 0.02
	var col := Color(float(ad) / 64.0, 0.0, 0.0, 1.0)
	var left_to_right := (b - a)
	var p0 := a
	var p1 := b
	if f.cross(Vector3.UP).dot(left_to_right) > 0.0:
		p0 = b
		p1 = a
	_kit.quad(kit, "boards", [p0 + off, p1 + off, p1 + up + off, p0 + up + off], f, col,
			[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	_kit.quad(kit, "steel", [p1 - f * 0.02, p0 - f * 0.02, p0 + up - f * 0.02, p1 + up - f * 0.02], -f, Color(0.12, 0.12, 0.13))
	_kit.beam(kit, "steel", p0 + up, p1 + up, 0.05, 0.06, Color(0.14, 0.14, 0.15), f)
	_kit.beam(kit, "steel", p0, p1, 0.05, 0.06, Color(0.14, 0.14, 0.15), f)


func _next_ad() -> int:
	var ad: int = AD_CYCLE[_ad_k % AD_CYCLE.size()]
	_ad_k += 1
	return ad


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


func _build_fences(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "CatchFences"
	root.add_child(node)

	var d_sb1 := _d_at_point(P_SB1)
	var d_vse := _d_at_point(P_VALLEY_SE)
	var d_vsw := _d_at_point(P_VALLEY_SW)

	var runs := [
		[8.0, 72.0, -12.8, "FencePaddock"],
		[d_vse - 35.0, d_vse + 25.0, -12.8, "FenceMeadowCamp"],
		[d_sb1 - 26.0, d_sb1 + 30.0, -11.8, "FenceSwitchbackCamp"],
		[d_vsw - 24.0, d_vsw + 28.0, 11.8, "FenceLakesideCorner"],
	]
	for r in runs:
		var sub_i := 0
		for pts in _offset_runs(float(r[0]), float(r[1]), float(r[2]), 0.5):
			_fence(node, pts, -signf(float(r[2])), String(r[3]) + ("" if sub_i == 0 else str(sub_i)))
			sub_i += 1


func _fence(parent: Node3D, pts: PackedVector3Array, road_side: float, node_name: String) -> void:
	var kit := {}
	var k := _kit
	k.reset_frame()
	var spacing := 3.0 * PROP_SCALE
	var height := 1.9 * PROP_SCALE
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
		k.tube(kit, "metal", p - Vector3(0, 0.5, 0), p + Vector3(0, height + 0.05, 0), 0.05, 0.05, 8, GALV)
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
		var u0 := 0.0
		var u1 := dl
		k.quad(kit, "chainlink", [q + Vector3(0, 0.06, 0), p + Vector3(0, 0.06, 0), p + Vector3(0, height, 0), q + Vector3(0, height, 0)], face, WHITE,
				[Vector2(u0, height), Vector2(u1, height), Vector2(u1, 0.06), Vector2(u0, 0.06)])
		boxes.append(_wall_box(q, p, 0.3, height))
		_note(node_name, (p + q) * 0.5, 0.1, 2.0)

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
		_ad_board(kit, Vector3(q2.x, lo, q2.z) + off + Vector3(0, 0.14, 0), Vector3(p2.x, lo, p2.z) + off + Vector3(0, 0.14, 0), 1.15, face2, _next_ad())
		i2 += span
	_commit(parent, kit, node_name)
	_boxes_body(parent, node_name + "Body", boxes)


# ======================================================================================
#  3. Wooden Trackside Marshal Posts (Concept Art 1)
# ======================================================================================

func _build_marshal_posts(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "MarshalPosts"
	root.add_child(node)

	var kit := {}
	var boxes: Array = []

	var d_p3 := _d_at_point(P_VALLEY_NW)
	var d_sb1 := _d_at_point(P_SB1)
	var d_sb4 := _d_at_point(P_SB4)

	var spots := [
		[d_p3 - 20.0, 12.2, "MarshalPost1"],
		[d_sb1 - 15.0, -12.0, "MarshalPost2"],
		[d_sb4 - 16.0, 12.2, "MarshalPost3"],
	]
	for sp in spots:
		var s: float = sp[0]
		var lat: float = sp[1]
		var fr := _frame(s)
		var at := _at(s, lat)
		at.y = _ground_min(at.x, at.z, 1.8)
		var face_dir: Vector3 = -(fr["right"] as Vector3) * signf(lat)
		var yaw := _yaw_to(face_dir)
		_kit.set_frame(_place(at, yaw))
		_marshal_hut(kit)
		boxes.append([at + Vector3(0, 1.3 * PROP_SCALE, 0), Vector3(1.8, 2.6, 1.5) * PROP_SCALE, Basis(Vector3.UP, yaw)])
		_note(String(sp[2]), at, 1.4 * PROP_SCALE, 1.8)

	_commit(node, kit, "MarshalHuts")
	_boxes_body(node, "MarshalHutsBody", boxes)


## Wooden marshal shelter at life size (front toward -z): timber posts, half-height plank boarding,
## sloped corrugated roof, yellow marshal sign, and green/yellow flags.
func _marshal_hut(kit: Dictionary) -> void:
	var k := _kit
	var dark_wood := Color(0.32, 0.22, 0.13)
	var plank := Color(0.50, 0.35, 0.20)
	var tin := Color(0.34, 0.37, 0.40)
	var hx := 0.85
	var hz := 0.68
	# Deep timber footing & floor deck
	k.block(kit, "wood", Vector3(-hx, -0.55, -hz), Vector3(hx, 0.08, hz), dark_wood)
	# 4 corner timber posts
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var top_y: float = 2.15 if sz < 0.0 else 1.92
			k.block(kit, "wood", Vector3(sx * (hx - 0.06) - 0.05, 0.08, sz * (hz - 0.06) - 0.05),
					Vector3(sx * (hx - 0.06) + 0.05, top_y, sz * (hz - 0.06) + 0.05), dark_wood)
	# Waist-high horizontal plank walls (front, back, left)
	for p_i in range(4):
		var y0 := 0.10 + p_i * 0.20
		var y1 := y0 + 0.18
		var shade := plank.darkened(0.05 * (p_i % 2))
		k.block(kit, "wood", Vector3(-hx, y0, -hz), Vector3(hx, y1, -hz + 0.05), shade)
		k.block(kit, "wood", Vector3(-hx, y0, hz - 0.05), Vector3(hx, y1, hz), shade)
		k.block(kit, "wood", Vector3(-hx, y0, -hz), Vector3(-hx + 0.05, y1, hz), shade)
	# Front counter shelf
	k.block(kit, "wood", Vector3(-hx - 0.04, 0.90, -hz - 0.08), Vector3(hx + 0.04, 0.95, -hz + 0.10), dark_wood)
	# Sloped roof
	var r_xf := Transform3D(Basis(Vector3.RIGHT, 0.13), Vector3(0, 2.06, 0))
	k.box(kit, "wood", r_xf, Vector3(hx * 2.3, 0.06, hz * 2.35), plank)
	k.box(kit, "metal", r_xf * Transform3D(Basis(), Vector3(0, 0.05, 0)), Vector3(hx * 2.36, 0.04, hz * 2.42), tin)
	# Yellow marshal sign & green safety flag on front post
	k.block(kit, "paint", Vector3(-hx + 0.08, 1.55, -hz - 0.03), Vector3(-hx + 0.48, 1.88, -hz), Color(0.96, 0.78, 0.10))
	k.tube(kit, "wood", Vector3(hx, 1.15, -hz), Vector3(hx + 0.35, 1.85, -hz - 0.1), 0.015, 0.015, 5, dark_wood)
	k.panel(kit, "canvas", [Vector3(hx + 0.15, 1.45, -hz - 0.04), Vector3(hx + 0.35, 1.85, -hz - 0.1),
			Vector3(hx + 0.62, 1.72, -hz - 0.1), Vector3(hx + 0.42, 1.32, -hz - 0.04)],
			Vector3(0, 0, -1), Color(0.14, 0.68, 0.24), Color(0.10, 0.50, 0.18))


# ======================================================================================
#  4. Tyre Walls, Chequered Tarps, Water Barrels, Cones & Rockfall Fences
# ======================================================================================

const TYRE_COLS := [Color(0.82, 0.11, 0.10), Color(0.93, 0.93, 0.90), Color(0.08, 0.08, 0.09)]

func _build_tyre_walls_and_props(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "RaceBarriers"
	root.add_child(node)

	var d_p3 := _d_at_point(P_VALLEY_NW)
	var d_sb1 := _d_at_point(P_SB1)
	var d_sb2 := _d_at_point(P_SB2)
	var d_sb3 := _d_at_point(P_SB3)
	var d_sum_w := _d_at_point(P_SUMMIT_W)
	var d_sb4 := _d_at_point(P_SB4)
	var d_sb5 := _d_at_point(P_SB5)
	var d_vse := _d_at_point(P_VALLEY_SE)
	var d_vsw := _d_at_point(P_VALLEY_SW)

	# 1. Red/white/black tyre stacks at switchback apexes/exits and valley sweepers
	var tyre_runs := [
		[d_sb1 - 22.0, d_sb1 + 20.0, -(VERGE + 1.0), "TyreWallSB1"],
		[d_sb2 - 20.0, d_sb2 + 20.0, VERGE + 1.0, "TyreWallSB2"],
		[d_sb3 - 20.0, d_sb3 + 20.0, -(VERGE + 1.0), "TyreWallSB3"],
		[d_sb4 - 18.0, d_sb4 + 20.0, VERGE + 1.0, "TyreWallSB4"],
		[d_sb5 - 18.0, d_sb5 + 18.0, -(VERGE + 1.0), "TyreWallSB5"],
		[d_vse - 22.0, d_vse + 22.0, -(VERGE + 1.1), "TyreWallValleySE"],
		[d_vsw - 20.0, d_vsw + 20.0, VERGE + 1.1, "TyreWallValleySW"],
	]
	var tyre_subs: Array = []
	for r in tyre_runs:
		var sub_i := 0
		for sr in _offset_runs(float(r[0]), float(r[1]), float(r[2]), 0.995 * PROP_SCALE * 0.62):
			tyre_subs.append([sr, String(r[3]) + ("" if sub_i == 0 else str(sub_i))])
			sub_i += 1
	for sub in tyre_subs:
		var pts: PackedVector3Array = sub[0]
		var tw_name: String = sub[1]
		var kit := {}
		var boxes: Array = []
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(tw_name)
		for i in range(pts.size()):
			var p: Vector3 = pts[i]
			_kit.set_frame(_place(p, rng.randf() * TAU))
			var col: Color = TYRE_COLS[i % 3]
			for t in range(3):
				var j := Vector3(rng.randf_range(-0.02, 0.02), 0.0, rng.randf_range(-0.02, 0.02))
				_kit.tyre(kit, "rubber", Vector3(0, 0.1 + t * 0.2, 0) + j, 0.19, 0.31, 0.2, 14, col.darkened(rng.randf_range(0.0, 0.12)))
			if i > 0 and (i % 4 == 0 or i == pts.size() - 1):
				boxes.append(_wall_box(pts[maxi(i - 4, 4 * ((i - 1) / 4))], p, 0.62 * PROP_SCALE, 0.6 * PROP_SCALE))
		_commit(node, kit, tw_name)
		_boxes_body(node, tw_name + "Body", boxes)
		for p in pts:
			_note(tw_name, p, 0.5, 1.0)

	# 2. Chequered-cloth tyre stacks & orange/white water crash barrels (Concept Art 1 & 2)
	var prop_kit := {}
	var prop_boxes: Array = []
	var cluster_spots := [
		[d_p3 - 16.0, 10.2],
		[d_sb1 - 12.0, -10.2],
		[d_sb1 + 12.0, 10.2],
		[d_sb2 - 14.0, -10.2],
		[d_sb3 - 14.0, 10.2],
		[d_sum_w - 14.0, -10.2],
		[d_sb4 - 13.0, 10.2],
		[d_sb5 - 13.0, 10.2],
	]
	for cs in cluster_spots:
		var s_c: float = cs[0]
		var lat_c: float = _safe_lat(s_c, float(cs[1]), 0.9 * PROP_SCALE + 1.2)
		if lat_c == 0.0:
			continue
		var fr := _frame(s_c)
		var at := _at(s_c, lat_c)
		var yaw := _yaw_to(-(fr["right"] as Vector3) * signf(lat_c))
		_kit.set_frame(_place(at, yaw))
		_chequered_tyres_and_barrels(prop_kit)
		prop_boxes.append([at + Vector3(0, 0.5 * PROP_SCALE, 0), Vector3(1.5, 1.0, 0.9) * PROP_SCALE, Basis(Vector3.UP, yaw)])
		_note("ChequeredTyres", at, 0.9 * PROP_SCALE, 1.2)

	# 3. Slatted timber rockfall / snow fences on upper mountain slopes (Concept Art 2)
	var rfence_lines := [
		[d_sb1 + 30.0, d_sb2 - 22.0, 15.5],
		[d_sb2 + 28.0, d_sb3 - 22.0, -15.5],
		[d_sb3 + 26.0, d_sum_w - 22.0, 15.5],
	]
	for rfl in rfence_lines:
		var s := float(rfl[0])
		while s <= float(rfl[1]):
			var fr := _frame(s)
			var at := _at(s, float(rfl[2]))
			var yaw := _yaw_to(-(fr["right"] as Vector3) * signf(float(rfl[2])))
			_kit.set_frame(_place(at, yaw))
			_rockfall_fence(prop_kit)
			_note("RockfallFence", at, 1.2 * PROP_SCALE, 4.0)
			s += 5.5

	_commit(node, prop_kit, "CornerBarrelsAndRockFences")
	_boxes_body(node, "CornerBarrelsBody", prop_boxes)

	# 4. Knockable traffic cones along corner verges & pit entry
	var cone_spots := [
		[18.0, 9.2], [22.0, 9.2], [26.0, 9.2], [106.0, 9.2], [110.0, 9.2],
		[d_p3 - 22.0, 9.4], [d_p3 - 19.0, 9.4],
		[d_sb1 - 18.0, -9.4], [d_sb1 - 15.0, -9.4],
		[d_sb2 - 17.0, -9.5], [d_sb3 - 17.0, 9.5],
		[d_sb4 - 16.0, 9.4], [d_sb5 - 16.0, 9.4],
	]
	var cone_xfs: Array = []
	var rng_c := RandomNumberGenerator.new()
	rng_c.seed = 77
	for c in cone_spots:
		var c_lat := _safe_lat(float(c[0]), float(c[1]), 1.0)
		if c_lat == 0.0:
			continue
		var p := _at(float(c[0]), c_lat)
		cone_xfs.append(Transform3D(Basis(Vector3.UP, rng_c.randf() * TAU), p))
		_note("Cone", p, 0.3, 0.4)
	var ck := {}
	_kit.set_frame(Transform3D(Basis().scaled(Vector3.ONE * PROP_SCALE), Vector3.ZERO))
	_camp.cone(ck)
	var cmesh: Mesh = _save_res(_kit.commit(ck), "cone")
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cmesh
	mm.instance_count = cone_xfs.size()
	mm.buffer = PropKit.transform_buffer(cone_xfs)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Cones"
	mmi.set_script(load("res://KnockableProps.gd"))
	var typed: Array[Transform3D] = []
	for t in cone_xfs:
		typed.append(t)
	mmi.set("prop_transforms", typed)
	mmi.set("boxes", [[Vector3(0, 0.03, 0) * PROP_SCALE, Vector3(0.38, 0.06, 0.38) * PROP_SCALE], [Vector3(0, 0.36, 0) * PROP_SCALE, Vector3(0.2, 0.62, 0.2) * PROP_SCALE]])
	mmi.set("prop_mass", 6.0)
	mmi.set("push_speed", 1.5)
	mmi.set("release_radius", 3.2)
	mmi.set("centre_of_mass_y", 0.06)
	mmi.multimesh = mm
	node.add_child(mmi)


## Double tyre stack draped with a black-and-white chequered banner + two orange/white barrels.
func _chequered_tyres_and_barrels(kit: Dictionary) -> void:
	var k := _kit
	for sx in [-0.34, 0.34]:
		for t in range(3):
			k.tyre(kit, "rubber", Vector3(sx, 0.1 + t * 0.2, 0.0), 0.19, 0.31, 0.2, 14, Color(0.08, 0.08, 0.09))
	# Chequered cloth draped over top & front of the double stack
	var cw := Color(0.95, 0.95, 0.92)
	var cb := Color(0.10, 0.10, 0.12)
	for ix in range(4):
		for iz in range(2):
			var col := cw if (ix + iz) % 2 == 0 else cb
			var x0 := -0.52 + ix * 0.26
			var x1 := x0 + 0.26
			var z0 := -0.26 + iz * 0.26
			var z1 := z0 + 0.26
			k.quad(kit, "canvas", [Vector3(x0, 0.61, z0), Vector3(x1, 0.61, z0), Vector3(x1, 0.61, z1), Vector3(x0, 0.61, z1)], Vector3.UP, col)
			var y_top := 0.61 - iz * 0.22
			var y_bot := y_top - 0.22
			k.quad(kit, "canvas", [Vector3(x0, y_bot, -0.32), Vector3(x1, y_bot, -0.32), Vector3(x1, y_top, -0.32), Vector3(x0, y_top, -0.32)], Vector3.FORWARD, col)
	# Two orange & white plastic crash barrels beside the stack
	var orange := Color(0.96, 0.34, 0.06)
	for bx in [0.92, 1.42]:
		var bz := 0.12 if bx > 1.1 else -0.05
		var prof := [
			[0.0, 0.22, orange], [0.22, 0.23, orange],
			[0.23, 0.23, WHITE], [0.42, 0.23, WHITE],
			[0.43, 0.22, orange], [0.64, 0.21, orange],
		]
		for i in range(prof.size() - 1):
			var a: Array = prof[i]
			var b: Array = prof[i + 1]
			k.lathe(kit, "plastic", Vector3(bx, 0, bz), [Vector2(float(a[1]), float(a[0])), Vector2(float(b[1]), float(b[0]))], 12, a[2])
		k.lathe(kit, "plastic", Vector3(bx, 0.64, bz), [Vector2(0.21, 0.0), Vector2(0.0, 0.01)], 12, Color(0.14, 0.14, 0.15))


## Slatted timber rockfall / snow barrier fence seen on the upper mountain cuts in Concept Art 2.
func _rockfall_fence(kit: Dictionary) -> void:
	var k := _kit
	var wood := Color(0.46, 0.33, 0.20)
	for x in [-1.1, 0.0, 1.1]:
		k.beam(kit, "wood", Vector3(x, -0.3, 0.05), Vector3(x, 1.15, -0.22), 0.09, 0.09, wood)
		k.beam(kit, "wood", Vector3(x, -0.3, 0.55), Vector3(x, 0.95, -0.15), 0.08, 0.08, wood.darkened(0.08))
	for r in range(4):
		var t := float(r) / 3.0
		var y := lerpf(0.22, 1.05, t)
		var z := lerpf(0.0, -0.20, t) - 0.05
		k.beam(kit, "wood", Vector3(-1.45, y, z), Vector3(1.45, y, z), 0.12, 0.04, wood.lightened(0.04 * (r % 2)), Vector3(0, 0.2, -1).normalized())


# ======================================================================================
#  5. Chevron Turn Boards & Lap Towers
# ======================================================================================

func _build_chevrons(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Chevrons"
	root.add_child(node)

	var kit := {}
	var boxes: Array = []

	var d_sb1 := _d_at_point(P_SB1)
	var d_sb2 := _d_at_point(P_SB2)
	var d_sb3 := _d_at_point(P_SB3)
	var d_sum_w := _d_at_point(P_SUMMIT_W)
	var d_sb4 := _d_at_point(P_SB4)
	var d_sb5 := _d_at_point(P_SB5)
	var d_vse := _d_at_point(P_VALLEY_SE)
	var d_vsw := _d_at_point(P_VALLEY_SW)

	# [d_start, d_end, count, lat_offset, point_dir (+1 right, -1 left)]
	var banks := [
		[d_sb1 - 18.0, d_sb1 + 18.0, 5, VERGE + 1.85, -1.0],
		[d_sb2 - 18.0, d_sb2 + 18.0, 5, -(VERGE + 1.85), 1.0],
		[d_sb3 - 18.0, d_sb3 + 18.0, 5, VERGE + 1.85, -1.0],
		[d_sum_w - 16.0, d_sum_w + 16.0, 4, -(VERGE + 1.85), 1.0],
		[d_sb4 - 16.0, d_sb4 + 18.0, 4, -(VERGE + 1.85), 1.0],
		[d_sb5 - 16.0, d_sb5 + 16.0, 4, VERGE + 1.85, -1.0],
		[d_vse - 18.0, d_vse + 18.0, 4, -(VERGE + 1.95), 1.0],
		[d_vsw - 18.0, d_vsw + 18.0, 4, VERGE + 1.95, -1.0],
	]
	for b in banks:
		var s0: float = b[0]
		var s1: float = b[1]
		var cnt: int = b[2]
		var lat: float = b[3]
		var pdir: float = b[4]
		for i in range(cnt):
			var s := lerpf(s0, s1, float(i) / float(maxi(cnt - 1, 1)))
			var fr := _frame(s)
			var at := _at(s, lat)
			if _road_distance(at.x, at.z) - 0.8 * PROP_SCALE - ROAD_HALF < 0.6:
				continue
			var aim: Vector3 = -(fr["fwd"] as Vector3) - (fr["right"] as Vector3) * signf(lat) * 0.45
			var yaw := _yaw_to(aim.normalized())
			_kit.set_frame(_place(at, yaw))
			_chevron_board(kit, pdir)
			boxes.append([at + Vector3(0, 0.65 * PROP_SCALE, 0), Vector3(1.5, 1.3, 0.2) * PROP_SCALE, Basis(Vector3.UP, yaw)])
			_note("Chevron", at, 0.8 * PROP_SCALE, 1.2)

	_commit(node, kit, "ChevronSigns")
	_boxes_body(node, "ChevronSignsBody", boxes)


func _chevron_board(kit: Dictionary, dir: float) -> void:
	var k := _kit
	var red := Color(0.86, 0.12, 0.10)
	var hw := 0.72
	var y0 := 0.45
	var y1 := 1.15
	for sx in [-0.52, 0.52]:
		k.tube(kit, "metal", Vector3(sx, -0.35, 0.04), Vector3(sx, y1, 0.04), 0.025, 0.025, 6, GALV)
	k.block(kit, "steel", Vector3(-hw, y0, 0.0), Vector3(hw, y1, 0.025), Color(0.16, 0.17, 0.19))
	# Red & white chevron stripes on the front (-z)
	var n_stripes := 4
	for i in range(n_stripes):
		var col := red if i % 2 == 0 else WHITE
		var x0 := lerpf(-hw + 0.03, hw - 0.03, float(i) / float(n_stripes))
		var x1 := lerpf(-hw + 0.03, hw - 0.03, float(i + 1) / float(n_stripes))
		k.quad(kit, "paint", [Vector3(x0, y0 + 0.03, -0.005), Vector3(x1, y0 + 0.03, -0.005),
				Vector3(x1, y1 - 0.03, -0.005), Vector3(x0, y1 - 0.03, -0.005)], Vector3.FORWARD, col)


func _build_lap_towers(root: Node3D) -> void:
	var spots := [
		[72.0, 11.2, "LapTowerStart"],
		[_d_at_point(P_SUMMIT_CREST) - 12.0, -11.2, "LapTowerSummit"],
	]
	for sp in spots:
		var s: float = sp[0]
		var lat: float = sp[1]
		var fr := _frame(s)
		var at := _at(s, lat)
		at.y = _ground_min(at.x, at.z, 1.2)
		var yaw := _yaw_to(-(fr["fwd"] as Vector3))
		var node := Node3D.new()
		node.name = String(sp[2])
		node.set_script(load("res://LapBoard.gd"))
		var xf := _place(at, yaw)
		node.transform = Transform3D(Basis(Vector3.UP, yaw), at)
		root.add_child(node)
		var kit := {}
		_kit.set_frame(Transform3D(Basis().scaled(Vector3.ONE * PROP_SCALE), Vector3.ZERO))
		var tops := _lap_tower(kit)
		_commit(node, kit, "Tower")
		var brand := Label3D.new()
		brand.name = "Brand"
		brand.text = "PINECREST GP"
		brand.font = _bold_font()
		brand.font_size = 64
		brand.pixel_size = 0.0068
		brand.outline_size = 0
		brand.shaded = false
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
		lap.modulate = Color(1.0, 0.72, 0.16)
		lap.transform = Transform3D(Basis(Vector3.UP, PI), (tops[1] as Vector3) * PROP_SCALE)
		node.add_child(lap)
		node.set("label_path", NodePath("Lap"))
		var boxes: Array = []
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				boxes.append([xf * Vector3(sx * 0.6, 0.0, sz * 0.6) + Vector3(0, 2.9, 0), Vector3(0.16, 5.8, 0.16), Basis(Vector3.UP, yaw)])
		_boxes_body(root, String(sp[2]) + "Body", boxes)
		_note(String(sp[2]), at, 1.0 * PROP_SCALE, 1.5)


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
	var y0 := h
	var y1 := h + 1.95
	var hw := 1.3
	k.block(kit, "steel", Vector3(-hw, y0, -0.2), Vector3(hw, y1, 0.2), Color(0.18, 0.19, 0.21))
	var forest_hdr := Color(0.06, 0.24, 0.14)
	k.block(kit, "paint", Vector3(-hw + 0.08, y0 + 0.95, -0.215), Vector3(hw - 0.08, y1 - 0.08, -0.2), forest_hdr)
	k.block(kit, "paint", Vector3(-hw + 0.08, y0 + 0.08, -0.215), Vector3(hw - 0.08, y0 + 0.88, -0.2), Color(0.02, 0.02, 0.025))
	k.block(kit, "steel", Vector3(-hw - 0.05, y1, -0.25), Vector3(hw + 0.05, y1 + 0.06, 0.25), Color(0.14, 0.14, 0.15))
	return [Vector3(0, y0 + 1.42, -0.225), Vector3(0, y0 + 0.47, -0.225)]


# ======================================================================================
#  6. Valley Paddock & Spectator Overlook Camps (Concept Art 1 & 2)
# ======================================================================================

const CANOPIES := [
	Color(0.80, 0.11, 0.09), Color(0.10, 0.28, 0.66),
	Color(0.12, 0.45, 0.22), Color(0.95, 0.62, 0.08),
	Color(0.93, 0.93, 0.91), Color(0.80, 0.11, 0.09),
]

func _build_paddock(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Paddock"
	root.add_child(node)
	var kit := {}
	var clutter := {}
	var boxes: Array = []

	# Row of 5 team gazebos with work tables, chairs, coolers & motorhomes behind them on West Paddock
	var n := 5
	for i in range(n):
		var s: float = 12.0 + 52.0 * float(i) / float(n - 1)
		var lat: float = -22.5 - (1.4 if i % 2 == 1 else 0.0)
		var fr := _frame(s)
		var at := _at(s, lat)
		var yaw := _yaw_to((fr["right"] as Vector3))
		var canopy: Color = CANOPIES[i % CANOPIES.size()]
		_kit.set_frame(_place(at, yaw))
		_camp.gazebo(kit, canopy, i % 2 == 0)
		_kit.set_frame(_place(at, yaw) * Transform3D(Basis(), Vector3(0, 0, 0.35)))
		_camp.folding_table(clutter, WHITE)
		for c in range(2):
			_kit.set_frame(_place(at, yaw) * Transform3D(Basis(Vector3.UP, PI + (c - 0.5) * 0.6), Vector3(-0.55 + c * 1.1, 0, -0.55)))
			_camp.camp_chair(clutter, CampKit.CHAIR_COLS[(i + c) % CampKit.CHAIR_COLS.size()])
		_kit.set_frame(_place(at, yaw) * Transform3D(Basis(Vector3.UP, 0.25), Vector3(1.15, 0, 0.65)))
		_camp.cooler(clutter, canopy, WHITE)
		_note("PaddockGazebo%d" % i, at, 2.4 * PROP_SCALE, 6.0)
		for sx in [-1.47, 1.47]:
			for sz in [-1.47, 1.47]:
				var leg := Transform3D(Basis(Vector3.UP, yaw), at) * Vector3(sx * PROP_SCALE, 1.6, sz * PROP_SCALE)
				boxes.append([leg, Vector3(0.12, 3.2, 0.12), Basis(Vector3.UP, yaw)])

	# Team motorhomes & vans parked behind the pit gazebos
	var vehicles := [
		["motorhome", 18.0, -34.5, WHITE, 0],
		["caravan", 32.0, -34.0, Color(0.96, 0.95, 0.90), 0],
		["motorhome", 48.0, -34.5, Color(0.95, 0.93, 0.87), 1],
		["van", 62.0, -33.5, Color(0.94, 0.95, 0.93), 0],
	]
	for v in vehicles:
		var s_v: float = v[1]
		var lat_v: float = v[2]
		var fr := _frame(s_v)
		var at := _at(s_v, lat_v)
		var yaw := _yaw_to((fr["right"] as Vector3))
		_kit.set_frame(_place(at, yaw))
		var sz_v: Vector3 = _camp.vehicle(kit, String(v[0]), v[3], int(v[4]))
		boxes.append([at + Vector3(0, sz_v.y * 0.5 * PROP_SCALE, 0), Vector3(sz_v.z, sz_v.y, sz_v.x) * PROP_SCALE, Basis(Vector3.UP, yaw)])
		_note("PaddockVeh", at, sz_v.x * 0.5 * PROP_SCALE, 10.0)

	_commit(node, kit, "PaddockVehiclesAndTents")
	_commit(node, clutter, "PaddockGear", 240.0)
	_boxes_body(node, "PaddockBody", boxes)


func _build_campsites(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Campsites"
	root.add_child(node)
	var kit := {}
	var gear := {}
	var boxes: Array = []

	# 1. West Turn-1 Meadow Spectator Camp (LAYOUT_MAIN)
	# 2. Switchback 1 Mountain Overlook Camp (LAYOUT_VILLAGE - Concept Art 1 & 2!)
	for t in [
		[MEADOW_CAMP, CampKit.LAYOUT_MAIN, "meadow camp"],
		[SWITCHBACK_CAMP, CampKit.LAYOUT_VILLAGE, "switchback overlook camp"],
	]:
		var terrace: Array = t[0]
		var res: Dictionary = _camp.build_layout(kit, gear, t[1], terrace[0], float(terrace[2]), _ground, PROP_SCALE)
		boxes.append_array(res["boxes"])
		for n in res["notes"]:
			_note(String(n[0]), n[1], float(n[2]), 5.0)
		print("  camp %s: %d pitches" % [t[2], (res["placed"] as Array).size()])

	_commit(node, kit, "CampVehiclesAndTents")
	_commit(node, gear, "CampGear", 240.0)
	_boxes_body(node, "CampsitesBody", boxes)


# ======================================================================================
#  7. Granite Cliff-Cut Outcrops, Exposed Root Banks & Alpine Boulders
# ======================================================================================

func _build_boulders(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Boulders"
	root.add_child(node)

	var mat := ShaderMaterial.new()
	mat.shader = load("res://granite_rock.gdshader")
	mat.set_shader_parameter("dust_color", Color(0.28, 0.36, 0.18))
	mat = _save_res(mat, "mat_granite")

	var meshes: Array = []
	var hulls: Array = []
	var shapes := [
		Vector3(1.0, 0.75, 0.9),
		Vector3(1.45, 0.62, 1.05),
		Vector3(0.85, 1.0, 0.8),
		Vector3(1.3, 0.85, 1.15),
	]
	for v in range(shapes.size()):
		var res := _rock_mesh(v, shapes[v], mat)
		meshes.append(_save_res(res[0], "boulder_%d" % v))
		hulls.append(res[1])

	# Exposed pine root tangle mesh for steep cut-banks (Concept Art 1 & 2)
	var wb := Woodland.new()
	wb.save_res = _save_res
	var root_bark_mat: ShaderMaterial = _save_res(wb.bark_material("pine", 0), "bark_root_tangle")
	var root_mesh: ArrayMesh = _save_res(_root_tangle_mesh(root_bark_mat), "root_tangle_mesh")
	var root_xforms: Array = []

	var cells := {}
	var solid: Array = []
	var count := [0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 24680

	var place_boulder := func(px: float, pz: float, sc: float, v: int, pitch_max := 0.25) -> void:
		var gy: float = _ground_min(px, pz, sc * 0.85)
		var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, pitch_max))
		var pos := Vector3(px, gy - sc * 0.22, pz)
		var xf := Transform3D(basis.scaled(Vector3.ONE * sc), pos)
		_add_to_cells(cells, _cell(px, pz, 180.0, v), xf)
		count[0] += 1
		if _road_distance(px, pz) < 32.0 and sc >= 1.1:
			solid.append([Transform3D(basis, pos), v, sc])

	var d_j1_l := _d_at_point(P_JUMP1_LAND)
	var d_sb1 := _d_at_point(P_SB1)
	var d_sb2 := _d_at_point(P_SB2)
	var d_sb3 := _d_at_point(P_SB3)
	var d_sum_w := _d_at_point(P_SUMMIT_W)
	var d_sum_c := _d_at_point(P_SUMMIT_CREST)
	var d_sb4 := _d_at_point(P_SB4)
	var d_sb5 := _d_at_point(P_SB5)
	var d_j3_t := _d_at_point(P_JUMP3_TAKEOFF)

	# 1. Stratified cliff-cut outcrops & exposed pine roots along steep inside mountain switchback banks
	var cut_banks := [
		[d_j1_l + 14.0, d_sb1 - 16.0, -1.0],
		[d_sb1 + 16.0, d_sb2 - 16.0, 1.0],
		[d_sb2 + 16.0, d_sb3 - 16.0, -1.0],
		[d_sb3 + 16.0, d_sum_w - 16.0, 1.0],
		[d_sum_w + 18.0, d_sum_c + 24.0, -1.0],
		[d_sb4 + 14.0, d_sb5 - 14.0, 1.0],
		[d_sb5 + 16.0, d_j3_t - 18.0, -1.0],
	]
	for cb in cut_banks:
		var d := float(cb[0])
		var d_end := float(cb[1])
		var side := float(cb[2])
		while d <= d_end:
			if not _in_jump_zone(d, 8.0):
				var fr := _frame(d)
				var rp: Vector3 = fr["pos"]
				var right: Vector3 = fr["right"]
				var lat: float = side * (VERGE + rng.randf_range(3.6, 6.8))
				var p: Vector3 = rp + right * lat
				var sc: float = rng.randf_range(2.2, 3.8)
				place_boulder.call(p.x, p.z, sc, 1 + (rng.randi() % 3), 0.18)
				for m in range(2):
					var mp: Vector3 = p + (fr["fwd"] as Vector3) * rng.randf_range(-3.0, 3.0) - right * (side * rng.randf_range(1.2, 2.2))
					if _road_distance(mp.x, mp.z) >= VERGE + 2.2:
						place_boulder.call(mp.x, mp.z, rng.randf_range(0.9, 1.7), rng.randi() % 4, 0.25)
				if rng.randf() < 0.75:
					var gy: float = _ground(p.x, p.z)
					var ryaw := _yaw_to(-right * side) + rng.randf_range(-0.3, 0.3)
					var rsc := rng.randf_range(1.1, 1.65)
					root_xforms.append(Transform3D(Basis(Vector3.UP, ryaw).scaled(Vector3.ONE * rsc), Vector3(p.x, gy + sc * 0.35, p.z)))
			d += rng.randf_range(11.0, 16.0)

	# 2. Meadow & lakeside boulder clusters
	var keep_out := _woodland_keep_out()
	var step := 36.0
	var x := -380.0
	while x <= 380.0:
		var z := -380.0
		while z <= 380.0:
			var cx: float = x + rng.randf_range(-0.45, 0.45) * step
			var cz: float = z + rng.randf_range(-0.45, 0.45) * step
			z += step
			var g := _ground(cx, cz)
			var ldist := Vector2(cx, cz).distance_to(LAKE_CENTER) - LAKE_RADIUS
			var shore: bool = absf(ldist) < 18.0 and g > WATER_Y - 0.5
			if rng.randf() > (0.55 if shore else 0.16) or g < WATER_Y - 0.4:
				continue
			if _slope(cx, cz) > 0.72 or _road_distance(cx, cz) < VERGE + 4.5 or _kept_out(keep_out, cx, cz, 3.5):
				continue
			var n: int = rng.randi_range(2, 4)
			for k in range(n):
				var px: float = cx + rng.randf_range(-3.5, 3.5)
				var pz: float = cz + rng.randf_range(-3.5, 3.5)
				if _road_distance(px, pz) < VERGE + 3.5:
					continue
				var sc: float = rng.randf_range(0.8, 2.2) * (1.0 if k == 0 else rng.randf_range(0.45, 0.85))
				place_boulder.call(px, pz, sc, rng.randi() % shapes.size(), 0.25)
		x += step

	for k in cells.keys():
		var mmi := _multimesh(meshes[k.z], cells[k], "Boulders_%d_%d_%d" % [k.x, k.y, k.z])
		mmi.visibility_range_end = 420.0
		mmi.visibility_range_end_margin = 20.0
		node.add_child(mmi)

	if not root_xforms.is_empty():
		var mmi_r := _multimesh(root_mesh, root_xforms, "ExposedPineRoots")
		mmi_r.visibility_range_end = 220.0
		mmi_r.visibility_range_end_margin = 20.0
		node.add_child(mmi_r)

	var body := StaticBody3D.new()
	body.name = "BouldersBody"
	node.add_child(body)
	for sv in solid:
		var cs := CollisionShape3D.new()
		var shape := ConvexPolygonShape3D.new()
		var hp := PackedVector3Array()
		for q in (hulls[sv[1]] as PackedVector3Array):
			hp.append(q * float(sv[2]))
		shape.points = hp
		cs.shape = shape
		cs.transform = sv[0]
		body.add_child(cs)
	print("  boulders: %d in %d cells, %d solid, %d root overhangs" % [count[0], cells.size(), solid.size(), root_xforms.size()])


func _rock_mesh(variant: int, size: Vector3, mat: Material) -> Array:
	var noise := FastNoiseLite.new()
	noise.seed = 300 + variant * 17
	noise.frequency = 0.8
	var t := (1.0 + sqrt(5.0)) / 2.0
	var verts: Array = [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1),
	]
	var faces: Array = [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4],
		[11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
	]
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


func _root_tangle_mesh(bark_mat: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7741
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bi := 0
	var col := Color(0.58, 0.48, 0.40)
	for r in range(6):
		var a: float = lerpf(-1.2, 1.2, float(r) / 5.0) + rng.randf_range(-0.15, 0.15)
		var p0 := Vector3(rng.randf_range(-0.4, 0.4), 0.45, rng.randf_range(-0.2, 0.2))
		var p1 := p0 + Vector3(sin(a) * 0.85, -0.35 + rng.randf_range(-0.15, 0.15), cos(a) * 0.65)
		var p2 := p1 + Vector3(sin(a + 0.3) * 1.05, -0.75, cos(a - 0.2) * 0.85)
		var p3 := p2 + Vector3(rng.randf_range(-0.35, 0.35), -0.65, rng.randf_range(-0.35, 0.35))
		bi = Woodland.bark_tube(st, bi, [p0, p1, p2, p3], [0.13, 0.09, 0.055, 0.022], 5, col, 0.32, Vector2(-1.5, 1.0))
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, bark_mat)
	return mesh


# ======================================================================================
#  8. Procedural Alpine Woodland, Shrubs, Ferns, Wildflowers & Deadwood Logs
# ======================================================================================

const FOREST_CELL := 100.0
const FAR_CELL := 240.0
const TRUNK_COLLIDE_REACH := 38.0
const TREE_ROAD_CLEAR := {
	"pine": 14.5,
	"fir": 13.5,
	"larch": 14.0,
	"birch": 13.0,
	"alder": 14.0,
}
const KINDS := ["pine", "fir", "larch", "birch", "alder"]

func _build_woodland(root: Node3D) -> void:
	var t0 := Time.get_ticks_msec()
	var node := Node3D.new()
	node.name = "Woodland"
	root.add_child(node)

	var w := Woodland.new()
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
			match kind:
				"pine":
					nm = w.pine_mesh(v, 0, bn, leaf_near)
					fm = w.pine_mesh(v, 1, bf, leaf_far)
				"fir":
					nm = w.fir_mesh(v, 0, bn, leaf_near)
					fm = w.fir_mesh(v, 1, bf, leaf_far)
				"larch":
					nm = w.larch_mesh(v, 0, bn, leaf_near)
					fm = w.larch_mesh(v, 1, bf, leaf_far)
				_:
					nm = w.broadleaf_mesh(kind, v, 0, bn, leaf_near)
					fm = w.broadleaf_mesh(kind, v, 1, bf, leaf_far)
			near_meshes.append(_save_res(nm, "tree_%s_%d" % [kind, v]))
			far_meshes.append(_save_res(fm, "tree_%s_%d_far" % [kind, v]))

	# Understory & GroundCover plant meshes (`Plants_*` and `GroundCover_*`):
	#   0, 1: Dwarf mountain pine / alpine juniper shrub (WoodlandBuilder.alpine_shrub_mesh)
	#   2: Hazel bush (WoodlandBuilder.shrub_mesh)
	#   3, 4: Alpine fern rosettes (_fern_mesh)
	#   5, 6: Fallen deadwood pine logs (_deadwood_log_mesh)
	#   7: Golden yellow wildflower patch (_wildflower_patch_mesh 0)
	#   8: Meadow daisy white wildflower patch (_wildflower_patch_mesh 1)
	#   9: Alpine gentian/lupine blue wildflower patch (_wildflower_patch_mesh 2)
	#   10: Lush alpine meadow grass tuft (_grass_tuft_mesh)
	var shrub_bark: ShaderMaterial = _save_res(w.bark_material("pine", 0), "bark_alpine_shrub")
	var hazel_bark: ShaderMaterial = _save_res(w.bark_material("hazel", 0), "bark_hazel")
	var shrub_leaf: ShaderMaterial = _save_res(w.leaf_material(0, 0.10, 3.5), "leaf_shrub")

	var flower_mat := StandardMaterial3D.new()
	flower_mat.vertex_color_use_as_albedo = true
	flower_mat.vertex_color_is_srgb = true
	flower_mat.roughness = 0.72
	flower_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var saved_flower_mat: Material = _save_res(flower_mat, "mat_wildflower")

	var grass_mat := ShaderMaterial.new()
	grass_mat.shader = load("res://dune_grass.gdshader")
	grass_mat.set_shader_parameter("sway", 0.12)
	grass_mat.set_shader_parameter("speed", 1.4)
	var saved_grass_mat: Material = _save_res(grass_mat, "mat_tuft_grass")

	var plant_meshes: Array = [
		_save_res(w.alpine_shrub_mesh(0, shrub_bark, shrub_leaf), "plant_alpine_shrub_0"),
		_save_res(w.alpine_shrub_mesh(1, shrub_bark, shrub_leaf), "plant_alpine_shrub_1"),
		_save_res(w.shrub_mesh(0, hazel_bark, shrub_leaf), "plant_hazel_0"),
		_save_res(_fern_mesh(0, shrub_leaf), "plant_fern_0"),
		_save_res(_fern_mesh(1, shrub_leaf), "plant_fern_1"),
		_save_res(_deadwood_log_mesh(0, shrub_bark), "plant_deadwood_0"),
		_save_res(_deadwood_log_mesh(1, shrub_bark), "plant_deadwood_1"),
		_save_res(_wildflower_patch_mesh(0, saved_flower_mat), "plant_wildflower_yellow"),
		_save_res(_wildflower_patch_mesh(1, saved_flower_mat), "plant_wildflower_white"),
		_save_res(_wildflower_patch_mesh(2, saved_flower_mat), "plant_wildflower_blue"),
		_save_res(_grass_tuft_mesh(saved_grass_mat), "plant_grass_tuft"),
	]
	print("  alpine tree & plant meshes built (%.1fs)" % ((Time.get_ticks_msec() - t0) / 1000.0))

	var forest := FastNoiseLite.new()
	forest.seed = 4815
	forest.frequency = 0.005
	forest.fractal_octaves = 3
	var kind_noise := FastNoiseLite.new()
	kind_noise.seed = 1623
	kind_noise.frequency = 0.012
	kind_noise.fractal_type = FastNoiseLite.FRACTAL_NONE

	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var keep_out := _woodland_keep_out()

	var near := {}
	var far := {}
	var deep_near := {}
	var deep_far := {}
	var plants := {}
	var cover := {}
	var trunks: Array = []
	var counts := {"pine": 0, "fir": 0, "larch": 0, "birch": 0, "alder": 0, "deep": 0, "plants": 0, "cover": 0}

	var step := 10.5
	var r_max := 440.0
	var x := -r_max
	while x <= r_max:
		var z := -r_max
		while z <= r_max:
			var px: float = x + rng.randf_range(-0.45, 0.45) * step
			var pz: float = z + rng.randf_range(-0.45, 0.45) * step
			z += step
			var roll := rng.randf()
			var g := _ground(px, pz)
			var ldist := Vector2(px, pz).distance_to(LAKE_CENTER) - LAKE_RADIUS
			if g < WATER_Y + 0.5 or ldist < 3.0:
				continue

			var f: float = forest.get_noise_2d(px, pz) + clampf((g - 8.0) * 0.010, -0.08, 0.18)
			var dens: float = lerpf(0.06, 0.88, smoothstep(-0.08, 0.26, f))
			if roll > dens:
				if roll < dens + 0.14 and _slope(px, pz) < 0.72 and _road_distance(px, pz) > 11.5 and not _kept_out(keep_out, px, pz, 2.0):
					var sc_s: float = rng.randf_range(0.75, 1.25)
					var xf_s := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc_s),
							Vector3(px, g - 0.12 - minf(_relief(px, pz, 1.8) * 0.6, 0.6), pz))
					var sk := 2 if (g < 14.0 and rng.randf() < 0.45) else (rng.randi() % 2)
					_add_to_cells(plants, _cell(px, pz, FOREST_CELL, sk), xf_s)
					counts["plants"] += 1
				continue
			if _slope(px, pz) > 0.78:
				continue

			# Pick alpine tree species by elevation, lake proximity, and noise:
			var kn: float = kind_noise.get_noise_2d(px, pz)
			var kind := "pine"
			if ldist < 28.0 and g < 8.0:
				if rng.randf() < 0.52:
					kind = "alder"
				elif rng.randf() < 0.82:
					kind = "birch"
				else:
					kind = "pine"
			elif g < 16.0:
				if kn < -0.22:
					kind = "birch"
				elif kn < 0.02 and rng.randf() < 0.45:
					kind = "alder"
				elif kn > 0.28:
					kind = "larch"
				elif rng.randf() < 0.35:
					kind = "fir"
				else:
					kind = "pine"
			elif g < 54.0:
				# Mid-mountain switchbacks: Scots pine dominant + silver fir + golden-green larch
				if kn > 0.24:
					kind = "larch"
				elif kn < -0.14:
					kind = "fir"
				else:
					kind = "pine"
			else:
				# High summit ridge: Scots pine & subalpine silver fir + larch
				if kn > 0.30:
					kind = "larch"
				elif kn < 0.0:
					kind = "fir"
				else:
					kind = "pine"

			var rd := _road_distance(px, pz)
			if rd < float(TREE_ROAD_CLEAR[kind]) or _kept_out(keep_out, px, pz, 3.5):
				continue

			var ki: int = KINDS.find(kind)
			var v: int = rng.randi() % 2
			var mi: int = ki * 2 + v
			var sc: float = rng.randf_range(0.84, 1.18)
			var y: float = g - 0.22 - minf(_relief(px, pz, 2.5) * 0.6, 1.0)
			var lean := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.04))
			var xf := Transform3D(lean * Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.92, 1.08), sc)), Vector3(px, y, pz))

			var deep: bool = rd > 125.0 and ldist > 45.0 and rng.randf() < 0.65
			if deep:
				_add_to_cells(deep_near, _cell(px, pz, FOREST_CELL, mi), xf)
				_add_to_cells(deep_far, _cell(px, pz, FAR_CELL, mi), xf)
				counts["deep"] += 1
			else:
				_add_to_cells(near, _cell(px, pz, FOREST_CELL, mi), xf)
				_add_to_cells(far, _cell(px, pz, FAR_CELL, mi), xf)
			counts[kind] += 1

			if rd < TRUNK_COLLIDE_REACH:
				var tr: float = (0.42 if kind == "pine" else (0.38 if kind == "fir" else (0.34 if kind == "larch" else (0.22 if kind == "birch" else 0.28)))) * sc
				trunks.append([Vector3(px, y, pz), maxf(tr * 1.2, 0.32), 5.0 * sc])

			# Understory ferns & fallen deadwood logs around near trees
			if not deep and rd < 85.0:
				if rng.randf() < 0.65:
					for f_i in range(rng.randi_range(1, 3)):
						var fa := rng.randf() * TAU
						var fd := rng.randf_range(1.4, 3.8)
						var fx := px + cos(fa) * fd
						var fz := pz + sin(fa) * fd
						if _road_distance(fx, fz) > VERGE + 1.8 and not _kept_out(keep_out, fx, fz, 1.0):
							var fy := _ground(fx, fz)
							var fsc := rng.randf_range(0.85, 1.45)
							var fxf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * fsc), Vector3(fx, fy - 0.05, fz))
							_add_to_cells(plants, _cell(fx, fz, FOREST_CELL, 3 + (rng.randi() % 2)), fxf)
							counts["plants"] += 1
				if rng.randf() < 0.16:
					var la := rng.randf() * TAU
					var ld := rng.randf_range(2.8, 5.5)
					var lx := px + cos(la) * ld
					var lz := pz + sin(la) * ld
					if _road_distance(lx, lz) > VERGE + 4.0 and not _kept_out(keep_out, lx, lz, 2.0):
						var ly := _ground(lx, lz)
						var lnrm := _ground_normal(lx, lz)
						var lyaw := rng.randf() * TAU
						var lfwd := Vector3(sin(lyaw), 0.0, cos(lyaw))
						lfwd = (lfwd - lnrm * lfwd.dot(lnrm)).normalized()
						var lright := lfwd.cross(lnrm).normalized()
						var lsc := rng.randf_range(0.80, 1.25)
						var lxf := Transform3D(Basis(lright, lnrm, lfwd).scaled(Vector3.ONE * lsc), Vector3(lx, ly - 0.08, lz))
						_add_to_cells(plants, _cell(lx, lz, FOREST_CELL, 5 + (rng.randi() % 2)), lxf)
						counts["plants"] += 1
		x += step

	# Walk along the 1650m track to dress the road shoulders, cut banks & meadows with ferns,
	# yellow/white/blue wildflower drifts, and meadow grass tufts (Concept Art 1 & 2).
	var s_walk := 0.0
	while s_walk < _length:
		var fr := _frame(s_walk)
		var rp: Vector3 = fr["pos"]
		var fwd: Vector3 = fr["fwd"]
		var right: Vector3 = fr["right"]
		var in_jmp := _in_jump_zone(s_walk, 3.0)

		for side in [-1.0, 1.0]:
			# 1. Ferns along steep mountain cut banks
			if rp.y > 8.0 and not in_jmp and rng.randf() < 0.78:
				for k in range(2):
					var off_f: float = VERGE + rng.randf_range(1.6, 10.5)
					var fp: Vector3 = rp + right * (side * off_f) + fwd * rng.randf_range(-2.0, 2.0)
					if _road_distance(fp.x, fp.z) < VERGE + 1.3 or _kept_out(keep_out, fp.x, fp.z, 1.0):
						continue
					var fy := _ground(fp.x, fp.z)
					var fsc := rng.randf_range(0.88, 1.50)
					var fxf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * fsc), Vector3(fp.x, fy - 0.05, fp.z))
					_add_to_cells(plants, _cell(fp.x, fp.z, FOREST_CELL, 3 + (rng.randi() % 2)), fxf)
					counts["plants"] += 1

			# 2. Wildflower patches (yellow, white, blue) & grass tufts along shoulders & meadows
			var n_patches := 3 if rp.y < 32.0 else 2
			for p_i in range(n_patches):
				var off_w: float = VERGE + rng.randf_range(1.3, 28.0)
				var wp: Vector3 = rp + right * (side * off_w) + fwd * rng.randf_range(-2.2, 2.2)
				if _road_distance(wp.x, wp.z) < VERGE + 1.1 or _kept_out(keep_out, wp.x, wp.z, 1.0):
					continue
				var wy := _ground(wp.x, wp.z)
				if wy < WATER_Y + 0.6:
					continue
				var wnrm := _ground_normal(wp.x, wp.z)
				if wnrm.y < 0.68:
					continue
				var wyaw := rng.randf() * TAU
				var wfwd := Vector3(sin(wyaw), 0.0, cos(wyaw))
				wfwd = (wfwd - wnrm * wfwd.dot(wnrm)).normalized()
				var wright := wfwd.cross(wnrm).normalized()

				var wave: float = sin(wp.x * 0.045) + cos(wp.z * 0.045)
				var f_idx := 7 # Yellow arnica/buttercup
				if wave > 0.35:
					f_idx = 8 # White meadow daisy
				elif wave < -0.85:
					f_idx = 9 # Blue alpine lupine/gentian

				var wsc := rng.randf_range(0.88, 1.38)
				var wxf := Transform3D(Basis(wright, wnrm, wfwd).scaled(Vector3.ONE * wsc), Vector3(wp.x, wy, wp.z))
				if p_i == 0:
					_add_to_cells(plants, _cell(wp.x, wp.z, FOREST_CELL, f_idx), wxf)
					counts["plants"] += 1
				else:
					_add_to_cells(cover, _cell(wp.x, wp.z, FOREST_CELL, f_idx), wxf)
					counts["cover"] += 1

				# Companion meadow grass tuft
				var tsc := rng.randf_range(0.85, 1.35)
				var txf := Transform3D(Basis(wright, wnrm, wfwd).scaled(Vector3.ONE * tsc),
						Vector3(wp.x + rng.randf_range(-0.8, 0.8), wy, wp.z + rng.randf_range(-0.8, 0.8)))
				if p_i == 0:
					_add_to_cells(plants, _cell(wp.x, wp.z, FOREST_CELL, 10), txf)
					counts["plants"] += 1
				else:
					_add_to_cells(cover, _cell(wp.x, wp.z, FOREST_CELL, 10), txf)
					counts["cover"] += 1
		s_walk += 4.2

	print("  woodland counts: %s (%.1fs)" % [str(counts), (Time.get_ticks_msec() - t0) / 1000.0])

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
		var mmi5 := _multimesh(plant_meshes[k.z], plants[k], "Plants_%d_%d_%d" % [k.x, k.y, k.z])
		mmi5.visibility_range_end = 150.0 + FOREST_CELL * 0.72
		mmi5.visibility_range_end_margin = 10.0
		mmi5.set_meta(&"base_range", mmi5.visibility_range_end)
		mmi5.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mmi5)

	for k in cover.keys():
		var mmi6 := _multimesh(plant_meshes[k.z], cover[k], "GroundCover_%d_%d_%d" % [k.x, k.y, k.z])
		mmi6.visibility_range_end = 115.0 + FOREST_CELL * 0.5
		mmi6.visibility_range_end_margin = 12.0
		mmi6.set_meta(&"base_range", mmi6.visibility_range_end)
		mmi6.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mmi6)

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


## Lush arched fern rosette (12-14 folded fronds using WoodlandBuilder's frond helper).
func _fern_mesh(variant: int, leaf_mat: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3311 + variant * 73
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lb := 0
	var fronds := 12 + variant * 2
	var tint := Color(0.84, 0.96, 0.72) if variant == 0 else Color(0.78, 0.92, 0.68)
	for k in range(fronds):
		var a: float = TAU * float(k) / float(fronds) + rng.randf_range(-0.16, 0.16)
		var dir := Vector3(cos(a), 0.0, sin(a))
		var inner: bool = k % 3 == 0
		var flen: float = rng.randf_range(0.95, 1.35) if not inner else rng.randf_range(0.65, 0.90)
		var fwid: float = flen * 0.48
		var rise: float = rng.randf_range(0.65, 0.95) if inner else rng.randf_range(0.35, 0.62)
		var droop: float = rng.randf_range(0.45, 0.75)
		lb = Woodland.frond(st, lb, Vector3(0.0, 0.04, 0.0) + dir * 0.05, dir, rise, droop,
				flen, fwid, 4, Woodland.CELL_SPRUCE, tint, 0.45, 0.98, 0.34, dir)
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, leaf_mat)
	return mesh


## Alpine wildflower patch: basal green stems & leaves topped with star-shaped blossom heads.
func _wildflower_patch_mesh(kind: int, mat: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6060 + kind * 199
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vi := 0

	var petal_col := Color(0.98, 0.80, 0.12)
	var center_col := Color(0.78, 0.42, 0.06)
	if kind == 1:
		petal_col = Color(0.96, 0.96, 0.92)
		center_col = Color(0.96, 0.78, 0.12)
	elif kind == 2:
		petal_col = Color(0.46, 0.42, 0.90)
		center_col = Color(0.92, 0.84, 0.28)

	var stem_base := Color(0.16, 0.30, 0.10)
	var stem_tip := Color(0.28, 0.48, 0.16)

	for b in range(18):
		var r: float = sqrt(rng.randf()) * 0.65
		var th: float = rng.randf() * TAU
		var root := Vector3(cos(th) * r, -0.03, sin(th) * r)
		var b_ang: float = th + rng.randf_range(-0.6, 0.6)
		var b_dir := Vector3(cos(b_ang), 0.0, sin(b_ang))
		var b_side := Vector3(-b_dir.z, 0.0, b_dir.x)
		var h: float = rng.randf_range(0.24, 0.48)
		var lean: float = rng.randf_range(0.14, 0.30)
		var w: float = rng.randf_range(0.035, 0.055)
		var p0 := root - b_side * w
		var p1 := root + b_side * w
		var mid := root + b_dir * (lean * 0.45) + Vector3(0.0, h * 0.55, 0.0)
		var p2 := mid - b_side * (w * 0.65)
		var p3 := mid + b_side * (w * 0.65)
		var tip := root + b_dir * lean + Vector3(0.0, h, 0.0)
		var nrm: Vector3 = (Vector3.UP + b_dir * 0.35).normalized()
		var verts := [p0, p1, p2, p3, tip]
		var cols := [stem_base, stem_base, stem_tip, stem_tip, stem_tip]
		for k in range(5):
			st.set_normal(nrm)
			st.set_color(cols[k])
			st.set_uv(Vector2(0.5, float(k) * 0.25))
			st.add_vertex(verts[k])
		for idx in [0, 1, 2, 1, 3, 2, 2, 3, 4]:
			st.add_index(vi + idx)
		vi += 5

	for f in range(14):
		var r: float = sqrt(rng.randf()) * 0.62
		var th: float = rng.randf() * TAU
		var head_p := Vector3(cos(th) * r, rng.randf_range(0.32, 0.58), sin(th) * r)
		var tilt := Vector3(rng.randf_range(-0.22, 0.22), 1.0, rng.randf_range(-0.22, 0.22)).normalized()
		var u: Vector3 = tilt.cross(Vector3.RIGHT if absf(tilt.x) < 0.8 else Vector3.FORWARD).normalized()
		var v_ax: Vector3 = tilt.cross(u).normalized()
		var rad: float = rng.randf_range(0.085, 0.135)
		var pc: Color = petal_col.lerp(Color.WHITE, rng.randf_range(0.0, 0.12))

		var n_petals := 6
		var center_v: Vector3 = head_p + tilt * 0.018
		st.set_normal(tilt)
		st.set_color(center_col)
		st.set_uv(Vector2(0.5, 1.0))
		st.add_vertex(center_v)
		for p_i in range(n_petals):
			var a0: float = TAU * float(p_i) / float(n_petals)
			var a1: float = TAU * (float(p_i) + 0.5) / float(n_petals)
			var outer_v: Vector3 = head_p + (u * cos(a0) + v_ax * sin(a0)) * rad
			var inner_v: Vector3 = head_p + (u * cos(a1) + v_ax * sin(a1)) * (rad * 0.48) + tilt * 0.008
			st.set_normal(tilt)
			st.set_color(pc)
			st.set_uv(Vector2(0.5, 1.0))
			st.add_vertex(outer_v)
			st.set_normal(tilt)
			st.set_color(pc.darkened(0.08))
			st.set_uv(Vector2(0.5, 1.0))
			st.add_vertex(inner_v)
		for p_i in range(n_petals):
			var i1: int = 1 + p_i * 2
			var i2: int = 1 + p_i * 2 + 1
			var i3: int = 1 + ((p_i + 1) % n_petals) * 2
			for idx in [0, i1, i2, 0, i2, i3]:
				st.add_index(vi + idx)
		vi += 1 + n_petals * 2

	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, mat)
	return mesh


## Lush alpine meadow grass tuft (curved blades for `dune_grass.gdshader`).
func _grass_tuft_mesh(mat: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5151
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vi := 0
	for b in range(22):
		var r: float = sqrt(rng.randf()) * 0.55
		var th: float = rng.randf() * TAU
		var root := Vector3(cos(th) * r, -0.04, sin(th) * r)
		var b_ang: float = th + rng.randf_range(-0.5, 0.5)
		var dir := Vector3(cos(b_ang), 0.0, sin(b_ang))
		var side := Vector3(-dir.z, 0.0, dir.x)
		var h: float = rng.randf_range(0.32, 0.68)
		var lean: float = rng.randf_range(0.16, 0.36)
		var w: float = rng.randf_range(0.032, 0.052)
		var p0 := root - side * w
		var p1 := root + side * w
		var mid := root + dir * (lean * 0.45) + Vector3(0.0, h * 0.55, 0.0)
		var p2 := mid - side * (w * 0.65)
		var p3 := mid + side * (w * 0.65)
		var tip := root + dir * lean + Vector3(0.0, h, 0.0)
		var nrm: Vector3 = (Vector3.UP + dir * 0.3).normalized()
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(0, 0.55), Vector2(1, 0.55), Vector2(0.5, 1.0)]
		var pts := [p0, p1, p2, p3, tip]
		var heights := [0.0, 0.0, 0.55, 0.55, 1.0]
		# dune_grass.gdshader: vertex colour = blade colour (sRGB), alpha = height up the blade (sway).
		var dry: float = rng.randf()
		var tip_col: Color = Color(0.46, 0.62, 0.22).lerp(Color(0.66, 0.64, 0.32), dry * dry * 0.6)
		var base_col := Color(0.20, 0.36, 0.12)
		for k in range(5):
			var hk: float = heights[k]
			var ck: Color = base_col.lerp(tip_col, hk)
			ck.a = hk
			st.set_normal(nrm)
			st.set_color(ck)
			st.set_uv(uvs[k])
			st.add_vertex(pts[k])
		for idx in [0, 1, 2, 1, 3, 2, 2, 3, 4]:
			st.add_index(vi + idx)
		vi += 5
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, mat)
	return mesh


## Fallen weathered deadwood pine log with broken branch stubs (Concept Art 1 & 2).
func _deadwood_log_mesh(variant: int, bark_mat: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4404 + variant * 89
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bi := 0
	var length: float = 4.2 + float(variant) * 1.1
	var r0: float = 0.24 + float(variant) * 0.04
	var col := Color(0.56, 0.50, 0.44)
	var pts: Array = []
	var radii: Array = []
	for k in range(6):
		var t: float = float(k) / 5.0
		var z: float = lerpf(-length * 0.5, length * 0.5, t)
		var bend: float = sin(t * PI) * 0.14 * (1.0 if variant == 0 else -1.0)
		pts.append(Vector3(bend, r0 * 0.55, z))
		radii.append(r0 * lerpf(1.0, 0.58, t))
	bi = Woodland.bark_tube(st, bi, pts, radii, 7, col, 0.35, Vector2(-1.0, 2.0))
	for s in range(3):
		var st_t: float = 0.22 + 0.26 * float(s)
		var p_attach: Vector3 = (pts[0] as Vector3).lerp(pts[5], st_t)
		var ang: float = (-0.8 if s % 2 == 0 else 0.85) + rng.randf_range(-0.2, 0.2)
		var sdir := Vector3(sin(ang), rng.randf_range(0.25, 0.65), cos(ang) * 0.4).normalized()
		var p_tip: Vector3 = p_attach + sdir * rng.randf_range(0.65, 1.25)
		bi = Woodland.bark_tube(st, bi, [p_attach, p_tip], [r0 * 0.42, r0 * 0.14], 4, col.darkened(0.12), 0.3, Vector2(-1.0, 2.0))
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, bark_mat)
	return mesh


func _woodland_keep_out() -> Array:
	var out: Array = []
	var cl: PackedFloat32Array = _tg.get("grass_clearings")
	for o in range(0, cl.size() - 5, 6):
		out.append([cl[o], cl[o + 1], cl[o + 2], cl[o + 3], cl[o + 4]])
	var pads: PackedFloat32Array = _tg.get("flat_pads")
	for o in range(0, pads.size() - 6, 7):
		out.append([pads[o], pads[o + 1], pads[o + 2] + 4.0, pads[o + 3] + 4.0, pads[o + 4]])
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


func _cell(x: float, z: float, size: float, v: int) -> Vector3i:
	return Vector3i(floori(x / size), floori(z / size), v)


func _add_to_cells(cells: Dictionary, key: Vector3i, xf: Transform3D) -> void:
	if not cells.has(key):
		cells[key] = []
	cells[key].append(xf)


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


func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	if node != scene_root:
		node.owner = scene_root
	for child in node.get_children():
		if child.owner != null and child.owner != scene_root:
			continue
		_set_owner_recursive(child, scene_root)
