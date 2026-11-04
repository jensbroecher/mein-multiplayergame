# regenerate_freight_line.gd
#
# Builds levels/FreightLevel.tscn - Estación Seca (once Freight Line), third stage of the Sierra del Viento GP: a high-desert
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
const YardKit = preload("res://YardKit.gd")
const FactoryKit = preload("res://FactoryKit.gd")

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
## The railways: straight lines from where they come out of the hills to where they go into them. Every train
## on a line runs from the first point to the second once a `period`, entering `phase` seconds into it, so a
## line's trains must be scheduled not to overlap on it: each one's turn on the line is (line + train) / speed
## seconds. `kicker` puts a flatcar kicker before each of the line's crossings.
const RAILS := [
	{"name": "MainLine", "a": Vector2(-860.0, 0.0), "b": Vector2(860.0, 0.0), "kicker": 1, "trains": [
		{"name": "Freight", "speed": 36.0, "period": 125.0, "phase": 0.0, "consist": [
			"loco", "loco:1", "box", "box:1", "hopper", "hopper", "hopper:1", "flat", "flat", "flat", "flat", "box:2",
			"tank", "tank:1", "tank", "box", "flat_load", "flat_load", "flat", "flat", "flat", "hopper", "hopper:1", "box:3",
			"flat", "flat", "flat", "caboose"]},
		{"name": "Express", "speed": 40.0, "period": 125.0, "phase": 68.0, "consist": [
			"ploco", "coach", "coach", "coach", "coach", "coach", "obs"]},
	]},
	{"name": "BranchLine", "a": Vector2(210.0, -850.0), "b": Vector2(210.0, -60.0), "kicker": 1, "trains": [
		{"name": "Freight", "speed": 28.0, "period": 60.0, "phase": 17.0, "consist": [
			"loco", "flat_load", "flat_load", "flat", "flat", "flat", "flat", "hopper", "hopper:1", "tank", "box", "flat", "flat",
			"flat_load", "box:1", "caboose"]},
	]},
]
## The hills the railways run into: centre x, z, radius, height.
const HILLS := [
	[-880.0, 0.0, 110.0, 36.0],
	[880.0, 0.0, 110.0, 36.0],
	[210.0, -880.0, 100.0, 34.0],
	[210.0, -50.0, 90.0, 30.0],
]

## The yard behind the start straight, a network of its own off the Main Line: a lead leaves it at turnout T1 (to
## the right, toward the south), curves round to the east and runs on, as the platform track, past Estación del
## Viento to a buffer stop. At turnout T2 (to the left) the factory track leaves the platform track and runs
## on, 12m north of it, past the grain complex to its own buffer stop. Moves are ["S", length] and
## ["A", radius, degrees] (positive turns right), from the toe with heading east.
const YARD_T1 := Vector2(-440.0, 0.0)
const YARD_LEAD_MOVES := [["A", 100.0, 90.0], ["S", 10.0], ["A", 60.0, -90.0], ["S", 172.0]]
const YARD_T2_X := -262.0
const FACTORY_SHIFT := 12.0
const FACTORY_R := 150.0
const FACTORY_END_X := 25.0
## Where the two tracks of a turnout are this far apart (centre to centre) they get beds of their own.
const TURNOUT_SEPARATION := 4.4
## A yard track keeps exactly the height of the track it leaves for this many metres from the turnout's toe (past the
## turnout's zone, so its rails meet the turnout's on the same sleepers), easing to its own over 46m more.
const TURNOUT_HOLD := 42.0

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
## The big trestle jumps (WoodenRamp, as on Mina del Viento's plateau): [name, s of the toe], on the two straights with
## no crossing ahead: the start straight past the station (150m from the grid) and the top straight past checkpoint 4
## (a gate under the flight would be hit: carts fly 7-11m up). BIG_JUMP is [length, height, curve]; each has a boost
## pad BIG_JUMP_BOOST before its toe.
const BIG_JUMPS := [["StationJump", 300.0], ["TopJump", 1880.0]]
const BIG_JUMP := [26.0, 6.0, 0.55]
const BIG_JUMP_BOOST := 26.0

## Level pads for the depot: centre x, z, half length (x), half width (z), the blend over which the ground
## eases back, and the pad's height (set from the plain's mean under it by _plan_pads).
var _pads: Array = [
	{"c": Vector2(-130.0, 166.0), "half": Vector2(175.0, 56.0), "blend": 16.0, "h": 0.0},
]

var _lap: Dictionary = {}
var _rails: Array = []
## Where a railway crosses the lap: {rail, lap_s, rail_s, pos (Vector2), road_y}.
var _crossings: Array = []
## The yard's tracks (see _build_spurs): {name, samples, ground, top, parent (kind, index, junction s), zone_end}.
var _spurs: Array = []
## Its turnouts: {name, through (kind, index), x0, z0, side, spur, zone_end}.
var _turnouts: Array = []
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
var _rs_line := PackedInt32Array()     # which line: a railway's index, 100 + a yard track's, -1 the lap
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
## The centre line (rails' top) of every stretch of track outside the hills, for RailRumble.gd.
var _rumble_lines: Array[PackedVector3Array] = []
var _rock_normal: Texture2D


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
const HILL_PORTAL := 0.78

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


## The cutting into a portal: its floor's half width and its walls' rise per metre (past a rounded shoulder).
const PORTAL_FLAT := 5.4
const PORTAL_CUT := 2.0
## Metres either side of a railway, at a portal, over which the terrain grid is halved.
const PORTAL_REFINE := 32.0
## Behind a facade the hill keeps this much cover over the lining's crown, and rises from the facade's top at most
## this much per metre back.
const PORTAL_COVER := 1.2
const PORTAL_RISE := 1.2
const PORTAL_TOP_MIN := 13.5

## The tunnel mouths, planned before the ground is graded: where each railway goes into a hill, at the last sample
## outside it. {line, pos (the rail's top at the facade's front), into (Vector2, into the hill), right (Vector2, the
## world's right of `into`), ground (the graded ground under the rails there), depth (metres of tunnel behind it),
## wing_l, wing_r (FreightKit.portal's wing tops)}. The portal's frame is Basis(-right, UP, into) at `pos`.
var _portals: Array = []

func _plan_portals() -> void:
	_portals.clear()
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
			prev_in = now_in
			# The boundary: the outside sample is k - 1 (going in) or k (coming out).
			var out_s: float = s - SAMPLE_STEP if now_in else s
			var sgn: float = 1.0 if now_in else -1.0
			var into: Vector2 = dir * sgn
			var p: Vector2 = _rail_at(ri, out_s)
			# How far the tunnel runs behind: to where the line comes out again, or to its end.
			var depth := 0.0
			var d := SAMPLE_STEP
			while out_s + sgn * d >= 0.0 and out_s + sgn * d <= len_r and _in_hill(_rail_at(ri, out_s + sgn * d)):
				depth = d
				d += SAMPLE_STEP
			var pd := {"line": ri, "pos": Vector3(p.x, _rail_top(ri, out_s), p.y), "into": into, "right": Vector2(-into.y, into.x),
					"ground": _rail_height(ri, out_s), "depth": depth + SAMPLE_STEP, "out_s": out_s}
			# The bay stands 0.8m over the hill above the arch, at least PORTAL_TOP_MIN (room for the plaque over the string
			# course) and at most FreightKit.PORTAL_TOP.
			var over_arch: Vector2 = p + into * 2.5
			pd["top"] = clampf(_base_height(over_arch.x, over_arch.y) - float(pd["pos"].y) + 0.8, PORTAL_TOP_MIN, FreightKit.PORTAL_TOP)
			pd["wing_l"] = _wing_tops(pd, -1.0)
			pd["wing_r"] = _wing_tops(pd, 1.0)
			_portals.append(pd)
	print("  %d tunnel portals planned" % _portals.size())


## A portal's wing tops on its local side `sx` (the portal's +x is the world's -right): [metres out, height over the
## rail], every 2m from the bay's edge out, each 0.8m over the natural hill just behind the facade (at least 1m, at
## most the bay's height), so the facade's top follows the hill.
func _wing_tops(pd: Dictionary, sx: float) -> Array:
	var out: Array = []
	var bx: Vector2 = -(pd["right"] as Vector2)
	var p: Vector3 = pd["pos"]
	var x: float = FreightKit.PORTAL_BAY + 2.0
	while x <= FreightKit.PORTAL_WING_END + 0.01:
		var q: Vector2 = Vector2(p.x, p.z) + bx * (sx * x) + (pd["into"] as Vector2) * 2.5
		var h: float = _base_height(q.x, q.y) - p.y
		out.append([x, clampf(h + 0.8, 1.0, float(pd["top"]))])
		x += 2.0
	return out


## The height of a portal's facade over the rail at the world lateral `lat` (metres along `right`).
func _facade_top(pd: Dictionary, lat: float) -> float:
	var x: float = -lat
	var ax: float = absf(x)
	if ax <= FreightKit.PORTAL_BAY:
		return pd["top"]
	var wing: Array = pd["wing_r"] if x > 0.0 else pd["wing_l"]
	var px: float = FreightKit.PORTAL_BAY
	var py: float = pd["top"]
	for w in wing:
		if ax <= float(w[0]):
			return lerpf(py, float(w[1]), (ax - px) / maxf(float(w[0]) - px, 0.001))
		px = w[0]
		py = w[1]
	return py


