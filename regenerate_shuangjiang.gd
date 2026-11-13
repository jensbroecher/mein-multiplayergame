extends "res://YunhaiStage.gd"
# Builds levels/ShuangjiangLevel.tscn - Shuangjiang (双江, "two rivers"), the Yunhai GP's fourth stage: laps at dawn
# along both banks of the river where the Jialing-like tributary meets it, in morning fog that lifts as the race goes on
# (FogLift.gd), mist lying on the water (river_mist.gdshader). The last of the four ideas offered for the cup's second
# stage, which the user asked for next: the river's banks in the morning fog, two big bridges, dirt and gravel along the
# shore under the towers, a ramp jump over a moored barge, the towers of Tianqiao looming out of the mist.
#
# The lap (game metres, x east, z south; the river along z 0, 410m wide; the tributary along x 700 from the north, 300m
# wide; the peninsula between them, its tip at the confluence):
#   - the start on Binjiang Avenue (滨江大道) on the south bank, heading west past the riverside park;
#   - north over the river on the Jiangxin Bridge (江心大桥), a red through-arch;
#   - down off the peninsula's bluff to the shore road: gravel and mud at the water's edge under the bluff and its towers,
#     a kicker and a 36m jump over a sand barge moored in an inlet;
#   - up a looping ramp near the tip (over the shore road) onto the Shuangjiang Bridge (双江大桥), a suspension bridge,
#     back across the river and down onto the avenue.
# Built on YunhaiStage.gd (the Yunhai GP's base) on the Miyoshino GP's stage base: decks on hammerhead piers, the city.

## Heights along the lap: [plan point on it, height], each clear of where the lap crosses itself (the loop over the shore).
const KNOTS := [
	[Vector2(-200.0, 420.0), 8.5], [Vector2(220.0, 420.0), 8.5], [Vector2(-600.0, 360.0), 9.0], [Vector2(-600.0, 215.0), 22.0],
	[Vector2(-600.0, -200.0), 22.0], [Vector2(-600.0, -290.0), 19.0], [Vector2(-520.0, -340.0), 16.0], [Vector2(-330.0, -340.0), 6.0],
	[Vector2(-260.0, -300.0), 3.4], [Vector2(-150.0, -260.0), 2.6], [Vector2(350.0, -260.0), 2.6], [Vector2(460.0, -345.0), 9.0],
	[Vector2(380.0, -470.0), 20.0], [Vector2(300.0, -400.0), 27.0], [Vector2(300.0, -300.0), 30.0], [Vector2(300.0, -200.0), 32.0],
	[Vector2(300.0, 200.0), 32.0], [Vector2(300.0, 360.0), 13.0],
]
const START_AT := Vector2(0.0, 420.0)
## The river: its banks at |z| RIVER_HALF_W; the tributary along TRIB_X, TRIB_HALF wide each side, north of the river.
const RIVER_HALF_W := 205.0
const TRIB_X := 700.0
const TRIB_HALF := 150.0
## The barge jump on the shore road: the lip, the gap (an inlet in the shore, the barge moored in it).
const JUMP_LIP := Vector2(0.0, -260.0)
const JUMP_GAP := 36.0
const KICK_LEN := 9.0
const KICK_H := 1.6
const INLET := Rect2(3.0, -300.0, 30.0, 100.0)
## The bridges: the arch along x ARCH_X, the suspension bridge along x SUSP_X (its towers at z +-SUSP_TOWER_Z).
const ARCH_X := -600.0
const SUSP_X := 300.0
const SUSP_TOWER_Z := 170.0
const SUSP_TOP := 112.0
## Tianqiao's towers on the peninsula's heights, to loom out of the mist: the Liangjiang towers with their crystal sky
## gallery, and the Yunhai Center.
const CRYSTAL_X := [140.0, 230.0, 320.0, 410.0]
const CRYSTAL_Z := -680.0
const SUPERTALL_AT := Vector2(-180.0, -1180.0)
## The riverside park between the avenue and the river's south bank.
const RIVERSIDE := Rect2(-760.0, 230.0, 1200.0, 168.0)
## Where the bluff behind the shore road turns north (the shore broadening into the confluence's beach under the loop).
const BLUFF_X0 := 170.0
const BLUFF_X1 := 260.0
const BLUFF_RECEDE := 260.0
## The suspension bridge's main cables are anchored on the deck (a self-anchored span) this far from the middle.
const SUSP_END_Z := 272.0

var _a := {}


func _configure() -> void:
	level_name = "ShuangjiangLevel"
	level_path = "res://levels/ShuangjiangLevel.tscn"
	stem = "shuangjiang"
	title = "Shuangjiang"
	seed_base = 8400
	road_half = 7.5
	max_grade = 0.16
	closed = true
	point_to_point = false
	finish_at = START_AT
	corners = [
		[Vector2(-600.0, 420.0), 60.0],
		[Vector2(-600.0, -340.0), 50.0],
		[Vector2(-260.0, -340.0), 35.0],
		[Vector2(-260.0, -260.0), 35.0],
		[Vector2(460.0, -260.0), 80.0],
		[Vector2(460.0, -470.0), 80.0],
		[Vector2(300.0, -470.0), 80.0],
		[Vector2(300.0, 420.0), 60.0],
	]
	fine_x = Vector2(-900.0, 1000.0)
	fine_z = Vector2(-800.0, 700.0)
	fine_step = 5.0
	outer = 6000.0
	tree_step = 9.0
	tree_margin = 30.0
	tree_far_range = 900.0
	tree_clear = 12.0
	collide_margin = 80.0
	pier_style = 1
	grid_origin = Vector2(-11.0, 9.0)
	city_mid = Vector2(0.0, -100.0)
	city_near = 1500.0
	city_tall = Vector2(105.0, 70.0)
	park_rect = RIVERSIDE
	river_half = RIVER_HALF_W
	water_y = 0.0
	skyline_clusters = [Vector2(-300.0, -1600.0), Vector2(1400.0, -900.0), Vector2(-1500.0, 900.0), Vector2(900.0, 1500.0), Vector2(2200.0, 200.0)]


# ======================================================================================
#  The ground: the two rivers, the shore, the peninsula's bluff, the banks
# ======================================================================================

