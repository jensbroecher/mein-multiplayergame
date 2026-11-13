# regenerate_test_track.gd
#
# Builds levels/TestTrackLevel.tscn - the Test Track: a proving ground for trying the cars, listed under "Other Courses"
# (Time Trial, Spectator, Inspect, VS), never in a cup or the random pick (NetworkManager's ALL_STAGES entry has
# "test"). The lap (1.6km, clockwise): a 580m start straight for top speed (distance boards before the first corner), a
# fast right-hander, the long south leg, a tight hairpin, a table-top jump, a chicane, the surface strip (a patch of
# every surface the tyres know, one after the other: sand, snow, ice, mud, grass, gravel, dirt, wood, cobbles), and a
# hill with a kicker at its crest. Boost pads before the hill and out of the last corner.
#
# Built on MiyoshinoStage.gd (the roads, the ground, the gates, the sky): read its header. Here: the ground, the course,
# the strip (`STRIP`, `_build_strip`: ribbons over the road, each its own body with its `surface` meta and a name with
# "Road" in it, so it is track), the jumps and the signs.
extends "res://MiyoshinoStage.gd"

## The surface strip: [surface (Surfaces.NAMES), its kind in test_surface.gdshader, the sign's words]. Each patch is
## STRIP_PATCH long with STRIP_GAP of asphalt after it, from STRIP_X0 westward along the strip's leg.
const STRIP := [["sand", 0, "SAND"], ["snow", 1, "SNOW"], ["ice", 2, "ICE"], ["mud", 3, "MUD"], ["grass", 4, "GRASS"],
	["gravel", 5, "GRAVEL"], ["dirt", 6, "DIRT"], ["wood", 7, "WOOD"], ["rock", 8, "COBBLES"]]
const STRIP_X0 := 22.0
const STRIP_PATCH := 24.0
const STRIP_GAP := 6.0
const STRIP_Z := 70.0
const STRIP_LIFT := 0.03
## The hill on the west leg: its crest (z) and height, and how far either way it rises.
const HILL_Z := -25.0
const HILL_H := 7.0
const HILL_HALF := 70.0
const HILL_X := -280.0
## The pond in the infield: a smooth union of ellipses ([centre, radii]) with a wandering shore, an island, its surface
## at POND_Y (the ground round it about 0.4m higher), its bed shelving to POND_DEEP under the surface.
const POND_BLOBS := [[Vector2(40.0, -12.0), Vector2(46.0, 22.0)], [Vector2(92.0, -2.0), Vector2(30.0, 19.0)],
	[Vector2(12.0, 10.0), Vector2(20.0, 13.0)]]
const POND_ISLAND := [Vector2(84.0, -5.0), Vector2(8.5, 6.0)]
const POND_Y := -0.45
const POND_DEEP := 1.3
## The drum bridge from the south-east bank to the island, and the jetty on the north bank: [x, z, yaw].
const POND_BRIDGE := [Vector3(96.0, 6.5, 0.0), 13.0]
const POND_JETTY := [Vector2(28.0, -33.0), Vector2(28.0, -24.0)]
## Ground kept flat round the buildings, car parks and aprons ([x0, z0, x1, z1]), where the meadows' swells don't go.
const FLAT_RECTS := [[-35.0, -185.0, 95.0, -125.0], [-245.0, -195.0, -140.0, -150.0], [-120.0, -95.0, -30.0, -40.0],
	[140.0, -115.0, 215.0, -45.0], [-150.0, -185.0, -40.0, -138.0]]

var s_p1 := 0.0
var s_hairpin := 0.0
var s_chic0 := 0.0
var s_chic1 := 0.0
var s_strip0 := 0.0
var s_crest := 0.0
var _raw_route: Route


func _configure() -> void:
	level_name = "TestTrackLevel"
	level_path = "res://levels/TestTrackLevel.tscn"
	stem = "testtrack"
	title = "Test Track"
	seed_base = 8800
	road_half = 8.0
	max_grade = 0.14
	smooth_half = 10
	corners = [
		[Vector2(300.0, -120.0), 60.0],    # the end of the start straight: right, south
		[Vector2(300.0, 170.0), 16.0],     # the hairpin, back north-west
		[Vector2(220.0, 70.0), 26.0],      # left, west
		[Vector2(140.0, 70.0), 14.0],      # the chicane
		[Vector2(112.0, 92.0), 14.0],
		[Vector2(78.0, 92.0), 14.0],
		[Vector2(50.0, 70.0), 14.0],
		[Vector2(-280.0, STRIP_Z), 32.0],  # the end of the surface strip: right, north over the hill
		[Vector2(-280.0, -120.0), 32.0],   # right onto the start straight
	]
	finish_at = Vector2(-100.0, -120.0)
	fine_x = Vector2(-460.0, 480.0)
	fine_z = Vector2(-300.0, 340.0)
	tree_margin = 260.0


func _init_noise() -> void:
	super._init_noise()
	_raw_route = Route.new()
	_raw_route.build(corners, true)
	s_p1 = _raw_route.closest_s(Vector2(240.0, -120.0))
	s_hairpin = _raw_route.closest_s(Vector2(300.0, 170.0))
	s_chic0 = _raw_route.closest_s(Vector2(150.0, 70.0))
	s_chic1 = _raw_route.closest_s(Vector2(40.0, 70.0))
	s_strip0 = _raw_route.closest_s(Vector2(STRIP_X0, STRIP_Z))
	s_crest = _raw_route.closest_s(Vector2(HILL_X, HILL_Z))


## A flat proving ground, the hill on the west leg, low hills far round it.
func _natural(x: float, z: float) -> float:
	var h := 0.0
	var dz: float = (z - HILL_Z) / HILL_HALF
	var dx: float = (x - HILL_X) / 60.0
	h += HILL_H * exp(-dz * dz * 2.2) * exp(-dx * dx * 1.6)
	var far: float = Vector2(x - 20.0, z - 25.0).length()
	h += smoothstep(650.0, 2600.0, far) * (60.0 + 190.0 * absf(n_ridge.get_noise_2d(x, z)))
	h += smoothstep(500.0, 900.0, far) * 4.0 * n_hill.get_noise_2d(x, z)
	# Gentle swells in the meadows away from the lap (by its corner polygon, the fillets inside it) and the buildings.
	var away: float = smoothstep(32.0, 70.0, _lap_poly_d(x, z))
	var flat := 0.0
	for r in FLAT_RECTS:
		flat = maxf(flat, _rect_weight(x, z, r, 18.0))
	h += away * (1.0 - flat) * (1.8 * n_land.get_noise_2d(x * 1.6, z * 1.6) + 0.6 * n_fine.get_noise_2d(x * 0.8, z * 0.8))
	# The pond.
	var wd: float = _water_d(x, z)
	if wd < 0.0:
		return POND_Y - 0.25 - POND_DEEP * smoothstep(0.0, 14.0, -wd) + 0.12 * n_fine.get_noise_2d(x * 2.0, z * 2.0)
	if _island_d(x, z) < 0.0:
		return POND_Y + 0.35 + 0.6 * smoothstep(0.0, 5.0, -_island_d(x, z))
	return lerpf(POND_Y + 0.2, h, smoothstep(0.0, 9.0, wd))


## Distance in plan from the lap's corner polygon.
func _lap_poly_d(x: float, z: float) -> float:
	var q := Vector2(x, z)
	var best := INF
	var n: int = corners.size()
	for i in n:
		var a: Vector2 = corners[i][0]
		var b: Vector2 = corners[(i + 1) % n][0]
		best = minf(best, Geometry2D.get_closest_point_to_segment(q, a, b).distance_to(q))
	return best


func _ellipse_d(p: Vector2, c: Vector2, r: Vector2) -> float:
	var q: Vector2 = (p - c) / r
	return (q.length() - 1.0) * minf(r.x, r.y)


