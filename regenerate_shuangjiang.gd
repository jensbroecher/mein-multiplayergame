extends "res://YunhaiStage.gd"
# Builds levels/ShuangjiangLevel.tscn - Shuangjiang (双江, "two rivers"), the Yunhai GP's fourth stage: one run of about
# 5.4km at dawn, from the Grand Theatre on the south bank to the plaza at the tip of the peninsula where the two rivers
# meet, in morning fog that lifts as the race goes on (FogLift.gd), mist lying on the water (river_mist.gdshader).
#
# The run (game metres, x east, z south; the river along z 0, 410m wide; the tributary along x 700 from the north, 300m
# wide; the peninsula between them, its tip at the confluence):
#   - the start on Binjiang Avenue (滨江大道) on the south bank, heading west past the Grand Theatre (云海大剧院);
#   - a spiral ramp climbing round over the avenue onto the Jiangxin Bridge (江心大桥), a red through-arch, north;
#   - off the bridge, a tight left and a descending chicane down to the shore road: gravel at the water's edge under the
#     bluff, a jump over a sand barge moored in an inlet and one over a boat slipway, boulders along the river side;
#   - the switchbacks of the old town (老街): four legs and three hairpins up the bluff's face between terraces of old
#     whitewashed houses and stone stairs, under the gondola lift climbing from the shore to the heights;
#   - north on the heights between the Liangjiang towers under their sky gallery (云廊), east past the Yunhai Center;
#   - down the Shuangjiang Tunnel (双江隧道) through the bluff, out onto the confluence's beach, the finish on the
#     Chaotian plaza (朝天广场) facing where the rivers meet.
# The Shuangjiang suspension bridge spans the tributary to the north-east (scenery).
# Built on YunhaiStage.gd (the Yunhai GP's base) on the Miyoshino GP's stage base: decks on hammerhead piers, the city.
# Daylight: the city's windows unlit, no LED shows or media facades (they are the night stages').

## Heights along the run: [plan point on it, height]; a height of NAT means the natural ground there (+ GROUND_UNDER).
## Each point is clear of where the run crosses itself (the spiral over the avenue at (-600, 420)).
const NAT := -999.0
const KNOTS := [
	[Vector2(40.0, 420.0), 8.5], [Vector2(-560.0, 420.0), 8.5], [Vector2(-720.0, 470.0), 10.5], [Vector2(-660.0, 530.0), 12.5],
	[Vector2(-600.0, 480.0), 15.5], [Vector2(-600.0, 360.0), 18.5], [Vector2(-600.0, 215.0), 22.0], [Vector2(-600.0, -200.0), 22.0],
	[Vector2(-600.0, -290.0), 19.5], [Vector2(-500.0, -330.0), 13.0], [Vector2(-340.0, -330.0), 6.5], [Vector2(-300.0, -290.0), 4.0],
	[Vector2(-250.0, -260.0), 2.8], [Vector2(-150.0, -260.0), 2.6], [Vector2(300.0, -260.0), 2.6], [Vector2(340.0, -300.0), 3.2],
	[Vector2(250.0, -322.0), 4.0], [Vector2(0.0, -322.0), 8.0], [Vector2(-40.0, -342.0), 9.0], [Vector2(0.0, -362.0), 10.5],
	[Vector2(100.0, -362.0), 17.0], [Vector2(140.0, -382.0), 18.5], [Vector2(100.0, -402.0), 20.5], [Vector2(0.0, -402.0), 27.0],
	[Vector2(-40.0, -422.0), 28.5], [Vector2(0.0, -442.0), 30.0], [Vector2(150.0, -442.0), 32.5], [Vector2(185.0, -520.0), 33.0],
	[Vector2(185.0, -680.0), NAT], [Vector2(185.0, -820.0), NAT], [Vector2(300.0, -880.0), NAT], [Vector2(470.0, -840.0), 37.5],
	[Vector2(470.0, -600.0), 4.6], [Vector2(470.0, -520.0), 3.4], [Vector2(470.0, -240.0), 3.4],
]
## The river: its banks at |z| RIVER_HALF_W; the tributary along TRIB_X, TRIB_HALF wide each side, north of the river.
const RIVER_HALF_W := 205.0
const TRIB_X := 700.0
const TRIB_HALF := 150.0
## The jumps on the shore road: [lip (plan), gap, the inlet the gap crosses (water), kicker length and height, name].
const JUMPS := [
	[Vector2(0.0, -260.0), 36.0, Rect2(3.0, -300.0, 30.0, 100.0), 9.0, 1.6, "Jump_Barge"],
	[Vector2(185.0, -260.0), 24.0, Rect2(188.0, -300.0, 20.0, 100.0), 8.0, 1.3, "Jump_Slipway"],
]
## The arch bridge along x ARCH_X.
const ARCH_X := -600.0
## The Liangjiang towers (the run passes between the first two) and their crystal gallery; the Yunhai Center.
const CRYSTAL_X := [140.0, 230.0, 320.0, 410.0]
const CRYSTAL_Z := -680.0
const SUPERTALL_AT := Vector2(320.0, -1000.0)
## The riverside park between the avenue and the river's south bank; the Grand Theatre south of the avenue.
const RIVERSIDE := Rect2(-760.0, 230.0, 1200.0, 168.0)
const THEATRE := Rect2(-370.0, 440.0, 190.0, 80.0)
## Where the bluff behind the shore road turns north (the shore broadening into the confluence's beach).
const BLUFF_X0 := 170.0
const BLUFF_X1 := 260.0
const BLUFF_RECEDE := 260.0
## The old town between the switchbacks' legs (their z), the stairway up it, the gondola lift's line (x) and stations.
const LEGS_Z := [-322.0, -362.0, -402.0, -442.0]
const LEGS_X := Vector2(-40.0, 140.0)
const STAIR_X := -8.0
const GONDOLA_X := 60.0
const GONDOLA_A := Vector3(60.0, 14.0, -226.0)
const GONDOLA_B := Vector3(60.0, 62.0, -522.0)
const GONDOLA_SAG := 6.0
## The finish plaza at the peninsula's tip.
const PLAZA := Rect2(398.0, -450.0, 150.0, 222.0)
## The Shuangjiang suspension bridge across the tributary (scenery): its deck along z SUSP_Z from SUSP_X0 to SUSP_X1,
## towers at SUSP_TOWERS, the deck SUSP_DECK up.
const SUSP_Z := -650.0
const SUSP_X0 := 470.0
const SUSP_X1 := 1010.0
const SUSP_TOWERS := [610.0, 790.0]
const SUSP_DECK := 33.0
const SUSP_TOP := 112.0
## The tunnel's lining: walls `TUN_HALF` from the middle, the ceiling `TUN_H` over the road.
const TUN_HALF := 8.6
const TUN_H := 7.4

var _a := {}
## Colliders for the props the batches can't give (they are wider than DressingColliders takes, or chunked).
var _solid_body: StaticBody3D


func _configure() -> void:
	level_name = "ShuangjiangLevel"
	level_path = "res://levels/ShuangjiangLevel.tscn"
	stem = "shuangjiang"
	title = "Shuangjiang"
	seed_base = 8400
	road_half = 7.5
	max_grade = 0.16
	closed = false
	point_to_point = true
	start_s = 180.0
	finish_runout = 120.0
	corners = [
		[Vector2(40.0, 420.0), 0.0],
		[Vector2(-720.0, 420.0), 50.0],
		[Vector2(-720.0, 530.0), 50.0],
		[Vector2(-600.0, 530.0), 50.0],
		[Vector2(-600.0, -330.0), 35.0],
		[Vector2(-300.0, -330.0), 30.0],
		[Vector2(-300.0, -260.0), 30.0],
		[Vector2(340.0, -260.0), 28.0],
		[Vector2(340.0, LEGS_Z[0]), 28.0],
		[Vector2(LEGS_X.x, LEGS_Z[0]), 18.0],
		[Vector2(LEGS_X.x, LEGS_Z[1]), 18.0],
		[Vector2(LEGS_X.y, LEGS_Z[1]), 18.0],
		[Vector2(LEGS_X.y, LEGS_Z[2]), 18.0],
		[Vector2(LEGS_X.x, LEGS_Z[2]), 18.0],
		[Vector2(LEGS_X.x, LEGS_Z[3]), 18.0],
		[Vector2(185.0, LEGS_Z[3]), 40.0],
		[Vector2(185.0, -880.0), 60.0],
		[Vector2(470.0, -880.0), 60.0],
		[Vector2(470.0, -240.0), 0.0],
	]
	fine_x = Vector2(-900.0, 1050.0)
	fine_z = Vector2(-1150.0, 700.0)
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
	city_tall = Vector2(95.0, 60.0)
	city_seed = 4417
	park_rect = RIVERSIDE
	river_half = RIVER_HALF_W
	water_y = 0.0
	skyline_clusters = [Vector2(-300.0, -1700.0), Vector2(1400.0, -900.0), Vector2(-1500.0, 900.0), Vector2(900.0, 1500.0), Vector2(2200.0, 200.0)]


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
		# The peninsula: a shore of gravel at 2.5m, then the bluff (receding north toward the tip, so the beach broadens
		# there), the heights above.
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
	# The inlets the jumps cross (the barge's, the slipway's).
	for j in JUMPS:
		var inlet: Rect2 = j[2]
		if inlet.grow(4.0).has_point(Vector2(x, z)):
			var e: float = minf(minf(x - inlet.position.x, inlet.end.x - x), inlet.end.y - z)
			e = minf(e, z - inlet.position.y)
			h = lerpf(h, -6.0, smoothstep(-2.0, 2.0, e))
	# Hills round the far city.
	var r: float = Vector2(x, z).distance_to(city_mid)
	var hill: float = smoothstep(2400.0, 4200.0, r) * (170.0 + 120.0 * n_ridge.get_noise_2d(x * 0.6, z * 0.6))
	return h + maxf(hill, 0.0)


func _ground_params(m: ShaderMaterial) -> void:
	super(m)
	m.set_shader_parameter("shore_y", 3.4)
	m.set_shader_parameter("slope_grass", 1.0)
	m.set_shader_parameter("lamp_energy", 0.0)


## Steep cuttings (stone-faced, as the city's are) along the switchbacks and into the tunnel: the trench under the
## tunnel's lid stays narrow.
func _grade_params(r: Route, s: float) -> Array:
	var p: Array = super(r, s)
	if r == lap and not _a.is_empty():
		if s > float(_a["tun0"]) - 90.0 and s < float(_a["tun1"]) + 30.0:
			p[2] = 4.0
		elif s > float(_a["sw0"]) and s < float(_a["sw1"]):
			p[2] = 1.5
	return p


# ======================================================================================
#  The run's heights
# ======================================================================================

func _knot_y(k: Array) -> float:
	var q: Vector2 = k[0]
	var y: float = k[1]
	return (_natural(q.x, q.y) if y == NAT else y) + GROUND_UNDER


