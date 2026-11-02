extends Node

var Level: Node
var cart: RigidBody3D
var cluster: MultiMeshInstance3D
var initial_rock_pos: Array[Vector3] = []
var initial_speed: float = 0.0
var min_speed: float = 999.0
var final_speed: float = 0.0
var rocks_moved: int = 0
var max_rock_displacement: float = 0.0

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	Level = load("res://levels/FreightLevel.tscn").instantiate()
	add_child(Level)

	for i in 10:
		await get_tree().physics_frame

	var clusters_parent = Level.get_node_or_null("Desert/RockClusters")
	if clusters_parent == null or clusters_parent.get_child_count() == 0:
		print("ERROR: No RockClusters found in Desert!")
		get_tree().quit(1)
		return

	# Pick the first rock cluster
	cluster = clusters_parent.get_child(0) as MultiMeshInstance3D
	print("Testing with cluster: ", cluster.name)
	var c_center: Vector3 = cluster.get("_cluster_center")
	print("Cluster center: ", c_center)

	var xfs: Array = cluster.get("rock_transforms")
	for xf in xfs:
		initial_rock_pos.append(xf.origin)
	print("Cluster rock count: %d" % initial_rock_pos.size())

	# Spawn a test cart (RigidBody3D in group player_carts)
	cart = RigidBody3D.new()
	cart.name = "TestCart"
	cart.mass = 1200.0
	cart.collision_layer = 1
	cart.collision_mask = 1
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 0.8, 3.2)
	col.shape = box
	cart.add_child(col)
	cart.add_to_group("player_carts")

	# Position cart 8m away from cluster center on ground, aiming towards cluster
	var approach_dir = Vector3(1.0, 0.0, 0.0) # from -X towards +X
	var cart_start = c_center - approach_dir * 8.0
	cart_start.y = c_center.y + 0.4
	cart.global_transform = Transform3D(Basis.looking_at(approach_dir, Vector3.UP), cart_start)

	Level.add_child(cart)

	for i in 3:
		await get_tree().physics_frame

	# Launch cart towards cluster at 22 m/s
	cart.linear_velocity = approach_dir * 22.0
	initial_speed = cart.linear_velocity.length()
	print("Cart launched at pos %s speed: %.2f m/s towards cluster" % [cart.global_position, initial_speed])

	# Simulate 120 physics frames (~2 seconds)
	for frame in range(120):
		await get_tree().physics_frame
		var cur_speed = cart.linear_velocity.length()
		min_speed = minf(min_speed, cur_speed)
		if frame % 20 == 0:
			print("Frame %d: cart_pos=%s speed=%.2f dist_to_center=%.2f" % [frame, cart.global_position, cur_speed, cart.global_position.distance_to(c_center)])

	final_speed = cart.linear_velocity.length()

	# Check rock movement
	var current_bodies: Array = cluster.get("_bodies")
	for i in range(current_bodies.size()):
		var b: RigidBody3D = current_bodies[i]
		var disp = b.global_position.distance_to(initial_rock_pos[i])
		max_rock_displacement = maxf(max_rock_displacement, disp)
		if disp > 0.4:
			rocks_moved += 1

	print("--- TEST RESULTS ---")
	print("Initial speed: %.2f m/s" % initial_speed)
	print("Minimum speed during cluster push: %.2f m/s" % min_speed)
	print("Final speed after cluster: %.2f m/s" % final_speed)
	var speed_reduction = (initial_speed - min_speed) / initial_speed * 100.0
	print("Speed reduction: %.1f%%" % speed_reduction)
	print("Rocks pushed aside (>0.4m displacement): %d / %d" % [rocks_moved, initial_rock_pos.size()])
	print("Max rock displacement: %.2f meters" % max_rock_displacement)

	var success = (speed_reduction >= 30.0) and (rocks_moved >= 1) and (max_rock_displacement >= 1.0)
	print("TEST SUCCESS: %s" % str(success))
	get_tree().quit(0 if success else 1)
