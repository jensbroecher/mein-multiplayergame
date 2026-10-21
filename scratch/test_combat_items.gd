extends SceneTree

func _initialize() -> void:
	print("--- Running Combat Items & Announcer Test ---")
	
	# 1. Test RaceCommentator with weapons & lightning
	var Commentator = load("res://RaceCommentator.gd")
	var comm = Commentator.new()
	root.add_child(comm)
	comm.begin()
	
	print("[1/3] Testing RaceCommentator voice line generation...")
	comm.call_explosion("Jens", "Viper", "MISSILE")
	assert(!comm._pending.is_empty(), "Expected pending voice line for missile")
	var m_line = comm._pending.pop_front()["text"]
	print("  Missile line: ", m_line)
	assert("missile" in m_line.to_lower() or "rocket" in m_line.to_lower(), "Should mention missile or rocket")
	
	comm._last_explosion_call = -1000.0
	comm.call_explosion("Shadow", "Apex", "GUIDED_MISSILE")
	var gm_line = comm._pending.pop_front()["text"]
	print("  Guided missile line: ", gm_line)
	assert("guided missile" in gm_line.to_lower() or "homing" in gm_line.to_lower(), "Should mention guided missile")
	
	comm._last_explosion_call = -1000.0
	comm.call_explosion("Blaze", "Nova", "BOMB")
	var b_line = comm._pending.pop_front()["text"]
	print("  Bomb line: ", b_line)
	assert("bomb" in b_line.to_lower(), "Should mention bomb")
	
	comm._last_explosion_call = -1000.0
	comm.call_lightning("Jens", "Volt")
	var l_line = comm._pending.pop_front()["text"]
	print("  Lightning single line: ", l_line)
	assert("lightning" in l_line.to_lower() or "zaps" in l_line.to_lower() or "arc" in l_line.to_lower(), "Should mention lightning")

	comm._last_explosion_call = -1000.0
	comm.call_lightning_multi("Jens", ["Volt", "Apex", "Shadow"])
	var lm_line = comm._pending.pop_front()["text"]
	print("  Lightning multi line: ", lm_line)
	assert("lightning" in lm_line.to_lower(), "Should mention lightning in multi strike")
	
	comm._last_explosion_call = -1000.0
	comm.call_explosion("Blaze", "Blaze", "BOMB")
	var sb_line = comm._pending.pop_front()["text"]
	print("  Self bomb line: ", sb_line)
	assert("bomb" in sb_line.to_lower(), "Should mention bomb in self blast")

	comm._last_explosion_call = -1000.0
	comm.call_explosion("Nova", "Nova", "MISSILE")
	var sm_line = comm._pending.pop_front()["text"]
	print("  Self missile line: ", sm_line)
	assert("missile" in sm_line.to_lower() or "rocket" in sm_line.to_lower(), "Should mention missile/rocket in self blast")

	print("  RaceCommentator checks PASSED!")

	# 2. Test RaceUI with all weapons
	print("[2/3] Testing RaceUI killfeed cards...")
	var race_ui = load("res://RaceUI.tscn").instantiate()
	root.add_child(race_ui)
	
	var dummy_cart = Node3D.new()
	dummy_cart.name = "1"
	dummy_cart.set("player_name", "Jens")
	dummy_cart.set("is_local_player", true)
	dummy_cart.set("race_ui", race_ui)
	dummy_cart.add_to_group("player_carts")
	root.add_child(dummy_cart)
	
	await process_frame
	await process_frame
	
	race_ui.show_explosion_notice("Jens", "Viper", 1, 2, "MISSILE")
	race_ui.show_explosion_notice("Shadow", "Apex", 3, 4, "GUIDED_MISSILE")
	race_ui.show_explosion_notice("Volt", "Jens", 5, 1, "LIGHTNING")
	
	await process_frame
	
	assert(race_ui.killfeed_container.get_child_count() == 3, "Expected 3 notices in killfeed")
	print("  Killfeed notices generated: ", race_ui.killfeed_container.get_child_count())
	print("  RaceUI killfeed checks PASSED!")
	
	# 3. Test Countdown has no 's'
	print("[3/3] Testing EndCountdown without 's'...")
	var ec = race_ui.get_node("EndCountdown")
	var hbox = ec.get_node("HBoxContainer")
	var unit = hbox.get_node_or_null("LabelUnit")
	assert(unit == null, "LabelUnit ('s') should be completely removed from EndCountdown!")
	var count = hbox.get_node("LabelCount")
	assert(count != null, "LabelCount must exist")
	race_ui.update_end_timer(15)
	assert(count.text == "15", "Expected '15' without s, got: " + count.text)
	print("  EndCountdown label text: '", count.text, "' (LabelUnit is null: ", unit == null, ")")
	print("  EndCountdown checks PASSED!")

	print("--- ALL COMBAT ITEMS & COUNTDOWN TESTS PASSED! ---")
	quit()
