extends Node
## Dresses levels/FrostpeakCreekLevel.tscn (the Svartfjell GP's first stage) and saves it. Run headless after
## regenerate_frostpeak_creek.gd, which builds the track, the terrain and the bridges from scratch:
##   Godot --headless --path . res://regenerate_frostpeak_dressing.tscn
## It replaces everything under FrostpeakDressing on every run, and leaves the lap, the jumps, the shortcuts and
## the terrain's shape alone. What it does:
##   - The ground: frostpeak_ground.gdshader on TerrainGenerator's Terrain_Visual (it had a flat white material),
##     with a ground map baked here (_bake_ground_map: the distance to the nearest road's edge, the woods).
##   - The fjord (_build_backdrop): the island stands in a fjord. One ring of ground from under the island's rim out
##     to BACK_R1 carries the fjord's bed, its walls (black rock, snow, forest on the lower slopes:
##     fjord_mountain.gdshader) and, at its head to the north, Svartfjell (SVART_*), a black horn standing out of the
##     water. TerrainGenerator's water plane is stretched over the whole fjord, and the fog pushed out (FOG) so it
##     shows.
##   - The woods (_plan_woods, _build_woods): snowy spruce on the valley's flanks, bare winter birch by the creek
##     and on the woods' edges (SnowTreeKit.gd), saved as the Detail Level's Ultra draws them (every tree, the rich
##     spruce); SnowWoodsDetail.gd draws a share of them, in lighter meshes, below it. Kept off the roads
##     (TREE_CLEAR), out of the water, off steep ground, and out of two reserved clearings: the start's west side
##     (a race venue to come) and the south shore (a village to come), RESERVED.
##   - The overpass (_build_overpasses): a concrete deck under the Jump 2 approach where it crosses the start
##     straight.
##   - Svartvik (_plan_village, _build_village, FjordVillageKit.gd), the fishing village on the south shore: painted
##     timber houses along a lane on the shore's flat, a white church on the east terrace, rorbuer and boathouses on
##     the waterline, a timber quay with two fishing boats, racks of drying stockfish, chimney smoke.
const SnowTreeKit = preload("res://SnowTreeKit.gd")
const SnowWoodsDetail = preload("res://SnowWoodsDetail.gd")
const PropKit = preload("res://PropKit.gd")

const LEVEL_PATH := "res://levels/FrostpeakCreekLevel.tscn"
const DRESSING := "FrostpeakDressing"
const RES_PREFIX := "frostpeak_dress_"
const TERRAIN_MESH := "res://generated/frostpeak_creek_terrain_visual.res"

## TerrainGenerator's grid (terrain_size 900, terrain_resolution 420).
const GRID_START := -450.0
const GRID_RES := 420
const GRID_STEP := 900.0 / 420.0
const WATER_Y := -1.2
## Road half widths: the trunk to its curbs' outer edge, the two shortcuts' decks.
const TRUNK_HALF := 8.5
const SHORTCUTS := [["AlternativePaths/AlternativePath_CanyonCut", 5.75], ["AlternativePaths/AlternativePath_GladeBridge", 5.5]]

## The ground map: MAP_RES texels a side from MAP_ORIGIN over MAP_SIZE metres. R is the distance to the nearest
## road's edge over ROAD_REACH, G the woods' cover.
const MAP_ORIGIN := Vector2(-460.0, -460.0)
const MAP_SIZE := 920.0
const MAP_RES := 512
const ROAD_REACH := 40.0

## The meshes drawn as granite retaining walls (frostpeak_wall.gdshader).
const WALLS := ["TerrainGenerator/Visual_Road_Sides", "AlternativeRoad_Collision/AlternativeRoad_Embankment",
		"AlternativeRoad_Glade_Collision/AlternativeRoad_Glade_Embankment"]

## Depth fog: begins past the near stretch of road and runs out past the fjord's walls.
const FOG := Vector2(170.0, 5200.0)

# --- The fjord ------------------------------------------------------------------------------------
const BACK_R0 := 436.0
const BACK_R1 := 4100.0
const BACK_SEGS := 720
const BACK_SECTORS := 24
## The fjord's centre line wanders a little east and west of the island; its half width round the island,
## narrowing toward its head in the north and opening toward the sea in the south.
const FJORD_HALF := 800.0
const FJORD_HEAD_Z := -2300.0
const FJORD_BED := -62.0
## Svartfjell: where its summit stands, how high, the radius of its core between the ridges, and its ridges
## (aretes): [bearing from the summit (radians, atan2(z, x)), how far out it runs]. The first runs down toward
## the fjord. Shoulders on the ridges: [offset from the summit, height, radius].
const SVART_AT := Vector2(-360.0, -2880.0)
const SVART_H := 1380.0
const SVART_CORE := 640.0
const SVART_ARETES := [[1.30, 1300.0], [-2.70, 1080.0], [-0.45, 930.0], [2.75, 760.0]]
const SVART_SHOULDERS := [[Vector2(140.0, 500.0), 840.0, 560.0], [Vector2(-620.0, -170.0), 720.0, 520.0],
		[Vector2(560.0, -290.0), 610.0, 480.0]]

# --- The woods ------------------------------------------------------------------------------------
## How far a tree's crown keeps from a road's edge.
const TREE_CLEAR := {"spruce": 2.5, "birch": 1.8}
## Nothing grows past this radius (the island's rim falls into the fjord).
const WOODS_R := 392.0
## A tree is tried every TREE_STEP metres: the woods' density at the Detail Level's Ultra (about 5,400 trees).
## SnowWoodsDetail.gd draws a share of them below it.
const TREE_STEP := 6.0
const FOREST_CELL := 80.0
const FAR_CELL := 240.0
## A tree's rank (SnowWoodsDetail.gd draws the trees ranked under the level's share) is a random number, scaled
## down by RANK_NEAR_ROAD within RANK_ROAD.x of a road's edge, back to 1 by RANK_ROAD.y: the trees along the lap
## are the last to go.
const RANK_NEAR_ROAD := 0.55
const RANK_ROAD := Vector2(30.0, 110.0)
## Trees within this of a road get a collider of their own reaching to their branches (DressingColliders gives
## every tree a trunk at race time too).
const TRUNK_COLLIDE_REACH := 40.0
const TREE_SOLID_SHARE := 0.7
## Clearings kept for what comes later: [x0, z0, x1, z1, share of the trees that still grow there].
const RESERVED := [
	[-170.0, 40.0, -55.0, 195.0, 0.08],   # the start's west side: a race venue
	[-190.0, 285.0, 190.0, 420.0, 0.12],  # the south shore: a village
	[-100.0, 262.0, 60.0, 300.0, 0.2],    # the view from the south loop to the village
]

var _level: Node3D
var _tg: Node
var _heights := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()
var _materials := {}
## Road samples [x, z, half width] in a hash of ROAD_CELL squares.
const ROAD_CELL := 16.0
var _road_pts: Array = []
var _road_hash := {}
var _ground_mat: ShaderMaterial
var _trees: Array = []


