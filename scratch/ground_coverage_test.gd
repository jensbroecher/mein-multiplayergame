extends Node

# Casts a ray down every `step` metres over a level and reports where there is no ground collision
# (a car there falls through the world).
#   Godot --headless --path . res://scratch/ground_coverage_test.tscn -- res://levels/X.tscn [step=25] [x0,z0,x1,z1]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var step := 25.0
	var rect := Rect2(-700, -1350, 1450, 2300)
	for a in args:
		if a.begins_with("step="):
			step = float(a.substr(5))
		elif a.count(",") == 3:
			var v := a.split(",")
			rect = Rect2(float(v[0]), float(v[1]), float(v[2]) - float(v[0]), float(v[3]) - float(v[1]))
	var level: Node = load(args[0]).instantiate()
	level.set_script(null)
	add_child(level)
	for i in 3:
		await get_tree().physics_frame
	var space := get_viewport().world_3d.direct_space_state
	var misses := 0
	var total := 0
	var x := rect.position.x
	while x <= rect.end.x:
		var z := rect.position.y
		while z <= rect.end.y:
			total += 1
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 600, z), Vector3(x, -200, z)))
			if hit.is_empty():
				misses += 1
				if misses <= 10:
					print("NO GROUND at (%.0f, %.0f)" % [x, z])
			z += step
		x += step
	print("coverage: %d of %d points have ground (%d holes)" % [total - misses, total, misses])
	get_tree().quit()
