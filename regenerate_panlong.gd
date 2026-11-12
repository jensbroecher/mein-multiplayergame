extends "res://YunhaiStage.gd"
# Builds levels/PanlongLevel.tscn - Panlong Interchange (盘龙立交, "the coiled dragon"), the Yunhai GP's second stage: a
# circuit through a made-up motorway interchange in Yunhai at the blue hour, the city lit up round it. The user picked it
# from four ideas: a lap that climbs and drops through the knot, under and over its own road, with an unfinished ramp
# to jump and traffic streaming on the levels the race doesn't use.
#
# The lap (game metres, x east, z south) turns left eight times, twice round (720 degrees), crossing itself three times:
#   - the start straight runs east along the ground (z 0), under the coil's two upper legs and over the sunken motorway
#     (the Nanbin Expressway, in a cutting along x 0, its traffic 9m down);
#   - it climbs round the east corner to the top leg (z -300, 22m), where a ramp left unfinished (the Panlong works) has a
#     28m gap to jump, with a kicker;
#   - it comes down the west leg (x -150) over the start straight and the low leg, round the south, and north again
#     (x 120) over the start straight at 12m, west along the low leg (z -160) under the west leg, and down to the ground;
#   - over all of it, at 36m, the Yunhai Ring Expressway runs east and west on its piers (z -60) with its traffic.
# Built on YunhaiStage.gd (the Yunhai GP's base: the city, the night, decks, the signs' font) on the Miyoshino GP's stage
# base. The decks are motorway decks: concrete parapets, LED strips under the edges, hammerhead piers (kept off the lap's
# lower stretches and the cutting), lamp posts, green sign gantries. The traffic is AutobahnTraffic.gd's (CampKit's vans
# and cars with lights).

## Heights along the lap: [plan point on it, height]; lap order, each point well clear of where the lap crosses itself.
const KNOTS := [
	[Vector2(-250.0, 0.0), 0.0], [Vector2(-60.0, 0.0), 0.0], [Vector2(165.0, 0.0), 0.0], [Vector2(280.0, -150.0), 13.0],
	[Vector2(150.0, -300.0), 22.5], [Vector2(-60.0, -300.0), 22.0], [Vector2(-150.0, -220.0), 23.0], [Vector2(-150.0, -80.0), 22.0],
	[Vector2(-150.0, 160.0), 17.0], [Vector2(0.0, 260.0), 14.0], [Vector2(120.0, 120.0), 12.0], [Vector2(120.0, -100.0), 12.0],
	[Vector2(0.0, -160.0), 12.0], [Vector2(-260.0, -160.0), 8.0], [Vector2(-330.0, -80.0), 3.0],
]
## The start line (the finish), on the start straight.
const START_AT := Vector2(-200.0, 0.0)
## The unfinished ramp on the top leg: the lip's plan point, the gap, the kicker's length and height.
const JUMP_LIP := Vector2(124.0, -300.0)
const JUMP_GAP := 28.0
const KICK_LEN := 9.0
const KICK_H := 1.6
## The sunken Nanbin Expressway along x 0: half width of its floor, its floor's height.
const CUT_HALF := 17.0
const CUT_Y := -9.0
const CUT_REACH := 1500.0
## The Yunhai Ring Expressway over everything, along z RING_Z at RING_Y: its half width, its reach either way.
const RING_Z := -60.0
const RING_Y := 36.0
const RING_HALF := 13.5
const RING_REACH := 1500.0
## Where the lap's legs cross the ring and the cutting (no piers there).
const LEG_X := [-330.0, -150.0, 120.0, 280.0]
## The interchange's lawns.
const KNOT_RECT := Rect2(-440.0, -400.0, 830.0, 740.0)
## The footbridge over the start straight (x) and the billboards (plan, facing bearing in degrees).
const FOOTBRIDGE_X := -95.0
const BILLBOARDS := [[Vector2(-255.0, -250.0), 45.0], [Vector2(205.0, -215.0), 160.0], [Vector2(-70.0, 150.0), 10.0], [Vector2(235.0, 175.0), 300.0]]

var _a := {}
var _ys := PackedFloat32Array()


