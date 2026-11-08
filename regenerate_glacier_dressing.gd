extends Node
## Dresses levels/GlacierHighwayLevel.tscn (the Svartfjell GP's second stage) and saves it. Run headless after
## regenerate_glacier_highway.gd, which builds the lap, the ramps, the far highway, the tunnel and the valley from scratch:
##   Godot --headless --path . res://regenerate_glacier_dressing.tscn
## It replaces everything under GlacierDressing on every run and first deletes its own generated/glacier_dress_* files.
##   - The country (_build_country): the valley's heightfield ends 550m out from its middle. Rows of ground step out from
##     its edge, the first on the edge's own vertices (raycast, so they meet without a gap), carrying the generator's own
##     height function (_alpine_height, from an instance of its script) on and blending into far ranges by COUNTRY_BLEND;
##     south, the open valley runs on down along the far highway (FAR_SOUTH) toward the lowlands. Near the heightfield the
##     rows are drawn in the valley's ground material, past NEAR_D in fjord_mountain.gdshader (Frostpeak Creek's fjord
##     walls); solid out to SOLID_D.
##   - The ground (_build_ground): frostpeak_ground.gdshader on the valley, the tunnel's massif and the near country, with
##     a ground map of its own (the distance to the nearest road's edge, the woods). The valley had alpine_snow's rock,
##     which read as knitted wool.
##   - The woods (_plan_woods, _build_woods): SnowTreeKit's snowy spruce (and a few birches low down) on the valley's
##     lower slopes, off the roads, the far highway and anything steep; saved as the Detail Level's Ultra draws them,
##     SnowWoodsDetail.gd thinning them below it (as on Frostpeak Creek).
const SnowTreeKit = preload("res://SnowTreeKit.gd")
const SnowWoodsDetail = preload("res://SnowWoodsDetail.gd")
const PropKit = preload("res://PropKit.gd")
const HighwayGen = preload("res://regenerate_glacier_highway.gd")

const LEVEL_PATH := "res://levels/GlacierHighwayLevel.tscn"
const DRESSING := "GlacierDressing"
const RES_PREFIX := "glacier_dress_"

## The valley's heightfield (regenerate_glacier_highway.gd: ALPINE_TERRAIN_CENTER, _SIZE, _RES): its corners and cell.
const SQ_MIN := Vector2(-540.0, -570.0)
const SQ_MAX := Vector2(560.0, 530.0)
const CELL := 5.0
## The country's rows: metres out from the heightfield's edge.
const ROWS := [0.0, 5.0, 11.0, 19.0, 30.0, 45.0, 64.0, 88.0, 118.0, 155.0, 200.0, 255.0, 320.0, 400.0, 500.0, 620.0,
		760.0, 930.0, 1130.0, 1370.0, 1650.0, 1980.0, 2370.0, 2830.0, 3380.0, 4000.0]
## Vertices fanned round each corner of the heightfield (its edge's normal turning through 90 degrees).
const CORNER_FAN := 8
## Out to here the country takes the valley's ground material; solid out to SOLID_D.
const NEAR_D := 620.0
const SOLID_D := 200.0
## From the generator's ground (at the edge) to the far ranges, over this distance from the edge.
const COUNTRY_BLEND := Vector2(60.0, 760.0)
## The open valley south: within this of the far highway (and south of SOUTH_FROM) the ranges give way to its floor.
const VALLEY_HALF := Vector2(160.0, 900.0)
const SOUTH_FROM := Vector2(350.0, 800.0)
const ROAD_SHELF := 1.25

## The ground map: MAP_RES texels a side over MAP_SIZE metres from MAP_ORIGIN (the valley and the near country).
const MAP_ORIGIN := Vector2(-1300.0, -1400.0)
const MAP_SIZE := 2800.0
const MAP_RES := 1024
const ROAD_REACH := 40.0
const ROAD_CELL := 16.0

