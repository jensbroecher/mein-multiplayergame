extends Node

# Checks that a car's steered parts (CarSteerFollower.gd: the Tuk-Tuk's fork and handlebars) turn with its front
# wheels in a real race: races bots (spectator, headless) on a level with the cars given, and for every cart whose
# model has steered parts prints where its two front wheel pivots stand (the Tuk-Tuk's share one hub), and, over the
# race, how far the pivots turned and the largest difference between each part's turn and the pivot's times its gain.
#   Godot --headless --path . res://scratch/steer_follow_probe.tscn -- [level=res://levels/LakesideLevel.tscn]
#       [cars=28,28,20,23,25,26] [seconds=60] [speed=2]

var seconds := 60.0
var speed := 2.0


func _ready() -> void:
	var level_path := "res://levels/LakesideLevel.tscn"
	var cars := PackedStringArray(["28", "28", "20", "23", "25", "26"])
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="):
			level_path = a.substr(6)
		elif a.begins_with("cars="):
			cars = a.substr(5).split(",")
		elif a.begins_with("seconds="):
			seconds = float(a.substr(8))
		elif a.begins_with("speed="):
			speed = float(a.substr(6))
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	for i in mini(cars.size(), 6):
		NetworkManager.players[100 + i]["car_index"] = int(cars[i])
	var level: Node = load(level_path).instantiate()
	add_child(level)
	Engine.time_scale = speed
	var carts: Array = []
	var stats := {}
	var t := 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if carts.is_empty():
			carts = get_tree().get_nodes_in_group("player_carts")
			continue
		for c in carts:
			if not is_instance_valid(c):
				continue
			var pivot: Node3D = c.get_node_or_null("Visuals/WheelPivotFR")
			if pivot == null:
				continue
			var parts: Array = []
			for n in c.find_children("*", "MeshInstance3D", true, false):
				if n.get_script() == preload("res://CarSteerFollower.gd"):
					parts.append(n)
			if parts.is_empty():
				continue
			if not stats.has(c):
				var fl: Node3D = c.get_node_or_null("Visuals/WheelPivotFL")
				print("%s: front pivots FL %s FR %s (apart %.4fm)" % [c.name, fl.position, pivot.position,
						fl.position.distance_to(pivot.position)])
				stats[c] = {"max_turn": 0.0, "max_err": 0.0, "frames": 0, "parts": parts.size()}
			var s: Dictionary = stats[c]
			var a: float = pivot.rotation.y
			s["max_turn"] = maxf(s["max_turn"], absf(a))
			s["frames"] += 1
			for p in parts:
				var rest: Basis = p.get("_rest")
				var turned: Basis = rest.inverse() * p.transform.basis
				var got: float = turned.get_euler().y
				var want: float = clampf(a * float(p.get("gain")), -float(p.get("limit")), float(p.get("limit")))
				s["max_err"] = maxf(s["max_err"], absf(got - want))
	for c in stats:
		var s: Dictionary = stats[c]
		print("STEER %s: %d steered parts, %d frames, pivot turned up to %.2f rad, largest part error %.4f rad" % [c.name,
				s["parts"], s["frames"], s["max_turn"], s["max_err"]])
	get_tree().quit()
