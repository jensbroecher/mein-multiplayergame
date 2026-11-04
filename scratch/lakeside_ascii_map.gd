extends SceneTree
## An ASCII map of the Lakeside Meadows for planning dressing by eye (headless, seconds):
##   Godot --headless --path . -s res://scratch/lakeside_ascii_map.gd -- [cell=20] [x0=-960 x1=960 z0=-960 z1=960]
## One character per `cell` metres, x to the right, z downward (north up: -z at the top). Reads the baked
## terrain (generated/terrain_visual.res, its 2m grid's heights) and the TrackPath:
##   '#' the lap's road (within 8m of its centreline), '=' on a bridge (road more than 4m over the ground),
##   '~' water (ground under the -10m water plane), '^' steep (over 0.45 rise per metre), '.' meadow,
##   ':' low meadow (under -6m), digits the ground's height band (tens of metres) where 'h' is given,
##   and named points: M marquee, C camp terrace, Y the woodyard, T lookout tower, F finish, L loop, P playground;
##   'o' the bike path and '+' the footpaths (LakesideDressing/Paths' Trail_* ribbons).
## Row and column labels give the z and x of each cell's middle.

const GRID_RES := 1000
const GRID_START := -1000.0
const GRID_STEP := 2.0
const WATER := -10.0

var _h := PackedFloat32Array()


func _ground(x: float, z: float) -> float:
	var gx: float = (x - GRID_START) / GRID_STEP
	var gz: float = (z - GRID_START) / GRID_STEP
	var x0: int = clampi(floori(gx), 0, GRID_RES - 1)
	var z0: int = clampi(floori(gz), 0, GRID_RES - 1)
	var fx: float = gx - float(x0)
	var fz: float = gz - float(z0)
	var stride := GRID_RES + 1
	var h00: float = _h[z0 * stride + x0]
	var h10: float = _h[z0 * stride + x0 + 1]
	var h01: float = _h[(z0 + 1) * stride + x0]
	var h11: float = _h[(z0 + 1) * stride + x0 + 1]
	if fx + fz <= 1.0:
		return h00 + (h10 - h00) * fx + (h01 - h00) * fz
	return h11 + (h01 - h11) * (1.0 - fx) + (h10 - h11) * (1.0 - fz)


func _init() -> void:
	var cell := 20.0
	var x0 := -960.0
	var x1 := 960.0
	var z0 := -960.0
	var z1 := 960.0
	var heights := false
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() != 2:
			if a == "h":
				heights = true
			continue
		match kv[0]:
			"cell": cell = float(kv[1])
			"x0": x0 = float(kv[1])
			"x1": x1 = float(kv[1])
			"z0": z0 = float(kv[1])
			"z1": z1 = float(kv[1])
	var mesh: ArrayMesh = load("res://generated/terrain_visual.res")
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	_h.resize(verts.size())
	for i in range(verts.size()):
		_h[i] = verts[i].y
	var lvl: Node3D = load("res://levels/LakesideLevel.tscn").instantiate()
	var path: Path3D = lvl.get_node("TrackPath")
	var curve: Curve3D = path.curve
	var marks := {}
	var named := {"M": "LakesideDressing/Marquee", "Y": "LakesideDressing/LogCabin", "T": "LakesideDressing/LookoutTower",
			"F": "FinishLine", "L": "Ramps/LoopCSG"}
	for k in named:
		var n := lvl.get_node_or_null(named[k]) as Node3D
		if n:
			marks[k] = n.position if n.get_parent() == lvl else (n.get_parent() as Node3D).transform * n.position
	marks["C"] = Vector3(62.0, 0.0, 68.0)
	var pg := lvl.get_node_or_null("LakesideDressing/Playground/PlaygroundKit") as MeshInstance3D
	if pg:
		marks["P"] = pg.mesh.get_aabb().get_center()
	var path_cells := {}
	var paths := lvl.get_node_or_null("LakesideDressing/Paths")
	if paths:
		for c in paths.get_children():
			if c is MeshInstance3D and String(c.name).begins_with("Trail_"):
				var bike := String(c.name).begins_with("Trail_Bike")
				var vs: PackedVector3Array = (c as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				for i in range(0, vs.size(), 5):
					var k := Vector2i(int(round((vs[i].x - x0) / cell)), int(round((vs[i].z - z0) / cell)))
					path_cells[k] = "o" if bike else "+"
	var head := "        "
	var x := x0
	while x <= x1:
		var lab := int(x)
		head += ("|" if lab % 200 == 0 else " ")
		x += cell
	print(head)
	var z := z0
	while z <= z1:
		var row := "%6d  " % int(z)
		x = x0
		while x <= x1:
			var c := "."
			var g := _ground(x, z)
			var p := path.transform * curve.get_closest_point(path.transform.affine_inverse() * Vector3(x, g, z))
			var rd := Vector2(p.x - x, p.z - z).length()
			if rd < maxf(8.0, cell * 0.5):
				c = "=" if p.y - g > 4.0 else "#"
			elif g < WATER:
				c = "~"
			else:
				var sl: float = maxf(absf(_ground(x + 2.0, z) - g), absf(_ground(x, z + 2.0) - g)) / 2.0
				if sl > 0.45:
					c = "^"
				elif heights:
					c = str(clampi(int(floor((g + 10.0) / 10.0)), 0, 9))
				elif g < -6.0:
					c = ":"
			var pk := Vector2i(int(round((x - x0) / cell)), int(round((z - z0) / cell)))
			if path_cells.has(pk) and c != "#" and c != "=":
				c = path_cells[pk]
			for k in marks:
				var m: Vector3 = marks[k]
				if absf(m.x - x) <= cell * 0.5 and absf(m.z - z) <= cell * 0.5:
					c = k
			row += c
			x += cell
		print(row)
		z += cell
	print("columns from x %d every %dm ('|' every 200m from 0); rows labelled with z" % [int(x0), int(cell)])
	lvl.free()
	quit()
