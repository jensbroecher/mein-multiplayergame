extends SceneTree

# Casts horizontal rays across a road to find its barriers' walls: for each start point, a ray along `dir` at height y
# (or a list), printing what it meets first and where. Headless:
#   Godot --headless --path . -s res://scratch/wall_ray_probe.gd -- <level.tscn> dir=x,z len=12 y=17.2 x,z [x,z ...]
#     [line=x0,z0,x1,z1,step]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var level: Node3D = load(args[0]).instantiate()
	root.add_child(level)
	var dir := Vector3(0, 0, 1)
	var length := 12.0
	var y := 1.0
	var pts: Array = []
	for a in args.slice(1):
		if a.begins_with("dir="):
			var v := a.substr(4).split_floats(",")
			dir = Vector3(v[0], 0, v[1]).normalized()
		elif a.begins_with("len="):
			length = float(a.substr(4))
		elif a.begins_with("y="):
			y = float(a.substr(2))
		elif a.begins_with("line="):
			var v := a.substr(5).split_floats(",")
			var p0 := Vector2(v[0], v[1])
			var p1 := Vector2(v[2], v[3])
			var n := maxi(1, int(p0.distance_to(p1) / v[4]))
			for k in range(n + 1):
				pts.append(p0.lerp(p1, float(k) / float(n)))
		else:
			var v := a.split_floats(",")
			pts.append(Vector2(v[0], v[1]))
	for i in 20:
		await physics_frame
	var space := level.get_world_3d().direct_space_state
	for p in pts:
		var from := Vector3(p.x, y, p.y)
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * length)
		var hit := space.intersect_ray(q)
		if hit:
			print("%7.1f %7.1f  hit %s at (%.2f, %.2f, %.2f) after %.2fm" % [p.x, p.y, str((hit.collider as Node).name),
					hit.position.x, hit.position.y, hit.position.z, from.distance_to(hit.position)])
		else:
			print("%7.1f %7.1f  nothing in %.1fm" % [p.x, p.y, length])
	quit()
