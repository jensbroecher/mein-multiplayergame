extends Node

# Checks that knockable poles stand still on their own and fall when a cart-sized body hits them.
#   Godot --headless --path . res://scratch/pole_knock_test.tscn -- res://levels/X.tscn

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var level: Node = load(args[0]).instantiate()
	level.set_script(null)
	add_child(level)
	var poles: Node = level.find_child("SnowPoles", true, false)
	for i in 300:
		await get_tree().physics_frame
	var bodies: Array = poles.get_children(true).filter(func(n): return n is RigidBody3D)
	var moved := 0
	for i in range(bodies.size()):
		if bodies[i].transform.origin.distance_to(poles.pole_transforms[i].origin) > 0.05:
			moved += 1
	print("poles: %d, moved by themselves after 5s: %d" % [bodies.size(), moved])
	for k in [0, 20, 40, 60, 80]:
		var pole: RigidBody3D = bodies[k]
		var base: Vector3 = pole.global_position
		var ball := RigidBody3D.new()
		ball.add_to_group("player_carts")
		ball.mass = 1200.0
		ball.continuous_cd = true
		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 1.0
		cs.shape = sph
		ball.add_child(cs)
		add_child(ball)
		var dir := Vector3(1, 0, 0.3).normalized()
		ball.global_position = base - dir * 5.0 + Vector3.UP * 0.3
		ball.linear_velocity = dir * 30.0
		var v_before := 30.0
		for f in 60:
			await get_tree().physics_frame
		var tilt: float = rad_to_deg(pole.global_transform.basis.y.angle_to(Vector3.UP))
		print("pole %d: tilt %.0f deg, moved %.1fm, ball speed %.1f -> %.1f" % [k, tilt, pole.global_position.distance_to(base), v_before, ball.linear_velocity.length()])
		ball.remove_from_group("player_carts")
		ball.queue_free()
	get_tree().quit()
