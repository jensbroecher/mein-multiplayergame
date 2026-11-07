# regenerate_zeche.gd
#
# Builds levels/ZecheLevel.tscn - Zeche Kronprinz, the third stage of the Kronburg GP: an off-road stage through the
# fictional colliery Zeche Kronprinz (Schacht I's Malakoff tower, Schacht II's steel headframe, the Lohnhalle, closed
# 1986, now industrial heritage), the still-working Kokerei Kronprinz next door and the colliery's spoil heap (the
# Halde), early on a misty summer morning. The lap starts on the old colliery yard heading east, runs under the coal
# washer (Kohlenwäsche), along the coke oven battery past the quench tower, climbs the Halde's haul ramp onto its
# plateau past the summit landmark, jumps off the plateau's north end and runs down the flank, swings west through the
# birch scrub (Industriewald) across the colliery railway, south past and through the settling ponds (Klärteiche), over
# the railway again and back onto the yard.
#
# Things worth knowing before editing this file:
#
# 1. There is no road mesh: the lap is the ground itself, graded flat across the track (`_grade`), its triangles one
#    body, KohlenTrack (track, surface dirt; the yard's ZechenplatzTrack gravel), the rest off-road (spoil, slag,
#    meadow). zeche_ground.gdshader paints the track from the distance to it (UV2.x) as compacted dirt with ruts,
#    gravel and puddles; the vertex colour carries the masks (R spoil, G the works' ground, B the track, A woods).
# 2. The lap is straights and arcs (CORNERS, filleted); its height is designed (`_design_y`): the base ground smoothed
#    along it, the Halde's haul ramp (HALDE_RAMP), its plateau and the descent off its north end (HALDE_DROP), where a
#    timber kicker (HaldenSprung) throws the carts down the slope.
# 3. The colliery railway (Zechenbahn, the polyline RAIL) crosses the lap twice, nearly square: FreightKit's track, Freight Line's
#    Train.gd (a shunter with coal hoppers on a timetable of its own, `legs`) and RailCrossing.gd; a train destroys a
#    cart it touches and the bots wait at a closed crossing.
# 4. Props come from ZechenKit and KokereiKit (and stage 1's SteelworksKit, KronburgTownKit, CampKit): life size,
#    grown by PROP_SCALE, batched into one mesh per key and cell under PROP_PREFIX (DressingColliders makes them solid).
#
# The generator runs headless and cannot render; scratch/lap_shots.tscn renders the lap.
extends Node

const LEVEL_NAME := "ZecheLevel"
const LEVEL_PATH := "res://levels/ZecheLevel.tscn"
const RES_PREFIX := "zeche_"
const PROP_PREFIX := "zecheprop_"
const MeshChunker = preload("res://MeshChunker.gd")
const PropKit = preload("res://PropKit.gd")
const YardKit = preload("res://YardKit.gd")
const CampKit = preload("res://CampKit.gd")
const CrowdPlacer = preload("res://CrowdPlacer.gd")
const FreightKit = preload("res://FreightKit.gd")

const MESH_CHUNK_CELL := 80.0
const PROP_SCALE := 1.6

## The track's half width (the flat, drivable band); the ground is graded flat a little wider.
const ROAD_HALF := 8.0
const SAMPLE_STEP := 3.0
const CELL := 32.0
const GRADE_REACH := 60.0

## The lap's corners: [point (x, z), fillet radius]. x east, z south.
const CORNERS := [
	[Vector2(560.0, 0.0), 50.0],       # 0 past the Kokerei: left, north onto the Halde's haul ramp
	[Vector2(560.0, -780.0), 60.0],    # 1 below the Halde's north end: left, west through the scrub
	[Vector2(250.0, -780.0), 70.0],    # 2 left, south-west
	[Vector2(110.0, -660.0), 70.0],    # 3 right, west again, over the railway
	[Vector2(-250.0, -660.0), 50.0],   # 4 left, south past the settling ponds
	[Vector2(-250.0, 0.0), 50.0],      # 5 left, east over the railway onto the yard
]

# ---- The colliery yard (the start), the coal washer, the Kokerei along the lap's first straight.
const YARD_RECT := [-170.0, -70.0, 160.0, 70.0]
const YARD_Y := 1.0
const FINISH_X := -30.0
const WASHER_X := 205.0
const BATTERY_X0 := 300.0
## The Kokerei's ground (no woods, the works' slag and concrete).
const WORKS_RECT := [170.0, -170.0, 720.0, 90.0]
## Where the works' ground is painted (the washer, the Kokerei and its by-product plant): WORKS_RECT is only graded.
const WORKS_PAINT := [175.0, -205.0, 530.0, 30.0]

# ---- The Halde: a capsule of spoil along x = HALDE_X from HALDE_Z0 to HALDE_Z1 (its plateau, HALDE_R wide each side at
# HALDE_Y), flanks of HALDE_SLOPE; the lap climbs its haul ramp from the south and leaves off its north end.
const HALDE_X := 560.0
const HALDE_Z0 := -345.0
const HALDE_Z1 := -500.0
const HALDE_R := 48.0
const HALDE_Y := 36.0
const HALDE_SLOPE := 0.52
## The haul ramp: the lap's height from 0 at RAMP_Z0 up to the plateau at HALDE_Z0 (12%).
const RAMP_Z0 := -45.0
## The descent: the kicker's lip at JUMP_LIP_Z, the slope down to the foot at DROP_Z1.
const JUMP_LIP_Z := -506.0
const DROP_Z1 := -712.0
const SUMMIT_AT := Vector2(604.0, -425.0)

# ---- The settling ponds (Klärteiche): [centre, half extents, water level]; the lap fords the east one's shallows.
const PONDS := [[Vector2(-275.0, -470.0), Vector2(68.0, 55.0)], [Vector2(-445.0, -440.0), Vector2(75.0, 70.0)]]
const POND_DEPTH := 0.45
const POND_DEEP := 1.6

# ---- The colliery railway: from the loading bunker in the west, east past the yard's north side (crossing the lap's
# west leg square), round a bend and north (crossing the scrub's leg square) off to the main line.
const RAIL := [[Vector2(-720.0, -118.0), 0.0], [Vector2(-20.0, -160.0), 150.0], [Vector2(0.0, -1380.0), 0.0]]
## The loading bunker this far along the line from its west end.
const BUNKER_S := 140.0

# ---- The terrain grid.
const FINE_X := Vector2(-760.0, 960.0)
const FINE_Z := Vector2(-1080.0, 420.0)
const FINE_STEP := 4.0
const OUTER := 6000.0
const COARSE_GROWTH := 1.16
const COARSE_MAX := 180.0

var level: Node3D
var segs: Array = []
var lap_len := 0.0
var _road_y := PackedFloat32Array()

var _noise := FastNoiseLite.new()
var _land_noise := FastNoiseLite.new()
var _forest_noise := FastNoiseLite.new()
var _gully_noise := FastNoiseLite.new()

var _seg_a := PackedVector3Array()
var _seg_b := PackedVector3Array()
var _seg_flat := PackedFloat32Array()
var _seg_lap := PackedByteArray()
var _seg_cells := {}

var _grid_x := PackedFloat32Array()
var _grid_z := PackedFloat32Array()
var _heights := PackedFloat32Array()
var _road_d := PackedFloat32Array()
var _ground_mat: ShaderMaterial

var _batches := {}
var _saved_mats := {}
var _missing := {}
var _occ := {}
var _camp_mats := {}
var _puff_tex: Texture2D
var _people: Array = []
## Rail crossings: [{pos, lap_s, rail_s, road_y}].
var _crossings: Array = []
var _rail_y := PackedFloat32Array()


# ======================================================================================
#  The designed heights
# ======================================================================================

## The base country: a gentle swell, the yard and the Kokerei level.
func _base(x: float, z: float) -> float:
	var h: float = 1.2 * _land_noise.get_noise_2d(x, z) + 0.6 * _noise.get_noise_2d(x * 2.0, z * 2.0)
	# Rising gently to the north-west and to wooded hills far off.
	h += smoothstep(1400.0, 5500.0, Vector2(x, z).length()) * 40.0 * (0.6 + 0.4 * _land_noise.get_noise_2d(z * 0.2, x * 0.2))
	return h


## Distance outside the Halde's plateau (a capsule along x = HALDE_X); negative inside.
func _halde_d(x: float, z: float) -> float:
	var zc: float = clampf(z, HALDE_Z1, HALDE_Z0)
	return Vector2(x - HALDE_X, z - zc).length() - HALDE_R


func _halde(x: float, z: float) -> float:
	var d: float = _halde_d(x, z)
	if d <= 0.0:
		return HALDE_Y + 0.6 * _noise.get_noise_2d(x * 1.5, z * 1.5)
	# The flanks, scored by erosion gullies (deeper half way down).
	var g: float = absf(_gully_noise.get_noise_2d(x, z))
	var h: float = HALDE_Y - d * HALDE_SLOPE
	h -= (1.0 - smoothstep(0.0, 0.25, g)) * 1.6 * smoothstep(0.0, 18.0, d) * smoothstep(HALDE_Y / HALDE_SLOPE, HALDE_Y / HALDE_SLOPE * 0.6, d)
	return h


func _raw_natural(x: float, z: float) -> float:
	var h: float = _base(x, z)
	h = lerpf(h, YARD_Y, _rect_weight(x, z, YARD_RECT, 30.0))
	h = maxf(h, _halde(x, z))
	# The settling ponds: basins with low dams round them.
	for p in PONDS:
		var c: Vector2 = p[0]
		var he: Vector2 = p[1]
		var q := Vector2(absf(x - c.x) / he.x, absf(z - c.y) / he.y)
		var r: float = q.length()
		var dam: float = 1.2 * (1.0 - smoothstep(0.0, 0.18, absf(r - 1.08)))
		var basin: float = (1.0 - smoothstep(0.82, 1.0, r)) * (POND_DEEP + 0.6)
		h = h + dam - basin
	return h


func _natural(x: float, z: float) -> float:
	return _raw_natural(x, z)


## The water level of a pond (its rim's base level less a little).
func _pond_level(i: int) -> float:
	var c: Vector2 = PONDS[i][0]
	return _base(c.x, c.y) - 0.4


