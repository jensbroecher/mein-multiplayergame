extends Node3D

# Freight Line's train against a real cart. A rail runs along x, a road along -z crosses it at the
# origin; the cart sets off 70m back at full throttle and the train's clock is set so the cart reaches
# the crossing at a chosen second of the train's cycle: in the middle of each kind of car, in the gap,
# before the head and after the tail. Prints whether the cart was destroyed and whether it should have been.
#   Godot --headless --path . res://scratch/train_kill_test.tscn [-- consist=loco,box,gap:16,... speed=24 run_up=70]

const CART_SCENE := preload("res://PlayerCart.tscn")
const Train = preload("res://Train.gd")

var consist := PackedStringArray(["loco", "box", "flat", "flat_load", "gap:16", "tank", "gap:16", "box", "caboose"])
var speed := 24.0
var run_up := 70.0
const PERIOD := 40.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("consist="):
			consist = PackedStringArray(a.substr(8).split(","))
		elif a.begins_with("speed="):
			speed = float(a.substr(6))
		elif a.begins_with("run_up="):
			run_up = float(a.substr(7))
	Engine.physics_ticks_per_second = 60
	MusicManager.window_mode = 0
	AudioServer.set_bus_mute(0, true)
	await get_tree().process_frame

	var arrive := await _calibrate()
	print("cart reaches the crossing %.2fs after setting off" % arrive)

	# The cases: the middle of each solid car, of each gap, and either side of the train.
	var probe := _make_train()
	add_child(probe)
	await get_tree().physics_frame
	var cases: Array = []
	var off := 0.0
	for car in probe.cars:
		var mid: float = (off + car.length * 0.5) / speed + 300.0 / speed   # crossing is 300m along the path
		cases.append([car.kind, mid, not car.solid])
		off += car.length
	cases.insert(0, ["before the head", 0.0, true])
	var tail_t: float = (off + 300.0) / speed + 1.5
	cases.append(["after the tail", tail_t, true])
	probe.queue_free()
	await get_tree().physics_frame

	var wrong := 0
	for c in cases:
		var r: Dictionary = await _trial(c[1], arrive)
		var expect_alive: bool = c[2]
		var ok: bool = (r.alive == expect_alive)
		if not ok:
			wrong += 1
		print("%-16s t=%5.1fs  cart %s  (expected %s)  %s" % [c[0], c[1], "survived" if r.alive else "destroyed", "survive" if expect_alive else "destroy", "ok" if ok else "MISMATCH"])
	print("RESULT: %s" % ("PASS" if wrong == 0 else "FAIL (%d mismatches)" % wrong))
	get_tree().quit()


func _make_train() -> Node3D:
	var t: Node3D = Train.new()
	var curve := Curve3D.new()
	curve.add_point(Vector3(-300, 0, 0))
	curve.add_point(Vector3(300, 0, 0))
	t.path = curve
	t.consist = consist
	t.speed = speed
	t.period = PERIOD
	t.clock_override = 0.0
	return t


func _world() -> Node3D:
	var world := Node3D.new()
	add_child(world)
	var body := StaticBody3D.new()
	body.name = "RoadFloor"
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(200, 1, 400)
	cs.shape = shape
	body.add_child(cs)
	body.position = Vector3(0, -0.5, 0)
	world.add_child(body)
	return world


func _spawn(world: Node3D) -> RigidBody3D:
	var cart: RigidBody3D = CART_SCENE.instantiate()
	cart.name = "1"
	cart.position = Vector3(0, 0.9, run_up)
	world.add_child(cart)
	return cart


func _settle(cart: RigidBody3D) -> void:
	for i in 3:
		await get_tree().physics_frame
	cart.set("is_landing", false)
	cart.set("can_move", true)
	cart.freeze = false
	for i in 30:
		await get_tree().physics_frame


func _calibrate() -> float:
	var world := _world()
	var cart := _spawn(world)
	await _settle(cart)
	Input.action_press("p1_throttle")
	var t := 0.0
	for i in 60 * 15:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if cart.global_position.z < 0.0:
			break
	Input.action_release("p1_throttle")
	world.queue_free()
	await get_tree().physics_frame
	return t


## One run: the cart arrives at the crossing at cycle time `at`.
func _trial(at: float, arrive: float) -> Dictionary:
	var world := _world()
	var train := _make_train()
	world.add_child(train)
	var cart := _spawn(world)
	await _settle(cart)
	var base := at - arrive
	while base < 0.0:
		base += PERIOD
	var elapsed := 0.0
	train.clock_override = base
	Input.action_press("p1_throttle")
	var dead := false
	for i in 60 * 12:
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0
		train.clock_override = base + elapsed
		if cart.get("is_exploding"):
			dead = true
			break
		if cart.global_position.z < -40.0:
			break
	Input.action_release("p1_throttle")
	world.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	return {"alive": not dead}
