# regenerate_desert.gd
# Regenerates ONLY Level.tscn (the desert/oval track) — preserves your custom Path3D curve.
# Run by opening regenerate_desert.tscn and pressing F6 (Run Current Scene).
extends Node

func _ready():
	print("=== Desert Level Regeneration ===")

	var desert_path = "res://levels/Level.tscn"
	var packed_desert = load(desert_path)
	if not packed_desert:
		push_error("Could not load Level.tscn")
		get_tree().quit(1)
		return

	var level = packed_desert.instantiate()
	if not level:
		push_error("Could not instantiate Level.tscn")
		get_tree().quit(1)
		return

	print("Instantiated Level.tscn")
	add_child(level)

	var tg = level.get_node_or_null("TerrainGenerator")
	if tg:
		print("Regenerating desert terrain from existing custom curve...")
		tg.generate_world()
	else:
		push_error("TerrainGenerator node not found in Level.tscn")

	print("Aligning desert spawn points...")
	level._align_start_and_spawns_to_track()

	# Level.tscn has no SandDunes — remove them if somehow present
	var sd = level.get_node_or_null("SandDunes")
	if sd:
		sd.free()

	# Fix ownership so all generated nodes are saved into the scene file
	if tg:
		for child in tg.get_children():
			_set_owner_recursive(child, level)
	var sp = level.get_node_or_null("SpawnPoints")
	if sp:
		_set_owner_recursive(sp, level)

	remove_child(level)
	var new_packed = PackedScene.new()
	var err = new_packed.pack(level)
	if err == OK:
		err = ResourceSaver.save(new_packed, desert_path)
		if err == OK:
			print("Saved Level.tscn successfully.")
		else:
			push_error("ResourceSaver.save failed: " + str(err))
	else:
		push_error("PackedScene.pack failed: " + str(err))

	get_tree().quit(0)


func _set_owner_recursive(node: Node, scene_root: Node):
	node.owner = scene_root
	if node.scene_file_path != "":
		return
	for child in node.get_children():
		_set_owner_recursive(child, scene_root)
