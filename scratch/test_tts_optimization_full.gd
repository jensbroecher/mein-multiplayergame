extends Node

func _ready():
	print("--- Running Full TTS Optimization & Settings Test ---")
	
	# 1. Test Commentator Warm Up & Say
	var Commentator = load("res://RaceCommentator.gd")
	Commentator.warm_up()
	var c = Commentator.new()
	add_child(c)
	c.begin()
	
	var heard = []
	c.said.connect(func(t): heard.append(t))

	# Initial speech timing test
	var t0 = Time.get_ticks_usec()
	c._say("Optimized speech test 1: leader is Jens.")
	var t1 = Time.get_ticks_usec()
	var say_ms = (t1 - t0) / 1000.0
	print("c._say() execution time: %f ms" % say_ms)
	assert(say_ms < 1.0, "c._say() should take less than 1ms")
	
	# 2. Test PauseMenu options hookup
	var pause_scene = load("res://PauseMenu.tscn").instantiate()
	add_child(pause_scene)
	assert(pause_scene.option_commentary != null, "PauseMenu must have option_commentary")
	
	# Test toggling OFF via PauseMenu
	pause_scene._on_commentary_selected(0)
	assert(MusicManager.commentary_enabled == false, "MusicManager commentary_enabled must be false")
	assert(pause_scene.option_commentary.selected == 0, "PauseMenu option_commentary selected must be 0")
	
	# Verify speech is muted when disabled
	heard.clear()
	c._say("This should not be spoken via TTS because it is disabled.")
	assert(heard.size() == 1, "said signal still emitted")
	
	# Test toggling ON via PauseMenu
	pause_scene._on_commentary_selected(1)
	assert(MusicManager.commentary_enabled == true, "MusicManager commentary_enabled must be true")
	
	# Test PauseMenu show_pause_menu sync
	pause_scene.show_pause_menu()
	assert(pause_scene.option_commentary.selected == 1, "option_commentary should sync to 1")
	pause_scene.hide()
	pause_scene.queue_free()

	# 3. Test ConfigurationMenu settings hookup
	var config_menu = load("res://ConfigurationMenu.tscn").instantiate()
	add_child(config_menu)
	assert(config_menu.check_commentary != null, "ConfigurationMenu must have check_commentary")
	assert(config_menu.slider_commentary != null, "ConfigurationMenu must have slider_commentary")
	config_menu.queue_free()
	
	# 4. Measure repeated rapid utterances to ensure 0 frame drops
	var max_say_ms := 0.0
	for i in range(5):
		var test_t0 = Time.get_ticks_usec()
		c._say("Rapid call %d" % i)
		var test_t1 = Time.get_ticks_usec()
		var dur = (test_t1 - test_t0) / 1000.0
		if dur > max_say_ms:
			max_say_ms = dur
	print("Max rapid _say() time across 5 calls: %f ms" % max_say_ms)
	assert(max_say_ms < 0.5, "Max rapid _say time must be well under 0.5ms")

	c.queue_free()
	print("ALL TESTS PASSED SUCCESSFULLY!")
	get_tree().quit()