func _smin(a: float, b: float, k: float) -> float:
	var hh: float = clampf(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
	return lerpf(b, a, hh) - k * hh * (1.0 - hh)


## Signed distance outside the pond's outline (the island counted as pond).
func _pond_d(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var d: float = _ellipse_d(p, POND_BLOBS[0][0], POND_BLOBS[0][1])
	for i in range(1, POND_BLOBS.size()):
		d = _smin(d, _ellipse_d(p, POND_BLOBS[i][0], POND_BLOBS[i][1]), 14.0)
	return d + 3.2 * n_hill.get_noise_2d(x * 2.4 + 300.0, z * 2.4)


func _island_d(x: float, z: float) -> float:
	return _ellipse_d(Vector2(x, z), POND_ISLAND[0], POND_ISLAND[1]) + 1.2 * n_hill.get_noise_2d(x * 5.0, z * 5.0 + 500.0)


## Signed distance from the water's edge: negative in the water, positive on land (the island is land).
func _water_d(x: float, z: float) -> float:
	return maxf(_pond_d(x, z), -_island_d(x, z))


func _map_water(x: float, z: float) -> float:
	return POND_Y if _water_d(x, z) < 0.0 else NAN


func _extra_refine() -> Array:
	return [[Vector2(-25.0, 135.0)], [Vector2(-45.0, 35.0)]]


## Ground masks: R rock, G bare (the pond's muddy, pebbly margin), B the cherry groves' fallen petals, A the woods' floor.
func _masks(_i: int, x: float, z: float, nrm_y: float, road_d: float) -> Color:
	var off: float = smoothstep(road_half + 4.0, road_half + 16.0, road_d)
	var rock: float = 1.0 - smoothstep(0.62, 0.78, nrm_y)
	var wd: float = _water_d(x, z)
	var bare: float = 1.0 - smoothstep(0.5, 3.5, wd + 1.0 * n_fine.get_noise_2d(x * 3.0, z * 3.0))
	var near_water: float = 1.0 - smoothstep(3.0, 9.0, wd)
	return Color(rock, bare * (1.0 - rock), _grove_w(x, z) * off * (1.0 - near_water), _forest_w(x, z) * off * (1.0 - near_water))


func _wet(x: float, z: float) -> float:
	return 1.0 - smoothstep(-0.5, 2.5, _water_d(x, z))


## The woods: patches by noise, thicker away from the lap, none in the infield's park round the pond.
func _forest_w(x: float, z: float) -> float:
	var w: float = smoothstep(0.05, 0.4, n_wood.get_noise_2d(x, z) * 0.5 + 0.5)
	var away: float = smoothstep(55.0, 110.0, _lap_poly_d(x, z))
	var park: float = 1.0 - smoothstep(30.0, 60.0, _water_d(x, z))
	return clampf(w * away * (1.0 - park), 0.0, 1.0)


## The cherry groves (petals on the ground under them): round the pond and in clumps across the meadows.
func _grove_w(x: float, z: float) -> float:
	var pond: float = smoothstep(4.0, 10.0, _water_d(x, z)) * (1.0 - smoothstep(22.0, 40.0, _water_d(x, z)))
	var clumps: float = smoothstep(0.62, 0.8, n_fine.get_noise_2d(x * 0.35 + 70.0, z * 0.35) * 0.5 + 0.5)
	return clampf(maxf(pond * 0.7, clumps * (1.0 - _forest_w(x, z))), 0.0, 1.0)


func _sections(r: Route) -> Array:
	return [[0.0, r.length, K_ASPHALT, r.half]]


func _environment() -> Dictionary:
	return {"sun_pitch": -58.0, "sun_yaw": 20.0, "cloud_coverage": 0.3, "cloud_seed": 51.7, "fog_end": 3600.0, "sun_energy": 1.4}


func _ground_params(m: ShaderMaterial) -> void:
	m.set_shader_parameter("petal_amount", 0.35)


func _petals_at(_x: float, _z: float) -> float:
	return 0.0


# ======================================================================================
#  Gameplay
# ======================================================================================

func _place_gameplay(root: Node3D) -> void:
	var fin: float = _finish_s()
	_checkpoints([
		_closest_s(Vector2(300.0, 60.0)),      # the south leg
		_closest_s(Vector2(170.0, 70.0)),      # before the chicane
		_closest_s(Vector2(-130.0, STRIP_Z)),  # the surface strip
		_closest_s(Vector2(-280.0, -70.0)),    # over the hill
	])
	_boosts([
		["Boost_Hill", _closest_s(Vector2(-280.0, 22.0)), 0.0],
		["Boost_StraightL", fin - 95.0, -3.0],
		["Boost_StraightR", fin - 95.0, 3.0],
	])
	# A kicker just before the hill's crest: big air over the top.
	_kicker(root, "CrestJump", lap, s_crest - 12.0, 9.0, 1.3, 0.35)
	# A table-top on the leg out of the hairpin: up, along the top, down the far side.
	_ramp(root, "TableTop", s_hairpin + 58.0, 8.0, 1.6, 7.0, 9.0)


## A WoodenRamp across the lap, its toe at s: `table` along the top, `tail` back down (0: a kicker).
func _ramp(root: Node3D, jump_name: String, toe: float, length: float, height: float, table: float, tail: float) -> void:
	var j: Node3D = (load("res://WoodenRamp.tscn") as PackedScene).instantiate()
	j.name = jump_name
	var sp: Dictionary = lap.spot(toe, 0.0, 0.0)
	j.position = sp["pos"]
	j.rotation_degrees = Vector3(0, sp["yaw"], 0)
	j.set("length", length)
	j.set("height", height)
	j.set("curve", 0.3)
	j.set("table_length", table)
	j.set("tail_length", tail)
	j.set("width", lap.half * 2.0)
	j.set("wood_color", Color(0.55, 0.42, 0.30))
	j.set("trim_color", Color(0.95, 0.80, 0.12))
	root.add_child(j)
	var lp: Dictionary = lap.spot(toe + length, 0.0, 0.0)
	var slope: float = height / length * 1.3
	_jump_lips.append({"name": jump_name, "lip": (lp["pos"] as Vector3) + Vector3(0, height, 0),
			"dir": ((lp["fwd"] as Vector3) + Vector3(0, slope, 0)).normalized()})


# ======================================================================================
#  The surface strip and the signs
# ======================================================================================

func _build_dressing(root: Node3D) -> void:
	_build_strip(root)
	_build_signs(root)
	var fin: float = _finish_s()
	_build_start_crowd(root, fin - 70.0, fin + 70.0, road_half + 3.0, fin - 8.0, fin + 8.0, seed_base + 11)
	_build_paddock(root)
	_build_buildings(root)
	_build_pond(root)
	_build_cones(root)
	# Guardrails round the outside of the corners (every corner turns right: the outside is the left).
	var body: StaticBody3D = _body(root, "GuardrailBody_Lap")
	for c in [Vector2(300.0, -120.0), Vector2(300.0, 170.0), Vector2(-280.0, STRIP_Z), Vector2(-280.0, -120.0)]:
		var sc: float = lap.closest_s(c)
		_rails(body, sc - 60.0, sc + 60.0, -1.0)


# ======================================================================================
#  The pond
# ======================================================================================

const PondKit = preload("res://PondKit.gd")

## The pond's water: a grid of 4m cells over every cell within 6m of the water (the banks hide the rest), still_water.
func _build_water(root: Node3D) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://still_water.gdshader")
	mat.set_shader_parameter("water_color", Color(0.04, 0.10, 0.08, 1.0))
	mat.set_shader_parameter("sky_tint", Color(0.58, 0.72, 0.86, 1.0))
	mat.set_shader_parameter("sky_reflect", 0.6)
	mat.set_shader_parameter("ripple_tile", 12.0)
	mat.set_shader_parameter("ripple_strength", 0.06)
	var noise_tex := NoiseTexture2D.new()
	noise_tex.seamless = true
	noise_tex.as_normal_map = true
	noise_tex.width = 256
	noise_tex.height = 256
	var nz := FastNoiseLite.new()
	nz.frequency = 0.02
	noise_tex.noise = nz
	mat.set_shader_parameter("noise_tex", noise_tex)
	var smat: Material = _save_res(mat, "pond_water_material")
	var lo := Vector2(-40.0, -60.0)
	var hi := Vector2(150.0, 45.0)
	var cell := 4.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wlo := Vector2(1e9, 1e9)
	var whi := Vector2(-1e9, -1e9)
	for j in range(int((hi.y - lo.y) / cell)):
		for i in range(int((hi.x - lo.x) / cell)):
			var x0: float = lo.x + float(i) * cell
			var z0: float = lo.y + float(j) * cell
			var x1: float = x0 + cell
			var z1: float = z0 + cell
			if minf(minf(_water_d(x0, z0), _water_d(x1, z0)), minf(_water_d(x0, z1), _water_d(x1, z1))) > 6.0:
				continue
			wlo = Vector2(minf(wlo.x, x0), minf(wlo.y, z0))
			whi = Vector2(maxf(whi.x, x1), maxf(whi.y, z1))
			var a := Vector3(x0, 0.0, z0)
			var b := Vector3(x1, 0.0, z0)
			var c := Vector3(x1, 0.0, z1)
			var d := Vector3(x0, 0.0, z1)
			# Clockwise from above (Godot's front face).
			for v in [a, b, c, a, c, d]:
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(v.x, v.z))
				st.add_vertex(v)
	st.index()
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, smat)
	var water := MeshInstance3D.new()
	water.name = "PondWater"
	water.mesh = _save_res(mesh, "pond")
	water.position = Vector3(0, POND_Y, 0)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.set_meta(&"water_surface_y", POND_Y)
	water.set_meta(&"water_bounds_min", wlo)
	water.set_meta(&"water_bounds_max", whi)
	root.add_child(water)


