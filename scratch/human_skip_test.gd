extends Node

# Drives a real, non-AI cart (the human's, id 1, in a single-player GP) round the lap with the same input
# actions a player uses (throttle, steering), and takes it `aside` metres to the right of the lap line for
# `span` metres either side of a gate, so it passes outside the gate's area. Unlike
# missed_checkpoint_test (which moves the cart along the racing line a few metres a frame), this is the
# cart's own physics and a detour a person would drive: it shows what the server's racing-line tracking
# (Level._track_cart_curve_offset) and the announcer make of it. Prints when "checkpoint missed" is said
# and, at the end, which gate the lap thinks is next and whether the gates after the skipped one counted.
#   Godot --headless --path . res://scratch/human_skip_test.tscn -- [level=res://levels/LakesideLevel.tscn]
#       [skip=2] [aside=16] [span=30] [fade=40] [speed=22] [gates_after=2] [seconds=240] [reach=150]
# reach= sets Level.miss_track_reach (how far off the line the missed-gate watch follows the cart): a small
# one makes the watch lose the line, so only the fallback (reaching the next gate) can say the gate was missed.
# skip=-1 drives the lap clean. The 22m-wide gate areas mean aside above 11 skips the gate; a negative
# aside goes to the left of the line. A run in which the cart respawns (it drowned, stuck) stops and says
# so: the detour was not drivable there. The result line says how far off the line the cart got.

var heard := 0
var level: Node
var cart: RigidBody3D
var curve: Curve3D
var length := 1.0
var gate_off := 0.0