## How far into the dry: below `river_half` is the water (the city keeps off it, YunhaiStage).
func _river_d(x: float, z: float) -> float:
	var d: float = absf(z)
	if z < -RIVER_HALF_W + 10.0:
		d = minf(d, RIVER_HALF_W - TRIB_HALF + absf(x - TRIB_X))
	return d


func _natural(x: float, z: float) -> float:
	var h: float
	if z > 0.0:
		# The south bank: the embankment at 8m, rising gently inland.
		h = 8.0 + 6.0 * smoothstep(450.0, 1100.0, z)
		h = lerpf(-10.0, h, smoothstep(RIVER_HALF_W - 5.0, RIVER_HALF_W + 22.0, z))
	elif x < TRIB_X:
		# The peninsula: a shore of gravel at 2.5m, then the bluff (receding north toward the tip, so the loop up onto the
		# suspension bridge stands on the broad shore there), the heights above.
		var z0: float = -300.0 - BLUFF_RECEDE * smoothstep(BLUFF_X0, BLUFF_X1, x)
		var t: float = smoothstep(-z0, -z0 + 110.0, -z)
		h = lerpf(2.5, 30.0, t) + 15.0 * smoothstep(500.0, 1100.0, -z)
		h = lerpf(-10.0, h, smoothstep(RIVER_HALF_W - 5.0, RIVER_HALF_W + 23.0, -z))
	else:
		# The north district across the tributary.
		h = 10.0 + 8.0 * smoothstep(1100.0, 1800.0, x)
		h = lerpf(-10.0, h, smoothstep(RIVER_HALF_W - 5.0, RIVER_HALF_W + 40.0, -z))
	# The tributary: water along x TRIB_X north of the river, its banks shores at 2.5m.
	if z < -RIVER_HALF_W + 15.0:
		var d: float = absf(x - TRIB_X)
		var bank: float = lerpf(2.5, h, smoothstep(TRIB_HALF + 25.0, TRIB_HALF + 80.0, d))
		h = lerpf(-10.0, bank, smoothstep(TRIB_HALF - 5.0, TRIB_HALF + 22.0, d))
	# The inlet the barge lies in.
	if INLET.grow(4.0).has_point(Vector2(x, z)):
		var e: float = minf(minf(x - INLET.position.x, INLET.end.x - x), INLET.end.y - z)
		e = minf(e, z - INLET.position.y)
		h = lerpf(h, -6.0, smoothstep(-2.0, 2.0, e))
	# Hills round the far city.
	var r: float = Vector2(x, z).distance_to(city_mid)
	var hill: float = smoothstep(2400.0, 4200.0, r) * (170.0 + 120.0 * n_ridge.get_noise_2d(x * 0.6, z * 0.6))
	return h + maxf(hill, 0.0)


func _ground_params(m: ShaderMaterial) -> void:
	super(m)
	m.set_shader_parameter("shore_y", 3.4)
	m.set_shader_parameter("slope_grass", 1.0)
	m.set_shader_parameter("lamp_energy", 0.2)


# ======================================================================================
#  The route's heights
# ======================================================================================

func _shape_heights(r: Route, ys: PackedFloat32Array) -> void:
	if r != lap:
		return
	var n: int = ys.size()
	var L: float = lap.length
	var ks: Array = []
	for k in KNOTS:
		ks.append([lap.closest_s(k[0] as Vector2), float(k[1]) + GROUND_UNDER])
	ks.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var lip: float = lap.closest_s(JUMP_LIP)
	var land: float = lip + JUMP_GAP
	var raw := PackedFloat32Array()
	raw.resize(n)
	for i in range(n):
		var s := float(i)
		var k0: Array = ks[ks.size() - 1]
		var k1: Array = ks[0]
		for j in range(ks.size()):
			if float(ks[j][0]) <= s:
				k0 = ks[j]
				k1 = ks[(j + 1) % ks.size()]
		var span: float = fposmod(float(k1[0]) - float(k0[0]), L)
		var t: float = clampf(fposmod(s - float(k0[0]), L) / maxf(span, 0.001), 0.0, 1.0)
		raw[i] = lerpf(float(k0[1]), float(k1[1]), t)
	for i in range(n):
		if float(i) > lip - 10.0 and float(i) < land + 10.0:
			ys[i] = raw[i]
			continue
		var acc := 0.0
		for d in range(-10, 11):
			acc += raw[posmod(i + d, n)]
		ys[i] = acc / 21.0
	_a = {"lip": lip, "land": land, "start": lap.closest_s(START_AT), "shore0": lap.closest_s(Vector2(-260.0, -300.0)),
		"shore1": lap.closest_s(Vector2(360.0, -260.0))}
	# Bridges: every stretch more than 3m over the natural ground, and over the barge's inlet.
	bridges = []
	var in_b := false
	var b0 := 0.0
	for i in range(n):
		var p: Vector2 = lap.at(float(i))["p"]
		var up: bool = ys[i] - _natural(p.x, p.y) > 3.0
		if up and not in_b:
			in_b = true
			b0 = float(i)
		elif not up and in_b:
			in_b = false
			bridges.append(["lap", b0, float(i), 0.0, true])
	if in_b:
		bridges.append(["lap", b0, L, 0.0, true])
	bridges.append(["lap", lip - 3.0, land + 3.0, 0.0, true])
	print("  lap %.0fm, jump lip at %.0fm, bridges %s" % [L, lip, str(bridges.map(func(b): return "%.0f-%.0f" % [b[1], b[2]]))])


## Dew on the roads: a little gloss, the sky in it.
func _road_params(m: ShaderMaterial) -> void:
	super(m)
	m.set_shader_parameter("wetness", 0.35)
	# Daylight: no neon skyline in the gloss.
	m.set_shader_parameter("city_reflect", 0.0)


func _sections(r: Route) -> Array:
	if r != lap or _a.is_empty():
		return [[0.0, r.length, K_ASPHALT, r.half]]
	var s0: float = _a["shore0"]
	var s1: float = _a["shore1"]
	return [[0.0, s0, K_ASPHALT, r.half], [s0, float(_a["lip"]), K_GRAVEL, r.half], [float(_a["land"]), s1, K_GRAVEL, r.half],
		[s1, r.length, K_ASPHALT, r.half]]


func _build_deck_slab(_node: Node3D, _r: Route, _s0: float, _s1: float, _idx: int) -> void:
	pass


