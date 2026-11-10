# regenerate_monzenmachi.gd
#
# Builds levels/MonzenmachiLevel.tscn - Monzenmachi (the town before the temple gate), the third stage of the
# Miyoshino GP: a tight street race at dusk through a temple town on a ridge, its paper lanterns lit. The lap starts on
# the shop street heading east, runs under strings of lanterns and through the temple's great gate (the Niomon),
# climbs the stone steps onto the precinct, turns before the main hall and passes the pagoda, leaves down the back
# street's slope, swings through a chicane in the bamboo grove (a walled alley runs straight on: the shortcut) and
# comes back round the town's west end.
#
# Everything shared with the other Miyoshino stages is MiyoshinoStage.gd: read its header first. Here: the ridge, the
# course, the town's houses along the streets, the precinct, the lights.
extends "res://MiyoshinoStage.gd"

const MK = preload("res://MiyoshinoKit.gd")

const MAIN_Z := 60.0
const BACK_Z := -150.0
## The great gate across the shop street, the steps' foot and head, the precinct's level ground.
const GATE_X := 105.0
const STEPS_X := Vector2(180.0, 232.0)
const STEPS_RISE := 8.0
const TOWN_RISE := 7.0
const PRECINCT_RECT := [236.0, -196.0, 480.0, 130.0]
const HALL_AT := Vector2(428.0, 60.0)
const PAGODA_AT := Vector2(402.0, -78.0)
const ALLEY := [Vector2(150.0, BACK_Z), Vector2(-150.0, BACK_Z)]
const LAMP_WARM := Color(1.0, 0.72, 0.42)

var s_gate := 0.0
var s_steps0 := 0.0
var s_steps1 := 0.0
var s_prec1 := 0.0
var s_chic0 := 0.0
var s_chic1 := 0.0
var _raw_route: Route
var _lights: Node3D
var _n_lights := 0


func _configure() -> void:
	level_name = "MonzenmachiLevel"
	level_path = "res://levels/MonzenmachiLevel.tscn"
	stem = "monzen"
	title = "Monzenmachi"
	seed_base = 7500
	road_half = 7.0
	max_grade = 0.17
	smooth_half = 8
	MK.night = true
	MK.glow_energy = 2.8
	corners = [
		[Vector2(-470.0, MAIN_Z), 45.0],    # onto the shop street, east
		[Vector2(330.0, MAIN_Z), 40.0],     # before the main hall: left, north across the precinct
		[Vector2(330.0, BACK_Z), 45.0],     # left onto the back street, west and down
		[Vector2(120.0, BACK_Z), 60.0],     # the chicane through the bamboo
		[Vector2(60.0, -205.0), 35.0],
		[Vector2(-60.0, -205.0), 35.0],
		[Vector2(-120.0, BACK_Z), 60.0],
		[Vector2(-470.0, BACK_Z), 45.0],    # the town's west end: left, south
	]
	finish_at = Vector2(-250.0, MAIN_Z)
	fine_x = Vector2(-640.0, 640.0)
	fine_z = Vector2(-440.0, 340.0)
	tree_step = 10.5
	tree_margin = 260.0
	tree_clear = 15.0


# ======================================================================================
#  The ridge
# ======================================================================================

func _town_y(x: float) -> float:
	return TOWN_RISE * smoothstep(-460.0, 170.0, x) + STEPS_RISE * smoothstep(STEPS_X.x, STEPS_X.y, x)


func _natural(x: float, z: float) -> float:
	var h: float = _town_y(x)
	# The ridge's flanks fall away north and south of the town; the temple's hill stands a little longer.
	var mid: float = (MAIN_Z + BACK_Z) * 0.5
	var half: float = 190.0 + 40.0 * smoothstep(200.0, 300.0, x) + 22.0 * n_land.get_noise_2d(x, 0.0)
	var out: float = maxf(0.0, absf(z - mid) - half)
	h -= out * out / (out + 60.0) * 0.42
	# Its ends: down to the west, a wooded hill behind the temple to the east.
	h -= maxf(0.0, -x - 540.0) * 0.12
	h += smoothstep(470.0, 620.0, x) * 26.0 * (1.0 - smoothstep(120.0, 320.0, absf(z - mid)))
	h += smoothstep(0.0, 80.0, out) * 5.0 * n_hill.get_noise_2d(x * 0.7, z * 0.7)
	var far: float = Vector2(x, z).length()
	h += smoothstep(900.0, 3800.0, far) * (150.0 + 260.0 * absf(n_ridge.get_noise_2d(x, z)))
	h = lerpf(h, TOWN_RISE + STEPS_RISE, _rect_weight(x, z, PRECINCT_RECT, 18.0))
	return h


