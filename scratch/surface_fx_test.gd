extends Node

# Races the AI round a level and tallies, per surface the carts drive on (Surfaces.gd), how long
# they spent there and what the wheels did: skid marks (paved only), smoke, dust, grit, the sliding
# loop. Ends with the skid-mark segments laid. Headless:
#   Godot --headless --path . res://scratch/surface_fx_test.tscn -- res://levels/X.tscn [seconds=60] [speed=2]

const Surfaces = preload("res://Surfaces.gd")

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var level_path: String = args[0]
	var seconds := 60.0
	var speed := 2.0
	for a in args:
		if a.begins_with("seconds="):
			seconds = float(a.substr(8))
		elif a.begins_with("speed="):
			speed = float(a.substr(6))
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	var level: Node = load(level_path).instantiate()
	add_child(level)
	Engine.time_scale = speed
	var stats := {}
	var t := 0.0
	var frames := 0
	while t < seconds:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		for c in get_tree().get_nodes_in_group("player_carts"):
			if not c.is_on_ground:
				continue
			var s: int = c.surface
			if not stats.has(s):
				stats[s] = {"frames": 0, "track": 0, "marks": 0, "smoke": 0, "dust": 0, "grit": 0, "sound": 0, "slide": 0}
			var st: Dictionary = stats[s]
			st["frames"] += 1
			if not c.is_offroad:
				st["track"] += 1
			if c._is_skid_active:
				st["marks"] += 1
			if c._skid_amount > 0.25:
				st["slide"] += 1
			for p in c.drift_particles:
				if p.emitting:
					st["smoke"] += 1
					break
			if c._is_dust_active:
				st["dust"] += 1
			for g in c.grit_particles:
				if g.emitting:
					st["grit"] += 1
					break
			for ap in c._sfx_surface:
				if ap.playing:
					st["sound"] += 1
					break
		frames += 1
	print("=== %s, %.0fs ===" % [level_path.get_file(), seconds])
	for c in get_tree().get_nodes_in_group("player_carts"):
		if not c._trail_particles_ready:
			print("  (%s: trail particles never primed, so no marks or spray: headless?)" % c.name)
			break
	for s in stats:
		var st: Dictionary = stats[s]
		var f: float = maxf(float(st["frames"]), 1.0)
		print("  %-8s %6d frames  track %3.0f%%  sliding %3.0f%%  marks %3.0f%%  smoke %3.0f%%  dust %3.0f%%  grit %3.0f%%  sound %3.0f%%" % [
			Surfaces.NAMES[s], st["frames"], 100.0 * st["track"] / f, 100.0 * st["slide"] / f, 100.0 * st["marks"] / f,
			100.0 * st["smoke"] / f, 100.0 * st["dust"] / f, 100.0 * st["grit"] / f, 100.0 * st["sound"] / f])
	var marks: Node = level.get_node_or_null("SkidMarks")
	print("  skid mark segments laid: %d" % (marks._used if marks else 0))
	get_tree().quit()
