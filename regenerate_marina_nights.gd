# regenerate_marina_nights.gd
# Builds levels/MarinaNightsLevel.tscn, Marina Nights, the Al-Raihana GP's finale: a night street race through the city
# whose skyline the other three stages see on their horizon. The lap starts on the corniche along the sea (palms, a
# promenade, the balustrade over the water) and crosses the creek's mouth, turns north up Al-Manara Avenue between the
# lit glass towers, west over the creek on the arch bridge (dhows moored below, strung with lights), through the souk's
# tight lanes between mud-brick houses and lanterns, and down the palm avenue back to the sea. Fireworks burst over the
# water all race long. Ramlat Hamra's scene is the template (gates, grid, spawners); the ground is TerrainGenerator's
# ("marina_nights": ArabianTerrain.marina_height), its meshes chunked so no mesh takes in more lamps than the mobile
# renderer gives one.
#
# Run: Godot --headless --path . res://regenerate_marina_nights.tscn
extends Node

const D = preload("res://ArabianDresser.gd")
const ArabianKit = preload("res://ArabianKit.gd")
const AT = preload("res://ArabianTerrain.gd")
const BloombayCity = preload("res://BloombayCity.gd")
const GulfCity = preload("res://GulfCity.gd")
const MeshChunker = preload("res://MeshChunker.gd")
const ShipKitRef = preload("res://ShipKit.gd")
const PortKitRef = preload("res://PortKit.gd")

const TEMPLATE := "res://levels/RamlatHamraLevel.tscn"
const LEVEL := "res://levels/MarinaNightsLevel.tscn"
const ROOT := "MarinaDressing"
const PS := 1.6
const LAND := AT.MARINA_LAND
const ROAD_Y := 2.45
## The corniche runs this far inland of the coast; the avenue up the east side at AVENUE_X.
const CORNICHE_IN := 34.0
const AVENUE_X := 430.0
const NORTH_Z := -215.0
const BRIDGE_Y := 6.2
## The roundabout where the avenue meets the north road: its middle and the lap's radius round it (the island inside).
const RB_C := Vector2(AVENUE_X - 12.0, NORTH_Z - 12.0)
const RB_R := 36.0
## Bab al-Lulu, the Pearl Ring over the corniche, and the kicker that throws the carts through it: where its toe stands
## (x on the corniche), the ring this far past the lip.
const RING_TOE_X := -105.0
const RING_PAST_LIP := 10.0
const RING_RADIUS := 12.5
const RING_TUBE := 1.6
## The opening's bottom 4.3m over the ground: no getting under the ring, every cart off the kicker (lip 4.65m up)
## clears it at 25 m/s and more.
const RING_HC := 15.2
const CORNICHE_BRIDGE_Y := 4.0
## Districts: downtown's towers east of the creek, the souk west of it.
const DOWNTOWN := Rect2(110.0, -420.0, 620.0, 560.0)
const SOUK := Rect2(-300.0, -290.0, 290.0, 300.0)
const LAMP_EVERY := 32.0
const GATE_CLEAR := 18.0

var d := D.new()
var tg: Node3D
var level: Node3D
var gates: Array = []
var palms_at: Array = []
var lamp_spots: Array = []


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	level = (load(TEMPLATE) as PackedScene).instantiate()
	level.name = "MarinaNightsLevel"
	add_child(level)
	for n in ["RamlatDressing", "WorldEnvironment", "SunLight", "WeatherController", "Jumps", "BoostPads", ROOT, "MarinaWater"]:
		var old := level.get_node_or_null(n)
		if old:
			level.remove_child(old)
			old.free()
	tg = level.get_node("TerrainGenerator")
	tg.set("level_prefix", "marina_nights")
	tg.set("track_layout_type", 0)
	tg.set("terrain_resolution", 1000)
	tg.set("hill_height", 0.0)
	tg.set("no_water", false)
	tg.set("edge_falloff", false)
	tg.set("clip_to_disc", false)
	tg.set("flat_pads", PackedFloat32Array())
	tg.set("road_gaps", PackedFloat32Array())
	tg.set("road_gap_drift", PackedFloat32Array())
	tg.set("road_height_from_plan", true)
	var road_mat := ShaderMaterial.new()
	road_mat.shader = load("res://road_crumble.gdshader")
	road_mat.set_shader_parameter("asphalt_tex", load("res://materials/asphalt.png"))
	road_mat.set_shader_parameter("dirt_tex", load("res://materials/sand.png"))
	road_mat.set_shader_parameter("gap_count", 0)
	road_mat.set_shader_parameter("tint", Color(0.62, 0.62, 0.64))
	road_mat.set_shader_parameter("roughness", 0.55)
	tg.set("road_material", road_mat)
	var path: Path3D = level.get_node("TrackPath")
	path.transform = Transform3D.IDENTITY
	for m in [&"town_route", &"jump_lips"]:
		if path.has_meta(m):
			path.remove_meta(m)
	path.curve = _lap_curve()
	print("Lap: ", path.curve.get_baked_length(), "m")
	_plan_ring(path)
	_place_gates(path.curve)
	_place_pads(path.curve)

	d.setup(level, tg, 9191)
	for cp in level.get_node("Checkpoints").get_children():
		gates.append(Vector2(cp.global_position.x, cp.global_position.z))
	var fl: Node3D = level.get_node("FinishLine")
	gates.append(Vector2(fl.global_position.x, fl.global_position.z))
	for rs in ring_spots:
		gates.append(rs)
	gates.append(RB_C)
	print("Baking the ground...")
	tg.generate_world()
	d.setup(level, tg, 9191)
	level._align_start_and_spawns_to_track()

	var root := Node3D.new()
	root.name = ROOT
	level.add_child(root)
	root.owner = level
	root.set_script(load("res://CanyonDetail.gd"))
	_environment()
	_sea()
	_plan_palms()
	_ground_material()
	_build_city(root)
	_build_souk(root)
	_build_lamps(root)
	_build_palms(root)
	_build_railings(root)
	_build_arch(root)
	_build_dhows(root)
	_build_roundabout(root)
	_build_ring(root)
	_build_marina(root)
	_build_far_city(root)
	var fw := Node3D.new()
	fw.name = "Fireworks"
	fw.set_script(load("res://Fireworks.gd"))
	fw.set("area", AABB(Vector3(-520.0, 70.0, 330.0), Vector3(1000.0, 90.0, 140.0)))
	root.add_child(fw)
	fw.owner = level

	# The ground and the road in 80m cells, so each takes in only the lamps near it (Mobile's per-mesh light limit).
	var n_chunked: int = MeshChunker.chunk_scene(tg, "res://generated/marina_nights_", "res://generated/marina_nights_chunks/", 80.0)
	print("Chunked meshes: ", n_chunked)
	for child in tg.get_children():
		_own(child)
	var grid := level.get_node_or_null("FinishLine/SpawnPoints")
	if grid:
		_own(grid)

	remove_child(level)
	var packed := PackedScene.new()
	var err := packed.pack(level)
	if err == OK:
		err = ResourceSaver.save(packed, LEVEL)
	print("Saved MarinaNightsLevel.tscn: ", err, " in ", (Time.get_ticks_msec() - t0) / 1000.0, "s")
	get_tree().quit(0 if err == OK else 1)


func _own(n: Node) -> void:
	n.owner = level
	if n.scene_file_path != "":
		return
	for c in n.get_children():
		_own(c)


# ======================================================================================
#  The lap
# ======================================================================================