# ======================================================================================
#  The course
# ======================================================================================

func _init_noise() -> void:
	super._init_noise()
	_raw_route = Route.new()
	_raw_route.build(corners, true)
	s_gate = _raw_route.closest_s(Vector2(GATE_X, MAIN_Z))
	s_steps0 = _raw_route.closest_s(Vector2(STEPS_X.x - 2.0, MAIN_Z))
	s_steps1 = _raw_route.closest_s(Vector2(STEPS_X.y + 2.0, MAIN_Z))
	s_prec1 = _raw_route.closest_s(Vector2(244.0, BACK_Z))
	s_chic0 = _raw_route.closest_s(Vector2(100.0, -168.0))
	s_chic1 = _raw_route.closest_s(Vector2(-100.0, -168.0))


func _road_base(_r: Route, _s: float, p: Vector2) -> float:
	return _natural(p.x, p.y) + GROUND_UNDER


func _plan_routes() -> void:
	var r: Route = _add_route("Alley", [[ALLEY[0], 0.0], [ALLEY[1], 0.0]], 3.8, true, 0.1)
	_report_profile(r)
	shortcuts = [["Alley", 0.5]]


func _sections(r: Route) -> Array:
	if r.name == "Alley":
		return [[46.0, r.length - 46.0, K_STONE, r.half]]
	return [[0.0, s_gate - 14.0, K_STONE, r.half], [s_gate - 14.0, s_gate + 14.0, K_STONE, 6.5], [s_gate + 14.0, s_steps0, K_STONE, r.half],
			[s_steps0, s_steps1, K_STEPS, r.half], [s_steps1, s_prec1, K_PRECINCT, r.half], [s_prec1, s_chic0, K_STONE, r.half],
			[s_chic0, s_chic1, K_DIRT, r.half], [s_chic1, r.length, K_STONE, r.half]]


func _grade_params(r: Route, _s: float) -> Array:
	if r.name == "Alley":
		return [r.half + 1.5, r.half + 1.5, 0.8, 0.8]
	return [r.half + 2.5, r.half + 2.5, cut_slope, fill_slope]


# ======================================================================================
#  What grows where
# ======================================================================================

func _in_town(x: float, z: float) -> bool:
	return x > -520.0 and x < 250.0 and z > BACK_Z - 34.0 and z < MAIN_Z + 34.0


func _in_bamboo(x: float, z: float) -> bool:
	return absf(x) < 130.0 and z < BACK_Z - 4.0 and z > -250.0


func _grove_w(x: float, z: float) -> float:
	# Cherries in the precinct, in the gardens between the two streets and along the ridge's shoulders.
	var w: float = _rect_weight(x, z, PRECINCT_RECT, 10.0) * 0.7
	w = maxf(w, _rect_weight(x, z, [-440.0, BACK_Z + 34.0, 230.0, MAIN_Z - 34.0], 10.0) * 0.6)
	var mid: float = (MAIN_Z + BACK_Z) * 0.5
	w = maxf(w, smoothstep(140.0, 165.0, absf(z - mid)) * (1.0 - smoothstep(190.0, 230.0, absf(z - mid))) * 0.7)
	return w * (0.5 + 0.6 * smoothstep(-0.25, 0.3, n_wood.get_noise_2d(x * 1.6, z * 1.6)))


func _forest_w(x: float, z: float) -> float:
	var mid: float = (MAIN_Z + BACK_Z) * 0.5
	var w: float = smoothstep(200.0, 250.0, absf(z - mid))
	w = maxf(w, smoothstep(490.0, 540.0, x))
	w = maxf(w, smoothstep(-530.0, -590.0, x))
	return clampf(w, 0.0, 1.0)


