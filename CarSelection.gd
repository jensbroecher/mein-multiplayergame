extends Control

signal car_selected(car_index: int)

const CarPaint = preload("res://CarPaint.gd")

@onready var car_name_label = $CenterContainer/VBoxContainer/CarName
@onready var preview_viewport = $CenterContainer/VBoxContainer/PreviewContainer/SubViewport
@onready var model_pivot = $CenterContainer/VBoxContainer/PreviewContainer/SubViewport/ModelPivot
@onready var speed_bar = $CenterContainer/VBoxContainer/StatsGrid/SpeedBar
@onready var accel_bar = $CenterContainer/VBoxContainer/StatsGrid/AccelBar
@onready var handling_bar = $CenterContainer/VBoxContainer/StatsGrid/HandlingBar
@onready var offroad_bar = $CenterContainer/VBoxContainer/StatsGrid/OffroadBar

var current_car_index = 0
var rotating_model: Node3D = null
## Who is choosing: 2 is split-screen's second player, whose paint jobs are saved apart.
var player_slot := 1
## The paint job on the previewed car (procedural cars only).
var current_paint: Dictionary = {}
var _paint_panel: PanelContainer
var _paint_values := {}      # row key -> Label showing the choice
var _paint_swatches := {}    # row key -> ColorRect
var _number_row: Control

const CAR_PRESETS = [
	{
		"name": "Viper",
		"model_path": "res://models/cars/Viper.tscn",
		"model_y_rotation": PI,
		"max_speed": 40.0,
		"acceleration": 65.0,
		"steer_speed": 2.5,
		"grip": 5.0,
		"braking": 40.0,
		"offroad": 6.0,
		"desc": "All-around performer. Great for beginners.",
		"wheel_parts": {"FL": "part_5", "FR": "part_2", "RL": "part_0", "RR": "part_6"}
	},
	{
		"name": "Shadow",
		"model_path": "res://models/cars/Shadow.tscn",
		"model_y_rotation": PI,
		"max_speed": 41.0,
		"acceleration": 52.0,
		"steer_speed": 2.2,
		"grip": 4.5,
		"braking": 32.0,
		"offroad": 4.0,
		"desc": "High top speed, but slower to accelerate.",
		"wheel_parts": {"FL": "part_3", "FR": "part_0", "RL": "part_4", "RR": "part_2"}
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
		"model_path": "res://models/cars/Apex.tscn",
		"model_y_rotation": PI,
		"max_speed": 39.0,
		"acceleration": 70.0,
		"steer_speed": 3.2,
		"grip": 6.0,
		"braking": 46.0,
		"offroad": 5.0,
		"desc": "Unmatched steering response. Master of drifts.",
		"wheel_parts": {"FL": "part_0", "FR": "part_1", "RL": "part_4", "RR": "part_2"}
	},
	{
		"name": "Interceptor",
		"model_path": "res://models/cars/Interceptor.tscn",
		"model_y_rotation": PI,
		"max_speed": 43.0,
		"acceleration": 58.0,
		"steer_speed": 2.0,
		"grip": 4.0,
		"braking": 35.0,
		"offroad": 3.0,
		"desc": "High speed interceptor. Built for straightaways.",
		"wheel_parts": {"FL": "part_6", "FR": "part_3", "RL": "part_4", "RR": "part_5"}
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
		"offroad": 4.0,
		"desc": "Super agile drift machine. Slides effortlessly around corners.",
		"wheel_parts": {"FL": "Wheel_FL", "FR": "Wheel_FR", "RL": "Wheel_RL", "RR": "Wheel_RR"}
	},
	{
		"name": "Centurion",
		"model_path": "res://models/cars/Centurion.tscn",
		"model_y_rotation": PI,
		"max_speed": 39.5,
		"acceleration": 76.0,
		"steer_speed": 2.6,
		"grip": 5.5,
		"braking": 48.0,
		"offroad": 6.5,
		"desc": "Heavy armored racer. Balanced stats with high durability.",
		"wheel_parts": {"FL": "part_0", "FR": "part_5", "RL": "part_2", "RR": "part_3"}
	}
]

func _ready():
	$CenterContainer/VBoxContainer/NavButtons/ButtonPrev.pressed.connect(_on_prev_pressed)
	$CenterContainer/VBoxContainer/NavButtons/ButtonNext.pressed.connect(_on_next_pressed)
	$CenterContainer/VBoxContainer/ButtonConfirm.pressed.connect(_on_confirm_pressed)
	
	# Load saved car selection
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		current_car_index = config.get_value("player", "car_index", 0)
		current_car_index = clamp(current_car_index, 0, CAR_PRESETS.size() - 1)
	NetworkManager.local_car_index = current_car_index

	_setup_preview_lighting()
	_build_paint_panel()
	update_car_selection()

func _process(delta):
	if model_pivot:
		model_pivot.rotate_y(0.8 * delta)

func update_car_selection():
	var preset = CAR_PRESETS[current_car_index]
	car_name_label.text = preset.name
	$CenterContainer/VBoxContainer/Description.text = preset.desc
	
	# Update stats UI (maps values to 0-100 range)
	speed_bar.value = (preset.max_speed / 50.0) * 100.0
	accel_bar.value = (preset.acceleration / 100.0) * 100.0
	handling_bar.value = (preset.steer_speed / 4.0) * 100.0
	offroad_bar.value = (preset.get("offroad", 5.0) / 10.0) * 100.0
	
	# Instantiate preview model
	if rotating_model:
		rotating_model.queue_free()
		rotating_model = null
		
	var scene = load(preset.model_path)
	if scene:
		rotating_model = scene.instantiate()
		model_pivot.add_child(rotating_model)
		# Position/orient preview model with larger scale
		var rot = preset.get("model_y_rotation", PI)
		rotating_model.transform = Transform3D(Basis(Vector3(0, 1, 0), rot) * 2.4, Vector3(0, -0.4, 0))
	_load_paint()

