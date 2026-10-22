extends Control
## The car select screen: a showroom (the car on a lit turntable, in its own 3D world behind the
## UI), the car's name and stats on the left, the paint shop on the right (procedural cars:
## CarPaint.gd), and a bar along the bottom to go back, jump to any car or confirm. Built in code;
## CarSelection.tscn is only the root.
##
## Main.gd shows it from the main menu and the lobby, and show_for_player(2) lets split-screen's
## second player choose. car_selected fires on confirm, back_requested on Back, Esc or the pad's B.
## Controls: left/right (or Q/E, the shoulder buttons, the arrows by the car, the names along the
## bottom) change car; drag the car, or the right stick, to turn it; up/down reach the paint shop,
## whose rows change with left/right.

signal car_selected(car_index: int)
signal back_requested

const CarPaint = preload("res://CarPaint.gd")
const SKY_SHADER = preload("res://showroom_sky.gdshader")
const FLOOR_SHADER = preload("res://showroom_floor.gdshader")

const CAR_PRESETS = [
	{
		"name": "Viper",
		# Procedural (regenerate_cars.gd): paintable, wheels are separate meshes.
		"model_path": "res://generated/cars/Viper.tscn",
		"model_y_rotation": PI,
		"max_speed": 40.0,
		"acceleration": 65.0,
		"steer_speed": 2.5,
		"grip": 5.0,
		"braking": 40.0,
		"offroad": 6.0,
		"desc": "All-around performer. Great for beginners.",
		"wheel_parts": {"FL": "Wheel_FL", "FR": "Wheel_FR", "RL": "Wheel_RL", "RR": "Wheel_RR"}
	},
	{
		"name": "Shadow",
		# Procedural (regenerate_cars.gd): paintable, wheels are separate meshes.
		"model_path": "res://generated/cars/Shadow.tscn",
		"model_y_rotation": PI,
		"max_speed": 41.0,
		"acceleration": 52.0,
		"steer_speed": 2.2,
		"grip": 4.5,
		"braking": 32.0,
		"offroad": 4.0,
		"desc": "High top speed, but slower to accelerate.",
		"wheel_parts": {"FL": "Wheel_FL", "FR": "Wheel_FR", "RL": "Wheel_RL", "RR": "Wheel_RR"}
	},
	{
		"name": "Strikeforce",
		"model_path": "res://generated/cars/Strikeforce.tscn",
		"model_y_rotation": PI,
		"max_speed": 37.5,
		"acceleration": 82.0,
		"steer_speed": 2.7,
		"grip": 5.5,
		"braking": 52.0,
		"offroad": 8.0,
		"desc": "Explosive acceleration and good handling.",
		"wheel_parts": {"FL": "Wheel_FL", "FR": "Wheel_FR", "RL": "Wheel_RL", "RR": "Wheel_RR"}
	},
	{
		"name": "Apex",
		# Procedural (regenerate_cars.gd): paintable, wheels are separate meshes.
		"model_path": "res://generated/cars/Apex.tscn",
		"model_y_rotation": PI,
		"max_speed": 39.0,
		"acceleration": 70.0,
		"steer_speed": 3.2,
		"grip": 6.0,
		"braking": 46.0,
		"offroad": 5.0,
		"desc": "Unmatched steering response. Master of drifts.",
		"wheel_parts": {"FL": "Wheel_FL", "FR": "Wheel_FR", "RL": "Wheel_RL", "RR": "Wheel_RR"}
	},
	{
		"name": "Interceptor",
		# Procedural (regenerate_cars.gd): paintable, wheels are separate meshes.
		"model_path": "res://generated/cars/Interceptor.tscn",
		"model_y_rotation": PI,
		"max_speed": 43.0,
		"acceleration": 58.0,
		"steer_speed": 2.0,
		"grip": 4.0,
		"braking": 35.0,
		"offroad": 3.0,
		"desc": "High speed interceptor. Built for straightaways.",
		"wheel_parts": {"FL": "Wheel_FL", "FR": "Wheel_FR", "RL": "Wheel_RL", "RR": "Wheel_RR"}
	},
	{
		"name": "Mudrunner",
		"model_path": "res://generated/cars/Mudrunner.tscn",
		"model_y_rotation": PI,
		"max_speed": 36.0,
		"acceleration": 68.0,
		"steer_speed": 2.4,
		"grip": 5.0,
		"braking": 44.0,
		"offroad": 9.5,
		"desc": "Offroad specialist. Heavy tires maintain full speed off-track.",
		"wheel_parts": {"FL": "Wheel_FL", "FR": "Wheel_FR", "RL": "Wheel_RL", "RR": "Wheel_RR"}
	},
	{
		"name": "Phantom",
		"model_path": "res://generated/cars/Phantom.tscn",
		"model_y_rotation": PI,
		"max_speed": 39.5,
		"acceleration": 64.0,
		"steer_speed": 3.5,
		"grip": 3.5,
		"braking": 40.0,
		"offroad": 8.0,
		"desc": "Agile drifter on crawler tyres. Slides through corners, keeps its pace off-road.",
		"wheel_parts": {"FL": "Wheel_FL", "FR": "Wheel_FR", "RL": "Wheel_RL", "RR": "Wheel_RR"}
	},
	{
		"name": "Centurion",
		"model_path": "res://generated/cars/Centurion.tscn",
		"model_y_rotation": PI,
		"max_speed": 39.5,
		"acceleration": 76.0,
		"steer_speed": 2.6,
		"grip": 5.5,
		"braking": 48.0,
		"offroad": 6.5,
		"desc": "Heavy armored racer. Balanced stats with high durability.",
		"wheel_parts": {"FL": "Wheel_FL", "FR": "Wheel_FR", "RL": "Wheel_RL", "RR": "Wheel_RR"}
	},
	{
		"name": "Mirage",
		"model_path": "res://generated/cars/Mirage.tscn",
		"model_y_rotation": PI,
		"max_speed": 41.5,
		"acceleration": 72.0,
		"steer_speed": 3.0,
		"grip": 5.2,
		"braking": 45.0,
		"offroad": 8.5,
		"desc": "All-terrain rally hypercar. Supercar aerodynamics on long-travel trophy suspension.",
		"wheel_parts": {"FL": "Wheel_FL", "FR": "Wheel_FR", "RL": "Wheel_RL", "RR": "Wheel_RR"}
	},
	{
		"name": "Inferno",
		"model_path": "res://generated/cars/Inferno.tscn",
		"model_y_rotation": PI,
		"max_speed": 41.5,
		"acceleration": 68.0,
		"steer_speed": 2.9,
		"grip": 4.4,
		"braking": 42.0,
		"offroad": 9.0,
		"desc": "Dune supercar on paddle tyres. Flies over sand, slides on tarmac.",
		"wheel_parts": {"FL": "Wheel_FL", "FR": "Wheel_FR", "RL": "Wheel_RL", "RR": "Wheel_RR"}
	}
]

