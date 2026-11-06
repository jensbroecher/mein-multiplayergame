# regenerate_kronburg.gd
#
# Builds levels/KronburgLevel.tscn - Kronburger Hütte, the first stage of the Kronburg GP: a fictional town in the
# Ruhrgebiet on a summer afternoon. The lap starts on the Kanalstraße beside the canal, turns in through the works gate
# of the Kronburger Hütte (the steelworks in the valley), runs straight through the rolling mill hall (Walzwerk 2), round
# the blast furnace and out along the works' north road under the pipe bridges, climbs through the colliery estate
# (Zechensiedlung) under the headframe of the old Zeche Kronprinz, enters the half-timbered Altstadt through its gate,
# crosses the Marktplatz between St. Lamberti and the Rathaus, and drops down the Kirchberg back to the canal. Burg
# Kronburg's ruin stands on the hill above the town; the slag heap east of the works carries the steel crown.
#
# Things worth knowing before editing this file:
#
# 1. The lap is straights and arcs (CORNERS: corner points and radii, filleted). Every road surface is a ribbon laid a
#    few centimetres over the graded ground (as on Marina Nights), drawn by kronburg_road.gdshader by kind (_road_kinds:
#    country asphalt, the old town's cobbles, the estate's street, the works' concrete, the mill hall's floor, the
#    market square), and every triangle the lap runs on is one body, LapRoad (track). The ground is one heightfield
#    (kronburg_ground.gdshader, masks in the vertex colour) graded to the road (`_grade`).
# 2. The ground's natural shape is `_natural`: the valley rising toward the north-west (`_rise` of the distance up the
#    slope), the castle hill, the slag heap, the canal cut along CANAL_Z, the works' pad, the market square's pad. The
#    road's height is the natural ground along the lap smoothed (`_plan_road_heights`), the square held level.
# 3. The town's buildings are KronburgTownKit.gd's, the works' SteelworksKit.gd's: life size, grown by PROP_SCALE, one
#    mesh each saved under PROP_PREFIX (MeshChunker leaves them whole, so DressingColliders makes them solid at race
#    time).
#
# The generator runs headless and cannot render; scratch/lap_shots.tscn renders the lap.
extends Node

const LEVEL_NAME := "KronburgLevel"
const LEVEL_PATH := "res://levels/KronburgLevel.tscn"
const RES_PREFIX := "kronburg_"
const PROP_PREFIX := "kronburgprop_"
const MeshChunker = preload("res://MeshChunker.gd")
const PropKit = preload("res://PropKit.gd")
const YardKit = preload("res://YardKit.gd")

const MESH_CHUNK_CELL := 80.0
const PROP_SCALE := 1.6

## The carriageway's half width (the AI's road half is 7.5 by default) and the pavements in town.
const ROAD_HALF := 7.5
const PAVEMENT := 3.4
## The ground under a ribbon lies this far below the road's surface.
const GROUND_UNDER := 0.07
const SAMPLE_STEP := 3.0
const CELL := 32.0
const GRADE_REACH := 48.0

## The lap: corner points (x east, z south) and fillet radii.
const CORNERS := [
	[Vector2(-640.0, 250.0), 55.0],   # C0: off the Kirchberg onto the Kanalstraße
	[Vector2(40.0, 250.0), 40.0],     # C1: left into the works
	[Vector2(40.0, 90.0), 32.0],      # C2: right, lined up on the mill hall
	[Vector2(580.0, 90.0), 45.0],     # C3: left past the blast furnace
	[Vector2(580.0, -150.0), 50.0],   # C4: left onto the north road
	[Vector2(120.0, -150.0), 60.0],   # C5: out of the works, up into the estate
	[Vector2(-200.0, -230.0), 45.0],  # C6: the town gate
	[Vector2(-450.0, -230.0), 22.0],  # C7: the Marktplatz
	[Vector2(-470.0, 40.0), 60.0],    # C8: down the Kirchberg
]

## The valley's floor (the canal's plain and the works) and the canal.
const VALLEY_Y := 2.0
const CANAL_Z := 310.0
const CANAL_HALF := 32.0
const CANAL_BED := -3.2
const WATER_Y := 0.6
## The works' pad: [x0, z0, x1, z1], its height and blend.
const WORKS_RECT := [40.0, -265.0, 660.0, 255.0]
const WORKS_Y := 1.8
const WORKS_BLEND := 60.0
## The works' harbour basin, dug off the canal: [x0, z0, x1, z1].
const HARBOUR_RECT := [170.0, 196.0, 345.0, 300.0]
const CASTLE_C := Vector2(-370.0, -470.0)
## The slag heap: centre, foot radius, plateau radius, height.
const HALDE_C := Vector2(810.0, -40.0)
const HALDE_R0 := 185.0
const HALDE_R1 := 38.0
const HALDE_H := 46.0
## The market square: its paving's corners [x0, z0, x1, z1].
const MARKT_RECT := [-546.0, -312.0, -436.0, -211.0]
## The old town and the estate (no fields or woods inside).
const TOWN_RECT := [-600.0, -360.0, -205.0, -60.0]
const ESTATE_RECT := [-215.0, -310.0, 60.0, -48.0]

## The terrain grid.
const FINE_X := Vector2(-1650.0, 1750.0)
const FINE_Z := Vector2(-760.0, 600.0)
const FINE_STEP := 5.0
const OUTER := 6500.0
const COARSE_GROWTH := 1.16
const COARSE_MAX := 180.0

const FINISH_X := -420.0
## The square's stretch of road held level (either side of its corner), and the steepest grade anywhere else.
const MARKT_HOLD := 30.0
const MAX_GRADE := 0.105

var level: Node3D
var segs: Array = []
var lap_len := 0.0
var _road_y := PackedFloat32Array()
var _markt_y := 0.0

var _noise := FastNoiseLite.new()
var _hill_noise := FastNoiseLite.new()
var _forest_noise := FastNoiseLite.new()
var _field_noise := FastNoiseLite.new()

var _rs_pos := PackedVector3Array()
var _rs_right := PackedVector3Array()
var _rs_flat := PackedFloat32Array()
var _rs_cells := {}

var _grid_x := PackedFloat32Array()
var _grid_z := PackedFloat32Array()
var _heights := PackedFloat32Array()
var _road_d := PackedFloat32Array()
var _lap_faces := PackedVector3Array()
var _ground_mat: ShaderMaterial
var _road_mat: ShaderMaterial


# ======================================================================================
#  The lap
# ======================================================================================

func _dir_of(th: float) -> Vector2:
	return Vector2(cos(th), sin(th))


## Right of travel for a heading (x east, z south: heading east has the south on its right).
func _right_of(th: float) -> Vector2:
	return Vector2(-sin(th), cos(th))


func _fillet(corners: Array) -> void:
	var n: int = corners.size()
	var a_in: Array = []
	var a_out: Array = []
	var arcs: Array = []
	for i in range(n):
		var b: Vector2 = corners[i][0]
		var r: float = corners[i][1]
		var a: Vector2 = corners[(i - 1 + n) % n][0]
		var c: Vector2 = corners[(i + 1) % n][0]
		var d1: Vector2 = (b - a).normalized()
		var d2: Vector2 = (c - b).normalized()
		var ang: float = atan2(d1.x * d2.y - d1.y * d2.x, d1.dot(d2))
		var t: float = r * tan(absf(ang) * 0.5)
		if t > b.distance_to(a) * 0.5 + 0.01 or t > b.distance_to(c) * 0.5 + 0.01:
			push_error("Kronburg lap: corner %d's radius %.0f does not fit" % [i, r])
		a_in.append(b - d1 * t)
		a_out.append(b + d2 * t)
		if absf(ang) < 0.0001 or r <= 0.0:
			arcs.append(null)
		else:
			arcs.append({"kind": "A", "p0": b - d1 * t, "th0": atan2(d1.y, d1.x), "r": r, "sign": signf(ang), "len": r * absf(ang)})
	segs.clear()
	var s := 0.0
	var prev: Vector2 = a_out[0]
	for k in range(1, n + 1):
		var i: int = k % n
		var p_in: Vector2 = a_in[i]
		var length: float = prev.distance_to(p_in)
		if length > 0.001:
			var dd: Vector2 = (p_in - prev) / length
			segs.append({"kind": "S", "p0": prev, "th0": atan2(dd.y, dd.x), "len": length, "s0": s})
			s += length
		if arcs[i] != null:
			var arc: Dictionary = (arcs[i] as Dictionary).duplicate()
			arc["s0"] = s
			segs.append(arc)
			s += float(arc["len"])
		prev = a_out[i]
	lap_len = s


## Position (x, z), heading and signed curvature at s along the lap.
func _at(s: float) -> Dictionary:
	s = fposmod(s, lap_len)
	var seg: Dictionary = segs[0]
	for i in range(segs.size() - 1, -1, -1):
		if s >= float(segs[i]["s0"]) - 0.0001:
			seg = segs[i]
			break
	var dd: float = s - float(seg["s0"])
	var p0: Vector2 = seg["p0"]
	var th0: float = seg["th0"]
	if seg["kind"] == "S":
		return {"p": p0 + _dir_of(th0) * dd, "th": th0, "k": 0.0}
	var r: float = seg["r"]
	var sg: float = seg["sign"]
	var c: Vector2 = p0 + _right_of(th0) * r * sg
	var th: float = th0 + sg * dd / r
	return {"p": c - _right_of(th) * r * sg, "th": th, "k": sg / r}


func _lap_y(s: float) -> float:
	var n: int = _road_y.size()
	var f: float = fposmod(s, lap_len)
	var i: int = int(floor(f))
	var t: float = f - float(i)
	return lerpf(_road_y[i % n], _road_y[(i + 1) % n], t)


func _pt(s: float) -> Vector3:
	var p: Vector2 = _at(s)["p"]
	return Vector3(p.x, _lap_y(s), p.y)


func _rt(s: float) -> Vector3:
	var r: Vector2 = _right_of(float(_at(s)["th"]))
	return Vector3(r.x, 0.0, r.y)


func _fw(s: float) -> Vector3:
	var f: Vector2 = _dir_of(float(_at(s)["th"]))
	return Vector3(f.x, 0.0, f.y)


## A spot on the lap: `lat` metres right of the centreline, `lift` over the road, the yaw facing the way of travel
## (a node's -z along the lap).
func _spot(s: float, lat: float, lift: float) -> Dictionary:
	var fwd: Vector3 = _fw(s)
	var right: Vector3 = _rt(s)
	var pos: Vector3 = _pt(s) + right * lat + Vector3(0, lift, 0)
	return {"pos": pos, "yaw": rad_to_deg(atan2(-fwd.x, -fwd.z)), "fwd": fwd, "right": right}


## The s nearest to q in plan (a coarse walk, then a fine one).
func _closest_s(q: Vector2) -> float:
	var best := 0.0
	var bd := INF
	var s := 0.0
	while s < lap_len:
		var d: float = (_at(s)["p"] as Vector2).distance_squared_to(q)
		if d < bd:
			bd = d
			best = s
		s += 4.0
	var lo: float = best - 4.0
	var hi: float = best + 4.0
	s = lo
	while s <= hi:
		var d2: float = (_at(s)["p"] as Vector2).distance_squared_to(q)
		if d2 < bd:
			bd = d2
			best = s
		s += 0.1
	return fposmod(best, lap_len)


## The corner's apex s (the middle of its arc).
func _corner_s(i: int) -> float:
	return _closest_s(CORNERS[i][0])


# ======================================================================================
#  The natural ground
# ======================================================================================

func _init_noise() -> void:
	_noise.seed = 4201
	_noise.frequency = 0.004
	_noise.fractal_octaves = 4
	_hill_noise.seed = 4202
	_hill_noise.frequency = 0.0016
	_hill_noise.fractal_octaves = 4
	_forest_noise.seed = 4203
	_forest_noise.frequency = 0.0042
	_forest_noise.fractal_octaves = 3
	_field_noise.seed = 4204
	_field_noise.frequency = 0.003
	_field_noise.fractal_octaves = 2


## How high the valley's side stands `u` metres up its slope (toward the north-west).
const RISE := [[-1000.0, 1.6], [-20.0, 1.6], [60.0, 2.4], [130.0, 5.5], [200.0, 11.0], [300.0, 20.0], [420.0, 29.0],
		[560.0, 38.0], [800.0, 50.0], [1400.0, 72.0], [3200.0, 118.0]]

func _rise(u: float) -> float:
	if u <= float(RISE[0][0]):
		return RISE[0][1]
	for i in range(RISE.size() - 1):
		var a: Array = RISE[i]
		var b: Array = RISE[i + 1]
		if u <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (u - float(a[0])) / (float(b[0]) - float(a[0])))
	return RISE[RISE.size() - 1][1]


func _rect_weight(x: float, z: float, r: Array, blend: float) -> float:
	var dx: float = maxf(maxf(float(r[0]) - x, x - float(r[2])), 0.0)
	var dz: float = maxf(maxf(float(r[1]) - z, z - float(r[3])), 0.0)
	var d: float = sqrt(dx * dx + dz * dz)
	return 1.0 - smoothstep(0.0, blend, d)


func _in_rect(x: float, z: float, r: Array, pad := 0.0) -> bool:
	return x > float(r[0]) - pad and x < float(r[2]) + pad and z > float(r[1]) - pad and z < float(r[3]) + pad


## The ground before the pads, the canal and the heap: the valley's side, its hills, the castle hill, the far country.
func _raw_natural(x: float, z: float) -> float:
	var u: float = -0.49 * x - 0.87 * z
	var h: float = _rise(u)
	var up: float = clampf(u / 420.0, 0.0, 1.0)
	h += _hill_noise.get_noise_2d(x, z) * lerpf(1.2, 8.0, up)
	h += _noise.get_noise_2d(x, z) * lerpf(0.4, 1.6, up)
	h += 26.0 * exp(-pow(Vector2(x, z).distance_to(CASTLE_C) / 120.0, 2.0))
	# The far country: hills to the south across the canal, and east past the heap.
	h += smoothstep(CANAL_Z + 200.0, CANAL_Z + 1500.0, z) * (40.0 + 25.0 * _hill_noise.get_noise_2d(x * 0.7 + 900.0, z * 0.7))
	h += smoothstep(1250.0, 2600.0, x) * (45.0 + 25.0 * _hill_noise.get_noise_2d(x * 0.6, z * 0.6 - 700.0))
	# The canal's plain: the valley floor eases flat toward the canal.
	var dzc: float = absf(z - CANAL_Z)
	var plain: float = smoothstep(175.0, 65.0, dzc)
	h = lerpf(h, VALLEY_Y + 0.25 * _noise.get_noise_2d(x * 2.0, z * 2.0), plain)
	return h


## The natural ground with the pads, the canal and the slag heap.
func _natural(x: float, z: float) -> float:
	var h: float = _raw_natural(x, z)
	# The works' pad.
	var ww: float = _rect_weight(x, z, WORKS_RECT, WORKS_BLEND)
	h = lerpf(h, WORKS_Y, ww)
	# The market square's pad.
	var mw: float = _rect_weight(x, z, MARKT_RECT, 24.0)
	h = lerpf(h, _markt_y - GROUND_UNDER, mw)
	# The football pitch's pad.
	var sw: float = _rect_weight(x, z, SPORT_RECT, 18.0)
	h = lerpf(h, _sport_y, sw)
	# The castle's hilltop, levelled for the ruin.
	var cw: float = 1.0 - smoothstep(26.0, 52.0, Vector2(x, z).distance_to(CASTLE_C))
	h = lerpf(h, _castle_y, cw)
	# The slag heap: a cone with a plateau, terraced a little.
	var dh: float = Vector2(x, z).distance_to(HALDE_C)
	if dh < HALDE_R0 + 20.0:
		var t: float = clampf((HALDE_R0 - dh) / (HALDE_R0 - HALDE_R1), 0.0, 1.0)
		var heap: float = WORKS_Y + HALDE_H * (t * t * (3.0 - 2.0 * t) * 0.35 + t * 0.65)
		heap += 0.8 * sin(t * 18.0) * t * (1.0 - t) * 4.0
		heap += _noise.get_noise_2d(x * 3.0, z * 3.0) * 0.8 * t
		h = maxf(h, heap)
	# The canal: sloped banks of stone down to its bed.
	var dzc: float = absf(z - CANAL_Z)
	if dzc < CANAL_HALF:
		h = minf(h, lerpf(CANAL_BED, VALLEY_Y, clampf((dzc - (CANAL_HALF - 10.4)) / 10.4, 0.0, 1.0)))
	# The works' harbour, off the canal.
	var hd: float = maxf(maxf(float(HARBOUR_RECT[0]) - x, x - float(HARBOUR_RECT[2])), maxf(float(HARBOUR_RECT[1]) - z, z - float(HARBOUR_RECT[3])))
	if hd < 0.0:
		h = minf(h, lerpf(CANAL_BED, WORKS_Y, clampf((hd + 9.0) / 9.0, 0.0, 1.0)))
	return h


var _castle_y := 60.0
var _sport_y := 4.0
## The football pitch (red ash, Ascheplatz) and its surround: [x0, z0, x1, z1].
const SPORT_RECT := [-110.0, 60.0, 30.0, 160.0]
## The allotments (Kleingartenanlage) and the beer garden by the Kanalstraße.
const ALLOT_X := Vector2(-340.0, -150.0)
const ALLOT_Z := 190.0
const BEERGARDEN_AT := Vector2(-110.0, 220.0)


# ======================================================================================
#  The road's height and the grading
# ======================================================================================

func _plan_road_heights() -> void:
	var n: int = int(ceil(lap_len)) + 1
	var raw := PackedFloat32Array()
	raw.resize(n)
	for i in range(n):
		var p: Vector2 = _at(float(i))["p"]
		raw[i] = _natural(p.x, p.y) + GROUND_UNDER
	# Smoothed along the lap: a box of 41m three times (about a 120m bell), round the closed lap.
	var cur := raw
	for pass_i in range(3):
		var out := PackedFloat32Array()
		out.resize(n)
		var reach := 20
		for i in range(n):
			var acc := 0.0
			for k in range(-reach, reach + 1):
				acc += cur[(i + k + n * 4) % n]
			out[i] = acc / float(2 * reach + 1)
		cur = out
	# The market square held level, eased in and out.
	var s7: float = _corner_s(7)
	var hold := PackedByteArray()
	hold.resize(n)
	for i in range(n):
		var s: float = float(i)
		var d: float = absf(fposmod(s - s7 + lap_len * 0.5, lap_len) - lap_len * 0.5)
		var w: float = 1.0 - smoothstep(MARKT_HOLD, MARKT_HOLD + 70.0, d)
		cur[i] = lerpf(cur[i], _markt_y, w)
		hold[i] = 1 if d < MARKT_HOLD else 0
	# No grade steeper than MAX_GRADE: forward and back round the lap, the square left as it is; then a light smoothing.
	for it in range(4):
		for i in range(1, n):
			if hold[i] == 0:
				cur[i] = clampf(cur[i], cur[i - 1] - MAX_GRADE, cur[i - 1] + MAX_GRADE)
		for i in range(n - 2, -1, -1):
			if hold[i] == 0:
				cur[i] = clampf(cur[i], cur[i + 1] - MAX_GRADE, cur[i + 1] + MAX_GRADE)
	var sm := cur.duplicate()
	for i in range(n):
		if hold[i] == 1:
			continue
		var acc := 0.0
		for k in range(-6, 7):
			acc += cur[(i + k + n * 4) % n]
		sm[i] = acc / 13.0
	cur = sm
	# Never below the natural ground's level in the works or the canal plain by more than the ground's margin.
	_road_y = cur
	var max_grade := 0.0
	var at := 0.0
	for i in range(n - 1):
		var g: float = absf(cur[i + 1] - cur[i])
		if g > max_grade:
			max_grade = g
			at = float(i)
	print("  lap %.0fm, road from %.1f to %.1fm, steepest %.1f%% at %.0fm" % [lap_len, _min(cur), _max(cur), max_grade * 100.0, at])


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


