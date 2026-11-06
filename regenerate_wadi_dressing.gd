# regenerate_wadi_dressing.gd
# Dresses levels/DesertWadiLevel.tscn (Desert Wadi, the Al-Raihana GP's second stage), keeping the lap, gates,
# boost pads and the kicker as they are. It re-bakes the TerrainGenerator's ground (ArabianTerrain's dunes on the
# ring round the valley instead of noise blobs) with level pads for the buildings, replaces the shared weather
# system with the stage's own sky, and builds WadiDressing:
#   - the oasis: date palms round the lake and along the wadi's bed, palm-frond huts in the groves;
#   - Husn al-Wadi, a fort on the dunes over the valley, watchtowers on the crests, a village by the oasis;
#   - a Bedouin camp inside the western bowl;
#   - the piste: the lap's line driven into the sand (the ground map), rally marker flags along its edges;
#   - dune grass, broom bushes, ghaf and thorn trees, stones in the wadi's gravel bed;
#   - the country past the rim and the city on the horizon.
# Everything under WadiDressing is replaced on every run.
#
# Run: Godot --headless --path . res://regenerate_wadi_dressing.tscn
extends Node

const D = preload("res://ArabianDresser.gd")
const ArabianKit = preload("res://ArabianKit.gd")
const ArabianTerrain = preload("res://ArabianTerrain.gd")

const LEVEL := "res://levels/DesertWadiLevel.tscn"
const ROOT := "WadiDressing"
const OLD := ["WeatherController", "WorldEnvironment", "SunLight", "RockRidges", ROOT]
const PS := 1.6
const LAKE := Vector2(195.0, -208.0)
const LAKE_R := Vector2(130.0, 105.0)
const WATER_Y := 1.7
const RIVER := [Vector2(70.0, -150.0), Vector2(110.0, -175.0), Vector2(160.0, -200.0), Vector2(205.0, -215.0),
	Vector2(250.0, -230.0), Vector2(295.0, -245.0), Vector2(330.0, -260.0)]
const FORT_SIDE := 30.0
const VILLAGE_HALF := Vector2(70.0, 42.0)
const VILLAGE_BLEND := 24.0
const VILLAGE_HOUSES := 10
const TOWERS := 4
## The villa (ArabianKit.villa, from the user's picture of a sandstone house among boulders): its pad's half size and
## blend (game metres), and how far its middle stands from the lap's line.
const VILLA_HALF := Vector2(44.0, 52.0)
const VILLA_BLEND := 16.0
const VILLA_ROAD := Vector2(95.0, 175.0)
## Palms in the villa's courtyard, in its own (life-size) frame.
const VILLA_PALMS := [Vector2(-21.0, -10.0), Vector2(20.0, -12.0), Vector2(-8.0, -27.0), Vector2(12.0, -26.0), Vector2(14.0, -18.0)]
const GATE_CLEAR := 16.0
## The piste: full within PISTE_IN of the line, gone by PISTE_OUT.
const PISTE_IN := 6.0
const PISTE_OUT := 11.0
const FLAG_EVERY := 22.0
const FLAG_LAT := 10.5

