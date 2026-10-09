extends Node

# Drives a cart through the loose rubble round a Thin Ice hole on Northlight Caverns and reports how
# many chunks it scattered and what the hits did to the cart.
#   Godot --headless --path . res://scratch/ice_rubble_test.tscn

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	var level: Node = load("res://levels/NorthlightCavernsLevel.tscn").instantiate()
	add_child(level)
	var carts: Array = []
	while carts.size() < 6:
		await get_tree().physics_frame
		carts = get_tree().get_nodes_in_group("player_carts")
	for i in 600:
		await get_tree().physics_frame
	var rubble: MultiMeshInstance3D = level.find_child("HoleRubble", true, false)
	var xfs: Array = rubble.get("chunk_transforms")
	var water: Node = level.get_node("RiverWater")
	var cart: RigidBody3D = carts[0]
	# A chunk at the first hole, approached from outside the hole, tangent to the rim.
	var holes: PackedVector4Array = water.get("holes")
	var h: Vector4 = holes[0]
	var target: Vector3 = xfs[0].origin
	var radial := Vector2(target.x - h.x, target.z - h.y).normalized()
	var tangent := Vector3(-radial.y, 0.0, radial.x)
	var start: Vector3 = target - tangent * 12.0 + Vector3(radial.x, 0.0, radial.y) * 0.4 + Vector3.UP * 0.8
	print("ice under start: water %s" % water.surface_at(start.x, start.z))
	# A stand-in for a cart that only goes where it is pushed: the cart's own sphere and mass.
	var ram := RigidBody3D.new()
	ram.mass = 1200.0
	ram.continuous_cd = true
	# KnockableIce kicks chunks for anything in this group; only for the kicks, then it goes.
	ram.add_to_group("player_carts")
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.35
	cs.shape = sph
	ram.add_child(cs)
	add_child(ram)
	ram.global_position = start + Vector3.UP * 0.6
	ram.linear_velocity = tangent * 18.0
	var min_speed := 99.0
	var max_up := 0.0
	for i in 120:
		await get_tree().physics_frame
		min_speed = minf(min_speed, Vector2(ram.linear_velocity.x, ram.linear_velocity.z).length())
		max_up = maxf(max_up, ram.linear_velocity.y)
		if i % 10 == 0:
			var c0 := rubble.get_child(0, true) as RigidBody3D
			print("  t%d ram %s v %.1f  chunk0 %s frozen %s  d %.2f" % [i, ram.global_position, ram.linear_velocity.length(), c0.global_position, c0.freeze, ram.global_position.distance_to(c0.global_position)])
	var splashes := 0
	var moved := 0
	var kids := rubble.get_children(true)
	for i in range(kids.size()):
		var b := kids[i] as RigidBody3D
		if b and b.global_position.distance_to(xfs[int(b.name.split("_")[1])].origin) > 0.3:
			moved += 1
	print("RUBBLE: %d of %d chunks moved; cart min speed %.1f, max up %.2f m/s, frames in water %d, drowned %s" % [
		moved, xfs.size(), min_speed, max_up, splashes, cart.is_drowned or cart.is_teleporting])
	ram.queue_free()
	# Then straight into the hole.
	var drop := Vector3(h.x, 4.0, h.y)
	var xf := Transform3D(Basis(), drop)
	PhysicsServer3D.body_set_state(cart.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, xf)
	PhysicsServer3D.body_set_state(cart.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
	cart.global_transform = xf
	var t := 0.0
	while t < 8.0 and not (cart.is_drowned or cart.is_teleporting):
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	print("  cart at %s" % cart.global_position)
	print("HOLE: water %.2f, %s after %.1fs" % [water.surface_at(drop.x, drop.z), "DROWNED" if t < 8.0 else "not drowned", t])
	get_tree().quit()