## The road's height at (x, z): the land's, and over the creek a bridge (the corniche's low, the arch's higher),
## easing up over its approaches.
func _road_y(x: float, z: float, deck: float) -> float:
	var cz: float = maxf(z, AT.MARINA_CREEK_HEAD)
	var w: float = AT.MARINA_CREEK_HALF - Vector2(absf(x - AT.creek_x(cz)), z - cz).length()
	# Rising over 45m either side of the water's edge.
	var t: float = smoothstep(-45.0, -2.0, w)
	return lerpf(ROAD_Y, deck, t)


func _lap_curve() -> Curve3D:
	var pts: Array = []
	# The corniche, east: the coast's line CORNICHE_IN inland, the creek's mouth on the low bridge.
	var x := -325.0
	while x <= 380.0:
		var z: float = AT.coast_z(x) - CORNICHE_IN
		pts.append(Vector3(x, _road_y(x, z, CORNICHE_BRIDGE_Y), z))
		x += 45.0
	# The turn north onto the avenue.
	var zc: float = AT.coast_z(AVENUE_X) - CORNICHE_IN
	pts.append(Vector3(AVENUE_X - 12.0, ROAD_Y, zc - 20.0))
	var z2: float = zc - 60.0
	while z2 > RB_C.y + RB_R + 40.0:
		pts.append(Vector3(AVENUE_X + 4.0 * sin(z2 / 60.0), ROAD_Y, z2))
		z2 -= 50.0
	pts.append(Vector3(AVENUE_X, ROAD_Y, RB_C.y + RB_R + 20.0))
	# The roundabout: in from the south, round its east and north sides (keeping right, the island on the left) and
	# out to the west, three quarters of the way round.
	var a := 60.0
	while a >= -185.0:
		var r := deg_to_rad(a)
		pts.append(Vector3(RB_C.x + cos(r) * RB_R, ROAD_Y, RB_C.y + sin(r) * RB_R))
		a -= 30.0
	# The north road, west, over the creek on the arch bridge.
	var x2: float = RB_C.x - RB_R - 32.0
	while x2 > -40.0:
		pts.append(Vector3(x2, _road_y(x2, NORTH_Z, BRIDGE_Y), NORTH_Z + 6.0 * sin(x2 / 70.0)))
		x2 -= 42.0
	# The souk: tight right-angled lanes stepping south-west.
	for p in [Vector2(-70, -215), Vector2(-102, -212), Vector2(-122, -192), Vector2(-124, -160), Vector2(-142, -138),
			Vector2(-178, -136), Vector2(-198, -114), Vector2(-198, -82), Vector2(-218, -60), Vector2(-256, -58)]:
		pts.append(Vector3(p.x, ROAD_Y, p.y))
	# The palm avenue, south to the sea.
	for p in [Vector2(-300, -40), Vector2(-322, 0), Vector2(-332, 50), Vector2(-338, 100), Vector2(-348, 138), Vector2(-356, 166)]:
		pts.append(Vector3(p.x, ROAD_Y, p.y))
	var c := Curve3D.new()
	c.bake_interval = 0.25
	var n := pts.size()
	for i in range(n):
		var p0: Vector3 = pts[(i - 1 + n) % n]
		var p1: Vector3 = pts[i]
		var p2: Vector3 = pts[(i + 1) % n]
		var tan: Vector3 = (p2 - p0) / 6.0
		c.add_point(p1, -tan, tan)
	return c


func _place_gates(curve: Curve3D) -> void:
	var length := curve.get_baked_length()
	var fl: Node3D = level.get_node("FinishLine")
	fl.position = curve.sample_baked(curve.get_closest_offset(Vector3(-150.0, ROAD_Y, AT.coast_z(-150.0) - CORNICHE_IN)))
	var start: float = curve.get_closest_offset(fl.position)
	var shares := {"Halfway4": 0.22, "Halfway3": 0.42, "Halfway2": 0.62, "Halfway1": 0.82}
	for cp in level.get_node("Checkpoints").get_children():
		if shares.has(str(cp.name)):
			var o: float = fmod(start + length * float(shares[str(cp.name)]), length)
			# Not on the roundabout or at the ring's jump.
			for k in range(40):
				var q: Vector3 = curve.sample_baked(o)
				var bad: bool = Vector2(q.x, q.z).distance_to(RB_C) < RB_R + 30.0
				for rs in ring_spots:
					if Vector2(q.x, q.z).distance_to(rs) < 45.0:
						bad = true
				if not bad:
					break
				o = fmod(o + 10.0, length)
			(cp as Node3D).position = curve.sample_baked(o)
	level._align_checkpoints_to_track()


func _place_pads(curve: Curve3D) -> void:
	var pads_node := Node3D.new()
	pads_node.name = "BoostPads"
	level.add_child(pads_node)
	pads_node.owner = level
	var bp: PackedScene = load("res://BoostPad.tscn")
	var spots := [[curve.sample_baked(ring_toe_s - 28.0), "BoostPad_Ring"], [Vector3(150.0, ROAD_Y, AT.coast_z(150.0) - CORNICHE_IN), "BoostPad_Corniche"],
		[Vector3(AVENUE_X, ROAD_Y, 40.0), "BoostPad_Avenue"], [Vector3(-334.0, ROAD_Y, 40.0), "BoostPad_PalmAvenue"]]
	for at in spots:
		var off: float = curve.get_closest_offset(at[0])
		var p := curve.sample_baked(off)
		var q := curve.sample_baked(off + 2.0)
		var pad: Node3D = bp.instantiate()
		pad.name = at[1]
		pads_node.add_child(pad)
		pad.owner = level
		pad.transform = Transform3D(Basis.looking_at((q - p).normalized(), Vector3.UP), p + Vector3(0, 0.1, 0))


# ======================================================================================
#  Night, the sea, the ground
# ======================================================================================

const HAZE := Color(0.20, 0.18, 0.26)

func _environment() -> void:
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://sky_tropical_cumulus.gdshader")
	# Night over the Gulf: deep blue-black overhead, the city's glow warm along the horizon, a high moon.
	sm.set_shader_parameter("sky_top", Color(0.01, 0.02, 0.06))
	sm.set_shader_parameter("sky_horizon", Color(0.20, 0.14, 0.18))
	sm.set_shader_parameter("ground_horizon", Color(0.10, 0.08, 0.10))
	sm.set_shader_parameter("ground_bottom", Color(0.02, 0.02, 0.03))
	sm.set_shader_parameter("sky_curve", 0.28)
	sm.set_shader_parameter("sky_energy", 0.7)
	sm.set_shader_parameter("horizon_haze", HAZE)
	sm.set_shader_parameter("haze_strength", 0.6)
	sm.set_shader_parameter("haze_height", 0.1)
	sm.set_shader_parameter("sun_tint", Color(0.85, 0.90, 1.0))
	sm.set_shader_parameter("sun_disc_degrees", 1.6)
	sm.set_shader_parameter("sun_glow", 0.25)
	sm.set_shader_parameter("sun_horizon_glow", 0.0)
	sm.set_shader_parameter("cloud_lit", Color(0.30, 0.30, 0.38))
	sm.set_shader_parameter("cloud_shade", Color(0.06, 0.06, 0.10))
	sm.set_shader_parameter("cloud_coverage", 0.22)
	sm.set_shader_parameter("cloud_opacity", 0.6)
	sm.set_shader_parameter("cloud_scale", 1.8)
	sm.set_shader_parameter("cloud_seed", 9.1)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.16, 0.18, 0.30)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.15
	env.glow_enabled = true
	env.glow_intensity = 0.75
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = HAZE
	env.fog_light_energy = 1.0
	env.fog_density = 1.0
	env.fog_depth_begin = 260.0
	env.fog_depth_end = 3800.0
	env.fog_depth_curve = 1.4
	env.fog_sky_affect = 0.03
	env_node.environment = env
	level.add_child(env_node)
	level.move_child(env_node, 0)
	env_node.owner = level
	var moon := DirectionalLight3D.new()
	moon.name = "SunLight"
	moon.rotation_degrees = Vector3(-52.0, 150.0, 0.0)
	moon.light_color = Color(0.62, 0.70, 0.95)
	moon.light_energy = 0.22
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 200.0
	level.add_child(moon)
	level.move_child(moon, 1)
	moon.owner = level