func _plan_road_heights() -> void:
	var n: int = int(ceil(lap_len)) + 1
	var raw := PackedFloat32Array()
	raw.resize(n)
	for i in range(n):
		var p: Vector2 = _at(float(i))["p"]
		raw[i] = _base(p.x, p.y)
		if _in_rect(p.x, p.y, YARD_RECT, 10.0):
			raw[i] = YARD_Y
	# Smoothed along the lap (a box of 31m twice).
	var cur := raw
	for pass_i in range(2):
		var out := PackedFloat32Array()
		out.resize(n)
		for i in range(n):
			var acc := 0.0
			for k in range(-15, 16):
				acc += cur[(i + k + n * 4) % n]
			out[i] = acc / 31.0
		cur = out
	# The Halde (the lap's first straight, north along HALDE_X): the haul ramp at a steady grade, the plateau, the descent.
	var y0: float = 0.0
	for i in range(n):
		var p0: Vector2 = _at(float(i))["p"]
		if _seg_index(float(i)) == 0 and p0.y <= RAMP_Z0:
			y0 = cur[i]
			break
	for i in range(n):
		var s: float = float(i)
		var p: Vector2 = _at(s)["p"]
		if _seg_index(s) != 0:
			continue
		var z: float = p.y
		if z <= RAMP_Z0 and z > HALDE_Z0:
			cur[i] = lerpf(y0, HALDE_Y, (RAMP_Z0 - z) / (RAMP_Z0 - HALDE_Z0))
		elif z <= HALDE_Z0 and z >= JUMP_LIP_Z:
			cur[i] = HALDE_Y + 0.6 * sin((z - HALDE_Z0) / (JUMP_LIP_Z - HALDE_Z0) * PI)
		elif z < JUMP_LIP_Z and z > DROP_Z1:
			cur[i] = _hermite(z, JUMP_LIP_Z, HALDE_Y, 0.0, DROP_Z1, cur[i], 0.0)
	# The ford: through the east settling pond's shallows the track dips POND_DEPTH under its water, easing in and out.
	var lvl: float = minf(_pond_level(0), _pond_level(1))
	var c0: Vector2 = PONDS[0][0]
	var he0: Vector2 = PONDS[0][1]
	for i in range(n):
		var p3: Vector2 = _at(float(i))["p"]
		var r: float = Vector2((p3.x - c0.x) / he0.x, (p3.y - c0.y) / he0.y).length()
		var w: float = 1.0 - smoothstep(0.55, 1.25, r)
		cur[i] = lerpf(cur[i], minf(cur[i], lvl - POND_DEPTH), w)
	# Ease the ramp's foot and top (the linear ramp joins the flat with a short vertical curve), then a light smoothing
	# everywhere but on the plateau's edge where the kicker stands.
	var sm := cur.duplicate()
	for i in range(n):
		var p2: Vector2 = _at(float(i))["p"]
		if _seg_index(float(i)) == 0 and p2.y < HALDE_Z0 + 5.0 and p2.y > JUMP_LIP_Z - 5.0:
			continue
		var acc2 := 0.0
		for k in range(-6, 7):
			acc2 += cur[(i + k + n * 4) % n]
		sm[i] = acc2 / 13.0
	_road_y = sm
	var steep := 0.0
	var at := 0.0
	for i in range(n - 1):
		var g: float = absf(_road_y[i + 1] - _road_y[i])
		if g > steep:
			steep = g
			at = float(i)
	print("  lap %.0fm, road from %.1f to %.1fm, steepest %.1f%% at %.0fm" % [lap_len, _min(_road_y), _max(_road_y), steep * 100.0, at])


# ======================================================================================
#  The grading (every road segment: the lap, the railway's bed) and the terrain
# ======================================================================================

func _add_samples() -> void:
	var s := 0.0
	while s < lap_len:
		var s2: float = minf(s + SAMPLE_STEP, lap_len)
		_add_seg(_pt(s), _pt(s2), ROAD_HALF + 2.0, true)
		s = s2


## The ground graded to the lap: level with it across its flat band, then rounded shoulders out to the natural ground.
## Returns the height and the distance to the lap's centreline.
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
				var foot_y: float = lerpf(a.y, b.y, t)
				var flat: float = _seg_flat[i]
				var over: float = maxf(0.0, lateral - flat)
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


func _lap_dist(x: float, z: float) -> float:
	var cx: int = floori(x / CELL)
	var cz: int = floori(z / CELL)
	var best := 1e18
	for gz in range(cz - 2, cz + 3):
		for gx in range(cx - 2, cx + 3):
			var bucket: PackedInt32Array = _seg_cells.get(Vector2i(gx, gz), PackedInt32Array())
			for i in bucket:
				var a: Vector3 = _seg_a[i]
				var b: Vector3 = _seg_b[i]
				var sx: float = b.x - a.x
				var sz: float = b.z - a.z
				var l2: float = maxf(sx * sx + sz * sz, 1e-6)
				var t: float = clampf(((x - a.x) * sx + (z - a.z) * sz) / l2, 0.0, 1.0)
				var fx: float = x - (a.x + sx * t)
				var fz: float = z - (a.z + sz * t)
				best = minf(best, fx * fx + fz * fz)
	return sqrt(best) if best < 1e17 else 1e9


func _init_noise() -> void:
	_noise.seed = 6301
	_noise.frequency = 0.008
	_noise.fractal_octaves = 3
	_land_noise.seed = 6302
	_land_noise.frequency = 0.0025
	_land_noise.fractal_octaves = 3
	_forest_noise.seed = 6303
	_forest_noise.frequency = 0.006
	_forest_noise.fractal_octaves = 3
	_gully_noise.seed = 6304
	_gully_noise.frequency = 0.045
	_gully_noise.fractal_type = FastNoiseLite.FRACTAL_NONE


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
			var g: Vector2 = _grade(h, x, z)
			_heights[i] = g.x
			_road_d[i] = minf(g.y, 1.0e7)


## Woods: the birch scrub (Industriewald) round the ponds and between the railway and the Halde, copses elsewhere.
func _forest_w(x: float, z: float) -> float:
	var f: float = _forest_noise.get_noise_2d(x, z)
	var w: float = smoothstep(0.12, 0.36, f + 0.1)
	# Thicker in the north-west quarter (the scrub on the old sidings), thin on the Halde's flanks.
	w = maxf(w, smoothstep(-0.1, 0.2, f) * (1.0 - smoothstep(-200.0, 0.0, z + x * 0.3)) * 0.9)
	if _halde_d(x, z) < 70.0:
		w *= 0.35
	return w


func _open_land(x: float, z: float) -> float:
	var yard: float = _rect_weight(x, z, YARD_RECT, 12.0)
	var works: float = _rect_weight(x, z, WORKS_RECT, 15.0)
	var ponds := 0.0
	for p in PONDS:
		var c: Vector2 = p[0]
		var he: Vector2 = p[1]
		ponds = maxf(ponds, 1.0 - smoothstep(1.0, 1.3, Vector2((x - c.x) / he.x, (z - c.y) / he.y).length()))
	return (1.0 - yard) * (1.0 - works) * (1.0 - ponds)


func _masks(i: int, x: float, z: float, nrm_y: float) -> Color:
	var road_d: float = _road_d[i]
	var h: float = _heights[i]
	var track: float = 1.0 - smoothstep(ROAD_HALF - 0.5, ROAD_HALF + 1.8, road_d)
	var hd: float = _halde_d(x, z)
	var spoil: float = 1.0 - smoothstep(HALDE_Y / HALDE_SLOPE - 4.0, HALDE_Y / HALDE_SLOPE + 10.0, hd)
	# Bare spoil on steep ground anywhere (the ramp's and descent's embankments).
	spoil = maxf(spoil, (1.0 - smoothstep(0.7, 0.85, nrm_y)) * 0.9)
	# The works' slag and slabs cover only where the plant stands (WORKS_PAINT), their edge wandering on noise, so from
	# the air they are no rectangle: the graded pad beyond (WORKS_RECT) is meadow gone back to grass.
	var wx: float = x + 22.0 * _noise.get_noise_2d(x * 0.6 + 400.0, z * 0.6)
	var wz: float = z + 22.0 * _noise.get_noise_2d(x * 0.6, z * 0.6 - 300.0)
	var works: float = maxf(_rect_weight(x, z, YARD_RECT, 10.0), _rect_weight(wx, wz, WORKS_PAINT, 16.0))
	# Coal dust along the railway and round the bunker.
	var rd: float = _rail_dist(x, z)
	works = maxf(works, 1.0 - smoothstep(6.0, 16.0, rd))
	var forest: float = _forest_w(x, z) * _open_land(x, z) * smoothstep(12.0, 26.0, road_d)
	for p in PONDS:
		var c: Vector2 = p[0]
		var he: Vector2 = p[1]
		if Vector2((x - c.x) / he.x, (z - c.y) / he.y).length() < 1.15:
			spoil = maxf(spoil, 0.5)
	return Color(spoil * (1.0 - track), works * (1.0 - track) * (1.0 - spoil * 0.5), track, forest * (1.0 - track) * (1.0 - spoil * 0.7))


func _rail_dist(x: float, z: float) -> float:
	if _rail_pts.is_empty():
		return 1e9
	# Coarse first (every 10th sample), then the neighbours of the best.
	var q := Vector2(x, z)
	var best := 1e18
	var bi := 0
	var i := 0
	while i < _rail_pts.size():
		var d: float = _rail_pts[i].distance_squared_to(q)
		if d < best:
			best = d
			bi = i
		i += 10
	for k in range(maxi(bi - 10, 0), mini(bi + 11, _rail_pts.size())):
		best = minf(best, _rail_pts[k].distance_squared_to(q))
	return sqrt(best)


const BODIES := [
	["KohlenTrack", "dirt", Color(0.36, 0.31, 0.26, 0.6)],
	["ZechenplatzTrack", "gravel", Color(0.34, 0.33, 0.32, 0.55)],
	["HaldenGrund", "gravel", Color(0.30, 0.28, 0.27, 0.6)],
	["ZechenGrund", "gravel", Color(0.28, 0.27, 0.27, 0.6)],
	["ZechenWiese", "grass", Color(0, 0, 0, 0)],
]


