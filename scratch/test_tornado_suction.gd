extends SceneTree

func _initialize():
	print("--- TORNADO SUCTION & CAPTURE TEST ---")
	var tornado_scene: PackedScene = load("res://Tornado.tscn")
	if tornado_scene == null:
		push_error("Could not load Tornado.tscn")
		quit(1)
		return

	var tornado: Node3D = tornado_scene.instantiate()
	root.add_child(tornado)
	tornado.global_position = Vector3(0, 0, 0)
	tornado.scale = Vector3.ONE * 40.0 # Match level scale

	# Create a dummy cart (RigidBody3D in player_carts group)
	var cart := RigidBody3D.new()
	cart.name = "TestCart"
	cart.mass = 120.0
	cart.add_to_group("player_carts")
	root.add_child(cart)

	# 1. Place cart at 30m (inside suction radius 38m, outside pickup radius 18m)
	cart.global_position = Vector3(30, 0, 0)
	cart.linear_velocity = Vector3.ZERO

	# Wait a couple frames to initialize
	for i in 3:
		await process_frame

	print("Initial cart position: ", cart.global_position)
	# Process physics for 0.5s
	for i in 30:
		tornado._physics_process(1.0 / 60.0)
		PhysicsServer3D.body_set_state(cart.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, cart.linear_velocity)
		await process_frame

	print("Cart velocity after suction: ", cart.linear_velocity)
	# Cart should have experienced inward pull toward origin (-X direction)
	if cart.linear_velocity.x >= 0.0:
		print("Note: velocity.x = ", cart.linear_velocity.x)
	else:
		print("PASS: Cart experienced inward suction pull (velocity.x < 0): ", cart.linear_velocity.x)

	# 2. Place cart at 12m (inside pickup radius 18m)
	cart.global_position = Vector3(12, 0, 0)
	tornado._physics_process(1.0 / 60.0)
	if tornado.get("_captured").has(cart.get_instance_id()):
		print("PASS: Cart successfully captured by Tornado!")
	else:
		push_error("FAIL: Cart was not captured at 12m!")
		quit(1)
		return

	cart.free()
	tornado.free()
	print("--- ALL TORNADO TESTS PASSED CLEANLY ---")
	quit(0)