## The portal whose tunnel `p` lies behind (within its depth; of a tunnel's two mouths, the nearer), and how far behind
## and how far across: [index, e, lat], or [-1, 0, 0].
func _behind_portal(x: float, z: float) -> Array:
	var best: Array = [-1, 0.0, 0.0]
	for i in range(_portals.size()):
		var pd: Dictionary = _portals[i]
		var rel := Vector2(x - pd["pos"].x, z - pd["pos"].z)
		var e: float = rel.dot(pd["into"])
		if e > 0.0 and e < float(pd["depth"]) and (int(best[0]) < 0 or e < float(best[1])):
			var lat: float = rel.dot(pd["right"])
			if absf(lat) < GRADE_REACH + FreightKit.PORTAL_WING_END:
				best = [i, e, lat]
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
	_hill_noise.frequency = 0.011
	_hill_noise.fractal_octaves = 2


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
		var r: float = float(hl[2]) * (1.0 + _hill_noise.get_noise_2d(x, z) * 0.12)
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
#  The yard's tracks
# ======================================================================================

## A path of straights and arcs from `start` heading `th` (the heading's direction is (cos, sin) in x, z, so a
## positive turn is to the right): moves are ["S", length] and ["A", radius, degrees]. A sample every SAMPLE_STEP at
## most: {"p": Vector2, "th": float, "s": float}.
func _turtle(start: Vector2, th: float, moves: Array) -> Array:
	var out: Array = [{"p": start, "th": th, "s": 0.0}]
	var p := start
	var s := 0.0
	for mv in moves:
		if mv[0] == "S":
			var length: float = mv[1]
			var n: int = maxi(int(ceil(length / SAMPLE_STEP)), 1)
			var d: Vector2 = _dir_of(th)
			for i in range(1, n + 1):
				var f: float = float(i) / float(n)
				out.append({"p": p + d * (length * f), "th": th, "s": s + length * f})
			p = p + d * length
			s += length
		else:
			var r: float = mv[1]
			var ang: float = deg_to_rad(float(mv[2]))
			var sgn: float = signf(ang)
			var arc_len: float = r * absf(ang)
			var n2: int = maxi(int(ceil(arc_len / SAMPLE_STEP)), 1)
			var c: Vector2 = p + _right_of(th) * r * sgn
			for i in range(1, n2 + 1):
				var f2: float = float(i) / float(n2)
				var th2: float = th + ang * f2
				out.append({"p": c - _right_of(th2) * r * sgn, "th": th2, "s": s + arc_len * f2})
			th += ang
			p = c - _right_of(th) * r * sgn
			s += arc_len
	return out


## The spur's ground height at distance `s` along it (linear between samples).
func _spur_ground_at(si: int, s: float) -> float:
	var samples: Array = _spurs[si]["samples"]
	var ground: PackedFloat32Array = _spurs[si]["ground"]
	if s <= 0.0:
		return ground[0]
	for k in range(1, samples.size()):
		if s <= float(samples[k]["s"]):
			var s0: float = samples[k - 1]["s"]
			var s1: float = samples[k]["s"]
			return lerpf(ground[k - 1], ground[k], (s - s0) / maxf(s1 - s0, 0.0001))
	return ground[ground.size() - 1]


## The ground height of the track a spur leaves, at the spur's point `p` (the parent's own height at the same distance
## along it), so the two meet without a step.
func _parent_ground(si: int, p: Vector2) -> float:
	var parent: Dictionary = _spurs[si]["parent"]
	if parent["kind"] == "rail":
		var ri: int = parent["index"]
		var a: Vector2 = _rails[ri]["a"]
		var dir: Vector2 = (_rails[ri]["b"] - a).normalized()
		return _rail_height(ri, (p - a).dot(dir))
	var pi: int = parent["index"]
	var axis: Vector2 = parent["axis"]
	return _spur_ground_at(pi, float(parent["s"]) + (p - parent["at"]).dot(axis))


## The lead, the platform track and the factory track: their samples, heights (the plain smoothed along each, held
## to the track it leaves near the turnout and to the pad's height on it), and the two turnouts.
func _build_spurs() -> void:
	_spurs.clear()
	_turnouts.clear()
	var lead: Array = _turtle(YARD_T1, 0.0, YARD_LEAD_MOVES)
	_spurs.append({"name": "YardLead", "samples": lead, "parent": {"kind": "rail", "index": 0}, "ground": PackedFloat32Array(), "top": PackedFloat32Array(), "zone_end": 0.0})
	_spur_heights(0)
	# T2: on the lead's final straight at x = YARD_T2_X.
	var s_t2 := 0.0
	var ls: Array = lead
	for k in range(1, ls.size()):
		if float(ls[k]["p"].x) >= YARD_T2_X and absf(float(ls[k]["th"])) < 0.01:
			var x0: float = ls[k - 1]["p"].x
			var x1: float = ls[k]["p"].x
			s_t2 = lerpf(float(ls[k - 1]["s"]), float(ls[k]["s"]), (YARD_T2_X - x0) / maxf(x1 - x0, 0.0001))
			break
	var z_platform: float = lead[lead.size() - 1]["p"].y
	var theta: float = acos(1.0 - FACTORY_SHIFT / (2.0 * FACTORY_R))
	var run: float = FACTORY_END_X - (YARD_T2_X + 2.0 * FACTORY_R * sin(theta))
	var factory: Array = _turtle(Vector2(YARD_T2_X, z_platform), 0.0, [["A", FACTORY_R, -rad_to_deg(theta)], ["A", FACTORY_R, rad_to_deg(theta)], ["S", run]])
	_spurs.append({"name": "FactoryTrack", "samples": factory, "parent": {"kind": "spur", "index": 0, "s": s_t2, "at": Vector2(YARD_T2_X, z_platform), "axis": Vector2(1.0, 0.0)},
			"ground": PackedFloat32Array(), "top": PackedFloat32Array(), "zone_end": 0.0})
	_spur_heights(1)
	_turnouts.append({"name": "T1", "through": {"kind": "rail", "index": 0}, "x0": YARD_T1.x, "z0": YARD_T1.y, "side": 1.0, "spur": 0, "s0": YARD_T1.x - float(_rails[0]["a"].x)})
	_turnouts.append({"name": "T2", "through": {"kind": "spur", "index": 0}, "x0": YARD_T2_X, "z0": z_platform, "side": -1.0, "spur": 1, "s0": s_t2})
	for t in _turnouts:
		var samples: Array = _spurs[int(t["spur"])]["samples"]
		var zone: float = float(samples[samples.size() - 1]["p"].x) - float(t["x0"])
		for sm in samples:
			if absf(float(sm["p"].y) - float(t["z0"])) >= TURNOUT_SEPARATION:
				zone = float(sm["p"].x) - float(t["x0"])
				break
		t["zone_end"] = zone
		_spurs[int(t["spur"])]["zone_end"] = zone
	print("  yard: lead %.0fm, factory track %.0fm, turnouts at x %.0f and %.0f (zones %.0fm, %.0fm)" % [
		float(lead[lead.size() - 1]["s"]), float(factory[factory.size() - 1]["s"]), YARD_T1.x, YARD_T2_X, _turnouts[0]["zone_end"], _turnouts[1]["zone_end"]])


func _spur_heights(si: int) -> void:
	var samples: Array = _spurs[si]["samples"]
	var raw := PackedFloat32Array()
	raw.resize(samples.size())
	for k in range(samples.size()):
		var p: Vector2 = samples[k]["p"]
		raw[k] = _plain(p.x, p.y)
	var smooth: PackedFloat32Array = _smooth_along(raw, false, int(SMOOTH_REACH / SAMPLE_STEP))
	var ground := PackedFloat32Array()
	ground.resize(samples.size())
	var top := PackedFloat32Array()
	top.resize(samples.size())
	for k in range(samples.size()):
		var p: Vector2 = samples[k]["p"]
		var s: float = samples[k]["s"]
		var w: float = smoothstep(TURNOUT_HOLD, TURNOUT_HOLD + 46.0, s)
		var h: float = lerpf(_parent_ground(si, p), smooth[k], w)
		var pad: Vector2 = _pad_at(p.x, p.y)
		h = lerpf(h, pad.y, pad.x)
		ground[k] = h
		top[k] = h + RAIL_LIFT
	# Packed arrays are values: store them once they are filled.
	_spurs[si]["ground"] = ground
	_spurs[si]["top"] = top


## The spur's rail-top height at distance `s` along it.
func _spur_top_at(si: int, s: float) -> float:
	return _spur_ground_at(si, s) + RAIL_LIFT


## Distance from `p` to the nearest yard track.
func _spur_distance(p: Vector2) -> float:
	var best := 1e9
	for sp in _spurs:
		for sm in sp["samples"]:
			best = minf(best, p.distance_to(sm["p"]))
	return best


func _in_turnout(kind: String, index: int, s: float) -> bool:
	for t in _turnouts:
		if t["through"]["kind"] == kind and int(t["through"]["index"]) == index:
			if s >= float(t["s0"]) - 0.5 and s <= float(t["s0"]) + float(t["zone_end"]) + 3.0:
				return true
	return false


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
	_rs_line = PackedInt32Array()
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
				cut = PORTAL_CUT
				flat = PORTAL_FLAT
			_push_sample(Vector3(p2.x, _rail_height(ri, s), p2.y), right, s, 1, flat, cut, RAIL_FILL,
					first + k + 1 if link else -1, false, ri)
	for si in range(_spurs.size()):
		var sm: Array = _spurs[si]["samples"]
		var gr: PackedFloat32Array = _spurs[si]["ground"]
		var first2: int = _rs_pos.size()
		for k in range(sm.size()):
			var q: Vector2 = sm[k]["p"]
			var rv: Vector2 = _right_of(float(sm[k]["th"]))
			_push_sample(Vector3(q.x, gr[k], q.y), Vector3(rv.x, 0.0, rv.y), float(sm[k]["s"]), 1, RAIL_FLAT + 1.0, RAIL_CUT, RAIL_FILL,
					first2 + k + 1 if k < sm.size() - 1 else -1, false, 100 + si)
	print("  samples: %d on the lap, %d on the rails and the yard" % [base, _rs_pos.size() - base])