func _on_prev_pressed():
	current_car_index = (current_car_index - 1 + CAR_PRESETS.size()) % CAR_PRESETS.size()
	update_car_selection()

func _on_next_pressed():
	current_car_index = (current_car_index + 1) % CAR_PRESETS.size()
	update_car_selection()

func _on_confirm_pressed():
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

## Called by Main.gd during LOCAL_COOP to let a second player pick their car.
func show_for_player(player_num: int):
	# Update the header label if it exists
	var header = get_node_or_null("CenterContainer/VBoxContainer/HeaderLabel")
	if not header:
		header = Label.new()
		header.name = "HeaderLabel"
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_theme_font_size_override("font_size", 28)
		$CenterContainer/VBoxContainer.add_child(header)
		$CenterContainer/VBoxContainer.move_child(header, 0)
	header.text = "PLAYER %d — SELECT CAR" % player_num
	player_slot = player_num
	# Reset to first car so players don't accidentally duplicate choices
	current_car_index = 0
	update_car_selection()
	show()


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
	if _paint_panel:
		_paint_panel.visible = paintable
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
	# Only the Racer pattern shows a number.
	_number_row.visible = current_paint["pattern"] == CarPaint.PATTERNS.find("Racer")
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
	match key:
		"pattern":
			current_paint["pattern"] = posmod(current_paint["pattern"] + step, CarPaint.PATTERNS.size())
		"finish":
			current_paint["finish"] = posmod(current_paint["finish"] + step, CarPaint.FINISHES.size())
		"number":
			current_paint["number"] = posmod(current_paint["number"] + step, 100)
		_:
			var list: Array = CarPaint.RIMS if key == "rim" else CarPaint.PALETTE
			var k: int = posmod(_nearest(list, current_paint[key]) + step, list.size())
			current_paint[key] = list[k][1]
	_paint_changed()


func _on_paint_random() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	current_paint = CarPaint.random(rng, CAR_PRESETS[current_car_index].name)
	_paint_changed()


func _on_paint_reset() -> void:
	current_paint = CarPaint.factory(CAR_PRESETS[current_car_index].name)
	_paint_changed()


## The paint shop panel, right of the car column. Built here rather than in CarSelection.tscn so it
## follows CarPaint's lists; every control is a Button, so pads and keyboards can drive it.
func _build_paint_panel() -> void:
	_paint_panel = PanelContainer.new()
	_paint_panel.name = "PaintPanel"
	_paint_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_paint_panel.offset_left = -470
	_paint_panel.offset_right = -40
	# No height of its own: it fits its rows, growing both ways from the middle.
	_paint_panel.offset_top = 0
	_paint_panel.offset_bottom = 0
	_paint_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_paint_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.16, 0.21, 0.95)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(18)
	_paint_panel.add_theme_stylebox_override("panel", style)
	add_child(_paint_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_paint_panel.add_child(box)
	var title := Label.new()
	title.text = "PAINT SHOP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)
	box.add_child(_paint_row("pattern", "Pattern", false))
	box.add_child(_paint_row("finish", "Finish", false))
	box.add_child(_paint_row("primary", "Main", true))
	box.add_child(_paint_row("secondary", "Second", true))
	box.add_child(_paint_row("accent", "Accent", true))
	box.add_child(_paint_row("rim", "Rims", true))
	_number_row = _paint_row("number", "Number", false)
	box.add_child(_number_row)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	var rnd := Button.new()
	rnd.text = "RANDOM"
	rnd.custom_minimum_size = Vector2(140, 40)
	rnd.pressed.connect(_on_paint_random)
	buttons.add_child(rnd)
	var reset := Button.new()
	reset.text = "FACTORY"
	reset.custom_minimum_size = Vector2(140, 40)
	reset.pressed.connect(_on_paint_reset)
	buttons.add_child(reset)
	box.add_child(buttons)
	_paint_panel.visible = false


func _paint_row(key: String, caption: String, swatch: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size = Vector2(80, 0)
	row.add_child(label)
	var prev := Button.new()
	prev.text = "<"
	prev.custom_minimum_size = Vector2(40, 36)
	prev.pressed.connect(_cycle.bind(key, -1))
	row.add_child(prev)
	if swatch:
		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(28, 28)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(sw)
		_paint_swatches[key] = sw
	var value := Label.new()
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.clip_text = true
	row.add_child(value)
	_paint_values[key] = value
	var next := Button.new()
	next.text = ">"
	next.custom_minimum_size = Vector2(40, 36)
	next.pressed.connect(_cycle.bind(key, 1))
	row.add_child(next)
	return row


## Sky light for the preview, so metallic, pearl and chrome paint have something to reflect.
## The background stays transparent: the sky only lights the car.
func _setup_preview_lighting() -> void:
	if preview_viewport.get_node_or_null("PreviewEnvironment"):
		return
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.32, 0.50, 0.78)
	sm.sky_horizon_color = Color(0.74, 0.80, 0.86)
	sm.ground_bottom_color = Color(0.20, 0.20, 0.22)
	sm.ground_horizon_color = Color(0.50, 0.52, 0.54)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.name = "PreviewEnvironment"
	we.environment = env
	preview_viewport.add_child(we)
