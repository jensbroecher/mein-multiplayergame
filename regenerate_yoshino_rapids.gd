# regenerate_yoshino_rapids.gd
#
# Builds levels/YoshinoRapidsLevel.tscn - Yoshino Rapids, the second stage of the Miyoshino GP: a lap round a reach of
# the emerald Yoshino river at midday, in the valley where the cedar of the hills was lashed into rafts and floated
# down to the sea. The lap starts in the riverside village on the south bank heading west (downstream), crosses the
# river on the vermilion-railed timber bridge, runs east through the lumber yard past its water-powered sawmill (a creek
# off the hill feeds a mill pond, a raised flume carries the water onto the wheel, the tailrace runs under the yard road
# and down into the log pond, a bay of the river where the rafts are moored), climbs a twisting gravel forest road up and
# down through the cedar plantation, comes down a log-built timber slide (the shura), fords the river through the
# shallows of the upper rapids and returns along the south bank. A moored raft train lies across the calm pool above the
# bridge: a floating shortcut for whoever dares its width.
#
# Everything shared with the other Miyoshino stages is MiyoshinoStage.gd: read its header first. Here: the river
# (its line, width, level and depth as functions of x, which carve the ground and build the water), the course, what
# grows where, and the dressing.
extends "res://MiyoshinoStage.gd"

## Rapids, flowing west: [x, drop (m), length (m)]. The water's level falls by `drop` over `length` centred on x.
const RAPIDS := [[470.0, 1.2, 90.0], [120.0, 1.5, 70.0], [-160.0, 0.9, 60.0]]
## The ford: the lap wades the upper rapids' shallows here, this deep.
const FORD_X := 560.0
const FORD_DEPTH := 0.36
## The calm pool the rafts lie on.
const POOL_X := Vector2(-500.0, -215.0)
const DEEP := 2.5
## The lumber yard on the north bank: level ground.
const YARD_RECT := [-470.0, -196.0, -170.0, -112.0]
## The village's terrace on the south bank.
const VILLAGE_RECT := [-380.0, 96.0, 520.0, 190.0]
## The raft crossing: off the start straight, over the pool, onto the yard road.
const RAFT_PTS := [Vector2(-262.0, 125.0), Vector2(-322.0, 62.0), Vector2(-338.0, -96.0), Vector2(-292.0, -150.0)]
## The log pond: a bay of the river's north bank below the sawmill (an ellipse: its centre, its half widths in x and z),
## where the rafts lie moored.
const BAY_C := Vector2(-252.0, -93.0)
const BAY_R := Vector2(24.0, 16.0)
const BAY_DEPTH := 1.8
## The sawmill's frame: its west end (the wheel's) at x, its front this far off the yard road's edge.
const MILL_X := -270.0
const MILL_GAP := 4.0
## The flume (game metres): inside width, wall height, the water's depth in it, its fall toward the wheel (m per m).
const FLUME_IW := 0.86
const FLUME_WH := 0.58
const FLUME_WATER := 0.31
const FLUME_FALL := 0.01
## The mill pond's radius and depth.
const POND_R := 7.0
const POND_DEPTH := 1.3
## The village (the start straight, the user's picture of a Japanese town): the sidewalk along the houses' side (this
## wide from the road's edge, its kerb this high over the road), the riverside promenade (its middle this far right of
## the lap's line, this wide), the back lane behind the first row of houses (its middle this far left).
const SIDE_W := 6.0
const KERB := 0.16
const PROM_LAT := 20.0
const PROM_W := 4.0
const LANE_LAT := 34.5
const LANE_W := 3.6
## The riverside park between these x, from the promenade to the river: the garden stream from its spring pool under the
## drum bridge to the river, paths, two plazas, the tea house.
const PARK_X := Vector2(-236.0, -84.0)
const GARDEN_POOL := Vector3(-125.0, 98.0, 3.0)
const GARDEN_STREAM := [Vector2(-127.0, 95.5), Vector2(-131.0, 90.0), Vector2(-138.0, 82.0), Vector2(-146.0, 73.0), Vector2(-153.0, 63.0),
		Vector2(-162.0, 53.0), Vector2(-170.0, 42.0), Vector2(-175.0, 28.0), Vector2(-179.0, 12.0), Vector2(-184.0, -4.0), Vector2(-189.0, -28.0)]
const PARK_PATHS := [
	[Vector2(-92.0, 95.0), Vector2(-95.0, 80.0), Vector2(-104.0, 68.0)],
	[Vector2(-118.0, 58.0), Vector2(-140.0, 56.0), Vector2(-160.2, 55.1), Vector2(-178.0, 54.0), Vector2(-188.0, 46.0), Vector2(-189.0, 30.0), Vector2(-197.0, 8.0)],
	[Vector2(-205.0, 7.0), Vector2(-208.0, 25.0), Vector2(-213.0, 50.0), Vector2(-217.0, 75.0), Vector2(-220.0, 94.0)],
]
const PARK_PATH_HALF := 1.4
## [centre, radius] of the plazas: one round a weeping cherry, one looking out over the river.
const PARK_PLAZAS := [[Vector2(-110.0, 62.0), 9.0], [Vector2(-202.0, 2.0), 7.0]]
## The tea house on the stream's west bank (its middle), facing east across the water.
const TEA_HOUSE := Vector2(-196.0, 40.0)
## The park run: a shortcut for the bots (and anyone brave) off the start straight, across the promenade and the lawns,
## over the park's little drum bridge, along the river meadow onto the raft crossing. [point, corner radius]; the first
## is moved onto the lap's line. Everything keeps PARK_RUN_CLEAR off its line.
## The first corner is a long sweep (45m): bots come off the start straight flat out, and at 18m a third of them ran
## straight on past it.
const PARK_RUN := [[Vector2(-74.0, 116.0), 0.0], [Vector2(-102.0, 103.0), 45.0], [Vector2(-138.0, 57.0), 24.0],
		[Vector2(-182.0, 54.0), 16.0], [Vector2(-205.0, 60.0), 20.0], [Vector2(-322.5, 57.5), 14.0], [Vector2(-325.2, 30.0), 0.0]]
const PARK_RUN_CLEAR := 5.5
## The cherry-blossom fair on the promenade: from these metres past the finish line to these.
const FAIR := Vector2(16.0, 98.0)
## The heron in the shallows above the ford (x, metres right of the river's line), and how high its flight goes.
const HERON_AT := Vector2(590.0, -12.0)

var s_bridge0 := 0.0
var s_bridge1 := 0.0
var s_yard_end := 0.0
var s_chute0 := 0.0
var s_chute1 := 0.0
var s_south := 0.0
var raft_s0 := 0.0
var raft_s1 := 0.0
var _raw_route: Route
## The mill race, planned in _plan_race(): channel pieces carved into the ground, each a Dictionary: "name", "pts"
## (PackedVector2Array, downstream), "lv" (the water's level at each point), "hw" (the bed's half width), "depth" (bed under
## the water), "bank" (how steeply the sides rise, m per m), "box" (Rect2, where it can cut), "wet" (false: a dry notch).
var _race: Array = []
## The mill pond: x, its water level, z, its radius; and every pond the race's pieces start from (the mill pond, the
## park's spring pool).
var _pond := Vector4.ZERO
var _ponds: Array[Vector4] = []
## The sawmill's frame, the flume's floor (its top, on the middle line) from the pond's sluice to where it meets the
## sawmill's own trough, and the culverts under the yard road: [their bed's middle, the way out of them].
var _mill_xf := Transform3D.IDENTITY
var _flume_pts := PackedVector3Array()
var _culverts: Array = []
var _pit_level := 0.0
## The village's stretch of the lap (s), set before the dressing: the sidewalk runs along it.
var _sv0 := -1.0
var _sv1 := -1.0
## The park's little drum bridge (its middle on the ground, x along its deck), which the park run crosses; its span,
## width and rise (life).
var _park_bridge := Transform3D.IDENTITY
const PARK_BRIDGE := Vector3(7.5, 3.4, 0.7)


func _configure() -> void:
	level_name = "YoshinoRapidsLevel"
	level_path = "res://levels/YoshinoRapidsLevel.tscn"
	stem = "yoshinogawa"
	title = "Yoshino Rapids"
	seed_base = 7300
	road_half = 7.5
	max_grade = 0.095
	corners = [
		[Vector2(560.0, 125.0), 50.0],     # out of the ford: right onto the south bank's road, west
		[Vector2(250.0, 140.0), 220.0],    # the road sways with the river
		[Vector2(-130.0, 112.0), 220.0],
		[Vector2(-430.0, 125.0), 55.0],    # right, north onto the bridge
		[Vector2(-430.0, -150.0), 50.0],   # right, east through the lumber yard
		[Vector2(-150.0, -150.0), 40.0],   # left, up into the cedars
		[Vector2(-110.0, -265.0), 26.0],   # sharp right across the slope
		[Vector2(-20.0, -215.0), 24.0],    # sharp left, back up through the cedars
		[Vector2(40.0, -325.0), 28.0],     # right over the top
		[Vector2(150.0, -265.0), 30.0],    # left at the foot of the dip
		[Vector2(240.0, -300.0), 40.0],    # right, down the timber slide
		[Vector2(400.0, -150.0), 60.0],    # left, along the north bank
		[Vector2(560.0, -140.0), 45.0],    # right, south through the ford
	]
	finish_at = Vector2(60.0, 126.0)
	fine_x = Vector2(-700.0, 740.0)
	fine_z = Vector2(-560.0, 420.0)
	bare_surface = "gravel"
	tree_step = 10.5
	tree_margin = 300.0


# ======================================================================================
#  The river
# ======================================================================================

func _river_z(x: float) -> float:
	return 40.0 * sin(x / 170.0) + 12.0 * sin(x / 61.0 + 1.0)


func _pool(x: float) -> float:
	return smoothstep(POOL_X.x - 40.0, POOL_X.x + 40.0, x) * (1.0 - smoothstep(POOL_X.y - 30.0, POOL_X.y + 30.0, x))


func _ford(x: float) -> float:
	return 1.0 - smoothstep(26.0, 60.0, absf(x - FORD_X))


func _river_half(x: float) -> float:
	return 24.0 + 14.0 * _pool(x) + 12.0 * _ford(x)


func _water_y(x: float) -> float:
	var y := 0.0
	for r in RAPIDS:
		y += float(r[1]) * smoothstep(float(r[0]) - float(r[2]) * 0.5, float(r[0]) + float(r[2]) * 0.5, x)
	return y


## How rough the water is at x (0 a pool .. 1 white water).
func _rough(x: float) -> float:
	var t := 0.0
	for r in RAPIDS:
		t = maxf(t, 1.0 - smoothstep(float(r[2]) * 0.35, float(r[2]) * 0.8, absf(x - float(r[0]))))
	return t


func _depth(x: float) -> float:
	var d: float = lerpf(DEEP, 1.0, _rough(x))
	return lerpf(d, FORD_DEPTH + 0.05, _ford(x))


## Signed distance from the river's edge (or the log pond's): negative in the water.
func _shore_d(x: float, z: float) -> float:
	return minf(absf(z - _river_z(x)) - _river_half(x), _bay_d(x, z))


## Signed distance (roughly, in metres) from the log pond's edge: negative in it.
func _bay_d(x: float, z: float) -> float:
	var q := Vector2((x - BAY_C.x) / BAY_R.x, (z - BAY_C.y) / BAY_R.y)
	return (q.length() - 1.0) * minf(BAY_R.x, BAY_R.y)


func _map_water(x: float, z: float) -> float:
	var rw: float = _race_water_at(x, z)
	if not is_nan(rw):
		return rw
	return _water_y(x) if _shore_d(x, z) < 1.0 else NAN


## The ground before the mill race is cut into it.
func _natural(x: float, z: float) -> float:
	return minf(_natural_base(x, z), _race_cut(x, z))


func _natural_base(x: float, z: float) -> float:
	var zr: float = _river_z(x)
	var d: float = z - zr
	var hw: float = _river_half(x)
	var wy: float = _water_y(x)
	var ad: float = absf(d)
	if ad < hw:
		var q: float = ad / hw
		return wy - _depth(x) * pow(1.0 - q * q, 0.75)
	var out: float = ad - hw
	var h: float = wy + 2.7 * smoothstep(0.0, 13.0, out) + out * 0.006
	if d > 0.0:
		# The south bank: the village's terrace, then hills.
		h += maxf(0.0, z - 215.0) * 0.16 * (0.8 + 0.4 * n_land.get_noise_2d(x, z))
		h += smoothstep(215.0, 420.0, z) * 9.0 * n_hill.get_noise_2d(x * 0.6, z * 0.6)
	else:
		# The north bank: a strip of level ground, the plantation's slope, the steep hill behind.
		var t: float = maxf(0.0, out - 82.0)
		var hill: float = 0.1 * minf(t, 250.0) + 0.24 * maxf(0.0, t - 250.0)
		hill = minf(hill, 120.0 + 30.0 * n_land.get_noise_2d(x * 0.5, z * 0.5))
		h += hill + smoothstep(0.0, 120.0, t) * 5.0 * n_hill.get_noise_2d(x * 0.7, z * 0.7)
	h += 0.5 * n_fine.get_noise_2d(x * 0.4, z * 0.4) * smoothstep(8.0, 40.0, out)
	# Far ranges closing the valley.
	var far: float = Vector2(x, z).length()
	h += smoothstep(800.0, 3800.0, far) * (120.0 + 240.0 * absf(n_ridge.get_noise_2d(x, z))) * smoothstep(60.0, 500.0, ad)
	h = lerpf(h, _water_y(-320.0) + 3.0, _rect_weight(x, z, YARD_RECT, 28.0))
	h = lerpf(h, wy + 3.4, _rect_weight(x, z, VILLAGE_RECT, 30.0) * 0.85)
	# The log pond: a bowl off the river's bank, its banks rising like the river's.
	var bd: float = _bay_d(x, z)
	if bd < 30.0:
		var by: float = _water_y(BAY_C.x)
		var bh: float
		if bd < 0.0:
			var q: float = clampf(-bd / minf(BAY_R.x, BAY_R.y), 0.0, 1.0)
			bh = by - BAY_DEPTH * pow(1.0 - (1.0 - q) * (1.0 - q), 0.75)
		else:
			bh = by + 2.7 * smoothstep(0.0, 13.0, bd) + bd * 0.05
		h = minf(h, bh)
	return h


# ======================================================================================
#  The mill race
# ======================================================================================

## The sawmill's water, laid out before the ground is built (its channels are cut into `_natural`): a creek off the
## north hill into the mill pond; the sluice; the flume on trestles to the sawmill's own trough and over the wheel; the
## wheel pit; a culvert under the yard road; the brook down into the log pond.
func _plan_race() -> void:
	var rk: Script = load("res://MiyoshinoRiverKit.gd")
	var ms: float = PROP_SCALE
	var axle: Vector3 = rk.sawmill_wheel_at() if rk else Vector3(1.3, 2.75, -5.15)
	var wr: float = 2.4
	var fl: Array = rk.sawmill_flume() if rk else [1.3, 0.27, 5.465, -9.0, -4.7]
	var at := Vector3(MILL_X, 0.0, -150.0 - road_half - MILL_GAP)
	at.y = _natural_base(at.x + 8.0, at.z - 6.0)
	_mill_xf = Transform3D(Basis(), at)
	var wx: float = at.x + axle.x * ms
	# The wheel pit (inside the kit's stone walls), its water a little under the yard.
	var pit_z0: float = at.z + (axle.z - wr - 0.3) * ms
	var pit_z1: float = at.z + (axle.z + wr + 0.3) * ms
	_pit_level = at.y - 0.55
	_race.append(_race_piece("pit", [Vector2(wx, pit_z0 + 0.3), Vector2(wx, pit_z1 + 0.5)], [_pit_level, _pit_level], 0.95, 0.95, 3.0))
	# Under the yard road: the culvert's mouths where the road's grading lets the channel show.
	var z_n: float = pit_z1 + 0.05
	var z_s: float = -150.0 + road_half + 2.0 + 4.6
	_culverts = [[Vector3(wx, _pit_level - 0.95, z_n), Vector3(0, 0, -1)], [Vector3(wx, _pit_level - 0.1 - 0.45, z_s), Vector3(0, 0, 1)]]
	# The brook from the culvert down to the log pond, in two small falls.
	var brook: Array = [Vector2(wx, z_s - 0.8), Vector2(wx + 1.5, -127.0), Vector2(wx + 3.0, -119.0), Vector2(wx + 4.5, -111.0), Vector2(wx + 6.0, -104.0), Vector2(wx + 7.5, -98.0)]
	var by: float = _water_y(BAY_C.x)
	var ctrl: Array = [_pit_level - 0.1, _pit_level - 0.3, by + 1.35, by + 1.1, by + 0.1, by]
	_race.append(_race_piece("brook", brook, _levels(brook, ctrl, 0.4), 1.1, 0.45, 1.0))
	# The flume: from the sawmill's trough back up the hill until the ground can hold a pond at its height.
	var j := at + Vector3(float(fl[0]), float(fl[2]), float(fl[3])) * ms
	var d := 12.0
	while d < 160.0:
		var floor_y: float = j.y + FLUME_FALL * d
		var level: float = floor_y + FLUME_WATER + 0.12
		var rim := Vector2(wx, j.z - d - 0.4)
		if _natural_base(rim.x, rim.y) >= level + 0.5 and _natural_base(rim.x, rim.y - POND_R) >= level + 0.8:
			break
		d += 1.0
	var start := Vector3(wx, j.y + FLUME_FALL * d, j.z - d)
	_flume_pts = PackedVector3Array()
	var n: int = maxi(2, int(ceil(d / 2.0)))
	for i in range(n + 1):
		_flume_pts.append(start.lerp(j, float(i) / float(n)))
	var pond_level: float = start.y + FLUME_WATER + 0.12
	var pc := Vector2(wx - 0.8, start.z - 0.4 - POND_R)
	_pond = Vector4(pc.x, pond_level, pc.y, POND_R)
	_ponds.append(_pond)
	# A notch through the pond's bank for the flume's mouth (dry: its water is in the trough).
	_race.append(_race_piece("intake", [Vector2(wx, start.z - 1.2), Vector2(wx, start.z + 5.0)], [start.y - 0.1, start.y - 0.12], 0.75, 0.0, 1.3, false))
	# The creek down the hill into the pond: a wandering line, its water a little under the ground and never rising.
	var creek: Array = []
	var k := 0
	var z := pc.y - POND_R * 0.6
	while k < 13:
		creek.push_front(Vector2(pc.x + 7.0 * sin(float(k) * 0.9) + 3.0 * sin(float(k) * 2.3), z))
		z -= 14.0
		k += 1
	var c_ctrl: Array = []
	for q in creek:
		c_ctrl.append(INF)
	c_ctrl[c_ctrl.size() - 1] = pond_level
	_race.append(_race_piece("creek", creek, _levels(creek, c_ctrl, 0.55, pond_level), 0.9, 0.4, 0.9))
	# The park's garden stream: from its spring pool by the promenade, under the drum bridge, down through the park.
	var garden: Array = GARDEN_STREAM.duplicate()
	var g_ctrl: Array = []
	for q in garden:
		g_ctrl.append(INF)
	var g_end: Vector2 = garden[garden.size() - 1]
	var g_lv: Array = _levels(garden, g_ctrl, 0.45, _water_y(g_end.x) - 0.05)
	_ponds.append(Vector4(GARDEN_POOL.x, float(g_lv[0]), GARDEN_POOL.y, GARDEN_POOL.z))
	_race.append(_race_piece("garden", garden, g_lv, 1.2, 0.45, 0.7))
	print("  the garden stream: %.0fm from its pool (%.1fm) to the river" % [_poly_len(garden), float(g_lv[0])])
	print("  the mill race: the flume %.0fm from the pond (water %.1fm) to the wheel, the pit's water %.1fm, the brook %.0fm" % [
			d + absf(float(fl[3]) - float(fl[4])) * ms, pond_level, _pit_level, _poly_len(brook)])


