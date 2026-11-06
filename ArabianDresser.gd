extends RefCounted
## What the Al-Raihana GP's dressers share (regenerate_mountain_dressing.gd, regenerate_wadi_dressing.gd): the
## ground under the TerrainGenerator's own triangles, the lap's distance and height in plan, footprints, the
## sky, the ground material and its map, the desert's plants and rocks scattered in MultiMesh cells (named for
## CanyonDetail.gd: Plants_, Tall_ and Rocks_), the country round the terrain's rim and the city on the
## horizon. Nothing here is a node of its own at runtime: it builds into the level and is gone.

const PropKit = preload("res://PropKit.gd")
const ArabianKit = preload("res://ArabianKit.gd")
const ArabianTerrain = preload("res://ArabianTerrain.gd")
const DatePalmKit = preload("res://DatePalmKit.gd")
const Woodland = preload("res://WoodlandBuilder.gd")
const FreightKit = preload("res://FreightKit.gd")
const BloombayCity = preload("res://BloombayCity.gd")

const PROP_SCALE := 1.6
const ROAD_CELL := 24.0

var level: Node3D
var tg: Node3D
var curve: Curve3D
var length := 0.0
var road_half := 8.5
var rng := RandomNumberGenerator.new()
## [centre (Vector2), radius] of everything standing (buildings, pads, landmarks), for keeping apart.
var notes: Array = []
var _pts := PackedVector3Array()
var _grid := {}
var _res := 0
var _step := 2.0
var _start := -1000.0


func setup(lvl: Node3D, gen: Node3D, seed_v: int) -> void:
	level = lvl
	tg = gen
	rng.seed = seed_v
	var tp: Path3D = level.get_node("TrackPath")
	curve = tp.curve
	length = curve.get_baked_length()
	road_half = float(tg.curb_outer_width) * 0.5
	_index_road()


func save(res: Resource, n: String) -> Resource:
	return tg.call("_save_resource", res, n)


# ======================================================================================
#  The lap and the ground
# ======================================================================================

func _index_road() -> void:
	_pts.clear()
	_grid.clear()
	var s := 0.0
	while s < length:
		_pts.append(curve.sample_baked(s))
		s += 2.0
	for i in range(_pts.size()):
		var k := Vector2i(floori(_pts[i].x / ROAD_CELL), floori(_pts[i].z / ROAD_CELL))
		if not _grid.has(k):
			_grid[k] = []
		(_grid[k] as Array).append(i)


## Distance in plan from (x, z) to the lap's centreline (searching `reach` metres; INF if none within it).
func road_dist(x: float, z: float, reach := 60.0) -> float:
	var r: int = int(ceil(reach / ROAD_CELL))
	var cx := floori(x / ROAD_CELL)
	var cz := floori(z / ROAD_CELL)
	var best := INF
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var k := Vector2i(cx + dx, cz + dz)
			if not _grid.has(k):
				continue
			for i in (_grid[k] as Array):
				var d: float = Vector2(_pts[i].x - x, _pts[i].z - z).length_squared()
				if d < best:
					best = d
	return sqrt(best) if best < INF else INF


## The nearest lap point in plan: [distance, point, offset along the lap].
func road_near(x: float, z: float, reach := 60.0) -> Array:
	var r: int = int(ceil(reach / ROAD_CELL))
	var cx := floori(x / ROAD_CELL)
	var cz := floori(z / ROAD_CELL)
	var best := INF
	var bi := -1
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var k := Vector2i(cx + dx, cz + dz)
			if not _grid.has(k):
				continue
			for i in (_grid[k] as Array):
				var d: float = Vector2(_pts[i].x - x, _pts[i].z - z).length_squared()
				if d < best:
					best = d
					bi = i
	if bi < 0:
		return [INF, Vector3.ZERO, 0.0]
	return [sqrt(best), _pts[bi], float(bi) * 2.0]


