# regenerate_ramlat_hamra.gd
# Builds levels/RamlatHamraLevel.tscn, Ramlat Hamra (the red sands), the Al-Raihana GP's third stage: a desert road
# at sunset through a sea of linear dunes 50m high (ArabianTerrain.megadunes). It runs east along a salt corridor
# (sabkha) from the start, climbs over the ridge through the east saddle, west along the next corridor past Qasr
# al-Hamra (a palace hotel) and the camel herds, and back over the west saddle, where a kicker at the crest throws
# the carts down the dune's face. Jebel Sahar's scene is the template (its gates, grid and spawners); everything
# else is made here, and the ground is baked by TerrainGenerator (prefix "ramlat_hamra").
#
# Run: Godot --headless --path . res://regenerate_ramlat_hamra.tscn   (about a minute)
extends Node

const D = preload("res://ArabianDresser.gd")
const ArabianKit = preload("res://ArabianKit.gd")
const ArabianTerrain = preload("res://ArabianTerrain.gd")

const TEMPLATE := "res://levels/MountainLevel.tscn"
const LEVEL := "res://levels/RamlatHamraLevel.tscn"
const ROOT := "RamlatDressing"
const PS := 1.6
## The corridors' road height and their lines (z), the passes' x.
const ROAD_Y := 1.4
## Corridor A has two lanes (north eastbound from the start, south westbound back), corridor B one.
const LANE_AN := -125.0
const LANE_AS := -200.0
const CORRIDOR_B := 182.0
## The canyon road: the lap leaves the south lane at x 265 and snakes between LANE_AS - 28 and - 68 (into the foot of
## the southern ridge) round rock formations on the inside of each bend, back onto the lane at x -200. The straight
## off-road bypass (AlternativePaths/DuneBypass) runs on along the lane's line, flat sand: shorter, off-road.
const SNAKE := [Vector2(265, -204), Vector2(235, -228), Vector2(170, -268), Vector2(105, -228), Vector2(40, -268), Vector2(-25, -228),
	Vector2(-90, -268), Vector2(-150, -238)]
const BYPASS_X0 := 278.0
const BYPASS_X1 := -192.0

## The off-road crossings over the middle ridge (ArabianTerrain.MEGA_SADDLES): x.
const CROSS_MID := 40.0
const CROSS_E := 430.0
## The palace at the foot of the next ridge, square to the middle crossing: the lap comes down the dune toward
## its front and turns along its court.
const PALACE_AT := Vector2(40.0, 254.0)
const CAMP_Z := -162.5
const GATE_CLEAR := 16.0

var d := D.new()
var tg: Node3D
var level: Node3D
var gates: Array = []
var pads := PackedFloat32Array()


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	level = (load(TEMPLATE) as PackedScene).instantiate()
	level.name = "RamlatHamraLevel"
	add_child(level)
	for n in ["MountainDressing", "WorldEnvironment", "SunLight", "WeatherController"]:
		var old := level.get_node_or_null(n)
		if old:
			level.remove_child(old)
			old.free()
	tg = level.get_node("TerrainGenerator")
	tg.set("level_prefix", "ramlat_hamra")
	tg.set("track_layout_type", 0)
	tg.set("terrain_resolution", 900)
	tg.set("hill_height", 30.0)
	tg.set("flat_pads", PackedFloat32Array())
	var path: Path3D = level.get_node("TrackPath")
	path.transform = Transform3D.IDENTITY
	if path.has_meta(&"town_route"):
		path.remove_meta(&"town_route")
	path.curve = _lap_curve()
	print("Lap: ", path.curve.get_baked_length(), "m")
	_plan_gaps(path.curve)
	_place_gates(path.curve)
	_place_jumps_and_pads(path)

	d.setup(level, tg, 7373)
	for cp in level.get_node("Checkpoints").get_children():
		gates.append(Vector2(cp.global_position.x, cp.global_position.z))
	var fl: Node3D = level.get_node("FinishLine")
	gates.append(Vector2(fl.global_position.x, fl.global_position.z))
	_plan_pads()
	tg.set("flat_pads", pads)
	tg.generate_world()
	for child in tg.get_children():
		_own(child)
	level._align_start_and_spawns_to_track()
	var grid := level.get_node_or_null("FinishLine/SpawnPoints")
	if grid:
		_own(grid)
	d.setup(level, tg, 7373)

	var root := Node3D.new()
	root.name = ROOT
	level.add_child(root)
	root.owner = level
	root.set_script(load("res://CanyonDetail.gd"))
	_ground_and_sky()
	_build_palace(root)
	_build_camps(root)
	_build_camels(root)
	_build_posts(root)
	_build_flora(root)
	d.backdrop(root, 868.0, 3900.0, PI * 0.9, 0.7, 260.0, Color(0.88, 0.50, 0.30), Color(0.40, 0.30, 0.24))
	d.skyline(root, Vector2(2400.0, 1400.0), 0.0, 18)

	remove_child(level)
	var packed := PackedScene.new()
	var err := packed.pack(level)
	if err == OK:
		err = ResourceSaver.save(packed, LEVEL)
	print("Saved RamlatHamraLevel.tscn: ", err, " in ", (Time.get_ticks_msec() - t0) / 1000.0, "s")
	get_tree().quit(0 if err == OK else 1)