## Each car's colour on this screen: its name's underline, stat bars, the turntable's light ring
## and the confirm button.
const CAR_ACCENTS := {
	"Viper": Color(0.36, 0.92, 0.40), "Shadow": Color(0.72, 0.40, 1.0), "Strikeforce": Color(0.70, 0.88, 0.20),
	"Apex": Color(1.0, 0.60, 0.16), "Interceptor": Color(0.30, 0.52, 1.0), "Mudrunner": Color(0.22, 0.80, 0.66),
	"Phantom": Color(1.0, 0.78, 0.14), "Centurion": Color(0.98, 0.46, 0.12), "Mirage": Color(0.96, 0.28, 0.14),
	"Inferno": Color(1.0, 0.22, 0.20),
}
## Stat bars: caption, preset key, and the values at an empty and a full bar (spanning the fleet).
const STATS := [
	["SPEED", "max_speed", 30.0, 45.0],
	["ACCELERATION", "acceleration", 40.0, 90.0],
	["HANDLING", "steer_speed", 1.5, 4.0],
	["GRIP", "grip", 2.5, 7.0],
	["OFFROAD", "offroad", 0.0, 10.0],
]

# The main menu's palette.
const COL_TEAL := Color(0.15, 0.75, 0.92)
const COL_ORANGE := Color(1.0, 0.55, 0.16)
const COL_TEXT := Color(0.93, 0.95, 0.98)
const COL_DIM := Color(0.60, 0.66, 0.76)
const COL_CARD := Color(0.045, 0.052, 0.075, 0.82)
const COL_BUTTON := Color(0.12, 0.14, 0.2)
const COL_BUTTON_EDGE := Color(0.28, 0.34, 0.44)

# Showroom.
const SPIN_SPEED := 0.26          # rad/s: a turn every 24 s
const SPIN_RESUME := 2.5          # s after you let go before the turntable takes over again
const DRAG_RAD_PER_PX := 0.009
const STICK_SPEED := 2.4          # rad/s at full right stick
const CAMERA_FOV := 26.0          # a long lens: no wide-angle stretch on the car
const CAMERA_DIST := 7.6
const CAMERA_PITCH := 13.0        # degrees above the turntable
const LOOK_AT := Vector3(0.0, 0.40, 0.0)
const TABLE_RADIUS := 1.5
const START_YAW := PI + 0.62      # the front three-quarter view
const CAR_SCALE := 2.0            # what PlayerCart scales a car's scene by

var current_car_index := 0
var rotating_model: Node3D = null
## Who is choosing: 2 is split-screen's second player, whose paint jobs are saved apart.
var player_slot := 1
## The paint job on the previewed car (procedural cars only).
var current_paint: Dictionary = {}

var _stage: SubViewport
var _turntable: Node3D
var _model_pivot: Node3D
var _blob: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _spin := SPIN_SPEED
var _dragging := false
var _since_drag := 100.0
var _swap_tween: Tween
var _scene_cache := {}

