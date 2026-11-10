# regenerate_senbon_sakura.gd
#
# Builds levels/SenbonSakuraLevel.tscn - Senbon Sakura Pass, the first stage of the Miyoshino GP: a mountain road
# (a touge) up through a thousand cherry trees in full bloom on a spring morning. The lap starts in the hanami park by
# the pond on the valley floor heading east, climbs the south-facing slope in three long legs and two hairpins through
# the groves (the upper hairpin can be cut on foot: a flagged path under a tunnel of vermilion torii), runs west along
# the ridge past the teahouse and its view, turns back at the shrine in the cedars, comes down through the cedar
# forest over a vermilion arch bridge across the brook's ravine and returns to the park.
#
# Everything shared with the other Miyoshino stages (routes, heights, the graded heightfield, the road ribbons, gates,
# sky, woods, the prop batches) is MiyoshinoStage.gd: read its header first. Here: the course, the hill, what grows
# where, and the dressing.
extends "res://MiyoshinoStage.gd"

## The hill: the ground rises from the valley floor (z > RISE_Z0) northward at SLOPE to the ridge at RIDGE_Z.
const RISE_Z0 := -15.0
const SLOPE := 0.142
const RIDGE_Z := -500.0
## The brook's ravine down the west of the hill: its line x = GULLY_X + sway, how deep and how wide.
const GULLY_X := -425.0
const GULLY_DEPTH := 13.0
const GULLY_HALF := 26.0
## The pond in the park south of the start straight: centre, radii, the water's level.
const POND_C := Vector2(60.0, 215.0)
const POND_R := Vector2(95.0, 46.0)
const POND_Y := -0.7
const POND_DEEP := 2.4
## The park: level ground between the start straight and the pond.
const PARK_RECT := [-330.0, 84.0, 330.0, 168.0]

## The torii path: from the lap before the upper hairpin up the slope to the lap after it.
const TORII_A := Vector2(280.0, -283.3)
const TORII_B := Vector2(280.0, -338.6)

var s_bridge0 := 0.0
var s_bridge1 := 0.0


func _configure() -> void:
	level_name = "SenbonSakuraLevel"
	level_path = "res://levels/SenbonSakuraLevel.tscn"
	stem = "senbon"
	title = "Senbon Sakura Pass"
	seed_base = 7100
	road_half = 7.5
	max_grade = 0.095
	corners = [
		[Vector2(400.0, 70.0), 60.0],      # the end of the start straight: left, north toward the hill
		[Vector2(400.0, -60.0), 45.0],     # left onto the first leg, west-north-west up the slope
		[Vector2(220.0, -100.0), 120.0],   # a sweep on the first leg
		[Vector2(30.0, -185.0), 24.0],     # the lower hairpin
		[Vector2(200.0, -262.0), 110.0],   # a sweep on the second leg
		[Vector2(380.0, -310.0), 24.0],    # the upper hairpin
		[Vector2(170.0, -370.0), 130.0],   # a sweep on the third leg
		[Vector2(-60.0, -467.0), 90.0],    # onto the ridge, west
		[Vector2(-300.0, -498.0), 150.0],  # the ridge's bend at the teahouse
		[Vector2(-560.0, -500.0), 35.0],   # the shrine in the cedars: back, south-east and down
		[Vector2(-330.0, -330.0), 45.0],   # right, south-west toward the ravine
		[Vector2(-520.0, -160.0), 45.0],   # left, down to the valley
		[Vector2(-420.0, 70.0), 50.0],     # left onto the start straight
	]
	finish_at = Vector2(-90.0, 70.0)
	fine_x = Vector2(-720.0, 560.0)
	fine_z = Vector2(-680.0, 340.0)
	tree_step = 10.5
	tree_margin = 320.0


# ======================================================================================
#  The hill
# ======================================================================================

func _gully_x(z: float) -> float:
	return GULLY_X + (z + 245.0) * 0.45 + 10.0 * sin(z / 60.0)


func _gully_w(z: float) -> float:
	return smoothstep(-370.0, -310.0, z) * (1.0 - smoothstep(-70.0, -20.0, z))


## The hill is lower toward the west (the ridge runs down to the shrine).
func _hill_scale(x: float) -> float:
	return 1.0 - 0.27 * smoothstep(-120.0, -600.0, x)


