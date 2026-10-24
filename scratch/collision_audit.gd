extends Node

# Lists what a cart would drive straight through: for every mesh (and MultiMesh instance) within
# `reach` of the lap, the 1m cells where its geometry is at a cart's height (0.4 to 1.4m over the
# ground), each tested with a sphere for any collider other than the ground and the road. A cell with
# none is open: the cart drives through whatever is drawn there. Runs the level as a spectator race,
# so Level.gd's runtime colliders exist. Headless:
#   Godot --headless --path . res://scratch/collision_audit.tscn -- res://levels/X.tscn [reach=30] [all=1]
# Grouped by node; all=1 lists every instance.

const SKIP := ["Grass", "Meadow", "Terrain_Visual", "Visual_Road", "Visual_Curbs", "Water", "Sky", "Decal", "Spawn",
		"FxWarmup", "Players", "Cloud", "Shadow", "Far", "Wake", "Particles", "ItemBox", "GateBuild", "Crowd"]
const GROUND_BODIES := ["Unified_World_Collision", "Track_Collision", "Terrain", "Ground", "Road"]

var reach := 30.0
var list_all := false
var _space: PhysicsDirectSpaceState3D
var _curve: Curve3D
var _tp: Path3D
var _lap_cells := {}   # Vector2i (20m cells) -> PackedVector2Array of lap points 2m apart


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("reach="): reach = float(a.substr(6))
		elif a == "all=1": list_all = true
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	var level: Node = load(args[0]).instantiate()
	add_child(level)
	await level.wait_for_collisions()
	for i in 10:
		await get_tree().physics_frame
	# The carts would block the rays.
	for c in get_tree().get_nodes_in_group("player_carts"):
		c.global_position += Vector3(0, 500, 0)
		c.freeze = true
	for i in 3:
		await get_tree().physics_frame
	_space = level.get_world_3d().direct_space_state
	_tp = level.track_path
	_curve = _tp.curve
	var length := _curve.get_baked_length()
	var s := 0.0
	while s < length:
		var p := _tp.to_global(_curve.sample_baked(s))
		var k := Vector2i(floori(p.x / 20.0), floori(p.z / 20.0))
		if not _lap_cells.has(k):
			_lap_cells[k] = PackedVector2Array()
		_lap_cells[k].append(Vector2(p.x, p.z))
		s += 2.0
	var found := {}
	_walk(level, found)
	var total := 0
	var keys := found.keys()
	keys.sort()
	for k in keys:
		var e: Array = found[k]
		total += e.size()
		var nearest := INF
		for f in e:
			nearest = minf(nearest, float(f[1]))
		var cells := 0
		for f in e:
			cells += int(f[2])
		print("NO COLLISION %-60s x%d (%d open cells)  nearest %.1fm from the lap, e.g. at %s" % [k, e.size(), cells, nearest, e[0][0]])
		if list_all:
			for f in e:
				print("    at %s, %.1fm, %d cells" % [f[0], f[1], f[2]])
	print("TOTAL %d objects without collision within %.0fm" % [total, reach])
	get_tree().quit()


func _walk(n: Node, found: Dictionary) -> void:
	var nm := str(n.name)
	for sk in SKIP:
		if sk in nm:
			return
	if n is Node3D and not (n as Node3D).visible:
		return
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mi := n as MeshInstance3D
		_test_mesh(mi.mesh, mi.global_transform, str(mi.get_path()), found)
	elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh and (n as MultiMeshInstance3D).multimesh.mesh:
		var mmi := n as MultiMeshInstance3D
		var mm := mmi.multimesh
		var buf := mm.buffer
		var stride := 12 + (4 if mm.use_colors else 0) + (4 if mm.use_custom_data else 0)
		var count := mm.instance_count if mm.visible_instance_count < 0 else mm.visible_instance_count
		for i in range(mini(count, buf.size() / stride)):
			var o := i * stride
			var t := Transform3D(Vector3(buf[o], buf[o + 4], buf[o + 8]), Vector3(buf[o + 1], buf[o + 5], buf[o + 9]),
					Vector3(buf[o + 2], buf[o + 6], buf[o + 10]), Vector3(buf[o + 3], buf[o + 7], buf[o + 11]))
			var gx := mmi.global_transform * t
			if _lap_distance(gx.origin) > reach + 15.0:
				continue
			_test_mesh(mm.mesh, gx, str(mmi.get_path()), found)
	for c in n.get_children(true):
		_walk(c, found)