## Road samples for the grading: every SAMPLE_STEP along the lap, with the flat band's half width (the ribbon and a verge).
func _add_samples() -> void:
	var s := 0.0
	var kinds: Array = _road_kinds()
	while s < lap_len:
		var p: Vector3 = _pt(s)
		var w: float = _ribbon_half(_kind_at(kinds, s))
		_rs_pos.append(p)
		_rs_right.append(_rt(s))
		_rs_flat.append(w + 1.6)
		var key := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
		if not _rs_cells.has(key):
			_rs_cells[key] = PackedInt32Array()
		var arr: PackedInt32Array = _rs_cells[key]
		arr.append(_rs_pos.size() - 1)
		_rs_cells[key] = arr
		s += SAMPLE_STEP


## The ground graded to the road: level with it (GROUND_UNDER under) across the flat band, then rounded shoulders
## rising or falling at most `cut`/`fill` a metre out to the natural ground. Returns the height and the distance to the
## lap's centreline.
func _grade(h: float, x: float, z: float) -> Vector2:
	var cx: int = floori(x / CELL)
	var cz: int = floori(z / CELL)
	var upper := 1e9
	var lower := -1e9
	var touched := false
	var flat_y := NAN
	var flat_lat := 1e9
	var best_d := 1e9
	var n: int = _rs_pos.size()
	for gz in range(cz - 2, cz + 3):
		for gx in range(cx - 2, cx + 3):
			var bucket: PackedInt32Array = _rs_cells.get(Vector2i(gx, gz), PackedInt32Array())
			for i in bucket:
				var j: int = (i + 1) % n
				var a: Vector3 = _rs_pos[i]
				var dx: float = x - a.x
				var dz: float = z - a.z
				if dx * dx + dz * dz > GRADE_REACH * GRADE_REACH:
					continue
				var b: Vector3 = _rs_pos[j]
				var sx: float = b.x - a.x
				var sz: float = b.z - a.z
				var l2: float = sx * sx + sz * sz
				if l2 < 1e-6:
					continue
				var t: float = clampf((dx * sx + dz * sz) / l2, 0.0, 1.0)
				var fx: float = x - (a.x + sx * t)
				var fz: float = z - (a.z + sz * t)
				var lateral: float = sqrt(fx * fx + fz * fz)
				best_d = minf(best_d, lateral)
				var foot_y: float = lerpf(a.y, b.y, t) - GROUND_UNDER
				var flat: float = _rs_flat[i]
				var over: float = maxf(0.0, lateral - flat)
				var soft: float = over * over / (over + 5.0)
				upper = minf(upper, foot_y + soft * 0.75)
				lower = maxf(lower, foot_y - soft * 0.6)
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


func _build_heights() -> void:
	_grid_x = _grid_axis(FINE_X)
	_grid_z = _grid_axis(FINE_Z)
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
			var h: float = _natural(x, z)
			var near: bool = x > FINE_X.x - 60.0 and x < FINE_X.y + 60.0 and z > FINE_Z.x - 60.0 and z < FINE_Z.y + 60.0
			if not near:
				_heights[i] = h
				_road_d[i] = 1e9
				continue
			var g: Vector2 = _grade(h, x, z)
			_heights[i] = g.x
			# Out of the grading's reach the distance is "far" (1e9): keep it under 1e8, the fine grid's mark (_build_terrain
			# paints the coarse land's masks past it, and inside the works that painted fields).
			_road_d[i] = minf(g.y, 1.0e7)


## Ground height at any (x, z) from the built heightfield, on the mesh's own triangles (each cell split along the
## diagonal joining its closer heights).
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


## The lowest and highest ground under a footprint (a w x d rectangle at c turned yaw), sampled every 2m.
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


## The ground's masks: R sandstone, G the works' ground, B farmland, A woodland floor.
func _forest_w(x: float, z: float) -> float:
	var f: float = _forest_noise.get_noise_2d(x, z)
	var u: float = -0.49 * x - 0.87 * z
	# Woods on the valley's side, the castle hill, round the heap and in a few copses on the plain.
	var w: float = smoothstep(0.08, 0.28, f + 0.18 * smoothstep(120.0, 420.0, u))
	w = maxf(w, 1.0 - smoothstep(110.0, 175.0, Vector2(x, z).distance_to(CASTLE_C)))
	var dh: float = Vector2(x, z).distance_to(HALDE_C)
	w = maxf(w, smoothstep(0.0, 0.25, f + 0.3) * (1.0 - smoothstep(HALDE_R0 - 10.0, HALDE_R0 + 25.0, dh)) * smoothstep(HALDE_R1 + 30.0, HALDE_R1 + 70.0, dh))
	return w


func _open_land(x: float, z: float) -> float:
	var town: float = maxf(_rect_weight(x, z, TOWN_RECT, 30.0), _rect_weight(x, z, ESTATE_RECT, 25.0))
	town = maxf(town, _rect_weight(x, z, SPORT_RECT, 12.0))
	town = maxf(town, _rect_weight(x, z, [ALLOT_X.x - 8.0, ALLOT_Z - 30.0, ALLOT_X.y + 40.0, ALLOT_Z + 34.0], 12.0))
	var works: float = _rect_weight(x, z, WORKS_RECT, 25.0)
	var canal: float = 1.0 - smoothstep(CANAL_HALF + 6.0, CANAL_HALF + 30.0, absf(z - CANAL_Z))
	var heap: float = 1.0 - smoothstep(HALDE_R0, HALDE_R0 + 30.0, Vector2(x, z).distance_to(HALDE_C))
	return (1.0 - town) * (1.0 - works) * (1.0 - canal) * (1.0 - heap)


func _masks(i: int, x: float, z: float, nrm_y: float) -> Color:
	var road_d: float = _road_d[i]
	var near_road: float = smoothstep(12.0, 30.0, road_d)
	var rock: float = (1.0 - smoothstep(0.62, 0.82, nrm_y)) * smoothstep(10.0, 14.0, road_d)
	# The canal's stone-pitched banks (riprap) from the bed up to the bank's top.
	var dzc: float = absf(z - CANAL_Z)
	if dzc < CANAL_HALF + 1.0 and _heights[i] < VALLEY_Y - 0.2:
		rock = maxf(rock, 0.85)
	var hd: float = maxf(maxf(float(HARBOUR_RECT[0]) - x, x - float(HARBOUR_RECT[2])), maxf(float(HARBOUR_RECT[1]) - z, z - float(HARBOUR_RECT[3])))
	if hd < 1.0 and _heights[i] < WORKS_Y - 0.2:
		rock = maxf(rock, 0.85)
	var works: float = _rect_weight(x, z, WORKS_RECT, 12.0)
	var dh: float = Vector2(x, z).distance_to(HALDE_C)
	works = maxf(works, 1.0 - smoothstep(HALDE_R1 + 20.0, HALDE_R1 + 60.0, dh))
	var open: float = _open_land(x, z)
	var forest: float = _forest_w(x, z) * open * near_road
	forest = maxf(forest, (1.0 - smoothstep(HALDE_R0 - 10.0, HALDE_R0 + 25.0, dh)) * smoothstep(HALDE_R1 + 25.0, HALDE_R1 + 60.0, dh) * 0.85)
	var field: float = open * (1.0 - forest) * smoothstep(-0.25, 0.05, _field_noise.get_noise_2d(x, z)) * smoothstep(16.0, 34.0, road_d)
	# No crops on the canal plain's strip by the road, nor on steep ground.
	field *= smoothstep(0.86, 0.94, nrm_y)
	return Color(rock, works * (1.0 - rock * 0.6), field, forest * (1.0 - works))


const BODIES := [
	["KronburgMeadow", "grass", Color(0, 0, 0, 0)],
	["WorksGround", "gravel", Color(0.36, 0.33, 0.31, 0.65)],
	["KronburgCrag", "rock", Color(0.62, 0.56, 0.46, 0.5)],
]


func _build_terrain(parent: Node3D) -> void:
	var nx: int = _grid_x.size()
	var nz: int = _grid_z.size()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	verts.resize(nx * nz)
	normals.resize(nx * nz)
	colors.resize(nx * nz)
	uvs.resize(nx * nz)
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
				colors[i] = _masks(i, x, z, nrm.y)
			else:
				# Out past the fine grid: farmland and woods by the same noise, rock on the steepest.
				var f: float = _forest_w(x, z)
				colors[i] = Color(1.0 - smoothstep(0.6, 0.8, nrm.y), 0.0, (1.0 - f) * smoothstep(-0.25, 0.05, _field_noise.get_noise_2d(x, z)), f)
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
				if absf(cen.x) > 2400.0 or absf(cen.z) > 2400.0:
					continue
				var wk: float = (colors[tri[0]].g + colors[tri[1]].g + colors[tri[2]].g) / 3.0
				var rk: float = (colors[tri[0]].r + colors[tri[1]].r + colors[tri[2]].r) / 3.0
				var k: int = 0
				if rk > 0.6:
					k = 2
				elif wk > 0.5:
					k = 1
				var f: PackedVector3Array = faces[k]
				f.append(p0)
				f.append(p1)
				f.append(p2)
				faces[k] = f
	var near_mesh: ArrayMesh = _compact_mesh(verts, normals, colors, uvs, near_idx, _ground_mat)
	var inst := MeshInstance3D.new()
	inst.name = "KronburgGroundMesh"
	inst.mesh = _save_res(near_mesh, "ground_visual")
	parent.add_child(inst)
	var far_mesh: ArrayMesh = _compact_mesh(verts, normals, colors, uvs, far_idx, _ground_mat)
	var far_inst := MeshInstance3D.new()
	far_inst.name = "KronburgFarGround"
	far_inst.mesh = _save_res(far_mesh, "far_ground", "kronburgfar_")
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
		idx: PackedInt32Array, mat: Material) -> ArrayMesh:
	var remap := PackedInt32Array()
	remap.resize(verts.size())
	remap.fill(-1)
	var nv := PackedVector3Array()
	var nn := PackedVector3Array()
	var nc := PackedColorArray()
	var nu := PackedVector2Array()
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
		ni[k] = remap[v]
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = nv
	arrays[Mesh.ARRAY_NORMAL] = nn
	arrays[Mesh.ARRAY_COLOR] = nc
	arrays[Mesh.ARRAY_TEX_UV] = nu
	arrays[Mesh.ARRAY_INDEX] = ni
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, mat)
	return mesh


# ======================================================================================
#  The canal
# ======================================================================================

func _build_canal(root: Node3D) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://still_water.gdshader")
	mat.set_shader_parameter("water_color", Color(0.020, 0.055, 0.050, 1.0))
	mat.set_shader_parameter("sky_tint", Color(0.42, 0.58, 0.72, 1.0))
	mat.set_shader_parameter("sky_reflect", 0.5)
	mat.set_shader_parameter("ripple_tile", 26.0)
	mat.set_shader_parameter("ripple_strength", 0.14)
	var noise_tex := NoiseTexture2D.new()
	noise_tex.seamless = true
	noise_tex.as_normal_map = true
	noise_tex.width = 256
	noise_tex.height = 256
	var nz := FastNoiseLite.new()
	nz.frequency = 0.02
	noise_tex.noise = nz
	mat.set_shader_parameter("noise_tex", noise_tex)
	var smat: Material = _save_res(mat, "canal_water_material")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rects: Array = [[FINE_X.x - 200.0, CANAL_Z - CANAL_HALF - 2.0, FINE_X.y + 200.0, CANAL_Z + CANAL_HALF + 2.0],
		[HARBOUR_RECT[0] - 2.0, HARBOUR_RECT[1] - 2.0, HARBOUR_RECT[2] + 2.0, CANAL_Z - CANAL_HALF]]
	for r in rects:
		# In 40m strips so the culling boxes stay small.
		var x0: float = r[0]
		while x0 < float(r[2]) - 0.01:
			var x1: float = minf(x0 + 40.0, r[2])
			var a := Vector3(x0, 0.0, r[1])
			var b := Vector3(x1, 0.0, r[1])
			var c := Vector3(x1, 0.0, r[3])
			var d := Vector3(x0, 0.0, r[3])
			for v in [a, c, b, a, d, c]:
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(v.x, v.z))
				st.add_vertex(v)
			x0 = x1
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, smat)
	var water := MeshInstance3D.new()
	water.name = "CanalWater"
	water.mesh = _save_res(mesh, "canal_water", "kronburgfar_")
	water.position = Vector3(0, WATER_Y, 0)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.set_meta(&"water_surface_y", WATER_Y)
	water.set_meta(&"water_bounds_min", Vector2(FINE_X.x - 200.0, float(HARBOUR_RECT[1]) - 2.0))
	water.set_meta(&"water_bounds_max", Vector2(FINE_X.y + 200.0, CANAL_Z + CANAL_HALF + 2.0))
	root.add_child(water)
	_build_towpath(root)


## The towpath (Leinpfad) along the canal's north bank, a gravel ribbon on the ground (no collider: the meadow's).
const TOWPATH_Z := CANAL_Z - CANAL_HALF - 3.5
const TOWPATH_HALF := 2.2

func _build_towpath(root: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x0: float = FINE_X.x + 20.0
	var x1: float = float(HARBOUR_RECT[0]) - 12.0
	var step := 4.0
	var x: float = x0
	while x < x1:
		var xb: float = minf(x + step, x1)
		var q: Array = []
		for c in [[x, -1.0], [x, 1.0], [xb, -1.0], [xb, 1.0]]:
			var px: float = c[0]
			var pz: float = TOWPATH_Z + float(c[1]) * TOWPATH_HALF
			q.append([Vector3(px, _ground_at(px, pz) + 0.05, pz), Vector2(float(c[1]) * TOWPATH_HALF, px)])
		# Heading east: right of travel is +z, so (left a, right b, next left c): (a, c, b), (b, c, d).
		for tri in [[0, 2, 1], [1, 2, 3]]:
			for k in tri:
				st.set_normal(Vector3.UP)
				st.set_color(Color(1, 0, 0, 1))
				st.set_uv(q[k][1])
				st.set_uv2(Vector2(6.0, TOWPATH_HALF))
				st.add_vertex(q[k][0])
		x = xb
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, _road_mat)
	var mi := MeshInstance3D.new()
	mi.name = "Towpath"
	mi.mesh = _save_res(mesh, "towpath", "kronburgroad_")
	mi.visibility_range_end = 1200.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


# ======================================================================================
#  The roads
# ======================================================================================

## [s0, s1, kind] along the lap (see kronburg_road.gdshader's kinds).
var _kinds_cache: Array = []

func _road_kinds() -> Array:
	if not _kinds_cache.is_empty():
		return _kinds_cache
	var s_gate: float = _closest_s(WORKS_GATE)
	var s_h0: float = _closest_s(Vector2(HALL_X0, HALL_Z))
	var s_h1: float = _closest_s(Vector2(HALL_X0 + HALL_LEN, HALL_Z))
	var s_works_out: float = _closest_s(Vector2(-5.0, -164.0))
	var s_town_gate: float = _closest_s(TOWN_GATE)
	var s7: float = _corner_s(7)
	var s_kirch: float = _closest_s(Vector2(-452.0, -95.0))
	_kinds_cache = [
		[0.0, s_gate, 0],
		[s_gate, s_h0 - 2.0, 3],
		[s_h0 - 2.0, s_h1 + 2.0, 4],
		[s_h1 + 2.0, s_works_out, 3],
		[s_works_out, s_town_gate, 2],
		[s_town_gate, s7 - 38.0, 1],
		[s7 - 38.0, s7 + 30.0, 5],
		[s7 + 30.0, s_kirch, 1],
		[s_kirch, lap_len, 0],
	]
	return _kinds_cache


func _kind_at(kinds: Array, s: float) -> int:
	s = fposmod(s, lap_len)
	for k in kinds:
		if s >= float(k[0]) and s < float(k[1]):
			return int(k[2])
	return 0


## The ribbon's half width: the carriageway and, in town, its pavements.
func _ribbon_half(kind: int) -> float:
	if kind == 1 or kind == 2:
		return ROAD_HALF + PAVEMENT
	if kind == 5:
		return ROAD_HALF + 1.5
	return ROAD_HALF


func _road_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://kronburg_road.gdshader")
	m.set_shader_parameter("asphalt_tex", load("res://materials/asphalt.png"))
	m.set_shader_parameter("sett_tex", load("res://materials/cobblestone.png"))
	m.set_shader_parameter("sett_normal", load("res://materials/cobblestone_normal.png"))
	m.set_shader_parameter("concrete_tex", load("res://materials/concrete.png"))
	return _save_res(m, "road_material") as ShaderMaterial


