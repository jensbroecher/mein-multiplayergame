extends Node

# Starts a splitscreen (LOCAL_COOP VS) race headless, holds throttle for both players after the
# start and prints where both human carts and their splitscreen cameras are, to catch P2 spawning
# underground or stuck.
#   Godot --headless --path . res://scratch/coop_spawn_test.tscn -- res://levels/X.tscn [seconds=14] [gp]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var level_path: String = args[0] if args.size() > 0 else "res://levels/Level.tscn"
	var seconds := 14.0
	for a in args:
		if a.begins_with("seconds="):
			seconds = float(a.substr(8))
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.LOCAL_COOP
	NetworkManager.is_coop_gp = args.has("gp")
	NetworkManager.start_local_coop("P1", "P2")
	var level: Node = load(level_path).instantiate()
	add_child(level)
	var t := 0.0
	var next_report := 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if t > 7.0:
			Input.action_press("p1_throttle")
			Input.action_press("p2_throttle")
		if t >= next_report:
			next_report += 1.0
			for c in get_tree().get_nodes_in_group("player_carts"):
				if c.is_ai and t > 0.5:
					continue
				var cam: Camera3D = c.splitscreen_camera
				print("t=%.1f cart %s pos=%s vel=%.1f freeze=%s can_move=%s auth=%s prefix=%s cam=%s" % [
					t, c.name, c.global_position, c.linear_velocity.length(), c.freeze, c.can_move,
					c.has_physics_authority(), c.input_prefix, cam.global_position if cam else "UNLINKED"])
	get_tree().quit()