func _is_bridge(s: float) -> bool:
	for b in bridges:
		if s >= float(b[1]) and s <= float(b[2]):
			return true
	return false


# ======================================================================================
#  Dawn in the fog
# ======================================================================================

func _environment() -> Dictionary:
	var e: Dictionary = super()
	e["sky_top"] = Color(0.34, 0.47, 0.66)
	e["sky_horizon"] = Color(0.96, 0.74, 0.6)
	e["haze"] = Color(0.84, 0.79, 0.76)
	e["ground_bottom"] = Color(0.4, 0.38, 0.36)
	e["sun_tint"] = Color(1.0, 0.8, 0.6)
	e["sun_glow"] = 0.2
	e["sun_horizon_tint"] = Color(1.0, 0.65, 0.45)
	e["sun_horizon_glow"] = 0.3
	e["cloud_lit"] = Color(1.0, 0.84, 0.74)
	e["cloud_shade"] = Color(0.58, 0.58, 0.66)
	e["cloud_coverage"] = 0.35
	e["cloud_opacity"] = 0.6
	e["ambient"] = 0.7
	e["ambient_color"] = Color(0.78, 0.75, 0.78)
	e["exposure"] = 1.0
	e["glow"] = 0.35
	e["bloom"] = 0.03
	e["fog_begin"] = 25.0
	e["fog_end"] = 850.0
	e["fog_curve"] = 1.1
	e["fog_density"] = 1.0
	e["fog_sky"] = 0.65
	e["fog_aerial"] = 0.3
	e["fog_scatter"] = 0.45
	e["sun_pitch"] = -9.0
	e["sun_yaw"] = 75.0
	e["sun_color"] = Color(1.0, 0.76, 0.56)
	e["sun_energy"] = 1.15
	e["shadow_distance"] = 320.0
	return e


# ======================================================================================
#  Gameplay
# ======================================================================================

func _place_gameplay(root: Node3D) -> void:
	var cps: Array = []
	for q in [Vector2(-350.0, 420.0), Vector2(ARCH_X, 0.0), Vector2(-430.0, -340.0), Vector2(200.0, -260.0), Vector2(460.0, -360.0),
			Vector2(SUSP_X, 0.0)]:
		cps.append(lap.closest_s(q))
	_checkpoints(cps)
	_boosts([["Boost_Avenue", lap.closest_s(Vector2(-250.0, 420.0)), 2.5], ["Boost_Shore", float(_a["lip"]) - 60.0, 0.0],
["Boost_Bridge", lap.closest_s(Vector2(SUSP_X, 150.0)), 0.0]])
	var lip: float = _a["lip"]
	_kicker(root, "Jump_Barge", lap, lip - KICK_LEN, KICK_LEN, KICK_H, 0.5, false, Color(0.45, 0.38, 0.3))


# ======================================================================================
#  The dressing
# ======================================================================================

## Air taxis: along the river between the two bridges, up the tributary, and over the riverside park by the start.
const TAXI_ROUTES: Array = [
	{"points": [Vector3(-500, 60, -120), Vector3(-150, 62, -140), Vector3(200, 60, -125), Vector3(225, 62, 120), Vector3(-150, 62, 140),
		Vector3(-500, 60, 130)], "speed": 24.0, "count": 2},
	{"points": [Vector3(620, 52, -260), Vector3(780, 54, -260), Vector3(785, 56, -700), Vector3(615, 54, -700)], "speed": 22.0, "count": 1},
	{"points": [Vector3(-660, 42, 300), Vector3(150, 44, 300), Vector3(170, 46, 345), Vector3(-660, 44, 355)], "speed": 20.0, "count": 2},
]

func _build_dressing(root: Node3D) -> void:
	_load_cjk_font()
	# Morning: the windows mostly dark, the LED shows dimmed (the kit's materials are shared by everything built here).
	(MCK.material("tower") as ShaderMaterial).set_shader_parameter("lit_energy", 0.7)
	(MCK.material("tower") as ShaderMaterial).set_shader_parameter("led_energy", 1.4)
	(MCK.material("neon") as ShaderMaterial).set_shader_parameter("energy", 2.0)
	_rails = _body(root, "RoadRailsBody")
	_rails.set_meta(&"surface", "rock")
	_sample_route()
	_reserved.append(Rect2(BLUFF_X0, -580.0, TRIB_X - TRIB_HALF - BLUFF_X0, 380.0))
	_reserved.append(Rect2(CRYSTAL_X[0] - 40.0, CRYSTAL_Z - 40.0, CRYSTAL_X[3] - CRYSTAL_X[0] + 80.0, 80.0))
	_reserved.append(Rect2(SUPERTALL_AT - Vector2(70, 70), Vector2(140, 140)))
	_reserved.append(RIVERSIDE)
	_reserved.append(Rect2(-800.0, -300.0, 1300.0, 90.0))
	_build_road_decks()
	_build_lamps()
	_build_arch_bridge()
	_build_suspension_bridge()
	_build_shore()
	_build_beach()
	_build_barges()
	_build_landmarks()
	_build_riverside_park()
	_build_mist(root)
	_build_city()
	_build_skyline(root)
	_build_crowds()
	_build_air_taxis(root, TAXI_ROUTES)
	print("  dressing: %d buildings, %d people" % [_bid, _people.size()])


## No piers under the bridges' spans (the arch and the cables carry them).
func _col_blocked(p: Vector3, _g: float) -> bool:
	if absf(p.x - ARCH_X) < 30.0 and absf(p.z) < 214.0:
		return true
	if absf(p.x - SUSP_X) < 30.0 and absf(p.z) < SUSP_TOWER_Z + 8.0:
		return true
	return false


func _build_road_decks() -> void:
	var L: float = lap.length
	var lip: float = _a["lip"]
	var land: float = _a["land"]
	var cuts: Array = [0.0, L, lip, land]
	for b in bridges:
		cuts.append(float(b[1]))
		cuts.append(float(b[2]))
	cuts.sort()
	var k := 0
	for i in range(cuts.size() - 1):
		var s0: float = cuts[i]
		var s1: float = cuts[i + 1]
		if s1 - s0 < 1.0 or (s0 >= lip - 0.5 and s1 <= land + 0.5):
			continue
		var mid: float = (s0 + s1) * 0.5
		var up: bool = _is_bridge(mid)
		var shore: bool = mid > float(_a["shore0"]) and mid < float(_a["shore1"])
		# The shore road has no parapets on its river side (a kerb of stones, `_build_shore`), only on the bluff's.
		var rails: Array = [true, true]
		if shore and not up:
			rails = [true, false]
		_deck("deck_road_%d" % k, s0, s1, 2.2 if up else 0.4, Color(1.0, 0.7, 0.4, 0.0), 34.0 if up else 0.0, rails, 0.0, true)
		k += 1


