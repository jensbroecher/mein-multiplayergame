# regenerate_freight_line.gd
#
# Builds levels/FreightLevel.tscn - Freight Line, third stage of the Sierra del Viento GP: a high-desert
# railroad plain at midday, with two railways crossing the lap.
#
# The lap is a closed loop of straights and arcs (LAP: corner points and radii, filleted) round a plain
# of dry grass and hardpan. A freight line (the Main Line) runs east-west through the middle of it and
# crosses the lap twice, on its east side and on its west; a branch line comes down from the north,
# crosses the top of the lap once, and ends in a hill inside it. Trains (Train.gd) run on the wall clock;
# a cart that touches one is destroyed. At the level crossings (RailCrossing.gd) barriers come down and
# the lights flash a few seconds ahead. See the notes on the three crossings in CROSSINGS below.
#
# Things worth knowing before editing this file:
#
# 1. There is no road mesh: the ground is graded flat under the road (and under the railways) and
#    canyon_ground.gdshader paints the tarmac, as on the Canyon Course. Heights come from `_plain` (the
#    gentle rolling plain), the hills at the railways' ends and the far ranges. The road's height and the
#    rails' are `_plain` smoothed along each, and where they cross the rail takes the road's height, so
#    the crossing is dead flat.
#
# 2. The railways are built from the same samples as the road (`_add_samples`): `_grade` clamps the ground
#    between every nearby sample's fill and cut bounds. Samples belong to a line (`_rs_next` chains them
#    and ends each line), and only road samples paint the tarmac.
#
# The menu tile (images/menu/tile_freight_line.jpg) is a render of this level; the generator runs
# headless and cannot render (scratch/lap_shots.tscn renders the lap).
extends Node

const LEVEL_NAME := "FreightLevel"
const LEVEL_PATH := "res://levels/FreightLevel.tscn"
const RES_PREFIX := "freight_"
const MeshChunker = preload("res://MeshChunker.gd")
const FreightKit = preload("res://FreightKit.gd")
const TrainKit = preload("res://TrainKit.gd")
const CactusKit = preload("res://CactusKit.gd")
const PropKit = preload("res://PropKit.gd")

const MESH_CHUNK_CELL := 80.0

## Painted road half width (the shader's road_half_width) and how wide the road's collision body is.
const ROAD_HALF := 7.0
const ROAD_COLLIDE := 7.9
## Half width of the strip graded flat to road height, and the rise per metre of a cutting and the drop
## per metre of a fill beside it.
const ROAD_FLAT := 8.8
const ROAD_CUT := 0.9
const ROAD_FILL := 0.6
## The same for a railway: a bed 6m either side of the rail line, gentler banks.
const RAIL_FLAT := 6.0
const RAIL_CUT := 0.7
const RAIL_FILL := 0.5
const GRADE_REACH := 30.0
const CELL := 32.0
const SAMPLE_STEP := 3.0
## The heights the lines follow are `_plain` averaged over this many metres either side.
const SMOOTH_REACH := 75.0

## The lap: corner points and radii (x east, z south). Closed; s = 0 is where the first corner's arc ends,
## on the start straight. Everything turns left except the S in the north-east and the north-west bend.
const LAP := [
	[-500.0, 250.0, 90.0],    # 0 bottom-left, onto the start straight
	[300.0, 250.0, 120.0],    # 1 bottom-right
	[520.0, 130.0, 120.0],    # 2 the east side
	[520.0, -140.0, 100.0],   # 3 north on the straight with the Main Line's east crossing
	[390.0, -330.0, 110.0],   # 4
	[80.0, -290.0, 130.0],    # 5 a right-hander on the top, over the Branch's crossing
	[-260.0, -390.0, 100.0],  # 6
	[-500.0, -210.0, 100.0],  # 7
]
## The railways: straight lines [x0, z0, x1, z1] from where they come out of the hills to where they go
## into them. Trains run from the first point to the second.
const RAILS := [
	{"name": "MainLine", "a": Vector2(-860.0, 0.0), "b": Vector2(860.0, 0.0), "speed": 30.0, "period": 70.0,
		"consist": ["loco", "box", "box:1", "flat", "flat", "gap:20", "tank", "tank:1", "box:2", "box", "flat_load", "flat_load", "caboose"]},
	{"name": "BranchLine", "a": Vector2(210.0, -850.0), "b": Vector2(210.0, -60.0), "speed": 24.0, "period": 48.0, "phase": 17.0, "kicker": 1,
		"consist": ["loco", "flat_load", "flat", "flat", "flat", "flat", "flat_load", "caboose"]},
]
## The hills the railways run into: centre x, z, radius, height.
const HILLS := [
	[-880.0, 0.0, 110.0, 36.0],
	[880.0, 0.0, 110.0, 36.0],
	[210.0, -880.0, 100.0, 34.0],
	[210.0, -50.0, 90.0, 30.0],
]

## Terrain grid: fine round the lap and the railways, cells growing outward to the horizon.
const FINE_X := Vector2(-1050.0, 1050.0)
const FINE_Z := Vector2(-1000.0, 420.0)
const FINE_STEP := 5.0
const OUTER_X := Vector2(-6000.0, 6000.0)
const OUTER_Z := Vector2(-6000.0, 6000.0)
const COARSE_GROWTH := 1.16
const COARSE_MAX := 160.0
const CENTRE := Vector2(0.0, -150.0)

const FINISH_S := 160.0

## Level pads for the depot: centre x, z, half length (x), half width (z), the blend over which the ground
## eases back, and the pad's height (set from the plain's mean under it by _plan_pads).
var _pads: Array = [
	{"c": Vector2(-215.0, 192.0), "half": Vector2(135.0, 38.0), "blend": 16.0, "h": 0.0},
]

var _lap: Dictionary = {}
var _rails: Array = []
## Where a railway crosses the lap: {rail, lap_s, rail_s, pos (Vector2), road_y}.
var _crossings: Array = []
var main_curve: Curve3D

var _base_noise := FastNoiseLite.new()
var _detail_noise := FastNoiseLite.new()
var _far_noise := FastNoiseLite.new()
var _hill_noise := FastNoiseLite.new()

# Samples along the lap and every railway, every SAMPLE_STEP metres.
var _rs_pos := PackedVector3Array()
var _rs_right := PackedVector3Array()
var _rs_s := PackedFloat32Array()
var _rs_next := PackedInt32Array()    # the next sample on the line, -1 at its end
var _rs_kind := PackedByteArray()     # 0 the road, 1 a railway
var _rs_cut := PackedFloat32Array()
var _rs_flat := PackedFloat32Array()
var _rs_fill := PackedFloat32Array()
var _rs_cells := {}
var _road_cells := {}
var _road_y := PackedFloat32Array()   # the lap's height at each of its samples
var _road_n := 0

var _grid_x := PackedFloat32Array()
var _grid_z := PackedFloat32Array()
var _heights := PackedFloat32Array()
var _road_d := PackedFloat32Array()
var _vert_lat := PackedFloat32Array()
var _vert_s := PackedFloat32Array()
var _ground_mat: ShaderMaterial


# ======================================================================================
#  Paths
# ======================================================================================

func _right_of(th: float) -> Vector2:
	return Vector2(-sin(th), cos(th))


func _dir_of(th: float) -> Vector2:
	return Vector2(cos(th), sin(th))


## A closed path through the LAP corners: straights joined by arcs of each corner's radius.
func _fillet(corners: Array) -> Dictionary:
	var n: int = corners.size()
	var a_in: Array = []
	var a_out: Array = []
	var arcs: Array = []
	for i in range(n):
		var b := Vector2(corners[i][0], corners[i][1])
		var r: float = corners[i][2]
		var a := Vector2(corners[(i - 1 + n) % n][0], corners[(i - 1 + n) % n][1])
		var c := Vector2(corners[(i + 1) % n][0], corners[(i + 1) % n][1])
		var d1: Vector2 = (b - a).normalized()
		var d2: Vector2 = (c - b).normalized()
		var ang: float = atan2(d1.x * d2.y - d1.y * d2.x, d1.dot(d2))
		var t: float = r * tan(absf(ang) * 0.5)
		if t > b.distance_to(a) * 0.5 + 0.01 or t > b.distance_to(c) * 0.5 + 0.01:
			push_error("LAP: corner %d's radius %.0f does not fit" % [i, r])
		a_in.append(b - d1 * t)
		a_out.append(b + d2 * t)
		if absf(ang) < 0.0001 or r <= 0.0:
			arcs.append(null)
		else:
			arcs.append({"kind": "A", "p0": b - d1 * t, "th0": atan2(d1.y, d1.x), "r": r, "sign": signf(ang), "len": r * absf(ang)})
	var segs: Array = []
	var s := 0.0
	var prev: Vector2 = a_out[0]
	for k in range(1, n + 1):
		var i: int = k % n
		var p_in: Vector2 = a_in[i]
		var length: float = prev.distance_to(p_in)
		if length > 0.001:
			var d: Vector2 = (p_in - prev) / length
			segs.append({"kind": "S", "p0": prev, "th0": atan2(d.y, d.x), "len": length, "s0": s})
			s += length
		if arcs[i] != null:
			var arc: Dictionary = (arcs[i] as Dictionary).duplicate()
			arc["s0"] = s
			segs.append(arc)
			s += float(arc["len"])
		prev = a_out[i]
	return {"segs": segs, "len": s}