# --- The woods ---
const TREE_STEP := 7.0
const TREE_LINE := 95.0
const TREE_CLEAR := 4.0
const FOREST_CELL := 80.0
const FAR_CELL := 240.0
const TRUNK_COLLIDE_REACH := 40.0
const TREE_SOLID_SHARE := 0.7
const RANK_NEAR_ROAD := 0.55
const RANK_ROAD := Vector2(30.0, 110.0)
const MESH_KINDS := ["spruce", "spruce", "birch", "birch"]

var _level: Node3D
var _gen
var _far: Curve3D
var _far_pts := PackedVector3Array()
var _space: PhysicsDirectSpaceState3D
var _road_pts: Array = []
var _road_hash := {}
var _trees: Array = []
var _ground_mat: ShaderMaterial
var _n_massif := FastNoiseLite.new()
var _n_ridge := FastNoiseLite.new()


func _ready() -> void:
	print("=== Glacier Highway dressing ===")
	var t0 := Time.get_ticks_msec()
	_level = (load(LEVEL_PATH) as PackedScene).instantiate()
	add_child(_level)
	_clear_generated()
	var old := _level.get_node_or_null(DRESSING)
	if old:
		_level.remove_child(old)
		old.free()
	# The generator's own ground and far highway, from an instance of its script (not in the tree: its _ready builds
	# the level).
	_gen = HighwayGen.new()
	_gen.call("_init_noise")
	_far = _gen.call("_open_curve", HighwayGen.FAR_SOUTH)
	var L := _far.get_baked_length()
	var s := 0.0
	while s <= L:
		_far_pts.append(_far.sample_baked(s))
		s += 8.0
	_n_massif.seed = 5521
	_n_massif.frequency = 1.0 / 1400.0
	_n_massif.fractal_octaves = 2
	_n_ridge.seed = 3389
	_n_ridge.frequency = 1.0 / 560.0
	_n_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_n_ridge.fractal_octaves = 5
	for i in 3:
		await get_tree().physics_frame
	_space = _level.get_world_3d().direct_space_state
	_index_roads()
	var root := Node3D.new()
	root.name = DRESSING
	_level.add_child(root)

	_build_country(root)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_plan_woods()
	_build_ground()
	_build_woods(root)

	_set_owner_recursive(_level, _level)
	remove_child(_level)
	var packed := PackedScene.new()
	var err := packed.pack(_level)
	if err != OK:
		push_error("Failed to pack %s: %d" % [LEVEL_PATH, err])
	else:
		err = ResourceSaver.save(packed, LEVEL_PATH)
		if err != OK:
			push_error("Failed to save %s: %d" % [LEVEL_PATH, err])
		else:
			print("Saved %s (%.1fs)" % [LEVEL_PATH, (Time.get_ticks_msec() - t0) / 1000.0])
	_level.free()
	_gen.free()
	get_tree().quit()


func _clear_generated() -> void:
	for f in DirAccess.get_files_at("res://generated"):
		if f.begins_with(RES_PREFIX):
			DirAccess.remove_absolute("res://generated/" + f)


func _save_res(res: Resource, res_name: String) -> Resource:
	var path := "res://generated/" + RES_PREFIX + res_name + ".res"
	res.take_over_path(path)
	ResourceSaver.save(res, path)
	return load(path)


func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	if node != scene_root:
		node.owner = scene_root
	for child in node.get_children():
		if child.owner != null and child.owner != scene_root:
			continue
		_set_owner_recursive(child, scene_root)


# ======================================================================================
#  Ground lookups and roads
# ======================================================================================

## The ground's height and normal straight down at (x, z) (the valley, the massif, the country), or y NAN.
func _ray(x: float, z: float) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 1500.0, z), Vector3(x, -300.0, z))
	q.collision_mask = 1
	var hit := _space.intersect_ray(q)
	return hit


