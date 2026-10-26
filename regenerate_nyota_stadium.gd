# regenerate_nyota_stadium.gd
#
# Builds levels/NyotaStadiumLevel.tscn - the second stage of the Matumaini GP: a supercross track
# in a city football stadium on a hot afternoon, that leaves the bowl for a lap of the streets
# outside and drops back in over the corner wall.
#
# The lap: the start/finish straight runs west in front of the main (south) stand. The track
# snakes back and forth across the floor in four lanes joined by bermed hairpins, with the jumps
# in the lanes: the Grandstand Table and the Simba Double on the start straight, the whoops and
# the triple on the second lane, the step-up and a rhythm section on the third, the big Kibo
# Double on the fourth. The fourth lane runs straight out of the north-east corner, up a ramp in
# a cutting to street level, round a city block on tarmac, and back to the south-east corner,
# where the Drop-In launches the field off the yard, over the retaining wall and down the landing
# hill onto the start straight.
#
# Things worth knowing before editing this file:
#
# 1. The lap is planned as turtle segments (PLAN: straights and circular arcs), so the lanes are
#    exactly straight and the hairpins exactly round. Everything else is placed by arc length `s`
#    along that plan, through _plan_at(s).
#
# 2. The track surface is one ribbon (_build_track) built from the height profile along s
#    (_h_at: the jumps are pieces of that profile, see _plan_profile) plus the berm across the
#    hairpins (_berm_lift). Its shoulders run down into the arena floor, which sits FLOOR_Y below
#    the flat lanes. The ribbon is dirt in the bowl and tarmac outside; the vertex colour tells the
#    shader which (stadium_track.gdshader). The ribbon's collision is split by surface into
#    StadiumTrack and StreetTrack bodies: PlayerCart counts both as track ("track" in the name),
#    and the arena floor (ArenaInfield) as off-road.
#
# 3. The arena floor is FLOOR_Y; the streets are STREET_Y higher. The four stands stand on the
#    edges of the sunken floor and stop short of the corners, where retaining walls hold up the
#    street-level corner yards. The lap passes the north-east yard in a cutting and jumps off the
#    south-east one.
#
# 4. The jumps are measured twice. _verify_jumps() here flies a ballistic cart (39.8 m/s^2:
#    PlayerCart.GRAVITY plus the engine's 9.8) off every lip and push_errors when one at racing
#    speed lands short; it is a lower bound, since a real cart leaves the lip steeper and keeps
#    driving itself back up to its top speed in the air, so it flies 30-45% further.
#    scratch/nyota_jump_test.tscn drives a real PlayerCart over every jump (TrackPath's
#    "jump_lips" meta) and is what the landing lengths are tuned to: at 40 m/s, the speed carts
#    carry in the lanes, every landing is on its landing face.
extends Node

const LEVEL_NAME := "NyotaStadiumLevel"
const LEVEL_PATH := "res://levels/NyotaStadiumLevel.tscn"
const RES_PREFIX := "nyota_"
const MeshChunker = preload("res://MeshChunker.gd")
const PropKit = preload("res://PropKit.gd")
const MatatuKit = preload("res://MatatuKit.gd")
const StreetLampKit = preload("res://StreetLampKit.gd")
const FoodTruckKit = preload("res://FoodTruckKit.gd")
const MarketStallKit = preload("res://MarketStallKit.gd")
const CrowdKit = preload("res://CrowdKit.gd")
const MESH_CHUNK_CELL := 80.0

## The cart: PlayerCart.GRAVITY plus the engine's 9.8, its fall speed cap, sphere centre over the
## ground.
const G := 39.8
const VCAP := 48.0
const RIDE := 0.45

## Arena floor (off-road) and the flat lanes on it; street level outside the bowl.
const FLOOR_Y := -0.15
const TRACK_Y := 0.0
const STREET_Y := 7.0
## The road surface outside sits this far over the paving.
const STREET_ROAD_LIFT := 0.06

## The sunken floor: |x| <= ARENA_X, |z| <= ARENA_Z.
const ARENA_X := 160.0
const ARENA_Z := 76.0
## The long stands (north and south) run |x| <= SIDE_STAND_X; the end stands |z| <= END_STAND_Z.
const SIDE_STAND_X := 110.0
const END_STAND_Z := 28.0

const STEP := 0.5
## Half widths: dirt lanes, hairpins, streets.
const LANE_HALF := 6.5
const HAIRPIN_HALF := 8.0
const STREET_HALF := 7.0
## Shoulder: run per metre of drop, down from the track edge to the floor.
const SHOULDER_RUN := 1.3
## Berm: how high the outside edge of a hairpin stands, and the run per metre of drop down its
## back (gentle: PlayerCart treats off-road slopes past ~35 degrees as cliffs it cannot climb).
const BERM_H := 2.3
const BERM_BACK_RUN := 3.2

## The lap as turtle moves from PLAN_START heading PLAN_HEADING (x east, z south): ["S", length],
## or ["R"/"L", radius, degrees].
const PLAN_START := Vector2(100.0, 48.0)
const PLAN_HEADING := PI
const PLAN := [
	["S", 220.0],          # 0  start/finish straight, west
	["R", 16.0, 180.0],    # 1  T1, west hairpin
	["S", 240.0],          # 2  lane 2, east
	["L", 16.0, 180.0],    # 3  T2, east hairpin
	["S", 240.0],          # 4  lane 3, west
	["R", 16.0, 180.0],    # 5  T3, west hairpin
	["S", 400.0],          # 6  lane 4, east, and out up the ramp
	["R", 40.0, 90.0],     # 7
	["S", 158.0],          # 8  Mto Avenue, south
	["R", 40.0, 90.0],     # 9
	["S", 20.0],           # 10
	["R", 30.0, 90.0],     # 11
	["S", 82.0],           # 12 Soko Street, north
	["L", 30.0, 90.0],     # 13
	["S", 100.0],          # 14 the Drop-In: run-up, lip, landing hill
]
const SEG_L1 := 0
const SEG_L2 := 2
const SEG_L3 := 4
const SEG_L4 := 6
const SEG_AVENUE := 8
const SEG_SOKO := 12
const SEG_DROP := 14

## The exit ramp climbs from the floor at EXIT_FROM_X to street level at EXIT_TO_X.
const EXIT_FROM_X := 122.0
const EXIT_TO_X := 236.0
## The Drop-In: kicker lip, the retaining wall it clears, the landing hill down to the floor.
const DROP_LIP_X := 166.0
const DROP_KICK_LEN := 8.0
const DROP_KICK_H := 0.75
const DROP_HILL_TOP_X := ARENA_X
const DROP_HILL_TOP_Y := 6.2
const DROP_HILL_END_X := 116.0

const FINISH_S := 30.0

var _segs: Array = []
var _lap_len := 0.0
## Height profile pieces: [s0, s1, kind, h0, h1, n] sorted by s0.
var _pieces: Array = []
## Spans of s with no surface (the Drop-In gap).
var _voids: Array = []
## Take-off lips for _verify_jumps: {name, s, must}.
var _lips: Array = []
var _named_s := {}

var _st_pos := PackedVector3Array()
var _st_s := PackedFloat32Array()
var main_curve: Curve3D


# ======================================================================================
#  Plan
# ======================================================================================

func _right_of(th: float) -> Vector2:
	return Vector2(-sin(th), cos(th))


func _dir_of(th: float) -> Vector2:
	return Vector2(cos(th), sin(th))


## Walks PLAN once, recording each segment's start state and arc length.
func _build_plan() -> void:
	_segs.clear()
	var p := PLAN_START
	var th := PLAN_HEADING
	var s := 0.0
	for m in PLAN:
		var seg := {"kind": m[0], "s0": s, "p0": p, "th0": th}
		if m[0] == "S":
			var length: float = m[1]
			seg["len"] = length
			p += _dir_of(th) * length
		else:
			var r: float = m[1]
			var sign: float = 1.0 if m[0] == "R" else -1.0
			var ang: float = deg_to_rad(float(m[2]))
			seg["len"] = r * ang
			seg["r"] = r
			seg["sign"] = sign
			var c: Vector2 = p + _right_of(th) * r * sign
			th += sign * ang
			p = c - _right_of(th) * r * sign
		s += float(seg["len"])
		_segs.append(seg)
	_lap_len = s
	var gap: float = p.distance_to(PLAN_START)
	var turn: float = absf(wrapf(th - PLAN_HEADING, -PI, PI))
	if gap > 0.01 or turn > 0.001:
		push_error("The plan does not close: ends %.2fm and %.2f deg from its start" % [gap, rad_to_deg(turn)])
	print("  lap %.0fm in %d segments" % [_lap_len, _segs.size()])


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


## Arc length where segment `seg` (a straight) passes `x` (or z, for the north-south streets).
func _s_at_x(seg: int, x: float) -> float:
	var sg: Dictionary = _segs[seg]
	var p0: Vector2 = sg["p0"]
	var dir: Vector2 = _dir_of(float(sg["th0"]))
	return float(sg["s0"]) + (x - p0.x) / dir.x


func _s_at_z(seg: int, z: float) -> float:
	var sg: Dictionary = _segs[seg]
	var p0: Vector2 = sg["p0"]
	var dir: Vector2 = _dir_of(float(sg["th0"]))
	return float(sg["s0"]) + (z - p0.y) / dir.y


func _seg_mid(seg: int) -> float:
	return float(_segs[seg]["s0"]) + float(_segs[seg]["len"]) * 0.5


# ======================================================================================
#  Height profile
# ======================================================================================

## Appends a run of pieces starting at s0 from height h0: each step is [length, kind, end height]
## (whoops: [length, "whoops", base height, count, bump height]). Returns the s where it ends.
func _add_run(s0: float, h0: float, steps: Array) -> float:
	var s := s0
	var h := h0
	for st in steps:
		var length: float = st[0]
		var kind: String = st[1]
		var h1: float = st[2]
		var n: float = float(st[3]) if st.size() > 3 else 0.0
		var amp: float = float(st[4]) if st.size() > 4 else 0.0
		_pieces.append([s, s + length, kind, h, h1, n, amp])
		s += length
		h = h1
	return s


## Length of a take-off face `height` tall leaving its lip at `deg` (the face is a parabola,
## flat at its foot).
func _face_len(height: float, deg: float) -> float:
	return 2.0 * height / tan(deg_to_rad(deg))


func _face(height: float, deg: float) -> Array:
	return [_face_len(height, deg), "up", height]


## A double: take-off face to `lip_h` at `deg`, its back down to the floor, the floor, and a
## landing mound whose crest stands `gap` metres past the lip at `land_h`, with a `land_len`
## landing face. `must`: the speed that has to clear the gap.
func _add_double(s0: float, jump_name: String, lip_h: float, deg: float, gap: float, land_h: float,
		land_len: float, must: float) -> void:
	var lip: float = _add_run(s0, TRACK_Y, [_face(lip_h, deg)])
	var back := 4.0
	var rise := 7.0
	var flat: float = gap - back - rise
	if flat < 0.5:
		push_error("%s: the gap is too short for its faces" % jump_name)
	_add_run(lip, lip_h, [[back, "drop", TRACK_Y], [flat, "flat", TRACK_Y], [rise, "ease", land_h], [land_len, "land", TRACK_Y]])
	_lips.append({"name": jump_name, "s": lip, "must": must, "land_from": lip + gap})


func _plan_profile() -> void:
	_pieces.clear()
	_voids.clear()
	_lips.clear()

	# --- Start/finish straight (west). s = 100 - x. ---
	# Grandstand Table: a tabletop in front of the main stand.
	var s: float = _s_at_x(SEG_L1, 46.0)
	var e: float = _add_run(s, TRACK_Y, [_face(2.2, 17.0), [18.0, "flat", 2.2], [14.0, "land", TRACK_Y]])
	_lips.append({"name": "GrandstandTable", "s": s + _face_len(2.2, 17.0), "must": 30.0})
	_named_s["grandstand_table"] = s
	# Simba Double: a take-off and a landing mound with the floor between.
	s = _s_at_x(SEG_L1, -20.0)
	_add_double(s, "SimbaDouble", 2.6, 20.0, 24.0, 3.0, 26.0, 40.0)
	_named_s["simba"] = s

	# --- Lane 2 (east). Whoops, then the triple, then a roller into T2. ---
	s = _s_at_x(SEG_L2, -90.0)
	_add_run(s, TRACK_Y, [[64.0, "whoops", TRACK_Y, 8, 0.85]])
	_named_s["whoops"] = s
	# The triple: a take-off, a smaller mound under the flight, and the landing.
	s = _s_at_x(SEG_L2, -6.0)
	var lip: float = _add_run(s, TRACK_Y, [_face(3.0, 22.0)])
	_add_run(lip, 3.0, [[4.0, "drop", 0.8], [6.0, "ease", 2.0], [6.0, "ease", 0.8], [6.0, "ease", 3.0], [26.0, "land", TRACK_Y]])
	_lips.append({"name": "Triple", "s": lip, "must": 36.0, "land_from": lip + 22.0})
	_named_s["triple"] = s
	s = _s_at_x(SEG_L2, 76.0)
	_add_run(s, TRACK_Y, [[8.0, "ease", 1.3], [9.0, "ease", TRACK_Y]])

	# --- Lane 3 (west). Step-up, then a rhythm of rollers into a double. ---
	s = _s_at_x(SEG_L3, 96.0)
	lip = _add_run(s, TRACK_Y, [_face(2.0, 20.0)])
	_add_run(lip, 2.0, [[3.0, "drop", 1.0], [6.0, "ease", 3.4], [24.0, "flat", 3.4], [13.0, "land", TRACK_Y]])
	_lips.append({"name": "StepUp", "s": lip, "must": 34.0, "land_from": lip + 9.0})
	_named_s["step_up"] = s
	s = _s_at_x(SEG_L3, 22.0)
	e = _add_run(s, TRACK_Y, [[7.0, "ease", 1.4], [7.0, "ease", TRACK_Y], [7.0, "ease", 1.4], [7.0, "ease", TRACK_Y]])
	_add_double(e, "Rhythm", 2.1, 19.0, 20.0, 2.6, 22.0, 40.0)
	_named_s["rhythm"] = s

	# --- Lane 4 (east). The Kibo Double, a tabletop, then up and out. ---
	s = _s_at_x(SEG_L4, -86.0)
	_add_double(s, "KiboDouble", 3.4, 22.0, 22.0, 3.5, 24.0, 36.0)
	_named_s["kibo"] = s
	s = _s_at_x(SEG_L4, 6.0)
	_add_run(s, TRACK_Y, [_face(2.0, 16.0), [18.0, "flat", 2.0], [16.0, "land", TRACK_Y]])
	_lips.append({"name": "ExitTable", "s": s + _face_len(2.0, 16.0), "must": 28.0})
	# The ramp out of the bowl, through the north-east yard, to the street.
	s = _s_at_x(SEG_L4, EXIT_FROM_X)
	e = _s_at_x(SEG_L4, EXIT_TO_X)
	_add_run(s, TRACK_Y, [[e - s, "smoother", STREET_Y + STREET_ROAD_LIFT]])
	_named_s["exit_from"] = s
	_named_s["exit_to"] = e
	# The streets: level all the way round to the Drop-In.
	var street_end: float = _s_at_x(SEG_DROP, DROP_LIP_X + DROP_KICK_LEN)
	_add_run(e, STREET_Y + STREET_ROAD_LIFT, [[street_end - e, "flat", STREET_Y + STREET_ROAD_LIFT]])

	# --- The Drop-In ---
	var kick_s: float = street_end
	var lip_s: float = _s_at_x(SEG_DROP, DROP_LIP_X)
	_add_run(kick_s, STREET_Y + STREET_ROAD_LIFT, [[lip_s - kick_s, "up", STREET_Y + STREET_ROAD_LIFT + DROP_KICK_H]])
	var hill_s: float = _s_at_x(SEG_DROP, DROP_HILL_TOP_X)
	_voids.append([lip_s, hill_s])
	var hill_e: float = _s_at_x(SEG_DROP, DROP_HILL_END_X)
	_add_run(hill_s, DROP_HILL_TOP_Y, [[hill_e - hill_s, "smoother", TRACK_Y]])
	_lips.append({"name": "DropIn", "s": lip_s, "must": 26.0, "land_from": hill_s})
	_named_s["drop_lip"] = lip_s
	_named_s["drop_kick"] = kick_s
	_named_s["drop_hill"] = hill_s
	_named_s["drop_hill_end"] = hill_e
	# Between the void's two sides the profile carries straight across (the flight line).
	_add_run(lip_s, STREET_Y + STREET_ROAD_LIFT + DROP_KICK_H, [[hill_s - lip_s, "lin", DROP_HILL_TOP_Y]])

	_pieces.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for i in range(_pieces.size() - 1):
		if float(_pieces[i][1]) > float(_pieces[i + 1][0]) + 0.01:
			push_error("Profile pieces overlap at s=%.1f" % float(_pieces[i + 1][0]))


func _piece_h(pc: Array, s: float) -> float:
	var s0: float = pc[0]
	var s1: float = pc[1]
	var h0: float = pc[3]
	var h1: float = pc[4]
	var u: float = clampf((s - s0) / maxf(s1 - s0, 0.001), 0.0, 1.0)
	match String(pc[2]):
		"flat":
			return h1
		"lin":
			return lerpf(h0, h1, u)
		"up":
			# Steepest at the end: a take-off face, concave up to its lip.
			return h0 + (h1 - h0) * u * u
		"drop":
			# Steepest at the start: the back of a take-off.
			return h0 + (h1 - h0) * (1.0 - (1.0 - u) * (1.0 - u))
		"ease":
			return h0 + (h1 - h0) * u * u * (3.0 - 2.0 * u)
		"smoother":
			return h0 + (h1 - h0) * u * u * u * (u * (u * 6.0 - 15.0) + 10.0)
		"land":
			# A landing face: steepest just over the crest, where carts at racing speed come
			# down, flattening out to the bottom.
			return h0 + (h1 - h0) * (1.0 - pow(1.0 - u, 2.5))
		"whoops":
			var n: float = pc[5]
			var amp: float = pc[6]
			return h0 + amp * 0.5 * (1.0 - cos(TAU * n * u))
	return h1


## Height of the track centreline at arc length s (berms not included).
func _h_at(s: float) -> float:
	s = fposmod(s, _lap_len)
	var lo := 0
	var hi: int = _pieces.size() - 1
	var found := -1
	while lo <= hi:
		var mid: int = (lo + hi) / 2
		if float(_pieces[mid][0]) <= s:
			found = mid
			lo = mid + 1
		else:
			hi = mid - 1
	if found >= 0 and s <= float(_pieces[found][1]):
		return _piece_h(_pieces[found], s)
	return TRACK_Y


func _in_void(s: float) -> bool:
	s = fposmod(s, _lap_len)
	for v in _voids:
		if s > float(v[0]) and s < float(v[1]):
			return true
	return false


## 0 dirt, 1 tarmac. Dirt in the bowl, tarmac from the top of the cutting round to the kicker.
func _surface_at(s: float) -> float:
	s = fposmod(s, _lap_len)
	var a: float = _named_s["exit_from"] + 36.0
	var b: float = _named_s["drop_lip"]
	if s < a - 14.0 or s > b:
		return 0.0
	if s < a:
		return smoothstep(a - 14.0, a, s)
	return 1.0


## Half width along the lap: wider through the hairpins, tarmac width outside.
func _half_at(s: float) -> float:
	s = fposmod(s, _lap_len)
	var w: float = LANE_HALF
	for i in [1, 3, 5]:
		var s0: float = _segs[i]["s0"]
		var s1: float = s0 + float(_segs[i]["len"])
		var t: float = minf(smoothstep(s0 - 18.0, s0 + 4.0, s), 1.0 - smoothstep(s1 - 4.0, s1 + 18.0, s))
		w = maxf(w, lerpf(LANE_HALF, HAIRPIN_HALF, t))
	var out: float = _surface_at(s)
	w = lerpf(w, STREET_HALF, out)
	# The Drop-In run-up and landing hill: wide, so the field can spread out.
	var d0: float = _named_s["drop_kick"] - 30.0
	var d1: float = _named_s["drop_hill_end"] + 20.0
	if s > d0 and s < d1:
		w = maxf(w, lerpf(w, 8.0, minf(smoothstep(d0, d0 + 20.0, s), 1.0 - smoothstep(d1 - 20.0, d1, s))))
	return w


## Berm weight 0..1 across the hairpins, and which side is the outside (+1 right, -1 left).
func _berm_at(s: float) -> Vector2:
	for i in [1, 3, 5]:
		var sg: Dictionary = _segs[i]
		var s0: float = sg["s0"]
		var s1: float = s0 + float(sg["len"])
		var t: float = minf(smoothstep(s0 - 10.0, s0 + 10.0, s), 1.0 - smoothstep(s1 - 10.0, s1 + 10.0, s))
		if t > 0.0:
			# Outside of a right turn is on the left.
			return Vector2(t, -float(sg["sign"]))
	return Vector2.ZERO


## Lift of the surface `lat` metres right of the centreline: the berm's bowl, rising toward the
## outside edge.
func _berm_lift(s: float, lat: float, half: float) -> float:
	var b: Vector2 = _berm_at(s)
	if b.x <= 0.0:
		return 0.0
	var o: float = clampf((lat * b.y + half) / (2.0 * half), 0.0, 1.0)
	var q: float = clampf((o - 0.2) / 0.8, 0.0, 1.0)
	return BERM_H * b.x * q * q


## Ground level the shoulders run down to: the arena floor in the bowl, the paving outside,
## the cutting's gutter in the cutting.
func _shoulder_floor(s: float, p: Vector2) -> float:
	if absf(p.x) <= ARENA_X + 0.01 and absf(p.y) <= ARENA_Z + 0.01:
		return FLOOR_Y
	var exit_from: float = _named_s["exit_from"]
	var exit_to: float = _named_s["exit_to"]
	if s > exit_from and s < exit_to:
		return _h_at(s) - 0.12
	return STREET_Y - 0.04


# ======================================================================================
#  Self-checks
# ======================================================================================

## Flies a cart off every lip at a range of speeds against the built profile.
func _verify_jumps() -> void:
	for lip in _lips:
		var line := ""
		var s_lip: float = lip["s"]
		var h_lip: float = _h_at(s_lip)
		var slope: float = (_h_at(s_lip) - _h_at(s_lip - 0.5)) / 0.5
		var th: float = atan(slope)
		for v in [24.0, 28.0, 32.0, 36.0, 40.0, 44.0, 50.0]:
			var x := 0.0
			var y: float = h_lip + RIDE
			var vx: float = v * cos(th)
			var vy: float = v * sin(th)
			var dt := 1.0 / 240.0
			var t := 0.0
			var result := ""
			while t < 6.0:
				vy = maxf(vy - G * dt, -VCAP)
				x += vx * dt
				y += vy * dt
				t += dt
				var sx: float = s_lip + x
				if _in_void(sx):
					continue
				var gy: float = _h_at(sx)
				if y - RIDE <= gy:
					var gs: float = (_h_at(sx + 0.25) - _h_at(sx - 0.25)) / 0.5
					var impact: float = sqrt(vx * vx + vy * vy) * sin(absf(atan2(vy, vx) - atan(gs)))
					result = "%.0fm/%.0f" % [x, impact]
					if lip.has("land_from") and v >= float(lip["must"]) and sx < float(lip["land_from"]):
						push_error("%s: a cart at %d m/s comes down %.1fm out, short of the landing" % [lip["name"], int(v), x])
						result += "!"
					break
			line += "  %d:%s" % [int(v), result]
		print("  jump %s (lip %.1fm, %.0f deg):%s" % [lip["name"], h_lip, rad_to_deg(th), line])


func _verify_layout() -> void:
	# Lanes must clear each other's shoulders: sample the centreline against every other part of
	# the lap more than 60m away along it.
	var worst := INF
	var worst_s := 0.0
	var s := 0.0
	while s < _lap_len:
		var a: Vector2 = _plan_at(s)["p"]
		var s2 := 0.0
		while s2 < _lap_len:
			var ds: float = absf(s2 - s)
			ds = minf(ds, _lap_len - ds)
			if ds > 60.0:
				var b: Vector2 = _plan_at(s2)["p"]
				var d: float = a.distance_to(b)
				if d < worst:
					worst = d
					worst_s = s
			s2 += 4.0
		s += 4.0
	print("  closest approach of two parts of the lap: %.1fm (at s=%.0f)" % [worst, worst_s])
	if worst < 2.0 * HAIRPIN_HALF + 6.0:
		push_error("Two parts of the lap pass %.1fm apart" % worst)


# ======================================================================================
#  Mesh helpers
# ======================================================================================

