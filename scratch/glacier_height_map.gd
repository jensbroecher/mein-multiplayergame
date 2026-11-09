extends Node

# Prints Glacier Highway's natural ground (regenerate_glacier_highway.gd's _alpine_height, before the roads are graded
# in) on a coarse grid with the lap ('##') and the ramps ('++') marked, for placing dressing. Headless (a scene, since the
# level's scripts need the autoloads):
#   Godot --headless --path . res://scratch/glacier_height_map.tscn -- [cell=40] [x0=-560 x1=560 z0=-1200 z1=560]

func _ready() -> void:
	var cell := 40.0
	var x0 := -560.0
	var x1 := 560.0
	var z0 := -1200.0
	var z1 := 560.0
	for a in OS.get_cmdline_user_args():
		var kv := (a as String).split("=")
		if kv.size() == 2:
			match kv[0]:
				"cell": cell = float(kv[1])
				"x0": x0 = float(kv[1])
				"x1": x1 = float(kv[1])
				"z0": z0 = float(kv[1])
				"z1": z1 = float(kv[1])
	var gen = load("res://regenerate_glacier_highway.gd").new()
	gen.call("_init_noise")
	var level: Node3D = load("res://levels/GlacierHighwayLevel.tscn").instantiate()
	var marks := {}
	var paths: Array = [[level.get_node("TrackPath"), "##"]]
	for p in level.get_node("AlternativePaths").get_children():
		paths.append([p, "++"])
	for entry in paths:
		var c: Curve3D = (entry[0] as Path3D).curve
		var L := c.get_baked_length()
		var s := 0.0
		while s < L:
			var q: Vector3 = c.sample_baked(s)
			var k := Vector2i(int(floor((q.x - x0) / cell)), int(floor((q.z - z0) / cell)))
			if not marks.has(k) or entry[1] == "##":
				marks[k] = entry[1]
			s += 4.0
	var head := "      "
	var x := x0
	while x < x1:
		head += "%5d" % int(x)
		x += cell
	print(head)
	var z := z0
	while z < z1:
		var line := "%5d " % int(z)
		x = x0
		while x < x1:
			var k := Vector2i(int(floor((x - x0) / cell)), int(floor((z - z0) / cell)))
			if marks.has(k):
				line += "   " + str(marks[k])
			else:
				line += "%5d" % int(round(gen.call("_alpine_height", x + cell * 0.5, z + cell * 0.5)))
			x += cell
		print(line)
		z += cell
	level.free()
	gen.free()
	get_tree().quit()