var _font_title: FontVariation
var _font_bold: FontVariation
var _title: Label
var _subtitle: Label
var _counter: Label
var _bg_name: Label
var _name_label: Label
var _name_line: ColorRect
var _desc: Label
var _stat_bars: Array = []
var _paint_panel: PanelContainer
var _paint_rows: VBoxContainer
var _paint_note: Label
var _paint_title_line: ColorRect
var _paint_values := {}      # row key -> Label showing the choice
var _paint_swatches := {}    # row key -> ColorRect
var _number_row: Control
## The RC antenna on the showroom car (PlayerCart's own is a separate node), shown with the paint's
## "antenna" option.
var _showroom_antenna: Node3D
var _pills: Array[Button] = []
var _confirm_btn: Button
var _back_btn: Button


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		current_car_index = clampi(int(config.get_value("player", "car_index", 0)), 0, CAR_PRESETS.size() - 1)
	NetworkManager.local_car_index = current_car_index
	_make_fonts()
	_build_backdrop()
	_build_showroom()
	_build_top_bar()
	_build_info_card()
	_build_paint_panel()
	_build_bottom_bar()
	visibility_changed.connect(_on_visibility_changed)
	update_car_selection()
	_on_visibility_changed()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or _turntable == null:
		return
	var stick := 0.0
	for pad in Input.get_connected_joypads():
		var ax: float = Input.get_joy_axis(pad, JOY_AXIS_RIGHT_X)
		if absf(ax) > 0.25:
			stick = ax
	if stick != 0.0:
		_spin = stick * STICK_SPEED
		_since_drag = 0.0
	elif not _dragging:
		_since_drag += delta
		# Let a flick coast to a stop, then ease back into the slow showroom spin.
		var resting: bool = _since_drag > SPIN_RESUME
		_spin = lerpf(_spin, SPIN_SPEED if resting else 0.0, 1.0 - exp(-delta * (0.8 if resting else 2.5)))
	if not _dragging:
		_turntable.rotate_y(_spin * delta)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
		return
	var step := 0
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			step = -1
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			step = 1
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			step = -1
		elif event.keycode == KEY_E:
			step = 1
	# Left/right change car, unless the paint shop has the focus (its rows take them).
	var focus: Control = get_viewport().gui_get_focus_owner()
	if step == 0 and (focus == null or not _paint_panel.is_ancestor_of(focus)):
		if event.is_action_pressed("ui_left", true):
			step = -1
		elif event.is_action_pressed("ui_right", true):
			step = 1
	if step != 0:
		_change_car(step)
		get_viewport().set_input_as_handled()


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		return
	if player_slot == 1:
		var coop: bool = NetworkManager.current_game_mode == NetworkManager.GameMode.LOCAL_COOP
		_set_title("PLAYER 1 — SELECT YOUR CAR" if coop else "SELECT YOUR CAR")
	_since_drag = 100.0
	_confirm_btn.grab_focus.call_deferred()


func _set_title(text: String) -> void:
	_title.text = text
	_subtitle.text = "Choose your ride and paint it" if player_slot == 1 else "Player 2, choose your ride"
	_subtitle.add_theme_color_override("font_color", COL_DIM if player_slot == 1 else COL_ORANGE)


## The accent colour of the car on show.
func _accent() -> Color:
	return CAR_ACCENTS.get(CAR_PRESETS[current_car_index].name, COL_TEAL)


func update_car_selection() -> void:
	var preset: Dictionary = CAR_PRESETS[current_car_index]
	var accent: Color = _accent()
	var car_name: String = str(preset.name).to_upper()
	_name_label.text = car_name
	_bg_name.text = car_name
	_desc.text = preset.desc
	_counter.text = "%d / %d" % [current_car_index + 1, CAR_PRESETS.size()]
	for k in STATS.size():
		var st: Array = STATS[k]
		var v: float = inverse_lerp(st[2], st[3], float(preset.get(st[1], st[2])))
		_stat_bars[k].set_value(clampf(v, 0.05, 1.0), accent)
	_apply_accent(accent)
	_show_model(preset)
	_load_paint()


func _change_car(step: int) -> void:
	current_car_index = posmod(current_car_index + step, CAR_PRESETS.size())
	update_car_selection()
	_play_swap(step)


func _select_car(index: int) -> void:
	if index == current_car_index:
		return
	var step: int = 1 if index > current_car_index else -1
	current_car_index = index
	update_car_selection()
	_play_swap(step)


func _on_prev_pressed() -> void:
	_change_car(-1)


func _on_next_pressed() -> void:
	_change_car(1)


func _on_confirm_pressed() -> void:
	# Save car selection
	var config = ConfigFile.new()
	config.load("user://settings.cfg") # Load existing if it exists
	config.set_value("player", "car_index", current_car_index)
	config.save("user://settings.cfg")

	hide()

	NetworkManager.local_car_index = current_car_index
	var chosen_paint: Dictionary = current_paint.duplicate() if _is_paintable() else {}
	if player_slot == 2:
		NetworkManager.local_p2_paint = chosen_paint
		player_slot = 1
	else:
		NetworkManager.local_paint = chosen_paint
	car_selected.emit(current_car_index)


func _on_back_pressed() -> void:
	back_requested.emit()


## Called by Main.gd during LOCAL_COOP to let a player pick their car: 2 after player 1 confirmed,
## 1 when player 2 goes back.
func show_for_player(player_num: int):
	player_slot = player_num
	if player_num == 2:
		# Start player 2 on the first car, so the two don't end up on the same one by accident.
		current_car_index = 0
	else:
		var config := ConfigFile.new()
		if config.load("user://settings.cfg") == OK:
			current_car_index = clampi(int(config.get_value("player", "car_index", 0)), 0, CAR_PRESETS.size() - 1)
	update_car_selection()
	show()
	_set_title("PLAYER %d — SELECT YOUR CAR" % player_num)


# ============================================================================================
#  Showroom
# ============================================================================================

## The car's scene, kept once loaded (the imported cars take a moment).
func _car_scene(path: String) -> PackedScene:
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path)
	return _scene_cache[path]


## Puts the preset's car on the turntable: at the size it races at, centred, standing on it.
func _show_model(preset: Dictionary) -> void:
	if rotating_model:
		rotating_model.queue_free()
		rotating_model = null
		_showroom_antenna = null
	var scene: PackedScene = _car_scene(preset.model_path)
	if scene == null:
		return
	rotating_model = scene.instantiate()
	_model_pivot.add_child(rotating_model)
	var rot: float = preset.get("model_y_rotation", PI)
	rotating_model.transform = Transform3D(Basis(Vector3.UP, rot) * CAR_SCALE, Vector3.ZERO)
	var box: AABB = _bounds(rotating_model, _model_pivot)
	if box.size != Vector3.ZERO:
		var centre: Vector3 = box.get_center()
		rotating_model.position -= Vector3(centre.x, box.position.y, centre.z)
		# The contact shadow follows the car's footprint.
		_blob.scale = Vector3(box.size.x * 1.15, 1.0, box.size.z * 1.1)
	_add_showroom_antenna()