## A channel piece: see `_race`. Its points are resampled every metre.
func _race_piece(piece_name: String, pts: Array, levels: Array, hw: float, depth: float, bank: float, wet := true) -> Dictionary:
	var out_p := PackedVector2Array()
	var out_l := PackedFloat32Array()
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var m: int = maxi(1, int(ceil(a.distance_to(b))))
		for k in range(m):
			var t: float = float(k) / float(m)
			out_p.append(a.lerp(b, t))
			out_l.append(lerpf(float(levels[i]), float(levels[i + 1]), t))
	out_p.append(pts[pts.size() - 1])
	out_l.append(float(levels[levels.size() - 1]))
	var box := Rect2(out_p[0], Vector2.ZERO)
	for q in out_p:
		box = box.expand(q)
	var reach: float = hw + 0.35 * depth + 8.0
	box = box.grow(reach)
	return {"name": piece_name, "pts": out_p, "lv": out_l, "hw": hw, "depth": depth, "bank": bank, "box": box, "wet": wet}


## The water's levels at `pts`: the wanted ones (`ctrl`, INF for none), but never less than `free` under the uncut ground
## there and never rising downstream; `floor_y` the least.
func _levels(pts: Array, ctrl: Array, free: float, floor_y := -INF) -> Array:
	var out: Array = []
	var prev := INF
	for i in range(pts.size()):
		var p: Vector2 = pts[i]
		var v: float = minf(float(ctrl[i]), _natural_base(p.x, p.y) - free)
		v = minf(v, prev)
		out.append(v)
		prev = v
	for i in range(out.size()):
		out[i] = maxf(float(out[i]), floor_y)
	return out


func _poly_len(pts: Array) -> float:
	var l := 0.0
	for i in range(pts.size() - 1):
		l += (pts[i] as Vector2).distance_to(pts[i + 1])
	return l


## The nearest point of a piece to (x, z): [distance, index along it (fractional)], or [] when out of its box.
func _race_near(pc: Dictionary, x: float, z: float) -> Array:
	if not (pc["box"] as Rect2).has_point(Vector2(x, z)):
		return []
	var pts: PackedVector2Array = pc["pts"]
	var q := Vector2(x, z)
	var best := INF
	var best_t := 0.0
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var ab: Vector2 = pts[i + 1] - a
		var l2: float = ab.length_squared()
		var t: float = 0.0 if l2 < 1e-6 else clampf((q - a).dot(ab) / l2, 0.0, 1.0)
		var dd: float = q.distance_squared_to(a + ab * t)
		if dd < best:
			best = dd
			best_t = float(i) + t
	return [sqrt(best), best_t]


func _piece_level(pc: Dictionary, t: float) -> float:
	var lv: PackedFloat32Array = pc["lv"]
	var i: int = clampi(int(floor(t)), 0, lv.size() - 1)
	var i1: int = mini(i + 1, lv.size() - 1)
	return lerpf(lv[i], lv[i1], t - float(i))


## How high the ground may be at (x, z) for the channels and the pond: INF where none of them is near.
func _race_cut(x: float, z: float) -> float:
	var cap := INF
	for pc in _race:
		var nr: Array = _race_near(pc, x, z)
		if nr.is_empty():
			continue
		var d: float = nr[0]
		var lv: float = _piece_level(pc, nr[1])
		var depth: float = pc["depth"]
		var hw: float = pc["hw"]
		var bed: float = lv - depth
		var c: float
		if d < hw:
			c = bed + depth * 0.35 * (d / hw) * (d / hw)
		else:
			c = bed + depth * 0.35 + (d - hw) * float(pc["bank"])
		cap = minf(cap, c)
	for pd in _ponds:
		var dp: float = Vector2(x - pd.x, z - pd.z).length()
		if dp < pd.w + 25.0:
			var pb: float = pd.y - POND_DEPTH
			if dp < pd.w:
				cap = minf(cap, pb + POND_DEPTH * 0.75 * pow(dp / pd.w, 2.0))
			else:
				cap = minf(cap, pb + POND_DEPTH * 0.75 + (dp - pd.w) * 1.1)
	return cap


## The surface of the race's water at (x, z) (the pond, a wet channel), or NAN.
func _race_water_at(x: float, z: float) -> float:
	for pd in _ponds:
		if Vector2(x - pd.x, z - pd.z).length() < pd.w + 0.6:
			return pd.y
	for pc in _race:
		if not bool(pc["wet"]):
			continue
		var nr: Array = _race_near(pc, x, z)
		if nr.is_empty():
			continue
		if float(nr[0]) < _race_half_water(pc):
			return _piece_level(pc, nr[1])
	return NAN


## How far either side of a piece's line its water reaches (where the bank rises through its level).
func _race_half_water(pc: Dictionary) -> float:
	var bank: float = maxf(float(pc["bank"]), 0.01)
	return float(pc["hw"]) + 0.65 * float(pc["depth"]) / bank


## Distance to the nearest wet channel's line, the pond's edge or the flume (for what grows and the ground's look).
func _race_d(x: float, z: float) -> float:
	var best := INF
	for pc in _race:
		var nr: Array = _race_near(pc, x, z)
		if not nr.is_empty():
			best = minf(best, float(nr[0]) - _race_half_water(pc))
	for pd in _ponds:
		best = minf(best, Vector2(x - pd.x, z - pd.z).length() - pd.w)
	if _flume_pts.size() > 1:
		var a: Vector3 = _flume_pts[0]
		var b: Vector3 = _flume_pts[_flume_pts.size() - 1]
		if absf(x - a.x) < 12.0 and z > a.z - 4.0 and z < b.z + 4.0:
			best = minf(best, absf(x - a.x) - 1.5)
	return best


# ======================================================================================
#  The course
# ======================================================================================

func _init_noise() -> void:
	super._init_noise()
	_plan_race()
	_raw_route = Route.new()
	_raw_route.build(corners, true)
	# The bridge: where the lap's leg north along x = -430 is over the water (and a little of each bank).
	var s: float = _raw_route.closest_s(Vector2(-430.0, 70.0))
	var a := -1.0
	var b := -1.0
	var k: float = s
	while k < s + 220.0:
		var p: Vector2 = _raw_route.at(k)["p"]
		if _shore_d(p.x, p.y) < 7.0:
			if a < 0.0:
				a = k
			b = k
		k += 1.0
	s_bridge0 = a
	s_bridge1 = b
	bridges = [["lap", s_bridge0, s_bridge1, 2.6]]
	s_yard_end = _raw_route.closest_s(Vector2(-150.0, -150.0)) - 30.0
	s_chute0 = _raw_route.closest_s(Vector2(262.0, -279.0))
	s_chute1 = _raw_route.closest_s(Vector2(378.0, -171.0))
	s_south = _raw_route.closest_s(Vector2(560.0, 70.0))
	print("  the bridge from %.0f to %.0fm, the timber slide %.0f to %.0fm" % [s_bridge0, s_bridge1, s_chute0, s_chute1])


func _road_base(r: Route, _s: float, p: Vector2) -> float:
	var sd: float = _shore_d(p.x, p.y)
	if r.name == "RaftCrossing":
		# The banks down to the rafts' deck, a hand over the water.
		return maxf(_natural(p.x, p.y) + GROUND_UNDER, _water_y(p.x) + 0.5)
	if _ford(p.x) > 0.5 and sd < 3.0:
		return _water_y(p.x) - FORD_DEPTH
	return _natural(p.x, p.y) + GROUND_UNDER


func _plan_routes() -> void:
	var pts: Array = [[RAFT_PTS[0], 0.0], [RAFT_PTS[1], 22.0], [RAFT_PTS[2], 22.0], [RAFT_PTS[3], 0.0]]
	# Where the crossing is over the water: its own deck, not graded.
	var probe := Route.new()
	probe.build(pts, false)
	var a := -1.0
	var b := -1.0
	var s := 0.0
	while s < probe.length:
		var p: Vector2 = probe.at(s)["p"]
		if _shore_d(p.x, p.y) < 0.5:
			if a < 0.0:
				a = s
			b = s
		s += 1.0
	raft_s0 = a
	raft_s1 = b
	bridges.append(["RaftCrossing", raft_s0, raft_s1, 0.0, true])
	var r: Route = _add_route("RaftCrossing", pts, 4.6, true, 0.16)
	_report_profile(r)
	print("  the raft crossing: on the water from %.0f to %.0fm of %.0fm" % [raft_s0, raft_s1, r.length])
	shortcuts = [["RaftCrossing", 0.6]]


func _sections(r: Route) -> Array:
	if r.name == "RaftCrossing":
		var off: Vector2 = _off_lap_range(r)
		return [[off.x, raft_s0, K_DIRT, r.half, 1], [raft_s1, off.y, K_DIRT, r.half, 2]]
	return [[0.0, s_bridge0, K_ASPHALT, r.half], [s_bridge0, s_bridge1, K_PLANKS, r.half], [s_bridge1, s_chute0, K_GRAVEL, r.half],
			[s_chute0, s_chute1, K_PLANKS, r.half], [s_chute1, s_south, K_GRAVEL, r.half], [s_south, r.length, K_ASPHALT, r.half]]


func _grade_params(r: Route, s: float) -> Array:
	if r.name == "RaftCrossing":
		return [r.half + 1.0, r.half + 1.0, 0.8, 0.8]
	return [r.half + 2.0, r.half + 2.0, cut_slope, fill_slope]


# ======================================================================================
#  What grows where
# ======================================================================================

## Cherries along both banks and through the village.
func _grove_w(x: float, z: float) -> float:
	var sd: float = _shore_d(x, z)
	var bank: float = smoothstep(4.0, 14.0, sd) * (1.0 - smoothstep(40.0, 75.0, sd))
	var south: float = 1.0 if z > _river_z(x) else 0.55
	return clampf(bank * south * (0.45 + 0.7 * smoothstep(-0.2, 0.3, n_wood.get_noise_2d(x * 1.5, z * 1.5))), 0.0, 1.0) \
			* (1.0 - _rect_weight(x, z, YARD_RECT, 10.0))


## The cedar plantation on the north hill, woods on the southern hills.
func _forest_w(x: float, z: float) -> float:
	var d: float = z - _river_z(x)
	var sd: float = _shore_d(x, z)
	var w := 0.0
	if d < 0.0:
		w = smoothstep(70.0, 110.0, sd)
	else:
		w = smoothstep(215.0, 260.0, z) * (0.6 + 0.4 * n_wood.get_noise_2d(x, z))
	return clampf(w, 0.0, 1.0) * (1.0 - _rect_weight(x, z, YARD_RECT, 6.0))


func _masks(_i: int, x: float, z: float, nrm_y: float, road_d: float) -> Color:
	var off: float = smoothstep(road_half + 3.0, road_half + 14.0, road_d)
	var rock: float = 1.0 - smoothstep(0.60, 0.76, nrm_y)
	var sd: float = _shore_d(x, z)
	# Shingle in the bed and up the banks, the yard's trodden ground, the village's lanes.
	var bare: float = 1.0 - smoothstep(3.0, 9.0, sd + 2.0 * n_fine.get_noise_2d(x, z))
	bare = maxf(bare, _rect_weight(x, z, YARD_RECT, 8.0))
	# Wet stones along the creek, the brook and round the mill pond.
	bare = maxf(bare, 1.0 - smoothstep(0.3, 2.2, _race_d(x, z) + 0.6 * n_fine.get_noise_2d(x * 2.0, z * 2.0)))
	var grove: float = _grove_w(x, z)
	var forest: float = _forest_w(x, z) * (1.0 - grove)
	return Color(rock * (1.0 - bare), bare, grove * off * (1.0 - bare), forest * off * (1.0 - bare))


func _wet(x: float, z: float) -> float:
	return maxf(1.0 - smoothstep(-1.0, 7.0, _shore_d(x, z)), 1.0 - smoothstep(-0.5, 2.0, _race_d(x, z)))


func _tree_pick(x: float, z: float, roll: float, rng: RandomNumberGenerator) -> Array:
	var sd: float = _shore_d(x, z)
	if sd < 5.0 or _in_rect(x, z, YARD_RECT, 4.0) or _race_d(x, z) < 3.5:
		return []
	if _in_rect(x, z, VILLAGE_RECT, -6.0) and z > 132.0:
		return []
	if _in_park(x, z) or _run_d(x, z) < PARK_RUN_CLEAR + 4.0:
		return []
	var g: float = _grove_w(x, z)
	var f: float = _forest_w(x, z) * (1.0 - g)
	f *= lerpf(1.0, 0.3, smoothstep(560.0, 760.0, Vector2(x, z).length()))
	if roll < g * 0.5:
		var r: float = rng.randf()
		if r < 0.12:
			return ["momiji", rng.randf_range(0.9, 1.2)]
		if r < 0.2:
			return ["shidare", rng.randf_range(0.9, 1.15)]
		if r < 0.5:
			return ["yamazakura", rng.randf_range(0.85, 1.15), rng.randi_range(0, 1)]
		return ["sakura", rng.randf_range(0.85, 1.2), rng.randi_range(0, 1)]
	if roll < g * 0.5 + f * 0.6:
		if z > 0.0 and rng.randf() < 0.25:
			return ["yamazakura", rng.randf_range(0.9, 1.2)]
		if z > 0.0 and rng.randf() < 0.15:
			return ["take", rng.randf_range(0.9, 1.15)]
		return ["sugi", rng.randf_range(0.8, 1.2), rng.randi_range(0, 1)]
	return []


func _environment() -> Dictionary:
	# Midday, the sun high in the south, a few more clouds.
	return {"sun_pitch": -62.0, "sun_yaw": -8.0, "cloud_coverage": 0.42, "cloud_seed": 33.1, "fog_end": 3400.0,
		"sun_energy": 1.45, "ambient": 0.6}


func _ground_params(m: ShaderMaterial) -> void:
	m.set_shader_parameter("petal_amount", 1.0)
	m.set_shader_parameter("moss_amount", 0.6)
	m.set_shader_parameter("earth_tint", Color(0.52, 0.47, 0.40))


# ======================================================================================
#  Gameplay
# ======================================================================================

func _place_gameplay(root: Node3D) -> void:
	var fin: float = _finish_s()
	_checkpoints([
		_closest_s(Vector2(-215.0, -150.0)),   # the lumber yard (past where the rafts land and the sawmill)
		_closest_s(Vector2(95.0, -295.0)),     # the forest road, over the top
		_closest_s(Vector2(470.0, -146.0)),    # below the timber slide
		_closest_s(Vector2(560.0, 62.0)),      # out of the ford
		_closest_s(Vector2(330.0, 136.0)),     # the village
	])
	_boosts([
		["Boost_Village", fin + 90.0, 0.0],
		["Boost_Yard", _closest_s(Vector2(-330.0, -150.0)), -2.6],
		["Boost_Forest", _closest_s(Vector2(62.0, -313.0)), 0.0],
	])
	# The timber slide ends in a lip: a low kicker at its foot.
	_kicker(root, "SlideJump", lap, s_chute1 - 4.0, 10.0, 1.3, 0.35)


