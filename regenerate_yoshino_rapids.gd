# regenerate_yoshino_rapids.gd
#
# Builds levels/YoshinoRapidsLevel.tscn - Yoshino Rapids, the second stage of the Miyoshino GP: a lap round a reach of
# the emerald Yoshino river at midday, in the valley where the cedar of the hills was lashed into rafts and floated
# down to the sea. The lap starts in the riverside village on the south bank heading west (downstream), crosses the
# river on the vermilion-railed timber bridge, runs east through the lumber yard and its water-powered sawmill, climbs
# a gravel forest road through the cedar plantation, comes down a log-built timber slide (the shura), fords the river
# through the shallows of the upper rapids and returns along the south bank. A moored raft train lies across the
# calm pool above the bridge: a floating shortcut for whoever dares its width.
#
# Everything shared with the other Miyoshino stages is MiyoshinoStage.gd: read its header first. Here: the river
# (its line, width, level and depth as functions of x, which carve the ground and build the water), the course, what
# grows where, and the dressing.
extends "res://MiyoshinoStage.gd"

## Rapids, flowing west: [x, drop (m), length (m)]. The water's level falls by `drop` over `length` centred on x.
const RAPIDS := [[470.0, 1.2, 90.0], [120.0, 1.5, 70.0], [-160.0, 0.9, 60.0]]
## The ford: the lap wades the upper rapids' shallows here, this deep.
const FORD_X := 560.0
const FORD_DEPTH := 0.36
## The calm pool the rafts lie on.
const POOL_X := Vector2(-500.0, -215.0)
const DEEP := 2.5
## The lumber yard on the north bank: level ground.
const YARD_RECT := [-470.0, -196.0, -170.0, -112.0]
## The village's terrace on the south bank.
const VILLAGE_RECT := [-380.0, 96.0, 520.0, 190.0]
## The raft crossing: off the start straight, over the pool, onto the yard road.
const RAFT_PTS := [Vector2(-262.0, 125.0), Vector2(-322.0, 62.0), Vector2(-338.0, -96.0), Vector2(-292.0, -150.0)]

var s_bridge0 := 0.0
var s_bridge1 := 0.0
var s_yard_end := 0.0
var s_chute0 := 0.0
var s_chute1 := 0.0
var s_south := 0.0
var raft_s0 := 0.0
var raft_s1 := 0.0
var _raw_route: Route


func _configure() -> void:
	level_name = "YoshinoRapidsLevel"
	level_path = "res://levels/YoshinoRapidsLevel.tscn"
	stem = "yoshinogawa"
	title = "Yoshino Rapids"
	seed_base = 7300
	road_half = 7.5
	max_grade = 0.095
	corners = [
		[Vector2(560.0, 125.0), 50.0],     # out of the ford: right onto the south bank's road, west
		[Vector2(250.0, 140.0), 220.0],    # the road sways with the river
		[Vector2(-130.0, 112.0), 220.0],
		[Vector2(-430.0, 125.0), 55.0],    # right, north onto the bridge
		[Vector2(-430.0, -150.0), 50.0],   # right, east through the lumber yard
		[Vector2(-150.0, -150.0), 70.0],   # left, up into the cedars
		[Vector2(-40.0, -290.0), 45.0],    # right, east along the hillside
		[Vector2(240.0, -300.0), 40.0],    # right, down the timber slide
		[Vector2(400.0, -150.0), 60.0],    # left, along the north bank
		[Vector2(560.0, -140.0), 45.0],    # right, south through the ford
	]
	finish_at = Vector2(60.0, 126.0)
	fine_x = Vector2(-700.0, 740.0)
	fine_z = Vector2(-560.0, 420.0)
	bare_surface = "gravel"
	tree_step = 10.5
	tree_margin = 300.0


# ======================================================================================
#  The river
# ======================================================================================

func _river_z(x: float) -> float:
	return 40.0 * sin(x / 170.0) + 12.0 * sin(x / 61.0 + 1.0)


func _pool(x: float) -> float:
	return smoothstep(POOL_X.x - 40.0, POOL_X.x + 40.0, x) * (1.0 - smoothstep(POOL_X.y - 30.0, POOL_X.y + 30.0, x))


func _ford(x: float) -> float:
	return 1.0 - smoothstep(26.0, 60.0, absf(x - FORD_X))


func _river_half(x: float) -> float:
	return 24.0 + 14.0 * _pool(x) + 12.0 * _ford(x)


func _water_y(x: float) -> float:
	var y := 0.0
	for r in RAPIDS:
		y += float(r[1]) * smoothstep(float(r[0]) - float(r[2]) * 0.5, float(r[0]) + float(r[2]) * 0.5, x)
	return y


## How rough the water is at x (0 a pool .. 1 white water).
func _rough(x: float) -> float:
	var t := 0.0
	for r in RAPIDS:
		t = maxf(t, 1.0 - smoothstep(float(r[2]) * 0.35, float(r[2]) * 0.8, absf(x - float(r[0]))))
	return t


