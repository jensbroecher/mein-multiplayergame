extends SceneTree

func _init():
	print("Testing WorkerThreadPool with TTS...")
	var voices = DisplayServer.tts_get_voices_for_language("en")
	var voice = voices[0] if not voices.is_empty() else ""

	var task_id = WorkerThreadPool.add_task(func():
		print("Thread running tts_speak...")
		var t0 = Time.get_ticks_usec()
		DisplayServer.tts_speak("Hello from worker thread!", voice, 80, 1.0, 1.12, 0, false)
		var t1 = Time.get_ticks_usec()
		print("Worker thread tts_speak took %f ms" % [(t1 - t0) / 1000.0])
	)

	WorkerThreadPool.wait_for_task_completion(task_id)
	print("Task completed successfully!")
	OS.delay_msec(1000)
	DisplayServer.tts_stop()
	quit()
