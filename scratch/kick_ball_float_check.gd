extends Node

# Loads a level in a spectator race and, after `seconds`, lists every KickBall: where it started, where
# it is, its height over the water (water_y) and whether it is asleep. Afloat balls should sit about
# float_share under the surface and have drifted shoreward, not sunk or flown off. Headless:
#   Godot --headless --path . res://scratch/kick_ball_float_check.tscn -- [level=res://levels/BloombayDunesLevel.tscn] [seconds=20]


func _ready() -> void:
	var level_path := "res://levels/BloombayDunesLevel.tscn"
	var seconds := 20.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="): level_path = a.substr(6)
		elif a.begins_with("seconds="): seconds = float(a.substr(8))
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	var level: Node3D = load(level_path).instantiate()
	add_child(level)
	await level.wait_for_collisions()
	var start := {}
	for b in get_tree().get_nodes_in_group("kick_balls"):
		start[b] = (b as Node3D).global_position
	var t := 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	for b in get_tree().get_nodes_in_group("kick_balls"):
		var p: Vector3 = (b as Node3D).global_position
		var w: float = b.get("water_y")
		print("%s: %s -> %s (moved %.1fm)%s, %s" % [b.name, start[b], p, p.distance_to(start[b]),
			"" if w < -999.0 else ", %.2fm over the water" % (p.y - w), "asleep" if b.sleeping else "moving %.1f m/s" % b.linear_velocity.length()])
	get_tree().quit()
