extends SceneTree

# Checks the Canyon Course's slot canyon walls (generated/canyon_slot_wall_l/r.res): for each band of
# height over the road, how many triangles face the road (front faces, Godot's clockwise winding:
# (c - a) x (b - a)) and how many face away (culled seen from the road, so the wall is see-through
# there), and how many have vertex normals against their face. Reads the meshes and the TrackPath's
# curve from the saved files, so no level script runs (they need the autoloads). Headless:
#   Godot --headless --path . -s res://scratch/slot_wall_probe.gd

const LEVEL := "res://levels/CanyonLevel.tscn"
const WALLS := ["res://generated/canyon_slot_wall_l.res", "res://generated/canyon_slot_wall_r.res"]

func _init() -> void:
	var state: SceneState = (load(LEVEL) as PackedScene).get_state()
	var curve: Curve3D = null
	for i in state.get_node_count():
		if state.get_node_name(i) != &"TrackPath":
			continue
		for p in state.get_node_property_count(i):
			if state.get_node_property_name(i, p) == &"curve":
				curve = state.get_node_property_value(i, p)
	if curve == null:
		print("no TrackPath curve")
		quit()
		return
	for path in WALLS:
		var mesh: Mesh = load(path)
		var arr := mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		# Bands of 1.5m over the road under the triangle: [toward, away, normals against the face].
		var bands := {}
		for t in range(0, idx.size(), 3):
			var a: Vector3 = v[idx[t]]
			var b: Vector3 = v[idx[t + 1]]
			var c: Vector3 = v[idx[t + 2]]
			var mid: Vector3 = (a + b + c) / 3.0
			var face: Vector3 = (c - a).cross(b - a)
			if face.length() < 1e-6:
				continue
			face = face.normalized()
			var on_road: Vector3 = curve.get_closest_point(mid)
			var to_road: Vector3 = on_road - mid
			to_road.y = 0.0
			var band: int = int(floor((mid.y - on_road.y) / 1.5))
			var row: Array = bands.get(band, [0, 0, 0])
			if face.dot(to_road) > 0.0:
				row[0] += 1
			else:
				row[1] += 1
			if (nrm[idx[t]] + nrm[idx[t + 1]] + nrm[idx[t + 2]]).dot(face) < 0.0:
				row[2] += 1
			bands[band] = row
		var keys: Array = bands.keys()
		keys.sort()
		print(path.get_file())
		for k in keys:
			var r: Array = bands[k]
			print("  %5.1fm .. %5.1fm over the road: %4d face the road, %4d face away, %4d normals against the face" % [k * 1.5, k * 1.5 + 1.5, r[0], r[1], r[2]])
	quit()
