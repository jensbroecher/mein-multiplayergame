# regenerate_msitu_falls.gd
#
# Builds levels/MsituFallsLevel.tscn - the third stage of the Matumaini GP: a red laterite road
# through the equatorial rainforest of the East African highlands, round a waterfall that drops
# out of the forest into a gorge.
#
# The lap: the start/finish straight runs south out of the gorge to the Matope, a hairpin through
# the swamp where the road is mud. The road climbs the west ridge under the Mugumo, a strangler
# fig whose roots arch over it, onto the plateau, and crosses the river on the Daraja, a rope
# bridge that sags over the water a few metres upstream of the brink. It winds through the
# canopy and drops down the Nyoka, three switchback hairpins on the slope east of the falls,
# runs behind the falls between the cliff and the falling water, and heads back down the gorge.
# Every so often a tropical downpour (Mvua, JungleRain.gd) sweeps over: the light goes, the rain
# streams down and the whole road turns slick.
#
# Things worth knowing before editing this file:
#
# 1. The lap is planned as turtle moves (PLAN: straights and circular arcs, as on Nyota Stadium),
#    so the hairpins are exactly round. Two straights ("SV") have no fixed length: _build_plan()
#    solves them so the lap closes. Heights come from PROFILE, stations along the plan joined by
#    a monotone cubic (_profile_y), plus the bridge's sag (_bridge_sag).
#
# 2. There is no road mesh except the bridge deck: the heightfield is graded flat under the road
#    and jungle_ground.gdshader paints the laterite from the signed distance across it, baked in
#    the vertex colour (as on Mara Crossing). The ground's collision is split in three: JungleRoad
#    and MatopeMudRoad (PlayerCart counts "road" as track; the mud carries the ice_grip meta, so it
#    is slippery) and ForestFloor (off-road).
#
# 3. The heightfield is built in layers: a field that follows the road's own heights near it and
#    the landscape (plateau, gorge, lowland, far hills) away from it -> the cliff round the falls
#    -> clamp between every road's cut and fill bounds (the cliff relaxes the cut bound) -> carve
#    the rivers, the plunge pool and the swamp -> put the road strip back. The bridge span is left
#    out of the grading, so the river's slot runs on under the deck.
#
# 4. The falls pour off a rock slab that overhangs the road behind them (FALLS_*). _verify_falls()
#    checks the water clears the road and lands in the pool.
#
# The menu tile (images/menu/tile_msitu_falls.jpg) is a render of this level taken windowed with
# scratch/msitu_shots.gd; the generator runs headless and cannot render.
extends Node

const LEVEL_NAME := "MsituFallsLevel"
const LEVEL_PATH := "res://levels/MsituFallsLevel.tscn"
const RES_PREFIX := "msitu_"
const MeshChunker = preload("res://MeshChunker.gd")
const RiverWaterScript = preload("res://RiverWater.gd")

const MESH_CHUNK_CELL := 80.0

## Painted laterite half width (the shader's road_half_width).
const ROAD_HALF := 7.0
## Ground within this of a road centreline goes into a road collision body.
const ROAD_COLLIDE := 7.8
## Half width of the strip graded flat to road height.
const ROAD_FLAT := 8.6
## Embankments beside the flat strip: rise per metre of a cutting, drop per metre of a fill.
const CUT_SLOPE := 0.62
const FILL_SLOPE := 0.66
const GRADE_REACH := 70.0
## Road samples are bucketed in CELL x CELL squares for the lookups.
const CELL := 40.0
const SAMPLE_STEP := 2.0

## The switchbacks: hairpin radius, leg length, and how far each leg fans off the one before
## (degrees), so the open ends of a pair stand further apart than the hairpin end.
const SW_R := 18.0
const SW_LEG := 110.0
const SW_TILT := 5.0

## The lap as turtle moves from PLAN_START heading PLAN_HEADING (x east, z south): ["S", length],
## ["SV"] (a straight whose length _build_plan solves), or ["R"/"L", radius, degrees].
const PLAN_START := Vector2(-60.0, -360.0)
const PLAN_HEADING := PI * 0.5
const PLAN := [
	["S", 90.0],                          # 0  the gorge road, south from the falls
	["R", 220.0, 14.0],                   # 1
	["S", 40.0],                          # 2
	["L", 220.0, 14.0],                   # 3
	["SV"],                               # 4  start/finish straight
	["R", 22.0, 180.0],                   # 5  the Matope hairpin
	["S", 40.0],                          # 6
	["L", 70.0, 40.0],                    # 7
	["S", 70.0],                          # 8
	["R", 70.0, 40.0],                    # 9
	["S", 60.0],                          # 10 under the Mugumo
	["L", 120.0, 25.0],                   # 11
	["S", 60.0],                          # 12
	["R", 120.0, 25.0],                   # 13
	["S", 80.0],                          # 14
	["R", 40.0, 90.0],                    # 15 onto the plateau
	["SV"],                               # 16 the bridge road, east over the Daraja
	["R", 90.0, 22.0],                    # 17
	["S", 40.0],                          # 18 the canopy
	["L", 90.0, 22.0],                    # 19
	["S", 30.0],                          # 20
	["R", SW_R, 180.0 - SW_TILT],         # 21 Nyoka 1
	["S", SW_LEG],                        # 22
	["L", SW_R, 180.0 - 2.0 * SW_TILT],   # 23 Nyoka 2
	["S", SW_LEG],                        # 24
	["R", SW_R, 180.0 - 2.0 * SW_TILT],   # 25 Nyoka 3
	["S", SW_LEG],                        # 26
	["R", 70.0, 90.0 + SW_TILT],          # 27
	["S", 30.0],                          # 28 the east bank
	["L", 30.0, 90.0],                    # 29
	["S", 60.0],                          # 30 behind the falls
	["L", 30.0, 90.0],                    # 31
]
const SEG_GORGE := 0
const SEG_START := 4
const SEG_MATOPE := 5
const SEG_MUGUMO := 10
const SEG_BRIDGE := 16
const SEG_NYOKA := [21, 23, 25]
const SEG_FALLS := 30

## Height stations: [segment, fraction along it, height]. The bridge's ends are added in code.
const PROFILE := [
	[0, 0.0, 5.4], [2, 0.5, 4.8], [4, 0.15, 4.3], [4, 1.0, 3.0], [5, 1.0, 3.0],
	[7, 1.0, 4.6], [8, 1.0, 8.6], [10, 0.0, 11.6], [10, 1.0, 15.0], [12, 0.5, 21.4],
	[14, 0.0, 27.0], [14, 1.0, 32.6], [15, 1.0, 35.6], [16, 1.0, 36.2],
	[20, 1.0, 37.0], [21, 1.0, 37.0], [22, 1.0, 29.0], [23, 1.0, 28.6], [24, 1.0, 20.6],
	[25, 1.0, 20.2], [26, 1.0, 12.4], [27, 1.0, 7.6], [28, 1.0, 6.1], [29, 1.0, 5.6], [30, 1.0, 5.6],
]

## The Daraja: a rope bridge over the river's slot just upstream of the falls, crossing x = 0.
const BRIDGE_Y := 36.0
const BRIDGE_HALF_SPAN := 20.0
const BRIDGE_SAG := 1.4
## Deck half width (the road narrows a little onto it).
const BRIDGE_HALF_W := 6.6

## The falls. The river leaves an overhanging slab FALLS_OVERHANG metres out from the cliff
## face, which stands FALLS_FACE_OFF behind the road's centreline; the water arcs over the outer
## half of the road and lands in the plunge pool.
const FALLS_X := 0.0
const FALLS_HALF_W := 16.0
const FALLS_FACE_OFF := 11.0
const FALLS_OVERHANG := 7.0
const FALLS_LIP_Y := 31.0
const FALLS_V0 := 7.3
const POOL_OFF := 48.0
const POOL_R := 25.0
const POOL_Y := 1.5
## Top of the cliff round the falls (the plateau's edge).
const CLIFF_TOP := 36.5

## The river on the plateau, north to the lip: [x, z, half width]. Its surface falls gently to
## FALLS_LIP_Y at the lip; the last point is the lip (the slab's edge, checked in _ready).
const UPPER_RIVER := [
	[-30.0, -1500.0, 20.0], [12.0, -1100.0, 17.0], [-14.0, -800.0, 15.0], [8.0, -600.0, 13.5],
	[0.0, -470.0, 14.0], [0.0, -394.0, 16.0],
]
const UPPER_GRADE := 0.004
## Below the falls: from the pool south through the valley to the swamp: [x, z, half width, y].
const LOWER_RIVER := [
	[0.0, -330.0, 11.0, POOL_Y], [10.0, -260.0, 10.0, 1.35], [-4.0, -170.0, 10.5, 1.2],
	[8.0, -70.0, 11.0, 1.05], [24.0, 30.0, 12.0, 0.9], [46.0, 120.0, 14.0, 0.75],
	[70.0, 200.0, 16.0, 0.65],
]
## The swamp south of the Matope: (x, z, radius) pools at SWAMP_Y.
const SWAMP_Y := 0.65
const SWAMP_POOLS := [
	Vector3(80.0, 230.0, 48.0), Vector3(30.0, 250.0, 34.0), Vector3(-30.0, 205.0, 26.0),
	Vector3(-145.0, 175.0, 18.0), Vector3(-75.0, 200.0, 20.0), Vector3(130.0, 260.0, 40.0),
]
## The Matope: the stretch of the lap (s, before and after the hairpin) that is mud.
const MATOPE_BEFORE := 70.0
const MATOPE_AFTER := 60.0
const MUD_GRIP := 0.5

const LOWLAND_Y := 2.6
const PLATEAU_Y := 37.0

## Terrain grid: fine around the lap, cells growing outward to the horizon.
const FINE_X := Vector2(-330.0, 330.0)
const FINE_Z := Vector2(-560.0, 220.0)
const FINE_STEP := 2.5
const OUTER_X := Vector2(-3200.0, 3200.0)
const OUTER_Z := Vector2(-3600.0, 3000.0)
const COARSE_GROWTH := 1.18
const COARSE_MAX := 80.0
## The road field: a Gaussian of SIGMA metres round every road sample, against the landscape's
## weight W0. Sampled on a coarse grid of RF_STEP and interpolated.
const RF_SIGMA := 42.0
const RF_W0 := 1.0
const RF_STEP := 6.0

const FINISH_OFF := 22.0

var _segs: Array = []
var _lap_len := 0.0
var _prof_s := PackedFloat32Array()
var _prof_y := PackedFloat32Array()
var _prof_m := PackedFloat32Array()
var _bridge_s0 := 0.0
var _bridge_s1 := 0.0
var _mud_s0 := 0.0
var _mud_s1 := 0.0
var main_curve: Curve3D

var _base_noise := FastNoiseLite.new()
var _detail_noise := FastNoiseLite.new()
var _far_noise := FastNoiseLite.new()

# Road samples every SAMPLE_STEP metres along the lap.
var _rs_pos := PackedVector3Array()
var _rs_right := PackedVector3Array()
var _rs_s := PackedFloat32Array()
## 1 over the bridge span: not graded, not ground road.
var _rs_gap := PackedByteArray()
var _rs_cells := {}

# The road field on its coarse grid: weighted height sum and weight sum.
var _rf_x0 := 0.0
var _rf_z0 := 0.0
var _rf_nx := 0
var _rf_nz := 0
var _rf_h := PackedFloat32Array()

var _grid_x := PackedFloat32Array()
var _grid_z := PackedFloat32Array()
var _heights := PackedFloat32Array()
var _road_d := PackedFloat32Array()
var _road_mud := PackedByteArray()
var _ground_mat: ShaderMaterial


# ======================================================================================
#  Plan
# ======================================================================================

func _right_of(th: float) -> Vector2:
	return Vector2(-sin(th), cos(th))


func _dir_of(th: float) -> Vector2:
	return Vector2(cos(th), sin(th))


## Walks PLAN once with the "SV" straights at `sv` lengths; returns the segments and where the
## walk ends.
func _walk(sv: Array) -> Dictionary:
	var p := PLAN_START
	var th := PLAN_HEADING
	var s := 0.0
	var k := 0
	var segs: Array = []
	for m in PLAN:
		var seg := {"kind": "S", "s0": s, "p0": p, "th0": th}
		if m[0] == "S" or m[0] == "SV":
			var length: float = float(m[1]) if m[0] == "S" else float(sv[k])
			if m[0] == "SV":
				k += 1
			seg["len"] = length
			p += _dir_of(th) * length
		else:
			var r: float = m[1]
			var sign: float = 1.0 if m[0] == "R" else -1.0
			var ang: float = deg_to_rad(float(m[2]))
			seg["kind"] = "A"
			seg["len"] = r * ang
			seg["r"] = r
			seg["sign"] = sign
			var c: Vector2 = p + _right_of(th) * r * sign
			th += sign * ang
			p = c - _right_of(th) * r * sign
		s += float(seg["len"])
		segs.append(seg)
	return {"segs": segs, "end": p, "th": th, "len": s}


## Solves the two "SV" straights so the lap closes (the end point moves linearly with their
## lengths, since no heading depends on them), then walks the plan for real.
func _build_plan() -> void:
	var base: Dictionary = _walk([0.0, 0.0])
	var c1: Vector2 = (_walk([1.0, 0.0])["end"] as Vector2) - (base["end"] as Vector2)
	var c2: Vector2 = (_walk([0.0, 1.0])["end"] as Vector2) - (base["end"] as Vector2)
	var rhs: Vector2 = PLAN_START - (base["end"] as Vector2)
	var det: float = c1.x * c2.y - c1.y * c2.x
	var a: float = (rhs.x * c2.y - rhs.y * c2.x) / det
	var b: float = (c1.x * rhs.y - c1.y * rhs.x) / det
	if a < 40.0 or b < 40.0:
		push_error("The plan only closes with straights of %.0fm and %.0fm" % [a, b])
	var w: Dictionary = _walk([a, b])
	_segs = w["segs"]
	_lap_len = w["len"]
	var gap: float = (w["end"] as Vector2).distance_to(PLAN_START)
	var turn: float = absf(wrapf(float(w["th"]) - PLAN_HEADING, -PI, PI))
	if gap > 0.01 or turn > 0.001:
		push_error("The plan does not close: ends %.2fm and %.2f deg from its start" % [gap, rad_to_deg(turn)])
	print("  lap %.0fm in %d segments (start straight %.0fm, bridge road %.0fm)" % [_lap_len, _segs.size(), a, b])


func _seg_index(s: float) -> int:
	s = fposmod(s, _lap_len)
	for i in range(_segs.size() - 1, -1, -1):
		if s >= float(_segs[i]["s0"]):
			return i
	return 0


## Position, heading and signed curvature (+ turning right) on the plan at arc length s.
func _plan_at(s: float) -> Dictionary:
	s = fposmod(s, _lap_len)
	var seg: Dictionary = _segs[_seg_index(s)]
	var d: float = s - float(seg["s0"])
	var p0: Vector2 = seg["p0"]
	var th0: float = seg["th0"]
	if seg["kind"] == "S":
		return {"p": p0 + _dir_of(th0) * d, "th": th0, "k": 0.0}
	var r: float = seg["r"]
	var sign: float = seg["sign"]
	var c: Vector2 = p0 + _right_of(th0) * r * sign
	var th: float = th0 + sign * d / r
	return {"p": c - _right_of(th) * r * sign, "th": th, "k": sign / r}


func _seg_s(seg: int, frac: float) -> float:
	return float(_segs[seg]["s0"]) + float(_segs[seg]["len"]) * frac


# ======================================================================================
#  Height profile
# ======================================================================================

## The stations as (s, y), the bridge's two ends added, wrapped round the lap, and the slopes
## of the monotone cubic (Fritsch-Carlson) through them.
func _build_profile() -> void:
	var seg: Dictionary = _segs[SEG_BRIDGE]
	var p0: Vector2 = seg["p0"]
	var dir: Vector2 = _dir_of(float(seg["th0"]))
	if absf(dir.x - 1.0) > 0.001:
		push_error("The bridge road must run due east, not %s" % dir)
	_bridge_s0 = float(seg["s0"]) + (FALLS_X - BRIDGE_HALF_SPAN - p0.x)
	_bridge_s1 = float(seg["s0"]) + (FALLS_X + BRIDGE_HALF_SPAN - p0.x)
	var hp_s0: float = float(_segs[SEG_MATOPE]["s0"])
	_mud_s0 = hp_s0 - MATOPE_BEFORE
	_mud_s1 = hp_s0 + float(_segs[SEG_MATOPE]["len"]) + MATOPE_AFTER
	var st: Array = []
	for p in PROFILE:
		st.append(Vector2(_seg_s(int(p[0]), float(p[1])), float(p[2])))
	st.append(Vector2(_bridge_s0 - 25.0, BRIDGE_Y))
	st.append(Vector2(_bridge_s0, BRIDGE_Y))
	st.append(Vector2(_bridge_s1, BRIDGE_Y))
	st.append(Vector2(_bridge_s1 + 25.0, BRIDGE_Y + 0.05))
	st.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var first: Vector2 = st[0]
	var last: Vector2 = st[st.size() - 1]
	st.insert(0, Vector2(last.x - _lap_len, last.y))
	st.append(Vector2(first.x + _lap_len, first.y))
	_prof_s = PackedFloat32Array()
	_prof_y = PackedFloat32Array()
	for v in st:
		_prof_s.append(v.x)
		_prof_y.append(v.y)
	var n: int = _prof_s.size()
	var d := PackedFloat32Array()
	for i in range(n - 1):
		var h: float = _prof_s[i + 1] - _prof_s[i]
		if h < 0.5:
			push_error("Profile stations %.0f and %.0f are too close" % [_prof_s[i], _prof_s[i + 1]])
		d.append((_prof_y[i + 1] - _prof_y[i]) / maxf(h, 0.001))
	_prof_m = PackedFloat32Array()
	_prof_m.resize(n)
	_prof_m[0] = d[0]
	_prof_m[n - 1] = d[n - 2]
	for i in range(1, n - 1):
		if d[i - 1] * d[i] <= 0.0:
			_prof_m[i] = 0.0
		else:
			var h0: float = _prof_s[i] - _prof_s[i - 1]
			var h1: float = _prof_s[i + 1] - _prof_s[i]
			var w1: float = 2.0 * h1 + h0
			var w2: float = h1 + 2.0 * h0
			_prof_m[i] = (w1 + w2) / (w1 / d[i - 1] + w2 / d[i])


## Height of the road centreline at arc length s, the bridge's sag included.
func _road_y(s: float) -> float:
	s = fposmod(s, _lap_len)
	var lo := 0
	var hi: int = _prof_s.size() - 2
	while lo < hi:
		var mid: int = (lo + hi + 1) >> 1
		if _prof_s[mid] <= s:
			lo = mid
		else:
			hi = mid - 1
	var h: float = _prof_s[lo + 1] - _prof_s[lo]
	var t: float = clampf((s - _prof_s[lo]) / h, 0.0, 1.0)
	var t2: float = t * t
	var t3: float = t2 * t
	var y: float = (2.0 * t3 - 3.0 * t2 + 1.0) * _prof_y[lo] + (t3 - 2.0 * t2 + t) * h * _prof_m[lo] \
			+ (-2.0 * t3 + 3.0 * t2) * _prof_y[lo + 1] + (t3 - t2) * h * _prof_m[lo + 1]
	return y - _bridge_sag(s)


## The deck hangs lowest in the middle of the span, level where it meets the abutments.
func _bridge_sag(s: float) -> float:
	if s <= _bridge_s0 or s >= _bridge_s1:
		return 0.0
	var u: float = (s - _bridge_s0) / (_bridge_s1 - _bridge_s0)
	var k: float = sin(PI * u)
	return BRIDGE_SAG * k * k


func _on_bridge(s: float) -> bool:
	s = fposmod(s, _lap_len)
	return s > _bridge_s0 and s < _bridge_s1


func _in_mud(s: float) -> bool:
	s = fposmod(s, _lap_len)
	return s > _mud_s0 and s < _mud_s1


# ======================================================================================
#  Track path (for the AI, checkpoints and placement)
# ======================================================================================

func _build_main_curve() -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = 0.5
	var n: int = int(round(_lap_len / 2.0))
	var step: float = _lap_len / float(n)
	var pts: Array = []
	for i in range(n):
		var s: float = float(i) * step
		var p2: Vector2 = _plan_at(s)["p"]
		pts.append(Vector3(p2.x, _road_y(s), p2.y))
	for i in range(n + 1):
		var k: int = i % n
		var a: Vector3 = pts[(k - 1 + n) % n]
		var c: Vector3 = pts[(k + 1) % n]
		var hnd: Vector3 = (c - a) / 6.0
		curve.add_point(pts[k], -hnd, hnd)
	return curve


## Ground spot on the lap: surface position `lat` metres right of the centreline, and yaw facing
## the direction of travel.
func _spot(s: float, lat: float, lift: float) -> Dictionary:
	var pa: Dictionary = _plan_at(s)
	var p2: Vector2 = pa["p"]
	var r2: Vector2 = _right_of(float(pa["th"]))
	var f2: Vector2 = _dir_of(float(pa["th"]))
	var pos := Vector3(p2.x + r2.x * lat, _road_y(s) + lift, p2.y + r2.y * lat)
	var fwd := Vector3(f2.x, 0.0, f2.y)
	return {"pos": pos, "yaw": rad_to_deg(atan2(-fwd.x, -fwd.z)), "fwd": fwd, "right": Vector3(r2.x, 0.0, r2.y)}


# ======================================================================================
#  Self-checks
# ======================================================================================

## Parts of the lap more than 120m apart along it must stand clear of each other, unless one
## passes well over the other (the bridge road over the falls road, with the cliff between).
func _verify_layout() -> void:
	var worst := INF
	var worst_s := Vector2.ZERO
	var s := 0.0
	while s < _lap_len:
		var a: Vector2 = _plan_at(s)["p"]
		var ya: float = _road_y(s)
		var s2 := 0.0
		while s2 < _lap_len:
			var ds: float = absf(s2 - s)
			ds = minf(ds, _lap_len - ds)
			if ds > 120.0:
				var b: Vector2 = _plan_at(s2)["p"]
				var d: float = a.distance_to(b)
				var dy: float = absf(_road_y(s2) - ya)
				# Two roads may run this close only when the slope between them is gentle enough
				# to grade, or one is a cliff's height above the other.
				var need: float = 2.0 * ROAD_FLAT + dy * 1.2 if dy < 20.0 else 2.0 * ROAD_FLAT + 8.0
				if d - need < worst:
					worst = d - need
					worst_s = Vector2(s, s2)
			s2 += 4.0
		s += 4.0
	print("  layout: tightest margin between two parts of the lap %.1fm (s=%.0f and %.0f)" % [worst, worst_s.x, worst_s.y])
	if worst < 0.0:
		push_error("Two parts of the lap pass too close: s=%.0f and s=%.0f" % [worst_s.x, worst_s.y])


## Steepest grade along the road, and road samples the ground does not match (the bridge span is
## left out).
func _verify_road_ground() -> void:
	var worst_grade := 0.0
	var worst_grade_at := 0.0
	var worst_cross := 0.0
	var worst_cross_at := Vector3.ZERO
	var off_ground := 0
	var s := 0.0
	while s < _lap_len:
		if not _on_bridge(s - 3.0) and not _on_bridge(s) and not _on_bridge(s + 4.0):
			var sp: Dictionary = _spot(s, 0.0, 0.0)
			var p: Vector3 = sp["pos"]
			var g0: float = _ground_at(p.x, p.z)
			var grade: float = absf(_road_y(s + 4.0) - _road_y(s)) / 4.0
			if grade > worst_grade:
				worst_grade = grade
				worst_grade_at = s
			var r: Vector3 = sp["right"]
			var cross: float = absf(_ground_at(p.x + r.x * 6.0, p.z + r.z * 6.0) - _ground_at(p.x - r.x * 6.0, p.z - r.z * 6.0)) / 12.0
			if cross > worst_cross:
				worst_cross = cross
				worst_cross_at = p
			if absf(g0 - p.y) > 0.3:
				off_ground += 1
				if off_ground <= 6:
					push_error("Ground at s=%.0f (%.0f, %.0f) is %.2fm off the road" % [s, p.x, p.z, g0 - p.y])
		s += 2.0
	print("  road: steepest grade %.1f%% at s=%.0f, steepest cross slope %.1f%% at (%.0f, %.0f), %d samples off the ground" % [
		worst_grade * 100.0, worst_grade_at, worst_cross * 100.0, worst_cross_at.x, worst_cross_at.z, off_ground])
	if worst_grade > 0.14 or worst_cross > 0.08:
		push_error("Road ground too steep (grade %.0f%%, cross %.0f%%)" % [worst_grade * 100.0, worst_cross * 100.0])


func _verify_min_radius() -> void:
	var worst := INF
	var worst_s := 0.0
	for seg in _segs:
		if seg["kind"] == "A" and float(seg["r"]) < worst:
			worst = seg["r"]
			worst_s = seg["s0"]
	print("  tightest bend R=%.0fm at s=%.0f" % [worst, worst_s])


# ======================================================================================
#  Landscape
# ======================================================================================

func _init_noise() -> void:
	_base_noise.seed = 6021
	_base_noise.frequency = 0.004
	_base_noise.fractal_octaves = 3
	_detail_noise.seed = 1187
	_detail_noise.frequency = 0.035
	_detail_noise.fractal_octaves = 2
	_far_noise.seed = 404
	_far_noise.frequency = 0.0012
	_far_noise.fractal_octaves = 4