func _index_roads() -> void:
	var curves: Array = [[(_level.get_node("TrackPath") as Path3D).curve, HighwayGen.MAIN_HALF_W]]
	for ap in _level.get_node("AlternativePaths").get_children():
		if ap is Path3D:
			curves.append([(ap as Path3D).curve, HighwayGen.RAMP_HALF_W])
	curves.append([_far, HighwayGen.MAIN_HALF_W])
	for entry in curves:
		var c: Curve3D = entry[0]
		var length := c.get_baked_length()
		var s := 0.0
		while s <= length:
			var p3 := c.sample_baked(s)
			var i := _road_pts.size()
			_road_pts.append(Vector3(p3.x, p3.z, float(entry[1])))
			var k := Vector2i(floori(p3.x / ROAD_CELL), floori(p3.z / ROAD_CELL))
			if not _road_hash.has(k):
				_road_hash[k] = []
			_road_hash[k].append(i)
			s += 2.0
	print("  roads: %d samples" % _road_pts.size())


## Metres from (x, z) to the nearest road's edge in plan (0 on one), looking `reach` metres out.
func _road_edge_d(x: float, z: float, reach: float = 30.0) -> float:
	var best := reach
	var cr := int(ceil((reach + 8.0) / ROAD_CELL))
	var cx := floori(x / ROAD_CELL)
	var cz := floori(z / ROAD_CELL)
	for i in range(cx - cr, cx + cr + 1):
		for j in range(cz - cr, cz + cr + 1):
			var k := Vector2i(i, j)
			if not _road_hash.has(k):
				continue
			for idx in _road_hash[k]:
				var rp: Vector3 = _road_pts[idx]
				var d := Vector2(rp.x - x, rp.y - z).length() - rp.z
				if d < best:
					best = d
	return maxf(best, 0.0)


## The far highway's nearest sample to (x, z): [distance in plan, its height].
func _far_near(x: float, z: float) -> Vector2:
	var best := INF
	var y := 0.0
	for p in _far_pts:
		var d := Vector2(p.x - x, p.z - z).length_squared()
		if d < best:
			best = d
			y = p.y
	return Vector2(sqrt(best), y)


# ======================================================================================
#  The country round the valley
# ======================================================================================

## The far country: ranges everywhere (higher the further out, broken by ridges, lower toward the lowlands in the south),
## and the open valley's floor along the far highway south of the lap.
func _far_h(x: float, z: float, far: Vector2) -> float:
	var massif := clampf(_n_massif.get_noise_2d(x, z) * 0.5 + 0.5, 0.0, 1.0)
	var ridge := clampf(_n_ridge.get_noise_2d(x, z) * 0.5 + 0.5, 0.0, 1.0)
	var r := Vector2(x - 10.0, z + 20.0).length()
	var mountains := (210.0 + 520.0 * pow(massif, 1.3)) * (0.75 + 0.45 * ridge) * smoothstep(300.0, 1600.0, r) + 140.0 * ridge
	mountains *= lerpf(1.0, 0.42, smoothstep(1500.0, 3800.0, z))
	var valley: float = (1.0 - smoothstep(VALLEY_HALF.x, VALLEY_HALF.y, far.x)) * smoothstep(SOUTH_FROM.x, SOUTH_FROM.y, z)
	var floor_h: float = far.y - 1.5 + 22.0 * ridge * smoothstep(60.0, 400.0, far.x)
	return lerpf(mountains, floor_h, valley)


## The country's height `d` metres out from the heightfield's edge at (x, z).
func _country_h(x: float, z: float, d: float) -> float:
	var near: float = _gen.call("_alpine_height", x, z)
	var far := _far_near(x, z)
	var h := lerpf(near, _far_h(x, z, far), smoothstep(COUNTRY_BLEND.x, COUNTRY_BLEND.y, d))
	# The far highway's shelf.
	if far.x < 60.0:
		h = lerpf(h, far.y - ROAD_SHELF, 1.0 - smoothstep(14.0, 60.0, far.x))
	return h