func _ready() -> void:
	print("=== Frostpeak Creek dressing ===")
	var t0 := Time.get_ticks_msec()
	# Load first: the dressed level points at the files the clear-out deletes (they stay in memory, and
	# everything this run keeps from them is saved again under its own name).
	_level = (load(LEVEL_PATH) as PackedScene).instantiate()
	add_child(_level)
	_clear_generated()
	_tg = _level.get_node("TerrainGenerator")
	var old := _level.get_node_or_null(DRESSING)
	if old:
		_level.remove_child(old)
		old.free()
	_heights = _load_heights()
	_index_roads()
	var root := Node3D.new()
	root.name = DRESSING
	_level.add_child(root)

	_plan_village()
	_plan_woods()
	_build_ground()
	_build_environment()
	_build_backdrop(root)
	_build_woods(root)
	_build_overpasses(root)
	_build_village(root)

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
	get_tree().quit()


# ======================================================================================
#  Saving
# ======================================================================================

## Every file this generator wrote last time, so a renamed or dropped resource leaves nothing behind.
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
#  Ground and roads
# ======================================================================================

## The terrain's vertex heights from the saved mesh, in grid order (TerrainGenerator._generate_mesh).
func _load_heights() -> PackedFloat32Array:
	var mesh: ArrayMesh = load(TERRAIN_MESH)
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var out := PackedFloat32Array()
	out.resize(verts.size())
	for i in range(verts.size()):
		out[i] = verts[i].y
	return out


## Ground height on the terrain's own triangles: each cell is split along the diagonal from (x + 1, z) to
## (x, z + 1), as TerrainGenerator indexes it.
func _ground(x: float, z: float) -> float:
	var gx: float = (x - GRID_START) / GRID_STEP
	var gz: float = (z - GRID_START) / GRID_STEP
	var x0: int = clampi(floori(gx), 0, GRID_RES - 1)
	var z0: int = clampi(floori(gz), 0, GRID_RES - 1)
	var fx: float = gx - float(x0)
	var fz: float = gz - float(z0)
	var stride := GRID_RES + 1
	var h00: float = _heights[z0 * stride + x0]
	var h10: float = _heights[z0 * stride + x0 + 1]
	var h01: float = _heights[(z0 + 1) * stride + x0]
	var h11: float = _heights[(z0 + 1) * stride + x0 + 1]
	if fx + fz <= 1.0:
		return h00 + fx * (h10 - h00) + fz * (h01 - h00)
	return h11 + (1.0 - fx) * (h01 - h11) + (1.0 - fz) * (h10 - h11)


## The ground's slope (rise per metre) over 2m either way.
func _slope(x: float, z: float) -> float:
	var dx := _ground(x + 2.0, z) - _ground(x - 2.0, z)
	var dz := _ground(x, z + 2.0) - _ground(x, z - 2.0)
	return Vector2(dx, dz).length() / 4.0


## The fall from (x, z) to the lowest ground within r: a tree there is sunk by part of it.
func _relief(x: float, z: float, r: float) -> float:
	var g := _ground(x, z)
	var lo := g
	for k in range(6):
		var a := TAU * k / 6.0
		lo = minf(lo, _ground(x + cos(a) * r, z + sin(a) * r))
	return g - lo


## The creek's centre line (TerrainGenerator's frostpeak_creek branch).
func _creek_x(z: float) -> float:
	return sin(z * 0.018) * 14.0


func _index_roads() -> void:
	var curves: Array = [[(_level.get_node("TrackPath") as Path3D).curve, TRUNK_HALF]]
	for sc in SHORTCUTS:
		var p := _level.get_node_or_null(sc[0]) as Path3D
		if p:
			curves.append([p.curve, sc[1]])
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


## Metres from (x, z) to the nearest road's edge (0 on a road), looking `reach` metres out (beyond it: reach).
func _road_edge_d(x: float, z: float, reach: float = 30.0) -> float:
	var best := reach
	var cr := int(ceil((reach + TRUNK_HALF) / ROAD_CELL))
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