## Position and heading on the lap at `s` (wrapped).
func _lap_at(s: float) -> Dictionary:
	var length: float = _lap["len"]
	s = fposmod(s, length)
	var segs: Array = _lap["segs"]
	var seg: Dictionary = segs[0]
	for i in range(segs.size() - 1, -1, -1):
		if s >= float(segs[i]["s0"]) - 0.0001:
			seg = segs[i]
			break
	var d: float = s - float(seg["s0"])
	var p0: Vector2 = seg["p0"]
	var th0: float = seg["th0"]
	if seg["kind"] == "S":
		return {"p": p0 + _dir_of(th0) * d, "th": th0}
	var r: float = seg["r"]
	var sgn: float = seg["sign"]
	var c: Vector2 = p0 + _right_of(th0) * r * sgn
	var th: float = th0 + sgn * d / r
	return {"p": c - _right_of(th) * r * sgn, "th": th}


func _rail_len(i: int) -> float:
	return (_rails[i]["b"] as Vector2).distance_to(_rails[i]["a"])


func _rail_at(i: int, s: float) -> Vector2:
	var a: Vector2 = _rails[i]["a"]
	var b: Vector2 = _rails[i]["b"]
	return a + (b - a).normalized() * clampf(s, 0.0, a.distance_to(b))


## Whether a point is inside one of the hills the railways run into (their tunnel mouths lie at HILL_PORTAL of
## its radius): there the line is not graded and has no track, and the trains run on underground.
const HILL_PORTAL := 0.85

func _in_hill(p: Vector2) -> bool:
	for hl in HILLS:
		if p.distance_to(Vector2(hl[0], hl[1])) < float(hl[2]) * HILL_PORTAL:
			return true
	return false


## Distance from `p` to the nearest tunnel mouth (the hills' portal circles).
func _portal_distance(p: Vector2) -> float:
	var best := 1e9
	for hl in HILLS:
		best = minf(best, p.distance_to(Vector2(hl[0], hl[1])) - float(hl[2]) * HILL_PORTAL)
	return best


## How far a rail's top stands over the ground it is graded to: a few centimetres over a crossing, so the
## rails are flush with the road, and the full height of a bed (ballast under the sleepers) 24m away.
const RAIL_LIFT_CROSSING := 0.10
const RAIL_LIFT := 0.60

func _rail_lift(ri: int, s: float) -> float:
	var d := 1e9
	for c in _crossings:
		if int(c["rail"]) == ri:
			d = minf(d, absf(s - float(c["rail_s"])))
	return lerpf(RAIL_LIFT_CROSSING, RAIL_LIFT, smoothstep(9.5, 24.0, d))


# ======================================================================================
#  Landscape
# ======================================================================================

func _init_noise() -> void:
	_base_noise.seed = 3107
	_base_noise.frequency = 0.0032
	_base_noise.fractal_octaves = 3
	_detail_noise.seed = 811
	_detail_noise.frequency = 0.02
	_detail_noise.fractal_octaves = 2
	_far_noise.seed = 4409
	_far_noise.frequency = 0.0009
	_far_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_far_noise.fractal_octaves = 4
	_hill_noise.seed = 91
	_hill_noise.frequency = 0.018
	_hill_noise.fractal_octaves = 3


## The rolling plain the lines follow: a few metres of gentle swell.
func _plain(x: float, z: float) -> float:
	return 4.0 + _base_noise.get_noise_2d(x, z) * 4.5 + _detail_noise.get_noise_2d(x, z) * 0.25


## The hills the railways run into: steep-sided buttes, their rims ragged.
func _hills(x: float, z: float) -> float:
	var h := 0.0
	for hl in HILLS:
		var dx: float = x - float(hl[0])
		var dz: float = z - float(hl[1])
		var d: float = sqrt(dx * dx + dz * dz)
		if d > float(hl[2]) * 1.6:
			continue
		var r: float = float(hl[2]) * (1.0 + _hill_noise.get_noise_2d(x, z) * 0.22)
		var t: float = 1.0 - smoothstep(r * 0.55, r, d)
		h = maxf(h, float(hl[3]) * t * (0.92 + 0.08 * _hill_noise.get_noise_2d(x * 2.0, z * 2.0)))
	return h


## Mesas and ranges on the horizon, from 1.3km out.
func _far(x: float, z: float) -> float:
	var d: float = Vector2(x, z).distance_to(CENTRE)
	var t: float = smoothstep(1250.0, 2600.0, d)
	if t <= 0.0:
		return 0.0
	var ridge: float = (_far_noise.get_noise_2d(x, z) + 1.0) * 0.5
	# Flat-topped: the ridged noise clipped, so the far country is mesas, not cones.
	var mesa: float = smoothstep(0.38, 0.62, ridge)
	var top: float = lerpf(0.55, 1.0, smoothstep(0.62, 0.75, ridge))
	return t * (mesa * top * 240.0 + ridge * 40.0)


func _base_height(x: float, z: float) -> float:
	return _plain(x, z) + _hills(x, z) + _far(x, z)


# ======================================================================================
#  The lap and the railways
# ======================================================================================

func _smooth_along(values: PackedFloat32Array, closed: bool, reach_samples: int) -> PackedFloat32Array:
	var n: int = values.size()
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		var sum := 0.0
		var cnt := 0
		for k in range(-reach_samples, reach_samples + 1):
			var j: int = i + k
			if closed:
				j = posmod(j, n)
			elif j < 0 or j >= n:
				continue
			sum += values[j]
			cnt += 1
		out[i] = sum / float(maxi(cnt, 1))
	return out


func _build_lines() -> void:
	_lap = _fillet(LAP)
	_rails = []
	for r in RAILS:
		_rails.append(r)
	print("  lap %.0fm, %d segments" % [_lap["len"], (_lap["segs"] as Array).size()])
	# The road's height: the plain, smoothed round the lap.
	_road_n = int(floor(float(_lap["len"]) / SAMPLE_STEP))
	var raw := PackedFloat32Array()
	raw.resize(_road_n)
	for k in range(_road_n):
		var p: Vector2 = _lap_at(float(k) * SAMPLE_STEP)["p"]
		raw[k] = _plain(p.x, p.y)
	_road_y = _smooth_along(raw, true, int(SMOOTH_REACH / SAMPLE_STEP))
	_find_crossings()


## Where each railway crosses the lap: the lap's samples against the rail's line, the sign of the side
## they lie on changing.
func _find_crossings() -> void:
	_crossings.clear()
	for ri in range(_rails.size()):
		var a: Vector2 = _rails[ri]["a"]
		var dir: Vector2 = (_rails[ri]["b"] - a).normalized()
		var prev_side := 0.0
		var prev_p := Vector2.ZERO
		var prev_s := 0.0
		for k in range(_road_n + 1):
			var s: float = float(k) * SAMPLE_STEP
			var p: Vector2 = _lap_at(s)["p"]
			var side: float = dir.x * (p.y - a.y) - dir.y * (p.x - a.x)
			if k > 0 and prev_side * side < 0.0:
				var f: float = absf(prev_side) / (absf(prev_side) + absf(side))
				var q: Vector2 = prev_p.lerp(p, f)
				var along: float = (q - a).dot(dir)
				if along > 0.0 and along < _rail_len(ri):
					var ls: float = lerpf(prev_s, s, f)
					_crossings.append({"rail": ri, "lap_s": ls, "rail_s": along, "pos": q, "road_y": _road_height_at_s(ls)})
			prev_side = side
			prev_p = p
			prev_s = s
	_crossings.sort_custom(func(x, y): return float(x["lap_s"]) < float(y["lap_s"]))
	for c in _crossings:
		print("  crossing: %s at lap %.0fm, rail %.0fm, (%.0f, %.0f)" % [_rails[c["rail"]]["name"], c["lap_s"], c["rail_s"], c["pos"].x, c["pos"].y])


func _road_height_at_s(s: float) -> float:
	var f: float = fposmod(s, float(_lap["len"])) / SAMPLE_STEP
	var i: int = int(floor(f)) % _road_n
	var j: int = (i + 1) % _road_n
	return lerpf(_road_y[i], _road_y[j], f - floor(f))