func _configure() -> void:
	level_name = "PanlongLevel"
	level_path = "res://levels/PanlongLevel.tscn"
	stem = "panlong"
	title = "Panlong Interchange"
	seed_base = 8200
	road_half = 7.5
	max_grade = 0.16
	closed = true
	point_to_point = false
	finish_at = START_AT
	corners = [
		[Vector2(-330.0, 0.0), 45.0],
		[Vector2(280.0, 0.0), 70.0],
		[Vector2(280.0, -300.0), 60.0],
		[Vector2(-150.0, -300.0), 60.0],
		[Vector2(-150.0, 260.0), 60.0],
		[Vector2(120.0, 260.0), 50.0],
		[Vector2(120.0, -160.0), 50.0],
		[Vector2(-330.0, -160.0), 50.0],
	]
	fine_x = Vector2(-700.0, 700.0)
	fine_z = Vector2(-650.0, 650.0)
	fine_step = 4.0
	outer = 6000.0
	tree_step = 10.0
	tree_margin = 30.0
	tree_far_range = 900.0
	tree_clear = 14.0
	collide_margin = 80.0
	pier_style = 1
	# The city round the knot (YunhaiStage): streets centred on the start straight (z 0) and the cutting (x 0).
	grid_origin = Vector2(-11.0, -11.0)
	city_mid = Vector2(0.0, 0.0)
	city_near = 1250.0
	city_tall = Vector2(95.0, 60.0)
	park_rect = KNOT_RECT
	skyline_clusters = [Vector2(500.0, -900.0), Vector2(-1300.0, 600.0), Vector2(1700.0, 1200.0), Vector2(-500.0, -1700.0), Vector2(900.0, 2100.0)]


# ======================================================================================
#  The ground: the cutting
# ======================================================================================

func _natural(x: float, z: float) -> float:
	var h: float = super(x, z)
	if absf(z) < CUT_REACH + 200.0:
		var cut: float = 1.0 - smoothstep(CUT_HALF - 0.5, CUT_HALF + 5.0, absf(x))
		h = lerpf(h, CUT_Y, cut)
	return h


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
		# The knots round the closed lap: the last before s and the first after it (wrapping).
		var k0: Array = ks[ks.size() - 1]
		var k1: Array = ks[0]
		for j in range(ks.size()):
			if float(ks[j][0]) <= s:
				k0 = ks[j]
				k1 = ks[(j + 1) % ks.size()]
		var s0: float = k0[0]
		var s1: float = k1[0]
		var span: float = fposmod(s1 - s0, L)
		var t: float = clampf(fposmod(s - s0, L) / maxf(span, 0.001), 0.0, 1.0)
		raw[i] = lerpf(float(k0[1]), float(k1[1]), smoothstep(0.0, 1.0, t) * 0.35 + t * 0.65)
	var sm := raw.duplicate()
	for i in range(n):
		if float(i) > lip - 10.0 and float(i) < land + 10.0:
			continue
		var acc := 0.0
		for d in range(-10, 11):
			acc += raw[posmod(i + d, n)]
		sm[i] = acc / 21.0
	for i in range(n):
		ys[i] = sm[i]
	_ys = ys
	# Anchors.
	_a = {"lip": lip, "land": land, "start": lap.closest_s(START_AT)}
	# Bridges: every stretch more than 2.5m up, and the start straight over the cutting.
	bridges = []
	var in_b := false
	var b0 := 0.0
	for i in range(n):
		var up: bool = ys[i] > 2.5
		if up and not in_b:
			in_b = true
			b0 = float(i)
		elif not up and in_b:
			in_b = false
			bridges.append(["lap", b0, float(i), 0.0, true])
	if in_b:
		bridges.append(["lap", b0, L, 0.0, true])
	var cut_s: float = lap.closest_s(Vector2(0.0, 0.0))
	bridges.append(["lap", cut_s - (CUT_HALF + 12.0), cut_s + (CUT_HALF + 12.0), 0.0, true])
	print("  lap %.0fm, jump lip at %.0fm, bridges %s" % [L, lip, str(bridges.map(func(b): return "%.0f-%.0f" % [b[1], b[2]]))])


func _sections(r: Route) -> Array:
	if r != lap or _a.is_empty():
		return [[0.0, r.length, K_ASPHALT, r.half]]
	return [[0.0, float(_a["lip"]), K_ASPHALT, r.half], [float(_a["land"]), r.length, K_ASPHALT, r.half]]


func _build_deck_slab(_node: Node3D, _r: Route, _s0: float, _s1: float, _idx: int) -> void:
	pass


# ======================================================================================
#  The blue hour
# ======================================================================================

func _environment() -> Dictionary:
	var e: Dictionary = super()
	e["sky_top"] = Color(0.03, 0.04, 0.11)
	e["sky_horizon"] = Color(0.34, 0.17, 0.3)
	e["haze"] = Color(0.19, 0.12, 0.22)
	e["cloud_lit"] = Color(0.36, 0.22, 0.32)
	e["cloud_shade"] = Color(0.1, 0.08, 0.14)
	e["sun_tint"] = Color(1.0, 0.6, 0.45)
	e["sun_horizon_tint"] = Color(1.0, 0.45, 0.3)
	e["sun_horizon_glow"] = 0.25
	e["sun_pitch"] = -4.0
	e["sun_yaw"] = 255.0
	e["sun_color"] = Color(0.95, 0.55, 0.45)
	e["sun_energy"] = 0.35
	e["ambient"] = 0.2
	e["ambient_color"] = Color(0.38, 0.33, 0.48)
	return e