func _build_terrain(parent: Node3D) -> void:
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
			verts[i] = Vector3(x, _heights[i], z)
			uvs[i] = Vector2(x, z)
			uv2s[i] = Vector2(minf(_road_d[i], 99.0), 0.0)
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
				var tk: float = (colors[tri[0]].b + colors[tri[1]].b + colors[tri[2]].b) / 3.0
				var sp: float = (colors[tri[0]].r + colors[tri[1]].r + colors[tri[2]].r) / 3.0
				var wk: float = (colors[tri[0]].g + colors[tri[1]].g + colors[tri[2]].g) / 3.0
				var k: int = 4
				if tk > 0.5:
					k = 1 if _in_rect(cen.x, cen.z, YARD_RECT, -4.0) else 0
				elif sp > 0.5:
					k = 2
				elif wk > 0.5:
					k = 3
				var f: PackedVector3Array = faces[k]
				f.append(p0)
				f.append(p1)
				f.append(p2)
				faces[k] = f
	var near_mesh: ArrayMesh = _compact_mesh2(verts, normals, colors, uvs, uv2s, near_idx, _ground_mat)
	var inst := MeshInstance3D.new()
	inst.name = "ZecheGroundMesh"
	inst.mesh = _save_res(near_mesh, "ground_visual")
	parent.add_child(inst)
	var far_mesh: ArrayMesh = _compact_mesh2(verts, normals, colors, uvs, uv2s, far_idx, _ground_mat)
	var far_inst := MeshInstance3D.new()
	far_inst.name = "ZecheFarGround"
	far_inst.mesh = _save_res(far_mesh, "far_ground", "zechefar_")
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
		print("  %s: %d triangles" % [BODIES[k][0], f.size() / 3])
	print("  ground: %d near and %d far triangles" % [near_idx.size() / 3, far_idx.size() / 3])


func _compact_mesh2(verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, uvs: PackedVector2Array,
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


# ======================================================================================
#  The settling ponds
# ======================================================================================

func _build_ponds(root: Node3D) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://still_water.gdshader")
	mat.set_shader_parameter("water_color", Color(0.035, 0.045, 0.040, 1.0))
	mat.set_shader_parameter("sky_tint", Color(0.62, 0.64, 0.66, 1.0))
	mat.set_shader_parameter("sky_reflect", 0.55)
	mat.set_shader_parameter("ripple_tile", 18.0)
	mat.set_shader_parameter("ripple_strength", 0.08)
	var noise_tex := NoiseTexture2D.new()
	noise_tex.seamless = true
	noise_tex.as_normal_map = true
	noise_tex.width = 256
	noise_tex.height = 256
	var nz := FastNoiseLite.new()
	nz.frequency = 0.02
	noise_tex.noise = nz
	mat.set_shader_parameter("noise_tex", noise_tex)
	var smat: Material = _save_res(mat, "pond_water_material")
	# One water node (PlayerCart takes the first "...Water"): both ponds at one level, the box round both.
	var lvl: float = minf(_pond_level(0), _pond_level(1))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for p in PONDS:
		var c: Vector2 = p[0]
		var he: Vector2 = (p[1] as Vector2) * 1.12
		lo = Vector2(minf(lo.x, c.x - he.x), minf(lo.y, c.y - he.y))
		hi = Vector2(maxf(hi.x, c.x + he.x), maxf(hi.y, c.y + he.y))
		var n := 48
		for k in range(n):
			var a0: float = TAU * float(k) / float(n)
			var a1: float = TAU * float(k + 1) / float(n)
			var pa := Vector3(c.x + cos(a0) * he.x, 0.0, c.y + sin(a0) * he.y)
			var pb := Vector3(c.x + cos(a1) * he.x, 0.0, c.y + sin(a1) * he.y)
			var pc := Vector3(c.x, 0.0, c.y)
			# Clockwise from above (Godot's front face): pc, pa, pb faces up; the other way round it was culled.
			for v in [pc, pa, pb]:
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(v.x, v.z))
				st.add_vertex(v)
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, smat)
	var water := MeshInstance3D.new()
	water.name = "KlaerteichWater"
	water.mesh = _save_res(mesh, "pond_water", "zechefar_")
	water.position = Vector3(0, lvl, 0)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.set_meta(&"water_surface_y", lvl)
	water.set_meta(&"water_bounds_min", lo)
	water.set_meta(&"water_bounds_max", hi)
	root.add_child(water)
	print("  ponds at %.2fm" % lvl)


# ======================================================================================
#  The colliery railway: track, the shunter and its hoppers on a timetable, the two crossings
# ======================================================================================

const RAIL_STEP := 3.0
const RAIL_LIFT := 0.55
const DECK_HALF_LEN := 9.0
const DECK_HALF_W := 3.2
const RAIL_SURFACE_SKIP := 13.0
## The shunter and its coal hoppers, out and back. RAIL_SPEED and the short stands (RAIL_STANDS: before the run out, at
## the far end, home) bring it past a crossing about every lap: at 13 m/s with long stands it came once in about six
## minutes, and the user never met it in a race.
const RAIL_CONSIST := ["~loco:2", "hopper", "hopper:1", "hopper", "hopper", "hopper:1", "hopper", "hopper"]
const RAIL_SPEED := 19.0
const RAIL_STANDS := [6.0, 10.0, 8.0]

var _rail_segs: Array = []
var _rail_total := 0.0
var _rail_pts := PackedVector2Array()

func _plan_rail() -> void:
	var fp: Array = _fillet_path(RAIL, false)
	_rail_segs = fp[0]
	_rail_total = fp[1]
	_rail_pts.clear()
	var s := 0.0
	while s <= _rail_total:
		_rail_pts.append(_rail_at(s))
		s += 2.0


func _rail_len() -> float:
	return _rail_total


func _rail_at(s: float) -> Vector2:
	return _seg_at(_rail_segs, clampf(s, 0.0, _rail_total))["p"]


func _rail_dir(s: float) -> Vector2:
	return _dir_of(float(_seg_at(_rail_segs, clampf(s, 0.0, _rail_total))["th"]))


## The nearest point of the railway to q: [distance, s along the line].
func _rail_nearest(q: Vector2) -> Vector2:
	var best := 1e18
	var bi := 0
	for i in range(_rail_pts.size()):
		var d: float = _rail_pts[i].distance_squared_to(q)
		if d < best:
			best = d
			bi = i
	return Vector2(sqrt(best), float(bi) * 2.0)


## Where the lap crosses the railway: the lap's s and the rail's s.
func _find_crossings() -> void:
	_crossings.clear()
	var prev_side := 0.0
	var prev_near := false
	var s := 0.0
	while s <= lap_len:
		var p: Vector2 = _at(s)["p"]
		var nr: Vector2 = _rail_nearest(p)
		var dir: Vector2 = _rail_dir(nr.y)
		var side: float = (p - _rail_at(nr.y)).dot(Vector2(-dir.y, dir.x))
		var near: bool = nr.x < 12.0
		if near and prev_near and signf(side) != signf(prev_side) and nr.y > 4.0 and nr.y < _rail_total - 4.0:
			var rs: float = nr.y
			_crossings.append({"pos": p, "lap_s": s, "rail_s": rs, "road_y": _lap_y(s)})
		prev_side = side
		prev_near = near
		s += 1.0
	print("  railway crossings: %s" % str(_crossings.map(func(c): return "lap %.0fm, rail %.0fm, angle %.0f deg" % [c["lap_s"], c["rail_s"], rad_to_deg(acos(absf(_rail_dir(c["rail_s"]).dot(_dir_of(float(_at(c["lap_s"])["th"]))))))])))


## The rail's top along the line: the ground smoothed, level with the lap at the crossings.
func _plan_rail_heights() -> void:
	var n: int = int(ceil(_rail_len() / RAIL_STEP)) + 1
	var raw := PackedFloat32Array()
	raw.resize(n)
	for i in range(n):
		var p: Vector2 = _rail_at(float(i) * RAIL_STEP)
		raw[i] = _base(p.x, p.y) + RAIL_LIFT
	var cur := raw
	for pass_i in range(3):
		var out := PackedFloat32Array()
		out.resize(n)
		for i in range(n):
			var acc := 0.0
			var cnt := 0
			for k in range(-8, 9):
				var j: int = clampi(i + k, 0, n - 1)
				acc += cur[j]
				cnt += 1
			out[i] = acc / float(cnt)
		cur = out
	for c in _crossings:
		var rs: float = c["rail_s"]
		var ry: float = float(c["road_y"]) + 0.08
		for i in range(n):
			var d: float = absf(float(i) * RAIL_STEP - rs)
			var w: float = 1.0 - smoothstep(14.0, 60.0, d)
			cur[i] = lerpf(cur[i], ry, w)
	_rail_y = cur


func _rail_top(s: float) -> float:
	var f: float = clampf(s / RAIL_STEP, 0.0, float(_rail_y.size() - 1))
	var i: int = mini(int(f), _rail_y.size() - 2)
	return lerpf(_rail_y[i], _rail_y[i + 1], f - float(i))


## The railway's bed is graded like a road (its own segments, a narrow flat band).
func _add_rail_samples() -> void:
	var s := 0.0
	var len_r: float = _rail_len()
	while s < len_r:
		var s2: float = minf(s + 6.0, len_r)
		var a: Vector2 = _rail_at(s)
		var b: Vector2 = _rail_at(s2)
		_add_seg(Vector3(a.x, _rail_top(s) - RAIL_LIFT, a.y), Vector3(b.x, _rail_top(s2) - RAIL_LIFT, b.y), 3.4, false)
		s = s2


func _near_crossing(s: float, reach: float) -> bool:
	for c in _crossings:
		if absf(float(c["rail_s"]) - s) < reach:
			return true
	return false


