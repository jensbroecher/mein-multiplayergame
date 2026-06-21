extends Control

signal car_selected(car_index: int)

@onready var car_name_label = $CenterContainer/VBoxContainer/CarName
@onready var preview_viewport = $CenterContainer/VBoxContainer/PreviewContainer/SubViewport
@onready var model_pivot = $CenterContainer/VBoxContainer/PreviewContainer/SubViewport/ModelPivot
@onready var speed_bar = $CenterContainer/VBoxContainer/StatsGrid/SpeedBar
@onready var accel_bar = $CenterContainer/VBoxContainer/StatsGrid/AccelBar
@onready var handling_bar = $CenterContainer/VBoxContainer/StatsGrid/HandlingBar
@onready var offroad_bar = $CenterContainer/VBoxContainer/StatsGrid/OffroadBar

var current_car_index = 0
var rotating_model: Node3D = null

const CAR_PRESETS = [
	{
		"name": "Viper",
		"model_path": "res://models/cars/20260505221030_500312d9.fbx",
		"max_speed": 30.0,
		"acceleration": 50.0,
		"steer_speed": 2.5,
		"grip": 5.0,
		"braking": 40.0,
		"offroad": 6.0,
		"desc": "All-around performer. Great for beginners.",
		"wheel_parts": {"FL": "part_5", "FR": "part_2", "RL": "part_0", "RR": "part_6"}
	},
	{
		"name": "Shadow",
		"model_path": "res://models/cars/20260505210312_305e4d34.fbx",
		"max_speed": 30.5,
		"acceleration": 40.0,
		"steer_speed": 2.2,
		"grip": 4.5,
		"braking": 30.0,
		"offroad": 4.0,
		"desc": "High top speed, but slower to accelerate.",
		"wheel_parts": {"FL": "part_3", "FR": "part_0", "RL": "part_4", "RR": "part_2"}
	},
	{
		"name": "Strikeforce",
		"model_path": "res://models/cars/20260505211857_6fc2a5d6.fbx",
		"max_speed": 28.0,
		"acceleration": 65.0,
		"steer_speed": 2.7,
		"grip": 5.5,
		"braking": 55.0,
		"offroad": 8.0,
		"desc": "Explosive acceleration and good handling.",
		"wheel_parts": {"FL": "part_10", "FR": "part_7", "RL": "part_11", "RR": "part_9"}
	},
	{
		"name": "Apex",
		"model_path": "res://models/cars/HIINQjUWAAAZYGR.fbx",
		"max_speed": 29.0,
		"acceleration": 55.0,
		"steer_speed": 3.2,
		"grip": 6.0,
		"braking": 48.0,
		"offroad": 5.0,
		"desc": "Unmatched steering response. Master of drifts.",
		"wheel_parts": {"FL": "part_0", "FR": "part_1", "RL": "part_3", "RR": "part_2"}
	},
	{
		"name": "Interceptor",
		"model_path": "res://models/cars/20260618044707_89ae4d5d.fbx",
		"max_speed": 32.0,
		"acceleration": 45.0,
		"steer_speed": 2.0,
		"grip": 4.0,
		"braking": 35.0,
		"offroad": 3.0,
		"desc": "High speed interceptor. Built for straightaways.",
		"wheel_parts": {"FL": "part_5", "FR": "part_4", "RL": "part_3", "RR": "part_2"}
	},
	{
		"name": "Mudrunner",
		"model_path": "res://models/cars/20260618232844_3429272f.fbx",
		"max_speed": 27.0,
		"acceleration": 55.0,
		"steer_speed": 2.4,
		"grip": 5.0,
		"braking": 45.0,
		"offroad": 9.5,
		"desc": "Offroad specialist. Heavy tires maintain full speed off-track.",
		"wheel_parts": {"FL": "part_5", "FR": "part_4", "RL": "part_3", "RR": "part_2"}
	},
	{
		"name": "Phantom",
		"model_path": "res://models/cars/20260618234038_69b1ff17.fbx",
		"max_speed": 29.5,
		"acceleration": 50.0,
		"steer_speed": 3.5,
		"grip": 3.5,
		"braking": 40.0,
		"offroad": 4.0,
		"desc": "Super agile drift machine. Slides effortlessly around corners.",
		"wheel_parts": {"FL": "part_5", "FR": "part_4", "RL": "part_3", "RR": "part_2"}
	},
	{
		"name": "Centurion",
		"model_path": "res://models/cars/20260618234103_e5456a8f.fbx",
		"max_speed": 29.5,
		"acceleration": 60.0,
		"steer_speed": 2.6,
		"grip": 5.5,
		"braking": 50.0,
		"offroad": 6.5,
		"desc": "Heavy armored racer. Balanced stats with high durability.",
		"wheel_parts": {"FL": "part_5", "FR": "part_4", "RL": "part_3", "RR": "part_2"}
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
	
	update_car_selection()

func _process(delta):
	if model_pivot:
		model_pivot.rotate_y(0.8 * delta)

func update_car_selection():
	var preset = CAR_PRESETS[current_car_index]
	car_name_label.text = preset.name
	$CenterContainer/VBoxContainer/Description.text = preset.desc
	
	# Update stats UI (maps values to 0-100 range)
	speed_bar.value = (preset.max_speed / 40.0) * 100.0
	accel_bar.value = (preset.acceleration / 80.0) * 100.0
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
		rotating_model.transform = Transform3D(Basis(Vector3(0, 1, 0), PI) * 2.4, Vector3(0, -0.4, 0))
		# Hide wheels on preview too
		_hide_preview_wheels(rotating_model)

func _hide_preview_wheels(model: Node3D):
	var preset = CAR_PRESETS[current_car_index]
	var wheel_parts: Dictionary = preset.get("wheel_parts", {})
	for corner in ["FL", "FR", "RL", "RR"]:
		var part_name: String = wheel_parts.get(corner, "")
		if not part_name.is_empty():
			var wheel_part = model.get_node_or_null(part_name)
			if wheel_part:
				wheel_part.visible = false

func _on_prev_pressed():
	current_car_index = (current_car_index - 1 + CAR_PRESETS.size()) % CAR_PRESETS.size()
	update_car_selection()

func _on_next_pressed():
	current_car_index = (current_car_index + 1) % CAR_PRESETS.size()
	update_car_selection()

func _on_confirm_pressed():
	NetworkManager.local_car_index = current_car_index
	car_selected.emit(current_car_index)
	
	# Save car selection
	var config = ConfigFile.new()
	config.load("user://settings.cfg") # Load existing if it exists
	config.set_value("player", "car_index", current_car_index)
	config.save("user://settings.cfg")
	
	hide()