## `line`: the railway's index, 100 + a yard track's, -1 for the lap.
func _push_sample(pos: Vector3, right: Vector3, s: float, kind: int, flat: float, cut: float, fill: float, next: int, _closed: bool, line := -1) -> void:
	var idx: int = _rs_pos.size()
	_rs_line.append(line)
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
##
## Behind a tunnel portal (inside the hill, over its tunnel) a railway's own segments are left out: the last ones
## outside would cut a bowl round the mouth that ran on into the hill and up through the lining, and the trains drove
## into a slope of rock. There the hill is held at least PORTAL_COVER over the lining's crown, and no higher than the
## facade's top (or the cutting's walls beside it) plus PORTAL_RISE per metre back, so it rises from the facade's top
## instead of standing over it as a cliff.
func _grade(h: float, x: float, z: float) -> Vector2:
	var cx: int = floori(x / CELL)
	var cz: int = floori(z / CELL)
	var upper := 1e9
	var lower := -1e9
	var touched := false
	var flat_y := NAN
	var flat_lat := 1e9
	var behind: Array = _behind_portal(x, z)
	var skip_line: int = int(_portals[int(behind[0])]["line"]) if int(behind[0]) >= 0 else -999
	for gz in range(cz - 1, cz + 2):
		for gx in range(cx - 1, cx + 2):
			var bucket: PackedInt32Array = _rs_cells.get(Vector2i(gx, gz), PackedInt32Array())
			for i in bucket:
				var j: int = _rs_next[i]
				if j < 0 or _rs_line[i] == skip_line:
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
	var res: float = h
	if touched:
		res = upper if lower > upper else clampf(h, lower, upper)
	if int(behind[0]) >= 0:
		var pd: Dictionary = _portals[int(behind[0])]
		var e: float = behind[1]
		var lat: float = behind[2]
		var al: float = absf(lat)
		var top_y: float = pd["pos"].y
		var over2: float = maxf(0.0, al - PORTAL_FLAT)
		var cut_wall: float = float(pd["ground"]) + over2 * over2 / (over2 + 4.0) * PORTAL_CUT
		var cap: float = maxf(top_y + _facade_top(pd, lat), cut_wall) + maxf(e - FreightKit.PORTAL_BACK, 0.0) * PORTAL_RISE
		var cover := -1e9
		if al < FreightKit.PORTAL_HW + 2.5 and e < FreightKit.PORTAL_BACK + FreightKit.PORTAL_DEPTH + 2.0:
			cover = top_y + FreightKit.PORTAL_CROWN + PORTAL_COVER
		res = clampf(res, cover, maxf(cap, cover))
		return Vector2(res, NAN)
	if not touched:
		return Vector2(h, NAN)
	return Vector2(res, flat_y)


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


## One axis of the terrain grid: FINE_STEP over the fine range, growing outward to the horizon, halved inside the
## `refine` ranges ([lo, hi]), and with a line exactly on each of `exact` (a portal's face and back): lines within 1m
## of one give way to it.
func _grid_axis(fine: Vector2, outer: Vector2, refine: Array = [], exact: Array = []) -> PackedFloat32Array:
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
	if not refine.is_empty():
		var dense := PackedFloat32Array()
		for i in range(out.size()):
			dense.append(out[i])
			if i + 1 < out.size():
				var mid: float = (out[i] + out[i + 1]) * 0.5
				for r in refine:
					if mid >= float(r[0]) and mid <= float(r[1]):
						dense.append(mid)
						break
		out = dense
	if not exact.is_empty():
		var kept: Array = []
		for v in out:
			var clear := true
			for e in exact:
				if absf(v - float(e)) < 1.0:
					clear = false
			if clear:
				kept.append(v)
		for e in exact:
			kept.append(float(e))
		kept.sort()
		out = PackedFloat32Array(kept)
	return out


func _build_heights() -> void:
	# Across each cutting (z for the Main Line, x for the Branch) the grid is halved, and lines run exactly along each
	# portal's face and back, so the cutting's walls are smooth and the step from the cutting's floor up to the hill over
	# the lining falls inside the facade's thickness (see _grade and _build_terrain).
	var refine_x: Array = []
	var refine_z: Array = []
	var exact_x: Array = []
	var exact_z: Array = []
	for pd in _portals:
		var p: Vector3 = pd["pos"]
		var into: Vector2 = pd["into"]
		if absf(into.x) > 0.5:
			refine_z.append([p.z - PORTAL_REFINE, p.z + PORTAL_REFINE])
			exact_x.append_array([p.x, p.x + into.x * FreightKit.PORTAL_BACK])
		else:
			refine_x.append([p.x - PORTAL_REFINE, p.x + PORTAL_REFINE])
			exact_z.append_array([p.z, p.z + into.y * FreightKit.PORTAL_BACK])
	_grid_x = _grid_axis(FINE_X, OUTER_X, refine_x, exact_x)
	_grid_z = _grid_axis(FINE_Z, OUTER_Z, refine_z, exact_z)
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
	var rock: float = 1.0 - smoothstep(0.5, 0.86, nrm_y)
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


## Whether a ground triangle (by its centre) lies under a portal's arch inside the facade's thickness, where the ground
## steps from the cutting's floor up over the lining: such cells are left out of the drawn ground (they keep their
## collision, which also stops a cart driving into the tunnel), so the arch shows the lining and not a slope of rock.
func _in_portal_hole(c: Vector3) -> bool:
	for pd in _portals:
		var rel := Vector2(c.x - pd["pos"].x, c.z - pd["pos"].z)
		var e: float = rel.dot(pd["into"])
		if e > 0.0 and e < FreightKit.PORTAL_BACK and absf(rel.dot(pd["right"])) < FreightKit.PORTAL_HW + 2.2:
			return true
	return false


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
				if not _in_portal_hole((p0 + p1 + p2) / 3.0):
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
		# Track pieces over every stretch outside the hills, and the bed's collision.
		var piece: Array = []
		var bed: Array = []
		var piece_no := 0
		var faces: Array = []
		# The line's points beyond each piece's ends (outside the hills), for the joints' mitres.
		var beyond := func(k: int):
			return pts[k] if k >= 0 and k < n and outside[k] else null
		var k_start := 0
		for k in range(n):
			if not outside[k]:
				if piece.size() > 1:
					piece_no = _flush_track(root, ri, piece, bed, piece_no, faces, beyond.call(k_start - 1), null)
				piece = []
				bed = []
				continue
			if piece.is_empty():
				k_start = k
			piece.append(pts[k])
			if piece.size() > 1:
				var mid_s: float = (float(s_at[k]) + float(s_at[k - 1])) * 0.5
				bed.append(not _near_crossing(ri, mid_s, DECK_HALF_LEN + 1.5) and not _in_turnout("rail", ri, mid_s))
			if piece.size() > TRACK_PIECE:
				piece_no = _flush_track(root, ri, piece, bed, piece_no, faces, beyond.call(k_start - 1), beyond.call(k + 1))
				piece = [pts[k]]
				bed = []
				k_start = k
		if piece.size() > 1:
			piece_no = _flush_track(root, ri, piece, bed, piece_no, faces, beyond.call(k_start - 1), null)
		_bed_body(root, "RailBed_%s" % info["name"], faces)
		var stretch := PackedVector3Array()
		for k in range(n):
			if outside[k]:
				stretch.append(pts[k])
			elif stretch.size() > 1:
				_rumble_lines.append(stretch)
				stretch = PackedVector3Array()
			else:
				stretch = PackedVector3Array()
		if stretch.size() > 1:
			_rumble_lines.append(stretch)
		# The trains.
		for tr in info["trains"]:
			var train := Node3D.new()
			train.name = "%s%sTrain" % [info["name"], tr["name"]]
			train.set_script(load("res://Train.gd"))
			train.set("path", curve)
			train.set("consist", PackedStringArray(tr["consist"]))
			train.set("speed", float(tr["speed"]))
			train.set("period", float(tr["period"]))
			train.set("phase", float(tr.get("phase", 0.0)))
			level_scene.add_child(train)
			var length_m: float = _consist_length(tr["consist"])
			var turn_s: float = (len_r + length_m) / float(tr["speed"])
			print("  %s %s: %d cars, %.0fm, %.0f m/s, every %.0fs (a turn on the line takes %.0fs)" % [
				info["name"], tr["name"], (tr["consist"] as Array).size(), length_m, float(tr["speed"]), float(tr["period"]), turn_s])
			if turn_s > float(tr["period"]):
				push_error("%s %s needs %.0fs to clear the line but runs every %.0fs" % [info["name"], tr["name"], turn_s, float(tr["period"])])
		# Two trains on a line must not overlap: each one's turn [phase, phase + turn] within the period.
		var turns: Array = []
		for tr in info["trains"]:
			turns.append([float(tr.get("phase", 0.0)), float(tr.get("phase", 0.0)) + (len_r + _consist_length(tr["consist"])) / float(tr["speed"]), float(tr["period"])])
		for i in range(turns.size()):
			for j in range(i + 1, turns.size()):
				var period_j: float = turns[i][2]
				var a0: float = turns[i][0]
				var a1: float = turns[i][1]
				var b0: float = turns[j][0]
				var b1: float = turns[j][1]
				for shift in [-period_j, 0.0, period_j]:
					if a0 < b1 + shift and b0 + shift < a1:
						push_error("%s: trains %d and %d overlap on the line" % [info["name"], i, j])
	_build_local_train(level_scene)
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
		var paths := PackedStringArray()
		for tr in _rails[ri]["trains"]:
			paths.append("../%s%sTrain" % [_rails[ri]["name"], tr["name"]])
		# The local passes the crossings on the Main Line between its west end and T1, both ways.
		if ri == 0 and float(c["rail_s"]) < float(_turnouts[0]["s0"]):
			paths.append("../%s" % LOCAL_NAME)
		cn.set("train_paths", paths)
		cn.set("train_s", float(c["rail_s"]))
		cn.set("road_half", ROAD_HALF)
		level_scene.add_child(cn)
		if int(info_of(ri).get("kicker", 0)) == 1:
			_build_kicker(level_scene, c, ci, cn)
		c["node_name"] = cn.name
		print("  crossing %d: %s at lap %.0fm (skew %.0f deg)" % [ci, _rails[ri]["name"], lap_s, rad_to_deg(acos(skew))])