func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Nearest point of the river above the falls: distance, half width and water height there.
func _upper_river_at(x: float, z: float) -> Vector3:
	var q := Vector2(x, z)
	var best := Vector3(1e9, 0.0, 0.0)
	for i in range(UPPER_RIVER.size() - 1):
		var a := Vector2(UPPER_RIVER[i][0], UPPER_RIVER[i][1])
		var b := Vector2(UPPER_RIVER[i + 1][0], UPPER_RIVER[i + 1][1])
		var ab: Vector2 = b - a
		var t: float = clampf((q - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d: float = q.distance_to(a + ab * t)
		if d < best.x:
			var hw: float = lerpf(float(UPPER_RIVER[i][2]), float(UPPER_RIVER[i + 1][2]), t)
			var pz: float = lerpf(a.y, b.y, t)
			best = Vector3(d, hw, _upper_water_y(pz))
	return best


## Water surface of the upper river at `z` (it runs due south over its last stretch).
func _upper_water_y(z: float) -> float:
	return FALLS_LIP_Y + maxf(_face_z() + FALLS_OVERHANG - z, 0.0) * UPPER_GRADE


## Nearest point of the river below the falls: distance, half width, water height.
func _lower_river_at(x: float, z: float) -> Vector3:
	var q := Vector2(x, z)
	var best := Vector3(1e9, 0.0, 0.0)
	for i in range(LOWER_RIVER.size() - 1):
		var a := Vector2(LOWER_RIVER[i][0], LOWER_RIVER[i][1])
		var b := Vector2(LOWER_RIVER[i + 1][0], LOWER_RIVER[i + 1][1])
		var ab: Vector2 = b - a
		var t: float = clampf((q - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d: float = q.distance_to(a + ab * t)
		if d < best.x:
			best = Vector3(d, lerpf(float(LOWER_RIVER[i][2]), float(LOWER_RIVER[i + 1][2]), t),
					lerpf(float(LOWER_RIVER[i][3]), float(LOWER_RIVER[i + 1][3]), t))
	return best


## The falls road's centreline height, and the cliff face line behind it.
func _falls_z() -> float:
	return (_segs[SEG_FALLS]["p0"] as Vector2).y


func _face_z() -> float:
	return _falls_z() - FALLS_FACE_OFF


func _pool_centre() -> Vector2:
	return Vector2(FALLS_X, _face_z() + POOL_OFF)


## Distance from (x, z) to the falls road's U round the pool (the two corners and the straight
## behind the falls), whether the point lies outside the U (away from the pool), and how far
## round the U it is (0 in the middle of the straight, 1 past the corners' ends).
func _falls_u(x: float, z: float) -> Vector3:
	var q := Vector2(x, z)
	var best := 1e9
	var outside := 0.0
	var along := 1.0
	for i in [SEG_FALLS - 1, SEG_FALLS, SEG_FALLS + 1]:
		var seg: Dictionary = _segs[i]
		var p0: Vector2 = seg["p0"]
		var th0: float = seg["th0"]
		if seg["kind"] == "S":
			var p1: Vector2 = p0 + _dir_of(th0) * float(seg["len"])
			var d: float = _segment_distance(q, p0, p1)
			if d < best:
				best = d
				outside = 1.0 if q.y < p0.y else 0.0
				var mid: float = (p0.x + p1.x) * 0.5
				along = clampf(absf(q.x - mid) / (absf(p1.x - p0.x) * 0.5) * 0.35, 0.0, 0.35)
		else:
			var r: float = seg["r"]
			var sign: float = seg["sign"]
			var c: Vector2 = p0 + _right_of(th0) * r * sign
			var ang0: float = (p0 - c).angle()
			var rel: Vector2 = q - c
			var a: float = wrapf(rel.angle() - ang0, -PI, PI)
			# The arc sweeps round its centre the way it turns; past its ends, measure to the
			# nearer end point.
			var sweep: float = sign * float(seg["len"]) / r
			var u: float = a / sweep
			var d2: float
			if u >= 0.0 and u <= 1.0:
				d2 = absf(rel.length() - r)
			else:
				var e0: Vector2 = p0
				var e1: Vector2 = c + (p0 - c).rotated(sweep)
				d2 = minf(q.distance_to(e0), q.distance_to(e1))
				u = 0.0 if q.distance_to(e0) < q.distance_to(e1) else 1.0
			if d2 < best:
				best = d2
				outside = 1.0 if rel.length() > r else 0.0
				# The corner after the straight runs away from it, the one before toward it.
				var from_straight: float = u if i == SEG_FALLS + 1 else 1.0 - u
				along = 0.35 + from_straight * 0.65
	return Vector3(best, outside, along)


## The cliff round the falls: how strongly (x, z) is cliff top (1) or foot (0) territory, and the
## weight of the cliff there (it fades out round the corners).
func _cliff(x: float, z: float) -> Vector2:
	var u: Vector3 = _falls_u(x, z)
	if u.y < 0.5:
		return Vector2(0.0, 0.0)
	var w: float = 1.0 - smoothstep(0.55, 0.95, u.z)
	var top: float = smoothstep(FALLS_FACE_OFF - 1.0, FALLS_FACE_OFF + 1.2, u.x)
	return Vector2(top, w)


## The gorge's floor runs from GORGE_WEST metres beyond the gorge road (west) to GORGE_EAST beyond
## the river (east), between walls GORGE_WALL_W / GORGE_WALL_E wide; both open out into the
## lowland south of the gorge's mouth. One entry per GORGE_DZ metres of z from GORGE_Z0.
const GORGE_Z0 := -440.0
const GORGE_Z1 := 260.0
const GORGE_DZ := 2.0
const GORGE_WEST := 16.0
const GORGE_EAST := 32.0
const GORGE_WALL_W := 24.0
const GORGE_WALL_E := 34.0
const GORGE_MOUTH_Z := -110.0
var _gorge_w := PackedFloat32Array()
var _gorge_e := PackedFloat32Array()


## The gorge road's x at every z down the gorge (it runs due south bar the S-bend), and the
## river's, give the floor's two edges.
func _build_gorge_table() -> void:
	var road_z := PackedFloat32Array()
	var road_x := PackedFloat32Array()
	var s := 0.0
	var s_end: float = _seg_s(SEG_MATOPE, 0.0)
	while s <= s_end:
		var p: Vector2 = _plan_at(s)["p"]
		road_z.append(p.y)
		road_x.append(p.x)
		s += 1.0
	_gorge_w = PackedFloat32Array()
	_gorge_e = PackedFloat32Array()
	var n: int = int((GORGE_Z1 - GORGE_Z0) / GORGE_DZ) + 1
	var k := 0
	for i in range(n):
		var z: float = GORGE_Z0 + float(i) * GORGE_DZ
		while k < road_z.size() - 2 and road_z[k + 1] < z:
			k += 1
		var rx: float = road_x[k]
		if z > road_z[0] and k < road_z.size() - 1:
			var t: float = clampf((z - road_z[k]) / maxf(road_z[k + 1] - road_z[k], 0.001), 0.0, 1.0)
			rx = lerpf(road_x[k], road_x[k + 1], t)
		var west: float = rx - GORGE_WEST
		if z < road_z[0]:
			# Round the falls the floor takes in the whole U, from corner to corner.
			west = road_x[0] - GORGE_WEST
		if z > GORGE_MOUTH_Z:
			west -= (z - GORGE_MOUTH_Z) * 0.9
		var river_x: float = _lower_river_x(z)
		var east: float = river_x + GORGE_EAST
		# The east bank road and the corner down to it sit on the floor too.
		east = maxf(east, lerpf(80.0, 0.0, smoothstep(-300.0, -240.0, z)))
		if z > GORGE_MOUTH_Z:
			east += (z - GORGE_MOUTH_Z) * 1.1
		_gorge_w.append(west)
		_gorge_e.append(east)


func _lower_river_x(z: float) -> float:
	if z <= float(LOWER_RIVER[0][1]):
		return float(LOWER_RIVER[0][0])
	for i in range(LOWER_RIVER.size() - 1):
		var z0: float = LOWER_RIVER[i][1]
		var z1: float = LOWER_RIVER[i + 1][1]
		if z <= z1:
			return lerpf(float(LOWER_RIVER[i][0]), float(LOWER_RIVER[i + 1][0]), (z - z0) / (z1 - z0))
	return float(LOWER_RIVER[LOWER_RIVER.size() - 1][0])


## Floor edges (west, east) at z.
func _gorge_edges(z: float) -> Vector2:
	var f: float = clampf((z - GORGE_Z0) / GORGE_DZ, 0.0, float(_gorge_w.size() - 1) - 0.001)
	var i: int = int(f)
	var t: float = f - float(i)
	return Vector2(lerpf(_gorge_w[i], _gorge_w[i + 1], t), lerpf(_gorge_e[i], _gorge_e[i + 1], t))


## The landscape before any road or water: the plateau in the north and on the west ridge, the
## hillside of the Nyoka falling south-west from it, the gorge below the falls with its walls,
## the lowland and swamp in the south, and the forested mountains on the horizon.
func _base_height(x: float, z: float) -> float:
	var n1: float = _base_noise.get_noise_2d(x, z)
	var plateau: float = PLATEAU_Y + n1 * 3.0 + _detail_noise.get_noise_2d(x * 0.5, z * 0.5) * 0.6
	var up: float = plateau
	# The Nyoka's hillside: falling from the plateau's edge south-west to the gorge floor.
	var hill_u: float = smoothstep(-415.0, -205.0, z + (250.0 - x) * 0.22) * (1.0 - smoothstep(300.0, 420.0, x))
	hill_u *= smoothstep(-20.0, 60.0, x) * (1.0 - smoothstep(-235.0, -175.0, z))
	up = lerpf(up, 5.0 + n1 * 2.0, hill_u)
	# South of it the gorge's east wall rises only to forested hills.
	up = lerpf(up, 24.0 + n1 * 5.0, smoothstep(-235.0, -175.0, z) * smoothstep(-20.0, 60.0, x))
	# West of the ridge the land drops to a forested valley.
	up = lerpf(up, 17.0 + n1 * 4.0, smoothstep(-270.0, -420.0, x))
	# The plateau's southern edge slopes down to the lowland.
	var south: float = smoothstep(-170.0, 70.0, z)
	up = lerpf(up, LOWLAND_Y + 1.0 + n1 * 1.5, south)
	var h: float = up
	# The gorge below the falls: a floor with steep walls either side.
	if z > GORGE_Z0 and z < GORGE_Z1:
		var e: Vector2 = _gorge_edges(z)
		var floor_y: float = lerpf(5.2, 3.4, smoothstep(-380.0, -100.0, z))
		floor_y = lerpf(floor_y, LOWLAND_Y, smoothstep(-100.0, 80.0, z)) + _detail_noise.get_noise_2d(x, z) * 0.5
		var out_w: float = e.x - x
		var out_e: float = x - e.y
		var wall := 0.0
		if out_w > 0.0:
			wall = pow(smoothstep(0.0, GORGE_WALL_W, out_w), 0.7)
		elif out_e > 0.0:
			wall = pow(smoothstep(0.0, GORGE_WALL_E, out_e), 0.8)
		# North of the cliff there is no gorge, only the plateau.
		var inside: float = smoothstep(_face_z() - 4.0, _face_z() + 3.0, z)
		if h > floor_y:
			h = lerpf(h, floor_y + (h - floor_y) * wall, inside)
	# The river above the falls comes down a valley out of the hills.
	var ur: Vector3 = _upper_river_at(x, z)
	if z < _face_z():
		var valley_y: float = ur.z + 4.0 + maxf(ur.x - ur.y, 0.0) * 0.22
		h = minf(h, lerpf(h, valley_y, smoothstep(_face_z() - 120.0, _face_z() - 500.0, z)))
	# Hills and then mountains toward the horizon, misty and green.
	var far: float = Vector2(x, z + 150.0).length()
	var hills: float = smoothstep(560.0, 1900.0, far) * (_far_noise.get_noise_2d(x, z) * 0.5 + 0.55) * 260.0
	hills += smoothstep(1200.0, 2600.0, -z) * 180.0 * (0.8 + _far_noise.get_noise_2d(x * 0.4, z) * 0.5)
	# The upper river's valley keeps on through them.
	if z < _face_z():
		hills *= smoothstep(ur.y + 30.0, ur.y + 260.0, ur.x)
	return h + hills


func _add_road_samples() -> void:
	_rs_pos = PackedVector3Array()
	_rs_right = PackedVector3Array()
	_rs_s = PackedFloat32Array()
	_rs_gap = PackedByteArray()
	_rs_cells.clear()
	var n: int = int(floor(_lap_len / SAMPLE_STEP))
	for k in range(n):
		var s: float = float(k) * SAMPLE_STEP
		var pa: Dictionary = _plan_at(s)
		var p2: Vector2 = pa["p"]
		var r2: Vector2 = _right_of(float(pa["th"]))
		var pos := Vector3(p2.x, _road_y(s), p2.y)
		_rs_pos.append(pos)
		_rs_right.append(Vector3(r2.x, 0.0, r2.y))
		_rs_s.append(s)
		_rs_gap.append(1 if _on_bridge(s) else 0)
		var key := Vector2i(floori(pos.x / CELL), floori(pos.z / CELL))
		var bucket: PackedInt32Array = _rs_cells.get(key, PackedInt32Array())
		bucket.append(k)
		_rs_cells[key] = bucket
	print("  road samples: %d" % _rs_pos.size())


## The road field on a coarse grid: near the road the ground follows the road's own height.
func _build_road_field() -> void:
	_rf_x0 = FINE_X.x - 260.0
	_rf_z0 = FINE_Z.x - 260.0
	_rf_nx = int((FINE_X.y - FINE_X.x + 520.0) / RF_STEP) + 1
	_rf_nz = int((FINE_Z.y - FINE_Z.x + 520.0) / RF_STEP) + 1
	_rf_h = PackedFloat32Array()
	_rf_h.resize(_rf_nx * _rf_nz)
	var reach: float = RF_SIGMA * 3.0
	var inv: float = 1.0 / (RF_SIGMA * RF_SIGMA)
	for iz in range(_rf_nz):
		var z: float = _rf_z0 + float(iz) * RF_STEP
		for ix in range(_rf_nx):
			var x: float = _rf_x0 + float(ix) * RF_STEP
			var wsum := 0.0
			var hsum := 0.0
			var cx: int = floori(x / CELL)
			var cz: int = floori(z / CELL)
			var span: int = int(ceil(reach / CELL))
			for gz in range(cz - span, cz + span + 1):
				for gx in range(cx - span, cx + span + 1):
					var bucket: PackedInt32Array = _rs_cells.get(Vector2i(gx, gz), PackedInt32Array())
					for i in bucket:
						if i % 3 != 0:
							continue
						var p: Vector3 = _rs_pos[i]
						var dd: float = (p.x - x) * (p.x - x) + (p.z - z) * (p.z - z)
						if dd > reach * reach:
							continue
						var w: float = exp(-dd * inv)
						wsum += w
						hsum += w * p.y
			var base: float = _base_height(x, z)
			_rf_h[iz * _rf_nx + ix] = (hsum + RF_W0 * base) / (wsum + RF_W0)


func _road_field_at(x: float, z: float) -> float:
	var fx: float = (x - _rf_x0) / RF_STEP
	var fz: float = (z - _rf_z0) / RF_STEP
	if fx < 0.0 or fz < 0.0 or fx >= float(_rf_nx - 1) or fz >= float(_rf_nz - 1):
		return _base_height(x, z)
	var ix: int = int(fx)
	var iz: int = int(fz)
	var tx: float = fx - float(ix)
	var tz: float = fz - float(iz)
	var i: int = iz * _rf_nx + ix
	var a: float = lerpf(_rf_h[i], _rf_h[i + 1], tx)
	var b: float = lerpf(_rf_h[i + _rf_nx], _rf_h[i + _rf_nx + 1], tx)
	return lerpf(a, b, tz)


## How much the gorge's own shape overrules the road field at (x, z): inside the gorge and on
## its walls the landscape stands as it is (the walls would otherwise be smoothed into ramps).
func _gorge_weight(x: float, z: float) -> float:
	if z < _face_z() or z > GORGE_MOUTH_Z + 120.0:
		return 0.0
	var e: Vector2 = _gorge_edges(z)
	var w: float = smoothstep(e.x - GORGE_WALL_W - 30.0, e.x - GORGE_WALL_W, x) * (1.0 - smoothstep(e.y + GORGE_WALL_E, e.y + GORGE_WALL_E + 30.0, x))
	w *= smoothstep(_face_z(), _face_z() + 15.0, z) * (1.0 - smoothstep(GORGE_MOUTH_Z, GORGE_MOUTH_Z + 120.0, z))
	return w


## The cut slope the grading allows at (x, z): steep where a wall of rock stands over the road,
## the gorge's walls and the cliff round the falls.
func _cut_slope_at(x: float, z: float) -> float:
	var cut: float = CUT_SLOPE
	var cl: Vector2 = _cliff(x, z)
	if cl.y > 0.0:
		cut = lerpf(cut, 40.0, cl.y * smoothstep(FALLS_FACE_OFF - 3.0, FALLS_FACE_OFF - 1.5, _falls_u(x, z).x))
	if z > _face_z() and z < GORGE_MOUTH_Z + 60.0:
		var e: Vector2 = _gorge_edges(z)
		var wall: float = maxf(smoothstep(e.x + 2.0, e.x - 2.0, x), smoothstep(e.y - 2.0, e.y + 2.0, x))
		cut = lerpf(cut, 3.0, wall * (1.0 - smoothstep(GORGE_MOUTH_Z, GORGE_MOUTH_Z + 60.0, z)))
	return cut


## The ground before grading: the road field (or the gorge as it stands), the cliff round the
## falls, a little relief.
func _natural_height(x: float, z: float) -> float:
	var h: float = _road_field_at(x, z)
	var gw: float = _gorge_weight(x, z)
	if gw > 0.0:
		h = lerpf(h, _base_height(x, z), gw)
	h += _detail_noise.get_noise_2d(x, z) * 0.45
	var cl: Vector2 = _cliff(x, z)
	if cl.y > 0.0:
		var top: float = maxf(h, CLIFF_TOP + _detail_noise.get_noise_2d(x * 0.7, z * 0.7) * 0.5)
		var foot: float = minf(h, _falls_z_height() + 0.4)
		h = lerpf(h, lerpf(foot, top, cl.x), cl.y)
	return h


func _falls_z_height() -> float:
	return _road_y(_seg_s(SEG_FALLS, 0.5))


## Clamps `h` between the fill and cut bounds of every road segment within reach (the cut bound
## is relaxed by `cut` where a cliff stands over the road). Returns the graded height and, where
## (x, z) lies beside a segment inside the flat strip, that segment's road height (else NAN).
func _grade(h: float, x: float, z: float, cut: float) -> Vector2:
	var cx: int = floori(x / CELL)
	var cz: int = floori(z / CELL)
	var upper := 1e9
	var lower := -1e9
	var touched := false
	var flat_y := NAN
	var flat_lat := 1e9
	var n: int = _rs_pos.size()
	for gz in range(cz - 2, cz + 3):
		for gx in range(cx - 2, cx + 3):
			var bucket: PackedInt32Array = _rs_cells.get(Vector2i(gx, gz), PackedInt32Array())
			for i in bucket:
				var j: int = (i + 1) % n
				if _rs_gap[i] == 1 or _rs_gap[j] == 1:
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
				var t_raw: float = (dx * sx + dz * sz) / l2
				var t: float = clampf(t_raw, 0.0, 1.0)
				var excess: float = absf(t_raw - t) * sqrt(l2)
				var fx: float = x - (a.x + sx * t)
				var fz: float = z - (a.z + sz * t)
				var lateral: float = sqrt(fx * fx + fz * fz)
				var foot_y: float = lerpf(a.y, b.y, t)
				var over: float = maxf(0.0, lateral - ROAD_FLAT)
				# Rounded shoulder, so there is no crease at the edge of the flat strip.
				var soft: float = over * over / (over + 4.0)
				upper = minf(upper, foot_y + soft * cut + excess * cut)
				lower = maxf(lower, foot_y - soft * FILL_SLOPE - excess * FILL_SLOPE)
				touched = true
				if excess < 0.01 and lateral <= ROAD_FLAT and lateral < flat_lat:
					flat_lat = lateral
					flat_y = foot_y
	if not touched:
		return Vector2(h, NAN)
	if lower > upper:
		return Vector2(upper, flat_y)
	return Vector2(clampf(h, lower, upper), flat_y)


## Height the water allows at (x, z): the beds of both rivers, the plunge pool and the swamp,
## and their banks rising beside them.
func _water_cap(x: float, z: float) -> float:
	var cap := 1e9
	# Above the falls the river runs in a slot of rock, steepest near the brink.
	var ur: Vector3 = _upper_river_at(x, z)
	if z < _face_z() + 0.5 and ur.x < ur.y + 40.0 and z > -1400.0:
		var near_brink: float = 1.0 - smoothstep(_face_z() - 200.0, _face_z() - 40.0, z)
		var bank: float = lerpf(3.0, 0.7, near_brink)
		# The bed shoals onto the shelf the river pours off.
		var depth: float = 2.2 * smoothstep(_face_z() + 1.0, _face_z() - 40.0, z)
		if ur.x < ur.y:
			cap = ur.z - 0.4 - depth * (1.0 - pow(ur.x / ur.y, 2.0))
		else:
			cap = ur.z - 0.4 + (ur.x - ur.y) * bank
	var lr: Vector3 = _lower_river_at(x, z)
	if lr.x < lr.y + 40.0:
		if lr.x < lr.y:
			cap = minf(cap, lr.z - 0.3 - 1.8 * (1.0 - pow(lr.x / lr.y, 2.0)))
		else:
			cap = minf(cap, lr.z - 0.3 + (lr.x - lr.y) * 0.45)
	var pc: Vector2 = _pool_centre()
	var pd: float = Vector2(x, z).distance_to(pc)
	if pd < POOL_R + 30.0:
		if pd < POOL_R:
			cap = minf(cap, POOL_Y - 0.4 - 4.0 * (1.0 - pow(pd / POOL_R, 2.0)))
		else:
			cap = minf(cap, POOL_Y - 0.4 + (pd - POOL_R) * 1.4)
	for sp in SWAMP_POOLS:
		var d: float = Vector2(x - sp.x, z - sp.y).length()
		if d < sp.z + 25.0:
			var e: float = d / sp.z + _detail_noise.get_noise_2d(x * 2.0, z * 2.0) * 0.12
			if e < 1.0:
				cap = minf(cap, SWAMP_Y - 0.25 - 0.9 * (1.0 - e * e))
			else:
				cap = minf(cap, SWAMP_Y - 0.25 + (e - 1.0) * sp.z * 0.08)
	return cap


## Distance to the nearest road centreline (the bridge span excluded), the signed lateral across
## it (+ right of travel), and the arc length of that sample.
func _road_lat(x: float, z: float, reach: float) -> Vector3:
	var cx: int = floori(x / CELL)
	var cz: int = floori(z / CELL)
	var best := 1e9
	var lat := 0.0
	var at_s := 0.0
	var span: int = 1 if reach <= CELL else 2
	var n: int = _rs_pos.size()
	for gz in range(cz - span, cz + span + 1):
		for gx in range(cx - span, cx + span + 1):
			var bucket: PackedInt32Array = _rs_cells.get(Vector2i(gx, gz), PackedInt32Array())
			for i in bucket:
				var j: int = (i + 1) % n
				if _rs_gap[i] == 1 or _rs_gap[j] == 1:
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
					at_s = _rs_s[i]
	return Vector3(sqrt(best), lat, at_s)


func _road_distance(x: float, z: float) -> float:
	return _road_lat(x, z, 80.0).x


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
	_road_mud = PackedByteArray()
	_road_mud.resize(nx * nz)
	for iz in range(nz):
		var z: float = _grid_z[iz]
		for ix in range(nx):
			var x: float = _grid_x[ix]
			var i: int = iz * nx + ix
			var near: bool = x > FINE_X.x - 200.0 and x < FINE_X.y + 200.0 and z > FINE_Z.x - 200.0 and z < FINE_Z.y + 200.0
			if not near:
				_heights[i] = minf(_base_height(x, z), _water_cap(x, z))
				_road_d[i] = 1e9
				continue
			var h: float = _natural_height(x, z)
			var g: Vector2 = _grade(h, x, z, _cut_slope_at(x, z))
			h = minf(g.x, _water_cap(x, z))
			if not is_nan(g.y):
				h = g.y
			h = minf(h, _under_bridge_cap(x, z))
			_heights[i] = h
			var rl: Vector3 = _road_lat(x, z, 20.0)
			_road_d[i] = rl.x
			_road_mud[i] = 1 if rl.x < 30.0 and _in_mud(rl.z) else 0


## Ground height at any (x, z) from the built heightfield, interpolated like the triangles.
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


func _in_water(x: float, z: float, margin: float) -> bool:
	var ur: Vector3 = _upper_river_at(x, z)
	if z < _face_z() and ur.x < ur.y + margin:
		return true
	var lr: Vector3 = _lower_river_at(x, z)
	if lr.x < lr.y + margin:
		return true
	if Vector2(x, z).distance_to(_pool_centre()) < POOL_R + margin:
		return true
	for sp in SWAMP_POOLS:
		if Vector2(x - sp.x, z - sp.y).length() < sp.z + margin:
			return true
	return false


## Vertex-colour masks for jungle_ground.gdshader: rock, road band, wet, lateral.
func _terrain_masks(x: float, z: float, h: float, nrm_y: float, mud: bool) -> Color:
	var rl: Vector3 = _road_lat(x, z, 20.0)
	var band: float = 1.0 - smoothstep(13.0, 15.0, rl.x)
	# Rock on the cliff, in the river's slot and on anything too steep to hold soil.
	var rock: float = 1.0 - smoothstep(0.55, 0.72, nrm_y)
	var cl: Vector2 = _cliff(x, z)
	rock = maxf(rock, cl.y * (1.0 - smoothstep(FALLS_FACE_OFF + 4.0, FALLS_FACE_OFF + 9.0, _falls_u(x, z).x)) * smoothstep(FALLS_FACE_OFF - 4.0, FALLS_FACE_OFF - 1.0, _falls_u(x, z).x))
	var ur: Vector3 = _upper_river_at(x, z)
	if z < _face_z() + 1.0 and ur.x < ur.y + 6.0:
		rock = maxf(rock, 1.0 - smoothstep(ur.y + 2.0, ur.y + 6.0, ur.x))
	if Vector2(x, z).distance_to(_pool_centre()) < POOL_R + 8.0:
		rock = maxf(rock, 0.8)
	rock *= smoothstep(ROAD_HALF + 0.5, ROAD_HALF + 2.0, rl.x)
	var wet := 0.0
	if _in_water(x, z, 25.0):
		var water_y: float = minf(_lower_river_at(x, z).z, POOL_Y)
		wet = 1.0 - smoothstep(0.3, 1.8, h - water_y)
		if h < SWAMP_Y + 0.6:
			wet = maxf(wet, 0.9)
	if mud:
		wet = maxf(wet, 0.6 * (1.0 - smoothstep(ROAD_HALF + 4.0, ROAD_HALF + 14.0, rl.x)))
	var lat_enc: float = clampf(rl.y / 24.0 + 0.5, 0.0, 1.0) if rl.x < 1000.0 else 1.0
	return Color(rock, band, wet, lat_enc)


## Terrain mesh with the shader masks in the vertex colour, and its collision split into the
## road, the mud and the forest floor.
func _build_terrain(parent: Node, mat: Material) -> Array:
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
			if _road_d[i] < 80.0 or _near_detail(x, z):
				colors[i] = _terrain_masks(x, z, h, nrm.y, _road_mud[i] == 1)
			else:
				colors[i] = Color(1.0 - smoothstep(0.55, 0.72, nrm.y), 0.0, 0.0, 0.5)
	# Each cell is split along the diagonal joining its closer heights, so steep slopes that run
	# across the grid don't saw into teeth.
	var indices := PackedInt32Array()
	var road_faces := PackedVector3Array()
	var mud_faces := PackedVector3Array()
	var ground_faces := PackedVector3Array()
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
				# Front faces wind clockwise seen from above (CLAUDE.md): check against the up hint.
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
				# Packed arrays are values: append to each by name, never through an alias.
				if _road_d[tri[0]] < ROAD_COLLIDE and _road_d[tri[1]] < ROAD_COLLIDE and _road_d[tri[2]] < ROAD_COLLIDE:
					if _road_mud[tri[0]] == 1 or _road_mud[tri[1]] == 1 or _road_mud[tri[2]] == 1:
						mud_faces.append_array([p0, p1, p2])
					else:
						road_faces.append_array([p0, p1, p2])
				else:
					ground_faces.append_array([p0, p1, p2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, mat)

	var ground_body := StaticBody3D.new()
	ground_body.name = "ForestFloor"
	ground_body.set_meta(&"dust_color", Color(0.30, 0.24, 0.16, 0.95))
	parent.add_child(ground_body)
	var inst := MeshInstance3D.new()
	inst.name = "ForestFloorMesh"
	inst.mesh = _save_baked_resource(mesh, "ground_visual")
	ground_body.add_child(inst)
	_add_faces_shape(ground_body, ground_faces, "ForestFloorShape", "ground_collision_shape")
	var bodies: Array = []
	for spec in [["JungleRoad", road_faces, 1.0], ["MatopeMudRoad", mud_faces, MUD_GRIP]]:
		var body := StaticBody3D.new()
		body.name = spec[0]
		# The rain lowers every road's grip at runtime; the mud starts low (PlayerCart reads it).
		body.set_meta(&"ice_grip", spec[2])
		body.set_meta(&"dry_grip", spec[2])
		if spec[0] == "MatopeMudRoad":
			# Wheels throw mud here, though it counts as road (PlayerCart).
			body.set_meta(&"surface_spray", true)
			body.set_meta(&"dust_color", Color(0.24, 0.17, 0.10, 0.95))
		else:
			body.set_meta(&"dust_color", Color(0.62, 0.36, 0.24, 0.9))
		parent.add_child(body)
		_add_faces_shape(body, spec[1], String(spec[0]) + "Shape", String(spec[0]).to_lower() + "_collision_shape")
		bodies.append(body)
	print("  ground: %d triangles, %d road, %d mud" % [indices.size() / 3, road_faces.size() / 3, mud_faces.size() / 3])
	return bodies


func _add_faces_shape(body: Node, faces: PackedVector3Array, shape_name: String, res_name: String) -> void:
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var cs := CollisionShape3D.new()
	cs.name = shape_name
	cs.shape = _save_baked_resource(shape, res_name)
	body.add_child(cs)


## The masks only matter where someone can see them closely: within the fine grid.
func _near_detail(x: float, z: float) -> bool:
	return x > FINE_X.x - 60.0 and x < FINE_X.y + 60.0 and z > FINE_Z.x - 60.0 and z < FINE_Z.y + 60.0


## A top-down picture of the built ground (height tint, hill shading, the road and the water)
## for checking the landscape without rendering it: `-- dump=<file.png>`.
func _dump_map(path: String) -> void:
	var x0 := -460.0
	var z0 := -700.0
	var px := 1.5
	var w := 620
	var hh := 680
	var img := Image.create(w, hh, false, Image.FORMAT_RGB8)
	var light := Vector3(-0.5, 0.75, -0.45).normalized()
	for j in range(hh):
		var z: float = z0 + float(j) * px
		for i in range(w):
			var x: float = x0 + float(i) * px
			var y: float = _ground_at(x, z)
			var gx: float = _ground_at(x + 1.0, z) - _ground_at(x - 1.0, z)
			var gz: float = _ground_at(x, z + 1.0) - _ground_at(x, z - 1.0)
			var nrm := Vector3(-gx * 0.5, 1.0, -gz * 0.5).normalized()
			var shade: float = clampf(nrm.dot(light), 0.0, 1.0) * 0.75 + 0.25
			var t: float = clampf(y / 60.0, 0.0, 1.0)
			var col := Color(0.25, 0.45, 0.2).lerp(Color(0.85, 0.75, 0.5), t)
			if fposmod(y, 5.0) < 0.35:
				col = col.darkened(0.25)
			if _in_water(x, z, 0.0) and y < 2.0:
				col = Color(0.2, 0.35, 0.7)
			var rd: float = _road_distance(x, z) if absf(x) < 400.0 else 1e9
			if rd < ROAD_HALF:
				col = Color(0.8, 0.25, 0.15)
			img.set_pixel(i, j, col * shade)
	img.save_png(path)
	print("  map written to %s" % path)


# ======================================================================================
#  Water
# ======================================================================================

## Tea-brown forest water: tannin from the leaf litter, clear in the shallows.
func _water_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://river_water.gdshader")
	var n := FastNoiseLite.new()
	n.seed = 5521
	n.frequency = 0.035
	n.fractal_octaves = 3
	var nt := NoiseTexture2D.new()
	nt.seamless = true
	nt.as_normal_map = true
	nt.bump_strength = 4.0
	nt.noise = n
	nt.width = 256
	nt.height = 256
	mat.set_shader_parameter("noise_tex", nt)
	var f := FastNoiseLite.new()
	f.seed = 8086
	f.frequency = 0.05
	f.fractal_octaves = 4
	f.noise_type = FastNoiseLite.TYPE_CELLULAR
	f.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_DIV
	var ft := NoiseTexture2D.new()
	ft.seamless = true
	ft.noise = f
	ft.width = 256
	ft.height = 256
	mat.set_shader_parameter("foam_noise", ft)
	mat.set_shader_parameter("deep_color", Vector3(0.025, 0.035, 0.018))
	mat.set_shader_parameter("shallow_color", Vector3(0.16, 0.15, 0.07))
	mat.set_shader_parameter("foam_color", Vector3(0.86, 0.88, 0.82))
	# The forest round it, not the sky, is what the water would mirror: keep it dull.
	mat.set_shader_parameter("sky_tint", Vector3(0.22, 0.30, 0.22))
	mat.set_shader_parameter("roughness_min", 0.3)
	mat.set_shader_parameter("specular_max", 0.2)
	mat.set_shader_parameter("flow_speed", 1.6)
	mat.set_shader_parameter("clarity_depth", 1.6)
	mat.set_shader_parameter("shore_foam_depth", 0.35)
	return mat


## Swamp water: still, opaque and dark, with a green scum.
func _swamp_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://still_water.gdshader")
	var n := FastNoiseLite.new()
	n.seed = 9310
	n.frequency = 0.02
	n.fractal_octaves = 3
	var nt := NoiseTexture2D.new()
	nt.seamless = true
	nt.as_normal_map = true
	nt.bump_strength = 3.0
	nt.noise = n
	nt.width = 256
	nt.height = 256
	mat.set_shader_parameter("noise_tex", nt)
	mat.set_shader_parameter("water_color", Color(0.05, 0.06, 0.025))
	mat.set_shader_parameter("sky_tint", Color(0.50, 0.58, 0.52))
	mat.set_shader_parameter("sky_reflect", 0.45)
	mat.set_shader_parameter("ripple_tile", 18.0)
	mat.set_shader_parameter("ripple_strength", 0.12)
	mat.set_shader_parameter("drift", 0.05)
	mat.set_shader_parameter("roughness", 0.3)
	return mat


## A river polyline resampled every `step` metres: [position (water surface), half width, metres
## downstream, drop per metre].
func _river_samples(pts: Array, step: float) -> Array:
	var out: Array = []
	var along := 0.0
	for i in range(pts.size() - 1):
		var a: Vector4 = pts[i]
		var b: Vector4 = pts[i + 1]
		var seg_len: float = Vector2(b.x - a.x, b.z - a.z).length()
		var steps: int = maxi(int(seg_len / step), 1)
		var drop: float = (a.y - b.y) / maxf(seg_len, 0.01)
		for k in range(steps):
			var t: float = float(k) / float(steps)
			out.append([Vector3(lerpf(a.x, b.x, t), lerpf(a.y, b.y, t), lerpf(a.z, b.z, t)), lerpf(a.w, b.w, t), along + seg_len * t, drop])
		along += seg_len
	var last: Vector4 = pts[pts.size() - 1]
	out.append([Vector3(last.x, last.y, last.z), last.w, along, 0.0])
	return out


## The upper river as (x, water y, z, half width), north to the lip; `to_z` cuts it short.
func _upper_river_points(to_z: float) -> Array:
	var pts: Array = []
	for i in range(UPPER_RIVER.size()):
		var r: Array = UPPER_RIVER[i]
		var z: float = r[1]
		if z > to_z:
			var prev: Array = UPPER_RIVER[i - 1]
			var t: float = (to_z - float(prev[1])) / (z - float(prev[1]))
			var x: float = lerpf(float(prev[0]), float(r[0]), t)
			pts.append(Vector4(x, _upper_water_y(to_z), to_z, lerpf(float(prev[2]), float(r[2]), t)))
			break
		pts.append(Vector4(r[0], _upper_water_y(z), z, r[2]))
	return pts


func _lower_river_points() -> Array:
	var pts: Array = []
	for r in LOWER_RIVER:
		pts.append(Vector4(r[0], r[3], r[1], r[2]))
	return pts


## A ribbon for river_water.gdshader: UV.x across, UV.y metres downstream; COLOR r turbulence, g
## current, b edge fade (`turb` and `fade` map metres downstream to 0..1).
func _river_ribbon(samples: Array, margin: float, turb: Callable, fade: Callable) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var across := 8
	var n: int = samples.size()
	for i in range(n):
		var p: Vector3 = samples[i][0]
		var prv: Vector3 = samples[maxi(i - 1, 0)][0]
		var nxt: Vector3 = samples[mini(i + 1, n - 1)][0]
		var fwd := Vector3(nxt.x - prv.x, 0.0, nxt.z - prv.z).normalized()
		var right := Vector3(-fwd.z, 0.0, fwd.x)
		var hw: float = float(samples[i][1]) + margin
		var along: float = samples[i][2]
		var drop: float = samples[i][3]
		var current: float = clampf(0.35 + drop * 40.0, 0.35, 1.5)
		var tb: float = clampf(maxf(drop * 25.0, float(turb.call(along))), 0.0, 1.0)
		var fd: float = fade.call(along)
		for k in range(across + 1):
			var u: float = float(k) / float(across)
			st.set_color(Color(tb, current, fd, 1.0))
			st.set_uv(Vector2(u, along))
			st.set_normal(Vector3.UP)
			st.add_vertex(p + right * lerpf(-hw, hw, u))
	for i in range(n - 1):
		for k in range(across):
			var a0: int = i * (across + 1) + k
			var b0: int = a0 + across + 1
			# Front face up: (c - a) x (b - a) must point +Y (CLAUDE.md winding note).
			st.add_index(a0)
			st.add_index(b0)
			st.add_index(a0 + 1)
			st.add_index(a0 + 1)
			st.add_index(b0)
			st.add_index(b0 + 1)
	return st.commit()


## A flat disc of water rings x segs; `col` gives each vertex's colour from its position.
func _water_disc(c: Vector3, r: float, rings: int, segs: int, col: Callable) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ri in range(rings + 1):
		var rr: float = r * float(ri) / float(rings)
		for si in range(segs + 1):
			var a: float = TAU * float(si) / float(segs)
			var q := Vector3(c.x + cos(a) * rr, c.y, c.z + sin(a) * rr)
			st.set_color(col.call(q, rr / r))
			st.set_uv(Vector2(float(si) / float(segs) * TAU * r * 0.25, rr))
			st.set_normal(Vector3.UP)
			st.add_vertex(q)
	for ri in range(rings):
		for si in range(segs):
			var a0: int = ri * (segs + 1) + si
			var b0: int = a0 + segs + 1
			st.add_index(a0)
			st.add_index(b0)
			st.add_index(a0 + 1)
			st.add_index(a0 + 1)
			st.add_index(b0)
			st.add_index(b0 + 1)
	return st.commit()


## The water: the river above the falls and below them, the plunge pool and the swamp, as
## meshes, and as the RiverWater node PlayerCart reads the surface from.
func _build_water(level_scene: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Water"
	level_scene.add_child(root)
	var mat := _water_material()
	var lip_z: float = _face_z() + FALLS_OVERHANG
	var upper: Array = _river_samples(_upper_river_points(lip_z), 3.0)
	var upper_len: float = upper[upper.size() - 1][2]
	var up_mesh: ArrayMesh = _river_ribbon(upper, 1.2,
			func(a: float) -> float: return smoothstep(upper_len - 45.0, upper_len - 3.0, a) * 0.55,
			func(_a: float) -> float: return 0.0)
	var mi := MeshInstance3D.new()
	mi.name = "UpperRiver"
	mi.mesh = _save_baked_resource(up_mesh, "water_upper")
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var lower: Array = _river_samples(_lower_river_points(), 3.0)
	var low_mesh: ArrayMesh = _river_ribbon(lower, 1.5,
			func(a: float) -> float: return (1.0 - smoothstep(0.0, 35.0, a)) * 0.32,
			func(a: float) -> float: return 1.0 - smoothstep(4.0, 22.0, a))
	var mi2 := MeshInstance3D.new()
	mi2.name = "LowerRiver"
	mi2.mesh = _save_baked_resource(low_mesh, "water_lower")
	mi2.material_override = mat
	mi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi2)
	# The plunge pool, foaming hardest where the falls land.
	var pc: Vector2 = _pool_centre()
	var impact := Vector2(FALLS_X, _falls_land_z())
	var pool_mesh: ArrayMesh = _water_disc(Vector3(pc.x, POOL_Y, pc.y), POOL_R + 1.5, 12, 48,
			func(q: Vector3, rr: float) -> Color:
				var di: float = Vector2(q.x, q.z).distance_to(impact)
				var tb: float = (1.0 - smoothstep(2.0, 18.0, di)) * 0.55
				return Color(clampf(tb, 0.1, 1.0), 0.5, smoothstep(0.82, 1.0, rr) * 0.0, 1.0))
	var pmi := MeshInstance3D.new()
	pmi.name = "PlungePool"
	pmi.mesh = _save_baked_resource(pool_mesh, "water_pool")
	pmi.material_override = mat
	pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pmi.position.y = 0.02
	root.add_child(pmi)
	# The swamp: still dark pools.
	var swamp_mat := _swamp_material()
	var k := 0
	for sp in SWAMP_POOLS:
		var smesh: ArrayMesh = _water_disc(Vector3(sp.x, SWAMP_Y, sp.y), sp.z * 1.25, 6, 32,
				func(_q: Vector3, _rr: float) -> Color: return Color(0, 0, 0, 1))
		var smi := MeshInstance3D.new()
		smi.name = "SwampPool_%d" % k
		smi.mesh = smesh
		smi.material_override = swamp_mat
		smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(smi)
		k += 1

	# What PlayerCart wades in and drowns in. The river above the falls stops short of the cliff:
	# the falls road runs under the slab, and a surface overhead would drown every cart on it.
	var node := Node3D.new()
	node.name = "RiverWater"
	node.set_script(RiverWaterScript)
	var pts := PackedVector3Array()
	var hws := PackedFloat32Array()
	var starts := PackedInt32Array()
	var bounds := Rect2(pc, Vector2.ZERO)
	for strip in [_upper_river_points(_face_z() - 3.0), _lower_river_points()]:
		starts.append(pts.size())
		for q in strip:
			pts.append(Vector3(q.x, q.y, q.z))
			hws.append(q.w + 1.0)
			bounds = bounds.expand(Vector2(q.x - q.w - 4.0, q.z - q.w - 4.0))
			bounds = bounds.expand(Vector2(q.x + q.w + 4.0, q.z + q.w + 4.0))
	var pools: Array[Vector4] = [Vector4(pc.x, POOL_Y, pc.y, POOL_R + 1.0)]
	for sp in SWAMP_POOLS:
		pools.append(Vector4(sp.x, SWAMP_Y, sp.y, sp.z * 1.15))
		bounds = bounds.expand(Vector2(sp.x - sp.z * 1.2, sp.y - sp.z * 1.2))
		bounds = bounds.expand(Vector2(sp.x + sp.z * 1.2, sp.y + sp.z * 1.2))
	bounds = bounds.expand(pc - Vector2(POOL_R + 2.0, POOL_R + 2.0))
	bounds = bounds.expand(pc + Vector2(POOL_R + 2.0, POOL_R + 2.0))
	node.set("strip_points", pts)
	node.set("strip_half_widths", hws)
	node.set("strip_starts", starts)
	node.set("pools", pools)
	node.set("water_bounds", bounds)
	level_scene.add_child(node)


# ======================================================================================
#  The falls
# ======================================================================================

## Where the falls' water is `t` seconds after leaving the lip (z, y), on the curtain's middle.
func _falls_arc(t: float) -> Vector2:
	return Vector2(_face_z() + FALLS_OVERHANG + FALLS_V0 * t, FALLS_LIP_Y - 0.25 - 4.9 * t * t)


func _falls_land_t() -> float:
	return sqrt((FALLS_LIP_Y - 0.25 - POOL_Y) / 4.9)


func _falls_land_z() -> float:
	return _falls_arc(_falls_land_t()).x


## The water must clear the road behind the falls with room to spare, and land in the pool.
func _verify_falls() -> void:
	var road_y: float = _falls_z_height()
	var lowest := INF
	var t := 0.0
	while t < _falls_land_t():
		var a: Vector2 = _falls_arc(t)
		if absf(a.x - _falls_z()) < ROAD_HALF + 1.5:
			lowest = minf(lowest, a.y - road_y)
		t += 0.01
	var land: float = _falls_land_z()
	var into_pool: float = POOL_R - absf(land - _pool_centre().y)
	print("  falls: %.0fm drop, clear %.1fm over the road behind them, land %.1fm inside the pool" % [FALLS_LIP_Y - POOL_Y, lowest, into_pool])
	if lowest < 8.0:
		push_error("The falls come down within %.1fm of the road behind them" % lowest)
	if into_pool < 1.5:
		push_error("The falls land %.1fm from the pool's edge" % into_pool)


func _soft_particle_material(color: Color, tex_size: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 1.5
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = tex_size
	tex.height = tex_size
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	m.albedo_texture = tex
	m.albedo_color = color
	return m


## A soft, ragged cloud sprite for mist and spray: noise shaped by a radial falloff.
var _mist_tex: Texture2D

func _mist_texture() -> Texture2D:
	if _mist_tex:
		return _mist_tex
	const SIZE := 128
	var n := FastNoiseLite.new()
	n.seed = 7720
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.035
	n.fractal_octaves = 4
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in range(SIZE):
		for x in range(SIZE):
			var d: float = Vector2(x - SIZE * 0.5, y - SIZE * 0.5).length() / (SIZE * 0.5)
			var cloud: float = n.get_noise_2d(x, y) * 0.5 + 0.5
			var a: float = clampf((1.0 - smoothstep(0.25, 1.0, d)) * smoothstep(0.25, 0.75, cloud + (1.0 - d) * 0.35), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	_mist_tex = _save_baked_resource(ImageTexture.create_from_image(img), "mist_puff")
	return _mist_tex


func _mist_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Soft where a puff cuts into rock or water, and thinning out when the camera is inside it.
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 3.0
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 1.0
	m.distance_fade_max_distance = 7.0
	m.albedo_texture = _mist_texture()
	m.albedo_color = Color(0.94, 0.97, 0.96, 1.0)
	return m


## Mist billowing out of an emission box: `amount` puffs `size` metres across living `life`
## seconds, drifting with `drift`, peaking at `alpha`.
func _mist_particles(pname: String, at: Vector3, box: Vector3, amount: int, size: float, life: float,
		dir: Vector3, speed: Vector2, drift: Vector3, alpha: float, aabb: AABB) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = pname
	p.position = at
	p.amount = amount
	p.lifetime = life
	p.preprocess = life * 1.3
	p.randomness = 0.6
	p.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = aabb
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box
	pm.direction = dir
	pm.spread = 45.0
	pm.initial_velocity_min = speed.x
	pm.initial_velocity_max = speed.y
	pm.gravity = drift
	pm.damping_min = 0.6
	pm.damping_max = 1.2
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.angular_velocity_min = -12.0
	pm.angular_velocity_max = 12.0
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.35))
	sc.add_point(Vector2(0.4, 0.8))
	sc.add_point(Vector2(1, 1.25))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var cr := Gradient.new()
	cr.offsets = PackedFloat32Array([0.0, 0.15, 0.6, 1.0])
	cr.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, alpha), Color(1, 1, 1, alpha * 0.55), Color(1, 1, 1, 0)])
	var crt := GradientTexture1D.new()
	crt.gradient = cr
	pm.color_ramp = crt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _mist_material()
	p.draw_pass_1 = q
	return p


## Droplets thrown up where the falls land.
func _spray_particles(at: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "FallsSpray"
	p.position = at
	p.amount = 280
	p.lifetime = 1.6
	p.preprocess = 2.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-30, -4, -20), Vector3(60, 24, 50))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(FALLS_HALF_W * 0.95, 0.3, 1.5)
	pm.direction = Vector3(0, 1, 0.3)
	pm.spread = 60.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 12.0
	pm.gravity = Vector3(0, -9.8, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.4
	var cr := Gradient.new()
	cr.colors = PackedColorArray([Color(1, 1, 1, 0.75), Color(1, 1, 1, 0)])
	var crt := GradientTexture1D.new()
	crt.gradient = cr
	pm.color_ramp = crt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	q.material = _soft_particle_material(Color(0.95, 0.98, 1.0, 1.0), 32)
	p.draw_pass_1 = q
	return p


## A faint rainbow standing in the spray over the pool.
func _rainbow(at: Vector3, yaw: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 36
	var r_in := 14.0
	var r_out := 17.5
	for i in range(segs + 1):
		var a: float = lerpf(0.12, PI - 0.12, float(i) / float(segs))
		for k in range(2):
			var r: float = r_in if k == 0 else r_out
			st.set_uv(Vector2(float(i) / float(segs), float(k)))
			st.add_vertex(Vector3(cos(a) * r, sin(a) * r - 7.0, 0.0))
	for i in range(segs):
		var a0: int = i * 2
		st.add_index(a0)
		st.add_index(a0 + 2)
		st.add_index(a0 + 1)
		st.add_index(a0 + 1)
		st.add_index(a0 + 2)
		st.add_index(a0 + 3)
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
uniform float strength = 0.07;
void fragment() {
	// Red on the outside of the bow, violet inside; fading out toward the feet of the arc.
	float h = UV.y;
	vec3 c = clamp(abs(fract(vec3(h * 0.78) + vec3(0.0, 0.666, 0.333)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	float edge = smoothstep(0.0, 0.35, UV.y) * smoothstep(1.0, 0.65, UV.y);
	float feet = smoothstep(0.0, 0.25, UV.x) * smoothstep(1.0, 0.75, UV.x);
	ALBEDO = c * strength * edge * feet;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	var mi := MeshInstance3D.new()
	mi.name = "MistRainbow"
	mi.mesh = st.commit()
	mi.material_override = m
	mi.position = at
	mi.rotation.y = yaw
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## A seamless loop of falling-water noise: brown noise for the roar, a little white for the hiss.
func _roar_stream() -> AudioStreamWAV:
	const RATE := 22050
	const SECONDS := 4.0
	var n: int = int(RATE * SECONDS)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2209
	var samples := PackedFloat32Array()
	samples.resize(n)
	var brown := 0.0
	var low := 0.0
	for i in range(n):
		var white: float = rng.randf_range(-1.0, 1.0)
		brown = clampf(brown * 0.995 + white * 0.06, -1.0, 1.0)
		low += (white - low) * 0.18
		samples[i] = brown * 0.9 + low * 0.35
	# Crossfade the tail into the head so the loop point is inaudible.
	var fade: int = int(RATE * 0.5)
	for i in range(fade):
		var t: float = float(i) / float(fade)
		samples[i] = samples[i] * t + samples[n - fade + i] * (1.0 - t)
	var peak := 0.001
	for i in range(n - fade):
		peak = maxf(peak, absf(samples[i]))
	var data := PackedByteArray()
	data.resize((n - fade) * 2)
	for i in range(n - fade):
		data.encode_s16(i * 2, int(clampf(samples[i] / peak * 0.8, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n - fade
	return _save_baked_resource(wav, "falls_roar") as AudioStreamWAV


## Rock in jungle_ground.gdshader's colours: a mesh drawn with vertex colour (1, 0, wet, 0.5) is
## all rock there, mossy on its ledges.
func _rock_vertex_color(wet: float) -> Color:
	return Color(1.0, 0.0, wet, 0.5)


## The slab the river pours off: a shelf of rock standing out of the cliff over the road behind
## the falls, its top the river's bed, its front the brink, its underside a dripping roof.
func _falls_slab_mesh() -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = 3361
	noise.frequency = 0.25
	var face: float = _face_z()
	var lip: float = face + FALLS_OVERHANG
	var half: float = FALLS_HALF_W + 7.0
	var cols := 40
	var rock_noise := FastNoiseLite.new()
	rock_noise.seed = 3362
	rock_noise.frequency = 0.35
	rock_noise.fractal_octaves = 3
	# The section's outline seen from the side, as (z, y) from the cliff over the top, down the
	# brink and back under the roof into the cliff.
	var top_y: float = FALLS_LIP_Y - 0.55
	var outline: Array = [
		Vector2(face - 2.0, top_y + 0.2), Vector2(face + 2.0, top_y), Vector2(lip - 1.0, top_y - 0.05),
		Vector2(lip, top_y - 0.35), Vector2(lip + 0.3, top_y - 1.4), Vector2(lip + 0.1, top_y - 2.8),
		Vector2(lip - 1.2, top_y - 3.6), Vector2(lip - 4.0, top_y - 4.6), Vector2(face + 0.5, top_y - 6.4),
		Vector2(face - 2.0, top_y - 7.0),
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array = []
	for ci in range(cols + 1):
		var u: float = float(ci) / float(cols)
		var x: float = FALLS_X + lerpf(-half, half, u)
		# The shelf thins and tucks back into the cliff toward its ends.
		var edge: float = smoothstep(0.0, 0.3, minf(u, 1.0 - u))
		var col: Array = []
		for k in range(outline.size()):
			var o: Vector2 = outline[k]
			var z: float = lerpf(face - 2.0, o.x, edge)
			var y: float = o.y
			# The river's bed dips a little in the middle of the shelf.
			if k <= 3:
				y -= (1.0 - smoothstep(FALLS_HALF_W - 2.0, FALLS_HALF_W + 3.0, absf(x - FALLS_X))) * 0.3
			var amp: float = (1.1 if k >= 3 else 0.15) * edge
			var q := Vector3(x, y, z)
			var jit := Vector3(rock_noise.get_noise_3dv(q), rock_noise.get_noise_3dv(q + Vector3(31.0, 7.0, 3.0)), rock_noise.get_noise_3dv(q - Vector3(5.0, 17.0, 29.0)))
			# Blocky: the noise is snapped into ledges and steps, as weathered rock breaks.
			jit = (jit * 3.0).floor() / 3.0 * amp + jit * amp * 0.4
			col.append(q + jit + Vector3(0, noise.get_noise_2d(x * 1.3, float(k) * 3.1) * 0.2, 0))
		grid.append(col)
	var ref := Vector3(FALLS_X, top_y - 3.0, face + 1.0)
	for ci in range(cols):
		for k in range(outline.size() - 1):
			var a: Vector3 = grid[ci][k]
			var b: Vector3 = grid[ci + 1][k]
			var c: Vector3 = grid[ci + 1][k + 1]
			var d: Vector3 = grid[ci][k + 1]
			var mid: Vector3 = (a + b + c + d) * 0.25
			var hint := Vector3(0.0, mid.y - ref.y, mid.z - ref.z)
			for tri in [[a, b, c], [a, c, d]]:
				var p0: Vector3 = tri[0]
				var p1: Vector3 = tri[1]
				var p2: Vector3 = tri[2]
				if (p2 - p0).cross(p1 - p0).dot(hint) < 0.0:
					var tmp: Vector3 = p1
					p1 = p2
					p2 = tmp
				for v in [p0, p1, p2]:
					st.set_color(_rock_vertex_color(0.45))
					st.add_vertex(v)
	st.index()
	st.generate_normals()
	return st.commit()


## A boulder: a cube-sphere pushed about by noise and flattened on its underside, in rock
## vertex colour (mossy on top in jungle_ground.gdshader).
func _boulder_mesh(seed: int) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 0.9
	noise.fractal_octaves = 3
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 6
	var faces: Array = [[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
			[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT],
			[Vector3.BACK, Vector3.UP, Vector3.LEFT], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT]]
	var squash := Vector3(1.0, 0.62, 0.85)
	for f in faces:
		var nrm: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var grid: Array = []
		for j in range(n + 1):
			var row: Array = []
			for i in range(n + 1):
				var d: Vector3 = (nrm + u * (float(i) / float(n) * 2.0 - 1.0) + v * (float(j) / float(n) * 2.0 - 1.0)).normalized()
				var r: float = 1.0 + noise.get_noise_3dv(d * 2.0) * 0.35
				var p: Vector3 = d * r * squash
				p.y = maxf(p.y, -0.35)
				row.append(p)
			grid.append(row)
		for j in range(n):
			for i in range(n):
				var a: Vector3 = grid[j][i]
				var b: Vector3 = grid[j][i + 1]
				var c: Vector3 = grid[j + 1][i + 1]
				var d2: Vector3 = grid[j + 1][i]
				for tri in [[a, b, c], [a, c, d2]]:
					var t0: Vector3 = tri[0]
					var t1: Vector3 = tri[1]
					var t2: Vector3 = tri[2]
					var mid: Vector3 = (t0 + t1 + t2) / 3.0
					if (t2 - t0).cross(t1 - t0).dot(mid) < 0.0:
						var tmp: Vector3 = t1
						t1 = t2
						t2 = tmp
					for vv in [t0, t1, t2]:
						st.set_color(_rock_vertex_color(0.35))
						st.add_vertex(vv)
	st.index()
	st.generate_normals()
	return st.commit()


## Boulders fallen from the cliff: round the plunge pool, along the foot of the cliff beside the
## road behind the falls (never on it), and down the gorge's banks.
func _build_boulders(parent: Node, rock_mat: Material) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8282
	var meshes: Array = [_save_baked_resource(_boulder_mesh(11), "boulder_0"), _save_baked_resource(_boulder_mesh(23), "boulder_1"), _save_baked_resource(_boulder_mesh(37), "boulder_2")]
	var xfs := {0: [], 1: [], 2: []}
	var colliders: Array = []
	var pc: Vector2 = _pool_centre()
	var placed := 0
	var tries := 0
	while placed < 70 and tries < 3000:
		tries += 1
		var a: float = rng.randf() * TAU
		var p: Vector2
		var size: float
		if rng.randf() < 0.6:
			p = pc + Vector2(cos(a), sin(a)) * (POOL_R + rng.randf_range(-2.0, 6.0))
			size = rng.randf_range(1.0, 3.2)
		else:
			p = Vector2(_lower_river_x(rng.randf_range(_pool_centre().y, -120.0)), 0.0)
			p.y = rng.randf_range(pc.y + 20.0, -120.0)
			p.x = _lower_river_x(p.y) + (rng.randf_range(10.0, 16.0) * (1.0 if rng.randf() < 0.5 else -1.0))
			size = rng.randf_range(0.8, 2.4)
		if _road_distance(p.x, p.y) < ROAD_FLAT + 2.0 + size:
			continue
		if absf(p.y - _falls_land_z()) < 4.0 and absf(p.x - FALLS_X) < FALLS_HALF_W:
			continue
		var y: float = _ground_at(p.x, p.y)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), Vector3(p.x, y - size * 0.25, p.y))
		xfs[rng.randi() % 3].append(xf)
		if _road_distance(p.x, p.y) < 30.0:
			colliders.append([xf.origin + Vector3(0, size * 0.2, 0), size * 0.85])
		placed += 1
	var root := Node3D.new()
	root.name = "FallsBoulders"
	parent.add_child(root)
	for k in xfs.keys():
		if xfs[k].is_empty():
			continue
		var mmi := _multimesh(meshes[k], xfs[k], "Boulders_%d" % k)
		mmi.material_override = rock_mat
		root.add_child(mmi)
	var body := StaticBody3D.new()
	# "Boulder" in the name: the AI's obstacle rays steer round them.
	body.name = "BoulderRocks"
	root.add_child(body)
	for c in colliders:
		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = c[1]
		cs.shape = sph
		cs.position = c[0]
		body.add_child(cs)
	print("  boulders: %d" % placed)


func _build_falls(level_scene: Node3D, rock_mat: Material) -> void:
	var root := Node3D.new()
	root.name = "Waterfall"
	level_scene.add_child(root)
	var slab := MeshInstance3D.new()
	slab.name = "FallsSlab"
	slab.mesh = _save_baked_resource(_falls_slab_mesh(), "falls_slab")
	slab.material_override = rock_mat
	root.add_child(slab)

	var streak := FastNoiseLite.new()
	streak.seed = 4418
	streak.frequency = 0.08
	streak.fractal_octaves = 3
	var streak_tex := NoiseTexture2D.new()
	streak_tex.seamless = true
	streak_tex.noise = streak
	streak_tex.width = 256
	streak_tex.height = 256
	var lip_z: float = _face_z() + FALLS_OVERHANG
	var t_end: float = _falls_land_t()
	for layer in [["Curtain", 0.0, 1.0, 0.0], ["Veil", 0.8, 1.16, 1.0]]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var cols := 24
		# Row profile as (z, y, v): the main curtain first runs along the river's surface over
		# the shelf and rolls over the brink, then falls on its arc to the pool.
		var profile: Array = []
		if layer[3] == 0.0:
			for b in [[-3.0, 0.03], [-1.6, 0.03], [-0.6, 0.0], [-0.15, -0.12]]:
				profile.append(Vector3(lip_z + b[0], FALLS_LIP_Y + b[1], 0.0))
		var rows := 30
		for ri in range(rows + 1):
			var tt: float = float(ri) / float(rows)
			var a: Vector2 = _falls_arc(tt * t_end)
			profile.append(Vector3(a.x + layer[1] * tt, a.y - 0.4 * sin(minf(tt * 8.0, 1.0) * PI * 0.5) * (1.0 - tt), maxf(tt, 0.004)))
		for ri in range(profile.size()):
			var pr: Vector3 = profile[ri]
			var tt: float = pr.z
			var spread: float = lerpf(1.0, layer[2], tt) * (1.0 + tt * 0.1)
			for ci in range(cols + 1):
				var u: float = float(ci) / float(cols)
				var xx: float = FALLS_X + lerpf(-FALLS_HALF_W, FALLS_HALF_W, u) * spread
				var bulge: float = sin(u * PI) * 0.8 * tt
				st.set_uv(Vector2(u, tt))
				st.set_normal(Vector3(0, 0.3, 1).normalized())
				st.add_vertex(Vector3(xx, pr.y, pr.x + bulge))
		for ri in range(profile.size() - 1):
			for ci in range(cols):
				var a0: int = ri * (cols + 1) + ci
				var b0: int = a0 + cols + 1
				st.add_index(a0)
				st.add_index(a0 + 1)
				st.add_index(b0)
				st.add_index(a0 + 1)
				st.add_index(b0 + 1)
				st.add_index(b0)
		var mat := ShaderMaterial.new()
		mat.shader = load("res://waterfall.gdshader")
		mat.set_shader_parameter("streak_noise", streak_tex)
		mat.set_shader_parameter("veil", layer[3])
		mat.set_shader_parameter("opacity", 0.94 if layer[3] == 0.0 else 0.5)
		mat.set_shader_parameter("body_color", Color(0.58, 0.63, 0.55))
		mat.set_shader_parameter("strand_count", 11.0)
		mat.set_shader_parameter("foam_color", Color(0.96, 0.97, 0.94))
		mat.render_priority = 1 if layer[3] > 0.0 else 0
		var mi := MeshInstance3D.new()
		mi.name = "Falls" + str(layer[0])
		mi.mesh = st.commit()
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)

	var impact := Vector3(FALLS_X, POOL_Y + 0.3, _falls_land_z() + 0.5)
	root.add_child(_mist_particles("FallsMist", impact, Vector3(FALLS_HALF_W * 1.05, 1.2, 2.0), 260, 8.0, 6.0,
			Vector3(0, 1, 0.8), Vector2(2.0, 6.5), Vector3(0, 0.25, 0.5), 0.42, AABB(Vector3(-45, -8, -40), Vector3(90, 60, 90))))
	root.add_child(_mist_particles("PoolFog", Vector3(_pool_centre().x, POOL_Y + 1.6, _pool_centre().y + 4.0), Vector3(POOL_R * 0.7, 0.4, POOL_R * 0.6),
			70, 11.0, 9.0, Vector3(0, 0.1, 1), Vector2(0.4, 1.4), Vector3(0, 0.05, 0.25), 0.22, AABB(Vector3(-40, -4, -40), Vector3(80, 20, 90))))
	# Spray drifting back under the shelf and over the road behind the falls.
	root.add_child(_mist_particles("RoadSpray", Vector3(FALLS_X, _falls_z_height() + 2.5, _falls_z() + 2.0), Vector3(FALLS_HALF_W + 6.0, 1.5, 6.0),
			60, 6.0, 5.0, Vector3(0, 0.3, -1), Vector2(0.3, 1.2), Vector3(0, 0.1, -0.15), 0.18, AABB(Vector3(-40, -6, -20), Vector3(80, 20, 40))))
	root.add_child(_spray_particles(impact))
	root.add_child(_rainbow(impact + Vector3(0.0, 6.0, 12.0), deg_to_rad(-25.0)))

	# The roar: the falls drown out everything near them.
	var roar: AudioStream = _roar_stream()
	for spot in [[impact + Vector3(0, 2, 4), 0.0, 34.0, 320.0], [Vector3(FALLS_X, FALLS_LIP_Y + 1.0, lip_z - 20.0), -8.0, 16.0, 140.0]]:
		var ap := AudioStreamPlayer3D.new()
		ap.name = "FallsRoar"
		ap.stream = roar
		ap.position = spot[0]
		ap.volume_db = spot[1]
		ap.unit_size = spot[2]
		ap.max_distance = spot[3]
		ap.autoplay = true
		ap.bus = &"SFX"
		ap.attenuation_filter_cutoff_hz = 6000.0
		root.add_child(ap)


# ======================================================================================
#  The Daraja
# ======================================================================================

## The bridge road's z, and the arc length at which it passes `x`.
func _bridge_z() -> float:
	return (_segs[SEG_BRIDGE]["p0"] as Vector2).y


func _bridge_s_at_x(x: float) -> float:
	var seg: Dictionary = _segs[SEG_BRIDGE]
	return float(seg["s0"]) + (x - (seg["p0"] as Vector2).x)


## Under the deck the banks are cut away to a little below it, so the deck never sits in the
## ground between its ends and the river's slot.
func _under_bridge_cap(x: float, z: float) -> float:
	var dz: float = absf(z - _bridge_z())
	var dx: float = absf(x - FALLS_X)
	if dz > BRIDGE_HALF_W + 4.0 or dx > BRIDGE_HALF_SPAN + 1.0:
		return 1e9
	var deck: float = _road_y(_bridge_s_at_x(x))
	# Down to the deck's underside in the middle, rising to meet the road at the deck's ends.
	var end_ramp: float = smoothstep(BRIDGE_HALF_SPAN - 4.0, BRIDGE_HALF_SPAN + 1.0, dx)
	var side: float = smoothstep(BRIDGE_HALF_W + 1.0, BRIDGE_HALF_W + 4.0, dz)
	return deck - lerpf(1.6, 0.0, maxf(end_ramp, side))


## A lashed timber pole: a tube from `a` to `b`, `r` radius, in bark colours.
func _pole(st: SurfaceTool, a: Vector3, b: Vector3, r: float, sides: int, col: Color) -> void:
	var t: Vector3 = (b - a).normalized()
	var u: Vector3 = t.cross(Vector3.UP if absf(t.y) < 0.9 else Vector3.RIGHT).normalized()
	var w: Vector3 = t.cross(u)
	var length: float = a.distance_to(b)
	for k in range(sides):
		var a0: float = TAU * float(k) / float(sides)
		var a1: float = TAU * float(k + 1) / float(sides)
		var d0: Vector3 = u * cos(a0) + w * sin(a0)
		var d1: Vector3 = u * cos(a1) + w * sin(a1)
		var p00: Vector3 = a + d0 * r
		var p01: Vector3 = a + d1 * r
		var p10: Vector3 = b + d0 * r * 0.9
		var p11: Vector3 = b + d1 * r * 0.9
		var quad := [[p00, p10, p11, Vector2(float(k), 0.0), Vector2(float(k), length), Vector2(float(k + 1), length)],
				[p00, p11, p01, Vector2(float(k), 0.0), Vector2(float(k + 1), length), Vector2(float(k + 1), 0.0)]]
		for tri in quad:
			var v0: Vector3 = tri[0]
			var v1: Vector3 = tri[1]
			var v2: Vector3 = tri[2]
			var out: Vector3 = (v0 + v1 + v2) / 3.0 - (a + b) * 0.5
			out -= t * out.dot(t)
			var uv0: Vector2 = tri[3]
			var uv1: Vector2 = tri[4]
			var uv2: Vector2 = tri[5]
			if (v2 - v0).cross(v1 - v0).dot(out) < 0.0:
				var tv: Vector3 = v1
				v1 = v2
				v2 = tv
				var tu: Vector2 = uv1
				uv1 = uv2
				uv2 = tu
			for e in [[v0, uv0], [v1, uv1], [v2, uv2]]:
				var v: Vector3 = e[0]
				st.set_color(col)
				st.set_normal(((v - a) - t * (v - a).dot(t)).normalized())
				st.set_uv((e[1] as Vector2) * Vector2(0.25, 0.5))
				st.add_vertex(v)


## A rope sagging between two points: `sag` metres at its middle.
func _rope_points(a: Vector3, b: Vector3, sag: float, n: int) -> Array:
	var pts: Array = []
	for i in range(n + 1):
		var t: float = float(i) / float(n)
		pts.append(a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0))
	return pts


func _rope(st: SurfaceTool, pts: Array, r: float, col: Color) -> void:
	for i in range(pts.size() - 1):
		_pole(st, pts[i], pts[i + 1], r, 5, col)


## The diamond mesh of the rope netting under the handrails, drawn into an alpha-tested texture.
func _net_texture() -> Texture2D:
	const SIZE := 128
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in range(SIZE):
		for x in range(SIZE):
			var u: float = float(x) / float(SIZE)
			var v: float = float(y) / float(SIZE)
			var d1: float = absf(fposmod(u + v, 0.25) - 0.125)
			var d2: float = absf(fposmod(u - v, 0.25) - 0.125)
			var a: float = 1.0 - smoothstep(0.008, 0.02, minf(0.125 - d1, 0.125 - d2))
			img.set_pixel(x, y, Color(0.55, 0.45, 0.30, a))
	img.generate_mipmaps()
	return _save_baked_resource(ImageTexture.create_from_image(img), "bridge_net")


func _build_bridge(level_scene: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Daraja"
	level_scene.add_child(root)
	var zb: float = _bridge_z()
	var x0: float = FALLS_X - BRIDGE_HALF_SPAN
	var x1: float = FALLS_X + BRIDGE_HALF_SPAN
	var hw: float = BRIDGE_HALF_W
	# --- Deck: planks across, a beam under each edge. Its ends run 3m onto the road and dip
	# into it, so the road rolls onto the planks without a lip.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var step := 0.5
	var xa: float = x0 - 3.0
	var n: int = int((x1 + 3.0 - xa) / step)
	var thick := 0.35
	var tops: Array = []
	for i in range(n + 1):
		var x: float = xa + float(i) * step
		var y: float = _road_y(_bridge_s_at_x(x)) + 0.03
		var past: float = maxf(x0 - x, x - x1)
		if past > 0.0:
			y -= past * 0.07
		tops.append(Vector3(x, y, zb))
	for i in range(n):
		var a: Vector3 = tops[i]
		var b: Vector3 = tops[i + 1]
		var corners: Array = [a + Vector3(0, 0, -hw), b + Vector3(0, 0, -hw), b + Vector3(0, 0, hw), a + Vector3(0, 0, hw)]
		# Top (faces up).
		var top_tris: Array = [[corners[0], corners[1], corners[2]], [corners[0], corners[2], corners[3]]]
		for tri in top_tris:
			var v0: Vector3 = tri[0]
			var v1: Vector3 = tri[1]
			var v2: Vector3 = tri[2]
			if (v2 - v0).cross(v1 - v0).y < 0.0:
				var tv: Vector3 = v1
				v1 = v2
				v2 = tv
			for v in [v0, v1, v2]:
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(v.x * 0.5, (v.z - zb) * 0.08))
				st.add_vertex(v)
			faces.append_array([v0, v1, v2])
		# Sides and bottom.
		for side in [-1.0, 1.0]:
			var ta: Vector3 = a + Vector3(0, 0, side * hw)
			var tb: Vector3 = b + Vector3(0, 0, side * hw)
			var quad: Array = [ta, tb, tb - Vector3(0, thick, 0), ta - Vector3(0, thick, 0)]
			for tri in [[quad[0], quad[1], quad[2]], [quad[0], quad[2], quad[3]]]:
				var v0: Vector3 = tri[0]
				var v1: Vector3 = tri[1]
				var v2: Vector3 = tri[2]
				if (v2 - v0).cross(v1 - v0).z * side < 0.0:
					var tv: Vector3 = v1
					v1 = v2
					v2 = tv
				for v in [v0, v1, v2]:
					st.set_normal(Vector3(0, 0, side))
					st.set_uv(Vector2(v.x * 0.5, v.y * 0.5))
					st.add_vertex(v)
		var bq: Array = [a + Vector3(0, -thick, -hw), b + Vector3(0, -thick, -hw), b + Vector3(0, -thick, hw), a + Vector3(0, -thick, hw)]
		for tri in [[bq[0], bq[1], bq[2]], [bq[0], bq[2], bq[3]]]:
			var v0: Vector3 = tri[0]
			var v1: Vector3 = tri[1]
			var v2: Vector3 = tri[2]
			if (v2 - v0).cross(v1 - v0).y > 0.0:
				var tv: Vector3 = v1
				v1 = v2
				v2 = tv
			for v in [v0, v1, v2]:
				st.set_normal(Vector3.DOWN)
				st.set_uv(Vector2(v.x * 0.5, v.z * 0.08))
				st.add_vertex(v)
	st.generate_tangents()
	var deck_mesh: ArrayMesh = st.commit()
	var deck_mat := StandardMaterial3D.new()
	deck_mat.albedo_texture = load("res://materials/wood_planks.png")
	deck_mat.normal_enabled = true
	deck_mat.normal_texture = load("res://materials/wood_planks_normal.png")
	deck_mat.roughness_texture = load("res://materials/wood_planks_roughness.png")
	deck_mat.albedo_color = Color(0.95, 0.82, 0.66)
	var deck_body := StaticBody3D.new()
	# "Bridge" in the name: PlayerCart counts it as track.
	deck_body.name = "DarajaBridgeDeck"
	root.add_child(deck_body)
	deck_body.set_meta(&"ice_grip", 1.0)
	deck_body.set_meta(&"dry_grip", 1.0)
	var dmi := MeshInstance3D.new()
	dmi.name = "DeckMesh"
	dmi.mesh = _save_baked_resource(deck_mesh, "bridge_deck")
	dmi.material_override = deck_mat
	deck_body.add_child(dmi)
	_add_faces_shape(deck_body, faces, "DeckShape", "bridge_deck_collision")

	# --- Timber: towers at both ends, the beams under the deck, posts along the rails.
	var wood := Color(0.42, 0.32, 0.22)
	var tw := SurfaceTool.new()
	tw.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rope_st := SurfaceTool.new()
	rope_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rope_col := Color(0.66, 0.55, 0.38)
	var tower_h := 8.5
	var tops_l: Array = []
	var tops_r: Array = []
	var colliders: Array = []
	for end_x in [x0, x1]:
		var out: float = -1.0 if end_x == x0 else 1.0
		var base_y: float = _road_y(_bridge_s_at_x(end_x))
		var tx: float = end_x - out * 0.6
		for side in [-1.0, 1.0]:
			var foot := Vector3(tx, base_y - 1.5, zb + side * (hw + 0.9))
			var head := Vector3(tx, base_y + tower_h, zb + side * (hw + 0.6))
			_pole(tw, foot, head, 0.32, 8, wood)
			colliders.append([foot.lerp(head, 0.5), 0.36, tower_h + 1.5])
			if side < 0.0:
				tops_l.append(head)
			else:
				tops_r.append(head)
		# The crossbeam over the road, and a lashed brace under it.
		var cb_y: float = base_y + tower_h - 0.6
		_pole(tw, Vector3(tx, cb_y, zb - hw - 1.4), Vector3(tx, cb_y, zb + hw + 1.4), 0.26, 7, wood)
		_pole(tw, Vector3(tx, cb_y - 1.3, zb - hw - 0.7), Vector3(tx, cb_y - 1.3, zb + hw + 0.7), 0.18, 6, wood)
		# Backstays: the main cables run on down to anchors in the ground behind the towers.
		for side in [-1.0, 1.0]:
			var head2 := Vector3(tx, base_y + tower_h, zb + side * (hw + 0.6))
			var anchor := Vector3(end_x + out * 13.0, _ground_at(end_x + out * 13.0, zb + side * (hw + 2.0)) - 0.2, zb + side * (hw + 2.0))
			_rope(rope_st, _rope_points(head2, anchor, 0.4, 8), 0.12, rope_col)
			_pole(tw, anchor + Vector3(0, -1.0, 0), anchor + Vector3(-out * 0.4, 1.4, 0), 0.3, 6, wood)
	# Main cables, tower to tower, hanging to a couple of metres over the deck's middle.
	var mid_deck: float = _road_y(_bridge_s_at_x(FALLS_X))
	var cable_l: Array = _rope_points(tops_l[0], tops_l[1], (tops_l[0].y - mid_deck) - 2.2, 40)
	var cable_r: Array = _rope_points(tops_r[0], tops_r[1], (tops_r[0].y - mid_deck) - 2.2, 40)
	_rope(rope_st, cable_l, 0.14, rope_col)
	_rope(rope_st, cable_r, 0.14, rope_col)
	# Hangers from the cables down to the deck's edge, posts and two handrail ropes along it.
	var x := x0 + 2.0
	while x < x1 - 1.0:
		var dy: float = _road_y(_bridge_s_at_x(x)) + 0.03
		for side in [-1.0, 1.0]:
			var cable: Array = cable_l if side < 0.0 else cable_r
			var f: float = (x - x0 + 0.6) / (x1 - x0 - 1.2) * float(cable.size() - 1)
			var ci: int = clampi(int(f), 0, cable.size() - 2)
			var cp: Vector3 = (cable[ci] as Vector3).lerp(cable[ci + 1], f - float(ci))
			var edge := Vector3(x, dy + 1.15, zb + side * (hw + 0.1))
			if cp.y > edge.y + 0.3:
				_rope(rope_st, [cp, edge], 0.04, rope_col)
		x += 2.0
	x = x0
	while x <= x1 + 0.01:
		var dy2: float = _road_y(_bridge_s_at_x(x)) + 0.03
		for side in [-1.0, 1.0]:
			_pole(tw, Vector3(x, dy2 - 0.4, zb + side * (hw + 0.12)), Vector3(x, dy2 + 1.25, zb + side * (hw + 0.12)), 0.09, 6, wood)
		x += 4.0
	for side in [-1.0, 1.0]:
		for hgt in [0.55, 1.15]:
			var rail: Array = []
			var xr := x0
			while xr <= x1 + 0.01:
				rail.append(Vector3(xr, _road_y(_bridge_s_at_x(xr)) + 0.03 + hgt, zb + side * (hw + 0.12)))
				xr += 2.0
			_rope(rope_st, rail, 0.06, rope_col)
	# Logs under the deck: two stringers and a crossbeam every 1.5m.
	for side in [-1.0, 1.0]:
		var xs := x0 - 1.0
		while xs < x1 + 1.0:
			var xe: float = minf(xs + 2.0, x1 + 1.0)
			_pole(tw, Vector3(xs, _road_y(_bridge_s_at_x(xs)) - 0.5, zb + side * (hw - 0.6)),
					Vector3(xe, _road_y(_bridge_s_at_x(xe)) - 0.5, zb + side * (hw - 0.6)), 0.22, 6, wood)
			xs = xe
	var xc := x0
	while xc <= x1:
		var yc: float = _road_y(_bridge_s_at_x(xc)) - 0.45
		_pole(tw, Vector3(xc, yc, zb - hw - 0.3), Vector3(xc, yc, zb + hw + 0.3), 0.14, 5, wood)
		xc += 1.5
	var timber_mat := StandardMaterial3D.new()
	timber_mat.vertex_color_use_as_albedo = true
	timber_mat.vertex_color_is_srgb = true
	timber_mat.albedo_texture = load("res://materials/wood_planks.png")
	timber_mat.roughness = 0.85
	var tmi := MeshInstance3D.new()
	tmi.name = "Timber"
	tw.generate_tangents()
	tmi.mesh = _save_baked_resource(tw.commit(), "bridge_timber")
	tmi.material_override = timber_mat
	root.add_child(tmi)
	var rope_mat := StandardMaterial3D.new()
	rope_mat.vertex_color_use_as_albedo = true
	rope_mat.vertex_color_is_srgb = true
	rope_mat.roughness = 0.95
	var rmi := MeshInstance3D.new()
	rmi.name = "Ropes"
	rmi.mesh = _save_baked_resource(rope_st.commit(), "bridge_ropes")
	rmi.material_override = rope_mat
	root.add_child(rmi)
	# Netting from the deck's edge up to the handrail.
	var net := SurfaceTool.new()
	net.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		var xn := x0
		while xn < x1 - 0.01:
			var xe2: float = minf(xn + 1.0, x1)
			var ya: float = _road_y(_bridge_s_at_x(xn)) + 0.03
			var yb: float = _road_y(_bridge_s_at_x(xe2)) + 0.03
			var zz: float = zb + side * (hw + 0.1)
			var q: Array = [Vector3(xn, ya, zz), Vector3(xe2, yb, zz), Vector3(xe2, yb + 1.15, zz), Vector3(xn, ya + 1.15, zz)]
			var uvq: Array = [Vector2(xn * 0.5, 0.0), Vector2(xe2 * 0.5, 0.0), Vector2(xe2 * 0.5, 0.575), Vector2(xn * 0.5, 0.575)]
			for idx in [0, 1, 2, 0, 2, 3]:
				net.set_normal(Vector3(0, 0, side))
				net.set_uv(uvq[idx])
				net.add_vertex(q[idx])
			xn = xe2
	var net_mat := StandardMaterial3D.new()
	net_mat.albedo_texture = _net_texture()
	net_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	net_mat.alpha_scissor_threshold = 0.5
	net_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	net_mat.roughness = 0.95
	var nmi := MeshInstance3D.new()
	nmi.name = "Netting"
	nmi.mesh = net.commit()
	nmi.material_override = net_mat
	nmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(nmi)
	# Walls behind the netting, so a cart that slides wide stays on the bridge. They flare out
	# at the bridge's ends, so a cart running the road's edge meets them at a glance.
	var rail_body := StaticBody3D.new()
	rail_body.name = "DarajaRailing"
	root.add_child(rail_body)
	for side in [-1.0, 1.0]:
		var pts_r: Array = [Vector3(x0 - 4.0, 0.0, zb + side * (hw + 2.4)), Vector3(x0 + 1.0, 0.0, zb + side * (hw + 0.25))]
		var xw := x0 + 3.0
		while xw < x1 - 1.0:
			pts_r.append(Vector3(xw, 0.0, zb + side * (hw + 0.25)))
			xw += 3.0
		pts_r.append(Vector3(x1 - 1.0, 0.0, zb + side * (hw + 0.25)))
		pts_r.append(Vector3(x1 + 4.0, 0.0, zb + side * (hw + 2.4)))
		for i in range(pts_r.size() - 1):
			var a: Vector3 = pts_r[i]
			var b: Vector3 = pts_r[i + 1]
			var ya2: float = _road_y(_bridge_s_at_x(clampf(a.x, x0 - 3.0, x1 + 3.0)))
			var yb2: float = _road_y(_bridge_s_at_x(clampf(b.x, x0 - 3.0, x1 + 3.0)))
			a.y = ya2
			b.y = yb2
			var mid: Vector3 = (a + b) * 0.5
			var length: float = Vector2(b.x - a.x, b.z - a.z).length()
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(length + 0.3, 1.5, 0.3)
			cs.shape = box
			var ang: float = atan2(-(b.z - a.z), b.x - a.x)
			cs.transform = Transform3D(Basis(Vector3.UP, ang), mid + Vector3(0, 0.7, 0))
			rail_body.add_child(cs)
	# The towers' posts.
	var post_body := StaticBody3D.new()
	post_body.name = "DarajaTowers"
	root.add_child(post_body)
	for c in colliders:
		var cs2 := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = c[1]
		cyl.height = c[2]
		cs2.shape = cyl
		cs2.position = c[0]
		post_body.add_child(cs2)
	# The name board on the west tower, for the field crossing eastward.
	for end_x2 in [x0]:
		var by: float = _road_y(_bridge_s_at_x(end_x2)) + tower_h - 1.95
		var board := MeshInstance3D.new()
		board.name = "NameBoard"
		var bm := BoxMesh.new()
		bm.size = Vector3(0.12, 1.1, 6.4)
		board.mesh = bm
		var bmat := StandardMaterial3D.new()
		bmat.albedo_texture = load("res://materials/wood_planks.png")
		bmat.albedo_color = Color(0.7, 0.55, 0.38)
		board.material_override = bmat
		board.position = Vector3(end_x2 - 0.9, by, zb)
		root.add_child(board)
		var label := Label3D.new()
		label.text = "DARAJA"
		label.font_size = 128
		label.pixel_size = 0.008
		label.outline_size = 18
		label.modulate = Color(0.98, 0.92, 0.70)
		label.outline_modulate = Color(0.20, 0.12, 0.05)
		label.position = Vector3(end_x2 - 0.98, by, zb)
		label.rotation.y = -PI * 0.5
		root.add_child(label)


# ======================================================================================
#  The rainforest
# ======================================================================================

## Canopy trees, in metres: height, trunk radius at the foot, crown radius, the crown's
## underside, how far the buttresses run out, limbs and leaf clusters. 0 an emergent giant, 1 a
## canopy tree, 2 a smaller understory tree with a rounder crown.
const TREE_SHAPES := [
	{"h": 36.0, "r": 1.05, "cr": 12.5, "under": 25.0, "but": 4.2, "limbs": 6, "clusters": 15},
	{"h": 27.0, "r": 0.8, "cr": 9.5, "under": 17.0, "but": 3.0, "limbs": 5, "clusters": 12},
	{"h": 15.0, "r": 0.45, "cr": 6.0, "under": 7.5, "but": 1.2, "limbs": 4, "clusters": 9},
]
## Leaf atlas cells (2 x 2): broadleaf spray, fern frond, palm frond, banana leaf.
const CELL_SPRAY := 0
const CELL_FERN := 1
const CELL_PALM := 2
const CELL_BANANA := 3
## The canopy crossfades from the detailed tree to the stand-in round TREE_NEAR.
const TREE_NEAR := 115.0
const TREE_FADE := 40.0
const TREE_FADE_JITTER := 12.0
const FOREST_CELL := 80.0
## Trunks within this of a road centreline get a collider (all of them on the Nyoka's hillside).
const TRUNK_COLLIDE_REACH := 45.0
## Bark tint where moss covers it.
const MOSS_TINT := Color(0.42, 0.62, 0.22)

var _leaf_atlas: Texture2D


## A float RGB + alpha canvas for drawing the leaf atlas (members, so drawing edits in place).
class LeafCanvas:
	var w := 0
	var rgb := PackedFloat32Array()
	var alpha := PackedFloat32Array()

	func _init(size: int, bg: Color) -> void:
		w = size
		rgb.resize(size * size * 3)
		alpha.resize(size * size)
		for i in range(size * size):
			rgb[i * 3] = bg.r
			rgb[i * 3 + 1] = bg.g
			rgb[i * 3 + 2] = bg.b

	func _put(i: int, a: float, col: Color) -> void:
		var k: float = a if alpha[i] > 0.0 else 1.0
		rgb[i * 3] = lerpf(rgb[i * 3], col.r, k)
		rgb[i * 3 + 1] = lerpf(rgb[i * 3 + 1], col.g, k)
		rgb[i * 3 + 2] = lerpf(rgb[i * 3 + 2], col.b, k)
		alpha[i] = maxf(alpha[i], a)

	## An antialiased dot.
	func dot(c: Vector2, r: float, col: Color) -> void:
		var x0: int = maxi(0, int(c.x - r - 1.0))
		var x1: int = mini(w - 1, int(c.x + r + 1.0))
		var y0: int = maxi(0, int(c.y - r - 1.0))
		var y1: int = mini(w - 1, int(c.y + r + 1.0))
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var a: float = clampf(r + 0.5 - Vector2(x + 0.5, y + 0.5).distance_to(c), 0.0, 1.0)
				if a > 0.0:
					_put(y * w + x, a, col)

	## A stroke of dots from `a` to `b`, `r` tapering to `r2`.
	func line(a: Vector2, b: Vector2, r: float, r2: float, col: Color) -> void:
		var n: int = maxi(1, int(a.distance_to(b) / 0.7))
		for k in range(n + 1):
			var t: float = float(k) / float(n)
			dot(a.lerp(b, t), lerpf(r, r2, t), col)

	## A leaf from `base` along `dir`: pointed at both ends, widest a third of the way up, lighter
	## along its midrib and toward its tip. `tears` cuts it into strips across (a banana leaf).
	func leaf(base: Vector2, dir: Vector2, length: float, width: float, col: Color, rib: Color, tears: float = 0.0, seed: int = 0) -> void:
		var d: Vector2 = dir.normalized()
		var perp := Vector2(-d.y, d.x)
		var ends: Array = [base, base + d * length, base + perp * width, base - perp * width, base + d * length * 0.4 + perp * width, base + d * length * 0.4 - perp * width]
		var lo := Vector2(1e9, 1e9)
		var hi := Vector2(-1e9, -1e9)
		for e in ends:
			lo = Vector2(minf(lo.x, e.x), minf(lo.y, e.y))
			hi = Vector2(maxf(hi.x, e.x), maxf(hi.y, e.y))
		for y in range(maxi(0, int(lo.y) - 1), mini(w - 1, int(hi.y) + 2)):
			for x in range(maxi(0, int(lo.x) - 1), mini(w - 1, int(hi.x) + 2)):
				var q := Vector2(x + 0.5, y + 0.5) - base
				var along: float = q.dot(d) / length
				if along < 0.0 or along > 1.0:
					continue
				var across: float = q.dot(perp)
				var half: float = width * pow(sin(PI * clampf(pow(along, 0.75), 0.0, 1.0)), 0.7)
				var a: float = clampf(half - absf(across) + 0.5, 0.0, 1.0)
				if a <= 0.0:
					continue
				if tears > 0.0:
					# Torn into strips running out from the midrib, more toward the edges.
					var band: float = fposmod(along * length / 9.0 + float(seed) * 0.37 + sin(along * 23.0 + float(seed)) * 0.3, 1.0)
					var edge: float = absf(across) / maxf(half, 0.001)
					if band < tears * smoothstep(0.25, 0.9, edge) and edge > 0.2:
						continue
				var c: Color = col.lerp(col.lightened(0.18), along * 0.6)
				c = c.darkened(0.25 * (1.0 - absf(across) / maxf(half, 0.001)) * 0.3)
				var r: float = clampf(1.2 - absf(across) / maxf(width * 0.06, 0.6), 0.0, 1.0)
				c = c.lerp(rib, r * 0.6)
				_put(y * w + x, a, c)


## Mipmapped RGBA8 image of the canvas whose every mip keeps level 0's coverage at alpha
## `cutoff` (each level's alpha scaled up until as many texels pass the test), so foliage does
## not thin out to nothing with distance.
func _coverage_mipmaps(cv: LeafCanvas, cutoff: float) -> Image:
	var size: int = cv.w
	var rgb: PackedFloat32Array = cv.rgb
	var alpha: PackedFloat32Array = cv.alpha
	var target := 0.0
	for a in alpha:
		if a >= cutoff:
			target += 1.0
	target /= float(alpha.size())
	var data := PackedByteArray()
	var scale := 1.0
	while true:
		var n: int = size * size
		var level := PackedByteArray()
		level.resize(n * 4)
		for i in range(n):
			level[i * 4] = int(clampf(rgb[i * 3], 0.0, 1.0) * 255.0 + 0.5)
			level[i * 4 + 1] = int(clampf(rgb[i * 3 + 1], 0.0, 1.0) * 255.0 + 0.5)
			level[i * 4 + 2] = int(clampf(rgb[i * 3 + 2], 0.0, 1.0) * 255.0 + 0.5)
			level[i * 4 + 3] = int(clampf(alpha[i] * scale, 0.0, 1.0) * 255.0 + 0.5)
		data.append_array(level)
		if size == 1:
			break
		var half: int = size / 2
		var rgb2 := PackedFloat32Array()
		rgb2.resize(half * half * 3)
		var alpha2 := PackedFloat32Array()
		alpha2.resize(half * half)
		for y in range(half):
			for x in range(half):
				var sa := 0.0
				var sr := 0.0
				var sg := 0.0
				var sb := 0.0
				for dy in range(2):
					for dx in range(2):
						var i2: int = (y * 2 + dy) * size + x * 2 + dx
						var wgt: float = alpha[i2] + 0.001
						sa += alpha[i2]
						sr += rgb[i2 * 3] * wgt
						sg += rgb[i2 * 3 + 1] * wgt
						sb += rgb[i2 * 3 + 2] * wgt
				var j: int = y * half + x
				var wsum: float = sa + 0.004
				alpha2[j] = sa * 0.25
				rgb2[j * 3] = sr / wsum
				rgb2[j * 3 + 1] = sg / wsum
				rgb2[j * 3 + 2] = sb / wsum
		size = half
		rgb = rgb2
		alpha = alpha2
		var lo := 1.0
		var hi := 16.0
		for it in range(14):
			var mid: float = (lo + hi) * 0.5
			var covered := 0
			var need: float = cutoff / mid
			for a2 in alpha:
				if a2 >= need:
					covered += 1
			if float(covered) / float(alpha.size()) < target:
				lo = mid
			else:
				hi = mid
		scale = hi
	return Image.create_from_data(cv.w, cv.w, true, Image.FORMAT_RGBA8, data)


## The leaf atlas: a spray of broad leaves on twigs (the canopy and the shrubs), a fern frond, a
## palm frond and a torn banana leaf, each drawn upright in its own cell with its base at the
## cell's bottom edge.
func _leaf_atlas_texture() -> Texture2D:
	if _leaf_atlas:
		return _leaf_atlas
	const W := 1024
	const C := 512
	var cv := LeafCanvas.new(W, Color(0.10, 0.20, 0.05))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7710
	# --- 0: broadleaf spray, a rough disc of twigs and glossy leaves.
	var centre := Vector2(C * 0.5, C * 0.5)
	for t in range(11):
		var a: float = TAU * float(t) / 11.0 + rng.randf_range(-0.25, 0.25)
		var p: Vector2 = centre + Vector2(cos(a), sin(a)) * rng.randf_range(10.0, 40.0)
		var dir := Vector2(cos(a), sin(a))
		var length: float = rng.randf_range(150.0, 205.0)
		var travelled := 0.0
		var side := 1.0
		while travelled < length:
			var seg: float = rng.randf_range(16.0, 24.0)
			dir = dir.rotated(rng.randf_range(-0.18, 0.18))
			var q: Vector2 = p + dir * seg
			if q.distance_to(centre) > C * 0.47:
				break
			cv.line(p, q, 1.6, 1.2, Color(0.24, 0.18, 0.11))
			side = -side
			var la: float = dir.angle() + side * rng.randf_range(0.5, 1.1)
			var ll: float = rng.randf_range(34.0, 58.0) * (1.0 - travelled / length * 0.35)
			var g: Color = Color(0.11, 0.24, 0.06).lerp(Color(0.20, 0.34, 0.09), rng.randf()).lerp(Color(0.10, 0.22, 0.10), rng.randf() * 0.5)
			cv.leaf(q, Vector2(cos(la), sin(la)), ll, ll * rng.randf_range(0.2, 0.28), g, g.lightened(0.25))
			p = q
			travelled += seg
		# A leaf at the tip, along the twig.
		var g2: Color = Color(0.16, 0.32, 0.08).lerp(Color(0.24, 0.40, 0.11), rng.randf())
		cv.leaf(p, dir, rng.randf_range(36.0, 50.0), 11.0, g2, g2.lightened(0.25))
	# --- 1: fern frond: a rachis up the cell, pinnae either side shortening toward the tip.
	var f_base := Vector2(C * 1.5, C - 6.0)
	var f_tip := Vector2(C * 1.5 + 18.0, 14.0)
	var f_col := Color(0.18, 0.36, 0.08)
	var steps := 34
	for k in range(steps):
		var t: float = float(k) / float(steps)
		var at: Vector2 = f_base.lerp(f_tip, t) + Vector2(sin(t * PI) * 14.0, 0.0)
		var nxt: Vector2 = f_base.lerp(f_tip, t + 1.0 / float(steps)) + Vector2(sin((t + 1.0 / float(steps)) * PI) * 14.0, 0.0)
		cv.line(at, nxt, 2.4 * (1.0 - t) + 0.8, 2.4 * (1.0 - t) + 0.6, Color(0.30, 0.34, 0.14))
		if t < 0.06:
			continue
		var pl: float = 150.0 * sin(PI * clampf((t - 0.04) * 1.05, 0.0, 1.0)) * (1.0 - t * 0.35) + 10.0
		for side2 in [-1.0, 1.0]:
			var pd := Vector2(side2, -0.55).normalized()
			var c2: Color = f_col.lerp(Color(0.26, 0.44, 0.12), rng.randf() * 0.6)
			cv.leaf(at, pd, pl, pl * 0.11, c2, c2.lightened(0.15))
	# --- 2: palm frond: long narrow leaflets drooping off a stout rachis.
	var p_base := Vector2(C * 0.5, 2.0 * C - 6.0)
	var p_tip := Vector2(C * 0.5 - 10.0, C + 10.0)
	for k in range(40):
		var t: float = float(k) / 40.0
		var at2: Vector2 = p_base.lerp(p_tip, t)
		var nxt2: Vector2 = p_base.lerp(p_tip, t + 0.025)
		cv.line(at2, nxt2, 3.2 * (1.0 - t) + 1.0, 3.2 * (1.0 - t) + 0.8, Color(0.36, 0.38, 0.18))
		if t < 0.08:
			continue
		var pl2: float = 210.0 * sin(PI * clampf(t * 0.95, 0.0, 1.0)) * (1.0 - t * 0.3) + 16.0
		for side3 in [-1.0, 1.0]:
			var droop := Vector2(side3, rng.randf_range(-0.05, 0.25)).normalized()
			var c3: Color = Color(0.16, 0.32, 0.07).lerp(Color(0.26, 0.40, 0.11), rng.randf())
			cv.leaf(at2, droop, pl2, 7.0, c3, c3.lightened(0.2))
	# --- 3: banana leaf: one great paddle, torn into strips at the edges.
	var b_base := Vector2(C * 1.5, 2.0 * C - 4.0)
	cv.line(b_base, b_base + Vector2(0, -40.0), 6.0, 5.0, Color(0.40, 0.48, 0.20))
	cv.leaf(b_base + Vector2(0, -30.0), Vector2(0.02, -1.0), C - 40.0, 118.0, Color(0.20, 0.40, 0.09), Color(0.52, 0.60, 0.28), 0.42, 3)
	var img := _coverage_mipmaps(cv, 0.5)
	_leaf_atlas = _save_baked_resource(ImageTexture.create_from_image(img), "leaf_atlas")
	return _leaf_atlas


func _cell_uv(cell: int) -> Rect2:
	return Rect2(float(cell % 2) * 0.5, float(cell / 2) * 0.5, 0.5, 0.5)


## Appends a bark tube along `pts` (a radius per point) to `st`, as `sides` faces round plus a
## seam column so the UVs can wrap (tree_bark.gdshader). Colour `col`, its alpha the shade.
## Returns the next free vertex index.
func _bark_tube(st: SurfaceTool, base: int, pts: Array, radii: Array, sides: int, col: Color, cell: float, wobble: float, noise: FastNoiseLite, shade: Vector2, moss_h: float = 0.0) -> int:
	var n: int = pts.size()
	var period: float = maxf(3.0, roundf(TAU * float(radii[0]) / cell))
	var grid: Array = []
	var vs := PackedFloat32Array()
	var along := 0.0
	var t0: Vector3 = ((pts[1] as Vector3) - (pts[0] as Vector3)).normalized()
	var u: Vector3 = t0.cross(Vector3.UP if absf(t0.y) < 0.95 else Vector3.RIGHT).normalized()
	for k in range(n):
		var t: Vector3 = ((pts[mini(k + 1, n - 1)] as Vector3) - (pts[maxi(k - 1, 0)] as Vector3)).normalized()
		u = (u - t * u.dot(t)).normalized()
		var w: Vector3 = t.cross(u)
		if k > 0:
			along += (pts[k] as Vector3).distance_to(pts[k - 1])
		vs.append(along / cell)
		var ring := PackedVector3Array()
		for s in range(sides + 1):
			var ang: float = TAU * float(s % sides) / float(sides)
			var r: float = radii[k]
			if wobble > 0.0:
				r *= 1.0 + noise.get_noise_3d(cos(ang) * 2.0, sin(ang) * 2.0, along * 0.35) * wobble
			ring.append((pts[k] as Vector3) + (u * cos(ang) + w * sin(ang)) * r)
		grid.append(ring)
	for k in range(n):
		var c: Vector3 = pts[k]
		var a_sh: float = 1.0 - 0.55 * smoothstep(shade.x, shade.y, c.y)
		# Moss climbs the foot of the trunk, thickest on the ground.
		var kc: Color = col.lerp(MOSS_TINT, (1.0 - smoothstep(0.0, moss_h, c.y)) * 0.75) if moss_h > 0.0 else col
		for s in range(sides + 1):
			var si: int = s % sides
			var around: Vector3 = (grid[k][(si + 1) % sides] as Vector3) - (grid[k][(si - 1 + sides) % sides] as Vector3)
			var length_dir: Vector3 = (grid[mini(k + 1, n - 1)][si] as Vector3) - (grid[maxi(k - 1, 0)][si] as Vector3)
			var nrm: Vector3 = around.cross(length_dir).normalized()
			var p: Vector3 = grid[k][s]
			if nrm.dot(p - c) < 0.0:
				nrm = -nrm
			st.set_normal(nrm)
			st.set_color(Color(kc.r, kc.g, kc.b, a_sh))
			st.set_uv(Vector2(float(s) / float(sides) * period, vs[k]))
			st.set_uv2(Vector2(period, 0.0))
			st.add_vertex(p)
	# Front faces outward: clockwise, face normal (c - a) x (b - a).
	var p0: Vector3 = grid[0][0]
	var p1: Vector3 = grid[0][1]
	var p2: Vector3 = grid[1][1]
	var flip: bool = (p2 - p0).cross(p1 - p0).dot(p0 - (pts[0] as Vector3)) < 0.0
	for k in range(n - 1):
		for s in range(sides):
			var a: int = base + k * (sides + 1) + s
			var b: int = a + 1
			var c2: int = a + sides + 2
			var d: int = a + sides + 1
			if flip:
				st.add_index(a)
				st.add_index(c2)
				st.add_index(b)
				st.add_index(a)
				st.add_index(d)
				st.add_index(c2)
			else:
				st.add_index(a)
				st.add_index(b)
				st.add_index(c2)
				st.add_index(a)
				st.add_index(c2)
				st.add_index(d)
	return base + n * (sides + 1)


## The buttress roots of a rainforest giant: thin fins of wood flaring from the trunk to the
## ground, each a slab with a concave outer edge. Returns the next free vertex index.
func _buttresses(st: SurfaceTool, base: int, r0: float, reach: float, count: int, rng: RandomNumberGenerator, col: Color) -> int:
	var n := 6
	for f in range(count):
		var a: float = TAU * float(f) / float(count) + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(a), 0.0, sin(a))
		var side := Vector3(-out.z, 0.0, out.x)
		var height: float = reach * rng.randf_range(1.0, 1.5)
		var far: float = r0 + reach * rng.randf_range(0.75, 1.1)
		var thick: float = r0 * 0.22
		# The fin's outer edge: from high on the trunk down to the ground well out, sagging inward.
		var edge: Array = []
		for k in range(n + 1):
			var t: float = float(k) / float(n)
			var d: float = lerpf(r0 * 0.8, far, t)
			var y: float = height * pow(1.0 - t, 1.6) - 0.6 * t
			edge.append(out * d + Vector3(0, y, 0))
		var inner_top: Vector3 = out * r0 * 0.6 + Vector3(0, height, 0)
		var inner_foot: Vector3 = out * r0 * 0.6 + Vector3(0, -0.8, 0)
		for sgn in [-1.0, 1.0]:
			var off: Vector3 = side * thick * sgn
			for k in range(n):
				var t0: float = float(k) / float(n)
				var t1: float = float(k + 1) / float(n)
				var e0: Vector3 = (edge[k] as Vector3) + off * (1.0 - t0 * 0.7)
				var e1: Vector3 = (edge[k + 1] as Vector3) + off * (1.0 - t1 * 0.7)
				var i0: Vector3 = inner_top.lerp(inner_foot, t0) + off * 0.6
				var i1: Vector3 = inner_top.lerp(inner_foot, t1) + off * 0.6
				var quad: Array = [i0, e0, e1, i1]
				var tris: Array = [[quad[0], quad[1], quad[2]], [quad[0], quad[2], quad[3]]]
				for tri in tris:
					var v0: Vector3 = tri[0]
					var v1: Vector3 = tri[1]
					var v2: Vector3 = tri[2]
					var hint: Vector3 = side * sgn
					if (v2 - v0).cross(v1 - v0).dot(hint) < 0.0:
						var tv: Vector3 = v1
						v1 = v2
						v2 = tv
					for v in [v0, v1, v2]:
						st.set_normal((hint + out * 0.3).normalized())
						st.set_color(Color(col.r, col.g, col.b, 0.85))
						st.set_uv(Vector2(v.dot(out) * 2.0, v.y * 2.0))
						st.set_uv2(Vector2(1000.0, 0.0))
						st.add_vertex(v)
						base += 1
		# The fin's top edge, so it doesn't look paper-thin from above.
		for k in range(n):
			var ea: Vector3 = edge[k]
			var eb: Vector3 = edge[k + 1]
			var q: Array = [ea - side * thick, ea + side * thick, eb + side * thick * 0.3, eb - side * thick * 0.3]
			for tri in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
				var v0: Vector3 = tri[0]
				var v1: Vector3 = tri[1]
				var v2: Vector3 = tri[2]
				var up_hint: Vector3 = (Vector3.UP + out).normalized()
				if (v2 - v0).cross(v1 - v0).dot(up_hint) < 0.0:
					var tv2: Vector3 = v1
					v1 = v2
					v2 = tv2
				for v in [v0, v1, v2]:
					st.set_normal(up_hint)
					st.set_color(Color(col.r, col.g, col.b, 0.85))
					st.set_uv(Vector2(v.dot(side) * 2.0, v.dot(out) * 2.0))
					st.set_uv2(Vector2(1000.0, 0.0))
					st.add_vertex(v)
					base += 1
	return base


## Leaf cards filling a cluster: `n` cards `size` metres across round `c` (radius `r`), facing
## out from the crown's middle `crown_c`; the colour's alpha the shade inside the crown.
func _cluster_cards(st: SurfaceTool, base: int, c: Vector3, r: float, n: int, size: Vector2, crown_c: Vector3, crown_r: float,
		under: float, top: float, cell: int, tint: Color, rng: RandomNumberGenerator) -> int:
	var uvr: Rect2 = _cell_uv(cell)
	for k in range(n):
		var dir := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.4, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
		var p: Vector3 = c + dir * r * sqrt(rng.randf()) * 0.85
		var out: Vector3 = (p - crown_c)
		out.y *= 0.6
		out = (out.normalized() + Vector3.UP * 0.4 + dir * 0.3).normalized()
		var nrm: Vector3 = out if rng.randf() < 0.6 else Vector3(rng.randf_range(-1, 1), rng.randf_range(0.2, 1.0), rng.randf_range(-1, 1)).normalized()
		var t1: Vector3 = nrm.cross(Vector3.RIGHT if absf(nrm.x) < 0.9 else Vector3.FORWARD).normalized()
		t1 = t1.rotated(nrm, rng.randf() * TAU)
		var t2: Vector3 = nrm.cross(t1)
		var h: float = rng.randf_range(size.x, size.y) * 0.5
		var corners: Array = [p - t1 * h - t2 * h, p + t1 * h - t2 * h, p + t1 * h + t2 * h, p - t1 * h + t2 * h]
		var uvs: Array = [uvr.position + Vector2(0, uvr.size.y), uvr.position + uvr.size, uvr.position + Vector2(uvr.size.x, 0), uvr.position]
		var bright: float = rng.randf_range(0.9, 1.08)
		for j in range(4):
			var v: Vector3 = corners[j]
			var cn: Vector3 = (v - crown_c)
			cn = Vector3(cn.x / maxf(crown_r, 0.1), cn.y / maxf((top - under) * 0.7, 0.1), cn.z / maxf(crown_r, 0.1)).normalized()
			var shade: float = clampf(0.3 + 0.7 * smoothstep(under - 0.5, top - 0.5, v.y), 0.25, 1.0)
			shade *= lerpf(0.75, 1.0, clampf(Vector2(v.x - crown_c.x, v.z - crown_c.z).length() / maxf(crown_r, 0.1), 0.0, 1.0))
			st.set_normal((cn + Vector3.UP * 0.5).normalized())
			st.set_color(Color(tint.r * bright, tint.g * bright, tint.b * bright, shade))
			st.set_uv(uvs[j])
			st.add_vertex(v)
		for idx in [0, 1, 2, 0, 2, 3]:
			st.add_index(base + idx)
		base += 4
	return base


## A curved leaf strip (a frond or a banana leaf): from `root` along `dir` rising at `rise` and
## drooping by `droop` toward its tip, `length` by `width`, in `segs` quads, mapped onto `cell`.
func _frond(st: SurfaceTool, base: int, root: Vector3, dir: Vector3, rise: float, droop: float, length: float, width: float,
		segs: int, cell: int, tint: Color, shade0: float, twist: float = 0.0) -> int:
	var uvr: Rect2 = _cell_uv(cell)
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	var side := Vector3(-flat.z, 0.0, flat.x)
	var p := root
	var pts: Array = [p]
	for k in range(segs):
		var t: float = (float(k) + 0.5) / float(segs)
		var ang: float = rise - (rise + droop) * t * t
		p += (flat * cos(ang) + Vector3.UP * sin(ang)) * (length / float(segs))
		pts.append(p)
	for k in range(segs + 1):
		var t: float = float(k) / float(segs)
		var q: Vector3 = pts[k]
		var tw: Vector3 = side.rotated(flat, twist * t)
		var w: float = width * (0.35 + 0.65 * sin(PI * clampf(0.15 + t * 0.85, 0.0, 1.0)))
		if cell == CELL_BANANA:
			w = width * (0.25 + 0.75 * sin(PI * clampf(0.1 + t * 0.9, 0.0, 1.0)))
		var up: Vector3 = tw.cross(((pts[mini(k + 1, segs)] as Vector3) - (pts[maxi(k - 1, 0)] as Vector3)).normalized()).normalized()
		if up.y < 0.0:
			up = -up
		var v: float = uvr.position.y + uvr.size.y * (1.0 - t)
		var shade: float = lerpf(shade0, 1.0, t)
		for e in [-1.0, 1.0]:
			st.set_normal((up + Vector3.UP * 0.3).normalized())
			st.set_color(Color(tint.r, tint.g, tint.b, shade))
			st.set_uv(Vector2(uvr.position.x + uvr.size.x * (0.5 + e * 0.5), v))
			st.add_vertex(q + tw * w * e)
	for k in range(segs):
		var a0: int = base + k * 2
		for idx in [a0, a0 + 2, a0 + 1, a0 + 1, a0 + 2, a0 + 3]:
			st.add_index(idx)
	return base + (segs + 1) * 2


## A rainforest tree: a straight pale trunk on buttress roots, limbs only near the top, and a
## broad crown of leaf clusters. Surface 0 the bark, 1 the leaves. `lod` 1 is the far stand-in.
func _tree_mesh(variant: int, lod: int, bark_mat: Material, leaf_mat: Material) -> ArrayMesh:
	var sh: Dictionary = TREE_SHAPES[variant]
	var rng := RandomNumberGenerator.new()
	rng.seed = 8101 + variant * 131
	var noise := FastNoiseLite.new()
	noise.seed = 51 + variant
	noise.frequency = 0.5
	var h: float = sh["h"]
	var r0: float = sh["r"]
	var cr: float = sh["cr"]
	var under: float = sh["under"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark := Color(0.80, 0.80, 0.72)
	var lean := Vector3(rng.randf_range(-0.4, 0.4), 0.0, rng.randf_range(-0.4, 0.4))
	var trunk: Array = []
	var radii: Array = []
	var segs: int = 8 if lod == 0 else 3
	for k in range(segs + 1):
		var t: float = float(k) / float(segs)
		trunk.append(Vector3(0.0, lerpf(-1.0, under + 1.5, t), 0.0) + lean * t * t + Vector3(sin(t * 5.0 + variant) * 0.15, 0, cos(t * 4.0) * 0.15))
		radii.append(r0 * lerpf(1.0, 0.62, t) * (1.0 + 0.5 * (1.0 - smoothstep(0.0, 0.12, t))))
	var base: int = _bark_tube(st, 0, trunk, radii, 10 if lod == 0 else 5, bark, 0.45, 0.06 if lod == 0 else 0.0, noise, Vector2(under - 2.0, under + 2.0), 9.0)
	if lod == 0 and float(sh["but"]) > 1.5:
		base = _buttresses(st, base, r0, sh["but"], 6, rng, bark.lerp(MOSS_TINT, 0.45))
	# Limbs from the top of the trunk up into the clusters.
	var top_c: Vector3 = trunk[trunk.size() - 1]
	var clusters: Array = []
	var nc: int = sh["clusters"]
	for i in range(nc):
		var a: float = TAU * float(i) / float(nc) + rng.randf_range(-0.3, 0.3)
		var d: float = cr * (0.25 + 0.65 * sqrt(rng.randf())) if i > 0 else 0.0
		var y: float = lerpf(under + 1.5, h - 2.5, 0.35 + 0.65 * (1.0 - d / cr) * rng.randf_range(0.7, 1.0))
		var c := Vector3(cos(a) * d, y, sin(a) * d) + lean
		clusters.append([c, cr * rng.randf_range(0.28, 0.38)])
	var nl: int = sh["limbs"]
	for i in range(nl):
		var cl: Array = clusters[1 + (i * (nc - 1)) / nl]
		var tgt: Vector3 = cl[0]
		var start: Vector3 = top_c + Vector3(0, -rng.randf_range(0.0, 2.5), 0)
		var mid: Vector3 = start.lerp(tgt, 0.5) + Vector3(0, rng.randf_range(0.5, 1.5), 0)
		if lod == 0 or i % 2 == 0:
			base = _bark_tube(st, base, [start, mid, tgt], [r0 * 0.42, r0 * 0.28, r0 * 0.12], 6 if lod == 0 else 4, bark, 0.45, 0.0, noise, Vector2(under - 2.0, under + 2.0))
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, bark_mat)
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	var crown_c := Vector3(lean.x, (under + h) * 0.5, lean.z)
	var b2 := 0
	for cl in clusters:
		var tint := Color(rng.randf_range(0.74, 0.82), rng.randf_range(0.78, 0.84), rng.randf_range(0.70, 0.80))
		var cards: int = (9 if variant < 2 else 7) if lod == 0 else 2
		var size := Vector2(3.8, 5.0) if lod == 0 else Vector2(cl[1] * 2.0, cl[1] * 2.4)
		b2 = _cluster_cards(st2, b2, cl[0], cl[1], cards, size, crown_c, cr, under, h, CELL_SPRAY, tint, rng)
	st2.commit(mesh)
	mesh.surface_set_material(1, leaf_mat)
	return mesh


## An oil palm: a scaly, slightly curved trunk and a crown of long arching fronds.
func _palm_mesh(variant: int, bark_mat: Material, leaf_mat: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6150 + variant * 17
	var noise := FastNoiseLite.new()
	noise.seed = 3 + variant
	noise.frequency = 0.7
	var h: float = 10.0 + float(variant) * 3.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bend := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized() * h * 0.08
	var pts: Array = []
	var radii: Array = []
	for k in range(7):
		var t: float = float(k) / 6.0
		pts.append(Vector3(0.0, lerpf(-0.6, h, t), 0.0) + bend * t * t)
		radii.append(lerpf(0.42, 0.32, t))
	_bark_tube(st, 0, pts, radii, 7, Color(0.9, 0.86, 0.8), 0.35, 0.12, noise, Vector2(1000.0, 1001.0))
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, bark_mat)
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top: Vector3 = pts[pts.size() - 1]
	var b := 0
	var n := 16
	for i in range(n):
		var a: float = TAU * float(i) / float(n) + rng.randf_range(-0.15, 0.15)
		var dir := Vector3(cos(a), 0.0, sin(a))
		var rise: float = rng.randf_range(0.5, 1.0) if i % 3 != 0 else rng.randf_range(0.95, 1.25)
		var tint := Color(rng.randf_range(0.75, 0.85), rng.randf_range(0.8, 0.86), rng.randf_range(0.68, 0.78))
		b = _frond(st2, b, top, dir, rise, rng.randf_range(1.2, 1.7), rng.randf_range(5.2, 6.6), 1.5, 4, CELL_PALM, tint, 0.55, rng.randf_range(-0.4, 0.4))
	st2.commit(mesh)
	mesh.surface_set_material(1, leaf_mat)
	return mesh


## A tree fern: a slim dark trunk furred with old frond bases and a shuttlecock of arching fronds.
func _tree_fern_mesh(bark_mat: Material, leaf_mat: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var noise := FastNoiseLite.new()
	noise.seed = 9
	noise.frequency = 1.1
	var h := 5.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array = []
	var radii: Array = []
	for k in range(6):
		var t: float = float(k) / 5.0
		pts.append(Vector3(sin(t * 2.0) * 0.15, lerpf(-0.5, h, t), cos(t * 1.7) * 0.12))
		radii.append(lerpf(0.34, 0.26, t))
	_bark_tube(st, 0, pts, radii, 7, Color(0.62, 0.52, 0.44), 0.3, 0.2, noise, Vector2(1000.0, 1001.0))
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, bark_mat)
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top: Vector3 = pts[pts.size() - 1]
	var b := 0
	for i in range(13):
		var a: float = TAU * float(i) / 13.0 + rng.randf_range(-0.2, 0.2)
		var dir := Vector3(cos(a), 0.0, sin(a))
		var tint := Color(rng.randf_range(0.8, 0.9), rng.randf_range(0.86, 0.94), rng.randf_range(0.72, 0.82))
		b = _frond(st2, b, top, dir, rng.randf_range(0.7, 1.1), rng.randf_range(1.0, 1.4), rng.randf_range(3.8, 4.8), 1.15, 4, CELL_FERN, tint, 0.5)
	st2.commit(mesh)
	mesh.surface_set_material(1, leaf_mat)
	return mesh


## Wild banana (Ensete): a stout green pseudostem and a fountain of huge paddle leaves.
func _banana_mesh(variant: int, bark_mat: Material, leaf_mat: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3030 + variant * 7
	var noise := FastNoiseLite.new()
	noise.seed = 21
	noise.frequency = 0.8
	var h: float = 2.6 + float(variant) * 1.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_bark_tube(st, 0, [Vector3(0, -0.4, 0), Vector3(0, h * 0.35, 0), Vector3(0, h * 0.75, 0), Vector3(0, h, 0)], [0.34, 0.27, 0.2, 0.15], 7,
			Color(0.50, 0.46, 0.30), 0.4, 0.12, noise, Vector2(1000.0, 1001.0), h * 0.4)
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, bark_mat)
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	var b := 0
	for i in range(9):
		var a: float = TAU * float(i) / 9.0 * 1.618 + rng.randf_range(-0.2, 0.2)
		var dir := Vector3(cos(a), 0.0, sin(a))
		var root := Vector3(0.0, h - rng.randf_range(0.0, 0.5), 0.0) + dir * 0.2
		var tint := Color(rng.randf_range(0.82, 0.92), rng.randf_range(0.86, 0.96), rng.randf_range(0.72, 0.84))
		b = _frond(st2, b, root, dir, rng.randf_range(0.9, 1.25), rng.randf_range(0.9, 1.6), rng.randf_range(3.6, 4.6), 0.75, 4, CELL_BANANA, tint, 0.7, rng.randf_range(-0.6, 0.6))
	st2.commit(mesh)
	mesh.surface_set_material(1, leaf_mat)
	return mesh


## A ground fern: a rosette of fronds arching out of the leaf litter.
func _fern_mesh(variant: int, leaf_mat: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1212 + variant
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var b := 0
	var n: int = 9 + variant * 3
	for i in range(n):
		var a: float = TAU * float(i) / float(n) + rng.randf_range(-0.25, 0.25)
		var dir := Vector3(cos(a), 0.0, sin(a))
		var tint := Color(rng.randf_range(0.82, 0.95), rng.randf_range(0.88, 1.0), rng.randf_range(0.72, 0.85))
		b = _frond(st, b, Vector3(0, -0.05, 0) + dir * 0.1, dir, rng.randf_range(0.9, 1.3), rng.randf_range(1.0, 1.6), rng.randf_range(1.4, 2.2) * (1.0 + variant * 0.3), 0.45, 3, CELL_FERN, tint, 0.6)
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, leaf_mat)
	return mesh


## A leafy shrub: a mound of broadleaf cards.
func _shrub_mesh(variant: int, leaf_mat: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5656 + variant
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r: float = 1.6 + variant * 0.7
	var c := Vector3(0, r * 0.75, 0)
	var b := 0
	for k in range(5):
		var cc: Vector3 = c + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.3, 0.4), rng.randf_range(-0.6, 0.6)) * r
		var tint := Color(rng.randf_range(0.8, 0.9), rng.randf_range(0.84, 0.94), rng.randf_range(0.72, 0.82))
		b = _cluster_cards(st, b, cc, r * 0.6, 4, Vector2(r * 0.9, r * 1.3), c, r, 0.0, r * 1.6, CELL_SPRAY, tint, rng)
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, leaf_mat)
	return mesh


## Lianas: a few woody vines hanging out of the canopy in loose loops down to the ground.
func _liana_mesh(bark_mat: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var noise := FastNoiseLite.new()
	noise.seed = 5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := 0
	for k in range(4):
		var top := Vector3(rng.randf_range(-2.0, 2.0), rng.randf_range(18.0, 24.0), rng.randf_range(-2.0, 2.0))
		var foot := Vector3(rng.randf_range(-3.0, 3.0), -0.3, rng.randf_range(-3.0, 3.0))
		var loop_out := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized() * rng.randf_range(1.5, 3.5)
		var pts: Array = []
		var radii: Array = []
		for i in range(11):
			var t: float = float(i) / 10.0
			pts.append(top.lerp(foot, t) + loop_out * sin(t * PI) + Vector3(sin(t * 9.0 + k) * 0.25, 0.0, cos(t * 7.0 + k) * 0.25))
			radii.append(lerpf(0.07, 0.11, t))
		base = _bark_tube(st, base, pts, radii, 4, Color(0.55, 0.50, 0.40), 0.3, 0.0, noise, Vector2(1000.0, 1001.0))
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, bark_mat)
	return mesh


func _bark_material(lod_mode: int, bark: Color, fissure: Color, stretch: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://tree_bark.gdshader")
	m.set_shader_parameter("bark_color", bark)
	m.set_shader_parameter("fissure_color", fissure)
	m.set_shader_parameter("fissure_width", 0.32)
	m.set_shader_parameter("fissure_depth", 0.03)
	m.set_shader_parameter("plate_stretch", stretch)
	m.set_shader_parameter("roughness_value", 0.8)
	_set_tree_lod(m, lod_mode)
	return m


func _leaf_material(lod_mode: int, sway: float, sway_height: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://acacia_leaves.gdshader")
	m.set_shader_parameter("leaf_tex", _leaf_atlas_texture())
	m.set_shader_parameter("backlight_color", Color(0.55, 0.72, 0.25))
	m.set_shader_parameter("sway", sway)
	m.set_shader_parameter("sway_height", sway_height)
	_set_tree_lod(m, lod_mode)
	return m


func _set_tree_lod(m: ShaderMaterial, lod_mode: int) -> void:
	m.set_shader_parameter("lod_mode", lod_mode)
	m.set_shader_parameter("lod_fade_begin", TREE_NEAR - TREE_FADE * 0.5)
	m.set_shader_parameter("lod_fade_end", TREE_NEAR + TREE_FADE * 0.5)
	m.set_shader_parameter("lod_jitter", TREE_FADE_JITTER)


func _transform_buffer(transforms: Array) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(transforms.size() * 12)
	for i in range(transforms.size()):
		var t: Transform3D = transforms[i]
		var b: Basis = t.basis
		var o: int = i * 12
		buf[o] = b.x.x
		buf[o + 1] = b.y.x
		buf[o + 2] = b.z.x
		buf[o + 3] = t.origin.x
		buf[o + 4] = b.x.y
		buf[o + 5] = b.y.y
		buf[o + 6] = b.z.y
		buf[o + 7] = t.origin.y
		buf[o + 8] = b.x.z
		buf[o + 9] = b.y.z
		buf[o + 10] = b.z.z
		buf[o + 11] = t.origin.z
	return buf


func _multimesh(mesh: Mesh, transforms: Array, node_name: String) -> MultiMeshInstance3D:
	# Random order, seeded by the node's name: drawing the first N instances (a lower level of
	# detail, JungleDetail.gd) then thins the cell evenly instead of emptying one side of it.
	var order: Array = transforms.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(node_name)
	for i in range(order.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	transforms = order
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	# The dummy renderer drops set_instance_transform(); write the buffer itself (CLAUDE.md).
	mm.buffer = _transform_buffer(transforms)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	return mmi


## Where nothing may grow: the road and its verge (`clear` metres from the centreline), water,
## the cliff round the falls and the floor under the falls, the bridge's ends, the start's
## clearing, and anything too steep.
func _plant_ok(x: float, z: float, clear: float, max_slope: float, tall: bool = false) -> bool:
	if _road_distance(x, z) < clear:
		return false
	if tall and _in_spray_zone(x, z):
		return false
	if _in_water(x, z, 2.0):
		return false
	if _slope_at(x, z) > max_slope:
		return false
	var u: Vector3 = _falls_u(x, z)
	if u.x < FALLS_FACE_OFF + 4.0 and _cliff(x, z).y > 0.05:
		return false
	if Vector2(x, z).distance_to(_pool_centre()) < POOL_R + 6.0:
		return false
	if absf(z - _bridge_z()) < 18.0 and absf(x - FALLS_X) < BRIDGE_HALF_SPAN + 18.0:
		return false
	if _in_start_clearing(x, z):
		return false
	if _near_mugumo(x, z, 20.0):
		return false
	return true


## The falls' spray zone: round the pool and down the river's first stretch nothing tall grows,
## only ferns and moss, so the falls stand clear of the forest and show from the gorge road.
func _in_spray_zone(x: float, z: float) -> bool:
	var pc: Vector2 = _pool_centre()
	if Vector2(x, z).distance_to(pc) < POOL_R + 34.0:
		return true
	# On the plateau, the brink stands against the sky.
	if Vector2(x - FALLS_X, z - (_face_z() - 22.0)).length() < 46.0:
		return true
	if z > _face_z() and z < pc.y + 110.0:
		var rx: float = _lower_river_x(z)
		return x > _gorge_edges(z).x + 6.0 and x < rx + 34.0
	return false


## The clearing by the start: the ranger post west of the straight, and the grid itself.
func _in_start_clearing(x: float, z: float) -> bool:
	var fl: Dictionary = _spot(_seg_s(SEG_START, 0.0) + FINISH_OFF, 0.0, 0.0)
	var p: Vector3 = fl["pos"]
	return x > p.x - 60.0 and x < p.x + 14.0 and z > p.z - 30.0 and z < p.z + 70.0


## Jittered grid points over the fine region, every `step` metres.
func _scatter(step: float, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var x: float = FINE_X.x + 10.0
	while x < FINE_X.y - 10.0:
		var z: float = FINE_Z.x + 10.0
		while z < FINE_Z.y - 10.0:
			out.append(Vector2(x + rng.randf_range(-0.45, 0.45) * step, z + rng.randf_range(-0.45, 0.45) * step))
			z += step
		x += step
	return out


func _cell_key(p: Vector3, v: int) -> Vector3i:
	return Vector3i(floori(p.x / FOREST_CELL), floori(p.z / FOREST_CELL), v)


func _add_to_cells(cells: Dictionary, key: Vector3i, xf: Transform3D) -> void:
	if not cells.has(key):
		cells[key] = []
	cells[key].append(xf)


## The forest: canopy trees, palms and tree ferns, wild bananas, shrubs and ferns crowding the
## road's verges, lianas hanging over it. Instanced per 80m cell; the canopy crossfades to a
## stand-in past TREE_NEAR (tree_lod.gdshaderinc). Trunks near the road, and every trunk on the
## Nyoka's hillside, are solid, so the hairpins can't be cut down the slope.
func _build_forest(parent: Node) -> void:
	var root := Node3D.new()
	root.name = "Rainforest"
	parent.add_child(root)
	var t0: int = Time.get_ticks_msec()
	_leaf_atlas_texture()
	print("  leaf atlas drawn (%.1fs)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	# Saved on their own, so every tree shares them and the level of detail (JungleDetail.gd) can
	# move the crossfade for the whole forest at once.
	var bark_near: ShaderMaterial = _save_baked_resource(_bark_material(1, Color(0.34, 0.32, 0.27), Color(0.17, 0.15, 0.12), 2.5), "tree_bark_near")
	var bark_far: ShaderMaterial = _save_baked_resource(_bark_material(2, Color(0.34, 0.32, 0.27), Color(0.17, 0.15, 0.12), 2.5), "tree_bark_far")
	var leaf_near: ShaderMaterial = _save_baked_resource(_leaf_material(1, 0.18, 30.0), "tree_leaf_near")
	var leaf_far: ShaderMaterial = _save_baked_resource(_leaf_material(2, 0.18, 30.0), "tree_leaf_far")
	var near_meshes: Array = []
	var far_meshes: Array = []
	for v in range(TREE_SHAPES.size()):
		near_meshes.append(_save_baked_resource(_tree_mesh(v, 0, bark_near, leaf_near), "tree_%d" % v))
		far_meshes.append(_save_baked_resource(_tree_mesh(v, 1, bark_far, leaf_far), "tree_far_%d" % v))
	var palm_bark := _bark_material(0, Color(0.42, 0.36, 0.28), Color(0.22, 0.18, 0.13), 0.35)
	var fern_bark := _bark_material(0, Color(0.30, 0.22, 0.16), Color(0.14, 0.10, 0.07), 0.6)
	var stem_mat := _bark_material(0, Color(0.36, 0.38, 0.20), Color(0.24, 0.20, 0.12), 4.0)
	var palm_leaf := _leaf_material(0, 0.22, 12.0)
	var under_leaf := _leaf_material(0, 0.12, 6.0)
	var ground_leaf := _leaf_material(0, 0.05, 2.0)
	var palms: Array = [_save_baked_resource(_palm_mesh(0, palm_bark, palm_leaf), "palm_0"), _save_baked_resource(_palm_mesh(1, palm_bark, palm_leaf), "palm_1")]
	var tree_fern: Mesh = _save_baked_resource(_tree_fern_mesh(fern_bark, under_leaf), "tree_fern")
	var bananas: Array = [_save_baked_resource(_banana_mesh(0, stem_mat, under_leaf), "banana_0"), _save_baked_resource(_banana_mesh(1, stem_mat, under_leaf), "banana_1")]
	var ferns: Array = [_save_baked_resource(_fern_mesh(0, ground_leaf), "fern_0"), _save_baked_resource(_fern_mesh(1, ground_leaf), "fern_1")]
	var shrubs: Array = [_save_baked_resource(_shrub_mesh(0, under_leaf), "shrub_0"), _save_baked_resource(_shrub_mesh(1, under_leaf), "shrub_1")]
	var liana: Mesh = _save_baked_resource(_liana_mesh(fern_bark), "liana")
	print("  plant meshes built (%.1fs)" % ((Time.get_ticks_msec() - t0) / 1000.0))

	var rng := RandomNumberGenerator.new()
	rng.seed = 24601
	var near := {}
	var far := {}
	var deep_near := {}
	var deep_far := {}
	var other := {}
	var cover := {}
	var trunks: Array = []
	var counts := {"tree": 0, "palm": 0, "treefern": 0, "banana": 0, "shrub": 0, "fern": 0, "liana": 0}
	# Canopy and understory trees. A few gaps where a giant fell, more palms by the water.
	var tree_pts: Array = _scatter(10.5, rng)
	for p in _scatter(10.0, rng):
		# The understory trees, a layer under the canopy.
		tree_pts.append(Vector3(p.x, p.y, 2.0))
	for p in tree_pts:
		var x: float = p.x
		var z: float = p.y
		if _base_noise.get_noise_2d(x * 4.0, z * 4.0) < -0.45:
			continue
		var pick: float = rng.randf()
		var v: int = 0 if pick < 0.3 else 1
		if p is Vector3:
			v = 2
			if rng.randf() < 0.35:
				continue
		# Deep in the forest the trees are only ever seen as canopy from far off: most of them go
		# into a layer only the higher levels of detail draw (the far stand-ins and the ground's
		# canopy colour carry the look without them).
		var deep: float = smoothstep(55.0, 140.0, _road_distance(x, z))
		var in_deep: bool = rng.randf() < deep * (0.75 if v == 2 else 0.6) and not _on_nyoka_hillside(x, z)
		var sc: float = rng.randf_range(0.85, 1.15)
		var trunk_r: float = float(TREE_SHAPES[v]["r"]) * sc
		var clear: float = ROAD_FLAT + 3.5 + trunk_r * 2.0 + (1.5 if v == 0 else 0.0)
		if not _plant_ok(x, z, clear, 0.75, true):
			continue
		var y: float = _ground_at(x, z)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.92, 1.1), sc)), Vector3(x, y, z))
		if in_deep:
			_add_to_cells(deep_near, _cell_key(xf.origin, v), xf)
			_add_to_cells(deep_far, Vector3i(floori(x / 200.0), floori(z / 200.0), v), xf)
			counts["deep"] = int(counts.get("deep", 0)) + 1
			continue
		_add_to_cells(near, _cell_key(xf.origin, v), xf)
		_add_to_cells(far, Vector3i(floori(x / 200.0), floori(z / 200.0), v), xf)
		counts["tree"] += 1
		var rd: float = _road_distance(x, z)
		if rd < TRUNK_COLLIDE_REACH or _on_nyoka_hillside(x, z):
			trunks.append([Vector3(x, y, z), trunk_r * (1.6 if v < 2 else 1.1), float(TREE_SHAPES[v]["under"]) * sc])
		# Lianas hang from the canopy trees right by the road.
		if v < 2 and rd < clear + 6.0 and rng.randf() < 0.45:
			var lx := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(x, y, z))
			_add_to_cells(other, _cell_key(lx.origin, 100), lx)
			counts["liana"] += 1
	# Palms and tree ferns: in the gaps, palms toward the water.
	for p in _scatter(17.0, rng):
		var x: float = p.x
		var z: float = p.y
		var wet: bool = _in_water(x, z, 30.0)
		var is_palm: bool = rng.randf() < (0.65 if wet else 0.3)
		if not _plant_ok(x, z, ROAD_FLAT + 3.0, 0.8, is_palm):
			continue
		var y: float = _ground_at(x, z)
		var sc2: float = rng.randf_range(0.85, 1.15)
		var xf2 := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc2), Vector3(x, y, z))
		if is_palm:
			_add_to_cells(other, _cell_key(xf2.origin, 10 + (rng.randi() % 2)), xf2)
			counts["palm"] += 1
		else:
			_add_to_cells(other, _cell_key(xf2.origin, 12), xf2)
			counts["treefern"] += 1
		if _road_distance(x, z) < 30.0 or _on_nyoka_hillside(x, z):
			trunks.append([Vector3(x, y, z), 0.45 * sc2, 6.0])
	# The understory: thick along the verges, where the light reaches, thinner in the forest.
	for p in _scatter(4.2, rng):
		var x: float = p.x
		var z: float = p.y
		var rd2: float = _road_distance(x, z)
		var verge: float = 1.0 - smoothstep(ROAD_FLAT + 10.0, ROAD_FLAT + 40.0, rd2)
		if rng.randf() > lerpf(0.3, 0.9, verge):
			continue
		if not _plant_ok(x, z, ROAD_FLAT + 1.2, 0.9):
			continue
		var y: float = _ground_at(x, z)
		var pick2: float = rng.randf()
		var kind: int
		if rd2 < ROAD_FLAT + 3.0:
			kind = 20 + (rng.randi() % 2)
		elif pick2 < 0.32:
			kind = 30 + (rng.randi() % 2)
		elif pick2 < 0.62:
			kind = 20 + (rng.randi() % 2)
		else:
			kind = 40 + (rng.randi() % 2)
		var sc3: float = rng.randf_range(0.8, 1.25)
		var xf3 := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc3), Vector3(x, y - 0.05, z))
		_add_to_cells(other, _cell_key(xf3.origin, kind), xf3)
		if kind >= 40:
			counts["banana"] += 1
		elif kind >= 30:
			counts["shrub"] += 1
		else:
			counts["fern"] += 1

	# Ground cover: small ferns and leafy herbs carpeting the verges, drawn only at the higher
	# levels of detail.
	for p in _scatter(2.6, rng):
		var x: float = p.x
		var z: float = p.y
		var rd3: float = _road_distance(x, z)
		if rd3 > ROAD_FLAT + 34.0 or rng.randf() > lerpf(0.9, 0.35, smoothstep(ROAD_FLAT + 4.0, ROAD_FLAT + 34.0, rd3)):
			continue
		if not _plant_ok(x, z, ROAD_FLAT + 0.6, 0.95):
			continue
		var sc4: float = rng.randf_range(0.45, 0.8)
		var xf4 := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc4), Vector3(x, _ground_at(x, z) - 0.04, z))
		_add_to_cells(cover, _cell_key(xf4.origin, rng.randi() % 3), xf4)
		counts["cover"] = int(counts.get("cover", 0)) + 1

	# Canopy: each tree crossfades between the two around TREE_NEAR. Cell ranges are measured to
	# the cell's centre, so they're padded by half a cell diagonal.
	for k in near.keys():
		var mmi := _multimesh(near_meshes[k.z], near[k], "Tree_%d_%d_%d" % [k.x, k.y, k.z])
		mmi.visibility_range_end = TREE_NEAR + TREE_FADE * 0.5 + TREE_FADE_JITTER + FOREST_CELL * 0.72
		mmi.visibility_range_end_margin = 10.0
		# The detailed trees cast no shadow themselves: a shadow-only copy of the stand-in does it,
		# with a quarter of the leaf cards (alpha-tested cards are what the shadow pass pays for).
		# The understory trees stand in the canopy's shade and cast none at all.
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)
		if k.z != 2:
			var proxy := _multimesh(far_meshes[k.z], near[k], "TreeShadow_%d_%d_%d" % [k.x, k.y, k.z])
			proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			proxy.visibility_range_end = mmi.visibility_range_end
			proxy.visibility_range_end_margin = 10.0
			root.add_child(proxy)
	for k in far.keys():
		var mmi2 := _multimesh(far_meshes[k.z], far[k], "TreeFar_%d_%d_%d" % [k.x, k.y, k.z])
		mmi2.visibility_range_begin = maxf(0.0, TREE_NEAR - TREE_FADE * 0.5 - TREE_FADE_JITTER - 200.0 * 0.72)
		mmi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi2)
	for k in deep_near.keys():
		var mmi4 := _multimesh(near_meshes[k.z], deep_near[k], "TreeDeep_%d_%d_%d" % [k.x, k.y, k.z])
		mmi4.visibility_range_end = TREE_NEAR + TREE_FADE * 0.5 + TREE_FADE_JITTER + FOREST_CELL * 0.72
		mmi4.visibility_range_end_margin = 10.0
		mmi4.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi4)
	for k in deep_far.keys():
		var mmi5 := _multimesh(far_meshes[k.z], deep_far[k], "TreeDeepFar_%d_%d_%d" % [k.x, k.y, k.z])
		mmi5.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi5)
	var cover_mesh: Array = [ferns[0], ferns[1], shrubs[0]]
	for k in cover.keys():
		var mmi6 := _multimesh(cover_mesh[k.z], cover[k], "GroundCover_%d_%d_%d" % [k.x, k.y, k.z])
		mmi6.visibility_range_end = 70.0 + FOREST_CELL * 0.72
		mmi6.visibility_range_end_margin = 10.0
		mmi6.set_meta(&"base_range", mmi6.visibility_range_end)
		mmi6.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi6)
	var other_mesh := {10: palms[0], 11: palms[1], 12: tree_fern, 20: ferns[0], 21: ferns[1], 30: shrubs[0], 31: shrubs[1], 40: bananas[0], 41: bananas[1], 100: liana}
	var other_range := {10: 260.0, 11: 260.0, 12: 170.0, 20: 70.0, 21: 80.0, 30: 110.0, 31: 120.0, 40: 130.0, 41: 140.0, 100: 120.0}
	for k in other.keys():
		var kind2: int = k.z
		var mmi3 := _multimesh(other_mesh[kind2], other[k], "Plants_%d_%d_%d" % [k.x, k.y, kind2])
		mmi3.visibility_range_end = float(other_range[kind2]) + FOREST_CELL * 0.72
		mmi3.visibility_range_end_margin = 10.0
		mmi3.set_meta(&"base_range", mmi3.visibility_range_end)
		if kind2 == 100:
			mmi3.set_meta(&"liana", true)
		# Only the palms throw a shadow worth its cost; the rest stand in the canopy's shade.
		if kind2 != 10 and kind2 != 11:
			mmi3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi3)
	# Solid trunks, per cell. "Tree" in the name: the AI's obstacle rays steer round them.
	var bodies := {}
	for t in trunks:
		var p3: Vector3 = t[0]
		var bk := Vector2i(floori(p3.x / FOREST_CELL), floori(p3.z / FOREST_CELL))
		if not bodies.has(bk):
			var body := StaticBody3D.new()
			body.name = "TreeTrunks_%d_%d" % [bk.x, bk.y]
			root.add_child(body)
			bodies[bk] = body
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = t[1]
		cyl.height = t[2]
		cs.shape = cyl
		cs.position = p3 + Vector3(0, cyl.height * 0.5 - 0.5, 0)
		bodies[bk].add_child(cs)
	var detail := Node3D.new()
	detail.name = "JungleDetail"
	detail.set_script(load("res://JungleDetail.gd"))
	var mats: Array[ShaderMaterial] = [bark_near, bark_far, leaf_near, leaf_far]
	detail.set("lod_materials", mats)
	detail.set("tree_fade", TREE_FADE)
	detail.set("tree_fade_jitter", TREE_FADE_JITTER)
	detail.set("forest_cell", FOREST_CELL)
	# JungleDressing/Rainforest/JungleDetail -> the level's JungleRain.
	detail.set("rain_path", NodePath("../../../JungleRain"))
	detail.set("ground_material", _ground_mat)
	root.add_child(detail)
	print("  forest: %s, %d trunk colliders (%.1fs)" % [str(counts), trunks.size(), (Time.get_ticks_msec() - t0) / 1000.0])


