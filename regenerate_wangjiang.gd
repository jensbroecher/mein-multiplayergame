extends "res://YunhaiStage.gd"
# Builds levels/WangjiangLevel.tscn - Wangjiang (望江, "looking out over the river"), the Yunhai GP's third stage: one
# long run (4.6km) at night from the hill town above the river down to the riverside. The user asked for two of the ideas
# for the cup together, as a longer point-to-point race: racing the monorail through a block of flats, and the cliff town
# of stilt houses by the river.
#
# The run (game metres, x east, z south):
#   - from Wangjiang station (望江站) on the plateau (80m) east along Wangjiang Road with the monorail's beam beside it,
#     the line and the road on viaducts across the Huaxi gully (floor at 25m, tower blocks rising out of it);
#   - through the Jiayuan Building (嘉园大厦), a block of flats with a hole through its 14th to 16th floors that the road
#     and the monorail share: the train may come through beside you;
#   - up onto the deck through Chaoyang station (朝阳站), whose two halves stand either side of a cross street: a kicker
#     at the end of the first, a 28m gap, the second;
#   - south along Jiefang Road to the edge of the hill and down the cliff town (吊脚楼, stilt houses) in four legs along
#     the slope joined by hairpins, through arcades where the houses' upper floors span the road, lanterns everywhere;
#   - west along the quay under the cableway over the river, past the moored tour boats, to the finish in the plaza at the
#     end of the quay under a lantern gate.
# Built on YunhaiStage.gd (the Yunhai GP's base) on the Miyoshino GP's stage base. The monorail is Monorail.gd's (three
# cars, AnimatableBody boxes, on the wall clock), the cableway CableCar.gd (two cabins, wall clock).

## Heights along the run: [plan point on it, height], in order.
const KNOTS := [
	[Vector2(-20.0, 0.0), 80.0], [Vector2(500.0, 0.0), 79.0], [Vector2(880.0, 0.0), 76.5], [Vector2(990.0, 0.0), 80.0],
	[Vector2(1150.0, 0.0), 80.0], [Vector2(1240.0, 150.0), 74.0], [Vector2(1240.0, 400.0), 61.0], [Vector2(1200.0, 480.0), 60.0],
	[Vector2(1090.0, 480.0), 47.5], [Vector2(1090.0, 520.0), 47.0], [Vector2(1240.0, 520.0), 35.5], [Vector2(1240.0, 560.0), 35.0],
	[Vector2(1090.0, 560.0), 23.5], [Vector2(1090.0, 600.0), 23.0], [Vector2(1270.0, 600.0), 11.0], [Vector2(1300.0, 645.0), 7.0],
	[Vector2(1260.0, 660.0), 5.0], [Vector2(800.0, 660.0), 5.0],
	# The Yunhai Bridge: up the north ramp, level over the main span, down the south ramp into the plaza.
	[Vector2(BRIDGE_X, 700.0), 6.0], [Vector2(BRIDGE_X, 880.0), 28.0], [Vector2(BRIDGE_X, 1120.0), 30.0], [Vector2(BRIDGE_X, 1300.0), 7.0],
	[Vector2(BRIDGE_X, 1345.0), 6.0], [Vector2(BRIDGE_X, 1520.0), 6.0],
]
## The cliff town's legs: [plan point at one end, plan point at the other] (lap order), and the hairpins between.
const LEGS := [[Vector2(1200.0, 480.0), Vector2(1090.0, 480.0)], [Vector2(1090.0, 520.0), Vector2(1240.0, 520.0)],
	[Vector2(1240.0, 560.0), Vector2(1090.0, 560.0)], [Vector2(1090.0, 600.0), Vector2(1270.0, 600.0)]]
## The Yunhai Bridge (云海大桥) over the river along x BRIDGE_X: its two pylons' z, their height over the water.
const BRIDGE_X := 760.0
const PYLONS := [880.0, 1120.0]
const PYLON_TOP := 118.0
## The Yunhai Plaza (云海广场) on the far bank, where the race ends: its paving, the grandstands' reach along the road,
## the stage at its south end.
const PLAZA2 := Rect2(560.0, 1320.0, 400.0, 260.0)
const STANDS_Z := Vector2(1345.0, 1470.0)
const STAGE_Z := 1548.0
## The gap at Chaoyang station: the lip's plan point, the gap, the kicker.
const JUMP_LIP := Vector2(1045.0, 0.0)
const JUMP_GAP := 28.0
const KICK_LEN := 9.0
const KICK_H := 1.5
## The monorail runs `MONO_SIDE` metres north of the road's middle, its beam's top `MONO_UP` over the road.
const MONO_SIDE := 18.0
const MONO_UP := 2.6
const MONO_WEST := -340.0
const MONO_EAST := 1760.0
const CAR_LEN := 12.0
const CAR_PITCH := 12.6
const MONO_WHITE := Color(0.93, 0.94, 0.95)
const MONO_RED := Color(0.82, 0.12, 0.12)
const MONO_BLUE := Color(0.14, 0.32, 0.62)
const MONO_GLASS := Color(0.08, 0.13, 0.2)
## The stations' platform stretches (x from, x to) and names.
const STATION_1 := [Vector2(-170.0, -70.0), "望江站"]
const STATION_2A := Vector2(985.0, 1040.0)
const STATION_2B := Vector2(1078.0, 1150.0)
## The Jiayuan Building: its plan (x from, x to, z from, z to) and the hole's z span (the road and the line).
const FLATS := Rect2(882.0, -48.0, 48.0, 84.0)
const FLATS_HOLE_Z := Vector2(-25.0, 10.0)
## The quay: its road along z QUAY_Z, the river wall at QUAY_EDGE, the plaza at the end.
const QUAY_Z := 660.0
const QUAY_EDGE := 692.0
const PLAZA := Rect2(170.0, 640.0, 240.0, 52.0)
## The cableway: the ropes' ends (top station on the hill's edge, bottom across the river).
const CABLE_A := Vector3(450.0, 104.0, 360.0)
const CABLE_B := Vector3(450.0, 34.0, 1400.0)
## The cliff town's area (on the ground shader's lawns, off the city's blocks).
const TOWN := Rect2(1030.0, 380.0, 320.0, 300.0)

var _a := {}


func _configure() -> void:
	level_name = "WangjiangLevel"
	level_path = "res://levels/WangjiangLevel.tscn"
	stem = "wangjiang"
	title = "Wangjiang"
	seed_base = 8300
	road_half = 7.5
	max_grade = 0.16
	closed = false
	point_to_point = true
	start_s = 50.0
	finish_runout = 100.0
	corners = [
		[Vector2(-20.0, 0.0), 0.0],
		[Vector2(1240.0, 0.0), 70.0],
		[Vector2(1240.0, 480.0), 20.0],
		[Vector2(1070.0, 480.0), 20.0],
		[Vector2(1070.0, 520.0), 20.0],
		[Vector2(1260.0, 520.0), 20.0],
		[Vector2(1260.0, 560.0), 20.0],
		[Vector2(1070.0, 560.0), 20.0],
		[Vector2(1070.0, 600.0), 20.0],
		[Vector2(1300.0, 600.0), 30.0],
		[Vector2(1300.0, 660.0), 30.0],
		[Vector2(BRIDGE_X, 660.0), 40.0],
		[Vector2(BRIDGE_X, 1520.0), 0.0],
	]
	fine_x = Vector2(-450.0, 1850.0)
	fine_z = Vector2(-350.0, 1000.0)
	fine_step = 6.0
	outer = 6000.0
	tree_step = 9.0
	tree_margin = 30.0
	tree_far_range = 900.0
	tree_clear = 12.0
	collide_margin = 80.0
	pier_style = 1
	grid_origin = Vector2(-11.0, -11.0)
	city_mid = Vector2(650.0, 250.0)
	city_near = 1300.0
	city_tall = Vector2(90.0, 70.0)
	park_rect = TOWN
	river_half = 300.0
	water_y = 0.0
	skyline_clusters = [Vector2(700.0, 1900.0), Vector2(-900.0, 1500.0), Vector2(2200.0, 1400.0), Vector2(-700.0, -1200.0), Vector2(1800.0, -1000.0)]


# ======================================================================================
#  The ground: the plateau, the Huaxi gully, the slope down to the quay, the river
# ======================================================================================

## The river runs east and west along z 980, 600m wide: the quay's wall on its north bank, the far bank to the south.
func _river_d(_x: float, z: float) -> float:
	return absf(z - 980.0)


func _natural(x: float, z: float) -> float:
	# The plateau: 80m, falling to 70m east of the stations (midtown).
	var up: float = lerpf(80.0, 70.0, smoothstep(950.0, 1060.0, x))
	var h: float = up
	# The slope down to the river (the cliff town's hill): from the plateau's edge (z 380) to the quay (z 650).
	if z > 380.0:
		var t: float = smoothstep(380.0, 650.0, z)
		h = lerpf(up, 4.0, t)
	# The quay (4m), its wall into the river, the riverbed, the far bank.
	if z > 650.0:
		h = 4.0
	if z > 690.0:
		h = lerpf(4.0, -10.0, smoothstep(690.0, 706.0, z))
	if z > 1240.0:
		h = lerpf(-10.0, 6.0, smoothstep(1240.0, 1320.0, z))
	# The Huaxi gully: a ravine running north and south at x 750 (floor at 25m), cutting on down the slope.
	var gully: float = 25.0 + 55.0 * smoothstep(110.0, 170.0, absf(x - 750.0))
	if z < 640.0:
		h = minf(h, gully)
	# Hills round the far city.
	var r: float = Vector2(x, z).distance_to(city_mid)
	var hill: float = smoothstep(2400.0, 4200.0, r) * (170.0 + 120.0 * n_ridge.get_noise_2d(x * 0.6, z * 0.6))
	return h + maxf(hill, 0.0)


# ======================================================================================
#  The route's heights
# ======================================================================================

func _shape_heights(r: Route, ys: PackedFloat32Array) -> void:
	if r != lap:
		return
	var n: int = ys.size()
	var ks: Array = []
	for k in KNOTS:
		ks.append([lap.closest_s(k[0] as Vector2), float(k[1]) + GROUND_UNDER])
	ks.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	ks.push_front([0.0, float(ks[0][1])])
	ks.append([lap.length, float(ks[ks.size() - 1][1])])
	var lip: float = lap.closest_s(JUMP_LIP)
	var land: float = lip + JUMP_GAP
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
		if float(i) > lip - 10.0 and float(i) < land + 10.0:
			ys[i] = raw[i]
			continue
		var acc := 0.0
		var cnt := 0
		for d in range(-10, 11):
			var j: int = clampi(i + d, 0, n - 1)
			if float(j) > lip and float(j) < land:
				continue
			acc += raw[j]
			cnt += 1
		ys[i] = acc / float(maxi(cnt, 1))
	_a = {"lip": lip, "land": land}
	for li in range(LEGS.size()):
		_a["leg%d_0" % li] = lap.closest_s(LEGS[li][0])
		_a["leg%d_1" % li] = lap.closest_s(LEGS[li][1])
	_a["quay"] = lap.closest_s(Vector2(1260.0, QUAY_Z))
	_a["quay_end"] = lap.closest_s(Vector2(BRIDGE_X + 40.0, QUAY_Z))
	_a["bridge0"] = lap.closest_s(Vector2(BRIDGE_X, QUAY_EDGE))
	_a["bridge1"] = lap.closest_s(Vector2(BRIDGE_X, 1300.0))
	_a["flats0"] = lap.closest_s(Vector2(FLATS.position.x - 4.0, 0.0))
	_a["flats1"] = lap.closest_s(Vector2(FLATS.end.x + 4.0, 0.0))
	_a["turn"] = lap.closest_s(Vector2(1240.0, 150.0))
	# Bridges: everything more than 3m over the natural ground, and through the Jiayuan Building.
	bridges = []
	var in_b := false
	var b0 := 0.0
	for i in range(n):
		var p: Vector2 = lap.at(float(i))["p"]
		var up: bool = ys[i] - _natural(p.x, p.y) > 3.0 or (float(i) > float(_a["flats0"]) and float(i) < float(_a["flats1"]))
		if up and not in_b:
			in_b = true
			b0 = float(i)
		elif not up and in_b:
			in_b = false
			bridges.append(["lap", b0, float(i), 0.0, true])
	if in_b:
		bridges.append(["lap", b0, lap.length, 0.0, true])
	print("  run %.0fm, lip at %.0fm, bridges %s" % [lap.length, lip, str(bridges.map(func(b): return "%.0f-%.0f" % [b[1], b[2]]))])


