# regenerate_mina.gd
#
# Builds levels/MinaLevel.tscn - Mina del Viento, the finale of the Sierra del Viento GP: a point-to-point rally
# sprint (one run, no laps) from a high plateau at dawn down into an open-pit copper mine and out into the valley.
#
#   0 - 1.3km   The plateau, tarmac: the start in the middle of a balloon fiesta, the arm of a radio telescope array
#               along the road, and a crest over a dry wash that throws the carts.
#   1.3 - 1.9km The shelf road, gravel: cut into the escarpment's face, a safety berm on the drop side. The haboob
#               (HaboobWeather.gd) is at its thickest here: dust, gusts across the road, sand drifted over it,
#               tumbleweeds.
#   1.9 - 3.2km The pit: through a notch in its rim, then the haul ramp spirals three quarters of the way round it
#               on the benches, down to the floor. The pit is sheltered and the dust thins as it goes down.
#   3.2 - 4.2km The mouth (a benched cut through the pit's south wall), then the valley: the plant, conveyors
#               over the road, the truck shop and the finish.
#
# Things worth knowing before editing this file:
#
# 1. The pit is one function, `_pit_d`: the distance outside its floor, a rounded rectangle. Benches are contours
#    of it (BENCH_H high every BENCH_W), and the haul ramp's corners are on contours too: `_solve_route` picks each
#    corner's offset so that the road's height there lies on the walls' mean slope. So the ramp is cut into the
#    benches it crosses, never left standing in the air or buried in a wall, and whatever is placed by (s, lat) on
#    the ramp is on the ramp.
# 2. There is no road mesh: the ground is graded flat under the road and the ground shader (mina_ground.gdshader)
#    paints it, as on the Canyon Course and Freight Line. `_grade` clamps the ground between every nearby road
#    sample's cut and fill bounds.
# 3. Dressing stands on `_ground_at`, the built heightfield on its own triangles, never on a guess.
#
# The menu tile (images/menu/tile_mina_del_viento.jpg) is a render of this level (scratch/lap_shots.tscn).
extends Node

const LEVEL_NAME := "MinaLevel"
const LEVEL_PATH := "res://levels/MinaLevel.tscn"
const RES_PREFIX := "mina_"
const MeshChunker = preload("res://MeshChunker.gd")
const MESH_CHUNK_CELL := 80.0

# ======================================================================================
#  The route
# ======================================================================================

const ROAD_HALF := 7.5
const SAMPLE_STEP := 3.0
const CELL := 32.0
const GRADE_REACH := 45.0

## The pit's floor: a rounded rectangle about the origin, half sizes and corner radius. Benches rise from its edge.
const PIT_HX := 190.0
const PIT_HZ := 130.0
const PIT_RC := 55.0
const FLOOR_Y := -30.0
const BENCH_H := 12.0
const BENCH_W := 15.0
## The share of a bench's width taken by its face (the rest is the berm on top).
const BENCH_FACE := 0.6
## Where the ramp starts down the pit's wall, through the notch in the rim.
const RAMP_TOP_Y := 32.0
## The mouth: a cut south through the pit's wall to the valley, MOUTH_HALF either side of x = MOUTH_X.
const MOUTH_X := -40.0
const MOUTH_HALF := 15.0
const MOUTH_BENCH_H := 10.0
const MOUTH_BENCH_W := 11.0

## The route's corners before the pit: [x, z, radius]. The first is the start of the path.
const HEAD := [
	[-1780.0, -480.0, 0.0],
	[-1260.0, -480.0, 330.0],  # the fiesta's sweeper
	[-1030.0, 110.0, 300.0],   # out of the radio array onto the shelf
	[-300.0, 330.0, 60.0],     # the notch
]
## The pit's floor, off-road: from the foot of the ramp a serpentine between the trucks and the shovel, along the
## north wall past the drills, hard left by the sump (a late braker runs on into it) and back down the west side into
## the mouth. [x, z, radius].
const FLOOR := [
	[60.0, 124.0, 18.0], [60.0, 30.0, 18.0], [128.0, 30.0, 18.0], [128.0, -82.0, 20.0], [-84.0, -82.0, 24.0],
	[-84.0, 55.0, 22.0],
]
## And after it: the turn into the mouth, the turn into the valley, the end of the run-out.
const TAIL := [
	[MOUTH_X, PIT_HZ - 8.0, 34.0],
	[MOUTH_X, 520.0, 110.0],
	[600.0, 560.0, 0.0],
]
## Indices into the route's turns.
const T_FIESTA := 0
const T_ARRAY := 1
const T_NOTCH := 2
const T_NW := 3
const T_NE := 4
const T_SE := 5
const T_FLOOR := 6
## T_FLOOR + FLOOR.size(), and one on.
const T_MOUTH := 12
const T_VALLEY := 13
## The north leg's corner, where the sump waits beyond.
const T_SUMP_TURN := 10

## The road's height: [s, y] stations, linear between and smoothed. The ramp's and the tail's are added by
## `_build_profile` from the solved route.
const HEAD_PROFILE := [
	[0.0, 54.0], [300.0, 53.6], [700.0, 52.4], [960.0, 50.8], [1224.0, 48.6], [1290.0, 47.9],
]
## The dry wash the plateau road dips through and leaps out of: its centre on the route, and the road's offset from
## the smoothed profile at metres from it (Catmull-Rom between).
const WASH_S := 820.0
const WASH_SHAPE := [
	[-70.0, 0.0], [-40.0, -1.0], [-18.0, -3.1], [-6.0, -3.6], [6.0, -3.5], [20.0, 0.7], [25.0, 1.1], [46.0, -1.1],
	[78.0, -1.2], [125.0, 0.0],
]
## Tarmac on the plateau, gravel from the mine's gate, concrete again past the plant.
const PAVED_END := 1262.0
## From here the valley's road is concrete again (set from the route: just out of the valley's bend).
var _paved_again := 0.0

## The run's start and finish (s), and the run-out past the finish.
const START_S := 46.0
const FINISH_RUNOUT := 125.0

## The escarpment's edge, plateau to the north of it, valley to the south: a polyline (x, z).
const EDGE := [
	[-2900.0, 40.0], [-1600.0, 55.0], [-1200.0, 85.0], [-910.0, 152.0], [-720.0, 196.0], [-530.0, 236.0],
	[-330.0, 280.0], [-160.0, 318.0], [120.0, 340.0], [500.0, 330.0], [1000.0, 300.0], [2900.0, 260.0],
]
const PLATEAU_Y := 46.5
const VALLEY_Y := -34.0
## The face below the edge falls this much per metre out, under a cap rock CAP_DROP high.
const FACE_SLOPE := 1.05
const CAP_DROP := 7.0

## The wash across the plateau, from the north-east down to the edge (it leaves a notch there): a polyline.
const WASH_LINE := [[-760.0, -560.0], [-930.0, -330.0], [-1105.0, -205.0], [-1290.0, -60.0], [-1410.0, 90.0]]
const WASH_DEPTH := 3.6
const WASH_FLOOR_HALF := 7.0

## Terrain grid: FINE_STEP over the course, halved over the pit and its mouth, growing to the horizon.
const FINE_X := Vector2(-1870.0, 700.0)
const FINE_Z := Vector2(-580.0, 700.0)
const PIT_X := Vector2(-320.0, 320.0)
const PIT_Z := Vector2(-275.0, 470.0)
const FINE_STEP := 5.0
const OUTER_X := Vector2(-7000.0, 6000.0)
const OUTER_Z := Vector2(-6500.0, 6500.0)
const COARSE_GROWTH := 1.16
const COARSE_MAX := 180.0
## The middle of the course, for the far country.
const CENTRE := Vector2(-600.0, 50.0)

var _route: Dictionary = {}
var _turns: Array = []
var _prof := PackedFloat32Array()   # the road's height every metre
var _ramp_s0 := 0.0
var _ramp_s1 := 0.0
var _finish_s := 0.0

var _plain_noise := FastNoiseLite.new()
var _detail_noise := FastNoiseLite.new()
var _far_noise := FastNoiseLite.new()
var _edge_noise := FastNoiseLite.new()
var _bench_noise := FastNoiseLite.new()

# Road samples.
var _rs_pos := PackedVector3Array()
var _rs_right := PackedVector3Array()
var _rs_s := PackedFloat32Array()
var _rs_cut := PackedFloat32Array()
var _rs_flat := PackedFloat32Array()
var _rs_fill := PackedFloat32Array()
var _rs_cells := {}
var _rs_n := 0

# The heightfield.
var _grid_x := PackedFloat32Array()
var _grid_z := PackedFloat32Array()
var _heights := PackedFloat32Array()
var _road_d := PackedFloat32Array()
var _vert_lat := PackedFloat32Array()
var _vert_s := PackedFloat32Array()
var _vert_mined := PackedFloat32Array()
var _vert_rock := PackedFloat32Array()
var _ground_mat: ShaderMaterial


func _right_of(th: float) -> Vector2:
	return Vector2(-sin(th), cos(th))


func _dir_of(th: float) -> Vector2:
	return Vector2(cos(th), sin(th))


## An open path through `corners` ([x, z, radius]; the first and last are its ends): straights joined by arcs of
## each corner's radius. Returns {"segs", "len", "turns": [{s0, s1, turn (degrees, + right), r}]}.
func _fillet_open(corners: Array) -> Dictionary:
	var n: int = corners.size()
	var segs: Array = []
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
		segs.append({"kind": "S", "p0": prev, "th0": atan2(d1.y, d1.x), "len": length, "s0": s})
		s += length
		var arc_len: float = r * absf(ang)
		segs.append({"kind": "A", "p0": p_in, "th0": atan2(d1.y, d1.x), "r": r, "sign": signf(ang), "len": arc_len, "s0": s})
		turns.append({"s0": s, "s1": s + arc_len, "turn": rad_to_deg(ang), "r": r})
		s += arc_len
		prev = b + d2 * t
	var last := Vector2(corners[n - 1][0], corners[n - 1][1])
	var dl: Vector2 = last - prev
	segs.append({"kind": "S", "p0": prev, "th0": atan2(dl.y, dl.x), "len": dl.length(), "s0": s})
	s += dl.length()
	return {"segs": segs, "len": s, "turns": turns}


## Position and heading on the route at `s` (clamped to its ends; past them it carries straight on).
func _at(s: float) -> Dictionary:
	var segs: Array = _route["segs"]
	var seg: Dictionary = segs[0]
	for i in range(segs.size() - 1, -1, -1):
		if s >= float(segs[i]["s0"]) - 0.0001:
			seg = segs[i]
			break
	var d: float = s - float(seg["s0"])
	var p0: Vector2 = seg["p0"]
	var th0: float = seg["th0"]
	if seg["kind"] == "S" or d < 0.0 or d > float(seg["len"]):
		if seg["kind"] == "A" and d > float(seg["len"]):
			var e: Dictionary = _arc_point(seg, float(seg["len"]))
			return {"p": e["p"] + _dir_of(e["th"]) * (d - float(seg["len"])), "th": e["th"]}
		return {"p": p0 + _dir_of(th0) * d, "th": th0}
	return _arc_point(seg, d)


func _arc_point(seg: Dictionary, d: float) -> Dictionary:
	var r: float = seg["r"]
	var sgn: float = seg["sign"]
	var th0: float = seg["th0"]
	var c: Vector2 = seg["p0"] + _right_of(th0) * r * sgn
	var th: float = th0 + sgn * d / r
	return {"p": c - _right_of(th) * r * sgn, "th": th}


## The route's corners with the pit's three at offsets `ds` (NW, NE, SE) from the floor's edge.
func _corners(ds: Array) -> Array:
	var out: Array = HEAD.duplicate(true)
	out.append([-(PIT_HX + ds[0]), -(PIT_HZ + ds[0]), PIT_RC + ds[0]])
	out.append([PIT_HX + ds[1], -(PIT_HZ + ds[1]), PIT_RC + ds[1]])
	out.append([PIT_HX + ds[2], PIT_HZ + ds[2], PIT_RC + ds[2]])
	out.append_array(FLOOR.duplicate(true))
	out.append_array(TAIL.duplicate(true))
	return out


## Places the ramp's corners round the pit so that the road's height at each (falling evenly from RAMP_TOP_Y at the
## notch to FLOOR_Y at the end of the last one) is the walls' mean height at that corner's offset.
func _solve_route() -> void:
	var ds: Array = [62.0, 36.0, 10.0]
	for _it in range(12):
		var rt: Dictionary = _fillet_open(_corners(ds))
		var turns: Array = rt["turns"]
		var s_top: float = turns[T_NOTCH]["s1"]
		var s_floor: float = turns[T_SE]["s1"]
		for k in range(3):
			var tn: Dictionary = turns[T_NW + k]
			var u: float = clampf((0.5 * (float(tn["s0"]) + float(tn["s1"])) - s_top) / (s_floor - s_top), 0.0, 1.0)
			var y: float = lerpf(RAMP_TOP_Y, FLOOR_Y, u)
			ds[k] = 0.5 * float(ds[k]) + 0.5 * maxf((y - FLOOR_Y) / BENCH_H * BENCH_W, 0.0)
	_route = _fillet_open(_corners(ds))
	_turns = _route["turns"]
	_ramp_s0 = _turns[T_NOTCH]["s1"]
	_ramp_s1 = _turns[T_SE]["s1"]
	_finish_s = float(_route["len"]) - FINISH_RUNOUT
	if _turns.size() != T_VALLEY + 1:
		push_error("route: %d turns, but T_VALLEY is %d" % [_turns.size(), T_VALLEY])
	_paved_again = float(_turns[T_VALLEY]["s1"]) + 59.0
	print("  route %.0fm; pit corners at offsets %.1f, %.1f, %.1f; ramp %.0f-%.0fm (%.0fm at %.1f%%); finish at %.0fm" % [
		_route["len"], ds[0], ds[1], ds[2], _ramp_s0, _ramp_s1, _ramp_s1 - _ramp_s0,
		100.0 * (RAMP_TOP_Y - FLOOR_Y) / (_ramp_s1 - _ramp_s0), _finish_s])
	for i in range(_turns.size()):
		var tn: Dictionary = _turns[i]
		print("    turn %d: %.0f-%.0fm, %.0f degrees, r %.0f" % [i, tn["s0"], tn["s1"], tn["turn"], tn["r"]])


## The road's height along the route, a value a metre: the stations joined by straight lines, smoothed, and the
## wash's dip and crest added.
func _build_profile() -> void:
	var st: Array = HEAD_PROFILE.duplicate(true)
	st.append([float(_turns[T_NOTCH]["s0"]), 33.8])
	st.append([_ramp_s0, RAMP_TOP_Y])
	st.append([_ramp_s1, FLOOR_Y])
	st.append([float(_turns[T_MOUTH]["s0"]), FLOOR_Y - 0.2])
	st.append([float(_turns[T_MOUTH]["s1"]), FLOOR_Y - 0.4])
	st.append([float(_turns[T_VALLEY]["s0"]), VALLEY_Y + 1.0])
	st.append([float(_turns[T_VALLEY]["s1"]), VALLEY_Y + 0.4])
	st.append([float(_route["len"]), VALLEY_Y])
	var n: int = int(ceil(float(_route["len"]))) + 1
	var raw := PackedFloat32Array()
	raw.resize(n)
	var k := 0
	for i in range(n):
		var s := float(i)
		while k < st.size() - 2 and s > float(st[k + 1][0]):
			k += 1
		var a: Array = st[k]
		var b: Array = st[k + 1]
		raw[i] = lerpf(float(a[1]), float(b[1]), clampf((s - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001), 0.0, 1.0))
	# Two passes of a 30m box: a smooth rounding where the grade changes.
	var sm: PackedFloat32Array = raw
	for _p in range(2):
		var out := PackedFloat32Array()
		out.resize(n)
		for i in range(n):
			var sum := 0.0
			var cnt := 0
			for j in range(maxi(i - 15, 0), mini(i + 16, n)):
				sum += sm[j]
				cnt += 1
			out[i] = sum / float(cnt)
		sm = out
	for i in range(n):
		sm[i] += _wash_offset(float(i) - WASH_S)
	_prof = sm


