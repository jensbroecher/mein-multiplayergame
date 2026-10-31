# regenerate_canyon.gd
#
# Builds levels/CanyonLevel.tscn - the Canyon Course ("Canyon Drift"), first stage of the Sierra
# del Viento: red-rock canyon country, half of the lap on tarmac and half on gravel and dirt.
#
# The lap: the start/finish straight runs south down the river's west bank past the Parador del
# Viento, a filling station, and swings east over the river on the Puente, a steel truss bridge. On
# the east bank the road climbs the canyon wall on a shelf cut into the rock, turns back on itself at
# La Horquilla and comes up onto the mesa, where the tarmac ends. A gravel road runs out along La
# Cuchilla, a knife-edge ridge with the canyon country falling away on both sides into the haze. Off
# its end the trail drops down La Bajada, a gully with two kickers, into the Valle de los Duendes, a
# valley of hoodoos, and threads La Garganta, a slot canyon, down to the river. It fords the river at
# El Vado and climbs onto the west bank, where the tarmac starts again, and runs back to the line
# through El Arco del Viento, a sandstone arch over the road.
#
# Things worth knowing before editing this file:
#
# 1. The lap is planned as turtle moves (PLAN: straights and circular arcs, as on Msitu Falls and
#    Nyota Stadium). Two straights ("SV") have no fixed length: _build_plan() solves them so the lap
#    closes, one running north-south (the shelf road) and one east-west (out of the slot and over
#    the ford). Heights come from PROFILE, stations along the plan joined by a monotone cubic.
#
# 2. The river is laid through the plan, not the plan round the river: it passes under the middle
#    of the bridge and through the ford (_build_river), and the canyon's walls stand at offsets from
#    it (_canyon_frame), so moving the plan moves the canyon with it.
#
# 3. There is no road mesh except the bridge deck: the heightfield is graded flat under the road and
#    canyon_ground.gdshader paints it, tarmac or gravel (PAVED), from data baked into the vertices.
#    The deck carries the same data and material. The ground's collision is split by surface
#    (_build_terrain): the tarmac, each kind of dirt road, the river's sand and the open ground, each
#    with a "surface" meta (Surfaces.gd) and a dust colour; roads are named "...Road" so PlayerCart
#    counts them as track.
#
# 4. The heightfield is built in layers: the landscape (_base_height: the canyon walls, the mesa, the
#    ridge, the valleys, the fin the arch is cut through, the far mesas and mountains) -> carve the
#    river (_water_cap: a channel deepest toward the outside of each bend, gravel bars inside them, a
#    broad shallow riffle at the ford) -> clamp between every road's cut and fill bounds (_grade; the
#    slot canyon and the arch's cutting stand vertical) -> put the road strip back. The bridge span is
#    left out of the grading, so the river runs on under the deck.
#
# The menu tile (images/menu/tile_canyon.jpg) is a render of this level; the generator runs headless
# and cannot render (scratch/lap_shots.tscn renders the lap).
extends Node

const LEVEL_NAME := "CanyonLevel"
const LEVEL_PATH := "res://levels/CanyonLevel.tscn"
const RES_PREFIX := "canyon_"
const MeshChunker = preload("res://MeshChunker.gd")
const RiverWaterScript = preload("res://RiverWater.gd")
const PropKit = preload("res://PropKit.gd")
const CactusKit = preload("res://CactusKit.gd")
const SandstoneKit = preload("res://SandstoneKit.gd")
const Woodland = preload("res://WoodlandBuilder.gd")

const MESH_CHUNK_CELL := 80.0

## Painted road half width (the shader's road_half_width).
const ROAD_HALF := 7.0
## Ground within this of a road centreline goes into a road collision body.
const ROAD_COLLIDE := 7.9
## Half width of the strip graded flat to road height.
const ROAD_FLAT := 8.8
## The slot canyon's floor is graded this wide, its walls standing on it in front of the cut. The
## walls' feet reach out to 10.6m, and the heightfield's 2.5m cells rise from the floor's edge: with
## the floor ending less than a cell diagonal behind them (it was 11m), the cut's rising triangles
## stood in front of the walls' feet, a pale apron along both walls.
const SLOT_FLAT := 14.5
## The slot walls' tops reach out this far, over the trench between a wall and the cut behind it,
## and tuck under the ground there: past where the cut's triangles have reached the natural ground.
const SLOT_LIP := 20.0
## Embankments: the rise per metre of a cutting (sandstone stands steep) and the drop per metre of
## a fill (rubble at its angle of repose).
const CUT_SLOPE := 2.2
const FILL_SLOPE := 0.85
const GRADE_REACH := 60.0
## Road samples are bucketed in CELL x CELL squares for the lookups.
const CELL := 40.0
const SAMPLE_STEP := 2.0

## The lap as turtle moves from PLAN_START heading PLAN_HEADING (x east, z south): ["S", length],
## ["SV"] (a straight whose length _build_plan solves), or ["R"/"L", radius, degrees].
const PLAN_START := Vector2(-150.0, -80.0)
const PLAN_HEADING := PI * 0.5
const PLAN := [
	["S", 150.0],          # 0  the start/finish straight, south down the west bank
	["L", 70.0, 90.0],     # 1  turn one, east
	["S", 160.0],          # 2  over the Puente
	["L", 45.0, 90.0],     # 3  north onto the east bank
	["SV"],                # 4  the shelf road, up the canyon wall
	["R", 20.0, 180.0],    # 5  La Horquilla, the hairpin
	["S", 130.0],          # 6  on up the wall, south
	["L", 45.0, 90.0],     # 7  onto the mesa, east
	["S", 60.0],           # 8  the trailhead: the tarmac ends
	["R", 260.0, 14.0],    # 9  La Cuchilla, the ridge
	["S", 70.0],           # 10
	["L", 260.0, 14.0],    # 11
	["S", 90.0],           # 12 the crest
	["L", 45.0, 110.0],    # 13 off the end of the ridge, north
	["S", 120.0],          # 14 La Bajada, down the gully
	["L", 80.0, 30.0],     # 15
	["S", 110.0],          # 16
	["L", 90.0, 40.0],     # 17 into the Valle de los Duendes, west
	["S", 110.0],          # 18 through the hoodoos
	["R", 70.0, 35.0],     # 19 La Garganta, the slot canyon
	["L", 70.0, 35.0],     # 20
	["R", 70.0, 30.0],     # 21
	["L", 70.0, 30.0],     # 22
	["SV"],                # 23 out of the slot, over the ford (El Vado)
	["L", 55.0, 90.0],     # 24 south on the west bank
	["S", 170.0],          # 25 through El Arco to the line
]
const SEG_START := 0
const SEG_BRIDGE := 2
const SEG_SHELF := 4
const SEG_HAIRPIN := 5
const SEG_TRAILHEAD := 8
const SEG_RIDGE := [9, 10, 11, 12]
const SEG_DESCENT := [14, 15, 16]
const SEG_VALLEY := 18
const SEG_SLOT := [19, 20, 21, 22]
const SEG_FORD := 23
const SEG_ARCH := 25

## Where on its segment the ford crosses the river, and where the arch spans the road.
const FORD_FRAC := 0.6
const ARCH_FRAC := 0.42
## The tarmac: from the west bank (this far into the turn after the ford) round to this far into
## the trailhead straight. PAVED_BLEND is how long the crumbling edge between the two is.
const PAVED_FROM := [24, 0.25]
const PAVED_TO := [8, 0.35]
const PAVED_BLEND := 16.0

## Height stations: [segment, fraction along it, height]. The bridge and the ford add their own.
const PROFILE := [
	[0, 0.0, 7.2], [0, 1.0, 7.2], [1, 0.5, 7.6], [3, 0.6, 9.8], [4, 0.0, 10.4], [4, 1.0, 32.0],
	[5, 1.0, 33.0], [6, 1.0, 43.0], [7, 1.0, 44.4], [8, 1.0, 45.3], [10, 0.5, 47.8], [12, 0.25, 49.8],
	[12, 1.0, 48.6], [13, 1.0, 44.6], [14, 1.0, 32.5], [15, 1.0, 29.5], [16, 1.0, 19.0],
	[17, 1.0, 16.0], [18, 1.0, 14.2], [20, 1.0, 12.2], [22, 1.0, 10.4],
	[24, 0.6, 7.4], [25, 0.5, 7.3],
]

## The Puente: a through truss over the river, deck at BRIDGE_Y, BRIDGE_HALF_SPAN either side of
## the river's centreline along the road.
const BRIDGE_Y := 9.2
const BRIDGE_HALF_SPAN := 40.0
const BRIDGE_HALF_W := 6.6

## The river: its water surface, and its half width, which wanders between these along the reaches and
## widens round the bends. Over the ford it is FORD_HALF + 2, so the road climbs out of the water where
## its profile does (FORD_HALF + 3), and the bar under the road lies a hand's depth down (FORD_BED).
const RIVER_Y := 0.0
const RIVER_HALF_MIN := 11.0
const RIVER_HALF_MAX := 24.0
const FORD_HALF := 17.0
const FORD_BED := -0.32
## The channel's deepest line: shallow along the straight reaches, deep in the bends (where it swings
## toward the outside bank), a riffle over the ford.
const RIVER_DEPTH := Vector2(1.4, 3.4)
const FORD_DEPTH := 0.38
## Along the river, the ford's bar reaches this far either side of the crossing.
const FORD_REACH := 70.0

## The canyon: terraces either side of the river, the east wall up to the mesa, the west wall.
const TERRACE_W := 7.0
const TERRACE_E := 9.0
const MESA_Y := 44.0
const WEST_TOP := 36.0
## The ridge's crest stands this far over the road; its flanks fall at RIDGE_FLANK per metre.
const RIDGE_CROWN := 0.8
const RIDGE_FLANK := 0.62
const VALLEY_N_Y := 14.0
const VALLEY_S_Y := 10.0

## Terrain grid: fine round the lap, cells growing outward to the horizon.
const FINE_X := Vector2(-320.0, 740.0)
const FINE_Z := Vector2(-720.0, 470.0)
const FINE_STEP := 2.5
const OUTER_X := Vector2(-6000.0, 6500.0)
const OUTER_Z := Vector2(-6500.0, 6000.0)
const COARSE_GROWTH := 1.16
const COARSE_MAX := 160.0
## The landscape's centre, for the far mesas and the mountains.
const CENTRE := Vector2(200.0, -110.0)

const FINISH_OFF := 45.0
const EAGLE_SCALE := 6.5

var _segs: Array = []
var _lap_len := 0.0
var _prof_s := PackedFloat32Array()
var _prof_y := PackedFloat32Array()
var _prof_m := PackedFloat32Array()
var _bridge_s0 := 0.0
var _bridge_s1 := 0.0
var _ford_s := 0.0
var _arch_s := 0.0
var _paved_s0 := 0.0
var _paved_s1 := 0.0
var main_curve: Curve3D

var _base_noise := FastNoiseLite.new()
var _detail_noise := FastNoiseLite.new()
var _far_noise := FastNoiseLite.new()
var _ridge_noise := FastNoiseLite.new()

# Road samples every SAMPLE_STEP metres along the lap.
var _rs_pos := PackedVector3Array()
var _rs_right := PackedVector3Array()
var _rs_s := PackedFloat32Array()
## 1 over the bridge span: not graded, not ground road.
var _rs_gap := PackedByteArray()
## Per sample: how steep its cutting may stand (CUT_SLOPE, or near vertical in the slot and the arch).
var _rs_cut := PackedFloat32Array()
## Per sample: half width of the strip graded flat (wider in the slot, whose walls stand on it).
var _rs_flat := PackedFloat32Array()
var _rs_cells := {}

# The river, sampled every 4m from north to south: centre, half width, distance along it; how it bends
# (1/radius, + where the inside of the bend is east, the + side of _river_frame's lateral, smoothed over
# 80m), how deep its channel runs, and how much of the ford's bar it is (1 at the crossing).
var _rv_pts := PackedVector2Array()
var _rv_hw := PackedFloat32Array()
var _rv_along := PackedFloat32Array()
var _rv_bend := PackedFloat32Array()
var _rv_depth := PackedFloat32Array()
var _rv_ford := PackedFloat32Array()
var _river_noise := FastNoiseLite.new()
var _rv_cells := {}
var _ford_along := 0.0
var _bridge_along := 0.0

var _grid_x := PackedFloat32Array()
var _grid_z := PackedFloat32Array()
var _heights := PackedFloat32Array()
var _road_d := PackedFloat32Array()
var _vert_lat := PackedFloat32Array()
var _vert_s := PackedFloat32Array()
## The river's frame at each grid vertex (_river_frame), kept from _build_heights for the masks.
var _rv_at := PackedVector3Array()
var _ground_mat: ShaderMaterial
var _rock_mat: ShaderMaterial


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
	if a < 60.0 or b < 60.0:
		push_error("The plan only closes with straights of %.0fm and %.0fm" % [a, b])
	var w: Dictionary = _walk([a, b])
	_segs = w["segs"]
	_lap_len = w["len"]
	var gap: float = (w["end"] as Vector2).distance_to(PLAN_START)
	var turn: float = absf(wrapf(float(w["th"]) - PLAN_HEADING, -PI, PI))
	if gap > 0.01 or turn > 0.001:
		push_error("The plan does not close: ends %.2fm and %.2f deg from its start" % [gap, rad_to_deg(turn)])
	print("  lap %.0fm in %d segments (shelf road %.0fm, ford straight %.0fm)" % [_lap_len, _segs.size(), a, b])


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


func _plan_p(s: float) -> Vector2:
	return _plan_at(s)["p"]


# ======================================================================================
#  Height profile
# ======================================================================================

## The stations as (s, y) with the bridge's and the ford's added, wrapped round the lap, and the
## slopes of the monotone cubic (Fritsch-Carlson) through them.
func _build_profile() -> void:
	var st: Array = []
	for p in PROFILE:
		st.append(Vector2(_seg_s(int(p[0]), float(p[1])), float(p[2])))
	# The deck runs level over the span and its approaches.
	st.append(Vector2(_bridge_s0 - 22.0, BRIDGE_Y - 0.4))
	st.append(Vector2(_bridge_s0, BRIDGE_Y))
	st.append(Vector2(_bridge_s1, BRIDGE_Y))
	st.append(Vector2(_bridge_s1 + 22.0, BRIDGE_Y + 0.2))
	# Down to the ford, across its bar a hand's depth under the water, and up the far bank.
	var drop: float = FORD_HALF + 3.0
	st.append(Vector2(_ford_s - 105.0, 9.4))
	st.append(Vector2(_ford_s - 62.0, 4.9))
	st.append(Vector2(_ford_s - drop, 0.45))
	st.append(Vector2(_ford_s - drop + 6.0, FORD_BED + 0.05))
	st.append(Vector2(_ford_s + drop - 6.0, FORD_BED + 0.05))
	st.append(Vector2(_ford_s + drop, 0.45))
	st.append(Vector2(_ford_s + 58.0, 3.8))
	st.append(Vector2(_ford_s + 95.0, 7.0))
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


## Height of the road centreline at arc length s.
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
	return (2.0 * t3 - 3.0 * t2 + 1.0) * _prof_y[lo] + (t3 - 2.0 * t2 + t) * h * _prof_m[lo] \
			+ (-2.0 * t3 + 3.0 * t2) * _prof_y[lo + 1] + (t3 - t2) * h * _prof_m[lo + 1]


func _on_bridge(s: float) -> bool:
	s = fposmod(s, _lap_len)
	return s > _bridge_s0 and s < _bridge_s1


## 1 where the road is paved at s, 0 on gravel, the crumbling edge between over PAVED_BLEND. The
## tarmac wraps through s = 0: from _paved_s0 round to _paved_s1.
func _paved_at(s: float) -> float:
	s = fposmod(s, _lap_len)
	var into: float
	if s >= _paved_s0:
		into = minf(s - _paved_s0, _lap_len - s + _paved_s1)
	elif s <= _paved_s1:
		into = minf(_paved_s1 - s, s + _lap_len - _paved_s0)
	else:
		into = -minf(s - _paved_s1, _paved_s0 - s)
	return smoothstep(-PAVED_BLEND * 0.5, PAVED_BLEND * 0.5, into)


## The road's surface (Surfaces.gd name) and its body at s.
func _road_kind(s: float) -> String:
	if _paved_at(s) >= 0.5:
		return "tarmac"
	var seg: int = _seg_index(s)
	if seg == SEG_FORD:
		return "ford"
	if seg >= 19 and seg <= 22:
		return "slot"
	if seg >= 14:
		return "dirt"
	return "gravel"


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
		var p2: Vector2 = _plan_p(s)
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

## Parts of the lap more than 120m apart along it must stand clear of each other, unless one passes
## well over the other.
func _verify_layout() -> void:
	var worst := INF
	var worst_s := Vector2.ZERO
	var s := 0.0
	while s < _lap_len:
		var a: Vector2 = _plan_p(s)
		var ya: float = _road_y(s)
		var s2 := 0.0
		while s2 < _lap_len:
			var ds: float = absf(s2 - s)
			ds = minf(ds, _lap_len - ds)
			if ds > 120.0:
				var d: float = a.distance_to(_plan_p(s2))
				var dy: float = absf(_road_y(s2) - ya)
				var need: float = 2.0 * ROAD_FLAT + dy * 0.6 if dy < 25.0 else 2.0 * ROAD_FLAT + 8.0
				if d - need < worst:
					worst = d - need
					worst_s = Vector2(s, s2)
			s2 += 4.0
		s += 4.0
	print("  layout: tightest margin between two parts of the lap %.1fm (s=%.0f and %.0f)" % [worst, worst_s.x, worst_s.y])
	if worst < 0.0:
		push_error("Two parts of the lap pass too close: s=%.0f and s=%.0f" % [worst_s.x, worst_s.y])


## Steepest grade along the road and across it, and road samples the ground doesn't match (the
## bridge span left out).
func _verify_road_ground() -> void:
	var worst_grade := 0.0
	var worst_grade_at := 0.0
	var worst_cross := 0.0
	var worst_cross_at := Vector3.ZERO
	var worst_cross_s := 0.0
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
				worst_cross_s = s
			if absf(g0 - p.y) > 0.3:
				off_ground += 1
				if off_ground <= 6:
					push_error("Ground at s=%.0f (%.0f, %.0f) is %.2fm off the road" % [s, p.x, p.z, g0 - p.y])
		s += 2.0
	print("  road: steepest grade %.1f%% at s=%.0f, steepest cross slope %.1f%% at s=%.0f (%.0f, %.0f), %d samples off the ground" % [
		worst_grade * 100.0, worst_grade_at, worst_cross * 100.0, worst_cross_s, worst_cross_at.x, worst_cross_at.z, off_ground])
	var sp2: Dictionary = _spot(worst_cross_s, 0.0, 0.0)
	var line := "    across it:"
	for l in [-10.0, -8.0, -6.0, -4.0, -2.0, 0.0, 2.0, 4.0, 6.0, 8.0, 10.0]:
		var q: Vector3 = (sp2["pos"] as Vector3) + (sp2["right"] as Vector3) * l
		line += " %+.0f:%.2f" % [l, _ground_at(q.x, q.z) - (sp2["pos"] as Vector3).y]
	print(line)
	if worst_grade > 0.15 or worst_cross > 0.08:
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
#  The river
# ======================================================================================

## The river's centreline: through the ford and under the middle of the bridge, on north and
## south out of sight round the canyon's bends. Catmull-Rom through the control points, sampled
## every 4m from north to south.
func _build_river() -> void:
	var f: Vector2 = _plan_p(_ford_s)
	var b: Vector2 = _plan_p((_bridge_s0 + _bridge_s1) * 0.5)
	var ctrl: Array = [
		f + Vector2(-260.0, -3300.0), f + Vector2(-80.0, -2500.0), f + Vector2(110.0, -1850.0),
		f + Vector2(-90.0, -1300.0), f + Vector2(60.0, -840.0), f + Vector2(-40.0, -480.0), f + Vector2(14.0, -210.0), f,
		(f + b) * 0.5 + Vector2(-14.0, 0.0), b,
		b + Vector2(30.0, 300.0), b + Vector2(-50.0, 620.0), b + Vector2(80.0, 1050.0), b + Vector2(-90.0, 1600.0),
		b + Vector2(70.0, 2250.0), b + Vector2(-80.0, 3000.0),
	]
	_rv_pts = PackedVector2Array()
	for i in range(ctrl.size() - 1):
		var p0: Vector2 = ctrl[maxi(i - 1, 0)]
		var p1: Vector2 = ctrl[i]
		var p2: Vector2 = ctrl[i + 1]
		var p3: Vector2 = ctrl[mini(i + 2, ctrl.size() - 1)]
		var steps: int = maxi(2, int(p1.distance_to(p2) / 4.0))
		for k in range(steps):
			var t: float = float(k) / float(steps)
			var t2: float = t * t
			var t3: float = t2 * t
			_rv_pts.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	_rv_pts.append(ctrl[ctrl.size() - 1])
	# Meanders: between the big bends the river swings from side to side (wavelength and swing
	# wandering along it), except near the ford and under the bridge, where it passes where the
	# road crosses. Without them the reaches ran straight between parallel banks, like a canal.
	var cum := PackedFloat32Array()
	cum.resize(_rv_pts.size())
	for i in range(1, _rv_pts.size()):
		cum[i] = cum[i - 1] + _rv_pts[i].distance_to(_rv_pts[i - 1])
	var near_ford: int = 0
	var near_bridge: int = 0
	for i in range(_rv_pts.size()):
		if _rv_pts[i].distance_to(f) < _rv_pts[near_ford].distance_to(f):
			near_ford = i
		if _rv_pts[i].distance_to(b) < _rv_pts[near_bridge].distance_to(b):
			near_bridge = i
	var phase := 0.0
	var swung := PackedVector2Array()
	swung.resize(_rv_pts.size())
	for i in range(_rv_pts.size()):
		var al: float = cum[i]
		if i > 0:
			var wavelength: float = lerpf(180.0, 300.0, _river_noise.get_noise_1d(al * 0.002 + 90.0) * 0.5 + 0.5)
			phase += (cum[i] - cum[i - 1]) * TAU / wavelength
		var swing: float = 9.0 + 8.0 * (_river_noise.get_noise_1d(al * 0.003 + 140.0) * 0.5 + 0.5)
		var keep: float = smoothstep(55.0, 170.0, absf(al - cum[near_ford])) * smoothstep(55.0, 170.0, absf(al - cum[near_bridge]))
		var tng: Vector2 = (_rv_pts[mini(i + 1, _rv_pts.size() - 1)] - _rv_pts[maxi(i - 1, 0)]).normalized()
		swung[i] = _rv_pts[i] + Vector2(-tng.y, tng.x) * sin(phase) * swing * keep
	_rv_pts = swung
	_rv_along = PackedFloat32Array()
	_rv_along.resize(_rv_pts.size())
	var acc := 0.0
	for i in range(_rv_pts.size()):
		if i > 0:
			acc += _rv_pts[i].distance_to(_rv_pts[i - 1])
		_rv_along[i] = acc
	_rv_cells.clear()
	for i in range(_rv_pts.size() - 1):
		var key := Vector2i(floori(_rv_pts[i].x / 80.0), floori(_rv_pts[i].y / 80.0))
		var bucket: PackedInt32Array = _rv_cells.get(key, PackedInt32Array())
		bucket.append(i)
		_rv_cells[key] = bucket
	var n: int = _rv_pts.size()
	_rv_hw = PackedFloat32Array()
	_rv_hw.resize(n)
	_rv_hw.fill(RIVER_HALF_MIN)
	_ford_along = _river_frame(f.x, f.y).z
	_bridge_along = _river_frame(b.x, b.y).z
	# How it bends at each point: the chord's midpoint lies toward the inside of the bend, and its
	# offset gives the radius. Signed by which side of the river that is, as _river_frame signs it.
	var raw := PackedFloat32Array()
	raw.resize(n)
	for i in range(1, n - 1):
		var a0: Vector2 = _rv_pts[i - 1]
		var p: Vector2 = _rv_pts[i]
		var a1: Vector2 = _rv_pts[i + 1]
		var chord: float = a0.distance_to(a1)
		var m: Vector2 = (a0 + a1) * 0.5
		var tng: Vector2 = (a1 - a0) / maxf(chord, 0.001)
		var side: float = -signf(tng.x * (m.y - p.y) - tng.y * (m.x - p.x))
		raw[i] = side * 8.0 * m.distance_to(p) / maxf(chord * chord, 0.001)
	_rv_bend = PackedFloat32Array()
	_rv_bend.resize(n)
	_rv_depth = PackedFloat32Array()
	_rv_depth.resize(n)
	_rv_ford = PackedFloat32Array()
	_rv_ford.resize(n)
	for i in range(n):
		var sum := 0.0
		var cnt := 0
		for k in range(maxi(i - 10, 1), mini(i + 11, n - 1)):
			sum += raw[k]
			cnt += 1
		_rv_bend[i] = sum / maxf(cnt, 1)
		var along: float = _rv_along[i]
		# 1 round a bend of 250m radius or tighter.
		var bendy: float = clampf(absf(_rv_bend[i]) * 250.0, 0.0, 1.0)
		var reach: float = _river_noise.get_noise_1d(along * 0.0045) * 0.5 + 0.5
		var ripple: float = _river_noise.get_noise_1d(along * 0.03 + 500.0)
		var hw: float = lerpf(RIVER_HALF_MIN, RIVER_HALF_MAX, clampf(reach * 0.75 + bendy * 0.4, 0.0, 1.0)) + ripple * 2.0
		var depth: float = lerpf(RIVER_DEPTH.x, RIVER_DEPTH.y, clampf(bendy * 0.8 + (1.0 - reach) * 0.3, 0.0, 1.0))
		var at_ford: float = 1.0 - smoothstep(FORD_REACH * 0.6, FORD_REACH * 1.4, absf(along - _ford_along))
		# The old gorge's width under the bridge (see _water_cap).
		var at_bridge: float = 1.0 - smoothstep(60.0, 140.0, absf(along - _bridge_along))
		hw = lerpf(hw, 20.0, at_bridge)
		depth = lerpf(depth, 3.0, at_bridge)
		_rv_hw[i] = lerpf(hw, FORD_HALF + 2.0, at_ford)
		_rv_depth[i] = lerpf(depth, FORD_DEPTH, at_ford)
		_rv_ford[i] = at_ford
	print("  river %.0fm long, ford %.0fm and bridge %.0fm along it" % [acc, _ford_along, _bridge_along])


