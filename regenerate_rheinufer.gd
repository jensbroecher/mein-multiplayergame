# regenerate_rheinufer.gd
#
# Builds levels/RheinuferLevel.tscn - Rheinufer, the second stage of the Kronburg GP: the Lower Rhine at the edge of the
# fictional Ruhr town Kronburg on a summer evening. The lap starts on the east bank's Rheinuferpromenade (Gründerzeit
# houses, plane trees, the lower promenade and the Rheintreppe), turns west across the Rhine on the Alte Rheinbrücke (a
# steel through-arch town bridge between sandstone bridge towers), runs north along the west bank's dyke road through the
# Rhine meadows (groynes and beaches, sheep, pollarded willows, the tower windmill, the Kirmes on the meadow), turns west
# off the dyke and over the A 58, swings round the Anschlussstelle's loop ramp up onto the A 47, crosses the A 58 again
# at the Autobahnkreuz and the Rhine on the Harfenbrücke (a cable-stayed motorway bridge) and leaves the motorway down a
# curving exit ramp onto the promenade.
#
# Things worth knowing before editing this file:
#
# 1. The lap is straights and arcs (CORNERS, filleted). Its height is designed, not taken from the ground (`_design_y`):
#    the bridges' decks are functions of x (`_old_deck`, `_harp_deck`: the bridge kits are built to the same functions),
#    the motorway's profile is `_a2_y`, the rest Hermite pieces between flat stretches. Where the lap is on a structure
#    (`_lap_on_deck`) the ground is not graded to it.
# 2. Every road surface is a ribbon laid a few centimetres over the graded ground or on a structure, drawn by
#    kronburg_road.gdshader by kind (7 the Autobahn, 8 the old bridge's asphalt, 2 the promenade, 0 the country roads).
#    Every triangle the lap runs on is one body, LapRoad (track). The dressing roads (the A 58, the A 47's other
#    carriageway and its continuations, the Kreuz's loops, the country road, the promenade's continuation) are ribbons
#    of their own on the same grading, solid as "Autobahn..." bodies (named without "road": they are not the lap).
# 3. The ground is one heightfield (kronburg_ground.gdshader with `g_beach`: G is the Rhine's beach, R the basalt
#    riprap) graded to every road (`_grade`, over segments of all roads). The Rhine is a plane at WATER_Y between
#    ±RIVER_HALF, drawn by rhine_water.gdshader, flowing toward -z.
# 4. Props come from RheinBridgeKit, RheinShipKit, NiederrheinKit, RheinStadtKit (and stage 1's KronburgTownKit,
#    SteelworksKit, CampKit): life size, grown by PROP_SCALE, batched into one mesh per key and cell under PROP_PREFIX
#    (MeshChunker leaves them whole, so DressingColliders makes them solid at race time). The two Rhine bridges and the
#    viaduct parts are built in game metres (`_add_prop_game`).
#
# The generator runs headless and cannot render; scratch/lap_shots.tscn renders the lap.
extends Node

const LEVEL_NAME := "RheinuferLevel"
const LEVEL_PATH := "res://levels/RheinuferLevel.tscn"
const RES_PREFIX := "rheinufer_"
const PROP_PREFIX := "rheinuferprop_"
const MeshChunker = preload("res://MeshChunker.gd")
const PropKit = preload("res://PropKit.gd")
const YardKit = preload("res://YardKit.gd")
const CampKit = preload("res://CampKit.gd")
const CrowdPlacer = preload("res://CrowdPlacer.gd")

const MESH_CHUNK_CELL := 80.0
const PROP_SCALE := 1.6

const ROAD_HALF := 7.5
const PAVEMENT := 3.4
## The ground lies this far under a road's surface across its flat band.
const GROUND_UNDER := 0.07
const SAMPLE_STEP := 3.0
const CELL := 32.0
const GRADE_REACH := 52.0

## The lap's corners: [point (x, z), fillet radius]. x east, z south.
const CORNERS := [
	[Vector2(232.0, -347.0), 60.0],   # 0 the exit ramp: off the A 47 eastbound, south onto the promenade
	[Vector2(232.0, 200.0), 40.0],    # 1 the promenade's end: right, onto the Alte Rheinbrücke (between its towers)
	[Vector2(-345.0, 200.0), 35.0],   # 2 the bridge's west end: right, north along the dyke
	[Vector2(-345.0, -200.0), 45.0],  # 3 off the dyke: left, west toward the A 58
	[Vector2(-760.0, -200.0), 73.5],  # 4 the Anschlussstelle's loop ramp, its first half
	[Vector2(-760.0, -347.0), 73.5],  # 5 its second half, onto the A 47 eastbound
]

# ---- The river and its banks (world metres; the Rhine flows toward -z).
const WATER_Y := 0.0
const RIVER_HALF := 180.0
const BED_Y := -6.5
const FLOOD_Y := 3.0
const DYKE_X := -345.0
const DYKE_Y := 10.0
const DYKE_CROWN := 11.0
const LAND_Y := 4.5
const TOWN_Y := 9.0
const LOWER_PROM_Y := 3.5
const LOWER_PROM_X := 186.0
const QUAY_X := 200.0
## The town's river front (the quay and the lower promenade) in z.
const TOWN_Z := Vector2(-300.0, 255.0)
const PROMENADE_X := 232.0

# ---- The two Rhine bridges and the motorways.
const OLD_BRIDGE_Z := 200.0
const OLD_BRIDGE_X := Vector2(-310.0, 202.0)
const A47_Z := -347.0          # the lap's (eastbound) carriageway's centre
const A47_AXIS := -360.0       # the motorway's median
const A47_WB := -373.0         # the westbound carriageway's centre
const HARP_X := Vector2(-345.0, 180.0)
const HARP_PYLON_X := -150.0
const A58_X := -560.0          # the A 58's median
const A58_SB := -571.5
const A58_NB := -548.5
## The overpasses over the A 58 (x range) and the A 47's viaduct between its embankment and the Harfenbrücke.
const OVER_A58 := Vector2(-605.0, -515.0)
const A47_VIADUCT := Vector2(-392.0, -345.0)
const WEST_ROAD_Z := -200.0
const HAIRPIN_Y := 11.5
## The country road on west of the loop ramp starts clear of the ramp's bulge (and its guardrail).
const COUNTRY_X0 := -752.0
## The A 47 eastbound west of the loop ramp ends (closed) clear of the ramp's last bend, which runs on its line.
const A47_EB_END := -742.0
## East of the exit ramp the closed eastbound carriageway (and its girder's edge) begins clear of the ramp's bend.
const A47_EB_EAST := 218.0
const KREUZ_R := 45.0
const LOOP_HALF := 4.0

# ---- The terrain grid.
const FINE_X := Vector2(-1150.0, 750.0)
const FINE_Z := Vector2(-900.0, 650.0)
const FINE_STEP := 5.0
const OUTER := 6500.0
const COARSE_GROWTH := 1.16
const COARSE_MAX := 180.0

const FINISH_Z := -40.0
## The exit ramp's Hermite ends this far along the promenade's straight (the lap's s).
const RAMP_END := 150.0

var level: Node3D
var segs: Array = []
var lap_len := 0.0
var _road_y := PackedFloat32Array()

var _noise := FastNoiseLite.new()
var _land_noise := FastNoiseLite.new()
var _forest_noise := FastNoiseLite.new()
var _field_noise := FastNoiseLite.new()

## Grading segments of every road (a, b, the flat band's half width), bucketed by CELL.
var _seg_a := PackedVector3Array()
var _seg_b := PackedVector3Array()
var _seg_flat := PackedFloat32Array()
var _seg_lap := PackedByteArray()
var _seg_cells := {}

var _grid_x := PackedFloat32Array()
var _grid_z := PackedFloat32Array()
var _heights := PackedFloat32Array()
var _road_d := PackedFloat32Array()
var _lap_faces := PackedVector3Array()
var _ground_mat: ShaderMaterial
var _road_mat: ShaderMaterial
## The dressing roads: [{name, pts, rts, ss, half, chw, kind, deck, solid}].
var _droads: Array = []


# ======================================================================================
#  The lap
# ======================================================================================

func _dir_of(th: float) -> Vector2:
	return Vector2(cos(th), sin(th))


## Right of travel for a heading (x east, z south: heading east has the south on its right).
func _right_of(th: float) -> Vector2:
	return Vector2(-sin(th), cos(th))


## Fillets a polygon of [point, radius] corners into straights and arcs; `closed` joins the last corner to the first.
## An open path's first and last points are its ends (their radii are ignored). Returns [segs, length].
func _fillet_path(corners: Array, closed: bool) -> Array:
	var n: int = corners.size()
	var a_in: Array = []
	var a_out: Array = []
	var arcs: Array = []
	for i in range(n):
		var b: Vector2 = corners[i][0]
		if not closed and (i == 0 or i == n - 1):
			a_in.append(b)
			a_out.append(b)
			arcs.append(null)
			continue
		var r: float = corners[i][1]
		var a: Vector2 = corners[(i - 1 + n) % n][0]
		var c: Vector2 = corners[(i + 1) % n][0]
		var d1: Vector2 = (b - a).normalized()
		var d2: Vector2 = (c - b).normalized()
		var ang: float = atan2(d1.x * d2.y - d1.y * d2.x, d1.dot(d2))
		var t: float = r * tan(absf(ang) * 0.5)
		if t > b.distance_to(a) * 0.5 + 0.01 or t > b.distance_to(c) * 0.5 + 0.01:
			push_error("Rheinufer: corner %d's radius %.0f does not fit" % [i, r])
		a_in.append(b - d1 * t)
		a_out.append(b + d2 * t)
		if absf(ang) < 0.0001 or r <= 0.0:
			arcs.append(null)
		else:
			arcs.append({"kind": "A", "p0": b - d1 * t, "th0": atan2(d1.y, d1.x), "r": r, "sign": signf(ang), "len": r * absf(ang)})
	var out: Array = []
	var s := 0.0
	var prev: Vector2 = a_out[0]
	var k0: int = 1
	var k1: int = n + 1 if closed else n
	for k in range(k0, k1):
		var i: int = k % n
		var p_in: Vector2 = a_in[i]
		var length: float = prev.distance_to(p_in)
		if length > 0.001:
			var dd: Vector2 = (p_in - prev) / length
			out.append({"kind": "S", "p0": prev, "th0": atan2(dd.y, dd.x), "len": length, "s0": s})
			s += length
		if arcs[i] != null:
			var arc: Dictionary = (arcs[i] as Dictionary).duplicate()
			arc["s0"] = s
			out.append(arc)
			s += float(arc["len"])
		prev = a_out[i]
	return [out, s]


func _seg_at(path: Array, s: float) -> Dictionary:
	var seg: Dictionary = path[0]
	for i in range(path.size() - 1, -1, -1):
		if s >= float(path[i]["s0"]) - 0.0001:
			seg = path[i]
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


## Position (x, z), heading and signed curvature at s along the lap.
func _at(s: float) -> Dictionary:
	return _seg_at(segs, fposmod(s, lap_len))


## Which of the lap's segments s is on (0 the promenade's straight ... 11 the exit ramp's arc).
func _seg_index(s: float) -> int:
	s = fposmod(s, lap_len)
	for i in range(segs.size() - 1, -1, -1):
		if s >= float(segs[i]["s0"]) - 0.0001:
			return i
	return 0


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


## A spot on the lap: `lat` metres right of the centreline, `lift` over the road, the yaw facing the way of travel.
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


# ======================================================================================
#  The designed heights: the bridges' decks, the motorway's profile, the lap
# ======================================================================================

## Cubic Hermite from (x0, y0, slope m0) to (x1, y1, slope m1), clamped outside.
func _hermite(x: float, x0: float, y0: float, m0: float, x1: float, y1: float, m1: float) -> float:
	var h: float = x1 - x0
	var t: float = clampf((x - x0) / h, 0.0, 1.0)
	var t2: float = t * t
	var t3: float = t2 * t
	return (2.0 * t3 - 3.0 * t2 + 1.0) * y0 + (t3 - 2.0 * t2 + t) * h * m0 + (-2.0 * t3 + 3.0 * t2) * y1 + (t3 - t2) * h * m1


## The Alte Rheinbrücke's road surface at x: level with the promenade (TOWN_Y) at its east head and the dyke (DYKE_Y)
## at its west end, cresting at 15.5 over the river's middle, flat at both ends.
static func old_deck(x: float) -> float:
	if x >= 0.0:
		return 9.0 + 3.25 * (1.0 + cos(PI * clampf(x / 202.0, 0.0, 1.0)))
	return 10.0 + 2.75 * (1.0 + cos(PI * clampf(x / 310.0, -1.0, 0.0)))


## The Harfenbrücke's road surface at x (both carriageways): 23 over the river's middle, 21 at the banks, down to 17
## over the dyke.
static func harp_deck(x: float) -> float:
	if x >= -180.0:
		var u: float = x / 180.0
		return 23.0 - 2.0 * u * u
	return 21.0 - (-180.0 - x) * (4.0 / 165.0)


## The A 47's road surface (both carriageways) at x, from the west country to the town in the east.
func _a2_y(x: float) -> float:
	if x < -686.5:
		return _hermite(x, -960.0, LAND_Y + GROUND_UNDER, 0.0, -686.5, HAIRPIN_Y, 0.0)
	if x < -590.0:
		return _hermite(x, -686.5, HAIRPIN_Y, 0.0, -590.0, 13.5, 0.0)
	if x < -530.0:
		return 13.5
	if x < -345.0:
		return _hermite(x, -530.0, 13.5, 0.0, -345.0, 17.0, 4.0 / 165.0)
	if x <= 180.0:
		return harp_deck(x)
	return _hermite(x, 180.0, 21.0, -4.0 / 180.0, 640.0, _town_ground(640.0) + GROUND_UNDER, 0.0)


## The west road from the dyke over the A 58 to the loop ramp.
func _west_y(x: float) -> float:
	if x > -530.0:
		return _hermite(x, -390.0, DYKE_Y, 0.0, -530.0, 13.5, 0.0)
	if x > -590.0:
		return 13.5
	return _hermite(x, -590.0, 13.5, 0.0, -686.5, HAIRPIN_Y, 0.0)


func _plan_road_heights() -> void:
	# The fillet's segments: [promenade, E1 arc, old bridge, W1 arc, dyke, D1 arc, west road, H1 arc, H2 arc, A 47,
	# E0 arc] (H1 and H2 share their tangent point, so the straight between them has no length).
	if segs.size() != 11:
		push_error("Rheinufer: expected 11 lap segments, got %d" % segs.size())
	var n: int = int(ceil(lap_len)) + 1
	_road_y.resize(n)
	for i in range(n):
		_road_y[i] = _design_y_fixed(float(i))
	var steep := 0.0
	var at := 0.0
	for i in range(n - 1):
		var g: float = absf(_road_y[i + 1] - _road_y[i])
		if g > steep:
			steep = g
			at = float(i)
	print("  lap %.0fm, road from %.1f to %.1fm, steepest %.1f%% at %.0fm" % [lap_len, _min(_road_y), _max(_road_y), steep * 100.0, at])


## _design_y with the segment order the fillet produces: [promenade, E1 arc, old bridge, W1 arc, dyke, D1 arc, west
## road, H1 arc, H2 arc, A 47, E0 arc].
func _design_y_fixed(s: float) -> float:
	var i: int = _seg_index(s)
	var p: Vector2 = _at(s)["p"]
	match i:
		0, 10:
			var u: float = s if s < lap_len * 0.5 else s - lap_len
			var arc: Dictionary = segs[10]
			var x0: float = float((arc["p0"] as Vector2).x)
			return _hermite(u, -float(arc["len"]), harp_deck(x0), -4.0 * x0 / (180.0 * 180.0), RAMP_END, TOWN_Y, 0.0)
		1:
			return TOWN_Y
		2:
			return old_deck(p.x)
		3, 4, 5:
			return DYKE_Y
		6:
			return _west_y(p.x)
		7, 8:
			return HAIRPIN_Y
		9:
			return _a2_y(p.x)
	return TOWN_Y


## Whether the lap at s is on a structure (no grading under it): the old bridge, the overpasses over the A 58, the A 47's
## viaduct and the Harfenbrücke, the exit ramp's viaduct until it nears the ground.
func _lap_on_deck(s: float) -> bool:
	var i: int = _seg_index(s)
	var p: Vector2 = _at(s)["p"]
	match i:
		2:
			return true
		6, 9:
			if p.x > OVER_A58.x and p.x < OVER_A58.y:
				return true
			if i == 9 and p.x > A47_VIADUCT.x:
				return true
		0, 10:
			return _lap_y(s) - _natural(p.x, p.y) > 2.2
	return false


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


# ======================================================================================
#  The natural ground
# ======================================================================================

func _init_noise() -> void:
	_noise.seed = 5301
	_noise.frequency = 0.006
	_noise.fractal_octaves = 3
	_land_noise.seed = 5302
	_land_noise.frequency = 0.0022
	_land_noise.fractal_octaves = 3
	_forest_noise.seed = 5303
	_forest_noise.frequency = 0.0045
	_forest_noise.fractal_octaves = 3
	_field_noise.seed = 5304
	_field_noise.frequency = 0.003
	_field_noise.fractal_octaves = 2


func _town_ground(x: float) -> float:
	return TOWN_Y + maxf(0.0, x - 260.0) * 0.004


## 1 inside the town's river front (z), easing to 0 over 40m.
func _town_w(z: float) -> float:
	return smoothstep(TOWN_Z.x - 40.0, TOWN_Z.x, z) * (1.0 - smoothstep(TOWN_Z.y, TOWN_Z.y + 40.0, z))


func _raw_natural(x: float, z: float) -> float:
	var n: float = _noise.get_noise_2d(x, z)
	var h: float
	if x < 0.0:
		var d: float = -x - RIVER_HALF
		if d < 0.0:
			h = lerpf(-0.6, BED_Y, smoothstep(0.0, 80.0, -d)) + 0.5 * n
		else:
			# A beach of sand and gravel (1:6), then the meadow at FLOOD_Y with shallow flood hollows.
			var hollow: float = smoothstep(0.35, 0.65, _land_noise.get_noise_2d(x * 1.7, z * 0.6) + 0.5) * 1.1
			h = minf(FLOOD_Y + 0.35 * n - hollow * smoothstep(30.0, 60.0, d), d * 0.17)
			# The dyke (the river side and the land side at 1:3) and the land behind it.
			var dd: float = absf(x - DYKE_X) - DYKE_CROWN
			var dyke: float = DYKE_Y - maxf(dd, 0.0) / 3.0
			if x < DYKE_X:
				h = LAND_Y + 0.6 * _land_noise.get_noise_2d(x, z)
				# The far west: the land rises to low hills on the horizon.
				h += smoothstep(1800.0, 6000.0, -x) * 26.0 * (0.6 + 0.4 * _land_noise.get_noise_2d(z * 0.3, x * 0.3))
			h = maxf(h, dyke)
	else:
		var d2: float = x - RIVER_HALF
		if d2 < 0.0:
			h = lerpf(-0.6, BED_Y, smoothstep(0.0, 80.0, -d2)) + 0.5 * n
		else:
			var tw: float = _town_w(z)
			# The town: riprap up to the lower promenade, the quay wall to the town's level.
			var h_town: float
			if x < LOWER_PROM_X:
				h_town = lerpf(0.0, LOWER_PROM_Y, (x - RIVER_HALF) / (LOWER_PROM_X - RIVER_HALF))
			elif x <= QUAY_X:
				h_town = LOWER_PROM_Y
			else:
				h_town = _town_ground(x)
			# Elsewhere a grassy bank up to the town's level.
			var h_bank: float = lerpf(0.0, _town_ground(x), smoothstep(RIVER_HALF, 236.0, x)) + 0.3 * n * smoothstep(RIVER_HALF + 8.0, RIVER_HALF + 30.0, x)
			h = lerpf(h_bank, h_town, tw)
			# The far east: the land climbs toward the Bergisches Land.
			h += smoothstep(900.0, 6000.0, x) * 55.0 * (0.7 + 0.3 * _land_noise.get_noise_2d(z * 0.3, x * 0.3))
	return h