## Catmull-Rom through WASH_SHAPE at `u` metres from the wash's centre.
func _wash_offset(u: float) -> float:
	var pts: Array = WASH_SHAPE
	if u <= float(pts[0][0]) or u >= float(pts[pts.size() - 1][0]):
		return 0.0
	var i := 0
	while i < pts.size() - 2 and u > float(pts[i + 1][0]):
		i += 1
	var p0: float = pts[maxi(i - 1, 0)][1]
	var p1: float = pts[i][1]
	var p2: float = pts[i + 1][1]
	var p3: float = pts[mini(i + 2, pts.size() - 1)][1]
	var t: float = (u - float(pts[i][0])) / (float(pts[i + 1][0]) - float(pts[i][0]))
	var t2: float = t * t
	return 0.5 * (2.0 * p1 + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t2 * t)


func _road_y(s: float) -> float:
	var f: float = clampf(s, 0.0, float(_prof.size() - 1))
	var i: int = mini(int(floor(f)), _prof.size() - 2)
	return lerpf(_prof[i], _prof[i + 1], f - float(i))


## A spot on the route: `lat` metres right of the centreline, `lift` over the road, and the yaw facing the way of
## travel.
func _spot(s: float, lat: float, lift: float) -> Dictionary:
	var pa: Dictionary = _at(s)
	var p2: Vector2 = pa["p"]
	var r2: Vector2 = _right_of(float(pa["th"]))
	var f2: Vector2 = _dir_of(float(pa["th"]))
	var pos := Vector3(p2.x + r2.x * lat, _road_y(s) + lift, p2.y + r2.y * lat)
	var fwd := Vector3(f2.x, 0.0, f2.y)
	return {"pos": pos, "yaw": rad_to_deg(atan2(-fwd.x, -fwd.z)), "fwd": fwd, "right": Vector3(r2.x, 0.0, r2.y)}


# ======================================================================================
#  The land
# ======================================================================================

func _init_noise() -> void:
	_plain_noise.seed = 5113
	_plain_noise.frequency = 0.0028
	_plain_noise.fractal_octaves = 3
	_detail_noise.seed = 207
	_detail_noise.frequency = 0.021
	_detail_noise.fractal_octaves = 2
	_far_noise.seed = 9901
	_far_noise.frequency = 0.0008
	_far_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_far_noise.fractal_octaves = 4
	_edge_noise.seed = 77
	_edge_noise.frequency = 0.012
	_edge_noise.fractal_octaves = 2
	_bench_noise.seed = 3301
	_bench_noise.frequency = 0.05
	_bench_noise.fractal_octaves = 2


## Signed distance from the escarpment's edge (+ out over the face, toward the valley), its line wandering a little.
func _edge_dist(x: float, z: float) -> float:
	var best := 1e9
	var sgn := 1.0
	var p := Vector2(x, z)
	for i in range(EDGE.size() - 1):
		var a := Vector2(EDGE[i][0], EDGE[i][1])
		var b := Vector2(EDGE[i + 1][0], EDGE[i + 1][1])
		var ab: Vector2 = b - a
		var t: float = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d: float = p.distance_to(a + ab * t)
		if d < best:
			best = d
			# Valley to the right of the line's direction (it runs west to east, valley south).
			sgn = 1.0 if ab.x * (p.y - a.y) - ab.y * (p.x - a.x) > 0.0 else -1.0
	return best * sgn + _edge_noise.get_noise_2d(x, z) * 9.0


## The plateau: rising gently away from the edge, a few metres of swell.
func _plateau(x: float, z: float, ed: float) -> float:
	return PLATEAU_Y + 7.5 * smoothstep(0.0, 700.0, -ed) + _plain_noise.get_noise_2d(x, z) * 2.2 + _detail_noise.get_noise_2d(x, z) * 0.2


func _valley(x: float, z: float) -> float:
	return VALLEY_Y + _plain_noise.get_noise_2d(x + 900.0, z) * 1.6 + _detail_noise.get_noise_2d(x, z) * 0.15


## The natural land before the mine: plateau, the escarpment's face and the valley under it.
func _natural(x: float, z: float) -> float:
	var ed: float = _edge_dist(x, z)
	var top: float = _plateau(x, z, minf(ed, 0.0))
	var val: float = _valley(x, z)
	if ed < -6.0:
		return maxf(top, val)
	# The cap rock: a few metres of cliff at the lip, then the face down to the valley, its foot a talus apron.
	var face: float = top - CAP_DROP * smoothstep(-3.0, 4.0, ed) - maxf(ed - 3.0, 0.0) * FACE_SLOPE
	var k := 14.0
	var h: float = maxf(face, val)
	# Soft max: the talus fans out at the foot.
	h += k * 0.25 * pow(maxf(1.0 - absf(face - val) / k, 0.0), 2.0)
	return h


## Distance outside the pit's floor (negative inside it).
func _pit_d(x: float, z: float) -> float:
	var qx: float = absf(x) - (PIT_HX - PIT_RC)
	var qz: float = absf(z) - (PIT_HZ - PIT_RC)
	return Vector2(maxf(qx, 0.0), maxf(qz, 0.0)).length() + minf(maxf(qx, qz), 0.0) - PIT_RC


## Benches: a face BENCH_H high over the first BENCH_FACE of every BENCH_W, then the berm. `d` from the toe.
func _benches(d: float, bh: float, bw: float) -> float:
	if d <= 0.0:
		return 0.0
	var b: float = d / bw
	var k: float = floor(b)
	var f: float = b - k
	return bh * (k + smoothstep(0.0, BENCH_FACE, f))


## The ground the mine has cut: the pit's benches, and the mouth's through its south wall (1e9 where neither is).
func _mine_cut(x: float, z: float) -> float:
	var h := 1e9
	var d: float = _pit_d(x, z) + _bench_noise.get_noise_2d(x, z) * 1.3
	if d < 140.0:
		h = FLOOR_Y + _benches(d, BENCH_H, BENCH_W)
		# The sump: the floor's low corner, where the water gathers, deep enough to drown a cart.
		h -= SUMP_DEPTH * (1.0 - smoothstep(SUMP_R - 14.0, SUMP_R + 4.0, Vector2(x - SUMP.x, z - SUMP.y).length()))
	if z > PIT_HZ - 30.0 and z < 640.0:
		var dm: float = absf(x - MOUTH_X) - MOUTH_HALF + _bench_noise.get_noise_2d(x + 400.0, z) * 1.0
		var floor_y: float = lerpf(FLOOR_Y - 0.4, VALLEY_Y + 0.6, smoothstep(PIT_HZ, 520.0, z))
		h = minf(h, floor_y + _benches(dm, MOUTH_BENCH_H, MOUTH_BENCH_W))
	return h


## The sump: its middle, its radius at the waterline (about), how deep it is dug, its water. It lies straight on
## from the north leg's corner (T_SUMP_TURN): a cart that brakes late runs into it and drowns.
const SUMP := Vector2(-130.0, -95.0)
const SUMP_R := 28.0
const SUMP_DEPTH := 5.5
const SUMP_WATER_Y := FLOOR_Y - 1.0
## The pit floor's track: how lumpy (metres up and down).
const FLOOR_LUMPS := 0.2


## The dry wash: distance from its line and how far along it.
func _wash(x: float, z: float) -> Vector2:
	var best := 1e9
	var along := 0.0
	var acc := 0.0
	var p := Vector2(x, z)
	for i in range(WASH_LINE.size() - 1):
		var a := Vector2(WASH_LINE[i][0], WASH_LINE[i][1])
		var b := Vector2(WASH_LINE[i + 1][0], WASH_LINE[i + 1][1])
		var ab: Vector2 = b - a
		var t: float = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d: float = p.distance_to(a + ab * t)
		if d < best:
			best = d
			along = acc + t * ab.length()
		acc += ab.length()
	return Vector2(best + _detail_noise.get_noise_2d(x * 0.6, z * 0.6) * 3.0, along)


## Mesas and ranges on the horizon.
func _far(x: float, z: float) -> float:
	var d: float = Vector2(x, z).distance_to(CENTRE)
	var t: float = smoothstep(1700.0, 3200.0, d)
	if t <= 0.0:
		return 0.0
	var ridge: float = (_far_noise.get_noise_2d(x, z) + 1.0) * 0.5
	var mesa: float = smoothstep(0.38, 0.62, ridge)
	var top: float = lerpf(0.55, 1.0, smoothstep(0.62, 0.75, ridge))
	return t * (mesa * top * 260.0 + ridge * 50.0)


## The land before the road is graded into it, and how deep the mine has cut it (for the shader's copper rock).
func _base(x: float, z: float) -> Vector2:
	var h: float = _natural(x, z)
	var w: Vector2 = _wash(x, z)
	if w.x < 40.0:
		var bed: float = h - WASH_DEPTH * (1.0 - smoothstep(WASH_FLOOR_HALF, WASH_FLOOR_HALF + 9.0, w.x))
		h = minf(h, bed)
	h += _far(x, z)
	var cut: float = _mine_cut(x, z)
	var mined := 0.0
	if cut < h:
		mined = h - cut
		h = cut
	return Vector2(h, mined)


# ======================================================================================
#  Road samples and grading
# ======================================================================================

## Cut and fill per stretch: [s up to, flat half width, cut per metre, fill per metre].
func _grading_at(s: float) -> Vector3:
	if s < 1240.0:
		return Vector3(9.6, 0.8, 0.55)
	if s < _ramp_s0:
		return Vector3(9.6, 2.4, 1.6)
	if s < float(_turns[T_VALLEY]["s0"]):
		return Vector3(9.8, 3.0, 1.6)
	return Vector3(10.0, 0.7, 0.5)


func _add_samples() -> void:
	_rs_n = int(floor(float(_route["len"]) / SAMPLE_STEP)) + 1
	for k in range(_rs_n):
		var s: float = minf(float(k) * SAMPLE_STEP, float(_route["len"]))
		var pa: Dictionary = _at(s)
		var p2: Vector2 = pa["p"]
		var r2: Vector2 = _right_of(float(pa["th"]))
		var g: Vector3 = _grading_at(s)
		_rs_pos.append(Vector3(p2.x, _road_y(s), p2.y))
		_rs_right.append(Vector3(r2.x, 0.0, r2.y))
		_rs_s.append(s)
		_rs_flat.append(g.x)
		_rs_cut.append(g.y)
		_rs_fill.append(g.z)
		var key := Vector2i(floori(p2.x / CELL), floori(p2.y / CELL))
		var bucket: PackedInt32Array = _rs_cells.get(key, PackedInt32Array())
		bucket.append(k)
		_rs_cells[key] = bucket


## Clamps `h` between the cut and fill bounds of every road segment within reach. Returns the graded height and,
## beside a segment inside its flat strip, the road's height there (else NAN).
func _grade(h: float, x: float, z: float) -> Vector2:
	var cx: int = floori(x / CELL)
	var cz: int = floori(z / CELL)
	var upper := 1e9
	var lower := -1e9
	var touched := false
	var flat_y := NAN
	var flat_lat := 1e9
	var reach: int = int(ceil(GRADE_REACH / CELL))
	for gz in range(cz - reach, cz + reach + 1):
		for gx in range(cx - reach, cx + reach + 1):
			var bucket: PackedInt32Array = _rs_cells.get(Vector2i(gx, gz), PackedInt32Array())
			for i in bucket:
				if i >= _rs_n - 1:
					continue
				var a: Vector3 = _rs_pos[i]
				var dx: float = x - a.x
				var dz: float = z - a.z
				if dx * dx + dz * dz > GRADE_REACH * GRADE_REACH:
					continue
				var b: Vector3 = _rs_pos[i + 1]
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
				var soft: float = over * over / (over + 3.0)
				upper = minf(upper, foot_y + soft * _rs_cut[i])
				lower = maxf(lower, foot_y - soft * _rs_fill[i])
				touched = true
				if lateral <= flat and lateral < flat_lat:
					flat_lat = lateral
					flat_y = foot_y
	if not touched:
		return Vector2(h, NAN)
	var res: float = upper if lower > upper else clampf(h, lower, upper)
	return Vector2(res, flat_y)


## Distance to the route's centreline, the signed lateral (+ right of travel) and the route's s there.
func _road_lat(x: float, z: float) -> Vector3:
	var cx: int = floori(x / CELL)
	var cz: int = floori(z / CELL)
	var best := 1e9
	var lat := 0.0
	var at_s := 0.0
	for gz in range(cz - 1, cz + 2):
		for gx in range(cx - 1, cx + 2):
			var bucket: PackedInt32Array = _rs_cells.get(Vector2i(gx, gz), PackedInt32Array())
			for i in bucket:
				if i >= _rs_n - 1:
					continue
				var a: Vector3 = _rs_pos[i]
				var b: Vector3 = _rs_pos[i + 1]
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
					at_s = _rs_s[i] + t * (_rs_s[i + 1] - _rs_s[i])
	return Vector3(sqrt(best), lat, at_s)


# ======================================================================================
#  The heightfield
# ======================================================================================

## One axis of the grid: FINE_STEP over `fine`, half that over `dense`, growing outward to `outer`.
func _grid_axis(fine: Vector2, dense: Vector2, outer: Vector2) -> PackedFloat32Array:
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
	x = fine.x
	while x < fine.y - 0.01:
		out.append(x)
		var st: float = FINE_STEP * 0.5 if x >= dense.x - 0.01 and x < dense.y - 0.01 else FINE_STEP
		x += st
	out.append(fine.y)
	step = FINE_STEP
	x = fine.y
	while x < outer.y:
		step = minf(step * COARSE_GROWTH, COARSE_MAX)
		x += step
		out.append(minf(x, outer.y))
	return out


func _build_heights() -> void:
	_grid_x = _grid_axis(FINE_X, PIT_X, OUTER_X)
	_grid_z = _grid_axis(FINE_Z, PIT_Z, OUTER_Z)
	var nx: int = _grid_x.size()
	var nz: int = _grid_z.size()
	print("  terrain grid %d x %d = %d vertices" % [nx, nz, nx * nz])
	var count: int = nx * nz
	_heights.resize(count)
	_road_d.resize(count)
	_vert_lat.resize(count)
	_vert_s.resize(count)
	_vert_mined.resize(count)
	for iz in range(nz):
		var z: float = _grid_z[iz]
		for ix in range(nx):
			var x: float = _grid_x[ix]
			var i: int = iz * nx + ix
			var bm: Vector2 = _base(x, z)
			var h: float = bm.x
			_vert_mined[i] = bm.y
			var near: bool = x > FINE_X.x - 60.0 and x < FINE_X.y + 60.0 and z > FINE_Z.x - 60.0 and z < FINE_Z.y + 60.0
			if not near:
				_heights[i] = h
				_road_d[i] = 1e9
				continue
			var g: Vector2 = _grade(h, x, z)
			h = g.y if not is_nan(g.y) else g.x
			h = _pad_height(x, z, h, not is_nan(g.y))
			_heights[i] = h
			var rl: Vector3 = _road_lat(x, z)
			_road_d[i] = rl.x
			_vert_lat[i] = rl.y
			_vert_s[i] = rl.z


## Ground height at any (x, z) from the built heightfield, on the same triangles as the mesh: each cell is split
## along the diagonal joining its closer heights, so this must be too.
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


## The steepest rise of the ground over a few metres round (x, z), as rise per metre.
func _slope_at(x: float, z: float, r := 1.5) -> float:
	var gx: float = _ground_at(x + r, z) - _ground_at(x - r, z)
	var gz: float = _ground_at(x, z + r) - _ground_at(x, z - r)
	return Vector2(gx, gz).length() / (2.0 * r)


