extends Control
## The garage: a hall the player walks through (first person) to look at their cars, choose which ones
## the car select screen offers (the line-up, CarCollection.gd) and see the Grand Prix trophies they have
## won (Trophies.gd). Built in code, in its own world in a SubViewport, like the podium; Main.gd adds it
## from the main menu (GARAGE), calls start() once the loading screen has gone, and frees it on `finished`.
##
## The hall, looking down it from the door: the foyer with the player's own car on a turntable, then the
## concourse, with a gallery per category (CarCollection.galleries()) off either side, in pairs, and the
## trophy hall at its end. A gallery's cars stand in two rows either side of its aisle, angled toward the
## way in, each on a two-post lift, with a lectern and a spotlight. More cars lengthen the galleries and
## more categories the concourse, so the hall grows with the collection.
##
## A car in the line-up has its bay's floor rim lit in its gallery's colour and its spotlight up; one left
## out stands in a dimmer light with a grey rim. Look at a car (within REACH) and press E to put it in or
## take it out (the last one stays), F to lift it: it goes up on the lift and the camera orbits it, from
## any side and from under it, until F or Esc lowers it again.
##
## Controls: WASD or the left stick walk, Shift or a pressed left stick runs, the mouse or the right stick
## looks; E or the pad's A, F or Y; Esc or B leaves (from an inspection, back to walking). In an
## inspection the mouse or right stick orbits, the wheel, W/S or the triggers zoom.

signal finished

const CarPaint = preload("res://CarPaint.gd")
const CarCollection = preload("res://CarCollection.gd")
const Trophies = preload("res://Trophies.gd")
const PodiumScript = preload("res://Podium.gd")
const CAR_PRESETS = preload("res://PlayerCart.gd").CAR_PRESETS
const CAR_ACCENTS = preload("res://CarSelection.gd").CAR_ACCENTS
## The car select screen's copy of the presets, which has each car's description.
const SELECT_PRESETS = preload("res://CarSelection.gd").CAR_PRESETS
const SKY_SHADER = preload("res://showroom_sky.gdshader")
const FLOOR_SHADER = preload("res://garage_floor.gdshader")
const LOGO_PATH := "res://generated/logo/RcVibeLogo.tscn"

## What PlayerCart scales a car's scene by, and how much bigger than that the cars stand here: about a
## road car's 4m, so the hall reads as a car collection at the walker's eye height.
const CAR_SCALE := 2.0
const SHOW_SCALE := 1.8

# The hall, in metres. The concourse runs from the door (ENTRANCE_Z) toward -z, x within SPINE_HALF.
const WALL_H := 7.0
const WALL_T := 0.4
const WAINSCOT := 1.1
const SPINE_HALF := 6.0
const ENTRANCE_Z := 4.0
## From the door to the first pair of galleries.
const FOYER := 14.0
## A gallery's inside along the concourse, and the pitch of the pairs (a 2m pier between them).
const GALLERY_W := 16.0
const SLOT := 18.0
const DOOR_W := 8.0
const DOOR_H := 4.8
## Along a gallery: from the concourse wall to the first cars, between cars, after the last.
const G_ENTRY := 6.5
const BAY := 7.6
const G_END := 5.5
## A car's middle off its gallery's aisle, and how far it is turned from facing straight across toward the
## way in.
const BAY_SIDE := 4.4
const CAR_TURN := 0.52
const HALL_HALF := 13.0
const HALL_D := 24.0
const TROPHY_RING := 8.0
const PEDESTAL_H := 1.3

# The lifts.
const POST_GAP := 0.45
const POST_H := 3.3
const LIFT_HEIGHT := 2.0
const LIFT_TIME := 3.2
## The pads' top over the carriage's foot, and the carriage's foot at rest (the arms on the dais). A car
## whose underside is lower than the pads at rest just rests on its wheels over them.
const PAD_TOP := 0.17
const LIFT_REST := 0.05

# Walking and looking.
const EYE := 1.7
const WALK_SPEED := 3.4
const RUN_SPEED := 6.5
const MOVE_RATE := 10.0
const MOUSE_LOOK := 0.0022
const STICK_LOOK := 2.4
const STICK_DEADZONE := 0.18
const PITCH_LIMIT := 1.35
const REACH := 7.5
const AIM_CONE := 0.5

# Inspecting.
const ORBIT_MIN := 3.2
const ORBIT_MAX := 11.0
const ORBIT_RATE := 10.0
const ORBIT_PITCH_MIN := -1.1
const ORBIT_PITCH_MAX := 1.3
const CAM_BLEND_TIME := 0.7

# The main menu's palette.
const COL_TEAL := Color(0.15, 0.75, 0.92)
const COL_GOLD := Color(1.0, 0.78, 0.22)
const COL_TEXT := Color(0.93, 0.95, 0.98)
const COL_DIM := Color(0.60, 0.66, 0.76)
const COL_CARD := Color(0.045, 0.052, 0.075, 0.82)
const COL_OFF := Color(0.32, 0.34, 0.38)
const MEDAL := [Color(1.0, 0.78, 0.26), Color(0.84, 0.87, 0.92), Color(0.86, 0.52, 0.26)]
const PLACE_NAMES := ["1ST", "2ND", "3RD"]

enum Mode { WALK, INSPECT }

var _stage: SubViewport
var _world: Node3D
var _player: CharacterBody3D
var _head: Node3D
var _eye_cam: Camera3D
var _orbit_cam: Camera3D
var _walls: StaticBody3D

var _galleries: Array = []
## Per gallery: {name, color, cars, side, rect (Rect2 in x/z of its floor), door_z}.
var _rooms: Array = []
var _spine_end := 0.0
## Per car on show: see _build_bay.
var _bays: Array = []
var _featured: Node3D

var _mode := Mode.WALK
var _started := false
var _yaw := 0.0
var _pitch := 0.0
var _move := Vector3.ZERO
var _target := -1
var _inspected := -1
var _orbit_yaw := 0.0
var _orbit_pitch := 0.2
var _orbit_dist := 6.5
var _orbit_goal := Vector3(0.2, 0.0, 6.5)    # pitch, yaw, dist the orbit eases toward
var _blend := 1.0                            # 0..1: eye to orbit camera (and back)
var _blend_from: Transform3D
var _leaving := false
var _pad := false
var _area := ""
var _time := 0.0

var _mats := {}
var _font_bold: FontVariation
var _font_title: FontVariation
var _hud_count: Label
var _crosshair: Control
var _prompt: PanelContainer
var _prompt_name: Label
var _prompt_info: Label
var _prompt_desc: Label
var _prompt_keys: Label
var _toast: Label
var _toast_tween: Tween
var _banner: Label
var _banner_sub: Label
var _banner_tween: Tween
var _hint: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_galleries = CarCollection.galleries()
	_make_fonts()
	_build_stage()
	_build_hall()
	_build_featured()
	_build_trophies()
	_build_player()
	_build_hud()
	_refresh_count()


