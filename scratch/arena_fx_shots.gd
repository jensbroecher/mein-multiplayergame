extends Node
## Photographs the Hex Bowl's goal and kick-off effects (ArenaFx.gd, ArenaGame's `_ball_fx_rpc`), the goals' name
## labels and the name boards over the stands: a single-player football match in a window, the ball shot into goal 0
## once the match runs, frames from a camera of its own before goal 0 through the goal and the burst, then from one
## by the middle through the ball's return, then a wide view of the bowl.
##   Godot --path . --resolution 1600x900 res://scratch/arena_fx_shots.tscn -- <dir> [teams=1] [goal=0]

var cam: Camera3D


func _process(_delta: float) -> void:
	if cam:
		cam.make_current()


func _shot(dir: String, n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, n])
	print("SHOT ", n)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0]
	var teams := args.has("teams=1")
	var goal_i := 0
	for a in args:
		if a.begins_with("goal="):
			goal_i = int(a.substr(5))
	DirAccess.make_dir_recursive_absolute(dir)
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SINGLE_PLAYER_TIME_TRIAL
	NetworkManager.arena = {"kind": "football", "teams": teams}
	NetworkManager.start_single_player("Jabro")
	var level: Node = load(NetworkManager.arena_level()).instantiate()
	add_child(level)
	var game: Node = level.get_node("ArenaGame")
	while level.race_state != 1 or not bool(game._running):
		await get_tree().process_frame
	# Everyone stands still: only the staged ball moves.
	for c in get_tree().get_nodes_in_group("player_carts"):
		c.set("is_ai", false)
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.far = 2000.0
	add_child(cam)
	var goal: Node3D = game._goals[goal_i]
	var gt := goal.global_transform
	cam.global_position = gt * Vector3(11.0, 6.5, -24.0)
	cam.look_at(gt * Vector3(0, 3.2, 1.0))
	await get_tree().create_timer(2.0).timeout
	var scorer := 0
	for id in game._side:
		if int(game._side[id]) != int(game._goal_owner[goal_i]):
			scorer = int(id)
			break
	var ball: RigidBody3D = game._balls[0]
	ball.global_position = gt * Vector3(0.5, 2.4, -9.0)
	ball.linear_velocity = gt.basis * Vector3(0, 1.5, 24.0)
	ball.reset_physics_interpolation()
	game._ball_anchor[0] = [ball.global_position, 0.0]
	var t := 0.0
	var k := 0
	var marks := [0.3, 0.5, 0.65, 0.8, 0.95, 1.1, 1.3, 1.7]
	while k < marks.size():
		await get_tree().process_frame
		t += get_process_delta_time()
		# Its last touch: set every frame until it is in (the carts standing near would take it).
		if float(game._ball_linger[0]) <= 0.0 and bool(game._ball_active[0]):
			game._last_touch[0] = scorer
		if t >= float(marks[k]):
			await _shot(dir, "goal_%02d" % k)
			k += 1
	# The kick-off: wait for the ball to come back.
	cam.global_position = Vector3(15.0, 5.0, 17.0)
	cam.look_at(Vector3(0, 5.5, 0))
	while not bool(game._ball_active[0]):
		await get_tree().process_frame
	t = 0.0
	k = 0
	marks = [0.05, 0.2, 0.4, 0.7, 1.1]
	while k < marks.size():
		await get_tree().process_frame
		t += get_process_delta_time()
		if t >= float(marks[k]):
			await _shot(dir, "spawn_%02d" % k)
			k += 1
	cam.global_position = Vector3(-30.0, 9.0, 18.0)
	cam.look_at(Vector3(48.0, 9.0, -6.0))
	cam.fov = 70.0
	await get_tree().create_timer(0.4).timeout
	await _shot(dir, "bowl")
	cam.global_position = Vector3(0.0, 10.0, -8.0)
	cam.look_at(Vector3(40.0, 4.0, 26.0))
	await get_tree().create_timer(0.3).timeout
	await _shot(dir, "corner")
	get_tree().quit()