# ======================================================================================
#  Gameplay
# ======================================================================================

func _place_gameplay(root: Node3D) -> void:
	var cps: Array = []
	for q in [Vector2(280.0, -110.0), Vector2(30.0, -300.0), Vector2(-150.0, 110.0), Vector2(60.0, 260.0), Vector2(120.0, 100.0),
			Vector2(-230.0, -160.0)]:
		cps.append(lap.closest_s(q))
	_checkpoints(cps)
	_boosts([["Boost_Straight", lap.closest_s(Vector2(60.0, 0.0)), -2.5], ["Boost_Top", lap.closest_s(Vector2(190.0, -300.0)), 0.0],
		["Boost_WestLeg", lap.closest_s(Vector2(-150.0, 40.0)), 2.5], ["Boost_LowLeg", lap.closest_s(Vector2(-40.0, -160.0)), -2.5]])
	var lip: float = _a["lip"]
	_kicker(root, "Jump_Panlong_Works", lap, lip - KICK_LEN, KICK_LEN, KICK_H, 0.5, false, Color(0.25, 0.27, 0.3))


# ======================================================================================
#  The dressing
# ======================================================================================

func _build_dressing(root: Node3D) -> void:
	_load_cjk_font()
	_rails = _body(root, "MotorwayRailsBody")
	_rails.set_meta(&"surface", "rock")
	_sample_route()
	_reserved.append(KNOT_RECT.grow(10.0))
	_reserved.append(Rect2(-CUT_HALF - 10.0, -CUT_REACH - 300.0, 2.0 * CUT_HALF + 20.0, 2.0 * CUT_REACH + 600.0))
	_reserved.append(Rect2(-RING_REACH - 300.0, RING_Z - RING_HALF - 10.0, 2.0 * RING_REACH + 600.0, 2.0 * RING_HALF + 20.0))
	_build_lap_decks()
	_build_works()
	_build_lamps()
	_build_gantries()
	_build_cutting(root)
	_build_ring(root)
	_build_footbridge()
	_build_billboards()
	_build_city()
	_build_skyline(root)
	_build_crowds()
	print("  dressing: %d buildings, %d people" % [_bid, _people.size()])


## No piers in the cutting, on the ring's line under it or on the street grid's middle lines near the knot.
func _col_blocked(p: Vector3, _g: float) -> bool:
	return absf(p.x) < CUT_HALF + 2.0


# ---- The lap's decks ------------------------------------------------------------------------------------------------

## The decks: everything that is a bridge gets a motorway deck on hammerhead piers; the ground stretches get the same
## parapets on a shallow kerb. LED under the edges by level: amber low, cyan in the middle, magenta on top.
func _build_lap_decks() -> void:
	var L: float = lap.length
	var lip: float = _a["lip"]
	var land: float = _a["land"]
	# Split the lap into runs of up / down (the bridges list) and cut out the jump's gap.
	var cuts: Array = [0.0, L]
	for b in bridges:
		cuts.append(float(b[1]))
		cuts.append(float(b[2]))
	cuts.append(lip)
	cuts.append(land)
	cuts.sort()
	var k := 0
	for i in range(cuts.size() - 1):
		var s0: float = cuts[i]
		var s1: float = cuts[i + 1]
		if s1 - s0 < 1.0 or (s0 >= lip - 0.5 and s1 <= land + 0.5):
			continue
		var mid: float = lap.y((s0 + s1) * 0.5)
		var up: bool = _is_bridge((s0 + s1) * 0.5)
		var led := Color(1.0, 0.6, 0.2, 0.0)
		if mid > 17.0:
			led = Color(1.0, 0.3, 0.85, 0.3)
		elif mid > 6.0:
			led = Color(0.25, 0.85, 1.0, 0.3)
		_deck("deck_lap_%d" % k, s0, s1, 2.0 if up else 0.4, led, 34.0 if up else 0.0, [true, true], 0.0, true)
		k += 1


func _is_bridge(s: float) -> bool:
	for b in bridges:
		if s >= float(b[1]) and s <= float(b[2]):
			return true
	return false