## Appends triangle a-b-c to `faces`, ordered so its front face looks along `out_hint`. Godot
## front faces wind clockwise, with face normal (c - a) x (b - a) (CLAUDE.md, "Procedural mesh
## winding").
func _tri_out(faces: Array, a: Vector3, b: Vector3, c: Vector3, out_hint: Vector3) -> void:
	if (c - a).cross(b - a).dot(out_hint) < 0.0:
		faces.append_array([a, c, b])
	else:
		faces.append_array([a, b, c])


func _quad_out(faces: Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, out_hint: Vector3) -> void:
	_tri_out(faces, a, b, c, out_hint)
	_tri_out(faces, a, c, d, out_hint)


func _transform_buffer(transforms: Array, colors: Array = []) -> PackedFloat32Array:
	var stride: int = 16 if not colors.is_empty() else 12
	var buf := PackedFloat32Array()
	buf.resize(transforms.size() * stride)
	for i in range(transforms.size()):
		var t: Transform3D = transforms[i]
		var b: Basis = t.basis
		var o: int = i * stride
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
		if not colors.is_empty():
			var c: Color = colors[i]
			buf[o + 12] = c.r
			buf[o + 13] = c.g
			buf[o + 14] = c.b
			buf[o + 15] = c.a
	return buf


## A MultiMeshInstance3D; `colors` (one per transform) go to the instance colour.
func _multimesh(mesh: Mesh, transforms: Array, node_name: String, colors: Array = []) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	# The dummy renderer drops set_instance_transform(); write the buffer itself (CLAUDE.md).
	mm.buffer = _transform_buffer(transforms, colors)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	return mmi


func _vertex_color_material(rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = rough
	return m


## Collects coloured, UV'd quads and triangles; commit() returns an indexed, smooth-shaded mesh
## (or flat, when `flat`).
class Builder:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	## A second UV set, one per vertex like the first; commit() writes it only if tri2() was used.
	var uv2s := PackedVector2Array()
	var has_uv2 := false

	func tri(a: Vector3, b: Vector3, c: Vector3, out_hint: Vector3, col: Color, ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO) -> void:
		if (c - a).cross(b - a).dot(out_hint) < 0.0:
			verts.append_array([a, c, b])
			uvs.append_array([ua, uc, ub])
		else:
			verts.append_array([a, b, c])
			uvs.append_array([ua, ub, uc])
		cols.append_array([col, col, col])
		uv2s.append_array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])

	## tri() with a second UV set (va, vb, vc).
	func tri2(a: Vector3, b: Vector3, c: Vector3, out_hint: Vector3, col: Color, ua: Vector2, ub: Vector2, uc: Vector2, va: Vector2, vb: Vector2, vc: Vector2) -> void:
		var n0: int = verts.size()
		tri(a, b, c, out_hint, col, ua, ub, uc)
		has_uv2 = true
		if (c - a).cross(b - a).dot(out_hint) < 0.0:
			uv2s[n0] = va
			uv2s[n0 + 1] = vc
			uv2s[n0 + 2] = vb
		else:
			uv2s[n0] = va
			uv2s[n0 + 1] = vb
			uv2s[n0 + 2] = vc

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, out_hint: Vector3, col: Color, uv_scale := 0.25) -> void:
		var n: Vector3 = out_hint.normalized()
		var ua: Vector2 = _uv(a, n, uv_scale)
		var ub: Vector2 = _uv(b, n, uv_scale)
		var uc: Vector2 = _uv(c, n, uv_scale)
		var ud: Vector2 = _uv(d, n, uv_scale)
		tri(a, b, c, out_hint, col, ua, ub, uc)
		tri(a, c, d, out_hint, col, ua, uc, ud)

	## A box from its centre, size and yaw, faces out.
	func box(centre: Vector3, size: Vector3, yaw: float, col: Color, uv_scale := 0.25, bottom := false) -> void:
		var bs := Basis(Vector3.UP, yaw)
		var h: Vector3 = size * 0.5
		var c := []
		for k in range(8):
			var o := Vector3(h.x if k & 1 else -h.x, h.y if k & 2 else -h.y, h.z if k & 4 else -h.z)
			c.append(centre + bs * o)
		quad(c[2], c[3], c[7], c[6], Vector3.UP, col, uv_scale)
		if bottom:
			quad(c[0], c[1], c[5], c[4], Vector3.DOWN, col, uv_scale)
		quad(c[0], c[2], c[6], c[4], bs * Vector3.LEFT, col, uv_scale)
		quad(c[1], c[3], c[7], c[5], bs * Vector3.RIGHT, col, uv_scale)
		quad(c[0], c[1], c[3], c[2], bs * Vector3.FORWARD, col, uv_scale)
		quad(c[4], c[5], c[7], c[6], bs * Vector3.BACK, col, uv_scale)

	static func _uv(p: Vector3, n: Vector3, sc: float) -> Vector2:
		var an := Vector3(absf(n.x), absf(n.y), absf(n.z))
		if an.y >= an.x and an.y >= an.z:
			return Vector2(p.x, p.z) * sc
		if an.x >= an.z:
			return Vector2(p.z, -p.y) * sc
		return Vector2(p.x, -p.y) * sc

	func is_empty() -> bool:
		return verts.is_empty()

	func commit(flat := true) -> ArrayMesh:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(verts.size()):
			st.set_color(cols[i])
			st.set_uv(uvs[i])
			if has_uv2:
				st.set_uv2(uv2s[i])
			if flat:
				var t: int = i - i % 3
				var nrm: Vector3 = (verts[t + 2] - verts[t]).cross(verts[t + 1] - verts[t]).normalized()
				st.set_normal(nrm)
			st.add_vertex(verts[i])
		if not flat:
			st.index()
			st.generate_normals()
		else:
			st.index()
		st.generate_tangents()
		return st.commit()

	func faces() -> PackedVector3Array:
		return verts


# ======================================================================================
#  Track ribbon
# ======================================================================================

## Lateral stations across the top of the ribbon, as fractions of the half width.
const TOP_FRACS := [-1.0, -0.8, -0.6, -0.4, -0.2, 0.0, 0.2, 0.4, 0.6, 0.8, 1.0]

## One cross-section: [Vector3 points], [u lateral metres], [colour], and per-point whether it is
## shoulder.
func _section(s: float) -> Dictionary:
	var pa: Dictionary = _plan_at(s)
	var p2: Vector2 = pa["p"]
	var th: float = pa["th"]
	var right2: Vector2 = _right_of(th)
	var right := Vector3(right2.x, 0.0, right2.y)
	var centre := Vector3(p2.x, 0.0, p2.y)
	var half: float = _half_at(s)
	var h: float = _h_at(s)
	var surf: float = _surface_at(s)
	var berm: float = _berm_at(s).x
	var floor_y: float = _shoulder_floor(s, p2)
	var steel: float = 1.0 if s > float(_named_s["drop_kick"]) - 0.01 and s <= float(_named_s["drop_lip"]) + 0.01 else 0.0
	var pts: Array = []
	var us: Array = []
	var cs: Array = []
	# Top: lateral fractions, with the berm lift.
	var top_pts: Array = []
	for f in TOP_FRACS:
		var lat: float = float(f) * half
		var y: float = h + _berm_lift(s, lat, half)
		top_pts.append(centre + right * lat + Vector3(0, y, 0))
	# Shoulders: from each edge down to the floor, rounded with a mid point.
	var berm_side: Vector2 = _berm_at(s)
	for side in [-1.0, 1.0]:
		var edge: Vector3 = top_pts[0] if side < 0.0 else top_pts[top_pts.size() - 1]
		var drop: float = maxf(edge.y - floor_y, 0.0)
		var run: float = maxf(drop * SHOULDER_RUN, 0.35)
		# The back of a berm is gentle, so a cart that goes over the top can drive back.
		if berm_side.x > 0.0 and side == berm_side.y:
			run = maxf(drop * lerpf(SHOULDER_RUN, BERM_BACK_RUN, berm_side.x), 0.35)
		if surf > 0.5:
			run = 0.5
		var foot: Vector3 = edge + right * side * run
		foot.y = floor_y - 0.06
		var mid: Vector3 = edge + right * side * (run * 0.45)
		mid.y = lerpf(edge.y, foot.y, 0.62)
		if side < 0.0:
			pts.append_array([foot, mid])
			us.append_array([-half - run, -half - run * 0.45])
		else:
			for k in range(top_pts.size()):
				pts.append(top_pts[k])
				us.append(float(TOP_FRACS[k]) * half)
			pts.append_array([mid, foot])
			us.append_array([half + run * 0.45, half + run])
	for k in range(pts.size()):
		var shoulder: float = 1.0 if k < 2 or k >= pts.size() - 2 else 0.0
		cs.append(Color(surf, steel, shoulder, berm))
	return {"pts": pts, "us": us, "cols": cs, "right": right}


## Builds the ribbon mesh and its two collision bodies (dirt and tarmac).
func _build_track(parent: Node, mat: Material) -> void:
	var n: int = int(round(_lap_len / STEP))
	var step: float = _lap_len / float(n)
	var sections: Array = []
	for i in range(n):
		var s: float = float(i) * step
		if _in_void(s):
			sections.append(null)
		else:
			sections.append(_section(s))
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var dirt_faces := PackedVector3Array()
	var street_faces := PackedVector3Array()
	var base := []
	base.resize(n)
	for i in range(n):
		var sec = sections[i]
		if sec == null:
			base[i] = -1
			continue
		base[i] = verts.size()
		var s: float = float(i) * step
		for k in range(sec["pts"].size()):
			verts.append(sec["pts"][k])
			uvs.append(Vector2(sec["us"][k], s))
			cols.append(sec["cols"][k])
	var w: int = TOP_FRACS.size() + 4
	for i in range(n):
		var j: int = (i + 1) % n
		if base[i] < 0 or base[j] < 0:
			continue
		var a0: int = base[i]
		var b0: int = base[j]
		var surf: float = cols[a0 + w / 2].r
		for k in range(w - 1):
			# Wound so the faces look up (CLAUDE.md: clockwise front faces).
			var a: int = a0 + k
			var b: int = a0 + k + 1
			var c: int = b0 + k + 1
			var d: int = b0 + k
			var t1 := [a, b, c]
			var t2 := [a, c, d]
			for t in [t1, t2]:
				var pa: Vector3 = verts[t[0]]
				var pb: Vector3 = verts[t[1]]
				var pc: Vector3 = verts[t[2]]
				if (pc - pa).cross(pb - pa).y < 0.0:
					t = [t[0], t[2], t[1]]
					pb = verts[t[1]]
					pc = verts[t[2]]
				idx.append_array(t)
				if surf > 0.5:
					street_faces.append_array([pa, pb, pc])
				else:
					dirt_faces.append_array([pa, pb, pc])
	# End caps where the surface stops at a void: a face from the section down to the ground.
	for i in range(n):
		var j: int = (i + 1) % n
		var prev: int = (i - 1 + n) % n
		var cap_dir := 0.0
		if base[i] >= 0 and base[j] < 0:
			cap_dir = 1.0
		elif base[i] >= 0 and base[prev] < 0:
			cap_dir = -1.0
		if cap_dir == 0.0:
			continue
		var sec: Dictionary = sections[i]
		var fwd2: Vector2 = _dir_of(float(_plan_at(float(i) * step)["th"]))
		var fwd := Vector3(fwd2.x, 0.0, fwd2.y) * cap_dir
		var bottom_y: float = STREET_Y - 0.02 if cap_dir > 0.0 else FLOOR_Y - 0.1
		var pts: Array = sec["pts"]
		for k in range(pts.size() - 1):
			var p0: Vector3 = pts[k]
			var p1: Vector3 = pts[k + 1]
			var q0 := Vector3(p0.x, minf(bottom_y, p0.y), p0.z)
			var q1 := Vector3(p1.x, minf(bottom_y, p1.y), p1.z)
			if p0.y - q0.y < 0.01 and p1.y - q1.y < 0.01:
				continue
			var vi: int = verts.size()
			for q in [p0, p1, q1, q0]:
				verts.append(q)
				uvs.append(Vector2(q.x + q.z, q.y))
				cols.append(Color(cols[base[i]].r, 1.0 if cap_dir > 0.0 else 0.0, 1.0, 0.0))
			var face := [vi, vi + 1, vi + 2, vi, vi + 2, vi + 3]
			for t in range(0, 6, 3):
				var ta: Vector3 = verts[face[t]]
				var tb: Vector3 = verts[face[t + 1]]
				var tc: Vector3 = verts[face[t + 2]]
				if (tc - ta).cross(tb - ta).dot(fwd) < 0.0:
					idx.append_array([face[t], face[t + 2], face[t + 1]])
				else:
					idx.append_array([face[t], face[t + 1], face[t + 2]])
				if cap_dir > 0.0:
					street_faces.append_array([ta, tb, tc])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var st := SurfaceTool.new()
	st.create_from_arrays(arrays)
	st.generate_normals()
	st.generate_tangents()
	var mesh: ArrayMesh = st.commit()
	mesh = _save_baked_resource(mesh, "track_visual")
	var mi := MeshInstance3D.new()
	mi.name = "TrackSurface"
	mi.mesh = mesh
	mi.material_override = mat
	parent.add_child(mi)
	for spec in [["StadiumTrack", dirt_faces], ["StreetTrack", street_faces]]:
		var body := StaticBody3D.new()
		body.name = spec[0]
		var cs := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(spec[1])
		shape.backface_collision = true
		cs.shape = _save_baked_resource(shape, String(spec[0]).to_lower() + "_collision")
		body.add_child(cs)
		parent.add_child(body)
	print("  track ribbon: %d vertices, %d triangles" % [verts.size(), idx.size() / 3])
	_st_pos.clear()
	_st_s.clear()


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
		pts.append(Vector3(p2.x, _h_at(s) + _berm_lift(s, 0.0, _half_at(s)), p2.y))
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
	var half: float = _half_at(s)
	var pos := Vector3(p2.x + r2.x * lat, _h_at(s) + _berm_lift(s, lat, half) + lift, p2.y + r2.y * lat)
	var fwd := Vector3(f2.x, 0.0, f2.y)
	return {"pos": pos, "yaw": rad_to_deg(atan2(-fwd.x, -fwd.z)), "fwd": fwd, "right": Vector3(r2.x, 0.0, r2.y)}


# ======================================================================================
#  Arena floor and walls
# ======================================================================================

## Stand front wall height over the floor, and the catch net above it.
const WALL_TOP := 2.4
## The stand fronts' wall as (centre, thickness) from the arena edge outward: its face stands 3cm proud
## of the stand shell's front. The board frames and the boards in front of it keep 4cm gaps (FRAME_D, BOARD_D).
const WALL_FACE_OFFSET := Vector2(0.28, 0.62)
const FRAME_D := 0.05
const BOARD_D := 0.11
const NET_H := 3.2
## The corner retaining walls' parapet over street level.
const PARAPET := 1.15
## Invisible part of the stand fronts' collision, over the net.
const WALL_STOP_H := 16.0

## The sunken floor: one plane, off-road.
func _build_arena_floor(parent: Node, mat: Material) -> void:
	var b := Builder.new()
	var cell := 16.0
	var nx: int = int(ceil(2.0 * ARENA_X / cell))
	var nz: int = int(ceil(2.0 * ARENA_Z / cell))
	for i in range(nx):
		for j in range(nz):
			var x0: float = -ARENA_X + 2.0 * ARENA_X * float(i) / float(nx)
			var x1: float = -ARENA_X + 2.0 * ARENA_X * float(i + 1) / float(nx)
			var z0: float = -ARENA_Z + 2.0 * ARENA_Z * float(j) / float(nz)
			var z1: float = -ARENA_Z + 2.0 * ARENA_Z * float(j + 1) / float(nz)
			b.quad(Vector3(x0, FLOOR_Y, z0), Vector3(x1, FLOOR_Y, z0), Vector3(x1, FLOOR_Y, z1), Vector3(x0, FLOOR_Y, z1), Vector3.UP, Color(0, 0, 0, 0), 1.0)
	var mi := MeshInstance3D.new()
	mi.name = "ArenaFloor"
	mi.mesh = b.commit()
	mi.material_override = mat
	parent.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "ArenaInfield"
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0 * ARENA_X + 2.0, 2.0, 2.0 * ARENA_Z + 2.0)
	cs.shape = box
	cs.position = Vector3(0, FLOOR_Y - 1.0, 0)
	body.add_child(cs)
	parent.add_child(body)


## A thin wall from a to b (XZ), bottom to top, `thick` metres thick, its face toward `face`.
func _wall(b: Builder, a: Vector2, c: Vector2, y0: float, y1: float, thick: float, col: Color) -> void:
	var dir: Vector2 = (c - a).normalized()
	var n2 := Vector2(-dir.y, dir.x)
	var len: float = a.distance_to(c)
	var mid: Vector2 = (a + c) * 0.5
	b.box(Vector3(mid.x, (y0 + y1) * 0.5, mid.y), Vector3(len, y1 - y0, thick), -atan2(dir.y, dir.x), col)


func _box_body(parent: Node, body_name: String, centre: Vector3, size: Vector3, yaw: float) -> void:
	var body := StaticBody3D.new()
	body.name = body_name
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.add_child(cs)
	body.transform = Transform3D(Basis(Vector3.UP, yaw), centre)
	parent.add_child(body)


## Stand front walls (with the catch net over them) and the corner retaining walls, with the gap
## the exit ramp passes through and the Drop-In's corridor in the south-east parapet.
func _build_walls(parent: Node, concrete: Material, net_mat: Material) -> void:
	var b := Builder.new()
	var net := Builder.new()
	var wall_col := Color(0.78, 0.77, 0.74)
	var cap_col := Color(0.62, 0.62, 0.60)
	var root := Node3D.new()
	root.name = "ArenaWalls"
	parent.add_child(root)
	# Stand fronts: [from, to] along the arena edge.
	var fronts := [
		[Vector2(-SIDE_STAND_X, ARENA_Z), Vector2(SIDE_STAND_X, ARENA_Z)],
		[Vector2(-SIDE_STAND_X, -ARENA_Z), Vector2(SIDE_STAND_X, -ARENA_Z)],
		[Vector2(ARENA_X, -END_STAND_Z), Vector2(ARENA_X, END_STAND_Z)],
		[Vector2(-ARENA_X, -END_STAND_Z), Vector2(-ARENA_X, END_STAND_Z)],
	]
	for f in fronts:
		var a: Vector2 = f[0]
		var c: Vector2 = f[1]
		var out2: Vector2 = Vector2(signf(a.x) if absf(a.x) == ARENA_X else 0.0, signf(a.y) if absf(a.y) == ARENA_Z else 0.0)
		# The stand's own shell has its front face on the arena edge (d = 0), so the wall's stands 3cm in
		# front of it: two coplanar faces z-fight, which showed on the wall the sun isn't lighting.
		var a2: Vector2 = a + out2 * WALL_FACE_OFFSET.x
		var c2: Vector2 = c + out2 * WALL_FACE_OFFSET.x
		_wall(b, a2, c2, FLOOR_Y - 0.2, WALL_TOP, WALL_FACE_OFFSET.y, wall_col)
		_wall(b, a2 - out2 * 0.05, c2 - out2 * 0.05, WALL_TOP, WALL_TOP + 0.12, 0.8, cap_col)
		# Catch net: posts and a mesh panel over the wall.
		var len: float = a.distance_to(c)
		var dir: Vector2 = (c - a) / len
		var posts: int = int(len / 6.0)
		for k in range(posts + 1):
			var q: Vector2 = a2.lerp(c2, float(k) / float(posts))
			b.box(Vector3(q.x, WALL_TOP + NET_H * 0.5, q.y), Vector3(0.14, NET_H, 0.14), 0.0, Color(0.25, 0.26, 0.28))
		var p0 := Vector3(a2.x, WALL_TOP + 0.1, a2.y)
		var p1 := Vector3(c2.x, WALL_TOP + 0.1, c2.y)
		net.quad(p0, p1, p1 + Vector3(0, NET_H - 0.1, 0), p0 + Vector3(0, NET_H - 0.1, 0), Vector3(-out2.x, 0, -out2.y), Color.WHITE, 1.0)
		var mid: Vector2 = (a2 + c2) * 0.5
		# Collision well above the net: a cart thrown off a jump must not clear it into the seats.
		_box_body(root, "StandFrontWall", Vector3(mid.x, (FLOOR_Y + WALL_STOP_H) * 0.5, mid.y), Vector3(len + 0.6, WALL_STOP_H - FLOOR_Y, 0.6), -atan2(dir.y, dir.x))
	# Corner retaining walls, each corner along both arena edges.
	var exit_half: float = _half_at(_s_at_x(SEG_L4, ARENA_X)) + 0.55
	var drop_corridor: float = 9.5
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var corner := Vector2(sx * ARENA_X, sz * ARENA_Z)
			# Along the long edge (z = +-ARENA_Z) from the side stand's end to the corner.
			var runs := [[Vector2(sx * SIDE_STAND_X, sz * ARENA_Z), corner], [Vector2(sx * ARENA_X, sz * END_STAND_Z), corner]]
			for r in runs:
				var a: Vector2 = r[0]
				var c: Vector2 = r[1]
				var along_x: bool = absf(a.y - c.y) < 0.01
				var out2 := Vector2(0.0, sz) if along_x else Vector2(sx, 0.0)
				# Gaps: the exit ramp (north-east, x edge) cuts the whole wall; the Drop-In only
				# leaves the parapet open.
				var wall_gaps: Array = []
				var parapet_gaps: Array = []
				if sx > 0.0 and not along_x:
					if sz < 0.0:
						wall_gaps.append(Vector2(-48.0 - exit_half, -48.0 + exit_half))
					else:
						parapet_gaps.append(Vector2(48.0 - drop_corridor, 48.0 + drop_corridor))
				for piece in _split_run(a, c, wall_gaps):
					var pa: Vector2 = piece[0] + out2 * 0.4
					var pc: Vector2 = piece[1] + out2 * 0.4
					if pa.distance_to(pc) < 0.2:
						continue
					_wall(b, pa, pc, FLOOR_Y - 0.2, STREET_Y, 0.8, wall_col)
					var pm: Vector2 = (pa + pc) * 0.5
					var pdir: Vector2 = (pc - pa).normalized()
					# The wall's collision stops at street level; the parapet has its own, so the
					# Drop-In's corridor is open to carts rolling off the lip as well as flying.
					_box_body(root, "CornerWall", Vector3(pm.x, (FLOOR_Y + STREET_Y) * 0.5, pm.y), Vector3(pa.distance_to(pc) + 0.8, STREET_Y - FLOOR_Y, 0.8), -atan2(pdir.y, pdir.x))
					for piece2 in _split_run(piece[0], piece[1], parapet_gaps):
						var qa: Vector2 = piece2[0] + out2 * 0.4
						var qc: Vector2 = piece2[1] + out2 * 0.4
						if qa.distance_to(qc) < 0.2:
							continue
						_wall(b, qa, qc, STREET_Y, STREET_Y + PARAPET, 0.35, cap_col)
						var qm: Vector2 = (qa + qc) * 0.5
						var qdir: Vector2 = (qc - qa).normalized()
						_box_body(root, "CornerParapet", Vector3(qm.x, STREET_Y + 2.0, qm.y), Vector3(qa.distance_to(qc), 4.0, 0.5), -atan2(qdir.y, qdir.x))
	var mi := MeshInstance3D.new()
	mi.name = "WallMesh"
	mi.mesh = _save_baked_resource(b.commit(), "walls")
	mi.material_override = concrete
	root.add_child(mi)
	var ni := MeshInstance3D.new()
	ni.name = "CatchNet"
	ni.mesh = net.commit()
	ni.material_override = net_mat
	ni.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ni)


## Splits the straight run a..c around gaps given as ranges of the coordinate that varies along it.
func _split_run(a: Vector2, c: Vector2, gaps: Array) -> Array:
	var along_x: bool = absf(a.y - c.y) < 0.01
	var lo: float = minf(a.x, c.x) if along_x else minf(a.y, c.y)
	var hi: float = maxf(a.x, c.x) if along_x else maxf(a.y, c.y)
	var spans: Array = [Vector2(lo, hi)]
	for g in gaps:
		var out: Array = []
		for sp in spans:
			if g.y <= sp.x or g.x >= sp.y:
				out.append(sp)
				continue
			if g.x > sp.x:
				out.append(Vector2(sp.x, g.x))
			if g.y < sp.y:
				out.append(Vector2(g.y, sp.y))
		spans = out
	var res: Array = []
	for sp in spans:
		if along_x:
			res.append([Vector2(sp.x, a.y), Vector2(sp.y, a.y)])
		else:
			res.append([Vector2(a.x, sp.x), Vector2(a.x, sp.y)])
	return res


# ======================================================================================
#  Stands
# ======================================================================================