## The loading screen has gone: take the mouse and show where we are.
func start() -> void:
	_started = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	_time += delta
	if _featured:
		_featured.rotate_y(delta * 0.22)
	_update_lifts(delta)
	if not _started or _leaving:
		return
	var look := _stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)
	if _mode == Mode.WALK:
		_yaw -= look.x * STICK_LOOK * delta
		_pitch = clampf(_pitch - look.y * STICK_LOOK * 0.75 * delta, -PITCH_LIMIT, PITCH_LIMIT)
		_player.rotation.y = _yaw
		_head.rotation.x = _pitch
		_update_target()
		_update_area()
	else:
		_orbit_goal.y -= look.x * STICK_LOOK * delta
		_orbit_goal.x = clampf(_orbit_goal.x + look.y * STICK_LOOK * 0.75 * delta, ORBIT_PITCH_MIN, ORBIT_PITCH_MAX)
		var zoom := 0.0
		for pad in Input.get_connected_joypads():
			zoom += Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_RIGHT) - Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_LEFT)
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
			zoom += 1.0
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
			zoom -= 1.0
		_orbit_goal.z = clampf(_orbit_goal.z - zoom * 5.0 * delta, ORBIT_MIN, ORBIT_MAX)
	_update_camera(delta)


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	var want := Vector3.ZERO
	if _started and not _leaving and _mode == Mode.WALK:
		var stick := _stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
		var keys := Vector2(
				float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
				- float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
				float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
				- float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
		var dir: Vector2 = (stick + keys).limit_length(1.0)
		var run: bool = Input.is_physical_key_pressed(KEY_SHIFT)
		for pad in Input.get_connected_joypads():
			run = run or Input.is_joy_button_pressed(pad, JOY_BUTTON_LEFT_STICK)
		want = (_player.transform.basis * Vector3(dir.x, 0.0, dir.y)) * (RUN_SPEED if run else WALK_SPEED)
	_move = _move.lerp(want, 1.0 - exp(-MOVE_RATE * delta))
	_player.velocity = Vector3(_move.x, _player.velocity.y - 9.8 * delta, _move.z)
	_player.move_and_slide()
	if _player.is_on_floor():
		_player.velocity.y = 0.0


func _input(event: InputEvent) -> void:
	if not _started or _leaving or not is_visible_in_tree():
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event is InputEventJoypadButton or absf((event as InputEventJoypadMotion).axis_value) > 0.5:
			_set_pad(true)
	elif event is InputEventKey or event is InputEventMouseButton:
		_set_pad(false)
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var rel: Vector2 = (event as InputEventMouseMotion).relative
		if _mode == Mode.WALK:
			_yaw -= rel.x * MOUSE_LOOK
			_pitch = clampf(_pitch - rel.y * MOUSE_LOOK, -PITCH_LIMIT, PITCH_LIMIT)
			_player.rotation.y = _yaw
			_head.rotation.x = _pitch
		else:
			_orbit_goal.y -= rel.x * MOUSE_LOOK * 1.4
			_orbit_goal.x = clampf(_orbit_goal.x + rel.y * MOUSE_LOOK * 1.4, ORBIT_PITCH_MIN, ORBIT_PITCH_MAX)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and _mode == Mode.INSPECT:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_orbit_goal.z = maxf(ORBIT_MIN, _orbit_goal.z - 0.5)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_orbit_goal.z = minf(ORBIT_MAX, _orbit_goal.z + 0.5)
	var lineup_key := false
	var lift_key := false
	var back_key := false
	if event is InputEventKey and event.pressed and not event.echo:
		var k: Key = (event as InputEventKey).physical_keycode
		lineup_key = k == KEY_E or k == KEY_ENTER or k == KEY_SPACE
		lift_key = k == KEY_F
		back_key = k == KEY_ESCAPE or k == KEY_BACKSPACE
	elif event is InputEventJoypadButton and event.pressed:
		var b: JoyButton = (event as InputEventJoypadButton).button_index
		lineup_key = b == JOY_BUTTON_A
		lift_key = b == JOY_BUTTON_Y
		back_key = b == JOY_BUTTON_B or b == JOY_BUTTON_START
	if lineup_key:
		var bay: int = _inspected if _mode == Mode.INSPECT else _target
		if bay >= 0:
			_toggle_lineup(bay)
		get_viewport().set_input_as_handled()
	elif lift_key:
		if _mode == Mode.INSPECT:
			_end_inspect()
		elif _target >= 0:
			_begin_inspect(_target)
		get_viewport().set_input_as_handled()
	elif back_key:
		if _mode == Mode.INSPECT:
			_end_inspect()
		else:
			_leave()
		get_viewport().set_input_as_handled()


## Off to the menu: Main swipes over it and frees it.
func _leave() -> void:
	_leaving = true
	_prompt.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	finished.emit()


## The stick on a pair of axes, past its dead zone, the furthest pushed of the connected pads.
func _stick(ax: JoyAxis, ay: JoyAxis) -> Vector2:
	var best := Vector2.ZERO
	for pad in Input.get_connected_joypads():
		var v := Vector2(Input.get_joy_axis(pad, ax), Input.get_joy_axis(pad, ay))
		if v.length() > best.length():
			best = v
	if best.length() < STICK_DEADZONE:
		return Vector2.ZERO
	return best.normalized() * inverse_lerp(STICK_DEADZONE, 1.0, minf(best.length(), 1.0))


func _set_pad(on: bool) -> void:
	if on == _pad:
		return
	_pad = on
	_hint.text = _hint_text()
	_refresh_prompt()


# ============================================================================================
#  Looking at cars, the line-up and the lifts
# ============================================================================================

## The car the player looks at: the nearest to the middle of the view within REACH and AIM_CONE, that
## no wall hides.
func _update_target() -> void:
	var eye: Vector3 = _eye_cam.global_position
	var fwd: Vector3 = -_eye_cam.global_transform.basis.z
	var best := -1
	var best_score := INF
	for i in _bays.size():
		var c: Vector3 = _bay_centre(i)
		var to := c - eye
		var d := to.length()
		if d > REACH + float(_bays[i]["radius"]) or d < 0.01:
			continue
		var ang := fwd.angle_to(to / d)
		if ang > AIM_CONE:
			continue
		var score := ang * 6.0 + d * 0.1
		if score < best_score:
			best_score = score
			best = i
	if best >= 0:
		var q := PhysicsRayQueryParameters3D.create(eye, _bay_centre(best))
		q.collision_mask = 1
		q.exclude = [_player.get_rid()]
		var hit: Dictionary = _world.get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty() and hit["collider"] == _walls:
			best = -1
	if best != _target:
		_target = best
		_refresh_prompt()


## The middle of a car on show, in the world, wherever its lift has it.
func _bay_centre(i: int) -> Vector3:
	var bay: Dictionary = _bays[i]
	return (bay["car"] as Node3D).global_transform * (bay["centre"] as Vector3)


func _toggle_lineup(i: int) -> void:
	var bay: Dictionary = _bays[i]
	var idx: int = bay["index"]
	var car_name: String = str(CAR_PRESETS[idx].name).to_upper()
	var on := not CarCollection.in_lineup(idx)
	if not CarCollection.set_in_lineup(idx, on):
		_show_toast("%s is the only car left in the line-up" % car_name)
		return
	MusicManager.play_sfx(MusicManager.UI_CONFIRM_SOUND, 0.0, 1.0 if on else 0.82)
	_show_toast(("%s joins the line-up" if on else "%s leaves the line-up") % car_name)
	_show_lineup_state(i, true)
	_refresh_count()
	_refresh_prompt()


## A bay's rim, spotlight and lectern say whether its car is in the line-up.
func _show_lineup_state(i: int, animate: bool) -> void:
	var bay: Dictionary = _bays[i]
	var on: bool = CarCollection.in_lineup(bay["index"])
	var col: Color = bay["color"]
	var rim: StandardMaterial3D = bay["rim_mat"]
	var spot: SpotLight3D = bay["spot"]
	var energy: float = 11.0 if on else 3.2
	var rim_col: Color = col if on else COL_OFF
	var rim_energy: float = 2.6 if on else 0.35
	if animate:
		var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
		tw.tween_property(spot, "light_energy", energy, 0.6)
		tw.tween_property(rim, "emission", rim_col, 0.4)
		tw.tween_property(rim, "emission_energy_multiplier", rim_energy, 0.4)
	else:
		spot.light_energy = energy
		rim.emission = rim_col
		rim.emission_energy_multiplier = rim_energy
	var status: Label3D = bay["status"]
	status.text = "IN THE LINE-UP" if on else "NOT IN THE LINE-UP"
	status.modulate = col.lightened(0.2) if on else COL_DIM


## Moves every lift toward where it is going: the carriage up to the car's underside, then both together
## up LIFT_HEIGHT; down the same way.
func _update_lifts(delta: float) -> void:
	for bay in _bays:
		var goal: float = 1.0 if bay["up"] else 0.0
		if is_equal_approx(bay["lift"], goal):
			continue
		bay["lift"] = move_toward(bay["lift"], goal, delta / LIFT_TIME)
		_pose_lift(bay)


func _pose_lift(bay: Dictionary) -> void:
	var t: float = smoothstep(0.0, 1.0, bay["lift"])
	var rest: float = LIFT_REST
	var top: float = float(bay["contact"]) - PAD_TOP + LIFT_HEIGHT
	var cy: float = lerpf(rest, top, t)
	(bay["carriage"] as Node3D).position.y = cy
	var raise: float = maxf(0.0, cy + PAD_TOP - float(bay["contact"]))
	(bay["car"] as Node3D).position.y = float(bay["car_y"]) + raise
	var lamp: OmniLight3D = bay["lamp"]
	lamp.light_energy = 1.6 * clampf(raise / LIFT_HEIGHT, 0.0, 1.0)
	lamp.visible = lamp.light_energy > 0.01


func _begin_inspect(i: int) -> void:
	_mode = Mode.INSPECT
	_inspected = i
	_bays[i]["up"] = true
	_target = -1
	_crosshair.visible = false
	# Start the orbit where the player stands, so the camera only has to swing up and out a little.
	var c: Vector3 = _bay_centre(i)
	var from: Vector3 = _eye_cam.global_position - c
	_orbit_goal = Vector3(0.28, atan2(from.x, from.z), clampf(Vector2(from.x, from.z).length() + 1.0, 5.5, 8.0))
	_orbit_pitch = clampf(asin(clampf(from.y / maxf(from.length(), 0.01), -1.0, 1.0)), ORBIT_PITCH_MIN, ORBIT_PITCH_MAX)
	_orbit_yaw = _orbit_goal.y
	_orbit_dist = from.length()
	_blend_from = _eye_cam.global_transform
	_blend = 0.0
	_orbit_cam.global_transform = _blend_from
	_orbit_cam.current = true
	MusicManager.play_sfx(MusicManager.UI_CONFIRM_SOUND, -4.0, 0.7)
	_hint.text = _hint_text()
	_refresh_prompt()


func _end_inspect() -> void:
	if _inspected >= 0:
		_bays[_inspected]["up"] = false
	_mode = Mode.WALK
	_blend_from = _orbit_cam.global_transform
	_blend = 0.0
	_hint.text = _hint_text()
	_crosshair.visible = true
	_inspected = -1
	_refresh_prompt()


## The orbit eases toward its goal and follows the car up; the camera blends from the eye to it (and
## back) over CAM_BLEND_TIME. It keeps out of the walls and above the floor.
func _update_camera(delta: float) -> void:
	_blend = minf(1.0, _blend + delta / CAM_BLEND_TIME)
	var w: float = smoothstep(0.0, 1.0, _blend)
	if _mode == Mode.WALK:
		if _orbit_cam.current:
			if _blend >= 1.0:
				_eye_cam.current = true
			else:
				_orbit_cam.global_transform = _blend_from.interpolate_with(_eye_cam.global_transform, w)
		return
	var k := 1.0 - exp(-ORBIT_RATE * delta)
	_orbit_pitch = lerpf(_orbit_pitch, _orbit_goal.x, k)
	_orbit_yaw = lerp_angle(_orbit_yaw, _orbit_goal.y, k)
	_orbit_dist = lerpf(_orbit_dist, _orbit_goal.z, k)
	var c: Vector3 = _bay_centre(_inspected)
	var dir := Vector3(sin(_orbit_yaw) * cos(_orbit_pitch), sin(_orbit_pitch), cos(_orbit_yaw) * cos(_orbit_pitch))
	var dist := _orbit_dist
	# Never through the floor: shorten the arm when it points down.
	if dir.y < -0.01:
		dist = minf(dist, (c.y - 0.35) / -dir.y)
	var q := PhysicsRayQueryParameters3D.create(c, c + dir * (dist + 0.4))
	q.collision_mask = 1
	q.exclude = [_player.get_rid()]
	var hit: Dictionary = _world.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and hit["collider"] == _walls:
		dist = minf(dist, c.distance_to(hit["position"]) - 0.4)
	dist = maxf(dist, 1.2)
	var pos := c + dir * dist
	var goal := Transform3D(Basis.looking_at(c - pos, Vector3.UP), pos)
	_orbit_cam.global_transform = _blend_from.interpolate_with(goal, w) if _blend < 1.0 else goal


# ============================================================================================
#  HUD
# ============================================================================================

func _make_fonts() -> void:
	_font_bold = FontVariation.new()
	_font_bold.base_font = ThemeDB.fallback_font
	_font_bold.variation_embolden = 0.7
	_font_title = FontVariation.new()
	_font_title.base_font = ThemeDB.fallback_font
	_font_title.variation_embolden = 1.1
	_font_title.spacing_glyph = 2


func _label(text: String, size: int, color: Color, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 2)
	if font:
		l.add_theme_font_override("font", font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_hud() -> void:
	var top := VBoxContainer.new()
	top.position = Vector2(48, 36)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	top.add_child(_label("GARAGE", 40, COL_TEXT, _font_title))
	_hud_count = _label("", 18, COL_DIM, _font_bold)
	top.add_child(_hud_count)

	_crosshair = Control.new()
	_crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.draw.connect(func():
		_crosshair.draw_circle(Vector2.ZERO, 3.5, Color(0, 0, 0, 0.45))
		_crosshair.draw_circle(Vector2.ZERO, 2.2, Color(1, 1, 1, 0.85)))
	add_child(_crosshair)

	_prompt = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_CARD
	sb.set_corner_radius_all(14)
	sb.border_width_left = 5
	sb.set_content_margin_all(18)
	sb.content_margin_left = 24
	_prompt.add_theme_stylebox_override("panel", sb)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_left = -330
	_prompt.offset_right = 330
	_prompt.offset_top = -60
	_prompt.offset_bottom = -60
	_prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.visible = false
	add_child(_prompt)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.add_child(col)
	_prompt_name = _label("", 32, COL_TEXT, _font_title)
	col.add_child(_prompt_name)
	_prompt_info = _label("", 16, COL_DIM, _font_bold)
	col.add_child(_prompt_info)
	_prompt_desc = _label("", 15, Color(COL_TEXT, 0.8))
	_prompt_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_desc.custom_minimum_size.x = 600
	col.add_child(_prompt_desc)
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	col.add_child(gap)
	_prompt_keys = _label("", 18, COL_TEXT, _font_bold)
	col.add_child(_prompt_keys)

	_toast = _label("", 22, COL_TEXT, _font_bold)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_toast.offset_left = -500
	_toast.offset_right = 500
	_toast.offset_top = 70
	_toast.offset_bottom = 110
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	add_child(_toast)

	var banner := VBoxContainer.new()
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	banner.offset_left = -600
	banner.offset_right = 600
	banner.offset_top = 120
	banner.offset_bottom = 230
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner)
	_banner = _label("", 54, COL_TEXT, _font_title)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_child(_banner)
	_banner_sub = _label("", 20, COL_DIM, _font_bold)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_child(_banner_sub)
	banner.modulate.a = 0.0

	_hint = _label(_hint_text(), 15, Color(COL_DIM, 0.8))
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.offset_left = -900
	_hint.offset_right = -40
	_hint.offset_top = -46
	_hint.offset_bottom = -20
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_hint)