## The heightfield's edge, walked round outward-facing: [point (x, z), outward normal, side]. Every edge vertex of the
## heightfield's grid, and CORNER_FAN fanned normals at each corner.
func _perimeter() -> Array:
	var out: Array = []
	var sides := [
		[Vector2(SQ_MIN.x, SQ_MIN.y), Vector2(SQ_MAX.x, SQ_MIN.y), Vector2(0, -1)],  # north
		[Vector2(SQ_MAX.x, SQ_MIN.y), Vector2(SQ_MAX.x, SQ_MAX.y), Vector2(1, 0)],   # east
		[Vector2(SQ_MAX.x, SQ_MAX.y), Vector2(SQ_MIN.x, SQ_MAX.y), Vector2(0, 1)],   # south
		[Vector2(SQ_MIN.x, SQ_MAX.y), Vector2(SQ_MIN.x, SQ_MIN.y), Vector2(-1, 0)],  # west
	]
	for si in range(4):
		var a: Vector2 = sides[si][0]
		var b: Vector2 = sides[si][1]
		var n: Vector2 = sides[si][2]
		var steps := int(round(a.distance_to(b) / CELL))
		for k in range(steps):
			out.append([a.lerp(b, float(k) / float(steps)), n, si])
		# The corner at b: the normal turning from this side's to the next one's.
		var n2: Vector2 = sides[(si + 1) % 4][2]
		for f in range(CORNER_FAN + 1):
			var t := float(f) / float(CORNER_FAN)
			var a0 := n.angle()
			var a1 := a0 + angle_difference(a0, n2.angle()) * t
			out.append([b, Vector2(cos(a1), sin(a1)), si])
	return out


func _build_country(root: Node3D) -> void:
	var t0 := Time.get_ticks_msec()
	var node := Node3D.new()
	node.name = "Country"
	root.add_child(node)
	var per := _perimeter()
	var np := per.size()
	var nr := ROWS.size()
	var pts := PackedVector3Array()
	pts.resize(np * nr)
	var misses := 0
	for i in range(np):
		var e: Vector2 = per[i][0]
		var n: Vector2 = per[i][1]
		for r in range(nr):
			var d: float = ROWS[r]
			var p2 := e + n * d
			var h: float
			if r == 0:
				# On the heightfield's own edge, a hair inside so the ray can't slip past it.
				var inward := e - n * 0.02
				var hit := _ray(inward.x, inward.y)
				if hit.is_empty():
					misses += 1
					h = _gen.call("_alpine_height", e.x, e.y)
				else:
					h = (hit.position as Vector3).y
			else:
				h = _country_h(p2.x, p2.y, d)
			pts[i * nr + r] = Vector3(p2.x, h, p2.y)
	var nrms := PackedVector3Array()
	nrms.resize(pts.size())
	for i in range(np):
		for r in range(nr):
			var p := pts[i * nr + r]
			var pl := pts[((i + np - 1) % np) * nr + r]
			var pr := pts[((i + 1) % np) * nr + r]
			var pi := pts[i * nr + maxi(r - 1, 0)]
			var po := pts[i * nr + mini(r + 1, nr - 1)]
			var nn := (po - pi).cross(pr - pl)
			if nn.length_squared() < 1e-8:
				nn = Vector3.UP
			nn = nn.normalized()
			if nn.y < 0.0:
				nn = -nn
			nrms[i * nr + r] = nn
	var far_mat := ShaderMaterial.new()
	far_mat.shader = load("res://fjord_mountain.gdshader")
	far_mat.set_shader_parameter("rock_albedo", load("res://materials/dark_canyon_rock.png"))
	far_mat.set_shader_parameter("water_y", -500.0)
	var saved_far: Material = _save_res(far_mat, "country_far_mat")
	var col_faces := PackedVector3Array()
	var tris := 0
	for side in range(4):
		var near_st := SurfaceTool.new()
		near_st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var far_st := SurfaceTool.new()
		far_st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(np):
			if int(per[i][2]) != side:
				continue
			var j := (i + 1) % np
			for r in range(nr - 1):
				var a := pts[i * nr + r]
				var b := pts[j * nr + r]
				var c := pts[i * nr + r + 1]
				var dd := pts[j * nr + r + 1]
				var na := nrms[i * nr + r]
				var nb := nrms[j * nr + r]
				var nc := nrms[i * nr + r + 1]
				var nd := nrms[j * nr + r + 1]
				var st: SurfaceTool = near_st if float(ROWS[r + 1]) <= NEAR_D else far_st
				for tri in [[a, b, c, na, nb, nc], [b, dd, c, nb, nd, nc]]:
					var p0: Vector3 = tri[0]
					var p1: Vector3 = tri[1]
					var p2: Vector3 = tri[2]
					if (p2 - p0).cross(p1 - p0).length_squared() < 1e-6:
						continue
					var n0: Vector3 = tri[3]
					var n1: Vector3 = tri[4]
					var n2: Vector3 = tri[5]
					# Front faces wind clockwise seen from above: (c - a) x (b - a) points up.
					if (p2 - p0).cross(p1 - p0).y < 0.0:
						var tp := p1
						p1 = p2
						p2 = tp
						var tn := n1
						n1 = n2
						n2 = tn
					for v in [[p0, n0], [p1, n1], [p2, n2]]:
						st.set_normal(v[1])
						st.add_vertex(v[0])
					tris += 1
					if float(ROWS[r + 1]) <= SOLID_D:
						col_faces.append(p0)
						col_faces.append(p1)
						col_faces.append(p2)
		for pair in [[near_st, "near"], [far_st, "far"]]:
			var mesh := (pair[0] as SurfaceTool).commit()
			if mesh.get_surface_count() == 0:
				continue
			mesh.surface_set_material(0, saved_far)
			var mi := MeshInstance3D.new()
			mi.name = "CountryGround_%d_%s" % [side, pair[1]]
			mi.mesh = _save_res(mesh, "country_%d_%s" % [side, pair[1]])
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if pair[1] == "far" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			mi.set_meta(&"near_ground", pair[1] == "near")
			node.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "CountrySolid"
	body.set_meta(&"surface", "snow")
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(col_faces)
	var cs := CollisionShape3D.new()
	cs.shape = _save_res(shape, "country_collision")
	body.add_child(cs)
	node.add_child(body)
	print("  country: %d edge points x %d rows, %d triangles, %d edge rays missed (%.1fs)" % [np, nr, tris, misses,
			(Time.get_ticks_msec() - t0) / 1000.0])


