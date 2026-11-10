# regenerate_yamabushi.gd
#
# Builds levels/YamabushiLevel.tscn - the Yamabushi Trail, the Miyoshino GP's finale: a point-to-point hill climb (one
# run, no laps) up the mountain ascetics' pilgrim trail at dawn. The trail winds one and a half times round a great
# cone of a mountain from the cedar forest at its foot, over a suspension bridge across the gorge, through the layer of
# cloud that hangs round the mountain's waist (the fog closes in to a few dozen metres), out above it into the
# sunrise along plank walkways chained to the cliffs, over the gorge's head on a timber bridge and up to the shrine on
# the summit, the cloud a sea below. (The file is "YamabushiLevel": "trail" in a level's name would make
# DressingColliders skip every mesh on it.)
#
# Everything shared with the other Miyoshino stages is MiyoshinoStage.gd: read its header first. Here: the mountain
# (a cone about the origin: its height is a function of the distance from the summit, a gorge down one flank), the
# trail (a spiral of corner points), the cloud (CloudLayer.gd, cloud_sea.gdshader) and the dressing.
extends "res://MiyoshinoStage.gd"

## The cone: SUMMIT_Y at the top, level out to TOP_R, falling at SLOPE to FOOT_R, the foothills beyond.
const SUMMIT_Y := 262.0
const TOP_R := 78.0
const SLOPE := 0.37
const FOOT_R := 800.0
## The trail's spiral: from R0 at bearing 0 (east of the summit) inward to R1 over TURNS degrees, a corner every STEP.
const R0 := 770.0
const R1 := 60.0
const TURNS := 590.0
const STEP := 20.0
## The gorge down the mountain's flank at this bearing (degrees): how deep and wide at the foot, fading to the top.
const GORGE_AT := 205.0
const GORGE_DEPTH := 30.0
const GORGE_HALF := 26.0
## The plank walkways: [bearing from, bearing to] along the spiral.
const LEDGES := [[262.0, 300.0], [442.0, 486.0]]
## The cloud's band.
const CLOUD_LOW := 96.0
const CLOUD_HIGH := 150.0

var _bridge_s: Array = []
var _ledge_s: Array = []
var _raw_route: Route


func _configure() -> void:
	level_name = "YamabushiLevel"
	level_path = "res://levels/YamabushiLevel.tscn"
	stem = "yamabushi"
	title = "Yamabushi Trail"
	seed_base = 7700
	road_half = 7.0
	max_grade = 0.105
	cut_slope = 1.05
	fill_slope = 0.85
	closed = false
	point_to_point = true
	start_s = 70.0
	finish_runout = 46.0
	corners = []
	var a := 0.0
	var k := 0
	while a <= TURNS + 0.01:
		var p: Vector2 = _spiral(a) * (1.0 + (0.03 * sin(float(k) * 2.4) if a > 30.0 and a < TURNS - 40.0 else 0.0))
		var chord: float = (_spiral(a + STEP) - _spiral(a)).length()
		corners.append([p, clampf(chord * 0.8, 20.0, 130.0)])
		a += STEP
		k += 1
	# The run-in: a straight start before the first corner, and the last metres straight onto the summit.
	var d0: Vector2 = ((corners[1][0] as Vector2) - (corners[0][0] as Vector2)).normalized()
	corners.push_front([(corners[0][0] as Vector2) - d0 * 150.0, 0.0])
	fine_x = Vector2(-900.0, 960.0)
	fine_z = Vector2(-900.0, 900.0)
	fine_step = 5.0
	tree_step = 12.0
	tree_margin = 200.0
	tree_far_range = 1500.0
	collide_margin = 60.0


func _spiral(deg: float) -> Vector2:
	var t: float = clampf(deg / TURNS, 0.0, 1.0)
	var r: float = lerpf(R0, R1, t)
	var a: float = deg_to_rad(deg)
	return Vector2(cos(a), sin(a)) * r


# ======================================================================================
#  The mountain
# ======================================================================================

func _gorge(x: float, z: float) -> float:
	var r: float = Vector2(x, z).length()
	if r < 110.0:
		return 0.0
	var a: float = deg_to_rad(GORGE_AT)
	var axis := Vector2(cos(a), sin(a))
	var along: float = Vector2(x, z).dot(axis)
	if along < 0.0:
		return 0.0
	var across: float = absf(-x * axis.y + z * axis.x) + 9.0 * sin(r / 46.0)
	var w: float = GORGE_HALF * (0.55 + 0.45 * smoothstep(120.0, 600.0, r))
	var q: float = across / w
	return GORGE_DEPTH * (0.4 + 0.6 * smoothstep(120.0, 500.0, r)) * exp(-q * q) * smoothstep(110.0, 170.0, r)