## The pond's plants (PondKit: bulrushes and rushes in the shallows, irises on the wet bank, water lilies on the open
## water near the shores), its koi, a heron in the shallows, a drum bridge to the island with a lantern and a weeping
## cherry on it, a jetty, rocks, benches and lanterns round it; flowers across the meadows.
func _build_pond(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Pond"
	root.add_child(node)
	var body := StaticBody3D.new()
	body.name = "PondSolids"
	body.set_meta(&"surface", "rock")
	node.add_child(body)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_base + 501
	var reed := ShaderMaterial.new()
	reed.shader = load("res://dune_grass.gdshader")
	reed.set_shader_parameter("sway", 0.1)
	reed.set_shader_parameter("speed", 1.1)
	var reed_mat: Material = _save_res(reed, "pond_reed_material")
	var lily := StandardMaterial3D.new()
	lily.vertex_color_use_as_albedo = true
	lily.vertex_color_is_srgb = true
	lily.roughness = 0.38
	lily.cull_mode = BaseMaterial3D.CULL_DISABLED
	var lily_mat: Material = _save_res(lily, "pond_lily_material")
	# 0, 1 bulrushes, 2 rushes, 3 yellow irises, 4 purple irises, 5-7 lilies.
	var meshes: Array = [_save_res(PondKit.bulrush(0, reed_mat), "pond_bulrush_0"), _save_res(PondKit.bulrush(1, reed_mat), "pond_bulrush_1"),
		_save_res(PondKit.rushes(0, reed_mat), "pond_rushes_0"), _save_res(PondKit.iris(0, reed_mat), "pond_iris_0"),
		_save_res(PondKit.iris(1, reed_mat, Color(0.48, 0.30, 0.80)), "pond_iris_1"),
		_save_res(PondKit.lilies(0, lily_mat), "pond_lilies_0"), _save_res(PondKit.lilies(1, lily_mat), "pond_lilies_1"),
		_save_res(PondKit.lilies(2, lily_mat), "pond_lilies_2")]
	var patch := FastNoiseLite.new()
	patch.seed = seed_base + 7
	patch.frequency = 1.0 / 14.0
	var lists: Array = []
	for k in meshes.size():
		lists.append([])
	var x := -40.0
	while x < 150.0:
		var z := -60.0
		while z < 45.0:
			var px: float = x + rng.randf() * 1.6
			var pz: float = z + rng.randf() * 1.6
			z += 1.6
			var wd: float = _water_d(px, pz)
			if wd > 4.0 or wd < -18.0:
				continue
			var depth: float = POND_Y - _ground_at(px, pz)
			var pn: float = patch.get_noise_2d(px, pz)
			var roll: float = rng.randf()
			var kind := -1
			if depth > 0.5 and wd > -14.0 and wd < -3.0 and pn > 0.05 and roll < 0.32:
				kind = 5 + rng.randi() % 3
			elif depth > -0.1 and depth < 0.55 and pn < -0.1 and roll < 0.55:
				kind = rng.randi() % 2 if roll < 0.4 else 2
			elif depth > -0.6 and depth <= 0.08 and roll < 0.16:
				kind = 3 if pn > 0.2 else (4 if pn < -0.25 else 2)
			if kind < 0:
				continue
			if _near_pond_works(px, pz):
				continue
			var sc: float = PROP_SCALE * (rng.randf_range(0.9, 1.4) if kind >= 5 else rng.randf_range(0.9, 1.35))
			var y: float = POND_Y if kind >= 5 else _ground_at(px, pz) - 0.05
			lists[kind].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(px, y, pz)))
		x += 1.6
	var counts := []
	for k in meshes.size():
		counts.append(lists[k].size())
		if lists[k].is_empty():
			continue
		var nm: String = ("PondLilies_%d" if k >= 5 else "PondGrass_%d") % k
		_multimesh(node, nm, meshes[k], lists[k], 220.0 if k >= 5 else 300.0, false)
	print("  pond plants: ", counts)
	_build_pond_works(node, body, rng)
	_build_koi(node, rng)
	_build_heron(node)
	_build_meadow_flowers(node, reed_mat, rng)


## The drum bridge's line (island edge to the bank, along z at POND_BRIDGE's x) and the jetty: [a, b] each.
func _bridge_ends() -> Array:
	var bx: float = POND_BRIDGE[0].x
	var za: float = POND_ISLAND[0].y
	while _island_d(bx, za) < 0.0:
		za += 0.25
	var zb: float = za
	while _pond_d(bx, zb) < 0.0:
		zb += 0.25
	return [Vector2(bx, za - 1.5), Vector2(bx, zb + 2.0)]


func _jetty_ends() -> Array:
	var jx: float = POND_JETTY[0].x
	var z0: float = POND_JETTY[0].y
	while _pond_d(jx, z0) > 0.0:
		z0 += 0.25
	return [Vector2(jx, z0 - 3.0), Vector2(jx, z0 + 9.0)]


func _near_pond_works(x: float, z: float) -> bool:
	var q := Vector2(x, z)
	for ends in [_bridge_ends(), _jetty_ends()]:
		if Geometry2D.get_closest_point_to_segment(q, ends[0], ends[1]).distance_to(q) < 3.2:
			return true
	return false


func _build_pond_works(node: Node3D, body: StaticBody3D, rng: RandomNumberGenerator) -> void:
	# The drum bridge to the island.
	var be: Array = _bridge_ends()
	var bmid: Vector2 = (be[0] + be[1]) * 0.5
	var span: float = be[0].distance_to(be[1])
	var by: float = POND_Y + 0.3
	var bxf := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(bmid.x, by, bmid.y))
	_put("pond_bridge", prop_kit, bxf, "arched_bridge", [span / PROP_SCALE, 2.4, 1.2], 900.0)
	_box_shape(body, Transform3D(Basis(), Vector3(bmid.x, by + 0.8, bmid.y)), Vector3(4.2, 1.6, span))
	_note_rect(bmid, 6.0, span, 0.0, 1.0)
	# On the island: a lantern, rocks, a weeping cherry, azaleas.
	var ic: Vector2 = POND_ISLAND[0]
	var lp := Vector3(ic.x - 2.0, 0.0, ic.y + 1.0)
	lp.y = _ground_at(lp.x, lp.z)
	_put("pond_stone", prop_kit, Transform3D(Basis(Vector3.UP, 0.4), lp), "stone_lantern", [1, 2.1], 600.0)
	_box_shape(body, Transform3D(Basis(), lp + Vector3(0, 1.6, 0)), Vector3(1.4, 3.2, 1.4))
	extra_trees.append(["shidare", ic.x + 2.5, ic.y - 1.5, 0.95, 0])
	extra_trees.append(["tsutsuji", ic.x - 4.5, ic.y - 2.0, 0.8, 1])
	extra_trees.append(["tsutsuji", ic.x + 5.0, ic.y + 2.5, 0.7, 0])
	# The jetty: planks on posts from the north bank out over the water, a bench at its end.
	var je: Array = _jetty_ends()
	var jk = PGK.new_kit(PROP_SCALE)
	var jkit := {}
	var deck_y: float = POND_Y + 0.55
	jk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * PROP_SCALE), Vector3.ZERO))
	PGK.jetty(jk, jkit, Vector3(je[0].x, deck_y, je[0].y) / PROP_SCALE, Vector3(je[1].x, deck_y, je[1].y) / PROP_SCALE, 2.2, (POND_Y - 1.6) / PROP_SCALE)
	var jm := MeshInstance3D.new()
	jm.name = "PondJetty"
	jm.mesh = _save_building_mesh(PGK.commit(jk, jkit), "pond_jetty")
	jm.visibility_range_end = 700.0
	node.add_child(jm)
	var jl: float = je[0].distance_to(je[1])
	_box_shape(body, Transform3D(Basis(), Vector3(je[0].x, deck_y - 0.1, (je[0].y + je[1].y) * 0.5)), Vector3(3.6, 0.3, jl))
	# Rocks along the shore, lanterns and benches round it.
	var rocks := 0
	for k in 140:
		var a: float = rng.randf() * TAU
		var r: float = rng.randf_range(10.0, 60.0)
		var q := Vector2(55.0 + cos(a) * r * 1.6, -5.0 + sin(a) * r * 0.8)
		var wd: float = _water_d(q.x, q.y)
		if wd < -0.6 or wd > 1.8 or _near_pond_works(q.x, q.y):
			continue
		var rs: float = rng.randf_range(0.5, 1.2)
		var rp := Vector3(q.x, _ground_at(q.x, q.y) - 0.15, q.y)
		_put(_cell_key("pond_rocks", rp), prop_kit, Transform3D(Basis(), rp), "garden_rock", [rs, rs * 0.65, k * 13 + 5], 500.0)
		_box_shape(body, Transform3D(Basis(), rp + Vector3(0, rs * 0.35 * PROP_SCALE, 0)), Vector3(rs, rs * 0.65, rs) * PROP_SCALE * 1.4)
		rocks += 1
		if rocks >= 34:
			break
	var placed := 0
	for k in 200:
		var a: float = rng.randf() * TAU
		var q := Vector2(55.0 + cos(a) * 75.0, -5.0 + sin(a) * 36.0)
		# Walk in until 7m from the water.
		var t := 1.0
		while t > 0.2 and _water_d(lerpf(55.0, q.x, t), lerpf(-5.0, q.y, t)) > 7.0:
			t -= 0.02
		var p := Vector2(lerpf(55.0, q.x, t), lerpf(-5.0, q.y, t))
		if _water_d(p.x, p.y) < 5.0 or _near_pond_works(p.x, p.y) or _occupied(p.x, p.y):
			continue
		var look: Vector2 = Vector2(55.0, -5.0) - p
		var yaw: float = atan2(look.x, look.y)
		var g := Vector3(p.x, _ground_at(p.x, p.y), p.y)
		if placed % 3 == 2:
			_put(_cell_key("pond_lanterns", g), prop_kit, Transform3D(Basis(Vector3.UP, yaw), g), "stone_lantern", [0, 1.8], 600.0)
			_box_shape(body, Transform3D(Basis(), g + Vector3(0, 1.4, 0)), Vector3(1.2, 2.8, 1.2))
		else:
			_put(_cell_key("pond_benches", g), prop_kit, Transform3D(Basis(Vector3.UP, yaw), g + Vector3(0, 0.0, 0)), "park_bench", [], 500.0)
			_box_shape(body, Transform3D(Basis(Vector3.UP, yaw), g + Vector3(0, 0.6, 0)), Vector3(3.0, 1.2, 1.2))
		_note_circle(p, 2.5)
		placed += 1
		if placed >= 9:
			break
	print("  pond works: bridge %.0fm, jetty %.0fm, %d rocks, %d benches and lanterns" % [span, jl, rocks, placed])