## The pads graded level: the Kirmes on the meadow, the farmsteads, the power station.
const KIRMES_RECT := [-300.0, -130.0, -200.0, 140.0]
const KIRMES_Y := 3.3

func _rect_weight(x: float, z: float, r: Array, blend: float) -> float:
	var dx: float = maxf(float(r[0]) - x, x - float(r[2]))
	var dz: float = maxf(float(r[1]) - z, z - float(r[3]))
	return 1.0 - smoothstep(0.0, blend, maxf(dx, dz))


func _in_rect(x: float, z: float, r: Array, pad := 0.0) -> bool:
	return x > float(r[0]) - pad and x < float(r[2]) + pad and z > float(r[1]) - pad and z < float(r[3]) + pad


func _natural(x: float, z: float) -> float:
	var h: float = _raw_natural(x, z)
	h = lerpf(h, KIRMES_Y, _rect_weight(x, z, KIRMES_RECT, 14.0))
	for p in _pads:
		h = lerpf(h, float(p[2]), _rect_weight(x, z, [float(p[0].x) - float(p[1].x), float(p[0].y) - float(p[1].y), float(p[0].x) + float(p[1].x), float(p[0].y) + float(p[1].y)], 16.0))
	return h


## Pads: [centre, half extents, height] (the farmsteads and the power station), filled in before the heights are built.
var _pads: Array = []


# ======================================================================================
#  The roads: the lap's samples and the dressing roads, and the grading over all of them
# ======================================================================================

## A dressing road from a polyline of [point, radius] corners: sampled every `step`, its height and whether it is on a
## structure from callables of (x, z, s).
func _dress_road(name: String, corners: Array, half: float, chw: float, kind: int, y_fn: Callable, deck_fn: Callable, solid := true, step := 2.0) -> Dictionary:
	var fp: Array = _fillet_path(corners, false)
	var path: Array = fp[0]
	var total: float = fp[1]
	return _dress_from(name, func(s: float) -> Dictionary: return _seg_at(path, s), total, half, chw, kind, y_fn, deck_fn, solid, step)


func _dress_from(name: String, at_fn: Callable, total: float, half: float, chw: float, kind: int, y_fn: Callable, deck_fn: Callable, solid: bool, step: float) -> Dictionary:
	var pts := PackedVector3Array()
	var rts := PackedVector3Array()
	var ss := PackedFloat32Array()
	var deck := PackedByteArray()
	var n: int = maxi(1, ceili(total / step))
	for i in range(n + 1):
		var s: float = total * float(i) / float(n)
		var a: Dictionary = at_fn.call(s)
		var p: Vector2 = a["p"]
		var r: Vector2 = _right_of(float(a["th"]))
		pts.append(Vector3(p.x, float(y_fn.call(p.x, p.y, s)), p.y))
		rts.append(Vector3(r.x, 0.0, r.y))
		ss.append(s)
		deck.append(1 if bool(deck_fn.call(p.x, p.y, s)) else 0)
	var road := {"name": name, "pts": pts, "rts": rts, "ss": ss, "half": half, "chw": chw, "kind": kind, "deck": deck, "solid": solid}
	_droads.append(road)
	return road


func _add_seg(a: Vector3, b: Vector3, flat: float, lap: bool) -> void:
	_seg_a.append(a)
	_seg_b.append(b)
	_seg_flat.append(flat)
	_seg_lap.append(1 if lap else 0)
	var idx: int = _seg_a.size() - 1
	var lo := Vector2(minf(a.x, b.x), minf(a.z, b.z))
	var hi := Vector2(maxf(a.x, b.x), maxf(a.z, b.z))
	for gx in range(floori(lo.x / CELL), floori(hi.x / CELL) + 1):
		for gz in range(floori(lo.y / CELL), floori(hi.y / CELL) + 1):
			var key := Vector2i(gx, gz)
			if not _seg_cells.has(key):
				_seg_cells[key] = PackedInt32Array()
			var arr: PackedInt32Array = _seg_cells[key]
			arr.append(idx)
			_seg_cells[key] = arr


## The grading's segments: the lap every SAMPLE_STEP (none where it is on a structure), every dressing road.
func _add_samples() -> void:
	var s := 0.0
	while s < lap_len:
		var s2: float = minf(s + SAMPLE_STEP, lap_len)
		if not (_lap_on_deck(s) and _lap_on_deck(s2)):
			var w: float = _ribbon_half(_kind_at(_road_kinds(), s))
			_add_seg(_pt(s), _pt(s2), w + 1.6, true)
		s = s2
	for road in _droads:
		var pts: PackedVector3Array = road["pts"]
		var deck: PackedByteArray = road["deck"]
		var stride: int = 2
		var i := 0
		while i < pts.size() - 1:
			var j: int = mini(i + stride, pts.size() - 1)
			if not (deck[i] == 1 and deck[j] == 1):
				_add_seg(pts[i], pts[j], float(road["half"]) + 1.6, false)
			i = j


## The ground graded to the roads: level with them (GROUND_UNDER under) across their flat bands, then rounded shoulders
## rising or falling out to the natural ground. Returns the height and the distance to the nearest road's centreline.
func _grade(h: float, x: float, z: float) -> Vector2:
	var cx: int = floori(x / CELL)
	var cz: int = floori(z / CELL)
	var upper := 1e9
	var lower := -1e9
	var touched := false
	var flat_y := NAN
	var flat_lat := 1e9
	var best_d := 1e9
	var seen := {}
	for gz in range(cz - 2, cz + 3):
		for gx in range(cx - 2, cx + 3):
			var bucket: PackedInt32Array = _seg_cells.get(Vector2i(gx, gz), PackedInt32Array())
			for i in bucket:
				if seen.has(i):
					continue
				seen[i] = true
				var a: Vector3 = _seg_a[i]
				var b: Vector3 = _seg_b[i]
				var sx: float = b.x - a.x
				var sz: float = b.z - a.z
				var l2: float = sx * sx + sz * sz
				if l2 < 1e-6:
					continue
				var t: float = clampf(((x - a.x) * sx + (z - a.z) * sz) / l2, 0.0, 1.0)
				var fx: float = x - (a.x + sx * t)
				var fz: float = z - (a.z + sz * t)
				var lateral: float = sqrt(fx * fx + fz * fz)
				if lateral > GRADE_REACH:
					continue
				best_d = minf(best_d, lateral)
				var foot_y: float = lerpf(a.y, b.y, t) - GROUND_UNDER
				var flat: float = _seg_flat[i]
				var over: float = maxf(0.0, lateral - flat)
				# Embankments and cuttings: about 1:2 once away from the road, rounded at the top.
				var soft: float = over * over / (over + 4.0)
				upper = minf(upper, foot_y + soft * 0.62)
				lower = maxf(lower, foot_y - soft * 0.55)
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


## The distance in plan from (x, z) to the lap's centreline.
func _lap_dist(x: float, z: float) -> float:
	return _road_dist(x, z, true)


func _road_dist(x: float, z: float, lap_only: bool) -> float:
	var cx: int = floori(x / CELL)
	var cz: int = floori(z / CELL)
	var best := 1e18
	for gz in range(cz - 2, cz + 3):
		for gx in range(cx - 2, cx + 3):
			var bucket: PackedInt32Array = _seg_cells.get(Vector2i(gx, gz), PackedInt32Array())
			for i in bucket:
				if lap_only and _seg_lap[i] == 0:
					continue
				var a: Vector3 = _seg_a[i]
				var b: Vector3 = _seg_b[i]
				var sx: float = b.x - a.x
				var sz: float = b.z - a.z
				var l2: float = maxf(sx * sx + sz * sz, 1e-6)
				var t: float = clampf(((x - a.x) * sx + (z - a.z) * sz) / l2, 0.0, 1.0)
				var fx: float = x - (a.x + sx * t)
				var fz: float = z - (a.z + sz * t)
				best = minf(best, fx * fx + fz * fz)
	if lap_only:
		# Structures carry no grading segments: measure to the lap's points on them (every 3m).
		if _deck_pts.is_empty():
			var s := 0.0
			while s < lap_len:
				if _lap_on_deck(s):
					_deck_pts.append(_at(s)["p"])
				s += 3.0
		var q := Vector2(x, z)
		for p in _deck_pts:
			best = minf(best, p.distance_squared_to(q))
	return sqrt(best) if best < 1e17 else 1e9


var _deck_pts := PackedVector2Array()


# ======================================================================================
#  The dressing roads: the A 58, the A 47's other carriageway and its ends, the Kreuz's loops, the country road
# ======================================================================================

func _plan_dressing_roads() -> void:
	var no_deck := func(_x: float, _z: float, _s: float) -> bool: return false
	var at_grade := func(x: float, z: float, _s: float) -> float: return _natural(x, z) + GROUND_UNDER
	# The A 58, both carriageways, at grade (it passes under the west road and the A 47).
	var a58_y := func(_x: float, _z: float, _s: float) -> float: return LAND_Y + GROUND_UNDER
	_dress_road("A58South", [[Vector2(A58_SB, -2600.0), 0.0], [Vector2(A58_SB, 2600.0), 0.0]], ROAD_HALF, ROAD_HALF, 7, a58_y, no_deck)
	_dress_road("A58North", [[Vector2(A58_NB, 2600.0), 0.0], [Vector2(A58_NB, -2600.0), 0.0]], ROAD_HALF, ROAD_HALF, 7, a58_y, no_deck)
	# The A 47 westbound, from the town in the east to the west country (beside the lap from the exit to the loop ramp).
	var a2y := func(x: float, _z: float, _s: float) -> float: return _a2_y(x)
	var a2_deck := func(x: float, _z: float, _s: float) -> bool:
		if x > OVER_A58.x and x < OVER_A58.y:
			return true
		if x > A47_VIADUCT.x and x <= HARP_X.y:
			return true
		return x > HARP_X.y and _a2_y(x) - _natural(x, A47_WB) > 2.2
	_dress_road("A47West", [[Vector2(1700.0, A47_WB), 0.0], [Vector2(-2600.0, A47_WB), 0.0]], ROAD_HALF, ROAD_HALF, 7, a2y, a2_deck)
	# The A 47 eastbound west of the loop ramp's merge (closed for the race) and east of the exit (closed too).
	_dress_road("A47EastW", [[Vector2(-2600.0, A47_Z), 0.0], [Vector2(A47_EB_END, A47_Z), 0.0]], ROAD_HALF, ROAD_HALF, 7, a2y, a2_deck)
	_dress_road("A47EastE", [[Vector2(A47_EB_EAST, A47_Z), 0.0], [Vector2(1700.0, A47_Z), 0.0]], ROAD_HALF, ROAD_HALF, 7, a2y, a2_deck)
	# The country road on west from the loop ramp's foot (closed), and the promenade on south of the old bridge.
	var west_y := func(x: float, z: float, _s: float) -> float:
		return _hermite(x, COUNTRY_X0, HAIRPIN_Y, 0.0, -900.0, _natural(-900.0, z) + GROUND_UNDER, 0.0) if x > -900.0 else _natural(x, z) + GROUND_UNDER
	_dress_road("CountryWest", [[Vector2(COUNTRY_X0, WEST_ROAD_Z), 0.0], [Vector2(-1500.0, WEST_ROAD_Z), 0.0], [Vector2(-2400.0, -60.0), 0.0]], ROAD_HALF, ROAD_HALF, 0, west_y, no_deck)
	_dress_road("PromenadeSouth", [[Vector2(PROMENADE_X, 206.0), 0.0], [Vector2(PROMENADE_X, 700.0), 0.0]], ROAD_HALF + PAVEMENT, ROAD_HALF, 2, func(x: float, _z: float, _s: float) -> float: return _town_ground(x) + GROUND_UNDER, no_deck)
	# The Kreuz's loops (one in each quadrant, single-lane ramps from the A 58 at grade up to the A 47).
	var lo: float = LAND_Y + GROUND_UNDER
	var off: float = 12.0 + KREUZ_R
	_kreuz_loop("SchleifeNE", Vector2(A58_NB + off, A47_WB - off), PI, lo, true)
	_kreuz_loop("SchleifeNW", Vector2(A58_SB - off, A47_WB - off), PI * 0.5, lo, false)
	_kreuz_loop("SchleifeSW", Vector2(A58_SB - off, A47_Z + off), 0.0, lo, true)
	_kreuz_loop("SchleifeSE", Vector2(A58_NB + off, A47_Z + off), PI * 1.5, lo, false)
	print("  dressing roads: %d" % _droads.size())


## A loop ramp: 270 degrees clockwise (seen from above, x east, z south) round `c` from the angle `phi0`, with a
## straight lane running on alongside the carriageway at each end: LOOP_LEAD_LOW at the A 58 (under the A 47's
## overpass, toward the next loop's lane, as a cloverleaf's weaving lanes), LOOP_LEAD_HIGH at the A 47 (short: past it
## the lane would hang off the overpass). Climbing from the A 58 (`lo`) to the A 47 when `up`, else coming down.
const LOOP_LEAD_LOW := 64.0
const LOOP_LEAD_HIGH := 16.0

func _kreuz_loop(name: String, c: Vector2, phi0: float, lo: float, up: bool) -> void:
	var arc: float = KREUZ_R * PI * 1.5
	var lead0: float = LOOP_LEAD_LOW if up else LOOP_LEAD_HIGH
	var lead1: float = LOOP_LEAD_HIGH if up else LOOP_LEAD_LOW
	var total: float = arc + lead0 + lead1
	var at_fn := func(s: float) -> Dictionary:
		var sa: float = clampf(s - lead0, 0.0, arc)
		var phi: float = phi0 + sa / KREUZ_R
		var p: Vector2 = c + Vector2(cos(phi), sin(phi)) * KREUZ_R
		# Moving with increasing phi: the heading is the tangent (-sin, cos).
		var tdir := Vector2(-sin(phi), cos(phi))
		if s < lead0:
			p -= tdir * (lead0 - s)
		elif s > lead0 + arc:
			p += tdir * (s - lead0 - arc)
		return {"p": p, "th": atan2(tdir.y, tdir.x)}
	var y_fn := func(x: float, _z: float, s: float) -> float:
		var hi_end: float = _a2_y(x)
		var t: float = clampf((s - lead0) / arc, 0.0, 1.0)
		var e: float = t * t * (3.0 - 2.0 * t)
		return lerpf(lo, hi_end, e) if up else lerpf(hi_end, lo, e)
	_dress_from(name, at_fn, total, LOOP_HALF, LOOP_HALF, 7, y_fn, func(_x: float, _z: float, _s: float) -> bool: return false, true, 2.0)


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


## The x axis keeps the fine step all along the river's banks out to the horizon (the river runs along z).
func _grid_axis_x() -> PackedFloat32Array:
	return _grid_axis(FINE_X)


func _build_heights() -> void:
	_grid_x = _grid_axis_x()
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
			var g: Vector2 = _grade(h, x, z)
			_heights[i] = g.x
			_road_d[i] = minf(g.y, 1.0e7)


## Ground height at any (x, z) from the built heightfield, on the mesh's own triangles.
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


## Woods: the floodplain forest (Auwald) up and down the river, copses in the fields, the east bank north of the A 47.
func _forest_w(x: float, z: float) -> float:
	var f: float = _forest_noise.get_noise_2d(x, z)
	var w := 0.0
	if x < -RIVER_HALF - 25.0 and x > DYKE_X + 30.0:
		# The floodplain: woods away from the meadows round the bridges, the Kirmes and the sheep's pasture.
		var open_z: float = 1.0 - smoothstep(380.0, 520.0, absf(z + 80.0))
		w = smoothstep(0.0, 0.25, f + 0.15) * (1.0 - open_z)
	elif x < DYKE_X - 40.0:
		w = smoothstep(0.30, 0.45, f) * 0.9
	elif x > 330.0 and z < -420.0:
		w = smoothstep(0.05, 0.3, f + 0.1)
	return w


func _open_land(x: float, z: float) -> float:
	var town: float = smoothstep(236.0, 260.0, x) * _town_w(z)
	var kirmes: float = _rect_weight(x, z, KIRMES_RECT, 10.0)
	var pads := 0.0
	for p in _pads:
		pads = maxf(pads, _rect_weight(x, z, [float(p[0].x) - float(p[1].x), float(p[0].y) - float(p[1].y), float(p[0].x) + float(p[1].x), float(p[0].y) + float(p[1].y)], 6.0))
	# The Kreuz: grass inside its loops and round the ramps.
	var kreuz: float = 1.0 - smoothstep(150.0, 200.0, Vector2(x - A58_X, z - A47_AXIS).length())
	return (1.0 - town) * (1.0 - kirmes) * (1.0 - pads) * (1.0 - kreuz)


func _masks(i: int, x: float, z: float, nrm_y: float) -> Color:
	var road_d: float = _road_d[i]
	var h: float = _heights[i]
	var near_road: float = smoothstep(12.0, 30.0, road_d)
	# Riprap: the town's bank up to the lower promenade, steep banks by the water, the quay's slope.
	var rock: float = 0.0
	if x > 0.0 and x < QUAY_X + 6.0 and h < LOWER_PROM_Y - 0.15 and _town_w(z) > 0.5:
		rock = 0.9
	if absf(x) < RIVER_HALF + 40.0 and h < 4.0 and nrm_y < 0.86:
		rock = maxf(rock, 0.8 * (1.0 - smoothstep(0.80, 0.9, nrm_y)))
	if x > QUAY_X - 1.0 and x < QUAY_X + 6.0 and _town_w(z) > 0.5:
		rock = 0.9
	# The Rhine's beaches (sand and gravel) and the river bed.
	var beach := 0.0
	if x < 0.0 and x > -RIVER_HALF - 30.0 and h < FLOOD_Y - 0.25:
		beach = 1.0 - smoothstep(FLOOD_Y - 1.0, FLOOD_Y - 0.25, h)
	if h < WATER_Y + 0.6:
		beach = maxf(beach, 1.0 - rock)
	if x > 0.0 and _town_w(z) < 0.5 and h < 2.0:
		beach = maxf(beach, (1.0 - smoothstep(1.0, 2.0, h)) * (1.0 - rock))
	var open: float = _open_land(x, z)
	var forest: float = _forest_w(x, z) * open * near_road
	var field := 0.0
	if x < DYKE_X - 24.0 or x > 640.0:
		field = open * (1.0 - forest) * smoothstep(-0.3, 0.0, _field_noise.get_noise_2d(x, z)) * smoothstep(18.0, 36.0, road_d)
	field *= smoothstep(0.9, 0.96, nrm_y)
	return Color(rock, beach * (1.0 - rock), field, forest * (1.0 - beach))