## PlayerCart's antenna (same rod and tip), stood on the car's AntennaPlacement. Added after the
## car is measured, so it doesn't change the framing. Shown by _paint_changed().
func _add_showroom_antenna() -> void:
	var placement := rotating_model.find_child("AntennaPlacement", true, false) as Node3D
	if placement == null:
		return
	_showroom_antenna = Node3D.new()
	_showroom_antenna.name = "ShowroomAntenna"
	# Upright and life size in the pivot's frame, as PlayerCart has it in Visuals: undo whatever the
	# placement inherits (the scene's Model node is 0.5 and the car x2, so usually nothing).
	var inherited: Vector3 = (_model_pivot.global_transform.affine_inverse() * placement.global_transform).basis.get_scale()
	_showroom_antenna.scale = Vector3.ONE / inherited
	placement.add_child(_showroom_antenna)
	var rod_mat := StandardMaterial3D.new()
	rod_mat.albedo_color = Color(0.2, 0.2, 0.2)
	rod_mat.metallic = 1.0
	rod_mat.roughness = 0.3
	var rod_mesh := CylinderMesh.new()
	rod_mesh.top_radius = 0.005
	rod_mesh.bottom_radius = 0.01
	rod_mesh.height = 0.8
	rod_mesh.radial_segments = 6
	rod_mesh.material = rod_mat
	var rod := MeshInstance3D.new()
	rod.mesh = rod_mesh
	rod.position.y = 0.4
	_showroom_antenna.add_child(rod)
	var tip_mat := StandardMaterial3D.new()
	tip_mat.albedo_color = current_paint.get("accent", Color(1, 0.2, 0))
	tip_mat.roughness = 0.2
	tip_mat.emission_enabled = true
	tip_mat.emission = current_paint.get("accent", Color(1, 0.2, 0))
	tip_mat.emission_energy_multiplier = 1.5
	var tip_mesh := SphereMesh.new()
	tip_mesh.radius = 0.04
	tip_mesh.height = 0.08
	tip_mesh.radial_segments = 8
	tip_mesh.rings = 6
	tip_mesh.material = tip_mat
	var tip := MeshInstance3D.new()
	tip.mesh = tip_mesh
	tip.position.y = 0.8
	_showroom_antenna.add_child(tip)
	_showroom_antenna.visible = CarPaint.has_antenna(current_paint)


## The bounds of every mesh under `node`, in `space`'s frame.
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


