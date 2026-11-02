extends Node
# Bloombay Dunes' boats and gulls at runtime (headless): each SeaBoat's speed and heading over a few
# seconds, whether its collision box rides with the hull, and which seagull calls each flock plays (clip,
# gain) over `seconds`. Godot --headless --path . res://scratch/sea_life_check.tscn -- [seconds=40]
func _ready() -> void:
	var seconds := 40.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seconds="):
			seconds = float(a.substr(8))
	var level: Node3D = load("res://levels/BloombayDunesLevel.tscn").instantiate()
	add_child(level)
	await get_tree().create_timer(1.0).timeout
	var boats := level.find_children("*", "Node3D", true, false).filter(func(n): return n.get_script() != null and n.get_script().resource_path == "res://SeaBoat.gd")
	var before := {}
	for b in boats:
		before[b] = (b.get("_hull") as Node3D).global_position
	var gulls := level.find_children("Flock*", "Node3D", true, false)
	var heard := {}
	var was_playing := {}
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()
		for g in gulls:
			var p: AudioStreamPlayer3D = g.get("_call_player")
			if p == null:
				continue
			if p.playing and not was_playing.get(g, false):
				heard[g] = heard.get(g, []) + ["%s@%.1fdB" % [p.stream.resource_path.get_file().get_basename(), p.volume_db]]
			was_playing[g] = p.playing
	for b in boats:
		var hull: Node3D = b.get("_hull")
		var body: Node3D = b.get("_body")
		var moved: Vector3 = hull.global_position - before[b]
		var fwd := hull.global_basis * Vector3.BACK
		print("BOAT %s at (%.0f, %.2f, %.0f) speed %.2f m/s heading-vs-travel %.2f body offset %.3f" % [b.name,
			hull.global_position.x, hull.global_position.y, hull.global_position.z, Vector2(moved.x, moved.z).length() / seconds,
			fwd.normalized().dot(moved.normalized()) if moved.length() > 0.5 else 0.0,
			body.global_position.distance_to(hull.global_position) if body else -1.0])
	for g in gulls:
		print("GULLS %s heard %s" % [g.name, heard.get(g, [])])
	get_tree().quit()