func _hint_text() -> String:
	if _mode == Mode.INSPECT:
		if _pad:
			return "Right stick  orbit      Triggers  zoom      A  line-up      Y / B  lower"
		return "Mouse  orbit      Wheel / W S  zoom      E  line-up      F / Esc  lower"
	if _pad:
		return "Left stick  walk      Right stick  look      Click stick  run      B  back"
	return "WASD  walk      Shift  run      Mouse  look      Esc  back"


func _refresh_count() -> void:
	_hud_count.text = "Line-up: %d of %d cars" % [CarCollection.lineup_size(), CAR_PRESETS.size()]


func _refresh_prompt() -> void:
	var i: int = _inspected if _mode == Mode.INSPECT else _target
	_prompt.visible = i >= 0 and not _leaving
	if i < 0:
		return
	var bay: Dictionary = _bays[i]
	var preset: Dictionary = CAR_PRESETS[bay["index"]]
	var on: bool = CarCollection.in_lineup(bay["index"])
	var accent: Color = CAR_ACCENTS.get(preset.name, bay["color"])
	_prompt_name.text = str(preset.name).to_upper()
	_prompt_name.add_theme_color_override("font_color", accent.lightened(0.15))
	(_prompt.get_theme_stylebox("panel") as StyleBoxFlat).border_color = accent
	_prompt_info.text = "%s   ·   %s" % [str(bay["gallery"]).to_upper(), "IN THE LINE-UP" if on else "NOT IN THE LINE-UP"]
	_place_prompt(_mode == Mode.INSPECT)
	_prompt_desc.text = str(SELECT_PRESETS[bay["index"]].get("desc", "")) if bay["index"] < SELECT_PRESETS.size() else ""
	var k_line := "A" if _pad else "E"
	var k_lift := "Y" if _pad else "F"
	var line_text := "take out of the line-up" if on else "add to the line-up"
	if _mode == Mode.INSPECT:
		_prompt_keys.text = "%s  %s        %s  lower it" % [k_line, line_text, k_lift]
	else:
		_prompt_keys.text = "%s  %s        %s  lift it up" % [k_line, line_text, k_lift]