# ======================================================================================
#  The water
# ======================================================================================

func _build_water(root: Node3D) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://river_water.gdshader")
	var n := FastNoiseLite.new()
	n.seed = 3301
	n.frequency = 0.035
	n.fractal_octaves = 3
	var nt := NoiseTexture2D.new()
	nt.seamless = true
	nt.as_normal_map = true
	nt.bump_strength = 6.0
	nt.noise = n
	nt.width = 256
	nt.height = 256
	mat.set_shader_parameter("noise_tex", nt)
	var f := FastNoiseLite.new()
	f.seed = 919
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
	# The Yoshino's emerald: clear green shallows over the shingle, deep jade pools.
	mat.set_shader_parameter("deep_color", Color(0.012, 0.13, 0.10))
	mat.set_shader_parameter("shallow_color", Color(0.08, 0.36, 0.26))
	mat.set_shader_parameter("sky_tint", Color(0.26, 0.42, 0.40))
	mat.set_shader_parameter("flow_speed", 1.6)
	mat.set_shader_parameter("clarity_depth", 2.0)
	mat.set_shader_parameter("shore_foam_depth", 0.2)
	var smat: Material = _save_res(mat, "river_material")
	var node := Node3D.new()
	node.name = "RiverWater"
	node.set_script(load("res://RiverWater.gd"))
	root.add_child(node)
	var pts := PackedVector3Array()
	var halves := PackedFloat32Array()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var across := 8
	var x0 := 1500.0
	var x1 := -1500.0
	var step := 6.0
	var n_s: int = int((x0 - x1) / step)
	var rows: Array = []
	# Downstream is west: the ribbon runs from the east end to the west one, UV.y metres downstream.
	for i in range(n_s + 1):
		var x: float = x0 - float(i) * step
		var p := Vector3(x, _water_y(x), _river_z(x))
		var hw: float = _river_half(x) + 2.5
		pts.append(p)
		halves.append(hw)
		var dzdx: float = (_river_z(x - 1.0) - _river_z(x + 1.0)) / 2.0
		var fwd := Vector3(-1.0, 0.0, dzdx).normalized()
		var right := Vector3(-fwd.z, 0.0, fwd.x)
		var rough: float = _rough(x)
		var row: Array = []
		for k in range(across + 1):
			var u: float = float(k) / float(across)
			row.append([p + right * lerpf(-hw, hw, u), Color(rough * 0.42, 0.35 + rough * 0.9, 0.0, 1.0), Vector2(u, float(i) * step)])
		rows.append(row)
	for i in range(n_s):
		for k in range(across):
			var a: Array = rows[i][k]
			var b: Array = rows[i][k + 1]
			var c: Array = rows[i + 1][k]
			var d: Array = rows[i + 1][k + 1]
			for tri in [[a, b, c], [b, d, c]]:
				var p0: Vector3 = tri[0][0]
				var p1: Vector3 = tri[1][0]
				var p2: Vector3 = tri[2][0]
				var order: Array = tri
				# Clockwise from above (Godot's front face).
				if (p2 - p0).cross(p1 - p0).y < 0.0:
					order = [tri[0], tri[2], tri[1]]
				for v in order:
					st.set_color(v[1])
					st.set_uv(v[2])
					st.set_normal(Vector3.UP)
					st.add_vertex(v[0])
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, smat)
	var mi := MeshInstance3D.new()
	mi.name = "RiverSurface"
	mi.mesh = _save_res(mesh, "river", stem + "far_")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	node.set("strip_points", pts)
	node.set("strip_half_widths", halves)
	node.set("strip_starts", PackedInt32Array([0]))
	node.set("water_bounds", Rect2(-1500.0, -140.0, 3000.0, 280.0))
	# The log pond: the river's water over the bay, its surface for the carts as three discs.
	_build_bay_water(node, smat)
	var pools: Array[Vector4] = []
	for k in [-1.0, 0.0, 1.0]:
		pools.append(Vector4(BAY_C.x + k * BAY_R.x * 0.45, _water_y(BAY_C.x), BAY_C.y - 1.0, BAY_R.y * 0.95))
	node.set("pools", pools)
	_build_race_water(root, mat)


## Adds one triangle to `st`, wound clockwise from above (Godot's front face). Each vertex: [position, colour, uv].
func _water_tri(st: SurfaceTool, a: Array, b: Array, c: Array) -> void:
	var order: Array = [a, b, c]
	if ((c[0] as Vector3) - (a[0] as Vector3)).cross((b[0] as Vector3) - (a[0] as Vector3)).y < 0.0:
		order = [a, c, b]
	for v in order:
		st.set_color(v[1])
		st.set_uv(v[2])
		st.set_normal(Vector3.UP)
		st.add_vertex(v[0])


## The log pond's surface: a grid over the bay a hand over the river's level, fading out where the river's own surface
## lies under it (its mouth).
func _build_bay_water(node: Node3D, mat: Material) -> void:
	var by: float = _water_y(BAY_C.x) + 0.01
	var step := 2.0
	var pad := 4.0
	var nx: int = int(ceil((BAY_R.x + pad) * 2.0 / step))
	var nz: int = int(ceil((BAY_R.y + pad) * 2.0 / step))
	var x0: float = BAY_C.x - BAY_R.x - pad
	var z0: float = BAY_C.y - BAY_R.y - pad
	var vtx := func(i: int, k: int) -> Array:
		var x: float = x0 + float(i) * step
		var z: float = z0 + float(k) * step
		var rsd: float = absf(z - _river_z(x)) - _river_half(x)
		var fade: float = 1.0 - smoothstep(-0.5, 3.0, rsd)
		return [Vector3(x, by, z), Color(0.0, 0.05, fade, 1.0), Vector2(float(i) / float(nx), z - z0)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cells := 0
	for i in range(nx):
		for k in range(nz):
			var inside := false
			for c in [[i, k], [i + 1, k], [i, k + 1], [i + 1, k + 1]]:
				if _bay_d(x0 + float(c[0]) * step, z0 + float(c[1]) * step) < 2.5:
					inside = true
			if not inside:
				continue
			var a: Array = vtx.call(i, k)
			var b: Array = vtx.call(i + 1, k)
			var c2: Array = vtx.call(i, k + 1)
			var d: Array = vtx.call(i + 1, k + 1)
			_water_tri(st, a, b, c2)
			_water_tri(st, b, d, c2)
			cells += 1
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = "BayWaterSurface"
	mi.mesh = _save_res(mesh, "bay_water")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	print("  the log pond: %d cells of water" % cells)


## The mill race's running water: the creek, the pond, the flume, over the wheel, the pit and the brook.
func _build_race_water(root: Node3D, river_mat: ShaderMaterial) -> void:
	var holder := Node3D.new()
	holder.name = "MillRaceWater"
	root.add_child(holder)
	var cm: ShaderMaterial = river_mat.duplicate() as ShaderMaterial
	cm.set_shader_parameter("flow_speed", 2.6)
	cm.set_shader_parameter("ripple_scale", 0.35)
	cm.set_shader_parameter("clarity_depth", 0.7)
	cm.set_shader_parameter("shore_foam_depth", 0.06)
	cm.set_shader_parameter("shallow_alpha", 0.55)
	cm.set_shader_parameter("shallow_color", Color(0.10, 0.34, 0.27))
	var cmat: Material = _save_res(cm, "creek_water_material")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The channels, as ribbons on their levels; their speed and their white water from how fast they fall.
	for pc in _race:
		if not bool(pc["wet"]):
			continue
		var ppts: PackedVector2Array = pc["pts"]
		var lv: PackedFloat32Array = pc["lv"]
		var half: float = _race_half_water(pc) + 0.15
		var n: int = ppts.size()
		var rows: Array = []
		var dist := 0.0
		for i in range(n):
			var pa: Vector2 = ppts[maxi(i - 1, 0)]
			var pb: Vector2 = ppts[mini(i + 1, n - 1)]
			var dir: Vector2 = (pb - pa).normalized()
			var right := Vector2(-dir.y, dir.x)
			if i > 0:
				dist += ppts[i].distance_to(ppts[i - 1])
			var fall: float = (lv[maxi(i - 1, 0)] - lv[mini(i + 1, n - 1)]) / maxf(pa.distance_to(pb), 0.5)
			var turb: float = clampf(fall * 4.0, 0.08, 1.0)
			if String(pc["name"]) == "pit":
				turb = 0.95
			var cur: float = clampf(0.5 + fall * 8.0, 0.5, 1.6)
			var row: Array = []
			for k in range(3):
				var u: float = float(k) / 2.0
				var q: Vector2 = ppts[i] + right * lerpf(-half, half, u)
				row.append([Vector3(q.x, lv[i], q.y), Color(turb, cur, 0.0, 1.0), Vector2(u, dist)])
			rows.append(row)
		for i in range(n - 1):
			for k in range(2):
				_water_tri(st, rows[i][k], rows[i][k + 1], rows[i + 1][k])
				_water_tri(st, rows[i][k + 1], rows[i + 1][k + 1], rows[i + 1][k])
	# The mill pond: a disc, nearly still.
	for pd in _ponds:
		var segs := 24
		var pr: float = pd.w + 0.5
		var cv := [Vector3(pd.x, pd.y, pd.z), Color(0.0, 0.12, 0.0, 1.0), Vector2(0.5, 0.0)]
		for k in range(segs):
			var a0: float = TAU * float(k) / float(segs)
			var a1: float = TAU * float(k + 1) / float(segs)
			var va := [Vector3(pd.x + cos(a0) * pr, pd.y, pd.z + sin(a0) * pr), Color(0.0, 0.12, 0.0, 1.0), Vector2(0.5 + 0.5 * cos(a0), pr * sin(a0))]
			var vb := [Vector3(pd.x + cos(a1) * pr, pd.y, pd.z + sin(a1) * pr), Color(0.0, 0.12, 0.0, 1.0), Vector2(0.5 + 0.5 * cos(a1), pr * sin(a1))]
			_water_tri(st, cv, va, vb)
	# The flume: the water in its trough from the sluice to the lip over the wheel (the sawmill's own trough included).
	# (The kits are loaded after the water is built: ask the river kit's script itself.)
	var rk: Script = load("res://MiyoshinoRiverKit.gd")
	var fl: Array = rk.sawmill_flume()
	var lip: Vector3 = _mill_xf * (Vector3(float(fl[0]), float(fl[2]), float(fl[4])) * PROP_SCALE)
	var line := PackedVector3Array(_flume_pts)
	line.append(lip)
	var fh: float = FLUME_IW * 0.5 - 0.01
	var fd := 0.0
	for i in range(line.size() - 1):
		var a: Vector3 = line[i] + Vector3(0, FLUME_WATER, 0)
		var b: Vector3 = line[i + 1] + Vector3(0, FLUME_WATER, 0)
		var dir := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
		var rt := Vector3(-dir.z, 0.0, dir.x) * fh
		var l: float = a.distance_to(b)
		var col := Color(0.15, 1.3, 0.0, 1.0)
		var va := [a - rt, col, Vector2(0.0, fd)]
		var vb := [a + rt, col, Vector2(1.0, fd)]
		var vc := [b - rt, col, Vector2(0.0, fd + l)]
		var vd := [b + rt, col, Vector2(1.0, fd + l)]
		_water_tri(st, va, vb, vc)
		_water_tri(st, vb, vd, vc)
		fd += l
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, cmat)
	var mi := MeshInstance3D.new()
	mi.name = "MillRaceSurface"
	mi.mesh = _save_res(mesh, "mill_race_water")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(mi)
	_build_wheel_fall(holder, lip + Vector3(0, FLUME_WATER, 0))
	var axle: Vector3 = _mill_xf * (rk.sawmill_wheel_at() * PROP_SCALE)
	_player(holder, "MillWheelWater", "res://sounds/Gentle_flowing_water.wav", axle, -3.0, 9.0, 90.0)
	_player(holder, "BrookWater", "res://sounds/Gentle_flowing_water.wav", Vector3(_mill_xf.origin.x + 4.0, _pit_level, -118.0), -8.0, 6.0, 60.0)


## The water spilling off the flume's lip into the wheel's buckets, round its downstream side and down into the pit: a
## curtain hugging the rim (waterfall.gdshader).
func _build_wheel_fall(holder: Node3D, lip: Vector3) -> void:
	var rk: Script = load("res://MiyoshinoRiverKit.gd")
	var axle: Vector3 = _mill_xf * (rk.sawmill_wheel_at() * PROP_SCALE)
	var wr: float = 2.4 * PROP_SCALE + 0.08
	var path: Array = [lip, lip + Vector3(0, -0.12, 0.12)]
	var th0: float = asin(clampf((lip.z + 0.25 - axle.z) / wr, 0.0, 0.9))
	var th: float = th0
	while th < deg_to_rad(176.0):
		path.append(axle + Vector3(0, cos(th), sin(th)) * wr)
		th += deg_to_rad(6.0)
	var bottom: Vector3 = path[path.size() - 1]
	path.append(Vector3(bottom.x, _pit_level + 0.02, bottom.z - 0.15))
	var total := 0.0
	for i in range(path.size() - 1):
		total += (path[i] as Vector3).distance_to(path[i + 1])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw: float = FLUME_IW * 0.5 - 0.04
	var acc := 0.0
	var rows: Array = []
	for i in range(path.size()):
		if i > 0:
			acc += (path[i] as Vector3).distance_to(path[i - 1])
		var p: Vector3 = path[i]
		var out := Vector3(0, p.y - axle.y, p.z - axle.z).normalized()
		var row: Array = []
		for k in range(3):
			var u: float = float(k) / 2.0
			row.append([p + Vector3(lerpf(-hw, hw, u), 0, 0), out, Vector2(u, acc / total)])
		rows.append(row)
	for i in range(rows.size() - 1):
		for k in range(2):
			for v in [rows[i][k], rows[i][k + 1], rows[i + 1][k], rows[i][k + 1], rows[i + 1][k + 1], rows[i + 1][k]]:
				st.set_normal(v[1])
				st.set_uv(v[2])
				st.add_vertex(v[0])
	var streak := FastNoiseLite.new()
	streak.seed = 7311
	streak.frequency = 0.08
	streak.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.seamless = true
	tex.noise = streak
	tex.width = 256
	tex.height = 256
	var mat := ShaderMaterial.new()
	mat.shader = load("res://waterfall.gdshader")
	mat.set_shader_parameter("streak_noise", tex)
	mat.set_shader_parameter("opacity", 0.85)
	mat.set_shader_parameter("strand_count", 3.0)
	mat.set_shader_parameter("fall_speed", 1.1)
	mat.set_shader_parameter("body_color", Color(0.48, 0.66, 0.62))
	var mi := MeshInstance3D.new()
	mi.name = "WheelFallWater"
	mi.mesh = _save_res(st.commit(), "wheel_fall")
	mi.material_override = _save_res(mat, "wheel_fall_material")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(mi)


# ======================================================================================
#  Dressing
# ======================================================================================