## A masonry portal where each railway goes into a hill (planned by _plan_portals): its wings' tops follow the hill,
## the track runs on into the dark lining, black veils inside it fade a train into the dark (`TunnelFog_*`, a mesh of
## its own: DressingColliders leaves anything named "fog" soft), and a plaque names the tunnel.
const PORTAL_NAMES := ["TUNEL DE LA SIERRA", "TUNEL DEL OESTE", "TUNEL DEL VIENTO", "TUNEL DEL NORTE", "TUNEL DE LA CUMBRE", "TUNEL DEL ESTE"]

func _build_portals(level_scene: Node3D) -> void:
	var root := Node3D.new()
	root.name = "TunnelPortals"
	level_scene.add_child(root)
	var count := 0
	for pd in _portals:
		var ri: int = pd["line"]
		var len_r: float = _rail_len(ri)
		var into := Vector3(pd["into"].x, 0.0, pd["into"].y)
		var right := Vector3(pd["right"].x, 0.0, pd["right"].y)
		var basis := Basis(-right, Vector3.UP, into)
		var xf := Transform3D(basis, pd["pos"])
		var pk := FreightKit.new_kit()
		pk.reset_frame()
		var kit := {}
		FreightKit.portal(pk, kit, pd["wing_l"], pd["wing_r"], pd["top"])
		var mesh: ArrayMesh = _save_baked_resource(pk.commit(kit), "portal_%d" % count) as ArrayMesh
		_instance_mesh(root, "Portal_%s_%d" % [_rails[ri]["name"], count], mesh, xf)
		var fk := {}
		FreightKit.tunnel_fog(pk, fk)
		var fog: MeshInstance3D = _instance_mesh(root, "TunnelFog_%d" % count, _save_baked_resource(pk.commit(fk), "tunnel_fog") as ArrayMesh, xf)
		fog.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var plaque_y: float = (11.35 + float(pd["top"])) * 0.5
		_label(root, PORTAL_NAMES[count % PORTAL_NAMES.size()], xf.origin + basis * Vector3(0.0, plaque_y, -0.6), Basis(basis * Basis(Vector3.UP, PI)), 0.017, Color(0.95, 0.9, 0.78), 56,
				10.5)
		# The track runs on into the lining.
		var out_s: float = pd["out_s"]
		var sgn: float = signf(Vector2(pd["into"]).dot((_rails[ri]["b"] - _rails[ri]["a"]).normalized()))
		var pts: Array = []
		var bed: Array = []
		var d2 := 0.0
		while d2 <= FreightKit.PORTAL_BACK + FreightKit.PORTAL_DEPTH:
			var q: Vector2 = _rail_at(ri, out_s + sgn * d2)
			pts.append(Vector3(q.x, _rail_top(ri, clampf(out_s + sgn * d2, 0.0, len_r)), q.y))
			if pts.size() > 1:
				bed.append(true)
			d2 += SAMPLE_STEP
		# Inside the tunnels: no solid surface (nobody drives in there).
		var sink = FreightKit.solid_sink
		FreightKit.solid_sink = null
		_instance_mesh(root, "PortalTrackBed_%d" % count, FreightKit.track_piece(pts, bed, 900 + count), Transform3D.IDENTITY)
		FreightKit.solid_sink = sink
		count += 1
	print("  %d tunnel portals" % count)


## The yard's track: each spur's rails, ballast and sleepers outside its turnout, the turnouts themselves (rails,
## blades, frog, check rail, stretcher bars, switch stand, one bed), and a buffer stop at the end of each track.
func _build_yard(level_scene: Node3D) -> void:
	var root := Node3D.new()
	root.name = "YardTracks"
	level_scene.add_child(root)
	for si in range(_spurs.size()):
		var sp: Dictionary = _spurs[si]
		var samples: Array = sp["samples"]
		var top: PackedFloat32Array = sp["top"]
		var tn: Dictionary = {}
		for t in _turnouts:
			if int(t["spur"]) == si:
				tn = t
		# The stretch inside the turnout is the turnout's own: the track starts at the last sample its rails reach.
		var k0 := 0
		if not tn.is_empty():
			for k in range(samples.size()):
				if float(samples[k]["p"].x) - float(tn["x0"]) > float(tn["zone_end"]) + FreightKit.TURNOUT_RAILS:
					break
				k0 = k
		var piece: Array = []
		var bed: Array = []
		var piece_no := 0
		var faces: Array = []
		# The track's points beyond each piece's ends, for the joints' mitres (the first piece's comes off the turnout).
		var point_at := func(k: int):
			if k < 0 or k >= samples.size():
				return null
			var qq: Vector2 = samples[k]["p"]
			return Vector3(qq.x, top[k], qq.y)
		var k_start: int = k0
		for k in range(k0, samples.size()):
			var q: Vector2 = samples[k]["p"]
			piece.append(Vector3(q.x, top[k], q.y))
			if piece.size() > 1:
				var mid_s: float = (float(samples[k]["s"]) + float(samples[k - 1]["s"])) * 0.5
				bed.append(not _in_turnout("spur", si, mid_s))
			if piece.size() > TRACK_PIECE:
				_flush_spur_track(root, si, piece, bed, piece_no, faces, point_at.call(k_start - 1), point_at.call(k + 1))
				piece_no += 1
				piece = [piece[piece.size() - 1]]
				bed = []
				k_start = k
		if piece.size() > 1:
			_flush_spur_track(root, si, piece, bed, piece_no, faces, point_at.call(k_start - 1), null)
		_bed_body(root, "RailBed_%s" % sp["name"], faces)
		var centre := PackedVector3Array()
		for k in range(samples.size()):
			centre.append(Vector3(samples[k]["p"].x, top[k], samples[k]["p"].y))
		_rumble_lines.append(centre)
		# The buffer stop where the track ends.
		var last: Dictionary = samples[samples.size() - 1]
		var lp: Vector2 = last["p"]
		var lth: float = last["th"]
		var xf := Transform3D(Basis(Vector3.UP, PI * 0.5 - lth), Vector3(lp.x, top[top.size() - 1], lp.y))
		var pk := _scaled_kit(1.5)
		var kit := {}
		FreightKit.buffer_stop(pk, kit)
		var buffer_mesh: ArrayMesh = _save_baked_resource(pk.commit(kit), "buffer_stop") as ArrayMesh
		var bs_mi := _instance_mesh(root, "BufferStop_%d" % si, buffer_mesh, xf)
		var bs_body := StaticBody3D.new()
		bs_body.name = "BufferStop_Body"
		bs_body.set_meta(&"surface", "metal")
		# Solid impact front box covering base, buffer heads and crossbeam
		var front_box := BoxShape3D.new()
		front_box.size = Vector3(4.6 * 1.5, 2.4 * 1.5, 1.2 * 1.5)
		var front_col := CollisionShape3D.new()
		front_col.shape = front_box
		front_col.position = Vector3(0, 1.0 * 1.5, 0.5 * 1.5)
		bs_body.add_child(front_col)
		var bs_shape := buffer_mesh.create_trimesh_shape()
		if bs_shape:
			var bs_col := CollisionShape3D.new()
			bs_col.shape = bs_shape
			bs_body.add_child(bs_col)
		bs_mi.add_child(bs_body)
		_label(root, "FIN DE VIA", xf.origin + xf.basis * ((FreightKit.BUFFER_PLATE[0] as Vector3) * 1.5), Basis(xf.basis * Basis(Vector3.UP, PI)), 0.008,
				Color(0.97, 0.95, 0.9), 48, float(FreightKit.BUFFER_PLATE[1]) * 1.5)
	# The turnouts.
	for t in _turnouts:
		var through: Array = []
		var branch: Array = []
		var si2: int = int(t["spur"])
		var x0: float = t["x0"]
		var z0: float = t["z0"]
		var reach: float = float(t["zone_end"]) + 14.0
		var x := x0
		while x <= x0 + reach:
			var ty: float
			if t["through"]["kind"] == "rail":
				ty = _rail_top(int(t["through"]["index"]), x - float(_rails[int(t["through"]["index"])]["a"].x))
			else:
				ty = _spur_top_at(int(t["through"]["index"]), float(t["s0"]) + (x - x0))
			through.append(Vector3(x, ty, z0))
			x += 3.0
		var bs: Array = _spurs[si2]["samples"]
		var btop: PackedFloat32Array = _spurs[si2]["top"]
		for k in range(bs.size()):
			if float(bs[k]["p"].x) - x0 > reach:
				break
			branch.append(Vector3(bs[k]["p"].x, btop[k], bs[k]["p"].y))
		var info := {}
		var tfaces: Array = []
		var mesh: ArrayMesh = FreightKit.turnout(through, branch, float(t["side"]), info, tfaces)
		_instance_mesh(root, "TurnoutTrackBed_%s" % t["name"], _save_baked_resource(mesh, "turnout_%s" % String(t["name"]).to_lower()) as ArrayMesh, Transform3D.IDENTITY)
		_bed_body(root, "RailBed_%s" % t["name"], tfaces)
		# The switch stand beside the toe is solid: its base and post, and the lever reaching out over them (the bed's
		# mesh is skipped by DressingColliders, named for the track).
		if info.has("stand"):
			var sb := StaticBody3D.new()
			sb.name = "SwitchStand_%s" % t["name"]
			sb.set_meta(&"surface", "rock")
			# x out from the track (the way the lever reaches), y up.
			var sout: Vector3 = (info["stand_out"] as Vector3).normalized()
			var h: float = info["stand_h"]
			var lever: float = info["stand_reach"]
			sb.transform = Transform3D(Basis(sout, Vector3.UP, sout.cross(Vector3.UP)), info["stand"])
			var cs := CollisionShape3D.new()
			var bx := BoxShape3D.new()
			bx.size = Vector3(lever + 0.9, h, 0.9)
			cs.shape = bx
			cs.position = Vector3(lever * 0.5, h * 0.5, 0.0)
			sb.add_child(cs)
			root.add_child(sb)
		print("  turnout %s at x %.0f: zone %.1fm (the builder says %.1fm)" % [t["name"], x0, float(t["zone_end"]), float(info.get("zone_end", -1.0))])