func _depth(x: float) -> float:
	var d: float = lerpf(DEEP, 1.0, _rough(x))
	return lerpf(d, FORD_DEPTH + 0.05, _ford(x))


## Signed distance from the river's edge: negative in the water.
func _shore_d(x: float, z: float) -> float:
	return absf(z - _river_z(x)) - _river_half(x)


func _map_water(x: float, z: float) -> float:
	return _water_y(x) if _shore_d(x, z) < 1.0 else NAN


func _natural(x: float, z: float) -> float:
	var zr: float = _river_z(x)
	var d: float = z - zr
	var hw: float = _river_half(x)
	var wy: float = _water_y(x)
	var ad: float = absf(d)
	if ad < hw:
		var q: float = ad / hw
		return wy - _depth(x) * pow(1.0 - q * q, 0.75)
	var out: float = ad - hw
	var h: float = wy + 2.7 * smoothstep(0.0, 13.0, out) + out * 0.006
	if d > 0.0:
		# The south bank: the village's terrace, then hills.
		h += maxf(0.0, z - 215.0) * 0.16 * (0.8 + 0.4 * n_land.get_noise_2d(x, z))
		h += smoothstep(215.0, 420.0, z) * 9.0 * n_hill.get_noise_2d(x * 0.6, z * 0.6)
	else:
		# The north bank: a strip of level ground, the plantation's slope, the steep hill behind.
		var t: float = maxf(0.0, out - 82.0)
		var hill: float = 0.1 * minf(t, 250.0) + 0.24 * maxf(0.0, t - 250.0)
		hill = minf(hill, 120.0 + 30.0 * n_land.get_noise_2d(x * 0.5, z * 0.5))
		h += hill + smoothstep(0.0, 120.0, t) * 5.0 * n_hill.get_noise_2d(x * 0.7, z * 0.7)
	h += 0.5 * n_fine.get_noise_2d(x * 0.4, z * 0.4) * smoothstep(8.0, 40.0, out)
	# Far ranges closing the valley.
	var far: float = Vector2(x, z).length()
	h += smoothstep(800.0, 3800.0, far) * (120.0 + 240.0 * absf(n_ridge.get_noise_2d(x, z))) * smoothstep(60.0, 500.0, ad)
	h = lerpf(h, _water_y(-320.0) + 3.0, _rect_weight(x, z, YARD_RECT, 28.0))
	h = lerpf(h, wy + 3.4, _rect_weight(x, z, VILLAGE_RECT, 30.0) * 0.85)
	return h


# ======================================================================================
#  The course
# ======================================================================================

func _init_noise() -> void:
	super._init_noise()
	_raw_route = Route.new()
	_raw_route.build(corners, true)
	# The bridge: where the lap's leg north along x = -430 is over the water (and a little of each bank).
	var s: float = _raw_route.closest_s(Vector2(-430.0, 70.0))
	var a := -1.0
	var b := -1.0
	var k: float = s
	while k < s + 220.0:
		var p: Vector2 = _raw_route.at(k)["p"]
		if _shore_d(p.x, p.y) < 7.0:
			if a < 0.0:
				a = k
			b = k
		k += 1.0
	s_bridge0 = a
	s_bridge1 = b
	bridges = [["lap", s_bridge0, s_bridge1, 2.6]]
	s_yard_end = _raw_route.closest_s(Vector2(-150.0, -150.0)) - 30.0
	s_chute0 = _raw_route.closest_s(Vector2(262.0, -279.0))
	s_chute1 = _raw_route.closest_s(Vector2(378.0, -171.0))
	s_south = _raw_route.closest_s(Vector2(560.0, 70.0))
	print("  the bridge from %.0f to %.0fm, the timber slide %.0f to %.0fm" % [s_bridge0, s_bridge1, s_chute0, s_chute1])


func _road_base(r: Route, _s: float, p: Vector2) -> float:
	var sd: float = _shore_d(p.x, p.y)
	if r.name == "RaftCrossing":
		# The banks down to the rafts' deck, a hand over the water.
		return maxf(_natural(p.x, p.y) + GROUND_UNDER, _water_y(p.x) + 0.5)
	if _ford(p.x) > 0.5 and sd < 3.0:
		return _water_y(p.x) - FORD_DEPTH
	return _natural(p.x, p.y) + GROUND_UNDER


func _plan_routes() -> void:
	var pts: Array = [[RAFT_PTS[0], 0.0], [RAFT_PTS[1], 22.0], [RAFT_PTS[2], 22.0], [RAFT_PTS[3], 0.0]]
	# Where the crossing is over the water: its own deck, not graded.
	var probe := Route.new()
	probe.build(pts, false)
	var a := -1.0
	var b := -1.0
	var s := 0.0
	while s < probe.length:
		var p: Vector2 = probe.at(s)["p"]
		if _shore_d(p.x, p.y) < 0.5:
			if a < 0.0:
				a = s
			b = s
		s += 1.0
	raft_s0 = a
	raft_s1 = b
	bridges.append(["RaftCrossing", raft_s0, raft_s1, 0.0, true])
	var r: Route = _add_route("RaftCrossing", pts, 4.6, true, 0.16)
	_report_profile(r)
	print("  the raft crossing: on the water from %.0f to %.0fm of %.0fm" % [raft_s0, raft_s1, r.length])
	shortcuts = [["RaftCrossing", 0.6]]