func _natural(x: float, z: float) -> float:
	var r: float = Vector2(x, z).length()
	var h: float = SUMMIT_Y - maxf(0.0, r - TOP_R) * SLOPE
	# Round the summit's shoulder and the foot.
	h = minf(h, SUMMIT_Y - 0.0)
	var foot: float = SUMMIT_Y - (FOOT_R - TOP_R) * SLOPE
	if r > FOOT_R:
		h = foot - (r - FOOT_R) * 0.05
		h = maxf(h, foot - 26.0)
	# Spurs and hollows, bolder higher up; crags where the noise runs high.
	var up: float = smoothstep(FOOT_R, 150.0, r)
	h += (3.0 + 5.0 * up) * n_hill.get_noise_2d(x * 0.8, z * 0.8) * smoothstep(TOP_R, TOP_R + 60.0, r)
	h += 1.2 * n_fine.get_noise_2d(x * 0.6, z * 0.6) * smoothstep(TOP_R, TOP_R + 40.0, r)
	h -= _gorge(x, z)
	# Other peaks standing out of the cloud far off.
	h += smoothstep(1500.0, 4200.0, r) * (240.0 + 360.0 * absf(n_ridge.get_noise_2d(x, z)))
	return h


func _init_noise() -> void:
	super._init_noise()
	_raw_route = Route.new()
	_raw_route.build(corners, false)
	# Bridges: where the trail is over the gorge.
	var s := 0.0
	var a := -1.0
	var b := -1.0
	while s < _raw_route.length:
		var p: Vector2 = _raw_route.at(s)["p"]
		if _gorge(p.x, p.y) > 5.0:
			if a < 0.0:
				a = s
			b = s
		elif a >= 0.0:
			bridges.append(["lap", a - 5.0, b + 5.0, 0.0])
			_bridge_s.append([a - 5.0, b + 5.0])
			a = -1.0
		s += 1.0
	for l in LEDGES:
		var s0: float = _raw_route.closest_s(_spiral(float(l[0])))
		var s1: float = _raw_route.closest_s(_spiral(float(l[1])))
		_ledge_s.append([s0, s1])
	print("  bridges %s, plank walks %s" % [str(_bridge_s), str(_ledge_s)])


func _on_ledge(s: float) -> bool:
	for l in _ledge_s:
		if s >= float(l[0]) and s <= float(l[1]):
			return true
	return false


func _road_base(_r: Route, s: float, p: Vector2) -> float:
	# The trail climbs steadily with the spiral: the cone's own height at its radius, without the spurs.
	var r: float = p.length()
	var h: float = SUMMIT_Y - maxf(0.0, r - TOP_R) * SLOPE
	return lerpf(_natural(p.x, p.y), h, 0.6) + GROUND_UNDER + (_gorge(p.x, p.y) * 0.6)


func _sections(r: Route) -> Array:
	var cuts: Array = []
	for b in _bridge_s:
		cuts.append([float(b[0]), float(b[1]), K_PLANKS])
	for l in _ledge_s:
		cuts.append([float(l[0]), float(l[1]), K_PLANKS])
	cuts.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
	var out: Array = []
	var s := 0.0
	for c in cuts:
		if float(c[0]) > s:
			out.append([s, float(c[0]), K_DIRT, r.half])
		out.append([float(c[0]), float(c[1]), K_PLANKS, r.half])
		s = float(c[1])
	out.append([s, r.length, K_DIRT, r.half])
	return out


## The mountain is on the right of travel all the way (the trail winds clockwise as seen from above): on the plank
## walks the ground is cut away under the deck's valley side.
func _grade_params(r: Route, s: float) -> Array:
	if _on_ledge(s):
		return [0.5, r.half + 2.0, 1.6, 2.6]
	return [r.half + 2.0, r.half + 2.5, cut_slope, fill_slope]


# ======================================================================================
#  What grows where
# ======================================================================================