func _sections(r: Route) -> Array:
	if r != lap or _a.is_empty():
		return [[0.0, r.length, K_ASPHALT, r.half]]
	var q: float = _a["quay"]
	var qe: float = _a["quay_end"]
	return [[0.0, float(_a["lip"]), K_ASPHALT, r.half], [float(_a["land"]), float(_a["leg0_0"]) - 30.0, K_ASPHALT, r.half],
		[float(_a["leg0_0"]) - 30.0, q, K_STONE, r.half], [q, qe, K_STONE, r.half], [qe, r.length, K_ASPHALT, r.half]]


func _build_deck_slab(_node: Node3D, _r: Route, _s0: float, _s1: float, _idx: int) -> void:
	pass


func _is_bridge(s: float) -> bool:
	for b in bridges:
		if s >= float(b[1]) and s <= float(b[2]):
			return true
	return false


# ======================================================================================
#  The night: warmer and hazier than Tianqiao's, the river's mist
# ======================================================================================

func _environment() -> Dictionary:
	var e: Dictionary = super()
	e["sky_horizon"] = Color(0.26, 0.16, 0.2)
	e["haze"] = Color(0.22, 0.15, 0.17)
	e["cloud_lit"] = Color(0.3, 0.2, 0.22)
	e["ambient_color"] = Color(0.36, 0.3, 0.36)
	e["fog_begin"] = 90.0
	e["fog_end"] = 2300.0
	e["fog_density"] = 1.15
	return e


# ======================================================================================
#  Gameplay
# ======================================================================================

func _place_gameplay(root: Node3D) -> void:
	var cps: Array = []
	for q in [Vector2(420.0, 0.0), Vector2(1110.0, 0.0), Vector2(1240.0, 260.0), Vector2(1160.0, 480.0), Vector2(1160.0, 520.0),
			Vector2(1160.0, 560.0), Vector2(1170.0, 600.0), Vector2(1000.0, QUAY_Z), Vector2(BRIDGE_X, 1000.0)]:
		cps.append(lap.closest_s(q))
	_checkpoints(cps)
	var lip: float = _a["lip"]
	_boosts([["Boost_Road", lap.closest_s(Vector2(300.0, 0.0)), 0.0], ["Boost_Station", lip - 55.0, 0.0],
		["Boost_Jiefang", lap.closest_s(Vector2(1240.0, 120.0)), 2.5], ["Boost_Quay1", lap.closest_s(Vector2(1150.0, QUAY_Z)), -2.5],
		["Boost_Bridge", lap.closest_s(Vector2(BRIDGE_X, 1150.0)), 0.0]])
	_kicker(root, "Jump_Chaoyang", lap, lip - KICK_LEN, KICK_LEN, KICK_H, 0.5, false, Color(0.25, 0.27, 0.3))


# ======================================================================================
#  The dressing
# ======================================================================================

func _build_dressing(root: Node3D) -> void:
	_load_cjk_font()
	_rails = _body(root, "RoadRailsBody")
	_rails.set_meta(&"surface", "rock")
	_sample_route()
	_reserved.append(TOWN)
	_reserved.append(Rect2(100.0, 630.0, 1300.0, 80.0))
	_reserved.append(Rect2(MONO_WEST - 20.0, -MONO_SIDE - 14.0, MONO_EAST - MONO_WEST + 40.0, 28.0))
	_reserved.append(FLATS.grow(12.0))
	_reserved.append(Rect2(CABLE_A.x - 30.0, CABLE_A.z - 40.0, 60.0, CABLE_B.z - CABLE_A.z + 80.0))
	_reserved.append(Rect2(STATION_1[0].x - 20.0, -50.0, STATION_1[0].y - STATION_1[0].x + 40.0, 60.0))
	_reserved.append(Rect2(PLAZA2.position.x - 120.0, PLAZA2.position.y - 30.0, PLAZA2.size.x + 240.0, PLAZA2.size.y + 200.0))
	_build_road_decks()
	_build_lamps()
	_build_monorail(root)
	_build_stations()
	_build_flats()
	_build_cliff_town()
	_build_quay()
	_build_cableway(root)
	_build_bridge()
	_build_plaza()
	_build_city()
	_build_skyline(root)
	_build_crowds()
	print("  dressing: %d buildings, %d people" % [_bid, _people.size()])


# ---- The road's decks and parapets -----------------------------------------------------------------------------------

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
		var town: bool = mid > float(_a["leg0_0"]) - 30.0
		var led := Color(1.0, 0.55, 0.2, 0.0) if town else Color(0.3, 0.85, 1.0, 0.3)
		_deck("deck_road_%d" % k, s0, s1, 2.0 if up else 0.4, led, 32.0 if up else 0.0, [true, true], 0.0, true)
		k += 1


func _build_lamps() -> void:
	_city("deck_road_lamps", func(pk: PropKit, kit: Dictionary, _l: Array) -> void:
		var s := 20.0
		var k := 0
		var town0: float = float(_a["leg0_0"]) - 30.0
		while s < lap.length - 5.0:
			if s > float(_a["lip"]) - 8.0 and s < float(_a["land"]) + 8.0:
				s += 32.0
				continue
			var side: float = 1.0 if k % 2 == 0 else -1.0
			var b: Vector3 = lap.pt(s) + lap.rt(s) * side * (road_half + 0.7) + Vector3(0, 1.1, 0)
			var city_lamp: bool = s < town0 or s > float(_a["bridge0"]) - 20.0
			if city_lamp:
				# The city's roads: tall lamps over the carriageway (the monorail's side has none).
				if side > 0.0:
					pk.tube(kit, "steel", b, b + Vector3(0, 9.0, 0), 0.15, 0.1, 6, Color(0.4, 0.41, 0.44))
					var head: Vector3 = b + Vector3(0, 9.0, 0) - lap.rt(s) * side * 2.4
					pk.beam(kit, "steel", b + Vector3(0, 9.0, 0), head, 0.1, 0.1, Color(0.4, 0.41, 0.44))
					pk.block(kit, "neon", head + Vector3(-0.5, -0.16, -0.3), head + Vector3(0.5, 0.0, 0.3), Color(1.0, 0.82, 0.6))
			else:
				# The old town and the quay: lantern posts on the parapets.
				pk.tube(kit, "paint", b, b + Vector3(0, 3.4, 0), 0.09, 0.09, 6, Color(0.2, 0.08, 0.06))
				MCK.lantern(pk, kit, b + Vector3(0, 3.0, 0), 0.8)
			s += 32.0 if city_lamp else 14.0
			k += 1
	, 1400.0)


# ---- The monorail ---------------------------------------------------------------------------------------------------

## The beam's top line: straight in from the west end, along the road `MONO_SIDE` north of it (MONO_UP over it) to
## where the road turns south, straight on east to the terminus.
func _mono_points() -> PackedVector3Array:
	var pts := PackedVector3Array()
	var y0: float = lap.y(0.0) + MONO_UP
	var x: float = MONO_WEST
	while x < -20.0:
		pts.append(Vector3(x, y0, -MONO_SIDE))
		x += 10.0
	var s_end: float = lap.closest_s(Vector2(1160.0, 0.0))
	var s := 0.0
	var last := Vector3.ZERO
	while s <= s_end:
		var p: Vector3 = lap.pt(s)
		var y: float = p.y + MONO_UP
		# Across the jump's gap the line runs level.
		if s > float(_a["lip"]) - 5.0 and s < float(_a["land"]) + 5.0:
			y = lap.y(float(_a["lip"]) - 5.0) + MONO_UP
		last = Vector3(p.x, y, -MONO_SIDE)
		pts.append(last)
		s += 6.0
	x = last.x + 10.0
	while x <= MONO_EAST:
		pts.append(Vector3(x, last.y, -MONO_SIDE))
		x += 10.0
	return pts


func _build_monorail(root: Node3D) -> void:
	var pts: PackedVector3Array = _mono_points()
	var curve := Curve3D.new()
	for p in pts:
		curve.add_point(p)
	_city("deck_monorail", func(pk: PropKit, kit: Dictionary, _l: Array) -> void:
		var conc := Color(0.82, 0.82, 0.83, float(MCK.STYLE_CONCRETE) / 8.0)
		for i in range(pts.size() - 1):
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[i + 1]
			var hw := 0.6
			var hb := 1.9
			var r := Vector3(0, 0, 1)
			for q in [[Vector3(-hw, 0, 0), Vector3(hw, 0, 0), Vector3.UP], [Vector3(hw, 0, 0), Vector3(hw, -hb, 0), Vector3(0, 0, 1)],
					[Vector3(-hw, -hb, 0), Vector3(-hw, 0, 0), Vector3(0, 0, -1)], [Vector3(hw, -hb, 0), Vector3(-hw, -hb, 0), Vector3.DOWN]]:
				var o0: Vector3 = Vector3(0, q[0].y, q[0].x)
				var o1: Vector3 = Vector3(0, q[1].y, q[1].x)
				pk.quad(kit, "tower", [a + o0, b + o0, b + o1, a + o1], q[2], conc)
			MCK.led_line(pk, kit, a + Vector3(0, -1.2, 0.62), b + Vector3(0, -1.2, 0.62), Color(0.3, 0.85, 1.0, 0.0), 0.1)
			if r == Vector3.ZERO:
				pass
		# Columns every 30m (none inside the Jiayuan Building, over the cross street or at the stations' platforms' middle).
		var acc := 15.0
		for i2 in range(pts.size() - 1):
			var a2: Vector3 = pts[i2]
			var b2: Vector3 = pts[i2 + 1]
			var seg: float = a2.distance_to(b2)
			while acc < seg:
				var p: Vector3 = a2.lerp(b2, acc / seg)
				var inside: bool = p.x > FLATS.position.x - 2.0 and p.x < FLATS.end.x + 2.0
				var gap: bool = p.x > STATION_2A.y - 2.0 and p.x < STATION_2B.x + 2.0
				if not inside and not gap:
					var g: float = _ground_at(p.x, p.z)
					if p.y - 1.9 - g > 1.0:
						pk.box(kit, "tower", Transform3D(Basis(), Vector3(p.x, (g - 1.0 + p.y - 2.8) * 0.5, p.z)), Vector3(1.4, p.y - 2.8 - g + 1.0, 1.4), conc)
						pk.box(kit, "tower", Transform3D(Basis(), Vector3(p.x, p.y - 2.4, p.z)), Vector3(1.8, 1.0, 3.2), conc)
				acc += 30.0
			acc -= seg
		# Buffers at both ends.
		for e in [pts[0], pts[pts.size() - 1]]:
			var bp: Vector3 = e
			pk.block(kit, "paint", bp + Vector3(-0.9, 0.0, -0.9), bp + Vector3(0.9, 1.0, 0.9), Color(0.95, 0.78, 0.12))
			pk.block(kit, "neon", bp + Vector3(-0.2, 1.0, -0.2), bp + Vector3(0.2, 1.3, 0.2), Color(1.0, 0.15, 0.1))
	, 2600.0)
	var L: float = curve.get_baked_length()
	var half_train: float = CAR_PITCH + CAR_LEN * 0.5 + 1.2
	var s1: float = curve.get_closest_offset(Vector3((STATION_1[0].x + STATION_1[0].y) * 0.5, pts[0].y, -MONO_SIDE))
	var s2: float = curve.get_closest_offset(Vector3((STATION_2A.x + STATION_2A.y) * 0.5 - 8.0, 80.0, -MONO_SIDE))
	var train := Node3D.new()
	train.name = "MonorailTrain"
	train.set_script(load("res://Monorail.gd"))
	train.set("path", curve)
	train.set("end_car", _save_res(_car_mesh(true), "monorail_end_car"))
	train.set("mid_car", _save_res(_car_mesh(false), "monorail_mid_car"))
	train.set("stops", PackedFloat32Array([s1, s2, L - half_train, s2, s1, half_train]))
	train.set("dwells", PackedFloat32Array([16.0, 14.0, 8.0, 14.0, 16.0, 8.0]))
	train.set("car_pitch", CAR_PITCH)
	train.set("cruise", 21.0)
	train.set("accel", 1.1)
	train.set("stop_names", PackedStringArray(["望江站", "朝阳站", "东站", "朝阳站", "望江站", "西站"]))
	root.add_child(train)


