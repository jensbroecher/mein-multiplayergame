# regenerate_canyon_chasm.gd
# Regenerates CanyonChasmLevel.tscn preserving all custom props (Tornado, jump ramps, desert props)
# and its custom Path3D curve.
extends Node

func _ready():
	print("=== Canyon Chasm Level Regeneration ===")
	var target_path = "res://levels/CanyonChasmLevel.tscn"

	var packed = load(target_path)
	if not packed:
		push_error("Could not load CanyonChasmLevel.tscn")
		get_tree().quit(1)
		return
	
	var level = packed.instantiate()
	if not level:
		push_error("Could not instantiate CanyonChasmLevel.tscn")
		get_tree().quit(1)
		return
	
	print("Instantiated CanyonChasmLevel.tscn successfully")
	add_child(level)
	
	var tg = level.get_node_or_null("TerrainGenerator")
	var track_path = level.get_node_or_null("TrackPath")
	
	if not tg or not track_path:
		push_error("TerrainGenerator or TrackPath node not found")
		get_tree().quit(1)
		return
		
	tg.level_prefix = "canyon_chasm"
	tg.track_layout_type = 2 # CANYON
	tg.no_water = true
	tg.no_grass = true
	
	print("Regenerating canyon chasm meshes...")
	tg.generate_world()
	
	# Clean up ownership
	for child in level.get_children():
		_set_owner_recursive(child, level)
		
	var gc = tg.get_node_or_null("GrassContainer")
	if gc:
		tg.remove_child(gc)
		gc.free()
		
	remove_child(level)

	var new_packed = PackedScene.new()
	var err_pack = new_packed.pack(level)
	if err_pack == OK:
		var err_save = ResourceSaver.save(new_packed, target_path)
		if err_save == OK:
			print("Saved CanyonChasmLevel.tscn successfully.")
		else:
			push_error("ResourceSaver.save failed: " + str(err_save))
			get_tree().quit(1)
			return
	else:
		push_error("PackedScene.pack failed: " + str(err_pack))
		get_tree().quit(1)
		return
		
	get_tree().quit(0)

func _set_owner_recursive(node: Node, scene_root: Node):
	node.owner = scene_root
	if node.scene_file_path != "":
		return
	for child in node.get_children():
		_set_owner_recursive(child, scene_root)