## The height of a rail at `s`: the plain smoothed along the rail, taking the road's height within 14m of a
## crossing and easing back to the plain over 46m more, so the crossing is flat.
func _rail_height(ri: int, s: float) -> float:
	var sum := 0.0
	var cnt := 0
	var k := -SMOOTH_REACH
	while k <= SMOOTH_REACH:
		var p: Vector2 = _rail_at(ri, s + k)
		sum += _plain(p.x, p.y)
		cnt += 1
		k += SAMPLE_STEP
	var h: float = sum / float(cnt)
	for c in _crossings:
		if int(c["rail"]) != ri:
			continue
		var d: float = absf(s - float(c["rail_s"]))
		var w: float = smoothstep(14.0, 60.0, d)
		h = lerpf(float(c["road_y"]), h, w) if d < 60.0 else h
	return h


# ======================================================================================
#  Samples and grading
# ======================================================================================

func _plan_pads() -> void:
	for pd in _pads:
		var c: Vector2 = pd["c"]
		var half: Vector2 = pd["half"]
		var sum := 0.0
		var cnt := 0
		var x := -half.x
		while x <= half.x:
			var z := -half.y
			while z <= half.y:
				sum += _plain(c.x + x, c.y + z)
				cnt += 1
				z += 8.0
			x += 8.0
		pd["h"] = sum / float(cnt)


## The pad weight (1 on the pad, easing to 0 over its blend) and its height at (x, z).
func _pad_at(x: float, z: float) -> Vector2:
	for pd in _pads:
		var c: Vector2 = pd["c"]
		var half: Vector2 = pd["half"]
		var dx: float = absf(x - c.x) - half.x
		var dz: float = absf(z - c.y) - half.y
		var out: float = Vector2(maxf(dx, 0.0), maxf(dz, 0.0)).length()
		var blend: float = pd["blend"]
		if out < blend:
			return Vector2(1.0 - smoothstep(0.0, blend, out), pd["h"])
	return Vector2(0.0, 0.0)


func _add_samples() -> void:
	_rs_pos = PackedVector3Array()
	_rs_right = PackedVector3Array()
	_rs_s = PackedFloat32Array()
	_rs_next = PackedInt32Array()
	_rs_kind = PackedByteArray()
	_rs_cut = PackedFloat32Array()
	_rs_flat = PackedFloat32Array()
	_rs_fill = PackedFloat32Array()
	_rs_cells.clear()
	_road_cells.clear()
	for k in range(_road_n):
		var s: float = float(k) * SAMPLE_STEP
		var pa: Dictionary = _lap_at(s)
		var p2: Vector2 = pa["p"]
		var r2: Vector2 = _right_of(float(pa["th"]))
		_push_sample(Vector3(p2.x, _road_y[k], p2.y), Vector3(r2.x, 0.0, r2.y), s, 0, ROAD_FLAT, ROAD_CUT, ROAD_FILL,
				(k + 1) % _road_n + 0, true)
	var base: int = _rs_pos.size()
	for ri in range(_rails.size()):
		var n: int = int(floor(_rail_len(ri) / SAMPLE_STEP)) + 1
		var a: Vector2 = _rails[ri]["a"]
		var dir: Vector2 = (_rails[ri]["b"] - a).normalized()
		var right := Vector3(-dir.y, 0.0, dir.x)
		var first: int = _rs_pos.size()
		var inside: Array = []
		for k in range(n):
			inside.append(_in_hill(_rail_at(ri, minf(float(k) * SAMPLE_STEP, _rail_len(ri)))))
		for k in range(n):
			var s: float = minf(float(k) * SAMPLE_STEP, _rail_len(ri))
			var p2: Vector2 = _rail_at(ri, s)
			var link: bool = k < n - 1 and not inside[k] and not inside[k + 1]
			# Within 50m of a tunnel mouth the cutting stands steep, so the portal's wall can close it.
			var cut: float = RAIL_CUT
			var flat: float = RAIL_FLAT
			if _portal_distance(p2) < 50.0:
				cut = 2.8
				flat = 5.4
			_push_sample(Vector3(p2.x, _rail_height(ri, s), p2.y), right, s, 1, flat, cut, RAIL_FILL,
					first + k + 1 if link else -1, false)
	print("  samples: %d on the lap, %d on the rails" % [base, _rs_pos.size() - base])


func _push_sample(pos: Vector3, right: Vector3, s: float, kind: int, flat: float, cut: float, fill: float, next: int, _closed: bool) -> void:
	var idx: int = _rs_pos.size()
	_rs_pos.append(pos)
	_rs_right.append(right)
	_rs_s.append(s)
	_rs_next.append(next)
	_rs_kind.append(kind)
	_rs_cut.append(cut)
	_rs_flat.append(flat)
	_rs_fill.append(fill)
	var key := Vector2i(floori(pos.x / CELL), floori(pos.z / CELL))
	var bucket: PackedInt32Array = _rs_cells.get(key, PackedInt32Array())
	bucket.append(idx)
	_rs_cells[key] = bucket
	if kind == 0:
		var rb: PackedInt32Array = _road_cells.get(key, PackedInt32Array())
		rb.append(idx)
		_road_cells[key] = rb


## Clamps `h` between the fill and cut bounds of every line's segment within reach. Returns the graded
## height and, beside a segment inside its flat strip, that segment's height there (else NAN).
func _grade(h: float, x: float, z: float) -> Vector2:
	var cx: int = floori(x / CELL)
	var cz: int = floori(z / CELL)
	var upper := 1e9
	var lower := -1e9
	var touched := false
	var flat_y := NAN
	var flat_lat := 1e9
	for gz in range(cz - 1, cz + 2):
		for gx in range(cx - 1, cx + 2):
			var bucket: PackedInt32Array = _rs_cells.get(Vector2i(gx, gz), PackedInt32Array())
			for i in bucket:
				var j: int = _rs_next[i]
				if j < 0:
					continue
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
				var foot_y: float = lerpf(a.y, b.y, t)
				var flat: float = _rs_flat[i]
				var over: float = maxf(0.0, lateral - flat)
				# A rounded shoulder, so there is no crease at the edge of the flat strip.
				var soft: float = over * over / (over + 4.0)
				upper = minf(upper, foot_y + soft * _rs_cut[i])
				lower = maxf(lower, foot_y - soft * _rs_fill[i])
				touched = true
				if lateral <= flat and lateral < flat_lat:
					flat_lat = lateral
					flat_y = foot_y
	if not touched:
		return Vector2(h, NAN)
	if lower > upper:
		return Vector2(upper, flat_y)
	return Vector2(clampf(h, lower, upper), flat_y)


## Distance to the nearest road centreline, the signed lateral across it (+ right of travel) and the arc
## length of that sample.
func _road_lat(x: float, z: float) -> Vector3:
	var cx: int = floori(x / CELL)
	var cz: int = floori(z / CELL)
	var best := 1e9
	var lat := 0.0
	var at_s := 0.0
	for gz in range(cz - 1, cz + 2):
		for gx in range(cx - 1, cx + 2):
			var bucket: PackedInt32Array = _road_cells.get(Vector2i(gx, gz), PackedInt32Array())
			for i in bucket:
				var j: int = _rs_next[i]
				if j < 0:
					continue
				var a: Vector3 = _rs_pos[i]
				var b: Vector3 = _rs_pos[j]
				var sx: float = b.x - a.x
				var sz: float = b.z - a.z
				var l2: float = maxf(sx * sx + sz * sz, 1e-6)
				var t: float = clampf(((x - a.x) * sx + (z - a.z) * sz) / l2, 0.0, 1.0)
				var fx: float = x - (a.x + sx * t)
				var fz: float = z - (a.z + sz * t)
				var dd: float = fx * fx + fz * fz
				if dd < best:
					best = dd
					lat = fx * _rs_right[i].x + fz * _rs_right[i].z
					at_s = _rs_s[i] + t * SAMPLE_STEP
	return Vector3(sqrt(best), lat, at_s)


func _grid_axis(fine: Vector2, outer: Vector2) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var left := PackedFloat32Array()
	var step: float = FINE_STEP
	var x: float = fine.x
	while x > outer.x:
		step = minf(step * COARSE_GROWTH, COARSE_MAX)
		x -= step
		left.append(maxf(x, outer.x))
	left.reverse()
	out.append_array(left)
	var n: int = int(round((fine.y - fine.x) / FINE_STEP))
	for i in range(n + 1):
		out.append(fine.x + float(i) * FINE_STEP)
	step = FINE_STEP
	x = fine.y
	while x < outer.y:
		step = minf(step * COARSE_GROWTH, COARSE_MAX)
		x += step
		out.append(minf(x, outer.y))
	return out


