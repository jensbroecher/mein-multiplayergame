# regenerate_senbon_sakura.gd
#
# Builds levels/SenbonSakuraLevel.tscn - Senbon Sakura Pass, the first stage of the Miyoshino GP: a mountain road
# (a touge) up through a thousand cherry trees in full bloom on a spring morning. The lap starts in the hanami park by
# the lake on the valley floor heading east, crosses a vermilion-railed timber bridge onto the temple island, runs
# round the temple (its hall faces the park across the water) and back over a second bridge, climbs the south-facing
# slope in three long legs and two hairpins through
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
## The lake south of the start straight: a smooth union of ellipses [centre, half extents] with a wandering shore
## (`_lake_d`), the island in it (`_island_d`), the water's level and depth.
const LAKE_BLOBS := [[Vector2(95.0, 215.0), Vector2(175.0, 105.0)], [Vector2(-105.0, 250.0), Vector2(115.0, 72.0)],
	[Vector2(285.0, 245.0), Vector2(100.0, 72.0)], [Vector2(-70.0, 168.0), Vector2(62.0, 34.0)],
	[Vector2(-30.0, 318.0), Vector2(70.0, 40.0)]]
## Land reaching into the lake: a wooded point from the south shore and a smaller one from the east.
const LAKE_POINTS := [[Vector2(235.0, 318.0), Vector2(34.0, 62.0)], [Vector2(372.0, 205.0), Vector2(44.0, 26.0)]]
const ISLAND_C := Vector2(95.0, 205.0)
const ISLAND_R := Vector2(92.0, 58.0)
const POND_Y := -0.7
const POND_DEEP := 2.6
## The island loop: the legs at these x, the road behind the temple at ISLAND_ROAD_Z; the hall's front (facing north).
const LEG_W := 40.0
const LEG_E := 150.0
const ISLAND_ROAD_Z := 228.0
const HALL_FRONT_Z := 184.0
## The park: the lawn between the start straight and the lake, west of the island's bridges.
const PARK_RECT := [-340.0, 84.0, 20.0, 170.0]
## Level ground round the lake.
const VALLEY_RECT := [-380.0, 80.0, 440.0, 380.0]

## The torii path: from the lap before the upper hairpin up the slope to the lap after it.
const TORII_A := Vector2(280.0, -283.3)
const TORII_B := Vector2(280.0, -338.6)

var s_bridge0 := 0.0
var s_bridge1 := 0.0
## The two island bridges' spans along the lap: [[s0, s1], [s0, s1]].
var island_spans: Array = []
## Where the farmhouses' koinobori poles go.
var _farm_spots: Array = []


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
		[Vector2(LEG_W, 70.0), 34.0],      # right, south over the first bridge onto the temple island
		[Vector2(LEG_W, ISLAND_ROAD_Z), 36.0],    # left behind the temple
		[Vector2(LEG_E, ISLAND_ROAD_Z), 36.0],    # left, north over the second bridge
		[Vector2(LEG_E, 70.0), 34.0],      # right, east on along the valley road
	]
	finish_at = Vector2(-300.0, 70.0)
	fine_x = Vector2(-720.0, 560.0)
	fine_z = Vector2(-680.0, 400.0)
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
	# The valley's level ground round the lake, the lake and the island.
	hh = lerpf(hh, 0.25, _rect_weight(x, z, VALLEY_RECT, 60.0))
	var wd: float = _water_d(x, z)
	if wd < 0.0:
		# The bed: shelving down from the shore, deepest in the middle of each reach.
		return POND_Y - 0.45 - POND_DEEP * smoothstep(0.0, 26.0, -wd) + 0.25 * n_fine.get_noise_2d(x, z)
	var land: float = hh
	var isd: float = _island_d(x, z)
	if isd < 0.0:
		# The island: low, rising a little toward its middle.
		land = 0.3 + 0.45 * smoothstep(0.0, 40.0, -isd)
	# The bank down to the water's edge.
	return lerpf(POND_Y + 0.25, land, smoothstep(0.0, 10.0, wd))