func _own(n: Node) -> void:
	n.owner = level
	if n.scene_file_path != "":
		return
	for c in n.get_children():
		_own(c)


## The dune's height under (x, z), smoothed over a few metres, never under the corridor's road: the
## off-road crossings follow the sand up and over the crest.
func _dune_y(x: float, z: float) -> float:
	var s := 0.0
	var w := 0.0
	for k in range(-2, 3):
		var y: float = tg.natural_height(x, z + k * 4.0)
		var wk: float = 1.0 - absf(k) / 3.0
		s += y * wk
		w += wk
	return maxf(ROAD_Y, s / w + 0.25)


## The lap, from the start eastbound in corridor A: north off-road over the middle ridge straight down at the
## palace, east along its court and corridor B, south off-road over the east ridge, west along corridor A's
## south lane (the kicker), the hairpin at the west end back onto the north lane. Catmull-Rom through the points
## (collinear handles, so no corners in the road).
func _lap_curve() -> Curve3D:
	var pts: Array = []
	for p in [Vector2(-340, LANE_AN), Vector2(-230, LANE_AN + 6), Vector2(-120, LANE_AN - 5), Vector2(-40, LANE_AN + 2), Vector2(10, LANE_AN + 8)]:
		pts.append(Vector3(p.x, ROAD_Y, p.y))
	# Over the middle ridge, heading north (the crest near z 15).
	for z in [-92.0, -66.0, -42.0, -20.0, 0.0, 18.0, 38.0, 60.0, 84.0, 110.0, 136.0]:
		var x: float = CROSS_MID + sin((z + 92.0) / 228.0 * TAU) * 5.0
		pts.append(Vector3(x, _dune_y(x, z), z))
	# Down onto the flat facing the palace, then east along its court.
	for p in [Vector2(CROSS_MID + 4, 162), Vector2(CROSS_MID + 40, CORRIDOR_B), Vector2(140, CORRIDOR_B - 4), Vector2(230, CORRIDOR_B + 5),
			Vector2(320, CORRIDOR_B - 6), Vector2(390, CORRIDOR_B - 12)]:
		pts.append(Vector3(p.x, ROAD_Y, p.y))
	# Over the east ridge, heading south.
	for z in [148.0, 118.0, 92.0, 66.0, 42.0, 18.0, -6.0, -30.0, -56.0, -84.0]:
		var x: float = CROSS_E + sin((148.0 - z) / 232.0 * TAU) * 7.0
		pts.append(Vector3(x, _dune_y(x, z), z))
	# Corridor A's south lane, west: the canyon road snaking south of the lane between rock formations
	# (SNAKE), back onto the lane, over the kicker.
	for p in [Vector2(CROSS_E - 4, -122), Vector2(CROSS_E - 40, LANE_AS + 8), Vector2(300, LANE_AS)]:
		pts.append(Vector3(p.x, ROAD_Y, p.y))
	for p in SNAKE:
		pts.append(Vector3(p.x, ROAD_Y, p.y))
	for p in [Vector2(-200, LANE_AS - 2), Vector2(-300, LANE_AS - 3), Vector2(-390, LANE_AS + 6)]:
		pts.append(Vector3(p.x, ROAD_Y, p.y))
	# The hairpin at the west end.
	for p in [Vector2(-440, -186), Vector2(-455, -160), Vector2(-430, -132)]:
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