func _build_heights() -> void:
	_grid_x = _grid_axis(FINE_X, OUTER_X)
	_grid_z = _grid_axis(FINE_Z, OUTER_Z)
	var nx: int = _grid_x.size()
	var nz: int = _grid_z.size()
	print("  terrain grid %d x %d = %d vertices" % [nx, nz, nx * nz])
	_heights = PackedFloat32Array()
	_heights.resize(nx * nz)
	_road_d = PackedFloat32Array()
	_road_d.resize(nx * nz)
	_vert_lat = PackedFloat32Array()
	_vert_lat.resize(nx * nz)
	_vert_s = PackedFloat32Array()
	_vert_s.resize(nx * nz)
	for iz in range(nz):
		var z: float = _grid_z[iz]
		for ix in range(nx):
			var x: float = _grid_x[ix]
			var i: int = iz * nx + ix
			var near: bool = x > FINE_X.x - 80.0 and x < FINE_X.y + 80.0 and z > FINE_Z.x - 80.0 and z < FINE_Z.y + 80.0
			var h: float = _base_height(x, z)
			if not near:
				_heights[i] = h
				_road_d[i] = 1e9
				continue
			var g: Vector2 = _grade(h, x, z)
			h = g.y if not is_nan(g.y) else g.x
			var pad: Vector2 = _pad_at(x, z)
			if pad.x > 0.0 and is_nan(g.y):
				h = lerpf(h, pad.y, pad.x)
			_heights[i] = h
			var rl: Vector3 = _road_lat(x, z)
			_road_d[i] = rl.x
			_vert_lat[i] = rl.y
			_vert_s[i] = rl.z


## Ground height at any (x, z) from the built heightfield, on the same triangles as the mesh: each cell
## is split along the diagonal joining its closer heights, so this must be too.
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
	if v <= arr[0]:
		return 0
	if v >= arr[arr.size() - 1]:
		return hi
	while lo < hi:
		var mid: int = (lo + hi + 1) >> 1
		if arr[mid] <= v:
			lo = mid
		else:
			hi = mid - 1
	return lo


func _slope_at(x: float, z: float) -> float:
	var gx: float = _ground_at(x + 1.5, z) - _ground_at(x - 1.5, z)
	var gz: float = _ground_at(x, z + 1.5) - _ground_at(x, z - 1.5)
	return Vector2(gx, gz).length() / 3.0


# ======================================================================================
#  Terrain
# ======================================================================================

## The ground's collision bodies: [name, Surfaces.gd surface, dust colour]. The road ends in "Road"
## (PlayerCart counts it as track); the order is the index _ground_kind returns.
const BODIES := [
	["FreightRoad", "asphalt", Color(0, 0, 0, 0)],
	["PlainsGround", "gravel", Color(0.84, 0.70, 0.52, 0.6)],
	["PlainsRockFace", "rock", Color(0.78, 0.60, 0.46, 0.5)],
]


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


## Vertex masks for canyon_ground.gdshader: rock, road band, sand, lateral.
func _terrain_masks(i: int, x: float, z: float, nrm_y: float) -> Color:
	var road_d: float = _road_d[i]
	var band: float = 1.0 - smoothstep(13.0, 15.0, road_d)
	var rock: float = 1.0 - smoothstep(0.62, 0.8, nrm_y)
	rock *= smoothstep(ROAD_HALF + 0.5, ROAD_HALF + 2.0, road_d)
	# Dry washes of pale sand wander over the plain.
	var sand: float = smoothstep(0.35, 0.6, _detail_noise.get_noise_2d(x * 0.12 + 40.0, z * 0.12)) * 0.45 * (1.0 - rock)
	var lat_enc: float = clampf(_vert_lat[i] / 24.0 + 0.5, 0.0, 1.0) if road_d < 1000.0 else 1.0
	return Color(rock, band, sand, lat_enc)


func _ground_kind(tri: Array) -> int:
	var d_sum := 0.0
	var rock := 0.0
	for v in tri:
		d_sum += _road_d[v]
		rock += _vert_rock[v]
	# On the road when the triangle's mean distance from the centreline is inside the paint (the grid is
	# 4m, so judged by the corners the road's edge would lag the painted one).
	if d_sum / 3.0 < ROAD_HALF - 0.2:
		return 0
	return 2 if rock > 1.8 else 1


var _vert_rock := PackedFloat32Array()


## Terrain mesh with the shader masks in the vertex colour and the road data in UV2, and its collision
## split by surface into BODIES.
func _build_terrain(parent: Node, mat: Material) -> void:
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
	_vert_rock = PackedFloat32Array()
	_vert_rock.resize(nx * nz)
	for iz in range(nz):
		for ix in range(nx):
			var i: int = iz * nx + ix
			var x: float = _grid_x[ix]
			var z: float = _grid_z[iz]
			var h: float = _heights[i]
			verts[i] = Vector3(x, h, z)
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
				colors[i] = _terrain_masks(i, x, z, nrm.y)
				uv2s[i] = Vector2(_vert_s[i], 1.0)
			else:
				colors[i] = Color(1.0 - smoothstep(0.62, 0.8, nrm.y), 0.0, 0.0, 0.5)
			_vert_rock[i] = colors[i].r
	var indices := PackedInt32Array()
	var faces: Array = []
	for b in BODIES:
		faces.append(PackedVector3Array())
	var counts: Array = []
	counts.resize(BODIES.size())
	counts.fill(0)
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
				# Front faces wind clockwise seen from above (CLAUDE.md).
				var p0: Vector3 = verts[tri[0]]
				var p1: Vector3 = verts[tri[1]]
				var p2: Vector3 = verts[tri[2]]
				if (p2 - p0).cross(p1 - p0).y < 0.0:
					tri = [tri[0], tri[2], tri[1]]
					p1 = verts[tri[1]]
					p2 = verts[tri[2]]
				indices.append(tri[0])
				indices.append(tri[1])
				indices.append(tri[2])
				var k: int = _ground_kind(tri) if _road_d[tri[0]] < 1e8 else 1
				var f: PackedVector3Array = faces[k]
				f.append(p0)
				f.append(p1)
				f.append(p2)
				faces[k] = f
				counts[k] += 1
	# The fine grid, which MeshChunker cuts into cells, and the coarse land out to the horizon as one
	# mesh of its own.
	var near_idx := PackedInt32Array()
	var far_idx := PackedInt32Array()
	for t in range(0, indices.size(), 3):
		var far := false
		for k in range(3):
			var v: Vector3 = verts[indices[t + k]]
			if v.x < FINE_X.x or v.x > FINE_X.y or v.z < FINE_Z.x or v.z > FINE_Z.y:
				far = true
		if far:
			far_idx.append_array([indices[t], indices[t + 1], indices[t + 2]])
		else:
			near_idx.append_array([indices[t], indices[t + 1], indices[t + 2]])
	var near_mesh: ArrayMesh = _compact_mesh(verts, normals, colors, uvs, uv2s, near_idx, mat)
	var inst := MeshInstance3D.new()
	inst.name = "PlainsGroundMesh"
	inst.mesh = _save_baked_resource(near_mesh, "ground_visual")
	parent.add_child(inst)
	var far_mesh: ArrayMesh = _compact_mesh(verts, normals, colors, uvs, uv2s, far_idx, mat)
	far_mesh.take_over_path("res://generated/freightfar_ground.res")
	ResourceSaver.save(far_mesh, "res://generated/freightfar_ground.res")
	var far_inst := MeshInstance3D.new()
	far_inst.name = "PlainsFarGround"
	far_inst.mesh = load("res://generated/freightfar_ground.res")
	far_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(far_inst)
	var report := ""
	for k in range(BODIES.size()):
		if counts[k] == 0:
			continue
		var body := StaticBody3D.new()
		body.name = BODIES[k][0]
		body.set_meta(&"surface", BODIES[k][1])
		if (BODIES[k][2] as Color).a > 0.0:
			body.set_meta(&"dust_color", BODIES[k][2])
		parent.add_child(body)
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces[k])
		shape.backface_collision = true
		var cs := CollisionShape3D.new()
		cs.name = "Shape"
		cs.shape = _save_baked_resource(shape, String(BODIES[k][0]).to_snake_case() + "_shape")
		body.add_child(cs)
		report += " %s %d" % [BODIES[k][0], counts[k]]
	print("  ground: %d triangles:%s" % [indices.size() / 3, report])


# ======================================================================================
#  Lap geometry
# ======================================================================================

func _build_main_curve() -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = 0.5
	var n: int = _road_n
	var step: float = float(_lap["len"]) / float(n)
	var pts: Array = []
	for i in range(n):
		var s: float = float(i) * step
		var p2: Vector2 = _lap_at(s)["p"]
		pts.append(Vector3(p2.x, _road_height_at_s(s), p2.y))
	for i in range(n + 1):
		var k: int = i % n
		var a: Vector3 = pts[(k - 1 + n) % n]
		var c: Vector3 = pts[(k + 1) % n]
		var hnd: Vector3 = (c - a) / 6.0
		curve.add_point(pts[k], -hnd, hnd)
	return curve