func _masks(_i: int, x: float, z: float, nrm_y: float, road_d: float) -> Color:
	var off: float = smoothstep(road_half + 3.0, road_half + 12.0, road_d)
	var rock: float = 1.0 - smoothstep(0.60, 0.76, nrm_y)
	# The precinct's gravel, the streets' verges between the paving and the houses.
	var bare: float = _rect_weight(x, z, PRECINCT_RECT, 6.0)
	if _in_town(x, z):
		bare = maxf(bare, 1.0 - smoothstep(road_half + 8.0, road_half + 16.0, road_d))
	var grove: float = _grove_w(x, z) * (1.0 - bare)
	var forest: float = _forest_w(x, z) * (1.0 - grove) * (1.0 - bare)
	return Color(rock * (1.0 - bare), bare, grove * off, forest * off)


func _tree_pick(x: float, z: float, roll: float, rng: RandomNumberGenerator) -> Array:
	if _in_bamboo(x, z):
		return ["take", rng.randf_range(0.9, 1.2)] if roll < 0.55 else []
	var g: float = _grove_w(x, z)
	var f: float = _forest_w(x, z) * (1.0 - g)
	f *= lerpf(1.0, 0.3, smoothstep(560.0, 760.0, Vector2(x, z).length()))
	if roll < g * 0.42:
		var r: float = rng.randf()
		if _in_rect(x, z, PRECINCT_RECT, 0.0):
			if r < 0.3:
				return ["shidare", rng.randf_range(1.0, 1.25)]
			if r < 0.4:
				return ["matsu", rng.randf_range(0.9, 1.15)]
		if r < 0.12:
			return ["momiji", rng.randf_range(0.9, 1.2)]
		return ["sakura", rng.randf_range(0.85, 1.2), rng.randi_range(0, 1)]
	if roll < g * 0.42 + f * 0.36:
		return ["sugi", rng.randf_range(0.8, 1.2), rng.randi_range(0, 1)]
	return []


func _environment() -> Dictionary:
	# Dusk: the sun just down in the west-south-west, a deep blue overhead, an orange band along the horizon.
	return {
		"sky_top": Color(0.04, 0.07, 0.22), "sky_horizon": Color(0.66, 0.38, 0.34), "haze": Color(0.36, 0.28, 0.40),
		"ground_bottom": Color(0.10, 0.10, 0.14), "sky_curve": 0.85, "haze_strength": 0.4, "haze_height": 0.14,
		"sun_tint": Color(1.0, 0.62, 0.36), "sun_glow": 0.7, "sun_horizon_tint": Color(1.0, 0.50, 0.26), "sun_horizon_glow": 0.45,
		"cloud_lit": Color(0.98, 0.56, 0.44), "cloud_shade": Color(0.26, 0.22, 0.36), "cloud_coverage": 0.36, "cloud_seed": 51.3,
		"ambient": 0.7, "ambient_color": Color(0.52, 0.58, 0.95), "exposure": 1.0, "glow": 0.55, "bloom": 0.12,
		"fog_begin": 120.0, "fog_end": 2600.0, "fog_curve": 1.2, "fog_sky": 0.1, "fog_aerial": 0.5, "fog_scatter": 0.3,
		"sun_pitch": -7.0, "sun_yaw": -62.0, "sun_color": Color(1.0, 0.56, 0.36), "sun_energy": 0.42, "shadow_distance": 260.0,
	}


func _ground_params(m: ShaderMaterial) -> void:
	m.set_shader_parameter("petal_amount", 1.2)
	m.set_shader_parameter("moss_amount", 0.6)
	m.set_shader_parameter("earth_tint", Color(0.58, 0.54, 0.48))


# ======================================================================================
#  Gameplay
# ======================================================================================

func _place_gameplay(root: Node3D) -> void:
	var fin: float = _finish_s()
	_checkpoints([
		_closest_s(Vector2(10.0, MAIN_Z)),       # the shop street, before the gate
		_closest_s(Vector2(330.0, -55.0)),       # the precinct, by the pagoda
		_closest_s(Vector2(-260.0, BACK_Z)),     # the back street (past where the alley rejoins)
		_closest_s(Vector2(-470.0, -45.0)),      # the west end
	])
	_boosts([
		["Boost_Shops", fin + 110.0, 0.0],
		["Boost_Back", _closest_s(Vector2(-200.0, BACK_Z)), 0.0],
		["Boost_Alley", 150.0, 0.0, "Alley"],
	])


