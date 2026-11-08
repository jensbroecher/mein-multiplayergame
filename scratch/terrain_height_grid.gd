extends SceneTree
## Prints a saved level's terrain heights on a coarse grid, with the lap marked, for planning dressing (headless):
##   Godot --headless --path . -s res://scratch/terrain_height_grid.gd -- <level.tscn> [cell=50] [half=450]
## Each cell shows the ground's height (whole metres, the highest vertex of the terrain mesh in the cell), '##' where
## the TrackPath passes within the cell, '~~' where there is no terrain vertex (past the disc's rim). Rows are z
## (north, -z, at the top), columns x.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var level_path := args[0]
	var cell := 50.0
	var half := 450.0
	for a in args.slice(1):
		if a.begins_with("cell="):
			cell = float(a.substr(5))
		elif a.begins_with("half="):
			half = float(a.substr(5))
	var level: Node = (load(level_path) as PackedScene).instantiate()
	var tv := level.find_child("Terrain_Visual", true, false) as MeshInstance3D
	var n := int(ceil(2.0 * half / cell))
	var hmax := {}
	if tv and tv.mesh:
		for s in tv.mesh.get_surface_count():
			var verts: PackedVector3Array = tv.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for v in verts:
				var p: Vector3 = tv.global_transform * v if tv.is_inside_tree() else tv.transform * v
				var ix := int(floor((p.x + half) / cell))
				var iz := int(floor((p.z + half) / cell))
				if ix < 0 or iz < 0 or ix >= n or iz >= n:
					continue
				var k := iz * n + ix
				hmax[k] = maxf(hmax.get(k, -1e9), p.y)
	var lap := {}
	var tp := level.find_child("TrackPath", true, false) as Path3D
	if tp:
		var c := tp.curve
		var L := c.get_baked_length()
		var d := 0.0
		while d < L:
			var p := c.sample_baked(d)
			lap[int(floor((p.z + half) / cell)) * n + int(floor((p.x + half) / cell))] = true
			d += 2.0
	var head := "      "
	for ix in n:
		head += "%5d" % int(-half + (ix + 0.5) * cell)
	print(head)
	for iz in n:
		var row := "%5d " % int(-half + (iz + 0.5) * cell)
		for ix in n:
			var k := iz * n + ix
			if lap.has(k):
				row += "   ##"
			elif hmax.has(k):
				row += "%5d" % int(round(hmax[k]))
			else:
				row += "   ~~"
		print(row)
	level.free()
	quit()
