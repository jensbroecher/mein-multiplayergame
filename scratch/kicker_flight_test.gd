extends Node3D

# Freight Line's kicker beside the Branch crossing: drives a real cart over a WoodenRamp on flat ground at
# full throttle from several run-ups and prints its height over the ground along the flight, so the ramp can
# be placed with the flight's height over the rails where a flatcar (2.2m) is cleared and a boxcar (6.3m) isn't.
#   Godot --headless --path . res://scratch/kicker_flight_test.tscn [-- length=12 height=1.6 curve=0.6 run_ups=40,80,140]
# Output: per run-up, the speed at the lip and the cart's centre height every 2m past the lip (cart centre
# over the road is 0.75).

const CART_SCENE := preload("res://PlayerCart.tscn")
const RAMP_SCENE := preload("res://WoodenRamp.tscn")

var ramp_length := 12.0
var ramp_height := 1.6
var ramp_curve := 0.6
var ramp_width := 14.0
var run_ups: Array[float] = [40.0, 80.0, 140.0]


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("length="):
			ramp_length = float(a.substr(7))
		elif a.begins_with("height="):
			ramp_height = float(a.substr(7))
		elif a.begins_with("curve="):
			ramp_curve = float(a.substr(6))
		elif a.begins_with("run_ups="):
			run_ups.clear()
			for v in a.substr(8).split(","):
				run_ups.append(float(v))
	Engine.physics_ticks_per_second = 60
	MusicManager.window_mode = 0
	AudioServer.set_bus_mute(0, true)
	await get_tree().process_frame
	for ru in run_ups:
		await _run(ru)
	get_tree().quit()


func _run(run_up: float) -> void:
	var world := Node3D.new()
	add_child(world)
	var floor_body := StaticBody3D.new()
	floor_body.name = "RoadFloor"
	var fcs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(80, 1, 800)
	fcs.shape = shape
	floor_body.add_child(fcs)
	floor_body.position = Vector3(0, -0.5, -200)
	world.add_child(floor_body)
	var ramp: StaticBody3D = RAMP_SCENE.instantiate()
	ramp.set("settle_on_track", false)
	ramp.set("face_lap", false)
	ramp.set("length", ramp_length)
	ramp.set("height", ramp_height)
	ramp.set("curve", ramp_curve)
	ramp.set("width", ramp_width)
	ramp.position = Vector3(0, 0, 0)
	world.add_child(ramp)
	var cart: RigidBody3D = CART_SCENE.instantiate()
	cart.name = "1"
	cart.position = Vector3(0, 0.9, run_up)
	world.add_child(cart)
	for i in 3:
		await get_tree().physics_frame
	cart.set("is_landing", false)
	cart.set("can_move", true)
	cart.freeze = false
	for i in 30:
		await get_tree().physics_frame
	Input.action_press("p1_throttle")
	var lip_z := -ramp_length
	var samples := {}
	var lip_speed := 0.0
	var landed_at := 0.0
	var airborne := false
	for i in 60 * 10:
		await get_tree().physics_frame
		var p := cart.global_position
		if lip_speed == 0.0 and p.z < lip_z:
			lip_speed = cart.linear_velocity.length()
		if p.z < lip_z:
			var d: int = int(floor((lip_z - p.z) / 2.0)) * 2
			if not samples.has(d):
				samples[d] = p.y
			if not cart.get("is_on_ground"):
				airborne = true
			elif airborne and landed_at == 0.0:
				landed_at = lip_z - p.z
		if p.z < lip_z - 140.0:
			break
	Input.action_release("p1_throttle")
	var line := ""
	for d in samples.keys():
		if int(d) <= 70:
			line += " %d:%.1f" % [d, samples[d]]
	print("run_up %3.0f  lip speed %.1f m/s  landed %.0fm past the lip  | y over road by distance past lip:%s" % [run_up, lip_speed, landed_at, line])
	world.queue_free()
	await get_tree().physics_frame
