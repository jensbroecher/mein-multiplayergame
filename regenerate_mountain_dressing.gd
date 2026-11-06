# regenerate_mountain_dressing.gd
# Dresses levels/MountainLevel.tscn (Mountain Pass, the Al-Raihana GP's first stage) as a jebel in a fictional
# Gulf country, keeping the lap exactly as it is: the old imported rocks, ridges, sand "dunes", plants and the
# tower (FBX/GLB) are removed, the TerrainGenerator re-bakes the ground (ArabianTerrain: real dunes on the plain,
# spurs and gullies on the mountain) with level pads for what stands on it, and MountainDressing is built:
#   - Qal'at as-Sahar, a mud-brick fort on the summit, and watchtowers on the spurs over the road;
#   - a village at the mountain's foot north of the start (courtyard houses with wind towers) in its date gardens;
#   - a Bedouin camp in the dunes to the west;
#   - the road's lamps (tall twin-armed masts, on the outside of the bends);
#   - date palms, ghaf and umbrella thorns, dune grass and broom bushes, boulders on the rock;
#   - the country past the rim (dunes, a range to the south) and a modern city on the north-east horizon.
# Everything under MountainDressing is replaced on every run (about a minute: the bake is 45s).
#
# Run: Godot --headless --path . res://regenerate_mountain_dressing.tscn
extends Node

const D = preload("res://ArabianDresser.gd")
const ArabianKit = preload("res://ArabianKit.gd")
const ArabianTerrain = preload("res://ArabianTerrain.gd")

const LEVEL := "res://levels/MountainLevel.tscn"
const ROOT := "MountainDressing"
const OLD := ["WeatherController", "SandDunes", "LevelDesign", "Ridges", "WorldEnvironment", "SunLight", ROOT]
const PS := 1.6
## The summit fort: life-size side, at the cone's top.
const FORT_SIDE := 32.0
const FORT_AT := Vector2(0.0, 0.0)
const FORT_Y := 131.2
const FORT_YAW := 0.873
## The village: a box of the plain north of the start straight, and its date gardens.
const VILLAGE_BOX := Rect2(-220.0, -620.0, 500.0, 310.0)
const VILLAGE_HOUSES := 22
const VILLAGE_C := Vector2(-84.16, -440.89)
const VILLAGE_HALF := Vector2(110.0, 62.0)
const VILLAGE_BLEND := 28.0
const CAMP_BOX := Rect2(-520.0, -150.0, 170.0, 330.0)
const TOWERS := 7
const LAMP_EVERY := 46.0
const LAMP_LAT := 11.8
const GATE_CLEAR := 16.0

var d := D.new()
var tg: Node3D
var level: Node3D
var gates: Array = []
var pads := PackedFloat32Array()
var sites := {}          # name -> Array of [Vector2 centre, y, yaw, radius]


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	level = (load(LEVEL) as PackedScene).instantiate()
	add_child(level)
	tg = level.get_node("TerrainGenerator")
	d.setup(level, tg, 4141)
	print("Removed: ", d.strip(OLD))
	_reshape_lap()
	d.setup(level, tg, 4141)
	_town_checkpoint()
	for n in level.get_children():
		if n.name == "ArrowSign" or n.name == "Tower":
			print("  (also) ", n.name)
	for cp in level.get_node("Checkpoints").get_children():
		gates.append(Vector2(cp.global_position.x, cp.global_position.z))
	var fl: Node3D = level.get_node("FinishLine")
	gates.append(Vector2(fl.global_position.x, fl.global_position.z))
	for sp in level.find_children("Spawn*", "Marker3D", true, false):
		gates.append(Vector2((sp as Node3D).global_position.x, (sp as Node3D).global_position.z))

	_plan_sites()
	_plan_road_gaps()
	tg.set("flat_pads", pads)
	print("Pads: ", pads.size() / 7, "; baking the ground...")
	tg.generate_world()
	for child in tg.get_children():
		_own(child)
	_stone_road_sides()
	# The grid stays where it is (the finish straight is unchanged); keep it owned, or the level saves no spawns.
	var grid := level.get_node_or_null("FinishLine/SpawnPoints")
	if grid:
		_own(grid)
	d.setup(level, tg, 4141)   # the ground exists now

	var root := Node3D.new()
	root.name = ROOT
	level.add_child(root)
	root.owner = level
	root.set_script(load("res://CanyonDetail.gd"))

	_ground_and_sky()
	_build_fort(root)
	_build_towers(root)
	_build_village(root)
	_build_camp(root)
	_build_lamps(root)
	_build_flora(root)
	_build_rocks(root)
	_build_arrow_sign(root)
	_build_rock_formations(root)
	_build_sand_fx(root)
	# Airliners: arrivals down past the lap's north-west flank to the city, departures out past its south-east, away
	# from the ranges to the south.
	d.airliners(root, Vector2(1700.0, -2300.0), -1.0, 0.6, 0.7, 0.0, 300.0, 550.0, 115.0, 6000.0)
	d.backdrop(root, 868.0, 3900.0, PI * 0.5, 1.1, 420.0, Color(0.86, 0.62, 0.40), Color(0.36, 0.29, 0.24))
	d.skyline(root, Vector2(1700.0, -2300.0), 0.0, 26)

	remove_child(level)
	var packed := PackedScene.new()
	var err := packed.pack(level)
	if err == OK:
		err = ResourceSaver.save(packed, LEVEL)
	print("Saved MountainLevel.tscn: ", err, " in ", (Time.get_ticks_msec() - t0) / 1000.0, "s")
	get_tree().quit(0 if err == OK else 1)


func _own(n: Node) -> void:
	n.owner = level
	if n.scene_file_path != "":
		return
	for c in n.get_children():
		_own(c)


## Clear of the lap (in plan), the gates and everything noted.
func _clear(c: Vector2, r: float, road := 10.0) -> bool:
	if d.road_dist(c.x, c.y, r + d.road_half + road + 30.0) < r + d.road_half + road:
		return false
	for g in gates:
		if c.distance_to(g) < r + GATE_CLEAR:
			return false
	return d.is_free(c, r)


## Whether a rectangle (axis-aligned, half extents `half`) keeps `clear` metres off the lap's centreline.
func _rect_clear(c: Vector2, half: Vector2, clear: float) -> bool:
	var x := -half.x
	while x <= half.x:
		var z := -half.y
		while z <= half.y:
			if d.road_dist(c.x + x, c.y + z, clear + 30.0) < clear:
				return false
			z += 10.0
		x += 10.0
	return true


func _pad(c: Vector2, half: Vector2, yaw: float, blend: float) -> float:
	var rel: Vector2 = d.relief(c.x, c.y, maxf(half.x, half.y), true)
	var y: float = (rel.x + rel.y) * 0.5
	pads.append_array(PackedFloat32Array([c.x, c.y, half.x, half.y, yaw, y, blend]))
	return y


