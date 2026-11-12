extends Control
## The garage (the menus call it the Headquarters): a hall the player walks through (first person) to look at their cars, choose which ones
## the car select screen offers (the line-up, CarCollection.gd) and see the Grand Prix trophies they have
## won (Trophies.gd) and their time trial records (TimeTrialRecords.gd, a board per Grand Prix on the trophy
## hall's side walls). Built in code, in its own world in a SubViewport, like the podium; Main.gd adds it
## from the main menu (HEADQUARTERS), calls start() once the loading screen has gone, and frees it on `finished`.
##
## Everything is at life size except the cars, which are large-scale RC cars: on the courses people and
## props stand at 1.6 times life size beside the cars (PROP_SCALE), so here a car is its race size over 1.6
## (SHOW_SCALE), about 1.4m long. Each stands on a plinth on a two-post lift of its own size.
##
## The hall, looking down it from the entrance doors (glass, sliding open as the walker comes near, in a glazed front:
## outside, the plaza and its grounds, a road and lawns under the sky, _build_plaza): the foyer with the player's own car on a turntable, then the concourse under a glass gable
## roof (the sky's sun lights only what is on SUN_LAYER), with a gallery per category
## (CarCollection.galleries()) off either side in pairs, and the trophy hall at its end. A gallery's cars
## stand in two rows either side of its aisle, angled toward the way in, each with a placard and a
## spotlight. More cars lengthen the galleries and more categories the concourse.
##
## A car in the line-up has its plinth's band lit in its gallery's colour and its spotlight up; one left out
## stands in a dimmer light with a grey band. Look at a car (within REACH) and press E to put it in or take
## it out (the last one stays), F to lift it: it goes up on the lift and the camera orbits it, from any side
## and from under it, until F or Esc lowers it again.
##
## Controls: WASD or the left stick walk, Shift or a pressed left stick runs, the mouse or the right stick
## looks; E or the pad's A, F or Y; Esc or B leaves (from an inspection, back to walking). In an
## inspection the mouse or right stick orbits, the wheel, W/S or the triggers zoom.

signal finished

const CarPaint = preload("res://CarPaint.gd")
const CarCollection = preload("res://CarCollection.gd")
const Trophies = preload("res://Trophies.gd")
const TimeTrialRecords = preload("res://TimeTrialRecords.gd")
const PodiumScript = preload("res://Podium.gd")
const LogoFlag = preload("res://LogoFlag.gd")
const CAR_PRESETS = preload("res://PlayerCart.gd").CAR_PRESETS
const CAR_ACCENTS = preload("res://CarSelection.gd").CAR_ACCENTS
## The car select screen's copy of the presets, which has each car's description.
const SELECT_PRESETS = preload("res://CarSelection.gd").CAR_PRESETS
const SKY_SHADER = preload("res://garage_sky.gdshader")
const FLOOR_SHADER = preload("res://garage_floor.gdshader")
const LOGO_PATH := "res://generated/logo/RcVibeLogo.tscn"

## What PlayerCart scales a car's scene by, and the share of that the cars stand at here: the courses'
## people are 1.6 times life size (PROP_SCALE), this hall's are life size.
const CAR_SCALE := 2.0
const SHOW_SCALE := 1.0 / 1.6

# The hall, in metres. The concourse runs from the entrance (ENTRANCE_Z) toward -z, x within SPINE_HALF.
const WALL_H := 5.0
## The concourse's roof ridge, and the walls that close its gable ends (entrance, trophy hall).
const RIDGE_H := 7.0
const TALL_H := 7.4
const WALL_T := 0.4
const WAINSCOT := 1.0
const SPINE_HALF := 4.5
const ENTRANCE_Z := 4.0
## From the entrance to the first pair of galleries.
const FOYER := 9.0
## A gallery's inside along the concourse, and the pitch of the pairs (a 1.5m pier between them).
const GALLERY_W := 11.0
const SLOT := 12.5
const DOOR_W := 5.0
const DOOR_H := 3.3
## Along a gallery: from the concourse wall to the first cars, between cars, after the last.
const G_ENTRY := 3.4
const BAY := 3.7
const G_END := 2.8
## A car's middle off its gallery's aisle, and how far it is turned from facing straight across toward the
## way in.
const BAY_SIDE := 2.75
const CAR_TURN := 0.52
const HALL_HALF := 9.0
const HALL_D_MIN := 16.0
## Room either end of a wall's row of record boards.
const RECORD_BOARD_MARGIN := 2.2
const TROPHY_RING := 5.6
## The time trial record boards on the trophy hall's side walls: size, centre height, spacing, a stage's row.
const RECORD_BOARD_SIZE := Vector2(4.6, 2.5)
const RECORD_BOARD_Y := 2.05
const RECORD_BOARD_STEP := 5.15
const RECORD_ROW := 0.43
const PEDESTAL_H := 1.2
## A trophy's glass case on its column: the glass's radius and top over the column's top, the foot ring's top (the
## case's floor), the cup's round dais's top.
const CASE_R := 0.56
const CASE_TOP := 1.17
const CASE_FOOT := 0.06
const CASE_DAIS := 0.09
## The plaque on the column's front: a glass plate (size, thickness) leaning back RECLINE (radians) in a chrome clamp on
## a steel ledge (its top PLAQUE_LEDGE over the floor, PLAQUE_LEDGE_W wide).
const PLAQUE_SIZE := Vector2(0.86, 0.38)
const PLAQUE_T := 0.012
const PLAQUE_RECLINE := 0.2
const PLAQUE_LEDGE := 0.56
const PLAQUE_LEDGE_W := 0.72
## The entrance doors' opening in the entrance wall.
const ENTRY_HALF := 1.6
const ENTRY_H := 3.3
## The automatic doors: how far inside the frame the leaves run, how far each slides open, how near the walker
## (in plan, from the doorway's middle) opens them, how long a full travel takes, the sound's level.
const DOOR_LEAF_IN := 0.16
const DOOR_SLIDE := 1.5
const DOOR_REACH := 4.0
const DOOR_TIME := 0.75
const DOOR_DB := -6.0
const DOOR_SOUNDS := ["res://sounds/garage/sliding_door_open.wav", "res://sounds/garage/sliding_door_close.wav"]
## The foyer's glazed front: the doors in the middle of it, glass either side and over them.
const FRONT_GLASS_HALF := 4.1
const FRONT_GLASS_H := 4.85
const FRONT_MULLION_X := 2.85
## The plaza (_build_plaza), from the entrance wall's outer face out to the road's kerb.
const PLAZA_DEPTH := 46.0
const PLAZA_HALF := 30.0
const PLAZA_AVENUE_X := 14.0
const PLAZA_AVENUE := [8.0, 18.0, 28.0, 38.0]
const PLAZA_FOUNTAIN_Z := 19.0
const PLAZA_LOGO_Z := 33.0
## How far either side of the axis the walker may go outside (hedges mark it).
const GROUNDS_HALF := 56.0
## The sun lights only what is on this render layer as well: the concourse, the foyer and the outside, so it
## never reaches into the galleries through their roofs when shadows are off.
const SUN_LAYER := 2

# The plinths and lifts, at the cars' size.
const DAIS_H := 0.7
const POST_GAP := 0.16
const LIFT_HEIGHT := 0.95
const LIFT_TIME := 3.0
## The pads' top over the carriage's foot, and the carriage's foot at rest (the arms on the plinth). A car
## whose underside is lower than the pads at rest just rests on its wheels over them.
const PAD_TOP := 0.075
const LIFT_REST := 0.015
const CARRIAGE_H := 0.17

# Walking and looking.
const EYE := 1.7
const WALK_SPEED := 3.0
const RUN_SPEED := 5.5
const MOVE_RATE := 10.0
## Walking: a footstep every STEP_LENGTH metres (STEP_LENGTH_RUN running), the head dipping BOB_DROP at each
## (more running, BOB_RUN times) and swaying BOB_SWAY over the planted foot. Kept small, and no roll: swinging
## views make the player dizzy.
const STEP_LENGTH := 0.95
const STEP_LENGTH_RUN := 1.55
const BOB_DROP := 0.018
const BOB_SWAY := 0.009
const BOB_RUN := 1.6
const MUSIC_FOLDER := "res://music/headquarters/"
const STEP_SOUNDS := ["res://sounds/garage/footstep_1.mp3", "res://sounds/garage/footstep_2.mp3"]
const STEP_DB := -10.0
## The lifts' and the line-up's sounds (sounds/garage/: tools/elevenlabs' garage_* jobs readied by
## scratch/garage_sound_prep.py; the lock clack synthesised by scratch/garage_lock_click.py) and their levels in dB for
## the files as prepared, each played in 3D at its bay (SOUND_UNIT): the power unit's hum while a lift rises and the
## fluid's hiss through the valve while one lowers (loops, louder and a little higher with the carriage's speed, fading
## over HUM_FADE), a safety lock clacking every LOCK_STEP of a carriage's rise, the locks releasing as one starts down, a
## clunk at the top, a thud at the bottom; the plinth's lights switching on or off as a car joins or leaves the line-up.
const GARAGE_SOUNDS := {
	"motor": ["res://sounds/garage/lift_motor_loop.wav", -13.0],
	"lower": ["res://sounds/garage/lift_lower_loop.wav", -15.0],
	"lock": ["res://sounds/garage/lift_lock_click.wav", -15.0],
	"top": ["res://sounds/garage/lift_top.wav", -8.0],
	"release": ["res://sounds/garage/lift_release.wav", -9.0],
	"bottom": ["res://sounds/garage/lift_bottom.wav", -8.0],
	"lineup_on": ["res://sounds/garage/lineup_on.wav", -3.0],
	"lineup_off": ["res://sounds/garage/lineup_off.wav", -4.0],
}
const SOUND_UNIT := 3.0
const HUM_FADE := 0.15
const LOCK_STEP := 0.13
const MOUSE_LOOK := 0.0022
const STICK_LOOK := 2.4
const STICK_DEADZONE := 0.18
const PITCH_LIMIT := 1.35
const REACH := 4.5
const AIM_CONE := 0.5

# Inspecting.
const ORBIT_MIN := 1.3
const ORBIT_MAX := 5.0
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
var _door_leaves: Array[Node3D] = []
var _door_shapes: Array[CollisionShape3D] = []
var _door_rest: Array[float] = []
var _door_open := 0.0      # 0 shut .. 1 open
var _door_wanted := false
var _door_sound: AudioStreamPlayer3D
var _bays_shown := true
## The trophy hall's depth: deep enough for its side walls to hold a record board per cup (_build_hall).
var _hall_d := HALL_D_MIN
## Per car on show: see _build_bay.
var _bays: Array = []
var _featured: Node3D

var _mode := Mode.WALK
var _started := false
var _yaw := 0.0
var _pitch := 0.0
var _move := Vector3.ZERO
var _step_phase := 0.0   # in steps: a footstep as it passes each half
var _bob := 0.0          # how much of the bob shows, 0..1 (eases in and out with the speed)
var _step_foot := 0
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
var _time := 0.0

var _mats := {}
var _sounds := {}
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
var _hint: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_galleries = CarCollection.galleries()
	_make_fonts()
	_build_stage()
	_build_hall()
	_build_roof()
	_build_entrance()
	_build_featured()
	_build_trophies()
	_build_player()
	_build_hud()
	_refresh_count()


## The loading screen has gone: take the mouse and show where we are.
func start() -> void:
	_started = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Its own laid-back music (music/headquarters/, ElevenLabs Music, instrumental), shuffled, crossfading from the
	# menus' (and back to it on leaving).
	MusicManager._load_playlist(MUSIC_FOLDER)
	MusicManager.play_next()


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _started:
		MusicManager.play_menu_music()


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
		_orbit_goal.z = clampf(_orbit_goal.z - zoom * 2.5 * delta, ORBIT_MIN, ORBIT_MAX)
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
	_update_steps(delta)
	_update_doors(delta)
	_update_bays_shown()


## The cars on show (each with its shadowed spotlight) are hidden while the walker is outside the building: none can be
## seen from the grounds, and drawn they cost about 8ms of an M1 at 1600x1000 looking back across the plaza.
func _update_bays_shown() -> void:
	var p: Vector3 = _player.global_position
	var z_back: float = -FOYER - (SLOT - GALLERY_W) * 0.5
	var inside: bool = (absf(p.x) < SPINE_HALF + WALL_T and p.z < ENTRANCE_Z + 0.1) or p.z < z_back
	if inside == _bays_shown:
		return
	_bays_shown = inside
	for bay in _bays:
		(bay["root"] as Node3D).visible = inside


