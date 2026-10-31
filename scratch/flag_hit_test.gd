extends Node

# Coasts a real cart (no AI, no input) into one of a level's spring flags (SpringProps.gd) and logs what
# the hit does to it: its velocity just before and after the touch, how far aside of its line it is half
# a second and a second later, and whether the pole boinged. Headless, in a spectator race:
#   Godot --headless --fixed-fps 60 --path . res://scratch/flag_hit_test.tscn -- [level=res://levels/BloombayDunesLevel.tscn]
#       [props=Flags_chequered] [index=0] [speed=22] [aside=0.4]
# aside: how far right of the pole the cart's middle passes (negative: left).

func _ready() -> void:
	var level_path := "res://levels/BloombayDunesLevel.tscn"
	var filter := "Flags_chequered"
	var index := 0
	var speed := 22.0
	var aside := 0.4
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="): level_path = a.substr(6)
		elif a.begins_with("props="): filter = a.substr(6)
		elif a.begins_with("index="): index = int(a.substr(6))
		elif a.begins_with("speed="): speed = float(a.substr(6))
		elif a.begins_with("aside="): aside = float(a.substr(6))
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	var level: Node = load(level_path).instantiate()
	add_child(level)
	var t0 := Time.get_ticks_msec()
	while level.get("race_state") != 1 and Time.get_ticks_msec() - t0 < 60000:
		await get_tree().physics_frame
	for i in 30:
		await get_tree().physics_frame
	var props: MultiMeshInstance3D = null
	for n in level.find_children("*", "MultiMeshInstance3D", true, false):
		if filter in str(n.get_path()) and n.get_script() == load("res://SpringProps.gd"):
			props = n
			break
	if props == null:
		print("FAIL no SpringProps matching ", filter)
		get_tree().quit(1)
		return
	var foot: Vector3 = props.global_transform * props.rest[index].origin
	var carts := get_tree().get_nodes_in_group("player_carts")
	var cart: RigidBody3D = carts[0]
	for c in carts:
		if c != cart:
			(c as RigidBody3D).global_position += Vector3(0, 0, 4000)
	cart.set("is_ai", false)
	var dir := Vector3(1, 0, 0.25).normalized()
	var side := Vector3(-dir.z, 0, dir.x)
	var start: Vector3 = foot - dir * 18.0 + side * aside
	var q := PhysicsRayQueryParameters3D.create(start + Vector3.UP * 20.0, start - Vector3.UP * 20.0)
	q.exclude = [cart.get_rid()]
	var hit := cart.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		start.y = (hit["position"] as Vector3).y + 0.8
	cart.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), start)
	cart.linear_velocity = dir * speed
	print("PROP %s #%d at %s, cart passing %.1fm %s of it at %.0f m/s" % [props.name, index, foot, absf(aside), "right" if aside >= 0.0 else "left", speed])
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var prev_v := cart.linear_velocity
	var hit_t := -1.0
	var t := 0.0
	var boinged := false
	while t < 3.0:
		await get_tree().physics_frame
		t += dt
		var v := cart.linear_velocity
		var lat: float = (cart.global_position - foot).dot(side)
		if hit_t < 0.0 and Vector2(cart.global_position.x - foot.x, cart.global_position.z - foot.z).length() < float(props.get("reach")):
			hit_t = t
			print("TOUCH t=%.2f  before %s (%.1f m/s)  after %s (%.1f m/s)  sideways %+.1f m/s  up %+.1f m/s" % [t, prev_v.snapped(Vector3.ONE * 0.1), Vector2(prev_v.x, prev_v.z).length(),
					v.snapped(Vector3.ONE * 0.1), Vector2(v.x, v.z).length(), (v - prev_v).dot(side), v.y - prev_v.y])
		for pl in props.find_children("*", "AudioStreamPlayer3D", true, false):
			if (pl as AudioStreamPlayer3D).playing:
				boinged = true
		if hit_t > 0.0 and (absf(t - hit_t - 0.5) < dt * 0.5 or absf(t - hit_t - 1.0) < dt * 0.5):
			print("  +%.1fs: %.2fm %s of its line, %.1f m/s" % [t - hit_t, absf(lat - aside), "right" if lat - aside >= 0.0 else "left", Vector2(v.x, v.z).length()])
		prev_v = v
	print("BOING ", "yes" if boinged else "no")
	if hit_t < 0.0:
		print("FAIL the cart never reached the flag")
	get_tree().quit()