## The unfinished ramp: both deck ends cut square with starter bars sticking out of the faces under the road, hazard
## chevrons across the faces, red warning lamps, a works board.
func _build_works() -> void:
	var lip: float = _a["lip"]
	var land: float = _a["land"]
	_city("deck_works", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		for end in [[lip, 1.0], [land, -1.0]]:
			var s: float = end[0]
			var dir: float = end[1]
			var p: Vector3 = lap.pt(s)
			var rt: Vector3 = lap.rt(s)
			var fw: Vector3 = lap.fw(s) * dir
			# The face: chevrons in yellow and black.
			var w: float = road_half + 0.6
			for i in range(-6, 6):
				var a: Vector3 = p + rt * (float(i) / 6.0 * w) - Vector3(0, 0.15, 0) + fw * 0.05
				var col: Color = Color(1.0, 0.78, 0.1) if i % 2 == 0 else Color(0.06, 0.06, 0.06)
				pk.quad(kit, "paint", [a - Vector3(0, 1.7, 0), a + rt * (w / 6.0) - Vector3(0, 1.7, 0), a + rt * (w / 6.0), a], fw, col)
			# Starter bars.
			for i2 in range(-7, 8):
				for row in [0.6, 1.3]:
					var b: Vector3 = p + rt * (float(i2) * 0.95) - Vector3(0, row, 0)
					pk.beam(kit, "steel", b, b + fw * 1.8, 0.06, 0.06, Color(0.35, 0.22, 0.15))
			# Warning lamps on the parapets' ends.
			for side in [-1.0, 1.0]:
				var l: Vector3 = p + rt * side * (road_half + 0.4) + Vector3(0, 1.3, 0) - fw * 0.6
				pk.block(kit, "neon", l - Vector3(0.25, 0, 0.25), l + Vector3(0.25, 0.5, 0.25), Color(1.0, 0.12, 0.05))
		# The works board on the landing side, facing the way the cars come: "盘龙立交 施工" (the Panlong works).
		var bs: float = lip - 60.0
		var bp: Vector3 = lap.pt(bs) + lap.rt(bs) * (road_half + 3.5)
		MCK.neon_sign(pk, kit, labels, bp + Vector3(0, 6.0, 0), -lap.fw(bs), 10.0, 3.0, "前方施工", Color(1.0, 0.75, 0.15))
		pk.tube(kit, "steel", bp + Vector3(0, -1.0, 0), bp + Vector3(0, 4.5, 0), 0.2, 0.2, 8, Color(0.3, 0.3, 0.32))
	, 2600.0)
	_body_box_gap_ends()


## Nothing to stop a cart driving off the lip's sides: the parapets run to the faces already (rails from `_deck`).
func _body_box_gap_ends() -> void:
	pass


# ---- Lamps and gantries ---------------------------------------------------------------------------------------------

func _build_lamps() -> void:
	_city("deck_lap_lamps", func(pk: PropKit, kit: Dictionary, _l: Array) -> void:
		var s := 10.0
		var k := 0
		var lip: float = _a["lip"]
		var land: float = _a["land"]
		while s < lap.length - 5.0:
			if s > lip - 8.0 and s < land + 8.0:
				s += 30.0
				continue
			var side: float = -1.0 if k % 2 == 0 else 1.0
			var b: Vector3 = lap.pt(s) + lap.rt(s) * side * (road_half + 0.7) + Vector3(0, 1.1, 0)
			pk.tube(kit, "steel", b, b + Vector3(0, 10.0, 0), 0.16, 0.11, 6, Color(0.4, 0.41, 0.44))
			var head: Vector3 = b + Vector3(0, 10.0, 0) - lap.rt(s) * side * 2.6
			pk.beam(kit, "steel", b + Vector3(0, 10.0, 0), head, 0.12, 0.12, Color(0.4, 0.41, 0.44))
			pk.block(kit, "neon", head + Vector3(-0.6, -0.18, -0.35), head + Vector3(0.6, 0.0, 0.35), Color(1.0, 0.82, 0.6))
			s += 30.0
			k += 1
	, 1400.0)


## Green motorway sign gantries over the lap: [plan point, the boards' texts left to right].
const GANTRIES := [
	[Vector2(30.0, 0.0), ["盘龙立交", "市中心 ↑", "机场 →"]],
	[Vector2(-20.0, -300.0), ["云海中心 ←", "滨江路"]],
	[Vector2(-150.0, 60.0), ["星河汇 ↓", "南滨快速路"]],
	[Vector2(120.0, 60.0), ["环城高速 ↑", "江北"]],
]