const BODIES := [
	["RheinMeadow", "grass", Color(0, 0, 0, 0)],
	["RheinBeach", "sand", Color(0.66, 0.60, 0.48, 0.55)],
	["RheinRiprap", "rock", Color(0.40, 0.39, 0.37, 0.5)],
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
			colors[i] = _masks(i, x, z, nrm.y)
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
				if absf(cen.x) > 2600.0 or absf(cen.z) > 2600.0:
					continue
				# The river bed under the water needs no collider beyond the shallows (carts sink there anyway).
				if cen.y < BED_Y + 1.5:
					continue
				var gk: float = (colors[tri[0]].g + colors[tri[1]].g + colors[tri[2]].g) / 3.0
				var rk: float = (colors[tri[0]].r + colors[tri[1]].r + colors[tri[2]].r) / 3.0
				var k: int = 0
				if rk > 0.6:
					k = 2
				elif gk > 0.5:
					k = 1
				var f: PackedVector3Array = faces[k]
				f.append(p0)
				f.append(p1)
				f.append(p2)
				faces[k] = f
	var near_mesh: ArrayMesh = _compact_mesh(verts, normals, colors, uvs, near_idx, _ground_mat)
	var inst := MeshInstance3D.new()
	inst.name = "RheinGroundMesh"
	inst.mesh = _save_res(near_mesh, "ground_visual")
	parent.add_child(inst)
	var far_mesh: ArrayMesh = _compact_mesh(verts, normals, colors, uvs, far_idx, _ground_mat)
	var far_inst := MeshInstance3D.new()
	far_inst.name = "RheinFarGround"
	far_inst.mesh = _save_res(far_mesh, "far_ground", "rheinuferfar_")
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
#  The Rhine
# ======================================================================================

func _build_rhine(root: Node3D) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://rhine_water.gdshader")
	var noise_tex := NoiseTexture2D.new()
	noise_tex.seamless = true
	noise_tex.as_normal_map = true
	noise_tex.width = 256
	noise_tex.height = 256
	var nz := FastNoiseLite.new()
	nz.frequency = 0.02
	noise_tex.noise = nz
	mat.set_shader_parameter("noise_tex", noise_tex)
	mat.set_shader_parameter("flow_dir", Vector2(0.0, -1.0))
	mat.set_shader_parameter("river_half", RIVER_HALF)
	var smat: Material = _save_res(mat, "rhine_water_material")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw: float = RIVER_HALF + 8.0
	var z0: float = -OUTER
	while z0 < OUTER - 0.01:
		var z1: float = minf(z0 + 150.0, OUTER)
		var x0: float = -hw
		while x0 < hw - 0.01:
			var x1: float = minf(x0 + 47.0, hw)
			var a := Vector3(x0, 0.0, z0)
			var b := Vector3(x1, 0.0, z0)
			var c := Vector3(x1, 0.0, z1)
			var d := Vector3(x0, 0.0, z1)
			for v in [a, b, c, a, c, d]:
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(v.x, v.z))
				st.add_vertex(v)
			x0 = x1
		z0 = z1
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, smat)
	var water := MeshInstance3D.new()
	water.name = "RheinWater"
	water.mesh = _save_res(mesh, "rhine_water", "rheinuferfar_")
	water.position = Vector3(0, WATER_Y, 0)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.set_meta(&"water_surface_y", WATER_Y)
	water.set_meta(&"water_bounds_min", Vector2(-hw, -OUTER))
	water.set_meta(&"water_bounds_max", Vector2(hw, OUTER))
	root.add_child(water)


# ======================================================================================
#  The lap's ribbons and the dressing roads' ribbons
# ======================================================================================

## [s0, s1, kind] along the lap (see kronburg_road.gdshader's kinds).
var _kinds_cache: Array = []

func _road_kinds() -> Array:
	if not _kinds_cache.is_empty():
		return _kinds_cache
	var b: Array = []
	for sg in segs:
		b.append(float(sg["s0"]))
	b.append(lap_len)
	# [promenade, E1, old bridge, W1, dyke, D1, west road, H1, H2, A 47, E0]
	_kinds_cache = [
		[b[0], RAMP_END, 7],
		[RAMP_END, b[2], 2],
		[b[2], b[3], 8],
		[b[3], b[7], 0],
		[b[7], b[11], 7],
	]
	return _kinds_cache


func _kind_at(kinds: Array, s: float) -> int:
	s = fposmod(s, lap_len)
	for k in kinds:
		if s >= float(k[0]) and s < float(k[1]):
			return int(k[2])
	return 7


## The ribbon's half width: the carriageway and, on the promenade, its pavements.
func _ribbon_half(kind: int) -> float:
	if kind == 2:
		return ROAD_HALF + PAVEMENT
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
							# No threshold where the Autobahn's kinds meet the country road's.
							st.set_color(Color(clampf(edge / 4.0, 0.0, 1.0) if kind == 2 or kind == 8 else 1.0, 0.0, 0.0, 1.0))
							st.set_uv(Vector2(lv, sv))
							st.set_uv2(Vector2(float(kind), ROAD_HALF))
							st.add_vertex(pos)
							_lap_faces.append(pos)
			var mesh: ArrayMesh = st.commit()
			mesh.surface_set_material(0, _road_mat)
			var mi := MeshInstance3D.new()
			mi.name = "Road_%d" % piece
			mi.mesh = _save_res(mesh, "road_%d" % piece, "rheinuferroad_")
			node.add_child(mi)
			piece += 1
			r0 = r1
	print("  lap ribbons: %d pieces" % piece)
	_build_dress_ribbons(root)