## A monorail car in Yunhai's colours (white, a red waist band, a blue skirt), nose toward -z on the end cars: the
## Bloombay Dunes car's shape (regenerate_bloombay_dunes.gd) built through MegacityKit.
func _car_mesh(nose: bool) -> ArrayMesh:
	var pk := MCK.new_kit(1.0)
	var kit := {}
	var hl := CAR_LEN * 0.5
	var prof := [Vector2(0.0, 0.25), Vector2(1.3, 0.25), Vector2(1.5, 0.5), Vector2(1.5, 1.25), Vector2(1.5, 1.4), Vector2(1.5, 1.55),
		Vector2(1.5, 2.6), Vector2(1.47, 2.85), Vector2(1.32, 3.12), Vector2(0.95, 3.32), Vector2(0.0, 3.42)]
	var cols := [MONO_BLUE, MONO_BLUE, MONO_WHITE, MONO_RED, MONO_WHITE, MONO_GLASS, MONO_WHITE, MONO_WHITE, MONO_WHITE, MONO_WHITE]
	var nose_from := -hl + 3.6
	var rings: Array = [[hl, 0.0]]
	if nose:
		for t in [0.0, 0.15, 0.3, 0.45, 0.6, 0.72, 0.84, 0.93, 1.0]:
			rings.append([nose_from - t * 3.6, t])
	else:
		rings.append([-hl, 0.0])
	var ring_pt := func(p: Vector2, side: float, ring: Array) -> Vector3:
		var t: float = ring[1]
		var sx := 1.0 - 0.3 * t * t
		var sy := 1.0 - 0.4 * pow(t, 1.8)
		return Vector3(p.x * sx * side, 0.25 + (p.y - 0.25) * sy, ring[0])
	for r in rings.size() - 1:
		var r0: Array = rings[r]
		var r1: Array = rings[r + 1]
		for side in [-1.0, 1.0]:
			for k in prof.size() - 1:
				var col: Color = cols[k]
				var tm := (float(r0[1]) + float(r1[1])) * 0.5
				if nose and tm > 0.2 and tm < 0.97 and k >= 5 and k <= 8:
					col = MONO_GLASS
				var a0: Vector3 = ring_pt.call(prof[k], side, r0)
				var a1: Vector3 = ring_pt.call(prof[k + 1], side, r0)
				var b0: Vector3 = ring_pt.call(prof[k], side, r1)
				var b1: Vector3 = ring_pt.call(prof[k + 1], side, r1)
				var mid_p := (a0 + a1 + b0 + b1) * 0.25
				var out := (mid_p - Vector3(0, 1.8, mid_p.z)).normalized()
				var n := (a1 - a0).cross(b0 - a0).normalized()
				if n.dot(out) < 0.0:
					n = -n
				pk.tri(kit, "gloss", a0, a1, b1, n, n, n, col, out)
				pk.tri(kit, "gloss", a0, b1, b0, n, n, n, col, out)
	var ends: Array = [[rings[0], false], [rings[rings.size() - 1], nose]]
	for e in ends:
		var ring: Array = e[0]
		var is_nose: bool = e[1]
		var zf: float = ring[0]
		var outward := Vector3(0, 0, signf(zf))
		var centre := Vector3(0, 1.6, zf + outward.z * (0.25 if is_nose else 0.0))
		for side in [-1.0, 1.0]:
			for k in prof.size() - 1:
				var a: Vector3 = ring_pt.call(prof[k], side, ring)
				var b: Vector3 = ring_pt.call(prof[k + 1], side, ring)
				var col: Color = MONO_WHITE if is_nose else Color(0.3, 0.32, 0.35)
				if is_nose and k == 3:
					col = MONO_RED
				pk.tri(kit, "gloss", a, b, centre, outward, outward, outward, col, outward)
	if nose:
		for sx in [-0.62, 0.62]:
			pk.box(kit, "neon", Transform3D(Basis(), Vector3(sx, 0.62, -hl - 0.05)), Vector3(0.38, 0.14, 0.12), Color(1, 1, 0.9))
	# The windows lit from inside: a warm band along both sides.
	for side in [-1.0, 1.0]:
		pk.box(kit, "neon", Transform3D(Basis(), Vector3(side * 1.515, 2.05, 0.0 if not nose else 1.2)), Vector3(0.03, 0.8, CAR_LEN - (2.0 if not nose else 4.8)),
				Color(0.95, 0.88, 0.7))
	for side in [-1.0, 1.0]:
		pk.block(kit, "paint", Vector3(side * 0.72 - 0.07, -1.1, -hl + 1.2), Vector3(side * 0.72 + 0.07, 0.26, hl - 1.2), Color(0.35, 0.37, 0.4))
	return MCK.commit(pk, kit)


# ---- The stations ---------------------------------------------------------------------------------------------------

## A platform along the monorail's north side from x0 to x1 (its floor level with the cars' floor), a canopy over it and
## over the road beside it, glass screens, lights, the station's name.
func _station(key: String, x0: float, x1: float, name_cn: String, over_road: bool) -> void:
	var mid_x: float = (x0 + x1) * 0.5
	var s_mid: float = lap.closest_s(Vector2(mid_x, 0.0))
	var beam_y: float = lap.y(s_mid) + MONO_UP
	if mid_x < 0.0:
		beam_y = lap.y(0.0) + MONO_UP
	var fy: float = beam_y + 0.3
	var zb: float = -MONO_SIDE
	var id := _id()
	_city(key, func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		var conc := Color(0.75, 0.75, 0.76, float(MCK.STYLE_CONCRETE) / 8.0)
		# The platform: a slab north of the train, a yellow edge, its own columns.
		pk.block(kit, "tower", Vector3(x0, fy - 1.0, zb - 9.0), Vector3(x1, fy, zb - 1.75), conc)
		pk.block(kit, "paint", Vector3(x0, fy, zb - 2.3), Vector3(x1, fy + 0.02, zb - 1.75), Color(0.95, 0.8, 0.1))
		var x: float = x0 + 6.0
		while x < x1:
			var g: float = _ground_at(x, zb - 5.0)
			if fy - 1.0 - g > 1.0:
				pk.box(kit, "tower", Transform3D(Basis(), Vector3(x, (g + fy - 1.0) * 0.5, zb - 5.5)), Vector3(1.2, fy - 1.0 - g, 1.2), conc)
			x += 16.0
		# Glass screens along the platform's edge (gaps at the doors), a wall at the back with the name.
		MCK.glass_rail(pk, kit, Vector3(x0, fy, zb - 1.9), Vector3(x1, fy, zb - 1.9), 2.2, Color(0.3, 0.85, 1.0, 0.0))
		MCK.wall(pk, kit, Vector3(x1, 0, zb - 9.0), Vector3(x0, 0, zb - 9.0), fy, fy + 4.0, Vector3(0, 0, 1), Color(0.85, 0.8, 0.72), MCK.STYLE_INTERIOR, id)
		MCK.wall(pk, kit, Vector3(x0, 0, zb - 9.05), Vector3(x1, 0, zb - 9.05), fy - 1.0, fy + 4.0, Vector3(0, 0, -1), Color(0.2, 0.22, 0.25), MCK.STYLE_CLADDING, id)
		# The canopy: a curved shell on steel arches, over the platform and the line (and the road beside it).
		var zs: float = zb - 9.5
		var ze: float = (road_half + 2.0) if over_road else (zb + 4.0)
		var top: float = fy + 7.0
		var arc: Array = []
		for k in range(9):
			var t: float = float(k) / 8.0
			arc.append(Vector2(lerpf(zs, ze, t), top + sin(t * PI) * 2.2))
		for k2 in range(8):
			var a: Vector2 = arc[k2]
			var b: Vector2 = arc[k2 + 1]
			pk.quad(kit, "tower", [Vector3(x0, a.y, a.x), Vector3(x1, a.y, a.x), Vector3(x1, b.y, b.x), Vector3(x0, b.y, b.x)], Vector3.DOWN,
					Color(0.85, 0.85, 0.88, float(MCK.STYLE_CLADDING) / 8.0))
			pk.quad(kit, "tower", [Vector3(x0, a.y + 0.15, a.x), Vector3(x1, a.y + 0.15, a.x), Vector3(x1, b.y + 0.15, b.x), Vector3(x0, b.y + 0.15, b.x)], Vector3.UP,
					Color(0.55, 0.57, 0.6, float(MCK.STYLE_CONCRETE) / 8.0))
		var ax: float = x0
		while ax <= x1 + 0.1:
			for e in [zs, ze]:
				var g2: float = fy - 1.0 if e == zs else _ground_at(ax, e)
				if e != zs:
					g2 = lap.y(lap.closest_s(Vector2(ax, 0.0))) if over_road else fy
				pk.tube(kit, "steel", Vector3(ax, g2, e), Vector3(ax, top, e), 0.25, 0.25, 8, Color(0.5, 0.52, 0.56))
			for k3 in range(8):
				var a3: Vector2 = arc[k3]
				var b3: Vector2 = arc[k3 + 1]
				MCK.led_line(pk, kit, Vector3(ax, a3.y - 0.05, a3.x), Vector3(ax, b3.y - 0.05, b3.x), Color(0.95, 0.9, 0.8, 0.0), 0.18)
			ax += 12.0
		# The names: over the platform facing the track, and big on the canopy's ends.
		MCK.neon_sign(pk, kit, labels, Vector3(mid_x, fy + 5.2, zb - 8.9), Vector3(0, 0, 1), 12.0, 2.2, name_cn, Color(0.3, 0.85, 1.0))
		for ex in [[x0 - 0.3, -1.0], [x1 + 0.3, 1.0]]:
			MCK.neon_sign(pk, kit, labels, Vector3(float(ex[0]), top + 1.0, (zs + ze) * 0.5), Vector3(float(ex[1]), 0, 0), 14.0, 2.6, name_cn, Color(1.0, 0.85, 0.3))
	, 2200.0)


