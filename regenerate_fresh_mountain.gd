# regenerate_fresh_mountain.gd
extends Node

func _ready():
	print("Starting fresh MountainLevel track rebuild and regeneration...")
	
	var mountain_path = "res://levels/MountainLevel.tscn"
	var packed_mountain = load(mountain_path)
	if packed_mountain:
		var level = packed_mountain.instantiate()
		if level:
			print("Instantiated MountainLevel.tscn successfully")
			
			var tg = level.get_node_or_null("TerrainGenerator")
			if tg:
				print("Rebuilding track with bridge crossover...")
				tg._rebuild_mountain_track()
			
			print("Redistributing checkpoints...")
			level._rebuild_checkpoints()
			
			print("Aligning mountain desert spawn points...")
			level._align_start_and_spawns_to_track()
			
			print("Aligning checkpoints to track...")
			level._align_checkpoints_to_track()
			
			print("Spawning mountain desert sand dunes...")
			level._generate_sand_dunes()
			
			# Save and clean up ownership
			if tg:
				for child in tg.get_children():
					set_owner_recursive_target(child, level)
			var sd = level.get_node_or_null("SandDunes")
			if sd:
				set_owner_recursive_target(sd, level)
				# Ensure all generated dune children are owned by the level root for correct serialization
				for dune in sd.get_children():
					set_owner_recursive_target(dune, level)
					for child in dune.get_children():
						set_owner_recursive_target(child, level)
			var fl = level.get_node_or_null("FinishLine")
			if fl:
				var sp = fl.get_node_or_null("SpawnPoints")
				if sp:
					set_owner_recursive_target(sp, level)
			var cp_container = level.get_node_or_null("Checkpoints")
			if cp_container:
				for child in cp_container.get_children():
					set_owner_recursive_target(child, level)
					
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