## The dressing roads' ribbons (in pieces of about 100m), each road's triangles one solid body ("Autobahn..."), the
## towpath-like tracks without one.
func _build_dress_ribbons(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Autobahnen"
	root.add_child(node)
	var pieces := 0
	for road in _droads:
		var pts: PackedVector3Array = road["pts"]
		var rts: PackedVector3Array = road["rts"]
		var ss: PackedFloat32Array = road["ss"]
		var half: float = road["half"]
		var chw: float = road["chw"]
		var kind: int = road["kind"]
		var lats: Array = [-half, -chw, -chw * 0.5, 0.0, chw * 0.5, chw, half] if half > chw + 0.1 else [-half, -half * 0.5, 0.0, half * 0.5, half]
		var faces := PackedVector3Array()
		var i0 := 0
		var n: int = pts.size()
		while i0 < n - 1:
			var i1: int = mini(i0 + 50, n - 1)
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in range(i0, i1):
				for j in range(lats.size() - 1):
					var quad: Array = [[i, lats[j]], [i, lats[j + 1]], [i + 1, lats[j]], [i + 1, lats[j + 1]]]
					for t in [[0, 2, 1], [1, 2, 3]]:
						for k in t:
							var ii: int = quad[k][0]
							var lv: float = quad[k][1]
							var pos: Vector3 = pts[ii] + rts[ii] * lv
							var fwd: Vector3 = (pts[mini(ii + 1, n - 1)] - pts[maxi(ii - 1, 0)]).normalized()
							st.set_normal(rts[ii].cross(fwd).normalized())
							st.set_color(Color(1.0, 0.0, 0.0, 1.0))
							st.set_uv(Vector2(lv, ss[ii]))
							st.set_uv2(Vector2(float(kind), chw))
							st.add_vertex(pos)
							faces.append(pos)
			var mesh: ArrayMesh = st.commit()
			mesh.surface_set_material(0, _road_mat)
			var mi := MeshInstance3D.new()
			mi.name = "%s_%d" % [road["name"], i0]
			mi.mesh = _save_res(mesh, "%s_%d" % [String(road["name"]).to_snake_case(), i0], "rheinuferroad_")
			mi.visibility_range_end = 2600.0
			node.add_child(mi)
			pieces += 1
			i0 = i1
		if bool(road["solid"]):
			var body := StaticBody3D.new()
			body.name = "Autobahn%sBody" % road["name"]
			body.set_meta(&"surface", "asphalt")
			var cs := CollisionShape3D.new()
			var sh := ConcavePolygonShape3D.new()
			sh.backface_collision = true
			sh.set_faces(faces)
			cs.shape = _save_res(sh, "%s_shape" % String(road["name"]).to_snake_case())
			body.add_child(cs)
			node.add_child(body)
	print("  dressing ribbons: %d pieces" % pieces)


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
#  Structures the generator builds itself: girders under its decks, the edges' barriers and their colliders
# ======================================================================================

## A concrete box girder under a deck that follows a polyline: `pts` along its middle (the road surface), `rts` right of
## travel, from `l0` to `l1` across (right +), `depth` deep, its top `top_drop` under the surface. Its cornices stand
## 0.3m over the surface at both edges. Added to `st` (the "concrete" mesh) with UVs in metres.
func _girder(st: SurfaceTool, pts: PackedVector3Array, rts: PackedVector3Array, l0: float, l1: float, depth: float, top_drop := 0.06) -> void:
	var n: int = pts.size()
	# The section (lateral, height under the surface): a deck slab with cantilevers, a box below, cornice upstands.
	var w: float = l1 - l0
	var box0: float = l0 + w * 0.22
	var box1: float = l1 - w * 0.22
	var sec := [
		Vector2(l0, 0.3), Vector2(l0, -0.55), Vector2(box0, -0.75), Vector2(box0 + 0.6, -depth), Vector2(box1 - 0.6, -depth),
		Vector2(box1, -0.75), Vector2(l1, -0.55), Vector2(l1, 0.3), Vector2(l1 - 0.45, 0.3), Vector2(l1 - 0.45, -top_drop),
		Vector2(l0 + 0.45, -top_drop), Vector2(l0 + 0.45, 0.3),
	]
	var m: int = sec.size()
	var run := 0.0
	for i in range(n - 1):
		var a0: Vector3 = pts[i]
		var a1: Vector3 = pts[i + 1]
		var r0: Vector3 = rts[i]
		var r1: Vector3 = rts[i + 1]
		var u0: float = run
		var u1: float = run + a0.distance_to(a1)
		run = u1
		for k in range(m):
			var ka: Vector2 = sec[k]
			var kb: Vector2 = sec[(k + 1) % m]
			var p00: Vector3 = a0 + r0 * ka.x + Vector3(0, ka.y, 0)
			var p01: Vector3 = a0 + r0 * kb.x + Vector3(0, kb.y, 0)
			var p10: Vector3 = a1 + r1 * ka.x + Vector3(0, ka.y, 0)
			var p11: Vector3 = a1 + r1 * kb.x + Vector3(0, kb.y, 0)
			var v: float = ka.distance_to(kb)
			# The section runs counter-clockwise seen from behind (looking along travel, right on the right): this order
			# faces out ((c - a) x (b - a) = fwd x the section's edge, its outward side).
			_quad(st, p00, p01, p11, p10, Vector2(u0, 0.0), Vector2(u0, v), Vector2(u1, v), Vector2(u1, 0.0))
	# End caps.
	for e in [0, n - 1]:
		var a: Vector3 = pts[e]
		var r: Vector3 = rts[e]
		var poly := PackedVector2Array()
		for k in range(m):
			poly.append(sec[k])
		var tri: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
		for t in range(0, tri.size(), 3):
			var q: Array = [tri[t], tri[t + 1], tri[t + 2]]
			if e == 0:
				q = [tri[t], tri[t + 2], tri[t + 1]]
			for idx in q:
				var sp: Vector2 = sec[idx]
				st.set_color(GIRDER_GREY)
				st.set_uv(sp)
				st.add_vertex(a + r * sp.x + Vector3(0, sp.y, 0))


## A quad a, b, c, d as two triangles; its front face is the side from which a, b, c run clockwise.
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
	for pair in [[a, ua], [b, ub], [c, uc], [a, ua], [c, uc], [d, ud]]:
		st.set_color(GIRDER_GREY)
		st.set_uv(pair[1])
		st.add_vertex(pair[0])


const GIRDER_GREY := Color(0.56, 0.56, 0.54)
## RheinBridgeKit's bearings: the pier's cap and the abutment's shelf stand this far under a girder's underside.
const BEARING_H := 0.4
var _concrete_mat: Material

func _concrete() -> Material:
	if _concrete_mat == null:
		var m := ShaderMaterial.new()
		m.shader = load("res://hut_masonry.gdshader")
		m.set_shader_parameter("style", 8)
		_concrete_mat = _save_res(m, "girder_concrete")
	return _concrete_mat


## The structures under the lap and the dressing roads that the bridge kit doesn't build: the overpasses over the A 58,
## the A 47's viaduct onto the Harfenbrücke, the exit ramp's viaduct. Girders here, piers and abutments from the kit.
var _decks: Array = []

func _plan_decks() -> void:
	# [name, polyline points (Vector3 road surface), rights, l0, l1, pier spacing]
	var lap_part := func(cond: Callable, l0: float, l1: float, spacing: float, name: String) -> void:
		var pts := PackedVector3Array()
		var rts := PackedVector3Array()
		var s := 0.0
		var run := false
		var k := 0
		while s <= lap_len:
			var on: bool = cond.call(s)
			if on:
				pts.append(_pt(s))
				rts.append(_rt(s))
				run = true
			elif run:
				_decks.append([name + str(k), pts, rts, l0, l1, spacing])
				k += 1
				pts = PackedVector3Array()
				rts = PackedVector3Array()
				run = false
			s += 2.0
		if run:
			_decks.append([name + str(k), pts, rts, l0, l1, spacing])
	# The west road's overpass and the A 47's (both carriageways and the median on one deck).
	lap_part.call(func(s: float) -> bool: return _seg_index(s) == 6 and _lap_on_deck(s), -ROAD_HALF - 1.2, ROAD_HALF + 1.2, 45.0, "WestOverpass")
	lap_part.call(func(s: float) -> bool:
		var p: Vector2 = _at(s)["p"]
		return _seg_index(s) == 9 and p.x > OVER_A58.x - 1.0 and p.x < OVER_A58.y + 1.0, -(A47_Z - A47_WB) - ROAD_HALF - 1.2, ROAD_HALF + 1.2, 45.0, "A47Overpass")
	lap_part.call(func(s: float) -> bool:
		var p: Vector2 = _at(s)["p"]
		return _seg_index(s) == 9 and p.x > A47_VIADUCT.x - 1.0 and p.x < A47_VIADUCT.y + 1.0, -(A47_Z - A47_WB) - ROAD_HALF - 1.2, ROAD_HALF + 1.2, 25.0, "A47Viaduct")
	lap_part.call(func(s: float) -> bool:
		var p: Vector2 = _at(s)["p"]
		var i: int = _seg_index(s)
		return (i == 10 or i == 0) and p.x > HARP_X.y - 1.0 and _lap_on_deck(s), -ROAD_HALF - 1.2, ROAD_HALF + 1.2, 32.0, "AusfahrtSpan")
	# The A 47 east of the Harfenbrücke while it is still high (both carriageways' girder along the motorway's axis).
	for part in [[HARP_X.y, A47_EB_EAST, -(A47_AXIS - A47_WB) - ROAD_HALF - 1.2, -4.0, "A47EastWB"], [A47_EB_EAST, 700.0, -(A47_AXIS - A47_WB) - ROAD_HALF - 1.2, (A47_Z - A47_AXIS) + ROAD_HALF + 1.2, "A47EastViaduct"]]:
		var east := PackedVector3Array()
		var east_r := PackedVector3Array()
		var x: float = part[0]
		while x <= float(part[1]):
			var y: float = _a2_y(x)
			if y - _natural(x, A47_AXIS) < 2.2:
				break
			east.append(Vector3(x, y, A47_AXIS))
			east_r.append(Vector3(0, 0, 1))
			x += 2.0
		if east.size() > 1:
			_decks.append([part[4], east, east_r, part[2], part[3], 40.0])
	print("  decks: %d" % _decks.size())


func _build_decks(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Viaducts"
	root.add_child(node)
	var body := StaticBody3D.new()
	body.name = "ViaductsBody"
	body.set_meta(&"surface", "rock")
	node.add_child(body)
	var bridge_kit: Script = _kit_script("res://RheinBridgeKit.gd")
	for d in _decks:
		var pts: PackedVector3Array = d[1]
		var rts: PackedVector3Array = d[2]
		var l0: float = d[3]
		var l1: float = d[4]
		if pts.size() < 2:
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_girder(st, pts, rts, l0, l1, 2.4)
		st.generate_normals()
		st.generate_tangents()
		var mesh: ArrayMesh = st.commit()
		mesh.surface_set_material(0, _concrete())
		var mi := MeshInstance3D.new()
		mi.name = String(d[0])
		mi.mesh = _save_res(mesh, "girder_" + String(d[0]).to_snake_case())
		node.add_child(mi)
		# Barrier colliders along both edges (the cornices' upstands, 1.1m over the road).
		_edge_boxes(body, pts, rts, l0 + 0.25, 1.15)
		_edge_boxes(body, pts, rts, l1 - 0.25, 1.15)
		# Piers every `spacing` metres (not at the ends: the abutments), down to the ground; and the abutments.
		var spacing: float = d[5]
		var total: float = 0.0
		for i in range(pts.size() - 1):
			total += pts[i].distance_to(pts[i + 1])
		var count: int = maxi(1, int(round(total / spacing)))
		var acc := 0.0
		var next: float = total / float(count)
		for i in range(1, pts.size()):
			acc += pts[i - 1].distance_to(pts[i])
			if acc >= next - 0.01 and next < total - 1.0:
				var p: Vector3 = pts[i]
				var r: Vector3 = rts[i]
				var mid: Vector3 = p + r * ((l0 + l1) * 0.5)
				var foot: float = _ground_at(mid.x, mid.z)
				_pier(node, body, bridge_kit, mid, r, p.y - 0.06 - 2.4 - BEARING_H, foot, (l1 - l0) * 0.5)
				next += total / float(count)
		for e in [0, pts.size() - 1]:
			var p2: Vector3 = pts[e]
			if absf(p2.x - HARP_X.x) < 4.0 or absf(p2.x - HARP_X.y) < 4.0:
				continue
			# Where this deck runs on into another (the A 47's girders east of the river), no abutment.
			var joined := false
			for d2 in _decks:
				if d2 == d:
					continue
				var q: PackedVector3Array = d2[1]
				if q.size() > 1 and (q[0].distance_to(p2) < 4.0 or q[q.size() - 1].distance_to(p2) < 4.0):
					joined = true
			if joined:
				continue
			var r2: Vector3 = rts[e]
			var mid2: Vector3 = p2 + r2 * ((l0 + l1) * 0.5)
			var away: Vector3 = (pts[1] - pts[0]).normalized() if e == 0 else (pts[e - 1] - pts[e]).normalized()
			_abutment(node, body, bridge_kit, mid2, away, (l1 - l0) * 0.5, p2.y, _ground_at(mid2.x, mid2.z))


func _edge_boxes(body: StaticBody3D, pts: PackedVector3Array, rts: PackedVector3Array, lat: float, h: float) -> void:
	var i := 0
	var n: int = pts.size()
	while i < n - 1:
		var j: int = mini(i + 4, n - 1)
		var a: Vector3 = pts[i] + rts[i] * lat
		var b: Vector3 = pts[j] + rts[j] * lat
		var len: float = a.distance_to(b)
		if len > 0.1:
			var cs := CollisionShape3D.new()
			var bx := BoxShape3D.new()
			bx.size = Vector3(0.5, h, len + 0.4)
			cs.shape = bx
			var fwd: Vector3 = (b - a) / len
			var up := Vector3.UP
			var x: Vector3 = up.cross(fwd).normalized()
			cs.transform = Transform3D(Basis(x, up, fwd), (a + b) * 0.5 + Vector3(0, h * 0.5, 0))
			body.add_child(cs)
		i = j


## A pier under a deck: the bridge kit's when it exists, else a plain column. `r` is the deck's right (across).
func _pier(node: Node3D, body: StaticBody3D, kit_script: Script, at: Vector3, r: Vector3, top_y: float, foot_y: float, half: float) -> void:
	var fwd: Vector3 = Vector3.UP.cross(r).normalized()
	var xf := Transform3D(Basis(r, Vector3.UP, -fwd), Vector3(at.x, 0.0, at.z))
	if kit_script != null and _has_fn(kit_script, "viaduct_pier"):
		_add_prop_game(_cell_key("piers", at, 300.0), kit_script, xf, func(pk, kit, _labels): kit_script.viaduct_pier(pk, kit, top_y, foot_y - 2.0, half, 0))
	else:
		var bm := BoxMesh.new()
		bm.size = Vector3(half * 1.3, top_y - foot_y + 2.0, 2.6)
		var mi := MeshInstance3D.new()
		mi.mesh = bm
		mi.material_override = _concrete()
		mi.transform = Transform3D(xf.basis, Vector3(at.x, (top_y + foot_y - 2.0) * 0.5, at.z))
		node.add_child(mi)
	# Its collider: a column 2.6m thick across the deck's middle third.
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(half * 0.9, maxf(top_y - foot_y, 0.5), 2.8)
	cs.shape = bx
	cs.transform = Transform3D(xf.basis, Vector3(at.x, (top_y + foot_y) * 0.5, at.z))
	body.add_child(cs)


## An abutment where a deck meets its embankment: the kit's (front face toward the span, `away`), its bearing shelf
## BEARING_H under the girder's underside, the ballast wall up to just under the road (`road_y`).
func _abutment(_node: Node3D, body: StaticBody3D, kit_script: Script, at: Vector3, away: Vector3, half: float, road_y: float, foot_y: float) -> void:
	if road_y - foot_y < 3.0:
		return
	var z: Vector3 = Vector3(away.x, 0.0, away.z).normalized()
	var x: Vector3 = Vector3.UP.cross(z).normalized()
	var xf := Transform3D(Basis(x, Vector3.UP, z), Vector3(at.x, 0.0, at.z))
	var shelf: float = road_y - 0.06 - 2.4 - BEARING_H
	if kit_script != null and _has_fn(kit_script, "abutment"):
		_add_prop_game(_cell_key("widerlager", at, 300.0), kit_script, xf, func(pk, kit, _labels): kit_script.abutment(pk, kit, half, shelf, foot_y - 1.5, 8.0))
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(half * 2.0, maxf(shelf - foot_y, 0.3), 2.4)
	cs.shape = bx
	cs.transform = Transform3D(xf.basis, Vector3(at.x, (shelf + foot_y) * 0.5, at.z) - z * 1.2)
	body.add_child(cs)


# ======================================================================================
#  Gameplay: the start, the gates, boost pads, the dyke's kicker
# ======================================================================================

func _place_gameplay(root: Node3D) -> void:
	var gate_scene: PackedScene = load("res://CheckpointGate.tscn")
	var spawn_scene: PackedScene = load("res://SpawnIndicator.tscn")
	var s_fin: float = _closest_s(Vector2(PROMENADE_X, FINISH_Z))
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
	# Gates: on the old bridge, along the dyke, the west road, the loop ramp's apex, the A 47's embankment, the Harfenbrücke.
	var at: Array = [
		_closest_s(Vector2(-40.0, OLD_BRIDGE_Z)),
		_closest_s(Vector2(DYKE_X, 120.0)),
		_closest_s(Vector2(-470.0, WEST_ROAD_Z)),
		_closest_s(Vector2(-840.0, -273.5)),
		_closest_s(Vector2(-450.0, A47_Z)),
		_closest_s(Vector2(80.0, A47_Z)),
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
		["Boost_Promenade", _closest_s(Vector2(PROMENADE_X, 70.0)), -2.6],
		["Boost_Dyke", _closest_s(Vector2(DYKE_X, DYKE_JUMP_Z + 45.0)), 0.0],
		["Boost_West", _closest_s(Vector2(-420.0, WEST_ROAD_Z)), 2.6],
		["Boost_A47", _closest_s(Vector2(-650.0, A47_Z)), -2.6],
	]
	for p in pads:
		var b = boost_scene.instantiate()
		b.name = p[0]
		var sp2: Dictionary = _spot(p[1], p[2], 0.08)
		b.position = sp2["pos"]
		b.rotation_degrees = Vector3(0, sp2["yaw"], 0)
		bps.add_child(b)
	_build_jump(root)


## The kicker on the dyke road: a timber jump as wide as the road (heading north).
const DYKE_JUMP_Z := 60.0
const JUMP := [22.0, 3.8, 0.5]

func _build_jump(root: Node3D) -> void:
	var toe: float = _closest_s(Vector2(DYKE_X, DYKE_JUMP_Z))
	var j: Node3D = (load("res://WoodenRamp.tscn") as PackedScene).instantiate()
	j.name = "DeichJump"
	var sp: Dictionary = _spot(toe, 0.0, 0.0)
	j.position = sp["pos"]
	j.rotation_degrees = Vector3(0, sp["yaw"], 0)
	j.set("length", JUMP[0])
	j.set("height", JUMP[1])
	j.set("curve", JUMP[2])
	j.set("width", ROAD_HALF * 2.0)
	j.set("trestle", true)
	j.set("wood_color", Color(0.52, 0.42, 0.30))
	root.add_child(j)
	var lp: Dictionary = _spot(toe + float(JUMP[0]), 0.0, 0.0)
	var slope: float = float(JUMP[1]) / float(JUMP[0]) * (1.0 + float(JUMP[2]))
	var lip: Vector3 = (lp["pos"] as Vector3) + Vector3(0, float(JUMP[1]), 0)
	(root.get_node("TrackPath") as Node).set_meta(&"jump_lips", [{"name": "DeichJump", "lip": lip, "dir": ((lp["fwd"] as Vector3) + Vector3(0, slope, 0)).normalized()}])


# ======================================================================================
#  Sky and light: a summer evening, the sun low in the west-south-west
# ======================================================================================

const HAZE := Color(0.82, 0.80, 0.76)

func _build_environment(root: Node3D) -> void:
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://sky_tropical_cumulus.gdshader")
	sky_mat.set_shader_parameter("sky_top", Color(0.22, 0.40, 0.70))
	sky_mat.set_shader_parameter("sky_horizon", Color(0.86, 0.80, 0.70))
	sky_mat.set_shader_parameter("ground_horizon", HAZE)
	sky_mat.set_shader_parameter("ground_bottom", Color(0.40, 0.42, 0.36))
	sky_mat.set_shader_parameter("sky_curve", 0.42)
	sky_mat.set_shader_parameter("horizon_haze", HAZE)
	sky_mat.set_shader_parameter("haze_strength", 0.85)
	sky_mat.set_shader_parameter("haze_height", 0.13)
	sky_mat.set_shader_parameter("sun_tint", Color(1.0, 0.86, 0.62))
	sky_mat.set_shader_parameter("sun_disc_degrees", 1.1)
	sky_mat.set_shader_parameter("sun_glow", 0.55)
	sky_mat.set_shader_parameter("sun_horizon_tint", Color(1.0, 0.70, 0.42))
	sky_mat.set_shader_parameter("sun_horizon_glow", 0.35)
	sky_mat.set_shader_parameter("cloud_lit", Color(1.0, 0.93, 0.82))
	sky_mat.set_shader_parameter("cloud_shade", Color(0.56, 0.56, 0.64))
	sky_mat.set_shader_parameter("cloud_coverage", 0.36)
	sky_mat.set_shader_parameter("cloud_opacity", 0.9)
	sky_mat.set_shader_parameter("cloud_scale", 1.2)
	sky_mat.set_shader_parameter("cloud_seed", 31.7)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.5
	env.ambient_light_color = Color(0.92, 0.90, 0.88)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = HAZE
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.25
	env.fog_density = 1.0
	env.fog_depth_begin = 400.0
	env.fog_depth_end = 4600.0
	env.fog_depth_curve = 1.5
	env.fog_sky_affect = 0.05
	env.fog_aerial_perspective = 0.3
	env_node.environment = env
	root.add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	# Early evening: the sun in the west-south-west, about 24 degrees up, warm.
	sun.rotation_degrees = Vector3(-24.0, -112.0, 0.0)
	sun.light_color = Color(1.0, 0.86, 0.68)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 320.0
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
	print("=== Rheinufer (Kronburg GP) Level Generation ===")
	var t_start: int = Time.get_ticks_msec()
	var gen := DirAccess.open("res://generated/")
	if gen:
		var cleared := 0
		for f in gen.get_files():
			if f.begins_with("rheinufer") and (f.ends_with(".res") or f.ends_with(".tscn")):
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
	_plan_pads()
	var fp: Array = _fillet_path(CORNERS, true)
	segs = fp[0]
	lap_len = fp[1]
	_plan_road_heights()
	var track_path := Path3D.new()
	track_path.name = "TrackPath"
	track_path.curve = _build_main_curve()
	level.add_child(track_path)
	_plan_dressing_roads()
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
	gm.set_shader_parameter("g_beach", true)
	gm.set_shader_parameter("rock_tint", Color(0.62, 0.62, 0.64))
	_ground_mat = _save_res(gm, "ground_material") as ShaderMaterial
	_road_mat = _road_material()
	var terrain := Node3D.new()
	terrain.name = "RheinTerrain"
	level.add_child(terrain)
	_build_terrain(terrain)
	print("  terrain built (%.1fs)" % ((Time.get_ticks_msec() - t_start) / 1000.0))
	_build_rhine(terrain)
	_build_roads(level)
	_build_lap_body(level)
	_plan_decks()
	_build_decks(level)
	_build_environment(level)
	_place_gameplay(level)
	_build_dressing(level)

	level.set("track_path", track_path)
	level._setup_checkpoints()
	var chunked: int = MeshChunker.chunk_scene(level, "res://generated/" + RES_PREFIX, "res://generated/rheinufer_chunks", MESH_CHUNK_CELL)
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

func _build_dressing(root: Node3D) -> void:
	_bridge_kit = _kit_script("res://RheinBridgeKit.gd")
	_ship_kit = _kit_script("res://RheinShipKit.gd")
	_land_kit = _kit_script("res://NiederrheinKit.gd")
	_stadt_kit = _kit_script("res://RheinStadtKit.gd")
	_town = load("res://KronburgTownKit.gd")
	_works = load("res://SteelworksKit.gd")
	_build_bridges(root)
	_build_start(root)
	_build_quay(root)
	_build_town(root)
	_build_kirmes(root)
	_build_windmill(root)
	_build_sheep(root)
	_build_farms()
	_build_power(root)
	_build_barriers(root)
	_build_closures(root)
	_build_autobahn_furniture()
	_build_river_furniture()
	_build_traffic(root)
	_build_ships(root)
	CrowdPlacer.build(root, _people, SPECTATOR_SCALE, SPECTATOR_SKIN, 9121, func(res: Resource, n: String) -> Resource: return _save_res(res, n, "rheinufercrowd_"))
	_flush_batches(root)
	_build_sounds(root)
	_build_delineators(root)
	_build_woods(root)


var _bridge_kit: Script
var _ship_kit: Script
var _land_kit: Script
var _stadt_kit: Script
var _town: Script
var _works: Script


# ======================================================================================
#  The two Rhine bridges (RheinBridgeKit, game metres) and their edges' colliders
# ======================================================================================

func _build_bridges(root: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "BridgeEdgesBody"
	body.set_meta(&"surface", "rock")
	root.add_child(body)
	# The old bridge: its kerb barriers at |z| 7.5..8.3 either side of the lap.
	var s_old0: float = float(segs[2]["s0"])
	var s_old1: float = s_old0 + float(segs[2]["len"])
	_lap_edge_boxes(body, s_old0 - 2.0, s_old1 - 1.0, ROAD_HALF + 0.4, 1.1)
	_lap_edge_boxes(body, s_old0 - 2.0, s_old1 - 1.0, -ROAD_HALF - 0.4, 1.1)
	# The Harfenbrücke: the outer railing and the median barrier (the lap's left).
	var s9: float = float(segs[9]["s0"])
	var s_h0: float = s9 + (HARP_X.x - float((segs[9]["p0"] as Vector2).x))
	var s_h1: float = s9 + (HARP_X.y - float((segs[9]["p0"] as Vector2).x))
	_lap_edge_boxes(body, s_h0, s_h1, ROAD_HALF + 0.5, 1.3)
	_lap_edge_boxes(body, s_h0, s_h1, -ROAD_HALF - 0.85, 1.1)
	for tx in [200.0, -200.0]:
		for tz in [-14.5, 14.5]:
			var g: float = _ground_at(tx, OLD_BRIDGE_Z + tz)
			var cs := CollisionShape3D.new()
			var bx := BoxShape3D.new()
			bx.size = Vector3(10.2, 42.0, 10.0)
			cs.shape = bx
			cs.position = Vector3(tx, g + 19.0, OLD_BRIDGE_Z + tz)
			body.add_child(cs)
	if _bridge_kit == null:
		return
	var old_deck_fn := func(x: float) -> float: return old_deck(x)
	var old_ground := func(x: float) -> float: return _ground_at(x, OLD_BRIDGE_Z)
	if _has_fn(_bridge_kit, "old_bridge"):
		_add_prop_game("old_bridge", _bridge_kit, Transform3D(Basis(), Vector3(0, 0, OLD_BRIDGE_Z)), func(pk, kit, labels):
			_bridge_kit.old_bridge(pk, kit, labels, old_deck_fn, old_ground))
		_check_old_bridge(old_deck_fn, old_ground)
	var harp_fn := func(x: float) -> float: return harp_deck(x)
	var harp_ground := func(x: float) -> float: return _ground_at(x, A47_AXIS)
	if _has_fn(_bridge_kit, "harp_bridge"):
		_add_prop_game("harp_bridge", _bridge_kit, Transform3D(Basis(), Vector3(0, 0, A47_AXIS)), func(pk, kit, labels):
			_bridge_kit.harp_bridge(pk, kit, labels, harp_fn, harp_ground))


## Builds the old bridge again on its own (its frame, the real ground) and errors on anything standing over the road
## (RheinBridgeKit.check_clearance, OB_BANDS): its end piers' plinths and the last flood arch, buried in the dyke, had stood
## up across the road at both heads.
func _check_old_bridge(deck_fn: Callable, ground_fn: Callable) -> void:
	if not _has_fn(_bridge_kit, "check_clearance"):
		return
	var pk: PropKit = _bridge_kit.new_kit(1.0)
	var kit := {}
	pk.set_frame(Transform3D())
	_bridge_kit.old_bridge(pk, kit, [], deck_fn, ground_fn)
	var res: Array = _bridge_kit.check_clearance(kit, deck_fn, _bridge_kit.OB_BANDS, _bridge_kit.OB_WEST - 3.0, _bridge_kit.OB_EAST + 3.0)
	if int(res[0]) > 0:
		push_error("Alte Rheinbrücke: %d triangles over the road: %s" % [res[0], ", ".join(res[1])])
	else:
		print("  old bridge: the road is clear")


## Box colliders along the lap from s0 to s1 at `lat` (right of the line), `h` high over the road.
func _lap_edge_boxes(body: StaticBody3D, s0: float, s1: float, lat: float, h: float, thick := 0.5) -> void:
	var s: float = s0
	while s < s1 - 0.5:
		var sb: float = minf(s + 6.0, s1)
		var a: Vector3 = _pt(s) + _rt(s) * lat
		var b: Vector3 = _pt(sb) + _rt(sb) * lat
		var len: float = a.distance_to(b)
		if len > 0.1:
			var cs := CollisionShape3D.new()
			var bx := BoxShape3D.new()
			bx.size = Vector3(thick, h + 0.6, len + 0.3)
			cs.shape = bx
			var fwd: Vector3 = (b - a) / len
			var x: Vector3 = Vector3.UP.cross(fwd).normalized()
			cs.transform = Transform3D(Basis(x, x.cross(fwd).normalized() * -1.0, fwd).orthonormalized(), (a + b) * 0.5 + Vector3(0, h * 0.5 - 0.3, 0))
			body.add_child(cs)
		s = sb


# ======================================================================================
#  Guardrails along the lap's embankments and the median (RheinBridgeKit's Schutzplanke and Betonschutzwand)
# ======================================================================================

## [from (x, z), to (x, z), lateral (right +), kind]: the stretches of the lap fenced in where it is not on a structure.
func _barrier_runs() -> Array:
	var s9: float = float(segs[9]["s0"])
	var x9: float = float((segs[9]["p0"] as Vector2).x)
	var a47 := func(x: float) -> float: return s9 + (x - x9)
	var s6: float = float(segs[6]["s0"])
	var x6: float = float((segs[6]["p0"] as Vector2).x)
	var west := func(x: float) -> float: return s6 + (x6 - x)
	var s7: float = float(segs[7]["s0"])
	var s9e: float = s9 + float(segs[9]["len"])
	var runs: Array = []
	# The A 47: the median's concrete barrier all the way from the loop ramp to the Harfenbrücke, the guardrail outside
	# on the embankments.
	runs.append([a47.call(-686.0), a47.call(HARP_X.x), -ROAD_HALF - 0.85, "concrete"])
	runs.append([a47.call(-686.0), a47.call(OVER_A58.x), ROAD_HALF + 0.9, "guardrail"])
	runs.append([a47.call(OVER_A58.y), a47.call(A47_VIADUCT.x), ROAD_HALF + 0.9, "guardrail"])
	# The loop ramp, both sides (from where the west road leaves the overpass).
	runs.append([west.call(OVER_A58.x), s9, ROAD_HALF + 0.9, "guardrail"])
	runs.append([west.call(OVER_A58.x), s9, -ROAD_HALF - 0.9, "guardrail"])
	# The west road on its embankment from the dyke to the overpass.
	runs.append([west.call(-405.0), west.call(OVER_A58.y), ROAD_HALF + 0.9, "guardrail"])
	runs.append([west.call(-405.0), west.call(OVER_A58.y), -ROAD_HALF - 0.9, "guardrail"])
	# The exit ramp from the Harfenbrücke's end down to the promenade (beyond its viaduct).
	var ramp_end: float = RAMP_END - 30.0
	runs.append([s9e + 6.0, lap_len + ramp_end, ROAD_HALF + 0.9, "guardrail"])
	runs.append([s9e + 6.0, lap_len + ramp_end, -ROAD_HALF - 0.9, "guardrail"])
	var out: Array = []
	for r in runs:
		var s0: float = r[0]
		var s1: float = r[1]
		if s1 < s0:
			var t: float = s0
			s0 = s1
			s1 = t
		out.append([s0, s1, r[2], r[3]])
	return out


func _build_barriers(root: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "LapBarriersBody"
	body.set_meta(&"surface", "rock")
	root.add_child(body)
	var pieces := 0
	for r in _barrier_runs():
		var s0: float = r[0]
		var s1: float = r[1]
		var lat: float = r[2]
		var kind: String = r[3]
		_lap_edge_boxes(body, s0, s1, lat, 1.0 if kind == "guardrail" else 1.15)
		var piece: float = 4.0 * PROP_SCALE
		var s: float = s0
		while s < s1 - 0.5:
			var sm: float = minf(s + piece * 0.5, s1)
			if _lap_on_deck(fposmod(sm, lap_len)):
				s += piece
				continue
			var a: Vector3 = _pt(s) + _rt(s) * lat
			var b: Vector3 = _pt(minf(s + piece, s1)) + _rt(minf(s + piece, s1)) * lat
			var len: float = a.distance_to(b)
			if len < 0.5:
				break
			var fwd: Vector3 = (b - a) / len
			# The piece's frame: x along the run, z away from the road (toward lat's side), y up.
			var side: Vector3 = _rt(sm) * signf(lat)
			var y_ax: Vector3 = Vector3.UP
			var x_ax: Vector3 = fwd
			var z_ax: Vector3 = x_ax.cross(y_ax).normalized()
			# The kit's guardrail faces its +z (beam in front, posts behind): toward the road.
			if z_ax.dot(side) > 0.0:
				z_ax = -z_ax
			y_ax = z_ax.cross(x_ax).normalized()
			if y_ax.y < 0.0:
				y_ax = -y_ax
			var xf := Transform3D(Basis(x_ax, y_ax, z_ax), a)
			var life: float = len / PROP_SCALE
			if kind == "guardrail":
				_add_prop(_cell_key("leitplanke", a, 300.0), _bridge_kit if _bridge_kit else _works, xf, func(pk, kit, _l): _kit_call(_bridge_kit, "guardrail", [pk, kit, life]))
			else:
				_add_prop(_cell_key("betonwand", a, 300.0), _bridge_kit if _bridge_kit else _works, xf, func(pk, kit, _l): _kit_call(_bridge_kit, "concrete_barrier", [pk, kit, life]))
			pieces += 1
			s += piece
	print("  barriers: %d pieces" % pieces)


# ======================================================================================
#  Race closures where roads leave or join the lap (Vollsperrung), solid across the closed carriageway
# ======================================================================================

func _build_closures(root: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "ClosuresBody"
	body.set_meta(&"surface", "rock")
	root.add_child(body)
	# [at (x, z), the direction the closed road leads away from the lap, half width]
	var list: Array = [
		[Vector2(A47_EB_END - 6.0, A47_Z), Vector2(-1, 0), ROAD_HALF],
		[Vector2(A47_EB_EAST + 6.0, A47_Z), Vector2(1, 0), ROAD_HALF],
		[Vector2(COUNTRY_X0 - 6.0, WEST_ROAD_Z), Vector2(-1, 0), ROAD_HALF],
		[Vector2(PROMENADE_X, 212.0), Vector2(0, 1), ROAD_HALF + PAVEMENT],
	]
	# The loops that join or leave the lap's carriageway: closed at their lap end.
	for road in _droads:
		var nm: String = road["name"]
		if nm == "SchleifeSW" or nm == "SchleifeSE":
			var pts: PackedVector3Array = road["pts"]
			var k: int = pts.size() - 6 if nm == "SchleifeSW" else 5
			var a: Vector3 = pts[k]
			var b: Vector3 = pts[k + (1 if nm == "SchleifeSE" else -1)]
			var d := Vector2(b.x - a.x, b.z - a.z).normalized()
			list.append([Vector2(a.x, a.z), d, LOOP_HALF])
	for c in list:
		var at: Vector2 = c[0]
		var away: Vector2 = c[1]
		var half: float = c[2]
		var y: float = _ground_or_road(at)
		var face := Vector3(-away.x, 0, -away.y)
		var xf := _facing(face, Vector3(at.x, y, at.y))
		var life_w: float = half * 2.0 / PROP_SCALE
		_add_prop(_cell_key("sperre", xf.origin, 400.0), _bridge_kit if _bridge_kit else _works, xf, func(pk, kit, labels): _kit_call(_bridge_kit, "race_closure", [pk, kit, labels, life_w]))
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(half * 2.0 + 1.0, 1.6, 1.2)
		cs.shape = bx
		cs.transform = Transform3D(xf.basis, xf.origin + Vector3(0, 0.8, 0))
		body.add_child(cs)


## The height of whatever road surface is at (x, z) (the dressing roads' samples), else the ground.
func _ground_or_road(at: Vector2) -> float:
	var best := 1e9
	var y: float = _ground_at(at.x, at.y)
	for road in _droads:
		var pts: PackedVector3Array = road["pts"]
		for i in range(0, pts.size(), 2):
			var d: float = Vector2(pts[i].x, pts[i].z).distance_squared_to(at)
			if d < best and d < 400.0:
				best = d
				y = pts[i].y
	return y


## A frame facing `face` (its +z) standing upright at `at`.
func _facing(face: Vector3, at: Vector3) -> Transform3D:
	var z := Vector3(face.x, 0.0, face.z).normalized()
	var x := Vector3.UP.cross(z).normalized()
	return Transform3D(Basis(x, Vector3.UP, z), at)


# ======================================================================================
#  Traffic on the carriageways the race doesn't use: the A 58 both ways, the A 47 westbound (AutobahnTraffic.gd)
# ======================================================================================

var _camp_mats := {}

func _camp_material(key: String) -> Material:
	if not _camp_mats.has(key):
		_camp_mats[key] = _save_res(CampKit.make_material(key), "camp_mat_" + key, PROP_PREFIX)
	return _camp_mats[key]


func _build_traffic(root: Node3D) -> void:
	var pk := PropKit.new()
	pk.material_for = func(key: String) -> Material: return _camp_material(key)
	var camp := CampKit.new(pk)
	var meshes: Array[Mesh] = []
	var kinds := [["van", Color(0.92, 0.92, 0.90)], ["suv", Color(0.16, 0.18, 0.22)], ["suv", Color(0.62, 0.10, 0.10)],
		["motorhome", Color(0.94, 0.94, 0.92)], ["van", Color(0.20, 0.32, 0.55)], ["suv", Color(0.75, 0.76, 0.78)], ["suv", Color(0.10, 0.22, 0.40)]]
	for k in kinds:
		var kit := {}
		pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * PROP_SCALE), Vector3.ZERO))
		camp.vehicle(kit, k[0], k[1])
		meshes.append(_save_res(pk.commit(kit), "traffic_%s_%d" % [k[0], meshes.size()], PROP_PREFIX))
	var node := Node3D.new()
	node.name = "Verkehr"
	root.add_child(node)
	# The A 58: northbound lanes run toward -z (positive x offsets), southbound back toward +z.
	var a58 := Node3D.new()
	a58.name = "A58Traffic"
	a58.set_script(load("res://AutobahnTraffic.gd"))
	a58.position = Vector3(A58_X, LAND_Y + GROUND_UNDER + 0.03, 2500.0)
	a58.set("meshes", meshes)
	a58.set("length", 5000.0)
	a58.set("per_lane", 22)
	a58.set("lanes", PackedFloat32Array([6.6, 10.4, 14.1, -6.6, -10.4, -14.1]))
	node.add_child(a58)
	# The A 47 westbound, from the town east of the river to the west country: the node turned so its -z runs west.
	var x_start := 1500.0
	var length := 3900.0
	var hs := PackedFloat32Array()
	var d := 0.0
	while d <= length + 0.1:
		hs.append(_a2_y(x_start - d) + 0.03)
		d += 10.0
	var wb := Node3D.new()
	wb.name = "A47Traffic"
	wb.set_script(load("res://AutobahnTraffic.gd"))
	wb.position = Vector3(x_start, 0.0, A47_AXIS)
	wb.rotation_degrees = Vector3(0, 90, 0)
	wb.set("meshes", meshes)
	wb.set("length", length)
	wb.set("per_lane", 16)
	wb.set("lanes", PackedFloat32Array([8.1, 11.9, 15.6]))
	wb.set("heights", hs)
	wb.set("height_step", 10.0)
	node.add_child(wb)


# ======================================================================================
#  The start: crowd barriers and spectators along the promenade either side of the line
# ======================================================================================

const SPECTATOR_SCALE := PROP_SCALE / 1.86
## A Rhineland crowd: mostly European, Turkish and Arab families, a few others ([African, South Asian, European, East
## Asian, Arab or mixed]).
const SPECTATOR_SKIN := [0.05, 0.04, 0.72, 0.03, 0.16]
const START_BEFORE := 140.0
const START_AFTER := 110.0
const BARRIER_LAT := ROAD_HALF + 0.55
var _people: Array = []

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
	var s_fin: float = _closest_s(Vector2(PROMENADE_X, FINISH_Z))
	var rng := RandomNumberGenerator.new()
	rng.seed = 6611
	var step: float = 2.3 * PROP_SCALE
	var s: float = s_fin - START_BEFORE
	var count := 0
	while s < s_fin + START_AFTER:
		for side in [-1.0, 1.0]:
			if absf(s - s_fin) < 9.0:
				continue
			var sp: Dictionary = _spot(s, side * BARRIER_LAT, 0.0)
			var pos: Vector3 = sp["pos"]
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
			# The town's side (left, east): one loose row on the pavement; the river's side (right): two or three rows on
			# the promenade's walk.
			var rows: int = 1 if side < 0.0 else 3
			for row in range(rows):
				if rng.randf() < (0.3 if row == 0 else 0.55):
					continue
				var lat: float = side * (BARRIER_LAT + 1.3 + float(row) * 1.5 + rng.randf_range(0.0, 0.5))
				var ps: Dictionary = _spot(s + rng.randf_range(-1.2, 1.2), lat, 0.0)
				var pp: Vector3 = ps["pos"]
				if absf(lat) > ROAD_HALF + PAVEMENT:
					pp.y = _ground_at(pp.x, pp.z)
				var face: Vector3 = -(ps["right"] as Vector3) * side
				face = (face + (ps["fwd"] as Vector3) * rng.randf_range(-0.5, 0.5)).normalized()
				_people.append([pp, face, false, false, -1, rng.randf_range(0.9, 1.08)])
		s += step
	# Round the outside of the turn onto the old bridge (the lap's left): crowd barriers on the kerb and people
	# watching from the pavement, up to the bridge's head.
	var e1a: float = float(segs[1]["s0"]) - 25.0
	var e1b: float = float(segs[2]["s0"]) + 1.0
	var s2: float = e1a
	while s2 < e1b:
		var sp2: Dictionary = _spot(s2, -BARRIER_LAT, 0.0)
		var pos2: Vector3 = sp2["pos"]
		var fwd2: Vector3 = sp2["fwd"]
		var xf2 := Transform3D(Basis(fwd2, Vector3.UP, fwd2.cross(Vector3.UP)), pos2)
		pk.set_frame(xf2.scaled_local(Vector3.ONE * PROP_SCALE))
		camp.crowd_barrier(bkit)
		var bs2 := CollisionShape3D.new()
		var bx2 := BoxShape3D.new()
		bx2.size = Vector3(step + 0.4, 1.8, 0.5)
		bs2.shape = bx2
		bs2.transform = Transform3D(xf2.basis, pos2 + Vector3(0, 0.9, 0))
		body.add_child(bs2)
		count += 1
		if rng.randf() < 0.6:
			var ps2: Dictionary = _spot(s2, -(BARRIER_LAT + 1.4 + rng.randf_range(0.0, 0.8)), 0.0)
			var face2: Vector3 = (ps2["right"] as Vector3)
			_people.append([ps2["pos"], face2, false, false, -1, rng.randf_range(0.9, 1.08)])
		s2 += step
	pk.reset_frame()
	var bmi := MeshInstance3D.new()
	bmi.name = "Barriers"
	bmi.mesh = _save_res(pk.commit(bkit), "start_barriers", PROP_PREFIX)
	bmi.visibility_range_end = 700.0
	node.add_child(bmi)
	print("  start: %d barriers, %d spectators" % [count, _people.size()])


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
#  Leitpfosten: the white delineator posts along the country roads and the Autobahn (knockable)
# ======================================================================================

func _post_mesh() -> ArrayMesh:
	var pk := PropKit.new()
	pk.material_for = func(key: String) -> Material: return _camp_material(key)
	var kit := {}
	var sc := PROP_SCALE
	var white := Color(0.92, 0.92, 0.90)
	var black := Color(0.06, 0.06, 0.06)
	var prof := PackedVector2Array([Vector2(-0.06, 0.0), Vector2(0.06, 0.0), Vector2(0.06, 0.06), Vector2(0.0, 0.11), Vector2(-0.06, 0.06)])
	pk.set_frame(Transform3D(Basis(Vector3.RIGHT, Vector3.BACK, Vector3.DOWN) * Basis.from_scale(Vector3.ONE * sc), Vector3.ZERO))
	# Frame z is down: the post runs from z 0 (its foot) to -1 (its top), white with a black band near the top.
	pk.extrude(kit, "paint", prof, -0.73, 0.0, 0.0, white)
	pk.extrude(kit, "paint", prof, -0.98, -0.73, 0.0, black)
	pk.extrude(kit, "paint", prof, -1.0, -0.98, 0.0, white)
	pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * sc), Vector3.ZERO))
	pk.block(kit, "lamp", Vector3(-0.025, 0.80, -0.012), Vector3(0.025, 0.90, -0.002), Color(0.95, 0.95, 0.9))
	return pk.commit(kit)