# ======================================================================================
#  The ground material
# ======================================================================================

func _bake_ground_map() -> ImageTexture:
	var texel := MAP_SIZE / float(MAP_RES)
	var road := PackedFloat32Array()
	road.resize(MAP_RES * MAP_RES)
	road.fill(ROAD_REACH)
	var woods := PackedFloat32Array()
	woods.resize(MAP_RES * MAP_RES)
	for rp in _road_pts:
		var reach: float = ROAD_REACH + rp.z
		var cx: float = (rp.x - MAP_ORIGIN.x) / texel
		var cz: float = (rp.y - MAP_ORIGIN.y) / texel
		var rt: int = int(ceil(reach / texel))
		for j in range(maxi(0, int(cz) - rt), mini(MAP_RES - 1, int(cz) + rt) + 1):
			var wz: float = MAP_ORIGIN.y + (float(j) + 0.5) * texel
			var dz2: float = (wz - rp.y) * (wz - rp.y)
			var row := j * MAP_RES
			for i in range(maxi(0, int(cx) - rt), mini(MAP_RES - 1, int(cx) + rt) + 1):
				var wx: float = MAP_ORIGIN.x + (float(i) + 0.5) * texel
				var d: float = sqrt((wx - rp.x) * (wx - rp.x) + dz2) - rp.z
				if d < road[row + i]:
					road[row + i] = d
	for t in _trees:
		var p: Vector3 = (t["xf"] as Transform3D).origin
		var r: float = float(t["crown"]) * 1.25
		var cx2: float = (p.x - MAP_ORIGIN.x) / texel
		var cz2: float = (p.z - MAP_ORIGIN.y) / texel
		var rt2: int = int(ceil(r / texel))
		for j in range(maxi(0, int(cz2) - rt2), mini(MAP_RES - 1, int(cz2) + rt2) + 1):
			var wz2: float = MAP_ORIGIN.y + (float(j) + 0.5) * texel
			for i in range(maxi(0, int(cx2) - rt2), mini(MAP_RES - 1, int(cx2) + rt2) + 1):
				var wx2: float = MAP_ORIGIN.x + (float(i) + 0.5) * texel
				var d2: float = Vector2(wx2 - p.x, wz2 - p.z).length() / r
				if d2 < 1.0:
					woods[j * MAP_RES + i] = maxf(woods[j * MAP_RES + i], pow(1.0 - d2, 0.6))
	var data := PackedByteArray()
	data.resize(MAP_RES * MAP_RES * 4)
	for k in range(MAP_RES * MAP_RES):
		data[k * 4] = int(clampf(maxf(road[k], 0.0) / ROAD_REACH, 0.0, 1.0) * 255.0 + 0.5)
		data[k * 4 + 1] = int(clampf(woods[k], 0.0, 1.0) * 255.0 + 0.5)
		data[k * 4 + 2] = 0
		data[k * 4 + 3] = 255
	var img := Image.create_from_data(MAP_RES, MAP_RES, false, Image.FORMAT_RGBA8, data)
	return _save_res(ImageTexture.create_from_image(img), "ground_map")