## The rise and fall of the ground under a footprint (centre, yaw, half sizes): [lowest, highest].
func _relief(c: Vector3, yaw: float, half: Vector2) -> Vector2:
	var lo := 1e9
	var hi := -1e9
	var b := Basis(Vector3.UP, yaw)
	for u in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		for v in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			var p: Vector3 = c + b * Vector3(u * half.x, 0.0, v * half.y)
			var h: float = _ground_at(p.x, p.z)
			lo = minf(lo, h)
			hi = maxf(hi, h)
	return Vector2(lo, hi)


# ======================================================================================
#  Pads: level ground for what stands in the valley and at the start
# ======================================================================================

## [centre x, centre z, half x, half z, blend, height or NAN to take the natural ground's mean].
var _pads: Array = []

func _plan_pads() -> void:
	for p in PADS:
		var y: float = p[5]
		if is_nan(y):
			var sum := 0.0
			var cnt := 0
			for u in [-1.0, 0.0, 1.0]:
				for v in [-1.0, 0.0, 1.0]:
					sum += _base(float(p[0]) + u * float(p[2]), float(p[1]) + v * float(p[3])).x
					cnt += 1
			y = sum / float(cnt)
		_pads.append([p[0], p[1], p[2], p[3], p[4], y])


## Pads, by name: [x, z, half x, half z, blend, y (NAN: the natural mean)].
const PADS := [
	[-1560.0, -530.0, 170.0, 32.0, 28.0, NAN],   # the fiesta's launch field, north of the start straight
	[-1560.0, -420.0, 170.0, 30.0, 28.0, NAN],   # and south of it
	[38.0, 456.0, 32.0, 32.0, 14.0, VALLEY_Y - 0.3],   # the stockpile
	[330.0, 478.0, 66.0, 36.0, 16.0, VALLEY_Y - 0.2],  # the truck shop and its yard
	[232.0, 640.0, 26.0, 18.0, 14.0, VALLEY_Y - 0.2],  # the concentrator
	[322.0, 648.0, 50.0, 30.0, 14.0, VALLEY_Y - 0.2],  # the thickeners
	[492.0, 582.0, 40.0, 10.0, 12.0, VALLEY_Y - 0.1],  # the finish grandstand
]


func _pad_height(x: float, z: float, h: float, on_road: bool) -> float:
	if on_road:
		return h
	for p in _pads:
		var dx: float = maxf(absf(x - float(p[0])) - float(p[2]), 0.0)
		var dz: float = maxf(absf(z - float(p[1])) - float(p[3]), 0.0)
		var d: float = Vector2(dx, dz).length()
		var blend: float = p[4]
		if d < blend:
			h = lerpf(float(p[5]), h, smoothstep(0.0, blend, d))
	return h


# ======================================================================================
#  Sand drifted over the shelf road
# ======================================================================================

## [s centre, half length, height] of the drifts the haboob has laid across the shelf road.
const DRIFTS := [[1452.0, 15.0, 0.45], [1648.0, 13.0, 0.4]]

## How deep the drifted sand lies at (s, lat): a mound across the road, highest in its middle, thinning toward the
## lee edge (the wind comes from the valley side, the right).
func _drift_at(s: float, lat: float) -> float:
	var best := 0.0
	for d in DRIFTS:
		var u: float = absf(s - float(d[0])) / float(d[1])
		if u >= 1.0:
			continue
		var along: float = 0.5 + 0.5 * cos(u * PI)
		var across: float = lerpf(0.55, 1.0, smoothstep(-ROAD_HALF, ROAD_HALF, lat)) * (1.0 - smoothstep(ROAD_HALF + 2.0, ROAD_HALF + 6.0, absf(lat)))
		best = maxf(best, float(d[2]) * along * across)
	return best


# ======================================================================================
#  Terrain mesh and collision
# ======================================================================================

## The ground's bodies: [name, Surfaces.gd surface, dust colour]. Roads end in "Road" (PlayerCart counts them as
## track); the order is the index `_ground_kind` returns.
const BODIES := [
	["MinaRoad", "asphalt", Color(0, 0, 0, 0)],
	["MinaHaulRoad", "gravel", Color(0.80, 0.62, 0.48, 0.7)],
	["MinaSandRoad", "sand", Color(0.86, 0.70, 0.50, 0.8)],
	["MinaGround", "dirt", Color(0.82, 0.66, 0.50, 0.6)],
	["MinaPitGround", "gravel", Color(0.72, 0.52, 0.42, 0.6)],
	["MinaRockFace", "rock", Color(0.70, 0.55, 0.45, 0.5)],
]
const B_ROAD := 0
const B_HAUL := 1
const B_SAND := 2
const B_GROUND := 3
const B_PIT := 4
const B_ROCK := 5


func _paved_at(s: float) -> float:
	if s < PAVED_END:
		return 1.0 - smoothstep(PAVED_END - 30.0, PAVED_END, s)
	return smoothstep(_paved_again, _paved_again + 30.0, s)


## The pit floor's track, from the foot of the ramp to the mouth: off-road.
func _offroad_at(s: float) -> bool:
	return s > _ramp_s1 + 8.0 and s < float(_turns[T_MOUTH]["s0"]) - 4.0


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


## Which body a ground triangle belongs to: the road by the triangle's mean distance from the centreline (the grid is
## coarser than the paint, so judged by its corners the road's edge would lag the painted one), else by its rock and
## whether the mine has cut it.
func _ground_kind(tri: Array, verts: PackedVector3Array) -> int:
	var d_sum := 0.0
	var rock := 0.0
	var mined := 0.0
	var s_sum := 0.0
	var lat_sum := 0.0
	for v in tri:
		d_sum += _road_d[v]
		rock += _vert_rock[v]
		mined += _vert_mined[v]
		s_sum += _vert_s[v]
		lat_sum += _vert_lat[v]
	if d_sum / 3.0 < ROAD_HALF - 0.2:
		var s: float = s_sum / 3.0
		if _drift_at(s, lat_sum / 3.0) > 0.12:
			return B_SAND
		# The pit floor's track is off-road: rubble the trucks have rutted, not a made road.
		if _offroad_at(s):
			return B_PIT
		return B_ROAD if _paved_at(s) > 0.5 else B_HAUL
	var n: Vector3 = (verts[tri[2]] - verts[tri[0]]).cross(verts[tri[1]] - verts[tri[0]]).normalized()
	if rock > 1.8 or absf(n.y) < 0.62:
		return B_ROCK
	return B_PIT if mined > 1.5 else B_GROUND


func _build_terrain(parent: Node, mat: Material) -> void:
	var nx: int = _grid_x.size()
	var nz: int = _grid_z.size()
	var count: int = nx * nz
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	verts.resize(count)
	normals.resize(count)
	colors.resize(count)
	uvs.resize(count)
	uv2s.resize(count)
	_vert_rock.resize(count)
	# The drifts first: they lift the ground the normals are taken from. The pit floor's track is lumpy with rubble.
	for iz in range(nz):
		for ix in range(nx):
			var i: int = iz * nx + ix
			if _road_d[i] < ROAD_HALF + 7.0:
				_heights[i] += _drift_at(_vert_s[i], _vert_lat[i])
				if _offroad_at(_vert_s[i]):
					_heights[i] += FLOOR_LUMPS * _detail_noise.get_noise_2d(_grid_x[ix] * 4.0, _grid_z[iz] * 4.0)
	for iz in range(nz):
		for ix in range(nx):
			var i: int = iz * nx + ix
			var x: float = _grid_x[ix]
			var z: float = _grid_z[iz]
			verts[i] = Vector3(x, _heights[i], z)
			var ixl: int = maxi(ix - 1, 0)
			var ixr: int = mini(ix + 1, nx - 1)
			var izd: int = maxi(iz - 1, 0)
			var izu: int = mini(iz + 1, nz - 1)
			var dhdx: float = (_heights[iz * nx + ixr] - _heights[iz * nx + ixl]) / maxf(_grid_x[ixr] - _grid_x[ixl], 0.01)
			var dhdz: float = (_heights[izu * nx + ix] - _heights[izd * nx + ix]) / maxf(_grid_z[izu] - _grid_z[izd], 0.01)
			var nrm := Vector3(-dhdx, 1.0, -dhdz).normalized()
			normals[i] = nrm
			var road_d: float = _road_d[i]
			var mined: float = smoothstep(0.4, 2.5, _vert_mined[i])
			var rock: float = 1.0 - smoothstep(0.5, 0.86, nrm.y)
			if road_d < 1e8:
				var band: float = 1.0 - smoothstep(13.0, 15.0, road_d)
				rock *= smoothstep(ROAD_HALF + 0.5, ROAD_HALF + 2.0, road_d)
				# Pale sand: the wash's bed and patches blown about the plateau.
				var w: Vector2 = _wash(x, z)
				var sand: float = (1.0 - smoothstep(WASH_FLOOR_HALF, WASH_FLOOR_HALF + 10.0, w.x)) * 0.8
				sand = maxf(sand, smoothstep(0.35, 0.6, _detail_noise.get_noise_2d(x * 0.12 + 40.0, z * 0.12)) * 0.4 * (1.0 - mined))
				sand *= 1.0 - rock
				var lat_enc: float = clampf(_vert_lat[i] / 24.0 + 0.5, 0.0, 1.0)
				colors[i] = Color(rock, band, sand, lat_enc)
				var drift: float = smoothstep(0.02, 0.3, _drift_at(_vert_s[i], _vert_lat[i]))
				uvs[i] = Vector2(mined, drift)
				uv2s[i] = Vector2(_vert_s[i], -1.0 if _offroad_at(_vert_s[i]) else _paved_at(_vert_s[i]))
			else:
				colors[i] = Color(1.0 - smoothstep(0.62, 0.8, nrm.y), 0.0, 0.0, 0.5)
				uvs[i] = Vector2(mined, 0.0)
				uv2s[i] = Vector2(0.0, 0.0)
			_vert_rock[i] = colors[i].r
	var indices := PackedInt32Array()
	var faces: Array = []
	var counts: Array = []
	for b in BODIES:
		faces.append(PackedVector3Array())
		counts.append(0)
	for iz in range(nz - 1):
		for ix in range(nx - 1):
			var a: int = iz * nx + ix
			var b: int = a + 1
			var c: int = a + nx
			var d: int = a + nx + 1
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
				var k: int = _ground_kind(tri, verts) if _road_d[tri[0]] < 1e8 else B_GROUND
				var f: PackedVector3Array = faces[k]
				f.append(p0)
				f.append(p1)
				f.append(p2)
				faces[k] = f
				counts[k] += 1
	# The fine grid, which MeshChunker cuts into cells, and the coarse land out to the horizon as one mesh of its own
	# (saved under another prefix, so the chunker leaves it whole: cut into cells it was thousands of draws).
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
	inst.name = "MinaGroundMesh"
	inst.mesh = _save_baked_resource(near_mesh, "ground_visual")
	parent.add_child(inst)
	var far_mesh: ArrayMesh = _compact_mesh(verts, normals, colors, uvs, uv2s, far_idx, mat)
	var far_inst := MeshInstance3D.new()
	far_inst.name = "MinaFarGround"
	far_inst.mesh = _save_baked_resource(far_mesh, "ground", "minafar_")
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
		cs.shape = _save_baked_resource(shape, String(BODIES[k][0]).to_snake_case().trim_prefix("mina_") + "_shape")
		body.add_child(cs)
		report += " %s %d" % [BODIES[k][0], counts[k]]
	print("  ground: %d triangles (%d near):%s" % [indices.size() / 3, near_idx.size() / 3, report])


## The TrackPath: the route as a Curve3D, a point every SAMPLE_STEP.
func _build_track_curve() -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = 0.5
	var pts: Array = []
	for k in range(_rs_n):
		pts.append(_rs_pos[k])
	var n: int = pts.size()
	for k in range(n):
		var a: Vector3 = pts[maxi(k - 1, 0)]
		var c: Vector3 = pts[mini(k + 1, n - 1)]
		var hnd: Vector3 = (c - a) / (6.0 if k > 0 and k < n - 1 else 3.0)
		curve.add_point(pts[k], -hnd, hnd)
	return curve


# ======================================================================================
#  The race: start, checkpoints, finish, boost pads
# ======================================================================================

## Fixed checkpoints down to the ramp; those on the floor, in the mouth and the valley follow the route (`_checkpoints`).
const CHECKPOINTS_S := [640.0, 1180.0, 1600.0, 2120.0, 2560.0, 2870.0]
## [s, lat]: out of the fiesta's sweeper, onto the shelf, the north wall, the mouth and the valley.
const BOOSTS := [[250.0, -2.6], [1300.0, 2.6], [2430.0, 0.0]]


func _checkpoints() -> Array:
	var out: Array = CHECKPOINTS_S.duplicate()
	# The floor's first leg north, the north leg by the shovel, the mouth, the valley.
	out.append(0.5 * (float(_turns[T_FLOOR]["s1"]) + float(_turns[T_FLOOR + 1]["s0"])))
	out.append(float(_turns[T_FLOOR + 3]["s1"]) + 60.0)
	out.append(float(_turns[T_MOUTH]["s1"]) + 90.0)
	out.append(float(_turns[T_VALLEY]["s1"]) + 160.0)
	return out


## [s, lat]: the fixed ones, then onto the floor's north leg (straight at the sump's corner: brake!), the mouth and
## the valley's straight.
func _boosts() -> Array:
	var out: Array = BOOSTS.duplicate(true)
	out.append([float(_turns[T_FLOOR + 3]["s1"]) + 8.0, 0.0])
	out.append([float(_turns[T_MOUTH]["s1"]) + 30.0, 0.0])
	out.append([float(_turns[T_VALLEY]["s1"]) + 60.0, -2.6])
	return out


func _gate(parent: Node, gate_name: String, s: float, finish: bool, scene: PackedScene) -> Node3D:
	var sp: Dictionary = _spot(s, 0.0, 0.06)
	var gate: Node3D = scene.instantiate()
	gate.name = gate_name
	gate.position = sp["pos"]
	gate.rotation_degrees = Vector3(0, sp["yaw"], 0)
	gate.set("is_finish_line", finish)
	parent.add_child(gate)
	return gate