func _sections(r: Route) -> Array:
	if r.name == "RaftCrossing":
		return [[road_half + 0.6, raft_s0, K_DIRT, r.half], [raft_s1, r.length - road_half - 0.6, K_DIRT, r.half]]
	return [[0.0, s_bridge0, K_ASPHALT, r.half], [s_bridge0, s_bridge1, K_PLANKS, r.half], [s_bridge1, s_chute0, K_GRAVEL, r.half],
			[s_chute0, s_chute1, K_PLANKS, r.half], [s_chute1, s_south, K_GRAVEL, r.half], [s_south, r.length, K_ASPHALT, r.half]]


func _grade_params(r: Route, s: float) -> Array:
	if r.name == "RaftCrossing":
		return [r.half + 1.0, r.half + 1.0, 0.8, 0.8]
	return [r.half + 2.0, r.half + 2.0, cut_slope, fill_slope]


# ======================================================================================
#  What grows where
# ======================================================================================

## Cherries along both banks and through the village.
func _grove_w(x: float, z: float) -> float:
	var sd: float = _shore_d(x, z)
	var bank: float = smoothstep(4.0, 14.0, sd) * (1.0 - smoothstep(40.0, 75.0, sd))
	var south: float = 1.0 if z > _river_z(x) else 0.55
	return clampf(bank * south * (0.45 + 0.7 * smoothstep(-0.2, 0.3, n_wood.get_noise_2d(x * 1.5, z * 1.5))), 0.0, 1.0) \
			* (1.0 - _rect_weight(x, z, YARD_RECT, 10.0))


## The cedar plantation on the north hill, woods on the southern hills.
func _forest_w(x: float, z: float) -> float:
	var d: float = z - _river_z(x)
	var sd: float = _shore_d(x, z)
	var w := 0.0
	if d < 0.0:
		w = smoothstep(70.0, 110.0, sd)
	else:
		w = smoothstep(215.0, 260.0, z) * (0.6 + 0.4 * n_wood.get_noise_2d(x, z))
	return clampf(w, 0.0, 1.0) * (1.0 - _rect_weight(x, z, YARD_RECT, 6.0))


func _masks(_i: int, x: float, z: float, nrm_y: float, road_d: float) -> Color:
	var off: float = smoothstep(road_half + 3.0, road_half + 14.0, road_d)
	var rock: float = 1.0 - smoothstep(0.60, 0.76, nrm_y)
	var sd: float = _shore_d(x, z)
	# Shingle in the bed and up the banks, the yard's trodden ground, the village's lanes.
	var bare: float = 1.0 - smoothstep(3.0, 9.0, sd + 2.0 * n_fine.get_noise_2d(x, z))
	bare = maxf(bare, _rect_weight(x, z, YARD_RECT, 8.0))
	var grove: float = _grove_w(x, z)
	var forest: float = _forest_w(x, z) * (1.0 - grove)
	return Color(rock * (1.0 - bare), bare, grove * off * (1.0 - bare), forest * off * (1.0 - bare))


func _wet(x: float, z: float) -> float:
	return 1.0 - smoothstep(-1.0, 7.0, _shore_d(x, z))


func _tree_pick(x: float, z: float, roll: float, rng: RandomNumberGenerator) -> Array:
	var sd: float = _shore_d(x, z)
	if sd < 5.0 or _in_rect(x, z, YARD_RECT, 4.0):
		return []
	if _in_rect(x, z, VILLAGE_RECT, -6.0) and z > 132.0:
		return []
	var g: float = _grove_w(x, z)
	var f: float = _forest_w(x, z) * (1.0 - g)
	f *= lerpf(1.0, 0.3, smoothstep(560.0, 760.0, Vector2(x, z).length()))
	if roll < g * 0.5:
		var r: float = rng.randf()
		if r < 0.12:
			return ["momiji", rng.randf_range(0.9, 1.2)]
		if r < 0.2:
			return ["shidare", rng.randf_range(0.9, 1.15)]
		if r < 0.5:
			return ["yamazakura", rng.randf_range(0.85, 1.15), rng.randi_range(0, 1)]
		return ["sakura", rng.randf_range(0.85, 1.2), rng.randi_range(0, 1)]
	if roll < g * 0.5 + f * 0.6:
		if z > 0.0 and rng.randf() < 0.25:
			return ["yamazakura", rng.randf_range(0.9, 1.2)]
		if z > 0.0 and rng.randf() < 0.15:
			return ["take", rng.randf_range(0.9, 1.15)]
		return ["sugi", rng.randf_range(0.8, 1.2), rng.randi_range(0, 1)]
	return []


