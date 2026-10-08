extends Node

# Fires a cart at trees on a level and reports how close it got to each trunk and how fast it was
# still going, to check the trees are solid.
#   Godot --headless --path . res://scratch/tree_hit_test.tscn -- res://levels/X.tscn [count=5]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var count := 5
	for a in args:
		if a.begins_with("count="):
			count = int(a.substr(6))
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	var level: Node = load(args[0]).instantiate()
	add_child(level)
	var carts: Array = []
	while carts.size() < 6:
		await get_tree().physics_frame
		carts = get_tree().get_nodes_in_group("player_carts")
	for i in 600:
		await get_tree().physics_frame
	var cart: RigidBody3D = carts[0]
	var shapes: Array = []
	for body in level.find_children("TreeTrunks_*", "StaticBody3D", true, false):
		for c in body.get_children():
			shapes.append(c)
	print("tree colliders: ", shapes.size())
	var space := cart.get_world_3d().direct_space_state
	var tested := 0
	var idx := 0
	while tested < count and idx < shapes.size():
		var col: CollisionShape3D = shapes[idx]
		idx += 37
		var r: float = (col.shape as CylinderShape3D).radius
		var trunk: Vector3 = col.global_position
		var base := Vector3(trunk.x, trunk.y - (col.shape as CylinderShape3D).height * 0.5 + 0.5, trunk.z)
		# Approach over open ground: a run-up spot 20m away whose line to the tree is clear.
		var start := Vector3.ZERO
		var ok := false
		for k in 12:
			var dir := Vector3(cos(k * TAU / 12.0), 0, sin(k * TAU / 12.0))
			var s: Vector3 = base + dir * 20.0
			var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(s + Vector3.UP * 30, s + Vector3.DOWN * 30))
			if down.is_empty():
				continue
			s.y = down.position.y + 1.0
			var line := space.intersect_ray(PhysicsRayQueryParameters3D.create(s, base + Vector3.UP * 1.0, 1, [cart.get_rid()]))
			if not line.is_empty() and line.collider is StaticBody3D and str(line.collider.name).begins_with("TreeTrunks"):
				start = s
				ok = true
				break
		if not ok:
			continue
		tested += 1
		var toward: Vector3 = (base - start)
		toward.y = 0.0
		toward = toward.normalized()
		# A bare sphere with the cart's collision radius and mask, so the test measures the tree
		# colliders and not the cart's driving logic.
		var ball := RigidBody3D.new()
		ball.collision_mask = cart.collision_mask
		ball.continuous_cd = true
		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = (cart.get_node("CollisionShape3D").shape as SphereShape3D).radius
		cs.shape = sph
		ball.add_child(cs)
		add_child(ball)
		ball.global_position = start + Vector3.UP * 0.3
		ball.linear_velocity = toward * 25.0
		var closest := 1e9
		for f in 120:
			await get_tree().physics_frame
			closest = minf(closest, Vector2(ball.global_position.x - base.x, ball.global_position.z - base.z).length())
		var beyond: float = (ball.global_position - base).dot(toward)
		print("TREE r=%.2f closest=%.2f (contact at %.2f) %s" % [r, closest, r + sph.radius, "PASSED THROUGH" if beyond > r + 1.0 else "blocked"])
		ball.queue_free()
	get_tree().quit()
