# regenerate_stadtrallye.gd
#
# Builds levels/StadtrallyeLevel.tscn - Quer durch Kronburg, the Kronburg GP's finale: a point-to-point rally sprint (one
# run, no laps) of about 6km straight across Kronburg on a sunny late-summer morning. From the start on the Kaiserstraße
# in front of the Hauptbahnhof it runs through the Gründerzeit Neustadt (over the humpback bridge across the old moat,
# through the pedestrian zone past the Kaufhaus, under the railway), across the Ring (four lanes and the trams in the
# median, crossed at speed between the traffic: touching a vehicle wrecks a cart), through the Botanischer Garten (the
# parterre, straight through the Palmenhaus, under the rose pergola, over the lily pond, up the Alpinum in hairpins to the
# belvedere, a leap off the terrace), under the railway again and down the Hafenstraße into the docks: the demolition
# site with its swinging wrecking ball, the scrapyard's lanes under the magnet crane, the building site (the excavator's
# bucket, the dirt kicker, through the car park's columns, the road roller) to the finish at the old gasworks.
#
# Things worth knowing before editing this file:
#
# 1. The route is an open path of straights and arcs (CORNERS, `_fillet_open`), measured from its start (`_at(s)`). Its
#    height is designed (`_plan_profile`: stations smoothed, then the features added on top: the moat bridge's crest,
#    the dip under each railway bridge, the pond bridge, the terrace's drop, the dirt kicker), and the ground is graded
#    to it (`_grade`). Every road surface is a ribbon a few centimetres over the ground (stadt_road.gdshader, kinds by s
#    in `_road_kinds`); the bodies are split by surface (`ROUTE_BODIES`).
# 2. The ground is `_natural`: the city's plateau (CITY_Y), the garden's hill, the terrace edge down to the docks
#    (DOCK_Y) and the canal, the moat, the pond, the railway's earth embankment (where it has no brick walls). The pads
#    (`_pads`) level the sites.
# 3. The props are the kits' (StadtKit, GardenKit, ScrapKit, BaustelleKit, and the other Kronburg stages' RheinStadtKit,
#    KronburgTownKit, SteelworksKit, PortKit, CampKit), built at life size and grown by PROP_SCALE, batched per cell
#    under PROP_PREFIX (MeshChunker leaves them whole, so DressingColliders makes them solid at race time). Things that
#    stand by the road add their own boxes (`_solids`).
# 4. The hazards run on the wall clock: CrossTraffic.gd (the Ring), WreckingBall.gd, SlewHazard.gd (the magnet crane, the
#    excavator, the tower crane), ShuttleProp.gd (the road roller). Each one the route meets can have a HazardGate.gd (HAZARD_GATES, off), so the
#    bots wait for it as they do at a level crossing.
#
# The generator runs headless and cannot render; scratch/lap_shots.tscn renders the route.
extends Node

const LEVEL_NAME := "StadtrallyeLevel"
const LEVEL_PATH := "res://levels/StadtrallyeLevel.tscn"
const RES_PREFIX := "stadtrallye_"
const PROP_PREFIX := "stadtrallyeprop_"
const ROAD_PREFIX := "stadtrallyeroad_"
const FAR_PREFIX := "stadtrallyefar_"
const TREE_PREFIX := "stadtrallyetree_"
const MeshChunker = preload("res://MeshChunker.gd")
const PropKit = preload("res://PropKit.gd")
const CampKit = preload("res://CampKit.gd")
const CrowdPlacer = preload("res://CrowdPlacer.gd")
const FreightKit = preload("res://FreightKit.gd")
const TyreStacks = preload("res://TyreStacks.gd")

const MESH_CHUNK_CELL := 80.0
const PROP_SCALE := 1.6

const ROAD_HALF := 7.5
const PAVEMENT := 3.4
const GROUND_UNDER := 0.07
const SAMPLE_STEP := 3.0
const CELL := 32.0
const GRADE_REACH := 52.0

## The route: [x, z, radius]; the first and last are its ends (x east, z south).
const CORNERS := [
	[-1150.0, 0.0, 0.0],
	[-640.0, 0.0, 20.0],     # 1: off the Kaiserstraße, south toward the moat
	[-640.0, 270.0, 20.0],   # 2: into the pedestrian zone
	[-330.0, 270.0, 22.0],   # 3: north, under the railway
	[-330.0, -200.0, 26.0],  # 4: east toward the Ring
	[300.0, -200.0, 16.0],   # 5: in the garden: round the parterre, north through the Palmenhaus
	[300.0, -470.0, 16.0],   # 6: east under the rose pergola
	[560.0, -470.0, 14.0],   # 7: south over the lily pond
	[560.0, -370.0, 14.0],   # 8: east, up the Alpinum
	[760.0, -370.0, 15.0],   # 9: hairpin
	[760.0, -400.0, 15.0],   # 10
	[640.0, -400.0, 15.0],   # 11: hairpin
	[640.0, -430.0, 15.0],   # 12
	[840.0, -430.0, 30.0],   # 13: the belvedere; south down off the terrace, under the railway
	[840.0, 40.0, 70.0],     # 14: the Hafenstraße
	[690.0, 250.0, 70.0],    # 15
	[690.0, 430.0, 30.0],    # 16: west through the demolition site
	[330.0, 430.0, 22.0],    # 17: south into the scrapyard
	[330.0, 680.0, 18.0],    # 18: west down its lanes
	[-30.0, 680.0, 16.0],    # 19: south to the building site
	# 20-24: the building site's parcours (PARCOURS): a U to the right past the excavator, north up the kicker's straight,
	# a U to the left along the north fence over the table-top and through its checkpoint, then west.
	[-30.0, 965.0, 18.0],    # 20: west along the site's south side, past the excavator
	[-140.0, 965.0, 16.0],   # 21: north up the kicker's straight
	[-140.0, 825.0, 16.0],   # 22: west along the north fence, over the table-top
	[-250.0, 825.0, 16.0],   # 23: south
	[-250.0, 900.0, 18.0],   # 24: west through the car park to the gasworks
	[-780.0, 900.0, 0.0],
]

const START_S := 140.0
## The pedestrian zone's shop fronts this far either side of the route's line.
const PED_FRONT := 18.0
const FINISH_RUNOUT := 120.0

## The city's plateau, the docks' plain, the canal.
const CITY_Y := 34.0
const DOCK_Y := 6.2
const CANAL_Z := 1090.0
const CANAL_HALF := 34.0
const CANAL_BED := -2.5
const CANAL_WATER := 2.0

## The railway: east-west along RAIL_Z, its rails' top `_rail_top(x)`; walled (brick) where WALLED says, an earth
## embankment elsewhere. The route passes under it twice, the Ring once.
const RAIL_Z := -130.0
const RAIL_X := Vector2(-2600.0, 2600.0)
const RAIL_TRACK_OFF := 3.0
const EMBANK_UNDER := 0.95
## The first run starts at -1100, where `_natural` stops the earth embankment: it began at -860, under the Hauptbahnhof's
## east half, and the tracks west of the station stood on nothing.
const WALLED := [[-1100.0, -60.0], [40.0, 160.0], [770.0, 910.0]]
const EMBANK_HALF := 12.8

## The Ring: north-south along RING_X, from RING_Z0 to the tunnel's portal at RING_PORTAL_Z (its ramp down from
## RING_RAMP_Z). Its cross-section: the median (tram) to 5.5, two lanes to 16.7, the pavement to RING_HALF.
const RING_X := 100.0
const RING_Z0 := -1300.0
const RING_RAMP_Z := 140.0
const RING_PORTAL_Z := 300.0
const RING_DROP := 8.5
const RING_CARR := 16.7
const RING_HALF := 22.7
const RING_CROSS := Vector2(100.0, -200.0)

## The moat (Stadtgraben): east-west at MOAT_Z, its water's half width and level, its bed.
const MOAT_Z := 120.0
const MOAT_X := Vector2(-1500.0, -380.0)
const MOAT_HALF := 15.0
const MOAT_WATER := 30.6
const MOAT_BED := 28.4
## The moat bridge (GardenKit.stone_bridge style 0): its length and rise in life metres.
const MOAT_BRIDGE := [40.0, 2.2, 6.8]

## The garden: its hill (centre, radius, height), the pond (centre, radii, depth under the bridge's ends), the
## Palmenhaus's middle, the pergola's run, the summit's terrace and its drop, the gates.
const HILL_C := Vector2(790.0, -380.0)
const HILL_R := 340.0
const HILL_H := 22.0
const POND_C := Vector2(548.0, -421.0)
const POND_R := Vector2(40.0, 20.0)
const POND_BRIDGE := [24.0, 1.0, 4.9]
const PALM_C := Vector2(300.0, -310.0)
const PERGOLA_X := Vector2(342.0, 528.0)
const GARDEN_RECT := [140.0, -520.0, 905.0, -150.0]
const GARDEN_GATE := Vector2(140.0, -200.0)
const GARDEN_EXIT := Vector2(840.0, -175.0)
const TERRACE_Z := -330.0
const TERRACE_DROP := 4.6
const BELVEDERE_AT := Vector2(882.0, -470.0)

## The docks: the demolition site's wrecking ball over the route, the scrapyard's magnet crane, the building site's
## excavator, kicker, car park and road roller, the finish at the gasworks.
const BALL_X := 520.0
## The material handler's slew ring: its stick reaches 29m, so its magnet hangs over the lane (z 680) at slew 0.
const HANDLER_AT := Vector2(150.0, 709.0)
## The excavator 21m south of the parcours' first leg (z 965), its arm swinging over the leg's south half.
const EXCAVATOR_AT := Vector2(-85.0, 986.0)
## The kicker's lip, on the parcours' straight north (x -140), and the table-top's first lip, on its leg west (z 825).
const KICKER_AT := Vector2(-140.0, 900.0)
const TABLE_AT := Vector2(-182.0, 825.0)
const CARPARK_X := Vector2(-380.0, -482.0)
const ROLLER_X := -548.0
const GASWORKS_C := Vector2(-850.0, 960.0)

## The terrain grid: fine over the stage, growing coarser out to OUTER.
const FINE_X := Vector2(-1320.0, 1000.0)
const FINE_Z := Vector2(-600.0, 1180.0)
const FINE_STEP := 5.0
const OUTER := 6500.0
const COARSE_GROWTH := 1.16
const COARSE_MAX := 180.0

var level: Node3D
var _route: Dictionary = {}
var segs: Array = []
var route_len := 0.0
var _finish_s := 0.0
var _road_y := PackedFloat32Array()

var _noise := FastNoiseLite.new()
var _hill_noise := FastNoiseLite.new()
var _forest_noise := FastNoiseLite.new()

## Road samples for the grading: position, right, flat band half width, along the route or a dressing road.
var _rs_pos := PackedVector3Array()
var _rs_right := PackedVector3Array()
var _rs_flat := PackedFloat32Array()
var _rs_next := PackedInt32Array()
var _rs_cells := {}
var _route_rs := 0

var _grid_x := PackedFloat32Array()
var _grid_z := PackedFloat32Array()
var _heights := PackedFloat32Array()
var _road_d := PackedFloat32Array()
var _ground_mat: ShaderMaterial
var _road_mat: ShaderMaterial


# ======================================================================================
#  The route
# ======================================================================================

func _dir_of(th: float) -> Vector2:
	return Vector2(cos(th), sin(th))


## Right of travel for a heading (x east, z south: heading east has the south on its right).
func _right_of(th: float) -> Vector2:
	return Vector2(-sin(th), cos(th))


## An open path through `corners` ([x, z, radius]; the first and last are its ends): straights joined by arcs.
func _fillet_open(corners: Array) -> Dictionary:
	var n: int = corners.size()
	var out: Array = []
	var turns: Array = []
	var s := 0.0
	var prev := Vector2(corners[0][0], corners[0][1])
	for i in range(1, n - 1):
		var a := Vector2(corners[i - 1][0], corners[i - 1][1])
		var b := Vector2(corners[i][0], corners[i][1])
		var c := Vector2(corners[i + 1][0], corners[i + 1][1])
		var r: float = corners[i][2]
		var d1: Vector2 = (b - a).normalized()
		var d2: Vector2 = (c - b).normalized()
		var ang: float = atan2(d1.x * d2.y - d1.y * d2.x, d1.dot(d2))
		var t: float = r * tan(absf(ang) * 0.5)
		var room_in: float = b.distance_to(a) * (1.0 if i == 1 else 0.5)
		var room_out: float = b.distance_to(c) * (1.0 if i == n - 2 else 0.5)
		if t > room_in + 0.01 or t > room_out + 0.01:
			push_error("route: corner %d's radius %.0f does not fit" % [i, r])
		var p_in: Vector2 = b - d1 * t
		var length: float = prev.distance_to(p_in)
		out.append({"kind": "S", "p0": prev, "th0": atan2(d1.y, d1.x), "len": length, "s0": s})
		s += length
		var arc_len: float = r * absf(ang)
		out.append({"kind": "A", "p0": p_in, "th0": atan2(d1.y, d1.x), "r": r, "sign": signf(ang), "len": arc_len, "s0": s})
		turns.append({"s0": s, "s1": s + arc_len, "turn": rad_to_deg(ang), "r": r})
		s += arc_len
		prev = b + d2 * t
	var last := Vector2(corners[n - 1][0], corners[n - 1][1])
	var dl: Vector2 = last - prev
	out.append({"kind": "S", "p0": prev, "th0": atan2(dl.y, dl.x), "len": dl.length(), "s0": s})
	s += dl.length()
	return {"segs": out, "len": s, "turns": turns}


## Position, heading and signed curvature at s (past either end it carries straight on).
func _at(s: float) -> Dictionary:
	var seg: Dictionary = segs[0]
	for i in range(segs.size() - 1, -1, -1):
		if s >= float(segs[i]["s0"]) - 0.0001:
			seg = segs[i]
			break
	var d: float = s - float(seg["s0"])
	var p0: Vector2 = seg["p0"]
	var th0: float = seg["th0"]
	if seg["kind"] == "S" or d < 0.0:
		return {"p": p0 + _dir_of(th0) * d, "th": th0, "k": 0.0}
	if d > float(seg["len"]):
		var e: Dictionary = _arc_point(seg, float(seg["len"]))
		return {"p": (e["p"] as Vector2) + _dir_of(e["th"]) * (d - float(seg["len"])), "th": e["th"], "k": 0.0}
	return _arc_point(seg, d)


func _arc_point(seg: Dictionary, d: float) -> Dictionary:
	var r: float = seg["r"]
	var sgn: float = seg["sign"]
	var th0: float = seg["th0"]
	var c: Vector2 = (seg["p0"] as Vector2) + _right_of(th0) * r * sgn
	var th: float = th0 + sgn * d / r
	return {"p": c - _right_of(th) * r * sgn, "th": th, "k": sgn / r}


func _lap_y(s: float) -> float:
	var n: int = _road_y.size()
	var f: float = clampf(s, 0.0, float(n - 1) - 0.001)
	var i: int = int(floor(f))
	return lerpf(_road_y[i], _road_y[mini(i + 1, n - 1)], f - float(i))


func _pt(s: float) -> Vector3:
	var p: Vector2 = _at(s)["p"]
	return Vector3(p.x, _lap_y(s), p.y)


func _rt(s: float) -> Vector3:
	var r: Vector2 = _right_of(float(_at(s)["th"]))
	return Vector3(r.x, 0.0, r.y)


func _fw(s: float) -> Vector3:
	var f: Vector2 = _dir_of(float(_at(s)["th"]))
	return Vector3(f.x, 0.0, f.y)


## A spot on the route: `lat` metres right of the line, `lift` over the road, the yaw facing the way of travel.
func _spot(s: float, lat: float, lift: float) -> Dictionary:
	var fwd: Vector3 = _fw(s)
	var right: Vector3 = _rt(s)
	var pos: Vector3 = _pt(s) + right * lat + Vector3(0, lift, 0)
	return {"pos": pos, "yaw": rad_to_deg(atan2(-fwd.x, -fwd.z)), "fwd": fwd, "right": right}


## The s nearest to q in plan.
func _closest_s(q: Vector2) -> float:
	var best := 0.0
	var bd := INF
	var s := 0.0
	while s < route_len:
		var d: float = (_at(s)["p"] as Vector2).distance_squared_to(q)
		if d < bd:
			bd = d
			best = s
		s += 4.0
	var lo: float = maxf(best - 4.0, 0.0)
	var hi: float = minf(best + 4.0, route_len)
	s = lo
	while s <= hi:
		var d2: float = (_at(s)["p"] as Vector2).distance_squared_to(q)
		if d2 < bd:
			bd = d2
			best = s
		s += 0.1
	return best


func _turn(i: int) -> Dictionary:
	return (_route["turns"] as Array)[i - 1]


# ======================================================================================
#  The route's height
# ======================================================================================

## Where along the route the features are (filled by `_plan_profile`).
var s_moat := 0.0
var s_under1 := 0.0
var s_ring := 0.0
var s_gate := 0.0
var s_palm := 0.0
var s_pond := 0.0
var s_terrace := 0.0
var s_exit := 0.0
var s_under2 := 0.0
var s_ball := 0.0
var s_kicker := 0.0
var s_table := 0.0
var s_carpark0 := 0.0
var s_carpark1 := 0.0
var s_roller := 0.0

## The kicker on the building site (a heap of spoil shaped into a jump): [length up, height, length down].
const KICKER := [24.0, 3.3, 8.0]
## The table-top on the parcours (spoil too): [length up, height, table, length down].
const TABLE := [10.0, 1.8, 9.0, 10.0]
## The terrace's kicker before its drop: [length, rise].
const TERRACE_KICK := [14.0, 0.9]
## The flight of stairs from the kicker's lip down to the road below the terrace: its run (m along the route) and steps.
## The road's collision runs straight down their nosings; the stairs are drawn (`_build_terrace_stairs`), not the ribbon.
const TERRACE_FACE := 9.0
const TERRACE_STEPS := 15


static func _cos2(u: float) -> float:
	var c: float = cos(clampf(u, -0.5, 0.5) * PI)
	return c * c


func _plan_profile() -> void:
	s_moat = _closest_s(Vector2(-640.0, MOAT_Z))
	s_under1 = _closest_s(Vector2(-330.0, RAIL_Z))
	s_ring = _closest_s(RING_CROSS)
	s_gate = _closest_s(GARDEN_GATE)
	s_palm = _closest_s(PALM_C)
	s_pond = _closest_s(Vector2(560.0, POND_C.y))
	s_terrace = _closest_s(Vector2(840.0, TERRACE_Z))
	s_exit = _closest_s(GARDEN_EXIT)
	s_under2 = _closest_s(Vector2(840.0, RAIL_Z))
	s_ball = _closest_s(Vector2(BALL_X, 430.0))
	s_kicker = _closest_s(KICKER_AT)
	s_table = _closest_s(TABLE_AT)
	s_carpark0 = _closest_s(Vector2(CARPARK_X.x, 900.0))
	s_carpark1 = _closest_s(Vector2(CARPARK_X.y, 900.0))
	s_roller = _closest_s(Vector2(ROLLER_X, 900.0))
	var t5: Dictionary = _turn(5)
	var t6: Dictionary = _turn(6)
	var t7: Dictionary = _turn(7)
	var t8: Dictionary = _turn(8)
	var t9: Dictionary = _turn(9)
	var t10: Dictionary = _turn(10)
	var t11: Dictionary = _turn(11)
	var t12: Dictionary = _turn(12)
	var t13: Dictionary = _turn(13)
	var t15: Dictionary = _turn(15)
	var t16: Dictionary = _turn(16)
	# [s, y]: the city level, the garden climbing to the summit, down off the terrace, under the railway, down to the docks.
	var st: Array = [
		[0.0, CITY_Y], [s_ring + 60.0, CITY_Y], [float(t5["s0"]), CITY_Y + 0.3], [s_palm + 70.0, CITY_Y + 0.6],
		[float(t6["s1"]) + 20.0, CITY_Y + 0.9], [float(t7["s0"]) - 12.0, CITY_Y + 2.6], [float(t8["s1"]) + 15.0, CITY_Y + 3.0],
		[float(t9["s0"]), CITY_Y + 10.5], [float(t10["s1"]), CITY_Y + 11.5], [float(t11["s0"]), CITY_Y + 17.0],
		[float(t12["s1"]), CITY_Y + 18.0], [float(t13["s0"]), CITY_Y + 23.0], [s_terrace - 20.0, CITY_Y + 23.3],
		[s_terrace + 6.0, CITY_Y + 23.3 - TERRACE_DROP], [s_under2 - 60.0, 38.6], [s_under2 + 40.0, 37.4],
		[float(t15["s0"]) - 40.0, 17.0], [float(t15["s1"]) + 20.0, 11.0], [float(t16["s0"]), DOCK_Y + 0.3],
		[route_len + 50.0, DOCK_Y + 0.3],
	]
	var n: int = int(ceil(route_len)) + 2
	var raw := PackedFloat32Array()
	raw.resize(n)
	var j := 0
	for i in range(n):
		var s: float = float(i)
		while j < st.size() - 2 and s > float(st[j + 1][0]):
			j += 1
		var a: Array = st[j]
		var b: Array = st[j + 1]
		raw[i] = lerpf(float(a[1]), float(b[1]), clampf((s - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.01), 0.0, 1.0))
	# Smoothed (a box of 31m twice), except across the terrace's drop, which is added back sharp below.
	var cur := raw
	for _pass in range(2):
		var out := PackedFloat32Array()
		out.resize(n)
		for i in range(n):
			var acc := 0.0
			var cnt := 0
			for k in range(-15, 16):
				var ii: int = clampi(i + k, 0, n - 1)
				acc += cur[ii]
				cnt += 1
			out[i] = acc / float(cnt)
		cur = out
	# The terrace: level on top, the kicker, the drop at the wall, then on down (the smoothing spread the step: put it
	# back as a step at s_terrace).
	var top: float = CITY_Y + 23.3
	for i in range(n):
		var d: float = float(i) - s_terrace
		if d > -80.0 and d < 0.0:
			cur[i] = lerpf(cur[i], top, smoothstep(-80.0, -50.0, d))
		elif d >= 0.0 and d < 70.0:
			cur[i] = minf(lerpf(top - TERRACE_DROP, cur[i], smoothstep(0.0, 70.0, d)), top - TERRACE_DROP)
	# The features on top.
	for i in range(n):
		var s: float = float(i)
		var y: float = cur[i]
		# The moat bridge's crest (GardenKit.bridge_deck_y: rise * cos^2 over its length).
		var ml: float = float(MOAT_BRIDGE[0]) * PROP_SCALE
		y += float(MOAT_BRIDGE[1]) * PROP_SCALE * _cos2((s - s_moat) / ml)
		# The dips under the railway bridges.
		y -= 1.0 * _cos2((s - s_under1) / 90.0)
		# The pond bridge.
		var pl: float = float(POND_BRIDGE[0]) * PROP_SCALE
		y += float(POND_BRIDGE[1]) * PROP_SCALE * _cos2((s - s_pond) / pl)
		# The terrace's kicker: up TERRACE_KICK[1] over its length to the lip at s_terrace.
		var kd: float = s - (s_terrace - float(TERRACE_KICK[0]))
		if kd > 0.0 and s < s_terrace:
			var u: float = kd / float(TERRACE_KICK[0])
			y += float(TERRACE_KICK[1]) * u * u
		# The stairs below the lip: down their nosings over TERRACE_FACE metres.
		if s >= s_terrace and s < s_terrace + TERRACE_FACE:
			var top2: float = CITY_Y + 23.3 + float(TERRACE_KICK[1])
			y = lerpf(top2, cur[i], (s - s_terrace) / TERRACE_FACE)
		# The building site's kicker.
		var kk: float = s - (s_kicker - float(KICKER[0]))
		if kk > 0.0 and s < s_kicker + float(KICKER[2]):
			if s <= s_kicker:
				var u2: float = kk / float(KICKER[0])
				y += float(KICKER[1]) * (0.35 * u2 + 0.65 * u2 * u2)
			else:
				y += float(KICKER[1]) * (1.0 - (s - s_kicker) / float(KICKER[2]))
		# The table-top: up to its lip, level over the table, down a rounded landing slope.
		var td: float = s - (s_table - float(TABLE[0]))
		var t_end: float = s_table + float(TABLE[2]) + float(TABLE[3])
		if td > 0.0 and s < t_end:
			if s <= s_table:
				var u3: float = td / float(TABLE[0])
				y += float(TABLE[1]) * (0.35 * u3 + 0.65 * u3 * u3)
			elif s <= s_table + float(TABLE[2]):
				y += float(TABLE[1])
			else:
				var v3: float = (s - s_table - float(TABLE[2])) / float(TABLE[3])
				y += float(TABLE[1]) * 0.5 * (1.0 + cos(PI * v3))
		cur[i] = y
	_road_y = cur
	var steep := 0.0
	var at := 0.0
	for i in range(n - 1):
		var g: float = absf(cur[i + 1] - cur[i])
		if g > steep and (float(i) < s_terrace - 4.0 or float(i) > s_terrace + TERRACE_FACE + 4.0) and _jump_span_at(float(i), 4.0).is_empty():
			steep = g
			at = float(i)
	print("  route %.0fm, finish at %.0fm; road %.1f to %.1fm; steepest %.1f%% at %.0fm (off the jumps)" % [route_len, _finish_s, _min(cur), _max(cur), steep * 100.0, at])
	print("  moat %.0f, underpass %.0f, Ring %.0f, gate %.0f, Palmenhaus %.0f, pond %.0f, terrace %.0f, exit %.0f, underpass %.0f, ball %.0f, kicker %.0f, table-top %.0f, car park %.0f-%.0f, roller %.0f" % [
		s_moat, s_under1, s_ring, s_gate, s_palm, s_pond, s_terrace, s_exit, s_under2, s_ball, s_kicker, s_table, s_carpark0, s_carpark1, s_roller])


## The site's spoil jumps as [s where the heap starts, s where it ends]: the kicker and the table-top.
func _jump_spans() -> Array:
	return [[s_kicker - float(KICKER[0]), s_kicker + float(KICKER[2])],
		[s_table - float(TABLE[0]), s_table + float(TABLE[2]) + float(TABLE[3])]]


## The jump span s lies in (within `pad` of it), or [].
func _jump_span_at(s: float, pad := 0.0) -> Array:
	for sp in _jump_spans():
		if s > float(sp[0]) - pad and s < float(sp[1]) + pad:
			return sp
	return []


func _min(a: PackedFloat32Array) -> float:
	var m := INF
	for v in a:
		m = minf(m, v)
	return m


func _max(a: PackedFloat32Array) -> float:
	var m := -INF
	for v in a:
		m = maxf(m, v)
	return m


## The railway's rails' top at x: the city's level, rising past the Ring toward the garden.
func _rail_top(x: float) -> float:
	return 47.0 + 4.0 * smoothstep(-300.0, 840.0, x)


func _walled(x: float, pad := 0.0) -> bool:
	for w in WALLED:
		if x > float(w[0]) - pad and x < float(w[1]) + pad:
			return true
	return false


## The Ring's road height at z (over the plateau, down its ramp into the tunnel).
func _ring_y(z: float) -> float:
	return CITY_Y - RING_DROP * smoothstep(RING_RAMP_Z, RING_PORTAL_Z + 20.0, z)


# ======================================================================================
#  The natural ground
# ======================================================================================

func _init_noise() -> void:
	_noise.seed = 6101
	_noise.frequency = 0.004
	_noise.fractal_octaves = 4
	_hill_noise.seed = 6102
	_hill_noise.frequency = 0.0018
	_hill_noise.fractal_octaves = 4
	_forest_noise.seed = 6103
	_forest_noise.frequency = 0.005
	_forest_noise.fractal_octaves = 3


func _rect_weight(x: float, z: float, r: Array, blend: float) -> float:
	var dx: float = maxf(maxf(float(r[0]) - x, x - float(r[2])), 0.0)
	var dz: float = maxf(maxf(float(r[1]) - z, z - float(r[3])), 0.0)
	return 1.0 - smoothstep(0.0, blend, sqrt(dx * dx + dz * dz))


func _in_rect(x: float, z: float, r: Array, pad := 0.0) -> bool:
	return x > float(r[0]) - pad and x < float(r[2]) + pad and z > float(r[1]) - pad and z < float(r[3]) + pad


## The terrace edge's line (z) at x: south of it the ground falls to the docks.
func _edge_z(x: float) -> float:
	return lerpf(400.0, 205.0, clampf(x / 800.0, 0.0, 1.0))


## How far into the docks (0 on the plateau, 1 on the docks' plain).
func _dock_w(x: float, z: float) -> float:
	var e: float = _edge_z(x)
	return smoothstep(e - 70.0, e + 70.0, z)


func _hill(x: float, z: float) -> float:
	var d: float = Vector2(x, z).distance_to(HILL_C)
	if d > HILL_R:
		return 0.0
	var u: float = d / HILL_R
	var c: float = cos(u * PI * 0.5)
	return HILL_H * c * c * (1.0 + 0.12 * _hill_noise.get_noise_2d(x, z))


func _raw_natural(x: float, z: float) -> float:
	var plateau: float = CITY_Y - 0.3 + 0.8 * _noise.get_noise_2d(x, z) + _hill(x, z)
	# The far country: low hills round the city, the Ruhr's other towns beyond.
	var far: float = smoothstep(1400.0, 3600.0, Vector2(x - 100.0, z - 300.0).length())
	plateau += far * (18.0 + 22.0 * _hill_noise.get_noise_2d(x * 0.6 + 300.0, z * 0.6))
	var docks: float = DOCK_Y - 0.2 + 0.25 * _noise.get_noise_2d(x * 2.0, z * 2.0)
	var h: float = lerpf(plateau, docks, _dock_w(x, z))
	return h


## The natural ground with the moat, the pond, the canal and the railway's earth embankment.
func _natural(x: float, z: float) -> float:
	var h: float = _raw_natural(x, z)
	# The moat: grassy banks down to its water and a little under.
	if x > MOAT_X.x - 30.0 and x < MOAT_X.y + 30.0:
		var dz: float = absf(z - MOAT_Z)
		var ends: float = smoothstep(MOAT_X.x - 30.0, MOAT_X.x, x) * (1.0 - smoothstep(MOAT_X.y, MOAT_X.y + 30.0, x))
		var bank: float = lerpf(MOAT_BED, h, smoothstep(MOAT_HALF - 4.0, MOAT_HALF + 13.0, dz))
		h = lerpf(h, minf(h, bank), ends)
	# The lily pond.
	var pq: Vector2 = (Vector2(x, z) - POND_C) / POND_R
	var pd: float = pq.length()
	if pd < 1.6:
		var bed: float = _pond_level() - 1.0
		h = lerpf(bed, h, smoothstep(0.75, 1.5, pd))
	# The canal.
	var dzc: float = absf(z - CANAL_Z)
	if dzc < CANAL_HALF:
		h = minf(h, lerpf(CANAL_BED, DOCK_Y, clampf((dzc - (CANAL_HALF - 8.0)) / 8.0, 0.0, 1.0)))
	# The railway's earth embankment (not where it is walled).
	if x > RAIL_X.x and x < RAIL_X.y:
		var dr: float = absf(z - RAIL_Z)
		if dr < 60.0:
			var top: float = _rail_top(x) - EMBANK_UNDER
			var ridge: float = top - maxf(dr - 6.5, 0.0) * 0.62
			var wall: float = 0.0
			for w in WALLED:
				var e: float = minf(x - float(w[0]), float(w[1]) - x)
				wall = maxf(wall, 1.0 - smoothstep(-4.0, 6.0, -e))
			if x > -1100.0 and x < -760.0:
				wall = 1.0
			h = lerpf(maxf(h, ridge), h, wall)
	return h


var _pond_y := 0.0

func _pond_level() -> float:
	return _pond_y


# ======================================================================================
#  The pads: level ground for the sites and squares ([x0, z0, x1, z1], blend, height from the natural ground's mean)
# ======================================================================================

const PADS := [
	["kaiserplatz", [-1230.0, -40.0, -940.0, 70.0], 16.0],
	["parterre", [130.0, -250.0, 285.0, -150.0], 14.0],
	["palmenhaus", [262.0, -372.0, 338.0, -246.0], 12.0],
	["belvedere", [858.0, -496.0, 908.0, -444.0], 10.0],
	# Behind the terrace's retaining walls (`_build_terrace`), cut off inside them by `_terrace_cut`.
	["terrace", [797.0, -440.0, 883.0, -329.5], 8.0],
	# The lawn at the walls' foot, level with the steps' bottom: the hillside rose against the walls and buried half
	# their face. It starts at `_terrace_cut`'s far line (zero on its near one).
	["terrace_below", [797.0, -330.0, 883.0, -318.0], 12.0],
	["demolition", [380.0, 370.0, 700.0, 520.0], 30.0],
	["scrapyard", [-60.0, 600.0, 400.0, 760.0], 30.0],
	["building_site", [-620.0, 800.0, 40.0, 1000.0], 30.0],
	["gasworks", [-1000.0, 860.0, -640.0, 1050.0], 30.0],
]
var _pad_y := {}
## The terrace pad's edge (z): full height to x, none from y.
var _terrace_cut := Vector2(-330.0, -328.6)
## The route's x at the terrace's drop, and the height between the road on the terrace and the road below it.
var _terrace_x := 840.0
var _terrace_mid_y := 55.0