## Koi circling in the pond's deeper water (KoiFish.gd, koi.gdshader), near the surface.
func _build_koi(node: Node3D, rng: RandomNumberGenerator) -> void:
	var kinds := PackedInt32Array()
	var a_pts := PackedVector3Array()
	var b_pts := PackedVector3Array()
	var speeds := PackedFloat32Array()
	var phases := PackedFloat32Array()
	var sizes := PackedFloat32Array()
	var custom: Array = []
	var pats: Array = [0, 1, 0, 2, 3, 0, 4, 2, 1, 0, 3, 0]
	var tries := 0
	while kinds.size() < 14 and tries < 400:
		tries += 1
		var c := Vector2(rng.randf_range(-10.0, 120.0), rng.randf_range(-35.0, 20.0))
		var rad: float = rng.randf_range(2.0, 5.0)
		if _water_d(c.x, c.y) > -(rad + 2.5):
			continue
		var i: int = kinds.size()
		kinds.append(0)
		a_pts.append(Vector3(c.x, POND_Y - 0.14 - 0.05 * float(i % 3), c.y))
		var sp: float = rng.randf_range(0.35, 0.75) * (1.0 if i % 2 == 0 else -1.0)
		b_pts.append(Vector3(rad, 0.0, 0.0))
		speeds.append(sp)
		phases.append(rng.randf() * TAU)
		sizes.append(PROP_SCALE * rng.randf_range(0.9, 1.2))
		custom.append(Color(float(pats[i % pats.size()]), rng.randf(), rng.randf(), absf(sp)))
	var mat := ShaderMaterial.new()
	mat.shader = load("res://koi.gdshader")
	var mesh: ArrayMesh = _koi_mesh()
	mesh.surface_set_material(0, _save_res(mat, "koi_material"))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _save_res(mesh, "koi")
	mm.instance_count = kinds.size()
	var kn := MultiMeshInstance3D.new()
	kn.name = "PondKoi"
	kn.set_script(load("res://KoiFish.gd"))
	kn.set("kinds", kinds)
	kn.set("a_pts", a_pts)
	kn.set("b_pts", b_pts)
	kn.set("speeds", speeds)
	kn.set("phases", phases)
	kn.set("sizes", sizes)
	kn.set("centre", Vector3(55.0, POND_Y, -5.0))
	# Where they are at t = 0, straight into the buffer (the dummy renderer ignores set_instance_transform).
	var buf := PackedFloat32Array()
	buf.resize(kinds.size() * 16)
	for i in range(kinds.size()):
		var t: Transform3D = kn.call("pose_at", i, 0.0)
		var bs: Basis = t.basis
		var o: int = i * 16
		var row: Array = [bs.x.x, bs.y.x, bs.z.x, t.origin.x, bs.x.y, bs.y.y, bs.z.y, t.origin.y, bs.x.z, bs.y.z, bs.z.z, t.origin.z]
		for k in range(12):
			buf[o + k] = row[k]
		var c: Color = custom[i]
		buf[o + 12] = c.r
		buf[o + 13] = c.g
		buf[o + 14] = c.b
		buf[o + 15] = c.a
	mm.buffer = buf
	kn.multimesh = mm
	kn.visibility_range_end = 140.0
	kn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	kn.set_meta(&"skip_dressing_colliders", true)
	node.add_child(kn)
	print("  koi: %d" % kinds.size())


## A koi at life size, its nose toward +z (Yoshino Rapids' fish): a body of revolution flattened at the sides, a forked
## tail, a dorsal fin, two pectoral fins; UV.x along it, UV.y 1 on the fins.
func _koi_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z0 := 0.35
	var z1 := -0.22
	var stations := 10
	var segs := 10
	var rings: Array = []
	for i in range(stations + 1):
		var t: float = float(i) / float(stations)
		var z: float = lerpf(z0, z1, t)
		var prof: float = sin(PI * pow(clampf(t * 1.05, 0.0, 1.0), 0.6))
		var hw: float = 0.085 * prof + 0.008
		var hh: float = 0.07 * prof + 0.008
		var ring: Array = []
		for j in range(segs):
			var a: float = TAU * float(j) / float(segs)
			ring.append([Vector3(cos(a) * hw, sin(a) * hh - 0.01 * (1.0 - t), z), Vector3(cos(a) / hw, sin(a) / hh, 0.0).normalized(), (z0 - z) / (z0 + 0.55)])
		rings.append(ring)
	var put := func(v: Array, fin: float) -> void:
		st.set_normal(v[1])
		st.set_uv(Vector2(float(v[2]), fin))
		st.add_vertex(v[0])
	for i in range(stations):
		for j in range(segs):
			var j1: int = (j + 1) % segs
			for k in [rings[i][j], rings[i + 1][j], rings[i + 1][j1], rings[i][j], rings[i + 1][j1], rings[i][j1]]:
				put.call(k, 0.0)
	var fins: Array = [
		[Vector3(0, 0, z1), Vector3(0, 0.13, -0.5), Vector3(0, 0.0, -0.4)], [Vector3(0, 0, z1), Vector3(0, 0.0, -0.4), Vector3(0, -0.13, -0.5)],
		[Vector3(0, 0.07, 0.12), Vector3(0, 0.14, 0.0), Vector3(0, 0.06, -0.12)],
		[Vector3(0.07, -0.03, 0.18), Vector3(0.17, -0.06, 0.08), Vector3(0.07, -0.04, 0.08)],
		[Vector3(-0.07, -0.03, 0.18), Vector3(-0.17, -0.06, 0.08), Vector3(-0.07, -0.04, 0.08)]]
	for f in fins:
		var n: Vector3 = ((f[2] as Vector3) - (f[0] as Vector3)).cross((f[1] as Vector3) - (f[0] as Vector3)).normalized()
		for v in f:
			var vv: Vector3 = v
			put.call([vv, n, (z0 - vv.z) / (z0 + 0.55)], 1.0)
	return st.commit()


## A grey heron in the shallows at the pond's west end (Heron.gd: it takes off when a cart comes near, flies a loop over
## the pond and lands again).
func _build_heron(node: Node3D) -> void:
	var at := Vector3.ZERO
	var found := false
	for k in 400:
		var q := Vector2(-5.0 + float(k % 20) * 1.5, 2.0 + float(k / 20) * 1.0)
		var depth: float = POND_Y - _ground_at(q.x, q.y)
		if depth > 0.12 and depth < 0.3:
			at = Vector3(q.x, _ground_at(q.x, q.y), q.y)
			found = true
			break
	if not found:
		return
	var h := Node3D.new()
	h.name = "Heron"
	h.set_script(load("res://Heron.gd"))
	h.transform = Transform3D(Basis(Vector3.UP, 1.9), at)
	var loop := PackedVector3Array()
	for p in [Vector3(20.0, 5.0, -6.0), Vector3(55.0, 12.0, -14.0), Vector3(105.0, 15.0, -8.0), Vector3(118.0, 13.0, 6.0),
			Vector3(80.0, 10.0, 12.0), Vector3(35.0, 6.0, 8.0), Vector3(at.x + 6.0, 2.0, at.z)]:
		loop.append(Vector3(p.x, POND_Y + p.y, p.z))
	h.set("flight", loop)
	node.add_child(h)