## A spot on the lap: `lat` metres right of the centreline, `lift` over the road, and the yaw facing the
## way of travel.
func _spot(s: float, lat: float, lift: float) -> Dictionary:
	var pa: Dictionary = _lap_at(s)
	var p2: Vector2 = pa["p"]
	var r2: Vector2 = _right_of(float(pa["th"]))
	var f2: Vector2 = _dir_of(float(pa["th"]))
	var pos := Vector3(p2.x + r2.x * lat, _road_height_at_s(s) + lift, p2.y + r2.y * lat)
	var fwd := Vector3(f2.x, 0.0, f2.y)
	return {"pos": pos, "yaw": rad_to_deg(atan2(-fwd.x, -fwd.z)), "fwd": fwd, "right": Vector3(r2.x, 0.0, r2.y)}


# ======================================================================================
#  The railways, the trains and the crossings
# ======================================================================================

## The track in pieces of this many samples, so culling works along a line.
const TRACK_PIECE := 32
## Half the crossing deck's width across the rails and its half length along them for a road 90 degrees
## to them (it grows with the skew).
const DECK_HALF_W := 3.3
const DECK_HALF_LEN := 8.6

func _rail_top(ri: int, s: float) -> float:
	return _rail_height(ri, s) + _rail_lift(ri, s)


func _build_railways(level_scene: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Railway"
	level_scene.add_child(root)
	for ri in range(_rails.size()):
		var info: Dictionary = _rails[ri]
		var len_r: float = _rail_len(ri)
		var n: int = int(floor(len_r / SAMPLE_STEP)) + 1
		var curve := Curve3D.new()
		curve.bake_interval = 1.0
		var pts: Array = []
		var outside: Array = []
		var s_at: Array = []
		for k in range(n):
			var s: float = minf(float(k) * SAMPLE_STEP, len_r)
			var p: Vector2 = _rail_at(ri, s)
			var v := Vector3(p.x, _rail_top(ri, s), p.y)
			curve.add_point(v)
			pts.append(v)
			outside.append(not _in_hill(p))
			s_at.append(s)
		# Track pieces over every stretch outside the hills.
		var piece: Array = []
		var bed: Array = []
		var piece_no := 0
		for k in range(n):
			if not outside[k]:
				if piece.size() > 1:
					piece_no = _flush_track(root, ri, piece, bed, piece_no)
				piece = []
				bed = []
				continue
			piece.append(pts[k])
			if piece.size() > 1:
				var mid_s: float = (float(s_at[k]) + float(s_at[k - 1])) * 0.5
				bed.append(not _near_crossing(ri, mid_s, DECK_HALF_LEN + 1.5))
			if piece.size() > TRACK_PIECE:
				piece_no = _flush_track(root, ri, piece, bed, piece_no)
				piece = [pts[k]]
				bed = []
		if piece.size() > 1:
			piece_no = _flush_track(root, ri, piece, bed, piece_no)
		# The train.
		var train := Node3D.new()
		train.name = "%sTrain" % info["name"]
		train.set_script(load("res://Train.gd"))
		train.set("path", curve)
		train.set("consist", PackedStringArray(info["consist"]))
		train.set("speed", float(info["speed"]))
		train.set("period", float(info["period"]))
		train.set("phase", float(info.get("phase", 0.0)))
		level_scene.add_child(train)
		print("  %s: %.0fm of line, a train every %.0fs at %.0f m/s" % [info["name"], len_r, float(info["period"]), float(info["speed"])])
	# The crossings.
	var ci := 0
	for c in _crossings:
		ci += 1
		var ri: int = c["rail"]
		var lap_s: float = c["lap_s"]
		var sp: Dictionary = _spot(lap_s, 0.0, 0.0)
		var rail_dir3 := Vector3(_rails[ri]["b"].x - _rails[ri]["a"].x, 0.0, _rails[ri]["b"].y - _rails[ri]["a"].y).normalized()
		var skew: float = maxf(absf(rail_dir3.dot(sp["right"])), 0.5)
		var top_y: float = float(c["road_y"]) + RAIL_LIFT_CROSSING
		var deck := MeshInstance3D.new()
		deck.name = "CrossingDeck%d" % ci
		deck.mesh = _save_baked_resource(FreightKit.crossing_deck(Vector3(sp["pos"].x, top_y, sp["pos"].z), rail_dir3, DECK_HALF_LEN / skew, DECK_HALF_W), "crossing_deck_%d" % ci)
		root.add_child(deck)
		var cn := Node3D.new()
		cn.name = "RailCrossing%d" % ci
		cn.set_script(load("res://RailCrossing.gd"))
		cn.position = sp["pos"]
		cn.rotation_degrees = Vector3(0, sp["yaw"], 0)
		cn.set("train_path", NodePath("../%sTrain" % _rails[ri]["name"]))
		cn.set("train_s", float(c["rail_s"]))
		cn.set("road_half", ROAD_HALF)
		level_scene.add_child(cn)
		if int(info_of(ri).get("kicker", 0)) == 1:
			_build_kicker(level_scene, c, ci, cn)
		c["node_name"] = cn.name
		print("  crossing %d: %s at lap %.0fm (skew %.0f deg)" % [ci, _rails[ri]["name"], lap_s, rad_to_deg(acos(skew))])


## A masonry portal where each railway goes into a hill: at the last sample outside it, facing out.
func _build_portals(level_scene: Node3D) -> void:
	var root := Node3D.new()
	root.name = "TunnelPortals"
	level_scene.add_child(root)
	var pk := FreightKit.new_kit()
	pk.reset_frame()
	var kit := {}
	FreightKit.portal(pk, kit)
	var mesh: ArrayMesh = _save_baked_resource(pk.commit(kit), "portal") as ArrayMesh
	var count := 0
	for ri in range(_rails.size()):
		var len_r: float = _rail_len(ri)
		var a: Vector2 = _rails[ri]["a"]
		var dir: Vector2 = (_rails[ri]["b"] - a).normalized()
		var n: int = int(floor(len_r / SAMPLE_STEP)) + 1
		var prev_in: bool = _in_hill(_rail_at(ri, 0.0))
		for k in range(1, n):
			var s: float = float(k) * SAMPLE_STEP
			var now_in: bool = _in_hill(_rail_at(ri, s))
			if now_in == prev_in:
				continue
			# The boundary: the outside sample is k - 1 (going in) or k (coming out).
			var out_s: float = s - SAMPLE_STEP if now_in else s
			var into := Vector3(dir.x, 0.0, dir.y) * (1.0 if now_in else -1.0)
			var p: Vector2 = _rail_at(ri, out_s)
			var top := Vector3(p.x, _rail_top(ri, out_s), p.y)
			var right := Vector3(-into.z, 0.0, into.x)
			var basis := Basis(-right, Vector3.UP, into)
			_instance_mesh(root, "Portal_%s_%d" % [_rails[ri]["name"], count], mesh, Transform3D(basis, top))
			count += 1
			prev_in = now_in
	print("  %d tunnel portals" % count)


func info_of(ri: int) -> Dictionary:
	return _rails[ri]


## The flatcar kicker before a crossing: a wooden ramp the full width of the road whose lip stands KICKER_LIP
## metres short of the rails, so a cart at 35-40 m/s is over them (in the middle of its 4.8m flight over the
## train) at about 4m over the road: it clears a flatcar's deck (2.2m) and not a boxcar (6.3m) or a loaded
## flatcar (4.4m). `res://scratch/kicker_flight_test.tscn -- height=2.2 run_ups=...` measures it.
const KICKER_LIP := 11.0
const KICKER_LENGTH := 12.0
const KICKER_HEIGHT := 2.2

func _build_kicker(level_scene: Node3D, c: Dictionary, ci: int, crossing: Node3D) -> void:
	var toe: Dictionary = _spot(float(c["lap_s"]) - KICKER_LIP - KICKER_LENGTH, 0.0, 0.0)
	var ramp: StaticBody3D = (load("res://WoodenRamp.tscn") as PackedScene).instantiate()
	ramp.name = "FlatcarKicker%d" % ci
	ramp.set("length", KICKER_LENGTH)
	ramp.set("height", KICKER_HEIGHT)
	ramp.set("curve", 0.6)
	ramp.set("width", 13.6)
	ramp.position = toe["pos"]
	ramp.rotation_degrees = Vector3(0, toe["yaw"], 0)
	level_scene.add_child(ramp)
	crossing.set("ai_stop_short", KICKER_LIP + KICKER_LENGTH + 14.0)


func _near_crossing(ri: int, s: float, reach: float) -> bool:
	for c in _crossings:
		if int(c["rail"]) == ri and absf(s - float(c["rail_s"])) < reach:
			return true
	return false


func _flush_track(root: Node3D, ri: int, piece: Array, bed: Array, piece_no: int) -> int:
	var mi := MeshInstance3D.new()
	mi.name = "TrackBed_%s_%d" % [_rails[ri]["name"], piece_no]
	mi.mesh = FreightKit.track_piece(piece, bed, piece_no + ri * 1000)
	root.add_child(mi)
	return piece_no + 1


# ======================================================================================
#  The depot, the poles, the signs and the desert
# ======================================================================================

## People-sized things are grown like the rolling stock's (a depot 70m long beside carts 3m long).
const PROP_SCALE := 1.6

func _instance_mesh(parent: Node3D, node_name: String, mesh: Mesh, xf: Transform3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.transform = xf
	parent.add_child(mi)
	return mi


func _scaled_kit(sc: float) -> PropKit:
	var pk: PropKit = FreightKit.new_kit()
	pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * sc), Vector3.ZERO))
	return pk