## The sea and the creek: one plane at y 0 (named "...Water": PlayerCart's general water branch reads its height),
## night colours, the city's glow in its reflections.
func _sea() -> void:
	var water := MeshInstance3D.new()
	water.name = "MarinaWater"
	var plane := PlaneMesh.new()
	plane.size = Vector2(7000.0, 7000.0)
	plane.subdivide_width = 40
	plane.subdivide_depth = 40
	water.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = load("res://water.gdshader")
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.02
	var nt := NoiseTexture2D.new()
	nt.noise = noise
	nt.seamless = true
	nt.as_normal_map = true
	mat.set_shader_parameter("noise_tex", nt)
	mat.set_shader_parameter("normal_tex", nt)
	mat.set_shader_parameter("water_color", Color(0.005, 0.015, 0.03))
	mat.set_shader_parameter("shallow_color", Color(0.04, 0.10, 0.12))
	mat.set_shader_parameter("deep_water_color", Color(0.004, 0.01, 0.02))
	mat.set_shader_parameter("sky_tint", Color(0.30, 0.26, 0.30))
	mat.set_shader_parameter("sky_reflect", 0.5)
	mat.set_shader_parameter("transparency", 0.25)
	mat.set_shader_parameter("metallic", 0.75)
	mat.set_shader_parameter("roughness", 0.05)
	mat.set_shader_parameter("wave_strength", 0.5)
	mat.set_shader_parameter("wave_scale", 7000.0 / 1600.0)
	mat.set_shader_parameter("water_fade_start", 2600.0)
	mat.set_shader_parameter("water_fade_end", 3500.0)
	water.material_override = mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.set_meta("water_surface_y", 0.0)
	level.add_child(water)
	water.owner = level


func _plan_palms() -> void:
	# The promenade: a row between the corniche and the balustrade, and along the palm avenue both sides.
	var length: float = d.length
	var s := 0.0
	while s < length:
		var p: Vector3 = d.curve.sample_baked(s)
		var q: Vector3 = d.curve.sample_baked(fmod(s + 2.0, length))
		var tan := q - p
		tan.y = 0.0
		tan = tan.normalized()
		var right := Vector3(-tan.z, 0.0, tan.x)
		var promenade: bool = AT.coast_z(p.x) - p.z < CORNICHE_IN + 6.0
		var avenue: bool = p.x < -280.0 and p.z > -60.0 and p.z < 160.0
		var boulevard: bool = absf(p.x - AVENUE_X) < 20.0 and p.z < 120.0 and p.z > NORTH_Z + 40.0
		if promenade or avenue or boulevard:
			for sd in [-1.0, 1.0]:
				# On the corniche only the sea's side (+z) has the promenade.
				if promenade and right.z * sd < 0.0:
					continue
				var pp: Vector3 = p + right * sd * (d.road_half + 5.0)
				if AT.marina_water_d(pp.x, pp.z) > -4.0 or d.road_dist(pp.x, pp.z, 30.0) < d.road_half + 3.5 or _near_gate(Vector2(pp.x, pp.z), 6.0):
					continue
				palms_at.append(Vector2(pp.x, pp.z))
		s += 16.0
	# The promenade's seaward row too, along the balustrade.
	var x := -620.0
	while x < 720.0:
		var z: float = AT.coast_z(x) - 9.0
		if AT.marina_water_d(x, z) < -4.0 and d.road_dist(x, z, 30.0) > d.road_half + 3.5:
			palms_at.append(Vector2(x, z))
		x += 22.0


func _near_gate(c: Vector2, r: float) -> bool:
	for g in gates:
		if c.distance_to(g) < r + GATE_CLEAR:
			return true
	return false


var palm_hash := {}

func _ground_material() -> void:
	for p in palms_at:
		var k := Vector2i(floori(p.x / 8.0), floori(p.y / 8.0))
		if not palm_hash.has(k):
			palm_hash[k] = []
		palm_hash[k].append(p)
	var map: Texture2D = d.ground_map(1024, 1000.0, func(x: float, z: float) -> Color:
		var coast: float = AT.coast_z(x) - z
		var pr := 0.0
		if coast > 1.5 and coast < CORNICHE_IN - d.road_half - 0.5:
			pr = clampf((coast - 1.5) / (CORNICHE_IN - d.road_half - 2.0), 0.0, 1.0)
		var bed := 0.0
		var key := Vector2i(floori(x / 8.0), floori(z / 8.0))
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				for p in palm_hash.get(key + Vector2i(dx, dz), []):
					bed = maxf(bed, 1.0 - smoothstep(1.6, 2.6, (p as Vector2).distance_to(Vector2(x, z))))
		return Color(pr, bed, 0.0, 1.0))
	var m := ShaderMaterial.new()
	m.shader = load("res://marina_ground.gdshader")
	m.set_shader_parameter("concrete_tex", load("res://materials/concrete.png"))
	m.set_shader_parameter("stone_tex", load("res://materials/cobblestone.png"))
	m.set_shader_parameter("stone_normal", load("res://materials/cobblestone_normal.png"))
	m.set_shader_parameter("sand_tex", load("res://materials/sand.png"))
	m.set_shader_parameter("ground_map", map)
	m.set_shader_parameter("land_y", LAND)
	m = d.save(m, "ground_material") as ShaderMaterial
	tg.set("grass_material", m)
	(tg.get_node("Terrain_Visual") as MeshInstance3D).material_override = m


# ======================================================================================
#  The city
# ======================================================================================

## The night material for the city's walls: lit rooms, offices and shop fronts (city_building.gdshader's evening
## lights, as Mtaa Nights), the glass reflecting a night sky.
func _city_material() -> ShaderMaterial:
	var m: ShaderMaterial = BloombayCity.wall_material(Color(0.02, 0.03, 0.07), Color(0.22, 0.16, 0.18), Color(0.04, 0.04, 0.05), Color(0.10, 0.10, 0.14))
	m.set_shader_parameter("gulf", true)
	m.set_shader_parameter("lit_share", 0.5)
	m.set_shader_parameter("lit_energy", 1.2)
	m.set_shader_parameter("lit_color", Color(1.0, 0.80, 0.55))
	m.set_shader_parameter("sky_reflect", Color(0.10, 0.12, 0.22))
	m.set_shader_parameter("glass_dark", Color(0.03, 0.05, 0.10))
	return d.save(m, "city_walls") as ShaderMaterial


var _city_mat: ShaderMaterial
var _roof_mat: StandardMaterial3D
var _footprints: Array = []     # [centre, radius]

func _free_plot(c: Vector2, r: float, setback: float) -> bool:
	if AT.marina_water_d(c.x, c.y) > -(r + 4.0):
		return false
	if d.road_dist(c.x, c.y, r + d.road_half + setback + 30.0) < r + d.road_half + setback:
		return false
	if _near_gate(c, r):
		return false
	for f in _footprints:
		if c.distance_to(f[0]) < r + float(f[1]) + 3.0:
			return false
	for p in palms_at:
		if c.distance_to(p) < r + 3.0:
			return false
	return true


