extends Node

# Checks a level's starting grid markings (SpawnIndicator.gd) against the ground under them: for each slot, at the
# quad's middle and corners, the gap between the quad and the surface a ray down finds (carts looked past), now and as
# it was placed before settling (the spawn point plus 5cm, flat). Spectator race, headless:
#   Godot --headless --path . res://scratch/grid_ground_probe.tscn -- <level.tscn>

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	var level: Node3D = load(args[0]).instantiate()
	add_child(level)
	await level.wait_for_collisions()
	for i in 40:
		await get_tree().physics_frame
	var space := level.get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	for c in get_tree().get_nodes_in_group("player_carts"):
		exclude.append((c as CollisionObject3D).get_rid())
	var worst_now := 0.0
	var worst_before := 0.0
	var count := 0
	var stack: Array = [level]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n.get_script() == null or not str(n.get_script().resource_path).ends_with("SpawnIndicator.gd"):
			continue
		count += 1
		var mesh: Node3D = n.get_node("MeshInstance3D")
		var now_xf: Transform3D = mesh.global_transform
		var before_xf := Transform3D(Basis(Vector3.UP, (n.get_parent() as Node3D).global_transform.basis.get_euler().y),
				(n.get_parent() as Node3D).global_position + Vector3.UP * 0.05)
		var g_now := 0.0
		var g_before := 0.0
		for o in [Vector3.ZERO, Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]:
			for k in 2:
				var p: Vector3 = (now_xf if k == 0 else before_xf) * o
				var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p - Vector3.UP * 6.0, 1)
				q.exclude = exclude
				var h := space.intersect_ray(q)
				if h.is_empty():
					continue
				var gap: float = p.y - (h["position"] as Vector3).y
				if k == 0:
					g_now = maxf(g_now, absf(gap))
				else:
					g_before = maxf(g_before, absf(gap))
		worst_now = maxf(worst_now, g_now)
		worst_before = maxf(worst_before, g_before)
	print("GRID %s: %d slots, worst gap to the ground before %.2fm, now %.2fm" % [args[0].get_file(), count, worst_before, worst_now])
	get_tree().quit()