func _natural(x: float, z: float) -> float:
	# The slope and the ridge: up at SLOPE to the ridge, then gently down its north side.
	var up: float = maxf(0.0, RISE_Z0 - z)
	var hs: float = _hill_scale(x)
	var ridge_h: float = (RISE_Z0 - RIDGE_Z) * SLOPE * hs
	var south: float = up * SLOPE * hs
	var north: float = ridge_h + 6.0 - (RIDGE_Z - z) * 0.07
	# A smooth minimum of the two faces rounds the crest.
	var k := 14.0
	var hh: float = -k * log(exp(-south / k) + exp(-north / k))
	# Spurs and hollows across the slope, none on the valley floor.
	var on_hill: float = smoothstep(0.0, 120.0, up)
	hh += on_hill * (7.0 * n_hill.get_noise_2d(x * 0.7, z * 0.7) + 2.2 * n_fine.get_noise_2d(x * 0.5, z * 0.5))
	# The valley floor: nearly level, a little swell; low hills and far ranges to the south and all round.
	hh += 0.8 * n_land.get_noise_2d(x * 2.0, z * 2.0) * (1.0 - on_hill)
	var far: float = Vector2(x, z - 100.0).length()
	hh += smoothstep(700.0, 3600.0, far) * (140.0 + 260.0 * absf(n_ridge.get_noise_2d(x, z))) * smoothstep(120.0, 900.0, z + 260.0 + absf(x) * 0.2)
	hh += smoothstep(900.0, 4200.0, far) * 180.0 * (0.5 + 0.5 * n_land.get_noise_2d(x * 0.3, z * 0.3)) * (1.0 - smoothstep(120.0, 900.0, z + 260.0 + absf(x) * 0.2))
	# The brook's ravine.
	var gz: float = _gully_w(z)
	if gz > 0.0:
		var dx: float = (x - _gully_x(z)) / GULLY_HALF
		hh -= GULLY_DEPTH * gz * exp(-dx * dx)
	# The park's level ground and the pond.
	hh = lerpf(hh, 0.25, _rect_weight(x, z, PARK_RECT, 40.0))
	var q := Vector2((x - POND_C.x) / POND_R.x, (z - POND_C.y) / POND_R.y)
	var pr: float = q.length()
	if pr < 1.5:
		hh = lerpf(hh, 0.1, 1.0 - smoothstep(1.0, 1.5, pr))
		hh -= (1.0 - smoothstep(0.55, 1.0, pr)) * (POND_DEEP + 0.8) + (1.0 - smoothstep(0.9, 1.08, pr)) * 0.8
	return hh


func _map_water(x: float, z: float) -> float:
	var q := Vector2((x - POND_C.x) / POND_R.x, (z - POND_C.y) / POND_R.y)
	return POND_Y if q.length() < 1.2 else NAN


# ======================================================================================
#  The course
# ======================================================================================

func _plan_bridge() -> void:
	# The descent's leg from corner 6 to corner 7 crosses the ravine: where the ravine is over 4m deep under the line.
	var s6: float = 0.0
	var s: float = 0.0
	var a: float = -1.0
	var b: float = -1.0
	# Walk the lap, looking only along the leg between corners 6 and 7.
	s6 = _closest_s_raw(Vector2(-330.0, -330.0))
	s = s6
	while s < s6 + 330.0:
		var p: Vector2 = _raw_at(s)
		var dx: float = absf(p.x - _gully_x(p.y))
		if dx < GULLY_HALF * 0.95 and _gully_w(p.y) > 0.5:
			if a < 0.0:
				a = s
			b = s
		s += 1.0
	s_bridge0 = a - 4.0
	s_bridge1 = b + 4.0
	bridges = [["lap", s_bridge0, s_bridge1, 0.5]]
	print("  the ravine's bridge from %.0f to %.0fm (%.0fm)" % [s_bridge0, s_bridge1, s_bridge1 - s_bridge0])


## The lap before `lap` exists (bridges must be known before the heights are planned): a throwaway Route.
var _raw_route: Route

func _raw() -> Route:
	if _raw_route == null:
		_raw_route = Route.new()
		_raw_route.build(corners, true)
	return _raw_route


func _raw_at(s: float) -> Vector2:
	return _raw().at(s)["p"]


func _closest_s_raw(q: Vector2) -> float:
	return _raw().closest_s(q)


func _init_noise() -> void:
	super._init_noise()
	_plan_bridge()


func _plan_routes() -> void:
	# The torii path: a flagged footpath straight up the slope, cutting the upper hairpin.
	var r: Route = _add_route("ToriiPath", [[TORII_A, 0.0], [TORII_B, 0.0]], 4.2, true, 0.2)
	_report_profile(r)
	shortcuts = [["ToriiPath", 0.5]]


func _sections(r: Route) -> Array:
	if r.name == "ToriiPath":
		return [[road_half + 0.6, r.length - road_half - 0.6, K_FOOTPATH, r.half]]
	return [[0.0, s_bridge0, K_ASPHALT, r.half], [s_bridge0, s_bridge1, K_PLANKS, r.half], [s_bridge1, r.length, K_ASPHALT, r.half]]


func _grade_params(r: Route, _s: float) -> Array:
	if r.name == "ToriiPath":
		return [r.half + 1.0, r.half + 1.0, 0.9, 0.8]
	return [r.half + 2.0, r.half + 2.0, cut_slope, fill_slope]


# ======================================================================================
#  What grows where
# ======================================================================================

## Cherry groves: the whole south slope between the valley and the ridge, thinning to the west where the cedars begin.
func _grove_w(x: float, z: float) -> float:
	var on_slope: float = smoothstep(-10.0, -60.0, z) * smoothstep(RIDGE_Z - 40.0, RIDGE_Z + 30.0, z)
	var east: float = smoothstep(-300.0, -180.0, x)
	var w: float = on_slope * east * (0.55 + 0.6 * smoothstep(-0.25, 0.3, n_wood.get_noise_2d(x * 1.3, z * 1.3)))
	# The park: cherries round the lawn.
	w = maxf(w, _rect_weight(x, z, [-330.0, 84.0, 330.0, 280.0], 30.0) * 0.55)
	return clampf(w, 0.0, 1.0)