func _build_lamps() -> void:
	_city("deck_road_lamps", func(pk: PropKit, kit: Dictionary, _l: Array) -> void:
		var s := 10.0
		var k := 0
		while s < lap.length - 5.0:
			var shore: bool = s > float(_a["shore0"]) - 10.0 and s < float(_a["shore1"]) + 10.0
			if not shore:
				var side: float = -1.0 if k % 2 == 0 else 1.0
				var b: Vector3 = lap.pt(s) + lap.rt(s) * side * (road_half + 0.7) + Vector3(0, 1.1, 0)
				pk.tube(kit, "steel", b, b + Vector3(0, 10.0, 0), 0.16, 0.11, 6, Color(0.4, 0.41, 0.44))
				var head: Vector3 = b + Vector3(0, 10.0, 0) - lap.rt(s) * side * 2.6
				pk.beam(kit, "steel", b + Vector3(0, 10.0, 0), head, 0.12, 0.12, Color(0.4, 0.41, 0.44))
				pk.block(kit, "neon", head + Vector3(-0.6, -0.18, -0.35), head + Vector3(0.6, 0.0, 0.35), Color(1.0, 0.85, 0.65))
				k += 1
			s += 34.0
	, 1400.0)


# ---- The Jiangxin Bridge: a red through-arch -------------------------------------------------------------------------

func _arch_y(z: float) -> float:
	var f: float = z / (RIVER_HALF_W + 15.0)
	return 2.0 + 93.0 * (1.0 - f * f)


func _build_arch_bridge() -> void:
	var red := Color(0.72, 0.13, 0.1)
	var half := RIVER_HALF_W + 15.0
	var deck: float = lap.y(lap.closest_s(Vector2(ARCH_X, 0.0)))
	_city("bridge_arch", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		for side in [-1.0, 1.0]:
			var x: float = ARCH_X + side * 11.0
			var prev_u := Vector3.ZERO
			var prev_l := Vector3.ZERO
			var z: float = -half
			var k := 0
			while z <= half + 0.1:
				var yu: float = _arch_y(z)
				var yl: float = yu - lerpf(10.0, 6.5, 1.0 - absf(z) / half)
				var u := Vector3(x, yu, z)
				var l := Vector3(x, maxf(yl, 0.0), z)
				if k > 0:
					pk.beam(kit, "gloss", prev_u, u, 1.6, 1.8, red)
					pk.beam(kit, "gloss", prev_l, l, 1.4, 1.6, red)
					pk.beam(kit, "gloss", (prev_u if k % 2 == 0 else prev_l), (l if k % 2 == 0 else u), 0.7, 0.7, red)
					MCK.led_line(pk, kit, prev_u + Vector3(side * 0.85, 0.9, 0), u + Vector3(side * 0.85, 0.9, 0), Color(1.0, 0.55, 0.3, 0.0), 0.25)
				pk.beam(kit, "gloss", u, l, 0.6, 0.6, red)
				# Hangers down to the deck's edge where the arch is over it.
				if l.y > deck + 2.0:
					pk.beam(kit, "steel", l, Vector3(x - side * 1.5, deck - 0.2, z), 0.12, 0.12, Color(0.5, 0.5, 0.52))
				# Wind bracing between the ribs, high enough over the deck.
				if side > 0.0 and l.y > deck + 14.0 and k % 2 == 0:
					pk.beam(kit, "gloss", Vector3(ARCH_X - 11.0, l.y, z), Vector3(ARCH_X + 11.0, l.y, z), 0.6, 0.8, red)
					pk.beam(kit, "gloss", Vector3(ARCH_X - 11.0, l.y, z), Vector3(ARCH_X + 11.0, u.y, z + 10.0), 0.4, 0.4, red)
				prev_u = u
				prev_l = l
				z += 10.0
				k += 1
			# The springings: concrete piers on the banks.
			for zs in [-half, half]:
				pk.block(kit, "tower", Vector3(x - 4.0, -8.0, zs - 6.0), Vector3(x + 4.0, 4.0, zs + 6.0), Color(0.6, 0.6, 0.6, float(MCK.STYLE_CONCRETE) / 8.0))
		# The deck's fascia girders along the hangers' line.
		for side2 in [-1.0, 1.0]:
			pk.beam(kit, "gloss", Vector3(ARCH_X + side2 * 9.5, deck - 0.8, -half), Vector3(ARCH_X + side2 * 9.5, deck - 0.8, half), 1.2, 1.6, red)
		for face in [-1.0, 1.0]:
			MCK.neon_sign(pk, kit, labels, Vector3(ARCH_X, _arch_y(0.0) - 12.0, face * 2.0), Vector3(0, 0, face), 16.0, 3.0, "江心大桥", Color(1.0, 0.85, 0.5))
	, 4200.0)


# ---- The Shuangjiang Bridge: a suspension bridge ------------------------------------------------------------------

## The deck's height on the suspension bridge's line at z.
func _susp_deck(z: float) -> float:
	return lap.y(lap.closest_s(Vector2(SUSP_X, clampf(z, -SUSP_END_Z - 10.0, SUSP_END_Z + 10.0))))


func _cable_y(z: float) -> float:
	var a: float = absf(z)
	if a <= SUSP_TOWER_Z:
		var f: float = a / SUSP_TOWER_Z
		var mid: float = _susp_deck(0.0) + 3.5
		return mid + (SUSP_TOP - mid) * f * f
	# The side spans: a gentle sag from the tower's top down to the anchor on the deck's edge.
	var t: float = clampf((a - SUSP_TOWER_Z) / (SUSP_END_Z - SUSP_TOWER_Z), 0.0, 1.0)
	var end: float = _susp_deck(signf(z) * SUSP_END_Z) + 2.0
	return lerpf(SUSP_TOP, end, t) - 6.0 * t * (1.0 - t)


