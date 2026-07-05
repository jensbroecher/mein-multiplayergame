# regenerate_both.gd
# Regenerates ALL three levels at once, preserving custom Path3D curves in each.
# To regenerate a single level, use regenerate_canyon.tscn / regenerate_mountain.tscn / regenerate_desert.tscn
extends Node

func _ready():
	print("Starting regeneration for all levels (preserving custom curves)...")
	
	# --- 1. DEFAULT OVAL TRACK (Level.tscn) ---
	var desert_path = "res://levels/Level.tscn"
	var packed_desert = load(desert_path)
	if packed_desert:
		var level = packed_desert.instantiate()
		if level:
			print("Instantiated Level.tscn successfully")
			add_child(level)
			
			var tg = level.get_node_or_null("TerrainGenerator")
			
			print("Aligning default spawn points...")
			level._align_start_and_spawns_to_track()
			
			# Sand dunes are only for MountainLevel, not Level.tscn
			var sd = level.get_node_or_null("SandDunes")
			if sd:
				sd.free()
			
			_strip_grass_container(level, tg, "Level")
			
			# Save and clean up ownership
			if tg:
				for child in tg.get_children():
					set_owner_recursive_target(child, level)
			var sp = level.get_node_or_null("SpawnPoints")
			if sp:
				set_owner_recursive_target(sp, level)
					
			remove_child(level)
			var new_packed = PackedScene.new()
			var err = new_packed.pack(level)
			if err == OK:
				err = ResourceSaver.save(new_packed, desert_path)
				print("Saved Level.tscn: ", err)
			else:
				print("Failed to pack Level.tscn: ", err)
	
	# --- 2. MOUNTAIN DESERT TRACK (MountainLevel.tscn) ---
	var mountain_path = "res://levels/MountainLevel.tscn"
	var packed_mountain = load(mountain_path)
	if packed_mountain:
		var level = packed_mountain.instantiate()
		if level:
			print("Instantiated MountainLevel.tscn successfully")
			add_child(level)
			
			var tg = level.get_node_or_null("TerrainGenerator")
			if tg:
				print("Regenerating mountain terrain from existing custom curve...")
				tg.generate_world()
			
			print("Aligning mountain desert spawn points...")
			level._align_start_and_spawns_to_track()
			
			print("Spawning mountain desert sand dunes...")
			# level._generate_sand_dunes() # Commented out to preserve user's manually arranged dunes
			
			_strip_grass_container(level, tg, "MountainLevel")
			
			# Save and clean up ownership
			if tg:
				for child in tg.get_children():
					set_owner_recursive_target(child, level)
			var sd = level.get_node_or_null("SandDunes")
			if sd:
				set_owner_recursive_target(sd, level)
			var sp = level.get_node_or_null("SpawnPoints")
			if sp:
				set_owner_recursive_target(sp, level)
					
			remove_child(level)
			var new_packed = PackedScene.new()
			var err = new_packed.pack(level)
			if err == OK:
				err = ResourceSaver.save(new_packed, mountain_path)
				print("Saved MountainLevel.tscn: ", err)
			else:
				print("Failed to pack MountainLevel.tscn: ", err)

	# --- 3. CANYON TRACK (CanyonLevel.tscn) ---
	var canyon_path = "res://levels/CanyonLevel.tscn"
	var packed_canyon = load(canyon_path)
	if packed_canyon:
		var level = packed_canyon.instantiate()
		if level:
			print("Instantiated CanyonLevel.tscn successfully")
			add_child(level)
			
			var tg = level.get_node_or_null("TerrainGenerator")
			if tg:
				print("Regenerating canyon terrain from existing custom curve...")
				tg.generate_world()
			
			print("Aligning canyon spawn points...")
			level._align_start_and_spawns_to_track()
			
			_strip_grass_container(level, tg, "CanyonLevel")
			
			# Save and clean up ownership
			if tg:
				for child in tg.get_children():
					set_owner_recursive_target(child, level)
			var sp = level.get_node_or_null("SpawnPoints")
			if sp:
				set_owner_recursive_target(sp, level)
					
			remove_child(level)
			var new_packed = PackedScene.new()
			var err = new_packed.pack(level)
			if err == OK:
				err = ResourceSaver.save(new_packed, canyon_path)
				print("Saved CanyonLevel.tscn: ", err)
			else:
				print("Failed to pack CanyonLevel.tscn: ", err)
				
	get_tree().quit(0)

func set_owner_recursive_target(node: Node, scene_root: Node):
	node.owner = scene_root
	# If this node is an instantiated subscene, do not set owner on its internal children
	if node.scene_file_path != "":
		return
	for child in node.get_children():
		set_owner_recursive_target(child, scene_root)

func _find_node_by_name(root: Node, target_name: String) -> Node:
	if root.name == target_name:
		return root
	for child in root.get_children():
		var found = _find_node_by_name(child, target_name)
		if found:
			return found
	return null

func _strip_grass_container(level: Node, tg: Node, label: String):
	var gc = null
	if tg:
		gc = tg.get_node_or_null("GrassContainer")
	if not gc:
		gc = _find_node_by_name(level, "GrassContainer")
	if gc:
		gc.get_parent().remove_child(gc)
		gc.free()
		print("Removed GrassContainer from ", label, " before packing to prevent bloat")
	else:
		print("INFO: No GrassContainer in ", label, " to remove")