## The off-road crossings: road gaps wherever the lap leaves the corridors' level (sand over the road, the asphalt
## breaking up toward it), as Bloombay's dunes.
const GAP_TAPER := 12.0
const GAP_LEAD := 10.0
var gaps_list: Array = []

func _plan_gaps(curve: Curve3D) -> void:
	var length := curve.get_baked_length()
	var on := false
	var g0 := 0.0
	var s := 0.0
	while s < length:
		var high: bool = curve.sample_baked(s).y > ROAD_Y + 0.6
		if high and not on:
			g0 = s
			on = true
		elif not high and on:
			gaps_list.append([g0 - 14.0, s + 14.0])
			on = false
		s += 1.0
	var gaps := PackedFloat32Array()
	for g in gaps_list:
		gaps.append_array(PackedFloat32Array([g[0], g[1]]))
	tg.set("road_gaps", gaps)
	tg.set("road_gap_taper", GAP_TAPER)
	tg.set("road_gap_ground", 0.06)
	tg.set("curbs_stop_at_gaps", true)
	tg.set("road_gap_drift", PackedFloat32Array())
	tg.set("road_gap_half_width", 0.0)
	var road_mat := ShaderMaterial.new()
	road_mat.shader = load("res://road_crumble.gdshader")
	road_mat.set_shader_parameter("asphalt_tex", load("res://materials/asphalt.png"))
	road_mat.set_shader_parameter("dirt_tex", load("res://materials/sand.png"))
	road_mat.set_shader_parameter("dirt_normal", load("res://materials/sand_normal.png"))
	road_mat.set_shader_parameter("dirt_tint", Color(0.86, 0.48, 0.28))
	road_mat.set_shader_parameter("dirt_tile", 1.0 / 0.12)
	var pairs := PackedVector2Array()
	for g in gaps_list:
		pairs.append(Vector2(g[0], g[1]))
	road_mat.set_shader_parameter("gaps", pairs)
	road_mat.set_shader_parameter("gap_count", pairs.size())
	road_mat.set_shader_parameter("taper", GAP_TAPER)
	road_mat.set_shader_parameter("lead", GAP_LEAD)
	road_mat.set_shader_parameter("road_width", float(tg.road_width))
	tg.set("road_material", road_mat)
	print("Off-road crossings: ", gaps_list)


func _in_gap(o: float, margin := 0.0) -> bool:
	for g in gaps_list:
		if o > float(g[0]) - margin and o < float(g[1]) + margin:
			return true
	return false


func _place_gates(curve: Curve3D) -> void:
	var length := curve.get_baked_length()
	var fl: Node3D = level.get_node("FinishLine")
	fl.position = curve.sample_baked(60.0)
	# The template's order: Halfway4 first after the start, Halfway1 last.
	var shares := {"Halfway4": 0.22, "Halfway3": 0.42, "Halfway2": 0.62, "Halfway1": 0.82}
	for cp in level.get_node("Checkpoints").get_children():
		if shares.has(str(cp.name)):
			var o: float = length * float(shares[str(cp.name)])
			# Not on a crossing (a gate on a dune's crest): on to the corridor past it.
			while _in_gap(o, 25.0) and o < length - 5.0:
				o += 5.0
			(cp as Node3D).position = curve.sample_baked(o)
	level._align_checkpoints_to_track()