## Wildflowers in patches across the meadows: irises in yellow, purple, white and pink, clear of the lap, the buildings
## and the woods, in 120m cells drawn to 260m.
func _build_meadow_flowers(node: Node3D, reed_mat: Material, rng: RandomNumberGenerator) -> void:
	var colours := [Color(0.98, 0.82, 0.12), Color(0.48, 0.30, 0.80), Color(0.96, 0.95, 0.92), Color(0.95, 0.45, 0.62),
		Color(0.92, 0.32, 0.12)]
	var meshes: Array = []
	for k in colours.size():
		meshes.append(_save_res(PondKit.iris(k % 2, reed_mat, colours[k]), "meadow_flower_%d" % k))
	var patch := FastNoiseLite.new()
	patch.seed = seed_base + 13
	patch.frequency = 1.0 / 30.0
	var cells := {}
	var n := 0
	var x: float = fine_x.x + 20.0
	while x < fine_x.y - 20.0:
		var z: float = fine_z.x + 20.0
		while z < fine_z.y - 20.0:
			var px: float = x + rng.randf() * 3.0
			var pz: float = z + rng.randf() * 3.0
			z += 3.0
			var pn: float = patch.get_noise_2d(px, pz)
			if pn < 0.32 or rng.randf() > (pn - 0.32) * 2.2:
				continue
			if _water_d(px, pz) < 2.0 or _occupied(px, pz) or _forest_w(px, pz) > 0.25 or _road_dist(px, pz) < road_half + 6.0:
				continue
			var k: int = int(absf(patch.get_noise_2d(px * 0.2 + 400.0, pz * 0.2)) * 9.0) % colours.size()
			var key := Vector3i(floori(px / 120.0), floori(pz / 120.0), k)
			if not cells.has(key):
				cells[key] = []
			cells[key].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * PROP_SCALE * rng.randf_range(0.9, 1.3)),
					Vector3(px, _ground_at(px, pz) - 0.05, pz)))
			n += 1
		x += 3.0
	for key in cells.keys():
		_multimesh(node, "MeadowFlowers_%d_%d_%d" % [key.x, key.y, key.z], meshes[key.z], cells[key], 260.0, false)
	print("  meadow flowers: %d clumps" % n)


# ======================================================================================
#  The proving ground's buildings
# ======================================================================================

const PGK = preload("res://ProvingGroundKit.gd")
## [builder, x, z, yaw (degrees: 0 faces +z, south), range]. The pit building and the office face the start straight
## from the north, in the sun; the control tower (the 3D logo turning on its roof) and the Tech Centre face it from the
## infield.
const BUILDINGS := [["pit", 30.0, -161.2, 0.0, 0.0], ["office", -207.0, -178.0, 0.0, 1600.0],
	["tower", -55.0, -70.0, 180.0, 0.0], ["workshop", 178.0, -75.0, 180.0, 1600.0]]
## The logo on the tower, in model units to game metres (the model is 9 x 3.4m: 21.6m across here), turning slowly.
const LOGO_SCALE := 2.4
const LOGO_SPIN := 9.0

var _bld_mats := {}
var _sign_font: Font


## Each building one mesh (ProvingGroundKit, life size grown by PROP_SCALE) with its signs, box colliders (nothing on
## this level gets them from DressingColliders), its footprint noted so the woods keep off; paved aprons before the pit
## building and the Tech Centre (track: a car can drive in), car parks, light masts, the logo on the tower, flags.
func _build_buildings(root: Node3D) -> void:
	var holder := Node3D.new()
	holder.name = "ProvingGround"
	root.add_child(holder)
	var body := StaticBody3D.new()
	body.name = "BuildingsBody"
	body.set_meta(&"surface", "rock")
	holder.add_child(body)
	_sign_font = load("res://fonts/NotoSansSC-Yunhai.otf")
	for b in BUILDINGS:
		var kind: String = b[0]
		var yaw: float = deg_to_rad(float(b[3]))
		var c := Vector3(float(b[1]), 0.0, float(b[2]))
		c.y = _ground_at(c.x, c.z)
		var xf := Transform3D(Basis(Vector3.UP, yaw), c)
		var pk = PGK.new_kit(PROP_SCALE)
		pk.set_frame(Transform3D(xf.basis * Basis.from_scale(Vector3.ONE * PROP_SCALE), xf.origin))
		var kit := {}
		var labels: Array = []
		match kind:
			"pit": PGK.pit_building(pk, kit, labels)
			"tower": PGK.control_tower(pk, kit, labels)
			"workshop": PGK.workshop(pk, kit, labels)
			"office": PGK.office(pk, kit, labels)
		var frame: Transform3D = pk.xf
		var mi := MeshInstance3D.new()
		mi.name = kind.to_pascal_case()
		mi.mesh = _save_building_mesh(PGK.commit(pk, kit), "building_" + kind)
		if float(b[4]) > 0.0:
			mi.visibility_range_end = float(b[4])
		holder.add_child(mi)
		for l in labels:
			_building_label(mi, String(l[0]), frame * (l[1] as Vector3), (xf.basis * (l[2] as Vector3)).normalized(),
					float(l[3]) * PROP_SCALE, l[4], float(l[5]) * PROP_SCALE if l.size() > 5 else 0.0)
		# Colliders and the footprint.
		for bx in _building_boxes(kind):
			var lo := Vector3(bx[0], 0.0, bx[2])
			var hi := Vector3(bx[1], bx[4], bx[3])
			_box_shape(body, Transform3D(xf.basis, xf * (((lo + hi) * 0.5) * PROP_SCALE)), (hi - lo) * PROP_SCALE)
		var fp: Array = PGK.footprint(kind)
		_note_frame(xf, Vector2(fp[0], fp[2]), Vector2(fp[1], fp[3]), 6.0)
		if kind == "tower":
			_tower_logo(holder, xf)
			# Two flags either side of the lobby's canopy, streaming away from the road.
			for sx in [-11.0, 11.0]:
				var fpos: Vector3 = xf * (Vector3(sx, 0.0, 11.0) * PROP_SCALE)
				fpos.y = _ground_at(fpos.x, fpos.z)
				var flag := Node3D.new()
				flag.name = "LogoFlag_Tower%d" % (0 if sx < 0.0 else 1)
				flag.set_script(load("res://LogoFlag.gd"))
				flag.set("pole_height", 12.0)
				var fly := Vector3(signf(sx), 0, 0)
				flag.transform = Transform3D(Basis(fly, Vector3.UP, fly.cross(Vector3.UP)), fpos)
				holder.add_child(flag)
	_build_aprons(holder)
	_build_car_parks(holder)


## Box colliders per building: [x0, x1, z0, z1, height] in its frame, life metres.
func _building_boxes(kind: String) -> Array:
	match kind:
		"pit":
			var out: Array = [[-30.4, 30.4, -6.3, 6.95, 10.4], [30.4, 33.2, -3.6, 6.6, 9.2]]
			# The tyre stacks by every other garage door.
			for i in range(1, 10, 2):
				var x1: float = -30.0 + 6.0 * float(i) + 5.6
				out.append([x1 - 1.75, x1 - 0.15, 6.7, 7.5, 1.0])
			return out
		"tower":
			return [[-9.6, 9.6, -6.6, 6.6, 5.6], [-3.6, 3.6, -4.1, 3.1, 35.0], [-3.2, 3.2, 8.7, 9.3, 3.6]]
		"workshop":
			return [[-12.3, 12.3, -15.4, 15.4, 10.0], [12.0, 18.4, -2.3, 12.4, 4.2], [-8.2, 16.2, 15.4, 15.7, 6.0]]
		"office":
			return [[-13.2, 13.2, -7.2, 8.0, 11.8], [13.0, 17.3, -3.3, 3.3, 13.2], [-11.8, -6.4, 10.3, 10.7, 3.2]]
	return []


func _save_building_mesh(mesh: ArrayMesh, mesh_name: String) -> Resource:
	for si in range(mesh.get_surface_count()):
		var m: Material = mesh.surface_get_material(si)
		if m == null or not m.resource_path.is_empty():
			continue
		var id: int = m.get_instance_id()
		if not _bld_mats.has(id):
			_bld_mats[id] = _save_res(m, "bldmat_%d" % _bld_mats.size(), stem + "prop_")
		mesh.surface_set_material(si, _bld_mats[id])
	return _save_res(mesh, mesh_name, stem + "prop_")


## A sign's letters (the kit's labels: cap height and board width in game metres), in Noto Sans Bold.
func _building_label(parent: Node3D, text: String, at: Vector3, n: Vector3, cap: float, col: Color, max_w: float) -> void:
	var lab := Label3D.new()
	lab.text = text
	lab.font = _sign_font
	lab.font_size = 64
	var pixel: float = cap / 44.8
	if max_w > 0.0:
		var w: float = _sign_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x
		pixel = minf(pixel, max_w / maxf(w, 1.0))
	lab.pixel_size = pixel
	lab.modulate = col
	lab.outline_size = 0
	lab.double_sided = false
	lab.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	lab.transform = Transform3D(Basis.looking_at(-n, Vector3.UP), at)
	parent.add_child(lab)