func _build_suspension_bridge() -> void:
	var white := Color(0.9, 0.9, 0.92)
	_city("bridge_suspension", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		for zt in [-SUSP_TOWER_Z, SUSP_TOWER_Z]:
			var deck: float = lap.y(lap.closest_s(Vector2(SUSP_X, zt)))
			for side in [-1.0, 1.0]:
				var x: float = SUSP_X + side * 11.0
				pk.box(kit, "gloss", Transform3D(Basis(), Vector3(x, (SUSP_TOP - 12.0) * 0.5, zt)), Vector3(3.2, SUSP_TOP + 12.0, 5.0), white)
				MCK.led_line(pk, kit, Vector3(x + side * 1.65, 0.0, zt), Vector3(x + side * 1.65, SUSP_TOP, zt), Color(0.5, 0.85, 1.0, 0.0), 0.3)
				pk.block(kit, "neon", Vector3(x - 0.5, SUSP_TOP + 0.2, zt - 0.5), Vector3(x + 0.5, SUSP_TOP + 1.2, zt + 0.5), Color(1.0, 0.1, 0.05))
			for by in [deck - 2.6, 72.0, SUSP_TOP - 4.0]:
				pk.box(kit, "gloss", Transform3D(Basis(), Vector3(SUSP_X, by, zt)), Vector3(25.4, 3.0, 4.0), white)
			pk.block(kit, "tower", Vector3(SUSP_X - 16.0, -8.0, zt - 8.0), Vector3(SUSP_X + 16.0, 3.0, zt + 8.0), Color(0.6, 0.6, 0.6, float(MCK.STYLE_CONCRETE) / 8.0))
			for face in [-1.0, 1.0]:
				MCK.neon_sign(pk, kit, labels, Vector3(SUSP_X, 72.0, zt + face * 2.1), Vector3(0, 0, face), 18.0, 2.6, "双江大桥", Color(1.0, 0.85, 0.5))
		# The main cables, their hangers, the fascia girders they hold, the anchorages.
		for side2 in [-1.0, 1.0]:
			var x2: float = SUSP_X + side2 * 11.0
			var prev := Vector3.ZERO
			var z: float = -SUSP_END_Z
			var k := 0
			while z <= SUSP_END_Z + 0.1:
				var p := Vector3(x2, _cable_y(z), z)
				if k > 0:
					pk.beam(kit, "gloss", prev, p, 0.8, 0.8, white)
					MCK.led_line(pk, kit, prev + Vector3(0, 0.45, 0), p + Vector3(0, 0.45, 0), Color(0.9, 0.95, 1.0, 0.0), 0.12)
				var deck2: float = _susp_deck(z)
				if absf(z) < SUSP_TOWER_Z - 3.0 and p.y > deck2 + 2.0:
					pk.beam(kit, "steel", p, Vector3(x2, deck2 - 0.6, z), 0.12, 0.12, Color(0.55, 0.56, 0.6))
				prev = p
				z += 10.0
				k += 1
			pk.beam(kit, "gloss", Vector3(SUSP_X + side2 * 10.0, lap.y(lap.closest_s(Vector2(SUSP_X, -SUSP_TOWER_Z))) - 0.8, -SUSP_TOWER_Z),
					Vector3(SUSP_X + side2 * 10.0, lap.y(lap.closest_s(Vector2(SUSP_X, SUSP_TOWER_Z))) - 0.8, SUSP_TOWER_Z), 1.0, 1.4, white)
			# The anchors: blocks on the deck's edge outside its balustrade, the cables running into them.
			for za in [-SUSP_END_Z, SUSP_END_Z]:
				var ya: float = _susp_deck(za)
				pk.block(kit, "gloss", Vector3(x2 - 1.4, ya - 1.0, za - 4.0), Vector3(x2 + 1.4, ya + 2.6, za + 4.0), white)
	, 4200.0)


# ---- The shore road's surroundings -----------------------------------------------------------------------------------

## The retaining wall along the bluff's foot behind the shore road, steps up it, sampans on the gravel, heaps of sand, a
## kerb of boulders on the river side, mooring bollards.
func _build_shore() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6161
	var s0: float = float(_a["shore0"]) + 20.0
	var s1: float = float(_a["shore1"]) - 20.0
	_city("shore", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		var s: float = s0
		var wall_end: float = lap.closest_s(Vector2(BLUFF_X0 + 10.0, -260.0))
		while s < s1:
			var sb: float = minf(s + 8.0, s1)
			if s < wall_end and not (sb > float(_a["lip"]) - 4.0 and s < float(_a["land"]) + 4.0):
				# The wall: stone up the bluff, 10m behind the road's edge.
				var a: Vector3 = lap.pt(s) - lap.rt(s) * (road_half + 10.0)
				var b: Vector3 = lap.pt(sb) - lap.rt(sb) * (road_half + 10.0)
				var top: float = maxf(_ground_at(a.x, a.z - 12.0), a.y + 5.0)
				MCK.wall(pk, kit, Vector3(b.x, 0, b.z), Vector3(a.x, 0, a.z), a.y - 1.0, top, Vector3(0, 0, 1), Color(0.5, 0.48, 0.42), MCK.STYLE_CONCRETE, 91)
			if not (sb > float(_a["lip"]) - 4.0 and s < float(_a["land"]) + 4.0):
				# Boulders along the river side.
				var rp: Vector3 = lap.pt(s) + lap.rt(s) * (road_half + rng.randf_range(1.5, 3.5))
				rp.y = _ground_at(rp.x, rp.z)
				_boulders(pk, kit, rp, rng.randf_range(1.2, 2.2), rng)
			s = sb
		# Steps up the wall every 90m, sampans and sand heaps on the gravel by the water.
		var x := -200.0
		while x < 340.0:
			if absf(x - 18.0) > 40.0:
				var c := Vector3(x, 0.0, -233.0)
				c.y = _ground_at(c.x, c.z)
				# A sampan pulled up on the shore.
				var hull := PackedVector2Array([Vector2(c.x - 5.0, c.z - 1.0), Vector2(c.x + 4.0, c.z - 1.0), Vector2(c.x + 5.5, c.z), Vector2(c.x + 4.0, c.z + 1.0),
					Vector2(c.x - 5.0, c.z + 1.0)])
				MCK.prism(pk, kit, hull, c.y - 0.2, c.y + 0.8, Color(0.35, 0.25, 0.16), MCK.STYLE_CONCRETE, 92, true)
				pk.lathe(kit, "paint", Vector3(c.x - 1.0, c.y + 0.8, c.z), [Vector2(1.2, 0.0), Vector2(1.0, 0.8), Vector2(0.001, 1.1)], 6, Color(0.3, 0.32, 0.25))
				var heap := Vector3(x + 25.0, 0.0, -246.0)
				heap.y = _ground_at(heap.x, heap.z)
				pk.lathe(kit, "paint", heap, [Vector2(5.0, 0.0), Vector2(3.0, 1.4), Vector2(0.001, 2.4)], 10, Color(0.56, 0.49, 0.38))
			x += 90.0
	, 1400.0)


