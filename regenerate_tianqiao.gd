extends "res://YunhaiStage.gd"
# Builds levels/TianqiaoLevel.tscn - Tianqiao (天桥, "the sky bridges"), the Yunhai GP's first stage: one run at night
# through Yunhai (云海), a made-up river megacity of towers and fog after Chongqing, from the roof of its supertall down
# to a park at street level. The user's idea: rooftops of skyscrapers joined by skyways, gaps to jump between some of
# them, starting on the supertall and dropping to the lower towers, a big mall and an aquarium with giant tanks, the
# finish in a public park at street level.
#
# The run (game metres, x east, z south): the grid on the roof of the Yunhai Center (云海中心, the supertall, its crown
# and spire over the deck) and the long roof of the Yunlang (云廊), the sky gallery laid across four towers at 150m;
# off its end over a kicker and a 30m gap onto tower B's roof (138m); a skyway south through the sky lobby of tower E;
# down the spiral ramp round the round tower C (1.25 turns, 122m to 92m); a skyway to tower D; the second gap, onto the
# roof of the Xinghe Hui mall (星河汇, 70m); into its atrium hall, down three ramps that cascade across it (hairpins at
# the ends) past six floors of shops, LED screens and lanterns; through the aquarium's acrylic tunnel among the tanks
# (fish, rays, a whale shark); out of the mall's south front onto a flyover that comes down into the night-market
# street; along it under the neon to the Yunhai Park (云海公园), the finish among the willows by the lake.
#
# Built on MiyoshinoStage (the Miyoshino GP's stage base: routes, heights, road ribbons and their bodies, gates, pads,
# kickers, crowds, saving): every elevated stretch is a "bridge" left ungraded (b[4] true), and the stage builds its own
# decks, rails and buildings (MegacityKit.gd, in game metres). Its night is megacity_tower.gdshader's lit facades and
# LED shows, megacity_led.gdshader's strips and neon (neon_emissive.gdshader, Label3D signs in a subset of Noto Sans
# CJK SC: fonts/NotoSansSC-Tianqiao.otf, SIL Open Font License), under a dark purple sky in haze.


## The levels of the run.
const Y_TOP := 150.0
const Y_B := 138.0
const Y_SPIRAL_TOP := 122.0
const Y_SPIRAL_LOW := 92.0
const Y_D := 86.0
const Y_MALL := 70.0
const Y_LEG := [70.0, 54.0, 38.0, 26.0]
const Y_AQUA := 26.0

## The Yunhai Center (the supertall): its square plan's half, chamfered corners; its roof is the start's deck.
const TOWER0_C := Vector2(0, 0)
const TOWER0_HALF := 40.0
## The Yunlang: the sky gallery along the start straight, its underside at YUNLANG_UNDER, on four towers.
const YUNLANG_X := Vector2(40.0, 340.0)
const YUNLANG_HALF := 18.0
const YUNLANG_UNDER := 128.0
const YUNLANG_LEGS := [80.0, 160.0, 240.0, 310.0]
## Tower B (the first landing), tower E (the sky lobby), tower C (the spiral), tower D (the second jump).
const B_C := Vector2(416, 0)
const B_HALF := 46.0
const E_C := Vector2(440, 170)
const E_HALF := 22.0
const E_TOP := 176.0
const C_C := Vector2(400, 300)
const C_R := 24.0
const SPIRAL_R := 40.0
const C_TOP := 134.0
const D_C := Vector2(300, 470)
const D_HALF := 30.0
## The mall: its footprint, the atrium hall inside it (floor at HALL_FLOOR, the vault's crown at HALL_TOP), the
## aquarium's tanks round the tunnel.
const MALL := Rect2(160.0, 530.0, 270.0, 300.0)
const HALL := Rect2(172.0, 612.0, 248.0, 86.0)
const HALL_FLOOR := 22.0
const HALL_TOP := 100.0
## The hall's walls stand this far over the mall's roof and its vault springs from their top; the way in off the roof
## is an opening `HALL_ENTRY_H` high under a lintel (the vault had sprung 4m over the roof, its ribs and glass coming
## down into the opening in front of the cars).
const HALL_EAVE := 13.0
const HALL_ENTRY_H := 11.0
const AQUA := Rect2(203.0, 698.0, 84.0, 128.0)
const AQUA_FLOOR := 18.0
const AQUA_SURFACE := 44.0
## The opening in the mall's south front where the tunnel comes out (x from, to; y from, to).
const MALL_PORTAL := Vector2(232.0, 258.0)
const MALL_PORTAL_Y := Vector2(18.0, 38.0)
## The night-market street (its middle along z) and the park.
const STREET_Z := 960.0
const PARK := Rect2(640.0, 984.0, 340.0, 330.0)

## The jumps: [name, s of the lip, gap length, kicker length, kicker height].
var _jumps: Array = []
## Anchors along the lap (s), found once it is built.
var _a := {}


func _configure() -> void:
	level_name = "TianqiaoLevel"
	level_path = "res://levels/TianqiaoLevel.tscn"
	stem = "tianqiao"
	title = "Tianqiao"
	seed_base = 8100
	road_half = 7.0
	max_grade = 0.16
	closed = false
	point_to_point = true
	start_s = 62.0
	finish_runout = 110.0
	corners = [
		[Vector2(-36.0, 0.0), 0.0],
		[Vector2(440.0, 0.0), 20.0],
		[Vector2(440.0, 340.0), SPIRAL_R],
		[Vector2(360.0, 340.0), SPIRAL_R],
		[Vector2(360.0, 260.0), SPIRAL_R],
		[Vector2(440.0, 260.0), SPIRAL_R],
		[Vector2(440.0, 340.0), SPIRAL_R],
		[Vector2(300.0, 340.0), 30.0],
		[Vector2(300.0, 575.0), 22.0],
		[Vector2(412.0, 575.0), 22.0],
		[Vector2(412.0, 632.0), 16.0],
		[Vector2(186.0, 632.0), 12.0],
		[Vector2(186.0, 656.0), 12.0],
		[Vector2(404.0, 656.0), 12.0],
		[Vector2(404.0, 680.0), 12.0],
		[Vector2(245.0, 680.0), 16.0],
		[Vector2(245.0, 960.0), 60.0],
		[Vector2(760.0, 960.0), 30.0],
		[Vector2(760.0, 1240.0), 0.0],
	]
	fine_x = Vector2(-300.0, 1200.0)
	fine_z = Vector2(-300.0, 1450.0)
	fine_step = 8.0
	outer = 6000.0
	tree_step = 9.0
	tree_margin = 40.0
	tree_far_range = 900.0
	tree_clear = 9.0
	collide_margin = 80.0


# ======================================================================================
#  The route's heights
# ======================================================================================

## The s nearest to q past s_from (the lap crosses over itself round the spiral, so a plain nearest point is ambiguous).
func _s_after(q: Vector2, s_from: float, span := 900.0) -> float:
	var best: float = s_from
	var bd := INF
	var s: float = s_from
	while s <= minf(s_from + span, lap.length):
		var d: float = (lap.at(s)["p"] as Vector2).distance_squared_to(q)
		if d < bd:
			bd = d
			best = s
		s += 0.5
	return best


func _find_anchors() -> void:
	var a := {}
	a["jump1"] = _s_after(Vector2(YUNLANG_X.y, 0.0), 0.0)
	a["land1"] = a["jump1"] + 30.0
	a["b_exit"] = _s_after(Vector2(440.0, B_C.y + B_HALF), a["land1"])
	a["e0"] = _s_after(Vector2(440.0, E_C.y - E_HALF - 1.0), a["b_exit"])
	a["e1"] = _s_after(Vector2(440.0, E_C.y + E_HALF + 1.0), a["e0"])
	a["spiral0"] = _s_after(Vector2(440.0, 300.0), a["b_exit"])
	# One full turn round, then a quarter more: the second time past the spiral's start, and on to its south point.
	a["spiral_turn"] = a["spiral0"] + TAU * SPIRAL_R
	a["spiral1"] = a["spiral_turn"] + TAU * SPIRAL_R * 0.25
	a["d0"] = _s_after(Vector2(D_C.x, D_C.y - D_HALF), a["spiral1"])
	a["jump2"] = _s_after(Vector2(D_C.x, D_C.y + D_HALF), a["d0"])
	a["land2"] = a["jump2"] + 30.0
	a["leg1"] = _s_after(Vector2(400.0, 632.0), a["land2"])
	a["leg1_end"] = _s_after(Vector2(198.0, 632.0), a["leg1"])
	a["leg2"] = _s_after(Vector2(198.0, 656.0), a["leg1_end"])
	a["leg2_end"] = _s_after(Vector2(392.0, 656.0), a["leg2"])
	a["leg3"] = _s_after(Vector2(392.0, 680.0), a["leg2_end"])
	a["leg3_end"] = _s_after(Vector2(261.0, 680.0), a["leg3"])
	a["aqua0"] = _s_after(Vector2(245.0, AQUA.position.y), a["leg3_end"])
	a["aqua1"] = _s_after(Vector2(245.0, AQUA.end.y), a["aqua0"])
	a["mall_out"] = _s_after(Vector2(245.0, MALL.end.y), a["aqua1"])
	a["street"] = _s_after(Vector2(470.0, STREET_Z), a["mall_out"])
	a["park"] = _s_after(Vector2(760.0, PARK.position.y), a["street"])
	_a = a


func _shape_heights(r: Route, ys: PackedFloat32Array) -> void:
	if r != lap:
		return
	_find_anchors()
	var a: Dictionary = _a
	var g0: float = GROUND_UNDER
	var knots: Array = [
		[0.0, Y_TOP], [a["jump1"], Y_TOP], [a["land1"], Y_B], [a["b_exit"] + 6.0, Y_B], [a["spiral0"], Y_SPIRAL_TOP],
		[a["spiral1"], Y_SPIRAL_LOW], [a["d0"], Y_D], [a["jump2"], Y_D], [a["land2"], Y_MALL], [a["leg1"], Y_LEG[0]],
		[a["leg1_end"], Y_LEG[1]], [a["leg2"], Y_LEG[1]], [a["leg2_end"], Y_LEG[2]], [a["leg3"], Y_LEG[2]], [a["leg3_end"], Y_LEG[3]],
		[a["aqua0"], Y_AQUA], [a["mall_out"], Y_AQUA], [a["street"], g0], [lap.length, g0]]
	var n: int = ys.size()
	var raw := PackedFloat32Array()
	raw.resize(n)
	var k := 0
	for i in range(n):
		var s := float(i)
		while k < knots.size() - 2 and s > float(knots[k + 1][0]):
			k += 1
		var s0: float = knots[k][0]
		var s1: float = knots[k + 1][0]
		var t: float = clampf((s - s0) / maxf(s1 - s0, 0.001), 0.0, 1.0)
		raw[i] = lerpf(float(knots[k][1]), float(knots[k + 1][1]), t)
	# Round the changes of grade (not across the jumps' gaps: the lips and landings stay sharp).
	var sm := raw.duplicate()
	for i in range(n):
		var s2 := float(i)
		if _near_gap(s2, 10.0):
			continue
		var acc := 0.0
		var cnt := 0
		for d in range(-8, 9):
			var j: int = clampi(i + d, 0, n - 1)
			if _near_gap(float(j), 0.0):
				continue
			acc += raw[j]
			cnt += 1
		sm[i] = acc / float(maxi(cnt, 1))
	for i in range(n):
		ys[i] = sm[i]
	# Everything down to the street is laid by the stage itself (decks, roofs, the mall): ungraded.
	bridges = [["lap", 0.0, float(a["street"]) - 2.0, 0.0, true]]
	_jumps = [["Jump_Yunlang", float(a["jump1"]), 30.0, 9.0, 1.7], ["Jump_Tower_D", float(a["jump2"]), 30.0, 9.0, 1.5]]
	print("  anchors: %s" % str(a))


func _near_gap(s: float, margin: float) -> bool:
	for key in [["jump1", "land1"], ["jump2", "land2"]]:
		if _a.has(key[0]) and s > float(_a[key[0]]) - margin and s < float(_a[key[1]]) + margin:
			return true
	return false


func _sections(r: Route) -> Array:
	if r != lap or _a.is_empty():
		return [[0.0, r.length, K_ASPHALT, r.half]]
	var a: Dictionary = _a
	return [
		[0.0, a["jump1"], K_ASPHALT, r.half],
		[a["land1"], a["b_exit"], K_ASPHALT, r.half],
		[a["b_exit"], a["e0"], K_ASPHALT, r.half],
		[a["e0"], a["e1"], K_ASPHALT, r.half],
		[a["e1"], a["spiral0"], K_ASPHALT, r.half],
		[a["spiral0"], a["spiral1"] + 6.0, K_ASPHALT, r.half],
		[a["spiral1"] + 6.0, a["d0"], K_ASPHALT, r.half],
		[a["d0"], a["jump2"], K_ASPHALT, r.half],
		[a["land2"], a["leg1"], K_ASPHALT, r.half],
		[a["leg1"], a["aqua0"], K_STONE, r.half],
		[a["aqua0"], a["aqua1"], K_STONE, r.half],
		[a["aqua1"], r.length, K_ASPHALT, r.half],
	]


## The stage builds its own decks.
func _build_deck_slab(_node: Node3D, _r: Route, _s0: float, _s1: float, _idx: int) -> void:
	pass