var d := D.new()
var tg: Node3D
var level: Node3D
var gates: Array = []
var pads := PackedFloat32Array()
var sites := {}


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	level = (load(LEVEL) as PackedScene).instantiate()
	add_child(level)
	tg = level.get_node("TerrainGenerator")
	d.setup(level, tg, 5252)
	print("Removed: ", d.strip(OLD))
	for cp in level.get_node("Checkpoints").get_children():
		gates.append(Vector2(cp.global_position.x, cp.global_position.z))
	var fl: Node3D = level.get_node("FinishLine")
	gates.append(Vector2(fl.global_position.x, fl.global_position.z))
	for sp in level.find_children("Spawn*", "Marker3D", true, false):
		gates.append(Vector2((sp as Node3D).global_position.x, (sp as Node3D).global_position.z))
	for bp in level.get_node("BoostPads").get_children():
		gates.append(Vector2((bp as Node3D).global_position.x, (bp as Node3D).global_position.z))

	_raise_ford()
	_plan_sites()
	tg.set("flat_pads", pads)
	print("Pads: ", pads.size() / 7, "; baking the ground...")
	tg.generate_world()
	for child in tg.get_children():
		_own(child)
	var gc := tg.get_node_or_null("GrassContainer")
	if gc:
		tg.remove_child(gc)
		gc.free()
	d.setup(level, tg, 5252)

	var root := Node3D.new()
	root.name = ROOT
	level.add_child(root)
	root.owner = level
	root.set_script(load("res://CanyonDetail.gd"))

	_ground_and_sky()
	_build_fort(root)
	_build_towers(root)
	_build_village(root)
	_build_villa(root)
	_build_camp(root)
	_build_oasis(root)
	_build_flags(root)
	_build_flora(root)
	_build_rocks(root)
	# Airliners: arrivals down past the lap's south-east flank to the city, departures out past its north-west and
	# round to the east, away from the ranges to the north-east.
	d.airliners(root, Vector2(-2200.0, 1500.0), -1.0, 0.6, 0.8, 0.0, 300.0, 550.0, 115.0, 6000.0)
	d.backdrop(root, 868.0, 3900.0, -PI * 0.35, 0.9, 360.0, Color(0.90, 0.66, 0.44), Color(0.40, 0.32, 0.26))
	d.skyline(root, Vector2(-2200.0, 1500.0), 0.0, 22)

	remove_child(level)
	var packed := PackedScene.new()
	var err := packed.pack(level)
	if err == OK:
		err = ResourceSaver.save(packed, LEVEL)
	print("Saved DesertWadiLevel.tscn: ", err, " in ", (Time.get_ticks_msec() - t0) / 1000.0, "s")
	get_tree().quit(0 if err == OK else 1)


func _own(n: Node) -> void:
	n.owner = level
	if n.scene_file_path != "":
		return
	for c in n.get_children():
		_own(c)


func _clear(c: Vector2, r: float, road := 10.0) -> bool:
	if d.road_dist(c.x, c.y, r + d.road_half + road + 30.0) < r + d.road_half + road:
		return false
	for g in gates:
		if c.distance_to(g) < r + GATE_CLEAR:
			return false
	return d.is_free(c, r)


func _lake_d(p: Vector2) -> float:
	return Vector2((p.x - LAKE.x) / LAKE_R.x, (p.y - LAKE.y) / LAKE_R.y).length()


func _river_d(p: Vector2) -> float:
	var best := INF
	for i in range(RIVER.size() - 1):
		var a: Vector2 = RIVER[i]
		var b: Vector2 = RIVER[i + 1]
		var t: float = clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + (b - a) * t))
	return best


func _rect_clear(c: Vector2, half: Vector2, clear: float) -> bool:
	var x := -half.x
	while x <= half.x:
		var z := -half.y
		while z <= half.y:
			if d.road_dist(c.x + x, c.y + z, clear + 30.0) < clear:
				return false
			if _lake_d(c + Vector2(x, z)) < 1.08:
				return false
			z += 10.0
		x += 10.0
	return true


func _pad(c: Vector2, half: Vector2, yaw: float, blend: float) -> float:
	var rel: Vector2 = d.relief(c.x, c.y, maxf(half.x, half.y), true)
	var y: float = (rel.x + rel.y) * 0.5
	pads.append_array(PackedFloat32Array([c.x, c.y, half.x, half.y, yaw, y, blend]))
	return y