## A new car arrives: it drops onto the turntable with a little bounce while the table swings
## round to show it off.
func _play_swap(step: int) -> void:
	if _swap_tween:
		_swap_tween.kill()
	_model_pivot.scale = Vector3.ONE * 0.88
	_model_pivot.position.y = 0.35
	# Start it round so the swing ends on the three-quarter view.
	_turntable.rotation.y = START_YAW - 1.2 * step
	_swap_tween = create_tween().set_parallel(true)
	_swap_tween.tween_property(_model_pivot, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_swap_tween.tween_property(_model_pivot, "position:y", 0.0, 0.38).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_spin = 3.2 * step
	_since_drag = SPIN_RESUME - 0.6
	_name_label.modulate.a = 0.0
	_swap_tween.tween_property(_name_label, "modulate:a", 1.0, 0.3)


func _build_showroom() -> void:
	var holder := SubViewportContainer.new()
	holder.name = "Showroom"
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.mouse_default_cursor_shape = Control.CURSOR_DRAG
	holder.gui_input.connect(_on_showroom_input)
	add_child(holder)
	_stage = SubViewport.new()
	_stage.own_world_3d = true
	_stage.transparent_bg = true
	if OS.has_feature("mobile"):
		_stage.msaa_3d = Viewport.MSAA_DISABLED
		_stage.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	else:
		_stage.msaa_3d = Viewport.MSAA_4X
	# Only while the screen is up: it used to render the preview through every race.
	_stage.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	holder.add_child(_stage)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.4
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	_stage.add_child(we)

	# Key light high on the camera's left with soft shadows; a cool rim from behind; a dim fill.
	var key := DirectionalLight3D.new()
	key.light_energy = 1.7
	key.light_color = Color(1.0, 0.97, 0.92)
	if OS.has_feature("mobile"):
		key.shadow_enabled = false
	else:
		key.shadow_enabled = true
		key.shadow_bias = 0.04
		key.shadow_normal_bias = 2.4
		key.shadow_blur = 1.0
		key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		key.directional_shadow_max_distance = 10.0
		key.directional_shadow_pancake_size = 10.0
	key.rotation = Vector3(deg_to_rad(-58.0), deg_to_rad(-28.0), 0.0)
	_stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_energy = 1.1
	rim.light_color = Color(0.70, 0.84, 1.0)
	rim.rotation = Vector3(deg_to_rad(-24.0), deg_to_rad(160.0), 0.0)
	_stage.add_child(rim)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.35
	fill.light_color = Color(0.85, 0.9, 1.0)
	fill.rotation = Vector3(deg_to_rad(-12.0), deg_to_rad(55.0), 0.0)
	_stage.add_child(fill)

	var cam := Camera3D.new()
	cam.fov = CAMERA_FOV
	cam.near = 0.1
	cam.far = 60.0
	_stage.add_child(cam)
	var pitch: float = deg_to_rad(CAMERA_PITCH)
	cam.look_at_from_position(LOOK_AT + Vector3(0.0, sin(pitch), cos(pitch)) * CAMERA_DIST, LOOK_AT, Vector3.UP)
	cam.current = true

	# The floor: a grid fading out into the backdrop.
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(16.0, 16.0)
	floor_mi.mesh = plane
	var floor_mat := ShaderMaterial.new()
	floor_mat.shader = FLOOR_SHADER
	floor_mi.material_override = floor_mat
	floor_mi.position.y = -0.085
	floor_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stage.add_child(floor_mi)

	# The turntable: a brushed dark disc with a light ring round its edge.
	_turntable = Node3D.new()
	_turntable.rotation.y = START_YAW
	_stage.add_child(_turntable)
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = TABLE_RADIUS
	cyl.bottom_radius = TABLE_RADIUS + 0.05
	cyl.height = 0.08
	cyl.radial_segments = 96
	disc.mesh = cyl
	disc.position.y = -0.04
	var disc_mat := StandardMaterial3D.new()
	disc_mat.albedo_color = Color(0.085, 0.095, 0.12)
	disc_mat.metallic = 0.55
	disc_mat.roughness = 0.34
	disc.material_override = disc_mat
	_turntable.add_child(disc)
	var inlay := MeshInstance3D.new()
	var inlay_cyl := CylinderMesh.new()
	inlay_cyl.top_radius = TABLE_RADIUS - 0.16
	inlay_cyl.bottom_radius = TABLE_RADIUS - 0.16
	inlay_cyl.height = 0.004
	inlay_cyl.radial_segments = 96
	inlay.mesh = inlay_cyl
	inlay.position.y = 0.002
	var inlay_mat := StandardMaterial3D.new()
	inlay_mat.albedo_color = Color(0.06, 0.066, 0.085)
	inlay_mat.metallic = 0.3
	inlay_mat.roughness = 0.6
	inlay.material_override = inlay_mat
	_turntable.add_child(inlay)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = TABLE_RADIUS - 0.012
	torus.outer_radius = TABLE_RADIUS + 0.022
	torus.rings = 96
	torus.ring_segments = 8
	ring.mesh = torus
	ring.position.y = -0.012
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.albedo_color = Color(0, 0, 0)
	_ring_mat.emission_enabled = true
	_ring_mat.emission_energy_multiplier = 2.4
	ring.material_override = _ring_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_turntable.add_child(ring)
	# A soft contact shadow under the car, sized to it in _show_model().
	_blob = MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2(1.0, 1.0)
	_blob.mesh = quad
	_blob.position.y = 0.006
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.72))
	grad.set_color(1, Color(0, 0, 0, 0.0))
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(1.0, 0.5)
	var blob_mat := StandardMaterial3D.new()
	blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blob_mat.albedo_texture = grad_tex
	blob_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_blob.material_override = blob_mat
	_blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_turntable.add_child(_blob)
	_model_pivot = Node3D.new()
	_turntable.add_child(_model_pivot)


## Drag the car round (mouse, or a finger: touch arrives as mouse events); let go and it coasts.
func _on_showroom_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if not event.pressed:
			_since_drag = 0.0
	elif event is InputEventMouseMotion and _dragging:
		var d: float = event.relative.x * DRAG_RAD_PER_PX
		_turntable.rotate_y(d)
		_spin = d / maxf(get_process_delta_time(), 0.001)


# ============================================================================================
#  Screen layout
# ============================================================================================

func _make_fonts() -> void:
	_font_bold = FontVariation.new()
	_font_bold.base_font = ThemeDB.fallback_font
	_font_bold.variation_embolden = 0.7
	_font_bold.spacing_glyph = 1
	_font_title = FontVariation.new()
	_font_title.base_font = ThemeDB.fallback_font
	_font_title.variation_embolden = 1.1
	# Slanted, for a racing number-plate look.
	_font_title.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(0.22, 1.0), Vector2.ZERO)


func _label(text: String, size: int, color: Color, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _card_style(edge: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_CARD
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(2)
	sb.border_color = edge
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0, 6)
	sb.set_content_margin_all(26)
	return sb


## The main menu's chrome buttons: dark, an edge that lights up teal on hover and focus.
func _style_button(btn: Button, radius := 8) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_BUTTON
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(2)
	sb.border_color = COL_BUTTON_EDGE
	sb.set_content_margin_all(8)
	var hover: StyleBoxFlat = sb.duplicate()
	hover.border_color = COL_TEAL
	hover.bg_color = Color(0.16, 0.2, 0.28)
	var pressed: StyleBoxFlat = hover.duplicate()
	pressed.bg_color = Color(0.09, 0.11, 0.16)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_color_override("font_color", COL_TEXT)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_focus_color", Color.WHITE)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _build_backdrop() -> void:
	var bg := TextureRect.new()
	bg.name = "Backdrop"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	var grad := Gradient.new()
	grad.set_color(0, Color(0.13, 0.15, 0.22))
	grad.set_color(1, Color(0.02, 0.024, 0.036))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.62)
	tex.fill_to = Vector2(1.08, 0.0)
	bg.texture = tex
	add_child(bg)
	# The car's name, huge and faint, behind it.
	_bg_name = _label("", 230, Color(1, 1, 1, 0.045), null)
	_bg_name.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bg_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bg_name.offset_top = -170
	_bg_name.clip_text = true
	add_child(_bg_name)