func _build_stations() -> void:
	_station("station_wangjiang", STATION_1[0].x, STATION_1[0].y, STATION_1[1], false)
	_station("station_chaoyang_a", STATION_2A.x, STATION_2A.y, "朝阳站", true)
	_station("station_chaoyang_b", STATION_2B.x, STATION_2B.y, "朝阳站", true)


# ---- The Jiayuan Building -------------------------------------------------------------------------------------------

## A wall along z at x from za to zb facing `out_x`, with an opening [z from, z to, y from, y to] cut out of it.
func _z_wall(pk: PropKit, kit: Dictionary, x: float, za: float, zb: float, y0: float, y1: float, out_x: float, tint: Color, style: int, id: int,
		hole: Array) -> void:
	var out := Vector3(out_x, 0, 0)
	var lo: float = minf(za, zb)
	var hi: float = maxf(za, zb)
	var g0: float = clampf(float(hole[0]), lo, hi)
	var g1: float = clampf(float(hole[1]), lo, hi)
	var h0: float = clampf(float(hole[2]), y0, y1)
	var h1: float = clampf(float(hole[3]), y0, y1)
	for pc in [[lo, g0, y0, y1], [g1, hi, y0, y1], [g0, g1, y0, h0], [g0, g1, h1, y1]]:
		if float(pc[1]) - float(pc[0]) < 0.05 or float(pc[3]) - float(pc[2]) < 0.05:
			continue
		var pa: float = pc[0] if za < zb else pc[1]
		var pb: float = pc[1] if za < zb else pc[0]
		MCK.wall(pk, kit, Vector3(x, 0, pa), Vector3(x, 0, pb), pc[2], pc[3], out, tint, style, id, absf(pa - za))


func _build_flats() -> void:
	var f: Rect2 = FLATS
	var id := _id()
	var ry: float = lap.y(lap.closest_s(Vector2(f.get_center().x, 0.0)))
	var h0: float = ry - 2.6
	var h1: float = ry + 10.5
	var base: float = minf(minf(_ground_at(f.position.x, f.position.y), _ground_at(f.end.x, f.end.y)),
			minf(_ground_at(f.position.x, f.end.y), _ground_at(f.end.x, f.position.y))) - 2.0
	var top: float = ry + 66.0
	var hole := [FLATS_HOLE_Z.x, FLATS_HOLE_Z.y, h0, h1]
	_city("flats_jiayuan", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		var tint := Color(0.72, 0.68, 0.6)
		var x0: float = f.position.x
		var x1: float = f.end.x
		var z0: float = f.position.y
		var z1: float = f.end.y
		MCK.wall(pk, kit, Vector3(x1, 0, z0), Vector3(x0, 0, z0), base, top, Vector3(0, 0, -1), tint, MCK.STYLE_FLATS, id)
		MCK.wall(pk, kit, Vector3(x0, 0, z1), Vector3(x1, 0, z1), base, top, Vector3(0, 0, 1), tint, MCK.STYLE_FLATS, id)
		_z_wall(pk, kit, x0, z1, z0, base, top, -1.0, tint, MCK.STYLE_FLATS, id, hole)
		_z_wall(pk, kit, x1, z0, z1, base, top, 1.0, tint, MCK.STYLE_FLATS, id, hole)
		MCK.flat(pk, kit, MCK.rect_plan(f.get_center(), f.size.x * 0.5, f.size.y * 0.5), top, Vector3.UP, Color(0.32, 0.32, 0.34), MCK.STYLE_CONCRETE)
		MCK.parapet(pk, kit, MCK.rect_plan(f.get_center(), f.size.x * 0.5, f.size.y * 0.5), top, 1.3, 0.4, Color(0.25, 0.25, 0.28))
		# The hole's lining: a lit ceiling, dark sides, LED lines along it.
		pk.quad(kit, "tower", [Vector3(x0, h1, hole[0]), Vector3(x1, h1, hole[0]), Vector3(x1, h1, hole[1]), Vector3(x0, h1, hole[1])], Vector3.DOWN,
				Color(0.85, 0.82, 0.75, float(MCK.STYLE_INTERIOR) / 8.0))
		for zz in [[float(hole[0]), 1.0], [float(hole[1]), -1.0]]:
			MCK.wall(pk, kit, Vector3(x0, 0, zz[0]), Vector3(x1, 0, zz[0]), h0, h1, Vector3(0, 0, zz[1]), Color(0.2, 0.2, 0.24), MCK.STYLE_CLADDING, id + 1)
		pk.quad(kit, "tower", [Vector3(x0, h0, hole[0]), Vector3(x1, h0, hole[0]), Vector3(x1, h0, hole[1]), Vector3(x0, h0, hole[1])], Vector3.UP,
				Color(0.3, 0.3, 0.32, float(MCK.STYLE_CONCRETE) / 8.0))
		for k in range(6):
			var zl: float = lerpf(float(hole[0]) + 1.0, float(hole[1]) - 1.0, float(k) / 5.0)
			MCK.led_line(pk, kit, Vector3(x0, h1 - 0.08, zl), Vector3(x1, h1 - 0.08, zl), Color(1.0, 0.92, 0.75, 0.0), 0.25)
		for xx in [x0 - 0.1, x1 + 0.1]:
			var o: float = -1.0 if xx < x0 else 1.0
			for e in [[Vector3(xx, h0, hole[0]), Vector3(xx, h1, hole[0])], [Vector3(xx, h1, hole[0]), Vector3(xx, h1, hole[1])],
					[Vector3(xx, h1, hole[1]), Vector3(xx, h0, hole[1])]]:
				MCK.led_line(pk, kit, e[0], e[1], Color(1.0, 0.3, 0.75, 0.0), 0.5)
			# Its name over the hole, and "the light rail goes through the building".
			MCK.neon_sign(pk, kit, labels, Vector3(xx + o * 0.3, h1 + 4.0, (float(hole[0]) + float(hole[1])) * 0.5), Vector3(o, 0, 0), 20.0, 3.6, "嘉园大厦",
					Color(1.0, 0.35, 0.75))
			MCK.neon_sign(pk, kit, labels, Vector3(xx + o * 0.3, h1 + 9.0, (float(hole[0]) + float(hole[1])) * 0.5), Vector3(o, 0, 0), 16.0, 3.0, "轻轨穿楼",
					Color(0.35, 0.9, 1.0))
	, 3200.0)


# ---- The cliff town ---------------------------------------------------------------------------------------------------

const HOUSE_WOOD := [Color(0.36, 0.17, 0.1), Color(0.42, 0.24, 0.13), Color(0.3, 0.14, 0.09), Color(0.5, 0.3, 0.18)]
const SHOP_SIGNS := ["茶馆", "火锅", "小面", "酒家", "客栈", "麻花", "糖画", "豆花", "米酒", "古玩", "书画", "烧烤", "抄手", "火锅", "凉粉", "茶"]


func _build_cliff_town() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3301
	var sign_i := 0
	for li in range(LEGS.size()):
		var s0: float = minf(float(_a["leg%d_0" % li]), float(_a["leg%d_1" % li])) + 18.0
		var s1: float = maxf(float(_a["leg%d_0" % li]), float(_a["leg%d_1" % li])) - 18.0
		var houses: Array = []
		var s: float = s0
		var k := 0
		while s < s1 - 6.0:
			var w: float = rng.randf_range(9.0, 14.0)
			var sc: float = s + w * 0.5
			houses.append([sc, w, rng.randi_range(2, 3), HOUSE_WOOD[rng.randi() % HOUSE_WOOD.size()], k % 4 == 2])
			s += w + rng.randf_range(0.6, 2.0)
			k += 1
		_city("town_leg_%d" % li, func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
			for hs in houses:
				var sc: float = hs[0]
				var p: Vector3 = lap.pt(sc)
				var rt: Vector3 = lap.rt(sc)
				var down: float = signf(rt.z)
				var out: Vector3 = rt * down
				# Downhill: a stilt house, its floor at the road, stilts down the slope, balconies over the river.
				_stilt_house(pk, kit, labels, p + out * (road_half + 1.6), out, float(hs[1]), 11.0, int(hs[2]), hs[3], String(SHOP_SIGNS[sign_i % SHOP_SIGNS.size()]))
				sign_i += 1
				# Uphill: shopfronts in the retaining wall up to the leg above, an eave of tiles, lanterns.
				_uphill_front(pk, kit, labels, p - out * (road_half + 1.6), -out, float(hs[1]), String(SHOP_SIGNS[(sign_i + 5) % SHOP_SIGNS.size()]))
				# Every fourth house spans the road: an upper floor over it on posts.
				if hs[4]:
					_arcade(pk, kit, p, out, float(hs[1]), hs[3])
		, 1600.0)
	# Houses scattered up the slope above the first leg (between it and the plateau's edge), off Jiefang Road.
	var slope_houses: Array = []
	var tries := 0
	while slope_houses.size() < 16 and tries < 400:
		tries += 1
		var hx: float = rng.randf_range(1040.0, 1320.0)
		var hz: float = rng.randf_range(395.0, 452.0)
		if absf(hx - 1240.0) < 26.0:
			continue
		var clash := false
		for o in slope_houses:
			if Vector2(hx, hz).distance_to(Vector2(o[0], o[1])) < 15.0:
				clash = true
		if not clash:
			slope_houses.append([hx, hz, rng.randf_range(9.0, 13.0), rng.randi_range(2, 4), HOUSE_WOOD[rng.randi() % HOUSE_WOOD.size()]])
	_city("town_slope", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		for hsd in slope_houses:
			var fz: float = float(hsd[1]) - 5.0
			var fy: float = _ground_at(float(hsd[0]), fz)
			_stilt_house(pk, kit, labels, Vector3(float(hsd[0]), fy, fz), Vector3(0, 0, 1), float(hsd[2]), 10.0, int(hsd[3]), hsd[4], "")
	, 1800.0)
	# Pavilions and lantern posts round the hairpins' outsides, a cluster of houses at each.
	var hp := [Vector2(1070.0, 500.0), Vector2(1260.0, 540.0), Vector2(1070.0, 580.0), Vector2(1300.0, 630.0)]
	for i in range(hp.size()):
		var c: Vector2 = hp[i]
		var s_c: float = lap.closest_s(c)
		var p2: Vector3 = lap.pt(s_c)
		var outx: float = -1.0 if c.x < 1150.0 else 1.0
		_city("town_hairpins", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
			var pv := Vector3(c.x + outx * 34.0, 0.0, c.y)
			pv.y = _ground_at(pv.x, pv.z)
			_pavilion(pk, kit, pv, maxf(p2.y - pv.y, 0.0))
			for j in range(-2, 3):
				var lp := Vector3(c.x + outx * (road_half + 24.0), 0.0, c.y + float(j) * 9.0)
				lp.y = maxf(_ground_at(lp.x, lp.z), p2.y - 0.5)
				pk.tube(kit, "paint", lp, lp + Vector3(0, 4.0, 0), 0.1, 0.1, 6, Color(0.2, 0.08, 0.06))
				MCK.lantern(pk, kit, lp + Vector3(0, 3.6, 0), 0.9)
		, 1600.0)