func _build_gantries() -> void:
	for g in GANTRIES:
		var s: float = lap.closest_s(g[0] as Vector2)
		# The upper of the stretches at that point if it crosses itself there: the one nearest the plan point.
		var p: Vector3 = lap.pt(s)
		var rt: Vector3 = lap.rt(s)
		var fw: Vector3 = lap.fw(s)
		var texts: Array = g[1]
		_city("gantries", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
			var span: float = road_half + 1.6
			for side in [-1.0, 1.0]:
				var foot: Vector3 = p + rt * side * span
				pk.box(kit, "steel", Transform3D(Basis(rt, Vector3.UP, fw), foot + Vector3(0, 4.25, 0)), Vector3(0.5, 8.5, 0.5), Color(0.55, 0.56, 0.58))
			pk.box(kit, "steel", Transform3D(Basis(rt, Vector3.UP, fw), p + Vector3(0, 8.3, 0)), Vector3(2.0 * span + 0.6, 0.5, 0.6), Color(0.55, 0.56, 0.58))
			var n: int = texts.size()
			var bw: float = (2.0 * road_half - 1.0) / float(n)
			for i in range(n):
				var c: Vector3 = p + rt * (-road_half + 0.5 + bw * (float(i) + 0.5)) + Vector3(0, 9.9, 0) - fw * 0.4
				pk.box(kit, "paint", Transform3D(Basis(rt, Vector3.UP, fw), c), Vector3(bw - 0.4, 2.8, 0.15), Color(0.05, 0.36, 0.2))
				pk.box(kit, "neon", Transform3D(Basis(rt, Vector3.UP, fw), c - fw * 0.09), Vector3(bw - 0.6, 2.6, 0.02), Color(0.04, 0.2, 0.12))
				labels.append([String(texts[i]), c - fw * 0.12, -fw, 1.25, Color(1.6, 1.6, 1.6, 1.0), bw - 0.8])
		, 1400.0)


# ---- The sunken Nanbin Expressway along x 0 ---------------------------------------------------------------------------

func _build_cutting(root: Node3D) -> void:
	var z0: float = -CUT_REACH
	var z1: float = CUT_REACH
	_city("deck_cutting", func(pk: PropKit, kit: Dictionary, _l: Array) -> void:
		var z: float = z0
		while z < z1:
			var zb: float = minf(z + 50.0, z1)
			# The carriageways' asphalt, the white lane lines, the central reservation.
			pk.quad(kit, "matte", [Vector3(-CUT_HALF, CUT_Y + 0.03, zb), Vector3(CUT_HALF, CUT_Y + 0.03, zb), Vector3(CUT_HALF, CUT_Y + 0.03, z),
					Vector3(-CUT_HALF, CUT_Y + 0.03, z)], Vector3.UP, Color(0.07, 0.07, 0.08))
			for lx in [-9.5, -5.5, 5.5, 9.5]:
				var d: float = z
				while d < zb:
					pk.quad(kit, "paint", [Vector3(lx - 0.08, CUT_Y + 0.05, d + 4.0), Vector3(lx + 0.08, CUT_Y + 0.05, d + 4.0), Vector3(lx + 0.08, CUT_Y + 0.05, d),
							Vector3(lx - 0.08, CUT_Y + 0.05, d)], Vector3.UP, Color(0.7, 0.7, 0.7))
					d += 10.0
			pk.block(kit, "tower", Vector3(-0.4, CUT_Y, z), Vector3(0.4, CUT_Y + 0.9, zb), Color(0.5, 0.5, 0.52, float(MCK.STYLE_CONCRETE) / 8.0))
			# The retaining walls, an LED line along their tops.
			for side in [-1.0, 1.0]:
				var x: float = side * (CUT_HALF + 0.3)
				MCK.wall(pk, kit, Vector3(x, 0, z if side > 0.0 else zb), Vector3(x, 0, zb if side > 0.0 else z), CUT_Y - 0.2, 1.0,
						Vector3(-side, 0, 0), Color(0.48, 0.47, 0.46), MCK.STYLE_CLADDING, 77)
				MCK.led_line(pk, kit, Vector3(x - side * 0.05, -2.0, z), Vector3(x - side * 0.05, -2.0, zb), Color(0.3, 0.9, 1.0, 0.0), 0.2)
			z = zb
		# The streets of the grid cross it on bridges (the lap's start straight at z 0 has its own deck).
		var j: int = int(ceil(z0 / grid_cell.y))
		while float(j) * grid_cell.y < z1:
			var zc: float = float(j) * grid_cell.y
			if j != 0 and absf(zc - RING_Z) > 20.0:
				var hz: float = grid_street * 0.5
				pk.block(kit, "tower", Vector3(-CUT_HALF - 1.0, -1.4, zc - hz), Vector3(CUT_HALF + 1.0, -0.02, zc + hz), Color(0.4, 0.4, 0.42, float(MCK.STYLE_CONCRETE) / 8.0))
				for e in [-hz, hz]:
					MCK.led_line(pk, kit, Vector3(-CUT_HALF, -1.0, zc + e * 1.01), Vector3(CUT_HALF, -1.0, zc + e * 1.01), Color(1.0, 0.7, 0.3, 0.0), 0.15)
			j += 1
	, 2400.0)
	var t := _traffic_node("NanbinTraffic", Vector3(0.0, CUT_Y + 0.08, CUT_REACH), 0.0, 2.0 * CUT_REACH, PackedFloat32Array([3.5, 7.5, 11.5, -3.5, -7.5, -11.5]))
	root.add_child(t)


