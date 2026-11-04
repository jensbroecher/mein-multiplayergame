extends Node

# Drives a real cart at each of a level's return jumps (nodes "ReturnJump_*", WoodenRamps outside the street
# barriers) and reports whether it came down on the road: how far it ended from the lap's line in plan, its
# height against the line's and its speed. Headless:
#   Godot --headless --path . res://scratch/return_jump_test.tscn [-- level=res://levels/NyotaStadiumLevel.tscn speeds=12,16,22 only=Market]
# PASS when the cart first comes down past the lip (after 0.15s or more in the air) inside the barriers (8.3m from
# the line), near the road's height. `off`/`dy` are that landing; it is driven straight on, so where it ends up isn't judged.
# The node's name holds "regenerate" so Level.gd skips its race setup.

const CART_SCENE := preload("res://PlayerCart.tscn")


func _ready() -> void:
	var level_path := "res://levels/NyotaStadiumLevel.tscn"
	var speeds: Array[float] = [12.0, 16.0, 22.0]
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="):
			level_path = a.substr(6)
		elif a.begins_with("speeds="):
			speeds.clear()
			for v in a.substr(7).split(","):
				speeds.append(float(v))
		elif a.begins_with("only="):
			only = a.substr(5)
	Engine.physics_ticks_per_second = 60
	AudioServer.set_bus_mute(0, true)
	var level: Node3D = load(level_path).instantiate()
	add_child(level)
	for i in 30:
		await get_tree().physics_frame
	var curve: Curve3D = (level.get_node("TrackPath") as Path3D).curve
	var fails := 0
	for ramp in level.find_children("ReturnJump_*", "", true, false):
		if only != "" and not String(ramp.name).ends_with(only):
			continue
		var r := ramp as Node3D
		var dir: Vector3 = -r.global_basis.z
		dir.y = 0.0
		dir = dir.normalized()
		var line := ""
		for v in speeds:
			var res: Dictionary = await _run(level, r, dir, v, curve)
			line += "  %d m/s: %s off %.1fm dy %+.1f speed %.0f" % [int(v), "PASS" if res.ok else "FAIL", res.off, res.dy, res.speed]
			if not res.ok:
				fails += 1
		print("RETURN %-28s%s" % [ramp.name, line])
	print("RETURN fails: %d" % fails)
	get_tree().quit()


func _run(level: Node3D, ramp: Node3D, dir: Vector3, v: float, curve: Curve3D) -> Dictionary:
	var start: Vector3 = ramp.global_position - dir * 18.0 + Vector3.UP * 1.0
	var cart: RigidBody3D = CART_SCENE.instantiate()
	cart.name = "1"
	level.get_node("Players").add_child(cart)
	cart.global_position = start
	cart.get_node("Visuals").global_rotation = Vector3(0, atan2(-dir.x, -dir.z), 0)
	for i in 3:
		await get_tree().physics_frame
	cart.set("is_landing", false)
	cart.set("can_move", true)
	cart.set("max_speed", v)
	cart.freeze = false
	cart.linear_velocity = dir * v
	Input.action_press("p1_throttle")
	var t := 0.0
	var air := 0.0
	var land := Vector3.INF
	while t < 2.6 and land == Vector3.INF:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if not cart.get("is_on_ground"):
			air += 1.0 / 60.0
		elif air > 0.15 and (cart.global_position - ramp.global_position).dot(dir) > float(ramp.get("length")):
			land = cart.global_position
		else:
			air = 0.0
	Input.action_release("p1_throttle")
	var p: Vector3 = cart.global_position if land == Vector3.INF else land
	var near: Vector3 = curve.get_closest_point(p)
	var off: float = Vector2(p.x - near.x, p.z - near.z).length()
	var dy: float = p.y - near.y
	var speed: float = cart.linear_velocity.length()
	cart.queue_free()
	await get_tree().physics_frame
	return {"ok": land != Vector3.INF and off < 8.3 and absf(dy) < 2.0, "off": off, "dy": dy, "speed": speed}
