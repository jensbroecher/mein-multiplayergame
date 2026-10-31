extends Node

# Races the AI on a level with an eagle (the Canyon Course) headless and measures how smoothly the eagle
# takes carts: for each hunt, the carried cart's (and the eagle's) biggest step in one physics tick and its
# biggest acceleration, from the swoop (GRAB) through the carry to half a second after the drop. A jump or a
# snap shows as an acceleration in the thousands of m/s^2; a smooth lift stays under about 100.
#   Godot --headless --fixed-fps 60 --path . res://scratch/eagle_carry_test.tscn -- [level=res://levels/CanyonLevel.tscn]
#       [seconds=150] [trace=1]
# shots=<dir> (windowed, without --headless): photographs the first carry from beside it, at the grab and
# 0.25s, 0.75s and 1.5s into the lift.

const PHASES := ["PATROL", "DIVE", "GRAB", "CARRY", "RELEASE", "COOLDOWN"]

func _ready() -> void:
	var level_path := "res://levels/CanyonLevel.tscn"
	var seconds := 150.0
	var trace := false
	var shots := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="):
			level_path = a.substr(6)
		elif a.begins_with("seconds="):
			seconds = float(a.substr(8))
		elif a == "trace=1":
			trace = true
		elif a.begins_with("shots="):
			shots = a.substr(6)
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	var level: Node = load(level_path).instantiate()
	var eagle: Node3D = level.get_node_or_null("Eagle")
	if eagle == null:
		print("FAIL no eagle in ", level_path)
		get_tree().quit(1)
		return
	eagle.hunt_start_delay = 0.0
	eagle.cooldown_time = 3.0
	add_child(level)
	print("EAGLE scale %.2f" % eagle.global_basis.get_scale().x)
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var t := 0.0
	var hunt := 0
	var cart: Node3D = null
	var pts: Array = []
	var epts: Array = []
	var phs: Array = []
	var carry_ticks := 0
	var after := 0.0
	var log_lines: Array = []
	var results: Array = []
	while t < seconds:
		await get_tree().physics_frame
		t += dt
		var ph: int = eagle._phase
		var tc: Node3D = eagle._target_cart
		if cart == null and (ph == 2 or ph == 3) and tc != null:
			cart = tc
			hunt += 1
			pts = []
			epts = []
			phs = []
			after = 0.0
			log_lines = []
		if cart == null:
			continue
		if not is_instance_valid(cart):
			cart = null
			continue
		pts.append(cart.global_position)
		epts.append(eagle.global_position)
		phs.append(ph)
		if shots != "" and hunt == 1 and ph == 3:
			carry_ticks += 1
			if carry_ticks in [1, 15, 45, 90]:
				await _shoot(shots, "carry_%02d" % carry_ticks, cart, eagle)
		if trace:
			log_lines.append("  %.2f %s cart %s eagle %s" % [t, PHASES[ph], cart.global_position, eagle.global_position])
		if ph != 2 and ph != 3:
			after += dt
			if after >= 0.5:
				results.append(_report(hunt, cart.name, pts, epts, phs, dt))
				if trace:
					for l in log_lines:
						print(l)
				cart = null
	print("HUNTS %d" % results.size())
	for r in results:
		print(r)
	get_tree().quit()


func _shoot(dir: String, nm: String, cart: Node3D, eagle: Node3D) -> void:
	var cam := get_viewport().get_camera_3d()
	var own := Camera3D.new()
	own.far = 3000.0
	own.fov = 50.0
	add_child(own)
	var mid: Vector3 = (cart.global_position + eagle.global_position) * 0.5
	var side: Vector3 = eagle._last_flat_fwd.cross(Vector3.UP).normalized()
	own.global_position = mid + side * 16.0 + Vector3.UP * 2.0
	own.look_at(mid, Vector3.UP)
	own.make_current()
	var was := Engine.time_scale
	Engine.time_scale = 0.0
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, nm])
	print("SHOT ", nm)
	Engine.time_scale = was
	own.queue_free()
	if cam:
		cam.make_current()


func _report(hunt: int, nm: String, pts: Array, epts: Array, phs: Array, dt: float) -> String:
	var out := "HUNT %d cart %s: %d ticks" % [hunt, nm, pts.size()]
	for who in [["cart", pts], ["eagle", epts]]:
		for want in [2, 3]:
			var r: Array = _stats(who[1], phs, want, dt)
			out += "\n    %s in %s: max step %.2fm, max accel %.0f m/s2 at tick %d of the phase" % [who[0], PHASES[want], r[0], r[1], r[2]]
	return out


## In phase `want`, the biggest step in one tick and the biggest acceleration (second difference), and the
## tick of the phase it came at.
func _stats(p: Array, phs: Array, want: int, dt: float) -> Array:
	var step := 0.0
	var acc := 0.0
	var at := -1
	var k := 0
	for i in range(2, p.size()):
		if int(phs[i]) != want or int(phs[i - 1]) != want or int(phs[i - 2]) != want:
			continue
		k += 1
		step = maxf(step, (p[i] as Vector3).distance_to(p[i - 1]))
		var a: float = ((p[i] as Vector3) - 2.0 * (p[i - 1] as Vector3) + (p[i - 2] as Vector3)).length() / (dt * dt)
		if a > acc:
			acc = a
			at = k
	return [step, acc, at]
