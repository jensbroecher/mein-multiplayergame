extends SceneTree

func _initialize() -> void:
	var race_ui = load("res://RaceUI.tscn").instantiate()
	root.add_child(race_ui)
	
	# Mock local player
	var dummy_cart = Node3D.new()
	dummy_cart.name = "1"
	dummy_cart.set("player_name", "Jens")
	dummy_cart.set("is_local_player", true)
	dummy_cart.set("race_ui", race_ui)
	dummy_cart.add_to_group("player_carts")
	root.add_child(dummy_cart)
	
	await process_frame
	await process_frame
	
	print("Ready to test killfeed with items!")
	quit()
