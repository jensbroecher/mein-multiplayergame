extends SceneTree

class MockCart extends Node3D:
	var race_ui = null
	var player_name: String = "Jens"
	var is_local_player: bool = true
	var device_id: int = 0

func _initialize() -> void:
	var race_ui = load("res://RaceUI.tscn").instantiate()
	root.add_child(race_ui)
	
	var mock = MockCart.new()
	mock.name = "1"
	mock.race_ui = race_ui
	mock.add_to_group("player_carts")
	root.add_child(mock)
	
	await process_frame
	await process_frame
	
	# Show countdown timer as well to verify it has no 's'
	race_ui.update_end_timer(28)
	
	# Temporarily allow 4 notices for preview capture
	race_ui.killfeed_container.offset_top = 115.0
	race_ui.killfeed_container.add_theme_constant_override("separation", 8)
	
	# Notice 1: Local player shoots Missile
	race_ui.show_explosion_notice("Jens", "Viper", 1, 2, "MISSILE")
	# Notice 2: Homing Guided Missile between opponents
	race_ui.show_explosion_notice("Shadow", "Apex", 3, 4, "GUIDED_MISSILE")
	# Notice 3: Self Bomb blast
	race_ui.show_explosion_notice("Blaze", "Blaze", 5, 5, "BOMB")
	# Notice 4: Local player zaps opponent with Lightning Arc
	race_ui.show_explosion_notice("Jens", "Volt", 1, 6, "LIGHTNING")
	
	# Force cards fully opaque and positioned for screenshot
	for child in race_ui.killfeed_container.get_children():
		child.modulate.a = 1.0
		child.scale = Vector2.ONE
	
	await process_frame
	await process_frame
	
	var vp = root.get_viewport()
	var img = vp.get_texture().get_image()
	if img:
		img.save_png("res://scratch/killfeed_items_preview.png")
		print("Successfully saved killfeed_items_preview.png!")
	
	quit()
