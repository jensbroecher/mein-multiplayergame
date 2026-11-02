extends Node

# Test script to verify track rattle and flip mechanics on Freight Line
const CART_SCENE := preload("res://PlayerCart.tscn")

func _ready() -> void:
	Engine.physics_ticks_per_second = 60
	MusicManager.window_mode = 0
	AudioServer.set_bus_mute(0, true)
	var level: Node3D = load("res://levels/FreightLevel.tscn").instantiate()
	add_child(level)

	# Stop trains so they don't interfere
	for ch in level.get_children():
		if "kills" in ch:
			ch.kills = false

	for i in 25:
		await get_tree().physics_frame

	# Place cart directly on Main Line tracks at z ~ 3.5 (where track is)
	# Main line is roughly east-west at y=0, z=0
	var cart: RigidBody3D = CART_SCENE.instantiate()
	cart.name = "1"
	# Let's find a point on the track from RailRumble lines
	var rr = level.get_node_or_null("RailRumble")
	print("RailRumble node: ", rr, " script: ", rr.get_script() if rr else "null")
	var line_pts := PackedVector3Array()
	if rr and "lines" in rr and rr.lines.size() > 0:
		line_pts = rr.lines[0]
	else:
		line_pts = PackedVector3Array([Vector3(-700, 4.0, 0), Vector3(-600, 4.0, 0)])
	var p0 = line_pts[0]
	var p1 = line_pts[1]
	var dir = (p1 - p0).normalized()

	cart.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), p0 + Vector3.UP * 0.8)
	level.add_child(cart)

	for i in 5:
		await get_tree().physics_frame

	cart.set("is_landing", false)
	cart.set("can_move", true)
	cart.freeze = false

	# Push cart forward at high speed (30 m/s) along track
	cart.linear_velocity = dir * 30.0

	var flipped := false
	for step in range(120): # 2 seconds
		await get_tree().physics_frame
		var cur_up = cart.visuals.global_transform.basis.y
		var speed = cart.linear_velocity.length()
		var y_pos = cart.global_position.y
		if cur_up.y < 0.2:
			flipped = true
		if step % 15 == 0:
			print("step=%d speed=%.1f y=%.2f up_y=%.2f flipped=%s" % [step, speed, y_pos, cur_up.y, flipped])

	print("Final result: flipped=%s" % flipped)
	get_tree().quit()
