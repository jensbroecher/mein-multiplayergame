extends Node

# Drops one cart (a bot, the others moved away) at each spot in turn on any level and reports what the water code makes
# of it: the stage's water level, whether the spot counts as over water, whether the cart went under and whether it was
# respawned (drowned) within `seconds`. For bounded ponds (Mina del Viento's sump) and to check dry ground stays dry.
#   Godot --headless --path . res://scratch/pond_drop_test.tscn -- <level.tscn> x,z [x,z ...] [seconds=6]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var seconds := 6.0
	var spots: Array = []
	for a in args.slice(1):
		if a.begins_with("seconds="):
			seconds = float(a.substr(8))
		elif a.count(",") == 1:
			var v := a.split_floats(",")
			spots.append(Vector2(v[0], v[1]))
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	var level: Node = load(args[0]).instantiate()
	add_child(level)
	while level.race_state != level.RaceState.RACING:
		await get_tree().physics_frame
	for i in 120:
		await get_tree().physics_frame
	var carts: Array = get_tree().get_nodes_in_group("player_carts")
	var cart: RigidBody3D = carts[0]
	for c in carts:
		if c != cart:
			c.global_position += Vector3(0, 0, 4000)
	var space := (level as Node3D).get_world_3d().direct_space_state
	for sp in spots:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(sp.x, 300, sp.y), Vector3(sp.x, -300, sp.y)))
		var gy: float = hit.position.y if hit else 0.0
		var xf := Transform3D(Basis(), Vector3(sp.x, gy + 2.0, sp.y))
		PhysicsServer3D.body_set_state(cart.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, xf)
		cart.global_transform = xf
		cart.linear_velocity = Vector3.ZERO
		# Held where it lands (a bot would drive off): drowning doesn't need it to move.
		cart.set("can_move", false)
		var went_under := false
		var respawned := false
		var t := 0.0
		while t < seconds:
			await get_tree().physics_frame
			t += get_physics_process_delta_time()
			if cart.get("is_underwater"):
				went_under = true
			if Vector2(cart.global_position.x - sp.x, cart.global_position.z - sp.y).length() > 30.0:
				respawned = true
				break
		print("DROP (%.0f, %.0f) ground %.2f water_y %.2f over_water %s under %s %s" % [sp.x, sp.y, gy, float(cart.get("water_surface_y")),
				str(cart.call("_is_over_water_volume")) if not respawned else "-", str(went_under), "DROWNED/RESPAWNED" if respawned else "stayed"])
	get_tree().quit()