## frostpeak_ground.gdshader on the valley's chunks, the tunnel's massif and the near country.
func _build_ground() -> void:
	var m := ShaderMaterial.new()
	m.shader = load("res://frostpeak_ground.gdshader")
	m.set_shader_parameter("ground_map", _bake_ground_map())
	m.set_shader_parameter("map_origin", MAP_ORIGIN)
	m.set_shader_parameter("map_size", MAP_SIZE)
	m.set_shader_parameter("road_reach", ROAD_REACH)
	m.set_shader_parameter("rock_albedo", load("res://materials/dark_canyon_rock.png"))
	m.set_shader_parameter("rock_normal", load("res://materials/dark_canyon_rock_normal.png"))
	m.set_shader_parameter("snow_normal", load("res://materials/sand_normal.png"))
	m.set_shader_parameter("water_y", -500.0)
	# The massif's faces stand right over the overpass: smaller blocks, less contrast between them.
	m.set_shader_parameter("block_shade", 0.16)
	# The valley's walls lie near 45 degrees, right at Frostpeak's 0.7: whole hillsides came out mottled.
	m.set_shader_parameter("snow_slope", 0.62)
	m.set_shader_parameter("face_weight", 0.4)
	m.set_shader_parameter("fine_blocks", 1.0)
	_ground_mat = _save_res(m, "ground_mat")
	# The country's rows are tens of metres apart: by their faces' own facing whole triangles turned to rock.
	var cm := m.duplicate() as ShaderMaterial
	cm.set_shader_parameter("face_weight", 0.0)
	var country_mat: ShaderMaterial = _save_res(cm, "country_ground_mat")
	var n := 0
	for path in ["TerrainEnvironment/AlpineMountains/GlacierValley", "TerrainEnvironment/AlpineMountains/TunnelMassif"]:
		var base := _level.get_node_or_null(path)
		if base == null:
			push_error("no %s" % path)
			continue
		for mi in base.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = _ground_mat
			n += 1
	for mi in _level.get_node(DRESSING + "/Country").get_children():
		if mi is MeshInstance3D and mi.get_meta(&"near_ground", false):
			(mi as MeshInstance3D).material_override = country_mat
	print("  ground material on %d valley and massif meshes" % n)


# ======================================================================================
#  The woods
# ======================================================================================