func _plan_pads() -> void:
	for p in PADS:
		var r: Array = p[1]
		var acc := 0.0
		var cnt := 0
		var x: float = float(r[0])
		while x <= float(r[2]):
			var z: float = float(r[1])
			while z <= float(r[3]):
				acc += _raw_natural(x, z)
				cnt += 1
				z += 10.0
			x += 10.0
		_pad_y[p[0]] = acc / float(maxi(cnt, 1))
	# The palm house and the parterre sit at the route's own height there.
	_pad_y["parterre"] = _lap_y(_closest_s(Vector2(210.0, -200.0))) - GROUND_UNDER
	_pad_y["palmenhaus"] = _lap_y(s_palm) - GROUND_UNDER
	_pad_y["belvedere"] = CITY_Y + 23.3 - 0.2
	# The terrace is level with its walls' coping (10cm under it) and ends between their back face (0.9m behind the
	# walls' line) and their front face (1.0m before it), on grid lines of its own (`_build_heights`): on the 5m grid
	# alone its edge sloped across a cell, over the walls' face or down behind them. The route runs due south there.
	_pad_y["terrace"] = CITY_Y + 23.3 - 0.1
	_pad_y["terrace_below"] = CITY_Y + 23.3 - TERRACE_DROP - 0.1
	var wz: float = _pt(s_terrace + 0.5).z
	_terrace_cut = Vector2(wz - 0.5, wz + 0.9)
	_terrace_x = _pt(s_terrace).x
	_terrace_mid_y = CITY_Y + 23.3 - TERRACE_DROP * 0.5
	if absf((_spot(s_terrace + 0.5, 0.0, 0.0)["fwd"] as Vector3).z) < 0.99:
		push_error("Stadtrallye: the route doesn't run north-south at the terrace; its pad's cut assumes it does")
	for k in ["demolition", "scrapyard", "building_site", "gasworks"]:
		_pad_y[k] = DOCK_Y + 0.25
	_pad_y["kaiserplatz"] = CITY_Y - GROUND_UNDER
	print("  pads: %s" % str(_pad_y))


func _pads(x: float, z: float, h: float) -> float:
	for p in PADS:
		var w: float = _rect_weight(x, z, p[1], float(p[2]))
		if w > 0.0 and p[0] == "terrace":
			w *= 1.0 - clampf((z - _terrace_cut.x) / (_terrace_cut.y - _terrace_cut.x), 0.0, 1.0)
		elif w > 0.0 and p[0] == "terrace_below":
			w *= clampf((z - _terrace_cut.x) / (_terrace_cut.y - _terrace_cut.x), 0.0, 1.0)
		if w > 0.0:
			h = lerpf(h, float(_pad_y[p[0]]), w)
	return h


# ======================================================================================
#  The grading
# ======================================================================================

## The bridges' spans: [middle (xz), along (xz, unit), half length]; see `_add_samples`.
var _deck_zones: Array = []


## A run of road samples (a polyline): position (its road's height), right, the flat band's half width.
func _add_run(pts: Array, rights: Array, flats: Array) -> void:
	var first: int = _rs_pos.size()
	for k in range(pts.size()):
		var p: Vector3 = pts[k]
		_rs_pos.append(p)
		_rs_right.append(rights[k])
		_rs_flat.append(flats[k])
		_rs_next.append(first + k + 1 if k < pts.size() - 1 else -1)
		var key := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
		if not _rs_cells.has(key):
			_rs_cells[key] = PackedInt32Array()
		var arr: PackedInt32Array = _rs_cells[key]
		arr.append(first + k)
		_rs_cells[key] = arr


func _add_samples() -> void:
	var kinds: Array = _road_kinds()
	var pts: Array = []
	var rights: Array = []
	var flats: Array = []
	var s := 0.0
	while s <= route_len:
		var p: Vector3 = _pt(s)
		# Under the jumps' lips the ground keeps to the lowest road near it, so it never stands over the road's drop.
		var span: Array = _jump_span_at(s, 3.0)
		if absf(s - s_terrace) < 8.0:
			var lo: float = p.y
			for k in range(-6, 7):
				lo = minf(lo, _lap_y(s + float(k)))
			p.y = lo
		elif not span.is_empty():
			# Under the spoil jumps the ground stays at the road's level either side of them: their heaps' sides are
			# meshes of their own (`_build_spoil_jumps`), which a 5m grid can't hold. Graded up under the run-up, the
			# kicker had stood as a sheet of road over a low bank with no sides.
			p.y = minf(_lap_y(float(span[0]) - 4.0), _lap_y(float(span[1]) + 4.0))
		pts.append(p)
		rights.append(_rt(s))
		var w: float = _half_at(s)
		if absf(s - s_ring) < RING_HALF + 4.0:
			w = ROAD_HALF + PAVEMENT
		# The pedestrian zone's paving runs out to the shop fronts.
		if _kind_at(kinds, s) == 14:
			w = PED_FRONT - 1.0
		# Over the bridges' spans the ground is left to the water (the bridge stands over it).
		var deck: bool = absf(s - s_moat) < float(MOAT_BRIDGE[0]) * PROP_SCALE * 0.5 - 5.0 or absf(s - s_pond) < float(POND_BRIDGE[0]) * PROP_SCALE * 0.5 - 4.0
		flats.append(-1.0 if deck else w + 1.6)
		s += SAMPLE_STEP
	_add_run(pts, rights, flats)
	_route_rs = _rs_pos.size()
	# The bridges' spans as boxes the route leaves to the natural ground (`_grade`): leaving the deck samples out wasn't
	# enough, since the last graded segment's flat band and shoulders wrapped round its end 12m and more into the span
	# and dammed the moat and the pond, burying the side arches.
	_deck_zones.clear()
	for dzn in [[s_moat, float(MOAT_BRIDGE[0]) * PROP_SCALE * 0.5 - 5.0], [s_pond, float(POND_BRIDGE[0]) * PROP_SCALE * 0.5 - 4.0]]:
		var c: Vector3 = _pt(float(dzn[0]))
		var f: Vector3 = _spot(float(dzn[0]), 0.0, 0.0)["fwd"]
		_deck_zones.append([Vector2(c.x, c.z), Vector2(f.x, f.z).normalized(), float(dzn[1])])
	# The Ring, from the north to its tunnel's portal.
	pts = []
	rights = []
	flats = []
	var z: float = RING_Z0
	while z <= RING_PORTAL_Z:
		pts.append(Vector3(RING_X, _ring_y(z), z))
		rights.append(Vector3(-1, 0, 0))
		flats.append(RING_HALF + 1.5)
		z += SAMPLE_STEP
	_add_run(pts, rights, flats)


## The ground graded to the roads: level with them (GROUND_UNDER under) across the flat band, then rounded shoulders out
## to the natural ground. Returns the height and the distance to the nearest road's line.
func _grade(h: float, x: float, z: float) -> Vector2:
	var cx: int = floori(x / CELL)
	var cz: int = floori(z / CELL)
	var upper := 1e9
	var lower := -1e9
	var touched := false
	var flat_y := NAN
	var flat_lat := 1e9
	var best_d := 1e9
	# Within a bridge's span (along it, and GRADE_REACH either side) the route doesn't grade the ground.
	var on_deck := false
	for dzn in _deck_zones:
		var q: Vector2 = Vector2(x, z) - (dzn[0] as Vector2)
		var f: Vector2 = dzn[1]
		if absf(q.dot(f)) < float(dzn[2]) and absf(q.dot(Vector2(-f.y, f.x))) < GRADE_REACH:
			on_deck = true
	# Beside the terrace's drop (outside the road's own width) the terrace is graded only from the road up on it and
	# the lawn below only from the road below (the lip's samples, lowered under it, count as below): graded from both,
	# the lawn rose in a bank half up the retaining walls.
	# Only round the walls (34m out from the road's edge): at 90 x 70m it took in the Alpinum's last hairpin (x 745-775),
	# whose road, under the terrace's height, then no longer graded the ground under it, and the bots stuck there.
	var terrace_side := 0
	var dxt: float = absf(x - _terrace_x)
	if dxt > ROAD_HALF + 0.5 and dxt < ROAD_HALF + 0.3 + 34.0 + 8.0 and absf(z - _terrace_cut.x) < 36.0:
		terrace_side = 1 if z <= _terrace_cut.x + 0.05 else -1
	for gz in range(cz - 2, cz + 3):
		for gx in range(cx - 2, cx + 3):
			var bucket: PackedInt32Array = _rs_cells.get(Vector2i(gx, gz), PackedInt32Array())
			for i in bucket:
				if _rs_flat[i] < 0.0 or (on_deck and i < _route_rs):
					continue
				if terrace_side != 0 and i < _route_rs and (terrace_side > 0) != (_rs_pos[i].y > _terrace_mid_y):
					continue
				var j: int = _rs_next[i]
				var a: Vector3 = _rs_pos[i]
				var dx: float = x - a.x
				var dz: float = z - a.z
				if dx * dx + dz * dz > GRADE_REACH * GRADE_REACH:
					continue
				var b: Vector3 = _rs_pos[j] if j >= 0 else a
				var sx: float = b.x - a.x
				var sz: float = b.z - a.z
				var l2: float = sx * sx + sz * sz
				var t: float = clampf((dx * sx + dz * sz) / l2, 0.0, 1.0) if l2 > 1e-6 else 0.0
				var fx: float = x - (a.x + sx * t)
				var fz: float = z - (a.z + sz * t)
				var lateral: float = sqrt(fx * fx + fz * fz)
				best_d = minf(best_d, lateral)
				var foot_y: float = lerpf(a.y, b.y, t) - GROUND_UNDER
				var flat: float = _rs_flat[i]
				var over: float = maxf(0.0, lateral - flat)
				var soft: float = over * over / (over + 5.0)
				upper = minf(upper, foot_y + soft * 0.8)
				lower = maxf(lower, foot_y - soft * 0.65)
				touched = true
				if lateral <= flat and lateral < flat_lat:
					flat_lat = lateral
					flat_y = foot_y
	if not touched:
		return Vector2(h, best_d)
	if not is_nan(flat_y):
		return Vector2(flat_y, best_d)
	var res: float = upper if lower > upper else clampf(h, lower, upper)
	return Vector2(res, best_d)


# ======================================================================================
#  The terrain
# ======================================================================================

func _grid_axis(fine: Vector2) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var left := PackedFloat32Array()
	var step: float = FINE_STEP
	var x: float = fine.x
	while x > -OUTER:
		step = minf(step * COARSE_GROWTH, COARSE_MAX)
		x -= step
		left.append(maxf(x, -OUTER))
	left.reverse()
	out.append_array(left)
	var n: int = int(round((fine.y - fine.x) / FINE_STEP))
	for i in range(n + 1):
		out.append(fine.x + float(i) * FINE_STEP)
	step = FINE_STEP
	x = fine.y
	while x < OUTER:
		step = minf(step * COARSE_GROWTH, COARSE_MAX)
		x += step
		out.append(minf(x, OUTER))
	return out


## `axis` (sorted) with a line at `v`, unless one lies within 20cm of it.
func _with_line(axis: PackedFloat32Array, v: float) -> PackedFloat32Array:
	for a in axis:
		if absf(a - v) < 0.2:
			return axis
	var out := PackedFloat32Array()
	var placed := false
	for a in axis:
		if not placed and a > v:
			out.append(v)
			placed = true
		out.append(a)
	if not placed:
		out.append(v)
	return out


func _build_heights() -> void:
	_grid_x = _grid_axis(FINE_X)
	_grid_z = _grid_axis(FINE_Z)
	# The terrace's edge on lines of its own, so its step stays inside the retaining walls.
	for zz in [_terrace_cut.x, _terrace_cut.y]:
		_grid_z = _with_line(_grid_z, zz)
	var nx: int = _grid_x.size()
	var nz: int = _grid_z.size()
	print("  terrain grid %d x %d = %d vertices" % [nx, nz, nx * nz])
	_heights.resize(nx * nz)
	_road_d.resize(nx * nz)
	for iz in range(nz):
		var z: float = _grid_z[iz]
		for ix in range(nx):
			var x: float = _grid_x[ix]
			var i: int = iz * nx + ix
			var h: float = _pads(x, z, _natural(x, z))
			var near: bool = x > FINE_X.x - 60.0 and x < FINE_X.y + 60.0 and z > FINE_Z.x - 60.0 and z < FINE_Z.y + 60.0
			if not near:
				_heights[i] = h
				_road_d[i] = 1e9
				continue
			var g: Vector2 = _grade(h, x, z)
			_heights[i] = g.x
			_road_d[i] = minf(g.y, 1.0e7)


## Ground height at any (x, z) on the mesh's own triangles (each cell split along the diagonal joining its closer heights).
func _ground_at(x: float, z: float) -> float:
	var ix: int = _bsearch(_grid_x, x)
	var iz: int = _bsearch(_grid_z, z)
	var nx: int = _grid_x.size()
	var x0: float = _grid_x[ix]
	var x1: float = _grid_x[ix + 1]
	var z0: float = _grid_z[iz]
	var z1: float = _grid_z[iz + 1]
	var tx: float = clampf((x - x0) / (x1 - x0), 0.0, 1.0)
	var tz: float = clampf((z - z0) / (z1 - z0), 0.0, 1.0)
	var h00: float = _heights[iz * nx + ix]
	var h10: float = _heights[iz * nx + ix + 1]
	var h01: float = _heights[(iz + 1) * nx + ix]
	var h11: float = _heights[(iz + 1) * nx + ix + 1]
	if absf(h00 - h11) <= absf(h10 - h01):
		if tx >= tz:
			return h00 + (h10 - h00) * tx + (h11 - h10) * tz
		return h00 + (h11 - h01) * tx + (h01 - h00) * tz
	if tx + tz <= 1.0:
		return h00 + (h10 - h00) * tx + (h01 - h00) * tz
	return h11 + (h01 - h11) * (1.0 - tx) + (h10 - h11) * (1.0 - tz)


func _bsearch(arr: PackedFloat32Array, v: float) -> int:
	var lo := 0
	var hi: int = arr.size() - 2
	while lo < hi:
		var mid: int = (lo + hi + 1) >> 1
		if arr[mid] <= v:
			lo = mid
		else:
			hi = mid - 1
	return clampi(lo, 0, arr.size() - 2)


## The lowest and highest ground under a footprint (w x d at c, turned yaw), sampled every 2m.
func _ground_range(c: Vector2, w: float, d: float, yaw: float) -> Vector2:
	var lo := INF
	var hi := -INF
	var ax := Vector2(cos(yaw), -sin(yaw))
	var az := Vector2(sin(yaw), cos(yaw))
	var nx: int = maxi(2, ceili(w / 2.0))
	var nz: int = maxi(2, ceili(d / 2.0))
	for i in range(nx + 1):
		for j in range(nz + 1):
			var p: Vector2 = c + ax * (float(i) / float(nx) - 0.5) * w + az * (float(j) / float(nz) - 0.5) * d
			var g: float = _ground_at(p.x, p.y)
			lo = minf(lo, g)
			hi = maxf(hi, g)
	return Vector2(lo, hi)


## Inside the city (the plateau west of the Ring, short of the moat's park and the docks).
func _in_city(x: float, z: float) -> bool:
	return x < RING_X - RING_HALF + 4.0 and z < _edge_z(x) - 60.0 and z > -700.0


func _in_moat_park(x: float, z: float) -> bool:
	return x > MOAT_X.x - 20.0 and x < MOAT_X.y + 20.0 and absf(z - MOAT_Z) < MOAT_HALF + 26.0


## Vertex masks: COLOR (R stone, G docks' ground, B lawn, A bed soil) and UV2 (x mud, y city paving).
func _masks(i: int, x: float, z: float, nrm_y: float) -> Array:
	var road_d: float = _road_d[i]
	var off_road: float = smoothstep(8.6, 10.5, road_d)
	var rock: float = (1.0 - smoothstep(0.66, 0.82, nrm_y)) * smoothstep(9.0, 12.0, road_d)
	# The Alpinum: limestone breaking through the turf between the hairpins.
	if x > 590.0 and x < 815.0 and z > -452.0 and z < -350.0:
		rock = maxf(rock, smoothstep(0.86, 0.72, nrm_y) * off_road * 0.95)
	var docks: float = smoothstep(0.35, 0.8, _dock_w(x, z))
	# The canal's stone-pitched banks.
	if absf(z - CANAL_Z) < CANAL_HALF + 1.0 and _heights[i] < DOCK_Y - 0.4:
		rock = maxf(rock, 0.85)
	var garden: float = _rect_weight(x, z, GARDEN_RECT, 4.0)
	var lawn: float = garden * off_road
	if _in_moat_park(x, z):
		lawn = maxf(lawn, off_road)
	var soil: float = garden * off_road * smoothstep(0.18, 0.35, _forest_noise.get_noise_2d(x, z)) * 0.8
	var mud: float = 0.0
	for k in ["building_site", "scrapyard", "demolition"]:
		for p in PADS:
			if p[0] == k:
				mud = maxf(mud, _rect_weight(x, z, p[1], 14.0) * (0.55 + 0.45 * smoothstep(-0.2, 0.3, _noise.get_noise_2d(x * 3.0, z * 3.0))))
	mud *= off_road * (1.0 - rock)
	var paving: float = 0.0
	if _in_city(x, z) and not _in_moat_park(x, z):
		paving = 1.0 - smoothstep(19.0, 22.0, road_d)
		if absf(z - 270.0) < 21.0 and x > -640.0 and x < -330.0:
			paving = 1.0
	for k in ["kaiserplatz"]:
		for p in PADS:
			if p[0] == k:
				paving = maxf(paving, _rect_weight(x, z, p[1], 3.0))
	if x > -1010.0 and x < -790.0 and z > -36.0 and z < -8.0:
		paving = 1.0
	return [Color(rock, docks * (1.0 - rock) * (1.0 - mud), lawn * (1.0 - rock), soil * (1.0 - rock)), Vector2(mud, paving * (1.0 - rock))]


const BODIES := [
	["StadtWiese", "grass", Color(0, 0, 0, 0)],
	["HafenGrund", "gravel", Color(0.36, 0.33, 0.31, 0.6)],
	["StadtFels", "rock", Color(0.66, 0.64, 0.60, 0.5)],
	["BaustellenMatsch", "mud", Color(0.40, 0.31, 0.22, 0.7)],
	["StadtPflaster", "asphalt", Color(0.55, 0.54, 0.52, 0.4)],
]


func _build_terrain(parent: Node3D) -> void:
	var nx: int = _grid_x.size()
	var nz: int = _grid_z.size()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	verts.resize(nx * nz)
	normals.resize(nx * nz)
	colors.resize(nx * nz)
	uvs.resize(nx * nz)
	uv2s.resize(nx * nz)
	for iz in range(nz):
		for ix in range(nx):
			var i: int = iz * nx + ix
			var x: float = _grid_x[ix]
			var z: float = _grid_z[iz]
			verts[i] = Vector3(x, _heights[i], z)
			uvs[i] = Vector2(x, z)
			var ixl: int = maxi(ix - 1, 0)
			var ixr: int = mini(ix + 1, nx - 1)
			var izd: int = maxi(iz - 1, 0)
			var izu: int = mini(iz + 1, nz - 1)
			var dhdx: float = (_heights[iz * nx + ixr] - _heights[iz * nx + ixl]) / maxf(_grid_x[ixr] - _grid_x[ixl], 0.01)
			var dhdz: float = (_heights[izu * nx + ix] - _heights[izd * nx + ix]) / maxf(_grid_z[izu] - _grid_z[izd], 0.01)
			var nrm := Vector3(-dhdx, 1.0, -dhdz).normalized()
			normals[i] = nrm
			if _road_d[i] < 1e8:
				var m: Array = _masks(i, x, z, nrm.y)
				colors[i] = m[0]
				uv2s[i] = m[1]
			else:
				var dock: float = smoothstep(0.35, 0.8, _dock_w(x, z))
				colors[i] = Color(1.0 - smoothstep(0.6, 0.8, nrm.y), dock, 0.0, 0.0)
				uv2s[i] = Vector2.ZERO
	var near_idx := PackedInt32Array()
	var far_idx := PackedInt32Array()
	var faces: Array = []
	for b in BODIES:
		faces.append(PackedVector3Array())
	for iz in range(nz - 1):
		for ix in range(nx - 1):
			var i: int = iz * nx + ix
			var a: int = i
			var b: int = i + 1
			var c: int = i + nx
			var d: int = i + nx + 1
			var tris: Array
			if absf(_heights[a] - _heights[d]) <= absf(_heights[b] - _heights[c]):
				tris = [[a, b, d], [a, d, c]]
			else:
				tris = [[a, b, c], [b, d, c]]
			for tri in tris:
				var p0: Vector3 = verts[tri[0]]
				var p1: Vector3 = verts[tri[1]]
				var p2: Vector3 = verts[tri[2]]
				if (p2 - p0).cross(p1 - p0).y < 0.0:
					tri = [tri[0], tri[2], tri[1]]
					p1 = verts[tri[1]]
					p2 = verts[tri[2]]
				var far := false
				for k in range(3):
					var v: Vector3 = verts[tri[k]]
					if v.x < FINE_X.x or v.x > FINE_X.y or v.z < FINE_Z.x or v.z > FINE_Z.y:
						far = true
				if far:
					far_idx.append_array([tri[0], tri[1], tri[2]])
				else:
					near_idx.append_array([tri[0], tri[1], tri[2]])
				var cen: Vector3 = (p0 + p1 + p2) / 3.0
				if absf(cen.x - 100.0) > 2600.0 or absf(cen.z - 300.0) > 2600.0:
					continue
				var cc: Color = (colors[tri[0]] + colors[tri[1]] + colors[tri[2]]) / 3.0
				var c2: Vector2 = (uv2s[tri[0]] + uv2s[tri[1]] + uv2s[tri[2]]) / 3.0
				var k: int = 0
				if cc.r > 0.6:
					k = 2
				elif c2.x > 0.45:
					k = 3
				elif cc.g > 0.5:
					k = 1
				elif c2.y > 0.5:
					k = 4
				var f: PackedVector3Array = faces[k]
				f.append(p0)
				f.append(p1)
				f.append(p2)
				faces[k] = f
	var near_mesh: ArrayMesh = _compact_mesh(verts, normals, colors, uvs, uv2s, near_idx, _ground_mat)
	var inst := MeshInstance3D.new()
	inst.name = "StadtGroundMesh"
	inst.mesh = _save_res(near_mesh, "ground_visual")
	parent.add_child(inst)
	var far_mesh: ArrayMesh = _compact_mesh(verts, normals, colors, uvs, uv2s, far_idx, _ground_mat)
	var far_inst := MeshInstance3D.new()
	far_inst.name = "StadtFarGround"
	far_inst.mesh = _save_res(far_mesh, "far_ground", FAR_PREFIX)
	far_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(far_inst)
	for k in range(BODIES.size()):
		var f: PackedVector3Array = faces[k]
		if f.is_empty():
			continue
		var body := StaticBody3D.new()
		body.name = BODIES[k][0]
		body.set_meta(&"surface", BODIES[k][1])
		if (BODIES[k][2] as Color).a > 0.0:
			body.set_meta(&"dust_color", BODIES[k][2])
		parent.add_child(body)
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(f)
		shape.backface_collision = true
		var cs := CollisionShape3D.new()
		cs.name = "Shape"
		cs.shape = _save_res(shape, String(BODIES[k][0]).to_snake_case() + "_shape")
		body.add_child(cs)
	print("  ground: %d near and %d far triangles" % [near_idx.size() / 3, far_idx.size() / 3])


func _compact_mesh(verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, uvs: PackedVector2Array,
		uv2s: PackedVector2Array, idx: PackedInt32Array, mat: Material) -> ArrayMesh:
	var remap := PackedInt32Array()
	remap.resize(verts.size())
	remap.fill(-1)
	var nv := PackedVector3Array()
	var nn := PackedVector3Array()
	var nc := PackedColorArray()
	var nu := PackedVector2Array()
	var nu2 := PackedVector2Array()
	var ni := PackedInt32Array()
	ni.resize(idx.size())
	for k in range(idx.size()):
		var v: int = idx[k]
		if remap[v] < 0:
			remap[v] = nv.size()
			nv.append(verts[v])
			nn.append(normals[v])
			nc.append(colors[v])
			nu.append(uvs[v])
			nu2.append(uv2s[v])
		ni[k] = remap[v]
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = nv
	arrays[Mesh.ARRAY_NORMAL] = nn
	arrays[Mesh.ARRAY_COLOR] = nc
	arrays[Mesh.ARRAY_TEX_UV] = nu
	arrays[Mesh.ARRAY_TEX_UV2] = nu2
	arrays[Mesh.ARRAY_INDEX] = ni
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, mat)
	return mesh


# ======================================================================================
#  The roads
# ======================================================================================

## [s0, s1, kind] along the route (stadt_road.gdshader's kinds; -1: no ribbon, the Ring's own carries the route across).
var _kinds_cache: Array = []

func _road_kinds() -> Array:
	if not _kinds_cache.is_empty():
		return _kinds_cache
	var t2: Dictionary = _turn(2)
	var t3: Dictionary = _turn(3)
	var t16: Dictionary = _turn(16)
	var t18: Dictionary = _turn(18)
	var t19: Dictionary = _turn(19)
	var pb: float = float(POND_BRIDGE[0]) * PROP_SCALE * 0.5 + 2.0
	var palm_half: float = 32.0 * PROP_SCALE + 3.0
	_kinds_cache = [
		[0.0, s_moat - 42.0, 2],
		[s_moat - 42.0, s_moat + 42.0, 1],
		[s_moat + 42.0, float(t2["s1"]) + 8.0, 2],
		[float(t2["s1"]) + 8.0, float(t3["s0"]) - 8.0, 14],
		[float(t3["s0"]) - 8.0, s_ring - RING_HALF, 2],
		[s_ring - RING_HALF, s_ring + RING_HALF, -1],
		[s_ring + RING_HALF, s_gate + 4.0, 2],
		[s_gate + 4.0, s_palm - palm_half, 10],
		[s_palm - palm_half, s_palm + palm_half, 12],
		[s_palm + palm_half, s_pond - pb, 10],
		[s_pond - pb, s_pond + pb, 1],
		[s_pond + pb, s_exit, 10],
		[s_exit, float(t16["s0"]) - 20.0, 8],
		[float(t16["s0"]) - 20.0, s_ball + 140.0, 11],
		[s_ball + 140.0, float(t18["s0"]), 3],
		[float(t18["s0"]), float(t19["s0"]), 13],
		[float(t19["s0"]), _closest_s(Vector2(-30.0, 890.0)), 3],
		[_closest_s(Vector2(-30.0, 890.0)), s_carpark0 - 6.0, 11],
		[s_carpark0 - 6.0, s_carpark1 + 6.0, 4],
		[s_carpark1 + 6.0, _finish_s - 70.0, 11],
		[_finish_s - 70.0, route_len + 1.0, 5],
	]
	return _kinds_cache


func _kind_at(kinds: Array, s: float) -> int:
	for k in kinds:
		if s >= float(k[0]) and s < float(k[1]):
			return int(k[2])
	return 2


## The ribbon's half width at s: the carriageway and, in town, its pavements.
func _half_at(s: float) -> float:
	var kind: int = _kind_at(_road_kinds(), s)
	if kind == 2 or kind == 14:
		return ROAD_HALF + PAVEMENT
	if kind == 1:
		return ROAD_HALF + PAVEMENT if s < s_ring else ROAD_HALF
	if kind == 5:
		return ROAD_HALF + 1.5
	if kind == -1:
		return ROAD_HALF + PAVEMENT
	return ROAD_HALF


## Which body a kind's triangles go into (its surface).
const ROUTE_BODIES := {
	"CityRoad": ["asphalt", [1, 2, 3, 4, 5, 8, 12, 14]],
	"GartenwegTrack": ["gravel", [10]],
	"BaustrasseTrack": ["dirt", [11]],
	"SchrottplatzTrack": ["gravel", [13]],
}
var _route_faces := {}


func _road_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://stadt_road.gdshader")
	m.set_shader_parameter("asphalt_tex", load("res://materials/asphalt.png"))
	m.set_shader_parameter("sett_tex", load("res://materials/cobblestone.png"))
	m.set_shader_parameter("sett_normal", load("res://materials/cobblestone_normal.png"))
	m.set_shader_parameter("concrete_tex", load("res://materials/concrete.png"))
	m.set_shader_parameter("gravel_tex", load("res://materials/dark_canyon_rock.png"))
	m.set_shader_parameter("dirt_tex", load("res://materials/dirt.png"))
	m.set_shader_parameter("dirt_normal", load("res://materials/dirt_normal.png"))
	m.set_shader_parameter("cross_z", RING_CROSS.y)
	m.set_shader_parameter("cross_half", ROAD_HALF)
	return _save_res(m, "road_material") as ShaderMaterial


