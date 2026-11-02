extends Node

# Drops a real cart on Freight Line's lap and drives it at full throttle from a distance, printing its speed
# and what it stands on. Headless:
#   Godot --headless --path . res://scratch/freight_drive_test.tscn -- [from=1700] [seconds=14] [no_trains=1]

const CART_SCENE := preload("res://PlayerCart.tscn")

func _ready() -> void:
	var from_s := 1700.0
	var seconds := 14.0
	var no_trains := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("from="):
			from_s = float(a.substr(5))
		elif a.begins_with("seconds="):
			seconds = float(a.substr(8))
		elif a == "no_trains=1":
			no_trains = true
	Engine.physics_ticks_per_second = 60
	MusicManager.window_mode = 0
	AudioServer.set_bus_mute(0, true)
	var level: Node3D = load("res://levels/FreightLevel.tscn").instantiate()
	add_child(level)
	for ch in level.get_children():
		if no_trains and "kills" in ch:
			ch.kills = false
	for i in 30:
		await get_tree().physics_frame
	var curve: Curve3D = level.track_path.curve
	var p: Vector3 = curve.sample_baked(from_s)
	var q: Vector3 = curve.sample_baked(from_s + 3.0)
	var fwd: Vector3 = (q - p)
	fwd.y = 0.0
	fwd = fwd.normalized()
	var cart: RigidBody3D = CART_SCENE.instantiate()
	cart.name = "1"
	cart.transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), p + Vector3.UP * 1.0)
	level.add_child(cart)
	for i in 5:
		await get_tree().physics_frame
	cart.set("is_landing", false)
	cart.set("can_move", true)
	cart.freeze = false
	Input.action_press("p1_throttle")
	var t := 0.0
	var next := 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if t >= next:
			next += 0.5
			var gc = cart.ground_ray.get_collider() if cart.ground_ray.is_colliding() else null
			print("t=%.1f s=%.0f speed %.1f at (%.1f, %.1f, %.1f) on %s sleeping=%s" % [t, curve.get_closest_offset(curve.get_closest_point(cart.global_position)), cart.linear_velocity.length(), cart.global_position.x, cart.global_position.y, cart.global_position.z, gc.name if gc else "-", str(cart.sleeping)])
	get_tree().quit()
