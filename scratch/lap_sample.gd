extends SceneTree

# Prints a level's lap (TrackPath) between two distances: position, heading (degrees, 0 = -z, turning
# right is positive) and the turn since the last sample. Reads the saved scene, no level script runs.
#   Godot --headless --path . -s res://scratch/lap_sample.gd -- <level.tscn> <s0> <s1> [step=10]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var state: SceneState = (load(args[0]) as PackedScene).get_state()
	var curve: Curve3D = null
	for i in state.get_node_count():
		if String(state.get_node_name(i)) == "TrackPath":
			for p in state.get_node_property_count(i):
				if state.get_node_property_name(i, p) == &"curve":
					curve = state.get_node_property_value(i, p)
	var s0 := float(args[1])
	var s1 := float(args[2])
	var step := 10.0
	for a in args.slice(3):
		if a.begins_with("step="):
			step = float(a.substr(5))
	var length := curve.get_baked_length()
	var prev := NAN
	var s := s0
	while s <= s1 + 0.01:
		var ss := fposmod(s, length)
		var p := curve.sample_baked(ss)
		var f := curve.sample_baked(fposmod(ss + 0.5, length)) - curve.sample_baked(fposmod(ss - 0.5, length))
		var hdg := rad_to_deg(atan2(f.x, -f.z))
		var turn := 0.0 if is_nan(prev) else wrapf(hdg - prev, -180.0, 180.0)
		print("s=%6.0f  (%7.1f, %5.1f, %7.1f)  heading %6.1f  turn %+5.1f" % [s, p.x, p.y, p.z, hdg, turn])
		prev = hdg
		s += step
	quit()