func _build_roads(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Roads"
	root.add_child(node)
	for k in ROUTE_BODIES.keys():
		_route_faces[k] = PackedVector3Array()
	var kinds: Array = _road_kinds()
	var bounds: Array = []
	for k in kinds:
		bounds.append(float(k[0]))
	var piece := 0
	for sec in kinds:
		var s0: float = sec[0]
		var s1: float = minf(float(sec[1]), route_len)
		var kind: int = sec[2]
		if s1 - s0 < 0.5 or kind < 0:
			continue
		var body_key := ""
		for bk in ROUTE_BODIES.keys():
			if (ROUTE_BODIES[bk][1] as Array).has(kind):
				body_key = bk
		var n_steps: int = maxi(1, ceili(s1 - s0))
		# This section's solid triangles. A PackedVector3Array is copied when read out of the dictionary: appending
		# through `_route_faces[key] as PackedVector3Array` filled a copy, and the route had no road collision at all.
		var sec_faces := PackedVector3Array()
		var r0 := 0
		while r0 < n_steps:
			var r1: int = mini(r0 + 48, n_steps)
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in range(r0, r1):
				var sa: float = lerpf(s0, s1, float(i) / float(n_steps))
				var sb: float = lerpf(s0, s1, float(i + 1) / float(n_steps))
				var w: float = _half_at((sa + sb) * 0.5)
				var lats: Array = [-w, -ROAD_HALF, -ROAD_HALF * 0.5, 0.0, ROAD_HALF * 0.5, ROAD_HALF, w] if w > ROAD_HALF + 0.1 else [-w, -w * 0.5, 0.0, w * 0.5, w]
				# Over the terrace's stairs the ribbon is solid but not drawn: the stairs are.
				var drawn: bool = not ((sa + sb) * 0.5 > s_terrace and (sa + sb) * 0.5 < s_terrace + TERRACE_FACE)
				for j in range(lats.size() - 1):
					var quad: Array = [[sa, lats[j]], [sa, lats[j + 1]], [sb, lats[j]], [sb, lats[j + 1]]]
					for t in [[0, 2, 1], [1, 2, 3]]:
						for k in t:
							var sv: float = quad[k][0]
							var lv: float = quad[k][1]
							var pos: Vector3 = _pt(sv) + _rt(sv) * lv
							var edge: float = INF
							for bb in bounds:
								edge = minf(edge, absf(sv - float(bb)))
							if kind == 14 or kind == 10 or kind == 11 or kind == 12:
								edge = INF
							var fwd: Vector3 = (_pt(sv + 0.5) - _pt(sv - 0.5)).normalized()
							st.set_normal(_rt(sv).cross(fwd).normalized())
							st.set_color(Color(clampf(edge / 4.0, 0.0, 1.0), 0.0, 0.0, 1.0))
							st.set_uv(Vector2(lv, sv))
							st.set_uv2(Vector2(float(kind), ROAD_HALF))
							if drawn:
								st.add_vertex(pos)
							if body_key != "":
								sec_faces.append(pos)
			var mesh: ArrayMesh = st.commit()
			mesh.surface_set_material(0, _road_mat)
			var mi := MeshInstance3D.new()
			mi.name = "Road_%d" % piece
			mi.mesh = _save_res(mesh, "road_%d" % piece, ROAD_PREFIX)
			node.add_child(mi)
			piece += 1
			r0 = r1
		if body_key != "":
			var all_faces: PackedVector3Array = _route_faces[body_key]
			all_faces.append_array(sec_faces)
			_route_faces[body_key] = all_faces
	_build_ring_road(node)
	print("  roads: %d pieces" % piece)


## The Ring's ribbon: from the north to just inside its tunnel, the tram median, the lanes and pavements (kind 9).
func _build_ring_road(node: Node3D) -> void:
	var faces := PackedVector3Array()
	var lats: Array = [-RING_HALF, -RING_CARR, -11.1, -5.5, -2.4, 0.0, 2.4, 5.5, 11.1, RING_CARR, RING_HALF]
	var z0: float = RING_Z0
	var z1: float = RING_PORTAL_Z + 34.0
	var step := 3.0
	var n: int = ceili((z1 - z0) / step)
	var piece := 0
	var r0 := 0
	while r0 < n:
		var r1: int = mini(r0 + 40, n)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(r0, r1):
			var za: float = z0 + float(i) * step
			var zb: float = minf(za + step, z1)
			for j in range(lats.size() - 1):
				# Heading north (-z) the right of travel is +x: (left a, right b, next left c, next right d): (a, c, b), (b, c, d).
				var la: float = lats[j]
				var lb: float = lats[j + 1]
				var q: Array = [Vector3(RING_X + la, _ring_y(za), za), Vector3(RING_X + lb, _ring_y(za), za),
					Vector3(RING_X + la, _ring_y(zb), zb), Vector3(RING_X + lb, _ring_y(zb), zb)]
				for t in [[0, 1, 2], [1, 3, 2]]:
					var p0: Vector3 = q[t[0]]
					var p1: Vector3 = q[t[1]]
					var p2: Vector3 = q[t[2]]
					var nrm: Vector3 = (p2 - p0).cross(p1 - p0).normalized()
					if nrm.y < 0.0:
						var tmp: Vector3 = p1
						p1 = p2
						p2 = tmp
						nrm = -nrm
					for p in [p0, p1, p2]:
						st.set_normal(nrm)
						st.set_color(Color(1, 0, 0, 1))
						st.set_uv(Vector2(p.x - RING_X, p.z))
						st.set_uv2(Vector2(9.0, RING_CARR))
						st.add_vertex(p)
						faces.append(p)
		var mesh: ArrayMesh = st.commit()
		mesh.surface_set_material(0, _road_mat)
		var mi := MeshInstance3D.new()
		mi.name = "Ring_%d" % piece
		mi.mesh = _save_res(mesh, "ring_%d" % piece, ROAD_PREFIX)
		node.add_child(mi)
		piece += 1
		r0 = r1
	var body := StaticBody3D.new()
	body.name = "RingRoad"
	body.set_meta(&"surface", "asphalt")
	var cs := CollisionShape3D.new()
	var sh := ConcavePolygonShape3D.new()
	sh.backface_collision = true
	sh.set_faces(faces)
	cs.shape = _save_res(sh, "ring_road_shape")
	body.add_child(cs)
	node.add_child(body)


func _build_route_bodies(root: Node3D) -> void:
	for k in _route_faces.keys():
		var f: PackedVector3Array = _route_faces[k]
		if f.is_empty():
			continue
		var body := StaticBody3D.new()
		body.name = k
		body.set_meta(&"surface", ROUTE_BODIES[k][0])
		if k == "BaustrasseTrack":
			body.set_meta(&"dust_color", Color(0.46, 0.36, 0.26, 0.7))
		elif k == "GartenwegTrack":
			body.set_meta(&"dust_color", Color(0.74, 0.68, 0.56, 0.6))
		var cs := CollisionShape3D.new()
		var sh := ConcavePolygonShape3D.new()
		sh.backface_collision = true
		sh.set_faces(f)
		cs.shape = _save_res(sh, k.to_snake_case() + "_shape")
		body.add_child(cs)
		root.add_child(body)
		print("  %s: %d triangles" % [k, f.size() / 3])


## The route for the AI, the minimap and the jump tests: a point every 4m.
func _build_track_curve() -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = 0.5
	var pts: Array = []
	var n: int = int(ceil(route_len / 4.0))
	for i in range(n + 1):
		pts.append(_pt(minf(float(i) * 4.0, route_len)) + Vector3(0, 0.02, 0))
	var m: int = pts.size()
	for k in range(m):
		var a: Vector3 = pts[maxi(k - 1, 0)]
		var c: Vector3 = pts[mini(k + 1, m - 1)]
		var hnd: Vector3 = (c - a) / (6.0 if k > 0 and k < m - 1 else 3.0)
		curve.add_point(pts[k], -hnd, hnd)
	return curve


# ======================================================================================
#  Water: the moat (the level's water: deep enough to drown in), the lily pond and the canal (both only seen)
# ======================================================================================

func _water_material(col: Color, tile: float, strength: float, nm: String) -> Material:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://still_water.gdshader")
	mat.set_shader_parameter("water_color", col)
	mat.set_shader_parameter("sky_tint", Color(0.48, 0.62, 0.76, 1.0))
	mat.set_shader_parameter("sky_reflect", 0.5)
	mat.set_shader_parameter("ripple_tile", tile)
	mat.set_shader_parameter("ripple_strength", strength)
	var noise_tex := NoiseTexture2D.new()
	noise_tex.seamless = true
	noise_tex.as_normal_map = true
	noise_tex.width = 256
	noise_tex.height = 256
	var nz := FastNoiseLite.new()
	nz.frequency = 0.02
	noise_tex.noise = nz
	mat.set_shader_parameter("noise_tex", noise_tex)
	return _save_res(mat, nm)


func _water_strips(rects: Array, y: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in rects:
		var x0: float = r[0]
		while x0 < float(r[2]) - 0.01:
			var x1: float = minf(x0 + 40.0, r[2])
			var a := Vector3(x0, 0.0, r[1])
			var b := Vector3(x1, 0.0, r[1])
			var c := Vector3(x1, 0.0, r[3])
			var d := Vector3(x0, 0.0, r[3])
			# Clockwise from above (Godot's front faces): (a, b, c) faces up. Wound (a, c, b) the moat and the canal were
			# culled from above and showed no water at all.
			for v in [a, b, c, a, c, d]:
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(v.x, v.z))
				st.add_vertex(v)
			x0 = x1
	return st.commit()


func _build_water(root: Node3D) -> void:
	# The moat.
	var mm: ArrayMesh = _water_strips([[MOAT_X.x - 26.0, MOAT_Z - MOAT_HALF - 8.0, MOAT_X.y + 26.0, MOAT_Z + MOAT_HALF + 8.0]], 0.0)
	mm.surface_set_material(0, _water_material(Color(0.03, 0.07, 0.05, 1.0), 20.0, 0.12, "moat_water_material"))
	var moat := MeshInstance3D.new()
	moat.name = "StadtgrabenWater"
	moat.mesh = _save_res(mm, "moat_water", FAR_PREFIX)
	moat.position = Vector3(0, MOAT_WATER, 0)
	moat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	moat.set_meta(&"water_surface_y", MOAT_WATER)
	moat.set_meta(&"water_bounds_min", Vector2(MOAT_X.x - 26.0, MOAT_Z - MOAT_HALF - 8.0))
	moat.set_meta(&"water_bounds_max", Vector2(MOAT_X.y + 26.0, MOAT_Z + MOAT_HALF + 8.0))
	root.add_child(moat)
	# The lily pond: an ellipse of strips (no collider: shallow, a cart wades it).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 48
	var rx: float = POND_R.x * 1.45
	var rz: float = POND_R.y * 1.45
	for k in range(seg):
		var a0: float = TAU * float(k) / float(seg)
		var a1: float = TAU * float(k + 1) / float(seg)
		var c := Vector3(POND_C.x, 0.0, POND_C.y)
		var p0 := c + Vector3(cos(a0) * rx, 0.0, sin(a0) * rz)
		var p1 := c + Vector3(cos(a1) * rx, 0.0, sin(a1) * rz)
		# Clockwise from above: (c, p0, p1) with the angle growing from +x toward +z (the normal (p1 - c) x (p0 - c) is
		# +y). Wound (c, p1, p0) it faced down and the pond showed no water.
		for v in [c, p0, p1]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(v.x, v.z))
			st.add_vertex(v)
	var pm: ArrayMesh = st.commit()
	pm.surface_set_material(0, _water_material(Color(0.03, 0.06, 0.035, 1.0), 14.0, 0.06, "pond_water_material"))
	var pond := MeshInstance3D.new()
	pond.name = "Teichspiegel"
	pond.mesh = _save_res(pm, "pond_surface", FAR_PREFIX)
	pond.position = Vector3(0, _pond_y, 0)
	pond.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pond)
	# The canal (the Rhine-Herne's like), past the docks.
	var cm: ArrayMesh = _water_strips([[-2600.0, CANAL_Z - CANAL_HALF - 2.0, 2600.0, CANAL_Z + CANAL_HALF + 2.0]], 0.0)
	cm.surface_set_material(0, _water_material(Color(0.02, 0.055, 0.05, 1.0), 26.0, 0.14, "canal_water_material"))
	var canal := MeshInstance3D.new()
	canal.name = "KanalSpiegel"
	canal.mesh = _save_res(cm, "canal_surface", FAR_PREFIX)
	canal.position = Vector3(0, CANAL_WATER, 0)
	canal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(canal)
	# Every water body for the carts (StadtWater.gd as the level's "RiverWater"): PlayerCart took only the moat, and a cart
	# in the pond or the canal drove over a dry bed under the drawn water.
	var sw := Node3D.new()
	sw.name = "RiverWater"
	sw.set_script(load("res://StadtWater.gd"))
	var moat_r: Array = [MOAT_X.x - 26.0, MOAT_Z - MOAT_HALF - 8.0, MOAT_X.y + 26.0, MOAT_Z + MOAT_HALF + 8.0, MOAT_WATER]
	var canal_r: Array = [-2600.0, CANAL_Z - CANAL_HALF - 2.0, 2600.0, CANAL_Z + CANAL_HALF + 2.0, CANAL_WATER]
	sw.set("rects", [moat_r, canal_r])
	sw.set("ellipses", [[POND_C.x, POND_C.y, rx, rz, _pond_y]])
	var wb := Rect2(Vector2(moat_r[0], moat_r[1]), Vector2.ZERO)
	for r in [moat_r, canal_r]:
		wb = wb.expand(Vector2(r[0], r[1])).expand(Vector2(r[2], r[3]))
	wb = wb.expand(Vector2(POND_C.x - rx, POND_C.y - rz)).expand(Vector2(POND_C.x + rx, POND_C.y + rz))
	sw.set("water_bounds", wb)
	level.add_child(sw)


# ======================================================================================
#  The race: the start, the gates, the finish, boost pads, the jumps' lips
# ======================================================================================

## Checkpoints by s: down the Kaiserstraße, over the moat, the pedestrian zone, south of the railway, toward the Ring,
## the garden's gate, the pergola, the Alpinum, the summit, below the terrace, the Hafenstraße, the demolition site,
## the scrapyard, the building site's way in, its parcours (after the table-top), before the car park.
func _checkpoints() -> Array:
	var out: Array = [420.0, 700.0, 960.0, 1290.0, 1720.0, s_gate + 30.0]
	out.append(float(_turn(6)["s1"]) + 90.0)
	out.append(0.5 * (float(_turn(10)["s1"]) + float(_turn(11)["s0"])))
	out.append(float(_turn(13)["s0"]) - 40.0)
	# At the stairs' foot, before the boost pads on the sunken road's banks (its feet stand in their line further on).
	out.append(s_terrace + 35.0)
	out.append(float(_turn(15)["s1"]) + 60.0)
	out.append(s_ball + 120.0)
	# Before the scrapyard's handler, clear of its swing (at +150 the car on its magnet swept through the gate's truss).
	out.append(float(_turn(18)["s1"]) + 80.0)
	out.append(float(_turn(19)["s1"]) + 90.0)
	out.append(_closest_s(PARCOURS_GATE))
	out.append(s_carpark0 - 40.0)
	return out


## [s, lat]: the Kaiserstraße, the long north street, down the Hafenstraße, out of the parcours' last corner onto the run
## through the car park. Not into the kicker any more: boosted off its lip, a cart lands in the hairpin after it.
func _boosts() -> Array:
	return [[270.0, -2.6], [1170.0, 2.6], [s_under2 + 60.0, 0.0], [float(_turn(24)["s1"]) + 12.0, 0.0]]


func _gate(parent: Node, gate_name: String, s: float, finish: bool, scene: PackedScene) -> Node3D:
	var sp: Dictionary = _spot(s, 0.0, 0.06)
	var gate: Node3D = scene.instantiate()
	gate.name = gate_name
	gate.position = sp["pos"]
	gate.rotation_degrees = Vector3(0, sp["yaw"], 0)
	gate.set("is_finish_line", finish)
	parent.add_child(gate)
	return gate


func _place_gameplay(root: Node3D) -> void:
	var gate_scene: PackedScene = load("res://CheckpointGate.tscn")
	var spawn_scene: PackedScene = load("res://SpawnIndicator.tscn")
	var start: Node3D = _gate(root, "StartLine", START_S, true, gate_scene)
	var spawn_points := Node3D.new()
	spawn_points.name = "SpawnPoints"
	start.add_child(spawn_points)
	var grid := [Vector3(-2.9, 0.05, 5.0), Vector3(2.9, 0.05, 5.0), Vector3(-2.9, 0.05, 12.5), Vector3(2.9, 0.05, 12.5),
		Vector3(-2.9, 0.05, 20.0), Vector3(2.9, 0.05, 20.0)]
	for i in range(grid.size()):
		var sp := Marker3D.new()
		sp.name = "Spawn%d" % (i + 1)
		sp.position = grid[i]
		sp.gizmo_extents = 0.3
		spawn_points.add_child(sp)
		var si = spawn_scene.instantiate()
		si.name = "SpawnIndicator"
		sp.add_child(si)
	var cps := Node3D.new()
	cps.name = "Checkpoints"
	root.add_child(cps)
	var cp_s: Array = _checkpoints()
	var prev := START_S
	for i in range(cp_s.size()):
		if float(cp_s[i]) - prev < 53.0:
			push_error("checkpoint %d at %.0fm is %.0fm after the one before" % [i + 1, cp_s[i], float(cp_s[i]) - prev])
		prev = cp_s[i]
		_gate(cps, "Checkpoint_%d" % (i + 1), cp_s[i], false, gate_scene)
		print("  checkpoint %d at %.0fm" % [i + 1, cp_s[i]])
	_gate(root, "FinishLine", _finish_s, true, gate_scene)
	var boost_scene: PackedScene = load("res://BoostPad.tscn")
	var pads := Node3D.new()
	pads.name = "BoostPads"
	root.add_child(pads)
	var boosts: Array = _boosts()
	for i in range(boosts.size()):
		var bp: Node3D = boost_scene.instantiate()
		bp.name = "Boost_%d" % (i + 1)
		var sp2: Dictionary = _spot(boosts[i][0], boosts[i][1], 0.08)
		bp.position = sp2["pos"]
		bp.rotation_degrees = Vector3(0, sp2["yaw"], 0)
		pads.add_child(bp)
	# On the grass banks of the sunken road below the terrace (the user's idea): ride up the bank for a boost. Each stands on
	# the bank's slope (BoostPad settles onto it and tilts with it) and faces along the route.
	var bank_pads: Array = []
	for bb in BANK_BOOSTS:
		bank_pads.append([s_terrace + float(bb[0]), float(bb[1])])
	for bb in HAFEN_BANK_BOOSTS:
		bank_pads.append([s_under2 + float(bb[0]), float(bb[1])])
	for i in range(bank_pads.size()):
		var bb: Array = bank_pads[i]
		var sp3: Dictionary = _spot(float(bb[0]), float(bb[1]), 0.0)
		var bpos: Vector3 = sp3["pos"]
		# Reserved, so the dressing built after (lamps, trees, signs) keeps off it and the run along the bank past it.
		_note_rect(Vector2(bpos.x, bpos.z), 7.0, 7.0, 0.0)
		var ahead: Dictionary = _spot(float(bb[0]) + 14.0, float(bb[1]), 0.0)
		_note_rect(Vector2((ahead["pos"] as Vector3).x, (ahead["pos"] as Vector3).z), 7.0, 14.0, 0.0)
		var bpad: Node3D = boost_scene.instantiate()
		bpad.name = "BankBoost_%d" % (i + 1)
		bpad.position = Vector3(bpos.x, _ground_at(bpos.x, bpos.z) + 0.08, bpos.z)
		bpad.rotation_degrees = Vector3(0, sp3["yaw"], 0)
		pads.add_child(bpad)


## Whether the hazards get a HazardGate.gd, which holds the bots short of a hazard until it is clear. Off: the user found the
## waits too long and wants the bots to take their chances (some get blown up). The gates are still set up, only not added.
const HAZARD_GATES := false


func _add_hazard_gate(node: Node3D, gate: Node3D) -> void:
	if HAZARD_GATES:
		node.add_child(gate)
	else:
		gate.free()