func _shape_heights(r: Route, ys: PackedFloat32Array) -> void:
	if r != lap:
		return
	var n: int = ys.size()
	var ks: Array = []
	for k in KNOTS:
		ks.append([lap.closest_s(k[0] as Vector2), _knot_y(k)])
	ks.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	ks.push_front([0.0, float(ks[0][1])])
	ks.append([lap.length, float(ks[ks.size() - 1][1])])
	var jumps: Array = []
	for j in JUMPS:
		var lip: float = lap.closest_s(j[0] as Vector2)
		jumps.append([lip, lip + float(j[1])])
	var raw := PackedFloat32Array()
	raw.resize(n)
	var k := 0
	for i in range(n):
		var s := float(i)
		while k < ks.size() - 2 and s > float(ks[k + 1][0]):
			k += 1
		var t: float = clampf((s - float(ks[k][0])) / maxf(float(ks[k + 1][0]) - float(ks[k][0]), 0.001), 0.0, 1.0)
		raw[i] = lerpf(float(ks[k][1]), float(ks[k + 1][1]), t)
	for i in range(n):
		var in_jump := false
		for jr in jumps:
			if float(i) > float(jr[0]) - 10.0 and float(i) < float(jr[1]) + 10.0:
				in_jump = true
		if in_jump:
			ys[i] = raw[i]
			continue
		var acc := 0.0
		var cnt := 0
		for d in range(-12, 13):
			var jj: int = clampi(i + d, 0, n - 1)
			acc += raw[jj]
			cnt += 1
		ys[i] = acc / float(cnt)
	_a = {"jumps": jumps, "shore0": lap.closest_s(Vector2(-300.0, -275.0)), "shore1": lap.closest_s(Vector2(340.0, -275.0)),
		"sw0": lap.closest_s(Vector2(300.0, LEGS_Z[0])), "sw1": lap.closest_s(Vector2(150.0, LEGS_Z[3])),
		"cross": lap.closest_s(Vector2(-600.0, 400.0)), "plaza": lap.closest_s(Vector2(470.0, PLAZA.position.y))}
	# The tunnel: where the road runs more than its lining's height under the natural ground on the way down to the tip.
	var t0 := -1.0
	var t1 := -1.0
	var s_from: float = lap.closest_s(Vector2(470.0, -870.0))
	for i in range(int(s_from), n):
		var p: Vector2 = lap.at(float(i))["p"]
		if _natural(p.x, p.y) - ys[i] > TUN_H + 0.8:
			if t0 < 0.0:
				t0 = float(i)
			t1 = float(i)
	_a["tun0"] = t0
	_a["tun1"] = t1
	# Bridges: every stretch more than 3m over the natural ground, and over the inlets.
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
		bridges.append(["lap", b0, lap.length, 0.0, true])
	for jr in jumps:
		bridges.append(["lap", float(jr[0]) - 3.0, float(jr[1]) + 3.0, 0.0, true])
	print("  run %.0fm, jumps at %s, tunnel %.0f-%.0f, bridges %s" % [lap.length, str(jumps.map(func(j): return "%.0f" % j[0])), t0, t1,
			str(bridges.map(func(b): return "%.0f-%.0f" % [b[1], b[2]]))])


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
	var j: Array = _a["jumps"]
	return [[0.0, s0, K_ASPHALT, r.half], [s0, float(j[0][0]), K_GRAVEL, r.half], [float(j[0][1]), float(j[1][0]), K_GRAVEL, r.half],
		[float(j[1][1]), s1, K_GRAVEL, r.half], [s1, float(_a["sw1"]), K_STONE, r.half], [float(_a["sw1"]), r.length, K_ASPHALT, r.half]]


func _build_deck_slab(_node: Node3D, _r: Route, _s0: float, _s1: float, _idx: int) -> void:
	pass


func _is_bridge(s: float) -> bool:
	for b in bridges:
		if s >= float(b[1]) and s <= float(b[2]):
			return true
	return false


func _in_jump(s: float, margin := 0.0) -> bool:
	for jr in _a["jumps"]:
		if s > float(jr[0]) - margin and s < float(jr[1]) + margin:
			return true
	return false


func _in_tunnel(s: float, margin := 0.0) -> bool:
	return s > float(_a["tun0"]) - margin and s < float(_a["tun1"]) + margin


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
	for q in [Vector2(-600.0, 0.0), Vector2(-440.0, -330.0), Vector2(100.0, -260.0), Vector2(150.0, LEGS_Z[0]), Vector2(50.0, LEGS_Z[2]),
			Vector2(185.0, -600.0), Vector2(330.0, -880.0), Vector2(470.0, -540.0)]:
		cps.append(lap.closest_s(q))
	_checkpoints(cps)
	var j: Array = _a["jumps"]
	_boosts([["Boost_Avenue", lap.closest_s(Vector2(-420.0, 420.0)), 2.5], ["Boost_Shore", float(j[0][0]) - 70.0, -2.5],
		["Boost_Heights", lap.closest_s(Vector2(185.0, -560.0)), 0.0], ["Boost_Beach", lap.closest_s(Vector2(470.0, -560.0)), 2.5]])
	for i in range(JUMPS.size()):
		var jd: Array = JUMPS[i]
		var lip: float = j[i][0]
		_kicker(root, String(jd[5]), lap, lip - float(jd[3]), float(jd[3]), float(jd[4]), 0.5, false, Color(0.45, 0.38, 0.3))


# ======================================================================================
#  The dressing
# ======================================================================================

## Air taxis: along the river west of the confluence, up the tributary over the suspension bridge, over the park.
const TAXI_ROUTES: Array = [
	{"points": [Vector3(-500, 60, -120), Vector3(-150, 62, -140), Vector3(400, 60, -125), Vector3(425, 62, 120), Vector3(-150, 62, 140),
		Vector3(-500, 60, 130)], "speed": 24.0, "count": 2},
	{"points": [Vector3(650, 90, -300), Vector3(750, 92, -300), Vector3(752, 94, -1100), Vector3(648, 92, -1100)], "speed": 22.0, "count": 1},
	{"points": [Vector3(-660, 46, 300), Vector3(150, 48, 300), Vector3(170, 50, 345), Vector3(-660, 48, 355)], "speed": 20.0, "count": 2},
]

func _build_dressing(root: Node3D) -> void:
	_load_cjk_font()
	# Daylight: the windows unlit, the LED shows and media facades dark (the kit's materials are shared by everything
	# built here), a little glow left in the neon.
	(MCK.material("tower") as ShaderMaterial).set_shader_parameter("lit_energy", 0.08)
	(MCK.material("tower") as ShaderMaterial).set_shader_parameter("led_energy", 0.0)
	(MCK.material("led") as ShaderMaterial).set_shader_parameter("energy", 0.0)
	(MCK.material("neon") as ShaderMaterial).set_shader_parameter("energy", 0.8)
	_rails = _body(root, "RoadRailsBody")
	_rails.set_meta(&"surface", "rock")
	_solid_body = _body(root, "PropsSolidBody")
	_solid_body.set_meta(&"surface", "rock")
	_sample_route()
	_reserved.append(Rect2(BLUFF_X0, -580.0, TRIB_X - TRIB_HALF - BLUFF_X0, 380.0))
	_reserved.append(Rect2(CRYSTAL_X[0] - 40.0, CRYSTAL_Z - 40.0, CRYSTAL_X[3] - CRYSTAL_X[0] + 80.0, 80.0))
	_reserved.append(Rect2(SUPERTALL_AT - Vector2(95, 95), Vector2(190, 190)))
	_reserved.append(RIVERSIDE)
	_reserved.append(THEATRE.grow(25.0))
	_reserved.append(Rect2(-800.0, -300.0, 1300.0, 90.0))
	_reserved.append(Rect2(-80.0, -560.0, 260.0, 260.0))
	_reserved.append(Rect2(-790.0, 360.0, 260.0, 240.0))
	_reserved.append(Rect2(440.0, -900.0, 60.0, 380.0))
	_build_road_decks()
	_build_lamps()
	_build_arch_bridge()
	_build_suspension_bridge()
	_build_shore()
	_build_beach()
	_build_barges()
	_build_landmarks()
	_build_theatre()
	_build_old_town()
	_build_gondola(root)
	_build_tunnel(root)
	_build_finish_plaza()
	_build_riverside_park()
	_build_mist(root)
	_build_city()
	_build_skyline(root)
	_build_crowds()
	_build_air_taxis(root, TAXI_ROUTES)
	print("  dressing: %d buildings, %d people" % [_bid, _people.size()])


## The older riverside city by day: no media facades, and lower, older blocks of flats near the water.
func _plot_tweak(plot: Rect2, d: Dictionary) -> void:
	if int(d["style"]) == MCK.STYLE_MEDIA:
		d["style"] = MCK.STYLE_OFFICE
	var c: Vector2 = plot.get_center()
	var rd: float = _river_d(c.x, c.y)
	if rd < RIVER_HALF_W + 260.0:
		var g: float = _plot_ground(plot)
		d["top"] = minf(float(d["top"]), g + lerpf(26.0, 48.0, clampf((rd - RIVER_HALF_W) / 260.0, 0.0, 1.0)) + float(_bid % 5) * 3.0)
		d["style"] = MCK.STYLE_FLATS
		d["podium"] = 0.0


## No piers under the arch's span, the gondola's line or the tunnel's lid.
func _col_blocked(p: Vector3, _g: float) -> bool:
	if absf(p.x - ARCH_X) < 30.0 and absf(p.z) < 214.0:
		return true
	return false


func _build_road_decks() -> void:
	var L: float = lap.length
	var cuts: Array = [0.0, L, float(_a["tun0"]), float(_a["tun1"]), float(_a["shore0"]), float(_a["shore1"])]
	for jr in _a["jumps"]:
		cuts.append(float(jr[0]))
		cuts.append(float(jr[1]))
	for b in bridges:
		cuts.append(float(b[1]))
		cuts.append(float(b[2]))
	cuts.sort()
	var k := 0
	for i in range(cuts.size() - 1):
		var s0: float = cuts[i]
		var s1: float = cuts[i + 1]
		var mid: float = (s0 + s1) * 0.5
		if s1 - s0 < 1.0 or _in_jump(mid):
			continue
		var up: bool = _is_bridge(mid)
		var shore: bool = mid > float(_a["shore0"]) and mid < float(_a["shore1"])
		# The shore road has no parapets on its river side (a kerb of boulders, `_build_shore`), only on the bluff's; the
		# tunnel has its walls.
		var rails: Array = [true, true]
		if shore and not up:
			rails = [true, false]
		if _in_tunnel(mid):
			rails = [false, false]
		_deck("deck_road_%d" % k, s0, s1, 2.2 if up else 0.4, Color(1.0, 0.7, 0.4, 0.0), 34.0 if up else 0.0, rails, 0.0, true)
		k += 1