## A heap of river boulders (MegacityKit's rock heap is the aquarium's dark material).
func _boulders(pk: PropKit, kit: Dictionary, c: Vector3, r: float, rng: RandomNumberGenerator) -> void:
	for i in range(rng.randi_range(3, 6)):
		var a: float = rng.randf() * TAU
		var d: float = rng.randf() * r * 0.6
		var sz: float = r * rng.randf_range(0.3, 0.6)
		var p := c + Vector3(cos(a) * d, sz * 0.3, sin(a) * d)
		var prof: Array = [Vector2(0.001, -sz * 0.5), Vector2(sz * 0.8, -sz * 0.4), Vector2(sz, 0.0), Vector2(sz * 0.7, sz * 0.45), Vector2(0.001, sz * 0.6)]
		pk.lathe(kit, "paint", p, prof, 7, Color(0.4, 0.38, 0.34).lightened(rng.randf_range(-0.1, 0.1)), true, Basis(Vector3.UP, rng.randf() * TAU))


## The sand barge moored in the inlet the jump crosses, and barges and a river boat moored or at anchor on the river.
func _build_barges() -> void:
	var boats: Array = [
		# [centre, heading (radians), length, beam, cargo: 0 sand, 1 containers, 2 a river cruiser]
		[Vector2(18.0, -252.0), PI * 0.5, 40.0, 12.0, 0],
		[Vector2(-380.0, -150.0), 0.05, 70.0, 14.0, 1],
		[Vector2(140.0, 120.0), -0.1, 90.0, 16.0, 1],
		[Vector2(-200.0, 60.0), 0.0, 60.0, 13.0, 2],
		[Vector2(700.0, -600.0), PI * 0.5, 55.0, 12.0, 0],
		[Vector2(980.0, 40.0), 0.2, 80.0, 15.0, 2],
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7272
	for bt in boats:
		var c: Vector2 = bt[0]
		var hd: float = bt[1]
		var bl: float = bt[2]
		var bw: float = bt[3]
		var kind: int = bt[4]
		var id := _id()
		_city("barges", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
			var fw := Vector2(cos(hd), sin(hd))
			var rt := Vector2(-fw.y, fw.x)
			var pts := PackedVector2Array()
			for q in [Vector2(-0.5, -0.5), Vector2(0.42, -0.5), Vector2(0.5, -0.25), Vector2(0.5, 0.25), Vector2(0.42, 0.5), Vector2(-0.5, 0.5)]:
				pts.append(c + fw * (q.x * bl) + rt * (q.y * bw))
			var top: float = 1.0 if kind == 0 else 1.8
			MCK.prism(pk, kit, pts, -2.0, top, Color(0.25, 0.24, 0.22) if kind != 2 else Color(0.9, 0.9, 0.9), MCK.STYLE_CLADDING, id, true)
			if kind == 0:
				# Sand in low heaps (the jump passes over it).
				for k in range(3):
					var hc: Vector2 = c + fw * ((float(k) - 1.0) * bl * 0.25)
					pk.lathe(kit, "paint", Vector3(hc.x, top, hc.y), [Vector2(bw * 0.4, 0.0), Vector2(bw * 0.25, 0.5), Vector2(0.001, 0.9)], 10, Color(0.68, 0.6, 0.45))
				# The wheelhouse at the river end, well clear of the jump.
				var wh: Vector2 = c + fw * (bl * 0.4)
				MCK.prism(pk, kit, MCK.rect_plan(wh, 2.5, 2.5), top, top + 4.5, Color(0.85, 0.85, 0.82), MCK.STYLE_FLATS, id + 1, true)
			elif kind == 1:
				var n: int = int(bl / 7.0) - 2
				for k2 in range(n):
					for r2 in [-1.0, 1.0]:
						var cc: Vector2 = c + fw * ((float(k2) - float(n) * 0.5 + 0.5) * 6.5 - bl * 0.05) + rt * (r2 * bw * 0.22)
						var col := Color.from_hsv(rng.randf(), 0.6, 0.6)
						MCK.prism(pk, kit, MCK.rect_plan(cc, 3.0, 1.2).duplicate(), top, top + 2.6 * float(1 + rng.randi() % 2), col, MCK.STYLE_CONCRETE, id, true)
				var wh2: Vector2 = c - fw * (bl * 0.42)
				MCK.prism(pk, kit, MCK.rect_plan(wh2, 3.0, bw * 0.35), top, top + 7.0, Color(0.9, 0.9, 0.88), MCK.STYLE_FLATS, id + 1, true)
			else:
				for dk in range(3):
					var y0: float = top + float(dk) * 3.0
					var sh: float = 2.0 + float(dk) * 4.0
					var cab := PackedVector2Array([c + fw * (-bl * 0.5 + sh) + rt * (-bw * 0.4), c + fw * (bl * 0.35 - sh) + rt * (-bw * 0.4),
						c + fw * (bl * 0.35 - sh) + rt * (bw * 0.4), c + fw * (-bl * 0.5 + sh) + rt * (bw * 0.4)])
					MCK.prism(pk, kit, cab, y0, y0 + 2.8, Color(0.92, 0.92, 0.92), MCK.STYLE_OFFICE, id + dk, true)
		, 2600.0)


# ---- Tianqiao's towers on the heights --------------------------------------------------------------------------------

func _build_landmarks() -> void:
	var id := _id()
	_city("landmarks", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		# The Liangjiang towers and their crystal: four towers, a glass gallery laid across their tops.
		var gy: float = 0.0
		for x in CRYSTAL_X:
			gy = maxf(gy, _ground_at(x, CRYSTAL_Z))
		var gal_y := 238.0
		for i in range(CRYSTAL_X.size()):
			var x: float = CRYSTAL_X[i]
			var g: float = _ground_at(x, CRYSTAL_Z) - 2.0
			var h: float = gal_y + (12.0 if i % 3 == 0 else 0.0)
			MCK.tower(pk, kit, Vector2(x, CRYSTAL_Z), 20.0, 20.0, g, h, Color(0.55, 0.62, 0.7), MCK.STYLE_OFFICE, id + i, 6.0, 18.0, true, Color(0.5, 0.85, 1.0, 0.0), false)
		var plan := PackedVector2Array([Vector2(CRYSTAL_X[0] - 12.0, CRYSTAL_Z - 16.0), Vector2(CRYSTAL_X[3] + 12.0, CRYSTAL_Z - 16.0),
			Vector2(CRYSTAL_X[3] + 12.0, CRYSTAL_Z + 16.0), Vector2(CRYSTAL_X[0] - 12.0, CRYSTAL_Z + 16.0)])
		MCK.prism(pk, kit, plan, gal_y - 22.0, gal_y - 4.0, Color(0.7, 0.8, 0.88), MCK.STYLE_OFFICE, id + 6, true)
		MCK.neon_sign(pk, kit, labels, Vector3((CRYSTAL_X[0] + CRYSTAL_X[3]) * 0.5, gal_y - 13.0, CRYSTAL_Z + 16.4), Vector3(0, 0, 1), 40.0, 6.0, "云廊",
				Color(0.4, 0.85, 1.0))
		# The Yunhai Center: the supertall, its crown and spire, over everything.
		var c: Vector2 = SUPERTALL_AT
		var g2: float = _ground_at(c.x, c.y) - 2.0
		MCK.prism(pk, kit, MCK.rect_plan(c, 46.0, 46.0, 14.0), g2, g2 + 120.0, Color(0.42, 0.55, 0.62), MCK.STYLE_OFFICE, id + 7, true)
		MCK.prism(pk, kit, MCK.rect_plan(c, 42.0, 42.0, 12.0), g2 + 120.0, g2 + 250.0, Color(0.4, 0.52, 0.6), MCK.STYLE_OFFICE, id + 8, true)
		MCK.prism(pk, kit, MCK.rect_plan(c, 38.0, 38.0, 10.0), g2 + 250.0, g2 + 330.0, Color(0.38, 0.5, 0.58), MCK.STYLE_OFFICE, id + 9, true)
		for k in range(4):
			var ang: float = PI * 0.25 + PI * 0.5 * float(k)
			var d := Vector2(cos(ang), sin(ang))
			var p: Vector2 = c + d * 46.0
			var sv := Vector2(-d.y, d.x)
			MCK.prism(pk, kit, PackedVector2Array([p + sv * 4.0, p + d * 3.0, p - sv * 4.0, p - d * 2.0]), g2 + 328.0, g2 + 390.0, Color(0.3, 0.32, 0.36),
					MCK.STYLE_CLADDING, id + 10, true)
		pk.tube(kit, "steel", Vector3(c.x, g2 + 330.0, c.y), Vector3(c.x, g2 + 450.0, c.y), 2.4, 0.5, 10, Color(0.6, 0.62, 0.66))
		pk.block(kit, "neon", Vector3(c.x - 0.8, g2 + 450.0, c.y - 0.8), Vector3(c.x + 0.8, g2 + 452.0, c.y + 0.8), Color(1.0, 0.1, 0.05))
	, 6000.0)


# ---- The riverside park on the south bank ----------------------------------------------------------------------------

func _build_riverside_park() -> void:
	var r: Rect2 = RIVERSIDE
	var rng := RandomNumberGenerator.new()
	rng.seed = 8181
	_city("riverside", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		# The river wall and its railing, the promenade along it, benches, lamp posts.
		var z: float = r.position.y - 2.0
		MCK.wall(pk, kit, Vector3(r.position.x, 0, z), Vector3(r.end.x, 0, z), -10.0, 8.0, Vector3(0, 0, -1), Color(0.55, 0.52, 0.46), MCK.STYLE_CONCRETE, 93)
		MCK.glass_rail(pk, kit, Vector3(r.position.x, 8.0, z + 0.4), Vector3(r.end.x, 8.0, z + 0.4), 1.1, Color(1.0, 0.8, 0.5, 0.0))
		var x: float = r.position.x + 10.0
		while x < r.end.x:
			if absf(x - ARCH_X) > 20.0 and absf(x - SUSP_X) > 20.0:
				var lp := Vector3(x, 8.0, z + 3.0)
				pk.tube(kit, "steel", lp, lp + Vector3(0, 4.5, 0), 0.08, 0.06, 6, Color(0.2, 0.2, 0.22))
				pk.block(kit, "neon", lp + Vector3(-0.3, 4.4, -0.3), lp + Vector3(0.3, 4.7, 0.3), Color(1.0, 0.85, 0.6))
				pk.block(kit, "paint", lp + Vector3(2.0, 0.0, 0.0), lp + Vector3(4.2, 0.45, 0.6), Color(0.35, 0.22, 0.12))
			x += 24.0
	, 1400.0)


func _tree_pick(x: float, z: float, roll: float, rng: RandomNumberGenerator) -> Array:
	# The riverside park's trees (camphor-like dark crowns, willows by the water, a few maples), and on the bluff's face.
	if RIVERSIDE.has_point(Vector2(x, z)):
		if roll > 0.42:
			return []
		var near_water: bool = z < RIVERSIDE.position.y + 30.0
		var kinds: Array = ["matsu", "matsu", "momiji", "take", "sakura"]
		return ["shidare" if near_water and roll < 0.18 else kinds[rng.randi() % kinds.size()], rng.randf_range(0.85, 1.1)]
	if z < -300.0 and z > -420.0 and x < BLUFF_X0 and x > -560.0:
		if roll > 0.22:
			return []
		return [["matsu", "take", "momiji"][rng.randi() % 3], rng.randf_range(0.8, 1.05)]
	return []


# ---- The mist on the water -----------------------------------------------------------------------------------------

func _build_mist(root: Node3D) -> void:
	var shader: Shader = load("res://river_mist.gdshader")
	var sheets: Array = [
		# [name, centre, size, height, layer, density]
		["MistRiver0", Vector2(0.0, 0.0), Vector2(5000.0, 420.0), 2.5, 0.0, 0.5],
		["MistRiver1", Vector2(0.0, 0.0), Vector2(5000.0, 400.0), 6.5, 0.37, 0.4],
		["MistRiver2", Vector2(0.0, 0.0), Vector2(5000.0, 380.0), 12.0, 0.71, 0.28],
		["MistTributary0", Vector2(TRIB_X, -1400.0), Vector2(300.0, 2400.0), 3.0, 0.2, 0.45],
		["MistTributary1", Vector2(TRIB_X, -1400.0), Vector2(290.0, 2400.0), 8.0, 0.55, 0.32],
	]
	for sh in sheets:
		var mi := MeshInstance3D.new()
		mi.name = sh[0]
		var pm := PlaneMesh.new()
		pm.size = sh[2]
		mi.mesh = pm
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("layer", float(sh[4]))
		m.set_shader_parameter("density", float(sh[5]))
		mi.material_override = _save_res(m, String(sh[0]).to_lower() + "_material")
		mi.position = Vector3((sh[1] as Vector2).x, float(sh[3]), (sh[1] as Vector2).y)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)