## Wrecked cars through the scrapyard (ScrapKit.wreck): staggered on the lane, one side then the other, so there is always
## a way past but never a straight line; and scattered over the yard either side (some two high), off everything noted.
## Each a box (SchrottBody), so the bots' rays see them and steer round.
func _build_scrap_wrecks(node: Node3D, body: StaticBody3D, rng: RandomNumberGenerator, s_h: float) -> void:
	var t18: Dictionary = _turn(18)
	var t19: Dictionary = _turn(19)
	var s0: float = float(t18["s1"]) + 30.0
	var s1: float = float(t19["s0"]) - 25.0
	var cps: Array = _checkpoints()
	var placed := 0
	var side := 1.0
	var s: float = s0
	while s < s1:
		var near_gate := false
		for cp in cps:
			if absf(s - float(cp)) < 16.0:
				near_gate = true
		# Clear of the handler's drop (its car lands across the middle) and the gates.
		if absf(s - s_h) > 26.0 and not near_gate:
			# Toward the edge, a little askew: the bots keep to the middle, and wrecks 2.6m out turned across it stopped them
			# dead (they crawled into them until the stuck check respawned them).
			var lat: float = side * rng.randf_range(3.9, 5.2)
			var sp: Dictionary = _spot(s, lat, 0.0)
			var yaw: float = rng.randf_range(-0.3, 0.3)
			if _place_wreck(node, body, rng, sp["pos"], (sp["fwd"] as Vector3).rotated(Vector3.UP, yaw), false):
				placed += 1
			side = -side
		s += rng.randf_range(17.0, 26.0)
	# The yard: either side of the lane, out to the heaps.
	var yard := 0
	var tries := 0
	while yard < 34 and tries < 400:
		tries += 1
		var ss: float = rng.randf_range(s0 - 10.0, s1 + 10.0)
		var off: float = (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(ROAD_HALF + 6.0, ROAD_HALF + 40.0)
		var sp2: Dictionary = _spot(ss, off, 0.0)
		var p: Vector3 = sp2["pos"]
		if _route_dist(p.x, p.z) < ROAD_HALF + 5.0 or _occupied(p.x, p.z) or p.x < -50.0 or p.x > 390.0 or p.z < 612.0 or p.z > 748.0:
			continue
		var dir := Vector3(1, 0, 0).rotated(Vector3.UP, rng.randf() * TAU)
		if _place_wreck(node, body, rng, p, dir, rng.randf() < 0.3):
			yard += 1
	print("  scrapyard wrecks: %d on the lane, %d in the yard" % [placed, yard])


func _place_wreck(node: Node3D, body: StaticBody3D, rng: RandomNumberGenerator, at: Vector3, fwd: Vector3, stacked: bool) -> bool:
	fwd.y = 0.0
	fwd = fwd.normalized()
	var g: float = _ground_at(at.x, at.z)
	var xf := Transform3D(Basis.looking_at(fwd, Vector3.UP), Vector3(at.x, g - 0.03, at.z))
	var seed_v: int = rng.randi()
	_add_prop(_cell_key("wrecks", xf.origin, 160.0), _scrap, xf, func(pk, kit, _labels): _kit_call(_scrap, "wreck", [pk, kit, seed_v, stacked]), 1200.0)
	_solids(body, _kit_call(_scrap, "wreck_solids", [seed_v, stacked]), xf)
	_note_rect(Vector2(at.x, at.z), 5.0, 5.0, 0.0, 0.5)
	return true


## [s past the terrace's lip, lateral]: boost pads on the sunken road's banks, left and right in turn, clear of the
## checkpoint (35m) and the garden's exit gate (155m).
const BANK_BOOSTS := [[70.0, -12.0], [90.0, 12.0], [114.0, -12.0]]
## [s past the second railway underpass, lateral]: more on the Hafenstraße's banks down to the docks (the road runs in a
## cutting there, the banks rising from 10m out to 3m at 16m).
const HAFEN_BANK_BOOSTS := [[172.0, -13.0], [212.0, 13.0], [262.0, -13.0], [302.0, 13.0], [352.0, -13.0]]


## The jumps' lips for scratch/nyota_jump_test (the TrackPath's jump_lips): the moat bridge's crest, the terrace, the
## building site's kicker.
func _jump_lips() -> Array:
	var out: Array = []
	var crest: float = s_moat + 4.0
	var cp: Vector3 = _pt(crest)
	out.append({"name": "MoatBridge", "lip": cp, "dir": (_pt(crest + 2.0) - _pt(crest - 2.0)).normalized()})
	var tl: Vector3 = _pt(s_terrace - 0.2)
	out.append({"name": "Terrace", "lip": tl, "dir": (_pt(s_terrace - 0.2) - _pt(s_terrace - 3.0)).normalized()})
	var kl: Vector3 = _pt(s_kicker)
	out.append({"name": "SiteKicker", "lip": kl, "dir": (_pt(s_kicker) - _pt(s_kicker - 3.0)).normalized()})
	var tl2: Vector3 = _pt(s_table)
	out.append({"name": "SiteTableTop", "lip": tl2, "dir": (_pt(s_table) - _pt(s_table - 3.0)).normalized()})
	return out


# ======================================================================================
#  Sky and light: a late-summer morning, half past ten, the sun in the south-east
# ======================================================================================

const HAZE := Color(0.78, 0.82, 0.86)

func _build_environment(root: Node3D) -> void:
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://sky_tropical_cumulus.gdshader")
	sky_mat.set_shader_parameter("sky_top", Color(0.17, 0.40, 0.80))
	sky_mat.set_shader_parameter("sky_horizon", Color(0.72, 0.81, 0.91))
	sky_mat.set_shader_parameter("ground_horizon", HAZE)
	sky_mat.set_shader_parameter("ground_bottom", Color(0.42, 0.45, 0.42))
	sky_mat.set_shader_parameter("sky_curve", 0.42)
	sky_mat.set_shader_parameter("horizon_haze", HAZE)
	sky_mat.set_shader_parameter("haze_strength", 0.7)
	sky_mat.set_shader_parameter("haze_height", 0.11)
	sky_mat.set_shader_parameter("sun_tint", Color(1.0, 0.97, 0.90))
	sky_mat.set_shader_parameter("sun_disc_degrees", 1.0)
	sky_mat.set_shader_parameter("sun_glow", 0.42)
	sky_mat.set_shader_parameter("sun_horizon_tint", Color(1.0, 0.92, 0.78))
	sky_mat.set_shader_parameter("sun_horizon_glow", 0.05)
	sky_mat.set_shader_parameter("cloud_lit", Color(1.0, 1.0, 0.98))
	sky_mat.set_shader_parameter("cloud_shade", Color(0.60, 0.65, 0.73))
	sky_mat.set_shader_parameter("cloud_coverage", 0.40)
	sky_mat.set_shader_parameter("cloud_opacity", 0.92)
	sky_mat.set_shader_parameter("cloud_scale", 1.15)
	sky_mat.set_shader_parameter("cloud_seed", 41.7)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.45
	env.ambient_light_color = Color(0.90, 0.92, 0.95)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.22
	env.glow_bloom = 0.04
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = HAZE
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.1
	env.fog_density = 1.0
	env.fog_depth_begin = 320.0
	env.fog_depth_end = 4200.0
	env.fog_depth_curve = 1.6
	env.fog_sky_affect = 0.05
	env.fog_aerial_perspective = 0.3
	env_node.environment = env
	root.add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	# Toward the sun: the south-east (+x east, +z south), 44 degrees up; the light travels the other way.
	var el: float = deg_to_rad(44.0)
	var toward := Vector3(0.74 * cos(el), sin(el), 0.67 * cos(el)).normalized()
	sun.transform = Transform3D(Basis.looking_at(-toward, Vector3.UP), Vector3(0, 100, 0))
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 300.0
	sun.directional_shadow_split_1 = 0.08
	sun.directional_shadow_split_2 = 0.22
	sun.directional_shadow_split_3 = 0.5
	root.add_child(sun)


# ======================================================================================
#  Saving
# ======================================================================================

func _save_res(res: Resource, res_name: String, prefix := RES_PREFIX) -> Resource:
	if not DirAccess.dir_exists_absolute("res://generated/"):
		DirAccess.make_dir_absolute("res://generated/")
	var file_path: String = "res://generated/" + prefix + res_name + ".res"
	res.take_over_path(file_path)
	ResourceSaver.save(res, file_path)
	return load(file_path)


func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	if node != scene_root:
		node.owner = scene_root
	for child in node.get_children():
		if child.owner != null and child.owner != scene_root:
			continue
		_set_owner_recursive(child, scene_root)


func _ready() -> void:
	print("=== Quer durch Kronburg (Kronburg GP) Level Generation ===")
	var t_start: int = Time.get_ticks_msec()
	var gen := DirAccess.open("res://generated/")
	if gen:
		var cleared := 0
		for f in gen.get_files():
			if f.begins_with("stadtrallye") and (f.ends_with(".res") or f.ends_with(".tscn")):
				gen.remove(f)
				cleared += 1
		print("  cleared %d old files" % cleared)
	level = Node3D.new()
	level.name = LEVEL_NAME
	level.set_script(load("res://levels/Level.gd"))
	level.set("is_point_to_point", true)
	var players_node := Node3D.new()
	players_node.name = "Players"
	level.add_child(players_node)
	var p_spawner := MultiplayerSpawner.new()
	p_spawner.name = "PlayerSpawner"
	p_spawner.set("_spawnable_scenes", PackedStringArray(["uid://cart123"]))
	p_spawner.spawn_path = NodePath("../Players")
	p_spawner.spawn_limit = 6
	level.add_child(p_spawner)
	var proj_spawner := MultiplayerSpawner.new()
	proj_spawner.name = "ProjectileSpawner"
	proj_spawner.spawn_path = NodePath(".")
	level.add_child(proj_spawner)
	add_child(level)

	_init_noise()
	_route = _fillet_open(CORNERS)
	segs = _route["segs"]
	route_len = _route["len"]
	_finish_s = route_len - FINISH_RUNOUT
	_road_y.resize(int(ceil(route_len)) + 2)
	_road_y.fill(CITY_Y)
	_plan_profile()
	_pond_y = _lap_y(s_pond - float(POND_BRIDGE[0]) * PROP_SCALE * 0.5 - 3.0) - 1.8
	var track_path := Path3D.new()
	track_path.name = "TrackPath"
	track_path.curve = _build_track_curve()
	track_path.set_meta(&"jump_lips", _jump_lips())
	level.add_child(track_path)
	_plan_pads()
	_add_samples()
	_build_heights()
	print("  heights built (%.1fs)" % ((Time.get_ticks_msec() - t_start) / 1000.0))

	var gm := ShaderMaterial.new()
	gm.shader = load("res://stadt_ground.gdshader")
	gm.set_shader_parameter("grass_tex", load("res://materials/grass.png"))
	gm.set_shader_parameter("dirt_tex", load("res://materials/dirt.png"))
	gm.set_shader_parameter("dirt_normal", load("res://materials/dirt_normal.png"))
	gm.set_shader_parameter("rock_tex", load("res://materials/dark_rock.png"))
	gm.set_shader_parameter("gravel_tex", load("res://materials/dark_canyon_rock.png"))
	gm.set_shader_parameter("gravel_normal", load("res://materials/dark_canyon_rock_normal.png"))
	gm.set_shader_parameter("concrete_tex", load("res://materials/concrete.png"))
	gm.set_shader_parameter("water_y", CANAL_WATER)
	_ground_mat = _save_res(gm, "ground_material") as ShaderMaterial
	_road_mat = _road_material()
	var terrain := Node3D.new()
	terrain.name = "StadtTerrain"
	level.add_child(terrain)
	_build_terrain(terrain)
	print("  terrain built (%.1fs)" % ((Time.get_ticks_msec() - t_start) / 1000.0))
	_build_water(terrain)
	_build_roads(level)
	_build_route_bodies(level)
	_build_environment(level)
	_place_gameplay(level)
	_build_dressing(level)
	print("  dressing built (%.1fs)" % ((Time.get_ticks_msec() - t_start) / 1000.0))

	level.set("track_path", track_path)
	level._setup_checkpoints()
	var chunked: int = MeshChunker.chunk_scene(level, "res://generated/" + RES_PREFIX, "res://generated/stadtrallye_chunks", MESH_CHUNK_CELL)
	print("  chunked %d large meshes" % chunked)
	_set_owner_recursive(level, level)
	remove_child(level)
	var packed := PackedScene.new()
	var err = packed.pack(level)
	if err != OK:
		push_error("Failed to pack %s: %d" % [LEVEL_PATH, err])
		get_tree().quit(1)
		return
	err = ResourceSaver.save(packed, LEVEL_PATH)
	if err != OK:
		push_error("Failed to save %s: %d" % [LEVEL_PATH, err])
		get_tree().quit(1)
		return
	print("Saved %s in %.1fs" % [LEVEL_PATH, (Time.get_ticks_msec() - t_start) / 1000.0])
	get_tree().quit(0)


# ======================================================================================
#  Dressing
# ======================================================================================

var _stadt: Script
var _garden: Script
var _scrap: Script
var _baustelle: Script
var _rhein: Script
var _town: Script
var _works: Script
var _port: Script
var _batches := {}
var _saved_mats := {}
var _missing := {}
var _occ := {}
var _people: Array = []
var _camp_mats := {}

func _build_dressing(root: Node3D) -> void:
	_stadt = _kit_script("res://StadtKit.gd")
	_garden = _kit_script("res://GardenKit.gd")
	_scrap = _kit_script("res://ScrapKit.gd")
	_baustelle = _kit_script("res://BaustelleKit.gd")
	_rhein = _kit_script("res://RheinStadtKit.gd")
	_town = _kit_script("res://KronburgTownKit.gd")
	_works = _kit_script("res://SteelworksKit.gd")
	_port = _kit_script("res://PortKit.gd")
	_note_route()
	_build_railway(root)
	_build_city(root)
	_build_ring(root)
	_build_garden(root)
	_build_docks(root)
	_build_start(root)
	_build_finish(root)
	CrowdPlacer.build(root, _people, SPECTATOR_SCALE, SPECTATOR_SKIN, 9121, func(res: Resource, n: String) -> Resource: return _save_res(res, n, "stadtrallyecrowd_"))
	_flush_batches(root)
	_build_sounds(root)
	_build_woods(root)


# ======================================================================================
#  Prop batches: many props built into one kit (a mesh with a surface per material), saved under PROP_PREFIX
# ======================================================================================

func _kit_script(path: String) -> Script:
	if ResourceLoader.exists(path):
		var sc: Script = load(path)
		if sc != null and sc.can_instantiate():
			return sc
	push_warning("Stadtrallye: %s isn't there (or doesn't parse) yet" % path)
	return null


## How many arguments a kit's function takes (0 if it has none of that name).
func _fn_argc(script: Script, fn: String) -> int:
	if script == null:
		return 0
	for m in script.get_script_method_list():
		if m["name"] == fn:
			return (m["args"] as Array).size()
	return 0


func _has_fn(script: Script, fn: String) -> bool:
	if script == null:
		return false
	for m in script.get_script_method_list():
		if m["name"] == fn:
			return true
	return false


func _add_prop(key: String, kit_script: Script, xf: Transform3D, build: Callable, range_end := 0.0, range_begin := 0.0) -> void:
	if kit_script == null:
		return
	if not _batches.has(key):
		_batches[key] = {"pk": _kit_new(kit_script, PROP_SCALE), "kit": {}, "labels": [], "range": range_end, "begin": range_begin, "script": kit_script}
	else:
		_kit_new(kit_script, PROP_SCALE)
	var b: Dictionary = _batches[key]
	var pk: PropKit = b["pk"]
	var frame := Transform3D(xf.basis * Basis.from_scale(Vector3.ONE * PROP_SCALE), xf.origin)
	pk.set_frame(frame)
	var labels: Array = []
	build.call(pk, b["kit"], labels)
	for l in labels:
		var out: Array = [l[0], frame * (l[1] as Vector3), (xf.basis * (l[2] as Vector3)).normalized(), float(l[3]) * PROP_SCALE, l[4],
				float(l[5]) * PROP_SCALE if l.size() > 5 else 0.0]
		(b["labels"] as Array).append(out)


## A kit's PropKit and commit (PortKit names them its own way).
func _kit_new(script: Script, scale: float) -> PropKit:
	if _has_fn(script, "new_kit"):
		return script.new_kit(scale)
	return script.new_port_kit(scale)


func _kit_commit(script: Script, pk: PropKit, kit: Dictionary) -> ArrayMesh:
	if _has_fn(script, "commit"):
		return script.commit(pk, kit)
	return script.commit_port(pk, kit)


func _kit_call(script: Script, fn: String, args: Array) -> Variant:
	if script == null or not _has_fn(script, fn):
		if not _missing.has(fn):
			_missing[fn] = true
			push_warning("Stadtrallye: %s has no %s() yet" % [script.resource_path.get_file() if script else "(no kit)", fn])
		return null
	return script.callv(fn, args)


func _cell_key(prefix: String, p: Vector3, cell := 140.0) -> String:
	return "%s_%d_%d" % [prefix, floori(p.x / cell), floori(p.z / cell)]


func _flush_batches(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Stadt"
	root.add_child(node)
	var tris := 0
	var keys: Array = _batches.keys()
	keys.sort()
	for key in keys:
		var b: Dictionary = _batches[key]
		var pk: PropKit = b["pk"]
		pk.reset_frame()
		if (b["kit"] as Dictionary).is_empty():
			continue
		var mesh: ArrayMesh = _kit_commit(b["script"], pk, b["kit"])
		_share_materials(mesh)
		tris += MeshChunker.triangle_count(mesh)
		var mi := MeshInstance3D.new()
		mi.name = String(key).to_pascal_case()
		mi.mesh = _save_res(mesh, key, PROP_PREFIX)
		if float(b["range"]) > 0.0:
			mi.visibility_range_end = float(b["range"])
			mi.visibility_range_end_margin = float(b["range"]) * 0.08
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if float(b["begin"]) > 0.0:
			mi.visibility_range_begin = float(b["begin"])
			mi.visibility_range_begin_margin = 30.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		node.add_child(mi)
		for l in b["labels"]:
			var lab := Label3D.new()
			lab.text = l[0]
			lab.font_size = 64
			lab.pixel_size = _fit_pixel(l[0], 64, float(l[3]) / 44.8, float(l[5]))
			lab.modulate = l[4]
			lab.outline_size = 4
			lab.outline_modulate = Color(0.05, 0.05, 0.05)
			lab.double_sided = false
			lab.alpha_cut = Label3D.ALPHA_CUT_DISCARD
			var n: Vector3 = l[2]
			lab.transform = Transform3D(Basis.looking_at(-n, Vector3.UP if absf(n.y) < 0.95 else Vector3.BACK), l[1])
			if float(b["range"]) > 0.0:
				lab.visibility_range_end = float(b["range"])
			mi.add_child(lab)
	print("  props: %d meshes, %d triangles, %d materials" % [keys.size(), tris, _saved_mats.size()])


func _share_materials(mesh: ArrayMesh) -> void:
	for si in range(mesh.get_surface_count()):
		var m: Material = mesh.surface_get_material(si)
		if m == null:
			continue
		if m.resource_path.is_empty():
			var id: int = m.get_instance_id()
			if not _saved_mats.has(id):
				_saved_mats[id] = _save_res(m, "mat_%d" % _saved_mats.size(), PROP_PREFIX)
			mesh.surface_set_material(si, _saved_mats[id])


func _fit_pixel(text: String, font_size: int, pixel: float, max_w: float) -> float:
	if max_w <= 0.0:
		return pixel
	var w: float = ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if w * pixel <= max_w:
		return pixel
	return max_w / maxf(w, 1.0)


## A kit's mesh at life size, for the moving parts (under a node grown by PROP_SCALE), its materials shared.
func _kit_mesh(script: Script, mesh_name: String, build: Callable) -> ArrayMesh:
	if script == null:
		return null
	var pk: PropKit = script.new_kit(1.0)
	var kit := {}
	build.call(pk, kit)
	if kit.is_empty():
		return null
	var mesh: ArrayMesh = script.commit(pk, kit)
	_share_materials(mesh)
	return _save_res(mesh, mesh_name, PROP_PREFIX)


## A frame facing `face` (its +z) standing upright at `at`.
func _facing(face: Vector3, at: Vector3) -> Transform3D:
	var z := Vector3(face.x, 0.0, face.z).normalized()
	var x := Vector3.UP.cross(z).normalized()
	return Transform3D(Basis(x, Vector3.UP, z), at)


## The 4m cells something stands on, so props and trees keep apart.
func _note_rect(c: Vector2, w: float, d: float, yaw: float, margin := 1.0) -> void:
	var ax := Vector2(cos(yaw), -sin(yaw))
	var az := Vector2(sin(yaw), cos(yaw))
	var hw: float = w * 0.5 + margin
	var hd: float = d * 0.5 + margin
	var r: float = sqrt(hw * hw + hd * hd)
	for i in range(floori((c.x - r) / 4.0), floori((c.x + r) / 4.0) + 1):
		for j in range(floori((c.y - r) / 4.0), floori((c.y + r) / 4.0) + 1):
			var q := Vector2((float(i) + 0.5) * 4.0, (float(j) + 0.5) * 4.0) - c
			if absf(q.dot(ax)) < hw + 2.0 and absf(q.dot(az)) < hd + 2.0:
				_occ[Vector2i(i, j)] = true


func _note_xf(xf: Transform3D, x0: float, x1: float, z0: float, z1: float, margin := 0.5) -> void:
	var c: Vector3 = xf * Vector3((x0 + x1) * 0.5, 0.0, (z0 + z1) * 0.5)
	var ax: Vector3 = xf.basis.x.normalized()
	_note_rect(Vector2(c.x, c.z), absf(x1 - x0) * xf.basis.x.length(), absf(z1 - z0) * xf.basis.z.length(), atan2(-ax.z, ax.x), margin)


func _occupied(x: float, z: float) -> bool:
	return _occ.has(Vector2i(floori(x / 4.0), floori(z / 4.0)))


func _clear(c: Vector3, ax: Vector3, w: float, d: float) -> bool:
	var az := Vector3(-ax.z, 0.0, ax.x)
	for i in range(-2, 3):
		for j in range(-2, 3):
			var p: Vector3 = c + ax * (float(i) / 2.0) * (w * 0.5 - 1.0) + az * (float(j) / 2.0) * (d * 0.5 - 1.0)
			if _occupied(p.x, p.z):
				return false
	return true


## The Ring and the railway's band are taken before anything is placed (the route is kept clear by `_route_dist`).
func _note_route() -> void:
	# `_note_rect` takes in every 4m cell within its half width plus 2m, so the band is noted 3m narrower a side than the
	# Ring: as wide as the Ring plus 2m, it took the cells of every house front along it and `_row` placed none.
	_note_rect(Vector2(RING_X, (RING_Z0 + RING_PORTAL_Z) * 0.5), RING_HALF * 2.0 - 6.0, RING_PORTAL_Z - RING_Z0 + 40.0, 0.0, 0.0)
	_note_rect(Vector2(0.0, RAIL_Z), RAIL_X.y - RAIL_X.x, EMBANK_HALF * 2.0 + 10.0, 0.0, 0.0)


## The distance in plan from (x, z) to the route's line (from the grading's route samples).
func _route_dist(x: float, z: float) -> float:
	var cx: int = floori(x / CELL)
	var cz: int = floori(z / CELL)
	var best := 1e18
	for gz in range(cz - 2, cz + 3):
		for gx in range(cx - 2, cx + 3):
			var bucket: PackedInt32Array = _rs_cells.get(Vector2i(gx, gz), PackedInt32Array())
			for i in bucket:
				if i >= _route_rs:
					continue
				var a: Vector3 = _rs_pos[i]
				var j: int = _rs_next[i]
				var b: Vector3 = _rs_pos[j] if j >= 0 else a
				var sx: float = b.x - a.x
				var sz: float = b.z - a.z
				var l2: float = maxf(sx * sx + sz * sz, 1e-6)
				var t: float = clampf(((x - a.x) * sx + (z - a.z) * sz) / l2, 0.0, 1.0)
				var fx: float = x - (a.x + sx * t)
				var fz: float = z - (a.z + sz * t)
				best = minf(best, fx * fx + fz * fz)
	return sqrt(best) if best < 1e17 else 1e9


## Colliders from a kit's solids list ([Transform3D in the prop's life-size frame, size]) placed by `xf`.
func _solids(body: StaticBody3D, list, xf: Transform3D) -> void:
	if not (list is Array):
		return
	var rot: Basis = xf.basis.orthonormalized()
	for e in list:
		var t: Transform3D = e[0]
		var size: Vector3 = e[1]
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = (size * PROP_SCALE).abs().max(Vector3.ONE * 0.05)
		cs.shape = bx
		cs.transform = Transform3D(rot * t.basis.orthonormalized(), xf * (t.origin * PROP_SCALE))
		body.add_child(cs)


func _body(root: Node3D, body_name: String, surface := "") -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = body_name
	if surface != "":
		b.set_meta(&"surface", surface)
	root.add_child(b)
	return b


## A box collider in the world.
func _box(body: StaticBody3D, xf: Transform3D, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = size
	cs.shape = bx
	cs.transform = xf
	body.add_child(cs)


func _multimesh(parent: Node3D, node_name: String, mesh: Mesh, xfs: Array, range_end := 0.0, shadows := true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	mm.buffer = PropKit.transform_buffer(xfs)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if range_end > 0.0:
		mmi.visibility_range_end = range_end
	parent.add_child(mmi)
	return mmi


func _camp_material(key: String) -> Material:
	if not _camp_mats.has(key):
		_camp_mats[key] = _save_res(CampKit.make_material(key), "camp_mat_" + key, PROP_PREFIX)
	return _camp_mats[key]


func _player(parent: Node3D, node_name: String, path: String, at: Vector3, db: float, unit: float, max_d: float) -> AudioStreamPlayer3D:
	if not ResourceLoader.exists(path):
		return null
	var p := AudioStreamPlayer3D.new()
	p.name = node_name
	p.stream = load(path)
	p.volume_db = db
	p.unit_size = unit
	p.max_distance = max_d
	p.autoplay = true
	p.position = at
	p.bus = &"SFX"
	parent.add_child(p)
	return p


func _stream(path: String) -> AudioStream:
	return load(path) if ResourceLoader.exists(path) else null


func _streams(paths: Array) -> Array[AudioStream]:
	var out: Array[AudioStream] = []
	for p in paths:
		var s: AudioStream = _stream(p)
		if s != null:
			out.append(s)
	return out


# ======================================================================================
#  The railway: brick-walled embankments in the city and round the bridges, an earth one elsewhere (the terrain's),
#  the Hauptbahnhof's platforms, three bridges (the route twice, the Ring once), two tracks, S-Bahn trains
# ======================================================================================

const STATION_X := -900.0
var _station_z := -30.0

func _build_railway(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Eisenbahn"
	root.add_child(node)
	var body := _body(node, "BahnDammBody", "rock")
	# The Hauptbahnhof: its two middle tracks on the line's (RAIL_Z +- RAIL_TRACK_OFF).
	var tz: Array = []
	if _stadt != null and _stadt.get_script_constant_map().has("TRACKS_Z"):
		tz = _stadt.get_script_constant_map()["TRACKS_Z"]
	var mid_life: float = -62.0
	if tz.size() >= 4:
		mid_life = (float(tz[1]) + float(tz[2])) * 0.5
	elif tz.size() >= 2:
		mid_life = (float(tz[0]) + float(tz[tz.size() - 1])) * 0.5
	_station_z = RAIL_Z - mid_life * PROP_SCALE
	var hbf_xf := _facing(Vector3(0, 0, 1), Vector3(STATION_X, CITY_Y - GROUND_UNDER, _station_z))
	_add_prop("hauptbahnhof", _stadt, hbf_xf, func(pk, kit, labels): _kit_call(_stadt, "hauptbahnhof", [pk, kit, labels]), 2600.0)
	_solids(body, _kit_call(_stadt, "hauptbahnhof_solids", []), hbf_xf)
	_note_xf(hbf_xf, -64.0 * PROP_SCALE, 64.0 * PROP_SCALE, -100.0 * PROP_SCALE, 9.0 * PROP_SCALE, 1.0)
	print("  Hauptbahnhof's facade at z %.1f" % _station_z)
	# The bridges: [x, the road's height under it, the clear span (life)].
	var bridges: Array = [
		[-330.0, _lap_y(s_under1), (ROAD_HALF + PAVEMENT) * 2.0 / PROP_SCALE + 1.0],
		[RING_X, _ring_y(RAIL_Z), RING_HALF * 2.0 / PROP_SCALE + 0.6],
		[840.0, _lap_y(s_under2), (ROAD_HALF + 4.0) * 2.0 / PROP_SCALE],
	]
	var cuts: Array = []
	for br in bridges:
		var bx: float = br[0]
		var top: float = _rail_top(bx) - EMBANK_UNDER
		var h_life: float = (top - float(br[1])) / PROP_SCALE
		var span: float = br[2]
		var xf := Transform3D(Basis(), Vector3(bx, float(br[1]), RAIL_Z))
		var sp: float = span
		var hl: float = h_life
		_add_prop(_cell_key("railbridge", xf.origin), _stadt, xf, func(pk, kit, labels): _kit_call(_stadt, "railway_bridge", [pk, kit, labels, sp, hl]), 2000.0)
		_solids(body, _kit_call(_stadt, "railway_bridge_solids", [sp, hl]), xf)
		# The abutments stand about 4m (life) past each side of the opening; the walls butt against them.
		var half_out: float = (span * 0.5 + _bridge_abutment()) * PROP_SCALE
		cuts.append([bx - half_out, bx + half_out])
		print("  railway bridge at x %.0f: span %.1f, height %.2f (life)" % [bx, span, h_life])
	# The walled embankment in pieces up to 60m, between the station and the bridges.
	var station_x0: float = STATION_X - 64.0 * PROP_SCALE
	var station_x1: float = STATION_X + 64.0 * PROP_SCALE
	var pieces := 0
	for w in WALLED:
		var x0: float = w[0]
		var x1: float = w[1]
		var runs: Array = [[x0, x1]]
		for c in cuts + [[station_x0, station_x1]]:
			var nr: Array = []
			for r in runs:
				var a: float = r[0]
				var b: float = r[1]
				if float(c[1]) <= a or float(c[0]) >= b:
					nr.append(r)
					continue
				if float(c[0]) > a:
					nr.append([a, float(c[0])])
				if float(c[1]) < b:
					nr.append([float(c[1]), b])
			runs = nr
		for r in runs:
			var a2: float = r[0]
			var b2: float = r[1]
			var n: int = maxi(1, ceili((b2 - a2) / 60.0))
			for k in range(n):
				var pa: float = lerpf(a2, b2, float(k) / float(n))
				var pb: float = lerpf(a2, b2, float(k + 1) / float(n))
				var g: float = minf(_ground_at(pa, RAIL_Z), minf(_ground_at(pb, RAIL_Z), _ground_at((pa + pb) * 0.5, RAIL_Z)))
				var top2: float = _rail_top((pa + pb) * 0.5) - EMBANK_UNDER
				var length_life: float = (pb - pa) / PROP_SCALE
				var h2: float = (top2 - g) / PROP_SCALE
				var hw: float = EMBANK_HALF / PROP_SCALE
				var xf2 := Transform3D(Basis(), Vector3(pa, g, RAIL_Z))
				_add_prop(_cell_key("bahndamm", xf2.origin, 200.0), _stadt, xf2, func(pk, kit, _labels): _kit_call(_stadt, "rail_embankment", [pk, kit, length_life, h2, hw]), 2000.0)
				_box(body, Transform3D(Basis(), Vector3((pa + pb) * 0.5, (g + top2) * 0.5, RAIL_Z)), Vector3(pb - pa, top2 - g, EMBANK_HALF * 2.0))
				pieces += 1
	print("  walled embankment: %d pieces" % pieces)
	_build_tracks(node)


## How far (life) each abutment stands out past the bridge's opening (StadtKit's, or a guess).
func _bridge_abutment() -> float:
	if _stadt != null and _stadt.get_script_constant_map().has("BRIDGE_ABUTMENT"):
		return float(_stadt.get_script_constant_map()["BRIDGE_ABUTMENT"])
	return 4.0


const RAIL_STEP := 3.0
## The Regional-Express (TrainKit's German push-pull set): the diesel locomotive, two double-deck coaches and the cab car.
const SBAHN_CONSIST := ["re_loco", "re_dosto", "re_dosto", "~re_cab"]

func _build_tracks(node: Node3D) -> void:
	var curves: Array = []
	var piece_no := 0
	for side in [-1.0, 1.0]:
		var z: float = RAIL_Z + side * RAIL_TRACK_OFF
		var n: int = int((RAIL_X.y - RAIL_X.x) / RAIL_STEP)
		var pts: Array = []
		var curve := Curve3D.new()
		curve.bake_interval = 1.0
		for k in range(n + 1):
			var x: float = RAIL_X.x + float(k) * RAIL_STEP
			var v := Vector3(x, _rail_top(x), z)
			pts.append(v)
			curve.add_point(v)
		curves.append(curve)
		var piece: Array = []
		var bed: Array = []
		for k in range(pts.size()):
			piece.append(pts[k])
			if piece.size() > 1:
				bed.append(true)
			if piece.size() > 32 or k == pts.size() - 1:
				var mi := MeshInstance3D.new()
				mi.name = "Gleis_%d" % piece_no
				var before = pts[k - piece.size()] if k - piece.size() >= 0 else null
				var after = pts[k + 1] if k + 1 < pts.size() else null
				var tm: ArrayMesh = FreightKit.track_piece(piece, bed, piece_no, null, before, after)
				_share_materials(tm)
				mi.mesh = _save_res(tm, "track_%d" % piece_no, FAR_PREFIX)
				mi.visibility_range_end = 1400.0
				mi.visibility_range_end_margin = 100.0
				mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				node.add_child(mi)
				piece_no += 1
				piece = [pts[k]]
				bed = []
	# The S-Bahn: a train each way, through the station, on the wall clock (nothing up there for a cart to touch).
	for i in range(2):
		var train := Node3D.new()
		train.name = "SBahn%d" % i
		train.set_script(load("res://Train.gd"))
		train.set("path", curves[i])
		train.set("consist", PackedStringArray(SBAHN_CONSIST))
		train.set("speed", 21.0)
		# A turn takes (5.2km + the train) / 21 m/s, about 254s: at 150s each train jumped back to its start halfway
		# across the city.
		train.set("period", 260.0)
		train.set("phase", 37.0 + 130.0 * float(i))
		train.set("reverse", i == 0)
		train.set("kills", false)
		node.add_child(train)
	print("  tracks: %d pieces" % piece_no)


# ======================================================================================
#  The city: Gründerzeit frontage along the route's streets (RheinStadtKit), the Kaufhaus, the pedestrian zone, the moat's
#  park and its bridge, street furniture, and plain blocks behind for the views from the garden's hill
# ======================================================================================

const FRONT_LAT := ROAD_HALF + PAVEMENT + 0.15
const HOUSE_DEPTH := 13.0
## Detailed houses to this far (from their cell's middle), the plain stand-ins from there on.
const HOUSE_NEAR := 300.0
var _house_count := 0


## Gründerzeit houses along one side (`side` +1 right of travel, -1 left) from s0 to s1, fronts at `lat`.
func _frontage(s0: float, s1: float, side: float, rng: RandomNumberGenerator, lat := FRONT_LAT, tables := false) -> void:
	var s: float = s0
	while s < s1:
		var w_life: float = rng.randf_range(10.5, 16.0)
		var w: float = w_life * PROP_SCALE
		if s + w > s1:
			break
		var sc: float = s + w * 0.5
		var sp: Dictionary = _spot(sc, side * lat, 0.0)
		var face: Vector3 = -(sp["right"] as Vector3) * side
		var front: Vector3 = sp["pos"]
		var p2 := Vector2(front.x, front.z)
		if _in_moat_park(p2.x, p2.y) or _route_dist(p2.x - face.x * 4.0, p2.y - face.z * 4.0) < lat - 1.0:
			s += 4.0
			continue
		front.y = _ground_range(Vector2(front.x, front.z) - Vector2(face.x, face.z) * HOUSE_DEPTH * 0.8, w, HOUSE_DEPTH * 1.6, 0.0).x + 0.02
		front.y = minf(front.y, _lap_y(sc) + 0.05)
		var xf: Transform3D = _facing(face, front)
		xf.origin -= xf.basis.x * (w * 0.5)
		var d: float = HOUSE_DEPTH * PROP_SCALE
		var centre: Vector3 = front - face * (d * 0.5)
		if not _clear(centre, xf.basis.x, w, d):
			s += 4.0
			continue
		_house(xf, w_life, rng, tables)
		_note_xf(xf, 0.0, w, -d, 0.0, 0.2)
		s += w + rng.randf_range(0.0, 0.6)


## One Gründerzeit house in its frame (front-left corner at the origin, facing +z): the detailed one near, the plain one
## far (the same plan from the same seed).
func _house(xf: Transform3D, w_life: float, rng: RandomNumberGenerator, tables: bool, detail := true) -> void:
	var floors: int = rng.randi_range(4, 5) + int(rng.randf() < 0.2)
	var variant: int = rng.randi_range(0, 3)
	var seed_v: int = rng.randi()
	var number: int = rng.randi_range(2, 88)
	var key_near: String = _cell_key("haus", xf.origin)
	var key_far: String = _cell_key("hausfern", xf.origin, 280.0)
	if not detail:
		_add_prop(key_far + "_x", _rhein, xf, func(pk, kit, _labels):
			var hr3 := RandomNumberGenerator.new()
			hr3.seed = seed_v
			_kit_call(_rhein, "gruenderzeit_house_far", [pk, kit, w_life, floors, variant, hr3, HOUSE_DEPTH]), 2400.0)
		_house_count += 1
		return
	_add_prop(key_near, _rhein, xf, func(pk, kit, labels):
		var hr := RandomNumberGenerator.new()
		hr.seed = seed_v
		_kit_call(_rhein, "gruenderzeit_house", [pk, kit, labels, w_life, floors, variant, hr, HOUSE_DEPTH, number, tables]), HOUSE_NEAR)
	_add_prop(key_far, _rhein, xf, func(pk, kit, _labels):
		var hr2 := RandomNumberGenerator.new()
		hr2.seed = seed_v
		_kit_call(_rhein, "gruenderzeit_house_far", [pk, kit, w_life, floors, variant, hr2, HOUSE_DEPTH]), 2400.0, HOUSE_NEAR - 60.0)
	_house_count += 1


func _build_city(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7301
	var t1: Dictionary = _turn(1)
	var t2: Dictionary = _turn(2)
	var t3: Dictionary = _turn(3)
	var t4: Dictionary = _turn(4)
	var station_s0: float = _closest_s(Vector2(STATION_X - 64.0 * PROP_SCALE - 4.0, 0.0))
	var station_s1: float = _closest_s(Vector2(STATION_X + 64.0 * PROP_SCALE + 4.0, 0.0))
	# The Kaiserstraße: the station on the left (north), the start's grandstand opposite it.
	_frontage(8.0, station_s0, -1.0, rng)
	_frontage(station_s1, float(t1["s0"]) - 14.0, -1.0, rng)
	_frontage(8.0, GRAND_S0 - 4.0, 1.0, rng)
	_frontage(GRAND_S1 + 4.0, float(t1["s0"]) - 14.0, 1.0, rng)
	# South to the moat and on to the pedestrian zone.
	for side in [-1.0, 1.0]:
		_frontage(float(t1["s1"]) + 14.0, float(t2["s0"]) - 14.0, side, rng)
	# The pedestrian zone: the Kaufhaus on the left, a little square with the fountain on the right.
	var z0: float = float(t2["s1"]) + 6.0
	var z1: float = float(t3["s0"]) - 6.0
	var ks: float = _closest_s(Vector2(KAUFHAUS_X, 270.0))
	var kw: float = KAUFHAUS_W * PROP_SCALE
	_frontage(z0, ks - kw * 0.5 - 2.0, -1.0, rng, PED_FRONT, true)
	_frontage(ks + kw * 0.5 + 2.0, z1, -1.0, rng, PED_FRONT, true)
	var fs: float = _closest_s(Vector2(FOUNTAIN_X, 270.0))
	_frontage(z0, fs - 26.0, 1.0, rng, PED_FRONT, true)
	_frontage(fs + 26.0, z1, 1.0, rng, PED_FRONT, true)
	# North under the railway, then east to the Ring.
	for side in [-1.0, 1.0]:
		_frontage(float(t3["s1"]) + 14.0, s_under1 - EMBANK_HALF - 6.0, side, rng)
		_frontage(s_under1 + EMBANK_HALF + 6.0, float(t4["s0"]) - 14.0, side, rng)
		_frontage(float(t4["s1"]) + 14.0, s_ring - RING_HALF - 8.0, side, rng)
	print("  city: %d houses" % _house_count)
	_build_kaufhaus()
	_build_pedestrian_zone(rng)
	_build_moat()
	_build_street_furniture(rng)
	_build_city_blocks(root)


const KAUFHAUS_X := -480.0
const KAUFHAUS_W := 60.0
const KAUFHAUS_D := 40.0
const FOUNTAIN_X := -470.0


func _build_kaufhaus() -> void:
	var s: float = _closest_s(Vector2(KAUFHAUS_X, 270.0))
	var sp: Dictionary = _spot(s, -PED_FRONT, 0.0)
	var face: Vector3 = sp["right"]
	var at: Vector3 = sp["pos"]
	at.y = _lap_y(s) - 0.02
	var xf: Transform3D = _facing(face, at)
	_add_prop("kaufhaus", _stadt, xf, func(pk, kit, labels): _kit_call(_stadt, "department_store", [pk, kit, labels, KAUFHAUS_W, KAUFHAUS_D]), 2400.0)
	var body := _body(level, "KaufhausBody", "rock")
	_solids(body, _kit_call(_stadt, "department_store_solids", [KAUFHAUS_W, KAUFHAUS_D]), xf)
	_note_xf(xf, -KAUFHAUS_W * 0.5 * PROP_SCALE, KAUFHAUS_W * 0.5 * PROP_SCALE, -KAUFHAUS_D * PROP_SCALE, 2.0, 1.0)


## The pedestrian zone between the shop fronts: café terraces, planters, benches, bike racks, lamps, the fountain.
func _build_pedestrian_zone(rng: RandomNumberGenerator) -> void:
	var body := _body(level, "FussgaengerzoneBody", "rock")
	var t2: Dictionary = _turn(2)
	var t3: Dictionary = _turn(3)
	var fs: float = _closest_s(Vector2(FOUNTAIN_X, 270.0))
	var fsp: Dictionary = _spot(fs, PED_FRONT + 6.0, 0.0)
	var fpos: Vector3 = fsp["pos"]
	fpos.y = _lap_y(fs) - 0.03
	var fxf: Transform3D = _facing(-(fsp["right"] as Vector3), fpos)
	_add_prop("zone_fountain", _stadt, fxf, func(pk, kit, _labels): _kit_call(_stadt, "city_fountain", [pk, kit]), 900.0)
	_solids(body, _kit_call(_stadt, "city_fountain_solids", []), fxf)
	_note_rect(Vector2(fpos.x, fpos.z), 16.0, 16.0, 0.0)
	var s: float = float(t2["s1"]) + 14.0
	var n := 0
	while s < float(t3["s0"]) - 14.0:
		for side in [-1.0, 1.0]:
			var lat: float = side * (PED_FRONT - 4.3)
			var sp: Dictionary = _spot(s + side * 6.0, lat, 0.0)
			var p: Vector3 = sp["pos"]
			p.y = _lap_y(s) - 0.03
			if absf(s - fs) < 24.0 and side > 0.0:
				continue
			var face: Vector3 = -(sp["right"] as Vector3) * side
			var xf: Transform3D = _facing(face, p)
			var roll: float = rng.randf()
			var seed_v: int = rng.randi()
			if roll < 0.45:
				_add_prop(_cell_key("zone", p), _stadt, xf, func(pk, kit, _labels): _kit_call(_stadt, "cafe_terrace", [pk, kit, 5.5, 2.6, seed_v]), 600.0)
			elif roll < 0.7:
				_add_prop(_cell_key("zone", p), _stadt, xf, func(pk, kit, _labels): _kit_call(_stadt, "planter", [pk, kit, seed_v]), 500.0)
				_box(body, Transform3D(Basis(), p + Vector3(0, 0.6, 0)), Vector3(2.4, 1.2, 2.4))
			elif roll < 0.85:
				_add_prop(_cell_key("zone", p), _stadt, xf, func(pk, kit, _labels): _kit_call(_stadt, "bike_rack", [pk, kit, 5]), 400.0)
			else:
				_add_prop(_cell_key("zone", p), _rhein, xf, func(pk, kit, _labels): _kit_call(_rhein, "bench", [pk, kit]), 400.0)
			n += 1
			var lp: Dictionary = _spot(s, side * (PED_FRONT - 7.3), 0.0)
			var lpos: Vector3 = lp["pos"]
			lpos.y = _lap_y(s) - 0.03
			_add_prop(_cell_key("lamps", lpos, 300.0), _rhein, _facing(face, lpos), func(pk, kit, _labels): _kit_call(_rhein, "promenade_lamp", [pk, kit]), 600.0)
			_box(body, Transform3D(Basis(), lpos + Vector3(0, 3.0, 0)), Vector3(0.5, 6.0, 0.5))
		s += 22.0
	print("  pedestrian zone: %d groups" % n)


## The moat's park: the bridge over it (GardenKit.stone_bridge, the city's style) and its railings' colliders.
func _build_moat() -> void:
	var length: float = MOAT_BRIDGE[0]
	var rise: float = MOAT_BRIDGE[1]
	var half: float = MOAT_BRIDGE[2]
	var end_y: float = _lap_y(s_moat - length * PROP_SCALE * 0.5 - 2.0)
	var sp: Dictionary = _spot(s_moat, 0.0, 0.0)
	var at := Vector3((sp["pos"] as Vector3).x, end_y, (sp["pos"] as Vector3).z)
	var xf: Transform3D = _facing(sp["fwd"], at)
	var wy: float = (MOAT_WATER - end_y) / PROP_SCALE
	_add_prop("moat_bridge", _garden, xf, func(pk, kit, labels): _kit_call(_garden, "stone_bridge", [pk, kit, length, rise, half, wy, 0]), 1600.0)
	var body := _body(level, "MoatBridgeBody", "rock")
	_solids(body, _kit_call(_garden, "stone_bridge_solids", [length, rise, half, wy, 0]), xf)
	# Railings either side along the deck in any case (the kit's own boxes, if any, overlap them harmlessly).
	_route_edge_boxes(body, s_moat - length * PROP_SCALE * 0.5, s_moat + length * PROP_SCALE * 0.5, half * PROP_SCALE + 0.55, 1.3)
	_route_edge_boxes(body, s_moat - length * PROP_SCALE * 0.5, s_moat + length * PROP_SCALE * 0.5, -half * PROP_SCALE - 0.55, 1.3)


## Boxes along the route from s0 to s1, `lat` across (right +), `h` high over the road: railings and kerb walls.
func _route_edge_boxes(body: StaticBody3D, s0: float, s1: float, lat: float, h: float, thick := 0.5) -> void:
	var s: float = s0
	while s < s1:
		var sb: float = minf(s + 4.0, s1)
		var a: Vector3 = _pt(s) + _rt(s) * lat
		var b: Vector3 = _pt(sb) + _rt(sb) * lat
		var mid: Vector3 = (a + b) * 0.5
		var dir: Vector3 = b - a
		var length: float = dir.length()
		if length > 0.05:
			var z: Vector3 = dir / length
			var x: Vector3 = Vector3.UP.cross(z).normalized()
			var y: Vector3 = z.cross(x).normalized()
			_box(body, Transform3D(Basis(x, y, z), mid + Vector3(0, h * 0.5 - 0.2, 0)), Vector3(thick, h + 0.4, length + 0.3))
		s = sb


## Whip-arm lamps along the streets, old lanterns on the moat bridge, the U-Bahn's entrance on the Kaiserplatz.
func _build_street_furniture(rng: RandomNumberGenerator) -> void:
	var kinds: Array = _road_kinds()
	var body := _body(level, "LampsBody", "rock")
	var s := 20.0
	var placed := 0
	var side := 1.0
	while s < s_ring - RING_HALF - 10.0:
		var kind: int = _kind_at(kinds, s)
		if kind == 2 and absf(_at(s)["k"]) < 0.02 and not (s > START_S - 30.0 and s < START_S + 30.0):
			var sp: Dictionary = _spot(s, side * (ROAD_HALF + 0.6), 0.0)
			var p: Vector3 = sp["pos"]
			p.y = _lap_y(s)
			var xf := _facing(-(sp["right"] as Vector3) * side, p)
			_add_prop(_cell_key("lamps", p, 300.0), _town, xf, func(pk, kit, _labels): _kit_call(_town, "peitschen_lamp", [pk, kit]), 600.0)
			_box(body, Transform3D(Basis(), p + Vector3(0, 2.5, 0)), Vector3(0.45, 5.0, 0.45))
			placed += 1
			side = -side
		s += 31.0
	# Lanterns on the bridge's ends.
	for e in [-1.0, 1.0]:
		for sd in [-1.0, 1.0]:
			var ls: float = s_moat + e * (float(MOAT_BRIDGE[0]) * PROP_SCALE * 0.5 + 3.0)
			var lp: Dictionary = _spot(ls, sd * (ROAD_HALF + PAVEMENT - 0.6), 0.0)
			var lpos: Vector3 = lp["pos"]
			lpos.y = _lap_y(ls)
			_add_prop(_cell_key("lamps", lpos, 300.0), _town, _facing(-(lp["right"] as Vector3) * sd, lpos), func(pk, kit, _labels): _kit_call(_town, "old_lantern_post", [pk, kit]), 500.0)
	# The U-Bahn's entrance on the Kaiserplatz, the Litfaßsäule, a kiosk.
	var up := Vector3(-1180.0, CITY_Y, 34.0)
	var uxf := _facing(Vector3(1, 0, 0), up)
	_add_prop("kaiserplatz_ubahn", _stadt, uxf, func(pk, kit, labels): _kit_call(_stadt, "u_bahn_entrance", [pk, kit, labels]), 700.0)
	_solids(body, _kit_call(_stadt, "u_bahn_entrance_solids", []), uxf)
	_note_rect(Vector2(up.x, up.z), 14.0, 10.0, 0.0)
	var lit := Vector3(-1205.0, CITY_Y, -24.0)
	_add_prop("kaiserplatz_litfass", _town, _facing(Vector3(1, 0, 0), lit), func(pk, kit, _labels): _kit_call(_town, "litfass", [pk, kit]), 500.0)
	_box(body, Transform3D(Basis(), lit + Vector3(0, 2.0, 0)), Vector3(2.0, 4.0, 2.0))
	print("  street lamps: %d" % placed)


# ======================================================================================
#  The city behind: plain blocks of flats round courtyards (city_building.gdshader), cheap, for the views over the roofs
# ======================================================================================

const BLOCK_X := Vector2(-1500.0, 40.0)
const BLOCK_Z := Vector2(-620.0, 360.0)
const BLOCK_STEP := Vector2(118.0, 104.0)
const BLOCK_STREET := 22.0

func _build_city_blocks(root: Node3D) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://city_building.gdshader")
	mat.set_shader_parameter("concrete_tex", load("res://materials/concrete.png"))
	mat.set_shader_parameter("storey", 5.4)
	mat.set_shader_parameter("bay", 4.8)
	mat.set_shader_parameter("shop_h", 6.4)
	var smat: Material = _save_res(mat, "block_material", FAR_PREFIX)
	var roof_mat := StandardMaterial3D.new()
	roof_mat.vertex_color_use_as_albedo = true
	roof_mat.vertex_color_is_srgb = true
	roof_mat.roughness = 0.8
	var rmat: Material = _save_res(roof_mat, "block_roof_material", FAR_PREFIX)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7302
	var cells := {}
	var count := 0
	var palette: Array = [Color(0.86, 0.80, 0.66), Color(0.80, 0.70, 0.60), Color(0.76, 0.78, 0.74), Color(0.88, 0.84, 0.76),
		Color(0.72, 0.62, 0.52), Color(0.82, 0.76, 0.62), Color(0.70, 0.72, 0.70), Color(0.90, 0.86, 0.80)]
	var bx: float = BLOCK_X.x
	while bx < BLOCK_X.y:
		var bz: float = BLOCK_Z.x
		while bz < BLOCK_Z.y:
			var x0: float = bx + BLOCK_STREET * 0.5
			var x1: float = bx + BLOCK_STEP.x - BLOCK_STREET * 0.5
			var z0: float = bz + BLOCK_STREET * 0.5
			var z1: float = bz + BLOCK_STEP.y - BLOCK_STREET * 0.5
			bz += BLOCK_STEP.y
			var c := Vector2((x0 + x1) * 0.5, (z0 + z1) * 0.5)
			if absf(c.y - RAIL_Z) < 70.0 or _in_moat_park(c.x, c.y) or c.y > _edge_z(c.x) - 70.0:
				continue
			if c.x > STATION_X - 140.0 and c.x < STATION_X + 140.0 and c.y < 30.0 and c.y > -260.0:
				continue
			# Each side of the block is a row of houses 14m deep unless the route's frontage stands there.
			var sides: Array = [[Vector2(x0, z0), Vector2(x1, z0), Vector2(0, -1)], [Vector2(x1, z0), Vector2(x1, z1), Vector2(1, 0)],
				[Vector2(x1, z1), Vector2(x0, z1), Vector2(0, 1)], [Vector2(x0, z1), Vector2(x0, z0), Vector2(-1, 0)]]
			for sd in sides:
				var a: Vector2 = sd[0]
				var b: Vector2 = sd[1]
				var out: Vector2 = sd[2]
				var mid: Vector2 = (a + b) * 0.5
				if _route_dist(mid.x, mid.y) < 46.0 or _route_dist(a.x, a.y) < 34.0 or _route_dist(b.x, b.y) < 34.0:
					continue
				if absf(mid.x - RING_X) < RING_HALF + 30.0 and mid.y < RING_PORTAL_Z + 40.0:
					continue
				# The row in houses of 12-20m, each its own height and colour.
				var dir: Vector2 = (b - a).normalized()
				var total: float = a.distance_to(b)
				# A row starts one house deep in from its corner: the row before it fills the corner. Both filled it, and
				# their walls (and gables) lay in one plane there and flickered.
				var u := 14.0
				while u < total - 4.0:
					var w: float = minf(rng.randf_range(12.0, 20.0), total - u)
					var pa: Vector2 = a + dir * u
					var pb: Vector2 = a + dir * (u + w)
					var h: float = rng.randf_range(15.0, 23.0)
					var col: Color = palette[rng.randi_range(0, palette.size() - 1)]
					col.a = 0.0
					var g: float = minf(_ground_at(pa.x, pa.y), _ground_at(pb.x, pb.y)) - 0.5
					var key := Vector2i(floori(pa.x / 300.0), floori(pa.y / 300.0))
					if not cells.has(key):
						cells[key] = [SurfaceTool.new(), SurfaceTool.new()]
						(cells[key][0] as SurfaceTool).begin(Mesh.PRIMITIVE_TRIANGLES)
						(cells[key][1] as SurfaceTool).begin(Mesh.PRIMITIVE_TRIANGLES)
					_block_house(cells[key][0], cells[key][1], pa, pb, -out, 14.0, g, h, col, rng.randf())
					u += w
					count += 1
		# Without this the loop never ended: it ate the memory, filled the disk with swap and took the Mac down twice.
		bx += BLOCK_STEP.x
	var node := Node3D.new()
	node.name = "Stadtbloecke"
	root.add_child(node)
	for key in cells.keys():
		var wall: ArrayMesh = (cells[key][0] as SurfaceTool).commit()
		wall.surface_set_material(0, smat)
		var mi := MeshInstance3D.new()
		mi.name = "Block_%d_%d" % [key.x, key.y]
		var both := ArrayMesh.new()
		var arr: Array = wall.surface_get_arrays(0)
		both.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		both.surface_set_material(0, smat)
		var roofs: ArrayMesh = (cells[key][1] as SurfaceTool).commit()
		if roofs.get_surface_count() > 0:
			both.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, roofs.surface_get_arrays(0))
			both.surface_set_material(1, rmat)
		mi.mesh = _save_res(both, "block_%d_%d" % [key.x, key.y], FAR_PREFIX)
		mi.visibility_range_end = 3200.0
		node.add_child(mi)
	print("  city blocks: %d houses in %d cells" % [count, cells.size()])


## One plain house of a block row: its front from pa to pb facing away from the courtyard (`inward` points into it),
## `d` deep, walls to `h` over `g`, a mansard-ish roof. Walls: UV (metres along, metres up), city_building's block facade.
func _block_house(walls: SurfaceTool, roofs: SurfaceTool, pa: Vector2, pb: Vector2, inward: Vector2, d: float, g: float, h: float, col: Color, style: float) -> void:
	var a := Vector3(pa.x, g, pa.y)
	var b := Vector3(pb.x, g, pb.y)
	var inn := Vector3(inward.x, 0.0, inward.y)
	var c: Vector3 = b + inn * d
	var e: Vector3 = a + inn * d
	var top := Vector3(0, h, 0)
	var corners: Array = [a, b, c, e]
	var run := 0.0
	for k in range(4):
		var p: Vector3 = corners[k]
		var q: Vector3 = corners[(k + 1) % 4]
		var length: float = p.distance_to(q)
		var n: Vector3 = (q - p).cross(Vector3.UP).normalized()
		# The quad faces out of the house: its normal away from the middle.
		var mid: Vector3 = (a + b + c + e) * 0.25
		if n.dot((p + q) * 0.5 - mid) < 0.0:
			n = -n
		var quad: Array = [p, q, q + top, p + top]
		var uvs: Array = [Vector2(run, 0), Vector2(run + length, 0), Vector2(run + length, h + 0.5), Vector2(run, h + 0.5)]
		for t in [[0, 1, 2], [0, 2, 3]]:
			var v0: Vector3 = quad[t[0]]
			var v1: Vector3 = quad[t[1]]
			var v2: Vector3 = quad[t[2]]
			var order: Array = t
			if (v2 - v0).cross(v1 - v0).dot(n) < 0.0:
				order = [t[0], t[2], t[1]]
			for idx in order:
				walls.set_normal(n)
				walls.set_color(col)
				walls.set_uv(uvs[idx])
				walls.set_uv2(Vector2((uvs[idx] as Vector2).x, style))
				walls.add_vertex(quad[idx])
		run += length
	# The roof: a mansard, its slopes rising from the eaves to a ridge along the front's middle line, slate grey.
	var slate := Color(0.30, 0.31, 0.34)
	var r_up: float = 4.2
	var ridge_a: Vector3 = (a + e) * 0.5 + top + Vector3(0, r_up, 0)
	var ridge_b: Vector3 = (b + c) * 0.5 + top + Vector3(0, r_up, 0)
	var faces: Array = [[a + top, b + top, ridge_b, ridge_a], [c + top, e + top, ridge_a, ridge_b]]
	for f in faces:
		var n2: Vector3 = ((f[1] as Vector3) - (f[0] as Vector3)).cross((f[3] as Vector3) - (f[0] as Vector3)).normalized()
		if n2.y < 0.0:
			n2 = -n2
		for t in [[0, 1, 2], [0, 2, 3]]:
			var v0: Vector3 = f[t[0]]
			var v1: Vector3 = f[t[1]]
			var v2: Vector3 = f[t[2]]
			var order: Array = t
			if (v2 - v0).cross(v1 - v0).dot(n2) < 0.0:
				order = [t[0], t[2], t[1]]
			for idx in order:
				roofs.set_normal(n2)
				roofs.set_color(slate)
				roofs.add_vertex(f[idx])
	for tri in [[a + top, ridge_a, e + top], [b + top, c + top, ridge_b]]:
		var n3: Vector3 = ((tri[2] as Vector3) - (tri[0] as Vector3)).cross((tri[1] as Vector3) - (tri[0] as Vector3)).normalized()
		var outward: Vector3 = ((tri[0] as Vector3) - (a + b + c + e) * 0.25)
		outward.y = 0.0
		var order2: Array = [0, 1, 2]
		if n3.dot(outward) < 0.0:
			order2 = [0, 2, 1]
			n3 = -n3
		for idx in order2:
			roofs.set_normal(n3)
			roofs.set_color(slate)
			roofs.add_vertex(tri[idx])


## A row of houses along a straight line from `a` toward `b` (their fronts on it), facing `face`; detailed within
## `near` of `focus`, plain beyond.
func _row(a: Vector3, b: Vector3, face: Vector3, rng: RandomNumberGenerator, focus: Vector2, near: float) -> void:
	var dir: Vector3 = b - a
	dir.y = 0.0
	var total: float = dir.length()
	dir /= total
	var x := 0.0
	while x < total:
		var w_life: float = rng.randf_range(10.5, 16.0)
		var w: float = w_life * PROP_SCALE
		if x + w > total:
			break
		var at: Vector3 = a + dir * x
		var mid: Vector3 = at + dir * (w * 0.5)
		var d: float = HOUSE_DEPTH * PROP_SCALE
		at.y = _ground_range(Vector2(mid.x, mid.z) - Vector2(face.x, face.z) * d * 0.5, w, d, 0.0).x + 0.02
		var xf := Transform3D(Basis(dir, Vector3.UP, face), at)
		if xf.basis.determinant() < 0.0:
			xf = Transform3D(Basis(-dir, Vector3.UP, face), at + dir * w)
		var centre: Vector3 = mid - face * (d * 0.5)
		if not _clear(centre, dir, w, d) or _route_dist(centre.x, centre.z) < 18.0:
			x += 4.0
			continue
		_house(xf, w_life, rng, false, Vector2(mid.x, mid.z).distance_to(focus) < near)
		_note_xf(xf, 0.0, w, -d, 0.0, 0.2)
		x += w + rng.randf_range(0.0, 0.6)


# ======================================================================================
#  The Ring: the traffic (CrossTraffic.gd), the trams' catenary, the lights (out of order, flashing amber), the tram
#  stop, the tunnel it dives into south of the crossing, the houses along its west side
# ======================================================================================

## Ring lanes (x from its middle, + runs north): the inner and outer lane each way, and the trams.
const RING_LANES := [8.6, 14.2, -8.6, -14.2, 2.4, -2.4]
const RING_PERIOD := 64.0

func _build_ring(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Ring"
	root.add_child(node)
	var body := _body(node, "RingFurnitureBody", "rock")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7401
	# The traffic: the vehicles' meshes at game size.
	var meshes: Array[Mesh] = []
	var kinds: Array = []
	var vehicle_defs: Array = [
		["hatchback", [Color(0.78, 0.10, 0.08)]], ["hatchback", [Color(0.88, 0.88, 0.86)]], ["hatchback", [Color(0.12, 0.22, 0.42)]],
		["saloon", [Color(0.16, 0.16, 0.17), false]], ["saloon", [Color(0.62, 0.64, 0.66), false]], ["saloon", [Color(0.93, 0.90, 0.80), true]],
		["delivery_van", [Color(0.92, 0.92, 0.90)]], ["box_truck", [0]], ["box_truck", [1]], ["city_bus", [0]],
	]
	for vd in vehicle_defs:
		var fn: String = vd[0]
		var extra: Array = vd[1]
		var m: ArrayMesh = _kit_mesh_game(_stadt, "ring_%s_%d" % [fn, meshes.size()], func(pk, kit):
			_kit_call(_stadt, fn, [pk, kit] + extra))
		if m != null:
			meshes.append(m)
			kinds.append(fn)
	var tram_kinds := PackedInt32Array()
	for tv in [0, 1]:
		var tm: ArrayMesh = _kit_mesh_game(_stadt, "ring_tram_%d" % tv, func(pk, kit): _kit_call(_stadt, "tram", [pk, kit, tv]))
		if tm != null:
			tram_kinds.append(meshes.size())
			meshes.append(tm)
			kinds.append("tram")
	if meshes.is_empty():
		# No StadtKit yet: CampKit's vans and SUVs stand in.
		var pk := PropKit.new()
		pk.material_for = func(key: String) -> Material: return _camp_material(key)
		var camp := CampKit.new(pk)
		for k in [["van", Color(0.92, 0.92, 0.90)], ["suv", Color(0.16, 0.18, 0.22)], ["suv", Color(0.62, 0.10, 0.10)]]:
			var kit := {}
			pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * PROP_SCALE), Vector3.ZERO))
			camp.vehicle(kit, k[0], k[1])
			meshes.append(_save_res(pk.commit(kit), "ring_camp_%d" % meshes.size(), PROP_PREFIX))
			kinds.append(k[0])
	var slots := PackedFloat32Array()
	var cars: Array = []
	var buses: Array = []
	for i in range(kinds.size()):
		if kinds[i] == "city_bus" or kinds[i] == "box_truck":
			buses.append(i)
		elif kinds[i] != "tram":
			cars.append(i)
	# Platoons, as if let go by the lights up the road: northbound reach the crossing from 0 to about 22s into the cycle,
	# southbound from 32 to 54; between them the road is clear both ways.
	for dir_i in range(2):
		var t0: float = 0.0 if dir_i == 0 else 32.0
		for lane_k in range(2):
			var lane: int = dir_i * 2 + lane_k
			var v: float = 14.6 if lane_k == 0 else 13.4
			var t: float = t0 + rng.randf_range(0.0, 1.2) + float(lane_k) * 1.3
			while t < t0 + 20.0:
				var kind: int = cars[rng.randi_range(0, cars.size() - 1)] if not cars.is_empty() else 0
				if not buses.is_empty() and lane_k == 1 and rng.randf() < 0.22:
					kind = buses[rng.randi_range(0, buses.size() - 1)]
				slots.append_array(PackedFloat32Array([float(lane), float(kind), t, v]))
				var length: float = meshes[kind].get_aabb().size.z
				t += length / v + rng.randf_range(1.5, 2.8)
	if not tram_kinds.is_empty():
		slots.append_array(PackedFloat32Array([4.0, float(tram_kinds[0]), 9.0, 11.5]))
		slots.append_array(PackedFloat32Array([5.0, float(tram_kinds[tram_kinds.size() - 1]), 41.0, 11.5]))
	var traffic := Node3D.new()
	traffic.name = "RingTraffic"
	traffic.set_script(load("res://CrossTraffic.gd"))
	traffic.position = Vector3(RING_X, CITY_Y, RING_CROSS.y)
	traffic.set("meshes", meshes)
	traffic.set("lanes", PackedFloat32Array(RING_LANES))
	traffic.set("slots", slots)
	traffic.set("period", RING_PERIOD)
	var zn: float = RING_Z0 + 20.0 - RING_CROSS.y
	var zs: float = RING_PORTAL_Z + 110.0 - RING_CROSS.y
	traffic.set("z_north", zn)
	traffic.set("z_south", zs)
	var hts := PackedFloat32Array()
	var zz: float = zn
	while zz <= zs + 10.0:
		var wz: float = zz + RING_CROSS.y
		hts.append((_ring_y(wz) if wz < RING_PORTAL_Z + 34.0 else CITY_Y - RING_DROP - (wz - RING_PORTAL_Z - 34.0) * 0.04) - CITY_Y)
		zz += 10.0
	traffic.set("heights", hts)
	traffic.set("height_step", 10.0)
	traffic.set("crossing_z", 0.0)
	traffic.set("band", ROAD_HALF + 1.6)
	traffic.set("tram_kinds", tram_kinds)
	traffic.set("bells", _streams(["res://sounds/stadtrallye/tram_bell_1.wav", "res://sounds/stadtrallye/tram_bell_2.wav"]))
	traffic.set("horns", _streams(["res://sounds/stadtrallye/car_horn_1.wav", "res://sounds/stadtrallye/car_horn_2.wav", "res://sounds/stadtrallye/car_horn_3.wav"]))
	traffic.set("tram_sound", _stream("res://sounds/stadtrallye/tram_pass_loop.wav"))
	# Engines in town (tools/elevenlabs, levelled by their RMS): hatchbacks the small car, saloons the SUV's softer note,
	# the vans and the camp's stand-ins the diesel van, trucks and the bus the bus; the trams none (their own rumble).
	var engine_of := {"hatchback": 0, "saloon": 1, "delivery_van": 2, "van": 2, "suv": 1, "box_truck": 3, "city_bus": 3}
	var ke := PackedInt32Array()
	for k in kinds:
		ke.append(int(engine_of.get(k, -1)))
	traffic.set("engine_sounds", _streams(["res://sounds/stadtrallye/city_car_loop.wav", "res://sounds/stadtrallye/city_suv_loop.wav",
		"res://sounds/stadtrallye/city_van_loop.wav", "res://sounds/stadtrallye/city_bus_loop.wav"]))
	traffic.set("engine_rms", PackedFloat32Array([-39.2, -31.9, -33.6, -36.2]))
	traffic.set("kind_engine", ke)
	node.add_child(traffic)
	var gate := Node3D.new()
	gate.name = "RingCrossingGate"
	gate.set_script(load("res://HazardGate.gd"))
	var gsp: Dictionary = _spot(s_ring, 0.0, 0.0)
	gate.position = gsp["pos"]
	gate.rotation_degrees = Vector3(0, gsp["yaw"], 0)
	gate.set("hazard", NodePath("../RingTraffic"))
	gate.set("ai_stop_short", RING_HALF + 3.0)
	gate.set("road_half", ROAD_HALF)
	gate.set("reach", RING_HALF)
	_add_hazard_gate(node, gate)
	print("  Ring: %d vehicles a cycle of %.0fs (%d kinds)" % [slots.size() / 4, RING_PERIOD, meshes.size()])
	_build_catenary(node)
	_build_ring_furniture(node, body, rng)
	_build_ring_tunnel(node)
	# The houses along the Ring's west side, facing it; along its east side north of the garden.
	var west: float = RING_X - RING_HALF - 0.2
	_row(Vector3(west, CITY_Y, RING_Z0 + 40.0), Vector3(west, CITY_Y, RING_CROSS.y - 20.0), Vector3(1, 0, 0), rng, RING_CROSS, 300.0)
	_row(Vector3(west, CITY_Y, RING_CROSS.y + 20.0), Vector3(west, CITY_Y, RAIL_Z - EMBANK_HALF - 6.0), Vector3(1, 0, 0), rng, RING_CROSS, 300.0)
	_row(Vector3(west, CITY_Y, RAIL_Z + EMBANK_HALF + 6.0), Vector3(west, CITY_Y, RING_RAMP_Z), Vector3(1, 0, 0), rng, RING_CROSS, 300.0)
	var east: float = RING_X + RING_HALF + 0.2
	_row(Vector3(east, CITY_Y, float(GARDEN_RECT[1]) - 30.0), Vector3(east, CITY_Y, RING_Z0 + 40.0), Vector3(-1, 0, 0), rng, RING_CROSS, 300.0)
	_row(Vector3(east, CITY_Y, RAIL_Z + EMBANK_HALF + 6.0), Vector3(east, CITY_Y, RING_RAMP_Z), Vector3(-1, 0, 0), rng, RING_CROSS, 300.0)


## A kit's mesh at game size (a vehicle for a MultiMesh), its materials shared.
func _kit_mesh_game(script: Script, mesh_name: String, build: Callable) -> ArrayMesh:
	if script == null:
		return null
	var pk: PropKit = script.new_kit(PROP_SCALE)
	var kit := {}
	build.call(pk, kit)
	if kit.is_empty():
		return null
	var mesh: ArrayMesh = script.commit(pk, kit)
	_share_materials(mesh)
	return _save_res(mesh, mesh_name, PROP_PREFIX)


## The trams' overhead line: masts on the median's kerbs every 40m with arms over each track, the contact wires and the
## messenger wires between them.
func _build_catenary(node: Node3D) -> void:
	var wire_y_life := 6.0
	var reach_life: float = (5.0 - 2.4) / PROP_SCALE
	var zs: Array = []
	var z: float = RING_Z0 + 30.0
	while z < RING_RAMP_Z - 10.0:
		if absf(z - RING_CROSS.y) > ROAD_HALF + 8.0 and absf(z - RAIL_Z) > EMBANK_HALF + 4.0:
			zs.append(z)
		z += 40.0
	var pk := PropKit.new()
	pk.material_for = func(key: String) -> Material: return _camp_material(key)
	var kit := {}
	for zz in zs:
		for sd in [1.0, -1.0]:
			var at := Vector3(RING_X + sd * 5.0, _ring_y(zz), zz)
			# The arm reaches toward -x in the mast's frame: turned so it reaches toward the median's middle.
			var xf := Transform3D(Basis(Vector3.UP, 0.0 if sd > 0.0 else PI), at)
			_add_prop(_cell_key("catenary", at, 300.0), _stadt, xf, func(pk2, kit2, _labels): _kit_call(_stadt, "catenary_mast", [pk2, kit2, reach_life, wire_y_life]), 900.0)
	# The wires: a contact wire over each track and a messenger above it, mast to mast.
	var wire_y: float = wire_y_life * PROP_SCALE
	for tx in [2.4, -2.4]:
		for k in range(zs.size() - 1):
			var za: float = zs[k]
			var zb: float = zs[k + 1]
			var a := Vector3(RING_X + tx, _ring_y(za) + wire_y, za)
			var b := Vector3(RING_X + tx, _ring_y(zb) + wire_y, zb)
			pk.beam(kit, "metal", a, b, 0.035, 0.035, Color(0.30, 0.24, 0.18))
			pk.beam(kit, "metal", a + Vector3(0, 1.1, 0), b + Vector3(0, 1.1, 0), 0.03, 0.03, Color(0.28, 0.24, 0.20))
	if not kit.is_empty():
		var mi := MeshInstance3D.new()
		mi.name = "Fahrleitung"
		mi.mesh = _save_res(pk.commit(kit), "catenary_wires", PROP_PREFIX)
		mi.visibility_range_end = 700.0
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mi)


## The lights at the crossing (flashing amber: out of order), the tram stop north of it, the signs.
func _build_ring_furniture(_node: Node3D, body: StaticBody3D, _rng: RandomNumberGenerator) -> void:
	var cz: float = RING_CROSS.y
	for c in [[1.0, 1.0], [1.0, -1.0], [-1.0, 1.0], [-1.0, -1.0]]:
		var at := Vector3(RING_X + c[0] * (RING_CARR + 1.2), CITY_Y, cz + c[1] * (ROAD_HALF + PAVEMENT + 1.5))
		# Facing the traffic coming toward it: the north-side lights face north (-z), the arm reaching over the lanes.
		var face := Vector3(0, 0, -1) if c[1] < 0.0 else Vector3(0, 0, 1)
		var xf: Transform3D = _facing(face, at)
		if xf.basis.x.dot(Vector3(-c[0], 0, 0)) < 0.0:
			xf.basis = xf.basis * Basis(Vector3.UP, PI)
		var arm: float = 7.0
		_add_prop(_cell_key("ringlights", at, 300.0), _stadt, xf, func(pk, kit, _labels): _kit_call(_stadt, "traffic_light", [pk, kit, arm]), 700.0)
		_box(body, Transform3D(Basis(), at + Vector3(0, 3.0, 0)), Vector3(0.5, 6.0, 0.5))
	# The tram stop on the west pavement north of the crossing.
	var ts := Vector3(RING_X - RING_CARR - 3.4, CITY_Y, cz - 70.0)
	var txf: Transform3D = _facing(Vector3(1, 0, 0), ts)
	_add_prop("ring_tram_stop", _stadt, txf, func(pk, kit, labels): _kit_call(_stadt, "tram_stop", [pk, kit, labels, 22.0, "Botanischer Garten"]), 800.0)
	_solids(body, _kit_call(_stadt, "tram_stop_solids", [22.0]), txf)


## The Ring's ramp down into its tunnel: concrete walls along the cut, the portal, the dark inside.
func _build_ring_tunnel(node: Node3D) -> void:
	var yk: Script = load("res://YardKit.gd")
	var pk: PropKit = yk.new_kit(1.0)
	var kit := {}
	var body := _body(node, "RingTunnelBody", "rock")
	var conc := Color(0.66, 0.65, 0.61)
	var z: float = RING_RAMP_Z
	while z < RING_PORTAL_Z:
		var zb: float = minf(z + 10.0, RING_PORTAL_Z)
		for sd in [-1.0, 1.0]:
			var x: float = RING_X + sd * (RING_HALF + 0.4)
			var g: float = maxf(_ground_at(x + sd * 3.0, (z + zb) * 0.5), _ring_y(z))
			var top: float = g + 1.1
			var lo: float = _ring_y(zb) - 0.5
			pk.block(kit, "concrete", Vector3(x - 0.4, lo, z), Vector3(x + 0.4, top, zb + 0.02), conc, 1.0)
			_box(body, Transform3D(Basis(), Vector3(x, (lo + top) * 0.5, (z + zb) * 0.5)), Vector3(0.8, top - lo, zb - z))
		z = zb
	# The portal: two piers, a lintel with the tunnel's name, and the tunnel's dark inside (a box open toward the north).
	var py: float = _ring_y(RING_PORTAL_Z)
	var span: float = RING_HALF + 0.8
	var head: float = py + 7.8
	var gtop: float = _ground_at(RING_X, RING_PORTAL_Z + 20.0) + 1.0
	pk.block(kit, "concrete", Vector3(RING_X - span - 1.5, py - 0.5, RING_PORTAL_Z - 0.6), Vector3(RING_X - span + 0.2, maxf(gtop, head + 2.2), RING_PORTAL_Z + 1.0), conc, 1.0)
	pk.block(kit, "concrete", Vector3(RING_X + span - 0.2, py - 0.5, RING_PORTAL_Z - 0.6), Vector3(RING_X + span + 1.5, maxf(gtop, head + 2.2), RING_PORTAL_Z + 1.0), conc, 1.0)
	pk.block(kit, "concrete", Vector3(RING_X - span - 1.5, head, RING_PORTAL_Z - 0.8), Vector3(RING_X + span + 1.5, maxf(gtop, head + 2.2), RING_PORTAL_Z + 1.0), conc.darkened(0.08), 1.0)
	var dark := Color(0.02, 0.02, 0.02)
	pk.block(kit, "painted", Vector3(RING_X - span, head - 0.3, RING_PORTAL_Z + 1.0), Vector3(RING_X + span, head, RING_PORTAL_Z + 60.0), dark)
	pk.block(kit, "painted", Vector3(RING_X - span - 0.4, py - 1.0, RING_PORTAL_Z + 1.0), Vector3(RING_X - span, head, RING_PORTAL_Z + 60.0), dark)
	pk.block(kit, "painted", Vector3(RING_X + span, py - 1.0, RING_PORTAL_Z + 1.0), Vector3(RING_X + span + 0.4, head, RING_PORTAL_Z + 60.0), dark)
	pk.block(kit, "painted", Vector3(RING_X - span, py - 4.0, RING_PORTAL_Z + 34.0), Vector3(RING_X + span, head, RING_PORTAL_Z + 36.0), dark)
	_box(body, Transform3D(Basis(), Vector3(RING_X, (py + head) * 0.5, RING_PORTAL_Z + 35.0)), Vector3(span * 2.0, head - py + 4.0, 2.0))
	var mesh: ArrayMesh = yk.commit(pk, kit)
	_share_materials(mesh)
	var mi := MeshInstance3D.new()
	mi.name = "RingTunnel"
	mi.mesh = _save_res(mesh, "ring_tunnel", PROP_PREFIX)
	node.add_child(mi)
	var lab := Label3D.new()
	lab.text = "KAISERRING-TUNNEL"
	lab.font_size = 64
	lab.pixel_size = 0.03
	lab.modulate = Color(0.95, 0.95, 0.92)
	lab.outline_size = 4
	lab.outline_modulate = Color(0.05, 0.05, 0.05)
	lab.double_sided = false
	lab.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	lab.transform = Transform3D(Basis.looking_at(Vector3(0, 0, 1), Vector3.UP), Vector3(RING_X, head + 1.0, RING_PORTAL_Z - 0.85))
	node.add_child(lab)


# ======================================================================================
#  The Botanischer Garten (GardenKit): the fence and gates, the parterre, the Palmenhaus the route drives through, the
#  rose pergola, the lily pond and its bridge, the Alpinum round the hairpins, the belvedere, the terrace's drop
# ======================================================================================

func _build_garden(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Garten"
	root.add_child(node)
	var body := _body(node, "GartenBody", "rock")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7501
	_build_garden_fence(body)
	_build_parterre(body, rng)
	_build_palm_house(body)
	_build_pergola(body, rng)
	_build_pond(node, body, rng)
	_build_alpinum(rng)
	_build_summit(body)
	_build_terrace(body)
	_build_garden_furniture(body, rng)


## The garden's iron railing round its edge (open at the two gates), on the ground in pieces of 12m.
func _build_garden_fence(body: StaticBody3D) -> void:
	var x0: float = GARDEN_RECT[0]
	var z0: float = GARDEN_RECT[1]
	var x1: float = GARDEN_RECT[2]
	var z1: float = GARDEN_RECT[3]
	var gate_half: float = 10.4 * PROP_SCALE
	var sides: Array = [[Vector2(x0, z1), Vector2(x0, z0)], [Vector2(x0, z0), Vector2(x1, z0)], [Vector2(x1, z0), Vector2(x1, z1)], [Vector2(x1, z1), Vector2(x0, z1)]]
	var n := 0
	for sd in sides:
		var a: Vector2 = sd[0]
		var b: Vector2 = sd[1]
		var total: float = a.distance_to(b)
		var dir: Vector2 = (b - a) / total
		var u := 0.0
		while u < total - 1.0:
			var l: float = minf(12.0, total - u)
			var pa: Vector2 = a + dir * u
			var pm: Vector2 = a + dir * (u + l * 0.5)
			u += l
			if pm.distance_to(GARDEN_GATE) < gate_half or pm.distance_to(GARDEN_EXIT) < gate_half or _route_dist(pm.x, pm.y) < ROAD_HALF + 3.0:
				continue
			var g: float = minf(_ground_at(pa.x, pa.y), _ground_at(pa.x + dir.x * l, pa.y + dir.y * l))
			var x_axis := Vector3(dir.x, 0, dir.y)
			var z_axis := Vector3.UP.cross(x_axis).normalized()
			var xf := Transform3D(Basis(x_axis, Vector3.UP, -z_axis).orthonormalized(), Vector3(pa.x, g, pa.y))
			if xf.basis.determinant() < 0.0:
				xf.basis = Basis(x_axis, Vector3.UP, z_axis)
			var ll: float = l / PROP_SCALE
			_add_prop(_cell_key("gfence", xf.origin, 200.0), _garden, xf, func(pk, kit, _labels): _kit_call(_garden, "garden_fence", [pk, kit, ll]), 800.0)
			_box(body, Transform3D(xf.basis, Vector3(pm.x, g + 1.6, pm.y)), Vector3(l, 3.2, 0.6))
			n += 1
	# The gates: the main one from the Ring, the back one to the railway's underpass.
	for gd in [[s_gate, "BOTANISCHER GARTEN KRONBURG"], [s_exit, "BOTANISCHER GARTEN"]]:
		var gs: float = gd[0]
		var text: String = gd[1]
		var sp: Dictionary = _spot(gs, 0.0, 0.0)
		var at: Vector3 = sp["pos"]
		at.y = _lap_y(gs) - GROUND_UNDER
		var xf2: Transform3D = _facing(-(sp["fwd"] as Vector3), at)
		_add_prop(_cell_key("ggate", at), _garden, xf2, func(pk, kit, labels): _kit_call(_garden, "garden_gate", [pk, kit, labels, text]), 1200.0)
		_solids(body, _kit_call(_garden, "garden_gate_solids", []), xf2)
	print("  garden fence: %d pieces" % n)


## A low prop in the garden on the ground at (x, z) facing `face`, batched by cell.
func _garden_prop(key: String, at2: Vector2, face: Vector3, fn: String, args: Array, range_end := 500.0, lift := 0.0) -> Transform3D:
	var at := Vector3(at2.x, _ground_at(at2.x, at2.y) + lift, at2.y)
	var xf: Transform3D = _facing(face, at)
	_add_prop(_cell_key(key, at), _garden, xf, func(pk, kit, labels):
		var a: Array = [pk, kit]
		if fn in ["plant_label", "garden_sign", "belvedere", "greenhouse_small"]:
			a.append(labels)
		_kit_call(_garden, fn, a + args), range_end)
	return xf


## The parterre between the gate and the Palmenhaus: carpet bedding either side of the route, a round fountain, topiary.
func _build_parterre(body: StaticBody3D, rng: RandomNumberGenerator) -> void:
	var y: float = _pad_y["parterre"]
	# Long borders along both sides of the route, then round and oval beds further out.
	var s0: float = s_gate + 22.0
	var s1: float = float(_turn(5)["s0"]) - 8.0
	var s: float = s0
	var style := 0
	while s < s1 - 6.0:
		for side in [-1.0, 1.0]:
			var sp: Dictionary = _spot(s + 8.0, side * (ROAD_HALF + 5.2), 0.0)
			var p: Vector3 = sp["pos"]
			var bed_style: int = (style + int(side > 0.0)) % 6
			var seed_v: int = rng.randi()
			_garden_prop("gbeds", Vector2(p.x, p.z), -(sp["right"] as Vector3) * side, "flower_bed", [9.5, 3.6, 3, bed_style, seed_v], 450.0, 0.02)
		s += 18.0
		style += 1
	for b in [[Vector2(185.0, -245.0), 1, 12.0, 12.0], [Vector2(245.0, -245.0), 1, 12.0, 12.0], [Vector2(215.0, -275.0), 2, 16.0, 9.0],
			[Vector2(170.0, -172.0), 0, 10.0, 5.0], [Vector2(212.0, -172.0), 2, 12.0, 6.0], [Vector2(254.0, -172.0), 0, 10.0, 5.0]]:
		var c: Vector2 = b[0]
		var shape: int = b[1]
		var w: float = b[2]
		var d: float = b[3]
		var seed2: int = rng.randi()
		var st2: int = rng.randi_range(0, 4)
		_garden_prop("gbeds", c, Vector3(0, 0, 1), "flower_bed", [w, d, shape, st2, seed2], 450.0, 0.02)
		_note_rect(c, w * PROP_SCALE, d * PROP_SCALE, 0.0, 1.0)
	# The fountain on the parterre's axis north of the route.
	var fc := Vector2(215.0, -248.0)
	var fxf: Transform3D = _garden_prop("gfountain", fc, Vector3(0, 0, 1), "parterre_fountain", [], 900.0, 0.0)
	_solids(body, _kit_call(_garden, "parterre_fountain_solids", []), fxf)
	_note_rect(fc, 22.0, 22.0, 0.0)
	# Topiary along the parterre's edges: cones and balls.
	var k := 0
	for x in range(150, 290, 14):
		for z in [-290.0, -160.0]:
			var tp := Vector2(float(x), z)
			if _route_dist(tp.x, tp.y) < 12.0:
				continue
			var kind: String = ["cone", "ball", "spiral", "column"][k % 4]
			_garden_prop("gtopiary", tp, Vector3(0, 0, 1), "topiary", [kind, 2.4 if kind != "ball" else 1.6], 450.0)
			_box(body, Transform3D(Basis(), Vector3(tp.x, _ground_at(tp.x, tp.y) + 1.5, tp.y)), Vector3(1.6, 3.0, 1.6))
			k += 1


## The Palmenhaus: the route runs through it along its length.
func _build_palm_house(body: StaticBody3D) -> void:
	var sp: Dictionary = _spot(s_palm, 0.0, 0.0)
	var at: Vector3 = sp["pos"]
	at.y = _lap_y(s_palm) - GROUND_UNDER
	var xf: Transform3D = _facing(sp["fwd"], at)
	_add_prop("palmenhaus", _garden, xf, func(pk, kit, labels): _kit_call(_garden, "palm_house", [pk, kit, labels]), 2400.0)
	_solids(body, _kit_call(_garden, "palm_house_solids", []), xf)
	var half := Vector2(18.0, 32.0)
	if _garden != null and _garden.get_script_constant_map().has("PALM_HOUSE_HALF"):
		half = _garden.get_script_constant_map()["PALM_HOUSE_HALF"]
	_note_xf(xf, -half.x * PROP_SCALE, half.x * PROP_SCALE, -half.y * PROP_SCALE, half.y * PROP_SCALE, 2.0)
	# A small glasshouse beside it.
	_garden_prop("gglasshouse", Vector2(372.0, -300.0), Vector3(-1, 0, 0), "greenhouse_small", [], 900.0)
	_note_rect(Vector2(372.0, -300.0), 22.0, 14.0, 0.0)


## The rose pergola over the route east of the Palmenhaus: an arch every 6m (life), rose beds outside its posts.
func _build_pergola(body: StaticBody3D, rng: RandomNumberGenerator) -> void:
	var s0: float = _closest_s(Vector2(PERGOLA_X.x, -470.0))
	var s1: float = _closest_s(Vector2(PERGOLA_X.y, -470.0))
	var bay: float = 6.0 * PROP_SCALE
	var span: float = 13.0
	var s: float = s0
	var n := 0
	while s <= s1 + 0.1:
		var sp: Dictionary = _spot(s, 0.0, 0.0)
		var at: Vector3 = sp["pos"]
		at.y = _lap_y(s) - GROUND_UNDER
		var xf: Transform3D = _facing(-(sp["fwd"] as Vector3), at)
		var seed_v: int = rng.randi()
		var last: bool = s + bay > s1 + 0.1
		var b: float = 0.0 if last else 6.0
		_add_prop(_cell_key("pergola", at), _garden, xf, func(pk, kit, _labels): _kit_call(_garden, "rose_arch", [pk, kit, span, b, seed_v]), 900.0)
		for side in [-1.0, 1.0]:
			var pp: Vector3 = at + (sp["right"] as Vector3) * side * (span * 0.5 * PROP_SCALE)
			_box(body, Transform3D(Basis(), pp + Vector3(0, 2.5, 0)), Vector3(0.7, 5.0, 0.7))
		n += 1
		s += bay
	# Rose beds outside the posts, the length of the pergola.
	for side in [-1.0, 1.0]:
		var sm: float = (s0 + s1) * 0.5
		var sp2: Dictionary = _spot(sm, side * (span * 0.5 * PROP_SCALE + 5.0), 0.0)
		var p: Vector3 = sp2["pos"]
		var face: Vector3 = -(sp2["right"] as Vector3) * side
		var l: float = (s1 - s0) / PROP_SCALE
		var xf2: Transform3D = _facing(face, Vector3(p.x, _ground_at(p.x, p.z) + 0.02, p.z))
		xf2.origin -= xf2.basis.x * (l * 0.5 * PROP_SCALE)
		var seed_r: int = rng.randi()
		_add_prop(_cell_key("rosebeds", p), _garden, xf2, func(pk, kit, _labels): _kit_call(_garden, "rose_bed", [pk, kit, l, 3.0, seed_r]), 600.0)
	print("  pergola: %d arches" % n)


## The lily pond: its bridge (GardenKit.stone_bridge, the garden's style), lilies, rushes and irises (PondKit).
func _build_pond(node: Node3D, body: StaticBody3D, rng: RandomNumberGenerator) -> void:
	var length: float = POND_BRIDGE[0]
	var rise: float = POND_BRIDGE[1]
	var half: float = POND_BRIDGE[2]
	var end_y: float = _lap_y(s_pond - length * PROP_SCALE * 0.5 - 2.0)
	var sp: Dictionary = _spot(s_pond, 0.0, 0.0)
	var at := Vector3((sp["pos"] as Vector3).x, end_y, (sp["pos"] as Vector3).z)
	var xf: Transform3D = _facing(sp["fwd"], at)
	var wy: float = (_pond_y - end_y) / PROP_SCALE
	_add_prop("pond_bridge", _garden, xf, func(pk, kit, labels): _kit_call(_garden, "stone_bridge", [pk, kit, length, rise, half, wy, 1]), 1200.0)
	_solids(body, _kit_call(_garden, "stone_bridge_solids", [length, rise, half, wy, 1]), xf)
	_route_edge_boxes(body, s_pond - length * PROP_SCALE * 0.5, s_pond + length * PROP_SCALE * 0.5, half * PROP_SCALE + 0.55, 1.4)
	_route_edge_boxes(body, s_pond - length * PROP_SCALE * 0.5, s_pond + length * PROP_SCALE * 0.5, -half * PROP_SCALE - 0.55, 1.4)
	# The pond's plants (PondKit, as on Pinecrest Ridge): lilies on the water, bulrushes and irises round the edge.
	var pond_kit: Script = _kit_script("res://PondKit.gd")
	if pond_kit == null:
		return
	var reed := ShaderMaterial.new()
	reed.shader = load("res://dune_grass.gdshader")
	reed.set_shader_parameter("sway", 0.1)
	reed.set_shader_parameter("speed", 1.1)
	var reed_mat: Material = _save_res(reed, "mat_pond_reeds", PROP_PREFIX)
	var lily := StandardMaterial3D.new()
	lily.vertex_color_use_as_albedo = true
	lily.vertex_color_is_srgb = true
	lily.roughness = 0.38
	lily.cull_mode = BaseMaterial3D.CULL_DISABLED
	var lily_mat: Material = _save_res(lily, "mat_pond_lilies", PROP_PREFIX)
	var lily_xfs: Array = []
	var rush_xfs: Array = []
	var iris_xfs: Array = []
	for i in range(150):
		var a: float = rng.randf() * TAU
		var r: float = sqrt(rng.randf())
		var p := POND_C + Vector2(cos(a) * POND_R.x * 1.05 * r, sin(a) * POND_R.y * 1.05 * r)
		if absf(p.x - 560.0) < half * PROP_SCALE + 4.0:
			continue
		lily_xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.2, 1.8)), Vector3(p.x, _pond_y + 0.01, p.y)))
	for i in range(140):
		var a2: float = rng.randf() * TAU
		var p2 := POND_C + Vector2(cos(a2) * POND_R.x * rng.randf_range(1.02, 1.3), sin(a2) * POND_R.y * rng.randf_range(1.02, 1.3))
		if absf(p2.x - 560.0) < half * PROP_SCALE + 5.0:
			continue
		var g: float = maxf(_ground_at(p2.x, p2.y), _pond_y - 0.2)
		var xf2 := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.3, 1.7)), Vector3(p2.x, g, p2.y))
		if i % 3 == 0:
			iris_xfs.append(xf2)
		else:
			rush_xfs.append(xf2)
	_multimesh(node, "PondLilies", _save_res(pond_kit.lilies(0, lily_mat), "pond_lilies", PROP_PREFIX), lily_xfs, 400.0, false)
	_multimesh(node, "PondGrassRush", _save_res(pond_kit.bulrush(0, reed_mat), "pond_bulrush", PROP_PREFIX), rush_xfs, 400.0, false)
	_multimesh(node, "PondGrassIris", _save_res(pond_kit.iris(0, reed_mat), "pond_iris", PROP_PREFIX), iris_xfs, 300.0, false)