## The entrance's sliding doors open while the walker is near them in plan and close behind them, eased; the
## leaves' colliders follow them.
func _update_doors(delta: float) -> void:
	if _door_leaves.is_empty():
		return
	var p: Vector3 = _player.global_position
	var near: bool = absf(p.x) < DOOR_REACH and absf(p.z - ENTRANCE_Z) < DOOR_REACH
	if near != _door_wanted:
		_door_wanted = near
		if _started:
			_door_sound.stream = load(DOOR_SOUNDS[0 if near else 1])
			_door_sound.play()
	_door_open = move_toward(_door_open, 1.0 if _door_wanted else 0.0, delta / DOOR_TIME)
	var t: float = _door_open * _door_open * (3.0 - 2.0 * _door_open)
	for i in _door_leaves.size():
		var s: float = signf(_door_rest[i])
		var x: float = _door_rest[i] + s * DOOR_SLIDE * t
		_door_leaves[i].position.x = x
		_door_shapes[i].position.x = x


## The head bob and the footsteps, from how far the walker went.
func _update_steps(delta: float) -> void:
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	var walking: bool = _mode == Mode.WALK and _player.is_on_floor() and speed > 0.4
	var run_share: float = clampf((speed - WALK_SPEED) / (RUN_SPEED - WALK_SPEED), 0.0, 1.0)
	_bob = move_toward(_bob, clampf(speed / WALK_SPEED, 0.0, 1.0) if walking else 0.0, delta * 3.0)
	if walking:
		var before := _step_phase
		_step_phase += speed * delta / lerpf(STEP_LENGTH, STEP_LENGTH_RUN, run_share)
		if floorf(before + 0.5) != floorf(_step_phase + 0.5):
			_play_step(run_share)
	# Lowest as a foot lands (each half step), over that foot.
	var amp: float = _bob * lerpf(1.0, BOB_RUN, run_share)
	var drop: float = BOB_DROP * amp * (1.0 - cos(TAU * _step_phase)) * 0.5
	var sway: float = BOB_SWAY * amp * sin(PI * _step_phase)
	_head.position = Vector3(sway, EYE - drop, 0.0)


func _play_step(run_share: float) -> void:
	_step_foot = 1 - _step_foot
	MusicManager.play_sfx(STEP_SOUNDS[_step_foot], STEP_DB + run_share * 3.0 + randf_range(-1.5, 1.0),
			randf_range(0.93, 1.07))


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
			_orbit_goal.z = maxf(ORBIT_MIN, _orbit_goal.z - 0.25)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_orbit_goal.z = minf(ORBIT_MAX, _orbit_goal.z + 0.25)
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
	_play_at(bay["root"], Vector3(0.0, DAIS_H, 0.0), "lineup_on" if on else "lineup_off")
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
	var energy: float = 5.0 if on else 1.4
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
		var was: float = bay["lift"]
		if not is_equal_approx(was, goal):
			bay["lift"] = move_toward(was, goal, delta / LIFT_TIME)
			_pose_lift(bay)
		_lift_sounds(bay, was, delta)


## A lift's sounds from how it moved this frame (`was`: its travel before), as GARAGE_SOUNDS says.
func _lift_sounds(bay: Dictionary, was: float, delta: float) -> void:
	var now: float = bay["lift"]
	var dir: int = 0 if is_equal_approx(now, was) else (1 if now > was else -1)
	var last: int = bay.get("dir", 0)
	if dir == 0 and last == 0 and not bay.get("humming", false):
		return
	var root: Node3D = bay["root"]
	var travel: float = (bay["carriage"] as Node3D).position.y - float(bay["car_y"]) - LIFT_REST
	var at := Vector3(0.0, float(bay["car_y"]) + travel + LIFT_REST, 0.0)
	if dir != last:
		if dir > 0:
			bay["lock_next"] = (floorf(travel / LOCK_STEP) + 1.0) * LOCK_STEP
		elif dir < 0:
			_play_at(root, at, "release")
		bay["dir"] = dir
	if dir > 0:
		# The safety locks on the posts, a clack as the carriage passes each (none just under the top: the clunk).
		var full: float = float(bay["contact"]) - PAD_TOP + LIFT_HEIGHT - LIFT_REST
		while travel >= float(bay["lock_next"]):
			if float(bay["lock_next"]) < full - LOCK_STEP * 0.4:
				var side: float = 1.0 if bay.get("lock_side", false) else -1.0
				bay["lock_side"] = side < 0.0
				_play_at(root, Vector3(side * float(bay["post_x"]), at.y + CARRIAGE_H * 0.5, 0.0), "lock",
						randf_range(-1.5, 0.5), randf_range(0.94, 1.06))
			bay["lock_next"] = float(bay["lock_next"]) + LOCK_STEP
	if dir != 0 and is_equal_approx(now, 1.0 if dir > 0 else 0.0):
		_play_at(root, at, "top" if dir > 0 else "bottom")
	# The hums: the running one louder and higher as the carriage speeds up (smoothstep's slope, 1.5 at its most).
	var speed: float = 6.0 * now * (1.0 - now) / 1.5 if dir != 0 else 0.0
	var any := false
	for key in ["motor", "lower"]:
		var on: bool = dir == (1 if key == "motor" else -1)
		var gains: Dictionary = bay.get_or_add("hum_gain", {})
		var gain: float = move_toward(gains.get(key, 0.0), lerpf(0.45, 1.0, speed) if on else 0.0, delta / HUM_FADE)
		gains[key] = gain
		var players: Dictionary = bay.get_or_add("hums", {})
		var p: AudioStreamPlayer3D = players.get(key)
		if gain <= 0.0:
			if p and p.playing:
				p.stop()
			continue
		any = true
		if p == null:
			p = _sound_player(key)
			p.position = Vector3(float(bay["post_x"]), DAIS_H + 0.3, 0.0)
			root.add_child(p)
			players[key] = p
		if not p.playing:
			p.play(randf() * p.stream.get_length())
		p.volume_db = float(GARAGE_SOUNDS[key][1]) + linear_to_db(gain)
		p.pitch_scale = lerpf(0.9, 1.04, speed) if key == "motor" else lerpf(0.95, 1.03, speed)
	bay["humming"] = any


## A 3D player for one of GARAGE_SOUNDS, at its level, not yet in the tree.
func _sound_player(key: String) -> AudioStreamPlayer3D:
	if not _sounds.has(key):
		_sounds[key] = load(GARAGE_SOUNDS[key][0])
	var p := AudioStreamPlayer3D.new()
	p.stream = _sounds[key]
	p.bus = &"SFX"
	p.volume_db = GARAGE_SOUNDS[key][1]
	p.unit_size = SOUND_UNIT
	p.attenuation_filter_db = 0.0
	return p


## One of GARAGE_SOUNDS once, at `pos` in `parent`'s frame (a bay's), `shift` dB over its level.
func _play_at(parent: Node3D, pos: Vector3, key: String, shift := 0.0, pitch := 1.0) -> void:
	var p := _sound_player(key)
	if p.stream == null:
		return
	p.volume_db += shift
	p.pitch_scale = pitch
	p.position = pos
	parent.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _pose_lift(bay: Dictionary) -> void:
	var t: float = smoothstep(0.0, 1.0, bay["lift"])
	var rest: float = LIFT_REST
	var top: float = float(bay["contact"]) - PAD_TOP + LIFT_HEIGHT
	var cy: float = lerpf(rest, top, t)
	(bay["carriage"] as Node3D).position.y = float(bay["car_y"]) + cy
	var raise: float = maxf(0.0, cy + PAD_TOP - float(bay["contact"]))
	(bay["car"] as Node3D).position.y = float(bay["car_y"]) + raise
	var lamp: OmniLight3D = bay["lamp"]
	lamp.light_energy = 0.7 * clampf(raise / LIFT_HEIGHT, 0.0, 1.0)
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
	_orbit_goal = Vector3(0.28, atan2(from.x, from.z), clampf(Vector2(from.x, from.z).length() + 0.4, 2.4, 3.4))
	_orbit_pitch = clampf(asin(clampf(from.y / maxf(from.length(), 0.01), -1.0, 1.0)), ORBIT_PITCH_MIN, ORBIT_PITCH_MAX)
	_orbit_yaw = _orbit_goal.y
	_orbit_dist = from.length()
	_blend_from = _eye_cam.global_transform
	_blend = 0.0
	_orbit_cam.global_transform = _blend_from
	_orbit_cam.current = true
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
	# Never into the plinth: shorten the arm when it points down, so the camera stays over the plinth's
	# top, under the lifted car.
	var low: float = (_bays[_inspected]["root"] as Node3D).global_position.y + DAIS_H + 0.15
	if dir.y < -0.01:
		dist = minf(dist, (c.y - low) / -dir.y)
	var q := PhysicsRayQueryParameters3D.create(c, c + dir * (dist + 0.4))
	q.collision_mask = 1
	q.exclude = [_player.get_rid()]
	var hit: Dictionary = _world.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and hit["collider"] == _walls:
		dist = minf(dist, c.distance_to(hit["position"]) - 0.3)
	dist = maxf(dist, 0.5)
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
	top.add_child(_label("HEADQUARTERS", 40, COL_TEXT, _font_title))
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

	# garage_sky.gdshader: a summer sky where it is seen (the roof, the doors), the studio in the reflections.
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
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

	# The sun, high behind the entrance and straight down the concourse, so it falls on its floor and never
	# on the walls between it and the galleries; it lights only SUN_LAYER.
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation = Vector3(deg_to_rad(-56.0), 0.0, 0.0)
	sun.light_energy = 1.5
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_cull_mask = 1 << (SUN_LAYER - 1)
	sun.shadow_enabled = MusicManager.shadow_quality_index > 0 and not OS.has_feature("mobile")
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 60.0
	_world.add_child(sun)

	_walls = StaticBody3D.new()
	_walls.name = "Walls"
	_world.add_child(_walls)


func _mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	match key:
		"wall":
			m.albedo_color = Color(0.64, 0.63, 0.6)
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
		"board":
			m.albedo_color = Color(0.05, 0.055, 0.065)
			m.roughness = 0.45
		"lectern":
			m.albedo_color = Color(0.11, 0.12, 0.14)
			m.metallic = 0.5
			m.roughness = 0.35
		"marble":
			m.albedo_color = Color(0.09, 0.09, 0.1)
			m.metallic = 0.1
			m.roughness = 0.18
		"steel":
			m.albedo_color = Color(0.86, 0.87, 0.89)
			m.metallic = 0.3
			m.roughness = 0.45
		"alu":
			m.albedo_color = Color(0.13, 0.14, 0.16)
			m.metallic = 0.7
			m.roughness = 0.32
		"chrome":
			m.albedo_color = Color(0.9, 0.9, 0.92)
			m.metallic = 1.0
			m.roughness = 0.12
		"case_back", "case_front":
			# A trophy case's glass in two draws round the cup: its far side (the back faces) before a ghost cup
			# (render priority 0), its near side after, so they layer the same way from every side. Drawn as one
			# double-sided glass with the ghost, all three swapped places as the camera moved.
			m.albedo_color = Color(0.75, 0.85, 0.95, 0.10)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.metallic = 0.2
			m.roughness = 0.04
			m.rim_enabled = true
			m.rim = 0.35
			m.cull_mode = BaseMaterial3D.CULL_FRONT if key == "case_back" else BaseMaterial3D.CULL_BACK
			m.render_priority = -1 if key == "case_back" else 1
		"plaque_glass":
			# Frosted a little and pale, so the plate reads against the dark column; its text draws after it.
			m.albedo_color = Color(0.82, 0.9, 0.98, 0.2)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.18
			m.rim_enabled = true
			m.rim = 0.6
			m.rim_tint = 0.2
			m.render_priority = 1
		"velvet":
			m.albedo_color = Color(0.035, 0.04, 0.07)
			m.roughness = 1.0
		"roof_glass":
			m.albedo_color = Color(0.8, 0.9, 0.95, 0.07)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.05
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"frost":
			m.albedo_color = Color(0.92, 0.95, 0.97, 0.55)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.6
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"door_glass":
			m.albedo_color = Color(0.7, 0.85, 0.85, 0.16)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.04
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"ghost":
			m.albedo_color = Color(0.25, 0.27, 0.3, 0.35)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.5
			m.render_priority = 0
		"granite":
			m.albedo_color = Color(0.56, 0.55, 0.52)
			m.roughness = 0.7
		"granite_dark":
			m.albedo_color = Color(0.2, 0.2, 0.21)
			m.roughness = 0.45
		"iron":
			m.albedo_color = Color(0.09, 0.095, 0.1)
			m.metallic = 0.6
			m.roughness = 0.5
		"soil":
			m.albedo_color = Color(0.13, 0.09, 0.06)
			m.roughness = 1.0
		"timber":
			m.albedo_color = Color(0.45, 0.3, 0.18)
			m.roughness = 0.75
		"line":
			m.albedo_color = Color(0.85, 0.85, 0.82)
			m.roughness = 0.8
		"asphalt":
			m.albedo_color = Color(0.11, 0.115, 0.12)
			m.roughness = 0.92
		"curb":
			m.albedo_color = Color(0.62, 0.61, 0.58)
			m.roughness = 0.85
		"lawn":
			m.albedo_color = Color(0.2, 0.34, 0.12)
			m.roughness = 1.0
		"hedge":
			m.albedo_color = Color(0.12, 0.26, 0.09)
			m.roughness = 1.0
		"bark":
			m.albedo_color = Color(0.25, 0.19, 0.14)
			m.roughness = 1.0
		"leaves":
			m.albedo_color = Color(0.17, 0.33, 0.12)
			m.roughness = 1.0
		"floor", "paving", "paving_dark":
			var fm := ShaderMaterial.new()
			fm.shader = FLOOR_SHADER
			if key == "paving":
				fm.set_shader_parameter("base_color", Color(0.5, 0.49, 0.46))
				fm.set_shader_parameter("slab", 1.2)
				fm.set_shader_parameter("gloss", 0.5)
			elif key == "paving_dark":
				fm.set_shader_parameter("base_color", Color(0.24, 0.24, 0.25))
				fm.set_shader_parameter("slab", 0.6)
				fm.set_shader_parameter("gloss", 0.6)
			_mats[key] = fm
			return fm
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