func _flush_spur_track(root: Node3D, si: int, piece: Array, bed: Array, piece_no: int, faces: Array, before = null, after = null) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "TrackBed_%s_%d" % [_spurs[si]["name"], piece_no]
	mi.mesh = FreightKit.track_piece(piece, bed, piece_no + (si + 5) * 1000, faces, before, after)
	root.add_child(mi)


## A railway's bed as a solid body: FreightKit._bed_faces' hump, which a cart's sphere rolls over (up the ballast's
## shoulders and on over the rails), gravel to its tyres. Its name keeps clear of "track", "road", "ramp" and "deck",
## which PlayerCart takes for the lap's own surface.
func _bed_body(parent: Node3D, body_name: String, faces: Array) -> void:
	_rail_surface_body(parent, body_name.replace("RailBed", "RailSurface"))
	if faces.is_empty():
		return
	var body := StaticBody3D.new()
	body.name = body_name
	body.set_meta(&"surface", "gravel")
	body.set_meta(&"dust_color", Color(0.62, 0.58, 0.52, 0.5))
	parent.add_child(body)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(PackedVector3Array(faces))
	shape.backface_collision = true
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	cs.shape = _save_baked_resource(shape, body_name.to_snake_case() + "_shape")
	body.add_child(cs)


## The track's own surface as a solid body: the triangles FreightKit.track_piece and turnout drew since the last one
## (FreightKit.solid_sink: the ballast's shoulders, the sleepers, the rails), so a cart crossing a track off the road
## jolts over the sleepers and the rails as on Mina del Viento's rail loop, instead of gliding over the bed's smooth
## hump (which still lies under them, 15cm under the rails' tops, the hump's 7 degrees from 5.4m out, and keeps a cart
## from falling into the gaps). Gravel to the tyres, named clear of PlayerCart's track words. Not over the level
## crossings (RAIL_SURFACE_SKIP of each): the road's cars run on the planked deck there, flush with the rails.
const RAIL_SURFACE_SKIP := 13.0

func _rail_surface_body(parent: Node3D, body_name: String) -> void:
	var tris = FreightKit.solid_sink
	FreightKit.solid_sink = []
	if not (tris is Array) or (tris as Array).is_empty():
		return
	var faces := PackedVector3Array()
	var arr: Array = tris
	for i in range(0, arr.size() - 2, 3):
		var a: Vector3 = arr[i]
		var b: Vector3 = arr[i + 1]
		var c: Vector3 = arr[i + 2]
		var m := Vector2((a.x + b.x + c.x) / 3.0, (a.z + b.z + c.z) / 3.0)
		var skip := false
		for cr in _crossings:
			var q: Vector2 = cr["pos"]
			if m.distance_to(q) < RAIL_SURFACE_SKIP:
				skip = true
				break
		if not skip:
			faces.append_array([a, b, c])
	if faces.is_empty():
		return
	var body := StaticBody3D.new()
	body.name = body_name
	body.set_meta(&"surface", "gravel")
	body.set_meta(&"dust_color", Color(0.62, 0.58, 0.52, 0.5))
	parent.add_child(body)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	cs.shape = _save_baked_resource(shape, body_name.to_snake_case() + "_shape")
	body.add_child(cs)
	print("  %s: %d triangles" % [body_name, faces.size() / 3])


func info_of(ri: int) -> Dictionary:
	return _rails[ri]


## The length of a train: the sum of its cars (a gap is its own length in game metres).
func _consist_length(consist: Array) -> float:
	var total := 0.0
	for entry in consist:
		var parts: PackedStringArray = String(entry).split(":")
		if parts[0] == "gap":
			total += float(parts[1]) if parts.size() > 1 else 14.0
		else:
			total += TrainKit.car_length(parts[0].trim_prefix("~"))
	return total


## The local passenger train: a diesel at each end (the rear one turned round) and two coaches. It comes out of the
## west tunnel along the Main Line, takes turnout T1 onto the yard's lead and runs round into Estación Seca's
## platform, stands there, then backs out the way it came, onto the Main Line and away into the tunnel. Its path is
## the Main Line from its west end to T1 and the lead on to the buffer stop; it keeps a timetable of its own
## (Train.gd's `legs`) every LOCAL_PERIOD seconds, two of the Main Line's: in while the line between the tunnel and
## T1 is clear after the first freight, out after the second express. _verify_local checks it never meets them.
const LOCAL_NAME := "MainLineLocalTrain"
const LOCAL_CONSIST := ["ploco", "coach", "coach", "~ploco"]
const LOCAL_PERIOD := 250.0
## The head stops this far short of the buffer stop.
const LOCAL_STOP_SHORT := 7.0
## [start, end, ramp] of the run in and of the run out, seconds into its cycle.
const LOCAL_IN := [20.0, 82.0, 14.0]
const LOCAL_OUT := [198.0, 246.0, 12.0]

func _build_local_train(level_scene: Node3D) -> void:
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	var t1_s: float = _turnouts[0]["s0"]
	var s := 0.0
	while s < t1_s - 0.01:
		var p: Vector2 = _rail_at(0, s)
		curve.add_point(Vector3(p.x, _rail_top(0, s), p.y))
		s += SAMPLE_STEP
	var lead: Array = _spurs[0]["samples"]
	var top: PackedFloat32Array = _spurs[0]["top"]
	for k in range(lead.size()):
		var q: Vector2 = lead[k]["p"]
		curve.add_point(Vector3(q.x, top[k], q.y))
	var stop: float = curve.get_baked_length() - LOCAL_STOP_SHORT
	var train := Node3D.new()
	train.name = LOCAL_NAME
	train.set_script(load("res://Train.gd"))
	train.set("path", curve)
	train.set("consist", PackedStringArray(LOCAL_CONSIST))
	train.set("period", LOCAL_PERIOD)
	train.set("legs", PackedFloat32Array([LOCAL_IN[0], LOCAL_IN[1], 0.0, stop, LOCAL_IN[2], LOCAL_OUT[0], LOCAL_OUT[1], stop, 0.0, LOCAL_OUT[2]]))
	level_scene.add_child(train)
	print("  %s: %d cars, %.0fm, %.0fm of path, stands at the platform %.0f-%.0fs of every %.0fs" % [LOCAL_NAME, LOCAL_CONSIST.size(),
			_consist_length(LOCAL_CONSIST), curve.get_baked_length(), LOCAL_IN[1], LOCAL_OUT[0], LOCAL_PERIOD])
	_verify_local(stop, t1_s)


## Errors if the local and the Main Line's own trains are ever on the line between its west end and T1, or past T1
## where the yard lead still runs beside the main line (LOCAL_FOUL: closer than two cars' width and a margin), together
## (the local's leading end and its tail both counted, two Main Line cycles round). Without the stretch past T1 the
## Express's observation car and the local's rear diesel brushed each other there as the local backed out. On a clash
## it lists the starts of the run out (and in) that would be clear, keeping each run's length.
const LOCAL_FOUL := 60.0