# ======================================================================================
#  Sites, planned on the natural ground before the bake
# ======================================================================================

func _plan_sites() -> void:
	# The summit fort.
	# Level with the summit road that now runs round it (SUMMIT), a couple of metres over it.
	# The pad holds the corner towers (all but their rubble plinths' flare, 44m out along its diagonals at game size).
	# One diagonal points at the summit road (bearing -95, 61m out): at 35m the pad's corner and blend raised the ground
	# over the asphalt's edge there; at 30m its blend has faded out before the road.
	var fhalf := 30.0
	var fy := FORT_Y
	pads.append_array(PackedFloat32Array([FORT_AT.x, FORT_AT.y, fhalf, fhalf, FORT_YAW, fy, 12.0]))
	sites["fort"] = [[FORT_AT, fy, FORT_YAW, fhalf]]
	d.note(FORT_AT, fhalf + 12.0)
	print("Fort at ", FORT_AT, " y ", fy, ", lap ", d.road_dist(0, 0, 200.0), "m off")
	# Watchtowers on the spurs: high points over their neighbours, near enough to the road to be seen.
	var towers: Array = []
	var tries := 0
	while towers.size() < TOWERS and tries < 4000:
		tries += 1
		var a: float = d.rng.randf() * TAU
		var r: float = d.rng.randf_range(90.0, 300.0)
		var c := Vector2.from_angle(a) * r
		var rd: float = d.road_dist(c.x, c.y, 140.0)
		if rd < 30.0 or rd > 170.0 or not _clear(c, 10.0, 20.0):
			continue
		var y: float = tg.natural_height(c.x, c.y)
		var around: Vector2 = d.relief(c.x, c.y, 16.0, true)
		if y < around.y - 4.0 or y < 20.0:
			continue
		var ok := true
		for t in towers:
			if c.distance_to(t[0]) < 105.0:
				ok = false
		if not ok:
			continue
		var ty := _pad(c, Vector2(6.5, 6.5), 0.0, 6.0)
		towers.append([c, ty, d.rng.randf() * TAU, 8.0])
		d.note(c, 9.0)
	sites["towers"] = towers
	print("Watchtowers: ", towers.size())
	# The village: one broad terrace graded into the plain, the lap's off-road section winding through it (TOWN),
	# the houses lining its street, fronts to it, a few further back; the date gardens round it.
	var vy := _pad(VILLAGE_C, VILLAGE_HALF, 0.0, VILLAGE_BLEND)
	sites["village"] = [VILLAGE_C, vy]
	var houses: Array = []
	tries = 0
	while houses.size() < VILLAGE_HOUSES and tries < 20000:
		tries += 1
		var c := VILLAGE_C + Vector2(d.rng.randf_range(-VILLAGE_HALF.x + 12.0, VILLAGE_HALF.x - 12.0), d.rng.randf_range(-VILLAGE_HALF.y + 12.0, VILLAGE_HALF.y - 12.0))
		var near: Array = d.road_near(c.x, c.y, 80.0)
		var dist: float = near[0]
		var w: float = d.rng.randf_range(8.5, 11.5)
		var dd: float = d.rng.randf_range(7.0, 9.0)
		var front: float = dd * 0.5 * PS
		var street: bool = houses.size() < VILLAGE_HOUSES * 0.8
		if dist < d.road_half + 3.5 + front or dist > (d.road_half + 12.0 + front if street else 60.0):
			continue
		var to_road: Vector2 = Vector2((near[1] as Vector3).x, (near[1] as Vector3).z) - c
		var yaw: float = atan2(-to_road.x, -to_road.y)
		var fwd := Vector2(-sin(yaw), -cos(yaw))
		var side := Vector2(fwd.y, -fwd.x)
		var ok := true
		var yard := true
		for k in range(4):
			var back: float = front + (9.0 * PS if k >= 2 else 0.0)
			for sg in [-1.0, 1.0]:
				var q: Vector2 = c + (fwd * front if k == 0 else -fwd * back) + side * sg * w * 0.5 * PS
				var bad: bool = d.road_dist(q.x, q.y, 40.0) < d.road_half + 2.5 or absf(q.x - VILLAGE_C.x) > VILLAGE_HALF.x or absf(q.y - VILLAGE_C.y) > VILLAGE_HALF.y
				if bad and k >= 2:
					yard = false
				elif bad:
					ok = false
		var rad: float = Vector2(w * 0.5, dd * 0.5 + (6.0 if yard else 0.5)).length() * PS
		if not ok or not d.is_free(c, rad * 0.75):
			continue
		houses.append([c, vy, yaw, rad, w, dd, yard])
		d.note(c, rad * 0.75)
	sites["houses"] = houses
	print("Village houses: ", houses.size(), " (terrace y ", vy, ")")
	# A second, smaller fort guarding the village: a watchtower pair beside a walled compound.
	var camp: Array = []
	tries = 0
	while camp.size() < 3 and tries < 3000:
		tries += 1
		var c := Vector2(d.rng.randf_range(CAMP_BOX.position.x, CAMP_BOX.end.x), d.rng.randf_range(CAMP_BOX.position.y, CAMP_BOX.end.y))
		if not _clear(c, 18.0, 30.0):
			continue
		var rel: Vector2 = d.relief(c.x, c.y, 16.0, true)
		if rel.y - rel.x > 5.0:
			continue
		var ok := true
		for o in camp:
			if c.distance_to(o[0]) < 38.0:
				ok = false
		if not ok:
			continue
		var yaw: float = d.rng.randf() * TAU
		var y := _pad(c, Vector2(16.0, 14.0), yaw, 10.0)
		camp.append([c, y, yaw, 18.0])
		d.note(c, 18.0)
	sites["camp"] = camp
	print("Camp tents: ", camp.size())


# ======================================================================================
#  The ground, the sky
# ======================================================================================