## The ground map (see frostpeak_ground.gdshader): R the distance to the nearest road's edge, G the woods.
func _bake_ground_map() -> ImageTexture:
	var t0 := Time.get_ticks_msec()
	var texel := MAP_SIZE / float(MAP_RES)
	var road := PackedFloat32Array()
	road.resize(MAP_RES * MAP_RES)
	road.fill(ROAD_REACH)
	var woods := PackedFloat32Array()
	woods.resize(MAP_RES * MAP_RES)
	var lanes := PackedFloat32Array()
	lanes.resize(MAP_RES * MAP_RES)
	for lane in LANES:
		for li in range(lane.size() - 1):
			var a: Vector2 = lane[li]
			var b: Vector2 = lane[li + 1]
			var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2.ONE * (LANE_HALF + 3.0)
			var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2.ONE * (LANE_HALF + 3.0)
			for j in range(maxi(0, int((lo.y - MAP_ORIGIN.y) / texel)), mini(MAP_RES - 1, int((hi.y - MAP_ORIGIN.y) / texel)) + 1):
				for i in range(maxi(0, int((lo.x - MAP_ORIGIN.x) / texel)), mini(MAP_RES - 1, int((hi.x - MAP_ORIGIN.x) / texel)) + 1):
					var q := MAP_ORIGIN + Vector2(float(i) + 0.5, float(j) + 0.5) * texel
					var dl: float = q.distance_to(Geometry2D.get_closest_point_to_segment(q, a, b))
					var cover: float = 1.0 - smoothstep(LANE_HALF - 0.8, LANE_HALF + 1.2, dl)
					lanes[j * MAP_RES + i] = maxf(lanes[j * MAP_RES + i], cover)
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
					var cover: float = pow(1.0 - d2, 0.6)
					woods[j * MAP_RES + i] = maxf(woods[j * MAP_RES + i], cover)
	var data := PackedByteArray()
	data.resize(MAP_RES * MAP_RES * 4)
	for k in range(MAP_RES * MAP_RES):
		data[k * 4] = int(clampf(maxf(road[k], 0.0) / ROAD_REACH, 0.0, 1.0) * 255.0 + 0.5)
		data[k * 4 + 1] = int(clampf(woods[k], 0.0, 1.0) * 255.0 + 0.5)
		data[k * 4 + 2] = int(clampf(lanes[k], 0.0, 1.0) * 255.0 + 0.5)
		data[k * 4 + 3] = 255
	var img := Image.create_from_data(MAP_RES, MAP_RES, false, Image.FORMAT_RGBA8, data)
	print("  ground map baked (%.1fs)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	return _save_res(ImageTexture.create_from_image(img), "ground_map")


## frostpeak_ground.gdshader on the terrain, in place of the plain white material.
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
	m.set_shader_parameter("water_y", WATER_Y)
	_ground_mat = _save_res(m, "ground_mat")
	var tv := _level.get_node("TerrainGenerator/Terrain_Visual") as MeshInstance3D
	tv.material_override = _ground_mat
	# The roads' sides where they stand over the ground: granite retaining walls (they were the asphalt's own
	# texture, darkened, which read as brown earth).
	var wm := ShaderMaterial.new()
	wm.shader = load("res://frostpeak_wall.gdshader")
	var wall: Material = _save_res(wm, "wall_mat")
	for path in WALLS:
		var mi := _level.get_node_or_null(path) as MeshInstance3D
		if mi:
			mi.material_override = wall
		else:
			push_error("no %s to dress as a wall" % path)


# ======================================================================================
#  Overpasses
# ======================================================================================

## Where the lap's road stands this far over the ground on both sides of its line it is a bridge (the Jump 2
## approach crossing the start straight): TerrainGenerator draws nothing under it, and from below the curbs'
## 17m ribbon showed as a white slab.
const OVERPASS_CLEAR := 3.0
## The deck's depth under the road's surface, and its girders: lateral offsets, width, depth under the soffit.
const DECK_DEPTH := 1.0
const GIRDERS := [-5.2, 0.0, 5.2]
const GIRDER := Vector2(0.7, 0.9)


## Concrete undersides for the elevated stretches of the lap: a soffit from curb to curb, girders under it and a
## fascia along each edge, wherever the road's own mesh is there and the ground lies more than OVERPASS_CLEAR
## under its middle and both curbs.
func _build_overpasses(root: Node3D) -> void:
	var curve := (_level.get_node("TrackPath") as Path3D).curve
	var length := curve.get_baked_length()
	var road := (_level.get_node("TerrainGenerator/Visual_Road") as MeshInstance3D).mesh
	# Which 2m of the lap the road mesh covers (the jumps' flights have none).
	var covered := {}
	for si in range(road.get_surface_count()):
		var verts: PackedVector3Array = road.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
		for k in range(0, verts.size(), 3):
			covered[int(curve.get_closest_offset(verts[k]) / 2.0)] = true
	var runs: Array = []
	var run_start := -1.0
	var s := 0.0
	while s <= length:
		var p := curve.sample_baked(s)
		var r := _frame_right(curve, s)
		var high: bool = covered.has(int(s / 2.0)) and covered.has(int(s / 2.0) - 1)
		# The timber bridges carry their own decks.
		if bool(_tg.call("_in_frostpeak_bridge_zone", p.x, p.z)):
			high = false
		for lat in [-TRUNK_HALF, 0.0, TRUNK_HALF]:
			var q: Vector3 = p + r * lat
			if q.y - _ground(q.x, q.z) < OVERPASS_CLEAR:
				high = false
		if high and run_start < 0.0:
			run_start = s
		elif not high and run_start >= 0.0:
			runs.append(Vector2(run_start - 4.0, s + 2.0))
			run_start = -1.0
		s += 1.0
	if run_start >= 0.0:
		runs.append(Vector2(run_start - 4.0, length))
	if runs.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for run in runs:
		var a: float = maxf(run.x, 0.0)
		var b: float = minf(run.y, length)
		var n := int(ceil((b - a) / 1.0))
		var prev: Array = []
		for i in range(n + 1):
			var sv: float = lerpf(a, b, float(i) / float(n))
			var c := curve.sample_baked(sv) + Vector3(0.0, TRUNK_DECK_Y_UNDER, 0.0)
			var r2 := _frame_right(curve, sv)
			var bot := c + Vector3.DOWN * DECK_DEPTH
			# The section's points: fascia tops and feet, soffit edges, each girder's four corners.
			var sec := {
				"lt": c - r2 * (TRUNK_HALF + 0.05), "rt": c + r2 * (TRUNK_HALF + 0.05),
				"lb": bot - r2 * (TRUNK_HALF + 0.05), "rb": bot + r2 * (TRUNK_HALF + 0.05),
			}
			for gi in range(GIRDERS.size()):
				var gc: Vector3 = bot + r2 * float(GIRDERS[gi])
				sec["g%da" % gi] = gc - r2 * GIRDER.x * 0.5
				sec["g%db" % gi] = gc + r2 * GIRDER.x * 0.5
				sec["g%dc" % gi] = gc + r2 * GIRDER.x * 0.5 + Vector3.DOWN * GIRDER.y
				sec["g%dd" % gi] = gc - r2 * GIRDER.x * 0.5 + Vector3.DOWN * GIRDER.y
			if not prev.is_empty():
				var o: Dictionary = prev[0]
				# Soffit (faces down), fascias (face out).
				_quad_out(st, o["lb"], sec["lb"], sec["rb"], o["rb"], Vector3.DOWN)
				_quad_out(st, o["lt"], sec["lt"], sec["lb"], o["lb"], -r2)
				_quad_out(st, o["rt"], sec["rt"], sec["rb"], o["rb"], r2)
				for gi in range(GIRDERS.size()):
					var ga := "g%da" % gi
					var gb := "g%db" % gi
					var gcn := "g%dc" % gi
					var gd := "g%dd" % gi
					_quad_out(st, o[ga], sec[ga], sec[gd], o[gd], -r2)
					_quad_out(st, o[gb], sec[gb], sec[gcn], o[gcn], r2)
					_quad_out(st, o[gd], sec[gd], sec[gcn], o[gcn], Vector3.DOWN)
			prev = [sec]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://materials/concrete.png")
	mat.albedo_color = Color(0.66, 0.67, 0.69)
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(0.18, 0.18, 0.18)
	mat.roughness = 0.92
	var mi := MeshInstance3D.new()
	mi.name = "OverpassSoffit"
	var mesh := st.commit()
	mesh.surface_set_material(0, _save_res(mat, "overpass_mat"))
	mi.mesh = _save_res(mesh, "overpass")
	mi.set_meta(&"skip_dressing_colliders", true)
	root.add_child(mi)
	print("  overpasses: %s" % str(runs))


## The deck's top sits just under the road's surface, inside the curbs.
const TRUNK_DECK_Y_UNDER := -0.05


## The lap's right at s, flat.
func _frame_right(curve: Curve3D, s: float) -> Vector3:
	var t := (curve.sample_baked(minf(s + 0.5, curve.get_baked_length())) - curve.sample_baked(maxf(s - 0.5, 0.0)))
	t.y = 0.0
	t = t.normalized()
	return Vector3(-t.z, 0.0, t.x)


## A quad a-b-c-d wound to face `out` (Godot's front faces wind clockwise: the face normal is (c - a) x (b - a)).
func _quad_out(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3) -> void:
	var fn := (c - a).cross(b - a)
	if fn.dot(out) < 0.0:
		var t := b
		b = d
		d = t
	st.set_normal(out.normalized())
	for v in [a, b, c, a, c, d]:
		st.add_vertex(v)


# ======================================================================================
#  Sky, fog and the water
# ======================================================================================

func _build_environment() -> void:
	var we := _level.get_node("WorldEnvironment") as WorldEnvironment
	var env: Environment = we.environment.duplicate()
	env.fog_depth_begin = FOG.x
	env.fog_depth_end = FOG.y
	# Late: the fjord's walls 1-3km off stay crisp, the far end hazes over.
	env.fog_depth_curve = 1.8
	env.fog_aerial_perspective = 0.3
	we.environment = _save_res(env, "environment")
	# TerrainGenerator's water plane (1600m) stretched over the whole fjord, darker and with no fade to the sky
	# at its edge: the fog does that now.
	var water := _level.get_node("TerrainGenerator/Water_Surface") as MeshInstance3D
	var pm := PlaneMesh.new()
	pm.size = Vector2(9000.0, 9000.0)
	water.mesh = _save_res(pm, "fjord_plane")
	var wm: ShaderMaterial = (water.material_override as ShaderMaterial).duplicate()
	wm.set_shader_parameter("wave_scale", pm.size.x / 1600.0)
	wm.set_shader_parameter("enable_water_edge_fade", false)
	wm.set_shader_parameter("water_color", Color(0.03, 0.15, 0.24))
	wm.set_shader_parameter("shallow_color", Color(0.12, 0.42, 0.52))
	wm.set_shader_parameter("sky_tint", Color(0.60, 0.72, 0.84))
	# Deep and dark: at TerrainGenerator's mirror finish (metallic 0.65) the deep fjord reflected the pale sky
	# and read as a sheet of ice.
	wm.set_shader_parameter("metallic", 0.2)
	wm.set_shader_parameter("roughness", 0.12)
	wm.set_shader_parameter("sky_reflect", 0.38)
	wm.set_shader_parameter("deep_water_color", Color(0.01, 0.045, 0.07))
	water.material_override = _save_res(wm, "fjord_water_mat")


# ======================================================================================
#  The fjord and Svartfjell
# ======================================================================================

var _n_massif: FastNoiseLite
var _n_ridge: FastNoiseLite
var _n_shore: FastNoiseLite


func _fjord_axis(z: float) -> float:
	return 70.0 * sin(z / 1100.0) - 30.0


func _fjord_half(z: float) -> float:
	var w := FJORD_HALF
	if z < -500.0:
		w = lerpf(FJORD_HALF, 560.0, smoothstep(0.0, 1.0, (-500.0 - z) / 1500.0))
	if z > 500.0:
		w += (z - 500.0) * 0.42
	return w


## Smooth maximum of a and b over k metres.
func _smax(a: float, b: float, k: float) -> float:
	var h := clampf(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
	return lerpf(a, b, h) + k * h * (1.0 - h)


## Metres inland from the fjord's shore (negative out over the water).
func _inland(x: float, z: float) -> float:
	var dx := absf(x - _fjord_axis(z)) - _fjord_half(z)
	var d := _smax(dx, FJORD_HEAD_Z - z, 220.0)
	# Headlands and bays.
	return d + _n_shore.get_noise_2d(x, z) * 170.0


## Svartfjell's height at (x, z) (far under the fjord's bed off its foot, so the smooth maximum that sets it into
## the fjord leaves the bed alone there: at 0 it lifted the whole bed to the waterline): a horn whose faces are concave and steepest near the summit,
## ridges of different lengths running off it, shoulders standing on them, the faces broken into buttresses.
func _svart(x: float, z: float) -> float:
	var v := Vector2(x, z) - SVART_AT
	var dist := v.length()
	if dist > 1450.0:
		return -500.0
	var ang := atan2(v.y, v.x)
	var r := SVART_CORE
	for a in SVART_ARETES:
		var k := pow(maxf(cos(ang - float(a[0])), 0.0), 10.0)
		r = maxf(r, lerpf(SVART_CORE, float(a[1]), k))
	r *= 1.0 + _n_ridge.get_noise_2d(x * 1.1, z * 1.1) * 0.12
	var t := clampf(1.0 - dist / r, 0.0, 1.0)
	if t <= 0.0:
		return -500.0
	var h := SVART_H * pow(t, 1.45)
	for sh in SVART_SHOULDERS:
		var ds: float = (Vector2(x, z) - SVART_AT - (sh[0] as Vector2)).length()
		var ts := clampf(1.0 - ds / float(sh[2]), 0.0, 1.0)
		h = maxf(h, float(sh[1]) * pow(ts, 1.3))
	# Buttresses and gullies down the faces.
	h *= 1.0 + _n_ridge.get_noise_2d(x * 2.3, z * 2.3) * 0.07 * sqrt(t)
	return h


## The country's height at (x, z): the fjord's bed, the walls rising from its shore to shoulders and peaks,
## lower toward the sea in the south, and Svartfjell at its head.
func _back_height(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	var d := _inland(x, z)
	var h: float
	if d < 0.0:
		h = WATER_Y - 2.0 + (FJORD_BED - WATER_Y) * smoothstep(0.0, 1.0, -d / 260.0)
	else:
		var massif := clampf(_n_massif.get_noise_2d(x, z) * 0.5 + 0.5, 0.0, 1.0)
		var ridge := clampf(_n_ridge.get_noise_2d(x, z) * 0.5 + 0.5, 0.0, 1.0)
		var wall := 440.0 * (1.0 - exp(-d / 210.0)) * (0.7 + 0.6 * massif)
		var high := 640.0 * smoothstep(250.0, 1800.0, d) * (0.35 + 0.85 * massif) * (0.65 + 0.5 * ridge)
		h = wall + high + ridge * 120.0 * smoothstep(60.0, 500.0, d)
		# The shore: a low rocky foot over the first metres.
		h *= smoothstep(-5.0, 60.0, d) * 0.85 + 0.15 * smoothstep(0.0, 8.0, d)
		h = maxf(h, WATER_Y + 0.4 + d * 0.15)
		# Lower toward the sea in the south.
		h *= lerpf(1.0, 0.4, smoothstep(0.0, 1.0, (z - 1300.0) / 2200.0))
	h = _smax(h, _svart(x, z), 70.0)
	# The far edge sinks into the haze, so the ring has no wall at its rim.
	h = lerpf(h, minf(h, 120.0), smoothstep(BACK_R1 - 500.0, BACK_R1, r))
	# Under the island's rim (TerrainGenerator's edge falloff takes its ground to -40 there).
	if r < 470.0:
		h = minf(h, lerpf(-41.0, h, smoothstep(440.0, 470.0, r)))
	return h


## The ring of ground in BACK_SECTORS meshes (so each is culled on its own), rings 4m apart at the rim widening
## outward; vertex colour g black rock (Svartfjell).
func _build_backdrop(root: Node3D) -> void:
	var t0 := Time.get_ticks_msec()
	_n_massif = FastNoiseLite.new()
	_n_massif.seed = 4402
	_n_massif.frequency = 1.0 / 1500.0
	_n_massif.fractal_octaves = 2
	_n_ridge = FastNoiseLite.new()
	_n_ridge.seed = 1771
	_n_ridge.frequency = 1.0 / 520.0
	_n_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_n_ridge.fractal_octaves = 5
	_n_shore = FastNoiseLite.new()
	_n_shore.seed = 905
	_n_shore.frequency = 1.0 / 700.0
	_n_shore.fractal_octaves = 3
	var node := Node3D.new()
	node.name = "Fjord"
	root.add_child(node)

	var radii := PackedFloat32Array()
	var r := BACK_R0
	while r < 520.0:
		radii.append(r)
		r += 4.0
	while r < BACK_R1:
		radii.append(r)
		r *= 1.024
	radii.append(BACK_R1)
	var nr := radii.size()
	var pts := PackedVector3Array()
	pts.resize(nr * BACK_SEGS)
	for i in range(nr):
		for j in range(BACK_SEGS):
			var a := TAU * j / BACK_SEGS
			var x := cos(a) * radii[i]
			var z := sin(a) * radii[i]
			pts[i * BACK_SEGS + j] = Vector3(x, _back_height(x, z), z)
	var nrms := PackedVector3Array()
	nrms.resize(pts.size())
	var cols := PackedColorArray()
	cols.resize(pts.size())
	for i in range(nr):
		for j in range(BACK_SEGS):
			var p := pts[i * BACK_SEGS + j]
			var pl := pts[i * BACK_SEGS + (j + BACK_SEGS - 1) % BACK_SEGS]
			var pr := pts[i * BACK_SEGS + (j + 1) % BACK_SEGS]
			var pi := pts[maxi(i - 1, 0) * BACK_SEGS + j]
			var po := pts[mini(i + 1, nr - 1) * BACK_SEGS + j]
			var n := (po - pi).cross(pr - pl).normalized()
			if n.y < 0.0:
				n = -n
			nrms[i * BACK_SEGS + j] = n
			var svart := _svart(p.x, p.z)
			var black := smoothstep(0.0, 120.0, svart - 0.6 * (p.y - svart))
			cols[i * BACK_SEGS + j] = Color(0.0, black, 0.0, 1.0)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://fjord_mountain.gdshader")
	mat.set_shader_parameter("rock_albedo", load("res://materials/dark_canyon_rock.png"))
	mat.set_shader_parameter("water_y", WATER_Y)
	var saved_mat: Material = _save_res(mat, "fjord_mat")
	var per: int = BACK_SEGS / BACK_SECTORS
	var tris := 0
	for s in range(BACK_SECTORS):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var j0 := s * per
		for i in range(nr):
			for jj in range(per + 1):
				var k := i * BACK_SEGS + (j0 + jj) % BACK_SEGS
				st.set_normal(nrms[k])
				st.set_color(cols[k])
				st.add_vertex(pts[k])
		var w := per + 1
		for i in range(nr - 1):
			for jj in range(per):
				var a := i * w + jj
				var b := a + 1
				var c := a + w
				var d := c + 1
				for tri in [[a, b, c], [b, d, c]]:
					st.add_index(tri[0])
					st.add_index(tri[1])
					st.add_index(tri[2])
					tris += 1
		var mesh := st.commit()
		# Front faces wind clockwise seen from above ((c - a) x (b - a) points up): check one triangle and flip the
		# whole sector's winding if it came out the other way.
		mesh = _wind_up(mesh)
		mesh.surface_set_material(0, saved_mat)
		var mi := MeshInstance3D.new()
		mi.name = "BackdropGround_%d" % s
		mi.mesh = _save_res(mesh, "fjord_%d" % s)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mi)
	print("  fjord: %d rings x %d, %d triangles, Svartfjell %.0fm at %s (%.1fs)" % [nr, BACK_SEGS, tris,
			_back_height(SVART_AT.x, SVART_AT.y), str(SVART_AT), (Time.get_ticks_msec() - t0) / 1000.0])


## Rewinds a mesh's triangles if its first upward-facing triangle faces down (Godot's front faces wind
## clockwise: the face normal is (c - a) x (b - a)).
func _wind_up(mesh: ArrayMesh) -> ArrayMesh:
	var arrays := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var votes := 0
	for t in range(0, mini(idx.size(), 3000), 3):
		var fn := (v[idx[t + 2]] - v[idx[t]]).cross(v[idx[t + 1]] - v[idx[t]])
		votes += 1 if fn.y > 0.0 else -1
	if votes >= 0:
		return mesh
	for t in range(0, idx.size(), 3):
		var tmp := idx[t + 1]
		idx[t + 1] = idx[t + 2]
		idx[t + 2] = tmp
	arrays[Mesh.ARRAY_INDEX] = idx
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


# ======================================================================================
#  The woods
# ======================================================================================

## Mesh index: [spruce 0, spruce 1, birch 0, birch 1].
const MESH_KINDS := ["spruce", "spruce", "birch", "birch"]


func _reserved_share(x: float, z: float) -> float:
	var share := 1.0
	for rz in RESERVED:
		var inside := minf(minf(x - float(rz[0]), float(rz[2]) - x), minf(z - float(rz[1]), float(rz[3]) - z))
		# Thinning toward the clearing over 25m.
		share = minf(share, lerpf(1.0, float(rz[4]), smoothstep(-25.0, 0.0, inside)))
	return share


## Where the trees stand: stands of spruce on the valley's flanks and up the ridges, open snowfields on the valley
## floor by the road, birch along the creek's banks and on the edges of the woods.
func _plan_woods() -> void:
	var t0 := Time.get_ticks_msec()
	var forest := FastNoiseLite.new()
	forest.seed = 2207
	forest.frequency = 0.0065
	forest.fractal_octaves = 3
	var kind_noise := FastNoiseLite.new()
	kind_noise.seed = 811
	kind_noise.frequency = 0.014
	kind_noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	_rng.seed = 51907
	var counts := {"spruce": 0, "birch": 0}
	# Its own stream, so the ranks leave the placement's draws alone.
	var rank_rng := RandomNumberGenerator.new()
	rank_rng.seed = 4093
	var x := -WOODS_R
	while x <= WOODS_R:
		var z := -WOODS_R
		while z <= WOODS_R:
			var px: float = x + _rng.randf_range(-0.45, 0.45) * TREE_STEP
			var pz: float = z + _rng.randf_range(-0.45, 0.45) * TREE_STEP
			z += TREE_STEP
			var roll := _rng.randf()
			var r := Vector2(px, pz).length()
			if r > WOODS_R:
				continue
			var g := _ground(px, pz)
			if g < WATER_Y + 0.9:
				continue
			# Woods where the noise is high, thicker up the flanks, thin on the valley floor.
			var flank := smoothstep(70.0, 200.0, absf(px)) * 0.22 + clampf((g - 8.0) * 0.012, -0.08, 0.12)
			var f: float = forest.get_noise_2d(px, pz) + flank
			var dens: float = lerpf(0.02, 0.88, smoothstep(-0.04, 0.30, f))
			dens *= _reserved_share(px, pz)
			if roll > dens:
				continue
			if _slope(px, pz) > 0.75:
				continue
			var creek_d := absf(px - _creek_x(pz))
			var kn: float = kind_noise.get_noise_2d(px, pz)
			var kind := "spruce"
			if (creek_d < 48.0 and g < 7.0) or kn > 0.45 or (dens < 0.4 and _rng.randf() < 0.45):
				kind = "birch"
			var rd := _road_edge_d(px, pz, 40.0)
			if rd < float(TREE_CLEAR[kind]):
				continue
			var v: int = (0 if _rng.randf() < 0.6 else 1) if kind == "spruce" else _rng.randi() % 2
			var mi: int = (0 if kind == "spruce" else 2) + v
			var sc: float
			if kind == "spruce":
				sc = _rng.randf_range(1.0, 1.7) if v == 0 else _rng.randf_range(0.95, 1.45)
			else:
				sc = _rng.randf_range(0.72, 1.0)
			var crown: float = (3.75 if v == 0 else 3.55) * sc if kind == "spruce" else 3.9 * sc
			# A tree on a slope sinks a little, or its downhill roots hang in the air.
			var y: float = g - 0.25 - minf(_relief(px, pz, 2.5) * 0.6, 1.0)
			# The crown keeps TREE_CLEAR from the road's edge, and off the village's buildings and lanes.
			if rd < crown + float(TREE_CLEAR[kind]) or _in_village(px, pz, crown + 1.0):
				continue
			var lean := Basis(Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized(), _rng.randf_range(0.0, 0.04))
			var xf := Transform3D(lean * Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(sc, sc * _rng.randf_range(0.92, 1.12), sc)), Vector3(px, y, pz))
			var rank: float = rank_rng.randf() * lerpf(RANK_NEAR_ROAD, 1.0,
					smoothstep(RANK_ROAD.x, RANK_ROAD.y, _road_edge_d(px, pz, RANK_ROAD.y)))
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


## A cell's trees in rank order, the ranks in its meta `ranks` (SnowWoodsDetail.gd draws the first of them), its
## rich mesh (the Detail Level's Ultra, as saved) and its light one in metas `rich_mesh` and `light_mesh`.
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


## The woods in Lakeside's layers: Tree_ near cells with TreeShadow_ stand-ins casting their shadow below Ultra,
## TreeFar_ stand-ins beyond. Saved as the Detail Level's Ultra draws them (every tree, the rich meshes);
## SnowWoodsDetail.gd draws a share of them, in their light meshes, below it.
func _build_woods(root: Node3D) -> void:
	var t0 := Time.get_ticks_msec()
	var node := Node3D.new()
	node.name = "Woods"
	root.add_child(node)
	var kit := SnowTreeKit.new()
	kit.save_res = func(res: Resource, n: String) -> Resource: return _save_res(res, n)
	# [near rich, near light, far rich, far light] per mesh index.
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
	print("  tree meshes built (%.1fs), skirt radii %s" % [(Time.get_ticks_msec() - t0) / 1000.0, str(band_r)])
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
		# Ultra: the detailed trees cast their own shadows (as JungleDetail's Ultra does).
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
		# SnowWoodsDetail.gd switches off the colliders of the trees a Detail Level doesn't draw.
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
#  Svartvik, the fishing village on the south shore
# ======================================================================================

const FjordVillageKit = preload("res://FjordVillageKit.gd")
const ShipKit = preload("res://ShipKit.gd")
## People-sized things are built at life size and grown by this, as on the other stages.
const PROP_SCALE := 1.6
## The lanes (world xz polylines), painted into the ground map's B as trodden snow: the street along the shore's flat
## from the west terrace up to the church on the east one, and the lane down to the harbour.
const LANES := [
	[Vector2(-165.0, 318.0), Vector2(-125.0, 326.0), Vector2(-80.0, 330.0), Vector2(-35.0, 327.0), Vector2(5.0, 320.0),
		Vector2(45.0, 314.0), Vector2(85.0, 316.0), Vector2(112.0, 322.0)],
	[Vector2(-28.0, 327.0), Vector2(-22.0, 350.0), Vector2(-16.0, 368.0)],
]
const LANE_HALF := 3.2
## Houses stand along the street every HOUSE_STEP metres on each side, their fronts HOUSE_SETBACK from its middle.
const HOUSE_STEP := 21.0
const HOUSE_SETBACK := 7.0
## The most a house's ground may fall across its footprint (its stone foundation takes it up).
const HOUSE_MAX_DROP := 3.2
## Nothing of the village comes nearer a road's edge than this.
const VILLAGE_ROAD_CLEAR := 22.0
## The church: the middle of its south (front) wall's foot, its turn (the tower at the north end, facing the lap).
const CHURCH_AT := Vector2(120.0, 322.0)
## The waterfront: rorbuer and boathouses along the shore between these x, the quay at QUAY_X.
const SHORE_X := Vector2(-98.0, 42.0)
const QUAY_X := -14.0
const SMOKE_PARTICLES := 10

## The village's footprints in plan: [centre, radius], for keeping trees and other buildings off them.
var _village_spots: Array = []
## The village's buildings: [kind, Transform3D (frame at PROP_SCALE), args...].
var _village: Array = []
## Chimney mouths (world), for the smoke.
var _chimneys: Array = []


func _in_village(x: float, z: float, r: float) -> bool:
	var p := Vector2(x, z)
	for spot in _village_spots:
		if p.distance_to(spot[0]) < float(spot[1]) + r:
			return true
	for lane in LANES:
		for li in range(lane.size() - 1):
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, lane[li], lane[li + 1])) < LANE_HALF + r:
				return true
	return false