## The river's bend, channel depth and ford weight `along` it (see _rv_bend).
func _river_params(along: float) -> Vector3:
	var lo := 0
	var hi: int = _rv_along.size() - 1
	while lo < hi:
		var mid: int = (lo + hi) >> 1
		if _rv_along[mid] < along:
			lo = mid + 1
		else:
			hi = mid
	var i1: int = clampi(lo, 1, _rv_along.size() - 1)
	var i0: int = i1 - 1
	var t: float = clampf((along - _rv_along[i0]) / maxf(_rv_along[i1] - _rv_along[i0], 0.001), 0.0, 1.0)
	return Vector3(lerpf(_rv_bend[i0], _rv_bend[i1], t), lerpf(_rv_depth[i0], _rv_depth[i1], t), lerpf(_rv_ford[i0], _rv_ford[i1], t))


## (signed distance from the river's centreline, + east of it; its half width there; distance along
## it). Near the river the nearest segment is searched; further off (no sample within 160m) the
## river's x at the same z stands in, since it runs north to south.
func _river_frame(x: float, z: float) -> Vector3:
	var cx: int = floori(x / 80.0)
	var cz: int = floori(z / 80.0)
	var best := 1e18
	var bi := -1
	var bt := 0.0
	for gz in range(cz - 2, cz + 3):
		for gx in range(cx - 2, cx + 3):
			var bucket: PackedInt32Array = _rv_cells.get(Vector2i(gx, gz), PackedInt32Array())
			for i in bucket:
				var a: Vector2 = _rv_pts[i]
				var ab: Vector2 = _rv_pts[i + 1] - a
				var t: float = clampf(((x - a.x) * ab.x + (z - a.y) * ab.y) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
				var q: Vector2 = a + ab * t
				var d2: float = (x - q.x) * (x - q.x) + (z - q.y) * (z - q.y)
				if d2 < best:
					best = d2
					bi = i
					bt = t
	if bi < 0:
		var lo := 0
		var hi: int = _rv_pts.size() - 1
		while lo < hi:
			var mid: int = (lo + hi) >> 1
			if _rv_pts[mid].y < z:
				lo = mid + 1
			else:
				hi = mid
		return Vector3(x - _rv_pts[lo].x, _rv_hw[lo], _rv_along[lo])
	var a2: Vector2 = _rv_pts[bi]
	var ab2: Vector2 = _rv_pts[bi + 1] - a2
	# The river runs north to south (+z), so east (+x) is on its left: + where ab x (p - a) < 0.
	var side: float = signf(ab2.x * (z - a2.y) - ab2.y * (x - a2.x))
	var hw: float = lerpf(_rv_hw[bi], _rv_hw[bi + 1], bt)
	return Vector3(-side * sqrt(best), hw, lerpf(_rv_along[bi], _rv_along[bi + 1], bt))


# ======================================================================================
#  Landscape
# ======================================================================================

func _init_noise() -> void:
	_base_noise.seed = 7310
	_base_noise.frequency = 0.004
	_base_noise.fractal_octaves = 3
	_detail_noise.seed = 1913
	_detail_noise.frequency = 0.03
	_detail_noise.fractal_octaves = 2
	_far_noise.seed = 551
	_far_noise.frequency = 0.0009
	_far_noise.fractal_octaves = 4
	# Sampled at its own scales (frequency 1): the river's width along it, the shore's wiggle.
	_river_noise.seed = 3407
	_river_noise.frequency = 1.0
	_river_noise.fractal_octaves = 2
	_ridge_noise.seed = 2777
	_ridge_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_ridge_noise.frequency = 0.00045
	_ridge_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridge_noise.fractal_octaves = 5


## A canyon wall's profile, 0 at its foot to 1 at its rim (u), in steps: a cliff (riser) over each
## ledge and its talus (tread), the way beds of sandstone weather. `ledges` how many steps, `riser`
## how much of each step's width the cliff takes; it takes 85% of the step's rise.
func _stepped(u: float, ledges: float, riser: float) -> float:
	u = clampf(u, 0.0, 1.0)
	var t: float = u * ledges
	var i: float = floor(t)
	var f: float = t - i
	var tread: float = 1.0 - riser
	var g: float = f * 0.15 / tread if f < tread else 0.15 + 0.85 * smoothstep(tread, 1.0, f)
	return clampf((i + g) / ledges, 0.0, 1.0)


func _seg_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Signed distance from p to a closed polygon (negative inside).
func _poly_sdf(p: Vector2, poly: Array) -> float:
	var d := INF
	var inside := false
	var n: int = poly.size()
	for i in range(n):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		d = minf(d, _seg_distance(p, a, b))
		if (a.y > p.y) != (b.y > p.y) and p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x:
			inside = not inside
	return -d if inside else d


## The valley of the hoodoos, north of the ridge, and the open valley south of it: outlines (x, z).
const VALLEY_N := [Vector2(312, -70), Vector2(560, -60), Vector2(690, -120), Vector2(720, -250),
	Vector2(660, -385), Vector2(420, -392), Vector2(318, -360), Vector2(300, -230)]
const VALLEY_S := [Vector2(330, 40), Vector2(640, 46), Vector2(900, 120), Vector2(980, 600),
	Vector2(420, 700), Vector2(318, 260)]
## The fin El Arco is cut through: from the west wall east toward the river, crest height over the
## terrace and half width at its foot.
const FIN_A := Vector2(-300.0, -212.0)
const FIN_B := Vector2(-88.0, -196.0)
const FIN_HEIGHT := 21.0
const FIN_HALF := 15.0

## The landscape before any road or water: the terraces either side of the river and the canyon
## walls above them, the mesa, the ridge and the valleys either side of it, the fin of El Arco, and
## mesas and mountains toward the horizon.
func _base_height(x: float, z: float, rf: Vector3 = Vector3(NAN, 0, 0)) -> float:
	var p := Vector2(x, z)
	var n1: float = _base_noise.get_noise_2d(x, z)
	var n2: float = _detail_noise.get_noise_2d(x, z)
	if is_nan(rf.x):
		rf = _river_frame(x, z)
	var lat: float = rf.x
	var along: float = rf.z
	var h: float
	if lat >= 0.0:
		# East: the terrace, then the wall up to the mesa. Its foot stands well back from the river
		# by the bridge, where the road runs along under it, and closes in to the north, where the
		# slot canyon comes out of it just above the ford.
		var foot: float = lerpf(42.0, 108.0, smoothstep(_ford_along - 60.0, _bridge_along, along))
		foot += n1 * 8.0
		var u: float = (lat - foot) / (100.0 + n1 * 15.0)
		h = lerpf(TERRACE_E + n2 * 0.5, MESA_Y + n1 * 1.5, _stepped(u, 3.0, 0.15))
	else:
		# West: the terrace the start straight runs down, then the west wall.
		var foot_w: float = 248.0 + n1 * 10.0
		var u_w: float = (-lat - foot_w) / (60.0 + n1 * 10.0)
		h = lerpf(TERRACE_W + n2 * 0.4, WEST_TOP + n1 * 2.0, _stepped(u_w, 2.0, 0.16))
	# The valleys either side of the ridge, cut down from the mesa.
	var vn: float = _poly_sdf(p, VALLEY_N)
	var vs: float = _poly_sdf(p, VALLEY_S)
	if vn < 60.0:
		var floor_n: float = VALLEY_N_Y + smoothstep(320.0, 680.0, x) * 3.0 + n1 * 1.2
		h = minf(h, lerpf(floor_n, h, _stepped((vn + 12.0) / 70.0, 3.0, 0.16)))
	if vs < 60.0:
		h = minf(h, lerpf(VALLEY_S_Y + n1 * 1.5, h, _stepped((vs + 12.0) / 70.0, 3.0, 0.16)))
	# La Cuchilla: out here there is no mesa, only the ridge, its crest just over the road and its
	# flanks dropping steeply off it (cliff bands, then scree) to the valley floors either side.
	var rg: Vector3 = _ridge_at(p)
	if rg.x < 220.0:
		var crest: float = rg.y + RIDGE_CROWN
		var off: float = maxf(0.0, rg.x - 10.0)
		var drop: float = minf(off, 22.0) * 1.15 + maxf(off - 22.0, 0.0) * 0.45
		drop += _stepped(off / 30.0, 3.0, 0.35) * 3.0 - 1.5
		var side_floor: float = (VALLEY_N_Y + smoothstep(320.0, 680.0, x) * 3.0) if z < _ridge_z_at(x) else VALLEY_S_Y
		var ridge_h: float = maxf(crest - drop * (1.0 + n2 * 0.12) - maxf(0.0, rg.z) * 0.55, side_floor + n1 * 1.2)
		# Into the mesa at its west end; out on its own east of it.
		var w: float = smoothstep(_ridge_x0 + 15.0, _ridge_x0 + 60.0, x) * (1.0 - smoothstep(170.0, 220.0, rg.x))
		h = lerpf(h, ridge_h, w)
	# Inside the hairpin the rock is worn down to a low knoll.
	for hp in _hairpins:
		var dh: float = p.distance_to(hp[0])
		if dh < float(hp[1]) + 6.0:
			var knoll: float = float(hp[2]) + 1.2 + maxf(0.0, float(hp[1]) - 8.0 - dh) * 0.45 + n2 * 0.8
			h = minf(h, lerpf(knoll, h, smoothstep(float(hp[1]) - 2.0, float(hp[1]) + 6.0, dh)))
	# The fin El Arco is cut through.
	var fd: float = _seg_distance(p, FIN_A, FIN_B)
	if fd < FIN_HALF * 2.5:
		var along_fin: float = clampf((p - FIN_A).dot(FIN_B - FIN_A) / (FIN_B - FIN_A).length_squared(), 0.0, 1.0)
		var top: float = TERRACE_W + FIN_HEIGHT * (1.0 - smoothstep(0.62, 1.0, along_fin)) + n2 * 1.2
		var fin_h: float = lerpf(top, TERRACE_W, smoothstep(FIN_HALF * 0.35, FIN_HALF, fd))
		h = maxf(h, fin_h)
	# Toward the horizon: a field of mesas and buttes, then mountains in the haze.
	var r: float = p.distance_to(CENTRE)
	var far_w: float = smoothstep(900.0, 1500.0, r)
	if far_w > 0.0:
		var m: float = _far_noise.get_noise_2d(x, z)
		var mesas: float = 10.0 + 46.0 * smoothstep(0.14, 0.165, m) + 32.0 * smoothstep(0.43, 0.455, m) + n1 * 3.0
		var mountains: float = smoothstep(1700.0, 4600.0, r) * (240.0 + 520.0 * (_ridge_noise.get_noise_2d(x, z) * 0.5 + 0.5))
		# The river runs on between them in a broad valley: the mountains and mesas stand back from it.
		var open: float = smoothstep(120.0, 900.0, absf(lat))
		h = lerpf(h, lerpf(TERRACE_W + n1 * 2.0, maxf(mesas, mountains), open), far_w)
	return h


## The ridge's crest line, tabulated by x (the crest runs east, never more than 14 degrees off):
## its z, the road's height and the cosine of its heading, every metre from _ridge_x0 to _ridge_x1.
## Each hairpin: [centre (x, z), radius, road height round it].
var _hairpins: Array = []

func _find_hairpins() -> void:
	_hairpins.clear()
	for seg in _segs:
		if seg["kind"] == "A" and absf(float(seg["len"]) / float(seg["r"])) > deg_to_rad(150.0):
			var c: Vector2 = (seg["p0"] as Vector2) + _right_of(float(seg["th0"])) * float(seg["r"]) * float(seg["sign"])
			_hairpins.append([c, float(seg["r"]), _road_y(float(seg["s0"]) + float(seg["len"]) * 0.5)])


var _ridge_x0 := 0.0
var _ridge_x1 := 0.0
var _ridge_z := PackedFloat32Array()
var _ridge_y := PackedFloat32Array()
var _ridge_c := PackedFloat32Array()

func _build_ridge_table() -> void:
	var s0: float = _seg_s(SEG_TRAILHEAD, 0.4)
	var s1: float = _seg_s(12, 1.0)
	_ridge_x0 = _plan_p(s0).x
	_ridge_x1 = _plan_p(s1).x
	var n: int = int(ceil(_ridge_x1 - _ridge_x0)) + 1
	_ridge_z.resize(n)
	_ridge_y.resize(n)
	_ridge_c.resize(n)
	var s := s0
	for i in range(n):
		var x: float = _ridge_x0 + float(i)
		while s < s1 and _plan_p(s).x < x:
			s += 0.25
		var pa: Dictionary = _plan_at(s)
		_ridge_z[i] = (pa["p"] as Vector2).y
		_ridge_y[i] = _road_y(s)
		_ridge_c[i] = absf(cos(float(pa["th"])))


## The crest's z at x (clamped to the crest's ends).
func _ridge_z_at(x: float) -> float:
	if _ridge_z.is_empty():
		return 0.0
	return _ridge_z[clampi(int(x - _ridge_x0), 0, _ridge_z.size() - 1)]


## (distance from p to the ridge's crest line, the road's height there, how far past the crest's
## east end p lies). Far off it: a large distance.
func _ridge_at(p: Vector2) -> Vector3:
	if p.x < _ridge_x0 - 40.0 or p.x > _ridge_x1 + 220.0 or _ridge_z.is_empty():
		return Vector3(1e6, 0.0, 0.0)
	var i: int = clampi(int(p.x - _ridge_x0), 0, _ridge_z.size() - 1)
	var past: float = maxf(0.0, p.x - _ridge_x1)
	return Vector3(absf(p.y - _ridge_z[i]) * _ridge_c[i], _ridge_y[i], past)


# ======================================================================================
#  Grading
# ======================================================================================

## Where the slot canyon's walls stand vertical, and the cutting through the fin under El Arco.
var _slot_s0 := 0.0
var _slot_s1 := 0.0

func _add_road_samples() -> void:
	_rs_pos = PackedVector3Array()
	_rs_right = PackedVector3Array()
	_rs_s = PackedFloat32Array()
	_rs_gap = PackedByteArray()
	_rs_cut = PackedFloat32Array()
	_rs_flat = PackedFloat32Array()
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
		var cut: float = CUT_SLOPE
		var flat: float = ROAD_FLAT
		if s > _slot_s0 and s < _slot_s1:
			cut = 40.0
			flat = SLOT_FLAT
		elif absf(s - _arch_s) < 12.0:
			cut = 12.0
		_rs_cut.append(cut)
		_rs_flat.append(flat)
		var key := Vector2i(floori(pos.x / CELL), floori(pos.z / CELL))
		var bucket: PackedInt32Array = _rs_cells.get(key, PackedInt32Array())
		bucket.append(k)
		_rs_cells[key] = bucket
	print("  road samples: %d" % _rs_pos.size())


## Clamps `h` between the fill and cut bounds of every road segment within reach. Returns the
## graded height and, where (x, z) lies beside a segment inside the flat strip, that segment's road
## height (else NAN).
func _grade(h: float, x: float, z: float) -> Vector2:
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
				# Distance to the segment itself (clamped to its ends), so round the outside of a bend
				# the flat strip follows the joint instead of leaving a wedge between two segments.
				var t: float = clampf((dx * sx + dz * sz) / l2, 0.0, 1.0)
				var fx: float = x - (a.x + sx * t)
				var fz: float = z - (a.z + sz * t)
				var lateral: float = sqrt(fx * fx + fz * fz)
				var foot_y: float = lerpf(a.y, b.y, t)
				var flat: float = _rs_flat[i]
				var over: float = maxf(0.0, lateral - flat)
				var cut: float = _rs_cut[i]
				# Rounded shoulder, so there is no crease at the edge of the flat strip; a vertical
				# wall (the slot) rises straight off it.
				var soft: float = over * over / (over + (4.0 if cut < 10.0 else 0.6))
				upper = minf(upper, foot_y + soft * cut)
				lower = maxf(lower, foot_y - soft * FILL_SLOPE)
				touched = true
				if lateral <= flat and lateral < flat_lat:
					flat_lat = lateral
					flat_y = foot_y
	if not touched:
		return Vector2(h, NAN)
	if lower > upper:
		return Vector2(upper, flat_y)
	return Vector2(clampf(h, lower, upper), flat_y)


## Height the river allows at (x, z): its bed and banks. The channel's deepest line swings toward the
## outside of each bend, where the bank is cut steep; on the inside a gravel bar shelves gently up out
## of the water, and either side of the ford both banks are broad beaches. Elsewhere a short, moderate
## bank. The shore wanders by a few metres (low spits, little bays), and far off the river runs on in
## a broad valley.
func _water_cap(x: float, z: float, rf: Vector3 = Vector3(NAN, 0, 0)) -> float:
	if is_nan(rf.x):
		rf = _river_frame(x, z)
	var lat: float = rf.x
	var d: float = absf(lat)
	var hw: float = rf.y
	if d > hw + 110.0:
		return 1e9
	var rp: Vector3 = _river_params(rf.z)
	var bend: float = rp.x
	var bendy: float = clampf(absf(bend) * 250.0, 0.0, 1.0)
	var ford_w: float = rp.z
	# + on the inside of a bend, - on its outside.
	var inner: float = signf(lat) * signf(bend) * bendy
	var wig: float = _river_noise.get_noise_2d(x * 0.05, z * 0.05) * 0.7 + _river_noise.get_noise_2d(x * 0.19 + 70.0, z * 0.19) * 0.3
	if d < hw:
		var u: float = lat / hw
		var u0: float = -signf(bend) * 0.45 * bendy
		var du: float = u - u0
		var toward_inside: bool = du * signf(bend) > 0.0
		var half: float = (1.0 + absf(u0)) if toward_inside else (1.0 - absf(u0))
		var q: float = clampf(absf(du) / maxf(half, 0.05), 0.0, 1.0)
		# A bowl toward the cut bank, a long shoal up onto the bar.
		var shape: float = pow(q, lerpf(2.0, 1.3, bendy) if toward_inside else 2.0)
		return -0.12 - rp.y * (1.0 - shape) + wig * 0.3 * q
	var e: float = d - hw
	var in_w: float = maxf(inner, 0.0)
	var out_w: float = maxf(-inner, 0.0)
	var gentle: float = lerpf(lerpf(0.30, 0.06, in_w), 0.07, ford_w)
	var bar_w: float = lerpf(lerpf(3.0, 30.0, in_w), 26.0, ford_w) * (1.0 - out_w * 0.8)
	var rise: float = lerpf(lerpf(0.75, 1.9, out_w), 0.45, ford_w)
	var far_w: float = smoothstep(900.0, 1600.0, Vector2(x, z).distance_to(CENTRE))
	gentle = lerpf(gentle, 0.1, far_w)
	rise = lerpf(rise, 0.25, far_w)
	# Under the bridge the river keeps its gorge: steep banks up to the terraces, so the approaches
	# end at the abutments on the terrace instead of on a tall embankment over a beach.
	var gorge: float = 1.0 - smoothstep(60.0, 140.0, absf(rf.z - _bridge_along))
	gentle = lerpf(gentle, 1.0, gorge)
	bar_w = lerpf(bar_w, 1.5, gorge)
	rise = lerpf(rise, 1.7, gorge)
	return -0.12 + gentle * minf(e, bar_w) + rise * maxf(e - bar_w, 0.0) + wig * 0.3 * (1.0 - 0.5 * smoothstep(6.0, 20.0, e))


## Distance to the nearest road centreline (the bridge span left out), the signed lateral across it
## (+ right of travel), and the arc length of that sample.
func _road_lat(x: float, z: float) -> Vector3:
	var cx: int = floori(x / CELL)
	var cz: int = floori(z / CELL)
	var best := 1e9
	var lat := 0.0
	var at_s := 0.0
	var n: int = _rs_pos.size()
	for gz in range(cz - 1, cz + 2):
		for gx in range(cx - 1, cx + 2):
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
	_rv_at = PackedVector3Array()
	_rv_at.resize(nx * nz)
	for iz in range(nz):
		var z: float = _grid_z[iz]
		for ix in range(nx):
			var x: float = _grid_x[ix]
			var i: int = iz * nx + ix
			var near: bool = x > FINE_X.x - 120.0 and x < FINE_X.y + 120.0 and z > FINE_Z.x - 120.0 and z < FINE_Z.y + 120.0
			var rf: Vector3 = _river_frame(x, z)
			_rv_at[i] = rf
			if not near:
				_heights[i] = minf(_base_height(x, z, rf), _water_cap(x, z, rf))
				_road_d[i] = 1e9
				continue
			# The river first, then the road's grading: at the ford the road's shoulders ease down into
			# the bed instead of the bed being cut square beside the road strip.
			var h: float = minf(_base_height(x, z, rf), _water_cap(x, z, rf))
			var g: Vector2 = _grade(h, x, z)
			if g.x < h - 0.5 and is_nan(g.y):
				# A cutting: its faces weather unevenly, not as planes.
				g.x += _detail_noise.get_noise_2d(x * 2.0, z * 2.0) * minf((h - g.x) * 0.15, 0.9)
			h = g.x
			if not is_nan(g.y):
				h = g.y
			var pad: Vector2 = _pad_at(x, z)
			if pad.x > 0.0:
				h = lerpf(h, pad.y, pad.x)
			_heights[i] = h
			var rl: Vector3 = _road_lat(x, z)
			_road_d[i] = rl.x
			_vert_lat[i] = rl.y
			_vert_s[i] = rl.z


## Ground height at any (x, z) from the built heightfield, on the same triangles as the mesha:
## _build_terrain splits each cell along the diagonal joining its closer heights, so this must too.
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

## The ground's collision bodies: [name, Surfaces.gd surface, dust colour]. The roads end in "Road"
## (PlayerCart counts them as track); the order is the index _ground_kind returns.
const BODIES := [
	["CanyonRoad", "asphalt", Color(0, 0, 0, 0)],
	["CuchillaGravelRoad", "gravel", Color(0.80, 0.58, 0.44, 0.7)],
	["BajadaDirtRoad", "dirt", Color(0.78, 0.50, 0.36, 0.75)],
	["GargantaSandRoad", "sand", Color(0.88, 0.70, 0.52, 0.6)],
	["VadoFordRoad", "gravel", Color(0.70, 0.62, 0.54, 0.6)],
	["CanyonGround", "gravel", Color(0.80, 0.60, 0.46, 0.6)],
	["CanyonRockFace", "rock", Color(0.78, 0.56, 0.44, 0.5)],
	["RiverSandBar", "sand", Color(0.86, 0.76, 0.62, 0.55)],
]
const ROAD_KINDS := {"tarmac": 0, "gravel": 1, "dirt": 2, "slot": 3, "ford": 4}


## A mesh of the triangles `idx` of the terrain's vertex arrays, with only the vertices they use.
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
func _terrain_masks(i: int, x: float, z: float, h: float, nrm_y: float) -> Color:
	var road_d: float = _road_d[i]
	var band: float = 1.0 - smoothstep(13.0, 15.0, road_d)
	var rock: float = 1.0 - smoothstep(0.58, 0.78, nrm_y)
	rock *= smoothstep(ROAD_HALF + 0.5, ROAD_HALF + 2.0, road_d)
	var sand := 0.0
	var rf: Vector3 = _rv_at[i]
	if absf(rf.x) < rf.y + 45.0:
		# Sand and river gravel on the bars and beaches, up to where floods reach; a cut bank is
		# rock and mud (a band of sand down a steep bank read as a concrete kerb).
		sand = (1.0 - smoothstep(1.4, 3.2, h - RIVER_Y)) * smoothstep(0.80, 0.94, nrm_y)
		if h < RIVER_Y + 0.25:
			sand = maxf(sand, 0.9)
	var lat_enc: float = clampf(_vert_lat[i] / 24.0 + 0.5, 0.0, 1.0) if road_d < 1000.0 else 1.0
	return Color(rock, band, sand, lat_enc)


## Which collision body a ground triangle (its three vertex indices) goes into.
func _ground_kind(tri: Array, masks: PackedColorArray) -> int:
	var on_road := true
	for v in tri:
		if _road_d[v] >= ROAD_COLLIDE:
			on_road = false
	if on_road:
		return ROAD_KINDS[_road_kind(_vert_s[tri[0]])]
	var rock := 0.0
	var sand := 0.0
	for v in tri:
		rock += masks[v].r
		sand += masks[v].b
	if sand > 1.5:
		return 7
	if rock > 1.8:
		return 6
	return 5


## Terrain mesh with the shader masks in the vertex colour and the road data in UV2, and its
## collision split by surface into BODIES.
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
				colors[i] = _terrain_masks(i, x, z, h, nrm.y)
				uv2s[i] = Vector2(_vert_s[i], _paved_at(_vert_s[i]) if _road_d[i] < 20.0 else 0.0)
			else:
				colors[i] = Color(1.0 - smoothstep(0.58, 0.78, nrm.y), 0.0, 0.0, 0.5)
	# Each cell is split along the diagonal joining its closer heights, so steep slopes that run
	# across the grid don't saw into teeth.
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
				var k: int = _ground_kind(tri, colors) if _road_d[tri[0]] < 1e8 else 5
				# Packed arrays are values: write back through the array, never an alias.
				var f: PackedVector3Array = faces[k]
				f.append(p0)
				f.append(p1)
				f.append(p2)
				faces[k] = f
				counts[k] += 1
	# Two meshes: the fine grid round the lap, which MeshChunker cuts into cells, and the coarse land
	# out to the horizon as one mesh of its own (cut on the fine grid's cell size it became thousands
	# of one-triangle chunks, a draw call each).
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
	inst.name = "CanyonGroundMesh"
	inst.mesh = _save_baked_resource(near_mesh, "ground_visual")
	parent.add_child(inst)
	var far_mesh: ArrayMesh = _compact_mesh(verts, normals, colors, uvs, uv2s, far_idx, mat)
	far_mesh.take_over_path("res://generated/canyonfar_ground.res")
	ResourceSaver.save(far_mesh, "res://generated/canyonfar_ground.res")
	var far_inst := MeshInstance3D.new()
	far_inst.name = "CanyonFarGround"
	far_inst.mesh = load("res://generated/canyonfar_ground.res")
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
#  The river
# ======================================================================================

## Green water over a sandy bed, as the Colorado runs through its canyon.
func _water_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://canyon_river.gdshader")
	var n := FastNoiseLite.new()
	n.seed = 6113
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
	f.seed = 9091
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
	# The reflected sky matches the level's (_build_environment), the walls its sandstone.
	mat.set_shader_parameter("sky_top", Color(0.30, 0.48, 0.76))
	mat.set_shader_parameter("sky_low", Color(0.80, 0.80, 0.82))
	mat.set_shader_parameter("wall_color", Color(0.52, 0.28, 0.18))
	return mat


## The river as a ribbon for canyon_river.gdshader (UV metres across and downstream; COLOR r
## turbulence, the riffle over the ford's bar; g current), wider than the water so it reaches past
## the shore up every beach, and as the RiverWater node PlayerCart reads the water from.
func _build_water(level_scene: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var across := 12
	var rows := 0
	var i := 0
	while i < _rv_pts.size():
		var p: Vector2 = _rv_pts[i]
		var prv: Vector2 = _rv_pts[maxi(i - 1, 0)]
		var nxt: Vector2 = _rv_pts[mini(i + 1, _rv_pts.size() - 1)]
		var fwd: Vector2 = (nxt - prv).normalized()
		var right := Vector2(-fwd.y, fwd.x)
		# Past the shore of the widest beach (the banks hide the rest).
		var hw: float = _rv_hw[i] + 12.0
		var along: float = _rv_along[i]
		var riffle: float = 1.0 - smoothstep(FORD_REACH * 0.15, FORD_REACH * 0.65, absf(along - _ford_along))
		# Shallow reaches run a little rough; narrow ones run fast.
		var turb: float = clampf(riffle * 0.6 + (1.0 - smoothstep(1.3, 2.2, _rv_depth[i])) * 0.12, 0.0, 1.0)
		var cur: float = clampf(14.0 / _rv_hw[i] - 0.3, 0.2, 1.2) + riffle * 0.4
		for k in range(across + 1):
			var u: float = float(k) / float(across)
			var lat: float = lerpf(-hw, hw, u)
			var q: Vector2 = p + right * lat
			st.set_color(Color(turb, cur, 0.0, 1.0))
			st.set_uv(Vector2(lat, along))
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(q.x, RIVER_Y, q.y))
		rows += 1
		i += 2
	for r in range(rows - 1):
		for k in range(across):
			var a0: int = r * (across + 1) + k
			var b0: int = a0 + across + 1
			# Front face up: (c - a) x (b - a) must point +Y (CLAUDE.md winding note).
			st.add_index(a0)
			st.add_index(b0)
			st.add_index(a0 + 1)
			st.add_index(a0 + 1)
			st.add_index(b0)
			st.add_index(b0 + 1)
	var mesh: ArrayMesh = st.commit()
	# The river flows south, so "right" of the downstream direction is west: check the winding
	# against up and flip the whole mesh if it came out facing down.
	var arr := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	if (v[idx[2]] - v[idx[0]]).cross(v[idx[1]] - v[idx[0]]).y < 0.0:
		for t in range(0, idx.size(), 3):
			var tmp: int = idx[t + 1]
			idx[t + 1] = idx[t + 2]
			idx[t + 2] = tmp
		arr[Mesh.ARRAY_INDEX] = idx
		mesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, _save_baked_resource(_water_material(), "river_material"))
	var water := MeshInstance3D.new()
	water.name = "RiverSurface"
	water.mesh = _save_baked_resource(mesh, "river_visual")
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level_scene.add_child(water)

	var rw := Node3D.new()
	rw.name = "RiverWater"
	rw.set_script(RiverWaterScript)
	var pts := PackedVector3Array()
	var hws := PackedFloat32Array()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	# Every cart asks surface_at() every physics tick and it walks every segment: only the stretch a
	# cart can reach, every 48m (the river bends gently enough for chords that long).
	for k in range(0, _rv_pts.size(), 12):
		var q: Vector2 = _rv_pts[k]
		if q.distance_to(CENTRE) > 1300.0:
			continue
		pts.append(Vector3(q.x, RIVER_Y, q.y))
		# Out to the shore of the beaches: a cart wading off the ford is in the water.
		hws.append(_rv_hw[k] + 5.0)
		lo = Vector2(minf(lo.x, q.x - 40.0), minf(lo.y, q.y - 40.0))
		hi = Vector2(maxf(hi.x, q.x + 40.0), maxf(hi.y, q.y + 40.0))
	rw.set("strip_points", pts)
	rw.set("strip_half_widths", hws)
	rw.set("strip_starts", PackedInt32Array([0]))
	rw.set("water_bounds", Rect2(lo, hi - lo))
	level_scene.add_child(rw)
	print("  river: %d rows of water, %d strip points" % [rows, pts.size()])


