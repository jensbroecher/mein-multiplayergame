extends RefCounted

# Splits a large static mesh into a grid of smaller meshes on the XZ plane.
#
# A level-spanning mesh (a whole road ribbon, its barriers, a terrain sheet) can't be culled: every
# camera and every shadow pass draws all of it, even a streetlight whose shadow only reaches 20m.
# Chunked, each pass draws just the cells its frustum touches. Triangles and every vertex attribute
# are copied unchanged, so the result renders exactly like the original.


## Meshes with fewer triangles than this are left as they are.
const DEFAULT_MIN_TRIANGLES := 8000


## Splits `mesh` into cells of `cell_size` metres (in the mesh's local XZ), assigning each triangle
## to the cell holding its centroid. Returns { Vector2i cell: ArrayMesh }. Surfaces keep their
## materials and format; cells a surface doesn't touch get no surface for it.
static func split_mesh(mesh: ArrayMesh, cell_size: float) -> Dictionary:
	var out := {}
	for s in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			push_error("MeshChunker: only triangle surfaces can be split")
			return {}
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			indices.resize(verts.size())
			for i in verts.size():
				indices[i] = i
		# Triangle -> cell.
		var cell_tris := {}
		for t in range(0, indices.size(), 3):
			var c := (verts[indices[t]] + verts[indices[t + 1]] + verts[indices[t + 2]]) / 3.0
			var key := Vector2i(floori(c.x / cell_size), floori(c.z / cell_size))
			if not cell_tris.has(key):
				cell_tris[key] = PackedInt32Array()
			var list: PackedInt32Array = cell_tris[key]
			list.append(t)
			cell_tris[key] = list
		var fmt := mesh.surface_get_format(s)
		# Keep the original's compression/flag bits; the attribute layout is rebuilt from the arrays.
		var flags := fmt & ~(Mesh.ARRAY_FORMAT_VERTEX | Mesh.ARRAY_FORMAT_NORMAL | Mesh.ARRAY_FORMAT_TANGENT
			| Mesh.ARRAY_FORMAT_COLOR | Mesh.ARRAY_FORMAT_TEX_UV | Mesh.ARRAY_FORMAT_TEX_UV2
			| Mesh.ARRAY_FORMAT_CUSTOM0 | Mesh.ARRAY_FORMAT_CUSTOM1 | Mesh.ARRAY_FORMAT_CUSTOM2
			| Mesh.ARRAY_FORMAT_CUSTOM3 | Mesh.ARRAY_FORMAT_BONES | Mesh.ARRAY_FORMAT_WEIGHTS
			| Mesh.ARRAY_FORMAT_INDEX)
		var mat := mesh.surface_get_material(s)
		for key in cell_tris:
			var sub := _sub_arrays(arrays, indices, cell_tris[key])
			if not out.has(key):
				out[key] = ArrayMesh.new()
			var am: ArrayMesh = out[key]
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sub, [], {}, flags)
			am.surface_set_material(am.get_surface_count() - 1, mat)
	return out


