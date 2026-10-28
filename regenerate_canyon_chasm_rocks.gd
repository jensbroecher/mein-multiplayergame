# regenerate_canyon_chasm_rocks.gd
# Bakes the surface of every ChasmRock (ChasmRock.gd) in CanyonChasmLevel.tscn into its `bake_path()`
# (generated/canyon_chasm_rocks/<kind>_s<seed>_<stretch>.res), which the rock loads; building a rock's
# distance field takes seconds, too slow for loading the level. Bakes no rock uses any more are deleted.
# The level itself is only read: re-saving it from here flattened its instanced scenes and dropped its UIDs.
# Run it after changing ChasmRock.gd's builder (the old bakes stay in use until then) or adding a rock:
#   Godot --headless --path . res://regenerate_canyon_chasm_rocks.tscn
extends Node

const LEVEL := "res://levels/CanyonChasmLevel.tscn"
const ROCK_SCRIPT := "res://ChasmRock.gd"
const Rock := preload("res://ChasmRock.gd")

func _ready() -> void:
	var level: Node = (load(LEVEL) as PackedScene).instantiate()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Rock.BAKE_DIR))
	var t_all := Time.get_ticks_msec()
	var used := {}
	# Not in the tree: neither Level.gd nor the rocks' own _ready run.
	for r in level.find_children("*", "Node3D", true, true):
		if r.get_script() == null or r.get_script().resource_path != ROCK_SCRIPT:
			continue
		var path: String = r.bake_path()
		if used.has(path):
			print("  %-12s shares %s" % [r.name, path])
			continue
		used[path] = true
		var t0 := Time.get_ticks_msec()
		var mesh: ArrayMesh = r.build_mesh()
		var err := ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
		if err != OK:
			push_error("Saving %s failed: %d" % [path, err])
			continue
		print("  %-12s %6d triangles, %5d ms -> %s" % [r.name, mesh.surface_get_array_index_len(0) / 3,
			Time.get_ticks_msec() - t0, path])
	var dir := DirAccess.open(Rock.BAKE_DIR)
	for f in dir.get_files():
		if f.ends_with(".res") and not used.has(Rock.BAKE_DIR + f):
			dir.remove(f)
			print("  removed unused %s" % f)
	print("Baked %d rocks in %.1fs" % [used.size(), (Time.get_ticks_msec() - t_all) / 1000.0])
	level.free()
	get_tree().quit(0)
