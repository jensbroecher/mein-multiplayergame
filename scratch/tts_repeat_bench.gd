extends SceneTree

func _init():
	for i in 5:
		var t0 = Time.get_ticks_usec()
		var v = DisplayServer.tts_get_voices_for_language("en")
		var t1 = Time.get_ticks_usec()
		print("Call %d: tts_get_voices_for_language took %f ms" % [i, (t1 - t0) / 1000.0])

	quit()
