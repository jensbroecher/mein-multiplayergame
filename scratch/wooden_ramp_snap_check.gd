extends SceneTree
## Checks WoodenRamp's drop onto the ground: puts a ramp a few metres over each of a level's ramps (and
## one off the road), presses Snap To Ground and prints where it landed against the saved ramp. Headless:
##   Godot --headless --path . -s res://scratch/wooden_ramp_snap_check.gd -- [level=res://levels/LakesideLevel.tscn] [lift=3]

func _init() -> void:
	var args := {"level": "res://levels/LakesideLevel.tscn", "lift": "3"}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var level: Node3D = (load(args["level"]) as PackedScene).instantiate()
	get_root().add_child(level)
	for i in range(4):
		await physics_frame
	var lift := float(args["lift"])
	for ramp in level.find_children("*", "StaticBody3D", true, false):
		if not (ramp is WoodenRamp):
			continue
		var probe := (load("res://WoodenRamp.tscn") as PackedScene).instantiate() as WoodenRamp
		probe.settle_on_track = false
		probe.face_lap = false
		probe.width = ramp.width
		probe.length = ramp.length
		probe.table_length = ramp.table_length
		probe.tail_length = ramp.tail_length
		level.add_child(probe)
		probe.global_transform = Transform3D(Basis(Vector3.UP, ramp.global_rotation.y), ramp.global_position + Vector3.UP * lift)
		await physics_frame
		probe.call("_on_snap_button_pressed")
		var d: Vector3 = probe.global_position - ramp.global_position
		var tilt := rad_to_deg(probe.global_transform.basis.y.angle_to(ramp.global_transform.basis.y))
		print("SNAP %-16s off saved by %s (%.3fm), up %.2f deg from saved" % [ramp.name, d, d.length(), tilt])
		probe.queue_free()
	quit()
