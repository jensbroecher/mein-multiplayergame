extends Node

# Walks out of the headquarters (Garage.gd) with real key events: from the foyer facing the doors, holds W and prints
# where the walker is, how far the sliding doors are open and their colliders, every half second; then walks into the
# fountain, a plane's tree grate, the kerb and a side hedge, and prints where each one stopped it. PASS when the walker
# got out through the doors and every obstacle stopped it.
#   Godot --headless --path . --fixed-fps 60 res://scratch/hq_walk_out_test.tscn

var garage: Control
var fails := 0


func _key(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)


func _walk(from: Vector3, yaw_deg: float, seconds: float, label: String, log_every := 0) -> Vector3:
	garage._player.global_position = from
	garage._yaw = deg_to_rad(yaw_deg)
	garage._player.rotation.y = garage._yaw
	garage._move = Vector3.ZERO
	for i in 10:
		await get_tree().physics_frame
	_key(KEY_W, true)
	var frames := int(seconds * Engine.physics_ticks_per_second)
	for i in frames:
		await get_tree().physics_frame
		if log_every > 0 and i % log_every == 0:
			var p: Vector3 = garage._player.global_position
			print("  %s t=%.1f pos=(%.2f, %.2f) door=%.2f leaves x=%s" % [label, i / 60.0, p.x, p.z, garage._door_open,
					str(garage._door_shapes.map(func(c): return snappedf(c.position.x, 0.01)))])
	_key(KEY_W, false)
	for i in 20:
		await get_tree().physics_frame
	return garage._player.global_position


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	garage = load("res://Garage.gd").new()
	add_child(garage)
	for i in 50:
		await get_tree().process_frame
	garage.start()
	for i in 20:
		await get_tree().process_frame
	_check(garage._door_open == 0.0, "doors shut at the start (walker %.1fm in)" % (garage.ENTRANCE_Z - garage._player.global_position.z))
	var zo: float = garage.ENTRANCE_Z + garage.WALL_T * 0.5
	var p: Vector3 = await _walk(Vector3(0.0, 0.05, -0.5), 180.0, 5.0, "out", 30)
	_check(p.z > zo + 6.0, "walked out through the doors to z %.1f" % p.z)
	for i in 120:
		await get_tree().physics_frame
	_check(garage._door_open == 0.0, "doors shut again behind the walker")
	var fz: float = zo + garage.PLAZA_FOUNTAIN_Z
	p = await _walk(Vector3(0.0, 0.05, fz - 9.0), 180.0, 4.0, "fountain")
	_check(p.z < fz - 5.0 and p.z > fz - 6.0, "stopped at the fountain's rim (z %.2f, rim at %.2f)" % [p.z, fz - 5.1])
	var tz: float = zo + float(garage.PLAZA_AVENUE[1])
	p = await _walk(Vector3(garage.PLAZA_AVENUE_X, 0.05, tz - 4.0), 180.0, 3.0, "plane")
	_check(p.z < tz - 0.6, "stopped at a plane's trunk (z %.2f, trunk at %.2f)" % [p.z, tz])
	var zr: float = zo + garage.PLAZA_DEPTH
	var hits := 0
	for c in garage._walls.get_children():
		if c is CollisionShape3D and c.shape is BoxShape3D and absf(c.position.z - (zr - 0.8)) < 0.3:
			print("  kerb rail shape at ", c.position, " size ", c.shape.size, " disabled=", c.disabled)
			hits += 1
	print("  kerb rail shapes: ", hits)
	p = await _walk(Vector3(2.0, 0.05, zr - 6.0), 180.0, 4.0, "kerb", 30)
	_check(p.z < zr - 0.9, "stopped at the kerb (z %.2f, kerb at %.2f)" % [p.z, zr])
	p = await _walk(Vector3(garage.GROUNDS_HALF - 6.0, 0.05, zo + 10.0), -90.0, 4.0, "hedge")
	_check(p.x < garage.GROUNDS_HALF - 0.5, "stopped at the side hedge (x %.2f, hedge at %.2f)" % [p.x, garage.GROUNDS_HALF - 0.5])
	p = await _walk(Vector3(0.0, 0.05, zo + 6.0), 0.0, 4.0, "back in", 60)
	_check(p.z < garage.ENTRANCE_Z - 1.0, "walked back in to z %.1f" % p.z)
	print("RESULT %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit()
