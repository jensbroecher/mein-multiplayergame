extends SceneTree
## Writes a mesh resource's surfaces (vertices and indices) as JSON, for scratch/loose_parts.py.
##   godot --headless --path . -s res://scratch/mesh_dump.gd -- <mesh.res> <out.json>
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var mesh: ArrayMesh = load(args[0])
	var out: Array = []
	for s in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var flat := PackedFloat32Array()
		for p in v:
			flat.append_array([p.x, p.y, p.z])
		var idx = a[Mesh.ARRAY_INDEX]
		if idx == null:
			idx = PackedInt32Array(range(v.size()))
		out.append({"name": str(mesh.surface_get_material(s).resource_name if mesh.surface_get_material(s) else s),
				"v": Array(flat), "i": Array(idx)})
	var f := FileAccess.open(args[1], FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("surfaces ", out.size())
	quit()