## The Nyoka's hillside: the slope the switchbacks zigzag down, between the bridge road and the
## gorge. Every trunk on it is solid, so the hairpins can't be cut straight down the slope.
func _on_nyoka_hillside(x: float, z: float) -> bool:
	return x > 50.0 and x < 300.0 and z > _bridge_z() and z < -230.0


# ======================================================================================
#  The Mugumo
# ======================================================================================

## Where the Mugumo straddles the road: arc length on the climb, how far its two great root
## pillars stand from the centreline, the height its arch closes over the road.
const MUGUMO_FRAC := 0.55
const MUGUMO_LEG := 11.5
const MUGUMO_ARCH_Y := 15.0


## The Mugumo: a strangler fig that grew round a host tree long since rotted away, its roots
## fused into two pillars either side of the road that meet in an arch over it, a tangle of
## aerial roots hanging from the arch, and a vast crown above.
func _build_mugumo(parent: Node) -> void:
	var s0: float = _seg_s(SEG_MUGUMO, MUGUMO_FRAC)
	var sp: Dictionary = _spot(s0, 0.0, 0.0)
	var c: Vector3 = sp["pos"]
	var fwd: Vector3 = sp["fwd"]
	var right: Vector3 = sp["right"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1958
	var noise := FastNoiseLite.new()
	noise.seed = 77
	noise.frequency = 0.4
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark := Color(0.70, 0.70, 0.62)
	var base := 0
	var top := c + Vector3(0, MUGUMO_ARCH_Y, 0)
	var colliders: Array = []
	# The two pillars: each a bundle of fused roots, wide at the foot, bending in over the road.
	for side in [-1.0, 1.0]:
		var foot: Vector3 = c + right * side * MUGUMO_LEG
		foot.y = _ground_at(foot.x, foot.z) - 0.8
		for k in range(9):
			var off: Vector3 = fwd * rng.randf_range(-3.2, 3.2) + right * side * rng.randf_range(-0.4, 3.6)
			var f2: Vector3 = foot + off
			f2.y = _ground_at(f2.x, f2.z) - 0.8
			var pts: Array = []
			var radii: Array = []
			var r_foot: float = rng.randf_range(1.0, 1.5)
			for i in range(11):
				var t: float = float(i) / 10.0
				var p: Vector3 = f2.lerp(top + off * 0.2, t)
				# Up the verge first, then in over the road: a gothic arch, not a bridge.
				p += right * side * (sin(t * PI) * 2.2 - pow(t, 3.0) * 0.6)
				p.y = lerpf(f2.y, top.y, pow(t, 0.65))
				pts.append(p)
				radii.append(lerpf(r_foot, 0.65, pow(t, 0.7)) * (1.0 + (1.0 - smoothstep(0.0, 0.15, t)) * 0.6))
			base = _bark_tube(st, base, pts, radii, 9, bark, 0.4, 0.18, noise, Vector2(1000.0, 1001.0), 7.0)
		colliders.append([c + right * side * (MUGUMO_LEG + 1.4), 3.4, 10.0])
	# The trunk above the arch, and limbs out into the crown.
	var crown_y: float = top.y + 9.0
	base = _bark_tube(st, base, [top - Vector3(0, 2.0, 0), top + Vector3(0.3, 4.0, 0.2), top + Vector3(-0.2, 10.0, 0.3)], [3.4, 2.6, 2.0], 14, bark, 0.4, 0.15, noise, Vector2(1000.0, 1001.0))
	var clusters: Array = []
	for i in range(22):
		var a: float = TAU * float(i) / 22.0 + rng.randf_range(-0.2, 0.2)
		var d: float = rng.randf_range(4.0, 17.0)
		var cc: Vector3 = top + Vector3(cos(a) * d, rng.randf_range(8.0, 16.0) - d * 0.25, sin(a) * d)
		clusters.append([cc, rng.randf_range(4.0, 5.5)])
		if i % 2 == 0:
			var mid: Vector3 = (top + Vector3(0, 8.0, 0)).lerp(cc, 0.5) + Vector3(0, 1.5, 0)
			base = _bark_tube(st, base, [top + Vector3(0, 8.0, 0), mid, cc], [1.0, 0.6, 0.25], 6, bark, 0.4, 0.0, noise, Vector2(1000.0, 1001.0))
	# Aerial roots: dropped from the arch and the limbs, those over the verges reaching the
	# ground, those over the road stopping well above it.
	for i in range(60):
		var a2: float = rng.randf() * TAU
		var d2: float = rng.randf_range(3.0, 15.0)
		var from: Vector3 = top + Vector3(cos(a2) * d2, rng.randf_range(2.0, 7.0), sin(a2) * d2)
		var lat: float = (from - c).dot(right)
		var over_road: bool = absf(lat) < ROAD_FLAT + 1.5
		var to_y: float = from.y - rng.randf_range(3.0, 6.0) if over_road else _ground_at(from.x, from.z) - 0.3
		if over_road:
			to_y = maxf(to_y, c.y + 7.5)
		var pts2: Array = []
		var radii2: Array = []
		for k in range(6):
			var t: float = float(k) / 5.0
			pts2.append(Vector3(from.x + sin(t * 3.0 + i) * 0.3, lerpf(from.y, to_y, t), from.z + cos(t * 2.0 + i) * 0.3))
			radii2.append(lerpf(0.22, 0.1, t) if over_road else lerpf(0.25, 0.32, t))
		base = _bark_tube(st, base, pts2, radii2, 5, bark.darkened(0.1), 0.4, 0.0, noise, Vector2(1000.0, 1001.0), 3.0 if not over_road else 0.0)
		if not over_road:
			colliders.append([Vector3(from.x, _ground_at(from.x, from.z) + 2.0, from.z), 0.35, 4.0])
	var bark_mat := _bark_material(0, Color(0.33, 0.31, 0.26), Color(0.15, 0.13, 0.10), 6.0)
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, bark_mat)
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	var b2 := 0
	var crown_c: Vector3 = top + Vector3(0, 11.0, 0)
	for cl in clusters:
		var tint := Color(rng.randf_range(0.72, 0.8), rng.randf_range(0.78, 0.84), rng.randf_range(0.66, 0.76))
		b2 = _cluster_cards(st2, b2, cl[0], cl[1], 14, Vector2(3.6, 5.0), crown_c, 17.0, top.y + 3.0, top.y + 18.0, CELL_SPRAY, tint, rng)
	st2.commit(mesh)
	mesh.surface_set_material(1, _leaf_material(0, 0.15, 30.0))
	var mi := MeshInstance3D.new()
	mi.name = "Mugumo"
	mi.mesh = _save_baked_resource(mesh, "mugumo")
	parent.add_child(mi)
	var body := StaticBody3D.new()
	# "Tree" in the name: the AI's obstacle rays steer round it.
	body.name = "MugumoTree"
	parent.add_child(body)
	for cl2 in colliders:
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = cl2[1]
		cyl.height = cl2[2]
		cs.shape = cyl
		cs.position = cl2[0]
		body.add_child(cs)
	print("  mugumo at s=%.0f (%.0f, %.0f)" % [s0, c.x, c.z])


