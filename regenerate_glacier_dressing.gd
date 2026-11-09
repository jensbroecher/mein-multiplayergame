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
const BaustelleKit = preload("res://BaustelleKit.gd")
const FjordVillageKit = preload("res://FjordVillageKit.gd")
const CampKit = preload("res://CampKit.gd")
const RoadsideKit = preload("res://RoadsideKit.gd")
const YardKit = preload("res://YardKit.gd")

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

# --- The works: the far highway being carried on north over the hairpin ---
## People-sized things (the crane, machines, cabins) are built at life size and grown by this, as on every stage.
const PROP_SCALE := 1.6
## The new viaduct's line north of the hairpin (x) and its deck's height (the far highway's tip, FAR_SOUTH's first point,
## is its end south of the hairpin): the next pier carrying a balanced cantilever WORKS_T_HALF either way, then a pier
## with only its crosshead, one half poured, a footing with its starter bars, across the hairpin's infield.
const WORKS_X := -110.0
const WORKS_DECK_Y := 16.5
const WORKS_T_Z := 298.0
const WORKS_T_HALF := 12.0
const WORKS_PIERS := [[264.0, "cap"], [230.0, "half"], [196.0, "footing"]]
## The works' pieces keep this far (in plan) from any lap's edge; trees keep out of WORKS_KEEP (x, z, half x, half z): the
## works, the yard and the avalanche gallery's snow-covered roof up the slope.
const WORKS_LAP_CLEAR := 5.0
const WORKS_KEEP := [Vector4(-110.0, 250.0, 13.0, 70.0), Vector4(-106.0, 385.0, 46.0, 48.0), Vector4(226.0, -237.0, 20.0, 40.0), Vector4(78.0, -104.0, 42.0, 30.0)]
# --- The avalanche gallery ---
## Over the lap where it runs south along the east flank in its cutting (from the lap's nearest point to GALLERY_FROM to
## its nearest to GALLERY_TO): the roof's underside GALLERY_CLEAR over the road (the tunnel's), its slab GALLERY_SLAB
## thick, the uphill wall GALLERY_WALL past the road's edge, columns every GALLERY_BAY on the valley side.
const GALLERY_FROM := Vector2(209.0, -268.0)
const GALLERY_TO := Vector2(198.0, -206.0)
const GALLERY_CLEAR := 9.5
const GALLERY_SLAB := 0.9
const GALLERY_WALL := 1.4
const GALLERY_BAY := 7.0

# --- The mountain lodge ---
## Svartfjell Fjellstue's rest area on the valley floor east of the tunnel's approach (the highway generator's PADS[0]):
## its frame's origin on the pad's middle, x along the lodge's front, +z from the lodge toward the lot and the road.
const LODGE_AT := Vector2(78.0, -104.0)
const LODGE_YAW := 0.0
## The lodge's name board standing on its front roof slope (life size, in the house's frame: x along its front, z out of
## it, the floor at y 0.5; the roof's front plane rises from y 6.2 at z 0 by FjordVillageKit.PITCH a metre in), and the
## KAFE blade by the door, between the floors where no window is: their centres, sizes and thicknesses. On the wall
## between the window rows the name ran across the windows.
const LODGE_SIGN_C := Vector3(0.0, 8.15, -1.3)
const LODGE_SIGN_SIZE := Vector2(10.2, 1.25)
const LODGE_SIGN_T := 0.08
const LODGE_BLADE_C := Vector3(3.95, 3.0, 0.62)
const LODGE_BLADE_SIZE := Vector2(1.0, 0.62)
const LODGE_BLADE_T := 0.05

# --- The snow poles ---
## Plough markers every SNOW_POLE_STEP along both sides of every road where it runs at ground level, SNOW_POLE_OUT past
## its edge (just behind the barriers); not past SNOW_POLE_REACH from the heightfield's middle.
const SNOW_POLE_STEP := 18.0
const SNOW_POLE_OUT := 1.6
const SNOW_POLE_REACH := 1100.0
const SNOW_POLE_CELL := 240.0

# --- The glacier ---
## The ice in the glacier's valley (regenerate_glacier_highway.gd's glacier_trough): rows GLACIER_STEP apart from its
## snout (GLACIER_SNOUT_BACK north of the valley's mouth) up to where the valley no longer cuts GLACIER_MIN_CUT deep, at
## most GLACIER_MAX_LEN; GLACIER_COLS across GLACIER_WIDTH of the valley's width.
const GLACIER_SNOUT_BACK := 16.0
const GLACIER_STEP := 4.0
const GLACIER_COLS := 40
const GLACIER_WIDTH := 0.72
const GLACIER_MAX_LEN := 900.0
const GLACIER_MIN_CUT := 25.0
const STEEL_RED := Color(0.72, 0.16, 0.10)
const PLY := Color(0.78, 0.62, 0.30)

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
	_build_works(root)
	_build_glacier(root)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_plan_woods()
	_build_ground()
	_build_woods(root)
	_build_snow_poles(root)
	_build_gallery(root)
	_build_rest_stop(root)

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
	var near: float = _gen.call("_alpine_base", x, z)
	var far := _far_near(x, z)
	var h := lerpf(near, _far_h(x, z, far), smoothstep(COUNTRY_BLEND.x, COUNTRY_BLEND.y, d))
	# The glacier's valley runs on into the ranges (cut after the blend, so it doesn't fade with the valley's ground).
	h = _gen.glacier_trough(h, x, z)
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
	m.set_shader_parameter("block_shade", 0.07)
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
			if _in_works(px, pz, crown):
				continue
			if _on_glacier(px, pz, crown + 6.0):
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


# ======================================================================================
#  The works: the far highway carried on north over the hairpin
# ======================================================================================

## Inside one of WORKS_KEEP's rectangles, grown by `margin`.
func _in_works(x: float, z: float, margin: float) -> bool:
	for r in WORKS_KEEP:
		if absf(x - r.x) < r.z + margin and absf(z - r.y) < r.w + margin:
			return true
	return false


## The far highway (FAR_SOUTH) is being carried on north over the lap's hairpin. Its new viaduct ends in the air south of
## the hairpin; on the far side, in the hairpin's infield, the next pier stands with its balanced cantilever reaching out
## both ways, and beyond it a pier with only its crosshead, one half poured and a footing. A form traveller hangs off each
## deck end over the gap with the next segment's formwork and reinforcement in it, starter bars stick out of the ends, and
## temporary railings line the bare deck. South of the hairpin the tower crane, the yard (cabins, materials, a mixer
## truck, a dumper), an excavator at the footing, floodlights and the project's board. Everything stands clear of the
## lap (`_check_works_clear`).
func _build_works(root: Node3D) -> void:
	var t0 := Time.get_ticks_msec()
	var node := Node3D.new()
	node.name = "Anlegg"
	root.add_child(node)
	var conc: Material = null
	var cap := _level.find_child("CrossheadBeam", true, false) as MeshInstance3D
	if cap:
		conc = cap.material_override
	var foot_pts: Array = []
	# --- The spans, at the bridge's own scale ---
	var pkb: PropKit = BaustelleKit.new_kit(1.0)
	var kb := {}
	var tip: Vector3 = _far.sample_baked(0.0)
	var back: Vector3 = _far.sample_baked(4.0) - tip
	back.y = 0.0
	back = back.normalized()
	# The tip's frame: -z out over the gap, x across the deck, y up from the road's surface.
	var xf_tip := Transform3D(Basis(Vector3(-back.z, 0.0, back.x), Vector3.UP, back), tip)
	pkb.set_frame(xf_tip)
	_deck_end(pkb, kb, 8.0, 1.15)
	_traveller(pkb, kb)
	_temp_rails_far(pkb, kb)
	var xf_t := Transform3D(Basis(), Vector3(WORKS_X, WORKS_DECK_Y, WORKS_T_Z))
	pkb.set_frame(xf_t)
	_cantilever(pkb, kb, WORKS_T_HALF)
	for dir in [-1.0, 1.0]:
		# Each tip's frame: -z out over the next span.
		var b := Basis() if dir < 0.0 else Basis(Vector3.UP, PI)
		pkb.set_frame(xf_t * Transform3D(b, Vector3(0, 0, dir * WORKS_T_HALF)))
		_deck_end(pkb, kb, 8.0, 1.2)
		_traveller(pkb, kb)
	foot_pts.append([Vector2(WORKS_X, WORKS_T_Z), 8.5])
	_gen.call("_build_viaduct_pier", node, Vector3(WORKS_X, WORKS_DECK_Y, WORKS_T_Z), Vector3(0, 0, -1), Vector3(1, 0, 0), 8.0,
			WORKS_DECK_Y, conc)
	for pr in WORKS_PIERS:
		var z: float = pr[0]
		foot_pts.append([Vector2(WORKS_X, z), 7.0])
		match String(pr[1]):
			"cap":
				_gen.call("_build_viaduct_pier", node, Vector3(WORKS_X, WORKS_DECK_Y, z), Vector3(0, 0, -1), Vector3(1, 0, 0), 8.0,
						WORKS_DECK_Y, conc)
			"half":
				_half_pier(node, pkb, kb, z, conc)
			"footing":
				_footing(node, pkb, kb, z, conc)
	pkb.reset_frame()
	var mi := MeshInstance3D.new()
	mi.name = "Anlegg_Spenn"
	mi.mesh = _save_res(BaustelleKit.commit(pkb, kb), "works_spans")
	node.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "Anlegg_Spenn_Solid"
	node.add_child(body)
	# The cantilever's deck and the deck ends' formwork platforms: a cart flying the gap meets concrete.
	_box_shape(body, xf_t * Transform3D(Basis(), Vector3(0, -0.75, 0)), Vector3(16.0, 1.5, WORKS_T_HALF * 2.0 + 5.0))
	# --- The site, at life size ---
	_build_site(node, foot_pts)
	_check_works_clear(foot_pts)
	print("  works: the far highway's new viaduct and its site (%.1fs)" % ((Time.get_ticks_msec() - t0) / 1000.0))


