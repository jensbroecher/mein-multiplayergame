extends SceneTree

# Writes the knock sounds KnockableProps.gd synthesises (plastic, parasol, the cones' thud) and KickBall.gd's kicks
# (football, beach ball) out as .wav, with each one's peak and RMS in dBFS, to listen to them:
#   Godot --headless --path . -s res://scratch/knock_sound_dump.gd -- <dir>


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else "user://knock_sounds"
	DirAccess.make_dir_recursive_absolute(dir)
	var kp: Script = load("res://KnockableProps.gd")
	var kb: Script = load("res://KickBall.gd")
	var sounds := {
		"knock_plastic": kp._synth_sound(1),
		"knock_parasol": kp._synth_sound(2),
		"knock_cone_thud": kp._synth_sound(3),
		"kick_football": kb._thump(0),
		"kick_beachball": kb._thump(1),
	}
	for key in sounds:
		var wav: AudioStreamWAV = sounds[key]
		var path: String = dir.path_join(key + ".wav")
		wav.save_to_wav(path)
		var peak := 0.0
		var sum := 0.0
		var n: int = wav.data.size() / 2
		for i in n:
			var v := wav.data.decode_s16(i * 2) / 32768.0
			peak = maxf(peak, absf(v))
			sum += v * v
		print("%s: %.2fs, peak %.1f dBFS, RMS %.1f dBFS -> %s" % [key, float(n) / wav.mix_rate, linear_to_db(peak), linear_to_db(sqrt(sum / n)), path])
	quit()