## Under the crosshair while walking; in the bottom-left corner, without the description, while inspecting,
## so it keeps off the car.
func _place_prompt(corner: bool) -> void:
	_prompt_desc.visible = not corner
	if corner:
		_prompt.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		_prompt.offset_left = 48
		_prompt.offset_right = 560
	else:
		_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_prompt.offset_left = -330
		_prompt.offset_right = 330
	# Zero height at the bottom edge: it grows up to fit what it says.
	_prompt.offset_top = -60
	_prompt.offset_bottom = -60
	_prompt.reset_size()


func _show_toast(text: String) -> void:
	_toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)


## The name of the room the player walks into, faded in and out at the top.
func _show_banner(title: String, sub: String, color: Color = COL_TEXT) -> void:
	_banner.text = title
	_banner.add_theme_color_override("font_color", color)
	_banner_sub.text = sub
	var box: Control = _banner.get_parent()
	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(box, "modulate:a", 1.0, 0.5)
	_banner_tween.tween_interval(2.2)
	_banner_tween.tween_property(box, "modulate:a", 0.0, 0.9)


func _update_area() -> void:
	var p := Vector2(_player.global_position.x, _player.global_position.z)
	var area := "spine"
	for r in _rooms:
		if (r["rect"] as Rect2).has_point(p):
			area = r["name"]
			if area != _area:
				var n: int = (r["cars"] as Array).size()
				var in_line := 0
				for idx in r["cars"]:
					if CarCollection.in_lineup(idx):
						in_line += 1
				_show_banner(str(r["name"]).to_upper(), "%d cars  ·  %d in the line-up" % [n, in_line],
						(r["color"] as Color).lightened(0.25))
			break
	if area == "spine" and p.y < _spine_end:
		area = "hall"
		if area != _area:
			_show_banner("HALL OF FAME", "Your Grand Prix trophies", COL_GOLD)
	_area = area


# ============================================================================================
#  The stage
# ============================================================================================

func _build_stage() -> void:
	var holder := SubViewportContainer.new()
	holder.name = "Stage"
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_stage = SubViewport.new()
	_stage.own_world_3d = true
	_stage.audio_listener_enable_3d = true
	var mode: int = MusicManager.anti_aliasing if not OS.has_feature("mobile") else 4
	_stage.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X, Viewport.MSAA_DISABLED][clampi(mode, 0, 4)]
	_stage.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if mode == 4 else Viewport.SCREEN_SPACE_AA_DISABLED
	_stage.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	holder.add_child(_stage)
	_world = Node3D.new()
	_world.name = "World"
	_stage.add_child(_world)

	# The studio sky lights and reflects (soft boxes in the paint) but is never seen: the hall is closed.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.022, 0.028)
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)

	_walls = StaticBody3D.new()
	_walls.name = "Walls"
	_world.add_child(_walls)


func _mat(key: String) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	match key:
		"wall":
			m.albedo_color = Color(0.5, 0.49, 0.47)
			m.roughness = 0.85
		"wainscot":
			m.albedo_color = Color(0.13, 0.14, 0.16)
			m.roughness = 0.5
		"ceiling":
			m.albedo_color = Color(0.09, 0.095, 0.11)
			m.roughness = 0.9
		"strip":
			m.albedo_color = Color.BLACK
			m.emission_enabled = true
			m.emission = Color(1.0, 0.97, 0.9)
			m.emission_energy_multiplier = 3.0
		"post":
			m.albedo_color = Color(0.19, 0.2, 0.23)
			m.metallic = 0.6
			m.roughness = 0.38
		"rubber":
			m.albedo_color = Color(0.04, 0.04, 0.045)
			m.roughness = 0.8
		"dais":
			m.albedo_color = Color(0.07, 0.075, 0.085)
			m.metallic = 0.3
			m.roughness = 0.3
		"lectern":
			m.albedo_color = Color(0.11, 0.12, 0.14)
			m.metallic = 0.5
			m.roughness = 0.35
		"marble":
			m.albedo_color = Color(0.09, 0.09, 0.1)
			m.metallic = 0.1
			m.roughness = 0.18
		"glass":
			m.albedo_color = Color(0.75, 0.85, 0.95, 0.10)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.metallic = 0.2
			m.roughness = 0.04
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"ghost":
			m.albedo_color = Color(0.25, 0.27, 0.3, 0.35)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.5
	_mats[key] = m
	return m