## Nothing else may grow in the Mugumo's shadow.
func _near_mugumo(x: float, z: float, reach: float) -> bool:
	var c: Vector3 = _spot(_seg_s(SEG_MUGUMO, MUGUMO_FRAC), 0.0, 0.0)["pos"]
	return Vector2(x - c.x, z - c.z).length() < reach


# ======================================================================================
#  Trackside
# ======================================================================================

## Chevron boards on the outside of every sharp bend, facing the field as it arrives: red and
## white, pointing the way the road turns.
func _build_chevrons(parent: Node) -> void:
	var root := Node3D.new()
	root.name = "Chevrons"
	parent.add_child(root)
	var sh := Shader.new()
	sh.code = """shader_type spatial;
// A chevron board: white arrows on red, pointing along +UV.x (the generator mirrors the board's
// UVs for a left-hander). The back of the board is plain timber.
void fragment() {
	vec3 col = vec3(0.30, 0.22, 0.14);
	if (FRONT_FACING) {
		vec2 uv = UV;
		float x = fract(uv.x * 2.0);
		float d = abs(uv.y - 0.5);
		float arrow = step(abs(x - 0.35 - d * 0.6), 0.13);
		float border = step(0.42, d) + step(abs(uv.x - 0.5), 0.0) ;
		col = mix(vec3(0.78, 0.07, 0.05), vec3(0.95, 0.94, 0.90), clamp(arrow + border, 0.0, 1.0));
		EMISSION = col * 0.12;
	}
	ALBEDO = col;
	ROUGHNESS = 0.6;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var post_st := SurfaceTool.new()
	post_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	for seg_i in [SEG_MATOPE, 15, SEG_NYOKA[0], SEG_NYOKA[1], SEG_NYOKA[2], 27, SEG_FALLS - 1, SEG_FALLS + 1]:
		var seg: Dictionary = _segs[seg_i]
		if seg["kind"] != "A":
			continue
		var sign: float = seg["sign"]
		var s0: float = seg["s0"]
		var length: float = seg["len"]
		var n_boards: int = clampi(int(length / 9.0), 3, 7)
		for k in range(n_boards):
			var s: float = s0 + length * (0.08 + 0.84 * float(k) / float(maxi(n_boards - 1, 1)))
			var sp: Dictionary = _spot(s, 0.0, 0.0)
			# Outside of the bend: left of a right-hander.
			var out: Vector3 = sp["right"] * -sign
			var p: Vector3 = (sp["pos"] as Vector3) + out * (ROAD_FLAT + 1.6)
			p.y = _ground_at(p.x, p.z)
			# Not where the verge is a cliff or a drop: the wall is warning enough.
			if _in_water(p.x, p.z, 1.0) or absf(p.y - (sp["pos"] as Vector3).y) > 2.0:
				continue
			var face: Vector3 = -(sp["fwd"] as Vector3)
			var along: Vector3 = Vector3.UP.cross(face).normalized()
			var c: Vector3 = p + Vector3(0, 1.25, 0)
			var hw := 0.9
			var hh := 0.45
			var q: Array = [c - along * hw - Vector3(0, hh, 0), c + along * hw - Vector3(0, hh, 0), c + along * hw + Vector3(0, hh, 0), c - along * hw + Vector3(0, hh, 0)]
			# UV.x runs the way the road turns, so the arrows point into the bend.
			var flip: bool = (along.dot(sp["right"] * sign) < 0.0)
			var us: Array = [1.0, 0.0, 0.0, 1.0] if flip else [0.0, 1.0, 1.0, 0.0]
			var vs: Array = [1.0, 1.0, 0.0, 0.0]
			for tri in [[0, 1, 2], [0, 2, 3]]:
				var a: int = tri[0]
				var b: int = tri[1]
				var cc: int = tri[2]
				var va: Vector3 = q[a]
				var vb: Vector3 = q[b]
				var vc: Vector3 = q[cc]
				# Front face toward the field (clockwise, normal (c - a) x (b - a)).
				if (vc - va).cross(vb - va).dot(face) < 0.0:
					var tmp: int = b
					b = cc
					cc = tmp
				for idx in [a, b, cc]:
					st.set_normal(face)
					st.set_uv(Vector2(us[idx], vs[idx]))
					st.add_vertex(q[idx])
				for idx in [a, cc, b]:
					st.set_normal(-face)
					st.set_uv(Vector2(us[idx], vs[idx]))
					st.add_vertex((q[idx] as Vector3) - face * 0.04)
			_pole(post_st, p + Vector3(0, -0.3, 0) - face * 0.06, p + Vector3(0, 1.75, 0) - face * 0.06, 0.06, 5, Color(0.45, 0.36, 0.26))
			count += 1
	var mi := MeshInstance3D.new()
	mi.name = "ChevronBoards"
	mi.mesh = st.commit()
	mi.material_override = mat
	root.add_child(mi)
	var post_mat := StandardMaterial3D.new()
	post_mat.vertex_color_use_as_albedo = true
	post_mat.vertex_color_is_srgb = true
	post_mat.roughness = 0.9
	var pmi := MeshInstance3D.new()
	pmi.name = "ChevronPosts"
	pmi.mesh = post_st.commit()
	pmi.material_override = post_mat
	root.add_child(pmi)
	print("  chevrons: %d boards" % count)


## Log barriers round the outside of the Nyoka's hairpins: two rails on stout posts, so a cart
## that comes in too fast (a boost on the downhill leg will do it) is stopped at the edge instead
## of tumbling down the hillside. "Barrier" in the name: the AI's obstacle rays steer clear.
func _build_hairpin_barriers(parent: Node) -> void:
	var root := Node3D.new()
	root.name = "NyokaBarriers"
	parent.add_child(root)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := StaticBody3D.new()
	body.name = "NyokaBarrier"
	root.add_child(body)
	var wood := Color(0.40, 0.31, 0.21)
	var count := 0
	for seg_i in SEG_NYOKA:
		var seg: Dictionary = _segs[seg_i]
		var sign: float = seg["sign"]
		var s0: float = seg["s0"]
		var length: float = seg["len"]
		var pts: Array = []
		var n: int = int(length * 0.8 / 3.0)
		for k in range(n + 1):
			var s: float = s0 + length * (0.1 + 0.8 * float(k) / float(n))
			var sp: Dictionary = _spot(s, 0.0, 0.0)
			var q: Vector3 = (sp["pos"] as Vector3) + (sp["right"] as Vector3) * -sign * (ROAD_FLAT + 0.5)
			q.y = _ground_at(q.x, q.z)
			pts.append(q)
		for k in range(pts.size()):
			var q2: Vector3 = pts[k]
			_pole(st, q2 + Vector3(0, -0.5, 0), q2 + Vector3(0, 1.15, 0), 0.16, 6, wood)
			if k == pts.size() - 1:
				continue
			var nx: Vector3 = pts[k + 1]
			for hgt in [0.45, 0.95]:
				_pole(st, q2 + Vector3(0, hgt, 0), nx + Vector3(0, hgt, 0), 0.13, 6, wood.lightened(0.08))
			var mid: Vector3 = (q2 + nx) * 0.5
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(Vector2(nx.x - q2.x, nx.z - q2.z).length() + 0.3, 1.6, 0.45)
			cs.shape = box
			cs.transform = Transform3D(Basis(Vector3.UP, atan2(-(nx.z - q2.z), nx.x - q2.x)), mid + Vector3(0, 0.55, 0))
			body.add_child(cs)
			count += 1
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.albedo_texture = load("res://materials/wood_planks.png")
	mat.roughness = 0.9
	var mi := MeshInstance3D.new()
	mi.name = "BarrierLogs"
	mi.mesh = st.commit()
	mi.material_override = mat
	root.add_child(mi)
	print("  hairpin barriers: %d panels" % count)


## Bamboo marker poles with a red band along the verges; carts knock them over
## (KnockablePoles.gd).
func _build_marker_posts(parent: Node) -> void:
	var post := CylinderMesh.new()
	post.top_radius = 0.07
	post.bottom_radius = 0.08
	post.height = 1.7
	post.radial_segments = 6
	post.rings = 3
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """shader_type spatial;
// A bamboo marker: green-gold cane with nodes, a red band near the top.
void fragment() {
	float y = 1.0 - UV.y;
	float band = step(0.74, y) * step(y, 0.9);
	float node = smoothstep(0.02, 0.0, abs(fract(y * 4.0) - 0.5) - 0.47);
	vec3 cane = mix(vec3(0.62, 0.62, 0.30), vec3(0.42, 0.46, 0.20), node);
	ALBEDO = mix(cane, vec3(0.80, 0.08, 0.05), band);
	ROUGHNESS = 0.5;
	EMISSION = vec3(0.80, 0.08, 0.05) * band * 0.2;
}
"""
	mat.shader = sh
	post.material = mat
	var transforms: Array = []
	var s := 10.0
	while s < _lap_len - 6.0:
		var skip: bool = _on_bridge(s) or _on_bridge(s + 12.0) or _on_bridge(s - 12.0)
		skip = skip or absf(s - _seg_s(SEG_MUGUMO, MUGUMO_FRAC)) < 25.0
		if not skip:
			var sp: Dictionary = _spot(s, 0.0, 0.0)
			for side in [-1.0, 1.0]:
				var q: Vector3 = (sp["pos"] as Vector3) + (sp["right"] as Vector3) * side * (ROAD_HALF + 2.0)
				if _in_water(q.x, q.z, 0.5):
					continue
				q.y = _ground_at(q.x, q.z) + 0.75
				transforms.append(Transform3D(Basis(), q))
		s += 28.0
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = post
	mm.instance_count = transforms.size()
	mm.buffer = _transform_buffer(transforms)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "MarkerPosts"
	mmi.set_script(load("res://KnockablePoles.gd"))
	var typed: Array[Transform3D] = []
	for t in transforms:
		typed.append(t)
	mmi.set("pole_transforms", typed)
	mmi.set("pole_height", 1.7)
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	print("  marker posts: %d" % transforms.size())


## The ranger post in its clearing beside the start: a timber office on stilts and a store with
## rusty iron roofs, a flagpole, the reserve's sign, and the Matumaini GP banner over the road.
func _build_start_area(parent: Node) -> void:
	var root := Node3D.new()
	root.name = "RangerPost"
	parent.add_child(root)
	var fl: Dictionary = _spot(_seg_s(SEG_START, 0.0) + FINISH_OFF, 0.0, 0.0)
	var c: Vector3 = fl["pos"]
	var right: Vector3 = fl["right"]
	var fwd: Vector3 = fl["fwd"]
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = load("res://materials/wood_planks.png")
	wood.albedo_color = Color(0.78, 0.62, 0.44)
	wood.uv1_triplanar = true
	wood.uv1_scale = Vector3(0.5, 0.5, 0.5)
	wood.roughness = 0.9
	var roof_mat := ShaderMaterial.new()
	var rsh := Shader.new()
	rsh.code = """shader_type spatial;
