# Rebuilds OrganicDune meshes in MountainLevel.tscn (circular, higher detail).
# Play this scene once from the editor, then close it. Not used at race time.
extends Node

func _ready() -> void:
	print("=== Refresh Mountain Sand Dunes ===")
	var path := "res://levels/MountainLevel.tscn"
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_error("Could not load MountainLevel.tscn")
		get_tree().quit(1)
		return
	var level = packed.instantiate()
	if level == null:
		push_error("Could not instantiate MountainLevel.tscn")
		get_tree().quit(1)
		return
	add_child(level)
	if level.has_method("_refresh_existing_sand_dune_meshes"):
		level._refresh_existing_sand_dune_meshes()
	else:
		push_error("Level is missing _refresh_existing_sand_dune_meshes")
		get_tree().quit(1)
		return

	var dunes = level.get_node_or_null("SandDunes")
	if dunes:
		_set_owner_recursive(dunes, level)

	remove_child(level)
	var out := PackedScene.new()
	var err_pack := out.pack(level)
	if err_pack != OK:
		push_error("pack failed: " + str(err_pack))
		get_tree().quit(1)
		return
	var err_save := ResourceSaver.save(out, path)
	if err_save != OK:
		push_error("save failed: " + str(err_save))
		get_tree().quit(1)
		return
	print("Saved MountainLevel.tscn with updated circular dune meshes.")
	get_tree().quit(0)


func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	if node == null:
		return
	node.owner = scene_root
	if node.scene_file_path != "":
		return
	for child in node.get_children():
		_set_owner_recursive(child, scene_root)