## A beam `w` wide and `h` deep from `a` to `b`.
func _beam(parent: Node3D, a: Vector3, b: Vector3, w: float, h: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, a.distance_to(b))
	mi.mesh = bm
	mi.material_override = mat
	mi.transform = Transform3D(Basis.looking_at(b - a, Vector3.UP), (a + b) * 0.5)
	parent.add_child(mi)
	return mi


## Lets the sun light `node` and everything drawn under it (SUN_LAYER as well as the first layer).
func _sunlit(node: Node) -> Node:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = 1 | (1 << (SUN_LAYER - 1))
	for c in node.get_children(true):
		_sunlit(c)
	return node


## A collision box on the walls' body (or `body`), in world coordinates (or the body's).
func _solid(a: Vector3, b: Vector3, body: StaticBody3D = null) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = (b - a).abs()
	cs.shape = shape
	cs.position = (a + b) * 0.5
	(body if body else _walls).add_child(cs)


## Text `height` metres tall (a line), facing +z of its frame at `pos`, made smaller if it would be wider than
## `max_w`.
func _text(parent: Node3D, text: String, height: float, color: Color, pos: Vector3, max_w := 0.0,
		font: Font = null) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 128
	l.font = font if font else _font_title
	var pixel: float = height / 128.0
	if max_w > 0.0:
		var w: float = l.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 128).x * pixel
		if w > max_w:
			pixel *= max_w / w
	l.pixel_size = pixel
	l.modulate = color
	l.outline_size = 0
	l.shaded = false
	l.double_sided = false
	l.position = pos
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	parent.add_child(l)
	return l


## A sign: a dark board `size` (width, height) metres, its back on the plane through `pos` and facing +z
## turned by `yaw`, the title fitted to its width (with `sub` under it if any) and a band of `band` light
## along its foot.
func _sign(pos: Vector3, yaw: float, size: Vector2, title: String, color: Color, sub := "", band := Color(0, 0, 0, 0)) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	_world.add_child(root)
	var hw: float = size.x * 0.5
	var hh: float = size.y * 0.5
	_box(root, Vector3(-hw, -hh, 0.0), Vector3(hw, hh, 0.06), _mat("board"), false)
	var text_w: float = size.x - 0.4
	if sub == "":
		_text(root, title, size.y * 0.62, color, Vector3(0.0, 0.03 * size.y, 0.075), text_w)
	else:
		_text(root, title, size.y * 0.48, color, Vector3(0.0, 0.14 * size.y, 0.075), text_w)
		_text(root, sub, size.y * 0.2, COL_DIM, Vector3(0.0, -0.27 * size.y, 0.075), text_w, _font_bold)
	if band.a > 0.0:
		_box(root, Vector3(-hw, -hh, 0.06), Vector3(hw, -hh + 0.035, 0.075), _glow_mat(band, 2.2), false)
	return root


## A wall along x (at `z`) or along z (at `x`), from `from` to `to` along it, `height` tall, with openings
## (Vector3: from, to along it and the top; a lintel over each). Cut into pieces of at most 8m, so no piece
## takes in more lights than the mobile renderer gives a mesh, and the dark wainscot is its own box under the
## plaster.
func _wall(along_x: bool, at: float, from: float, to: float, openings: Array = [], height := WALL_H, sun := false) -> void:
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
			next.append([maxf(a, o.x), minf(b, o.y), o.z])
			if o.y < b:
				next.append([o.y, b, 0.0])
		cuts = next
	for c in cuts:
		var a: float = c[0]
		var b: float = c[1]
		var y0: float = c[2]
		if y0 >= height:
			continue
		var n := maxi(1, ceili((b - a) / 8.0))
		for k in n:
			var s0: float = lerpf(a, b, float(k) / n)
			var s1: float = lerpf(a, b, float(k + 1) / n)
			var lo := Vector3(s0, 0.0, at - WALL_T * 0.5) if along_x else Vector3(at - WALL_T * 0.5, 0.0, s0)
			var hi := Vector3(s1, 0.0, at + WALL_T * 0.5) if along_x else Vector3(at + WALL_T * 0.5, 0.0, s1)
			var pieces: Array = []
			if y0 <= 0.0:
				pieces.append(_box(_world, Vector3(lo.x, 0.0, lo.z), Vector3(hi.x, WAINSCOT, hi.z), _mat("wainscot")))
				pieces.append(_box(_world, Vector3(lo.x, WAINSCOT, lo.z), Vector3(hi.x, height, hi.z), _mat("wall")))
			else:
				pieces.append(_box(_world, Vector3(lo.x, y0, lo.z), Vector3(hi.x, height, hi.z), _mat("wall")))
			if sun:
				for p in pieces:
					_sunlit(p)
			_solid(Vector3(lo.x, y0, lo.z), Vector3(hi.x, height, hi.z))


## Floor tiles of at most 8m over x0..x1, z0..z1 in `mat`.
func _tiles(x0: float, x1: float, z0: float, z1: float, mat: Material, sun := false, y := 0.0) -> void:
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
			mi.position = Vector3((a.x + b.x) * 0.5, y, (a.y + b.y) * 0.5)
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_world.add_child(mi)
			if sun:
				_sunlit(mi)


## A room's floor and, at `ceiling` (0: none), its ceiling.
func _room(x0: float, x1: float, z0: float, z1: float, ceiling: float, sun := false) -> void:
	_tiles(x0, x1, z0, z1, _mat("floor"), sun)
	if ceiling > 0.0:
		_box(_world, Vector3(x0, ceiling, z0), Vector3(x1, ceiling + 0.3, z1), _mat("ceiling"), false)


func _omni(pos: Vector3, energy: float, reach: float) -> void:
	var o := OmniLight3D.new()
	o.position = pos
	o.light_energy = energy
	o.omni_range = reach
	o.omni_attenuation = 1.2
	o.light_color = Color(1.0, 0.95, 0.88)
	o.shadow_enabled = false
	_world.add_child(o)


# ============================================================================================
#  The hall
# ============================================================================================

func _build_hall() -> void:
	var slots: int = ceili(_galleries.size() / 2.0)
	_spine_end = -FOYER - slots * SLOT
	var per_wall: int = ceili(NetworkManager.GP_CUPS.size() * 0.5)
	_hall_d = maxf(HALL_D_MIN, per_wall * RECORD_BOARD_STEP + 2.0 * RECORD_BOARD_MARGIN)
	var left_doors: Array = []
	var right_doors: Array = []
	for gi in _galleries.size():
		var g: Dictionary = _galleries[gi]
		var side: float = -1.0 if gi % 2 == 0 else 1.0
		var slot: int = gi / 2
		var z_top: float = -FOYER - slot * SLOT - (SLOT - GALLERY_W) * 0.5
		var z_bot: float = z_top - GALLERY_W
		var zc: float = (z_top + z_bot) * 0.5
		var cols: int = ceili((g["cars"] as Array).size() / 2.0)
		var length: float = G_ENTRY + (cols - 1) * BAY + G_END
		var x_in: float = side * SPINE_HALF
		var x_out: float = side * (SPINE_HALF + length)
		(left_doors if side < 0.0 else right_doors).append(Vector3(zc - DOOR_W * 0.5, zc + DOOR_W * 0.5, DOOR_H))
		_room(minf(x_in, x_out), maxf(x_in, x_out), z_bot, z_top, WALL_H)
		# The first pair's front walls face the plaza's grounds: in the sun (their inside faces away from it).
		_wall(true, z_top, x_in, x_out + side * WALL_T * 0.5, [], WALL_H, slot == 0)
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

	# The concourse (its roof is _build_roof's), its walls with the galleries' doors, the entrance wall
	# (its doors are _build_entrance's), and the trophy hall, whose front wall closes the roof's gable.
	_room(-SPINE_HALF, SPINE_HALF, _spine_end, ENTRANCE_Z, 0.0, true)
	_wall(false, -SPINE_HALF, _spine_end, ENTRANCE_Z, left_doors, WALL_H, true)
	_wall(false, SPINE_HALF, _spine_end, ENTRANCE_Z, right_doors, WALL_H, true)
	_wall(true, ENTRANCE_Z, -SPINE_HALF - WALL_T * 0.5, SPINE_HALF + WALL_T * 0.5,
			[Vector3(-FRONT_GLASS_HALF, FRONT_GLASS_HALF, FRONT_GLASS_H)], TALL_H, true)
	var hall_back: float = _spine_end - _hall_d
	_room(-HALL_HALF, HALL_HALF, hall_back, _spine_end, TALL_H)
	_wall(true, _spine_end, -HALL_HALF - WALL_T * 0.5, HALL_HALF + WALL_T * 0.5,
			[Vector3(-SPINE_HALF, SPINE_HALF, WALL_H)], TALL_H, true)
	_wall(true, hall_back, -HALL_HALF - WALL_T * 0.5, HALL_HALF + WALL_T * 0.5, [], TALL_H)
	_wall(false, -HALL_HALF, hall_back, _spine_end, [], TALL_H)
	_wall(false, HALL_HALF, hall_back, _spine_end, [], TALL_H)
	# The floor's collision, under everything, outside too.
	_solid(Vector3(-200.0, -1.0, hall_back - 10.0), Vector3(200.0, 0.0, ENTRANCE_Z + PLAZA_DEPTH + 40.0))

	# Lamps along the concourse for the parts the sun doesn't reach.
	var z := ENTRANCE_Z - 3.0
	while z > _spine_end:
		_omni(Vector3(0.0, WALL_H - 0.6, z), 0.6, 10.0)
		z -= 9.0
	# The sign hangs across the foyer from the roof, short of the first pair of doors.
	var sign_z: float = -FOYER + 1.2
	_sign(Vector3(0.0, 4.25, sign_z), 0.0, Vector2(6.6, 1.3), "THE COLLECTION", COL_TEXT, "RC VIBE GP", COL_GOLD)
	for x in [-2.6, 2.6]:
		var roof_y: float = WALL_H + (RIDGE_H - WALL_H) * (1.0 - absf(x) / SPINE_HALF)
		_box(_world, Vector3(x - 0.015, 4.9, sign_z + 0.015), Vector3(x + 0.015, roof_y, sign_z + 0.045), _mat("alu"), false)


