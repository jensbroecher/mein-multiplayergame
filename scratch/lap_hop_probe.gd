extends Node

# Where carts hop "for no reason": drives the human's cart (a single-player GP, the car picked with car=) with the
# player's own input actions, flat out, `lat` metres to the right of the lap line (negative: left), from `from` metres
# along it for `seconds`, and lists every hop: a spell of physics frames off the ground (PlayerCart.was_on_ground false)
# whose clearance over the surface under it (a ray straight down, the cart excluded) rose more than `min` over its
# resting clearance. Each hop: where (s and the position), its peak, its length, the speed, the vertical speed it left
# with, and what it stood on just before. Jump lips (TrackPath's jump_lips) hop on purpose: they're marked.
#   Godot --headless --path . res://scratch/lap_hop_probe.tscn -- [level=res://levels/MarinaNightsLevel.tscn]
#       [car=16] [lat=0] [from=250] [seconds=12] [min=0.08] [cap=0]
# cap= holds the speed under that many m/s (0: flat out). A run in which the cart respawns stops there.

var level: Node
var cart: RigidBody3D
var curve: Curve3D
var length := 1.0


func _ready() -> void:
	var level_path := "res://levels/MarinaNightsLevel.tscn"
	var car := 16
	var lat := 0.0
	var from := 250.0
	var seconds := 12.0
	var min_hop := 0.08
	var cap := 0.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="): level_path = a.substr(6)
		elif a.begins_with("car="): car = int(a.substr(4))
		elif a.begins_with("lat="): lat = float(a.substr(4))
		elif a.begins_with("from="): from = float(a.substr(5))
		elif a.begins_with("seconds="): seconds = float(a.substr(8))
		elif a.begins_with("min="): min_hop = float(a.substr(4))
		elif a.begins_with("cap="): cap = float(a.substr(4))
	Engine.physics_ticks_per_second = 60
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SINGLE_PLAYER_GP
	NetworkManager.local_car_index = car
	NetworkManager.start_single_player("Tester")
	level = load(level_path).instantiate()
	add_child(level)
	while level.race_state != level.RaceState.RACING:
		await get_tree().process_frame
	cart = level.players_container.get_node("1")
	while not cart.can_move:
		await get_tree().physics_frame
	curve = level.track_path.curve
	length = curve.get_baked_length()
	# Start at `from`, on the line (or beside it), facing along it, at rest.
	var p0 := _target(from, lat)
	var p1 := _target(from + 2.0, lat)
	var fwd0 := (p1 - p0)
	fwd0.y = 0.0
	cart.global_position = p0 + Vector3(0, 1.5, 0)
	cart.linear_velocity = Vector3.ZERO
	cart.angular_velocity = Vector3.ZERO
	var vis: Node3D = cart.get_node("Visuals")
	vis.global_transform.basis = Basis.looking_at(fwd0.normalized(), Vector3.UP)
	for k in range(30):
		await get_tree().physics_frame
	var lips: Array = level.track_path.get_meta(&"jump_lips", []) if level.track_path.has_meta(&"jump_lips") else []
	print("car %d %s, lat %.1f from s %.0f for %.0fs%s" % [cart.car_index, cart.CAR_PRESETS[cart.car_index]["name"], lat, from, seconds,
			"" if cap <= 0.0 else ", held under %.0f m/s" % cap])
	var space := cart.get_world_3d().direct_space_state
	var rest := -1.0
	var rest_n := 0
	var t := 0.0
	var air := 0
	var peak := 0.0
	var hop_at := Vector3.ZERO
	var hop_s := 0.0
	var hop_speed := 0.0
	var hop_vy := 0.0
	var last_ground := "-"
	var hops := 0
	var top_speed := 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if cart.get("is_teleporting"):
			print("respawned at %.1fs: stopping" % t)
			break
		var pos: Vector3 = cart.global_position
		var off := curve.get_closest_offset(level.track_path.to_local(pos))
		var speed: float = cart.linear_velocity.length()
		top_speed = maxf(top_speed, speed)
		var tp := _target(off + 12.0 + speed * 0.5, lat)
		var fwd: Vector3 = -vis.global_transform.basis.z
		fwd.y = 0.0
		var to := tp - pos
		to.y = 0.0
		var steer := clampf(atan2(fwd.cross(to).y, fwd.dot(to)) * 1.6, -1.0, 1.0)
		_press("p1_steer_left", maxf(steer, 0.0))
		_press("p1_steer_right", maxf(-steer, 0.0))
		_press("p1_throttle", 0.0 if (cap > 0.0 and speed > cap) else 1.0)
		# The clearance over the surface straight down.
		var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.2, 0), pos + Vector3(0, -12.0, 0))
		q.exclude = [cart.get_rid()]
		var hit := space.intersect_ray(q)
		var clear: float = (pos.y - (hit["position"] as Vector3).y) if not hit.is_empty() else 99.0
		var grounded: bool = bool(cart.get("was_on_ground"))
		if grounded:
			var gr: RayCast3D = cart.get("ground_ray")
			if gr and gr.is_colliding() and gr.get_collider():
				last_ground = String((gr.get_collider() as Node).name)
			if t > 0.5 and rest_n < 120:
				rest = clear if rest < 0.0 else lerpf(rest, clear, 0.05)
				rest_n += 1
		if not grounded and rest > 0.0:
			if air == 0:
				hop_at = pos
				hop_s = off
				hop_speed = speed
				hop_vy = cart.linear_velocity.y
				peak = 0.0
			air += 1
			peak = maxf(peak, clear - rest)
		elif air > 0:
			if peak > min_hop:
				var lip := ""
				for l in lips:
					# A lip (WoodenRamp.lip_info: its point "lip") within 30m of where the hop began.
					if l is Dictionary and l.has("lip") and (l["lip"] as Vector3).distance_to(hop_at) < 30.0:
						lip = "  (jump lip %s)" % String(l.get("name", ""))
				hops += 1
				print("HOP s %6.1f at (%.1f, %.2f, %.1f): peak %.2fm, %d frames, %.1f m/s, left at vy %+.1f, from %s%s" % [hop_s, hop_at.x,
						hop_at.y, hop_at.z, peak, air, hop_speed, hop_vy, last_ground, lip])
			air = 0
	print("RESULT %d hops over %.0f m/s top speed, resting clearance %.2fm" % [hops, top_speed, rest])
	get_tree().quit()


func _press(action: String, strength: float) -> void:
	if strength > 0.01:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


## The point `off` metres along the lap, `lateral` to the right of the line.
func _target(off: float, lateral: float) -> Vector3:
	var o := fmod(off + length * 4.0, length)
	var p := curve.sample_baked(o)
	var along := (curve.sample_baked(fmod(o + 2.0, length)) - p).normalized()
	return level.track_path.to_global(p + along.cross(Vector3.UP).normalized() * lateral)