func _build_railway(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Zechenbahn"
	root.add_child(node)
	var len_r: float = _rail_len()
	var n: int = int(floor(len_r / RAIL_STEP)) + 1
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	var pts: Array = []
	for k in range(n):
		var s: float = minf(float(k) * RAIL_STEP, len_r)
		var p: Vector2 = _rail_at(s)
		var v := Vector3(p.x, _rail_top(s), p.y)
		curve.add_point(v)
		pts.append(v)
	var faces: Array = []
	FreightKit.solid_sink = []
	var piece: Array = []
	var bed: Array = []
	var piece_no := 0
	for k in range(n):
		piece.append(pts[k])
		if piece.size() > 1:
			var mid_s: float = (float(k) - 0.5) * RAIL_STEP
			bed.append(not _near_crossing(mid_s, DECK_HALF_LEN + 1.5))
		if piece.size() > 32:
			var mi := MeshInstance3D.new()
			mi.name = "Gleisbett_%d" % piece_no
			mi.mesh = FreightKit.track_piece(piece, bed, piece_no, faces, pts[maxi(k - 33, 0)] if piece_no > 0 else null, pts[mini(k + 1, n - 1)])
			mi.visibility_range_end = 1600.0
			node.add_child(mi)
			piece_no += 1
			piece = [pts[k]]
			bed = []
	if piece.size() > 1:
		var mi2 := MeshInstance3D.new()
		mi2.name = "Gleisbett_%d" % piece_no
		mi2.mesh = FreightKit.track_piece(piece, bed, piece_no, faces, null, null)
		node.add_child(mi2)
	# The bed's hump and the rails and sleepers themselves are solid (not over the crossings' decks).
	var tris = FreightKit.solid_sink
	FreightKit.solid_sink = null
	var surf := PackedVector3Array()
	if tris is Array:
		var arr: Array = tris
		for i in range(0, arr.size() - 2, 3):
			var a: Vector3 = arr[i]
			var b: Vector3 = arr[i + 1]
			var c: Vector3 = arr[i + 2]
			var m := Vector2((a.x + b.x + c.x) / 3.0, (a.z + b.z + c.z) / 3.0)
			var skip := false
			for cr in _crossings:
				if m.distance_to(cr["pos"]) < RAIL_SURFACE_SKIP:
					skip = true
			if not skip:
				surf.append_array([a, b, c])
	for pair in [["RailSurface_Zechenbahn", surf], ["RailBed_Zechenbahn", PackedVector3Array(faces)]]:
		var f: PackedVector3Array = pair[1]
		if f.is_empty():
			continue
		var body := StaticBody3D.new()
		body.name = pair[0]
		body.set_meta(&"surface", "gravel")
		body.set_meta(&"dust_color", Color(0.30, 0.29, 0.28, 0.5))
		node.add_child(body)
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(f)
		shape.backface_collision = true
		var cs := CollisionShape3D.new()
		cs.name = "Shape"
		cs.shape = _save_res(shape, String(pair[0]).to_snake_case() + "_shape")
		body.add_child(cs)
	# The shunter and its hoppers: pulls out from the bunker, runs to the line's far end, stands, comes back (backing up),
	# stands under the bunker. A timetable of its own (Train.gd `legs`): [start, end, from, to, ramp] per leg.
	var train := Node3D.new()
	train.name = "ZechenbahnTrain"
	train.set_script(load("res://Train.gd"))
	train.set("path", curve)
	train.set("consist", PackedStringArray(RAIL_CONSIST))
	train.set("speed", RAIL_SPEED)
	var head_home: float = BUNKER_S + 70.0
	var head_far: float = len_r - 10.0
	var run_t: float = (head_far - head_home) / RAIL_SPEED + 6.0
	var s0: float = RAIL_STANDS[0]
	var s1: float = RAIL_STANDS[1]
	var s2: float = RAIL_STANDS[2]
	var legs := PackedFloat32Array([s0, s0 + run_t, head_home, head_far, 6.0,
		s0 + run_t + s1, s0 + run_t * 2.0 + s1, head_far, head_home, 6.0])
	train.set("legs", legs)
	var period: float = s0 + run_t * 2.0 + s1 + s2
	train.set("period", period)
	node.add_child(train)
	print("  Zechenbahn: %.0fm, the train out and back every %.0fs" % [len_r, period])
	# The crossings: a planked deck, the barriers and lights (RailCrossing.gd).
	var ci := 0
	for c in _crossings:
		ci += 1
		var sp: Dictionary = _spot(float(c["lap_s"]), 0.0, 0.0)
		var rd2: Vector2 = _rail_dir(float(c["rail_s"]))
		var rail_dir3 := Vector3(rd2.x, 0.0, rd2.y)
		var skew: float = maxf(absf(rail_dir3.dot(sp["right"])), 0.5)
		var deck := MeshInstance3D.new()
		deck.name = "Bahnuebergang%d" % ci
		deck.mesh = _save_res(FreightKit.crossing_deck(Vector3(sp["pos"].x, float(c["road_y"]) + 0.08, sp["pos"].z), rail_dir3, DECK_HALF_LEN / skew, DECK_HALF_W), "crossing_deck_%d" % ci)
		node.add_child(deck)
		# The deck is solid at its mats' height: the ground dips under the rails there, and carts sank into the mats.
		var deck_body := StaticBody3D.new()
		deck_body.name = "BahnuebergangDeck%d" % ci
		deck_body.set_meta(&"surface", "asphalt")
		var dcs := CollisionShape3D.new()
		var dbx := BoxShape3D.new()
		dbx.size = Vector3(DECK_HALF_W * 2.0, 0.6, DECK_HALF_LEN / skew * 2.0)
		dcs.shape = dbx
		var across := Vector3(rail_dir3.z, 0.0, -rail_dir3.x)
		dcs.transform = Transform3D(Basis(across, Vector3.UP, rail_dir3), Vector3(sp["pos"].x, float(c["road_y"]) + 0.03 - 0.3, sp["pos"].z))
		deck_body.add_child(dcs)
		node.add_child(deck_body)
		var cn := Node3D.new()
		cn.name = "RailCrossing%d" % ci
		cn.set_script(load("res://RailCrossing.gd"))
		cn.position = sp["pos"]
		cn.rotation_degrees = Vector3(0, sp["yaw"], 0)
		cn.set("train_paths", PackedStringArray(["../ZechenbahnTrain"]))
		cn.set("train_s", float(c["rail_s"]))
		cn.set("road_half", ROAD_HALF)
		node.add_child(cn)
	var rumble := Node3D.new()
	rumble.name = "RailRumble"
	rumble.set_script(load("res://RailRumble.gd"))
	var lines: Array[PackedVector3Array] = [PackedVector3Array(pts)]
	rumble.set("lines", lines)
	node.add_child(rumble)


# ======================================================================================
#  Gameplay: the start, the gates, boost pads, the Halde's kicker
# ======================================================================================

func _place_gameplay(root: Node3D) -> void:
	var gate_scene: PackedScene = load("res://CheckpointGate.tscn")
	var spawn_scene: PackedScene = load("res://SpawnIndicator.tscn")
	var s_fin: float = _closest_s(Vector2(FINISH_X, 0.0))
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
	# Gates: up the haul ramp, on the plateau, the scrub, before the ford, by the ponds, past the Kokerei.
	var at: Array = [
		_closest_s(Vector2(HALDE_X, -200.0)),
		_closest_s(Vector2(HALDE_X, -420.0)),
		_closest_s(Vector2(380.0, -780.0)),
		_closest_s(Vector2(-60.0, -660.0)),
		_closest_s(Vector2(-250.0, -330.0)),
		_closest_s(Vector2(380.0, 0.0)),
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
		["Boost_Rampe", _closest_s(Vector2(HALDE_X, -120.0)), 0.0],
		["Boost_Plateau", _closest_s(Vector2(HALDE_X, -440.0)), 0.0],
		["Boost_Gestruepp", _closest_s(Vector2(400.0, -780.0)), -2.6],
		["Boost_Zechenplatz", _closest_s(Vector2(-160.0, 0.0)), 2.6],
	]
	for p in pads:
		var b = boost_scene.instantiate()
		b.name = p[0]
		var sp2: Dictionary = _spot(p[1], p[2], 0.08)
		b.position = sp2["pos"]
		b.rotation_degrees = Vector3(0, sp2["yaw"], 0)
		bps.add_child(b)
	_build_jump(root)


## The Halde's kicker at the plateau's north edge: a timber ramp as wide as the track, launching the carts down the
## descent's slope.
const JUMP := [16.0, 2.4, 0.4]

func _build_jump(root: Node3D) -> void:
	var toe: float = _closest_s(Vector2(HALDE_X, JUMP_LIP_Z + float(JUMP[0])))
	var j: Node3D = (load("res://WoodenRamp.tscn") as PackedScene).instantiate()
	j.name = "HaldenSprung"
	var sp: Dictionary = _spot(toe, 0.0, 0.0)
	j.position = sp["pos"]
	j.rotation_degrees = Vector3(0, sp["yaw"], 0)
	j.set("length", JUMP[0])
	j.set("height", JUMP[1])
	j.set("curve", JUMP[2])
	j.set("width", ROAD_HALF * 2.0)
	j.set("trestle", true)
	j.set("wood_color", Color(0.42, 0.36, 0.30))
	root.add_child(j)
	var lp: Dictionary = _spot(toe + float(JUMP[0]), 0.0, 0.0)
	var slope: float = float(JUMP[1]) / float(JUMP[0]) * (1.0 + float(JUMP[2]))
	var lip: Vector3 = (lp["pos"] as Vector3) + Vector3(0, float(JUMP[1]), 0)
	(root.get_node("TrackPath") as Node).set_meta(&"jump_lips", [{"name": "HaldenSprung", "lip": lip, "dir": ((lp["fwd"] as Vector3) + Vector3(0, slope, 0)).normalized()}])


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
#  Sky and light: an early summer morning, mist over the Halde, the sun low in the east-north-east
# ======================================================================================

const HAZE := Color(0.84, 0.83, 0.80)

func _build_environment(root: Node3D) -> void:
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://sky_tropical_cumulus.gdshader")
	sky_mat.set_shader_parameter("sky_top", Color(0.36, 0.52, 0.76))
	sky_mat.set_shader_parameter("sky_horizon", Color(0.90, 0.86, 0.80))
	sky_mat.set_shader_parameter("ground_horizon", HAZE)
	sky_mat.set_shader_parameter("ground_bottom", Color(0.46, 0.46, 0.44))
	sky_mat.set_shader_parameter("sky_curve", 0.5)
	sky_mat.set_shader_parameter("horizon_haze", HAZE)
	sky_mat.set_shader_parameter("haze_strength", 1.0)
	sky_mat.set_shader_parameter("haze_height", 0.18)
	sky_mat.set_shader_parameter("sun_tint", Color(1.0, 0.88, 0.70))
	sky_mat.set_shader_parameter("sun_disc_degrees", 1.1)
	sky_mat.set_shader_parameter("sun_glow", 0.6)
	sky_mat.set_shader_parameter("sun_horizon_tint", Color(1.0, 0.80, 0.58))
	sky_mat.set_shader_parameter("sun_horizon_glow", 0.3)
	sky_mat.set_shader_parameter("cloud_lit", Color(1.0, 0.96, 0.90))
	sky_mat.set_shader_parameter("cloud_shade", Color(0.64, 0.64, 0.70))
	sky_mat.set_shader_parameter("cloud_coverage", 0.30)
	sky_mat.set_shader_parameter("cloud_opacity", 0.85)
	sky_mat.set_shader_parameter("cloud_scale", 1.3)
	sky_mat.set_shader_parameter("cloud_seed", 47.1)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.55
	env.ambient_light_color = Color(0.92, 0.92, 0.92)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.06
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = HAZE
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.35
	env.fog_density = 1.0
	env.fog_depth_begin = 140.0
	env.fog_depth_end = 2600.0
	env.fog_depth_curve = 1.25
	env.fog_sky_affect = 0.08
	env.fog_aerial_perspective = 0.35
	env_node.environment = env
	root.add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	# An early morning: the sun in the east-north-east, about 20 degrees up.
	sun.rotation_degrees = Vector3(-20.0, 72.0, 0.0)
	sun.light_color = Color(1.0, 0.88, 0.72)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 320.0
	sun.directional_shadow_split_1 = 0.08
	sun.directional_shadow_split_2 = 0.22
	sun.directional_shadow_split_3 = 0.5
	root.add_child(sun)


func _ready() -> void:
	print("=== Zeche Kronprinz (Kronburg GP) Level Generation ===")
	var t_start: int = Time.get_ticks_msec()
	var gen := DirAccess.open("res://generated/")
	if gen:
		var cleared := 0
		for f in gen.get_files():
			if f.begins_with("zeche") and (f.ends_with(".res") or f.ends_with(".tscn")):
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
	_plan_rail()
	var fp: Array = _fillet_path(CORNERS, true)
	segs = fp[0]
	lap_len = fp[1]
	_plan_road_heights()
	var track_path := Path3D.new()
	track_path.name = "TrackPath"
	track_path.curve = _build_main_curve()
	level.add_child(track_path)
	_find_crossings()
	_plan_rail_heights()
	_add_samples()
	_add_rail_samples()
	_build_heights()
	print("  heights built (%.1fs)" % ((Time.get_ticks_msec() - t_start) / 1000.0))

	var gm := ShaderMaterial.new()
	gm.shader = load("res://zeche_ground.gdshader")
	gm.set_shader_parameter("grass_tex", load("res://materials/grass.png"))
	gm.set_shader_parameter("dirt_tex", load("res://materials/dirt.png"))
	gm.set_shader_parameter("dirt_normal", load("res://materials/dirt_normal.png"))
	gm.set_shader_parameter("rock_tex", load("res://materials/dark_rock.png"))
	gm.set_shader_parameter("gravel_tex", load("res://materials/dark_canyon_rock.png"))
	gm.set_shader_parameter("gravel_normal", load("res://materials/dark_canyon_rock_normal.png"))
	gm.set_shader_parameter("concrete_tex", load("res://materials/concrete.png"))
	gm.set_shader_parameter("track_half", ROAD_HALF)
	_ground_mat = _save_res(gm, "ground_material") as ShaderMaterial
	var terrain := Node3D.new()
	terrain.name = "ZecheTerrain"
	level.add_child(terrain)
	_build_terrain(terrain)
	print("  terrain built (%.1fs)" % ((Time.get_ticks_msec() - t_start) / 1000.0))
	_build_ponds(terrain)
	_build_railway(level)
	_build_environment(level)
	_place_gameplay(level)
	_build_dressing(level)

	level.set("track_path", track_path)
	# A four-seat touring plane on sightseeing loops over the stage (LightPlane.gd, fitted round the lap at runtime).
	load("res://LightPlane.gd").add_to(level, "Rundflug", 3.1, false)
	level._setup_checkpoints()
	var chunked: int = MeshChunker.chunk_scene(level, "res://generated/" + RES_PREFIX, "res://generated/zeche_chunks", MESH_CHUNK_CELL)
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

var _zechen_kit: Script
var _kokerei_kit: Script
var _works: Script
var _town: Script

func _build_dressing(root: Node3D) -> void:
	_zechen_kit = _kit_script("res://ZechenKit.gd")
	_kokerei_kit = _kit_script("res://KokereiKit.gd")
	_works = load("res://SteelworksKit.gd")
	_town = load("res://KronburgTownKit.gd")
	_build_start(root)
	_build_colliery(root)
	_build_kokerei(root)
	_build_halde_dressing(root)
	CrowdPlacer.build(root, _people, SPECTATOR_SCALE, SPECTATOR_SKIN, 9321, func(res: Resource, n: String) -> Resource: return _save_res(res, n, "zechecrowd_"))
	_flush_batches(root)
	_build_sounds(root)
	_build_scrub_plants(root)
	_build_woods(root)


# ======================================================================================
#  The colliery: Schacht I's Malakoff tower, Schacht II's headframe and winding house, the Lohnhalle, the coal washer
#  over the lap, the conveyor galleries, the loading bunker on the railway (ZechenKit)
# ======================================================================================

const MALAKOFF_AT := Vector2(-75.0, -112.0)
const HEADFRAME_AT := Vector2(70.0, -118.0)
## The winding engine houses stand this far either side of the headframe along its rope plane (z).
const WINDING_OFF := 64.0
const LOHNHALLE_AT := Vector2(-10.0, 96.0)

func _place(key: String, script: Script, at: Vector2, face: Vector3, fn: String, args: Array, range_end := 2400.0, lift := 0.0) -> Transform3D:
	var p := Vector3(at.x, _ground_at(at.x, at.y) + lift, at.y)
	var xf := _facing(face, p)
	if script != null:
		_add_prop(key, script, xf, func(pk, kit, labels):
			var a: Array = [pk, kit]
			for v in args:
				a.append(labels if (v is String and v == "@labels") else v)
			_kit_call(script, fn, a), range_end)
	return xf


func _build_colliery(root: Node3D) -> void:
	var zk: Script = _zechen_kit
	if zk == null:
		return
	_place("malakoff", zk, MALAKOFF_AT, Vector3(0, 0, 1), "malakoff_tower", ["@labels"], 4000.0)
	_note_rect(MALAKOFF_AT, 32.0, 32.0, 0.0)
	var hf: Transform3D = _place("schacht2", zk, HEADFRAME_AT, Vector3(0, 0, 1), "headframe", ["@labels"], 5000.0)
	_note_rect(HEADFRAME_AT, 40.0, 52.0, 0.0)
	# Schacht II's two winding engines, one each side of the headframe along its rope plane, their rope gables (-z)
	# toward it; the ropes from the sheaves' tops to their inlets.
	var ropes: Array = []
	for side in [1.0, -1.0]:
		var variant: int = 0 if side > 0.0 else 1
		var at := Vector2(HEADFRAME_AT.x, HEADFRAME_AT.y + side * WINDING_OFF)
		var wxf: Transform3D = _place("foerdermaschine_%d" % variant, zk, at, Vector3(0, 0, side), "winding_house", ["@labels", variant], 3000.0)
		_note_rect(at, 30.0, 52.0, 0.0)
		if _has_fn(zk, "headframe_rope_exits") and _has_fn(zk, "winding_house_rope_inlets"):
			var ex: Array = zk.headframe_rope_exits()
			var exit: Vector3 = hf * (((ex[0][0] if side > 0.0 else ex[1][0]) as Vector3) * PROP_SCALE)
			for inl in zk.winding_house_rope_inlets(variant):
				ropes.append([exit + hf.basis.x * (0.25 if (inl as Vector3).x > 0.0 else -0.25), wxf * ((inl as Vector3) * PROP_SCALE)])
	for r in ropes:
		var a: Vector3 = r[0]
		var b: Vector3 = r[1]
		_add_prop_game("seile", _works, Transform3D(), func(pk, kit, _l): _kit_call(_works, "_pipe", [pk, kit, "steel", [a, b], 0.06, Color(0.18, 0.18, 0.18), 6, 0.0, false]), 1500.0)
	_place("lohnhalle", zk, LOHNHALLE_AT, Vector3(0, 0, -1), "lohnhalle", ["@labels"], 3000.0)
	_note_rect(LOHNHALLE_AT, 150.0, 34.0, 0.0)
	# The headframe's sheaves turn slowly (a museum's display).
	if _has_fn(zk, "headframe_sheave") and _has_fn(zk, "headframe_sheave_hubs"):
		for hub in zk.headframe_sheave_hubs():
			var piv := Node3D.new()
			piv.name = "Seilscheibe%d" % root.get_child_count()
			piv.set_script(load("res://Spinner.gd"))
			piv.transform = Transform3D(hf.basis, hf * ((hub as Vector3) * PROP_SCALE))
			piv.set("axis", Vector3(1, 0, 0))
			piv.set("degrees_per_second", 9.0)
			root.add_child(piv)
			var sm := MeshInstance3D.new()
			sm.name = "Sheave"
			sm.mesh = _kit_mesh_life(zk, "sheave", func(pk, kit): zk.headframe_sheave(pk, kit))
			sm.scale = Vector3.ONE * PROP_SCALE
			piv.add_child(sm)
	# The coal washer over the lap (its passage along the lap: the kit's z along world +x).
	_place("kohlenwaesche", zk, Vector2(WASHER_X, 0.0), Vector3(1, 0, 0), "coal_washer", ["@labels"], 4000.0)
	_note_rect(Vector2(WASHER_X, 0.0), 58.0, 70.0, 0.0)
	# The loading bunker on the railway, by the yard's west side.
	var rdir: Vector2 = _rail_dir(BUNKER_S)
	var bunker: Vector2 = _rail_at(BUNKER_S)
	var bxf: Transform3D = _facing(Vector3(rdir.x, 0, rdir.y), Vector3(bunker.x, _rail_top(BUNKER_S) - RAIL_LIFT, bunker.y))
	_add_prop("verladebunker", zk, bxf, func(pk, kit, labels): _kit_call(zk, "coal_bunker", [pk, kit, labels]), 3000.0)
	_note_rect(bunker, 40.0, 70.0, atan2(rdir.x, rdir.y))
	# Mine carts on a display line along the yard's south side, a heritage board, floodlight masts round the yard.
	var cart_xf := _facing(Vector3(1, 0, 0), Vector3(-130.0, _ground_at(-130.0, 52.0), 52.0))
	_add_prop("grubenhunte", zk, cart_xf, func(pk, kit, _l):
		_kit_call(zk, "narrow_gauge", [pk, kit, 60.0])
		for k in range(14):
			pk.set_frame(cart_xf.scaled_local(Vector3.ONE * PROP_SCALE) * Transform3D(Basis(), Vector3(0, 0.227, 3.0 + float(k) * 2.4)))
			_kit_call(zk, "mine_cart", [pk, kit, k % 3]), 1200.0)
	_note_rect(Vector2(-130.0 + 50.0, 52.0), 100.0, 6.0, 0.0)
	for m in [Vector2(-160.0, -60.0), Vector2(150.0, -62.0), Vector2(-160.0, 62.0), Vector2(150.0, 62.0)]:
		_place(_cell_key("flutlicht", Vector3(m.x, 0, m.y), 300.0), zk, m, Vector3(0, 0, 1), "floodlight_mast", [], 2500.0)
		_note_rect(m, 6.0, 6.0, 0.0)
	_place("tafel", zk, Vector2(-120.0, -22.0), Vector3(0, 0, 1), "plaque_board", ["@labels", "ZECHE KRONPRINZ\nSchacht I 1871 · Schacht II 1912\nstillgelegt 1986"], 900.0)
	_note_rect(Vector2(-120.0, -22.0), 6.0, 4.0, 0.0)
	# The conveyor galleries from the washer's stubs: north-west to Schacht II's headframe, north-east to the coal tower.
	if _has_fn(zk, "conveyor_gallery") and _has_fn(zk, "coal_washer_stubs"):
		var foot := func(q: Vector3) -> float: return _ground_at(q.x * PROP_SCALE, q.z * PROP_SCALE) / PROP_SCALE
		var wxf2: Transform3D = _facing(Vector3(1, 0, 0), Vector3(WASHER_X, _ground_at(WASHER_X, 0.0), 0.0))
		var stubs: Array = zk.coal_washer_stubs()
		var targets: Array = [hf * (Vector3(0.0, 24.0, 9.5) * PROP_SCALE), Vector3.ZERO]
		if _kokerei_kit != null and _has_fn(_kokerei_kit, "coal_tower_gallery_end"):
			var ct: Array = _kokerei_kit.coal_tower_gallery_end()
			var yb: float = _ground_at(BATTERY_X0 + 60.0, KOKS_Z)
			var ctf := Transform3D(Basis(), Vector3(KOKS_COAL_TOWER.x, yb, KOKS_COAL_TOWER.y))
			targets[1] = ctf * ((ct[0] as Vector3) * PROP_SCALE)
		for gi in range(stubs.size()):
			var st: Dictionary = stubs[gi]
			var end_w: Vector3 = wxf2 * ((st["end"] as Vector3) * PROP_SCALE)
			# Which target this stub points toward (its direction in the world).
			var dir_w: Vector3 = wxf2.basis * (st["dir"] as Vector3)
			var tgt: Vector3 = targets[0] if (targets[0] - end_w).dot(dir_w) > (targets[1] - end_w).dot(dir_w) else targets[1]
			if tgt == Vector3.ZERO:
				continue
			var al: Vector3 = end_w / PROP_SCALE
			var bl: Vector3 = tgt / PROP_SCALE
			var wdt: float = float(st.get("width", 3.2))
			_add_prop("bandbruecke_%d" % gi, zk, Transform3D(), func(pk, kit, _l): _kit_call(zk, "conveyor_gallery", [pk, kit, al, bl, wdt, foot]), 3000.0)


# ======================================================================================
#  The Kokerei along the lap's first straight (KokereiKit; the layout from its report)
# ======================================================================================

## The battery's frame: x along the lap from BATTERY_X0, its coke side (+z) toward the lap, its centre line KOKS_Z
## (KokereiKit: the road's edge 13.3m life from the coke face clears the quench track and tower).
const KOKS_Z := -42.0
const KOKS_OVENS := 50
const KOKS_OPEN := 21
const KOKS_COAL_TOWER := Vector2(BATTERY_X0 - 12.55 * PROP_SCALE, KOKS_Z)

func _build_kokerei(root: Node3D) -> void:
	var kk: Script = _kokerei_kit
	if kk == null:
		return
	var yb: float = _ground_at(BATTERY_X0 + 60.0, KOKS_Z)
	var base := Transform3D(Basis(), Vector3(BATTERY_X0, yb, KOKS_Z))
	var at := func(lx: float, lz: float, ly := 0.0) -> Transform3D:
		return base * Transform3D(Basis(), Vector3(lx, ly, lz) * PROP_SCALE)
	var L: float = kk.battery_length(KOKS_OVENS)
	_add_prop("koksbatterie", kk, base, func(pk, kit, labels): _kit_call(kk, "coke_battery", [pk, kit, labels, KOKS_OVENS, 3, 3, KOKS_OPEN]), 4000.0)
	_note_rect(Vector2(BATTERY_X0 + L * 0.8, KOKS_Z), L * 1.6 + 30.0, 60.0, 0.0)
	_add_prop("kohlenturm", kk, at.call(kk.COAL_TOWER_X, 0.0), func(pk, kit, labels): _kit_call(kk, "coal_tower", [pk, kit, labels]), 5000.0)
	var ox: float = kk.oven_x(KOKS_OPEN)
	_add_prop("kokswagen", kk, at.call(kk.oven_x(KOKS_OPEN - 1), 0.0), func(pk, kit, _l): _kit_call(kk, "pusher_machine", [pk, kit, true]), 2500.0)
	_add_prop("kokswagen", kk, at.call(ox, 0.0), func(pk, kit, _l): _kit_call(kk, "coke_guide_car", [pk, kit, true, false]), 2500.0)
	_add_prop("kokswagen", kk, at.call(ox, kk.QUENCH_Z), func(pk, kit, _l): _kit_call(kk, "quench_car", [pk, kit, 1]), 2500.0)
	_add_prop("kokswagen", kk, at.call(kk.COAL_TOWER_X, 0.0), func(pk, kit, _l): _kit_call(kk, "larry_car", [pk, kit]), 2500.0)
	# The quench car's line, from the coal tower's end past the quench tower (it stops short of the lap's bend).
	_add_prop("loeschgleis", kk, at.call(-20.0, kk.QUENCH_Z), func(pk, kit, _l): _kit_call(kk, "kokerei_rails", [pk, kit, L + 66.0]), 2500.0)
	var qt: Transform3D = at.call(L + 30.0, kk.QUENCH_Z)
	_add_prop("loeschturm", kk, qt, func(pk, kit, labels): _kit_call(kk, "quench_tower", [pk, kit, labels]), 5000.0)
	_note_rect(Vector2(qt.origin.x, qt.origin.z), 26.0, 22.0, 0.0)
	# The by-product plant on the pusher side, the crossover main to it, the emergency flare.
	var bp: Transform3D = at.call(L * 0.5 + 10.0, -75.0)
	_add_prop("nebengewinnung", kk, bp, func(pk, kit, labels): _kit_call(kk, "byproduct_plant", [pk, kit, labels]), 4000.0)
	_note_rect(Vector2(bp.origin.x, bp.origin.z), 140.0, 100.0, 0.0)
	var off: Array = kk.gas_offtake(KOKS_OVENS)
	var inlet: Vector3 = Vector3(L * 0.5 + 10.0, 0.0, -75.0) + kk.byproduct_gas_inlet()
	var o0: Vector3 = off[0]
	var main_pts := PackedVector3Array([o0, o0 + Vector3(0, 0, -14.0), Vector3(inlet.x - 6.0, o0.y, o0.z - 14.0), Vector3(inlet.x - 6.0, inlet.y, inlet.z), inlet])
	_add_prop("saugleitung", _works, base, func(pk, kit, _l): _kit_call(_works, "pipe_run", [pk, kit, main_pts, 0.75]), 3000.0)
	var fl: Transform3D = at.call(L + 30.0, -62.0)
	_add_prop("notfackel", kk, fl, func(pk, kit, _l): _kit_call(kk, "gas_flare", [pk, kit]), 4000.0)
	# Steam, smoke and fire: the quench tower's bursts with their hiss, leaking doors, the open oven, the flare.
	var fx := Node3D.new()
	fx.name = "KokereiFx"
	root.add_child(fx)
	var sp: Vector3 = qt * (kk.quench_steam_point() * PROP_SCALE)
	var burst := _plume_node(fx, "Loeschdampf", sp, "burst", 2.4)
	burst.set_script(load("res://PeriodicBurst.gd"))
	burst.set("every", 95.0)
	burst.set("phase", 17.0)
	var hiss := _player(burst, "Sound", "res://sounds/zeche/quench_burst.wav", Vector3.ZERO, -24.0 + 32.8 + 2.0, 60.0, 900.0)
	hiss.autoplay = false
	var smokes := 0
	for f in kk.battery_fx_spots(KOKS_OVENS, 3, KOKS_OPEN):
		var kind: String = f[0]
		var p: Vector3 = base * ((f[1] as Vector3) * PROP_SCALE)
		match kind:
			"door_smoke":
				if smokes < 6:
					_plume(fx, "Tuerrauch%d" % smokes, p, "smoke", 0.35)
					smokes += 1
			"top_haze":
				_plume(fx, "Batteriedunst%d" % fx.get_child_count(), p, "steam", 0.3)
			"push_smoke":
				_plume(fx, "Drueckrauch", p, "smoke", 0.9)
				_glow(fx, "Ofenglut", p + Vector3(0, -4.0, 0), Color(1.0, 0.45, 0.12), 6.0, 26.0)
			"standpipe_fire":
				_plume(fx, "Steigrohrfeuer%d" % fx.get_child_count(), p, "flame", 0.6)
	for f2 in kk.byproduct_fx_spots():
		var p2: Vector3 = bp * ((f2[1] as Vector3) * PROP_SCALE)
		_plume(fx, "Nebengewinnung%d" % fx.get_child_count(), p2, "steam" if f2[0] == "steam" else "smoke", float(f2[2]) * 1.4)
	var fp: Vector3 = fl * (kk.flare_point() * PROP_SCALE)
	_plume(fx, "Fackel", fp, "flame", 1.6)
	_glow(fx, "Fackelschein", fp + Vector3(0, 2.0, 0), Color(1.0, 0.55, 0.2), 4.0, 60.0)


func _glow(parent: Node3D, node_name: String, at: Vector3, col: Color, energy: float, rng: float) -> void:
	var l := OmniLight3D.new()
	l.name = node_name
	l.position = at
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	l.set_meta(&"no_shadow", true)
	l.distance_fade_enabled = true
	l.distance_fade_begin = 600.0
	l.distance_fade_length = 200.0
	parent.add_child(l)


# ======================================================================================
#  The Halde: the summit landmark, a few walkers on the plateau
# ======================================================================================

func _build_halde_dressing(_root: Node3D) -> void:
	var zk: Script = _zechen_kit
	if zk != null:
		var lxf: Transform3D = _place("kronprinzenblick", zk, SUMMIT_AT, Vector3(-1, 0, 0), "summit_landmark", ["@labels", false], 6000.0)
		_note_rect(SUMMIT_AT, 34.0, 34.0, 0.0)
		if _has_fn(zk, "summit_wheel") and _has_fn(zk, "summit_wheel_hub"):
			var piv := Node3D.new()
			piv.name = "KronprinzenRad"
			piv.set_script(load("res://Spinner.gd"))
			piv.transform = Transform3D(lxf.basis, lxf * ((zk.summit_wheel_hub() as Vector3) * PROP_SCALE))
			piv.set("axis", Vector3(1, 0, 0))
			piv.set("degrees_per_second", 6.0)
			_root.add_child(piv)
			var wm := MeshInstance3D.new()
			wm.name = "Wheel"
			wm.mesh = _kit_mesh_life(zk, "summit_wheel", func(pk, kit): zk.summit_wheel(pk, kit))
			wm.scale = Vector3.ONE * PROP_SCALE
			piv.add_child(wm)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4411
	for i in range(10):
		var p := Vector2(SUMMIT_AT.x + rng.randf_range(-14.0, 14.0), SUMMIT_AT.y + rng.randf_range(-30.0, 30.0))
		if _lap_dist(p.x, p.y) < ROAD_HALF + 4.0:
			continue
		var face := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
		_people.append([Vector3(p.x, _ground_at(p.x, p.y), p.y), face, false, false, -1, rng.randf_range(0.85, 1.05)])


# ======================================================================================
#  Buddleia and goldenrod on the wasteland (ZechenKit's plant meshes), never on the track
# ======================================================================================

func _build_scrub_plants(root: Node3D) -> void:
	var zk: Script = _zechen_kit
	if zk == null or not _has_fn(zk, "buddleia_mesh"):
		return
	var node := Node3D.new()
	node.name = "Ruderalflora"
	root.add_child(node)
	var kinds: Array = [["buddleia", zk.buddleia_mesh(1), 0.55], ["buddleia", zk.buddleia_mesh(2), 0.2], ["goldenrod", zk.goldenrod_mesh(1), 0.25]] if _has_fn(zk, "goldenrod_mesh") else [["buddleia", zk.buddleia_mesh(1), 1.0]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5517
	var cells := {}
	var x: float = FINE_X.x + 40.0
	while x < FINE_X.y - 40.0:
		var z: float = FINE_Z.x + 40.0
		while z < FINE_Z.y - 40.0:
			var px: float = x + rng.randf_range(-6.0, 6.0)
			var pz: float = z + rng.randf_range(-6.0, 6.0)
			var roll: float = rng.randf()
			z += 14.0
			# Thickest by the railway and on the works' edges, some on the Halde's foot.
			var dens: float = 0.05 + 0.35 * (1.0 - smoothstep(10.0, 60.0, _rail_dist(px, pz)))
			dens += 0.2 * (1.0 - smoothstep(0.0, 40.0, absf(_halde_d(px, pz) - HALDE_Y / HALDE_SLOPE)))
			if roll > dens or _occupied(px, pz) or _lap_dist(px, pz) < ROAD_HALF + 6.0 or _rail_dist(px, pz) < 5.0:
				continue
			var r2: float = rng.randf()
			var ki := 0
			var acc := 0.0
			for k in range(kinds.size()):
				acc += float(kinds[k][2])
				if r2 <= acc:
					ki = k
					break
			var g: float = _ground_at(px, pz)
			var sc: float = PROP_SCALE * rng.randf_range(0.8, 1.2)
			var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(px, g - 0.1, pz))
			var key := Vector3i(floori(px / 200.0), floori(pz / 200.0), ki)
			if not cells.has(key):
				cells[key] = []
			cells[key].append(xf)
		x += 14.0
	var total := 0
	for key in cells.keys():
		var mesh: Mesh = kinds[key.z][1]
		var mid := Vector3((float(key.x) + 0.5) * 200.0, 0.0, (float(key.y) + 0.5) * 200.0)
		var local: Array = []
		for t in cells[key]:
			local.append(Transform3D((t as Transform3D).basis, (t as Transform3D).origin - mid))
		var mmi := _multimesh(node, "PlantsNear_%s_%d_%d_%d" % [kinds[key.z][0], key.x, key.y, key.z], _save_res(mesh, "plant_%s_%d" % [kinds[key.z][0], key.z], PROP_PREFIX) if mesh.resource_path.is_empty() else mesh, local, 520.0, false)
		mmi.position = mid
		total += local.size()
	print("  scrub plants: %d" % total)


# ======================================================================================
#  Sounds: the Kokerei, the quench tower's bursts, the conveyor, crows in the scrub
# ======================================================================================

func _build_sounds(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "ZecheSounds"
	root.add_child(node)
	var k := _player(node, "KokereiHum", "res://sounds/zeche/kokerei_loop.wav", Vector3(BATTERY_X0 + 70.0, 8.0, -40.0), -24.0 + 17.1 - 3.0, 26.0, 380.0)
	k.autoplay = true
	var cv := _player(node, "Foerderband", "res://sounds/zeche/conveyor_loop.wav", Vector3(WASHER_X + 40.0, 30.0, -20.0), -24.0 + 16.9 - 8.0, 16.0, 180.0)
	cv.autoplay = true
	for at in [Vector3(-300.0, 8.0, -560.0), Vector3(150.0, 8.0, -700.0), Vector3(-330.0, 8.0, -150.0), Vector3(400.0, 8.0, -620.0)]:
		var c := _player(node, "Kraehen%d" % node.get_child_count(), "res://sounds/zeche/crows_loop.wav", at, -24.0 + 38.8 - 4.0, 30.0, 300.0)
		c.autoplay = true


# ======================================================================================
#  The start: crowd barriers and spectators on the yard either side of the line
# ======================================================================================

const SPECTATOR_SCALE := PROP_SCALE / 1.86
const SPECTATOR_SKIN := [0.05, 0.04, 0.72, 0.03, 0.16]
const START_BEFORE := 110.0
const START_AFTER := 90.0
const BARRIER_LAT := ROAD_HALF + 3.0

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
	var s_fin: float = _closest_s(Vector2(FINISH_X, 0.0))
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
#  The woods: the birch scrub (WoodlandBuilder's birch, willow, poplar, oak)
# ======================================================================================

const TREE_CELL := 260.0
const TREE_FAR_RANGE := 1800.0
var _tree_kinds: Array = []

func _build_woods(root: Node3D) -> void:
	var t0 := Time.get_ticks_msec()
	var node := Node3D.new()
	node.name = "Woodland"
	root.add_child(node)
	var w = load("res://WoodlandBuilder.gd").new()
	w.save_res = func(res: Resource, n: String) -> Resource: return _save_res(res, n, "zechetree_")
	_tree_kinds = ["birch", "willow", "oak", "poplar"]
	var leaf_near: ShaderMaterial = _save_res(w.leaf_material(1, 0.14, 18.0), "leaf_near", "zechetree_")
	var leaf_far: ShaderMaterial = _save_res(w.leaf_material(2, 0.14, 18.0), "leaf_far", "zechetree_")
	var rleaf_near: ShaderMaterial = _save_res(w.rhein_leaf_material(1, 0.14, 18.0), "rhein_leaf_near", "zechetree_")
	var rleaf_far: ShaderMaterial = _save_res(w.rhein_leaf_material(2, 0.14, 18.0), "rhein_leaf_far", "zechetree_")
	var lod_mats: Array[ShaderMaterial] = [leaf_near, leaf_far, rleaf_near, rleaf_far]
	var near_meshes: Array = []
	var far_meshes: Array = []
	for kind in _tree_kinds:
		var bark_key: String = _bark_key(kind)
		var bn: ShaderMaterial = _save_res(w.bark_material(bark_key, 1), "bark_%s_near" % kind, "zechetree_")
		var bf: ShaderMaterial = _save_res(w.bark_material(bark_key, 2), "bark_%s_far" % kind, "zechetree_")
		lod_mats.append(bn)
		lod_mats.append(bf)
		var own: bool = w.uses_rhein_atlas(kind)
		near_meshes.append(_save_res(w.tree_mesh(kind, 0, 0, bn, rleaf_near if own else leaf_near), "tree_%s" % kind, "zechetree_"))
		far_meshes.append(_save_res(w.tree_mesh(kind, 0, 1, bf, rleaf_far if own else leaf_far), "tree_%s_far" % kind, "zechetree_"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 9841
	var cells := {}
	var counts := {}
	for k in _tree_kinds:
		counts[k] = 0
	var add := func(kind: String, px: float, pz: float, sc: float) -> void:
		var mi: int = _tree_kinds.find(kind)
		var g: float = _ground_at(px, pz)
		var lean := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.06))
		var xf := Transform3D(lean * Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.9, 1.1), sc)), Vector3(px, g - 0.3, pz))
		var key := Vector3i(floori(px / TREE_CELL), floori(pz / TREE_CELL), mi)
		if not cells.has(key):
			cells[key] = []
		cells[key].append(xf)
		counts[kind] += 1
	var step := 12.5
	var x: float = FINE_X.x + 30.0
	while x < FINE_X.y - 30.0:
		var z: float = FINE_Z.x + 30.0
		while z < FINE_Z.y - 30.0:
			var px: float = x + rng.randf_range(-0.45, 0.45) * step
			var pz: float = z + rng.randf_range(-0.45, 0.45) * step
			var roll: float = rng.randf()
			z += step
			var fw: float = _forest_w(px, pz) * _open_land(px, pz)
			if roll > maxf(fw, 0.015):
				continue
			if _occupied(px, pz) or _lap_dist(px, pz) < 15.0 or _rail_dist(px, pz) < 8.0:
				continue
			var g: float = _ground_at(px, pz)
			var slope: float = Vector2(_ground_at(px + 3.0, pz) - g, _ground_at(px, pz + 3.0) - g).length() / 3.0
			if slope > 0.6:
				continue
			var r2: float = rng.randf()
			# Birches mostly (the colliery's scrub), willows by the ponds, a few oaks and poplars.
			var kind := "birch"
			var near_pond := false
			for p in PONDS:
				if (p[0] as Vector2).distance_to(Vector2(px, pz)) < (p[1] as Vector2).length() * 1.3:
					near_pond = true
			if near_pond and r2 < 0.55:
				kind = "willow"
			elif r2 < 0.12:
				kind = "oak"
			elif r2 < 0.2:
				kind = "poplar"
			add.call(kind, px, pz, rng.randf_range(0.8, 1.2))
		x += step
	var cell_r: float = TREE_CELL * 0.72
	var near_end: float = 120.0 + cell_r
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
			push_error("Zeche: corner %d's radius %.0f does not fit" % [i, r])
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