# ======================================================================================
#  The Puente
# ======================================================================================

func _vc_material(roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = roughness
	m.metallic = metallic
	return m


func _concrete_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://materials/concrete.png")
	m.normal_enabled = true
	m.normal_texture = load("res://materials/concrete_normal.png")
	m.albedo_color = Color(0.86, 0.80, 0.74)
	m.roughness = 0.92
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.25, 0.25, 0.25)
	return m


## A through truss: a camel-back Pratt truss either side of the deck, struts across the top, inclined
## end posts and a portal at each end, on concrete abutments at the gorge's rims. The deck's top
## carries the road's own data and the ground material, so the tarmac and its lines run on across.
func _build_bridge(level_scene: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Puente"
	level_scene.add_child(root)
	var s_a: float = _bridge_s0 - 3.0
	var s_b: float = _bridge_s1 + 3.0
	var a: Dictionary = _spot(s_a, 0.0, 0.0)
	var fwd: Vector3 = a["fwd"]
	var right: Vector3 = a["right"]
	var origin: Vector3 = a["pos"]
	var length: float = s_b - s_a
	var hw: float = BRIDGE_HALF_W
	# --- The deck ------------------------------------------------------------------------------
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: int = int(length / 2.0) + 1
	for r in range(rows):
		var s: float = s_a + length * float(r) / float(rows - 1)
		var c: Vector3 = origin + fwd * (s - s_a)
		c.y = _road_y(s)
		for side in [-1.0, 1.0]:
			var lat: float = side * hw
			st.set_color(Color(0.0, 1.0, 0.0, clampf(lat / 24.0 + 0.5, 0.0, 1.0)))
			st.set_uv(Vector2(c.x, c.z))
			st.set_uv2(Vector2(s, 1.0))
			st.set_normal(Vector3.UP)
			st.add_vertex(c + right * lat)
	for r in range(rows - 1):
		var i0: int = r * 2
		_add_quad_up(st, i0, i0 + 1, i0 + 2, i0 + 3)
	var deck_top: ArrayMesh = st.commit()
	_fix_winding_up(deck_top)
	deck_top.surface_set_material(0, _ground_mat)
	var top_mi := MeshInstance3D.new()
	top_mi.name = "PuenteDeckSurface"
	top_mi.mesh = _save_baked_resource(deck_top, "bridge_deck_top")
	root.add_child(top_mi)

	var kit := {}
	var pk := PropKit.new()
	var steel := Color(0.30, 0.40, 0.38)
	var rust := Color(0.40, 0.30, 0.24)
	var conc := Color(0.78, 0.72, 0.64)
	var basis := Basis(right, Vector3.UP, -fwd)
	pk.set_frame(Transform3D(basis, origin))
	# In the frame: x across (right), y up, -z along the road (the bridge runs to z = -length).
	var deck_y := 0.0
	# Deck slab and its edge beams under the tarmac.
	pk.box(kit, "concrete", Transform3D(Basis(), Vector3(0, deck_y - 0.55, -length * 0.5)), Vector3(hw * 2.0 + 0.4, 1.0, length), conc, 0.0)
	for side in [-1.0, 1.0]:
		# Every member's faces stand 4cm+ off the next one's: the mobile renderer can't separate closer
		# faces, and the curb's face on the chord's flickered all along the inside of the truss.
		pk.box(kit, "steel", Transform3D(Basis(), Vector3(side * (hw + 0.55), deck_y - 0.75, -length * 0.5)), Vector3(0.44, 1.5, length), steel)
		pk.box(kit, "steel", Transform3D(Basis(), Vector3(side * (hw + 0.1), deck_y + 0.35, -length * 0.5)), Vector3(0.22, 0.7, length - 1.0), rust)
	# Floor beams under the deck.
	var panels: int = int(round(length / 8.0))
	var pl: float = length / float(panels)
	for k in range(panels + 1):
		pk.box(kit, "steel", Transform3D(Basis(), Vector3(0, deck_y - 1.35, -pl * k)), Vector3(hw * 2.0 + 1.4, 0.6, 0.5), steel)
	# The trusses: bottom chord, a camel-back top chord, verticals and diagonals.
	var top_at := func(k: int) -> float:
		var u: float = float(k) / float(panels)
		return deck_y + 6.2 + 2.6 * sin(PI * clampf((u - 0.1) / 0.8, 0.0, 1.0))
	for side in [-1.0, 1.0]:
		var x: float = side * (hw + 0.55)
		pk.beam(kit, "steel", Vector3(x, deck_y + 0.1, 0.0), Vector3(x, deck_y + 0.1, -length), 0.55, 0.7, steel, Vector3(side, 0, 0))
		for k in range(panels):
			var z0: float = -pl * k
			var z1: float = -pl * (k + 1)
			var y0: float = top_at.call(k)
			var y1: float = top_at.call(k + 1)
			if k == 0:
				# Inclined end post from the bearing up to the first top node.
				pk.beam(kit, "steel", Vector3(x, deck_y, z0), Vector3(x, y1, z1), 0.68, 0.6, steel, Vector3(side, 0, 0))
			elif k == panels - 1:
				pk.beam(kit, "steel", Vector3(x, y0, z0), Vector3(x, deck_y, z1), 0.68, 0.6, steel, Vector3(side, 0, 0))
			else:
				pk.beam(kit, "steel", Vector3(x, y0, z0), Vector3(x, y1, z1), 0.6, 0.55, steel, Vector3(side, 0, 0))
			if k > 0:
				pk.beam(kit, "steel", Vector3(x, deck_y, z0), Vector3(x, y0, z0), 0.36, 0.4, steel, Vector3(side, 0, 0))
				# Pratt diagonals lean toward the middle of the span.
				if k < panels / 2:
					pk.beam(kit, "steel", Vector3(x, y0, z0), Vector3(x, deck_y, z1), 0.28, 0.3, steel, Vector3(side, 0, 0))
				else:
					pk.beam(kit, "steel", Vector3(x, deck_y, z0), Vector3(x, y1 if k + 1 < panels else deck_y, z1), 0.28, 0.3, steel, Vector3(side, 0, 0))
	# Struts and X-bracing across the top, a portal at each end.
	for k in range(1, panels):
		var y: float = top_at.call(k)
		pk.beam(kit, "steel", Vector3(-hw - 0.55, y, -pl * k), Vector3(hw + 0.55, y, -pl * k), 0.35, 0.4, steel, Vector3(0, 1, 0))
		if k < panels - 1:
			var y2: float = top_at.call(k + 1)
			pk.beam(kit, "steel", Vector3(-hw - 0.55, y, -pl * k), Vector3(hw + 0.55, y2, -pl * (k + 1)), 0.14, 0.14, steel, Vector3(0, 1, 0))
			pk.beam(kit, "steel", Vector3(hw + 0.55, y, -pl * k), Vector3(-hw - 0.55, y2, -pl * (k + 1)), 0.14, 0.14, steel, Vector3(0, 1, 0))
	for z in [-pl, -pl * (panels - 1)]:
		var y: float = top_at.call(1)
		pk.box(kit, "steel", Transform3D(Basis(), Vector3(0, y - 0.9, z)), Vector3(hw * 2.0 + 1.1, 1.2, 0.35), steel)
	# Abutments at both ends, down into the rock.
	for z in [0.0, -length]:
		pk.box(kit, "concrete", Transform3D(Basis(), Vector3(0, deck_y - 5.0, z + (-2.0 if z == 0.0 else 2.0))), Vector3(hw * 2.0 + 3.0, 9.0, 5.0), conc)
	pk.material_for = func(key: String) -> Material:
		if key == "concrete":
			return _concrete_material()
		return _vc_material(0.55, 0.45)
	var mesh: ArrayMesh = pk.commit(kit)
	var mi := MeshInstance3D.new()
	mi.name = "PuenteSteel"
	mi.mesh = _save_baked_resource(mesh, "bridge_steel")
	root.add_child(mi)
	# Collision: the deck (road, tarmac) and a wall along each truss.
	var deck_body := StaticBody3D.new()
	deck_body.name = "PuenteDeckRoad"
	deck_body.set_meta(&"surface", "asphalt")
	root.add_child(deck_body)
	var faces := PackedVector3Array()
	var dv: PackedVector3Array = deck_top.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var di: PackedInt32Array = deck_top.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
	for t in di:
		faces.append(dv[t])
	var deck_shape := ConcavePolygonShape3D.new()
	deck_shape.set_faces(faces)
	deck_shape.backface_collision = true
	var dcs := CollisionShape3D.new()
	dcs.shape = _save_baked_resource(deck_shape, "bridge_deck_shape")
	deck_body.add_child(dcs)
	var truss_body := StaticBody3D.new()
	truss_body.name = "PuenteTruss"
	truss_body.set_meta(&"surface", "asphalt")
	root.add_child(truss_body)
	for side in [-1.0, 1.0]:
		var box := BoxShape3D.new()
		box.size = Vector3(0.8, 2.4, length)
		var cs := CollisionShape3D.new()
		cs.shape = box
		cs.transform = Transform3D(basis, origin + basis * Vector3(side * (hw + 0.55), 1.2, -length * 0.5))
		truss_body.add_child(cs)
	print("  bridge: %.0fm, %d panels" % [length, panels])


func _add_quad_up(st: SurfaceTool, a: int, b: int, c: int, d: int) -> void:
	st.add_index(a)
	st.add_index(c)
	st.add_index(b)
	st.add_index(b)
	st.add_index(c)
	st.add_index(d)


## Flips every triangle of `mesh` whose face points down, so a flat sheet faces up whichever way
## its rows ran (Godot fronts wind clockwise: the face normal is (c - a) x (b - a)).
func _fix_winding_up(mesh: ArrayMesh) -> void:
	var arr := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var flipped := false
	for t in range(0, idx.size(), 3):
		if (v[idx[t + 2]] - v[idx[t]]).cross(v[idx[t + 1]] - v[idx[t]]).y < 0.0:
			var tmp: int = idx[t + 1]
			idx[t + 1] = idx[t + 2]
			idx[t + 2] = tmp
			flipped = true
	if flipped:
		arr[Mesh.ARRAY_INDEX] = idx
		var mat: Material = mesh.surface_get_material(0)
		mesh.clear_surfaces()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		if mat:
			mesh.surface_set_material(0, mat)


# ======================================================================================
#  La Garganta and El Arco
# ======================================================================================

var _wall_noise := FastNoiseLite.new()

## The slot canyon's walls: on each side a sheet from under the floor up to the mesa, scalloped the
## way water carves sandstone and leaning in toward the top, with a lip over the heightfield's own
## cut behind it. Darker low down, where little light reaches.
func _build_slot_walls(level_scene: Node3D) -> void:
	_wall_noise.seed = 4401
	_wall_noise.frequency = 0.06
	_wall_noise.fractal_octaves = 3
	var root := Node3D.new()
	root.name = "Garganta"
	level_scene.add_child(root)
	var faces := PackedVector3Array()
	var tris := 0
	for side in [-1.0, 1.0]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var levels := 12
		var cols := 0
		var s: float = _slot_s0 - 6.0
		while s <= _slot_s1 + 6.0:
			var sp: Dictionary = _spot(s, 0.0, 0.0)
			var c: Vector3 = sp["pos"]
			var r: Vector3 = sp["right"] * side
			var floor_y: float = c.y - 0.8
			# The top tucks just under the mesa's surface, so from above the rim is the ground's own edge.
			var outer: Vector3 = c + r * SLOT_LIP
			var top: float = maxf(_base_height(outer.x, outer.z) - 0.3, floor_y + 7.0)
			# Toward the slot's ends the walls drop to the ground they come out of.
			var end_w: float = smoothstep(_slot_s0 - 6.0, _slot_s0 + 14.0, s) * (1.0 - smoothstep(_slot_s1 - 14.0, _slot_s1 + 6.0, s))
			top = lerpf(floor_y + 3.0, top, end_w)
			for lv in range(levels + 1):
				var v: float = float(lv) / float(levels)
				var y: float = lerpf(floor_y, top, v)
				var scallop: float = _wall_noise.get_noise_2d(s * 0.9, y * 1.3) * 1.5 + _wall_noise.get_noise_2d(s * 0.25 + 40.0, y * 0.4) * 1.0
				var lean: float = -2.4 * v * v * end_w
				var lat: float = 9.2 + clampf(scallop, -1.6, 1.4) + lean + (1.0 - end_w) * 1.5
				if lv == levels:
					lat = SLOT_LIP
				var q: Vector3 = c + r * lat
				q.y = y
				st.set_color(Color(clampf((1.0 - v) * 0.55 * end_w, 0.0, 1.0), 0, 0, 1))
				st.set_uv(Vector2(s, y))
				st.add_vertex(q)
			cols += 1
			s += 1.5
		for ci in range(cols - 1):
			for lv in range(levels):
				var a0: int = ci * (levels + 1) + lv
				var b0: int = a0 + levels + 1
				# The wall faces the road: on the right side (+1) the front faces -r.
				if side > 0.0:
					st.add_index(a0)
					st.add_index(a0 + 1)
					st.add_index(b0)
					st.add_index(b0)
					st.add_index(a0 + 1)
					st.add_index(b0 + 1)
				else:
					st.add_index(a0)
					st.add_index(b0)
					st.add_index(a0 + 1)
					st.add_index(a0 + 1)
					st.add_index(b0)
					st.add_index(b0 + 1)
		st.generate_normals()
		var mesh: ArrayMesh = st.commit()
		_orient_toward_road(mesh, side)
		mesh.surface_set_material(0, _rock_mat)
		var mi := MeshInstance3D.new()
		mi.name = "GargantaWall%s" % ("Right" if side > 0.0 else "Left")
		mi.mesh = _save_baked_resource(mesh, "slot_wall_%s" % ("r" if side > 0.0 else "l"))
		root.add_child(mi)
		var arr := mesh.surface_get_arrays(0)
		var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for t in arr[Mesh.ARRAY_INDEX]:
			faces.append(vv[t])
		tris += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	var body := StaticBody3D.new()
	body.name = "GargantaRock"
	body.set_meta(&"surface", "rock")
	root.add_child(body)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var cs := CollisionShape3D.new()
	cs.shape = _save_baked_resource(shape, "slot_wall_shape")
	body.add_child(cs)
	print("  slot canyon: %.0fm of walls, %d triangles" % [_slot_s1 - _slot_s0, tris])


## Turns a wall mesh's faces (and normals) toward the road if they came out facing away: tested on
## the middle triangle against the direction from the wall to the centreline.
func _orient_toward_road(mesh: ArrayMesh, side: float) -> void:
	var arr := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var t: int = (idx.size() / 6) * 3
	var c: Vector3 = (v[idx[t]] + v[idx[t + 1]] + v[idx[t + 2]]) / 3.0
	var s_near: float = _road_lat(c.x, c.z).z
	var road_p: Vector3 = _spot(s_near, 0.0, 0.0)["pos"]
	var toward: Vector3 = Vector3(road_p.x - c.x, 0.0, road_p.z - c.z)
	var face: Vector3 = (v[idx[t + 2]] - v[idx[t]]).cross(v[idx[t + 1]] - v[idx[t]])
	if face.dot(toward) >= 0.0:
		return
	for k in range(0, idx.size(), 3):
		var tmp: int = idx[k + 1]
		idx[k + 1] = idx[k + 2]
		idx[k + 2] = tmp
	var nr: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	for k in range(nr.size()):
		nr[k] = -nr[k]
	arr[Mesh.ARRAY_INDEX] = idx
	arr[Mesh.ARRAY_NORMAL] = nr
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)


## El Arco del Viento: the fin's rock carried on over the road, a lintel whose underside is a
## half-ellipse from one wall of the cutting to the other and whose top is the fin's crest. Lofted
## across the road as rings of a rounded section, roughened with noise along the normals.
func _build_arch(level_scene: Node3D) -> void:
	var root := Node3D.new()
	root.name = "ElArco"
	level_scene.add_child(root)
	var sp: Dictionary = _spot(_arch_s, 0.0, 0.0)
	var c: Vector3 = sp["pos"]
	var fwd: Vector3 = sp["fwd"]
	var right: Vector3 = sp["right"]
	var n3 := FastNoiseLite.new()
	n3.seed = 3303
	n3.frequency = 0.12
	n3.fractal_octaves = 3
	var span_half := 11.5
	var clearance := 15.0
	var ring := 22
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lats: Array = []
	var lat := -27.0
	while lat <= 27.01:
		lats.append(lat)
		lat += 0.75
	for li in range(lats.size()):
		var l: float = lats[li]
		var u: float = clampf(absf(l) / span_half, 0.0, 1.0)
		# The underside: a half-ellipse over the road, running down into the legs beyond it.
		var soffit: float = c.y + clearance * sqrt(maxf(1.0 - u * u, 0.0)) if absf(l) < span_half else c.y - 2.0 - (absf(l) - span_half) * 0.6
		var q2: Vector3 = c + right * l
		# The top: a lintel a few metres thick over the crown, thickening into the legs and the fin.
		var lintel: float = 5.0 + 4.0 * u * u + n3.get_noise_1d(l * 0.35 + 7.0) * 1.4
		var top: float = soffit + lintel
		if absf(l) >= span_half * 0.8:
			top = maxf(top, minf(_base_height(q2.x, q2.z), c.y + clearance + 9.0))
		var mid: float = (soffit + top) * 0.5
		var half_h: float = (top - soffit) * 0.5
		var thick: float = 3.4 + 2.6 * u * u + n3.get_noise_1d(l * 0.4) * 0.7
		for k in range(ring):
			var a: float = TAU * float(k) / float(ring)
			var sa: float = sin(a)
			var ca: float = cos(a)
			var along: float = thick * signf(sa) * pow(absf(sa), 0.9)
			var up: float = half_h * signf(ca) * pow(absf(ca), 0.85)
			var q: Vector3 = c + right * l + fwd * along
			q.y = mid + up
			var rough: float = n3.get_noise_3d(q.x, q.y, q.z) * 1.1
			var out := (fwd * sa + Vector3.UP * ca).normalized()
			q += out * rough
			# Shade the soffit: it faces down, into its own shadow.
			st.set_color(Color(clampf(-ca * 0.5, 0.0, 0.5), 0, 0, 1))
			st.set_uv(Vector2(l, float(k)))
			st.add_vertex(q)
	for li in range(lats.size() - 1):
		for k in range(ring):
			var a0: int = li * ring + k
			var a1: int = li * ring + (k + 1) % ring
			var b0: int = a0 + ring
			var b1: int = a1 + ring
			st.add_index(a0)
			st.add_index(b0)
			st.add_index(a1)
			st.add_index(a1)
			st.add_index(b0)
			st.add_index(b1)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	_orient_outward(mesh, c + Vector3.UP * (clearance + 4.0))
	mesh.surface_set_material(0, _rock_mat)
	var mi := MeshInstance3D.new()
	mi.name = "ArcoRock"
	mi.mesh = _save_baked_resource(mesh, "arch")
	root.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "ArcoRockBody"
	body.set_meta(&"surface", "rock")
	root.add_child(body)
	var cs := CollisionShape3D.new()
	cs.shape = _save_baked_resource(mesh.create_trimesh_shape(), "arch_shape")
	body.add_child(cs)


## Turns a closed mesh's faces outward if they came out facing in: the triangle farthest from
## `inside` should face away from it.
func _orient_outward(mesh: ArrayMesh, inside: Vector3) -> void:
	var arr := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var best := -1.0
	var bt := 0
	for t in range(0, idx.size(), 3):
		var d: float = v[idx[t]].distance_squared_to(inside)
		if d > best:
			best = d
			bt = t
	var cc: Vector3 = (v[idx[bt]] + v[idx[bt + 1]] + v[idx[bt + 2]]) / 3.0
	var face: Vector3 = (v[idx[bt + 2]] - v[idx[bt]]).cross(v[idx[bt + 1]] - v[idx[bt]])
	if face.dot(cc - inside) >= 0.0:
		return
	for k in range(0, idx.size(), 3):
		var tmp: int = idx[k + 1]
		idx[k + 1] = idx[k + 2]
		idx[k + 2] = tmp
	var nr: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	for k in range(nr.size()):
		nr[k] = -nr[k]
	arr[Mesh.ARRAY_INDEX] = idx
	arr[Mesh.ARRAY_NORMAL] = nr
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)


