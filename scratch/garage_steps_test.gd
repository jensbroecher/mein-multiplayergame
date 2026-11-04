extends Node

# The garage walker's head bob and footsteps (Garage._update_steps): holds W (then Shift too) with real key
# events and prints the steps heard per second, the head's dip and sway, and that it settles once stopped.
#   Godot --headless --path . --fixed-fps 60 res://scratch/garage_steps_test.tscn

var steps := 0


func _key(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	MusicManager.child_entered_tree.connect(func(n: Node):
		if n is AudioStreamPlayer and n.stream and n.stream.resource_path.contains("footstep"):
			steps += 1)
	var garage: Control = load("res://Garage.gd").new()
	add_child(garage)
	for i in 50:
		await get_tree().process_frame
	garage.start()
	for i in 30:
		await get_tree().process_frame
	garage._player.global_position = Vector3(0.0, 0.05, garage._spine_end + 20.0)
	for phase in [["walk", [KEY_W]], ["run", [KEY_W, KEY_SHIFT]]]:
		for k in phase[1]:
			_key(k, true)
		steps = 0
		var y0 := 99.0
		var y1 := -99.0
		var x0 := 99.0
		var x1 := -99.0
		var dist := 0.0
		var last: Vector3 = garage._player.global_position
		for i in 180:
			await get_tree().physics_frame
			if i > 30:
				var h: Vector3 = garage._head.position
				y0 = minf(y0, h.y); y1 = maxf(y1, h.y); x0 = minf(x0, h.x); x1 = maxf(x1, h.x)
				dist += garage._player.global_position.distance_to(last)
			last = garage._player.global_position
		var secs := 180.0 / Engine.physics_ticks_per_second
		print("%s: %d steps in %.1fs (%.1f/s), %.1fm, head dips %.1fcm, sways %.1fcm" % [phase[0], steps, secs,
				steps / secs, dist, (y1 - y0) * 100.0, (x1 - x0) * 100.0])
		for k in phase[1]:
			_key(k, false)
		for i in 60:
			await get_tree().physics_frame
		print("  stopped: head at %s (eye %.2f), %d steps after" % [str(garage._head.position), garage.EYE, steps])
	get_tree().quit()
