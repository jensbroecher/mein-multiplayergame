# regenerate_custom_path.gd
extends Node

func _ready():
	print("Starting track and level regeneration preserving custom paths...")
	
	# --- 1. DEFAULT OVAL TRACK (Level.tscn) ---
	var desert_path = "res://levels/Level.tscn"
	var packed_desert = load(desert_path)
	if packed_desert:
		var level = packed_desert.instantiate()
		if level:
			print("Instantiated Level.tscn successfully")
			
			var tg = level.get_node_or_null("TerrainGenerator")
			if tg:
				print("Regenerating terrain and road from existing custom curve...")
				tg.generate_world()
			
			print("Aligning default spawn points...")
			level._align_start_and_spawns_to_track()
			
			print("Spawning default sand dunes...")
			level._generate_sand_dunes()
			
			# Save and clean up ownership
			if tg:
				for child in tg.get_children():
					set_owner_recursive_target(child, level)
			var sd = level.get_node_or_null("SandDunes")
			if sd:
				set_owner_recursive_target(sd, level)
			var fl = level.get_node_or_null("FinishLine")
			if fl:
				var sp = fl.get_node_or_null("SpawnPoints")
				if sp:
					set_owner_recursive_target(sp, level)
					
			var new_packed = PackedScene.new()
			var err = new_packed.pack(level)
			if err == OK:
				err = ResourceSaver.save(new_packed, desert_path)
				print("Saved Level.tscn: ", err)
			else:
				print("Failed to pack Level.tscn: ", err)
			level.free()
	
	# --- 2. MOUNTAIN DESERT TRACK (MountainLevel.tscn) ---
	var mountain_path = "res://levels/MountainLevel.tscn"
	var packed_mountain = load(mountain_path)
	if packed_mountain:
		var level = packed_mountain.instantiate()
		if level:
			print("Instantiated MountainLevel.tscn successfully")
			
			var tg = level.get_node_or_null("TerrainGenerator")
			if tg:
				print("Regenerating terrain and road from existing custom curve...")
				tg.generate_world()
			
			print("Aligning mountain desert spawn points...")
			level._align_start_and_spawns_to_track()
			
			print("Spawning mountain desert sand dunes...")
			level._generate_sand_dunes()
			
			# Save and clean up ownership
			if tg:
				for child in tg.get_children():
					set_owner_recursive_target(child, level)
			var sd = level.get_node_or_null("SandDunes")
			if sd:
				set_owner_recursive_target(sd, level)
			var fl = level.get_node_or_null("FinishLine")
			if fl:
				var sp = fl.get_node_or_null("SpawnPoints")
				if sp:
					set_owner_recursive_target(sp, level)
					
			var new_packed = PackedScene.new()
			var err = new_packed.pack(level)
			if err == OK:
				err = ResourceSaver.save(new_packed, mountain_path)
				print("Saved MountainLevel.tscn: ", err)
			else:
				print("Failed to pack MountainLevel.tscn: ", err)
			level.free()
				
	get_tree().quit(0)

func set_owner_recursive_target(node: Node, scene_root: Node):
	node.owner = scene_root
	if node.scene_file_path != "":
		return
	for child in node.get_children():
		set_owner_recursive_target(child, scene_root)