## A gallery's sign over its door, its name on the end wall, a stripe in its colour round its walls, the
## light strip down its aisle.
func _dress_gallery(g: Dictionary, side: float, x_in: float, x_out: float, z_top: float, z_bot: float) -> void:
	var color: Color = g["color"]
	var zc: float = (z_top + z_bot) * 0.5
	var glow := _glow_mat(color, 2.2)
	var name_up := str(g["name"]).to_upper()
	var n: int = (g["cars"] as Array).size()
	# Over the door on the concourse side, on the lintel.
	var face_in: float = -side * PI * 0.5
	_sign(Vector3(x_in - side * WALL_T * 0.5, DOOR_H + 0.85, zc), face_in, Vector2(DOOR_W + 0.2, 1.3),
			name_up, color.lightened(0.3), "%d CAR%s" % [n, "" if n == 1 else "S"], color)
	# On the end wall, facing back up the aisle.
	_sign(Vector3(x_out - side * WALL_T * 0.5, 3.75, zc), face_in,
			Vector2(minf(GALLERY_W - 3.0, 7.0), 1.3), name_up, color.lightened(0.25), "", color)
	# A stripe round the inside at 2.6m: along both long walls and the end wall.
	var y0 := 2.55
	var y1 := 2.65
	var t: float = WALL_T * 0.5
	var end_x: float = x_out - side * (t + 0.015)
	_box(_world, Vector3(minf(x_in, x_out), y0, z_top - t - 0.03), Vector3(maxf(x_in, x_out), y1, z_top - t), glow, false)
	_box(_world, Vector3(minf(x_in, x_out), y0, z_bot + t), Vector3(maxf(x_in, x_out), y1, z_bot + t + 0.03), glow, false)
	_box(_world, Vector3(end_x - 0.015, y0, z_bot + t), Vector3(end_x + 0.015, y1, z_top - t), glow, false)
	# The aisle's light strip, and lamps along it for the floor and walls.
	_box(_world, Vector3(minf(x_in, x_out) + 1.0, WALL_H - 0.06, zc - 0.2), Vector3(maxf(x_in, x_out) - 1.0, WALL_H, zc + 0.2), _mat("strip"), false)
	_omni(Vector3(lerpf(x_in, x_out, 0.3), WALL_H - 0.8, zc), 0.6, 9.0)
	_omni(Vector3(lerpf(x_in, x_out, 0.8), WALL_H - 0.8, zc), 0.6, 9.0)


## The concourse's glass gable roof: white steel rafters every 3m with a tie across their feet, a ridge
## beam and purlins, glass between. The sky shows through it and the sun casts the steel's shadow.
func _build_roof() -> void:
	var z0: float = _spine_end + 0.25
	var z1: float = ENTRANCE_Z - 0.25
	var foot: float = SPINE_HALF + 0.2
	var rise: float = RIDGE_H - WALL_H
	var steel := _mat("steel")
	var roof := Node3D.new()
	roof.name = "GlassRoof"
	_world.add_child(roof)
	var z := z1
	while z >= z0 - 0.01:
		for s in [-1.0, 1.0]:
			_beam(roof, Vector3(s * foot, WALL_H + 0.1, z), Vector3(0.0, RIDGE_H + 0.02, z), 0.1, 0.2, steel)
		_beam(roof, Vector3(-foot, WALL_H - 0.08, z), Vector3(foot, WALL_H - 0.08, z), 0.05, 0.05, steel)
		z -= 3.0
	_beam(roof, Vector3(0.0, RIDGE_H + 0.02, z1), Vector3(0.0, RIDGE_H + 0.02, z0), 0.14, 0.2, steel)
	for s in [-1.0, 1.0]:
		var mid := Vector3(s * foot * 0.5, WALL_H + 0.1 + rise * 0.5, 0.0)
		_beam(roof, Vector3(mid.x, mid.y, z1), Vector3(mid.x, mid.y, z0), 0.08, 0.12, steel)
	_sunlit(roof)
	# The glass: a pane per slope per stretch of 8m, lying on the rafters.
	var slope := Vector2(foot, rise + 0.08)
	var across: float = slope.length() + 0.2
	var n := maxi(1, ceili((z1 - z0) / 8.0))
	for s in [-1.0, 1.0]:
		var along := Vector3(-s * slope.x, slope.y, 0.0).normalized()
		var up := Vector3(0.0, 0.0, 1.0).cross(along)
		if up.y < 0.0:
			up = -up
		var basis := Basis(along, up, along.cross(up))
		for k in n:
			var za: float = lerpf(z1, z0, float(k) / n)
			var zb: float = lerpf(z1, z0, float(k + 1) / n)
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(across, 0.02, absf(zb - za))
			mi.mesh = bm
			mi.material_override = _mat("roof_glass")
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var centre := Vector3(s * foot * 0.5, WALL_H + 0.1 + rise * 0.5, (za + zb) * 0.5) + up * 0.12
			mi.transform = Transform3D(basis, centre)
			roof.add_child(mi)


## The entrance: glazed double doors in an aluminium frame with a transom over them, pull handles, a mat,
## an EXIT sign, in a glazed front across the foyer; outside, a canopy, the name over it and the plaza (_build_plaza).
## The doors' leaves slide open as the walker comes near (_update_doors).
func _build_entrance() -> void:
	var z := ENTRANCE_Z
	var door := Node3D.new()
	door.name = "Entrance"
	_world.add_child(door)
	var alu := _mat("alu")
	var f := 0.07
	var transom := 2.6
	# The frame: jambs, head, the transom bar and the glass over it.
	for s in [-1.0, 1.0]:
		_box(door, Vector3(s * ENTRY_HALF - f, 0.0, z - 0.07), Vector3(s * ENTRY_HALF + f, ENTRY_H, z + 0.07), alu)
	_box(door, Vector3(-ENTRY_HALF, ENTRY_H - 0.1, z - 0.07), Vector3(ENTRY_HALF, ENTRY_H, z + 0.07), alu)
	_box(door, Vector3(-ENTRY_HALF, transom, z - 0.06), Vector3(ENTRY_HALF, transom + 0.08, z + 0.06), alu)
	var glass := _mat("door_glass")
	_box(door, Vector3(-ENTRY_HALF + f, transom + 0.08, z - 0.004), Vector3(ENTRY_HALF - f, ENTRY_H - 0.1, z + 0.004), glass, false)
	# The automatic sliding leaves, just inside the frame: each slides out behind the side glass as the walker comes
	# near (_update_doors), on a track under the transom. Each has a collider of its own on the walls' body that
	# moves with it.
	var zl: float = z - DOOR_LEAF_IN
	_box(door, Vector3(-ENTRY_HALF - DOOR_SLIDE - 0.1, transom, zl - 0.09), Vector3(ENTRY_HALF + DOOR_SLIDE + 0.1, transom + 0.16, zl + 0.06), alu)
	var lw: float = ENTRY_HALF - 0.02
	for s in [-1.0, 1.0]:
		var leaf := Node3D.new()
		leaf.name = "DoorLeaf_%s" % ("L" if s < 0.0 else "R")
		leaf.position = Vector3(s * lw * 0.5, 0.0, zl)
		door.add_child(leaf)
		var h: float = lw * 0.5
		for sx in [-1.0, 1.0]:
			_box(leaf, Vector3(sx * h - (0.07 if sx > 0.0 else 0.0), 0.0, -0.04), Vector3(sx * h + (0.0 if sx > 0.0 else 0.07), transom - 0.01, 0.04), alu)
		_box(leaf, Vector3(-h, 0.0, -0.04), Vector3(h, 0.16, 0.04), alu)
		_box(leaf, Vector3(-h, transom - 0.09, -0.04), Vector3(h, transom - 0.01, 0.04), alu)
		_box(leaf, Vector3(-h + 0.07, 0.16, -0.004), Vector3(h - 0.07, transom - 0.09, 0.004), glass, false)
		# A frosted band at eye height, so the glass reads as a door.
		_box(leaf, Vector3(-h + 0.07, 1.42, -0.006), Vector3(h - 0.07, 1.52, 0.006), _mat("frost"), false)
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(lw, transom, 0.2)
		cs.shape = shape
		cs.position = leaf.position + Vector3(0.0, transom * 0.5, 0.0)
		_walls.add_child(cs)
		_door_leaves.append(leaf)
		_door_shapes.append(cs)
		_door_rest.append(leaf.position.x)
	_door_sound = AudioStreamPlayer3D.new()
	_door_sound.name = "DoorSound"
	_door_sound.position = Vector3(0.0, transom, z)
	_door_sound.unit_size = SOUND_UNIT
	_door_sound.volume_db = DOOR_DB
	_world.add_child(_door_sound)
	_sunlit(door)
	# Inside: the mat and the EXIT sign.
	_box(_world, Vector3(-1.4, 0.0, z - 1.5), Vector3(1.4, 0.012, z - 0.25), _mat("rubber"), false)
	var exit_root := Node3D.new()
	exit_root.position = Vector3(0.0, ENTRY_H + 0.45, z - WALL_T * 0.5)
	exit_root.rotation.y = PI
	_world.add_child(exit_root)
	_box(exit_root, Vector3(-0.42, -0.15, 0.0), Vector3(0.42, 0.15, 0.06), _glow_mat(Color(0.1, 0.75, 0.3), 1.6), false)
	_text(exit_root, "EXIT", 0.2, Color.WHITE, Vector3(0.0, 0.0, 0.075), 0.7)

	# The glazed front either side of the doors and over them (the wall's opening is _build_hall's): mullions, a
	# transom at the doors' head, a header, glass. The plaza shows through it from the foyer.
	var glaze := Node3D.new()
	glaze.name = "GlassFront"
	_world.add_child(glaze)
	var gw: float = FRONT_GLASS_HALF
	var gh: float = FRONT_GLASS_H
	for s in [-1.0, 1.0]:
		for x in [ENTRY_HALF, FRONT_MULLION_X, gw]:
			var lo_y: float = ENTRY_H if is_equal_approx(x, ENTRY_HALF) else 0.0
			_box(glaze, Vector3(s * x - f, lo_y, z - 0.08), Vector3(s * x + f, gh, z + 0.08), alu)
		var x0: float = minf(s * ENTRY_HALF, s * gw)
		var x1: float = maxf(s * ENTRY_HALF, s * gw)
		_box(glaze, Vector3(x0, 0.0, z - 0.07), Vector3(x1, 0.1, z + 0.07), alu)
		_box(glaze, Vector3(x0, 0.1, z - 0.004), Vector3(x1, ENTRY_H, z + 0.004), glass, false)
		_solid(Vector3(x0, 0.0, z - 0.2), Vector3(x1, ENTRY_H, z + 0.2))
	_box(glaze, Vector3(-gw, ENTRY_H - 0.05, z - 0.08), Vector3(gw, ENTRY_H + 0.05, z + 0.08), alu)
	_box(glaze, Vector3(-gw, gh - 0.12, z - 0.1), Vector3(gw, gh, z + 0.1), alu)
	_box(glaze, Vector3(-gw, ENTRY_H + 0.05, z - 0.004), Vector3(gw, gh - 0.12, z + 0.004), glass, false)
	_sunlit(glaze)

	# Outside, all in the sun: the canopy over the doors, then the plaza.
	var out := Node3D.new()
	out.name = "Outside"
	_world.add_child(out)
	var zo: float = z + WALL_T * 0.5
	_box(out, Vector3(-3.2, 3.6, zo), Vector3(3.2, 3.75, zo + 3.6), _mat("steel"))
	for s in [-1.0, 1.0]:
		_box(out, Vector3(s * 3.0 - 0.07, 0.0, zo + 3.3), Vector3(s * 3.0 + 0.07, 3.6, zo + 3.44), _mat("steel"))
		_solid(Vector3(s * 3.0 - 0.1, 0.0, zo + 3.27), Vector3(s * 3.0 + 0.1, 3.6, zo + 3.47))
	# The name over the canopy, on the front wall above the glass: the logo and HEADQUARTERS under it.
	var logo_scene := load(LOGO_PATH) as PackedScene
	if logo_scene:
		var logo := logo_scene.instantiate() as Node3D
		logo.position = Vector3(0.0, 6.55, zo + 0.06)
		logo.scale = Vector3.ONE * 0.2
		out.add_child(logo)
	_text(out, "HEADQUARTERS", 0.42, COL_TEXT, Vector3(0.0, 5.42, zo + 0.02), 7.6, _font_bold)
	_box(out, Vector3(-3.9, 5.08, zo), Vector3(3.9, 5.12, zo + 0.03), _glow_mat(COL_GOLD, 1.6), false)
	_build_plaza(out, zo)
	_sunlit(out)


