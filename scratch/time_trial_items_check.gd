extends Node

# Time trial: no item boxes anywhere (spawned or placed in the level), both item slots holding a boost
# at the green light, and refilled with two at each new lap. Runs a spectator race switched to the
# time-trial mode. Headless:
#   Godot --headless --path . res://scratch/time_trial_items_check.tscn -- [res://levels/X.tscn]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var level_path := args[0] if not args.is_empty() else "res://levels/PinecrestRidgeLevel.tscn"
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	NetworkManager.current_game_mode = NetworkManager.GameMode.SINGLE_PLAYER_TIME_TRIAL
	var level: Node = load(level_path).instantiate()
	add_child(level)
	while level.race_state != level.RaceState.RACING or level._race_go_msec == 0:
		await get_tree().process_frame
	# Straight away: the spectator race's carts are bots, which use a boost as soon as they like.
	var cart = get_tree().get_nodes_in_group("player_carts")[0]
	print("boxes: %d (want 0)" % get_tree().get_nodes_in_group("item_boxes").size())
	print("at GO: slots %d, %d (want 1, 1: boosts)" % [cart.current_item, cart.current_item_2])
	cart.current_item = 0
	cart.current_item_2 = 0
	var id := str(cart.name).to_int()
	level.player_stats[id]["laps"] = 1
	level._lap_completed(id)
	print("after a lap: slots %d, %d (want 1, 1)" % [cart.current_item, cart.current_item_2])
	get_tree().quit()