## The kicker on the south lane (WoodenRamp, as wide as the road; it settles and faces the lap itself) with a boost
## pad before it, and boost pads on the corridors, none within 100m before a corner or a crossing.
func _place_jumps_and_pads(path: Path3D) -> void:
	var curve := path.curve
	var length := curve.get_baked_length()
	for n in ["Jumps", "BoostPads"]:
		var old := level.get_node_or_null(n)
		if old:
			level.remove_child(old)
			old.free()
	var toe_s: float = curve.get_closest_offset(Vector3(40.0, ROAD_Y, LANE_AS))
	var ramps := Node3D.new()
	ramps.name = "Jumps"
	level.add_child(ramps)
	ramps.owner = level
	var ramp: Node3D = (load("res://WoodenRamp.tscn") as PackedScene).instantiate()
	ramp.name = "SabkhaKicker"
	ramp.set("length", 16.0)
	ramp.set("height", 2.4)
	ramp.set("width", 16.0)
	ramp.set("curve", 0.6)
	var toe := curve.sample_baked(toe_s)
	var ahead := curve.sample_baked(toe_s + 2.0) - toe
	ahead.y = 0.0
	ramp.transform = Transform3D(Basis.looking_at(ahead.normalized(), Vector3.UP), toe)
	ramps.add_child(ramp)
	ramp.owner = level
	print("Kicker at s ", toe_s)
	var pads_node := Node3D.new()
	pads_node.name = "BoostPads"
	level.add_child(pads_node)
	pads_node.owner = level
	var bp: PackedScene = load("res://BoostPad.tscn")
	var spots := [[curve.get_closest_offset(Vector3(-250.0, ROAD_Y, LANE_AN)), "BoostPad_Start"],
		[curve.get_closest_offset(Vector3(170.0, ROAD_Y, CORRIDOR_B)), "BoostPad_Palace"],
		[toe_s - 45.0, "BoostPad_Kicker"]]
	for at in spots:
		var off: float = float(at[0])
		var p := curve.sample_baked(off)
		var q := curve.sample_baked(off + 2.0)
		var pad: Node3D = bp.instantiate()
		pad.name = at[1]
		pads_node.add_child(pad)
		pad.owner = level
		pad.transform = Transform3D(Basis.looking_at((q - p).normalized(), Vector3.UP), p + Vector3(0, 0.1, 0))
	path.set_meta(&"jump_lips", [ramp.lip_info()])


func _pad(c: Vector2, half: Vector2, yaw: float, blend: float) -> float:
	var rel: Vector2 = d.relief(c.x, c.y, maxf(half.x, half.y), true)
	var y: float = rel.x * 0.6 + rel.y * 0.4
	pads.append_array(PackedFloat32Array([c.x, c.y, half.x, half.y, yaw, y, blend]))
	return y


var palace_y := 0.0
var camp_sites: Array = []

func _plan_pads() -> void:
	# Cut into the ridge's foot: level with the corridor's ground at its front, its blend short of the road.
	var rel: Vector2 = d.relief(PALACE_AT.x, PALACE_AT.y, 60.0, true)
	palace_y = rel.x + 1.0
	pads.append_array(PackedFloat32Array([PALACE_AT.x, PALACE_AT.y, 60.0, 40.0, 0.0, palace_y, 10.0]))
	print("Palace pad at y ", palace_y, ", lap ", d.road_dist(PALACE_AT.x, PALACE_AT.y - 50.0, 80.0), "m from its front edge")
	d.note(PALACE_AT, 70.0)
	# Two camps between corridor A's lanes, seen from both.
	for c in [Vector2(-150.0, CAMP_Z), Vector2(230.0, CAMP_Z)]:
		camp_sites.append([c, _pad(c, Vector2(22.0, 10.0), 0.0, 5.0)])
		d.note(c, 24.0)