## The frame of a building whose front (local +z) faces `front` (world, flat), its origin at `at`.
func _frame(at: Vector3, front: Vector2) -> Transform3D:
	var f := Vector3(front.x, 0.0, front.y).normalized()
	var x := Vector3.UP.cross(f).normalized()
	return Transform3D(Basis(x, Vector3.UP, f).scaled(Vector3.ONE * PROP_SCALE), at)


## Ground under a footprint (life-size local rect from x0..x1, z0..z1 in `xf`'s frame): [min, max] over a 4 x 4 grid.
func _ground_span(xf: Transform3D, x0: float, x1: float, z0: float, z1: float) -> Vector2:
	var lo := INF
	var hi := -INF
	for i in range(4):
		for j in range(4):
			var w: Vector3 = xf * Vector3(lerpf(x0, x1, float(i) / 3.0), 0.0, lerpf(z0, z1, float(j) / 3.0))
			var g := _ground(w.x, w.z)
			lo = minf(lo, g)
			hi = maxf(hi, g)
	return Vector2(lo, hi)


## Plans every building of the village (before the woods, which keep off it).
func _plan_village() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5417
	# The church on the east terrace: its axis along z, the tower at the north end.
	var cxf := Transform3D(Basis(Vector3.UP, -PI * 0.5).scaled(Vector3.ONE * PROP_SCALE), Vector3(CHURCH_AT.x, 0.0, CHURCH_AT.y))
	var cspan := _ground_span(cxf, -12.6, 13.2, -10.2, 0.2)
	cxf.origin.y = cspan.y
	_village.append(["church", cxf, (cspan.y - cspan.x) / PROP_SCALE + 0.6])
	_village_spots.append([Vector2(CHURCH_AT.x + 8.0, CHURCH_AT.y), 24.0])
	# Houses along the street, both sides.
	var street: Array = LANES[0]
	var houses := 0
	var skipped := {}
	for side in [-1.0, 1.0]:
		var walked := HOUSE_STEP * (0.5 if side > 0.0 else 1.0)
		for li in range(street.size() - 1):
			var a: Vector2 = street[li]
			var b: Vector2 = street[li + 1]
			var seg := a.distance_to(b)
			var dir := (b - a) / seg
			var nrm: Vector2 = Vector2(-dir.y, dir.x) * float(side)
			var t := walked
			while t < seg:
				var p: Vector2 = a + dir * t
				t += HOUSE_STEP + rng.randf_range(-3.0, 4.0)
				var w: float = rng.randf_range(8.0, 11.0)
				var d: float = rng.randf_range(6.2, 7.4)
				var floors: float = [1.0, 1.5, 1.5, 2.0][rng.randi() % 4]
				var paint: Color = FjordVillageKit.PAINTS[rng.randi() % FjordVillageKit.PAINTS.size()]
				var front: Vector2 = p + nrm * (HOUSE_SETBACK + rng.randf_range(-0.8, 1.5))
				var xf := _frame(Vector3(front.x, 0.0, front.y), -nrm)
				var why := _house_fits(xf, w, d)
				if why != "":
					skipped[why] = int(skipped.get(why, 0)) + 1
					continue
				var span := _ground_span(xf, -w * 0.5, w * 0.5, -d, 0.0)
				xf.origin.y = span.y + 0.05
				var centre: Vector3 = xf * Vector3(0, 0, -d * 0.5)
				_village_spots.append([Vector2(centre.x, centre.z), Vector2(w, d).length() * 0.5 * PROP_SCALE + 1.5])
				_village.append(["house", xf, w, d, floors, paint, (span.y - span.x) / PROP_SCALE + 0.5, rng.randf_range(-0.2, 0.2), rng.randi()])
				houses += 1
			walked = t - seg
	# The waterfront: rorbuer and boathouses in turn along the shore, the quay in a gap of their own.
	var shore := 0
	var x := SHORE_X.x
	var k := 0
	while x <= SHORE_X.y:
		var here := x
		x += rng.randf_range(12.0, 16.0)
		if absf(here - QUAY_X) < 20.0:
			continue
		var zw := _shore_z(here)
		if is_nan(zw):
			continue
		var kind: String = "rorbu" if k % 3 != 2 else "naust"
		k += 1
		var w2: float = 5.0 if kind == "rorbu" else 5.5
		var d2: float = 7.0 if kind == "rorbu" else 8.0
		# The front (+z, south) a metre in from the waterline: a rorbu's deck stands out over the water.
		var xf2 := _frame(Vector3(here, 0.0, zw - 1.0), Vector2(0, 1))
		var span2 := _ground_span(xf2, -w2 * 0.5, w2 * 0.5, -d2, 0.0)
		if _in_village(here, zw - 1.0 - d2 * 0.8, d2 * 0.6):
			continue
		if span2.y - span2.x > 5.0:
			continue
		if kind == "rorbu":
			var floor_y: float = maxf(WATER_Y + 1.7, span2.y + 0.35)
			xf2.origin.y = floor_y
			var deck_low: float = minf(span2.x, _ground(here, zw + 2.5))
			_village.append(["rorbu", xf2, w2, d2, FjordVillageKit.PAINTS[1] if rng.randf() < 0.7 else FjordVillageKit.PAINTS[2],
					(floor_y - deck_low) / PROP_SCALE + 0.6, rng.randi()])
		else:
			xf2.origin.y = span2.y
			_village.append(["naust", xf2, w2, d2, (span2.y - span2.x) / PROP_SCALE + 0.4])
		var c2: Vector3 = xf2 * Vector3(0, 0, -d2 * 0.5)
		_village_spots.append([Vector2(c2.x, c2.z), Vector2(w2, d2).length() * 0.5 * PROP_SCALE + 1.0])
		shore += 1
	# The quay, out from the harbour lane's end over the water.
	var zq := _shore_z(QUAY_X)
	if not is_nan(zq):
		var qxf := _frame(Vector3(QUAY_X, WATER_Y, zq - 2.0), Vector2(0, 1))
		var depth: float = (WATER_Y - _ground(QUAY_X, zq + 6.0)) / PROP_SCALE + 0.8
		_village.append(["quay", qxf, 20.0, 5.0, 1.35, maxf(depth, 1.5)])
		_village_spots.append([Vector2(QUAY_X, zq + 2.0), 18.0])
		# Two fishing boats: one alongside the quay's outer edge, the other rafted outside it, bow the other way.
		for bi in range(2):
			var bx: float = QUAY_X + (1.0 if bi == 0 else -2.0)
			var bz: float = zq - 2.0 + 5.0 * PROP_SCALE + 2.45 * PROP_SCALE * (1.0 + 2.0 * float(bi)) + 0.9 + 0.6 * float(bi)
			var yaw: float = PI * 0.5 if bi == 0 else -PI * 0.5
			_village.append(["boat", Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * PROP_SCALE), Vector3(bx, WATER_Y, bz)),
					Color(0.55, 0.14, 0.11) if bi == 0 else Color(0.16, 0.30, 0.48), Color(0.93, 0.92, 0.88)])
	# Racks of stockfish on the shore's flat.
	for hs in [[Vector2(18.0, 352.0), 0.25], [Vector2(-62.0, 358.0), -0.15], [Vector2(-40.0, 362.0), -0.1]]:
		var hp: Vector2 = hs[0]
		if _in_village(hp.x, hp.y, 4.0) or _ground(hp.x, hp.y) < WATER_Y + 0.6:
			continue
		var hxf := Transform3D(Basis(Vector3.UP, float(hs[1])).scaled(Vector3.ONE * PROP_SCALE), Vector3(hp.x, _ground(hp.x, hp.y), hp.y))
		_village.append(["hjell", hxf, 12.0, rng.randi()])
		_village_spots.append([hp, 12.0])
	print("  village planned: church, %d houses, %d on the waterfront, quay at z %.0f; houses skipped %s" % [houses, shore, zq, str(skipped)])


