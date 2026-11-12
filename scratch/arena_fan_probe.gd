extends Node
## Drives a bot over each launch fan (ArenaFan.gd) of an arena level, headless, and prints how high it went and where
## it came down: -- <level> [speed=12] [only=<fan name part>]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var level_path: String = args[0]
	var approach := 12.0
	var only := ""
	for a in args:
		if a.begins_with("speed="):
			approach = float(a.substr(6))
		elif a.begins_with("only="):
			only = a.substr(5)
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	NetworkManager.arena = {"kind": "ctf" if "Ctf" in level_path else "football", "teams": false}
	var level: Node = load(level_path).instantiate()
	add_child(level)
	while level.race_state != 1:
		await get_tree().physics_frame
	# Past the intro and the countdown: the carts can move.
	while not bool(level.get_node("Players/100").get("can_move")):
		await get_tree().physics_frame
	for i in 30:
		await get_tree().physics_frame
	var game: Node = level.get_node("ArenaGame")
	game.set_physics_process(false)
	var cart: RigidBody3D = level.get_node("Players/100")
	for fan in level.find_children("*", "Node3D", true, false):
		if fan.get_script() != load("res://ArenaFan.gd") or (only != "" and not only in str(fan.name)):
			continue
		var fwd: Vector3 = -fan.global_transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		cart.set("arena_target", Vector3.INF)
		cart.global_position = fan.global_position - fwd * 9.0 + Vector3(0, 1.0, 0)
		cart.global_transform.basis = Basis.looking_at(fwd, Vector3.UP)
		cart.linear_velocity = fwd * approach
		var top := -INF
		var launched := false
		var land := Vector3.ZERO
		var trace := ""
		for f in 300:
			await get_tree().physics_frame
			top = maxf(top, cart.global_position.y)
			if f < 40 and f % 4 == 0:
				var lp: Vector3 = fan.to_local(cart.global_position)
				trace += " [%.1f,%.1f,%.1f]" % [lp.x, lp.y, lp.z]
			if launched and trace.length() < 400:
				trace += " %.1f/%.1f/h%.1f" % [cart.global_position.y - fan.global_position.y, cart.linear_velocity.y, Vector2(cart.linear_velocity.x, cart.linear_velocity.z).length()]
			if cart.global_position.y > fan.global_position.y + 4.0:
				launched = true
			if launched and cart.get("is_on_ground"):
				land = cart.global_position
				break
		print("FAN %s at (%.0f,%.0f,%.0f): up %.1fm, landed (%.0f,%.1f,%.0f) %.1fm on, launched=%s\n   %s" % [fan.name, fan.global_position.x,
			fan.global_position.y, fan.global_position.z, top - fan.global_position.y, land.x, land.y, land.z,
			Vector2(land.x - fan.global_position.x, land.z - fan.global_position.z).length(), launched, trace])
	get_tree().quit()
