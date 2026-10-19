extends SceneTree
# Loads a level in inspection mode and checks the free camera. -- <level.tscn>
func _initialize() -> void:
	var nm = root.get_node("NetworkManager")
	nm.current_game_mode = nm.GameMode.SPECTATOR
	nm.inspect_mode = true
	nm.start_inspect()
	var level: Node3D = load(OS.get_cmdline_user_args()[0]).instantiate()
	root.add_child(level)
	await level.wait_for_collisions()
	for i in 30:
		await process_frame
	var cam = level.get_node_or_null("FreeFlyCamera")
	print("INSPECT cam=", cam, " pos=", cam.global_position if cam else null, " carts=", get_nodes_in_group("player_carts").size())
	cam.global_position += Vector3.UP
	await process_frame
	quit()