## Why a house can't stand in frame `xf` (w x d life size), or "".
func _house_fits(xf: Transform3D, w: float, d: float) -> String:
	var centre: Vector3 = xf * Vector3(0, 0, -d * 0.5)
	var r: float = Vector2(w, d).length() * 0.5 * PROP_SCALE
	if _road_edge_d(centre.x, centre.z, VILLAGE_ROAD_CLEAR + r) < VILLAGE_ROAD_CLEAR + r:
		return "road"
	var span := _ground_span(xf, -w * 0.5, w * 0.5, -d, 0.0)
	if span.x < WATER_Y + 0.5:
		return "water"
	if span.y - span.x > HOUSE_MAX_DROP:
		return "slope"
	for spot in _village_spots:
		if Vector2(centre.x, centre.z).distance_to(spot[0]) < float(spot[1]) + r:
			return "taken"
	# Off the lanes (the street it faces is kept clear by the setback).
	for lane in LANES:
		for li in range(lane.size() - 1):
			if Vector2(centre.x, centre.z).distance_to(Geometry2D.get_closest_point_to_segment(Vector2(centre.x, centre.z), lane[li], lane[li + 1])) < LANE_HALF + r * 0.8:
				return "lane"
	return ""


## The z of the waterline south of the village at x (the first metre from z 330 southward under the water), or NAN.
func _shore_z(x: float) -> float:
	var z := 330.0
	while z < 420.0:
		if _ground(x, z) < WATER_Y - 0.1:
			return z if z > 355.0 else NAN
		z += 1.0
	return NAN