func _plan_sites() -> void:
	# The fort: on the dunes over the valley, the highest clear spot within reach of the lake.
	# Room for the corner towers (they reach 4.4m past the walls, life size) and 6m of level ground round them.
	var fhalf: float = FORT_SIDE * 0.5 * PS + 14.0
	var best := Vector2.INF
	var best_y := -INF
	for k in range(2500):
		var c: Vector2 = LAKE + Vector2.from_angle(d.rng.randf() * TAU) * d.rng.randf_range(150.0, 330.0)
		if not _rect_clear(c, Vector2(fhalf + 14.0, fhalf + 14.0), d.road_half + 6.0):
			continue
		var y: float = tg.natural_height(c.x, c.y)
		var rel: Vector2 = d.relief(c.x, c.y, fhalf, true)
		var score: float = y - (rel.y - rel.x) * 0.6
		if score > best_y:
			best_y = score
			best = c
	if best != Vector2.INF:
		var fy := _pad(best, Vector2(fhalf, fhalf), 0.0, 14.0)
		# The gate toward the lake.
		var to_lake := LAKE - best
		sites["fort"] = [best, fy, atan2(-to_lake.x, -to_lake.y), fhalf]
		d.note(best, fhalf + 6.0)
		print("Fort at ", best, " y ", fy)
	# The village by the oasis: a terrace on the valley's side, out of the lake's reach.
	var vbest := Vector2.INF
	var vrel := INF
	for k in range(1500):
		var c: Vector2 = LAKE + Vector2.from_angle(d.rng.randf() * TAU) * d.rng.randf_range(140.0, 300.0)
		if not _rect_clear(c, VILLAGE_HALF + Vector2(VILLAGE_BLEND, VILLAGE_BLEND), d.road_half + 4.0) or not d.is_free(c, 90.0):
			continue
		var rel: Vector2 = d.relief(c.x, c.y, VILLAGE_HALF.x, true)
		var score: float = (rel.y - rel.x) + c.distance_to(LAKE) * 0.03
		if score < vrel:
			vrel = score
			vbest = c
	var houses: Array = []
	if vbest != Vector2.INF:
		var vy := _pad(vbest, VILLAGE_HALF, 0.0, VILLAGE_BLEND)
		sites["village"] = [vbest, vy]
		print("Village terrace at ", vbest, " y ", vy)
		var face: float = atan2(-(LAKE - vbest).x, -(LAKE - vbest).y)
		for a in range(5):
			for b in range(3):
				if houses.size() >= VILLAGE_HOUSES or d.rng.randf() < 0.2:
					continue
				var c: Vector2 = vbest + Vector2(-VILLAGE_HALF.x + 28.0 * (a + 0.5), -VILLAGE_HALF.y + 28.0 * (b + 0.5))
				c += Vector2(d.rng.randf_range(-3.0, 3.0), d.rng.randf_range(-3.0, 3.0))
				var w: float = d.rng.randf_range(9.0, 12.0)
				var dd: float = d.rng.randf_range(7.5, 9.5)
				var rad: float = Vector2(w, dd + 7.0).length() * 0.5 * PS
				houses.append([c, vy, face + d.rng.randf_range(-0.15, 0.15), rad, w, dd])
				d.note(c, rad)
	sites["houses"] = houses
	# The villa: a sandstone house among boulders on a pad of its own, its front toward the lap, near enough to be
	# seen from it, on the flattest ground it can find.
	var vb := Vector2.INF
	var vscore := INF
	var vyaw := 0.0
	var vreach: float = maxf(VILLA_HALF.x, VILLA_HALF.y) + VILLA_BLEND
	for k in range(3000):
		var c := Vector2(d.rng.randf_range(-430.0, 470.0), d.rng.randf_range(-430.0, 370.0))
		var near: Array = d.road_near(c.x, c.y, VILLA_ROAD.y + 20.0)
		var rd: float = near[0]
		if rd < VILLA_ROAD.x or rd > VILLA_ROAD.y or not d.is_free(c, vreach) or _lake_d(c) < 1.35:
			continue
		if not _rect_clear(c, Vector2(vreach, vreach), d.road_half + 6.0):
			continue
		var rel: Vector2 = d.relief(c.x, c.y, VILLA_HALF.y, true)
		var score: float = (rel.y - rel.x) + absf(rd - 120.0) * 0.06
		if score < vscore:
			vscore = score
			vb = c
			var np: Vector3 = near[1]
			vyaw = atan2(-(np.x - c.x), -(np.z - c.y))
	if vb != Vector2.INF:
		var vfy := _pad(vb, VILLA_HALF, vyaw, VILLA_BLEND)
		sites["villa"] = [vb, vfy, vyaw]
		d.note(vb, VILLA_HALF.length())
		print("Villa at ", vb, " y ", vfy, " facing ", rad_to_deg(vyaw), " score ", vscore)
	# Watchtowers on the dune crests round the valley.
	var towers: Array = []
	var tries := 0
	while towers.size() < TOWERS and tries < 4000:
		tries += 1
		var c := Vector2(d.rng.randf_range(-420, 460), d.rng.randf_range(-420, 360))
		var rd: float = d.road_dist(c.x, c.y, 160.0)
		if rd < 35.0 or rd > 150.0 or not _clear(c, 10.0, 20.0) or _lake_d(c) < 1.15:
			continue
		var y: float = tg.natural_height(c.x, c.y)
		var around: Vector2 = d.relief(c.x, c.y, 14.0, true)
		if y < around.y - 2.5 or y < 24.0:
			continue
		var ok := true
		for t in towers:
			if c.distance_to(t[0]) < 180.0:
				ok = false
		if not ok:
			continue
		towers.append([c, _pad(c, Vector2(6.5, 6.5), 0.0, 10.0), d.rng.randf() * TAU])
		d.note(c, 9.0)
	sites["towers"] = towers
	# The Bedouin camp in the western bowl, inside the long left-hander.
	var camp: Array = []
	tries = 0
	while camp.size() < 3 and tries < 3000:
		tries += 1
		var c := Vector2(d.rng.randf_range(-260.0, -150.0), d.rng.randf_range(20.0, 160.0))
		if not _clear(c, 16.0, 16.0):
			continue
		var ok := true
		for o in camp:
			if c.distance_to(o[0]) < 34.0:
				ok = false
		if not ok:
			continue
		var yaw: float = d.rng.randf() * TAU
		var rel: Vector2 = d.relief(c.x, c.y, 18.0, true)
		if rel.y - rel.x > 6.0:
			continue
		camp.append([c, _pad(c, Vector2(15.0, 13.0), yaw, 22.0), yaw])
		d.note(c, 17.0)
	sites["camp"] = camp
	print("Village houses ", houses.size(), ", towers ", towers.size(), ", tents ", camp.size())


