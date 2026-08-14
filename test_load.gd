# test_load.gd
extends Node

func _ready():
	print("--- TEST ALL LEVELS LOAD & TERRAIN ---")
	var levels = [
		"res://levels/Level.tscn",
		"res://levels/MountainLevel.tscn",
		"res://levels/CanyonLevel.tscn",
		"res://levels/CanyonChasmLevel.tscn",
		"res://levels/DesertWadiLevel.tscn"
	]
	
	for lvl_path in levels:
		print("\nTesting level: ", lvl_path)
		var res = load(lvl_path) as PackedScene
		if not res:
			print("FAILED to load: ", lvl_path)
			continue
		var inst = res.instantiate()
		if not inst:
			print("FAILED to instantiate: ", lvl_path)
			continue
		add_child(inst)
		var tg = inst.get_node_or_null("TerrainGenerator")
		if tg:
			var tv = tg.get_node_or_null("Terrain_Visual") as MeshInstance3D
			if tv and tv.mesh:
				var aabb = tv.mesh.get_aabb()
				print("Terrain Visual AABB: ", aabb)
				print("Terrain Visual Surface Count: ", tv.mesh.get_surface_count())
				print("Radius X: ", aabb.size.x * 0.5, " | Radius Z: ", aabb.size.z * 0.5)
			else:
				print("Terrain_Visual mesh missing")
		else:
			print("TerrainGenerator missing")
		remove_child(inst)
		inst.free()
		print("PASSED: ", lvl_path)
		
	print("\n--- ALL LEVELS VERIFIED SUCCESSFULLY ---")
	get_tree().quit(0)