func _build_top_bar() -> void:
	var line := ColorRect.new()
	line.color = COL_TEAL
	line.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	line.offset_bottom = 4
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	box.offset_left = 60
	box.offset_top = 36
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_title = _label("SELECT YOUR CAR", 38, COL_TEXT, _font_bold)
	box.add_child(_title)
	_subtitle = _label("", 20, COL_DIM)
	box.add_child(_subtitle)
	_counter = _label("", 22, COL_DIM, _font_bold)
	_counter.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_counter.offset_left = -220
	_counter.offset_right = -60
	_counter.offset_top = 44
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_counter)


## Left: the car's name, what it's good at, and its stats.
func _build_info_card() -> void:
	var card := PanelContainer.new()
	card.name = "InfoCard"
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	card.offset_left = 60
	card.offset_right = 540
	card.offset_top = 0
	card.offset_bottom = 0
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	card.add_theme_stylebox_override("panel", _card_style(Color(1, 1, 1, 0.06)))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	_name_label = _label("", 56, COL_TEXT, _font_title)
	box.add_child(_name_label)
	_name_line = ColorRect.new()
	_name_line.custom_minimum_size = Vector2(130, 5)
	_name_line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_name_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_name_line)
	_desc = _label("", 19, COL_DIM)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(0, 54)
	box.add_child(_desc)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	box.add_child(gap)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 14)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(grid)
	for st in STATS:
		var cap := _label(st[0], 15, COL_DIM, _font_bold)
		cap.custom_minimum_size = Vector2(150, 0)
		grid.add_child(cap)
		var bar := StatBar.new()
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(bar)
		_stat_bars.append(bar)


## A round arrow button for the line-up (mouse and touch; pads and keys use left/right).
func _arrow_button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 34)
	b.add_theme_font_override("font", _font_bold)
	_style_button(b, 24)
	b.custom_minimum_size = Vector2(48, 48)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(on_press)
	return b


## Bottom: Back, the line-up (every car by name, between arrows), the controls, Confirm.
func _build_bottom_bar() -> void:
	_back_btn = Button.new()
	_back_btn.text = "BACK"
	_back_btn.focus_mode = Control.FOCUS_NONE
	_back_btn.add_theme_font_size_override("font_size", 20)
	_back_btn.add_theme_font_override("font", _font_bold)
	_style_button(_back_btn)
	_back_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_back_btn.offset_left = 60
	_back_btn.offset_right = 240
	_back_btn.offset_top = -112
	_back_btn.offset_bottom = -52
	_back_btn.pressed.connect(_on_back_pressed)
	add_child(_back_btn)

	_confirm_btn = Button.new()
	_confirm_btn.text = "CONFIRM  ›"
	_confirm_btn.add_theme_font_size_override("font_size", 26)
	_confirm_btn.add_theme_font_override("font", _font_bold)
	_confirm_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_confirm_btn.offset_left = -400
	_confirm_btn.offset_right = -60
	_confirm_btn.offset_top = -118
	_confirm_btn.offset_bottom = -46
	_confirm_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	_confirm_btn.set_meta(&"ui_important", true)
	add_child(_confirm_btn)

	var mid := VBoxContainer.new()
	mid.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	mid.offset_left = -560
	mid.offset_right = 560
	mid.offset_top = -124
	mid.offset_bottom = -40
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 12)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mid)
	var strip := HBoxContainer.new()
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	# Ten names fill the room between Back and Confirm: tight pills, small gaps.
	strip.add_theme_constant_override("separation", 3)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(strip)
	strip.add_child(_arrow_button("‹", _on_prev_pressed))
	for k in CAR_PRESETS.size():
		var pill := Button.new()
		pill.text = str(CAR_PRESETS[k].name).to_upper()
		pill.focus_mode = Control.FOCUS_NONE
		pill.flat = true
		pill.add_theme_font_size_override("font_size", 14)
		pill.add_theme_font_override("font", _font_bold)
		pill.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		pill.pressed.connect(_select_car.bind(k))
		strip.add_child(pill)
		_pills.append(pill)
	strip.add_child(_arrow_button("›", _on_next_pressed))
	var hint := _label("‹ ›  change car      drag  rotate      Enter  confirm      Esc  back", 15, Color(COL_DIM, 0.75))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(hint)