## The Alpinum: limestone breaking out of the slopes between the hairpins, cushion plants among the stones, dwarf pines.
func _build_alpinum(rng: RandomNumberGenerator) -> void:
	var n := 0
	var x: float = 590.0
	while x < 815.0:
		var z: float = -455.0
		while z < -345.0:
			var px: float = x + rng.randf_range(-3.0, 3.0)
			var pz: float = z + rng.randf_range(-3.0, 3.0)
			z += 6.5
			var d: float = _route_dist(px, pz)
			if d < ROAD_HALF + 2.5 or _occupied(px, pz):
				continue
			var g: float = _ground_at(px, pz)
			var slope: float = Vector2(_ground_at(px + 2.0, pz) - g, _ground_at(px, pz + 2.0) - g).length() / 2.0
			if rng.randf() > 0.35 + slope * 0.9:
				continue
			var r: float = rng.randf_range(0.5, 1.4) * (1.0 + slope * 0.6)
			var seed_v: int = rng.randi()
			var at := Vector3(px, g - 0.1, pz)
			var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at)
			_add_prop(_cell_key("alpinum", at, 120.0), _garden, xf, func(pk, kit, _labels): _kit_call(_garden, "rockery_stone", [pk, kit, r, seed_v]), 700.0)
			for k in range(rng.randi_range(1, 3)):
				var cp := Vector2(px + rng.randf_range(-2.4, 2.4), pz + rng.randf_range(-2.4, 2.4))
				if _route_dist(cp.x, cp.y) < ROAD_HALF + 1.5:
					continue
				var cr: float = rng.randf_range(0.35, 0.8)
				var cseed: int = rng.randi()
				var cat := Vector3(cp.x, _ground_at(cp.x, cp.y) - 0.04, cp.y)
				_add_prop(_cell_key("alpinum", cat, 120.0), _garden, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), cat), func(pk, kit, _labels): _kit_call(_garden, "alpine_cushion", [pk, kit, cr, cseed]), 450.0)
			n += 1
		x += 6.5
	print("  Alpinum: %d stones" % n)