func _place_gameplay(level_scene: Node3D) -> void:
	var gate_scene: PackedScene = load("res://CheckpointGate.tscn")
	var spawn_scene: PackedScene = load("res://SpawnIndicator.tscn")
	# The start gantry (its lights and ticker) and the grid behind it.
	var start: Node3D = _gate(level_scene, "StartLine", START_S, true, gate_scene)
	var spawn_points := Node3D.new()
	spawn_points.name = "SpawnPoints"
	start.add_child(spawn_points)
	var grid_coords := [
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
	var cps := Node3D.new()
	cps.name = "Checkpoints"
	level_scene.add_child(cps)
	var cp_s: Array = _checkpoints()
	for i in range(cp_s.size()):
		_gate(cps, "Checkpoint_%d" % (i + 1), cp_s[i], false, gate_scene)
	_gate(level_scene, "FinishLine", _finish_s, true, gate_scene)
	var boost_scene: PackedScene = load("res://BoostPad.tscn")
	var pads := Node3D.new()
	pads.name = "BoostPads"
	level_scene.add_child(pads)
	var boosts: Array = _boosts()
	for i in range(boosts.size()):
		var bp: Node3D = boost_scene.instantiate()
		bp.name = "Boost_%d" % (i + 1)
		var sp2: Dictionary = _spot(boosts[i][0], boosts[i][1], 0.08)
		bp.position = sp2["pos"]
		bp.rotation_degrees = Vector3(0, sp2["yaw"], 0)
		pads.add_child(bp)


# ======================================================================================
#  Safety berms
# ======================================================================================

## Windrows of rubble along the drop side of the haul road: [s from, s to, side (+1 right of travel)]. On the shelf
## the valley is to the right; down the ramp the pit is.
const BERMS := [[1296.0, 1762.0, 1.0], [1888.0, 2935.0, 1.0]]
## The berm's middle this far out from the centreline.
const BERM_LAT := ROAD_HALF + 1.9
## Across the berm (metres from its middle, outward) and up from the ground under each point: the heap drawn, and
## the wall a cart meets (steep on the road side, higher than the heap, so a cart glances off instead of riding up
## it and over the edge).
const BERM_SECTION := [[-2.3, -0.4], [-1.6, 0.45], [-0.8, 1.2], [0.0, 1.45], [0.9, 1.15], [1.7, 0.4], [2.4, -0.45]]
const BERM_WALL := [[-1.4, -0.7], [-1.05, 1.95], [0.9, 1.95], [1.7, -0.7]]

var _rubble_mat: ShaderMaterial


func _rubble_material() -> ShaderMaterial:
	if _rubble_mat == null:
		var m := ShaderMaterial.new()
		m.shader = load("res://mina_rubble.gdshader")
		m.set_shader_parameter("pebble_tex", load("res://materials/dark_canyon_rock.png"))
		m.set_shader_parameter("pebble_normal", load("res://materials/dark_canyon_rock_normal.png"))
		_rubble_mat = _save_baked_resource(m, "rubble_material", "minaprop_") as ShaderMaterial
	return _rubble_mat


## The colour of broken rock at a place: the escarpment's red sandstone, or in the pit the ore's zone at that height
## (mina_ground.gdshader's copper_rock, roughly).
func _rock_colour(p: Vector3, mined: bool) -> Color:
	if not mined:
		return Color(0.80, 0.58, 0.44)
	var depth: float = clampf((PLATEAU_Y - p.y) / (PLATEAU_Y - FLOOR_Y), 0.0, 1.0)
	var cap := Color(0.86, 0.76, 0.60)
	var oxide := Color(0.74, 0.50, 0.36)
	var primary := Color(0.62, 0.58, 0.54)
	var c: Color = cap.lerp(oxide, smoothstep(0.24, 0.36, depth))
	return c.lerp(primary, smoothstep(0.58, 0.7, depth))


func _build_berms(level_scene: Node3D) -> void:
	var root := StaticBody3D.new()
	root.name = "SafetyBerms"
	root.set_meta(&"surface", "rock")
	level_scene.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4471
	var faces := PackedVector3Array()
	var piece := 0
	for bd in BERMS:
		var s0: float = bd[0]
		var s1: float = bd[1]
		var side: float = bd[2]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var prev_ring: Array = []
		var prev_wall: Array = []
		var s := s0
		var n_sec: int = BERM_SECTION.size()
		while s <= s1 + 0.01:
			var pa: Dictionary = _at(s)
			var p2: Vector2 = pa["p"]
			var r2: Vector2 = _right_of(float(pa["th"])) * side
			# The heap swells and shrinks along its length, and its crest wanders.
			var swell: float = 0.85 + 0.3 * _detail_noise.get_noise_2d(s * 3.1, 7.0) + rng.randf_range(-0.05, 0.05)
			var shift: float = _detail_noise.get_noise_2d(s * 1.7, 31.0) * 0.35
			var ring: Array = []
			for k in range(n_sec):
				var u: float = float(BERM_SECTION[k][0]) * (0.9 + 0.1 * swell) + shift
				var q: Vector2 = p2 + r2 * (BERM_LAT + u)
				var h: float = float(BERM_SECTION[k][1]) * swell + (rng.randf_range(-0.08, 0.08) if k > 0 and k < n_sec - 1 else 0.0)
				ring.append(Vector3(q.x, _ground_at(q.x, q.y) + h, q.y))
			var wall: Array = []
			for k in range(BERM_WALL.size()):
				var q2: Vector2 = p2 + r2 * (BERM_LAT + float(BERM_WALL[k][0]))
				wall.append(Vector3(q2.x, _ground_at(q2.x, q2.y) + float(BERM_WALL[k][1]), q2.y))
			var mined: bool = _base(p2.x, p2.y).y > 1.0
			var col: Color = _rock_colour(ring[3], mined).darkened(rng.randf_range(0.0, 0.08))
			if not prev_ring.is_empty():
				for k in range(n_sec - 1):
					_quad_out(st, prev_ring[k], ring[k], ring[k + 1], prev_ring[k + 1], col)
				for k in range(BERM_WALL.size() - 1):
					faces.append_array(PackedVector3Array([prev_wall[k], wall[k], wall[k + 1], prev_wall[k], wall[k + 1], prev_wall[k + 1]]))
			prev_ring = ring
			prev_wall = wall
			s += 1.6
		st.generate_normals()
		var mesh: ArrayMesh = st.commit()
		mesh.surface_set_material(0, _rubble_material())
		var mi := MeshInstance3D.new()
		mi.name = "Berm%d" % piece
		mi.mesh = _save_baked_resource(mesh, "berm_%d" % piece, "minaprop_")
		root.add_child(mi)
		piece += 1
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	cs.shape = _save_baked_resource(shape, "berm_shape", "minaprop_")
	root.add_child(cs)


## A quad a -> b -> c -> d (a strip's edge pair: a, d on the previous ring, b, c on this one), wound to face away
## from the side its normal points: the triangles' own winding is fixed after, by the face's normal against up/out.
func _quad_out(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	for tri in [[a, b, c], [a, c, d]]:
		var p0: Vector3 = tri[0]
		var p1: Vector3 = tri[1]
		var p2: Vector3 = tri[2]
		# Godot's front faces: normal = (c - a) x (b - a). The heap's faces all look up and outward.
		if (p2 - p0).cross(p1 - p0).y < 0.0:
			var t: Vector3 = p1
			p1 = p2
			p2 = t
		st.set_color(col)
		st.add_vertex(p0)
		st.add_vertex(p1)
		st.add_vertex(p2)


# ======================================================================================
#  Dressing: helpers
# ======================================================================================

const MinaKit = preload("res://MinaKit.gd")
const CampKit = preload("res://CampKit.gd")
const CactusKit = preload("res://CactusKit.gd")
const FreightKit = preload("res://FreightKit.gd")
const CrowdPlacer = preload("res://CrowdPlacer.gd")
const PropKit = preload("res://PropKit.gd")

## People-sized things are 1.6 times life size, as on the other courses (the carts are big RC cars); so are the mine's
## machines. The balloons and the telescopes are a little less, or they would fill the sky.
const PROP_SCALE := 1.6
const BALLOON_SCALE := 1.5
const DISH_SCALE := 1.25
## Prop meshes and their materials are saved under this prefix, which MeshChunker leaves whole.
const PROP_PREFIX := "minaprop_"
const PEOPLE_SCALE := PROP_SCALE / 1.86
## A Sierra del Viento crowd: [African, South Asian, European, East Asian, Arab or mixed].
const PEOPLE_SKIN := [0.05, 0.03, 0.52, 0.04, 0.36]

var _prop_meshes := {}
## [centre (Vector2), radius] of everything placed, for the flora to keep off.
var _footprints: Array = []
## Spectators for CrowdPlacer: [position, facing, seated].
var _people: Array = []
## Footprints that sit badly on the ground: [name, rise and fall].
var _seat_report: Array = []


## A kit mesh built once by `build(pk, kit)` at `sc`, shared by every instance; saved with the rest by `_save_props`.
func _mesh(mesh_name: String, sc: float, build: Callable) -> ArrayMesh:
	if not _prop_meshes.has(mesh_name):
		var pk: PropKit = MinaKit.new_kit(sc)
		var kit := {}
		build.call(pk, kit)
		_prop_meshes[mesh_name] = pk.commit(kit)
	return _prop_meshes[mesh_name]


## Saves the kits' materials first (so every mesh refers to one per key) and then the meshes.
func _save_props() -> void:
	var mats: Dictionary = MinaKit.materials()
	for key in mats:
		var m: Material = mats[key]
		if m.resource_path == "":
			m.take_over_path("res://generated/%smat_%s.res" % [PROP_PREFIX, key])
			ResourceSaver.save(m, m.resource_path)
	for n in _prop_meshes:
		var mesh: Resource = _prop_meshes[n]
		mesh.take_over_path("res://generated/%s%s.res" % [PROP_PREFIX, n])
		ResourceSaver.save(mesh, mesh.resource_path)
	print("  props: %d meshes, %d materials" % [_prop_meshes.size(), mats.size()])


## The yaw that turns a prop's front (-z) toward `dir`.
func _yaw_to(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


## A prop standing at `pos` turned by `yaw`, solid through `boxes` ([centre, size] in its own frame, already grown),
## under a body of its own so DressingColliders leaves it be. `foot` (a radius) keeps the flora off it.
func _prop(parent: Node3D, node_name: String, mesh: Mesh, pos: Vector3, yaw: float, boxes: Array, foot := 0.0, surface := "rock") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.set_meta(&"surface", surface)
	body.transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	parent.add_child(body)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	body.add_child(mi)
	for b in boxes:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = b[1]
		cs.shape = sh
		cs.position = b[0]
		body.add_child(cs)
	if foot > 0.0:
		_footprints.append([Vector2(pos.x, pos.z), foot])
	return body


## The ground under a footprint (centre, yaw, half sizes): the lowest point, so nothing hangs over a dip. A footprint
## that rises and falls more than `tol` is reported (and fails the build's check past twice that).
func _seat(what: String, c: Vector3, yaw: float, half: Vector2, tol := 0.6) -> float:
	var r: Vector2 = _relief(c, yaw, half)
	if r.y - r.x > tol:
		_seat_report.append([what, r.y - r.x, tol])
	return r.x


func _label(parent: Node3D, text: String, at: Vector3, normal: Vector3, cap: float, col: Color, max_w := 0.0) -> void:
	var lab := Label3D.new()
	lab.text = text
	lab.font_size = 64
	var px: float = cap / 44.8
	if max_w > 0.0:
		var w: float = ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x
		if w * px > max_w:
			px = max_w / maxf(w, 1.0)
	lab.pixel_size = px
	lab.modulate = col
	lab.outline_size = 4
	lab.outline_modulate = Color(0.05, 0.05, 0.05)
	lab.double_sided = false
	lab.transform = Transform3D(Basis.looking_at(-normal, Vector3.UP), at)
	parent.add_child(lab)


## A kit's labels ([text, position, outward normal, cap height, colour, max width], in the kit's life-size frame)
## placed through the prop's transform and scale.
func _labels(parent: Node3D, labels: Array, xf: Transform3D, sc: float) -> void:
	for l in labels:
		var n: Vector3 = xf.basis * (l[2] as Vector3)
		_label(parent, l[0], xf * ((l[1] as Vector3) * sc), n, float(l[3]) * sc, l[4], float(l[5]) * sc if l.size() > 5 else 0.0)


## The nearest distance from `p` to the route's centreline (in plan).
func _route_dist(p: Vector2) -> float:
	return _road_lat(p.x, p.y).x


# ======================================================================================
#  The fiesta on the plateau
# ======================================================================================

## Balloons on the launch field either side of the start straight: [s, lat, kind (0 up and tethered, 1 lying while
## the fan fills it), livery].
const FIELD_BALLOONS := [
	[95.0, -50.0, 0, 0], [140.0, 62.0, 1, 2], [175.0, -58.0, 1, 1], [205.0, 50.0, 0, 3], [245.0, -48.0, 0, 4],
	[285.0, 64.0, 0, 6], [320.0, -60.0, 1, 7], [350.0, 52.0, 0, 5], [60.0, 54.0, 0, 1],
]
## Balloons aloft: how many, and the stretch of sky they wander over (centre x, z; half extents).
const SKY_BALLOONS := 26


func _build_fiesta(level: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Fiesta"
	level.add_child(root)
	var fiesta := Node3D.new()
	fiesta.name = "Balloons"
	fiesta.set_script(load("res://BalloonFiesta.gd"))
	root.add_child(fiesta)
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	var bs := BALLOON_SCALE
	for i in range(FIELD_BALLOONS.size()):
		var fb: Array = FIELD_BALLOONS[i]
		var sp: Dictionary = _spot(fb[0], fb[1], 0.0)
		var pos: Vector3 = sp["pos"]
		var livery: int = fb[3]
		if int(fb[2]) == 0:
			pos.y = _seat("balloon %d" % i, pos, 0.0, Vector2(3.0, 3.0))
			var mesh: ArrayMesh = _mesh("balloon_%d" % livery, bs, func(pk, kit): MinaKit.balloon(pk, kit, livery))
			var body := _prop(fiesta, "FieldBalloon_%d" % i, mesh, pos, rng.randf() * TAU, [[Vector3(0, 0.9, 0), Vector3(1.6, 1.8, 1.6) * bs]], 15.0)
			body.set_meta(&"burner", true)
			# The crew round the basket and people come to look.
			for k in range(rng.randi_range(4, 7)):
				var a: float = rng.randf() * TAU
				var d: float = rng.randf_range(4.0, 11.0)
				var pp := Vector3(pos.x + cos(a) * d, 0.0, pos.z + sin(a) * d)
				pp.y = _ground_at(pp.x, pp.z)
				_people.append([pp, (pos - pp).normalized(), false])
		else:
			# Lying along the road, the fan's end toward the start.
			var yaw: float = _yaw_to(-(sp["fwd"] as Vector3))
			var mesh2: ArrayMesh = _mesh("balloon_lying_%d" % livery, bs, func(pk, kit): MinaKit.balloon_inflating(pk, kit, livery))
			pos.y = _seat("lying balloon %d" % i, pos, yaw, Vector2(14.0, 18.0), 1.2)
			var body2 := _prop(fiesta, "InflatingBalloon_%d" % i, mesh2, pos, yaw, [[Vector3(0, 1.0, -5.4) , Vector3(1.8, 2.0, 2.0) * bs]], 22.0)
			body2.set_meta(&"burner", false)
			for k in range(rng.randi_range(3, 5)):
				var lp: Vector3 = body2.transform * Vector3(rng.randf_range(-12.0, 12.0), 0.0, rng.randf_range(-12.0, 20.0))
				lp.y = _ground_at(lp.x, lp.z)
				_people.append([lp, (pos - lp).normalized(), false])
		# A chase truck by each balloon.
		var vp: Vector3 = _spot(float(fb[0]) + 14.0, float(fb[1]) * 0.62, 0.0)["pos"]
		_footprints.append([Vector2(vp.x, vp.z), 5.0])
		_chase_vehicles.append([vp, _yaw_to(sp["fwd"]) + rng.randf_range(-0.4, 0.4), "van" if i % 3 == 0 else "suv", i])
	# Aloft: each on a slow loop of its own over the plateau (BalloonFiesta.gd moves them on the wall clock).
	for i in range(SKY_BALLOONS):
		var livery2: int = i % MinaKit.BALLOONS.size()
		var mesh3: ArrayMesh = _mesh("balloon_%d" % livery2, bs, func(pk, kit): MinaKit.balloon(pk, kit, livery2))
		var mi := MeshInstance3D.new()
		mi.name = "SkyBalloon_%d" % i
		mi.mesh = mesh3
		var centre := Vector3(rng.randf_range(-1900.0, -500.0), 0.0, rng.randf_range(-950.0, 150.0))
		centre.y = PLATEAU_Y + 8.0 + rng.randf_range(45.0, 360.0) * (0.4 + 0.6 * rng.randf())
		mi.set_meta(&"centre", centre)
		mi.set_meta(&"radius", Vector2(rng.randf_range(120.0, 420.0), rng.randf_range(90.0, 300.0)))
		mi.set_meta(&"period", rng.randf_range(700.0, 1500.0))
		mi.set_meta(&"phase", rng.randf())
		mi.set_meta(&"burner", true)
		mi.position = centre
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if i < 8 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fiesta.add_child(mi)
	# Barriers and spectators along the start straight, both sides.
	var barrier_xfs: Array = []
	var s := 64.0
	while s < 300.0:
		for side in [-1.0, 1.0]:
			var bp: Dictionary = _spot(s, side * 13.0, 0.0)
			var bpos: Vector3 = bp["pos"]
			bpos.y = _ground_at(bpos.x, bpos.z)
			barrier_xfs.append(Transform3D(Basis(Vector3.UP, _yaw_to(bp["fwd"]) + PI * 0.5), bpos))
			for row in range(2):
				if rng.randf() < 0.75:
					var pp2: Dictionary = _spot(s + rng.randf_range(-1.6, 1.6), side * (14.8 + float(row) * 1.5 + rng.randf_range(0.0, 0.6)), 0.0)
					var ppos: Vector3 = pp2["pos"]
					ppos.y = _ground_at(ppos.x, ppos.z)
					_people.append([ppos, -(pp2["right"] as Vector3) * side, false])
		s += 2.3 * PROP_SCALE
	_barriers(root, "StartBarriers", barrier_xfs)
	print("  fiesta: %d balloons on the field, %d aloft" % [FIELD_BALLOONS.size(), SKY_BALLOONS])


var _chase_vehicles: Array = []


## A run of crowd barriers (CampKit's, at PROP_SCALE), one mesh, each panel solid.
func _barriers(parent: Node3D, node_name: String, xfs: Array) -> void:
	var pk := MinaKit.new_kit(1.0)
	var camp := CampKit.new(pk)
	var kit := {}
	var body := StaticBody3D.new()
	body.name = node_name
	body.set_meta(&"surface", "rock")
	parent.add_child(body)
	for xf in xfs:
		var t: Transform3D = xf
		pk.set_frame(t.scaled_local(Vector3.ONE * PROP_SCALE))
		camp.crowd_barrier(kit)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(2.25 * PROP_SCALE, 1.1 * PROP_SCALE, 0.25)
		cs.shape = sh
		cs.transform = Transform3D(t.basis, t.origin + Vector3(0, 0.55 * PROP_SCALE, 0))
		body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = pk.commit(kit)
	mi.visibility_range_end = 500.0
	_prop_meshes[node_name.to_snake_case()] = mi.mesh
	body.add_child(mi)


## The chase trucks and the mine's pickups: CampKit's vans and SUVs, each solid.
func _build_vehicles(level: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Vehicles"
	level.add_child(root)
	var colours := [Color(0.92, 0.92, 0.90), Color(0.15, 0.30, 0.55), Color(0.62, 0.10, 0.10), Color(0.20, 0.22, 0.24), Color(0.85, 0.70, 0.30)]
	for i in range(_chase_vehicles.size()):
		var cv: Array = _chase_vehicles[i]
		var kind: String = cv[2]
		var col: Color = colours[int(cv[3]) % colours.size()]
		var key := "%s_%d" % [kind, int(cv[3]) % colours.size()]
		var mesh: ArrayMesh = _mesh(key, PROP_SCALE, func(pk, kit):
			var camp := CampKit.new(pk)
			camp.vehicle(kit, kind, col))
		var pos: Vector3 = cv[0]
		var aabb: AABB = mesh.get_aabb()
		pos.y = _seat(key, pos, cv[1], Vector2(aabb.size.x, aabb.size.z) * 0.5)
		_prop(root, "Vehicle_%d" % i, mesh, pos, cv[1], [[aabb.get_center(), aabb.size]], 0.0)


# ======================================================================================
#  The radio telescope array
# ======================================================================================

## The array's arm runs beside the plateau's straight on its east side: from s ARRAY_S0 to ARRAY_S1 along the
## straight's line, ARRAY_LAT out. The dishes stand on it at ARRAY_DISHES (s) and all look the same way.
const ARRAY_S0 := 520.0
const ARRAY_S1 := 1020.0
const ARRAY_LAT := -82.0
const ARRAY_DISHES := [560.0, 622.0, 684.0, 740.0, 905.0, 968.0]
const DISH_AZ := 2.35
const DISH_EL := 0.92
## The other two arms, far off: [heading from the hub (radians), dishes].
const FAR_ARMS := [[-0.55, 7], [2.6, 6]]


func _build_array(level: Node3D) -> void:
	var root := Node3D.new()
	root.name = "RadioArray"
	level.add_child(root)
	var straight: Dictionary = _at(800.0)
	var dir2: Vector2 = _dir_of(float(straight["th"]))
	var origin2: Vector2 = (straight["p"] as Vector2) + _right_of(float(straight["th"])) * ARRAY_LAT
	var dir := Vector3(dir2.x, 0.0, dir2.y)
	var right := Vector3(-dir2.y, 0.0, dir2.x)
	# The double track: rail tops on the ground smoothed along it (so it bridges the wash on a trestle).
	var n: int = int((ARRAY_S1 - ARRAY_S0) / 3.0)
	var line: Array = []
	var raw := PackedFloat32Array()
	for k in range(n + 1):
		var u: float = ARRAY_S0 + float(k) * 3.0 - 800.0
		var q: Vector2 = origin2 + dir2 * u
		line.append(q)
		raw.append(_ground_at(q.x, q.y))
	var smooth := PackedFloat32Array()
	for k in range(raw.size()):
		var sum := 0.0
		var cnt := 0
		for j in range(maxi(k - 13, 0), mini(k + 14, raw.size())):
			sum += raw[j]
			cnt += 1
		smooth.append(maxf(sum / float(cnt), raw[k]) + 0.55)
	var bed_faces: Array = []
	for side in [-3.6, 3.6]:
		var pts: Array = []
		var bed: Array = []
		for k in range(line.size()):
			var q2: Vector2 = line[k] + Vector2(right.x, right.z) * side
			pts.append(Vector3(q2.x, smooth[k], q2.y))
			bed.append(smooth[k] - raw[k] < 1.2)
		var mi := MeshInstance3D.new()
		mi.name = "ArrayRails_%d" % int(side > 0.0)
		mi.mesh = FreightKit.track_piece(pts, bed, 31 + int(side), bed_faces)
		_prop_meshes["array_rails_%d" % int(side > 0.0)] = mi.mesh
		root.add_child(mi)
	# Where the track crosses the wash it stands on timber trestles.
	var tkit := {}
	var tpk: PropKit = MinaKit.new_kit(1.0)
	for k in range(0, line.size(), 2):
		var lift: float = smooth[k] - raw[k]
		if lift < 1.0:
			continue
		for side2 in [-3.6, 3.6]:
			var c: Vector2 = line[k] + Vector2(right.x, right.z) * side2
			for e in [-1.3, 1.3]:
				var f: Vector2 = c + Vector2(right.x, right.z) * e
				tpk.beam(tkit, "wood", Vector3(f.x, raw[k] - 0.3, f.y), Vector3(f.x, smooth[k] - 0.3, f.y), 0.3, 0.3, Color(0.45, 0.34, 0.24))
			tpk.beam(tkit, "wood", Vector3(c.x, smooth[k] - 0.35, c.y) - right * 1.5, Vector3(c.x, smooth[k] - 0.35, c.y) + right * 1.5, 0.3, 0.3, Color(0.42, 0.32, 0.22))
	if not tkit.is_empty():
		var tmi := MeshInstance3D.new()
		tmi.name = "WashTrestle"
		tmi.mesh = tpk.commit(tkit)
		_prop_meshes["wash_trestle"] = tmi.mesh
		root.add_child(tmi)
	var bed_body := StaticBody3D.new()
	bed_body.name = "ArrayRailBed"
	bed_body.set_meta(&"surface", "gravel")
	root.add_child(bed_body)
	var bshape := ConcavePolygonShape3D.new()
	bshape.set_faces(PackedVector3Array(bed_faces))
	var bcs := CollisionShape3D.new()
	bcs.shape = bshape
	bed_body.add_child(bcs)
	_prop_meshes["array_bed_shape"] = bshape
	# The dishes, on pads over the track, all looking at one spot in the sky.
	var dish: ArrayMesh = _mesh("radio_dish", DISH_SCALE, func(pk, kit): MinaKit.radio_dish(pk, kit, 0.0, DISH_EL))
	var placed := 0
	for ds in ARRAY_DISHES:
		var q3: Vector2 = origin2 + dir2 * (float(ds) - 800.0)
		var pos := Vector3(q3.x, 0.0, q3.y)
		if _route_dist(q3) < 40.0:
			push_error("radio dish at %.0f is %.0fm from the road" % [ds, _route_dist(q3)])
		pos.y = _seat("dish %.0f" % ds, pos, DISH_AZ, Vector2(8.0, 8.0), 1.5) - 0.2
		_prop(root, "Dish_%d" % placed, dish, pos, DISH_AZ, [[Vector3(0, 0.45, 0) * DISH_SCALE, Vector3(13.0, 0.9, 13.0) * DISH_SCALE],
				[Vector3(0, 5.5, 0) * DISH_SCALE, Vector3(5.0, 10.0, 5.0) * DISH_SCALE]], 22.0)
		placed += 1
	# The far arms: dishes standing off across the plateau, the sun behind some of them.
	var hub: Vector2 = origin2 + dir2 * (ARRAY_S0 - 800.0 - 140.0)
	for arm in FAR_ARMS:
		var ad := Vector2(cos(float(arm[0])), sin(float(arm[0])))
		for k in range(int(arm[1])):
			var q4: Vector2 = hub + ad * (220.0 + float(k) * 150.0)
			if _route_dist(q4) < 80.0:
				continue
			var p4 := Vector3(q4.x, _ground_at(q4.x, q4.y) - 0.2, q4.y)
			_prop(root, "FarDish_%d_%d" % [int(arm[1]), k], dish, p4, DISH_AZ, [[Vector3(0, 5.5, 0) * DISH_SCALE, Vector3(13.0, 11.0, 13.0) * DISH_SCALE]], 22.0)
			placed += 1
	print("  radio array: %d dishes" % placed)


# ======================================================================================
#  The mine's gate and its signs
# ======================================================================================

const GATE_S := 1268.0
## Signs: [s, lat, kind, text, second line].
const SIGNS := [
	[1205.0, -12.5, "info", "MINA DEL VIENTO", "COBRE  -  2 KM"],
	[1300.0, -11.5, "warn", "PELIGRO", "ZONA DE VOLADURAS"],
	[1420.0, -11.5, "warn", "VIENTO FUERTE", "TORMENTAS DE POLVO"],
	[1560.0, -11.5, "mine", "VELOCIDAD MAX", "40 KM/H"],
	[1745.0, -12.0, "warn", "CURVA", "PELIGROSA"],
	[1920.0, -11.8, "mine", "RAMPA PRINCIPAL", "NIVEL 3200"],
	[2560.0, -11.8, "mine", "NIVEL 3160", "BANCO 6"],
]


## The fixed signs and those that follow the route: onto the floor, the sump's corner, the plant.
func _signs() -> Array:
	var out: Array = SIGNS.duplicate(true)
	out.append([_ramp_s1 + 15.0, -12.0, "warn", "TRAFICO PESADO", "VEHICULOS MINEROS"])
	out.append([float(_turns[T_SUMP_TURN]["s0"]) - 45.0, 12.0, "warn", "PELIGRO", "AGUA PROFUNDA"])
	out.append([float(_turns[T_MOUTH]["s1"]) + 40.0, -12.5, "info", "PLANTA", "TALLER  -  OFICINAS"])
	return out


func _build_gate(level: Node3D) -> void:
	var root := Node3D.new()
	root.name = "MineGate"
	level.add_child(root)
	var sp: Dictionary = _spot(GATE_S, 0.0, 0.0)
	var labels: Array = []
	var gate: ArrayMesh = _mesh("mine_gate", PROP_SCALE, func(pk, kit): MinaKit.mine_gate(pk, kit, labels, 11.5 / PROP_SCALE * 1.0 + 0.0))
	var pos: Vector3 = sp["pos"]
	pos.y = _road_y(GATE_S) - 0.05
	var yaw: float = sp["yaw"] * PI / 180.0
	var hw := 11.5
	var body := _prop(root, "Gate", gate, pos, yaw, [[Vector3(-hw, 5.9, 0), Vector3(1.6, 11.8, 1.6)], [Vector3(hw, 5.9, 0), Vector3(1.6, 11.8, 1.6)],
			[Vector3(hw + 5.8, 2.3, 6.1), Vector3(5.8, 4.6, 5.8)]], 0.0)
	_labels(root, labels, body.transform, PROP_SCALE)
	var signs: Array = _signs()
	for i in range(signs.size()):
		var sg: Array = signs[i]
		var ss: Dictionary = _spot(sg[0], sg[1], 0.0)
		var sp2: Vector3 = ss["pos"]
		sp2.y = _ground_at(sp2.x, sp2.z)
		var kind: String = sg[2]
		var smesh: ArrayMesh = _mesh("sign_" + kind, PROP_SCALE, func(pk, kit): MinaKit.sign_board(pk, kit, Vector3.ZERO, 0.0, kind))
		# Facing the drivers coming toward it.
		var syaw: float = _yaw_to(-(ss["fwd"] as Vector3))
		var mi := MeshInstance3D.new()
		mi.name = "Sign_%d" % i
		mi.mesh = smesh
		mi.transform = Transform3D(Basis(Vector3.UP, syaw), sp2)
		root.add_child(mi)
		var ink := Color(0.06, 0.06, 0.06) if kind == "warn" else Color(0.97, 0.97, 0.95)
		var face: Vector3 = Basis(Vector3.UP, syaw) * Vector3(0, 0, -1)
		_label(root, sg[3], sp2 + Vector3.UP * (2.2 + 1.1) * PROP_SCALE + face * 0.1, face, 0.42 * PROP_SCALE, ink, 2.9 * PROP_SCALE)
		_label(root, sg[4], sp2 + Vector3.UP * (2.2 + 0.5) * PROP_SCALE + face * 0.1, face, 0.3 * PROP_SCALE, ink, 2.9 * PROP_SCALE)


# ======================================================================================
#  The pit: the shovel at the face, trucks, the crusher, light towers, the sump
# ======================================================================================

## The shovel digs the north wall's toe, its muck pile against the face, a truck beside it to load.
const SHOVEL_AT := Vector2(70.0, -104.0)
const MUCK_AT := Vector2(70.0, -124.0)
const MUCK_HALF := Vector2(30.0, 7.0)
const MUCK_H := 8.0
const CRUSHER_AT := Vector2(0.0, 98.0)
## Trucks: [x, z, heading (degrees, 0 toward -z), loaded, kind ("haul" or "water")]. Several stand on the insides of
## the floor's bends, so its turns go round them.
const PIT_TRUCKS := [
	[114.0, -108.0, 90.0, true, "haul"],
	[165.0, 40.0, 0.0, true, "haul"],
	[165.0, -25.0, 180.0, false, "water"],
	[90.0, 100.0, 90.0, false, "haul"],
	[88.0, 58.0, -90.0, false, "haul"],
	[100.0, 2.0, 0.0, true, "haul"],
	[0.0, 76.0, 0.0, true, "haul"],
	[-25.0, 15.0, 120.0, false, "haul"],
	[20.0, -35.0, -60.0, true, "haul"],
]
const LIGHT_TOWERS := [[150.0, -60.0, 90.0], [-110.0, -30.0, 0.0], [30.0, 60.0, 20.0], [140.0, 110.0, 0.0], [-120.0, 30.0, 0.0]]
const DRILLS := [[-5.0, -112.0, 180.0], [-40.0, -114.0, 170.0]]
## How far a pit machine's footprint keeps off the floor track's edge.
const PIT_CLEAR := 2.5


## Errors when a footprint (centre, yaw, half sizes) comes within `margin` of the route's edge.
func _check_clear(what: String, c: Vector3, yaw: float, half: Vector2, margin: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var nearest := 1e9
	for u in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		for v in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			var p: Vector3 = c + b * Vector3(u * half.x, 0.0, v * half.y)
			nearest = minf(nearest, _route_dist(Vector2(p.x, p.z)))
	if nearest < ROAD_HALF + margin:
		push_error("%s stands %.1fm from the road's middle (keep %.1f)" % [what, nearest, ROAD_HALF + margin])


func _truck_mesh(loaded: bool, kind: String) -> ArrayMesh:
	if kind == "water":
		return _mesh("water_truck", PROP_SCALE, func(pk, kit): MinaKit.water_truck(pk, kit))
	return _mesh("haul_truck_%d" % int(loaded), PROP_SCALE, func(pk, kit): MinaKit.haul_truck(pk, kit, MinaKit.MINE_YELLOW, loaded, 0.3 + 0.4 * float(loaded)))


## A haul truck parked at (x, z) facing `yaw`: solid as two boxes (the body over the wheels, the deck in front).
func _truck(parent: Node3D, node_name: String, x: float, z: float, yaw: float, loaded: bool, kind := "haul") -> void:
	var s := PROP_SCALE
	var pos := Vector3(x, 0.0, z)
	_check_clear(node_name, pos, yaw, Vector2(4.9, 7.8) * s, PIT_CLEAR)
	pos.y = _seat(node_name, pos, yaw, Vector2(5.0, 8.0) * s, 0.5) - 0.05
	_prop(parent, node_name, _truck_mesh(loaded, kind), pos, yaw, [[Vector3(0, 4.3, 0.2) * s, Vector3(9.8, 7.8, 15.4) * s]], 16.0)


func _build_pit(level: Node3D) -> void:
	var root := Node3D.new()
	root.name = "PitWorks"
	level.add_child(root)
	var s := PROP_SCALE
	# The face being dug: the muck pile against the east wall, the shovel facing it.
	var muck: ArrayMesh = _mesh("muck_pile", 1.0, func(pk, kit): MinaKit.muck_pile(pk, kit, MUCK_HALF, MUCK_H, 0.4))
	var mpos := Vector3(MUCK_AT.x, FLOOR_Y - 0.4, MUCK_AT.y)
	# Its steep side (the kit's +z) against the north wall.
	var mbody := _prop(root, "MuckPile", muck, mpos, PI, [], 30.0)
	var hull := ConvexPolygonShape3D.new()
	var hp := PackedVector3Array()
	for u in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		for v in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			var dome: float = maxf(1.0 - pow(absf(u), 3.0) - pow(absf(v - 0.25) / 1.25, 2.0), 0.0)
			hp.append(Vector3(u * MUCK_HALF.x, MUCK_H * pow(dome, 0.7) * 0.85, v * MUCK_HALF.y))
	hull.points = hp
	var hcs := CollisionShape3D.new()
	hcs.shape = hull
	mbody.add_child(hcs)
	var shovel: ArrayMesh = _mesh("rope_shovel", s, func(pk, kit): MinaKit.rope_shovel(pk, kit, 0.0, 0.75, 4.0))
	var spos := Vector3(SHOVEL_AT.x, 0.0, SHOVEL_AT.y)
	var syaw := 0.0
	_check_clear("shovel", spos, syaw, Vector2(6.5, 7.0) * s, PIT_CLEAR)
	spos.y = _seat("shovel", spos, syaw, Vector2(6.5, 7.0) * s, 0.5) - 0.05
	_prop(root, "RopeShovel", shovel, spos, syaw, [[Vector3(0, 1.5, 0) * s, Vector3(13.0, 3.0, 13.5) * s], [Vector3(0, 7.5, 2.4) * s, Vector3(10.8, 7.5, 11.0) * s]], 30.0)
	_label(root, "MINA DEL VIENTO", spos + Basis(Vector3.UP, syaw) * (Vector3(5.24, 9.7, 2.4) * s), Basis(Vector3.UP, syaw) * Vector3.RIGHT, 0.55 * s, Color(0.96, 0.96, 0.94), 9.0 * s)
	for i in range(PIT_TRUCKS.size()):
		var t: Array = PIT_TRUCKS[i]
		_truck(root, "PitTruck_%d" % i, t[0], t[1], deg_to_rad(float(t[2])), t[3], t[4])
	var light: ArrayMesh = _mesh("light_tower", s, func(pk, kit): MinaKit.light_tower(pk, kit))
	for i in range(LIGHT_TOWERS.size()):
		var lt: Array = LIGHT_TOWERS[i]
		var lp := Vector3(lt[0], 0.0, lt[1])
		var ly: float = deg_to_rad(float(lt[2]))
		_check_clear("light tower %d" % i, lp, ly, Vector2(2.0, 2.0) * s, PIT_CLEAR)
		lp.y = _seat("light %d" % i, lp, ly, Vector2(2.0, 2.0) * s, 0.4)
		_prop(root, "LightTower_%d" % i, light, lp, ly, [[Vector3(0, 1.3, 0) * s, Vector3(2.2, 2.6, 3.6) * s]], 5.0)
	var drill: ArrayMesh = _mesh("drill_rig", s, func(pk, kit): MinaKit.drill_rig(pk, kit))
	for i in range(DRILLS.size()):
		var dr: Array = DRILLS[i]
		var dp := Vector3(dr[0], 0.0, dr[1])
		var dyaw: float = deg_to_rad(float(dr[2]))
		_check_clear("drill %d" % i, dp, dyaw, Vector2(2.7, 4.0) * s, PIT_CLEAR)
		dp.y = _seat("drill %d" % i, dp, dyaw, Vector2(2.7, 4.0) * s, 0.4)
		_prop(root, "DrillRig_%d" % i, drill, dp, dyaw, [[Vector3(0, 2.0, 0.4) * s, Vector3(5.4, 4.2, 7.8) * s]], 8.0)
	# The in-pit crusher by the mouth, a truck backed up to its pocket.
	var clabels: Array = []
	var cmesh: ArrayMesh = _mesh("crusher", s, func(pk, kit): MinaKit.crusher(pk, kit, clabels))
	var cpos := Vector3(CRUSHER_AT.x, 0.0, CRUSHER_AT.y)
	_check_clear("crusher", cpos + Vector3(0, 0, 5.0 * s), 0.0, Vector2(12.0, 7.0) * s, PIT_CLEAR)
	cpos.y = _seat("crusher", cpos, 0.0, Vector2(12.0, 7.0) * s, 0.6) - 0.1
	var cbody := _prop(root, "Crusher", cmesh, cpos, 0.0, [[Vector3(0, 3.6, 4.0) * s, Vector3(24.0, 7.2, 12.0) * s], [Vector3(0, 16.0, 5.5) * s, Vector3(16.0, 20.0, 13.0) * s]], 24.0)
	_labels(root, clabels, cbody.transform, s)
	# The sump: still water in the floor's low corner, blue-green with copper, deep enough to drown a cart. PlayerCart
	# takes the first node named "...Water" for the level's water: its bounds keep it to the sump, or the mouth and the
	# valley, which lie below its surface, would flood every engine.
	var water := MeshInstance3D.new()
	water.name = "SumpWater"
	water.set_meta(&"water_surface_y", SUMP_WATER_Y)
	water.set_meta(&"water_bounds_min", SUMP - Vector2.ONE * (SUMP_R + 6.0))
	water.set_meta(&"water_bounds_max", SUMP + Vector2.ONE * (SUMP_R + 6.0))
	var disc := CylinderMesh.new()
	disc.top_radius = SUMP_R + 8.0
	disc.bottom_radius = SUMP_R + 8.0
	disc.height = 0.05
	disc.radial_segments = 48
	water.mesh = disc
	var wm := ShaderMaterial.new()
	wm.shader = load("res://still_water.gdshader")
	wm.set_shader_parameter("water_color", Color(0.04, 0.30, 0.28))
	wm.set_shader_parameter("sky_tint", Color(0.35, 0.72, 0.66))
	wm.set_shader_parameter("ripple_strength", 0.12)
	water.material_override = _save_baked_resource(wm, "sump_water_material", PROP_PREFIX)
	water.position = Vector3(SUMP.x, SUMP_WATER_Y, SUMP.y)
	root.add_child(water)
	print("  pit: shovel, %d trucks, crusher, %d light towers, %d drills" % [PIT_TRUCKS.size(), LIGHT_TOWERS.size(), DRILLS.size()])


# ======================================================================================
#  Conveyors: from the crusher out through the mouth, over the road, to the stockpile and the plant
# ======================================================================================

## The belt's line, world metres (y up from the ground under each point, added by `_conveyor_points`), and which
## segments are galleries over the road.
const CONVEYOR_A := [[0.0, 119.0, 3.0], [-26.5, 121.0, 3.2], [-26.5, 395.0, 4.2], [-8.0, 438.0, 7.0], [6.0, 452.0, 7.0]]
const CONVEYOR_A_BRIDGES := []
const CONVEYOR_B := [[70.0, 470.0, 4.0], [128.0, 490.0, 9.0], [150.0, 498.0, 14.0], [168.0, 572.0, 14.0], [182.0, 592.0, 9.0], [200.0, 610.0, 6.0]]
const CONVEYOR_B_BRIDGES := [2]
const STOCKPILE_AT := Vector2(38.0, 456.0)
const STOCKPILE_R := 17.0


func _conveyor_points(def: Array) -> Array:
	var out: Array = []
	for d in def:
		out.append(Vector3(float(d[0]), _ground_at(float(d[0]), float(d[1])) + float(d[2]), float(d[1])))
	return out


func _build_conveyors(level: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Conveyors"
	level.add_child(root)
	var s := PROP_SCALE
	var body := StaticBody3D.new()
	body.name = "ConveyorSupports"
	body.set_meta(&"surface", "rock")
	root.add_child(body)
	for c in [[CONVEYOR_A, CONVEYOR_A_BRIDGES, "conveyor_a"], [CONVEYOR_B, CONVEYOR_B_BRIDGES, "conveyor_b"]]:
		var pts: Array = _conveyor_points(c[0])
		var bridges: Array = c[1]
		# Built in the kit's life-size frame (points and ground divided by the scale), grown back by it.
		var kpts: Array = []
		for p in pts:
			kpts.append((p as Vector3) / s)
		var ground := func(x: float, z: float) -> float: return _ground_at(x * s, z * s) / s
		var mesh: ArrayMesh = _mesh(c[2], s, func(pk, kit): MinaKit.conveyor_run(pk, kit, kpts, bridges, ground))
		var mi := MeshInstance3D.new()
		mi.name = String(c[2]).to_pascal_case()
		mi.mesh = mesh
		body.add_child(mi)
		# Solid: a box round each low segment (a cart meets the frame, not the gaps under it), the bridges' towers.
		for i in range(pts.size() - 1):
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[i + 1]
			var mid: Vector3 = (a + b) * 0.5
			var dir: Vector3 = (b - a)
			var flat := Vector3(dir.x, 0.0, dir.z)
			var basis := Basis(Vector3.UP, _yaw_to(flat.normalized()))
			if bridges.has(i):
				for e in [a, b]:
					var gy: float = _ground_at(e.x, e.z)
					_box_shape(body, Transform3D(basis, Vector3(e.x, (gy + e.y) * 0.5, e.z)), Vector3(5.4 * s, e.y - gy, 3.6 * s))
				continue
			var low_y: float = minf(a.y, b.y)
			var g_mid: float = _ground_at(mid.x, mid.z)
			if low_y - g_mid < 6.0:
				_box_shape(body, Transform3D(basis, Vector3(mid.x, (g_mid + mid.y) * 0.5, mid.z)), Vector3(2.6 * s, mid.y - g_mid + 0.6, flat.length()))
		for i in bridges:
			var a2: Vector3 = pts[i]
			var b2: Vector3 = pts[i + 1]
			var lowest := 1e9
			for k in range(9):
				var p: Vector3 = a2.lerp(b2, float(k) / 8.0)
				lowest = minf(lowest, p.y - 0.6 * s - _ground_at(p.x, p.z))
			print("  %s: bridge %d clears the ground by %.1fm" % [c[2], i, lowest])
			if lowest < 9.0:
				push_error("%s: the bridge over the road is only %.1fm up" % [c[2], lowest])
	# The stockpile in the valley's bend, its stacker fed by the first conveyor.
	var pile: ArrayMesh = _mesh("stockpile", s, func(pk, kit): MinaKit.stockpile(pk, kit, STOCKPILE_R))
	var ppos := Vector3(STOCKPILE_AT.x, VALLEY_Y - 0.3, STOCKPILE_AT.y)
	var pbody := _prop(root, "Stockpile", pile, ppos, PI, [], STOCKPILE_R * s + 4.0)
	var cone := ConvexPolygonShape3D.new()
	var cp := PackedVector3Array()
	var ph: float = STOCKPILE_R * s * tan(deg_to_rad(34.0))
	for k in range(16):
		var a3: float = TAU * float(k) / 16.0
		cp.append(Vector3(cos(a3), 0.0, sin(a3)) * STOCKPILE_R * s)
	cp.append(Vector3(0, ph, 0))
	cone.points = cp
	var ccs := CollisionShape3D.new()
	ccs.shape = cone
	pbody.add_child(ccs)
	if _route_dist(STOCKPILE_AT) < STOCKPILE_R * s + ROAD_HALF + 6.0:
		push_error("the stockpile is %.0fm from the road" % _route_dist(STOCKPILE_AT))


func _box_shape(body: Node3D, xf: Transform3D, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.transform = xf
	body.add_child(cs)


# ======================================================================================
#  The valley: the truck shop, the concentrator, the finish
# ======================================================================================

const SHOP_AT := Vector2(330.0, 468.0)
const CONC_AT := Vector2(232.0, 640.0)
const THICKENERS := [Vector2(300.0, 655.0), Vector2(345.0, 640.0)]
const SHOP_TRUCKS := [[300.0, 515.0, 0.0, false], [340.0, 512.0, 10.0, false], [230.0, 500.0, -80.0, true]]
## The grandstand's middle, this far past the finish line.
const STAND_PAST := 16.0
const STAND_LAT := 22.0


func _build_valley(level: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Plant"
	level.add_child(root)
	var s := PROP_SCALE
	# The truck shop, its bays open toward the road (south): 66 x 34 x 24m life size.
	var slabels: Array = []
	var shop: ArrayMesh = _mesh("truck_shop", s, func(pk, kit): MinaKit.truck_shop(pk, kit, slabels))
	var spos := Vector3(SHOP_AT.x, 0.0, SHOP_AT.y)
	# Its front (-z in the kit) toward +z, the road.
	var syaw := PI
	spos.y = _seat("truck shop", spos, syaw, Vector2(39.0, 17.0) * s, 0.6) - 0.05
	var sb := _prop(root, "TruckShop", shop, spos + Basis(Vector3.UP, syaw) * Vector3(0, 0, -17.0 * s), syaw, [
		[Vector3(0, 11.0, 33.8) * s, Vector3(66.0, 22.0, 0.6) * s],
		[Vector3(-33.0, 11.0, 17.0) * s, Vector3(0.6, 22.0, 34.0) * s],
		[Vector3(33.0, 11.0, 17.0) * s, Vector3(0.6, 22.0, 34.0) * s],
		[Vector3(-31.1, 11.0, 0.0) * s, Vector3(3.8, 22.0, 0.6) * s],
		[Vector3(-10.4, 11.0, 0.0) * s, Vector3(3.8, 22.0, 0.6) * s],
		[Vector3(10.4, 11.0, 0.0) * s, Vector3(3.8, 22.0, 0.6) * s],
		[Vector3(31.1, 11.0, 0.0) * s, Vector3(3.8, 22.0, 0.6) * s],
		[Vector3(39.0, 3.5, 12.0) * s, Vector3(12.0, 7.0, 20.0) * s],
	], 0.0)
	_footprints.append([SHOP_AT, 70.0])
	_labels(root, slabels, sb.transform, s)
	for i in range(SHOP_TRUCKS.size()):
		var t: Array = SHOP_TRUCKS[i]
		_truck(root, "ShopTruck_%d" % i, t[0], t[1], deg_to_rad(float(t[2])), t[3])
	# A truck inside the middle bay, nose in.
	_truck(root, "ShopTruckInside", SHOP_AT.x, SHOP_AT.y - 4.0, PI, false)
	# The concentrator: a tall mill building, the thickeners beside it.
	var clabels: Array = []
	var conc: ArrayMesh = _mesh("concentrator", s, func(pk, kit): MinaKit.crusher(pk, kit, clabels))
	var cpos := Vector3(CONC_AT.x, 0.0, CONC_AT.y)
	cpos.y = _seat("concentrator", cpos, PI, Vector2(12.0, 7.0) * s, 0.6) - 0.1
	var cbody := _prop(root, "Concentrator", conc, cpos, PI, [[Vector3(0, 3.6, 4.0) * s, Vector3(24.0, 7.2, 12.0) * s], [Vector3(0, 16.0, 5.5) * s, Vector3(16.0, 20.0, 13.0) * s]], 30.0)
	for l in clabels:
		l[0] = "CONCENTRADORA"
	_labels(root, clabels, cbody.transform, s)
	var thick: ArrayMesh = _mesh("thickener", s, func(pk, kit): MinaKit.thickener(pk, kit, 14.0))
	for i in range(THICKENERS.size()):
		var tp := Vector3(THICKENERS[i].x, 0.0, THICKENERS[i].y)
		tp.y = _seat("thickener %d" % i, tp, 0.0, Vector2(15.0, 15.0) * s, 0.6) - 0.1
		var tb := _prop(root, "Thickener_%d" % i, thick, tp, 0.6 * float(i), [], 24.0)
		var cyl := CylinderShape3D.new()
		cyl.radius = 14.0 * s
		cyl.height = 4.2 * s
		var tcs := CollisionShape3D.new()
		tcs.shape = cyl
		tcs.position = Vector3(0, 2.1 * s, 0)
		tb.add_child(tcs)
	# The finish: a grandstand beside the line, spectators along both sides behind barriers.
	var seats: Array = []
	var stand: ArrayMesh = _mesh("grandstand", s, func(pk, kit): MinaKit.grandstand(pk, kit, 44.0, seats))
	var stand_s: float = _finish_s + STAND_PAST
	var fs: Dictionary = _spot(stand_s, STAND_LAT, 0.0)
	var fpos: Vector3 = fs["pos"]
	# The stand's front (-z) toward the road.
	var fyaw: float = _yaw_to(-(fs["right"] as Vector3))
	fpos.y = _seat("grandstand", fpos + (fs["right"] as Vector3) * 3.0 * s, fyaw, Vector2(23.0, 4.0) * s, 0.6) - 0.05
	var fbody := _prop(root, "Grandstand", stand, fpos, fyaw, [[Vector3(0, 2.4, 3.0) * s, Vector3(44.0, 4.8, 6.0) * s]], 40.0)
	for st in seats:
		_people.append([fbody.transform * ((st[0] as Vector3) * s), fbody.transform.basis * (st[1] as Vector3), true])
	var bx: Array = []
	var ss := _finish_s - 70.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	while ss < _finish_s + 40.0:
		for side in [-1.0, 1.0]:
			if side > 0.0 and absf(ss - stand_s) < 40.0:
				continue
			var bp: Dictionary = _spot(ss, side * 12.5, 0.0)
			var bpos: Vector3 = bp["pos"]
			bpos.y = _ground_at(bpos.x, bpos.z)
			bx.append(Transform3D(Basis(Vector3.UP, _yaw_to(bp["fwd"]) + PI * 0.5), bpos))
			for row in range(2):
				if rng.randf() < 0.8:
					var pp: Dictionary = _spot(ss + rng.randf_range(-1.5, 1.5), side * (14.3 + float(row) * 1.5 + rng.randf_range(0.0, 0.5)), 0.0)
					var ppos: Vector3 = pp["pos"]
					ppos.y = _ground_at(ppos.x, ppos.z)
					_people.append([ppos, -(pp["right"] as Vector3) * side, false])
		ss += 2.3 * PROP_SCALE
	_barriers(root, "FinishBarriers", bx)
	# Pickups round the shop and the plant.
	for v in [[280.0, 520.0, 1.3], [380.0, 515.0, 1.6], [260.0, 600.0, -0.4], [480.0, 600.0, 0.2]]:
		_chase_vehicles.append([Vector3(v[0], 0.0, v[1]), v[2], "suv", int(v[0]) % 5])


# ======================================================================================
#  Plants and rocks
# ======================================================================================

## Whether flora may stand at `p`: off the road and its verges, the mine, the pads and everything placed.
func _flora_ok(p: Vector2, clear := 2.5) -> bool:
	if _route_dist(p) < ROAD_HALF + 4.5:
		return false
	if _base(p.x, p.y).y > 0.6:
		return false
	for f in _footprints:
		if p.distance_to(f[0]) < float(f[1]) + clear:
			return false
	for pd in _pads:
		if absf(p.x - float(pd[0])) < float(pd[2]) + 6.0 and absf(p.y - float(pd[1])) < float(pd[3]) + 6.0:
			return false
	if _slope_at(p.x, p.y) > 0.55:
		return false
	return true


func _build_flora(level: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Desert"
	level.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6651
	var cactus := CactusKit.new()
	var cmat: Material = cactus.material()
	# The high desert: sagebrush, a few cholla, prickly pear, barrel and ocotillo, a rare saguaro.
	var plants: Array = [["cholla", 3, Vector2(1.8, 2.8), 0.30], ["pear", 4, Vector2(1.2, 2.0), 0.25], ["barrel", 3, Vector2(0.9, 1.6), 0.2],
			["ocotillo", 3, Vector2(3.5, 5.5), 0.15], ["saguaro", 4, Vector2(6.0, 9.0), 0.1]]
	var meshes := {}
	var far_meshes := {}
	for pl in plants:
		for v in range(int(pl[1])):
			meshes["%s_%d" % [pl[0], v]] = cactus.build(pl[0], v, 0, cmat)
			far_meshes["%s_%d" % [pl[0], v]] = cactus.build(pl[0], v, 1, cmat)
	var sage: Array = []
	for v in 3:
		sage.append(FreightKit.sage(200 + v))
	var rock_mat := ShaderMaterial.new()
	rock_mat.shader = load("res://canyon_rock.gdshader")
	rock_mat.set_shader_parameter("sand_tex", load("res://materials/sand.png"))
	rock_mat.set_shader_parameter("rock_tex", load("res://materials/dark_rock.png"))
	rock_mat.set_shader_parameter("rock_normal", load("res://generated/mina_rock_normal.res"))
	rock_mat.set_shader_parameter("tint", Color(0.82, 0.62, 0.48))
	rock_mat.set_shader_parameter("tint_amount", 0.6)
	var pit_mat: ShaderMaterial = rock_mat.duplicate()
	pit_mat.set_shader_parameter("tint", Color(0.66, 0.56, 0.48))
	pit_mat.set_shader_parameter("tint_amount", 0.85)
	pit_mat.set_shader_parameter("moss", 0.0)
	var rocks := {}
	for v in 4:
		rocks["rock_l%d" % v] = FreightKit.boulder(5300 + v, Vector3(1.4, 0.62, 1.15), rock_mat)
		rocks["rock_t%d" % v] = FreightKit.boulder(5320 + v, Vector3(1.0, 0.95, 0.88), rock_mat)
		rocks["pit_%d" % v] = FreightKit.boulder(5340 + v, Vector3(1.2, 0.8, 1.0), pit_mat)
	var cells := {}
	var placed := 0
	var add := func(kind: String, xf: Transform3D) -> void:
		var key := "%s|%d|%d" % [kind, floori(xf.origin.x / 320.0), floori(xf.origin.z / 320.0)]
		if not cells.has(key):
			cells[key] = []
		cells[key].append(xf)
	# Along the route, both sides, thicker near it and thinning out to 250m.
	var s := 0.0
	var total: float = float(_route["len"])
	while s < total:
		for k in range(12):
			var side: float = -1.0 if rng.randf() < 0.5 else 1.0
			var lat: float = side * (ROAD_HALF + 5.0 + rng.randf() * rng.randf() * 250.0)
			var sp: Dictionary = _spot(s + rng.randf_range(-3.0, 3.0), lat, 0.0)
			var pos: Vector3 = sp["pos"]
			var p2 := Vector2(pos.x, pos.z)
			if not _flora_ok(p2):
				continue
			pos.y = _ground_at(pos.x, pos.z) - 0.05
			var roll: float = rng.randf()
			if roll < 0.62:
				add.call("sage_%d" % rng.randi_range(0, 2), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.9, 2.0)), pos))
			elif roll < 0.82:
				var tall: bool = rng.randf() < 0.35 and absf(lat) > 14.0
				var h: float = rng.randf_range(0.8, 2.2) if tall else rng.randf_range(0.25, 0.7)
				var rk: String = ("rock_t%d" if tall else "rock_l%d") % rng.randi_range(0, 3)
				add.call(rk, _rock_xf(h, rng.randf() * TAU, pos, rocks[rk]))
			else:
				var pl: Array = plants[rng.randi_range(0, plants.size() - 1)]
				if rng.randf() > float(pl[3]) * 3.0:
					continue
				var kind: String = "%s_%d" % [pl[0], rng.randi_range(0, int(pl[1]) - 1)]
				var mh: float = maxf((meshes[kind] as ArrayMesh).get_aabb().size.y, 0.1)
				var sc: float = rng.randf_range((pl[2] as Vector2).x, (pl[2] as Vector2).y) / mh
				add.call(kind, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), pos))
			placed += 1
		s += 6.0
	# Fallen blocks in the pit: along the toes of the benches and scattered on the floor, off the road.
	for k in range(420):
		var p3 := Vector2(rng.randf_range(-PIT_HX - 90.0, PIT_HX + 90.0), rng.randf_range(-PIT_HZ - 90.0, PIT_HZ + 90.0))
		var d: float = _pit_d(p3.x, p3.y)
		if d > 85.0 or _route_dist(p3) < ROAD_HALF + 3.5:
			continue
		var blocked := false
		for f in _footprints:
			if p3.distance_to(f[0]) < float(f[1]) + 2.0:
				blocked = true
				break
		if blocked or _slope_at(p3.x, p3.y) > 0.4:
			continue
		var pos3 := Vector3(p3.x, _ground_at(p3.x, p3.y), p3.y)
		var rk3: String = "pit_%d" % rng.randi_range(0, 3)
		add.call(rk3, _rock_xf(rng.randf_range(0.5, 2.4), rng.randf() * TAU, pos3, rocks[rk3]))
		placed += 1
	for key in cells.keys():
		var parts: PackedStringArray = String(key).split("|")
		var kind2: String = parts[0]
		var mesh: Mesh
		var range_end := 600.0
		var is_cactus := false
		if kind2.begins_with("sage"):
			mesh = sage[int(kind2.substr(5))]
			range_end = 280.0
		elif rocks.has(kind2):
			mesh = rocks[kind2]
			range_end = 550.0
		else:
			mesh = meshes[kind2]
			range_end = 700.0
			is_cactus = true
		var tf: Array = cells[key]
		var buf: PackedFloat32Array = PropKit.transform_buffer(tf)
		var variants: Array = [[mesh, 0.0, 150.0 if is_cactus else range_end, ""]]
		if is_cactus:
			variants.append([far_meshes[kind2], 140.0, range_end, "_far"])
		for vr in variants:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = vr[0]
			mm.instance_count = tf.size()
			mm.buffer = buf
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "%s_%s_%s%s" % [kind2.capitalize().replace(" ", ""), parts[1], parts[2], vr[3]]
			mmi.multimesh = mm
			mmi.visibility_range_begin = vr[1]
			mmi.visibility_range_end = vr[2]
			if vr[1] > 0.0 or kind2.begins_with("sage"):
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if rocks.has(kind2):
				mmi.set_meta(&"hull_collider", true)
				mmi.set_meta(&"min_collider_height", 0.15)
			elif kind2.begins_with("sage"):
				mmi.set_meta(&"min_collider_height", 0.35)
			root.add_child(mmi)
	var mat_i := 0
	for rk4 in rocks:
		_prop_meshes["boulder_" + rk4] = rocks[rk4]
	for v in range(sage.size()):
		_prop_meshes["sage_%d" % v] = sage[v]
	for kname in meshes:
		_prop_meshes["cactus_" + kname] = meshes[kname]
		_prop_meshes["cactus_far_" + kname] = far_meshes[kname]
	_save_baked_resource(rock_mat, "rock_material", PROP_PREFIX)
	_save_baked_resource(pit_mat, "pit_rock_material", PROP_PREFIX)
	print("  desert: %d plants and rocks in %d cells" % [placed, cells.size()])


## A rock `h` high at `pos` turned by `yaw`, its foot on the lowest ground under its footprint.
func _rock_xf(h: float, yaw: float, pos: Vector3, mesh: ArrayMesh) -> Transform3D:
	var size: Vector3 = mesh.get_aabb().size
	var sy: float = h / maxf(size.y, 0.05)
	var half: float = maxf(size.x, size.z) * 0.5 * sy * 0.85
	var lowest: float = _ground_at(pos.x, pos.z)
	for k in range(8):
		var a: float = TAU * float(k) / 8.0
		lowest = minf(lowest, _ground_at(pos.x + cos(a) * half, pos.z + sin(a) * half))
	return Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * sy), Vector3(pos.x, lowest - 0.1 * h, pos.z))


func _build_people(level: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Spectators"
	level.add_child(root)
	CrowdPlacer.build(root, _people, PEOPLE_SCALE, PEOPLE_SKIN, 3121, func(res: Resource, n: String) -> Resource: return _save_baked_resource(res, n, PROP_PREFIX))
	print("  spectators: %d" % _people.size())


func _report_seats() -> void:
	for r in _seat_report:
		var msg := "  %s stands on ground rising %.2fm under it (allowed %.2f)" % r
		if float(r[1]) > 2.0 * float(r[2]):
			push_error(msg)
		else:
			print(msg)


# ======================================================================================
#  The haboob: where it lies, its wall of dust, the wind, the siren, the tumbleweeds
# ======================================================================================

const STORM_CELL := 16.0
## The storm covers the escarpment from STORM_FROM north of its edge (thickening over the STORM_RAMP before that) to
## STORM_TO out over the valley, and the pit.
const STORM_FROM := -10.0
const STORM_RAMP := 120.0
const STORM_TO := 45.0
## The dust wall's curtains: offset from the edge (+ toward the valley), height, shade.
const DUST_CURTAINS := [[-115.0, 300.0, 0.0], [-55.0, 350.0, 1.0], [45.0, 400.0, 2.0]]
## Where the tumbleweeds cross: from s to s, how many.
const WEEDS_FROM := 1170.0
const WEEDS_TO := 1755.0
const WEEDS := 18


func _storm_cover(x: float, z: float) -> float:
	var ed: float = _edge_dist(x, z)
	var band: float = smoothstep(STORM_FROM - STORM_RAMP, STORM_FROM, ed) * (1.0 - smoothstep(STORM_TO, STORM_TO + 50.0, ed))
	var pit: float = 1.0 - smoothstep(70.0, 140.0, _pit_d(x, z))
	return maxf(band, pit)


func _build_storm(level: Node3D) -> void:
	var weather := Node3D.new()
	weather.name = "HaboobWeather"
	weather.set_script(load("res://HaboobWeather.gd"))
	var nx: int = int(ceil((FINE_X.y - FINE_X.x) / STORM_CELL)) + 2
	var nz: int = int(ceil((FINE_Z.y - FINE_Z.x) / STORM_CELL)) + 2
	var cover := PackedFloat32Array()
	var tops := PackedFloat32Array()
	for iz in range(nz):
		for ix in range(nx):
			var x: float = FINE_X.x + float(ix) * STORM_CELL
			var z: float = FINE_Z.x + float(iz) * STORM_CELL
			cover.append(_storm_cover(x, z))
			tops.append(_natural(x, z))
	weather.set("zone_origin", Vector2(FINE_X.x, FINE_Z.x))
	weather.set("zone_cell", STORM_CELL)
	weather.set("zone_size", Vector2i(nx, nz))
	weather.set("zone", cover)
	weather.set("top", tops)
	weather.set("ground_material", _ground_mat)
	weather.set("sun_path", NodePath("../SunLight"))
	weather.set("wind_audio_path", NodePath("../DesertWind"))
	var wind := AudioStreamPlayer.new()
	wind.name = "DesertWind"
	wind.stream = _save_baked_resource(FreightKit.wind(), "wind_loop") as AudioStream
	wind.volume_db = -24.0
	wind.bus = &"SFX"
	wind.autoplay = true
	level.add_child(wind)
	level.add_child(weather)
	# Where the shelf road runs through the thick of it, for the report.
	var thick := 0.0
	var prof := ""
	var s := 0.0
	while s < float(_route["len"]):
		var p: Vector3 = _spot(s, 0.0, 1.0)["pos"]
		var gx: int = clampi(int((p.x - FINE_X.x) / STORM_CELL), 0, nx - 1)
		var gz: int = clampi(int((p.z - FINE_Z.x) / STORM_CELL), 0, nz - 1)
		var c: float = cover[gz * nx + gx]
		var depth: float = tops[gz * nx + gx] - p.y
		var i: float = c * (1.0 - 0.9 * smoothstep(10.0, 72.0, depth))
		if i > 0.6:
			thick += 10.0
		if int(s) % 100 == 0:
			prof += " %d:%.2f" % [int(s), i]
		s += 10.0
	print("  haboob: thick (over 0.6) along %.0fm of the route;%s" % [thick, prof])
	weather.set("wall_materials", _build_dust_wall(level))
	_build_siren(level)
	_build_tumbleweeds(level)


## The dust wall: curtains along the escarpment's edge, offset from it, standing from under the ground to their height.
func _build_dust_wall(level: Node3D) -> Array[ShaderMaterial]:
	var mats: Array[ShaderMaterial] = []
	var root := Node3D.new()
	root.name = "DustWall"
	level.add_child(root)
	for ci in range(DUST_CURTAINS.size()):
		var cdef: Array = DUST_CURTAINS[ci]
		# Resample the edge every 25m and push it out along its normal.
		var line: Array = []
		var acc := 0.0
		for i in range(EDGE.size() - 1):
			var a := Vector2(EDGE[i][0], EDGE[i][1])
			var b := Vector2(EDGE[i + 1][0], EDGE[i + 1][1])
			var seg: float = a.distance_to(b)
			var n: int = maxi(int(seg / 25.0), 1)
			var nrm := Vector2(-(b - a).y, (b - a).x).normalized()
			for k in range(n):
				line.append(a.lerp(b, float(k) / float(n)) + nrm * float(cdef[0]))
		var verts := PackedVector3Array()
		var nrms := PackedVector3Array()
		var uvs := PackedVector2Array()
		var cols := PackedColorArray()
		var idx := PackedInt32Array()
		var total := 0.0
		for k in range(1, line.size()):
			total += (line[k] as Vector2).distance_to(line[k - 1])
		for k in range(line.size()):
			var q: Vector2 = line[k]
			if k > 0:
				acc += q.distance_to(line[k - 1])
			var foot: float = _base(q.x, q.y).x - 25.0
			var top_y: float = PLATEAU_Y + float(cdef[1])
			var fade: float = smoothstep(0.0, 500.0, acc) * smoothstep(0.0, 500.0, total - acc)
			verts.append(Vector3(q.x, foot, q.y))
			verts.append(Vector3(q.x, top_y, q.y))
			var along: Vector2 = (line[mini(k + 1, line.size() - 1)] as Vector2) - (line[maxi(k - 1, 0)] as Vector2)
			var cn := Vector3(-along.y, 0.0, along.x).normalized()
			nrms.append(cn)
			nrms.append(cn)
			uvs.append(Vector2(acc, 0.0))
			uvs.append(Vector2(acc, 1.0))
			cols.append(Color(1, 1, 1, fade))
			cols.append(Color(1, 1, 1, fade))
			if k > 0:
				var b0: int = (k - 1) * 2
				idx.append_array([b0, b0 + 2, b0 + 1, b0 + 1, b0 + 2, b0 + 3])
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = nrms
		arr[Mesh.ARRAY_TEX_UV] = uvs
		arr[Mesh.ARRAY_COLOR] = cols
		arr[Mesh.ARRAY_INDEX] = idx
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var m := ShaderMaterial.new()
		m.shader = load("res://mina_dust_wall.gdshader")
		m.set_shader_parameter("layer", float(cdef[2]))
		m.set_shader_parameter("opacity", 0.9 - 0.12 * float(cdef[2]))
		m.render_priority = -int(cdef[2])
		mesh.surface_set_material(0, m)
		mats.append(m)
		var mi := MeshInstance3D.new()
		mi.name = "Curtain_%d" % ci
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 400.0
		_prop_meshes["dust_curtain_%d" % ci] = mesh
		root.add_child(mi)
	return mats


## The mine's blast siren on a mast by the gate, wailing as the storm comes in.
func _build_siren(level: Node3D) -> void:
	var sp: Dictionary = _spot(GATE_S - 6.0, 17.0, 0.0)
	var pos: Vector3 = sp["pos"]
	pos.y = _ground_at(pos.x, pos.z)
	var pk: PropKit = MinaKit.new_kit(PROP_SCALE)
	var kit := {}
	pk.beam(kit, "steel", Vector3.ZERO, Vector3(0, 7.0, 0), 0.25, 0.25, Color(0.55, 0.55, 0.55))
	pk.tube(kit, "paint", Vector3(0, 7.0, 0), Vector3(0, 7.6, 0), 0.45, 0.45, 12, Color(0.85, 0.15, 0.1))
	for a in [0.0, PI * 0.5, PI, PI * 1.5]:
		var d := Vector3(cos(a), 0, sin(a))
		pk.tube(kit, "paint", Vector3(0, 7.3, 0) + d * 0.4, Vector3(0, 7.3, 0) + d * 1.2, 0.18, 0.42, 12, Color(0.85, 0.15, 0.1))
	var mi := MeshInstance3D.new()
	mi.name = "SirenMast"
	mi.mesh = pk.commit(kit)
	mi.position = pos
	_prop_meshes["siren_mast"] = mi.mesh
	level.add_child(mi)
	var snd := AudioStreamPlayer3D.new()
	snd.name = "BlastSiren"
	snd.stream = _save_baked_resource(_siren_stream(), "siren", PROP_PREFIX) as AudioStream
	snd.position = pos + Vector3.UP * 7.3 * PROP_SCALE
	snd.unit_size = 55.0
	snd.max_distance = 900.0
	snd.volume_db = -4.0
	snd.bus = &"SFX"
	snd.autoplay = true
	level.add_child(snd)


## A motor siren's wail: rising over two seconds, holding, falling away, a pause; rich in harmonics, 8s, looped.
func _siren_stream() -> AudioStreamWAV:
	var rate := 22050
	var secs := 8.0
	var n: int = int(rate * secs)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in range(n):
		var t: float = float(i) / float(rate)
		var u: float = fmod(t, secs)
		var env: float = smoothstep(0.0, 2.2, u) * (1.0 - smoothstep(4.6, 7.6, u))
		var f: float = 220.0 + 520.0 * env
		phase += TAU * f / float(rate)
		var v: float = sin(phase) * 0.55 + sin(phase * 2.0) * 0.25 + sin(phase * 3.0) * 0.12 + sin(phase * 5.0) * 0.05
		v = tanh(v * 1.6) * 0.6 * (0.15 + 0.85 * env)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w


func _build_tumbleweeds(level: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1717
	var mesh: ArrayMesh = _mesh("tumbleweed", PROP_SCALE, func(pk, kit): MinaKit.tumbleweed(pk, kit, 1))
	var starts := PackedVector3Array()
	var ends := PackedVector3Array()
	var heights := PackedFloat32Array()
	var speeds := PackedFloat32Array()
	var periods := PackedFloat32Array()
	var phases := PackedFloat32Array()
	for i in range(WEEDS):
		var s: float = lerpf(WEEDS_FROM, WEEDS_TO, (float(i) + rng.randf()) / float(WEEDS))
		var a: Vector3 = _spot(s, 21.0, 0.0)["pos"]
		var b: Vector3 = _spot(s - 24.0, -10.5, 0.0)["pos"]
		starts.append(a)
		ends.append(b)
		for k in range(16):
			var f: float = float(k) / 15.0
			var q: Vector3 = a.lerp(b, f)
			var h: float = _ground_at(q.x, q.z)
			# Over the berm where the path crosses it.
			var lat: float = lerpf(21.0, -10.5, f)
			var bu: float = absf(lat - BERM_LAT)
			if s > float(BERMS[0][0]) and s < float(BERMS[0][1]) and bu < 2.3:
				h += 1.45 * (1.0 - bu / 2.3)
			heights.append(h)
		speeds.append(rng.randf_range(8.0, 12.5))
		periods.append(rng.randf_range(9.0, 19.0))
		phases.append(rng.randf())
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = WEEDS
	var hidden: Array = []
	for i in range(WEEDS):
		hidden.append(Transform3D(Basis.from_scale(Vector3.ONE * 0.001), Vector3(0, -1000, 0)))
	mm.buffer = PropKit.transform_buffer(hidden)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Tumbleweeds"
	mmi.multimesh = mm
	mmi.custom_aabb = AABB(Vector3(-1200, -100, -200), Vector3(1100, 250, 700))
	mmi.set_script(load("res://Tumbleweeds.gd"))
	mmi.set("starts", starts)
	mmi.set("ends", ends)
	mmi.set("heights", heights)
	mmi.set("speeds", speeds)
	mmi.set("periods", periods)
	mmi.set("phases", phases)
	level.add_child(mmi)


# ======================================================================================
#  Sky and light
# ======================================================================================

## Dawn haze: warm, dusty.
const HAZE := Color(0.86, 0.72, 0.60)

func _build_environment(level_scene: Node3D) -> void:
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://sky_tropical_cumulus.gdshader")
	sky_mat.set_shader_parameter("sky_top", Color(0.22, 0.36, 0.66))
	sky_mat.set_shader_parameter("sky_horizon", Color(0.96, 0.74, 0.56))
	sky_mat.set_shader_parameter("ground_horizon", HAZE)
	sky_mat.set_shader_parameter("ground_bottom", Color(0.46, 0.36, 0.30))
	sky_mat.set_shader_parameter("sky_curve", 0.35)
	sky_mat.set_shader_parameter("horizon_haze", HAZE)
	sky_mat.set_shader_parameter("haze_strength", 0.7)
	sky_mat.set_shader_parameter("haze_height", 0.12)
	sky_mat.set_shader_parameter("sun_tint", Color(1.0, 0.82, 0.58))
	sky_mat.set_shader_parameter("sun_disc_degrees", 1.3)
	sky_mat.set_shader_parameter("sun_glow", 0.75)
	sky_mat.set_shader_parameter("sun_horizon_tint", Color(1.0, 0.62, 0.36))
	sky_mat.set_shader_parameter("sun_horizon_glow", 0.55)
	sky_mat.set_shader_parameter("cloud_lit", Color(1.0, 0.80, 0.62))
	sky_mat.set_shader_parameter("cloud_shade", Color(0.52, 0.46, 0.58))
	sky_mat.set_shader_parameter("cloud_coverage", 0.26)
	sky_mat.set_shader_parameter("cloud_opacity", 0.9)
	sky_mat.set_shader_parameter("cloud_scale", 1.3)
	sky_mat.set_shader_parameter("cloud_seed", 17.3)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.5
	env.ambient_light_color = Color(0.92, 0.84, 0.78)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_bloom = 0.06
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = HAZE
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.25
	env.fog_density = 1.0
	env.fog_depth_begin = 300.0
	env.fog_depth_end = 4800.0
	env.fog_depth_curve = 1.6
	env.fog_sky_affect = 0.06
	env.fog_aerial_perspective = 0.3
	env_node.environment = env
	level_scene.add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	# Dawn: low in the east-south-east, long shadows across the plateau, the pit's west wall lit and its east wall in
	# shade.
	sun.rotation_degrees = Vector3(-17.0, 108.0, 0.0)
	sun.light_color = Color(1.0, 0.84, 0.66)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 320.0
	sun.directional_shadow_split_1 = 0.08
	sun.directional_shadow_split_2 = 0.22
	sun.directional_shadow_split_3 = 0.5
	level_scene.add_child(sun)


# ======================================================================================
#  Build
# ======================================================================================

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


func _make_ground_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://mina_ground.gdshader")
	m.set_shader_parameter("sand_tex", load("res://materials/sand.png"))
	m.set_shader_parameter("dirt_tex", load("res://materials/dirt.png"))
	m.set_shader_parameter("rock_tex", load("res://materials/dark_rock.png"))
	m.set_shader_parameter("rock_normal", _rock_normal_texture())
	m.set_shader_parameter("gravel_tex", load("res://materials/dark_canyon_rock.png"))
	m.set_shader_parameter("gravel_normal", load("res://materials/dark_canyon_rock_normal.png"))
	m.set_shader_parameter("asphalt_tex", load("res://materials/asphalt.png"))
	m.set_shader_parameter("road_half_width", ROAD_HALF)
	m.set_shader_parameter("horizon_color", HAZE)
	m.set_shader_parameter("horizon_center", CENTRE)
	m.set_shader_parameter("floor_y", FLOOR_Y)
	m.set_shader_parameter("rim_y", PLATEAU_Y)
	m.set_shader_parameter("sump_y", SUMP_WATER_Y)
	m.set_shader_parameter("sump", Vector3(SUMP.x, SUMP.y, SUMP_R + 14.0))
	m.set_shader_parameter("face_slope", 0.0)
	return _save_baked_resource(m, "ground_material") as ShaderMaterial


func _ready() -> void:
	print("=== Mina del Viento (Sierra del Viento) Level Generation ===")
	var t_start: int = Time.get_ticks_msec()
	var level_scene := Node3D.new()
	level_scene.name = LEVEL_NAME
	level_scene.set_script(load("res://levels/Level.gd"))
	level_scene.set("is_point_to_point", true)
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
	_solve_route()
	_build_profile()
	_add_samples()
	var track_path := Path3D.new()
	track_path.name = "TrackPath"
	track_path.curve = _build_track_curve()
	level_scene.add_child(track_path)
	# The wash's crest throws the carts: its lip for scratch/nyota_jump_test.
	var lip_s: float = WASH_S + 22.0
	var lip: Vector3 = _spot(lip_s, 0.0, 0.0)["pos"]
	var rise: float = _road_y(lip_s) - _road_y(lip_s - 2.0)
	var lip_fwd: Vector3 = _spot(lip_s, 0.0, 0.0)["fwd"]
	track_path.set_meta(&"jump_lips", [{"name": "Wash", "lip": lip, "dir": (lip_fwd * 2.0 + Vector3(0, rise, 0)).normalized()}])
	_plan_pads()
	_build_heights()
	print("  heights built (%.1fs)" % ((Time.get_ticks_msec() - t_start) / 1000.0))
	_ground_mat = _make_ground_material()
	var terrain_root := Node3D.new()
	terrain_root.name = "MinaTerrain"
	level_scene.add_child(terrain_root)
	_build_terrain(terrain_root, _ground_mat)
	print("  terrain built (%.1fs)" % ((Time.get_ticks_msec() - t_start) / 1000.0))
	_build_berms(level_scene)
	_build_fiesta(level_scene)
	_build_array(level_scene)
	_build_gate(level_scene)
	_build_pit(level_scene)
	_build_conveyors(level_scene)
	_build_valley(level_scene)
	_build_vehicles(level_scene)
	_build_flora(level_scene)
	_build_people(level_scene)
	_build_storm(level_scene)
	_report_seats()
	print("  dressing built (%.1fs)" % ((Time.get_ticks_msec() - t_start) / 1000.0))

	_build_environment(level_scene)
	_place_gameplay(level_scene)

	level_scene.set("track_path", track_path)
	level_scene._setup_checkpoints()
	var chunked: int = MeshChunker.chunk_scene(level_scene, "res://generated/" + RES_PREFIX, "res://generated/mina_chunks", MESH_CHUNK_CELL)
	print("  chunked %d large meshes" % chunked)
	_save_props()
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