func _build_delineators(root: Node3D) -> void:
	var kinds: Array = _road_kinds()
	var xfs: Array[Transform3D] = []
	var s := 10.0
	while s < lap_len:
		var k: int = _kind_at(kinds, s)
		if k == 0 and absf(_at(s)["k"]) < 0.03 and not _lap_on_deck(s):
			var near_jump: bool = absf(_at(s)["p"].y - DYKE_JUMP_Z) < 40.0 and absf(_at(s)["p"].x - DYKE_X) < 2.0
			if not near_jump:
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


# ======================================================================================
#  The woods: WoodlandBuilder's trees (near cells, shadow stand-ins, far cells, JungleDetail)
# ======================================================================================

const TREE_CELL := 260.0
const TREE_FAR_RANGE := 1900.0
## Trees by kind: [kind, spruce?]. The poplar, pollard and plane come with NiederrheinKit's additions to WoodlandBuilder.
var _tree_kinds: Array = []

func _build_woods(root: Node3D) -> void:
	var t0 := Time.get_ticks_msec()
	var node := Node3D.new()
	node.name = "Woodland"
	root.add_child(node)
	var w = load("res://WoodlandBuilder.gd").new()
	w.save_res = func(res: Resource, n: String) -> Resource: return _save_res(res, n, "rheinufertree_")
	_tree_kinds = ["oak", "lime", "birch", "willow"]
	var rhein: bool = w.has_method("tree_mesh") and w.has_method("rhein_leaf_material")
	if rhein:
		_tree_kinds.append_array(["poplar", "pollard", "plane"])
	var leaf_near: ShaderMaterial = _save_res(w.leaf_material(1, 0.14, 18.0), "leaf_near", "rheinufertree_")
	var leaf_far: ShaderMaterial = _save_res(w.leaf_material(2, 0.14, 18.0), "leaf_far", "rheinufertree_")
	var lod_mats: Array[ShaderMaterial] = [leaf_near, leaf_far]
	var rleaf_near: ShaderMaterial = leaf_near
	var rleaf_far: ShaderMaterial = leaf_far
	if rhein:
		rleaf_near = _save_res(w.rhein_leaf_material(1, 0.14, 18.0), "rhein_leaf_near", "rheinufertree_")
		rleaf_far = _save_res(w.rhein_leaf_material(2, 0.14, 18.0), "rhein_leaf_far", "rheinufertree_")
		lod_mats.append(rleaf_near)
		lod_mats.append(rleaf_far)
	var near_meshes: Array = []
	var far_meshes: Array = []
	for kind in _tree_kinds:
		var bark_key: String = _bark_key(kind)
		var bn: ShaderMaterial = _save_res(w.bark_material(bark_key, 1), "bark_%s_near" % kind, "rheinufertree_")
		var bf: ShaderMaterial = _save_res(w.bark_material(bark_key, 2), "bark_%s_far" % kind, "rheinufertree_")
		lod_mats.append(bn)
		lod_mats.append(bf)
		var own: bool = rhein and w.uses_rhein_atlas(kind)
		var ln: ShaderMaterial = rleaf_near if own else leaf_near
		var lf: ShaderMaterial = rleaf_far if own else leaf_far
		if rhein:
			near_meshes.append(_save_res(w.tree_mesh(kind, 0, 0, bn, ln), "tree_%s" % kind, "rheinufertree_"))
			far_meshes.append(_save_res(w.tree_mesh(kind, 0, 1, bf, lf), "tree_%s_far" % kind, "rheinufertree_"))
		else:
			near_meshes.append(_save_res(w.broadleaf_mesh(kind, 0, 0, bn, ln), "tree_%s" % kind, "rheinufertree_"))
			far_meshes.append(_save_res(w.broadleaf_mesh(kind, 0, 1, bf, lf), "tree_%s_far" % kind, "rheinufertree_"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 8841
	var cells := {}
	var counts := {}
	for k in _tree_kinds:
		counts[k] = 0
	var add := func(kind: String, px: float, pz: float, sc: float) -> void:
		var mi: int = _tree_kinds.find(kind)
		if mi < 0:
			kind = "willow" if kind == "pollard" else ("lime" if kind == "plane" else "birch")
			mi = _tree_kinds.find(kind)
		var g: float = _ground_at(px, pz)
		var lean := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.04))
		var xf := Transform3D(lean * Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.92, 1.1), sc)),
				Vector3(px, g - 0.3, pz))
		var key := Vector3i(floori(px / TREE_CELL), floori(pz / TREE_CELL), mi)
		if not cells.has(key):
			cells[key] = []
		cells[key].append(xf)
		counts[kind] += 1
	var ok_spot := func(px: float, pz: float, road_clear: float) -> bool:
		if _occupied(px, pz) or absf(px) < RIVER_HALF + 4.0:
			return false
		if _road_dist(px, pz, false) < road_clear or _lap_dist(px, pz) < road_clear + 4.0:
			return false
		return true
	# The woods: by the ground's woodland mask (the Auwald on the floodplain, copses in the fields).
	var step := 12.0
	var x: float = FINE_X.x + 40.0
	while x < FINE_X.y - 40.0:
		var z: float = FINE_Z.x + 30.0
		while z < FINE_Z.y - 30.0:
			var px: float = x + rng.randf_range(-0.45, 0.45) * step
			var pz: float = z + rng.randf_range(-0.45, 0.45) * step
			var roll: float = rng.randf()
			z += step
			var fw: float = _forest_w(px, pz) * _open_land(px, pz)
			if roll > maxf(fw, 0.012):
				continue
			if not ok_spot.call(px, pz, 16.0) or (px > 236.0 and _town_w(pz) > 0.3):
				continue
			var flood: bool = px > DYKE_X + 20.0 and px < -RIVER_HALF
			var kind := "oak"
			var r2: float = rng.randf()
			if flood:
				kind = "willow" if r2 < 0.45 else ("poplar" if r2 < 0.75 else "oak")
			elif r2 < 0.2:
				kind = "lime"
			elif r2 < 0.32:
				kind = "birch"
			add.call(kind, px, pz, rng.randf_range(1.0, 1.3))
		x += step
	# Pollarded willows in rows along the field ditches west of the dyke, and poplar rows along the country roads.
	var ditch_rng := RandomNumberGenerator.new()
	ditch_rng.seed = 8842
	for row in range(14):
		var x0: float = ditch_rng.randf_range(-1080.0, -420.0)
		var z0: float = ditch_rng.randf_range(-850.0, 620.0)
		var ang: float = ditch_rng.randf_range(-0.3, 0.3) + (PI * 0.5 if ditch_rng.randf() < 0.5 else 0.0)
		var dir := Vector2(cos(ang), sin(ang))
		var n: int = ditch_rng.randi_range(8, 18)
		for k in range(n):
			var p := Vector2(x0, z0) + dir * float(k) * ditch_rng.randf_range(8.0, 10.0)
			if ok_spot.call(p.x, p.y, 14.0) and p.x < DYKE_X - 25.0:
				add.call("pollard", p.x, p.y, ditch_rng.randf_range(0.9, 1.15))
	for k in range(60):
		var px2: float = -1100.0 + float(k) * 13.0
		for side in [-1.0, 1.0]:
			var pz2: float = WEST_ROAD_Z + side * 24.0
			if px2 < -680.0 or px2 > -410.0:
				continue
			if ok_spot.call(px2, pz2, 12.0):
				add.call("poplar", px2, pz2, rng.randf_range(0.95, 1.1))
	# Plane trees along the promenade's walk.
	# (Not north of the exit ramp's foot: their crowns would reach its viaduct.)
	var zp: float = -196.0
	while zp < TOWN_Z.y - 10.0:
		var pxp: float = 212.5
		if not _occupied(pxp, zp) and _lap_dist(pxp, zp) > ROAD_HALF + 5.0:
			add.call("plane", pxp, zp, rng.randf_range(1.0, 1.15))
			_note_rect(Vector2(pxp, zp), 3.0, 3.0, 0.0, 0.0)
		zp += 14.0
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