func _ground_and_sky() -> void:
	var pad_list: Array = []
	for o in range(0, pads.size() - 6, 7):
		pad_list.append([Vector2(pads[o], pads[o + 1]), maxf(pads[o + 2], pads[o + 3])])
	var map: Texture2D = d.ground_map(1024, 1000.0, func(x: float, z: float) -> Color:
		var yard := 0.0
		for p in pad_list:
			var dist: float = (p[0] as Vector2).distance_to(Vector2(x, z))
			yard = maxf(yard, 1.0 - smoothstep(float(p[1]) * 0.75, float(p[1]) + 4.0, dist))
		var r: float = Vector2(x, z).length()
		var gravel: float = ArabianTerrain.serir(x, z) * smoothstep(300.0, 380.0, r)
		# The verge of the road: swept gravel a few metres past the kerbs.
		var near: Array = d.road_near(x, z, 30.0)
		if not _in_gap(float(near[2]), GAP_TAPER + GAP_LEAD):
			gravel = maxf(gravel, 1.0 - smoothstep(d.road_half + 1.0, d.road_half + 9.0, float(near[0])))
		return Color(_rock_at(x, z), gravel, yard, 1.0))
	var mat := d.ground_material(map, 1000.0, {
		"map_rock": true, "use_piste_map": true, "piste_map": _piste_map(), "piste_in": 5.0, "piste_reach": 10.0,
		"piste_tint": Color(0.66, 0.50, 0.36),
		"rock_height": 30.0, "rock_slope": 0.34, "high_slope": 0.05,
		"sand_light": Color(0.94, 0.70, 0.46), "sand_deep": Color(0.84, 0.54, 0.32), "gravel_tint": Color(0.80, 0.66, 0.52),
	})
	tg.set("grass_material", mat)
	var tv: MeshInstance3D = tg.get_node("Terrain_Visual")
	tv.material_override = mat
	# Late afternoon, the sun low in the west: long shadows across the dunes, the jebel's east face in shade.
	d.environment(Vector3(-24.0, -96.0, 0.0), Color(0.88, 0.78, 0.64), Color(1.0, 0.86, 0.66), 1.5, 0.1)


# ======================================================================================
#  Buildings
# ======================================================================================

func _build_fort(root: Node3D) -> void:
	var s: Array = sites["fort"][0]
	var c: Vector2 = s[0]
	var r := RandomNumberGenerator.new()
	r.seed = 77
	# The gate faces the summit road's hairpin.
	d.building(root, "FortSahar", c.x, c.y, float(s[1]), float(s[2]), func(pk, kit) -> void:
		ArabianKit.fort(pk, kit, r, FORT_SIDE, 8.0), 2600.0)


func _build_towers(root: Node3D) -> void:
	var i := 0
	for t in sites["towers"]:
		var c: Vector2 = t[0]
		var h: float = d.rng.randf_range(9.0, 12.5)
		d.building(root, "Watchtower_%d" % i, c.x, c.y, float(t[1]) - 0.1, float(t[2]), func(pk, kit) -> void:
			ArabianKit.watchtower(pk, kit, h, d.rng.randf_range(2.6, 3.2)), 1800.0)
		i += 1