## The road's heading near (x, z), as a yaw for a building to face it.
func _face_road(c: Vector2) -> float:
	var near: Array = d.road_near(c.x, c.y, 200.0)
	var off: float = near[2]
	var t: Vector3 = d.curve.sample_baked(fmod(off + 2.0, d.length)) - d.curve.sample_baked(off)
	return atan2(t.x, t.z)


func _build_city(root: Node3D) -> void:
	_city_mat = _city_material()
	_roof_mat = d.save(BloombayCity.roof_material(), "city_roofs") as StandardMaterial3D
	var cells := {}
	var rng := d.rng
	var towers := 0
	var blocks := 0
	# Towers first (downtown), tallest near the avenue's middle.
	for k in range(900):
		var c := Vector2(rng.randf_range(DOWNTOWN.position.x, DOWNTOWN.end.x), rng.randf_range(DOWNTOWN.position.y, DOWNTOWN.end.y))
		var w: float = rng.randf_range(20.0, 32.0)
		var r: float = w * 0.75
		if not _free_plot(c, r, 6.0):
			continue
		var focus: float = 1.0 - clampf(c.distance_to(Vector2(AVENUE_X + 60.0, -60.0)) / 400.0, 0.0, 1.0)
		var h: float = lerpf(70.0, 300.0, focus * rng.randf_range(0.6, 1.0))
		var kind: int = towers % 5
		_footprints.append([c, r * (1.6 if kind == 4 else 1.0)])
		var key := Vector2i(floori(c.x / 110.0), floori(c.y / 110.0))
		if not cells.has(key):
			cells[key] = GulfCity.new()
			(cells[key] as GulfCity).begin()
		(cells[key] as GulfCity).gulf_tower(c.x, c.y, LAND, w, h, kind, rng)
		towers += 1
		if towers >= 34:
			break
	# Blocks everywhere else on land: hotels and flats along the corniche, offices and flats inland.
	var paints := [Color(0.92, 0.86, 0.74), Color(0.86, 0.78, 0.64), Color(0.95, 0.93, 0.88), Color(0.80, 0.72, 0.60), Color(0.88, 0.82, 0.70)]
	for k in range(9000):
		var c := Vector2(rng.randf_range(-760.0, 820.0), rng.randf_range(-760.0, 260.0))
		if SOUK.grow(30.0).has_point(c):
			continue
		var w: float = rng.randf_range(18.0, 36.0)
		var dd: float = rng.randf_range(14.0, 26.0)
		var r: float = Vector2(w, dd).length() * 0.5
		if not _free_plot(c, r, 5.0):
			continue
		var near_road: float = d.road_dist(c.x, c.y, 120.0)
		var storeys: int = rng.randi_range(3, 7) if near_road < 120.0 else rng.randi_range(2, 5)
		if AT.coast_z(c.x) - c.y < 140.0:
			storeys = rng.randi_range(6, 14)   # hotels on the waterfront
		_footprints.append([c, r])
		var key := Vector2i(floori(c.x / 110.0), floori(c.y / 110.0))
		if not cells.has(key):
			cells[key] = GulfCity.new()
			(cells[key] as GulfCity).begin()
		(cells[key] as GulfCity).gulf_block(c.x, c.y, LAND, w, dd, _face_road(c), storeys, GulfCity.SAND_WALLS[rng.randi() % GulfCity.SAND_WALLS.size()], rng.randi() % 4, rng)
		blocks += 1
	var node := Node3D.new()
	node.name = "City"
	root.add_child(node)
	node.owner = level
	for key in cells:
		var bc: GulfCity = cells[key]
		var mi := MeshInstance3D.new()
		mi.name = "CityBlock_%d_%d" % [key.x, key.y]
		mi.mesh = d.save(bc.commit(_city_mat, _roof_mat), "city_%d_%d" % [key.x, key.y])
		node.add_child(mi)
		mi.owner = level
	print("City: ", towers, " towers, ", blocks, " blocks in ", cells.size(), " cells")


