# test_load.gd
extends Node

func _ready():
	print("--- TEST LOAD START ---")
	var path = "res://levels/CanyonLevel.tscn"
	print("Checking file exists: ", FileAccess.file_exists(path))
	var res = load(path)
	print("Loaded resource: ", res)
	if res:
		var inst = res.instantiate()
		print("Instantiated scene: ", inst)
		if inst:
			var tg = inst.get_node_or_null("TerrainGenerator")
			print("TerrainGenerator node: ", tg)
			if tg:
				print("Calling generate_world...")
				tg.generate_world()
				print("generate_world completed!")
	get_tree().quit(0)