## A stilt house (吊脚楼): `front` the middle of its front at the road's height, `out` away from the road. Its floors of
## dark timber with lit windows and shopfronts, a balcony on every floor at the back, a grey tile roof with flared
## eaves, stilts down to the slope, lanterns along the eaves.
func _stilt_house(pk: PropKit, kit: Dictionary, labels: Array, front: Vector3, out: Vector3, w: float, d: float, floors: int, wood: Color, sign_text: String) -> void:
	var along: Vector3 = Vector3.UP.cross(out).normalized()
	var b := Basis(along, Vector3.UP, out)
	var storey := 3.4
	var hgt: float = storey * float(floors)
	var c: Vector3 = front + out * (d * 0.5)
	var dark := Color(0.12, 0.1, 0.09)
	# The floor slab and the stilts.
	pk.box(kit, "paint", Transform3D(b, c + Vector3(0, -0.25, 0)), Vector3(w, 0.5, d), dark)
	for ix in [-0.45, 0.0, 0.45]:
		for iz in [0.15, 0.55, 0.95]:
			var sp: Vector3 = front + along * (ix * w) + out * (iz * d)
			var g: float = _ground_at(sp.x, sp.z)
			if front.y - 0.5 - g > 0.6:
				pk.tube(kit, "paint", Vector3(sp.x, g - 1.0, sp.z), Vector3(sp.x, front.y - 0.5, sp.z), 0.28, 0.24, 6, Color(0.22, 0.13, 0.08))
	# The walls.
	pk.box(kit, "paint", Transform3D(b, c + Vector3(0, hgt * 0.5, 0)), Vector3(w, hgt, d), wood)
	# Each floor: a white-plastered band at the floor line, windows lit on the front and the back.
	for f in range(floors):
		var y: float = storey * float(f)
		pk.box(kit, "paint", Transform3D(b, c + Vector3(0, y + 0.1, 0)), Vector3(w + 0.1, 0.2, d + 0.1), Color(0.75, 0.7, 0.62))
		var nwin: int = maxi(int(w / 3.2), 1)
		for i in range(nwin):
			var u: float = (float(i) + 0.5) / float(nwin) - 0.5
			for face in [-1.0, 1.0]:
				var wc: Vector3 = c + along * (u * w) + out * (face * (d * 0.5 + 0.03)) + Vector3(0, y + 1.8, 0)
				if f == 0 and face < 0.0:
					continue
				var lit: Color = Color(0.55, 0.38, 0.2) if (i + f) % 3 != 0 else Color(0.22, 0.13, 0.07)
				pk.box(kit, "neon", Transform3D(b, wc), Vector3(w / float(nwin) * 0.6, 1.5, 0.04), lit)
		# The balcony at the back.
		if f > 0 or true:
			var by: float = y + 0.05
			pk.box(kit, "paint", Transform3D(b, c + out * (d * 0.5 + 0.8) + Vector3(0, by, 0)), Vector3(w, 0.18, 1.6), dark)
			pk.box(kit, "paint", Transform3D(b, c + out * (d * 0.5 + 1.55) + Vector3(0, by + 0.55, 0)), Vector3(w, 0.08, 0.08), Color(0.55, 0.25, 0.12))
	# The shopfront on the road: a lit opening, a sign board over it.
	var sf: Vector3 = front + Vector3(0, 1.4, 0) - out * 0.03
	pk.box(kit, "neon", Transform3D(b, sf), Vector3(w * 0.7, 2.4, 0.04), Color(0.62, 0.44, 0.25))
	if not sign_text.is_empty():
		MCK.neon_sign(pk, kit, labels, front + Vector3(0, 3.0, 0) - out * 0.12, -out, minf(w * 0.6, 6.0), 1.0, sign_text, Color(1.0, 0.82, 0.35))
	# The roof: two pitches along the house, the eaves flaring up at the corners.
	var ry: float = hgt
	var ridge: float = ry + 2.6
	var ov := 1.4
	var hw: float = w * 0.5 + ov
	var hd: float = d * 0.5 + ov
	var roof := Color(0.16, 0.16, 0.18)
	for side in [-1.0, 1.0]:
		var e0: Vector3 = c + along * (-hw) + out * (side * hd) + Vector3(0, ry - 0.2, 0)
		var e1: Vector3 = c + along * hw + out * (side * hd) + Vector3(0, ry - 0.2, 0)
		var r0: Vector3 = c + along * (-hw + 0.6) + Vector3(0, ridge, 0)
		var r1: Vector3 = c + along * (hw - 0.6) + Vector3(0, ridge, 0)
		var n: Vector3 = (e1 - e0).cross(r0 - e0).normalized()
		if n.y < 0.0:
			n = -n
		pk.quad(kit, "paint", [e0, e1, r1, r0], n, roof)
		# The flared corners.
		for ce in [[e0, -1.0], [e1, 1.0]]:
			var cp: Vector3 = ce[0]
			var tip: Vector3 = cp + along * (float(ce[1]) * 0.9) + out * (side * 0.6) + Vector3(0, 0.9, 0)
			pk.tri(kit, "paint", cp, tip, cp - along * (float(ce[1]) * 2.0) + Vector3(0, 0.25, 0) - out * side * 0.4, Vector3.UP, Vector3.UP, Vector3.UP, roof, Vector3.UP)
	for gx in [-1.0, 1.0]:
		var g0: Vector3 = c + along * (gx * (w * 0.5)) + out * (-d * 0.5) + Vector3(0, ry, 0)
		var g1: Vector3 = c + along * (gx * (w * 0.5)) + out * (d * 0.5) + Vector3(0, ry, 0)
		var gt: Vector3 = c + along * (gx * (w * 0.5 - 0.3)) + Vector3(0, ridge, 0)
		pk.tri(kit, "paint", g0, g1, gt, along * gx, along * gx, along * gx, wood.darkened(0.2), along * gx)
	pk.box(kit, "paint", Transform3D(b, c + Vector3(0, ridge + 0.15, 0)), Vector3(w + 0.4, 0.35, 0.5), Color(0.1, 0.1, 0.11))
	# Lanterns along the front eave and at the back.
	var nl: int = maxi(int(w / 3.5), 1)
	for i2 in range(nl):
		var u2: float = (float(i2) + 0.5) / float(nl) - 0.5
		MCK.lantern(pk, kit, front + along * (u2 * w) - out * 0.9 + Vector3(0, ry - 1.0, 0), 0.75)
		MCK.lantern(pk, kit, front + along * (u2 * w) + out * (d + 2.2) + Vector3(0, storey * 1.0 - 0.8, 0), 0.65)


## The uphill side of a leg: a stone retaining wall up to the leg above, with a row of lit shopfronts in it and a tiled
## eave over them, lanterns, a vertical sign.
func _uphill_front(pk: PropKit, kit: Dictionary, labels: Array, front: Vector3, out: Vector3, w: float, sign_text: String) -> void:
	var along: Vector3 = Vector3.UP.cross(out).normalized()
	var b := Basis(along, Vector3.UP, out)
	var g_back: float = _ground_at(front.x + out.x * 12.0, front.z + out.z * 12.0)
	var top: float = maxf(g_back + 0.5, front.y + 6.0)
	var a: Vector3 = front - along * (w * 0.5 + 0.8)
	var e: Vector3 = front + along * (w * 0.5 + 0.8)
	MCK.wall(pk, kit, Vector3(e.x, 0, e.z), Vector3(a.x, 0, a.z), front.y - 0.5, top, -out, Color(0.5, 0.45, 0.38), MCK.STYLE_SHOPS, 81)
	pk.box(kit, "paint", Transform3D(b, Vector3(front.x, top - 0.1, front.z) + out * 3.0), Vector3(w + 1.6, 0.2, 6.0), Color(0.38, 0.36, 0.32))
	# The eave over the shops.
	var ey: float = front.y + 5.6
	var e0: Vector3 = a + Vector3(0, ey - front.y, 0)
	var e1: Vector3 = e + Vector3(0, ey - front.y, 0)
	pk.quad(kit, "paint", [e0 - out * 1.8 - Vector3(0, 0.6, 0), e1 - out * 1.8 - Vector3(0, 0.6, 0), e1, e0], (Vector3.UP - out * 0.3).normalized(), Color(0.16, 0.16, 0.18))
	MCK.lantern(pk, kit, front - out * 1.4 + Vector3(0, 4.4, 0), 0.7)
	MCK.neon_sign(pk, kit, labels, front - out * 0.3 + along * (w * 0.5 - 0.8) + Vector3(0, 9.0, 0), -out, 1.2, 1.2 * float(sign_text.length()) + 0.8, sign_text,
			Color(1.0, 0.3, 0.2), true, 0.25)


## An upper floor spanning the road from a downhill house to the uphill wall: 6.6m over the road, on posts off it.
func _arcade(pk: PropKit, kit: Dictionary, p: Vector3, out: Vector3, w: float, wood: Color) -> void:
	var along: Vector3 = Vector3.UP.cross(out).normalized()
	var b := Basis(along, Vector3.UP, out)
	var span: float = 2.0 * (road_half + 1.6)
	var y0 := 6.6
	pk.box(kit, "paint", Transform3D(b, p + Vector3(0, y0 + 1.8, 0)), Vector3(w * 0.8, 3.6, span), wood)
	pk.box(kit, "paint", Transform3D(b, p + Vector3(0, y0 - 0.15, 0)), Vector3(w * 0.8 + 0.4, 0.3, span + 0.4), Color(0.12, 0.1, 0.09))
	# Its windows on both faces the drivers see (up and down the road), lanterns under its eaves.
	var nwin: int = maxi(int(span / 3.4), 2)
	for face in [-1.0, 1.0]:
		for i in range(nwin):
			var u: float = (float(i) + 0.5) / float(nwin) - 0.5
			pk.box(kit, "neon", Transform3D(b, p + along * (face * (w * 0.4 + 0.03)) + out * (u * span) + Vector3(0, y0 + 1.9, 0)), Vector3(0.04, 1.4, span / float(nwin) * 0.6),
					Color(0.55, 0.38, 0.2))
		MCK.lantern(pk, kit, p + along * (face * (w * 0.4 + 0.9)) + Vector3(0, y0 - 0.7, 0), 0.8)
	for side in [-1.0, 1.0]:
		for f in [-1.0, 1.0]:
			var post: Vector3 = p + out * (side * (road_half + 1.0)) + along * (f * w * 0.35)
			pk.tube(kit, "paint", post, post + Vector3(0, 6.6, 0), 0.22, 0.22, 6, Color(0.25, 0.1, 0.06))
	var roof_y: float = y0 + 3.6
	pk.box(kit, "paint", Transform3D(b, p + Vector3(0, roof_y + 0.6, 0)), Vector3(w * 0.8 + 2.4, 0.4, span + 1.2), Color(0.16, 0.16, 0.18))
	for side2 in [-1.0, 1.0]:
		MCK.lantern(pk, kit, p + out * (side2 * (span * 0.5 + 0.2)) + Vector3(0, y0 - 0.9, 0), 0.9)