func _environment() -> Dictionary:
	# Midday, the sun high in the south, a few more clouds.
	return {"sun_pitch": -62.0, "sun_yaw": -8.0, "cloud_coverage": 0.42, "cloud_seed": 33.1, "fog_end": 3400.0,
		"sun_energy": 1.45, "ambient": 0.6}


func _ground_params(m: ShaderMaterial) -> void:
	m.set_shader_parameter("petal_amount", 1.0)
	m.set_shader_parameter("moss_amount", 0.6)
	m.set_shader_parameter("earth_tint", Color(0.52, 0.47, 0.40))


# ======================================================================================
#  Gameplay
# ======================================================================================

func _place_gameplay(root: Node3D) -> void:
	var fin: float = _finish_s()
	_checkpoints([
		_closest_s(Vector2(-250.0, -150.0)),   # the lumber yard (past where the rafts land)
		_closest_s(Vector2(110.0, -295.0)),    # the forest road
		_closest_s(Vector2(470.0, -146.0)),    # below the timber slide
		_closest_s(Vector2(560.0, 62.0)),      # out of the ford
		_closest_s(Vector2(330.0, 136.0)),     # the village
	])
	_boosts([
		["Boost_Village", fin + 90.0, 0.0],
		["Boost_Yard", _closest_s(Vector2(-330.0, -150.0)), -2.6],
		["Boost_Forest", _closest_s(Vector2(20.0, -291.0)), 0.0],
	])
	# The timber slide ends in a lip: a low kicker at its foot.
	_kicker(root, "SlideJump", lap, s_chute1 - 4.0, 10.0, 1.3, 0.35)


# ======================================================================================
#  The water
# ======================================================================================

func _build_water(root: Node3D) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://river_water.gdshader")
	var n := FastNoiseLite.new()
	n.seed = 3301
	n.frequency = 0.035
	n.fractal_octaves = 3
	var nt := NoiseTexture2D.new()
	nt.seamless = true
	nt.as_normal_map = true
	nt.bump_strength = 6.0
	nt.noise = n
	nt.width = 256
	nt.height = 256
	mat.set_shader_parameter("noise_tex", nt)
	var f := FastNoiseLite.new()
	f.seed = 919
	f.frequency = 0.05
	f.fractal_octaves = 4
	f.noise_type = FastNoiseLite.TYPE_CELLULAR
	f.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_DIV
	var ft := NoiseTexture2D.new()
	ft.seamless = true
	ft.noise = f
	ft.width = 256
	ft.height = 256
	mat.set_shader_parameter("foam_noise", ft)
	# The Yoshino's emerald: clear green shallows over the shingle, deep jade pools.
	mat.set_shader_parameter("deep_color", Color(0.012, 0.13, 0.10))
	mat.set_shader_parameter("shallow_color", Color(0.08, 0.36, 0.26))
	mat.set_shader_parameter("sky_tint", Color(0.26, 0.42, 0.40))
	mat.set_shader_parameter("flow_speed", 1.6)
	mat.set_shader_parameter("clarity_depth", 2.0)
	mat.set_shader_parameter("shore_foam_depth", 0.2)
	var smat: Material = _save_res(mat, "river_material")
	var node := Node3D.new()
	node.name = "RiverWater"
	node.set_script(load("res://RiverWater.gd"))
	root.add_child(node)
	var pts := PackedVector3Array()
	var halves := PackedFloat32Array()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var across := 8
	var x0 := 1500.0
	var x1 := -1500.0
	var step := 6.0
	var n_s: int = int((x0 - x1) / step)
	var rows: Array = []
	# Downstream is west: the ribbon runs from the east end to the west one, UV.y metres downstream.
	for i in range(n_s + 1):
		var x: float = x0 - float(i) * step
		var p := Vector3(x, _water_y(x), _river_z(x))
		var hw: float = _river_half(x) + 2.5
		pts.append(p)
		halves.append(hw)
		var dzdx: float = (_river_z(x - 1.0) - _river_z(x + 1.0)) / 2.0
		var fwd := Vector3(-1.0, 0.0, dzdx).normalized()
		var right := Vector3(-fwd.z, 0.0, fwd.x)
		var rough: float = _rough(x)
		var row: Array = []
		for k in range(across + 1):
			var u: float = float(k) / float(across)
			row.append([p + right * lerpf(-hw, hw, u), Color(rough * 0.42, 0.35 + rough * 0.9, 0.0, 1.0), Vector2(u, float(i) * step)])
		rows.append(row)
	for i in range(n_s):
		for k in range(across):
			var a: Array = rows[i][k]
			var b: Array = rows[i][k + 1]
			var c: Array = rows[i + 1][k]
			var d: Array = rows[i + 1][k + 1]
			for tri in [[a, b, c], [b, d, c]]:
				var p0: Vector3 = tri[0][0]
				var p1: Vector3 = tri[1][0]
				var p2: Vector3 = tri[2][0]
				var order: Array = tri
				# Clockwise from above (Godot's front face).
				if (p2 - p0).cross(p1 - p0).y < 0.0:
					order = [tri[0], tri[2], tri[1]]
				for v in order:
					st.set_color(v[1])
					st.set_uv(v[2])
					st.set_normal(Vector3.UP)
					st.add_vertex(v[0])
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, smat)
	var mi := MeshInstance3D.new()
	mi.name = "RiverSurface"
	mi.mesh = _save_res(mesh, "river", stem + "far_")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	node.set("strip_points", pts)
	node.set("strip_half_widths", halves)
	node.set("strip_starts", PackedInt32Array([0]))
	node.set("water_bounds", Rect2(-1500.0, -140.0, 3000.0, 280.0))