## The 3D logo (generated/logo/RcVibeLogo.tscn) back to back on the tower's post, turning slowly (Spinner.gd, wall clock).
func _tower_logo(holder: Node3D, xf: Transform3D) -> void:
	var spin := Node3D.new()
	spin.name = "TowerLogo"
	spin.set_script(load("res://Spinner.gd"))
	spin.set("axis", Vector3.UP)
	spin.set("degrees_per_second", LOGO_SPIN)
	spin.position = xf * (Vector3(0, PGK.TOWER_LOGO_Y, -0.5) * PROP_SCALE)
	holder.add_child(spin)
	var size: Vector3 = Vector3(9.0, 3.416, 0.584)
	for k in 2:
		var logo: Node3D = (load("res://generated/logo/RcVibeLogo.tscn") as PackedScene).instantiate()
		logo.name = "Logo%d" % k
		logo.scale = Vector3.ONE * LOGO_SCALE
		logo.rotation.y = PI * float(k)
		logo.position = Vector3(0, size.y * 0.5 * LOGO_SCALE, 0)
		spin.add_child(logo)


## Concrete aprons before the pit building (to the road's edge) and the Tech Centre: a slab 6cm up with painted bay
## boxes, solid and track ("...Road"), so a car can drive off the straight onto them.
func _build_aprons(holder: Node3D) -> void:
	var pk = PGK.new_kit(1.0)
	var kit := {}
	var body := StaticBody3D.new()
	body.name = "PitApronRoad"
	body.set_meta(&"surface", "asphalt")
	holder.add_child(body)
	# [x0, x1, z0 (the building's side), z1 (the road's edge), bay lines every (0: none)]: the pit apron north of the
	# straight, the Tech Centre's south of it.
	var aprons := [[-19.0, 79.0, -150.0, -120.0 - road_half - 0.4, 9.6], [151.0, 198.0, -100.0, -120.0 + road_half + 0.4, 0.0]]
	for a in aprons:
		var x0: float = a[0]
		var x1: float = a[1]
		var z0: float = minf(a[2], a[3])
		var z1: float = maxf(a[2], a[3])
		var y: float = maxf(maxf(_ground_at(x0, z0), _ground_at(x1, z0)), maxf(_ground_at(x0, z1), _ground_at(x1, z1))) + 0.06
		PGK.blk(pk, kit, "concrete", Vector3(x0, y - 0.5, z0), Vector3(x1, y, z1), Color(0.70, 0.70, 0.68))
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(x1 - x0, 0.5, z1 - z0)
		col.shape = shape
		col.position = Vector3((x0 + x1) * 0.5, y - 0.25, (z0 + z1) * 0.5)
		body.add_child(col)
		# A white line round it, bay lines across, a yellow pit-lane line along its middle.
		var w := 0.15
		for e in [[x0, z0, x1, z0 + w], [x0, z1 - w, x1, z1], [x0, z0, x0 + w, z1], [x1 - w, z0, x1, z1]]:
			PGK.blk(pk, kit, "alu", Vector3(e[0], y, e[1]), Vector3(e[2], y + 0.012, e[3]), Color(0.92, 0.92, 0.90))
		if float(a[4]) > 0.0:
			var bx: float = x0 + 1.4
			while bx < x1:
				PGK.blk(pk, kit, "alu", Vector3(bx - 0.08, y, z0 + 0.2), Vector3(bx + 0.08, y + 0.012, z0 + 9.0), Color(0.92, 0.92, 0.90))
				bx += float(a[4])
			PGK.blk(pk, kit, "alu", Vector3(x0 + 0.5, y, z0 + 11.0), Vector3(x1 - 0.5, y + 0.012, z0 + 11.2), Color(0.95, 0.78, 0.10))
		_note_rect(Vector2((x0 + x1) * 0.5, (z0 + z1) * 0.5), x1 - x0, z1 - z0, 0.0, 2.0)
	var mi := MeshInstance3D.new()
	mi.name = "Aprons"
	mi.mesh = _save_building_mesh(PGK.commit(pk, kit), "aprons")
	holder.add_child(mi)
	# Light masts along the pit apron's back and the Tech Centre's apron.
	var mk = PGK.new_kit(PROP_SCALE)
	var mkit := {}
	var spots: Array = []
	var x := -14.0
	while x < 78.0:
		spots.append(Vector3(x, 0, -147.5))
		x += 23.0
	for sx in [154.0, 195.0]:
		spots.append(Vector3(sx, 0, -102.5))
	for sp in spots:
		var p: Vector3 = sp
		p.y = _ground_at(p.x, p.z)
		mk.set_frame(Transform3D(Basis(Vector3.UP, 0.0 if p.z < -120.0 else PI).scaled(Vector3.ONE * PROP_SCALE), p))
		PGK.light_mast(mk, mkit, 7.5)
		_box_shape(body_or(holder), Transform3D(Basis(), p + Vector3(0, 6.0, 0)), Vector3(0.4, 12.0, 0.4))
	mk.reset_frame()
	var mm := MeshInstance3D.new()
	mm.name = "LightMasts"
	mm.mesh = _save_building_mesh(PGK.commit(mk, mkit), "light_masts")
	mm.visibility_range_end = 1200.0
	holder.add_child(mm)


func body_or(holder: Node3D) -> StaticBody3D:
	return holder.get_node("BuildingsBody") as StaticBody3D


## Car parks beside the office and the tower: asphalt with bay lines, CampKit cars in some bays (box colliders).
func _build_car_parks(holder: Node3D) -> void:
	var pk := PropKit.new()
	pk.material_for = func(key: String) -> Material: return _camp_material(key)
	var camp := CampKit.new(pk)
	var kit := {}
	var lk = PGK.new_kit(1.0)
	var lkit := {}
	var body := body_or(holder)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_base + 77
	var cols := [Color(0.92, 0.92, 0.90), Color(0.10, 0.10, 0.12), Color(0.55, 0.10, 0.10), Color(0.20, 0.30, 0.55),
		Color(0.65, 0.67, 0.70), Color(0.85, 0.45, 0.08)]
	# [x0, x1, z0, z1]: two rows of bays facing a middle aisle along x.
	for lot in [[-180.0, -146.0, -188.0, -160.0], [-112.0, -78.0, -86.0, -58.0]]:
		var x0: float = lot[0]
		var x1: float = lot[1]
		var z0: float = lot[2]
		var z1: float = lot[3]
		var y: float = maxf(_ground_at(x0, z0), _ground_at(x1, z1)) + 0.05
		PGK.blk(lk, lkit, "matte", Vector3(x0, y - 0.4, z0), Vector3(x1, y, z1), Color(0.20, 0.21, 0.22))
		var bay := 4.4
		var depth := 9.0
		var n: int = int((x1 - x0) / bay)
		for row in 2:
			var zr: float = z0 if row == 0 else z1 - depth
			for i in n + 1:
				var bx: float = x0 + float(i) * bay
				PGK.blk(lk, lkit, "alu", Vector3(bx - 0.06, y, zr + 0.3), Vector3(bx + 0.06, y + 0.01, zr + depth - 0.3), Color(0.9, 0.9, 0.88))
			for i in n:
				if rng.randf() < 0.35:
					continue
				var cx: float = x0 + (float(i) + 0.5) * bay
				var cz: float = zr + depth * 0.5
				var yaw: float = 0.0 if row == 0 else PI
				pk.set_frame(Transform3D(Basis(Vector3.UP, yaw + rng.randf_range(-0.04, 0.04)).scaled(Vector3.ONE * PROP_SCALE),
						Vector3(cx, y, cz)))
				camp.vehicle(kit, "suv" if rng.randf() < 0.5 else "van", cols[rng.randi() % cols.size()], rng.randi() % 2)
				_box_shape(body, Transform3D(Basis(Vector3.UP, yaw), Vector3(cx, y + 1.5 * PROP_SCALE * 0.6, cz)),
						Vector3(2.0, 1.8, 5.2) * PROP_SCALE)
		_note_rect(Vector2((x0 + x1) * 0.5, (z0 + z1) * 0.5), x1 - x0, z1 - z0, 0.0, 3.0)
	pk.reset_frame()
	var mi := MeshInstance3D.new()
	mi.name = "CarParkCars"
	mi.mesh = _save_res(pk.commit(kit), "carpark_cars", stem + "prop_")
	mi.visibility_range_end = 900.0
	holder.add_child(mi)
	var li := MeshInstance3D.new()
	li.name = "CarParkPaving"
	li.mesh = _save_building_mesh(PGK.commit(lk, lkit), "carpark_paving")
	holder.add_child(li)


