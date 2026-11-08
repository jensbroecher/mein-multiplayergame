extends SceneTree

# Lists everything a vertical ray meets at each point on a level, top to bottom (not just the first hit), to find
# decks with ground close under them, gaps between surfaces and what stands where. Headless:
#   Godot --headless --path . -s res://scratch/ray_stack_probe.gd -- <level.tscn> x,z [x,z ...] [line=x0,z0,x1,z1,step]
# A `line=` adds points every `step` metres along it.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var level: Node3D = load(args[0]).instantiate()
	root.add_child(level)
	var pts: Array = []
	for a in args.slice(1):
		if a.begins_with("line="):
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
		var line := "%7.1f %7.1f :" % [p.x, p.y]
		var excl: Array[RID] = []
		var top := 200.0
		for k in 6:
			var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, top, p.y), Vector3(p.x, -200.0, p.y))
			q.exclude = excl
			q.hit_back_faces = false
			var hit := space.intersect_ray(q)
			if not hit:
				break
			line += "  %.2f %s" % [hit.position.y, str((hit.collider as Node).name)]
			excl.append(hit.rid)
			top = hit.position.y + 0.001
		print(line)
	quit()