func _build_dressing(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_base + 77
	var fin: float = _finish_s()
	crowd_yukata = 0.22
	_sv0 = _closest_s(Vector2(500.0, 125.0))
	_sv1 = _closest_s(Vector2(-372.0, 125.0))
	# The crowd: behind barriers on the river side's verge, and on the sidewalk along the houses.
	_build_start_crowd(root, fin - 95.0, fin + 85.0, road_half + 3.0, fin - 8.0, fin + 8.0, seed_base + 11, [1.0])
	_build_start_crowd(root, fin - 95.0, fin + 85.0, road_half + 0.45, fin - 8.0, fin + 8.0, seed_base + 12, [-1.0])
	# The flag on the river side (the poles and their wires are on the houses' side).
	_logo_flag(root, fin - 24.0, road_half + 17.0)
	_build_village(root, rng, fin)
	_build_bridge(root)
	_build_rafts(root, rng)
	_build_yard(root, rng)
	_build_forest_road(root, rng)
	_build_slide(root)
	_build_ford(root, rng)
	_build_koinobori(rng)
	_auto_guardrails(root, lap, 0.0, lap.length, 2.8, [[s_chute0 - 10.0, s_chute1 + 10.0], [s_south - 80.0, s_south + 20.0]])
	var pg := Node3D.new()
	pg.name = "PetalGusts"
	pg.set_script(load("res://PetalGusts.gd"))
	pg.set("falling", 170)
	root.add_child(pg)


## The village's sidewalk top at s, `lat` (negative: the houses' side) across it: KERB over the road at the kerb, falling
## toward the road 1 in 100.
func _side_top(s: float, lat: float) -> float:
	return lap.y(s) + KERB + (absf(lat) - road_half) * 0.01


## Things on the sidewalk stand on it.
func _stand_y(x: float, z: float) -> float:
	var g: float = _ground_at(x, z)
	if _sv0 < 0.0 or x > 520.0 or x < -392.0 or z < 80.0 or z > 175.0:
		return g
	var s: float = lap.closest_s(Vector2(x, z))
	if s < _sv0 or s > _sv1:
		return g
	var lat: float = (Vector3(x, 0.0, z) - lap.pt(s)).dot(lap.rt(s))
	if lat <= -road_half + 0.05 and lat >= -(road_half + SIDE_W) - 0.05:
		return maxf(g, _side_top(s, lat))
	return g


## The riverside village along the start straight (after the user's picture of a Japanese town): a granite sidewalk
## along the houses' side with street lamps, potted pines and bicycles; the machiya in one row along it, alleys to a back
## lane and a second row behind; on the river side a hedge, a cherry avenue and a stone-paved promenade along the river
## with lamps and benches, and the park: the garden stream under the vermilion drum bridge, paths, plazas, the tea house.
func _build_village(root: Node3D, rng: RandomNumberGenerator, fin: float) -> void:
	_build_sidewalk(root)
	var paving := SurfaceTool.new()
	paving.begin(Mesh.PRIMITIVE_TRIANGLES)
	var alleys: Array = _build_house_rows(rng, fin)
	_build_street_furniture(rng, fin, alleys)
	# The back lane and the alleys onto it.
	var lane_s0: float = _sv0 + 30.0
	var lane_s1: float = _sv1 - 30.0
	_pave_offset(paving, lane_s0, lane_s1, -LANE_LAT, LANE_W * 0.5)
	for al in alleys:
		var c0: Vector3 = lap.spot(float(al), -(road_half + SIDE_W - 0.3), 0.0)["pos"]
		var c1: Vector3 = lap.spot(float(al), -(LANE_LAT - LANE_W * 0.5 + 0.3), 0.0)["pos"]
		_pave_line(paving, [Vector2(c0.x, c0.z), Vector2(c1.x, c1.z)], 1.9)
	# The river side.
	var cross_s: float = _promenade_and_avenue(paving, rng, fin)
	_build_park(root, paving, rng, cross_s)
	_build_fair(rng, fin)
	_build_picnics(rng)
	_build_koi(root, rng)
	var mesh: ArrayMesh = paving.commit()
	if mesh.get_surface_count() > 0:
		mesh.surface_set_material(0, _road_mat)
		var mi := MeshInstance3D.new()
		# "Ground": DressingColliders gives it no collider (the ground under it is solid).
		mi.name = "VillagePavingGround"
		mi.mesh = _save_res(mesh, "village_paving")
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	# Utility poles along the sidewalk's kerb, with their wires.
	var prev := Vector3.INF
	var s: float = _sv0 + 30.0
	var k := 0
	while s < _sv1:
		var px: Transform3D = _beside(lap, s, -(road_half + 1.2))
		_put(_cell_key("poles", px.origin), prop_kit, px, "utility_pole", [9.5, k % 3], 500.0)
		var top: Vector3 = px.origin + Vector3(0, 9.0 * PROP_SCALE, 0)
		if prev != Vector3.INF:
			_put_world("poles", top, prop_kit, "pole_wires", [_life(prev), _life(top), 0.7, 3], 500.0)
		prev = top
		s += 46.0
		k += 1
	# Boats on the shingle and moored in the pool below the village.
	for i in range(6):
		var x: float = lerpf(-150.0, 380.0, float(i) / 5.0) + rng.randf_range(-20.0, 20.0)
		var z: float = _river_z(x) + _river_half(x) - (3.0 if i % 2 == 0 else -1.5)
		var at := Vector3(x, _water_y(x) if i % 2 == 0 else _ground_at(x, z) + 0.15, z)
		var bxf := Transform3D(Basis(Vector3.UP, rng.randf_range(1.2, 1.9)), at)
		_put(_cell_key("boats", at), river_kit, bxf, "river_boat", [i % 3], 600.0)
	_build_hill_pagoda(rng)


## The sidewalk: granite flags (the road shader's paving, kind 1, its kerb stones along both edges) from the road's edge
## SIDE_W out, KERB over the road, a kerb face down into the road's gutter and an edge down into the ground; solid
## ("SidewalkStones": off the course, paved under the tyres).
func _build_sidewalk(root: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var hw: float = SIDE_W * 0.5
	var lats: Array = [-(road_half + 0.02), -(road_half + SIDE_W * 0.33), -(road_half + SIDE_W * 0.67), -(road_half + SIDE_W)]
	var s0: float = _sv0 + 2.0
	var s1: float = _sv1 - 2.0
	var n: int = int(ceil((s1 - s0) / 2.0))
	var rows: Array = []
	for i in range(n + 1):
		var s: float = lerpf(s0, s1, float(i) / float(n))
		var row: Array = []
		for lat in lats:
			var p: Vector3 = lap.spot(s, float(lat), 0.0)["pos"]
			p.y = _side_top(s, float(lat))
			row.append(p)
		# The kerb's foot in the gutter, the outer edge's foot in the ground.
		var kf: Vector3 = lap.spot(s, -(road_half + 0.02), 0.0)["pos"]
		kf.y = lap.y(s) - 0.04
		var of: Vector3 = row[row.size() - 1]
		of.y = minf(_ground_at(of.x, of.z), of.y) - 0.25
		rows.append([row, kf, of, s])
	var put := func(a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, solid: bool) -> void:
		var tri: Array = [[a, ua], [b, ub], [c, uc]]
		var nrm: Vector3 = (c - a).cross(b - a)
		if nrm.length_squared() < 1e-10:
			return
		for v in tri:
			st.set_normal(Vector3.UP)
			st.set_color(Color(1.0, _petals_at((v[0] as Vector3).x, (v[0] as Vector3).z) * 0.6, 0.0, 1.0))
			st.set_uv(v[1])
			st.set_uv2(Vector2(1.0, hw))
			st.add_vertex(v[0])
		if solid:
			faces.append_array(PackedVector3Array([a, b, c]))
	for i in range(n):
		var r0: Array = rows[i]
		var r1: Array = rows[i + 1]
		var sa: float = r0[3]
		var sb: float = r1[3]
		for j in range(lats.size() - 1):
			var a0: Vector3 = r0[0][j]
			var a1: Vector3 = r0[0][j + 1]
			var b0: Vector3 = r1[0][j]
			var b1: Vector3 = r1[0][j + 1]
			var ua0 := Vector2(float(lats[j]) + road_half + hw, sa)
			var ua1 := Vector2(float(lats[j + 1]) + road_half + hw, sa)
			var ub0 := Vector2(float(lats[j]) + road_half + hw, sb)
			var ub1 := Vector2(float(lats[j + 1]) + road_half + hw, sb)
			# Clockwise from above: (c - a) x (b - a) points up.
			for t in [[a0, a1, b0, ua0, ua1, ub0], [a1, b1, b0, ua1, ub1, ub0]]:
				var ta: Vector3 = t[0]
				var tb: Vector3 = t[1]
				var tc: Vector3 = t[2]
				if (tc - ta).cross(tb - ta).y < 0.0:
					put.call(ta, tc, tb, t[3], t[5], t[4], true)
				else:
					put.call(ta, tb, tc, t[3], t[4], t[5], true)
		# The kerb's face toward the road, the outer edge's face toward the houses.
		var faces_q: Array = [[r0[0][0], r1[0][0], r1[1], r0[1], -lap.rt(sa)], [r0[0][lats.size() - 1], r1[0][lats.size() - 1], r1[2], r0[2], lap.rt(sa)]]
		for fq in faces_q:
			var q0: Vector3 = fq[0]
			var q1: Vector3 = fq[1]
			var q2: Vector3 = fq[2]
			var q3: Vector3 = fq[3]
			var out: Vector3 = fq[4]
			var uvq := [Vector2(-hw, sa), Vector2(-hw, sb), Vector2(-hw + 0.2, sb), Vector2(-hw + 0.2, sa)]
			var sol: bool = out.dot(lap.rt(sa)) > 0.0
			for t2 in [[q0, q1, q2, 0, 1, 2], [q0, q2, q3, 0, 2, 3]]:
				var ta2: Vector3 = t2[0]
				var tb2: Vector3 = t2[1]
				var tc2: Vector3 = t2[2]
				if (tc2 - ta2).cross(tb2 - ta2).dot(-out) < 0.0:
					put.call(ta2, tc2, tb2, uvq[t2[3]], uvq[t2[5]], uvq[t2[4]], sol)
				else:
					put.call(ta2, tb2, tc2, uvq[t2[3]], uvq[t2[4]], uvq[t2[5]], sol)
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, _road_mat)
	var body := StaticBody3D.new()
	body.name = "SidewalkStones"
	body.set_meta(&"surface", "asphalt")
	root.add_child(body)
	var mi := MeshInstance3D.new()
	mi.name = "SidewalkPaving"
	mi.mesh = _save_res(mesh, "sidewalk")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var cs := CollisionShape3D.new()
	cs.shape = _save_res(shape, "sidewalk_shape")
	body.add_child(cs)
	print("  the sidewalk: %.0fm, %d triangles" % [s1 - s0, faces.size() / 3])


## The machiya along the sidewalk, one row nearly wall to wall, alleys every five to seven houses; the back lane's second
## row of houses, storehouses and farmhouses with gardens between. Returns the alleys' s.
func _build_house_rows(rng: RandomNumberGenerator, fin: float) -> Array:
	var alleys: Array = []
	var s: float = _sv0 + 6.0
	var k := 0
	var since := 0
	var front: float = road_half + SIDE_W + 0.25
	while s < _sv1 - 8.0:
		if since >= 5 + k % 3 and absf(s - fin) > 30.0:
			alleys.append(s + 2.9)
			_note_rect(_xz(lap.spot(s + 2.9, -(front + 8.0), 0.0)["pos"]), 5.8, 16.0, _yaw_at(s), 0.0)
			s += 5.8
			since = 0
			continue
		var variant: int = [0, 1, 0, 3, 2, 0, 4, 1, 5, 0, 2, 1][k % 12]
		var def: Vector3 = _kit_value(town_kit, "machiya_default", [variant], Vector3(7.2, 9.0, 2.0))
		var w: float = def.x * PROP_SCALE
		var ext: float = float(_kit_value(town_kit, "machiya_extent", [variant], 1.5)) * PROP_SCALE
		if absf(s + w * 0.5 - fin) > 16.0 and rng.randf() < 0.96:
			var push: float = maxf(0.0, ext - 2.7)
			var sp: Dictionary = lap.spot(s, -(front + push), 0.0)
			var pos: Vector3 = sp["pos"]
			var xf: Transform3D = _facing(sp["right"], pos)
			var back: Vector3 = xf * Vector3(w * 0.5, 0.0, -def.y * PROP_SCALE * 0.5)
			var gr: Vector2 = _ground_range(Vector2(back.x, back.z), w, def.y * PROP_SCALE, _yaw_at(s))
			pos.y = maxf(_side_top(s + w * 0.5, -(road_half + SIDE_W)), gr.y - 0.3)
			xf.origin = pos
			if _put(_cell_key("village", pos), town_kit, xf, "machiya", [def.x, def.y, int(def.z), variant, rng, LBL], 1100.0):
				_note_frame(xf, Vector2(-0.3, -def.y - 0.3), Vector2(def.x + 0.3, 0.6), 0.5)
		s += w + rng.randf_range(0.25, 0.9)
		k += 1
		since += 1
	# The second row, across the back lane, facing it.
	var s2: float = _sv0 + 40.0
	var k2 := 0
	var front2: float = LANE_LAT + LANE_W * 0.5 + 0.8
	while s2 < _sv1 - 40.0:
		var pick: float = rng.randf()
		var sp2: Dictionary
		if pick < 0.22:
			# A thatched farmhouse in its yard.
			var kw := 12.0
			var kd := 7.5
			sp2 = lap.spot(s2, -(front2 + 3.0), 0.0)
			var kxf: Transform3D = _facing(sp2["right"], sp2["pos"])
			var kc: Vector3 = kxf * Vector3(kw * PROP_SCALE * 0.5, 0.0, -kd * PROP_SCALE * 0.5)
			kxf.origin.y = _ground_range(Vector2(kc.x, kc.z), kw * PROP_SCALE, kd * PROP_SCALE, _yaw_at(s2)).x
			if not _occupied(kc.x, kc.z) and _put(_cell_key("village2", kxf.origin), town_kit, kxf, "kominka", [kw, kd, rng], 800.0):
				_note_frame(kxf, Vector2(-1.5, -kd - 1.5), Vector2(kw + 1.5, 1.5), 0.5)
			s2 += kw * PROP_SCALE + rng.randf_range(4.0, 9.0)
		elif pick < 0.82:
			var v2: int = [0, 5, 1, 0, 3, 5, 2][k2 % 7]
			var d2: Vector3 = _kit_value(town_kit, "machiya_default", [v2], Vector3(7.2, 9.0, 2.0))
			var w2: float = d2.x * PROP_SCALE
			sp2 = lap.spot(s2, -front2, 0.0)
			var mxf: Transform3D = _facing(sp2["right"], sp2["pos"])
			var mc: Vector3 = mxf * Vector3(w2 * 0.5, 0.0, -d2.y * PROP_SCALE * 0.5)
			mxf.origin.y = _ground_range(Vector2(mc.x, mc.z), w2, d2.y * PROP_SCALE, _yaw_at(s2)).x + 0.05
			if not _occupied(mc.x, mc.z) and _put(_cell_key("village2", mxf.origin), town_kit, mxf, "machiya", [d2.x, d2.y, int(d2.z), v2, rng, LBL], 800.0):
				_note_frame(mxf, Vector2(-0.3, -d2.y - 0.3), Vector2(d2.x + 0.3, 0.6), 0.5)
			s2 += w2 + rng.randf_range(0.4, 3.0)
			k2 += 1
		else:
			# A garden: a pine and a maple behind a bamboo fence along the lane.
			var gw: float = rng.randf_range(10.0, 16.0)
			var fa: Vector3 = lap.spot(s2, -(front2 + 0.3), 0.0)["pos"]
			var fb: Vector3 = lap.spot(s2 + gw, -(front2 + 0.3), 0.0)["pos"]
			fa.y = _ground_at(fa.x, fa.z)
			fb.y = _ground_at(fb.x, fb.z)
			_put_world("village2", fa, prop_kit, "bamboo_fence", [_life(fa), _life(fb), 1.3], 600.0)
			var t1: Vector3 = lap.spot(s2 + gw * 0.3, -(front2 + 6.0), 0.0)["pos"]
			var t2: Vector3 = lap.spot(s2 + gw * 0.72, -(front2 + 9.0), 0.0)["pos"]
			extra_trees.append(["matsu", t1.x, t1.z, rng.randf_range(0.8, 1.0), k2 % 2])
			extra_trees.append(["momiji_red" if rng.randf() < 0.4 else "momiji", t2.x, t2.z, rng.randf_range(0.8, 1.0)])
			_note_circle(Vector2(t1.x, t1.z), 4.0)
			_note_circle(Vector2(t2.x, t2.z), 4.0)
			s2 += gw
	print("  the village: %d alleys" % alleys.size())
	return alleys


## Where someone sits on a park_bench placed at `xf` (the top of its seat), `along` metres (life) along it.
func _bench_seat(xf: Transform3D, along: float) -> Vector3:
	return xf.origin + xf.basis.x.normalized() * along * PROP_SCALE + xf.basis.z.normalized() * (-0.05 * PROP_SCALE) + Vector3(0, 0.47 * PROP_SCALE, 0)


func _xz(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)


## The lap's heading at s as the yaw _note_rect and _ground_range take (x along the road).
func _yaw_at(s: float) -> float:
	var f: Vector3 = lap.fw(s)
	return atan2(-f.z, f.x)


## The sidewalk's furniture: street lamps by the kerb, potted pines, maples and azaleas against the houses, bicycle racks
## with bicycles at the alleys' mouths, a drinks machine.
func _build_street_furniture(rng: RandomNumberGenerator, fin: float, alleys: Array) -> void:
	var poles: Array = []
	var ps: float = _sv0 + 30.0
	while ps < _sv1:
		poles.append(ps)
		ps += 46.0
	var near_pole := func(s: float, r: float) -> bool:
		for q in poles:
			if absf(float(q) - s) < r:
				return true
		return false
	var s: float = _sv0 + 14.0
	while s < _sv1 - 6.0:
		if not near_pole.call(s, 4.0) and absf(s - fin) > 10.0:
			var lx: Transform3D = _beside(lap, s, -(road_half + 0.8))
			_put(_cell_key("street", lx.origin), prop_kit, lx, "street_lantern", [4.2], 450.0)
			_note_circle(_xz(lx.origin), 1.0)
		s += 30.0
	# Pot plants against the houses' fronts.
	s = _sv0 + 10.0
	var k := 0
	while s < _sv1 - 6.0:
		var lat: float = -(road_half + SIDE_W - 0.55)
		var px: Transform3D = _beside(lap, s, lat)
		if rng.randf() < 0.55 and not _occupied(px.origin.x, px.origin.z):
			_put(_cell_key("street", px.origin), prop_kit, px, "planter", [k % 3, rng], 300.0)
			if rng.randf() < 0.5:
				var px2: Transform3D = _beside(lap, s + 1.1, lat)
				_put(_cell_key("street", px2.origin), prop_kit, px2, "planter", [(k + 1) % 3, rng], 300.0)
			k += 1
		s += rng.randf_range(6.0, 12.0)
	# Bicycles at the alleys' mouths: a rack along the kerb side of the sidewalk, bicycles in it and one leaning by a door.
	var cols: Array = [Color(0.70, 0.72, 0.74), Color(0.85, 0.85, 0.82), Color(0.15, 0.30, 0.55), Color(0.60, 0.12, 0.12), Color(0.16, 0.36, 0.22)]
	var m := 0
	for al in alleys:
		var a: float = float(al)
		# Not where the crowd stands on race day.
		var rx: Transform3D = _beside(lap, a, -(road_half + 2.6))
		if absf(a - fin) > 90.0 and not near_pole.call(a, 3.0):
			_put(_cell_key("street", rx.origin), prop_kit, rx, "bike_rack", [4], 300.0)
			for b in range(3):
				if rng.randf() < 0.25:
					continue
				# Each in a hoop, across the sidewalk, its basket toward the road.
				var bx := Transform3D(rx.basis * Basis(Vector3.UP, -PI * 0.5), rx.origin + rx.basis.x.normalized() * (-1.05 + 0.7 * float(b)) * PROP_SCALE)
				_put(_cell_key("street", bx.origin), prop_kit, bx, "bicycle", [cols[(m + b) % cols.size()]], 300.0)
			_note_circle(_xz(rx.origin), 3.0)
		# A drinks machine on the alley's corner, against the next house.
		if m % 2 == 0:
			var vx: Transform3D = _beside(lap, a + 4.0, -(road_half + SIDE_W - 0.8))
			if not _occupied(vx.origin.x, vx.origin.z):
				_put(_cell_key("street", vx.origin), prop_kit, vx, "vending_machine", [m % 3], 300.0)
				_note_circle(_xz(vx.origin), 1.2)
		m += 1


## A ribbon of the road shader's stone paving (kind 1) laid on the ground along the lap at `lat` (right of its line),
## `hw` either side, from s0 to s1, into `st`.
func _pave_offset(st: SurfaceTool, s0: float, s1: float, lat: float, hw: float) -> void:
	var pts: Array = []
	var s: float = s0
	while s < s1:
		pts.append(_xz(lap.spot(s, lat, 0.0)["pos"]))
		s += 3.0
	pts.append(_xz(lap.spot(s1, lat, 0.0)["pos"]))
	_pave_line(st, pts, hw)


## A ribbon of stone paving along the plan points `pts`, `hw` either side, draped on the ground 5cm over it.
func _pave_line(st: SurfaceTool, pts: Array, hw: float) -> void:
	var line: Array = []
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var m: int = maxi(1, int(ceil(a.distance_to(b) / 1.5)))
		for k in range(m):
			line.append(a.lerp(b, float(k) / float(m)))
	line.append(pts[pts.size() - 1])
	var cols: Array = [-1.0, -0.5, 0.0, 0.5, 1.0]
	var rows: Array = []
	var dist := 0.0
	for i in range(line.size()):
		var pa: Vector2 = line[maxi(i - 1, 0)]
		var pb: Vector2 = line[mini(i + 1, line.size() - 1)]
		var dir: Vector2 = (pb - pa).normalized()
		var right := Vector2(-dir.y, dir.x)
		if i > 0:
			dist += (line[i] as Vector2).distance_to(line[i - 1])
		var row: Array = []
		for c in cols:
			var q: Vector2 = (line[i] as Vector2) + right * float(c) * hw
			row.append([Vector3(q.x, _ground_at(q.x, q.y) + 0.05, q.y), Vector2(float(c) * hw, dist)])
		rows.append(row)
	for i in range(rows.size() - 1):
		for j in range(cols.size() - 1):
			_pave_tri(st, rows[i][j], rows[i][j + 1], rows[i + 1][j], hw)
			_pave_tri(st, rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j], hw)