func _ground_and_sky() -> void:
	var pad_list: Array = []
	for o in range(0, pads.size() - 6, 7):
		pad_list.append([Vector2(pads[o], pads[o + 1]), maxf(pads[o + 2], pads[o + 3])])
	var map: Texture2D = d.ground_map(1024, 1000.0, func(x: float, z: float) -> Color:
		var p := Vector2(x, z)
		var yard := 0.0
		for pd in pad_list:
			yard = maxf(yard, 1.0 - smoothstep(float(pd[1]) * 0.75, float(pd[1]) + 4.0, (pd[0] as Vector2).distance_to(p)))
		var rd: float = d.road_dist(x, z, 20.0)
		var piste: float = clampf(1.0 - rd / PISTE_OUT, 0.0, 1.0)
		# The wadi's bed: gravel where the old river ran, out of the water; gravel pans in the dunes.
		var bed: float = 1.0 - smoothstep(18.0, 55.0, _river_d(p))
		var gravel: float = maxf(bed * 0.8, ArabianTerrain.serir(x, z) * 0.5)
		return Color(piste, gravel, yard, 1.0))
	var mat := d.ground_material(map, 1000.0, {
		"rock_height": 1000.0, "rock_slope": 0.95, "high_slope": 0.9, "water_y": WATER_Y,
		"sand_light": Color(0.96, 0.76, 0.52), "sand_deep": Color(0.86, 0.58, 0.36),
		"piste_tint": Color(0.70, 0.50, 0.34), "gravel_tint": Color(0.86, 0.74, 0.60),
	})
	tg.set("grass_material", mat)
	(tg.get_node("Terrain_Visual") as MeshInstance3D).material_override = mat
	# Early afternoon: the sun high in the south-south-west.
	d.environment(Vector3(-50.0, -160.0, 0.0), Color(0.90, 0.82, 0.70), Color(1.0, 0.93, 0.80), 1.4, 0.2)