# ======================================================================================
#  Dressing
# ======================================================================================

func _lamp(at: Vector3, col: Color, energy: float, reach: float) -> void:
	var l := OmniLight3D.new()
	l.name = "Lamp_%d" % _n_lights
	l.position = at
	l.light_color = col
	l.light_energy = energy
	l.omni_range = reach
	l.omni_attenuation = 1.2
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 150.0
	l.distance_fade_length = 40.0
	l.set_meta(&"no_shadow", true)
	_lights.add_child(l)
	_n_lights += 1


func _build_dressing(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_base + 77
	_lights = Node3D.new()
	_lights.name = "Lanterns"
	root.add_child(_lights)
	var fin: float = _finish_s()
	_build_start_crowd(root, fin - 80.0, fin + 60.0, road_half + 1.6, fin - 8.0, fin + 8.0, seed_base + 11)
	_build_gate(root)
	_build_steps(root)
	_build_precinct(root, rng)
	_build_streets(root, rng, fin)
	_build_alley(root, rng)
	var pg := Node3D.new()
	pg.name = "PetalGusts"
	pg.set_script(load("res://PetalGusts.gd"))
	pg.set("falling", 220)
	root.add_child(pg)
	print("  %d lights" % _n_lights)


## The Niomon across the shop street: the lap drives through its middle bay.
func _build_gate(root: Node3D) -> void:
	var xf: Transform3D = _across(lap, s_gate)
	xf.origin.y -= 0.06
	_put("niomon", town_kit, xf, "great_gate", [LBL], 1600.0)
	var size: Vector3 = _kit_value(town_kit, "great_gate_size", [], Vector3(17.0, 17.0, 9.0))
	_note_frame(xf, Vector2(-size.x * 0.5, -size.z * 0.5), Vector2(size.x * 0.5, size.z * 0.5), 3.0)
	# Light under the gate and on its face, guardian dogs and tall lanterns before it.
	_lamp(xf.origin + Vector3(0, 8.5, 0), Color(1.0, 0.55, 0.3), 3.0, 26.0)
	_lamp(xf.origin + xf.basis.z * 16.0 + Vector3(0, 6.0, 0), LAMP_WARM, 2.6, 30.0)
	for side in [-1.0, 1.0]:
		var kx: Transform3D = _beside(lap, s_gate - 17.0, side * (road_half + 4.0))
		kx = _facing(-lap.fw(s_gate), kx.origin)
		_put("niomon_court", prop_kit, kx, "komainu", [side < 0.0], 700.0)
		var lx: Transform3D = _beside(lap, s_gate - 23.0, side * (road_half + 3.2))
		_put("niomon_court", prop_kit, lx, "stone_lantern", [0, 2.8], 700.0)
		_note_circle(Vector2(kx.origin.x, kx.origin.z), 3.0)
	# The temple's wall either side of the gate, across the ridge.
	var across: Vector3 = xf.basis.x
	for side in [-1.0, 1.0]:
		var a: Vector3 = xf.origin + across * side * (size.x * 0.5 * PROP_SCALE - 0.5)
		var b: Vector3 = xf.origin + across * side * 62.0
		_wall_run(a, b, "niomon_wall")


## A run of temple wall between two points, in pieces that follow the ground.
func _wall_run(a: Vector3, b: Vector3, key: String) -> void:
	var n: int = maxi(1, int(a.distance_to(b) / 10.0))
	for i in range(n):
		var p: Vector3 = a.lerp(b, float(i) / float(n))
		var q: Vector3 = a.lerp(b, float(i + 1) / float(n))
		p.y = _ground_at(p.x, p.z)
		q.y = _ground_at(q.x, q.z)
		_put_world(key, p, town_kit, "temple_wall", [_life(p), _life(q)], 900.0)
	_note_rect(Vector2((a.x + b.x) * 0.5, (a.z + b.z) * 0.5), a.distance_to(b), 3.0, atan2(-(b.z - a.z), b.x - a.x), 1.5)


## The flight of stone steps up to the precinct: treads whose nosings lie on the road's line (the collision is that
## line, a ramp), kerb walls either side with lanterns up them.
func _build_steps(root: Node3D) -> void:
	var pk: PropKit = MK.new_kit(1.0)
	var kit := {}
	var run := 1.3
	var s: float = s_steps0
	var n := 0
	var w: float = road_half + 0.3
	while s < s_steps1 - 0.2:
		var sb: float = minf(s + run, s_steps1)
		var p: Vector3 = lap.pt(s)
		var fwd: Vector3 = lap.fw(s)
		var right: Vector3 = lap.rt(s)
		# The tread's top is the road's height at its front edge (the nosing); it reaches back under the next one.
		var top: float = lap.y(s)
		var basis := Basis(right, Vector3.UP, -fwd)
		var c: Vector3 = Vector3(p.x, top - 0.6, p.z) + fwd * (sb - s + 0.25) * 0.5
		pk.box(kit, "ishi", Transform3D(basis, c), Vector3(w * 2.0, 1.2, sb - s + 0.25), MK.GRANITE.lerp(MK.GRANITE_MOSSY, 0.25 if n % 3 == 0 else 0.1), 1.0)
		s = sb
		n += 1
	# Kerb walls along both sides, stepping up with the flight.
	var body: StaticBody3D = _body(root, "StepsKerbBody")
	for side in [-1.0, 1.0]:
		var k: float = s_steps0 - 3.0
		while k < s_steps1 + 3.0:
			var kb: float = minf(k + 5.2, s_steps1 + 3.0)
			var a: Vector3 = lap.pt(k) + lap.rt(k) * side * (w + 0.55)
			var b: Vector3 = lap.pt(kb) + lap.rt(kb) * side * (w + 0.55)
			var top2: float = maxf(a.y, b.y) + 1.1
			var mid: Vector3 = (a + b) * 0.5
			var fwd2: Vector3 = (b - a).normalized()
			fwd2.y = 0.0
			var bs := Basis(Vector3.UP.cross(fwd2.normalized()).normalized(), Vector3.UP, fwd2.normalized())
			pk.box(kit, "ishi", Transform3D(bs, Vector3(mid.x, top2 - 2.0, mid.z)), Vector3(0.9, 4.0, a.distance_to(b) + 0.05), MK.GRANITE, 1.0)
			_box_shape(body, Transform3D(bs, Vector3(mid.x, top2 - 2.0, mid.z)), Vector3(0.9, 4.0, a.distance_to(b) + 0.05))
			var lx := Transform3D(Basis(), Vector3(mid.x, top2, mid.z) + lap.rt(k) * side * 0.0)
			_put("steps_lanterns", prop_kit, lx, "stone_lantern", [0, 1.9], 700.0)
			_lamp(Vector3(mid.x, top2 + 2.4, mid.z), LAMP_WARM, 1.6, 16.0) if int(k) % 2 == 0 else null
			k = kb
	var mi := MeshInstance3D.new()
	mi.name = "TempleSteps"
	mi.mesh = _save_res(MK.commit(pk, kit), "temple_steps", stem + "prop_")
	mi.set_meta(&"skip_dressing_colliders", true)
	root.add_child(mi)
	print("  the steps: %d treads, %.1fm up over %.0fm" % [n, lap.y(s_steps1) - lap.y(s_steps0), s_steps1 - s_steps0])


## The precinct: the main hall facing the steps, the pagoda, the bell tower, lanterns along the way, the wall round it.
func _build_precinct(root: Node3D, rng: RandomNumberGenerator) -> void:
	var py: float = TOWN_RISE + STEPS_RISE
	var hx: Transform3D = _facing(Vector3(-1, 0, 0), Vector3(HALL_AT.x, py, HALL_AT.y))
	_put("hondo", town_kit, hx, "main_hall", [LBL], 1600.0)
	_note_rect(HALL_AT, 34.0, 44.0, 0.0, 4.0)
	_lamp(Vector3(HALL_AT.x - 26.0, py + 7.0, HALL_AT.y), LAMP_WARM, 3.2, 36.0)
	_lamp(Vector3(HALL_AT.x - 14.0, py + 5.0, HALL_AT.y - 16.0), Color(1.0, 0.6, 0.34), 2.0, 22.0)
	_lamp(Vector3(HALL_AT.x - 14.0, py + 5.0, HALL_AT.y + 16.0), Color(1.0, 0.6, 0.34), 2.0, 22.0)
	var px := Transform3D(Basis(Vector3.UP, 0.0), Vector3(PAGODA_AT.x, py, PAGODA_AT.y))
	_put("pagoda", town_kit, px, "pagoda", [3], 1800.0)
	_note_circle(PAGODA_AT, 9.0)
	_lamp(Vector3(PAGODA_AT.x - 12.0, py + 6.0, PAGODA_AT.y + 6.0), Color(1.0, 0.66, 0.4), 3.0, 34.0)
	_lamp(Vector3(PAGODA_AT.x - 8.0, py + 20.0, PAGODA_AT.y), Color(1.0, 0.6, 0.36), 2.4, 30.0)
	var bx := Transform3D(Basis(), Vector3(282.0, py, -62.0))
	_put("precinct", town_kit, bx, "bell_tower", [], 1000.0)
	_note_circle(Vector2(282.0, -62.0), 6.0)
	_lamp(Vector3(282.0, py + 5.0, -54.0), LAMP_WARM, 1.8, 18.0)
	var cx := _facing(Vector3(1, 0, 0), Vector3(288.0, py, 104.0))
	_put("precinct", prop_kit, cx, "chozuya", [], 1000.0)
	_note_circle(Vector2(288.0, 104.0), 5.0)
	var ex := _facing(Vector3(-1, 0, 0), Vector3(392.0, py, 118.0))
	_put("precinct", prop_kit, ex, "ema_rack", [], 1000.0)
	var sx := _facing(Vector3(-1, 0, 0), Vector3(410.0, py, 12.0))
	_put("precinct", prop_kit, sx, "sake_barrels", [5, 3], 1000.0)
	# Stone lanterns in pairs along the lap across the precinct, every third one a real light.
	var s: float = s_steps1 + 8.0
	var k := 0
	while s < s_prec1 - 8.0:
		for side in [-1.0, 1.0]:
			var lx: Transform3D = _beside(lap, s, side * (road_half + 2.6))
			if _occupied(lx.origin.x, lx.origin.z):
				continue
			_put(_cell_key("precinct_lanterns", lx.origin, 60.0), prop_kit, lx, "stone_lantern", [0, 2.3], 800.0)
			if k % 2 == 0 and side > 0.0 or k % 2 == 1 and side < 0.0:
				_lamp(lx.origin + Vector3(0, 3.2, 0), LAMP_WARM, 1.7, 17.0)
		s += 15.0
		k += 1
	# The wall round the precinct (open where the lap comes and goes), weeping cherries inside.
	var r: Array = PRECINCT_RECT
	var y: float = py
	_wall_run(Vector3(r[0], y, float(r[3]) - 4.0), Vector3(float(r[2]) - 4.0, y, float(r[3]) - 4.0), "precinct_wall")
	_wall_run(Vector3(float(r[2]) - 4.0, y, float(r[3]) - 4.0), Vector3(float(r[2]) - 4.0, y, float(r[1]) + 4.0), "precinct_wall")
	_wall_run(Vector3(float(r[2]) - 4.0, y, float(r[1]) + 4.0), Vector3(float(r[0]) + 30.0, y, float(r[1]) + 4.0), "precinct_wall")
	for q in [Vector2(300.0, 20.0), Vector2(366.0, -20.0), Vector2(372.0, 104.0), Vector2(296.0, -120.0), Vector2(440.0, -150.0), Vector2(366.0, -160.0)]:
		extra_trees.append(["shidare", q.x, q.y, rng.randf_range(1.05, 1.3), 0])
		_note_circle(q, 3.0)
	# Worshippers and visitors.
	for i in range(26):
		var p := Vector2(rng.randf_range(250.0, 410.0), rng.randf_range(-170.0, 118.0))
		if _occupied(p.x, p.y) or _route_dist(p.x, p.y) < road_half + 2.5:
			continue
		_person(Vector3(p.x, py, p.y), Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)), rng.randf_range(0.85, 1.05))


