extends SceneTree

# Scans a level's saved terrain meshes (TerrainGenerator's grid) for steps: neighbouring vertices whose
# height differs by more than `step` metres, the way a hard switch in the height function shows (a
# pond cut by a straight wall). Prints them clustered into 20m cells, the largest first:
#   Godot --headless --path . -s res://scratch/terrain_step_scan.gd -- [level=res://levels/BloombayDunesLevel.tscn] [step=1.5]
#       [shore=1 (only steps across the water's edge)] [column=x,z0,z1] [row=z,x0,x1] (also print the heights down a column or along a row)


func _init() -> void:
	var level_path := "res://levels/BloombayDunesLevel.tscn"
	var step := 1.5
	var shore := false
	for a in OS.get_cmdline_user_args():
		if a == "shore=1": shore = true
		if a.begins_with("level="): level_path = a.substr(6)
		elif a.begins_with("step="): step = float(a.substr(5))
	var level: Node = (load(level_path) as PackedScene).instantiate()
	var tg: Node = level.get_node("TerrainGenerator")
	var size: Vector2 = tg.get("terrain_size")
	var res: int = tg.get("terrain_resolution")
	var cell := size.x / res
	var start := -size.x * 0.5
	var grid := {}
	var stack: Array = [tg]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null or not String(mi.name).to_lower().contains("terrain"):
			continue
		for si in mi.mesh.get_surface_count():
			var verts: PackedVector3Array = mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
			for v in verts:
				var w: Vector3 = mi.transform * v
				grid[Vector2i(roundi((w.x - start) / cell), roundi((w.z - start) / cell))] = w.y
	print("%d terrain vertices" % grid.size())
	for a in OS.get_cmdline_user_args():
		if a.begins_with("column="):
			# column=x,z0,z1: the heights down a column of the grid.
			var c := a.substr(7).split(",")
			var i := roundi((float(c[0]) - start) / cell)
			var line := ""
			for j in range(roundi((float(c[1]) - start) / cell), roundi((float(c[2]) - start) / cell) + 1):
				line += "%.0f:%.2f  " % [start + j * cell, grid.get(Vector2i(i, j), NAN)]
			print("column x=%s: %s" % [c[0], line])
		elif a.begins_with("row="):
			# row=z,x0,x1: the heights along a row.
			var c := a.substr(4).split(",")
			var j := roundi((float(c[0]) - start) / cell)
			var line := ""
			for i in range(roundi((float(c[1]) - start) / cell), roundi((float(c[2]) - start) / cell) + 1):
				line += "%.0f:%.2f  " % [start + i * cell, grid.get(Vector2i(i, j), NAN)]
			print("row z=%s: %s" % [c[0], line])
	var hits := {}
	for k in grid:
		for o in [Vector2i(1, 0), Vector2i(0, 1)]:
			if not grid.has(k + o):
				continue
			var x: float = start + k.x * cell
			var z: float = start + k.y * cell
			# Only the disc TerrainGenerator draws (past it the grid holds -40).
			if Vector2(x, z).length() > size.x * 0.5 - cell * 1.5:
				continue
			var d: float = absf(grid[k + o] - grid[k])
			# shore=1: only steps across the water's edge (a pond or the sea cut by a wall).
			if shore and (minf(grid[k + o], grid[k]) > 0.05 or maxf(grid[k + o], grid[k]) < 0.3):
				continue
			if d > step:
				var c := Vector2i(floori(x / 20.0), floori(z / 20.0))
				if not hits.has(c) or hits[c][0] < d:
					hits[c] = [d, x, z, grid[k], grid[k + o]]
	var rows := hits.values()
	rows.sort_custom(func(a, b): return a[0] > b[0])
	print("%d cells with steps over %.1fm" % [rows.size(), step])
	for r in rows.slice(0, 40):
		print("  step %.2fm at (%.0f, %.0f): %.2f -> %.2f" % r)
	quit()
