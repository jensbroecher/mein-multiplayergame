# regenerate_yamabushi.gd
#
# Builds levels/YamabushiLevel.tscn - the Yamabushi Trail, the Miyoshino GP's finale: a point-to-point hill climb (one
# run, no laps) up the mountain ascetics' pilgrim trail at dawn. The trail winds one and a half times round a great
# cone of a mountain from the cedar forest at its foot, over a suspension bridge across the gorge, through the layer of
# cloud that hangs round the mountain's waist (the fog closes in to a few dozen metres), out above it into the
# sunrise along plank walkways chained to the cliffs, over the gorge's head on a timber bridge and up to the shrine on
# the summit, the cloud a sea below. (The file is "YamabushiLevel": "trail" in a level's name would make
# DressingColliders skip every mesh on it.)
#
# Everything shared with the other Miyoshino stages is MiyoshinoStage.gd: read its header first. Here: the mountain
# (a cone about the origin: its height is a function of the distance from the summit, a gorge down one flank), the
# trail (a spiral of corner points), the cloud (CloudLayer.gd, cloud_sea.gdshader) and the dressing.
extends "res://MiyoshinoStage.gd"

const MK = preload("res://MiyoshinoKit.gd")

## The cone: SUMMIT_Y at the top, level out to TOP_R, falling at SLOPE to FOOT_R, the foothills beyond.
const SUMMIT_Y := 262.0
const TOP_R := 78.0
const SLOPE := 0.37
const FOOT_R := 800.0
## The trail's spiral: from R0 at bearing 0 (east of the summit) inward to R1 over TURNS degrees, a corner every STEP.
const R0 := 770.0
const R1 := 60.0
const TURNS := 590.0
const STEP := 20.0
## The gorge down the mountain's flank at this bearing (degrees): how deep and wide at the foot, fading to the top.
const GORGE_AT := 205.0
const GORGE_DEPTH := 30.0
const GORGE_HALF := 26.0
## The plank walkways: [bearing from, bearing to] along the spiral.
const LEDGES := [[262.0, 300.0], [442.0, 486.0]]
## The cloud's band.
const CLOUD_LOW := 96.0
const CLOUD_HIGH := 150.0
## The summit's precinct: a level terrace PRECINCT_R round the summit at PRECINCT_Y, walled (TERRACE_DROP high), the
## mountain below it a gentle dome falling DOME_K a metre to meet the trail where it ends (the cone's top had stood 17m
## over the trail's end, which finished in a cutting) and running into the cone further down.
const PRECINCT_R := 44.0
const PRECINCT_Y := 245.85
const TERRACE_DROP := 2.6
const DOME_K := 0.08
## How far inside the wall the terrace starts to fall to the wall's foot (under its coping and the gravel's edge).
const TERRACE_SLOPE_W := 2.6
## The finish (the user's: the race ends in front of the temple, driven up the stairs onto the plaza, the people at the
## sides): the trail leaves its spiral at the corner at TURN_IN_A (degrees), turns TURN_IN_R round toward the summit and
## runs straight up the great stair onto the terrace and across it to the run-out's end END_Z in front of the main hall
## (HALL_Z), along the precinct's axis (its frame pf: +z from the summit toward the stair). The stair climbs from
## STAIR_FOOT_R (from the summit) to the terrace's rim, its treads STAIR_HALF either side of the line between cheek walls
## CHEEK thick, its grade whatever takes the trail from where it arrives up to PRECINCT_Y (printed: keep it near 16%).
const TURN_IN_A := 540.0
const TURN_IN_R := 26.0
const END_Z := -4.0
const HALL_Z := -14.0
const STAIR_FOOT_R := 96.0
const STAIR_HALF := 7.6
const CHEEK := 0.9
## The eases at the stair's foot and head (metres): its grade grows from the trail's and falls to level over them.
const STAIR_EASE_FOOT := 6.0
const STAIR_EASE_HEAD := 8.0
## A tread's depth along the stair (game metres).
const TREAD := 1.1

var _bridge_s: Array = []
var _ledge_s: Array = []
var _raw_route: Route
## The precinct's axis in plan: from the summit toward the stair (set by _configure from the turn-in corner).
var _axis := Vector2(-1.0, 0.0)
## Where the stair's foot and head are along the lap, and the grade it came out at.
var _s_foot := 0.0
var _s_head := 0.0
var _stair_grade := 0.0


func _configure() -> void:
	level_name = "YamabushiLevel"
	level_path = "res://levels/YamabushiLevel.tscn"
	stem = "yamabushi"
	title = "Yamabushi Trail"
	seed_base = 7700
	road_half = 7.0
	max_grade = 0.105
	cut_slope = 1.05
	fill_slope = 0.85
	closed = false
	point_to_point = true
	start_s = 70.0
	finish_runout = 20.0
	corners = []
	var a := 0.0
	var k := 0
	while a <= TURN_IN_A + 0.01:
		var p: Vector2 = _spiral(a) * (1.0 + (0.03 * sin(float(k) * 2.4) if a > 30.0 and a < TURNS - 40.0 else 0.0))
		var chord: float = (_spiral(a + STEP) - _spiral(a)).length()
		corners.append([p, clampf(chord * 0.8, 20.0, 130.0)])
		a += STEP
		k += 1
	# The turn toward the summit, and the run up the stair and across the terrace to the hall.
	var q: Vector2 = corners[corners.size() - 1][0]
	corners[corners.size() - 1][1] = TURN_IN_R
	_axis = q.normalized()
	corners.append([_axis * END_Z, 0.0])
	# The run-in: a straight start before the first corner, and the last metres straight onto the summit.
	var d0: Vector2 = ((corners[1][0] as Vector2) - (corners[0][0] as Vector2)).normalized()
	corners.push_front([(corners[0][0] as Vector2) - d0 * 150.0, 0.0])
	# The fine ground reaches north past the trailhead for the valley road.
	fine_x = Vector2(-900.0, 1060.0)
	fine_z = Vector2(-1180.0, 900.0)
	fine_step = 5.0
	tree_step = 12.0
	tree_margin = 200.0
	tree_far_range = 1500.0
	collide_margin = 60.0


## Where the trail turns from asphalt to the pilgrims' stone paving: the trailhead's torii.
func _trail_from() -> float:
	return start_s + 110.0

## The valley road's corners (plan), set by _plan_routes.
var _valley_pts: Array = []
## The car park: along the valley road from PARK_S0 to PARK_S1, its middle PARK_LAT right of it (the valley side),
## PARK_HALF deep either side of that.
const PARK_S0 := 34.0
const PARK_S1 := 86.0
const PARK_LAT := 21.0
const PARK_HALF := 13.0


## The valley road: on from the trail's start back down the valley to the north and away into the haze, past the
## trailhead's car park (the user found the road beginning at the start gate unreal).
func _plan_routes() -> void:
	var a: Dictionary = lap.at(0.0)
	var s0: Vector2 = a["p"]
	var d0: Vector2 = Route.dir_of(float(a["th"]))
	var p1: Vector2 = s0 - d0 * 230.0
	var p2: Vector2 = p1 + Vector2(45.0, -380.0)
	var p3: Vector2 = p2 + Vector2(90.0, -380.0)
	_valley_pts = [s0, p1, p2, p3]
	var r: Route = _add_route("ValleyRoad", [[s0, 0.0], [p1, 160.0], [p2, 260.0], [p3, 0.0]], road_half, true, 0.0, false)
	print("  valley road: %.0fm from the trail's start" % r.length)
	# The car park's ground: graded level with the road beside it.
	var sa: float = PARK_S0 - 2.0
	while sa < PARK_S1 + 2.0:
		var sb: float = minf(sa + 3.0, PARK_S1 + 2.0)
		var pa: Vector3 = r.pt(sa) + r.rt(sa) * PARK_LAT
		var pb: Vector3 = r.pt(sb) + r.rt(sb) * PARK_LAT
		_add_seg(pa, pb, [PARK_HALF + 0.5, PARK_HALF + 0.5, 0.9, 0.8, false])
		sa = sb


