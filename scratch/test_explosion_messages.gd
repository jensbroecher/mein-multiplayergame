extends Node

func _ready():
	print("--- Testing Explosion Messages (Narrator & UI) ---")
	
	# 1. Test Commentator callouts
	var Commentator = load("res://RaceCommentator.gd")
	var c = Commentator.new()
	add_child(c)
	c.begin()

	var heard = []
	c.said.connect(func(t): heard.append(t))

	# Test targeted explosion call
	c.call_explosion("Jens", "Viper")
	# Run a tiny bit so pending queue processes
	c._process(0.25)
	assert(heard.size() == 1, "Narrator should say explosion line")
	print("Narrator line 1: ", heard[0])
	assert("Jens" in heard[0] and "Viper" in heard[0], "Line must contain attacker and victim")

	# Test rapid explosion spam filtering
	c.call_explosion("Apex", "Shadow")
	c._process(0.25)
	assert(heard.size() == 1, "Rapid call within cooldown should be dropped/throttled")

	# Test self-inflicted call after cooldown
	c._clock += 3.0
	c.call_explosion("Jens", "Jens")
	c._process(0.25)
	assert(heard.size() == 2, "Self-inflicted explosion should be called after cooldown")
	print("Narrator line 2: ", heard[1])
	assert("Jens" in heard[1], "Self-inflicted line must contain racer name")

	c.queue_free()

	# 2. Test RaceUI Killfeed Notice
	var race_ui = load("res://RaceUI.tscn").instantiate()
	add_child(race_ui)
	race_ui.show_hud()

	assert(race_ui.killfeed_container != null, "RaceUI must have killfeed_container")
	race_ui.show_explosion_notice("Jens", "Viper", 1, 2)
	assert(race_ui.killfeed_container.get_child_count() == 1, "Killfeed should have 1 active card")

	race_ui.show_explosion_notice("Shadow", "Apex", 3, 4)
	assert(race_ui.killfeed_container.get_child_count() == 2, "Killfeed should have 2 active cards")

	race_ui.show_explosion_notice("Blaze", "Blaze", 5, 5)
	assert(race_ui.killfeed_container.get_child_count() == 3, "Killfeed should have 3 active cards")

	# Overflow test: adding a 4th card should cap at 3
	race_ui.show_explosion_notice("Nova", "Apex", 6, 4)
	assert(race_ui.killfeed_container.get_child_count() == 3, "Killfeed should cap at 3 active cards")

	race_ui.queue_free()
	print("ALL EXPLOSION NARRATOR & UI TESTS PASSED SUCCESSFULLY!")
	get_tree().quit()
