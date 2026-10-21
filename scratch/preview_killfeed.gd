extends Node

func _ready():
	var race_ui = load("res://RaceUI.tscn").instantiate()
	add_child(race_ui)
	race_ui.show_hud()
	
	# Add sample standings so the HUD looks alive
	race_ui.update_standings([
		{"id": 1, "pos": 1, "name": "Jens", "finished": false},
		{"id": 2, "pos": 2, "name": "Viper", "finished": false},
		{"id": 3, "pos": 3, "name": "Apex", "finished": false},
		{"id": 4, "pos": 4, "name": "Shadow", "finished": false}
	], 1)
	race_ui.update_hud(1, 4, 2, 3)

	# Mock a local player cart so my_id is detected as 1
	var mock_cart = Node.new()
	mock_cart.name = "1"
	mock_cart.set("race_ui", race_ui)
	mock_cart.add_to_group("player_carts")
	add_child(mock_cart)

	# 1. Local player blew up an opponent
	race_ui.show_explosion_notice("Jens", "Viper", 1, 2)
	
	await get_tree().create_timer(0.1).timeout
	# 2. Other racers combat
	race_ui.show_explosion_notice("Shadow", "Apex", 4, 3)

	await get_tree().create_timer(0.1).timeout
	# 3. Self-inflicted explosion
	race_ui.show_explosion_notice("Blaze", "Blaze", 5, 5)
	
	await get_tree().create_timer(0.5).timeout
	
	# Capture screenshot
	var img = get_viewport().get_texture().get_image()
	img.save_png("res://scratch/killfeed_preview.png")
	print("Saved screenshot to res://scratch/killfeed_preview.png")
	
	get_tree().quit()