## The ground on the TerrainGenerator's own visual triangles (each cell split from (x+1, z) to (x, z+1)).
func ground(x: float, z: float) -> float:
	var hts: PackedFloat32Array = tg.get("_visual_heights")
	if hts.is_empty():
		return tg.natural_height(x, z)
	if _res == 0:
		_res = int(tg.terrain_resolution)
		_step = float(tg.terrain_size.x) / float(_res)
		_start = -float(tg.terrain_size.x) * 0.5
	var gx: float = (x - _start) / _step
	var gz: float = (z - _start) / _step
	var x0: int = clampi(int(floor(gx)), 0, _res - 1)
	var z0: int = clampi(int(floor(gz)), 0, _res - 1)
	var fx: float = clampf(gx - x0, 0.0, 1.0)
	var fz: float = clampf(gz - z0, 0.0, 1.0)
	var stride := _res + 1
	var h00: float = hts[z0 * stride + x0]
	var h10: float = hts[z0 * stride + x0 + 1]
	var h01: float = hts[(z0 + 1) * stride + x0]
	var h11: float = hts[(z0 + 1) * stride + x0 + 1]
	if tg.call("split_00_11", h00, h10, h01, h11):
		# Split from (x, z) to (x+1, z+1).
		if fx >= fz:
			return h00 + (h10 - h00) * fx + (h11 - h10) * fz
		return h00 + (h01 - h00) * fz + (h11 - h01) * fx
	if fx + fz <= 1.0:
		return h00 + (h10 - h00) * fx + (h01 - h00) * fz
	return h11 + (h01 - h11) * (1.0 - fx) + (h10 - h11) * (1.0 - fz)


## The rise over a metre at (x, z), from four samples `r` apart.
func slope(x: float, z: float, r := 1.5) -> float:
	return maxf(absf(ground(x + r, z) - ground(x - r, z)), absf(ground(x, z + r) - ground(x, z - r))) / (2.0 * r)


## Lowest and highest ground within `r` (a ring of samples and the middle): [min, max].
func relief(x: float, z: float, r: float, use_natural := false) -> Vector2:
	var lo := INF
	var hi := -INF
	for k in range(13):
		var p := Vector2(x, z) if k == 12 else Vector2(x, z) + Vector2.from_angle(TAU * k / 12.0) * r
		var y: float = tg.natural_height(p.x, p.y) if use_natural else ground(p.x, p.y)
		lo = minf(lo, y)
		hi = maxf(hi, y)
	return Vector2(lo, hi)


func is_free(c: Vector2, r: float) -> bool:
	for n in notes:
		if c.distance_to(n[0]) < r + float(n[1]):
			return false
	return true


func note(c: Vector2, r: float) -> void:
	notes.append([c, r])


# ======================================================================================
#  Stripping, sky and the ground's material
# ======================================================================================

## Removes the named nodes, and every direct child instancing an imported model (.fbx, .glb, .blend).
func strip(names: Array) -> Array:
	var gone: Array = []
	var doomed: Array = []
	for child in level.get_children():
		var f: String = child.scene_file_path
		if names.has(str(child.name)) or f.ends_with(".fbx") or f.ends_with(".glb") or f.ends_with(".blend"):
			doomed.append(child)
	for n in doomed:
		gone.append(str(n.name))
		level.remove_child(n)
		n.free()
	return gone