## Distance in plan to the valley road's corner polyline (cheap: for the trees).
func _valley_d(q: Vector2) -> float:
	var best := 1e9
	for i in range(_valley_pts.size() - 1):
		var a: Vector2 = _valley_pts[i]
		var b: Vector2 = _valley_pts[i + 1]
		var ab: Vector2 = b - a
		var t: float = clampf((q - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		best = minf(best, q.distance_to(a + ab * t))
	return best


## The summit's grid halved (2.5m), for the terrace's walled edge, the stair and its walls.
func _extra_refine() -> Array:
	var far: Vector2 = _axis * (STAIR_FOOT_R + 30.0)
	return [[Vector2(minf(-PRECINCT_R - 50.0, far.x - 20.0), maxf(PRECINCT_R + 30.0, far.x + 20.0))],
			[Vector2(minf(-PRECINCT_R - 50.0, far.y - 20.0), maxf(PRECINCT_R + 30.0, far.y + 20.0))]]


## Where the lap is at a distance `rr` from the summit along the precinct's axis (on the final straight).
func _s_at_axis(rr: float) -> float:
	return lap.length - (rr - END_Z)


## The stair: from its foot the trail's grade grows over STAIR_EASE_FOOT to the stair's, which holds to STAIR_EASE_HEAD
## short of the terrace's rim and eases to level there, the terrace's height (PRECINCT_Y, the ground under the paving);
## level on across the terrace.
func _shape_heights(r: Route, ys: PackedFloat32Array) -> void:
	if r != lap:
		return
	var n: int = ys.size()
	var plaza: float = PRECINCT_Y + GROUND_UNDER
	_s_foot = _s_at_axis(STAIR_FOOT_R)
	_s_head = _s_at_axis(PRECINCT_R - 0.6)
	var i_f: int = int(round(_s_foot))
	var y_f: float = ys[i_f]
	var g_f: float = ys[i_f] - ys[i_f - 1]
	var L: float = _s_head - float(i_f)
	var e1: float = STAIR_EASE_FOOT
	var e2: float = STAIR_EASE_HEAD
	var g: float = (plaza - y_f - g_f * e1 * 0.5) / (L - e1 * 0.5 - e2 * 0.5)
	_stair_grade = g
	for i in range(i_f, n):
		var x: float = float(i - i_f)
		var y: float
		if x >= L:
			y = plaza
		elif x <= e1:
			y = y_f + g_f * x + (g - g_f) * x * x / (2.0 * e1)
		elif x >= L - e2:
			y = plaza - g * (L - x) * (L - x) / (2.0 * e2)
		else:
			y = y_f + g_f * e1 + (g - g_f) * e1 * 0.5 + g * (x - e1)
		ys[i] = y
	print("  the great stair: %.0fm from %.1f up to %.1f, %.1f%% (the trail arrives at %.1f%%)" % [L, y_f, plaza, g * 100.0, g_f * 100.0])
	if g < 0.12 or g > 0.2:
		push_warning("Yamabushi Trail: the great stair's grade is %.1f%%: move PRECINCT_Y to bring it near 16%%" % (g * 100.0))


func _spiral(deg: float) -> Vector2:
	var t: float = clampf(deg / TURNS, 0.0, 1.0)
	var r: float = lerpf(R0, R1, t)
	var a: float = deg_to_rad(deg)
	return Vector2(cos(a), sin(a)) * r


# ======================================================================================
#  The mountain
# ======================================================================================

func _gorge(x: float, z: float) -> float:
	var r: float = Vector2(x, z).length()
	if r < 110.0:
		return 0.0
	var a: float = deg_to_rad(GORGE_AT)
	var axis := Vector2(cos(a), sin(a))
	var along: float = Vector2(x, z).dot(axis)
	if along < 0.0:
		return 0.0
	var across: float = absf(-x * axis.y + z * axis.x) + 9.0 * sin(r / 46.0)
	var w: float = GORGE_HALF * (0.55 + 0.45 * smoothstep(120.0, 600.0, r))
	var q: float = across / w
	return GORGE_DEPTH * (0.4 + 0.6 * smoothstep(120.0, 500.0, r)) * exp(-q * q) * smoothstep(110.0, 170.0, r)


## The mountain's shape by the distance from the summit (no spurs): the cone, its top the dome under the precinct's
## terrace.
func _summit_h(r: float) -> float:
	var cone: float = SUMMIT_Y - maxf(0.0, r - TOP_R) * SLOPE
	var base: float = PRECINCT_Y - TERRACE_DROP
	var dome: float = base - maxf(0.0, r - PRECINCT_R - 1.2) * DOME_K
	# A smooth minimum: the dome runs into the cone's flank without a crease.
	var k := 6.0
	var hh: float = clampf(0.5 + 0.5 * (dome - cone) / k, 0.0, 1.0)
	var h: float = lerpf(dome, cone, hh) - k * hh * (1.0 - hh)
	# The terrace: level to TERRACE_SLOPE_W inside its wall, then down to the wall's foot by the wall's own line, hidden
	# under the coping and the gravel. Dropping outside the wall, the ground's grid smeared the drop over a cell and
	# buried most of the wall.
	if r < PRECINCT_R:
		h = lerpf(PRECINCT_Y, base, clampf((r - (PRECINCT_R - TERRACE_SLOPE_W)) / (TERRACE_SLOPE_W - 0.1), 0.0, 1.0))
	return h


func _natural(x: float, z: float) -> float:
	var r: float = Vector2(x, z).length()
	var h: float = _summit_h(r)
	var foot: float = SUMMIT_Y - (FOOT_R - TOP_R) * SLOPE
	if r > FOOT_R:
		h = foot - (r - FOOT_R) * 0.05
		h = maxf(h, foot - 26.0)
	# Spurs and hollows, bolder higher up; crags where the noise runs high.
	var up: float = smoothstep(FOOT_R, 150.0, r)
	h += (3.0 + 5.0 * up) * n_hill.get_noise_2d(x * 0.8, z * 0.8) * smoothstep(TOP_R, TOP_R + 60.0, r)
	h += 1.2 * n_fine.get_noise_2d(x * 0.6, z * 0.6) * smoothstep(TOP_R, TOP_R + 40.0, r)
	h -= _gorge(x, z)
	# Other peaks standing out of the cloud far off.
	h += smoothstep(1500.0, 4200.0, r) * (240.0 + 360.0 * absf(n_ridge.get_noise_2d(x, z)))
	return h


func _init_noise() -> void:
	super._init_noise()
	_raw_route = Route.new()
	_raw_route.build(corners, false)
	# Bridges: where the trail is over the gorge.
	var s := 0.0
	var a := -1.0
	var b := -1.0
	while s < _raw_route.length:
		var p: Vector2 = _raw_route.at(s)["p"]
		if _gorge(p.x, p.y) > 5.0:
			if a < 0.0:
				a = s
			b = s
		elif a >= 0.0:
			bridges.append(["lap", a - 5.0, b + 5.0, 0.0])
			_bridge_s.append([a - 5.0, b + 5.0])
			a = -1.0
		s += 1.0
	for l in LEDGES:
		var s0: float = _raw_route.closest_s(_spiral(float(l[0])))
		var s1: float = _raw_route.closest_s(_spiral(float(l[1])))
		_ledge_s.append([s0, s1])
	print("  bridges %s, plank walks %s" % [str(_bridge_s), str(_ledge_s)])


func _on_ledge(s: float) -> bool:
	for l in _ledge_s:
		if s >= float(l[0]) and s <= float(l[1]):
			return true
	return false


func _road_base(_r: Route, s: float, p: Vector2) -> float:
	# The valley road lies on the valley floor.
	if _r != lap:
		return _natural(p.x, p.y) + GROUND_UNDER
	# The trail climbs steadily with the spiral: the cone's own height at its radius, without the spurs.
	var r: float = p.length()
	var h: float = _summit_h(r)
	return lerpf(_natural(p.x, p.y), h, 0.6) + GROUND_UNDER + (_gorge(p.x, p.y) * 0.6)


## The trail: asphalt from the valley road to the trailhead's torii (`_trail_from`), then the pilgrims' stone paving
## (ishidatami) all the way up, planks on the bridges and the cliff walks. (It was trodden earth.)
func _sections(r: Route) -> Array:
	if r.name == "ValleyRoad":
		return [[0.0, r.length, K_ASPHALT, r.half]]
	var cuts: Array = [[0.0, _trail_from(), K_ASPHALT], [_s_foot, _s_head, K_STEPS]]
	for b in _bridge_s:
		cuts.append([float(b[0]), float(b[1]), K_PLANKS])
	for l in _ledge_s:
		cuts.append([float(l[0]), float(l[1]), K_PLANKS])
	cuts.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
	var out: Array = []
	var s := 0.0
	for c in cuts:
		if float(c[0]) > s:
			out.append([s, float(c[0]), K_STONE, r.half])
		out.append([float(c[0]), float(c[1]), int(c[2]), r.half])
		s = float(c[1])
	out.append([s, r.length, K_STONE, r.half])
	return out


## The mountain is on the right of travel all the way (the trail winds clockwise as seen from above): on the plank
## walks the ground is cut away under the deck's valley side.
func _grade_params(r: Route, s: float) -> Array:
	if r != lap:
		return [r.half + 2.0, r.half + 2.0, cut_slope, fill_slope]
	if _on_ledge(s):
		return [0.5, r.half + 2.0, 1.6, 2.6]
	# The stair stands on a causeway between its cheek walls: the ground drops at the walls' outer faces.
	if s > _s_foot - 2.0 and s < _s_head + 1.0:
		return [STAIR_HALF + CHEEK + 0.2, STAIR_HALF + CHEEK + 0.2, cut_slope, 4.0]
	return [r.half + 2.0, r.half + 2.5, cut_slope, fill_slope]


# ======================================================================================
#  What grows where
# ======================================================================================

func _grove_w(x: float, z: float) -> float:
	var r: float = Vector2(x, z).length()
	# Mountain cherries in patches up to the cloud, a few above it.
	var band: float = smoothstep(FOOT_R + 60.0, FOOT_R - 80.0, r) * (1.0 - smoothstep(330.0, 420.0, 800.0 - r))
	return band * smoothstep(0.1, 0.4, n_wood.get_noise_2d(x * 1.4, z * 1.4)) * 0.8


func _forest_w(x: float, z: float) -> float:
	var r: float = Vector2(x, z).length()
	# Cedar forest from the foot to above the cloud, thinning to rock and scrub toward the summit.
	return clampf(smoothstep(190.0, 330.0, r) * (0.75 + 0.4 * n_wood.get_noise_2d(x, z)), 0.0, 1.0)


func _masks(_i: int, x: float, z: float, nrm_y: float, road_d: float) -> Color:
	var off: float = smoothstep(road_half + 3.0, road_half + 12.0, road_d)
	var r: float = Vector2(x, z).length()
	var rock: float = 1.0 - smoothstep(0.66, 0.80, nrm_y)
	# Bare rock and scree toward the top.
	rock = maxf(rock, smoothstep(560.0, 260.0, r) * smoothstep(-0.25, 0.2, n_hill.get_noise_2d(x * 1.7, z * 1.7) + 0.5 * n_fine.get_noise_2d(x, z)))
	var grove: float = _grove_w(x, z)
	var forest: float = _forest_w(x, z) * (1.0 - grove)
	# Bare under the precinct's gravel, grass round it with less rock.
	rock *= lerpf(0.3, 1.0, smoothstep(PRECINCT_R + 20.0, PRECINCT_R + 120.0, r))
	var bare: float = (1.0 - smoothstep(PRECINCT_R - 3.0, PRECINCT_R + 0.5, r)) * 0.9
	return Color(rock * (1.0 - bare), bare, grove * off * (1.0 - rock), forest * off * (1.0 - rock))


func _tree_pick(x: float, z: float, roll: float, rng: RandomNumberGenerator) -> Array:
	var r: float = Vector2(x, z).length()
	# Past the mountain's foot the cedars stand only along the valley road.
	if r < TOP_R + 20.0 or (r > FOOT_R + 240.0 and (r > FOOT_R + 520.0 or _valley_d(Vector2(x, z)) > 170.0)):
		return []
	var g: float = _grove_w(x, z)
	var f: float = _forest_w(x, z) * (1.0 - g)
	if roll < g * 0.4:
		return ["yamazakura", rng.randf_range(0.9, 1.25), rng.randi_range(0, 1)]
	if roll < g * 0.4 + f * 0.3:
		# Smaller, wind-bent trees toward the summit.
		var sc: float = rng.randf_range(0.8, 1.2) * lerpf(0.55, 1.0, smoothstep(200.0, 420.0, r))
		return ["sugi", sc, rng.randi_range(0, 1)]
	if r < 330.0 and roll < 0.03:
		return ["matsu", rng.randf_range(0.9, 1.3)]
	return []


func _environment() -> Dictionary:
	# Dawn above the cloud: the sun just up in the east, gold on the rock, the sky pale and clear.
	return {
		"sky_top": Color(0.20, 0.36, 0.70), "sky_horizon": Color(0.98, 0.80, 0.60), "haze": Color(0.96, 0.84, 0.70),
		"ground_bottom": Color(0.78, 0.76, 0.76), "sky_curve": 0.55, "haze_strength": 0.8, "haze_height": 0.12,
		"sun_tint": Color(1.0, 0.86, 0.62), "sun_glow": 0.8, "sun_horizon_tint": Color(1.0, 0.72, 0.42), "sun_horizon_glow": 0.6,
		"cloud_lit": Color(1.0, 0.86, 0.72), "cloud_shade": Color(0.60, 0.58, 0.70), "cloud_coverage": 0.16, "cloud_seed": 71.9,
		"ambient": 0.6, "ambient_color": Color(0.86, 0.88, 1.0), "exposure": 1.05, "glow": 0.4, "bloom": 0.08,
		"fog_begin": 30.0, "fog_end": 900.0, "fog_curve": 1.1, "fog_sky": 0.9, "fog_aerial": 0.0, "fog_scatter": 0.3,
		"sun_pitch": -14.0, "sun_yaw": 96.0, "sun_color": Color(1.0, 0.84, 0.62), "sun_energy": 1.35, "shadow_distance": 300.0,
	}


func _ground_params(m: ShaderMaterial) -> void:
	m.set_shader_parameter("petal_amount", 1.3)
	m.set_shader_parameter("moss_amount", 0.9)
	m.set_shader_parameter("rock_tint", Color(0.50, 0.49, 0.48))
	m.set_shader_parameter("canopy_from", 420.0)
	m.set_shader_parameter("grass_a", Color(0.24, 0.32, 0.15))
	m.set_shader_parameter("grass_b", Color(0.38, 0.40, 0.22))


func _road_params(m: ShaderMaterial) -> void:
	m.set_shader_parameter("wetness", 0.35)
	m.set_shader_parameter("plank_tint", Color(0.44, 0.36, 0.28))


# ======================================================================================
#  Gameplay
# ======================================================================================

func _place_gameplay(root: Node3D) -> void:
	var gates: Array = []
	var s: float = 520.0
	var fin: float = lap.length - finish_runout
	while s < fin - 250.0:
		# Never on a bridge or a plank walk's first metres.
		var at: float = s
		while _on_bridge(lap, at, -20.0) or _on_ledge(at):
			at += 20.0
		gates.append(at)
		s = at + 520.0
	_checkpoints(gates)
	var pads: Array = []
	var k := 0
	for q in [260.0, 1150.0, 2050.0, 2900.0]:
		var at2: float = q
		while _on_bridge(lap, at2, -30.0) or _on_ledge(at2) or absf(float(lap.at(at2 + 60.0)["k"])) > 0.012:
			at2 += 15.0
		if at2 < fin - 200.0:
			pads.append(["Boost_%d" % (k + 1), at2, 0.0])
			k += 1
	_boosts(pads)


# ======================================================================================
#  Dressing
# ======================================================================================

func _build_dressing(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_base + 77
	_build_start(root, rng)
	_build_trailhead(root, rng)
	_build_bridges(root)
	_build_ledges(root)
	_build_wayside(root, rng)
	_build_summit(root, rng)
	_build_edges(root)
	_build_cloud(root)


## The start in the forest: a cedar torii over the trail, the pilgrims' lodge, lanterns, spectators.
func _build_start(root: Node3D, rng: RandomNumberGenerator) -> void:
	_build_start_crowd(root, start_s - 60.0, start_s + 70.0, road_half + 2.6, start_s - 8.0, start_s + 8.0, seed_base + 11)
	_logo_flag(root, start_s + 24.0, -(road_half + 15.0))
	var gx: Transform3D = _across(lap, start_s + 110.0)
	gx.origin.y -= 0.05
	_put("start_torii", prop_kit, gx, "torii", [2, 10.6, 7.4], 900.0)
	for side in [-1.0, 1.0]:
		var foot: Vector3 = gx.origin + gx.basis.x * side * 5.3 * PROP_SCALE
		_note_circle(Vector2(foot.x, foot.z), 2.5)
		var lx: Transform3D = _beside(lap, start_s + 98.0, side * (road_half + 3.0))
		_put("start_torii", prop_kit, lx, "stone_lantern", [0, 2.4], 900.0)
	var hx: Transform3D = _beside(lap, start_s - 20.0, road_half + 12.0)
	var gr: Vector2 = _ground_range(Vector2(hx.origin.x, hx.origin.z), 18.0, 14.0, 0.0)
	hx.origin.y = gr.y
	hx.origin -= hx.basis.x * 4.5 * PROP_SCALE
	if _put("lodge", town_kit, hx, "mountain_hut", [LBL], 900.0):
		_note_frame(hx, Vector2(-1.0, -7.5), Vector2(10.0, 1.5), 2.0)
	var mx: Transform3D = _beside(lap, start_s + 40.0, -(road_half + 3.0))
	_put("start_torii", prop_kit, mx, "stone_marker", [1.7, "OKUGAKE", LBL], 900.0)


## The trailhead's car park beside the valley road: a gravel lot (the road shader's forestry gravel, kind 4) with kei
## cars and trucks parked in two rows facing an aisle, drinks machines and a signboard at its entrance, people walking
## up to the start.
func _build_trailhead(root: Node3D, rng: RandomNumberGenerator) -> void:
	var r: Route = _route_by_name.get("ValleyRoad")
	if r == null:
		return
	# The lot's surface: across from PARK_LAT - PARK_HALF to + PARK_HALF, along PARK_S0..PARK_S1, level with the road.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lats: Array = [-PARK_HALF, -PARK_HALF * 0.5, 0.0, PARK_HALF * 0.5, PARK_HALF]
	var rows: int = ceili(PARK_S1 - PARK_S0)
	var vert := func(i: int, j: int) -> Vector3:
		var sv: float = lerpf(PARK_S0, PARK_S1, float(i) / float(rows))
		return r.pt(sv) + r.rt(sv) * (PARK_LAT + float(lats[j]))
	for i in range(rows):
		for j in range(lats.size() - 1):
			var quad: Array = [[i, j], [i, j + 1], [i + 1, j], [i + 1, j + 1]]
			for tri0 in [[0, 2, 1], [1, 2, 3]]:
				var va: Vector3 = vert.call(quad[tri0[0]][0], quad[tri0[0]][1])
				var vb: Vector3 = vert.call(quad[tri0[1]][0], quad[tri0[1]][1])
				var vc: Vector3 = vert.call(quad[tri0[2]][0], quad[tri0[2]][1])
				var tri: Array = tri0 if (vc - va).cross(vb - va).y > 0.0 else [tri0[0], tri0[2], tri0[1]]
				for kk in tri:
					var ii: int = quad[kk][0]
					var jj: int = quad[kk][1]
					st.set_normal(Vector3.UP)
					st.set_color(Color(1.0, 0.05, 0.0, 1.0))
					st.set_uv(Vector2(float(lats[jj]), lerpf(PARK_S0, PARK_S1, float(ii) / float(rows))))
					st.set_uv2(Vector2(4.0, PARK_HALF))
					st.add_vertex(vert.call(ii, jj))
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, _road_mat)
	var mi := MeshInstance3D.new()
	mi.name = "TrailheadParkingGround"
	mi.mesh = _save_res(mesh, "parking", stem + "trailhead_")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var mid_s: float = (PARK_S0 + PARK_S1) * 0.5
	var mid: Vector3 = r.pt(mid_s) + r.rt(mid_s) * PARK_LAT
	_note_rect(Vector2(mid.x, mid.z), PARK_HALF * 2.0 + 4.0, PARK_S1 - PARK_S0 + 4.0, atan2(-r.rt(mid_s).z, r.rt(mid_s).x), 2.0)
	# Two rows facing the aisle down the middle: the far row's noses toward the road, the near row's away from it.
	var cols: Array = [Color(0.93, 0.93, 0.90), Color(0.82, 0.86, 0.90), Color(0.20, 0.22, 0.25), Color(0.72, 0.12, 0.10), Color(0.55, 0.62, 0.48),
			Color(0.90, 0.80, 0.55), Color(0.30, 0.40, 0.62), Color(0.62, 0.62, 0.64)]
	var parked := 0
	for row in [[PARK_LAT + PARK_HALF - 4.6, -1.0], [PARK_LAT - PARK_HALF + 4.6, 1.0]]:
		var sv: float = PARK_S0 + 3.0
		while sv < PARK_S1 - 2.5:
			if rng.randf() < 0.72:
				var lat: float = float(row[0])
				var p: Vector3 = r.pt(sv) + r.rt(sv) * lat
				p.y = _ground_at(p.x, p.z)
				# Nose toward the aisle: -z is the nose, so +z faces away from it.
				var xf: Transform3D = _facing(r.rt(sv) * float(row[1]) * -1.0, p)
				xf = Transform3D(xf.basis.rotated(Vector3.UP, rng.randf_range(-0.04, 0.04)), xf.origin)
				if rng.randf() < 0.22:
					_put(_cell_key("carpark_cars", p), prop_kit, xf, "kei_truck", [cols[0] if rng.randf() < 0.7 else cols[1]], 900.0)
				else:
					_put(_cell_key("carpark_cars", p), prop_kit, xf, "kei_car", [cols[rng.randi() % cols.size()], rng.randf() < 0.25], 900.0)
				parked += 1
			sv += 3.4
	# Drinks machines and a signboard at the entrance, a toilet-hut's lantern post, people walking to the start.
	var ent: float = PARK_S0 + 1.5
	for k in range(2):
		var vp: Vector3 = r.pt(ent) + r.rt(ent) * (PARK_LAT - PARK_HALF + 2.0 + 1.6 * float(k))
		vp -= r.fw(ent) * 3.0
		vp.y = _ground_at(vp.x, vp.z)
		_put("tozanguchi", prop_kit, _facing(r.fw(ent), vp), "vending_machine", [k], 900.0)
	var mp: Vector3 = r.pt(ent) + r.rt(ent) * (r.half + 2.5) - r.fw(ent) * 5.0
	mp.y = _ground_at(mp.x, mp.z)
	_put("tozanguchi", prop_kit, _facing(-r.rt(ent), mp), "stone_marker", [1.8, "TOZANGUCHI", LBL], 900.0)
	for i in range(10):
		var sv2: float = rng.randf_range(4.0, PARK_S0 - 2.0)
		var pp: Vector3 = r.pt(sv2) + r.rt(sv2) * rng.randf_range(r.half + 1.5, r.half + 3.5)
		pp.y = _ground_at(pp.x, pp.z)
		_person(pp, r.fw(sv2) * -1.0, rng.randf_range(0.85, 1.05))
	print("  trailhead car park: %d cars" % parked)


## The gorge's two bridges: a suspension bridge low down, a timber trestle near its head; their sides solid. A bridge is
## straight and the trail curves round the mountain over the gorge, so each is laid along the chord between its ends,
## shifted and widened to hold the trail's whole width all the way across: laid along the trail's heading at its start,
## the trail ran off the deck and out past the netting toward its far end (the user saw the planks behind the railings).
## Its side colliders follow its own railings.
func _build_bridges(root: Node3D) -> void:
	var body: StaticBody3D = _body(root, "GorgeRailsBody")
	for i in range(_bridge_s.size()):
		var s0: float = _bridge_s[i][0]
		var s1: float = _bridge_s[i][1]
		var a: Vector3 = lap.pt(s0)
		var e: Vector3 = lap.pt(s1)
		var chord := Vector3(e.x - a.x, 0.0, e.z - a.z)
		var span: float = chord.length()
		var frame: Transform3D = _facing(-chord / span, a)
		# The trail's edges across the frame.
		var inv: Transform3D = frame.affine_inverse()
		var lo := INF
		var hi := -INF
		var s: float = s0
		while s <= s1:
			var x: float = (inv * lap.pt(s)).x
			lo = minf(lo, x - road_half)
			hi = maxf(hi, x + road_half)
			s += 1.0
		var shift: float = (lo + hi) * 0.5
		var hw: float = (hi - lo) * 0.5 + 0.1
		frame.origin += frame.basis.x * shift
		var o: Vector3 = frame.origin
		var deck := func(t: float) -> float: return lap.y(s0 + (s1 - s0) * clampf(t / span, 0.0, 1.0)) - a.y
		var ground := func(x: float, t: float) -> float:
			var p: Vector3 = frame * Vector3(x, 0.0, -t)
			return _ground_at(p.x, p.z) - o.y
		var fn: String = "suspension_bridge" if i == 0 else "road_bridge"
		var args: Array = [span, hw, deck, ground] if i == 0 else [span, hw, deck, ground, 0]
		_add_prop_game("gorge_span_%d" % i, river_kit, frame, func(pk: PropKit, kit: Dictionary, _labels: Array) -> void:
			_kit_call(river_kit, fn, [pk, kit] + args), 1500.0)
		for side in [-1.0, 1.0]:
			_bridge_side_boxes(body, frame, span, side * (hw + 0.3), deck, 1.7, 0.4)
		var mid: Vector3 = lap.pt((s0 + s1) * 0.5)
		print("  bridge %d: %.0fm at %.0fm (%.0f, %.0f, %.0f) toward (%.0f, %.0f), %.0fm over the gorge, the trail %.2fm to %.2fm across it (half width %.2f, shifted %.2f)" % [i, span, s0, o.x, o.y, o.z, e.x, e.z,
				lap.y((s0 + s1) * 0.5) - _ground_at(mid.x, mid.z), lo, hi, hw, shift])


## Solid sides along a straight bridge in `frame` (z = 0 to -span) at x = lat, `h` over its deck.
func _bridge_side_boxes(body: StaticBody3D, frame: Transform3D, span: float, lat: float, deck: Callable, h: float, thick: float) -> void:
	var t := -3.0
	while t < span + 3.0:
		var tb: float = minf(t + 6.0, span + 3.0)
		var pa: Vector3 = frame * Vector3(lat, float(deck.call(t)), -t)
		var pb: Vector3 = frame * Vector3(lat, float(deck.call(tb)), -tb)
		var l: float = pa.distance_to(pb)
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(thick, h + 0.6, l + 0.3)
		cs.shape = bx
		var fwd: Vector3 = (pb - pa) / l
		var x: Vector3 = Vector3.UP.cross(fwd).normalized()
		cs.transform = Transform3D(Basis(x, fwd.cross(x).normalized(), fwd).orthonormalized(), (pa + pb) * 0.5 + Vector3(0, h * 0.5 - 0.3, 0))
		body.add_child(cs)
		t = tb


## The plank walks: joists, struts and chains from the kit; a kerb and the chain solid on the valley side.
func _build_ledges(root: Node3D) -> void:
	var body: StaticBody3D = _body(root, "LedgeChainsBody")
	var ground := func(x: float, z: float) -> float: return _ground_at(x, z)
	for i in range(_ledge_s.size()):
		var s0: float = _ledge_s[i][0]
		var s1: float = _ledge_s[i][1]
		var pts := PackedVector3Array()
		var rights := PackedVector3Array()
		var s: float = s0
		while s <= s1:
			pts.append(lap.pt(s))
			rights.append(lap.rt(s))
			s += 2.0
		_add_prop_game("plank_walk_%d" % i, river_kit, Transform3D.IDENTITY, func(pk: PropKit, kit: Dictionary, _labels: Array) -> void:
			_kit_call(river_kit, "ledge_walk", [pk, kit, pts, rights, road_half, -1.0, ground]), 1200.0)
		_edge_boxes(body, lap, s0 - 2.0, s1 + 2.0, -(road_half + 0.3), 1.5, 0.4)


## Things along the way: statues, way-stones, cairns above the trees, small torii, a shrine at the cloud's edge.
func _build_wayside(root: Node3D, rng: RandomNumberGenerator) -> void:
	var s: float = 330.0
	var k := 0
	var fin: float = lap.length - finish_runout
	while s < minf(fin - 120.0, _s_foot - 70.0):
		if not _on_bridge(lap, s, -25.0) and not _on_ledge(s):
			var y: float = lap.y(s)
			var xf: Transform3D = _beside(lap, s, road_half + 3.4)
			var kind: int = k % 5
			if y > 190.0:
				_put(_cell_key("wayside", xf.origin), prop_kit, xf, "cairn", [rng, rng.randf_range(0.9, 1.5)], 400.0)
			elif kind == 0:
				_put(_cell_key("wayside", xf.origin), prop_kit, xf, "jizo_row", [rng.randi_range(3, 6), rng], 400.0)
			elif kind == 1:
				_put(_cell_key("wayside", xf.origin), prop_kit, xf, "stone_marker", [1.5, ["ICHI NO NABIKI", "NI NO NABIKI", "SAN NO NABIKI", "YON NO NABIKI"][(k / 5) % 4], LBL], 400.0)
			elif kind == 2:
				_put(_cell_key("wayside", xf.origin), prop_kit, xf, "stone_lantern", [0], 400.0)
			elif kind == 3:
				_put(_cell_key("wayside", xf.origin), prop_kit, xf, "hokora", [], 400.0)
			else:
				# A small torii over the trail.
				var tx: Transform3D = _across(lap, s)
				tx.origin.y -= 0.05
				_put(_cell_key("torii", tx.origin), prop_kit, tx, "torii", [0 if k % 2 == 0 else 2, 10.4, 7.2], 700.0)
				for side in [-1.0, 1.0]:
					var foot: Vector3 = tx.origin + tx.basis.x * side * 5.2 * PROP_SCALE
					_note_circle(Vector2(foot.x, foot.z), 2.5)
			_note_circle(Vector2(xf.origin.x, xf.origin.z), 2.5)
		s += rng.randf_range(150.0, 210.0)
		k += 1


## The summit (the user's idea, after two pictures: a vermilion hall and a five-storey pagoda on a terrace over the
## cloud), where the race ends (the user's: in front of the temple, driven up the stairs onto the plaza, the people at the
## sides). The trail turns off its spiral toward the summit, passes under a vermilion torii and climbs the great stair
## (`_build_great_stair`) onto the walled terrace; across it, between the crowd behind barriers either side, to the
## finish and the run-out's end before the main hall's steps. Round the terrace's rim a dry-stone wall and a vermilion
## fence, inside raked gravel and stone paths: the hall at the back facing the stair, the pagoda to its right, the bell
## tower on the left, the water pavilion by the gate, lanterns and banners behind the crowd, cherries, maples and pines,
## pilgrims; the old summit shrine (its SANJO post) on the dome beside the stair. Its frame `pf`: on the summit, +z toward
## the stair (the precinct's axis, `_axis`).
func _build_summit(root: Node3D, rng: RandomNumberGenerator) -> void:
	var toward := Vector3(_axis.x, 0.0, _axis.y)
	var pf: Transform3D = _facing(toward, Vector3(0.0, PRECINCT_Y, 0.0))
	var L := func(x: float, z: float) -> Vector3: return pf * Vector3(x, 0.0, z)
	var face := func(dx: float, dz: float, x: float, z: float) -> Transform3D: return _facing(pf.basis * Vector3(dx, 0.0, dz), pf * Vector3(x, 0.0, z))
	_build_great_stair(root, pf)
	_build_precinct_ground(root, pf)
	_build_precinct_rim(pf)
	# The buildings, clear of the run (the road's 7m and the crowd's 9.6-15m either side of the axis).
	_put("summit_hall", town_kit, face.call(0.0, 1.0, 0.0, HALL_Z), "summit_hall", [LBL], 3000.0)
	_put("summit_pagoda", town_kit, face.call(-1.0, 0.0, PAGODA.x, PAGODA.y), "pagoda", [5], 3500.0)
	_put("summit_court", town_kit, face.call(1.0, 0.0, BELL.x, BELL.y), "bell_tower", [], 1800.0)
	_put("summit_court", prop_kit, face.call(1.0, 0.0, -21.0, 31.0), "chozuya", [], 1200.0)
	_put("summit_court", town_kit, face.call(-1.0, 0.0, 30.0, -24.0), "shrine_hall", [LBL], 1500.0)
	_put("summit_court", prop_kit, face.call(-1.0, 0.0, 19.5, HALL_Z + 6.0), "ema_rack", [2.6], 900.0)
	for side in [-1.0, 1.0]:
		# Guardian lions at the hall's steps and at the stair's head; sake barrels and small shrines by the hall.
		_put("summit_court", prop_kit, face.call(0.0, 1.0, side * 9.2, HALL_Z + 5.2), "komainu", [side < 0.0], 1200.0)
		_put("summit_court", prop_kit, face.call(0.0, 1.0, side * 10.8, PRECINCT_R - 4.0), "komainu", [side < 0.0], 1200.0)
		_put("summit_court", prop_kit, face.call(0.0, 1.0, side * 14.0, HALL_Z + 1.0), "sake_barrels", [4, 3], 900.0)
		_put("summit_court", prop_kit, face.call(side * -1.0, 0.0, side * 32.0, -6.0), "hokora", [], 900.0)
	# Stone lanterns and banners lining the run behind the crowd.
	var cols: Array = [MK.VERMILION, Color(0.95, 0.94, 0.90), Color(0.16, 0.22, 0.45)]
	var k := 0
	for z in [35.0, 26.0, 17.0, 8.0, -1.0]:
		for side in [-1.0, 1.0]:
			_put("summit_court", prop_kit, face.call(side * -1.0, 0.0, side * 16.2, z), "stone_lantern", [0, 2.3], 1200.0)
			if z < 34.0:
				_put("summit_court", prop_kit, face.call(side * -1.0, 0.0, side * 18.2, z + 4.5), "nobori", [cols[k % 3], 4.6], 1200.0)
				k += 1
	# Benches at the rim looking out over the cloud.
	for ang in [70.0, 112.0, 248.0, 292.0]:
		var a: float = deg_to_rad(ang)
		var bp: Vector3 = L.call(sin(a) * (PRECINCT_R - 4.0), cos(a) * (PRECINCT_R - 4.0))
		_put("summit_court", prop_kit, _facing(Vector3(bp.x, 0.0, bp.z), bp), "red_bench", [false], 900.0)
	# Trees in the precinct.
	for t in [["sakura", -38.0, 2.0], ["sakura", 37.0, -8.0], ["sakura", -24.0, 33.0], ["sakura", 24.0, 33.0], ["momiji_red", -32.0, -14.0],
			["momiji_red", -26.0, -30.0], ["momiji_red", 22.0, -36.0], ["momiji_red", 37.0, 18.0], ["matsu", -36.0, 20.0]]:
		var tp: Vector3 = L.call(float(t[1]), float(t[2]))
		extra_trees.append([t[0], tp.x, tp.z, rng.randf_range(0.85, 1.05), rng.randi_range(0, 1)])
	_build_summit_slopes(pf, rng)
	_build_old_shrine(pf, rng)
	_build_finish_crowd(root, pf, rng)
	# Pilgrims round the pagoda and at the rim looking out.
	for i in range(18):
		var p := Vector3.ZERO
		var look := Vector3.ZERO
		if i % 2 == 0:
			var a2: float = rng.randf() * TAU
			p = Vector3(PAGODA.x, 0.0, PAGODA.y) + Vector3(cos(a2), 0.0, sin(a2)) * rng.randf_range(10.5, 12.5)
			look = Vector3(PAGODA.x, 0.0, PAGODA.y) - p
		else:
			var a3: float = deg_to_rad(rng.randf_range(60.0, 130.0) + (170.0 if rng.randf() < 0.5 else 0.0))
			p = Vector3(sin(a3), 0.0, cos(a3)) * rng.randf_range(39.0, 41.5)
			look = p
		if p.length() > PRECINCT_R - 2.0 or absf(p.x) < 16.5:
			continue
		_person(pf * p, pf.basis * look, rng.randf_range(0.88, 1.05))
	_note_circle(Vector2(0.0, 0.0), PRECINCT_R + 3.0)

## The pagoda's and the bell tower's places in the precinct's frame.
const PAGODA := Vector2(28.0, 6.0)
const BELL := Vector2(-27.0, 8.0)


## The great stair: granite treads across the run from its foot to the terrace's rim, each tread's nosing on the
## lap's line (the road's collision there is that ramp, K_STEPS; the cars ride the nosings), between ashlar cheek walls
## stepping up with it (solid, stone lanterns on them) that stand down to the ground either side: the stair rises out of
## a shallow cutting at its foot onto a causeway the terrace's height at its head. A great vermilion torii over its foot,
## a stone one at its head on the terrace.
func _build_great_stair(root: Node3D, pf: Transform3D) -> void:
	var pk: PropKit = MK.new_kit(1.0)
	var kit := {}
	var w: float = STAIR_HALF + 0.1
	var s: float = _s_foot
	var n := 0
	while s < _s_head - 0.05:
		var sb: float = minf(s + TREAD, _s_head)
		var p: Vector3 = lap.pt(s)
		var fwd: Vector3 = lap.fw(s)
		fwd.y = 0.0
		fwd = fwd.normalized()
		var right: Vector3 = lap.rt(s)
		# The tread's top is the road's height at its front edge (the nosing); it reaches back under the next one.
		var top: float = lap.y(s)
		var basis := Basis(right, Vector3.UP, -fwd)
		var c: Vector3 = Vector3(p.x, top - 0.6, p.z) + fwd * (sb - s + 0.3) * 0.5
		pk.box(kit, "ishi", Transform3D(basis, c), Vector3(w * 2.0, 1.2, sb - s + 0.3), MK.GRANITE.lerp(MK.GRANITE_MOSSY, 0.22 if n % 4 == 0 else 0.07), 1.0)
		s = sb
		n += 1
	# The cheek walls, a level parapet every four treads, down past the ground beside them.
	var body: StaticBody3D = _body(root, "GreatStairWallsBody")
	var lanterns := 0
	for side in [-1.0, 1.0]:
		var k: float = _s_foot - 2.0
		var seg := 0
		while k < _s_head + 0.4:
			var kb: float = minf(k + TREAD * 4.0, _s_head + 0.4)
			var lat: float = side * (STAIR_HALF + CHEEK * 0.5)
			var a: Vector3 = lap.pt(k) + lap.rt(k) * lat
			var b: Vector3 = lap.pt(kb) + lap.rt(kb) * lat
			var top2: float = maxf(lap.y(k), lap.y(kb)) + 0.75
			var lo: float = INF
			for q in [a, b]:
				for out in [0.0, 2.5]:
					var g: Vector3 = q + lap.rt(k) * side * out
					lo = minf(lo, _ground_at(g.x, g.z))
			var bottom: float = minf(lo, minf(lap.y(k), lap.y(kb))) - 1.2
			var mid: Vector3 = (a + b) * 0.5
			var fwd2: Vector3 = Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
			var bs := Basis(Vector3.UP.cross(fwd2).normalized(), Vector3.UP, fwd2)
			var ln: float = Vector2(b.x - a.x, b.z - a.z).length() + 0.04
			var wall := Transform3D(bs, Vector3(mid.x, (top2 + bottom) * 0.5, mid.z))
			pk.box(kit, "ishi", wall, Vector3(CHEEK, top2 - bottom, ln), MK.GRANITE.darkened(0.06), 1.0)
			pk.box(kit, "ishi", Transform3D(bs, Vector3(mid.x, top2 + 0.09, mid.z)), Vector3(CHEEK + 0.16, 0.18, ln + 0.02), MK.GRANITE.lightened(0.04), 1.0)
			_box_shape(body, wall, Vector3(CHEEK, top2 - bottom, ln))
			if seg % 2 == 1 and kb < _s_head - 2.0:
				_put("stair_lanterns", prop_kit, Transform3D(Basis(), Vector3(mid.x, top2 + 0.18, mid.z)), "stone_lantern", [0, 1.7], 1200.0)
				lanterns += 1
			k = kb
			seg += 1
	var mi := MeshInstance3D.new()
	mi.name = "GreatStair"
	mi.mesh = _save_res(MK.commit(pk, kit), "great_stair", stem + "prop_")
	mi.set_meta(&"skip_dressing_colliders", true)
	root.add_child(mi)
	print("  the great stair: %d treads, %d lanterns on its walls" % [n, lanterns])
	# The torii: vermilion over the foot, stone at the head on the terrace (their pillars clear of the run's 7m).
	var tx: Transform3D = _across(lap, _s_foot - 3.0)
	tx.origin.y -= 0.05
	_put("summit_stair", prop_kit, tx, "torii", [0, 10.6, 9.0], 2500.0)
	var hx: Transform3D = _facing(-pf.basis.z, pf * Vector3(0.0, 0.0, PRECINCT_R - 2.4))
	hx.origin.y = PRECINCT_Y - 0.05
	_put("summit_stair", prop_kit, hx, "torii", [1, 10.6, 8.2], 2500.0)
	for t in [tx, hx]:
		for sd in [-1.0, 1.0]:
			var foot: Vector3 = t.origin + t.basis.x * sd * 5.3 * PROP_SCALE
			_note_circle(Vector2(foot.x, foot.z), 2.0)
	# Lanterns either side of the foot, outside the walls.
	for sd in [-1.0, 1.0]:
		var lx: Transform3D = _beside(lap, _s_foot - 6.0, sd * (STAIR_HALF + CHEEK + 3.0))
		_put("summit_stair", prop_kit, _facing(-lap.rt(_s_foot) * sd, lx.origin), "stone_lantern", [0, 2.6], 1200.0)
	# The stair keeps everything else off it.
	var c2: Vector3 = (lap.pt(_s_foot) + lap.pt(_s_head)) * 0.5
	_note_rect(Vector2(c2.x, c2.z), (STAIR_HALF + CHEEK) * 2.0 + 4.0, _s_head - _s_foot + 6.0, atan2(_axis.x, _axis.y), 1.0)


## The old summit shrine (the stage's first summit, which the user liked) on the dome beside the stair, facing it: its
## rock, the SANJO post, cairns and pilgrims round it.
func _build_old_shrine(pf: Transform3D, rng: RandomNumberGenerator) -> void:
	var sh: Vector3 = pf * Vector3(-30.0, 0.0, 74.0)
	sh.y = _ground_at(sh.x, sh.z)
	var to_stair: Vector3 = pf.basis * Vector3(1.0, 0.0, -0.25)
	_put("summit_shrine", prop_kit, _facing(to_stair, sh), "summit_shrine", [LBL, "SANJO"], 1500.0)
	_note_circle(Vector2(sh.x, sh.z), 8.0)
	for i in range(10):
		var a: float = rng.randf() * TAU
		var p: Vector3 = sh + Vector3(cos(a), 0, sin(a)) * rng.randf_range(7.0, 15.0)
		if _route_dist(p.x, p.z) < road_half + 6.0 or (p - sh).dot(to_stair) > 2.0:
			continue
		p.y = _ground_at(p.x, p.z)
		_person(p, sh - p, rng.randf_range(0.9, 1.05))
		_put("summit_shrine", prop_kit, Transform3D(Basis(), p + Vector3(2.0, 0, 1.0)), "cairn", [rng, 0.8], 600.0)


## The crowd: behind barriers either side of the run across the terrace (a gap at the finish gantry's posts), at the
## approach under the torii, and along the terrace's rim either side of the stair's head looking down it.
func _build_finish_crowd(root: Node3D, pf: Transform3D, rng: RandomNumberGenerator) -> void:
	var s_fin: float = lap.length - finish_runout
	_build_start_crowd(root, _s_head + 5.5, lap.length - 0.5, road_half + 2.6, s_fin - 8.0, s_fin + 8.0, seed_base + 21, [-1.0, 1.0],
			"Finish", [0.08, 0.2, 0.4], 2)
	_build_start_crowd(root, _s_foot - 26.0, _s_foot - 6.0, road_half + 2.6, -1.0, -1.0, seed_base + 23, [-1.0, 1.0], "StairFoot")
	var watch: Vector3 = pf * Vector3(0.0, 0.0, PRECINCT_R + 22.0)
	var n := 0
	for side in [-1.0, 1.0]:
		var a: float = deg_to_rad(17.0)
		while a < deg_to_rad(44.0):
			for row in range(2):
				if rng.randf() < 0.2:
					continue
				var rr: float = PRECINCT_R - 1.6 - float(row) * 1.4 - rng.randf_range(0.0, 0.5)
				var lp := Vector3(side * sin(a) * rr, 0.0, cos(a) * rr)
				var wp: Vector3 = pf * lp
				wp.y = PRECINCT_Y
				var look: Vector3 = (watch - wp)
				look.y = 0.0
				_person(wp, look, rng.randf_range(0.9, 1.07), false, -1, rng.randf() < 0.15)
				n += 1
			a += deg_to_rad(2.2)
	print("  %d spectators on the rim over the stair" % n)


var _precinct_mat: ShaderMaterial

## The roads' material with the precinct's gravel warmer (sand-coloured, as the pictures had it).
func _precinct_material() -> ShaderMaterial:
	if _precinct_mat == null:
		var m: ShaderMaterial = _road_mat.duplicate()
		m.set_shader_parameter("precinct_gravel", Color(0.78, 0.73, 0.62))
		_precinct_mat = _save_res(m, "precinct_material", stem + "precinct_") as ShaderMaterial
	return _precinct_mat


## The terrace's surface: raked gravel (the road shader's kind 5, its rake lines in rings round the summit) out to the
## wall's coping, and stone paths (kind 1) from the run (the lap's own paving, from the stair's head to the hall) across
## to the pagoda and the bell tower. Drawn only: the ground under them is the terrace.
func _build_precinct_ground(root: Node3D, pf: Transform3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r1: float = PRECINCT_R - 0.96
	var rings: int = ceili(r1 / 1.5)
	var segs := 160
	var gy: float = PRECINCT_Y + 0.03
	var vtx := func(ri: int, si: int) -> Array:
		var r: float = r1 * float(ri) / float(rings)
		var a: float = TAU * float(si) / float(segs)
		return [Vector3(cos(a) * r, gy, sin(a) * r), Vector2(r, a * r1)]
	for ri in range(rings):
		for si in range(segs):
			var q: Array = [vtx.call(ri, si), vtx.call(ri, si + 1), vtx.call(ri + 1, si), vtx.call(ri + 1, si + 1)]
			for tri in [[0, 1, 2], [1, 3, 2]]:
				# Clockwise from above (Godot's front faces).
				var a3: Vector3 = q[tri[0]][0]
				var b3: Vector3 = q[tri[1]][0]
				var c3: Vector3 = q[tri[2]][0]
				var order: Array = tri if (c3 - a3).cross(b3 - a3).y > 0.0 else [tri[0], tri[2], tri[1]]
				for kk in order:
					st.set_normal(Vector3.UP)
					st.set_color(Color(1.0, 0.12, 0.0, 1.0))
					st.set_uv(q[kk][1])
					st.set_uv2(Vector2(5.0, r1))
					st.add_vertex(q[kk][0])
	# The paths, 3cm over the gravel.
	var py: float = PRECINCT_Y + 0.06
	for path in [[Vector2(road_half + 0.4, PAGODA.y), Vector2(PAGODA.x - 9.4, PAGODA.y), 1.6],
			[Vector2(-road_half - 0.4, BELL.y), Vector2(BELL.x + 4.3, BELL.y), 1.6]]:
		var p0: Vector3 = pf * Vector3((path[0] as Vector2).x, 0.0, (path[0] as Vector2).y)
		var p1: Vector3 = pf * Vector3((path[1] as Vector2).x, 0.0, (path[1] as Vector2).y)
		var dirv: Vector3 = (p1 - p0)
		var ln: float = dirv.length()
		dirv /= ln
		var right: Vector3 = Vector3.UP.cross(dirv).normalized() * -1.0
		var hw: float = path[2]
		for i in range(ceili(ln / 2.0)):
			var t0: float = minf(float(i) * 2.0, ln)
			var t1: float = minf(float(i + 1) * 2.0, ln)
			var corners: Array = [[t0, -hw], [t0, hw], [t1, -hw], [t1, hw]]
			for tri in [[0, 2, 1], [1, 2, 3]]:
				var pa: Vector3 = p0 + dirv * float(corners[tri[0]][0]) + right * float(corners[tri[0]][1])
				var pb: Vector3 = p0 + dirv * float(corners[tri[1]][0]) + right * float(corners[tri[1]][1])
				var pc: Vector3 = p0 + dirv * float(corners[tri[2]][0]) + right * float(corners[tri[2]][1])
				var order2: Array = tri if (pc - pa).cross(pb - pa).y > 0.0 else [tri[0], tri[2], tri[1]]
				for kk in order2:
					var tt: float = corners[kk][0]
					var lv: float = corners[kk][1]
					st.set_normal(Vector3.UP)
					st.set_color(Color(1.0, 0.12, 0.0, 1.0))
					st.set_uv(Vector2(lv, tt))
					st.set_uv2(Vector2(1.0, hw))
					var v: Vector3 = p0 + dirv * tt + right * lv
					st.add_vertex(Vector3(v.x, py, v.z))
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, _precinct_material())
	var mi := MeshInstance3D.new()
	mi.name = "SummitPrecinctGround"
	mi.mesh = _save_res(mesh, "gravel", stem + "precinct_")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


## The terrace's rim: a dry-stone wall round it (open where the stair comes up) and a vermilion fence on its coping.
func _build_precinct_rim(pf: Transform3D) -> void:
	# The wall and fence end at the stair's cheek walls.
	var gap_w: float = STAIR_HALF + CHEEK + 0.05
	var drop_life: float = TERRACE_DROP / PROP_SCALE
	for ring in [[PRECINCT_R, "wall"], [PRECINCT_R - 0.55, "fence"]]:
		var r: float = ring[0]
		var gap_a: float = asin(clampf(gap_w / r, 0.0, 0.9))
		var a0: float = gap_a
		var a1: float = TAU - gap_a
		var n: int = ceili((a1 - a0) * r / (5.0 if ring[1] == "wall" else 4.0))
		for i in range(n):
			var aa: float = lerpf(a0, a1, float(i) / float(n))
			var ab: float = lerpf(a0, a1, float(i + 1) / float(n))
			var pa: Vector3 = pf * Vector3(sin(aa) * r, 0.0, cos(aa) * r)
			var pb: Vector3 = pf * Vector3(sin(ab) * r, 0.0, cos(ab) * r)
			if ring[1] == "wall":
				var am: float = (aa + ab) * 0.5
				var out: Vector3 = pf.basis * Vector3(sin(am), 0.0, cos(am))
				_put_world("summit_wall", pa, prop_kit, "ishigaki", [_life(pa), _life(pb), out, drop_life], 2500.0)
			else:
				_put_world("summit_fence", pa, prop_kit, "koran", [_life(pa), _life(pb), 1.0], 1500.0)


## The dome round the terrace: cherries, maples and pines scattered on the grass, off the trail and the approach.
func _build_summit_slopes(pf: Transform3D, rng: RandomNumberGenerator) -> void:
	var placed := 0
	for i in range(140):
		var a: float = rng.randf() * TAU
		var r: float = rng.randf_range(PRECINCT_R + 7.0, 105.0)
		var lp := Vector3(sin(a) * r, 0.0, cos(a) * r)
		# Not on the stair, its walls or the approach.
		if lp.z > 30.0 and absf(lp.x) < 24.0:
			continue
		var wp: Vector3 = pf * lp
		if _route_dist(wp.x, wp.z) < road_half + 9.0 or _occupied(wp.x, wp.z):
			continue
		var roll: float = rng.randf()
		var kind: String = "sakura" if roll < 0.35 else ("momiji_red" if roll < 0.55 else ("momiji" if roll < 0.62 else ("matsu" if roll < 0.85 else "sugi")))
		var sc: float = rng.randf_range(0.75, 1.0) if kind != "sugi" else rng.randf_range(0.6, 0.85)
		extra_trees.append([kind, wp.x, wp.z, sc, rng.randi_range(0, 1)])
		_note_circle(Vector2(wp.x, wp.z), 4.0)
		placed += 1
		if placed >= 34:
			break
	print("  summit slopes: %d trees" % placed)


## Chain fences along the valley side wherever the ground falls away (the same test as the guardrails'), solid.
func _build_edges(root: Node3D) -> void:
	var skip: Array = []
	for l in _ledge_s:
		skip.append([float(l[0]) - 6.0, float(l[1]) + 6.0])
	var body: StaticBody3D = _body(root, "TrailChainsBody")
	var s: float = 150.0
	var run0 := -1.0
	var n := 0
	while s < _s_foot - 4.0:
		var bad := false
		if not _on_bridge(lap, s, -6.0):
			var p: Vector3 = lap.pt(s) - lap.rt(s) * (road_half + 9.0)
			bad = lap.y(s) - _ground_at(p.x, p.z) > 3.2
			for sk in skip:
				if s > float(sk[0]) and s < float(sk[1]):
					bad = false
		if bad and run0 < 0.0:
			run0 = s
		elif not bad and run0 >= 0.0:
			if s - run0 > 14.0:
				var k: float = run0
				while k < s - 0.5:
					var kb: float = minf(k + 9.0, s)
					var a: Vector3 = lap.pt(k) - lap.rt(k) * (road_half + 0.9)
					var b: Vector3 = lap.pt(kb) - lap.rt(kb) * (road_half + 0.9)
					_put_world("chains", a, prop_kit, "chain_fence", [_life(a), _life(b)], 500.0)
					k = kb
					n += 1
				_edge_boxes(body, lap, run0, s, -(road_half + 0.9), 1.3, 0.4)
			run0 = -1.0
		s += 4.0
	print("  chain fences: %d pieces" % n)


## The cloud: the sea of it below the upper mountain, the script that closes the fog in by the camera's height, and
## wisps blowing across the open trail above it.
func _build_cloud(root: Node3D) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://cloud_sea.gdshader")
	var plane := PlaneMesh.new()
	plane.size = Vector2(12000.0, 12000.0)
	plane.subdivide_width = 8
	plane.subdivide_depth = 8
	plane.material = _save_res(mat, "cloud_sea_material")
	var sea := MeshInstance3D.new()
	sea.name = "CloudSea"
	sea.mesh = plane
	sea.position = Vector3(0, CLOUD_HIGH - 6.0, 0)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(sea)
	var cl := Node.new()
	cl.name = "CloudLayer"
	cl.set_script(load("res://CloudLayer.gd"))
	cl.set("band_low", CLOUD_LOW)
	cl.set("band_high", CLOUD_HIGH)
	root.add_child(cl)
	var pg := Node3D.new()
	pg.name = "PetalGusts"
	pg.set_script(load("res://PetalGusts.gd"))
	pg.set("mist", true)
	pg.set("falling", 0)
	pg.set("push_accel", 12.0)
	var spots: Array = []
	var s: float = 0.0
	var k := 0
	while s < lap.length - 150.0:
		if lap.y(s) > CLOUD_HIGH + 25.0 and not _on_ledge(s) and not _on_bridge(lap, s, -10.0):
			# The wind comes up the mountain: from the valley side across the trail.
			spots.append([lap.pt(s), lap.rt(s), 24.0, 15.0 + float(k % 3) * 3.0, float(k) * 4.1])
			s += 230.0
			k += 1
		else:
			s += 20.0
	pg.set("spots", spots)
	root.add_child(pg)
	print("  %d gust places above the cloud" % spots.size())
