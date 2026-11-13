extends Node
## Checks that the Hex Bowl's ball can't come to rest out of the cars' reach, headless. With the bots held still
## (so nothing but the bowl moves the ball) it drops the ball from 12m over each corner (the slope behind the
## slingshot bar), each pop bumper, each wall's foot and each goal's roof line, and prints where it lay after
## `watch` seconds and whether the arena had to take it back to the middle (ArenaGame._ball_out_of_reach). Then it
## holds a ball still 4m up in the air: the arena must return it within STRANDED_TIME and a bit.
##   Godot --headless --path . res://scratch/arena_ball_reach_test.tscn -- [watch=10] [only=corner]
## PASS: after every drop the ball comes back down to the pitch (its middle under 1.6m at some time in the last 3
## seconds: it is lively and may still be bouncing) without a return, and the held ball is returned.

func _ready() -> void:
	var watch := 10.0
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("watch="):
			watch = float(a.substr(6))
		elif a.begins_with("only="):
			only = a.substr(5)
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	NetworkManager.arena = {"kind": "football", "teams": false}
	var level: Node = load(NetworkManager.arena_level()).instantiate()
	add_child(level)
	var game: Node = level.get_node("ArenaGame")
	game.match_seconds = 3600.0
	# Past the green light's own kick-off (it would take the first drop's ball back to the middle).
	while level.race_state != 1 or not bool(game._running):
		await get_tree().physics_frame
	for k in 90:
		await get_tree().physics_frame
	# The bots stand still, far from every drop.
	for c in get_tree().get_nodes_in_group("player_carts"):
		c.set("can_move", false)
		c.set("is_ai", false)
	var r: float = 48.0
	var rc := r / 0.8660254
	var drops: Array = []
	for k in 6:
		var a := k * PI / 3.0 + PI / 6.0
		var dir := Vector3(cos(a), 0, sin(a))
		var across := Vector3(-dir.z, 0, dir.x)
		drops.append(["corner%d mid" % k, dir * (rc - 2.2)])
		drops.append(["corner%d side" % k, dir * (rc - 3.2) + across * 3.5])
		drops.append(["corner%d bar" % k, dir * (rc - 5.0) + across * 2.0])
		var s := k * PI / 3.0
		var sd := Vector3(cos(s), 0, sin(s))
		var sx := Vector3(-sd.z, 0, sd.x)
		drops.append(["wall%d foot" % k, sd * (r - 1.2) + sx * 16.0])
		drops.append(["goal%d lintel" % k, sd * (r - 1.1)])
	for k in 3:
		var a := k * TAU / 3.0 + PI / 2.0
		drops.append(["bumper%d top" % k, Vector3(cos(a), 0, sin(a)) * 14.0 + Vector3(0.5, 0, 0.3)])
	var ball: RigidBody3D = game._balls[0]
	var bad := 0
	for d in drops:
		if only != "" and not str(d[0]).contains(only):
			continue
		# A goal or a return takes the ball away: wait for it to be back.
		while not bool(game._ball_active[0]) or float(game._ball_linger[0]) > 0.0:
			await get_tree().physics_frame
		var at: Vector3 = (d[1] as Vector3) + Vector3(0, 12.0, 0)
		ball.global_position = at
		ball.linear_velocity = Vector3.ZERO
		ball.angular_velocity = Vector3.ZERO
		ball.reset_physics_interpolation()
		game._ball_anchor[0] = [at, 0.0]
		var score0: String = str(game._score)
		var returned := false
		var t := 0.0
		var low := INF
		var prev := at
		while t < watch:
			await get_tree().physics_frame
			t += get_physics_process_delta_time()
			if not bool(game._ball_active[0]) or float(game._ball_linger[0]) > 0.0 or str(game._score) != score0:
				break
			var p := ball.global_position
			# Taken back to the middle: it jumps there in one step.
			if p.distance_to(prev) > 8.0:
				returned = true
				break
			prev = p
			if t > watch - 3.0:
				low = minf(low, p.y)
		var p2 := ball.global_position
		var what := "on the pitch"
		var ok := true
		if str(game._score) != score0 or float(game._ball_linger[0]) > 0.0 or not bool(game._ball_active[0]):
			what = "went into a goal"
		elif returned:
			what = "RETURNED to the middle (it had lain out of reach)"
			ok = false
		elif low > 1.6:
			what = "STILL UP, never under %.1fm" % low
			ok = false
		if not ok:
			bad += 1
		print("%-16s from (%.0f, %.0f) -> (%.1f, %.1f, %.1f) after %.1fs: %s" % [d[0], at.x, at.z, p2.x, p2.y, p2.z, t, what])
	# The watch itself: a ball held still in the air must come back.
	while not bool(game._ball_active[0]) or float(game._ball_linger[0]) > 0.0:
		await get_tree().physics_frame
	var hold := Vector3(20.0, 4.0, 10.0)
	var t2 := 0.0
	var came_back := false
	while t2 < 5.0:
		await get_tree().physics_frame
		t2 += get_physics_process_delta_time()
		if ball.global_position.distance_to(hold) > 6.0 and t2 > 0.5:
			came_back = true
			break
		ball.global_position = hold
		ball.linear_velocity = Vector3.ZERO
	print("held ball: %s after %.1fs" % ["returned to the middle" if came_back else "NOT returned", t2])
	if not came_back:
		bad += 1
	print("PASS" if bad == 0 else "FAIL (%d)" % bad)
	get_tree().quit()