func _ground_and_sky() -> void:
	var pad_list: Array = []
	for o in range(0, pads.size() - 6, 7):
		pad_list.append([Vector2(pads[o], pads[o + 1]), Vector2(pads[o + 2], pads[o + 3])])
	var map: Texture2D = d.ground_map(512, 1000.0, func(x: float, z: float) -> Color:
		var yard := 0.0
		for p in pad_list:
			var q: Vector2 = (Vector2(x, z) - (p[0] as Vector2)).abs() - (p[1] as Vector2)
			var out: float = Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0)
			yard = maxf(yard, 1.0 - smoothstep(-6.0, 4.0, out))
		var rd: float = d.road_dist(x, z, 30.0)
		var verge: float = 1.0 - smoothstep(d.road_half + 0.5, d.road_half + 6.0, rd)
		return Color(0.0, verge * 0.7, yard, 1.0))
	var mat := d.ground_material(map, 1000.0, {
		"rock_height": 1000.0, "rock_slope": 0.95, "high_slope": 0.9, "salt_height": 3.0,
		"sand_light": Color(0.92, 0.56, 0.34), "sand_deep": Color(0.76, 0.38, 0.22), "sand_pale": Color(0.96, 0.70, 0.50),
		"gravel_tint": Color(0.80, 0.62, 0.48), "ripple_strength": 0.7,
	})
	tg.set("grass_material", mat)
	(tg.get_node("Terrain_Visual") as MeshInstance3D).material_override = mat
	# Sunset: the sun low in the west, the dunes' crests lit red and their lee faces in deep shadow.
	d.environment(Vector3(-11.0, -84.0, 0.0), Color(0.92, 0.70, 0.52), Color(1.0, 0.70, 0.46), 1.35, 0.16, 4200.0)


func _build_palace(root: Node3D) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 4040
	# The court faces the road (-z in its frame toward -z in the world: the corridor lies south of it).
	d.building(root, "QasrHamra", PALACE_AT.x, PALACE_AT.y + 8.0, palace_y, 0.0, func(pk, kit) -> void:
		ArabianKit.palace(pk, kit, r), 2400.0)
	# Its garden: palms round the court and behind the wings.
	var palms := d.palms()
	var lists := {}
	for k in range(70):
		var q: Vector2 = PALACE_AT + Vector2(r.randf_range(-95.0, 95.0), r.randf_range(-40.0, 40.0))
		var lx: float = absf(q.x - PALACE_AT.x)
		var lz: float = q.y - PALACE_AT.y
		if lx < 62.0 and lz > -40.0:
			continue     # the buildings and the court
		if d.road_dist(q.x, q.y, 40.0) < d.road_half + 9.0:
			continue
		var v: int = r.randi() % 4
		if not lists.has(v):
			lists[v] = []
		lists[v].append(d.stand(q.x, q.y, r.randf_range(1.0, 1.25), 0.25, 0.03))
	# An avenue of palms along the court's sides.
	for k in range(7):
		for sx in [-1.0, 1.0]:
			var q: Vector2 = PALACE_AT + Vector2(sx * 52.0, -22.0 + k * 9.0)
			var v2: int = (k + int(sx > 0)) % 4
			if not lists.has(v2):
				lists[v2] = []
			lists[v2].append(Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * 1.1), Vector3(q.x, d.ground(q.x, q.y) - 0.2, q.y)))
	var near_mats := palms.materials(1)
	var far_mats := palms.materials(2)
	for v in lists:
		var nm: ArrayMesh = d.save(palms.mesh(v, 0, near_mats), "datepalm_%d" % v) as ArrayMesh
		var fm: ArrayMesh = d.save(palms.mesh(v, 1, far_mats), "datepalm_far_%d" % v) as ArrayMesh
		d.scatter(root, nm, lists[v], "TallNear_palm%d" % v, 120.0, D.DatePalmKit.NEAR + D.DatePalmKit.FADE, 0.0, true, false)
		d.scatter(root, fm, lists[v], "Tall_palm%d" % v, 120.0, 1500.0, D.DatePalmKit.NEAR - D.DatePalmKit.FADE)


