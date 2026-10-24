extends Node

# Checks what the item boxes hold through a race's start: every box a boost before and during the
# boost-only start (ItemBox.START_BOOST_ONLY_SECONDS after the green light), a mix afterwards, and that a
# pickup gives the box's own item (or a boost, to the racer in last place). Headless:
#   Godot --headless --path . res://scratch/item_box_roll_check.tscn -- [res://levels/X.tscn]

const ItemSymbols = preload("res://ItemSymbols.gd")

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var level_path := args[0] if not args.is_empty() else "res://levels/LakesideLevel.tscn"
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	var level: Node = load(level_path).instantiate()
	add_child(level)
	while level.race_state != level.RaceState.RACING or level._race_go_msec == 0:
		await get_tree().process_frame
	_report("at the green light")
	await get_tree().create_timer(5.0).timeout
	_report("5s in")
	await get_tree().create_timer(6.0).timeout
	_report("11s in")
	# Pickups from boxes showing something other than a boost: the leader gets what was shown, last
	# place a boost.
	var boxes := get_tree().get_nodes_in_group("item_boxes").filter(func(b): return b.is_active and b.item != 1)
	var carts := get_tree().get_nodes_in_group("player_carts")
	for want_last in [false, true]:
		var cart = carts.filter(func(c): return (int(level.player_stats[str(c.name).to_int()]["pos"]) == carts.size()) == want_last)[0]
		var box = boxes.pop_back()
		cart.current_item = 0
		cart.current_item_2 = 0
		var shown: int = box.item
		box._server_process_pickup(cart)
		print("pickup: box showed %s, racer in place %d got %s" % [ItemSymbols.NAMES[shown - 1],
				level.player_stats[str(cart.name).to_int()]["pos"], ItemSymbols.NAMES[cart.current_item - 1]])
	get_tree().quit()


func _report(when: String) -> void:
	var counts := {}
	for b in get_tree().get_nodes_in_group("item_boxes"):
		var n: String = ItemSymbols.NAMES[b.item - 1]
		counts[n] = int(counts.get(n, 0)) + 1
	print("%s: %s" % [when, str(counts)])