## A clear desert sky: deep blue overhead fading to a warm, dusty haze at the horizon, a few high clouds,
## and the sun at `sun_rot` (degrees: pitch, yaw).
func environment(sun_rot: Vector3, haze: Color, sun_col: Color, sun_energy: float, clouds := 0.12, fog_end := 4600.0) -> void:
	for n in ["WorldEnvironment", "SunLight"]:
		var old := level.get_node_or_null(n)
		if old:
			level.remove_child(old)
			old.free()
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://sky_tropical_cumulus.gdshader")
	sm.set_shader_parameter("sky_top", Color(0.16, 0.36, 0.72))
	sm.set_shader_parameter("sky_horizon", haze.lightened(0.12))
	sm.set_shader_parameter("ground_horizon", haze)
	sm.set_shader_parameter("ground_bottom", Color(0.62, 0.50, 0.38))
	sm.set_shader_parameter("sky_curve", 0.42)
	sm.set_shader_parameter("horizon_haze", haze)
	sm.set_shader_parameter("haze_strength", 1.0)
	sm.set_shader_parameter("haze_height", 0.2)
	sm.set_shader_parameter("sun_tint", sun_col)
	sm.set_shader_parameter("sun_disc_degrees", 1.0)
	sm.set_shader_parameter("sun_glow", 0.75)
	sm.set_shader_parameter("sun_horizon_tint", Color(1.0, 0.74, 0.46))
	sm.set_shader_parameter("sun_horizon_glow", 0.5)
	sm.set_shader_parameter("cloud_lit", Color(1.0, 0.97, 0.92))
	sm.set_shader_parameter("cloud_shade", Color(0.70, 0.66, 0.66))
	sm.set_shader_parameter("cloud_coverage", clouds)
	sm.set_shader_parameter("cloud_opacity", 0.7)
	sm.set_shader_parameter("cloud_scale", 2.2)
	sm.set_shader_parameter("cloud_seed", 41.7)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.4
	env.ambient_light_color = Color(0.98, 0.88, 0.76)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.22
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = haze
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.25
	env.fog_density = 1.0
	env.fog_depth_begin = 300.0
	env.fog_depth_end = fog_end
	env.fog_depth_curve = 1.6
	env.fog_sky_affect = 0.05
	env.fog_aerial_perspective = 0.25
	env_node.environment = env
	level.add_child(env_node)
	level.move_child(env_node, 0)
	env_node.owner = level
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = sun_rot
	sun.light_color = sun_col
	sun.light_energy = sun_energy
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 280.0
	sun.directional_shadow_split_1 = 0.08
	sun.directional_shadow_split_2 = 0.22
	sun.directional_shadow_split_3 = 0.5
	level.add_child(sun)
	level.move_child(sun, 1)
	sun.owner = level


## Bakes the ground map (see arabian_ground.gdshader) over [-half, half] at `res` texels: `fn(x, z)` gives
## (piste, gravel, yard, 1).
func ground_map(res: int, half: float, fn: Callable) -> ImageTexture:
	var img := Image.create(res, res, false, Image.FORMAT_RGBA8)
	for j in range(res):
		var z: float = -half + (float(j) + 0.5) * (2.0 * half / res)
		for i in range(res):
			var x: float = -half + (float(i) + 0.5) * (2.0 * half / res)
			img.set_pixel(i, j, fn.call(x, z))
	var tex := ImageTexture.create_from_image(img)
	return save(tex, "ground_map") as ImageTexture