// Corrugated iron, painted green and gone to rust in streaks.
varying vec3 w_pos;
void vertex() { w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	float rib = 0.5 + 0.5 * sin((w_pos.x + w_pos.z) * 9.0);
	float rust = smoothstep(0.55, 0.9, h(floor(vec2(w_pos.x + w_pos.z, w_pos.y * 0.4) * 1.3)) * 0.6 + sin(w_pos.x * 2.1) * 0.2 + 0.3);
	vec3 col = mix(vec3(0.22, 0.38, 0.26), vec3(0.45, 0.22, 0.10), rust);
	ALBEDO = col * (0.8 + rib * 0.25);
	ROUGHNESS = mix(0.45, 0.85, rust);
	METALLIC = mix(0.5, 0.1, rust);
}
"""
	roof_mat.shader = rsh
	var body := StaticBody3D.new()
	body.name = "RangerPostBuildings"
	root.add_child(body)
	# Buildings west of the straight (left, heading south, is east: the straight runs south, its
	# right is west).
	var bdefs: Array = [[30.0, -18.0, Vector3(12.0, 4.0, 8.0), true], [48.0, 14.0, Vector3(8.0, 3.2, 6.0), false], [32.0, 36.0, Vector3(6.0, 3.0, 6.0), false]]
	for bd in bdefs:
		var pos: Vector3 = c + right * float(bd[0]) + fwd * float(bd[1])
		pos.y = _ground_at(pos.x, pos.z)
		var size: Vector3 = bd[2]
		var yaw: float = atan2(-fwd.x, -fwd.z)
		var stilts: float = 1.2 if bd[3] else 0.3
		var walls := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = size
		walls.mesh = wm
		walls.material_override = wood
		walls.transform = Transform3D(Basis(Vector3.UP, yaw), pos + Vector3(0, stilts + size.y * 0.5, 0))
		root.add_child(walls)
		var roof := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(size.x + 1.6, 1.6, size.z + 1.4)
		roof.mesh = pm
		roof.material_override = roof_mat
		roof.transform = Transform3D(Basis(Vector3.UP, yaw), pos + Vector3(0, stilts + size.y + 0.8, 0))
		root.add_child(roof)
		if bd[3]:
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var leg := MeshInstance3D.new()
					var lm := CylinderMesh.new()
					lm.top_radius = 0.18
					lm.bottom_radius = 0.2
					lm.height = stilts + 0.6
					leg.mesh = lm
					leg.material_override = wood
					var lp: Vector3 = pos + Basis(Vector3.UP, yaw) * Vector3(sx * (size.x * 0.5 - 0.3), 0, sz * (size.z * 0.5 - 0.3))
					leg.position = lp + Vector3(0, (stilts + 0.6) * 0.5 - 0.4, 0)
					root.add_child(leg)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size + Vector3(0, stilts + 1.6, 0)
		cs.shape = box
		cs.transform = Transform3D(Basis(Vector3.UP, yaw), pos + Vector3(0, (size.y + stilts + 1.6) * 0.5, 0))
		body.add_child(cs)
	# The reserve's sign, by the road at the start of the straight.
	var sign_pos: Vector3 = c + right * (ROAD_FLAT + 4.0) - fwd * 26.0
	sign_pos.y = _ground_at(sign_pos.x, sign_pos.z)
	var board := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(7.0, 2.2, 0.2)
	board.mesh = bm
	board.material_override = wood
	# Facing up the straight, toward the field arriving out of the gorge.
	var face_yaw: float = atan2(-fwd.x, -fwd.z)
	board.transform = Transform3D(Basis(Vector3.UP, face_yaw), sign_pos + Vector3(0, 3.2, 0))
	root.add_child(board)
	for sx2 in [-3.0, 3.0]:
		var leg2 := MeshInstance3D.new()
		var lm2 := CylinderMesh.new()
		lm2.top_radius = 0.14
		lm2.bottom_radius = 0.16
		lm2.height = 4.4
		leg2.mesh = lm2
		leg2.material_override = wood
		leg2.position = sign_pos + Basis(Vector3.UP, face_yaw) * Vector3(sx2, 2.0, 0.0)
		root.add_child(leg2)
	var label := Label3D.new()
	label.text = "MSITU FALLS\nFOREST RESERVE"
	label.font_size = 96
	label.pixel_size = 0.009
	label.outline_size = 14
	label.modulate = Color(0.98, 0.94, 0.78)
	label.outline_modulate = Color(0.16, 0.10, 0.04)
	label.transform = Transform3D(Basis(Vector3.UP, face_yaw), sign_pos + Vector3(0, 3.2, 0) + (-fwd) * 0.12)
	root.add_child(label)
	# The flagpole.
	var fp_pos: Vector3 = c + right * 22.0 + fwd * 4.0
	fp_pos.y = _ground_at(fp_pos.x, fp_pos.z)
	var fpole := MeshInstance3D.new()
	var fpm := CylinderMesh.new()
	fpm.top_radius = 0.06
	fpm.bottom_radius = 0.09
	fpm.height = 9.0
	fpole.mesh = fpm
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.75, 0.75, 0.72)
	steel.metallic = 0.6
	steel.roughness = 0.4
	fpole.material_override = steel
	fpole.position = fp_pos + Vector3(0, 4.5, 0)
	root.add_child(fpole)
	var cloth := PlaneMesh.new()
	cloth.orientation = PlaneMesh.FACE_Z
	cloth.size = Vector2(2.4, 1.5)
	cloth.subdivide_width = 16
	cloth.subdivide_depth = 4
	cloth.center_offset = Vector3(1.2, 0.0, 0.0)
	var cloth_mat := ShaderMaterial.new()
	cloth_mat.shader = load("res://flag_cloth.gdshader")
	cloth.material = cloth_mat
	var flag := MeshInstance3D.new()
	flag.name = "RangerFlag"
	flag.mesh = cloth
	flag.position = fp_pos + Vector3(0, 8.1, 0)
	root.add_child(flag)
	# The Matumaini GP banner over the straight, 30m past the line.
	var g: Dictionary = _spot(_seg_s(SEG_START, 0.0) + FINISH_OFF + 30.0, 0.0, 0.0)
	var gp: Vector3 = g["pos"]
	var gr: Vector3 = g["right"]
	var gyaw: float = float(g["yaw"])
	var pole := CylinderMesh.new()
	pole.top_radius = 0.22
	pole.bottom_radius = 0.28
	pole.height = 9.0
	pole.radial_segments = 8
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.32, 0.22, 0.14)
	pole_mat.roughness = 0.85
	pole.material = pole_mat
	for sx3 in [-11.0, 11.0]:
		var pm2 := MeshInstance3D.new()
		pm2.mesh = pole
		var pp: Vector3 = gp + gr * sx3
		pp.y = _ground_at(pp.x, pp.z)
		pm2.position = pp + Vector3(0, 4.5, 0)
		root.add_child(pm2)
		var cs2 := CollisionShape3D.new()
		var cyl2 := CylinderShape3D.new()
		cyl2.radius = 0.35
		cyl2.height = 9.0
		cs2.shape = cyl2
		cs2.position = pp + Vector3(0, 4.5, 0)
		body.add_child(cs2)
	var banner := MeshInstance3D.new()
	banner.name = "Banner"
	var bm2 := BoxMesh.new()
	bm2.size = Vector3(21.6, 1.9, 0.12)
	banner.mesh = bm2
	var bmat := ShaderMaterial.new()
	var bsh := Shader.new()
	bsh.code = """shader_type spatial;