const LOWER_ROWS := 18
const LOWER_RISE := 0.85
const ROW_DEPTH := 1.75
const FRONT_WALK := 3.0
const CONCOURSE := 4.0
const BALCONY_H := 3.4
const UPPER_ROWS := 14
const UPPER_RISE := 1.05
const UPPER_ROW_DEPTH := 1.7
## Seats per metre of row (a seat every SEAT_PITCH), and aisle spacing.
const SEAT_PITCH := 1.1
const AISLE_EVERY := 24.0
const AISLE_W := 2.6
## Roof over the long stands: front edge depth and heights.
const ROOF_FRONT_D := 24.0
const ROOF_FRONT_Y := 44.0
const ROOF_BACK_Y := 47.0

## [name, front centre, outward direction, half length, upper tier]
const STANDS := [
	["SouthStand", Vector2(0.0, ARENA_Z), Vector2(0.0, 1.0), SIDE_STAND_X, true],
	["NorthStand", Vector2(0.0, -ARENA_Z), Vector2(0.0, -1.0), SIDE_STAND_X, true],
	["EastStand", Vector2(ARENA_X, 0.0), Vector2(1.0, 0.0), END_STAND_Z, false],
	["WestStand", Vector2(-ARENA_X, 0.0), Vector2(-1.0, 0.0), END_STAND_Z, false],
]


## Seat rows of a stand as [d_front, d_back, tread_y]; and the full cross-section from the foot of
## the front wall to the foot of the back wall, as (d, y).
func _stand_section(upper: bool) -> Dictionary:
	var rows: Array = []
	var prof := PackedVector2Array()
	prof.append(Vector2(0.0, FLOOR_Y - 0.2))
	prof.append(Vector2(0.0, WALL_TOP))
	var d: float = FRONT_WALK
	var y: float = WALL_TOP
	prof.append(Vector2(d, y))
	for i in range(LOWER_ROWS):
		y += LOWER_RISE
		prof.append(Vector2(d, y))
		rows.append([d, d + ROW_DEPTH, y, 0])
		d += ROW_DEPTH
		prof.append(Vector2(d, y))
	d += CONCOURSE
	prof.append(Vector2(d, y))
	if upper:
		y += BALCONY_H
		prof.append(Vector2(d, y))
		d += 2.0
		prof.append(Vector2(d, y))
		for j in range(UPPER_ROWS):
			y += UPPER_RISE
			prof.append(Vector2(d, y))
			rows.append([d, d + UPPER_ROW_DEPTH, y, 1])
			d += UPPER_ROW_DEPTH
			prof.append(Vector2(d, y))
		d += 1.0
		prof.append(Vector2(d, y))
	y += 2.6
	prof.append(Vector2(d, y))
	d += 0.6
	prof.append(Vector2(d, y))
	prof.append(Vector2(d, STREET_Y - 0.3))
	return {"rows": rows, "profile": prof, "depth": d, "top": y}


## World position from stand coordinates: `a` along the stand, `d` back from the arena edge.
func _stand_point(st: Array, a: float, d: float, y: float) -> Vector3:
	var c: Vector2 = st[1]
	var out2: Vector2 = st[2]
	var along := Vector2(-out2.y, out2.x)
	var p: Vector2 = c + along * a + out2 * d
	return Vector3(p.x, y, p.y)


## Seat colours: blocks of orange, green and gold by section, with a scatter of odd seats.
func _seat_color(section: int, row: int, k: int, tier: int) -> Color:
	var pal := [Color(0.92, 0.42, 0.08), Color(0.10, 0.45, 0.22), Color(0.95, 0.74, 0.12)]
	var base: Color = pal[(section + tier) % 3]
	var h: int = (section * 7919 + row * 104729 + k * 1299709) % 97
	if h < 9:
		base = pal[(section + tier + 1) % 3]
	return base


func _build_stands(parent: Node, concrete: Material, seat_mat: Material) -> Array:
	var crowd_spots: Array = []
	var root := Node3D.new()
	root.name = "Stands"
	parent.add_child(root)
	for st in STANDS:
		var upper: bool = st[4]
		var half: float = st[3]
		var sec: Dictionary = _stand_section(upper)
		var prof: PackedVector2Array = sec["profile"]
		var shell := Builder.new()
		var seats := Builder.new()
		var col := Color(0.74, 0.73, 0.70)
		var out2: Vector2 = st[2]
		var out3 := Vector3(out2.x, 0.0, out2.y)
		var along3 := Vector3(-out2.y, 0.0, out2.x)
		# The extruded shell.
		for k in range(prof.size() - 1):
			var p0: Vector2 = prof[k]
			var p1: Vector2 = prof[k + 1]
			var t: Vector2 = p1 - p0
			var n2 := Vector2(-t.y, t.x).normalized()
			var hint: Vector3 = out3 * n2.x + Vector3.UP * n2.y
			var a0: Vector3 = _stand_point(st, -half, p0.x, p0.y)
			var a1: Vector3 = _stand_point(st, half, p0.x, p0.y)
			var b1: Vector3 = _stand_point(st, half, p1.x, p1.y)
			var b0: Vector3 = _stand_point(st, -half, p1.x, p1.y)
			var shade: float = 0.92 if absf(n2.y) > 0.5 else 0.8
			shell.quad(a0, a1, b1, b0, hint, Color(col.r * shade, col.g * shade, col.b * shade), 0.25)
		# End walls: the cross-section filled down to the floor.
		var poly := PackedVector2Array(prof)
		poly.append(Vector2(prof[prof.size() - 1].x, FLOOR_Y - 0.2))
		var tris: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
		for side in [-1.0, 1.0]:
			for t in range(0, tris.size(), 3):
				var q0: Vector2 = poly[tris[t]]
				var q1: Vector2 = poly[tris[t + 1]]
				var q2: Vector2 = poly[tris[t + 2]]
				shell.tri(_stand_point(st, side * half, q0.x, q0.y), _stand_point(st, side * half, q1.x, q1.y),
						_stand_point(st, side * half, q2.x, q2.y), along3 * side, col * 0.86,
						Vector2(q0.x, -q0.y) * 0.25, Vector2(q1.x, -q1.y) * 0.25, Vector2(q2.x, -q2.y) * 0.25)
		# Seat rows: a block per seat group, split by aisles.
		var rows: Array = sec["rows"]
		for r in range(rows.size()):
			var row: Array = rows[r]
			var d_back: float = row[1]
			var y: float = row[2]
			var tier: int = row[3]
			var a: float = -half + 1.2
			var k := 0
			while a < half - 1.2:
				var section: int = int(floor((a + half) / AISLE_EVERY))
				var in_aisle: bool = fposmod(a + half, AISLE_EVERY) < AISLE_W
				if not in_aisle:
					var c: Color = _seat_color(section, r, k, tier)
					var s0: Vector3 = _stand_point(st, a, d_back - 0.62, y + 0.42)
					var s1: Vector3 = _stand_point(st, a, d_back - 0.2, y + 0.95)
					seats.box(Vector3(s0.x, y + 0.42, s0.z), Vector3(0.9, 0.84, 0.9), atan2(-out2.x, -out2.y) + PI * 0.5 if absf(out2.x) > 0.5 else 0.0, c, 0.5)
					seats.box(Vector3(s1.x, y + 1.05, s1.z), Vector3(0.9, 0.9, 0.14), atan2(-out2.x, -out2.y) + PI * 0.5 if absf(out2.x) > 0.5 else 0.0, c * 0.92, 0.5)
					crowd_spots.append([_stand_point(st, a, d_back - 0.75, y), out3, r, tier])
				a += SEAT_PITCH
				k += 1
		var body := StaticBody3D.new()
		body.name = st[0] + "Seating"
		var bcs := CollisionShape3D.new()
		var bshape := ConcavePolygonShape3D.new()
		bshape.set_faces(shell.faces())
		bshape.backface_collision = true
		bcs.shape = bshape
		body.add_child(bcs)
		root.add_child(body)
		var mi := MeshInstance3D.new()
		mi.name = st[0] + "Shell"
		mi.mesh = _save_baked_resource(shell.commit(), st[0].to_lower() + "_shell")
		mi.material_override = concrete
		root.add_child(mi)
		var si := MeshInstance3D.new()
		si.name = st[0] + "Seats"
		si.mesh = _save_baked_resource(seats.commit(), st[0].to_lower() + "_seats")
		si.material_override = seat_mat
		si.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(si)
		if upper:
			_build_roof(root, st, sec, concrete)
	return crowd_spots


## Height of a long stand's roof underside (the trusses' bottom chords, _build_roof) over a point `d` back from
## the arena edge; INF where there is no roof (in front of it, or a stand without an upper tier).
func _roof_underside(d: float, tier: int) -> float:
	if tier < 1 or d < ROOF_FRONT_D + 4.0:
		return INF
	var back_d: float = float(_stand_section(true)["depth"]) + 1.5
	var t: float = clampf((d - (ROOF_FRONT_D + 4.0)) / (back_d - (ROOF_FRONT_D + 4.0)), 0.0, 1.0)
	return lerpf(ROOF_FRONT_Y - 0.6, ROOF_BACK_Y - 6.0, t)


## Cantilever roof over a long stand: back columns, a truss every 11m, the roof sheet and a fascia
## carrying a row of floodlights along the front edge.
func _build_roof(parent: Node, st: Array, sec: Dictionary, concrete: Material) -> void:
	var half: float = st[3]
	var depth: float = sec["depth"]
	var steel := Builder.new()
	var sheet := Builder.new()
	var lamps := Builder.new()
	var steel_col := Color(0.82, 0.83, 0.85)
	var back_d: float = depth + 1.5
	var n: int = int(2.0 * half / 11.0)
	for i in range(n + 1):
		var a: float = -half + 2.0 * half * float(i) / float(n)
		# Column behind the stand.
		var base: Vector3 = _stand_point(st, a, back_d, STREET_Y)
		steel.box(base + Vector3(0, (ROOF_BACK_Y - STREET_Y) * 0.5, 0), Vector3(1.0, ROOF_BACK_Y - STREET_Y, 1.0), 0.0, steel_col)
		# Truss: top and bottom chords and diagonals.
		var top0: Vector3 = _stand_point(st, a, back_d, ROOF_BACK_Y)
		var top1: Vector3 = _stand_point(st, a, ROOF_FRONT_D, ROOF_FRONT_Y)
		var bot0: Vector3 = _stand_point(st, a, back_d, ROOF_BACK_Y - 6.0)
		var bot1: Vector3 = _stand_point(st, a, ROOF_FRONT_D + 4.0, ROOF_FRONT_Y - 0.6)
		_beam(steel, top0, top1, 0.6, steel_col)
		_beam(steel, bot0, bot1, 0.45, steel_col)
		for k in range(6):
			var u0: float = float(k) / 6.0
			var u1: float = float(k + 1) / 6.0
			var tp: Vector3 = top0.lerp(top1, u1 if k % 2 == 0 else u0)
			var bp: Vector3 = bot0.lerp(bot1, u0 if k % 2 == 0 else u1)
			_beam(steel, tp, bp, 0.3, steel_col)
	# Roof sheet, a little above the top chords.
	var r0: Vector3 = _stand_point(st, -half - 1.0, ROOF_FRONT_D - 0.5, ROOF_FRONT_Y + 0.35)
	var r1: Vector3 = _stand_point(st, half + 1.0, ROOF_FRONT_D - 0.5, ROOF_FRONT_Y + 0.35)
	var r2: Vector3 = _stand_point(st, half + 1.0, back_d + 1.0, ROOF_BACK_Y + 0.35)
	var r3: Vector3 = _stand_point(st, -half - 1.0, back_d + 1.0, ROOF_BACK_Y + 0.35)
	sheet.quad(r0, r1, r2, r3, Vector3.UP, Color(0.93, 0.93, 0.92), 0.05)
	sheet.quad(r0, r1, r2, r3, Vector3.DOWN, Color(0.70, 0.71, 0.73), 0.05)
	# Fascia along the front edge, with the floodlights under it.
	var f0: Vector3 = _stand_point(st, -half - 1.0, ROOF_FRONT_D - 0.6, ROOF_FRONT_Y - 1.4)
	var f1: Vector3 = _stand_point(st, half + 1.0, ROOF_FRONT_D - 0.6, ROOF_FRONT_Y - 1.4)
	var out2: Vector2 = st[2]
	var fascia_yaw: float = 0.0 if absf(out2.y) > 0.5 else PI * 0.5
	steel.box((f0 + f1) * 0.5 + Vector3(0, 0.85, 0), Vector3(2.0 * half + 2.0, 1.9, 0.5), fascia_yaw, Color(0.20, 0.22, 0.25))
	var lamp_n: int = int(2.0 * half / 7.0)
	for i in range(lamp_n):
		var a2: float = -half + 2.0 * half * (float(i) + 0.5) / float(lamp_n)
		var lp: Vector3 = _stand_point(st, a2, ROOF_FRONT_D + 0.2, ROOF_FRONT_Y - 1.9)
		lamps.box(lp, Vector3(1.6, 0.9, 1.2), fascia_yaw, Color(1.0, 0.97, 0.88))
	var mi := MeshInstance3D.new()
	mi.name = st[0] + "RoofSteel"
	mi.mesh = _save_baked_resource(steel.commit(), st[0].to_lower() + "_roof_steel")
	mi.material_override = _metal_material()
	parent.add_child(mi)
	var sm := MeshInstance3D.new()
	sm.name = st[0] + "RoofSheet"
	sm.mesh = sheet.commit()
	sm.material_override = _vertex_color_material(0.6)
	parent.add_child(sm)
	var lm := MeshInstance3D.new()
	lm.name = st[0] + "RoofLamps"
	lm.mesh = lamps.commit()
	lm.material_override = _lamp_material()
	lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(lm)


## A square beam from a to b.
func _beam(b: Builder, a: Vector3, c: Vector3, w: float, col: Color) -> void:
	var dir: Vector3 = c - a
	var len: float = dir.length()
	if len < 0.01:
		return
	dir /= len
	var ref: Vector3 = Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	var u: Vector3 = dir.cross(ref).normalized() * (w * 0.5)
	var v: Vector3 = dir.cross(u).normalized() * (w * 0.5)
	var corners := [u + v, -u + v, -u - v, u - v]
	for k in range(4):
		var q0: Vector3 = corners[k]
		var q1: Vector3 = corners[(k + 1) % 4]
		var hint: Vector3 = (q0 + q1).normalized()
		b.quad(a + q0, a + q1, c + q1, c + q0, hint, col, 0.5)


func _metal_material() -> StandardMaterial3D:
	var m := _vertex_color_material(0.42)
	m.metallic = 0.55
	return m


func _lamp_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.98, 0.92)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.95, 0.82)
	m.emission_energy_multiplier = 2.2
	return m


func _concrete_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.albedo_texture = load("res://materials/concrete.png")
	m.normal_enabled = true
	m.normal_texture = load("res://materials/concrete_normal.png")
	m.normal_scale = 0.5
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.12, 0.12, 0.12)
	m.roughness = 0.9
	return m


# ======================================================================================
#  Crowd
# ======================================================================================

const CROWD_CELL := 60.0
## The 3D spectators are in smaller cells, so the ones too far to draw are culled with their cell.
const CROWD_NEAR_CELL := 24.0
## Only spectators this near the lap (in plan) ever get a 3D figure: the camera can't be nearer than that. It
## covers Ultra's range (CrowdDetail.gd draws the figures out to 1.3 times CROWD_LOD_END).
const CROWD_NEAR_REACH := 62.0
## The card dithers into the 3D figure between these distances (tree_lod.gdshaderinc), jittered per spectator.
const CROWD_LOD_BEGIN := 34.0
const CROWD_LOD_END := 44.0
const CROWD_LOD_JITTER := 3.0
## Height of a seat's cushion over the tread: a seated spectator's pelvis is on it, a standing one's feet.
const CROWD_SEAT_H := 0.84
## The seated cards stand this far toward the arena, so their shins hang in front of the seat's cushion
## instead of behind it.
const CROWD_CARD_FORWARD := 0.6

## Pose odds (crowd_common.gdshaderinc has the poses): seated 0-6, standing 7-15. Not everyone cheers: most sit
## and watch, clap, film, talk or fold their arms.
const POSE_SEATED := [0.34, 0.13, 0.12, 0.17, 0.08, 0.09, 0.07]
const POSE_STANDING_FANS := [0.18, 0.13, 0.22, 0.10, 0.08, 0.05, 0.08, 0.10, 0.06]
## Off the stands nobody waves a flag (pose 12): the fan zone's tents and the stalls' tarps hang over people
## there, and the flags stood up through them.
const POSE_STANDING_PLAZA := [0.26, 0.08, 0.05, 0.17, 0.12, 0.0, 0.14, 0.08, 0.08]
## A flag waver's flag reaches this far over what they stand on; under less of the roof they cheer instead.
const FLAG_HEADROOM := 6.0


## A pose id from `odds` (weights for poses first, first + 1, ...). `boost` multiplies one weight, the cheer.
func _pick_pose(rng: RandomNumberGenerator, odds: Array, first: int, boost_at := -1, boost := 1.0) -> int:
	var total := 0.0
	for i in range(odds.size()):
		total += float(odds[i]) * (boost if i == boost_at else 1.0)
	var r: float = rng.randf() * total
	for i in range(odds.size()):
		r -= float(odds[i]) * (boost if i == boost_at else 1.0)
		if r <= 0.0:
			return first + i
	return first


func _crowd_material(mode: int, card_w := 1.1, card_h := 2.75, card_below := 0.9, card_x := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://stadium_person.gdshader" if mode == 1 else "res://stadium_crowd.gdshader")
	m.set_shader_parameter("lod_mode", mode)
	m.set_shader_parameter("lod_fade_begin", CROWD_LOD_BEGIN)
	m.set_shader_parameter("lod_fade_end", CROWD_LOD_END)
	m.set_shader_parameter("lod_jitter", CROWD_LOD_JITTER)
	if mode == 2:
		m.set_shader_parameter("card_w", card_w)
		m.set_shader_parameter("card_h", card_h)
		m.set_shader_parameter("card_below", card_below)
		m.set_shader_parameter("card_x", card_x)
	return m


## The card shapes, by the pose's class: [width, height, reach below the pelvis, x of its middle, y of its middle
## in the spectator's frame]. A pixel of a card is shaded however empty it is, and the stands overlap many cards
## deep, so each is as small as its pose allows: only arms up (and a flag) need the wide ones.
##   0 seated   1 seated, arms up   2 standing   3 standing, arms up   4 standing with a flag
const CROWD_CARDS := [
	[1.1, 2.75, 0.9, 0.0, 0.475],
	[2.1, 3.15, 0.9, 0.0, 0.675],
	[1.1, 3.5, 1.65, 0.0, 1.75],
	[2.1, 3.9, 1.65, 0.0, 1.95],
	[3.0, 4.9, 1.65, -0.5, 2.45],
]


func _crowd_card_class(pose: int) -> int:
	if pose == 5:
		return 1
	if pose == 9 or pose == 14:
		return 3
	if pose == 12:
		return 4
	return 2 if pose >= 7 else 0


func _crowd_card_mesh(cls: int) -> QuadMesh:
	var c: Array = CROWD_CARDS[cls]
	var q := QuadMesh.new()
	q.size = Vector2(float(c[0]), float(c[1]))
	q.center_offset = Vector3(float(c[3]), float(c[4]), 0.0)
	q.material = _crowd_material(2, float(c[0]), float(c[1]), float(c[2]), float(c[3]))
	return q


## MultiMesh buffer with per-instance custom data (transform then INSTANCE_CUSTOM).
func _custom_buffer(transforms: Array, customs: Array) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(transforms.size() * 16)
	for i in range(transforms.size()):
		var t: Transform3D = transforms[i]
		var b: Basis = t.basis
		var o: int = i * 16
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
		var c: Color = customs[i]
		buf[o + 12] = c.r
		buf[o + 13] = c.g
		buf[o + 14] = c.b
		buf[o + 15] = c.a
	return buf


## The crowd: every spectator is a card (far) and, near the lap, also a 3D figure (near); the two swap by
## dither. Seated and standing ones have different cards (the standing ones reach the ground).
func _build_crowd(parent: Node, spots: Array, extra: Array = []) -> void:
	var card_meshes: Array = []
	for cls in range(CROWD_CARDS.size()):
		card_meshes.append(_crowd_card_mesh(cls))
	var person_mesh: ArrayMesh = CrowdKit.new().build()
	person_mesh.surface_set_material(0, _crowd_material(1))
	person_mesh = _save_shared_resource(person_mesh, "crowd_person")
	var rng := RandomNumberGenerator.new()
	rng.seed = 9021
	var cells := {}
	var near_cells := {}
	var all: Array = spots.duplicate()
	all.append_array(extra)
	var near_count := 0
	var standing_count := 0
	var poses_used := {}
	for sp in all:
		var pos: Vector3 = sp[0]
		var out3: Vector3 = sp[1]
		var row: int = sp[2]
		var standing_only: bool = sp.size() > 4 and sp[4]
		# Fuller near the front and the middle of the long stands.
		var empty_p: float = 0.1 + 0.012 * float(row)
		if rng.randf() < empty_p:
			continue
		var z: Vector3 = -out3
		var x: Vector3 = Vector3.UP.cross(z).normalized()
		var yaw_jit: float = rng.randf_range(-0.25, 0.25)
		var bs := Basis(x, Vector3.UP, z).rotated(Vector3.UP, yaw_jit)
		var hot: bool = absf(pos.x) < 60.0 and pos.z > 0.0
		var pose: int
		var origin: Vector3
		if standing_only:
			pose = _pick_pose(rng, POSE_STANDING_PLAZA, 7)
			origin = pos
		else:
			# A few stand in the stands, more in front of the main stand.
			var up_p: float = 0.18 if hot else 0.11
			if rng.randf() < up_p:
				pose = _pick_pose(rng, POSE_STANDING_FANS, 7, 2, 1.4 if hot else 1.0)
			else:
				pose = _pick_pose(rng, POSE_SEATED, 0, 5, 1.8 if hot else 1.0)
			origin = pos + out3 * 0.2 + Vector3(0.0, CROWD_SEAT_H, 0.0)
			if pose == 12 and _roof_underside(Vector2(pos.x, pos.z).dot(Vector2(out3.x, out3.z)) - ARENA_Z, int(sp[3])) - origin.y < FLAG_HEADROOM:
				pose = 9
		poses_used[pose] = int(poses_used.get(pose, 0)) + 1
		var is_standing: bool = pose >= 7
		if is_standing:
			standing_count += 1
		var cust := Color(rng.randf(), rng.randf(), (float(pose) + 0.5) / 16.0, rng.randf())
		# The card: seated ones stand forward of the seat.
		var card_origin: Vector3 = origin if is_standing else origin + z * CROWD_CARD_FORWARD
		var key := Vector3i(floori(pos.x / CROWD_CELL), floori(pos.z / CROWD_CELL), _crowd_card_class(pose))
		if not cells.has(key):
			cells[key] = [[], []]
		cells[key][0].append(Transform3D(bs, card_origin))
		cells[key][1].append(cust)
		if _lap_distance(Vector2(pos.x, pos.z), CROWD_NEAR_REACH) < CROWD_NEAR_REACH:
			var nkey := Vector2i(floori(pos.x / CROWD_NEAR_CELL), floori(pos.z / CROWD_NEAR_CELL))
			if not near_cells.has(nkey):
				near_cells[nkey] = [[], []]
			near_cells[nkey][0].append(Transform3D(bs, origin))
			near_cells[nkey][1].append(cust)
			near_count += 1
	var root := Node3D.new()
	root.name = "Crowd"
	root.set_script(load("res://CrowdDetail.gd"))
	root.set("base_begin", CROWD_LOD_BEGIN)
	root.set("base_end", CROWD_LOD_END)
	root.set("jitter", CROWD_LOD_JITTER)
	root.set("cell_reach", CROWD_NEAR_CELL)
	parent.add_child(root)
	var total := 0
	for key in cells:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = card_meshes[key.z]
		mm.instance_count = cells[key][0].size()
		mm.buffer = _custom_buffer(cells[key][0], cells[key][1])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Crowd_%d_%d_%d" % [key.x, key.y, key.z]
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)
		total += mm.instance_count
	var near_root := Node3D.new()
	near_root.name = "CrowdNear"
	root.add_child(near_root)
	# A cell is drawn while its middle is within the fade's end plus the cell's reach, the dither doing the rest
	# (CrowdDetail.gd moves this with the detail setting).
	var near_range: float = CROWD_LOD_END + CROWD_LOD_JITTER + CROWD_NEAR_CELL
	for key in near_cells:
		var mm2 := MultiMesh.new()
		mm2.transform_format = MultiMesh.TRANSFORM_3D
		mm2.use_custom_data = true
		mm2.mesh = person_mesh
		mm2.instance_count = near_cells[key][0].size()
		mm2.buffer = _custom_buffer(near_cells[key][0], near_cells[key][1])
		var mmi2 := MultiMeshInstance3D.new()
		mmi2.name = "CrowdNear_%d_%d" % [key.x, key.y]
		mmi2.multimesh = mm2
		mmi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi2.visibility_range_end = near_range
		near_root.add_child(mmi2)
	print("  crowd: %d spectators in %d cells (%d standing), %d with a 3D figure in %d cells" % [total, cells.size(), standing_count, near_count, near_cells.size()])