func _build_water(root: Node3D) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "RiverSurface"
	var pm := PlaneMesh.new()
	pm.size = Vector2(12000.0, 12000.0)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	# The rivers at dawn: silty grey-green water with a soft sheen of the sky.
	m.albedo_color = Color(0.2, 0.21, 0.17)
	m.roughness = 0.18
	m.metallic = 0.35
	m.metallic_specular = 0.7
	mi.material_override = _save_res(m, "river_material")
	mi.position = Vector3(city_mid.x, water_y, city_mid.y)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


# ---- The confluence's beach ------------------------------------------------------------------------------------------

## The broad shore at the peninsula's tip under the loop (the bluff turned away north): sand heaps, boulders, boats pulled
## up, a walk of stepping slabs out to the point, people out early (fishing at the water, walking, flying kites).
func _build_beach() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9393
	var spots: Array = []
	_city("beach", func(pk: PropKit, kit: Dictionary, _l: Array) -> void:
		var x: float = BLUFF_X1 + 10.0
		while x < TRIB_X - TRIB_HALF - 15.0:
			var z: float = -RIVER_HALF_W - 18.0
			while z > -520.0:
				var c := Vector3(x + rng.randf_range(-12.0, 12.0), 0.0, z + rng.randf_range(-12.0, 12.0))
				var near_road: bool = _route_low_over(Rect2(c.x, c.z, 0.0, 0.0), 16.0) < INF
				if not near_road and _natural(c.x, c.z) > 1.0:
					c.y = _ground_at(c.x, c.z)
					var roll: float = rng.randf()
					if roll < 0.22:
						pk.lathe(kit, "paint", c, [Vector2(rng.randf_range(4.0, 8.0), 0.0), Vector2(3.0, 1.3), Vector2(0.001, rng.randf_range(2.0, 3.2))], 10,
								Color(0.56, 0.49, 0.38).lightened(rng.randf_range(-0.05, 0.05)))
					elif roll < 0.5:
						_boulders(pk, kit, c, rng.randf_range(1.0, 2.6), rng)
					elif roll < 0.62:
						var hd: float = rng.randf() * TAU
						var fw := Vector2(cos(hd), sin(hd))
						var rt := Vector2(-fw.y, fw.x)
						var cc := Vector2(c.x, c.z)
						var hull := PackedVector2Array([cc - fw * 5.0 - rt, cc + fw * 4.0 - rt, cc + fw * 5.5, cc + fw * 4.0 + rt, cc - fw * 5.0 + rt])
						MCK.prism(pk, kit, hull, c.y - 0.2, c.y + 0.8, Color(0.33, 0.24, 0.16), MCK.STYLE_CONCRETE, 94, true)
					elif roll < 0.8:
						spots.append(c)
				z -= 34.0
			x += 34.0
	, 1400.0)
	for c in spots:
		var face := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized()
		for k in range(rng.randi_range(1, 3)):
			var p: Vector3 = c + Vector3(rng.randf_range(-2.5, 2.5), 0.0, rng.randf_range(-2.5, 2.5))
			p.y = _ground_at(p.x, p.z)
			_person(p, face, rng.randf_range(0.92, 1.06))


