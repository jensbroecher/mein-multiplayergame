extends SceneTree

func _init() -> void:
	var log_file = FileAccess.open("res://scratch/tts_probe_output.txt", FileAccess.WRITE)
	var log_msg = func(msg):
		print(msg)
		if log_file:
			log_file.store_line(str(msg))
			log_file.flush()
	log_msg.call("TTS Feature available: %s" % DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH))
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		quit()
		return

	var t0 = Time.get_ticks_usec()
	var voices = DisplayServer.tts_get_voices_for_language("en")
	var t1 = Time.get_ticks_usec()
	log_msg.call("tts_get_voices_for_language took: %f ms. Count: %d" % [(t1 - t0) / 1000.0, voices.size()])

	if voices.is_empty():
		var all_voices = DisplayServer.tts_get_voices()
		if not all_voices.is_empty():
			voices.append(all_voices[0]["id"])

	if voices.is_empty():
		log_msg.call("No voices found")
		quit()
		return

	var voice_id = voices[0]
	log_msg.call("Using voice: %s" % voice_id)

	# Measure first tts_speak call
	t0 = Time.get_ticks_usec()
	DisplayServer.tts_speak("First test call", voice_id, 50, 1.0, 1.0, 0, false)
	t1 = Time.get_ticks_usec()
	log_msg.call("First tts_speak took: %f ms" % [(t1 - t0) / 1000.0])

	OS.delay_msec(200)

	# Measure second tts_speak call
	t0 = Time.get_ticks_usec()
	DisplayServer.tts_speak("Second test call", voice_id, 50, 1.0, 1.0, 0, false)
	t1 = Time.get_ticks_usec()
	log_msg.call("Second tts_speak took: %f ms" % [(t1 - t0) / 1000.0])

	# Test thread / WorkerThreadPool
	var thread_time := 0.0
	var th = Thread.new()
	th.start(func():
		var th_t0 = Time.get_ticks_usec()
		DisplayServer.tts_speak("Thread test call", voice_id, 50, 1.0, 1.0, 0, false)
		var th_t1 = Time.get_ticks_usec()
		thread_time = (th_t1 - th_t0) / 1000.0
	)
	th.wait_to_finish()
	log_msg.call("tts_speak in Thread took: %f ms" % thread_time)

	DisplayServer.tts_stop()
	quit()