## Cubic Hermite from (x0, y0, slope m0) to (x1, y1, slope m1), clamped outside.
func _hermite(x: float, x0: float, y0: float, m0: float, x1: float, y1: float, m1: float) -> float:
	var h: float = x1 - x0
	var t: float = clampf((x - x0) / h, 0.0, 1.0)
	var t2: float = t * t
	var t3: float = t2 * t
	return (2.0 * t3 - 3.0 * t2 + 1.0) * y0 + (t3 - 2.0 * t2 + t) * h * m0 + (-2.0 * t3 + 3.0 * t2) * y1 + (t3 - t2) * h * m1


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


func _rect_weight(x: float, z: float, r: Array, blend: float) -> float:
	var dx: float = maxf(float(r[0]) - x, x - float(r[2]))
	var dz: float = maxf(float(r[1]) - z, z - float(r[3]))
	return 1.0 - smoothstep(0.0, blend, maxf(dx, dz))


func _in_rect(x: float, z: float, r: Array, pad := 0.0) -> bool:
	return x > float(r[0]) - pad and x < float(r[2]) + pad and z > float(r[1]) - pad and z < float(r[3]) + pad


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


## A frame facing `face` (its +z) standing upright at `at`.
func _facing(face: Vector3, at: Vector3) -> Transform3D:
	var z := Vector3(face.x, 0.0, face.z).normalized()
	var x := Vector3.UP.cross(z).normalized()
	return Transform3D(Basis(x, Vector3.UP, z), at)