func _label(parent: Node3D, text: String, at: Vector3, basis: Basis, pixel: float, col: Color, size := 64) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = pixel
	l.modulate = col
	l.outline_size = 8
	l.outline_modulate = Color(0.05, 0.05, 0.05)
	l.transform = Transform3D(basis, at)
	parent.add_child(l)


func _build_depot(level_scene: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Depot"
	level_scene.add_child(root)
	var h: float = _pads[0]["h"]
	var pk := _scaled_kit(PROP_SCALE)
	var kit := {}
	FreightKit.depot(pk, kit)
	var x0 := -330.0
	var z_front := 214.0
	_instance_mesh(root, "Station", _save_baked_resource(pk.commit(kit), "station"), Transform3D(Basis(), Vector3(x0, h, z_front)))
	_label(root, "ESTACIÓN DEL VIENTO", Vector3(x0 + 22.0 * PROP_SCALE, h + 7.4 * PROP_SCALE, z_front + 1.0 * PROP_SCALE), Basis(), 0.036, Color(0.96, 0.92, 0.82))
	_label(root, "FREIGHT LINE · KM 0", Vector3(x0 + 22.0 * PROP_SCALE, h + 2.9 * PROP_SCALE, z_front + 0.5), Basis(), 0.012, Color(0.2, 0.2, 0.2), 48)
	# The water tower and the grain silos.
	pk = _scaled_kit(PROP_SCALE)
	kit = {}
	FreightKit.water_tower(pk, kit)
	_instance_mesh(root, "TankTower", _save_baked_resource(pk.commit(kit), "tank_tower"), Transform3D(Basis(), Vector3(-105.0, h, 186.0)))
	pk = _scaled_kit(PROP_SCALE)
	kit = {}
	FreightKit.silos(pk, kit)
	_instance_mesh(root, "GrainSilos", _save_baked_resource(pk.commit(kit), "silos"), Transform3D(Basis(), Vector3(-205.0, h, 170.0)))
	_label(root, "COOPERATIVA GRANERA", Vector3(-205.0 + 10.5 * PROP_SCALE, h + 6.6 * PROP_SCALE, 170.0 + 11.2 * PROP_SCALE), Basis(), 0.024, Color(0.96, 0.94, 0.88), 56)
	# A siding behind them with wagons on it: track, then the cars standing on the rails.
	var siding_z := 160.0
	var pts: Array = []
	var bed: Array = []
	var top: float = h + RAIL_LIFT
	var sx := -345.0
	while sx <= -95.0:
		pts.append(Vector3(sx, top, siding_z))
		if pts.size() > 1:
			bed.append(true)
		sx += SAMPLE_STEP
	var track := _instance_mesh(root, "SidingTrackBed", FreightKit.track_piece(pts, bed, 4242), Transform3D.IDENTITY)
	track.name = "SidingTrackBed"
	var parked := [["box", 0, -330.0], ["box", 1, -305.0], ["tank", 1, -278.0], ["flat_load", 0, -250.0], ["box", 2, -222.0]]
	for w in parked:
		var kind: String = w[0]
		_instance_mesh(root, "ParkedWagon_%s_%d" % [kind, int(w[2])], TrainKit.build(kind, int(w[1])), Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(float(w[2]), top, siding_z)))
	# Buffer stop at the siding's east end.
	pk = FreightKit.new_kit()
	kit = {}
	pk.block(kit, "steel", Vector3(-96.0, top - 0.1, siding_z - 2.6), Vector3(-94.4, top + 2.6, siding_z + 2.6), Color(0.45, 0.10, 0.08))
	_instance_mesh(root, "BufferStop", pk.commit(kit), Transform3D.IDENTITY)
	print("  depot built on a pad at %.1fm" % h)


func _build_poles(level_scene: Node3D) -> void:
	var root := Node3D.new()
	root.name = "TelegraphLines"
	level_scene.add_child(root)
	var pk := _scaled_kit(1.3)
	var kit := {}
	FreightKit.pole(pk, kit)
	var pole_mesh: ArrayMesh = _save_baked_resource(pk.commit(kit), "pole") as ArrayMesh
	var wk := FreightKit.new_kit()
	wk.reset_frame()
	var wire_kit := {}
	var transforms: Array = []
	for ri in range(_rails.size()):
		var a: Vector2 = _rails[ri]["a"]
		var dir: Vector2 = (_rails[ri]["b"] - a).normalized()
		var right := Vector3(-dir.y, 0.0, dir.x)
		var prev := PackedVector3Array()
		var s := 40.0
		while s < _rail_len(ri) - 40.0:
			var p: Vector2 = _rail_at(ri, s)
			var side := Vector2(right.x, right.z) * 11.0
			var q: Vector2 = p + side
			if _in_hill(p) or _near_crossing(ri, s, 34.0) or _near_pad(q, 10.0):
				prev = PackedVector3Array()
				s += 70.0
				continue
			var y: float = _ground_at(q.x, q.y)
			var xf := Transform3D(Basis(right, Vector3.UP, Vector3(dir.x, 0.0, dir.y).normalized() * -1.0).orthonormalized(), Vector3(q.x, y, q.y))
			transforms.append(xf)
			# Wires from the last pole: the outer insulators of both arms, sagging in the middle.
			var heights: Array = [10.2 * 1.3 + 0.55, 8.6 * 1.3 + 0.55]
			var offs: Array = [-1.35 * 1.3, 1.35 * 1.3]
			var cur := PackedVector3Array()
			for hh in heights:
				for oo in offs:
					cur.append(xf * Vector3(float(oo), float(hh), 0.0))
			if prev.size() == cur.size():
				for k in range(cur.size()):
					var sag := 1.6
					var last: Vector3 = prev[k]
					for j in range(1, 7):
						var f: float = float(j) / 6.0
						var pt: Vector3 = prev[k].lerp(cur[k], f)
						pt.y -= sag * 4.0 * f * (1.0 - f)
						wk.beam(wire_kit, "steel", last, pt, 0.07, 0.07, Color(0.10, 0.10, 0.10))
						last = pt
			prev = cur
			s += 70.0
	var wires := _instance_mesh(root, "TelegraphWires", wk.commit(wire_kit), Transform3D.IDENTITY)
	wires.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = pole_mesh
	mm.instance_count = transforms.size()
	mm.buffer = PropKit.transform_buffer(transforms)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "TelegraphPoles"
	mmi.multimesh = mm
	root.add_child(mmi)
	print("  %d telegraph poles" % transforms.size())


func _near_pad(p: Vector2, reach: float) -> bool:
	for pd in _pads:
		var c: Vector2 = pd["c"]
		var half: Vector2 = pd["half"]
		if absf(p.x - c.x) < half.x + reach and absf(p.y - c.y) < half.y + reach:
			return true
	return false


## Advance warning signs 120m before each crossing on the right of the road: a yellow disc with a black X
## and RR, on a post.
func _build_crossing_signs(level_scene: Node3D) -> void:
	var root := Node3D.new()
	root.name = "CrossingSigns"
	level_scene.add_child(root)
	var pk := _scaled_kit(1.4)
	var kit := {}
	pk.beam(kit, "steel", Vector3(0, 0, 0), Vector3(0, 3.3, 0), 0.16, 0.16, Color(0.55, 0.55, 0.55))
	pk.tube(kit, "paint", Vector3(0, 3.8, 0.0), Vector3(0, 3.8, 0.07), 1.0, 1.0, 28, Color(0.96, 0.78, 0.10))
	pk.tube(kit, "paint", Vector3(0, 3.8, 0.07), Vector3(0, 3.8, 0.09), 0.88, 0.88, 28, Color(0.96, 0.78, 0.10))
	for ang in [0.7, -0.7]:
		pk.beam(kit, "paint", Vector3(-0.62 * cos(ang), 3.8 - 0.62 * sin(ang) * -1.0 * 0.0 + -0.62 * sin(ang), 0.1), Vector3(0.62 * cos(ang), 3.8 + 0.62 * sin(ang), 0.1), 0.14, 0.03, Color(0.05, 0.05, 0.05), Vector3(0, 0, 1))
	var mesh: ArrayMesh = _save_baked_resource(pk.commit(kit), "rr_sign") as ArrayMesh
	var ci := 0
	for c in _crossings:
		ci += 1
		for before in [150.0, 70.0]:
			var sp: Dictionary = _spot(float(c["lap_s"]) - before, ROAD_HALF + 3.6, 0.0)
			var pos: Vector3 = sp["pos"]
			pos.y = _ground_at(pos.x, pos.z)
			var basis := Basis(Vector3.UP, deg_to_rad(float(sp["yaw"])))
			_instance_mesh(root, "RRSign%d_%d" % [ci, int(before)], mesh, Transform3D(basis, pos))
			_label(root, "RR", pos + basis * Vector3(0.0, 3.8 * 1.4 - 0.15, 0.2), basis, 0.012, Color(0.05, 0.05, 0.05), 64)