## The souk: mud-brick houses with wind towers close along the lanes, arcades on their fronts, lanterns.
func _build_souk(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Souk"
	root.add_child(node)
	node.owner = level
	var rng := d.rng
	var n := 0
	# Along the lanes first (fronts a pavement's width off the road), then filling in behind.
	for k in range(20000):
		if n >= 90:
			break
		var c := Vector2(rng.randf_range(SOUK.position.x - 40.0, SOUK.end.x + 20.0), rng.randf_range(SOUK.position.y - 30.0, SOUK.end.y + 30.0))
		var w: float = rng.randf_range(6.5, 9.0)
		var dd: float = rng.randf_range(6.0, 7.5)
		var r: float = Vector2(w, dd).length() * 0.5 * PS
		var near: Array = d.road_near(c.x, c.y, 80.0)
		var front: float = float(near[0]) - dd * 0.5 * PS
		if (n < 60 and (front < d.road_half + 2.0 or front > d.road_half + 4.5)) or front < d.road_half + 2.0:
			continue
		if not _free_plot(c, r * 0.7, 0.0):
			continue
		var to_road := Vector2((near[1] as Vector3).x, (near[1] as Vector3).z) - c
		var yaw: float = atan2(-to_road.x, -to_road.y)
		_footprints.append([c, r * 0.7])
		var hr := RandomNumberGenerator.new()
		hr.seed = 7000 + n
		var storeys: int = 2 if hr.randf() < 0.5 else 1
		var key: String = "mud" if hr.randf() < 0.6 else "lime"
		d.building(node, "SoukHouse_%d" % n, c.x, c.y, LAND, yaw, func(pk, kit) -> void:
			ArabianKit.house(pk, kit, hr, w, dd, storeys, key, hr.randf() < 0.6, false)
			# Hanging lanterns on the front and an awning.
			for sx in [-1.0, 1.0]:
				var lp := Vector3(sx * w * 0.3, 2.9, -dd * 0.5 - 0.5)
				pk.beam(kit, "timber", lp + Vector3(0, 0.4, 0.5), lp + Vector3(0, 0.4, 0), 0.06, 0.06, ArabianKit.POLE)
				pk.box(kit, "lamp", Transform3D(Basis(), lp), Vector3(0.32, 0.45, 0.32), Color(1.0, 0.62, 0.28))
			var aw: Color = [Color(0.62, 0.16, 0.12), Color(0.15, 0.30, 0.45), Color(0.70, 0.52, 0.18)][hr.randi() % 3]
			pk.panel(kit, "cloth", [Vector3(-w * 0.4, 2.6, -dd * 0.5), Vector3(w * 0.4, 2.6, -dd * 0.5), Vector3(w * 0.4, 2.1, -dd * 0.5 - 1.6), Vector3(-w * 0.4, 2.1, -dd * 0.5 - 1.6)],
					Vector3(0, 1, -0.3).normalized(), aw, aw.darkened(0.4)), 900.0)
		n += 1
	print("Souk houses: ", n)
	_souk_festoons(node)


## The street lamps: a mast every LAMP_EVERY along the lap, alternating sides, each with a real light (faded out
## with distance), on the ground beside the road (none on the bridges, where the ground's far below).
func _build_lamps(root: Node3D) -> void:
	var pk := ArabianKit.new_kit(1.0)
	var kit := {}
	ArabianKit.road_lamp(pk, kit, 7.0, 1)
	var mesh: ArrayMesh = d.save(ArabianKit.commit(pk, kit), "street_lamp") as ArrayMesh
	var node := Node3D.new()
	node.name = "StreetLamps"
	root.add_child(node)
	node.owner = level
	var xfs: Array = []
	var s := 8.0
	var k := 0
	while s < d.length:
		var p: Vector3 = d.curve.sample_baked(s)
		var q: Vector3 = d.curve.sample_baked(fmod(s + 2.0, d.length))
		var tan := q - p
		tan.y = 0.0
		tan = tan.normalized()
		var right := Vector3(-tan.z, 0.0, tan.x)
		var sd: float = 1.0 if k % 2 == 0 else -1.0
		k += 1
		var lp: Vector3 = p + right * sd * (d.road_half + 1.4)
		var g: float = d.ground(lp.x, lp.z)
		var ok: bool = absf(g - p.y) < 1.2 and d.road_dist(lp.x, lp.z, 30.0) > d.road_half + 0.8 and not _near_gate(Vector2(lp.x, lp.z), -6.0)
		for pa in palms_at:
			if Vector2(lp.x, lp.z).distance_to(pa) < 3.0:
				ok = false
		if ok:
			# The arm (local +x) reaches over the road.
			var arm := -right * sd
			var b := Basis(arm, Vector3.UP, arm.cross(Vector3.UP)).scaled(Vector3.ONE * PS)
			xfs.append(Transform3D(b, Vector3(lp.x, g - 0.1, lp.z)))
			var om := OmniLight3D.new()
			om.name = "LampLight_%d" % xfs.size()
			om.position = Vector3(lp.x, g, lp.z) + arm * 2.7 * PS + Vector3(0, 7.2 * PS, 0)
			om.light_color = Color(1.0, 0.82, 0.58)
			om.light_energy = 3.2
			om.omni_range = 34.0
			om.omni_attenuation = 1.2
			om.shadow_enabled = false
			om.distance_fade_enabled = true
			om.distance_fade_begin = 150.0
			om.distance_fade_length = 40.0
			om.set_meta(&"no_shadow", true)
			node.add_child(om)
			om.owner = level
		s += LAMP_EVERY
	d.scatter(node, mesh, xfs, "Lamps", 160.0, 900.0, 0.0, true, false)
	print("Street lamps: ", xfs.size())


func _build_palms(root: Node3D) -> void:
	# The roundabout island's planting ring.
	for k in range(10):
		var a: float = TAU * (float(k) + 0.5) / 10.0
		palms_at.append(RB_C + Vector2(cos(a), sin(a)) * (RB_ISLAND * 0.84))
	var palms := d.palms()
	var near_mats := palms.materials(1)
	var far_mats := palms.materials(2)
	var lists := {}
	for p in palms_at:
		var v: int = d.rng.randi() % 4
		if not lists.has(v):
			lists[v] = []
		lists[v].append(Transform3D(Basis(Vector3.UP, d.rng.randf() * TAU).scaled(Vector3.ONE * d.rng.randf_range(1.0, 1.2)), Vector3(p.x, d.ground(p.x, p.y) - 0.2, p.y)))
	for v in lists:
		var nm: ArrayMesh = d.save(palms.mesh(v, 0, near_mats), "datepalm_%d" % v) as ArrayMesh
		var fm: ArrayMesh = d.save(palms.mesh(v, 1, far_mats), "datepalm_far_%d" % v) as ArrayMesh
		d.scatter(root, nm, lists[v], "TallNear_palm%d" % v, 120.0, D.DatePalmKit.NEAR + D.DatePalmKit.FADE, 0.0, true, false)
		d.scatter(root, fm, lists[v], "Tall_palm%d" % v, 120.0, 1500.0, D.DatePalmKit.NEAR - D.DatePalmKit.FADE)
	print("Palms: ", palms_at.size())


## The balustrade along the sea and the creek's quays (solid: boxes along it), a bollard every few metres.
func _build_railings(root: Node3D) -> void:
	var pk := ArabianKit.new_kit(1.0)
	var kit := {}
	var body := StaticBody3D.new()
	body.name = "QuayRailBody"
	var segs := 0
	var runs: Array = []
	# The sea front, from west to east, 1.6m inland of the quay's edge.
	var line: Array = []
	var x := -900.0
	while x <= 900.0:
		line.append(Vector2(x, AT.coast_z(x) - 1.6))
		x += 4.0
	runs.append(line)
	# The creek's two quays, from the sea to the head.
	for sd in [-1.0, 1.0]:
		var l2: Array = []
		var z := 260.0
		while z > AT.MARINA_CREEK_HEAD:
			l2.append(Vector2(AT.creek_x(z) + sd * (AT.MARINA_CREEK_HALF + 1.6), z))
			z -= 4.0
		runs.append(l2)
	# The bridges' parapets: along both edges of the road wherever it crosses water (over its side walls).
	var bridge_runs: Array = []
	for sd in [-1.0, 1.0]:
		var cur: Array = []
		var s := 0.0
		while s < d.length:
			var p: Vector3 = d.curve.sample_baked(s)
			var q: Vector3 = d.curve.sample_baked(fmod(s + 1.0, d.length))
			var tan := q - p
			tan.y = 0.0
			tan = tan.normalized()
			var e: Vector3 = p + Vector3(-tan.z, 0.0, tan.x) * sd * (d.road_half - 0.3)
			if AT.marina_water_d(e.x, e.z) > -6.0:
				cur.append(Vector3(e.x, p.y + float(tg.road_y_offset), e.z))
			elif cur.size() > 1:
				bridge_runs.append(cur)
				cur = []
			else:
				cur = []
			s += 3.0
		if cur.size() > 1:
			bridge_runs.append(cur)
	for run in bridge_runs:
		for i in range(run.size() - 1):
			var a3: Vector3 = run[i]
			var b3: Vector3 = run[i + 1]
			pk.beam(kit, "stone", a3 + Vector3(0, 0.45, 0), b3 + Vector3(0, 0.45, 0), 0.45, 0.9, Color(0.80, 0.74, 0.64))
			pk.beam(kit, "metal", a3 + Vector3(0, 1.15, 0), b3 + Vector3(0, 1.15, 0), 0.12, 0.12, Color(0.75, 0.76, 0.78))
			var cs := CollisionShape3D.new()
			var sh := BoxShape3D.new()
			sh.size = Vector3(0.5, 1.6, a3.distance_to(b3) + 0.1)
			cs.shape = sh
			var dir := (b3 - a3).normalized()
			cs.transform = Transform3D(Basis(dir.cross(Vector3.UP).normalized(), Vector3.UP, dir).orthonormalized(), (a3 + b3) * 0.5 + Vector3(0, 0.8, 0))
			body.add_child(cs)
			segs += 1
	for run in runs:
		for i in range(run.size() - 1):
			var a: Vector2 = run[i]
			var b: Vector2 = run[i + 1]
			var m := (a + b) * 0.5
			if AT.marina_water_d(m.x, m.y) > -0.8 or d.road_dist(m.x, m.y, 30.0) < d.road_half + 1.5:
				continue
			var y: float = LAND
			var a3 := Vector3(a.x, y, a.y)
			var b3 := Vector3(b.x, y, b.y)
			pk.beam(kit, "stone", a3 + Vector3(0, 0.25, 0), b3 + Vector3(0, 0.25, 0), 0.4, 0.5, Color(0.78, 0.72, 0.62))
			pk.beam(kit, "stone", a3 + Vector3(0, 1.05, 0), b3 + Vector3(0, 1.05, 0), 0.32, 0.12, Color(0.86, 0.80, 0.70))
			for t in [0.25, 0.5, 0.75]:
				var bp: Vector3 = a3.lerp(b3, t)
				pk.box(kit, "stone", Transform3D(Basis(), bp + Vector3(0, 0.75, 0)), Vector3(0.14, 0.5, 0.14), Color(0.86, 0.80, 0.70))
			var cs := CollisionShape3D.new()
			var sh := BoxShape3D.new()
			sh.size = Vector3(0.45, 1.3, a.distance_to(b) + 0.1)
			cs.shape = sh
			var dir := (b3 - a3).normalized()
			cs.transform = Transform3D(Basis(dir.cross(Vector3.UP).normalized(), Vector3.UP, dir), (a3 + b3) * 0.5 + Vector3(0, 0.6, 0))
			body.add_child(cs)
			segs += 1
	var mi := MeshInstance3D.new()
	mi.name = "QuayRail"
	mi.mesh = d.save(ArabianKit.commit(pk, kit), "quay_rail")
	mi.visibility_range_end = 700.0
	body.add_child(mi)
	root.add_child(body)
	body.set_meta(&"surface", "rock")
	_own(body)
	print("Quay rail: ", segs, " pieces")


## The arch bridge where the north road crosses the creek: a steel arch rib either side of the deck, springing from
## stone piers on the quays, hangers down to the deck's edge, lights along the ribs. Named "CreekArch" (not
## "...Bridge": PlayerCart counts that as road).
func _build_arch(root: Node3D) -> void:
	var cross: float = d.curve.get_closest_offset(Vector3(AT.creek_x(NORTH_Z), BRIDGE_Y, NORTH_Z))
	var pk := ArabianKit.new_kit(1.0)
	var kit := {}
	var span := AT.MARINA_CREEK_HALF + 14.0
	var steel := Color(0.85, 0.86, 0.88)
	for sd in [-1.0, 1.0]:
		var pts: Array = []
		for i in range(25):
			var t: float = float(i) / 24.0
			var o: float = cross - span + 2.0 * span * t
			var p: Vector3 = d.curve.sample_baked(o)
			var q: Vector3 = d.curve.sample_baked(o + 1.0)
			var tan := q - p
			tan.y = 0.0
			tan = tan.normalized()
			var right := Vector3(-tan.z, 0.0, tan.x)
			var rise: float = 24.0 * sin(PI * t)
			pts.append([p + right * sd * (d.road_half + 1.2) + Vector3(0, rise, 0), p + right * sd * (d.road_half + 1.2)])
		for i in range(pts.size() - 1):
			pk.tube(kit, "metal", pts[i][0], pts[i + 1][0], 0.55, 0.55, 8, steel, false)
			if i % 2 == 1:
				pk.tube(kit, "metal", pts[i][0], pts[i][1], 0.07, 0.07, 5, steel)
				pk.box(kit, "lamp", Transform3D(Basis(), (pts[i][0] as Vector3) + Vector3(0, 0.7, 0)), Vector3(0.35, 0.2, 0.35), Color(0.75, 0.85, 1.0))
		# Piers on the quays under the arch's feet.
		for e in [0, pts.size() - 1]:
			var f: Vector3 = pts[e][1]
			pk.block(kit, "stone", Vector3(f.x - 1.6, LAND - 3.0, f.z - 1.6), Vector3(f.x + 1.6, f.y + 0.8, f.z + 1.6), Color(0.76, 0.70, 0.60))
	# Cross bracing over the middle.
	var mi := MeshInstance3D.new()
	mi.name = "CreekArch"
	mi.mesh = d.save(ArabianKit.commit(pk, kit), "creek_arch")
	root.add_child(mi)
	mi.owner = level


## Dhows moored along the creek's quays (the road's crossings kept clear), most strung with lights.
func _build_dhows(root: Node3D) -> void:
	var meshes: Array = []
	for v in range(3):
		var pk := ArabianKit.new_kit(1.0)
		var kit := {}
		var r := RandomNumberGenerator.new()
		r.seed = 300 + v
		ArabianKit.dhow(pk, kit, r, [17.0, 21.0, 14.0][v], v != 2)
		meshes.append(d.save(ArabianKit.commit(pk, kit), "dhow_%d" % v))
	var node := Node3D.new()
	node.name = "Dhows"
	root.add_child(node)
	node.owner = level
	var n := 0
	for sd in [-1.0, 1.0]:
		var z := 200.0
		while z > AT.MARINA_CREEK_HEAD + 30.0:
			var x: float = AT.creek_x(z) + sd * (AT.MARINA_CREEK_HALF - 7.0)
			if d.road_dist(x, z, 60.0) > 40.0:
				var v: int = d.rng.randi() % 3
				var t := Vector3(AT.creek_x(z - 2.0) - AT.creek_x(z + 2.0), 0, -4.0).normalized()
				var mi := MeshInstance3D.new()
				mi.name = "Dhow_%d" % n
				mi.mesh = meshes[v]
				mi.transform = Transform3D(Basis.looking_at(t * (1.0 if d.rng.randf() < 0.5 else -1.0), Vector3.UP).scaled(Vector3.ONE * PS),
						Vector3(x, -0.2, z))
				mi.visibility_range_end = 700.0
				node.add_child(mi)
				mi.owner = level
				n += 1
				z -= 34.0
			else:
				z -= 10.0
	print("Dhows: ", n)


## The city carries on past the terrain's edge, west, north and east: low blocks and towers with lit windows on a
## flat plain, out to the fog (the sea lies south). No colliders.
func _build_far_city(root: Node3D) -> void:
	var bc := GulfCity.new()
	bc.begin()
	var r := RandomNumberGenerator.new()
	r.seed = 6161
	for k in range(900):
		var c := Vector2(r.randf_range(-2600.0, 2600.0), r.randf_range(-2600.0, 400.0))
		if absf(c.x) < 1000.0 and absf(c.y) < 1000.0:
			continue
		if c.y > AT.coast_z(c.x) - 60.0:
			continue
		if r.randf() < 0.08:
			bc.gulf_tower(c.x, c.y, LAND, r.randf_range(22.0, 34.0), r.randf_range(80.0, 220.0), r.randi() % 5, r)
		else:
			bc.gulf_block(c.x, c.y, LAND, r.randf_range(25.0, 50.0), r.randf_range(20.0, 40.0), r.randf() * TAU, r.randi_range(2, 8),
					GulfCity.SAND_WALLS[r.randi() % GulfCity.SAND_WALLS.size()], r.randi() % 4, r)
	var mi := MeshInstance3D.new()
	mi.name = "FarCity"
	mi.mesh = d.save(bc.commit(_city_mat, _roof_mat), "far_city")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	mi.owner = level
	# The plain under it.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cells := 70
	for j in range(cells):
		for i in range(cells):
			var x0: float = -3500.0 + i * 100.0
			var z0: float = -3500.0 + j * 100.0
			var cx: float = x0 + 50.0
			var cz: float = z0 + 50.0
			if absf(cx) < 1000.0 and absf(cz) < 1000.0:
				continue
			if cz > AT.coast_z(cx) - 20.0:
				continue
			for q in [[Vector3(x0, LAND - 0.3, z0), Vector3(x0 + 100, LAND - 0.3, z0), Vector3(x0 + 100, LAND - 0.3, z0 + 100)],
					[Vector3(x0, LAND - 0.3, z0), Vector3(x0 + 100, LAND - 0.3, z0 + 100), Vector3(x0, LAND - 0.3, z0 + 100)]]:
				for v in q:
					st.set_normal(Vector3.UP)
					st.set_color(Color(0.20, 0.18, 0.16))
					st.add_vertex(v)
	var pm := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	pm.surface_set_material(0, mat)
	var pmi := MeshInstance3D.new()
	pmi.name = "FarGround"
	pmi.mesh = d.save(pm, "far_ground")
	pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pmi)
	pmi.owner = level


