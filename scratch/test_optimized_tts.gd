extends Node

func _ready():
	print("Testing optimized commentator TTS logic...")
	var Commentator = load("res://RaceCommentator.gd")
	Commentator.warm_up()
	
	# Give warm_up worker task a moment to complete
	OS.delay_msec(100)

	var c = Commentator.new()
	add_child(c)

	var heard = []
	c.said.connect(func(t): heard.append(t))

	var t0 = Time.get_ticks_usec()
	c._say("Testing announcer voice optimization.")
	var t1 = Time.get_ticks_usec()
	var duration_ms = (t1 - t0) / 1000.0
	print("c._say() took: %f ms (must be < 1.0 ms, ideally < 0.1 ms)" % duration_ms)

	# Wait a bit for audio to play
	OS.delay_msec(1500)
	print("is_speaking: ", c._is_speaking())
	c.queue_free()
	print("Test finished successfully!")
	get_tree().quit()