func _build_roads(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Roads"
	root.add_child(node)
	var kinds: Array = _road_kinds()
	var bounds: Array = []
	for k in kinds:
		bounds.append(float(k[0]))
	var piece := 0
	for sec in kinds:
		var s0: float = sec[0]
		var s1: float = sec[1]
		var kind: int = sec[2]
		if s1 - s0 < 0.5:
			continue
		var w: float = _ribbon_half(kind)
		var lats: Array = [-w, -ROAD_HALF, -ROAD_HALF * 0.5, 0.0, ROAD_HALF * 0.5, ROAD_HALF, w] if w > ROAD_HALF + 0.1 else [-w, -w * 0.5, 0.0, w * 0.5, w]
		var n_steps: int = maxi(1, ceili(s1 - s0))
		var r0 := 0
		while r0 < n_steps:
			var r1: int = mini(r0 + 48, n_steps)
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in range(r0, r1):
				var sa: float = lerpf(s0, s1, float(i) / float(n_steps))
				var sb: float = lerpf(s0, s1, float(i + 1) / float(n_steps))
				for j in range(lats.size() - 1):
					var quad: Array = [[sa, lats[j]], [sa, lats[j + 1]], [sb, lats[j]], [sb, lats[j + 1]]]
					# A (sa, left), B (sa, right), C (sb, left), D (sb, right): (A, C, B), (B, C, D).
					for t in [[0, 2, 1], [1, 2, 3]]:
						for k in t:
							var sv: float = quad[k][0]
							var lv: float = quad[k][1]
							var pos: Vector3 = _pt(sv) + _rt(sv) * lv
							var edge: float = INF
							for bb in bounds:
								edge = minf(edge, absf(sv - float(bb)))
							var fwd: Vector3 = (_pt(sv + 0.5) - _pt(sv - 0.5)).normalized()
							st.set_normal(_rt(sv).cross(fwd).normalized())
							st.set_color(Color(clampf(edge / 4.0, 0.0, 1.0), 0.0, 0.0, 1.0))
							st.set_uv(Vector2(lv, sv))
							st.set_uv2(Vector2(float(kind), ROAD_HALF))
							st.add_vertex(pos)
							_lap_faces.append(pos)
			var mesh: ArrayMesh = st.commit()
			mesh.surface_set_material(0, _road_mat)
			var mi := MeshInstance3D.new()
			mi.name = "Road_%d" % piece
			mi.mesh = _save_res(mesh, "road_%d" % piece, "kronburgroad_")
			node.add_child(mi)
			piece += 1
			r0 = r1
	_build_markt_paving(node)
	print("  roads: %d pieces" % piece)


## The market square's paving: one flat sheet at the square's road height, drawn in world space as the ribbon over it is
## (so where they overlap the two are the same picture).
func _build_markt_paving(node: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 4.0
	var x0: float = MARKT_RECT[0]
	var z0: float = MARKT_RECT[1]
	var nxs: int = ceili((float(MARKT_RECT[2]) - x0) / step)
	var nzs: int = ceili((float(MARKT_RECT[3]) - z0) / step)
	var y: float = _markt_y
	for i in range(nxs):
		for j in range(nzs):
			var xa: float = x0 + float(i) * step
			var xb: float = minf(xa + step, MARKT_RECT[2])
			var za: float = z0 + float(j) * step
			var zb: float = minf(za + step, MARKT_RECT[3])
			var a := Vector3(xa, y, za)
			var b := Vector3(xb, y, za)
			var c := Vector3(xb, y, zb)
			var d := Vector3(xa, y, zb)
			for v in [a, b, c, a, c, d]:
				st.set_normal(Vector3.UP)
				st.set_color(Color(1, 0, 0, 1))
				st.set_uv(Vector2(v.x, v.z))
				st.set_uv2(Vector2(5.0, ROAD_HALF))
				st.add_vertex(v)
				_lap_faces.append(v)
	var mesh: ArrayMesh = st.commit()
	# Front faces clockwise from above: (a, b, c) with x east and z south runs clockwise seen from +y.
	mesh.surface_set_material(0, _road_mat)
	var mi := MeshInstance3D.new()
	mi.name = "MarktplatzPaving"
	mi.mesh = _save_res(mesh, "markt_paving", "kronburgroad_")
	node.add_child(mi)


func _build_lap_body(root: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "LapRoad"
	body.set_meta(&"surface", "asphalt")
	var cs := CollisionShape3D.new()
	var sh := ConcavePolygonShape3D.new()
	sh.backface_collision = true
	sh.set_faces(_lap_faces)
	cs.shape = _save_res(sh, "lap_road_shape")
	body.add_child(cs)
	root.add_child(body)
	print("  lap road body: %d triangles" % (_lap_faces.size() / 3))


func _build_main_curve() -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = 0.5
	var n: int = int(ceil(lap_len / 4.0))
	var step: float = lap_len / float(n)
	var pts: Array = []
	for i in range(n):
		pts.append(_pt(float(i) * step) + Vector3(0, 0.02, 0))
	for i in range(n + 1):
		var k: int = i % n
		var a: Vector3 = pts[(k - 1 + n) % n]
		var c: Vector3 = pts[(k + 1) % n]
		var hnd: Vector3 = (c - a) / 6.0
		curve.add_point(pts[k], -hnd, hnd)
	return curve


# ======================================================================================
#  Places the generator and the dressing agree on
# ======================================================================================

## The rolling mill hall: the lap runs through it eastward along z = HALL_Z from x = HALL_X0.
const HALL_X0 := 110.0
const HALL_Z := 90.0
const HALL_LEN := 240.0
const WORKS_GATE := Vector2(40.0, 188.0)
const TOWN_GATE := Vector2(-236.0, -230.0)


# ======================================================================================
#  Gameplay: the start, the gates, boost pads, the jump
# ======================================================================================

func _place_gameplay(root: Node3D) -> void:
	var gate_scene: PackedScene = load("res://CheckpointGate.tscn")
	var spawn_scene: PackedScene = load("res://SpawnIndicator.tscn")
	var s_fin: float = _closest_s(Vector2(FINISH_X, 250.0))
	var fl: Dictionary = _spot(s_fin, 0.0, 0.05)
	var finish_line = gate_scene.instantiate()
	finish_line.name = "FinishLine"
	finish_line.position = fl["pos"]
	finish_line.rotation_degrees = Vector3(0, fl["yaw"], 0)
	finish_line.set("is_finish_line", true)
	root.add_child(finish_line)
	var spawn_points := Node3D.new()
	spawn_points.name = "SpawnPoints"
	finish_line.add_child(spawn_points)
	var grid := [Vector3(-2.9, 0.05, 5.0), Vector3(2.9, 0.05, 5.0), Vector3(-2.9, 0.05, 12.5), Vector3(2.9, 0.05, 12.5),
		Vector3(-2.9, 0.05, 20.0), Vector3(2.9, 0.05, 20.0)]
	for i in range(grid.size()):
		var sp := Marker3D.new()
		sp.name = "Spawn%d" % (i + 1)
		sp.position = grid[i]
		spawn_points.add_child(sp)
		var si = spawn_scene.instantiate()
		si.name = "SpawnIndicator"
		sp.add_child(si)
	var cps := Node3D.new()
	cps.name = "Checkpoints"
	root.add_child(cps)
	# Gates: the works' approach, before the hall, the north road, the estate, the old town's street, the Kirchberg.
	var at: Array = [
		_closest_s(Vector2(40.0, 140.0)),
		_closest_s(Vector2(520.0, 90.0)),
		_closest_s(Vector2(330.0, -150.0)),
		_closest_s(Vector2(-60.0, -186.0)),
		_closest_s(Vector2(-330.0, -230.0)),
		_closest_s(Vector2(-462.0, -60.0)),
	]
	for i in range(at.size()):
		var c: Dictionary = _spot(at[i], 0.0, 0.08)
		var g = gate_scene.instantiate()
		g.name = "Checkpoint_%d" % (i + 1)
		g.position = c["pos"]
		g.rotation_degrees = Vector3(0, c["yaw"], 0)
		cps.add_child(g)
		print("  checkpoint %d at %.0fm" % [i + 1, at[i]])
	var boost_scene: PackedScene = load("res://BoostPad.tscn")
	var bps := Node3D.new()
	bps.name = "BoostPads"
	root.add_child(bps)
	var pads: Array = [
		["Boost_Kanal", _closest_s(Vector2(-200.0, 250.0)), -2.6],
		["Boost_Hall", _closest_s(Vector2(HALL_X0 + 30.0, HALL_Z)), 2.6],
		["Boost_Jump", _closest_s(Vector2(JUMP_TOE_X + 30.0, -150.0)), 0.0],
		["Boost_Estate", _closest_s(Vector2(-120.0, -210.0)), 2.6],
	]
	for p in pads:
		var b = boost_scene.instantiate()
		b.name = p[0]
		var sp2: Dictionary = _spot(p[1], p[2], 0.08)
		b.position = sp2["pos"]
		b.rotation_degrees = Vector3(0, sp2["yaw"], 0)
		bps.add_child(b)
	_build_jump(root)


## The jump on the north road: a timber kicker as wide as the road, west of the pipe bridges' reach.
const JUMP_TOE_X := 486.0
const JUMP := [22.0, 4.2, 0.5]

func _build_jump(root: Node3D) -> void:
	var toe: float = _closest_s(Vector2(JUMP_TOE_X, -150.0))
	var j: Node3D = (load("res://WoodenRamp.tscn") as PackedScene).instantiate()
	j.name = "SlagJump"
	var sp: Dictionary = _spot(toe, 0.0, 0.0)
	j.position = sp["pos"]
	j.rotation_degrees = Vector3(0, sp["yaw"], 0)
	j.set("length", JUMP[0])
	j.set("height", JUMP[1])
	j.set("curve", JUMP[2])
	j.set("width", ROAD_HALF * 2.0)
	j.set("trestle", true)
	j.set("wood_color", Color(0.50, 0.40, 0.30))
	root.add_child(j)
	var lp: Dictionary = _spot(toe + float(JUMP[0]), 0.0, 0.0)
	var slope: float = float(JUMP[1]) / float(JUMP[0]) * (1.0 + float(JUMP[2]))
	var lip: Vector3 = (lp["pos"] as Vector3) + Vector3(0, float(JUMP[1]), 0)
	(root.get_node("TrackPath") as Node).set_meta(&"jump_lips", [{"name": "SlagJump", "lip": lip, "dir": ((lp["fwd"] as Vector3) + Vector3(0, slope, 0)).normalized()}])


# ======================================================================================
#  Sky and light
# ======================================================================================

const HAZE := Color(0.76, 0.80, 0.84)

func _build_environment(root: Node3D) -> void:
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://sky_tropical_cumulus.gdshader")
	# A summer afternoon over the Ruhr: a mild blue, fair-weather cumulus, a little haze from the works.
	sky_mat.set_shader_parameter("sky_top", Color(0.20, 0.42, 0.78))
	sky_mat.set_shader_parameter("sky_horizon", Color(0.76, 0.83, 0.90))
	sky_mat.set_shader_parameter("ground_horizon", HAZE)
	sky_mat.set_shader_parameter("ground_bottom", Color(0.40, 0.44, 0.40))
	sky_mat.set_shader_parameter("sky_curve", 0.45)
	sky_mat.set_shader_parameter("horizon_haze", HAZE)
	sky_mat.set_shader_parameter("haze_strength", 0.8)
	sky_mat.set_shader_parameter("haze_height", 0.12)
	sky_mat.set_shader_parameter("sun_tint", Color(1.0, 0.96, 0.88))
	sky_mat.set_shader_parameter("sun_disc_degrees", 1.0)
	sky_mat.set_shader_parameter("sun_glow", 0.4)
	sky_mat.set_shader_parameter("sun_horizon_tint", Color(1.0, 0.88, 0.70))
	sky_mat.set_shader_parameter("sun_horizon_glow", 0.08)
	sky_mat.set_shader_parameter("cloud_lit", Color(1.0, 0.99, 0.96))
	sky_mat.set_shader_parameter("cloud_shade", Color(0.58, 0.62, 0.70))
	sky_mat.set_shader_parameter("cloud_coverage", 0.44)
	sky_mat.set_shader_parameter("cloud_opacity", 0.94)
	sky_mat.set_shader_parameter("cloud_scale", 1.1)
	sky_mat.set_shader_parameter("cloud_seed", 17.3)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.45
	env.ambient_light_color = Color(0.90, 0.92, 0.94)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_bloom = 0.04
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = HAZE
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.12
	env.fog_density = 1.0
	env.fog_depth_begin = 300.0
	env.fog_depth_end = 4200.0
	env.fog_depth_curve = 1.6
	env.fog_sky_affect = 0.05
	env.fog_aerial_perspective = 0.3
	env_node.environment = env
	root.add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	# Mid-afternoon: the sun in the south-west, about 45 degrees up.
	sun.rotation_degrees = Vector3(-46.0, -142.0, 0.0)
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 1.45
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
	print("=== Kronburger Hütte (Kronburg GP) Level Generation ===")
	var t_start: int = Time.get_ticks_msec()
	# Every file a run writes is written again: clear the old ones, so props renamed or dropped leave nothing behind.
	var gen := DirAccess.open("res://generated/")
	if gen:
		var cleared := 0
		for f in gen.get_files():
			if f.begins_with("kronburg") and (f.ends_with(".res") or f.ends_with(".tscn")):
				gen.remove(f)
				cleared += 1
		print("  cleared %d old files" % cleared)
	level = Node3D.new()
	level.name = LEVEL_NAME
	level.set_script(load("res://levels/Level.gd"))
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
	_fillet(CORNERS)
	_markt_y = _raw_natural(CORNERS[7][0].x, CORNERS[7][0].y) + GROUND_UNDER
	_castle_y = _raw_natural(CASTLE_C.x, CASTLE_C.y)
	_sport_y = _raw_natural((float(SPORT_RECT[0]) + float(SPORT_RECT[2])) * 0.5, (float(SPORT_RECT[1]) + float(SPORT_RECT[3])) * 0.5)
	print("  market square at %.1fm, castle at %.1fm" % [_markt_y, _castle_y])
	_plan_road_heights()
	var track_path := Path3D.new()
	track_path.name = "TrackPath"
	track_path.curve = _build_main_curve()
	level.add_child(track_path)
	_add_samples()
	_build_heights()
	print("  heights built (%.1fs)" % ((Time.get_ticks_msec() - t_start) / 1000.0))

	var gm := ShaderMaterial.new()
	gm.shader = load("res://kronburg_ground.gdshader")
	gm.set_shader_parameter("grass_tex", load("res://materials/grass.png"))
	gm.set_shader_parameter("dirt_tex", load("res://materials/dirt.png"))
	gm.set_shader_parameter("dirt_normal", load("res://materials/dirt_normal.png"))
	gm.set_shader_parameter("rock_tex", load("res://materials/dark_rock.png"))
	gm.set_shader_parameter("gravel_tex", load("res://materials/dark_canyon_rock.png"))
	gm.set_shader_parameter("gravel_normal", load("res://materials/dark_canyon_rock_normal.png"))
	gm.set_shader_parameter("concrete_tex", load("res://materials/concrete.png"))
	gm.set_shader_parameter("water_y", WATER_Y)
	_ground_mat = _save_res(gm, "ground_material") as ShaderMaterial
	_road_mat = _road_material()
	var terrain := Node3D.new()
	terrain.name = "KronburgTerrain"
	level.add_child(terrain)
	_build_terrain(terrain)
	print("  terrain built (%.1fs)" % ((Time.get_ticks_msec() - t_start) / 1000.0))
	_build_canal(terrain)
	_build_roads(level)
	_build_lap_body(level)
	_build_environment(level)
	_place_gameplay(level)
	_build_dressing(level)

	level.set("track_path", track_path)
	level._setup_checkpoints()
	var chunked: int = MeshChunker.chunk_scene(level, "res://generated/" + RES_PREFIX, "res://generated/kronburg_chunks", MESH_CHUNK_CELL)
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
#  Dressing (the town, the works, the woods)
# ======================================================================================

func _build_dressing(root: Node3D) -> void:
	_town = load("res://KronburgTownKit.gd")
	_works = load("res://SteelworksKit.gd")
	_build_start(root)
	_build_town(root)
	_build_works(root)
	_build_autobahn()
	_build_traffic_signs()
	_build_leisure()
	_build_town_people()
	_build_weekly_market(root)
	CrowdPlacer.build(root, _people, SPECTATOR_SCALE, SPECTATOR_SKIN, 8121, func(res: Resource, n: String) -> Resource: return _save_res(res, n, "kronburgcrowd_"))
	_flush_batches(root)
	_build_sounds(root)
	_build_works_fx(root)
	_build_delineators(root)
	_build_woods(root)


# ======================================================================================
#  Prop batches: many props built into one kit (a mesh with a surface per material), saved under PROP_PREFIX
# ======================================================================================

var _town: Script
var _works: Script
var _batches := {}
var _saved_mats := {}

## Builds one prop into the batch `key`: `xf` places it rigidly (the kit's life-size frame is grown by PROP_SCALE about its
## origin), `build` is called as build(pk, kit, labels). Labels come back in the kit's life-size coordinates.
func _add_prop(key: String, kit_script: Script, xf: Transform3D, build: Callable, range_end := 0.0) -> void:
	if not _batches.has(key):
		_batches[key] = {"pk": kit_script.new_kit(PROP_SCALE), "kit": {}, "labels": [], "range": range_end, "script": kit_script}
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


## Calls a kit's builder if the kit has it (and says so once if it doesn't), so the level builds while a kit grows.
var _missing := {}

func _kit_call(script: Script, fn: String, args: Array) -> void:
	var has := false
	for m in script.get_script_method_list():
		if m["name"] == fn:
			has = true
			break
	if not has:
		if not _missing.has(fn):
			_missing[fn] = true
			push_warning("Kronburg: %s has no %s() yet" % [script.resource_path.get_file(), fn])
		return
	script.callv(fn, args)


func _cell_key(prefix: String, p: Vector3, cell := 140.0) -> String:
	return "%s_%d_%d" % [prefix, floori(p.x / cell), floori(p.z / cell)]


func _flush_batches(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Kronburg"
	root.add_child(node)
	var tris := 0
	var keys: Array = _batches.keys()
	keys.sort()
	for key in keys:
		var b: Dictionary = _batches[key]
		var pk: PropKit = b["pk"]
		pk.reset_frame()
		var mesh: ArrayMesh = (b["script"] as Script).commit(pk, b["kit"])
		for si in range(mesh.get_surface_count()):
			var m: Material = mesh.surface_get_material(si)
			if m == null:
				continue
			if m.resource_path.is_empty():
				var id: int = m.get_instance_id()
				if not _saved_mats.has(id):
					_saved_mats[id] = _save_res(m, "mat_%d" % _saved_mats.size(), PROP_PREFIX)
				mesh.surface_set_material(si, _saved_mats[id])
		tris += MeshChunker.triangle_count(mesh)
		var mi := MeshInstance3D.new()
		mi.name = String(key).to_pascal_case()
		mi.mesh = _save_res(mesh, key, PROP_PREFIX)
		if float(b["range"]) > 0.0:
			mi.visibility_range_end = float(b["range"])
			mi.visibility_range_end_margin = float(b["range"]) * 0.08
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


func _fit_pixel(text: String, font_size: int, pixel: float, max_w: float) -> float:
	if max_w <= 0.0:
		return pixel
	var w: float = ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if w * pixel <= max_w:
		return pixel
	return max_w / maxf(w, 1.0)


## A frame facing `face` (its +z) standing upright at `at`.
func _facing(face: Vector3, at: Vector3) -> Transform3D:
	var z := Vector3(face.x, 0.0, face.z).normalized()
	var x := Vector3.UP.cross(z).normalized()
	return Transform3D(Basis(x, Vector3.UP, z), at)


## Whether a footprint (w x d in plan, centred at c, its x axis `ax`) is clear of everything noted so far.
func _clear(c: Vector3, ax: Vector3, w: float, d: float) -> bool:
	var az := Vector3(-ax.z, 0.0, ax.x)
	for i in range(-2, 3):
		for j in range(-2, 3):
			var p: Vector3 = c + ax * (float(i) / 2.0) * (w * 0.5 - 1.0) + az * (float(j) / 2.0) * (d * 0.5 - 1.0)
			if _occupied(p.x, p.z):
				return false
	return true


func _note_xf(xf: Transform3D, x0: float, x1: float, z0: float, z1: float, margin := 0.5) -> void:
	# A rectangle in the prop's frame (game metres, x0..x1 along its x, z0..z1 along its z).
	var c: Vector3 = xf * Vector3((x0 + x1) * 0.5, 0.0, (z0 + z1) * 0.5)
	var ax: Vector3 = xf.basis.x.normalized()
	_note_rect(Vector2(c.x, c.z), absf(x1 - x0), absf(z1 - z0), atan2(-ax.z, ax.x), margin)


# ======================================================================================
#  The start: crowd barriers and spectators along the Kanalstraße either side of the line
# ======================================================================================

const CrowdPlacer = preload("res://CrowdPlacer.gd")
const CampKit = preload("res://CampKit.gd")
const SPECTATOR_SCALE := PROP_SCALE / 1.86
## A Ruhr crowd: mostly European, Turkish and Arab families, a few others ([African, South Asian, European, East Asian,
## Arab or mixed]).
const SPECTATOR_SKIN := [0.05, 0.04, 0.72, 0.03, 0.16]
const START_BEFORE := 150.0
const START_AFTER := 90.0
const BARRIER_LAT := ROAD_HALF + 3.6
var _people: Array = []
var _camp_mats := {}

func _camp_material(key: String) -> Material:
	if not _camp_mats.has(key):
		_camp_mats[key] = _save_res(CampKit.make_material(key), "camp_mat_" + key, "kronburgprop_")
	return _camp_mats[key]


func _build_start(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "StartVenue"
	root.add_child(node)
	var pk := PropKit.new()
	pk.material_for = func(key: String) -> Material: return _camp_material(key)
	var camp := CampKit.new(pk)
	var bkit := {}
	var body := StaticBody3D.new()
	body.name = "StartBarriersBody"
	node.add_child(body)
	var s_fin: float = _closest_s(Vector2(FINISH_X, 250.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5511
	var step: float = 2.3 * PROP_SCALE
	var s: float = s_fin - START_BEFORE
	var count := 0
	while s < s_fin + START_AFTER:
		for side in [-1.0, 1.0]:
			if absf(s - s_fin) < 9.0:
				continue  # the gantry's feet
			var sp: Dictionary = _spot(s, side * BARRIER_LAT, 0.0)
			var pos: Vector3 = sp["pos"]
			pos.y = _ground_at(pos.x, pos.z)
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
			_note_rect(Vector2(pos.x, pos.z), step, 1.0, atan2(fwd.x, fwd.z))
			count += 1
			# One or two loose rows behind it, facing the road.
			for row in range(2):
				if rng.randf() < (0.25 if row == 0 else 0.6):
					continue
				var lat: float = side * (BARRIER_LAT + 1.6 + float(row) * 1.5 + rng.randf_range(0.0, 0.7))
				var ps: Dictionary = _spot(s + rng.randf_range(-1.2, 1.2), lat, 0.0)
				var pp: Vector3 = ps["pos"]
				pp.y = _ground_at(pp.x, pp.z)
				var face: Vector3 = -(ps["right"] as Vector3) * side
				face = (face + (ps["fwd"] as Vector3) * rng.randf_range(-0.5, 0.5)).normalized()
				_people.append([pp, face, false, false, -1, rng.randf_range(0.9, 1.08)])
		s += step
	pk.reset_frame()
	var bmi := MeshInstance3D.new()
	bmi.name = "Barriers"
	bmi.mesh = _save_res(pk.commit(bkit), "start_barriers", PROP_PREFIX)
	bmi.visibility_range_end = 700.0
	node.add_child(bmi)
	print("  start: %d barriers, %d spectators" % [count, _people.size()])


# ======================================================================================
#  Leitpfosten: the white delineator posts with a black band along German country roads (knockable)
# ======================================================================================

func _post_mesh() -> ArrayMesh:
	var pk := PropKit.new()
	pk.material_for = func(key: String) -> Material: return _camp_material(key)
	var kit := {}
	var s := PROP_SCALE
	var white := Color(0.92, 0.92, 0.90)
	var black := Color(0.06, 0.06, 0.06)
	# A post 1m tall (life), its face toward -z (the road), its back rounded off as two bevels.
	var prof := PackedVector2Array([Vector2(-0.06, 0.0), Vector2(0.06, 0.0), Vector2(0.06, 0.06), Vector2(0.0, 0.11), Vector2(-0.06, 0.06)])
	pk.set_frame(Transform3D(Basis(Vector3.RIGHT, Vector3.BACK, Vector3.DOWN) * Basis.from_scale(Vector3.ONE * s), Vector3.ZERO))
	pk.extrude(kit, "paint", prof, -1.0, -0.73, 0.0, white)
	pk.extrude(kit, "paint", prof, -0.73, -0.98, 0.0, black)
	pk.extrude(kit, "paint", prof, -0.98, -1.0, 0.0, white)
	pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3.ZERO))
	# The reflector on the black band, facing the oncoming traffic.
	pk.block(kit, "lamp", Vector3(-0.025, 0.80, -0.012), Vector3(0.025, 0.90, -0.002), Color(0.95, 0.95, 0.9))
	return pk.commit(kit)


func _build_delineators(root: Node3D) -> void:
	var kinds: Array = _road_kinds()
	var s_fin: float = _closest_s(Vector2(FINISH_X, 250.0))
	var xfs: Array[Transform3D] = []
	var s := 10.0
	while s < lap_len:
		if _kind_at(kinds, s) == 0 and absf(_at(s)["k"]) < 0.03 and not (s > s_fin - START_BEFORE - 10.0 and s < s_fin + START_AFTER + 10.0):
			for side in [-1.0, 1.0]:
				var sp: Dictionary = _spot(s, side * (ROAD_HALF + 1.1), 0.0)
				var pos: Vector3 = sp["pos"]
				pos.y = _ground_at(pos.x, pos.z)
				var face: Vector3 = (sp["right"] as Vector3) * side
				xfs.append(Transform3D(Basis.looking_at(face, Vector3.UP), pos))
		s += 50.0
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _save_res(_post_mesh(), "delineator_post", PROP_PREFIX)
	mm.instance_count = xfs.size()
	mm.buffer = PropKit.transform_buffer(xfs)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Leitpfosten"
	mmi.multimesh = mm
	mmi.set_script(load("res://KnockablePoles.gd"))
	mmi.set("pole_transforms", xfs)
	mmi.set("pole_height", 1.6)
	mmi.set("pole_mass", 3.0)
	mmi.visibility_range_end = 450.0
	root.add_child(mmi)
	print("  Leitpfosten: %d" % xfs.size())


## The distance in plan from (x, z) to the lap's centreline (from the grading's samples).
func _lap_dist(x: float, z: float) -> float:
	var cx: int = floori(x / CELL)
	var cz: int = floori(z / CELL)
	var best := 1e9
	var n: int = _rs_pos.size()
	for gz in range(cz - 2, cz + 3):
		for gx in range(cx - 2, cx + 3):
			var bucket: PackedInt32Array = _rs_cells.get(Vector2i(gx, gz), PackedInt32Array())
			for i in bucket:
				var a: Vector3 = _rs_pos[i]
				var b: Vector3 = _rs_pos[(i + 1) % n]
				var sx: float = b.x - a.x
				var sz: float = b.z - a.z
				var l2: float = maxf(sx * sx + sz * sz, 1e-6)
				var t: float = clampf(((x - a.x) * sx + (z - a.z) * sz) / l2, 0.0, 1.0)
				var fx: float = x - (a.x + sx * t)
				var fz: float = z - (a.z + sz * t)
				best = minf(best, fx * fx + fz * fz)
	return sqrt(best) if best < 1e8 else 1e9


## The 4m cells something stands on, so the woods and props keep apart.
var _occ := {}

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


func _occupied(x: float, z: float) -> bool:
	return _occ.has(Vector2i(floori(x / 4.0), floori(z / 4.0)))


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


# ======================================================================================
#  The woods: WoodlandBuilder's oak, lime, birch and spruce (Harbor Pier's way: near cells, shadow stand-ins, far cells)
# ======================================================================================

const TREE_KINDS := ["oak", "lime", "birch", "spruce"]
const TREE_CELL := 260.0
const TREE_FAR_RANGE := 1800.0

func _build_woods(root: Node3D) -> void:
	var t0 := Time.get_ticks_msec()
	var node := Node3D.new()
	node.name = "Woodland"
	root.add_child(node)
	var w = load("res://WoodlandBuilder.gd").new()
	w.save_res = func(res: Resource, n: String) -> Resource: return _save_res(res, n, "kronburgtree_")
	var leaf_near: ShaderMaterial = _save_res(w.leaf_material(1, 0.14, 18.0), "leaf_near", "kronburgtree_")
	var leaf_far: ShaderMaterial = _save_res(w.leaf_material(2, 0.14, 18.0), "leaf_far", "kronburgtree_")
	var lod_mats: Array[ShaderMaterial] = [leaf_near, leaf_far]
	var near_meshes: Array = []
	var far_meshes: Array = []
	for kind in TREE_KINDS:
		var bn: ShaderMaterial = _save_res(w.bark_material(kind, 1), "bark_%s_near" % kind, "kronburgtree_")
		var bf: ShaderMaterial = _save_res(w.bark_material(kind, 2), "bark_%s_far" % kind, "kronburgtree_")
		lod_mats.append(bn)
		lod_mats.append(bf)
		var nm: ArrayMesh
		var fm: ArrayMesh
		if kind == "spruce":
			nm = w.spruce_mesh(0, 0, bn, leaf_near)
			fm = w.spruce_mesh(0, 1, bf, leaf_far)
		else:
			nm = w.broadleaf_mesh(kind, 0, 0, bn, leaf_near)
			fm = w.broadleaf_mesh(kind, 0, 1, bf, leaf_far)
		near_meshes.append(_save_res(nm, "tree_%s" % kind, "kronburgtree_"))
		far_meshes.append(_save_res(fm, "tree_%s_far" % kind, "kronburgtree_"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7741
	var kind_noise := FastNoiseLite.new()
	kind_noise.seed = 7742
	kind_noise.frequency = 0.007
	kind_noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	var cells := {}
	var counts := {"oak": 0, "lime": 0, "birch": 0, "spruce": 0}
	var add := func(kind: String, px: float, pz: float, sc: float) -> void:
		var g: float = _ground_at(px, pz)
		var lean := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.04))
		var xf := Transform3D(lean * Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.92, 1.1), sc)),
				Vector3(px, g - 0.3, pz))
		var mi: int = TREE_KINDS.find(kind)
		var key := Vector3i(floori(px / TREE_CELL), floori(pz / TREE_CELL), mi)
		if not cells.has(key):
			cells[key] = []
		cells[key].append(xf)
		counts[kind] += 1
	# The woods, by the ground's woodland mask.
	var step := 12.0
	var x: float = FINE_X.x + 50.0
	while x < FINE_X.y - 50.0:
		var z: float = FINE_Z.x + 30.0
		while z < FINE_Z.y - 30.0:
			var px: float = x + rng.randf_range(-0.45, 0.45) * step
			var pz: float = z + rng.randf_range(-0.45, 0.45) * step
			var roll: float = rng.randf()
			z += step
			var fw: float = _forest_w(px, pz) * _open_land(px, pz)
			var dh: float = Vector2(px, pz).distance_to(HALDE_C)
			var heap: float = (1.0 - smoothstep(HALDE_R0 - 10.0, HALDE_R0 + 25.0, dh)) * smoothstep(HALDE_R1 + 25.0, HALDE_R1 + 60.0, dh)
			var dens: float = maxf(fw, heap * 0.6)
			# A few lone trees and copses out in the fields.
			dens = maxf(dens, 0.025)
			if roll > dens:
				continue
			if _occupied(px, pz) or absf(pz - CANAL_Z) < CANAL_HALF + 6.0 or _in_rect(px, pz, HARBOUR_RECT, 8.0):
				continue
			if _in_rect(px, pz, WORKS_RECT, -4.0) or _in_rect(px, pz, TOWN_RECT) or _in_rect(px, pz, ESTATE_RECT):
				continue
			if _lap_dist(px, pz) < 19.0:
				continue
			var g: float = _ground_at(px, pz)
			var slope: float = Vector2(_ground_at(px + 3.0, pz) - g, _ground_at(px, pz + 3.0) - g).length() / 3.0
			if slope > 0.75:
				continue
			var kn: float = kind_noise.get_noise_2d(px, pz)
			var kind := "oak"
			if heap > 0.3:
				kind = "birch" if rng.randf() < 0.75 else "oak"
			elif kn > 0.45 and g > 15.0:
				kind = "spruce"
			elif kn < -0.2:
				kind = "lime"
			elif rng.randf() < 0.18:
				kind = "birch"
			add.call(kind, px, pz, rng.randf_range(1.0, 1.35))
		x += step
	# Garden trees in the town and the estate: small limes, birches and oaks in the yards behind the houses.
	var gx: float = float(TOWN_RECT[0])
	while gx < float(ESTATE_RECT[2]):
		var gz: float = float(TOWN_RECT[1])
		while gz < float(TOWN_RECT[3]):
			var px3: float = gx + rng.randf_range(-3.0, 3.0)
			var pz3: float = gz + rng.randf_range(-3.0, 3.0)
			gz += 9.0
			if not (_in_rect(px3, pz3, TOWN_RECT) or _in_rect(px3, pz3, ESTATE_RECT)):
				continue
			if rng.randf() > 0.22 or _occupied(px3, pz3) or _in_rect(px3, pz3, MARKT_RECT, 6.0) or _lap_dist(px3, pz3) < 14.0:
				continue
			var roll2: float = rng.randf()
			add.call("birch" if roll2 < 0.3 else ("oak" if roll2 < 0.5 else "lime"), px3, pz3, rng.randf_range(0.55, 0.85))
		gx += 9.0
	# Lime trees on the market square, clear of the racing line.
	for lt in [Vector2(-508.0, -298.5), Vector2(-472.0, -298.5), Vector2(-500.0, -223.0), Vector2(-526.0, -223.0)]:
		var lp: Vector2 = lt
		add.call("lime", lp.x, lp.y, 1.15)
		_note_rect(lp, 6.0, 6.0, 0.0, 0.0)
	# Street trees: limes along the canal's promenade and on the far bank, birches round the works' edge.
	for k in range(0, 60):
		var xs: float = -1150.0 + float(k) * 36.0
		for zz in [CANAL_Z - CANAL_HALF - 9.5, CANAL_Z + CANAL_HALF + 7.0]:
			var px2: float = xs + rng.randf_range(-2.0, 2.0)
			if _in_rect(px2, zz, HARBOUR_RECT, 30.0) or _occupied(px2, zz) or _lap_dist(px2, zz) < 15.0:
				continue
			add.call("lime", px2, zz, rng.randf_range(1.05, 1.25))
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
#  The town: the Altstadt's streets and market square, the gate, the castle, the colliery estate
# ======================================================================================

## A house's front stands on the pavement's outer edge.
const FRONT_LAT := ROAD_HALF + PAVEMENT + 0.15
const HOUSE_DEPTH := 11.0
var _house_count := 0

## Gable houses along one side (`side` +1 right of travel, -1 left) of the lap from s0 to s1, fronts on the pavement.
func _frontage(s0: float, s1: float, side: float, rng: RandomNumberGenerator) -> void:
	var s: float = s0
	while s < s1:
		var w_life: float = rng.randf_range(6.6, 9.8)
		var w: float = w_life * PROP_SCALE
		if s + w > s1:
			break
		var sc: float = s + w * 0.5
		var sp: Dictionary = _spot(sc, side * FRONT_LAT, 0.0)
		var face: Vector3 = -(sp["right"] as Vector3) * side
		var front: Vector3 = sp["pos"]
		var xf: Transform3D = _facing(face, front)
		xf.origin -= xf.basis.x * (w * 0.5)
		var d: float = HOUSE_DEPTH * PROP_SCALE
		var centre: Vector3 = front - face * (d * 0.5)
		if not _clear(centre, xf.basis.x, w, d):
			s += 3.0
			continue
		var floors: int = 2 + int(rng.randf() < 0.75) + int(rng.randf() < 0.3)
		var variant: int = rng.randi_range(0, 9)
		var wl := w_life
		var seed_v: int = rng.randi()
		_add_prop(_cell_key("town", front), _town, xf, func(pk, kit, labels):
			var hr := RandomNumberGenerator.new()
			hr.seed = seed_v
			_kit_call(_town, "fachwerk_house", [pk, kit, wl, HOUSE_DEPTH, floors, variant, hr, labels]))
		_note_xf(xf, 0.0, w, -d, 0.0, 0.2)
		_house_count += 1
		# The narrow gap (Traufgasse) between gable houses.
		s += w + rng.randf_range(0.5, 1.6)


## A row of gable houses along a straight line from `a` (local x = 0 of the first) toward `b`, facing `face`.
func _row(a: Vector3, b: Vector3, face: Vector3, rng: RandomNumberGenerator) -> void:
	var dir: Vector3 = (b - a)
	var total: float = dir.length()
	dir /= total
	var x := 0.0
	while x < total:
		var w_life: float = rng.randf_range(6.6, 9.4)
		var w: float = w_life * PROP_SCALE
		if x + w > total:
			break
		var at: Vector3 = a + dir * x
		var mid: Vector3 = at + dir * (w * 0.5)
		at.y = maxf(_ground_at(mid.x, mid.z) + 0.04, a.y) if a.y > -1000.0 else _ground_at(mid.x, mid.z) + 0.04
		var xf := Transform3D(Basis(dir, Vector3.UP, face), at)
		if xf.basis.determinant() < 0.0:
			xf = Transform3D(Basis(-dir, Vector3.UP, face), at + dir * w)
		var d: float = HOUSE_DEPTH * PROP_SCALE
		var centre: Vector3 = a + dir * (x + w * 0.5) - face * (d * 0.5)
		if not _clear(centre, dir, w, d):
			x += 3.0
			continue
		var floors: int = 3 + int(rng.randf() < 0.4)
		var variant: int = rng.randi_range(0, 9)
		var wl := w_life
		var seed_v: int = rng.randi()
		_add_prop(_cell_key("town", at), _town, xf, func(pk, kit, labels):
			var hr := RandomNumberGenerator.new()
			hr.seed = seed_v
			_kit_call(_town, "fachwerk_house", [pk, kit, wl, HOUSE_DEPTH, floors, variant, hr, labels]))
		_note_xf(xf, 0.0, w, -d, 0.0, 0.2)
		_house_count += 1
		x += w + rng.randf_range(0.4, 1.4)


func _build_town(_root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6620
	var s7: float = _corner_s(7)
	var s_tg: float = _closest_s(TOWN_GATE)
	var s_kirch: float = _closest_s(Vector2(-452.0, -95.0))
	var y: float = _markt_y
	# The market square first (its landmarks take their places before the streets fill in).
	# St. Lamberti on the north side: its west tower facing west, the nave running east along the square.
	var church_xf := _facing(Vector3(-1, 0, 0), Vector3(-536.0, y, -322.0))
	_add_prop("markt_church", _town, church_xf, func(pk, kit, labels): _kit_call(_town, "church", [pk, kit, labels]))
	_note_rect(Vector2(-490.0, -322.0), 96.0, 30.0, 0.0, 1.0)
	# The Rathaus on the west side, facing east over the square.
	var rat_w: float = 22.0 * PROP_SCALE
	var rat_xf := _facing(Vector3(1, 0, 0), Vector3(-539.5, y, -262.0 + rat_w * 0.5))
	_add_prop("markt_rathaus", _town, rat_xf, func(pk, kit, labels): _kit_call(_town, "rathaus", [pk, kit, labels]))
	_note_xf(rat_xf, 0.0, rat_w, -16.0 * PROP_SCALE, 0.0, 0.5)
	# The fountain.
	var fx := _facing(Vector3(1, 0, 0), Vector3(-498.0, y, -268.0))
	_add_prop("markt_fountain", _town, fx, func(pk, kit, _labels): _kit_call(_town, "market_fountain", [pk, kit]))
	_note_rect(Vector2(-498.0, -268.0), 14.0, 14.0, 0.0)
	# The maypole on the square's north side, between the lime trees in front of the church.
	_add_prop("markt_maibaum", _town, _facing(Vector3(0, 0, 1), Vector3(-490.0, y, -292.0)), func(pk, kit, _labels): _kit_call(_town, "maibaum", [pk, kit]))
	_note_rect(Vector2(-490.0, -292.0), 5.0, 5.0, 0.0)
	# The square's east side (facing west) and its south-west side (facing north).
	_row(Vector3(-441.0, y, -305.0), Vector3(-441.0, y, -243.0), Vector3(-1, 0, 0), rng)
	_row(Vector3(-461.5, y, -217.0), Vector3(-536.0, y, -217.0), Vector3(0, 0, -1), rng)
	# The square's west side either side of the Rathaus, facing east.
	_row(Vector3(-541.5, y, -282.5), Vector3(-541.5, y, -308.0), Vector3(1, 0, 0), rng)
	_row(Vector3(-541.5, y, -213.0), Vector3(-541.5, y, -242.5), Vector3(1, 0, 0), rng)
	# The town gate on the Hauptstraße, then the street to the square, then the Kirchberg down to the edge of town.
	var gs: Dictionary = _spot(s_tg, 0.0, 0.0)
	# Its field side (+z) faces out of town, back along the lap toward the estate.
	var gate_xf := _facing(-(gs["fwd"] as Vector3), gs["pos"])
	_add_prop("kronentor", _town, gate_xf, func(pk, kit, labels): _kit_call(_town, "town_gate", [pk, kit, labels]))
	_note_xf(gate_xf, -22.0 * PROP_SCALE, 22.0 * PROP_SCALE, -8.0 * PROP_SCALE, 8.0 * PROP_SCALE, 0.5)
	_frontage(s_tg + 16.0, s7 - 26.0, 1.0, rng)
	_frontage(s_tg + 16.0, s7 - 40.0, -1.0, rng)
	_frontage(s7 + 24.0, s_kirch, 1.0, rng)
	_frontage(s7 + 40.0, s_kirch, -1.0, rng)
	_build_lanes(rng)
	_build_town_wall()
	print("  old town: %d houses" % _house_count)
	# Burg Kronburg on its hill.
	var cy: float = _ground_range(CASTLE_C, 40.0, 40.0, 0.0).x
	_add_prop("castle", _town, _facing(Vector3(0.3, 0, 1), Vector3(CASTLE_C.x, cy, CASTLE_C.y)), func(pk, kit, _labels): _kit_call(_town, "castle_ruin", [pk, kit]))
	_note_rect(CASTLE_C, 70.0, 70.0, 0.0)
	_build_estate(rng)
	_build_street_furniture(rng)


## The colliery estate (Zechensiedlung) along the climb from the works to the town gate: brick terraces in their front
## gardens either side, a Trinkhalle on the corner.
func _build_estate(rng: RandomNumberGenerator) -> void:
	var s_out: float = _closest_s(Vector2(-5.0, -164.0))
	var s_tg: float = _closest_s(TOWN_GATE)
	var n := 0
	var kiosk_done := false
	for side in [1.0, -1.0]:
		var s: float = s_out + 18.0
		while s < s_tg - 30.0:
			var units: int = 4 if rng.randf() < 0.55 else 2
			var w: float = float(units) * 7.0 * PROP_SCALE
			if s + w > s_tg - 30.0:
				units = 2
				w = 14.0 * PROP_SCALE
				if s + w > s_tg - 30.0:
					break
			var sc: float = s + w * 0.5
			var sp: Dictionary = _spot(sc, side * FRONT_LAT, 0.0)
			var face: Vector3 = -(sp["right"] as Vector3) * side
			var xf: Transform3D = _facing(face, sp["pos"])
			if not kiosk_done and side < 0.0 and sc > s_out + 160.0:
				# The Trinkhalle on the street corner, with room round it.
				var kx: Transform3D = _facing(face, (sp["pos"] as Vector3) - face * 2.5)
				_add_prop(_cell_key("estate", kx.origin), _town, kx, func(pk, kit, labels): _kit_call(_town, "trinkhalle", [pk, kit, labels]))
				_note_xf(kx, -4.0 * PROP_SCALE, 4.0 * PROP_SCALE, -4.0 * PROP_SCALE, 1.0, 0.5)
				kiosk_done = true
				s += 16.0
				continue
			xf.origin -= xf.basis.x * (w * 0.5)
			var d: float = 22.0 * PROP_SCALE
			if not _clear((sp["pos"] as Vector3) - face * (d * 0.5), xf.basis.x, w, d):
				s += 4.0
				continue
			var variant: int = rng.randi_range(0, 7)
			var seed_v: int = rng.randi()
			var u := units
			_add_prop(_cell_key("estate", sp["pos"]), _town, xf, func(pk, kit, _labels):
				var hr := RandomNumberGenerator.new()
				hr.seed = seed_v
				_kit_call(_town, "brick_terrace", [pk, kit, u, variant, hr]))
			_note_xf(xf, 0.0, w, -d, 0.0, 0.3)
			n += 1
			s += w + rng.randf_range(9.0, 14.0)
	n += _estate_streets(rng)
	print("  colliery estate: %d terraces" % n)


## Lamps, the place-name signs, a Litfaßsäule and a bus stop.
func _build_street_furniture(rng: RandomNumberGenerator) -> void:
	var kinds: Array = _road_kinds()
	var s := 5.0
	var placed := 0
	while s < lap_len:
		var kind: int = _kind_at(kinds, s)
		var k: float = absf(_at(s)["k"])
		var step := 38.0
		if kind == 0 and k < 0.02:
			# Whip-arm street lamps along the Kanalstraße's north verge and the Kirchberg's lower end.
			var side := -1.0
			var sp: Dictionary = _spot(s, side * (ROAD_HALF + 1.7), 0.0)
			var p: Vector3 = sp["pos"]
			if not _occupied(p.x, p.z):
				p.y = _ground_at(p.x, p.z)
				var xf := _facing(-(sp["right"] as Vector3) * side, p)
				_add_prop(_cell_key("lamps", p, 300.0), _town, xf, func(pk, kit, _labels): _kit_call(_town, "peitschen_lamp", [pk, kit]), 500.0)
				placed += 1
		elif kind == 2 and k < 0.02:
			step = 34.0
			for side in [-1.0, 1.0]:
				var sp2: Dictionary = _spot(s + (17.0 if side > 0.0 else 0.0), side * (ROAD_HALF + 0.75), 0.0)
				var p2: Vector3 = sp2["pos"]
				var xf2 := _facing(-(sp2["right"] as Vector3) * side, p2)
				_add_prop(_cell_key("lamps", p2, 300.0), _town, xf2, func(pk, kit, _labels): _kit_call(_town, "peitschen_lamp", [pk, kit]), 500.0)
				placed += 1
		elif kind == 1:
			step = 26.0
			for side in [-1.0, 1.0]:
				var sp3: Dictionary = _spot(s + (13.0 if side > 0.0 else 0.0), side * (ROAD_HALF + PAVEMENT - 0.55), 0.0)
				var p3: Vector3 = sp3["pos"]
				var xf3 := _facing(-(sp3["right"] as Vector3) * side, p3)
				_add_prop(_cell_key("lamps", p3, 300.0), _town, xf3, func(pk, kit, _labels): _kit_call(_town, "old_lantern_post", [pk, kit]), 450.0)
				placed += 1
		s += step
	# The place-name signs where the lap enters Kronburg: on the estate road out of the works, and on the Kanalstraße.
	for at in [[Vector2(10.0, -172.0), "Kronburg", "Kreis Ruhr-Ost"], [Vector2(-90.0, 250.0), "Kronburg", "Ortsteil Hafen"]]:
		var ss: float = _closest_s(at[0])
		var sp4: Dictionary = _spot(ss, ROAD_HALF + 2.4, 0.0)
		var p4: Vector3 = sp4["pos"]
		p4.y = _ground_at(p4.x, p4.z)
		var txt: String = at[1]
		var sub: String = at[2]
		_add_prop(_cell_key("signs", p4, 300.0), _town, _facing(-(sp4["fwd"] as Vector3), p4), func(pk, kit, labels): _kit_call(_town, "ortsschild", [pk, kit, labels, txt, sub]), 400.0)
	# A Litfaßsäule on the square, a bus stop on the Kanalstraße by the start.
	var lp := Vector3(-468.0, _markt_y, -292.0)
	_add_prop("markt_litfass", _town, _facing(Vector3(0, 0, 1), lp), func(pk, kit, _labels): _kit_call(_town, "litfass", [pk, kit]), 400.0)
	var sb: Dictionary = _spot(_closest_s(Vector2(-300.0, 250.0)), -(ROAD_HALF + 3.0), 0.0)
	var pb: Vector3 = sb["pos"]
	pb.y = _ground_at(pb.x, pb.z)
	_add_prop(_cell_key("signs", pb, 300.0), _town, _facing(sb["right"], pb), func(pk, kit, labels): _kit_call(_town, "bus_stop", [pk, kit, labels]), 400.0)
	print("  street lamps: %d" % placed)


# ======================================================================================
#  The works: the rolling mill hall over the lap, the blast furnace and its stoves, the gas holder, the stacks, the
#  pipe bridges over the north road, the works gate, the harbour, the slag heap's crown, the old colliery's headframe
# ======================================================================================

## Life metres: the hall's length (240m in game).
const HALL_LIFE := 150.0
const FURNACE_AT := Vector2(450.0, -76.0)
const COWPERS_AT := Vector2(298.0, -52.0)
const GASOMETER_AT := Vector2(286.0, -262.0)
const COOLING_AT := Vector2(476.0, -296.0)
const HEADFRAME_AT := Vector2(-48.0, -352.0)
## Chimneys: [x, z, height (life), style].
const STACKS := [[330.0, -214.0, 70.0, 0], [536.0, -238.0, 90.0, 1], [176.0, -228.0, 60.0, 0]]
## Pipe bridges over the north road (x) and over the works' approach (z on the C1 leg).
const PIPE_BRIDGES_X := [540.0, 246.0]
const TORPEDO_TRACK_Z := 71.0
## The cooling tower's rim over the ground (game metres), for its steam.
const COOLING_TOP := 80.0
var _hall_xf := Transform3D()

func _works_xf(at: Vector2, face: Vector3) -> Transform3D:
	return _facing(face, Vector3(at.x, _ground_at(at.x, at.y), at.y))


func _build_works(_root: Node3D) -> void:
	var y: float = WORKS_Y
	# The rolling mill hall, the lap through it eastward: its frame's -z along the lap.
	var hs: Dictionary = _spot(_closest_s(Vector2(HALL_X0, HALL_Z)), 0.0, 0.0)
	_hall_xf = _facing(-(hs["fwd"] as Vector3), Vector3(HALL_X0, _lap_y(_closest_s(Vector2(HALL_X0, HALL_Z))), HALL_Z))
	_add_prop("works_hall", _works, _hall_xf, func(pk, kit, labels): _kit_call(_works, "rolling_hall", [pk, kit, HALL_LIFE, labels]))
	_note_rect(Vector2(HALL_X0 + HALL_LEN * 0.5, HALL_Z), HALL_LEN + 4.0, 56.0, 0.0)
	# The blast furnace and its hot-blast stoves.
	_add_prop("works_furnace", _works, _works_xf(FURNACE_AT, Vector3(0, 0, 1)), func(pk, kit, labels): _kit_call(_works, "blast_furnace", [pk, kit, labels]))
	_note_rect(FURNACE_AT + Vector2(-4.0, 42.0), 140.0, 194.0, 0.0)
	_add_prop("works_cowpers", _works, _works_xf(COWPERS_AT, Vector3(0, 0, 1)), func(pk, kit, _labels): _kit_call(_works, "cowpers", [pk, kit, 4]))
	_note_rect(COWPERS_AT, 90.0, 40.0, 0.0)
	# The hot-blast main from the stoves' flange (32, 13, 0) to the furnace's stub (0, 13.2, -16.6), on the pipe racks.
	var flange: Vector3 = _works_xf(COWPERS_AT, Vector3(0, 0, 1)) * (Vector3(32.0, 0.0, 0.0) * PROP_SCALE)
	var stub: Vector3 = _works_xf(FURNACE_AT, Vector3(0, 0, 1)) * (Vector3(0.0, 0.0, -16.6) * PROP_SCALE)
	var mid_x: float = (flange.x + stub.x) * 0.5
	var pts := PackedVector3Array([Vector3(flange.x, 13.0 * PROP_SCALE, flange.z), Vector3(mid_x, 13.0 * PROP_SCALE, flange.z),
			Vector3(mid_x, 13.2 * PROP_SCALE, stub.z), Vector3(stub.x, 13.2 * PROP_SCALE, stub.z)])
	for i in range(pts.size()):
		pts[i] = Vector3(pts[i].x, pts[i].y, pts[i].z) / PROP_SCALE
	_add_prop("works_hotblast", _works, Transform3D(Basis(), Vector3(0, WORKS_Y, 0)), func(pk, kit, _labels): _kit_call(_works, "pipe_run", [pk, kit, pts, 1.1]))
	_add_prop("works_gasometer", _works, _works_xf(GASOMETER_AT, Vector3(0, 0, 1)), func(pk, kit, labels): _kit_call(_works, "gasometer", [pk, kit, labels]))
	_note_rect(GASOMETER_AT, 80.0, 80.0, 0.0)
	_add_prop("works_cooling", _works, _works_xf(COOLING_AT, Vector3(0, 0, 1)), func(pk, kit, _labels): _kit_call(_works, "cooling_tower", [pk, kit]))
	_note_rect(COOLING_AT, 90.0, 90.0, 0.0)
	for st in STACKS:
		var at := Vector2(st[0], st[1])
		var h: float = st[2]
		var style: int = st[3]
		_add_prop(_cell_key("works_chimneys", Vector3(at.x, 0, at.y), 400.0), _works, _works_xf(at, Vector3(0, 0, 1)), func(pk, kit, _labels): _kit_call(_works, "chimney", [pk, kit, h, style]))
		_note_rect(at, 18.0, 18.0, 0.0)
	# Pipe bridges over the north road.
	for bx in PIPE_BRIDGES_X:
		var s_b: float = _closest_s(Vector2(bx, -150.0))
		var sp: Dictionary = _spot(s_b, 0.0, 0.0)
		var bxf := Transform3D(Basis(sp["right"], Vector3.UP, -(sp["fwd"] as Vector3)), sp["pos"])
		_add_prop("works_pipes_%d" % int(bx), _works, bxf, func(pk, kit, _labels): _kit_call(_works, "pipe_bridge", [pk, kit, 44.0, 11.5, 3]))
		_note_xf(bxf, -24.0 * PROP_SCALE, 24.0 * PROP_SCALE, -4.0 * PROP_SCALE, 4.0 * PROP_SCALE, 0.5)
	# The works gate on the approach from the canal.
	var gs: Dictionary = _spot(_closest_s(WORKS_GATE), 0.0, 0.0)
	var gxf := _facing(gs["fwd"], gs["pos"])
	_add_prop("works_werkstor", _works, gxf, func(pk, kit, labels): _kit_call(_works, "works_gate", [pk, kit, labels]))
	_note_xf(gxf, -16.0 * PROP_SCALE, 16.0 * PROP_SCALE, -6.0 * PROP_SCALE, 6.0 * PROP_SCALE, 0.5)
	# The old colliery's headframe up the hill behind the estate.
	_add_prop("works_headframe", _works, _works_xf(HEADFRAME_AT, Vector3(0, 0, 1)), func(pk, kit, labels): _kit_call(_works, "headframe", [pk, kit, labels]))
	_note_rect(HEADFRAME_AT, 70.0, 90.0, 0.0)
	# Torpedo ladle cars on the works' track between the hall and the furnace.
	for tx in [404.0, 470.0]:
		var txf := _facing(Vector3(1, 0, 0), Vector3(tx, y, TORPEDO_TRACK_Z))
		_add_prop("works_torpedo", _works, txf, func(pk, kit, _labels): _kit_call(_works, "torpedo_car", [pk, kit]))
	_works_track(Vector2(362.0, TORPEDO_TRACK_Z), Vector2(548.0, TORPEDO_TRACK_Z))
	_note_rect(Vector2(455.0, TORPEDO_TRACK_Z), 190.0, 8.0, 0.0)
	# The harbour: the ore unloader over the stockpiles, barges moored along the basin.
	var hx := float(HARBOUR_RECT[0]) + 90.0
	_add_prop("works_orecrane", _works, _works_xf(Vector2(hx, float(HARBOUR_RECT[1]) - 6.0), Vector3(0, 0, 1)), func(pk, kit, _labels): _kit_call(_works, "ore_crane", [pk, kit]))
	for px in [200.0, 302.0]:
		var coal: bool = px > 250.0
		_add_prop("works_stockpiles", _works, _works_xf(Vector2(px, 160.0), Vector3(0, 0, 1)), func(pk, kit, _labels): _kit_call(_works, "stockpile", [pk, kit, 58.0, 22.0, 9.0, coal]))
		_note_rect(Vector2(px, 160.0), 96.0, 40.0, 0.0)
	# The slag heap's crown.
	var top := Vector3(HALDE_C.x, _ground_at(HALDE_C.x, HALDE_C.y), HALDE_C.y)
	_add_prop("works_crown", _works, _facing(Vector3(-0.8, 0, 0.6), top), func(pk, kit, _labels): _kit_call(_works, "steel_crown", [pk, kit]))
	_build_barges()
	_build_works_fill()


## A works track: rails and sleepers along a straight from a to b (the torpedo cars' rails: top at the ground + 0).
func _works_track(a: Vector2, b: Vector2) -> void:
	var dir: Vector2 = (b - a).normalized()
	var length: float = a.distance_to(b)
	_add_prop("works_rails", _works, Transform3D(), func(pk, kit, _labels):
		var g := 1.435 * 0.5
		var n: int = int(length / (0.65 * PROP_SCALE))
		for i in range(n):
			var t: float = (float(i) + 0.5) / float(n) * length
			var c := Vector3(a.x + dir.x * t, WORKS_Y + 0.02, a.y + dir.y * t)
			pk.set_frame(Transform3D(Basis(Vector3(-dir.y, 0, dir.x), Vector3.UP, Vector3(dir.x, 0, dir.y)) * Basis.from_scale(Vector3.ONE * PROP_SCALE), c))
			pk.block(kit, "timber", Vector3(-1.3, -0.16, -0.12), Vector3(1.3, -0.02, 0.12), Color(0.36, 0.30, 0.25), 1.0)
		pk.set_frame(Transform3D(Basis(Vector3(-dir.y, 0, dir.x), Vector3.UP, Vector3(dir.x, 0, dir.y)) * Basis.from_scale(Vector3.ONE * PROP_SCALE), Vector3(a.x, WORKS_Y + 0.02, a.y)))
		for side in [-1.0, 1.0]:
			pk.block(kit, "steel", Vector3(side * g - 0.035, -0.02, 0.0), Vector3(side * g + 0.035, 0.12, length / PROP_SCALE), Color(0.36, 0.30, 0.26)))


## Barges on the canal: one cruising up and down (SeaBoat: a long loop, its turns out of sight beyond the fog), two
## moored in the harbour.
## The barge's life length (110m in game), its draft over the model's y 0, and the cruising one's loop: lanes 2 x
## BARGE_LANE apart along the canal, turning out of sight at its ends.
const BARGE_LIFE := 60.0
const BARGE_LANE := 13.0

func _barge_scene(seed_v: int) -> PackedScene:
	var pk: PropKit = _works.new_kit(PROP_SCALE)
	var kit := {}
	var labels: Array = []
	# The kit builds the barge bow along +z with its waterline at y 0, SeaBoat's convention.
	pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * PROP_SCALE), Vector3.ZERO))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	_kit_call(_works, "barge", [pk, kit, BARGE_LIFE, labels])
	var mesh: ArrayMesh = _works.commit(pk, kit)
	for si in range(mesh.get_surface_count()):
		var m: Material = mesh.surface_get_material(si)
		if m != null and m.resource_path.is_empty():
			var id: int = m.get_instance_id()
			if not _saved_mats.has(id):
				_saved_mats[id] = _save_res(m, "mat_%d" % _saved_mats.size(), PROP_PREFIX)
			mesh.surface_set_material(si, _saved_mats[id])
	var root := Node3D.new()
	root.name = "Barge"
	var mi := MeshInstance3D.new()
	mi.name = "Hull"
	mi.mesh = _save_res(mesh, "barge_%d" % seed_v, PROP_PREFIX)
	root.add_child(mi)
	mi.owner = root
	for l in labels:
		var lab := Label3D.new()
		lab.text = l[0]
		lab.font_size = 64
		lab.pixel_size = float(l[3]) * PROP_SCALE / 44.8
		lab.modulate = l[4]
		lab.outline_size = 4
		lab.double_sided = false
		lab.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		var n: Vector3 = l[2]
		lab.transform = Transform3D(Basis.looking_at(-n, Vector3.UP), (l[1] as Vector3) * PROP_SCALE)
		root.add_child(lab)
		lab.owner = root
	var ps := PackedScene.new()
	ps.pack(root)
	var path := "res://generated/%sbarge_%d.tscn" % [PROP_PREFIX, seed_v]
	ResourceSaver.save(ps, path)
	return load(path)