func _ready() -> void:
	var level_path := "res://levels/LakesideLevel.tscn"
	var skip := 2
	var aside := 16.0
	var span := 30.0
	var fade := 40.0
	var target_speed := 22.0
	var gates_after := 2
	var seconds := 240.0
	var reach := -1.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="): level_path = a.substr(6)
		elif a.begins_with("skip="): skip = int(a.substr(5))
		elif a.begins_with("aside="): aside = float(a.substr(6))
		elif a.begins_with("span="): span = float(a.substr(5))
		elif a.begins_with("fade="): fade = float(a.substr(5))
		elif a.begins_with("speed="): target_speed = float(a.substr(6))
		elif a.begins_with("gates_after="): gates_after = int(a.substr(12))
		elif a.begins_with("seconds="): seconds = float(a.substr(8))
		elif a.begins_with("reach="): reach = float(a.substr(6))
	Engine.physics_ticks_per_second = 60
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SINGLE_PLAYER_GP
	NetworkManager.start_single_player("Tester")
	MusicManager.child_entered_tree.connect(func(n: Node):
		if n is AudioStreamPlayer and n.stream and n.stream.resource_path.get_file() == "checkpointmissed.mp3":
			heard += 1
			print("  SAID checkpoint missed at %.1fs, next gate %s" % [_t, str(level.player_stats[1]["next_checkpoint_idx"])]))
	level = load(level_path).instantiate()
	add_child(level)
	if reach >= 0.0:
		level.miss_track_reach = reach
	while level.race_state != level.RaceState.RACING:
		await get_tree().process_frame
	cart = level.players_container.get_node("1")
	while not cart.can_move:
		await get_tree().physics_frame
	curve = level.track_path.curve
	length = curve.get_baked_length()
	var stats: Dictionary = level.player_stats[1]
	var gates: Array = level.cp_offsets
	print("track %.0f m, %d gates at %s; skipping gate %d by %.0f m (span %.0f)" % [length, gates.size(),
			str(gates.map(func(g): return roundi(g))), skip, aside, span])
	if skip >= 0:
		gate_off = gates[skip]
	var last_off := curve.get_closest_offset(level.track_path.to_local(cart.global_position))
	# Gate distances from where the cart starts; the finish line, the lap's last gate, comes after the rest.
	var rel: Array = gates.map(func(g: float) -> float: return fmod(g - last_off + length, length))
	rel[rel.size() - 1] += length
	var travelled := 0.0
	var next_log := 0.0
	var done_after := -1.0
	var respawns := 0
	var was_teleporting := false
	var max_lateral := 0.0
	while _t < seconds:
		await get_tree().physics_frame
		_t += 1.0 / 60.0
		if cart.get("is_teleporting"):
			if not was_teleporting:
				respawns += 1
			was_teleporting = true
			break
		was_teleporting = false
		var pos: Vector3 = cart.global_position
		var local: Vector3 = level.track_path.to_local(pos)
		var off := curve.get_closest_offset(local)
		max_lateral = maxf(max_lateral, Vector2(local.x - curve.sample_baked(off).x, local.z - curve.sample_baked(off).z).length())
		var step := fmod(off - last_off + length * 1.5, length) - length * 0.5
		if absf(step) < 60.0:
			travelled += step
		last_off = off
		var speed: float = cart.linear_velocity.length()
		var look := 10.0 + speed * 0.5
		var tp := _target(off + look, skip, aside, span, fade)
		var fwd: Vector3 = -cart.get_node("Visuals").global_transform.basis.z
		fwd.y = 0.0
		var to := tp - pos
		to.y = 0.0
		var ang := atan2(fwd.cross(to).y, fwd.dot(to))
		var steer := clampf(ang * 1.6, -1.0, 1.0)
		_press("p1_steer_left", maxf(steer, 0.0))
		_press("p1_steer_right", maxf(-steer, 0.0))
		_press("p1_throttle", 1.0 if speed < target_speed else 0.0)
		_press("p1_brake", 0.6 if speed > target_speed + 8.0 else 0.0)
		if _t >= next_log:
			next_log = _t + 5.0
			print("t=%5.1f off %6.0f (lap %+.0f) speed %4.1f next gate %d path_off %.0f laps %d  missed_run %s" % [_t, off, travelled, speed,
					stats["next_checkpoint_idx"], float(stats.get("path_off", -1.0)), stats["laps"], str(stats.get("missed_run", 0))])
		# Stop `gates_after` gates after the skipped one (or one gate in, when driving clean).
		var stop_gate: int = (skip if skip >= 0 else 0) + gates_after
		if stop_gate < gates.size() and travelled > rel[stop_gate] + 40.0 and done_after < 0.0:
			done_after = _t
		if done_after > 0.0 and _t > done_after + 1.0:
			break
	var want_next := (skip + gates_after + 1) % gates.size() if skip >= 0 else (gates_after + 1) % gates.size()
	var verdict := "INVALID (respawned: %d)" % respawns if respawns > 0 else ("PASS" if heard == (1 if skip >= 0 and absf(aside) > 11.0 else 0) and stats["next_checkpoint_idx"] == want_next else "FAIL")
	print("RESULT %s: aside %.0f reached %.0f m off the line; said %d time(s) (want %d); next gate %d (want %d); laps %d; disqualified %s; clock %.0fs" % [
			verdict, aside, max_lateral, heard, 1 if skip >= 0 and absf(aside) > 11.0 else 0, stats["next_checkpoint_idx"], want_next, stats["laps"],
			str(stats.get("disqualified", false)), _t])
	_press("p1_steer_left", 0.0)
	_press("p1_steer_right", 0.0)
	_press("p1_throttle", 0.0)
	get_tree().quit()


var _t := 0.0


func _press(action: String, strength: float) -> void:
	if strength > 0.01:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


## The point `off` metres along the lap, `aside` to the right of the line while within `span` of the
## skipped gate (fading out over `fade` either side).
func _target(off: float, skip: int, aside: float, span: float, fade: float) -> Vector3:
	var o := fmod(off + length * 4.0, length)
	var p := curve.sample_baked(o)
	var along := (curve.sample_baked(fmod(o + 2.0, length)) - p).normalized()
	var right := along.cross(Vector3.UP).normalized()
	var lateral := 0.0
	if skip >= 0:
		var d := absf(fmod(o - gate_off + length * 1.5, length) - length * 0.5)
		lateral = aside * clampf(1.0 - (d - span) / maxf(fade, 1.0), 0.0, 1.0)
	return level.track_path.to_global(p + right * lateral)