func ground_material(map: Texture2D, half: float, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://arabian_ground.gdshader")
	m.set_shader_parameter("sand_tex", load("res://materials/sand.png"))
	m.set_shader_parameter("sand_normal", load("res://materials/sand_normal.png"))
	m.set_shader_parameter("rock_tex", load("res://materials/dark_rock.png"))
	m.set_shader_parameter("rock_normal", load("res://materials/dark_canyon_rock_normal.png"))
	m.set_shader_parameter("gravel_tex", load("res://materials/dark_canyon_rock.png"))
	if map:
		m.set_shader_parameter("ground_map", map)
		m.set_shader_parameter("use_map", true)
		m.set_shader_parameter("map_min", Vector2(-half, -half))
		m.set_shader_parameter("map_max", Vector2(half, half))
	for k in params:
		m.set_shader_parameter(k, params[k])
	return save(m, "ground_material") as ShaderMaterial


# ======================================================================================
#  Plants and rocks
# ======================================================================================

var _palms: DatePalmKit
var _wood: Woodland
var _rock_mat: ShaderMaterial

## A dune-grass tuft (Panicum, the desert's tough clumping grass): stiff blades fanning out of a clump, pale
## straw at the tips. dune_grass.gdshader (alpha: height up the blade).
func tuft_mesh(v: int) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = 6600 + v
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blades: int = 26 + v * 6
	var base_col: Color = [Color(0.52, 0.56, 0.32), Color(0.62, 0.60, 0.36), Color(0.58, 0.54, 0.34)][v % 3]
	for b in range(blades):
		var a: float = r.randf() * TAU
		var lean: float = r.randf_range(0.15, 0.75)
		var h: float = r.randf_range(0.55, 1.05)
		var w: float = r.randf_range(0.025, 0.04)
		var foot := Vector3(cos(a), 0, sin(a)) * r.randf_range(0.0, 0.18)
		var dir := (Vector3(cos(a) * sin(lean), cos(lean), sin(a) * sin(lean))).normalized()
		var side := dir.cross(Vector3(cos(a), 0, sin(a))).normalized()
		if side.length_squared() < 0.01:
			side = Vector3.RIGHT
		var mid := foot + dir * h * 0.55 + Vector3(cos(a), 0, sin(a)) * h * 0.08
		var tip := foot + dir * h + Vector3(cos(a), -0.2, sin(a)) * h * 0.22
		var c0: Color = base_col.darkened(0.25)
		var c2: Color = base_col.lerp(Color(0.86, 0.78, 0.55), r.randf_range(0.3, 0.8))
		var n := side.cross(dir).normalized()
		var pts := [[foot - side * w, 0.0, c0], [foot + side * w, 0.0, c0], [mid - side * w * 0.7, 0.55, base_col], [mid + side * w * 0.7, 0.55, base_col]]
		for q in [[0, 1, 3], [0, 3, 2]]:
			for k in q:
				var c: Color = pts[k][2]
				st.set_color(Color(c.r, c.g, c.b, pts[k][1]))
				st.set_normal((n + Vector3.UP).normalized())
				st.add_vertex(pts[k][0])
		for k in [2, 3]:
			var c: Color = pts[k][2]
			st.set_color(Color(c.r, c.g, c.b, pts[k][1]))
			st.set_normal((n + Vector3.UP).normalized())
			st.add_vertex(pts[k][0])
		st.set_color(Color(c2.r, c2.g, c2.b, 1.0))
		st.set_normal((n + Vector3.UP).normalized())
		st.add_vertex(tip)
	var mesh := st.commit()
	var m := ShaderMaterial.new()
	m.shader = load("res://dune_grass.gdshader")
	m.set_shader_parameter("sway", 0.12)
	mesh.surface_set_material(0, m)
	return mesh


## A broom bush (abal, Calligonum): a mound of leafless jointed green-grey twigs, reddish at the nodes, from a
## woody base. Vertex colour, two-sided.
func broom_mesh(v: int) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = 6700 + v
	var pk := PropKit.new()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.9
	pk.material_for = func(_k: String) -> Material: return mat
	var kit := {}
	var height: float = 1.4 + v * 0.35
	var spread: float = 1.2 + v * 0.3
	for s in range(9):
		var a: float = TAU * s / 9.0 + r.randf_range(-0.3, 0.3)
		var out := Vector3(cos(a), 0, sin(a))
		var p0 := out * 0.1
		var p1 := out * spread * 0.35 + Vector3(0, height * 0.35, 0)
		pk.tube(kit, "w", p0, p1, 0.05, 0.035, 4, Color(0.36, 0.28, 0.22), false)
		for t in range(7):
			var tw := Vector3(cos(a + r.randf_range(-0.9, 0.9)), 0, sin(a + r.randf_range(-0.9, 0.9)))
			var q0 := p1 + Vector3(r.randf_range(-0.15, 0.15), r.randf_range(-0.1, 0.2), r.randf_range(-0.15, 0.15))
			var q1 := q0 + tw * spread * r.randf_range(0.3, 0.6) + Vector3(0, height * r.randf_range(0.35, 0.65), 0)
			var q2 := q1 + tw * spread * r.randf_range(0.1, 0.3) + Vector3(0, height * r.randf_range(0.0, 0.2), 0)
			var g := Color(0.50, 0.56, 0.40).lerp(Color(0.62, 0.62, 0.48), r.randf())
			pk.tube(kit, "w", q0, q1, 0.022, 0.016, 3, g, false)
			pk.tube(kit, "w", q1, q2, 0.016, 0.008, 3, g.lerp(Color(0.58, 0.36, 0.28), 0.4), false)
	return pk.commit(kit)


func palms() -> DatePalmKit:
	if _palms == null:
		_palms = DatePalmKit.new()
		_palms.save_res = func(res: Resource, n: String) -> Resource: return save(res, n)
	return _palms


func woods() -> Woodland:
	if _wood == null:
		_wood = Woodland.new()
		_wood.save_res = func(res: Resource, n: String) -> Resource: return save(res, n)
	return _wood


func rock_material(tint := Color(0.42, 0.34, 0.28)) -> ShaderMaterial:
	if _rock_mat == null:
		var m := ShaderMaterial.new()
		m.shader = load("res://canyon_rock.gdshader")
		m.set_shader_parameter("sand_tex", load("res://materials/sand.png"))
		m.set_shader_parameter("rock_tex", load("res://materials/dark_rock.png"))
		m.set_shader_parameter("rock_normal", load("res://materials/dark_canyon_rock_normal.png"))
		m.set_shader_parameter("sand_tint", Color(0.86, 0.62, 0.42))
		# The jebel's dark rock: brown-grey, not the Sierra's red beds.
		m.set_shader_parameter("tint", tint)
		m.set_shader_parameter("tint_amount", 0.92)
		_rock_mat = save(m, "rock_material") as ShaderMaterial
	return _rock_mat


## Instances bucketed into `cell`-metre MultiMesh cells under `root`, each cell's instances shuffled (so
## CanyonDetail.gd thins it evenly), drawn to `range_end` (with `base_range` for CanyonDetail), from `range_begin`.
func scatter(root: Node3D, mesh: Mesh, xfs: Array, prefix: String, cell: float, range_end: float, range_begin := 0.0,
		shadows := true, detail := true) -> int:
	var cells := {}
	for xf in xfs:
		var o: Vector3 = (xf as Transform3D).origin
		var k := Vector2i(floori(o.x / cell), floori(o.z / cell))
		if not cells.has(k):
			cells[k] = []
		cells[k].append(xf)
	var n := 0
	for k in cells:
		var list: Array = cells[k]
		for i in range(list.size() - 1, 0, -1):
			var j: int = rng.randi() % (i + 1)
			var tmp = list[i]
			list[i] = list[j]
			list[j] = tmp
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list.size()
		mm.buffer = PropKit.transform_buffer(list)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s_%d_%d" % [prefix, k.x, k.y]
		mmi.multimesh = mm
		mmi.visibility_range_end = range_end + cell * 0.71
		mmi.visibility_range_begin = maxf(0.0, range_begin - cell * 0.71) if range_begin > 0.0 else 0.0
		if detail:
			mmi.set_meta(&"base_range", mmi.visibility_range_end)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)
		mmi.owner = level
		n += list.size()
	return n