## Recolours what follows the car: its name's underline, the bars, the ring, Confirm, the line-up.
func _apply_accent(accent: Color) -> void:
	_name_line.color = accent
	if _paint_title_line:
		_paint_title_line.color = accent
	_ring_mat.emission = accent
	var sb := StyleBoxFlat.new()
	sb.bg_color = accent
	sb.set_corner_radius_all(12)
	sb.shadow_color = Color(accent, 0.45)
	sb.shadow_size = 14
	sb.set_content_margin_all(10)
	var hover: StyleBoxFlat = sb.duplicate()
	hover.bg_color = accent.lightened(0.18)
	hover.shadow_size = 22
	var focus: StyleBoxFlat = hover.duplicate()
	focus.set_border_width_all(3)
	focus.border_color = Color(1, 1, 1, 0.85)
	var pressed: StyleBoxFlat = sb.duplicate()
	pressed.bg_color = accent.darkened(0.15)
	_confirm_btn.add_theme_stylebox_override("normal", sb)
	_confirm_btn.add_theme_stylebox_override("hover", hover)
	_confirm_btn.add_theme_stylebox_override("focus", focus)
	_confirm_btn.add_theme_stylebox_override("pressed", pressed)
	var ink: Color = Color(0.03, 0.04, 0.06) if accent.get_luminance() > 0.45 else Color.WHITE
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		_confirm_btn.add_theme_color_override(state, ink)
	for k in _pills.size():
		var pill: Button = _pills[k]
		var on: bool = k == current_car_index
		var pb := StyleBoxFlat.new()
		pb.bg_color = Color(accent, 0.22) if on else Color(0, 0, 0, 0)
		pb.set_corner_radius_all(6)
		pb.border_width_bottom = 4 if on else 0
		pb.border_color = accent
		pb.content_margin_left = 8
		pb.content_margin_right = 8
		pb.content_margin_top = 6
		pb.content_margin_bottom = 6
		var ph: StyleBoxFlat = pb.duplicate()
		ph.bg_color = Color(accent, 0.24) if on else Color(1, 1, 1, 0.06)
		pill.add_theme_stylebox_override("normal", pb)
		pill.add_theme_stylebox_override("hover", ph)
		pill.add_theme_stylebox_override("pressed", ph)
		var c: Color = accent.lightened(0.25) if on else Color(COL_DIM, 0.8)
		pill.add_theme_color_override("font_color", c)
		pill.add_theme_color_override("font_hover_color", COL_TEXT)


# ============================================================================================
#  Paint shop (procedural cars: CarPaint.gd, car_body.gdshader)
# ============================================================================================

func _is_paintable() -> bool:
	return rotating_model != null and CarPaint.is_paintable(rotating_model)


func _paint_section() -> String:
	return "paint" if player_slot == 1 else "paint_p2"


## The saved paint job for the previewed car, or its factory paint.
func _load_paint() -> void:
	var paintable := _is_paintable()
	_paint_rows.visible = paintable
	_paint_note.visible = not paintable
	if not paintable:
		current_paint = {}
		return
	var car_name: String = CAR_PRESETS[current_car_index].name
	var saved: Variant = null
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK and config.has_section_key(_paint_section(), car_name):
		saved = config.get_value(_paint_section(), car_name)
	current_paint = CarPaint.sanitize(saved, car_name)
	_paint_changed(false)


func _save_paint() -> void:
	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	config.set_value(_paint_section(), CAR_PRESETS[current_car_index].name, current_paint)
	config.save("user://settings.cfg")


## Shows the paint job on the preview and in the panel; `save` stores it for this car.
func _paint_changed(save := true) -> void:
	if rotating_model:
		CarPaint.apply(rotating_model, current_paint)
	_paint_values["pattern"].text = CarPaint.PATTERNS[current_paint["pattern"]]
	_paint_values["finish"].text = CarPaint.FINISHES[current_paint["finish"]]
	for key in ["primary", "secondary", "accent", "rim"]:
		var c: Color = current_paint[key]
		_paint_swatches[key].color = c
		var list: Array = CarPaint.RIMS if key == "rim" else CarPaint.PALETTE
		_paint_values[key].text = list[_nearest(list, c)][0]
	_paint_values["number"].text = str(current_paint["number"])
	# Only the Racer and Rally patterns show a number.
	_number_row.visible = CarPaint.PATTERNS[current_paint["pattern"]] in ["Racer", "Rally"]
	_paint_values["antenna"].text = "ON" if CarPaint.has_antenna(current_paint) else "OFF"
	if _showroom_antenna:
		_showroom_antenna.visible = CarPaint.has_antenna(current_paint)
		var tip := _showroom_antenna.get_child(1) as MeshInstance3D
		var tip_mat := (tip.mesh as SphereMesh).material as StandardMaterial3D
		tip_mat.albedo_color = current_paint.get("accent", Color(1, 0.2, 0))
		tip_mat.emission = current_paint.get("accent", Color(1, 0.2, 0))
	if save:
		_save_paint()


static func _nearest(list: Array, c: Color) -> int:
	var best := 0
	var best_d := INF
	for k in list.size():
		var e: Color = list[k][1]
		var d: float = Vector3(e.r - c.r, e.g - c.g, e.b - c.b).length_squared()
		if d < best_d:
			best_d = d
			best = k
	return best


func _cycle(key: String, step: int) -> void:
	if current_paint.is_empty():
		return
	match key:
		"pattern":
			current_paint["pattern"] = posmod(current_paint["pattern"] + step, CarPaint.PATTERNS.size())
		"finish":
			current_paint["finish"] = posmod(current_paint["finish"] + step, CarPaint.FINISHES.size())
		"number":
			current_paint["number"] = posmod(current_paint["number"] + step, 100)
		"antenna":
			current_paint["antenna"] = not CarPaint.has_antenna(current_paint)
		_:
			var list: Array = CarPaint.RIMS if key == "rim" else CarPaint.PALETTE
			var k: int = posmod(_nearest(list, current_paint[key]) + step, list.size())
			current_paint[key] = list[k][1]
	_paint_changed()


func _on_paint_random() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var antenna: bool = CarPaint.has_antenna(current_paint)
	current_paint = CarPaint.random(rng, CAR_PRESETS[current_car_index].name)
	current_paint["antenna"] = antenna
	_paint_changed()


func _on_paint_reset() -> void:
	var antenna: bool = CarPaint.has_antenna(current_paint)
	current_paint = CarPaint.factory(CAR_PRESETS[current_car_index].name)
	current_paint["antenna"] = antenna
	_paint_changed()


