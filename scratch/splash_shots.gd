extends Node

# Photographs the title card (SplashScreen.gd) at given moments of its clock. Run windowed with a fixed
# frame rate, so the clock (and the dust, which is simulated per frame) is the same however slowly the
# shots save:
#   Godot --path . --resolution 1600x900 --fixed-fps 30 res://scratch/splash_shots.tscn -- <out_dir>
#       [times=0.5,1.0,2.0,...] [seek=1]
# seek=1 jumps the clock to each time instead of playing up to it (quicker; no dust, since it is made
# as the cars move). bench=1 takes no shots: it plays the title card in real time (leave out --fixed-fps)
# and prints its frame times.
const SplashScreen = preload("res://SplashScreen.gd")


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var times: Array = [0.4, 0.8, 1.2, 1.6, 2.0, 2.4, 3.0, 4.5, 6.0]
	var seek := false
	var bench := false
	for a in args.slice(1):
		if a.begins_with("times="):
			times = []
			for s in a.substr(6).split(","):
				times.append(float(s))
		elif a == "seek=1":
			seek = true
		elif a == "bench=1":
			bench = true
	var splash: Control = load("res://SplashScreen.tscn").instantiate()
	get_tree().root.add_child.call_deferred(splash)
	await get_tree().process_frame
	await get_tree().process_frame
	if bench:
		var frame_times: Array[float] = []
		var last := Time.get_ticks_usec()
		while not splash._done:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			if splash._t > 0.5:
				frame_times.append((now - last) / 1000.0)
				if (now - last) / 1000.0 > 30.0:
					print("  hitch: %.0f ms at clock %.2fs" % [(now - last) / 1000.0, splash._t])
			last = now
		frame_times.sort()
		var n := frame_times.size()
		var mean := 0.0
		for ft in frame_times:
			mean += ft
		print("frame ms over %d frames: median %.1f, mean %.1f, 95th %.1f, worst %.1f (%.0f fps on average)" % [
			n, frame_times[n / 2], mean / n, frame_times[int(n * 0.95)], frame_times[n - 1], 1000.0 / (mean / n)])
		get_tree().quit()
		return
	var shots := 0
	for target in times:
		if seek:
			splash.seek(target)
			for i in 6:
				await get_tree().process_frame
		else:
			while splash._t < target and not splash._done:
				await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/splash_%04.1f.png" % [out, target])
		print("SHOT %.1fs (clock %.2f)" % [target, splash._t])
		shots += 1
	print("done, %d shots" % shots)
	get_tree().quit()