func _plan_woods() -> void:
	var t0 := Time.get_ticks_msec()
	var forest := FastNoiseLite.new()
	forest.seed = 7703
	forest.frequency = 0.0075
	forest.fractal_octaves = 3
	var rng := RandomNumberGenerator.new()
	rng.seed = 33017
	var rank_rng := RandomNumberGenerator.new()
	rank_rng.seed = 991
	var counts := {"spruce": 0, "birch": 0}
	var lo := SQ_MIN - Vector2.ONE * (SOLID_D - 10.0)
	var hi := SQ_MAX + Vector2.ONE * (SOLID_D - 10.0)
	var x := lo.x
	while x <= hi.x:
		var z := lo.y
		while z <= hi.y:
			var px: float = x + rng.randf_range(-0.45, 0.45) * TREE_STEP
			var pz: float = z + rng.randf_range(-0.45, 0.45) * TREE_STEP
			z += TREE_STEP
			var roll := rng.randf()
			var f: float = forest.get_noise_2d(px, pz)
			var dens: float = lerpf(0.0, 0.85, smoothstep(0.0, 0.32, f))
			if roll > dens:
				continue
			var hit := _ray(px, pz)
			if hit.is_empty():
				continue
			var hn: Vector3 = hit.normal
			var hp: Vector3 = hit.position
			var col_name := str((hit.collider as Node).name)
			if not (col_name == "GlacierValley" or col_name == "TunnelMassif" or col_name == "CountrySolid"):
				continue
			if hn.y < 0.78 or hp.y > TREE_LINE:
				continue
			var low: bool = hp.y < 12.0
			var kind := "birch" if low and rng.randf() < 0.25 else "spruce"
			var v: int = (0 if rng.randf() < 0.6 else 1) if kind == "spruce" else rng.randi() % 2
			var mi: int = (0 if kind == "spruce" else 2) + v
			var sc: float = (rng.randf_range(1.0, 1.7) if v == 0 else rng.randf_range(0.95, 1.45)) if kind == "spruce" else rng.randf_range(0.72, 1.0)
			var crown: float = (3.75 if v == 0 else 3.55) * sc if kind == "spruce" else 3.9 * sc
			var rd := _road_edge_d(px, pz, 40.0)
			if rd < crown + TREE_CLEAR:
				continue
			var lean := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.04))
			var xf := Transform3D(lean * Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.92, 1.12), sc)),
					hp + Vector3.DOWN * 0.3)
			var rank: float = rank_rng.randf() * lerpf(RANK_NEAR_ROAD, 1.0, smoothstep(RANK_ROAD.x, RANK_ROAD.y, _road_edge_d(px, pz, RANK_ROAD.y)))
			_trees.append({"xf": xf, "mi": mi, "kind": kind, "rd": rd, "rank": rank, "crown": crown, "scale": sc})
			counts[kind] += 1
		x += TREE_STEP
	var shown := []
	for share in SnowWoodsDetail.TREE_SHARE:
		shown.append(_trees.filter(func(t: Dictionary) -> bool: return float(t["rank"]) < share).size())
	print("  woods planned: %s, drawn Off..Ultra %s (%.1fs)" % [str(counts), str(shown), (Time.get_ticks_msec() - t0) / 1000.0])


func _cell(p: Vector3, size: float, mi: int) -> Vector3i:
	return Vector3i(floori(p.x / size), floori(p.z / size), mi)


func _add_to(cells: Dictionary, k: Vector3i, tree: Dictionary) -> void:
	if not cells.has(k):
		cells[k] = []
	cells[k].append(tree)


func _multimesh(rich: Mesh, light: Mesh, trees: Array, node_name: String) -> MultiMeshInstance3D:
	var order: Array = trees.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["rank"]) < float(b["rank"]))
	var ranks := PackedFloat32Array()
	var xfs: Array = []
	for t in order:
		ranks.append(float(t["rank"]))
		xfs.append(t["xf"])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = rich
	mm.instance_count = xfs.size()
	mm.buffer = PropKit.transform_buffer(xfs)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.set_meta(&"ranks", ranks)
	if light != rich:
		mmi.set_meta(&"rich_mesh", rich)
		mmi.set_meta(&"light_mesh", light)
	return mmi