## Cacti, sagebrush and boulders over the plain: dense near the road, thinning out to the hills.
func _build_flora(level_scene: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Desert"
	level_scene.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6677
	var kinds := {}
	var cactus := CactusKit.new()
	var cmat: Material = cactus.material()
	var plants: Array = [
		["saguaro", 7, Vector2(6.0, 9.5), 0.10],
		["organ", 3, Vector2(3.5, 5.5), 0.02],
		["barrel", 3, Vector2(1.0, 1.8), 0.05],
		["pear", 4, Vector2(1.3, 2.2), 0.08],
		["cholla", 3, Vector2(2.0, 3.0), 0.05],
		["ocotillo", 3, Vector2(4.0, 6.0), 0.04],
	]
	var meshes := {}
	var far_meshes := {}
	for pl in plants:
		for v in range(int(pl[1])):
			meshes["%s_%d" % [pl[0], v]] = cactus.build(pl[0], v, 0, cmat)
			far_meshes["%s_%d" % [pl[0], v]] = cactus.build(pl[0], v, 1, cmat)
	var sage_meshes: Array = []
	for v in 3:
		sage_meshes.append(FreightKit.sage(100 + v))
	var rock_meshes: Array = []
	for v in 5:
		rock_meshes.append(FreightKit.rock(300 + v))
	# Candidate spots along the lap: both sides, closer in more of them.
	var cells := {}
	var s := 0.0
	var placed := 0
	while s < float(_lap["len"]):
		for k in range(14):
			var side: float = -1.0 if rng.randf() < 0.5 else 1.0
			var lat: float = side * (ROAD_FLAT + 3.0 + rng.randf() * rng.randf() * 260.0)
			var sp: Dictionary = _spot(s + rng.randf_range(-3.0, 3.0), lat, 0.0)
			var pos: Vector3 = sp["pos"]
			var p2 := Vector2(pos.x, pos.z)
			if not _flora_ok(p2):
				continue
			pos.y = _ground_at(pos.x, pos.z) - 0.05
			var roll: float = rng.randf()
			var kind: String
			var scl: float
			if roll < 0.62:
				kind = "sage_%d" % rng.randi_range(0, 2)
				scl = rng.randf_range(0.9, 2.2)
			elif roll < 0.80:
				kind = "rock_%d" % rng.randi_range(0, 4)
				scl = rng.randf_range(0.9, 4.0)
			else:
				var pl: Array = plants[rng.randi_range(0, plants.size() - 1)]
				if rng.randf() > float(pl[3]) * 5.0:
					continue
				var vi: int = rng.randi_range(0, int(pl[1]) - 1)
				kind = "%s_%d" % [pl[0], vi]
				var mesh_h: float = maxf((meshes[kind] as ArrayMesh).get_aabb().size.y, 0.1)
				scl = rng.randf_range((pl[2] as Vector2).x, (pl[2] as Vector2).y) / mesh_h
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scl)
			var key := "%s|%d|%d" % [kind, floori(pos.x / 160.0), floori(pos.z / 160.0)]
			if not cells.has(key):
				cells[key] = []
			cells[key].append(Transform3D(basis, pos))
			placed += 1
		s += 6.0
	for key in cells.keys():
		var parts: PackedStringArray = String(key).split("|")
		var kind: String = parts[0]
		var mesh: Mesh
		var node_name: String
		var range_end := 600.0
		if kind.begins_with("sage"):
			mesh = sage_meshes[int(kind.substr(5))]
			node_name = "groundcover_sage_%s_%s" % [parts[1], parts[2]]
			range_end = 170.0
		elif kind.begins_with("rock"):
			mesh = rock_meshes[int(kind.substr(5))]
			node_name = "Boulders_%s_%s_%s" % [kind, parts[1], parts[2]]
			range_end = 520.0
		else:
			mesh = meshes[kind]
			node_name = "Cactus_%s_%s_%s" % [kind, parts[1], parts[2]]
			range_end = 700.0
		var tf: Array = cells[key]
		var buf: PackedFloat32Array = PropKit.transform_buffer(tf)
		var is_cactus: bool = not kind.begins_with("sage") and not kind.begins_with("rock")
		# Cacti come in two detail levels, swapped at 150m; the rest are one mesh.
		var variants: Array = [[mesh, 0.0, 150.0 if is_cactus else range_end, node_name]]
		if is_cactus:
			variants.append([far_meshes[kind], 140.0, range_end, node_name + "_far"])
		for vr in variants:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = vr[0]
			mm.instance_count = tf.size()
			mm.buffer = buf
			var mmi := MultiMeshInstance3D.new()
			mmi.name = vr[3]
			mmi.multimesh = mm
			mmi.visibility_range_begin = vr[1]
			mmi.visibility_range_end = vr[2]
			if kind.begins_with("sage") or vr[1] > 0.0:
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mmi)
	print("  desert: %d plants and rocks in %d cells" % [placed, cells.size()])


## Whether flora may stand at `p`: off the road, the rails, the hills, the depot and steep ground.
func _flora_ok(p: Vector2) -> bool:
	if p.x < FINE_X.x + 40.0 or p.x > FINE_X.y - 40.0 or p.y < FINE_Z.x + 40.0 or p.y > FINE_Z.y - 40.0:
		return false
	for ri in range(_rails.size()):
		var a: Vector2 = _rails[ri]["a"]
		var b: Vector2 = _rails[ri]["b"]
		var ab: Vector2 = b - a
		var t: float = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		if p.distance_to(a + ab * t) < 15.0:
			return false
	if _near_pad(p, 6.0):
		return false
	if _hills(p.x, p.y) > 1.0:
		return false
	return _slope_at(p.x, p.y) < 0.45


# ======================================================================================
#  Gameplay
# ======================================================================================

func _place_gameplay(level_scene: Node3D) -> void:
	var gate_scene: PackedScene = load("res://CheckpointGate.tscn")
	var spawn_scene: PackedScene = load("res://SpawnIndicator.tscn")
	var fl: Dictionary = _spot(FINISH_S, 0.0, 0.06)
	var finish_line = gate_scene.instantiate()
	finish_line.name = "FinishLine"
	finish_line.position = fl["pos"]
	finish_line.rotation_degrees = Vector3(0, fl["yaw"], 0)
	finish_line.set("is_finish_line", true)
	level_scene.add_child(finish_line)
	var spawn_points := Node3D.new()
	spawn_points.name = "SpawnPoints"
	finish_line.add_child(spawn_points)
	var grid_coords = [
		Vector3(-2.9, 0.05, 5.0), Vector3(2.9, 0.05, 5.0),
		Vector3(-2.9, 0.05, 12.5), Vector3(2.9, 0.05, 12.5),
		Vector3(-2.9, 0.05, 20.0), Vector3(2.9, 0.05, 20.0),
	]
	for i in range(grid_coords.size()):
		var sp := Marker3D.new()
		sp.name = "Spawn%d" % (i + 1)
		sp.position = grid_coords[i]
		sp.gizmo_extents = 0.3
		spawn_points.add_child(sp)
		if spawn_scene:
			var si = spawn_scene.instantiate()
			si.name = "SpawnIndicator"
			sp.add_child(si)

	# Checkpoints: each crossing has one 110m before it (a respawn after the train puts you back in time
	# to catch the next gap) and one 230m after it.
	var checkpoints_container := Node3D.new()
	checkpoints_container.name = "Checkpoints"
	level_scene.add_child(checkpoints_container)
	var cp_offs: Array = []
	for c in _crossings:
		cp_offs.append(float(c["lap_s"]) - 110.0)
		cp_offs.append(float(c["lap_s"]) + 230.0)
	cp_offs.sort()
	for i in range(cp_offs.size()):
		var c: Dictionary = _spot(cp_offs[i], 0.0, 0.1)
		var gate = gate_scene.instantiate()
		gate.name = "Checkpoint_%d" % (i + 1)
		gate.position = c["pos"]
		gate.rotation_degrees = Vector3(0, c["yaw"], 0)
		checkpoints_container.add_child(gate)
		print("  checkpoint %d at %.0fm" % [i + 1, cp_offs[i]])

	# Boost pads: out of the first corner, the far side of each crossing, and the finish straight.
	var boost_scene: PackedScene = load("res://BoostPad.tscn")
	var boost_container := Node3D.new()
	boost_container.name = "BoostPads"
	level_scene.add_child(boost_container)
	var bp_defs: Array = [["Boost_Start", FINISH_S + 330.0, 0.0]]
	var bi := 0
	for c in _crossings:
		bi += 1
		bp_defs.append(["Boost_Cross%d" % bi, float(c["lap_s"]) + 60.0, -2.6 if bi % 2 == 0 else 2.6])
	for bd in bp_defs:
		var bp = boost_scene.instantiate()
		bp.name = bd[0]
		var sp2: Dictionary = _spot(bd[1], bd[2], 0.08)
		bp.position = sp2["pos"]
		bp.rotation_degrees = Vector3(0, sp2["yaw"], 0)
		boost_container.add_child(bp)