## A transform standing a plant at (x, z) on the ground, turned at random, scaled `s`, sunk `sink`.
func stand(x: float, z: float, s: float, sink := 0.05, tilt := 0.0) -> Transform3D:
	var b := Basis(Vector3.UP, rng.randf() * TAU)
	if tilt > 0.0:
		b = Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, tilt)) * b
	return Transform3D(b.scaled(Vector3.ONE * s), Vector3(x, ground(x, z) - sink, z))


# ======================================================================================
#  The country past the rim, and the city
# ======================================================================================

## A ring of ground from `r0` (tucked under the terrain's rim) out to `r1`: dunes carried on, and ranges
## rising toward `range_bearing` (radians, ±`range_half`) to `range_h`. Vertex colour, unshaded by distance.
func backdrop(root: Node3D, r0: float, r1: float, range_bearing: float, range_half: float, range_h: float, sand: Color, rock: Color) -> void:
	var segs := 540
	var rings: Array = []
	var r := r0
	while r < r1:
		rings.append(r)
		r += maxf(8.0, r * 0.03)
	rings.append(r1)
	var ridge := FastNoiseLite.new()
	ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridge.fractal_octaves = 4
	ridge.frequency = 0.0016
	ridge.seed = 8181
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array = []
	for ri in range(rings.size()):
		var row: Array = []
		var rr: float = rings[ri]
		for si in range(segs + 1):
			var a: float = TAU * si / segs
			var p := Vector2(cos(a), sin(a)) * rr
			var y: float
			if ri == 0:
				y = tg.natural_height(p.x, p.y) - 0.15
			else:
				var fade: float = clampf((rr - r0) / 120.0, 0.0, 1.0)
				var near_y: float = tg.natural_height(p.x, p.y) if rr < r0 + 140.0 else 0.0
				var dunes: float = ArabianTerrain.dunes(p.x, p.y, 1.0)
				var da: float = absf(wrapf(a - range_bearing, -PI, PI))
				var in_range: float = (1.0 - smoothstep(range_half * 0.6, range_half, da)) * smoothstep(r0 + 400.0, r0 + 1500.0, rr)
				var mtn: float = (ridge.get_noise_2d(p.x, p.y) * 0.5 + 0.5)
				mtn = pow(mtn, 1.6) * range_h * in_range
				y = lerpf(near_y, dunes + 2.0, fade) + mtn
			var rockish: float = clampf(y / maxf(range_h * 0.25, 1.0), 0.0, 1.0)
			var col: Color = sand.lerp(rock, smoothstep(0.15, 0.6, rockish))
			row.append([Vector3(p.x, y, p.y), col])
		grid.append(row)
	for ri in range(rings.size() - 1):
		for si in range(segs):
			var a: Array = grid[ri][si]
			var b: Array = grid[ri][si + 1]
			var c: Array = grid[ri + 1][si + 1]
			var d: Array = grid[ri + 1][si]
			for tri in [[a, c, b], [a, d, c]]:
				var p0: Vector3 = tri[0][0]
				var p1: Vector3 = tri[1][0]
				var p2: Vector3 = tri[2][0]
				var n := (p2 - p0).cross(p1 - p0).normalized()
				if n.y < 0.0:
					n = -n
				for v in tri:
					st.set_color(v[1])
					st.set_normal(n)
					st.add_vertex(v[0])
	st.index()
	st.generate_normals()
	var mesh := st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 1.0
	mesh.surface_set_material(0, m)
	var mi := MeshInstance3D.new()
	mi.name = "FarCountry"
	mi.mesh = save(mesh, "far_country")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	mi.owner = level