## Replaces a MeshInstance3D with a Node3D of the same name, transform and parent, holding one
## MeshInstance3D per cell with the original's rendering settings. When `save_prefix` is set
## (e.g. "res://generated/level_road_deck"), each chunk is saved as `<prefix>_<x>_<z>.res` so the
## scene references it instead of embedding it. Returns the new node, or the original if the mesh
## is too small to be worth splitting.
static func chunk_instance(mi: MeshInstance3D, cell_size: float, save_prefix: String = "",
		min_triangles: int = DEFAULT_MIN_TRIANGLES) -> Node3D:
	var mesh := mi.mesh as ArrayMesh
	if mesh == null or triangle_count(mesh) < min_triangles:
		return mi
	var cells := split_mesh(mesh, cell_size)
	if cells.size() <= 1:
		return mi
	var group := Node3D.new()
	group.name = mi.name
	group.transform = mi.transform
	group.visible = mi.visible
	var keys := cells.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for key in keys:
		var chunk_mesh: Mesh = cells[key]
		if save_prefix != "":
			var path := "%s_%d_%d.res" % [save_prefix, key.x, key.y]
			var err := ResourceSaver.save(chunk_mesh, path)
			if err != OK:
				push_error("MeshChunker: failed to save %s (%d)" % [path, err])
			else:
				chunk_mesh.take_over_path(path)
		var part := MeshInstance3D.new()
		part.name = "Chunk_%d_%d" % [key.x, key.y]
		part.mesh = chunk_mesh
		part.material_override = mi.material_override
		part.material_overlay = mi.material_overlay
		part.cast_shadow = mi.cast_shadow
		part.layers = mi.layers
		part.gi_mode = mi.gi_mode
		part.extra_cull_margin = mi.extra_cull_margin
		part.lod_bias = mi.lod_bias
		part.visibility_range_begin = mi.visibility_range_begin
		part.visibility_range_end = mi.visibility_range_end
		part.transparency = mi.transparency
		for s in mi.get_surface_override_material_count():
			# Chunks only carry the surfaces they touch, so match overrides by material slot order
			# only when the chunk kept every surface.
			if chunk_mesh.get_surface_count() == mesh.get_surface_count():
				part.set_surface_override_material(s, mi.get_surface_override_material(s))
		group.add_child(part)
	var parent := mi.get_parent()
	if parent:
		var idx := mi.get_index()
		parent.remove_child(mi)
		parent.add_child(group)
		parent.move_child(group, idx)
	mi.free()
	return group


## Chunks every MeshInstance3D under `root` whose mesh was saved under `source_prefix` (e.g.
## "res://generated/glacier_highway_") and is big enough to be worth it. Chunks are written to
## `out_dir` (emptied first, so stale cells don't linger) and the whole-mesh files they replace are
## deleted, since nothing references them anymore. Call before setting scene ownership.
static func chunk_scene(root: Node, source_prefix: String, out_dir: String, cell_size: float,
		min_triangles: int = DEFAULT_MIN_TRIANGLES) -> int:
	if DirAccess.dir_exists_absolute(out_dir):
		for f in DirAccess.get_files_at(out_dir):
			DirAccess.remove_absolute(out_dir.path_join(f))
	else:
		DirAccess.make_dir_recursive_absolute(out_dir)
	var count := 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		if mesh == null or not mesh.resource_path.begins_with(source_prefix):
			continue
		var source_path := mesh.resource_path
		var prefix := out_dir.path_join(source_path.get_file().get_basename())
		if chunk_instance(mi, cell_size, prefix, min_triangles) != mi:
			DirAccess.remove_absolute(source_path)
			count += 1
	return count


static func triangle_count(mesh: Mesh) -> int:
	var t := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var idx = arrays[Mesh.ARRAY_INDEX]
		t += (idx.size() if idx != null and idx.size() > 0 else arrays[Mesh.ARRAY_VERTEX].size()) / 3
	return t


# Copies the triangles listed in `tris` (first-index offsets into `indices`) into new arrays with
# their own compact vertex buffer.
static func _sub_arrays(arrays: Array, indices: PackedInt32Array, tris: PackedInt32Array) -> Array:
	var index_map := {}
	var order := PackedInt32Array()
	var new_idx := PackedInt32Array()
	new_idx.resize(tris.size() * 3)
	var w := 0
	for t in tris:
		for k in 3:
			var old := indices[t + k]
			var ni: int
			if index_map.has(old):
				ni = index_map[old]
			else:
				ni = order.size()
				index_map[old] = ni
				order.append(old)
			new_idx[w] = ni
			w += 1
	var sub := []
	sub.resize(Mesh.ARRAY_MAX)
	for a in Mesh.ARRAY_MAX:
		if a == Mesh.ARRAY_INDEX:
			continue
		var src = arrays[a]
		if src == null or src.size() == 0:
			continue
		# Some attributes pack several values per vertex (tangents 4, bones/weights 4 or 8,
		# custom channels up to 4).
		var vcount: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var per: int = src.size() / vcount
		var dst = src.duplicate()
		dst.resize(order.size() * per)
		for i in order.size():
			var o := order[i] * per
			var d := i * per
			for k in per:
				dst[d + k] = src[o + k]
		sub[a] = dst
	sub[Mesh.ARRAY_INDEX] = new_idx
	return sub
