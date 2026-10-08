extends Node3D

# Drives a PlayerCart at full throttle over a step-up of each height and prints how far above its
# resting ride height the car rises afterwards (the "hop"), plus the speed it carried.
# Also drives up a ramp to a lip, to check jumps still launch.
#   Godot --headless --path . res://scratch/hop_test.tscn [-- heights=0.01,0.03 run_up=60]

const CART_SCENE := preload("res://PlayerCart.tscn")

var heights: Array[float] = [0.0, 0.01, 0.02, 0.04, 0.07, 0.10, 0.15, 0.22, 0.30, 0.40]
var run_ups: Array[float] = [12.0, 60.0]   # metres of flat road before the step (sets impact speed)
var ramp := true


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("heights="):
			heights.clear()
			for s in a.substr(8).split(","):
				heights.append(float(s))
		elif a.begins_with("run_up="):
			run_ups.clear()
			for s in a.substr(7).split(","):
				run_ups.append(float(s))
		elif a == "ramp=0":
			ramp = false
	Engine.physics_ticks_per_second = 60
	MusicManager.window_mode = 0
	AudioServer.set_bus_mute(0, true)
	await get_tree().process_frame
	for run_up in run_ups:
		for h in heights:
			var r: Dictionary = await _run_step(h, run_up, false)
			print("STEP h=%.2f run_up=%3.0f  impact=%.1fm/s  hop=%.3fm  peak_vy=%.2f  exit_speed=%.1fm/s  air=%.2fs" % [h, run_up, r.impact, r.hop, r.peak_vy, r.exit, r.air])
	if ramp:
		for seam in [0.0, 0.02]:
			for run_up in run_ups:
				var r: Dictionary = await _run_step(seam, run_up, true)
				print("RAMP seam=%.2f run_up=%3.0f impact=%.1fm/s  peak_above_lip=%.2fm  air=%.2fs  exit_speed=%.1fm/s" % [seam, run_up, r.impact, r.hop, r.air, r.exit])
	get_tree().quit()


func _box(parent: Node, name_: String, size: Vector3, pos: Vector3, rot_x: float = 0.0) -> void:
	var body := StaticBody3D.new()
	body.name = name_
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.transform = Transform3D(Basis(Vector3.RIGHT, rot_x), pos)
	parent.add_child(body)


func _run_step(h: float, run_up: float, use_ramp: bool) -> Dictionary:
	var world := Node3D.new()
	world.name = "TestLevel"
	add_child(world)
	# Road runs along -Z. Floor top at y=0.
	_box(world, "RoadFloor", Vector3(40, 1, 400), Vector3(0, -0.5, -150))
	var step_z := -run_up
	var lip_y := 0.0
	if use_ramp:
		# 12 degree, 10m long ramp ending in a lip with nothing after it but the floor.
		var ang := deg_to_rad(12.0)
		var length := 10.0
		lip_y = sin(ang) * length
		var centre := Vector3(0, lip_y * 0.5 - 0.25 * cos(ang), step_z - cos(ang) * length * 0.5)
		_box(world, "RampJump", Vector3(12, 0.5, length), centre, ang)
		if h > 0.0:
			# A low seam 3m before the ramp, like a separate ramp mesh sitting on the road.
			_box(world, "RoadSeam", Vector3(12, h, 3.0), Vector3(0, h * 0.5, step_z + 1.5))
	elif h > 0.0:
		_box(world, "RoadStep", Vector3(40, h, 200), Vector3(0, h * 0.5, step_z - 100.0))

	var cart: RigidBody3D = CART_SCENE.instantiate()
	cart.name = "1"
	cart.position = Vector3(0, 0.9, 0)
	world.add_child(cart)
	for i in 3:
		await get_tree().physics_frame
	cart.set("is_landing", false)
	cart.set("can_move", true)
	cart.freeze = false
	# Settle on the floor.
	for i in 30:
		await get_tree().physics_frame
	var rest_y := cart.global_position.y
	Input.action_press("p1_throttle")
	var impact := 0.0
	var top_y := rest_y + h
	var peak := -INF
	var peak_vy := 0.0
	var air := 0.0
	var crossed := false
	var exit_speed := 0.0
	for i in 60 * 12:
		await get_tree().physics_frame
		var p := cart.global_position
		if not crossed and p.z < step_z + 0.5:
			crossed = true
			impact = cart.linear_velocity.length()
		if crossed:
			peak = maxf(peak, p.y)
			peak_vy = maxf(peak_vy, cart.linear_velocity.y)
			if not cart.get("is_on_ground"):
				air += 1.0 / 60.0
			if p.z < step_z - (40.0 if use_ramp else 25.0):
				exit_speed = cart.linear_velocity.length()
				break
	Input.action_release("p1_throttle")
	world.queue_free()
	await get_tree().physics_frame
	var ref := (rest_y + lip_y) if use_ramp else top_y
	return {"impact": impact, "hop": peak - ref, "peak_vy": peak_vy, "exit": exit_speed, "air": air}