# ---- The Yunhai Ring Expressway over everything --------------------------------------------------------------------

func _build_ring(root: Node3D) -> void:
	var x0: float = -RING_REACH
	var x1: float = RING_REACH
	var y: float = RING_Y
	var hw: float = RING_HALF
	_city("deck_ring", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		var x: float = x0
		while x < x1:
			var xb: float = minf(x + 60.0, x1)
			pk.quad(kit, "matte", [Vector3(x, y, RING_Z - hw), Vector3(xb, y, RING_Z - hw), Vector3(xb, y, RING_Z + hw), Vector3(x, y, RING_Z + hw)], Vector3.UP,
					Color(0.07, 0.07, 0.08))
			pk.quad(kit, "tower", [Vector3(x, y - 2.6, RING_Z + hw), Vector3(xb, y - 2.6, RING_Z + hw), Vector3(xb, y - 2.6, RING_Z - hw), Vector3(x, y - 2.6, RING_Z - hw)],
					Vector3.DOWN, Color(0.25, 0.25, 0.28, float(MCK.STYLE_CLADDING) / 8.0))
			for side in [-1.0, 1.0]:
				var z: float = RING_Z + side * hw
				MCK.wall(pk, kit, Vector3(x if side > 0.0 else xb, 0, z), Vector3(xb if side > 0.0 else x, 0, z), y - 2.6, y + 1.1, Vector3(0, 0, side),
						Color(0.5, 0.5, 0.52), MCK.STYLE_CONCRETE, 78)
				MCK.led_line(pk, kit, Vector3(x, y - 1.6, z + side * 0.05), Vector3(xb, y - 1.6, z + side * 0.05), Color(0.95, 0.35, 1.0, 0.6), 0.3)
			for lz in [-9.0, -4.5, 4.5, 9.0]:
				var d: float = x
				while d < xb:
					pk.quad(kit, "paint", [Vector3(d, y + 0.02, RING_Z + lz - 0.08), Vector3(d + 4.0, y + 0.02, RING_Z + lz - 0.08),
							Vector3(d + 4.0, y + 0.02, RING_Z + lz + 0.08), Vector3(d, y + 0.02, RING_Z + lz + 0.08)], Vector3.UP, Color(0.7, 0.7, 0.7))
					d += 10.0
			pk.block(kit, "tower", Vector3(x, y, RING_Z - 0.4), Vector3(xb, y + 0.9, RING_Z + 0.4), Color(0.5, 0.5, 0.52, float(MCK.STYLE_CONCRETE) / 8.0))
			x = xb
		# Piers every 45m, none on the lap's legs or in the cutting; lamps along the reservation.
		var px: float = x0 + 20.0
		while px < x1:
			var ok: bool = absf(px) > CUT_HALF + 6.0
			for lx in LEG_X:
				if absf(px - float(lx)) < road_half + 9.0:
					ok = false
			if ok:
				var g: float = _ground_at(px, RING_Z)
				pk.box(kit, "tower", Transform3D(Basis(), Vector3(px, (g - 1.0 + y - 4.6) * 0.5, RING_Z)), Vector3(3.2, y - 4.6 - g + 1.0, 3.2),
						Color(0.5, 0.5, 0.52, float(MCK.STYLE_CONCRETE) / 8.0))
				pk.box(kit, "tower", Transform3D(Basis(), Vector3(px, y - 3.6, RING_Z)), Vector3(4.0, 2.0, 2.0 * hw * 0.9), Color(0.5, 0.5, 0.52, float(MCK.STYLE_CONCRETE) / 8.0))
			var lamp := Vector3(px, y + 0.9, RING_Z)
			pk.tube(kit, "steel", lamp, lamp + Vector3(0, 9.0, 0), 0.15, 0.1, 6, Color(0.4, 0.41, 0.44))
			for side2 in [-1.0, 1.0]:
				var head := lamp + Vector3(0, 9.0, side2 * 2.5)
				pk.beam(kit, "steel", lamp + Vector3(0, 9.0, 0), head, 0.1, 0.1, Color(0.4, 0.41, 0.44))
				pk.block(kit, "neon", head + Vector3(-0.35, -0.18, -0.5), head + Vector3(0.35, 0.0, 0.5), Color(1.0, 0.85, 0.65))
			px += 45.0
		# The ring's name over the knot, on both faces.
		for side3 in [-1.0, 1.0]:
			MCK.neon_sign(pk, kit, labels, Vector3(-40.0, y - 1.3, RING_Z + side3 * (hw + 0.4)), Vector3(0, 0, side3), 22.0, 2.4, "云海环城高速", Color(0.35, 0.9, 1.0))
	, 3000.0)
	var t := _traffic_node("RingTraffic", Vector3(x0, y + 0.06, RING_Z), -PI * 0.5, 2.0 * RING_REACH, PackedFloat32Array([3.0, 6.6, 10.2, -3.0, -6.6, -10.2]))
	root.add_child(t)