## A disc of stone paving (a plaza) on the ground at `c`, radius `r`: flags in courses across it, no kerb band.
func _pave_disc(st: SurfaceTool, c: Vector2, r: float) -> void:
	var rings: int = maxi(2, int(ceil(r / 1.5)))
	var segs := 28
	var vtx := func(ri: int, si: int) -> Array:
		var rr: float = r * float(ri) / float(rings)
		var a: float = TAU * float(si) / float(segs)
		var q: Vector2 = c + Vector2(cos(a), sin(a)) * rr
		return [Vector3(q.x, _ground_at(q.x, q.y) + 0.06, q.y), q - c]
	for ri in range(rings):
		for si in range(segs):
			var a0: Array = vtx.call(ri, si)
			var a1: Array = vtx.call(ri, si + 1)
			var b0: Array = vtx.call(ri + 1, si)
			var b1: Array = vtx.call(ri + 1, si + 1)
			if ri > 0:
				_pave_tri(st, a0, a1, b0, 99.0)
			_pave_tri(st, a1, b1, b0, 99.0)


func _pave_tri(st: SurfaceTool, a: Array, b: Array, c: Array, hw: float) -> void:
	var order: Array = [a, b, c]
	if ((c[0] as Vector3) - (a[0] as Vector3)).cross((b[0] as Vector3) - (a[0] as Vector3)).y < 0.0:
		order = [a, c, b]
	for v in order:
		var p: Vector3 = v[0]
		st.set_normal(Vector3.UP)
		st.set_color(Color(1.0, _petals_at(p.x, p.z) * 0.7, 0.0, 1.0))
		st.set_uv(v[1])
		st.set_uv2(Vector2(1.0, hw))
		st.add_vertex(p)


## The river side of the street: a hedge of azaleas along the verge, the cherry avenue, the promenade (stone paving PROM_W
## wide, the drum bridge where the garden stream crosses it) with lamps and benches, a second row of cherries outside
## the park. Returns the s where the stream crosses the promenade.
func _promenade_and_avenue(paving: SurfaceTool, rng: RandomNumberGenerator, fin: float) -> float:
	var p0: float = _sv0 + 14.0
	var p1: float = _closest_s(Vector2(-250.0, 118.0))
	# Where the garden stream crosses the promenade's line.
	var cross_s := -1.0
	for i in range(GARDEN_STREAM.size() - 1):
		var a: Vector2 = GARDEN_STREAM[i]
		var b: Vector2 = GARDEN_STREAM[i + 1]
		for k in range(20):
			var q: Vector2 = a.lerp(b, float(k) / 20.0)
			var sq: float = lap.closest_s(q)
			var lat: float = (Vector3(q.x, 0.0, q.y) - lap.pt(sq)).dot(lap.rt(sq))
			if absf(lat - PROM_LAT) < 0.6 and cross_s < 0.0:
				cross_s = sq
	var gap: float = 7.6
	if cross_s > 0.0:
		_pave_offset(paving, p0, cross_s - gap, PROM_LAT, PROM_W * 0.5)
		_pave_offset(paving, cross_s + gap, p1, PROM_LAT, PROM_W * 0.5)
		# The drum bridge carrying the promenade over the stream.
		var bc: Vector3 = lap.spot(cross_s, PROM_LAT, 0.0)["pos"]
		var f: Vector3 = lap.fw(cross_s)
		var ga: Vector3 = lap.spot(cross_s - gap, PROM_LAT, 0.0)["pos"]
		var gb: Vector3 = lap.spot(cross_s + gap, PROM_LAT, 0.0)["pos"]
		bc.y = maxf(_ground_at(ga.x, ga.z), _ground_at(gb.x, gb.z)) - 0.05
		var bxf := Transform3D(Basis(f, Vector3.UP, f.cross(Vector3.UP).normalized()), bc)
		_put("drum_bridge", prop_kit, bxf, "arched_bridge", [9.4, 3.0, 1.7], 900.0)
		_note_rect(_xz(bc), 16.0, 6.0, _yaw_at(cross_s), 1.0)
		print("  the drum bridge: the promenade over the garden stream at %.0fm" % cross_s)
	else:
		_pave_offset(paving, p0, p1, PROM_LAT, PROM_W * 0.5)
	var s: float = p0
	while s < p1:
		_note_rect(_xz(lap.spot(s, PROM_LAT, 0.0)["pos"]), 10.0, PROM_W + 1.0, _yaw_at(s), 0.0)
		s += 8.0
	var far_from := func(sq: float, r: float) -> bool:
		return cross_s < 0.0 or absf(sq - cross_s) > r
	var pool := Vector2(GARDEN_POOL.x, GARDEN_POOL.y)
	# The hedge along the verge (not where the crowd stands on race day).
	s = p0
	while s < p1:
		var hp: Vector3 = lap.spot(s, road_half + 2.4, 0.0)["pos"]
		if (s < fin - 98.0 or s > fin + 88.0) and _xz(hp).distance_to(pool) > GARDEN_POOL.z + 3.0 and far_from.call(s, 9.0) and _run_d(hp.x, hp.z) > PARK_RUN_CLEAR:
			extra_trees.append(["tsutsuji", hp.x, hp.z, rng.randf_range(0.7, 0.85), 0 if rng.randf() < 0.5 else 1])
		s += 2.4
	# The cherry avenue between the verge and the promenade, and lamps between the trees.
	s = p0 + 4.0
	var k := 0
	while s < p1:
		var cp: Vector3 = lap.spot(s, road_half + 6.0, 0.0)["pos"]
		if absf(s - fin) > 12.0 and _shore_d(cp.x, cp.z) > 5.0 and _xz(cp).distance_to(pool) > GARDEN_POOL.z + 5.0 and far_from.call(s, 11.0) and _run_d(cp.x, cp.z) > PARK_RUN_CLEAR + 2.0:
			extra_trees.append(["sakura", cp.x, cp.z, rng.randf_range(0.95, 1.15), k % 2])
			_note_circle(_xz(cp), 2.0)
		var lx: Transform3D = _beside(lap, s, PROM_LAT - PROM_W * 0.5 - 0.7)
		if k % 2 == 1 and far_from.call(s, 10.0) and _run_d(lx.origin.x, lx.origin.z) > PARK_RUN_CLEAR:
			_put(_cell_key("riverside", lx.origin), prop_kit, lx, "street_lantern", [4.2], 450.0)
			_note_circle(_xz(lx.origin), 1.0)
		# Benches on the promenade's river side, looking at the water.
		if k % 3 == 1 and far_from.call(s, 12.0) and (s < fin + FAIR.x - 6.0 or s > fin + FAIR.y + 6.0):
			var bx: Transform3D = _beside(lap, s + 4.0, PROM_LAT + PROM_W * 0.5 + 0.9)
			bx = Transform3D(Basis(Vector3.UP, PI) * bx.basis, bx.origin)
			if _shore_d(bx.origin.x, bx.origin.z) > 6.0 and not _occupied(bx.origin.x, bx.origin.z) and _run_d(bx.origin.x, bx.origin.z) > PARK_RUN_CLEAR:
				_put(_cell_key("riverside", bx.origin), prop_kit, bx, "park_bench", [], 420.0)
				_note_circle(_xz(bx.origin), 2.5)
				if rng.randf() < 0.6:
					_person(_bench_seat(bx, rng.randf_range(-0.6, 0.6)), bx.basis.z, rng.randf_range(0.88, 1.05), true)
		# A second row of cherries past the promenade, outside the park.
		if k % 2 == 0:
			var cp2: Vector3 = lap.spot(s + 6.0, PROM_LAT + PROM_W * 0.5 + 5.0, 0.0)["pos"]
			if not _in_park(cp2.x, cp2.z) and _shore_d(cp2.x, cp2.z) > 6.0 and not _occupied(cp2.x, cp2.z) and _run_d(cp2.x, cp2.z) > PARK_RUN_CLEAR + 2.0 \
					and (s < fin + FAIR.x - 8.0 or s > fin + FAIR.y + 8.0):
				extra_trees.append(["yamazakura" if k % 4 == 0 else "sakura", cp2.x, cp2.z, rng.randf_range(0.9, 1.15), k % 2])
				_note_circle(_xz(cp2), 3.0)
		s += 16.0
		k += 1
	for ds in [-60.0, -30.0, 30.0, 60.0]:
		var nx: Transform3D = _beside(lap, fin + ds, road_half + 4.5)
		_put(_cell_key("riverside", nx.origin), prop_kit, nx, "nobori", [Color(0.20, 0.30, 0.55)], 420.0)
	# People strolling on the promenade.
	s = p0 + 8.0
	while s < p1:
		if rng.randf() < 0.45 and far_from.call(s, 9.0):
			var wp: Vector3 = lap.spot(s, PROM_LAT + rng.randf_range(-1.4, 1.4), 0.0)["pos"]
			wp.y = _ground_at(wp.x, wp.z)
			var face: Vector3 = lap.fw(s) * (1.0 if rng.randf() < 0.5 else -1.0)
			_person(wp, face, rng.randf_range(0.88, 1.05), false, -1, rng.randf() < 0.35)
		s += rng.randf_range(14.0, 30.0)
	return cross_s