# ======================================================================================
#  Dressing
# ======================================================================================

func _build_dressing(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_base + 77
	var fin: float = _finish_s()
	_build_start_crowd(root, fin - 95.0, fin + 85.0, road_half + 3.0, fin - 8.0, fin + 8.0, seed_base + 11)
	_build_village(root, rng, fin)
	_build_bridge(root)
	_build_rafts(root, rng)
	_build_yard(root, rng)
	_build_forest_road(root, rng)
	_build_slide(root)
	_build_ford(root, rng)
	_build_koinobori(rng)
	_auto_guardrails(root, lap, 0.0, lap.length, 2.8, [[s_chute0 - 10.0, s_chute1 + 10.0], [s_south - 80.0, s_south + 20.0]])
	var pg := Node3D.new()
	pg.name = "PetalGusts"
	pg.set_script(load("res://PetalGusts.gd"))
	pg.set("falling", 170)
	root.add_child(pg)


## The riverside village along the start straight: houses on the landward side, the river side open under an avenue
## of cherries, lamps and banners, boats drawn up on the shingle.
func _build_village(root: Node3D, rng: RandomNumberGenerator, fin: float) -> void:
	var s0: float = _closest_s(Vector2(500.0, 125.0))
	var s1: float = _closest_s(Vector2(-370.0, 125.0))
	# Heading west the river is on the right: houses on the left.
	var s: float = s0
	var k := 0
	while s < s1:
		var variant: int = [0, 1, 0, 3, 2, 0, 4, 1, 5, 0][k % 10]
		var def: Vector3 = _kit_value(town_kit, "machiya_default", [variant], Vector3(7.2, 9.0, 2.0))
		var w: float = def.x * PROP_SCALE
		var ext: float = float(_kit_value(town_kit, "machiya_extent", [variant], 1.5)) * PROP_SCALE
		if absf(s + w * 0.5 - fin) > 16.0 and rng.randf() < 0.86:
			var sp: Dictionary = lap.spot(s + w, -(road_half + 3.2 + ext), 0.0)
			var pos: Vector3 = sp["pos"]
			var gr: Vector2 = _ground_range(Vector2(pos.x, pos.z + 6.0), w, 14.0, 0.0)
			pos.y = gr.y
			# The house's x runs along the street from its left corner as seen from the road: its front faces the road.
			var xf: Transform3D = _facing(sp["right"], pos)
			if _put(_cell_key("village", pos), town_kit, xf, "machiya", [def.x, def.y, int(def.z), variant, rng, LBL], 1100.0):
				_note_frame(xf, Vector2(-0.5, -def.y - 0.5), Vector2(def.x + 0.5, 2.0), 1.0)
		s += w + rng.randf_range(1.0, 6.0)
		k += 1
	# The river side: an avenue of cherries, lamps between them, banners, benches looking at the water.
	s = s0 + 6.0
	k = 0
	while s < s1:
		var sp2: Dictionary = lap.spot(s, road_half + 6.0, 0.0)
		var p: Vector3 = sp2["pos"]
		if absf(s - fin) > 12.0 and _shore_d(p.x, p.z) > 5.0:
			extra_trees.append(["sakura", p.x, p.z, rng.randf_range(0.95, 1.15), k % 2])
			_note_circle(Vector2(p.x, p.z), 2.0)
		if k % 2 == 0:
			var lx: Transform3D = _beside(lap, s + 8.0, road_half + 4.2)
			_put(_cell_key("riverside", lx.origin), prop_kit, lx, "bonbori", [], 420.0)
		if k % 5 == 2:
			var bx: Transform3D = _beside(lap, s + 8.0, road_half + 9.5)
			bx = Transform3D(Basis(Vector3.UP, PI) * bx.basis, bx.origin)
			if _shore_d(bx.origin.x, bx.origin.z) > 6.0:
				_put(_cell_key("riverside", bx.origin), prop_kit, bx, "red_bench", [k % 10 == 2], 420.0)
				_note_circle(Vector2(bx.origin.x, bx.origin.z), 3.0)
				_person(bx.origin + bx.basis.z * 2.0, bx.basis.z, rng.randf_range(0.88, 1.05))
		s += 16.0
		k += 1
	for ds in [-60.0, -30.0, 30.0, 60.0]:
		var nx: Transform3D = _beside(lap, fin + ds, road_half + 5.0)
		_put(_cell_key("riverside", nx.origin), prop_kit, nx, "nobori", [Color(0.20, 0.30, 0.55)], 420.0)
	# Utility poles behind the houses' eaves... along the river side's verge, with their wires.
	var prev := Vector3.INF
	s = s0 + 30.0
	k = 0
	while s < s1:
		var px: Transform3D = _beside(lap, s, -(road_half + 1.9))
		_put(_cell_key("poles", px.origin), prop_kit, px, "utility_pole", [9.5, k % 3], 500.0)
		var top: Vector3 = px.origin + Vector3(0, 9.0 * PROP_SCALE, 0)
		if prev != Vector3.INF:
			_put_world("poles", top, prop_kit, "pole_wires", [_life(prev), _life(top), 0.7, 3], 500.0)
		prev = top
		s += 46.0
		k += 1
	# Boats on the shingle and moored in the pool below the village.
	for i in range(6):
		var x: float = lerpf(-150.0, 380.0, float(i) / 5.0) + rng.randf_range(-20.0, 20.0)
		var z: float = _river_z(x) + _river_half(x) - (3.0 if i % 2 == 0 else -1.5)
		var at := Vector3(x, _water_y(x) if i % 2 == 0 else _ground_at(x, z) + 0.15, z)
		var bxf := Transform3D(Basis(Vector3.UP, rng.randf_range(1.2, 1.9)), at)
		_put(_cell_key("boats", at), river_kit, bxf, "river_boat", [i % 3], 600.0)
	# A drinks machine by the line.
	var vx: Transform3D = _beside(lap, fin + 70.0, -(road_half + 2.4))
	_put(_cell_key("riverside", vx.origin), prop_kit, vx, "vending_machine", [1], 300.0)


## The timber bridge with vermilion railings (the kit builds all but the deck), its railings solid.
func _build_bridge(root: Node3D) -> void:
	var o: Vector3 = lap.pt(s_bridge0)
	var fwd: Vector3 = lap.fw(s_bridge0)
	var xf := _facing(-fwd, o)
	var span: float = s_bridge1 - s_bridge0
	var deck := func(t: float) -> float: return lap.y(s_bridge0 + t) - o.y
	var ground := func(x: float, t: float) -> float:
		var p: Vector3 = lap.pt(s_bridge0 + t) + lap.rt(s_bridge0 + t) * -x
		return _ground_at(p.x, p.z) - o.y
	_add_prop_game("river_span", river_kit, xf, func(pk: PropKit, kit: Dictionary, _labels: Array) -> void:
		_kit_call(river_kit, "road_bridge", [pk, kit, span, road_half, deck, ground, 0]), 1500.0)
	var body: StaticBody3D = _body(root, "RiverRailsBody")
	for side in [-1.0, 1.0]:
		_edge_boxes(body, lap, s_bridge0 - 3.0, s_bridge1 + 3.0, side * (road_half + 0.3), 1.7, 0.4)
	print("  the bridge: %.0fm, its deck %.1fm over the water" % [span, lap.y((s_bridge0 + s_bridge1) * 0.5) - _water_y(-430.0)])


## The raft train across the pool: sections of lashed logs end to end along the crossing, their deck one row of flat
## boxes (wood, driven on); and rafts drifting down the river.
func _build_rafts(root: Node3D, rng: RandomNumberGenerator) -> void:
	var r: Route = _route_by_name["RaftCrossing"]
	var logs := 11
	var raft_len: float = 7.5
	var w_life: float = float(_kit_value(river_kit, "raft_width", [logs], 3.6))
	var mesh: ArrayMesh = _kit_mesh(river_kit, "raft_section", func(pk: PropKit, kit: Dictionary) -> void:
		_kit_call(river_kit, "log_raft", [pk, kit, logs, raft_len, rng]))
	var holder := Node3D.new()
	holder.name = "RaftTrain"
	holder.set_script(load("res://RiverRafts.gd"))
	root.add_child(holder)
	var body := StaticBody3D.new()
	body.name = "RaftDeckBody"
	body.set_meta(&"surface", "wood")
	root.add_child(body)
	var step: float = raft_len * PROP_SCALE + 0.3
	var s: float = raft_s0 - 1.0 + step * 0.5
	var n := 0
	# Two sections abreast make the deck wide enough to drive.
	var wide: float = w_life * PROP_SCALE
	while s < raft_s1 + 1.0 + step * 0.5:
		var p: Vector3 = r.pt(s)
		var fwd: Vector3 = r.fw(s)
		var wy: float = _water_y(p.x)
		var basis := Basis(Vector3.UP.cross(fwd).normalized(), Vector3.UP, fwd)
		for side in [-0.5, 0.5]:
			if mesh != null:
				var mi := MeshInstance3D.new()
				mi.name = "Moored_%d_%s" % [n, "a" if side < 0.0 else "b"]
				mi.mesh = mesh
				mi.transform = Transform3D(basis.scaled(Vector3.ONE * PROP_SCALE), Vector3(p.x, wy, p.z) + basis.x * side * (wide + 0.2))
				mi.set_meta(&"skip_dressing_colliders", true)
				holder.add_child(mi)
		_box_shape(body, Transform3D(basis, Vector3(p.x, wy + 0.30 * PROP_SCALE - 0.6, p.z)), Vector3(wide * 2.0 + 0.4, 1.2, step + 0.2))
		s += step
		n += 1
	# Rafts drifting down the river: scenery, carried by RiverRafts on the wall clock.
	var path := PackedVector3Array()
	var x := 1100.0
	while x > -1100.0:
		path.append(Vector3(x, _water_y(x), _river_z(x)))
		x -= 12.0
	holder.set("drift_path", path)
	holder.set("drift_speed", 2.6)
	if mesh != null:
		for i in range(5):
			var d := MeshInstance3D.new()
			d.name = "Drift_%d" % i
			d.mesh = mesh
			d.scale = Vector3.ONE * PROP_SCALE
			d.set_meta(&"skip_dressing_colliders", true)
			holder.add_child(d)
			var cargo: ArrayMesh = _kit_mesh(river_kit, "raft_cargo_%d" % (i % 3), func(pk: PropKit, kit: Dictionary) -> void:
				_kit_call(river_kit, "raft_cargo", [pk, kit, i % 3, rng]))
			if cargo != null:
				var c := MeshInstance3D.new()
				c.name = "Cargo"
				c.mesh = cargo
				d.add_child(c)
	print("  the raft train: %d sections, %.1fm wide" % [n, wide * 2.0])


## The lumber yard: the water-powered sawmill, stacks of cedar logs and sawn boards.
func _build_yard(root: Node3D, rng: RandomNumberGenerator) -> void:
	# The sawmill on the yard's hill side, facing the road (south).
	var size: Vector3 = _kit_value(river_kit, "sawmill_size", [], Vector3(16.0, 7.0, 9.0))
	var at := Vector3(-300.0, 0.0, -150.0 - road_half - 6.0)
	at.y = _ground_at(at.x, at.z)
	var xf := Transform3D(Basis(), at)
	if _put("sawmill", river_kit, xf, "sawmill", [LBL], 1200.0):
		_note_frame(xf, Vector2(-4.0, -size.z - 1.0), Vector2(size.x + 1.0, 1.0), 2.0)
		var wheel_at: Vector3 = _kit_value(river_kit, "sawmill_wheel_at", [], Vector3(-2.0, 2.6, -4.0))
		var wmesh: ArrayMesh = _kit_mesh(river_kit, "sawmill_wheel", func(pk: PropKit, kit: Dictionary) -> void:
			_kit_call(river_kit, "water_wheel", [pk, kit]))
		if wmesh != null:
			var w := MeshInstance3D.new()
			w.name = "SawmillWheel"
			w.mesh = wmesh
			w.set_script(load("res://Spinner.gd"))
			w.set("axis", Vector3(1, 0, 0))
			w.set("degrees_per_second", 26.0)
			w.transform = Transform3D(Basis.from_scale(Vector3.ONE * PROP_SCALE), xf * (wheel_at * PROP_SCALE))
			root.add_child(w)
	# Logs and boards along both sides of the yard road.
	var spots: Array = [[-420.0, -1.0, "log_stack", [6, 6.0, rng]], [-395.0, 1.0, "log_pile", [9, 4.0, rng]], [-360.0, 1.0, "log_stack", [5, 6.0, rng]],
			[-245.0, -1.0, "plank_stack", []], [-232.0, -1.0, "plank_stack", []], [-215.0, 1.0, "log_stack", [7, 6.0, rng]],
			[-195.0, -1.0, "kinma_sled", []], [-250.0, 1.0, "log_pile", [7, 4.0, rng]]]
	for sp in spots:
		var s: float = _closest_s(Vector2(float(sp[0]), -150.0))
		var lx: Transform3D = _beside(lap, s, float(sp[1]) * (road_half + 7.0))
		if _occupied(lx.origin.x, lx.origin.z):
			continue
		lx = Transform3D(Basis(Vector3.UP, PI * 0.5) * lx.basis, lx.origin)
		if _put(_cell_key("timber", lx.origin), river_kit, lx, String(sp[2]), sp[3], 700.0):
			_note_circle(Vector2(lx.origin.x, lx.origin.z), 7.0)


## The forest road: a cedar torii and a wayside shrine at the top of the climb, way-stones.
func _build_forest_road(root: Node3D, rng: RandomNumberGenerator) -> void:
	var s_t: float = _closest_s(Vector2(60.0, -292.0))
	var hx: Transform3D = _beside(lap, s_t, -(road_half + 4.0))
	_put(_cell_key("wayside", hx.origin), prop_kit, hx, "hokora", [], 400.0)
	var jx: Transform3D = _beside(lap, s_t + 22.0, -(road_half + 4.0))
	_put(_cell_key("wayside", jx.origin), prop_kit, jx, "jizo_row", [6, rng], 400.0)
	var mx: Transform3D = _beside(lap, _closest_s(Vector2(-95.0, -220.0)), road_half + 3.5)
	_put(_cell_key("wayside", mx.origin), prop_kit, mx, "stone_marker", [1.5, "YOSHINO SUGI", LBL], 400.0)
	for q in [Vector2(-10.0, -292.0), Vector2(170.0, -298.0)]:
		var lx: Transform3D = _beside(lap, _closest_s(q), road_half + 6.5)
		lx = Transform3D(Basis(Vector3.UP, PI * 0.5) * lx.basis, lx.origin)
		if _put(_cell_key("timber", lx.origin), river_kit, lx, "log_stack", [5, 6.0, rng], 700.0):
			_note_circle(Vector2(lx.origin.x, lx.origin.z), 7.0)


## The timber slide's log walls and trestles (the kit), its walls solid.
func _build_slide(root: Node3D) -> void:
	var pts := PackedVector3Array()
	var rights := PackedVector3Array()
	var s: float = s_chute0
	while s <= s_chute1:
		pts.append(lap.pt(s))
		rights.append(lap.rt(s))
		s += 2.0
	var ground := func(x: float, z: float) -> float: return _ground_at(x, z)
	_add_prop_game("timber_slide", river_kit, Transform3D.IDENTITY, func(pk: PropKit, kit: Dictionary, _labels: Array) -> void:
		_kit_call(river_kit, "timber_chute", [pk, kit, pts, rights, road_half, ground]), 1200.0)
	var body: StaticBody3D = _body(root, "SlideWallsBody")
	for side in [-1.0, 1.0]:
		_edge_boxes(body, lap, s_chute0, s_chute1 - 6.0, side * (road_half + 0.45), 1.5, 0.6)


## The ford: a fish weir below it, way-stones either side, a boat.
func _build_ford(root: Node3D, rng: RandomNumberGenerator) -> void:
	var x: float = FORD_X - 75.0
	var at := Vector3(x, _water_y(x), _river_z(x) + 6.0)
	_put("ford_yana", river_kit, Transform3D(Basis(Vector3.UP, PI * 0.5), at), "yana", [9.0], 800.0)
	for q in [Vector2(FORD_X, -70.0), Vector2(FORD_X, 62.0)]:
		var mx: Transform3D = _beside(lap, _closest_s(q), road_half + 3.0)
		_put(_cell_key("wayside", mx.origin), prop_kit, mx, "stone_lantern", [0], 400.0)


## Koinobori: lines of carp across the river (as Japanese river towns hang them in May), streaming downstream, and
## poles on the village's river side.
func _build_koinobori(rng: RandomNumberGenerator) -> void:
	var wind := Vector3(-1.0, 0.0, 0.08)
	var lines := 0
	# Just downstream of the timber bridge (seen from it and from the rafts), mid-river, and above the ford.
	for x in [-385.0, 175.0, 480.0]:
		var zc: float = _river_z(x)
		var hw: float = _river_half(x) + 9.0
		var a := Vector3(x, 0.0, zc - hw)
		var b := Vector3(x, 0.0, zc + hw)
		a.y = _ground_at(a.x, a.z)
		b.y = _ground_at(b.x, b.z)
		if _occupied(a.x, a.z) or _occupied(b.x, b.z):
			continue
		var n: int = int(a.distance_to(b) / 5.4)
		_put_world("koinobori_river", a, prop_kit, "koinobori_line", [_life(a), _life(b), n, wind, 1.6, rng, 10.5], 1400.0)
		_note_circle(Vector2(a.x, a.z), 3.0)
		_note_circle(Vector2(b.x, b.z), 3.0)
		lines += 1
	var poles := 0
	for q in [Vector2(430.0, 0.0), Vector2(60.0, 0.0), Vector2(-220.0, 0.0)]:
		var s_q: float = _closest_s(Vector2(q.x, 125.0))
		var at: Vector3 = lap.spot(s_q, road_half + 16.0, 0.0)["pos"]
		if _water_d_ok(at) and not _occupied(at.x, at.z):
			at.y = _ground_at(at.x, at.z)
			_put(_cell_key("koinobori_poles", at), prop_kit, Transform3D(Basis(), at), "koinobori_pole", [12.0, 2 + poles % 2, wind, rng], 900.0)
			_note_circle(Vector2(at.x, at.z), 7.0)
			poles += 1
	print("  koinobori: %d lines over the river, %d poles" % [lines, poles])


func _water_d_ok(p: Vector3) -> bool:
	return _shore_d(p.x, p.z) > 12.0