func _build_fort(root: Node3D) -> void:
	if not sites.has("fort"):
		return
	var s: Array = sites["fort"]
	var c: Vector2 = s[0]
	var r := RandomNumberGenerator.new()
	r.seed = 3131
	d.building(root, "FortWadi", c.x, c.y, float(s[1]), float(s[2]), func(pk, kit) -> void:
		ArabianKit.fort(pk, kit, r, FORT_SIDE, 7.5, 1), 2600.0)


func _build_towers(root: Node3D) -> void:
	var i := 0
	for t in sites["towers"]:
		var c: Vector2 = t[0]
		var h: float = d.rng.randf_range(9.0, 12.0)
		d.building(root, "Watchtower_%d" % i, c.x, c.y, float(t[1]) - 0.1, float(t[2]), func(pk, kit) -> void:
			ArabianKit.watchtower(pk, kit, h, d.rng.randf_range(2.6, 3.1), 1), 1800.0)
		i += 1


func _build_village(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Village"
	root.add_child(node)
	node.owner = level
	# Najdi houses; the plot nearest the village's middle holds its mosque.
	var mosque_i := -1
	if sites.has("village") and not (sites["houses"] as Array).is_empty():
		var vc: Vector2 = sites["village"][0]
		var best_d := INF
		for k in range((sites["houses"] as Array).size()):
			var dd: float = ((sites["houses"][k] as Array)[0] as Vector2).distance_to(vc)
			if dd < best_d:
				best_d = dd
				mosque_i = k
	var i := 0
	for h in sites["houses"]:
		var c: Vector2 = h[0]
		var r := RandomNumberGenerator.new()
		r.seed = 1500 + i
		var storeys: int = 2 if r.randf() < 0.45 else 1
		if i == mosque_i:
			d.building(node, "Mosque", c.x, c.y, float(h[1]), float(h[2]), func(pk, kit) -> void:
				ArabianKit.mosque(pk, kit, r, 10.0, 8.0, 1), 1400.0)
		else:
			d.building(node, "House_%d" % i, c.x, c.y, float(h[1]), float(h[2]), func(pk, kit) -> void:
				ArabianKit.house_najdi(pk, kit, r, float(h[4]), float(h[5]), storeys, true), 1100.0)
		i += 1


func _build_villa(root: Node3D) -> void:
	if not sites.has("villa"):
		return
	var s: Array = sites["villa"]
	var c: Vector2 = s[0]
	var r := RandomNumberGenerator.new()
	r.seed = 4242
	d.building(root, "VillaWadi", c.x, c.y, float(s[1]), float(s[2]), func(pk, kit) -> void:
		ArabianKit.villa(pk, kit, r), 2600.0)


## Where a point of the villa's own (life-size) frame lies on the ground.
func _villa_point(local: Vector2) -> Vector2:
	var s: Array = sites["villa"]
	var yaw: float = s[2]
	var v := Basis(Vector3.UP, yaw) * Vector3(local.x * PS, 0.0, local.y * PS)
	return (s[0] as Vector2) + Vector2(v.x, v.z)


func _build_camp(root: Node3D) -> void:
	var i := 0
	for t in sites["camp"]:
		var c: Vector2 = t[0]
		var r := RandomNumberGenerator.new()
		r.seed = 1900 + i
		d.building(root, "BedouinTent_%d" % i, c.x, c.y, float(t[1]) - 0.03, float(t[2]), func(pk, kit) -> void:
			ArabianKit.bedouin_tent(pk, kit, r, 2 + r.randi() % 3), 900.0)
		i += 1


## The oasis: palms in clumps round the lake's shore and along the wadi's bed, on dry ground a little above
## the water, clear of the lap; palm-frond huts among them.
func _build_oasis(root: Node3D) -> void:
	var palms := d.palms()
	var near_mats := palms.materials(1)
	var far_mats := palms.materials(2)
	var lists := {}
	var placed := 0
	var huts := 0
	var r := d.rng
	for k in range(260):
		var c: Vector2
		if r.randf() < 0.7:
			c = LAKE + Vector2.from_angle(r.randf() * TAU) * Vector2(LAKE_R.x, LAKE_R.y) * r.randf_range(0.9, 1.45)
		else:
			var i: int = r.randi() % (RIVER.size() - 1)
			c = (RIVER[i] as Vector2).lerp(RIVER[i + 1], r.randf()) + Vector2(r.randf_range(-70, 70), r.randf_range(-70, 70))
		var n: int = r.randi_range(2, 7)
		for j in range(n):
			var q: Vector2 = c + Vector2.from_angle(r.randf() * TAU) * r.randf_range(0.0, 11.0)
			var y: float = d.ground(q.x, q.y)
			if y < WATER_Y + 0.35 or y > 12.0 or d.slope(q.x, q.y) > 0.35 or not _clear(q, 2.5, 4.0):
				continue
			var v: int = r.randi() % 5
			if not lists.has(v):
				lists[v] = []
			lists[v].append(d.stand(q.x, q.y, r.randf_range(0.9, 1.2), 0.25, 0.07))
			d.note(q, 2.2)
			placed += 1
		if r.randf() < 0.08 and huts < 7:
			var hc: Vector2 = c + Vector2(r.randf_range(-14, 14), r.randf_range(-14, 14))
			var hy: float = d.ground(hc.x, hc.y)
			if hy > WATER_Y + 0.5 and d.slope(hc.x, hc.y) < 0.15 and _clear(hc, 7.0, 10.0):
				var hr := RandomNumberGenerator.new()
				hr.seed = 2100 + huts
				d.building(root, "Barasti_%d" % huts, hc.x, hc.y, hy - 0.1, r.randf() * TAU, func(pk, kit) -> void:
					ArabianKit.barasti(pk, kit, hr), 700.0)
				d.note(hc, 7.0)
				huts += 1
	# The village's own gardens.
	if sites.has("village"):
		var vc: Vector2 = sites["village"][0]
		for k in range(60):
			var q: Vector2 = vc + Vector2(r.randf_range(-VILLAGE_HALF.x - 25, VILLAGE_HALF.x + 25), r.randf_range(-VILLAGE_HALF.y - 25, VILLAGE_HALF.y + 25))
			if d.slope(q.x, q.y) > 0.3 or not _clear(q, 3.0, 6.0):
				continue
			var v: int = r.randi() % 5
			if not lists.has(v):
				lists[v] = []
			lists[v].append(d.stand(q.x, q.y, r.randf_range(0.9, 1.15), 0.25, 0.05))
			d.note(q, 2.5)
			placed += 1
	# The villa's courtyard.
	if sites.has("villa"):
		for lp in VILLA_PALMS:
			var q: Vector2 = _villa_point(lp)
			var v: int = r.randi() % 5
			if not lists.has(v):
				lists[v] = []
			lists[v].append(d.stand(q.x, q.y, r.randf_range(1.0, 1.2), 0.25, 0.04))
			placed += 1
	for v in lists:
		var nm: ArrayMesh = d.save(palms.mesh(v, 0, near_mats), "datepalm_%d" % v) as ArrayMesh
		var fm: ArrayMesh = d.save(palms.mesh(v, 1, far_mats), "datepalm_far_%d" % v) as ArrayMesh
		d.scatter(root, nm, lists[v], "TallNear_palm%d" % v, 120.0, D.DatePalmKit.NEAR + D.DatePalmKit.FADE, 0.0, true, false)
		d.scatter(root, fm, lists[v], "Tall_palm%d" % v, 120.0, 1500.0, D.DatePalmKit.NEAR - D.DatePalmKit.FADE)
	print("Oasis: ", placed, " palms, ", huts, " huts")


## Rally marker flags along the piste's edges: a pennant on a slim pole every FLAG_EVERY, alternating sides,
## orange and white. Soft ("Flag" in the name): a cart that clips one drives through it.
func _build_flags(root: Node3D) -> void:
	var meshes: Array = []
	for v in range(2):
		var pk := ArabianKit.new_kit(1.0)
		var kit := {}
		var col: Color = [Color(1.0, 0.42, 0.08), Color(0.96, 0.95, 0.92)][v]
		pk.tube(kit, "matte", Vector3(0, -0.3, 0), Vector3(0, 2.6, 0), 0.035, 0.025, 5, Color(0.2, 0.2, 0.2))
		pk.panel(kit, "awning", [Vector3(0, 2.55, 0), Vector3(0.9, 2.3, 0), Vector3(0.9, 1.95, 0), Vector3(0, 1.75, 0)], Vector3(0, 0, 1), col, col.darkened(0.1))
		meshes.append(d.save(ArabianKit.commit(pk, kit), "marker_flag_%d" % v))
	var lists: Array = [[], []]
	var s := 8.0
	var k := 0
	while s < d.length:
		var p: Vector3 = d.curve.sample_baked(s)
		var q: Vector3 = d.curve.sample_baked(fmod(s + 2.0, d.length))
		var tan := q - p
		tan.y = 0.0
		tan = tan.normalized()
		var right := Vector3(-tan.z, 0, tan.x)
		var side: float = 1.0 if k % 2 == 0 else -1.0
		var fp: Vector3 = p + right * side * FLAG_LAT
		var ok: bool = d.road_dist(fp.x, fp.z, 30.0) > FLAG_LAT - 1.0 and d.ground(fp.x, fp.z) > WATER_Y + 0.1
		for g in gates:
			if Vector2(fp.x, fp.z).distance_to(g) < 9.0:
				ok = false
		if ok:
			var b := Basis(Vector3.UP, atan2(tan.x, tan.z) + PI * 0.5).scaled(Vector3.ONE * PS)
			lists[k % 2].append(Transform3D(b, Vector3(fp.x, d.ground(fp.x, fp.z) - 0.05, fp.z)))
		s += FLAG_EVERY
		k += 1
	var n := 0
	for v in range(2):
		n += d.scatter(root, meshes[v], lists[v], "Plants_flag%d" % v, 120.0, 380.0, 0.0, true)
	print("Marker flags: ", n)


func _ok_plant(x: float, z: float, clear_road: float) -> bool:
	if d.road_dist(x, z, clear_road + 12.0) < d.road_half + clear_road:
		return false
	if d.ground(x, z) < WATER_Y + 0.2:
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
	for k in range(4200):
		var c := Vector2(r.randf_range(-860, 860), r.randf_range(-860, 860))
		if c.length() > 860.0 or d.slope(c.x, c.y) > 0.42:
			continue
		var n: int = r.randi_range(3, 9)
		for j in range(n):
			var q: Vector2 = c + Vector2.from_angle(r.randf() * TAU) * r.randf_range(0.0, 5.0)
			if not _ok_plant(q.x, q.y, 1.5):
				continue
			tufts[r.randi() % 3].append(d.stand(q.x, q.y, r.randf_range(0.9, 1.6), 0.06))
		if r.randf() < 0.3 and _ok_plant(c.x, c.y, 3.0):
			brooms[r.randi() % 2].append(d.stand(c.x, c.y, r.randf_range(0.8, 1.3), 0.1))
	var w := d.woods()
	var leaf_near := w.leaf_material(1, 0.1, 10.0)
	var leaf_far := w.leaf_material(2, 0.1, 10.0)
	for lm in [leaf_near, leaf_far]:
		lm.set_shader_parameter("desaturate", 0.55)
		lm.set_shader_parameter("backlight_color", Color(0.48, 0.50, 0.34))
	var bark_n := w.bark_material("ghaf", 1)
	var bark_f := w.bark_material("ghaf", 2)
	for k in range(700):
		var c := Vector2(r.randf_range(-860, 860), r.randf_range(-860, 860))
		if c.length() > 860.0 or d.slope(c.x, c.y) > 0.3 or not _ok_plant(c.x, c.y, 8.0):
			continue
		# Thorn trees in the valley and the wadi's bed, ghaf out on the dunes.
		if _lake_d(c) < 2.4 or _river_d(c) < 90.0:
			samr[r.randi() % 2].append(d.stand(c.x, c.y, r.randf_range(0.75, 1.05), 0.3, 0.08))
			d.note(c, 3.0)
		elif r.randf() < 0.5:
			ghaf[r.randi() % 2].append(d.stand(c.x, c.y, r.randf_range(0.8, 1.15), 0.3, 0.06))
			d.note(c, 3.5)
	for v in range(3):
		d.scatter(root, d.save(d.tuft_mesh(v), "tuft_%d" % v) as Mesh, tufts[v], "Plants_grass%d" % v, 96.0, 260.0, 0.0, false)
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
			d.scatter(root, nm, lists[v], "TallNear_%s%d" % [kind, v], 120.0, 140.0, 0.0, true, false)
			d.scatter(root, fm, lists[v], "Tall_%s%d" % [kind, v], 120.0, 1400.0, 90.0)
	print("Flora: ", tufts[0].size() + tufts[1].size() + tufts[2].size(), " tufts, ", brooms[0].size() + brooms[1].size(), " brooms, ",
			ghaf[0].size() + ghaf[1].size(), " ghaf, ", samr[0].size() + samr[1].size(), " thorn trees")


## Stones in the wadi's bed (rounded by the floods that once ran there), a few outcrops on the dunes.
func _build_rocks(root: Node3D) -> void:
	var mat := d.rock_material(Color(0.66, 0.54, 0.42))
	var meshes: Array = []
	for v in range(4):
		meshes.append(d.save(D.FreightKit.boulder(6100 + v, Vector3(1.3, 0.7, 1.1) if v % 2 == 0 else Vector3(1.0, 0.9, 0.85), mat), "boulder_%d" % v))
	var lists: Array = [[], [], [], []]
	var r := d.rng
	for k in range(900):
		var c: Vector2
		if r.randf() < 0.75:
			var i: int = r.randi() % (RIVER.size() - 1)
			c = (RIVER[i] as Vector2).lerp(RIVER[i + 1], r.randf()) + Vector2(r.randf_range(-60, 60), r.randf_range(-60, 60))
		else:
			c = Vector2(r.randf_range(-800, 800), r.randf_range(-800, 800))
		var n: int = r.randi_range(1, 6)
		for j in range(n):
			var q: Vector2 = c + Vector2.from_angle(r.randf() * TAU) * r.randf_range(0.0, 6.0)
			var s: float = r.randf_range(0.25, 1.1) * (2.2 if j == 0 and r.randf() < 0.1 else 1.0)
			if not _ok_plant(q.x, q.y, 2.0 + s * 1.5):
				continue
			lists[r.randi() % 4].append(Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * s), Vector3(q.x, d.ground(q.x, q.y) - s * 0.25, q.y)))
	var total := 0
	for v in range(4):
		total += d.scatter(root, meshes[v], lists[v], "Rocks_boulder%d" % v, 120.0, 600.0)
	print("Stones: ", total)


## The ford's road no lower than FORD_Y: it ran a metre under the water (0.7m), deep enough to drown a cart, and bots
## drowned crossing. At FORD_Y the cart wades: the water slows it (PlayerCart's shallow drag), it never floods.
const FORD_Y := 1.2

func _raise_ford() -> void:
	var path: Path3D = level.get_node("TrackPath")
	var c: Curve3D = path.curve
	var n := 0
	for i in range(c.point_count):
		var p := c.get_point_position(i)
		if p.y < FORD_Y:
			c.set_point_position(i, Vector3(p.x, FORD_Y, p.z))
			c.set_point_in(i, Vector3(c.get_point_in(i).x, 0.0, c.get_point_in(i).z))
			c.set_point_out(i, Vector3(c.get_point_out(i).x, 0.0, c.get_point_out(i).z))
			n += 1
	print("Ford: ", n, " points raised to ", FORD_Y)

