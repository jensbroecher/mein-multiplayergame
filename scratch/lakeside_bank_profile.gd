extends SceneTree

# How the ground beside the Lakeside lap compares with the road: for each lap distance, the road's height
# and the ground's at some lateral offsets (left negative), from the baked terrain heights (as
# regenerate_lakeside.gd's _ground reads them). For laying shortcuts and props off the road. Headless:
#   Godot --headless --path . -s res://scratch/lakeside_bank_profile.gd -- <s0> <s1> [step=6] [lats=-20,-14,-10,10,14,20]

const GRID_RES := 1000
const GRID_START := -1000.0
const GRID_STEP := 2.0

var _heights := PackedFloat32Array()


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var s0 := float(args[0])
	var s1 := float(args[1])
	var step := 6.0
	var lats := [-20.0, -14.0, -10.0, 10.0, 14.0, 20.0]
	for a in args.slice(2):
		if a.begins_with("step="):
			step = float(a.substr(5))
		elif a.begins_with("lats="):
			lats = Array(a.substr(5).split(",")).map(func(v): return float(v))
	var mesh: ArrayMesh = load("res://generated/terrain_visual.res")
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	_heights.resize(verts.size())
	for i in range(verts.size()):
		_heights[i] = verts[i].y
	var state: SceneState = (load("res://levels/LakesideLevel.tscn") as PackedScene).get_state()
	var curve: Curve3D = null
	for i in state.get_node_count():
		if String(state.get_node_name(i)) == "TrackPath":
			for p in state.get_node_property_count(i):
				if state.get_node_property_name(i, p) == &"curve":
					curve = state.get_node_property_value(i, p)
	var length := curve.get_baked_length()
	var head := "     s   road "
	for l in lats:
		head += " %6.0f" % l
	print(head + "   (ground minus road)")
	var s := s0
	while s <= s1 + 0.01:
		var ss := fposmod(s, length)
		var p := curve.sample_baked(ss)
		var f := curve.sample_baked(fposmod(ss + 0.6, length)) - curve.sample_baked(fposmod(ss - 0.6, length))
		f.y = 0.0
		f = f.normalized()
		var right := Vector3(-f.z, 0.0, f.x)
		var line := "%6.0f %6.1f " % [s, p.y]
		for l in lats:
			var q: Vector3 = p + right * float(l)
			line += " %+6.1f" % (_ground(q.x, q.z) - p.y)
		print(line)
		s += step
	quit()


func _ground(x: float, z: float) -> float:
	var gx: float = (x - GRID_START) / GRID_STEP
	var gz: float = (z - GRID_START) / GRID_STEP
	var x0: int = clampi(floori(gx), 0, GRID_RES - 1)
	var z0: int = clampi(floori(gz), 0, GRID_RES - 1)
	var fx: float = gx - float(x0)
	var fz: float = gz - float(z0)
	var stride := GRID_RES + 1
	var h00: float = _heights[z0 * stride + x0]
	var h10: float = _heights[z0 * stride + x0 + 1]
	var h01: float = _heights[(z0 + 1) * stride + x0]
	var h11: float = _heights[(z0 + 1) * stride + x0 + 1]
	if fx + fz <= 1.0:
		return h00 + fx * (h10 - h00) + fz * (h01 - h00)
	return h11 + (1.0 - fx) * (h01 - h11) + (1.0 - fz) * (h10 - h11)
