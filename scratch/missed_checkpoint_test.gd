extends Node
# Moves splitscreen player 1 along the racing line, a few metres a frame, through every gate's area
# but one, which it passes 16 m wide of. Prints every time the announcer says "checkpoint missed",
# and how far past the gate that was. One missed gate is allowed: the cart drives on, the gate after
# it counts and the lap is completed. Then it drives the wrong way for a few seconds ("wrong way"),
# and on lap two misses two gates in a row, which disqualifies it. Headless:
#   Godot --headless --path . res://scratch/missed_checkpoint_test.tscn -- [res://levels/X.tscn] [skip=2]
# skip=-1 drives a clean lap and must say nothing.

var heard: Array = []
var said := {}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var level_path := "res://levels/LakesideLevel.tscn"
	var skip := 2
	for a in args:
		if a.begins_with("skip="):
			skip = int(a.substr(5))
		elif a.begins_with("res://"):
			level_path = a
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.LOCAL_COOP
	NetworkManager.start_local_coop("P1", "P2")
	MusicManager.child_entered_tree.connect(func(n: Node):
		if n is AudioStreamPlayer and n.stream:
			var f: String = n.stream.resource_path.get_file()
			said[f] = int(said.get(f, 0)) + 1
			if f.begins_with("wrongway"):
				print("  said %s at %d ms" % [f, Time.get_ticks_msec()])
			if f == "checkpointmissed.mp3":
				heard.append(true))
	var level: Node = load(level_path).instantiate()
	add_child(level)
	while level.race_state != level.RaceState.RACING:
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout

	var cart: RigidBody3D = level.players_container.get_node("1")
	cart.freeze = true
	var curve: Curve3D = level.track_path.curve
	var length: float = curve.get_baked_length()
	var o0: float = curve.get_closest_offset(level.track_path.to_local(cart.global_position))
	var gates: Array = []
	for off in level.cp_offsets:
		gates.append(fmod(off - o0 + length, length))
	# The finish line is the lap's last gate, which the lap reaches after all the others.
	gates[gates.size() - 1] += length
	print("track %.0f m, %d gates at %s" % [length, gates.size(), str(gates.map(func(g): return roundi(g)))])
	var stats: Dictionary = level.player_stats[1]

	# Lap one: past gate `skip` the cart drives 16 m to the side, outside the gate's area (22 m wide).
	var step := 3.0
	var d := 0.0
	var missed_at := -1.0
	while d < gates[gates.size() - 1] + 30.0:
		d += step
		var wide := 16.0 if skip >= 0 and absf(d - gates[skip]) < 14.0 else 0.0
		_put(cart, level, curve, o0 + d, length, wide)
		await get_tree().process_frame
		if missed_at < 0.0 and not heard.is_empty():
			missed_at = d
			print("MISSED heard at %.0f m: gate %d is at %.0f m, so %.0f m past it; next expected %d" % [d, skip, gates[skip], d - gates[skip], stats["next_checkpoint_idx"]])
	print("lap one: said %d time(s) (want %d), next expected gate %d (want 0), laps %d (want 1), disqualified %s (want false)" % [heard.size(),
			1 if skip >= 0 else 0, stats["next_checkpoint_idx"], stats["laps"], str(stats.get("disqualified", false))])
	if skip < 0:
		get_tree().quit()
		return

	# The wrong way: back along the line at 15 m/s for 4 s.
	cart.freeze = false
	var t := 0.0
	var back := d
	while t < 4.0:
		var dt := get_process_delta_time()
		t += dt
		back -= 15.0 * dt
		_put(cart, level, curve, o0 + back, length)
		var o := fmod(o0 + back + length * 4.0, length)
		var along: Vector3 = level.track_path.to_global(curve.sample_baked(fmod(o + 1.0, length))) - level.track_path.to_global(curve.sample_baked(o))
		cart.linear_velocity = -along.normalized() * 15.0
		await get_tree().process_frame
	cart.freeze = true
	print("wrong way: said %d time(s) (want 1)" % (int(said.get("wrongway.mp3", 0)) + int(said.get("wrongway-2.mp3", 0))))

	# Lap two: two gates in a row missed, which disqualifies.
	heard.clear()
	var lap2 := length
	d = 0.0
	while d < gates[mini(skip + 1, gates.size() - 1)] + 30.0:
		d += step
		var wide2 := 16.0 if absf(d - gates[skip]) < 14.0 or absf(d - gates[mini(skip + 1, gates.size() - 1)]) < 14.0 else 0.0
		_put(cart, level, curve, o0 + lap2 + d, length, wide2)
		await get_tree().process_frame
	print("lap two: missed said %d time(s) (want 1), disqualified said %d (want 1), disqualified %s (want true)" % [heard.size(),
			int(said.get("disqualified.mp3", 0)), str(stats.get("disqualified", false))])
	get_tree().quit()


func _put(cart: Node3D, level: Node, curve: Curve3D, offset: float, length: float, aside: float = 0.0) -> void:
	var o := fmod(offset + length, length)
	var p := curve.sample_baked(o)
	var along := (curve.sample_baked(fmod(o + 1.0, length)) - p).normalized()
	var right := along.cross(Vector3.UP).normalized()
	cart.global_position = level.track_path.to_global(p + right * aside) + Vector3.UP * 0.8
	# Moving forward, as a cart driving there would (the wrong-way check reads the velocity).
	cart.linear_velocity = level.track_path.global_transform.basis * along * 20.0
