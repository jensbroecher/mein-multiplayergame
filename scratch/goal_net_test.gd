extends Node
## Shoots Kronburger Hütte's football into a goal and logs the ball and the net (GoalNet.gd), saving frames when windowed.
##   Godot --path . --resolution 1280x720 res://scratch/goal_net_test.tscn -- [<dir>] [goal=West|East] [speed=22] [lat=0]
##       [up=3] [from=14] [cam=x,y,z] [frames=0.3,0.5,...]
## Headless (--headless, no dir) it only logs: the ball must end up inside the goal, short of the net's stretch.
##   ... -- cart=front|back [speed=25]: drives a real cart (a spectator race's first) into the back of the net from inside
##   the goal (front: in through the mouth) or from behind it, and prints how far it got (it must stay within the stretch).
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := ""
	var goal := "West"
	var speed := 22.0
	var lat := 0.0
	var up := 3.0
	var from := 14.0
	var cam_at := Vector3.INF
	var frames := PackedFloat64Array([0.25, 0.45, 0.6, 0.8, 1.2, 2.0])
	var cart_mode := ""
	for a in args:
		if a.begins_with("cart="): cart_mode = a.substr(5)
	if cart_mode != "":
		for a in args:
			if a.begins_with("speed="): speed = a.substr(6).to_float()
			elif a.begins_with("goal="): goal = a.substr(5)
		_cart_test(cart_mode, goal, speed)
		return
	for a in args:
		if a.begins_with("goal="): goal = a.substr(5)
		elif a.begins_with("speed="): speed = a.substr(6).to_float()
		elif a.begins_with("lat="): lat = a.substr(4).to_float()
		elif a.begins_with("up="): up = a.substr(3).to_float()
		elif a.begins_with("from="): from = a.substr(5).to_float()
		elif a.begins_with("cam="):
			var c := a.substr(4).split_floats(",")
			cam_at = Vector3(c[0], c[1], c[2])
		elif a.begins_with("frames="): frames = a.substr(7).split_floats(",")
		elif not a.contains("="): dir = a
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		n.visible = false
	var level: Node3D = (load("res://levels/KronburgLevel.tscn") as PackedScene).instantiate()
	add_child(level)
	var net: Node3D = level.get_node("Bolzplatz/GoalNet" + goal)
	var ball: RigidBody3D = level.get_node("Bolzplatz/Football")
	for i in 10:
		await get_tree().physics_frame
	var xf: Transform3D = net.global_transform
	var start: Vector3 = xf * Vector3(lat, 0.4, -from)
	var target: Vector3 = xf * Vector3(lat * 0.3, 1.4, 1.0)
	ball.global_position = start
	var v: Vector3 = (target - start).normalized() * speed + Vector3.UP * up
	ball.linear_velocity = v
	ball.sleeping = false
	var cam := Camera3D.new()
	add_child(cam)
	var eye: Vector3 = cam_at if cam_at != Vector3.INF else xf * Vector3(9.0, 3.5, -9.0)
	cam.look_at_from_position(eye, xf * Vector3(0, 1.5, 1.5))
	cam.make_current()
	var t := 0.0
	var fi := 0
	var inv: Transform3D = xf.affine_inverse()
	var max_amp := 0.0
	while t < 4.0:
		await get_tree().physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		var lp: Vector3 = inv * ball.global_position
		var amp := 0.0
		for p in net.get("_pokes"):
			amp = maxf(amp, absf(float(p["amp"])))
		max_amp = maxf(max_amp, amp)
		if int(t * 60.0) % 6 == 0:
			print("t=%.2f ball local=(%.2f, %.2f, %.2f) v=%.1f net=%.2f" % [t, lp.x, lp.y, lp.z, ball.linear_velocity.length(), amp])
		if dir != "" and fi < frames.size() and t >= frames[fi]:
			await RenderingServer.frame_post_draw
			get_tree().root.get_texture().get_image().save_png("%s/net_%02d.png" % [dir, fi])
			fi += 1
	var end: Vector3 = inv * ball.global_position
	var inside: bool = end.z > 0.0 and absf(end.x) < float(net.get("half_width")) and end.y < float(net.get("height"))
	print("RESULT ball end local=%s inside=%s max_net=%.2f" % [end, inside, max_amp])
	get_tree().quit()


func _cart_test(mode: String, goal: String, speed: float) -> void:
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	var level: Node3D = (load("res://levels/KronburgLevel.tscn") as PackedScene).instantiate()
	add_child(level)
	await level.wait_for_collisions()
	for i in 10:
		await get_tree().physics_frame
	var net: Node3D = level.get_node("Bolzplatz/GoalNet" + goal)
	var xf: Transform3D = net.global_transform
	var inv: Transform3D = xf.affine_inverse()
	var cart: RigidBody3D = get_tree().get_nodes_in_group("player_carts")[0]
	var wait := 0.0
	while not cart.can_move and wait < 30.0:
		await get_tree().physics_frame
		wait += get_physics_process_delta_time()
	# Inside: from 20m out in front, through the mouth to the back. Behind: from 20m behind, toward the goal.
	# Not a bot (it would turn for the road and respawn), but driven here: still this peer's to move.
	cart.set("is_ai", false)
	cart.set("is_local_player", true)
	var from_l := Vector3(1.0, 0.85, -20.0) if mode == "front" else Vector3(1.0, 0.85, float(net.get("depth")) + 20.0)
	var dir_l := Vector3(0, 0, 1) if mode == "front" else Vector3(0, 0, -1)
	var from: Vector3 = xf * from_l
	var dir: Vector3 = (xf.basis * dir_l).normalized()
	PhysicsServer3D.body_set_state(cart.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(Basis.looking_at(dir, Vector3.UP), from))
	for i in 20:
		cart.linear_velocity = Vector3(0.0, cart.linear_velocity.y, 0.0)
		await get_tree().physics_frame
	var t := 0.0
	var touched := -1.0
	var deepest := -INF
	var limit: float = float(net.get("depth")) + 1.0 if mode == "front" else -INF
	while t < 5.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		var lp: Vector3 = inv * cart.global_position
		var amp := 0.0
		for p in net.get("_pokes"):
			amp = maxf(amp, absf(float(p["amp"])))
		if touched < 0.0 and amp > 0.01:
			touched = t
			print("t=%.2f TOUCH at local %s, %.1f m/s" % [t, lp, cart.linear_velocity.length()])
		if touched < 0.0 or t - touched < 1.5:
			# Held at speed on its line until 1.5s after it meets the net: the net has to stop it against that.
			cart.linear_velocity = Vector3(dir.x * speed, cart.linear_velocity.y, dir.z * speed) if touched < 0.0 else cart.linear_velocity
		deepest = maxf(deepest, lp.z if mode == "front" else -lp.z)
		if int(t * 60.0) % 6 == 0:
			print("t=%.2f cart local=(%.2f, %.2f, %.2f) v=%.1f net=%.2f" % [t, lp.x, lp.y, lp.z, cart.linear_velocity.length(), amp])
	var end: Vector3 = inv * cart.global_position
	var through: bool = end.z > float(net.get("depth")) + 2.6 if mode == "front" else (end.z < 0.0)
	print("RESULT %s: deepest %.2f, end local %s, through=%s" % [mode, deepest, end, through])
	get_tree().quit()