# ======================================================================================
#  Sky and light
# ======================================================================================

## The haze over the plain: pale, dusty, a touch warm.
const HAZE := Color(0.80, 0.78, 0.72)

func _build_environment(level_scene: Node3D) -> void:
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://sky_tropical_cumulus.gdshader")
	sky_mat.set_shader_parameter("sky_top", Color(0.14, 0.36, 0.76))
	sky_mat.set_shader_parameter("sky_horizon", Color(0.80, 0.84, 0.88))
	sky_mat.set_shader_parameter("ground_horizon", HAZE)
	sky_mat.set_shader_parameter("ground_bottom", Color(0.52, 0.46, 0.40))
	sky_mat.set_shader_parameter("sky_curve", 0.4)
	sky_mat.set_shader_parameter("horizon_haze", HAZE)
	sky_mat.set_shader_parameter("haze_strength", 0.85)
	sky_mat.set_shader_parameter("haze_height", 0.14)
	sky_mat.set_shader_parameter("sun_tint", Color(1.0, 0.96, 0.86))
	sky_mat.set_shader_parameter("sun_disc_degrees", 1.0)
	sky_mat.set_shader_parameter("sun_glow", 0.45)
	sky_mat.set_shader_parameter("sun_horizon_tint", Color(1.0, 0.86, 0.66))
	sky_mat.set_shader_parameter("sun_horizon_glow", 0.1)
	sky_mat.set_shader_parameter("cloud_lit", Color(1.0, 0.98, 0.94))
	sky_mat.set_shader_parameter("cloud_shade", Color(0.60, 0.62, 0.70))
	sky_mat.set_shader_parameter("cloud_coverage", 0.30)
	sky_mat.set_shader_parameter("cloud_opacity", 0.92)
	sky_mat.set_shader_parameter("cloud_scale", 1.2)
	sky_mat.set_shader_parameter("cloud_seed", 52.1)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.4
	env.ambient_light_color = Color(0.94, 0.90, 0.84)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.2
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = HAZE
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.15
	env.fog_density = 1.0
	env.fog_depth_begin = 380.0
	env.fog_depth_end = 5200.0
	env.fog_depth_curve = 1.8
	env.fog_sky_affect = 0.05
	env.fog_aerial_perspective = 0.25
	env_node.environment = env
	level_scene.add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	# Midday: high in the south-west, short hard shadows, so the train reads as a mass of colour and a
	# dark band under it.
	sun.rotation_degrees = Vector3(-62.0, -38.0, 0.0)
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 300.0
	sun.directional_shadow_split_1 = 0.08
	sun.directional_shadow_split_2 = 0.22
	sun.directional_shadow_split_3 = 0.5
	level_scene.add_child(sun)


# ======================================================================================
#  Build
# ======================================================================================

func _save_baked_resource(res: Resource, res_name: String) -> Resource:
	if not DirAccess.dir_exists_absolute("res://generated/"):
		DirAccess.make_dir_absolute("res://generated/")
	var file_path: String = "res://generated/" + RES_PREFIX + res_name + ".res"
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
	print("=== Freight Line (Sierra del Viento) Level Generation ===")
	var t_start: int = Time.get_ticks_msec()

	var level_scene := Node3D.new()
	level_scene.name = LEVEL_NAME
	level_scene.set_script(load("res://levels/Level.gd"))
	var players_node := Node3D.new()
	players_node.name = "Players"
	level_scene.add_child(players_node)
	var p_spawner := MultiplayerSpawner.new()
	p_spawner.name = "PlayerSpawner"
	p_spawner.set("_spawnable_scenes", PackedStringArray(["uid://cart123"]))
	p_spawner.spawn_path = NodePath("../Players")
	p_spawner.spawn_limit = 6
	level_scene.add_child(p_spawner)
	var proj_spawner := MultiplayerSpawner.new()
	proj_spawner.name = "ProjectileSpawner"
	proj_spawner.spawn_path = NodePath(".")
	level_scene.add_child(proj_spawner)
	add_child(level_scene)

	_init_noise()
	_build_lines()
	main_curve = _build_main_curve()
	var track_path := Path3D.new()
	track_path.name = "TrackPath"
	track_path.curve = main_curve
	level_scene.add_child(track_path)

	_plan_pads()
	_add_samples()
	_build_heights()
	print("  heights built (%.1fs)" % ((Time.get_ticks_msec() - t_start) / 1000.0))
	var ground_mat := ShaderMaterial.new()
	ground_mat.shader = load("res://canyon_ground.gdshader")
	ground_mat.set_shader_parameter("sand_tex", load("res://materials/sand.png"))
	ground_mat.set_shader_parameter("dirt_tex", load("res://materials/dirt.png"))
	ground_mat.set_shader_parameter("gravel_tex", load("res://materials/dark_canyon_rock.png"))
	ground_mat.set_shader_parameter("gravel_normal", load("res://materials/dark_canyon_rock_normal.png"))
	ground_mat.set_shader_parameter("asphalt_tex", load("res://materials/asphalt.png"))
	ground_mat.set_shader_parameter("road_half_width", ROAD_HALF)
	ground_mat.set_shader_parameter("horizon_color", HAZE)
	ground_mat.set_shader_parameter("horizon_center", CENTRE)
	# A paler, drier plain than the canyon's red: tan hardpan and bleached grass.
	ground_mat.set_shader_parameter("sand_tint", Color(0.80, 0.66, 0.46))
	ground_mat.set_shader_parameter("pale_sand", Color(0.90, 0.80, 0.62))
	ground_mat.set_shader_parameter("gravel_tint", Color(1.0, 0.95, 0.86))
	ground_mat.set_shader_parameter("scrub_tint", Color(0.58, 0.54, 0.30))
	ground_mat.set_shader_parameter("river_y", -1000.0)
	_ground_mat = _save_baked_resource(ground_mat, "ground_material") as ShaderMaterial
	var terrain_root := Node3D.new()
	terrain_root.name = "PlainsTerrain"
	level_scene.add_child(terrain_root)
	_build_terrain(terrain_root, _ground_mat)
	print("  terrain built (%.1fs)" % ((Time.get_ticks_msec() - t_start) / 1000.0))

	_build_railways(level_scene)
	_build_portals(level_scene)
	_build_depot(level_scene)
	_build_poles(level_scene)
	_build_crossing_signs(level_scene)
	_build_flora(level_scene)
	_build_environment(level_scene)
	var wind := AudioStreamPlayer.new()
	wind.name = "PlainsWind"
	wind.stream = _save_baked_resource(FreightKit.wind(), "wind_loop") as AudioStream
	wind.volume_db = -22.0
	wind.bus = &"SFX"
	wind.autoplay = true
	level_scene.add_child(wind)
	_place_gameplay(level_scene)

	level_scene.set("track_path", track_path)
	level_scene._setup_checkpoints()
	var chunked: int = MeshChunker.chunk_scene(level_scene, "res://generated/" + RES_PREFIX, "res://generated/freight_chunks", MESH_CHUNK_CELL)
	print("  chunked %d large meshes" % chunked)
	_set_owner_recursive(level_scene, level_scene)
	remove_child(level_scene)
	var packed_scene := PackedScene.new()
	var pack_err = packed_scene.pack(level_scene)
	if pack_err != OK:
		push_error("Failed to pack %s: %d" % [LEVEL_PATH, pack_err])
		get_tree().quit(1)
		return
	var save_err = ResourceSaver.save(packed_scene, LEVEL_PATH)
	if save_err != OK:
		push_error("Failed to save %s: %d" % [LEVEL_PATH, save_err])
		get_tree().quit(1)
		return
	print("Saved %s in %.1fs" % [LEVEL_PATH, (Time.get_ticks_msec() - t_start) / 1000.0])
	get_tree().quit(0)