# ======================================================================================
#  Boards, lights, screens, flags
# ======================================================================================

const AD_COUNT := 16

func _boards_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://stadium_boards.gdshader")
	return m


## A sign panel `width` x `height` whose bottom edge is centred on `centre`, facing `face`,
## showing advert `idx` (LED boards cycle through the adverts). Its text reads left to right for
## someone looking at its front.
func _sign(b: Builder, centre: Vector3, width: float, height: float, face: Vector3, idx: int, led: bool) -> void:
	var c := Color(float(idx) / 64.0, 1.0 if led else 0.0, 0.0, 1.0)
	var right: Vector3 = (-face).cross(Vector3.UP).normalized()
	var p0: Vector3 = centre - right * (width * 0.5)
	var p1: Vector3 = centre + right * (width * 0.5)
	var up := Vector3(0, height, 0)
	b.tri(p0, p1, p1 + up, face, c, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1))
	b.tri(p0, p1 + up, p0 + up, face, c, Vector2(0, 0), Vector2(1, 1), Vector2(0, 1))


## LED boards along every stand front, printed banners on the corner walls and the roof
## fascias, and the StadiumAds node that draws their artwork at load.
func _build_boards(parent: Node) -> void:
	var boards := Builder.new()
	var frames := Builder.new()
	var mat := _boards_material()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4040
	var panel := 12.0
	var h := 1.5
	var y0 := 0.5
	var idx := 0
	for st in STANDS:
		var half: float = st[3]
		var out2: Vector2 = st[2]
		var out3 := Vector3(out2.x, 0.0, out2.y)
		var along3 := Vector3(-out2.y, 0.0, out2.x)
		var n: int = int(2.0 * half / panel)
		var w: float = 2.0 * half / float(n)
		for i in range(n):
			var c: Vector3 = _stand_point(st, -half + (float(i) + 0.5) * w, -BOARD_D, FLOOR_Y + y0)
			_sign(boards, c, w - 0.16, h, -out3, idx % AD_COUNT, true)
			idx += 1
		var f0: Vector3 = _stand_point(st, 0.0, -FRAME_D, FLOOR_Y + y0 + h * 0.5)
		frames.box(f0, Vector3(2.0 * half, h + 0.3, 0.04) if absf(out2.y) > 0.5 else Vector3(0.04, h + 0.3, 2.0 * half), 0.0, Color(0.06, 0.06, 0.07))
	# Printed banners on the corner walls (arena side), 24m x 3m.
	var banners := [
		[Vector2(ARENA_X, END_STAND_Z + 2.0), Vector2(0, 1), Vector2(-1, 0), 0],
		[Vector2(-ARENA_X, END_STAND_Z + 2.0), Vector2(0, 1), Vector2(1, 0), 1],
		[Vector2(-ARENA_X, -END_STAND_Z - 26.0), Vector2(0, 1), Vector2(1, 0), 13],
		[Vector2(SIDE_STAND_X + 2.0, ARENA_Z), Vector2(1, 0), Vector2(0, -1), 5],
		[Vector2(-SIDE_STAND_X - 26.0, ARENA_Z), Vector2(1, 0), Vector2(0, -1), 6],
		[Vector2(SIDE_STAND_X + 2.0, -ARENA_Z), Vector2(1, 0), Vector2(0, 1), 3],
		[Vector2(-SIDE_STAND_X - 26.0, -ARENA_Z), Vector2(1, 0), Vector2(0, 1), 8],
	]
	for bn in banners:
		var o: Vector2 = bn[0]
		var dir2: Vector2 = bn[1]
		var face2: Vector2 = bn[2]
		var face := Vector3(face2.x, 0, face2.y)
		var centre := Vector3(o.x + dir2.x * 12.0, 1.6, o.y + dir2.y * 12.0) + face * 0.06
		_sign(boards, centre, 24.0, 3.0, face, bn[3], false)
	# The roof fascias: the stadium's name over the start straight, the GP's over the north.
	for st in STANDS:
		if not st[4]:
			continue
		var out2b: Vector2 = st[2]
		var out3b := Vector3(out2b.x, 0.0, out2b.y)
		var along3b := Vector3(-out2b.y, 0.0, out2b.x)
		var fp: Vector3 = _stand_point(st, 0.0, ROOF_FRONT_D - 0.9, ROOF_FRONT_Y - 0.35)
		_sign(boards, fp, 32.0, 4.0, -out3b, 1 if out2b.y > 0.0 else 0, false)
	var mi := MeshInstance3D.new()
	mi.name = "SponsorBoards"
	mi.mesh = _save_baked_resource(boards.commit(), "boards")
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var fm := MeshInstance3D.new()
	fm.name = "BoardFrames"
	fm.mesh = frames.commit()
	fm.material_override = _vertex_color_material(0.6)
	parent.add_child(fm)
	var ads := Node.new()
	ads.name = "StadiumAds"
	ads.set_script(load("res://StadiumAds.gd"))
	var targets: Array[ShaderMaterial] = [mat]
	ads.set("targets", targets)
	parent.add_child(ads)
	_ads_material = mat


var _ads_material: ShaderMaterial


## Lattice floodlight masts in the four corner yards, heads aimed at the middle of the floor.
func _build_floodlights(parent: Node) -> void:
	var steel := Builder.new()
	var lamps := Builder.new()
	var col := Color(0.70, 0.72, 0.75)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var base := Vector3(sx * 140.0, STREET_Y, sz * 100.0)
			var height := 50.0
			var levels := 12
			var corners_b: Array = []
			var corners_t: Array = []
			for k in range(4):
				var a: float = PI * 0.25 + PI * 0.5 * float(k)
				corners_b.append(Vector3(cos(a), 0, sin(a)) * 2.4)
				corners_t.append(Vector3(cos(a), 0, sin(a)) * 0.9)
			for k in range(4):
				_beam(steel, base + corners_b[k], base + corners_t[k] + Vector3(0, height, 0), 0.35, col)
			for l in range(levels):
				var t0: float = float(l) / float(levels)
				var t1: float = float(l + 1) / float(levels)
				for k in range(4):
					var k2: int = (k + 1) % 4
					var a0: Vector3 = base + (corners_b[k] as Vector3).lerp(corners_t[k], t0) + Vector3(0, height * t0, 0)
					var b1: Vector3 = base + (corners_b[k2] as Vector3).lerp(corners_t[k2], t1) + Vector3(0, height * t1, 0)
					var a1: Vector3 = base + (corners_b[k] as Vector3).lerp(corners_t[k], t1) + Vector3(0, height * t1, 0)
					_beam(steel, a0, b1, 0.14, col)
					_beam(steel, a1, base + (corners_b[k2] as Vector3).lerp(corners_t[k2], t1) + Vector3(0, height * t1, 0), 0.14, col)
			# Lamp head: a frame of 5 x 4 lamps, tipped toward the middle of the floor.
			var top: Vector3 = base + Vector3(0, height + 3.0, 0)
			var aim: Vector3 = (Vector3(0, 0, 0) - top).normalized()
			var yaw: float = atan2(aim.x, aim.z)
			var bs := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -0.45)
			var head_w := 12.0
			var head_h := 7.0
			steel.box(top + bs * Vector3(0, 0, -0.5), Vector3(head_w + 0.6, 0.4, 0.4), yaw, col)
			for r in range(4):
				for c in range(5):
					var lp: Vector3 = top + bs * Vector3((float(c) - 2.0) * 2.4, (float(r) - 1.5) * 1.75, 0.0)
					lamps.box(lp, Vector3(1.9, 1.4, 0.5), yaw, Color(1, 1, 1))
					steel.box(lp + bs * Vector3(0, 0, -0.45), Vector3(2.0, 1.5, 0.5), yaw, Color(0.22, 0.23, 0.25))
	var mi := MeshInstance3D.new()
	mi.name = "FloodlightMasts"
	mi.mesh = _save_baked_resource(steel.commit(), "floodlight_masts")
	mi.material_override = _metal_material()
	parent.add_child(mi)
	var lm := MeshInstance3D.new()
	lm.name = "FloodlightLamps"
	lm.mesh = lamps.commit()
	var lmat := _lamp_material()
	lmat.emission_energy_multiplier = 3.0
	lm.material_override = lmat
	lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(lm)


## The big screen over the west stand: a live picture of the pack (Jumbotron.gd), facing the
## start straight. A static scoreboard over the east stand shows the GP's board.
func _build_screens(parent: Node, board_mat: ShaderMaterial) -> void:
	var west: Array = STANDS[3]
	var sec: Dictionary = _stand_section(false)
	var depth: float = sec["depth"]
	var top: float = sec["top"]
	var screen := Node3D.new()
	screen.name = "Jumbotron"
	screen.set_script(load("res://Jumbotron.gd"))
	var sp: Vector3 = _stand_point(west, 0.0, depth - 2.0, top)
	screen.position = sp
	# Faces east, down the floor (the quad's front is local +Z).
	screen.rotation.y = PI * 0.5
	screen.set("fallback_target", Vector3(60.0, 2.0, 48.0))
	screen.set("camera_offset", Vector3(16.0, 7.0, 12.0))
	screen.set("max_render_distance", 900.0)
	var vp := SubViewport.new()
	vp.name = "BroadcastViewport"
	vp.size = Vector2i(384, 216)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var cam := Camera3D.new()
	cam.name = "BroadcastCamera"
	cam.current = true
	cam.fov = 50.0
	cam.near = 0.5
	cam.far = 400.0
	vp.add_child(cam)
	screen.add_child(vp)
	var panel_size := Vector2(28.0, 15.75)
	var panel_y: float = panel_size.y * 0.5 + 3.0
	var quad := QuadMesh.new()
	quad.size = panel_size
	var face := MeshInstance3D.new()
	face.name = "Screen"
	face.mesh = quad
	face.position = Vector3(0, panel_y, 0)
	face.rotation.x = deg_to_rad(-6.0)
	screen.add_child(face)
	# The frame tilts with the panel. Untilted, its flat front face stood in front of the quad's upper
	# half (the quad leans back 6 degrees, so above 1m from its centre it sank behind the frame), which
	# hid the top 44% of the picture.
	var frame := Builder.new()
	frame.box(Vector3(0, 0, -0.7), Vector3(panel_size.x + 1.2, panel_size.y + 1.2, 1.2), 0.0, Color(0.12, 0.13, 0.15))
	var fm := MeshInstance3D.new()
	fm.name = "ScreenFrame"
	fm.mesh = frame.commit()
	fm.material_override = _metal_material()
	fm.position = Vector3(0, panel_y, 0)
	fm.rotation.x = face.rotation.x
	screen.add_child(fm)
	var legs := Builder.new()
	for sx in [-1.0, 1.0]:
		legs.box(Vector3(sx * panel_size.x * 0.3, 1.5, -1.2), Vector3(1.0, 3.0, 1.0), 0.0, Color(0.55, 0.57, 0.6))
	var lgm := MeshInstance3D.new()
	lgm.name = "ScreenLegs"
	lgm.mesh = legs.commit()
	lgm.material_override = _metal_material()
	screen.add_child(lgm)
	parent.add_child(screen)
	# Entering the tree ran Jumbotron._ready(), which gave the screen a material bound to the
	# viewport; it is made again at load, and saved here it would point at no viewport.
	face.material_override = null
	# East scoreboard: a printed board in a frame.
	var east: Array = STANDS[2]
	var ep: Vector3 = _stand_point(east, 0.0, depth - 2.0, top)
	var sb := Builder.new()
	var sbf := Builder.new()
	var w := 26.0
	var hh := 3.25
	_sign(sb, ep + Vector3(-0.6, 6.0, 0.0), w, hh, Vector3(-1, 0, 0), 0, false)
	_sign(sb, ep + Vector3(-0.6, 6.0 + hh + 0.4, 0.0), w, hh, Vector3(-1, 0, 0), 1, false)
	sbf.box(ep + Vector3(0.1, 6.0 + hh + 0.2, 0), Vector3(1.2, 2.0 * hh + 1.4, w + 1.2), 0.0, Color(0.12, 0.13, 0.15))
	for sz in [-1.0, 1.0]:
		sbf.box(ep + Vector3(0.3, 3.0, sz * w * 0.3), Vector3(1.0, 6.0, 1.0), 0.0, Color(0.55, 0.57, 0.6))
	var sbm := MeshInstance3D.new()
	sbm.name = "EastScoreboard"
	sbm.mesh = sb.commit()
	sbm.material_override = board_mat
	parent.add_child(sbm)
	var sbfm := MeshInstance3D.new()
	sbfm.name = "EastScoreboardFrame"
	sbfm.mesh = sbf.commit()
	sbfm.material_override = _metal_material()
	parent.add_child(sbfm)


## Pennants either side of every take-off (flag_cloth.gdshader), so the jumps read from afar.
func _build_jump_flags(parent: Node) -> void:
	const POST_H := 5.0
	var root := Node3D.new()
	root.name = "JumpFlags"
	parent.add_child(root)
	var post := CylinderMesh.new()
	post.top_radius = 0.06
	post.bottom_radius = 0.08
	post.height = POST_H
	post.radial_segments = 6
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.85, 0.85, 0.85)
	post_mat.metallic = 0.5
	post_mat.roughness = 0.4
	post.material = post_mat
	var cloth := PlaneMesh.new()
	cloth.orientation = PlaneMesh.FACE_Z
	cloth.size = Vector2(1.8, 1.1)
	cloth.subdivide_width = 14
	cloth.subdivide_depth = 3
	cloth.center_offset = Vector3(0.9, 0.0, 0.0)
	var cloth_mat := ShaderMaterial.new()
	cloth_mat.shader = load("res://flag_cloth.gdshader")
	cloth_mat.set_shader_parameter("color_a", Color(0.08, 0.42, 0.20))
	cloth_mat.set_shader_parameter("color_b", Color(0.98, 0.80, 0.15))
	cloth.material = cloth_mat
	var wind := Vector3(0.9, 0.0, -0.4).normalized()
	var flag_basis := Basis(Vector3.UP, atan2(-wind.z, wind.x))
	var posts: Array = []
	var flags: Array = []
	for lip in _lips:
		var s_lip: float = lip["s"]
		for side in [-1.0, 1.0]:
			var sp: Dictionary = _spot(s_lip - 2.0, side * (_half_at(s_lip) + 3.2), 0.0)
			var p: Vector3 = sp["pos"]
			p.y = _floor_at(p)
			posts.append(Transform3D(Basis(), p + Vector3(0, POST_H * 0.5, 0)))
			flags.append(Transform3D(flag_basis, p + Vector3(0, POST_H - 0.6, 0) + wind * 0.05))
	var pm: MultiMeshInstance3D = _multimesh(post, posts, "FlagPosts")
	root.add_child(pm)
	for i in range(flags.size()):
		var fl := MeshInstance3D.new()
		fl.name = "Flag_%d" % i
		fl.mesh = cloth
		fl.transform = flags[i]
		fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(fl)


## A truss gantry over the Drop-In's lip: the GP's board toward the run-up, the stadium's toward
## the floor. High enough to clear a boosted cart's flight.
func _build_drop_gantry(parent: Node) -> void:
	var b := Builder.new()
	var signs := Builder.new()
	var lip: Dictionary = _spot(float(_named_s["drop_lip"]) - 1.5, 0.0, 0.0)
	var p: Vector3 = lip["pos"]
	var right: Vector3 = lip["right"]
	var fwd: Vector3 = lip["fwd"]
	var half: float = _half_at(float(_named_s["drop_lip"])) + 2.6
	var top: float = STREET_Y + 13.0
	var col := Color(0.82, 0.83, 0.85)
	for side in [-1.0, 1.0]:
		var base: Vector3 = p + right * side * half
		base.y = STREET_Y
		for k in range(2):
			var off: Vector3 = fwd * (0.7 if k == 0 else -0.7)
			_beam(b, base + off, base + off + Vector3(0, top - STREET_Y, 0), 0.35, col)
		for l in range(6):
			var y0: float = STREET_Y + float(l) * (top - STREET_Y) / 6.0
			var y1: float = STREET_Y + float(l + 1) * (top - STREET_Y) / 6.0
			_beam(b, base + fwd * 0.7 + Vector3(0, y0, 0) - Vector3(0, STREET_Y, 0) + Vector3(0, STREET_Y, 0), base - fwd * 0.7 + Vector3(0, y1 - STREET_Y, 0), 0.12, col)
		_box_body(parent, "DropGantryLeg", base + Vector3(0, (top - STREET_Y) * 0.5, 0), Vector3(1.8, top - STREET_Y, 1.8), atan2(fwd.x, fwd.z))
	var l0: Vector3 = p - right * half
	var l1: Vector3 = p + right * half
	for dy in [top - 3.6, top]:
		for k in range(2):
			var off2: Vector3 = fwd * (0.7 if k == 0 else -0.7)
			_beam(b, Vector3(l0.x, dy, l0.z) + off2, Vector3(l1.x, dy, l1.z) + off2, 0.3, col)
	var mid := Vector3(p.x, top - 3.4, p.z)
	_sign(signs, mid - fwd * 0.8, 24.0, 3.0, -fwd, 0, false)
	_sign(signs, mid + fwd * 0.8, 24.0, 3.0, fwd, 1, false)
	var mi := MeshInstance3D.new()
	mi.name = "DropInGantry"
	mi.mesh = b.commit()
	mi.material_override = _metal_material()
	parent.add_child(mi)
	var sm := MeshInstance3D.new()
	sm.name = "DropInGantrySigns"
	sm.mesh = signs.commit()
	sm.material_override = _ads_material
	parent.add_child(sm)


## Ground under a point beside the track: the floor in the bowl, the paving outside.
func _floor_at(p: Vector3) -> float:
	if absf(p.x) <= ARENA_X and absf(p.z) <= ARENA_Z:
		return FLOOR_Y
	return STREET_Y


## Standing fans along the corner yards' parapets, two deep, clear of the Drop-In and the exit.
func _corner_crowd_spots() -> Array:
	var spots: Array = []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			for row in range(2):
				var back: float = 1.2 + float(row) * 1.3
				# Along the long edge.
				var x: float = SIDE_STAND_X + 2.0
				while x < ARENA_X - 1.0:
					spots.append([Vector3(sx * x, STREET_Y, sz * (ARENA_Z + back)), Vector3(0, 0, sz), row, 0, true])
					x += 1.25
				var z: float = END_STAND_Z + 2.0
				while z < ARENA_Z - 1.0:
					var zz: float = sz * z
					var skip: bool = sx > 0.0 and (absf(zz - 48.0) < 12.0 or absf(zz + 48.0) < 11.0)
					if not skip:
						spots.append([Vector3(sx * (ARENA_X + back), STREET_Y, zz), Vector3(sx, 0, 0), row, 0, true])
					z += 1.25
	return spots


# ======================================================================================
#  Streets
# ======================================================================================

## Street-level paving everywhere outside the bowl: a big sheet with holes for the floor, the
## stands and the exit cutting, as a union of rectangles.
func _build_ground(parent: Node, mat: Material) -> void:
	var outer := Rect2(-2600.0, -2600.0, 5200.0, 5200.0)
	var holes: Array = [Rect2(-ARENA_X, -ARENA_Z, 2.0 * ARENA_X, 2.0 * ARENA_Z)]
	for st in STANDS:
		var sec: Dictionary = _stand_section(st[4])
		var depth: float = float(sec["depth"]) + 0.1
		var half: float = st[3]
		var p0: Vector3 = _stand_point(st, -half, 0.0, 0.0)
		var p1: Vector3 = _stand_point(st, half, depth, 0.0)
		holes.append(Rect2(Vector2(minf(p0.x, p1.x), minf(p0.z, p1.z)), Vector2(absf(p1.x - p0.x), absf(p1.z - p0.z))))
	var cut_half: float = _half_at(_s_at_x(SEG_L4, ARENA_X)) + 0.55
	holes.append(Rect2(ARENA_X, -48.0 - cut_half, EXIT_TO_X - ARENA_X, 2.0 * cut_half))
	var xs: Array = [outer.position.x, outer.end.x]
	var zs: Array = [outer.position.y, outer.end.y]
	for h in holes:
		xs.append_array([h.position.x, h.end.x])
		zs.append_array([h.position.y, h.end.y])
	# Extra cuts so no quad is more than ~400m across (fog and shadows behave).
	var k := -2400.0
	while k < 2600.0:
		xs.append(k)
		zs.append(k)
		k += 400.0
	xs.sort()
	zs.sort()
	var b := Builder.new()
	var faces := PackedVector3Array()
	for i in range(xs.size() - 1):
		for j in range(zs.size() - 1):
			var x0: float = xs[i]
			var x1: float = xs[i + 1]
			var z0: float = zs[j]
			var z1: float = zs[j + 1]
			if x1 - x0 < 0.01 or z1 - z0 < 0.01:
				continue
			var c := Vector2((x0 + x1) * 0.5, (z0 + z1) * 0.5)
			var in_hole := false
			for h in holes:
				if h.has_point(c):
					in_hole = true
					break
			if in_hole:
				continue
			var a := Vector3(x0, STREET_Y, z0)
			var bb := Vector3(x1, STREET_Y, z0)
			var cc := Vector3(x1, STREET_Y, z1)
			var d := Vector3(x0, STREET_Y, z1)
			b.quad(a, bb, cc, d, Vector3.UP, Color.WHITE, 1.0)
			if absf(c.x) < 700.0 and absf(c.y) < 700.0:
				faces.append_array([a, bb, cc, a, cc, d])
	var mi := MeshInstance3D.new()
	mi.name = "StreetPaving"
	mi.mesh = b.commit()
	mi.material_override = mat
	parent.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "StreetPavingBody"
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)


## Concrete walls each side of the ramp up out of the bowl, from the arena edge to the street.
func _build_cutting(parent: Node, concrete: Material) -> void:
	var b := Builder.new()
	var faces := PackedVector3Array()
	var s0: float = _s_at_x(SEG_L4, ARENA_X)
	var s1: float = _named_s["exit_to"]
	var step := 2.0
	var s: float = s0
	while s < s1 - 0.01:
		var sa: float = s
		var sb: float = minf(s + step, s1)
		for side in [-1.0, 1.0]:
			var pts: Array = []
			for ss in [sa, sb]:
				var pa: Dictionary = _plan_at(ss)
				var p2: Vector2 = pa["p"]
				var r2: Vector2 = _right_of(float(pa["th"]))
				var lat: float = side * (_half_at(ss) + 0.55)
				var q: Vector2 = p2 + r2 * lat
				var q2: Vector2 = p2 + r2 * (lat + side * 0.7)
				pts.append([Vector3(q.x, _h_at(ss) - 0.4, q.y), Vector3(q.x, STREET_Y + PARAPET, q.y), Vector3(q2.x, STREET_Y + PARAPET, q2.y)])
			var inner := Vector3(-side * _right_of(float(_plan_at(sa)["th"])).x, 0.0, -side * _right_of(float(_plan_at(sa)["th"])).y)
			var c := Color(0.76, 0.75, 0.72)
			b.quad(pts[0][0], pts[1][0], pts[1][1], pts[0][1], inner, c, 0.25)
			b.quad(pts[0][1], pts[1][1], pts[1][2], pts[0][2], Vector3.UP, c * 0.9, 0.25)
			faces.append_array([pts[0][0], pts[1][0], pts[1][1], pts[0][0], pts[1][1], pts[0][1]])
		s = sb
	var mi := MeshInstance3D.new()
	mi.name = "CuttingWalls"
	mi.mesh = b.commit()
	mi.material_override = concrete
	parent.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "CuttingWallBody"
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)