func _build_camps(root: Node3D) -> void:
	var i := 0
	for cs in camp_sites:
		var c: Vector2 = cs[0]
		for k in range(2):
			var r := RandomNumberGenerator.new()
			r.seed = 600 + i * 7 + k
			var off := Vector2(-11.0 + k * 22.0, r.randf_range(-1.0, 1.0))
			d.building(root, "BedouinTent_%d_%d" % [i, k], c.x + off.x, c.y + off.y, float(cs[1]) - 0.03, (PI if k == 1 else 0.0) + r.randf_range(-0.1, 0.1), func(pk, kit) -> void:
				ArabianKit.bedouin_tent(pk, kit, r, 2), 900.0)
		i += 1


## Camels: herds grazing on the corridors' far sides, couched round the camps.
func _build_camels(root: Node3D) -> void:
	var meshes: Array = []
	for v in range(4):
		var pk := ArabianKit.new_kit(1.0)
		var kit := {}
		var r := RandomNumberGenerator.new()
		r.seed = 800 + v
		ArabianKit.camel(pk, kit, r, v >= 2, v % 2 == 1)
		meshes.append(d.save(ArabianKit.commit(pk, kit), "camel_%d" % v))
	var lists: Array = [[], [], [], []]
	var r := d.rng
	var herds: Array = [Vector2(60.0, CAMP_Z), Vector2(-300.0, CAMP_Z), Vector2(260.0, 140.0), Vector2(-150.0, 160.0), Vector2(-280.0, 150.0), Vector2(300.0, 228.0)]
	for cs in camp_sites:
		herds.append((cs[0] as Vector2) + Vector2(36.0, 0.0))
	var n := 0
	for hi in range(herds.size()):
		var hc: Vector2 = herds[hi]
		var count: int = r.randi_range(4, 9)
		for k in range(count):
			var q: Vector2 = hc + Vector2(r.randf_range(-24.0, 24.0), r.randf_range(-8.0, 8.0))
			if d.road_dist(q.x, q.y, 40.0) < d.road_half + 12.0 or not d.is_free(q, 2.0):
				continue
			var couched: bool = hi >= 6 or r.randf() < 0.3
			var v: int = (2 if couched else 0) + (1 if r.randf() < 0.3 else 0)
			lists[v].append(Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * PS), Vector3(q.x, d.ground(q.x, q.y) - 0.03, q.y)))
			d.note(q, 2.5)
			n += 1
	for v in range(4):
		d.scatter(root, meshes[v], lists[v], "Tall_camel%d" % v, 160.0, 700.0)
	print("Camels: ", n)


## Reflector posts along the road's edges, every 40m each side (white, an orange band at the top).
func _build_posts(root: Node3D) -> void:
	var pk := ArabianKit.new_kit(1.0)
	var kit := {}
	pk.block(kit, "matte", Vector3(-0.07, -0.3, -0.05), Vector3(0.07, 1.2, 0.05), Color(0.94, 0.94, 0.92))
	pk.block(kit, "lamp", Vector3(-0.072, 0.95, -0.052), Vector3(0.072, 1.12, 0.052), Color(1.0, 0.45, 0.1))
	var mesh: ArrayMesh = d.save(ArabianKit.commit(pk, kit), "reflector_post") as ArrayMesh
	var xfs: Array = []
	var s := 10.0
	while s < d.length:
		var p: Vector3 = d.curve.sample_baked(s)
		var q: Vector3 = d.curve.sample_baked(fmod(s + 2.0, d.length))
		var tan := q - p
		tan.y = 0.0
		tan = tan.normalized()
		var right := Vector3(-tan.z, 0, tan.x)
		if _in_gap(s, GAP_TAPER):
			s += 40.0
			continue
		for sd in [-1.0, 1.0]:
			var lp: Vector3 = p + right * sd * (d.road_half + 1.6)
			var g: float = d.ground(lp.x, lp.z)
			var ok: bool = absf(g - p.y) < 1.5 and d.road_dist(lp.x, lp.z, 20.0) > d.road_half + 1.0
			for gt in gates:
				if Vector2(lp.x, lp.z).distance_to(gt) < 10.0:
					ok = false
			if ok:
				xfs.append(Transform3D(Basis(Vector3.UP, atan2(tan.x, tan.z)).scaled(Vector3.ONE * PS), Vector3(lp.x, g - 0.05, lp.z)))
		s += 40.0
	d.scatter(root, mesh, xfs, "Rocks_post", 160.0, 420.0, 0.0, false)
	print("Posts: ", xfs.size())


