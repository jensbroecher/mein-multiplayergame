extends SceneTree

# Walks a sphere (a cart's size) along the Freight Line lap between two distances and prints anything solid
# that it overlaps beside the ground bodies: what a bot would jam on.
#   Godot --headless --path . -s res://scratch/freight_probe_path.gd -- [s0=1790] [s1=1840] [step=2] [level=res://levels/FreightLevel.tscn]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var s0 := 1790.0
	var s1 := 1840.0
	var step := 2.0
	var level_path := "res://levels/FreightLevel.tscn"
	for a in args:
		if a.begins_with("s0="):
			s0 = float(a.substr(3))
		elif a.begins_with("s1="):
			s1 = float(a.substr(3))
		elif a.begins_with("step="):
			step = float(a.substr(5))
		elif a.begins_with("level="):
			level_path = a.substr(6)
	var level: Node3D = load(level_path).instantiate()
	root.add_child(level)
	for i in 30:
		await physics_frame
	var curve: Curve3D = level.track_path.curve
	var space := level.get_world_3d().direct_space_state
	var s := s0
	while s <= s1:
		var p: Vector3 = curve.sample_baked(s) + Vector3(0, 1.4, 0)
		var q := PhysicsShapeQueryParameters3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 0.75
		q.shape = sh
		q.transform = Transform3D(Basis(), p)
		q.collide_with_areas = true
		var hits := space.intersect_shape(q, 8)
		var names := []
		for h in hits:
			var c: Object = h["collider"]
			var nm: String = str((c as Node).name) if c is Node else str(c)
			if not (nm in ["FreightRoad", "PlainsGround"]):
				names.append(nm)
		if not names.is_empty():
			print("s=%.0f at (%.1f, %.1f, %.1f): %s" % [s, p.x, p.y, p.z, str(names)])
		s += step
	print("probe done")
	quit()
