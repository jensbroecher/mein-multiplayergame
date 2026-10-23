extends SceneTree

func _init() -> void:
	var files := [
		"res://sounds/enginesounds/engine_mudrunner_loop.wav",
		"res://sounds/enginesounds/engine_phantom_electric_loop.wav",
		"res://sounds/enginesounds/engine_shadow_electric_loop.wav",
		"res://sounds/enginesounds/engine_apex_loop.wav",
		"res://sounds/enginesounds/engine_zephyr_electric_loop.wav"
	]
	for path in files:
		var stream: AudioStreamWAV = load(path)
		if stream == null:
			print("Could not load ", path)
			continue
		var data: PackedByteArray = stream.data
		var sample_count: int = 0
		var sum_sq: float = 0.0

		for i in range(0, data.size() - 1, 2):
			var sample_int := data.decode_s16(i)
			var sample_float := float(sample_int) / 32768.0
			sum_sq += sample_float * sample_float
			sample_count += 1

		var rms := sqrt(sum_sq / float(sample_count)) if sample_count > 0 else 0.0
		var gain_db := 20.0 * log(0.328 / rms) / log(10.0) if rms > 0.0 else 0.0
		print("%-35s: length=%.2fs  rms=%.5f  gain_db=%+.2f" % [
			path.get_file(), stream.get_length(), rms, gain_db
		])
	quit(0)