## A hexagonal pavilion on posts: its floor `lift` under the road beside it on stilts, a two-tier roof, lanterns.
func _pavilion(pk: PropKit, kit: Dictionary, base: Vector3, lift: float) -> void:
	var fy: float = base.y + maxf(lift - 0.5, 0.0)
	if lift > 1.0:
		for k in range(6):
			var a: float = TAU * float(k) / 6.0
			var sp: Vector3 = base + Vector3(cos(a) * 4.0, 0, sin(a) * 4.0)
			pk.tube(kit, "paint", Vector3(sp.x, base.y - 1.0, sp.z), Vector3(sp.x, fy, sp.z), 0.3, 0.3, 6, Color(0.22, 0.13, 0.08))
	pk.lathe(kit, "paint", Vector3(base.x, fy - 0.3, base.z), [Vector2(0.001, 0.0), Vector2(5.0, 0.0), Vector2(5.0, 0.3), Vector2(0.001, 0.3)], 6, Color(0.5, 0.48, 0.44), true)
	for k2 in range(6):
		var a2: float = TAU * float(k2) / 6.0
		var cp: Vector3 = Vector3(base.x + cos(a2) * 4.0, fy, base.z + sin(a2) * 4.0)
		pk.tube(kit, "paint", cp, cp + Vector3(0, 4.2, 0), 0.22, 0.22, 6, Color(0.65, 0.1, 0.06))
	pk.lathe(kit, "paint", Vector3(base.x, fy + 4.2, base.z), [Vector2(6.2, 0.6), Vector2(4.5, 1.0), Vector2(2.5, 2.2), Vector2(0.5, 3.4), Vector2(0.001, 3.8)], 6,
			Color(0.14, 0.14, 0.16), true)
	pk.lathe(kit, "paint", Vector3(base.x, fy + 7.4, base.z), [Vector2(3.0, 0.4), Vector2(2.0, 0.8), Vector2(0.6, 1.8), Vector2(0.001, 2.4)], 6, Color(0.14, 0.14, 0.16), true)
	MCK.lantern(pk, kit, Vector3(base.x, fy + 3.6, base.z), 1.2)


# ---- The quay ---------------------------------------------------------------------------------------------------------

func _build_quay() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4401
	var x0 := 120.0
	var x1 := 1360.0
	_city("quay", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		# The river wall: stone from the riverbed to the promenade, a railing with lantern posts along it.
		MCK.wall(pk, kit, Vector3(x0, 0, QUAY_EDGE), Vector3(x1, 0, QUAY_EDGE), -10.5, 4.0, Vector3(0, 0, 1), Color(0.5, 0.47, 0.42), MCK.STYLE_CONCRETE, 82)
		pk.quad(kit, "tower", [Vector3(x0, 4.0, QUAY_Z + road_half + 1.0), Vector3(x1, 4.0, QUAY_Z + road_half + 1.0), Vector3(x1, 4.0, QUAY_EDGE),
				Vector3(x0, 4.0, QUAY_EDGE)], Vector3.UP, Color(0.42, 0.4, 0.38, float(MCK.STYLE_CONCRETE) / 8.0))
		# The railing stops either side of the bridge's foot, where the road crosses the promenade.
		var gap := Vector2(BRIDGE_X - road_half - 4.0, BRIDGE_X + road_half + 4.0)
		MCK.glass_rail(pk, kit, Vector3(x0, 4.0, QUAY_EDGE - 0.3), Vector3(gap.x, 4.0, QUAY_EDGE - 0.3), 1.1, Color(1.0, 0.6, 0.25, 0.0))
		MCK.glass_rail(pk, kit, Vector3(gap.y, 4.0, QUAY_EDGE - 0.3), Vector3(x1, 4.0, QUAY_EDGE - 0.3), 1.1, Color(1.0, 0.6, 0.25, 0.0))
		var x: float = x0 + 6.0
		while x < x1:
			if x > gap.x - 2.0 and x < gap.y + 2.0:
				x += 16.0
				continue
			var lp := Vector3(x, 4.0, QUAY_EDGE - 0.6)
			pk.tube(kit, "paint", lp, lp + Vector3(0, 3.8, 0), 0.1, 0.1, 6, Color(0.2, 0.08, 0.06))
			MCK.lantern(pk, kit, lp + Vector3(0, 3.4, 0), 0.85)
			x += 16.0
		# Shophouses along the foot of the hill facing the quay road: two storeys and a tiled roof, lit, signs.
		var sx: float = 300.0
		var i := 0
		while sx < 1230.0:
			var w: float = rng.randf_range(10.0, 16.0)
			var front := Vector3(sx + w * 0.5, 4.0, QUAY_Z - road_half - 2.0)
			_stilt_house(pk, kit, labels, front, Vector3(0, 0, -1), w, 9.0, 2, HOUSE_WOOD[i % HOUSE_WOOD.size()], String(SHOP_SIGNS[(i + 3) % SHOP_SIGNS.size()]))
			sx += w + 1.0
			i += 1
		# Food stalls along the promenade.
		var fx: float = 330.0
		while fx < 1220.0:
			if rng.randf() < 0.6 and absf(fx - BRIDGE_X) > 40.0:
				var c := Vector3(fx, 4.0, QUAY_Z + road_half + 6.0)
				pk.block(kit, "paint", c + Vector3(-1.6, 0.0, -0.8), c + Vector3(1.6, 1.1, 0.8), Color(0.5, 0.15, 0.1))
				pk.block(kit, "neon", c + Vector3(-1.5, 1.1, -0.7), c + Vector3(1.5, 1.2, 0.7), Color(1.0, 0.8, 0.5))
				pk.block(kit, "paint", c + Vector3(-1.9, 2.5, -1.1), c + Vector3(1.9, 2.6, 1.1), Color.from_hsv(rng.randf(), 0.7, 0.8))
				for dx in [-1.6, 1.6]:
					pk.beam(kit, "steel", c + Vector3(dx, 0, 0.9), c + Vector3(dx, 2.5, 0.9), 0.06, 0.06, Color(0.4, 0.4, 0.4))
			fx += 14.0
		# A red lantern gate over the road at the bridge's foot, its name in gold.
		var s_gate: float = float(_a["bridge0"]) - 20.0
		var g: Vector3 = lap.pt(s_gate)
		var rt: Vector3 = lap.rt(s_gate)
		var fw: Vector3 = lap.fw(s_gate)
		for side in [-1.0, 1.0]:
			for k in range(2):
				var bp: Vector3 = g + rt * side * (road_half + 1.4 + 2.6 * float(k))
				pk.tube(kit, "paint", bp, bp + Vector3(0, 12.0 - 1.6 * float(k), 0), 0.6, 0.6, 10, Color(0.7, 0.08, 0.06))
		pk.box(kit, "paint", Transform3D(Basis(rt, Vector3.UP, fw), g + Vector3(0, 12.4, 0)), Vector3(2.0 * road_half + 9.0, 1.0, 1.5), Color(0.75, 0.1, 0.08))
		pk.box(kit, "paint", Transform3D(Basis(rt, Vector3.UP, fw), g + Vector3(0, 13.6, 0)), Vector3(2.0 * road_half + 12.0, 0.7, 2.6), Color(0.12, 0.13, 0.15))
		MCK.neon_sign(pk, kit, labels, g + Vector3(0, 10.6, 0) - fw * 0.9, -fw, 10.0, 2.2, "望江码头", Color(1.0, 0.8, 0.3))
		for j in range(-4, 5):
			MCK.lantern(pk, kit, g + rt * (float(j) * 2.2) + Vector3(0, 11.2, 0) - fw * 0.9, 0.8)
	, 1800.0)
	# Tour boats moored along the wall: two-deck river boats outlined in LED.
	var boats: Array = [[380.0, 70.0], [580.0, 60.0], [990.0, 80.0], [1230.0, 55.0]]
	for bt in boats:
		var bx: float = bt[0]
		var bl: float = bt[1]
		var id := _id()
		_city("boats", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
			var z: float = QUAY_EDGE + 9.0
			var hull := PackedVector2Array([Vector2(bx - bl * 0.5, z - 7.0), Vector2(bx + bl * 0.4, z - 7.0), Vector2(bx + bl * 0.5, z), Vector2(bx + bl * 0.4, z + 7.0),
				Vector2(bx - bl * 0.5, z + 7.0)])
			MCK.prism(pk, kit, hull, -1.5, 2.5, Color(0.9, 0.9, 0.9), MCK.STYLE_CLADDING, id, true)
			for deck in range(2):
				var y0: float = 2.5 + float(deck) * 3.2
				var shrink: float = 2.0 + float(deck) * 3.0
				var cabin := PackedVector2Array([Vector2(bx - bl * 0.5 + shrink, z - 5.5), Vector2(bx + bl * 0.35 - shrink, z - 5.5), Vector2(bx + bl * 0.35 - shrink, z + 5.5),
					Vector2(bx - bl * 0.5 + shrink, z + 5.5)])
				MCK.prism(pk, kit, cabin, y0, y0 + 3.0, Color(0.85, 0.85, 0.85), MCK.STYLE_OFFICE, id + deck, true)
				for e in range(4):
					var a: Vector2 = cabin[e]
					var b: Vector2 = cabin[(e + 1) % 4]
					MCK.led_line(pk, kit, Vector3(a.x, y0 + 3.05, a.y), Vector3(b.x, y0 + 3.05, b.y), Color.from_hsv(fmod(bx * 0.0013 + float(deck) * 0.3, 1.0), 0.8, 1.0, 0.8), 0.2)
			for e2 in range(5):
				var a2: Vector2 = hull[e2]
				var b2: Vector2 = hull[(e2 + 1) % 5]
				MCK.led_line(pk, kit, Vector3(a2.x, 2.55, a2.y), Vector3(b2.x, 2.55, b2.y), Color(0.3, 0.8, 1.0, 0.4), 0.25)
		, 2400.0)


# ---- The Yunhai Bridge -------------------------------------------------------------------------------------------------

## No piers under the main span between the pylons (the stays carry it).
func _col_blocked(p: Vector3, _g: float) -> bool:
	return absf(p.x - BRIDGE_X) < 30.0 and p.z > float(PYLONS[0]) + 8.0 and p.z < float(PYLONS[1]) - 8.0