## The hoodoos of the Valle de los Duendes: spires of soft rock under a harder cap, each a lathe of
## lumpy rings narrowing to a neck under its cap stone, roughened with noise. Placed off the road
## down the valley, with a cylinder collider each.
func _build_hoodoos(level_scene: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Duendes"
	level_scene.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6606
	var n3 := FastNoiseLite.new()
	n3.seed = 812
	n3.frequency = 0.25
	n3.fractal_octaves = 2
	var spots: Array = []
	var s0: float = _seg_s(16, 0.4)
	var s1: float = _seg_s(SEG_VALLEY, 1.0)
	var tries := 0
	while spots.size() < 34 and tries < 3000:
		tries += 1
		var s: float = rng.randf_range(s0, s1)
		var lat: float = (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(17.0, 110.0)
		var q: Vector3 = _spot(s, lat, 0.0)["pos"]
		if _road_lat(q.x, q.z).x < 16.0 or _slope_at(q.x, q.z) > 0.35:
			continue
		var clear := true
		for o in spots:
			if Vector2(q.x - o[0].x, q.z - o[0].z).length() < 14.0:
				clear = false
				break
		if not clear:
			continue
		# Taller further from the road, a few giants.
		var height: float = rng.randf_range(6.0, 13.0) + absf(lat) * 0.08 + (9.0 if rng.randf() < 0.15 else 0.0)
		spots.append([q, height])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := StaticBody3D.new()
	body.name = "DuendesRock"
	body.set_meta(&"surface", "rock")
	root.add_child(body)
	var base := 0
	var segs := 14
	for sp in spots:
		var c: Vector3 = sp[0]
		c.y = _ground_at(c.x, c.z) - 1.2
		var h: float = sp[1]
		var r0: float = h * rng.randf_range(0.16, 0.22)
		var phase: float = rng.randf() * TAU
		var waves: float = rng.randf_range(2.0, 4.0)
		var profile: Array = []
		var rings := 16
		for k in range(rings + 1):
			var t: float = float(k) / float(rings)
			var r: float = r0 * (1.15 - 0.6 * t) * (1.0 + 0.18 * sin(t * PI * waves + phase))
			# The neck under the cap stone.
			r *= 1.0 - 0.45 * smoothstep(0.72, 0.88, t) * (1.0 - smoothstep(0.88, 0.94, t))
			profile.append(Vector2(r, t * h))
		# The cap: a flat, wider slab of the harder bed on top.
		var cap_r: float = r0 * rng.randf_range(0.75, 1.0)
		profile.append(Vector2(cap_r, h + 0.2))
		profile.append(Vector2(cap_r * 0.92, h + 1.4))
		profile.append(Vector2(0.0, h + 1.6))
		var start: int = base
		for k in range(profile.size()):
			var pr: Vector2 = profile[k]
			for j in range(segs):
				var a: float = TAU * float(j) / float(segs)
				var dir := Vector3(cos(a), 0.0, sin(a))
				var q: Vector3 = c + dir * pr.x + Vector3.UP * pr.y
				var rough: float = n3.get_noise_3d(q.x, q.y * 0.6, q.z) * minf(pr.x * 0.3, 0.9)
				q += dir * rough
				st.set_color(Color(clampf(0.4 - pr.y / h * 0.5, 0.0, 0.4), 0, 0, 1))
				st.set_uv(Vector2(float(j) / float(segs), pr.y))
				st.add_vertex(q)
				base += 1
		for k in range(profile.size() - 1):
			for j in range(segs):
				var a0: int = start + k * segs + j
				var a1: int = start + k * segs + (j + 1) % segs
				var b0: int = a0 + segs
				var b1: int = a1 + segs
				st.add_index(a0)
				st.add_index(a1)
				st.add_index(b0)
				st.add_index(a1)
				st.add_index(b1)
				st.add_index(b0)
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = r0 * 0.95
		cyl.height = h * 0.8
		cs.shape = cyl
		cs.position = c + Vector3.UP * (h * 0.4 + 1.2)
		body.add_child(cs)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	# Each spire's faces must look outward: check one against its axis and flip all if needed.
	var arr := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var first_c: Vector3 = spots[0][0]
	var cc: Vector3 = (v[idx[0]] + v[idx[1]] + v[idx[2]]) / 3.0
	var face: Vector3 = (v[idx[2]] - v[idx[0]]).cross(v[idx[1]] - v[idx[0]])
	if face.dot(Vector3(cc.x - first_c.x, 0.0, cc.z - first_c.z)) < 0.0:
		for k in range(0, idx.size(), 3):
			var tmp: int = idx[k + 1]
			idx[k + 1] = idx[k + 2]
			idx[k + 2] = tmp
		var nr: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		for k in range(nr.size()):
			nr[k] = -nr[k]
		arr[Mesh.ARRAY_INDEX] = idx
		arr[Mesh.ARRAY_NORMAL] = nr
		mesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, _rock_mat)
	var mi := MeshInstance3D.new()
	mi.name = "DuendesMesh"
	mi.mesh = _save_baked_resource(mesh, "hoodoos")
	root.add_child(mi)
	print("  hoodoos: %d" % spots.size())


# ======================================================================================
#  La Bajada's kickers
# ======================================================================================

## A dirt kicker across the trail: a ramp up to a lip KICK_H high, a short top and a steep back,
## its surface painted like the road (the ground material, gravel), its body named "...Jump" so
## PlayerCart drives on it as track.
const KICK_H := 1.1
const KICK_RUN := 7.0
## The dirt shoulders down each side: how far out they reach at the foot (plus 1.2 per metre of height)
## and how far under the road they end, so they meet the ground.
const KICK_SHOULDER := 1.4
const KICK_SINK := 0.35

func _build_kickers(level_scene: Node3D) -> Array:
	var root := Node3D.new()
	root.name = "BajadaKickers"
	level_scene.add_child(root)
	var lips: Array = []
	for frac_seg in [[14, 0.5], [16, 0.42]]:
		var s_lip: float = _seg_s(int(frac_seg[0]), float(frac_seg[1]))
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var prof: Array = [[-KICK_RUN, 0.0], [-KICK_RUN * 0.6, KICK_H * 0.22], [-KICK_RUN * 0.3, KICK_H * 0.58], [0.0, KICK_H], [1.0, KICK_H], [2.6, -0.2]]
		var half := 6.4
		# Each row runs out past the top's edges and down into the ground (KICK_SHOULDER): with only the
		# top, the kicker was a strip with open sides you could see under.
		var lats: Array = []
		for pi in range(prof.size()):
			var ds: float = prof[pi][0]
			var lift: float = prof[pi][1]
			var sh: float = KICK_SHOULDER + maxf(lift, 0.0) * 1.2
			lats = [[-half - sh, minf(lift, 0.0) - KICK_SINK], [-half, lift], [half, lift], [half + sh, minf(lift, 0.0) - KICK_SINK]]
			for l in lats:
				var lat: float = l[0]
				var q: Dictionary = _spot(s_lip + ds, lat, 0.0)
				var p: Vector3 = q["pos"]
				p.y = _road_y(s_lip + ds) + float(l[1])
				st.set_color(Color(0.0, 1.0, 0.0, clampf(lat / 24.0 + 0.5, 0.0, 1.0)))
				st.set_uv(Vector2(p.x, p.z))
				st.set_uv2(Vector2(s_lip + ds, 0.0))
				st.add_vertex(p)
		var cols: int = lats.size()
		for pi in range(prof.size() - 1):
			for c in range(cols - 1):
				_add_quad_up(st, pi * cols + c, pi * cols + c + 1, (pi + 1) * cols + c, (pi + 1) * cols + c + 1)
		st.generate_normals()
		var mesh: ArrayMesh = st.commit()
		_fix_winding_up(mesh)
		mesh.surface_set_material(0, _ground_mat)
		var mi := MeshInstance3D.new()
		mi.name = "Kicker%d" % lips.size()
		mi.mesh = mesh
		root.add_child(mi)
		var body := StaticBody3D.new()
		body.name = "BajadaKicker%dJump" % lips.size()
		body.set_meta(&"surface", "dirt")
		body.set_meta(&"dust_color", Color(0.78, 0.50, 0.36, 0.75))
		root.add_child(body)
		var cs := CollisionShape3D.new()
		cs.shape = mesh.create_trimesh_shape()
		body.add_child(cs)
		lips.append(s_lip)
	return lips


# ======================================================================================
#  Plants and rocks
# ======================================================================================

## What the canyon is dressed with. The Hunyuan plant models in models/ (their textures streamed and
## shrunk, scratch/stream_textures.py), each reduced to a triangle budget with Godot's own mesh
## simplifier and given a fresh LOD chain (_dress_mesh): [name, model, height range in metres, triangle
## budget, kind]. The cacti (CactusKit.gd) and the rocks (SandstoneKit.gd) are built in code instead
## (_build_procedural_dressing): the models' cacti were smooth green blobs up close, their boulders
## stacked pancakes and cairns. Kinds: "plant" (small: no shadow, no collider), "tall" (saguaros,
## organ pipes, ocotillos and joshua trees: shadows, a trunk collider near the road), "rock" (shadows,
## a box collider near the road; the "stones" scatters neither).
const DRESS := [
	["agave_a", "res://models/plants/1086dae7861d70b10cce6ef246128f58.fbx", Vector2(1.1, 1.8), 1100, "plant"],
	["agave_b", "res://models/plants/4749ac9125832710f735fccf4cc80f78.fbx", Vector2(0.8, 1.3), 1100, "plant"],
	["agave_e", "res://models/plants/f71bea208fc48e1bbd8f3270e3ea2138.fbx", Vector2(1.0, 1.7), 1100, "plant"],
	["agave_stones", "res://models/plants/155b46f430c01d85b690a61ac5be8ae0.fbx", Vector2(0.9, 1.4), 1100, "plant"],
	["yucca", "res://models/plants/f6113c6a82b962f4f0b9361a3e6c8c11.fbx", Vector2(1.5, 2.4), 1100, "plant"],
	["sotol", "res://models/plants/04b2c6e2e49cc272be24d5807fee4ea0.fbx", Vector2(1.0, 1.6), 1100, "plant"],
	["brush", "res://models/plants/361bcba64776771e1d9624b08d332c66.fbx", Vector2(1.0, 1.8), 1100, "plant"],
	["shrub_stones", "res://models/plants/aff6cf16c1bc07c2988e5df33874dd37.fbx", Vector2(1.2, 1.9), 1100, "plant"],
	["flowers_stones", "res://models/plants/411c0309a5ad518b5594f711a337e50b.fbx", Vector2(0.9, 1.4), 1100, "plant"],
	["daisies", "res://models/plants/6ba4bf59779bd313189f51d9f89c5c3a.fbx", Vector2(0.7, 1.1), 1100, "plant"],
	["marigolds", "res://models/desert3/720c50d2ba993bba0ff56039f05dbb0c.fbx", Vector2(0.8, 1.2), 1100, "plant"],
	["joshua_a", "res://models/plants/0797593737478869dca3e088a7e7ec6c.fbx", Vector2(5.0, 8.0), 2000, "tall"],
	["joshua_b", "res://models/plants/33c2bdd34237248948d6d4ca5c4ac8f2.fbx", Vector2(5.0, 8.5), 2000, "tall"],
]
## The procedural kinds: CactusKit species (each in CactusKit.VARIANTS shapes, named "<species>_<n>"),
## and SandstoneKit's blocks and stone scatters. A mix names the species; a variant is picked when placed.
const CACTUS_KIND := {"saguaro": "tall", "organ": "tall", "ocotillo": "tall", "barrel": "plant", "pear": "plant",
	"cholla": "plant", "hedgehog": "plant"}
const BLOCKS := 8
const STONES := 3
## Draw distance per kind (CanyonDetail.gd scales it with the Detail Level).
const DRESS_RANGE := {"plant": 190.0, "tall": 420.0, "rock": 360.0}
## The far versions: [triangle budget, distance they take over from the near ones].
const DRESS_FAR := {"plant": [260, 45.0], "tall": [600, 70.0], "rock": [300, 55.0]}
## MultiMesh cells.
const DRESS_CELL := 96.0
## The landmarks (SandstoneKit): [kind, s along the lap, metres right of it, height, radius (buttes)].
## A spot that falls in the river or too near the road moves further out (_build_formations).
const FORMATIONS := [
	["spires", 1630.0, -95.0, 26.0, 0.0], ["spires", 1790.0, 75.0, 22.0, 0.0], ["balanced", 1700.0, -48.0, 14.0, 0.0],
	["balanced", 1835.0, -40.0, 11.0, 0.0], ["butte", 1560.0, 75.0, 17.0, 13.0], ["butte", 1290.0, -150.0, 26.0, 22.0],
	["butte", 1200.0, 165.0, 30.0, 26.0], ["butte", 120.0, 125.0, 24.0, 19.0], ["spires", 2480.0, -110.0, 20.0, 0.0],
	["spires", 640.0, -150.0, 18.0, 0.0], ["balanced", 470.0, 60.0, 12.0, 0.0],
]

var _dress_meshes := {}
var _dress_aabb := {}
## Per model, where set: the distance its far version takes over, and its trunk's radius for the collider.
var _dress_swap := {}
var _dress_trunk := {}
## The landmarks' footprints (centre x, z, radius), which the dressing keeps out of.
var _landmarks: Array = []
var _dress_heights := {}
var _dress_radius := {}
var _dress_tris := {}
var _dress_far := {}


## Vertex clustering, for the far versions and for models Godot's simplifier gives up on (foliage
## seamed all over its UVs): every vertex snaps to a grid of cells and one vertex per cell stays (the
## first, with its normal and UV); a triangle whose corners land in fewer than three cells goes. The
## cell size is searched until about `target` triangles are left. Crude, but it reduces anything.
func _cluster_reduce(a: Dictionary, target: int) -> Dictionary:
	var verts: PackedVector3Array = a["v"]
	var idx: PackedInt32Array = a["i"]
	if idx.size() / 3 <= target:
		return a
	var box := AABB(verts[0], Vector3.ZERO)
	for v in verts:
		box = box.expand(v)
	var lo: float = box.get_longest_axis_size() / 400.0
	var hi: float = box.get_longest_axis_size() / 4.0
	var best: Dictionary = a
	for it in range(14):
		var cell: float = sqrt(lo * hi)
		var res: Dictionary = _cluster_once(a, box.position, cell)
		var n: int = (res["i"] as PackedInt32Array).size() / 3
		best = res
		if n > target * 1.1:
			lo = cell
		elif n < target * 0.8:
			hi = cell
		else:
			break
	return best


func _cluster_once(a: Dictionary, origin: Vector3, cell: float) -> Dictionary:
	var verts: PackedVector3Array = a["v"]
	var normals: PackedVector3Array = a["n"]
	var uvs: PackedVector2Array = a["u"]
	var idx: PackedInt32Array = a["i"]
	var rep_of := {}
	var remap := PackedInt32Array()
	remap.resize(verts.size())
	var nv := PackedVector3Array()
	var nn := PackedVector3Array()
	var nu := PackedVector2Array()
	for k in range(verts.size()):
		var q: Vector3 = (verts[k] - origin) / cell
		var key := Vector3i(int(q.x), int(q.y), int(q.z))
		if rep_of.has(key):
			remap[k] = rep_of[key]
		else:
			rep_of[key] = nv.size()
			remap[k] = nv.size()
			nv.append(verts[k])
			nn.append(normals[k])
			if not uvs.is_empty():
				nu.append(uvs[k])
	var ni := PackedInt32Array()
	var seen := {}
	for t in range(0, idx.size(), 3):
		var i0: int = remap[idx[t]]
		var i1: int = remap[idx[t + 1]]
		var i2: int = remap[idx[t + 2]]
		if i0 == i1 or i1 == i2 or i0 == i2:
			continue
		var key2 := Vector3i(mini(i0, mini(i1, i2)), maxi(i0, maxi(i1, i2)), i0 + i1 + i2)
		if seen.has(key2):
			continue
		seen[key2] = true
		ni.append_array([i0, i1, i2])
	return {"v": nv, "n": nn, "u": nu, "i": ni}


func _xform_to(n: Node, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur := n
	while cur and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


## One model's mesh, reduced to about `budget` triangles (the LOD of Godot's simplifier nearest it,
## never under 60% of it), in its own frame with its foot on y = 0 and its middle over the origin,
## with a fresh LOD chain for the distance, saved. Records its height and footprint radius.
func _dress_mesh(nm: String, path: String, budget: int, far_budget: int, tint: Color = Color.WHITE) -> ArrayMesh:
	var ps: PackedScene = load(path)
	var root: Node = ps.instantiate()
	var mis: Array = root.find_children("*", "MeshInstance3D", true, false)
	var mi: MeshInstance3D = mis[0]
	var xf: Transform3D = _xform_to(mi, root)
	var im := ImporterMesh.from_mesh(mi.mesh)
	im.generate_lods(25.0, 60.0, [])
	var arrays: Array = im.get_surface_arrays(0)
	var mat: Material = im.get_surface_material(0)
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var best: PackedInt32Array = idx
	for k in range(im.get_surface_lod_count(0)):
		var li: PackedInt32Array = im.get_surface_lod_indices(0, k)
		if li.size() / 3 >= int(budget * 0.6) and li.size() < best.size():
			best = li
	# Keep only the vertices the reduced triangles use, moved into the model's frame.
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var remap := PackedInt32Array()
	remap.resize(verts.size())
	remap.fill(-1)
	var nv := PackedVector3Array()
	var nn := PackedVector3Array()
	var nt := PackedFloat32Array()
	var nu := PackedVector2Array()
	var ni := PackedInt32Array()
	var nb: Basis = xf.basis.inverse().transposed()
	for v in best:
		if remap[v] < 0:
			remap[v] = nv.size()
			nv.append(xf * verts[v])
			nn.append((nb * normals[v]).normalized())
			if not tangents.is_empty():
				var tv: Vector3 = (xf.basis * Vector3(tangents[v * 4], tangents[v * 4 + 1], tangents[v * 4 + 2])).normalized()
				nt.append_array([tv.x, tv.y, tv.z, tangents[v * 4 + 3]])
			if not uvs.is_empty():
				nu.append(uvs[v])
		ni.append(remap[v])
	var box := AABB(nv[0], Vector3.ZERO)
	for v in nv:
		box = box.expand(v)
	var shift := Vector3(-box.get_center().x, -box.position.y, -box.get_center().z)
	for k in range(nv.size()):
		nv[k] += shift
	if mat is BaseMaterial3D and tint != Color.WHITE:
		mat = mat.duplicate()
		(mat as BaseMaterial3D).albedo_color = (mat as BaseMaterial3D).albedo_color * tint
	var near_a: Dictionary = {"v": nv, "n": nn, "u": nu, "i": ni}
	# The simplifier gives up on some models well over budget: cluster those down too.
	if ni.size() / 3 > budget * 2:
		near_a = _cluster_reduce(near_a, budget)
	var far_a: Dictionary = _cluster_reduce(near_a, far_budget)
	var near_mesh: ArrayMesh = _dress_surface(near_a, mat, true)
	var far_mesh: ArrayMesh = _dress_surface(far_a, mat, false)
	root.free()
	_dress_heights[nm] = box.size.y
	_dress_radius[nm] = maxf(box.size.x, box.size.z) * 0.5
	_dress_tris[nm] = Vector2i((near_a["i"] as PackedInt32Array).size() / 3, (far_a["i"] as PackedInt32Array).size() / 3)
	_dress_far[nm] = _save_baked_resource(far_mesh, "dress_" + nm + "_far")
	return _save_baked_resource(near_mesh, "dress_" + nm) as ArrayMesh


## A dressing model's surface from its arrays; the near version gets Godot's LOD chain too.
func _dress_surface(a: Dictionary, mat: Material, lods: bool) -> ArrayMesh:
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = a["v"]
	out[Mesh.ARRAY_NORMAL] = a["n"]
	if not (a["u"] as PackedVector2Array).is_empty():
		out[Mesh.ARRAY_TEX_UV] = a["u"]
	out[Mesh.ARRAY_INDEX] = a["i"]
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, out, [], {}, mat)
	if lods:
		im.generate_lods(25.0, 60.0, [])
	return im.get_mesh()


## Which models may grow where: [name, weight] lists for the desert floor, the mesa and the ridge,
## and the river's banks.
const FLOOR_MIX := [["agave_a", 4], ["agave_b", 4], ["agave_e", 3], ["agave_stones", 2], ["sotol", 3], ["yucca", 3],
	["brush", 5], ["shrub_stones", 3], ["flowers_stones", 1], ["saguaro", 6], ["organ", 2], ["ocotillo", 3],
	["barrel", 3], ["pear", 4], ["cholla", 3], ["hedgehog", 2], ["stones", 4], ["block", 2]]
const HIGH_MIX := [["joshua_a", 5], ["joshua_b", 5], ["yucca", 4], ["sotol", 3], ["agave_b", 2], ["brush", 5],
	["shrub_stones", 3], ["cholla", 3], ["hedgehog", 2], ["saguaro", 1], ["stones", 4], ["block", 3]]
const RIVER_MIX := [["daisies", 6], ["marigolds", 5], ["flowers_stones", 5], ["brush", 4], ["agave_a", 1], ["stones", 3]]

## A mix entry made concrete: a species or the rocks pick one of their variants.
func _variant(nm: String, rng: RandomNumberGenerator) -> String:
	if CACTUS_KIND.has(nm):
		return "%s_%d" % [nm, rng.randi() % int(CactusKit.VARIANTS[nm])]
	if nm == "block":
		return "block_%d" % (rng.randi() % BLOCKS)
	if nm == "stones":
		return "stones_%d" % (rng.randi() % STONES)
	return nm


func _pick(mix: Array, rng: RandomNumberGenerator) -> String:
	var total := 0
	for m in mix:
		total += int(m[1])
	var r: int = rng.randi() % total
	for m in mix:
		r -= int(m[1])
		if r < 0:
			return m[0]
	return mix[0][0]


## Places the plants, cacti and rocks along the lap (denser close to it, thinning out to 140m), talus
## at the foot of the cliffs and the riverside's green (_build_riverside), all clear of the landmarks
## (_build_formations, built before) and the Parador's pad; builds them as MultiMesh cells per model,
## and colliders for whatever stands near the road.
func _build_dressing(level_scene: Node3D) -> void:
	var t0 := Time.get_ticks_msec()
	var root := Node3D.new()
	# Not "Props"/"Vegetation"/"Environment": Level.gd bakes trimesh colliders for those names.
	root.name = "CanyonDressing"
	root.set_script(load("res://CanyonDetail.gd"))
	level_scene.add_child(root)
	var kinds := {}
	for d in DRESS:
		# The models' greens are bright and clean; the desert's are dusty grey-green.
		_dress_meshes[d[0]] = _dress_mesh(d[0], d[1], int(d[3]), int(DRESS_FAR[d[4]][0]), Color(0.84, 0.78, 0.70))
		kinds[d[0]] = d
	_build_procedural_dressing(kinds)
	var tri_line := ""
	for nm0 in _dress_tris:
		tri_line += " %s %d/%d" % [nm0, _dress_tris[nm0].x, _dress_tris[nm0].y]
	print("  dressing: %d models reduced (%.1fs):%s" % [DRESS.size(), (Time.get_ticks_msec() - t0) / 1000.0, tri_line])
	var rng := RandomNumberGenerator.new()
	rng.seed = 9137
	var placed := {}
	var spots: Array = []
	# Along the lap, both sides: closer in, more of them.
	var s := 0.0
	while s < _lap_len:
		for k in range(7):
			var side: float = -1.0 if rng.randf() < 0.5 else 1.0
			var lat: float = side * (ROAD_FLAT + 3.0 + rng.randf() * rng.randf() * 135.0)
			var sp: Dictionary = _spot(s + rng.randf_range(-2.0, 2.0), lat, 0.0)
			spots.append([sp["pos"], absf(lat)])
		s += 3.0
	for spot in spots:
		var p: Vector3 = spot[0]
		var x: float = p.x
		var z: float = p.z
		var rl: Vector3 = _road_lat(x, z)
		if rl.x < ROAD_FLAT + 2.5:
			continue
		# Not inside the slot canyon's walls, nor in the arch's cutting.
		if rl.x < 18.0 and ((rl.z > _slot_s0 - 10.0 and rl.z < _slot_s1 + 10.0) or absf(rl.z - _arch_s) < 30.0):
			continue
		var rf: Vector3 = _river_frame(x, z)
		var to_water: float = absf(rf.x) - rf.y
		if to_water < 4.0 or _in_landmark(x, z) or _pad_at(x, z).x > 0.2:
			continue
		var y: float = _ground_at(x, z)
		var slope: float = _slope_at(x, z)
		if slope > 0.5 or y < RIVER_Y + 0.6:
			continue
		var mix: Array = FLOOR_MIX
		if to_water < 40.0 and y < TERRACE_E + 3.0:
			mix = RIVER_MIX
		elif y > 36.0:
			mix = HIGH_MIX
		var nm: String = _variant(_pick(mix, rng), rng)
		var d: Array = kinds[nm]
		if d[4] == "tall" and (slope > 0.3 or rl.x < ROAD_FLAT + 5.0):
			continue
		var height: float = rng.randf_range(float(d[2].x), float(d[2].y))
		# Blocks lie a quarter buried.
		if nm.begins_with("block"):
			y -= height * 0.25
		_place(placed, nm, x, y, z, height, rng.randf() * TAU, rng)
	# Boulders where the cliffs meet the flats: a step down from steep ground.
	var b_count := 0
	for k in range(9000):
		var sp2: Dictionary = _spot(rng.randf() * _lap_len, (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(ROAD_FLAT + 4.0, 110.0), 0.0)
		var q: Vector3 = sp2["pos"]
		var rl2: Vector3 = _road_lat(q.x, q.z)
		if rl2.x < ROAD_FLAT + 3.5 or (rl2.x < 18.0 and rl2.z > _slot_s0 - 10.0 and rl2.z < _slot_s1 + 10.0):
			continue
		var rf2: Vector3 = _river_frame(q.x, q.z)
		if absf(rf2.x) - rf2.y < 3.0 or _in_landmark(q.x, q.z) or _pad_at(q.x, q.z).x > 0.2:
			continue
		var slope2: float = _slope_at(q.x, q.z)
		var up_slope: float = maxf(maxf(_slope_at(q.x + 6.0, q.z), _slope_at(q.x - 6.0, q.z)), maxf(_slope_at(q.x, q.z + 6.0), _slope_at(q.x, q.z - 6.0)))
		if slope2 > 0.55 or up_slope < 0.9:
			continue
		# Talus: one big block fallen from the cliff, a few smaller ones broken off round it.
		var big: float = rng.randf_range(1.8, 5.2)
		for j in range(rng.randi_range(1, 5)):
			var hj: float = big if j == 0 else big * rng.randf_range(0.2, 0.55)
			var oa: float = rng.randf() * TAU
			var od: float = 0.0 if j == 0 else big * rng.randf_range(0.8, 1.8)
			var qj := Vector3(q.x + cos(oa) * od, 0.0, q.z + sin(oa) * od)
			if j > 0 and (_road_lat(qj.x, qj.z).x < ROAD_FLAT + 3.5 or _slope_at(qj.x, qj.z) > 0.6):
				continue
			_place(placed, "block_%d" % (rng.randi() % BLOCKS), qj.x, _ground_at(qj.x, qj.z) - hj * 0.25, qj.z, hj, rng.randf() * TAU, rng)
		b_count += 1
		if b_count > 300:
			break
	_build_riverside(placed, kinds, rng)
	# Build the cells.
	var cells := 0
	var count := 0
	var collide := StaticBody3D.new()
	collide.name = "CanyonBoulders"
	collide.set_meta(&"surface", "rock")
	root.add_child(collide)
	for nm3 in placed:
		var d3: Array = kinds[nm3]
		var kind: String = d3[4]
		var by_cell := {}
		for xf in placed[nm3]:
			var t3: Transform3D = xf
			var key := Vector2i(floori(t3.origin.x / DRESS_CELL), floori(t3.origin.z / DRESS_CELL))
			if not by_cell.has(key):
				by_cell[key] = []
			by_cell[key].append(t3)
			count += 1
			# Colliders for what a cart can run into, near the road.
			if kind != "plant" and not nm3.begins_with("stones"):
				var rl3: Vector3 = _road_lat(t3.origin.x, t3.origin.z)
				if rl3.x < 45.0:
					var sc: float = t3.basis.get_scale().x
					var cs := CollisionShape3D.new()
					if kind == "rock":
						var ab: AABB = _dress_aabb[nm3]
						var box := BoxShape3D.new()
						box.size = ab.size * sc * 0.82
						cs.shape = box
						cs.transform = Transform3D(t3.basis.orthonormalized(), t3 * ab.get_center())
					elif kind == "tall":
						var cyl := CylinderShape3D.new()
						cyl.radius = float(_dress_trunk[nm3]) * sc if _dress_trunk.has(nm3) else maxf(0.25, float(_dress_radius[nm3]) * sc * 0.18)
						cyl.height = float(_dress_heights[nm3]) * sc * 0.6
						cs.shape = cyl
						cs.position = t3.origin + Vector3.UP * cyl.height * 0.5
					else:
						var sph := SphereShape3D.new()
						sph.radius = float(_dress_radius[nm3]) * sc * 0.7
						cs.shape = sph
						cs.position = t3.origin + Vector3.UP * minf(sph.radius * 0.6, float(_dress_heights[nm3]) * sc * 0.45)
					collide.add_child(cs)
		for key in by_cell:
			var list: Array = by_cell[key]
			# Shuffled, so CanyonDetail.gd thins a cell evenly by drawing its first N.
			for k in range(list.size() - 1, 0, -1):
				var j: int = rng.randi() % (k + 1)
				var tmp = list[k]
				list[k] = list[j]
				list[j] = tmp
			# Two MultiMeshes per cell holding the same instances: the near model, and the far one
			# (_cluster_reduce) beyond DRESS_FAR's distance.
			var prefix: String = {"plant": "Plants", "tall": "Tall", "rock": "Rocks"}[kind]
			var buf: PackedFloat32Array = PropKit.transform_buffer(list)
			var swap: float = float(_dress_swap.get(nm3, DRESS_FAR[kind][1]))
			for far in [false, true]:
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = _dress_far[nm3] if far else _dress_meshes[nm3]
				mm.instance_count = list.size()
				mm.buffer = buf
				var mmi := MultiMeshInstance3D.new()
				mmi.name = "%s%s_%s_%d_%d" % [prefix, "" if far else "Near", nm3, key.x, key.y]
				mmi.multimesh = mm
				if far:
					mmi.visibility_range_begin = swap
					mmi.visibility_range_end = DRESS_RANGE[kind]
					mmi.set_meta(&"base_range", DRESS_RANGE[kind])
				else:
					mmi.visibility_range_end = swap
				# Small things cast no shadow: the shadow pass would draw every one of them again.
				if kind == "plant" or nm3.begins_with("stones"):
					mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				root.add_child(mmi)
			cells += 1
	print("  dressing: %d placed in %d cells, %d colliders (%.1fs)" % [count, cells, collide.get_child_count(), (Time.get_ticks_msec() - t0) / 1000.0])


## The cacti (CactusKit.gd) and the rocks (SandstoneKit.gd), near and far, registered as dressing
## kinds like the models: [name, "", height range, 0, kind], the range scaled from each one's height.
func _build_procedural_dressing(kinds: Dictionary) -> void:
	var t0 := Time.get_ticks_msec()
	var kit := CactusKit.new()
	var cmat: Material = _save_baked_resource(kit.material(), "cactus_material")
	for sp in CactusKit.SPECIES:
		for v in range(int(CactusKit.VARIANTS[sp])):
			_register_dress(kinds, "%s_%d" % [sp, v], kit.build(sp, v, 0, cmat), kit.build(sp, v, 1, cmat), CACTUS_KIND[sp], Vector2(0.85, 1.2))
	for v in range(BLOCKS):
		_register_dress(kinds, "block_%d" % v, SandstoneKit.block(4100 + v, 7, _rock_mat), SandstoneKit.block(4100 + v, 2, _rock_mat), "rock", Vector2(0.9, 2.6))
	for v in range(STONES):
		_register_dress(kinds, "stones_%d" % v, SandstoneKit.pebbles(5100 + v, 11, 2, _rock_mat), SandstoneKit.pebbles(5100 + v, 11, 1, _rock_mat), "rock", Vector2(0.8, 1.3))
	print("  cacti and rocks built (%.1fs)" % ((Time.get_ticks_msec() - t0) / 1000.0))


## The river's green margin, the only green in the canyon: reed clumps at the water's edge, tamarisk
## and willows on the bars and low banks, cottonwoods on the terraces over them (WoodlandBuilder.gd's
## trees, as on the Lakeside Course). Walks both shores of the stretch the lap can see, finding each
## shore's waterline on the built ground; nothing on a road, by the bridge or in a landmark.
func _build_riverside(placed: Dictionary, kinds: Dictionary, rng: RandomNumberGenerator) -> void:
	var t0 := Time.get_ticks_msec()
	var w = Woodland.new()
	w.save_res = func(res: Resource, n: String) -> Resource: return _save_baked_resource(res, n)
	# No crossfade in the materials: the dressing's near and far cells swap by distance (_dress_swap).
	var leaf: ShaderMaterial = w.leaf_material(0, 0.12, 12.0)
	# A dusty desert green, not the lakeside's: the sun through the leaves glowed lime.
	leaf.set_shader_parameter("backlight_color", Color(0.44, 0.48, 0.28))
	leaf = _save_baked_resource(leaf, "leaf_riverside")
	var tree_names: Array = []
	for kind in ["cottonwood", "willow"]:
		var bark: ShaderMaterial = _save_baked_resource(w.bark_material(kind if kind == "cottonwood" else "alder", 0), "bark_" + kind)
		for v in range(2):
			var nm := "%s_%d" % [kind, v]
			_register_dress(kinds, nm, w.broadleaf_mesh(kind, v, 0, bark, leaf), w.broadleaf_mesh(kind, v, 1, bark, leaf), "tall", Vector2(0.8, 1.15))
			_dress_swap[nm] = 115.0
			_dress_trunk[nm] = 0.5 if kind == "cottonwood" else 0.3
			tree_names.append(nm)
	var shrub_bark: ShaderMaterial = _save_baked_resource(w.bark_material("hazel", 0), "bark_tamarisk")
	for v in range(2):
		var sm: ArrayMesh = w.shrub_mesh(v, shrub_bark, leaf)
		_register_dress(kinds, "tamarisk_%d" % v, sm, sm, "plant", Vector2(0.7, 1.0))
	var reed_mat := ShaderMaterial.new()
	reed_mat.shader = load("res://dune_grass.gdshader")
	reed_mat.set_shader_parameter("sway", 0.14)
	reed_mat.set_shader_parameter("speed", 1.3)
	reed_mat = _save_baked_resource(reed_mat, "reed_material")
	for v in range(3):
		_register_dress(kinds, "reeds_%d" % v, _reed_clump(v, 0, reed_mat), _reed_clump(v, 1, reed_mat), "plant", Vector2(1.2, 2.3))
	var bridge_a: Vector2 = _plan_p(_bridge_s0 - 10.0)
	var bridge_b: Vector2 = _plan_p(_bridge_s1 + 10.0)
	var trees: Array = []
	var counts := {"reeds": 0, "shrubs": 0, "trees": 0}
	for i in range(0, _rv_pts.size() - 1):
		var p: Vector2 = _rv_pts[i]
		if p.distance_to(CENTRE) > 1250.0:
			continue
		var fwd: Vector2 = (_rv_pts[i + 1] - p).normalized()
		var right := Vector2(-fwd.y, fwd.x)
		for side in [-1.0, 1.0]:
			# The waterline: the first metre out from the channel where the ground stands dry.
			var shore := -1.0
			var lat: float = maxf(_rv_hw[i] - 8.0, 2.0)
			while lat < _rv_hw[i] + 45.0:
				var q: Vector2 = p + right * side * lat
				if _ground_at(q.x, q.y) > RIVER_Y + 0.04:
					shore = lat
					break
				lat += 1.0
			if shore < 0.0:
				continue
			# Reeds most of the way along, then the shrubs, then now and then a tree.
			var picks: Array = []
			if rng.randf() < 0.55:
				picks.append(["reeds_%d" % (rng.randi() % 3), rng.randf_range(-0.8, 2.2), -0.2, 0.7, 0.35])
			if rng.randf() < 0.16:
				picks.append(["tamarisk_%d" % (rng.randi() % 2) if rng.randf() < 0.6 else "willow_%d" % (rng.randi() % 2), rng.randf_range(2.5, 14.0), 0.15, 3.0, 0.45])
			if rng.randf() < 0.075:
				picks.append(["cottonwood_%d" % (rng.randi() % 2), rng.randf_range(6.0, 30.0), 0.4, 6.0, 0.3])
			for pk in picks:
				var nm: String = pk[0]
				var q2: Vector2 = p + right * side * (shore + float(pk[1])) + fwd * rng.randf_range(-2.0, 2.0)
				var y: float = _ground_at(q2.x, q2.y)
				if y < RIVER_Y + float(pk[2]) or y > RIVER_Y + float(pk[3]) or _slope_at(q2.x, q2.y) > float(pk[4]):
					continue
				var big: bool = nm.begins_with("cottonwood") or nm.begins_with("willow")
				var clear: float = (16.0 if nm.begins_with("cottonwood") else 11.0) if big else ROAD_FLAT + 3.0
				if _road_lat(q2.x, q2.y).x < clear or _in_landmark(q2.x, q2.y) or _pad_at(q2.x, q2.y).x > 0.2:
					continue
				if big and _seg_distance(q2, bridge_a, bridge_b) < 22.0:
					continue
				if big:
					var crowded := false
					for o in trees:
						if (o as Vector2).distance_to(q2) < (13.0 if nm.begins_with("cottonwood") else 7.0):
							crowded = true
							break
					if crowded:
						continue
					trees.append(q2)
				var d: Array = kinds[nm]
				_place(placed, nm, q2.x, y - (0.25 if big else 0.05), q2.y, rng.randf_range(float(d[2].x), float(d[2].y)), rng.randf() * TAU, rng)
				counts["trees" if nm.begins_with("cottonwood") else ("reeds" if nm.begins_with("reeds") else "shrubs")] += 1
	print("  riverside: %d reed clumps, %d shrubs and willows, %d cottonwoods (%.1fs)" % [counts["reeds"], counts["shrubs"], counts["trees"], (Time.get_ticks_msec() - t0) / 1000.0])


## A clump of reeds about a metre tall (scaled when placed): blades fanning from one foot, bending out
## toward their tips, green to straw, a few carrying a cattail's brown spike. For dune_grass.gdshader:
## COLOR the blade's colour, its alpha how far up the blade.
func _reed_clump(variant: int, lod: int, mat: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8800 + variant * 17
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blades: int = (38 if lod == 0 else 12) + variant * 4
	var segs: int = 4 if lod == 0 else 2
	var n := 0
	for k in range(blades):
		var a: float = rng.randf() * TAU
		var out := Vector3(cos(a), 0.0, sin(a))
		var foot: Vector3 = out * sqrt(rng.randf()) * 0.32
		var h: float = rng.randf_range(0.6, 1.0)
		var lean: float = rng.randf_range(0.05, 0.4)
		var w0: float = rng.randf_range(0.025, 0.04) * (1.6 if lod == 1 else 1.0)
		var side: Vector3 = Vector3.UP.cross(out).normalized().rotated(Vector3.UP, rng.randf_range(-0.8, 0.8))
		var col: Color = Color(0.36, 0.47, 0.20).lerp(Color(0.66, 0.58, 0.36), rng.randf() * rng.randf())
		var face: Vector3 = side.cross(Vector3.UP).normalized()
		for j in range(segs + 1):
			var t: float = float(j) / float(segs)
			var c: Vector3 = foot + out * lean * t * t * h + Vector3.UP * (t * h - 0.05)
			var wd: float = w0 * (1.0 - t * 0.85)
			for sgn in [-1.0, 1.0]:
				st.set_color(Color(col.r, col.g, col.b, t))
				st.set_normal((face + Vector3.UP * 0.6).normalized())
				st.add_vertex(c + side * wd * sgn)
		for j in range(segs):
			var b0: int = n + j * 2
			st.add_index(b0)
			st.add_index(b0 + 1)
			st.add_index(b0 + 3)
			st.add_index(b0)
			st.add_index(b0 + 3)
			st.add_index(b0 + 2)
		n += (segs + 1) * 2
		# A cattail's spike on a few of the tallest.
		if lod == 0 and h > 0.85 and rng.randf() < 0.3:
			var top: Vector3 = foot + out * lean * h * 0.8 + Vector3.UP * (h * 0.86)
			for j in range(2):
				for sgn in [-1.0, 1.0]:
					st.set_color(Color(0.34, 0.22, 0.12, 0.9))
					st.set_normal((face + Vector3.UP * 0.4).normalized())
					st.add_vertex(top + Vector3.UP * (0.12 * float(j)) + side * 0.018 * sgn)
			st.add_index(n)
			st.add_index(n + 1)
			st.add_index(n + 3)
			st.add_index(n)
			st.add_index(n + 3)
			st.add_index(n + 2)
			n += 4
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, mat)
	return mesh


func _in_landmark(x: float, z: float) -> bool:
	for lm in _landmarks:
		if Vector2(x - lm.x, z - lm.y).length() < lm.z:
			return true
	return false


func _register_dress(kinds: Dictionary, nm: String, near: ArrayMesh, far: ArrayMesh, kind: String, scale: Vector2) -> void:
	var ab: AABB = near.get_aabb()
	var h: float = maxf(ab.end.y, 0.05)
	_dress_heights[nm] = h
	_dress_radius[nm] = maxf(ab.size.x, ab.size.z) * 0.5
	_dress_aabb[nm] = ab
	_dress_tris[nm] = Vector2i(near.surface_get_array_index_len(0) / 3, far.surface_get_array_index_len(0) / 3)
	_dress_meshes[nm] = _save_baked_resource(near, "dress_" + nm)
	# One mesh at both distances is saved once (saving it again would move it to the far file).
	_dress_far[nm] = _dress_meshes[nm] if far == near else _save_baked_resource(far, "dress_" + nm + "_far")
	kinds[nm] = [nm, "", Vector2(h * scale.x, h * scale.y), 0, kind]


## The landmarks: buttes, spire clusters and balanced rocks (SandstoneKit.gd) at FORMATIONS' spots, or
## pushed further out where a spot falls in the river or near the road. Each stands on the lowest
## ground under its foot (no edge floats on a slope) and is solid wherever it stands: a hull of its shape.
func _build_formations(level_scene: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Formations"
	level_scene.add_child(root)
	var body := StaticBody3D.new()
	body.name = "FormationRock"
	body.set_meta(&"surface", "rock")
	root.add_child(body)
	var built := 0
	for i in range(FORMATIONS.size()):
		var f: Array = FORMATIONS[i]
		var kind: String = f[0]
		var h: float = f[3]
		var rad: float = float(f[4]) if kind == "butte" else h * 0.4
		var lat: float = f[2]
		var pos := Vector3.ZERO
		var ok := false
		for tries in range(14):
			pos = _spot(float(f[1]), lat, 0.0)["pos"]
			var rf: Vector3 = _river_frame(pos.x, pos.z)
			var pad_clear: bool = _pad_at(pos.x, pos.z).x <= 0.0 and _pad_at(pos.x + rad * 1.8, pos.z).x <= 0.0 and _pad_at(pos.x - rad * 1.8, pos.z).x <= 0.0 and _pad_at(pos.x, pos.z + rad * 1.8).x <= 0.0 and _pad_at(pos.x, pos.z - rad * 1.8).x <= 0.0
			if pad_clear and _road_lat(pos.x, pos.z).x > rad * 1.8 + 14.0 and absf(rf.x) - rf.y > rad * 1.8 + 8.0:
				ok = true
				break
			lat += signf(lat) * 15.0
		if not ok:
			push_warning("Formation %d (%s) found no clear spot" % [i, kind])
			continue
		var seed_v: int = 7001 + i * 13
		var mesh: ArrayMesh
		match kind:
			"butte":
				mesh = SandstoneKit.butte(seed_v, rad, h, 56, _rock_mat)
			"spires":
				mesh = SandstoneKit.spires(seed_v, 5, h, 12, _rock_mat)
			_:
				mesh = SandstoneKit.balanced(seed_v, h, 14, 6, _rock_mat)
		var lowest: float = _ground_at(pos.x, pos.z)
		for a in range(10):
			var ang: float = TAU * float(a) / 10.0
			lowest = minf(lowest, _ground_at(pos.x + cos(ang) * rad, pos.z + sin(ang) * rad))
		var mi := MeshInstance3D.new()
		_landmarks.append(Vector3(pos.x, pos.z, (rad * 1.8 if kind == "butte" else rad * 1.3) + 2.0))
		mi.name = "%s%d" % [kind.capitalize(), i]
		mi.mesh = _save_baked_resource(mesh, "formation_%d" % i)
		mi.transform = Transform3D(Basis(Vector3.UP, float(seed_v) * 0.7), Vector3(pos.x, lowest - 0.8, pos.z))
		root.add_child(mi)
		var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var pts := PackedVector3Array()
		for k in range(0, verts.size(), 3):
			pts.append(verts[k])
		var hull := ConvexPolygonShape3D.new()
		hull.points = pts
		var cs := CollisionShape3D.new()
		cs.shape = hull
		cs.transform = mi.transform
		body.add_child(cs)
		built += 1
	print("  formations: %d" % built)


func _place(placed: Dictionary, nm: String, x: float, y: float, z: float, height: float, yaw: float, rng: RandomNumberGenerator) -> void:
	var sc: float = height / maxf(float(_dress_heights[nm]), 0.01)
	var b := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * sc)
	# A slight lean, as nothing in the desert grows plumb.
	b = Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.06)) * b
	if not placed.has(nm):
		placed[nm] = []
	placed[nm].append(Transform3D(b, Vector3(x, y - 0.05 * sc, z)))


