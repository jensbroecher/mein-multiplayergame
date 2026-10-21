extends SceneTree

func _init():
	print("Testing TTS speak timing in detail...")
	var voices = DisplayServer.tts_get_voices_for_language("en")
	var voice = voices[0] if not voices.is_empty() else ""
	print("Using voice: ", voice)

	for i in range(5):
		var text = "Call number %d: Testing announcer voice now." % i
		var t0 = Time.get_ticks_usec()
		DisplayServer.tts_speak(text, voice, 80, 1.0, 1.12, 0, false)
		var t1 = Time.get_ticks_usec()
		print("tts_speak call %d took %f ms" % [i, (t1 - t0) / 1000.0])
		
		# Let it speak for 1.5 seconds, polling tts_is_speaking
		var wait_start = Time.get_ticks_msec()
		var poll_times = []
		while Time.get_ticks_msec() - wait_start < 1500:
			var pt0 = Time.get_ticks_usec()
			var speaking = DisplayServer.tts_is_speaking()
			var pt1 = Time.get_ticks_usec()
			poll_times.append((pt1 - pt0) / 1000.0)
			OS.delay_msec(16)

		var max_poll = 0.0
		for p in poll_times:
			if p > max_poll: max_poll = p
		print("  Max poll time: %f ms" % max_poll)
		DisplayServer.tts_stop()
		OS.delay_msec(200)

	quit()