func _build_barges() -> void:
	var node := Node3D.new()
	node.name = "Barges"
	level.add_child(node)
	var scene: PackedScene = _barge_scene(1)
	# Cruising: up one lane and back down the other, at a walking pace, its turns 1.9km out (in the haze).
	var cruise := Node3D.new()
	cruise.name = "CanalBarge"
	cruise.set_script(load("res://SeaBoat.gd"))
	cruise.set("model", scene)
	cruise.set("draft", 0.0)
	cruise.set("length", 3600.0)
	cruise.set("turn_radius", BARGE_LANE)
	cruise.set("speed", 4.2)
	cruise.set("phase", 1300.0)
	cruise.set("bob_height", 0.05)
	cruise.set("roll_deg", 0.3)
	cruise.set("pitch_deg", 0.15)
	cruise.set("body_top", 6.0)
	cruise.set("engine_sound", load("res://sounds/kronburg/barge_engine_loop.wav"))
	cruise.set("engine_db", -2.0)
	cruise.set("engine_unit", 30.0)
	cruise.set("wake_width", 14.0)
	# The loop's straights along the node's z: turned to run along the canal (x), centred on its middle.
	cruise.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.0, WATER_Y, CANAL_Z))
	node.add_child(cruise)
	# Moored in the harbour along its north quay, one outside the other, bows east.
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
		moored.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(float(HARBOUR_RECT[0]) + 70.0 + float(k) * 6.0, WATER_Y, float(HARBOUR_RECT[1]) + 14.0 + float(k) * 19.0))
		node.add_child(moored)


