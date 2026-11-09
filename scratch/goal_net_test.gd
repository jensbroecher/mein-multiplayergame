extends Node
## Shoots Kronburger Hütte's football into a goal and logs the ball and the net (GoalNet.gd), saving frames when windowed.
##   Godot --path . --resolution 1280x720 res://scratch/goal_net_test.tscn -- [<dir>] [goal=West|East] [speed=22] [lat=0]
##       [up=3] [from=14] [cam=x,y,z] [frames=0.3,0.5,...]
## Headless (--headless, no dir) it only logs: the ball must end up inside the goal, short of the net's stretch.
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