## The bark a kind's trunk takes: BROADLEAF's own "bark" key where it names one (the willow's alder), else the kind.
func _bark_key(kind: String) -> String:
	var cm: Dictionary = (load("res://WoodlandBuilder.gd") as Script).get_script_constant_map()
	var bl: Dictionary = cm.get("BROADLEAF", {})
	if bl.has(kind) and (bl[kind] as Dictionary).has("bark"):
		return String(bl[kind]["bark"])
	return kind


func _woodland_has(w: Object, kind: String) -> bool:
	var cm: Dictionary = (w.get_script() as Script).get_script_constant_map()
	return cm.has("BROADLEAF") and (cm["BROADLEAF"] as Dictionary).has(kind)


# ======================================================================================
#  Prop batches: many props built into one kit (a mesh with a surface per material), saved under PROP_PREFIX
# ======================================================================================

var _batches := {}
var _saved_mats := {}

func _kit_script(path: String) -> Script:
	if ResourceLoader.exists(path):
		var sc: Script = load(path)
		if sc != null and sc.can_instantiate():
			return sc
	push_warning("Rheinufer: %s isn't there (or doesn't parse) yet" % path)
	return null


func _has_fn(script: Script, fn: String) -> bool:
	if script == null:
		return false
	for m in script.get_script_method_list():
		if m["name"] == fn:
			return true
	return false


## Builds one prop into the batch `key`: `xf` places it rigidly (the kit's life-size frame is grown by PROP_SCALE about
## its origin), `build` is called as build(pk, kit, labels). Labels come back in the kit's life-size coordinates.
func _add_prop(key: String, kit_script: Script, xf: Transform3D, build: Callable, range_end := 0.0) -> void:
	_add_prop_scaled(key, kit_script, xf, build, range_end, PROP_SCALE)


## The same at game scale (the bridges and viaduct parts are built in game metres).
func _add_prop_game(key: String, kit_script: Script, xf: Transform3D, build: Callable, range_end := 0.0) -> void:
	_add_prop_scaled(key + "_g", kit_script, xf, build, range_end, 1.0)


func _add_prop_scaled(key: String, kit_script: Script, xf: Transform3D, build: Callable, range_end: float, scale: float) -> void:
	if kit_script == null:
		return
	if not _batches.has(key):
		_batches[key] = {"pk": kit_script.new_kit(scale), "kit": {}, "labels": [], "range": range_end, "script": kit_script, "scale": scale}
	else:
		# The kits keep their UV scale (uvk) in statics shared between them: set it back for this batch's scale.
		kit_script.new_kit(scale)
	var b: Dictionary = _batches[key]
	var pk: PropKit = b["pk"]
	var frame := Transform3D(xf.basis * Basis.from_scale(Vector3.ONE * scale), xf.origin)
	pk.set_frame(frame)
	var labels: Array = []
	build.call(pk, b["kit"], labels)
	for l in labels:
		var out: Array = [l[0], frame * (l[1] as Vector3), (xf.basis * (l[2] as Vector3)).normalized(), float(l[3]) * scale, l[4],
				float(l[5]) * scale if l.size() > 5 else 0.0]
		(b["labels"] as Array).append(out)


var _missing := {}

func _kit_call(script: Script, fn: String, args: Array) -> void:
	if script == null or not _has_fn(script, fn):
		if not _missing.has(fn):
			_missing[fn] = true
			push_warning("Rheinufer: %s has no %s() yet" % [script.resource_path.get_file() if script else "(no kit)", fn])
		return
	script.callv(fn, args)


func _cell_key(prefix: String, p: Vector3, cell := 140.0) -> String:
	return "%s_%d_%d" % [prefix, floori(p.x / cell), floori(p.z / cell)]


func _flush_batches(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Rheinufer"
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


# ======================================================================================
#  Places the dressing and the generator agree on
# ======================================================================================

## The farmsteads (NiederrheinKit.farmhouse) on pads of their own: [centre, yaw (degrees, the house's front +z)].
const FARMS := [[Vector2(-720.0, 262.0), 20.0], [Vector2(-955.0, -520.0), -70.0], [Vector2(-470.0, 470.0), 160.0], [Vector2(-1050.0, 120.0), 95.0]]
const FARM_HALF := Vector2(32.0, 40.0)
## The power station (NiederrheinKit.power_station, SteelworksKit's cooling towers and chimney) far out west-south-west.
const POWER_AT := Vector2(-1750.0, 980.0)
## The station faces east (its +z): its kit frame's x runs north (-z), so the pad reaches out over the coal yard to the
## south and the cooling towers to the north.
const POWER_PAD_OFF := Vector2(35.0, 110.0)
const POWER_HALF := Vector2(270.0, 455.0)
## The transmission line from the power station east over the Rhine (tall crossing towers on both banks).
const LINE_TOWERS := [Vector2(-1560.0, 880.0), Vector2(-1250.0, 800.0), Vector2(-940.0, 720.0), Vector2(-630.0, 640.0),
	Vector2(-330.0, 560.0), Vector2(320.0, 540.0), Vector2(640.0, 500.0), Vector2(960.0, 460.0), Vector2(1280.0, 420.0)]
## The Kirmes on the west bank's meadow (inside KIRMES_RECT).
## The wheel and the bumper cars on the west side facing the river (their fronts +x), the chain swing by the beach, the
## stalls along an alley at x ALLEY_X, the beer tent at the north end facing south.
const WHEEL_AT := Vector2(-278.0, 100.0)
const SWING_AT := Vector2(-218.0, 60.0)
const SCOOTER_AT := Vector2(-280.0, 22.0)
const TENT_AT := Vector2(-255.0, -58.0)
const ALLEY_X := -245.0
## The tower windmill on the dyke's land side, north of the jump's landing.
const MILL_AT := Vector2(-404.0, -84.0)
## The sheep: graze area A on the river side by the old bridge, B on the land side; they cross the dyke road at z ~155.
const SHEEP_A := [Vector2(-300.0, 162.0), Vector2(20.0, 16.0)]
const SHEEP_B := [Vector2(-392.0, 140.0), Vector2(16.0, 22.0)]
const SHEEP_CROSS := [Vector2(-322.0, 158.0), Vector2(-372.0, 150.0)]
## The landing stage on the east bank (the excursion ship moored at it) and the ferry's on the west bank.
const LANDING_Z := 70.0
## The pontoon's middle: its gangway (RheinShipKit.gangway_top: about 29.6m back toward the bank) lands on the lower
## promenade.
const LANDING_X := 159.0
const FERRY_Z := 420.0


func _plan_pads() -> void:
	_pads.clear()
	for f in FARMS:
		var c: Vector2 = f[0]
		_pads.append([c, FARM_HALF, _raw_natural(c.x, c.y) + 0.3])
	_pads.append([POWER_AT + POWER_PAD_OFF, POWER_HALF, _raw_natural(POWER_AT.x, POWER_AT.y) + 0.5])


# ======================================================================================
#  Ships on the Rhine (RheinShipKit, SeaBoat.gd) and the river's furniture
# ======================================================================================

func _ship_scene(name: String, build: Callable) -> PackedScene:
	var pk: PropKit = _ship_kit.new_kit(PROP_SCALE)
	var kit := {}
	var labels: Array = []
	pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * PROP_SCALE), Vector3.ZERO))
	build.call(pk, kit, labels)
	if kit.is_empty():
		return null
	var mesh: ArrayMesh = _ship_kit.commit(pk, kit)
	for si in range(mesh.get_surface_count()):
		var m: Material = mesh.surface_get_material(si)
		if m != null and m.resource_path.is_empty():
			var id: int = m.get_instance_id()
			if not _saved_mats.has(id):
				_saved_mats[id] = _save_res(m, "mat_%d" % _saved_mats.size(), PROP_PREFIX)
			mesh.surface_set_material(si, _saved_mats[id])
	var root := Node3D.new()
	root.name = "Vessel"
	var mi := MeshInstance3D.new()
	mi.name = "Hull"
	mi.mesh = _save_res(mesh, "ship_" + name, PROP_PREFIX)
	mi.visibility_range_end = 2600.0
	root.add_child(mi)
	mi.owner = root
	for l in labels:
		var lab := Label3D.new()
		lab.text = l[0]
		lab.font_size = 64
		lab.pixel_size = _fit_pixel(l[0], 64, float(l[3]) * PROP_SCALE / 44.8, float(l[5]) * PROP_SCALE if l.size() > 5 else 0.0)
		lab.modulate = l[4]
		lab.outline_size = 4
		lab.double_sided = false
		lab.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		lab.visibility_range_end = 600.0
		var n: Vector3 = l[2]
		lab.transform = Transform3D(Basis.looking_at(-n, Vector3.UP if absf(n.y) < 0.95 else Vector3.BACK), (l[1] as Vector3) * PROP_SCALE)
		root.add_child(lab)
		lab.owner = root
	var ps := PackedScene.new()
	ps.pack(root)
	var path := "res://generated/%sship_%s.tscn" % [PROP_PREFIX, name]
	ResourceSaver.save(ps, path)
	return load(path)


## Each cruising vessel: [scene name, builder, speed, phase share, horn?, body top (game m)].
func _build_ships(root: Node3D) -> void:
	if _ship_kit == null:
		return
	var node := Node3D.new()
	node.name = "Schiffe"
	root.add_child(node)
	var sk: Script = _ship_kit
	var tops := {"cargo_hatch": 4.0, "cargo_boxes": 4.0, "cargo_gravel": 4.0, "tanker": 2.1, "convoy": 3.1, "excursion": 5.1}
	var defs: Array = [
		["cargo_hatch", func(pk, kit, labels): _kit_call(sk, "cargo_ship", [pk, kit, labels, 0, "Annegret"])],
		["cargo_boxes", func(pk, kit, labels): _kit_call(sk, "cargo_ship", [pk, kit, labels, 1, "Rheinländer"])],
		["cargo_gravel", func(pk, kit, labels): _kit_call(sk, "cargo_ship", [pk, kit, labels, 2, "Johanna B"])],
		["tanker", func(pk, kit, labels): _kit_call(sk, "tanker", [pk, kit, labels, "Lippestrom"])],
		["convoy", func(pk, kit, labels): _kit_call(sk, "push_convoy", [pk, kit, labels, 2])],
		["excursion", func(pk, kit, labels): _kit_call(sk, "excursion_ship", [pk, kit, labels, "Stadt Kronburg"])],
	]
	var scenes := {}
	for d in defs:
		var sc: PackedScene = _ship_scene(d[0], d[1])
		if sc != null:
			scenes[d[0]] = sc
	# The loop: up the west lane, down the east lane (keeping right), turns 4.6km out in the haze.
	var order := ["cargo_hatch", "tanker", "convoy", "cargo_boxes", "excursion", "cargo_gravel", "cargo_hatch", "tanker", "cargo_boxes", "convoy"]
	var loop_len := 9200.0
	var lane := 55.0
	var perimeter: float = loop_len * 2.0 + PI * lane * 2.0
	var horns: Array[AudioStream] = [load("res://sounds/rheinufer/ship_horn_long.wav"), load("res://sounds/rheinufer/ship_horn_double.wav")]
	var engine: AudioStream = load("res://sounds/rheinufer/ship_engine_loop.wav")
	var i := 0
	for nm in order:
		if not scenes.has(nm):
			continue
		var b := Node3D.new()
		b.name = "Ship%d_%s" % [i, String(nm).to_pascal_case()]
		b.set_script(load("res://SeaBoat.gd"))
		b.set("model", scenes[nm])
		b.set("draft", 0.0)
		b.set("length", loop_len)
		b.set("turn_radius", lane)
		b.set("speed", 8.5 if nm != "convoy" else 6.5)
		b.set("phase", perimeter * (float(i) + 0.37) / float(order.size()))
		b.set("bob_height", 0.06)
		b.set("roll_deg", 0.25)
		b.set("pitch_deg", 0.1)
		b.set("body_top", float(tops.get(nm, 4.0)))
		b.set("engine_sound", engine)
		b.set("engine_db", 24.0 - 19.1 - 21.0)
		b.set("engine_unit", 45.0)
		b.set("horns", horns)
		b.set("horn_db", PackedFloat32Array([24.0 - 18.9 - 16.0, 24.0 - 23.5 - 16.0]))
		b.set("horn_unit", 220.0)
		b.set("horn_gap", Vector2(70.0, 160.0))
		b.set("wake_width", 16.0)
		b.position = Vector3(0.0, WATER_Y, 0.0)
		node.add_child(b)
		i += 1
	# Moored: the excursion ship at the landing stage, the ferry at its landing on the west bank.
	if scenes.has("excursion"):
		var m := Node3D.new()
		m.name = "MooredExcursion"
		m.set_script(load("res://SeaBoat.gd"))
		m.set("model", scenes["excursion"])
		m.set("bob_height", 0.04)
		m.set("roll_deg", 0.15)
		m.set("body_top", 5.1)
		m.set("bob_height", 0.0)
		m.set("roll_deg", 0.0)
		m.set("pitch_deg", 0.0)
		var mxf := Transform3D(Basis(Vector3.UP, PI), Vector3(LANDING_X - 4.5 * PROP_SCALE - 9.8, WATER_Y, LANDING_Z))
		m.transform = mxf
		node.add_child(m)
		# Passengers on its open decks (it lies still: SeaBoat moves nothing with no loop and no bob).
		if _has_fn(sk, "excursion_seats"):
			for seat in sk.excursion_seats():
				var pos: Vector3 = mxf * ((seat[0] as Vector3) * PROP_SCALE)
				var face: Vector3 = mxf.basis * (seat[1] as Vector3)
				_people.append([pos, face, bool(seat[2]), bool(seat[2]), -1, 1.0])
	var ferry: PackedScene = _ship_scene("ferry", func(pk, kit, labels): _kit_call(sk, "car_ferry", [pk, kit, labels]))
	if ferry != null:
		var f := Node3D.new()
		f.name = "MooredFerry"
		f.set_script(load("res://SeaBoat.gd"))
		f.set("model", ferry)
		f.set("bob_height", 0.04)
		f.set("roll_deg", 0.15)
		f.set("body_top", 1.6)
		f.transform = Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-RIVER_HALF + 34.0, WATER_Y, FERRY_Z))
		node.add_child(f)
	print("  ships: %d cruising" % i)