func _box_shape(body: StaticBody3D, xf: Transform3D, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.transform = xf
	body.add_child(cs)


## A deck's end in its frame (-z out over the gap, the road's surface at y 0): the construction joint's face, set 3cm back
## so it never shares a plane with the deck's own end, and the starter bars sticking out of the slab and the box's webs.
func _deck_end(pk: PropKit, kit: Dictionary, half: float, depth: float) -> void:
	BaustelleKit._blk(pk, kit, "concrete", Vector3(-half + 0.02, -0.32, 0.03), Vector3(half - 0.02, -0.05, 0.4), Color(0.70, 0.70, 0.69))
	BaustelleKit._blk(pk, kit, "concrete", Vector3(-3.9, -depth, 0.03), Vector3(3.9, -0.32, 0.4), Color(0.66, 0.66, 0.65))
	var rust := Color(0.42, 0.22, 0.12)
	var x := -half + 0.3
	while x <= half - 0.3:
		for y in [-0.1, -0.25]:
			BaustelleKit._bar(pk, kit, "rusty", Vector3(x, y, 0.1), Vector3(x, y, -1.3), 0.03, 0.03, rust)
		x += 0.35
	x = -3.6
	while x <= 3.6:
		for y in [-0.55, -0.85]:
			BaustelleKit._bar(pk, kit, "rusty", Vector3(x, y, 0.1), Vector3(x, y, -1.1), 0.03, 0.03, rust)
		x += 0.4


## A form traveller on a deck's end (its frame as _deck_end's): two red triangular frames on rails along the deck, their
## front post at the end and their noses reaching out over the gap, cross beams, hangers carrying the next segment's
## formwork under it (the bottom platform, the webs' and the slab's forms with the reinforcement mat in them), railings
## round the platforms.
func _traveller(pk: PropKit, kit: Dictionary) -> void:
	var red := STEEL_RED
	var dark := Color(0.16, 0.16, 0.17)
	for sx in [-1.0, 1.0]:
		var x: float = sx * 4.4
		BaustelleKit._blk(pk, kit, "steel", Vector3(x - 0.25, 0.0, 7.5), Vector3(x + 0.25, 0.18, -0.6), dark)
		BaustelleKit._bar(pk, kit, "bpaint", Vector3(x, 0.4, 7.2), Vector3(x, 0.4, -5.2), 0.45, 0.45, red)
		BaustelleKit._bar(pk, kit, "bpaint", Vector3(x, 0.2, -0.5), Vector3(x, 4.2, -0.5), 0.45, 0.45, red)
		BaustelleKit._bar(pk, kit, "bpaint", Vector3(x, 4.2, -0.5), Vector3(x, 0.6, 7.0), 0.35, 0.35, red)
		BaustelleKit._bar(pk, kit, "bpaint", Vector3(x, 4.2, -0.5), Vector3(x, 0.6, -5.0), 0.35, 0.35, red)
		BaustelleKit._blk(pk, kit, "concrete", Vector3(x - 0.6, 0.18, 6.4), Vector3(x + 0.6, 1.0, 7.6), Color(0.6, 0.6, 0.6))
	BaustelleKit._bar(pk, kit, "bpaint", Vector3(-6.2, 0.85, -5.0), Vector3(6.2, 0.85, -5.0), 0.5, 0.5, red)
	BaustelleKit._bar(pk, kit, "bpaint", Vector3(-5.0, 0.85, 6.9), Vector3(5.0, 0.85, 6.9), 0.4, 0.4, red)
	BaustelleKit._bar(pk, kit, "bpaint", Vector3(-4.4, 4.2, -0.5), Vector3(4.4, 4.2, -0.5), 0.3, 0.3, red)
	# Hangers from the front beam down past the forms to the bottom platform.
	for hx in [-5.6, -2.0, 2.0, 5.6]:
		BaustelleKit._rod(pk, kit, "steel", Vector3(hx, 0.6, -4.9), Vector3(hx, -2.75, -4.9), 0.05, 6, dark)
		BaustelleKit._rod(pk, kit, "steel", Vector3(hx, -0.05, 0.6), Vector3(hx, -2.75, 0.6), 0.05, 6, dark)
	# The bottom platform under the next segment, and its railings.
	BaustelleKit._blk(pk, kit, "steel", Vector3(-6.0, -2.85, 1.0), Vector3(6.0, -2.7, -5.4), Color(0.3, 0.3, 0.31))
	for z in [-5.35]:
		_rail_run(pk, kit, Vector3(-6.0, -2.7, z), Vector3(6.0, -2.7, z), 1.1)
	for sx in [-1.0, 1.0]:
		_rail_run(pk, kit, Vector3(sx * 5.95, -2.7, 0.9), Vector3(sx * 5.95, -2.7, -5.3), 1.1)
	# The next segment's forms: the webs' faces, the slab's soffit and edge boards, plywood on red walers.
	for sx in [-1.0, 1.0]:
		BaustelleKit._blk(pk, kit, "timber", Vector3(sx * 3.95, -1.15, -0.1), Vector3(sx * 4.05, -0.34, -4.6), PLY)
		BaustelleKit._blk(pk, kit, "timber", Vector3(sx * 7.9, -0.38, -0.1), Vector3(sx * 8.0, 0.02, -4.6), PLY)
		for z in [-1.0, -2.3, -3.6]:
			BaustelleKit._bar(pk, kit, "bpaint", Vector3(sx * 4.12, -1.1, z), Vector3(sx * 4.12, -0.4, z), 0.12, 0.12, red)
	BaustelleKit._blk(pk, kit, "timber", Vector3(-7.9, -0.42, -0.1), Vector3(7.9, -0.36, -4.6), PLY)
	BaustelleKit._blk(pk, kit, "timber", Vector3(-3.95, -1.2, -0.1), Vector3(3.95, -1.14, -4.6), PLY)
	# The slab's reinforcement in its form: a mat of bars, and bars along.
	pk.quad(kit, "brebar", [Vector3(-7.8, -0.2, -0.05), Vector3(7.8, -0.2, -0.05), Vector3(7.8, -0.2, -4.55), Vector3(-7.8, -0.2, -4.55)],
			Vector3.UP, Color(0.42, 0.22, 0.12), [Vector2(0, 0), Vector2(15.6, 0), Vector2(15.6, 4.5), Vector2(0, 4.5)])
	# Railings along the slab form's edges.
	for sx in [-1.0, 1.0]:
		_rail_run(pk, kit, Vector3(sx * 7.85, 0.02, -0.2), Vector3(sx * 7.85, 0.02, -4.6), 1.1)
	_rail_run(pk, kit, Vector3(-7.85, 0.02, -4.6), Vector3(7.85, 0.02, -4.6), 1.1)


## A temporary railing from a to b standing `h` high: posts every 2m, a top and a knee rail in red and white, a toe board.
func _rail_run(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, h: float) -> void:
	var length := a.distance_to(b)
	var n := maxi(1, int(ceil(length / 2.0)))
	var stripe := BaustelleKit._a(Color(0.9, 0.1, 0.08), 0.2)
	for i in range(n + 1):
		var p := a.lerp(b, float(i) / float(n))
		BaustelleKit._rod(pk, kit, "steel", p, p + Vector3.UP * h, 0.03, 5, Color(0.55, 0.56, 0.57))
	BaustelleKit._bar(pk, kit, "bpaint", a + Vector3.UP * h, b + Vector3.UP * h, 0.06, 0.06, stripe)
	BaustelleKit._bar(pk, kit, "bpaint", a + Vector3.UP * h * 0.5, b + Vector3.UP * h * 0.5, 0.05, 0.05, stripe)
	BaustelleKit._bar(pk, kit, "timber", a + Vector3.UP * 0.08, b + Vector3.UP * 0.08, 0.03, 0.15, Color(0.8, 0.66, 0.36), Vector3.UP)


## Temporary railings along both edges of the far highway's bare first FAR_BARE metres (it has no barriers yet).
func _temp_rails_far(pk: PropKit, kit: Dictionary) -> void:
	pk.reset_frame()
	for sx in [-1.0, 1.0]:
		var prev := Vector3.INF
		var s := 0.3
		while s <= HighwayGen.FAR_BARE + 2.0:
			var c: Vector3 = _far.sample_baked(s)
			var f: Vector3 = _far.sample_baked(s + 1.0) - c
			f.y = 0.0
			f = f.normalized()
			var p: Vector3 = c + Vector3(-f.z, 0.0, f.x) * (sx * 7.7) + Vector3.UP * 0.02
			if prev != Vector3.INF:
				_rail_run(pk, kit, prev, p, 1.1)
			prev = p
			s += 6.0


## The balanced cantilever over the next pier, in its frame (the deck's top at y 0, x across, z along the line): the top
## slab with its wings and the box below it deepening toward the pier, bare concrete, temporary railings along it.
func _cantilever(pk: PropKit, kit: Dictionary, half: float) -> void:
	var slab := PackedVector2Array([Vector2(-half, -0.3), Vector2(half, -0.3), Vector2(half, 0.0), Vector2(-half, 0.0)])
	BaustelleKit._side_prism(pk, kit, "concrete", slab, -8.0, 8.0, Color(0.72, 0.72, 0.71))
	var box := PackedVector2Array()
	box.append(Vector2(-half, -0.29))
	box.append(Vector2(half, -0.29))
	var n := 12
	for i in range(n + 1):
		var z: float = lerpf(half, -half, float(i) / float(n))
		var t: float = 1.0 - absf(z) / half
		box.append(Vector2(z, -1.2 - 0.45 * t * t))
	BaustelleKit._side_prism(pk, kit, "concrete", box, -3.9, 3.9, Color(0.68, 0.68, 0.67))
	for sx in [-1.0, 1.0]:
		_rail_run(pk, kit, Vector3(sx * 7.7, 0.0, half - 0.2), Vector3(sx * 7.7, 0.0, -half + 0.2), 1.1)


## A pier half poured: its two columns 8m up from their footings, the starter bars of the rest sticking out of their tops,
## a climbing form's platform round each top and a scaffold up to it.
func _half_pier(node: Node3D, pk: PropKit, kit: Dictionary, z: float, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.name = "Anlegg_Soyle_%d" % int(z)
	node.add_child(body)
	for sx in [-1.0, 1.0]:
		var x: float = WORKS_X + sx * 4.4
		var g := _ground_y(x, z)
		var h := 8.0
		var cm := CylinderMesh.new()
		cm.top_radius = 1.0
		cm.bottom_radius = 1.15
		cm.height = h + 1.0
		cm.radial_segments = 16
		var ci := MeshInstance3D.new()
		ci.mesh = cm
		ci.material_override = mat
		ci.position = Vector3(x, g - 1.0 + (h + 1.0) * 0.5, z)
		body.add_child(ci)
		var cs := CollisionShape3D.new()
		var cy := CylinderShape3D.new()
		cy.radius = 1.1
		cy.height = h + 1.0
		cs.shape = cy
		cs.position = ci.position
		body.add_child(cs)
		pk.reset_frame()
		var top := Vector3(x, g + h, z)
		for k in range(14):
			var a := TAU * float(k) / 14.0
			var o := Vector3(cos(a), 0, sin(a)) * 0.82
			BaustelleKit._bar(pk, kit, "rusty", top + o + Vector3.DOWN * 0.3, top + o + Vector3.UP * 2.4, 0.035, 0.035, Color(0.42, 0.22, 0.12))
		# The climbing form's platform and its railing.
		BaustelleKit._blk(pk, kit, "steel", top + Vector3(-1.9, -0.75, -1.9), top + Vector3(1.9, -0.6, 1.9), Color(0.3, 0.3, 0.31))
		for e in [[Vector3(-1.85, -0.6, -1.85), Vector3(1.85, -0.6, -1.85)], [Vector3(1.85, -0.6, -1.85), Vector3(1.85, -0.6, 1.85)],
				[Vector3(1.85, -0.6, 1.85), Vector3(-1.85, -0.6, 1.85)], [Vector3(-1.85, -0.6, 1.85), Vector3(-1.85, -0.6, -1.85)]]:
			_rail_run(pk, kit, top + e[0], top + e[1], 1.0)
		BaustelleKit._blk(pk, kit, "concrete", Vector3(x - 1.6, g - 0.6, z - 1.6), Vector3(x + 1.6, g + 0.4, z + 1.6), Color(0.62, 0.62, 0.61))


## A footing with the columns' starter cages standing out of it, waiting to be poured on.
func _footing(node: Node3D, pk: PropKit, kit: Dictionary, z: float, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.name = "Anlegg_Fundament_%d" % int(z)
	node.add_child(body)
	pk.reset_frame()
	var g := _ground_y(WORKS_X, z)
	BaustelleKit._blk(pk, kit, "concrete", Vector3(WORKS_X - 7.0, g - 0.8, z - 2.6), Vector3(WORKS_X + 7.0, g + 0.5, z + 2.6), Color(0.66, 0.66, 0.65))
	_box_shape(body, Transform3D(Basis(), Vector3(WORKS_X, g - 0.15, z)), Vector3(14.0, 1.3, 5.2))
	for sx in [-1.0, 1.0]:
		var c := Vector3(WORKS_X + sx * 4.4, g + 0.5, z)
		for k in range(14):
			var a := TAU * float(k) / 14.0
			var o := Vector3(cos(a), 0, sin(a)) * 0.85
			BaustelleKit._bar(pk, kit, "rusty", c + o, c + o + Vector3.UP * 3.2, 0.035, 0.035, Color(0.42, 0.22, 0.12))
		for hy in [0.8, 1.6, 2.4]:
			for k in range(14):
				var a0 := TAU * float(k) / 14.0
				var a1 := TAU * float(k + 1) / 14.0
				BaustelleKit._bar(pk, kit, "rusty", c + Vector3(cos(a0), 0, sin(a0)) * 0.85 + Vector3.UP * hy,
						c + Vector3(cos(a1), 0, sin(a1)) * 0.85 + Vector3.UP * hy, 0.03, 0.03, Color(0.42, 0.22, 0.12))


## The ground's height at (x, z).
func _ground_y(x: float, z: float) -> float:
	var hit := _ray(x, z)
	return (hit.position as Vector3).y if not hit.is_empty() else 2.0


## The site south of the hairpin and in its infield, at life size grown by PROP_SCALE: the tower crane (its top slewing
## slowly over the gap: SlewHazard.gd, harmless), the yard's cabins, toilet, skip and materials, a mixer truck and a
## dumper, the excavator at the footing, floodlights and the project's board. One mesh (DressingColliders makes it solid)
## and the crane's top apart.
func _build_site(node: Node3D, foot_pts: Array) -> void:
	var pk: PropKit = BaustelleKit.new_kit(PROP_SCALE)
	var kit := {}
	var junk: Array = []
	var place := func(x: float, z: float, yaw_deg: float, fn: Callable, r: float) -> void:
		var g := _ground_y(x, z)
		pk.set_frame(Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)).scaled(Vector3.ONE * PROP_SCALE), Vector3(x, g, z)))
		fn.call()
		foot_pts.append([Vector2(x, z), r])
	# The crane, west of the far viaduct.
	var crane := Vector2(-138.0, 372.0)
	# Tall enough that its load (BaustelleKit's hook block 14m and the load 17.6m under the jib, life) hangs well over the
	# bridge's formwork and the spruces: on a 30m mast it hung at 22m and swung through both.
	var mast_h := 40.0
	place.call(crane.x, crane.y, 0.0, func(): BaustelleKit.tower_crane_mast(pk, kit, mast_h), 5.0)
	var cg := _ground_y(crane.x, crane.y)
	# The yard east of it.
	place.call(-74.0, 372.0, 90.0, func(): BaustelleKit.site_cabin(pk, kit, junk, true), 6.0)
	place.call(-74.0, 384.0, 90.0, func(): BaustelleKit.site_cabin(pk, kit, junk, false), 6.0)
	place.call(-68.0, 394.0, 0.0, func(): BaustelleKit.portable_toilet(pk, kit), 2.0)
	place.call(-80.0, 404.0, 15.0, func(): BaustelleKit.skip(pk, kit, 3), 4.0)
	place.call(-92.0, 378.0, 90.0, func(): BaustelleKit.rebar_stack(pk, kit, 6.0), 6.0)
	place.call(-90.0, 392.0, 0.0, func(): BaustelleKit.formwork_stack(pk, kit), 3.0)
	place.call(-88.0, 402.0, 80.0, func(): BaustelleKit.formwork_stack(pk, kit), 3.0)
	place.call(-70.0, 410.0, 0.0, func(): BaustelleKit.concrete_pipes(pk, kit, 5), 5.0)
	place.call(-84.0, 418.0, 0.0, func(): BaustelleKit.sand_pile(pk, kit, 3.2, 1.8, 7), 6.0)
	place.call(-76.0, 420.0, 0.0, func(): BaustelleKit.cable_drum(pk, kit), 2.0)
	place.call(-97.0, 360.0, 180.0, func(): BaustelleKit.mixer_truck(pk, kit), 8.0)
	place.call(-124.0, 402.0, 200.0, func(): BaustelleKit.dumper(pk, kit), 4.0)
	place.call(-110.0, 181.0, 175.0, func(): BaustelleKit.excavator(pk, kit, junk); pk.set_frame(pk.xf * Transform3D(Basis(Vector3.UP, 0.6), Vector3(0, BaustelleKit.EXC_RING_Y, 0))); BaustelleKit.excavator_upper(pk, kit), 5.0)
	place.call(-110.0, 214.0, 90.0, func(): BaustelleKit.rebar_stack(pk, kit, 5.0), 5.0)
	# The board facing the hairpin, under the far viaduct's tip.
	var board_at := Vector3(-123.0, _ground_y(-123.0, 352.0), 352.0)
	foot_pts.append([Vector2(board_at.x, board_at.z), 4.0])
	_project_board(node, pk, kit, board_at, deg_to_rad(205.0))
	# Floodlight masts.
	var lights := [Vector2(-96.0, 346.0), Vector2(-125.0, 360.0), Vector2(-110.0, 248.0), Vector2(-101.0, 205.0)]
	for i in range(lights.size()):
		var lp: Vector2 = lights[i]
		foot_pts.append([lp, 1.5])
		_floodlight(node, pk, kit, Vector3(lp.x, _ground_y(lp.x, lp.y), lp.y), i)
	pk.reset_frame()
	var mi := MeshInstance3D.new()
	mi.name = "Anlegg_Plass"
	mi.mesh = _save_res(BaustelleKit.commit(pk, kit), "works_site")
	node.add_child(mi)
	# The crane's top, turning slowly to and fro over the gap.
	var top := Node3D.new()
	top.name = "Anlegg_KranTopp"
	top.set_script(load("res://SlewHazard.gd"))
	top.position = Vector3(crane.x, cg + mast_h * PROP_SCALE, crane.y)
	top.set("centre_deg", -32.0)
	top.set("amplitude_deg", 38.0)
	top.set("move", 34.0)
	top.set("dwell", 16.0)
	top.set("hits", false)
	var tpk: PropKit = BaustelleKit.new_kit(PROP_SCALE)
	var tkit := {}
	BaustelleKit.tower_crane_top(tpk, tkit, [], "rebar")
	var tmi := MeshInstance3D.new()
	tmi.name = "Top"
	tmi.mesh = _save_res(BaustelleKit.commit(tpk, tkit), "works_crane_top")
	tmi.scale = Vector3.ONE * PROP_SCALE
	top.add_child(tmi)
	node.add_child(top)