## Cedar forest: the hill's west (the descent), the ridge's north side, and the far slopes all round.
func _forest_w(x: float, z: float) -> float:
	var west: float = 1.0 - smoothstep(-300.0, -200.0, x)
	var hill: float = smoothstep(20.0, -40.0, z)
	var north: float = 1.0 - smoothstep(RIDGE_Z - 50.0, RIDGE_Z - 5.0, z)
	var far: float = smoothstep(560.0, 760.0, Vector2(x, z - 100.0).length())
	var w: float = maxf(maxf(west * hill, north), far * (0.6 + 0.4 * n_wood.get_noise_2d(x, z)))
	return clampf(w * (0.75 + 0.4 * n_wood.get_noise_2d(x * 2.0 + 90.0, z * 2.0)), 0.0, 1.0)


func _masks(_i: int, x: float, z: float, nrm_y: float, road_d: float) -> Color:
	var off: float = smoothstep(road_half + 3.0, road_half + 14.0, road_d)
	var rock: float = 1.0 - smoothstep(0.60, 0.76, nrm_y)
	var grove: float = _grove_w(x, z)
	var forest: float = _forest_w(x, z) * (1.0 - grove)
	# Trodden ground in the park along the road and round the pond's shore.
	var bare: float = _rect_weight(x, z, [-300.0, 84.0, 300.0, 100.0], 6.0) * 0.8
	var q := Vector2((x - POND_C.x) / POND_R.x, (z - POND_C.y) / POND_R.y)
	bare = maxf(bare, (1.0 - smoothstep(1.0, 1.12, q.length())))
	return Color(rock, bare * (1.0 - rock), grove * off, forest * off)


func _wet(x: float, z: float) -> float:
	var q := Vector2((x - POND_C.x) / POND_R.x, (z - POND_C.y) / POND_R.y)
	return 1.0 - smoothstep(0.95, 1.12, q.length())


func _tree_pick(x: float, z: float, roll: float, rng: RandomNumberGenerator) -> Array:
	var q := Vector2((x - POND_C.x) / POND_R.x, (z - POND_C.y) / POND_R.y)
	if q.length() < 1.12:
		return []
	# The park's lawn stays open for the picnics; its trees are placed by hand.
	if _in_rect(x, z, PARK_RECT, 6.0):
		return []
	var g: float = _grove_w(x, z)
	var f: float = _forest_w(x, z) * (1.0 - g)
	# Past the stage's own hills the forest is drawn thinner (stand-ins on the far ground).
	var far_d: float = Vector2(x, z - 100.0).length()
	f *= lerpf(1.0, 0.3, smoothstep(520.0, 700.0, far_d))
	if z < RIDGE_Z - 60.0:
		f *= 0.5
	if roll < g * 0.62:
		var high: float = smoothstep(-250.0, -460.0, z)
		var r: float = rng.randf()
		if r < 0.05:
			return ["shidare", rng.randf_range(0.9, 1.15)]
		if r < 0.25 + 0.5 * high:
			return ["yamazakura", rng.randf_range(0.85, 1.15), rng.randi_range(0, 1)]
		return ["sakura", rng.randf_range(0.85, 1.2), rng.randi_range(0, 1)]
	if roll < g * 0.62 + f * 0.8:
		if rng.randf() < 0.05:
			return ["yamazakura", rng.randf_range(0.9, 1.2)]
		return ["sugi", rng.randf_range(0.8, 1.2), rng.randi_range(0, 1)]
	# Open valley: a few maples, a bamboo grove by the brook's mouth.
	if z > -10.0 and Vector2(x + 430.0, z - 150.0).length() < 90.0 and roll < 0.5:
		return ["take", rng.randf_range(0.85, 1.15)]
	if roll < 0.012:
		return ["momiji", rng.randf_range(0.9, 1.2)]
	return []


func _environment() -> Dictionary:
	# A clear spring morning, the sun in the south-east.
	return {"sun_pitch": -42.0, "sun_yaw": 38.0, "cloud_coverage": 0.30, "cloud_seed": 21.7,
		"fog_end": 3600.0, "sun_energy": 1.4, "ambient": 0.62}


func _ground_params(m: ShaderMaterial) -> void:
	m.set_shader_parameter("petal_amount", 1.0)
	m.set_shader_parameter("moss_amount", 0.4)


# ======================================================================================
#  Gameplay
# ======================================================================================