# ======================================================================================
#  Sound: the mill's hum in the hall, the furnace's roar, St. Lamberti's bells, the crane's horn
# ======================================================================================

func _player(parent: Node3D, node_name: String, path: String, at: Vector3, db: float, unit: float, max_d: float, loop_script := "") -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	if not loop_script.is_empty():
		p.set_script(load(loop_script))
	p.name = node_name
	p.stream = load(path)
	p.volume_db = db
	p.unit_size = unit
	p.max_distance = max_d
	p.bus = &"SFX"
	p.position = at
	parent.add_child(p)
	return p


func _build_sounds(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "WorksSounds"
	root.add_child(node)
	var hy: float = _hall_xf.origin.y + 8.0
	for i in range(3):
		var px: float = HALL_X0 + HALL_LEN * (0.2 + 0.3 * float(i))
		var p := _player(node, "MillHum%d" % i, "res://sounds/kronburg/rolling_mill_loop.wav", Vector3(px, hy, HALL_Z), -3.0, 34.0, 320.0)
		p.autoplay = true
	var f := _player(node, "FurnaceRoar", "res://sounds/kronburg/blast_furnace_loop.wav", Vector3(FURNACE_AT.x, WORKS_Y + 25.0, FURNACE_AT.y), -2.0, 45.0, 600.0)
	f.autoplay = true
	var horn := _player(node, "CraneHorn", "res://sounds/kronburg/crane_warning.wav", Vector3(HALL_X0 + HALL_LEN * 0.55, hy + 10.0, HALL_Z), 0.0, 30.0, 260.0, "res://PeriodicSound.gd")
	horn.set("every", 34.0)
	horn.set("jitter", 16.0)
	var bells := _player(node, "ChurchBells", "res://sounds/kronburg/church_bells.wav", Vector3(-525.0, _markt_y + 48.0, -322.0), 6.0, 90.0, 1400.0, "res://PeriodicSound.gd")
	bells.set("every", 150.0)
	bells.set("phase", 40.0)


# ======================================================================================
#  The Autobahn: a concrete viaduct striding across the valley west of the town (no traffic: it is closed for the race)
# ======================================================================================

const AUTOBAHN_X := -790.0
const AUTOBAHN_DECK := 36.0
const AUTOBAHN_Z0 := 1700.0
const AUTOBAHN_SPAN := 64.0

func _build_autobahn() -> void:
	var z: float = AUTOBAHN_Z0
	var n := 0
	var started := false
	var s_life: float = AUTOBAHN_SPAN / PROP_SCALE
	var z_south := z
	var z_north := z
	while z > -900.0:
		var g: float = _ground_at(AUTOBAHN_X, z)
		if g > AUTOBAHN_DECK - 5.0:
			if started:
				break
			z -= AUTOBAHN_SPAN
			continue
		if not started:
			z_south = z + AUTOBAHN_SPAN
		started = true
		var deck_life: float = (AUTOBAHN_DECK - g) / PROP_SCALE
		var xf := _facing(Vector3(0, 0, -1), Vector3(AUTOBAHN_X, g, z))
		var last: bool = _ground_at(AUTOBAHN_X, z - AUTOBAHN_SPAN) > AUTOBAHN_DECK - 5.0
		var first: bool = n == 0
		var sign_here: bool = absf(z - 300.0) < AUTOBAHN_SPAN * 0.5
		_add_prop(_cell_key("autobahn", xf.origin, 400.0), _town, xf, func(pk, kit, labels):
			_viaduct_bay(pk, kit, deck_life, 0.0 if last else s_life, labels, sign_here)
			if first:
				# The bay back to the hillside behind the first pier.
				pk.set_frame(pk.xf * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO))
				_viaduct_bay(pk, kit, deck_life, s_life, [], false))
		_note_rect(Vector2(AUTOBAHN_X, z - AUTOBAHN_SPAN * 0.5), 44.0, AUTOBAHN_SPAN, 0.0)
		n += 1
		z_north = z - (0.0 if last else AUTOBAHN_SPAN)
		z -= AUTOBAHN_SPAN
	_autobahn_span = Vector2(z_south, z_north)
	print("  Autobahn viaduct: %d piers, z %.0f to %.0f" % [n, z_south, z_north])
	_build_autobahn_traffic()


