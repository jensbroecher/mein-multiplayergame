extends SceneTree
## The Lakeside's ground round its rim, from the baked terrain (generated/terrain_visual.res, a 2m grid from -1000):
## per bearing the heights at radii from 600 to 1000m, the lap's extent and the water level. Headless:
##   Godot --headless --path . -s res://scratch/lakeside_rim_probe.gd

func _init() -> void:
	var mesh: ArrayMesh = load("res://generated/terrain_visual.res")
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var res := int(round(sqrt(float(verts.size())))) - 1
	print("grid ", res, " verts ", verts.size(), " first ", verts[0], " last ", verts[verts.size() - 1])
	var stride := res + 1
	var start: float = verts[0].x
	var step: float = (verts[verts.size() - 1].x - start) / float(res)
	var h := func(x: float, z: float) -> float:
		var i := clampi(int(round((x - start) / step)), 0, res)
		var j := clampi(int(round((z - start) / step)), 0, res)
		return verts[j * stride + i].y
	var level: Node = (load("res://levels/LakesideLevel.tscn") as PackedScene).instantiate()
	var curve: Curve3D = (level.get_node("TrackPath") as Path3D).curve
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := -lo
	var maxr := 0.0
	for k in range(0, int(curve.get_baked_length()), 5):
		var p: Vector3 = curve.sample_baked(k)
		lo = Vector3(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z))
		hi = Vector3(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z))
		maxr = maxf(maxr, Vector2(p.x, p.z).length())
	print("lap box ", lo, " .. ", hi, " furthest from centre ", maxr)
	var water := level.get_node_or_null("TerrainGenerator/Water_Surface") as Node3D
	print("water y ", water.position.y if water else "none")
	for deg in range(0, 360, 30):
		var a := deg_to_rad(float(deg))
		var line := "bearing %3d (x %+.2f z %+.2f):" % [deg, cos(a), sin(a)]
		for r in [600, 700, 800, 850, 880, 920, 960, 1000]:
			line += " %4d:%6.1f" % [r, h.call(cos(a) * r, sin(a) * r)]
		print(line)
	level.free()
	quit()