## The plaza in front of the headquarters (all at life size, in `out`'s frame, `zo` the entrance wall's outer face):
## granite paving out to the road, an avenue of London planes either side in iron tree grates with benches and lamps
## between them, a round fountain on the axis (fountain_water.gdshader, as Estación Seca's), the RC Vibe GP logo on a
## plinth beyond it facing the doors, weeping cherries flanking it, Japanese maples in stone planters either side of
## the doors with azaleas round them, beds of azaleas along the plaza's edges, flags at the road, birches on the lawns.
## The trees are the courses' own detailed ones, baked by regenerate_headquarters_trees.gd. The walker can come out
## here (the doors slide open), so what stands on it is solid and hedges (and the kerb) bound the grounds.
func _build_plaza(out: Node3D, zo: float) -> void:
	var z_road: float = zo + PLAZA_DEPTH
	var half: float = PLAZA_HALF
	_tiles_in(out, -half, half, zo, z_road, _mat("paving"))
	# A band of darker stone round the fountain and down the axis to the doors.
	_tiles_in(out, -1.8, 1.8, zo + 3.6, zo + PLAZA_FOUNTAIN_Z - 5.6, _mat("paving_dark"), 0.006)
	_box(out, Vector3(-half, 0.0, z_road - 0.3), Vector3(half, 0.15, z_road), _mat("curb"))
	_tiles_in(out, -140.0, 140.0, z_road, z_road + 8.0, _mat("asphalt"), -0.02)
	_box(out, Vector3(-140.0, 0.0, z_road + 8.0), Vector3(140.0, 0.15, z_road + 8.3), _mat("curb"))
	for x in range(-12, 13, 4):
		_box(out, Vector3(x - 0.15, 0.003, z_road + 3.92), Vector3(x + 1.6, 0.012, z_road + 4.08), _mat("line"), false)
	_tiles_in(out, -140.0, 140.0, z_road + 8.3, z_road + 150.0, _mat("lawn"), 0.0)
	# Lawn round the building and either side of the plaza, a little under the floors and the paving.
	_tiles_in(out, -140.0, 140.0, _spine_end - _hall_d - 30.0, z_road, _mat("lawn"), -0.03)
	var trees := {}
	# The trees follow the Detail Level (MusicManager.grass_quality_index, read once as the headquarters is built):
	# Ultra, every tree casts its own detailed shadow; High, the plaza's trees cast theirs through their far stand-ins
	# (the detailed crowns' leaf cards cost about 3ms of an M1 at 1600x1000 in the shadow pass) and the birches on the
	# lawns none; Medium, only the planes' and the cherries' stand-ins; Low, no tree shadows; Off, nor the trees across
	# the road. `plaza` false: a tree on the lawns or across the road.
	var q: int = MusicManager.grass_quality_index
	var tree := func(kind: String, pos: Vector3, yaw: float, sc: float, plaza := true) -> void:
		if q <= 0 and pos.z > z_road:
			return
		if not trees.has(kind):
			var path: String = "res://generated/headquarters_tree_%s.res" % kind
			trees[kind] = load(path) if ResourceLoader.exists(path) else null
		if trees[kind] == null:
			return
		var mi := MeshInstance3D.new()
		mi.mesh = trees[kind]
		mi.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * sc), pos)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if q >= 4 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		out.add_child(mi)
		var big: bool = kind.begins_with("plane") or kind.begins_with("shidare")
		if not plaza or q >= 4 or q <= 1 or (q == 2 and not big):
			return
		var sk: String = kind + "_shadow"
		if not trees.has(sk):
			var sp: String = "res://generated/headquarters_tree_%s.res" % sk
			trees[sk] = load(sp) if ResourceLoader.exists(sp) else null
		if trees[sk] != null:
			var sh := MeshInstance3D.new()
			sh.mesh = trees[sk]
			sh.transform = mi.transform
			sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			out.add_child(sh)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2611

	# The avenue: planes in iron grates, a bench facing the axis and a lamp between each pair.
	for s in [-1.0, 1.0]:
		for k in PLAZA_AVENUE.size():
			var tz: float = zo + float(PLAZA_AVENUE[k])
			var tx: float = s * PLAZA_AVENUE_X
			tree.call("plane_%d" % (k % 2), Vector3(tx, -0.05, tz), rng.randf() * TAU, rng.randf_range(0.82, 0.95))
			_tree_grate(out, Vector3(tx, 0.0, tz))
			_solid_post(Vector3(tx, 0.0, tz), 0.45, 4.0)
			if k + 1 < PLAZA_AVENUE.size():
				var mz: float = zo + (float(PLAZA_AVENUE[k]) + float(PLAZA_AVENUE[k + 1])) * 0.5
				_bench(out, Vector3(s * (PLAZA_AVENUE_X - 2.2), 0.0, mz), -s * PI * 0.5)
				_solid(Vector3(s * (PLAZA_AVENUE_X - 2.2) - 0.35, 0.0, mz - 1.08), Vector3(s * (PLAZA_AVENUE_X - 2.2) + 0.35, 0.9, mz + 1.08))
				_lamp_post(out, Vector3(tx, 0.0, mz))
				_solid_post(Vector3(tx, 0.0, mz), 0.12, 5.0)
	# The fountain on the axis.
	_fountain(out, Vector3(0.0, 0.0, zo + PLAZA_FOUNTAIN_Z))
	_solid_post(Vector3(0.0, 0.0, zo + PLAZA_FOUNTAIN_Z), 5.1, 0.7)
	_solid_post(Vector3(0.0, 0.0, zo + PLAZA_FOUNTAIN_Z), 0.65, 3.0)
	# The logo on its plinth beyond, facing the doors, a weeping cherry either side.
	var lz: float = zo + PLAZA_LOGO_Z
	_box(out, Vector3(-3.6, 0.0, lz - 0.7), Vector3(3.6, 1.1, lz + 0.7), _mat("granite"))
	_box(out, Vector3(-3.75, 1.1, lz - 0.85), Vector3(3.75, 1.22, lz + 0.85), _mat("granite_dark"))
	_solid(Vector3(-3.75, 0.0, lz - 0.85), Vector3(3.75, 4.6, lz + 0.85))
	var logo_scene := load(LOGO_PATH) as PackedScene
	if logo_scene:
		var logo := logo_scene.instantiate() as Node3D
		logo.position = Vector3(0.0, 1.22 + 1.6, lz)
		logo.rotation.y = PI
		logo.scale = Vector3.ONE * 0.72
		out.add_child(logo)
	for s in [-1.0, 1.0]:
		var cp := Vector3(s * 7.6, 0.0, lz + 0.5)
		_round_planter(out, cp, 2.6, 0.55)
		_solid_post(cp, 2.6, 1.2)
		tree.call("shidare_0", cp + Vector3(0.0, 0.45, 0.0), rng.randf() * TAU, 1.0)
		for k in 7:
			var a: float = TAU * k / 7.0 + rng.randf() * 0.3
			tree.call("tsutsuji_%d" % (k % 2), cp + Vector3(cos(a) * 1.85, 0.45, sin(a) * 1.85), rng.randf() * TAU, 0.7)
	# Japanese maples in stone planters either side of the doors, azaleas at their feet.
	for s in [-1.0, 1.0]:
		var mp := Vector3(s * 7.0, 0.0, zo + 4.2)
		_square_planter(out, mp, Vector2(4.4, 3.4), 0.6)
		_solid(mp - Vector3(2.2, 0.0, 1.7), mp + Vector3(2.2, 1.2, 1.7))
		tree.call("momiji_red_%d" % (0 if s < 0.0 else 1), mp + Vector3(0.0, 0.5, 0.0), rng.randf() * TAU, 0.95)
		for k in 6:
			var px: float = lerpf(-1.75, 1.75, float(k) / 5.0)
			tree.call("tsutsuji_%d" % (k % 2), mp + Vector3(px, 0.5, s * 0.0 + (1.25 if k % 2 == 0 else -1.25)),
					rng.randf() * TAU, 0.62)
	# Beds of azaleas and a green maple at each corner of the plaza, toward the road.
	for s in [-1.0, 1.0]:
		var bp := Vector3(s * (half - 6.0), 0.0, z_road - 4.5)
		_square_planter(out, bp, Vector2(9.0, 4.0), 0.45)
		_solid(bp - Vector3(4.5, 0.0, 2.0), bp + Vector3(4.5, 1.2, 2.0))
		tree.call("momiji_0", bp + Vector3(s * 2.2, 0.4, 0.0), rng.randf() * TAU, 0.9)
		for k in 9:
			var px: float = lerpf(-4.0, 1.0, float(k) / 8.0) * s
			tree.call("tsutsuji_%d" % (k % 2), bp + Vector3(px, 0.4, rng.randf_range(-1.2, 1.2)), rng.randf() * TAU,
					rng.randf_range(0.6, 0.75))
	# Flags at the plaza's front, either side of the axis.
	for x in [-11.0, 11.0]:
		var flag := LogoFlag.new()
		flag.position = Vector3(x, 0.0, z_road - 1.6)
		# Both streaming the same way (along +x), broadside to the doors.
		flag.scale = Vector3.ONE * 0.62
		out.add_child(flag)
	# Bollards along the kerb.
	var bx := -half + 1.0
	while bx < half:
		if absf(bx) > 2.5:
			_bollard(out, Vector3(bx, 0.0, z_road - 0.8))
		bx += 2.4
	# The grounds end at the kerb (an invisible rail between the bollards), hedges along the lawns' edge by the road,
	# hedges down either side, and hedges from the first galleries' far corners out to the side ones.
	_solid(Vector3(-GROUNDS_HALF, 0.0, z_road - 1.0), Vector3(GROUNDS_HALF, 2.5, z_road - 0.6))
	var z_back: float = -FOYER - (SLOT - GALLERY_W) * 0.5
	for s in [-1.0, 1.0]:
		_hedge(out, Vector3(s * half, 0.0, z_road - 1.6), Vector3(s * GROUNDS_HALF, 1.0, z_road - 0.6))
		_hedge(out, Vector3(s * GROUNDS_HALF - 0.5, 0.0, z_back), Vector3(s * GROUNDS_HALF + 0.5, 1.3, z_road - 0.6))
		var corner: float = SPINE_HALF
		for r in _rooms:
			var rect: Rect2 = r["rect"]
			if signf(r["side"]) == s and absf(rect.end.y - z_back) < 0.01:
				corner = maxf(absf(rect.position.x), absf(rect.end.x)) + WALL_T * 0.5
		_hedge(out, Vector3(s * corner, 0.0, z_back - 0.5), Vector3(s * GROUNDS_HALF, 1.3, z_back + 0.5))
	# The building's faces on the grounds: the first galleries' fronts (their names on them) and the concourse's
	# sides between them and the foyer's front.
	var face_z: float = z_back + WALL_T * 0.5
	for r in _rooms:
		var rect: Rect2 = r["rect"]
		if absf(rect.end.y - z_back) > 0.01:
			continue
		var sd: float = signf(r["side"])
		_facade(out, Vector3(sd * (SPINE_HALF + WALL_T * 0.5), 0.0, face_z), Vector3(sd * (maxf(absf(rect.position.x),
				absf(rect.end.x)) + WALL_T * 0.5), 0.0, face_z), Vector3(0, 0, 1), str(r["name"]).to_upper(), r["color"])
	for sd in [-1.0, 1.0]:
		var fx: float = sd * (SPINE_HALF + WALL_T * 0.5)
		_facade(out, Vector3(fx, 0.0, face_z), Vector3(fx, 0.0, ENTRANCE_Z - WALL_T * 0.5), Vector3(sd, 0, 0), "", COL_GOLD)
	# Birches on the lawns either side of the plaza and across the road; planes further off.
	for i in 22:
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var p := Vector3(side * rng.randf_range(half + 5.0, half + 40.0), -0.05, zo + rng.randf_range(-6.0, PLAZA_DEPTH - 4.0))
		tree.call("birch_%d" % (i % 2), p, rng.randf() * TAU, rng.randf_range(0.8, 1.05), false)
		_solid_post(p, 0.25, 4.0)
	# Two maples and azaleas in each lawn between the foyer and the first galleries.
	for s in [-1.0, 1.0]:
		for k in 2:
			var mp := Vector3(s * (9.0 + k * 6.5), -0.03, zo - 5.0 - k * 4.5)
			tree.call("momiji_0" if k == 0 else "momiji_red_1", mp, rng.randf() * TAU, 0.85)
			_solid_post(mp, 0.25, 3.0)
			for j in 5:
				var a: float = TAU * j / 5.0 + rng.randf()
				tree.call("tsutsuji_%d" % (j % 2), mp + Vector3(cos(a) * 2.4, 0.0, sin(a) * 2.4), rng.randf() * TAU, 0.65)
	for i in 26:
		var p := Vector3(rng.randf_range(-70.0, 70.0), -0.05, z_road + rng.randf_range(16.0, 75.0))
		var kind: String = "birch_%d" % (i % 2) if i % 3 != 0 else "plane_%d" % (i % 2)
		tree.call(kind, p, rng.randf() * TAU, rng.randf_range(0.8, 1.05), false)


