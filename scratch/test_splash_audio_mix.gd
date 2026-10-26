extends SceneTree

# Records the audio output of SplashScreen to test mix and timing
var _rec: AudioEffectRecord
var _t_splash := -1
var _saved := false

func _initialize() -> void:
	# Add record effect to Master bus
	var bus_idx := AudioServer.get_bus_index("Master")
	_rec = AudioEffectRecord.new()
	AudioServer.add_bus_effect(bus_idx, _rec)
	_rec.set_recording_active(true)

	change_scene_to_file("res://Main.tscn")

func _process(_delta: float) -> bool:
	var main := current_scene
	if main == null or not main.has_node("SplashCanvas"):
		return false
	if _t_splash < 0:
		_t_splash = Time.get_ticks_msec()
		print("SplashScreen active, recording...")
	var elapsed := (Time.get_ticks_msec() - _t_splash) / 1000.0
	if elapsed >= 5.0 and not _saved:
		_saved = true
		_rec.set_recording_active(false)
		var recording := _rec.get_recording()
		if recording != null:
			recording.save_to_wav("scratch/recorded_splash_mix.wav")
			print("Saved scratch/recorded_splash_mix.wav successfully")
		else:
			print("Recording was null")
		return true
	return false
