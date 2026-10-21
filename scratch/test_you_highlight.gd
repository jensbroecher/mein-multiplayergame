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
	
	race_ui.show_explosion_notice("Jens", "Viper", 1, 2, "MISSILE")
	
	var card = race_ui.killfeed_container.get_child(0)
	var hbox = card.get_child(0)
	var atk_lbl = hbox.get_child(1) # icon is 0, atk_lbl is 1
	print("Atk label text: '", atk_lbl.text, "'")
	assert(atk_lbl.text == "Jens (YOU)", "Expected 'Jens (YOU)', got: " + atk_lbl.text)
	print("YOU highlight test PASSED!")
	
	quit()