# ======================================================================================
#  Gameplay: gates, pads, the kickers over the gaps
# ======================================================================================

func _place_gameplay(root: Node3D) -> void:
	var a: Dictionary = _a
	# The gates after the jumps stand well past the landings (cars flew over them on tower B's roof): on the glass skyway
	# leaving tower B, and on the mall's roof by the first corner.
	_checkpoints([float(a["b_exit"]) + 25.0, float(a["spiral0"]) - 40.0, float(a["d0"]) + 10.0, float(a["land2"]) + 58.0,
		(float(a["leg2"]) + float(a["leg2_end"])) * 0.5, float(a["mall_out"]) + 40.0, float(a["street"]) + 120.0])
	_boosts([["Boost_Yunlang", float(a["jump1"]) - 70.0, 0.0], ["Boost_Tower_D", float(a["jump2"]) - 40.0, 0.0],
		["Boost_Leg2", float(a["leg2"]) + 60.0, -2.5], ["Boost_Aqua", float(a["aqua0"]) + 10.0, 0.0], ["Boost_Street", float(a["street"]) + 40.0, 2.5]])
	for j in _jumps:
		var lip: float = j[1]
		_kicker(root, String(j[0]), lap, lip - float(j[3]), float(j[3]), float(j[4]), 0.5, false, Color(0.25, 0.27, 0.3))
	print("  jumps: %s" % str(_jumps))


# ======================================================================================
#  The dressing
# ======================================================================================

func _build_dressing(root: Node3D) -> void:
	_load_cjk_font()
	_glass_roads(root)
	_rails = _body(root, "SkyRailsBody")
	_rails.set_meta(&"surface", "rock")
	_sample_route()
	_build_supertall()
	_build_yunlang()
	_build_tower_b()
	_build_skyway_s1()
	_build_tower_e()
	_build_spiral()
	_build_skyway_s2()
	_build_tower_d()
	_build_mall()
	_build_library()
	_build_hall()
	_build_aquarium(root)
	_build_flyover()
	_build_street()
	_build_park()
	_build_city()
	_build_skyline(root)
	_build_crowds()
	_build_air_taxis(root, TAXI_ROUTES)
	print("  dressing: %d buildings, %d people" % [_bid, _people.size()])