# ======================================================================================
#  The roadside: the Parador, guardrails, poles, markers and signs
# ======================================================================================

const CampKit = preload("res://CampKit.gd")
const VenueKit = preload("res://VenueKit.gd")
const CrowdPlacer = preload("res://CrowdPlacer.gd")
## People-sized things are built at life size and scaled up, as on the Lakeside Course and Bloombay.
const PROP_SCALE := 1.6
## The Parador del Viento: on a pad graded level beside the start straight, [s, metres right] of its
## centre and its half extents (along, across). Its near edge stands 19m off the centreline, so the
## pad's 10m blend never reaches the road's flat strip.
const PARADOR_AT := Vector2(100.0, 53.0)
const PARADOR_HALF := Vector2(62.0, 34.0)
## The windmill over the stock tank, in the Parador's frame (life size): its foot, its wheel's hub over the
## foot, and how fast the wheel turns (degrees a second).
const WINDMILL_BASE := Vector3(31.0, 0.0, 17.0)
const WINDMILL_HUB := Vector3(0.0, 10.6, -0.9)
const WINDMILL_SPIN := 32.0

var _prop_mats := {}

func _prop_material(key: String) -> Material:
	if _prop_mats.has(key):
		return _prop_mats[key]
	var m: Material
	match key:
		"concrete":
			m = _concrete_material()
		"glass":
			var g := _vc_material(0.08, 0.4)
			g.albedo_color = Color(0.55, 0.6, 0.65)
			m = g
		"lamp":
			var l := _vc_material(0.5)
			l.emission_enabled = true
			l.emission = Color(1.0, 0.95, 0.8)
			l.emission_energy_multiplier = 1.4
			m = l
		"metal":
			m = _vc_material(0.45, 0.55)
		"wood":
			m = _vc_material(0.92)
		_:
			m = CampKit.make_material(key) if key in ["matte", "canvas", "gloss", "chrome", "rubber"] else _vc_material(0.6)
	m = _save_baked_resource(m, "prop_mat_" + key)
	_prop_mats[key] = m
	return m


## The level pads: [centre (x, z), along (unit x, z), half extents (along, across), height].
var _pads: Array = []

func _plan_pads() -> void:
	var sp: Dictionary = _spot(PARADOR_AT.x, PARADOR_AT.y, 0.0)
	var f: Vector3 = sp["fwd"]
	_pads = [[Vector2((sp["pos"] as Vector3).x, (sp["pos"] as Vector3).z), Vector2(f.x, f.z), PARADOR_HALF, _road_y(PARADOR_AT.x) + 0.15]]
	# The start venue's marquee, across the road from the Parador.
	var ts: float = _finish_s() + VENUE_TENT.x
	var tp: Dictionary = _spot(ts, VENUE_TENT.y, 0.0)
	var tf: Vector3 = tp["fwd"]
	_pads.append([Vector2((tp["pos"] as Vector3).x, (tp["pos"] as Vector3).z), Vector2(tf.x, tf.z), VENUE_PAD_HALF, _road_y(ts) + 0.1])


## How much a pad levels the ground at (x, z): 1 on it, easing to 0 over 10m; and its height.
func _pad_at(x: float, z: float) -> Vector2:
	for pad in _pads:
		var c: Vector2 = pad[0]
		var a: Vector2 = pad[1]
		var half: Vector2 = pad[2]
		var d := Vector2(x, z) - c
		var q := Vector2(absf(d.dot(a)) - half.x, absf(d.dot(Vector2(-a.y, a.x))) - half.y)
		var sd: float = Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0)
		var w: float = 1.0 - smoothstep(0.0, 10.0, sd)
		if w > 0.0:
			return Vector2(w, float(pad[3]))
	return Vector2(0.0, 0.0)


