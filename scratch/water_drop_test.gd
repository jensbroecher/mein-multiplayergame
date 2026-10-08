extends Node

# Drops an AI cart into the water at given spots and reports whether it drowns.
#   Godot --headless --path . res://scratch/water_drop_test.tscn -- res://levels/X.tscn x,y,z ...

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
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
	var water := level.get_node("RiverWater")
	for a in args.slice(1):
		var p := a.split(",")
		var spot := Vector3(float(p[0]), float(p[1]), float(p[2]))
		cart.freeze = false
		var xf := Transform3D(Basis(), spot)
		PhysicsServer3D.body_set_state(cart.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, xf)
		PhysicsServer3D.body_set_state(cart.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
		cart.global_transform = xf
		var drowned := false
		var t := 0.0
		while t < 8.0:
			await get_tree().physics_frame
			t += get_physics_process_delta_time()
			if cart.is_drowned or cart.is_teleporting:
				drowned = true
				break
		print("DROP %s water_y=%.2f -> %s after %.1fs (cart y %.1f, surface_y var %.2f)" % [spot, water.surface_at(spot.x, spot.z), "DROWNED/RESPAWN" if drowned else "still there", t, cart.global_position.y, cart.water_surface_y])
		while cart.is_teleporting:
			await get_tree().physics_frame
		for i in 120:
			await get_tree().physics_frame
	get_tree().quit()