## The project's board on two posts (life size in `pk`'s units), facing `yaw`: SVARTFJELLVEGEN, the new bridge, its
## builder (all made up).
func _project_board(node: Node3D, pk: PropKit, kit: Dictionary, at: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	pk.set_frame(Transform3D(b.scaled(Vector3.ONE * PROP_SCALE), at))
	for sx in [-1.0, 1.0]:
		BaustelleKit._rod(pk, kit, "steel", Vector3(sx * 1.9, -0.5, 0.0), Vector3(sx * 1.9, 3.6, 0.0), 0.06, 8, Color(0.5, 0.52, 0.54))
	BaustelleKit._blk(pk, kit, "bpaint", Vector3(-2.3, 1.4, -0.04), Vector3(2.3, 3.5, 0.04), Color(0.06, 0.22, 0.48))
	BaustelleKit._blk(pk, kit, "bpaint", Vector3(-2.3, 1.25, -0.04), Vector3(2.3, 1.4, 0.04), Color(0.95, 0.72, 0.1))
	var lines := [["SVARTFJELLVEGEN", 3.05, 0.34], ["NY BRU OVER DALEN", 2.55, 0.2], ["FERDIG 2028", 2.15, 0.2],
			["SVARTFJELL ANLEGG AS", 1.6, 0.14]]
	for l in lines:
		var lab := Label3D.new()
		lab.text = l[0]
		lab.font_size = 64
		lab.pixel_size = float(l[2]) * PROP_SCALE / 44.8
		lab.modulate = Color(0.97, 0.97, 0.95) if l[0] != "SVARTFJELL ANLEGG AS" else Color(0.06, 0.06, 0.08)
		if l[0] == "SVARTFJELL ANLEGG AS":
			lab.modulate = Color(0.97, 0.97, 0.95)
		lab.outline_size = 0
		lab.double_sided = false
		lab.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		lab.transform = Transform3D(b, at + b * Vector3(0, float(l[1]) * PROP_SCALE, 0.07 * PROP_SCALE))
		lab.visibility_range_end = 400.0
		node.add_child(lab)


## A floodlight mast: a galvanised pole on a concrete block, a cross arm with four lamps, a real light (no shadow).
func _floodlight(node: Node3D, pk: PropKit, kit: Dictionary, at: Vector3, i: int) -> void:
	pk.set_frame(Transform3D(Basis(Vector3.UP, float(i) * 1.3).scaled(Vector3.ONE * PROP_SCALE), at))
	BaustelleKit._blk(pk, kit, "concrete", Vector3(-0.5, -0.3, -0.5), Vector3(0.5, 0.35, 0.5), Color(0.6, 0.6, 0.6))
	BaustelleKit._rod(pk, kit, "steel", Vector3(0, 0.3, 0), Vector3(0, 9.0, 0), 0.09, 8, Color(0.62, 0.64, 0.66))
	BaustelleKit._bar(pk, kit, "steel", Vector3(-1.2, 9.0, 0), Vector3(1.2, 9.0, 0), 0.1, 0.1, Color(0.62, 0.64, 0.66))
	for lx in [-1.05, -0.35, 0.35, 1.05]:
		BaustelleKit._blk(pk, kit, "steel", Vector3(lx - 0.28, 9.05, -0.25), Vector3(lx + 0.28, 9.5, 0.12), Color(0.2, 0.2, 0.21))
		BaustelleKit._blk(pk, kit, "lamp", Vector3(lx - 0.24, 9.09, -0.28), Vector3(lx + 0.24, 9.46, -0.24), Color(1.0, 0.95, 0.85))
	var light := OmniLight3D.new()
	light.name = "Anlegg_Lys_%d" % i
	light.position = at + Vector3(0, 9.0 * PROP_SCALE - 1.0, 0)
	light.light_color = Color(1.0, 0.94, 0.84)
	light.light_energy = 2.4
	light.omni_range = 38.0
	light.shadow_enabled = false
	light.set_meta(&"no_shadow", true)
	node.add_child(light)


## Every piece of the works stands WORKS_LAP_CLEAR (plus its own radius) from the lap's and the ramps' edges in plan (the
## far highway itself is the works' own).
func _check_works_clear(foot_pts: Array) -> void:
	var lines: Array = [[(_level.get_node("TrackPath") as Path3D).curve, HighwayGen.MAIN_HALF_W]]
	for ap in _level.get_node("AlternativePaths").get_children():
		if ap is Path3D:
			lines.append([(ap as Path3D).curve, HighwayGen.RAMP_HALF_W])
	var bad := 0
	for fp in foot_pts:
		var p: Vector2 = fp[0]
		var r: float = fp[1]
		var d := 1e9
		for l in lines:
			var c: Curve3D = l[0]
			var length := c.get_baked_length()
			var s := 0.0
			while s <= length:
				var q := c.sample_baked(s)
				d = minf(d, Vector2(q.x, q.z).distance_to(p) - float(l[1]))
				s += 2.0
		if d < r + WORKS_LAP_CLEAR:
			push_error("works piece at (%.0f, %.0f) only %.1fm from a road's edge (needs %.1f)" % [p.x, p.y, d, r + WORKS_LAP_CLEAR])
			bad += 1
	if bad == 0:
		print("  works: every piece clear of the roads")


# ======================================================================================
#  The glacier
# ======================================================================================

## The ground before the glacier's valley is cut into it: the valley's own inside the heightfield, the country's past it.
func _raw_ground(x: float, z: float) -> float:
	var near: float = _gen.call("_alpine_base", x, z)
	var dx := maxf(maxf(SQ_MIN.x - x, x - SQ_MAX.x), 0.0)
	var dz := maxf(maxf(SQ_MIN.y - z, z - SQ_MAX.y), 0.0)
	var d := Vector2(dx, dz).length()
	if d <= 0.0:
		return near
	return lerpf(near, _far_h(x, z, _far_near(x, z)), smoothstep(COUNTRY_BLEND.x, COUNTRY_BLEND.y, d))


## Within `margin` of the glacier's ice in plan.
func _on_glacier(x: float, z: float, margin: float) -> bool:
	if z > HighwayGen.GLACIER_MOUTH_Z + margin:
		return false
	return absf(x - _gen.glacier_axis_x(z)) < _gen.glacier_half_w(z) * GLACIER_WIDTH + margin


## The glacier tongue in the north wall's side valley: a convex sheet of ice on the valley's floor, its margins tucked
## under the valley's walls, thickening up the valley from a rounded snout; seracs heaved up where the wall steepens (the
## icefall), firn up high. glacier_tongue.gdshader draws it from UV (across, metres up from the snout) and COLOR (r how
## broken, g the snow).
func _build_glacier(root: Node3D) -> void:
	var t0 := Time.get_ticks_msec()
	var z0: float = HighwayGen.GLACIER_MOUTH_Z - GLACIER_SNOUT_BACK
	var serac := FastNoiseLite.new()
	serac.seed = 4471
	serac.frequency = 0.09
	serac.fractal_type = FastNoiseLite.FRACTAL_NONE
	serac.noise_type = FastNoiseLite.TYPE_CELLULAR
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := 0
	var along := 0.0
	while along <= GLACIER_MAX_LEN:
		var z: float = z0 - along
		var ax: float = _gen.glacier_axis_x(z)
		var hw: float = _gen.glacier_half_w(z) * GLACIER_WIDTH
		var fl: float = _gen.glacier_floor(z)
		# Stop where the valley is no longer cut deep: the ice would stand proud of the ground round it.
		if along > 200.0 and _raw_ground(ax, z) < fl + GLACIER_MIN_CUT:
			break
		# The icefall, where the valley's floor steepens: the ice breaks up into seracs.
		var broken: float = smoothstep(0.25, 0.5, _gen.glacier_floor_slope(z))
		var thick: float = lerpf(8.0, 30.0, smoothstep(0.0, 300.0, along)) * sqrt(clampf(along / 18.0, 0.0, 1.0))
		var snow: float = smoothstep(300.0, 460.0, along)
		for j in range(GLACIER_COLS):
			var u: float = -1.0 + 2.0 * float(j) / float(GLACIER_COLS - 1)
			var prof: float = sqrt(maxf(0.0, 1.0 - u * u))
			var x: float = ax + u * hw
			var y: float = fl + thick * prof - 1.5 * (1.0 - prof)
			y += broken * prof * (serac.get_noise_2d(x, z) * 0.5 + 0.5) * 4.5
			st.set_color(Color(broken, snow, 0.0))
			st.set_uv(Vector2(u, along))
			st.add_vertex(Vector3(x, y, z))
		rows += 1
		along += GLACIER_STEP
	# Rows run north (z falling), columns west to east: wound so the faces look up (Godot's front faces are clockwise).
	for r in range(rows - 1):
		for j in range(GLACIER_COLS - 1):
			var a: int = r * GLACIER_COLS + j
			var b: int = a + 1
			var c: int = a + GLACIER_COLS
			var d: int = c + 1
			st.add_index(a); st.add_index(c); st.add_index(b)
			st.add_index(b); st.add_index(c); st.add_index(d)
	st.generate_normals()
	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://glacier_tongue.gdshader")
	mesh.surface_set_material(0, _save_res(mat, "glacier_mat"))
	var mi := MeshInstance3D.new()
	mi.name = "GlacierTongue"
	mi.mesh = _save_res(mesh, "glacier_mesh")
	root.add_child(mi)
	print("  glacier: %d rows, %.0fm from the snout (%.1fs)" % [rows, float(rows - 1) * GLACIER_STEP, (Time.get_ticks_msec() - t0) / 1000.0])


# ======================================================================================
#  The snow poles
# ======================================================================================

## Plough markers (as on mountain roads in the north): a slim grey pole with its top third orange and a reflector,
## leaning a little this way or that, along both sides of every road at ground level (where the ground SNOW_POLE_OUT past
## the deck's edge is the valley's or the country's, within 1.4m of the road's height, and no other road is there), in
## MultiMesh cells. "pole" in the name: DressingColliders makes each a rigid post (behind the barriers, nobody reaches one).
func _build_snow_poles(root: Node3D) -> void:
	var t0 := Time.get_ticks_msec()
	var pk: PropKit = BaustelleKit.new_kit(1.0)
	var kit := {}
	var grey := Color(0.78, 0.79, 0.80)
	var orange := Color(0.95, 0.38, 0.08)
	pk.tube(kit, "plastic", Vector3(0, -0.4, 0), Vector3(0, 2.1, 0), 0.045, 0.04, 6, grey, false)
	pk.tube(kit, "plastic", Vector3(0, 2.1, 0), Vector3(0, 3.1, 0), 0.04, 0.035, 6, orange, true)
	BaustelleKit._blk(pk, kit, "lamp", Vector3(-0.03, 2.55, 0.03), Vector3(0.03, 2.75, 0.05), Color(1.0, 0.9, 0.7))
	var mesh: ArrayMesh = _save_res(BaustelleKit.commit(pk, kit), "snow_pole")
	var rng := RandomNumberGenerator.new()
	rng.seed = 6113
	var cells := {}
	var count := 0
	var roads: Array = [[(_level.get_node("TrackPath") as Path3D).curve, HighwayGen.MAIN_HALF_W]]
	for ap in _level.get_node("AlternativePaths").get_children():
		if ap is Path3D:
			roads.append([(ap as Path3D).curve, HighwayGen.RAMP_HALF_W])
	roads.append([_far, HighwayGen.MAIN_HALF_W])
	var centre := (SQ_MIN + SQ_MAX) * 0.5
	for r in roads:
		var c: Curve3D = r[0]
		var half: float = r[1]
		var length := c.get_baked_length()
		var s := rng.randf() * SNOW_POLE_STEP
		while s < length:
			var p: Vector3 = c.sample_baked(s)
			var f: Vector3 = c.sample_baked(minf(s + 1.0, length)) - p
			s += SNOW_POLE_STEP
			if Vector2(p.x, p.z).distance_to(centre) > SNOW_POLE_REACH:
				continue
			f.y = 0.0
			if f.length_squared() < 1e-6:
				continue
			f = f.normalized()
			var right := Vector3(-f.z, 0.0, f.x)
			for sx in [-1.0, 1.0]:
				var q: Vector3 = p + right * (sx * (half + SNOW_POLE_OUT))
				if _road_edge_d(q.x, q.z, 6.0) < SNOW_POLE_OUT * 0.5 or _in_works(q.x, q.z, 2.0):
					continue
				var hit := _ray(q.x, q.z)
				if hit.is_empty():
					continue
				var col_name := str((hit.collider as Node).name)
				if not (col_name == "GlacierValley" or col_name == "CountrySolid" or col_name == "TunnelMassif"):
					continue
				var hp: Vector3 = hit.position
				if absf(hp.y - p.y) > 1.4 or (hit.normal as Vector3).y < 0.8:
					continue
				var lean := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.06))
				var xf := Transform3D(lean * Basis(Vector3.UP, rng.randf() * TAU), hp)
				var k := Vector2i(floori(hp.x / SNOW_POLE_CELL), floori(hp.z / SNOW_POLE_CELL))
				if not cells.has(k):
					cells[k] = []
				cells[k].append(xf)
				count += 1
	var node := Node3D.new()
	node.name = "SnowPoles"
	root.add_child(node)
	for k in cells:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = (cells[k] as Array).size()
		mm.buffer = PropKit.transform_buffer(cells[k])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "SnowPoles_%d_%d" % [k.x, k.y]
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 420.0 + SNOW_POLE_CELL * 0.7
		node.add_child(mmi)
	print("  snow poles: %d in %d cells (%.1fs)" % [count, cells.size(), (Time.get_ticks_msec() - t0) / 1000.0])