## Traffic along a straight road: AutobahnTraffic.gd at `pos`, turned `yaw` (its road runs along its -z), CampKit's
## vehicles with head- and tail-lights, no sound (the Kronburg GP's engine loops at far less than these distances).
func _traffic_node(node_name: String, pos: Vector3, yaw: float, length: float, lanes: PackedFloat32Array) -> Node3D:
	var meshes: Array[Mesh] = []
	var pk := PropKit.new()
	var mats := {}
	pk.material_for = func(key: String) -> Material:
		if not mats.has(key):
			if key == "lamp":
				var m := StandardMaterial3D.new()
				m.vertex_color_use_as_albedo = true
				m.emission_enabled = true
				m.emission_energy_multiplier = 4.0
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mats[key] = _save_res(m, "traffic_lamp_material")
			else:
				mats[key] = _save_res(CampKit.make_material(key), "traffic_mat_" + key)
		return mats[key]
	var camp := CampKit.new(pk)
	var kinds := [["van", Color(0.92, 0.92, 0.90)], ["suv", Color(0.16, 0.18, 0.22)], ["suv", Color(0.62, 0.10, 0.10)], ["van", Color(0.20, 0.32, 0.55)],
		["suv", Color(0.8, 0.8, 0.82)]]
	for k in kinds:
		var kit := {}
		pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * PROP_SCALE), Vector3.ZERO))
		camp.vehicle(kit, k[0], k[1])
		var mesh: ArrayMesh = pk.commit(kit)
		var bb: AABB = mesh.get_aabb()
		# Headlights at the nose (-z), tail-lights at the back.
		var lk := {}
		pk.set_frame(Transform3D.IDENTITY)
		for sx in [-1.0, 1.0]:
			var x: float = bb.get_center().x + sx * bb.size.x * 0.34
			var y0: float = bb.position.y + bb.size.y * 0.3
			pk.block(lk, "lamp", Vector3(x - 0.3, y0, bb.position.z - 0.06), Vector3(x + 0.3, y0 + 0.22, bb.position.z + 0.02), Color(1.0, 0.95, 0.8))
			pk.block(lk, "lamp", Vector3(x - 0.3, y0, bb.end.z - 0.02), Vector3(x + 0.3, y0 + 0.22, bb.end.z + 0.06), Color(1.0, 0.08, 0.04))
		var lm: ArrayMesh = pk.commit(lk)
		for si in range(lm.get_surface_count()):
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, lm.surface_get_arrays(si))
			mesh.surface_set_material(mesh.get_surface_count() - 1, lm.surface_get_material(si))
		meshes.append(_save_res(mesh, "traffic_%s_%d" % [k[0], meshes.size()]))
	var t := Node3D.new()
	t.name = node_name
	t.set_script(load("res://AutobahnTraffic.gd"))
	t.position = pos
	t.rotation = Vector3(0.0, yaw, 0.0)
	t.set("meshes", meshes)
	t.set("length", length)
	t.set("lanes", lanes)
	t.set("per_lane", 22)
	t.set("speeds", Vector2(22.0, 34.0))
	t.set("fade", 60.0)
	return t


# ---- The footbridge over the start straight and the billboards -------------------------------------------------------