func _verify_local(stop: float, t1_s: float) -> void:
	var clashes := _local_clashes(LOCAL_IN, LOCAL_OUT, stop, t1_s, true)
	print("  local checked against the Main Line's trains to %.0fm past T1: %d clashes" % [LOCAL_FOUL, clashes])
	if clashes == 0:
		return
	# [start, length] of runs out that would be clear, the run in as it is, slowest first.
	var ok_out: Array = []
	var dur := float(LOCAL_OUT[1]) - float(LOCAL_OUT[0])
	while dur >= 26.0 and ok_out.size() < 12:
		var st := float(LOCAL_IN[1]) + 5.0
		while st + dur <= LOCAL_PERIOD - 2.0:
			if _local_clashes(LOCAL_IN, [st, st + dur, LOCAL_OUT[2]], stop, t1_s, false) == 0:
				ok_out.append("%.0f+%.0fs (%.0f m/s on average)" % [st, dur, stop / (dur - float(LOCAL_OUT[2]))])
			st += 1.0
		dur -= 2.0
	print("  the run out is %.0fm; clear runs out (start+length): %s" % [stop, ", ".join(ok_out)])


func _local_clashes(leg_in: Array, leg_out: Array, stop: float, t1_s: float, report: bool) -> int:
	var length: float = _consist_length(LOCAL_CONSIST)
	var trains: Array = _rails[0]["trains"]
	var zone: float = t1_s + LOCAL_FOUL
	var clashes := 0
	var t := 0.0
	while t < LOCAL_PERIOD:
		var head: float = _local_head(t, stop, leg_in, leg_out)
		# The part of the local on the shared stretch and beside the main line past T1.
		var a: float = maxf(head - length, 0.0)
		var b: float = minf(head, zone)
		if b > a:
			for tr in trains:
				var th: float = fposmod(t - float(tr["phase"]), float(tr["period"])) * float(tr["speed"])
				var ta: float = maxf(th - _consist_length(tr["consist"]), 0.0)
				var tb: float = minf(th, zone)
				if tb > ta and ta < b + 20.0 and a < tb + 20.0:
					clashes += 1
					if report and clashes < 4:
						push_error("the local meets the %s at %.1fs (local %.0f-%.0fm, it %.0f-%.0fm)" % [tr["name"], t, a, b, ta, tb])
		t += 0.25
	return clashes


## The local's head along its path `t` seconds into its cycle (as Train.gd's legs).
func _local_head(t: float, stop: float, leg_in: Array = LOCAL_IN, leg_out: Array = LOCAL_OUT) -> float:
	var legs: Array = [[leg_in[0], leg_in[1], 0.0, stop, leg_in[2]], [leg_out[0], leg_out[1], stop, 0.0, leg_out[2]]]
	var head := 0.0
	for lg in legs:
		if t < float(lg[0]):
			return head
		if t <= float(lg[1]):
			var dur: float = float(lg[1]) - float(lg[0])
			var u: float = (t - float(lg[0])) / dur
			var ar: float = clampf(float(lg[4]) / dur, 0.001, 0.5)
			var f: float = (u - ar * 0.5) / (1.0 - ar)
			if u <= ar:
				f = u * u / (2.0 * ar) / (1.0 - ar)
			elif u >= 1.0 - ar:
				f = 1.0 - (1.0 - u) * (1.0 - u) / (2.0 * ar) / (1.0 - ar)
			return float(lg[2]) + (float(lg[3]) - float(lg[2])) * f
		head = lg[3]
	return head


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


func _flush_track(root: Node3D, ri: int, piece: Array, bed: Array, piece_no: int, faces: Array, before = null, after = null) -> int:
	var mi := MeshInstance3D.new()
	mi.name = "TrackBed_%s_%d" % [_rails[ri]["name"], piece_no]
	mi.mesh = FreightKit.track_piece(piece, bed, piece_no + ri * 1000, faces, before, after)
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


## A label `pixel` metres a font pixel, shrunk to fit `max_w` metres (0: any width) when it would run past its board.
func _label(parent: Node3D, text: String, at: Vector3, basis: Basis, pixel: float, col: Color, size := 64, max_w := 0.0) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = _fit_pixel(text, size, pixel, max_w)
	l.modulate = col
	l.outline_size = 8
	l.outline_modulate = Color(0.05, 0.05, 0.05)
	# One-sided: from behind a plate or a facade the letters read backwards.
	l.double_sided = false
	l.transform = Transform3D(basis, at)
	parent.add_child(l)


## The yard's buildings are YardKit's and FactoryKit's (life size, grown by PROP_SCALE through their own kit), each
## one mesh under "Depot" saved under `YARD_PREFIX` so MeshChunker leaves it whole and DressingColliders makes it solid.
## The station stands south of the platform track with its platform between them (its frame's origin `STATION_BACK`
## beyond the track, so the platform's edge is 2.6m from the track's centre); the grain cooperative stands north of the
## factory track, its loadout gantry straddling it at `FACTORY_X`; the water tower is east of the platform track's end.
const YARD_PREFIX := "freightyard_"
const STATION_X := -180.0
const STATION_BACK := 37.2
const PLATFORM_EDGE := 2.6
const FACTORY_X := -13.5
const WATER_TOWER_AT := Vector2(-84.0, 192.0)