## The two streets: townhouses along both sides, lantern strings across the shop street, wooden lantern posts along
## the back street, utility poles, banners, drinks machines, people under the eaves.
func _build_streets(root: Node3D, rng: RandomNumberGenerator, fin: float) -> void:
	var runs: Array = [
		[4.0, s_gate - 30.0, true],
		[s_gate + 26.0, s_steps0 - 8.0, true],
		[_closest_s(Vector2(200.0, BACK_Z)), _closest_s(Vector2(150.0, BACK_Z)), false],
		[_closest_s(Vector2(-150.0, BACK_Z)), _closest_s(Vector2(-430.0, BACK_Z)), false],
		[_closest_s(Vector2(-470.0, -110.0)), _closest_s(Vector2(-470.0, 20.0)), false],
	]
	var houses := 0
	for run in runs:
		var shops: bool = run[2]
		for side in [-1.0, 1.0]:
			var s: float = float(run[0]) + rng.randf_range(0.0, 3.0)
			var k: int = rng.randi_range(0, 9)
			while s < float(run[1]):
				var variant: int = ([1, 0, 4, 1, 3, 2, 1, 0, 5, 3] if shops else [0, 0, 5, 0, 3, 0, 2, 0, 0, 1])[k % 10]
				var def: Vector3 = _kit_value(town_kit, "machiya_default", [variant], Vector3(7.2, 9.0, 2.0))
				var w: float = def.x * PROP_SCALE
				var ext: float = float(_kit_value(town_kit, "machiya_extent", [variant], 1.5)) * PROP_SCALE
				if s + w > float(run[1]) + 4.0:
					break
				# The house's own x runs to its right as seen from the street: start it at the far or near end by side.
				var s_origin: float = s + w if side < 0.0 else s
				var sp: Dictionary = lap.spot(s_origin, side * (road_half + 1.3 + ext), 0.0)
				var pos: Vector3 = sp["pos"]
				var face: Vector3 = -(sp["right"] as Vector3) * side
				var mid: Vector3 = lap.pt(s + w * 0.5) + lap.rt(s + w * 0.5) * side * (road_half + 1.3 + ext + def.y * PROP_SCALE * 0.5)
				var gr: Vector2 = _ground_range(Vector2(mid.x, mid.z), w, def.y * PROP_SCALE, atan2(lap.fw(s).x, lap.fw(s).z))
				pos.y = gr.y
				var xf: Transform3D = _facing(face, pos)
				if not _occupied(mid.x, mid.z) and _put(_cell_key("town", mid, 60.0), town_kit, xf, "machiya", [def.x, def.y, int(def.z), variant, rng, LBL], 900.0):
					_note_frame(xf, Vector2(-0.3, -def.y - 0.3), Vector2(def.x + 0.3, 1.0), 0.6)
					houses += 1
					# A person or two before a shop.
					if shops and rng.randf() < 0.5 and absf(s - fin) > 70.0:
						var at: Vector3 = lap.pt(s + w * 0.5) + lap.rt(s + w * 0.5) * side * (road_half + 1.6)
						_person(Vector3(at.x, _ground_at(at.x, at.z), at.z), face * -1.0 + lap.fw(s) * rng.randf_range(-0.6, 0.6), rng.randf_range(0.88, 1.05))
				s += w + (rng.randf_range(0.2, 1.2) if shops else rng.randf_range(0.6, 5.0))
				k += 1
	print("  %d townhouses" % houses)
	# Lantern strings across the shop street, each with a light at its middle.
	var s2: float = 8.0
	var k2 := 0
	while s2 < s_steps0 - 6.0:
		if absf(s2 - s_gate) > 22.0:
			var p: Vector3 = lap.pt(s2)
			var right: Vector3 = lap.rt(s2)
			var a: Vector3 = p - right * (road_half + 1.2) + Vector3(0, 9.6, 0)
			var b: Vector3 = p + right * (road_half + 1.2) + Vector3(0, 9.6, 0)
			_put_world("lantern_lights", p, prop_kit, "chochin_string", [_life(a), _life(b), 7, 0.45, [MK.PAPER_RED, MK.PAPER, MK.PAPER_WARM]], 600.0)
			if k2 % 2 == 0:
				_lamp(p + Vector3(0, 7.2, 0), LAMP_WARM if k2 % 4 == 0 else Color(1.0, 0.5, 0.34), 2.3, 24.0)
		s2 += 14.0
		k2 += 1
	# Wooden lantern posts along the back street and the west end, alternate sides, each a light.
	var s3: float = s_prec1 + 10.0
	k2 = 0
	while s3 < lap.length - 30.0:
		if s3 < s_chic0 - 10.0 or s3 > s_chic1 + 10.0:
			var side2: float = 1.0 if k2 % 2 == 0 else -1.0
			var lx: Transform3D = _beside(lap, s3, side2 * (road_half + 0.9))
			_put(_cell_key("andon", lx.origin, 60.0), prop_kit, lx, "wood_lantern_post", [], 500.0)
			_lamp(lx.origin + Vector3(0, 4.4, 0) - lx.basis.z * -1.0, LAMP_WARM, 1.9, 21.0)
		else:
			# The chicane in the bamboo: low stone lanterns on its outside.
			var side3: float = -signf(float(lap.at(s3)["k"])) if absf(float(lap.at(s3)["k"])) > 0.001 else 1.0
			var cx: Transform3D = _beside(lap, s3, side3 * (road_half + 2.2))
			_put(_cell_key("andon", cx.origin, 60.0), prop_kit, cx, "stone_lantern", [1, 2.0], 500.0)
			_lamp(cx.origin + Vector3(0, 2.6, 0), Color(1.0, 0.8, 0.5), 1.5, 16.0)
		s3 += 27.0
		k2 += 1
	# Utility poles with their wires down the back street, banners and drinks machines on the shop street.
	var prev := Vector3.INF
	var s4: float = _closest_s(Vector2(-160.0, BACK_Z))
	k2 = 0
	while s4 < _closest_s(Vector2(-440.0, BACK_Z)):
		var px: Transform3D = _beside(lap, s4, road_half + 0.8)
		_put(_cell_key("poles", px.origin, 60.0), prop_kit, px, "utility_pole", [9.5, k2 % 3], 500.0)
		var top: Vector3 = px.origin + Vector3(0, 9.0 * PROP_SCALE, 0)
		if prev != Vector3.INF:
			_put_world("poles", top, prop_kit, "pole_wires", [_life(prev), _life(top), 0.7, 3], 500.0)
		prev = top
		s4 += 44.0
		k2 += 1
	for ds in [-52.0, -26.0, 26.0, 52.0]:
		for side in [-1.0, 1.0]:
			var nx: Transform3D = _beside(lap, fin + ds, side * (road_half + 0.9))
			_put(_cell_key("banners", nx.origin, 60.0), prop_kit, nx, "nobori", [Color(0.80, 0.16, 0.14)], 420.0)
	var vx: Transform3D = _beside(lap, _closest_s(Vector2(-60.0, MAIN_Z)), road_half + 0.9)
	_put(_cell_key("banners", vx.origin, 60.0), prop_kit, vx, "vending_machine", [0], 300.0)
	_lamp(vx.origin + vx.basis.z * 1.5 + Vector3(0, 2.0, 0), Color(0.8, 0.9, 1.0), 1.2, 9.0)