## Builds the planned village: its buildings in batches by 120m of x (one mesh each, made solid by DressingColliders),
## the boats, kick-sleds and woodpiles by some doors, and chimney smoke.
func _build_village(root: Node3D) -> void:
	var t0 := Time.get_ticks_msec()
	var node := Node3D.new()
	node.name = "Svartvik"
	root.add_child(node)
	var rng := RandomNumberGenerator.new()
	rng.seed = 991
	var batches := {}
	var boat_pk := ShipKit.new_port_kit(PROP_SCALE)
	var boat_kit := {}
	for b in _village:
		var xf: Transform3D = b[1]
		if b[0] == "boat":
			boat_pk.set_frame(xf)
			ShipKit.fishing_boat(boat_pk, boat_kit, b[2], b[3])
			continue
		var key := floori((xf.origin.x + 200.0) / 120.0)
		if not batches.has(key):
			batches[key] = [FjordVillageKit.new_village_kit(PROP_SCALE), {}]
		var pk: PropKit = batches[key][0]
		var kit: Dictionary = batches[key][1]
		pk.set_frame(xf)
		match b[0]:
			"church":
				FjordVillageKit.church(pk, kit, b[2])
			"house":
				var mouth: Vector3 = FjordVillageKit.house(pk, kit, b[2], b[3], b[4], b[5], b[6], b[7], b[8])
				_chimneys.append(xf * mouth)
				# A woodpile against one gable, a kick-sled by some doors (on their own ground).
				var gx: float = (float(b[2]) * 0.5 + 0.45) * (1.0 if rng.randf() < 0.5 else -1.0)
				var wp: Vector3 = xf * Vector3(gx, 0, -float(b[3]) * 0.5)
				pk.set_frame(Transform3D(xf.basis * Basis(Vector3.UP, PI * 0.5), Vector3(wp.x, _ground(wp.x, wp.z) - 0.05, wp.z)))
				FjordVillageKit.woodpile(pk, kit, float(b[3]) * 0.6, int(b[8]))
				if rng.randf() < 0.45:
					var sp: Vector3 = xf * Vector3(float(b[7]) * float(b[2]) + 1.6, 0, 1.8)
					pk.set_frame(Transform3D(xf.basis * Basis(Vector3.UP, rng.randf_range(-0.6, 0.6)), Vector3(sp.x, _ground(sp.x, sp.z), sp.z)))
					FjordVillageKit.spark(pk, kit)
			"rorbu":
				var mouth2: Vector3 = FjordVillageKit.rorbu(pk, kit, b[2], b[3], b[4], b[5], b[6])
				_chimneys.append(xf * mouth2)
			"naust":
				FjordVillageKit.naust(pk, kit, b[2], b[3], b[4])
			"quay":
				FjordVillageKit.quay(pk, kit, b[2], b[3], b[4], b[5])
			"hjell":
				FjordVillageKit.hjell(pk, kit, b[2], b[3])
	var tris := 0
	for key in batches.keys():
		var mesh: ArrayMesh = FjordVillageKit.commit(batches[key][0], batches[key][1])
		_save_village_materials(mesh)
		var mi := MeshInstance3D.new()
		mi.name = "Svartvik_%d" % key
		mi.mesh = _save_res(mesh, "village_%d" % key)
		node.add_child(mi)
		tris += _tri_count(mesh)
	if not boat_kit.is_empty():
		var bmesh: ArrayMesh = ShipKit.commit_port(boat_pk, boat_kit)
		var bmi := MeshInstance3D.new()
		bmi.name = "FishingBoats"
		bmi.mesh = _save_res(bmesh, "village_boats")
		node.add_child(bmi)
		tris += _tri_count(bmesh)
	_build_smoke(node)
	print("  village: %d buildings in %d batches, %d triangles, %d chimneys smoking (%.1fs)" % [_village.size(), batches.size(), tris,
			_chimneys.size(), (Time.get_ticks_msec() - t0) / 1000.0])