func _grove_w(x: float, z: float) -> float:
	var r: float = Vector2(x, z).length()
	# Mountain cherries in patches up to the cloud, a few above it.
	var band: float = smoothstep(FOOT_R + 60.0, FOOT_R - 80.0, r) * (1.0 - smoothstep(330.0, 420.0, 800.0 - r))
	return band * smoothstep(0.1, 0.4, n_wood.get_noise_2d(x * 1.4, z * 1.4)) * 0.8


func _forest_w(x: float, z: float) -> float:
	var r: float = Vector2(x, z).length()
	# Cedar forest from the foot to above the cloud, thinning to rock and scrub toward the summit.
	return clampf(smoothstep(190.0, 330.0, r) * (0.75 + 0.4 * n_wood.get_noise_2d(x, z)), 0.0, 1.0)


func _masks(_i: int, x: float, z: float, nrm_y: float, road_d: float) -> Color:
	var off: float = smoothstep(road_half + 3.0, road_half + 12.0, road_d)
	var r: float = Vector2(x, z).length()
	var rock: float = 1.0 - smoothstep(0.66, 0.80, nrm_y)
	# Bare rock and scree toward the top.
	rock = maxf(rock, smoothstep(560.0, 260.0, r) * smoothstep(-0.25, 0.2, n_hill.get_noise_2d(x * 1.7, z * 1.7) + 0.5 * n_fine.get_noise_2d(x, z)))
	var grove: float = _grove_w(x, z)
	var forest: float = _forest_w(x, z) * (1.0 - grove)
	var bare: float = (1.0 - smoothstep(TOP_R - 6.0, TOP_R + 10.0, r)) * 0.9
	return Color(rock * (1.0 - bare), bare, grove * off * (1.0 - rock), forest * off * (1.0 - rock))


func _tree_pick(x: float, z: float, roll: float, rng: RandomNumberGenerator) -> Array:
	var r: float = Vector2(x, z).length()
	if r < TOP_R + 20.0 or r > FOOT_R + 240.0:
		return []
	var g: float = _grove_w(x, z)
	var f: float = _forest_w(x, z) * (1.0 - g)
	if roll < g * 0.4:
		return ["yamazakura", rng.randf_range(0.9, 1.25), rng.randi_range(0, 1)]
	if roll < g * 0.4 + f * 0.3:
		# Smaller, wind-bent trees toward the summit.
		var sc: float = rng.randf_range(0.8, 1.2) * lerpf(0.55, 1.0, smoothstep(200.0, 420.0, r))
		return ["sugi", sc, rng.randi_range(0, 1)]
	if r < 330.0 and roll < 0.03:
		return ["matsu", rng.randf_range(0.9, 1.3)]
	return []


func _environment() -> Dictionary:
	# Dawn above the cloud: the sun just up in the east, gold on the rock, the sky pale and clear.
	return {
		"sky_top": Color(0.20, 0.36, 0.70), "sky_horizon": Color(0.98, 0.80, 0.60), "haze": Color(0.96, 0.84, 0.70),
		"ground_bottom": Color(0.78, 0.76, 0.76), "sky_curve": 0.55, "haze_strength": 0.8, "haze_height": 0.12,
		"sun_tint": Color(1.0, 0.86, 0.62), "sun_glow": 0.8, "sun_horizon_tint": Color(1.0, 0.72, 0.42), "sun_horizon_glow": 0.6,
		"cloud_lit": Color(1.0, 0.86, 0.72), "cloud_shade": Color(0.60, 0.58, 0.70), "cloud_coverage": 0.16, "cloud_seed": 71.9,
		"ambient": 0.6, "ambient_color": Color(0.86, 0.88, 1.0), "exposure": 1.05, "glow": 0.4, "bloom": 0.08,
		"fog_begin": 30.0, "fog_end": 900.0, "fog_curve": 1.1, "fog_sky": 0.9, "fog_aerial": 0.0, "fog_scatter": 0.3,
		"sun_pitch": -14.0, "sun_yaw": 96.0, "sun_color": Color(1.0, 0.84, 0.62), "sun_energy": 1.35, "shadow_distance": 300.0,
	}


func _ground_params(m: ShaderMaterial) -> void:
	m.set_shader_parameter("petal_amount", 1.3)
	m.set_shader_parameter("moss_amount", 0.9)
	m.set_shader_parameter("rock_tint", Color(0.50, 0.49, 0.48))
	m.set_shader_parameter("canopy_from", 420.0)
	m.set_shader_parameter("grass_a", Color(0.24, 0.32, 0.15))
	m.set_shader_parameter("grass_b", Color(0.38, 0.40, 0.22))


