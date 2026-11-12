extends Node
## Plays an arena match with six bots, headless, and prints how it goes: the clock, the scores, the balls or the flag
## and bases every `every` game seconds, each event, the respawns (with where), and the result.
##   Godot --headless --path . res://scratch/arena_match_test.tscn -- <football|ctf> [teams=1] [seconds=120] [speed=3]
##       [every=10] [level=res://levels/...]

var kind := "football"
var teams := false
var seconds := 120.0
var speed := 3.0
var every := 10.0


func _ready() -> void:
	var level_path := ""
	for a in OS.get_cmdline_user_args():
		if a == "football" or a == "ctf":
			kind = a
		elif a == "teams=1":
			teams = true
		elif a.begins_with("seconds="):
			seconds = float(a.substr(8))
		elif a.begins_with("speed="):
			speed = float(a.substr(6))
		elif a.begins_with("every="):
			every = float(a.substr(6))
		elif a.begins_with("level="):
			level_path = a.substr(6)
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	NetworkManager.arena = {"kind": kind, "teams": teams}
	if level_path == "":
		level_path = NetworkManager.arena_level()
	var level: Node = load(level_path).instantiate()
	add_child(level)
	var game: Node = level.get_node("ArenaGame")
	game.match_seconds = seconds
	Engine.time_scale = speed
	var was_tele := {}
	var respawns := {}
	var t := 0.0
	var next := 0.0
	var started := false
	var start_t := 0.0
	while level.race_state != 2:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		if level.race_state == 1 and not started:
			started = true
			start_t = t
			print("GO at %.1fs" % t)
		for c in get_tree().get_nodes_in_group("player_carts"):
			var tele: bool = c.get("is_teleporting")
			if tele and not was_tele.get(c.name, false):
				respawns[c.name] = respawns.get(c.name, []) + ["%.0f,%.0f,%.0f" % [c.global_position.x, c.global_position.y, c.global_position.z]]
			was_tele[c.name] = tele
		if started and t - start_t >= next:
			next += every
			var line := "t=%3.0f left=%3.0f score=%s" % [t - start_t, game._time_left, str(game._score)]
			if kind == "football":
				for i in game._balls.size():
					if game._ball_active[i]:
						var p: Vector3 = game._balls[i].global_position
						line += " ball%d=(%.0f,%.0f,%.0f)" % [i, p.x, p.y, p.z]
			else:
				line += " flag=%d carrier=%d at=(%.0f,%.0f,%.0f) bases=%s" % [game._flag_state, game._carrier, game._flag_pos.x, game._flag_pos.y, game._flag_pos.z, str(game._base_owner)]
			var speeds := ""
			for c in get_tree().get_nodes_in_group("player_carts"):
				speeds += " %s:%d(%.0f,%.0f)" % [c.name, game.side_of(str(c.name).to_int()), c.global_position.x, c.global_position.z]
			print(line)
			print("   carts" + speeds)
		if t > seconds / speed * speed + 120.0:
			print("TIMEOUT")
			break
	print("RESULT score=%s stats=%s" % [str(game._score), str(game._stat)])
	for n in respawns:
		print("RESPAWNS %s: %d %s" % [n, respawns[n].size(), str(respawns[n])])
	get_tree().quit()