## Guardrail pieces along the lap from s0 to s1 on one side (-1 left), with a box collider along them.
func _rails(body: StaticBody3D, s0: float, s1: float, side: float) -> void:
	var s: float = s0
	while s < s1 - 0.5:
		var sb: float = minf(s + 12.0, s1)
		var a: Vector3 = lap.pt(s) + lap.rt(s) * side * (lap.half + 4.0)
		var b: Vector3 = lap.pt(sb) + lap.rt(sb) * side * (lap.half + 4.0)
		a.y = _ground_at(a.x, a.z)
		b.y = _ground_at(b.x, b.z)
		_put_world("guard", a, prop_kit, "guardrail", [_life(a), _life(b)], 600.0)
		# A box along the piece as drawn, on the ground it stands on (the lap's own height is metres off it on the
		# hill's corners).
		var l: float = a.distance_to(b)
		if l > 0.1:
			var fwd: Vector3 = (b - a) / l
			var x: Vector3 = Vector3.UP.cross(fwd).normalized()
			_box_shape(body, Transform3D(Basis(x, fwd.cross(x).normalized(), fwd).orthonormalized(),
					(a + b) * 0.5 + Vector3(0, 0.5, 0)), Vector3(0.4, 1.8, l + 0.3))
		s = sb


## Cones along both edges of the chicane and on the hairpin's apex: knocked flying by any cart (KnockableProps, as on
## Lakeside). DressingColliders gives nothing on this level a collider ("track" is in the level's name), so every prop
## here brings its own.
func _build_cones(root: Node3D) -> void:
	var pk := PropKit.new()
	pk.material_for = func(key: String) -> Material: return _camp_material(key)
	var camp := CampKit.new(pk)
	var spots: Array = []
	var s: float = s_chic0 - 10.0
	while s < s_chic1 + 10.0:
		for side in [-1.0, 1.0]:
			spots.append(lap.spot(s, side * (lap.half + 0.6), 0.0)["pos"])
		s += 5.0
	for k in range(-3, 4):
		spots.append(lap.spot(s_hairpin + float(k) * 4.0, lap.half + 0.6, 0.0)["pos"])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_base + 41
	var xfs: Array[Transform3D] = []
	for p in spots:
		var q: Vector3 = p
		q.y = _ground_at(q.x, q.z)
		xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), q))
	var kit := {}
	pk.set_frame(Transform3D(Basis().scaled(Vector3.ONE * PROP_SCALE), Vector3.ZERO))
	camp.cone(kit)
	pk.reset_frame()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _save_res(pk.commit(kit), "cone", stem + "prop_")
	mm.instance_count = xfs.size()
	mm.buffer = PropKit.transform_buffer(xfs)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Cones"
	mmi.set_script(load("res://KnockableProps.gd"))
	mmi.set("prop_transforms", xfs)
	mmi.set("boxes", [[Vector3(0, 0.03, 0) * PROP_SCALE, Vector3(0.38, 0.06, 0.38) * PROP_SCALE],
			[Vector3(0, 0.36, 0) * PROP_SCALE, Vector3(0.2, 0.62, 0.2) * PROP_SCALE]])
	mmi.set("prop_mass", 6.0)
	mmi.set("push_speed", 1.5)
	mmi.set("release_radius", 3.2)
	mmi.set("centre_of_mass_y", 0.06)
	mmi.multimesh = mm
	mmi.visibility_range_end = 500.0
	root.add_child(mmi)


## The paddock north of the start straight: gazebos over tables, the team's vehicles.
func _build_paddock(root: Node3D) -> void:
	_note_rect(Vector2(-100.0, -160.0), 110.0, 45.0, 0.0, 2.0)
	var pk := PropKit.new()
	pk.material_for = func(key: String) -> Material: return _camp_material(key)
	var camp := CampKit.new(pk)
	var kit := {}
	var fin: float = _finish_s()
	var body := StaticBody3D.new()
	body.name = "PaddockBody"
	root.add_child(body)
	var canopies := [Color(0.95, 0.80, 0.10), Color(0.10, 0.40, 0.85), Color(0.90, 0.20, 0.15), Color(0.12, 0.62, 0.40)]
	for i in range(4):
		var sp: Dictionary = lap.spot(fin - 40.0 + float(i) * 26.0, -(lap.half + 24.0), 0.0)
		var pos: Vector3 = sp["pos"]
		pos.y = _ground_at(pos.x, pos.z)
		var fwd: Vector3 = sp["fwd"]
		var xf := Transform3D(Basis(fwd, Vector3.UP, fwd.cross(Vector3.UP)).rotated(Vector3.UP, PI * 0.5), pos)
		pk.set_frame(xf.scaled_local(Vector3.ONE * PROP_SCALE * 1.4))
		camp.gazebo(kit, canopies[i], i % 2 == 0)
		pk.set_frame(xf.translated_local(Vector3(0, 0, 0)).scaled_local(Vector3.ONE * PROP_SCALE))
		camp.folding_table(kit, Color(0.92, 0.92, 0.90))
		# The gazebo's four legs and the table (life size 1.84 x 0.74 x 0.76m), solid.
		var gs: float = PROP_SCALE * 1.4
		for lx in [-1.47, 1.47]:
			for lz in [-1.47, 1.47]:
				_box_shape(body, xf * Transform3D(Basis(), Vector3(lx, 1.03, lz) * gs), Vector3(0.12, 2.06, 0.12) * gs)
		_box_shape(body, xf * Transform3D(Basis(), Vector3(0, 0.37, 0) * PROP_SCALE), Vector3(1.84, 0.74, 0.76) * PROP_SCALE)
		if i % 2 == 0:
			# The walled gazebo's back wall and its two side banners.
			_box_shape(body, xf * Transform3D(Basis(), Vector3(0, 1.03, 1.5) * gs), Vector3(2.94, 2.06, 0.1) * gs)
			for wx in [-1.49, 1.49]:
				_box_shape(body, xf * Transform3D(Basis(), Vector3(wx, 0.45, 0) * gs), Vector3(0.1, 0.9, 2.94) * gs)
		var vp: Dictionary = lap.spot(fin - 40.0 + float(i) * 26.0 + 2.0, -(lap.half + 40.0), 0.0)
		var vpos: Vector3 = vp["pos"]
		vpos.y = _ground_at(vpos.x, vpos.z)
		var vxf := Transform3D(Basis(fwd, Vector3.UP, fwd.cross(Vector3.UP)), vpos)
		pk.set_frame(vxf.scaled_local(Vector3.ONE * PROP_SCALE))
		camp.vehicle(kit, ["motorhome", "van", "suv", "van"][i], [Color(0.95, 0.95, 0.93), Color(0.20, 0.30, 0.55), Color(0.55, 0.10, 0.10), Color(0.85, 0.85, 0.82)][i], i % 2)
		var bs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(4.0, 3.0, 9.0) * PROP_SCALE
		bs.shape = bx
		bs.transform = Transform3D(vxf.basis, vpos + Vector3(0, 1.5 * PROP_SCALE, 0))
		body.add_child(bs)
	pk.reset_frame()
	var mi := MeshInstance3D.new()
	mi.name = "Paddock"
	mi.mesh = _save_res(pk.commit(kit), "paddock", stem + "prop_")
	mi.visibility_range_end = 900.0
	root.add_child(mi)


## The trees: mixed woods (cedar, pine, maple, mountain cherry, bamboo thickets) in patches away from the lap, cherry
## clumps and lone trees across the meadows, weeping cherries, red maples and azaleas round the pond.
func _tree_pick(x: float, z: float, roll: float, rng: RandomNumberGenerator) -> Array:
	var rd: float = _road_dist(x, z)
	if rd < 26.0:
		return []
	var wd: float = _water_d(x, z)
	if wd < 3.0 or _island_d(x, z) < 1.0:
		return []
	# Round the pond.
	if wd < 24.0:
		if roll > 0.42:
			return []
		var k: float = rng.randf()
		if wd < 9.0 and k < 0.35:
			return ["shidare", rng.randf_range(0.85, 1.1), rng.randi_range(0, 1)]
		if k < 0.55:
			return ["tsutsuji", rng.randf_range(0.7, 1.0), rng.randi_range(0, 1)]
		if k < 0.75:
			return ["momiji_red", rng.randf_range(0.8, 1.05), rng.randi_range(0, 1)]
		if k < 0.88:
			return ["matsu", rng.randf_range(0.8, 1.0), rng.randi_range(0, 1)]
		return ["sakura", rng.randf_range(0.85, 1.05), rng.randi_range(0, 1)]
	var f: float = _forest_w(x, z)
	if f > 0.05 and rd > 45.0:
		if roll > f * 0.6:
			return []
		var bamboo: float = n_fine.get_noise_2d(x * 0.5 - 200.0, z * 0.5)
		if bamboo > 0.45:
			return ["take", rng.randf_range(0.9, 1.15), rng.randi_range(0, 1)]
		var k2: float = rng.randf()
		if k2 < 0.42:
			return ["sugi", rng.randf_range(0.8, 1.2), rng.randi_range(0, 1)]
		if k2 < 0.6:
			return ["matsu", rng.randf_range(0.85, 1.15), rng.randi_range(0, 1)]
		if k2 < 0.76:
			return ["momiji", rng.randf_range(0.9, 1.2), rng.randi_range(0, 1)]
		if k2 < 0.9:
			return ["yamazakura", rng.randf_range(0.85, 1.1), rng.randi_range(0, 1)]
		return ["tsutsuji", rng.randf_range(0.8, 1.1), rng.randi_range(0, 1)]
	# The meadows: cherry clumps, now and then a lone pine, maple or cherry, azaleas along the woods' edges.
	var g: float = _grove_w(x, z)
	if g > 0.3 and roll < g * 0.45:
		return ["sakura" if rng.randf() < 0.65 else "yamazakura", rng.randf_range(0.85, 1.1), rng.randi_range(0, 1)]
	if f > 0.0 and f < 0.3 and roll < 0.2:
		return ["tsutsuji", rng.randf_range(0.75, 1.05), rng.randi_range(0, 1)]
	if rd > 40.0 and roll < 0.025:
		var k3: float = rng.randf()
		return [["matsu", "momiji", "sakura", "momiji_red"][int(k3 * 4.0) % 4], rng.randf_range(0.9, 1.15), rng.randi_range(0, 1)]
	return []


