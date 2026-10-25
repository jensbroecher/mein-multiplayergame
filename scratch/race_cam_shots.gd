extends Node

# Rides along with an AI cart in a spectator race through its own race camera (the cart made the local
# player's, as PlayerCart sets one up) and saves a frame every `every` seconds: the Top Down camera
# (mode=top) or the follower (mode=follow). Windowed:
#   Godot --path . --resolution 1600x900 res://scratch/race_cam_shots.tscn -- <out_dir>
#       [level=res://levels/LakesideLevel.tscn] [mode=top] [cart=0] [every=4] [count=6]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0]
	var level_path := "res://levels/LakesideLevel.tscn"
	var top := true
	var index := 0
	var every := 4.0
	var count := 6
	for a in args.slice(1):
		if a.begins_with("level="): level_path = a.substr(6)
		elif a.begins_with("mode="): top = a.substr(5) != "follow"
		elif a.begins_with("cart="): index = int(a.substr(5))
		elif a.begins_with("every="): every = float(a.substr(6))
		elif a.begins_with("count="): count = int(a.substr(6))
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	var level: Node = load(level_path).instantiate()
	add_child(level)
	var carts: Array = []
	while carts.size() <= index:
		await get_tree().physics_frame
		carts = get_tree().get_nodes_in_group("player_carts")
	var cart = carts[index]
	while not cart.can_move:
		await get_tree().physics_frame
	cart.is_local_player = true
	cart.is_isometric = top
	cart.camera_pivot.top_level = true
	cart.camera.make_current()
	var t := 0.0
	for k in range(count):
		while t < every * float(k + 1):
			await get_tree().physics_frame
			t += get_physics_process_delta_time()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/cam_%02d.png" % [out_dir, k])
		print("SHOT %d t=%.1f cart %s cam %s fov %.0f" % [k, t, cart.global_position, cart.camera.global_position, cart.camera.fov])
	get_tree().quit()
