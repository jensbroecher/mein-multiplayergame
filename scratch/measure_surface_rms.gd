extends SceneTree

# Measures the RMS level (dBFS) of each new recorded surface clip, the way StageAmbience's
# CLIP_DB table is built, so Surfaces.gd can normalise them to match the synthesised loops'
# -16 dBFS baseline. Run headless: Godot --headless --path . -s res://scratch/measure_surface_rms.gd

func _init() -> void:
	var files := [
		"res://sounds/continuous_gravel_tire_1.wav",
		"res://sounds/continuous_gravel_tire_2.wav",
		"res://sounds/continuous_gravel_tire_3.wav",
		"res://sounds/continuous_gravel_tire_4.wav",
		"res://sounds/continuous_sand_crunching.wav",
		"res://sounds/continuous_sand_crunching_2.wav",
		"res://sounds/continuous_sand_tire_2.wav",
		"res://sounds/driving_on_ice_1.wav",
		"res://sounds/driving_on_ice_2.wav",
		"res://sounds/driving_on_ice_3.wav",
		"res://sounds/driving_on_snow_1.wav",
		"res://sounds/driving_on_snow_2.wav",
		"res://sounds/driving_on_snow_3.wav",
		"res://sounds/snow_impact_and_driving.wav",
	]
	for path in files:
		var stream: AudioStreamWAV = load(path)
		if stream == null:
			print("Could not load ", path)
			continue
		var data: PackedByteArray = stream.data
		var sample_count: int = 0
		var sum_sq: float = 0.0
		var stereo := stream.stereo
		for i in range(0, data.size() - 1, 2):
			var sample_int := data.decode_s16(i)
			var sample_float := float(sample_int) / 32768.0
			sum_sq += sample_float * sample_float
			sample_count += 1
		var rms := sqrt(sum_sq / float(sample_count)) if sample_count > 0 else 0.0
		var dbfs := 20.0 * log(rms) / log(10.0) if rms > 0.0 else -120.0
		print("%-42s: length=%6.2fs  stereo=%s  rms=%.5f  dBFS=%+6.2f  norm_to_-16dBFS_gain=%+6.2f" % [
			path.get_file(), stream.get_length(), stereo, rms, dbfs, -16.0 - dbfs
		])
	quit(0)