func _build_village(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Village"
	root.add_child(node)
	node.owner = level
	var i := 0
	var garden: Array = []
	for h in sites["houses"]:
		var c: Vector2 = h[0]
		var r := RandomNumberGenerator.new()
		r.seed = 500 + i
		var storeys: int = 2 if r.randf() < 0.45 else 1
		var key: String = "mud" if r.randf() < 0.55 else "lime"
		d.building(node, "House_%d" % i, c.x, c.y, float(h[1]), float(h[2]), func(pk, kit) -> void:
			ArabianKit.house(pk, kit, r, float(h[4]), float(h[5]), storeys, key, r.randf() < 0.7, h.size() < 7 or bool(h[6])), 1100.0)
		# A barasti hut and palms in the yard behind some.
		var back := Vector2(sin(float(h[2])), cos(float(h[2])))
		if r.randf() < 0.4:
			var hc: Vector2 = c - back * (float(h[3]) + 6.0)
			if _clear(hc, 6.0, 10.0):
				d.building(node, "Barasti_%d" % i, hc.x, hc.y, d.ground(hc.x, hc.y) - 0.05, float(h[2]) + r.randf_range(-0.4, 0.4), func(pk, kit) -> void:
					ArabianKit.barasti(pk, kit, r), 700.0)
				d.note(hc, 6.0)
		garden.append(c)
		i += 1
	_build_town_walls(node)
	# The date gardens: rows of palms on the plain round the village, low mud walls round the plots.
	var palms := d.palms()
	var near_mats := palms.materials(1)
	var far_mats := palms.materials(2)
	var xfs_near := {}
	var plots := 0
	var vc: Vector2 = sites["village"][0] if sites.has("village") else Vector2(0, -400)
	for k in range(16):
		var pc: Vector2 = vc + Vector2(d.rng.randf_range(-VILLAGE_HALF.x, VILLAGE_HALF.x), d.rng.randf_range(VILLAGE_HALF.y * 0.25, VILLAGE_HALF.y + 25.0))
		if k >= 11:
			pc = vc + Vector2(d.rng.randf_range(-1.0, 1.0) * (VILLAGE_HALF.x + 30.0), d.rng.randf_range(-VILLAGE_HALF.y - 30.0, VILLAGE_HALF.y))
		var yaw: float = d.rng.randf_range(-0.08, 0.08)
		var cols: int = d.rng.randi_range(3, 6)
		var rows: int = d.rng.randi_range(3, 6)
		var gap: float = d.rng.randf_range(8.5, 10.5)
		var ax := Vector2.from_angle(yaw)
		var ay := Vector2(-ax.y, ax.x)
		var planted := 0
		for a in range(cols):
			for b in range(rows):
				var p: Vector2 = pc + ax * (a - cols * 0.5) * gap + ay * (b - rows * 0.5) * gap + Vector2(d.rng.randf_range(-0.8, 0.8), d.rng.randf_range(-0.8, 0.8))
				if not _clear(p, 3.0, 9.0) or d.slope(p.x, p.y) > 0.3:
					continue
				var v: int = d.rng.randi() % 4
				if not xfs_near.has(v):
					xfs_near[v] = []
				xfs_near[v].append(d.stand(p.x, p.y, d.rng.randf_range(0.95, 1.15), 0.2, 0.05))
				planted += 1
		if planted > 4:
			plots += 1
	var n := 0
	for v in xfs_near:
		var nm: ArrayMesh = d.save(palms.mesh(v, 0, near_mats), "datepalm_%d" % v) as ArrayMesh
		var fm: ArrayMesh = d.save(palms.mesh(v, 1, far_mats), "datepalm_far_%d" % v) as ArrayMesh
		n += d.scatter(root, nm, xfs_near[v], "TallNear_palm%d" % v, 120.0, D.DatePalmKit.NEAR + D.DatePalmKit.FADE, 0.0, true, false)
		d.scatter(root, fm, xfs_near[v], "Tall_palm%d" % v, 120.0, 1500.0, D.DatePalmKit.NEAR - D.DatePalmKit.FADE)
	print("Village: ", sites["houses"].size(), " houses, ", plots, " date gardens, ", n, " palms")


func _build_camp(root: Node3D) -> void:
	var i := 0
	for t in sites["camp"]:
		var c: Vector2 = t[0]
		var r := RandomNumberGenerator.new()
		r.seed = 900 + i
		d.building(root, "BedouinTent_%d" % i, c.x, c.y, float(t[1]) - 0.03, float(t[2]), func(pk, kit) -> void:
			ArabianKit.bedouin_tent(pk, kit, r, 2 + r.randi() % 3), 900.0)
		i += 1


## The road's lamps: a twin-armed mast every LAMP_EVERY on the outside of the bend (the side the road turns
## away from), stood only where the ground there is near the road's height and no other leg passes close.
func _build_lamps(root: Node3D) -> void:
	var pk := ArabianKit.new_kit(1.0)
	var kit := {}
	ArabianKit.road_lamp(pk, kit, 11.0, 1)
	var mesh: ArrayMesh = d.save(ArabianKit.commit(pk, kit), "road_lamp") as ArrayMesh
	var xfs: Array = []
	var s := 20.0
	while s < d.length - 10.0:
		var p: Vector3 = d.curve.sample_baked(s)
		var q: Vector3 = d.curve.sample_baked(fmod(s + 2.0, d.length))
		var tan := (q - p)
		tan.y = 0.0
		tan = tan.normalized()
		var right := Vector3(-tan.z, 0, tan.x)
		var ahead: Vector3 = d.curve.sample_baked(fmod(s + 25.0, d.length)) - p
		var outside: float = -1.0 if ahead.dot(right) > 0.0 else 1.0
		if (absf(p.x - VILLAGE_C.x) < VILLAGE_HALF.x + 30.0 and absf(p.z - VILLAGE_C.y) < VILLAGE_HALF.y + 40.0) or _in_gap(s, GAP_TAPER + 4.0):
			s += LAMP_EVERY
			continue
		var ok := false
		var side := outside
		var lp := Vector3.ZERO
		var g := 0.0
		# The outside of the bend first, else the inside.
		for sd in [outside, -outside]:
			lp = p + right * float(sd) * LAMP_LAT
			g = d.ground(lp.x, lp.z)
			ok = g - p.y > -2.5 and g - p.y < 5.0 and d.road_dist(lp.x, lp.z, 30.0) > LAMP_LAT - 0.8
			for gt in gates:
				if Vector2(lp.x, lp.z).distance_to(gt) < GATE_CLEAR:
					ok = false
			if ok:
				side = sd
				break
		if ok:
			# The arm reaches back over the road (local +x toward it).
			var xb := Basis(Vector3.UP, atan2(right.x * side, right.z * side) + PI * 0.5)
			xfs.append(Transform3D(xb.scaled(Vector3.ONE * PS), Vector3(lp.x, g - 0.1, lp.z)))
		s += LAMP_EVERY
	d.scatter(root, mesh, xfs, "Rocks_lamp", 160.0, 700.0)
	print("Road lamps: ", xfs.size())


# ======================================================================================
#  Plants and rocks
# ======================================================================================

func _ok_plant(x: float, z: float, clear_road: float) -> bool:
	if d.road_dist(x, z, clear_road + 12.0) < d.road_half + clear_road:
		return false
	var c := Vector2(x, z)
	for g in gates:
		if c.distance_to(g) < GATE_CLEAR:
			return false
	return d.is_free(c, 2.0)


func _build_flora(root: Node3D) -> void:
	var tufts: Array = [[], [], []]
	var brooms: Array = [[], []]
	var ghaf: Array = [[], []]
	var samr: Array = [[], []]
	var r := d.rng
	# Dune grass in clumps over the sand (thinning up the mountain), broom bushes among it.
	for k in range(5200):
		var c := Vector2(r.randf_range(-860, 860), r.randf_range(-860, 860))
		if c.length() > 860.0:
			continue
		var y: float = d.ground(c.x, c.y)
		var share: float = clampf(1.0 - (y - 25.0) / 40.0, 0.05, 1.0)
		if r.randf() > share or d.slope(c.x, c.y) > 0.45:
			continue
		var n: int = r.randi_range(3, 9)
		for j in range(n):
			var q: Vector2 = c + Vector2.from_angle(r.randf() * TAU) * r.randf_range(0.0, 5.0)
			if not _ok_plant(q.x, q.y, 1.5):
				continue
			tufts[r.randi() % 3].append(d.stand(q.x, q.y, r.randf_range(0.9, 1.6), 0.06))
		if r.randf() < 0.35 and _ok_plant(c.x, c.y, 3.0):
			brooms[r.randi() % 2].append(d.stand(c.x, c.y, r.randf_range(0.8, 1.3), 0.1))
	# Ghaf on the plain, umbrella thorns on the mountain's lower slopes and gravel.
	var w := d.woods()
	var leaf_near := w.leaf_material(1, 0.1, 10.0)
	var leaf_far := w.leaf_material(2, 0.1, 10.0)
	for lm in [leaf_near, leaf_far]:
		lm.set_shader_parameter("desaturate", 0.55)
		lm.set_shader_parameter("backlight_color", Color(0.48, 0.50, 0.34))
	var bark_n := w.bark_material("ghaf", 1)
	var bark_f := w.bark_material("ghaf", 2)
	for k in range(900):
		var c := Vector2(r.randf_range(-860, 860), r.randf_range(-860, 860))
		var rr: float = c.length()
		if rr > 860.0 or d.slope(c.x, c.y) > 0.3 or not _ok_plant(c.x, c.y, 8.0):
			continue
		var y: float = d.ground(c.x, c.y)
		if rr > 330.0 and r.randf() < 0.55:
			ghaf[r.randi() % 2].append(d.stand(c.x, c.y, r.randf_range(0.8, 1.15), 0.3, 0.06))
			d.note(c, 3.5)
		elif rr < 380.0 and y < 70.0 and r.randf() < 0.45:
			samr[r.randi() % 2].append(d.stand(c.x, c.y, r.randf_range(0.75, 1.05), 0.3, 0.08))
			d.note(c, 3.0)
	for v in range(3):
		var m := d.tuft_mesh(v)
		d.scatter(root, d.save(m, "tuft_%d" % v) as Mesh, tufts[v], "Plants_grass%d" % v, 96.0, 260.0, 0.0, false)
	for v in range(2):
		d.scatter(root, d.save(d.broom_mesh(v), "broom_%d" % v) as Mesh, brooms[v], "Plants_broom%d" % v, 96.0, 360.0, 0.0, false)
	for kind_v in [["ghaf", ghaf], ["samr", samr]]:
		var kind: String = kind_v[0]
		var lists: Array = kind_v[1]
		for v in range(2):
			if lists[v].is_empty():
				continue
			var nm: ArrayMesh = d.save(w.broadleaf_mesh(kind, v, 0, bark_n, leaf_near), "%s_%d" % [kind, v]) as ArrayMesh
			var fm: ArrayMesh = d.save(w.broadleaf_mesh(kind, v, 1, bark_f, leaf_far), "%s_far_%d" % [kind, v]) as ArrayMesh
			d.scatter(root, nm, lists[v], "TallNear_%s%d" % [kind, v], 120.0, Woodland_near() + 25.0, 0.0, true, false)
			d.scatter(root, fm, lists[v], "Tall_%s%d" % [kind, v], 120.0, 1400.0, Woodland_near() - 25.0)
	var counts := [0, 0, 0, 0]
	for v in tufts:
		counts[0] += v.size()
	for v in brooms:
		counts[1] += v.size()
	for v in ghaf:
		counts[2] += v.size()
	for v in samr:
		counts[3] += v.size()
	print("Flora: ", counts[0], " grass tufts, ", counts[1], " broom bushes, ", counts[2], " ghaf, ", counts[3], " umbrella thorns")


func Woodland_near() -> float:
	return 115.0


func _build_rocks(root: Node3D) -> void:
	var mat := d.rock_material()
	var meshes: Array = []
	for v in range(4):
		meshes.append(d.save(D.FreightKit.boulder(5100 + v, Vector3(1.3, 0.75, 1.1) if v % 2 == 0 else Vector3(1.0, 1.0, 0.85), mat), "boulder_%d" % v))
	var lists: Array = [[], [], [], []]
	var big := 0
	var r := d.rng
	for k in range(4200):
		var c := Vector2.from_angle(r.randf() * TAU) * sqrt(r.randf()) * 420.0
		var y: float = d.ground(c.x, c.y)
		if y < 18.0 and r.randf() < 0.8:
			continue
		var steep: float = d.slope(c.x, c.y)
		if steep > 1.2:
			continue
		var n: int = r.randi_range(1, 5)
		for j in range(n):
			var q: Vector2 = c + Vector2.from_angle(r.randf() * TAU) * r.randf_range(0.0, 7.0)
			var s: float = r.randf_range(0.3, 1.4) * (2.6 if j == 0 and r.randf() < 0.15 else 1.0)
			if not _ok_plant(q.x, q.y, 2.0 + s * 1.5):
				continue
			if s > 2.0:
				big += 1
			lists[r.randi() % 4].append(Transform3D(Basis(Vector3.UP, r.randf() * TAU).rotated(Vector3.RIGHT, r.randf_range(-0.2, 0.2)).scaled(Vector3.ONE * s),
					Vector3(q.x, d.ground(q.x, q.y) - s * 0.25, q.y)))
	var total := 0
	for v in range(4):
		total += d.scatter(root, meshes[v], lists[v], "Rocks_boulder%d" % v, 120.0, 650.0)
	print("Boulders: ", total, " (", big, " big)")


## The chevron board on the outside of the turn off the summit into the plunge (the old imported sign is gone): its
## arrow (ArrowSign's +x) points the way the road goes, down into the valley, its board facing the drivers coming in.
func _build_arrow_sign(root: Node3D) -> void:
	var c: Curve3D = d.curve
	var s0: float = c.get_closest_offset(SUMMIT[3])
	var s1: float = c.get_closest_offset(Vector3(0.0, 115.0, -130.0))
	var best := s0
	var best_turn := 0.0
	var s := s0
	while s < s1:
		var a: Vector3 = c.sample_baked(s + 6.0) - c.sample_baked(s)
		var b: Vector3 = c.sample_baked(s + 12.0) - c.sample_baked(s + 6.0)
		var turn: float = absf(Vector2(a.x, a.z).angle_to(Vector2(b.x, b.z)))
		if turn > best_turn:
			best_turn = turn
			best = s + 6.0
		s += 1.0
	# The approach's heading (before the turn) and which way the road turns from it.
	var p: Vector3 = c.sample_baked(best)
	var tan: Vector3 = p - c.sample_baked(best - 8.0)
	tan.y = 0.0
	tan = tan.normalized()
	var right := Vector3(-tan.z, 0, tan.x)
	var ahead: Vector3 = c.sample_baked(best + 25.0) - p
	var turn_dir: Vector3 = right if ahead.dot(right) > 0.0 else -right
	# Straight ahead of the drivers coming in, past the road's outside edge.
	var at: Vector3 = p - turn_dir * (d.road_half + 6.0)
	for k in range(12):
		var q: Vector3 = p + tan * (d.road_half + 6.0 + k * 2.0) - turn_dir * 3.0
		if d.road_dist(q.x, q.z, 40.0) > d.road_half + 4.0 and absf(d.ground(q.x, q.z) - p.y) < 4.0:
			at = q
			break
	var sign: Node3D = (load("res://ArrowSign.tscn") as PackedScene).instantiate()
	sign.name = "SummitArrowSign"
	root.add_child(sign)
	sign.owner = level
	var x: Vector3 = turn_dir
	var basis := Basis(x, Vector3.UP, x.cross(Vector3.UP)).scaled(Vector3.ONE * 1.25)
	sign.transform = Transform3D(basis, Vector3(at.x, d.ground(at.x, at.z), at.z))
	print("Summit arrow at s ", best, " pointing ", turn_dir)


# ======================================================================================
#  The lap: the summit round the fort, the town section, sand over the road
# ======================================================================================

## The summit road, from the old lap's point 43 round the fort's north-west side 60m out (it ran 100m off), to
## the plunge (point 49).
const SUMMIT := [Vector3(-88.0, 121.0, -26.0), Vector3(-58.0, 125.5, -16.0), Vector3(-46.0, 128.5, -38.0),
	Vector3(-26.0, 130.5, -54.0), Vector3(0.0, 130.0, -66.0)]
## The town section, from the plunge's foot (old point 55) through the village terrace's lanes (y 0: on the
## terrace) and out to the finish straight (old point 2). Its hairpins are tight on purpose.
const TOWN := [Vector3(0.0, 22.0, -310.0), Vector3(-6.0, 12.0, -345.0), Vector3(-18.0, 5.0, -372.0), Vector3(-30.0, 0.0, -400.0),
	Vector3(-62.0, 0.0, -412.0), Vector3(-100.0, 0.0, -400.0), Vector3(-138.0, 0.0, -412.0), Vector3(-160.0, 0.0, -440.0),
	Vector3(-150.0, 0.0, -472.0), Vector3(-120.0, 0.0, -485.0), Vector3(-88.0, 0.0, -470.0), Vector3(-60.0, 0.0, -488.0),
	Vector3(-28.0, 0.0, -470.0), Vector3(-2.0, 0.0, -448.0), Vector3(15.0, 0.0, -418.0), Vector3(40.0, 4.5, -380.0),
	Vector3(70.0, 7.0, -335.0), Vector3(100.0, 8.0, -300.0)]
## The town is off-road from TOWN[2] to TOWN[16]; sand drifts over the road near these points.
const DRIFTS := [Vector2(246.0, 0.0), Vector2(130.4, 225.8), Vector2(-190.5, 110.0)]
const DRIFT_HALF := 15.0
const GAP_TAPER := 12.0
const GAP_LEAD := 10.0
const GAP_GROUND := 0.06


## The old lap (Mountain Pass's custom curve) becomes the new one once, marked by the TrackPath's
## `town_route` meta: points 2-43 and 49-54 kept with their handles, the summit and the town new.
func _reshape_lap() -> void:
	var path: Path3D = level.get_node("TrackPath")
	if path.has_meta(&"town_route"):
		print("Lap already has the town route (", path.curve.get_baked_length(), "m)")
		return
	var old: Curve3D = path.curve
	if old.point_count != 59:
		push_error("TrackPath isn't the old 59-point lap: not reshaped")
		return
	var vy: float = _village_y()
	var pts: Array = []    # [position, in, out, keep]
	for i in range(2, 44):
		pts.append([old.get_point_position(i), old.get_point_in(i), old.get_point_out(i), i != 2 and i != 43])
	for p in SUMMIT:
		pts.append([p, Vector3.ZERO, Vector3.ZERO, false])
	for i in range(49, 55):
		pts.append([old.get_point_position(i), old.get_point_in(i), old.get_point_out(i), i != 49 and i != 54])
	for p in TOWN:
		var q: Vector3 = p
		if q.y == 0.0:
			# On the terrace: its surface is the road's, less the gap's lift (road_y_offset - road_gap_ground).
			q.y = vy - (float(tg.road_y_offset) - GAP_GROUND)
		pts.append([q, Vector3.ZERO, Vector3.ZERO, false])
	var c := Curve3D.new()
	c.bake_interval = 0.25
	var n := pts.size()
	for i in range(n):
		var p: Vector3 = pts[i][0]
		if pts[i][3]:
			c.add_point(p, pts[i][1], pts[i][2])
			continue
		# Collinear handles a third of each neighbouring segment long.
		var prev: Vector3 = pts[(i - 1 + n) % n][0]
		var next: Vector3 = pts[(i + 1) % n][0]
		var dir: Vector3 = (next - prev).normalized()
		c.add_point(p, -dir * p.distance_to(prev) / 3.0, dir * p.distance_to(next) / 3.0)
	path.curve = c
	path.set_meta(&"town_route", true)
	print("Lap reshaped: ", old.get_baked_length(), "m -> ", c.get_baked_length(), "m")


func _village_y() -> float:
	var rel: Vector2 = d.relief(VILLAGE_C.x, VILLAGE_C.y, maxf(VILLAGE_HALF.x, VILLAGE_HALF.y), true)
	return (rel.x + rel.y) * 0.5


## Road gaps: the town (no tarmac: the terrace's packed earth), and three stretches where sand has blown over the
## road (a mound across it, road_gap_drift); the asphalt breaks up toward each under blown sand (road_crumble).
func _plan_road_gaps() -> void:
	var c: Curve3D = d.curve
	var gaps := PackedFloat32Array()
	var drift := PackedFloat32Array()
	var t0: float = c.get_closest_offset(TOWN[2])
	var t1: float = c.get_closest_offset(TOWN[16])
	var list: Array = [[t0, t1, 0.0]]
	for p in DRIFTS:
		var o: float = c.get_closest_offset(Vector3(p.x, c.sample_baked(c.get_closest_offset(Vector3(p.x, 50.0, p.y))).y, p.y))
		list.append([o - DRIFT_HALF, o + DRIFT_HALF, 0.42])
	list.sort_custom(func(a, b): return a[0] < b[0])
	for g in list:
		gaps.append_array(PackedFloat32Array([g[0], g[1]]))
		drift.append(g[2])
	tg.set("road_gaps", gaps)
	tg.set("road_gap_taper", GAP_TAPER)
	tg.set("road_gap_ground", GAP_GROUND)
	tg.set("curbs_stop_at_gaps", true)
	tg.set("road_gap_drift", drift)
	var road_mat := ShaderMaterial.new()
	road_mat.shader = load("res://road_crumble.gdshader")
	road_mat.set_shader_parameter("asphalt_tex", load("res://materials/asphalt.png"))
	road_mat.set_shader_parameter("dirt_tex", load("res://materials/sand.png"))
	road_mat.set_shader_parameter("dirt_normal", load("res://materials/sand_normal.png"))
	road_mat.set_shader_parameter("dirt_tint", Color(0.88, 0.62, 0.40))
	road_mat.set_shader_parameter("dirt_tile", 1.0 / 0.12)
	var pairs := PackedVector2Array()
	for k in range(0, gaps.size() - 1, 2):
		pairs.append(Vector2(gaps[k], gaps[k + 1]))
	road_mat.set_shader_parameter("gaps", pairs)
	road_mat.set_shader_parameter("gap_count", pairs.size())
	road_mat.set_shader_parameter("taper", GAP_TAPER)
	road_mat.set_shader_parameter("lead", GAP_LEAD)
	road_mat.set_shader_parameter("road_width", float(tg.road_width))
	tg.set("road_material", road_mat)
	sites["gaps"] = list
	print("Road gaps (town, drifts): ", list)


## The rock map (the ground map's R): how far the ground is a rock face, from its slope over 6m and its height.
func _rock_at(x: float, z: float) -> float:
	if Vector2(x, z).length() > 440.0:
		return 0.0
	var g: float = d.ground(x, z)
	var sl: float = maxf(absf(d.ground(x + 3.0, z) - d.ground(x - 3.0, z)), absf(d.ground(x, z + 3.0) - d.ground(x, z - 3.0))) / 6.0
	var high: float = smoothstep(20.0, 40.0, g)
	return clampf(smoothstep(0.65, 1.1, sl) + high * smoothstep(0.32, 0.7, sl), 0.0, 1.0)


# ======================================================================================
#  Rock formations and the sand's effects
# ======================================================================================

## Rock formations on the jebel's faces (ChasmRock.gd, the shapes that replaced the stacked-slab FBX rocks on
## Tolvanera Gulch, here in the jebel's brown, `palette` 1): baked once per shape, stood on the lowest ground
## under their middle on steep faces, clear of the lap. Their colliders are their own triangles.
const FORMATIONS := [[0, 1, Vector3(1.0, 1.0, 1.0)], [0, 2, Vector3(1.3, 1.5, 1.2)], [1, 1, Vector3(1.0, 1.0, 1.0)], [1, 3, Vector3(1.4, 1.8, 1.3)],
	[2, 1, Vector3(1.0, 1.0, 1.0)], [0, 4, Vector3(0.8, 1.7, 0.8)], [1, 5, Vector3(0.9, 1.3, 0.9)]]
const FORMATION_COUNT := 34

func _build_rock_formations(root: Node3D) -> void:
	var Rock = load("res://ChasmRock.gd")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://generated/canyon_chasm_rocks/"))
	var shapes: Array = []
	for f in FORMATIONS:
		var r: Node3D = Node3D.new()
		r.set_script(Rock)
		r.set("kind", f[0])
		r.set("rock_seed", f[1])
		r.set("stretch", f[2])
		var path: String = r.call("bake_path")
		if not ResourceLoader.exists(path):
			var mesh: ArrayMesh = r.call("build_mesh")
			ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
		var aabb: AABB = (load(path) as Mesh).get_aabb()
		shapes.append([f, maxf(aabb.size.x, aabb.size.z) * 0.5])
		r.free()
	var node := Node3D.new()
	node.name = "RockFormations"
	root.add_child(node)
	node.owner = level
	var placed := 0
	var tries := 0
	while placed < FORMATION_COUNT and tries < 8000:
		tries += 1
		var c := Vector2.from_angle(d.rng.randf() * TAU) * d.rng.randf_range(60.0, 330.0)
		if _rock_at(c.x, c.y) < 0.6:
			continue
		var sh: Array = shapes[d.rng.randi() % shapes.size()]
		var rad: float = sh[1]
		if d.road_dist(c.x, c.y, rad + 40.0) < rad + d.road_half + 6.0 or not d.is_free(c, rad * 0.8):
			continue
		var ok := true
		for g in gates:
			if c.distance_to(g) < rad + GATE_CLEAR:
				ok = false
		if not ok:
			continue
		var rel: Vector2 = d.relief(c.x, c.y, rad * 0.45)
		var r: Node3D = Node3D.new()
		r.set_script(Rock)
		r.name = "Formation_%d" % placed
		r.set("kind", sh[0][0])
		r.set("rock_seed", sh[0][1])
		r.set("stretch", sh[0][2])
		r.set("palette", 1)
		r.transform = Transform3D(Basis(Vector3.UP, d.rng.randf() * TAU), Vector3(c.x, rel.x - 0.5, c.y))
		node.add_child(r)
		r.owner = level
		d.note(c, rad * 0.8)
		placed += 1
	print("Rock formations: ", placed)


## Blowing sand where it lies over the road: at each drift, ribbons of sand streaming across the road on the
## shamal (sand_drift.gdshader: two layers, at the surface and a little above it, the upper fainter and
## coarser), and grains blown off the drift's crest (GPU particles, a few hundred). Named "SandFx" (no colliders).
func _build_sand_fx(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "SandFx"
	root.add_child(node)
	node.owner = level
	var shader: Shader = load("res://sand_drift.gdshader")
	var i := 0
	for g in sites["gaps"]:
		if float(g[2]) <= 0.0:
			continue
		var mid: float = (float(g[0]) + float(g[1])) * 0.5
		var reach: float = DRIFT_HALF + GAP_TAPER + GAP_LEAD + 14.0
		for layer in range(2):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var rows: Array = []
			var s: float = mid - reach
			while s <= mid + reach:
				var p: Vector3 = d.curve.sample_baked(s)
				var q: Vector3 = d.curve.sample_baked(s + 1.0)
				var tan := q - p
				tan.y = 0.0
				tan = tan.normalized()
				var right := Vector3(-tan.z, 0.0, tan.x)
				var row: Array = []
				for k in range(9):
					var lat: float = lerpf(-16.0, 16.0, float(k) / 8.0)
					var wp: Vector3 = p + right * lat
					var y: float = d.ground(wp.x, wp.z)
					if absf(lat) < d.road_half:
						y = maxf(y, p.y + float(tg.road_y_offset))
					var along: float = (s - mid) / reach
					# Fades out along the road past the drift and toward the edges of the strip.
					var fade: float = (1.0 - smoothstep(0.55, 1.0, absf(along))) * (1.0 - smoothstep(0.6, 1.0, absf(lat) / 16.0))
					row.append([Vector3(wp.x, y + (0.04 if layer == 0 else 0.35), wp.z), fade])
				rows.append(row)
				s += 3.0
			for r in range(rows.size() - 1):
				for k in range(8):
					for v in [[r, k], [r, k + 1], [r + 1, k + 1], [r, k], [r + 1, k + 1], [r + 1, k]]:
						var cell: Array = rows[v[0]][v[1]]
						st.set_color(Color(1, 1, 1, cell[1]))
						st.set_normal(Vector3.UP)
						st.add_vertex(cell[0])
			var mesh := st.commit()
			var m := ShaderMaterial.new()
			m.shader = shader
			m.set_shader_parameter("wind_dir", ArabianTerrain.WIND.rotated(0.4))
			m.set_shader_parameter("layer", layer)
			m.set_shader_parameter("strength", 1.0 if layer == 0 else 0.6)
			mesh.surface_set_material(0, m)
			var mi := MeshInstance3D.new()
			mi.name = "SandStream_%d_%d" % [i, layer]
			mi.mesh = d.save(mesh, "sand_stream_%d_%d" % [i, layer])
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = 320.0
			node.add_child(mi)
			mi.owner = level
		# Grains blown off the drift.
		var gp := GPUParticles3D.new()
		gp.name = "SandGrains_%d" % i
		var centre: Vector3 = d.curve.sample_baked(mid)
		var wind3 := Vector3(ArabianTerrain.WIND.x, 0.0, ArabianTerrain.WIND.y).normalized()
		gp.position = centre + Vector3(0, 0.3, 0) - wind3 * 14.0
		gp.amount = 600
		gp.lifetime = 2.6
		gp.preprocess = 3.0
		gp.visibility_aabb = AABB(Vector3(-40, -3, -40), Vector3(80, 10, 80))
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(16.0, 0.2, 16.0)
		pm.direction = wind3 + Vector3(0, 0.12, 0)
		pm.spread = 12.0
		pm.initial_velocity_min = 6.0
		pm.initial_velocity_max = 11.0
		pm.gravity = Vector3(0, -1.2, 0)
		pm.damping_min = 0.5
		pm.damping_max = 1.0
		pm.scale_min = 0.6
		pm.scale_max = 1.4
		var fade := Gradient.new()
		fade.set_color(0, Color(1, 1, 1, 0))
		fade.add_point(0.2, Color(1, 1, 1, 1))
		fade.add_point(0.75, Color(1, 1, 1, 0.8))
		fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
		var ft := GradientTexture1D.new()
		ft.gradient = fade
		pm.color_ramp = ft
		gp.process_material = pm
		var quad := QuadMesh.new()
		quad.size = Vector2(0.14, 0.07)
		var qm := StandardMaterial3D.new()
		qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		qm.vertex_color_use_as_albedo = true
		qm.albedo_color = Color(0.92, 0.70, 0.48)
		quad.material = qm
		gp.draw_pass_1 = quad
		gp.visibility_range_end = 200.0
		gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(gp)
		gp.owner = level
		i += 1
	print("Sand drifts with blowing sand: ", i)


func _in_gap(o: float, margin: float) -> bool:
	if not sites.has("gaps"):
		return false
	for g in sites["gaps"]:
		if o > float(g[0]) - margin and o < float(g[1]) + margin:
			return true
	return false


## The town's lanes, as the ground map's R would carry them (1 - metres / piste_reach): only the town section.
func _piste_map() -> Texture2D:
	var town: Array = sites["gaps"][sites["gaps"].size() - 1]
	var res := 1024
	var half := 1000.0
	var img := Image.create(res, res, false, Image.FORMAT_L8)
	var x0: int = int((VILLAGE_C.x - VILLAGE_HALF.x - 80.0 + half) / (2.0 * half) * res)
	var x1: int = int((VILLAGE_C.x + VILLAGE_HALF.x + 140.0 + half) / (2.0 * half) * res)
	var z0: int = int((VILLAGE_C.y - VILLAGE_HALF.y - 40.0 + half) / (2.0 * half) * res)
	var z1: int = int((VILLAGE_C.y + VILLAGE_HALF.y + 160.0 + half) / (2.0 * half) * res)
	for j in range(maxi(z0, 0), mini(z1, res)):
		for i in range(maxi(x0, 0), mini(x1, res)):
			var x: float = -half + (i + 0.5) * 2.0 * half / res
			var z: float = -half + (j + 0.5) * 2.0 * half / res
			var near: Array = d.road_near(x, z, 20.0)
			var o: float = near[2]
			if o < float(town[0]) - GAP_TAPER or o > float(town[1]) + GAP_TAPER:
				continue
			img.set_pixel(i, j, Color(clampf(1.0 - float(near[0]) / 10.0, 0.0, 1.0), 0, 0))
	return d.save(ImageTexture.create_from_image(img), "piste_map") as Texture2D


## Garden walls along the town's street, where no house fronts it: mud walls with stepped tops, gaps for the
## lanes' corners, so the street reads (and keeps a cart that leaves it out of the yards).
func _build_town_walls(parent: Node3D) -> void:
	var town: Array = sites["gaps"][sites["gaps"].size() - 1]
	var pk := ArabianKit.new_kit(1.0)
	var kit := {}
	var segs := 0
	for side in [-1.0, 1.0]:
		var s: float = float(town[0]) + 6.0
		while s < float(town[1]) - 6.0:
			var a: Vector3 = d.curve.sample_baked(s)
			var b: Vector3 = d.curve.sample_baked(s + 6.0)
			var tan := b - a
			tan.y = 0.0
			tan = tan.normalized()
			var right: Vector3 = Vector3(-tan.z, 0.0, tan.x) * side
			var lat := d.road_half + 4.0
			var pa: Vector3 = a + right * lat
			var pb: Vector3 = b + right * lat
			var mid := (pa + pb) * 0.5
			var ok: bool = absf(mid.x - VILLAGE_C.x) < VILLAGE_HALF.x - 2.0 and absf(mid.z - VILLAGE_C.y) < VILLAGE_HALF.y - 2.0
			ok = ok and d.road_dist(mid.x, mid.z, 30.0) > lat - 0.6 and d.is_free(Vector2(mid.x, mid.z), 1.5)
			if ok:
				var y: float = float(sites["village"][1])
				var basis := Basis(right, Vector3.UP, -tan)
				var c := Vector3(mid.x, y + 1.1, mid.z)
				var len: float = pa.distance_to(pb) + 0.2
				pk.box(kit, "mud", Transform3D(basis, c), Vector3(0.6, 2.6, len), Color(ArabianKit.MUD.r, ArabianKit.MUD.g, ArabianKit.MUD.b, 0.2), ArabianKit.uvk)
				# A coping along the top and small stepped merlons on it, in line with the wall.
				pk.box(kit, "mud", Transform3D(basis, c + Vector3(0, 1.38, 0)), Vector3(0.72, 0.16, len), ArabianKit.MUD_PALE, ArabianKit.uvk)
				var top := c + Vector3(0, 1.46, 0)
				ArabianKit.merlons(pk, kit, "mud", top - tan * len * 0.5, top + tan * len * 0.5, ArabianKit.MUD_PALE, 1.5, 0.42, 0.5, 0.5)
				segs += 1
			s += 6.0
	if segs == 0:
		return
	var mi := MeshInstance3D.new()
	mi.name = "TownWalls"
	mi.mesh = d.save(ArabianKit.commit(pk, kit), "town_walls")
	mi.visibility_range_end = 900.0
	parent.add_child(mi)
	mi.owner = level
	print("Town walls: ", segs, " pieces")


## The road's side walls (where it stands over the ground) in sandy dressed stone, not white concrete.
func _stone_road_sides() -> void:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://materials/cobblestone.png")
	m.albedo_color = Color(0.92, 0.74, 0.56)
	m.normal_enabled = true
	m.normal_texture = load("res://materials/cobblestone_normal.png")
	m.roughness_texture = load("res://materials/cobblestone_roughness.png")
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.22, 0.22, 0.22)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m = d.save(m, "stone_sides") as StandardMaterial3D
	for n in ["Visual_Road_Sides", "Visual_Curbs_Sides"]:
		var mi := tg.get_node_or_null(n) as MeshInstance3D
		if mi:
			mi.material_override = m



## Checkpoints at the town's entrance (HalfwayTownEntry) and in its middle (HalfwayTown), between Halfway1 on the summit
## and the finish, so the town can't be skipped by cutting across from the plunge's foot to the finish straight.
func _town_checkpoint() -> void:
	var cps: Node = level.get_node("Checkpoints")
	var gate: Node3D = cps.get_node_or_null("HalfwayTown")
	if gate == null:
		gate = (load("res://CheckpointGate.tscn") as PackedScene).instantiate()
		gate.name = "HalfwayTown"
		cps.add_child(gate)
		gate.owner = level
	gate.position = d.curve.sample_baked(d.curve.get_closest_offset(TOWN[11]))
	# And one at the town's entrance, where the lap comes off the plunge into the first lane.
	var entry: Node3D = cps.get_node_or_null("HalfwayTownEntry")
	if entry == null:
		entry = (load("res://CheckpointGate.tscn") as PackedScene).instantiate()
		entry.name = "HalfwayTownEntry"
		cps.add_child(entry)
		entry.owner = level
	entry.position = d.curve.sample_baked(d.curve.get_closest_offset((TOWN[2] as Vector3).lerp(TOWN[3], 0.55)))
	level._align_checkpoints_to_track()
	var order: Array[Area3D] = []
	for n in ["Halfway4", "Halfway3", "Halfway2", "Halfway1", "HalfwayTownEntry", "HalfwayTown"]:
		order.append(cps.get_node(n) as Area3D)
	order.append(level.get_node("FinishLine") as Area3D)
	level.checkpoints = order
	for gn in [gate, entry]:
		gates.append(Vector2(gn.position.x, gn.position.z))
		d.note(Vector2(gn.position.x, gn.position.z), 9.0)
	var s_entry: float = d.curve.get_closest_offset(entry.position)
	var s_town: float = d.curve.get_closest_offset(gate.position)
	print("Town checkpoints: entrance at s %.0f %s, middle at s %.0f %s (%.0fm apart)" % [s_entry, entry.position, s_town, gate.position, s_town - s_entry])
	if s_town - s_entry < 53.0:
		push_error("Town checkpoints only %.0fm apart" % (s_town - s_entry))