## Saves each of a kit mesh's materials once under its key, so the batches share them and the level holds no copies.
var _village_mats := {}

func _save_village_materials(mesh: ArrayMesh) -> void:
	for i in range(mesh.get_surface_count()):
		var m := mesh.surface_get_material(i)
		if m == null:
			continue
		var id := m.get_instance_id()
		if not _village_mats.has(id):
			_village_mats[id] = _save_res(m, "village_mat_%d" % _village_mats.size())
		mesh.surface_set_material(i, _village_mats[id])


func _tri_count(mesh: ArrayMesh) -> int:
	var t := 0
	for s in mesh.get_surface_count():
		t += (mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return t


## Wood smoke from every chimney: a few soft grey puffs rising slowly and drifting off with the wind (from the
## south-west), one shared material and mesh.
func _build_smoke(node: Node3D) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.25
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 8.0
	pm.initial_velocity_min = 1.2
	pm.initial_velocity_max = 1.8
	pm.gravity = Vector3(0.45, 0.05, -0.35)
	pm.damping_min = 0.05
	pm.damping_max = 0.1
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -8.0
	pm.angular_velocity_max = 8.0
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.25))
	sc.add_point(Vector2(1.0, 1.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var grad := Gradient.new()
	var c := Color(0.78, 0.79, 0.81)
	grad.colors = PackedColorArray([Color(c, 0.0), Color(c, 0.42), Color(c, 0.18), Color(c, 0.0)])
	grad.offsets = PackedFloat32Array([0.0, 0.1, 0.55, 1.0])
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	var puff := GradientTexture2D.new()
	puff.fill = GradientTexture2D.FILL_RADIAL
	puff.fill_from = Vector2(0.5, 0.5)
	puff.fill_to = Vector2(0.5, 0.0)
	var pg := Gradient.new()
	pg.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	puff.gradient = pg
	puff.width = 64
	puff.height = 64
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mat.disable_receive_shadows = true
	mat.albedo_texture = puff
	var quad := QuadMesh.new()
	quad.size = Vector2(3.2, 3.2)
	quad.material = _save_res(mat, "smoke_mat")
	var saved_pm: ParticleProcessMaterial = _save_res(pm, "smoke_process")
	var saved_quad: Mesh = _save_res(quad, "smoke_quad")
	var i := 0
	for m in _chimneys:
		var p := GPUParticles3D.new()
		p.name = "ChimneySmoke_%d" % i
		p.position = m
		p.amount = SMOKE_PARTICLES
		p.lifetime = 9.0
		p.preprocess = 9.0
		p.randomness = 0.4
		p.process_material = saved_pm
		p.draw_pass_1 = saved_quad
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.visibility_aabb = AABB(Vector3(-12, -2, -12), Vector3(24, 22, 24))
		node.add_child(p)
		i += 1