# ---- Crowds ----------------------------------------------------------------------------------------------------------

func _build_crowds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2401
	var s0: float = float(_a["start"]) - 60.0
	var s1: float = float(_a["start"]) + 60.0
	var s: float = s0
	while s < s1:
		for side in [-1.0, 1.0]:
			for row in range(2):
				if rng.randf() < 0.35:
					continue
				var p: Vector3 = lap.pt(fposmod(s, lap.length)) + lap.rt(fposmod(s, lap.length)) * side * (road_half + 2.6 + float(row) * 1.5 + rng.randf() * 0.5)
				p.y = _ground_at(p.x, p.z)
				_person(p, -lap.rt(fposmod(s, lap.length)) * side, rng.randf_range(0.92, 1.06))
		s += 2.4
	# Morning walkers along the riverside promenade and fishermen on the shore.
	_crowd_line(Vector3(RIVERSIDE.position.x + 20.0, 8.0, RIVERSIDE.position.y + 2.5), Vector3(RIVERSIDE.end.x - 20.0, 8.0, RIVERSIDE.position.y + 2.5),
			Vector3(0, 0, -1), 9.0, rng, 0.5)
	var x := -180.0
	while x < 330.0:
		if absf(x - 18.0) > 30.0 and rng.randf() < 0.6:
			var fp := Vector3(x + rng.randf_range(-8.0, 8.0), 0.0, -228.0)
			fp.y = _ground_at(fp.x, fp.z)
			_person(fp, Vector3(0, 0, 1), rng.randf_range(0.92, 1.06))
		x += 35.0


# ======================================================================================
#  After the build
# ======================================================================================

func _finish(root: Node3D) -> void:
	root.set_meta(&"fall_respawn_drop", 9.0)
	root.set_meta(&"music_stage", "shuangjiang")
	var fog := Node.new()
	fog.name = "FogLift"
	fog.set_script(load("res://FogLift.gd"))
	root.add_child(fog)
	fog.owner = root