## Strings of bulbs across the souk's lanes every 12m, from house front to house front (4.5m up, sagging), and a
## warm light under every other one: the lanes glow.
func _souk_festoons(parent: Node3D) -> void:
	var pk := ArabianKit.new_kit(1.0)
	var kit := {}
	var cols := [Color(1.0, 0.75, 0.4), Color(1.0, 0.5, 0.3), Color(0.9, 0.9, 0.6), Color(0.6, 0.85, 1.0)]
	var s0: float = d.curve.get_closest_offset(Vector3(-70.0, ROAD_Y, -215.0))
	var s1: float = d.curve.get_closest_offset(Vector3(-256.0, ROAD_Y, -58.0))
	var s := s0
	var k := 0
	while s < s1:
		var p: Vector3 = d.curve.sample_baked(s)
		var q: Vector3 = d.curve.sample_baked(s + 1.0)
		var tan := q - p
		tan.y = 0.0
		tan = tan.normalized()
		var right := Vector3(-tan.z, 0.0, tan.x)
		var a: Vector3 = p + right * (d.road_half + 3.0) + Vector3(0, 6.0, 0)
		var b: Vector3 = p - right * (d.road_half + 3.0) + Vector3(0, 6.0, 0)
		a.y = LAND + 6.0
		b.y = LAND + 6.0
		var cnt := 18
		for i in range(cnt + 1):
			var t: float = float(i) / cnt
			var bp: Vector3 = a.lerp(b, t) - Vector3(0, sin(PI * t) * 1.4, 0)
			pk.box(kit, "lamp", Transform3D(Basis(), bp), Vector3(0.2, 0.2, 0.2), cols[(i + k) % cols.size()])
			if i < cnt:
				pk.beam(kit, "matte", bp, a.lerp(b, float(i + 1) / cnt) - Vector3(0, sin(PI * float(i + 1) / cnt) * 1.4, 0), 0.03, 0.03, Color(0.1, 0.1, 0.1))
		if k % 2 == 0:
			var om := OmniLight3D.new()
			om.name = "SoukLight_%d" % k
			om.position = p + Vector3(0, LAND + 4.2 - p.y + p.y - p.y, 0) + Vector3(0, 0, 0)
			om.position.y = LAND + 4.2
			om.light_color = Color(1.0, 0.7, 0.42)
			om.light_energy = 2.6
			om.omni_range = 20.0
			om.shadow_enabled = false
			om.distance_fade_enabled = true
			om.distance_fade_begin = 120.0
			om.distance_fade_length = 30.0
			om.set_meta(&"no_shadow", true)
			parent.add_child(om)
			om.owner = level
		k += 1
		s += 12.0
	var mi := MeshInstance3D.new()
	mi.name = "SoukFestoons"
	mi.mesh = d.save(ArabianKit.commit(pk, kit), "souk_festoons")
	mi.visibility_range_end = 500.0
	parent.add_child(mi)
	mi.owner = level
	print("Souk festoons: ", k)