## The riverside park (after the user's picture): stone paths and two plazas, the garden stream with rocks and purple
## irises along it, a second little drum bridge where a path crosses it, the tea house on its west bank, benches and
## lanterns, weeping cherries, cherries, maples, a pine, azalea hedges along the paths.
func _build_park(root: Node3D, paving: SurfaceTool, rng: RandomNumberGenerator, cross_s: float) -> void:
	for path in PARK_PATHS:
		_pave_line(paving, path, PARK_PATH_HALF)
	for pz in PARK_PLAZAS:
		_pave_disc(paving, pz[0], float(pz[1]))
	var near_path := func(q: Vector2, r: float) -> bool:
		for path in PARK_PATHS:
			for i in range((path as Array).size() - 1):
				var a: Vector2 = path[i]
				var b: Vector2 = path[i + 1]
				var t: float = clampf((q - a).dot(b - a) / maxf((b - a).length_squared(), 1e-4), 0.0, 1.0)
				if q.distance_to(a.lerp(b, t)) < r + PARK_PATH_HALF:
					return true
		for pz in PARK_PLAZAS:
			if q.distance_to(pz[0]) < float(pz[1]) + r:
				return true
		return false
	# The path's own little drum bridge over the stream.
	var path1: Array = PARK_PATHS[1]
	var b2: Vector2 = path1[2]
	var bd: Vector2 = ((path1[3] as Vector2) - (path1[1] as Vector2)).normalized()
	var bf := Vector3(bd.x, 0.0, bd.y)
	var b2y: float = maxf(_ground_at(b2.x - bd.x * 5.5, b2.y - bd.y * 5.5), _ground_at(b2.x + bd.x * 5.5, b2.y + bd.y * 5.5)) - 0.05
	# Wide and low enough for the park run's carts to cross: 7.5 x 3.4 (life), 0.7 high.
	_park_bridge = Transform3D(Basis(bf, Vector3.UP, bf.cross(Vector3.UP).normalized()), Vector3(b2.x, b2y, b2.y))
	_put("park_bridge", prop_kit, _park_bridge, "arched_bridge", [PARK_BRIDGE.x, PARK_BRIDGE.y, PARK_BRIDGE.z], 800.0)
	_note_circle(b2, 6.0)
	# The tea house facing east across the stream, its bench and parasol toward the water.
	var tf := Vector3(1.0, 0.0, 0.0)
	var tx: Transform3D = _facing(tf, Vector3.ZERO)
	var torg: Vector3 = Vector3(TEA_HOUSE.x, 0.0, TEA_HOUSE.y) - tx.basis.x.normalized() * 4.5 * PROP_SCALE + tf * 2.75 * PROP_SCALE
	torg.y = _ground_range(TEA_HOUSE, 9.0, 15.0, 0.0).x
	tx.origin = torg
	if _put("park_teahouse", town_kit, tx, "chaya", [LBL], 900.0):
		_note_frame(tx, Vector2(-1.2, -6.7), Vector2(10.2, 2.8), 1.0)
	# Benches round the weeping cherry's plaza, facing in; benches on the river plaza facing the water; lanterns.
	var c1: Vector2 = PARK_PLAZAS[0][0]
	var r1: float = PARK_PLAZAS[0][1]
	extra_trees.append(["shidare", c1.x, c1.y, 1.25, 0])
	for k in range(4):
		var a: float = TAU * float(k) / 4.0 + 0.4
		var bp: Vector2 = c1 + Vector2(cos(a), sin(a)) * (r1 - 2.0)
		var bxf: Transform3D = _facing(Vector3(c1.x - bp.x, 0.0, c1.y - bp.y), Vector3(bp.x, _ground_at(bp.x, bp.y) + 0.06, bp.y))
		_put("park_furniture", prop_kit, bxf, "park_bench", [], 500.0)
		if rng.randf() < 0.6:
			_person(_bench_seat(bxf, rng.randf_range(-0.6, 0.6)), bxf.basis.z, rng.randf_range(0.88, 1.05), true)
		var la: float = a + PI * 0.25
		var lp: Vector2 = c1 + Vector2(cos(la), sin(la)) * (r1 + 1.4)
		_put("park_furniture", prop_kit, _facing(Vector3(c1.x - lp.x, 0.0, c1.y - lp.y), Vector3(lp.x, _ground_at(lp.x, lp.y), lp.y)), "stone_lantern", [k % 2, 2.0], 500.0)
	var c2: Vector2 = PARK_PLAZAS[1][0]
	var r2: float = PARK_PLAZAS[1][1]
	var to_river := Vector2(0.0, -1.0)
	for k in range(3):
		var bp2: Vector2 = c2 + to_river * (r2 - 2.2) + Vector2(1.0, 0.0) * (float(k) - 1.0) * 3.4
		var bx2: Transform3D = _facing(Vector3(0.0, 0.0, -1.0), Vector3(bp2.x, _ground_at(bp2.x, bp2.y) + 0.06, bp2.y))
		_put("park_furniture", prop_kit, bx2, "park_bench", [], 500.0)
		if rng.randf() < 0.7:
			_person(_bench_seat(bx2, rng.randf_range(-0.6, 0.6)), bx2.basis.z, rng.randf_range(0.88, 1.05), true)
	for sx in [-1.0, 1.0]:
		var lp2: Vector2 = c2 + Vector2(sx * (r2 + 1.2), 1.0)
		_put("park_furniture", prop_kit, Transform3D(Basis(), Vector3(lp2.x, _ground_at(lp2.x, lp2.y), lp2.y)), "stone_lantern", [1, 2.2], 500.0)
	extra_trees.append(["sakura", c2.x + 9.0, c2.y + 7.0, 1.2, 1])
	# Street lamps along the paths.
	for path in PARK_PATHS:
		var acc := 0.0
		for i in range((path as Array).size() - 1):
			var a: Vector2 = path[i]
			var b: Vector2 = path[i + 1]
			var l: float = a.distance_to(b)
			var d: Vector2 = (b - a) / maxf(l, 0.001)
			var t := 9.0 - fmod(acc, 18.0)
			while t < l:
				var q: Vector2 = a + d * t + Vector2(-d.y, d.x) * (PARK_PATH_HALF + 0.8)
				if not _occupied(q.x, q.y) and _race_d(q.x, q.y) > 2.0 and _run_d(q.x, q.y) > PARK_RUN_CLEAR:
					_put("park_furniture", prop_kit, _facing(Vector3(d.y, 0.0, -d.x), Vector3(q.x, _ground_at(q.x, q.y), q.y)), "street_lantern", [3.8], 500.0)
					_note_circle(q, 1.0)
				t += 18.0
			acc += l
	# Azaleas along both sides of the paths, in runs.
	for path in PARK_PATHS:
		for i in range((path as Array).size() - 1):
			var a: Vector2 = path[i]
			var b: Vector2 = path[i + 1]
			var l: float = a.distance_to(b)
			var d: Vector2 = (b - a) / maxf(l, 0.001)
			var t := 1.5
			while t < l - 1.0:
				for sd in [-1.0, 1.0]:
					var q: Vector2 = a + d * t + Vector2(-d.y, d.x) * sd * (PARK_PATH_HALF + 1.3)
					if fmod(t + sd * 7.0, 14.0) < 9.0 and not _occupied(q.x, q.y) and _race_d(q.x, q.y) > 1.2 and not near_path.call(q, 0.6) and _run_d(q.x, q.y) > PARK_RUN_CLEAR:
						extra_trees.append(["tsutsuji", q.x, q.y, rng.randf_range(0.6, 0.8), rng.randi_range(0, 1)])
				t += 2.4
	# Trees on the lawns, clear of the paths, the stream and the tea house.
	var lawn: Array = [Vector2(-100.0, 45.0), Vector2(-128.0, 40.0), Vector2(-140.0, 72.0), Vector2(-118.0, 82.0), Vector2(-175.0, 70.0), Vector2(-196.0, 80.0),
			Vector2(-160.0, 30.0), Vector2(-140.0, 18.0), Vector2(-110.0, 22.0), Vector2(-226.0, 40.0), Vector2(-228.0, 68.0), Vector2(-150.0, 92.0),
			Vector2(-92.0, 62.0), Vector2(-198.0, 24.0), Vector2(-122.0, 98.0)]
	var kinds: Array = ["sakura", "yamazakura", "sakura", "shidare", "momiji", "sakura", "matsu", "sakura", "yamazakura", "sakura", "momiji_red", "matsu", "sakura", "momiji", "sakura"]
	var planted := 0
	for i in range(lawn.size()):
		var q: Vector2 = lawn[i]
		if near_path.call(q, 4.0) or _race_d(q.x, q.y) < 3.5 or _occupied(q.x, q.y) or _shore_d(q.x, q.y) < 6.0 or _run_d(q.x, q.y) < PARK_RUN_CLEAR + 3.0:
			continue
		extra_trees.append([kinds[i], q.x, q.y, rng.randf_range(0.95, 1.15), i % 2])
		_note_circle(q, 3.0)
		planted += 1
	# The garden stream: rocks along its banks, purple irises in patches, two yukimi lanterns by the pool.
	var gpc: Dictionary = {}
	for pc in _race:
		if String(pc["name"]) == "garden":
			gpc = pc
	var iris_xfs: Array = []
	if not gpc.is_empty():
		var gp: PackedVector2Array = gpc["pts"]
		var lv: PackedFloat32Array = gpc["lv"]
		var hw: float = _race_half_water(gpc)
		for i in range(1, gp.size() - 1):
			var q: Vector2 = gp[i]
			if _shore_d(q.x, q.y) < 3.0:
				break
			var dir: Vector2 = (gp[i + 1] - gp[i - 1]).normalized()
			var right := Vector2(-dir.y, dir.x)
			if i % 4 == 0:
				var side: float = 1.0 if (i / 4) % 2 == 0 else -1.0
				var rq: Vector2 = q + right * side * (hw + rng.randf_range(0.1, 0.5))
				if not near_path.call(rq, 0.5) and not _occupied(rq.x, rq.y) and _run_d(rq.x, rq.y) > PARK_RUN_CLEAR:
					var rs: float = rng.randf_range(0.45, 0.85)
					_put(_cell_key("park_rocks", Vector3(rq.x, 0, rq.y)), prop_kit, Transform3D(Basis(), Vector3(rq.x, minf(_ground_at(rq.x, rq.y), lv[i] + 0.2), rq.y)), "garden_rock", [rs, rs * 0.7, i * 31 + 7], 400.0)
			for sd in [-1.0, 1.0]:
				if sin(float(i) * 0.45 + sd * 1.7) < -0.1:
					continue
				var iq: Vector2 = q + right * sd * (hw + rng.randf_range(0.2, 0.9))
				if near_path.call(iq, 0.3):
					continue
				var iy: float = _ground_at(iq.x, iq.y)
				iris_xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.3, 1.7)), Vector3(iq.x, iy - 0.05, iq.y)))
	var gpool := Vector2(GARDEN_POOL.x, GARDEN_POOL.y)
	for k in range(9):
		var a: float = TAU * float(k) / 9.0
		var iq2: Vector2 = gpool + Vector2(cos(a), sin(a)) * (GARDEN_POOL.z + 0.7)
		iris_xfs.append(Transform3D(Basis(Vector3.UP, a).scaled(Vector3.ONE * 1.5), Vector3(iq2.x, _ground_at(iq2.x, iq2.y) - 0.05, iq2.y)))
		if k % 3 == 1:
			var rq2: Vector2 = gpool + Vector2(cos(a + 0.35), sin(a + 0.35)) * (GARDEN_POOL.z + 0.4)
			_put(_cell_key("park_rocks", Vector3(rq2.x, 0, rq2.y)), prop_kit, Transform3D(Basis(), Vector3(rq2.x, _ground_at(rq2.x, rq2.y), rq2.y)), "garden_rock", [0.7, 0.5, k * 17 + 3], 400.0)
	var lq: Vector2 = gpool + Vector2(-GARDEN_POOL.z - 1.6, 1.0)
	_put("park_furniture", prop_kit, _facing(Vector3(1.0, 0.0, 0.0), Vector3(lq.x, _ground_at(lq.x, lq.y), lq.y)), "stone_lantern", [1, 1.9], 500.0)
	if not iris_xfs.is_empty():
		var reed := ShaderMaterial.new()
		reed.shader = load("res://dune_grass.gdshader")
		reed.set_shader_parameter("sway", 0.08)
		reed.set_shader_parameter("speed", 1.0)
		var PondKitS: Script = load("res://PondKit.gd")
		var imesh: ArrayMesh = PondKitS.iris(1, _save_res(reed, "iris_material"), Color(0.45, 0.28, 0.78))
		_multimesh(root, "ParkIrisGrass", _save_res(imesh, "park_iris"), iris_xfs, 260.0, false)
	print("  the park: %d trees on the lawns, %d iris clumps" % [planted, iris_xfs.size()])


## The cherry-blossom fair along the promenade past the finish: food stalls on its river side facing it (takoyaki,
## candied fruit, goldfish scooping, masks), bamboo poles either side with strings of paper lanterns across and along,
## people at the counters and strolling, most of them in yukata.
func _build_fair(rng: RandomNumberGenerator, fin: float) -> void:
	var s0: float = fin + FAIR.x
	var s1: float = fin + FAIR.y
	var s: float = s0
	var k := 0
	while s < s1 - 4.0:
		var xf: Transform3D = _beside(lap, s, PROM_LAT + PROM_W * 0.5 + 1.0)
		# The stall's frame runs x from 0: centre it on its spot.
		xf.origin -= xf.basis.x * 1.35 * PROP_SCALE
		if _put(_cell_key("fair", xf.origin), town_kit, xf, "yatai", [k % 4, rng, LBL], 450.0):
			_note_frame(xf, Vector2(-0.3, -2.2), Vector2(3.0, 0.4))
		for j in range(rng.randi_range(1, 3)):
			var at: Vector3 = xf * (Vector3(rng.randf_range(0.4, 2.3), 0.0, rng.randf_range(1.0, 1.9)) * PROP_SCALE)
			at.y = _ground_at(at.x, at.z)
			var kid: bool = rng.randf() < 0.2
			_person(at, -xf.basis.z + xf.basis.x * rng.randf_range(-0.3, 0.3), 0.62 if kid else rng.randf_range(0.88, 1.06), false, -1, rng.randf() < 0.6)
		s += 7.2
		k += 1
	# Poles either side of the promenade every 12m, lantern strings across each pair and along each side.
	var prev: Array = []
	s = s0 - 2.0
	var n := 0
	while s < s1 + 2.0:
		var tops: Array = []
		for lat in [PROM_LAT - PROM_W * 0.5 - 0.4, PROM_LAT + PROM_W * 0.5 + 0.3]:
			var px: Transform3D = _beside(lap, s + (3.6 if lat > PROM_LAT else 0.0), lat)
			_put(_cell_key("fair", px.origin), prop_kit, px, "festival_pole", [4.2], 450.0)
			_note_circle(_xz(px.origin), 0.8)
			tops.append(px.origin + Vector3(0, 4.15 * PROP_SCALE, 0))
		var cols: Array = [Color(0.92, 0.20, 0.12), Color(0.97, 0.93, 0.82), Color(1.0, 0.66, 0.72)]
		_put_world("fair_lanterns", tops[0], prop_kit, "chochin_string", [_life(tops[0]), _life(tops[1]), 5, 0.35, cols], 450.0)
		if not prev.is_empty():
			for side in range(2):
				_put_world("fair_lanterns", tops[side], prop_kit, "chochin_string", [_life(prev[side]), _life(tops[side]), 6, 0.5, cols], 450.0)
		prev = tops
		s += 12.0
		n += 1
	# Visitors strolling the fair.
	s = s0
	while s < s1:
		var lat2: float = PROM_LAT + rng.randf_range(-1.6, 1.6)
		var wp: Vector3 = lap.spot(s, lat2, 0.0)["pos"]
		wp.y = _ground_at(wp.x, wp.z)
		var kid2: bool = rng.randf() < 0.15
		_person(wp, lap.fw(s) * (1.0 if rng.randf() < 0.5 else -1.0) + lap.rt(s) * rng.randf_range(-0.4, 0.4), 0.62 if kid2 else rng.randf_range(0.88, 1.05), false, -1, rng.randf() < 0.65)
		s += rng.randf_range(2.5, 6.0)
	print("  the fair: %d stalls, %d pairs of lantern poles" % [k, n])


## Cherry-blossom picnics on the park's lawns: a tarp or a red felt carpet, people sitting round it (some in yukata),
## clear of the paths, the stream, the park run and the trees' trunks.
func _build_picnics(rng: RandomNumberGenerator) -> void:
	var spots: Array = [Vector2(-130.0, 44.0), Vector2(-150.0, 22.0), Vector2(-118.0, 30.0), Vector2(-228.0, 18.0), Vector2(-96.0, 40.0),
			Vector2(-176.0, 80.0), Vector2(-140.0, 84.0), Vector2(-230.0, 82.0)]
	var placed := 0
	for i in range(spots.size()):
		var q: Vector2 = spots[i]
		if _occupied(q.x, q.y) or _race_d(q.x, q.y) < 4.0 or _run_d(q.x, q.y) < PARK_RUN_CLEAR + 3.0 or _shore_d(q.x, q.y) < 8.0:
			continue
		var on_path := false
		for path in PARK_PATHS:
			for j in range((path as Array).size() - 1):
				var a: Vector2 = path[j]
				var b: Vector2 = path[j + 1]
				var t: float = clampf((q - a).dot(b - a) / maxf((b - a).length_squared(), 1e-4), 0.0, 1.0)
				if q.distance_to(a.lerp(b, t)) < PARK_PATH_HALF + 4.0:
					on_path = true
		if on_path:
			continue
		var yaw: float = rng.randf() * TAU
		var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(q.x, _ground_at(q.x, q.y), q.y))
		_put(_cell_key("park_picnic", xf.origin), prop_kit, xf, "hanami_set", [placed % 3, rng], 300.0)
		_note_rect(q, 7.0, 6.0, yaw, 1.0)
		for j in range(rng.randi_range(3, 5)):
			var ang: float = rng.randf() * TAU
			var rr: float = rng.randf_range(0.9, 1.5) * PROP_SCALE
			var at: Vector3 = xf.origin + Vector3(cos(ang) * rr, 0.06, sin(ang) * rr * 0.8)
			var seated: bool = rng.randf() < 0.75
			var kid: bool = rng.randf() < 0.2
			_person(at, xf.origin - at + Vector3(0.01, 0, 0), 0.62 if kid else rng.randf_range(0.88, 1.05), seated, -1, rng.randf() < 0.4)
		placed += 1
	print("  picnics: %d" % placed)


## Koi in the garden: five circling the spring pool, more holding station up the stream, noses to the current
## (KoiFish.gd, koi.gdshader).
func _build_koi(root: Node3D, rng: RandomNumberGenerator) -> void:
	var gpc: Dictionary = {}
	for pc in _race:
		if String(pc["name"]) == "garden":
			gpc = pc
	if gpc.is_empty():
		return
	var pool_y: float = 0.0
	for pd in _ponds:
		if absf(pd.x - GARDEN_POOL.x) < 0.1:
			pool_y = pd.y
	var kinds := PackedInt32Array()
	var a_pts := PackedVector3Array()
	var b_pts := PackedVector3Array()
	var speeds := PackedFloat32Array()
	var phases := PackedFloat32Array()
	var sizes := PackedFloat32Array()
	var custom: Array = []
	var pats: Array = [0, 1, 0, 2, 3, 0, 4, 2, 1, 0, 3, 0]
	for i in range(5):
		kinds.append(0)
		# Near the surface: deeper, the creek water's colour all but hid them.
		a_pts.append(Vector3(GARDEN_POOL.x, pool_y - 0.12 - 0.04 * float(i % 2), GARDEN_POOL.y))
		b_pts.append(Vector3(lerpf(0.9, 2.1, float(i) / 4.0), 0.0, 0.0))
		var sp: float = rng.randf_range(0.35, 0.7) * (1.0 if i % 2 == 0 else -1.0)
		speeds.append(sp)
		phases.append(rng.randf() * TAU)
		sizes.append(PROP_SCALE * rng.randf_range(0.85, 1.15))
		custom.append(Color(float(pats[i % pats.size()]), rng.randf(), rng.randf(), absf(sp)))
	var gp: PackedVector2Array = gpc["pts"]
	var lv: PackedFloat32Array = gpc["lv"]
	var i2 := 8
	var n := 0
	while i2 < gp.size() - 6:
		var q: Vector2 = gp[i2]
		if _shore_d(q.x, q.y) < 4.0:
			break
		var a: Vector2 = gp[i2 - 3]
		var b: Vector2 = gp[i2 + 3]
		kinds.append(1)
		a_pts.append(Vector3(a.x, lv[i2 - 3] - 0.13, a.y))
		b_pts.append(Vector3(b.x, lv[i2 + 3] - 0.13, b.y))
		speeds.append(rng.randf_range(0.15, 0.3))
		phases.append(rng.randf() * TAU)
		sizes.append(PROP_SCALE * rng.randf_range(0.8, 1.05))
		custom.append(Color(float(pats[(n + 5) % pats.size()]), rng.randf(), rng.randf(), rng.randf_range(0.5, 0.9)))
		i2 += rng.randi_range(12, 18)
		n += 1
	var mat := ShaderMaterial.new()
	mat.shader = load("res://koi.gdshader")
	var mesh: ArrayMesh = _koi_mesh()
	mesh.surface_set_material(0, _save_res(mat, "koi_material"))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _save_res(mesh, "koi")
	mm.instance_count = kinds.size()
	var node := MultiMeshInstance3D.new()
	node.name = "GardenKoi"
	node.set_script(load("res://KoiFish.gd"))
	node.set("kinds", kinds)
	node.set("a_pts", a_pts)
	node.set("b_pts", b_pts)
	node.set("speeds", speeds)
	node.set("phases", phases)
	node.set("sizes", sizes)
	node.set("centre", Vector3(-150.0, 2.0, 50.0))
	# Where they are at t = 0, written straight into the buffer (the dummy renderer ignores set_instance_transform).
	var buf := PackedFloat32Array()
	buf.resize(kinds.size() * 16)
	for i in range(kinds.size()):
		var t: Transform3D = node.call("pose_at", i, 0.0)
		var bs: Basis = t.basis
		var o: int = i * 16
		var row: Array = [bs.x.x, bs.y.x, bs.z.x, t.origin.x, bs.x.y, bs.y.y, bs.z.y, t.origin.y, bs.x.z, bs.y.z, bs.z.z, t.origin.z]
		for k in range(12):
			buf[o + k] = row[k]
		var c: Color = custom[i]
		buf[o + 12] = c.r
		buf[o + 13] = c.g
		buf[o + 14] = c.b
		buf[o + 15] = c.a
	mm.buffer = buf
	node.multimesh = mm
	node.visibility_range_end = 140.0
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# "water": DressingColliders leaves the fish soft.
	node.set_meta(&"skip_dressing_colliders", true)
	root.add_child(node)
	print("  koi: %d in the pool and the stream" % kinds.size())