func _road_params(m: ShaderMaterial) -> void:
	m.set_shader_parameter("wetness", 0.35)
	m.set_shader_parameter("plank_tint", Color(0.44, 0.36, 0.28))


# ======================================================================================
#  Gameplay
# ======================================================================================

func _place_gameplay(root: Node3D) -> void:
	var gates: Array = []
	var s: float = 520.0
	var fin: float = lap.length - finish_runout
	while s < fin - 250.0:
		# Never on a bridge or a plank walk's first metres.
		var at: float = s
		while _on_bridge(lap, at, -20.0) or _on_ledge(at):
			at += 20.0
		gates.append(at)
		s = at + 520.0
	_checkpoints(gates)
	var pads: Array = []
	var k := 0
	for q in [260.0, 1150.0, 2050.0, 2900.0]:
		var at2: float = q
		while _on_bridge(lap, at2, -30.0) or _on_ledge(at2) or absf(float(lap.at(at2 + 60.0)["k"])) > 0.012:
			at2 += 15.0
		if at2 < fin - 200.0:
			pads.append(["Boost_%d" % (k + 1), at2, 0.0])
			k += 1
	_boosts(pads)


# ======================================================================================
#  Dressing
# ======================================================================================

func _build_dressing(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_base + 77
	_build_start(root, rng)
	_build_bridges(root)
	_build_ledges(root)
	_build_wayside(root, rng)
	_build_summit(root, rng)
	_build_edges(root)
	_build_cloud(root)


## The start in the forest: a cedar torii over the trail, the pilgrims' lodge, lanterns, spectators.
func _build_start(root: Node3D, rng: RandomNumberGenerator) -> void:
	_build_start_crowd(root, start_s - 60.0, start_s + 70.0, road_half + 2.6, start_s - 8.0, start_s + 8.0, seed_base + 11)
	_logo_flag(root, start_s + 24.0, -(road_half + 15.0))
	var gx: Transform3D = _across(lap, start_s + 110.0)
	gx.origin.y -= 0.05
	_put("start_torii", prop_kit, gx, "torii", [2, 10.6, 7.4], 900.0)
	for side in [-1.0, 1.0]:
		var foot: Vector3 = gx.origin + gx.basis.x * side * 5.3 * PROP_SCALE
		_note_circle(Vector2(foot.x, foot.z), 2.5)
		var lx: Transform3D = _beside(lap, start_s + 98.0, side * (road_half + 3.0))
		_put("start_torii", prop_kit, lx, "stone_lantern", [0, 2.4], 900.0)
	var hx: Transform3D = _beside(lap, start_s - 20.0, road_half + 12.0)
	var gr: Vector2 = _ground_range(Vector2(hx.origin.x, hx.origin.z), 18.0, 14.0, 0.0)
	hx.origin.y = gr.y
	hx.origin -= hx.basis.x * 4.5 * PROP_SCALE
	if _put("lodge", town_kit, hx, "mountain_hut", [LBL], 900.0):
		_note_frame(hx, Vector2(-1.0, -7.5), Vector2(10.0, 1.5), 2.0)
	var mx: Transform3D = _beside(lap, start_s + 40.0, -(road_half + 3.0))
	_put("start_torii", prop_kit, mx, "stone_marker", [1.7, "OKUGAKE", LBL], 900.0)


func _bridge_frame(s0: float) -> Transform3D:
	return _facing(-lap.fw(s0), lap.pt(s0))


## The gorge's two bridges: a suspension bridge low down, a timber trestle near its head; their sides solid.
func _build_bridges(root: Node3D) -> void:
	var body: StaticBody3D = _body(root, "GorgeRailsBody")
	for i in range(_bridge_s.size()):
		var s0: float = _bridge_s[i][0]
		var s1: float = _bridge_s[i][1]
		var o: Vector3 = lap.pt(s0)
		var span: float = s1 - s0
		var deck := func(t: float) -> float: return lap.y(s0 + t) - o.y
		var ground := func(x: float, t: float) -> float:
			var p: Vector3 = lap.pt(s0 + t) + lap.rt(s0 + t) * -x
			return _ground_at(p.x, p.z) - o.y
		var fn: String = "suspension_bridge" if i == 0 else "road_bridge"
		var args: Array = [span, road_half, deck, ground] if i == 0 else [span, road_half, deck, ground, 0]
		_add_prop_game("gorge_span_%d" % i, river_kit, _bridge_frame(s0), func(pk: PropKit, kit: Dictionary, _labels: Array) -> void:
			_kit_call(river_kit, fn, [pk, kit] + args), 1500.0)
		for side in [-1.0, 1.0]:
			_edge_boxes(body, lap, s0 - 3.0, s1 + 3.0, side * (road_half + 0.3), 1.7, 0.4)
		print("  bridge %d: %.0fm at %.0fm, %.0fm over the gorge" % [i, span, s0, lap.y((s0 + s1) * 0.5) - _ground_at(lap.pt((s0 + s1) * 0.5).x, lap.pt((s0 + s1) * 0.5).z)])


## The plank walks: joists, struts and chains from the kit; a kerb and the chain solid on the valley side.
func _build_ledges(root: Node3D) -> void:
	var body: StaticBody3D = _body(root, "LedgeChainsBody")
	var ground := func(x: float, z: float) -> float: return _ground_at(x, z)
	for i in range(_ledge_s.size()):
		var s0: float = _ledge_s[i][0]
		var s1: float = _ledge_s[i][1]
		var pts := PackedVector3Array()
		var rights := PackedVector3Array()
		var s: float = s0
		while s <= s1:
			pts.append(lap.pt(s))
			rights.append(lap.rt(s))
			s += 2.0
		_add_prop_game("plank_walk_%d" % i, river_kit, Transform3D.IDENTITY, func(pk: PropKit, kit: Dictionary, _labels: Array) -> void:
			_kit_call(river_kit, "ledge_walk", [pk, kit, pts, rights, road_half, -1.0, ground]), 1200.0)
		_edge_boxes(body, lap, s0 - 2.0, s1 + 2.0, -(road_half + 0.3), 1.5, 0.4)


## Things along the way: statues, way-stones, cairns above the trees, small torii, a shrine at the cloud's edge.
func _build_wayside(root: Node3D, rng: RandomNumberGenerator) -> void:
	var s: float = 330.0
	var k := 0
	var fin: float = lap.length - finish_runout
	while s < fin - 120.0:
		if not _on_bridge(lap, s, -25.0) and not _on_ledge(s):
			var y: float = lap.y(s)
			var xf: Transform3D = _beside(lap, s, road_half + 3.4)
			var kind: int = k % 5
			if y > 190.0:
				_put(_cell_key("wayside", xf.origin), prop_kit, xf, "cairn", [rng, rng.randf_range(0.9, 1.5)], 400.0)
			elif kind == 0:
				_put(_cell_key("wayside", xf.origin), prop_kit, xf, "jizo_row", [rng.randi_range(3, 6), rng], 400.0)
			elif kind == 1:
				_put(_cell_key("wayside", xf.origin), prop_kit, xf, "stone_marker", [1.5, ["ICHI NO NABIKI", "NI NO NABIKI", "SAN NO NABIKI", "YON NO NABIKI"][(k / 5) % 4], LBL], 400.0)
			elif kind == 2:
				_put(_cell_key("wayside", xf.origin), prop_kit, xf, "stone_lantern", [0], 400.0)
			elif kind == 3:
				_put(_cell_key("wayside", xf.origin), prop_kit, xf, "hokora", [], 400.0)
			else:
				# A small torii over the trail.
				var tx: Transform3D = _across(lap, s)
				tx.origin.y -= 0.05
				_put(_cell_key("torii", tx.origin), prop_kit, tx, "torii", [0 if k % 2 == 0 else 2, 10.4, 7.2], 700.0)
				for side in [-1.0, 1.0]:
					var foot: Vector3 = tx.origin + tx.basis.x * side * 5.2 * PROP_SCALE
					_note_circle(Vector2(foot.x, foot.z), 2.5)
			_note_circle(Vector2(xf.origin.x, xf.origin.z), 2.5)
		s += rng.randf_range(150.0, 210.0)
		k += 1


## The summit: the shrine on its rock, a torii before it, the finish under it; a few pilgrims.
func _build_summit(root: Node3D, rng: RandomNumberGenerator) -> void:
	var fin: float = lap.length - finish_runout
	var end: Vector3 = lap.pt(lap.length)
	var fwd: Vector3 = lap.fw(lap.length)
	var at: Vector3 = end + fwd * 16.0
	at.y = _ground_at(at.x, at.z)
	var sx: Transform3D = _facing(-fwd, at)
	_put("summit", prop_kit, sx, "summit_shrine", [LBL, "SANJO"], 1500.0)
	_note_circle(Vector2(at.x, at.z), 8.0)
	var body: StaticBody3D = _body(root, "SummitStopBody")
	_box_shape(body, Transform3D(sx.basis, at + Vector3(0, 2.0, 0)), Vector3(40.0, 5.0, 2.0))
	var tx: Transform3D = _across(lap, fin - 40.0)
	tx.origin.y -= 0.05
	_put("summit", prop_kit, tx, "torii", [1, 10.4, 7.2], 1500.0)
	for i in range(10):
		var a: float = rng.randf() * TAU
		var p: Vector3 = at + Vector3(cos(a), 0, sin(a)) * rng.randf_range(10.0, 26.0)
		if _route_dist(p.x, p.z) < road_half + 3.0:
			continue
		p.y = _ground_at(p.x, p.z)
		_person(p, at - p, rng.randf_range(0.9, 1.05))
		_put("summit", prop_kit, Transform3D(Basis(), p + Vector3(2.0, 0, 1.0)), "cairn", [rng, 0.8], 600.0)


## Chain fences along the valley side wherever the ground falls away (the same test as the guardrails'), solid.
func _build_edges(root: Node3D) -> void:
	var skip: Array = []
	for l in _ledge_s:
		skip.append([float(l[0]) - 6.0, float(l[1]) + 6.0])
	var body: StaticBody3D = _body(root, "TrailChainsBody")
	var s: float = 150.0
	var run0 := -1.0
	var n := 0
	while s < lap.length - finish_runout:
		var bad := false
		if not _on_bridge(lap, s, -6.0):
			var p: Vector3 = lap.pt(s) - lap.rt(s) * (road_half + 9.0)
			bad = lap.y(s) - _ground_at(p.x, p.z) > 3.2
			for sk in skip:
				if s > float(sk[0]) and s < float(sk[1]):
					bad = false
		if bad and run0 < 0.0:
			run0 = s
		elif not bad and run0 >= 0.0:
			if s - run0 > 14.0:
				var k: float = run0
				while k < s - 0.5:
					var kb: float = minf(k + 9.0, s)
					var a: Vector3 = lap.pt(k) - lap.rt(k) * (road_half + 0.9)
					var b: Vector3 = lap.pt(kb) - lap.rt(kb) * (road_half + 0.9)
					_put_world("chains", a, prop_kit, "chain_fence", [_life(a), _life(b)], 500.0)
					k = kb
					n += 1
				_edge_boxes(body, lap, run0, s, -(road_half + 0.9), 1.3, 0.4)
			run0 = -1.0
		s += 4.0
	print("  chain fences: %d pieces" % n)


## The cloud: the sea of it below the upper mountain, the script that closes the fog in by the camera's height, and
## wisps blowing across the open trail above it.
func _build_cloud(root: Node3D) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://cloud_sea.gdshader")
	var plane := PlaneMesh.new()
	plane.size = Vector2(12000.0, 12000.0)
	plane.subdivide_width = 8
	plane.subdivide_depth = 8
	plane.material = _save_res(mat, "cloud_sea_material")
	var sea := MeshInstance3D.new()
	sea.name = "CloudSea"
	sea.mesh = plane
	sea.position = Vector3(0, CLOUD_HIGH - 6.0, 0)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(sea)
	var cl := Node.new()
	cl.name = "CloudLayer"
	cl.set_script(load("res://CloudLayer.gd"))
	cl.set("band_low", CLOUD_LOW)
	cl.set("band_high", CLOUD_HIGH)
	root.add_child(cl)
	var pg := Node3D.new()
	pg.name = "PetalGusts"
	pg.set_script(load("res://PetalGusts.gd"))
	pg.set("mist", true)
	pg.set("falling", 0)
	pg.set("push_accel", 12.0)
	var spots: Array = []
	var s: float = 0.0
	var k := 0
	while s < lap.length - 150.0:
		if lap.y(s) > CLOUD_HIGH + 25.0 and not _on_ledge(s) and not _on_bridge(lap, s, -10.0):
			# The wind comes up the mountain: from the valley side across the trail.
			spots.append([lap.pt(s), lap.rt(s), 24.0, 15.0 + float(k % 3) * 3.0, float(k) * 4.1])
			s += 230.0
			k += 1
		else:
			s += 20.0
	pg.set("spots", spots)
	root.add_child(pg)
	print("  %d gust places above the cloud" % spots.size())