// A kanga-print banner: a bold border of triangles round a forest-green field.
void fragment() {
	vec2 uv = UV * vec2(3.0, 2.0);
	vec2 f = fract(uv * vec2(18.0, 6.0));
	float tri = step(f.x, f.y);
	float border = step(0.82, fract(uv.y)) + step(fract(uv.y), 0.18);
	vec3 field = vec3(0.10, 0.36, 0.16);
	vec3 a = vec3(0.86, 0.36, 0.08);
	vec3 b = vec3(0.98, 0.80, 0.18);
	ALBEDO = mix(field, mix(a, b, tri), clamp(border, 0.0, 1.0));
	ROUGHNESS = 0.8;
}
"""
	bmat.shader = bsh
	banner.material_override = bmat
	banner.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(gyaw)), gp + Vector3(0, 7.6, 0))
	root.add_child(banner)
	for side2 in [1.0, -1.0]:
		var lab := Label3D.new()
		lab.text = "MATUMAINI GP"
		lab.font_size = 160
		lab.pixel_size = 0.0075
		lab.outline_size = 28
		lab.modulate = Color(1.0, 0.97, 0.88)
		lab.outline_modulate = Color(0.06, 0.18, 0.08)
		var n: Vector3 = Basis(Vector3.UP, deg_to_rad(gyaw)).z
		lab.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(gyaw) + (0.0 if side2 > 0.0 else PI)), gp + Vector3(0, 7.6, 0) + n * side2 * 0.08)
		root.add_child(lab)


# ======================================================================================
#  Weather
# ======================================================================================

## The hiss of heavy rain on leaves: high-passed noise, with the patter of big drops in it.
func _rain_stream() -> AudioStreamWAV:
	const RATE := 22050
	const SECONDS := 4.0
	var n: int = int(RATE * SECONDS)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6161
	var samples := PackedFloat32Array()
	samples.resize(n)
	var low := 0.0
	var drop := 0.0
	for i in range(n):
		var white: float = rng.randf_range(-1.0, 1.0)
		low += (white - low) * 0.25
		var hiss: float = white - low
		if rng.randf() < 0.012:
			drop = rng.randf_range(0.4, 1.0) * (1.0 if rng.randf() < 0.5 else -1.0)
		drop *= 0.93
		samples[i] = hiss * 0.55 + low * 0.35 + drop * 0.5
	var fade: int = int(RATE * 0.5)
	for i in range(fade):
		var t: float = float(i) / float(fade)
		samples[i] = samples[i] * t + samples[n - fade + i] * (1.0 - t)
	return _pcm_stream(samples, n - fade, RATE, true, "rain_loop")


## A thunderclap: a short crack, then a long rolling rumble.
func _thunder_stream() -> AudioStreamWAV:
	const RATE := 22050
	var n: int = int(RATE * 5.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7171
	var samples := PackedFloat32Array()
	samples.resize(n)
	var brown := 0.0
	var low := 0.0
	for i in range(n):
		var t: float = float(i) / float(RATE)
		var white: float = rng.randf_range(-1.0, 1.0)
		brown = clampf(brown * 0.997 + white * 0.05, -1.0, 1.0)
		low += (brown - low) * 0.08
		var crack: float = white * exp(-t * 18.0) * 0.8
		var roll: float = low * smoothstep(0.0, 0.25, t) * exp(-t * 0.75) * (0.7 + 0.3 * sin(t * 5.3) * sin(t * 1.7))
		samples[i] = crack + roll * 3.0
	return _pcm_stream(samples, n, RATE, false, "thunder")


func _pcm_stream(samples: PackedFloat32Array, n: int, rate: int, loop: bool, res_name: String) -> AudioStreamWAV:
	var peak := 0.001
	for i in range(n):
		peak = maxf(peak, absf(samples[i]))
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		data.encode_s16(i * 2, int(clampf(samples[i] / peak * 0.8, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = n
	return _save_baked_resource(wav, res_name) as AudioStreamWAV


## The forest's voice: a cicada drone that swells and fades, bird calls (a run of chips, a
## two-note whistle, a hornbill's honk) and the rustle of leaves, as a seamless loop.
func _forest_stream() -> AudioStreamWAV:
	const RATE := 22050
	const SECONDS := 14.0
	var n: int = int(RATE * SECONDS)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3131
	var samples := PackedFloat32Array()
	samples.resize(n)
	var low := 0.0
	for i in range(n):
		var t: float = float(i) / float(RATE)
		# Cicadas: a high buzz pulsing at ~45Hz, swelling over a few seconds.
		var swell: float = 0.5 + 0.5 * sin(t * TAU / 7.0)
		var buzz: float = sin(t * TAU * 4100.0) * (0.6 + 0.4 * sin(t * TAU * 4.6)) + sin(t * TAU * 4650.0) * 0.4
		buzz *= maxf(sin(t * TAU * 44.0), 0.0) * swell * swell
		var white: float = rng.randf_range(-1.0, 1.0)
		low += (white - low) * 0.05
		samples[i] = buzz * 0.10 + low * 0.25
	# Bird calls dropped into the loop at random.
	var t_call := 0.4
	while t_call < SECONDS - 1.5:
		var kind: int = rng.randi() % 3
		var start: int = int(t_call * RATE)
		match kind:
			0:
				# A run of chips, each a fast downward sweep.
				var count: int = rng.randi_range(3, 6)
				var f0: float = rng.randf_range(2600.0, 3400.0)
				for c in range(count):
					var s0: int = start + int(float(c) * 0.13 * RATE)
					var dur: int = int(0.06 * RATE)
					var ph := 0.0
					for k in range(dur):
						var u: float = float(k) / float(dur)
						ph += TAU * lerpf(f0, f0 * 0.6, u) / float(RATE)
						if s0 + k < n:
							samples[s0 + k] += sin(ph) * sin(PI * u) * 0.35
			1:
				# A fluting two-note whistle with a little vibrato.
				var f1: float = rng.randf_range(900.0, 1300.0)
				var notes: Array = [f1, f1 * rng.randf_range(1.15, 1.35)]
				var ph2 := 0.0
				for ni in range(2):
					var s1: int = start + int(float(ni) * 0.32 * RATE)
					var dur2: int = int(0.28 * RATE)
					for k in range(dur2):
						var u2: float = float(k) / float(dur2)
						ph2 += TAU * (float(notes[ni]) + sin(u2 * 40.0) * 12.0) / float(RATE)
						if s1 + k < n:
							samples[s1 + k] += sin(ph2) * pow(sin(PI * u2), 0.5) * 0.3
			2:
				# A hornbill's honk: a nasal, buzzy low call, twice.
				for h in range(2):
					var s2: int = start + int(float(h) * 0.45 * RATE)
					var dur3: int = int(0.22 * RATE)
					var ph3 := 0.0
					for k in range(dur3):
						var u3: float = float(k) / float(dur3)
						ph3 += TAU * lerpf(420.0, 360.0, u3) / float(RATE)
						var saw: float = fposmod(ph3 / TAU, 1.0) * 2.0 - 1.0
						if s2 + k < n:
							samples[s2 + k] += saw * sin(PI * u3) * 0.18
		t_call += rng.randf_range(0.9, 2.6)
	var fade: int = int(RATE * 1.0)
	for i in range(fade):
		var t2: float = float(i) / float(fade)
		samples[i] = samples[i] * t2 + samples[n - fade + i] * (1.0 - t2)
	return _pcm_stream(samples, n - fade, RATE, true, "forest_ambience")


func _build_ambience(level_scene: Node3D) -> void:
	var amb := AudioStreamPlayer.new()
	amb.name = "ForestAmbience"
	amb.stream = _forest_stream()
	amb.volume_db = -17.0
	amb.bus = &"SFX"
	amb.autoplay = true
	level_scene.add_child(amb)


func _build_rain(level_scene: Node3D, ground_mat: ShaderMaterial) -> void:
	var rain := Node3D.new()
	rain.name = "JungleRain"
	rain.set_script(load("res://JungleRain.gd"))
	var paths: Array[NodePath] = [NodePath("../TerrainEnvironment/JungleRoad"), NodePath("../TerrainEnvironment/MatopeMudRoad"),
			NodePath("../Daraja/DarajaBridgeDeck")]
	rain.set("road_paths", paths)
	rain.set("ground_material", ground_mat)
	rain.set("sun_path", NodePath("../SunLight"))
	rain.set("ambience_path", NodePath("../ForestAmbience"))
	var we: WorldEnvironment = level_scene.get_node("WorldEnvironment")
	rain.set("sky_material", we.environment.sky.sky_material)
	rain.set("rain_stream", _rain_stream())
	rain.set("thunder_stream", _thunder_stream())
	level_scene.add_child(rain)


# ======================================================================================
#  Gameplay
# ======================================================================================

func _place_gameplay(level_scene: Node3D) -> void:
	var gate_scene: PackedScene = load("res://CheckpointGate.tscn")
	var spawn_scene: PackedScene = load("res://SpawnIndicator.tscn")
	var finish_s: float = _seg_s(SEG_START, 0.0) + FINISH_OFF
	var fl: Dictionary = _spot(finish_s, 0.0, 0.06)
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

	# Checkpoints: out of the Matope, up the ridge, over the bridge, between the hairpins, out of
	# the Nyoka and down the gorge, so a respawn never skips a hairpin.
	var checkpoints_container := Node3D.new()
	checkpoints_container.name = "Checkpoints"
	level_scene.add_child(checkpoints_container)
	var cp_offs: Array = [
		_seg_s(7, 0.5),
		_seg_s(12, 0.5),
		_bridge_s1 + 40.0,
		_seg_s(24, 0.5),
		_seg_s(27, 0.8),
		_seg_s(SEG_GORGE, 0.6),
	]
	cp_offs.sort()
	for i in range(cp_offs.size()):
		var c: Dictionary = _spot(cp_offs[i], 0.0, 0.1)
		var gate = gate_scene.instantiate()
		gate.name = "Checkpoint_%d" % (i + 1)
		gate.position = c["pos"]
		gate.rotation_degrees = Vector3(0, c["yaw"], 0)
		checkpoints_container.add_child(gate)
		print("  checkpoint %d at %.0fm" % [i + 1, cp_offs[i]])

	# Boost pads: out of the falls onto the gorge road, the run up the ridge, the bridge road
	# before the bridge (carry speed over the sag), out of the Matope.
	var boost_scene: PackedScene = load("res://BoostPad.tscn")
	var boost_container := Node3D.new()
	boost_container.name = "BoostPads"
	level_scene.add_child(boost_container)
	var bp_defs: Array = [
		["Boost_Gorge_L", _seg_s(SEG_GORGE, 0.4), -3.0],
		["Boost_Gorge_R", _seg_s(SEG_GORGE, 0.4), 3.0],
		["Boost_Ridge", _seg_s(10, 0.3), 0.0],
		["Boost_Daraja_L", _bridge_s0 - 70.0, -3.0],
		["Boost_Daraja_R", _bridge_s0 - 70.0, 3.0],
		["Boost_Matope", _seg_s(6, 0.6), 2.5],
	]
	for bd in bp_defs:
		var bp = boost_scene.instantiate()
		bp.name = bd[0]
		var sp2: Dictionary = _spot(bd[1], bd[2], 0.08)
		bp.position = sp2["pos"]
		bp.rotation_degrees = Vector3(0, sp2["yaw"], 0)
		boost_container.add_child(bp)

	# Item boxes in rows on calm stretches.
	var item_scene: PackedScene = load("res://ItemBox.tscn")
	var item_container := Node3D.new()
	item_container.name = "ItemBoxes"
	level_scene.add_child(item_container)
	var item_rows := [finish_s + 70.0, _seg_s(8, 0.5), _seg_s(14, 0.4), _bridge_s1 + 70.0, _seg_s(24, 0.3), _seg_s(28, 0.5)]
	var item_idx := 1
	for off in item_rows:
		for lat in [-4.5, 0.0, 4.5]:
			var ib = item_scene.instantiate()
			ib.name = "ItemBox_%d" % item_idx
			var s2: Dictionary = _spot(off, lat, 1.4)
			ib.position = s2["pos"]
			item_container.add_child(ib)
			item_idx += 1


# ======================================================================================
#  Sky and light
# ======================================================================================

## Humid haze: pale and a little green, the colour the forest's breath gives the distance.
const HAZE := Color(0.66, 0.74, 0.70)

func _build_environment(level_scene: Node3D) -> void:
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://sky_tropical_cumulus.gdshader")
	sky_mat.set_shader_parameter("sky_top", Color(0.16, 0.40, 0.78))
	sky_mat.set_shader_parameter("sky_horizon", Color(0.74, 0.84, 0.84))
	sky_mat.set_shader_parameter("ground_horizon", HAZE)
	sky_mat.set_shader_parameter("ground_bottom", Color(0.36, 0.42, 0.36))
	sky_mat.set_shader_parameter("sky_curve", 0.3)
	sky_mat.set_shader_parameter("horizon_haze", HAZE)
	sky_mat.set_shader_parameter("haze_strength", 0.85)
	sky_mat.set_shader_parameter("haze_height", 0.22)
	sky_mat.set_shader_parameter("sun_tint", Color(1.0, 0.94, 0.80))
	sky_mat.set_shader_parameter("sun_disc_degrees", 1.0)
	sky_mat.set_shader_parameter("sun_glow", 0.55)
	sky_mat.set_shader_parameter("cloud_lit", Color(1.0, 0.98, 0.94))
	sky_mat.set_shader_parameter("cloud_shade", Color(0.42, 0.50, 0.62))
	sky_mat.set_shader_parameter("cloud_coverage", 0.55)
	sky_mat.set_shader_parameter("cloud_opacity", 0.95)
	sky_mat.set_shader_parameter("cloud_seed", 41.7)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.6
	env.ambient_light_color = Color(0.86, 0.94, 0.86)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.1
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = HAZE
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.25
	env.fog_density = 1.0
	env.fog_depth_begin = 90.0
	env.fog_depth_end = 1700.0
	env.fog_depth_curve = 1.15
	env.fog_sky_affect = 0.06
	env.fog_aerial_perspective = 0.35
	env_node.environment = env
	level_scene.add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	# Mid-morning, from the east-north-east: it shines down the gorge and lights the falls.
	sun.rotation_degrees = Vector3(-38.0, 62.0, 0.0)
	sun.light_color = Color(1.0, 0.95, 0.84)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 240.0
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
	print("=== Msitu Falls (Matumaini GP) Level Generation ===")
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

	# 1. The plan, its heights and its checks.
	_build_plan()
	_build_profile()
	_verify_min_radius()
	_verify_layout()
	var lip_z: float = float(UPPER_RIVER[UPPER_RIVER.size() - 1][1])
	if absf(lip_z - (_face_z() + FALLS_OVERHANG)) > 0.01:
		push_error("UPPER_RIVER ends at z=%.1f, but the lip is at z=%.1f" % [lip_z, _face_z() + FALLS_OVERHANG])
	print("  falls road at z=%.0f, cliff face z=%.0f, pool (%.0f, %.0f); bridge s=%.0f..%.0f, mud s=%.0f..%.0f" % [
		_falls_z(), _face_z(), _pool_centre().x, _pool_centre().y, _bridge_s0, _bridge_s1, _mud_s0, _mud_s1])

	# 2. Track path.
	main_curve = _build_main_curve()
	var track_path := Path3D.new()
	track_path.name = "TrackPath"
	track_path.curve = main_curve
	level_scene.add_child(track_path)

	# 3. Ground.
	_build_gorge_table()
	_add_road_samples()
	_build_road_field()
	print("  road field built (%.1fs)" % ((Time.get_ticks_msec() - t_start) / 1000.0))
	_build_heights()
	print("  heights built (%.1fs)" % ((Time.get_ticks_msec() - t_start) / 1000.0))
	var ground_mat := ShaderMaterial.new()
	ground_mat.shader = load("res://jungle_ground.gdshader")
	ground_mat.set_shader_parameter("soil_tex", load("res://materials/dirt.png"))
	ground_mat.set_shader_parameter("soil_normal", load("res://materials/dirt_normal.png"))
	ground_mat.set_shader_parameter("moss_tex", load("res://materials/grass.png"))
	ground_mat.set_shader_parameter("laterite_tex", load("res://materials/dark_canyon_rock.png"))
	ground_mat.set_shader_parameter("rock_tex", load("res://materials/dark_rock.png"))
	ground_mat.set_shader_parameter("road_half_width", ROAD_HALF)
	ground_mat.set_shader_parameter("horizon_color", HAZE)
	ground_mat.set_shader_parameter("forest_min", Vector2(FINE_X.x, FINE_Z.x))
	ground_mat.set_shader_parameter("forest_max", Vector2(FINE_X.y, FINE_Z.y))
	# Saved on its own, so every terrain chunk shares this one material and the rain
	# (JungleRain.gd) wets them all through it.
	ground_mat = _save_baked_resource(ground_mat, "ground_material")
	_ground_mat = ground_mat
	var terrain_root := Node3D.new()
	terrain_root.name = "TerrainEnvironment"
	level_scene.add_child(terrain_root)
	_build_terrain(terrain_root, ground_mat)
	print("  terrain built (%.1fs)" % ((Time.get_ticks_msec() - t_start) / 1000.0))
	_verify_road_ground()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("dump="):
			_dump_map(arg.substr(5))

	# 4. Water and the falls.
	_build_water(level_scene)
	var rock_mat := ShaderMaterial.new()
	rock_mat.shader = ground_mat.shader
	for prm in ["soil_tex", "soil_normal", "moss_tex", "laterite_tex", "rock_tex"]:
		rock_mat.set_shader_parameter(prm, ground_mat.get_shader_parameter(prm))
	_build_falls(level_scene, rock_mat)
	_build_boulders(level_scene.get_node("Waterfall"), rock_mat)
	_verify_falls()
	_build_bridge(level_scene)

	# 5. The forest.
	var dressing := Node3D.new()
	# Not "Props"/"Vegetation"/"Environment": Level.gd bakes trimesh colliders for those names.
	dressing.name = "JungleDressing"
	level_scene.add_child(dressing)
	_build_forest(dressing)
	_build_mugumo(dressing)
	_build_chevrons(dressing)
	_build_hairpin_barriers(dressing)
	_build_marker_posts(dressing)
	_build_start_area(dressing)

	# 6. Sky, light, gameplay.
	_build_environment(level_scene)
	_build_ambience(level_scene)
	_build_rain(level_scene, ground_mat)
	_place_gameplay(level_scene)

	# 7. Save.
	level_scene.set("track_path", track_path)
	level_scene._setup_checkpoints()
	var chunked: int = MeshChunker.chunk_scene(level_scene, "res://generated/" + RES_PREFIX, "res://generated/msitu_chunks", MESH_CHUNK_CELL)
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
