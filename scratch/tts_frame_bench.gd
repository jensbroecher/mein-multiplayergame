extends SceneTree

var commentator
var frame_count := 0
var spoken := false
var max_frame_time := 0.0

func _init():
	print("Starting frame test...")
	var root_node = Node.new()
	root.add_child(root_node)

	var script_node = Node.new()
	root_node.add_child(script_node)

	var timer = 0.0
	var voice = ""
	var voices = DisplayServer.tts_get_voices_for_language("en")
	if not voices.is_empty():
		voice = voices[0]

	script_node.set_process(true)
	var last_tick = Time.get_ticks_usec()
	
	# We will monitor 300 frames
	var check_loop = func():
		pass

	# Connect process
	var frame_times = []
	var speak_frame = 60
	var speak_frame_2 = 120

	var callable = func():
		for f in range(240):
			var t_start = Time.get_ticks_usec()
			
			if f == speak_frame:
				var t0 = Time.get_ticks_usec()
				DisplayServer.tts_speak("Player 1 has taken the lead!", voice, 50, 1.0, 1.12, 0, false)
				var t1 = Time.get_ticks_usec()
				print("Frame %d: tts_speak took %f ms" % [f, (t1 - t0) / 1000.0])
			elif f == speak_frame_2:
				var t0 = Time.get_ticks_usec()
				DisplayServer.tts_speak("Player 2 moves into the lead!", voice, 50, 1.0, 1.12, 0, false)
				var t1 = Time.get_ticks_usec()
				print("Frame %d: tts_speak 2 took %f ms" % [f, (t1 - t0) / 1000.0])

			OS.delay_msec(16) # simulate 60fps frame
			var t_end = Time.get_ticks_usec()
			var duration = (t_end - t_start) / 1000.0
			if duration > 25.0:
				print("Spike at frame %d: %f ms" % [f, duration])

		DisplayServer.tts_stop()
		quit()

	callable.call_deferred()