func _ellipse_d(p: Vector2, c: Vector2, r: Vector2) -> float:
	var q: Vector2 = (p - c) / r
	return (q.length() - 1.0) * minf(r.x, r.y)


func _smin(a: float, b: float, k: float) -> float:
	var h: float = clampf(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
	return lerpf(b, a, h) - k * h * (1.0 - h)


## Signed distance outside the lake's outline (negative inside it, the island counted as lake).
func _lake_d(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var d: float = 1e9
	for b in LAKE_BLOBS:
		d = _smin(d, _ellipse_d(p, b[0], b[1]), 45.0) if d < 1e8 else _ellipse_d(p, b[0], b[1])
	for pt in LAKE_POINTS:
		d = maxf(d, -_ellipse_d(p, pt[0], pt[1]))
	return d + 7.0 * n_hill.get_noise_2d(x * 0.9 + 300.0, z * 0.9)


## Signed distance outside the island's outline.
func _island_d(x: float, z: float) -> float:
	return _ellipse_d(Vector2(x, z), ISLAND_C, ISLAND_R) + 3.5 * n_hill.get_noise_2d(x * 2.2, z * 2.2 + 500.0)


## Signed distance from the water's edge: negative in the water, positive on land (the island is land).
func _water_d(x: float, z: float) -> float:
	return maxf(_lake_d(x, z), -_island_d(x, z))


func _in_lake(x: float, z: float, margin: float) -> bool:
	return _water_d(x, z) < margin


func _map_water(x: float, z: float) -> float:
	return POND_Y if _water_d(x, z) < 0.0 else NAN


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
	# The island's bridges: where each leg crosses the water and its banks (a hump: taiko-bashi).
	island_spans = []
	for leg in [[Vector2(LEG_W, 100.0), Vector2(LEG_W, 190.0)], [Vector2(LEG_E, 190.0), Vector2(LEG_E, 100.0)]]:
		var s0: float = _closest_s_raw(leg[0])
		var s1: float = _closest_s_raw(leg[1])
		var a2 := -1.0
		var b2 := -1.0
		var k: float = s0
		while k < s1:
			var q: Vector2 = _raw_at(k)
			if _water_d(q.x, q.y) < 4.0:
				if a2 < 0.0:
					a2 = k
				b2 = k
			k += 1.0
		island_spans.append([a2 - 5.0, b2 + 5.0])
		bridges.append(["lap", a2 - 5.0, b2 + 5.0, 1.5])
	print("  the island's bridges: %s" % str(island_spans))


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
	var r: Route = _add_route("ToriiPath", [[TORII_A, 0.0], [TORII_B, 0.0]], 4.2, true, 0.3)
	_report_profile(r)
	shortcuts = [["ToriiPath", 0.5]]


func _sections(r: Route) -> Array:
	if r.name == "ToriiPath":
		return [[road_half + 0.6, r.length - road_half - 0.6, K_FOOTPATH, r.half]]
	var spans: Array = [[s_bridge0, s_bridge1]] + island_spans
	spans.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var out: Array = []
	var s := 0.0
	for sp in spans:
		# The island's own road (between its two bridges) is the temple's stone paving.
		var on_island: bool = not island_spans.is_empty() and absf(s - float(island_spans[0][1])) < 0.01
		out.append([s, float(sp[0]), K_STONE if on_island else K_ASPHALT, r.half])
		out.append([float(sp[0]), float(sp[1]), K_PLANKS, r.half])
		s = float(sp[1])
	out.append([s, r.length, K_ASPHALT, r.half])
	return out


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
	# The park and the lake's shores: cherries round the lawn.
	w = maxf(w, _rect_weight(x, z, [-340.0, 84.0, 420.0, 360.0], 30.0) * 0.55)
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
	# Trodden ground in the park along the road, the lake's shingle shore and the temple's gravel forecourt.
	var bare: float = _rect_weight(x, z, [-340.0, 84.0, 30.0, 96.0], 6.0) * 0.8
	var wd: float = _water_d(x, z)
	bare = maxf(bare, 1.0 - smoothstep(1.5, 5.0, wd + 1.2 * n_fine.get_noise_2d(x * 2.0, z * 2.0)))
	bare = maxf(bare, _rect_weight(x, z, [ISLAND_C.x - 15.0, 140.0, ISLAND_C.x + 15.0, HALL_FRONT_Z - 2.0], 3.0) * 0.9)
	var near_water: float = 1.0 - smoothstep(6.0, 14.0, wd)
	return Color(rock, bare * (1.0 - rock), grove * off * (1.0 - near_water), forest * off * (1.0 - near_water))


func _wet(x: float, z: float) -> float:
	return 1.0 - smoothstep(-1.0, 3.5, _water_d(x, z))


func _tree_pick(x: float, z: float, roll: float, rng: RandomNumberGenerator) -> Array:
	# The water, its banks and the island stay clear; the island's trees and the park's are placed by hand.
	if _water_d(x, z) < 7.0 or _island_d(x, z) < 6.0:
		return []
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
	# Two gates on the island, one after the other: driving round the lake instead of over it misses both, and two
	# missed in a row disqualify.
	_checkpoints([
		_closest_s(Vector2(LEG_W, 190.0)),     # the island, coming off the first bridge
		_closest_s(Vector2(LEG_E, 190.0)),     # the island, before the second bridge
		_closest_s(Vector2(215.0, -122.0)),    # the first leg
		_closest_s(Vector2(205.0, -247.0)),    # the second leg
		_closest_s(Vector2(160.0, -388.0)),    # the third leg
		_closest_s(Vector2(-300.0, -483.0)),   # the ridge
		s_bridge0 - 46.0,                      # before the ravine's bridge
		_closest_s(Vector2(-470.0, -45.0)),    # the valley's edge
	])
	_boosts([
		["Boost_Park", fin + 30.0, 0.0],
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
	# A grid over the lake's box: every cell with a corner within 6m of the water (under the banks, hidden by the
	# ground there), none over the island's middle or the land round the lake.
	var lo := Vector2(-280.0, 95.0)
	var hi := Vector2(430.0, 360.0)
	var cell := 5.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wlo := Vector2(1e9, 1e9)
	var whi := Vector2(-1e9, -1e9)
	var nx: int = int((hi.x - lo.x) / cell)
	var nzc: int = int((hi.y - lo.y) / cell)
	var cells := 0
	for j in range(nzc):
		for i in range(nx):
			var x0: float = lo.x + float(i) * cell
			var z0: float = lo.y + float(j) * cell
			var x1: float = x0 + cell
			var z1: float = z0 + cell
			if minf(minf(_water_d(x0, z0), _water_d(x1, z0)), minf(_water_d(x0, z1), _water_d(x1, z1))) > 6.0:
				continue
			cells += 1
			wlo = Vector2(minf(wlo.x, x0), minf(wlo.y, z0))
			whi = Vector2(maxf(whi.x, x1), maxf(whi.y, z1))
			var a := Vector3(x0, 0.0, z0)
			var b := Vector3(x1, 0.0, z0)
			var c := Vector3(x1, 0.0, z1)
			var d := Vector3(x0, 0.0, z1)
			# Clockwise from above (Godot's front face): (a, b, c) with x east and z south.
			for v in [a, b, c, a, c, d]:
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(v.x, v.z))
				st.add_vertex(v)
	st.index()
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, smat)
	var water := MeshInstance3D.new()
	water.name = "LakeWater"
	water.mesh = _save_res(mesh, "lake", stem + "far_")
	water.position = Vector3(0, POND_Y, 0)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.set_meta(&"water_surface_y", POND_Y)
	water.set_meta(&"water_bounds_min", wlo)
	water.set_meta(&"water_bounds_max", whi)
	root.add_child(water)
	print("  the lake: %d water cells, %s to %s" % [cells, str(wlo), str(whi)])


func _build_dressing(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_base + 77
	var fin: float = _finish_s()
	_build_start_crowd(root, fin - 55.0, fin + 95.0, road_half + 3.0, fin - 8.0, fin + 8.0, seed_base + 11)
	_build_avenues(rng)
	_build_park(root, rng, fin)
	_build_roadside(root, rng)
	_build_torii_path(root)
	_build_ridge(root, rng)
	_build_shrine(root, rng)
	_build_span(root, "ravine_span", "RavineRailsBody", s_bridge0, s_bridge1, 1)
	for i in range(island_spans.size()):
		_build_span(root, "island_span_%d" % i, "IslandBridgeRailsBody%d" % i, float(island_spans[i][0]), float(island_spans[i][1]), 0, 2.6)
	_build_approach_rails(root)
	_build_island(root, rng)
	_build_shore(root, rng)
	# The bell tower on the island's east end is struck every two and a half minutes, heard across the lake.
	var bell := Vector3(174.0, 0.0, 205.0)
	_periodic(root, "TempleBell", "res://sounds/miyoshino/temple_bell.wav", Vector3(bell.x, _ground_at(bell.x, bell.z) + 8.0, bell.z),
			0.0, 80.0, 1600.0, 150.0, 37.0)
	_build_valley(root, rng)
	_build_koinobori(rng)
	_build_petals(root)


## Cherries in rows along the road: an avenue both sides of the start straight, single trees up the climb.
func _build_avenues(rng: RandomNumberGenerator) -> void:
	var fin: float = _finish_s()
	var s: float = 0.0
	var k := 0
	while s < lap.length:
		if absf(s - fin) > 12.0 and _on_valley_road(s, 8.0):
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


## True where the lap runs along the valley road (the start straight and its stretch east of the island), `margin`
## metres from where it turns away.
func _on_valley_road(s: float, margin := 0.0) -> bool:
	for d in [-margin, 0.0, margin]:
		var a: Dictionary = lap.at(s + d)
		if absf((a["p"] as Vector2).y - 70.0) > 0.6 or cos(float(a["th"])) < 0.999:
			return false
	return true


func _near_torii_path(p: Vector3, d: float) -> bool:
	return p.x > TORII_A.x - d and p.x < TORII_A.x + d and p.z < TORII_A.y + d and p.z > TORII_B.y - d


## The hanami park along the start straight: lamps, banners, food stalls, picnics on the lawn, the pond's lanterns.
func _build_park(root: Node3D, rng: RandomNumberGenerator, fin: float) -> void:
	# Bonbori lamps between the avenue's trees, both sides.
	var s: float = 7.5
	while s < lap.length:
		if _on_valley_road(s, 8.0):
			for side in [-1.0, 1.0]:
				var xf: Transform3D = _beside(lap, s, side * (road_half + 4.3))
				_put(_cell_key("park", xf.origin), prop_kit, xf, "bonbori", [], 420.0)
		s += 30.0
	# Banners in pairs either side of the line and at the park's ends.
	for ds in [-90.0, -60.0, -30.0, 30.0, 60.0, 120.0]:
		for side in [-1.0, 1.0]:
			var xf2: Transform3D = _beside(lap, fin + ds, side * (road_half + 5.0))
			var col: Color = [Color(0.86, 0.22, 0.30), Color(0.96, 0.62, 0.70), Color(0.20, 0.30, 0.55), Color(0.95, 0.93, 0.86)][rng.randi_range(0, 3)]
			_put(_cell_key("park", xf2.origin), prop_kit, xf2, "nobori", [col], 420.0)
	# Food stalls on the park side (the right of travel), facing the road, people at their counters.
	var k := 0
	s = fin + 200.0
	while s < fin + 280.0:
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
		if _occupied(x, z) or _in_lake(x, z, 10.0):
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
	# Drinks machines and a bench by the road, a farm truck behind the stalls.
	var vx: Transform3D = _beside(lap, fin + 82.0, road_half + 6.0)
	_put(_cell_key("park", vx.origin), prop_kit, vx, "vending_machine", [0], 300.0)
	var vx2: Transform3D = _beside(lap, fin + 84.0, road_half + 6.0)
	_put(_cell_key("park", vx2.origin), prop_kit, vx2, "vending_machine", [1], 300.0)
	var tx: Transform3D = _beside(lap, fin + 135.0, road_half + 24.0)
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
	var prev := Vector3.INF
	var s: float = 0.0
	var k2 := 0
	while s < lap.length:
		if not _on_valley_road(s, 14.0):
			prev = Vector3.INF
			s += 11.0
			continue
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


## A bridge on the lap from s0 to s1 (the river kit builds all but the deck: style 0 a timber trestle with vermilion
## railings, 1 the steel arch over the ravine), its railings solid.
func _build_span(root: Node3D, key: String, body_name: String, s0: float, s1: float, style: int, rail_h := 1.7) -> void:
	var o: Vector3 = lap.pt(s0)
	var fwd: Vector3 = lap.fw(s0)
	var xf := _facing(-fwd, o)
	var span: float = s1 - s0
	var deck := func(t: float) -> float: return lap.y(s0 + t) - o.y
	var ground := func(x: float, t: float) -> float:
		var p: Vector3 = lap.pt(s0 + t) + lap.rt(s0 + t) * -x
		return _ground_at(p.x, p.z) - o.y
	_add_prop_game(key, river_kit, xf, func(pk: PropKit, kit: Dictionary, _labels: Array) -> void:
		_kit_call(river_kit, "road_bridge", [pk, kit, span, road_half, deck, ground, style]), 1500.0)
	var body: StaticBody3D = _body(root, body_name)
	for side in [-1.0, 1.0]:
		_edge_boxes(body, lap, s0 - 3.0, s1 + 3.0, side * (road_half + 0.3), rail_h, 0.4)
	var mid: Vector3 = lap.pt((s0 + s1) * 0.5)
	_note_rect(Vector2(mid.x, mid.z), 24.0, span + 16.0, atan2(fwd.x, fwd.z), 2.0)
	print("  %s: %.0fm, its deck %.1fm over the ground under its middle" % [key, span, mid.y - _ground_at(mid.x, mid.z)])


## Vermilion railings round the outside of the turns onto and off the island's bridges, carrying on from the bridges'
## own: a bot that ran wide out of the right-hander had missed the railing's start and slid down the bank into the lake.
func _build_approach_rails(root: Node3D) -> void:
	var body: StaticBody3D = _body(root, "BridgeApproachRailsBody")
	# Round the whole outside (the left) of the right-hander onto the first bridge, from before the turn begins: a bot
	# that ran wide where the railing started 30m before the bridge got behind it, drove down the verge and dropped
	# into the lake at the bank. The same round the right-hander off the second bridge, and a short run on the inside
	# of each causeway where its bank falls to the water.
	var b0: float = float(island_spans[0][0])
	var b1: float = float(island_spans[1][1])
	var turn_in: float = _closest_s(Vector2(LEG_W - 34.0, 70.0))
	var turn_out: float = _closest_s(Vector2(LEG_E + 34.0, 70.0))
	var runs: Array = [[turn_in - 10.0, b0 - 2.5, -1.0], [b0 - 18.0, b0 - 2.5, 1.0], [b1 + 2.5, turn_out + 10.0, -1.0], [b1 + 2.5, b1 + 18.0, 1.0]]
	for run in runs:
		var lat: float = float(run[2]) * (road_half + 0.6)
		var s: float = run[0]
		while s < float(run[1]) - 0.5:
			var sb: float = minf(s + 6.0, float(run[1]))
			var a: Vector3 = lap.pt(s) + lap.rt(s) * lat
			var b: Vector3 = lap.pt(sb) + lap.rt(sb) * lat
			a.y -= GROUND_UNDER
			b.y -= GROUND_UNDER
			_put_world("approach_rail", a, prop_kit, "koran", [_life(a), _life(b), 1.0], 900.0)
			s = sb
		_edge_boxes(body, lap, float(run[0]), float(run[1]), lat, 2.6, 0.4)
	print("  approach railings: %s" % str(runs))


## The temple island: the hall facing the park across the water, two halls as its wings, a pagoda at the island's west
## end and a bell tower at its east end, the gravel forecourt with stone lanterns down to the water, weeping cherries.
func _build_island(root: Node3D, rng: RandomNumberGenerator) -> void:
	var cx: float = ISLAND_C.x
	var north := Vector3(0, 0, -1)
	var at_ground := func(x: float, z: float, w: float, d: float) -> Vector3:
		var gr: Vector2 = _ground_range(Vector2(x, z), w, d, 0.0)
		return Vector3(x, gr.y, z)
	# The hall: its front (frame +z) to the north, its middle on the island's axis.
	var hall: Vector3 = at_ground.call(cx, HALL_FRONT_Z + 14.0, 40.0, 32.0)
	hall.z = HALL_FRONT_Z
	_put("island_hall", town_kit, _facing(north, hall), "main_hall", [LBL], 1800.0)
	_note_rect(Vector2(cx, HALL_FRONT_Z + 9.0), 44.0, 46.0, 0.0, 1.0)
	for side in [-1.0, 1.0]:
		var wx: float = cx + side * 31.0
		var w: Vector3 = at_ground.call(wx, HALL_FRONT_Z + 18.0, 16.0, 18.0)
		w.z = HALL_FRONT_Z + 12.0
		_put("island_hall", town_kit, _facing(north, w), "shrine_hall", [LBL], 1800.0)
		_note_rect(Vector2(wx, w.z + 3.0), 16.0, 18.0, 0.0, 1.0)
	# The forecourt: stone lanterns in pairs from the hall to the water, a pair of guardian dogs, the island's shore.
	var z: float = HALL_FRONT_Z - 16.0
	var k := 0
	while z > 150.0 and _island_d(cx, z) < -3.0:
		for side in [-1.0, 1.0]:
			var lp := Vector3(cx + side * 9.0, 0.0, z)
			lp.y = _ground_at(lp.x, lp.z)
			_put("island_court", prop_kit, _facing(Vector3(-side, 0, 0), lp), "stone_lantern" if k % 2 == 0 else "bonbori", [0, 2.4] if k % 2 == 0 else [], 1200.0)
		z -= 7.0
		k += 1
	for side in [-1.0, 1.0]:
		var kp := Vector3(cx + side * 5.0, 0.0, HALL_FRONT_Z - 15.0)
		kp.y = _ground_at(kp.x, kp.z)
		_put("island_court", prop_kit, _facing(Vector3(0, 0, -1), kp), "komainu", [side < 0.0], 1200.0)
	# The pagoda at the island's west end, the bell tower at its east end, both facing outward over the water.
	var px: Vector3 = at_ground.call(16.0, 205.0, 20.0, 20.0)
	_put("island_pagoda", town_kit, _facing(Vector3(-1, 0, 0), px), "pagoda", [3], 2200.0)
	_note_circle(Vector2(px.x, px.z), 10.0)
	var bx: Vector3 = at_ground.call(174.0, 205.0, 14.0, 14.0)
	_put("island_court", town_kit, _facing(Vector3(1, 0, 0), bx), "bell_tower", [], 1200.0)
	_note_circle(Vector2(bx.x, bx.z), 7.0)
	# Weeping cherries at the forecourt's corners and the island's ends, pines by the hall, cherries behind it.
	for t in [["shidare", cx - 22.0, 160.0], ["shidare", cx + 22.0, 160.0], ["shidare", 22.0, 178.0], ["shidare", 168.0, 178.0],
			["matsu", cx - 26.0, 186.0], ["matsu", cx + 26.0, 186.0], ["sakura", 18.0, 236.0], ["sakura", 170.0, 236.0],
			["sakura", cx - 30.0, 250.0], ["sakura", cx + 30.0, 250.0], ["shidare", cx, 252.0]]:
		if _island_d(float(t[1]), float(t[2])) < -2.0:
			extra_trees.append([t[0], t[1], t[2], rng.randf_range(1.0, 1.2), rng.randi_range(0, 1)])
	# People in the forecourt, a few at the water.
	for i in range(14):
		var p := Vector3(cx + rng.randf_range(-16.0, 16.0), 0.0, rng.randf_range(150.0, HALL_FRONT_Z - 6.0))
		if _island_d(p.x, p.z) > -2.0 or absf(p.x - cx) < 3.0:
			continue
		p.y = _ground_at(p.x, p.z)
		_person(p, Vector3(rng.randf_range(-0.4, 0.4), 0, 1.0 if rng.randf() < 0.6 else -1.0), rng.randf_range(0.85, 1.05))


## The lake's north shore between the bridges: the temple's outer wall with its gate facing the island, a garden of
## lanterns and benches looking across the water; round the rest of the shore benches, lanterns, weeping cherries and
## a couple of pleasure boats.
func _build_shore(root: Node3D, rng: RandomNumberGenerator) -> void:
	var wz := 92.0
	var x0: float = LEG_W + road_half + 3.2
	var x1: float = LEG_E - road_half - 3.2
	var gate_half := 4.0
	for seg in [[x0, ISLAND_C.x - gate_half], [ISLAND_C.x + gate_half, x1]]:
		var n: int = maxi(1, int((float(seg[1]) - float(seg[0])) / 10.0))
		for i in range(n):
			var a := Vector3(lerpf(seg[0], seg[1], float(i) / float(n)), 0.0, wz)
			var b := Vector3(lerpf(seg[0], seg[1], float(i + 1) / float(n)), 0.0, wz)
			a.y = _ground_at(a.x, a.z)
			b.y = _ground_at(b.x, b.z)
			_put_world("shore_wall", a, town_kit, "temple_wall", [_life(a), _life(b)], 1200.0)
	_note_rect(Vector2((x0 + x1) * 0.5, wz), x1 - x0, 3.0, 0.0, 1.0)
	var g := Vector3(ISLAND_C.x, 0.0, wz)
	g.y = _ground_at(g.x, g.z)
	_put("shore_wall", town_kit, _facing(Vector3(0, 0, 1), g), "wall_gate", [3.2, LBL], 1200.0)
	# The garden between the wall and the water: lanterns, benches facing the island, people.
	for i in range(6):
		var gx: float = lerpf(x0 + 6.0, x1 - 6.0, float(i) / 5.0)
		var gz: float = wz + 9.0
		if _water_d(gx, gz) < 3.0:
			continue
		var p := Vector3(gx, _ground_at(gx, gz), gz)
		if i % 2 == 0:
			_put("shore_garden", prop_kit, _facing(Vector3(0, 0, 1), p), "red_bench", [i % 4 == 0], 900.0)
			_person(p + Vector3(0.8, 0, 3.0), Vector3(0, 0, 1), rng.randf_range(0.85, 1.05))
		else:
			_put("shore_garden", prop_kit, _facing(Vector3(0, 0, 1), p), "stone_lantern", [1, 1.6], 900.0)
	# Round the outer shore: march out from the lake's middle to land on each bearing.
	var c := Vector2(95.0, 240.0)
	for i in range(30):
		var ang: float = TAU * (float(i) + 0.4) / 30.0
		var dir := Vector2(cos(ang), sin(ang))
		var r := 60.0
		while r < 600.0 and _lake_d(c.x + dir.x * r, c.y + dir.y * r) < 7.0:
			r += 2.0
		var q: Vector2 = c + dir * r
		if r >= 600.0 or _occupied(q.x, q.y) or _route_dist(q.x, q.y) < road_half + 8.0:
			continue
		var p2 := Vector3(q.x, _ground_at(q.x, q.y), q.y)
		var face := Vector3(-dir.x, 0.0, -dir.y)
		match i % 3:
			0:
				_put(_cell_key("shore", p2), prop_kit, _facing(face, p2), "red_bench", [true], 600.0)
				_note_circle(q, 3.0)
				_person(p2 + face * 2.4, face, rng.randf_range(0.85, 1.05))
			1:
				_put(_cell_key("shore", p2), prop_kit, _facing(face, p2), "stone_lantern", [i % 2], 600.0)
			2:
				extra_trees.append(["shidare", q.x, q.y, rng.randf_range(0.95, 1.15), 0])
				_note_circle(q, 3.0)
	# Pleasure boats on the water.
	for b in [[Vector2(-120.0, 245.0), 0.4], [Vector2(300.0, 250.0), 2.2], [Vector2(95.0, 300.0), -1.1]]:
		var q2: Vector2 = b[0]
		if _water_d(q2.x, q2.y) < -6.0:
			_put("shore_boats", river_kit, Transform3D(Basis(Vector3.UP, float(b[1])), Vector3(q2.x, POND_Y, q2.y)), "river_boat", [2], 900.0)


## The valley: farmhouses beyond the pond and at the hill's foot, timber at the forest's edge.
func _build_valley(root: Node3D, rng: RandomNumberGenerator) -> void:
	var farms: Array = [Vector3(-420.0, 230.0, 0.4), Vector3(-520.0, 310.0, -0.3), Vector3(-20.0, 372.0, 0.2), Vector3(240.0, 375.0, -0.2),
			Vector3(470.0, 160.0, -1.2), Vector3(500.0, 30.0, -1.5), Vector3(-560.0, 120.0, 1.3)]
	for f in farms:
		if _in_lake(f.x, f.y, 18.0):
			continue
		var at := Vector3(f.x, 0.0, f.y)
		var gr: Vector2 = _ground_range(Vector2(f.x, f.y), 22.0, 16.0, f.z)
		at.y = gr.y
		var xf := Transform3D(Basis(Vector3.UP, f.z), at)
		if _put(_cell_key("farm", at), town_kit, xf, "kominka", [11.0, 7.5, rng], 900.0):
			_note_rect(Vector2(f.x, f.y), 24.0, 18.0, f.z, 3.0)
			# A koinobori pole in the yard in front of the house.
			var yard: Vector3 = xf * Vector3(-4.0, 0.0, 14.0)
			_farm_spots.append(Vector2(yard.x, yard.z))
	# Cedar logs stacked at the forest road's edge on the descent.
	for q in [Vector2(-455.0, -430.0), Vector2(-492.0, -110.0)]:
		var s: float = _closest_s(q)
		var lx: Transform3D = _beside(lap, s, road_half + 6.5)
		lx = Transform3D(Basis(Vector3.UP, PI * 0.5) * lx.basis, lx.origin)
		if _put(_cell_key("timber", lx.origin), river_kit, lx, "log_stack", [6, 6.0, rng], 500.0):
			_note_circle(Vector2(lx.origin.x, lx.origin.z), 7.0)


## Koinobori: carp streamers on poles in the park by the start and beside the farmhouses, streaming north up the
## valley with the wind that carries the petals.
const KOI_WIND := Vector3(0.25, 0.0, -1.0)

func _build_koinobori(rng: RandomNumberGenerator) -> void:
	# The park's at the lawn's front edge, tall enough for the carp to fly over the avenue's blossom (further back they
	# were hidden behind it from the road); the farmhouses' in their yards.
	var spots: Array = [[Vector2(-265.0, 100.0), 14.0], [Vector2(-185.0, 102.0), 14.0], [Vector2(-125.0, 100.0), 14.0], [Vector2(245.0, 100.0), 14.0]]
	for f in _farm_spots:
		spots.append([f, 10.0])
	var n := 0
	for sp in spots:
		var qq: Vector2 = sp[0]
		if _in_lake(qq.x, qq.y, 12.0) or _occupied(qq.x, qq.y) or _route_dist(qq.x, qq.y) < road_half + 12.0:
			continue
		var at := Vector3(qq.x, _ground_at(qq.x, qq.y), qq.y)
		_put(_cell_key("koinobori_poles", at), prop_kit, Transform3D(Basis(), at), "koinobori_pole", [float(sp[1]) + rng.randf_range(-0.8, 0.8), 2 + n % 2, KOI_WIND, rng], 900.0)
		_note_circle(qq, 7.0)
		n += 1
	print("  koinobori: %d poles" % n)


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