## Dresses a stretch of the building's outside face, from `a` to `b` on the ground, facing `n`: aluminium pilasters
## about every 3.5m up to a fascia along the top, an accent line in `color` under it, and `label` across the middle.
func _facade(out: Node3D, a: Vector3, b: Vector3, n: Vector3, label: String, color: Color) -> void:
	# A right-handed frame: x along the face as seen from outside, y up, z out of it.
	var x_axis: Vector3 = Vector3.UP.cross(n).normalized()
	var ta: float = a.dot(x_axis)
	var tb: float = b.dot(x_axis)
	var length: float = absf(tb - ta)
	if length < 0.5:
		return
	var root := Node3D.new()
	root.position = a if ta < tb else b
	root.basis = Basis(x_axis, Vector3.UP, n.normalized())
	out.add_child(root)
	var alu := _mat("alu")
	var count: int = maxi(1, roundi(length / 3.5))
	for k in count + 1:
		var x: float = clampf(length * float(k) / count, 0.2, length - 0.2)
		_box(root, Vector3(x - 0.2, 0.0, 0.0), Vector3(x + 0.2, WALL_H + 0.3, 0.22), alu)
	_box(root, Vector3(0.0, WALL_H - 0.35, 0.0), Vector3(length, WALL_H + 0.3, 0.26), alu)
	_box(root, Vector3(0.0, WALL_H - 0.47, 0.0), Vector3(length, WALL_H - 0.41, 0.05), _glow_mat(color, 1.8), false)
	if label != "":
		_text(root, label, 0.55, color.lightened(0.25), Vector3(length * 0.5, 3.0, 0.24), length - 1.4, _font_bold)


## A cylinder collider standing on the ground at `p`.
func _solid_post(p: Vector3, r: float, h: float) -> void:
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = h
	cs.shape = shape
	cs.position = Vector3(p.x, h * 0.5, p.z)
	_walls.add_child(cs)


## A clipped hedge filling the box from `a` to `b` (hedge.gdshader: UVs in metres on every face, the colour the
## foliage's tint), solid.
func _hedge(out: Node3D, a: Vector3, b: Vector3) -> void:
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	if not _mats.has("hedge_leaf"):
		var hm := ShaderMaterial.new()
		hm.shader = load("res://hedge.gdshader")
		_mats["hedge_leaf"] = hm
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var col := Color(0.42, 0.6, 0.3)
	# Five faces (no bottom), each [corner, edge u, edge v], wound so they face out.
	var size: Vector3 = hi - lo
	var faces := [
		[Vector3(lo.x, hi.y, lo.z), Vector3(size.x, 0, 0), Vector3(0, 0, size.z)],
		[Vector3(lo.x, lo.y, hi.z), Vector3(size.x, 0, 0), Vector3(0, size.y, 0)],
		[Vector3(hi.x, lo.y, lo.z), Vector3(-size.x, 0, 0), Vector3(0, size.y, 0)],
		[Vector3(hi.x, lo.y, hi.z), Vector3(0, 0, -size.z), Vector3(0, size.y, 0)],
		[Vector3(lo.x, lo.y, lo.z), Vector3(0, 0, size.z), Vector3(0, size.y, 0)],
	]
	for f in faces:
		var o: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var n: Vector3 = v.cross(u).normalized()
		if n.dot((o + (u + v) * 0.5) - (lo + hi) * 0.5) < 0.0:
			n = -n
		var q := [o, o + u, o + u + v, o + v]
		var uv := [Vector2(0, 0), Vector2(u.length(), 0), Vector2(u.length(), v.length()), Vector2(0, v.length())]
		var order: Array = [0, 1, 2, 0, 2, 3]
		# Clockwise seen from outside: flip the order if (q1-q0)x(q2-q0) points along n.
		if (q[1] - q[0]).cross(q[2] - q[0]).dot(n) > 0.0:
			order = [0, 2, 1, 0, 3, 2]
		for idx in order:
			st.set_color(col)
			st.set_normal(n)
			st.set_uv(Vector2(uv[idx].x, -uv[idx].y))
			st.add_vertex(q[idx])
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mats["hedge_leaf"]
	out.add_child(mi)
	_solid(lo, hi)


## Floor tiles under `parent` (not the world), at most 8m each.
func _tiles_in(parent: Node3D, x0: float, x1: float, z0: float, z1: float, mat: Material, y := 0.0) -> void:
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
			mi.position = Vector3((a.x + b.x) * 0.5, y, (a.y + b.y) * 0.5)
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(mi)


## A surface of revolution about the y axis through `profile` ([radius, height] pairs), `segs` round, at `pos`. Its
## faces are on the right of the profile's travel: out from the axis where it runs up, up where it runs in toward the
## axis (and down where it runs out).
func _lathe(parent: Node3D, pos: Vector3, profile: PackedVector2Array, segs: int, mat: Material, shadow := true) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in segs:
		var a0: float = TAU * k / segs
		var a1: float = TAU * (k + 1) / segs
		for j in profile.size() - 1:
			var p0: Vector2 = profile[j]
			var p1: Vector2 = profile[j + 1]
			var q := [Vector3(cos(a0) * p0.x, p0.y, sin(a0) * p0.x), Vector3(cos(a1) * p0.x, p0.y, sin(a1) * p0.x),
				Vector3(cos(a1) * p1.x, p1.y, sin(a1) * p1.x), Vector3(cos(a0) * p1.x, p1.y, sin(a0) * p1.x)]
			# Godot's front faces wind clockwise seen from the front.
			for idx in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(q[idx])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.position = pos
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## The fountain: a round granite basin, a column carrying a bowl, a sheet of water falling from the bowl's lip into
## the basin and a trickle over the top (fountain_water.gdshader: mode 0 a pool, 1 a falling sheet), and its sound.
func _fountain(out: Node3D, c: Vector3) -> void:
	var granite := _mat("granite")
	_lathe(out, c, PackedVector2Array([Vector2(5.1, 0.0), Vector2(5.1, 0.55), Vector2(5.0, 0.68), Vector2(4.55, 0.68),
			Vector2(4.45, 0.58), Vector2(4.45, 0.05)]), 64, granite)
	_lathe(out, c, PackedVector2Array([Vector2(4.46, 0.04), Vector2(0.0, 0.04)]), 48, _mat("granite_dark"), false)
	_lathe(out, c, PackedVector2Array([Vector2(0.62, 0.0), Vector2(0.62, 0.3), Vector2(0.42, 0.45), Vector2(0.36, 1.9),
			Vector2(0.55, 2.05), Vector2(1.9, 2.45), Vector2(2.02, 2.62), Vector2(1.94, 2.68), Vector2(1.8, 2.55),
			Vector2(0.0, 2.5)]), 48, granite)
	_lathe(out, c, PackedVector2Array([Vector2(0.12, 2.5), Vector2(0.2, 2.75), Vector2(0.16, 2.9), Vector2(0.0, 2.92)]), 16, granite)
	var sh: Shader = load("res://fountain_water.gdshader")
	var water := func(nm: String, mesh: Mesh, mode: int, y: float, fall_r: float) -> void:
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("mode", mode)
		if fall_r > 0.0:
			m.set_shader_parameter("fall_r", fall_r)
		var mi := MeshInstance3D.new()
		mi.name = nm
		mi.mesh = mesh
		mi.material_override = m
		mi.position = c + Vector3(0.0, y, 0.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		out.add_child(mi)
	var basin := CylinderMesh.new()
	basin.top_radius = 4.47
	basin.bottom_radius = 4.47
	basin.height = 0.02
	basin.radial_segments = 64
	basin.rings = 1
	water.call("BasinPool", basin, 0, 0.5, 2.0)
	var bowl := CylinderMesh.new()
	bowl.top_radius = 1.82
	bowl.bottom_radius = 1.82
	bowl.height = 0.02
	bowl.radial_segments = 40
	bowl.rings = 1
	water.call("BowlPool", bowl, 0, 2.6, 0.2)
	var sheet := CylinderMesh.new()
	sheet.top_radius = 2.0
	sheet.bottom_radius = 2.16
	sheet.height = 2.1
	sheet.radial_segments = 48
	sheet.rings = 4
	sheet.cap_top = false
	sheet.cap_bottom = false
	water.call("FallingSheet", sheet, 1, 0.5 + 1.05, 0.0)
	var jet := CylinderMesh.new()
	jet.top_radius = 0.06
	jet.bottom_radius = 0.34
	jet.height = 0.6
	jet.radial_segments = 16
	jet.rings = 3
	jet.cap_top = false
	jet.cap_bottom = false
	water.call("Trickle", jet, 1, 2.62 + 0.3, 0.0)
	var snd := AudioStreamPlayer3D.new()
	snd.name = "FountainSound"
	snd.stream = load("res://sounds/Gentle_flowing_water.wav")
	snd.position = c + Vector3(0.0, 1.0, 0.0)
	snd.unit_size = 6.0
	snd.volume_db = -6.0
	snd.autoplay = true
	out.add_child(snd)


## An iron tree grate round a plane's foot: a dark square frame with radial bars, soil in the middle.
func _tree_grate(out: Node3D, p: Vector3) -> void:
	var r: float = 1.2
	var iron := _mat("iron")
	_box(out, p + Vector3(-r, 0.0, -r), p + Vector3(r, 0.015, r), _mat("soil"), false)
	for s in [-1.0, 1.0]:
		_box(out, p + Vector3(-r, 0.0, s * r - 0.08), p + Vector3(r, 0.03, s * r + 0.08), iron, false)
		_box(out, p + Vector3(s * r - 0.08, 0.0, -r), p + Vector3(s * r + 0.08, 0.03, r), iron, false)
	for k in 16:
		var a: float = TAU * k / 16.0
		var d := Vector3(cos(a), 0.0, sin(a))
		var e: float = r / maxf(absf(d.x), absf(d.z))
		_beam(out, p + d * 0.55 + Vector3(0.0, 0.022, 0.0), p + d * (e - 0.06) + Vector3(0.0, 0.022, 0.0), 0.05, 0.02, iron)
	_lathe(out, p, PackedVector2Array([Vector2(0.62, 0.0), Vector2(0.62, 0.03), Vector2(0.5, 0.03)]), 24, iron, false)


## A bench facing +z of its yaw: timber slats on two granite blocks, a backrest on steel posts.
func _bench(out: Node3D, p: Vector3, yaw: float) -> void:
	var root := Node3D.new()
	root.position = p
	root.rotation.y = yaw
	out.add_child(root)
	for x in [-0.85, 0.85]:
		_box(root, Vector3(x - 0.12, 0.0, -0.25), Vector3(x + 0.12, 0.42, 0.25), _mat("granite"))
		_box(root, Vector3(x - 0.03, 0.42, -0.3), Vector3(x + 0.03, 0.85, -0.24), _mat("iron"))
	for k in 5:
		var z0: float = -0.27 + k * 0.11
		_box(root, Vector3(-1.05, 0.42, z0), Vector3(1.05, 0.46, z0 + 0.09), _mat("timber"))
	for k in 3:
		var y0: float = 0.52 + k * 0.11
		_box(root, Vector3(-1.05, y0, -0.32), Vector3(1.05, y0 + 0.08, -0.28), _mat("timber"))


## A slim lamp post: a dark pole, a flat round head with a glowing underside.
func _lamp_post(out: Node3D, p: Vector3) -> void:
	_lathe(out, p, PackedVector2Array([Vector2(0.11, 0.0), Vector2(0.11, 0.3), Vector2(0.065, 0.36), Vector2(0.05, 4.6),
			Vector2(0.05, 4.7)]), 16, _mat("iron"))
	_lathe(out, p, PackedVector2Array([Vector2(0.38, 4.8), Vector2(0.36, 4.86), Vector2(0.18, 4.96), Vector2(0.0, 4.98)]), 24,
			_mat("iron"))
	_lathe(out, p, PackedVector2Array([Vector2(0.0, 4.79), Vector2(0.37, 4.8)]), 24, _glow_mat(Color(1.0, 0.93, 0.8), 1.5), false)


func _bollard(out: Node3D, p: Vector3) -> void:
	_lathe(out, p, PackedVector2Array([Vector2(0.11, 0.0), Vector2(0.11, 0.82), Vector2(0.09, 0.9), Vector2(0.0, 0.92)]), 14,
			_mat("iron"))
	_lathe(out, p, PackedVector2Array([Vector2(0.112, 0.7), Vector2(0.112, 0.75)]), 14, _glow_mat(Color(1.0, 0.9, 0.7), 0.6), false)


## A round raised planter: a granite wall `h` high round dark soil.
func _round_planter(out: Node3D, c: Vector3, r: float, h: float) -> void:
	_lathe(out, c, PackedVector2Array([Vector2(r, 0.0), Vector2(r, h), Vector2(r - 0.05, h + 0.05), Vector2(r - 0.35, h + 0.05),
			Vector2(r - 0.4, h)]), 48, _mat("granite"))
	_lathe(out, c, PackedVector2Array([Vector2(r - 0.39, h - 0.08), Vector2(0.0, h - 0.08)]), 32, _mat("soil"), false)


## A square raised planter, `size` across in plan.
func _square_planter(out: Node3D, c: Vector3, size: Vector2, h: float) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.y * 0.5
	var t := 0.3
	var g := _mat("granite")
	_box(out, c + Vector3(-hx, 0.0, -hz), c + Vector3(hx, h, -hz + t), g)
	_box(out, c + Vector3(-hx, 0.0, hz - t), c + Vector3(hx, h, hz), g)
	_box(out, c + Vector3(-hx, 0.0, -hz + t), c + Vector3(-hx + t, h, hz - t), g)
	_box(out, c + Vector3(hx - t, 0.0, -hz + t), c + Vector3(hx, h, hz - t), g)
	_box(out, c + Vector3(-hx - 0.03, h, -hz - 0.03), c + Vector3(hx + 0.03, h + 0.06, -hz + t), _mat("granite_dark"))
	_box(out, c + Vector3(-hx - 0.03, h, hz - t), c + Vector3(hx + 0.03, h + 0.06, hz + 0.03), _mat("granite_dark"))
	_box(out, c + Vector3(-hx - 0.03, h, -hz + t), c + Vector3(-hx + t, h + 0.06, hz - t), _mat("granite_dark"))
	_box(out, c + Vector3(hx - t, h, -hz + t), c + Vector3(hx + 0.03, h + 0.06, hz - t), _mat("granite_dark"))
	_box(out, c + Vector3(-hx + t, 0.0, -hz + t), c + Vector3(hx - t, h - 0.08, hz - t), _mat("soil"), false)


## Everything at one car: the plinth and its band, the car (in `car`, whose y the lift sets), the two-post
## lift, the placard, the spotlight and the inspection lamp. Bay frame: the car's middle at the origin on the
## floor, its nose toward +z; the plinth, lift and car are at the car's own size.
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
	car.position.y = DAIS_H

	# The plinth, with a band of light under its top edge that says whether the car is in the line-up.
	var px: float = size.x * 0.5 + POST_GAP
	var hw: float = px + 0.3
	var hl: float = size.z * 0.5 + 0.36
	var rim_mat := _glow_mat(color, 2.6)
	_box(root, Vector3(-hw, 0.0, -hl), Vector3(hw, DAIS_H, hl), _mat("dais"))
	_box(root, Vector3(-hw - 0.012, DAIS_H - 0.075, -hl - 0.012), Vector3(hw + 0.012, DAIS_H - 0.04, hl + 0.012), rim_mat, false)
	var blob := MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2(size.x * 1.25, size.z * 1.12)
	blob.mesh = quad
	blob.position.y = DAIS_H + 0.004
	blob.material_override = _blob_mat()
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(blob)

	# The lift: a post either side at the middle of the car, tall enough for the carriage at the top of its
	# travel, a carriage on each with two arms swung in under the car to its pads.
	var post_h: float = maxf(contact, LIFT_REST + PAD_TOP) - PAD_TOP + LIFT_HEIGHT + CARRIAGE_H + 0.08
	var cap := _glow_mat(color, 1.4)
	var body := StaticBody3D.new()
	body.name = "BayBody"
	root.add_child(body)
	for s in [-1.0, 1.0]:
		_box(root, Vector3(s * px - 0.09, DAIS_H, -0.09), Vector3(s * px + 0.09, DAIS_H + 0.012, 0.09), _mat("post"))
		_box(root, Vector3(s * px - 0.04, DAIS_H, -0.05), Vector3(s * px + 0.04, DAIS_H + post_h, 0.05), _mat("post"))
		_box(root, Vector3(s * px - 0.048, DAIS_H + post_h, -0.058), Vector3(s * px + 0.048, DAIS_H + post_h + 0.02, 0.058), cap, false)
	var carriage := Node3D.new()
	carriage.name = "Carriage"
	root.add_child(carriage)
	for s in [-1.0, 1.0]:
		var sx: float = s
		_box(carriage, Vector3(sx * px - 0.06, 0.0, -0.07), Vector3(sx * px + 0.06, CARRIAGE_H, 0.07), _mat("post"))
		for e in [-1.0, 1.0]:
			var a := Vector3(sx * (px - 0.05), 0.022, 0.0)
			var pad := Vector3(sx * size.x * 0.22, 0.022, e * size.z * 0.27)
			var arm := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.04, 0.03, a.distance_to(pad))
			arm.mesh = bm
			arm.material_override = _mat("post")
			arm.transform = Transform3D(Basis.looking_at(pad - a, Vector3.UP), (a + pad) * 0.5)
			carriage.add_child(arm)
			var p := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.04
			cyl.bottom_radius = 0.04
			cyl.height = 0.03
			p.mesh = cyl
			p.material_override = _mat("rubber")
			p.position = pad + Vector3(0.0, PAD_TOP - 0.015 - 0.022, 0.0)
			carriage.add_child(p)
	# The plinth is solid to walk into, up past the car.
	_solid(Vector3(-hw, 0.0, -hl), Vector3(hw, 1.2, hl), body)

	# The plaque on the plinth's front, under the car's nose.
	var plaque := Node3D.new()
	plaque.position = Vector3(0.0, DAIS_H * 0.5, hl)
	root.add_child(plaque)
	var pw: float = minf(hw * 2.0 - 0.3, 0.9)
	_box(plaque, Vector3(-pw * 0.5, -0.15, 0.0), Vector3(pw * 0.5, 0.15, 0.015), _mat("board"), false)
	var accent: Color = CAR_ACCENTS.get(CAR_PRESETS[index].name, color)
	_text(plaque, str(CAR_PRESETS[index].name).to_upper(), 0.1, accent.lightened(0.2), Vector3(0.0, 0.06, 0.025), pw - 0.1)
	var status := _text(plaque, "", 0.05, COL_DIM, Vector3(0.0, -0.035, 0.025), pw - 0.1, _font_bold)
	_text(plaque, str(g["name"]).to_upper(), 0.035, Color(COL_DIM, 0.7), Vector3(0.0, -0.1, 0.025), pw - 0.1, _font_bold)

	# The spotlight: high on the aisle side, aimed at the car.
	var spot := SpotLight3D.new()
	root.add_child(spot)
	spot.position = Vector3(0.0, WALL_H - 0.35, size.z * 0.5 + 1.5)
	spot.look_at(root.to_global(Vector3(0.0, DAIS_H + size.y * 0.4, 0.0)), Vector3.UP)
	spot.spot_angle = 18.0
	spot.spot_angle_attenuation = 0.8
	spot.spot_range = 8.0
	spot.light_color = Color(1.0, 0.96, 0.9)
	spot.shadow_enabled = MusicManager.shadow_quality_index > 0 and not OS.has_feature("mobile")
	spot.shadow_bias = 0.03
	spot.shadow_normal_bias = 1.0
	# The inspection lamp: lights the underside once the car is up (only while it is: _pose_lift).
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.0, DAIS_H + 0.08, 0.0)
	lamp.omni_range = size.z * 0.5 + 1.0
	lamp.omni_attenuation = 0.8
	lamp.light_color = Color(0.92, 0.96, 1.0)
	lamp.shadow_enabled = false
	lamp.visible = false
	root.add_child(lamp)

	var bay := {
		"index": index, "lamp": lamp, "gallery": g["name"], "color": color, "root": root, "car": car,
		"car_y": DAIS_H, "centre": Vector3(0.0, size.y * 0.45, 0.0), "radius": size.z * 0.5 + 0.4,
		"contact": maxf(contact, LIFT_REST + PAD_TOP + 0.005), "carriage": carriage, "blob": blob,
		"rim_mat": rim_mat, "spot": spot, "status": status, "lift": 0.0, "up": false, "post_x": px,
	}
	_bays.append(bay)
	_pose_lift(bay)
	_show_lineup_state(_bays.size() - 1, false)


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