func _build_depot(level_scene: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Depot"
	level_scene.add_child(root)
	var h: float = _pads[0]["h"]
	var p_samples: Array = _spurs[0]["samples"]
	var f_samples: Array = _spurs[1]["samples"]
	var z_p: float = p_samples[p_samples.size() - 1]["p"].y
	var z_f: float = f_samples[f_samples.size() - 1]["p"].y
	# The station, its goods shed and the platform.
	var pk := YardKit.new_kit(PROP_SCALE)
	var kit := {}
	var labels: Array = []
	var z_edge: float = (PLATFORM_EDGE - STATION_BACK) / PROP_SCALE
	YardKit.station(pk, kit, labels)
	YardKit.platform(pk, kit, -32.0, 40.0, -12.0, z_edge, true, true, labels)
	YardKit.goods_shed(pk, kit, -30.0, -4.0, labels)
	var origin := Vector3(STATION_X, h, z_p + STATION_BACK)
	_instance_mesh(root, "Station", _save_baked_resource(YardKit.commit(pk, kit), "station", YARD_PREFIX), Transform3D(Basis(), origin))
	_yard_labels(root, labels, origin)
	# The grain cooperative.
	pk = YardKit.new_kit(PROP_SCALE)
	kit = {}
	labels = []
	FactoryKit.factory(pk, kit, labels)
	origin = Vector3(FACTORY_X, h, z_f - FactoryKit.TRACK_Z * PROP_SCALE)
	_instance_mesh(root, "GrainCooperative", _save_baked_resource(YardKit.commit(pk, kit), "cooperative", YARD_PREFIX), Transform3D(Basis(), origin))
	_yard_labels(root, labels, origin)
	# The water tower by the end of the platform track.
	pk = _scaled_kit(PROP_SCALE)
	kit = {}
	FreightKit.water_tower(pk, kit)
	_instance_mesh(root, "TankTower", _save_baked_resource(pk.commit(kit), "tank_tower", YARD_PREFIX), Transform3D(Basis(), Vector3(WATER_TOWER_AT.x, h, WATER_TOWER_AT.y)))
	# Stock standing on the yard: the yard switcher with three grain hoppers on the factory track, the first one under
	# the loadout's spout. (The platform is the local's: see _build_local_train.)
	_park_train(root, "LoadingHoppers", 1, ["hopper", "hopper:1", "hopper", "loco:2"], 0.0, false, FACTORY_X)
	print("  depot built on a pad at %.1fm (station at x %.0f, z %.0f; cooperative at x %.0f, z %.0f)" % [h, STATION_X, z_p + STATION_BACK, FACTORY_X, origin.z])


## The pixel size at which `text` at `font_size` (Label3D's default font, which ThemeDB measures headless too) is no
## wider than `max_w` metres, at most `pixel`. Signs' letters ran past their boards.
func _fit_pixel(text: String, font_size: int, pixel: float, max_w: float) -> float:
	if max_w <= 0.0:
		return pixel
	var w: float = ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if w * pixel <= max_w:
		return pixel
	print("  sign '%s' shrunk to fit %.2fm (it was %.2fm)" % [text, max_w, w * pixel])
	return max_w / maxf(w, 1.0)


## Letters for a yard building's signs: `labels` are [text, position, outward normal, cap height, colour] in the kit's
## own units, placed by the building's origin and PROP_SCALE.
func _yard_labels(parent: Node3D, labels: Array, origin: Vector3) -> void:
	for l in labels:
		var lab := Label3D.new()
		lab.text = l[0]
		lab.font_size = 64
		lab.pixel_size = _fit_pixel(l[0], 64, float(l[3]) * PROP_SCALE / 44.8, float(l[5]) * PROP_SCALE if l.size() > 5 else 0.0)
		lab.modulate = l[4]
		lab.outline_size = 4
		lab.outline_modulate = Color(0.05, 0.05, 0.05)
		lab.double_sided = false
		var n: Vector3 = l[2]
		lab.transform = Transform3D(Basis.looking_at(-n, Vector3.UP), origin + (l[1] as Vector3) * PROP_SCALE)
		parent.add_child(lab)


## A train standing still on yard track `si`: the head `from_end` metres short of the track's end, or (with `at_x`) the
## middle of the first car at that x. It runs on the wall clock like the others, held at one clock reading.
func _park_train(parent: Node3D, node_name: String, si: int, consist: Array, from_end: float, _at_end: bool, at_x := 1.0e9) -> void:
	var samples: Array = _spurs[si]["samples"]
	var top: PackedFloat32Array = _spurs[si]["top"]
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	for k in range(samples.size()):
		var q: Vector2 = samples[k]["p"]
		curve.add_point(Vector3(q.x, top[k], q.y))
	var length: float = curve.get_baked_length()
	var head: float = length - from_end
	if at_x < 1.0e8:
		# Along the track to the point at `at_x`, then half the first car on (the head leads the car's middle by half).
		var s_at := 0.0
		for k in range(1, samples.size()):
			if float(samples[k]["p"].x) >= at_x:
				var x0: float = samples[k - 1]["p"].x
				var x1: float = samples[k]["p"].x
				s_at = lerpf(float(samples[k - 1]["s"]), float(samples[k]["s"]), (at_x - x0) / maxf(x1 - x0, 0.0001))
				break
		head = s_at + TrainKit.car_length(String(consist[0]).split(":")[0]) * 0.5
	var train := Node3D.new()
	train.name = node_name
	train.set_script(load("res://Train.gd"))
	train.set("path", curve)
	train.set("consist", PackedStringArray(consist))
	train.set("speed", 1.0)
	train.set("period", 1.0e6)
	train.set("kills", false)
	train.set("sounds", false)
	train.set("clock_override", head)
	parent.add_child(train)
	print("  %s: %d cars, head %.0fm along a %.0fm track" % [node_name, consist.size(), head, length])


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
			# No pole in a portal's cutting (it stood on the cut wall, in front of the facade).
			if _in_hill(p) or _portal_distance(p) < 36.0 or _near_crossing(ri, s, 34.0) or _near_pad(q, 10.0) or _spur_distance(q) < 12.0:
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
			_label(root, "RR", pos + basis * Vector3(0.0, 3.8 * 1.4 - 0.15, 0.2), basis, 0.012, Color(0.05, 0.05, 0.05), 64, 1.6)


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
		sage_meshes.append(_save_baked_resource(FreightKit.sage(100 + v), "sage_%d" % v) as ArrayMesh)
	# Rocks: weathered boulders (FreightKit.boulder) in canyon_rock.gdshader, the hills' sandstone beds tinted toward the
	# plain's tan. "rock_l" are low and wide (a cart rides over them), "rock_t" rounder and taller.
	var rock_mat := ShaderMaterial.new()
	rock_mat.shader = load("res://canyon_rock.gdshader")
	rock_mat.set_shader_parameter("sand_tex", load("res://materials/sand.png"))
	rock_mat.set_shader_parameter("rock_tex", load("res://materials/dark_rock.png"))
	rock_mat.set_shader_parameter("rock_normal", _rock_normal)
	rock_mat.set_shader_parameter("sand_tint", Color(0.70, 0.55, 0.40))
	rock_mat.set_shader_parameter("tint", Color(0.80, 0.66, 0.52))
	rock_mat.set_shader_parameter("tint_amount", 0.7)
	rock_mat = _save_baked_resource(rock_mat, "rock_material") as ShaderMaterial
	var rock_meshes := {}
	for v in 4:
		rock_meshes["rock_l%d" % v] = _save_baked_resource(FreightKit.boulder(4300 + v, Vector3(1.4, 0.62, 1.15), rock_mat), "rock_l%d" % v)
		rock_meshes["rock_t%d" % v] = _save_baked_resource(FreightKit.boulder(4320 + v, Vector3(1.0, 0.95, 0.88), rock_mat), "rock_t%d" % v)

	# Hull vertices for each boulder mesh to bake precise collision shapes for large immovable rocks.
	var rock_hull_points := {}
	for rk in rock_meshes.keys():
		var rm: ArrayMesh = rock_meshes[rk]
		var pts := PackedVector3Array()
		var seen_pts := {}
		for si in range(rm.get_surface_count()):
			var verts: PackedVector3Array = rm.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
			for v in verts:
				var k := Vector3i(roundi(v.x * 200.0), roundi(v.y * 200.0), roundi(v.z * 200.0))
				if not seen_pts.has(k):
					seen_pts[k] = true
					pts.append(v)
		rock_hull_points[rk] = pts

	# Rock clusters across the circuit: carts can push through them, but get significantly slowed down.
	var clusters_parent := Node3D.new()
	clusters_parent.name = "RockClusters"
	root.add_child(clusters_parent)

	var cells := {}
	var placed := 0
	var large_boulders_xfs: Array = []
	var cluster_s := 30.0
	var cluster_idx := 0
	while cluster_s < float(_lap["len"]) - 40.0:
		var side: float = -1.0 if rng.randf() < 0.5 else 1.0
		var lat: float = side * rng.randf_range(ROAD_HALF + 3.2, ROAD_HALF + 24.0)
		var sp: Dictionary = _spot(cluster_s, lat, 0.0)
		var cpos: Vector3 = sp["pos"]
		if _flora_ok(Vector2(cpos.x, cpos.z)):
			var num_rocks := rng.randi_range(5, 8)
			var cluster_r := rng.randf_range(2.0, 3.8)
			var cluster_kind: String = "rock_l%d" % rng.randi_range(0, 3)
			var cluster_mesh: ArrayMesh = rock_meshes[cluster_kind]
			var cluster_xfs: Array[Transform3D] = []
			var cluster_radii: Array[float] = []

			for ri in range(num_rocks):
				var ang: float = rng.randf() * TAU
				var rdist: float = rng.randf_range(0.3, cluster_r)
				var rpos: Vector3 = cpos + Vector3(cos(ang) * rdist, 0.0, sin(ang) * rdist)
				if not _flora_ok(Vector2(rpos.x, rpos.z)):
					continue
				var rh: float = rng.randf_range(0.35, 0.78)
				var r_xf: Transform3D = _rock_xf(cluster_kind, rh, rng.randf() * TAU, rpos, cluster_mesh)
				cluster_xfs.append(r_xf)
				cluster_radii.append(rh * 0.7)

			if cluster_xfs.size() >= 3:
				var kr := MultiMeshInstance3D.new()
				kr.name = "RockCluster_%d" % cluster_idx
				kr.set_script(load("res://KnockableRocks.gd"))
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = cluster_mesh
				mm.instance_count = cluster_xfs.size()
				mm.buffer = PropKit.transform_buffer(cluster_xfs)
				kr.multimesh = mm
				kr.set("rock_transforms", cluster_xfs)
				kr.set("rock_radii", cluster_radii)
				kr.set("cluster_drag", 7.5)
				kr.set_meta(&"skip_dressing_colliders", true)
				clusters_parent.add_child(kr)
				cluster_idx += 1

				# In ~40% of clusters, an immovable anchor boulder
				if rng.randf() < 0.40:
					var anchor_ang: float = rng.randf() * TAU
					var anchor_pos: Vector3 = cpos + Vector3(cos(anchor_ang) * 0.9, 0.0, sin(anchor_ang) * 0.9)
					if _flora_ok(Vector2(anchor_pos.x, anchor_pos.z)):
						var anchor_kind: String = "rock_t%d" % rng.randi_range(0, 3)
						var anchor_h: float = rng.randf_range(1.4, 2.2)
						var anchor_xf: Transform3D = _rock_xf(anchor_kind, anchor_h, rng.randf() * TAU, anchor_pos, rock_meshes[anchor_kind])
						large_boulders_xfs.append([anchor_xf, anchor_kind])
						var akey := "rock_large_%s|%d|%d" % [anchor_kind, floori(anchor_pos.x / 160.0), floori(anchor_pos.z / 160.0)]
						if not cells.has(akey):
							cells[akey] = []
						cells[akey].append(anchor_xf)
						placed += 1

		cluster_s += rng.randf_range(48.0, 72.0)

	# Candidate spots along the lap: both sides, closer in more of them.
	var s := 0.0
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
			var rock_xf := Transform3D()
			var is_rock := false
			if roll < 0.62:
				kind = "sage_%d" % rng.randi_range(0, 2)
				scl = rng.randf_range(0.9, 2.2)
			elif roll < 0.80:
				var rk: Dictionary = _pick_rock(rng, absf(lat))
				var r_kind: String = rk["kind"]
				scl = rk["h"]
				rock_xf = _rock_xf(r_kind, scl, rng.randf() * TAU, pos, rock_meshes[r_kind])
				is_rock = true
				if scl >= 1.0:
					kind = "rock_large_" + r_kind
					large_boulders_xfs.append([rock_xf, r_kind])
				else:
					kind = r_kind
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
			cells[key].append(rock_xf if is_rock else Transform3D(basis, pos))
			placed += 1
		s += 6.0
	# Small stones right beside the road, where a cart that runs wide meets them.
	s = 0.0
	while s < float(_lap["len"]):
		if rng.randf() < 0.55:
			var side2: float = -1.0 if rng.randf() < 0.5 else 1.0
			var lat2: float = side2 * (ROAD_HALF + 1.7 + rng.randf() * rng.randf() * 34.0)
			var sp2: Dictionary = _spot(s + rng.randf_range(-2.0, 2.0), lat2, 0.0)
			var pos2: Vector3 = sp2["pos"]
			if _flora_ok(Vector2(pos2.x, pos2.z)):
				var h2: float = rng.randf_range(0.2, 0.55)
				var kind2: String = "rock_l%d" % rng.randi_range(0, 3)
				var key2 := "%s|%d|%d" % [kind2, floori(pos2.x / 160.0), floori(pos2.z / 160.0)]
				if not cells.has(key2):
					cells[key2] = []
				cells[key2].append(_rock_xf(kind2, h2, rng.randf() * TAU, pos2, rock_meshes[kind2]))
				placed += 1
		s += 5.0
	for key in cells.keys():
		var parts: PackedStringArray = String(key).split("|")
		var kind: String = parts[0]
		var mesh: Mesh
		var node_name: String
		var range_end := 600.0
		if kind.begins_with("sage"):
			mesh = sage_meshes[int(kind.substr(5))]
			node_name = "Sagebrush_%s_%s" % [parts[1], parts[2]]
			range_end = 260.0
		elif kind.begins_with("rock_large_"):
			var base_kind: String = kind.substr(11)
			mesh = rock_meshes[base_kind]
			node_name = "Boulders_Large_%s_%s_%s" % [base_kind, parts[1], parts[2]]
			range_end = 520.0
		elif kind.begins_with("rock"):
			mesh = rock_meshes[kind]
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
			if vr[1] > 0.0:
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if kind.begins_with("sage"):
				# Desert sagebrush shrubs: solid wobbling vegetation colliders
				mmi.set_meta(&"min_collider_height", 0.35)
			elif kind.begins_with("rock_large_"):
				# Large immovable boulders have their permanent collision shapes baked in BouldersBody
				mmi.set_meta(&"skip_dressing_colliders", true)
			elif kind.begins_with("rock"):
				# DressingColliders gives these the hull of the stone, not a box, and lets even the low ones
				# (down to 15cm) be felt: a cart rides over a small one, hopping if it is fast.
				mmi.set_meta(&"hull_collider", true)
				mmi.set_meta(&"min_collider_height", 0.15)
			root.add_child(mmi)

	# Build explicit StaticBody3D with individual ConvexPolygonShape3Ds for all large immovable boulders
	var boulders_body := StaticBody3D.new()
	boulders_body.name = "BouldersBody"
	boulders_body.collision_layer = 1
	boulders_body.collision_mask = 1
	boulders_body.set_meta(&"surface", "rock")
	root.add_child(boulders_body)

	for bi in range(large_boulders_xfs.size()):
		var entry: Array = large_boulders_xfs[bi]
		var b_xf: Transform3D = entry[0]
		var b_kind: String = entry[1]
		var pts: PackedVector3Array = rock_hull_points[b_kind]
		var sc: Vector3 = b_xf.basis.get_scale()
		var scaled_pts := PackedVector3Array()
		for pt in pts:
			scaled_pts.append(pt * sc)
		var hull := ConvexPolygonShape3D.new()
		hull.points = scaled_pts

		var cs := CollisionShape3D.new()
		cs.name = "Boulder_%d" % bi
		cs.shape = hull
		cs.transform = Transform3D(b_xf.basis.orthonormalized(), b_xf.origin)
		boulders_body.add_child(cs)

	print("  desert: %d plants and rocks in %d cells, %d clusters, %d large boulders in BouldersBody" % [placed, cells.size(), cluster_idx, large_boulders_xfs.size()])


## A rock's size and shape: mostly small low stones (under 60cm, a cart rides over them), some medium ones and a
## few big ones, kept off the road by their size (`lat` is the lateral distance from the road's centre).
func _pick_rock(rng: RandomNumberGenerator, lat: float) -> Dictionary:
	var roll: float = rng.randf()
	if roll < 0.64 or lat < 12.5:
		return {"kind": "rock_l%d" % rng.randi_range(0, 3), "h": rng.randf_range(0.22, 0.60)}
	if roll < 0.93 or lat < 16.0:
		var tall: bool = rng.randf() < 0.5
		return {"kind": "rock_%s%d" % ["t" if tall else "l", rng.randi_range(0, 3)], "h": rng.randf_range(0.8, 1.5)}
	return {"kind": "rock_t%d" % rng.randi_range(0, 3), "h": rng.randf_range(1.6, 2.6)}


## A rock `h` high at `pos` (x and z), turned by `yaw`, at its mesh's own proportions. Its foot sits on the lowest
## ground under its footprint and a little lower, so no side of it hangs over a slope.
func _rock_xf(_kind: String, h: float, yaw: float, pos: Vector3, mesh: ArrayMesh) -> Transform3D:
	var size: Vector3 = mesh.get_aabb().size
	var sy: float = h / maxf(size.y, 0.05)
	var sxz: float = sy
	var half: float = maxf(size.x, size.z) * 0.5 * sxz * 0.85
	var lowest: float = _ground_at(pos.x, pos.z)
	for k in range(8):
		var a: float = TAU * float(k) / 8.0
		lowest = minf(lowest, _ground_at(pos.x + cos(a) * half, pos.z + sin(a) * half))
	return Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(sxz, sy, sxz)), Vector3(pos.x, lowest - 0.1 * h, pos.z))


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
	if _near_pad(p, 6.0) or _spur_distance(p) < 14.0:
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

	_build_big_jumps(level_scene)
	# Boost pads: out of the first corner, the far side of each crossing, before each big jump, and the west straight
	# (none leading into a crossing: a boosting cart can't brake for a closed one).
	var boost_scene: PackedScene = load("res://BoostPad.tscn")
	var boost_container := Node3D.new()
	boost_container.name = "BoostPads"
	level_scene.add_child(boost_container)
	var bp_defs: Array = [["Boost_Start", FINISH_S + 330.0, 0.0], ["Boost_West", 2140.0, 0.0]]
	for bj in BIG_JUMPS:
		bp_defs.append(["Boost_%s" % bj[0], float(bj[1]) - BIG_JUMP_BOOST, 0.0])
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