## The paint shop, right of the car. Built here so it follows CarPaint's lists. Each row is one
## focusable button: left/right (or its arrows) step through the choices, pressing it steps on.
func _build_paint_panel() -> void:
	_paint_panel = PanelContainer.new()
	_paint_panel.name = "PaintPanel"
	_paint_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_paint_panel.offset_left = -540
	_paint_panel.offset_right = -60
	# No height of its own: it fits its rows, growing both ways from the middle.
	_paint_panel.offset_top = 0
	_paint_panel.offset_bottom = 0
	_paint_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_paint_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_paint_panel.add_theme_stylebox_override("panel", _card_style(Color(1, 1, 1, 0.06)))
	add_child(_paint_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_paint_panel.add_child(box)
	var title := _label("PAINT SHOP", 26, COL_TEXT, _font_bold)
	box.add_child(title)
	_paint_title_line = ColorRect.new()
	_paint_title_line.custom_minimum_size = Vector2(90, 4)
	_paint_title_line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(_paint_title_line)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	box.add_child(gap)
	_paint_rows = VBoxContainer.new()
	_paint_rows.add_theme_constant_override("separation", 8)
	box.add_child(_paint_rows)
	_paint_rows.add_child(_paint_row("pattern", "PATTERN", false))
	_paint_rows.add_child(_paint_row("finish", "FINISH", false))
	_paint_rows.add_child(_paint_row("primary", "MAIN", true))
	_paint_rows.add_child(_paint_row("secondary", "SECOND", true))
	_paint_rows.add_child(_paint_row("accent", "ACCENT", true))
	_paint_rows.add_child(_paint_row("rim", "RIMS", true))
	_number_row = _paint_row("number", "NUMBER", false)
	_paint_rows.add_child(_number_row)
	_paint_rows.add_child(_paint_row("antenna", "ANTENNA", false))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	_paint_rows.add_child(spacer)
	for spec in [["RANDOM", _on_paint_random], ["FACTORY", _on_paint_reset]]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(0, 48)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 18)
		b.add_theme_font_override("font", _font_bold)
		_style_button(b)
		b.pressed.connect(spec[1])
		buttons.add_child(b)
	_paint_rows.add_child(buttons)
	_paint_note = _label("This car comes in its factory paint.", 18, COL_DIM)
	_paint_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_paint_note)


func _paint_row(key: String, caption: String, swatch: bool) -> Control:
	var row := Button.new()
	row.custom_minimum_size = Vector2(0, 48)
	row.focus_mode = Control.FOCUS_ALL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.035)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = Color(0, 0, 0, 0)
	var hover: StyleBoxFlat = sb.duplicate()
	hover.bg_color = Color(1, 1, 1, 0.07)
	var focus: StyleBoxFlat = hover.duplicate()
	focus.border_color = COL_TEAL
	row.add_theme_stylebox_override("normal", sb)
	row.add_theme_stylebox_override("hover", hover)
	row.add_theme_stylebox_override("pressed", hover)
	row.add_theme_stylebox_override("focus", focus)
	row.pressed.connect(_cycle.bind(key, 1))
	row.gui_input.connect(func(ev: InputEvent) -> void:
		if ev.is_action_pressed("ui_left", true):
			_cycle(key, -1)
			row.accept_event()
		elif ev.is_action_pressed("ui_right", true):
			_cycle(key, 1)
			row.accept_event())
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 14
	h.offset_right = -6
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(h)
	var label := _label(caption, 14, COL_DIM, _font_bold)
	label.custom_minimum_size = Vector2(92, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(label)
	h.add_child(_row_arrow("‹", key, -1))
	if swatch:
		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(24, 24)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(sw)
		_paint_swatches[key] = sw
	var value := _label("", 18, COL_TEXT)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.clip_text = true
	h.add_child(value)
	_paint_values[key] = value
	h.add_child(_row_arrow("›", key, 1))
	return row


func _row_arrow(text: String, key: String, step: int) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(36, 0)
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_color_override("font_color", COL_DIM)
	b.add_theme_color_override("font_hover_color", COL_TEAL)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(_cycle.bind(key, step))
	return b


## A stat as ten slanted segments, filling (and draining) smoothly when the car changes.
class StatBar extends Control:
	const SEGMENTS := 10
	const GAP := 4.0
	var value := 0.0
	var shown := 0.0
	var color := Color.WHITE

	func _init() -> void:
		custom_minimum_size = Vector2(250, 16)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_value(v: float, c: Color) -> void:
		value = v
		color = c
		queue_redraw()

	func _process(delta: float) -> void:
		if absf(shown - value) > 0.001:
			shown = lerpf(shown, value, 1.0 - exp(-delta * 9.0))
			queue_redraw()

	func _draw() -> void:
		var h: float = size.y
		var w: float = (size.x - GAP * (SEGMENTS - 1) - h * 0.4) / SEGMENTS
		var skew: float = h * 0.4
		for k in SEGMENTS:
			var x0: float = k * (w + GAP)
			draw_colored_polygon(PackedVector2Array([Vector2(x0 + skew, 0), Vector2(x0 + w + skew, 0),
					Vector2(x0 + w, h), Vector2(x0, h)]), Color(1, 1, 1, 0.07))
			var f: float = clampf(shown * SEGMENTS - k, 0.0, 1.0)
			if f > 0.0:
				draw_colored_polygon(PackedVector2Array([Vector2(x0 + skew, 0), Vector2(x0 + w * f + skew, 0),
						Vector2(x0 + w * f, h), Vector2(x0, h)]), color)
