extends SceneTree
## Every MultiMesh instance (plants, rocks, grass) of a level standing within `half` of a lap path's line in plan (the
## TrackPath and the AlternativePaths), with its MultiMesh, its distance and the lap distance: what grows through the
## road. Reads the instances from multimesh.buffer (works headless). Headless:
##   Godot --headless --path . -s res://scratch/flora_on_road.gd -- res://levels/X.tscn [half=7.5]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var half := 7.5
	for a in args.slice(1):
		if a.begins_with("half="):
			half = float(a.substr(5))
	var root: Node3D = (load(args[0]) as PackedScene).instantiate()
	get_root().add_child(root)
	await process_frame
	var paths: Array = [root.get_node("TrackPath")]
	var alt := root.get_node_or_null("AlternativePaths")
	if alt:
		for c in alt.get_children():
			if c is Path3D:
				paths.append(c)
	# The lines in plan, sampled every 2m, in a 16m grid for lookups.
	var grid := {}
	for p in paths:
		var path := p as Path3D
		var c := path.curve
		var L := c.get_baked_length()
		var s := 0.0
		while s < L:
			var q: Vector3 = path.global_transform * c.sample_baked(s)
			var k := Vector2i(floori(q.x / 16.0), floori(q.z / 16.0))
			if not grid.has(k):
				grid[k] = []
			grid[k].append([Vector2(q.x, q.z), s, path.name])
			s += 2.0
	var hits := 0
	for n in root.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := n as MultiMeshInstance3D
		var mm := mmi.multimesh
		if mm == null or mm.instance_count == 0:
			continue
		var buf := mm.buffer
		var stride: int = buf.size() / mm.instance_count
		for i in range(mm.instance_count):
			var o: int = i * stride
			var w: Vector3 = mmi.global_transform * Vector3(buf[o + 3], buf[o + 7], buf[o + 11])
			var k := Vector2i(floori(w.x / 16.0), floori(w.z / 16.0))
			var best := 1e9
			var best_s := 0.0
			var best_p := ""
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					for e in grid.get(k + Vector2i(dx, dz), []):
						var d: float = (e[0] as Vector2).distance_to(Vector2(w.x, w.z))
						if d < best:
							best = d
							best_s = e[1]
							best_p = e[2]
			if best < half:
				hits += 1
				print("%s #%d at (%.1f, %.1f, %.1f): %.1fm from %s's line at s %.0f" % [root.get_path_to(mmi), i, w.x, w.y, w.z, best, best_p, best_s])
	print("%d instances within %.1fm of a lap path" % [hits, half])
	quit()