## A koi at life size, its nose toward +z, 0.7 long: a body of revolution flattened at the sides, a vertical forked tail,
## a dorsal fin, two pectoral fins; UV.x along it (0 the nose, 1 the tail's tip), UV.y 1 on the fins.
func _koi_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z0 := 0.35
	var z1 := -0.22
	var stations := 10
	var segs := 10
	var rings: Array = []
	for i in range(stations + 1):
		var t: float = float(i) / float(stations)
		var z: float = lerpf(z0, z1, t)
		var prof: float = sin(PI * pow(clampf(t * 1.05, 0.0, 1.0), 0.6))
		var hw: float = 0.085 * prof + 0.008
		var hh: float = 0.07 * prof + 0.008
		var ring: Array = []
		for j in range(segs):
			var a: float = TAU * float(j) / float(segs)
			ring.append([Vector3(cos(a) * hw, sin(a) * hh - 0.01 * (1.0 - t), z), Vector3(cos(a) / hw, sin(a) / hh, 0.0).normalized(), (z0 - z) / (z0 + 0.55)])
		rings.append(ring)
	var put := func(v: Array, fin: float) -> void:
		st.set_normal(v[1])
		st.set_uv(Vector2(float(v[2]), fin))
		st.add_vertex(v[0])
	for i in range(stations):
		for j in range(segs):
			var j1: int = (j + 1) % segs
			for k in [rings[i][j], rings[i + 1][j], rings[i + 1][j1], rings[i][j], rings[i + 1][j1], rings[i][j1]]:
				put.call(k, 0.0)
	# The tail: a forked fan in the vertical plane, the dorsal fin along the back, two pectoral fins.
	var fins: Array = [
		[Vector3(0, 0, z1), Vector3(0, 0.13, -0.5), Vector3(0, 0.0, -0.4)], [Vector3(0, 0, z1), Vector3(0, 0.0, -0.4), Vector3(0, -0.13, -0.5)],
		[Vector3(0, 0.07, 0.12), Vector3(0, 0.14, 0.0), Vector3(0, 0.06, -0.12)],
		[Vector3(0.07, -0.03, 0.18), Vector3(0.17, -0.06, 0.08), Vector3(0.07, -0.04, 0.08)],
		[Vector3(-0.07, -0.03, 0.18), Vector3(-0.17, -0.06, 0.08), Vector3(-0.07, -0.04, 0.08)]]
	for f in fins:
		var n: Vector3 = ((f[2] as Vector3) - (f[0] as Vector3)).cross((f[1] as Vector3) - (f[0] as Vector3)).normalized()
		for v in f:
			var vv: Vector3 = v
			put.call([vv, n, (z0 - vv.z) / (z0 + 0.55)], 1.0)
	return st.commit()


## A three-storey pagoda on the hill behind the village, over the roofs from the start straight, with stone lanterns and
## maples round it in a clearing of the woods.
func _build_hill_pagoda(rng: RandomNumberGenerator) -> void:
	var c := Vector2(-30.0, 232.0)
	var at := Vector3(c.x, _ground_range(c, 16.0, 16.0, 0.0).x, c.y)
	var face: Vector3 = Vector3(0.0, 0.0, -1.0)
	if _put("hill_pagoda", town_kit, _facing(face, at), "pagoda", [3], 2500.0):
		_note_circle(c, 18.0)
		for sx in [-1.0, 1.0]:
			var lp := Vector3(c.x + sx * 7.0, 0.0, c.y - 12.0)
			lp.y = _ground_at(lp.x, lp.z)
			_put("hill_pagoda", prop_kit, _facing(face, lp), "stone_lantern", [0, 2.4], 900.0)
		for k in range(5):
			var a: float = PI * (0.15 + 0.7 * float(k) / 4.0)
			var tp: Vector2 = c + Vector2(cos(a), -sin(a)) * 15.0
			extra_trees.append(["momiji" if k % 2 == 0 else "yamazakura", tp.x, tp.y, rng.randf_range(0.95, 1.1)])


## The timber bridge with vermilion railings (the kit builds all but the deck), its railings solid.
func _build_bridge(root: Node3D) -> void:
	var o: Vector3 = lap.pt(s_bridge0)
	var fwd: Vector3 = lap.fw(s_bridge0)
	var xf := _facing(-fwd, o)
	var span: float = s_bridge1 - s_bridge0
	var deck := func(t: float) -> float: return lap.y(s_bridge0 + t) - o.y
	var ground := func(x: float, t: float) -> float:
		var p: Vector3 = lap.pt(s_bridge0 + t) + lap.rt(s_bridge0 + t) * -x
		return _ground_at(p.x, p.z) - o.y
	_add_prop_game("river_span", river_kit, xf, func(pk: PropKit, kit: Dictionary, _labels: Array) -> void:
		_kit_call(river_kit, "road_bridge", [pk, kit, span, road_half, deck, ground, 0]), 1500.0)
	var body: StaticBody3D = _body(root, "RiverRailsBody")
	for side in [-1.0, 1.0]:
		_edge_boxes(body, lap, s_bridge0 - 3.0, s_bridge1 + 3.0, side * (road_half + 0.3), 1.7, 0.4)
	print("  the bridge: %.0fm, its deck %.1fm over the water" % [span, lap.y((s_bridge0 + s_bridge1) * 0.5) - _water_y(-430.0)])


## The raft train across the pool: sections of lashed logs end to end along the crossing, their deck one row of flat
## boxes (wood, driven on); and more rafts with their loads moored in the log pond, tied to posts on its bank. (Rafts
## had drifted down the river, through the timber bridge and the raft train: the user saw them collide.)
func _build_rafts(root: Node3D, rng: RandomNumberGenerator) -> void:
	var r: Route = _route_by_name["RaftCrossing"]
	var logs := 11
	var raft_len: float = 7.5
	var w_life: float = float(_kit_value(river_kit, "raft_width", [logs], 3.6))
	var mesh: ArrayMesh = _kit_mesh(river_kit, "raft_section", func(pk: PropKit, kit: Dictionary) -> void:
		_kit_call(river_kit, "log_raft", [pk, kit, logs, raft_len, rng]))
	var holder := Node3D.new()
	holder.name = "RaftTrain"
	holder.set_script(load("res://RiverRafts.gd"))
	root.add_child(holder)
	var body := StaticBody3D.new()
	body.name = "RaftDeckBody"
	body.set_meta(&"surface", "wood")
	root.add_child(body)
	var step: float = raft_len * PROP_SCALE + 0.3
	var s: float = raft_s0 - 1.0 + step * 0.5
	var n := 0
	# Two sections abreast make the deck wide enough to drive.
	var wide: float = w_life * PROP_SCALE
	while s < raft_s1 + 1.0 + step * 0.5:
		var p: Vector3 = r.pt(s)
		var fwd: Vector3 = r.fw(s)
		var wy: float = _water_y(p.x)
		var basis := Basis(Vector3.UP.cross(fwd).normalized(), Vector3.UP, fwd)
		for side in [-0.5, 0.5]:
			if mesh != null:
				var mi := MeshInstance3D.new()
				mi.name = "Moored_%d_%s" % [n, "a" if side < 0.0 else "b"]
				mi.mesh = mesh
				mi.transform = Transform3D(basis.scaled(Vector3.ONE * PROP_SCALE), Vector3(p.x, wy, p.z) + basis.x * side * (wide + 0.2))
				mi.set_meta(&"skip_dressing_colliders", true)
				holder.add_child(mi)
		_box_shape(body, Transform3D(basis, Vector3(p.x, wy + 0.30 * PROP_SCALE - 0.6, p.z)), Vector3(wide * 2.0 + 0.4, 1.2, step + 0.2))
		s += step
		n += 1
	# The log pond: three rafts with their loads, lying along the bay, each tied to a post on the bank.
	var by: float = _water_y(BAY_C.x)
	var moored := 0
	var bay_rafts: Array = [[Vector2(BAY_C.x + 7.0, BAY_C.y - 4.5), 0], [Vector2(BAY_C.x - 5.0, BAY_C.y + 3.5), 1], [Vector2(BAY_C.x + 8.0, BAY_C.y + 3.5), 2]]
	var raft_l: float = raft_len * PROP_SCALE
	for br in bay_rafts:
		var c: Vector2 = br[0]
		# Lying along x: all four corners well inside the pond.
		var ok := true
		for corner in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, 0.5)]:
			if _bay_d(c.x + corner.x * raft_l, c.y + corner.y * wide) > -1.5:
				ok = false
		if not ok or mesh == null:
			continue
		var basis := Basis(Vector3(0, 0, -1), Vector3.UP, Vector3(1, 0, 0))
		var mi := MeshInstance3D.new()
		mi.name = "Moored_bay_%d" % moored
		mi.mesh = mesh
		mi.transform = Transform3D(basis.scaled(Vector3.ONE * PROP_SCALE), Vector3(c.x, by, c.y))
		mi.set_meta(&"skip_dressing_colliders", true)
		holder.add_child(mi)
		var v: int = int(br[1])
		var cargo: ArrayMesh = _kit_mesh(river_kit, "raft_cargo_%d" % v, func(pk: PropKit, kit: Dictionary) -> void:
			_kit_call(river_kit, "raft_cargo", [pk, kit, v, rng]))
		if cargo != null:
			var cg := MeshInstance3D.new()
			cg.name = "Cargo"
			cg.mesh = cargo
			cg.set_meta(&"skip_dressing_colliders", true)
			mi.add_child(cg)
		_note_rect(c, raft_l, wide, 0.0, 1.0)
		# Its post on the nearer bank, a line to its stern.
		var stern := Vector3(c.x - raft_l * 0.5 + 0.6, by + 0.45, c.y)
		var dirs: Array = [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0)]
		var post := Vector2.INF
		for dv in dirs:
			var q := Vector2(stern.x, stern.z)
			var walk := 0
			while walk < 60 and _bay_d(q.x, q.y) < 1.2:
				q += (dv as Vector2) * 0.5
				walk += 1
			if walk < 60 and (post == Vector2.INF or q.distance_to(Vector2(stern.x, stern.z)) < post.distance_to(Vector2(stern.x, stern.z))):
				post = q
		if post != Vector2.INF:
			var pp := Vector3(post.x, _ground_at(post.x, post.y), post.y)
			_put(_cell_key("moorings", pp), river_kit, Transform3D(Basis(), pp), "mooring_post", [1.5], 500.0)
			var top: Vector3 = pp + Vector3(0, 1.15 * PROP_SCALE, 0)
			_put_world("moorings", top, river_kit, "mooring_rope", [_life(top), _life(stern), 0.25], 500.0)
		moored += 1
	print("  the raft train: %d sections, %.1fm wide; %d rafts moored in the log pond" % [n, wide * 2.0, moored])


## The lumber yard: the water-powered sawmill close by the road (its wheel turning under the water off the flume), the
## flume on its trestles back up the hill to the mill pond and its sluice, the culverts carrying the tailrace under the
## road; stacks of cedar logs and sawn boards.
func _build_yard(root: Node3D, rng: RandomNumberGenerator) -> void:
	var size: Vector3 = _kit_value(river_kit, "sawmill_size", [], Vector3(16.0, 7.0, 9.0))
	var xf: Transform3D = _mill_xf
	if _put("sawmill", river_kit, xf, "sawmill", [LBL, false], 1200.0):
		_note_frame(xf, Vector2(-1.5, -size.z - 1.0), Vector2(size.x + 1.0, 1.0), 1.0)
		var wheel_at: Vector3 = _kit_value(river_kit, "sawmill_wheel_at", [], Vector3(1.3, 2.75, -5.15))
		var wmesh: ArrayMesh = _kit_mesh(river_kit, "sawmill_wheel", func(pk: PropKit, kit: Dictionary) -> void:
			_kit_call(river_kit, "water_wheel", [pk, kit]))
		if wmesh != null:
			var w := MeshInstance3D.new()
			w.name = "SawmillWheel"
			w.mesh = wmesh
			w.set_script(load("res://Spinner.gd"))
			w.set("axis", Vector3(1, 0, 0))
			w.set("degrees_per_second", 26.0)
			w.transform = Transform3D(Basis.from_scale(Vector3.ONE * PROP_SCALE), xf * (wheel_at * PROP_SCALE))
			root.add_child(w)
	print("  the sawmill at %.0f, %.0f (%.1fm up), its front %.0fm off the road's edge" % [xf.origin.x, xf.origin.z, xf.origin.y, MILL_GAP])
	# The flume on its trestles, from the pond's sluice to the sawmill's trough.
	var ground := func(x: float, z: float) -> float: return _ground_at(x, z)
	var fpts := _flume_pts
	_add_prop_game("millflume", river_kit, Transform3D.IDENTITY, func(pk: PropKit, kit: Dictionary, _labels: Array) -> void:
		_kit_call(river_kit, "flume", [pk, kit, fpts, ground, FLUME_IW, FLUME_WH]), 1200.0)
	var f0: Vector3 = _flume_pts[0]
	var f1: Vector3 = _flume_pts[_flume_pts.size() - 1]
	_note_rect(Vector2(f0.x, (f0.z + f1.z) * 0.5), 5.0, absf(f1.z - f0.z), 0.0, 1.0)
	_add_prop_game("millflume", river_kit, Transform3D(Basis(), f0), func(pk: PropKit, kit: Dictionary, _labels: Array) -> void:
		_kit_call(river_kit, "sluice", [pk, kit, FLUME_IW, FLUME_WH]), 1000.0)
	# Stones round the pond's rim, a stone lantern and a little shrine to the water.
	var pc := Vector2(_pond.x, _pond.z)
	for k in range(14):
		var ang: float = TAU * float(k) / 14.0 + 0.2
		if absf(wrapf(ang - PI * 0.5, -PI, PI)) < 0.35:
			continue
		var q: Vector2 = pc + Vector2(cos(ang), sin(ang)) * (_pond.w + 0.9)
		var sx := Transform3D(Basis(Vector3.UP, ang), Vector3(q.x, _ground_at(q.x, q.y) - 0.1, q.y))
		_put(_cell_key("pond", sx.origin), prop_kit, sx, "cairn", [rng, rng.randf_range(0.35, 0.6)], 500.0)
	var lq: Vector2 = pc + Vector2(_pond.w + 3.0, -2.0)
	_put(_cell_key("pond", Vector3(lq.x, 0, lq.y)), prop_kit, _facing(Vector3(pc.x - lq.x, 0, pc.y - lq.y), Vector3(lq.x, _ground_at(lq.x, lq.y), lq.y)), "stone_lantern", [1, 1.8], 500.0)
	var hq: Vector2 = pc + Vector2(-_pond.w - 3.2, 1.0)
	_put(_cell_key("pond", Vector3(hq.x, 0, hq.y)), prop_kit, _facing(Vector3(pc.x - hq.x, 0, pc.y - hq.y), Vector3(hq.x, _ground_at(hq.x, hq.y), hq.y)), "hokora", [], 500.0)
	_note_circle(pc, _pond.w + 4.0)
	# The culverts' headwalls where the tailrace goes under the yard road and comes out on the river side.
	for cv in _culverts:
		var bed: Vector3 = cv[0]
		var out: Vector3 = cv[1]
		var top: float = maxf(_ground_at(bed.x - 2.6, bed.z - out.z * 0.5), _ground_at(bed.x + 2.6, bed.z - out.z * 0.5)) + 0.12
		var h: float = clampf(top - bed.y, 1.2, 3.5)
		var cx := _facing(out, bed)
		_add_prop_game("culvert", river_kit, cx, func(pk: PropKit, kit: Dictionary, _labels: Array) -> void:
			_kit_call(river_kit, "culvert_head", [pk, kit, 5.0, h, 2.4, minf(1.15, h - 0.45), 5.0]), 900.0)
		_note_circle(Vector2(bed.x, bed.z), 3.5)
	# Logs and boards along both sides of the yard road (none on the tailrace or the brook).
	var spots: Array = [[-420.0, -1.0, "log_stack", [6, 6.0, rng]], [-395.0, 1.0, "log_pile", [9, 4.0, rng]], [-360.0, 1.0, "log_stack", [5, 6.0, rng]],
			[-226.0, -1.0, "plank_stack", []], [-213.0, -1.0, "plank_stack", []], [-200.0, 1.0, "log_stack", [7, 6.0, rng]],
			[-185.0, -1.0, "kinma_sled", []], [-232.0, 1.0, "log_pile", [7, 4.0, rng]]]
	for sp in spots:
		var s: float = _closest_s(Vector2(float(sp[0]), -150.0))
		var lx: Transform3D = _beside(lap, s, float(sp[1]) * (road_half + 7.0))
		if _occupied(lx.origin.x, lx.origin.z) or _race_d(lx.origin.x, lx.origin.z) < 5.0:
			continue
		lx = Transform3D(Basis(Vector3.UP, PI * 0.5) * lx.basis, lx.origin)
		if _put(_cell_key("timber", lx.origin), river_kit, lx, String(sp[2]), sp[3], 700.0):
			_note_circle(Vector2(lx.origin.x, lx.origin.z), 7.0)
	# Logs waiting by the sawmill's shed for the saw.
	var wx: Transform3D = _mill_xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(19.5, 0.0, -4.0) * PROP_SCALE)
	wx.origin.y = _ground_at(wx.origin.x, wx.origin.z)
	if not _occupied(wx.origin.x, wx.origin.z):
		_put(_cell_key("timber", wx.origin), river_kit, wx, "log_pile", [8, 4.5, rng], 700.0)
		_note_circle(Vector2(wx.origin.x, wx.origin.z), 6.0)