func _camp_material(key: String) -> Material:
	if not _camp_mats.has(key):
		_camp_mats[key] = _save_res(CampKit.make_material(key), "camp_mat_" + key, PROP_PREFIX)
	return _camp_mats[key]


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


## A plume of steam or smoke ("steam", "smoke"), a flame ("flame": additive, flickering, small) or a one-shot burst of
## steam ("burst": the quench tower's, emitted by PeriodicBurst.gd) at `at`, `size` times the works' own.
func _plume(parent: Node3D, node_name: String, at: Vector3, kind: String, size := 1.0) -> void:
	_plume_node(parent, node_name, at, kind, size)


func _plume_node(parent: Node3D, node_name: String, at: Vector3, kind: String, size := 1.0) -> GPUParticles3D:
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
	mat.albedo_texture = _puff_texture()
	var grad := Gradient.new()
	var sc := Curve.new()
	match kind:
		"flame":
			p.amount = 24
			p.lifetime = 0.9
			p.visibility_aabb = AABB(Vector3(-10, -2, -10) * size, Vector3(20, 20, 20) * size)
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			pm.emission_sphere_radius = 0.6 * size
			pm.direction = Vector3(0, 1, 0)
			pm.spread = 14.0
			pm.initial_velocity_min = 3.0 * size
			pm.initial_velocity_max = 5.0 * size
			pm.gravity = Vector3(0.6, 2.0, 0.2)
			quad.size = Vector2.ONE * 2.6 * size
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			grad.colors = PackedColorArray([Color(1.0, 0.9, 0.5, 0.0), Color(1.0, 0.65, 0.2, 0.9), Color(0.9, 0.25, 0.05, 0.5), Color(0.3, 0.05, 0.0, 0.0)])
			grad.offsets = PackedFloat32Array([0.0, 0.15, 0.6, 1.0])
			sc.add_point(Vector2(0.0, 1.0))
			sc.add_point(Vector2(1.0, 0.3))
		"burst":
			p.amount = 90
			p.lifetime = 14.0
			p.explosiveness = 0.75
			p.one_shot = true
			p.emitting = false
			p.visibility_aabb = AABB(Vector3(-120, -10, -120) * size, Vector3(240, 220, 240) * size)
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			pm.emission_sphere_radius = 4.0 * size
			pm.direction = Vector3(0, 1, 0)
			pm.spread = 22.0
			pm.initial_velocity_min = 9.0 * size
			pm.initial_velocity_max = 16.0 * size
			pm.gravity = Vector3(1.2, -0.3, 0.6) * size
			pm.damping_min = 0.6 * size
			pm.damping_max = 1.0 * size
			pm.angle_min = -180.0
			pm.angle_max = 180.0
			quad.size = Vector2.ONE * 26.0 * size
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
			mat.disable_receive_shadows = true
			var cw := Color(0.97, 0.96, 0.95)
			grad.colors = PackedColorArray([Color(cw, 0.0), Color(cw, 0.92), Color(cw, 0.45), Color(cw, 0.0)])
			grad.offsets = PackedFloat32Array([0.0, 0.05, 0.5, 1.0])
			sc.add_point(Vector2(0.0, 0.3))
			sc.add_point(Vector2(1.0, 1.0))
		_:
			var steam: bool = kind == "steam"
			p.amount = 40 if steam else 28
			p.lifetime = 14.0 if steam else 12.0
			p.preprocess = p.lifetime
			p.visibility_aabb = AABB(Vector3(-150, -20, -150) * size, Vector3(300, 260, 300) * size)
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			pm.emission_sphere_radius = (10.0 if steam else 1.6) * size
			pm.direction = Vector3(0.2, 1.0, 0.1)
			pm.spread = 12.0
			pm.initial_velocity_min = (6.0 if steam else 3.5) * size
			pm.initial_velocity_max = (9.0 if steam else 5.5) * size
			pm.gravity = Vector3(1.4, -0.4, 0.7) * maxf(size, 0.5)
			pm.damping_min = 0.25
			pm.damping_max = 0.45
			pm.angle_min = -180.0
			pm.angle_max = 180.0
			quad.size = Vector2.ONE * (30.0 if steam else 12.0) * size
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
			mat.disable_receive_shadows = true
			var c: Color = Color(0.96, 0.96, 0.95) if steam else Color(0.36, 0.34, 0.33)
			grad.colors = PackedColorArray([Color(c, 0.0), Color(c, 0.8 if steam else 0.6), Color(c, 0.32), Color(c, 0.0)])
			grad.offsets = PackedFloat32Array([0.0, 0.08, 0.55, 1.0])
			sc.add_point(Vector2(0.0, 0.35))
			sc.add_point(Vector2(1.0, 1.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	quad.material = mat
	p.draw_pass_1 = quad
	parent.add_child(p)
	return p


func _kit_script(path: String) -> Script:
	if ResourceLoader.exists(path):
		var sc: Script = load(path)
		if sc != null and sc.can_instantiate():
			return sc
	push_warning("Zeche: %s isn't there (or doesn't parse) yet" % path)
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


func _kit_call(script: Script, fn: String, args: Array) -> void:
	if script == null or not _has_fn(script, fn):
		if not _missing.has(fn):
			_missing[fn] = true
			push_warning("Zeche: %s has no %s() yet" % [script.resource_path.get_file() if script else "(no kit)", fn])
		return
	script.callv(fn, args)


func _cell_key(prefix: String, p: Vector3, cell := 140.0) -> String:
	return "%s_%d_%d" % [prefix, floori(p.x / cell), floori(p.z / cell)]


func _flush_batches(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Zeche"
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


## The bark a kind's trunk takes: BROADLEAF's own "bark" key where it names one (the willow's alder), else the kind.
func _bark_key(kind: String) -> String:
	var cm: Dictionary = (load("res://WoodlandBuilder.gd") as Script).get_script_constant_map()
	var bl: Dictionary = cm.get("BROADLEAF", {})
	if bl.has(kind) and (bl[kind] as Dictionary).has("bark"):
		return String(bl[kind]["bark"])
	return kind

