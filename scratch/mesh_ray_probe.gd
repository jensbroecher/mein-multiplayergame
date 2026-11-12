extends SceneTree
## Casts rays down onto a mesh resource and prints every hit, top first: where a part's surface is, to seat things on it.
##   godot --headless --path . -s res://scratch/mesh_ray_probe.gd -- <mesh.res> x,z ... [from=2.0]
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var mesh: Mesh = load(args[0])
	var faces := mesh.get_faces()
	var from := 2.0
	for a in args.slice(1):
		if a.begins_with("from="):
			from = float(a.substr(5))
	for a in args.slice(1):
		if a.begins_with("from="):
			continue
		var p := a.split(",")
		var o := Vector3(float(p[0]), from, float(p[1]))
		var ys: Array = []
		for i in range(0, faces.size(), 3):
			var h = Geometry3D.ray_intersects_triangle(o, Vector3.DOWN, faces[i], faces[i + 1], faces[i + 2])
			if h != null:
				ys.append(snappedf(h.y, 0.001))
		ys.sort()
		ys.reverse()
		print(a, ": ", ys)
	quit()