var _autobahn_span := Vector2.ZERO

## Traffic on the viaduct: CampKit's vans, SUVs and motorhomes at PROP_SCALE, two lanes each way, on the wall clock
## (AutobahnTraffic.gd), shrinking away at the viaduct's ends.
func _build_autobahn_traffic() -> void:
	var pk := PropKit.new()
	pk.material_for = func(key: String) -> Material: return _camp_material(key)
	var camp := CampKit.new(pk)
	var meshes: Array[Mesh] = []
	var kinds := [["van", Color(0.92, 0.92, 0.90)], ["suv", Color(0.16, 0.18, 0.22)], ["suv", Color(0.62, 0.10, 0.10)], ["motorhome", Color(0.94, 0.94, 0.92)], ["van", Color(0.20, 0.32, 0.55)]]
	for k in kinds:
		var kit := {}
		pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * PROP_SCALE), Vector3.ZERO))
		camp.vehicle(kit, k[0], k[1])
		meshes.append(_save_res(pk.commit(kit), "autobahn_%s_%d" % [k[0], meshes.size()], PROP_PREFIX))
	var t := Node3D.new()
	t.name = "AutobahnTraffic"
	t.set_script(load("res://AutobahnTraffic.gd"))
	t.position = Vector3(AUTOBAHN_X, AUTOBAHN_DECK + 0.05, _autobahn_span.x)
	t.set("meshes", meshes)
	t.set("length", _autobahn_span.x - _autobahn_span.y)
	# Lanes (x in the node's frame, + is east): northbound on the east carriageway.
	t.set("lanes", PackedFloat32Array([5.4, 10.6, -5.4, -10.6]))
	level.add_child(t)
## One bay of the viaduct in its pier's frame (life size): the pier pair at the origin, the box girder on toward -z for
## `span`, its deck's top `deck` over the ground. The road on top, its barriers, the deck's cornices.
func _viaduct_bay(pk: PropKit, kit: Dictionary, deck: float, span: float, labels: Array, sign_here: bool) -> void:
	var conc := Color(0.70, 0.69, 0.66)
	var dark := Color(0.46, 0.45, 0.43)
	var half_w := 13.5
	var top: float = deck
	var girder: float = 3.2
	# The pier: two tapered columns on a footing, a cap beam across.
	for side in [-1.0, 1.0]:
		var x: float = side * 4.2
		pk.box(kit, "concrete", Transform3D(Basis(), Vector3(x, -1.5, 0)), Vector3(4.6, 3.0, 4.6), conc, YardKit.uvk)
		var h: float = top - girder - 1.4
		var steps := 4
		for k in range(steps):
			var y0: float = h * float(k) / float(steps)
			var y1: float = h * float(k + 1) / float(steps)
			var wdt: float = lerpf(2.6, 2.0, (y0 + y1) * 0.5 / maxf(h, 1.0))
			pk.box(kit, "concrete", Transform3D(Basis(), Vector3(x, (y0 + y1) * 0.5, 0)), Vector3(wdt, y1 - y0 + 0.01, wdt * 1.25), conc, YardKit.uvk)
	pk.box(kit, "concrete", Transform3D(Basis(), Vector3(0, top - girder - 0.7, 0)), Vector3(12.4, 1.4, 3.2), conc, YardKit.uvk)
	if span <= 0.0:
		return
	var zc: float = -span * 0.5
	# The box girder: a bottom slab, two webs, the deck slab with its cantilevers.
	pk.box(kit, "concrete", Transform3D(Basis(), Vector3(0, top - girder + 0.2, zc)), Vector3(8.0, 0.4, span + 0.02), dark, YardKit.uvk)
	for side in [-1.0, 1.0]:
		pk.box(kit, "concrete", Transform3D(Basis(Vector3.BACK, side * 0.22), Vector3(side * 4.6, top - girder * 0.5, zc)), Vector3(0.45, girder, span + 0.01), conc, YardKit.uvk)
	pk.box(kit, "concrete", Transform3D(Basis(), Vector3(0, top - 0.25, zc)), Vector3(half_w * 2.0, 0.5, span), conc, YardKit.uvk)
	# Cornices and the steel guardrails (Schutzplanke) on posts, the concrete divider down the middle.
	for side in [-1.0, 1.0]:
		pk.box(kit, "concrete", Transform3D(Basis(), Vector3(side * (half_w - 0.3), top + 0.2, zc)), Vector3(0.62, 0.5, span), Color(0.80, 0.79, 0.76), YardKit.uvk)
		pk.box(kit, "metal", Transform3D(Basis(), Vector3(side * (half_w - 0.75), top + 0.85, zc)), Vector3(0.08, 0.32, span), Color(0.72, 0.74, 0.75), YardKit.uvk)
		var posts: int = int(span / 2.0)
		for k in range(posts):
			pk.box(kit, "metal", Transform3D(Basis(), Vector3(side * (half_w - 0.62), top + 0.55, -2.0 * float(k) - 1.0)), Vector3(0.1, 0.9, 0.12), Color(0.55, 0.57, 0.58), YardKit.uvk)
	pk.box(kit, "concrete", Transform3D(Basis(), Vector3(0, top + 0.45, zc)), Vector3(0.6, 0.9, span), Color(0.78, 0.77, 0.74), YardKit.uvk)
	if sign_here:
		# A blue direction sign on a gantry over the northbound lanes.
		for side in [-1.0, 1.0]:
			pk.box(kit, "metal", Transform3D(Basis(), Vector3(side * 12.6, top + 3.6, -6.0)), Vector3(0.35, 7.2, 0.35), Color(0.55, 0.57, 0.58), YardKit.uvk)
		pk.box(kit, "metal", Transform3D(Basis(), Vector3(0, top + 7.0, -6.0)), Vector3(25.6, 0.5, 0.5), Color(0.55, 0.57, 0.58), YardKit.uvk)
		pk.box(kit, "metal", Transform3D(Basis(), Vector3(6.0, top + 5.6, -6.25)), Vector3(10.0, 3.0, 0.12), Color(0.08, 0.26, 0.62), YardKit.uvk)
		labels.append(["Kronburg-Hütte", Vector3(6.0, top + 6.1, -6.33), Vector3(0, 0, -1), 0.55, Color(1, 1, 1), 9.0])
		labels.append(["A 47  Ruhrtal", Vector3(6.0, top + 5.0, -6.33), Vector3(0, 0, -1), 0.45, Color(1, 1, 1), 9.0])


# ======================================================================================
#  German traffic signs: Tempo 30 zone, a warning triangle, the yellow priority diamond, a gradient warning
# ======================================================================================

## A sign on a grey post in its own frame (life size), its face toward +z: `kind` "limit" (a red ring round a number),
## "warn" (a red-bordered triangle with a symbol and a plate under it), "priority" (the yellow diamond).
func _traffic_sign(pk: PropKit, kit: Dictionary, labels: Array, kind: String, text: String, plate := "") -> void:
	var grey := Color(0.62, 0.64, 0.65)
	var white := Color(0.95, 0.95, 0.93)
	var red := Color(0.78, 0.08, 0.08)
	pk.tube(kit, "metal", Vector3(0, -0.4, 0), Vector3(0, 2.55, 0), 0.032, 0.032, 10, grey)
	var y := 2.15
	match kind:
		"limit":
			pk.tube(kit, "paint", Vector3(0, y, 0.035), Vector3(0, y, 0.055), 0.33, 0.33, 28, red)
			pk.tube(kit, "paint", Vector3(0, y, 0.055), Vector3(0, y, 0.07), 0.265, 0.265, 28, white)
			labels.append([text, Vector3(0, y - 0.11, 0.08), Vector3(0, 0, 1), 0.2, Color(0.05, 0.05, 0.05), 0.42])
			if not plate.is_empty():
				pk.block(kit, "paint", Vector3(-0.3, y - 0.62, 0.035), Vector3(0.3, y - 0.4, 0.055), white)
				labels.append([plate, Vector3(0, y - 0.56, 0.06), Vector3(0, 0, 1), 0.1, Color(0.05, 0.05, 0.05), 0.55])
		"warn":
			var o := Vector2(0.0, y)
			var tri_o := PackedVector2Array([Vector2(-0.45, -0.3) + o, Vector2(0.45, -0.3) + o, Vector2(0.0, 0.48) + o])
			var tri_i := PackedVector2Array([Vector2(-0.33, -0.23) + o, Vector2(0.33, -0.23) + o, Vector2(0.0, 0.33) + o])
			pk.extrude(kit, "paint", tri_o, 0.035, 0.055, 0.0, red)
			pk.extrude(kit, "paint", tri_i, 0.055, 0.07, 0.0, white)
			labels.append([text, Vector3(0, y - 0.12, 0.08), Vector3(0, 0, 1), 0.16, Color(0.05, 0.05, 0.05), 0.4])
			if not plate.is_empty():
				pk.block(kit, "paint", Vector3(-0.42, y - 0.62, 0.035), Vector3(0.42, y - 0.4, 0.055), white)
				labels.append([plate, Vector3(0, y - 0.56, 0.06), Vector3(0, 0, 1), 0.085, Color(0.05, 0.05, 0.05), 0.78])
		"priority":
			var rot := Basis(Vector3(0, 0, 1), PI * 0.25)
			pk.box(kit, "paint", Transform3D(rot, Vector3(0, y, 0.045)), Vector3(0.5, 0.5, 0.02), white)
			pk.box(kit, "paint", Transform3D(rot, Vector3(0, y, 0.06)), Vector3(0.36, 0.36, 0.015), Color(0.98, 0.76, 0.06))


func _build_traffic_signs() -> void:
	var s_tg: float = _closest_s(TOWN_GATE)
	var s7: float = _corner_s(7)
	var s_c1: float = _corner_s(1)
	var s_fin: float = _closest_s(Vector2(FINISH_X, 250.0))
	var defs: Array = [
		[s_tg - 40.0, "limit", "30", "ZONE"],
		[s7 + 58.0, "warn", "10%", ""],
		[s_c1 - 150.0, "warn", "!", "Werksverkehr"],
		[s_fin + 150.0, "priority", "", ""],
	]
	for d in defs:
		var sp: Dictionary = _spot(float(d[0]), ROAD_HALF + (PAVEMENT if _kind_at(_road_kinds(), float(d[0])) in [1, 2] else 1.8), 0.0)
		var p: Vector3 = sp["pos"]
		p.y = maxf(_ground_at(p.x, p.z), _lap_y(float(d[0])) - 0.1)
		var kind: String = d[1]
		var text: String = d[2]
		var plate: String = d[3]
		var xf := _facing(-(sp["fwd"] as Vector3), p)
		_add_prop(_cell_key("signs", p, 300.0), _town, xf, func(pk, kit, labels): _traffic_sign(pk, kit, labels, kind, text, plate), 350.0)


# ======================================================================================
#  Steam, smoke and sparks
# ======================================================================================

var _puff_tex: Texture2D