func _place_gameplay(root: Node3D) -> void:
	var fin: float = _finish_s()
	_checkpoints([
		_closest_s(Vector2(215.0, -122.0)),    # the first leg
		_closest_s(Vector2(205.0, -247.0)),    # the second leg
		_closest_s(Vector2(160.0, -388.0)),    # the third leg
		_closest_s(Vector2(-300.0, -483.0)),   # the ridge
		s_bridge0 - 46.0,                      # before the ravine's bridge
		_closest_s(Vector2(-470.0, -45.0)),    # the valley's edge
	])
	_boosts([
		["Boost_Park", fin + 150.0, 0.0],
		["Boost_Leg2", _closest_s(Vector2(150.0, -228.0)), 2.5],
		["Boost_Ridge", _closest_s(Vector2(-150.0, -473.0)), 0.0],
		["Boost_Torii", 12.0, 0.0, "ToriiPath"],
	])
	# A timber kicker on the ridge straight, past the teahouse.
	_kicker(root, "RidgeJump", lap, _closest_s(Vector2(-330.0, -485.0)), 13.0, 1.9, 0.4)


# ======================================================================================
#  Dressing
# ======================================================================================

func _build_water(root: Node3D) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://still_water.gdshader")
	mat.set_shader_parameter("water_color", Color(0.03, 0.09, 0.08, 1.0))
	mat.set_shader_parameter("sky_tint", Color(0.55, 0.68, 0.82, 1.0))
	mat.set_shader_parameter("sky_reflect", 0.6)
	mat.set_shader_parameter("ripple_tile", 16.0)
	mat.set_shader_parameter("ripple_strength", 0.07)
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
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var he: Vector2 = POND_R * 1.15
	var n := 56
	for k in range(n):
		var a0: float = TAU * float(k) / float(n)
		var a1: float = TAU * float(k + 1) / float(n)
		var pa := Vector3(POND_C.x + cos(a0) * he.x, 0.0, POND_C.y + sin(a0) * he.y)
		var pb := Vector3(POND_C.x + cos(a1) * he.x, 0.0, POND_C.y + sin(a1) * he.y)
		var pc := Vector3(POND_C.x, 0.0, POND_C.y)
		# Clockwise from above (Godot's front face).
		for v in [pc, pa, pb]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(v.x, v.z))
			st.add_vertex(v)
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, smat)
	var water := MeshInstance3D.new()
	water.name = "PondWater"
	water.mesh = _save_res(mesh, "pond", stem + "far_")
	water.position = Vector3(0, POND_Y, 0)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.set_meta(&"water_surface_y", POND_Y)
	water.set_meta(&"water_bounds_min", POND_C - he)
	water.set_meta(&"water_bounds_max", POND_C + he)
	root.add_child(water)


