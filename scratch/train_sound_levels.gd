extends SceneTree
# Prints the RMS (dBFS) of the synthesised train loops (FreightKit.diesel, clatter), which Train.gd's recorded
# loops are levelled against. Godot --headless --path . -s res://scratch/train_sound_levels.gd
func _init() -> void:
	var FK = load("res://FreightKit.gd")
	for n in ["diesel", "clatter"]:
		var w: AudioStreamWAV = FK.call(n)
		var d: PackedByteArray = w.data
		var sum := 0.0
		var cnt := 0
		var stride := 2 * (2 if w.stereo else 1)
		for i in range(0, d.size() - 1, stride * 3):
			var v := float(d.decode_s16(i)) / 32768.0
			sum += v * v
			cnt += 1
		print("%s rms %.1f dBFS stereo=%s" % [n, 20.0 * log(sqrt(sum / cnt)) / log(10.0), w.stereo])
	quit()
