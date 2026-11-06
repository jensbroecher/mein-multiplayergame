extends Node

# The race start through Main's own flow (the loading screen, the grid's drop, the intro's camera move, the countdown):
# starts a single-player GP on a stage and logs, frame by frame, what shows once the loading screen has gone: any cart
# still dropping onto the grid (FAIL: it should all happen under the cover), the camera's speed and turn rate through
# the move (from its start to a second after the hand-over), the worst jump in its velocity from one frame to the next (the hand-over to the race camera included: the
# old orbit ended at a fixed world offset and the race camera snapped from there), and which start the intro picked.
# Saves frames along the move into <dir>. Windowed (`--fixed-fps 60` keeps the clock steady while the shots save):
#   Godot --path . --resolution 1600x900 --fixed-fps 60 res://scratch/start_intro_test.tscn -- <dir>
#       [cup="Bloombay GP"] [stage=0] [mode=chase|top|follow] [shots=0,0.25,0.5,0.75,1.0,1.4]
# `trace` prints the intro's progress and the camera every 6 frames.
# Shots are at those fractions of the intro (from its start; past 1 is after the hand-over).

var main: Node


func _ready() -> void:
	var dir := ""
	var cup := "Bloombay GP"
	var stage := 0
	var mode := ""
	var trace := false
	var shots: PackedFloat32Array = [0.0, 0.25, 0.5, 0.75, 1.0, 1.4]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("cup="): cup = a.substr(4)
		elif a.begins_with("stage="): stage = int(a.substr(6))
		elif a.begins_with("mode="): mode = a.substr(5)
		elif a == "trace": trace = true
		elif a.begins_with("shots="):
			shots = PackedFloat32Array()
			for v in a.substr(6).split(","):
				shots.append(float(v))
		elif not a.contains("="): dir = a
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
	AudioServer.set_bus_mute(0, true)
	var saved_mode: int = MusicManager.camera_mode
	match mode:
		"chase": MusicManager.camera_mode = MusicManager.CameraMode.HIGH_CHASE
		"top": MusicManager.camera_mode = MusicManager.CameraMode.TOP_DOWN
		"follow": MusicManager.camera_mode = MusicManager.CameraMode.FOLLOWER
	main = load("res://Main.tscn").instantiate()
	add_child(main)
	for i in 10:
		await get_tree().process_frame
	main.main_menu.hide()
	NetworkManager.current_game_mode = NetworkManager.GameMode.SINGLE_PLAYER_GP
	NetworkManager.current_gp_name = cup
	NetworkManager.current_gp_stage = stage
	NetworkManager.start_single_player("Tester")
	main.start_game(true)
	var t0 := Time.get_ticks_msec()
	var level: Node = null
	var revealed_at := -1.0
	var falling_seen := 0
	var intro_started := -1.0
	var intro_ended := -1.0
	var prev_pos := Vector3(NAN, NAN, NAN)
	var prev_vel := Vector3.ZERO
	var prev_fwd := Vector3.ZERO
	var max_speed := 0.0
	var max_turn := 0.0
	var max_jerk := 0.0
	var max_jerk_at := 0.0
	var handover_jerk := 0.0
	var shot_i := 0
	var frames := 0
	while Time.get_ticks_msec() - t0 < 90000:
		await get_tree().process_frame
		var dt: float = maxf(get_process_delta_time(), 0.001)
		if level == null:
			level = get_tree().get_first_node_in_group("level")
			continue
		var covered: bool = main.loading_screen.visible
		var cart: Node = level.players_container.get_node_or_null("1")
		if cart == null:
			continue
		var now := (Time.get_ticks_msec() - t0) / 1000.0
		if not covered and revealed_at < 0.0:
			revealed_at = now
			print("REVEALED at %.2fs, race state %d, intro %s, holding %s" % [now, level.race_state, cart.is_intro_active, cart._intro_holding])
		if covered:
			continue
		for c in level.players_container.get_children():
			if c.get("is_landing"):
				falling_seen += 1
				if falling_seen == 1:
					print("FALLING in view: %s at %.2fs, at %s, velocity %s" % [c.name, now, str((c as Node3D).global_position), str(c.get("linear_velocity"))])
		if cart.is_intro_active and intro_started < 0.0:
			intro_started = now
		if intro_started >= 0.0 and not cart.is_intro_active and intro_ended < 0.0:
			intro_ended = now
		var cam: Camera3D = get_viewport().get_camera_3d()
		var pos: Vector3 = cam.global_position
		var fwd: Vector3 = -cam.global_basis.z
		if not is_nan(prev_pos.x):
			var vel: Vector3 = (pos - prev_pos) / dt
			var jerk: float = (vel - prev_vel).length() / dt
			var turn: float = rad_to_deg(prev_fwd.angle_to(fwd)) / dt
			# Only through the move and the second after the hand-over: later it is the race camera.
			var measuring: bool = intro_started >= 0.0 and (intro_ended < 0.0 or now - intro_ended < 1.0)
			if frames > 2 and measuring:
				max_speed = maxf(max_speed, vel.length())
				max_turn = maxf(max_turn, turn)
				if jerk > max_jerk:
					max_jerk = jerk
					max_jerk_at = now
				if intro_ended >= 0.0 and now - intro_ended < 1.0:
					handover_jerk = maxf(handover_jerk, jerk)
			prev_vel = vel
		prev_pos = pos
		prev_fwd = fwd
		frames += 1
		if trace and frames % 6 == 0 and (cart.is_intro_active or cart._intro_holding or now - intro_ended < 1.0):
			print("TRACE %.2fs t=%.3f active=%s hold=%s cam=%s race=%s" % [now, cart._intro_t, cart.is_intro_active, cart._intro_holding,
				str(pos.snappedf(0.1)), str(cart._intro_race_pos.snappedf(0.1))])
		var frac: float = -1.0
		if intro_started >= 0.0:
			frac = (now - intro_started) / float(level.INTRO_SECONDS)
		if dir != "" and shot_i < shots.size() and frac >= shots[shot_i]:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(dir.path_join("intro_%02d_%s.png" % [shot_i, str(snappedf(shots[shot_i], 0.01))]))
			print("SHOT %.2f at %.2fs cam %s" % [shots[shot_i], now, str(pos)])
			shot_i += 1
		if intro_ended >= 0.0 and now - intro_ended > 2.0 and (shot_i >= shots.size() or shots[shot_i] > 1.6):
			break
	print("intro %.2fs to %.2fs (revealed %.2fs); in view: falling frames %d" % [intro_started, intro_ended, revealed_at, falling_seen])
	print("camera: top speed %.1f m/s, top turn %.1f deg/s, worst velocity jump %.0f m/s^2 at %.2fs, at the hand-over %.0f m/s^2" % [
		max_speed, max_turn, max_jerk, max_jerk_at, handover_jerk])
	print("RESULT %s" % ("PASS" if falling_seen == 0 and intro_ended > 0.0 else "FAIL"))
	MusicManager.camera_mode = saved_mode
	get_tree().quit()