func _build_footbridge() -> void:
	var x: float = FOOTBRIDGE_X
	var y: float = 7.5
	var half: float = 26.0
	_city("footbridge", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		pk.block(kit, "tower", Vector3(x - 2.5, y - 0.8, -half), Vector3(x + 2.5, y, half), Color(0.3, 0.3, 0.34, float(MCK.STYLE_CLADDING) / 8.0))
		for side in [-1.0, 1.0]:
			MCK.glass_rail(pk, kit, Vector3(x + side * 2.4, y, -half), Vector3(x + side * 2.4, y, half), 1.3, Color(1.0, 0.4, 0.8, 0.0))
			MCK.led_line(pk, kit, Vector3(x + side * 2.55, y - 0.4, -half), Vector3(x + side * 2.55, y - 0.4, half), Color(1.0, 0.4, 0.8, 0.0), 0.2)
		# Stair towers at both ends, clear of the road and its parapets.
		for zs in [-1.0, 1.0]:
			var c := Vector2(x, zs * (half + 2.5))
			MCK.prism(pk, kit, MCK.rect_plan(c, 3.5, 3.0), 0.0, y + 3.0, Color(0.2, 0.22, 0.26), MCK.STYLE_CLADDING, 79, true)
		MCK.neon_sign(pk, kit, labels, Vector3(x - 2.6, y - 2.2, 0.0), Vector3(-1, 0, 0), 14.0, 2.4, "欢迎来到云海", Color(1.0, 0.35, 0.8))
	, 1800.0)


func _build_billboards() -> void:
	for b in BILLBOARDS:
		var c: Vector2 = b[0]
		var ang: float = deg_to_rad(float(b[1]))
		var face := Vector3(sin(ang), 0, -cos(ang))
		var side: Vector3 = Vector3.UP.cross(face).normalized()
		var id := _id()
		_city("billboards", func(pk: PropKit, kit: Dictionary, _l: Array) -> void:
			var foot := Vector3(c.x, 0.0, c.y)
			pk.box(kit, "tower", Transform3D(Basis(side, Vector3.UP, face), foot + Vector3(0, 15.0, 0)), Vector3(2.2, 30.0, 2.2),
					Color(0.4, 0.4, 0.42, float(MCK.STYLE_CONCRETE) / 8.0))
			var mid := foot + Vector3(0, 34.0, 0)
			for f in [face, -face]:
				var a: Vector3 = mid + f * 0.5 - side * 14.0 * (1.0 if f == face else -1.0)
				var bb: Vector3 = mid + f * 0.5 + side * 14.0 * (1.0 if f == face else -1.0)
				MCK.wall(pk, kit, a, bb, 28.0, 40.0, f, Color(0.1, 0.1, 0.14), MCK.STYLE_MEDIA, id)
			pk.box(kit, "tower", Transform3D(Basis(side, Vector3.UP, face), mid), Vector3(28.6, 12.6, 0.9), Color(0.15, 0.15, 0.17, float(MCK.STYLE_CLADDING) / 8.0))
		, 3000.0)


# ---- Crowds ----------------------------------------------------------------------------------------------------------

func _build_crowds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2201
	var s0: float = float(_a["start"]) - 70.0
	var s1: float = float(_a["start"]) + 50.0
	var s: float = s0
	while s < s1:
		for side in [-1.0, 1.0]:
			for row in range(2):
				if rng.randf() < 0.35:
					continue
				var p: Vector3 = lap.pt(s) + lap.rt(s) * side * (road_half + 2.6 + float(row) * 1.5 + rng.randf() * 0.5)
				p.y = _ground_at(p.x, p.z)
				_person(p, -lap.rt(s) * side, rng.randf_range(0.92, 1.06))
		s += 2.4
	# On the footbridge, looking down the straight both ways.
	_crowd_line(Vector3(FOOTBRIDGE_X - 1.6, 7.5, -22.0), Vector3(FOOTBRIDGE_X - 1.6, 7.5, 22.0), Vector3(-1, 0, 0), 1.6, rng, 0.75)
	_crowd_line(Vector3(FOOTBRIDGE_X + 1.6, 7.5, -22.0), Vector3(FOOTBRIDGE_X + 1.6, 7.5, 22.0), Vector3(1, 0, 0), 1.6, rng, 0.6)


func _tree_pick(x: float, z: float, roll: float, rng: RandomNumberGenerator) -> Array:
	if not KNOT_RECT.has_point(Vector2(x, z)):
		return []
	if absf(x) < CUT_HALF + 8.0 or absf(z - RING_Z) < RING_HALF + 4.0:
		return []
	# Groups of pines and maples on the lawns with bamboo and a few cherries, the lawn showing between.
	var clump: float = n_ridge.get_noise_2d(x * 3.0, z * 3.0) if n_ridge != null else 0.0
	if roll > 0.12 + 0.3 * maxf(clump, 0.0):
		return []
	var r2: float = rng.randf()
	var kind: String = "matsu" if r2 < 0.4 else ("momiji" if r2 < 0.65 else ("take" if r2 < 0.85 else "sakura"))
	return [kind, rng.randf_range(0.8, 1.1)]


# ======================================================================================
#  After the build
# ======================================================================================

func _finish(root: Node3D) -> void:
	root.set_meta(&"fall_respawn_drop", 9.0)
	root.set_meta(&"music_stage", "panlong")