## The city on the horizon at `centre` (world xz, 2-3km out): a cluster of towers, tallest in the middle, low
## blocks round them. Built at full size (it is far off), no colliders (named "Skyline").
func skyline(root: Node3D, centre: Vector2, base_y: float, count: int) -> void:
	var pk := ArabianKit.new_kit(1.0)
	var kit := {}
	var r := RandomNumberGenerator.new()
	r.seed = 9393
	for i in range(count):
		var a: float = r.randf() * TAU
		var d: float = pow(r.randf(), 0.7) * 380.0
		var p: Vector2 = centre + Vector2.from_angle(a) * d
		var tall: float = lerpf(320.0, 70.0, d / 380.0) * r.randf_range(0.6, 1.1)
		if i == 0:
			p = centre
			tall = 620.0
		var w: float = clampf(tall * r.randf_range(0.12, 0.18), 16.0, 60.0)
		ArabianKit.at(pk, Transform3D(Basis(Vector3.UP, r.randf() * TAU), Vector3(p.x, base_y, p.y)), func() -> void:
			ArabianKit.skyline_tower(pk, kit, r, tall, w, 1 if i == 0 or r.randf() < 0.3 else 0))
	for i in range(count * 3):
		var p: Vector2 = centre + Vector2.from_angle(r.randf() * TAU) * r.randf_range(80.0, 650.0)
		var w: float = r.randf_range(25.0, 60.0)
		var h: float = r.randf_range(8.0, 30.0)
		pk.block(kit, "stucco", Vector3(p.x - w * 0.5, base_y - 2.0, p.y - w * 0.4), Vector3(p.x + w * 0.5, base_y + h, p.y + w * 0.4),
				ArabianKit.STUCCO.lerp(ArabianKit.MUD_PALE, r.randf() * 0.6))
	var mesh := ArabianKit.commit(pk, kit)
	var mi := MeshInstance3D.new()
	mi.name = "Skyline"
	mi.mesh = save(mesh, "skyline")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	mi.owner = level


## A built thing: `build(pk, kit)` lays it out at life size in its own frame, which is placed at (x, z) on
## `y`, turned `yaw`, grown by PROP_SCALE. One mesh (DressingColliders gives it a trimesh at race time).
func building(root: Node3D, nm: String, x: float, z: float, y: float, yaw: float, build: Callable, range_end := 900.0) -> MeshInstance3D:
	var pk := ArabianKit.new_kit(PROP_SCALE)
	pk.set_frame(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * PROP_SCALE), Vector3(x, y, z)))
	var kit := {}
	build.call(pk, kit)
	var mesh := ArabianKit.commit(pk, kit)
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = save(mesh, nm.to_lower())
	mi.visibility_range_end = range_end
	root.add_child(mi)
	mi.owner = level
	return mi
