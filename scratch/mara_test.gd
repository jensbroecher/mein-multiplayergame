extends Node

# Mara Crossing: sends every AI cart down the Croc Jump line and reports, per attempt, the take-off
# speed at the lip and whether the cart made the far bank or drowned; also counts herd bumps.
#   Godot --headless --path . res://scratch/mara_test.tscn -- [seconds=200] [speed=4] [croc=1.0]

const LIP := Vector3(-31.5, 5.0, -437.0)

func _ready() -> void:
	var seconds := 200.0
	var speed := 4.0
	var croc := 1.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seconds="):
			seconds = float(a.substr(8))
		elif a.begins_with("speed="):
			speed = float(a.substr(6))
		elif a.begins_with("croc="):
			croc = float(a.substr(5))
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	var level: Node = load("res://levels/MaraCrossingLevel.tscn").instantiate()
	add_child(level)
	Engine.time_scale = speed
	var herd: Node = level.get_node("MigrationHerd")
	var carts: Array = []
	var near := {}
	var lip_speed := {}
	var made := 0
	var drowned := 0
	var t := 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if carts.is_empty():
			carts = get_tree().get_nodes_in_group("player_carts")
			for c in carts:
				near[c] = false
		for c in carts:
			if not is_instance_valid(c):
				continue
			c.ai_shortcut_chance = croc
			var p: Vector3 = c.global_position
			var d := Vector2(p.x - LIP.x, p.z - LIP.z).length()
			if d < 4.0 and not near[c]:
				near[c] = true
				lip_speed[c] = c.linear_velocity.length()
			if near[c] and c.is_drowned:
				drowned += 1
				print("DROWN %s took off at %.1f m/s" % [c.name, lip_speed[c]])
				near[c] = false
			elif near[c] and p.x < LIP.x - 32.0:
				made += 1
				print("MADE  %s took off at %.1f m/s" % [c.name, lip_speed[c]])
				near[c] = false
	print("croc jumps: %d made, %d drowned; herd bumps: %d" % [made, drowned, herd.bump_count])
	get_tree().quit()