## The belvedere on the summit, a balustrade along the terrace's edge.
func _build_summit(body: StaticBody3D) -> void:
	var at := Vector3(BELVEDERE_AT.x, _pad_y["belvedere"], BELVEDERE_AT.y)
	var xf: Transform3D = _facing(Vector3(-0.6, 0, 0.8), at)
	_add_prop("belvedere", _garden, xf, func(pk, kit, labels): _kit_call(_garden, "belvedere", [pk, kit, labels]), 2400.0)
	_solids(body, _kit_call(_garden, "belvedere_solids", []), xf)
	_note_rect(BELVEDERE_AT, 22.0, 22.0, 0.0)


## The terrace's drop: retaining walls either side of the route along the terrace's edge, steps beside it, and the
## route's own drop faced in ashlar down both its sides.
func _build_terrace(body: StaticBody3D) -> void:
	var top: float = CITY_Y + 23.3
	var h_life: float = (TERRACE_DROP + 0.4) / PROP_SCALE
	var sp: Dictionary = _spot(s_terrace + 0.5, 0.0, 0.0)
	# The steps down beside the route, on its right: their middle's lateral and their width (life).
	var steps_lat: float = ROAD_HALF + 12.0
	var steps_w := 4.0
	for side in [-1.0, 1.0]:
		var start: Vector3 = (sp["pos"] as Vector3) + (sp["right"] as Vector3) * side * (ROAD_HALF + 0.3)
		var l: float = 34.0
		var along: Vector3 = (sp["right"] as Vector3) * side
		var face: Vector3 = sp["fwd"]
		var x_axis: Vector3 = along
		var xf := Transform3D(Basis(x_axis, Vector3.UP, face).orthonormalized(), Vector3(start.x, top, start.z))
		if xf.basis.determinant() < 0.0:
			xf = Transform3D(Basis(-x_axis, Vector3.UP, face), Vector3(start.x, top, start.z) + along * l)
		var ll: float = l / PROP_SCALE
		_add_prop("terrace_walls", _garden, xf, func(pk, kit, _labels): _kit_call(_garden, "terrace_wall", [pk, kit, ll, h_life]), 1200.0)
		_box(body, Transform3D(xf.basis, Vector3(start.x, top - TERRACE_DROP * 0.5, start.z) + along * (l * 0.5)), Vector3(l, TERRACE_DROP + 0.6, 1.2))
		# The balustrade along the coping from 2m in from each end, with a gap at the head of the steps. Runs are [d0, d1]
		# metres along `along` from `start`; where the frame is flipped its x runs back, so a run starts at d1 (from
		# `start` it had run 30m back across the route on that side).
		var flipped: bool = xf.basis.x.dot(along) < 0.0
		var runs: Array = [[2.0, l - 2.0]]
		if side > 0.0:
			var gc: float = steps_lat - (ROAD_HALF + 0.3)
			var gh: float = (steps_w * 0.5 + 0.5) * PROP_SCALE + 0.3
			runs = [[2.0, gc - gh], [gc + gh, l - 2.0]]
		for r in runs:
			var d0: float = r[0]
			var d1: float = r[1]
			var o: Vector3 = start + along * (d1 if flipped else d0)
			var bl: float = (d1 - d0) / PROP_SCALE
			_add_prop("terrace_walls", _garden, Transform3D(xf.basis, Vector3(o.x, top + 0.02, o.z)), func(pk, kit, _labels): _kit_call(_garden, "balustrade", [pk, kit, bl]), 900.0)
	# Steps down beside the route, on its right.
	var st: Dictionary = _spot(s_terrace + 0.5, steps_lat, 0.0)
	var sat := Vector3((st["pos"] as Vector3).x, top, (st["pos"] as Vector3).z)
	_add_prop("terrace_walls", _garden, _facing(sp["fwd"], sat), func(pk, kit, _labels): _kit_call(_garden, "terrace_steps", [pk, kit, steps_w, h_life]), 900.0)
	# The route's drop: ashlar faces down both sides of its ribbon where the ground was lowered under the lip.
	var tk: Script = _town
	if tk == null:
		return
	var pk2: PropKit = tk.new_kit(1.0)
	var kit2 := {}
	var stone := Color(0.78, 0.72, 0.62)
	var s: float = s_terrace - float(TERRACE_KICK[0]) - 4.0
	while s < s_terrace + TERRACE_FACE + 2.0:
		var sb: float = s + 1.0
		for side in [-1.0, 1.0]:
			var lat: float = side * (ROAD_HALF + 0.02)
			var a: Vector3 = _pt(s) + _rt(s) * lat
			var b: Vector3 = _pt(sb) + _rt(sb) * lat
			var ga: float = minf(_ground_at(a.x, a.z), a.y) - 0.6
			var gb: float = minf(_ground_at(b.x, b.z), b.y) - 0.6
			var out: Vector3 = _rt(s) * side
			var quad: Array = [Vector3(a.x, ga, a.z), Vector3(b.x, gb, b.z), b, a]
			var ul: float = s - s_terrace
			pk2.quad(kit2, "ashlar", quad, out, stone, [Vector2(ul, ga - top), Vector2(ul + 1.0, gb - top), Vector2(ul + 1.0, b.y - top), Vector2(ul, a.y - top)])
		s = sb
	var mesh: ArrayMesh = tk.commit(pk2, kit2)
	_share_materials(mesh)
	var mi := MeshInstance3D.new()
	mi.name = "TerraceLipFaces"
	mi.mesh = _save_res(mesh, "terrace_lip", PROP_PREFIX)
	level.add_child(mi)
	_build_terrace_stairs(body)


## The flight of stairs from the kicker's lip down to the road below (TERRACE_FACE, TERRACE_STEPS), as wide as the road:
## each tread level with the road's (collision) line at its front edge, so that line runs down the nosings; a parapet
## along each side with a coping, solid.
func _build_terrace_stairs(body: StaticBody3D) -> void:
	var tk: Script = _town
	if tk == null:
		return
	var pk: PropKit = tk.new_kit(1.0)
	var kit := {}
	var tread_col := Color(0.82, 0.77, 0.68)
	var riser_col := Color(0.66, 0.6, 0.52)
	var nose_col := Color(0.9, 0.87, 0.8)
	var top: float = CITY_Y + 23.3
	var w: float = ROAD_HALF
	var run: float = TERRACE_FACE / float(TERRACE_STEPS)
	var prev_y: float = _lap_y(s_terrace)
	for k in range(TERRACE_STEPS):
		var s0: float = s_terrace + float(k) * run
		var s1: float = s0 + run
		var y: float = _lap_y(s1)
		var f: Vector3 = _rt(s0)
		var a0: Vector3 = _pt(s0) - f * w
		var b0: Vector3 = _pt(s0) + f * w
		var a1: Vector3 = _pt(s1) - f * w
		var b1: Vector3 = _pt(s1) + f * w
		var fwd: Vector3 = (_pt(s1) - _pt(s0)).normalized()
		# The riser at the tread's back, from the step above down to this tread (facing down the flight).
		pk.quad(kit, "ashlar", [Vector3(a0.x, y, a0.z), Vector3(b0.x, y, b0.z), Vector3(b0.x, prev_y, b0.z), Vector3(a0.x, prev_y, a0.z)], fwd, riser_col,
				[Vector2(-w, y - top), Vector2(w, y - top), Vector2(w, prev_y - top), Vector2(-w, prev_y - top)])
		# The tread, its front 6cm a lighter nosing.
		var sn: float = s1 - 0.06
		var an: Vector3 = _pt(sn) - f * w
		var bn: Vector3 = _pt(sn) + f * w
		pk.quad(kit, "ashlar", [Vector3(a0.x, y, a0.z), Vector3(an.x, y, an.z), Vector3(bn.x, y, bn.z), Vector3(b0.x, y, b0.z)], Vector3.UP, tread_col,
				[Vector2(-w, s0), Vector2(-w, sn), Vector2(w, sn), Vector2(w, s0)])
		pk.quad(kit, "ashlar", [Vector3(an.x, y, an.z), Vector3(a1.x, y, a1.z), Vector3(b1.x, y, b1.z), Vector3(bn.x, y, bn.z)], Vector3.UP, nose_col,
				[Vector2(-w, sn), Vector2(-w, s1), Vector2(w, s1), Vector2(w, sn)])
		prev_y = y
	# The parapets: from the lip to the foot, 0.6m wide outside the road's edge, standing 0.55m over the nosings' line.
	var ps0: float = s_terrace - 0.5
	var ps1: float = s_terrace + TERRACE_FACE + 0.5
	var stone := Color(0.78, 0.72, 0.62)
	for side in [-1.0, 1.0]:
		var pts: Array = []
		var s: float = ps0
		while s <= ps1 + 0.01:
			pts.append(s)
			s += 0.5
		for i in range(pts.size() - 1):
			var sa: float = pts[i]
			var sb: float = pts[i + 1]
			var ra: Vector3 = _rt(sa) * side
			var rb: Vector3 = _rt(sb) * side
			var ia: Vector3 = _pt(sa) + ra * (w + 0.02)
			var ib: Vector3 = _pt(sb) + rb * (w + 0.02)
			var oa: Vector3 = _pt(sa) + ra * (w + 0.62)
			var ob: Vector3 = _pt(sb) + rb * (w + 0.62)
			var ta: float = maxf(_lap_y(sa), _lap_y(clampf(sa, s_terrace, ps1))) + 0.55
			var tb: float = maxf(_lap_y(sb), _lap_y(clampf(sb, s_terrace, ps1))) + 0.55
			var ba: float = minf(_ground_at(oa.x, oa.z), _lap_y(sa)) - 0.6
			var bb: float = minf(_ground_at(ob.x, ob.z), _lap_y(sb)) - 0.6
			var ua: float = sa - s_terrace
			var ub: float = sb - s_terrace
			# Outer face, inner face (down to the treads), the coping on top.
			pk.quad(kit, "ashlar", [Vector3(oa.x, ba, oa.z), Vector3(ob.x, bb, ob.z), Vector3(ob.x, tb, ob.z), Vector3(oa.x, ta, oa.z)], ra, stone,
					[Vector2(ua, ba - top), Vector2(ub, bb - top), Vector2(ub, tb - top), Vector2(ua, ta - top)])
			pk.quad(kit, "ashlar", [Vector3(ia.x, _lap_y(sa) - 0.5, ia.z), Vector3(ib.x, _lap_y(sb) - 0.5, ib.z), Vector3(ib.x, tb, ib.z), Vector3(ia.x, ta, ia.z)], -ra, stone,
					[Vector2(ua, -1.0), Vector2(ub, -1.0), Vector2(ub, 0.0), Vector2(ua, 0.0)])
			pk.quad(kit, "ashlar", [Vector3(ia.x, ta + 0.08, ia.z), Vector3(ib.x, tb + 0.08, ib.z), Vector3(ob.x, tb + 0.08, ob.z), Vector3(oa.x, ta + 0.08, oa.z)], Vector3.UP,
					nose_col, [Vector2(ua, 0.0), Vector2(ub, 0.0), Vector2(ub, 0.6), Vector2(ua, 0.6)])
			pk.quad(kit, "ashlar", [Vector3(ia.x, ta, ia.z), Vector3(ib.x, tb, ib.z), Vector3(ib.x, tb + 0.08, ib.z), Vector3(ia.x, ta + 0.08, ia.z)], -ra, nose_col)
			pk.quad(kit, "ashlar", [Vector3(oa.x, ta, oa.z), Vector3(ob.x, tb, ob.z), Vector3(ob.x, tb + 0.08, ob.z), Vector3(oa.x, ta + 0.08, oa.z)], ra, nose_col)
		# Solid: a box along each parapet, tilted down the flight.
		var p0: Vector3 = _pt(s_terrace) + _rt(s_terrace) * side * (w + 0.32)
		var p1: Vector3 = _pt(s_terrace + TERRACE_FACE) + _rt(s_terrace + TERRACE_FACE) * side * (w + 0.32)
		p0.y = _lap_y(s_terrace) + 0.27
		p1.y = _lap_y(s_terrace + TERRACE_FACE) + 0.27
		var zax: Vector3 = (p1 - p0).normalized()
		var xax: Vector3 = _rt(s_terrace)
		var yax: Vector3 = zax.cross(xax).normalized()
		if yax.y < 0.0:
			xax = -xax
			yax = -yax
		_box(body, Transform3D(Basis(xax, yax, zax), (p0 + p1) * 0.5 - yax * 0.84), Vector3(0.6, 2.4, p0.distance_to(p1) + 0.6))
	var mesh: ArrayMesh = tk.commit(pk, kit)
	_share_materials(mesh)
	var mi := MeshInstance3D.new()
	mi.name = "TerraceStairs"
	mi.mesh = _save_res(mesh, "terrace_stairs", PROP_PREFIX)
	level.add_child(mi)


## Benches and lanterns along the paths, botanical labels, a sundial, urns, a statue, the plan by the gate.
func _build_garden_furniture(body: StaticBody3D, rng: RandomNumberGenerator) -> void:
	var s: float = s_gate + 30.0
	var side := 1.0
	var n := 0
	var labels_txt: Array = ["Ginkgo biloba", "Quercus robur", "Tilia cordata", "Magnolia kobus", "Rosa gallica", "Dahlia pinnata",
		"Salvia splendens", "Begonia semperflorens", "Aster amellus", "Lavandula angustifolia", "Gentiana acaulis", "Saxifraga paniculata"]
	while s < s_exit - 20.0:
		# None from the terrace on: below it the road is sunk between banks with boost pads on them (BANK_BOOSTS), and a lamp
		# and a bench stood in the first pad's way.
		if _kind_at(_road_kinds(), s) == 10 and absf(_at(s)["k"]) < 0.03 and s < s_terrace - 30.0:
			var sp: Dictionary = _spot(s, side * (ROAD_HALF + 2.2), 0.0)
			var p: Vector3 = sp["pos"]
			var face: Vector3 = -(sp["right"] as Vector3) * side
			if not _occupied(p.x, p.z):
				_garden_prop("gfurn", Vector2(p.x, p.z), face, "park_lamp", [], 600.0)
				_box(body, Transform3D(Basis(), Vector3(p.x, _ground_at(p.x, p.z) + 3.2, p.z)), Vector3(0.45, 6.4, 0.45))
				var bp: Dictionary = _spot(s + 9.0, side * (ROAD_HALF + 2.6), 0.0)
				var bpos: Vector3 = bp["pos"]
				if not _occupied(bpos.x, bpos.z):
					_garden_prop("gfurn", Vector2(bpos.x, bpos.z), face, "park_bench", [], 450.0)
					_box(body, Transform3D(Basis.looking_at(face, Vector3.UP), Vector3(bpos.x, _ground_at(bpos.x, bpos.z) + 0.6, bpos.z)), Vector3(3.0, 1.2, 1.2))
				if rng.randf() < 0.5:
					var lp: Dictionary = _spot(s + 4.0, side * (ROAD_HALF + 4.6), 0.0)
					var lpos: Vector3 = lp["pos"]
					var txt: String = labels_txt[rng.randi_range(0, labels_txt.size() - 1)]
					_garden_prop("gfurn", Vector2(lpos.x, lpos.z), face, "plant_label", [txt], 120.0)
				n += 1
			side = -side
		s += 38.0
	# The plan of the garden by the main gate, a sundial and urns on the parterre, a statue by the pond.
	var gp: Dictionary = _spot(s_gate + 12.0, -(ROAD_HALF + 4.0), 0.0)
	_garden_prop("gfurn", Vector2((gp["pos"] as Vector3).x, (gp["pos"] as Vector3).z), gp["right"], "garden_sign",
		[["BOTANISCHER GARTEN", "Palmenhaus  >", "Rosengarten  >", "Alpinum  >", "Belvedere  >"]], 500.0)
	_garden_prop("gfurn", Vector2(268.0, -262.0), Vector3(0, 0, 1), "sundial", [], 400.0)
	_box(body, Transform3D(Basis(), Vector3(268.0, _ground_at(268.0, -262.0) + 0.7, -262.0)), Vector3(1.2, 1.4, 1.2))
	for up in [Vector2(165.0, -215.0), Vector2(165.0, -185.0), Vector2(275.0, -215.0), Vector2(275.0, -185.0)]:
		if _route_dist(up.x, up.y) > ROAD_HALF + 1.5:
			_garden_prop("gfurn", up, Vector3(0, 0, 1), "urn", [], 400.0)
			_box(body, Transform3D(Basis(), Vector3(up.x, _ground_at(up.x, up.y) + 0.8, up.y)), Vector3(1.2, 1.6, 1.2))
	var stp := Vector2(505.0, -392.0)
	_garden_prop("gfurn", stp, Vector3(0.6, 0, -0.8), "statue", [], 500.0)
	_box(body, Transform3D(Basis(), Vector3(stp.x, _ground_at(stp.x, stp.y) + 2.0, stp.y)), Vector3(1.8, 4.0, 1.8))
	# Hedges round the parterre.
	for hx in [[Vector2(148.0, -296.0), Vector2(282.0, -296.0)], [Vector2(148.0, -158.0), Vector2(282.0, -158.0)]]:
		var a: Vector2 = hx[0]
		var b: Vector2 = hx[1]
		var l: float = a.distance_to(b)
		var xf := Transform3D(Basis(), Vector3(a.x, _ground_at(a.x, a.y), a.y))
		_add_prop(_cell_key("ghedge", xf.origin), _garden, xf, func(pk, kit, _labels): _kit_call(_garden, "hedge", [pk, kit, l / PROP_SCALE, 1.1, 0.8]), 600.0)
		_box(body, Transform3D(Basis(), Vector3((a.x + b.x) * 0.5, _ground_at(a.x, a.y) + 0.9, a.y)), Vector3(l, 1.8, 1.4))
	print("  garden paths: %d lamp groups" % n)


# ======================================================================================
#  The docks: warehouses and the canal, the demolition site (the wrecking ball), the scrapyard (the magnet crane), the
#  building site (the excavator, the kicker, the car park, the road roller, the tower crane)
# ======================================================================================

