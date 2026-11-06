extends SceneTree

# Lists the triangles of a level's meshes that reach into a box, per node and surface (with the surface's material), to
# find which part of a merged prop stands where it shouldn't. Headless:
#   Godot --headless --path . -s res://scratch/mesh_tris_in_box.gd -- <level.tscn> <node name part> x0,y0,z0 x1,y1,z1 [max=20]
# A triangle counts when its middle or any corner lies in the box.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var level: Node3D = load(args[0]).instantiate()
	root.add_child(level)
	await process_frame
	var part: String = args[1]
	var a := args[2].split(",")
	var b := args[3].split(",")
	var box := AABB(Vector3(float(a[0]), float(a[1]), float(a[2])), Vector3.ZERO).expand(Vector3(float(b[0]), float(b[1]), float(b[2])))
	var max_n := 20
	for x in args.slice(4):
		if x.begins_with("max="):
			max_n = int(x.substr(4))
	for mi in level.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		var npath := str(level.get_path_to(m))
		if m.mesh == null or not (part in npath):
			continue
		var xf: Transform3D = m.global_transform
		for si in range(m.mesh.get_surface_count()):
			var arr: Array = m.mesh.surface_get_arrays(si)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var n: int = idx.size() if idx.size() > 0 else v.size()
			var mat: Material = m.mesh.surface_get_material(si)
			var shown := 0
			var count := 0
			var lo := Vector3(1e9, 1e9, 1e9)
			var hi := -lo
			var t := 0
			while t + 2 < n:
				var p0: Vector3 = xf * v[idx[t] if idx.size() > 0 else t]
				var p1: Vector3 = xf * v[idx[t + 1] if idx.size() > 0 else t + 1]
				var p2: Vector3 = xf * v[idx[t + 2] if idx.size() > 0 else t + 2]
				t += 3
				var mid: Vector3 = (p0 + p1 + p2) / 3.0
				if box.has_point(mid) or box.has_point(p0) or box.has_point(p1) or box.has_point(p2):
					count += 1
					for p in [p0, p1, p2]:
						lo = lo.min(p)
						hi = hi.max(p)
					if shown < max_n:
						print("  %s #%d: %s %s %s" % [npath, si, p0, p1, p2])
						shown += 1
			if count > 0:
				print("%s surface %d (%s): %d triangles, spanning %s .. %s" % [npath, si, mat.resource_path if mat else "none", count, lo, hi])
	quit()