func _strip_material(kind: int) -> Material:
	var m := ShaderMaterial.new()
	m.shader = load("res://test_surface.gdshader")
	m.set_shader_parameter("kind", kind)
	m.set_shader_parameter("sand_tex", load("res://materials/sand.png"))
	m.set_shader_parameter("dirt_tex", load("res://materials/dirt.png"))
	m.set_shader_parameter("grass_tex", load("res://materials/grass.png"))
	m.set_shader_parameter("gravel_tex", load("res://materials/dark_canyon_rock.png"))
	m.set_shader_parameter("wood_tex", load("res://materials/wood_planks.png"))
	m.set_shader_parameter("cobble_tex", load("res://materials/cobblestone.png"))
	return _save_res(m, "strip_material_%d" % kind)


## Each patch: a ribbon over the road (its width and a little more), STRIP_LIFT up, in its own body named for the surface
## with "Road" in it (track to PlayerCart) and the surface in its meta; the word painted on the road at its start and a
## board beside it.
func _build_strip(root: Node3D) -> void:
	var holder := Node3D.new()
	holder.name = "SurfaceStrip"
	root.add_child(holder)
	for i in range(STRIP.size()):
		var surf: String = STRIP[i][0]
		var x0: float = STRIP_X0 - float(i) * (STRIP_PATCH + STRIP_GAP)
		var s0: float = lap.closest_s(Vector2(x0, STRIP_Z))
		var s1: float = lap.closest_s(Vector2(x0 - STRIP_PATCH, STRIP_Z))
		var half: float = lap.half + 0.4
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var cols := 8
		var s := s0
		var rows: Array = []
		while true:
			var row: Array = []
			for c in range(cols + 1):
				var lat: float = lerpf(-half, half, float(c) / float(cols))
				row.append([lap.surf(s, lat) + Vector3(0, STRIP_LIFT, 0), Vector2(s - s0, lat)])
			rows.append(row)
			if s >= s1:
				break
			s = minf(s + 1.0, s1)
		for k in range(rows.size() - 1):
			for c in range(cols):
				var a: Array = rows[k][c]
				var b: Array = rows[k][c + 1]
				var c2: Array = rows[k + 1][c + 1]
				var d: Array = rows[k + 1][c]
				for v in [a, c2, b, a, d, c2]:
					st.set_normal(Vector3.UP)
					st.set_uv(v[1])
					st.add_vertex(v[0])
		st.generate_normals()
		var mesh: ArrayMesh = st.commit()
		mesh.surface_set_material(0, _strip_material(int(STRIP[i][1])))
		mesh = _save_res(mesh, "strip_%s" % surf) as ArrayMesh
		var body := StaticBody3D.new()
		body.name = "TestStrip%sRoad" % surf.capitalize()
		body.set_meta(&"surface", surf)
		holder.add_child(body)
		var mi := MeshInstance3D.new()
		mi.name = "Patch"
		mi.mesh = mesh
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		cs.shape = mesh.create_trimesh_shape()
		body.add_child(cs)
		# The word on the road, just past the patch's start, and a board on the right.
		var word := Label3D.new()
		word.name = "Word"
		word.text = String(STRIP[i][2])
		word.font_size = 256
		word.pixel_size = 0.012
		word.outline_size = 0
		word.modulate = Color(1.0, 1.0, 1.0, 0.85) if i != 1 and i != 2 else Color(0.15, 0.25, 0.45, 0.85)
		var wp: Dictionary = lap.spot(s0 + 4.0, 0.0, STRIP_LIFT + 0.02)
		word.position = wp["pos"]
		word.rotation = Vector3(-PI * 0.5, deg_to_rad(float(wp["yaw"])), 0.0)
		holder.add_child(word)
		_sign(root, "Strip_" + surf, s0 - 2.0, lap.half + 3.5, String(STRIP[i][2]), Color(0.10, 0.12, 0.16))
		print("  strip: %s %.0f-%.0fm" % [surf, s0, s1])


## A board on two posts beside the lap at s (lateral `lat`, + right of travel) facing the oncoming cars.
func _sign(root: Node3D, sign_name: String, s: float, lat: float, words: String, board := Color(0.08, 0.30, 0.62)) -> void:
	var w: float = maxf(3.0, 0.62 * float(words.length()) + 1.2)
	# `lat` is the board's inner edge.
	var sp: Dictionary = lap.spot(s, lat + w * 0.5, 0.0)
	var y: float = _ground_at((sp["pos"] as Vector3).x, (sp["pos"] as Vector3).z)
	# A body of its own: DressingColliders gives nothing on this level a collider ("track" is in its name).
	var n := StaticBody3D.new()
	n.name = "Sign_" + sign_name
	n.set_meta(&"surface", "rock")
	n.position = Vector3((sp["pos"] as Vector3).x, y, (sp["pos"] as Vector3).z)
	# Facing back down the road, toward the cars coming.
	n.rotation = Vector3(0.0, deg_to_rad(float(sp["yaw"])) + PI, 0.0)
	root.add_child(n)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = board
	mat.roughness = 0.6
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.75, 0.76, 0.78)
	post_mat.metallic = 0.6
	post_mat.roughness = 0.4
	var bm := BoxMesh.new()
	bm.size = Vector3(w, 1.5, 0.12)
	bm.material = mat
	var bi := MeshInstance3D.new()
	bi.name = "SignBoard"
	bi.mesh = bm
	bi.position = Vector3(0, 3.3, 0)
	n.add_child(bi)
	for sx in [-1.0, 1.0]:
		var pm := CylinderMesh.new()
		pm.top_radius = 0.09
		pm.bottom_radius = 0.09
		pm.height = 4.3
		pm.material = post_mat
		var post := MeshInstance3D.new()
		post.name = "SignPost"
		post.mesh = pm
		post.position = Vector3(sx * (w * 0.5 - 0.5), 2.15, -0.1)
		n.add_child(post)
		var pc := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.12
		cyl.height = 4.3
		pc.shape = cyl
		pc.position = post.position
		n.add_child(pc)
	var bc := CollisionShape3D.new()
	var bshape := BoxShape3D.new()
	bshape.size = Vector3(w, 1.5, 0.2)
	bc.shape = bshape
	bc.position = Vector3(0, 3.3, 0)
	n.add_child(bc)
	for face in [1.0, -1.0]:
		var lb := Label3D.new()
		lb.text = words
		lb.font_size = 96
		lb.pixel_size = 0.01
		lb.outline_size = 0
		lb.modulate = Color.WHITE
		lb.position = Vector3(0, 3.3, 0.07 * face)
		lb.rotation = Vector3(0, 0.0 if face > 0.0 else PI, 0)
		lb.double_sided = false
		n.add_child(lb)


func _build_signs(root: Node3D) -> void:
	var fin: float = _finish_s()
	_sign(root, "TopSpeed", fin + 20.0, lap.half + 4.0, "TOP SPEED STRAIGHT")
	for d in [300, 200, 100]:
		_sign(root, "Board%d" % d, s_p1 - float(d) - 30.0, lap.half + 3.0, str(d), Color(0.10, 0.10, 0.12))
	_sign(root, "Hairpin", s_hairpin - 70.0, lap.half + 4.0, "HAIRPIN")
	_sign(root, "TableTop", s_hairpin + 40.0, lap.half + 4.0, "TABLE-TOP JUMP")
	_sign(root, "Chicane", s_chic0 - 25.0, lap.half + 4.0, "CHICANE")
	_sign(root, "Strip", s_strip0 - 25.0, lap.half + 4.0, "SURFACE STRIP", Color(0.62, 0.30, 0.06))
	_sign(root, "Hill", s_crest - 60.0, lap.half + 4.0, "HILL + CREST JUMP")
