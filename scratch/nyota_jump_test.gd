extends Node

# Nyota Stadium: drives a real PlayerCart over every jump (TrackPath's "jump_lips" meta) with its
# top speed capped at each of SPEEDS, and prints for each run the airtime, how far past the lip it
# first came down, the height it reached over the lip, and the speed it kept a second later.
#   Godot --headless --path . res://scratch/nyota_jump_test.tscn [-- speeds=30,36,40 only=Triple]
# The node's name holds "regenerate" so Level.gd skips its race setup (no UI, no grid).

const CART_SCENE := preload("res://PlayerCart.tscn")
var speeds: Array[float] = [30.0, 36.0, 40.0]
var only := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("speeds="):
			speeds.clear()
			for v in a.substr(7).split(","):
				speeds.append(float(v))
		elif a.begins_with("only="):
			only = a.substr(5)
	Engine.physics_ticks_per_second = 60
	AudioServer.set_bus_mute(0, true)
	var level: Node3D = load("res://levels/NyotaStadiumLevel.tscn").instantiate()
	add_child(level)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var lips: Array = level.get_node("TrackPath").get_meta(&"jump_lips")
	for lip in lips:
		if only != "" and lip["name"] != only:
			continue
		var line := ""
		for v in speeds:
			var r: Dictionary = await _run(level, lip, v)
			line += "  %d: air %.2fs land %+.1fm peak %.1fm keep %.0f%s" % [int(v), r.air, r.land, r.peak, r.keep, "" if r.ok else " STUCK"]
		print("JUMP %-16s%s" % [lip["name"], line])
	get_tree().quit()


func _run(level: Node3D, lip: Dictionary, v: float) -> Dictionary:
	var p: Vector3 = lip["lip"]
	var d: Vector3 = lip["dir"]
	var start: Vector3 = p - d * 30.0
	# Down onto the surface under the start.
	var space := level.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(start + Vector3.UP * 30.0, start - Vector3.UP * 30.0)
	var hit := space.intersect_ray(q)
	if hit:
		start.y = hit.position.y + 0.9
	var cart: RigidBody3D = CART_SCENE.instantiate()
	cart.name = "1"
	level.get_node("Players").add_child(cart)
	cart.global_position = start
	cart.get_node("Visuals").global_rotation = Vector3(0, atan2(-d.x, -d.z), 0)
	for i in 3:
		await get_tree().physics_frame
	cart.set("is_landing", false)
	cart.set("can_move", true)
	cart.set("max_speed", v)
	cart.freeze = false
	cart.linear_velocity = d * v
	Input.action_press("p1_throttle")
	var air := 0.0
	var max_air := 0.0
	var land := NAN
	var peak := -INF
	var passed := false
	var keep := 0.0
	var t_land := -1.0
	var t := 0.0
	var ok := true
	while t < 6.0:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		var cp: Vector3 = cart.global_position
		var along: float = (cp - p).dot(d)
		if along > 0.0:
			passed = true
			peak = maxf(peak, cp.y - p.y - 0.45)
		var on_ground: bool = cart.get("is_on_ground")
		if passed and not on_ground:
			air += 1.0 / 60.0
		elif passed and on_ground and air > 0.15 and is_nan(land):
			land = along
			max_air = air
			t_land = t
		if t_land > 0.0 and t - t_land >= 1.0:
			keep = cart.linear_velocity.length() / v * 100.0
			break
	if is_nan(land):
		ok = false
		land = 0.0
	Input.action_release("p1_throttle")
	cart.queue_free()
	await get_tree().physics_frame
	return {"air": max_air if max_air > 0.0 else air, "land": land, "peak": peak, "keep": keep, "ok": ok}