func _build_river_furniture() -> void:
	if _ship_kit == null:
		return
	var sk: Script = _ship_kit
	var rng := RandomNumberGenerator.new()
	rng.seed = 9161
	# Groynes along the west bank every ~95m, clear of the bridges and the ferry's landing.
	var z: float = -1500.0
	var n := 0
	while z < 1500.0:
		if absf(z - OLD_BRIDGE_Z) > 45.0 and absf(z - A47_AXIS) > 50.0 and absf(z - FERRY_Z) > 60.0:
			var foot := Vector3(-RIVER_HALF - 12.0, 0.0, z)
			foot.y = _ground_at(foot.x, foot.z)
			# Running out into the river (+x), angled a little upstream (+z) as Rhine groynes are.
			var dir := Vector3(1.0, 0.0, 0.12).normalized()
			var xf := _facing(dir, foot)
			var life_len: float = 62.0 / PROP_SCALE
			var drop: float = (foot.y - (WATER_Y - 1.2)) / PROP_SCALE
			_add_prop(_cell_key("buhne", foot, 400.0), sk, xf, func(pk, kit, _l): _kit_call(sk, "groyne", [pk, kit, life_len, drop]), 2200.0)
			n += 1
		z += 95.0
	# Rhine-kilometre boards on both banks every 200m (the kilometres count downstream, toward -z), crosses between.
	var zk: float = -1400.0
	while zk <= 1400.0:
		var km: int = 742 + int(round(-zk / 1000.0))
		var whole: bool = absf(fposmod(-zk, 1000.0)) < 1.0
		for side in [-1.0, 1.0]:
			var bx: float = side * (RIVER_HALF + (8.0 if side < 0.0 else 4.0))
			if side > 0.0 and _town_w(zk) > 0.5:
				bx = LOWER_PROM_X + 2.0
			var at := Vector3(bx, 0.0, zk)
			at.y = _ground_at(at.x, at.z)
			var face := Vector3(-side, 0.0, 0.0)
			var xf := _facing(face, at)
			if whole:
				_add_prop(_cell_key("rheinkm", at, 500.0), sk, xf, func(pk, kit, labels): _kit_call(sk, "km_board", [pk, kit, labels, km]), 1500.0)
			else:
				_add_prop(_cell_key("rheinkm", at, 500.0), sk, xf, func(pk, kit, _l): _kit_call(sk, "half_km_mark", [pk, kit]), 1200.0)
		zk += 500.0
	# Fairway buoys: red cans off the right (east) bank, green cones off the left.
	var zb: float = -1300.0
	while zb < 1300.0:
		for side in [-1.0, 1.0]:
			var at2 := Vector3(side * (RIVER_HALF - 52.0), WATER_Y, zb + side * 120.0)
			var red: bool = side > 0.0
			_add_prop(_cell_key("tonne", at2, 600.0), sk, Transform3D(Basis(Vector3.UP, PI), at2), func(pk, kit, _l): _kit_call(sk, "fairway_buoy", [pk, kit, red]), 1400.0)
		zb += 420.0
	# The river gauge on the lower promenade, the landing stage in front of the start.
	var pg := Vector3(RIVER_HALF + 1.2, WATER_Y - 0.6, 132.0)
	_add_prop("pegel", sk, _facing(Vector3(-1, 0, 0), pg), func(pk, kit, labels): _kit_call(sk, "pegel", [pk, kit, labels]), 1500.0)
	var ls := Vector3(LANDING_X, WATER_Y, LANDING_Z)
	var drop2: float = (LOWER_PROM_Y - WATER_Y) / PROP_SCALE - 0.9
	_add_prop("anleger", sk, _facing(Vector3(-1, 0, 0), ls), func(pk, kit, labels): _kit_call(sk, "landing_stage", [pk, kit, labels, 50.0, drop2]), 1500.0)
	_note_rect(Vector2(LANDING_X + 14.0, LANDING_Z), 40.0, 82.0, 0.0)
	print("  river: %d groynes" % n)


# ======================================================================================
#  The east bank: the quay, the Rheintreppe, the promenade's furniture, the Gründerzeit houses (RheinStadtKit)
# ======================================================================================

## A house's front stands on the pavement's outer edge.
const FRONT_LAT := ROAD_HALF + PAVEMENT + 0.15
## Where the Rheintreppe cut the quay (z ranges), the rest is quay wall.
const STEPS := [Vector2(-150.0, -110.0), Vector2(20.0, 50.0), Vector2(150.0, 190.0)]

func _build_quay(root: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "QuayRailBody"
	body.set_meta(&"surface", "rock")
	root.add_child(body)
	# The railing along the quay's top edge (and across the steps' heads: carts stay on the promenade).
	var z0: float = TOWN_Z.x + 8.0
	var z1: float = TOWN_Z.y - 8.0
	# Open where the lap turns onto the old bridge over the quay.
	for r in [Vector2(z0, OLD_BRIDGE_Z - 15.0), Vector2(OLD_BRIDGE_Z + 15.0, z1)]:
		if r.y - r.x < 1.0:
			continue
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(0.6, 1.8, r.y - r.x)
		cs.shape = bx
		cs.position = Vector3(QUAY_X + 1.0, TOWN_Y + 0.9, (r.x + r.y) * 0.5)
		body.add_child(cs)
	if _stadt_kit == null:
		return
	var st: Script = _stadt_kit
	var drop: float = (TOWN_Y - LOWER_PROM_Y) / PROP_SCALE
	var z: float = z0
	while z < z1 - 1.0:
		if z > OLD_BRIDGE_Z - 16.0 and z < OLD_BRIDGE_Z + 16.0:
			z = OLD_BRIDGE_Z + 16.0
			continue
		var in_steps := false
		for r in STEPS:
			if z >= float(r.x) and z < float(r.y):
				in_steps = true
		var zn: float = z + 16.0
		for r in STEPS:
			if z < float(r.x) and zn > float(r.x):
				zn = float(r.x)
			if in_steps and z >= float(r.x) and z < float(r.y):
				zn = float(r.y)
		zn = minf(zn, z1)
		if z < OLD_BRIDGE_Z - 16.0 and zn > OLD_BRIDGE_Z - 16.0:
			zn = OLD_BRIDGE_Z - 16.0
		var mid := Vector3(QUAY_X + 0.6, TOWN_Y, z)
		# The kit's frame: the upper promenade at y 0 along z = 0, the drop toward +z: facing the river (-x).
		var xf := _facing(Vector3(-1, 0, 0), mid)
		var life_len: float = (zn - z) / PROP_SCALE
		if in_steps:
			_add_prop(_cell_key("treppe", mid, 200.0), st, xf, func(pk, kit, _l): _kit_call(st, "rhine_steps", [pk, kit, life_len - 1.2, drop, 9.0]))
		else:
			_add_prop(_cell_key("kaimauer", mid, 200.0), st, xf, func(pk, kit, labels): _kit_call(st, "quay_wall", [pk, kit, life_len, drop, labels, true]))
		z = zn


func _build_town(_root: Node3D) -> void:
	if _stadt_kit == null:
		return
	var st: Script = _stadt_kit
	var rng := RandomNumberGenerator.new()
	rng.seed = 7301
	# The row along the promenade: fronts on the pavement's edge facing the river (-x), from the ramp's foot to the
	# old bridge's head; a corner house with its turret at each end.
	var z: float = -196.0
	var count := 0
	var z_end: float = 178.0
	while z < z_end - 8.0:
		var w_life: float = rng.randf_range(13.0, 18.0)
		var w: float = w_life * PROP_SCALE
		if z + w > z_end:
			w = z_end - z
			w_life = w / PROP_SCALE
			if w_life < 9.0:
				break
		var floors: int = rng.randi_range(4, 5)
		var variant: int = rng.randi_range(0, 3)
		var front := Vector3(PROMENADE_X + FRONT_LAT, 0.0, z)
		front.y = _ground_at(front.x + 2.0, front.z)
		var xf := _facing(Vector3(-1, 0, 0), front)
		var hseed: int = rng.randi()
		var corner: bool = count == 0
		_add_prop(_cell_key("altbau", front, 120.0), st, xf, func(pk, kit, labels):
			var r2 := RandomNumberGenerator.new()
			r2.seed = hseed
			if corner:
				_kit_call(st, "corner_house", [pk, kit, labels, w_life, 14.0, floors, r2, true])
			else:
				_kit_call(st, "gruenderzeit_house", [pk, kit, labels, w_life, floors, variant, r2, 13.0, 2 * count + 1, false]), 1600.0)
		_note_rect(Vector2(front.x + 11.0, front.z + w * 0.5), 22.0, w, 0.0, 0.5)
		z += w
		count += 1
	# A second row facing the back street (Friedrichstraße), plainer and further off.
	var zb: float = -190.0
	while zb < 170.0:
		var wl: float = rng.randf_range(12.0, 17.0)
		var wb: float = wl * PROP_SCALE
		var bf := Vector3(PROMENADE_X + FRONT_LAT + 62.0, 0.0, zb + wb)
		bf.y = _ground_at(bf.x - 2.0, bf.z)
		var bxf := _facing(Vector3(1, 0, 0), bf)
		var bseed: int = rng.randi()
		var fl: int = rng.randi_range(3, 4)
		var bv: int = rng.randi_range(0, 3)
		_add_prop(_cell_key("hinterhaus", bf, 160.0), st, bxf, func(pk, kit, labels):
			var r3 := RandomNumberGenerator.new()
			r3.seed = bseed
			_kit_call(st, "gruenderzeit_house", [pk, kit, labels, wl, fl, bv, r3, 13.0, 0, false]), 1300.0)
		_note_rect(Vector2(bf.x - 11.0, bf.z - wb * 0.5), 22.0, wb, 0.0, 0.5)
		zb += wb
		count += 1
	# The hotel by the old bridge's head and the church tower over the roofs (stage 1's church kit).
	# Its terrace and winter garden reach 13m out: set back so they stop at the pavement.
	var hotel := Vector3(PROMENADE_X + FRONT_LAT + 13.5, 0.0, 216.0)
	hotel.y = _ground_at(hotel.x + 3.0, hotel.z)
	_add_prop("hotel", st, _facing(Vector3(-1, 0, 0), hotel), func(pk, kit, labels): _kit_call(st, "hotel", [pk, kit, labels]), 2000.0)
	var church := Vector3(PROMENADE_X + 140.0, 0.0, -40.0)
	church.y = _ground_at(church.x, church.z)
	_add_prop("kirche", _town, _facing(Vector3(-1, 0, 0), church), func(pk, kit, labels): _kit_call(_town, "church", [pk, kit, labels]), 3000.0)
	_note_rect(Vector2(church.x, church.y), 40.0, 70.0, 0.0)
	# The promenade's walk: lamps, benches and bins between the plane trees, a café pavilion and two kiosks.
	var zl: float = TOWN_Z.x + 37.0
	while zl < TOWN_Z.y - 12.0:
		var lp := Vector3(208.5, TOWN_Y, zl)
		if _lap_dist(lp.x, lp.z) > ROAD_HALF + 4.0:
			_add_prop(_cell_key("promenade", lp, 200.0), st, _facing(Vector3(1, 0, 0), lp), func(pk, kit, _l): _kit_call(st, "promenade_lamp", [pk, kit]), 900.0)
		var bp := Vector3(205.5, TOWN_Y, zl + 7.0)
		if _lap_dist(bp.x, bp.z) > ROAD_HALF + 4.0:
			_add_prop(_cell_key("promenade", bp, 200.0), st, _facing(Vector3(-1, 0, 0), bp), func(pk, kit, _l): _kit_call(st, "bench", [pk, kit]), 700.0)
		zl += 28.0
	# The café pavilion is too deep for the upper promenade: it stands on the west bank's beach meadow by the ferry.
	var cafe := Vector3(-232.0, 0.0, 330.0)
	cafe.y = _ground_at(cafe.x, cafe.z)
	_add_prop("pavillon", st, _facing(Vector3(1, 0, 0), cafe), func(pk, kit, labels): _kit_call(st, "pavilion_cafe", [pk, kit, labels]), 1500.0)
	_note_rect(Vector2(cafe.x, cafe.z + 11.0), 26.0, 26.0, 0.0)
	for k in [[Vector3(211.0, TOWN_Y, -88.0), "eis"], [Vector3(211.0, TOWN_Y, 66.0), "getraenke"]]:
		var kp: Vector3 = k[0]
		var kind: String = k[1]
		_add_prop(_cell_key("promenade", kp, 200.0), st, _facing(Vector3(-1, 0, 0), kp), func(pk, kit, labels): _kit_call(st, "kiosk", [pk, kit, labels, kind]), 900.0)
		_note_rect(Vector2(kp.x, kp.z), 6.0, 6.0, 0.0)
	print("  town: %d houses" % count)


# ======================================================================================
#  The Kirmes on the west bank's meadow (RheinStadtKit, FerrisWheel.gd, KirmesRide.gd)
# ======================================================================================

func _build_kirmes(root: Node3D) -> void:
	if _stadt_kit == null:
		return
	var st: Script = _stadt_kit
	var node := Node3D.new()
	node.name = "Kirmes"
	root.add_child(node)
	var yk: float = KIRMES_Y
	var cm: Dictionary = st.get_script_constant_map()
	# The wheel: its base in the batch (solid), its rotor and gondolas under KirmesWheel.gd at the hub, at life size
	# under a node grown by PROP_SCALE.
	var wheel_xf := _facing(Vector3(1, 0, 0), Vector3(WHEEL_AT.x, yk, WHEEL_AT.y))
	_add_prop("riesenrad", st, wheel_xf, func(pk, kit, labels): _kit_call(st, "ferris_wheel_base", [pk, kit, labels]), 3000.0)
	_note_rect(WHEEL_AT + Vector2(6.0, 0.0), 40.0, 56.0, 0.0)
	if _has_fn(st, "ferris_wheel_rotor") and ResourceLoader.exists("res://KirmesWheel.gd"):
		var hub_y: float = float(cm.get("WHEEL_HUB_Y", 25.6))
		var n_cab: int = int(cm.get("WHEEL_CABINS", 36))
		var pivot_r: float = float(cm.get("WHEEL_PIVOT_R", 21.0))
		var colours: int = int(cm.get("WHEEL_GONDOLA_COLOURS", 4))
		var wheel := Node3D.new()
		wheel.name = "Riesenrad"
		wheel.set_script(load("res://KirmesWheel.gd"))
		wheel.transform = Transform3D(wheel_xf.basis.scaled(Vector3.ONE * PROP_SCALE), wheel_xf * Vector3(0, hub_y * PROP_SCALE, 0))
		wheel.set("cabin_radius", pivot_r)
		wheel.set("cabins", n_cab)
		node.add_child(wheel)
		var rotor := Node3D.new()
		rotor.name = "Rotor"
		wheel.add_child(rotor)
		var rmi := MeshInstance3D.new()
		rmi.name = "RotorMesh"
		rmi.mesh = _kit_mesh_life(st, "kirmes_wheel_rotor", func(pk, kit): st.ferris_wheel_rotor(pk, kit))
		rotor.add_child(rmi)
		for c in range(colours):
			var gm: ArrayMesh = _kit_mesh_life(st, "kirmes_gondola_%d" % c, func(pk, kit): st.ferris_wheel_gondola(pk, kit, c))
			var xfs: Array = []
			var j: int = c
			while j < n_cab:
				var a: float = TAU * float(j) / float(n_cab)
				xfs.append(Transform3D(Basis(), Vector3(cos(a), sin(a), 0.0) * pivot_r))
				j += colours
			var cab := MultiMeshInstance3D.new()
			cab.name = "Cabins%d" % c
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = gm
			mm.instance_count = xfs.size()
			mm.buffer = PropKit.transform_buffer(xfs)
			cab.multimesh = mm
			cab.set_meta(&"cabin_offset", c)
			cab.set_meta(&"cabin_stride", colours)
			wheel.add_child(cab)
	# The chain swing: its base in the batch, the rotor and chairs under KirmesRide.gd.
	var swing_xf := _facing(Vector3(1, 0, 0), Vector3(SWING_AT.x, yk, SWING_AT.y))
	_add_prop("kettenflieger", st, swing_xf, func(pk, kit, labels): _kit_call(st, "chair_swing_base", [pk, kit, labels]), 2200.0)
	_note_rect(SWING_AT, 36.0, 36.0, 0.0)
	if _has_fn(st, "chair_swing_rotor") and ResourceLoader.exists("res://KirmesRide.gd"):
		var hang_y: float = float(cm.get("SWING_HANG_Y", 6.0))
		var hang_r: float = float(cm.get("SWING_HANG_R", 5.2))
		var n_ch: int = int(cm.get("SWING_CHAIRS", 32))
		var ride := Node3D.new()
		ride.name = "Kettenflieger"
		ride.set_script(load("res://KirmesRide.gd"))
		ride.transform = Transform3D(swing_xf.basis.scaled(Vector3.ONE * PROP_SCALE), swing_xf.origin)
		node.add_child(ride)
		var rot := Node3D.new()
		rot.name = "Rotor"
		rot.position = Vector3(0, hang_y, 0)
		ride.add_child(rot)
		var rm := MeshInstance3D.new()
		rm.name = "RotorMesh"
		rm.mesh = _kit_mesh_life(st, "kirmes_swing_rotor", func(pk, kit): st.chair_swing_rotor(pk, kit))
		rot.add_child(rm)
		var cmesh: ArrayMesh = _kit_mesh_life(st, "kirmes_swing_chair", func(pk, kit): st.chair_swing_chair(pk, kit, 0))
		var cx: Array = []
		for i in range(n_ch):
			var a: float = TAU * float(i) / float(n_ch)
			var out := Vector3(cos(a), 0.0, sin(a))
			cx.append(Transform3D(Basis(out, Vector3.UP, out.cross(Vector3.UP) * -1.0), out * hang_r))
		var chairs := MultiMeshInstance3D.new()
		chairs.name = "Chairs"
		var cmm := MultiMesh.new()
		cmm.transform_format = MultiMesh.TRANSFORM_3D
		cmm.mesh = cmesh
		cmm.instance_count = cx.size()
		cmm.buffer = PropKit.transform_buffer(cx)
		chairs.multimesh = cmm
		rot.add_child(chairs)
	_add_prop("autoscooter", st, _facing(Vector3(1, 0, 0), Vector3(SCOOTER_AT.x, yk, SCOOTER_AT.y)), func(pk, kit, labels): _kit_call(st, "bumper_cars", [pk, kit, labels]), 1500.0)
	_note_rect(SCOOTER_AT + Vector2(4.0, 0.0), 40.0, 46.0, 0.0)
	_add_prop("festzelt", st, _facing(Vector3(0, 0, 1), Vector3(TENT_AT.x, yk, TENT_AT.y)), func(pk, kit, labels): _kit_call(st, "beer_tent", [pk, kit, labels]), 1800.0)
	_note_rect(TENT_AT + Vector2(0.0, -32.0), 38.0, 66.0, 0.0)
	# The stalls along the alley, facing it from both sides.
	var kinds := ["bratwurst", "mandeln", "lebkuchen", "lose", "schiess", "crepes", "getraenke", "mandeln", "bratwurst", "lebkuchen"]
	var zst: float = -46.0
	var k := 0
	while zst < 130.0:
		for side in [-1.0, 1.0]:
			var at := Vector3(ALLEY_X + side * 9.0, yk, zst)
			if _occupied(at.x, at.z):
				continue
			var kind: String = kinds[k % kinds.size()]
			k += 1
			_add_prop(_cell_key("buden", at, 120.0), st, _facing(Vector3(-side, 0, 0), at), func(pk, kit, labels): _kit_call(st, "stall", [pk, kit, labels, kind]), 1200.0)
			_note_rect(Vector2(at.x, at.z), 7.0, 9.0, 0.0)
		zst += 11.0
	# The fence round the fair along the dyke's side, with its banners; bunting across the alley.
	var fz: float = -120.0
	while fz < 130.0:
		var fa := Vector3(-297.0, 0.0, fz)
		fa.y = _ground_at(fa.x, fa.z)
		_add_prop(_cell_key("kirmeszaun", fa, 200.0), st, _facing(Vector3(1, 0, 0), fa).rotated_local(Vector3.UP, PI * 0.5), func(pk, kit, labels): _kit_call(st, "kirmes_fence", [pk, kit, 24.0 / PROP_SCALE, labels]), 1200.0)
		fz += 24.0
	var bz: float = -40.0
	while bz < 128.0:
		var ba := Vector3(ALLEY_X - 7.0, yk, bz)
		var bb := Vector3(ALLEY_X + 7.0, yk, bz + 3.0)
		_add_prop(_cell_key("wimpel", ba, 200.0), st, Transform3D(Basis(), Vector3.ZERO), func(pk, kit, _l):
			_kit_call(st, "bunting", [pk, kit, ba / PROP_SCALE + Vector3(0, 4.2, 0), bb / PROP_SCALE + Vector3(0, 4.2, 0), 0.5]), 900.0)
		bz += 22.0
	# Visitors wandering the alley and queueing at the stalls.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7171
	for i in range(80):
		var px: float = rng.randf_range(ALLEY_X - 4.5, ALLEY_X + 4.5)
		var pz: float = rng.randf_range(-40.0, 125.0)
		var face := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
		_people.append([Vector3(px, KIRMES_Y, pz), face, false, false, -1, rng.randf_range(0.6, 1.08)])
	print("  Kirmes: %d stalls" % k)


## A kit's mesh at life size (for the rides, under a node grown by PROP_SCALE), its materials saved with the batches'.
func _kit_mesh_life(script: Script, name: String, build: Callable) -> ArrayMesh:
	var pk: PropKit = script.new_kit(1.0)
	var kit := {}
	build.call(pk, kit)
	var mesh: ArrayMesh = script.commit(pk, kit)
	for si in range(mesh.get_surface_count()):
		var m: Material = mesh.surface_get_material(si)
		if m != null and m.resource_path.is_empty():
			var id: int = m.get_instance_id()
			if not _saved_mats.has(id):
				_saved_mats[id] = _save_res(m, "mat_%d" % _saved_mats.size(), PROP_PREFIX)
			mesh.surface_set_material(si, _saved_mats[id])
	return _save_res(mesh, name, PROP_PREFIX)


## A kit's mesh built on its own (not batched), its materials saved with the batches'.
func _kit_mesh(script: Script, name: String, build: Callable) -> ArrayMesh:
	var pk: PropKit = script.new_kit(PROP_SCALE)
	var kit := {}
	pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * PROP_SCALE), Vector3.ZERO))
	build.call(pk, kit)
	var mesh: ArrayMesh = script.commit(pk, kit)
	for si in range(mesh.get_surface_count()):
		var m: Material = mesh.surface_get_material(si)
		if m != null and m.resource_path.is_empty():
			var id: int = m.get_instance_id()
			if not _saved_mats.has(id):
				_saved_mats[id] = _save_res(m, "mat_%d" % _saved_mats.size(), PROP_PREFIX)
			mesh.surface_set_material(si, _saved_mats[id])
	return _save_res(mesh, name, PROP_PREFIX)


