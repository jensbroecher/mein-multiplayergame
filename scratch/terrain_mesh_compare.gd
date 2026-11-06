extends SceneTree
## Prints the heights of two terrain meshes (TerrainGenerator grids) at given points, to compare a re-bake with
## an older one:  Godot --headless --path . -s res://scratch/terrain_mesh_compare.gd -- <a.res> <b.res> x,z ...
func _h(m: ArrayMesh, x: float, z: float) -> float:
	var v: PackedVector3Array = m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var best := INF
	var y := NAN
	for p in v:
		var d := Vector2(p.x - x, p.z - z).length_squared()
		if d < best:
			best = d
			y = p.y
	return y
func _init():
	var a: ArrayMesh = load(OS.get_cmdline_user_args()[0])
	var b: ArrayMesh = load(OS.get_cmdline_user_args()[1])
	for s in OS.get_cmdline_user_args().slice(2):
		var xz := s.split(",")
		print(s, "  a=", _h(a, float(xz[0]), float(xz[1])), "  b=", _h(b, float(xz[0]), float(xz[1])))
	quit()