func _build_lamps() -> void:
	_city("deck_road_lamps", func(pk: PropKit, kit: Dictionary, _l: Array) -> void:
		var s := 10.0
		var k := 0
		while s < lap.length - 5.0:
			var bare: bool = (s > float(_a["shore0"]) - 10.0 and s < float(_a["sw1"]) + 10.0) or _in_tunnel(s, 20.0)
			if not bare:
				var side: float = -1.0 if k % 2 == 0 else 1.0
				var b: Vector3 = lap.pt(s) + lap.rt(s) * side * (road_half + 0.7) + Vector3(0, 1.1, 0)
				pk.tube(kit, "steel", b, b + Vector3(0, 10.0, 0), 0.16, 0.11, 6, Color(0.4, 0.41, 0.44))
				var head: Vector3 = b + Vector3(0, 10.0, 0) - lap.rt(s) * side * 2.6
				pk.beam(kit, "steel", b + Vector3(0, 10.0, 0), head, 0.12, 0.12, Color(0.4, 0.41, 0.44))
				pk.block(kit, "paint", head + Vector3(-0.6, -0.18, -0.35), head + Vector3(0.6, 0.0, 0.35), Color(0.75, 0.74, 0.7))
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
				pk.beam(kit, "gloss", u, l, 0.6, 0.6, red)
				if l.y > deck + 2.0:
					pk.beam(kit, "steel", l, Vector3(x - side * 1.5, deck - 0.2, z), 0.12, 0.12, Color(0.5, 0.5, 0.52))
				if side > 0.0 and l.y > deck + 14.0 and k % 2 == 0:
					pk.beam(kit, "gloss", Vector3(ARCH_X - 11.0, l.y, z), Vector3(ARCH_X + 11.0, l.y, z), 0.6, 0.8, red)
					pk.beam(kit, "gloss", Vector3(ARCH_X - 11.0, l.y, z), Vector3(ARCH_X + 11.0, u.y, z + 10.0), 0.4, 0.4, red)
				prev_u = u
				prev_l = l
				z += 10.0
				k += 1
			for zs in [-half, half]:
				pk.block(kit, "tower", Vector3(x - 4.0, -8.0, zs - 6.0), Vector3(x + 4.0, 4.0, zs + 6.0), Color(0.6, 0.6, 0.6, float(MCK.STYLE_CONCRETE) / 8.0))
		for side2 in [-1.0, 1.0]:
			pk.beam(kit, "gloss", Vector3(ARCH_X + side2 * 9.5, deck - 0.8, -half), Vector3(ARCH_X + side2 * 9.5, deck - 0.8, half), 1.2, 1.6, red)
		for face in [-1.0, 1.0]:
			MCK.neon_sign(pk, kit, labels, Vector3(ARCH_X, _arch_y(0.0) - 12.0, face * 2.0), Vector3(0, 0, face), 16.0, 3.0, "江心大桥", Color(1.0, 0.85, 0.5))
	, 4200.0)


# ---- The Shuangjiang Bridge: a suspension bridge across the tributary (scenery) ------------------------------------

## The deck's height at x: level over the river, its east approach falling to the north district's ground.
func _susp_deck(x: float) -> float:
	var ground: float = _natural(SUSP_X1, SUSP_Z) + 0.3
	return lerpf(SUSP_DECK, ground, smoothstep(860.0, SUSP_X1, x))


func _cable_y(x: float) -> float:
	var t0: float = SUSP_TOWERS[0]
	var t1: float = SUSP_TOWERS[1]
	var mid_x: float = (t0 + t1) * 0.5
	var half: float = (t1 - t0) * 0.5
	if x >= t0 and x <= t1:
		var f: float = (x - mid_x) / half
		var mid: float = SUSP_DECK + 3.5
		return mid + (SUSP_TOP - mid) * f * f
	# The side spans: from the tower's top down to the anchor on the deck's edge.
	var end_x: float = SUSP_X0 + 25.0 if x < t0 else 900.0
	var tw: float = t0 if x < t0 else t1
	var t: float = clampf(absf(x - tw) / absf(end_x - tw), 0.0, 1.0)
	return lerpf(SUSP_TOP, _susp_deck(end_x) + 2.0, t) - 6.0 * t * (1.0 - t)


func _build_suspension_bridge() -> void:
	var white := Color(0.9, 0.9, 0.92)
	var w := 11.0
	_city("bridge_suspension", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		# The deck: a box girder with parapets, every 10m.
		var x: float = SUSP_X0
		while x < SUSP_X1 - 0.1:
			var xb: float = minf(x + 10.0, SUSP_X1)
			var ya: float = _susp_deck(x)
			var yb: float = _susp_deck(xb)
			pk.quad(kit, "paint", [Vector3(x, ya, SUSP_Z - w), Vector3(xb, yb, SUSP_Z - w), Vector3(xb, yb, SUSP_Z + w), Vector3(x, ya, SUSP_Z + w)],
					Vector3.UP, Color(0.24, 0.24, 0.25))
			pk.quad(kit, "paint", [Vector3(x, ya - 2.4, SUSP_Z + w), Vector3(xb, yb - 2.4, SUSP_Z + w), Vector3(xb, yb - 2.4, SUSP_Z - w), Vector3(x, ya - 2.4, SUSP_Z - w)],
					Vector3.DOWN, Color(0.75, 0.75, 0.77))
			for side in [-1.0, 1.0]:
				var zz: float = SUSP_Z + side * w
				pk.quad(kit, "paint", [Vector3(x, ya - 2.4, zz), Vector3(xb, yb - 2.4, zz), Vector3(xb, yb + 1.1, zz), Vector3(x, ya + 1.1, zz)] if side > 0.0
						else [Vector3(xb, yb - 2.4, zz), Vector3(x, ya - 2.4, zz), Vector3(x, ya + 1.1, zz), Vector3(xb, yb + 1.1, zz)],
						Vector3(0, 0, side), white)
				pk.quad(kit, "paint", [Vector3(x, ya + 1.1, zz), Vector3(xb, yb + 1.1, zz), Vector3(xb, yb + 1.1, zz - side * 0.4), Vector3(x, ya + 1.1, zz - side * 0.4)],
						Vector3.UP, white)
			x = xb
		# Piers under the approaches (none under the main span or over the water's middle).
		var px: float = SUSP_X0 + 20.0
		while px < SUSP_X1 - 10.0:
			if (px < SUSP_TOWERS[0] - 20.0 or px > SUSP_TOWERS[1] + 20.0) and _susp_deck(px) - _natural(px, SUSP_Z) > 4.0:
				var g: float = minf(_natural(px, SUSP_Z), 0.0) if _natural(px, SUSP_Z) < 0.5 else _natural(px, SUSP_Z)
				_hammerhead(pk, kit, Vector3(px, _susp_deck(px), SUSP_Z), Vector3(0, 0, 1), g - 4.0, 2.4, w)
			px += 40.0
		for xt in SUSP_TOWERS:
			for side in [-1.0, 1.0]:
				var zt: float = SUSP_Z + side * (w + 1.5)
				pk.box(kit, "gloss", Transform3D(Basis(), Vector3(xt, (SUSP_TOP - 12.0) * 0.5, zt)), Vector3(5.0, SUSP_TOP + 12.0, 3.2), white)
				pk.block(kit, "neon", Vector3(xt - 0.5, SUSP_TOP + 0.2, zt - 0.5), Vector3(xt + 0.5, SUSP_TOP + 1.2, zt + 0.5), Color(1.0, 0.1, 0.05))
			for by in [SUSP_DECK - 2.6, 72.0, SUSP_TOP - 4.0]:
				pk.box(kit, "gloss", Transform3D(Basis(), Vector3(xt, by, SUSP_Z)), Vector3(4.0, 3.0, 2.0 * w + 6.4), white)
			pk.block(kit, "tower", Vector3(xt - 8.0, -8.0, SUSP_Z - 16.0), Vector3(xt + 8.0, 3.0, SUSP_Z + 16.0), Color(0.6, 0.6, 0.6, float(MCK.STYLE_CONCRETE) / 8.0))
			for face in [-1.0, 1.0]:
				MCK.neon_sign(pk, kit, labels, Vector3(xt + face * 2.1, 72.0, SUSP_Z), Vector3(face, 0, 0), 18.0, 2.6, "双江大桥", Color(1.0, 0.85, 0.5))
		# The main cables and hangers.
		for side2 in [-1.0, 1.0]:
			var z2: float = SUSP_Z + side2 * (w + 1.5)
			var prev := Vector3.ZERO
			var cx: float = SUSP_X0 + 25.0
			var k := 0
			while cx <= 900.0 + 0.1:
				var p := Vector3(cx, _cable_y(cx), z2)
				if k > 0:
					pk.beam(kit, "gloss", prev, p, 0.8, 0.8, white)
				if cx > SUSP_TOWERS[0] + 3.0 and cx < SUSP_TOWERS[1] - 3.0 and p.y > _susp_deck(cx) + 2.0:
					pk.beam(kit, "steel", p, Vector3(cx, _susp_deck(cx) - 0.6, z2), 0.12, 0.12, Color(0.55, 0.56, 0.6))
				prev = p
				cx += 10.0
				k += 1
			for xa in [SUSP_X0 + 25.0, 900.0]:
				var ya2: float = _susp_deck(xa)
				pk.block(kit, "gloss", Vector3(xa - 4.0, ya2 - 1.0, z2 - 1.4), Vector3(xa + 4.0, ya2 + 2.6, z2 + 1.4), white)
	, 4200.0)
	# Its deck is solid (anyone driving off the heights onto it), boxes every 10m.
	var x2: float = SUSP_X0
	while x2 < SUSP_X1 - 0.1:
		var xb2: float = minf(x2 + 10.0, SUSP_X1)
		var ya3: float = _susp_deck(x2)
		var yb3: float = _susp_deck(xb2)
		var mid := Vector3((x2 + xb2) * 0.5, (ya3 + yb3) * 0.5 - 1.0, SUSP_Z)
		var ang: float = atan2(yb3 - ya3, xb2 - x2)
		_box_shape(_solid_body, Transform3D(Basis(Vector3.BACK, ang), mid), Vector3(xb2 - x2 + 0.4, 2.0, 2.0 * w))
		for side3 in [-1.0, 1.0]:
			_box_shape(_solid_body, Transform3D(Basis(Vector3.BACK, ang), mid + Vector3(0, 1.6, side3 * (w - 0.2))), Vector3(xb2 - x2 + 0.4, 2.2, 0.4))
		x2 = xb2


# ---- The shore road's surroundings -----------------------------------------------------------------------------------

## The retaining wall along the bluff's foot behind the shore road, sampans on the gravel, heaps of sand, a kerb of
## boulders on the river side.
func _build_shore() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6161
	var s0: float = float(_a["shore0"]) + 20.0
	var s1: float = float(_a["shore1"]) - 30.0
	_city("shore", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		var s: float = s0
		var wall_end: float = lap.closest_s(Vector2(BLUFF_X0 + 10.0, -260.0))
		while s < s1:
			var sb: float = minf(s + 8.0, s1)
			var near_jump: bool = _in_jump(s, 5.0) or _in_jump(sb, 5.0)
			if s < wall_end and not near_jump:
				var a: Vector3 = lap.pt(s) - lap.rt(s) * (road_half + 10.0)
				var b: Vector3 = lap.pt(sb) - lap.rt(sb) * (road_half + 10.0)
				var top: float = maxf(_ground_at(a.x, a.z - 12.0), a.y + 5.0)
				MCK.wall(pk, kit, Vector3(b.x, 0, b.z), Vector3(a.x, 0, a.z), a.y - 1.0, top, Vector3(0, 0, 1), Color(0.5, 0.48, 0.42), MCK.STYLE_CONCRETE, 91)
			var gp: Vector3 = lap.pt(s)
			if not near_jump and absf(gp.x - GONDOLA_X) > 14.0:
				var rp: Vector3 = lap.pt(s) + lap.rt(s) * (road_half + rng.randf_range(1.5, 3.5))
				rp.y = _ground_at(rp.x, rp.z)
				_boulders(pk, kit, rp, rng.randf_range(1.2, 2.2), rng)
			s = sb
		var x := -200.0
		while x < 340.0:
			if absf(x - 18.0) > 40.0 and absf(x - 198.0) > 26.0 and absf(x - GONDOLA_X) > 22.0:
				var c := Vector3(x, 0.0, -233.0)
				c.y = _ground_at(c.x, c.z)
				_sampan(pk, kit, Vector2(c.x, c.z), 0.0, c.y)
				var heap := Vector3(x + 25.0, 0.0, -246.0)
				if absf(heap.x - 198.0) > 22.0 and absf(heap.x - GONDOLA_X) > 16.0 and absf(heap.x - 18.0) > 24.0:
					heap.y = _ground_at(heap.x, heap.z)
					_sand_heap(pk, kit, heap, 5.0, 2.4)
			x += 90.0
	, 1400.0)