func _glow_mat(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.BLACK
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


## A box from `a` to `b` (opposite corners) in `parent`'s frame.
func _box(parent: Node3D, a: Vector3, b: Vector3, mat: Material, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = (b - a).abs()
	mi.mesh = bm
	mi.position = (a + b) * 0.5
	mi.material_override = mat
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## A collision box on the walls' body, in world coordinates.
func _solid(a: Vector3, b: Vector3, body: StaticBody3D = null) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = (b - a).abs()
	cs.shape = shape
	cs.position = (a + b) * 0.5
	(body if body else _walls).add_child(cs)


func _text(parent: Node3D, text: String, size: int, color: Color, pos: Vector3, yaw: float,
		pixel := 0.01, font: Font = null) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = pixel
	l.modulate = color
	l.outline_size = 0
	l.font = font if font else _font_title
	l.shaded = false
	l.double_sided = false
	l.position = pos
	l.rotation.y = yaw
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	parent.add_child(l)
	return l


## A wall along x (at `z`) or along z (at `x`), from `from` to `to` along it, with openings ([a, b] along
## it, a lintel over each from DOOR_H). Cut into pieces of at most 8m, so no piece takes in more lights than
## the mobile renderer gives a mesh, and the dark wainscot is its own box under the plaster.
func _wall(along_x: bool, at: float, from: float, to: float, openings: Array = []) -> void:
	var cuts: Array = [[minf(from, to), maxf(from, to), 0.0]]
	for o in openings:
		var next: Array = []
		for c in cuts:
			var a: float = c[0]
			var b: float = c[1]
			if o.y <= a or o.x >= b or c[2] > 0.0:
				next.append(c)
				continue
			if o.x > a:
				next.append([a, o.x, 0.0])
			next.append([maxf(a, o.x), minf(b, o.y), DOOR_H])
			if o.y < b:
				next.append([o.y, b, 0.0])
		cuts = next
	for c in cuts:
		var a: float = c[0]
		var b: float = c[1]
		var y0: float = c[2]
		var n := maxi(1, ceili((b - a) / 8.0))
		for k in n:
			var s0: float = lerpf(a, b, float(k) / n)
			var s1: float = lerpf(a, b, float(k + 1) / n)
			var lo := Vector3(s0, 0.0, at - WALL_T * 0.5) if along_x else Vector3(at - WALL_T * 0.5, 0.0, s0)
			var hi := Vector3(s1, 0.0, at + WALL_T * 0.5) if along_x else Vector3(at + WALL_T * 0.5, 0.0, s1)
			if y0 <= 0.0:
				_box(_world, Vector3(lo.x, 0.0, lo.z), Vector3(hi.x, WAINSCOT, hi.z), _mat("wainscot"))
				_box(_world, Vector3(lo.x, WAINSCOT, lo.z), Vector3(hi.x, WALL_H, hi.z), _mat("wall"))
			else:
				_box(_world, Vector3(lo.x, y0, lo.z), Vector3(hi.x, WALL_H, hi.z), _mat("wall"))
			_solid(Vector3(lo.x, y0, lo.z), Vector3(hi.x, WALL_H, hi.z))


## The floor of a room (x0..x1, z0..z1) in tiles of at most 8m, and its ceiling.
func _room(x0: float, x1: float, z0: float, z1: float) -> void:
	if not _mats.has("floor"):
		var fm := ShaderMaterial.new()
		fm.shader = FLOOR_SHADER
		_mats["floor"] = fm
	var nx := maxi(1, ceili((x1 - x0) / 8.0))
	var nz := maxi(1, ceili((z1 - z0) / 8.0))
	for i in nx:
		for k in nz:
			var a := Vector2(lerpf(x0, x1, float(i) / nx), lerpf(z0, z1, float(k) / nz))
			var b := Vector2(lerpf(x0, x1, float(i + 1) / nx), lerpf(z0, z1, float(k + 1) / nz))
			var mi := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = b - a
			mi.mesh = pm
			mi.position = Vector3((a.x + b.x) * 0.5, 0.0, (a.y + b.y) * 0.5)
			mi.material_override = _mats["floor"]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_world.add_child(mi)
	_box(_world, Vector3(x0, WALL_H, z0), Vector3(x1, WALL_H + 0.3, z1), _mat("ceiling"), false)


# ============================================================================================
#  The hall
# ============================================================================================

func _build_hall() -> void:
	var slots: int = ceili(_galleries.size() / 2.0)
	_spine_end = -FOYER - slots * SLOT
	var left_doors: Array = []
	var right_doors: Array = []
	for gi in _galleries.size():
		var g: Dictionary = _galleries[gi]
		var side: float = -1.0 if gi % 2 == 0 else 1.0
		var slot: int = gi / 2
		var z_top: float = -FOYER - slot * SLOT - 1.0
		var z_bot: float = z_top - GALLERY_W
		var zc: float = (z_top + z_bot) * 0.5
		var cols: int = ceili((g["cars"] as Array).size() / 2.0)
		var length: float = G_ENTRY + (cols - 1) * BAY + G_END
		var x_in: float = side * SPINE_HALF
		var x_out: float = side * (SPINE_HALF + length)
		(left_doors if side < 0.0 else right_doors).append(Vector2(zc - DOOR_W * 0.5, zc + DOOR_W * 0.5))
		_room(minf(x_in, x_out), maxf(x_in, x_out), z_bot, z_top)
		_wall(true, z_top, x_in, x_out + side * WALL_T * 0.5)
		_wall(true, z_bot, x_in, x_out + side * WALL_T * 0.5)
		_wall(false, x_out, z_bot - WALL_T * 0.5, z_top + WALL_T * 0.5)
		_rooms.append({"name": g["name"], "color": g["color"], "cars": g["cars"], "side": side,
				"rect": Rect2(minf(x_in, x_out), z_bot, length, GALLERY_W)})
		_dress_gallery(g, side, x_in, x_out, z_top, z_bot)
		var cars: Array = g["cars"]
		for j in cars.size():
			var col: int = j / 2
			var row: float = 1.0 if j % 2 == 0 else -1.0
			var along: float = G_ENTRY + col * BAY
			var pos := Vector3(side * (SPINE_HALF + along), 0.0, zc + row * BAY_SIDE)
			# Face across the aisle, turned toward the way in.
			var face := Vector3(-side * sin(CAR_TURN), 0.0, -row * cos(CAR_TURN))
			_build_bay(cars[j], g, pos, atan2(face.x, face.z))

	# The concourse, its walls with the galleries' doors, the door wall, and the trophy hall.
	_room(-SPINE_HALF, SPINE_HALF, _spine_end, ENTRANCE_Z)
	_wall(false, -SPINE_HALF, _spine_end, ENTRANCE_Z, left_doors)
	_wall(false, SPINE_HALF, _spine_end, ENTRANCE_Z, right_doors)
	_wall(true, ENTRANCE_Z, -SPINE_HALF - WALL_T * 0.5, SPINE_HALF + WALL_T * 0.5)
	var hall_back: float = _spine_end - HALL_D
	_room(-HALL_HALF, HALL_HALF, hall_back, _spine_end)
	_wall(true, _spine_end, -HALL_HALF - WALL_T * 0.5, HALL_HALF + WALL_T * 0.5, [Vector2(-SPINE_HALF, SPINE_HALF)])
	_wall(true, hall_back, -HALL_HALF - WALL_T * 0.5, HALL_HALF + WALL_T * 0.5)
	_wall(false, -HALL_HALF, hall_back, _spine_end)
	_wall(false, HALL_HALF, hall_back, _spine_end)
	# The floor's collision, under everything.
	_solid(Vector3(-200.0, -1.0, hall_back - 10.0), Vector3(200.0, 0.0, ENTRANCE_Z + 10.0))

	# Light: two strips down the concourse's ceiling and lamps along it.
	for x in [-3.2, 3.2]:
		_box(_world, Vector3(x - 0.2, WALL_H - 0.06, _spine_end + 1.0), Vector3(x + 0.2, WALL_H, ENTRANCE_Z - 1.0), _mat("strip"), false)
	var z := ENTRANCE_Z - 4.0
	while z > _spine_end:
		_omni(Vector3(0.0, WALL_H - 1.2, z), 1.1, 13.0)
		z -= 10.0
	# The sign: a board across the concourse just before its first pair of doors, hung from the ceiling.
	_box(_world, Vector3(-SPINE_HALF + 0.6, 4.5, -FOYER - 0.2), Vector3(SPINE_HALF - 0.6, 6.6, -FOYER), _mat("wainscot"), false)
	_box(_world, Vector3(-SPINE_HALF + 0.6, 4.5, -FOYER + 0.0), Vector3(SPINE_HALF - 0.6, 4.56, -FOYER + 0.02), _glow_mat(COL_GOLD, 1.8), false)
	for x in [-4.5, 4.5]:
		_box(_world, Vector3(x - 0.02, 6.6, -FOYER - 0.12), Vector3(x + 0.02, WALL_H, -FOYER - 0.08), _mat("post"), false)
	_text(_world, "THE COLLECTION", 120, COL_TEXT, Vector3(0.0, 5.85, -FOYER + 0.02), 0.0, 0.01)
	_text(_world, "RC VIBE GP", 56, COL_GOLD, Vector3(0.0, 4.98, -FOYER + 0.02), 0.0, 0.01, _font_bold)


## A gallery's sign over its door, its name on the end wall, a stripe in its colour round its walls, the
## light strip down its aisle.
func _dress_gallery(g: Dictionary, side: float, x_in: float, x_out: float, z_top: float, z_bot: float) -> void:
	var color: Color = g["color"]
	var zc: float = (z_top + z_bot) * 0.5
	var glow := _glow_mat(color, 2.2)
	var name_up := str(g["name"]).to_upper()
	# Over the door, on the concourse side, facing across it.
	var sign_x: float = x_in - side * (WALL_T * 0.5 + 0.02)
	_text(_world, name_up, 96, color.lightened(0.3), Vector3(sign_x, 5.75, zc), -side * PI * 0.5, 0.01)
	_text(_world, "%d CARS" % (g["cars"] as Array).size(), 40, COL_DIM, Vector3(sign_x, 5.05, zc), -side * PI * 0.5, 0.01, _font_bold)
	_box(_world, Vector3(sign_x - 0.02, DOOR_H + 0.04, zc - DOOR_W * 0.5), Vector3(sign_x + 0.02, DOOR_H + 0.12, zc + DOOR_W * 0.5), glow, false)
	# On the end wall, facing back up the aisle.
	var end_x: float = x_out - side * (WALL_T * 0.5 + 0.02)
	_text(_world, name_up, 160, color.lightened(0.25), Vector3(end_x, 4.6, zc), side * -PI * 0.5, 0.01)
	# A stripe round the inside at 3.1m: along both long walls and the end wall.
	var y0 := 3.05
	var y1 := 3.17
	var t: float = WALL_T * 0.5
	_box(_world, Vector3(minf(x_in, x_out), y0, z_top - t - 0.03), Vector3(maxf(x_in, x_out), y1, z_top - t), glow, false)
	_box(_world, Vector3(minf(x_in, x_out), y0, z_bot + t), Vector3(maxf(x_in, x_out), y1, z_bot + t + 0.03), glow, false)
	_box(_world, Vector3(end_x - 0.015, y0, z_bot + t), Vector3(end_x + 0.015, y1, z_top - t), glow, false)
	# The aisle's light strip, and a lamp at each end of it for the floor and walls.
	_box(_world, Vector3(minf(x_in, x_out) + 1.0, WALL_H - 0.06, zc - 0.25), Vector3(maxf(x_in, x_out) - 1.0, WALL_H, zc + 0.25), _mat("strip"), false)
	_omni(Vector3(lerpf(x_in, x_out, 0.3), WALL_H - 1.0, zc), 0.8, 12.0)
	_omni(Vector3(lerpf(x_in, x_out, 0.8), WALL_H - 1.0, zc), 0.8, 12.0)


func _omni(pos: Vector3, energy: float, reach: float) -> void:
	var o := OmniLight3D.new()
	o.position = pos
	o.light_energy = energy
	o.omni_range = reach
	o.omni_attenuation = 1.2
	o.light_color = Color(1.0, 0.95, 0.88)
	o.shadow_enabled = false
	_world.add_child(o)


## A car's scene at show size, in the player's paint for it (or its factory paint).
func _car_model(index: int) -> Node3D:
	var preset: Dictionary = CAR_PRESETS[index]
	var scene := load(preset.model_path) as PackedScene
	if scene == null:
		return null
	var model := scene.instantiate() as Node3D
	if CarPaint.is_paintable(model):
		var car_name := str(preset.name)
		var saved: Variant = null
		var config := ConfigFile.new()
		if config.load("user://settings.cfg") == OK:
			if config.has_section_key("paint", car_name):
				saved = config.get_value("paint", car_name)
			elif car_name == "Trailblazer" and config.has_section_key("paint", "Viper"):
				saved = config.get_value("paint", "Viper")
		CarPaint.apply(model, CarPaint.sanitize(saved, car_name))
	return model


## Everything at one car: the car (in `car`, whose y the lift sets), the dais and its rim, the two-post lift,
## the lectern, the spotlight. Bay frame: the car's middle on the floor at the origin, its nose toward +z.
func _build_bay(index: int, g: Dictionary, pos: Vector3, yaw: float) -> void:
	var root := Node3D.new()
	root.name = "Bay_%s" % CAR_PRESETS[index].name
	root.position = pos
	root.rotation.y = yaw
	_world.add_child(root)
	var color: Color = g["color"]
	var car := Node3D.new()
	car.name = "Car"
	root.add_child(car)
	var model := _car_model(index)
	if model == null:
		return
	car.add_child(model)
	model.transform = Transform3D(Basis.from_scale(Vector3.ONE * CAR_SCALE * SHOW_SCALE), Vector3.ZERO)
	var box: AABB = _bounds(model, root)
	var centre: Vector3 = box.get_center()
	model.position -= Vector3(centre.x, box.position.y, centre.z)
	box = _bounds(model, root)
	var size: Vector3 = box.size
	var contact := _underside(model, root, size)

	# The dais: a dark plate with a rim of light round it, which says whether the car is in the line-up.
	var hw: float = size.x * 0.5 + POST_GAP + 0.75
	var hl: float = size.z * 0.5 + 0.8
	var rim_mat := _glow_mat(color, 2.6)
	_box(root, Vector3(-hw - 0.06, 0.0, -hl - 0.06), Vector3(hw + 0.06, 0.03, hl + 0.06), rim_mat, false)
	_box(root, Vector3(-hw, 0.0, -hl), Vector3(hw, 0.045, hl), _mat("dais"), false)
	car.position.y = 0.045
	# A soft shadow under the car, which stays on the dais when the car goes up.
	var blob := MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2(size.x * 1.25, size.z * 1.12)
	blob.mesh = quad
	blob.position.y = 0.05
	blob.material_override = _blob_mat()
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(blob)

	# The lift: a post either side at the middle of the car, a carriage on each with two arms swung in
	# under the car to its pads.
	var px: float = size.x * 0.5 + POST_GAP
	var cap := _glow_mat(color, 1.4)
	var body := StaticBody3D.new()
	body.name = "BayBody"
	root.add_child(body)
	for s in [-1.0, 1.0]:
		_box(root, Vector3(s * px - 0.3, 0.045, -0.3), Vector3(s * px + 0.3, 0.07, 0.3), _mat("post"))
		_box(root, Vector3(s * px - 0.12, 0.07, -0.15), Vector3(s * px + 0.12, POST_H, 0.15), _mat("post"))
		_box(root, Vector3(s * px - 0.14, POST_H, -0.17), Vector3(s * px + 0.14, POST_H + 0.05, 0.17), cap, false)
		_solid(Vector3(s * px - 0.3, 0.0, -0.3), Vector3(s * px + 0.3, POST_H, 0.3), body)
	var carriage := Node3D.new()
	carriage.name = "Carriage"
	root.add_child(carriage)
	for s in [-1.0, 1.0]:
		var sx: float = s
		_box(carriage, Vector3(sx * px - 0.17, 0.0, -0.2), Vector3(sx * px + 0.17, 0.45, 0.2), _mat("post"))
		for e in [-1.0, 1.0]:
			var a := Vector3(sx * (px - 0.18), 0.06, 0.0)
			var pad := Vector3(sx * size.x * 0.24, 0.06, e * size.z * 0.27)
			var arm := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.1, 0.07, a.distance_to(pad))
			arm.mesh = bm
			arm.material_override = _mat("post")
			arm.transform = Transform3D(Basis.looking_at(pad - a, Vector3.UP), (a + pad) * 0.5)
			carriage.add_child(arm)
			var p := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.13
			cyl.bottom_radius = 0.13
			cyl.height = 0.06
			p.mesh = cyl
			p.material_override = _mat("rubber")
			p.position = pad + Vector3(0.0, PAD_TOP - 0.06 - 0.03, 0.0)
			carriage.add_child(p)
	# The car itself is solid to walk into, up to its roof.
	_solid(Vector3(-size.x * 0.5 - 0.1, 0.0, -size.z * 0.5 - 0.1), Vector3(size.x * 0.5 + 0.1, size.y, size.z * 0.5 + 0.1), body)

	# The lectern, at the front corner away from the concourse, angled to the aisle.
	var corner := 1.0
	var probe_a: Vector3 = root.transform * Vector3(hw - 0.6, 0.0, hl + 0.5)
	var probe_b: Vector3 = root.transform * Vector3(-hw + 0.6, 0.0, hl + 0.5)
	if absf(probe_b.x) > absf(probe_a.x):
		corner = -1.0
	var lectern := Node3D.new()
	lectern.position = Vector3(corner * (hw - 0.65), 0.0, hl + 0.55)
	lectern.rotation.y = -corner * 0.35
	root.add_child(lectern)
	_box(lectern, Vector3(-0.08, 0.0, -0.08), Vector3(0.08, 0.95, 0.08), _mat("lectern"))
	var top := _box(lectern, Vector3(-0.62, -0.03, -0.32), Vector3(0.62, 0.03, 0.32), _mat("lectern"))
	top.position = Vector3(0.0, 1.0, 0.0)
	top.rotation.x = 0.55
	_box(lectern, Vector3(-0.3, 0.0, -0.3), Vector3(0.3, 0.04, 0.3), _mat("lectern"))
	_solid(Vector3(-0.2, 0.0, -0.2) + lectern.position, Vector3(0.2, 1.0, 0.2) + lectern.position, body)
	var face := Node3D.new()
	face.position = Vector3(0.0, 1.0, 0.0)
	face.rotation.x = -PI * 0.5 + 0.55
	lectern.add_child(face)
	var accent: Color = CAR_ACCENTS.get(CAR_PRESETS[index].name, color)
	# Long names in smaller type, so they stay on the board.
	var car_name := str(CAR_PRESETS[index].name).to_upper()
	var name_size: int = clampi(int(64.0 * 8.0 / maxf(car_name.length(), 8.0)), 36, 64)
	_text(face, car_name, name_size, accent.lightened(0.2), Vector3(0.0, 0.12, 0.035), 0.0, 0.0028)
	var status := _text(face, "", 32, COL_DIM, Vector3(0.0, -0.06, 0.035), 0.0, 0.0028, _font_bold)
	_text(face, str(g["name"]).to_upper(), 26, Color(COL_DIM, 0.7), Vector3(0.0, -0.17, 0.035), 0.0, 0.0028, _font_bold)

	# The spotlight: high on the aisle side, aimed at the car.
	var spot := SpotLight3D.new()
	root.add_child(spot)
	spot.position = Vector3(0.0, WALL_H - 0.6, size.z * 0.5 + 2.6)
	spot.look_at(root.to_global(Vector3(0.0, size.y * 0.35, 0.0)), Vector3.UP)
	spot.spot_angle = 30.0
	spot.spot_angle_attenuation = 0.7
	spot.spot_range = 13.0
	spot.light_color = Color(1.0, 0.96, 0.9)
	spot.shadow_enabled = MusicManager.shadow_quality_index > 0 and not OS.has_feature("mobile")
	spot.shadow_bias = 0.05
	spot.shadow_normal_bias = 1.5

	# The inspection lamp: lights the underside once the car is up (only while it is: _pose_lift).
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.0, 0.25, 0.0)
	lamp.omni_range = size.z * 0.5 + 2.0
	lamp.omni_attenuation = 0.8
	lamp.light_color = Color(0.92, 0.96, 1.0)
	lamp.shadow_enabled = false
	lamp.visible = false
	root.add_child(lamp)

	var bay := {
		"index": index, "lamp": lamp, "gallery": g["name"], "color": color, "root": root, "car": car, "car_y": car.position.y,
		"centre": Vector3(0.0, size.y * 0.45, 0.0), "radius": size.z * 0.5,
		"contact": maxf(contact + car.position.y, LIFT_REST + PAD_TOP + 0.01), "carriage": carriage, "blob": blob, "rim_mat": rim_mat,
		"spot": spot, "status": status, "lift": 0.0, "up": false,
	}
	_bays.append(bay)
	_pose_lift(bay)
	_show_lineup_state(_bays.size() - 1, false)