## Concrete barriers with a catch fence along both sides of the streets, from the top of the
## cutting round to the Drop-In kicker.
func _build_street_barriers(parent: Node, concrete: Material, net_mat: Material) -> void:
	var b := Builder.new()
	var net := Builder.new()
	var faces := PackedVector3Array()
	var s0: float = _named_s["exit_to"]
	var s1: float = _named_s["drop_kick"] + 2.0
	var step := 2.0
	var s: float = s0
	var col := Color(0.86, 0.85, 0.82)
	var stripe := 0
	while s < s1 - 0.01:
		var sa: float = s
		var sb: float = minf(s + step, s1)
		stripe += 1
		for side in [-1.0, 1.0]:
			var ring: Array = []
			for ss in [sa, sb]:
				var pa: Dictionary = _plan_at(ss)
				var p2: Vector2 = pa["p"]
				var r2: Vector2 = _right_of(float(pa["th"]))
				var base_lat: float = side * (_half_at(ss) + 1.3)
				var prof := [[0.0, 0.0], [0.15, 0.25], [0.42, 0.7], [0.5, 1.25], [0.75, 1.25], [0.85, 0.7], [1.1, 0.25], [1.25, 0.0]]
				var pts: Array = []
				for pr in prof:
					var q: Vector2 = p2 + r2 * (base_lat + side * float(pr[0]))
					pts.append(Vector3(q.x, STREET_Y - 0.05 + float(pr[1]), q.y))
				ring.append(pts)
				ring.append(r2 * side)
			var inner2: Vector2 = -ring[1]
			for k in range(ring[0].size() - 1):
				var a0: Vector3 = ring[0][k]
				var a1: Vector3 = ring[0][k + 1]
				var b1: Vector3 = ring[2][k + 1]
				var b0: Vector3 = ring[2][k]
				var mid: Vector3 = (a0 + a1) * 0.5
				var hint: Vector3 = Vector3(inner2.x, 0, inner2.y) if k < 3 else (Vector3.UP if k == 3 else Vector3(-inner2.x, 0, -inner2.y))
				var c: Color = col
				if k == 3 and stripe % 2 == 0:
					c = Color(0.85, 0.16, 0.10)
				b.quad(a0, a1, b1, b0, hint, c, 0.3)
				if k < 4:
					faces.append_array([a0, a1, b1, a0, b1, b0])
			# Fence over the barrier.
			var t0: Vector3 = (ring[0][3] + ring[0][4]) * 0.5
			var t1: Vector3 = (ring[2][3] + ring[2][4]) * 0.5
			net.quad(t0, t1, t1 + Vector3(0, 2.8, 0), t0 + Vector3(0, 2.8, 0), Vector3(inner2.x, 0, inner2.y), Color.WHITE, 1.0)
			if stripe % 3 == 0:
				b.box(t0 + Vector3(0, 1.45, 0), Vector3(0.12, 2.9, 0.12), 0.0, Color(0.3, 0.31, 0.33))
		s = sb
	var mi := MeshInstance3D.new()
	mi.name = "StreetBarriers"
	mi.mesh = _save_baked_resource(b.commit(), "street_barriers")
	mi.material_override = concrete
	parent.add_child(mi)
	var ni := MeshInstance3D.new()
	ni.name = "StreetFence"
	ni.mesh = _save_baked_resource(net.commit(), "street_fence")
	ni.material_override = net_mat
	ni.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ni)
	var body := StaticBody3D.new()
	body.name = "StreetBarrierBody"
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	cs.shape = _save_baked_resource(shape, "street_barrier_collision")
	body.add_child(cs)
	parent.add_child(body)


