extends Node

# Drives a real cart straight across Freight Line's track off the road, to check the beds' collision (RailBed_*: a hump
# a cart's sphere rolls over): how high it hops, whether it sticks, how much speed it loses, what it stands on. Headless:
#   Godot --headless --path . res://scratch/track_cross_test.tscn -- [run=x,z,yaw_deg,run_up ...] [trace=1]
#       [hold=<train node>:<clock s>] [kills=1]
# It also counts the jolts RailRumble.gd gives the chassis over the rails and sleepers, and whether the cart was blown up.
# hold= holds a train at one clock reading (MainLineLocalTrain:120 stands it at the platform); kills=1 leaves the trains
# deadly (they are made harmless otherwise, to test the track alone).
# Each run drops the cart `run_up` metres back from (x, z) along its heading (yaw 0 = north, -z; 90 = west, -x) and
# drives it at full throttle through (x, z) and 25m on. Without runs it tries the Main Line fast and slow and both
# yard tracks by the station.

const CART_SCENE := preload("res://PlayerCart.tscn")

func _ready() -> void:
	var runs: Array = []
	var trace := false
	var holds := {}
	var keep_kills := false
	for a in OS.get_cmdline_user_args():
		if a == "trace=1":
			trace = true
		if a == "kills=1":
			keep_kills = true
		if a.begins_with("hold="):
			var hp := a.substr(5).split(":")
			holds[hp[0]] = float(hp[1])
		if a.begins_with("run="):
			var c := a.substr(4).split(",")
			runs.append([float(c[0]), float(c[1]), float(c[2]), float(c[3])])
	if runs.is_empty():
		runs = [[-300.0, 0.0, 0.0, 70.0], [-300.0, 0.0, 180.0, 12.0], [-250.0, 164.0, 180.0, 45.0], [600.0, 0.0, 0.0, 40.0]]
	Engine.physics_ticks_per_second = 60
	MusicManager.window_mode = 0
	AudioServer.set_bus_mute(0, true)
	var level: Node3D = load("res://levels/FreightLevel.tscn").instantiate()
	add_child(level)
	for ch in level.get_children():
		if "kills" in ch and not keep_kills:
			ch.kills = false
		if holds.has(String(ch.name)):
			ch.clock_override = holds[String(ch.name)]
	for i in 40:
		await get_tree().physics_frame
	var space := level.get_world_3d().direct_space_state
	for r in runs:
		var yaw: float = deg_to_rad(float(r[2]))
		var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var target := Vector3(float(r[0]), 0.0, float(r[1]))
		var start: Vector3 = target - fwd * float(r[3])
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(start + Vector3.UP * 300.0, start - Vector3.UP * 300.0))
		start.y = (hit.position.y if hit else 5.0) + 1.0
		var cart: RigidBody3D = CART_SCENE.instantiate()
		cart.name = "1"
		cart.transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), start)
		level.add_child(cart)
		for i in 5:
			await get_tree().physics_frame
		cart.set("is_landing", false)
		cart.set("can_move", true)
		cart.freeze = false
		Input.action_press("p1_throttle")
		var max_hop := 0.0
		var max_vy := 0.0
		var slow_time := 0.0
		var stuck := false
		var speed_in := 0.0
		var speed_out := 0.0
		var colliders := {}
		var jolts := 0
		var max_jolt := 0.0
		var last_jolt := Vector4.ZERO
		var blown := false
		var t := 0.0
		var travelled := 0.0
		var last := cart.global_position
		while travelled < float(r[3]) + 25.0 and t < 25.0:
			await get_tree().physics_frame
			t += 1.0 / 60.0
			var pos: Vector3 = cart.global_position
			var jv: Vector4 = cart.get("_jolt")
			if jv.y > last_jolt.y + 0.05:
				jolts += 1
			max_jolt = maxf(max_jolt, absf(jv.x))
			last_jolt = jv
			if cart.get("is_exploding"):
				blown = true
			travelled += Vector2(pos.x - last.x, pos.z - last.z).length()
			last = pos
			# Height over the ground under it (the terrain alone: the beds are what it rides).
			var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 30.0, pos - Vector3.UP * 30.0)
			q.exclude = [cart.get_rid()]
			var gh := space.intersect_ray(q)
			var along: float = (pos - target).dot(fwd)
			if gh:
				var nm: String = String((gh.collider as Node).name)
				if absf(along) < 12.0:
					colliders[nm] = true
					max_hop = maxf(max_hop, pos.y - gh.position.y)
			if absf(along) < 12.0:
				max_vy = maxf(max_vy, cart.linear_velocity.y)
				if trace and Engine.get_physics_frames() % 3 == 0:
					print("  along %.1f  y %.2f  over %.2f  vy %.1f  speed %.1f  on %s" % [along, pos.y, pos.y - (gh.position.y if gh else 0.0), cart.linear_velocity.y,
							cart.linear_velocity.length(), String((gh.collider as Node).name) if gh else "-"])
			if along < -8.0:
				speed_in = cart.linear_velocity.length()
			if along > 8.0 and speed_out == 0.0:
				speed_out = cart.linear_velocity.length()
			if cart.linear_velocity.length() < 1.0 and t > 1.5:
				slow_time += 1.0 / 60.0
				if slow_time > 2.0:
					stuck = true
					break
			else:
				slow_time = 0.0
		Input.action_release("p1_throttle")
		print("RUN through (%.0f, %.0f) heading %.0f from %.0fm: in %.1f m/s, out %.1f m/s, height over what it stands on up to %.2fm, rising up to %.1f m/s, %s, on %s; %d jolts (body up to %.3f)%s" % [
			float(r[0]), float(r[1]), float(r[2]), float(r[3]), speed_in, speed_out, max_hop, max_vy, "STUCK" if stuck else "through", ", ".join(colliders.keys()),
			jolts, max_jolt, ", BLOWN UP" if blown else ""])
		cart.queue_free()
		for i in 5:
			await get_tree().physics_frame
	get_tree().quit()