## A heap of river boulders, each one solid (a sphere a little inside its shape).
func _boulders(pk: PropKit, kit: Dictionary, c: Vector3, r: float, rng: RandomNumberGenerator) -> void:
	for i in range(rng.randi_range(3, 6)):
		var a: float = rng.randf() * TAU
		var d: float = rng.randf() * r * 0.6
		var sz: float = r * rng.randf_range(0.3, 0.6)
		var p := c + Vector3(cos(a) * d, sz * 0.3, sin(a) * d)
		var prof: Array = [Vector2(0.001, -sz * 0.5), Vector2(sz * 0.8, -sz * 0.4), Vector2(sz, 0.0), Vector2(sz * 0.7, sz * 0.45), Vector2(0.001, sz * 0.6)]
		pk.lathe(kit, "paint", p, prof, 7, Color(0.4, 0.38, 0.34).lightened(rng.randf_range(-0.1, 0.1)), true, Basis(Vector3.UP, rng.randf() * TAU))
		var cs := CollisionShape3D.new()
		var sp := SphereShape3D.new()
		sp.radius = sz * 0.82
		cs.shape = sp
		cs.position = p
		_solid_body.add_child(cs)


## A sampan pulled up on the shore (and its box).
func _sampan(pk: PropKit, kit: Dictionary, c: Vector2, hd: float, y: float) -> void:
	var fw := Vector2(cos(hd), sin(hd))
	var rt := Vector2(-fw.y, fw.x)
	var hull := PackedVector2Array([c - fw * 5.0 - rt, c + fw * 4.0 - rt, c + fw * 5.5, c + fw * 4.0 + rt, c - fw * 5.0 + rt])
	MCK.prism(pk, kit, hull, y - 0.2, y + 0.8, Color(0.35, 0.25, 0.16), MCK.STYLE_CONCRETE, 92, true)
	var cab: Vector2 = c - fw * 1.0
	pk.lathe(kit, "paint", Vector3(cab.x, y + 0.8, cab.y), [Vector2(1.2, 0.0), Vector2(1.0, 0.8), Vector2(0.001, 1.1)], 6, Color(0.3, 0.32, 0.25))
	_box_shape(_solid_body, Transform3D(Basis(Vector3.UP, -hd), Vector3(c.x, y + 0.3, c.y)), Vector3(10.5, 1.0, 2.0))


## A heap of sand: the cars drive up and over it (a convex cone).
func _sand_heap(pk: PropKit, kit: Dictionary, c: Vector3, r: float, h: float) -> void:
	pk.lathe(kit, "paint", c, [Vector2(r, 0.0), Vector2(r * 0.6, h * 0.58), Vector2(0.001, h)], 10, Color(0.56, 0.49, 0.38))
	var pts := PackedVector3Array()
	for k in range(10):
		var a: float = TAU * float(k) / 10.0
		pts.append(c + Vector3(cos(a) * r, -0.3, sin(a) * r))
		pts.append(c + Vector3(cos(a) * r * 0.6, h * 0.58 - 0.15, sin(a) * r * 0.6))
	pts.append(c + Vector3(0, h - 0.2, 0))
	var cs := CollisionShape3D.new()
	var cv := ConvexPolygonShape3D.new()
	cv.points = pts
	cs.shape = cv
	_solid_body.add_child(cs)


