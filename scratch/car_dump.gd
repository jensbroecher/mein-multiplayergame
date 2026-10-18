extends SceneTree

# Dumps an imported car model's triangles in the cart frame (PlayerCart's placement: x2, turned by
# model_y_rotation), for measuring it before a procedural rebuild. Writes <out>/parts.txt (each
# MeshInstance3D: name, triangle count, AABB) and <out>/tris.bin (float32 rows: part index, then
# the triangle's three vertices). Run headless:
#   Godot --headless --path . -s res://scratch/car_dump.gd -- <scene.tscn> <out_dir> [yaw=180]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path: String = args[0]
	var out: String = args[1]
	var yaw := PI
	for a in args.slice(2):
		if a.begins_with("yaw="):
			yaw = deg_to_rad(float(a.substr(4)))
	var car: Node3D = (load(scene_path) as PackedScene).instantiate()
	root.add_child(car)
	car.transform = Transform3D(Basis(Vector3.UP, yaw) * 2.0, Vector3.ZERO)
	var meshes: Array = car.find_children("*", "MeshInstance3D", true, false)
	var info := FileAccess.open(out + "/parts.txt", FileAccess.WRITE)
	var bin := FileAccess.open(out + "/tris.bin", FileAccess.WRITE)
	for idx in meshes.size():
		var mi: MeshInstance3D = meshes[idx]
		# Not in a running tree yet (_init), so global_transform isn't available: walk up by hand.
		var xf: Transform3D = mi.transform
		var n: Node = mi.get_parent()
		while n != root:
			if n is Node3D:
				xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var tris := 0
		var box := AABB()
		var first := true
		for s in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ind: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			if ind.is_empty():
				ind = PackedInt32Array(range(v.size()))
			for k in range(0, ind.size(), 3):
				bin.store_float(idx)
				for m in 3:
					var p: Vector3 = xf * v[ind[k + m]]
					bin.store_float(p.x)
					bin.store_float(p.y)
					bin.store_float(p.z)
					if first:
						box = AABB(p, Vector3.ZERO)
						first = false
					else:
						box = box.expand(p)
				tris += 1
		info.store_line("%d %s tris=%d min=(%.3f, %.3f, %.3f) max=(%.3f, %.3f, %.3f)" % [idx, mi.name, tris,
				box.position.x, box.position.y, box.position.z, box.end.x, box.end.y, box.end.z])
	info.close()
	bin.close()
	print("dumped ", meshes.size(), " meshes")
	quit()