## A cable-stayed bridge: two A-shaped white pylons rising 118m out of the river either side of the deck, joined under
## it by a cross beam, LED along their legs, red lights on their tops, fans of stays lit white from each pylon's head to
## both edges of the deck toward the middle and toward the banks, its name on the pylons.
func _build_bridge() -> void:
	_city("bridge_yunhai", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		var white := Color(0.88, 0.89, 0.92)
		for zp in PYLONS:
			var z: float = zp
			var yd: float = lap.y(lap.closest_s(Vector2(BRIDGE_X, z)))
			var top := Vector3(BRIDGE_X, PYLON_TOP, z)
			for side in [-1.0, 1.0]:
				var foot := Vector3(BRIDGE_X + side * 21.0, -11.0, z)
				var head := Vector3(BRIDGE_X + side * 1.6, PYLON_TOP - 4.0, z)
				pk.beam(kit, "gloss", foot, head, 3.4, 4.6, white)
				MCK.led_line(pk, kit, foot + Vector3(side * 1.75, 0, 0), head + Vector3(side * 1.75, 0, 0), Color(0.4, 0.85, 1.0, 0.0), 0.3)
				pk.block(kit, "tower", foot + Vector3(-5.0, 0.0, -5.0), foot + Vector3(5.0, 11.5, 5.0), Color(0.55, 0.55, 0.57, float(MCK.STYLE_CONCRETE) / 8.0))
			pk.box(kit, "gloss", Transform3D(Basis(), Vector3(BRIDGE_X, yd - 3.4, z)), Vector3(34.0, 2.6, 4.4), white)
			pk.box(kit, "gloss", Transform3D(Basis(), top + Vector3(0, -2.0, 0)), Vector3(6.0, 8.0, 5.0), white)
			pk.block(kit, "neon", top + Vector3(-0.6, 2.0, -0.6), top + Vector3(0.6, 3.2, 0.6), Color(1.0, 0.08, 0.04))
			for face in [-1.0, 1.0]:
				MCK.neon_sign(pk, kit, labels, Vector3(BRIDGE_X, PYLON_TOP - 30.0, z + face * 2.6), Vector3(0, 0, face), 3.4, 14.0, "云海大桥",
						Color(1.0, 0.85, 0.4), true, 0.3)
			# The stays: from the head, ten to each edge of the deck each way along it.
			for dirz in [-1.0, 1.0]:
				for k in range(10):
					var dz: float = 22.0 + 10.5 * float(k)
					var zd: float = z + dirz * dz
					var yy: float = lap.y(lap.closest_s(Vector2(BRIDGE_X, zd)))
					for side2 in [-1.0, 1.0]:
						var anchor := Vector3(BRIDGE_X + side2 * 1.4, PYLON_TOP - 8.0 - 3.2 * float(k), z + dirz * 1.2)
						var deck_pt := Vector3(BRIDGE_X + side2 * (road_half + 1.1), yy + 0.2, zd)
						# Steel, faintly lit (bright, they glowed into broad white bars across the view from the deck).
						pk.beam(kit, "steel", anchor, deck_pt, 0.18, 0.18, Color(0.55, 0.57, 0.6))
						MCK.led_line(pk, kit, anchor.lerp(deck_pt, 0.02), anchor.lerp(deck_pt, 0.85), Color(0.22, 0.26, 0.34, 0.0), 0.06)
	, 4000.0)
	# The pylons' legs are solid near the water (boats aside, nothing reaches their tops).
	var body := _body(level, "BridgePylonsBody")
	for zp2 in PYLONS:
		for side3 in [-1.0, 1.0]:
			_box_shape(body, Transform3D(Basis(), Vector3(BRIDGE_X + side3 * 17.0, 10.0, float(zp2))), Vector3(5.0, 40.0, 5.0))


# ---- The Yunhai Plaza: the finish -------------------------------------------------------------------------------------

func _build_plaza() -> void:
	var p: Rect2 = PLAZA2
	var gy := 6.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 5151
	var cx: float = BRIDGE_X
	var mid_z: float = (STANDS_Z.x + STANDS_Z.y) * 0.5
	_city("plaza", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		# The paving, rings of LED set in it round the finish.
		MCK.flat(pk, kit, PackedVector2Array([p.position, Vector2(p.end.x, p.position.y), p.end, Vector2(p.position.x, p.end.y)]), gy + 0.03, Vector3.UP,
				Color(0.62, 0.6, 0.58), MCK.STYLE_CONCRETE)
		for rr in [40.0, 75.0, 110.0, 150.0]:
			var prev := Vector3.ZERO
			for k in range(65):
				var an: float = TAU * float(k) / 64.0
				var q := Vector3(cx + cos(an) * rr, gy + 0.06, mid_z + sin(an) * rr * 0.8)
				if k > 0 and p.has_point(Vector2(q.x, q.z)) and p.has_point(Vector2(prev.x, prev.z)):
					MCK.led_line(pk, kit, prev, q, Color(0.4, 0.8, 1.0, 0.6), 0.25)
				prev = q
		# The entrance arch over the road where the bridge comes down: a ring of light and the plaza's name.
		var za: float = p.position.y + 14.0
		var prev2 := Vector3.ZERO
		for k2 in range(33):
			var an2: float = PI * float(k2) / 32.0
			var q2 := Vector3(cx + cos(an2) * 15.0, gy + sin(an2) * 15.0, za)
			if k2 > 0:
				pk.beam(kit, "gloss", prev2, q2, 0.7, 0.7, Color(0.9, 0.9, 0.92))
				MCK.led_line(pk, kit, prev2 + Vector3(0, 0, -0.4), q2 + Vector3(0, 0, -0.4), Color(1.0, 0.35, 0.8, 0.0), 0.35)
			prev2 = q2
		MCK.neon_sign(pk, kit, labels, Vector3(cx, gy + 12.4, za - 0.6), Vector3(0, 0, -1), 12.0, 2.2, "云海广场", Color(1.0, 0.85, 0.35))
		# The grandstands either side of the finish straight.
		for side in [-1.0, 1.0]:
			_grandstand(pk, kit, labels, side, gy)
		# The stage at the south end: a platform, a big LED screen, side screens, a truss roof, speakers, lasers.
		var sz: float = STAGE_Z
		pk.block(kit, "tower", Vector3(cx - 26.0, gy, sz - 9.0), Vector3(cx + 26.0, gy + 1.8, sz + 9.0), Color(0.1, 0.1, 0.12, float(MCK.STYLE_CLADDING) / 8.0))
		MCK.led_line(pk, kit, Vector3(cx - 26.0, gy + 1.8, sz - 9.05), Vector3(cx + 26.0, gy + 1.8, sz - 9.05), Color(1.0, 0.3, 0.8, 0.0), 0.2)
		MCK.wall(pk, kit, Vector3(cx + 22.0, 0, sz + 8.0), Vector3(cx - 22.0, 0, sz + 8.0), gy + 2.0, gy + 20.0, Vector3(0, 0, -1), Color(0.1, 0.1, 0.12), MCK.STYLE_MEDIA, _id())
		for sx in [-1.0, 1.0]:
			var e0 := Vector3(cx + sx * 31.0, 0, sz + 2.0)
			var e1 := Vector3(cx + sx * 25.0, 0, sz + 7.0)
			MCK.wall(pk, kit, e1 if sx < 0.0 else e0, e0 if sx < 0.0 else e1, gy + 4.0, gy + 14.0, Vector3(-sx * 0.6, 0, -0.8).normalized(), Color(0.1, 0.1, 0.12), MCK.STYLE_MEDIA, _id())
			# Speaker stacks.
			for k3 in range(4):
				pk.block(kit, "paint", Vector3(cx + sx * 28.5 - 1.5, gy + 1.8 * float(k3), sz - 8.0), Vector3(cx + sx * 28.5 + 1.5, gy + 1.8 * float(k3) + 1.7, sz - 5.5),
						Color(0.05, 0.05, 0.06))
			# Truss towers.
			for zz in [sz - 8.0, sz + 7.0]:
				pk.tube(kit, "steel", Vector3(cx + sx * 24.0, gy, zz), Vector3(cx + sx * 24.0, gy + 24.0, zz), 0.4, 0.4, 6, Color(0.6, 0.6, 0.62))
		for zz2 in [sz - 8.0, sz + 7.0]:
			pk.beam(kit, "steel", Vector3(cx - 24.0, gy + 24.0, zz2), Vector3(cx + 24.0, gy + 24.0, zz2), 0.6, 0.6, Color(0.6, 0.6, 0.62))
		for k4 in range(7):
			var lx: float = cx - 21.0 + 7.0 * float(k4)
			pk.beam(kit, "steel", Vector3(lx, gy + 24.0, sz - 8.0), Vector3(lx, gy + 24.0, sz + 7.0), 0.4, 0.4, Color(0.6, 0.6, 0.62))
			var spot := Vector3(lx, gy + 23.4, sz - 7.6)
			var col := Color.from_hsv(float(k4) / 7.0, 0.8, 1.0)
			pk.block(kit, "neon", spot - Vector3(0.4, 0.4, 0.4), spot + Vector3(0.4, 0.4, 0.4), col)
			# A laser into the sky from each spot, fanned.
			var dir := Vector3(sin(float(k4 - 3) * 0.22), 1.0, -0.35).normalized()
			MCK.led_line(pk, kit, spot, spot + dir * 260.0, Color(col.r, col.g, col.b, 0.0), 0.12)
		MCK.neon_sign(pk, kit, labels, Vector3(cx, gy + 22.0, sz - 8.4), Vector3(0, 0, -1), 24.0, 3.0, "云海之夜", Color(1.0, 0.4, 0.85))
		# Fountains either side, outside the stands.
		for fx in [cx - 140.0, cx + 140.0]:
			var fc := Vector3(fx, gy, mid_z)
			pk.lathe(kit, "tower", fc, [Vector2(15.0, 0.0), Vector2(16.0, 0.0), Vector2(16.0, 0.7), Vector2(15.0, 0.7), Vector2(15.0, 0.1), Vector2(0.001, 0.1)], 32,
					Color(0.6, 0.58, 0.55, float(MCK.STYLE_CONCRETE) / 8.0))
			pk.lathe(kit, "neon", fc + Vector3(0, 0.45, 0), [Vector2(0.001, 0.0), Vector2(14.8, 0.0)], 32, Color(0.05, 0.25, 0.45))
			for k5 in range(16):
				var an3: float = TAU * float(k5) / 16.0
				var jp: Vector3 = fc + Vector3(cos(an3) * 10.0, 0.45, sin(an3) * 10.0)
				pk.tube(kit, "neon", jp, jp + Vector3(0, 3.0 + 2.0 * float(k5 % 3), 0), 0.12, 0.05, 5, Color(0.7, 0.9, 1.0))
			pk.tube(kit, "neon", fc, fc + Vector3(0, 12.0, 0), 0.4, 0.1, 6, Color(0.8, 0.95, 1.0))
	, 1600.0)
	# The towers round the plaza: illuminated high-rises, media facades and lit crowns.
	var towers := [[Vector2(505.0, 1370.0), 180.0], [Vector2(505.0, 1460.0), 230.0], [Vector2(505.0, 1550.0), 160.0], [Vector2(1015.0, 1370.0), 200.0],
		[Vector2(1015.0, 1460.0), 260.0], [Vector2(1015.0, 1550.0), 170.0], [Vector2(640.0, 1650.0), 150.0], [Vector2(760.0, 1670.0), 210.0],
		[Vector2(880.0, 1650.0), 150.0]]
	for i in range(towers.size()):
		var t: Array = towers[i]
		var c: Vector2 = t[0]
		var h: float = t[1]
		var id := _id()
		var style: int = MCK.STYLE_MEDIA if i % 3 == 1 else MCK.STYLE_OFFICE
		var tint := Color.from_hsv(0.55 + 0.05 * float(i % 3), 0.25, 0.6)
		var led := Color.from_hsv(float(i) / 9.0, 0.7, 1.0, 0.0)
		_city("plaza_towers", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
			MCK.tower(pk, kit, c, 22.0, 22.0, gy - 1.0, gy + h, tint, style, id, 5.0, 14.0, true, led, true)
			for k6 in range(3):
				var ry: float = gy + h + 2.0 + 5.0 * float(k6)
				var rr2: float = 14.0 - 3.5 * float(k6)
				var prev3 := Vector3.ZERO
				for k7 in range(25):
					var an4: float = TAU * float(k7) / 24.0
					var q3 := Vector3(c.x + cos(an4) * rr2, ry, c.y + sin(an4) * rr2)
					if k7 > 0:
						MCK.led_line(pk, kit, prev3, q3, led, 0.35)
					prev3 = q3
		, 4000.0)
	# The crowd: seated in the stands, standing before the stage and round the fountains.
	for side in [-1.0, 1.0]:
		for row in range(STAND_ROWS):
			var lat: float = STAND_FRONT + 0.6 + float(row) * STAND_DEPTH
			var y: float = gy + STAND_RISE * float(row + 1)
			var z: float = STANDS_Z.x + 1.0
			while z < STANDS_Z.y - 1.0:
				if rng.randf() < 0.62:
					_person(Vector3(cx + side * lat, y, z), Vector3(-side, 0, 0), rng.randf_range(0.92, 1.06), true)
				z += 1.15
	var sz2: float = STAGE_Z - 12.0
	for k8 in range(140):
		var pp := Vector3(cx + rng.randf_range(-24.0, 24.0), gy, sz2 - rng.randf_range(0.0, 10.0))
		_person(pp, Vector3(rng.randf_range(-0.3, 0.3), 0, 1), rng.randf_range(0.92, 1.06))
	for fx2 in [cx - 140.0, cx + 140.0]:
		for k9 in range(26):
			var an5: float = rng.randf() * TAU
			var pp2 := Vector3(fx2 + cos(an5) * 18.5, gy, mid_z + sin(an5) * 18.5)
			_person(pp2, Vector3(fx2 - pp2.x, 0, mid_z - pp2.z), rng.randf_range(0.92, 1.06))
	# Barriers: along the finish straight in front of the stands and across the road's end before the stage's crowd.
	var body := _body(level, "PlazaBarriersBody")
	var fs: float = lap.length - finish_runout
	for side2 in [-1.0, 1.0]:
		_edge_boxes(body, lap, fs - 90.0, lap.length, side2 * (road_half + 2.0), 1.2, 0.4)
	var end_p: Vector3 = lap.pt(lap.length)
	_box_shape(body, Transform3D(Basis(), end_p + Vector3(0, 0.6, 3.0)), Vector3(2.0 * road_half + 6.0, 1.2, 0.6))