func _puff_texture() -> Texture2D:
	if _puff_tex == null:
		# A soft, lumpy puff: radial falloff times low-frequency noise, white (the material tints it).
		var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
		var nz := FastNoiseLite.new()
		nz.seed = 77
		nz.frequency = 0.045
		for y in range(128):
			for x in range(128):
				var d: float = Vector2(x - 63.5, y - 63.5).length() / 64.0
				var a: float = clampf(1.0 - d, 0.0, 1.0)
				a = a * a * (3.0 - 2.0 * a)
				a *= clampf(0.65 + 0.7 * nz.get_noise_2d(x, y), 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		img.generate_mipmaps()
		_puff_tex = _save_res(ImageTexture.create_from_image(img), "puff_texture")
	return _puff_tex


## A plume of steam ("steam": the cooling tower), smoke ("smoke": a stack) or sparks ("sparks": the mill stands) at `at`.
func _plume(parent: Node3D, node_name: String, at: Vector3, kind: String, size := 1.0) -> void:
	var p := GPUParticles3D.new()
	p.name = node_name
	p.position = at
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	var quad := QuadMesh.new()
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	var grad := Gradient.new()
	match kind:
		"steam", "smoke":
			var steam: bool = kind == "steam"
			p.amount = 48 if steam else 32
			p.lifetime = 16.0 if steam else 13.0
			p.preprocess = p.lifetime
			p.visibility_aabb = AABB(Vector3(-150, -20, -150), Vector3(300, 260, 300))
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			pm.emission_sphere_radius = (14.0 if steam else 1.6) * size
			pm.direction = Vector3(0.2, 1.0, 0.1)
			pm.spread = 12.0
			pm.initial_velocity_min = (7.0 if steam else 4.0) * size
			pm.initial_velocity_max = (10.0 if steam else 6.0) * size
			pm.gravity = Vector3(1.6, -0.4, 0.8)
			pm.damping_min = 0.25
			pm.damping_max = 0.45
			pm.angle_min = -180.0
			pm.angle_max = 180.0
			pm.angular_velocity_min = -6.0
			pm.angular_velocity_max = 6.0
			var sc := Curve.new()
			sc.add_point(Vector2(0.0, 0.35))
			sc.add_point(Vector2(1.0, 1.0))
			var sct := CurveTexture.new()
			sct.curve = sc
			pm.scale_curve = sct
			quad.size = Vector2.ONE * (34.0 if steam else 12.0) * size
			mat.albedo_texture = _puff_texture()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
			mat.disable_receive_shadows = true
			var c: Color = Color(0.96, 0.97, 0.98) if steam else Color(0.42, 0.40, 0.38)
			grad.colors = PackedColorArray([Color(c, 0.0), Color(c, 0.85 if steam else 0.6), Color(c, 0.35), Color(c, 0.0)])
			grad.offsets = PackedFloat32Array([0.0, 0.08, 0.55, 1.0])
		"sparks":
			p.amount = 90
			p.lifetime = 1.1
			p.visibility_aabb = AABB(Vector3(-20, -6, -20), Vector3(40, 20, 40))
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			pm.emission_sphere_radius = 0.8
			pm.direction = Vector3(0, 0.6, 1)
			pm.spread = 55.0
			pm.initial_velocity_min = 6.0
			pm.initial_velocity_max = 13.0
			pm.gravity = Vector3(0, -12.0, 0)
			quad.size = Vector2(0.16, 0.16)
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			mat.albedo_texture = _puff_texture()
			grad.colors = PackedColorArray([Color(1.0, 0.95, 0.7, 1.0), Color(1.0, 0.55, 0.15, 0.9), Color(0.8, 0.2, 0.05, 0.0)])
			grad.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	quad.material = mat
	p.draw_pass_1 = quad
	parent.add_child(p)


# ======================================================================================
#  The old town's back lanes: cobbled, off the lap, houses either side
# ======================================================================================

const LANE_HALF := 4.2
## [points (x, z)]: the Gasse north of the Hauptstraße, the one south of it, and the lane down behind the Kirchberg.
const LANES := [
	[Vector2(-262.0, -287.0), Vector2(-428.0, -287.0)],
	[Vector2(-268.0, -173.0), Vector2(-418.0, -173.0)],
	[Vector2(-268.0, -112.0), Vector2(-436.0, -112.0)],
	[Vector2(-404.0, -150.0), Vector2(-404.0, -117.0)],
]

func _build_lanes(rng: RandomNumberGenerator) -> void:
	var node := Node3D.new()
	node.name = "Lanes"
	level.add_child(node)
	var li := 0
	for lane in LANES:
		var a: Vector2 = lane[0]
		var b: Vector2 = lane[1]
		var dir: Vector2 = (b - a).normalized()
		var right := Vector2(-dir.y, dir.x)
		var length: float = a.distance_to(b)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var n: int = ceili(length / 2.0)
		var lats := [-LANE_HALF, 0.0, LANE_HALF]
		for i in range(n):
			for j in range(lats.size() - 1):
				var q: Array = []
				for c in [[i, j], [i, j + 1], [i + 1, j], [i + 1, j + 1]]:
					var t: float = float(c[0]) / float(n) * length
					var l: float = lats[c[1]]
					var p2: Vector2 = a + dir * t + right * l
					q.append([Vector3(p2.x, _ground_at(p2.x, p2.y) + 0.06, p2.y), Vector2(l, t)])
				for tri in [[0, 2, 1], [1, 2, 3]]:
					var p0: Vector3 = q[tri[0]][0]
					var p1: Vector3 = q[tri[1]][0]
					var p2b: Vector3 = q[tri[2]][0]
					var nrm: Vector3 = (p2b - p0).cross(p1 - p0).normalized()
					if nrm.y < 0.0:
						nrm = -nrm
					for k in tri:
						st.set_normal(nrm)
						st.set_color(Color(1, 0, 0, 1))
						st.set_uv(q[k][1])
						st.set_uv2(Vector2(1.0, LANE_HALF))
						st.add_vertex(q[k][0])
		var mesh: ArrayMesh = st.commit()
		mesh.surface_set_material(0, _road_mat)
		var mi := MeshInstance3D.new()
		mi.name = "Gasse_%d" % li
		mi.mesh = _save_res(mesh, "lane_%d" % li, "kronburgroad_")
		mi.visibility_range_end = 900.0
		node.add_child(mi)
		# Houses either side, fronts on the lane's edge.
		for side in [-1.0, 1.0]:
			var face := Vector3(-right.x * side, 0.0, -right.y * side)
			var off: Vector2 = right * side * (LANE_HALF + 0.5)
			var pa := Vector3(a.x + off.x, -10000.0, a.y + off.y)
			var pb := Vector3(b.x + off.x, -10000.0, b.y + off.y)
			_row(pa, pb, face, rng)
		var mid2: Vector2 = (a + b) * 0.5
		_note_rect(mid2, LANE_HALF * 2.0, length, atan2(-right.y, right.x), 0.0)
		li += 1


# ======================================================================================
#  The town wall: rubble stone with a parapet of merlons, round towers under slate cones, open where the lap and the
#  lanes go through (the Hauptstraße through the gate tower)
# ======================================================================================

## The wall's corners (x, z), closed round the old town.
const WALL := [Vector2(-243.0, -352.0), Vector2(-578.0, -352.0), Vector2(-578.0, -68.0), Vector2(-243.0, -68.0)]
const WALL_H := 7.5
const WALL_T := 1.7
const TOWER_EVERY := 78.0

func _build_town_wall() -> void:
	var gaps: Array = []
	# The gate (its own wall stubs), the Kirchberg's way out, the estate's road at the wall's corner.
	gaps.append([TOWN_GATE, 20.5 * PROP_SCALE])
	var n: int = WALL.size()
	var towers: Array = []
	for i in range(n):
		var a: Vector2 = WALL[i]
		var b: Vector2 = WALL[(i + 1) % n]
		var length: float = a.distance_to(b)
		var dir: Vector2 = (b - a) / length
		var t := 0.0
		var step := 7.0
		while t < length - 0.01:
			var t1: float = minf(t + step, length)
			var p0: Vector2 = a + dir * t
			var p1: Vector2 = a + dir * t1
			var mid: Vector2 = (p0 + p1) * 0.5
			var open := false
			for g in gaps:
				if mid.distance_to(g[0]) < float(g[1]):
					open = true
			if _lap_dist(mid.x, mid.y) < ROAD_HALF + PAVEMENT + 3.0 or _occupied(mid.x, mid.y):
				open = true
			for lane in LANES:
				var la: Vector2 = lane[0]
				var lb: Vector2 = lane[1]
				var q: Vector2 = Geometry2D.get_closest_point_to_segment(mid, la, lb)
				if q.distance_to(mid) < LANE_HALF + 3.0:
					open = true
			if not open:
				var g0: float = minf(_ground_at(p0.x, p0.y), _ground_at(p1.x, p1.y))
				var g1: float = maxf(_ground_at(p0.x, p0.y), _ground_at(p1.x, p1.y))
				var seg_len: float = t1 - t
				var xf := Transform3D(Basis(Vector3(dir.x, 0, dir.y), Vector3.UP, Vector3(-dir.y, 0, dir.x)), Vector3(mid.x, g0, mid.y))
				var top_life: float = (g1 - g0) / PROP_SCALE + WALL_H
				var ll: float = seg_len / PROP_SCALE + 0.02
				_add_prop(_cell_key("wall", xf.origin, 300.0), _town, xf, func(pk, kit, _labels): _wall_piece(pk, kit, ll, top_life))
				_note_rect(mid, seg_len, WALL_T * PROP_SCALE + 1.0, atan2(-dir.y, dir.x), 0.3)
			t = t1
		# Towers: at the corner and every TOWER_EVERY along, where the wall stands.
		var tt := 0.0
		while tt < length:
			var tp: Vector2 = a + dir * tt
			var near_gap := false
			for g in gaps:
				if tp.distance_to(g[0]) < float(g[1]) + 6.0:
					near_gap = true
			if not near_gap and _lap_dist(tp.x, tp.y) > ROAD_HALF + PAVEMENT + 9.0:
				towers.append(tp)
			tt += TOWER_EVERY
	for tp in towers:
		var ty: float = _ground_range(tp, 9.0, 9.0, 0.0).x
		var r := RandomNumberGenerator.new()
		r.seed = int(tp.x * 13.0 + tp.y * 7.0)
		var h_life: float = r.randf_range(12.0, 15.5)
		_add_prop(_cell_key("wall", Vector3(tp.x, ty, tp.y), 300.0), _town, _facing(Vector3(0, 0, 1), Vector3(tp.x, ty, tp.y)), func(pk, kit, _labels): _wall_tower(pk, kit, h_life))
		_note_rect(tp, 12.0, 12.0, 0.0, 0.3)
	print("  town wall: %d towers" % towers.size())


## A piece of wall `length` long (life) along x, centred, its top `top` over its lower foot, a parapet of merlons.
func _wall_piece(pk: PropKit, kit: Dictionary, length: float, top: float) -> void:
	var stone := Color(0.80, 0.74, 0.64)
	var cap := Color(0.70, 0.66, 0.58)
	YardKit.blk(pk, kit, "stone", Vector3(-length * 0.5, -3.0, -WALL_T * 0.5), Vector3(length * 0.5, top - 1.0, WALL_T * 0.5), stone)
	YardKit.blk(pk, kit, "stone", Vector3(-length * 0.5, top - 1.0, -WALL_T * 0.5 - 0.06), Vector3(length * 0.5, top - 0.8, WALL_T * 0.5 + 0.06), cap)
	# Merlons on the outer half, 1.1m wide with 0.9m gaps.
	var x := -length * 0.5
	while x < length * 0.5 - 0.3:
		var x1: float = minf(x + 1.1, length * 0.5)
		YardKit.blk(pk, kit, "stone", Vector3(x, top - 0.8, -WALL_T * 0.5), Vector3(x1, top + 0.45, -0.1), stone)
		x += 2.0


## A round wall tower (life size) on the ground at its origin: rubble stone, arrow slits, a slate cone with a finial.
func _wall_tower(pk: PropKit, kit: Dictionary, h: float) -> void:
	var r := 3.6
	var stone := Color(0.80, 0.73, 0.62)
	pk.lathe(kit, "stone", Vector3.ZERO, [Vector2(r + 0.4, -4.0), Vector2(r + 0.3, 0.0), Vector2(r, 1.2), Vector2(r, h), Vector2(r + 0.35, h + 0.1), Vector2(r + 0.35, h + 0.5), Vector2(0.0, h + 0.5)], 20, stone)
	# Arrow slits, dark, a little proud of the round face.
	for k in range(4):
		var ang: float = TAU * float(k) / 4.0 + 0.4
		var out := Vector3(cos(ang), 0, sin(ang))
		for yy in [h * 0.35, h * 0.68]:
			var c: Vector3 = out * (r + 0.02) + Vector3(0, yy, 0)
			YardKit.box_at(pk, kit, "matte", c, Basis(out.cross(Vector3.UP).normalized(), Vector3.UP, out), Vector3(0.18, 1.1, 0.04), Color(0.06, 0.06, 0.06))
	# The slate cone.
	pk.lathe(kit, "slate", Vector3(0, h + 0.5, 0), [Vector2(r + 0.6, 0.0), Vector2(r * 0.55, h * 0.32), Vector2(0.08, h * 0.62)], 20, Color(0.34, 0.36, 0.40))
	pk.tube(kit, "metal", Vector3(0, h + 0.5 + h * 0.6, 0), Vector3(0, h + 0.5 + h * 0.62 + 1.4, 0), 0.05, 0.03, 6, Color(0.70, 0.58, 0.30))



# ======================================================================================
#  Inside the loop: the allotments, the beer garden, the football pitch
# ======================================================================================

func _build_leisure() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3307
	# Kleingärten: two rows of plots either side of a path, gates on the path.
	var pw: float = 12.0 * PROP_SCALE
	var pd: float = 16.0 * PROP_SCALE
	var plots := 0
	for row in [-1.0, 1.0]:
		var x: float = ALLOT_X.x
		while x + pw < ALLOT_X.y:
			var face := Vector3(0, 0, -row)
			var front_z: float = ALLOT_Z + row * 2.5
			var at := Vector3(x if row < 0.0 else x + pw, 0.0, front_z)
			at.y = _ground_at(x + pw * 0.5, front_z - face.z * pd * 0.5)
			var xf := _facing(face, at)
			if _clear(at + xf.basis.x * (pw * 0.5) - face * (pd * 0.5), xf.basis.x, pw, pd):
				var seed_v: int = rng.randi()
				_add_prop(_cell_key("allot", at, 200.0), _town, xf, func(pk, kit, _labels):
					var r := RandomNumberGenerator.new()
					r.seed = seed_v
					_kit_call(_town, "allotment", [pk, kit, 12.0, 16.0, r]), 700.0)
				_note_xf(xf, 0.0, pw, -pd, 0.0, 0.2)
				plots += 1
			x += pw + 0.4
	_note_rect(Vector2((ALLOT_X.x + ALLOT_X.y) * 0.5, ALLOT_Z), ALLOT_X.y - ALLOT_X.x, 5.0, 0.0, 0.0)
	# The beer garden, its front on the Kanalstraße's north verge.
	var bs: Dictionary = _spot(_closest_s(Vector2(BEERGARDEN_AT.x, 250.0)), -(ROAD_HALF + 4.0), 0.0)
	var bp: Vector3 = bs["pos"]
	bp.y = _ground_at(bp.x, bp.z)
	var bxf := _facing(bs["right"], bp)
	bxf.origin -= bxf.basis.x * (15.0 * PROP_SCALE)
	_add_prop("leisure_beergarden", _town, bxf, func(pk, kit, labels):
		var r := RandomNumberGenerator.new()
		r.seed = 91
		_kit_call(_town, "beer_garden", [pk, kit, 30.0, 18.0, r]), 600.0)
	_note_xf(bxf, 0.0, 30.0 * PROP_SCALE, -18.0 * PROP_SCALE, 0.0, 0.5)
	_build_pitch()
	print("  allotments: %d plots" % plots)


## The football pitch: red ash with white lines, goals, four floodlight masts, a clubhouse; its own mesh.
func _build_pitch() -> void:
	var c := Vector3((float(SPORT_RECT[0]) + float(SPORT_RECT[2])) * 0.5, _sport_y + 0.03, (float(SPORT_RECT[1]) + float(SPORT_RECT[3])) * 0.5)
	var xf := _facing(Vector3(0, 0, 1), c)
	_add_prop("leisure_pitch", _town, xf, func(pk, kit, labels): _pitch(pk, kit, labels), 900.0)
	_note_rect(Vector2(c.x, c.z), float(SPORT_RECT[2]) - float(SPORT_RECT[0]), float(SPORT_RECT[3]) - float(SPORT_RECT[1]), 0.0, 0.0)


## Life size, centred: a 64 x 42m ash pitch along x.
func _pitch(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var hx := 32.0
	var hz := 21.0
	var ash := Color(0.62, 0.30, 0.20)
	var white := Color(0.92, 0.90, 0.86)
	pk.block(kit, "matte", Vector3(-hx - 3.0, -0.3, -hz - 3.0), Vector3(hx + 3.0, 0.0, hz + 3.0), ash)
	var lw := 0.1
	var ly := 0.006
	for z in [-hz, hz]:
		pk.block(kit, "paint", Vector3(-hx, 0.0, z - lw * 0.5), Vector3(hx, ly, z + lw * 0.5), white)
	for x in [-hx, 0.0, hx]:
		pk.block(kit, "paint", Vector3(x - lw * 0.5, 0.0, -hz), Vector3(x + lw * 0.5, ly, hz), white)
	for sx in [-1.0, 1.0]:
		# Penalty areas and goals.
		var gx: float = sx * hx
		pk.block(kit, "paint", Vector3(minf(gx, gx - sx * 12.0) - 0.0, 0.0, -12.0 - lw * 0.5), Vector3(maxf(gx, gx - sx * 12.0), ly, -12.0 + lw * 0.5), white)
		pk.block(kit, "paint", Vector3(minf(gx, gx - sx * 12.0), 0.0, 12.0 - lw * 0.5), Vector3(maxf(gx, gx - sx * 12.0), ly, 12.0 + lw * 0.5), white)
		pk.block(kit, "paint", Vector3(gx - sx * 12.0 - lw * 0.5, 0.0, -12.0), Vector3(gx - sx * 12.0 + lw * 0.5, ly, 12.0), white)
		for gz in [-3.66, 3.66]:
			pk.tube(kit, "paint", Vector3(gx, 0.0, gz), Vector3(gx, 2.44, gz), 0.06, 0.06, 8, white)
		pk.tube(kit, "paint", Vector3(gx, 2.44, -3.66), Vector3(gx, 2.44, 3.66), 0.06, 0.06, 8, white)
		pk.tube(kit, "metal", Vector3(gx + sx * 1.8, 0.0, -3.66), Vector3(gx + sx * 1.8, 2.0, -3.66), 0.03, 0.03, 6, Color(0.5, 0.5, 0.5))
		pk.tube(kit, "metal", Vector3(gx + sx * 1.8, 0.0, 3.66), Vector3(gx + sx * 1.8, 2.0, 3.66), 0.03, 0.03, 6, Color(0.5, 0.5, 0.5))
	# The centre circle (a ring of thin boxes).
	for k in range(36):
		var a0: float = TAU * float(k) / 36.0
		var a1: float = TAU * float(k + 1) / 36.0
		pk.beam(kit, "paint", Vector3(cos(a0) * 9.15, ly * 0.5, sin(a0) * 9.15), Vector3(cos(a1) * 9.15, ly * 0.5, sin(a1) * 9.15), lw, ly, white)
	# Floodlight masts at the corners: lattice-ish poles with a bank of lamps.
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			var base := Vector3(cx * (hx + 2.0), 0.0, cz * (hz + 2.0))
			pk.tube(kit, "metal", base + Vector3(0, -1.0, 0), base + Vector3(0, 22.0, 0), 0.35, 0.22, 10, Color(0.62, 0.64, 0.66))
			var face := Vector3(-cx, 0, -cz).normalized()
			pk.box(kit, "metal", Transform3D(Basis(face.cross(Vector3.UP).normalized(), Vector3.UP, face), base + Vector3(0, 22.5, 0) + face * 0.3), Vector3(3.2, 1.6, 0.3), Color(0.40, 0.42, 0.44))
			pk.box(kit, "lamp", Transform3D(Basis(face.cross(Vector3.UP).normalized(), Vector3.UP, face), base + Vector3(0, 22.5, 0) + face * 0.47), Vector3(2.9, 1.3, 0.04), Color(0.95, 0.95, 0.9))
	# The clubhouse at one end: a low brick building with a flat roof and the club's name.
	var ch := Vector3(0.0, 0.0, -hz - 9.0)
	YardKit.blk(pk, kit, "brick", ch + Vector3(-9.0, -1.0, -3.5), ch + Vector3(9.0, 3.4, 3.5), Color(0.62, 0.30, 0.22))
	YardKit.blk(pk, kit, "concrete", ch + Vector3(-9.4, 3.4, -3.9), ch + Vector3(9.4, 3.7, 3.9), Color(0.72, 0.71, 0.68))
	for wx in [-6.0, -2.0, 2.0, 6.0]:
		YardKit.window(pk, kit, ch + Vector3(wx, 1.8, 3.5), Vector3(0, 0, 1), 1.6, 1.1)
	labels.append(["SV Glückauf Kronburg 1919", ch + Vector3(0, 2.95, 3.56), Vector3(0, 0, 1), 0.42, Color(0.95, 0.85, 0.20), 16.0])



## The hall's glow and sparks at the kit's spots (SteelworksKit.hall_fx_spots, life size in the hall's frame), steam off the
## cooling tower, smoke from the stacks. Lights carry `no_shadow` (MusicManager leaves them unshadowed).
func _build_works_fx(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "WorksFx"
	root.add_child(node)
	var spots: Array = []
	for m in _works.get_script_method_list():
		if m["name"] == "hall_fx_spots":
			spots = _works.call("hall_fx_spots", HALL_LIFE)
	var lights := 0
	for sp in spots:
		var kind: String = sp[0]
		var at: Vector3 = _hall_xf * ((sp[1] as Vector3) * PROP_SCALE)
		if kind.ends_with("_light") and kind != "hall_fill_light":
			var l := OmniLight3D.new()
			l.name = kind.to_pascal_case()
			l.position = at
			l.light_color = Color(1.0, 0.55, 0.22) if not kind.begins_with("cooling") else Color(0.95, 0.32, 0.12)
			l.light_energy = 2.2
			l.omni_range = (14.0 if kind == "stand_lights" else 11.0) * PROP_SCALE
			l.omni_attenuation = 1.4
			l.shadow_enabled = false
			l.set_meta(&"no_shadow", true)
			l.distance_fade_enabled = true
			l.distance_fade_begin = 160.0
			l.distance_fade_length = 40.0
			node.add_child(l)
			lights += 1
		elif kind.ends_with("_sparks_steam"):
			_plume(node, kind.to_pascal_case() + "Sparks", at, "sparks")
			_plume(node, kind.to_pascal_case() + "Steam", at + Vector3(0, 1.0, 0), "smoke", 0.35)
		elif kind == "stack_smoke":
			_plume(node, "HallStackSmoke", at, "smoke", 0.8)
	# Soft fill along the road under the roof, so the hall doesn't read as a cave.
	for k in range(4):
		var f := OmniLight3D.new()
		f.name = "HallFill%d" % k
		f.position = _hall_xf * Vector3(0.0, 15.0 * PROP_SCALE, -HALL_LIFE * PROP_SCALE * (0.14 + 0.24 * float(k)))
		f.light_color = Color(1.0, 0.93, 0.82)
		f.light_energy = 0.9
		f.omni_range = 42.0
		f.omni_attenuation = 0.8
		f.shadow_enabled = false
		f.set_meta(&"no_shadow", true)
		f.distance_fade_enabled = true
		f.distance_fade_begin = 200.0
		f.distance_fade_length = 40.0
		node.add_child(f)
	# The blast furnace's tap hole and the pour into the torpedo car: sparks and an orange glow; smoke off the stoves' chimney
	# (SteelworksKit.works_fx_spots, in each builder's own frame).
	var has_spots := false
	for m in _works.get_script_method_list():
		if m["name"] == "works_fx_spots":
			has_spots = true
	if has_spots:
		var fxf: Transform3D = _works_xf(FURNACE_AT, Vector3(0, 0, 1))
		var cxf: Transform3D = _works_xf(COWPERS_AT, Vector3(0, 0, 1))
		for sp in _works.call("works_fx_spots"):
			var kind: String = sp[0]
			var lp: Vector3 = (sp[1] as Vector3) * PROP_SCALE
			if kind == "furnace_tap_hole" or kind == "furnace_pour":
				var at: Vector3 = fxf * lp
				_plume(node, kind.to_pascal_case() + "Sparks", at, "sparks")
				var l := OmniLight3D.new()
				l.name = kind.to_pascal_case() + "Glow"
				l.position = at + Vector3(0, 1.5, 0)
				l.light_color = Color(1.0, 0.55, 0.2)
				l.light_energy = 2.4
				l.omni_range = 18.0
				l.shadow_enabled = false
				l.set_meta(&"no_shadow", true)
				l.distance_fade_enabled = true
				l.distance_fade_begin = 180.0
				l.distance_fade_length = 40.0
				node.add_child(l)
				lights += 1
			elif kind == "furnace_runner":
				_plume(node, "FurnaceRunnerFume", fxf * lp, "smoke", 0.5)
			elif kind == "cowper_chimney":
				_plume(node, "CowperSmoke", cxf * lp, "smoke", 1.1)
	# Steam off the cooling tower, smoke from the stacks.
	_plume(node, "CoolingSteam", Vector3(COOLING_AT.x, WORKS_Y + COOLING_TOP, COOLING_AT.y), "steam")
	for st in STACKS:
		_plume(node, "StackSmoke%d" % int(st[0]), Vector3(st[0], WORKS_Y + float(st[2]) * PROP_SCALE + 1.0, st[1]), "smoke", 1.2)
	print("  works fx: %d lights" % (lights + 4))



## People in town: watching from the market square's edges (in front of St. Lamberti and the Rathaus), by the fountain and
## at the town gate; a few in the beer garden's gateway.
func _build_town_people() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4410
	var y: float = _markt_y
	var before: int = _people.size()
	var groups: Array = [
		# [from, to, facing, count]
		[Vector3(-528.0, y, -305.5), Vector3(-462.0, y, -305.5), Vector3(0, 0, 1), 16],
		[Vector3(-523.0, y, -292.0), Vector3(-523.0, y, -240.0), Vector3(1, 0, 0), 10],
		[Vector3(-508.0, y, -258.0), Vector3(-488.0, y, -258.0), Vector3(0.3, 0, 1), 5],
	]
	for g in groups:
		var a: Vector3 = g[0]
		var b: Vector3 = g[1]
		var face: Vector3 = (g[2] as Vector3).normalized()
		for i in range(int(g[3])):
			var t: float = (float(i) + rng.randf_range(0.1, 0.9)) / float(g[3])
			var p: Vector3 = a.lerp(b, t) + face * rng.randf_range(-1.0, 1.0)
			if _lap_dist(p.x, p.z) < ROAD_HALF + 3.0:
				continue
			var f: Vector3 = (face + Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))).normalized()
			_people.append([Vector3(p.x, y, p.z), f, false, false, -1, rng.randf_range(0.85, 1.06)])
	# At the town gate, outside, on the verges.
	var s_tg: float = _closest_s(TOWN_GATE)
	for side in [-1.0, 1.0]:
		for k in range(5):
			var sp: Dictionary = _spot(s_tg - 34.0 - float(k) * 3.5, side * (ROAD_HALF + PAVEMENT + 1.5 + rng.randf_range(0.0, 2.0)), 0.0)
			var p2: Vector3 = sp["pos"]
			p2.y = maxf(_ground_at(p2.x, p2.z), _lap_y(s_tg - 34.0) - 0.05)
			if _occupied(p2.x, p2.z):
				continue
			_people.append([p2, -(sp["right"] as Vector3) * side, false, false, -1, rng.randf_range(0.85, 1.06)])
	print("  town people: %d" % (_people.size() - before))



## The weekly market (Wochenmarkt) on the square's west side, between the fountain and the Rathaus: CampKit's gazebos in
## white and red-and-white over folding tables of crates, shoppers between them. Away from the racing line.
const MARKET_STALLS := [Vector2(-530.0, -298.0), Vector2(-530.0, -286.0), Vector2(-530.0, -248.0), Vector2(-530.0, -236.0),
	Vector2(-516.0, -298.0), Vector2(-516.0, -236.0)]

func _build_weekly_market(root: Node3D) -> void:
	var pk := PropKit.new()
	pk.material_for = func(key: String) -> Material: return _camp_material(key)
	var camp := CampKit.new(pk)
	var kit := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 2211
	var y: float = _markt_y
	var produce := [Color(0.85, 0.20, 0.12), Color(0.95, 0.70, 0.10), Color(0.35, 0.60, 0.18), Color(0.55, 0.30, 0.55), Color(0.92, 0.85, 0.70)]
	for i in range(MARKET_STALLS.size()):
		var c: Vector2 = MARKET_STALLS[i]
		var xf := _facing(Vector3(1, 0, 0), Vector3(c.x, y, c.y))
		pk.set_frame(xf.scaled_local(Vector3.ONE * PROP_SCALE))
		camp.gazebo(kit, Color(0.95, 0.95, 0.93) if i % 2 == 0 else Color(0.82, 0.12, 0.10), false)
		pk.set_frame(Transform3D(xf.basis * Basis.from_scale(Vector3.ONE * PROP_SCALE), xf.origin + xf.basis.z * 0.6))
		camp.folding_table(kit, Color(0.92, 0.90, 0.86))
		# Crates of produce on the table.
		for k in range(4):
			var cx: float = -0.75 + 0.5 * float(k)
			pk.block(kit, "wood", Vector3(cx - 0.2, 0.74, -0.25), Vector3(cx + 0.2, 0.92, 0.15), Color(0.58, 0.44, 0.28))
			pk.block(kit, "paint", Vector3(cx - 0.17, 0.92, -0.22), Vector3(cx + 0.17, 0.98, 0.12), produce[rng.randi_range(0, produce.size() - 1)])
		_note_rect(c, 6.0, 6.0, 0.0, 0.2)
		# A shopper or two in front.
		for k in range(rng.randi_range(1, 2)):
			var pp := Vector3(c.x + 4.2 + rng.randf_range(0.0, 1.5), y, c.y + rng.randf_range(-2.0, 2.0))
			_people.append([pp, Vector3(-1, 0, rng.randf_range(-0.3, 0.3)).normalized(), false, false, -1, rng.randf_range(0.85, 1.05)])
	pk.reset_frame()
	var mi := MeshInstance3D.new()
	mi.name = "Wochenmarkt"
	mi.mesh = _save_res(pk.commit(kit), "weekly_market", PROP_PREFIX)
	mi.visibility_range_end = 600.0
	root.add_child(mi)



## The estate's back street, south of the climb: asphalt with kerbs and flags (kind 2, off the lap), terraces either side.
const ESTATE_STREETS := [[Vector2(30.0, -83.0), Vector2(-168.0, -133.0)]]
const ESTATE_STREET_HALF := 3.6
const ESTATE_STREET_PAVE := 2.0

func _estate_streets(rng: RandomNumberGenerator) -> int:
	var n := 0
	var node := Node3D.new()
	node.name = "EstateStreets"
	level.add_child(node)
	var si := 0
	for st_def in ESTATE_STREETS:
		var a: Vector2 = st_def[0]
		var b: Vector2 = st_def[1]
		var dir: Vector2 = (b - a).normalized()
		var right := Vector2(-dir.y, dir.x)
		var length: float = a.distance_to(b)
		var w: float = ESTATE_STREET_HALF + ESTATE_STREET_PAVE
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var steps: int = ceili(length / 2.0)
		var lats := [-w, -ESTATE_STREET_HALF, 0.0, ESTATE_STREET_HALF, w]
		for i in range(steps):
			for j in range(lats.size() - 1):
				var q: Array = []
				for c in [[i, j], [i, j + 1], [i + 1, j], [i + 1, j + 1]]:
					var t: float = float(c[0]) / float(steps) * length
					var l: float = lats[c[1]]
					var p2: Vector2 = a + dir * t + right * l
					q.append([Vector3(p2.x, _ground_at(p2.x, p2.y) + 0.06, p2.y), Vector2(l, t)])
				for tri in [[0, 2, 1], [1, 2, 3]]:
					var p0: Vector3 = q[tri[0]][0]
					var nrm: Vector3 = (q[tri[2]][0] - p0).cross(q[tri[1]][0] - p0).normalized()
					if nrm.y < 0.0:
						nrm = -nrm
					for k in tri:
						st.set_normal(nrm)
						st.set_color(Color(1, 0, 0, 1))
						st.set_uv(q[k][1])
						st.set_uv2(Vector2(2.0, ESTATE_STREET_HALF))
						st.add_vertex(q[k][0])
		var mesh: ArrayMesh = st.commit()
		mesh.surface_set_material(0, _road_mat)
		var mi := MeshInstance3D.new()
		mi.name = "Siedlungsstrasse_%d" % si
		mi.mesh = _save_res(mesh, "estate_street_%d" % si, "kronburgroad_")
		mi.visibility_range_end = 900.0
		node.add_child(mi)
		for side in [-1.0, 1.0]:
			var face := Vector3(-right.x * side, 0.0, -right.y * side)
			var off: Vector2 = right * side * (w + 0.2)
			var along := 8.0
			while along < length - 8.0:
				var units: int = 4 if rng.randf() < 0.5 else 2
				var tw: float = float(units) * 7.0 * PROP_SCALE
				if along + tw > length - 6.0:
					break
				var mid2: Vector2 = a + dir * (along + tw * 0.5) + off
				var front := Vector3(mid2.x, _ground_at(mid2.x, mid2.y) + 0.05, mid2.y)
				var xf: Transform3D = _facing(face, front)
				xf.origin -= xf.basis.x * (tw * 0.5)
				var d: float = 22.0 * PROP_SCALE
				if _clear(front - face * (d * 0.5), xf.basis.x, tw, d):
					var variant: int = rng.randi_range(0, 7)
					var seed_v: int = rng.randi()
					var u := units
					_add_prop(_cell_key("estate", front), _town, xf, func(pk, kit, _labels):
						var hr := RandomNumberGenerator.new()
						hr.seed = seed_v
						_kit_call(_town, "brick_terrace", [pk, kit, u, variant, hr]))
					_note_xf(xf, 0.0, tw, -d, 0.0, 0.3)
					n += 1
				along += tw + rng.randf_range(8.0, 13.0)
		_note_rect((a + b) * 0.5, w * 2.0, length, atan2(-right.y, right.x), 0.0)
		si += 1
	return n



# --------------------------------------------------------------------------------------
#  Filling the works' pad: the steel shop (a shorter hall), more stockpiles, pipe runs on their racks, the car park
# --------------------------------------------------------------------------------------

## The ore yard south of the mill's exit: [centre]. Its bridge's rails run along z.
const ORE_YARD := Vector2(452.0, 192.0)
const WORKS_PILES := [[Vector2(610.0, 200.0), 40.0, 18.0, 9.0, true],
	[Vector2(120.0, -220.0), 50.0, 20.0, 8.0, false], [Vector2(592.0, -202.0), 36.0, 18.0, 7.0, true]]
const CAR_PARK := [Vector2(70.0, 130.0), Vector2(144.0, 245.0)]

func _build_works_fill() -> void:
	# The ore yard: an ore bridge over two long stockpiles (iron ore and coal), their length along z.
	_add_prop("works_oreyard", _works, _works_xf(ORE_YARD, Vector3(0, 0, 1)), func(pk, kit, _labels): _kit_call(_works, "ore_crane", [pk, kit]))
	for k in range(2):
		var pc := Vector2(ORE_YARD.x - 20.0 + 42.0 * float(k), ORE_YARD.y)
		var coal_pile: bool = k == 1
		_add_prop("works_stockpiles", _works, _works_xf(pc, Vector3(1, 0, 0)), func(pk, kit, _labels): _kit_call(_works, "stockpile", [pk, kit, 56.0, 19.0, 9.0, coal_pile]))
		_note_rect(pc, 34.0, 94.0, 0.0)
	_note_rect(ORE_YARD, 110.0, 100.0, 0.0)
	for wp in WORKS_PILES:
		var at: Vector2 = wp[0]
		var l: float = wp[1]
		var w: float = wp[2]
		var h: float = wp[3]
		var coal: bool = wp[4]
		_add_prop("works_stockpiles", _works, _works_xf(at, Vector3(0, 0, 1)), func(pk, kit, _labels): _kit_call(_works, "stockpile", [pk, kit, l, w, h, coal]))
		_note_rect(at, l * PROP_SCALE + 4.0, w * PROP_SCALE + 4.0, 0.0)
	# Pipe runs on racks along the north road's south side and up the east side of the pad.
	var runs: Array = [
		[Vector3(150.0, 6.0, -126.0), Vector3(228.0, 6.0, -126.0)],
		[Vector3(264.0, 6.0, -126.0), Vector3(372.0, 6.0, -126.0), Vector3(372.0, 6.0, -112.0)],
		[Vector3(548.0, 5.0, -88.0), Vector3(548.0, 5.0, 20.0)],
	]
	for r in runs:
		var pts := PackedVector3Array()
		for p in r:
			pts.append(Vector3(p.x, p.y, p.z) / PROP_SCALE)
		_add_prop("works_piperuns", _works, Transform3D(Basis(), Vector3(0, WORKS_Y, 0)), func(pk, kit, _labels): _kit_call(_works, "pipe_run", [pk, kit, pts, 0.7]))
		for i in range(r.size() - 1):
			var a: Vector3 = r[i]
			var b: Vector3 = r[i + 1]
			var c := Vector2((a.x + b.x) * 0.5, (a.z + b.z) * 0.5)
			_note_rect(c, absf(b.x - a.x) + 4.0, absf(b.z - a.z) + 4.0, 0.0)
	_build_car_park()


## The works' car park by the gate: rows of the shift's cars (CampKit's SUVs and vans), one MultiMesh per model and colour
## (merged, 146 detailed cars made a 34MB mesh).
func _build_car_park() -> void:
	var pk := PropKit.new()
	pk.material_for = func(key: String) -> Material: return _camp_material(key)
	var camp := CampKit.new(pk)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6161
	var paints := [Color(0.85, 0.85, 0.86), Color(0.10, 0.11, 0.13), Color(0.45, 0.47, 0.50), Color(0.62, 0.10, 0.10), Color(0.15, 0.25, 0.45),
		Color(0.78, 0.78, 0.74), Color(0.30, 0.32, 0.30)]
	var groups := {}
	var x0: float = CAR_PARK[0].x
	var x1: float = CAR_PARK[1].x
	var z: float = CAR_PARK[0].y
	var cars := 0
	var row := 0
	while z < CAR_PARK[1].y:
		var x: float = x0
		while x < x1:
			if rng.randf() < 0.78:
				var face := Vector3(0, 0, 1) if row % 2 == 0 else Vector3(0, 0, -1)
				var key := "%s_%d" % ["van" if rng.randf() < 0.18 else "suv", rng.randi_range(0, paints.size() - 1)]
				if not groups.has(key):
					groups[key] = []
				groups[key].append(_facing(face, Vector3(x, WORKS_Y + 0.02, z)))
				cars += 1
			x += 4.4
		z += 13.0 if row % 2 == 0 else 9.0
		row += 1
	var node := Node3D.new()
	node.name = "Werksparkplatz"
	level.add_child(node)
	for key in groups.keys():
		var parts: PackedStringArray = String(key).split("_")
		var kit := {}
		pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * PROP_SCALE), Vector3.ZERO))
		camp.vehicle(kit, parts[0], paints[int(parts[1])])
		var mesh: Mesh = _save_res(pk.commit(kit), "carpark_" + String(key), PROP_PREFIX)
		var mmi := _multimesh(node, "Cars_" + String(key), mesh, groups[key], 700.0, true)
		mmi.visibility_range_end_margin = 40.0
	_note_rect((CAR_PARK[0] + CAR_PARK[1]) * 0.5, CAR_PARK[1].x - CAR_PARK[0].x, CAR_PARK[1].y - CAR_PARK[0].y, 0.0)
	print("  works car park: %d cars in %d models" % [cars, groups.size()])