## Wire mesh for the catch nets: alpha-tested diamonds, thinning out with distance.
func _net_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode cull_disabled, diffuse_burley;
varying vec3 w_pos;
void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float d = length(w_pos - CAMERA_POSITION_WORLD);
	vec2 g = vec2(w_pos.x + w_pos.z, w_pos.y) * 1.6;
	vec2 a = abs(fract(vec2(g.x + g.y, g.x - g.y)) - 0.5);
	float wire = 1.0 - smoothstep(0.03, 0.09 + d * 0.0015, min(a.x, a.y));
	float far = smoothstep(25.0, 120.0, d);
	ALBEDO = vec3(0.22, 0.23, 0.24);
	ROUGHNESS = 0.6;
	METALLIC = 0.5;
	ALPHA = mix(wire, 0.28, far);
	ALPHA_SCISSOR_THRESHOLD = 0.25;
}
"""
	m.shader = sh
	return m


# ======================================================================================
#  City
# ======================================================================================

## The street grid (city_ground.gdshader draws the same one): streets every BLOCK_X along x and
## BLOCK_Z along z through (STREET_X0, STREET_Z0), so the avenue and the south street of the lap
## are grid streets. Inside PRECINCT there is no grid: the stadium, its plazas and the lap.
const STREET_X0 := 320.0
const STREET_Z0 := 190.0
const BLOCK_X := 110.0
const BLOCK_Z := 95.0
const CITY_STREET_HALF := 9.0
const PAVEMENT := 4.5
const PRECINCT := Rect2(-230.0, -190.0, 550.0, 380.0)
const CITY_RADIUS := 1900.0
## The towers of the city centre, east-north-east: ahead as the lap climbs out of the bowl.
const CBD := Vector2(1050.0, -650.0)
const CITY_CELL := 400.0

var _lap_cells := {}

## Buckets the lap centreline (every 2m) for _lap_distance.
func _index_lap() -> void:
	_lap_cells.clear()
	var s := 0.0
	while s < _lap_len:
		var p: Vector2 = _plan_at(s)["p"]
		var key := Vector2i(floori(p.x / 20.0), floori(p.y / 20.0))
		if not _lap_cells.has(key):
			_lap_cells[key] = PackedVector2Array()
		_lap_cells[key].append(p)
		s += 2.0


## Distance from p to the nearest point of the lap's centreline (searching `reach` metres).
func _lap_distance(p: Vector2, reach := 60.0) -> float:
	var best := reach
	var r: int = int(ceil(reach / 20.0))
	var cx: int = floori(p.x / 20.0)
	var cz: int = floori(p.y / 20.0)
	for i in range(cx - r, cx + r + 1):
		for j in range(cz - r, cz + r + 1):
			var key := Vector2i(i, j)
			if not _lap_cells.has(key):
				continue
			for q in _lap_cells[key]:
				best = minf(best, p.distance_to(q))
	return best


## A box building on footprint `r` (x, z) from the street up to `top`, walls UV'd in metres
## (along, up) for city_building.gdshader, a flat roof UV'd in world XZ.
## city_building.gdshader's window bay, and its shop-front unit (1.5 bays).
const CITY_BAY := 4.0
const CITY_SHOP_UNIT := 6.0
const CITY_STOREY := 4.6
const CITY_SHOP_H := 6.0
## Facade kinds in a vertex colour's alpha (city_building.gdshader): 0 a block with windows, 0.25 a low block with
## an iron roof, 0.7 plain concrete (cornices, balconies, plant rooms), 0.8 railing bars, 1 glass.
const A_PLAIN := 0.7
const A_RAIL := 0.8
## Buildings within this of the lap get the full detail; within the second, the massing and cornices only.
const CITY_DETAIL_NEAR := 180.0
const CITY_DETAIL_MID := 460.0
## The small parts (balconies, canopies, rooftop gear) are drawn out to this and cast no shadow.
const CITY_DETAIL_RANGE := 520.0


static func _poly_area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in range(poly.size()):
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


static func _rect_poly(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


## The polygon's outward normal for the edge i -> i+1, in (x, z).
static func _edge_out(poly: PackedVector2Array, i: int) -> Vector2:
	var a := poly[i]
	var c := poly[(i + 1) % poly.size()]
	var d := (c - a).normalized()
	return Vector2(d.y, -d.x) if _poly_area(poly) > 0.0 else Vector2(-d.y, d.x)


## One tier of a building: walls from `y0` to `y1` round `poly` (UV.x stretched so every wall ends on a whole bay
## and a whole shop front, see city_building.gdshader), and a roof. `runs` carries the bay counts from tier to tier.
func _tier(b: Builder, poly: PackedVector2Array, y0: float, y1: float, col: Color, runs: Dictionary) -> void:
	for k in range(poly.size()):
		var a: Vector2 = poly[k]
		var c: Vector2 = poly[(k + 1) % poly.size()]
		var len: float = a.distance_to(c)
		if len < 0.05:
			continue
		var o: Vector2 = _edge_out(poly, k)
		var out3 := Vector3(o.x, 0, o.y)
		var p0 := Vector3(a.x, y0, a.y)
		var p1 := Vector3(c.x, y0, c.y)
		var p2 := Vector3(c.x, y1, c.y)
		var p3 := Vector3(a.x, y1, a.y)
		var n_bays: int = maxi(1, int(round(len / CITY_BAY)))
		var n_shops: int = maxi(1, int(round(len / CITY_SHOP_UNIT)))
		var u0: float = float(runs["bays"]) * CITY_BAY
		var u1: float = float(int(runs["bays"]) + n_bays) * CITY_BAY
		var v0: float = float(runs["shops"]) * CITY_SHOP_UNIT
		var v1: float = float(int(runs["shops"]) + n_shops) * CITY_SHOP_UNIT
		var h0: float = y0 - STREET_Y
		var h1: float = y1 - STREET_Y
		var st: float = float(runs.get("style", 0))
		b.tri2(p0, p1, p2, out3, col, Vector2(u0, h0), Vector2(u1, h0), Vector2(u1, h1), Vector2(v0, st), Vector2(v1, st), Vector2(v1, st))
		b.tri2(p0, p2, p3, out3, col, Vector2(u0, h0), Vector2(u1, h1), Vector2(u0, h1), Vector2(v0, st), Vector2(v1, st), Vector2(v0, st))
		runs["bays"] = int(runs["bays"]) + n_bays
		runs["shops"] = int(runs["shops"]) + n_shops
	var tris := Geometry2D.triangulate_polygon(poly)
	for i in range(0, tris.size(), 3):
		var q0 := Vector3(poly[tris[i]].x, y1, poly[tris[i]].y)
		var q1 := Vector3(poly[tris[i + 1]].x, y1, poly[tris[i + 1]].y)
		var q2 := Vector3(poly[tris[i + 2]].x, y1, poly[tris[i + 2]].y)
		b.tri(q0, q1, q2, Vector3.UP, col, Vector2(q0.x, q0.z), Vector2(q1.x, q1.z), Vector2(q2.x, q2.z))


## A box along the edge i of `poly`, `along` long (centred, or from the start with `from_start`), `depth` out
## from the wall (negative: in), `height` tall from `y`; for cornices, parapets, canopies and balconies.
func _edge_box(b: Builder, poly: PackedVector2Array, i: int, y: float, height: float, depth: float, col: Color, grow := 0.0, margin := 0.0, inner := 0.0) -> void:
	var a: Vector2 = poly[i]
	var c: Vector2 = poly[(i + 1) % poly.size()]
	var d: Vector2 = c - a
	var len: float = d.length()
	if len - 2.0 * margin < 0.3:
		return
	d /= len
	var o: Vector2 = _edge_out(poly, i)
	# The box spans from `inner` behind the wall face to `depth` in front of it.
	var thick: float = absf(depth) + inner
	var mid_off: float = (depth - inner) * 0.5
	var centre2: Vector2 = (a + c) * 0.5 + o * mid_off
	var length: float = len - 2.0 * margin + 2.0 * grow
	b.box(Vector3(centre2.x, y + height * 0.5, centre2.y), Vector3(length, height, thick), -atan2(d.y, d.x), col)


## True where edge i of `poly` lies along an edge of one of `others` (a wall shared with another tier).
static func _edge_shared(poly: PackedVector2Array, i: int, others: Array) -> bool:
	var m: Vector2 = (poly[i] + poly[(i + 1) % poly.size()]) * 0.5
	for op in others:
		var pg: PackedVector2Array = op
		for k in range(pg.size()):
			var a := pg[k]
			var c := pg[(k + 1) % pg.size()]
			var t := clampf((m - a).dot(c - a) / maxf((c - a).length_squared(), 0.001), 0.0, 1.0)
			if m.distance_to(a + (c - a) * t) < 0.3:
				return true
	return false


## The tiers of a building as [{poly, y0, y1}], bottom to top. `lot` is the whole plot, `fp` the footprint the
## tower or the body stands on; `kind` 0 slab, 1 podium and tower, 2 stepped, 3 L-shaped.
func _massing(lot: Rect2, fp: Rect2, top: float, storeys: int, kind: int, rng: RandomNumberGenerator) -> Array:
	var y_base: float = STREET_Y - 0.3
	var tiers: Array = []
	match kind:
		1:
			# A podium of two floors on the plot, a tower on it, and a crown of two floors with a mast.
			var py: float = STREET_Y + CITY_SHOP_H + 2.0 * CITY_STOREY
			var crown_y: float = top - 2.0 * CITY_STOREY
			tiers.append({"poly": _rect_poly(lot), "y0": y_base, "y1": py, "podium": true})
			tiers.append({"poly": _rect_poly(fp), "y0": py, "y1": crown_y})
			tiers.append({"poly": _rect_poly(fp.grow(-minf(fp.size.x, fp.size.y) * 0.16)), "y0": crown_y, "y1": top, "crown": true})
		2:
			# Stepped back twice, the upper steps on two sides or all four.
			var f1: float = STREET_Y + CITY_SHOP_H + float(maxi(2, int(round(float(storeys) * 0.55)))) * CITY_STOREY
			var f2: float = STREET_Y + CITY_SHOP_H + float(maxi(3, int(round(float(storeys) * 0.80)))) * CITY_STOREY
			var s1: float = rng.randf_range(2.5, 4.0)
			var s2: float = s1 + rng.randf_range(2.5, 4.0)
			tiers.append({"poly": _rect_poly(fp), "y0": y_base, "y1": f1})
			tiers.append({"poly": _rect_poly(_step_rect(fp, s1, rng)), "y0": f1, "y1": f2})
			tiers.append({"poly": _rect_poly(_step_rect(fp, s2, rng)), "y0": f2, "y1": top})
		3:
			# An L: the main body full height, with a lower wing filling the notch.
			var cut_x: float = fp.size.x * rng.randf_range(0.38, 0.5)
			var cut_z: float = fp.size.y * rng.randf_range(0.38, 0.5)
			var corner: int = rng.randi_range(0, 3)
			var x0: float = fp.position.x
			var x1: float = fp.end.x
			var z0: float = fp.position.y
			var z1: float = fp.end.y
			var notch: Rect2
			var l_poly: PackedVector2Array
			match corner:
				0:
					notch = Rect2(x0, z0, cut_x, cut_z)
					l_poly = PackedVector2Array([Vector2(x0 + cut_x, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1), Vector2(x0, z0 + cut_z), Vector2(x0 + cut_x, z0 + cut_z)])
				1:
					notch = Rect2(x1 - cut_x, z0, cut_x, cut_z)
					l_poly = PackedVector2Array([Vector2(x0, z0), Vector2(x1 - cut_x, z0), Vector2(x1 - cut_x, z0 + cut_z), Vector2(x1, z0 + cut_z), Vector2(x1, z1), Vector2(x0, z1)])
				2:
					notch = Rect2(x1 - cut_x, z1 - cut_z, cut_x, cut_z)
					l_poly = PackedVector2Array([Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1 - cut_z), Vector2(x1 - cut_x, z1 - cut_z), Vector2(x1 - cut_x, z1), Vector2(x0, z1)])
				_:
					notch = Rect2(x0, z1 - cut_z, cut_x, cut_z)
					l_poly = PackedVector2Array([Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0 + cut_x, z1), Vector2(x0 + cut_x, z1 - cut_z), Vector2(x0, z1 - cut_z)])
			tiers.append({"poly": l_poly, "y0": y_base, "y1": top})
			var wing_top: float = STREET_Y + CITY_SHOP_H + float(maxi(1, storeys - 3)) * CITY_STOREY
			tiers.append({"poly": _rect_poly(notch), "y0": y_base, "y1": wing_top, "wing": true})
		_:
			tiers.append({"poly": _rect_poly(fp), "y0": y_base, "y1": top})
	return tiers


## `r` set back by `d` on two adjacent sides (a corner setback) or on all four.
func _step_rect(r: Rect2, d: float, rng: RandomNumberGenerator) -> Rect2:
	var dd: float = minf(d, minf(r.size.x, r.size.y) * 0.3)
	if rng.randf() < 0.5:
		return r.grow(-dd)
	var sx: float = -1.0 if rng.randf() < 0.5 else 1.0
	var sz: float = -1.0 if rng.randf() < 0.5 else 1.0
	var out := r
	if sx < 0.0:
		out.position.x += dd
		out.size.x -= dd
	else:
		out.size.x -= dd
	if sz < 0.0:
		out.position.y += dd
		out.size.y -= dd
	else:
		out.size.y -= dd
	return out


## A building: its massing as tiers, then (by `detail` 0 none, 1 cornices, 2 everything) the architecture:
## cornices and parapets, corner pilasters, shop awnings, balcony galleries, and the roof's gear. `b` is the
## shell (it casts shadows) and `d` the small parts. `street` is the block's outline: edges along it are the
## street fronts. Details use `rng`, their own stream, so the city's layout does not move.
func _building_massed(b: Builder, d: Builder, lot: Rect2, fp: Rect2, top: float, storeys: int, col: Color, street: Rect2, detail: int, rng: RandomNumberGenerator) -> void:
	var glass: bool = col.a > 0.9
	var kind := 0
	if glass and storeys >= 8:
		kind = 1
	elif detail >= 1 and not glass:
		var roll: float = rng.randf()
		if storeys >= 7 and roll < 0.40:
			kind = 2
		elif storeys >= 3 and roll < 0.62 and minf(fp.size.x, fp.size.y) > 16.0:
			kind = 3
	var tiers := _massing(lot, fp, top, storeys, kind, rng)
	# The window style, in UV2.y: 0 punched, 1 ribbon, 2 a narrow pair, 3 tall (city_building.gdshader).
	var runs := {"bays": 0, "shops": 0, "style": rng.randi_range(0, 3)}
	var trim := Color(minf(col.r + 0.14, 1.0), minf(col.g + 0.14, 1.0), minf(col.b + 0.14, 1.0), A_PLAIN)
	var dark := Color(col.r * 0.55, col.g * 0.55, col.b * 0.55, A_PLAIN)
	var polys: Array = []
	for t in tiers:
		polys.append(t["poly"])
	for ti in range(tiers.size()):
		var t: Dictionary = tiers[ti]
		var poly: PackedVector2Array = t["poly"]
		var tier_col := col
		if t.get("podium", false):
			tier_col = Color(col.r, col.g, col.b, 0.0)
		elif t.get("crown", false):
			tier_col = Color(col.r, col.g, col.b, A_PLAIN) if rng.randf() < 0.5 else col
		_tier(b, poly, float(t["y0"]), float(t["y1"]), tier_col, runs)
	if detail < 1:
		return
	var others: Array
	# Cornices and parapets on every tier's top; the parapet only where the roof is open.
	for ti in range(tiers.size()):
		var t2: Dictionary = tiers[ti]
		var poly2: PackedVector2Array = t2["poly"]
		others = polys.duplicate()
		others.remove_at(ti)
		var y1: float = t2["y1"]
		for k in range(poly2.size()):
			if _edge_shared(poly2, k, others):
				continue
			_edge_box(d, poly2, k, y1 - 0.55, 0.55, 0.30, trim, 0.30, 0.0, 0.1)
			if ti == tiers.size() - 1 or t2.get("podium", false) or t2.get("wing", false) or t2.get("crown", false):
				_edge_box(d, poly2, k, y1, 0.9, -0.0, dark, 0.0, 0.0, 0.28)
	if detail < 2:
		return
	var base: Dictionary = tiers[0]
	var bpoly: PackedVector2Array = base["poly"]
	var base_top: float = base["y1"]
	# Corner pilasters up the ground tier.
	if not glass and rng.randf() < 0.55:
		for k in range(bpoly.size()):
			var corner: Vector2 = bpoly[k]
			var o1: Vector2 = _edge_out(bpoly, k)
			var o0: Vector2 = _edge_out(bpoly, (k - 1 + bpoly.size()) % bpoly.size())
			if (o0 + o1).length() < 0.9:
				continue
			var bis: Vector2 = (o0 + o1).normalized()
			var c2: Vector2 = corner + bis * 0.05
			d.box(Vector3(c2.x, (STREET_Y - 0.3 + base_top) * 0.5, c2.y), Vector3(0.9, base_top - (STREET_Y - 0.3), 0.9), 0.0, trim)
	# Shop awnings along the street fronts, in a bright cloth.
	var awning: Color = [Color(0.85, 0.20, 0.12), Color(0.10, 0.45, 0.72), Color(0.95, 0.72, 0.12), Color(0.10, 0.52, 0.28), Color(0.90, 0.42, 0.10)][rng.randi() % 5]
	awning.a = A_PLAIN
	for k in range(bpoly.size()):
		var mid: Vector2 = (bpoly[k] + bpoly[(k + 1) % bpoly.size()]) * 0.5
		if bpoly[k].distance_to(bpoly[(k + 1) % bpoly.size()]) < 7.0:
			continue
		# Only along the street: the edge is near the outline of the block.
		var d_street: float = minf(minf(absf(mid.x - street.position.x), absf(mid.x - street.end.x)), minf(absf(mid.y - street.position.y), absf(mid.y - street.end.y)))
		if d_street > 1.5:
			continue
		_edge_box(d, bpoly, k, STREET_Y + 4.55, 0.18, 1.7, awning, 0.0, 0.6, 0.15)
		_edge_box(d, bpoly, k, STREET_Y + 4.25, 0.30, 1.7, awning * 0.8, 0.0, 0.6, -1.55)
	# Balcony galleries on the street fronts of the residential blocks, every other floor.
	if not glass and storeys >= 3 and storeys <= 14 and kind != 1 and rng.randf() < 0.6:
		var rail := Color(col.r, col.g, col.b, A_RAIL)
		var slab := Color(col.r * 0.9, col.g * 0.9, col.b * 0.9, A_PLAIN)
		var edges_done := 0
		for k in range(bpoly.size()):
			var a2: Vector2 = bpoly[k]
			var c3: Vector2 = bpoly[(k + 1) % bpoly.size()]
			if a2.distance_to(c3) < 10.0 or edges_done >= 2:
				continue
			var mid2: Vector2 = (a2 + c3) * 0.5
			var d_st: float = minf(minf(absf(mid2.x - street.position.x), absf(mid2.x - street.end.x)), minf(absf(mid2.y - street.position.y), absf(mid2.y - street.end.y)))
			if d_st > 1.5 or _edge_shared(bpoly, k, polys.slice(1)):
				continue
			var first: int = 1 + rng.randi_range(0, 1)
			for fl in range(first, storeys, 2):
				var fy: float = STREET_Y + CITY_SHOP_H + float(fl) * CITY_STOREY
				if fy + 1.3 > base_top:
					break
				_edge_box(d, bpoly, k, fy, 0.22, 1.5, slab, 0.0, 1.0, 0.1)
				_edge_box(d, bpoly, k, fy + 0.22, 1.0, 1.44, rail, 0.0, 1.0, -1.38)
				_edge_box(d, bpoly, k, fy + 1.22, 0.07, 1.5, slab * 0.8, 0.0, 1.0, -1.43)
			edges_done += 1
	# The roof's gear, on the top tier.
	var top_t: Dictionary = tiers[tiers.size() - 1]
	if kind == 3:
		top_t = tiers[0]
	_roof_gear(d, top_t["poly"], float(top_t["y1"]), glass, kind == 1, rng)


## What stands on a roof: water tanks on stands, a stair housing, solar water heaters, air-conditioner
## boxes, a satellite dish, an antenna mast (tall on a glass tower), and a lift housing.
func _roof_gear(d: Builder, poly: PackedVector2Array, y: float, glass: bool, tower: bool, rng: RandomNumberGenerator) -> void:
	var bb := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		bb = bb.expand(p)
	var inner: Rect2 = bb.grow(-2.0)
	if inner.size.x < 3.0 or inner.size.y < 3.0:
		return
	var plain := func(c: Color) -> Color:
		return Color(c.r, c.g, c.b, A_PLAIN)
	var pick := func() -> Vector2:
		var pt := Vector2.ZERO
		for t in range(8):
			pt = Vector2(rng.randf_range(inner.position.x, inner.end.x), rng.randf_range(inner.position.y, inner.end.y))
			if Geometry2D.is_point_in_polygon(pt, poly):
				break
		return pt
	# A lift or stair housing, with a door and a deeper roof.
	if rng.randf() < 0.65 or tower:
		var c: Vector2 = pick.call()
		d.box(Vector3(c.x, y + 1.9, c.y), Vector3(4.2, 3.8, 4.6), 0.0, plain.call(Color(0.72, 0.70, 0.66)))
		d.box(Vector3(c.x, y + 3.95, c.y), Vector3(4.6, 0.3, 5.0), 0.0, plain.call(Color(0.52, 0.52, 0.50)))
	# Water tanks: black polytanks on steel stands.
	var tanks: int = rng.randi_range(1, 3) if not tower else 1
	for k in range(tanks):
		var c2: Vector2 = pick.call()
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				d.box(Vector3(c2.x + sx * 0.9, y + 0.7, c2.y + sz * 0.9), Vector3(0.18, 1.4, 0.18), 0.0, plain.call(Color(0.35, 0.36, 0.38)))
		d.box(Vector3(c2.x, y + 1.45, c2.y), Vector3(2.3, 0.2, 2.3), 0.0, plain.call(Color(0.35, 0.36, 0.38)))
		var tank_poly := PackedVector2Array()
		for i in range(10):
			var a: float = TAU * float(i) / 10.0
			tank_poly.append(c2 + Vector2(cos(a), sin(a)) * 1.05)
		_roof_cylinder(d, tank_poly, y + 1.55, y + 3.45, plain.call(Color(0.07, 0.07, 0.08)))
		_roof_cylinder(d, _scaled_poly(tank_poly, c2, 0.5), y + 3.45, y + 3.65, plain.call(Color(0.05, 0.05, 0.06)))
	# Solar water heaters: a tilted panel and a cylinder on a frame, a Nairobi rooftop's staple.
	if rng.randf() < 0.55 and not tower:
		var c3: Vector2 = pick.call()
		var yaw: float = float(rng.randi_range(0, 3)) * PI * 0.5
		for k in range(rng.randi_range(1, 3)):
			var o: Vector3 = Vector3(c3.x, y, c3.y) + Basis(Vector3.UP, yaw) * Vector3(float(k) * 2.4, 0.0, 0.0)
			var bs := Basis(Vector3.UP, yaw)
			d.box(o + bs * Vector3(0, 0.75, 0.2), Vector3(1.9, 0.14, 1.3), yaw, plain.call(Color(0.10, 0.12, 0.22)))
			d.box(o + bs * Vector3(0, 1.35, 0.9), Vector3(1.9, 0.5, 0.5), yaw, plain.call(Color(0.84, 0.85, 0.86)))
			d.box(o + bs * Vector3(0, 0.4, 0.2), Vector3(0.12, 0.8, 0.12), yaw, plain.call(Color(0.4, 0.4, 0.42)))
	# Air-conditioner condensers.
	if rng.randf() < 0.5:
		var c4: Vector2 = pick.call()
		for k in range(rng.randi_range(2, 4)):
			d.box(Vector3(c4.x + float(k) * 1.3, y + 0.45, c4.y), Vector3(1.0, 0.9, 0.5), 0.0, plain.call(Color(0.85, 0.86, 0.87)))
			d.box(Vector3(c4.x + float(k) * 1.3, y + 0.45, c4.y + 0.26), Vector3(0.7, 0.7, 0.03), 0.0, plain.call(Color(0.15, 0.15, 0.16)))
	# An antenna mast with a crossbar, tall on a tower with a red lamp at the top.
	if rng.randf() < 0.5 or tower:
		var c5: Vector2 = pick.call()
		var mh: float = 14.0 if tower else rng.randf_range(4.0, 7.0)
		d.box(Vector3(c5.x, y + mh * 0.5, c5.y), Vector3(0.22, mh, 0.22), 0.0, plain.call(Color(0.55, 0.56, 0.58)))
		d.box(Vector3(c5.x, y + mh * 0.8, c5.y), Vector3(2.2, 0.12, 0.12), 0.0, plain.call(Color(0.55, 0.56, 0.58)))
		if tower:
			d.box(Vector3(c5.x, y + mh + 0.2, c5.y), Vector3(0.5, 0.5, 0.5), 0.0, Color(1.0, 0.25, 0.2, A_PLAIN))
	# A satellite dish on a post.
	if rng.randf() < 0.35:
		var c6: Vector2 = pick.call()
		d.box(Vector3(c6.x, y + 0.6, c6.y), Vector3(0.15, 1.2, 0.15), 0.0, plain.call(Color(0.5, 0.5, 0.52)))
		var dish := PackedVector2Array()
		for i in range(9):
			var a: float = TAU * float(i) / 9.0
			dish.append(c6 + Vector2(cos(a), sin(a)) * 0.75)
		_roof_cylinder(d, dish, y + 1.2, y + 1.3, plain.call(Color(0.9, 0.9, 0.9)))


static func _scaled_poly(poly: PackedVector2Array, centre: Vector2, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly:
		out.append(centre + (p - centre) * k)
	return out


## A prism over a convex plan polygon, from y0 to y1 (smooth walls are not needed: the shader paints flat).
func _roof_cylinder(d: Builder, poly: PackedVector2Array, y0: float, y1: float, col: Color) -> void:
	var cen := Vector2.ZERO
	for p in poly:
		cen += p
	cen /= float(poly.size())
	for k in range(poly.size()):
		var a: Vector2 = poly[k]
		var c: Vector2 = poly[(k + 1) % poly.size()]
		var o: Vector2 = ((a + c) * 0.5 - cen).normalized()
		d.quad(Vector3(a.x, y0, a.y), Vector3(c.x, y0, c.y), Vector3(c.x, y1, c.y), Vector3(a.x, y1, a.y), Vector3(o.x, 0, o.y), col, 0.5)
	for k in range(poly.size()):
		var a: Vector2 = poly[k]
		var c: Vector2 = poly[(k + 1) % poly.size()]
		d.tri(Vector3(cen.x, y1, cen.y), Vector3(a.x, y1, a.y), Vector3(c.x, y1, c.y), Vector3.UP, col, Vector2(cen.x, cen.y), Vector2(a.x, a.y), Vector2(c.x, c.y))


const WALL_PAINTS := [
	Color(0.86, 0.80, 0.68), Color(0.80, 0.72, 0.60), Color(0.92, 0.90, 0.84), Color(0.76, 0.56, 0.42),
	Color(0.66, 0.70, 0.72), Color(0.88, 0.74, 0.50), Color(0.72, 0.62, 0.55), Color(0.62, 0.66, 0.58),
	Color(0.90, 0.84, 0.74), Color(0.70, 0.48, 0.38),
]


func _city_cell_builder(cells: Dictionary, p: Vector2) -> Builder:
	var key := Vector2i(floori(p.x / CITY_CELL), floori(p.y / CITY_CELL))
	if not cells.has(key):
		cells[key] = Builder.new()
	return cells[key]


func _add_rooftop(b: Builder, r: Rect2, top: float, rng: RandomNumberGenerator) -> void:
	# Black water tanks and a stair housing on most roofs.
	if rng.randf() < 0.7:
		var n: int = rng.randi_range(1, 3)
		for k in range(n):
			var tx: float = rng.randf_range(r.position.x + 2.0, r.end.x - 2.0)
			var tz: float = rng.randf_range(r.position.y + 2.0, r.end.y - 2.0)
			b.box(Vector3(tx, top + 1.3, tz), Vector3(2.2, 2.6, 2.2), rng.randf() * PI, Color(0.08, 0.08, 0.09, A_PLAIN))
	if rng.randf() < 0.5 and r.size.x > 10.0 and r.size.y > 10.0:
		var c: Vector2 = r.get_center()
		b.box(Vector3(c.x, top + 1.8, c.y), Vector3(4.0, 3.6, 5.0), 0.0, Color(0.70, 0.68, 0.64, A_PLAIN))


func _build_city(parent: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7171
	var cells := {}
	var detail_cells := {}
	var mat := ShaderMaterial.new()
	mat.shader = load("res://city_building.gdshader")
	mat.set_shader_parameter("concrete_tex", load("res://materials/concrete.png"))
	# What the windows reflect: the sky's colours (see the sky in _build_environment).
	mat.set_shader_parameter("refl_top", Color(0.07, 0.27, 0.68))
	mat.set_shader_parameter("refl_horizon", Color(0.72, 0.84, 0.94))
	mat.set_shader_parameter("refl_ground", Color(0.42, 0.40, 0.37))
	mat.set_shader_parameter("refl_cloud", Color(1.0, 0.98, 0.95))
	var count := 0
	var ix0: int = int(floor((-CITY_RADIUS - STREET_X0) / BLOCK_X))
	var ix1: int = int(ceil((CITY_RADIUS - STREET_X0) / BLOCK_X))
	var jz0: int = int(floor((-CITY_RADIUS - STREET_Z0) / BLOCK_Z))
	var jz1: int = int(ceil((CITY_RADIUS - STREET_Z0) / BLOCK_Z))
	var inset: float = CITY_STREET_HALF + PAVEMENT + 1.0
	for i in range(ix0, ix1):
		for j in range(jz0, jz1):
			var bx0: float = STREET_X0 + float(i) * BLOCK_X + inset
			var bx1: float = STREET_X0 + float(i + 1) * BLOCK_X - inset
			var bz0: float = STREET_Z0 + float(j) * BLOCK_Z + inset
			var bz1: float = STREET_Z0 + float(j + 1) * BLOCK_Z - inset
			var blk := Rect2(bx0, bz0, bx1 - bx0, bz1 - bz0)
			if blk.intersects(PRECINCT.grow(-1.0)):
				continue
			var c: Vector2 = blk.get_center()
			var r: float = c.length()
			if r > CITY_RADIUS:
				continue
			# Thinner toward the edge of town.
			if r > 1100.0 and rng.randf() < (r - 1100.0) / 1200.0:
				continue
			var cbd_d: float = c.distance_to(CBD)
			var nx: int = rng.randi_range(1, 3)
			var nz: int = rng.randi_range(1, 2)
			for a in range(nx):
				for bb in range(nz):
					var lx0: float = lerpf(bx0, bx1, float(a) / float(nx))
					var lx1: float = lerpf(bx0, bx1, float(a + 1) / float(nx))
					var lz0: float = lerpf(bz0, bz1, float(bb) / float(nz))
					var lz1: float = lerpf(bz0, bz1, float(bb + 1) / float(nz))
					# Set back from the pavement a little, more on the inner sides.
					var fx0: float = lx0 + (0.0 if a == 0 else rng.randf_range(1.0, 4.0))
					var fx1: float = lx1 - (0.0 if a == nx - 1 else rng.randf_range(1.0, 4.0))
					var fz0: float = lz0 + (0.0 if bb == 0 else rng.randf_range(1.0, 4.0))
					var fz1: float = lz1 - (0.0 if bb == nz - 1 else rng.randf_range(1.0, 4.0))
					var fp := Rect2(fx0, fz0, fx1 - fx0, fz1 - fz0)
					var lot_fp := fp
					var storeys: int
					var glass := 0.0
					if cbd_d < 380.0:
						storeys = rng.randi_range(8, 30) if rng.randf() < 0.7 else rng.randi_range(4, 10)
						glass = 1.0 if rng.randf() < 0.55 else 0.0
						# Towers stand back from the street on a podium.
						if storeys > 14:
							fp = fp.grow(-rng.randf_range(3.0, 7.0))
					elif cbd_d < 750.0:
						storeys = rng.randi_range(4, 12)
						glass = 1.0 if rng.randf() < 0.2 else 0.0
					else:
						storeys = rng.randi_range(1, 6)
					var top: float = STREET_Y + 6.0 + float(storeys) * 4.6
					var col: Color = WALL_PAINTS[rng.randi() % WALL_PAINTS.size()]
					# Facade kind in alpha (city_building.gdshader): glass tower, or a block whose
					# roof is concrete (tall) or painted iron (low).
					col.a = 1.0 if glass > 0.5 else (0.25 if storeys <= 3 else 0.0)
					var b: Builder = _city_cell_builder(cells, c)
					var db: Builder = _city_cell_builder(detail_cells, c)
					# The detail is by distance from the lap: all of it near, the massing and cornices at
					# middle distance, a plain box beyond. Its own random stream keeps the layout where it was.
					var lap_d: float = _lap_distance(fp.get_center(), CITY_DETAIL_MID)
					var detail: int = 2 if lap_d < CITY_DETAIL_NEAR else (1 if lap_d < CITY_DETAIL_MID else 0)
					var drng := RandomNumberGenerator.new()
					drng.seed = hash(Vector2i(roundi(fp.position.x * 4.0), roundi(fp.position.y * 4.0)))
					_building_massed(b, db, lot_fp, fp, top, storeys, col, blk, detail, drng)
					if glass < 0.5:
						# The old rooftop's draws are still taken, so the layout of what comes after is the same.
						var burn := Builder.new()
						_add_rooftop(burn, fp, top, rng)
						if detail == 0:
							_add_rooftop(db, fp, top, drng)
					count += 1
	_build_inner_block(cells, detail_cells, rng)
	var root := Node3D.new()
	root.name = "City"
	parent.add_child(root)
	var shell_tris := 0
	var detail_tris := 0
	for key in cells:
		var b2: Builder = cells[key]
		var mi := MeshInstance3D.new()
		mi.name = "Blocks_%d_%d" % [key.x, key.y]
		mi.mesh = b2.commit()
		mi.material_override = mat
		var centre := Vector2((float(key.x) + 0.5) * CITY_CELL, (float(key.y) + 0.5) * CITY_CELL)
		# Only the buildings near the lap throw shadows the cameras can see.
		if centre.length() > 700.0:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		shell_tris += b2.verts.size() / 3
	# The small parts: no shadow, and out of sight beyond CITY_DETAIL_RANGE.
	for key in detail_cells:
		var b3: Builder = detail_cells[key]
		if b3.is_empty():
			continue
		var mi2 := MeshInstance3D.new()
		mi2.name = "BlockDetail_%d_%d" % [key.x, key.y]
		mi2.mesh = b3.commit()
		mi2.material_override = mat
		mi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi2.visibility_range_end = CITY_DETAIL_RANGE
		mi2.visibility_range_end_margin = 30.0
		root.add_child(mi2)
		detail_tris += b3.verts.size() / 3
	print("  city: %d buildings in %d cells (%d triangles, %d in the detail)" % [count, cells.size(), shell_tris, detail_tris])


## The block inside the lap's streets, between Soko Street and the avenue: shops on every side,
## kept clear of the barriers.
func _build_inner_block(cells: Dictionary, detail_cells: Dictionary, rng: RandomNumberGenerator) -> void:
	var lots := [
		Rect2(250.0, 66.0, 26.0, 30.0), Rect2(280.0, 66.0, 24.0, 22.0), Rect2(250.0, 100.0, 22.0, 34.0),
		Rect2(276.0, 92.0, 28.0, 40.0), Rect2(250.0, 138.0, 30.0, 20.0), Rect2(284.0, 136.0, 20.0, 30.0),
	]
	for lot in lots:
		var fp: Rect2 = lot
		var ok := true
		for c in [fp.position, fp.end, Vector2(fp.position.x, fp.end.y), Vector2(fp.end.x, fp.position.y), fp.get_center()]:
			if _lap_distance(c, 40.0) < STREET_HALF + 7.0:
				ok = false
		if not ok:
			continue
		var col: Color = WALL_PAINTS[rng.randi() % WALL_PAINTS.size()]
		col.a = 0.25
		var storeys: int = rng.randi_range(1, 4)
		var top: float = STREET_Y + 6.0 + float(storeys) * 4.6
		var b: Builder = _city_cell_builder(cells, fp.get_center())
		var db: Builder = _city_cell_builder(detail_cells, fp.get_center())
		var drng := RandomNumberGenerator.new()
		drng.seed = hash(Vector2i(roundi(fp.position.x * 4.0), roundi(fp.position.y * 4.0)))
		_building_massed(b, db, fp, fp, top, storeys, col, fp, 2, drng)
		var burn := Builder.new()
		_add_rooftop(burn, fp, top, rng)


## Hills on the horizon: a ring of ridges past the end of town, highest to the south-west.
func _build_hills(parent: Node) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 3131
	noise.frequency = 0.0009
	var segs := 160
	var rings := [2500.0, 3100.0, 3800.0, 4600.0, 5600.0]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array = []
	for ri in range(rings.size()):
		var row: Array = []
		for k in range(segs):
			var a: float = TAU * float(k) / float(segs)
			var rad: float = rings[ri]
			var p := Vector2(cos(a), sin(a)) * rad
			# Ngong-like knuckles to the south-west (around 150 degrees), gentle ridges elsewhere.
			var sw: float = exp(-pow(wrapf(a - deg_to_rad(150.0), -PI, PI) / 0.35, 2.0))
			var knuckles: float = absf(sin(a * 22.0)) * 0.5 + 0.5
			var h: float = (90.0 + noise.get_noise_2d(p.x, p.y) * 120.0) + sw * 520.0 * knuckles
			var t: float = float(ri) / float(rings.size() - 1)
			var y: float = STREET_Y - 2.0 + h * sin(t * PI * 0.9) if ri > 0 else STREET_Y - 2.0
			var green: float = clampf(0.5 + noise.get_noise_2d(p.x * 2.0, p.y * 2.0), 0.0, 1.0)
			var col := Color(0.30, 0.36, 0.24).lerp(Color(0.44, 0.42, 0.32), green)
			row.append([Vector3(p.x, y, p.y), col])
		grid.append(row)
	for ri in range(rings.size() - 1):
		for k in range(segs):
			var k2: int = (k + 1) % segs
			var quad := [grid[ri][k], grid[ri][k2], grid[ri + 1][k2], grid[ri + 1][k]]
			var tris := [[0, 1, 2], [0, 2, 3]]
			for t in tris:
				var a: Vector3 = quad[t[0]][0]
				var b: Vector3 = quad[t[1]][0]
				var c: Vector3 = quad[t[2]][0]
				# Faces toward the middle (and up).
				var order: Array = t if (c - a).cross(b - a).dot(-a.normalized() + Vector3.UP * 0.3) >= 0.0 else [t[0], t[2], t[1]]
				for idx in order:
					st.set_color(quad[idx][1])
					st.add_vertex(quad[idx][0])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "HorizonHills"
	mi.mesh = st.commit()
	var m := ShaderMaterial.new()
	m.shader = load("res://distant_mountain.gdshader")
	m.set_shader_parameter("haze_color", HAZE)
	m.set_shader_parameter("haze_base", 0.55)
	m.set_shader_parameter("haze_top", 0.32)
	m.set_shader_parameter("peak_height", 650.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


# ======================================================================================
#  Street trees
# ======================================================================================

## Jacarandas in bloom (twice life size, like everything here) and a green shade tree, built the
## way Mara Crossing builds its acacias: bark tubes (tree_bark.gdshader) under a crown of
## alpha-tested cards (acacia_leaves.gdshader) in pads over a dome. In metres: crown top, crown
## radius, crown underside, fork height, trunk radius; limbs and pads. Variant 2 is the green tree.
const TREE_SHAPES := [
	{"top": 18.0, "r": 10.5, "under": 7.5, "fork": 3.4, "trunk": 0.48, "limbs": 5, "pads": 16, "dome": 4.5},
	{"top": 14.0, "r": 8.0, "under": 6.0, "fork": 2.8, "trunk": 0.38, "limbs": 4, "pads": 11, "dome": 3.8},
	{"top": 16.0, "r": 9.0, "under": 5.5, "fork": 2.6, "trunk": 0.5, "limbs": 4, "pads": 14, "dome": 5.5},
]
const TREE_NEAR := 260.0
const TREE_FADE := 50.0
const TREE_FADE_JITTER := 12.0

var _blossom_tex: Texture2D

## A float RGB + alpha canvas for drawing the leaf texture (members, so drawing edits in place).
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

	## An antialiased dot.
	func dot(c: Vector2, r: float, col: Color) -> void:
		var x0: int = maxi(0, int(c.x - r - 1.0))
		var x1: int = mini(w - 1, int(c.x + r + 1.0))
		var y0: int = maxi(0, int(c.y - r - 1.0))
		var y1: int = mini(w - 1, int(c.y + r + 1.0))
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var a: float = clampf(r + 0.5 - Vector2(x + 0.5, y + 0.5).distance_to(c), 0.0, 1.0)
				if a <= 0.0:
					continue
				var i: int = y * w + x
				var k: float = a if alpha[i] > 0.0 else 1.0
				rgb[i * 3] = lerpf(rgb[i * 3], col.r, k)
				rgb[i * 3 + 1] = lerpf(rgb[i * 3 + 1], col.g, k)
				rgb[i * 3 + 2] = lerpf(rgb[i * 3 + 2], col.b, k)
				alpha[i] = maxf(alpha[i], a)

	## A stroke of dots from `a` to `b`, `r` tapering to `r2`.
	func line(a: Vector2, b: Vector2, r: float, r2: float, col: Color) -> void:
		var n: int = maxi(1, int(a.distance_to(b) / 0.7))
		for k in range(n + 1):
			var t: float = float(k) / float(n)
			dot(a.lerp(b, t), lerpf(r, r2, t), col)



## The crown atlas, 2 x 2: three cells of jacaranda sprays (panicles of lilac trumpet flowers
## among feathery leaves) and one of green leaves for the shade trees. Mipmaps keep coverage.
func _blossom_texture() -> Texture2D:
	if _blossom_tex:
		return _blossom_tex
	const W := 1024
	const CELL := 512
	var cv := LeafCanvas.new(W, Color(0.42, 0.36, 0.55))
	var rng := RandomNumberGenerator.new()
	rng.seed = 6262
	for cell in range(4):
		var centre := Vector2(float(cell % 2) * CELL + CELL * 0.5, float(cell / 2) * CELL + CELL * 0.5)
		var green: bool = cell == 3
		var twigs: int = rng.randi_range(6, 8)
		for t in range(twigs):
			var a: float = TAU * float(t) / float(twigs) + rng.randf_range(-0.3, 0.3)
			var from: Vector2 = centre + Vector2(cos(a), sin(a)) * rng.randf_range(0.0, 40.0)
			_blossom_twig(cv, from, a, rng.randf_range(140.0, 210.0), 2.6, centre, CELL * 0.45, rng, 0, green)
	var img := _coverage_mipmaps(cv, 0.5)
	_blossom_tex = _save_baked_resource(ImageTexture.create_from_image(img), "blossom_cards")
	return _blossom_tex


## One twig of the crown texture: leaflets along it and, on the jacarandas, clusters of
## flowers at its nodes.
func _blossom_twig(cv: LeafCanvas, p: Vector2, ang: float, length: float, width: float, centre: Vector2, limit: float, rng: RandomNumberGenerator, depth: int, green: bool) -> void:
	var twig_col := Color(0.24, 0.20, 0.16)
	var travelled := 0.0
	while travelled < length:
		var seg: float = rng.randf_range(12.0, 20.0)
		var a: float = ang + rng.randf_range(-0.3, 0.3)
		var q: Vector2 = p + Vector2(cos(a), sin(a)) * seg
		if q.distance_to(centre) > limit:
			break
		var w: float = width * (1.0 - travelled / length * 0.6)
		cv.line(p, q, w * 0.5, w * 0.45, twig_col)
		# Feathery leaves: pairs of fine leaflets.
		var leaf_n: int = rng.randi_range(2, 4) if not green else rng.randi_range(4, 7)
		for l in range(leaf_n):
			var la: float = a + (1.0 if l % 2 == 0 else -1.0) * rng.randf_range(0.6, 1.4)
			var ll: float = rng.randf_range(8.0, 16.0)
			var col := Color(0.26, 0.40, 0.18).lerp(Color(0.40, 0.52, 0.22), rng.randf())
			if green:
				col = Color(0.20, 0.38, 0.14).lerp(Color(0.36, 0.50, 0.20), rng.randf())
			var dir := Vector2(cos(la), sin(la))
			var perp := Vector2(-dir.y, dir.x)
			var steps: int = int(ll / 2.0)
			for k in range(1, steps + 1):
				var at: Vector2 = q + dir * (float(k) * 2.0)
				for side in [-1.0, 1.0]:
					cv.dot(at + perp * side * rng.randf_range(1.2, 2.6), rng.randf_range(1.0, 2.0), col * rng.randf_range(0.88, 1.12))
		if not green:
			# A panicle: a loose cone of trumpet flowers, lilac to violet, paler at the throat.
			var fl_n: int = rng.randi_range(9, 16)
			var fa: float = a + rng.randf_range(-0.8, 0.8)
			for f in range(fl_n):
				var along: float = rng.randf_range(0.0, 22.0)
				var spread: float = (22.0 - along) * 0.45
				var fp: Vector2 = q + Vector2(cos(fa), sin(fa)) * along + Vector2(-sin(fa), cos(fa)) * rng.randf_range(-spread, spread)
				var col2 := Color(0.52, 0.40, 0.82).lerp(Color(0.66, 0.54, 0.90), rng.randf()).lerp(Color(0.44, 0.30, 0.70), rng.randf() * 0.5)
				var r: float = rng.randf_range(2.6, 4.2)
				cv.dot(fp, r, col2)
				cv.dot(fp + Vector2(0.6, -0.6), r * 0.45, col2.lerp(Color(0.86, 0.80, 0.96), 0.6))
		if depth < 2 and rng.randf() < 0.4:
			var side3: float = 1.0 if rng.randf() < 0.5 else -1.0
			_blossom_twig(cv, q, a + side3 * rng.randf_range(0.5, 1.0), length * 0.45, width * 0.65, centre, limit, rng, depth + 1, green)
		p = q
		travelled += seg


## Mipmapped RGBA8 image of the canvas whose every mip keeps level 0's coverage at alpha
## `cutoff` (each level's alpha scaled up until as many texels pass the test).
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
		# Next level: a 2 x 2 box, colour weighted by alpha so the leaves don't darken at the edges.
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
		# The scale that brings this level's coverage back to the target.
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



## Branches and crown pads of one street tree, the trunk's foot at the origin (same layout as
## Mara Crossing's _acacia_plan): {"tubes": [[points, radii, order]], "pads": [[centre, radius,
## thickness]]}. The pads sit over a dome rather than a flat table.
func _tree_plan(variant: int) -> Dictionary:
	var sh: Dictionary = TREE_SHAPES[variant]
	var rng := RandomNumberGenerator.new()
	rng.seed = 8101 + variant * 97
	var top: float = sh["top"]
	var cr: float = sh["r"]
	var under: float = sh["under"]
	var fork: float = sh["fork"]
	var r0: float = sh["trunk"]
	var dome: float = sh["dome"]
	var pads: Array = []
	pads.append([Vector3(0.0, 0.0, 0.0), cr * 0.42])
	var tries := 0
	while pads.size() < int(sh["pads"]) and tries < 3000:
		tries += 1
		var a: float = rng.randf() * TAU
		var d: float = cr * lerpf(0.25, 0.78, sqrt(rng.randf()))
		var pr: float = cr * rng.randf_range(0.26, 0.36) * (1.0 - 0.2 * d / cr)
		var c := Vector3(cos(a) * d, 0.0, sin(a) * d)
		var ok := true
		for q in pads:
			var qc: Vector3 = q[0]
			if Vector2(c.x - qc.x, c.z - qc.z).length() < (pr + float(q[1])) * 0.55:
				ok = false
				break
		if ok:
			pads.append([c, pr])
	for q in pads:
		var qc: Vector3 = q[0]
		var d2: float = Vector2(qc.x, qc.z).length() / cr
		var thick: float = lerpf(3.4, 2.2, d2) * sqrt(cr / 10.0) * rng.randf_range(0.85, 1.15)
		var ptop: float = top - d2 * d2 * dome - rng.randf_range(0.0, 0.8)
		qc.y = ptop - thick * 0.5
		q[0] = qc
		q.append(thick)
	var tubes: Array = []
	var fork_p := Vector3(rng.randf_range(-0.2, 0.2), fork, rng.randf_range(-0.2, 0.2))
	tubes.append([[Vector3(0, -0.8, 0), Vector3(0, 0.3, 0), fork_p * 0.55, fork_p], [r0 * 1.45, r0 * 1.15, r0 * 1.0, r0 * 0.88], 0])
	var limbs: Array = []
	var nl: int = sh["limbs"]
	for i in range(nl):
		var a: float = TAU * float(i) / float(nl) + rng.randf_range(-0.35, 0.35)
		var reach: float = cr * rng.randf_range(0.28, 0.45)
		var head := Vector3(cos(a) * reach, under + rng.randf_range(0.5, 2.5), sin(a) * reach)
		var start: Vector3 = fork_p + Vector3(cos(a), 0.0, sin(a)) * r0 * 0.3 - Vector3(0, 0.3, 0)
		var side := Vector3(-sin(a), 0.0, cos(a))
		var pts: Array = [start]
		var radii: Array = [r0 * 0.6]
		for k in range(1, 5):
			var t: float = float(k) / 4.0
			var hp: Vector3 = start + (head - start) * Vector3(pow(t, 1.2), pow(t, 0.75), pow(t, 1.2))
			if k < 4:
				hp += side * rng.randf_range(-0.5, 0.5) + Vector3(0, rng.randf_range(-0.2, 0.2), 0)
			pts.append(hp)
			radii.append(lerpf(r0 * 0.6, r0 * 0.28, t))
		tubes.append([pts, radii, 1])
		limbs.append([pts, a])
	for q in pads:
		var c: Vector3 = q[0]
		var pr: float = q[1]
		var th: float = q[2]
		var pa: float = atan2(c.z, c.x)
		var best: Array = limbs[0]
		var bd := 1e9
		for lb in limbs:
			var dd: float = absf(wrapf(pa - float(lb[1]), -PI, PI))
			if dd < bd:
				bd = dd
				best = lb
		var lpts: Array = best[0]
		var fi: float = rng.randf_range(0.5, 0.85) * float(lpts.size() - 1)
		var i0: int = int(fi)
		var start2: Vector3 = (lpts[i0] as Vector3).lerp(lpts[mini(i0 + 1, lpts.size() - 1)], fi - float(i0))
		var end2: Vector3 = c - Vector3(0, th * 0.3, 0)
		var mid2: Vector3 = start2.lerp(end2, 0.5) + Vector3(rng.randf_range(-0.5, 0.5), 0.6, rng.randf_range(-0.5, 0.5))
		tubes.append([[start2, mid2, end2], [r0 * 0.26, r0 * 0.17, r0 * 0.1], 2])
		var tw: int = rng.randi_range(3, 5)
		for k in range(tw):
			var ta: float = TAU * float(k) / float(tw) + rng.randf_range(-0.4, 0.4)
			var reach2: float = pr * rng.randf_range(0.5, 0.8)
			var tip: Vector3 = end2 + Vector3(cos(ta) * reach2, rng.randf_range(0.2, 0.6) * th, sin(ta) * reach2)
			tubes.append([[end2, end2.lerp(tip, 0.5) + Vector3(0, 0.2, 0), tip], [r0 * 0.09, r0 * 0.06, 0.035], 3])
	return {"tubes": tubes, "pads": pads}


## Appends a bark tube along `pts` (a radius per point) to `st`, as `sides` faces round plus a
## seam column so the UVs can wrap (tree_bark.gdshader): UV x round in bark cells of `cell`
## metres, repeating after UV2.x of them; y along in the same cells. Normals come from the
## surface (the trunk's flutes from `wobble` included). Colour `col`, its alpha the shade
## inside the canopy, darkening between heights `shade.x` and `shade.y`. Returns the next
## free vertex index.
func _bark_tube(st: SurfaceTool, base: int, pts: Array, radii: Array, sides: int, col: Color, cell: float, wobble: float, noise: FastNoiseLite, shade: Vector2) -> int:
	var n: int = pts.size()
	var period: float = maxf(3.0, roundf(TAU * float(radii[0]) / cell))
	var grid: Array = []
	var vs := PackedFloat32Array()
	var along := 0.0
	var t0: Vector3 = ((pts[1] as Vector3) - (pts[0] as Vector3)).normalized()
	var u: Vector3 = t0.cross(Vector3.UP if absf(t0.y) < 0.95 else Vector3.RIGHT).normalized()
	for k in range(n):
		var t: Vector3 = ((pts[mini(k + 1, n - 1)] as Vector3) - (pts[maxi(k - 1, 0)] as Vector3)).normalized()
		# Parallel transport: the frame turns with the tube and never twists.
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
		for s in range(sides + 1):
			var si: int = s % sides
			var around: Vector3 = (grid[k][(si + 1) % sides] as Vector3) - (grid[k][(si - 1 + sides) % sides] as Vector3)
			var length_dir: Vector3 = (grid[mini(k + 1, n - 1)][si] as Vector3) - (grid[maxi(k - 1, 0)][si] as Vector3)
			var nrm: Vector3 = around.cross(length_dir).normalized()
			var p: Vector3 = grid[k][s]
			if nrm.dot(p - c) < 0.0:
				nrm = -nrm
			st.set_normal(nrm)
			st.set_color(Color(col.r, col.g, col.b, a_sh))
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


## Foliage cards filling the pads (acacia_leaves.gdshader, shared with Mara Crossing): about one card per `area` square
## metres of pad, `size` metres across (x to y), lying mostly flat with some steep ones so the
## canopy has body seen from the side; more of them near a pad's top. Normals are the crown's,
## colour a tint per pad and the shade inside the canopy.
func _crown_cards(st: SurfaceTool, pads: Array, cr: float, top: float, under: float, area: float, size: Vector2, rng: RandomNumberGenerator, cell_pick: Callable, tint_lo: Color, tint_hi: Color) -> void:
	var crown_c := Vector3(0.0, under + (top - under) * 0.3, 0.0)
	var crown_h: float = (top - under) * 1.3
	var base := 0
	for q in pads:
		var c: Vector3 = q[0]
		var pr: float = q[1]
		var th: float = q[2]
		var tint: Color = tint_lo.lerp(tint_hi, rng.randf())
		var n: int = maxi(2, int(PI * pr * pr / area))
		for k in range(n):
			var a: float = rng.randf() * TAU
			var rr: float = pr * sqrt(rng.randf()) * 0.9
			var up: float = rng.randf()
			var p := Vector3(c.x + cos(a) * rr, c.y + th * (0.5 - up * up), c.z + sin(a) * rr)
			var tilt: float = rng.randf_range(0.0, 0.45) if rng.randf() < 0.7 else rng.randf_range(0.75, 1.3)
			var az: float = rng.randf() * TAU
			var nrm := Vector3(sin(tilt) * cos(az), cos(tilt), sin(tilt) * sin(az))
			var t1: Vector3 = nrm.cross(Vector3.RIGHT if absf(nrm.x) < 0.9 else Vector3.FORWARD).normalized()
			t1 = t1.rotated(nrm, rng.randf() * TAU)
			var t2: Vector3 = nrm.cross(t1)
			var h: float = rng.randf_range(size.x, size.y) * 0.5
			var corners: Array = [p - t1 * h - t2 * h, p + t1 * h - t2 * h, p + t1 * h + t2 * h, p - t1 * h + t2 * h]
			var cell: Vector2 = cell_pick.call(rng)
			var uvs: Array = [cell, cell + Vector2(0.5, 0.0), cell + Vector2(0.5, 0.5), cell + Vector2(0.0, 0.5)]
			var bright: float = rng.randf_range(0.93, 1.07)
			for j in range(4):
				var v: Vector3 = corners[j]
				var cn := Vector3((v.x - crown_c.x) / cr, (v.y - crown_c.y) / crown_h, (v.z - crown_c.z) / cr).normalized()
				var shade: float = clampf(0.3 + 0.7 * smoothstep(under - 0.5, top - 0.3, v.y), 0.25, 1.0)
				shade *= lerpf(0.8, 1.0, clampf(Vector2(v.x, v.z).length() / cr, 0.0, 1.0))
				st.set_normal((cn + Vector3.UP * 0.6).normalized())
				st.set_color(Color(tint.r * bright, tint.g * bright, tint.b * bright, shade))
				st.set_uv(uvs[j])
				st.add_vertex(v)
			for idx in [0, 1, 2, 0, 2, 3]:
				st.add_index(base + idx)
			base += 4



## A street tree's mesh: surface 0 the bark, 1 the crown. `lod` 1 is the far stand-in.
func _tree_mesh(variant: int, lod: int, bark_mat: Material, leaf_mat: Material) -> ArrayMesh:
	var sh: Dictionary = TREE_SHAPES[variant]
	var plan: Dictionary = _tree_plan(variant)
	var noise := FastNoiseLite.new()
	noise.seed = 51 + variant
	noise.frequency = 0.5
	var under: float = sh["under"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides: Array = [10, 7, 5, 3] if lod == 0 else [5, 4, 0, 0]
	var tints: Array = [Color(0.62, 0.58, 0.56), Color(0.66, 0.60, 0.56), Color(0.70, 0.62, 0.56), Color(0.74, 0.64, 0.56)]
	var base := 0
	for tb in plan["tubes"]:
		var order: int = tb[2]
		if sides[order] == 0:
			continue
		base = _bark_tube(st, base, tb[0], tb[1], sides[order], tints[order], 0.35, 0.06 if order == 0 else 0.0, noise, Vector2(under - 3.0, under + 1.0))
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, bark_mat)
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 313 + variant * 7 + lod * 1000
	var green: bool = variant == 2
	var pick := func(r: RandomNumberGenerator) -> Vector2:
		if green:
			return Vector2(0.5, 0.5)
		var c: int = r.randi() % 3
		return Vector2(float(c % 2), float(c / 2)) * 0.5
	var lo := Color(0.78, 0.78, 0.80) if not green else Color(0.74, 0.78, 0.70)
	var hi := Color(0.86, 0.82, 0.86) if not green else Color(0.82, 0.84, 0.74)
	if lod == 0:
		_crown_cards(st2, plan["pads"], sh["r"], sh["top"], under, 1.4, Vector2(2.2, 3.4), rng, pick, lo, hi)
	else:
		_crown_cards(st2, plan["pads"], sh["r"], sh["top"], under, 6.0, Vector2(4.0, 6.0), rng, pick, lo, hi)
	st2.commit(mesh)
	mesh.surface_set_material(1, leaf_mat)
	return mesh


func _tree_material(lod_mode: int, leaf: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	if leaf:
		m.shader = load("res://acacia_leaves.gdshader")
		m.set_shader_parameter("leaf_tex", _blossom_texture())
		m.set_shader_parameter("backlight_color", Color(0.62, 0.50, 0.80))
		m.set_shader_parameter("sway_height", 18.0)
	else:
		m.shader = load("res://tree_bark.gdshader")
		m.set_shader_parameter("bark_color", Color(0.34, 0.30, 0.28))
	m.set_shader_parameter("lod_mode", lod_mode)
	m.set_shader_parameter("lod_fade_begin", TREE_NEAR - TREE_FADE * 0.5)
	m.set_shader_parameter("lod_fade_end", TREE_NEAR + TREE_FADE * 0.5)
	m.set_shader_parameter("lod_jitter", TREE_FADE_JITTER)
	return m


## Trees along the pavements of the streets near the stadium and round its plazas, and behind
## the lap's barriers; never within reach of the road.
func _build_street_trees(parent: Node) -> void:
	var root := Node3D.new()
	root.name = "StreetTrees"
	parent.add_child(root)
	var bark_near := _tree_material(1, false)
	var bark_far := _tree_material(2, false)
	var leaf_near := _tree_material(1, true)
	var leaf_far := _tree_material(2, true)
	var near_meshes: Array = []
	var far_meshes: Array = []
	for v in range(TREE_SHAPES.size()):
		near_meshes.append(_save_baked_resource(_tree_mesh(v, 0, bark_near, leaf_near), "tree_%d" % v))
		far_meshes.append(_save_baked_resource(_tree_mesh(v, 1, bark_far, leaf_far), "tree_far_%d" % v))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5353
	var spots: Array = []
	# The grid streets: both pavements, out to 700m.
	var lim := 560.0
	var line_off: float = CITY_STREET_HALF + 2.6
	for i in range(-9, 4):
		var sx: float = STREET_X0 + float(i) * BLOCK_X
		var z: float = -lim
		while z < lim:
			for side in [-1.0, 1.0]:
				spots.append(Vector2(sx + side * line_off, z + rng.randf_range(-3.0, 3.0)))
			z += rng.randf_range(24.0, 34.0)
	for j in range(-10, 6):
		var sz: float = STREET_Z0 + float(j) * BLOCK_Z
		var x: float = -lim
		while x < lim:
			for side in [-1.0, 1.0]:
				spots.append(Vector2(x + rng.randf_range(-3.0, 3.0), sz + side * line_off))
			x += rng.randf_range(24.0, 34.0)
	var street_spots: int = spots.size()
	# Rows round the stadium's plazas and the fan zone.
	for k in range(-9, 10):
		spots.append(Vector2(float(k) * 22.0, -168.0))
		spots.append(Vector2(float(k) * 22.0, 168.0))
	for k in range(-6, 7):
		spots.append(Vector2(-214.0, float(k) * 24.0))
	for k in range(4):
		spots.append(Vector2(222.0 + float(k) * 26.0, -30.0))
		spots.append(Vector2(222.0 + float(k) * 26.0, 30.0))
	var count := 0
	var near := {}
	var far := {}
	for si in range(spots.size()):
		var pv: Vector2 = spots[si]
		if pv.length() > lim + 100.0:
			continue
		# Grid-street rows stop at the precinct, which has no grid streets.
		if si < street_spots and PRECINCT.grow(-2.0).has_point(pv):
			continue
		# Off the streets, clear of the lap's barriers, the stands and the cutting.
		if _lap_distance(pv, 30.0) < 13.0:
			continue
		if _in_stadium_footprint(pv, 6.0):
			continue
		if rng.randf() < 0.12:
			continue
		var pick: float = rng.randf()
		var v: int = 0 if pick < 0.45 else (1 if pick < 0.75 else 2)
		# Pavement trees are smaller, their crowns clear of the facades.
		var s: float = rng.randf_range(0.7, 0.9) if si < street_spots else rng.randf_range(0.9, 1.12)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.92, 1.08), s)), Vector3(pv.x, STREET_Y, pv.y))
		var key := Vector3i(floori(pv.x / 160.0), floori(pv.y / 160.0), v)
		if not near.has(key):
			near[key] = []
		near[key].append(xf)
		var fk := Vector3i(floori(pv.x / 400.0), floori(pv.y / 400.0), v)
		if not far.has(fk):
			far[fk] = []
		far[fk].append(xf)
		count += 1
	for k in near.keys():
		var mmi := _multimesh(near_meshes[k.z], near[k], "Tree_%d_%d_%d" % [k.x, k.y, k.z])
		mmi.visibility_range_end = TREE_NEAR + TREE_FADE * 0.5 + TREE_FADE_JITTER + 160.0 * 0.72
		mmi.visibility_range_end_margin = 10.0
		root.add_child(mmi)
	for k in far.keys():
		var mmi2 := _multimesh(far_meshes[k.z], far[k], "TreeFar_%d_%d_%d" % [k.x, k.y, k.z])
		mmi2.visibility_range_begin = maxf(0.0, TREE_NEAR - TREE_FADE * 0.5 - TREE_FADE_JITTER - 400.0 * 0.72)
		mmi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi2)
	print("  street trees: %d" % count)


## Inside the bowl or the stands (grown by `margin`), or in the exit cutting.
func _in_stadium_footprint(p: Vector2, margin: float) -> bool:
	if absf(p.x) < ARENA_X + margin and absf(p.y) < ARENA_Z + margin:
		return true
	for st in STANDS:
		var sec: Dictionary = _stand_section(st[4])
		var half: float = st[3]
		var p0: Vector3 = _stand_point(st, -half, 0.0, 0.0)
		var p1: Vector3 = _stand_point(st, half, float(sec["depth"]) + 2.0, 0.0)
		var r := Rect2(Vector2(minf(p0.x, p1.x), minf(p0.z, p1.z)), Vector2(absf(p1.x - p0.x), absf(p1.z - p0.z))).grow(margin)
		if r.has_point(p):
			return true
	return false


# ======================================================================================
#  Precinct dressing
# ======================================================================================

## The stands' street faces: concrete fins, dark concourse openings, gates at street level and the
## stadium's name over the gates.
func _build_facades(parent: Node, concrete: Material) -> void:
	var b := Builder.new()
	var signs := Builder.new()
	var fin_col := Color(0.86, 0.84, 0.80)
	var dark := Color(0.16, 0.16, 0.17)
	var canopy := Color(0.93, 0.42, 0.07)
	for st in STANDS:
		var upper: bool = st[4]
		var half: float = st[3]
		var sec: Dictionary = _stand_section(upper)
		var depth: float = sec["depth"]
		var top: float = sec["top"]
		var out2: Vector2 = st[2]
		var out3 := Vector3(out2.x, 0.0, out2.y)
		var yaw: float = 0.0 if absf(out2.y) > 0.5 else PI * 0.5
		# Dark bands where the concourses open to the street, behind the fins.
		var bands := [[STREET_Y + 0.0, STREET_Y + 5.5], [top - 9.0, top - 5.0]]
		for bd in bands:
			var c: Vector3 = _stand_point(st, 0.0, depth + 0.05, (bd[0] + bd[1]) * 0.5)
			b.box(c, Vector3(2.0 * half - 2.0, bd[1] - bd[0], 0.1) if yaw == 0.0 else Vector3(0.1, bd[1] - bd[0], 2.0 * half - 2.0), 0.0, dark)
		# Fins every 8m, full height.
		var n: int = int(2.0 * half / 8.0)
		for i in range(n + 1):
			var a: float = -half + 2.0 * half * float(i) / float(n)
			var c2: Vector3 = _stand_point(st, a, depth + 0.7, (STREET_Y - 0.3 + top + 0.4) * 0.5)
			b.box(c2, Vector3(1.0, top + 0.7 - STREET_Y, 1.4), yaw, fin_col)
		# A slab over the street-level openings, and gate canopies.
		var slab: Vector3 = _stand_point(st, 0.0, depth + 1.4, STREET_Y + 5.9)
		b.box(slab, Vector3(2.0 * half, 0.6, 2.8) if yaw == 0.0 else Vector3(2.8, 0.6, 2.0 * half), 0.0, fin_col * 0.95)
		var gates: int = 4 if upper else 2
		for g in range(gates):
			var ga: float = -half * 0.75 + 1.5 * half * (float(g) + 0.5) / float(gates)
			var gc: Vector3 = _stand_point(st, ga, depth + 3.2, STREET_Y + 4.2)
			b.box(gc, Vector3(9.0, 0.35, 4.0) if yaw == 0.0 else Vector3(4.0, 0.35, 9.0), 0.0, canopy)
		# The stadium's name over the street.
		var sp: Vector3 = _stand_point(st, 0.0, depth + 1.5, STREET_Y + 7.0)
		_sign(signs, sp, 32.0 if upper else 22.0, 4.0 if upper else 2.75, out3, 1, false)
		# Banners on the end walls, over the corner yards.
		var along3 := Vector3(-out2.y, 0.0, out2.x)
		var k := 0
		for side in [-1.0, 1.0]:
			var ep: Vector3 = _stand_point(st, side * (half + 0.08), depth * 0.62, STREET_Y + 8.0)
			_sign(signs, ep, 24.0, 3.0, along3 * side, [9, 4, 12, 7, 2, 10, 15, 11][(int(out2.x * 3.0 + out2.y * 5.0 + 8.0) + k) % 8], false)
			k += 1
	var mi := MeshInstance3D.new()
	mi.name = "StandFacades"
	mi.mesh = _save_baked_resource(b.commit(), "facades")
	mi.material_override = concrete
	parent.add_child(mi)
	var sm := MeshInstance3D.new()
	sm.name = "FacadeSigns"
	sm.mesh = signs.commit()
	sm.material_override = _ads_material
	parent.add_child(sm)


## Matatus, the minibuses of Nairobi, parked in the east plaza and the car park north of the exit.
## MatatuKit builds each livery once at life size, scaled by MATATU_SCALE like everything else here
## (twice life size); the same mesh serves every van in that livery. `spots` are [position, yaw,
## livery index]: the nose points along -z turned by yaw. A van within MATATU_SOLID of the lap gets a
## box collider; the rest are scenery.
const MATATU_SCALE := 2.0
const MATATU_SOLID := 15.0
const MATATU_LENGTH := 5.4
const MATATU_WIDTH := 1.95
const MATATU_HEIGHT := 2.4


var _vehicle_mats := {}


## A PropKit at MATATU_SCALE whose materials are MatatuKit's, saved once and shared by the matatus and the food
## trucks (which are built on the same kit).
func _vehicle_kit() -> PropKit:
	var kit := PropKit.new()
	kit.material_for = func(key: String) -> Material:
		if not _vehicle_mats.has(key):
			_vehicle_mats[key] = _save_shared_resource(MatatuKit.make_material(key), "matatu_" + key)
		return _vehicle_mats[key]
	kit.set_frame(Transform3D(Basis().scaled(Vector3.ONE * MATATU_SCALE), Vector3.ZERO))
	return kit


## The food trucks of the fan zone (FoodTruckKit, three liveries): `spots` are [position, yaw, truck index].
func _build_food_trucks(parent: Node, spots: Array) -> void:
	var root := Node3D.new()
	root.name = "FoodTrucks"
	parent.add_child(root)
	var kit := _vehicle_kit()
	var tris := 0
	for k in range(spots.size()):
		var sp: Array = spots[k]
		var ti: int = sp[2]
		var mesh: ArrayMesh = FoodTruckKit.new(kit).build_truck(FoodTruckKit.TRUCKS[ti])
		for si in range(mesh.get_surface_count()):
			tris += (mesh.surface_get_arrays(si)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		var mi := MeshInstance3D.new()
		mi.name = "FoodTruck_%d" % k
		mi.mesh = _save_shared_resource(mesh, "foodtruck_%d" % ti)
		mi.transform = Transform3D(Basis(Vector3.UP, float(sp[1])), sp[0])
		mi.visibility_range_end = 420.0
		mi.visibility_range_end_margin = 30.0
		root.add_child(mi)
		var lap_d: float = _matatu_lap_distance(sp[0], float(sp[1]))
		if lap_d < STREET_HALF + 1.5:
			push_error("FoodTruck_%d stands %.1fm from the lap's centre line" % [k, lap_d])
	print("  food trucks: %d (%d triangles)" % [spots.size(), tris])


func _build_matatus(parent: Node, spots: Array) -> void:
	var root := Node3D.new()
	root.name = "Matatus"
	parent.add_child(root)
	var kit := _vehicle_kit()
	var meshes := {}
	var solid := 0
	var tris := 0
	var closest := MATATU_SOLID
	for k in range(spots.size()):
		var sp: Array = spots[k]
		var pos: Vector3 = sp[0]
		var yaw: float = sp[1]
		var li: int = sp[2]
		if not meshes.has(li):
			var mesh: ArrayMesh = MatatuKit.new(kit).build(MatatuKit.LIVERIES[li])
			for si in range(mesh.get_surface_count()):
				tris += (mesh.surface_get_arrays(si)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			meshes[li] = _save_shared_resource(mesh, "matatu_%d" % li)
		var mi := MeshInstance3D.new()
		mi.name = "Matatu_%d" % k
		mi.mesh = meshes[li]
		mi.transform = Transform3D(Basis(Vector3.UP, yaw), pos)
		mi.visibility_range_end = 420.0
		mi.visibility_range_end_margin = 30.0
		root.add_child(mi)
		var lap_d: float = _matatu_lap_distance(pos, yaw)
		closest = minf(closest, lap_d)
		if lap_d < STREET_HALF + 1.5:
			push_error("Matatu_%d stands %.1fm from the lap's centre line; the road is %.0fm wide each side" % [k, lap_d, STREET_HALF])
		if lap_d < MATATU_SOLID:
			var body := StaticBody3D.new()
			body.name = "MatatuBody_%d" % k
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(MATATU_WIDTH, MATATU_HEIGHT - 0.25, MATATU_LENGTH) * MATATU_SCALE
			cs.shape = box
			cs.position = Vector3(0.0, (0.25 + MATATU_HEIGHT) * 0.5 * MATATU_SCALE, 0.0)
			body.add_child(cs)
			body.transform = Transform3D(Basis(Vector3.UP, yaw), pos)
			root.add_child(body)
			solid += 1
	print("  matatus: %d vans, %d liveries (%d triangles), %d solid, closest %.1fm to the lap" % [spots.size(), meshes.size(), tris, solid, closest])


## The nearest the lap's centre line comes to a van's footprint (corners and edge midpoints).
func _matatu_lap_distance(pos: Vector3, yaw: float) -> float:
	var basis := Basis(Vector3.UP, yaw)
	var best := MATATU_SOLID
	for ix in [-1.0, 0.0, 1.0]:
		for iz in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			var q: Vector3 = pos + basis * Vector3(float(ix) * MATATU_WIDTH * 0.5, 0.0, float(iz) * MATATU_LENGTH * 0.5) * MATATU_SCALE
			best = minf(best, _lap_distance(Vector2(q.x, q.z), MATATU_SOLID))
	return best


## A gazebo tent: four legs and a pyramid roof.
func _tent(b: Builder, pos: Vector3, size: float, col: Color) -> void:
	var h := 4.6
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			b.box(pos + Vector3(sx * size * 0.47, h * 0.5, sz * size * 0.47), Vector3(0.18, h, 0.18), 0.0, Color(0.85, 0.85, 0.85))
	var apex: Vector3 = pos + Vector3(0, h + 2.2, 0)
	var c := [pos + Vector3(-size * 0.5, h, -size * 0.5), pos + Vector3(size * 0.5, h, -size * 0.5), pos + Vector3(size * 0.5, h, size * 0.5), pos + Vector3(-size * 0.5, h, size * 0.5)]
	for k in range(4):
		var a: Vector3 = c[k]
		var d: Vector3 = c[(k + 1) % 4]
		var mid: Vector3 = (a + d) * 0.5
		var out3: Vector3 = (mid - pos).normalized() + Vector3.UP
		b.tri(a, d, apex, out3, col if k % 2 == 0 else col * 0.92)
		b.tri(a, apex, d, -out3, col * 0.7)
	# A valance round the roof edge.
	for k in range(4):
		var a2: Vector3 = c[k]
		var d2: Vector3 = c[(k + 1) % 4]
		var out4: Vector3 = ((a2 + d2) * 0.5 - pos)
		out4.y = 0.0
		b.quad(a2, d2, d2 - Vector3(0, 0.6, 0), a2 - Vector3(0, 0.6, 0), out4.normalized(), Color(0.95, 0.95, 0.93))


const STALL_SCALE := 2.0
var _stall_mats := {}


## The market stalls of Soko Street (MarketStallKit, six trades, a few colourways): `spots` are
## [position, yaw, kind, variant], the front toward +z of the stall's own frame. Built at STALL_SCALE like
## everything else here (twice life size); the same mesh serves every stall of a trade and colourway.
func _build_market_stalls(parent: Node, spots: Array) -> void:
	var root := Node3D.new()
	root.name = "MarketStalls"
	parent.add_child(root)
	var kit := PropKit.new()
	kit.material_for = func(key: String) -> Material:
		if not _stall_mats.has(key):
			_stall_mats[key] = _save_shared_resource(MarketStallKit.make_stall_material(key), "stall_" + key)
		return _stall_mats[key]
	kit.set_frame(Transform3D(Basis().scaled(Vector3.ONE * STALL_SCALE), Vector3.ZERO))
	var meshes := {}
	var tris := 0
	for k in range(spots.size()):
		var sp: Array = spots[k]
		var key := "%d_%d" % [sp[2], sp[3]]
		if not meshes.has(key):
			var mesh: ArrayMesh = MarketStallKit.new(kit).build_stall(int(sp[2]), int(sp[3]))
			for si in range(mesh.get_surface_count()):
				tris += (mesh.surface_get_arrays(si)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			meshes[key] = _save_shared_resource(mesh, "stall_%s" % key)
		var mi := MeshInstance3D.new()
		mi.name = "Stall_%d" % k
		mi.mesh = meshes[key]
		mi.transform = Transform3D(Basis(Vector3.UP, float(sp[1])), sp[0])
		mi.visibility_range_end = 380.0
		mi.visibility_range_end_margin = 20.0
		root.add_child(mi)
	print("  market stalls: %d (%d meshes, %d triangles), the first at (%.0f, %.0f)" % [spots.size(), meshes.size(), tris, (spots[0][0] as Vector3).x, (spots[0][0] as Vector3).z])


## Everything round the stadium at street level: the fan zone in the east plaza (tents, food
## trucks, matatus, flags), the market stalls along Soko Street, TV trucks in the corner yards,
## and streetlights along the lap. Returns standing-crowd spots for _build_crowd.
func _build_precinct_dressing(parent: Node) -> Array:
	var b := Builder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1212
	var people: Array = []
	var tarps := [Color(0.12, 0.30, 0.62), Color(0.93, 0.42, 0.07), Color(0.10, 0.45, 0.22), Color(0.78, 0.12, 0.12), Color(0.95, 0.75, 0.12)]
	# Fan zone: rows of tents with people milling between them.
	for i in range(4):
		for j in range(2):
			var tp := Vector3(222.0 + float(i) * 22.0, STREET_Y, -14.0 + float(j) * 28.0)
			_tent(b, tp, 8.0, tarps[(i + j) % tarps.size()])
			for k in range(10):
				var pp := tp + Vector3(rng.randf_range(-7.0, 7.0), 0, rng.randf_range(-7.0, 7.0))
				people.append([pp, Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() + Vector3(0.001, 0, 0), 0, 0, true])
	# Food trucks along the plaza's north edge, their serving hatches toward the fan zone (+z).
	var truck_spots: Array = []
	for k in range(3):
		truck_spots.append([Vector3(235.0 + float(k) * 26.0, STREET_Y, -33.0), -PI * 0.5, k])
	_build_food_trucks(parent, truck_spots)
	# Matatus parked nose to tail (nose to the stadium) along the plaza's south edge, and a car park of
	# them north of the exit.
	var matatu_spots: Array = []
	var plaza_liveries := [0, 3, 5, 1, 4, 6]
	for k in range(6):
		matatu_spots.append([Vector3(220.0 + float(k) * 14.0, STREET_Y, 36.0), PI * 0.5 + rng.randf_range(-0.05, 0.05), plaza_liveries[k]])
	var park_liveries := [2, 7, 4, 0, 6, 1, 3, 5, 7, 2]
	var park_rng := RandomNumberGenerator.new()
	park_rng.seed = 4242
	for k in range(10):
		matatu_spots.append([Vector3(214.0 + float(k % 5) * 18.0, STREET_Y, -95.0 - float(k / 5) * 22.0), park_rng.randf_range(-0.04, 0.04), park_liveries[k]])
	_build_matatus(parent, matatu_spots)
	# Soko Street: market stalls behind the barriers on both sides, a seller at each and customers in front.
	var s0: float = _s_at_z(SEG_SOKO, 152.0)
	var s1: float = _s_at_z(SEG_SOKO, 92.0)
	var ss: float = s0
	var stall_spots: Array = []
	var stall_i := 0
	while ss < s1:
		for side in [-1.0, 1.0]:
			var sp: Dictionary = _spot(ss, side * (STREET_HALF + 6.2), 0.0)
			var pos: Vector3 = sp["pos"]
			pos.y = STREET_Y
			var face: Vector3 = -sp["right"] * side
			stall_spots.append([pos, atan2(face.x, face.z), stall_i % 6, (stall_i / 6) % 3])
			stall_i += 1
			# The seller stands behind the counter, facing the street.
			people.append([pos - face * 0.6 + sp["fwd"] * rng.randf_range(-0.8, 0.8), -face, 0, 0, true])
			for k in range(3):
				var pp2: Vector3 = pos + face * rng.randf_range(3.0, 4.5) + sp["fwd"] * rng.randf_range(-2.5, 2.5)
				if _lap_distance(Vector2(pp2.x, pp2.z), 20.0) > STREET_HALF + 3.0:
					people.append([pp2, face, 0, 0, true])
		ss += 8.5
	_build_market_stalls(parent, stall_spots)
	# TV trucks and camera towers in the west corner yards.
	for sz in [-1.0, 1.0]:
		var tv := Vector3(-150.0, STREET_Y, sz * 104.0)
		b.box(tv + Vector3(0, 3.2, 0), Vector3(14.0, 5.6, 4.6), 0.0, Color(0.92, 0.92, 0.90))
		b.box(tv + Vector3(8.0, 2.6, 0), Vector3(3.6, 4.4, 4.4), 0.0, Color(0.20, 0.22, 0.25))
		b.box(tv + Vector3(-2.0, 6.4, 0), Vector3(0.3, 1.2, 0.3), 0.0, Color(0.5, 0.5, 0.5))
		var dish: Vector3 = tv + Vector3(-2.0, 7.6, 0)
		b.box(dish, Vector3(2.6, 2.6, 0.3), 0.6, Color(0.95, 0.95, 0.95))
	for corner in [Vector2(-128.0, 84.0), Vector2(-128.0, -84.0), Vector2(128.0, 84.0)]:
		var base := Vector3(corner.x, STREET_Y, corner.y)
		for sx in [-1.0, 1.0]:
			for sz2 in [-1.0, 1.0]:
				b.box(base + Vector3(sx * 1.6, 6.0, sz2 * 1.6), Vector3(0.2, 12.0, 0.2), 0.0, Color(0.7, 0.7, 0.72))
		b.box(base + Vector3(0, 12.1, 0), Vector3(4.2, 0.3, 4.2), 0.0, Color(0.45, 0.32, 0.20))
		b.box(base + Vector3(0, 13.4, 0), Vector3(1.2, 1.2, 2.2), 0.0, Color(0.08, 0.08, 0.09))
	# Streetlights along the lap's streets, behind the barriers: one StreetLampKit mesh, instanced per cell.
	var lamp_xf: Array = []
	var sl: float = _named_s["exit_to"] + 6.0
	var sl_end: float = _named_s["drop_kick"] - 4.0
	while sl < sl_end:
		for side in [-1.0, 1.0]:
			var lp: Dictionary = _spot(sl + (12.0 if side > 0.0 else 0.0), side * (STREET_HALF + 3.6), 0.0)
			var base2: Vector3 = lp["pos"]
			base2.y = STREET_Y
			var inward: Vector3 = -lp["right"] * side
			# The kit's arm reaches along +x.
			lamp_xf.append(Transform3D(Basis(Vector3.UP, atan2(-inward.z, inward.x)), base2))
		sl += 24.0
	_build_street_lamps(parent, lamp_xf)
	var mi := MeshInstance3D.new()
	mi.name = "PrecinctProps"
	mi.mesh = _save_baked_resource(b.commit(), "precinct_props")
	mi.material_override = _vertex_color_material(0.75)
	parent.add_child(mi)
	return people


## Street lights: StreetLampKit's mesh (life size, scaled by LAMP_SCALE) at each of `xf`, in cells so
## the ones out of sight cost nothing.
const LAMP_SCALE := 1.35
const LAMP_CELL := 160.0
const LAMP_RANGE := 380.0


func _build_street_lamps(parent: Node, xf: Array) -> void:
	var mats := {}
	var kit := PropKit.new()
	kit.material_for = func(key: String) -> Material:
		if not mats.has(key):
			mats[key] = _save_shared_resource(StreetLampKit.make_material(key), "streetlamp_" + key)
		return mats[key]
	kit.set_frame(Transform3D(Basis().scaled(Vector3.ONE * LAMP_SCALE), Vector3.ZERO))
	var mesh: ArrayMesh = _save_shared_resource(StreetLampKit.new(kit).build(), "streetlamp")
	var cells := {}
	for t in xf:
		var key := Vector2i(floori((t as Transform3D).origin.x / LAMP_CELL), floori((t as Transform3D).origin.z / LAMP_CELL))
		if not cells.has(key):
			cells[key] = []
		cells[key].append(t)
	var root := Node3D.new()
	root.name = "StreetLamps"
	parent.add_child(root)
	for key in cells:
		var mmi := _multimesh(mesh, cells[key], "StreetLamps_%d_%d" % [key.x, key.y])
		mmi.visibility_range_end = LAMP_RANGE
		mmi.visibility_range_end_margin = 20.0
		root.add_child(mmi)
	print("  street lamps: %d in %d cells" % [xf.size(), cells.size()])


# ======================================================================================
#  Lane dividers
# ======================================================================================

## Lines of plastic barrier blocks along the infield between the lanes, alternating orange and
## white, each line one long collision box.
func _build_lane_dividers(parent: Node) -> void:
	# Each line stops where the hairpin berms' backs take over the job.
	var lines := [[32.0, -114.0, 108.0], [0.0, -108.0, 114.0], [-32.0, -114.0, 108.0]]
	var block := BoxMesh.new()
	block.size = Vector3(2.8, 1.15, 1.0)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.55
	block.material = mat
	var transforms: Array = []
	var colors: Array = []
	var root := Node3D.new()
	root.name = "LaneDividers"
	parent.add_child(root)
	for ln in lines:
		var z: float = ln[0]
		var x0: float = ln[1]
		var x1: float = ln[2]
		var x: float = x0 + 1.5
		var k := 0
		while x < x1 - 1.4:
			transforms.append(Transform3D(Basis(), Vector3(x, FLOOR_Y + 0.575, z)))
			colors.append(Color(0.95, 0.40, 0.06) if k % 2 == 0 else Color(0.93, 0.93, 0.90))
			x += 3.0
			k += 1
		_box_body(root, "LaneDivider", Vector3((x0 + x1) * 0.5, FLOOR_Y + 0.6, z), Vector3(x1 - x0, 1.3, 1.0), 0.0)
	var mmi: MultiMeshInstance3D = _multimesh(block, transforms, "DividerBlocks", colors)
	root.add_child(mmi)


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

	# Checkpoints: one out of each hairpin (so nobody hops the dividers past it), two on the
	# streets.
	var checkpoints_container := Node3D.new()
	checkpoints_container.name = "Checkpoints"
	level_scene.add_child(checkpoints_container)
	var cp_offs: Array = [
		_s_at_x(SEG_L2, -104.0),
		_s_at_x(SEG_L3, 104.0),
		_s_at_x(SEG_L4, -104.0),
		_s_at_z(SEG_AVENUE, 75.0),
		_s_at_z(SEG_SOKO, 118.0),
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

	# Boost pads: before the whoops (skim them), on the climb out of the bowl, and a reward out of
	# T3. None on the streets: a boosted cart reaches the avenue's corners far too fast.
	var boost_scene: PackedScene = load("res://BoostPad.tscn")
	var boost_container := Node3D.new()
	boost_container.name = "BoostPads"
	level_scene.add_child(boost_container)
	var bp_defs: Array = [
		["Boost_Whoops_L", _s_at_x(SEG_L2, -98.0), -2.8],
		["Boost_Whoops_R", _s_at_x(SEG_L2, -98.0), 2.8],
		["Boost_Exit_L", _s_at_x(SEG_L4, 100.0), -3.0],
		["Boost_Exit_R", _s_at_x(SEG_L4, 100.0), 3.0],
		["Boost_Lane3", _s_at_x(SEG_L3, -75.0), 0.0],
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
	var item_rows := [_s_at_x(SEG_L1, -92.0), _s_at_x(SEG_L3, -96.0), _s_at_z(SEG_AVENUE, 110.0), _s_at_z(SEG_SOKO, 95.0)]
	var item_idx := 1
	for off in item_rows:
		for lat in [-4.0, 0.0, 4.0]:
			var ib = item_scene.instantiate()
			ib.name = "ItemBox_%d" % item_idx
			var s2: Dictionary = _spot(off, lat, 1.4)
			ib.position = s2["pos"]
			item_container.add_child(ib)
			item_idx += 1


# ======================================================================================
#  Sky and light
# ======================================================================================

const HAZE := Color(0.80, 0.79, 0.76)

func _build_environment(level_scene: Node3D) -> void:
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	# A Nairobi afternoon at 1,800m: deep clean-air blue overhead, big heaped cumulus building up toward the
	# horizon with flat blue-grey bases, a dusty cream haze along the horizon and a warm glow on the sun's side.
	# (Msitu Falls has the same shader with a milky, humid look; the cirrus sky was Frostpeak Creek's.)
	sky_mat.shader = load("res://sky_tropical_cumulus.gdshader")
	sky_mat.set_shader_parameter("sky_top", Color(0.07, 0.27, 0.68))
	sky_mat.set_shader_parameter("sky_horizon", Color(0.62, 0.78, 0.92))
	sky_mat.set_shader_parameter("ground_horizon", Color(0.82, 0.76, 0.66))
	sky_mat.set_shader_parameter("ground_bottom", Color(0.50, 0.45, 0.38))
	sky_mat.set_shader_parameter("sky_curve", 0.42)
	sky_mat.set_shader_parameter("horizon_haze", HAZE)
	sky_mat.set_shader_parameter("haze_strength", 0.55)
	sky_mat.set_shader_parameter("haze_height", 0.15)
	sky_mat.set_shader_parameter("sun_tint", Color(1.0, 0.93, 0.80))
	sky_mat.set_shader_parameter("sun_disc_degrees", 1.0)
	sky_mat.set_shader_parameter("sun_glow", 0.5)
	sky_mat.set_shader_parameter("sun_horizon_glow", 0.55)
	sky_mat.set_shader_parameter("sun_horizon_tint", Color(1.0, 0.80, 0.55))
	sky_mat.set_shader_parameter("cloud_lit", Color(1.0, 0.98, 0.95))
	sky_mat.set_shader_parameter("cloud_shade", Color(0.46, 0.54, 0.70))
	sky_mat.set_shader_parameter("cloud_coverage", 0.58)
	sky_mat.set_shader_parameter("cloud_opacity", 0.97)
	sky_mat.set_shader_parameter("cloud_scale", 1.15)
	sky_mat.set_shader_parameter("cloud_seed", 12.3)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.6
	env.ambient_light_color = Color(1.0, 0.94, 0.86)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.08
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = HAZE
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.18
	env.fog_density = 1.0
	env.fog_depth_begin = 450.0
	env.fog_depth_end = 3200.0
	env.fog_depth_curve = 1.5
	env.fog_sky_affect = 0.05
	env.fog_aerial_perspective = 0.3
	env_node.environment = env
	level_scene.add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	# Mid-afternoon, from the west-south-west.
	sun.rotation_degrees = Vector3(-41.0, -67.5, 0.0)
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 400.0
	level_scene.add_child(sun)


# ======================================================================================
#  Build
# ======================================================================================

## Saves a resource that is not the level's own, under generated/ without the level's prefix: the
## matatus belong to MatatuKit, and a nyota_ mesh over MESH_CHUNK_CELL triangles would be split by
## MeshChunker at the origin (they are modelled around it, so each van would become four pieces).
func _save_shared_resource(res: Resource, res_name: String) -> Resource:
	var file_path: String = "res://generated/" + res_name + ".res"
	res.take_over_path(file_path)
	ResourceSaver.save(res, file_path)
	return load(file_path)


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
	print("=== Nyota Stadium (Matumaini GP) Level Generation ===")
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

	# 1. The plan and its checks.
	_build_plan()
	_plan_profile()
	_verify_layout()
	_verify_jumps()

	# 2. Track.
	main_curve = _build_main_curve()
	var track_path := Path3D.new()
	track_path.name = "TrackPath"
	track_path.curve = main_curve
	level_scene.add_child(track_path)
	var track_root := Node3D.new()
	track_root.name = "Track"
	level_scene.add_child(track_root)
	var track_mat := ShaderMaterial.new()
	track_mat.shader = load("res://stadium_track.gdshader")
	track_mat.set_shader_parameter("dirt_tex", load("res://materials/dirt.png"))
	track_mat.set_shader_parameter("dirt_normal", load("res://materials/dirt_normal.png"))
	track_mat.set_shader_parameter("asphalt_tex", load("res://materials/asphalt.png"))
	_build_track(track_root, track_mat)

	# 3. The bowl: floor, walls, stands; the streets outside.
	var concrete := _concrete_material()
	var net_mat := _net_material()
	var stadium := Node3D.new()
	# Not "Buildings"/"Environment": Level.gd bakes trimesh colliders for nodes with those names.
	stadium.name = "Stadium"
	level_scene.add_child(stadium)
	var floor_mat := ShaderMaterial.new()
	floor_mat.shader = track_mat.shader
	for p in ["dirt_tex", "dirt_normal", "asphalt_tex"]:
		floor_mat.set_shader_parameter(p, track_mat.get_shader_parameter(p))
	floor_mat.set_shader_parameter("infield", true)
	_build_arena_floor(stadium, floor_mat)
	_build_walls(stadium, concrete, net_mat)
	var seat_mat := _vertex_color_material(0.5)
	var crowd_spots: Array = _build_stands(stadium, concrete, seat_mat)
	print("  stands: %d seats" % crowd_spots.size())
	# The crowd decides who gets a 3D figure by how near the lap they are.
	_index_lap()
	_build_crowd(stadium, crowd_spots, _corner_crowd_spots())
	_build_boards(stadium)
	_build_floodlights(stadium)
	_build_screens(stadium, _ads_material)
	_build_jump_flags(stadium)
	var streets := Node3D.new()
	streets.name = "Streets"
	level_scene.add_child(streets)
	var paving := ShaderMaterial.new()
	paving.shader = load("res://city_ground.gdshader")
	paving.set_shader_parameter("concrete_tex", load("res://materials/concrete.png"))
	paving.set_shader_parameter("asphalt_tex", load("res://materials/asphalt.png"))
	paving.set_shader_parameter("grid_origin", Vector2(STREET_X0, STREET_Z0))
	paving.set_shader_parameter("block", Vector2(BLOCK_X, BLOCK_Z))
	paving.set_shader_parameter("street_half", CITY_STREET_HALF)
	paving.set_shader_parameter("pavement", PAVEMENT)
	paving.set_shader_parameter("precinct", Vector4(PRECINCT.position.x, PRECINCT.position.y, PRECINCT.end.x, PRECINCT.end.y))
	_build_ground(streets, paving)
	_index_lap()
	_build_city(streets)
	_build_hills(streets)
	_build_street_trees(streets)
	_build_facades(stadium, concrete)
	_build_drop_gantry(streets)
	var plaza_people: Array = _build_precinct_dressing(streets)
	_build_crowd(streets, plaza_people)
	_build_cutting(streets, concrete)
	_build_street_barriers(streets, concrete, net_mat)
	_build_lane_dividers(stadium)

	# 4. Sky, light, gameplay.
	_build_environment(level_scene)
	_place_gameplay(level_scene)

	# 5. Save.
	level_scene.set("track_path", track_path)
	# The take-off lips, for scratch/nyota_jump_test.gd.
	var lips: Array = []
	for lip in _lips:
		var sp: Dictionary = _spot(float(lip["s"]), 0.0, 0.0)
		lips.append({"name": lip["name"], "lip": sp["pos"], "dir": sp["fwd"]})
	track_path.set_meta(&"jump_lips", lips)
	level_scene._setup_checkpoints()
	var chunked: int = MeshChunker.chunk_scene(level_scene, "res://generated/" + RES_PREFIX, "res://generated/nyota_chunks", MESH_CHUNK_CELL)
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