## The skyways from tower B down to the spiral and from the spiral to tower D are glass (the user's wish): their road
## ribbons (sections of their own, see `_sections`) are drawn in glass_deck.gdshader instead of the road's material,
## and their decks have no slab (`_deck(..., glass)`).
func _glass_roads(root: Node3D) -> void:
	var ranges: Array = [[float(_a["b_exit"]), float(_a["e0"])], [float(_a["e1"]), float(_a["spiral0"])], [float(_a["spiral1"]) + 6.0, float(_a["d0"])]]
	var mat := ShaderMaterial.new()
	mat.shader = load("res://glass_deck.gdshader")
	var mat_s: Material = _save_res(mat, "glass_deck_material")
	var roads: Node = root.get_node_or_null("Roads")
	if roads == null:
		return
	var n := 0
	for mi in roads.get_children():
		if not mi is MeshInstance3D or (mi as MeshInstance3D).mesh == null:
			continue
		var uvs: PackedVector2Array = (mi as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
		if uvs.is_empty():
			continue
		var lo := INF
		var hi := -INF
		for uv in uvs:
			lo = minf(lo, uv.y)
			hi = maxf(hi, uv.y)
		for r in ranges:
			if lo >= float(r[0]) - 0.01 and hi <= float(r[1]) + 0.01:
				(mi as MeshInstance3D).material_override = mat_s
				n += 1
	print("  glass skyways: %d road pieces" % n)


# ---- The Yunhai Center: the supertall, the start on its roof -------------------------------------------------------

func _build_supertall() -> void:
	var id := _id()
	var c: Vector2 = TOWER0_C
	var h: float = TOWER0_HALF
	_reserved.append(Rect2(c - Vector2(h + 8, h + 8), Vector2(2 * h + 16, 2 * h + 16)))
	_city("supertall", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		# A podium, the shaft in three set-back stages of glass with an LED media band up its middle, the deck.
		MCK.prism(pk, kit, MCK.rect_plan(c, h + 18.0, h + 18.0, 10.0), 0.0, 24.0, Color(0.45, 0.4, 0.36), MCK.STYLE_SHOPS, id, true)
		MCK.prism(pk, kit, MCK.rect_plan(c, h + 6.0, h + 6.0, 14.0), 24.0, 70.0, Color(0.42, 0.55, 0.62), MCK.STYLE_OFFICE, id, true)
		MCK.prism(pk, kit, MCK.rect_plan(c, h + 3.0, h + 3.0, 12.0), 70.0, 112.0, Color(0.4, 0.52, 0.6), MCK.STYLE_OFFICE, id + 1, true)
		MCK.prism(pk, kit, MCK.rect_plan(c, h, h, 10.0), 112.0, Y_TOP, Color(0.38, 0.5, 0.58), MCK.STYLE_OFFICE, id + 2, false)
		for side in [-1.0, 1.0]:
			MCK.wall(pk, kit, Vector3(c.x - 12.0, 0, c.y + side * (h + 6.05)), Vector3(c.x + 12.0, 0, c.y + side * (h + 6.05)), 26.0, 68.0,
					Vector3(0, 0, side), Color(0.2, 0.2, 0.25), MCK.STYLE_MEDIA, id + 3)
		# The deck at the top (the start), the crown: four fins rising from the chamfers, rings of LED, the spire.
		MCK.flat(pk, kit, MCK.rect_plan(c, h, h, 10.0), Y_TOP - 0.06, Vector3.UP, Color(0.28, 0.29, 0.32), MCK.STYLE_CONCRETE)
		for k in range(4):
			var ang: float = PI * 0.25 + PI * 0.5 * float(k)
			var dirv := Vector2(cos(ang), sin(ang))
			var p := c + dirv * (h * 1.414 - 7.0)
			var side_v := Vector2(-dirv.y, dirv.x)
			var fin := PackedVector2Array([p + side_v * 4.0, p + dirv * 3.0, p - side_v * 4.0, p - dirv * 2.0])
			MCK.prism(pk, kit, fin, Y_TOP - 0.1, Y_TOP + 62.0 - 6.0 * float(k % 2), Color(0.3, 0.32, 0.36), MCK.STYLE_CLADDING, id + 4, true)
			MCK.led_line(pk, kit, Vector3((p + dirv * 3.0).x, Y_TOP, (p + dirv * 3.0).y), Vector3((p + dirv * 3.0).x, Y_TOP + 62.0 - 6.0 * float(k % 2), (p + dirv * 3.0).y),
					Color(0.95, 0.75, 0.3, 0.0), 0.4)
		# The crown's rings: steel chords from fin to fin at three heights, LED along them, crossed braces between them
		# (as circles they had touched the fins only at their tips and hung in the air between).
		var rings: Array = [Y_TOP + 20.0, Y_TOP + 38.0, Y_TOP + 54.0]
		var fin_at := func(k: int, y: float) -> Vector3:
			var ang2: float = PI * 0.25 + PI * 0.5 * float(k % 4)
			var q := c + Vector2(cos(ang2), sin(ang2)) * (h * 1.414 - 6.0)
			return Vector3(q.x, y, q.y)
		for k3 in range(4):
			for ri in range(rings.size()):
				var a3: Vector3 = fin_at.call(k3, rings[ri])
				var b3: Vector3 = fin_at.call(k3 + 1, rings[ri])
				pk.beam(kit, "steel", a3, b3, 0.9, 0.9, Color(0.34, 0.35, 0.4))
				var o3 := Vector3((a3 + b3).x * 0.5 - c.x, 0, (a3 + b3).z * 0.5 - c.y).normalized()
				MCK.led_line(pk, kit, a3 + o3 * 0.5, b3 + o3 * 0.5, Color(0.95, 0.8, 0.4, 0.0), 0.35)
				if ri + 1 < rings.size():
					pk.beam(kit, "steel", a3, fin_at.call(k3 + 1, rings[ri + 1]), 0.45, 0.45, Color(0.34, 0.35, 0.4))
					pk.beam(kit, "steel", b3, fin_at.call(k3, rings[ri + 1]), 0.45, 0.45, Color(0.34, 0.35, 0.4))
		# The spire stands on the deck's north side, clear of the grid.
		var sp := Vector3(c.x - 6.0, Y_TOP, c.y - 26.0)
		pk.tube(kit, "steel", sp, sp + Vector3(0, 110.0, 0), 2.2, 0.5, 10, Color(0.6, 0.62, 0.66))
		for y in [40.0, 70.0, 95.0]:
			pk.lathe(kit, "neon", sp + Vector3(0, y, 0), [Vector2(0.001, -0.6), Vector2(1.6, 0.0), Vector2(0.001, 0.6)], 12, Color(1.0, 0.25, 0.15))
		pk.lathe(kit, "neon", sp + Vector3(0, 112.0, 0), [Vector2(0.001, -0.8), Vector2(0.8, 0.0), Vector2(0.001, 0.8)], 10, Color(1.0, 0.1, 0.05))
		# The building's name in red neon along the deck's south edge, facing the start straight's left.
		MCK.neon_sign(pk, kit, labels, Vector3(c.x + 10.0, Y_TOP + 4.5, c.y + h - 2.0), Vector3(0, 0, -1), 22.0, 4.5, "云海中心", Color(1.0, 0.22, 0.18))
	, 3800.0)
	_roof(Rect2(c - Vector2(h, h), Vector2(2.0 * h, 2.0 * h)), Y_TOP, [[1, 2.0, 2.0 * h - 2.0]])


# ---- The Yunlang: the sky gallery along the start straight ---------------------------------------------------------

func _build_yunlang() -> void:
	var id := _id()
	var x0: float = YUNLANG_X.x
	var x1: float = YUNLANG_X.y
	var hz: float = YUNLANG_HALF
	_reserved.append(Rect2(x0, -hz - 6.0, x1 - x0, 2.0 * hz + 12.0))
	_city("yunlang", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		# The gallery: glass walls lit from inside (an observation deck), an LED band under its roof's edge, its soffit lit.
		var plan := PackedVector2Array([Vector2(x0, -hz), Vector2(x1, -hz), Vector2(x1, hz), Vector2(x0, hz)])
		MCK.prism(pk, kit, plan, YUNLANG_UNDER, Y_TOP - 0.06, Color(0.45, 0.6, 0.7), MCK.STYLE_OFFICE, id, false)
		MCK.flat(pk, kit, plan, YUNLANG_UNDER, Vector3.DOWN, Color(0.2, 0.2, 0.24), MCK.STYLE_CLADDING)
		MCK.flat(pk, kit, plan, Y_TOP - 0.06, Vector3.UP, Color(0.28, 0.29, 0.32), MCK.STYLE_CONCRETE)
		for zz in [-hz, hz]:
			MCK.led_line(pk, kit, Vector3(x0, YUNLANG_UNDER + 0.3, zz), Vector3(x1, YUNLANG_UNDER + 0.3, zz), Color(0.9, 0.6, 1.0, 0.8), 0.5)
			MCK.led_line(pk, kit, Vector3(x0, Y_TOP - 1.4, zz), Vector3(x1, Y_TOP - 1.4, zz), Color(0.3, 0.85, 1.0, 0.0), 0.3)
		# The four towers it rests on.
		for lx in YUNLANG_LEGS:
			var tid := _id()
			MCK.tower(pk, kit, Vector2(lx, 0.0), 14.0, 14.0, 0.0, YUNLANG_UNDER, Color(0.5, 0.48, 0.45), MCK.STYLE_FLATS, tid, 4.0, 18.0, true,
					Color(0.95, 0.75, 0.35, 0.0), false)
		# On the roof: planters with trees' crowns (dark), an infinity pool along the north side, lamp posts.
		for xx in range(int(x0) + 24, int(x1) - 20, 36):
			for zz2 in [-hz + 3.5, hz - 3.5]:
				pk.block(kit, "tower", Vector3(xx - 6.0, Y_TOP - 0.1, zz2 - 1.2), Vector3(xx + 6.0, Y_TOP + 0.8, zz2 + 1.2), Color(0.35, 0.35, 0.37, 5.0 / 8.0))
				pk.lathe(kit, "matte", Vector3(xx, Y_TOP + 0.8, zz2), [Vector2(0.001, 0.0), Vector2(2.4, 0.6), Vector2(2.6, 1.6), Vector2(1.6, 2.8),
						Vector2(0.001, 3.2)], 8, Color(0.12, 0.2, 0.12))
		var pool := PackedVector2Array([Vector2(x0 + 30.0, -hz + 6.5), Vector2(x1 - 30.0, -hz + 6.5), Vector2(x1 - 30.0, -hz + 8.8), Vector2(x0 + 30.0, -hz + 8.8)])
		for i in range(pool.size()):
			pass
		pk.block(kit, "neon", Vector3(x0 + 30.0, Y_TOP - 0.05, -hz + 6.5), Vector3(x1 - 30.0, Y_TOP + 0.02, -hz + 8.8), Color(0.1, 0.45, 0.75))
		# Its name in neon over the jump's edge, facing the way the cars come.
		MCK.neon_sign(pk, kit, labels, Vector3(x1 + 0.4, YUNLANG_UNDER + 9.0, 0.0), Vector3(1, 0, 0), 16.0, 6.0, "云廊", Color(0.35, 0.85, 1.0))
	, 3800.0)
	_roof(Rect2(x0, -hz, x1 - x0, 2.0 * hz), Y_TOP, [[3, 0.0, 2.0 * hz], [1, hz - road_half - 0.6, hz + road_half + 0.6]])


# ---- Tower B: the first landing -------------------------------------------------------------------------------------

func _build_tower_b() -> void:
	var id := _id()
	var c: Vector2 = B_C
	var h: float = B_HALF
	_reserved.append(Rect2(c - Vector2(h + 6, h + 6), Vector2(2 * h + 12, 2 * h + 12)))
	_city("tower_b", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		MCK.tower(pk, kit, c, h, h, 0.0, Y_B - 0.06, Color(0.6, 0.58, 0.55), MCK.STYLE_FLATS, id, 6.0, 20.0, true, Color(1.0, 0.4, 0.8, 0.0), false, false)
		# A media wall on its west face (seen in the air off the jump).
		MCK.wall(pk, kit, Vector3(c.x - h - 0.06, 0, c.y + h - 8.0), Vector3(c.x - h - 0.06, 0, c.y - h + 8.0), 40.0, Y_B - 8.0, Vector3(-1, 0, 0),
				Color(0.15, 0.15, 0.2), MCK.STYLE_MEDIA, id + 1)
		# The helipad.
		var hp := Vector3(c.x - 18.0, Y_B - 0.04, c.y - 24.0)
		var pts: Array = []
		for k in range(33):
			var a: float = TAU * float(k) / 32.0
			pts.append(hp + Vector3(cos(a) * 10.0, 0.0, sin(a) * 10.0))
		for k2 in range(32):
			MCK.led_line(pk, kit, pts[k2], pts[k2 + 1], Color(0.2, 1.0, 0.4, 0.0), 0.2)
		MCK.neon_sign(pk, kit, labels, Vector3(c.x + h - 3.0, Y_B + 6.0, c.y), Vector3(-1, 0, 0), 14.0, 5.0, "龙凤大厦", Color(1.0, 0.3, 0.75))
	, 3800.0)
	_roof(Rect2(c - Vector2(h, h), Vector2(2.0 * h, 2.0 * h)), Y_B, [[3, 0.0, 2.0 * h], [2, (c.x + h - 440.0) - road_half - 0.6, (c.x + h - 440.0) + road_half + 0.6]])


# ---- Skyway S1 south from tower B, through tower E's sky lobby ------------------------------------------------------

func _build_skyway_s1() -> void:
	var s0: float = float(_a["b_exit"])
	var s1: float = float(_a["spiral0"])
	var e0: float = _a["e0"]
	var e1: float = _a["e1"]
	# Glass skyways (the user's wish): see `_glass_roads`.
	_deck("deck_skyway_s1", s0, e0, 2.6, Color(0.95, 0.4, 1.0, 0.7), 0.0, [true, true], 0.0, false, true)
	_deck("deck_skyway_s1", e1, s1, 2.6, Color(0.95, 0.4, 1.0, 0.7), 0.0, [true, true], 0.0, false, true)
	# Inside the lobby: the floor, glass sides (the rails), LED along the ceiling.
	_deck("deck_lobby_e", e0, e1, 1.0, Color(1.0, 0.85, 0.5, 0.0), 0.0)


func _build_tower_e() -> void:
	var id := _id()
	var c: Vector2 = E_C
	var h: float = E_HALF
	_reserved.append(Rect2(c - Vector2(h + 6, h + 6), Vector2(2 * h + 12, 2 * h + 12)))
	var ly: float = lap.y(_s_after(Vector2(440.0, E_C.y), float(_a["b_exit"])))
	var lo: float = ly - 2.0
	var hi: float = ly + 12.0
	_city("tower_e", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		MCK.prism(pk, kit, MCK.rect_plan(c, h, h, 5.0), 0.0, lo, Color(0.4, 0.5, 0.58), MCK.STYLE_OFFICE, id, true)
		MCK.prism(pk, kit, MCK.rect_plan(c, h, h, 5.0), hi, E_TOP, Color(0.4, 0.5, 0.58), MCK.STYLE_OFFICE, id, true)
		MCK.flat(pk, kit, MCK.rect_plan(c, h, h, 5.0), hi, Vector3.DOWN, Color(0.95, 0.9, 0.8), MCK.STYLE_INTERIOR)
		MCK.parapet(pk, kit, MCK.rect_plan(c, h, h, 5.0), E_TOP, 1.3, 0.4, Color(0.2, 0.21, 0.24))
		# The lobby between: glass all round (the cars run through it), columns at the corners, a lit ceiling.
		for k in range(4):
			var p: Vector2 = MCK.rect_plan(c, h, h, 5.0)[k * 2]
			pk.tube(kit, "tower", Vector3(p.x, lo, p.y), Vector3(p.x, hi, p.y), 1.2, 1.2, 8, Color(0.5, 0.5, 0.52, 5.0 / 8.0))
		for side in [-1.0, 1.0]:
			var x: float = c.x + side * (h - 0.5)
			pk.quad(kit, "glass", [Vector3(x, lo, c.y - h + 4.0), Vector3(x, lo, c.y + h - 4.0), Vector3(x, hi, c.y + h - 4.0), Vector3(x, hi, c.y - h + 4.0)],
					Vector3(side, 0, 0), Color(1, 1, 1))
		for zz in range(-int(h) + 3, int(h) - 2, 4):
			MCK.led_line(pk, kit, Vector3(c.x - h + 2.0, hi - 0.2, c.y + float(zz)), Vector3(c.x + h - 2.0, hi - 0.2, c.y + float(zz)), Color(1.0, 0.9, 0.7, 0.0), 0.25)
		MCK.neon_sign(pk, kit, labels, Vector3(c.x, hi + 4.0, c.y - h - 0.5), Vector3(0, 0, -1), 12.0, 4.0, "天桥", Color(1.0, 0.8, 0.3))
		MCK.led_line(pk, kit, Vector3(c.x - h, E_TOP + 1.3, c.y - h), Vector3(c.x - h, 20.0, c.y - h), Color(0.4, 0.8, 1.0, 0.0), 0.4)
	, 3800.0)


# ---- Tower C and the spiral ramp round it ---------------------------------------------------------------------------

func _build_spiral() -> void:
	var id := _id()
	var c: Vector2 = C_C
	_reserved.append(Rect2(c - Vector2(SPIRAL_R + 16, SPIRAL_R + 16), Vector2(2 * SPIRAL_R + 32, 2 * SPIRAL_R + 32)))
	var s0: float = float(_a["spiral0"])
	var s1: float = float(_a["spiral1"])
	_city("tower_c", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		# A round tower of flats, its crown a lit drum.
		var plan := PackedVector2Array()
		for k in range(24):
			var a: float = TAU * float(k) / 24.0
			plan.append(c + Vector2(cos(a), sin(a)) * C_R)
		MCK.prism(pk, kit, plan, 0.0, C_TOP, Color(0.62, 0.6, 0.56), MCK.STYLE_FLATS, id, true)
		var crown := PackedVector2Array()
		for k2 in range(24):
			var a2: float = TAU * float(k2) / 24.0
			crown.append(c + Vector2(cos(a2), sin(a2)) * (C_R - 3.0))
		MCK.prism(pk, kit, crown, C_TOP, C_TOP + 10.0, Color(0.2, 0.2, 0.25), MCK.STYLE_MEDIA, id + 1, true)
		# Cantilever arms from the tower out under the ramp, every 20 degrees of its turn.
		var s: float = s0 + 6.0
		while s < s1:
			var p: Vector3 = lap.pt(s)
			var inward: Vector2 = (c - Vector2(p.x, p.z)).normalized()
			var foot := Vector3(c.x - inward.x * C_R, p.y - 6.0, c.y - inward.y * C_R)
			pk.beam(kit, "tower", foot, Vector3(p.x, p.y - 1.4, p.z) - Vector3(inward.x, 0, inward.y) * 5.0, 1.0, 1.2,
					Color(0.45, 0.46, 0.48, 5.0 / 8.0))
			s += SPIRAL_R * deg_to_rad(20.0)
		MCK.neon_sign(pk, kit, labels, Vector3(c.x, C_TOP + 5.0, c.y + C_R - 2.6), Vector3(0, 0, 1), 10.0, 4.0, "螺旋", Color(0.4, 1.0, 0.6))
	, 3800.0)
	_deck("deck_spiral", s0 - 6.0, s1 + 6.0, 1.6, Color(0.3, 1.0, 0.6, 0.5), 0.0)


# ---- Skyway S2 to tower D, the second jump ---------------------------------------------------------------------------

func _build_skyway_s2() -> void:
	_deck("deck_skyway_s2", float(_a["spiral1"]) + 6.0, float(_a["d0"]), 2.4, Color(1.0, 0.75, 0.3, 0.0), 48.0, [true, true], 0.0, false, true)


func _build_tower_d() -> void:
	var id := _id()
	var c: Vector2 = D_C
	var h: float = D_HALF
	_reserved.append(Rect2(c - Vector2(h + 6, h + 6), Vector2(2 * h + 12, 2 * h + 12)))
	_city("tower_d", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		MCK.tower(pk, kit, c, h, h, 0.0, Y_D - 0.06, Color(0.35, 0.45, 0.55), MCK.STYLE_OFFICE, id, 5.0, 16.0, true, Color(0.3, 0.6, 1.0, 0.8), false, false)
		MCK.wall(pk, kit, Vector3(c.x + h + 0.06, 0, c.y - h + 6.0), Vector3(c.x + h + 0.06, 0, c.y + h - 6.0), 24.0, Y_D - 6.0, Vector3(1, 0, 0),
				Color(0.15, 0.15, 0.2), MCK.STYLE_MEDIA, id + 1)
		MCK.neon_sign(pk, kit, labels, Vector3(c.x - h + 3.0, Y_D + 5.0, c.y + 10.0), Vector3(1, 0, 0), 12.0, 4.0, "金鼎", Color(1.0, 0.8, 0.25))
	, 3800.0)
	_roof(Rect2(c - Vector2(h, h), Vector2(2.0 * h, 2.0 * h)), Y_D, [[0, h - road_half - 0.6, h + road_half + 0.6], [2, h - road_half - 0.6, h + road_half + 0.6]])


# ---- The Xinghe Hui mall: its block, the roof, the atrium hall -------------------------------------------------------

func _build_mall() -> void:
	var id := _id()
	var m: Rect2 = MALL
	_reserved.append(m.grow(6.0))
	_city("mall", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		var plan := MCK.rect_plan(m.get_center(), m.size.x * 0.5, m.size.y * 0.5, 14.0)
		# The walls round (the plan runs clockwise seen from above, so out is the edge turned left), the south front
		# left open round the portal where the aquarium's tunnel comes out onto the flyover.
		for i in range(plan.size()):
			var p0: Vector2 = plan[i]
			var p1: Vector2 = plan[(i + 1) % plan.size()]
			var e: Vector2 = (p1 - p0).normalized()
			var area := 0.0
			for k in range(plan.size()):
				area += plan[k].x * plan[(k + 1) % plan.size()].y - plan[(k + 1) % plan.size()].x * plan[k].y
			var o2: Vector2 = Vector2(e.y, -e.x) if area > 0.0 else Vector2(-e.y, e.x)
			var out := Vector3(o2.x, 0, o2.y)
			var spans: Array = [[p0, p1, 0.0, Y_MALL - 0.06]]
			if absf(p0.y - m.end.y) < 0.1 and absf(p1.y - m.end.y) < 0.1:
				var hi_x: float = maxf(p0.x, p1.x)
				var lo_x: float = minf(p0.x, p1.x)
				var g0: float = MALL_PORTAL.x
				var g1: float = MALL_PORTAL.y
				spans = [[Vector2(hi_x, m.end.y), Vector2(g1, m.end.y), 0.0, Y_MALL - 0.06], [Vector2(g0, m.end.y), Vector2(lo_x, m.end.y), 0.0, Y_MALL - 0.06],
					[Vector2(g1, m.end.y), Vector2(g0, m.end.y), 0.0, MALL_PORTAL_Y.x], [Vector2(g1, m.end.y), Vector2(g0, m.end.y), MALL_PORTAL_Y.y, Y_MALL - 0.06]]
			for sp in spans:
				var a2: Vector2 = sp[0]
				var b2: Vector2 = sp[1]
				var y0: float = sp[2]
				var y1: float = sp[3]
				if y0 < 12.0:
					MCK.wall(pk, kit, Vector3(a2.x, 0, a2.y), Vector3(b2.x, 0, b2.y), y0, minf(12.0, y1), out, Color(0.55, 0.5, 0.45), MCK.STYLE_SHOPS, id)
				if y1 > 12.0:
					MCK.wall(pk, kit, Vector3(a2.x, 0, a2.y), Vector3(b2.x, 0, b2.y), maxf(12.0, y0), y1, out, Color(0.2, 0.2, 0.25), MCK.STYLE_MEDIA, id + 1)
		# The portal's reveals (dark, 6m deep), an LED frame round it.
		var z1: float = m.end.y
		for gx in [MALL_PORTAL.x, MALL_PORTAL.y]:
			var o3: float = 1.0 if gx == MALL_PORTAL.x else -1.0
			MCK.wall(pk, kit, Vector3(gx, 0, z1 - 6.0), Vector3(gx, 0, z1), MALL_PORTAL_Y.x, MALL_PORTAL_Y.y, Vector3(o3, 0, 0), Color(0.15, 0.15, 0.18), MCK.STYLE_CLADDING, id)
		pk.quad(kit, "tower", [Vector3(MALL_PORTAL.x, MALL_PORTAL_Y.y, z1 - 6.0), Vector3(MALL_PORTAL.y, MALL_PORTAL_Y.y, z1 - 6.0), Vector3(MALL_PORTAL.y, MALL_PORTAL_Y.y, z1),
				Vector3(MALL_PORTAL.x, MALL_PORTAL_Y.y, z1)], Vector3.DOWN, Color(0.15, 0.15, 0.18, float(MCK.STYLE_CLADDING) / 8.0))
		for e2 in [[Vector3(MALL_PORTAL.x, MALL_PORTAL_Y.x, z1 + 0.1), Vector3(MALL_PORTAL.x, MALL_PORTAL_Y.y, z1 + 0.1)],
				[Vector3(MALL_PORTAL.x, MALL_PORTAL_Y.y, z1 + 0.1), Vector3(MALL_PORTAL.y, MALL_PORTAL_Y.y, z1 + 0.1)],
				[Vector3(MALL_PORTAL.y, MALL_PORTAL_Y.y, z1 + 0.1), Vector3(MALL_PORTAL.y, MALL_PORTAL_Y.x, z1 + 0.1)]]:
			MCK.led_line(pk, kit, e2[0], e2[1], Color(0.3, 0.85, 1.0, 0.0), 0.5)
		# The mall's name on its north and south fronts, a crown of LED round its roof's edge.
		MCK.neon_sign(pk, kit, labels, Vector3(m.get_center().x - 60.0, 48.0, m.position.y - 0.6), Vector3(0, 0, -1), 46.0, 12.0, "星河汇", Color(1.0, 0.35, 0.8))
		MCK.neon_sign(pk, kit, labels, Vector3(m.get_center().x + 50.0, 48.0, m.end.y + 0.6), Vector3(0, 0, 1), 46.0, 12.0, "星河汇", Color(1.0, 0.35, 0.8))
		MCK.neon_sign(pk, kit, labels, Vector3(m.end.x + 0.6, 40.0, m.get_center().y), Vector3(1, 0, 0), 30.0, 9.0, "海洋馆", Color(0.3, 0.8, 1.0))
	, 3800.0)
	# The roof, all but the hall's footprint (whose vault stands over it), open where the cars come in off the jump.
	var roof_n := Rect2(m.position.x, m.position.y, m.size.x, HALL.position.y - m.position.y)
	_roof(roof_n, Y_MALL, [[0, 300.0 - m.position.x - road_half - 1.0, 300.0 - m.position.x + road_half + 1.0], [2, 0.0, m.size.x]])
	_city("mall", func(pk: PropKit, kit: Dictionary, _l: Array) -> void:
		var south := PackedVector2Array([Vector2(m.position.x, HALL.end.y), Vector2(m.end.x, HALL.end.y), m.end, Vector2(m.position.x, m.end.y)])
		MCK.flat(pk, kit, south, Y_MALL - 0.06, Vector3.UP, Color(0.3, 0.3, 0.33), MCK.STYLE_CONCRETE)
		for side in [[m.position.x, HALL.position.x], [HALL.end.x, m.end.x]]:
			var strip := PackedVector2Array([Vector2(side[0], HALL.position.y), Vector2(side[1], HALL.position.y), Vector2(side[1], HALL.end.y),
				Vector2(side[0], HALL.end.y)])
			MCK.flat(pk, kit, strip, Y_MALL - 0.06, Vector3.UP, Color(0.3, 0.3, 0.33), MCK.STYLE_CONCRETE)
	, 3800.0)


# ---- Air taxis over the course ---------------------------------------------------------------------------------------

## Loops the air taxis fly (AirTaxis.gd, the user's idea): over the start straight 20m over the Yunlang's roof, round the
## spiral tower above its top, over the mall's roof between the library and the ring tunnel and back over the hall's
## vault, and round the park at the finish. Each clear of everything by `res://scratch/flight_path_clearance.gd`.
const TAXI_ROUTES: Array = [
	{"points": [Vector3(95, 170, -62), Vector3(300, 170, -76), Vector3(380, 172, 0), Vector3(300, 170, 76), Vector3(95, 170, 62), Vector3(70, 170, 0)],
		"speed": 26.0, "count": 2},
	{"points": [Vector3(390, 148, 252), Vector3(468, 148, 300), Vector3(468, 150, 370), Vector3(390, 150, 408), Vector3(318, 148, 360),
		Vector3(318, 148, 292)], "speed": 22.0, "count": 1},
	{"points": [Vector3(350, 98, 545), Vector3(440, 98, 560), Vector3(458, 104, 620), Vector3(410, 112, 668), Vector3(320, 114, 684),
		Vector3(290, 108, 630), Vector3(312, 100, 582)], "speed": 20.0, "count": 2},
	{"points": [Vector3(735, 46, 990), Vector3(900, 50, 1015), Vector3(950, 52, 1180), Vector3(840, 52, 1300), Vector3(690, 50, 1230),
		Vector3(655, 48, 1070)], "speed": 22.0, "count": 2},
]


# ---- The Xinghe Library on the mall's roof ----------------------------------------------------------------------------

## Where the car park was (the user wanted a futuristic structure of the mall's complex there): the Xinghe Library
## (星河图书馆), a twisting stack of elliptical glass floors on the roof's west part, white fins round it, a lit book core,
## terraces with readers, a glass dome with a roof garden; on the east part a white lattice shell over a sky garden; and
## a tunnel of LED rings over the lap where it runs east across the roof.
const LIB_C := Vector2(228.0, 572.0)
const LIB_R := Vector2(52.0, 28.0)
const LIB_FLOOR := 4.6
const LIB_TIERS := 5


func _ellipse(c: Vector2, r: Vector2, rot: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in range(n):
		var a: float = TAU * float(k) / float(n)
		var p := Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot)
		out.append(c + p)
	return out


## A blade swept along `pts` (a smooth curve): `w` across along each point's `outs` (horizontal), `t` thick, its four
## faces continuous from end to end with smooth normals, capped at both ends.
func _blade(pk: PropKit, kit: Dictionary, key: String, pts: Array, outs: Array, w: float, t: float, col: Color) -> void:
	var n: int = pts.size()
	var rings: Array = []
	var frames: Array = []
	for i in range(n):
		var tg: Vector3 = ((pts[mini(i + 1, n - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)).normalized()
		var r: Vector3 = outs[i]
		r = (r - tg * r.dot(tg)).normalized()
		var sd: Vector3 = tg.cross(r).normalized()
		var c: Vector3 = pts[i]
		rings.append([c + r * w * 0.5 + sd * t * 0.5, c + r * w * 0.5 - sd * t * 0.5, c - r * w * 0.5 - sd * t * 0.5, c - r * w * 0.5 + sd * t * 0.5])
		frames.append([r, -sd, -r, sd])
	# Face f runs from corner f to corner f+1; its normal is the frame's direction between them.
	var face_dirs: Array = [[0, 1, 0], [1, 2, 1], [2, 3, 2], [3, 0, 3]]
	for i in range(n - 1):
		for fd in face_dirs:
			var ca: int = fd[0]
			var cb: int = fd[1]
			var na: Vector3 = (frames[i] as Array)[fd[2]]
			var nb: Vector3 = (frames[i + 1] as Array)[fd[2]]
			var a0: Vector3 = (rings[i] as Array)[ca]
			var a1: Vector3 = (rings[i] as Array)[cb]
			var b0: Vector3 = (rings[i + 1] as Array)[ca]
			var b1: Vector3 = (rings[i + 1] as Array)[cb]
			var out: Vector3 = (na + nb).normalized()
			pk.tri(kit, key, a0, a1, b1, na, na, nb, col, out)
			pk.tri(kit, key, a0, b1, b0, na, nb, nb, col, out)
	for e in [[0, -1.0], [n - 1, 1.0]]:
		var rg: Array = rings[int(e[0])]
		var i2: int = int(e[0])
		var tg2: Vector3 = ((pts[mini(i2 + 1, n - 1)] as Vector3) - (pts[maxi(i2 - 1, 0)] as Vector3)).normalized() * float(e[1])
		pk.quad(kit, key, rg, tg2, col)


## Boxes for the runtime's colliders, gathered while a batch is built: [transform, size].
var _roof_solids: Array = []


## A box along a to b, `w` square (or `w` across `side` when given), into `_roof_solids`.
func _beam_solid(a: Vector3, b: Vector3, w: float, side := Vector3.ZERO) -> void:
	var d: Vector3 = b - a
	var ln: float = d.length()
	if ln < 0.05:
		return
	var z: Vector3 = d / ln
	var x: Vector3 = side if side.length_squared() > 1e-6 else Vector3.UP.cross(z)
	if x.length_squared() < 1e-6:
		x = Vector3.RIGHT
	x = (x - z * x.dot(z)).normalized()
	var y: Vector3 = z.cross(x).normalized()
	_roof_solids.append([Transform3D(Basis(x, y, z), (a + b) * 0.5), Vector3(w, minf(w, 0.6) if side.length_squared() > 1e-6 else w, ln + 0.2)])


## A square planter of polished stone `size` across at p (on its floor), soil on top, an LED line round its rim.
func _planter(pk: PropKit, kit: Dictionary, p: Vector3, size: float, led: Color) -> void:
	var h := 0.9
	pk.block(kit, "tower", p + Vector3(-size, 0, -size), p + Vector3(size, h, size), Color(0.62, 0.62, 0.66, float(MCK.STYLE_CONCRETE) / 8.0))
	pk.block(kit, "matte", p + Vector3(-size + 0.15, h, -size + 0.15), p + Vector3(size - 0.15, h + 0.04, size - 0.15), Color(0.16, 0.11, 0.07))
	var r: float = size + 0.03
	var y: float = h - 0.12
	for e in [[Vector3(-r, y, -r), Vector3(r, y, -r)], [Vector3(r, y, -r), Vector3(r, y, r)], [Vector3(r, y, r), Vector3(-r, y, r)], [Vector3(-r, y, r), Vector3(-r, y, -r)]]:
		MCK.led_line(pk, kit, p + (e[0] as Vector3), p + (e[1] as Vector3), led, 0.08)


func _build_library() -> void:
	var id := _id()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7171
	_reserved.append(Rect2(LIB_C - LIB_R - Vector2(4, 4), LIB_R * 2.0 + Vector2(8, 8)))
	_city("library", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		var y0: float = Y_MALL - 0.2
		var white := Color(0.92, 0.93, 0.95)
		for t in range(LIB_TIERS):
			var f: float = float(t) / float(LIB_TIERS - 1)
			var rot: float = 0.09 * float(t)
			var r: Vector2 = LIB_R * (1.0 - 0.1 * f)
			var yb: float = y0 + LIB_FLOOR * float(t)
			# The floor's glass wall, set in from its slab, lit like an office; the slab's white edge with an LED line.
			var wall_plan := _ellipse(LIB_C, r * 0.9, rot, 40)
			MCK.prism(pk, kit, wall_plan, yb + 0.5, yb + LIB_FLOOR, Color(0.55, 0.62, 0.66), MCK.STYLE_OFFICE, id + t, false)
			var slab := _ellipse(LIB_C, r, rot, 40)
			MCK.prism(pk, kit, slab, yb, yb + 0.5, white, MCK.STYLE_CONCRETE, id, true)
			for k in range(40):
				var a: Vector2 = slab[k]
				var b: Vector2 = slab[(k + 1) % 40]
				MCK.led_line(pk, kit, Vector3(a.x, yb + 0.25, a.y), Vector3(b.x, yb + 0.25, b.y), Color(0.55, 0.85, 1.0, 0.0), 0.12)
				# A glass balustrade round each terrace (the wall stands back from the slab's edge).
				if k % 2 == 0:
					MCK.glass_rail(pk, kit, Vector3(a.x, yb + 0.5, a.y), Vector3(b.x, yb + 0.5, b.y), 1.1, Color(0.55, 0.85, 1.0, 0.0))
		# White fins round the stack: tall curved blades leaning with its twist, each one continuous blade swept along
		# its curve (two straight beams had met at a kink with their ends apart), standing just outside the slabs and tied
		# to each slab's edge; every other one lit along its outer edge.
		var top_h: float = y0 + LIB_FLOOR * float(LIB_TIERS) + 3.0
		for k2 in range(28):
			var a2: float = TAU * float(k2) / 28.0
			var pts: Array = []
			var outs: Array = []
			var n_s := 14
			for j in range(n_s + 1):
				var t: float = float(j) / float(n_s)
				var an: float = a2 + 0.36 * t
				var rf: float = 1.06 + 0.05 * sin(PI * t) - 0.04 * t
				var q := LIB_C + Vector2(cos(an) * LIB_R.x * rf, sin(an) * LIB_R.y * rf)
				pts.append(Vector3(q.x, lerpf(y0, top_h, t), q.y))
				# Outward: the ellipse's normal there.
				var nrm := Vector2(cos(an) / LIB_R.x, sin(an) / LIB_R.y).normalized()
				outs.append(Vector3(nrm.x, 0, nrm.y))
			_blade(pk, kit, "gloss", pts, outs, 1.2, 0.35, white)
			for j3 in range(0, n_s, 2):
				_beam_solid(pts[j3], pts[j3 + 2], 1.2, outs[j3 + 1])
			if k2 % 2 == 0:
				for j2 in range(n_s):
					MCK.led_line(pk, kit, (pts[j2] as Vector3) + (outs[j2] as Vector3) * 0.62, (pts[j2 + 1] as Vector3) + (outs[j2 + 1] as Vector3) * 0.62,
							Color(1.0, 0.45, 0.85, 0.5), 0.12)
			# Ties from each slab's edge to the blade.
			for t3 in range(1, LIB_TIERS):
				var yt: float = y0 + LIB_FLOOR * float(t3) + 0.25
				var tf: float = (yt - y0) / (top_h - y0)
				var jf: int = clampi(int(round(tf * float(n_s))), 0, n_s)
				var fp: Vector3 = pts[jf]
				fp.y = yt
				var rot3: float = 0.09 * float(t3)
				var r3: Vector2 = LIB_R * (1.0 - 0.1 * float(t3) / float(LIB_TIERS - 1))
				var pa: float = atan2((fp.z - LIB_C.y) / LIB_R.y, (fp.x - LIB_C.x) / LIB_R.x) - rot3
				var sp := LIB_C + Vector2(cos(pa) * r3.x * 0.98, sin(pa) * r3.y * 0.98).rotated(rot3)
				pk.beam(kit, "gloss", Vector3(sp.x, yt, sp.y), fp - (outs[jf] as Vector3) * 0.3, 0.22, 0.22, white)
		# The book core: a drum of lit shelves through the middle, seen through the glass.
		var core := _ellipse(LIB_C, LIB_R * 0.38, 0.0, 24)
		MCK.prism(pk, kit, core, y0, y0 + LIB_FLOOR * float(LIB_TIERS), Color(0.95, 0.85, 0.7), MCK.STYLE_INTERIOR, id + 9, false)
		# The roof: a garden ring round a glass dome with ribs and an LED crown.
		var ry: float = y0 + LIB_FLOOR * float(LIB_TIERS)
		var roof := _ellipse(LIB_C, LIB_R * 0.9 * 0.9, 0.36, 40)
		MCK.flat(pk, kit, roof, ry + 0.02, Vector3.UP, Color(0.18, 0.28, 0.16), MCK.STYLE_CONCRETE)
		var dome_c := Vector3(LIB_C.x, ry, LIB_C.y)
		var prof: Array = []
		for k3 in range(9):
			var an: float = PI * 0.5 * float(k3) / 8.0
			prof.append(Vector2(maxf(cos(an) * 14.0, 0.001), sin(an) * 9.0))
		pk.lathe(kit, "glass", dome_c, prof, 24, Color(1, 1, 1), true)
		for k4 in range(12):
			var an2: float = TAU * float(k4) / 12.0
			var prev := Vector3.ZERO
			for k5 in range(9):
				var q: Vector2 = prof[k5]
				var pp: Vector3 = dome_c + Vector3(cos(an2) * q.x, q.y + 0.05, sin(an2) * q.x)
				if k5 > 0:
					MCK.led_line(pk, kit, prev, pp, Color(0.95, 0.9, 0.75, 0.0), 0.12)
				prev = pp
		# Trees in planters round the dome (they had been dark green lumps).
		for k6 in range(10):
			var an3: float = TAU * (float(k6) + 0.5) / 10.0
			var tp := Vector3(LIB_C.x + cos(an3) * LIB_R.x * 0.6, ry, LIB_C.y + sin(an3) * LIB_R.y * 0.6)
			_planter(pk, kit, tp, 1.6, Color(0.55, 0.85, 1.0, 0.0))
			extra_trees.append([["sakura", "momiji", "matsu"][k6 % 3], tp.x, tp.z, rng.randf_range(0.38, 0.46), k6 % 2, ry + 0.9])
		# Its name on the stack's north face, toward the jump's landing.
		MCK.neon_sign(pk, kit, labels, Vector3(LIB_C.x, ry + 2.2, LIB_C.y - LIB_R.y * 0.85), Vector3(0, 0, -1), 20.0, 3.4, "星河图书馆", Color(0.55, 0.85, 1.0))
		# The sky garden's lattice shell east of the lap (x 312-425, z 537-562): arches of white tubes, lit at the joints.
		var gx0 := 316.0
		var gx1 := 420.0
		var gz := 549.0
		var arch_n := 14
		for k7 in range(arch_n):
			var x: float = lerpf(gx0, gx1, float(k7) / float(arch_n - 1))
			var hgt: float = 9.0 + 4.0 * sin(float(k7) / float(arch_n - 1) * PI)
			var prev2 := Vector3.ZERO
			for k8 in range(11):
				var an4: float = PI * float(k8) / 10.0
				var lean: float = 3.0 * sin(float(k7) * 0.7)
				var pp2 := Vector3(x + lean * sin(an4), Y_MALL + sin(an4) * hgt, gz - cos(an4) * 11.0)
				if k8 > 0:
					pk.beam(kit, "gloss", prev2, pp2, 0.3, 0.3, white)
					_beam_solid(prev2, pp2, 0.4)
				if k8 % 2 == 0:
					pk.block(kit, "neon", pp2 - Vector3(0.18, 0.18, 0.18), pp2 + Vector3(0.18, 0.18, 0.18), Color(0.7, 0.9, 1.0))
				prev2 = pp2
		# The sky garden under the shell: trees in planters down its middle (they had been dark green lumps on sticks).
		for k9 in range(7):
			var tp2 := Vector3(lerpf(gx0 + 8.0, gx1 - 8.0, float(k9) / 6.0) + rng.randf_range(-3.0, 3.0), Y_MALL - 0.06, gz + (2.5 if k9 % 2 == 0 else -2.5))
			_planter(pk, kit, tp2, 2.0, Color(0.7, 0.9, 1.0, 0.0))
			extra_trees.append([["sakura", "shidare", "momiji", "sakura"][k9 % 4], tp2.x, tp2.z, rng.randf_range(0.45, 0.55), k9 % 2, tp2.y + 0.9])
			_roof_solids.append([Transform3D(Basis(), tp2 + Vector3(0, 0.45, 0)), Vector3(4.0, 0.9, 4.0)])
		# A tunnel of LED rings over the lap where it runs east across the roof: steel arches standing on plinths on the
		# roof either side of the road (they had started 2m up in the air), the LED on their inner faces.
		var s_r0: float = _s_after(Vector2(330.0, 575.0), float(_a["land2"]))
		var foot_y: float = Y_MALL - 0.1
		for k10 in range(5):
			var sr: float = s_r0 + 14.0 * float(k10)
			var lp: Vector3 = lap.pt(sr)
			var c := Vector3(lp.x, foot_y + 0.6, lp.z)
			var rt: Vector3 = lap.rt(sr)
			rt = Vector3(rt.x, 0, rt.z).normalized()
			var led_c := Color.from_hsv(0.55 + 0.08 * float(k10), 0.7, 1.0, 0.6)
			var prev3 := Vector3.ZERO
			var prev_o := Vector3.ZERO
			for k11 in range(25):
				var an5: float = PI * float(k11) / 24.0
				var pp3: Vector3 = c + rt * cos(an5) * 11.5 + Vector3(0, sin(an5) * 11.0, 0)
				# Outward from the arch's middle (the ellipse's normal), for the steel behind the LED.
				var o5 := (rt * cos(an5) / 11.5 + Vector3(0, sin(an5) / 11.0, 0)).normalized()
				if k11 > 0:
					pk.beam(kit, "steel", prev3 + prev_o * 0.32, pp3 + o5 * 0.32, 0.5, 0.42, Color(0.32, 0.34, 0.4), rt.cross(Vector3.UP))
					_beam_solid(prev3 + prev_o * 0.2, pp3 + o5 * 0.2, 0.7)
					MCK.led_line(pk, kit, prev3, pp3, led_c, 0.45)
				prev3 = pp3
				prev_o = o5
			for sd in [-1.0, 1.0]:
				var fp: Vector3 = Vector3(lp.x, foot_y, lp.z) + rt * sd * 11.5
				pk.block(kit, "tower", fp - Vector3(0.9, 0.0, 0.9), fp + Vector3(0.9, 0.7, 0.9), Color(0.22, 0.23, 0.27, float(MCK.STYLE_CLADDING) / 8.0))
				_roof_solids.append([Transform3D(Basis(), fp + Vector3(0, 0.35, 0)), Vector3(1.8, 0.7, 1.8)])
				MCK.led_line(pk, kit, fp + Vector3(-0.92, 0.6, -0.92), fp + Vector3(0.92, 0.6, -0.92), led_c, 0.1)
				MCK.led_line(pk, kit, fp + Vector3(-0.92, 0.6, 0.92), fp + Vector3(0.92, 0.6, 0.92), led_c, 0.1)
	, 3000.0)
	# Solid: the fins, the rings and their plinths, the shell's arches and planters (the library's mesh holds glass, so
	# DressingColliders leaves the whole batch soft).
	var rbody := _body(level, "RoofStructuresBody")
	for sd2 in _roof_solids:
		_box_shape(rbody, sd2[0], sd2[1])
	print("  roof structures: %d boxes" % _roof_solids.size())
	_roof_solids.clear()
	# Solid: the stack as slices of boxes (its mesh holds glass, so DressingColliders leaves it soft).
	var body := _body(level, "LibraryBody")
	for k13 in range(-5, 6):
		var x0: float = float(k13) / 5.5
		var depth: float = 2.0 * LIB_R.y * sqrt(maxf(1.0 - x0 * x0, 0.0))
		if depth < 2.0:
			continue
		_box_shape(body, Transform3D(Basis(), Vector3(LIB_C.x + x0 * LIB_R.x, Y_MALL + LIB_FLOOR * float(LIB_TIERS) * 0.5, LIB_C.y)),
				Vector3(LIB_R.x * 2.0 / 11.0, LIB_FLOOR * float(LIB_TIERS), depth))
	# Readers on the terraces.
	for t2 in range(1, LIB_TIERS):
		var yb2: float = Y_MALL - 0.2 + LIB_FLOOR * float(t2) + 0.5
		var r2: Vector2 = LIB_R * (1.0 - 0.1 * float(t2) / float(LIB_TIERS - 1)) * 0.95
		for k12 in range(10):
			if rng.randf() < 0.4:
				continue
			var an6: float = rng.randf() * TAU
			var pp4 := Vector2(cos(an6) * r2.x, sin(an6) * r2.y).rotated(0.09 * float(t2)) + LIB_C
			_person(Vector3(pp4.x, yb2, pp4.y), Vector3(pp4.x - LIB_C.x, 0, pp4.y - LIB_C.y).normalized(), rng.randf_range(0.92, 1.06))


func _build_hall() -> void:
	var id := _id()
	var hr: Rect2 = HALL
	var s_in: float = _s_after(Vector2(412.0, hr.position.y), float(_a["land2"]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5501
	var entry_x: float = lap.pt(s_in).x
	_city("hall", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		# The hall's walls inside: six floors of shops (the interior style), facing in; outside, the vault's ends glazed.
		# The north wall has an opening where the lap comes in off the roof, the south wall the aquarium's entrance.
		var x0: float = hr.position.x
		var x1: float = hr.end.x
		var z0: float = hr.position.y
		var z1: float = hr.end.y
		var eave: float = Y_MALL + HALL_EAVE
		var entry := [entry_x - road_half - 2.4, entry_x + road_half + 2.4, Y_MALL - 4.0, Y_MALL + HALL_ENTRY_H]
		var aqua_door := [MALL_PORTAL.x, MALL_PORTAL.y, MALL_PORTAL_Y.x, MALL_PORTAL_Y.y]
		_x_wall(pk, kit, z0, x1, x0, HALL_FLOOR, eave, 1.0, Color(0.92, 0.88, 0.8), MCK.STYLE_INTERIOR, id, entry)
		_x_wall(pk, kit, z1, x0, x1, HALL_FLOOR, eave, -1.0, Color(0.92, 0.88, 0.8), MCK.STYLE_INTERIOR, id + 1, aqua_door)
		# Outside, the walls' tops stand `HALL_EAVE` over the mall's roof round the vault: clad, an LED line along them (from
		# the roof they had shown only their backs, which aren't drawn, and the hall stood open).
		var y_out0: float = Y_MALL - 0.3
		var y_out1: float = eave
		_x_wall(pk, kit, z0 - 0.05, x0, x1, y_out0, y_out1, -1.0, Color(0.2, 0.21, 0.25), MCK.STYLE_CLADDING, id + 6, entry)
		_x_wall(pk, kit, z1 + 0.05, x1, x0, y_out0, y_out1, 1.0, Color(0.2, 0.21, 0.25), MCK.STYLE_CLADDING, id + 6, [])
		MCK.wall(pk, kit, Vector3(x0 - 0.05, 0, z1), Vector3(x0 - 0.05, 0, z0), y_out0, y_out1, Vector3(-1, 0, 0), Color(0.2, 0.21, 0.25), MCK.STYLE_CLADDING, id + 6)
		MCK.wall(pk, kit, Vector3(x1 + 0.05, 0, z0), Vector3(x1 + 0.05, 0, z1), y_out0, y_out1, Vector3(1, 0, 0), Color(0.2, 0.21, 0.25), MCK.STYLE_CLADDING, id + 6)
		for e in [[Vector3(x0, y_out1 + 0.05, z0 - 0.1), Vector3(x1, y_out1 + 0.05, z0 - 0.1)],
				[Vector3(x0, y_out1 + 0.05, z1 + 0.1), Vector3(x1, y_out1 + 0.05, z1 + 0.1)], [Vector3(x0 - 0.1, y_out1 + 0.05, z0), Vector3(x0 - 0.1, y_out1 + 0.05, z1)],
				[Vector3(x1 + 0.1, y_out1 + 0.05, z0), Vector3(x1 + 0.1, y_out1 + 0.05, z1)]]:
			MCK.led_line(pk, kit, e[0], e[1], Color(1.0, 0.4, 0.85, 0.5), 0.3)
		# The aquarium's entrance: a lit frame round the door, dark reveals through the wall to the tank, its name over it.
		var d0: float = MALL_PORTAL.x
		var d1: float = MALL_PORTAL.y
		var dy0: float = MALL_PORTAL_Y.x
		var dy1: float = MALL_PORTAL_Y.y
		for gx in [d0, d1]:
			var o3: float = 1.0 if gx == d0 else -1.0
			MCK.wall(pk, kit, Vector3(gx, 0, z1 + 2.0 if o3 > 0.0 else z1 - 0.05), Vector3(gx, 0, z1 - 0.05 if o3 > 0.0 else z1 + 2.0), dy0, dy1, Vector3(o3, 0, 0),
					Color(0.08, 0.1, 0.14), MCK.STYLE_CLADDING, id + 7)
		pk.quad(kit, "tower", [Vector3(d0, dy1, z1 - 0.05), Vector3(d1, dy1, z1 - 0.05), Vector3(d1, dy1, z1 + 2.0), Vector3(d0, dy1, z1 + 2.0)], Vector3.DOWN,
				Color(0.08, 0.1, 0.14, float(MCK.STYLE_CLADDING) / 8.0))
		var fz: float = z1 - 0.15
		for e2 in [[Vector3(d0, dy0, fz), Vector3(d0, dy1, fz)], [Vector3(d0, dy1, fz), Vector3(d1, dy1, fz)], [Vector3(d1, dy1, fz), Vector3(d1, dy0, fz)]]:
			MCK.led_line(pk, kit, e2[0], e2[1], Color(0.25, 0.75, 1.0, 0.0), 0.7)
		MCK.neon_sign(pk, kit, labels, Vector3((d0 + d1) * 0.5, dy1 + 3.2, z1 - 0.4), Vector3(0, 0, -1), 22.0, 4.0, "星河海洋馆", Color(0.3, 0.85, 1.0))
		MCK.wall(pk, kit, Vector3(x0, 0, z0), Vector3(x0, 0, z1), HALL_FLOOR, eave, Vector3(1, 0, 0), Color(0.92, 0.88, 0.8), MCK.STYLE_INTERIOR, id + 2)
		MCK.wall(pk, kit, Vector3(x1, 0, z1), Vector3(x1, 0, z0), HALL_FLOOR, eave, Vector3(-1, 0, 0), Color(0.92, 0.88, 0.8), MCK.STYLE_INTERIOR, id + 3)
		# The floor: polished stone, a fountain pool in its middle.
		MCK.flat(pk, kit, PackedVector2Array([Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)]), HALL_FLOOR, Vector3.UP,
				Color(0.7, 0.66, 0.6), MCK.STYLE_CONCRETE)
		pk.block(kit, "neon", Vector3(260.0, HALL_FLOOR, 640.0), Vector3(330.0, HALL_FLOOR + 0.4, 650.0), Color(0.15, 0.5, 0.9))
		# Balcony slabs along the walls at every floor (the shops' walkways), glass fronts, LED under them.
		var fy: float = HALL_FLOOR + 8.0
		while fy < Y_MALL:
			for zz in [[z0, z0 + 5.0, 1.0], [z1 - 5.0, z1, -1.0]]:
				var edge: float = zz[1] if zz[2] > 0.0 else zz[0]
				# The south walkways stop short of the aquarium's door below the floor the lap's last ramp passes (they hung
				# 3.5m over the road there), their ends railed.
				var runs: Array = [[x0, x1]]
				if zz[2] < 0.0 and fy < MALL_PORTAL_Y.y + 12.0:
					runs = [[x0, MALL_PORTAL.x - 14.0], [MALL_PORTAL.y + 14.0, x1]]
				for run in runs:
					var ra: float = run[0]
					var rb: float = run[1]
					pk.block(kit, "tower", Vector3(ra, fy - 0.5, zz[0]), Vector3(rb, fy, zz[1]), Color(0.85, 0.82, 0.76, 5.0 / 8.0))
					MCK.glass_rail(pk, kit, Vector3(ra, fy, edge), Vector3(rb, fy, edge), 1.1, Color(1.0, 0.85, 0.6, 0.0))
					MCK.led_line(pk, kit, Vector3(ra, fy - 0.55, edge), Vector3(rb, fy - 0.55, edge), Color(1.0, 0.9, 0.75, 0.0), 0.12)
					if runs.size() > 1:
						var cap_x: float = rb if ra == x0 else ra
						MCK.glass_rail(pk, kit, Vector3(cap_x, fy, zz[0]), Vector3(cap_x, fy, zz[1]), 1.1, Color(1.0, 0.85, 0.6, 0.0))
			fy += 8.0
		# The glass vault over the hall: ribs and glazing, LED along the ribs.
		var cz: float = (z0 + z1) * 0.5
		var hw: float = (z1 - z0) * 0.5
		var rise: float = HALL_TOP - eave
		var arc: Array = []
		for k in range(13):
			var t: float = PI * float(k) / 12.0
			arc.append(Vector2(cz - cos(t) * hw, eave + sin(t) * rise))
		var rx: float = x0
		while rx <= x1 + 0.01:
			for k2 in range(12):
				var a: Vector2 = arc[k2]
				var b: Vector2 = arc[k2 + 1]
				MCK.led_line(pk, kit, Vector3(rx, a.y, a.x), Vector3(rx, b.y, b.x), Color(0.85, 0.75, 1.0, 0.0), 0.35)
			rx += 16.0
		for k3 in range(12):
			var a3: Vector2 = arc[k3]
			var b3: Vector2 = arc[k3 + 1]
			var n := Vector3(0, b3.x - a3.x, -(b3.y - a3.y)).normalized()
			if n.y < 0.0:
				n = -n
			pk.quad(kit, "glass", [Vector3(x0, a3.y, a3.x), Vector3(x1, a3.y, a3.x), Vector3(x1, b3.y, b3.x), Vector3(x0, b3.y, b3.x)], n, Color(1, 1, 1))
		for gx in [x0, x1]:
			var tri := PackedVector2Array()
			for p in arc:
				tri.append(p)
			for k4 in range(12):
				var a4: Vector2 = arc[k4]
				var b4: Vector2 = arc[k4 + 1]
				pk.tri(kit, "glass", Vector3(gx, eave, cz), Vector3(gx, a4.y, a4.x), Vector3(gx, b4.y, b4.x), Vector3(1, 0, 0), Vector3(1, 0, 0),
						Vector3(1, 0, 0), Color(1, 1, 1), Vector3(1 if gx > x0 else -1, 0, 0))
		# Giant LED screens at the hall's ends, lanterns strung across it, hanging over the ramps.
		MCK.wall(pk, kit, Vector3(x0 + 0.3, 0, z0 + 18.0), Vector3(x0 + 0.3, 0, z1 - 18.0), 34.0, 66.0, Vector3(1, 0, 0), Color(0.1, 0.1, 0.14), MCK.STYLE_MEDIA, id + 4)
		MCK.wall(pk, kit, Vector3(x1 - 0.3, 0, z1 - 18.0), Vector3(x1 - 0.3, 0, z0 + 18.0), 30.0, 62.0, Vector3(-1, 0, 0), Color(0.1, 0.1, 0.14), MCK.STYLE_MEDIA, id + 5)
		var lx: float = x0 + 12.0
		while lx < x1 - 8.0:
			for lz in [z0 + 10.0, cz, z1 - 10.0]:
				MCK.lantern(pk, kit, Vector3(lx + rng.randf_range(-3.0, 3.0), Y_MALL + 14.0 + rng.randf_range(-3.0, 6.0), lz + rng.randf_range(-4.0, 4.0)), 2.2)
			lx += 14.0
		# Shop signs on the balcony fronts.
		var names: Array = ["火锅", "奶茶", "小面", "珠宝", "数码", "书店", "咖啡", "烤鸭", "饺子", "蛋糕", "眼镜", "服装", "鞋", "电影院", "美食", "超市"]
		var ni := 0
		var sy: float = HALL_FLOOR + 8.0 + 3.0
		while sy < Y_MALL:
			var sx: float = x0 + 16.0
			while sx < x1 - 16.0:
				for side in [[z0 + 0.4, 1.0], [z1 - 0.4, -1.0]]:
					var near_door: bool = float(side[1]) < 0.0 and sy < MALL_PORTAL_Y.y + 12.0 and sx > MALL_PORTAL.x - 18.0 and sx < MALL_PORTAL.y + 18.0
					if rng.randf() < 0.55 and not near_door:
						var col := Color.from_hsv(rng.randf(), 0.75, 1.0)
						MCK.neon_sign(pk, kit, labels, Vector3(sx, sy, float(side[0])), Vector3(0, 0, float(side[1])), 7.0, 2.2, String(names[ni % names.size()]), col)
						ni += 1
				sx += 22.0
			sy += 8.0
	, 2600.0)
	# The ramps: decks with glass sides on columns to the hall's floor; the leg into the hall from the roof.
	var a: Dictionary = _a
	_deck("hall_decks", s_in - 2.0, float(a["aqua0"]) - 2.0, 1.6, Color(1.0, 0.7, 0.35, 0.0), 30.0, [true, true], HALL_FLOOR)
	# A portal in the hall's north wall where the cars come in off the roof.
	var p: Vector3 = lap.pt(s_in)
	_city("hall", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		for side in [-1.0, 1.0]:
			pk.block(kit, "tower", Vector3(p.x + side * (road_half + 1.6) - 0.8, Y_MALL - 0.1, hr.position.y - 1.0),
					Vector3(p.x + side * (road_half + 1.6) + 0.8, Y_MALL + HALL_ENTRY_H, hr.position.y + 1.0), Color(0.25, 0.25, 0.3, 6.0 / 8.0))
		pk.block(kit, "tower", Vector3(p.x - road_half - 2.4, Y_MALL + HALL_ENTRY_H, hr.position.y - 1.0), Vector3(p.x + road_half + 2.4, Y_MALL + HALL_EAVE, hr.position.y + 1.0),
				Color(0.25, 0.25, 0.3, 6.0 / 8.0))
		# The name stands on the lintel, in front of the vault's foot.
		MCK.neon_sign(pk, kit, labels, Vector3(p.x, Y_MALL + HALL_EAVE + 2.55, hr.position.y - 1.2), Vector3(0, 0, -1), 18.0, 4.5, "星河汇 入口", Color(1.0, 0.4, 0.85))
	, 2600.0)


## A wall along x at z from xa to xb (keeping the order MCK.wall draws it in), facing `out_z` (+1 south, -1 north), with an
## opening `hole` = [x from, x to, y from, y to] cut out of it (empty: none).
func _x_wall(pk: PropKit, kit: Dictionary, z: float, xa: float, xb: float, y0: float, y1: float, out_z: float, tint: Color, style: int, id: int,
		hole: Array) -> void:
	var out := Vector3(0, 0, out_z)
	if hole.is_empty():
		MCK.wall(pk, kit, Vector3(xa, 0, z), Vector3(xb, 0, z), y0, y1, out, tint, style, id)
		return
	var lo: float = minf(xa, xb)
	var hi: float = maxf(xa, xb)
	var g0: float = clampf(float(hole[0]), lo, hi)
	var g1: float = clampf(float(hole[1]), lo, hi)
	var h0: float = clampf(float(hole[2]), y0, y1)
	var h1: float = clampf(float(hole[3]), y0, y1)
	# Pieces as [x from, x to, y from, y to], each drawn in the wall's own direction.
	var pieces: Array = [[lo, g0, y0, y1], [g1, hi, y0, y1], [g0, g1, y0, h0], [g0, g1, h1, y1]]
	for pc in pieces:
		if float(pc[1]) - float(pc[0]) < 0.05 or float(pc[3]) - float(pc[2]) < 0.05:
			continue
		var pa: float = pc[0] if xa < xb else pc[1]
		var pb: float = pc[1] if xa < xb else pc[0]
		MCK.wall(pk, kit, Vector3(pa, 0, z), Vector3(pb, 0, z), pc[2], pc[3], out, tint, style, id, absf(pa - xa))


# ---- The aquarium: the acrylic tunnel through the tanks -------------------------------------------------------------

func _build_aquarium(root: Node3D) -> void:
	var a: Dictionary = _a
	var s0: float = float(a["aqua0"])
	var s1: float = float(a["aqua1"])
	var r: Rect2 = AQUA
	var rng := RandomNumberGenerator.new()
	rng.seed = 6601
	var tank := ShaderMaterial.new()
	tank.shader = load("res://aquarium_tank.gdshader")
	tank.set_shader_parameter("surface_y", AQUA_SURFACE)
	_city("aquarium", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		# The tanks: a box round the tunnel, its faces turned inward (seen from inside), sand floor, rock walls.
		var y0: float = AQUA_FLOOR
		var y1: float = AQUA_SURFACE + 2.0
		var c0 := Vector3(r.position.x, y0, r.position.y)
		var c1 := Vector3(r.end.x, y1, r.end.y)
		pk.quad(kit, "tank", [Vector3(c0.x, y0, c0.z), Vector3(c1.x, y0, c0.z), Vector3(c1.x, y0, c1.z), Vector3(c0.x, y0, c1.z)], Vector3.UP, Color(0.75, 0.68, 0.52))
		pk.quad(kit, "tank", [Vector3(c0.x, y1, c0.z), Vector3(c1.x, y1, c0.z), Vector3(c1.x, y1, c1.z), Vector3(c0.x, y1, c1.z)], Vector3.DOWN, Color(0.5, 0.8, 0.9))
		for e in [[Vector3(c0.x, 0, c0.z), Vector3(c0.x, 0, c1.z), Vector3(1, 0, 0)], [Vector3(c1.x, 0, c0.z), Vector3(c1.x, 0, c1.z), Vector3(-1, 0, 0)],
				[Vector3(c0.x, 0, c0.z), Vector3(c1.x, 0, c0.z), Vector3(0, 0, 1)], [Vector3(c0.x, 0, c1.z), Vector3(c1.x, 0, c1.z), Vector3(0, 0, -1)]]:
			var pa: Vector3 = e[0]
			var pb: Vector3 = e[1]
			if absf((e[2] as Vector3).z) < 0.5:
				pk.quad(kit, "tank", [Vector3(pa.x, y0, pa.z), Vector3(pb.x, y0, pb.z), Vector3(pb.x, y1, pb.z), Vector3(pa.x, y1, pa.z)], e[2], Color(0.3, 0.32, 0.3))
				continue
			# The ends: open round the tunnel (its mouths), the glass walls of the tank framing them.
			var zz0: float = pa.z
			for piece in [[pa.x, MALL_PORTAL.x, y0, y1], [MALL_PORTAL.y, pb.x, y0, y1], [MALL_PORTAL.x, MALL_PORTAL.y, MALL_PORTAL_Y.y, y1]]:
				pk.quad(kit, "tank", [Vector3(piece[0], piece[2], zz0), Vector3(piece[1], piece[2], zz0), Vector3(piece[1], piece[3], zz0), Vector3(piece[0], piece[3], zz0)],
						e[2], Color(0.3, 0.32, 0.3))
		# Rocks and coral on the floor, kept off the tunnel.
		for i in range(60):
			var p := Vector3(rng.randf_range(r.position.x + 4.0, r.end.x - 4.0), y0, rng.randf_range(r.position.y + 4.0, r.end.y - 4.0))
			if absf(p.x - 245.0) < 14.0:
				continue
			if rng.randf() < 0.5:
				MCK.rock_heap(pk, kit, p, rng.randf_range(3.0, 8.0), rng)
			else:
				MCK.coral(pk, kit, p, rng.randf_range(2.0, 5.0), Color.from_hsv(rng.randf_range(0.0, 0.12) if rng.randf() < 0.6 else rng.randf_range(0.75, 0.95), 0.7, 0.9), rng)
		# The tunnel: an acrylic tube over the road (its floor the road), ribs every 6m, blue LED along its foot.
		var s: float = s0 - 2.0
		while s < s1 + 2.0:
			var sb: float = minf(s + 3.0, s1 + 2.0)
			var pa2: Vector3 = lap.pt(s)
			var pb2: Vector3 = lap.pt(sb)
			var ra: Vector3 = lap.rt(s)
			for k in range(10):
				var t0: float = PI * float(k) / 10.0
				var t1: float = PI * float(k + 1) / 10.0
				var rr: float = road_half + 2.0
				var q0 := Vector3(0, sin(t0) * (rr + 1.0), 0) + ra * cos(t0) * rr
				var q1 := Vector3(0, sin(t1) * (rr + 1.0), 0) + ra * cos(t1) * rr
				var nm: Vector3 = ((q0 + q1) * 0.5).normalized()
				pk.quad(kit, "acrylic", [pa2 + q0, pb2 + q0, pb2 + q1, pa2 + q1], -nm, Color(1, 1, 1))
			s = sb
		var sr: float = s0
		while sr < s1:
			var pc: Vector3 = lap.pt(sr)
			var rc: Vector3 = lap.rt(sr)
			var prev := Vector3.ZERO
			for k2 in range(11):
				var t2: float = PI * float(k2) / 10.0
				var q2: Vector3 = pc + Vector3(0, sin(t2) * (road_half + 3.0), 0) + rc * cos(t2) * (road_half + 2.0)
				if k2 > 0:
					pk.beam(kit, "steel", prev, q2, 0.25, 0.25, Color(0.2, 0.22, 0.25))
				prev = q2
			sr += 6.0
		for side in [-1.0, 1.0]:
			MCK.led_line(pk, kit, lap.pt(s0) + lap.rt(s0) * side * (road_half + 1.6), lap.pt(s1) + lap.rt(s1) * side * (road_half + 1.6), Color(0.2, 0.6, 1.0, 0.0), 0.2)
	, 1200.0)
	_edge_boxes(_rails, lap, s0 - 2.0, s1 + 2.0, -(road_half + 1.2), 3.0, 0.5)
	_edge_boxes(_rails, lap, s0 - 2.0, s1 + 2.0, road_half + 1.2, 3.0, 0.5)
	_build_fish(root, rng)


## The fish: a MultiMesh a kind (aquarium_fish.gdshader swims them round their loops).
func _build_fish(root: Node3D, rng: RandomNumberGenerator) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://aquarium_fish.gdshader")
	mat.set_shader_parameter("surface_y", AQUA_SURFACE)
	var mat_s: Material = _save_res(mat, "fish_material")
	var kinds: Array = [
		# [name, length, height, width, colour, count, loop radius range, speed (loops a minute)]
		["Fish_small", 1.0, 0.45, 0.18, Color(1.0, 0.75, 0.2), 140, Vector2(6.0, 18.0), 3.0],
		["Fish_blue", 1.4, 0.6, 0.2, Color(0.3, 0.55, 1.0), 90, Vector2(8.0, 24.0), 2.2],
		["Fish_ray", 3.2, 0.35, 3.0, Color(0.55, 0.5, 0.45), 10, Vector2(14.0, 28.0), 0.9],
	]
	for kd in kinds:
		var mesh := _fish_mesh(float(kd[1]), float(kd[2]), float(kd[3]), kd[4], String(kd[0]) == "Fish_ray")
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = int(kd[5])
		# The buffer is written by hand (the headless renderer keeps no instances): per fish the transform's 12 floats,
		# its colour, its custom data.
		var buf := PackedFloat32Array()
		for i in range(mm.instance_count):
			# Each fish loops in the tank on one side of the tunnel (x 245): long loops along it, narrow across.
			var rr: Vector2 = kd[6]
			var rz: float = rng.randf_range(rr.x, rr.y)
			var rx: float = minf(rz * 0.35, 7.0)
			var side: float = -1.0 if rng.randf() < 0.5 else 1.0
			var cx: float = 245.0 + side * rng.randf_range(road_half + 5.0 + rx, 38.0 - rx)
			var c := Vector3(cx, rng.randf_range(AQUA_FLOOR + 3.0, AQUA_SURFACE - 3.0), rng.randf_range(AQUA.position.y + 6.0 + rz, AQUA.end.y - 6.0 - rz))
			var xf := Transform3D(Basis(Vector3.UP, 0.0 if rng.randf() < 0.5 else PI), c)
			buf.append_array(PropKit.transform_buffer([xf]))
			buf.append_array(PackedFloat32Array([1.0, 1.0, 1.0, 1.0]))
			buf.append_array(PackedFloat32Array([rx, rz, float(kd[7]) * rng.randf_range(0.8, 1.2), rng.randf()]))
		mm.buffer = buf
		var mmi := MultiMeshInstance3D.new()
		mmi.name = String(kd[0])
		mmi.multimesh = _save_res(mm, String(kd[0]).to_lower(), stem + "fish_")
		mmi.material_override = mat_s
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 500.0
		mmi.custom_aabb = AABB(Vector3(AQUA.position.x, AQUA_FLOOR, AQUA.position.y), Vector3(AQUA.size.x, AQUA_SURFACE - AQUA_FLOOR, AQUA.size.y)).grow(4.0)
		root.add_child(mmi)


## A fish (nose +z): a lathed body flattened sideways, a tail fin; a ray is flat and wide.
func _fish_mesh(length: float, height: float, width: float, col: Color, ray: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 8
	var segs := 8
	var pts: Array = []
	for i in range(rings + 1):
		var t: float = float(i) / float(rings)
		var z: float = lerpf(length * 0.5, -length * 0.5, t)
		var r: float = sin(t * PI) * (1.0 - 0.45 * t)
		var ring: Array = []
		for j in range(segs):
			var a: float = TAU * float(j) / float(segs)
			ring.append(Vector3(cos(a) * width * 0.5 * r, sin(a) * height * 0.5 * r, z))
		pts.append(ring)
	for i in range(rings):
		for j in range(segs):
			var a: Vector3 = pts[i][j]
			var b: Vector3 = pts[i][(j + 1) % segs]
			var c: Vector3 = pts[i + 1][j]
			var d: Vector3 = pts[i + 1][(j + 1) % segs]
			var shade: Color = col.lightened(0.25) if a.y > 0.0 else col.darkened(0.2)
			for v in [a, c, b, b, c, d]:
				st.set_color(shade)
				st.set_normal(Vector3(v.x / maxf(width, 0.01), v.y / maxf(height, 0.01), 0.0).normalized())
				st.add_vertex(v)
	# The tail fin.
	var tz: float = -length * 0.5
	var fin: Array = [Vector3(0, 0, tz + length * 0.08), Vector3(0, height * 0.55, tz - length * 0.18), Vector3(0, -height * 0.45, tz - length * 0.16)]
	if ray:
		fin = [Vector3(0, 0, tz + 0.1), Vector3(0.05, 0, tz - length * 0.6), Vector3(-0.05, 0, tz - length * 0.6)]
	for v2 in fin:
		st.set_color(col.darkened(0.1))
		st.set_normal(Vector3.RIGHT)
		st.add_vertex(v2)
	# Eyes: a white disc and a black pupil each side of the head, a hair proud of the body.
	if not ray:
		var ez: float = length * 0.32
		var tt: float = 0.5 - ez / length
		var rr: float = sin(tt * PI) * (1.0 - 0.45 * tt)
		var ex: float = width * 0.5 * rr * 0.97
		var ey: float = height * 0.1
		var re: float = height * 0.14
		for side in [-1.0, 1.0]:
			var n := Vector3(side, 0, 0)
			for disc in [[re, 0.01, Color(0.92, 0.92, 0.88)], [re * 0.58, 0.018, Color(0.02, 0.02, 0.03)]]:
				var c0 := Vector3(side * (ex + float(disc[1]) * width), ey, ez)
				var rad: float = disc[0]
				for k in range(10):
					var a0: float = TAU * float(k) / 10.0
					var a1: float = TAU * float(k + 1) / 10.0
					for v3 in [c0, c0 + Vector3(0, sin(a0), cos(a0)) * rad, c0 + Vector3(0, sin(a1), cos(a1)) * rad]:
						st.set_color(disc[2])
						st.set_normal(n)
						st.add_vertex(v3)
	return st.commit()


# ---- The flyover from the mall down into the street -----------------------------------------------------------------

func _build_flyover() -> void:
	var a: Dictionary = _a
	var s0: float = float(a["mall_out"])
	var s1: float = float(a["street"]) - 2.0
	_deck("deck_flyover", s0, s1, 1.8, Color(1.0, 0.7, 0.3, 0.0), 32.0, [true, true], 0.0, true)
	_city("deck_flyover_lamps", func(pk: PropKit, kit: Dictionary, _l: Array) -> void:
		var s: float = s0 + 10.0
		var k := 0
		while s < s1:
			var side: float = -1.0 if k % 2 == 0 else 1.0
			var b: Vector3 = lap.pt(s) + lap.rt(s) * side * (road_half + 0.7)
			pk.tube(kit, "steel", b, b + Vector3(0, 9.0, 0), 0.14, 0.1, 6, Color(0.35, 0.36, 0.4))
			var head: Vector3 = b + Vector3(0, 9.0, 0) - lap.rt(s) * side * 2.2
			pk.beam(kit, "steel", b + Vector3(0, 9.0, 0), head, 0.12, 0.12, Color(0.35, 0.36, 0.4))
			pk.block(kit, "neon", head + Vector3(-0.5, -0.15, -0.3), head + Vector3(0.5, 0.0, 0.3), Color(1.0, 0.85, 0.65))
			s += 24.0
			k += 1
	, 1600.0)


# ---- The night-market street ----------------------------------------------------------------------------------------

const STREET_SIGNS := ["火锅", "小面", "烧烤", "奶茶", "抄手", "豆花", "串串", "麻辣", "夜市", "茶", "药房", "酒店", "按摩", "饺子", "网吧", "便利店", "冰淇淋",
	"包子", "果汁", "理发", "手机", "宾馆", "美食", "福"]


func _build_street() -> void:
	var a: Dictionary = _a
	var s0: float = float(a["street"]) - 60.0
	var s1: float = float(a["park"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7701
	_city("street", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		var s: float = s0
		var k := 0
		while s < s1 - 10.0:
			for side in [-1.0, 1.0]:
				# Vertical neon signs out from the fronts (the blocks' fronts stand 16m off the street's middle).
				if rng.randf() < 0.75:
					var base: Vector3 = lap.pt(s) + lap.rt(s) * side * 15.4
					base.y = 0.0
					var txt: String = STREET_SIGNS[k % STREET_SIGNS.size()]
					var col := Color.from_hsv(rng.randf(), rng.randf_range(0.6, 0.9), 1.0)
					var hgt: float = 2.0 + 1.6 * float(txt.length())
					MCK.neon_sign(pk, kit, labels, base + Vector3(0, 8.0 + hgt * 0.5, 0), lap.fw(s) * side, 2.2, hgt, txt, col, true, 0.5)
					k += 1
			# Strings of lanterns across the street.
			# Only where the road is down in the street between the fronts they hang from: over the flyover's foot, 9m up,
			# they had hung a metre over the road.
			if int(s) % 3 == 0 and lap.pt(s).y < 1.0:
				var hang := 9.0
				var l0: Vector3 = lap.pt(s) + lap.rt(s) * -14.0
				var l1: Vector3 = lap.pt(s) + lap.rt(s) * 14.0
				l0.y = hang
				l1.y = hang
				var pts: Array = _sag(l0, l1, 1.4, 10)
				for i in range(pts.size() - 1):
					pk.tube(kit, "matte", pts[i], pts[i + 1], 0.02, 0.02, 3, Color(0.1, 0.1, 0.1), false)
				for i2 in range(1, pts.size() - 1, 2):
					MCK.lantern(pk, kit, (pts[i2] as Vector3) + Vector3(0, -0.6, 0), 0.9)
			s += 16.0
	, 900.0)
	# Food stalls along the pavements: lit counters with awnings.
	_city("street_stalls", func(pk: PropKit, kit: Dictionary, _l: Array) -> void:
		var s2: float = s0 + 20.0
		while s2 < s1 - 30.0:
			for side in [-1.0, 1.0]:
				if rng.randf() < 0.5:
					continue
				var c: Vector3 = lap.pt(s2) + lap.rt(s2) * side * 12.4
				c.y = 0.0
				var f: Vector3 = lap.fw(s2)
				var xf := Transform3D(Basis(f, Vector3.UP, f.cross(Vector3.UP)), c)
				pk.box(kit, "paint", xf.translated_local(Vector3(0, 0.55, 0)), Vector3(3.2, 1.1, 1.6), Color(0.5, 0.15, 0.1))
				pk.box(kit, "neon", xf.translated_local(Vector3(0, 1.15, 0)), Vector3(3.0, 0.1, 1.4), Color(1.0, 0.8, 0.5))
				pk.box(kit, "paint", xf.translated_local(Vector3(0, 2.6, 0)), Vector3(3.6, 0.1, 2.2), Color.from_hsv(rng.randf(), 0.7, 0.8))
				for dx in [-1.6, 1.6]:
					pk.beam(kit, "steel", xf * Vector3(dx, 0, 0.9), xf * Vector3(dx, 2.6, 0.9), 0.06, 0.06, Color(0.4, 0.4, 0.4))
			s2 += 11.0
	, 600.0)
	# The street's crowd on both pavements.
	var s3: float = float(a["street"])
	while s3 < s1 - 10.0:
		for side in [-1.0, 1.0]:
			if rng.randf() < 0.55:
				var p: Vector3 = lap.pt(s3) + lap.rt(s3) * side * rng.randf_range(10.2, 14.0)
				p.y = _ground_at(p.x, p.z)
				_person(p, -lap.rt(s3) * side + lap.fw(s3) * rng.randf_range(-0.6, 0.6), rng.randf_range(0.92, 1.06))
		s3 += 3.0


# ---- The park: the finish -------------------------------------------------------------------------------------------

func _build_park() -> void:
	var p: Rect2 = PARK
	_reserved.append(p.grow(4.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 8801
	var a: Dictionary = _a
	_city("park", func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		# The park's gate: a red paifang over the road where it enters, its name in gold.
		var s_gate: float = float(a["park"]) + 6.0
		var g: Vector3 = lap.pt(s_gate)
		var rt: Vector3 = lap.rt(s_gate)
		var fw: Vector3 = lap.fw(s_gate)
		# Two pillars a side, both off the road (the outer lower).
		for side in [-1.0, 1.0]:
			for k in range(2):
				var b: Vector3 = g + rt * side * (road_half + 1.3 + 2.6 * float(k))
				pk.tube(kit, "paint", b, b + Vector3(0, 11.0 - 1.5 * float(k), 0), 0.55, 0.55, 10, Color(0.7, 0.08, 0.06))
		pk.box(kit, "paint", Transform3D(Basis(rt, Vector3.UP, fw), g + Vector3(0, 11.5, 0)), Vector3(2.0 * road_half + 8.0, 0.9, 1.4), Color(0.75, 0.1, 0.08))
		pk.box(kit, "paint", Transform3D(Basis(rt, Vector3.UP, fw), g + Vector3(0, 12.6, 0)), Vector3(2.0 * road_half + 11.0, 0.6, 2.4), Color(0.12, 0.25, 0.2))
		MCK.neon_sign(pk, kit, labels, g + Vector3(0, 10.0, 0) - fw * 0.8, -fw, 9.0, 2.0, "云海公园", Color(1.0, 0.8, 0.3))
		# The lake west of the finish, a zigzag bridge over it, lanterns on posts along the paths.
		var lake := Rect2(p.position.x + 20.0, p.position.y + 60.0, 70.0, 150.0)
		pk.block(kit, "neon", Vector3(lake.position.x, -0.4, lake.position.y), Vector3(lake.end.x, -0.3, lake.end.y), Color(0.02, 0.05, 0.09))
		var zz: float = lake.position.y + 20.0
		while zz < lake.end.y - 20.0:
			var c := Vector3(lake.get_center().x, 0.0, zz)
			MCK.lantern(pk, kit, c + Vector3(0, 0.8, 0), 0.8)
			zz += 18.0
		# A pavilion on the lake's far side: red columns, a dark roof with upturned corners, lit.
		var pv := Vector3(lake.position.x + 8.0, 0.0, lake.get_center().y)
		for dx in [-4.0, 4.0]:
			for dz in [-4.0, 4.0]:
				pk.tube(kit, "paint", pv + Vector3(dx, 0, dz), pv + Vector3(dx, 6.0, dz), 0.4, 0.4, 8, Color(0.7, 0.08, 0.06))
		pk.lathe(kit, "paint", pv + Vector3(0, 6.0, 0), [Vector2(8.5, 0.6), Vector2(6.0, 1.2), Vector2(3.0, 2.8), Vector2(0.5, 4.0), Vector2(0.001, 4.4)], 4,
				Color(0.12, 0.13, 0.15), true, Basis(Vector3.UP, PI * 0.25))
		MCK.lantern(pk, kit, pv + Vector3(0, 5.0, 0), 1.2)
		# Lamp posts along the park road.
		var s: float = float(a["park"]) + 20.0
		while s < lap.length - 5.0:
			for side2 in [-1.0, 1.0]:
				var lp: Vector3 = lap.pt(s) + lap.rt(s) * side2 * (road_half + 2.5)
				lp.y = 0.0
				pk.tube(kit, "steel", lp, lp + Vector3(0, 4.5, 0), 0.08, 0.06, 6, Color(0.15, 0.15, 0.15))
				MCK.lantern(pk, kit, lp + Vector3(0, 4.9, 0), 0.7, Color(1.0, 0.75, 0.4))
			s += 20.0
	, 900.0)
	# Spectators at the finish.
	var fs: float = lap.length - finish_runout
	var s2: float = fs - 60.0
	while s2 < fs + 30.0:
		for side3 in [-1.0, 1.0]:
			for row in range(2):
				if rng.randf() < 0.3:
					continue
				var pp: Vector3 = lap.pt(s2) + lap.rt(s2) * side3 * (road_half + 3.5 + float(row) * 1.6 + rng.randf() * 0.6)
				pp.y = _ground_at(pp.x, pp.z)
				_person(pp, -lap.rt(s2) * side3, rng.randf_range(0.92, 1.06))
		s2 += 2.4
	var body := _body(level, "FinishBarriersBody")
	for side4 in [-1.0, 1.0]:
		_edge_boxes(body, lap, fs - 60.0, fs + 30.0, side4 * (road_half + 2.6), 1.0, 0.3)


## Along the night-market street every block has shops at its foot.
func _plot_tweak(plot: Rect2, d: Dictionary) -> void:
	if absf(plot.get_center().y - STREET_Z) < 75.0 and plot.get_center().x > 200.0 and plot.get_center().x < 820.0:
		d["podium"] = 7.0
		d["style"] = MCK.STYLE_FLATS
		d["top"] = maxf(float(d["top"]), 30.0)


func _tree_pick(x: float, z: float, roll: float, rng: RandomNumberGenerator) -> Array:
	if PARK.has_point(Vector2(x, z)):
		var lake := Rect2(PARK.position.x + 20.0, PARK.position.y + 60.0, 70.0, 150.0)
		if lake.grow(6.0).has_point(Vector2(x, z)):
			return []
		if roll > 0.45:
			return []
		var near_lake: bool = lake.grow(20.0).has_point(Vector2(x, z))
		var k: String = "shidare" if near_lake else ["sakura", "momiji", "matsu", "take"][rng.randi() % 4]
		return [k, rng.randf_range(0.85, 1.15)]
	return []


# ---- The city round the course ---------------------------------------------------------------------------------------


# ---- Crowds on the roofs ---------------------------------------------------------------------------------------------

func _build_crowds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1201
	# Along the start straight's deck, both sides, behind the planters' line.
	_crowd_line(Vector3(-30.0, Y_TOP, -road_half - 3.5), Vector3(330.0, Y_TOP, -road_half - 3.5), Vector3(0, 0, 1), 2.2, rng, 0.55)
	_crowd_line(Vector3(-30.0, Y_TOP, road_half + 3.5), Vector3(330.0, Y_TOP, road_half + 3.5), Vector3(0, 0, -1), 2.2, rng, 0.55)
	# On tower B's roof by the landing, tower D's by the jump, the mall's roof.
	_crowd_line(Vector3(B_C.x - B_HALF + 6.0, Y_B, -road_half - 6.0), Vector3(B_C.x + 10.0, Y_B, -road_half - 6.0), Vector3(0, 0, 1), 2.0, rng, 0.7)
	_crowd_line(Vector3(D_C.x - road_half - 5.0, Y_D, D_C.y - 20.0), Vector3(D_C.x - road_half - 5.0, Y_D, D_C.y + 24.0), Vector3(1, 0, 0), 2.0, rng, 0.7)
	_crowd_line(Vector3(D_C.x + road_half + 5.0, Y_D, D_C.y - 20.0), Vector3(D_C.x + road_half + 5.0, Y_D, D_C.y + 24.0), Vector3(-1, 0, 0), 2.0, rng, 0.7)
	# Shoppers on the hall's balconies, looking down at the ramps.
	var fy: float = HALL_FLOOR + 8.0
	while fy < Y_MALL:
		_crowd_line(Vector3(HALL.position.x + 6.0, fy, HALL.position.y + 4.0), Vector3(HALL.end.x - 6.0, fy, HALL.position.y + 4.0), Vector3(0, 0, 1), 3.0, rng, 0.45)
		# The south walkways stop short of the aquarium's door on the low floors (_build_hall).
		if fy < MALL_PORTAL_Y.y + 12.0:
			_crowd_line(Vector3(HALL.position.x + 6.0, fy, HALL.end.y - 4.0), Vector3(MALL_PORTAL.x - 16.0, fy, HALL.end.y - 4.0), Vector3(0, 0, -1), 3.0, rng, 0.45)
			_crowd_line(Vector3(MALL_PORTAL.y + 16.0, fy, HALL.end.y - 4.0), Vector3(HALL.end.x - 6.0, fy, HALL.end.y - 4.0), Vector3(0, 0, -1), 3.0, rng, 0.45)
		else:
			_crowd_line(Vector3(HALL.position.x + 6.0, fy, HALL.end.y - 4.0), Vector3(HALL.end.x - 6.0, fy, HALL.end.y - 4.0), Vector3(0, 0, -1), 3.0, rng, 0.45)
		fy += 8.0


# ======================================================================================
#  After the build
# ======================================================================================

func _finish(root: Node3D) -> void:
	# A cart that falls off the towers is put back at its last gate once it is this far under the track (Level reads it).
	root.set_meta(&"fall_respawn_drop", 18.0)
	root.set_meta(&"music_stage", "tianqiao")
