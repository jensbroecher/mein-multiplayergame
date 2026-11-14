extends Node

# The time trial's ghost (TimeTrialGhost.gd): two real single-player time trials on one stage. In the first the human's
# cart drives itself (the AI) for `drive=` seconds, then the gates are granted to finish: a clean first run is the best,
# so its ghost must be saved (user://ghosts/<stage>.ghost) with a sample every 0.05s. In the second the ghost must come
# out at the green light and follow the saved path (checked at a few times against the samples), its car hidden once
# its run is over. The player's own records and ghost file are put back (scratch/user_file_guard.gd: a killed run's
# copies are put back by the next run, or by scratch/user_file_guard_restore.gd). Headless, fixed fps:
#   Godot --headless --path . res://scratch/ghost_test.tscn -- [res://levels/X.tscn] [drive=15]
# Not with --fixed-fps: the ghost runs on the race's clock (real time), and with a fixed step a headless run's physics
# races ahead of it, so the recorded run plays back in a second or two.
# Windowed with `shots=<dir>` it also saves the screen through the player's camera as the ghost pulls away in run 2.

const TTR = preload("res://TimeTrialRecords.gd")
const Ghost = preload("res://TimeTrialGhost.gd")
const Guard = preload("res://scratch/user_file_guard.gd")

var fails := 0


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	var level_path := "res://levels/LakesideLevel.tscn"
	var drive := 15.0
	var shots := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("drive="): drive = float(a.substr(6))
		elif a.begins_with("shots="): shots = a.substr(6)
		elif a.begins_with("res://"): level_path = a
	var key: String = TTR.key_of(level_path)
	var files: Array = ["user://time_trial_records.cfg", "user://lap_records.cfg", Ghost.path_of(key)]
	# Copied aside on disk first: a run killed half way leaves them there for the next run to put back.
	Guard.protect("ghost_test", files)
	for f in files:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SINGLE_PLAYER_TIME_TRIAL
	NetworkManager.time_trial_stage = level_path
	NetworkManager.start_single_player("Tester")

	# --- Run 1: record ---
	var level: Node = await _start(level_path)
	var cart = level.players_container.get_node("1")
	cart.is_ai = true
	var t0 := Time.get_ticks_msec()
	var frames := 0
	while frames < int(drive * 60.0):
		await get_tree().physics_frame
		frames += 1
	var stats: Dictionary = level.player_stats[1]
	var cps: int = level.checkpoints.size()
	for lap in level.get_target_laps():
		for i in cps:
			if stats.get("finished", false):
				break
			stats["lap_start"] = Time.get_ticks_msec() - int(60000.0 * float(i + 1) / cps)
			level._grant_checkpoint(1, i)
	_check(stats.get("finished", false), "run 1 finished")
	var g: Dictionary = Ghost.load_ghost(key)
	_check(not g.is_empty(), "the ghost was saved")
	var pos: PackedVector3Array = g.get("pos", PackedVector3Array())
	print("  saved %d samples, dt %.3f, scale %.2f, car %d, %s" % [pos.size(), float(g.get("dt", 0)), float(g.get("scale", 0)), int(g.get("car_index", -1)), TTR.format_ms(int(g.get("total_ms", 0)))])
	_check(absf(float(pos.size()) - drive * 20.0) < 25.0, "about %d samples (%d)" % [int(drive * 20.0), pos.size()])
	var moved: float = pos[0].distance_to(pos[pos.size() - 1]) if pos.size() > 1 else 0.0
	_check(moved > 50.0, "the recorded car moved (%.0fm)" % moved)
	level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	# --- Run 2: play ---
	level = await _start(level_path)
	cart = level.players_container.get_node("1")
	cart.can_move = false
	var ghost = level.get("_ghost")
	_check(ghost != null and ghost._playing, "a ghost plays in run 2")
	var ts0: PackedInt32Array = g.get("t", PackedInt32Array())
	if ts0.size() > 1:
		print("  the recording ran %.1fs on the race clock" % (float(ts0[ts0.size() - 1]) / 1000.0))
	_check((g.get("t", PackedInt32Array()) as PackedInt32Array).size() == pos.size(), "every sample has its time on the race clock")
	for t in [1.0, 2.0, 4.0, 8.0, drive - 1.0]:
		var spin := 0
		while ghost._playing and ghost._play_t < t and spin < 3000:
			await get_tree().process_frame
			spin += 1
		await get_tree().process_frame
		var car: Node3D = ghost._car
		# Where the saved run was at the moment shown (each sample's time on the race clock, `t`).
		var ts: PackedInt32Array = g.get("t", PackedInt32Array())
		var ms: float = ghost.shown_t * 1000.0
		var i: int = clampi(ts.bsearch(int(floor(ms)), false) - 1, 0, pos.size() - 2)
		var want: Vector3 = pos[i].lerp(pos[i + 1], clampf((ms - float(ts[i])) / maxf(float(ts[i + 1] - ts[i]), 1.0), 0.0, 1.0))
		var d: float = car.global_position.distance_to(want)
		if shots != "" and DisplayServer.get_name() != "headless":
			DirAccess.make_dir_recursive_absolute(shots)
			get_viewport().get_texture().get_image().save_png(shots.path_join("ghost_%04.1f.png" % t))
			print("SHOT ghost_%04.1f" % t)
		_check(d < 0.6, "at %.1fs the ghost is on its path (%.2fm off, at %s)" % [t, d, str(car.global_position.snapped(Vector3.ONE * 0.1))])
	# Its clock stops once it has faded out (it stops playing), so wait for that, not for a time.
	var waited := 0
	while ghost._playing and waited < 600:
		await get_tree().process_frame
		waited += 1
	await get_tree().process_frame
	_check(not ghost._car.visible, "hidden after its run (%.1fs)" % ghost._play_t)
	print("RESULT: %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	Guard.restore("ghost_test")
	get_tree().quit()


func _start(level_path: String) -> Node:
	var level: Node = load(level_path).instantiate()
	add_child(level)
	while level.race_state != level.RaceState.RACING or level._race_go_msec == 0:
		await get_tree().process_frame
	await get_tree().process_frame
	return level