func _build_docks(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Hafen"
	root.add_child(node)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7601
	_build_warehouses(node, rng)
	_build_demolition(node, rng)
	_build_scrapyard(node, rng)
	_build_building_site(node, rng)
	_build_barges(node)


func _dock_y(x: float, z: float) -> float:
	return _ground_at(x, z)


## Brick warehouses and container stacks along the dock roads and the canal's quay, ore cranes on the quay.
func _build_warehouses(node: Node3D, rng: RandomNumberGenerator) -> void:
	var body := _body(node, "HafenBody", "rock")
	var houses: Array = [
		# [centre, yaw (the front's facing), w, d, h, doors, sign]
		[Vector2(520.0, 560.0), Vector3(0, 0, -1), 60.0, 28.0, 12.0, 4, "SPEDITION RUHRTAL"],
		[Vector2(460.0, 760.0), Vector3(-1, 0, 0), 46.0, 24.0, 11.0, 3, "LAGERHAUS 7"],
		[Vector2(620.0, 760.0), Vector3(-1, 0, 0), 52.0, 26.0, 12.0, 3, "KRONBURGER HAFEN AG"],
		[Vector2(250.0, 900.0), Vector3(0, 0, -1), 64.0, 30.0, 13.0, 5, "GETREIDE KONTOR"],
		[Vector2(420.0, 990.0), Vector3(0, 0, -1), 58.0, 26.0, 12.0, 4, "STAHLHANDEL WEBER"],
		[Vector2(-1050.0, 990.0), Vector3(0, 0, -1), 60.0, 28.0, 12.0, 4, "LAGERHAUS 3"],
	]
	for h in houses:
		var c: Vector2 = h[0]
		var face: Vector3 = h[1]
		if _route_dist(c.x, c.y) < 40.0:
			continue
		var w: float = h[2]
		var d: float = h[3]
		var hh: float = h[4]
		var doors: int = h[5]
		var txt: String = h[6]
		var xf: Transform3D = _facing(face, Vector3(c.x, _ground_range(c, w * PROP_SCALE, d * PROP_SCALE, 0.0).x, c.y))
		_add_prop(_cell_key("warehouse", xf.origin, 300.0), _port, xf, func(pk, kit, labels): _kit_call(_port, "warehouse", [pk, kit, w, d, hh, doors, labels, txt]), 2400.0)
		_note_xf(xf, -w * 0.5 * PROP_SCALE, w * 0.5 * PROP_SCALE, -d * 0.5 * PROP_SCALE, d * 0.5 * PROP_SCALE, 2.0)
	# Container stacks by the quay and in the yard behind the warehouses.
	for st in [[Vector2(700.0, 980.0), 0.0, 4, 2, 3], [Vector2(560.0, 1010.0), 0.0, 5, 2, 2], [Vector2(80.0, 1000.0), 0.0, 4, 2, 3],
			[Vector2(-300.0, 1030.0), 0.0, 6, 2, 2], [Vector2(780.0, 620.0), PI * 0.5, 3, 2, 3]]:
		var c2: Vector2 = st[0]
		if _route_dist(c2.x, c2.y) < 45.0:
			continue
		var yaw: float = st[1]
		var nx: int = st[2]
		var nz: int = st[3]
		var lv: int = st[4]
		var seed_v: int = rng.randi()
		var at := Vector3(c2.x, _dock_y(c2.x, c2.y), c2.y)
		_add_prop(_cell_key("containers", at, 300.0), _port, Transform3D(Basis(), at), func(pk, kit, _labels):
			var r := RandomNumberGenerator.new()
			r.seed = seed_v
			_kit_call(_port, "stack", [pk, kit, r, Vector3.ZERO, yaw, nx, nz, lv]), 1800.0)
		_note_rect(c2, float(nx) * 13.0 * PROP_SCALE, float(nz) * 3.0 * PROP_SCALE, -yaw, 2.0)
		_box(body, Transform3D(Basis(Vector3.UP, yaw), at + Vector3(0, float(lv) * 2.6 * PROP_SCALE * 0.5, 0)), Vector3(float(nx) * 12.4 * PROP_SCALE, float(lv) * 2.6 * PROP_SCALE, float(nz) * 2.5 * PROP_SCALE))
	# Ore cranes on the quay along the canal.
	for x in [-520.0, 140.0, 760.0]:
		var at2 := Vector3(x, DOCK_Y + 0.25, CANAL_Z - CANAL_HALF - 14.0)
		_add_prop(_cell_key("quaycranes", at2, 400.0), _works, _facing(Vector3(0, 0, 1), at2), func(pk, kit, _labels): _kit_call(_works, "ore_crane", [pk, kit]), 2400.0)


## The demolition site: the half-demolished office block south of the road, the crawler crane north of it with its ball
## swinging across the road into the building, rubble, skips.
func _build_demolition(node: Node3D, rng: RandomNumberGenerator) -> void:
	var body := _body(node, "AbrissBody", "rock")
	var y0: float = _pad_y["demolition"]
	# The ruin's front faces the road (north), RUIN_GAP south of its line.
	var ruin_front: float = 430.0 + RUIN_GAP
	var rxf: Transform3D = _facing(Vector3(0, 0, -1), Vector3(BALL_X, y0, ruin_front))
	_add_prop("abriss_ruin", _scrap, rxf, func(pk, kit, labels): _kit_call(_scrap, "ruin_building", [pk, kit, labels, 7]), 2400.0)
	_solids(body, _kit_call(_scrap, "ruin_building_solids", [7]), rxf)
	_note_xf(rxf, -19.0 * PROP_SCALE, 19.0 * PROP_SCALE, -15.0 * PROP_SCALE, 0.0, 1.0)
	# The crane north of the road, its boom's tip over the road's line.
	var cm: Dictionary = _scrap.get_script_constant_map() if _scrap != null else {}
	var tip: Vector3 = cm.get("CRANE_TIP", Vector3(0, 32.0, -18.5))
	var ball_r: float = float(cm.get("BALL_R", 1.0)) * PROP_SCALE
	var ball_h: float = float(cm.get("BALL_H", 2.4))
	var foot: Vector2 = cm.get("CRANE_FOOT_HALF", Vector2(3.6, 6.0))
	var cxf: Transform3D = _facing(Vector3(0, 0, -1), Vector3(BALL_X, y0, 430.0))
	# Its local -z faces the road (south): turn it round, then step it back so the tip lands over the road's line.
	cxf = _facing(Vector3(0, 0, -1), Vector3.ZERO)
	var tip_off: Vector3 = cxf.basis * (tip * PROP_SCALE)
	cxf.origin = Vector3(BALL_X, y0, 430.0) - Vector3(tip_off.x, 0.0, tip_off.z)
	if (cxf.basis * Vector3(0, 0, -1)).z < 0.0:
		cxf = _facing(Vector3(0, 0, 1), Vector3.ZERO)
		tip_off = cxf.basis * (tip * PROP_SCALE)
		cxf.origin = Vector3(BALL_X, y0, 430.0) - Vector3(tip_off.x, 0.0, tip_off.z)
	_add_prop("abriss_crane", _scrap, cxf, func(pk, kit, labels): _kit_call(_scrap, "crawler_crane", [pk, kit, labels]), 2400.0)
	_solids(body, _kit_call(_scrap, "crawler_crane_solids", []), cxf)
	_note_xf(cxf, -foot.x * PROP_SCALE, foot.x * PROP_SCALE, -foot.y * PROP_SCALE, foot.y * PROP_SCALE, 2.0)
	var tip_w: Vector3 = cxf * (tip * PROP_SCALE)
	# The ball: its centre this far under the tip, 2.2m over the road at the bottom of its swing.
	var road_y: float = _lap_y(s_ball)
	var length: float = tip_w.y - (road_y + 2.2)
	var chain_life: float = length / PROP_SCALE - ball_h * 0.5
	var crane_front: float = absf(tip_w.z - (cxf * Vector3(0, 0, -foot.y * PROP_SCALE)).z)
	var wall: float = rad_to_deg(asin(clampf((ruin_front - 430.0 - ball_r - 0.3) / length, 0.0, 0.9)))
	var outd: float = rad_to_deg(asin(clampf((crane_front - ball_r - 2.0) / length, 0.0, 0.9)))
	outd = maxf(outd, wall + 1.5)
	var wb := Node3D.new()
	wb.name = "WreckingBall"
	wb.set_script(load("res://WreckingBall.gd"))
	wb.position = tip_w
	wb.set("length", length)
	wb.set("ball_radius", ball_r)
	wb.set("wall_deg", wall)
	wb.set("out_deg", outd)
	# Fast and free (the user wanted it quicker, no pause, and deadly): its gate gets tight margins instead.
	wb.set("gravity", BALL_GRAVITY)
	wb.set("hold", 0.0)
	wb.set("kills", true)
	wb.set("crash", _streams(["res://sounds/stadtrallye/wrecking_ball_crash_1.wav", "res://sounds/stadtrallye/wrecking_ball_crash_2.wav"]))
	wb.set("clang", _stream("res://sounds/stadtrallye/wrecking_ball_clang.wav"))
	wb.set("whoosh", _stream("res://sounds/stadtrallye/wrecking_ball_whoosh.wav"))
	var swing := Node3D.new()
	swing.name = "Swing"
	wb.add_child(swing)
	var bm: ArrayMesh = _kit_mesh(_scrap, "wrecking_ball", func(pk, kit): _kit_call(_scrap, "wrecking_ball", [pk, kit, chain_life]))
	if bm != null:
		var mi := MeshInstance3D.new()
		mi.name = "Ball"
		mi.mesh = bm
		mi.scale = Vector3.ONE * PROP_SCALE
		swing.add_child(mi)
	node.add_child(wb)
	var gate := Node3D.new()
	gate.name = "WreckingBallGate"
	gate.set_script(load("res://HazardGate.gd"))
	var gsp: Dictionary = _spot(s_ball, 0.0, 0.0)
	gate.position = gsp["pos"]
	gate.rotation_degrees = Vector3(0, gsp["yaw"], 0)
	gate.set("hazard", NodePath("../WreckingBall"))
	gate.set("ai_stop_short", 14.0)
	gate.set("road_half", ROAD_HALF)
	gate.set("reach", ball_r + 1.5)
	# Its clear gaps are short: the bot's crossing takes under a second there, and a bot keeps to the middle of the road,
	# so only the ball over its lane (3.5m a side) counts. Over the whole road's width it was open 0.7s a swing.
	gate.set("lead", 0.3)
	gate.set("trail", 0.6)
	gate.set("own_margin", 0.5)
	gate.set("road_half", 3.5)
	_add_hazard_gate(node, gate)
	print("  wrecking ball: line %.1fm, wall %.1f, out %.1f degrees (cycle %.1fs)" % [length, wall, outd, (TAU - 2.0 * acos(wall / outd)) / sqrt(BALL_GRAVITY / length)])
	# Rubble heaps against the ruin and along the site, skips, a parked excavator with its grapple.
	for rh in [[Vector2(BALL_X - 44.0, ruin_front + 14.0), 16.0, 12.0, 4.5], [Vector2(BALL_X + 46.0, ruin_front + 8.0), 12.0, 9.0, 3.2],
			[Vector2(BALL_X - 110.0, 470.0), 14.0, 10.0, 3.6], [Vector2(BALL_X + 110.0, 474.0), 18.0, 12.0, 4.0], [Vector2(BALL_X - 70.0, 392.0), 12.0, 8.0, 2.8]]:
		var c: Vector2 = rh[0]
		if _route_dist(c.x, c.y) < ROAD_HALF + float(rh[1]) * PROP_SCALE * 0.5 + 2.0:
			continue
		var w: float = rh[1]
		var d: float = rh[2]
		var h: float = rh[3]
		var seed_v: int = rng.randi()
		var at := Vector3(c.x, _ground_at(c.x, c.y) - 0.2, c.y)
		var hb := Basis(Vector3.UP, rng.randf() * TAU)
		_add_prop(_cell_key("rubble", at, 200.0), _scrap, Transform3D(hb, at), func(pk, kit, _labels): _kit_call(_scrap, "rubble_heap", [pk, kit, w, d, h, seed_v]), 1200.0)
		# The heap's core (life w x d x h, grown by PROP_SCALE), turned with it: three quarters of its footprint, a bit
		# over half its height.
		_box(body, Transform3D(hb, at + Vector3(0, h * PROP_SCALE * 0.275, 0)), Vector3(w * 0.75, h * 0.55, d * 0.75) * PROP_SCALE)
		_note_rect(c, w * PROP_SCALE, d * PROP_SCALE, 0.0)
	for sk in [Vector2(BALL_X + 70.0, 404.0), Vector2(BALL_X - 140.0, 404.0), Vector2(BALL_X + 30.0, 480.0)]:
		if _route_dist(sk.x, sk.y) < ROAD_HALF + 5.0 or _occupied(sk.x, sk.y):
			continue
		var seed2: int = rng.randi()
		var at2 := Vector3(sk.x, _ground_at(sk.x, sk.y), sk.y)
		var sxf := Transform3D(Basis(Vector3.UP, rng.randf_range(-0.3, 0.3)), at2)
		_add_prop(_cell_key("rubble", at2, 200.0), _scrap, sxf, func(pk, kit, _labels): _kit_call(_scrap, "skip", [pk, kit, seed2]), 900.0)
		_box(body, Transform3D(sxf.basis, at2 + Vector3(0, 1.2, 0)), Vector3(3.6, 2.4, 6.4))
	# The site's fence along its outer edges.
	_site_fence_line(node, body, Vector2(380.0, 520.0), Vector2(700.0, 520.0), rng)
	_site_fence_line(node, body, Vector2(380.0, 372.0), Vector2(700.0, 372.0), rng)

const RUIN_GAP := ROAD_HALF + 10.0
## The wrecking ball's pendulum gravity (WreckingBall.gravity): 28 swings it in 7.2s, 13 m/s over the road.
const BALL_GRAVITY := 28.0


## A Bauzaun (BaustelleKit.site_fence) along a line, in pieces on the ground, open where the route crosses it.
func _site_fence_line(_node: Node3D, body: StaticBody3D, a: Vector2, b: Vector2, rng: RandomNumberGenerator) -> void:
	var total: float = a.distance_to(b)
	var dir: Vector2 = (b - a) / total
	var u := 0.0
	while u < total - 2.0:
		var l: float = minf(3.5 * PROP_SCALE * 4.0, total - u)
		var pa: Vector2 = a + dir * u
		var pm: Vector2 = a + dir * (u + l * 0.5)
		u += l
		if _route_dist(pm.x, pm.y) < ROAD_HALF + l * 0.5 + 2.0 or _occupied(pm.x, pm.y):
			continue
		var g: float = minf(_ground_at(pa.x, pa.y), _ground_at(pa.x + dir.x * l, pa.y + dir.y * l))
		var x_axis := Vector3(dir.x, 0, dir.y)
		var xf := Transform3D(Basis(x_axis, Vector3.UP, x_axis.cross(Vector3.UP)), Vector3(pa.x, g, pa.y))
		if xf.basis.determinant() < 0.0:
			xf.basis = Basis(x_axis, Vector3.UP, -x_axis.cross(Vector3.UP))
		var ll: float = l / PROP_SCALE
		var seed_v: int = rng.randi()
		_add_prop(_cell_key("bauzaun", xf.origin, 200.0), _baustelle, xf, func(pk, kit, _labels): _kit_call(_baustelle, "site_fence", [pk, kit, ll, seed_v]), 700.0)
		_box(body, Transform3D(xf.basis, Vector3(pm.x, g + 1.6, pm.y)), Vector3(l, 3.2, 0.5))


## The scrapyard: its entrance road with the office and the weighbridge, the lanes between walls of crushed cars, the
## heaps behind them, the car press, and the material handler swinging its magnet (and a scrap car) across the lane.
func _build_scrapyard(node: Node3D, rng: RandomNumberGenerator) -> void:
	var body := _body(node, "SchrottBody", "rock")
	var t18: Dictionary = _turn(18)
	var t19: Dictionary = _turn(19)
	var s_h: float = _closest_s(Vector2(HANDLER_AT.x, 680.0))
	# The entrance: the office and the weighbridge beside the road south of the turn into the yard.
	var oxf: Transform3D = _facing(Vector3(-1, 0, 0), Vector3(330.0 + ROAD_HALF + 14.0, _dock_y(352.0, 560.0), 560.0))
	_add_prop("schrott_office", _scrap, oxf, func(pk, kit, labels): _kit_call(_scrap, "scrapyard_office", [pk, kit, labels]), 1600.0)
	_solids(body, _kit_call(_scrap, "scrapyard_office_solids", []), oxf)
	_note_xf(oxf, -8.0 * PROP_SCALE, 8.0 * PROP_SCALE, -6.0 * PROP_SCALE, 3.0 * PROP_SCALE)
	var wxf: Transform3D = _facing(Vector3(-1, 0, 0), Vector3(330.0 + ROAD_HALF + 14.0, _dock_y(352.0, 610.0), 612.0))
	_add_prop("schrott_office", _scrap, wxf, func(pk, kit, labels): _kit_call(_scrap, "weighbridge", [pk, kit, labels]), 1200.0)
	_solids(body, _kit_call(_scrap, "weighbridge_solids", []), wxf)
	_note_xf(wxf, -3.0 * PROP_SCALE, 3.0 * PROP_SCALE, -8.0 * PROP_SCALE, 8.0 * PROP_SCALE)
	# The bale walls either side of the lane, open round the handler, in short runs with gaps between (the yard is open:
	# a cart can leave the lane among the wrecks, `_build_scrap_wrecks`).
	var lane_s0: float = float(t18["s1"]) + 4.0
	var lane_s1: float = float(t19["s0"]) - 4.0
	var gap0: float = s_h - 34.0
	var gap1: float = s_h + 34.0
	var walls := 0
	for run in [[lane_s0, gap0], [gap1, lane_s1]]:
		for side in [-1.0, 1.0]:
			var s: float = run[0]
			while s < float(run[1]) - 8.0:
				var l: float = minf(rng.randf_range(9.0, 15.0), float(run[1]) - s)
				var sp: Dictionary = _spot(s, side * (ROAD_HALF + 2.2), 0.0)
				var a: Vector3 = sp["pos"]
				var fwd: Vector3 = sp["fwd"]
				var face: Vector3 = -(sp["right"] as Vector3) * side
				var g: float = _ground_at(a.x, a.z) - 0.05
				var xf := Transform3D(Basis(fwd, Vector3.UP, face), Vector3(a.x, g, a.z))
				if xf.basis.determinant() < 0.0:
					xf = Transform3D(Basis(-fwd, Vector3.UP, face), Vector3(a.x, g, a.z) + fwd * l)
				var ll: float = l / PROP_SCALE
				var layers: int = 3 + int(rng.randf() < 0.4)
				var seed_v: int = rng.randi()
				_add_prop(_cell_key("bales", a, 160.0), _scrap, xf, func(pk, kit, _labels): _kit_call(_scrap, "bale_wall", [pk, kit, ll, layers, seed_v]), 1200.0)
				var mid: Vector3 = a + fwd * (l * 0.5) - face * 1.6
				_box(body, Transform3D(Basis(fwd, Vector3.UP, fwd.cross(Vector3.UP)).orthonormalized(), Vector3(mid.x, g + 1.6, mid.z)), Vector3(l, 3.2 + float(layers - 3) * 0.9, 3.4))
				walls += 1
				s += l + rng.randf_range(8.0, 14.0)
	# Scrap heaps behind the walls.
	for hp in [[Vector2(250.0, 640.0), 22.0, 14.0, 7.0], [Vector2(40.0, 638.0), 20.0, 13.0, 6.0], [Vector2(240.0, 726.0), 20.0, 14.0, 6.5],
			[Vector2(30.0, 728.0), 18.0, 12.0, 6.0], [Vector2(150.0, 742.0), 24.0, 16.0, 8.0]]:
		var c: Vector2 = hp[0]
		if _route_dist(c.x, c.y) < ROAD_HALF + float(hp[2]) * PROP_SCALE * 0.5 + 3.0:
			continue
		var w: float = hp[1]
		var d: float = hp[2]
		var h: float = hp[3]
		var seed3: int = rng.randi()
		var at := Vector3(c.x, _ground_at(c.x, c.y) - 0.2, c.y)
		var hxf := Transform3D(Basis(Vector3.UP, rng.randf_range(-0.2, 0.2)), at)
		_add_prop(_cell_key("scrapheaps", at, 200.0), _scrap, hxf, func(pk, kit, _labels): _kit_call(_scrap, "scrap_heap", [pk, kit, w, d, h, seed3]), 1600.0)
		_solids(body, _kit_call(_scrap, "scrap_heap_solids", [w, d, h, seed3]), hxf)
		_note_rect(c, w * PROP_SCALE, d * PROP_SCALE, 0.0)
	# The car press on the north side across the lane from the handler, sorting bins, drums, tyres.
	var pxf: Transform3D = _facing(Vector3(0, 0, 1), Vector3(HANDLER_AT.x + 34.0, _dock_y(HANDLER_AT.x + 34.0, 650.0), 652.0))
	_add_prop("schrott_press", _scrap, pxf, func(pk, kit, labels): _kit_call(_scrap, "car_press", [pk, kit, labels]), 1600.0)
	_solids(body, _kit_call(_scrap, "car_press_solids", []), pxf)
	_note_xf(pxf, -9.0 * PROP_SCALE, 9.0 * PROP_SCALE, -6.0 * PROP_SCALE, 6.0 * PROP_SCALE)
	for bp in [[Vector2(HANDLER_AT.x - 30.0, 655.0), "sorting_bin"], [Vector2(HANDLER_AT.x - 14.0, 655.0), "sorting_bin"],
			[Vector2(300.0, 724.0), "drum_stack"], [Vector2(80.0, 650.0), "tyre_pile"], [Vector2(-10.0, 730.0), "tyre_pile"]]:
		var c4: Vector2 = bp[0]
		if _route_dist(c4.x, c4.y) < ROAD_HALF + 5.0 or _occupied(c4.x, c4.y):
			continue
		var fn: String = bp[1]
		var seed4: int = rng.randi()
		var at4 := Vector3(c4.x, _ground_at(c4.x, c4.y), c4.y)
		var bxf: Transform3D = _facing(Vector3(0, 0, 1), at4)
		_add_prop(_cell_key("scrapheaps", at4, 200.0), _scrap, bxf, func(pk, kit, _labels): _kit_call(_scrap, fn, [pk, kit, seed4]), 900.0)
		_box(body, Transform3D(Basis(), at4 + Vector3(0, 1.4, 0)), Vector3(5.0, 2.8, 5.0))
		_note_rect(c4, 8.0, 8.0, 0.0)
	# The material handler: its base south of the lane, its upper slewing (SlewHazard.gd) with the magnet on its stick.
	var cm: Dictionary = _scrap.get_script_constant_map() if _scrap != null else {}
	var ring_y: float = float(cm.get("HANDLER_RING_Y", 3.0)) * PROP_SCALE
	var tipv: Vector3 = cm.get("HANDLER_TIP", Vector3(0, 9.0, -15.0)) * PROP_SCALE
	var hit_c: Vector3 = cm.get("MAGNET_HIT_C", Vector3(0, -6.0, 0)) * PROP_SCALE
	var hit_h: Vector3 = cm.get("MAGNET_HIT_HALF", Vector3(1.4, 1.2, 2.4)) * PROP_SCALE
	var g0: float = _dock_y(HANDLER_AT.x, HANDLER_AT.y)
	var hb: Transform3D = Transform3D(Basis(), Vector3(HANDLER_AT.x, g0, HANDLER_AT.y))
	_add_prop("schrott_handler", _scrap, hb, func(pk, kit, labels): _kit_call(_scrap, "material_handler", [pk, kit, labels]), 2000.0)
	_solids(body, _kit_call(_scrap, "material_handler_solids", []), hb)
	# The upper (CarDropCrane.gd) slews the magnet out over the lane, drops its wreck on the road, lets it lie, pulls it back up.
	var slew := Node3D.new()
	slew.name = "MagnetCrane"
	slew.set_script(load("res://CarDropCrane.gd"))
	slew.position = Vector3(HANDLER_AT.x, g0 + ring_y, HANDLER_AT.y)
	var hang_w: Vector3 = slew.position + tipv
	var road_y: float = _lap_y(_closest_s(Vector2(hang_w.x, hang_w.z)))
	var car_bottom: float = hang_w.y + hit_c.y - hit_h.y
	var drop: float = car_bottom - road_y - 0.03
	slew.set("centre_deg", 0.0)
	slew.set("pile_deg", 82.0)
	slew.set("move", 5.0)
	slew.set("dwell", 3.0)
	slew.set("hover", 0.8)
	slew.set("drop", drop)
	# Under PlayerCart's 2.8s stuck check: a bot that meets it waits it out instead of being respawned.
	slew.set("lie", 2.2)
	slew.set("lift", 1.6)
	slew.set("hang", NodePath("Hang"))
	slew.set("car", NodePath("Hang/Car"))
	slew.set("car_centre", hit_c)
	slew.set("car_half", hit_h)
	slew.set("motor", _stream("res://sounds/stadtrallye/handler_hydraulics_loop.wav"))
	slew.set("clang", _stream("res://sounds/stadtrallye/magnet_clang.wav"))
	slew.set("crash", _stream("res://sounds/stadtrallye/wrecking_ball_crash_2.wav"))
	var um: ArrayMesh = _kit_mesh(_scrap, "handler_upper", func(pk, kit): _kit_call(_scrap, "material_handler_upper", [pk, kit]))
	if um != null:
		var umi := MeshInstance3D.new()
		umi.name = "Upper"
		umi.mesh = um
		umi.scale = Vector3.ONE * PROP_SCALE
		slew.add_child(umi)
	var hang := Node3D.new()
	hang.name = "Hang"
	hang.position = tipv
	slew.add_child(hang)
	var mm: ArrayMesh = _kit_mesh(_scrap, "scrap_magnet", func(pk, kit): _kit_call(_scrap, "scrap_magnet", [pk, kit, 3, false]))
	if mm != null:
		var mmi := MeshInstance3D.new()
		mmi.name = "Magnet"
		mmi.mesh = mm
		mmi.scale = Vector3.ONE * PROP_SCALE
		hang.add_child(mmi)
	var car_node := Node3D.new()
	car_node.name = "Car"
	hang.add_child(car_node)
	var wm: ArrayMesh = _kit_mesh(_scrap, "magnet_car", func(pk, kit): _kit_call(_scrap, "magnet_car", [pk, kit, 3]))
	if wm != null:
		var wmi := MeshInstance3D.new()
		wmi.name = "Wreck"
		wmi.mesh = wm
		wmi.scale = Vector3.ONE * PROP_SCALE
		car_node.add_child(wmi)
	print("  magnet crane: drops its car %.1fm onto the road (cycle %.1fs)" % [drop, 2.0 * 5.0 + 3.0 + 0.8 + sqrt(2.0 * drop / 24.0) + 2.2 + 1.6])
	node.add_child(slew)
	_note_rect(HANDLER_AT, 14.0, 14.0, 0.0)
	var gate := Node3D.new()
	gate.name = "MagnetCraneGate"
	gate.set_script(load("res://HazardGate.gd"))
	var gsp: Dictionary = _spot(s_h, 0.0, 0.0)
	gate.position = gsp["pos"]
	gate.rotation_degrees = Vector3(0, gsp["yaw"], 0)
	gate.set("hazard", NodePath("../MagnetCrane"))
	gate.set("ai_stop_short", 16.0)
	gate.set("road_half", ROAD_HALF)
	gate.set("reach", 5.0)
	_add_hazard_gate(node, gate)
	_build_scrap_wrecks(node, body, rng, s_h)
	# The yard's corrugated fence round its pad, open where the route comes in and goes out.
	var pr: Array = []
	for p in PADS:
		if p[0] == "scrapyard":
			pr = p[1]
	if not pr.is_empty():
		for e in [[Vector2(pr[0], pr[1]), Vector2(pr[2], pr[1])], [Vector2(pr[2], pr[1]), Vector2(pr[2], pr[3])],
				[Vector2(pr[2], pr[3]), Vector2(pr[0], pr[3])], [Vector2(pr[0], pr[3]), Vector2(pr[0], pr[1])]]:
			_scrap_fence_line(body, e[0], e[1])
	print("  scrapyard: %d bale walls" % walls)


func _scrap_fence_line(body: StaticBody3D, a: Vector2, b: Vector2) -> void:
	var total: float = a.distance_to(b)
	var dir: Vector2 = (b - a) / total
	var u := 0.0
	while u < total - 2.0:
		var l: float = minf(20.0, total - u)
		var pa: Vector2 = a + dir * u
		var pm: Vector2 = a + dir * (u + l * 0.5)
		u += l
		if _route_dist(pm.x, pm.y) < ROAD_HALF + l * 0.5 + 2.0 or _occupied(pm.x, pm.y):
			continue
		var g: float = minf(_ground_at(pa.x, pa.y), _ground_at(pa.x + dir.x * l, pa.y + dir.y * l))
		var x_axis := Vector3(dir.x, 0, dir.y)
		var xf := Transform3D(Basis(x_axis, Vector3.UP, x_axis.cross(Vector3.UP)), Vector3(pa.x, g, pa.y))
		if xf.basis.determinant() < 0.0:
			xf.basis = Basis(x_axis, Vector3.UP, -x_axis.cross(Vector3.UP))
		var ll: float = l / PROP_SCALE
		_add_prop(_cell_key("scrapfence", xf.origin, 200.0), _scrap, xf, func(pk, kit, _labels): _kit_call(_scrap, "scrap_fence", [pk, kit, ll]), 900.0)
		_box(body, Transform3D(xf.basis, Vector3(pm.x, g + 2.1, pm.y)), Vector3(l, 4.2, 0.4))


## The building site: cabins and the sign by its gate, the excavator digging beside the road and swinging its bucket
## over it, the kicker of spoil, the car park the route drives through, the road roller, the tower crane over it all.
func _build_building_site(node: Node3D, rng: RandomNumberGenerator) -> void:
	var body := _body(node, "BaustelleBody", "rock")
	var y0: float = _pad_y["building_site"]
	# Cabins, toilets, the sign by the site's gate on the road south into it.
	var t19: Dictionary = _turn(19)
	var gate_s: float = float(t19["s1"]) + 40.0
	var cab: Dictionary = _spot(gate_s, ROAD_HALF + 12.0, 0.0)
	var cab_at: Vector3 = cab["pos"]
	cab_at.y = _ground_at(cab_at.x, cab_at.z)
	var cxf: Transform3D = _facing(-(cab["right"] as Vector3), cab_at)
	_add_prop("bau_cabins", _baustelle, cxf, func(pk, kit, labels): _kit_call(_baustelle, "site_cabin", [pk, kit, labels, true]), 1400.0)
	_solids(body, _kit_call(_baustelle, "site_cabin_solids", [true]), cxf)
	_note_xf(cxf, -4.0 * PROP_SCALE, 4.0 * PROP_SCALE, -2.0 * PROP_SCALE, 2.0 * PROP_SCALE, 1.0)
	var cab2: Transform3D = cxf.translated(cxf.basis.x * 12.0)
	_add_prop("bau_cabins", _baustelle, cab2, func(pk, kit, labels): _kit_call(_baustelle, "site_cabin", [pk, kit, labels, false]), 1400.0)
	_solids(body, _kit_call(_baustelle, "site_cabin_solids", [false]), cab2)
	var sign_sp: Dictionary = _spot(gate_s - 20.0, -(ROAD_HALF + 4.0), 0.0)
	var sign_at: Vector3 = sign_sp["pos"]
	sign_at.y = _ground_at(sign_at.x, sign_at.z)
	_add_prop("bau_cabins", _baustelle, _facing(sign_sp["right"], sign_at), func(pk, kit, labels): _kit_call(_baustelle, "site_sign", [pk, kit, labels]), 900.0)
	_box(body, Transform3D(Basis(), sign_at + Vector3(0, 2.5, 0)), Vector3(1.0, 5.0, 1.0))
	for k in range(3):
		var tp: Dictionary = _spot(gate_s + 30.0 + float(k) * 3.0, ROAD_HALF + 8.0, 0.0)
		var tat: Vector3 = tp["pos"]
		tat.y = _ground_at(tat.x, tat.z)
		_add_prop("bau_small", _baustelle, _facing(-(tp["right"] as Vector3), tat), func(pk, kit, _labels): _kit_call(_baustelle, "portable_toilet", [pk, kit]), 700.0)
		_box(body, Transform3D(Basis(), tat + Vector3(0, 2.0, 0)), Vector3(2.2, 4.0, 2.2))
	# The excavator (SlewHazard.gd): its base south of the road, its arm swinging from the trench over the road's south half.
	var cm: Dictionary = _baustelle.get_script_constant_map() if _baustelle != null else {}
	var ring_y: float = float(cm.get("EXC_RING_Y", 1.4)) * PROP_SCALE
	var hit_c: Vector3 = cm.get("EXC_HIT_C", Vector3(0, 1.0, -8.0)) * PROP_SCALE
	var hit_h: Vector3 = cm.get("EXC_HIT_HALF", Vector3(1.0, 1.0, 1.6)) * PROP_SCALE
	var eg: float = _ground_at(EXCAVATOR_AT.x, EXCAVATOR_AT.y)
	var exf := Transform3D(Basis(), Vector3(EXCAVATOR_AT.x, eg, EXCAVATOR_AT.y))
	_add_prop("bau_excavator", _baustelle, exf, func(pk, kit, labels): _kit_call(_baustelle, "excavator", [pk, kit, labels]), 2000.0)
	_solids(body, _kit_call(_baustelle, "excavator_solids", []), exf)
	_note_rect(EXCAVATOR_AT, 12.0, 12.0, 0.0)
	var ex := Node3D.new()
	ex.name = "Excavator"
	ex.set_script(load("res://SlewHazard.gd"))
	ex.position = Vector3(EXCAVATOR_AT.x, eg + ring_y, EXCAVATOR_AT.y)
	ex.set("centre_deg", 95.0)
	ex.set("amplitude_deg", 95.0)
	ex.set("move", 4.5)
	ex.set("dwell", 3.0)
	ex.set("phase", 3.0)
	ex.set("hits", true)
	ex.set("hit_centre", hit_c)
	ex.set("hit_half", hit_h)
	ex.set("motor", _stream("res://sounds/stadtrallye/excavator_loop.wav"))
	ex.set("clang", _stream("res://sounds/stadtrallye/magnet_clang.wav"))
	var um: ArrayMesh = _kit_mesh(_baustelle, "excavator_upper", func(pk, kit): _kit_call(_baustelle, "excavator_upper", [pk, kit]))
	if um != null:
		var umi := MeshInstance3D.new()
		umi.name = "Upper"
		umi.mesh = um
		umi.scale = Vector3.ONE * PROP_SCALE
		ex.add_child(umi)
	node.add_child(ex)
	var gate := Node3D.new()
	gate.name = "ExcavatorGate"
	gate.set_script(load("res://HazardGate.gd"))
	var s_ex: float = _closest_s(EXCAVATOR_AT)
	var gsp: Dictionary = _spot(s_ex, 0.0, 0.0)
	gate.position = gsp["pos"]
	gate.rotation_degrees = Vector3(0, gsp["yaw"], 0)
	gate.set("hazard", NodePath("../Excavator"))
	gate.set("ai_stop_short", 14.0)
	gate.set("road_half", ROAD_HALF)
	gate.set("reach", 5.0)
	_add_hazard_gate(node, gate)
	# The car park under construction the route drives through.
	var cp0: Dictionary = _spot(s_carpark0, 0.0, 0.0)
	var cp_at: Vector3 = cp0["pos"]
	cp_at.y = _lap_y(s_carpark0) - GROUND_UNDER
	var pxf: Transform3D = _facing(-(cp0["fwd"] as Vector3), cp_at)
	var plen: float = (s_carpark1 - s_carpark0) / PROP_SCALE
	var road_half_life: float = (ROAD_HALF + 0.5) / PROP_SCALE
	_add_prop("bau_carpark", _baustelle, pxf, func(pk, kit, labels): _kit_call(_baustelle, "carpark_frame", [pk, kit, labels, plen, 40.0, road_half_life]), 2000.0)
	_solids(body, _kit_call(_baustelle, "carpark_frame_solids", [plen, 40.0, road_half_life]), pxf)
	_note_xf(pxf, -20.0 * PROP_SCALE, 20.0 * PROP_SCALE, -plen * PROP_SCALE, 0.0, 1.0)
	# The road roller (ShuttleProp.gd) up and down the road's north half after the car park.
	var rs: float = s_roller
	var rm: ArrayMesh = _kit_mesh(_baustelle, "road_roller", func(pk, kit): _kit_call(_baustelle, "road_roller", [pk, kit]))
	# Against the road's edge (its side 0.3m in), so it leaves the road's middle free: 3.6m out it stood over the middle,
	# where the bots drive, and they crawled behind it until the stuck check respawned them.
	var r_half: float = (rm.get_aabb().size.x * PROP_SCALE * 0.5) if rm != null else 1.8
	var rsp: Dictionary = _spot(rs, ROAD_HALF - r_half - 0.3, 0.0)
	var rat: Vector3 = rsp["pos"]
	rat.y = _lap_y(rs) + 0.02
	var roller := AnimatableBody3D.new()
	roller.name = "RoadRoller"
	roller.set_script(load("res://ShuttleProp.gd"))
	roller.transform = _facing(-(rsp["fwd"] as Vector3), rat)
	roller.set_meta(&"surface", "rock")
	roller.set("distance", 20.0)
	roller.set("speed", 1.6)
	roller.set("dwell", 3.0)
	roller.set("motor", _stream("res://sounds/stadtrallye/roller_loop.wav"))
	roller.set("beeper", _stream("res://sounds/stadtrallye/reverse_beeper_loop.wav"))
	if rm != null:
		var rmi := MeshInstance3D.new()
		rmi.name = "Body"
		rmi.mesh = rm
		rmi.scale = Vector3.ONE * PROP_SCALE
		roller.add_child(rmi)
		var ab: AABB = rm.get_aabb()
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = ab.size * PROP_SCALE
		cs.shape = bx
		cs.position = ab.get_center() * PROP_SCALE
		roller.add_child(cs)
	else:
		var cs2 := CollisionShape3D.new()
		var bx2 := BoxShape3D.new()
		bx2.size = Vector3(3.6, 4.6, 7.2)
		cs2.shape = bx2
		cs2.position = Vector3(0, 2.3, 0)
		roller.add_child(cs2)
	node.add_child(roller)
	# The tower crane south of the site road, its jib turning slowly over it all.
	var tc := Vector2(-330.0, 965.0)
	var tg: float = _ground_at(tc.x, tc.y)
	var mast_h := 40.0
	var txf := Transform3D(Basis(), Vector3(tc.x, tg, tc.y))
	_add_prop("bau_towercrane", _baustelle, txf, func(pk, kit, _labels): _kit_call(_baustelle, "tower_crane_mast", [pk, kit, mast_h]), 3000.0)
	_solids(body, _kit_call(_baustelle, "tower_crane_mast_solids", [mast_h]), txf)
	_note_rect(tc, 10.0, 10.0, 0.0)
	var top := Node3D.new()
	top.name = "TowerCraneTop"
	top.set_script(load("res://SlewHazard.gd"))
	top.position = Vector3(tc.x, tg + mast_h * PROP_SCALE, tc.y)
	top.set("centre_deg", 10.0)
	top.set("amplitude_deg", 110.0)
	top.set("move", 26.0)
	top.set("dwell", 12.0)
	top.set("hits", false)
	var tm: ArrayMesh = _kit_mesh(_baustelle, "tower_crane_top", func(pk, kit): _kit_call(_baustelle, "tower_crane_top", [pk, kit, []]))
	if tm != null:
		var tmi := MeshInstance3D.new()
		tmi.name = "Top"
		tmi.mesh = tm
		tmi.scale = Vector3.ONE * PROP_SCALE
		top.add_child(tmi)
	node.add_child(top)
	_build_parcours(node)
	_site_materials(node, body, rng)
	_build_leitbaken(node)
	# The site's Bauzaun along both sides of the road from its gate, open across the route.
	var pr: Array = []
	for p in PADS:
		if p[0] == "building_site":
			pr = p[1]
	_site_fence_line(node, body, Vector2(pr[0], pr[1]), Vector2(pr[2], pr[1]), rng)
	_site_fence_line(node, body, Vector2(pr[0], pr[3]), Vector2(pr[2], pr[3]), rng)
	_site_fence_line(node, body, Vector2(pr[2], pr[1]), Vector2(pr[2], pr[3]), rng)


## The building site's parcours (corners 20-24): tyre walls round the outside of each corner, and the spoil jumps' sides.
## Its checkpoint stands on the leg west along the north fence, after the table-top (PARCOURS_GATE): like every gate it may
## be missed once (the user's rule), so the walls only show the way, they don't fence the field off.
const PARCOURS_GATE := Vector2(-216.0, 825.0)
## [corner, metres of wall before its arc, after it].
const PARCOURS_TYRES := [[20, 10.0, 16.0], [21, 12.0, 16.0], [22, 10.0, 16.0], [23, 12.0, 14.0], [24, 10.0, 16.0]]
## The walls' line, right of the route's (outside the Leitbaken at ROAD_HALF + 0.9).
const PARCOURS_TYRE_LAT := ROAD_HALF + 1.9
const TYRE_STEP := 0.99

func _build_parcours(node: Node3D) -> void:
	if _scrap == null:
		return
	var pk: PropKit = _scrap.new_kit(1.0)
	var designs: Array = TyreStacks.meshes(pk, "tyre", 7311)
	for d in range(designs.size()):
		_share_materials(designs[d])
		designs[d] = _save_res(designs[d], "parcours_tyre_%d" % d, PROP_PREFIX)
	var body := _body(node, "ParcoursTyreWalls", "rock")
	var walls := 0
	var count := 0
	for spec in PARCOURS_TYRES:
		var t: Dictionary = _turn(int(spec[0]))
		# The outside of the corner: left of the way for a right turn (a positive turn), right for a left one.
		var lat: float = -signf(float(t["turn"])) * PARCOURS_TYRE_LAT
		var pts := PackedVector3Array()
		var s: float = float(t["s0"]) - float(spec[1])
		var last := Vector3(INF, 0, INF)
		while s <= float(t["s1"]) + float(spec[2]):
			var q: Vector3 = _pt(s) + _rt(s) * lat
			if Vector2(q.x - last.x, q.z - last.z).length() >= TYRE_STEP:
				# Nothing on another stretch of road.
				if _route_dist(q.x, q.z) > PARCOURS_TYRE_LAT - 0.8:
					q.y = _ground_at(q.x, q.z)
					pts.append(q)
					last = q
			s += 0.1
		var rng := RandomNumberGenerator.new()
		rng.seed = 7400 + int(spec[0])
		var stacks: Array = []
		for i in range(pts.size()):
			stacks.append([Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * PROP_SCALE), pts[i]), TyreStacks.design(i, rng)])
			# A box over every four stacks (and the last few): the stacks only rock, the boxes stop the cart.
			if i > 0 and (i % 4 == 0 or i == pts.size() - 1):
				var a: Vector3 = pts[maxi(i - 4, 4 * ((i - 1) / 4))]
				var b: Vector3 = pts[i]
				var along := Vector3(b.x - a.x, 0.0, b.z - a.z)
				var length: float = along.length()
				if length > 0.05:
					var z := along / length
					var x := Vector3.UP.cross(z).normalized()
					var h: float = 0.62 * PROP_SCALE
					var mid: Vector3 = (a + b) * 0.5 + Vector3(0, h * 0.5, 0)
					_box(body, Transform3D(Basis(x, Vector3.UP, z), mid), Vector3(0.62 * PROP_SCALE, h + absf(a.y - b.y), length + 0.62 * PROP_SCALE))
		node.add_child(TyreStacks.spring_node("ParcoursTyres%d" % int(spec[0]), designs, stacks, PROP_SCALE))
		for q in pts:
			_note_rect(Vector2(q.x, q.z), 1.0, 1.0, 0.0, 0.5)
		walls += 1
		count += pts.size()
	_build_spoil_jumps(node)
	print("  parcours: %d tyre walls, %d stacks; checkpoint at %.0fm" % [walls, count, _closest_s(PARCOURS_GATE)])


