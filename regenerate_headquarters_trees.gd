extends SceneTree
## Bakes the trees of the headquarters' plaza (Garage.gd's _build_plaza) into generated/headquarters_tree_*.res: the
## courses' own detailed trees (WoodlandBuilder's London planes and birches, MiyoshinoTrees' weeping cherry, Japanese
## maples and azaleas), at life size, each mesh holding its bark and leaf materials (lod_mode 0: always drawn), and
## each one's far stand-in (`*_shadow`), which casts its shadow in its place. The headquarters is built at run time
## and only loads these. Run headless:
##   Godot --headless --path . -s res://regenerate_headquarters_trees.gd
## Then reopen the headquarters (no level to regenerate).

const OUT := "res://generated/headquarters_tree_"
## [kind, variant]: what _build_plaza plants.
const TREES := [["plane", 0], ["plane", 1], ["birch", 0], ["birch", 1], ["shidare", 0], ["momiji", 0], ["momiji_red", 0],
	["momiji_red", 1], ["tsutsuji", 0], ["tsutsuji", 1]]
const MIYO := ["sakura", "yamazakura", "shidare", "sugi", "momiji", "momiji_red", "take", "matsu", "tsutsuji"]


func _save(res: Resource, n: String) -> Resource:
	var path: String = OUT + n + ".res"
	res.take_over_path(path)
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("couldn't save %s: %d" % [path, err])
	return load(path)


func _tris(mesh: ArrayMesh) -> int:
	var n := 0
	for si in mesh.get_surface_count():
		n += mesh.surface_get_array_index_len(si) / 3
	return n


func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var w = load("res://MiyoshinoTrees.gd").new()
	w.save_res = func(res: Resource, n: String) -> Resource: return _save(res, n)
	var leaf_classic: ShaderMaterial = _save(w.leaf_material(0, 0.10, 16.0), "leaf_classic")
	var leaf_rhein: ShaderMaterial = _save(w.rhein_leaf_material(0, 0.10, 18.0), "leaf_rhein")
	var leaf_miyo: ShaderMaterial = _save(w.miyo_leaf_material(0, 0.10, 10.0), "leaf_miyo")
	var barks := {}
	for t in TREES:
		var kind: String = t[0]
		var variant: int = t[1]
		var miyo: bool = MIYO.has(kind)
		var bark_key: String = w.miyo_bark_key(kind) if miyo else kind
		if not barks.has(bark_key):
			barks[bark_key] = _save(w.bark_material(bark_key, 0), "bark_" + bark_key)
		var mesh: ArrayMesh
		if miyo:
			mesh = w.miyo_mesh(kind, variant, 0, barks[bark_key], leaf_miyo)
		else:
			var leaf: ShaderMaterial = leaf_rhein if w.uses_rhein_atlas(kind) else leaf_classic
			mesh = w.tree_mesh(kind, variant, 0, barks[bark_key], leaf)
		_save(mesh, "%s_%d" % [kind, variant])
		# The far stand-in, only to cast the tree's shadow (Garage.gd draws it SHADOWS_ONLY): the detailed crowns'
		# leaf cards in the shadow pass cost about 5ms of an M1 at 1600x1000.
		var far: ArrayMesh
		if miyo:
			far = w.miyo_mesh(kind, variant, 1, barks[bark_key], leaf_miyo)
		else:
			var leaf_f: ShaderMaterial = leaf_rhein if w.uses_rhein_atlas(kind) else leaf_classic
			far = w.tree_mesh(kind, variant, 1, barks[bark_key], leaf_f)
		if far:
			_save(far, "%s_%d_shadow" % [kind, variant])
		print("%s_%d: %d triangles (stand-in %d), %.1fm tall" % [kind, variant, _tris(mesh), _tris(far) if far else 0,
				mesh.get_aabb().end.y])
	print("baked in %.1fs" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit()
