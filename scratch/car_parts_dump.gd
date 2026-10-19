extends SceneTree

# Lists the loose pieces (connected triangle groups) in each procedural car's Body mesh: how many,
# how big, where. These are what an explosion can tear off (CarDebris.gd). Headless:
#   Godot --headless --path . -s res://scratch/car_parts_dump.gd -- [Viper ...]

func _init() -> void:
	var names: PackedStringArray = OS.get_cmdline_user_args()
	if names.is_empty():
		names = ["Apex", "Centurion", "Interceptor", "Mudrunner", "Phantom", "Shadow", "Strikeforce", "Viper"]
	for car in names:
		var scene: Node = load("res://generated/cars/%s.tscn" % car).instantiate()
		var mi := scene.find_child("Body", true, false) as MeshInstance3D
		var mesh := mi.mesh as ArrayMesh
		print("== %s: %d surfaces, aabb %s" % [car, mesh.get_surface_count(), mesh.get_aabb()])
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var t0 := Time.get_ticks_usec()
			var comps := _components(verts, idx)
			var ms := (Time.get_ticks_usec() - t0) / 1000.0
			comps.sort_custom(func(a, b): return a["tris"] > b["tris"])
			print("  surface %d: %d verts, %d tris, %d pieces (found in %.1f ms)" % [s, verts.size(), idx.size() / 3, comps.size(), ms])
			var shown := 0
			for c in comps:
				if shown < 14:
					var b: AABB = c["aabb"]
					print("    %5d tris  size %.2f x %.2f x %.2f  at %s" % [c["tris"], b.size.x, b.size.y, b.size.z, b.get_center().snapped(Vector3.ONE * 0.01)])
				shown += 1
			var small := 0
			for c in comps:
				if c["tris"] < 40:
					small += 1
			print("    ... %d pieces under 40 tris" % small)
		scene.free()
	quit()


## Pieces by shared vertex index: union-find over the triangles.
func _components(verts: PackedVector3Array, idx: PackedInt32Array) -> Array:
	var parent := PackedInt32Array()
	parent.resize(verts.size())
	for i in verts.size():
		parent[i] = i
	for t in range(0, idx.size(), 3):
		_union(parent, idx[t], idx[t + 1])
		_union(parent, idx[t], idx[t + 2])
	var by_root := {}
	for t in range(0, idx.size(), 3):
		var r := _find(parent, idx[t])
		if not by_root.has(r):
			by_root[r] = {"tris": 0, "aabb": AABB(verts[idx[t]], Vector3.ZERO)}
		var c: Dictionary = by_root[r]
		c["tris"] += 1
		var a: AABB = c["aabb"]
		for k in 3:
			a = a.expand(verts[idx[t + k]])
		c["aabb"] = a
	return by_root.values()


func _find(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


func _union(parent: PackedInt32Array, a: int, b: int) -> void:
	var ra := _find(parent, a)
	var rb := _find(parent, b)
	if ra != rb:
		parent[ra] = rb