## The sand barge moored in the barge jump's inlet, a fishing boat on the slipway's cradle, barges and river boats on
## the rivers; each solid (hull and superstructure boxes).
func _build_barges() -> void:
	var boats: Array = [
		# [centre, heading (radians), length, beam, cargo: 0 sand, 1 containers, 2 a river cruiser, 3 a boat on a slipway]
		[Vector2(18.0, -252.0), PI * 0.5, 40.0, 12.0, 0],
		[Vector2(198.0, -258.0), PI * 0.5, 16.0, 5.0, 3],
		[Vector2(-380.0, -150.0), 0.05, 70.0, 14.0, 1],
		[Vector2(140.0, 120.0), -0.1, 90.0, 16.0, 1],
		[Vector2(-200.0, 60.0), 0.0, 60.0, 13.0, 2],
		[Vector2(700.0, -520.0), PI * 0.5, 55.0, 12.0, 0],
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
		var fw := Vector2(cos(hd), sin(hd))
		var rt := Vector2(-fw.y, fw.x)
		var top: float = [1.0, 1.8, 1.8, -0.6][kind]
		var bottom: float = -2.0 if kind != 3 else -3.0
		_city("barges", func(pk: PropKit, kit: Dictionary, _labels: Array) -> void:
			var pts := PackedVector2Array()
			for q in [Vector2(-0.5, -0.5), Vector2(0.42, -0.5), Vector2(0.5, -0.25), Vector2(0.5, 0.25), Vector2(0.42, 0.5), Vector2(-0.5, 0.5)]:
				pts.append(c + fw * (q.x * bl) + rt * (q.y * bw))
			var hull_col: Color = [Color(0.25, 0.24, 0.22), Color(0.25, 0.24, 0.22), Color(0.9, 0.9, 0.9), Color(0.2, 0.36, 0.5)][kind]
			MCK.prism(pk, kit, pts, bottom, top, hull_col, MCK.STYLE_CLADDING, id, true)
			if kind == 0:
				for k in range(3):
					var hc: Vector2 = c + fw * ((float(k) - 1.0) * bl * 0.25)
					pk.lathe(kit, "paint", Vector3(hc.x, top, hc.y), [Vector2(bw * 0.4, 0.0), Vector2(bw * 0.25, 0.5), Vector2(0.001, 0.9)], 10, Color(0.68, 0.6, 0.45))
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
			elif kind == 2:
				for dk in range(3):
					var y0: float = top + float(dk) * 3.0
					var sh: float = 2.0 + float(dk) * 4.0
					var cab := PackedVector2Array([c + fw * (-bl * 0.5 + sh) + rt * (-bw * 0.4), c + fw * (bl * 0.35 - sh) + rt * (-bw * 0.4),
						c + fw * (bl * 0.35 - sh) + rt * (bw * 0.4), c + fw * (-bl * 0.5 + sh) + rt * (bw * 0.4)])
					MCK.prism(pk, kit, cab, y0, y0 + 2.8, Color(0.92, 0.92, 0.92), MCK.STYLE_OFFICE, id + dk, true)
			else:
				# A fishing boat on its cradle at the foot of the slipway, its wheelhouse at the river end.
				var wh3: Vector2 = c + fw * (bl * 0.2)
				MCK.prism(pk, kit, MCK.rect_plan(wh3, 1.8, 1.6), top, top + 2.6, Color(0.92, 0.9, 0.84), MCK.STYLE_FLATS, id + 1, true)
				pk.tube(kit, "steel", Vector3(wh3.x, top + 2.6, wh3.y), Vector3(wh3.x, top + 6.0, wh3.y), 0.08, 0.06, 5, Color(0.3, 0.3, 0.3))
		, 2600.0)
		# Solid: the hull, and what stands on it.
		var yaw: float = -hd
		_box_shape(_solid_body, Transform3D(Basis(Vector3.UP, yaw), Vector3(c.x, (top + bottom) * 0.5, c.y)), Vector3(bl, top - bottom, bw))
		if kind == 1:
			_box_shape(_solid_body, Transform3D(Basis(Vector3.UP, yaw), Vector3(c.x, top + 2.6, c.y)), Vector3(bl * 0.8, 5.2, bw * 0.7))
		elif kind == 2:
			_box_shape(_solid_body, Transform3D(Basis(Vector3.UP, yaw), Vector3(c.x - fw.x * bl * 0.07, top + 4.4, c.y - fw.y * bl * 0.07)), Vector3(bl * 0.75, 8.8, bw * 0.8))
		elif kind == 3:
			var wh4: Vector2 = c + fw * (bl * 0.2)
			_box_shape(_solid_body, Transform3D(Basis(Vector3.UP, yaw), Vector3(wh4.x, top + 1.3, wh4.y)), Vector3(3.6, 2.6, 3.2))


# ---- Tianqiao's towers on the heights --------------------------------------------------------------------------------

func _build_landmarks() -> void:
	var id := _id()
	_city("landmarks", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		# The Liangjiang towers and their crystal: four towers, a glass gallery laid across their tops.
		var gal_y := 238.0
		for i in range(CRYSTAL_X.size()):
			var x: float = CRYSTAL_X[i]
			var g: float = _ground_at(x, CRYSTAL_Z) - 2.0
			var h: float = gal_y + (12.0 if i % 3 == 0 else 0.0)
			MCK.tower(pk, kit, Vector2(x, CRYSTAL_Z), 20.0, 20.0, g, h, Color(0.55, 0.62, 0.7), MCK.STYLE_OFFICE, id + i, 6.0, 18.0, true, Color(0.5, 0.85, 1.0, 0.0), false)
		var plan := PackedVector2Array([Vector2(CRYSTAL_X[0] - 12.0, CRYSTAL_Z - 16.0), Vector2(CRYSTAL_X[3] + 12.0, CRYSTAL_Z - 16.0),
			Vector2(CRYSTAL_X[3] + 12.0, CRYSTAL_Z + 16.0), Vector2(CRYSTAL_X[0] - 12.0, CRYSTAL_Z + 16.0)])
		MCK.prism(pk, kit, plan, gal_y - 22.0, gal_y - 4.0, Color(0.7, 0.8, 0.88), MCK.STYLE_OFFICE, id + 6, true)
		# The gallery's underside, glazed in panels the run looks up at between the towers.
		for k in range(14):
			var x0: float = CRYSTAL_X[0] - 12.0 + float(k) * (CRYSTAL_X[3] - CRYSTAL_X[0] + 24.0) / 14.0
			pk.beam(kit, "steel", Vector3(x0, gal_y - 22.2, CRYSTAL_Z - 16.0), Vector3(x0, gal_y - 22.2, CRYSTAL_Z + 16.0), 0.5, 0.6, Color(0.3, 0.32, 0.36))
		MCK.neon_sign(pk, kit, labels, Vector3((CRYSTAL_X[0] + CRYSTAL_X[3]) * 0.5, gal_y - 13.0, CRYSTAL_Z + 16.4), Vector3(0, 0, 1), 40.0, 6.0, "云廊",
				Color(0.4, 0.85, 1.0))
		# The Yunhai Center: the supertall, its crown and spire, over everything; a plaza round its foot.
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
		# The plaza: paving out to 90m, a ring of flagpoles, the name on a low stone.
		var gp: float = _ground_at(c.x, c.y + 60.0)
		MCK.flat(pk, kit, MCK.rect_plan(c, 90.0, 90.0, 20.0), gp + 0.06, Vector3.UP, Color(0.66, 0.64, 0.6), MCK.STYLE_CONCRETE)
		for k2 in range(16):
			var a2: float = TAU * float(k2) / 16.0
			var fp := Vector2(c.x + cos(a2) * 72.0, c.y + sin(a2) * 72.0)
			var fy: float = _ground_at(fp.x, fp.y)
			pk.tube(kit, "steel", Vector3(fp.x, fy, fp.y), Vector3(fp.x, fy + 14.0, fp.y), 0.14, 0.08, 6, Color(0.8, 0.8, 0.82))
			var fc: Color = [Color(0.85, 0.1, 0.1), Color(0.95, 0.75, 0.15), Color(0.2, 0.5, 0.85)][k2 % 3]
			pk.box(kit, "paint", Transform3D(Basis(Vector3.UP, a2), Vector3(fp.x + 1.3, fy + 12.6, fp.y)), Vector3(2.4, 1.6, 0.05), fc)
		MCK.neon_sign(pk, kit, labels, Vector3(c.x, gp + 2.2, c.y + 52.0), Vector3(0, 0, 1), 22.0, 2.4, "云海中心", Color(0.95, 0.85, 0.6))
	, 6000.0)
	# Solid: the landmarks' mesh is too wide for DressingColliders, so the towers' feet get boxes of their own.
	for i2 in range(CRYSTAL_X.size()):
		_note_rect(Vector2(CRYSTAL_X[i2], CRYSTAL_Z), 46.0, 46.0, 0.0)
		var tg: float = _ground_at(CRYSTAL_X[i2], CRYSTAL_Z)
		_box_shape(_solid_body, Transform3D(Basis(), Vector3(CRYSTAL_X[i2], tg + 20.0, CRYSTAL_Z)), Vector3(40.0, 44.0, 40.0))
	var sg: float = _ground_at(SUPERTALL_AT.x, SUPERTALL_AT.y)
	_box_shape(_solid_body, Transform3D(Basis(), Vector3(SUPERTALL_AT.x, sg + 30.0, SUPERTALL_AT.y)), Vector3(92.0, 64.0, 92.0))
	_note_rect(SUPERTALL_AT, 190.0, 190.0, 0.0)


# ---- The Grand Theatre on the south bank -----------------------------------------------------------------------------

## 云海大剧院: a long glass hall on a stone podium beside the start, like a ship moored on the embankment: three glazed
## volumes rising toward the river end, their roofs raked, a stair of broad steps down to the avenue.
func _build_theatre() -> void:
	var r: Rect2 = THEATRE
	var g: float = _plot_ground(r) + 0.4
	var id := _id()
	var podium: float = g + 4.0
	_city("theatre", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		var stone := Color(0.78, 0.74, 0.66)
		MCK.prism(pk, kit, MCK.rect_plan(r.get_center(), r.size.x * 0.5, r.size.y * 0.5, 6.0), g - 3.0, podium, stone, MCK.STYLE_CONCRETE, id, true)
		# The steps down to the avenue along the podium's north side.
		for k in range(8):
			var zs: float = r.position.y - float(k) * 0.9
			pk.block(kit, "paint", Vector3(r.position.x + 20.0, g - 1.0, zs - 0.9), Vector3(r.end.x - 20.0, podium - float(k) * 0.5, zs), stone.darkened(0.04 * float(k % 2)))
		# The glass volumes: each a box whose roof rakes up toward the west (the river end of the "ship").
		var vols: Array = [[Vector2(r.end.x - 38.0, r.get_center().y + 8.0), 30.0, 22.0, 12.0, 20.0], [Vector2(r.get_center().x + 2.0, r.get_center().y - 2.0), 38.0, 28.0, 20.0, 31.0],
			[Vector2(r.position.x + 36.0, r.get_center().y + 6.0), 30.0, 24.0, 30.0, 44.0]]
		var glass := Color(0.16, 0.27, 0.3)
		for v in vols:
			var c: Vector2 = v[0]
			var hx: float = v[1]
			var hz: float = v[2]
			var y_e: float = podium + float(v[3])
			var y_w: float = podium + float(v[4])
			var a := Vector3(c.x - hx, podium, c.y - hz)
			var b := Vector3(c.x + hx, podium, c.y - hz)
			var cc := Vector3(c.x + hx, podium, c.y + hz)
			var d := Vector3(c.x - hx, podium, c.y + hz)
			# Walls (north, south, east, west), a raked roof; mullions every 6m.
			pk.quad(kit, "gloss", [a, b, b + Vector3(0, y_e - podium, 0), a + Vector3(0, y_w - podium, 0)], Vector3(0, 0, -1), glass)
			pk.quad(kit, "gloss", [cc, d, d + Vector3(0, y_w - podium, 0), cc + Vector3(0, y_e - podium, 0)], Vector3(0, 0, 1), glass)
			pk.quad(kit, "gloss", [b, cc, cc + Vector3(0, y_e - podium, 0), b + Vector3(0, y_e - podium, 0)], Vector3(1, 0, 0), glass)
			pk.quad(kit, "gloss", [d, a, a + Vector3(0, y_w - podium, 0), d + Vector3(0, y_w - podium, 0)], Vector3(-1, 0, 0), glass)
			var up := (Vector3(2.0 * hx, y_e - y_w, 0)).cross(Vector3(0, 0, 2.0 * hz)).normalized() * -1.0
			pk.quad(kit, "gloss", [Vector3(a.x, y_w, a.z), Vector3(d.x, y_w, d.z), Vector3(cc.x, y_e, cc.z), Vector3(b.x, y_e, b.z)], up if up.y > 0.0 else -up,
					Color(0.6, 0.72, 0.74))
			var mx: float = c.x - hx
			while mx <= c.x + hx + 0.1:
				var t: float = (mx - (c.x - hx)) / (2.0 * hx)
				var yt: float = lerpf(y_w, y_e, t)
				for zf in [c.y - hz - 0.15, c.y + hz + 0.15]:
					pk.beam(kit, "steel", Vector3(mx, podium, zf), Vector3(mx, yt, zf), 0.3, 0.4, Color(0.9, 0.9, 0.9))
				mx += 5.0
			# Transoms every 4m up the long faces, cut off under the raked roof.
			var ty: float = podium + 4.0
			while ty < y_w - 0.5:
				for zf2 in [c.y - hz - 0.2, c.y + hz + 0.2]:
					var x_end: float = c.x + hx if ty < y_e else c.x - hx + 2.0 * hx * (y_w - ty) / maxf(y_w - y_e, 0.01)
					pk.beam(kit, "steel", Vector3(c.x - hx, ty, zf2), Vector3(minf(x_end, c.x + hx), ty, zf2), 0.3, 0.3, Color(0.9, 0.9, 0.9))
				ty += 4.0
			# The eaves: a white blade along the roof's edges.
			pk.beam(kit, "gloss", Vector3(a.x - 3.0, y_w + 0.5, a.z - 1.2), Vector3(b.x + 3.0, y_e + 0.5, b.z - 1.2), 2.4, 1.0, Color(0.95, 0.95, 0.93))
			pk.beam(kit, "gloss", Vector3(d.x - 3.0, y_w + 0.5, d.z + 1.2), Vector3(cc.x + 3.0, y_e + 0.5, cc.z + 1.2), 2.4, 1.0, Color(0.95, 0.95, 0.93))
			# The prow: the tall west end leans out over the podium, a white fin up its edge.
			pk.beam(kit, "gloss", Vector3(a.x - 3.0, podium, (a.z + d.z) * 0.5), Vector3(a.x - 3.0, y_w + 1.0, (a.z + d.z) * 0.5), 1.2, 1.6, Color(0.95, 0.95, 0.93))
			# Lit from inside a little: the foyer's warm floors.
			pk.block(kit, "neon", Vector3(c.x - hx + 1.0, podium + 5.0, c.y - hz + 1.0), Vector3(c.x + hx - 1.0, podium + 5.3, c.y + hz - 1.0), Color(0.55, 0.42, 0.28))
		MCK.neon_sign(pk, kit, labels, Vector3(r.get_center().x, podium + 2.0, r.position.y - 0.5), Vector3(0, 0, -1), 30.0, 2.6, "云海大剧院", Color(0.95, 0.8, 0.45))
	, 3200.0)
	_box_shape(_solid_body, Transform3D(Basis(), Vector3(r.get_center().x, podium - 3.0, r.get_center().y)), Vector3(r.size.x, 6.0 + 2.0, r.size.y))
	_note_rect(r.get_center(), r.size.x + 20.0, r.size.y + 20.0, 0.0)


# ---- The old town up the bluff ---------------------------------------------------------------------------------------

## 老街: terraces of old whitewashed houses with dark timber frames and grey tiled roofs between the switchbacks' legs,
## facing the river, a stone stairway straight up the face crossing every leg, lanterns. Each house stands on the
## ground at its front (downhill), its back dug into the slope, under the leg above's road.
func _build_old_town() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5353
	var houses: Array = []
	for band in range(3):
		var z_low: float = LEGS_Z[band]
		var z_up: float = LEGS_Z[band + 1]
		var zc: float = (z_low + z_up) * 0.5
		var x: float = LEGS_X.x + 26.0
		while x < LEGS_X.y - 24.0:
			var w: float = rng.randf_range(9.0, 12.0)
			if absf(x - STAIR_X) > 9.0 and absf(x - GONDOLA_X) > 10.0:
				houses.append([Vector2(x, zc), w, 8.0, band])
			x += w + rng.randf_range(2.5, 5.0)
	_city("oldtown", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		for hdat in houses:
			var c: Vector2 = hdat[0]
			var w: float = hdat[1]
			var d: float = hdat[2]
			var band: int = hdat[3]
			var front: float = _ground_at(c.x, c.y + d * 0.5)
			var up_y: float = lap.y(lap.closest_s(Vector2(c.x, LEGS_Z[band + 1])))
			var floors: int = 2 if front + 6.6 < up_y + 3.0 else 1
			_old_house(pk, kit, labels, Vector3(c.x, front - 0.6, c.y), w, d, floors, rng)
		# The stairway: flights straight up the face between the legs, landings at the roads' edges, lanterns.
		for band2 in range(4):
			var z0: float = (-262.0 if band2 == 0 else LEGS_Z[band2 - 1]) - road_half - 0.8
			var z1: float = LEGS_Z[band2] + road_half + 0.8
			if band2 == 0:
				continue
			var y0: float = lap.y(lap.closest_s(Vector2(STAIR_X, LEGS_Z[band2 - 1]))) - 0.05
			var y1: float = lap.y(lap.closest_s(Vector2(STAIR_X, LEGS_Z[band2]))) - 0.05
			var n: int = maxi(int((z0 - z1) / 0.9), 4)
			for k in range(n):
				var f0: float = float(k) / float(n)
				var za: float = lerpf(z0, z1, f0)
				var zb: float = lerpf(z0, z1, float(k + 1) / float(n))
				var yk: float = lerpf(y0, y1, float(k + 1) / float(n))
				pk.block(kit, "paint", Vector3(STAIR_X - 2.2, minf(_ground_at(STAIR_X, za), yk) - 1.5, zb), Vector3(STAIR_X + 2.2, yk, za),
						Color(0.6, 0.58, 0.52).darkened(0.05 * float(k % 2)))
			for k2 in range(1, n, 6):
				var zl: float = lerpf(z0, z1, float(k2) / float(n))
				var yl: float = lerpf(y0, y1, float(k2) / float(n))
				for sx in [-1.0, 1.0]:
					var lp := Vector3(STAIR_X + sx * 2.6, yl, zl)
					pk.tube(kit, "paint", lp, lp + Vector3(0, 3.0, 0), 0.07, 0.07, 5, Color(0.2, 0.16, 0.12))
					MCK.lantern(pk, kit, lp + Vector3(0, 2.5, 0), 0.7)
	, 1400.0)
	for hdat2 in houses:
		var c2: Vector2 = hdat2[0]
		var front2: float = _ground_at(c2.x, c2.y + 4.0)
		_box_shape(_solid_body, Transform3D(Basis(), Vector3(c2.x, front2 + 2.0, c2.y)), Vector3(float(hdat2[1]), 6.0, float(hdat2[2])))
		_note_rect(c2, float(hdat2[1]) + 2.0, float(hdat2[2]) + 2.0, 0.0)
	print("  old town: %d houses" % houses.size())


func _old_house(pk: PropKit, kit: Dictionary, _labels: Array, base: Vector3, w: float, d: float, floors: int, rng: RandomNumberGenerator) -> void:
	var white := Color(0.9, 0.88, 0.82).darkened(rng.randf_range(0.0, 0.12))
	var timber := Color(0.24, 0.16, 0.1)
	var tile := Color(0.3, 0.31, 0.33)
	var fh := 3.2
	var h: float = fh * float(floors)
	var x0: float = base.x - w * 0.5
	var x1: float = base.x + w * 0.5
	var zf: float = base.z + d * 0.5
	var zb: float = base.z - d * 0.5
	# The walls (down past the ground at the back, where the slope rises), a stone plinth at the front.
	pk.block(kit, "paint", Vector3(x0, base.y - 2.0, zb), Vector3(x1, base.y + h, zf), white)
	pk.block(kit, "paint", Vector3(x0 - 0.05, base.y - 1.0, zf - 0.3), Vector3(x1 + 0.05, base.y + 0.8, zf + 0.05), Color(0.5, 0.48, 0.44))
	# Timber frame: corner posts, a beam at each floor, the ground floor's shop boards and doors, the upper's windows.
	for xp in [x0, x1]:
		pk.block(kit, "paint", Vector3(xp - 0.15, base.y, zf - 0.1), Vector3(xp + 0.15, base.y + h, zf + 0.12), timber)
	for f in range(floors + 1):
		pk.block(kit, "paint", Vector3(x0, base.y + fh * float(f) - 0.15, zf - 0.1), Vector3(x1, base.y + fh * float(f) + 0.12, zf + 0.12), timber)
	var nb: int = maxi(int(w / 2.4), 3)
	for k in range(nb):
		var bx0: float = x0 + 0.4 + float(k) * (w - 0.8) / float(nb)
		var bx1: float = bx0 + (w - 0.8) / float(nb) - 0.25
		pk.block(kit, "paint", Vector3(bx0, base.y + 0.8, zf - 0.02), Vector3(bx1, base.y + 2.7, zf + 0.06), timber.lightened(0.12 if k % 2 == 0 else 0.05))
		if floors > 1:
			pk.block(kit, "paint", Vector3(bx0 + 0.25, base.y + fh + 0.9, zf - 0.02), Vector3(bx1 - 0.25, base.y + fh + 2.3, zf + 0.05), Color(0.12, 0.12, 0.13))
	# The upper floor's balcony rail along the front.
	if floors > 1:
		pk.block(kit, "paint", Vector3(x0, base.y + fh + 0.85, zf + 0.6), Vector3(x1, base.y + fh + 0.95, zf + 0.7), timber)
		pk.block(kit, "paint", Vector3(x0, base.y + fh, zf), Vector3(x1, base.y + fh + 0.1, zf + 0.7), timber)
	# The roof: a gable along x, grey tiles, the eaves out over the front and back, the ridge's ends turned up.
	var ry: float = base.y + h
	var ov := 0.9
	var rh: float = d * 0.32
	var fz: float = zf + ov
	var bz: float = zb - ov
	var rx0: float = x0 - 0.6
	var rx1: float = x1 + 0.6
	pk.quad(kit, "paint", [Vector3(rx0, ry, fz), Vector3(rx1, ry, fz), Vector3(rx1, ry + rh, base.z), Vector3(rx0, ry + rh, base.z)], Vector3(0, 0.9, 0.4).normalized(), tile)
	pk.quad(kit, "paint", [Vector3(rx1, ry, bz), Vector3(rx0, ry, bz), Vector3(rx0, ry + rh, base.z), Vector3(rx1, ry + rh, base.z)], Vector3(0, 0.9, -0.4).normalized(), tile)
	pk.quad(kit, "paint", [Vector3(rx0, ry - 0.25, bz), Vector3(rx1, ry - 0.25, bz), Vector3(rx1, ry - 0.25, fz), Vector3(rx0, ry - 0.25, fz)], Vector3.DOWN, timber)
	for xs in [x0, x1]:
		pk.quad(kit, "paint", [Vector3(xs, ry, zb), Vector3(xs, ry, zf), Vector3(xs, ry + rh, base.z), Vector3(xs, ry + rh, base.z)],
				Vector3(signf(xs - base.x), 0, 0), white)
	pk.beam(kit, "paint", Vector3(rx0 - 0.3, ry + rh + 0.35, base.z), Vector3(rx1 + 0.3, ry + rh + 0.35, base.z), 0.35, 0.45, tile.darkened(0.2))
	for xe in [rx0 - 0.3, rx1 + 0.3]:
		pk.box(kit, "paint", Transform3D(Basis(Vector3.BACK, signf(xe - base.x) * 0.6), Vector3(xe, ry + rh + 0.7, base.z)), Vector3(0.9, 0.3, 0.45), tile.darkened(0.2))
	# A red lantern by the door.
	MCK.lantern(pk, kit, Vector3(base.x + w * 0.3, base.y + 2.8, zf + 0.6), 0.6)


# ---- The gondola lift up the bluff -----------------------------------------------------------------------------------

## 江岸缆车: a gondola lift from the shore by the barge to the heights over the old town, its little cabins going round
## (GondolaLift.gd) on two ropes `gauge` apart; a station at each end, towers between the legs.
func _build_gondola(root: Node3D) -> void:
	var gauge := 7.0
	var a := GONDOLA_A
	var b := GONDOLA_B
	_city("gondola", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		for e in [[a, 1.0, "江岸缆车"], [b, -1.0, "云顶站"]]:
			var top: Vector3 = e[0]
			var dir: float = e[1]
			var c := Vector2(top.x, top.z + dir * 6.0)
			var g: float = minf(_ground_at(c.x, c.y), _ground_at(c.x, c.y + dir * 6.0))
			var plan := MCK.rect_plan(c, 9.0, 8.0)
			MCK.prism(pk, kit, plan, minf(g, 0.0) - 2.0 if g < 1.0 else g - 1.0, top.y - 3.0, Color(0.82, 0.8, 0.76), MCK.STYLE_OFFICE, 84, true)
			# The open hall over the platform: a roof on posts where the cabins come round the bullwheel.
			pk.block(kit, "gloss", Vector3(c.x - 10.0, top.y + 2.0, c.y - 9.0), Vector3(c.x + 10.0, top.y + 3.0, c.y + 9.0), Color(0.75, 0.15, 0.12))
			for px in [c.x - 9.0, c.x + 9.0]:
				for pz in [c.y - 8.0, c.y + 8.0]:
					pk.tube(kit, "steel", Vector3(px, top.y - 3.0, pz), Vector3(px, top.y + 2.0, pz), 0.2, 0.2, 6, Color(0.4, 0.4, 0.42))
			pk.lathe(kit, "steel", top + Vector3(0, 0.6, dir * 2.0), [Vector2(gauge * 0.5 + 0.3, 0.0), Vector2(gauge * 0.5 + 0.3, 0.4), Vector2(0.4, 0.4)], 24,
					Color(0.5, 0.5, 0.52))
			MCK.neon_sign(pk, kit, labels, Vector3(c.x, top.y + 4.2, c.y - dir * 9.2), Vector3(0, 0, -dir), 10.0, 1.8, String(e[2]), Color(1.0, 0.3, 0.2))
		# Towers on the slope between the legs: a steel mast, a crossarm with the sheaves.
		for tz in [-342.0, -422.0]:
			var f: float = (tz - a.z) / (b.z - a.z)
			var ty: float = lerpf(a.y, b.y, f) - GONDOLA_SAG * 4.0 * f * (1.0 - f) - 1.0
			var g2: float = _ground_at(a.x, tz)
			pk.tube(kit, "steel", Vector3(a.x, g2 - 1.0, tz), Vector3(a.x, ty, tz), 0.9, 0.6, 8, Color(0.45, 0.47, 0.5))
			pk.beam(kit, "steel", Vector3(a.x - gauge * 0.5 - 0.6, ty, tz), Vector3(a.x + gauge * 0.5 + 0.6, ty, tz), 0.5, 0.6, Color(0.45, 0.47, 0.5))
			_box_shape(_solid_body, Transform3D(Basis(), Vector3(a.x, (g2 + ty) * 0.5, tz)), Vector3(1.6, ty - g2, 1.6))
		# The ropes.
		for side in [-1.0, 1.0]:
			var prev := Vector3.ZERO
			for i in range(31):
				var f2: float = float(i) / 30.0
				var p: Vector3 = a.lerp(b, f2) - Vector3(0, GONDOLA_SAG * 4.0 * f2 * (1.0 - f2), 0) + Vector3(side * gauge * 0.5, 0, 0)
				if i > 0:
					pk.beam(kit, "steel", prev, p, 0.06, 0.06, Color(0.2, 0.2, 0.22))
				prev = p
	, 2600.0)
	for e2 in [a, b]:
		var dir2: float = 1.0 if e2 == a else -1.0
		var c2 := Vector2(e2.x, e2.z + dir2 * 6.0)
		var g3: float = _ground_at(c2.x, c2.y)
		_box_shape(_solid_body, Transform3D(Basis(), Vector3(c2.x, (g3 + e2.y) * 0.5, c2.y)), Vector3(18.0, e2.y - g3 + 2.0, 16.0))
		_note_rect(c2, 22.0, 20.0, 0.0)
	# The cabins: an eight-seat gondola, red and white, its hanger's top at the origin.
	var cab_pk := MCK.new_kit(1.0)
	var ck := {}
	cab_pk.box(ck, "steel", Transform3D(Basis(), Vector3(0, -1.3, 0)), Vector3(0.12, 2.6, 0.12), Color(0.3, 0.3, 0.32))
	cab_pk.box(ck, "gloss", Transform3D(Basis(), Vector3(0, -3.6, 0)), Vector3(2.0, 2.0, 2.4), Color(0.85, 0.14, 0.12))
	cab_pk.box(ck, "gloss", Transform3D(Basis(), Vector3(0, -3.3, 0)), Vector3(2.06, 0.8, 2.2), Color(0.2, 0.26, 0.3))
	cab_pk.box(ck, "gloss", Transform3D(Basis(), Vector3(0, -2.55, 0)), Vector3(2.1, 0.12, 2.5), Color(0.95, 0.95, 0.95))
	var cab_mesh: ArrayMesh = MCK.commit(cab_pk, ck)
	var gl := Node3D.new()
	gl.name = "GondolaLift"
	gl.set_script(load("res://GondolaLift.gd"))
	gl.set("a", a)
	gl.set("b", b)
	gl.set("sag", GONDOLA_SAG)
	gl.set("gauge", gauge)
	gl.set("speed", 4.0)
	gl.set("spacing", 28.0)
	gl.set("cabin", _save_res(cab_mesh, "gondola_cabin"))
	root.add_child(gl)


# ---- The Shuangjiang Tunnel ------------------------------------------------------------------------------------------

## The run's road goes down through the bluff in a cutting under a lid: a lined tunnel (walls, ceiling, lights, solid),
## portals with the name at both ends, and the lid laid over the trench at the natural ground's height in the ground's
## own material, solid, so the heights carry on over it unbroken.
func _build_tunnel(root: Node3D) -> void:
	var t0: float = _a["tun0"]
	var t1: float = _a["tun1"]
	if t0 < 0.0:
		push_error("Shuangjiang: no tunnel found")
		return
	var body := _body(root, "TunnelLiningBody")
	body.set_meta(&"surface", "rock")
	_city("tunnel", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		var tile := Color(0.74, 0.74, 0.7)
		var s: float = t0 - 4.0
		var k := 0
		while s < t1 + 4.0:
			var sb: float = minf(s + 4.0, t1 + 4.0)
			var a: Vector3 = lap.pt(s)
			var b: Vector3 = lap.pt(sb)
			var ra: Vector3 = lap.rt(s)
			var rb: Vector3 = lap.rt(sb)
			for side in [-1.0, 1.0]:
				var pa: Vector3 = a + ra * side * TUN_HALF
				var pb: Vector3 = b + rb * side * TUN_HALF
				var pts: Array = [pa - Vector3(0, 0.4, 0), pb - Vector3(0, 0.4, 0), pb + Vector3(0, TUN_H, 0), pa + Vector3(0, TUN_H, 0)]
				if side > 0.0:
					pts = [pb - Vector3(0, 0.4, 0), pa - Vector3(0, 0.4, 0), pa + Vector3(0, TUN_H, 0), pb + Vector3(0, TUN_H, 0)]
				pk.quad(kit, "paint", pts, -ra * side, tile)
				# A dark dado and a yellow line along the wall's foot.
				pk.quad(kit, "paint", [pts[0] - ra * side * 0.03, pts[1] - rb * side * 0.03, pts[1] + Vector3(0, 1.2, 0) - rb * side * 0.03, pts[0] + Vector3(0, 1.2, 0) - ra * side * 0.03],
						-ra * side, Color(0.25, 0.26, 0.28))
			# Walkways along both walls from the road's edge, over the ground graded beside the road.
			for side4 in [-1.0, 1.0]:
				var e0: Vector3 = a + ra * side4 * (road_half - 0.05)
				var e1: Vector3 = b + rb * side4 * (road_half - 0.05)
				var w0: Vector3 = a + ra * side4 * (TUN_HALF + 0.05)
				var w1: Vector3 = b + rb * side4 * (TUN_HALF + 0.05)
				var lift := Vector3(0, 0.25, 0)
				pk.quad(kit, "paint", [e0 + lift, w0 + lift, w1 + lift, e1 + lift] if side4 > 0.0 else [w0 + lift, e0 + lift, e1 + lift, w1 + lift], Vector3.UP, Color(0.52, 0.52, 0.5))
				pk.quad(kit, "paint", [e0 - Vector3(0, 0.3, 0), e1 - Vector3(0, 0.3, 0), e1 + lift, e0 + lift] if side4 > 0.0 else [e1 - Vector3(0, 0.3, 0), e0 - Vector3(0, 0.3, 0), e0 + lift, e1 + lift],
						-ra * side4, Color(0.85, 0.75, 0.2))
			# Panel joints on the walls every 4m.
			for side5 in [-1.0, 1.0]:
				var jp: Vector3 = a + ra * side5 * (TUN_HALF - 0.04)
				pk.box(kit, "paint", Transform3D(Basis(Vector3.UP, atan2(-(b - a).z, (b - a).x)), jp + Vector3(0, TUN_H * 0.5 + 0.4, 0)), Vector3(0.08, TUN_H - 1.0, 0.1),
						Color(0.62, 0.62, 0.6))
			pk.quad(kit, "paint", [a + ra * TUN_HALF + Vector3(0, TUN_H, 0), b + rb * TUN_HALF + Vector3(0, TUN_H, 0), b - rb * TUN_HALF + Vector3(0, TUN_H, 0),
					a - ra * TUN_HALF + Vector3(0, TUN_H, 0)], Vector3.DOWN, Color(0.3, 0.31, 0.33))
			# Lights: two rows of strip lamps on the ceiling.
			if k % 2 == 0:
				for lat in [-3.0, 3.0]:
					var lc: Vector3 = (a + b) * 0.5 + (ra + rb) * 0.5 * lat + Vector3(0, TUN_H - 0.12, 0)
					pk.box(kit, "neon", Transform3D(Basis(Vector3.UP, atan2(-(b - a).z, (b - a).x)), lc), Vector3(3.0, 0.12, 0.4), Color(1.0, 0.92, 0.75))
			k += 1
			s = sb
		# The portals: a concrete headwall from the tunnel's crown up to the ground over it, the name over the mouth.
		for e in [[t0, -1.0], [t1, 1.0]]:
			var sp: float = e[0]
			var out: float = e[1]
			var c: Vector3 = lap.pt(sp)
			var rt: Vector3 = lap.rt(sp)
			var fw: Vector3 = lap.fw(sp) * out
			var top: float = maxf(_natural(c.x, c.z), c.y + TUN_H + 1.5) + 1.0
			var face: Vector3 = c + fw * 0.6
			pk.quad(kit, "tower", [face - rt * 18.0 + Vector3(0, TUN_H, 0), face + rt * 18.0 + Vector3(0, TUN_H, 0), face + rt * 18.0 + Vector3(0, top - c.y, 0),
					face - rt * 18.0 + Vector3(0, top - c.y, 0)] if out < 0.0 else [face + rt * 18.0 + Vector3(0, TUN_H, 0), face - rt * 18.0 + Vector3(0, TUN_H, 0),
					face - rt * 18.0 + Vector3(0, top - c.y, 0), face + rt * 18.0 + Vector3(0, top - c.y, 0)], fw,
					Color(0.6, 0.6, 0.6, float(MCK.STYLE_CONCRETE) / 8.0))
			for side2 in [-1.0, 1.0]:
				var wing: Vector3 = face + rt * side2 * (TUN_HALF + 0.3)
				var wing2: Vector3 = face + rt * side2 * 18.0
				pk.quad(kit, "tower", [wing - Vector3(0, 0.5, 0), wing2 - Vector3(0, 0.5, 0), wing2 + Vector3(0, TUN_H, 0), wing + Vector3(0, TUN_H, 0)] if side2 * out < 0.0
						else [wing2 - Vector3(0, 0.5, 0), wing - Vector3(0, 0.5, 0), wing + Vector3(0, TUN_H, 0), wing2 + Vector3(0, TUN_H, 0)], fw,
						Color(0.6, 0.6, 0.6, float(MCK.STYLE_CONCRETE) / 8.0))
			pk.beam(kit, "paint", face - rt * (TUN_HALF + 0.5) + Vector3(0, TUN_H + 0.5, 0) + fw * 0.3, face + rt * (TUN_HALF + 0.5) + Vector3(0, TUN_H + 0.5, 0) + fw * 0.3, 1.0, 1.0,
					Color(0.7, 0.68, 0.62))
			MCK.neon_sign(pk, kit, labels, face + Vector3(0, TUN_H + 2.4, 0) + fw * 0.85, fw, 14.0, 2.0, "双江隧道", Color(0.95, 0.85, 0.5))
	, 1400.0)
	# Solid: walls and ceiling every 6m, the portals' faces.
	var s2: float = t0
	while s2 < t1:
		var sb2: float = minf(s2 + 6.0, t1)
		var a2: Vector3 = lap.pt(s2)
		var b2: Vector3 = lap.pt(sb2)
		var mid: Vector3 = (a2 + b2) * 0.5
		var fwd: Vector3 = (b2 - a2).normalized()
		var x: Vector3 = Vector3.UP.cross(fwd).normalized()
		var basis := Basis(x, fwd.cross(x).normalized(), fwd).orthonormalized()
		var l: float = a2.distance_to(b2) + 0.4
		_box_shape(body, Transform3D(basis, mid + basis.y * (TUN_H + 0.5)), Vector3(2.0 * TUN_HALF + 2.0, 1.0, l))
		for side3 in [-1.0, 1.0]:
			_box_shape(body, Transform3D(basis, mid + basis.x * side3 * (TUN_HALF + 0.5) + basis.y * (TUN_H * 0.5)), Vector3(1.0, TUN_H + 1.0, l))
		s2 = sb2
	# The lid: the natural ground over the trench, a grid along the tunnel, in the ground's material, solid.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := 11
	var reach := 26.0
	var rows: Array = []
	var s3: float = t0 + 1.0
	while s3 <= t1 - 1.0 + 0.01:
		var row := PackedVector3Array()
		for ci in range(cols):
			var lat: float = lerpf(-reach, reach, float(ci) / float(cols - 1))
			var p: Vector3 = lap.pt(s3) + lap.rt(s3) * lat
			var top2: float = _natural(p.x, p.z)
			# Over the tunnel's lining at least (near the portals the ground is barely over it).
			if absf(lat) < TUN_HALF + 1.0:
				top2 = maxf(top2, lap.y(s3) + TUN_H + 0.8)
			p.y = top2 - (0.25 if absf(lat) > reach - 4.0 else 0.0)
			row.append(p)
		rows.append(row)
		s3 += 4.0
	var faces := PackedVector3Array()
	for i in range(rows.size() - 1):
		var ra2: PackedVector3Array = rows[i]
		var rb2: PackedVector3Array = rows[i + 1]
		for ci2 in range(cols - 1):
			var q: Array = [ra2[ci2], ra2[ci2 + 1], rb2[ci2 + 1], rb2[ci2]]
			for tri in [[0, 2, 1], [0, 3, 2]]:
				for v in tri:
					st.add_vertex(q[v])
					faces.append(q[v])
	st.generate_normals()
	var lid := MeshInstance3D.new()
	lid.name = "TunnelLidTerrain"
	lid.mesh = _save_res(st.commit(), "tunnel_lid")
	lid.material_override = _ground_mat
	root.add_child(lid)
	var lid_body := _body(root, "TunnelLidEarth")
	var cs := CollisionShape3D.new()
	var cp := ConcavePolygonShape3D.new()
	cp.set_faces(faces)
	cp.backface_collision = true
	cs.shape = cp
	lid_body.add_child(cs)
	print("  tunnel %.0f-%.0fm (%.0fm)" % [t0, t1, t1 - t0])


# ---- The finish: the Chaotian plaza at the peninsula's tip -----------------------------------------------------------

## 朝天广场: a paved plaza at the confluence, its prow pointing where the rivers meet: the finish straight down its
## middle between grandstands, flags, steps down to the water at the prow, the crowd.
func _build_finish_plaza() -> void:
	var p: Rect2 = PLAZA
	var gy: float = lap.y(lap.closest_s(Vector2(470.0, -330.0))) - 0.02
	var fs: float = lap.length - finish_runout
	var rng := RandomNumberGenerator.new()
	rng.seed = 5151
	var cx := 470.0
	_city("plaza", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		var prow := PackedVector2Array([p.position, Vector2(p.end.x, p.position.y), Vector2(p.end.x, p.end.y - 40.0), Vector2(cx + 20.0, p.end.y + 8.0),
			Vector2(cx - 20.0, p.end.y + 8.0), Vector2(p.position.x, p.end.y - 40.0)])
		MCK.flat(pk, kit, prow, gy - 0.04, Vector3.UP, Color(0.66, 0.63, 0.58), MCK.STYLE_CONCRETE)
		# A stone edge round it and steps down from the prow toward the water.
		for k in range(6):
			var zz: float = p.end.y + 8.0 + float(k) * 1.2
			pk.block(kit, "paint", Vector3(cx - 20.0 - float(k) * 3.0, gy - 0.4 * float(k + 1) - 1.0, zz), Vector3(cx + 20.0 + float(k) * 3.0, gy - 0.4 * float(k + 1), zz + 1.2),
					Color(0.62, 0.6, 0.55))
		# Flagpoles along both edges.
		for side in [-1.0, 1.0]:
			var z := p.position.y + 10.0
			while z < p.end.y - 30.0:
				var fx: float = cx + side * 62.0
				pk.tube(kit, "steel", Vector3(fx, gy, z), Vector3(fx, gy + 13.0, z), 0.14, 0.08, 6, Color(0.82, 0.82, 0.84))
				pk.box(kit, "paint", Transform3D(Basis(), Vector3(fx + 1.3, gy + 11.8, z)), Vector3(2.4, 1.5, 0.05), [Color(0.85, 0.1, 0.1), Color(0.95, 0.75, 0.15)][int(z) % 2])
				z += 16.0
		# The grandstands either side of the finish line, facing the road.
		for side2 in [-1.0, 1.0]:
			var s := fs - 70.0
			while s < fs + 14.0:
				for row in range(8):
					var lat: float = road_half + 4.5 + float(row) * 1.0
					var c: Vector3 = lap.pt(s) + lap.rt(s) * side2 * lat
					var yb: float = gy + 0.6 * float(row + 1)
					pk.box(kit, "paint", Transform3D(Basis(Vector3.UP, 0.0), Vector3(c.x, (gy + yb) * 0.5 - 0.3, c.z)), Vector3(1.0, yb - gy + 0.6, 4.2),
							Color(0.8, 0.16, 0.14) if row % 2 == 0 else Color(0.86, 0.86, 0.86))
				s += 4.0
			var roof_a: Vector3 = lap.pt(fs - 70.0) + lap.rt(fs - 70.0) * side2 * (road_half + 8.5) + Vector3(0, 9.5, 0)
			var roof_b: Vector3 = lap.pt(fs + 14.0) + lap.rt(fs + 14.0) * side2 * (road_half + 8.5) + Vector3(0, 9.5, 0)
			pk.beam(kit, "gloss", roof_a, roof_b, 9.5, 0.4, Color(0.9, 0.9, 0.9))
			for sp in [fs - 66.0, fs - 28.0, fs + 10.0]:
				var post: Vector3 = lap.pt(sp) + lap.rt(sp) * side2 * (road_half + 12.8)
				pk.tube(kit, "steel", Vector3(post.x, gy, post.z), Vector3(post.x, gy + 9.4, post.z), 0.25, 0.25, 6, Color(0.6, 0.6, 0.62))
		MCK.neon_sign(pk, kit, labels, Vector3(cx, gy + 1.4, p.end.y + 6.0), Vector3(0, 0, -1), 20.0, 2.2, "朝天广场", Color(0.95, 0.8, 0.45))
	, 1600.0)
	# The crowd: seated in the stands, standing along the barriers and at the prow.
	for side3 in [-1.0, 1.0]:
		var s2 := fs - 68.0
		while s2 < fs + 12.0:
			for row2 in range(8):
				if rng.randf() < 0.6:
					var q: Vector3 = lap.pt(s2) + lap.rt(s2) * side3 * (road_half + 4.6 + float(row2) * 1.0)
					q.y = gy + 0.6 * float(row2 + 1)
					_person(q, -lap.rt(s2) * side3, rng.randf_range(0.92, 1.06), true)
			s2 += 1.15
		var s3 := fs - 140.0
		while s3 < fs - 72.0:
			if rng.randf() < 0.55:
				var q2: Vector3 = lap.pt(s3) + lap.rt(s3) * side3 * (road_half + 2.6 + rng.randf() * 1.5)
				q2.y = gy
				_person(q2, -lap.rt(s3) * side3, rng.randf_range(0.92, 1.06))
			s3 += 1.6
	for k2 in range(60):
		var pp := Vector3(cx + rng.randf_range(-30.0, 30.0), gy, p.end.y - rng.randf_range(4.0, 14.0))
		if absf(pp.x - cx) > road_half + 3.0:
			_person(pp, Vector3(rng.randf_range(-0.3, 0.3), 0, -1), rng.randf_range(0.92, 1.06))
	# Barriers along the finish straight and across the road's end.
	var body := _body(level, "PlazaBarriersBody")
	for side4 in [-1.0, 1.0]:
		_edge_boxes(body, lap, fs - 140.0, lap.length, side4 * (road_half + 2.0), 1.2, 0.4)
		_edge_boxes(body, lap, fs - 70.0, fs + 14.0, side4 * (road_half + 4.0), 6.0, 1.0)
	var end_p: Vector3 = lap.pt(lap.length)
	_box_shape(body, Transform3D(Basis(), end_p + Vector3(0, 0.6, 3.0)), Vector3(2.0 * road_half + 6.0, 1.2, 0.6))
	_note_rect(p.get_center(), p.size.x, p.size.y, 0.0)


# ---- The riverside park on the south bank ----------------------------------------------------------------------------

func _build_riverside_park() -> void:
	var r: Rect2 = RIVERSIDE
	_city("riverside", func(pk: PropKit, kit: Dictionary, _labels: Array) -> void:
		var z: float = r.position.y - 2.0
		MCK.wall(pk, kit, Vector3(r.position.x, 0, z), Vector3(r.end.x, 0, z), -10.0, 8.0, Vector3(0, 0, -1), Color(0.55, 0.52, 0.46), MCK.STYLE_CONCRETE, 93)
		MCK.glass_rail(pk, kit, Vector3(r.position.x, 8.0, z + 0.4), Vector3(r.end.x, 8.0, z + 0.4), 1.1, Color(1.0, 0.8, 0.5, 0.0))
		var x: float = r.position.x + 10.0
		while x < r.end.x:
			if absf(x - ARCH_X) > 20.0:
				var lp := Vector3(x, 8.0, z + 3.0)
				pk.tube(kit, "steel", lp, lp + Vector3(0, 4.5, 0), 0.08, 0.06, 6, Color(0.2, 0.2, 0.22))
				pk.block(kit, "paint", lp + Vector3(-0.3, 4.4, -0.3), lp + Vector3(0.3, 4.7, 0.3), Color(0.8, 0.78, 0.72))
				pk.block(kit, "paint", lp + Vector3(2.0, 0.0, 0.0), lp + Vector3(4.2, 0.45, 0.6), Color(0.35, 0.22, 0.12))
			x += 24.0
	, 1400.0)


func _tree_pick(x: float, z: float, roll: float, rng: RandomNumberGenerator) -> Array:
	# The riverside park's trees (camphor-like dark crowns, willows by the water, a few maples), and on the bluff's face
	# (thin in the old town: a few big old trees between the houses).
	if RIVERSIDE.has_point(Vector2(x, z)):
		if roll > 0.42:
			return []
		var near_water: bool = z < RIVERSIDE.position.y + 30.0
		var kinds: Array = ["matsu", "matsu", "momiji", "take", "sakura"]
		return ["shidare" if near_water and roll < 0.18 else kinds[rng.randi() % kinds.size()], rng.randf_range(0.85, 1.1)]
	if z < -300.0 and z > -460.0 and x < BLUFF_X0 and x > -560.0:
		var town: bool = x > LEGS_X.x - 25.0 and x < LEGS_X.y + 25.0
		if roll > (0.05 if town else 0.22):
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

## The broad shore at the peninsula's tip round the plaza: sand heaps, boulders, boats pulled up, people out early.
func _build_beach() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9393
	var spots: Array = []
	_city("beach", func(pk: PropKit, kit: Dictionary, _l: Array) -> void:
		var x: float = BLUFF_X1 + 10.0
		while x < TRIB_X - TRIB_HALF - 15.0:
			var z: float = -RIVER_HALF_W - 18.0
			while z > -540.0:
				var c := Vector3(x + rng.randf_range(-12.0, 12.0), 0.0, z + rng.randf_range(-12.0, 12.0))
				var near_road: bool = _route_low_over(Rect2(c.x, c.z, 0.0, 0.0), 18.0) < INF
				var on_plaza: bool = PLAZA.grow(10.0).has_point(Vector2(c.x, c.z))
				if not near_road and not on_plaza and _natural(c.x, c.z) > 1.0 and _natural(c.x, c.z) < 6.0:
					c.y = _ground_at(c.x, c.z)
					var roll: float = rng.randf()
					if roll < 0.22:
						_sand_heap(pk, kit, c, rng.randf_range(4.0, 7.0), rng.randf_range(2.0, 3.0))
					elif roll < 0.5:
						_boulders(pk, kit, c, rng.randf_range(1.0, 2.6), rng)
					elif roll < 0.62:
						_sampan(pk, kit, Vector2(c.x, c.z), rng.randf() * TAU, c.y)
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
	# At the start, both sides of the avenue, in front of the theatre's steps.
	var s: float = start_s - 60.0
	while s < start_s + 70.0:
		for side in [-1.0, 1.0]:
			for row in range(2):
				if rng.randf() < 0.35:
					continue
				var p: Vector3 = lap.pt(s) + lap.rt(s) * side * (road_half + 2.6 + float(row) * 1.5 + rng.randf() * 0.5)
				p.y = _ground_at(p.x, p.z)
				if absf(p.y - lap.y(s)) < 1.5:
					_person(p, -lap.rt(s) * side, rng.randf_range(0.92, 1.06))
		s += 2.4
	# Morning walkers along the riverside promenade, fishermen on the shore, people on the old town's stairs.
	_crowd_line(Vector3(RIVERSIDE.position.x + 20.0, 8.0, RIVERSIDE.position.y + 2.5), Vector3(RIVERSIDE.end.x - 20.0, 8.0, RIVERSIDE.position.y + 2.5),
			Vector3(0, 0, -1), 9.0, rng, 0.5)
	var x := -180.0
	while x < 330.0:
		if absf(x - 18.0) > 30.0 and absf(x - 198.0) > 20.0 and absf(x - GONDOLA_X) > 16.0 and rng.randf() < 0.6:
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
