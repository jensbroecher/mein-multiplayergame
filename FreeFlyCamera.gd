extends Node3D

## Inspection camera: no cars, just the course. Hold the left or right mouse button to look, or swipe
## with two fingers on a trackpad (pinch to dolly forward and back). WASD to fly, Q/E down/up, Shift
## fast, Ctrl slow, mouse wheel changes the speed. The left stick flies and the right stick looks on
## a pad (triggers fly down and up).
const BASE_SPEED := 30.0
const FAST_MULT := 4.0
const SLOW_MULT := 0.2
const SPEED_MIN := 2.0
const SPEED_MAX := 600.0
const LOOK_SENS := 0.0028
const PAN_LOOK_SENS := 0.02  # per unit of a trackpad swipe, which arrives in much smaller steps than pixels
const PINCH_DOLLY := 40.0  # metres per unit of pinch, scaled by the fly speed
const STICK_LOOK := 2.2
const DEAD := 0.15

var speed: float = BASE_SPEED

var _cam: Camera3D
var _yaw := 0.0
var _pitch := 0.0
var _looking := false
var _look_buttons := {}
var _label: Label


func _ready() -> void:
	_cam = Camera3D.new()
	_cam.name = "Camera3D"
	_cam.current = true
	_cam.fov = 70.0
	_cam.far = 6000.0
	add_child(_cam)
	var listener := AudioListener3D.new()
	listener.current = true
	_cam.add_child(listener)

	var layer := CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(28, 18)
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95, 0.9))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(_label)
	_refresh_label()


## Puts the camera at `pos` looking at `target`.
func place(pos: Vector3, target: Vector3) -> void:
	global_position = pos
	var d := target - pos
	_yaw = atan2(-d.x, -d.z)
	_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	_apply_rotation()


func _apply_rotation() -> void:
	rotation = Vector3(_pitch, _yaw, 0.0)


func _refresh_label() -> void:
	_label.text = "INSPECTION  |  LMB/RMB drag or trackpad swipe: look  |  Pinch: forward/back  |  WASD: fly  |  Q/E: down/up  |  Shift/Ctrl: faster/slower  |  Wheel: speed (%d m/s)  |  Esc/Backspace: menu" % int(speed)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_look_buttons[event.button_index] = true
			else:
				_look_buttons.erase(event.button_index)
			_looking = not _look_buttons.is_empty()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _looking else Input.MOUSE_MODE_VISIBLE
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			speed = minf(speed * 1.2, SPEED_MAX)
			_refresh_label()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			speed = maxf(speed / 1.2, SPEED_MIN)
			_refresh_label()
	elif event is InputEventMouseMotion and _looking:
		_yaw -= event.relative.x * LOOK_SENS
		_pitch = clampf(_pitch - event.relative.y * LOOK_SENS, -PI * 0.495, PI * 0.495)
		_apply_rotation()
	elif event is InputEventPanGesture:
		_yaw -= event.delta.x * PAN_LOOK_SENS
		_pitch = clampf(_pitch - event.delta.y * PAN_LOOK_SENS, -PI * 0.495, PI * 0.495)
		_apply_rotation()
	elif event is InputEventMagnifyGesture:
		# factor > 1 while the fingers spread: move forward along the view.
		global_position += -global_basis.z * (event.factor - 1.0) * PINCH_DOLLY * (speed / BASE_SPEED)


func _exit_tree() -> void:
	if _looking:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	var move := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): move.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S): move.z += 1.0
	if Input.is_physical_key_pressed(KEY_A): move.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): move.x += 1.0
	if Input.is_physical_key_pressed(KEY_E): move.y += 1.0
	if Input.is_physical_key_pressed(KEY_Q): move.y -= 1.0

	var pad := Input.get_connected_joypads()
	if not pad.is_empty():
		var id: int = pad[0]
		var lx := Input.get_joy_axis(id, JOY_AXIS_LEFT_X)
		var ly := Input.get_joy_axis(id, JOY_AXIS_LEFT_Y)
		var rx := Input.get_joy_axis(id, JOY_AXIS_RIGHT_X)
		var ry := Input.get_joy_axis(id, JOY_AXIS_RIGHT_Y)
		if absf(lx) > DEAD: move.x += lx
		if absf(ly) > DEAD: move.z += ly
		move.y += Input.get_joy_axis(id, JOY_AXIS_TRIGGER_RIGHT) - Input.get_joy_axis(id, JOY_AXIS_TRIGGER_LEFT)
		if absf(rx) > DEAD or absf(ry) > DEAD:
			_yaw -= rx * STICK_LOOK * delta
			_pitch = clampf(_pitch - ry * STICK_LOOK * delta, -PI * 0.495, PI * 0.495)
			_apply_rotation()

	var mult := 1.0
	if Input.is_physical_key_pressed(KEY_SHIFT): mult = FAST_MULT
	elif Input.is_physical_key_pressed(KEY_CTRL): mult = SLOW_MULT
	# Forward follows the view, up and down are world axes.
	var dir := global_basis * Vector3(move.x, 0.0, move.z) + Vector3(0.0, move.y, 0.0)
	global_position += dir * speed * mult * delta