## The woods in Frostpeak Creek's layers (see regenerate_frostpeak_dressing.gd's _build_woods).
func _build_woods(root: Node3D) -> void:
	var t0 := Time.get_ticks_msec()
	var node := Node3D.new()
	node.name = "Woods"
	root.add_child(node)
	var kit := SnowTreeKit.new()
	kit.save_res = func(res: Resource, n: String) -> Resource: return _save_res(res, n)
	var meshes: Array = []
	for mi in range(MESH_KINDS.size()):
		var v: int = mi % 2
		if MESH_KINDS[mi] == "spruce":
			meshes.append([_save_res(kit.spruce_mesh(v, 0, true), "spruce_%d_rich" % v), _save_res(kit.spruce_mesh(v, 0), "spruce_%d" % v),
					_save_res(kit.spruce_mesh(v, 1, true), "spruce_%d_far_rich" % v), _save_res(kit.spruce_mesh(v, 1), "spruce_%d_far" % v)])
		else:
			var bn: Mesh = _save_res(kit.birch_mesh(v, 0), "birch_%d" % v)
			var bf: Mesh = _save_res(kit.birch_mesh(v, 1), "birch_%d_far" % v)
			meshes.append([bn, bn, bf, bf])
	var band_r: Array = meshes.map(func(m: Array) -> float: return SnowTreeKit.WoodlandBuilder.band_radius(m[0], 0.3, 2.0))
	var near := {}
	var far := {}
	var trunks: Array = []
	for t in _trees:
		var xf: Transform3D = t["xf"]
		var mi: int = t["mi"]
		_add_to(near, _cell(xf.origin, FOREST_CELL, mi), t)
		_add_to(far, _cell(xf.origin, FAR_CELL, mi), t)
		if float(t["rd"]) < TRUNK_COLLIDE_REACH:
			var sc: float = t["scale"]
			var tr: float = (0.36 if t["kind"] == "spruce" else 0.21) * sc
			trunks.append([xf.origin, maxf(maxf(tr * 1.25, 0.35), TREE_SOLID_SHARE * float(band_r[mi]) * sc), 5.0 * sc, t["rank"]])
	var near_end: float = SnowTreeKit.WoodlandBuilder.TREE_NEAR + SnowTreeKit.WoodlandBuilder.TREE_FADE * 0.5 \
			+ SnowTreeKit.WoodlandBuilder.TREE_FADE_JITTER + FOREST_CELL * 0.72
	var far_begin: float = maxf(0.0, SnowTreeKit.WoodlandBuilder.TREE_NEAR - SnowTreeKit.WoodlandBuilder.TREE_FADE * 0.5
			- SnowTreeKit.WoodlandBuilder.TREE_FADE_JITTER - FAR_CELL * 0.72)
	for k in near.keys():
		var m: Array = meshes[k.z]
		var mmi := _multimesh(m[0], m[1], near[k], "Tree_%d_%d_%d" % [k.x, k.y, k.z])
		mmi.visibility_range_end = near_end
		mmi.visibility_range_end_margin = 10.0
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		node.add_child(mmi)
		var proxy := _multimesh(m[2], m[3], near[k], "TreeShadow_%d_%d_%d" % [k.x, k.y, k.z])
		proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		proxy.visibility_range_end = near_end
		proxy.visibility_range_end_margin = 10.0
		proxy.visible = false
		node.add_child(proxy)
	for k in far.keys():
		var m2: Array = meshes[k.z]
		var mmi2 := _multimesh(m2[2], m2[3], far[k], "TreeFar_%d_%d_%d" % [k.x, k.y, k.z])
		mmi2.visibility_range_begin = far_begin
		mmi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mmi2)
	var bodies := {}
	for tk in trunks:
		var p3: Vector3 = tk[0]
		var bk := Vector2i(floori(p3.x / FOREST_CELL), floori(p3.z / FOREST_CELL))
		if not bodies.has(bk):
			var body := StaticBody3D.new()
			body.name = "TreeTrunks_%d_%d" % [bk.x, bk.y]
			body.set_meta(&"surface", "wood")
			node.add_child(body)
			bodies[bk] = body
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = tk[1]
		cyl.height = tk[2]
		cs.shape = cyl
		cs.position = p3 + Vector3(0.0, cyl.height * 0.5, 0.0)
		cs.set_meta(&"rank", tk[3])
		bodies[bk].add_child(cs)
	var detail := Node3D.new()
	detail.name = "SnowWoodsDetail"
	detail.set_script(load("res://SnowWoodsDetail.gd"))
	detail.set("lod_materials", kit.lod_materials())
	detail.set("forest_cell", FOREST_CELL)
	detail.set("ground_material", _ground_mat)
	node.add_child(detail)
	print("  woods: %d near cells, %d far, %d trunk colliders (%.1fs)" % [near.size(), far.size(), trunks.size(),
			(Time.get_ticks_msec() - t0) / 1000.0])