var _mesh_pts := {}   # Mesh -> PackedVector3Array of points over its triangles, 0.5m apart


func _points(mesh: Mesh) -> PackedVector3Array:
	if _mesh_pts.has(mesh):
		return _mesh_pts[mesh]
	var out := PackedVector3Array()
	var seen := {}
	for si in range(mesh.get_surface_count()):
		var arr := mesh.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := idx.size() / 3 if not idx.is_empty() else v.size() / 3
		for t in range(count):
			var a: Vector3 = v[idx[t * 3]] if not idx.is_empty() else v[t * 3]
			var b: Vector3 = v[idx[t * 3 + 1]] if not idx.is_empty() else v[t * 3 + 1]
			var c: Vector3 = v[idx[t * 3 + 2]] if not idx.is_empty() else v[t * 3 + 2]
			var e := maxf(a.distance_to(b), maxf(b.distance_to(c), c.distance_to(a)))
			var n := clampi(ceili(e / 0.5), 1, 60)
			for i in range(n + 1):
				for j in range(n + 1 - i):
					var p := a + (b - a) * (float(i) / n) + (c - a) * (float(j) / n)
					var key := Vector3i(floori(p.x / 0.5), floori(p.y / 0.5), floori(p.z / 0.5))
					if not seen.has(key):
						seen[key] = true
						out.append(p)
	_mesh_pts[mesh] = out
	return out


func _test_mesh(mesh: Mesh, xf: Transform3D, key: String, found: Dictionary) -> void:
	var cells := {}
	for q in _points(mesh):
		var p := xf * q
		var k := Vector2i(floori(p.x), floori(p.z))
		if cells.has(k):
			continue
		if _lap_distance(p) > reach:
			continue
		var g := _ground_at(p)
		if p.y < g + 0.4 or p.y > g + 1.4:
			continue
		cells[k] = Vector3(k.x + 0.5, g + 0.9, k.y + 0.5)
	var open := 0
	var first := Vector3.ZERO
	var sphere := SphereShape3D.new()
	sphere.radius = 0.6
	for k in cells:
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = sphere
		q.transform = Transform3D(Basis(), cells[k])
		var hits := _space.intersect_shape(q, 8)
		var solid := false
		for h in hits:
			var col: Object = h.collider
			var nm := str((col as Node).name) if col is Node else ""
			var ground := false
			for gb in GROUND_BODIES:
				if gb in nm:
					ground = true
			if not ground:
				solid = true
				break
		if not solid:
			open += 1
			first = cells[k]
	if open > 0:
		if not found.has(key):
			found[key] = []
		found[key].append([first.snapped(Vector3.ONE * 0.1), _lap_distance(first), open])


## The ground or road under `p`, looking past anything else in the way.
func _ground_at(p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2.0, p - Vector3.UP * 30.0)
	var exclude: Array[RID] = []
	for i in 6:
		q.exclude = exclude
		var h := _space.intersect_ray(q)
		if h.is_empty():
			return p.y - 1.0
		var nm := str((h.collider as Node).name) if h.collider is Node else ""
		for gb in GROUND_BODIES:
			if gb in nm:
				return (h.position as Vector3).y
		exclude.append(h.rid)
	return p.y - 1.0


func _lap_distance(c: Vector3) -> float:
	var best := INF
	var k := Vector2i(floori(c.x / 20.0), floori(c.z / 20.0))
	var r := ceili(reach / 20.0) + 1
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var pts = _lap_cells.get(k + Vector2i(dx, dz))
			if pts == null:
				continue
			for p in pts:
				best = minf(best, p.distance_squared_to(Vector2(c.x, c.z)))
	return sqrt(best)
