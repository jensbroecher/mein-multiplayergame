extends SceneTree

# Plays the game's real start-up and drives the title card's input: moving the mouse to the window's edges
# and pushing a stick must shift the view (and not skip the card), the stick winning over the mouse and
# letting go falling back to it, and then a pad button must skip the card and hand over to the menu.
# Run windowed:  Godot --path . --resolution 1600x900 -s res://scratch/splash_input_test.gd
var _step := 0
var _at := 1.0
var _fails := 0


func _initialize() -> void:
	change_scene_to_file("res://Main.tscn")


func _process(_delta: float) -> bool:
	var main := current_scene
	if main == null or main.name != "Main":
		return false
	if _step >= 6:
		# The card was skipped: wait for the menu.
		if not main.has_node("SplashCanvas") and main.get_node("MainMenu").visible:
			_check("the pad button skipped the card and the menu is up", true)
			print("RESULT: %s" % ("all passed" if _fails == 0 else "%d FAILED" % _fails))
			return true
		return false
	if not main.has_node("SplashCanvas/SplashScreen"):
		return false
	var splash: Control = main.get_node("SplashCanvas/SplashScreen")
	var t: float = splash._t
	if t < _at:
		return false
	var look: Vector2 = splash._look
	# Mouse events carry the window's canvas coordinates, which is what the card divides them by.
	var size := splash.get_viewport_rect().size
	match _step:
		0:
			_check("starts level (look %s)" % look, look.length() < 0.01)
			_mouse(Vector2(size.x - 1.0, size.y * 0.5))
			_at = t + 1.5
		1:
			_check("mouse at the right edge looks right (look %s)" % look, look.x > 0.85 and absf(look.y) < 0.1)
			_mouse(Vector2(1.0, size.y * 0.5))
			_at = t + 1.5
		2:
			_check("mouse at the left edge looks left (look %s)" % look, look.x < -0.85 and absf(look.y) < 0.1)
			_mouse(size * 0.5)
			_stick(JOY_AXIS_RIGHT_Y, 0.8)
			_at = t + 1.5
		3:
			# (0.8 - 0.2) / (1 - 0.2) = 0.75 once the dead zone is taken off.
			_check("a stick pushed down looks down, the mouse at the centre ignored (look %s)" % look, absf(look.y - 0.75) < 0.05 and absf(look.x) < 0.05)
			_stick(JOY_AXIS_RIGHT_Y, 0.0)
			_stick(JOY_AXIS_LEFT_X, -0.1)
			_mouse(Vector2(size.x - 1.0, size.y * 0.5))
			_at = t + 1.5
		4:
			_check("a stick inside its dead zone leaves the mouse in charge (look %s)" % look, look.x > 0.85)
			_check("none of that skipped the card", not splash._done)
			var ev := InputEventJoypadButton.new()
			ev.button_index = JOY_BUTTON_A
			ev.pressed = true
			Input.parse_input_event(ev)
			_at = t
		5:
			pass
	_step += 1
	return false


## Moves the mouse to a place in the window's canvas coordinates. An injected event is read as window pixels,
## which the viewport then scales back to canvas coordinates (as it does for the real mouse), so the
## place is sent through the window's stretch transform first.
func _mouse(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = root.get_final_transform() * pos
	ev.global_position = ev.position
	ev.relative = Vector2(4, 0)
	Input.parse_input_event(ev)


func _stick(axis: int, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	Input.parse_input_event(ev)


func _check(label: String, ok: bool) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", label])
	if not ok:
		_fails += 1