# ======================================================================================
#  The avalanche gallery
# ======================================================================================

## A cut-and-cover avalanche gallery over the lap on the east flank: a concrete wall on the uphill side, a roof slab
## carried on columns on the valley side with a deep edge beam, lamps under it, and the snow lying on the roof running on
## up the slope into the hillside (drawn in the valley's ground material, so it is the hillside's own snow: an avalanche
## would pass over the road). The roof is solid (the race camera comes down under it as in the tunnel), as are the wall
## and the columns, all outside the barriers.
func _build_gallery(root: Node3D) -> void:
	var t0 := Time.get_ticks_msec()
	var lap: Curve3D = (_level.get_node("TrackPath") as Path3D).curve
	var s0 := lap.get_closest_offset(Vector3(GALLERY_FROM.x, 14.0, GALLERY_FROM.y))
	var s1 := lap.get_closest_offset(Vector3(GALLERY_TO.x, 14.0, GALLERY_TO.y))
	if s1 < s0:
		var tmp := s0
		s0 = s1
		s1 = tmp
	var half := HighwayGen.MAIN_HALF_W
	var pk: PropKit = BaustelleKit.new_kit(1.0)
	var kit := {}
	var conc := Color(0.66, 0.66, 0.65)
	var snow_st := SurfaceTool.new()
	snow_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := StaticBody3D.new()
	body.name = "AvalancheGallery"
	body.set_meta(&"surface", "rock")
	var node := Node3D.new()
	node.name = "AvalancheGallery"
	root.add_child(node)
	node.add_child(body)
	# Which side is uphill: where the ground is higher 20m out.
	var mid := lap.sample_baked((s0 + s1) * 0.5)
	var mf := lap.sample_baked((s0 + s1) * 0.5 + 1.0) - mid
	var mr := Vector3(-mf.z, 0.0, mf.x).normalized()
	var ha: float = _gen.call("_alpine_height", mid.x + mr.x * 30.0, mid.z + mr.z * 30.0)
	var hb: float = _gen.call("_alpine_height", mid.x - mr.x * 30.0, mid.z - mr.z * 30.0)
	var up_side := 1.0 if ha > hb else -1.0
	print("  avalanche gallery: the slope rises to the %s (%.0fm against %.0fm)" % ["right" if up_side > 0.0 else "left", maxf(ha, hb), minf(ha, hb)])
	var w_in: float = half + 1.0
	var rings: Array = []
	var s := s0
	while s <= s1 + 0.01:
		var p := lap.sample_baked(s)
		var f := lap.sample_baked(minf(s + 1.0, lap.get_baked_length())) - p
		f.y = 0.0
		f = f.normalized()
		var r := Vector3(-f.z, 0.0, f.x) * up_side
		rings.append([s, p, f, r])
		s += 2.0
	var n := rings.size()
	var cols_rows := 0
	var lamp_i := 0
	for i in range(n):
		var p: Vector3 = rings[i][1]
		var r: Vector3 = rings[i][3]
		var y_s: float = p.y + GALLERY_CLEAR
		var y_t: float = y_s + GALLERY_SLAB
		# The snow on the roof and up the slope: across from a cornice over the valley-side edge, over the roof, then up
		# the hillside at 35 degrees until it meets the ground.
		var row: Array = []
		row.append(p - r * (w_in + 1.8) + Vector3.UP * (y_t - p.y + 0.15))
		row.append(p - r * (w_in + 1.5) + Vector3.UP * (y_t - p.y + 0.55))
		var lat := -w_in
		while lat <= w_in + GALLERY_WALL + 0.01:
			row.append(p + r * lat + Vector3.UP * (y_t - p.y + 0.6 + 0.15 * sin(lat * 0.7 + float(i) * 0.3)))
			lat += 2.0
		var ylast: float = y_t + 0.6
		var lat2 := w_in + GALLERY_WALL + 2.0
		for k in range(30):
			var q := p + r * lat2
			var g := _ground_y(q.x, q.z)
			var y := ylast + 1.4
			if y >= g:
				row.append(Vector3(q.x, g - 0.3, q.z))
				break
			row.append(Vector3(q.x, y, q.z))
			ylast = y
			lat2 += 2.0
		rings[i].append(row)
	# The snow's mesh: rows of different lengths, stitched pairwise by the shorter one's count, its last point carried on.
	for i in range(n - 1):
		var a: Array = rings[i][4]
		var b: Array = rings[i + 1][4]
		var m := maxi(a.size(), b.size())
		for k in range(m - 1):
			var a0: Vector3 = a[mini(k, a.size() - 1)]
			var a1: Vector3 = a[mini(k + 1, a.size() - 1)]
			var b0: Vector3 = b[mini(k, b.size() - 1)]
			var b1: Vector3 = b[mini(k + 1, b.size() - 1)]
			_snow_quad(snow_st, a0, a1, b1, b0)
	# The concrete: roof slab, uphill wall, the valley-side edge beam, columns, lamps.
	for i in range(n - 1):
		var pa: Vector3 = rings[i][1]
		var pb: Vector3 = rings[i + 1][1]
		var ra: Vector3 = rings[i][3]
		var rb: Vector3 = rings[i + 1][3]
		var ysa: float = pa.y + GALLERY_CLEAR
		var ysb: float = pb.y + GALLERY_CLEAR
		var e0 := -(w_in + 1.5)
		var e1 := w_in + GALLERY_WALL
		# Soffit (facing down), top, the valley-side fascia.
		pk.quad(kit, "concrete", [pa + ra * e1 + Vector3.UP * (ysa - pa.y), pb + rb * e1 + Vector3.UP * (ysb - pb.y),
				pb + rb * e0 + Vector3.UP * (ysb - pb.y), pa + ra * e0 + Vector3.UP * (ysa - pa.y)], Vector3.DOWN, conc)
		pk.quad(kit, "concrete", [pa + ra * e0 + Vector3.UP * (ysa - pa.y + GALLERY_SLAB), pb + rb * e0 + Vector3.UP * (ysb - pb.y + GALLERY_SLAB),
				pb + rb * e1 + Vector3.UP * (ysb - pb.y + GALLERY_SLAB), pa + ra * e1 + Vector3.UP * (ysa - pa.y + GALLERY_SLAB)], Vector3.UP, conc)
		pk.quad(kit, "concrete", [pa + ra * e0 + Vector3.UP * (ysa - pa.y - 0.8), pb + rb * e0 + Vector3.UP * (ysb - pb.y - 0.8),
				pb + rb * e0 + Vector3.UP * (ysb - pb.y + GALLERY_SLAB), pa + ra * e0 + Vector3.UP * (ysa - pa.y + GALLERY_SLAB)], -ra, conc)
		# The edge beam's inner face and underside.
		pk.quad(kit, "concrete", [pa + ra * (e0 + 0.8) + Vector3.UP * (ysa - pa.y), pb + rb * (e0 + 0.8) + Vector3.UP * (ysb - pb.y),
				pb + rb * (e0 + 0.8) + Vector3.UP * (ysb - pb.y - 0.8), pa + ra * (e0 + 0.8) + Vector3.UP * (ysa - pa.y - 0.8)], ra, conc)
		pk.quad(kit, "concrete", [pa + ra * e0 + Vector3.UP * (ysa - pa.y - 0.8), pa + ra * (e0 + 0.8) + Vector3.UP * (ysa - pa.y - 0.8),
				pb + rb * (e0 + 0.8) + Vector3.UP * (ysb - pb.y - 0.8), pb + rb * e0 + Vector3.UP * (ysb - pb.y - 0.8)], Vector3.DOWN, conc)
		# The uphill wall's road face, from below the road's surface up to the soffit.
		pk.quad(kit, "concrete", [pa + ra * w_in + Vector3.DOWN * 0.6, pb + rb * w_in + Vector3.DOWN * 0.6,
				pb + rb * w_in + Vector3.UP * (ysb - pb.y), pa + ra * w_in + Vector3.UP * (ysa - pa.y)], -ra, Color(0.6, 0.6, 0.6))
		# Collision: the roof and the wall, piece by piece.
		var c := (pa + pb) * 0.5
		var fwd: Vector3 = (pb - pa)
		fwd.y = 0.0
		var seg := fwd.length()
		var basis := Basis.looking_at(fwd.normalized(), Vector3.UP)
		var roof_c: Vector3 = c + ((ra + rb) * 0.5) * ((e0 + e1) * 0.5) + Vector3.UP * ((ysa + ysb) * 0.5 - c.y + GALLERY_SLAB * 0.5)
		_box_shape(body, Transform3D(basis, roof_c), Vector3(e1 - e0, GALLERY_SLAB + 0.8, seg + 0.3))
		var wall_c: Vector3 = c + ((ra + rb) * 0.5) * (w_in + GALLERY_WALL * 0.5) + Vector3.UP * (GALLERY_CLEAR * 0.5 - 0.3)
		_box_shape(body, Transform3D(basis, wall_c), Vector3(GALLERY_WALL, GALLERY_CLEAR + 0.6, seg + 0.3))
		# Lamps along the soffit's middle, every fourth ring a real light.
		if i % 2 == 0:
			var lp: Vector3 = pa + ra * 1.5 + Vector3.UP * (ysa - pa.y - 0.12)
			BaustelleKit._blk(pk, kit, "lamp", lp + Vector3(-0.35, -0.08, -0.35), lp + Vector3(0.35, 0.1, 0.35), Color(1.0, 0.86, 0.6))
			if i % 8 == 0:
				var light := OmniLight3D.new()
				light.name = "GalleryLamp_%d" % lamp_i
				light.position = lp + Vector3.DOWN * 0.6
				light.light_color = Color(1.0, 0.84, 0.58)
				light.light_energy = 1.6
				light.omni_range = 16.0
				light.shadow_enabled = false
				light.set_meta(&"no_shadow", true)
				node.add_child(light)
				lamp_i += 1
	# Columns on the valley side, every GALLERY_BAY.
	var s_c := s0
	var cl := lap.get_baked_length()
	while s_c <= s1:
		var p := lap.sample_baked(s_c)
		var f := lap.sample_baked(minf(s_c + 1.0, cl)) - p
		f.y = 0.0
		f = f.normalized()
		var r := Vector3(-f.z, 0.0, f.x) * up_side
		var cc: Vector3 = p - r * (w_in + 1.1)
		var g := _ground_y(cc.x, cc.z)
		var top: float = p.y + GALLERY_CLEAR
		var basis := Basis.looking_at(f, Vector3.UP)
		pk.set_frame(Transform3D(basis, Vector3(cc.x, 0.0, cc.z)))
		BaustelleKit._blk(pk, kit, "concrete", Vector3(-0.4, minf(g, p.y) - 0.8, -0.45), Vector3(0.4, top, 0.45), conc)
		pk.reset_frame()
		_box_shape(body, Transform3D(basis, Vector3(cc.x, (minf(g, p.y) - 0.8 + top) * 0.5, cc.z)), Vector3(0.8, top - minf(g, p.y) + 0.8, 0.9))
		cols_rows += 1
		s_c += GALLERY_BAY
	# The two portals: the roof's and the wall's ends faced off.
	for e in [0, n - 1]:
		var p: Vector3 = rings[e][1]
		var r: Vector3 = rings[e][3]
		var f: Vector3 = rings[e][2] * (-1.0 if e == 0 else 1.0)
		var ys: float = p.y + GALLERY_CLEAR
		pk.quad(kit, "concrete", [p - r * (w_in + 1.5) + Vector3.UP * (ys - p.y - 0.8), p + r * (w_in + GALLERY_WALL) + Vector3.UP * (ys - p.y - 0.8),
				p + r * (w_in + GALLERY_WALL) + Vector3.UP * (ys - p.y + GALLERY_SLAB), p - r * (w_in + 1.5) + Vector3.UP * (ys - p.y + GALLERY_SLAB)], f, Color(0.62, 0.62, 0.61))
	var mi := MeshInstance3D.new()
	mi.name = "AvalancheGallery_Concrete"
	mi.mesh = _save_res(BaustelleKit.commit(pk, kit), "gallery")
	node.add_child(mi)
	snow_st.generate_normals()
	var snow := MeshInstance3D.new()
	snow.name = "AvalancheGallery_Snow"
	snow.mesh = _save_res(snow_st.commit(), "gallery_snow")
	# The ground's material, but as if far from any road: over the road its map would paint the plough's grit on it.
	var snow_mat := _ground_mat.duplicate() as ShaderMaterial
	var far_img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	far_img.set_pixel(0, 0, Color(1.0, 0.0, 0.0, 1.0))
	snow_mat.set_shader_parameter("ground_map", ImageTexture.create_from_image(far_img))
	snow.material_override = _save_res(snow_mat, "gallery_snow_mat")
	node.add_child(snow)
	# The highway's streetlights stood up through the roof: none under it.
	var gone := 0
	for lamp in _level.find_children("Streetlight*", "", true, false):
		var lp: Vector3 = (lamp as Node3D).global_position
		var off := lap.get_closest_offset(lp)
		if off > s0 - 4.0 and off < s1 + 4.0 and Vector2(lp.x, lp.z).distance_to(Vector2(lap.sample_baked(off).x, lap.sample_baked(off).z)) < half + 6.0:
			lamp.get_parent().remove_child(lamp)
			lamp.free()
			gone += 1
	if gone > 0:
		print("  avalanche gallery: %d streetlights under it taken away" % gone)
	print("  avalanche gallery: %.0fm over the lap (%.0f to %.0f), %d columns (%.1fs)" % [s1 - s0, s0, s1, cols_rows, (Time.get_ticks_msec() - t0) / 1000.0])