## How high over the car's foot the lift's pads meet it: the lowest point of its body over the middle of
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


## The foyer: the player's own car (the one the car select screen last confirmed) on a turntable plinth,
## in the sun under the glass.
func _build_featured() -> void:
	var index: int = clampi(NetworkManager.local_car_index, 0, CAR_PRESETS.size() - 1)
	var base := Node3D.new()
	base.name = "Featured"
	base.position = Vector3(0.0, 0.0, -3.0)
	_world.add_child(base)
	var plinth := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.25
	cyl.bottom_radius = 1.3
	cyl.height = DAIS_H
	cyl.radial_segments = 64
	plinth.mesh = cyl
	plinth.position.y = DAIS_H * 0.5
	plinth.material_override = _mat("dais")
	base.add_child(plinth)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.26
	torus.outer_radius = 1.3
	torus.rings = 64
	torus.ring_segments = 6
	ring.mesh = torus
	ring.position.y = DAIS_H - 0.05
	ring.material_override = _glow_mat(CAR_ACCENTS.get(CAR_PRESETS[index].name, COL_TEAL), 2.6)
	base.add_child(ring)
	_solid(Vector3(-1.3, 0.0, -4.3), Vector3(1.3, 1.2, -1.7))
	_featured = Node3D.new()
	_featured.position.y = DAIS_H
	_featured.rotation.y = 0.6
	base.add_child(_featured)
	var model := _car_model(index)
	if model:
		_featured.add_child(model)
		model.transform = Transform3D(Basis.from_scale(Vector3.ONE * CAR_SCALE * SHOW_SCALE), Vector3.ZERO)
		var box: AABB = _bounds(model, _featured)
		var c: Vector3 = box.get_center()
		model.position -= Vector3(c.x, box.position.y, c.z)
	_sunlit(base)
	var spot := SpotLight3D.new()
	base.add_child(spot)
	spot.position = Vector3(2.6, WALL_H - 0.3, 2.2)
	spot.look_at(base.to_global(Vector3(0.0, DAIS_H + 0.3, 0.0)), Vector3.UP)
	spot.spot_angle = 16.0
	spot.spot_range = 9.0
	spot.light_energy = 4.0
	spot.light_color = Color(1.0, 0.96, 0.9)
	var label := _text(_world, "YOUR CAR  ·  %s" % str(CAR_PRESETS[index].name).to_upper(), 0.16, COL_DIM,
			Vector3(0.0, 0.006, -1.35), 2.4, _font_bold)
	label.rotation.x = -PI * 0.5


## The trophy hall: a pedestal per Grand Prix in an arc, each holding the best trophy won there (gold,
## silver or bronze) in a glass case, or a grey ghost of one; on the back wall the logo and the tally, high
## enough to clear the cases seen from the door (the sign over the door names the hall).
func _build_trophies() -> void:
	var hall_back: float = _spine_end - _hall_d
	var centre := Vector3(0.0, 0.0, _spine_end - _hall_d * 0.5)
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
	var wall_z: float = hall_back + WALL_T * 0.5 + 0.02
	var logo_scene := load(LOGO_PATH) as PackedScene
	if logo_scene:
		var logo := logo_scene.instantiate() as Node3D
		logo.position = Vector3(0.0, 5.15, wall_z + 0.3)
		logo.scale = Vector3.ONE * 0.45
		_world.add_child(logo)
	_text(_world, "%d GRAND PRIX WON  ·  %d PODIUMS" % [wins, podiums], 0.34, COL_GOLD, Vector3(0.0, 3.85, wall_z), 10.0, _font_bold)
	_box(_world, Vector3(-6.0, 3.55, wall_z - 0.02), Vector3(6.0, 3.59, wall_z), _glow_mat(COL_GOLD, 1.6), false)
	_box(_world, Vector3(-6.0, TALL_H - 0.06, centre.z - 0.2), Vector3(6.0, TALL_H, centre.z + 0.2), _mat("strip"), false)
	_omni(Vector3(-5.0, TALL_H - 1.2, centre.z), 0.8, 12.0)
	_omni(Vector3(5.0, TALL_H - 1.2, centre.z), 0.8, 12.0)
	# Over the hall's opening, on the concourse side, under the roof's slopes.
	_sign(Vector3(0.0, 5.55, _spine_end + WALL_T * 0.5), 0.0, Vector2(3.6, 0.85), "HALL OF FAME", COL_GOLD, "", COL_GOLD)
	_build_record_boards()