## How high over the floor the lift's pads meet the car: the lowest point of its body over the middle of
## its floor (between the axles, inside the wheels). The wheels themselves don't count.
func _underside(model: Node3D, space: Node3D, size: Vector3) -> float:
	var lowest := INF
	var to_space: Transform3D = space.global_transform.affine_inverse()
	var stack: Array[Node] = [model]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if str(n.name).begins_with("Wheel"):
			continue
		stack.append_array(n.get_children())
		if not (n is MeshInstance3D) or (n as MeshInstance3D).mesh == null:
			continue
		var mi := n as MeshInstance3D
		var xf: Transform3D = to_space * mi.global_transform
		for s in mi.mesh.get_surface_count():
			var verts: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for v in verts:
				var p: Vector3 = xf * v
				if absf(p.z) < size.z * 0.3 and absf(p.x) < size.x * 0.32 and p.y < lowest:
					lowest = p.y
	if lowest == INF:
		return size.y * 0.25
	return lowest


var _blob_material: StandardMaterial3D
func _blob_mat() -> StandardMaterial3D:
	if _blob_material:
		return _blob_material
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.75))
	grad.set_color(1, Color(0, 0, 0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	_blob_material = StandardMaterial3D.new()
	_blob_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_blob_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_blob_material.albedo_texture = tex
	_blob_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return _blob_material


static func _bounds(node: Node, space: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var to_space: Transform3D = space.global_transform.affine_inverse()
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and (n as MeshInstance3D).visible:
			var mi := n as MeshInstance3D
			var b: AABB = to_space * mi.global_transform * mi.mesh.get_aabb()
			box = b if first else box.merge(b)
			first = false
		stack.append_array(n.get_children())
	return box


## The foyer: the player's own car (the one the car select screen last confirmed) on a turntable.
func _build_featured() -> void:
	var index: int = clampi(NetworkManager.local_car_index, 0, CAR_PRESETS.size() - 1)
	var base := Node3D.new()
	base.name = "Featured"
	base.position = Vector3(0.0, 0.0, -4.0)
	_world.add_child(base)
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 3.0
	cyl.bottom_radius = 3.05
	cyl.height = 0.12
	cyl.radial_segments = 96
	disc.mesh = cyl
	disc.position.y = 0.06
	disc.material_override = _mat("dais")
	base.add_child(disc)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 3.04
	torus.outer_radius = 3.1
	torus.rings = 96
	torus.ring_segments = 6
	ring.mesh = torus
	ring.position.y = 0.06
	ring.material_override = _glow_mat(CAR_ACCENTS.get(CAR_PRESETS[index].name, COL_TEAL), 2.6)
	base.add_child(ring)
	_solid(Vector3(-3.0, 0.0, -7.0), Vector3(3.0, 1.6, -1.0))
	_featured = Node3D.new()
	_featured.position.y = 0.12
	_featured.rotation.y = 0.6
	base.add_child(_featured)
	var model := _car_model(index)
	if model:
		_featured.add_child(model)
		model.transform = Transform3D(Basis.from_scale(Vector3.ONE * CAR_SCALE * SHOW_SCALE), Vector3.ZERO)
		var box: AABB = _bounds(model, _featured)
		var c: Vector3 = box.get_center()
		model.position -= Vector3(c.x, box.position.y, c.z)
	for s in [-1.0, 1.0]:
		var spot := SpotLight3D.new()
		base.add_child(spot)
		spot.position = Vector3(s * 4.5, WALL_H - 0.6, 3.5)
		spot.look_at(base.to_global(Vector3(0.0, 0.6, 0.0)), Vector3.UP)
		spot.spot_angle = 28.0
		spot.spot_range = 13.0
		spot.light_energy = 7.0
		spot.light_color = Color(1.0, 0.96, 0.9)
	var label := _text(_world, "YOUR CAR  ·  %s" % str(CAR_PRESETS[index].name).to_upper(), 40, COL_DIM,
			Vector3(0.0, 0.14, -0.7), 0.0, 0.006, _font_bold)
	label.rotation.x = -PI * 0.5


## The trophy hall: a pedestal per Grand Prix in an arc, each holding the best trophy won there (gold,
## silver or bronze) in a glass case, or a grey ghost of one; the logo and the tally on the back wall.
func _build_trophies() -> void:
	var hall_back: float = _spine_end - HALL_D
	var centre := Vector3(0.0, 0.0, _spine_end - HALL_D * 0.55)
	var cups: Array = NetworkManager.GP_CUPS.keys()
	var wins := 0
	var podiums := 0
	var spread: float = minf(1.25, 0.32 * (cups.size() - 1))
	for i in cups.size():
		var cup_name: String = cups[i]
		var rec: Dictionary = Trophies.cup(cup_name)
		wins += int(rec["gold"])
		podiums += int(rec["gold"]) + int(rec["silver"]) + int(rec["bronze"])
		var a: float = 0.0 if cups.size() == 1 else lerpf(-spread, spread, float(i) / (cups.size() - 1))
		var pos: Vector3 = centre + Vector3(sin(a), 0.0, -cos(a)) * TROPHY_RING
		var ped := Node3D.new()
		ped.name = "Trophy_%d" % i
		ped.position = pos
		ped.rotation.y = -a
		_world.add_child(ped)
		_build_pedestal(ped, cup_name, rec)
	# The back wall: the logo, the title and the tally.
	var wall_z: float = hall_back + WALL_T * 0.5 + 0.03
	var logo_scene := load(LOGO_PATH) as PackedScene
	if logo_scene:
		var logo := logo_scene.instantiate() as Node3D
		logo.position = Vector3(0.0, 5.3, wall_z + 0.4)
		logo.scale = Vector3.ONE * 0.55
		_world.add_child(logo)
	_text(_world, "HALL OF FAME", 110, COL_GOLD, Vector3(0.0, 3.75, wall_z), 0.0, 0.01)
	_text(_world, "%d GRAND PRIX WON  ·  %d PODIUMS" % [wins, podiums], 40, COL_DIM, Vector3(0.0, 3.05, wall_z), 0.0, 0.01, _font_bold)
	_box(_world, Vector3(-9.0, 2.7, wall_z - 0.03), Vector3(9.0, 2.75, wall_z), _glow_mat(COL_GOLD, 1.6), false)
	# A ring of light on the ceiling over the arc, and lamps.
	_box(_world, Vector3(-8.0, WALL_H - 0.06, centre.z - 0.25), Vector3(8.0, WALL_H, centre.z + 0.25), _mat("strip"), false)
	_omni(Vector3(-6.0, WALL_H - 1.2, centre.z), 0.9, 14.0)
	_omni(Vector3(6.0, WALL_H - 1.2, centre.z), 0.9, 14.0)
	# Over the hall's door, facing the concourse.
	_text(_world, "HALL OF FAME", 96, COL_GOLD, Vector3(0.0, 5.75, _spine_end + WALL_T * 0.5 + 0.02), 0.0, 0.01)


func _build_pedestal(ped: Node3D, cup_name: String, rec: Dictionary) -> void:
	var best: int = rec["best"]
	var won: bool = best >= 0
	var col: Color = MEDAL[best] if won else COL_OFF
	var column := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.72
	cyl.bottom_radius = 0.8
	cyl.height = PEDESTAL_H
	cyl.radial_segments = 48
	column.mesh = cyl
	column.position.y = PEDESTAL_H * 0.5
	column.material_override = _mat("marble")
	ped.add_child(column)
	var band := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.7
	tor.outer_radius = 0.76
	tor.rings = 48
	tor.ring_segments = 6
	band.mesh = tor
	band.position.y = PEDESTAL_H
	band.material_override = _glow_mat(col, 2.0 if won else 0.4)
	ped.add_child(band)
	var body := StaticBody3D.new()
	ped.add_child(body)
	_solid(Vector3(-0.8, 0.0, -0.8), Vector3(0.8, PEDESTAL_H + 1.4, 0.8), body)
	# The cup (Podium's), or a ghost of it.
	var holder := Node3D.new()
	holder.position.y = PEDESTAL_H + 0.02
	holder.scale = Vector3.ONE * 1.05
	ped.add_child(holder)
	var mat: StandardMaterial3D
	if won:
		mat = StandardMaterial3D.new()
		mat.albedo_color = col
		mat.metallic = 1.0
		mat.roughness = 0.22
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 0.2
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	else:
		mat = _mat("ghost")
	var cup := MeshInstance3D.new()
	cup.mesh = PodiumScript._trophy_mesh()
	cup.material_override = mat
	holder.add_child(cup)
	for side in [-1.0, 1.0]:
		var handle := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.1
		torus.outer_radius = 0.16
		torus.rings = 24
		torus.ring_segments = 10
		handle.mesh = torus
		handle.rotation.x = PI * 0.5
		handle.scale = Vector3(1.0, 1.0, 1.5)
		handle.position = Vector3(side * 0.43, 0.8, 0.0)
		handle.material_override = mat
		holder.add_child(handle)
	_box(ped, Vector3(-0.68, PEDESTAL_H, -0.68), Vector3(0.68, PEDESTAL_H + 1.35, 0.68), _mat("glass"), false)
	# The plaque on the column's front.
	var plaque := Node3D.new()
	plaque.position = Vector3(0.0, PEDESTAL_H * 0.6, 0.82)
	ped.add_child(plaque)
	_text(plaque, cup_name.to_upper(), 46, col.lightened(0.2) if won else COL_DIM, Vector3(0.0, 0.22, 0.0), 0.0, 0.004)
	var line := "NOT YET WON"
	var sub := ""
	if won:
		var parts: Array = []
		for k in 3:
			var n := int(rec[Trophies.PLACES[k]])
			if n > 0:
				parts.append("%s x%d" % [PLACE_NAMES[k], n])
		line = "  ·  ".join(parts)
		if str(rec["car"]) != "":
			sub = "BEST: %s WITH THE %s" % [PLACE_NAMES[best], str(rec["car"]).to_upper()]
	_text(plaque, line, 34, COL_TEXT if won else Color(COL_DIM, 0.7), Vector3(0.0, 0.03, 0.0), 0.0, 0.004, _font_bold)
	if sub != "":
		_text(plaque, sub, 24, COL_DIM, Vector3(0.0, -0.12, 0.0), 0.0, 0.004, _font_bold)
	var spot := SpotLight3D.new()
	ped.add_child(spot)
	spot.position = Vector3(0.0, WALL_H - 0.5, 3.0)
	spot.look_at(ped.to_global(Vector3(0.0, PEDESTAL_H + 0.5, 0.0)), Vector3.UP)
	spot.spot_angle = 14.0
	spot.spot_range = 10.0
	spot.light_energy = 9.0 if won else 2.5
	spot.light_color = Color(1.0, 0.95, 0.85)


func _build_player() -> void:
	_player = CharacterBody3D.new()
	_player.name = "Walker"
	_player.position = Vector3(0.0, 0.05, ENTRANCE_Z - 1.6)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	_player.add_child(cs)
	_world.add_child(_player)
	_head = Node3D.new()
	_head.position.y = EYE
	_player.add_child(_head)
	_eye_cam = Camera3D.new()
	_eye_cam.fov = 72.0
	_eye_cam.near = 0.05
	_eye_cam.far = 200.0
	_head.add_child(_eye_cam)
	_eye_cam.current = true
	_orbit_cam = Camera3D.new()
	_orbit_cam.fov = 50.0
	_orbit_cam.near = 0.05
	_orbit_cam.far = 200.0
	_world.add_child(_orbit_cam)
	_pitch = -0.05
	_head.rotation.x = _pitch