## The big trestle jumps, and their lips in the TrackPath's jump_lips (for scratch/nyota_jump_test).
func _build_big_jumps(level_scene: Node3D) -> void:
	var lips: Array = []
	for bj in BIG_JUMPS:
		var toe: float = bj[1]
		var length: float = BIG_JUMP[0]
		var h: float = BIG_JUMP[1]
		var j: Node3D = (load("res://WoodenRamp.tscn") as PackedScene).instantiate()
		j.name = bj[0]
		var sp: Dictionary = _spot(toe, 0.0, 0.0)
		j.position = sp["pos"]
		j.rotation_degrees = Vector3(0, sp["yaw"], 0)
		j.set("length", length)
		j.set("height", h)
		j.set("curve", BIG_JUMP[2])
		j.set("width", ROAD_HALF * 2.0)
		j.set("trestle", true)
		j.set("wood_color", Color(0.62, 0.48, 0.33))
		level_scene.add_child(j)
		var lp: Dictionary = _spot(toe + length, 0.0, 0.0)
		var slope: float = h / length * (1.0 + float(BIG_JUMP[2]))
		var lip: Vector3 = (lp["pos"] as Vector3) + Vector3(0, h + (_road_height_at_s(toe) - _road_height_at_s(toe + length)), 0)
		lips.append({"name": bj[0], "lip": lip, "dir": ((lp["fwd"] as Vector3) + Vector3(0, slope, 0)).normalized()})
	(level_scene.get_node("TrackPath") as Node).set_meta(&"jump_lips", lips)


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

## The sandstone's grain as a normal map, from dark_rock.png (as the Canyon Course's): the hills' rock and the boulders.
func _rock_normal_texture() -> Texture2D:
	var img: Image = (load("res://materials/dark_rock.png") as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	img.bump_map_to_normal_map(5.0)
	img.generate_mipmaps()
	var tex := PortableCompressedTexture2D.new()
	tex.keep_compressed_buffer = true
	tex.create_from_image(img, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSY, true, 0.9)
	return _save_baked_resource(tex, "rock_normal")


func _save_baked_resource(res: Resource, res_name: String, prefix := RES_PREFIX) -> Resource:
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
	FreightKit.solid_sink = []
	FreightKit.bed_top = -0.4
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
	_build_spurs()
	_plan_portals()
	_add_samples()
	_build_heights()
	print("  heights built (%.1fs)" % ((Time.get_ticks_msec() - t_start) / 1000.0))
	var ground_mat := ShaderMaterial.new()
	ground_mat.shader = load("res://canyon_ground.gdshader")
	ground_mat.set_shader_parameter("sand_tex", load("res://materials/sand.png"))
	ground_mat.set_shader_parameter("dirt_tex", load("res://materials/dirt.png"))
	_rock_normal = _rock_normal_texture()
	ground_mat.set_shader_parameter("rock_tex", load("res://materials/dark_rock.png"))
	ground_mat.set_shader_parameter("rock_normal", _rock_normal)
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
	# The rock's slope from the smooth normals alone: by each triangle's own face the rock's edge followed the 5m grid's
	# triangles, and the hills showed every facet.
	ground_mat.set_shader_parameter("face_slope", 0.0)
	_ground_mat = _save_baked_resource(ground_mat, "ground_material") as ShaderMaterial
	var terrain_root := Node3D.new()
	terrain_root.name = "PlainsTerrain"
	level_scene.add_child(terrain_root)
	_build_terrain(terrain_root, _ground_mat)
	print("  terrain built (%.1fs)" % ((Time.get_ticks_msec() - t_start) / 1000.0))

	_build_railways(level_scene)
	_build_yard(level_scene)
	# The clunk over the rails and the rattle along the sleepers (RailRumble.gd).
	var rumble := Node3D.new()
	rumble.name = "RailRumble"
	rumble.set_script(load("res://RailRumble.gd"))
	rumble.set("lines", _rumble_lines)
	level_scene.add_child(rumble)
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