const RB_ISLAND := 25.5     # the island's kerb radius

var ring_spots: Array = []
var ring_toe_s := 0.0
var ring_s := 0.0

## Where the Pearl Ring's kicker and the ring stand along the corniche (before the bake, so gates and planting keep
## clear of them), the kicker (WoodenRamp, as wide as the road, dark steel and gold) and the TrackPath's jump_lips.
func _plan_ring(path: Path3D) -> void:
	var curve := path.curve
	ring_toe_s = curve.get_closest_offset(Vector3(RING_TOE_X, ROAD_Y, AT.coast_z(RING_TOE_X) - CORNICHE_IN))
	var ramp: Node3D = (load("res://WoodenRamp.tscn") as PackedScene).instantiate()
	ramp.name = "PearlKicker"
	ramp.set("length", 14.0)
	ramp.set("height", 4.0)
	ramp.set("width", 16.0)
	ramp.set("curve", 0.6)
	ramp.set("wood_color", Color(0.30, 0.30, 0.34))
	ramp.set("trim_color", Color(0.86, 0.66, 0.28))
	var toe := curve.sample_baked(ring_toe_s)
	var ahead := curve.sample_baked(ring_toe_s + 2.0) - toe
	ahead.y = 0.0
	ramp.transform = Transform3D(Basis.looking_at(ahead.normalized(), Vector3.UP), toe)
	var jumps := Node3D.new()
	jumps.name = "Jumps"
	level.add_child(jumps)
	jumps.owner = level
	jumps.add_child(ramp)
	ramp.owner = level
	path.set_meta(&"jump_lips", [ramp.lip_info()])
	ring_s = ring_toe_s + 14.0 + RING_PAST_LIP
	var rp := curve.sample_baked(ring_s)
	ring_spots = [Vector2(toe.x, toe.z), Vector2(rp.x, rp.z)]
	print("Pearl Ring: kicker at s ", ring_toe_s, ", ring at s ", ring_s)


func _build_ring(root: Node3D) -> void:
	var p: Vector3 = d.curve.sample_baked(ring_s)
	var q: Vector3 = d.curve.sample_baked(ring_s + 2.0)
	var tan := q - p
	tan.y = 0.0
	tan = tan.normalized()
	var side := Vector3.UP.cross(tan).normalized()
	var basis := Basis(side, Vector3.UP, tan)
	var origin := Vector3(p.x, LAND, p.z)
	var pk := ArabianKit.new_kit(1.0)
	pk.set_frame(Transform3D(basis, origin))
	var kit := {}
	ArabianKit.pearl_ring(pk, kit, RING_RADIUS, RING_TUBE, RING_HC)
	var body := StaticBody3D.new()
	body.name = "PearlRing"
	body.set_meta(&"surface", "rock")
	root.add_child(body)
	var mi := MeshInstance3D.new()
	mi.name = "PearlRingMesh"
	mi.mesh = d.save(ArabianKit.commit(pk, kit), "pearl_ring")
	body.add_child(mi)
	# The ring's collider: a capsule along each of 32 arcs of the torus; the pylons.
	for i in range(32):
		var a0: float = TAU * i / 32.0
		var a1: float = TAU * (i + 1) / 32.0
		var c0 := Vector3(0, RING_HC, 0) + Vector3(cos(a0), sin(a0), 0) * RING_RADIUS
		var c1 := Vector3(0, RING_HC, 0) + Vector3(cos(a1), sin(a1), 0) * RING_RADIUS
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = RING_TUBE
		cap.height = c0.distance_to(c1) + RING_TUBE * 2.0
		cs.shape = cap
		var dir := (c1 - c0).normalized()
		var local := Transform3D(Basis(dir.cross(Vector3(0, 0, 1)).normalized(), dir, Vector3(0, 0, 1)).orthonormalized(), (c0 + c1) * 0.5)
		cs.transform = Transform3D(basis, origin) * local
		body.add_child(cs)
	for sx in [-1.0, 1.0]:
		var cs2 := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 1.8
		cyl.height = RING_HC + 1.0
		cs2.shape = cyl
		cs2.position = origin + basis * Vector3(sx * (RING_RADIUS + RING_TUBE + 0.9), (RING_HC + 1.0) * 0.5, 0)
		body.add_child(cs2)
	_own(body)
	# Uplights on the pylons.
	for sx in [-1.0, 1.0]:
		var l := OmniLight3D.new()
		l.position = origin + basis * Vector3(sx * (RING_RADIUS + RING_TUBE + 0.9), 3.0, 0)
		l.light_color = Color(1.0, 0.82, 0.5)
		l.light_energy = 3.0
		l.omni_range = 26.0
		l.shadow_enabled = false
		l.set_meta(&"no_shadow", true)
		root.add_child(l)
		l.owner = level
	print("Pearl Ring built")