func _build_flora(root: Node3D) -> void:
	var tufts: Array = [[], [], []]
	var brooms: Array = [[], []]
	var ghaf: Array = [[], []]
	var r := d.rng
	for k in range(3600):
		var c := Vector2(r.randf_range(-860, 860), r.randf_range(-860, 860))
		if c.length() > 860.0 or d.slope(c.x, c.y) > 0.4:
			continue
		# Little grows on the salt; grass and broom on the ridges' feet and flanks.
		if ArabianTerrain.sabkha(c.x, c.y) > 0.6 and r.randf() < 0.85:
			continue
		for j in range(r.randi_range(2, 7)):
			var q: Vector2 = c + Vector2.from_angle(r.randf() * TAU) * r.randf_range(0.0, 5.0)
			if d.road_dist(q.x, q.y, 20.0) < d.road_half + 1.5 or not d.is_free(q, 1.0):
				continue
			tufts[r.randi() % 3].append(d.stand(q.x, q.y, r.randf_range(0.9, 1.6), 0.06))
		if r.randf() < 0.3 and d.road_dist(c.x, c.y, 20.0) > d.road_half + 3.0:
			brooms[r.randi() % 2].append(d.stand(c.x, c.y, r.randf_range(0.8, 1.3), 0.1))
	for k in range(500):
		var c := Vector2(r.randf_range(-860, 860), r.randf_range(-860, 860))
		if c.length() > 860.0 or d.slope(c.x, c.y) > 0.25 or d.road_dist(c.x, c.y, 30.0) < d.road_half + 8.0 or not d.is_free(c, 4.0):
			continue
		if ArabianTerrain.sabkha(c.x, c.y) > 0.5 and r.randf() < 0.7:
			continue
		ghaf[r.randi() % 2].append(d.stand(c.x, c.y, r.randf_range(0.8, 1.15), 0.3, 0.06))
		d.note(c, 3.5)
	for v in range(3):
		d.scatter(root, d.save(d.tuft_mesh(v), "tuft_%d" % v) as Mesh, tufts[v], "Plants_grass%d" % v, 96.0, 260.0, 0.0, false)
	for v in range(2):
		d.scatter(root, d.save(d.broom_mesh(v), "broom_%d" % v) as Mesh, brooms[v], "Plants_broom%d" % v, 96.0, 360.0, 0.0, false)
	var w := d.woods()
	var leaf_near := w.leaf_material(1, 0.1, 10.0)
	var leaf_far := w.leaf_material(2, 0.1, 10.0)
	for lm in [leaf_near, leaf_far]:
		lm.set_shader_parameter("desaturate", 0.55)
		lm.set_shader_parameter("backlight_color", Color(0.48, 0.50, 0.34))
	var bark_n := w.bark_material("ghaf", 1)
	var bark_f := w.bark_material("ghaf", 2)
	for v in range(2):
		var nm: ArrayMesh = d.save(w.broadleaf_mesh("ghaf", v, 0, bark_n, leaf_near), "ghaf_%d" % v) as ArrayMesh
		var fm: ArrayMesh = d.save(w.broadleaf_mesh("ghaf", v, 1, bark_f, leaf_far), "ghaf_far_%d" % v) as ArrayMesh
		d.scatter(root, nm, ghaf[v], "TallNear_ghaf%d" % v, 120.0, 140.0, 0.0, true, false)
		d.scatter(root, fm, ghaf[v], "Tall_ghaf%d" % v, 120.0, 1400.0, 90.0)
	print("Flora: ", tufts[0].size() + tufts[1].size() + tufts[2].size(), " tufts, ", ghaf[0].size() + ghaf[1].size(), " ghaf")
