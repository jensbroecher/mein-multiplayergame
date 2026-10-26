extends SceneTree

# Test if AudioStreamPlayer3D inside SubViewport is captured by AudioServer
var _rec: AudioEffectRecord
var _t0 := 0
var _saved := false

func _initialize() -> void:
	var bus_idx := AudioServer.get_bus_index("Master")
	_rec = AudioEffectRecord.new()
	AudioServer.add_bus_effect(bus_idx, _rec)
	_rec.set_recording_active(true)

	var root_node := Node.new()
	root.add_child(root_node)

	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.audio_listener_enable_3d = true
	root_node.add_child(vp)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 2, 10)
	cam.current = true
	vp.add_child(cam)

	var player := AudioStreamPlayer3D.new()
	player.position = Vector3(0, 0, 0)
	player.stream = load("res://sounds/enginesounds/engine_mudrunner_loop.wav")
	player.unit_size = 10.0
	player.max_distance = 50.0
	player.volume_db = -10.0
	vp.add_child(player)
	player.play()

	_t0 = Time.get_ticks_msec()

func _process(_delta: float) -> bool:
	var elapsed := (Time.get_ticks_msec() - _t0) / 1000.0
	if elapsed >= 1.0 and not _saved:
		_saved = true
		_rec.set_recording_active(false)
		var recording := _rec.get_recording()
		if recording != null:
			var frames := recording.data.size()
			print("AudioStreamPlayer3D in SubViewport captured bytes: ", frames)
		else:
			print("Recording null")
		return true
	return false