## The Parador del Viento: a roadside stop on the start straight, built at life size in its own frame
## (x along the road, y up, z away from it; fronts face -z, the road) and grown by PROP_SCALE. Across
## the front, the filling station: a canopy over three islands of pumps, the shop beside it, the pole
## sign. Behind them a diner with its patio, a motel wing with its office, a workshop with its yard
## of tyres and drums and a wreck, restrooms and a picnic ramada, a water tower, a windmill over a
## stock tank, lot lights and parked vehicles (CampKit's).
func _build_parador(level_scene: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Parador"
	level_scene.add_child(root)
	var sp: Dictionary = _spot(PARADOR_AT.x, PARADOR_AT.y, 0.0)
	var fwd: Vector3 = sp["fwd"]
	var right: Vector3 = sp["right"]
	var y0: float = _road_y(PARADOR_AT.x) + 0.15
	var origin := Vector3((sp["pos"] as Vector3).x, y0, (sp["pos"] as Vector3).z)
	var basis := Basis(fwd, Vector3.UP, right)
	var frame := Transform3D(basis.scaled(Vector3.ONE * PROP_SCALE), origin)
	var to_world := func(local: Vector3) -> Vector3: return origin + basis * (local * PROP_SCALE)
	var pk := PropKit.new()
	pk.set_frame(frame)
	var kit := {}
	var white := Color(0.92, 0.90, 0.86)
	var red := Color(0.72, 0.12, 0.10)
	var dark := Color(0.12, 0.12, 0.13)
	var cream := Color(0.86, 0.78, 0.62)
	var adobe := Color(0.80, 0.62, 0.46)
	var teal := Color(0.20, 0.50, 0.50)
	var yellow := Color(0.92, 0.74, 0.16)
	var steel := Color(0.62, 0.64, 0.66)
	var asphalt := Color(0.24, 0.24, 0.25)
	var hx: float = PARADOR_HALF.x / PROP_SCALE
	var hz: float = PARADOR_HALF.y / PROP_SCALE
	var boxes: Array = []

	# --- The ground: a concrete forecourt in front, an asphalt lot behind, parking lines, stains. ----
	pk.block(kit, "concrete", Vector3(-hx + 1.0, 0.0, -hz + 1.0), Vector3(hx - 1.0, 0.07, -1.0), white)
	pk.block(kit, "paint", Vector3(-hx + 1.0, 0.0, -1.0), Vector3(hx - 1.0, 0.06, hz - 1.0), asphalt)
	for k in range(9):
		var lx: float = -33.0 + k * 3.6
		pk.block(kit, "paint", Vector3(lx - 0.06, 0.06, 4.0), Vector3(lx + 0.06, 0.085, 9.5), white)
	var stain_rng := RandomNumberGenerator.new()
	stain_rng.seed = 404
	for k in range(14):
		var c := Vector3(stain_rng.randf_range(-20.0, 4.0), 0.095, stain_rng.randf_range(-17.0, -6.0))
		pk.box(kit, "paint", Transform3D(Basis(Vector3.UP, stain_rng.randf() * TAU), c), Vector3(stain_rng.randf_range(0.5, 1.4), 0.005, stain_rng.randf_range(0.4, 1.0)), Color(0.42, 0.40, 0.38))

	# --- The canopy over the pumps: a white roof with a red fascia striped white, on six columns,
	# lit underneath; three islands, two pumps each. -----------------------------------------------
	var cc := Vector3(-8.0, 0.0, -11.5)
	pk.box(kit, "paint", Transform3D(Basis(), cc + Vector3(0, 5.25, 0)), Vector3(22.0, 0.5, 11.0), white)
	# The fascia's top stands 8cm under the roof's (a shared top face flickered).
	pk.box(kit, "paint", Transform3D(Basis(), cc + Vector3(0, 5.01, 0)), Vector3(22.4, 0.82, 11.4), red)
	pk.box(kit, "paint", Transform3D(Basis(), cc + Vector3(0, 5.12, 0)), Vector3(22.44, 0.16, 11.44), white)
	for lx in [-9.0, -4.5, 0.0, 4.5, 9.0]:
		for lz in [-3.0, 0.0, 3.0]:
			pk.box(kit, "lamp", Transform3D(Basis(), cc + Vector3(lx, 4.52, lz)), Vector3(1.6, 0.06, 0.6), Color(1, 1, 1))
	for ix in [-8.0, 0.0, 8.0]:
		var ic: Vector3 = cc + Vector3(ix, 0.0, 0.0)
		pk.box(kit, "concrete", Transform3D(Basis(), ic + Vector3(0, 0.15, 0)), Vector3(1.6, 0.22, 7.0), white)
		for ez in [-3.6, 3.6]:
			pk.box(kit, "paint", Transform3D(Basis(), ic + Vector3(0, 0.17, ez)), Vector3(1.66, 0.22, 0.25), yellow)
			# Bollards at the island ends, and the column that carries the roof.
			pk.tube(kit, "paint", ic + Vector3(0, 0.26, ez * 1.08), ic + Vector3(0, 1.2, ez * 1.08), 0.12, 0.12, 8, yellow)
		pk.box(kit, "paint", Transform3D(Basis(), ic + Vector3(0, 2.7, 0)), Vector3(0.5, 4.9, 0.5), white)
		boxes.append([ic + Vector3(0, 1.3, 0), Vector3(1.6, 2.6, 7.0)])
		for pz in [-1.8, 1.8]:
			var pc: Vector3 = ic + Vector3(0, 0.26, pz)
			pk.box(kit, "paint", Transform3D(Basis(), pc + Vector3(0, 0.9, 0)), Vector3(0.7, 1.8, 1.0), red)
			pk.box(kit, "paint", Transform3D(Basis(), pc + Vector3(0, 1.95, 0)), Vector3(0.76, 0.32, 1.06), white)
			pk.box(kit, "paint", Transform3D(Basis(), pc + Vector3(0, 0.05, 0)), Vector3(0.8, 0.1, 1.1), dark)
			for sx in [-1.0, 1.0]:
				# The screen and the price window, a nozzle in its holster, the hose looping down.
				pk.box(kit, "glass", Transform3D(Basis(), pc + Vector3(sx * 0.36, 1.35, 0.15)), Vector3(0.03, 0.4, 0.5), dark)
				pk.box(kit, "lamp", Transform3D(Basis(), pc + Vector3(sx * 0.37, 1.65, -0.25)), Vector3(0.02, 0.12, 0.3), Color(0.4, 1.0, 0.5))
				pk.box(kit, "matte", Transform3D(Basis(), pc + Vector3(sx * 0.4, 1.0, -0.3)), Vector3(0.1, 0.3, 0.12), dark)
				pk.tube(kit, "matte", pc + Vector3(sx * 0.4, 1.0, -0.3), pc + Vector3(sx * 0.62, 0.35, -0.1), 0.035, 0.035, 5, dark)
				pk.tube(kit, "matte", pc + Vector3(sx * 0.62, 0.35, -0.1), pc + Vector3(sx * 0.38, 1.7, 0.3), 0.035, 0.035, 5, dark)
		# A bin and a bucket of squeegees at the end of each island.
		pk.tube(kit, "paint", ic + Vector3(0.4, 0.26, 2.9), ic + Vector3(0.4, 1.2, 2.9), 0.25, 0.25, 10, Color(0.25, 0.32, 0.30))
		pk.tube(kit, "paint", ic + Vector3(-0.4, 0.26, 2.9), ic + Vector3(-0.4, 0.7, 2.9), 0.18, 0.2, 10, Color(0.20, 0.36, 0.62))
	for cx in [-10.4, 10.4]:
		for dz in [-4.6, 4.6]:
			pk.box(kit, "paint", Transform3D(Basis(), cc + Vector3(cx, 2.4, dz)), Vector3(0.45, 4.8, 0.45), white)
			boxes.append([cc + Vector3(cx, 2.4, dz), Vector3(0.5, 4.8, 0.5)])
	# The air and water post.
	pk.box(kit, "paint", Transform3D(Basis(), Vector3(4.6, 0.8, -17.5)), Vector3(0.5, 1.6, 0.4), Color(0.20, 0.36, 0.62))
	pk.tube(kit, "matte", Vector3(4.6, 1.2, -17.75), Vector3(4.9, 0.3, -18.1), 0.03, 0.03, 5, dark)

	# --- The shop: flat roof and parapet, a glazed front with its door, a sign band and an awning,
	# posters in the windows; an ice chest, a gas-bottle cage and a bench outside. ------------------
	var shop := Vector3(11.0, 0.0, -6.0)
	pk.box(kit, "paint", Transform3D(Basis(), shop + Vector3(0, 2.2, 0)), Vector3(13.0, 4.4, 10.0), cream)
	pk.box(kit, "paint", Transform3D(Basis(), shop + Vector3(0, 4.55, 0)), Vector3(13.3, 0.5, 10.3), white)
	pk.box(kit, "paint", Transform3D(Basis(), shop + Vector3(0, 3.75, -5.06)), Vector3(12.4, 0.9, 0.12), red)
	for wx in [-5.0, -2.0, 4.0]:
		pk.box(kit, "glass", Transform3D(Basis(), shop + Vector3(wx, 1.65, -5.03)), Vector3(2.6, 2.3, 0.08), dark)
		pk.box(kit, "paint", Transform3D(Basis(), shop + Vector3(wx, 0.45, -5.05)), Vector3(2.8, 0.12, 0.1), white)
		pk.box(kit, "paint", Transform3D(Basis(), shop + Vector3(wx, 2.86, -5.05)), Vector3(2.8, 0.12, 0.1), white)
		pk.box(kit, "paint", Transform3D(Basis(), shop + Vector3(wx + 0.5, 1.9, -5.09)), Vector3(0.7, 0.9, 0.02), [yellow, Color(0.3, 0.55, 0.85), red][int(wx + 5.0) % 3])
	pk.box(kit, "glass", Transform3D(Basis(), shop + Vector3(1.0, 1.35, -5.03)), Vector3(1.8, 2.7, 0.08), Color(0.2, 0.25, 0.28))
	pk.box(kit, "metal", Transform3D(Basis(), shop + Vector3(1.0, 1.35, -5.1)), Vector3(0.06, 2.7, 0.06), steel)
	pk.box(kit, "paint", Transform3D(Basis(), shop + Vector3(0, 3.1, -5.9)), Vector3(13.0, 0.12, 1.8), red)
	for ax in [-6.0, 6.0]:
		pk.tube(kit, "metal", shop + Vector3(ax, 0.07, -6.7), shop + Vector3(ax, 3.05, -6.7), 0.06, 0.06, 6, steel)
	pk.box(kit, "paint", Transform3D(Basis(), shop + Vector3(-4.6, 0.6, -6.0)), Vector3(1.6, 1.1, 0.8), white)
	pk.box(kit, "paint", Transform3D(Basis(), shop + Vector3(-4.6, 1.16, -6.0)), Vector3(1.62, 0.04, 0.82), Color(0.2, 0.45, 0.8))
	for gx in range(4):
		pk.tube(kit, "paint", shop + Vector3(4.2 + gx * 0.45, 0.07, -6.0), shop + Vector3(4.2 + gx * 0.45, 1.0, -6.0), 0.17, 0.17, 8, Color(0.85, 0.82, 0.78))
	pk.box(kit, "metal", Transform3D(Basis(), shop + Vector3(4.9, 0.75, -6.0)), Vector3(2.0, 1.5, 0.9), Color(0.45, 0.47, 0.48))
	pk.box(kit, "wood", Transform3D(Basis(), shop + Vector3(-2.8, 0.45, -6.4)), Vector3(2.0, 0.08, 0.45), Color(0.48, 0.34, 0.22))
	for bx in [-3.6, -2.0]:
		pk.box(kit, "metal", Transform3D(Basis(), shop + Vector3(bx, 0.22, -6.4)), Vector3(0.06, 0.44, 0.4), dark)
	for rx in [-4.0, 2.0]:
		pk.box(kit, "metal", Transform3D(Basis(), shop + Vector3(rx, 5.15, 1.5)), Vector3(1.6, 0.9, 1.2), Color(0.70, 0.71, 0.70))
	boxes.append([shop + Vector3(0, 2.3, 0), Vector3(13.2, 4.6, 10.2)])

	# --- The diner: a streamlined body with round ends, a band of windows between chrome strips, a
	# roof sign on a frame; a patio of tables under parasols in front. ------------------------------
	var dn := Vector3(29.0, 0.0, -8.0)
	var dl := 5.5
	var dr := 3.5
	pk.box(kit, "paint", Transform3D(Basis(), dn + Vector3(0, 0.25, 0)), Vector3(dl * 2.0 + dr * 2.0 + 0.4, 0.5, dr * 2.0 + 0.4), Color(0.55, 0.55, 0.56))
	pk.box(kit, "paint", Transform3D(Basis(), dn + Vector3(0, 2.05, 0)), Vector3(dl * 2.0, 3.1, dr * 2.0), Color(0.86, 0.84, 0.80))
	pk.box(kit, "glass", Transform3D(Basis(), dn + Vector3(0, 2.1, 0)), Vector3(dl * 2.0, 1.3, dr * 2.0 + 0.06), dark)
	for ex in [-dl, dl]:
		pk.tube(kit, "paint", dn + Vector3(ex, 0.5, 0), dn + Vector3(ex, 3.6, 0), dr, dr, 24, Color(0.86, 0.84, 0.80))
		pk.tube(kit, "glass", dn + Vector3(ex, 1.45, 0), dn + Vector3(ex, 2.75, 0), dr + 0.03, dr + 0.03, 24, dark, false)
	for sy in [1.35, 2.85, 3.55]:
		pk.box(kit, "chrome", Transform3D(Basis(), dn + Vector3(0, sy, 0)), Vector3(dl * 2.0, 0.08, dr * 2.0 + 0.1), steel)
		for ex in [-dl, dl]:
			pk.tube(kit, "chrome", dn + Vector3(ex, sy - 0.04, 0), dn + Vector3(ex, sy + 0.04, 0), dr + 0.05, dr + 0.05, 24, steel, false)
	pk.box(kit, "paint", Transform3D(Basis(), dn + Vector3(0, 3.62, 0)), Vector3(dl * 2.0, 0.08, dr * 2.0), Color(0.55, 0.55, 0.56))
	pk.box(kit, "paint", Transform3D(Basis(), dn + Vector3(-3.0, 1.3, -dr - 0.05)), Vector3(1.4, 2.4, 0.1), teal)
	# The roof sign.
	for fx in [-3.5, 3.5]:
		pk.beam(kit, "metal", dn + Vector3(fx, 3.6, 0), dn + Vector3(fx, 6.2, 0), 0.12, 0.12, steel)
	pk.box(kit, "paint", Transform3D(Basis(), dn + Vector3(0, 6.6, 0)), Vector3(9.0, 1.6, 0.3), teal)
	pk.box(kit, "paint", Transform3D(Basis(), dn + Vector3(0, 6.6, 0)), Vector3(9.2, 1.8, 0.24), white)
	pk.tube(kit, "metal", dn + Vector3(4.5, 3.6, 1.5), dn + Vector3(4.5, 5.4, 1.5), 0.2, 0.2, 8, Color(0.4, 0.4, 0.42))
	boxes.append([dn + Vector3(0, 1.8, 0), Vector3(dl * 2.0 + dr * 2.0, 3.6, dr * 2.0)])
	var pr := RandomNumberGenerator.new()
	pr.seed = 77
	for k in range(4):
		var tc: Vector3 = dn + Vector3(-6.6 + k * 4.4, 0.07, -dr - 3.2)
		pk.tube(kit, "metal", tc, tc + Vector3(0, 0.75, 0), 0.05, 0.05, 6, steel)
		pk.lathe(kit, "paint", tc + Vector3(0, 0.75, 0), [Vector2(0.0, 0.0), Vector2(0.55, 0.0), Vector2(0.55, 0.04), Vector2(0.0, 0.04)], 12, white, true)
		pk.tube(kit, "metal", tc + Vector3(0, 0.79, 0), tc + Vector3(0, 2.5, 0), 0.03, 0.03, 5, steel)
		var umb: Color = [red, teal, yellow, Color(0.85, 0.85, 0.82)][k]
		pk.lathe(kit, "canvas", tc + Vector3(0, 2.2, 0), [Vector2(1.5, 0.0), Vector2(1.2, 0.18), Vector2(0.6, 0.38), Vector2(0.0, 0.5)], 12, umb)
		for c4 in range(3):
			var ca: float = TAU * float(c4) / 3.0 + pr.randf()
			var chair: Vector3 = tc + Vector3(cos(ca) * 0.95, 0.0, sin(ca) * 0.95)
			pk.box(kit, "metal", Transform3D(Basis(Vector3.UP, -ca), chair + Vector3(0, 0.45, 0)), Vector3(0.45, 0.05, 0.45), Color(0.3, 0.3, 0.32))
			pk.box(kit, "metal", Transform3D(Basis(Vector3.UP, -ca), chair + Vector3(cos(ca) * 0.2, 0.75, sin(ca) * 0.2)), Vector3(0.05, 0.6, 0.45), Color(0.3, 0.3, 0.32))

	# --- The motel: a row of rooms under a walkway roof on posts, the office at its end. ---------------
	var mz := 14.0
	var rooms := 8
	var room_w := 4.4
	var mx0: float = -36.0
	pk.box(kit, "paint", Transform3D(Basis(), Vector3(mx0 + rooms * room_w * 0.5, 1.6, mz + 3.5)), Vector3(rooms * room_w, 3.2, 7.0), adobe)
	pk.box(kit, "paint", Transform3D(Basis(), Vector3(mx0 + rooms * room_w * 0.5, 3.35, mz + 3.3)), Vector3(rooms * room_w + 0.4, 0.3, 7.8), Color(0.55, 0.30, 0.20))
	pk.box(kit, "concrete", Transform3D(Basis(), Vector3(mx0 + rooms * room_w * 0.5, 0.12, mz - 1.0)), Vector3(rooms * room_w, 0.15, 2.2), white)
	for k in range(rooms):
		var rx: float = mx0 + room_w * (float(k) + 0.5)
		var door_col: Color = [teal, Color(0.62, 0.20, 0.14), Color(0.86, 0.66, 0.20), Color(0.24, 0.36, 0.58)][k % 4]
		pk.box(kit, "paint", Transform3D(Basis(), Vector3(rx - 0.9, 1.1, mz - 0.03)), Vector3(1.0, 2.15, 0.08), door_col)
		pk.box(kit, "glass", Transform3D(Basis(), Vector3(rx + 0.8, 1.5, mz - 0.03)), Vector3(1.5, 1.0, 0.08), dark)
		pk.box(kit, "paint", Transform3D(Basis(), Vector3(rx + 0.8, 0.95, mz - 0.06)), Vector3(1.7, 0.1, 0.12), white)
		pk.box(kit, "metal", Transform3D(Basis(), Vector3(rx + 0.8, 0.5, mz - 0.35)), Vector3(0.8, 0.55, 0.5), Color(0.75, 0.75, 0.74))
		# The walkway's posts, every other room.
		if k % 2 == 0:
			pk.box(kit, "wood", Transform3D(Basis(), Vector3(rx - room_w * 0.5, 1.6, mz - 2.0)), Vector3(0.18, 3.0, 0.18), Color(0.45, 0.32, 0.22))
	pk.box(kit, "paint", Transform3D(Basis(), Vector3(mx0 + rooms * room_w * 0.5, 3.1, mz - 1.0)), Vector3(rooms * room_w, 0.15, 2.4), Color(0.55, 0.30, 0.20))
	boxes.append([Vector3(mx0 + rooms * room_w * 0.5, 1.6, mz + 3.5), Vector3(rooms * room_w, 3.2, 7.0)])
	var office := Vector3(mx0 + rooms * room_w + 3.5, 0.0, mz + 2.5)
	pk.box(kit, "paint", Transform3D(Basis(), office + Vector3(0, 1.8, 0)), Vector3(7.0, 3.6, 6.0), adobe)
	pk.box(kit, "paint", Transform3D(Basis(), office + Vector3(0, 3.75, 0)), Vector3(7.4, 0.3, 6.4), Color(0.55, 0.30, 0.20))
	pk.box(kit, "glass", Transform3D(Basis(), office + Vector3(0.6, 1.5, -3.03)), Vector3(3.6, 1.6, 0.08), dark)
	pk.box(kit, "paint", Transform3D(Basis(), office + Vector3(-2.2, 1.1, -3.03)), Vector3(1.0, 2.2, 0.08), teal)
	boxes.append([office + Vector3(0, 1.8, 0), Vector3(7.0, 3.6, 6.0)])

	# --- The workshop: a shed under a pitched roof of iron, two roll-up doors (one up, its bay dark),
	# tyres stacked outside, oil drums, a wreck waiting for parts. -----------------------------------
	var ws := Vector3(-30.5, 0.0, -3.0)
	var ww := 12.0
	var wd := 10.0
	pk.box(kit, "paint", Transform3D(Basis(), ws + Vector3(0, 2.4, 0)), Vector3(ww, 4.8, wd), Color(0.70, 0.68, 0.62))
	for side in [-1.0, 1.0]:
		var a0: Vector3 = ws + Vector3(-ww * 0.5 - 0.3, 4.8, side * (wd * 0.5 + 0.4))
		var a1: Vector3 = ws + Vector3(ww * 0.5 + 0.3, 4.8, side * (wd * 0.5 + 0.4))
		var r0: Vector3 = ws + Vector3(-ww * 0.5 - 0.3, 6.6, 0.0)
		var r1: Vector3 = ws + Vector3(ww * 0.5 + 0.3, 6.6, 0.0)
		var n: Vector3 = Vector3(0.0, 1.0, side * 0.36).normalized()
		pk.quad(kit, "metal", [a0, a1, r1, r0] if side > 0.0 else [a1, a0, r0, r1], n, Color(0.55, 0.36, 0.26))
	for ex in [-1.0, 1.0]:
		var gx: float = ws.x + ex * ww * 0.5
		pk.tri(kit, "paint", Vector3(gx, 4.8, ws.z - wd * 0.5), Vector3(gx, 4.8, ws.z + wd * 0.5), Vector3(gx, 6.6, ws.z), Vector3(ex, 0, 0), Vector3(ex, 0, 0), Vector3(ex, 0, 0), Color(0.70, 0.68, 0.62), Vector3(ex, 0, 0))
	pk.box(kit, "matte", Transform3D(Basis(), ws + Vector3(-2.8, 1.8, -wd * 0.5 - 0.02)), Vector3(4.2, 3.6, 0.06), Color(0.06, 0.06, 0.07))
	pk.box(kit, "metal", Transform3D(Basis(), ws + Vector3(-2.8, 3.55, -wd * 0.5 - 0.06)), Vector3(4.4, 0.3, 0.12), steel)
	pk.box(kit, "metal", Transform3D(Basis(), ws + Vector3(2.8, 1.8, -wd * 0.5 - 0.03)), Vector3(4.2, 3.6, 0.06), Color(0.66, 0.66, 0.64))
	for slat in range(12):
		pk.box(kit, "metal", Transform3D(Basis(), ws + Vector3(2.8, 0.15 + slat * 0.3, -wd * 0.5 - 0.07)), Vector3(4.2, 0.03, 0.02), Color(0.5, 0.5, 0.5))
	pk.box(kit, "paint", Transform3D(Basis(), ws + Vector3(0, 4.3, -wd * 0.5 - 0.06)), Vector3(7.5, 0.8, 0.08), yellow)
	boxes.append([ws + Vector3(0, 2.4, 0), Vector3(ww, 4.8, wd)])
	var tr := RandomNumberGenerator.new()
	tr.seed = 515
	for stack in range(5):
		var tsc := Vector3(-24.6 + (stack % 3) * 1.0, 0.07, -9.0 + float(stack / 3) * 1.0)
		for t in range(tr.randi_range(3, 6)):
			pk.tyre(kit, "rubber", tsc + Vector3(tr.randf_range(-0.05, 0.05), 0.15 + t * 0.29, tr.randf_range(-0.05, 0.05)), 0.24, 0.42, 0.28, 12, Color(0.1, 0.1, 0.1))
	for d in range(5):
		var dc := Vector3(-35.5 + d * 0.75, 0.07, -9.5 + (d % 2) * 0.7)
		pk.tube(kit, "paint", dc, dc + Vector3(0, 1.0, 0), 0.3, 0.3, 10, [Color(0.18, 0.32, 0.55), red, Color(0.25, 0.4, 0.25)][d % 3])
	boxes.append([Vector3(-24.0, 0.8, -8.5), Vector3(3.2, 1.6, 2.2)])

	# --- Restrooms, a picnic ramada, the water tower, the windmill over its stock tank, lot lights. --
	var wc := Vector3(9.0, 0.0, 15.5)
	pk.box(kit, "paint", Transform3D(Basis(), wc + Vector3(0, 1.4, 0)), Vector3(4.0, 2.8, 3.0), adobe)
	pk.box(kit, "paint", Transform3D(Basis(), wc + Vector3(0, 2.95, 0)), Vector3(4.4, 0.25, 3.4), Color(0.55, 0.30, 0.20))
	for dxx in [-0.9, 0.9]:
		pk.box(kit, "paint", Transform3D(Basis(), wc + Vector3(dxx, 1.0, -1.53)), Vector3(0.8, 2.0, 0.06), teal)
	boxes.append([wc + Vector3(0, 1.4, 0), Vector3(4.0, 2.8, 3.0)])
	var ram := Vector3(16.0, 0.0, 14.0)
	for px in [-2.5, 2.5]:
		for pz in [-1.8, 1.8]:
			pk.box(kit, "wood", Transform3D(Basis(), ram + Vector3(px, 1.4, pz)), Vector3(0.2, 2.8, 0.2), Color(0.45, 0.32, 0.22))
	for sl in range(9):
		pk.box(kit, "wood", Transform3D(Basis(), ram + Vector3(-2.8 + sl * 0.7, 2.9, 0)), Vector3(0.35, 0.08, 4.4), Color(0.50, 0.36, 0.24))
	pk.box(kit, "wood", Transform3D(Basis(), ram + Vector3(0, 0.75, 0)), Vector3(3.2, 0.08, 1.0), Color(0.55, 0.40, 0.27))
	for bz in [-0.85, 0.85]:
		pk.box(kit, "wood", Transform3D(Basis(), ram + Vector3(0, 0.45, bz)), Vector3(3.2, 0.06, 0.35), Color(0.55, 0.40, 0.27))
	var wt := Vector3(22.0, 0.0, 17.0)
	for lx in [-1.8, 1.8]:
		for lz in [-1.8, 1.8]:
			pk.tube(kit, "metal", wt + Vector3(lx, 0, lz), wt + Vector3(lx * 0.55, 9.5, lz * 0.55), 0.13, 0.11, 6, Color(0.55, 0.56, 0.56))
	pk.lathe(kit, "metal", wt + Vector3(0, 9.4, 0), [Vector2(0.0, 0.0), Vector2(2.4, 0.0), Vector2(2.5, 0.2), Vector2(2.5, 3.6), Vector2(1.0, 4.8), Vector2(0.0, 5.1)], 16, Color(0.70, 0.71, 0.70))
	boxes.append([wt + Vector3(0, 2.0, 0), Vector3(3.8, 4.0, 3.8)])
	_windmill(pk, kit, WINDMILL_BASE)
	boxes.append([Vector3(31.0, 2.0, 17.0), Vector3(2.6, 4.0, 2.6)])
	pk.lathe(kit, "metal", Vector3(34.5, 0.07, 16.5), [Vector2(0.0, 0.0), Vector2(2.2, 0.0), Vector2(2.2, 0.75), Vector2(2.1, 0.75), Vector2(2.1, 0.1), Vector2(0.0, 0.1)], 20, Color(0.58, 0.60, 0.60))
	pk.lathe(kit, "glass", Vector3(34.5, 0.62, 16.5), [Vector2(0.0, 0.0), Vector2(2.1, 0.0)], 20, Color(0.24, 0.30, 0.22), true)
	boxes.append([Vector3(34.5, 0.4, 16.5), Vector3(4.4, 0.8, 4.4)])
	for lp in [Vector3(-hx + 2.0, 0, -hz + 2.0), Vector3(hx - 2.0, 0, -hz + 2.0), Vector3(-hx + 2.0, 0, 8.0), Vector3(hx - 2.0, 0, 0.0)]:
		pk.tube(kit, "metal", lp, lp + Vector3(0, 7.0, 0), 0.12, 0.09, 8, steel)
		pk.beam(kit, "metal", lp + Vector3(0, 6.9, 0), lp + Vector3(0, 6.9, 1.2 if lp.z < 0.0 else -1.2), 0.1, 0.1, steel)
		pk.box(kit, "lamp", Transform3D(Basis(), lp + Vector3(0, 6.8, 1.2 if lp.z < 0.0 else -1.2)), Vector3(0.5, 0.12, 0.8), Color(1, 1, 1))
		boxes.append([lp + Vector3(0, 3.5, 0), Vector3(0.3, 7.0, 0.3)])

	# --- The pole sign at the road, and the motel's. -------------------------------------------------
	var pole := Vector3(-34.0, 0.0, -18.0)
	pk.tube(kit, "metal", pole, pole + Vector3(0, 9.0, 0), 0.22, 0.18, 10, steel)
	pk.box(kit, "paint", Transform3D(Basis(), pole + Vector3(0, 9.6, 0)), Vector3(4.6, 2.6, 0.5), white)
	pk.box(kit, "paint", Transform3D(Basis(), pole + Vector3(0, 9.6, 0)), Vector3(4.8, 2.8, 0.42), red)
	pk.box(kit, "paint", Transform3D(Basis(), pole + Vector3(0, 7.2, 0)), Vector3(3.6, 1.8, 0.4), dark)
	boxes.append([pole + Vector3(0, 4.0, 0), Vector3(0.5, 8.0, 0.5)])
	var mpole := Vector3(34.0, 0.0, -18.0)
	pk.tube(kit, "metal", mpole, mpole + Vector3(0, 8.0, 0), 0.2, 0.16, 10, steel)
	pk.box(kit, "paint", Transform3D(Basis(), mpole + Vector3(0, 8.8, 0)), Vector3(5.4, 1.8, 0.4), teal)
	pk.box(kit, "paint", Transform3D(Basis(), mpole + Vector3(0, 7.4, 0)), Vector3(3.8, 0.9, 0.36), Color(0.85, 0.3, 0.25))
	boxes.append([mpole + Vector3(0, 4.0, 0), Vector3(0.5, 8.0, 0.5)])

	pk.material_for = func(key: String) -> Material: return _prop_material(key)
	var mi := MeshInstance3D.new()
	mi.name = "ParadorBuildings"
	mi.mesh = _save_baked_resource(pk.commit(kit), "parador")
	root.add_child(mi)

	# Vehicles: at the shop, at the motel's rooms, the diner's, and the wreck by the workshop (CampKit's).
	var camp := CampKit.new(pk)
	var vkit := {}
	for v in [["suv", Color(0.78, 0.74, 0.62), Vector3(8.0, 0.07, -15.0), 0.0], ["van", Color(0.30, 0.42, 0.48), Vector3(14.5, 0.07, -15.5), 180.0],
			["motorhome", Color(0.90, 0.88, 0.84), Vector3(-29.0, 0.07, 7.0), 90.0], ["suv", Color(0.55, 0.12, 0.10), Vector3(-15.0, 0.07, 7.0), 180.0],
			["caravan", Color(0.92, 0.90, 0.86), Vector3(-6.0, 0.07, 7.5), 90.0], ["suv", Color(0.20, 0.22, 0.26), Vector3(25.0, 0.07, -1.5), 90.0],
			["van", Color(0.58, 0.36, 0.22), Vector3(-34.0, 0.07, -13.5), 35.0]]:
		var vb := Basis(Vector3.UP, deg_to_rad(float(v[3])))
		pk.set_frame(frame * Transform3D(vb, v[2]))
		camp.vehicle(vkit, v[0], v[1])
		boxes.append([v[2] + Vector3(0, 1.2, 0), Vector3(2.4, 2.4, 5.6) if v[0] != "motorhome" else Vector3(2.6, 3.2, 8.0), deg_to_rad(float(v[3]))])
	pk.material_for = func(key: String) -> Material: return _prop_material(key)
	var vmi := MeshInstance3D.new()
	vmi.name = "ParadorCars"
	vmi.mesh = _save_baked_resource(pk.commit(vkit), "parador_cars")
	root.add_child(vmi)

	# Its signs.
	_label(root, "PARADOR DEL VIENTO", to_world.call(cc + Vector3(0, 5.05, -5.75)), basis, 0.016 * PROP_SCALE, Color(1, 0.96, 0.9))
	_label(root, "GASOLINA", to_world.call(pole + Vector3(0, 10.1, -0.26)), basis, 0.010 * PROP_SCALE, Color(0.75, 0.1, 0.08))
	_label(root, "1.29", to_world.call(pole + Vector3(0, 9.05, -0.26)), basis, 0.014 * PROP_SCALE, Color(0.1, 0.1, 0.1))
	_label(root, "DIESEL 1.19", to_world.call(pole + Vector3(0, 7.2, -0.21)), basis, 0.0075 * PROP_SCALE, Color(1.0, 0.82, 0.2))
	_label(root, "TIENDA", to_world.call(shop + Vector3(0, 3.75, -5.13)), basis, 0.012 * PROP_SCALE, Color(1, 0.95, 0.85))
	_label(root, "CAFE LA CUCHILLA", to_world.call(dn + Vector3(0, 6.6, -0.17)), basis, 0.0105 * PROP_SCALE, Color(0.95, 0.94, 0.88))
	_label(root, "MOTEL", to_world.call(mpole + Vector3(0, 8.8, -0.21)), basis, 0.016 * PROP_SCALE, Color(0.98, 0.95, 0.85))
	_label(root, "HAY CUARTOS", to_world.call(mpole + Vector3(0, 7.4, -0.19)), basis, 0.0065 * PROP_SCALE, Color(1.0, 0.95, 0.8))
	_label(root, "TALLER", to_world.call(ws + Vector3(0, 4.3, -wd * 0.5 - 0.11)), basis, 0.010 * PROP_SCALE, Color(0.12, 0.12, 0.12))
	# The windmill's wheel turns slowly in the wind (Windmill.gd turns the BladePivot about the hub's axis).
	var mill := Node3D.new()
	mill.name = "ParadorWindmill"
	mill.set_script(load("res://Windmill.gd"))
	mill.set("spin_axis_local", Vector3(0, 0, 1))
	mill.set("spin_degrees_per_second", WINDMILL_SPIN)
	mill.transform = Transform3D(basis, to_world.call(WINDMILL_BASE + WINDMILL_HUB))
	var pivot := Node3D.new()
	pivot.name = "BladePivot"
	mill.add_child(pivot)
	var rpk := PropKit.new()
	rpk.set_frame(Transform3D(Basis().scaled(Vector3.ONE * PROP_SCALE), Vector3.ZERO))
	var rkit := {}
	_windmill_rotor(rpk, rkit)
	rpk.material_for = func(key: String) -> Material: return _prop_material(key)
	var rotor := MeshInstance3D.new()
	rotor.name = "Wheel"
	rotor.mesh = _save_baked_resource(rpk.commit(rkit), "parador_windmill_wheel")
	pivot.add_child(rotor)
	# Added once its pivot is in it: Windmill.gd looks for BladePivot when it enters the tree.
	root.add_child(mill)
	# Collision for everything a cart can reach.
	var body := StaticBody3D.new()
	body.name = "ParadorBody"
	body.set_meta(&"surface", "asphalt")
	root.add_child(body)
	for b in boxes:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = (b[1] as Vector3) * PROP_SCALE
		cs.shape = box
		var yaw: float = float(b[2]) if (b as Array).size() > 2 else 0.0
		cs.transform = Transform3D(basis * Basis(Vector3.UP, yaw), to_world.call(b[0]))
		body.add_child(cs)
	print("  parador: %d colliders" % boxes.size())


## An Aermotor windmill over a stock tank: a lattice tower, a platform, the wheel of vanes facing the
## wind and the tail vane behind it, in a PropKit frame at life size.
func _windmill(pk: PropKit, kit: Dictionary, base: Vector3) -> void:
	var steel := Color(0.58, 0.60, 0.60)
	var h := 10.0
	var corners: Array = [Vector3(-1.3, 0, -1.3), Vector3(1.3, 0, -1.3), Vector3(1.3, 0, 1.3), Vector3(-1.3, 0, 1.3)]
	var tops: Array = []
	for c in corners:
		var top: Vector3 = base + (c as Vector3) * 0.2 + Vector3(0, h, 0)
		pk.beam(kit, "metal", base + c, top, 0.09, 0.09, steel)
		tops.append(top)
	for lvl in range(4):
		var t0: float = float(lvl) / 4.0
		var t1: float = float(lvl + 1) / 4.0
		for k in range(4):
			var a: Vector3 = base + (corners[k] as Vector3).lerp((corners[k] as Vector3) * 0.2, t0) + Vector3(0, h * t0, 0)
			var b: Vector3 = base + (corners[(k + 1) % 4] as Vector3).lerp((corners[(k + 1) % 4] as Vector3) * 0.2, t1) + Vector3(0, h * t1, 0)
			var a2: Vector3 = base + (corners[(k + 1) % 4] as Vector3).lerp((corners[(k + 1) % 4] as Vector3) * 0.2, t0) + Vector3(0, h * t0, 0)
			var b2: Vector3 = base + (corners[k] as Vector3).lerp((corners[k] as Vector3) * 0.2, t1) + Vector3(0, h * t1, 0)
			pk.beam(kit, "metal", a, b, 0.04, 0.04, steel)
			pk.beam(kit, "metal", a2, b2, 0.04, 0.04, steel)
	# The gearbox the wheel turns on (the wheel is _windmill_rotor's, at WINDMILL_HUB).
	pk.box(kit, "metal", Transform3D(Basis(), base + Vector3(0, h + 0.4, 0)), Vector3(0.5, 0.5, 1.6), Color(0.40, 0.42, 0.42))
	# The tail vane.
	pk.beam(kit, "metal", base + Vector3(0, h + 0.45, 0.5), base + Vector3(0, h + 0.5, 2.6), 0.06, 0.06, steel)
	pk.box(kit, "paint", Transform3D(Basis(), base + Vector3(0, h + 0.7, 3.1)), Vector3(0.03, 1.1, 1.4), Color(0.8, 0.78, 0.74))
	# The pump rod down the middle, and the pipe to the tank.
	pk.tube(kit, "metal", base + Vector3(0, 0.0, 0), base + Vector3(0, h, 0), 0.04, 0.04, 6, Color(0.35, 0.35, 0.35))
	pk.tube(kit, "metal", base + Vector3(0, 0.6, 0), base + Vector3(2.6, 0.6, -0.4), 0.06, 0.06, 6, Color(0.35, 0.35, 0.35))


## The windmill's wheel, round its hub at the origin (the same frame as _windmill's, at life size): eighteen
## curved vanes between two rims, facing -z. It is its own mesh on a pivot that Windmill.gd turns.
func _windmill_rotor(pk: PropKit, kit: Dictionary) -> void:
	var steel := Color(0.58, 0.60, 0.60)
	pk.tube(kit, "metal", Vector3.ZERO, Vector3(0, 0, -0.25), 0.15, 0.15, 8, Color(0.4, 0.42, 0.42))
	var blades := 18
	for k in range(blades):
		var a: float = TAU * float(k) / float(blades)
		var d := Vector3(cos(a), sin(a), 0.0)
		var tang := Vector3(-sin(a), cos(a), 0.0)
		var basis_v := Basis(tang, d, Vector3(0, 0, 1)) * Basis(Vector3.UP, 0.45)
		pk.box(kit, "metal", Transform3D(basis_v, d * 1.35 + Vector3(0, 0, -0.12)), Vector3(0.32, 1.5, 0.02), Color(0.76, 0.77, 0.76))
		pk.beam(kit, "metal", Vector3.ZERO, d * 0.65, 0.03, 0.03, steel)
	for rr in [0.65, 2.05]:
		pk.tyre(kit, "metal", Vector3(0, 0, -0.12), rr - 0.03, rr + 0.03, 0.05, 28, steel, Basis(Vector3.RIGHT, PI * 0.5))


## A static body for a set of props, with the `surface` its colliders give a cart that lands on them.
func _solid_body(parent: Node, body_name: String, surface: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.set_meta(&"surface", surface)
	parent.add_child(body)
	return body


func _solid_box(body: StaticBody3D, xf: Transform3D, size: Vector3) -> void:
	var box := BoxShape3D.new()
	box.size = size
	var cs := CollisionShape3D.new()
	cs.shape = box
	cs.transform = xf
	body.add_child(cs)


func _solid_cylinder(body: StaticBody3D, centre: Vector3, radius: float, height: float) -> void:
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	var cs := CollisionShape3D.new()
	cs.shape = cyl
	cs.position = centre
	body.add_child(cs)


## A sign's text: a Label3D standing in the frame `basis` (its front facing -z).
func _label(parent: Node, text: String, at: Vector3, basis: Basis, pixel: float, col: Color) -> void:
	var lab := Label3D.new()
	lab.text = text
	lab.font_size = 64
	lab.pixel_size = pixel
	lab.modulate = col
	lab.outline_size = 0
	lab.double_sided = false
	lab.shaded = true
	# A Label3D reads from its +z: turn it to face the way the sign does (-z).
	lab.transform = Transform3D(basis * Basis(Vector3.UP, PI), at)
	parent.add_child(lab)


## Guardrails where the road runs along a drop: the shelf road and the hairpin on their outside, the
## upper leg over the shelf road. W-beam on posts, with a box collider per span.
func _build_guardrails(level_scene: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Guardrails"
	level_scene.add_child(root)
	var runs: Array = [
		[_seg_s(SEG_SHELF, 0.05), _seg_s(SEG_HAIRPIN, 1.0), -1.0],
		[_seg_s(6, 0.0), _seg_s(6, 0.92), 1.0],
	]
	var pk := PropKit.new()
	var kit := {}
	var galv := Color(0.70, 0.72, 0.74)
	var body := StaticBody3D.new()
	body.name = "GuardrailBody"
	body.set_meta(&"surface", "asphalt")
	root.add_child(body)
	var lat_off: float = ROAD_HALF + 1.15
	for run in runs:
		var s0: float = run[0]
		var s1: float = run[1]
		var side: float = run[2]
		var prev := Vector3.ZERO
		var s: float = s0
		var first := true
		while s <= s1 + 0.01:
			var sp: Dictionary = _spot(s, side * lat_off, 0.0)
			var p: Vector3 = sp["pos"]
			p.y = _ground_at(p.x, p.z)
			pk.box(kit, "metal", Transform3D(Basis(Vector3.UP, deg_to_rad(float(sp["yaw"]))), p + Vector3(0, 0.6, 0)), Vector3(0.14, 1.2, 0.14), Color(0.52, 0.53, 0.54))
			if not first:
				var mid: Vector3 = (prev + p) * 0.5
				var d: Vector3 = p - prev
				var length: float = d.length()
				var yaw: float = atan2(d.x, d.z)
				var pitch: float = -atan2(d.y, Vector2(d.x, d.z).length())
				var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
				for band in [[0.85, 0.22], [1.07, 0.12]]:
					pk.box(kit, "metal", Transform3D(b, mid + Vector3(0, float(band[0]), 0) - (sp["right"] as Vector3) * side * 0.08), Vector3(0.05, float(band[1]), length + 0.05), galv)
				var cs := CollisionShape3D.new()
				var box := BoxShape3D.new()
				box.size = Vector3(0.3, 1.3, length + 0.1)
				cs.shape = box
				cs.transform = Transform3D(b, mid + Vector3(0, 0.65, 0))
				body.add_child(cs)
			prev = p
			first = false
			s += 3.2
	pk.material_for = func(key: String) -> Material: return _prop_material(key)
	var mi := MeshInstance3D.new()
	mi.name = "GuardrailMesh"
	mi.mesh = _save_baked_resource(pk.commit(kit), "guardrails")
	root.add_child(mi)


## Telegraph poles along the tarmac on the west bank, wires sagging between them.
func _build_poles(level_scene: Node3D) -> void:
	var root := Node3D.new()
	root.name = "TelegraphPoles"
	level_scene.add_child(root)
	var pk := PropKit.new()
	var kit := {}
	var wood := Color(0.36, 0.27, 0.20)
	var tops: Array = []
	var body: StaticBody3D = _solid_body(root, "TelegraphPoleBody", "wood")
	var s: float = _paved_s0 + 20.0
	var end_s: float = _lap_len + _bridge_s0 - 40.0
	while s < end_s:
		var ss: float = fposmod(s, _lap_len)
		var sp: Dictionary = _spot(ss, 17.0, 0.0)
		if absf(ss - _arch_s) > 30.0 and absf(ss - (PARADOR_AT.x)) > 66.0 and not _near_sign(sp["pos"], 1.5):
			var p: Vector3 = sp["pos"]
			p.y = _ground_at(p.x, p.z) - 0.3
			var r: Vector3 = sp["right"]
			var f: Vector3 = sp["fwd"]
			pk.tube(kit, "wood", p, p + Vector3(0, 10.3, 0), 0.2, 0.15, 7, wood)
			_solid_cylinder(body, p + Vector3(0, 5.15, 0), 0.2, 10.3)
			var arm := p + Vector3(0, 9.6, 0)
			pk.beam(kit, "wood", arm - r * 1.3, arm + r * 1.3, 0.16, 0.14, wood, f)
			var ends: Array = []
			for k in [-1.1, 0.0, 1.1]:
				var ins: Vector3 = arm + r * float(k) + Vector3(0, 0.08, 0)
				pk.tube(kit, "metal", ins, ins + Vector3(0, 0.22, 0), 0.05, 0.04, 6, Color(0.40, 0.55, 0.50))
				ends.append(ins + Vector3(0, 0.2, 0))
			tops.append(ends)
		else:
			tops.append([])
		s += 46.0
	for i in range(tops.size() - 1):
		if (tops[i] as Array).is_empty() or (tops[i + 1] as Array).is_empty():
			continue
		for k in range(3):
			var a: Vector3 = tops[i][k]
			var b: Vector3 = tops[i + 1][k]
			var prev := a
			for t in range(1, 9):
				var u: float = float(t) / 8.0
				var q: Vector3 = a.lerp(b, u) - Vector3(0, 0.9 * 4.0 * u * (1.0 - u), 0)
				pk.tube(kit, "matte", prev, q, 0.025, 0.025, 4, Color(0.08, 0.08, 0.08), false)
				prev = q
	pk.material_for = func(key: String) -> Material: return _prop_material(key)
	var mi := MeshInstance3D.new()
	mi.name = "PoleMesh"
	mi.mesh = _save_baked_resource(pk.commit(kit), "telegraph_poles")
	mi.visibility_range_end = 900.0
	root.add_child(mi)


## Marker posts along the dirt sections (white, a red band at the top), and orange pennants beside
## each kicker.
func _build_markers(level_scene: Node3D, lips: Array) -> void:
	var root := Node3D.new()
	root.name = "TrailMarkers"
	level_scene.add_child(root)
	var pk := PropKit.new()
	var kit := {}
	var body: StaticBody3D = _solid_body(root, "TrailMarkerBody", "wood")
	var s: float = _paved_s1 + 15.0
	while s < _paved_s0 - 15.0:
		if not (s > _slot_s0 - 4.0 and s < _slot_s1 + 4.0) and absf(s - _ford_s) > 40.0:
			for side in [-1.0, 1.0]:
				var sp: Dictionary = _spot(s, side * (ROAD_HALF + 2.6), 0.0)
				var p: Vector3 = sp["pos"]
				p.y = _ground_at(p.x, p.z)
				pk.box(kit, "paint", Transform3D(Basis(Vector3.UP, deg_to_rad(float(sp["yaw"]))), p + Vector3(0, 0.65, 0)), Vector3(0.16, 1.3, 0.16), Color(0.93, 0.92, 0.88))
				pk.box(kit, "paint", Transform3D(Basis(Vector3.UP, deg_to_rad(float(sp["yaw"]))), p + Vector3(0, 1.18, 0)), Vector3(0.17, 0.22, 0.17), Color(0.80, 0.12, 0.08))
				_solid_box(body, Transform3D(Basis(Vector3.UP, deg_to_rad(float(sp["yaw"]))), p + Vector3(0, 0.65, 0)), Vector3(0.18, 1.3, 0.18))
		s += 28.0
	for lip in lips:
		for side in [-1.0, 1.0]:
			var lat := 7.6
			var sp2: Dictionary = _spot(float(lip), side * lat, 0.0)
			var p2: Vector3 = sp2["pos"]
			var top_y: float = _road_y(float(lip)) + KICK_H + 3.2
			# The pole stands on what is under it: the kicker's shoulder, falling from the top's edge (6.4m
			# out, KICK_H up) to KICK_SINK under the road (_build_kickers), or the ground where La Bajada's
			# embankment falls away. It used to start at the lip's height and hang in the air over both.
			var shoulder: float = KICK_SHOULDER + KICK_H * 1.2
			var on_kicker: float = _road_y(float(lip)) + KICK_H - (lat - 6.4) / shoulder * (KICK_H + KICK_SINK)
			p2.y = maxf(on_kicker, _ground_at(p2.x, p2.z)) - 0.25
			pk.tube(kit, "paint", p2, Vector3(p2.x, top_y, p2.z), 0.06, 0.05, 6, Color(0.9, 0.9, 0.88))
			_solid_cylinder(body, (p2 + Vector3(p2.x, top_y, p2.z)) * 0.5, 0.07, top_y - p2.y)
			var f: Vector3 = sp2["fwd"]
			var t0 := Vector3(p2.x, top_y - 0.05, p2.z)
			pk.tri(kit, "paint", t0, t0 + Vector3(0, -0.8, 0), t0 - f * 1.2 + Vector3(0, -0.4, 0), sp2["right"], sp2["right"], sp2["right"], Color(0.95, 0.42, 0.08), sp2["right"])
			pk.tri(kit, "paint", t0, t0 - f * 1.2 + Vector3(0, -0.4, 0), t0 + Vector3(0, -0.8, 0), -(sp2["right"] as Vector3), -(sp2["right"] as Vector3), -(sp2["right"] as Vector3), Color(0.95, 0.42, 0.08), -(sp2["right"] as Vector3))
	pk.material_for = func(key: String) -> Material: return _prop_material(key)
	var mi := MeshInstance3D.new()
	mi.name = "MarkerMesh"
	mi.mesh = _save_baked_resource(pk.commit(kit), "trail_markers")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


## Wooden signs naming the sections, on the right a little before each, facing the traffic.
const SECTION_SIGNS := [
	["PUENTE DEL RIO", 2, 0.02], ["LA HORQUILLA", 4, 0.82], ["LA CUCHILLA", 8, 0.55], ["LA BAJADA", 13, 0.1],
	["VALLE DE LOS DUENDES", 17, 0.2], ["LA GARGANTA", 18, 0.75], ["EL VADO", 23, 0.2], ["EL ARCO DEL VIENTO", 25, 0.05],
]

## How far along the lap either way a sign may move from its place in SECTION_SIGNS to find level ground.
const SIGN_SHIFT := 36.0
## The section signs' places (_plan_signs): {text, pos (the board's middle at the highest ground under it),
## fwd, right, width, posts (the ground under each post)}.
var _sign_spots: Array = []

## A sign is wide (the longest 9m across) and stands across the verge, facing the traffic, and the verges
## are rarely level: the shelf road has the cut wall on one side and the drop on the other, La Cuchilla's
## flanks fall away, La Bajada runs on an embankment. Each sign looks along its stretch, on either side, up
## to SIGN_SHIFT either way of its place, for ground that is level under the whole board, near the road's
## height, clear of every leg of the lap and out of the water, and the plants and rocks keep off it
## (_landmarks). It used to stand 11m off the centreline wherever that fell, on the ground under its middle,
## with one post on the road's edge, the other hanging over a bank or buried in a cut.
func _plan_signs() -> void:
	_sign_spots.clear()
	for sg in SECTION_SIGNS:
		var text: String = sg[0]
		var s0: float = _seg_s(int(sg[1]), float(sg[2]))
		var width: float = 1.0 + float(text.length()) * 0.42
		var best: Dictionary = {}
		# Level ground first; where there is none (the shelf road, the end of the ridge), a slope falling
		# away from the road, the board level at the road's height and each post down to its own ground.
		for max_spread in [1.2, 4.0]:
			if not best.is_empty():
				break
			_sign_search(text, s0, width, max_spread, best)
		if best.is_empty():
			push_error("Sign %s: no ground beside the road within %.0fm of its place" % [text, SIGN_SHIFT])
			continue
		_sign_spots.append(best)
		var c: Vector3 = best["pos"]
		_landmarks.append(Vector3(c.x, c.z, width * 0.5 + 2.5))
		print("  sign %s: %+.0fm along, %.1fm under the road, the ground under it %.2fm uneven" % [text, float(best["ds"]), float(best["below"]), float(best["spread"])])


## The best place for a sign within SIGN_SHIFT of s0 whose ground varies by at most `max_spread`, into `best`.
func _sign_search(text: String, s0: float, width: float, max_spread: float, best: Dictionary) -> void:
	var best_score := 1e9
	for side in [1.0, -1.0]:
		var ds := -SIGN_SHIFT
		while ds <= SIGN_SHIFT + 0.01:
			var s: float = fposmod(s0 + ds, _lap_len)
			# Not in the slot canyon, between its walls.
			if s > _slot_s0 - 8.0 and s < _slot_s1 + 8.0:
				ds += 4.0
				continue
			for extra in [0.0, 1.5, 3.0, 5.0]:
				# The inner post stands clear of the trail's marker posts (ROAD_HALF + 2.6).
				var cand: Dictionary = _sign_candidate(s, side * (ROAD_HALF + 3.4 + width * 0.5 + float(extra)), width, max_spread)
				if cand.is_empty():
					continue
				var score: float = float(cand["spread"]) * 2.0 + absf(ds) * 0.04 + float(extra) * 0.15 + (0.0 if side > 0.0 else 0.6) + float(cand["below"]) * 0.8
				if score < best_score:
					best_score = score
					best.clear()
					best.merge(cand)
					best["text"] = text
					best["ds"] = ds
			ds += 4.0


## A sign of `width` across the road at (s, lat): its place, or {} if the ground there won't do.
func _sign_candidate(s: float, lat: float, width: float, max_spread: float) -> Dictionary:
	var sp: Dictionary = _spot(s, lat, 0.0)
	var c: Vector3 = sp["pos"]
	var r: Vector3 = sp["right"]
	var f: Vector3 = sp["fwd"]
	var road_y: float = _road_y(s)
	var gmin := 1e9
	var gmax := -1e9
	for k in range(7):
		var u: float = -0.5 + float(k) / 6.0
		for d in [-0.6, 0.6]:
			var q: Vector3 = c + r * (u * width) + f * float(d)
			if _road_lat(q.x, q.z).x < ROAD_HALF + 2.0 or _in_landmark(q.x, q.z) or _pad_at(q.x, q.z).x > 0.0:
				return {}
			var g: float = _ground_at(q.x, q.z)
			if g < RIVER_Y + 0.8:
				return {}
			gmin = minf(gmin, g)
			gmax = maxf(gmax, g)
	if gmax - gmin > max_spread or gmax > road_y + 1.5 or gmax < road_y - 3.0:
		return {}
	var posts: Array = []
	for k in [-1.0, 1.0]:
		var q2: Vector3 = c + r * (float(k) * width * 0.42)
		posts.append(_ground_at(q2.x, q2.z))
	return {"pos": Vector3(c.x, gmax, c.z), "fwd": f, "right": r, "width": width, "posts": posts,
		"spread": gmax - gmin, "below": maxf(road_y - gmax, 0.0)}


## True within `margin` of a section sign's board.
func _near_sign(p: Vector3, margin: float) -> bool:
	for spot in _sign_spots:
		var c: Vector3 = spot["pos"]
		if Vector2(p.x - c.x, p.z - c.z).length() < float(spot["width"]) * 0.5 + margin:
			return true
	return false


func _build_signs(level_scene: Node3D) -> void:
	var root := Node3D.new()
	root.name = "SectionSigns"
	level_scene.add_child(root)
	var pk := PropKit.new()
	var kit := {}
	var wood := Color(0.42, 0.30, 0.20)
	var board := Color(0.55, 0.40, 0.26)
	var body: StaticBody3D = _solid_body(root, "SectionSignBody", "wood")
	for spot in _sign_spots:
		var p: Vector3 = spot["pos"]
		var f: Vector3 = spot["fwd"]
		var r: Vector3 = spot["right"]
		var width: float = spot["width"]
		# The board faces back down the road: its front is -fwd. Its foot is 1.85m over the highest ground
		# under it; each post runs down into the ground under it.
		var basis := Basis(-r, Vector3.UP, f)
		var board_y: float = p.y + 2.4
		var low: float = p.y
		for i in range(2):
			var k: float = -1.0 if i == 0 else 1.0
			var foot: float = float(spot["posts"][i]) - 0.4
			low = minf(low, foot)
			var top: float = board_y + 0.35
			var q: Vector3 = p + r * k * (width * 0.42)
			pk.box(kit, "wood", Transform3D(basis, Vector3(q.x, (foot + top) * 0.5, q.z)), Vector3(0.22, top - foot, 0.22), wood)
		pk.box(kit, "wood", Transform3D(basis, Vector3(p.x, board_y, p.z)), Vector3(width, 1.1, 0.14), board)
		var top_y: float = board_y + 0.55
		_solid_box(body, Transform3D(basis, Vector3(p.x, (low + top_y) * 0.5, p.z)), Vector3(width * 0.84 + 0.22, top_y - low, 0.24))
		_label(root, spot["text"], Vector3(p.x, board_y, p.z) - f * 0.09, basis, 0.0105, Color(0.98, 0.92, 0.78))
	pk.material_for = func(key: String) -> Material: return _prop_material(key)
	var mi := MeshInstance3D.new()
	mi.name = "SignMesh"
	mi.mesh = _save_baked_resource(pk.commit(kit), "section_signs")
	root.add_child(mi)


# ======================================================================================
#  The start venue
# ======================================================================================

## The start's venue, on the river side of the straight across from the Parador: crowd barriers along the
## verge either side of the line with spectators behind them, a pagoda marquee (VenueKit's, the Lakeside
## Course's beer tent) on its own pad with people at its tables and about it, the RC Vibe GP flag on a tall
## pole by the line, and a few people watching from the Parador's forecourt. Places are [metres along the
## lap from the line, metres right of the centreline]; the river side is left (negative).
const VENUE_TENT := Vector2(-12.0, -31.0)
## The marquee's pad: half extents along and across. Its near edge stands 21m off the centreline, so its
## 10m blend stays off the road's flat strip (ROAD_FLAT).
const VENUE_PAD_HALF := Vector2(14.0, 10.0)
const VENUE_BARRIER_LAT := -11.5
const VENUE_BARRIER_RUN := Vector2(-52.0, 38.0)
const VENUE_FLAG := Vector2(4.0, -15.0)
## The flagpole's height and the flag's length (hoist to fly) and depth, in metres. The flag streams west
## (across the road, the way the wind blows the Parador's windmill round to face east), so the grid sees it
## broadside.
const VENUE_FLAG_POLE := 14.0
const VENUE_FLAG_SIZE := Vector2(6.6, 4.1)
## Along the Parador's forecourt edge: [from, to] along the lap from the line, and how far out.
const VENUE_FORECOURT := Vector3(-4.0, 20.0, 21.0)
## The people: Nyota Stadium's at this level's PROP_SCALE, a Spanish meeting's mix (CrowdPlacer's groups:
## African, South Asian, European, East Asian, Arab or mixed).
const VENUE_PEOPLE_SCALE := PROP_SCALE / 1.86
const VENUE_SKIN := [0.06, 0.04, 0.74, 0.05, 0.11]

## Planned before the dressing, so the plants and rocks keep off it: the barriers [centre, along], the
## spectators (CrowdPlacer spots) and the marquee's and the flag's frames.
var _venue_barriers: Array = []
var _venue_people: Array = []
var _venue_tent := Transform3D()
var _venue_flag := Transform3D()


func _finish_s() -> float:
	return _seg_s(SEG_START, 0.0) + FINISH_OFF


## A frame on the ground at (metres along from the line, metres right): x along the road, y up.
func _venue_frame(along: float, lat: float) -> Transform3D:
	var sp: Dictionary = _spot(fposmod(_finish_s() + along, _lap_len), lat, 0.0)
	var f: Vector3 = sp["fwd"]
	var p: Vector3 = sp["pos"]
	p.y = _ground_at(p.x, p.z)
	return Transform3D(Basis(f, Vector3.UP, f.cross(Vector3.UP)), p)


func _plan_venue() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2207
	_venue_barriers.clear()
	_venue_people.clear()
	_venue_flag = _venue_frame(VENUE_FLAG.x, VENUE_FLAG.y)
	_venue_tent = _venue_frame(VENUE_TENT.x, VENUE_TENT.y)
	var piece: float = 2.3 * PROP_SCALE
	var along: float = VENUE_BARRIER_RUN.x
	while along + piece <= VENUE_BARRIER_RUN.y + 0.01:
		var xf: Transform3D = _venue_frame(along + piece * 0.5, VENUE_BARRIER_LAT)
		_venue_barriers.append(xf)
		_landmarks.append(Vector3(xf.origin.x, xf.origin.z, 3.0))
		# Behind it, facing the road: a front row along it and a looser one further back.
		var away: Vector3 = -xf.basis.z
		for k in range(3):
			if rng.randf() < (0.2 if k < 2 else 0.5):
				continue
			var back: float = rng.randf_range(1.1, 1.7) if k < 2 else rng.randf_range(2.4, 3.6)
			var p: Vector3 = xf.origin + xf.basis.x * rng.randf_range(-piece * 0.45, piece * 0.45) + away * back
			if Vector2(p.x - _venue_flag.origin.x, p.z - _venue_flag.origin.z).length() < 1.4:
				continue
			p.y = _ground_at(p.x, p.z)
			_venue_people.append([p, -away + xf.basis.x * rng.randf_range(-0.35, 0.35), false])
		# Keep the plants out of the crowd (a saguaro grew among them): the rows reach 3.6m back.
		for back in [2.5, 5.0]:
			var lm: Vector3 = xf.origin + away * float(back)
			_landmarks.append(Vector3(lm.x, lm.z, 3.4))
		along += piece
	_landmarks.append(Vector3(_venue_flag.origin.x, _venue_flag.origin.z, 2.5))
	# At the marquee's tables (VenueKit.beer_set at z = -1.2 and 1.2, its benches 0.55 either side, their
	# tops 0.475 up), about two in three seats taken, facing the table; more standing about it.
	var tx: Transform3D = _venue_tent.scaled_local(Vector3.ONE * PROP_SCALE)
	for set_z in [-1.2, 1.2]:
		for bz in [-0.55, 0.55]:
			for x in [-0.72, 0.0, 0.72]:
				if rng.randf() < 0.36:
					continue
				var seat: Vector3 = tx * Vector3(float(x) + rng.randf_range(-0.06, 0.06), 0.475, float(set_z) + float(bz))
				var face: Vector3 = _venue_tent.basis.z * (-signf(float(bz)))
				_venue_people.append([seat, face, true])
	var standing := 0
	var tries := 0
	while standing < 16 and tries < 200:
		tries += 1
		var a: float = rng.randf() * TAU
		var rr: float = rng.randf_range(6.2, 11.0)
		var p: Vector3 = _venue_tent.origin + _venue_tent.basis.x * cos(a) * rr * 1.2 + _venue_tent.basis.z * sin(a) * rr * 0.8
		if _pad_at(p.x, p.z).x < 0.9:
			continue
		p.y = _ground_at(p.x, p.z)
		# In twos and threes, talking, or looking toward the road.
		var look: Vector3 = (_venue_tent.origin - p) if rng.randf() < 0.4 else _venue_tent.basis.z
		_venue_people.append([p, look + Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(-0.5, 0.5)), false])
		standing += 1
		if rng.randf() < 0.6:
			var q: Vector3 = p + Vector3(rng.randf_range(-1.6, 1.6), 0.0, rng.randf_range(-1.6, 1.6))
			if _pad_at(q.x, q.z).x > 0.9:
				q.y = _ground_at(q.x, q.z)
				_venue_people.append([q, p - q, false])
				standing += 1
	# A few at the front of the Parador's forecourt, watching the start.
	var f_along: float = VENUE_FORECOURT.x
	while f_along < VENUE_FORECOURT.y:
		var fx: Transform3D = _venue_frame(f_along, VENUE_FORECOURT.z + rng.randf_range(0.0, 1.2))
		_venue_people.append([fx.origin, -fx.basis.z + fx.basis.x * rng.randf_range(-0.4, 0.4), false])
		f_along += rng.randf_range(1.2, 3.4)


func _build_venue(level_scene: Node3D) -> void:
	var root := Node3D.new()
	root.name = "StartVenue"
	level_scene.add_child(root)
	var pk := PropKit.new()
	pk.material_for = func(key: String) -> Material: return _prop_material(key)
	var camp := CampKit.new(pk)
	var venue := VenueKit.new(pk)
	var body: StaticBody3D = _solid_body(root, "StartVenueBody", "asphalt")
	# The barriers along the verge.
	var bkit := {}
	for xf in _venue_barriers:
		var bx: Transform3D = xf
		pk.set_frame(bx.scaled_local(Vector3.ONE * PROP_SCALE))
		camp.crowd_barrier(bkit)
		_solid_box(body, Transform3D(bx.basis, bx.origin + Vector3(0, 0.9, 0)), Vector3(2.3 * PROP_SCALE, 1.8, 0.3))
	pk.reset_frame()
	var bmi := MeshInstance3D.new()
	bmi.name = "Barriers"
	bmi.mesh = _save_baked_resource(pk.commit(bkit), "venue_barriers")
	bmi.visibility_range_end = 600.0
	root.add_child(bmi)
	# The marquee, trimmed in the logo's orange, its posts and tables solid.
	var tkit := {}
	var tx: Transform3D = _venue_tent.scaled_local(Vector3.ONE * PROP_SCALE)
	pk.set_frame(tx)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3141
	venue.marquee(tkit, Color(0.95, 0.45, 0.08), rng)
	pk.reset_frame()
	var tmi := MeshInstance3D.new()
	tmi.name = "Marquee"
	tmi.mesh = _save_baked_resource(venue.finish(tkit), "venue_marquee")
	root.add_child(tmi)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_solid_cylinder(body, tx * Vector3(float(sx) * 3.0, 1.2, float(sz) * 3.0), 0.2, 2.4 * PROP_SCALE)
	for z in [-1.2, 1.2]:
		_solid_box(body, Transform3D(_venue_tent.basis, tx * Vector3(0.0, 0.39, float(z))), Vector3(2.2, 0.78, 1.35) * PROP_SCALE)
	_build_logo_flag(root, body)
	CrowdPlacer.build(root, _venue_people, VENUE_PEOPLE_SCALE, VENUE_SKIN, 2207, func(res: Resource, n: String) -> Resource: return _save_baked_resource(res, n))
	print("  start venue: %d barriers, %d spectators" % [_venue_barriers.size(), _venue_people.size()])


## The RC Vibe GP flag: a white pole on a concrete foot with a gilt ball on top, and the flag waving from it
## (logo_flag.gdshader, flag_wave's wave), the artwork drawn here (_logo_flag_texture).
func _build_logo_flag(root: Node3D, body: StaticBody3D) -> void:
	var pk := PropKit.new()
	pk.material_for = func(key: String) -> Material: return _prop_material(key)
	var kit := {}
	var foot: Vector3 = _venue_flag.origin
	var top: Vector3 = foot + Vector3(0, VENUE_FLAG_POLE, 0)
	pk.block(kit, "concrete", foot + Vector3(-0.55, -0.3, -0.55), foot + Vector3(0.55, 0.35, 0.55), Color(0.80, 0.78, 0.74))
	pk.tube(kit, "metal", foot, top, 0.13, 0.08, 10, Color(0.92, 0.92, 0.90))
	pk.lathe(kit, "metal", top, [Vector2(0.0, 0.0), Vector2(0.17, 0.1), Vector2(0.2, 0.22), Vector2(0.15, 0.36), Vector2(0.0, 0.42)], 12, Color(0.95, 0.72, 0.22))
	var pmi := MeshInstance3D.new()
	pmi.name = "LogoFlagPole"
	pmi.mesh = _save_baked_resource(pk.commit(kit), "venue_flag_pole")
	root.add_child(pmi)
	_solid_cylinder(body, foot + Vector3(0, VENUE_FLAG_POLE * 0.5, 0), 0.16, VENUE_FLAG_POLE)
	# The flag: a grid from the hoist (u 0, at the pole) to the fly (u 1), streaming along its local +x,
	# facing +z (flag_wave.gdshaderinc reads which way it streams from the normal), UV2 its phase and length.
	var length: float = VENUE_FLAG_SIZE.x
	var depth: float = VENUE_FLAG_SIZE.y
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nu := 28
	var nv := 12
	for j in range(nv + 1):
		for i in range(nu + 1):
			var u: float = float(i) / nu
			var v: float = float(j) / nv
			st.set_normal(Vector3(0, 0, 1))
			st.set_uv(Vector2(u, v))
			st.set_uv2(Vector2(0.0, length))
			st.add_vertex(Vector3(u * length, -v * depth, 0.0))
	for j in range(nv):
		for i in range(nu):
			var a: int = j * (nu + 1) + i
			var b: int = a + 1
			var c: int = a + nu + 1
			var d: int = c + 1
			# Clockwise seen from +z, the front (CLAUDE.md, procedural mesh winding).
			st.add_index(c)
			st.add_index(a)
			st.add_index(d)
			st.add_index(a)
			st.add_index(b)
			st.add_index(d)
	var mesh: ArrayMesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://logo_flag.gdshader")
	mat.set_shader_parameter("flag_tex", _logo_flag_texture())
	mat.set_shader_parameter("amplitude", 0.12)
	mat.set_shader_parameter("speed", 5.5)
	mesh.surface_set_material(0, _save_baked_resource(mat, "logo_flag_material"))
	var fmi := MeshInstance3D.new()
	fmi.name = "LogoFlag"
	fmi.mesh = _save_baked_resource(mesh, "logo_flag")
	# Streaming west: local +x is the venue frame's +z (its right: toward the road from the river side).
	var fly: Vector3 = _venue_flag.basis.z
	fmi.transform = Transform3D(Basis(fly, Vector3.UP, fly.cross(Vector3.UP)), top - Vector3(0, 0.45, 0) + fly * 0.1)
	fmi.extra_cull_margin = length * 0.25
	root.add_child(fmi)


## The flag's artwork: the logo (images/logo_transparent.png) on its own navy between orange bands with a
## white pinstripe, 1024 x 640, mipmapped so it doesn't shimmer at a distance.
func _logo_flag_texture() -> Texture2D:
	var w := 1024
	var h := 640
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color8(14, 26, 64))
	var band := int(h * 0.075)
	img.fill_rect(Rect2i(0, 0, w, band), Color8(244, 120, 24))
	img.fill_rect(Rect2i(0, h - band, w, band), Color8(244, 120, 24))
	var pin := int(h * 0.014)
	img.fill_rect(Rect2i(0, band, w, pin), Color8(240, 240, 236))
	img.fill_rect(Rect2i(0, h - band - pin, w, pin), Color8(240, 240, 236))
	var logo: Image = (load("res://images/logo_transparent.png") as Texture2D).get_image()
	if logo.is_compressed():
		logo.decompress()
	logo.convert(Image.FORMAT_RGBA8)
	var lw := int(w * 0.84)
	var lh := int(float(lw) * logo.get_height() / logo.get_width())
	logo.resize(lw, lh, Image.INTERPOLATE_LANCZOS)
	img.blend_rect(logo, Rect2i(0, 0, lw, lh), Vector2i((w - lw) / 2, (h - lh) / 2))
	img.convert(Image.FORMAT_RGB8)
	img.generate_mipmaps()
	var tex := PortableCompressedTexture2D.new()
	# Kept, or a headless save writes the texture empty (CLAUDE.md, procedural cars).
	tex.keep_compressed_buffer = true
	tex.create_from_image(img, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
	return _save_baked_resource(tex, "logo_flag_texture")


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

	# Checkpoints: up the shelf road, onto the mesa, along the ridge, at the foot of the descent, out
	# of the slot before the ford, and past the arch, so a respawn never skips a hairpin or the ford.
	var checkpoints_container := Node3D.new()
	checkpoints_container.name = "Checkpoints"
	level_scene.add_child(checkpoints_container)
	var cp_offs: Array = [
		_seg_s(SEG_SHELF, 0.25),
		_seg_s(7, 0.6),
		_seg_s(10, 0.5),
		_seg_s(17, 0.6),
		_slot_s1 + 8.0,
		_arch_s + 45.0,
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

	# Boost pads: onto the bridge, up the shelf road, along the ridge, through the hoodoos, and out
	# of the arch toward the line.
	var boost_scene: PackedScene = load("res://BoostPad.tscn")
	var boost_container := Node3D.new()
	boost_container.name = "BoostPads"
	level_scene.add_child(boost_container)
	var bp_defs: Array = [
		["Boost_Puente", _seg_s(SEG_BRIDGE, 0.06), -2.8],
		["Boost_Shelf", _seg_s(SEG_SHELF, 0.55), 2.6],
		["Boost_Cuchilla", _seg_s(10, 0.3), 0.0],
		["Boost_Duendes", _seg_s(SEG_VALLEY, 0.35), -2.5],
		["Boost_Arco", _arch_s + 70.0, 2.5],
	]
	for bd in bp_defs:
		var bp = boost_scene.instantiate()
		bp.name = bd[0]
		var sp2: Dictionary = _spot(bd[1], bd[2], 0.08)
		bp.position = sp2["pos"]
		bp.rotation_degrees = Vector3(0, sp2["yaw"], 0)
		boost_container.add_child(bp)

	# The eagle that patrols the canyon and snatches carts (Eagle.gd), EAGLE_SCALE times the model: about a
	# 10m span, its body as long as a cart (at 10 it dwarfed them).
	var eagle_scene: PackedScene = load("res://models/animals/20260717033727_7db23447.fbx")
	if eagle_scene:
		var eagle: Node3D = eagle_scene.instantiate()
		eagle.name = "Eagle"
		eagle.set_script(load("res://Eagle.gd"))
		var ep: Vector3 = _spot(_seg_s(10, 0.5), 0.0, 70.0)["pos"]
		eagle.transform = Transform3D(Basis().scaled(Vector3.ONE * EAGLE_SCALE), ep)
		level_scene.add_child(eagle)


# ======================================================================================
#  Sky and light
# ======================================================================================

## The haze over the canyon country: pale and a little blue, so the far mesas and the mountains
## fade into mist.
const HAZE := Color(0.76, 0.77, 0.82)

func _build_environment(level_scene: Node3D) -> void:
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://sky_tropical_cumulus.gdshader")
	sky_mat.set_shader_parameter("sky_top", Color(0.17, 0.38, 0.74))
	sky_mat.set_shader_parameter("sky_horizon", Color(0.82, 0.82, 0.84))
	sky_mat.set_shader_parameter("ground_horizon", HAZE)
	sky_mat.set_shader_parameter("ground_bottom", Color(0.50, 0.42, 0.38))
	sky_mat.set_shader_parameter("sky_curve", 0.35)
	sky_mat.set_shader_parameter("horizon_haze", HAZE)
	sky_mat.set_shader_parameter("haze_strength", 0.9)
	sky_mat.set_shader_parameter("haze_height", 0.16)
	sky_mat.set_shader_parameter("sun_tint", Color(1.0, 0.90, 0.74))
	sky_mat.set_shader_parameter("sun_disc_degrees", 1.0)
	sky_mat.set_shader_parameter("sun_glow", 0.6)
	sky_mat.set_shader_parameter("sun_horizon_tint", Color(1.0, 0.76, 0.52))
	sky_mat.set_shader_parameter("sun_horizon_glow", 0.35)
	sky_mat.set_shader_parameter("cloud_lit", Color(1.0, 0.96, 0.90))
	sky_mat.set_shader_parameter("cloud_shade", Color(0.52, 0.52, 0.62))
	sky_mat.set_shader_parameter("cloud_coverage", 0.36)
	sky_mat.set_shader_parameter("cloud_opacity", 0.9)
	sky_mat.set_shader_parameter("cloud_scale", 1.4)
	sky_mat.set_shader_parameter("cloud_seed", 17.3)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.32
	env.ambient_light_color = Color(0.96, 0.88, 0.82)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_bloom = 0.06
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = HAZE
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.2
	env.fog_density = 1.0
	env.fog_depth_begin = 260.0
	env.fog_depth_end = 5200.0
	env.fog_depth_curve = 1.7
	env.fog_sky_affect = 0.06
	env.fog_aerial_perspective = 0.3
	env_node.environment = env
	level_scene.add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	# Late afternoon, low in the west-south-west: it rakes the canyon's walls and throws the hoodoos'
	# shadows long across the valley.
	sun.rotation_degrees = Vector3(-27.0, -72.0, 0.0)
	sun.light_color = Color(1.0, 0.88, 0.72)
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 260.0
	sun.directional_shadow_split_1 = 0.08
	sun.directional_shadow_split_2 = 0.22
	sun.directional_shadow_split_3 = 0.5
	level_scene.add_child(sun)


## The wind that gives the Sierra its name: a low roar that swells in gusts, and the hiss of it
## over the rock, as a seamless loop.
func _wind_stream() -> AudioStreamWAV:
	const RATE := 22050
	const SECONDS := 12.0
	var n: int = int(RATE * SECONDS)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var samples := PackedFloat32Array()
	samples.resize(n)
	var low := 0.0
	var low2 := 0.0
	var band := 0.0
	for i in range(n):
		var t: float = float(i) / float(RATE)
		var white: float = rng.randf_range(-1.0, 1.0)
		low += (white - low) * 0.02
		low2 += (low - low2) * 0.05
		band += (white - band) * 0.25
		var gust: float = 0.55 + 0.45 * sin(t * TAU / 6.0) * sin(t * TAU / 2.6 + 1.3)
		var hiss: float = (white - band) * 0.12 * gust * gust
		samples[i] = low2 * 9.0 * gust + hiss
	var fade: int = int(RATE * 1.0)
	for i in range(fade):
		var t2: float = float(i) / float(fade)
		samples[i] = samples[i] * sqrt(t2) + samples[n - fade + i] * sqrt(1.0 - t2)
	return _pcm_stream(samples, n - fade, RATE, true, "wind_loop")


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


func _build_ambience(level_scene: Node3D) -> void:
	var amb := AudioStreamPlayer.new()
	amb.name = "CanyonWind"
	amb.stream = _wind_stream()
	amb.volume_db = -19.0
	amb.bus = &"SFX"
	amb.autoplay = true
	level_scene.add_child(amb)


# ======================================================================================
#  Build
# ======================================================================================

## A normal map for the rock faces, from dark_rock.png's light and shade (there is none in the
## project), saved lossy-compressed.
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


## Places the bridge, the ford and the arch on the plan: the bridge's middle on the river, the
## ford at FORD_FRAC of its straight, the arch where the road crosses the fin.
func _locate_features() -> void:
	var seg: Dictionary = _segs[SEG_BRIDGE]
	var mid: float = float(seg["s0"]) + float(seg["len"]) * 0.5
	_bridge_s0 = mid - BRIDGE_HALF_SPAN
	_bridge_s1 = mid + BRIDGE_HALF_SPAN
	_ford_s = _seg_s(SEG_FORD, FORD_FRAC)
	var best := INF
	var s: float = _seg_s(SEG_ARCH, 0.0)
	while s < _seg_s(SEG_ARCH, 1.0):
		var d: float = _seg_distance(_plan_p(s), FIN_A, FIN_B)
		if d < best:
			best = d
			_arch_s = s
		s += 0.5
	if best > 3.0:
		push_error("The road misses the fin by %.1fm: no arch to drive through" % best)
	_paved_s0 = _seg_s(int(PAVED_FROM[0]), float(PAVED_FROM[1]))
	_paved_s1 = _seg_s(int(PAVED_TO[0]), float(PAVED_TO[1]))
	_slot_s0 = _seg_s(SEG_SLOT[0], 0.0) - 8.0
	_slot_s1 = _ford_s - 110.0
	print("  bridge s=%.0f..%.0f, ford s=%.0f, arch s=%.0f, tarmac from s=%.0f round to s=%.0f, slot s=%.0f..%.0f" % [
		_bridge_s0, _bridge_s1, _ford_s, _arch_s, _paved_s0, _paved_s1, _slot_s0, _slot_s1])


func _ready() -> void:
	print("=== Canyon Course (Sierra del Viento) Level Generation ===")
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

	# 1. The plan, its features, heights and checks.
	_build_plan()
	_locate_features()
	_build_profile()
	_verify_min_radius()
	_verify_layout()
	_build_ridge_table()
	_find_hairpins()
	_build_river()

	# 2. Track path.
	main_curve = _build_main_curve()
	var track_path := Path3D.new()
	track_path.name = "TrackPath"
	track_path.curve = main_curve
	level_scene.add_child(track_path)

	# 3. Ground.
	_plan_pads()
	_add_road_samples()
	_build_heights()
	print("  heights built (%.1fs)" % ((Time.get_ticks_msec() - t_start) / 1000.0))
	var ground_mat := ShaderMaterial.new()
	ground_mat.shader = load("res://canyon_ground.gdshader")
	var rock_normal: Texture2D = _rock_normal_texture()
	ground_mat.set_shader_parameter("sand_tex", load("res://materials/sand.png"))
	ground_mat.set_shader_parameter("dirt_tex", load("res://materials/dirt.png"))
	ground_mat.set_shader_parameter("gravel_tex", load("res://materials/dark_canyon_rock.png"))
	ground_mat.set_shader_parameter("gravel_normal", load("res://materials/dark_canyon_rock_normal.png"))
	ground_mat.set_shader_parameter("asphalt_tex", load("res://materials/asphalt.png"))
	ground_mat.set_shader_parameter("rock_tex", load("res://materials/dark_rock.png"))
	ground_mat.set_shader_parameter("rock_normal", rock_normal)
	ground_mat.set_shader_parameter("road_half_width", ROAD_HALF)
	ground_mat.set_shader_parameter("horizon_color", HAZE)
	ground_mat.set_shader_parameter("horizon_center", CENTRE)
	_ground_mat = _save_baked_resource(ground_mat, "ground_material")
	var rock_mat := ShaderMaterial.new()
	rock_mat.shader = load("res://canyon_rock.gdshader")
	rock_mat.set_shader_parameter("sand_tex", load("res://materials/sand.png"))
	rock_mat.set_shader_parameter("rock_tex", load("res://materials/dark_rock.png"))
	rock_mat.set_shader_parameter("rock_normal", rock_normal)
	_rock_mat = _save_baked_resource(rock_mat, "rock_material")
	var terrain_root := Node3D.new()
	terrain_root.name = "CanyonTerrain"
	level_scene.add_child(terrain_root)
	_build_terrain(terrain_root, _ground_mat)
	print("  terrain built (%.1fs)" % ((Time.get_ticks_msec() - t_start) / 1000.0))
	_verify_road_ground()

	# 4. Water, the bridge, the slot canyon, the arch, the kickers.
	_build_water(level_scene)
	_build_bridge(level_scene)
	_build_slot_walls(level_scene)
	_build_arch(level_scene)
	_build_hoodoos(level_scene)
	_build_formations(level_scene)
	var lips: Array = _build_kickers(level_scene)
	track_path.set_meta("jump_lips", lips)
	# Planned first, so the plants and rocks keep off them.
	_plan_signs()
	_plan_venue()
	_build_dressing(level_scene)
	_build_parador(level_scene)
	_build_venue(level_scene)
	_build_guardrails(level_scene)
	_build_poles(level_scene)
	_build_markers(level_scene, lips)
	_build_signs(level_scene)

	# 5. Sky, light, gameplay.
	_build_environment(level_scene)
	_build_ambience(level_scene)
	_place_gameplay(level_scene)

	# 6. Save.
	level_scene.set("track_path", track_path)
	level_scene._setup_checkpoints()
	var chunked: int = MeshChunker.chunk_scene(level_scene, "res://generated/" + RES_PREFIX, "res://generated/canyon_chunks", MESH_CHUNK_CELL)
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