## The roundabout's island: ArabianKit.fountain's stone, a FountainShow node for the water, jets and lights, a
## collider round the kerb (the island isn't for driving through).
func _build_roundabout(root: Node3D) -> void:
	var at := Vector3(RB_C.x, LAND, RB_C.y)
	var pk := ArabianKit.new_kit(1.0)
	pk.set_frame(Transform3D(Basis(), at))
	var kit := {}
	ArabianKit.fountain(pk, kit, RB_ISLAND)
	var body := StaticBody3D.new()
	body.name = "RoundaboutIsland"
	body.set_meta(&"surface", "rock")
	root.add_child(body)
	var mi := MeshInstance3D.new()
	mi.name = "FountainStone"
	mi.mesh = d.save(ArabianKit.commit(pk, kit), "fountain")
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = RB_ISLAND
	cyl.height = 4.0
	cs.shape = cyl
	cs.position = at + Vector3(0, 1.0, 0)
	body.add_child(cs)
	var cs2 := CollisionShape3D.new()
	var col2 := CylinderShape3D.new()
	col2.radius = 2.8
	col2.height = 14.0
	cs2.shape = col2
	cs2.position = at + Vector3(0, 7.0, 0)
	body.add_child(cs2)
	_own(body)
	var show := Node3D.new()
	show.name = "FountainShow"
	show.set_script(load("res://FountainShow.gd"))
	show.position = at
	show.set("basin_radius", RB_ISLAND * 0.68 - 0.1)
	show.set("ring_radius", RB_ISLAND * 0.68 - 2.2)
	root.add_child(show)
	show.owner = level
	print("Roundabout fountain at ", at)


## The marina east of the creek's mouth: pontoons out from the sea front with finger berths, sailing yachts and motor
## yachts in them, superyachts on the outer pontoon; two superyachts cruising offshore (SeaBoat, on the wall clock).
func _build_marina(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Marina"
	root.add_child(node)
	node.owner = level
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	# The boats' meshes.
	var meshes := {}
	for k in [["sail_blue", Color(0.12, 0.24, 0.48)], ["sail_red", Color(0.62, 0.14, 0.12)], ["sail_teal", Color(0.10, 0.42, 0.44)]]:
		var bpk := ShipKitRef.new_port_kit(1.0)
		var bkit := {}
		ShipKitRef.sailboat(bpk, bkit, k[1])
		meshes[k[0]] = d.save(PortKitRef.commit_port(bpk, bkit), "boat_" + String(k[0]))
	for k2 in [["super", 44.0], ["motor", 24.0]]:
		var ypk := ArabianKit.new_kit(1.0)
		var ykit := {}
		var yr := RandomNumberGenerator.new()
		yr.seed = int(float(k2[1]) * 13.0)
		ArabianKit.superyacht(ypk, ykit, yr, float(k2[1]))
		meshes[k2[0]] = d.save(ArabianKit.commit(ypk, ykit), "yacht_" + String(k2[0]))
	var pk := ArabianKit.new_kit(1.0)
	var kit := {}
	var x0 := 150.0
	var x1 := 370.0
	var off := 16.0        # the main pontoon this far out from the quay
	var finger := 26.0
	var main: Array = []
	var x := x0
	while x <= x1:
		main.append(Vector3(x, 0.45, AT.coast_z(x) + off))
		x += 10.0
	for i in range(main.size() - 1):
		ArabianKit.pontoon(pk, kit, main[i], main[i + 1], 3.0)
	# Gangways up to the quay.
	for gx in [x0 + 30.0, x1 - 30.0]:
		pk.beam(kit, "timber", Vector3(gx, LAND, AT.coast_z(gx) - 0.5), Vector3(gx, 0.5, AT.coast_z(gx) + off - 1.5), 2.0, 0.15, Color(0.5, 0.38, 0.26))
	var placed := 0
	x = x0 + 9.0
	while x <= x1 - 9.0:
		var base := Vector3(x, 0.45, AT.coast_z(x) + off + 1.5)
		ArabianKit.pontoon(pk, kit, base, base + Vector3(0, 0, finger), 1.6)
		# A boat either side of the finger (some berths empty).
		for sd in [-1.0, 1.0]:
			if rng.randf() < 0.2:
				continue
			var kind: String = ["sail_blue", "sail_red", "sail_teal", "motor", "sail_blue"][rng.randi() % 5]
			var mi := MeshInstance3D.new()
			mi.name = "Yacht_%d" % placed
			mi.mesh = meshes[kind]
			var bx: float = x + sd * 4.6
			var bz: float = base.z + finger * 0.5
			# Bows out to sea for the sailing yachts (their bow is +z), the motor yachts stern-to (bow -z).
			var yaw: float = 0.0 if kind.begins_with("sail") else PI
			mi.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * (PS if kind.begins_with("sail") else 1.0)), Vector3(bx, -0.15, bz))
			mi.visibility_range_end = 900.0
			node.add_child(mi)
			mi.owner = level
			placed += 1
		x += 18.0
	# The outer pontoon and the superyachts alongside it.
	var outer: Array = []
	x = x0
	while x <= x1:
		outer.append(Vector3(x, 0.45, AT.coast_z(x) + off + finger + 4.0))
		x += 10.0
	for i in range(outer.size() - 1):
		ArabianKit.pontoon(pk, kit, outer[i], outer[i + 1], 3.0)
	for k in range(3):
		var cx: float = lerpf(x0 + 40.0, x1 - 40.0, float(k) / 2.0)
		var mi2 := MeshInstance3D.new()
		mi2.name = "Superyacht_%d" % k
		mi2.mesh = meshes["super"]
		mi2.transform = Transform3D(Basis(Vector3.UP, PI * 0.5 * (1.0 if k % 2 == 0 else -1.0)), Vector3(cx, -0.25, AT.coast_z(cx) + off + finger + 13.0))
		mi2.visibility_range_end = 2000.0
		node.add_child(mi2)
		mi2.owner = level
	var pmi := MeshInstance3D.new()
	pmi.name = "Pontoons"
	pmi.mesh = d.save(ArabianKit.commit(pk, kit), "pontoons")
	pmi.visibility_range_end = 900.0
	node.add_child(pmi)
	pmi.owner = level
	# Cruising offshore: a superyacht and a motor yacht on long loops (their hulls turned bow +z for SeaBoat).
	var sb: Script = load("res://SeaBoat.gd")
	for c in [["CruisingSuperyacht", "super", Vector2(-150.0, 470.0), 0.0, 380.0, 70.0, 4.5, 0.0], ["CruisingMotorYacht", "motor", Vector2(250.0, 420.0), 90.0, 200.0, 45.0, 7.0, 0.4]]:
		var r := Node3D.new()
		r.name = "Boat"
		var hull := MeshInstance3D.new()
		hull.name = "Hull"
		hull.mesh = meshes[c[1]]
		hull.rotation.y = PI
		r.add_child(hull)
		hull.owner = r
		var ps := PackedScene.new()
		ps.pack(r)
		var path := "res://generated/marina_nights_boat_%s.tscn" % c[1]
		ResourceSaver.save(ps, path)
		r.free()
		var boat := Node3D.new()
		boat.set_script(sb)
		boat.name = c[0]
		var cc: Vector2 = c[2]
		boat.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(c[3]))), Vector3(cc.x, 0.0, cc.y))
		boat.set("model", load(path))
		boat.set("model_scale", 1.0)
		boat.set("draft", 0.0)
		boat.set("length", c[4])
		boat.set("turn_radius", c[5])
		boat.set("speed", c[6])
		boat.set("phase", c[7])
		boat.set("body_top", 12.0)
		boat.set("wake_width", 10.0)
		node.add_child(boat)
		boat.owner = level
	print("Marina: ", placed, " yachts in berths, 3 superyachts, 2 cruising")