## The time trial records: a board per Grand Prix on the hall's side walls, its stages' best runs and laps
## (TimeTrialRecords). They read round the hall from the door: down the left wall, then the cups on the back
## wall, then back up the right wall.
func _build_record_boards() -> void:
	var cups: Array = NetworkManager.GP_CUPS.keys()
	var left_n: int = ceili(cups.size() * 0.5)
	var mid_z: float = _spine_end - _hall_d * 0.5
	var face: float = HALL_HALF - WALL_T * 0.5 - 0.01
	for i in cups.size():
		var on_left: bool = i < left_n
		var n: int = left_n if on_left else cups.size() - left_n
		var k: int = i if on_left else i - left_n
		var along: float = (float(k) - (n - 1) * 0.5) * RECORD_BOARD_STEP
		# Left: from the door toward the back (-z); right: from the back toward the door.
		var z: float = mid_z - along if on_left else mid_z + along
		var pos := Vector3(-face if on_left else face, RECORD_BOARD_Y, z)
		_record_board(pos, PI * 0.5 if on_left else -PI * 0.5, cups[i])
	# A lamp over every other board along each wall.
	for k in maxi(1, ceili(left_n * 0.5)):
		var lz: float = mid_z + (float(k) - (ceili(left_n * 0.5) - 1) * 0.5) * RECORD_BOARD_STEP * 2.0
		_omni(Vector3(-HALL_HALF + 2.2, 3.4, lz), 0.5, 9.0)
		_omni(Vector3(HALL_HALF - 2.2, 3.4, lz), 0.5, 9.0)


func _record_board(pos: Vector3, yaw: float, cup_name: String) -> void:
	var size := RECORD_BOARD_SIZE
	var root := Node3D.new()
	root.name = "Records_" + cup_name.validate_node_name()
	root.position = pos
	root.rotation.y = yaw
	_world.add_child(root)
	var hw: float = size.x * 0.5
	var hh: float = size.y * 0.5
	_box(root, Vector3(-hw, -hh, 0.0), Vector3(hw, hh, 0.06), _mat("board"), false)
	_box(root, Vector3(-hw, hh - 0.035, 0.06), Vector3(hw, hh, 0.075), _glow_mat(COL_GOLD, 1.8), false)
	var zt := 0.075
	_text(root, cup_name.to_upper(), 0.22, COL_GOLD, Vector3(0.0, hh - 0.24, zt), size.x - 0.4)
	_text(root, "TIME TRIAL RECORDS", 0.075, COL_DIM, Vector3(0.0, hh - 0.44, zt), size.x - 0.4, _font_bold)
	var x_stage: float = -hw + 0.2
	var x_run: float = 0.55
	var x_lap: float = 1.45
	var x_car: float = 1.62
	var y: float = hh - 0.66
	_col_text(root, "STAGE", 0.065, COL_DIM, Vector3(x_stage, y, zt), 0, 1.9)
	_col_text(root, "BEST RUN", 0.065, COL_DIM, Vector3(x_run, y, zt), 2, 0.8)
	_col_text(root, "BEST LAP", 0.065, COL_DIM, Vector3(x_lap, y, zt), 2, 0.8)
	_col_text(root, "CAR", 0.065, COL_DIM, Vector3(x_car, y, zt), 0, hw - 0.12 - x_car)
	_box(root, Vector3(-hw + 0.15, y - 0.08, 0.06), Vector3(hw - 0.15, y - 0.07, 0.07), _glow_mat(COL_DIM, 0.6), false)
	y -= 0.3
	for path in NetworkManager.GP_CUPS[cup_name]["stages"]:
		var rec: Dictionary = TimeTrialRecords.stage(TimeTrialRecords.key_of(path))
		var any: bool = int(rec["run_ms"]) > 0 or int(rec["lap_ms"]) > 0
		var name_col: Color = COL_TEXT if any else Color(COL_DIM, 0.75)
		_col_text(root, _stage_name(path).to_upper(), 0.12, name_col, Vector3(x_stage, y, zt), 0, 1.9)
		var run: int = int(rec["run_ms"])
		var lap: int = int(rec["lap_ms"])
		_col_text(root, TimeTrialRecords.format_ms(run) if run > 0 else "-", 0.12, COL_GOLD if run > 0 else COL_OFF,
				Vector3(x_run, y, zt), 2, 0.8)
		_col_text(root, TimeTrialRecords.format_ms(lap) if lap > 0 else "-", 0.12, COL_TEXT if lap > 0 else COL_OFF,
				Vector3(x_lap, y, zt), 2, 0.8)
		var car: String = str(rec["run_car"]) if run > 0 else str(rec["lap_car"])
		_col_text(root, car.to_upper() if car != "" else "", 0.085, COL_DIM, Vector3(x_car, y, zt), 0, hw - 0.12 - x_car)
		var sub := "NOT RUN YET"
		if any:
			var runs: int = int(rec["runs"])
			var date: String = str(rec["run_date"]) if run > 0 else str(rec["lap_date"])
			sub = "SET %s  ·  %d RUN%s" % [date, runs, "" if runs == 1 else "S"]
		_col_text(root, sub, 0.055, Color(COL_DIM, 0.8), Vector3(x_stage, y - 0.13, zt), 0, 1.9)
		y -= RECORD_ROW


## Text in a column: `align` 0 starts at `pos`, 2 ends there (1 centres, as `_text`).
func _col_text(parent: Node3D, text: String, height: float, color: Color, pos: Vector3, align: int, max_w: float) -> Label3D:
	var l := _text(parent, text, height, color, pos, max_w, _font_bold)
	l.horizontal_alignment = [HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_RIGHT][align]
	return l


func _stage_name(path: String) -> String:
	for st in NetworkManager.ALL_STAGES:
		if st["path"] == path:
			return str(st["name"])
	return path.get_file().get_basename()


func _build_pedestal(ped: Node3D, cup_name: String, rec: Dictionary) -> void:
	var best: int = rec["best"]
	var won: bool = best >= 0
	var col: Color = MEDAL[best] if won else COL_OFF
	var column := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.62
	cyl.bottom_radius = 0.7
	cyl.height = PEDESTAL_H
	cyl.radial_segments = 48
	column.mesh = cyl
	column.position.y = PEDESTAL_H * 0.5
	column.material_override = _mat("marble")
	ped.add_child(column)
	var band := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.6
	tor.outer_radius = 0.66
	tor.rings = 48
	tor.ring_segments = 6
	band.mesh = tor
	band.position.y = PEDESTAL_H
	band.material_override = _glow_mat(col, 2.0 if won else 0.4)
	ped.add_child(band)
	var body := StaticBody3D.new()
	ped.add_child(body)
	_solid(Vector3(-0.7, 0.0, -0.7), Vector3(0.7, PEDESTAL_H + CASE_TOP + 0.05, 0.7), body)
	_solid(Vector3(-0.47, 0.0, 0.55), Vector3(0.47, PLAQUE_LEDGE + PLAQUE_SIZE.y, 0.82), body)
	# The case: a dark steel foot on the column's top (its floor), the cup on a velvet dais, a glass cylinder, a lid
	# with a ring of light under it. No two faces share a plane (the old glass box's floor lay on the column's top and
	# flickered against it): the foot, the dais and the glass have no bottom faces and start inside what they stand on.
	var y0: float = PEDESTAL_H
	_cyl(ped, CASE_R + 0.025, y0 - 0.01, y0 + CASE_FOOT, _mat("alu"), true, false)
	_cyl(ped, 0.4, y0 + CASE_FOOT - 0.004, y0 + CASE_DAIS, _mat("velvet"), true, false)
	for key in ["case_back", "case_front"]:
		_cyl(ped, CASE_R, y0 + CASE_FOOT - 0.02, y0 + CASE_TOP, _mat(key), false, false, false)
	_cyl(ped, CASE_R + 0.025, y0 + CASE_TOP, y0 + CASE_TOP + 0.05, _mat("alu"))
	var ring := MeshInstance3D.new()
	var rt := TorusMesh.new()
	rt.inner_radius = 0.44
	rt.outer_radius = 0.46
	rt.rings = 48
	rt.ring_segments = 6
	ring.mesh = rt
	ring.position.y = y0 + CASE_TOP - 0.006
	ring.material_override = _glow_mat(Color(1.0, 0.95, 0.86), 2.2)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ped.add_child(ring)
	# The cup (Podium's), or a ghost of it, its foot sunk 3mm into the dais.
	var holder := Node3D.new()
	holder.position.y = y0 + CASE_DAIS - 0.003
	holder.scale = Vector3.ONE * 0.9
	ped.add_child(holder)
	var mat: Material
	if won:
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.metallic = 1.0
		m.roughness = 0.22
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 0.2
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat = m
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
	# The plaque: a glass plate on the column's front, leaning back in a chrome clamp along a steel ledge that comes out
	# of the column, the text on the glass (it had stood in the air before the round column, 5 to 35cm off it).
	var r_ledge: float = _column_r(PLAQUE_LEDGE)
	var lw: float = PLAQUE_LEDGE_W * 0.5
	var foot_z: float = r_ledge + 0.09
	var ledge_back: float = sqrt(r_ledge * r_ledge - lw * lw) - 0.03
	_box(ped, Vector3(-lw, PLAQUE_LEDGE - 0.035, ledge_back), Vector3(lw, PLAQUE_LEDGE, foot_z + 0.04), _mat("post"))
	_box(ped, Vector3(-lw + 0.02, PLAQUE_LEDGE - 0.004, foot_z - 0.022), Vector3(lw - 0.02, PLAQUE_LEDGE + 0.035, foot_z + 0.022),
			_mat("chrome"), false)
	var plaque := Node3D.new()
	plaque.position = Vector3(0.0, PLAQUE_LEDGE, foot_z)
	plaque.rotation.x = -PLAQUE_RECLINE
	ped.add_child(plaque)
	var pw: float = PLAQUE_SIZE.x * 0.5
	# Its foot 4mm into the clamp and the ledge (it is wider than they are, and deeper it hung under them).
	_box(plaque, Vector3(-pw, -0.004, -PLAQUE_T * 0.5), Vector3(pw, PLAQUE_SIZE.y - 0.004, PLAQUE_T * 0.5),
			_mat("plaque_glass"), false)
	var zt: float = PLAQUE_T * 0.5 + 0.002
	var tw: float = PLAQUE_SIZE.x - 0.1
	_on_glass(_text(plaque, cup_name.to_upper(), 0.13, col.lightened(0.2) if won else COL_DIM, Vector3(0.0, 0.29, zt), tw))
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
	_on_glass(_text(plaque, line, 0.1, COL_TEXT if won else Color(COL_DIM, 0.8), Vector3(0.0, 0.172, zt), tw, _font_bold))
	if sub != "":
		_on_glass(_text(plaque, sub, 0.068, COL_DIM, Vector3(0.0, 0.085, zt), tw, _font_bold))
	var spot := SpotLight3D.new()
	ped.add_child(spot)
	spot.position = Vector3(0.0, TALL_H - 0.4, 3.0)
	spot.look_at(ped.to_global(Vector3(0.0, PEDESTAL_H + 0.5, 0.0)), Vector3.UP)
	spot.spot_angle = 14.0
	spot.spot_range = 10.0
	spot.light_energy = 9.0 if won else 2.5
	spot.light_color = Color(1.0, 0.95, 0.85)


## The trophy column's radius `y` over the floor (it tapers from 0.7 to 0.62).
func _column_r(y: float) -> float:
	return lerpf(0.7, 0.62, y / PEDESTAL_H)


## Text on a glass plate: drawn after the glass (transparent things of one priority sort by distance, and text 2mm in
## front of its plate would swap places with it as the camera moved).
func _on_glass(l: Label3D) -> void:
	l.render_priority = 2


## An upright cylinder in `parent`'s frame, radius `r`, from `y0` up to `y1`, with or without its end faces.
func _cyl(parent: Node3D, r: float, y0: float, y1: float, mat: Material, top := true, bottom := true,
		shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = y1 - y0
	c.radial_segments = 64
	c.rings = 1
	c.cap_top = top
	c.cap_bottom = bottom
	mi.mesh = c
	mi.position.y = (y0 + y1) * 0.5
	mi.material_override = mat
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _build_player() -> void:
	_player = CharacterBody3D.new()
	_player.name = "Walker"
	# Just out of the doors' reach, so they don't open as the hall comes up.
	_player.position = Vector3(0.0, 0.05, ENTRANCE_Z - DOOR_REACH - 0.2)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
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
	_eye_cam.far = 400.0
	_head.add_child(_eye_cam)
	_eye_cam.current = true
	_orbit_cam = Camera3D.new()
	_orbit_cam.fov = 50.0
	_orbit_cam.near = 0.03
	_orbit_cam.far = 400.0
	_world.add_child(_orbit_cam)
	_pitch = -0.12
	_head.rotation.x = _pitch