func _build_dressing(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_base + 77
	var fin: float = _finish_s()
	_build_start_crowd(root, fin - 95.0, fin + 85.0, road_half + 3.0, fin - 8.0, fin + 8.0, seed_base + 11)
	_build_avenues(rng)
	_build_park(root, rng, fin)
	_build_roadside(root, rng)
	_build_torii_path(root)
	_build_ridge(root, rng)
	_build_shrine(root, rng)
	_build_ravine_bridge(root)
	_build_valley(root, rng)
	_build_petals(root)


## Cherries in rows along the road: an avenue both sides of the start straight, single trees up the climb.
func _build_avenues(rng: RandomNumberGenerator) -> void:
	var s0: float = _closest_s(Vector2(-380.0, 70.0))
	var s1: float = s0 + 760.0
	var fin: float = _finish_s()
	var s: float = s0
	var k := 0
	while s < s1:
		if absf(s - fin) > 12.0:
			for side in [-1.0, 1.0]:
				var sp: Dictionary = lap.spot(s + (5.0 if side > 0.0 else 0.0), side * (road_half + 6.2), 0.0)
				var p: Vector3 = sp["pos"]
				extra_trees.append(["sakura", p.x, p.z, rng.randf_range(0.95, 1.15), k % 2])
				_note_circle(Vector2(p.x, p.z), 2.0)
		s += 15.0
		k += 1
	# Up the climb and along the ridge: a tree every so often on alternate sides, close to the road.
	var c0: float = _closest_s(Vector2(400.0, -60.0))
	var c1: float = _closest_s(Vector2(-300.0, -498.0))
	s = c0
	k = 0
	while s < c1:
		var side: float = -1.0 if k % 2 == 0 else 1.0
		var sp2: Dictionary = lap.spot(s, side * (road_half + rng.randf_range(5.5, 8.0)), 0.0)
		var p2: Vector3 = sp2["pos"]
		if not _near_torii_path(p2, 12.0) and absf(lap.at(s)["k"]) < 0.02:
			extra_trees.append(["sakura" if rng.randf() < 0.7 else "yamazakura", p2.x, p2.z, rng.randf_range(0.9, 1.15), k % 2])
		s += rng.randf_range(15.0, 22.0)
		k += 1


func _near_torii_path(p: Vector3, d: float) -> bool:
	return p.x > TORII_A.x - d and p.x < TORII_A.x + d and p.z < TORII_A.y + d and p.z > TORII_B.y - d


## The hanami park along the start straight: lamps, banners, food stalls, picnics on the lawn, the pond's lanterns.
func _build_park(root: Node3D, rng: RandomNumberGenerator, fin: float) -> void:
	var s0: float = _closest_s(Vector2(-380.0, 70.0))
	# Bonbori lamps between the avenue's trees, both sides.
	var s: float = s0 + 7.5
	while s < s0 + 760.0:
		for side in [-1.0, 1.0]:
			var xf: Transform3D = _beside(lap, s, side * (road_half + 4.3))
			_put(_cell_key("park", xf.origin), prop_kit, xf, "bonbori", [], 420.0)
		s += 30.0
	# Banners in pairs either side of the line and at the park's ends.
	for ds in [-60.0, -30.0, 30.0, 60.0, 120.0, 180.0]:
		for side in [-1.0, 1.0]:
			var xf2: Transform3D = _beside(lap, fin + ds, side * (road_half + 5.0))
			var col: Color = [Color(0.86, 0.22, 0.30), Color(0.96, 0.62, 0.70), Color(0.20, 0.30, 0.55), Color(0.95, 0.93, 0.86)][rng.randi_range(0, 3)]
			_put(_cell_key("park", xf2.origin), prop_kit, xf2, "nobori", [col], 420.0)
	# Food stalls on the park side (the right of travel), facing the road, people at their counters.
	var k := 0
	s = fin + 100.0
	while s < fin + 220.0:
		var xf3: Transform3D = _beside(lap, s, road_half + 11.5)
		# The stall's frame runs x from 0: centre it on its spot.
		xf3.origin -= xf3.basis.x * 1.35 * PROP_SCALE
		if _put(_cell_key("park", xf3.origin), town_kit, xf3, "yatai", [k % 4, rng, LBL], 420.0):
			_note_frame(xf3, Vector2(-0.3, -2.2), Vector2(3.0, 0.6))
		for j in range(rng.randi_range(1, 3)):
			var at: Vector3 = xf3 * (Vector3(rng.randf_range(0.4, 2.3), 0.0, rng.randf_range(1.1, 2.0)) * PROP_SCALE)
			at.y = _ground_at(at.x, at.z)
			_person(at, -xf3.basis.z + xf3.basis.x * rng.randf_range(-0.3, 0.3), rng.randf_range(0.88, 1.06))
		s += 9.5
		k += 1
	# Picnics under the trees on the lawn: a tarp, people sitting round it, some standing.
	var placed := 0
	var tries := 0
	while placed < 16 and tries < 400:
		tries += 1
		var x: float = rng.randf_range(float(PARK_RECT[0]) + 20.0, float(PARK_RECT[2]) - 20.0)
		var z: float = rng.randf_range(float(PARK_RECT[1]) + 34.0, float(PARK_RECT[3]) - 4.0)
		if _occupied(x, z) or _in_pond(x, z, 1.15):
			continue
		var yaw: float = rng.randf() * TAU
		var xf4 := Transform3D(Basis(Vector3.UP, yaw), Vector3(x, _ground_at(x, z), z))
		_put(_cell_key("park", xf4.origin), prop_kit, xf4, "hanami_set", [placed % 3, rng], 300.0)
		_note_rect(Vector2(x, z), 7.0, 6.0, yaw, 1.0)
		for j in range(rng.randi_range(3, 5)):
			var ang: float = rng.randf() * TAU
			var rr: float = rng.randf_range(0.7, 1.5) * PROP_SCALE
			var at2: Vector3 = xf4.origin + Vector3(cos(ang) * rr, 0.06, sin(ang) * rr * 0.8)
			var seated: bool = rng.randf() < 0.75
			_person(at2, xf4.origin - at2 + Vector3(0.01, 0, 0), rng.randf_range(0.6, 1.05), seated, -1)
		# A cherry over every picnic.
		extra_trees.append(["sakura", x + rng.randf_range(-5.0, 5.0), z - rng.randf_range(5.0, 8.0), rng.randf_range(0.95, 1.2), placed % 2])
		placed += 1
	# Red benches under parasols and stone lanterns round the pond; a couple of weeping cherries over the water.
	for i in range(14):
		var a: float = TAU * (float(i) + 0.3) / 14.0
		var p := Vector2(POND_C.x + cos(a) * (POND_R.x + 7.0), POND_C.y + sin(a) * (POND_R.y + 7.0))
		var at3 := Vector3(p.x, _ground_at(p.x, p.y), p.y)
		var face := Vector3(POND_C.x - p.x, 0.0, POND_C.y - p.y)
		var xf5: Transform3D = _facing(face, at3)
		if i % 3 == 0:
			_put(_cell_key("pond", at3), prop_kit, xf5, "red_bench", [true], 300.0)
			_note_rect(p, 5.0, 5.0, 0.0, 0.5)
		elif i % 3 == 1:
			_put(_cell_key("pond", at3), prop_kit, xf5, "stone_lantern", [i % 2], 300.0)
		else:
			extra_trees.append(["shidare", p.x, p.y, rng.randf_range(0.95, 1.15), 0])
	# Drinks machines and a bench by the road, a farm truck behind the stalls.
	var vx: Transform3D = _beside(lap, fin + 82.0, road_half + 6.0)
	_put(_cell_key("park", vx.origin), prop_kit, vx, "vending_machine", [0], 300.0)
	var vx2: Transform3D = _beside(lap, fin + 84.0, road_half + 6.0)
	_put(_cell_key("park", vx2.origin), prop_kit, vx2, "vending_machine", [1], 300.0)
	var tx: Transform3D = _beside(lap, fin + 232.0, road_half + 9.0)
	_put(_cell_key("park", tx.origin), prop_kit, Transform3D(tx.basis.rotated(Vector3.UP, 0.5), tx.origin), "kei_truck", [], 300.0)
	_note_rect(Vector2(tx.origin.x, tx.origin.z), 7.0, 4.0, 0.0)
	# A grand vermilion torii over the road where it turns up into the groves.
	var s_t: float = _closest_s(Vector2(330.0, -78.0))
	var gx: Transform3D = _across(lap, s_t)
	gx.origin.y -= 0.05
	_put("grand_torii", prop_kit, gx, "torii", [0, 11.2, 7.6], 1400.0)
	for side in [-1.0, 1.0]:
		var foot: Vector3 = gx.origin + gx.basis.x * side * 5.6 * PROP_SCALE
		_note_circle(Vector2(foot.x, foot.z), 2.5)
		var lx: Transform3D = _beside(lap, s_t - 9.0, side * (road_half + 3.4))
		_put("grand_torii", prop_kit, lx, "stone_lantern", [0, 2.6], 1400.0)


func _in_pond(x: float, z: float, k: float) -> bool:
	return Vector2((x - POND_C.x) / POND_R.x, (z - POND_C.y) / POND_R.y).length() < k


## Guardrails on the drops, mirrors and signs at the hairpins, wayside statues, poles along the valley road.
func _build_roadside(root: Node3D, rng: RandomNumberGenerator) -> void:
	_auto_guardrails(root, lap, 0.0, lap.length, 2.6)
	var hairpins: Array = [Vector2(30.0, -185.0), Vector2(380.0, -310.0), Vector2(-560.0, -500.0)]
	for hi in range(hairpins.size()):
		var hp: Vector2 = hairpins[hi]
		var s_h: float = _closest_s(hp)
		var k: float = lap.at(s_h)["k"]
		var out_side: float = -signf(k)
		# A mirror on the outside of the bend at its apex, a warning sign 70m before, a statue row inside it.
		var mx: Transform3D = _beside(lap, s_h, out_side * (road_half + 2.6))
		_put(_cell_key("signs", mx.origin), prop_kit, mx, "curve_mirror", [true], 300.0)
		var sx: Transform3D = _beside(lap, s_h - 78.0, road_half + 2.4)
		_put(_cell_key("signs", sx.origin), prop_kit, Transform3D(Basis(Vector3.UP, PI * 0.5) * sx.basis, sx.origin), "road_sign", ["curve_l" if k < 0.0 else "curve_r", LBL], 300.0)
		if hi < 2:
			var jx: Transform3D = _beside(lap, s_h, -out_side * (road_half + 4.5))
			_put(_cell_key("signs", jx.origin), prop_kit, jx, "jizo_row", [5 + hi, rng], 300.0)
			_note_circle(Vector2(jx.origin.x, jx.origin.z), 4.0)
	# Wayside things up the climb: stone lanterns, a little shrine, way-stones.
	var spots: Array = [[_closest_s(Vector2(300.0, -88.0)), -1.0, "hokora", []], [_closest_s(Vector2(120.0, -150.0)), 1.0, "stone_lantern", [0]],
			[_closest_s(Vector2(110.0, -215.0)), -1.0, "stone_marker", [1.5, "SHIMO SENBON", LBL]], [_closest_s(Vector2(300.0, -285.0)), 1.0, "stone_lantern", [0]],
			[_closest_s(Vector2(250.0, -355.0)), -1.0, "stone_marker", [1.5, "NAKA SENBON", LBL]], [_closest_s(Vector2(60.0, -425.0)), 1.0, "hokora", []],
			[_closest_s(Vector2(-60.0, -467.0)), -1.0, "stone_marker", [1.7, "KAMI SENBON", LBL]]]
	for sp in spots:
		var wx: Transform3D = _beside(lap, float(sp[0]), float(sp[1]) * (road_half + 3.6))
		_put(_cell_key("wayside", wx.origin), prop_kit, wx, String(sp[2]), sp[3], 300.0)
		_note_circle(Vector2(wx.origin.x, wx.origin.z), 2.5)
	# Utility poles along the valley road (the start straight's hill side) with their wires.
	var s0: float = _closest_s(Vector2(-380.0, 70.0))
	var prev := Vector3.INF
	var s: float = s0 + 20.0
	var k2 := 0
	while s < s0 + 780.0:
		var px: Transform3D = _beside(lap, s, -(road_half + 9.5))
		_put(_cell_key("poles", px.origin), prop_kit, px, "utility_pole", [9.5, k2 % 3], 500.0)
		_note_circle(Vector2(px.origin.x, px.origin.z), 1.5)
		var top: Vector3 = px.origin + Vector3(0, 9.0 * PROP_SCALE, 0)
		if prev != Vector3.INF:
			_put_world("poles", top, prop_kit, "pole_wires", [_life(prev), _life(top), 0.7, 3], 500.0)
		prev = top
		s += 44.0
		k2 += 1


## The torii path: a tunnel of vermilion torii over the flagged footpath that cuts the upper hairpin.
func _build_torii_path(root: Node3D) -> void:
	var r: Route = _route_by_name["ToriiPath"]
	var s: float = road_half + 3.0
	var n := 0
	while s < r.length - road_half - 2.0:
		var xf: Transform3D = _across(r, s)
		xf.origin.y -= 0.05
		_put("torii_tunnel", prop_kit, xf, "torii", [0, 6.3, 4.5], 900.0)
		s += 5.4
		n += 1
	for e in [[road_half + 1.2, 1.0], [r.length - road_half - 1.2, -1.0]]:
		for side in [-1.0, 1.0]:
			var lx: Transform3D = _beside(r, float(e[0]), side * (r.half + 1.6))
			_put("torii_tunnel", prop_kit, lx, "stone_lantern", [0], 900.0)
	_note_rect(Vector2(TORII_A.x, (TORII_A.y + TORII_B.y) * 0.5), 16.0, absf(TORII_A.y - TORII_B.y), 0.0, 2.0)
	print("  the torii path: %d torii" % n)


## The ridge: the teahouse at the view, benches under parasols, banners, people looking out over the valley.
func _build_ridge(root: Node3D, rng: RandomNumberGenerator) -> void:
	var s_c: float = _closest_s(Vector2(-215.0, -488.0))
	# Heading west the north is on the right: the teahouse stands there and looks south across the road.
	var cx: Transform3D = _beside(lap, s_c, road_half + 9.0)
	cx.origin -= cx.basis.x * 4.5 * PROP_SCALE
	if _put("ridge_chaya", town_kit, cx, "chaya", [LBL], 900.0):
		_note_frame(cx, Vector2(-1.0, -7.0), Vector2(10.0, 3.5), 2.0)
	for i in range(5):
		var at: Vector3 = cx * (Vector3(rng.randf_range(1.0, 8.0), 0.0, rng.randf_range(1.2, 3.2)) * PROP_SCALE)
		at.y = _ground_at(at.x, at.z)
		_person(at, cx.basis.z + cx.basis.x * rng.randf_range(-0.6, 0.6), rng.randf_range(0.9, 1.05))
	# The viewpoint on the valley side: benches, banners, a drinks machine, people at the edge.
	for i in range(4):
		var bx: Transform3D = _beside(lap, s_c - 24.0 + float(i) * 16.0, -(road_half + 6.5))
		# The benches face the view, their backs to the road.
		bx = Transform3D(Basis(Vector3.UP, PI) * bx.basis, bx.origin)
		if i % 2 == 0:
			_put("ridge_view", prop_kit, bx, "red_bench", [true], 600.0)
		else:
			_put("ridge_view", prop_kit, bx, "nobori", [Color(0.86, 0.22, 0.30)], 600.0)
		_note_circle(Vector2(bx.origin.x, bx.origin.z), 3.0)
		for j in range(rng.randi_range(1, 3)):
			var at2: Vector3 = bx.origin + bx.basis.z * rng.randf_range(1.5, 3.5) + bx.basis.x * rng.randf_range(-3.0, 3.0)
			at2.y = _ground_at(at2.x, at2.z)
			_person(at2, bx.basis.z, rng.randf_range(0.85, 1.05))
	var vx: Transform3D = _beside(lap, s_c + 30.0, road_half + 5.0)
	_put("ridge_view", prop_kit, vx, "vending_machine", [2], 600.0)


## The shrine in the cedars at the ridge's end, outside the turn: a cedar torii, guardian dogs, lanterns, the hall,
## and a giant sacred cedar with its rope.
func _build_shrine(root: Node3D, rng: RandomNumberGenerator) -> void:
	var s_h: float = _closest_s(Vector2(-560.0, -500.0))
	var k: float = lap.at(s_h)["k"]
	var out_side: float = -signf(k)
	var base: Transform3D = _beside(lap, s_h, out_side * (road_half + 7.0))
	# The approach runs away from the road: torii at 0, dogs at 5, lanterns, the hall at 20 (life metres).
	var away: Vector3 = -base.basis.z
	var place := func(d: float, lat: float) -> Transform3D:
		var p: Vector3 = base.origin + away * d * PROP_SCALE + base.basis.x * lat * PROP_SCALE
		p.y = _ground_at(p.x, p.z)
		return Transform3D(base.basis, p)
	_put("shrine", prop_kit, place.call(0.5, 0.0), "torii", [2, 4.6, 4.2], 900.0)
	for side in [-1.0, 1.0]:
		_put("shrine", prop_kit, place.call(4.5, side * 2.6), "komainu", [side < 0.0], 900.0)
		_put("shrine", prop_kit, place.call(8.0, side * 2.8), "stone_lantern", [0], 900.0)
		_put("shrine", prop_kit, place.call(13.0, side * 2.8), "stone_lantern", [0], 900.0)
	var hx: Transform3D = place.call(19.0, 0.0)
	_put("shrine", town_kit, hx, "shrine_hall", [LBL], 900.0)
	_put("shrine", prop_kit, place.call(12.0, -7.5), "ema_rack", [], 900.0)
	_put("shrine", prop_kit, place.call(7.0, 7.0), "chozuya", [], 900.0)
	var c: Vector3 = base.origin + away * 12.0 * PROP_SCALE
	_note_rect(Vector2(c.x, c.z), 30.0, 52.0, atan2(-base.basis.x.z, base.basis.x.x), 2.0)
	# The sacred cedar beside the hall.
	var tp: Vector3 = place.call(17.0, 9.5).origin
	extra_trees.append(["sugi", tp.x, tp.z, 1.7, 1])
	_put("shrine", prop_kit, Transform3D(Basis(), Vector3(tp.x, tp.y, tp.z)), "rope_ring", [0.62, 1.5], 900.0)
	for i in range(4):
		var at: Vector3 = place.call(rng.randf_range(9.0, 15.0), rng.randf_range(-2.0, 2.0)).origin
		_person(at, away, rng.randf_range(0.9, 1.05))


## The vermilion arch bridge over the brook's ravine (the kit builds all but the deck), its railings solid.
func _build_ravine_bridge(root: Node3D) -> void:
	var o: Vector3 = lap.pt(s_bridge0)
	var fwd: Vector3 = lap.fw(s_bridge0)
	var xf := _facing(-fwd, o)
	var span: float = s_bridge1 - s_bridge0
	var deck := func(t: float) -> float: return lap.y(s_bridge0 + t) - o.y
	var ground := func(x: float, t: float) -> float:
		var p: Vector3 = lap.pt(s_bridge0 + t) + lap.rt(s_bridge0 + t) * -x
		return _ground_at(p.x, p.z) - o.y
	_add_prop_game("ravine_span", river_kit, xf, func(pk: PropKit, kit: Dictionary, _labels: Array) -> void:
		_kit_call(river_kit, "road_bridge", [pk, kit, span, road_half, deck, ground, 1]), 1500.0)
	var body: StaticBody3D = _body(root, "RavineRailsBody")
	for side in [-1.0, 1.0]:
		_edge_boxes(body, lap, s_bridge0 - 3.0, s_bridge1 + 3.0, side * (road_half + 0.3), 1.7, 0.4)
	_note_rect(Vector2(lap.pt((s_bridge0 + s_bridge1) * 0.5).x, lap.pt((s_bridge0 + s_bridge1) * 0.5).z), 24.0, span + 16.0, atan2(fwd.x, fwd.z), 2.0)


## The valley: farmhouses beyond the pond and at the hill's foot, timber at the forest's edge.
func _build_valley(root: Node3D, rng: RandomNumberGenerator) -> void:
	var farms: Array = [Vector3(-210.0, 250.0, 0.4), Vector3(-90.0, 285.0, -0.3), Vector3(250.0, 262.0, 0.2), Vector3(470.0, 150.0, -1.2),
			Vector3(500.0, 30.0, -1.5), Vector3(-560.0, 120.0, 1.3)]
	for f in farms:
		var at := Vector3(f.x, 0.0, f.y)
		var gr: Vector2 = _ground_range(Vector2(f.x, f.y), 22.0, 16.0, f.z)
		at.y = gr.y
		var xf := Transform3D(Basis(Vector3.UP, f.z), at)
		if _put(_cell_key("farm", at), town_kit, xf, "kominka", [11.0, 7.5, rng], 900.0):
			_note_rect(Vector2(f.x, f.y), 24.0, 18.0, f.z, 3.0)
	# Cedar logs stacked at the forest road's edge on the descent.
	for q in [Vector2(-455.0, -430.0), Vector2(-492.0, -110.0)]:
		var s: float = _closest_s(q)
		var lx: Transform3D = _beside(lap, s, road_half + 6.5)
		lx = Transform3D(Basis(Vector3.UP, PI * 0.5) * lx.basis, lx.origin)
		if _put(_cell_key("timber", lx.origin), river_kit, lx, "log_stack", [6, 6.0, rng], 500.0):
			_note_circle(Vector2(lx.origin.x, lx.origin.z), 7.0)


## Petals in the air, and gusts that blow them across the road on the climb's open stretches.
func _build_petals(root: Node3D) -> void:
	var pg := Node3D.new()
	pg.name = "PetalGusts"
	pg.set_script(load("res://PetalGusts.gd"))
	var spots: Array = []
	var k := 0
	for q in [Vector2(260.0, -92.0), Vector2(120.0, -230.0), Vector2(250.0, -340.0), Vector2(20.0, -436.0), Vector2(-120.0, -476.0)]:
		var s: float = _closest_s(q)
		var p: Vector3 = lap.pt(s)
		# The wind comes up the valley and over the slope: across the road from its downhill side.
		var right: Vector3 = lap.rt(s)
		var dir: Vector3 = right if right.z < 0.0 else -right
		spots.append([p, dir, 26.0, 17.0 + float(k) * 2.5, float(k) * 5.3])
		k += 1
	pg.set("spots", spots)
	root.add_child(pg)