## The alley: a walled lane straight through the bamboo, its lanterns low on the walls.
func _build_alley(root: Node3D, rng: RandomNumberGenerator) -> void:
	var r: Route = _route_by_name["Alley"]
	for side in [-1.0, 1.0]:
		var s: float = 44.0
		while s < r.length - 44.0:
			var sb: float = minf(s + 10.0, r.length - 44.0)
			var a: Vector3 = r.pt(s) + r.rt(s) * side * (r.half + 0.9)
			var b: Vector3 = r.pt(sb) + r.rt(sb) * side * (r.half + 0.9)
			a.y = _ground_at(a.x, a.z)
			b.y = _ground_at(b.x, b.z)
			_put_world("alley_wall", a, town_kit, "temple_wall", [_life(a), _life(b), 2.0], 600.0)
			s = sb
	var k := 0
	var s2: float = 56.0
	while s2 < r.length - 50.0:
		var p: Vector3 = r.pt(s2) + Vector3(0, 3.6, 0)
		_lamp(p, LAMP_WARM, 1.5, 15.0)
		var lx: Transform3D = _beside(r, s2, (1.0 if k % 2 == 0 else -1.0) * (r.half + 0.1))
		_put("alley_wall", prop_kit, Transform3D(lx.basis, lx.origin + Vector3(0, 3.2, 0)), "chochin", [Vector3.ZERO, 0.3, MK.PAPER_WARM, true], 600.0)
		s2 += 34.0
		k += 1
	_note_rect(Vector2(0.0, BACK_Z), r.length - 80.0, r.half * 2.0 + 5.0, 0.0, 1.0)
