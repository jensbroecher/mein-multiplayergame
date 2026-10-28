extends SceneTree
# -s headless: checks every baked ChasmRock mesh (generated/canyon_chasm_rocks/*.res) for holes, at LOD0 and
# each LOD: open edges (used by one triangle), non-manifold edges (3+), and edges two triangles walk the same
# way (one of them flipped: back-face culled, it shows as a hole). A closed, consistently wound mesh prints
# open=0 nonman=0 flipped=0.
#   Godot --headless --path . -s res://scratch/chasm_rock_holes_probe.gd

const DIR := "res://generated/canyon_chasm_rocks/"

func _initialize():
	var dir := DirAccess.open(DIR)
	for f in dir.get_files():
		if not f.ends_with(".res"):
			continue
		var mesh: ArrayMesh = load(DIR + f)
		var surf := RenderingServer.mesh_get_surface(mesh.get_rid(), 0)
		var arrs := mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrs[Mesh.ARRAY_VERTEX]
		_report(f, "lod0", arrs[Mesh.ARRAY_INDEX], verts)
		var lods: Array = surf.get("lods", [])
		for l in lods.size():
			var data: PackedByteArray = lods[l]["index_data"]
			var idx := PackedInt32Array()
			if verts.size() > 65535:
				idx = data.to_int32_array()
			else:
				for i in data.size() / 2:
					idx.append(data.decode_u16(i * 2))
			_report(f, "lod%d" % (l + 1), idx, verts)
	quit()

func _report(name: String, lod: String, idx: PackedInt32Array, verts: PackedVector3Array) -> void:
	# Weld by position first (the importer may split vertices for normals).
	var weld := {}
	var id := PackedInt32Array()
	id.resize(verts.size())
	for i in verts.size():
		var key := Vector3i((verts[i] * 1000.0).round())
		if not weld.has(key):
			weld[key] = weld.size()
		id[i] = weld[key]
	var edges := {}
	var degen := 0
	for t in idx.size() / 3:
		var a := id[idx[t * 3]]
		var b := id[idx[t * 3 + 1]]
		var c := id[idx[t * 3 + 2]]
		if a == b or b == c or a == c:
			degen += 1
			continue
		for e in [[a, b], [b, c], [c, a]]:
			var k := Vector2i(e[0], e[1])
			edges[k] = edges.get(k, 0) + 1
	var open := 0
	var nonman := 0
	var flipped := 0
	for k in edges:
		var fwd: int = edges[k]
		var back: int = edges.get(Vector2i(k.y, k.x), 0)
		if fwd > 1:
			flipped += 1
		if fwd + back == 1:
			open += 1
		elif fwd + back > 2 and k.x < k.y:
			nonman += 1
	print("%-28s %-5s tris=%7d open=%5d nonman=%4d flipped=%4d degen=%4d" % [name, lod, idx.size() / 3,
		open, nonman, flipped, degen])
