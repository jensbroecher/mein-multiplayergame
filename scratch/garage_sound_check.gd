extends Node

# The garage's lift and line-up sounds (Garage.gd's GARAGE_SOUNDS): lifts a car all the way and lowers it, then
# lifts one and lowers it halfway up, raises it again from halfway down, lowers it; puts a car out of the line-up and
# back in. Prints every one-shot as it starts (time, clip, level, pitch, where on the bay) and the hums every 0.25s
# (which plays, level, pitch, the lift's travel), and per rise the locks clacked. The line-up ends as it began.
#   Godot --headless --path . --fixed-fps 60 res://scratch/garage_sound_check.tscn

var garage: Control
var t := 0.0
var shots: Array = []


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	garage = load("res://Garage.gd").new()
	add_child(garage)
	for i in 50:
		await get_tree().process_frame
	garage.start()
	for i in 10:
		await get_tree().process_frame
	var bay: Dictionary = garage._bays[0]
	var root: Node3D = bay["root"]
	root.child_entered_tree.connect(func(n: Node):
		if n is AudioStreamPlayer3D and n.stream:
			var p := n as AudioStreamPlayer3D
			# One-shots are added with their place set; the hums sit by the post. Read them a frame later.
			_note.call_deferred(p))
	print("bay 0: %s, post at x %.2f" % [CAR_NAME(bay), float(bay["post_x"])])

	print("--- full rise, then full lowering")
	garage._begin_inspect(0)
	await _run(3.6)
	_lock_count("rise")
	garage._end_inspect()
	await _run(3.6)
	print("--- rise, lowered from 40% of the way, raised again from 20%, up, lowered")
	garage._begin_inspect(0)
	await _run_until(func(): return float(bay["lift"]) >= 0.4)
	_lock_count("partial rise")
	garage._end_inspect()
	await _run_until(func(): return float(bay["lift"]) <= 0.2)
	garage._begin_inspect(0)
	await _run(3.0)
	_lock_count("rise from 20%")
	garage._end_inspect()
	await _run(3.6)
	var humming: bool = bay.get("humming", false)
	print("hums still on after the lowering: %s" % humming)

	print("--- the line-up: out and back in")
	var idx := 1
	var was_in: bool = garage.CarCollection.in_lineup(garage._bays[idx]["index"])
	var root1: Node3D = garage._bays[idx]["root"]
	root1.child_entered_tree.connect(func(n: Node):
		if n is AudioStreamPlayer3D:
			_note.call_deferred(n))
	garage._toggle_lineup(idx)
	await _run(0.5)
	garage._toggle_lineup(idx)
	await _run(0.5)
	var now_in: bool = garage.CarCollection.in_lineup(garage._bays[idx]["index"])
	print("line-up as it began: %s" % (now_in == was_in))
	get_tree().quit()


func CAR_NAME(bay: Dictionary) -> String:
	return str(garage.CAR_PRESETS[bay["index"]].name)


func _note(p: AudioStreamPlayer3D) -> void:
	if not is_instance_valid(p) or not p.playing:
		return
	var file: String = p.stream.resource_path.get_file()
	if file.contains("loop"):
		return
	shots.append(file)
	print("%6.2fs  %-22s %6.1f dB  pitch %.2f  at (%.2f, %.2f, %.2f)" % [t, file, p.volume_db, p.pitch_scale,
			p.position.x, p.position.y, p.position.z])


func _lock_count(what: String) -> void:
	print("        %s: %d lock clacks" % [what, shots.count("lift_lock_click.wav")])
	shots.clear()


func _run(seconds: float) -> void:
	var end := t + seconds
	await _run_until(func(): return t >= end)


func _run_until(done: Callable) -> void:
	var next_log := t
	while not done.call():
		await get_tree().process_frame
		t += 1.0 / 60.0
		if t >= next_log:
			next_log += 0.25
			var bay: Dictionary = garage._bays[0]
			var line := "%6.2fs  lift %.2f" % [t, float(bay["lift"])]
			for key in bay.get("hums", {}):
				var p: AudioStreamPlayer3D = bay["hums"][key]
				if p.playing:
					line += "   %s %.1f dB pitch %.2f" % [key, p.volume_db, p.pitch_scale]
			print(line)