## The spoil jumps' sides (the kicker, the table-top): the road's ribbon is their top, and each side is a slope of spoil
## from just under the ribbon's edge, rounded over, down at about the angle of repose into the ground (sunk 30cm under it).
## Their own body (off-road dirt) holds their triangles; the mesh is under it, so DressingColliders leaves it be.
const SPOIL_SLOPE := 1.35
const SPOIL_STEP := 0.75

func _build_spoil_jumps(node: Node3D) -> void:
	if _baustelle == null:
		return
	var pk: PropKit = _baustelle.new_kit(1.0)
	pk.reset_frame()
	var kit := {}
	var faces := PackedVector3Array()
	for span in _jump_spans():
		var s0: float = float(span[0]) - 1.0
		var s1: float = float(span[1]) + 1.0
		var base: float = minf(_lap_y(s0 - 3.0), _lap_y(s1 + 3.0))
		var n: int = ceili((s1 - s0) / SPOIL_STEP)
		for side in [-1.0, 1.0]:
			var grid: Array = []
			for i in range(n + 1):
				var sv: float = lerpf(s0, s1, float(i) / float(n))
				var c: Vector3 = _pt(sv)
				var r: Vector3 = _rt(sv) * side
				var top: float = _lap_y(sv)
				var h: float = maxf(top - base, 0.0)
				var run: float = h * SPOIL_SLOPE
				var lats: Array = [ROAD_HALF - 0.15, ROAD_HALF + 0.3, ROAD_HALF + 0.3 + run * 0.5, ROAD_HALF + 0.3 + run + 0.9]
				var row: Array = []
				for j in range(lats.size()):
					var p: Vector3 = c + r * float(lats[j])
					match j:
						0: p.y = top - 0.035
						1: p.y = top - 0.06 - h * 0.04
						2: p.y = base + h * 0.52
						_: p.y = _ground_at(p.x, p.z) - 0.3
					row.append(p)
				grid.append(row)
			var out_dir := func(i: int) -> Vector3:
				return (_rt(lerpf(s0, s1, float(i) / float(n))) * side + Vector3.UP).normalized()
			var nrm := func(i: int, j: int) -> Vector3:
				var a: Vector3 = grid[maxi(i - 1, 0)][j]
				var b: Vector3 = grid[mini(i + 1, n)][j]
				var cc: Vector3 = grid[i][maxi(j - 1, 0)]
				var d: Vector3 = grid[i][mini(j + 1, 3)]
				var nn: Vector3 = (d - cc).cross(b - a).normalized()
				return nn if nn.dot(out_dir.call(i)) > 0.0 else -nn
			for i in range(n):
				for j in range(3):
					var p00: Vector3 = grid[i][j]
					var p10: Vector3 = grid[i + 1][j]
					var p01: Vector3 = grid[i][j + 1]
					var p11: Vector3 = grid[i + 1][j + 1]
					# Spoil, darker in the rounded edge under the ribbon; one colour a band (a colour a quad read as a
					# chequerboard), the heap material's weathering varies it.
					var col: Color = [Color(0.34, 0.26, 0.19), Color(0.41, 0.32, 0.23), Color(0.43, 0.34, 0.25)][j]
					var o: Vector3 = out_dir.call(i)
					pk.tri(kit, "heap", p00, p10, p11, nrm.call(i, j), nrm.call(i + 1, j), nrm.call(i + 1, j + 1), col, o)
					pk.tri(kit, "heap", p00, p11, p01, nrm.call(i, j), nrm.call(i + 1, j + 1), nrm.call(i, j + 1), col, o)
					faces.append_array(PackedVector3Array([p00, p10, p11, p00, p11, p01]))
	if kit.is_empty():
		return
	var mesh: ArrayMesh = _baustelle.commit(pk, kit)
	_share_materials(mesh)
	var body := _body(node, "SpoilHeapsBody", "dirt")
	var mi := MeshInstance3D.new()
	mi.name = "SpoilHeaps"
	mi.mesh = _save_res(mesh, "spoil_jumps", PROP_PREFIX)
	mi.visibility_range_end = 1400.0
	body.add_child(mi)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)


## Stacks of materials round the site: rebar, formwork, bricks, concrete pipes, a cable drum, sand, the mixer truck, a
## dumper, skips and a scaffold.
func _site_materials(_node: Node3D, body: StaticBody3D, rng: RandomNumberGenerator) -> void:
	var items: Array = [
		[Vector2(-80.0, 940.0), "rebar_stack", [6.0], Vector3(7.0, 1.4, 3.0)], [Vector2(-196.0, 944.0), "formwork_stack", [], Vector3(5.0, 2.4, 3.0)],
		[Vector2(-270.0, 860.0), "brick_pallets", [6], Vector3(8.0, 2.0, 4.0)], [Vector2(-560.0, 948.0), "concrete_pipes", [5], Vector3(10.0, 3.0, 6.0)],
		[Vector2(-420.0, 948.0), "cable_drum", [], Vector3(4.0, 4.0, 3.0)], [Vector2(-215.0, 954.0), "sand_pile", [4.0, 2.4], Vector3(9.0, 3.0, 9.0)],
		[Vector2(-610.0, 860.0), "mixer_truck", [], Vector3(5.0, 6.0, 16.0)], [Vector2(-90.0, 862.0), "dumper", [], Vector3(4.0, 4.0, 7.0)],
		[Vector2(-520.0, 862.0), "skip", [5], Vector3(4.0, 2.6, 6.4)], [Vector2(-300.0, 856.0), "skip", [6], Vector3(4.0, 2.6, 6.4)],
	]
	for it in items:
		var c: Vector2 = it[0]
		if _route_dist(c.x, c.y) < ROAD_HALF + 6.0 or _occupied(c.x, c.y):
			continue
		var fn: String = it[1]
		var extra: Array = it[2]
		var size: Vector3 = it[3]
		var at := Vector3(c.x, _ground_at(c.x, c.y), c.y)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf_range(-0.4, 0.4)), at)
		var args: Array = extra
		if fn == "skip":
			args = [rng.randi()]
		_add_prop(_cell_key("bau_small", at, 200.0), _baustelle, xf, func(pk, kit, labels):
			if fn == "mixer_truck" or fn == "dumper":
				_kit_call(_baustelle, fn, [pk, kit])
			else:
				_kit_call(_baustelle, fn, [pk, kit] + args), 1000.0)
		# The solids take the builder's arguments, as far as they take any (a skip's seed doesn't change its box).
		var sfn: String = fn + "_solids"
		var sol = _kit_call(_baustelle, sfn, args.slice(0, _fn_argc(_baustelle, sfn))) if _has_fn(_baustelle, sfn) else null
		if sol is Array and not (sol as Array).is_empty():
			_solids(body, sol, xf)
		else:
			_box(body, Transform3D(xf.basis, at + Vector3(0, size.y * 0.5, 0)), size)
		_note_rect(c, size.x + 2.0, size.z + 2.0, 0.0)


## Leitbaken (red-and-white warning boards) along both edges of the site's road: knockable, as the Leitpfosten are.
func _build_leitbaken(node: Node3D) -> void:
	var m: ArrayMesh = _kit_mesh(_baustelle, "leitbake", func(pk, kit): _kit_call(_baustelle, "leitbake", [pk, kit]))
	if m == null:
		return
	var xfs: Array[Transform3D] = []
	var kinds: Array = _road_kinds()
	var s: float = float(_turn(19)["s1"]) + 60.0
	while s < _finish_s - 90.0:
		var k: int = _kind_at(kinds, s)
		if k == 11 and _jump_span_at(s, 8.0).is_empty() and absf(s - s_roller) > 30.0 and absf(s - _closest_s(EXCAVATOR_AT)) > 26.0:
			for side in [-1.0, 1.0]:
				var sp: Dictionary = _spot(s, side * (ROAD_HALF + 0.9), 0.0)
				var pos: Vector3 = sp["pos"]
				pos.y = _ground_at(pos.x, pos.z)
				var face: Vector3 = sp["fwd"]
				xfs.append(Transform3D(Basis.looking_at(-face, Vector3.UP).scaled(Vector3.ONE * PROP_SCALE), pos))
		s += 24.0
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = m
	mm.instance_count = xfs.size()
	mm.buffer = PropKit.transform_buffer(xfs)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Leitbaken"
	mmi.multimesh = mm
	mmi.set_script(load("res://KnockablePoles.gd"))
	mmi.set("pole_transforms", xfs)
	mmi.set("pole_height", 1.6)
	mmi.set("pole_mass", 4.0)
	mmi.visibility_range_end = 450.0
	node.add_child(mmi)
	print("  Leitbaken: %d" % xfs.size())


const BARGE_LIFE := 60.0

func _barge_scene(seed_v: int) -> PackedScene:
	if _works == null:
		return null
	var pk: PropKit = _works.new_kit(PROP_SCALE)
	var kit := {}
	var labels: Array = []
	pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * PROP_SCALE), Vector3.ZERO))
	_kit_call(_works, "barge", [pk, kit, BARGE_LIFE, labels])
	var mesh: ArrayMesh = _works.commit(pk, kit)
	_share_materials(mesh)
	var root := Node3D.new()
	root.name = "Barge"
	var mi := MeshInstance3D.new()
	mi.name = "Hull"
	mi.mesh = _save_res(mesh, "barge_%d" % seed_v, PROP_PREFIX)
	root.add_child(mi)
	mi.owner = root
	var ps := PackedScene.new()
	ps.pack(root)
	var path := "res://generated/%sbarge_%d.tscn" % [PROP_PREFIX, seed_v]
	ResourceSaver.save(ps, path)
	return load(path)


func _build_barges(node: Node3D) -> void:
	var scene: PackedScene = _barge_scene(1)
	if scene == null:
		return
	var cruise := Node3D.new()
	cruise.name = "CanalBarge"
	cruise.set_script(load("res://SeaBoat.gd"))
	cruise.set("model", scene)
	cruise.set("draft", 0.0)
	cruise.set("length", 3600.0)
	cruise.set("turn_radius", 13.0)
	cruise.set("speed", 4.2)
	cruise.set("phase", 900.0)
	cruise.set("bob_height", 0.05)
	cruise.set("roll_deg", 0.3)
	cruise.set("pitch_deg", 0.15)
	cruise.set("body_top", 6.0)
	if ResourceLoader.exists("res://sounds/kronburg/barge_engine_loop.wav"):
		cruise.set("engine_sound", load("res://sounds/kronburg/barge_engine_loop.wav"))
		cruise.set("engine_db", -2.0)
		cruise.set("engine_unit", 30.0)
	cruise.set("wake_width", 14.0)
	cruise.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.0, CANAL_WATER, CANAL_Z))
	node.add_child(cruise)
	for k in range(2):
		var moored := Node3D.new()
		moored.name = "MooredBarge%d" % k
		moored.set_script(load("res://SeaBoat.gd"))
		moored.set("model", scene)
		moored.set("draft", 0.0)
		moored.set("swing_deg", 0.0)
		moored.set("bob_height", 0.04)
		moored.set("roll_deg", 0.2)
		moored.set("body_top", 6.0)
		moored.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-200.0 + float(k) * 140.0, CANAL_WATER, CANAL_Z - CANAL_HALF + 9.0))
		node.add_child(moored)


# ======================================================================================
#  The start on the Kaiserstraße and the finish at the gasworks: grandstands, crowd barriers, spectators
# ======================================================================================

const SPECTATOR_SCALE := PROP_SCALE / 1.86
## A Ruhr crowd: mostly European, Turkish and Arab families, a few others ([African, South Asian, European, East Asian,
## Arab or mixed]).
const SPECTATOR_SKIN := [0.05, 0.04, 0.72, 0.03, 0.16]
const GRAND_S0 := 82.0
const GRAND_S1 := 200.0
const BARRIER_LAT := ROAD_HALF + PAVEMENT - 0.6

func _build_start(root: Node3D) -> void:
	_barrier_run(root, "StartBarriers", START_S - 120.0, START_S + 150.0, START_S, 5511)
	_grandstand(root, "StartGrandstand", GRAND_S0, GRAND_S1, 1.0)


func _build_finish(root: Node3D) -> void:
	_barrier_run(root, "FinishBarriers", _finish_s - 160.0, _finish_s + 60.0, _finish_s, 5512)
	_grandstand(root, "FinishGrandstand", _finish_s - 130.0, _finish_s - 20.0, -1.0)
	_grandstand(root, "FinishGrandstandSouth", _finish_s - 110.0, _finish_s - 30.0, 1.0)
	# The gasworks: the old gas holder, now the event hall the stage finishes at, a chimney and the old pipes.
	var gy: float = _ground_at(GASWORKS_C.x, GASWORKS_C.y)
	var gxf: Transform3D = _facing(Vector3(1, 0, 0), Vector3(GASWORKS_C.x, gy, GASWORKS_C.y))
	_add_prop("gaswerk", _works, gxf, func(pk, kit, labels): _kit_call(_works, "gasometer", [pk, kit, labels]), 4000.0)
	var body := _body(root, "GaswerkBody", "rock")
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 22.6 * PROP_SCALE
	cyl.height = 60.0 * PROP_SCALE
	cs.shape = cyl
	cs.position = Vector3(GASWORKS_C.x, gy + 30.0 * PROP_SCALE, GASWORKS_C.y)
	body.add_child(cs)
	_note_rect(GASWORKS_C, 54.0 * PROP_SCALE, 54.0 * PROP_SCALE, 0.0)
	var ch := Vector2(GASWORKS_C.x + 20.0, GASWORKS_C.y + 80.0)
	_add_prop("gaswerk", _works, _facing(Vector3(0, 0, 1), Vector3(ch.x, _ground_at(ch.x, ch.y), ch.y)), func(pk, kit, _labels): _kit_call(_works, "chimney", [pk, kit, 55.0, 0]), 4000.0)
	var lab := Label3D.new()
	lab.name = "ZielBanner"
	lab.text = "RALLYE KRONBURG  -  ZIEL"
	lab.font_size = 96
	lab.pixel_size = 0.07
	lab.modulate = Color(1.0, 0.82, 0.25)
	lab.outline_size = 8
	lab.outline_modulate = Color(0.08, 0.06, 0.04)
	lab.double_sided = false
	lab.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	lab.transform = Transform3D(Basis.looking_at(Vector3(-1, 0, 0), Vector3.UP), Vector3(GASWORKS_C.x + 22.7 * PROP_SCALE + 0.6, gy + 18.0, GASWORKS_C.y))
	root.add_child(lab)


## Crowd barriers either side of the route from s0 to s1 (open round the gantry at `gantry`), spectators behind.
func _barrier_run(root: Node3D, node_name: String, s0: float, s1: float, gantry: float, seed_v: int) -> void:
	var node := Node3D.new()
	node.name = node_name
	root.add_child(node)
	var pk := PropKit.new()
	pk.material_for = func(key: String) -> Material: return _camp_material(key)
	var camp := CampKit.new(pk)
	var bkit := {}
	var body := StaticBody3D.new()
	body.name = node_name + "Body"
	node.add_child(body)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var step: float = 2.3 * PROP_SCALE
	var s: float = maxf(s0, 4.0)
	var count := 0
	while s < minf(s1, route_len - 4.0):
		for side in [-1.0, 1.0]:
			if absf(s - gantry) < 9.0:
				continue
			var lat: float = side * BARRIER_LAT
			var sp: Dictionary = _spot(s, lat, 0.0)
			var pos: Vector3 = sp["pos"]
			pos.y = _lap_y(s)
			var fwd: Vector3 = sp["fwd"]
			var xf := Transform3D(Basis(fwd, Vector3.UP, fwd.cross(Vector3.UP)), pos)
			pk.set_frame(xf.scaled_local(Vector3.ONE * PROP_SCALE))
			camp.crowd_barrier(bkit)
			var bs := CollisionShape3D.new()
			var bx := BoxShape3D.new()
			bx.size = Vector3(step, 1.8, 0.35)
			bs.shape = bx
			bs.transform = Transform3D(xf.basis, pos + Vector3(0, 0.9, 0))
			body.add_child(bs)
			count += 1
			for row in range(2):
				if rng.randf() < (0.2 if row == 0 else 0.55):
					continue
				var plat: float = side * (BARRIER_LAT + 1.5 + float(row) * 1.4 + rng.randf_range(0.0, 0.5))
				var ps: Dictionary = _spot(s + rng.randf_range(-1.2, 1.2), plat, 0.0)
				var pp: Vector3 = ps["pos"]
				pp.y = maxf(_ground_at(pp.x, pp.z), _lap_y(s) - 0.1)
				if _occupied(pp.x, pp.z):
					continue
				var face: Vector3 = -(ps["right"] as Vector3) * side
				face = (face + (ps["fwd"] as Vector3) * rng.randf_range(-0.5, 0.5)).normalized()
				_people.append([pp, face, false, false, -1, rng.randf_range(0.9, 1.08)])
		s += step
	pk.reset_frame()
	var bmi := MeshInstance3D.new()
	bmi.name = "Barriers"
	bmi.mesh = _save_res(pk.commit(bkit), node_name.to_snake_case(), PROP_PREFIX)
	bmi.visibility_range_end = 700.0
	node.add_child(bmi)
	print("  %s: %d barriers" % [node_name, count])


## A scaffold grandstand (StadtKit.temp_grandstand) beside the route from s0 to s1 on `side`, facing it, spectators on it.
func _grandstand(root: Node3D, node_name: String, s0: float, s1: float, side: float) -> void:
	var sm: float = (s0 + s1) * 0.5
	var sp: Dictionary = _spot(sm, side * (BARRIER_LAT + 4.0), 0.0)
	var at: Vector3 = sp["pos"]
	at.y = _lap_y(sm) - 0.05
	var face: Vector3 = -(sp["right"] as Vector3) * side
	var xf: Transform3D = _facing(face, at)
	var length: float = (s1 - s0) / PROP_SCALE
	var rows := 8
	var holder := Node3D.new()
	holder.name = node_name
	root.add_child(holder)
	# Named "Grandstand" (in a holder of its own): StageAmbience cheers from it at the green light and the first finish.
	var node := Node3D.new()
	node.name = "Grandstand"
	holder.add_child(node)
	if _stadt == null or not _has_fn(_stadt, "temp_grandstand"):
		return
	var pk: PropKit = _stadt.new_kit(PROP_SCALE)
	var kit := {}
	var labels: Array = []
	pk.set_frame(Transform3D(xf.basis * Basis.from_scale(Vector3.ONE * PROP_SCALE), xf.origin))
	_stadt.temp_grandstand(pk, kit, labels, rows, length)
	pk.reset_frame()
	var mesh: ArrayMesh = _stadt.commit(pk, kit)
	_share_materials(mesh)
	var mi := MeshInstance3D.new()
	mi.name = "Stand"
	mi.mesh = _save_res(mesh, node_name.to_snake_case(), PROP_PREFIX)
	mi.visibility_range_end = 1800.0
	node.add_child(mi)
	for l in labels:
		var lab := Label3D.new()
		lab.text = l[0]
		lab.font_size = 64
		lab.pixel_size = _fit_pixel(l[0], 64, float(l[3]) * PROP_SCALE / 44.8, float(l[5]) * PROP_SCALE if l.size() > 5 else 0.0)
		lab.modulate = l[4]
		lab.outline_size = 4
		lab.outline_modulate = Color(0.05, 0.05, 0.05)
		lab.double_sided = false
		lab.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		var n: Vector3 = (xf.basis * (l[2] as Vector3)).normalized()
		lab.transform = Transform3D(Basis.looking_at(-n, Vector3.UP if absf(n.y) < 0.95 else Vector3.BACK), xf * ((l[1] as Vector3) * PROP_SCALE))
		node.add_child(lab)
	var body := _body(node, node_name + "Body", "rock")
	_solids(body, _kit_call(_stadt, "temp_grandstand_solids", [rows, length]), xf)
	# Spectators on its seats (about three in four taken).
	var seats = _kit_call(_stadt, "temp_grandstand_seats", [rows, length])
	if seats is Array:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(node_name)
		for st in seats:
			if rng.randf() > 0.75:
				continue
			var p: Vector3 = xf * ((st as Vector3) * PROP_SCALE)
			_people.append([p, face, true, true, -1, rng.randf_range(0.9, 1.06)])
	_note_xf(xf, -length * 0.5 * PROP_SCALE, length * 0.5 * PROP_SCALE, -float(rows) * 1.0 * PROP_SCALE, 1.0, 1.0)


# ======================================================================================
#  Trees: the garden's specimens, the moat's willows, plane trees on the Kaiserplatz and along the Ring, birches on the
#  slope down to the docks (WoodlandBuilder, near cells, shadow stand-ins and far cells, as on the other Kronburg stages)
# ======================================================================================

const TREE_CELL := 220.0
const TREE_FAR_RANGE := 1800.0
var _tree_kinds: Array = []

func _bark_key(kind: String) -> String:
	var cm: Dictionary = (load("res://WoodlandBuilder.gd") as Script).get_script_constant_map()
	var bl: Dictionary = cm.get("BROADLEAF", {})
	if bl.has(kind) and (bl[kind] as Dictionary).has("bark"):
		return String(bl[kind]["bark"])
	return kind


func _build_woods(root: Node3D) -> void:
	var t0 := Time.get_ticks_msec()
	var node := Node3D.new()
	node.name = "Baeume"
	root.add_child(node)
	var w = load("res://WoodlandBuilder.gd").new()
	w.save_res = func(res: Resource, n: String) -> Resource: return _save_res(res, n, TREE_PREFIX)
	_tree_kinds = ["oak", "lime", "birch", "spruce", "willow", "plane", "poplar"]
	var leaf_near: ShaderMaterial = _save_res(w.leaf_material(1, 0.14, 18.0), "leaf_near", TREE_PREFIX)
	var leaf_far: ShaderMaterial = _save_res(w.leaf_material(2, 0.14, 18.0), "leaf_far", TREE_PREFIX)
	var rleaf_near: ShaderMaterial = _save_res(w.rhein_leaf_material(1, 0.14, 18.0), "rhein_leaf_near", TREE_PREFIX)
	var rleaf_far: ShaderMaterial = _save_res(w.rhein_leaf_material(2, 0.14, 18.0), "rhein_leaf_far", TREE_PREFIX)
	var lod_mats: Array[ShaderMaterial] = [leaf_near, leaf_far, rleaf_near, rleaf_far]
	var near_meshes: Array = []
	var far_meshes: Array = []
	for kind in _tree_kinds:
		var bk: String = _bark_key(kind)
		var bn: ShaderMaterial = _save_res(w.bark_material(bk, 1), "bark_%s_near" % kind, TREE_PREFIX)
		var bf: ShaderMaterial = _save_res(w.bark_material(bk, 2), "bark_%s_far" % kind, TREE_PREFIX)
		lod_mats.append(bn)
		lod_mats.append(bf)
		var rh: bool = w.uses_rhein_atlas(kind)
		near_meshes.append(_save_res(w.tree_mesh(kind, 0, 0, bn, rleaf_near if rh else leaf_near), "tree_%s" % kind, TREE_PREFIX))
		far_meshes.append(_save_res(w.tree_mesh(kind, 0, 1, bf, rleaf_far if rh else leaf_far), "tree_%s_far" % kind, TREE_PREFIX))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7801
	var cells := {}
	var counts := {}
	var add := func(kind: String, px: float, pz: float, sc: float) -> void:
		var g: float = _ground_at(px, pz)
		var lean := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.04))
		var xf := Transform3D(lean * Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.92, 1.1), sc)), Vector3(px, g - 0.3, pz))
		var mi: int = _tree_kinds.find(kind)
		var key := Vector3i(floori(px / TREE_CELL), floori(pz / TREE_CELL), mi)
		if not cells.has(key):
			cells[key] = []
		cells[key].append(xf)
		counts[kind] = int(counts.get(kind, 0)) + 1
		_note_rect(Vector2(px, pz), 3.0, 3.0, 0.0, 0.0)
	var ok := func(px: float, pz: float, clear: float) -> bool:
		if _occupied(px, pz) or _route_dist(px, pz) < clear:
			return false
		if absf(px - RING_X) < RING_HALF + 4.0 and pz < RING_PORTAL_Z + 30.0:
			return false
		if absf(pz - RAIL_Z) < EMBANK_HALF + 8.0:
			return false
		if (Vector2(px, pz) - POND_C).length() < POND_R.x * 1.2 and ((Vector2(px, pz) - POND_C) / POND_R).length() < 1.25:
			return false
		if absf(pz - MOAT_Z) < MOAT_HALF + 3.0 and px > MOAT_X.x and px < MOAT_X.y:
			return false
		return true
	# The garden: specimen trees in groups on the lawns, fewer on the Alpinum, a willow or two by the pond.
	var x: float = float(GARDEN_RECT[0]) + 10.0
	while x < float(GARDEN_RECT[2]) - 10.0:
		var z: float = float(GARDEN_RECT[1]) + 10.0
		while z < float(GARDEN_RECT[3]) - 8.0:
			var px: float = x + rng.randf_range(-6.0, 6.0)
			var pz: float = z + rng.randf_range(-6.0, 6.0)
			z += 16.0
			var f: float = _forest_noise.get_noise_2d(px, pz)
			var dens: float = smoothstep(-0.05, 0.3, f) * 0.75 + 0.06
			if px > 590.0 and px < 815.0 and pz > -455.0 and pz < -345.0:
				dens *= 0.35
			if rng.randf() > dens or not ok.call(px, pz, 15.0):
				continue
			var roll: float = rng.randf()
			var kind := "lime"
			if (Vector2(px, pz) - POND_C).length() < 70.0:
				kind = "willow" if roll < 0.6 else "birch"
			elif roll < 0.22:
				kind = "oak"
			elif roll < 0.38:
				kind = "plane"
			elif roll < 0.52:
				kind = "birch"
			elif roll < 0.64:
				kind = "spruce"
			elif roll < 0.72:
				kind = "poplar"
			add.call(kind, px, pz, rng.randf_range(0.85, 1.25))
		x += 16.0
	# The moat's park: willows along the water, limes on the banks.
	x = MOAT_X.x
	while x < MOAT_X.y:
		for side in [-1.0, 1.0]:
			var px2: float = x + rng.randf_range(-4.0, 4.0)
			var pz2: float = MOAT_Z + side * rng.randf_range(MOAT_HALF + 5.0, MOAT_HALF + 22.0)
			if rng.randf() < 0.55 and ok.call(px2, pz2, 14.0):
				add.call("willow" if absf(pz2 - MOAT_Z) < MOAT_HALF + 11.0 else "lime", px2, pz2, rng.randf_range(0.9, 1.2))
		x += 15.0
	# Plane trees on the Kaiserplatz round the start, and along both sides of the Ring away from the crossing.
	for tp in [Vector2(-1205.0, -16.0), Vector2(-1205.0, 22.0), Vector2(-1180.0, 52.0), Vector2(-1130.0, 52.0), Vector2(-1080.0, 50.0)]:
		if ok.call(tp.x, tp.y, 12.0):
			add.call("plane", tp.x, tp.y, 1.0)
	var rz: float = RING_Z0 + 40.0
	while rz < RING_RAMP_Z - 20.0:
		if absf(rz - RING_CROSS.y) > 40.0 and absf(rz - RAIL_Z) > EMBANK_HALF + 12.0:
			for sd in [-1.0, 1.0]:
				var tx: float = RING_X + sd * (RING_HALF - 1.6)
				if not _occupied(tx, rz):
					add.call("plane", tx, rz, 0.8)
		rz += 24.0
	# Birches and poplars on the slope down to the docks, and along the canal.
	x = FINE_X.x + 30.0
	while x < FINE_X.y - 30.0:
		var e: float = _edge_z(x)
		var z3: float = e - 60.0
		while z3 < e + 70.0:
			var px3: float = x + rng.randf_range(-5.0, 5.0)
			var pz3: float = z3 + rng.randf_range(-5.0, 5.0)
			z3 += 13.0
			if rng.randf() > 0.42 or not ok.call(px3, pz3, 16.0):
				continue
			var g3: float = _ground_at(px3, pz3)
			var slope: float = Vector2(_ground_at(px3 + 3.0, pz3) - g3, _ground_at(px3, pz3 + 3.0) - g3).length() / 3.0
			if slope > 0.8:
				continue
			add.call("birch" if rng.randf() < 0.7 else "poplar", px3, pz3, rng.randf_range(0.8, 1.15))
		x += 13.0
	var cell_r: float = TREE_CELL * 0.72
	var near_end: float = 170.0 + cell_r
	var total := 0
	for key in cells.keys():
		var list: Array = cells[key]
		var mid := Vector3((float(key.x) + 0.5) * TREE_CELL, 0.0, (float(key.y) + 0.5) * TREE_CELL)
		var local: Array = []
		for t in list:
			local.append(Transform3D((t as Transform3D).basis, (t as Transform3D).origin - mid))
		var srng := RandomNumberGenerator.new()
		srng.seed = key.x * 7919 + key.y * 104729 + key.z * 31
		for i in range(local.size() - 1, 0, -1):
			var j := srng.randi_range(0, i)
			var tmp: Transform3D = local[i]
			local[i] = local[j]
			local[j] = tmp
		total += local.size()
		var near_mmi := _multimesh(node, "Tree_%d_%d_%d" % [key.x, key.y, key.z], near_meshes[key.z], local, near_end, false)
		near_mmi.position = mid
		near_mmi.visibility_range_end_margin = 10.0
		var proxy := _multimesh(node, "TreeShadow_%d_%d_%d" % [key.x, key.y, key.z], far_meshes[key.z], local, near_end, true)
		proxy.position = mid
		proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		var far_mmi := _multimesh(node, "Trees_far_%d_%d_%d" % [key.x, key.y, key.z], far_meshes[key.z], local, TREE_FAR_RANGE, false)
		far_mmi.position = mid
		far_mmi.visibility_range_end_margin = TREE_FAR_RANGE * 0.1
		far_mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		far_mmi.set_meta(&"base_range", TREE_FAR_RANGE)
	var detail := Node3D.new()
	detail.name = "JungleDetail"
	detail.set_script(load("res://JungleDetail.gd"))
	detail.set("lod_materials", lod_mats)
	detail.set("tree_fade", 40.0)
	detail.set("tree_fade_jitter", 12.0)
	detail.set("forest_cell", TREE_CELL)
	node.add_child(detail)
	print("  trees: %d %s in %d cells (%.1fs)" % [total, str(counts), cells.size(), (Time.get_ticks_msec() - t0) / 1000.0])


# ======================================================================================
#  Sound: the Ring's traffic, the garden's fountain and birds, the docks' machines (the hazards carry their own)
# ======================================================================================

func _build_sounds(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Sounds"
	root.add_child(node)
	var z: float = RING_Z0 + 200.0
	var k := 0
	while z < RING_RAMP_Z:
		_player(node, "RingTraffic%d" % k, "res://sounds/stadtrallye/ring_traffic_loop.wav", Vector3(RING_X, CITY_Y + 2.0, z), -8.0, 40.0, 500.0)
		z += 220.0
		k += 1
	_player(node, "ParterreFountain", "res://sounds/Gentle_flowing_water.wav", Vector3(215.0, _pad_y["parterre"] + 1.5, -248.0), -6.0, 14.0, 160.0)
	_player(node, "ZoneFountain", "res://sounds/Gentle_flowing_water.wav", _spot(_closest_s(Vector2(FOUNTAIN_X, 270.0)), PED_FRONT + 6.0, 1.5)["pos"], -8.0, 12.0, 140.0)
	_player(node, "Baustelle", "res://sounds/stadtrallye/site_ambience_loop.wav", Vector3(-300.0, DOCK_Y + 3.0, 930.0), -10.0, 50.0, 500.0)
	_player(node, "Schrottplatz", "res://sounds/stadtrallye/scrapyard_ambience_loop.wav", Vector3(150.0, DOCK_Y + 3.0, 720.0), -10.0, 45.0, 450.0)