## The grandstands' make: STAND_ROWS rows of seats rising STAND_RISE a row from STAND_FRONT off the road's middle.
const STAND_ROWS := 10
const STAND_FRONT := 12.5
const STAND_DEPTH := 1.0
const STAND_RISE := 0.6


func _grandstand(pk: PropKit, kit: Dictionary, labels: Array, side: float, gy: float) -> void:
	var cx: float = BRIDGE_X
	var z0: float = STANDS_Z.x
	var z1: float = STANDS_Z.y
	var conc := Color(0.55, 0.55, 0.57, float(MCK.STYLE_CONCRETE) / 8.0)
	for row in range(STAND_ROWS):
		var l0: float = STAND_FRONT + float(row) * STAND_DEPTH
		var y: float = gy + STAND_RISE * float(row + 1)
		var xa: float = cx + side * l0
		var xb: float = cx + side * (l0 + STAND_DEPTH)
		pk.block(kit, "tower", Vector3(minf(xa, xb), gy, z0), Vector3(maxf(xa, xb), y, z1), conc)
		# The seats' backs, in bands of the cup's colours.
		var seat_x: float = cx + side * (l0 + STAND_DEPTH * 0.8)
		var col: Color = [Color(0.85, 0.15, 0.45), Color(0.2, 0.45, 0.85), Color(0.9, 0.9, 0.92)][row % 3]
		pk.block(kit, "paint", Vector3(seat_x - 0.12, y, z0), Vector3(seat_x + 0.12, y + 0.45, z1), col)
	# The back wall, the roof on columns along it, cantilevered over the rows, LED along its edge; boards along the front.
	var back: float = cx + side * (STAND_FRONT + STAND_DEPTH * float(STAND_ROWS))
	var top_y: float = gy + STAND_RISE * float(STAND_ROWS)
	MCK.wall(pk, kit, Vector3(back, 0, z0 if side > 0.0 else z1), Vector3(back, 0, z1 if side > 0.0 else z0), gy, top_y + 6.0, Vector3(side, 0, 0),
			Color(0.2, 0.21, 0.25), MCK.STYLE_CLADDING, 85)
	var roof_y: float = top_y + 6.0
	var front_x: float = cx + side * (STAND_FRONT + 1.0)
	pk.quad(kit, "tower", [Vector3(back, roof_y, z0), Vector3(back, roof_y, z1), Vector3(front_x, roof_y + 1.2, z1), Vector3(front_x, roof_y + 1.2, z0)], Vector3.UP,
			Color(0.85, 0.86, 0.9, float(MCK.STYLE_CLADDING) / 8.0))
	pk.quad(kit, "tower", [Vector3(back, roof_y - 0.1, z0), Vector3(back, roof_y - 0.1, z1), Vector3(front_x, roof_y + 1.1, z1), Vector3(front_x, roof_y + 1.1, z0)],
			Vector3.DOWN, Color(0.26, 0.27, 0.31, float(MCK.STYLE_CLADDING) / 8.0))
	MCK.led_line(pk, kit, Vector3(front_x, roof_y + 1.15, z0), Vector3(front_x, roof_y + 1.15, z1), Color(0.4, 0.85, 1.0, 0.0), 0.3)
	var z: float = z0
	while z <= z1 + 0.1:
		pk.tube(kit, "steel", Vector3(back - side * 0.4, gy, z), Vector3(back - side * 0.4, roof_y, z), 0.3, 0.3, 6, Color(0.5, 0.52, 0.56))
		z += 25.0
	var fx: float = cx + side * (STAND_FRONT - 0.3)
	MCK.wall(pk, kit, Vector3(fx, 0, z1 if side > 0.0 else z0), Vector3(fx, 0, z0 if side > 0.0 else z1), gy, gy + 1.2, Vector3(-side, 0, 0), Color(0.1, 0.1, 0.14),
			MCK.STYLE_MEDIA, 86)


# ---- The cableway over the river ---------------------------------------------------------------------------------------

func _build_cableway(root: Node3D) -> void:
	var gauge := 12.0
	_city("cableway", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		for e in [[CABLE_A, 1.0, "长江索道"], [CABLE_B, -1.0, "长江索道"]]:
			var top: Vector3 = e[0]
			var dir: float = e[1]
			var g: float = _ground_at(top.x, top.z - dir * 8.0)
			# The station: a hall on a tower, the ropes coming out of its front.
			var hall := MCK.rect_plan(Vector2(top.x, top.z - dir * 8.0), 11.0, 9.0)
			MCK.prism(pk, kit, hall, g - 2.0, top.y + 4.0, Color(0.55, 0.5, 0.45), MCK.STYLE_OFFICE, 83, true)
			MCK.neon_sign(pk, kit, labels, Vector3(top.x, top.y + 6.5, top.z - dir * 8.0 + dir * 9.2), Vector3(0, 0, dir), 14.0, 2.6, String(e[2]), Color(1.0, 0.3, 0.2))
		# The ropes: track ropes sagging between the stations, drawn as LED-lit lines.
		var n := 40
		for side in [-1.0, 1.0]:
			var prev := Vector3.ZERO
			for i in range(n + 1):
				var f: float = float(i) / float(n)
				var p: Vector3 = CABLE_A.lerp(CABLE_B, f) - Vector3(0, 26.0 * 4.0 * f * (1.0 - f), 0) + Vector3(side * gauge * 0.5, 0, 0)
				if i > 0:
					pk.beam(kit, "steel", prev, p, 0.08, 0.08, Color(0.3, 0.3, 0.32))
				prev = p
	, 3600.0)
	var cab_pk := MCK.new_kit(1.0)
	var ck := {}
	cab_pk.box(ck, "steel", Transform3D(Basis(), Vector3(0, -2.0, 0)), Vector3(0.25, 4.0, 0.25), Color(0.3, 0.3, 0.32))
	cab_pk.box(ck, "gloss", Transform3D(Basis(), Vector3(0, -5.6, 0)), Vector3(3.6, 3.2, 7.0), Color(0.8, 0.12, 0.1))
	cab_pk.box(ck, "neon", Transform3D(Basis(), Vector3(0, -5.2, 0)), Vector3(3.66, 1.2, 6.2), Color(1.0, 0.85, 0.6))
	cab_pk.box(ck, "gloss", Transform3D(Basis(), Vector3(0, -4.0, 0)), Vector3(3.8, 0.2, 7.2), Color(0.95, 0.95, 0.95))
	var cab_mesh: ArrayMesh = MCK.commit(cab_pk, ck)
	var cw := Node3D.new()
	cw.name = "Cableway"
	cw.set_script(load("res://CableCar.gd"))
	cw.set("a", CABLE_A)
	cw.set("b", CABLE_B)
	cw.set("sag", 26.0)
	cw.set("gauge", gauge)
	cw.set("cruise", 7.0)
	cw.set("cabin", _save_res(cab_mesh, "cable_cabin"))
	root.add_child(cw)


# ---- Crowds ----------------------------------------------------------------------------------------------------------

func _build_crowds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2301
	# At the start, both sides of the road.
	var s: float = start_s - 40.0
	while s < start_s + 50.0:
		for side in [-1.0, 1.0]:
			for row in range(2):
				if rng.randf() < 0.35:
					continue
				var p: Vector3 = lap.pt(s) + lap.rt(s) * side * (road_half + 2.6 + float(row) * 1.5 + rng.randf() * 0.5)
				p.y = _ground_at(p.x, p.z)
				if absf(p.y - lap.y(s)) < 1.5:
					_person(p, -lap.rt(s) * side, rng.randf_range(0.92, 1.06))
		s += 2.4
	# Waiting on the platforms.
	for st in [STATION_1[0], STATION_2A, STATION_2B]:
		var xr: Vector2 = st
		var y: float = (lap.y(0.0) if xr.x < 0.0 else lap.y(lap.closest_s(Vector2((xr.x + xr.y) * 0.5, 0.0)))) + MONO_UP + 0.3
		_crowd_line(Vector3(xr.x + 4.0, y, -MONO_SIDE - 4.5), Vector3(xr.y - 4.0, y, -MONO_SIDE - 4.5), Vector3(0, 0, 1), 2.0, rng, 0.55)
	# Along the quay's promenade and at the finish.
	_crowd_line(Vector3(BRIDGE_X + 30.0, 4.0, QUAY_Z + road_half + 3.0), Vector3(1200.0, 4.0, QUAY_Z + road_half + 3.0), Vector3(0, 0, -1), 4.0, rng, 0.45)
	# The finish's crowd is the plaza's (`_build_plaza`).
	pass

func _tree_pick(x: float, z: float, roll: float, rng: RandomNumberGenerator) -> Array:
	# Banyan-like dark trees and bamboo on the cliff town's slope between the legs.
	if not TOWN.has_point(Vector2(x, z)) or roll > 0.3:
		return []
	return [["matsu", "take", "momiji"][rng.randi() % 3], rng.randf_range(0.8, 1.05)]


# ======================================================================================
#  After the build
# ======================================================================================

func _finish(root: Node3D) -> void:
	root.set_meta(&"fall_respawn_drop", 11.0)
	root.set_meta(&"music_stage", "wangjiang")