## The forest road, twisting up and down through the cedar plantation: curve mirrors and warning signs at its four sharp
## bends, jizo inside them, a cedar torii over the road at the top of the climb with stone lanterns, a wayside shrine and
## way-stones, the forestry's log stacks, a timber sledge, a woodcutters' hut with its kei truck, banners.
func _build_forest_road(root: Node3D, rng: RandomNumberGenerator) -> void:
	var bends: Array = [Vector2(-110.0, -265.0), Vector2(-20.0, -215.0), Vector2(40.0, -325.0), Vector2(150.0, -265.0)]
	for hi in range(bends.size()):
		var s_h: float = _closest_s(bends[hi])
		var k: float = lap.at(s_h)["k"]
		var out_side: float = -signf(k)
		var mx: Transform3D = _beside(lap, s_h, out_side * (road_half + 2.6))
		_put(_cell_key("forest_signs", mx.origin), prop_kit, mx, "curve_mirror", [hi % 2 == 0], 300.0)
		_note_circle(Vector2(mx.origin.x, mx.origin.z), 2.0)
		var sx: Transform3D = _beside(lap, s_h - 52.0, road_half + 2.4)
		_put(_cell_key("forest_signs", sx.origin), prop_kit, Transform3D(Basis(Vector3.UP, PI * 0.5) * sx.basis, sx.origin), "road_sign",
				["curve_l" if k < 0.0 else "curve_r", LBL], 300.0)
		_note_circle(Vector2(sx.origin.x, sx.origin.z), 1.5)
		if hi != 2:
			var jx: Transform3D = _beside(lap, s_h, -out_side * (road_half + 4.5))
			if not _occupied(jx.origin.x, jx.origin.z):
				_put(_cell_key("forest_signs", jx.origin), prop_kit, jx, "jizo_row", [4 + hi, rng], 300.0)
				_note_circle(Vector2(jx.origin.x, jx.origin.z), 4.0)
	# A cedar torii over the road near the top of the climb, stone lanterns at its feet.
	var s_t: float = _closest_s(Vector2(22.0, -292.0))
	var tx: Transform3D = _across(lap, s_t)
	tx.origin.y -= 0.05
	for side in [-1.0, 1.0]:
		var leg: Vector3 = tx.origin + tx.basis.x * side * 5.2 * PROP_SCALE
		tx.origin.y = minf(tx.origin.y, _ground_at(leg.x, leg.z) - 0.02)
	_put("forest_torii", prop_kit, tx, "torii", [2, 10.4, 7.2], 900.0)
	for side in [-1.0, 1.0]:
		var foot: Vector3 = tx.origin + tx.basis.x * side * 5.2 * PROP_SCALE
		_note_circle(Vector2(foot.x, foot.z), 2.5)
		var lx: Transform3D = _beside(lap, s_t + 9.0, side * (road_half + 2.2))
		_put("forest_torii", prop_kit, lx, "stone_lantern", [0, 2.3], 900.0)
		_note_circle(Vector2(lx.origin.x, lx.origin.z), 1.5)
	# Wayside things and the forestry's work along the way.
	var spots: Array = [
		[Vector2(-135.0, -205.0), 1.0, prop_kit, "stone_marker", [1.5, "YOSHINO SUGI", LBL], 3.5],
		[Vector2(-75.0, -246.0), -1.0, river_kit, "log_stack", [6, 6.0, rng], 7.0],
		[Vector2(-58.0, -238.0), 1.0, prop_kit, "stone_lantern", [0], 3.0],
		[Vector2(10.0, -270.0), -1.0, prop_kit, "hokora", [], 4.0],
		[Vector2(-2.0, -246.0), 1.0, river_kit, "log_pile", [8, 4.0, rng], 7.0],
		[Vector2(80.0, -305.0), 1.0, river_kit, "log_stack", [5, 6.0, rng], 7.0],
		[Vector2(110.0, -287.0), -1.0, river_kit, "kinma_sled", [rng], 6.0],
		[Vector2(125.0, -279.0), 1.0, prop_kit, "stone_marker", [1.4, "SHURA", LBL], 3.5],
		[Vector2(195.0, -282.0), -1.0, river_kit, "log_stack", [7, 6.0, rng], 7.0],
	]
	for sp in spots:
		var s_q: float = _closest_s(sp[0])
		var off: float = 3.6 if String(sp[3]) in ["stone_marker", "stone_lantern", "hokora"] else 7.5
		var lx2: Transform3D = _beside(lap, s_q, float(sp[1]) * (road_half + off))
		if _occupied(lx2.origin.x, lx2.origin.z):
			continue
		if String(sp[3]) in ["log_stack", "log_pile", "kinma_sled"]:
			lx2 = Transform3D(Basis(Vector3.UP, PI * 0.5) * lx2.basis, lx2.origin)
		if _put(_cell_key("forest_wayside", lx2.origin), sp[2], lx2, String(sp[3]), sp[4], 600.0):
			_note_circle(Vector2(lx2.origin.x, lx2.origin.z), float(sp[5]))
	# Banners up the first climb.
	var s0: float = _closest_s(Vector2(-140.0, -180.0))
	for k2 in range(4):
		var nx: Transform3D = _beside(lap, s0 + float(k2) * 14.0, -(road_half + 3.0))
		if not _occupied(nx.origin.x, nx.origin.z):
			_put(_cell_key("forest_wayside", nx.origin), prop_kit, nx, "nobori", [Color(0.18, 0.42, 0.30) if k2 % 2 == 0 else Color(0.86, 0.22, 0.30)], 420.0)
			_note_circle(Vector2(nx.origin.x, nx.origin.z), 1.2)
	# The woodcutters' hut in a clearing inside the dip's bend, its kei truck loaded with logs.
	var s_hut: float = _closest_s(Vector2(150.0, -265.0)) - 30.0
	var hx: Transform3D = _beside(lap, s_hut, -(road_half + 13.0))
	var gr: Vector2 = _ground_range(Vector2(hx.origin.x, hx.origin.z), 16.0, 12.0, 0.0)
	hx.origin.y = gr.y
	hx.origin -= hx.basis.x * 4.5 * PROP_SCALE
	if not _occupied(hx.origin.x, hx.origin.z) and _put("forest_hut", town_kit, hx, "mountain_hut", [LBL], 900.0):
		_note_frame(hx, Vector2(-1.0, -7.5), Vector2(10.0, 1.5), 2.0)
		var kx: Transform3D = _beside(lap, s_hut + 22.0, -(road_half + 6.0))
		kx = Transform3D(Basis(Vector3.UP, PI * 0.5) * kx.basis, kx.origin)
		if not _occupied(kx.origin.x, kx.origin.z):
			_put("forest_hut", prop_kit, kx, "kei_truck", [Color(0.93, 0.93, 0.90)], 500.0)
			_note_circle(Vector2(kx.origin.x, kx.origin.z), 4.0)


## The timber slide's log walls and trestles (the kit), its walls solid.
func _build_slide(root: Node3D) -> void:
	var pts := PackedVector3Array()
	var rights := PackedVector3Array()
	var s: float = s_chute0
	while s <= s_chute1:
		pts.append(lap.pt(s))
		rights.append(lap.rt(s))
		s += 2.0
	var ground := func(x: float, z: float) -> float: return _ground_at(x, z)
	_add_prop_game("timber_slide", river_kit, Transform3D.IDENTITY, func(pk: PropKit, kit: Dictionary, _labels: Array) -> void:
		_kit_call(river_kit, "timber_chute", [pk, kit, pts, rights, road_half, ground]), 1200.0)
	var body: StaticBody3D = _body(root, "SlideWallsBody")
	for side in [-1.0, 1.0]:
		_edge_boxes(body, lap, s_chute0, s_chute1 - 6.0, side * (road_half + 0.45), 1.5, 0.6)


## The ford: a fish weir below it, way-stones either side, a boat.
func _build_ford(root: Node3D, rng: RandomNumberGenerator) -> void:
	_build_heron(root)
	var x: float = FORD_X - 75.0
	var at := Vector3(x, _water_y(x), _river_z(x) + 6.0)
	_put("ford_yana", river_kit, Transform3D(Basis(Vector3.UP, PI * 0.5), at), "yana", [9.0], 800.0)
	for q in [Vector2(FORD_X, -70.0), Vector2(FORD_X, 62.0)]:
		var mx: Transform3D = _beside(lap, _closest_s(q), road_half + 3.0)
		_put(_cell_key("wayside", mx.origin), prop_kit, mx, "stone_lantern", [0], 400.0)


## A grey heron in the shallows above the ford, looking upstream (Heron.gd: it takes off when a cart comes near and
## flies a loop up the river and back).
func _build_heron(root: Node3D) -> void:
	var hx: float = HERON_AT.x
	var hz: float = _river_z(hx) + HERON_AT.y
	var at := Vector3(hx, _ground_at(hx, hz), hz)
	var h := Node3D.new()
	h.name = "Heron"
	h.set_script(load("res://Heron.gd"))
	h.transform = Transform3D(Basis(Vector3.UP, PI * 0.5 + 0.3), at)
	var loop := PackedVector3Array()
	for p in [Vector3(25.0, 5.0, -4.0), Vector3(80.0, 12.0, -10.0), Vector3(140.0, 15.0, -2.0), Vector3(172.0, 13.0, 16.0), Vector3(125.0, 10.0, 26.0),
			Vector3(65.0, 7.0, 12.0), Vector3(22.0, 3.0, 3.0)]:
		var x: float = hx + p.x
		loop.append(Vector3(x, _water_y(x) + p.y, _river_z(x) + HERON_AT.y + p.z))
	h.set("flight", loop)
	root.add_child(h)


## Koinobori: lines of carp across the river (as Japanese river towns hang them in May), streaming downstream, and
## poles on the village's river side.
func _build_koinobori(rng: RandomNumberGenerator) -> void:
	var wind := Vector3(-1.0, 0.0, 0.08)
	var lines := 0
	# Just downstream of the timber bridge (seen from it and from the rafts), mid-river, and above the ford.
	for x in [-385.0, 175.0, 480.0]:
		var zc: float = _river_z(x)
		var hw: float = _river_half(x) + 9.0
		var a := Vector3(x, 0.0, zc - hw)
		var b := Vector3(x, 0.0, zc + hw)
		a.y = _ground_at(a.x, a.z)
		b.y = _ground_at(b.x, b.z)
		if _occupied(a.x, a.z) or _occupied(b.x, b.z):
			continue
		var n: int = int(a.distance_to(b) / 5.4)
		_put_world("koinobori_river", a, prop_kit, "koinobori_line", [_life(a), _life(b), n, wind, 1.6, rng, 10.5], 1400.0)
		_note_circle(Vector2(a.x, a.z), 3.0)
		_note_circle(Vector2(b.x, b.z), 3.0)
		lines += 1
	var poles := 0
	for q in [Vector2(430.0, 0.0), Vector2(60.0, 0.0), Vector2(250.0, 0.0)]:
		var s_q: float = _closest_s(Vector2(q.x, 125.0))
		var at: Vector3 = lap.spot(s_q, PROM_LAT + PROM_W * 0.5 + 11.0, 0.0)["pos"]
		if _water_d_ok(at) and not _occupied(at.x, at.z):
			at.y = _ground_at(at.x, at.z)
			_put(_cell_key("koinobori_poles", at), prop_kit, Transform3D(Basis(), at), "koinobori_pole", [12.0, 2 + poles % 2, wind, rng], 900.0)
			_note_circle(Vector2(at.x, at.z), 7.0)
			poles += 1
	print("  koinobori: %d lines over the river, %d poles" % [lines, poles])


## The bots' shortcuts: the raft crossing (MiyoshinoStage's), and the park run, which isn't a road of its own: a line
## over the ground (and the park's little drum bridge's deck) off the start straight, across the promenade and the lawns,
## that joins the raft crossing on its way to the water.
func _build_shortcut_paths(root: Node3D) -> void:
	super(root)
	var holder: Node3D = root.get_node_or_null("AlternativePaths")
	var raft: Route = _route_by_name.get("RaftCrossing")
	if holder == null or raft == null:
		return
	var pts: Array = []
	for i in range(PARK_RUN.size()):
		var p: Vector2 = PARK_RUN[i][0]
		if i == 0:
			p = lap.at(lap.closest_s(p))["p"]
		pts.append([p, float(PARK_RUN[i][1])])
	var r := Route.new()
	r.name = "ParkRun"
	r.half = 3.0
	r.build(pts, false)
	r.from_s = lap.closest_s(pts[0][0])
	var end_p: Vector2 = pts[pts.size() - 1][0]
	var join: float = raft.closest_s(end_p)
	var bx: Transform3D = _park_bridge
	var span: float = PARK_BRIDGE.x * PROP_SCALE
	var rise: float = PARK_BRIDGE.z * PROP_SCALE
	var curve := Curve3D.new()
	curve.bake_interval = 0.5
	var line: Array = [lap.pt(r.from_s - 10.0) + Vector3(0, 0.02, 0)]
	var s := 0.0
	while s < r.length:
		var q: Vector2 = r.at(s)["p"]
		var y: float = _ground_at(q.x, q.y)
		# On the little bridge: its deck's curve.
		var local: Vector3 = bx.affine_inverse() * Vector3(q.x, bx.origin.y, q.y)
		if absf(local.x) < span * 0.5 and absf(local.z) < 3.0:
			y = maxf(y, bx.origin.y + rise * (1.0 - pow(2.0 * local.x / span, 2.0)))
		line.append(Vector3(q.x, y + 0.02, q.y))
		s += 4.0
	var t: float = join
	while t < raft.length:
		line.append(raft.pt(t) + Vector3(0, 0.02, 0))
		t += 4.0
	line.append(lap.pt(raft.to_s + 10.0) + Vector3(0, 0.02, 0))
	for i in range(line.size()):
		var a: Vector3 = line[maxi(i - 1, 0)]
		var c: Vector3 = line[mini(i + 1, line.size() - 1)]
		var hnd: Vector3 = (c - a) / 6.0
		curve.add_point(line[i], -hnd, hnd)
	var path := Path3D.new()
	path.name = "ParkRun"
	path.set_meta(&"ai_chance_scale", 0.35)
	path.curve = curve
	holder.add_child(path)
	var list: Array[Path3D] = []
	for c2 in holder.get_children():
		if c2 is Path3D:
			list.append(c2)
	root.set("alternative_paths", list)
	print("  shortcut ParkRun: %.0fm over the lawns, then the raft crossing from %.0fm (lap %.0fm to %.0fm)" % [r.length, join, r.from_s, raft.to_s])


## The ground's grid halved (2m) round the garden stream and the mill's tailrace and brook: on the 4m grid their channels,
## a few metres wide, came out as a row of pits with the water showing in patches.
func _extra_refine() -> Array:
	return [[Vector2(-196.0, -118.0), Vector2(-285.0, -250.0)], [Vector2(-32.0, 106.0), Vector2(-182.0, -92.0)]]


## How far (x, z) is from the park run's line (its corner points; near enough for keeping things off it).
func _run_d(x: float, z: float) -> float:
	var q := Vector2(x, z)
	var best := INF
	for i in range(PARK_RUN.size() - 1):
		var a: Vector2 = PARK_RUN[i][0]
		var b: Vector2 = PARK_RUN[i + 1][0]
		var t: float = clampf((q - a).dot(b - a) / maxf((b - a).length_squared(), 1e-4), 0.0, 1.0)
		best = minf(best, q.distance_to(a.lerp(b, t)))
	return best


## In the riverside park (its own planting): between PARK_X, from the river's shingle up to the promenade.
func _in_park(x: float, z: float) -> bool:
	return x > PARK_X.x - 6.0 and x < PARK_X.y + 6.0 and z < 100.0 and _shore_d(x, z) > 4.0


func _water_d_ok(p: Vector3) -> bool:
	return _shore_d(p.x, p.z) > 12.0