## A quad in the snow's mesh (a, b, c, d in order round it), wound so its front faces up.
func _snow_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var nrm := (b - a).cross(d - a)
	if nrm.y > 0.0:
		for v in [a, d, b, b, d, c]:
			st.add_vertex(v)
	else:
		for v in [a, b, d, b, c, d]:
			st.add_vertex(v)


# ======================================================================================
#  The mountain lodge
# ======================================================================================

## Svartfjell Fjellstue (made up): a two-storey lodge in Falu red with its café, a white annex with the toilets, on the
## pad the highway generator levels (PADS); before them the lot (a dark slab with its bays painted) with cars and a
## motorhome parked, ploughed snow heaped round its edges, picnic tables to the side, lamp posts and their lights, the
## name on the lodge's front. Life size (FjordVillageKit, CampKit, RoadsideKit, YardKit) grown by PROP_SCALE; the lodge
## and the rest are two meshes, which DressingColliders makes solid.
func _build_rest_stop(root: Node3D) -> void:
	var t0 := Time.get_ticks_msec()
	var pad: Array = HighwayGen.PADS[0]
	var y0: float = float(pad[2])
	var frame := Transform3D(Basis(Vector3.UP, LODGE_YAW), Vector3(LODGE_AT.x, y0, LODGE_AT.y))
	var node := Node3D.new()
	node.name = "Fjellstue"
	root.add_child(node)
	# The buildings, at the lot's back (-z).
	var vk: PropKit = FjordVillageKit.new_village_kit(PROP_SCALE)
	var vkit := {}
	var lodge_xf := frame * Transform3D(Basis(), Vector3(-6.0, 0.15, -10.0))
	vk.set_frame(Transform3D(lodge_xf.basis.scaled(Vector3.ONE * PROP_SCALE), lodge_xf.origin))
	var chim := FjordVillageKit.house(vk, vkit, 15.0, 9.0, 2.0, FjordVillageKit.PAINTS[1], 0.6, 0.15, 7)
	_lodge_signs(vk, vkit)
	var annex_xf := frame * Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(20.0, 0.15, -8.0))
	vk.set_frame(Transform3D(annex_xf.basis.scaled(Vector3.ONE * PROP_SCALE), annex_xf.origin))
	FjordVillageKit.house(vk, vkit, 7.0, 5.0, 1.0, FjordVillageKit.PAINTS[0], 0.6, 0.0, 3)
	# Ploughed snow heaped round the lot's sides and back.
	vk.set_frame(Transform3D(frame.basis.scaled(Vector3.ONE * PROP_SCALE), frame.origin))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	for e in [[Vector3(-19.0, 0, 1.0), Vector3(-19.0, 0, 13.0)], [Vector3(19.5, 0, -2.0), Vector3(19.5, 0, 13.0)],
			[Vector3(-19.0, 0, 13.5), Vector3(-6.0, 0, 13.5)], [Vector3(6.0, 0, 13.5), Vector3(19.5, 0, 13.5)]]:
		var a: Vector3 = e[0]
		var b: Vector3 = e[1]
		var steps := int(a.distance_to(b) / 1.6)
		for k in range(steps + 1):
			var c: Vector3 = a.lerp(b, float(k) / float(maxi(steps, 1)))
			var hr := rng.randf_range(0.5, 0.9)
			vk.lathe(vkit, "snow", c + Vector3(rng.randf_range(-0.3, 0.3), -0.2, rng.randf_range(-0.3, 0.3)),
					[Vector2(hr * 1.6, 0.0), Vector2(hr * 1.4, hr * 0.5), Vector2(hr * 0.8, hr * 0.95), Vector2(0.001, hr * 1.1)], 8, Color(0.92, 0.94, 0.97))
	var lodge := MeshInstance3D.new()
	lodge.name = "Fjellstue_Hus"
	lodge.mesh = _save_res(FjordVillageKit.commit(vk, vkit), "lodge")
	node.add_child(lodge)
	# The lot, the cars, the tables and the lamps.
	var pk: PropKit = BaustelleKit.new_kit(PROP_SCALE)
	var kit := {}
	pk.set_frame(Transform3D(frame.basis.scaled(Vector3.ONE * PROP_SCALE), frame.origin))
	BaustelleKit._blk(pk, kit, "concrete", Vector3(-18.5, -0.3, -1.5), Vector3(18.5, 0.06, 13.0), Color(0.24, 0.24, 0.26))
	for k in range(9):
		var x := -14.0 + float(k) * 3.0
		BaustelleKit._blk(pk, kit, "painted", Vector3(x - 0.06, 0.06, 1.0), Vector3(x + 0.06, 0.075, 6.0), Color(0.92, 0.92, 0.9))
	var ck = CampKit.new(pk)
	var cars := [["suv", Color(0.12, 0.2, 0.36), 0, -12.5], ["suv", Color(0.75, 0.76, 0.78), 0, -9.5], ["van", Color(0.92, 0.92, 0.9), 0, -3.5],
			["suv", Color(0.45, 0.08, 0.07), 0, 2.5], ["motorhome_road", Color(0.95, 0.95, 0.93), 1, 10.0]]
	for c in cars:
		# Nose into the bay, toward the lodge (-z).
		pk.set_frame(Transform3D(frame.basis.scaled(Vector3.ONE * PROP_SCALE), frame.origin) * Transform3D(Basis(), Vector3(float(c[3]), 0.07, 3.6 if c[0] != "motorhome_road" else 6.0)))
		ck.vehicle(kit, String(c[0]), c[1], int(c[2]))
	var rk = RoadsideKit.new(pk)
	for t in [Vector3(-16.5, 0.07, 9.5), Vector3(-16.5, 0.07, 5.0)]:
		pk.set_frame(Transform3D(frame.basis.scaled(Vector3.ONE * PROP_SCALE), frame.origin) * Transform3D(Basis(Vector3.UP, PI * 0.5), t))
		rk.picnic_table(kit)
	var lamp_spots := [Vector3(-18.0, 0.06, 12.5), Vector3(0.0, 0.06, 12.5), Vector3(18.0, 0.06, 12.5), Vector3(18.0, 0.06, 0.0)]
	pk.set_frame(Transform3D(frame.basis.scaled(Vector3.ONE * PROP_SCALE), frame.origin))
	YardKit.uvk = PROP_SCALE
	for i in range(lamp_spots.size()):
		var lp: Vector3 = lamp_spots[i]
		YardKit.lamp_post(pk, kit, lp, 4.2)
		if i % 2 == 0:
			var light := OmniLight3D.new()
			light.name = "Fjellstue_Lys_%d" % i
			light.position = frame * (lp * PROP_SCALE) + Vector3.UP * (4.0 * PROP_SCALE)
			light.light_color = Color(1.0, 0.82, 0.55)
			light.light_energy = 1.8
			light.omni_range = 26.0
			light.shadow_enabled = false
			light.set_meta(&"no_shadow", true)
			node.add_child(light)
	pk.reset_frame()
	var lot := MeshInstance3D.new()
	lot.name = "Fjellstue_Plass"
	lot.mesh = _save_res(BaustelleKit.commit(pk, kit), "lodge_lot")
	node.add_child(lot)
	# Its name on the board on the roof, KAFE on both faces of the blade by the door, a lamp on the board.
	for l in [["SVARTFJELL FJELLSTUE", LODGE_SIGN_C + Vector3(0, 0, LODGE_SIGN_T * 0.5 + 0.03), Vector3.BACK, 0.54],
			["KAFE", LODGE_BLADE_C + Vector3(LODGE_BLADE_T * 0.5 + 0.02, 0, 0), Vector3.RIGHT, 0.25],
			["KAFE", LODGE_BLADE_C - Vector3(LODGE_BLADE_T * 0.5 + 0.02, 0, 0), Vector3.LEFT, 0.25]]:
		var lab := Label3D.new()
		lab.text = l[0]
		lab.font_size = 64
		lab.pixel_size = float(l[3]) * PROP_SCALE / 44.8
		lab.modulate = Color(0.97, 0.95, 0.88)
		lab.outline_size = 0
		lab.double_sided = false
		lab.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		var n: Vector3 = lodge_xf.basis * (l[2] as Vector3)
		lab.transform = Transform3D(Basis.looking_at(-n, Vector3.UP), lodge_xf * ((l[1] as Vector3) * PROP_SCALE))
		lab.visibility_range_end = 450.0
		node.add_child(lab)
	var sign_light := OmniLight3D.new()
	sign_light.name = "Fjellstue_Skiltlys"
	sign_light.position = lodge_xf * ((LODGE_SIGN_C + Vector3(0, 0.4, 1.6)) * PROP_SCALE)
	sign_light.light_color = Color(1.0, 0.86, 0.62)
	sign_light.light_energy = 1.2
	sign_light.omni_range = 10.0
	sign_light.shadow_enabled = false
	sign_light.set_meta(&"no_shadow", true)
	node.add_child(sign_light)
	# Warm light in its windows at dusk: a few lights inside.
	for wx in [-4.0, 4.0]:
		var wl := OmniLight3D.new()
		wl.name = "Fjellstue_Vindu_%d" % int(wx)
		wl.position = lodge_xf * Vector3(wx * PROP_SCALE, 1.8 * PROP_SCALE, -1.5 * PROP_SCALE)
		wl.light_color = Color(1.0, 0.72, 0.42)
		wl.light_energy = 1.4
		wl.omni_range = 9.0
		wl.shadow_enabled = false
		wl.set_meta(&"no_shadow", true)
		node.add_child(wl)
	print("  mountain lodge at (%.0f, %.0f) (%.1fs)" % [LODGE_AT.x, LODGE_AT.y, (Time.get_ticks_msec() - t0) / 1000.0])


