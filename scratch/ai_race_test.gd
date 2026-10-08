extends Node

# Races 6 AI carts around a level headless and reports lap times, respawns (with where they
# happened) and how far each cart got.
#   Godot --headless --path . res://scratch/ai_race_test.tscn -- res://levels/X.tscn [seconds=300] [speed=4]

var seconds := 300.0
var speed := 4.0

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var level_path: String = args[0]
	for a in args:
		if a.begins_with("seconds="):
			seconds = float(a.substr(8))
		elif a.begins_with("speed="):
			speed = float(a.substr(6))
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	var level: Node = load(level_path).instantiate()
	add_child(level)
	Engine.time_scale = speed
	var track: Path3D = level.track_path
	var length: float = track.curve.get_baked_length()
	var carts: Array = []
	var was_tele := {}
	var last_pos := {}
	var respawns := {}
	var best_prog := {}
	var t := 0.0
	var next_report := 20.0
	while t < seconds:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if carts.is_empty():
			carts = get_tree().get_nodes_in_group("player_carts")
			for c in carts:
				was_tele[c] = false
				respawns[c] = []
				best_prog[c] = 0.0
		for c in carts:
			if not is_instance_valid(c):
				continue
			var tele: bool = c.is_teleporting
			if tele and not was_tele[c]:
				var p: Vector3 = last_pos.get(c, c.global_position)
				var off: float = track.curve.get_closest_offset(track.to_local(p))
				respawns[c].append("%.0fm(%s y%.0f)" % [off, "drown" if c.is_drowned else "fall", p.y])
			was_tele[c] = tele
			if not tele:
				last_pos[c] = c.global_position
		if t >= next_report:
			next_report += 20.0
			var line := "t=%3.0fs" % t
			for c in carts:
				var st: Dictionary = level.player_stats.get(c.name.to_int(), {})
				var off: float = track.curve.get_closest_offset(track.to_local(c.global_position))
				line += "  %s:L%d/%.0fm %.0fkmh" % [c.name, st.get("laps", 0), off, c.linear_velocity.length() * 3.6]
			print(line)
	for c in carts:
		var st: Dictionary = level.player_stats.get(c.name.to_int(), {})
		print("CART %s car=%d laps=%d finished=%s respawns=%d %s" % [c.name, c.car_index, st.get("laps", 0), st.get("finished", false), respawns[c].size(), respawns[c]])
	get_tree().quit()
