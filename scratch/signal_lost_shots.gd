extends Node

# Photographs the "signal lost" cut (SignalLostOverlay, signal_lost.gdshader) in a real single-player race: the weak
# signal warning, then the human's cart lost (PlayerCart._signal_lost_respawn) and frames through the break-up, the
# static, the respawn and the restore. Windowed, with --fixed-fps 60 so the clock is the same however slowly it saves:
#   Godot --path . --resolution 1600x900 --fixed-fps 60 res://scratch/signal_lost_shots.tscn -- <dir>
#       [level=res://levels/LakesideLevel.tscn] [times=0.1,0.25,0.6,1.2,1.6,1.75,1.95] [weak=0.7]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var level_path := "res://levels/LakesideLevel.tscn"
	var times := [0.1, 0.25, 0.6, 1.2, 1.6, 1.75, 1.95]
	var weak := 0.7
	for a in args.slice(1):
		if a.begins_with("level="): level_path = a.substr(6)
		elif a.begins_with("times="): times = Array(a.substr(6).split(",")).map(func(x): return float(x))
		elif a.begins_with("weak="): weak = float(a.substr(5))
	NetworkManager.current_game_mode = NetworkManager.GameMode.SINGLE_PLAYER_GP
	NetworkManager.start_single_player("Tester")
	var level: Node = load(level_path).instantiate()
	add_child(level)
	while level.race_state != level.RaceState.RACING:
		await get_tree().process_frame
	var cart = level.players_container.get_node("1")
	for i in 150:
		await get_tree().process_frame
	# The warning: the picture breaking up a little.
	# (The cart sets the warning itself every check: off for the shot.)
	cart.is_local_player = false
	cart.race_ui.set_signal_weak(weak)
	for i in 90:
		await get_tree().process_frame
	await _shot(out, "weak")
	cart.race_ui.set_signal_weak(0.0)
	cart.is_local_player = true
	for i in 90:
		await get_tree().process_frame
	cart.call("_signal_lost_respawn")
	var t := 0.0
	var k := 0
	while k < times.size():
		await get_tree().process_frame
		t += 1.0 / 60.0
		if t >= float(times[k]):
			await _shot(out, "cut_%02d_%.2f" % [k, float(times[k])])
			k += 1
	get_tree().quit()


func _shot(out: String, n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, n])
	print("SHOT ", n)
