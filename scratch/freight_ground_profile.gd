extends Node

# Raycasts down onto Freight Line's collision along the lap and prints the surface's height and any step
# between neighbours bigger than `step` (a bump a cart can stall on). With `across=1` it also samples the
# road's width every metre (-8..8) and reports any point more than 0.25m off the centre's height. Headless:
#   Godot --headless --path . res://scratch/freight_ground_profile.tscn -- [s0=0] [s1=2900] [every=1] [step=0.12] [across=1]

func _ready() -> void:
	var s0 := 0.0
	var s1 := 2900.0
	var every := 1.0
	var step := 0.12
	var across := false
	for a in OS.get_cmdline_user_args():
		if a == "across=1":
			across = true
		if a.begins_with("s0="):
			s0 = float(a.substr(3))
		elif a.begins_with("s1="):
			s1 = float(a.substr(3))
		elif a.begins_with("every="):
			every = float(a.substr(6))
		elif a.begins_with("step="):
			step = float(a.substr(5))
	var level: Node3D = load("res://levels/FreightLevel.tscn").instantiate()
	add_child(level)
	for i in 30:
		await get_tree().physics_frame
	var curve: Curve3D = level.track_path.curve
	var space := level.get_world_3d().direct_space_state
	var prev_y := NAN
	var s := s0
	var steps := 0
	while s <= s1:
		var p: Vector3 = curve.sample_baked(s)
		var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 20.0, p + Vector3.DOWN * 20.0)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			print("s=%.0f: NO GROUND under (%.1f, %.1f)" % [s, p.x, p.z])
		else:
			var y: float = hit.position.y
			if not is_nan(prev_y) and absf(y - prev_y) > step * every:
				steps += 1
				print("s=%.0f: step %.2f (%.2f -> %.2f) on %s at (%.1f, %.1f)" % [s, y - prev_y, prev_y, y, (hit.collider as Node).name, p.x, p.z])
			prev_y = y
			if across:
				var ahead: Vector3 = curve.sample_baked(s + 1.0) - p
				ahead.y = 0.0
				var right := Vector3(-ahead.z, 0.0, ahead.x).normalized()
				for lat in range(-8, 9):
					var pp: Vector3 = p + right * float(lat)
					var h2 := space.intersect_ray(PhysicsRayQueryParameters3D.create(pp + Vector3.UP * 20.0, pp + Vector3.DOWN * 20.0))
					if not h2.is_empty() and absf(h2.position.y - y) > 0.25:
						print("s=%.0f lat %d: %.2f off the centre (%.2f vs %.2f) on %s" % [s, lat, h2.position.y - y, h2.position.y, y, (h2.collider as Node).name])
		s += every
	print("profile done, %d steps" % steps)
	get_tree().quit()