## The lodge's signs in its frame (life size): the name board on three posts standing on the front roof slope, braced
## back to it, a white frame round its dark green face; the KAFE blade on a bracket off the wall by the door.
func _lodge_signs(pk: PropKit, kit: Dictionary) -> void:
	var green := Color(0.10, 0.22, 0.16)
	var white := Color(0.93, 0.93, 0.9)
	var wood := Color(0.30, 0.22, 0.15)
	var c := LODGE_SIGN_C
	var hw := LODGE_SIGN_SIZE.x * 0.5
	var hh := LODGE_SIGN_SIZE.y * 0.5
	var t := LODGE_SIGN_T * 0.5
	BaustelleKit._blk(pk, kit, "painted", c + Vector3(-hw, -hh, -t), c + Vector3(hw, hh, t), green)
	# The frame, standing 2cm proud of the face.
	for e in [[Vector3(-hw - 0.08, hh, t), Vector3(hw + 0.08, hh + 0.1, t + 0.03)], [Vector3(-hw - 0.08, -hh - 0.1, t), Vector3(hw + 0.08, -hh, t + 0.03)],
			[Vector3(-hw - 0.08, -hh, t), Vector3(-hw, hh, t + 0.03)], [Vector3(hw, -hh, t), Vector3(hw + 0.08, hh, t + 0.03)]]:
		BaustelleKit._blk(pk, kit, "painted", c + (e[0] as Vector3) + Vector3(0, 0, -t * 2.0 - 0.02), c + (e[1] as Vector3), white)
	var roof_y := func(z: float) -> float: return 6.2 - z * FjordVillageKit.PITCH
	for px in [-hw + 0.6, 0.0, hw - 0.6]:
		var zb: float = c.z - t - 0.08
		BaustelleKit._blk(pk, kit, "timber", Vector3(px - 0.07, roof_y.call(zb) - 0.2, zb - 0.07), Vector3(px + 0.07, c.y + hh, zb + 0.07), wood)
		# A brace from the post's middle back to the roof.
		var zr: float = zb - 1.0
		BaustelleKit._bar(pk, kit, "timber", Vector3(px, c.y - 0.1, zb), Vector3(px, roof_y.call(zr) + 0.05, zr), 0.1, 0.1, wood)
	# The KAFE blade: a board across the wall's normal on a bracket.
	var b := LODGE_BLADE_C
	var bw := LODGE_BLADE_SIZE.x * 0.5
	var bh := LODGE_BLADE_SIZE.y * 0.5
	var bt := LODGE_BLADE_T * 0.5
	BaustelleKit._blk(pk, kit, "painted", b + Vector3(-bt, -bh, -bw), b + Vector3(bt, bh, bw), green)
	BaustelleKit._blk(pk, kit, "painted", b + Vector3(-bt - 0.02, bh, -bw - 0.04), b + Vector3(bt + 0.02, bh + 0.06, bw + 0.04), white)
	BaustelleKit._bar(pk, kit, "iron", Vector3(b.x, b.y + bh + 0.12, 0.03), Vector3(b.x, b.y + bh + 0.12, b.z + bw + 0.05), 0.05, 0.05, Color(0.12, 0.12, 0.12))
	BaustelleKit._bar(pk, kit, "iron", Vector3(b.x, b.y - bh, 0.03), Vector3(b.x, b.y + bh + 0.12, b.z + bw * 0.6), 0.04, 0.04, Color(0.12, 0.12, 0.12))