# ======================================================================================
#  The Niederrhein: the tower windmill, the sheep, the farmsteads, the power station and its line (NiederrheinKit)
# ======================================================================================

func _build_windmill(root: Node3D) -> void:
	if _land_kit == null:
		return
	var lk: Script = _land_kit
	var at := Vector3(MILL_AT.x, _ground_at(MILL_AT.x, MILL_AT.y), MILL_AT.y)
	# The sails face the river (east) and the lap.
	var xf := _facing(Vector3(1, 0, 0.25), at)
	_add_prop("windmuehle", lk, xf, func(pk, kit, labels): _kit_call(lk, "tower_windmill", [pk, kit, labels]), 3000.0)
	_note_rect(MILL_AT, 22.0, 22.0, 0.0)
	if _has_fn(lk, "windmill_sails") and _has_fn(lk, "mill_sails_transform"):
		var st_xf: Transform3D = lk.mill_sails_transform()
		var pivot := Node3D.new()
		pivot.name = "MuehleFluegel"
		pivot.set_script(load("res://Spinner.gd"))
		pivot.transform = Transform3D(xf.basis * st_xf.basis, xf * (st_xf.origin * PROP_SCALE))
		pivot.set("axis", Vector3(0, 0, 1))
		pivot.set("degrees_per_second", 30.0)
		root.add_child(pivot)
		var sails := MeshInstance3D.new()
		sails.name = "Sails"
		sails.mesh = _kit_mesh(lk, "windmill_sails", func(pk, kit): lk.windmill_sails(pk, kit))
		pivot.add_child(sails)
		var snd := _player(pivot, "MillCreak", "res://sounds/rheinufer/windmill_loop.wav", Vector3.ZERO, -24.0 + 29.6 - 6.0, 18.0, 160.0)
		snd.autoplay = true


func _build_sheep(root: Node3D) -> void:
	if _kit_script("res://SheepFlock.gd") == null:
		return
	var flock := Node3D.new()
	flock.name = "Schafherde"
	flock.set_script(load("res://SheepFlock.gd"))
	root.add_child(flock)
	var props: Array = (flock.get_script() as Script).get_script_property_list()
	var has := func(p: String) -> bool:
		for pr in props:
			if pr["name"] == p:
				return true
		return false
	var a_c: Vector2 = SHEEP_A[0]
	var b_c: Vector2 = SHEEP_B[0]
	if has.call("area_a_centre"):
		flock.set("area_a_centre", Vector3(a_c.x, 0.0, a_c.y))
		flock.set("area_a_half", SHEEP_A[1])
		flock.set("area_b_centre", Vector3(b_c.x, 0.0, b_c.y))
		flock.set("area_b_half", SHEEP_B[1])
	if has.call("cross_from"):
		var c0: Vector2 = SHEEP_CROSS[0]
		var c1: Vector2 = SHEEP_CROSS[1]
		flock.set("cross_from", Vector3(c0.x, _ground_at(c0.x, c0.y), c0.y))
		flock.set("cross_to", Vector3(c1.x, _ground_at(c1.x, c1.y), c1.y))
	if has.call("bleats"):
		var bl: Array[AudioStream] = [load("res://sounds/rheinufer/sheep_bleat_1.wav"), load("res://sounds/rheinufer/sheep_bleat_2.wav"), load("res://sounds/rheinufer/sheep_bleat_3.wav")]
		flock.set("bleats", bl)
		flock.set("bleat_db", 2.0)
	_note_rect(a_c, (SHEEP_A[1] as Vector2).x * 2.0, (SHEEP_A[1] as Vector2).y * 2.0, 0.0)
	_note_rect(b_c, (SHEEP_B[1] as Vector2).x * 2.0, (SHEEP_B[1] as Vector2).y * 2.0, 0.0)
	var snd := _player(root, "SheepFlockSound", "res://sounds/rheinufer/sheep_flock_loop.wav", Vector3(a_c.x, FLOOD_Y + 2.0, a_c.y), -24.0 + 40.5 - 8.0, 22.0, 220.0)
	snd.autoplay = true


func _build_farms() -> void:
	if _land_kit == null:
		return
	var lk: Script = _land_kit
	var rng := RandomNumberGenerator.new()
	rng.seed = 5151
	for i in range(FARMS.size()):
		var c: Vector2 = FARMS[i][0]
		var yaw: float = deg_to_rad(float(FARMS[i][1]))
		var y: float = _ground_at(c.x, c.y)
		var base := Transform3D(Basis(Vector3.UP, yaw), Vector3(c.x, y, c.y))
		var key: String = "hof_%d" % i
		# The kit's frames (life metres): the house x 0..14, z -26..0 facing +z; the barn beside it; the cart shed across
		# the yard facing back at the house; bales and a tractor in the yard. Centred on the pad.
		var at := func(lx: float, lz: float, yaw_l: float) -> Transform3D:
			return base * Transform3D(Basis(Vector3.UP, yaw_l), Vector3(lx + 1.0, 0.0, lz + 4.0) * PROP_SCALE)
		_add_prop(key, lk, at.call(0.0, 0.0, 0.0), func(pk, kit, labels): _kit_call(lk, "farmhouse", [pk, kit, labels, 0]), 2400.0)
		_add_prop(key, lk, at.call(-18.0, -4.0, 0.0), func(pk, kit, labels): _kit_call(lk, "farmhouse", [pk, kit, labels, 1]), 2400.0)
		_add_prop(key, lk, at.call(12.0, 18.0, PI), func(pk, kit, labels): _kit_call(lk, "farmhouse", [pk, kit, labels, 2]), 2400.0)
		var bseed: int = rng.randi()
		_add_prop(key, lk, at.call(16.0, 2.0, 0.0), func(pk, kit, _l):
			var r := RandomNumberGenerator.new()
			r.seed = bseed
			_kit_call(lk, "silage_bales", [pk, kit, r, 9]), 1600.0)
		_add_prop(key, lk, at.call(5.0, 7.0, 0.5), func(pk, kit, _l): _kit_call(lk, "tractor", [pk, kit, i % 2]), 1200.0)
		_note_rect(c, FARM_HALF.x * 2.0, FARM_HALF.y * 2.0, yaw)
	# The shepherd's cart by the sheep's land-side pasture.
	var sc := Vector3(SHEEP_B[0].x - 22.0, 0.0, SHEEP_B[0].y + 10.0)
	sc.y = _ground_at(sc.x, sc.z)
	_add_prop("schaeferkarren", lk, _facing(Vector3(1, 0, 0), sc), func(pk, kit, labels): _kit_call(lk, "shepherd_cart", [pk, kit, labels]), 1200.0)
	_note_rect(Vector2(sc.x, sc.z), 8.0, 6.0, 0.0)


func _build_power(root: Node3D) -> void:
	var y: float = _ground_at(POWER_AT.x, POWER_AT.y)
	var base := _facing(Vector3(1, 0, 0), Vector3(POWER_AT.x, y, POWER_AT.y))
	if _land_kit == null:
		return
	var lk: Script = _land_kit
	_add_prop("kraftwerk", lk, base, func(pk, kit, labels): _kit_call(lk, "power_station", [pk, kit, labels]), 6000.0)
	var cmap: Dictionary = lk.get_script_constant_map()
	var tscale: float = PROP_SCALE * float(cmap.get("POWER_TOWER_SCALE", 2.6))
	for t in cmap.get("POWER_TOWERS", []):
		var tp: Vector3 = base * ((t as Vector3) * PROP_SCALE)
		_add_prop_scaled("kuehlturm_%d" % int(tp.z), _works, Transform3D(Basis(), tp), func(pk, kit, _l): _kit_call(_works, "cooling_tower", [pk, kit]), 7000.0, tscale)
		_plume(root, "KuehlturmDampf_%d" % int(tp.z), tp + Vector3(0, 50.0 * tscale, 0), "steam", tscale / PROP_SCALE * 1.2)
	var ch: Vector3 = base * ((cmap.get("POWER_CHIMNEY_AT", Vector3(0, 0, -142)) as Vector3) * PROP_SCALE)
	var chh: float = float(cmap.get("POWER_CHIMNEY_H", 200.0))
	_add_prop("kraftwerk_schornstein", _works, Transform3D(Basis(), ch), func(pk, kit, _l): _kit_call(_works, "chimney", [pk, kit, chh, 1]), 7000.0)
	_build_power_line()


func _build_power_line() -> void:
	if _bridge_kit == null or not _has_fn(_bridge_kit, "transmission_tower"):
		return
	var bk: Script = _bridge_kit
	var tops: Array = []
	for i in range(LINE_TOWERS.size()):
		var p: Vector2 = LINE_TOWERS[i]
		var crossing: bool = absf(p.x) < 400.0
		var h: float = 112.0 if crossing else 50.0
		var style: int = 1 if crossing else 0
		var prev: Vector2 = LINE_TOWERS[maxi(i - 1, 0)]
		var nxt: Vector2 = LINE_TOWERS[mini(i + 1, LINE_TOWERS.size() - 1)]
		var along: Vector2 = (nxt - prev).normalized()
		var g: float = _ground_at(p.x, p.y)
		# The tower's crossarms run across the line: its x along the line's perpendicular.
		var xf := Transform3D(Basis(Vector3(-along.y, 0, along.x), Vector3.UP, Vector3(-along.x, 0, -along.y)), Vector3(p.x, g, p.y))
		_add_prop(_cell_key("mast", xf.origin, 600.0), bk, xf, func(pk, kit, _l): _kit_call(bk, "transmission_tower", [pk, kit, h, style]), 6000.0)
		_note_rect(p, 16.0, 16.0, 0.0)
		var pts: Array = bk.conductor_points(h, style) if _has_fn(bk, "conductor_points") else []
		var world: Array = []
		for q in pts:
			world.append(xf * ((q as Vector3) * PROP_SCALE))
		tops.append(world)
	# The conductors between neighbouring towers (game metres: a kit at scale 1 built in world space).
	for i in range(tops.size() - 1):
		var a: Array = tops[i]
		var b: Array = tops[i + 1]
		for k in range(mini(a.size(), b.size())):
			var pa: Vector3 = a[k]
			var pb: Vector3 = b[k]
			var sag: float = pa.distance_to(pb) * 0.03
			_add_prop_game(_cell_key("leitung", (pa + pb) * 0.5, 800.0), bk, Transform3D(), func(pk, kit, _l): _kit_call(bk, "conductor", [pk, kit, pa, pb, sag, 0.09]), 5000.0)


# ======================================================================================
#  Autobahn furniture: sign gantries over the lap's carriageway, exit signs, emergency phones, kilometre boards
# ======================================================================================

func _build_autobahn_furniture() -> void:
	if _bridge_kit == null:
		return
	var bk: Script = _bridge_kit
	var s9: float = float(segs[9]["s0"])
	var x9: float = float((segs[9]["p0"] as Vector2).x)
	# [x along the A 47, signs]: over the lap's carriageway heading east.
	var gantries: Array = [
		[-660.0, [[-3.5, 6.0, "A 58", "Kreuz Kronburg-West", "Weidenhoven"], [4.2, 4.6, "A 47", "Kronburg"]]],
		[-250.0, [[0.0, 7.0, "A 47", "Kronburg", "Kronburg-Rheinufer 1000 m"]]],
	]
	for g in gantries:
		var x: float = g[0]
		var s: float = s9 + (x - x9)
		var sp: Dictionary = _spot(s, 0.0, 0.0)
		var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(float(sp["yaw"]))), sp["pos"])
		# The gantry's signs face the oncoming lap (its +z toward the cars).
		var signs: Array = g[1]
		_add_prop(_cell_key("schilderbruecke", xf.origin, 400.0), bk, xf, func(pk, kit, labels):
			_kit_call(bk, "sign_gantry", [pk, kit, labels, (ROAD_HALF + 1.6) / PROP_SCALE, 6.4, signs]), 2200.0)
	# The exit sign before the ramp, Notrufsäulen and km boards on the A 47's outer verge.
	var se: float = s9 + (60.0 - x9)
	var esp: Dictionary = _spot(se, ROAD_HALF + 2.4, 0.0)
	_add_prop("ausfahrt_schild", bk, Transform3D(Basis(Vector3.UP, deg_to_rad(float(esp["yaw"]))), esp["pos"]), func(pk, kit, labels):
		_kit_call(bk, "exit_sign", [pk, kit, labels, 12, "Kronburg-Rheinufer"]), 1500.0)
	for xk in [-640.0, -480.0]:
		var sk2: float = s9 + (xk - x9)
		var ksp: Dictionary = _spot(sk2, ROAD_HALF + 2.0, 0.0)
		var kp: Vector3 = ksp["pos"]
		kp.y = _ground_at(kp.x, kp.z)
		var kxf := Transform3D(Basis(Vector3.UP, deg_to_rad(float(ksp["yaw"]))), kp)
		_add_prop(_cell_key("notruf", kp, 400.0), bk, kxf, func(pk, kit, _l): _kit_call(bk, "notrufsaeule", [pk, kit]), 900.0)
		_add_prop(_cell_key("notruf", kp, 400.0), bk, kxf * Transform3D(Basis(), Vector3(0, 0, -14.0)), func(pk, kit, labels): _kit_call(bk, "kilometre_board", [pk, kit, labels, 31 + int((xk + 700.0) / 160.0)]), 900.0)


# ======================================================================================
#  Sounds: the river along the banks, the Autobahn, the Kirmes, the church bells (ships, sheep, mill: their own nodes)
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


## Levels: each clip's measured RMS brought to about -24 dBFS at its unit size, then trimmed by ear.
func _build_sounds(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "RheinSounds"
	root.add_child(node)
	# The river lapping at the banks where the lap runs close: the west bank by the dyke, the east bank's riprap.
	var z: float = -420.0
	var k := 0
	while z <= 420.0:
		for side in [-1.0, 1.0]:
			var x: float = side * (RIVER_HALF + 2.0)
			var p := _player(node, "RiverLap%d" % k, "res://sounds/rheinufer/river_lap_loop.wav", Vector3(x, 1.0, z), -24.0 + 21.0 - 6.0, 16.0, 150.0)
			p.autoplay = true
			k += 1
		z += 140.0
	# The Autobahn's hum beside the A 58 and along the A 47.
	for at in [Vector3(A58_X, LAND_Y + 2.0, -150.0), Vector3(A58_X, LAND_Y + 2.0, -620.0), Vector3(A58_X, LAND_Y + 2.0, 300.0),
			Vector3(-520.0, 16.0, A47_WB), Vector3(-160.0, 24.0, A47_WB)]:
		var a := _player(node, "AutobahnHum%d" % k, "res://sounds/rheinufer/autobahn_traffic_loop.wav", at, -24.0 + 35.8 - 4.0, 30.0, 420.0)
		a.autoplay = true
		k += 1
	var kp := _player(node, "KirmesSound", "res://sounds/rheinufer/kirmes_loop.wav", Vector3(-240.0, KIRMES_Y + 4.0, 40.0), -24.0 + 19.4 - 3.0, 28.0, 520.0)
	kp.autoplay = true
	var bells := _player(node, "ChurchBells", "res://sounds/kronburg/church_bells.wav", Vector3(PROMENADE_X + 140.0, TOWN_Y + 60.0, -40.0), 6.0, 90.0, 1600.0, "res://PeriodicSound.gd")
	bells.set("every", 150.0)
	bells.set("phase", 95.0)


var _puff_tex: Texture2D

func _puff_texture() -> Texture2D:
	if _puff_tex == null:
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


## A plume of steam (the cooling towers) at `at`, `size` times the works' own.
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
	var steam: bool = kind == "steam"
	p.amount = 48
	p.lifetime = 18.0
	p.preprocess = p.lifetime
	p.visibility_aabb = AABB(Vector3(-150, -20, -150) * size, Vector3(300, 260, 300) * size)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 14.0 * size
	pm.direction = Vector3(0.2, 1.0, 0.1)
	pm.spread = 12.0
	pm.initial_velocity_min = 7.0 * size
	pm.initial_velocity_max = 10.0 * size
	pm.gravity = Vector3(1.6, -0.4, 0.8) * size
	pm.damping_min = 0.25 * size
	pm.damping_max = 0.45 * size
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.35))
	sc.add_point(Vector2(1.0, 1.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	quad.size = Vector2.ONE * 34.0 * size
	mat.albedo_texture = _puff_texture()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mat.disable_receive_shadows = true
	var c: Color = Color(0.97, 0.95, 0.93) if steam else Color(0.42, 0.40, 0.38)
	grad.colors = PackedColorArray([Color(c, 0.0), Color(c, 0.85), Color(c, 0.35), Color(c, 0.0)])
	grad.offsets = PackedFloat32Array([0.0, 0.08, 0.55, 1.0])
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	quad.material = mat
	p.draw_pass_1 = quad
	parent.add_child(p)
