extends Control

signal car_selected(car_index: int)

@onready var car_name_label = $CenterContainer/VBoxContainer/CarName
@onready var preview_viewport = $CenterContainer/VBoxContainer/PreviewContainer/SubViewport
@onready var model_pivot = $CenterContainer/VBoxContainer/PreviewContainer/SubViewport/ModelPivot
@onready var speed_bar = $CenterContainer/VBoxContainer/StatsGrid/SpeedBar
@onready var accel_bar = $CenterContainer/VBoxContainer/StatsGrid/AccelBar
@onready var handling_bar = $CenterContainer/VBoxContainer/StatsGrid/HandlingBar

var current_car_index = 0
var rotating_model: Node3D = null

const CAR_PRESETS = [
	{
		"name": "Viper (Balanced)",
		"model_path": "res://models/cars/20260505221030_500312d9.fbx",
		"max_speed": 30.0,
		"acceleration": 50.0,
		"steer_speed": 2.5,
		"grip": 5.0,
		"desc": "All-around performer. Great for beginners."
	},
	{
		"name": "Lightning (Speedster)",
		"model_path": "res://models/cars/20260505210312_305e4d34.fbx",
		"max_speed": 35.0,
		"acceleration": 40.0,
		"steer_speed": 2.2,
		"grip": 4.5,
		"desc": "Extreme top speed, but slower to accelerate."
	},
	{
		"name": "Strikeforce (Muscle)",
		"model_path": "res://models/cars/20260505211857_6fc2a5d6.fbx",
		"max_speed": 28.0,
		"acceleration": 65.0,
		"steer_speed": 2.7,
		"grip": 5.5,
		"desc": "Explosive acceleration and good handling."
	},
	{
		"name": "Apex (Agile)",
		"model_path": "res://models/cars/20260505221804_6590f061.fbx",
		"max_speed": 29.0,
		"acceleration": 55.0,
		"steer_speed": 3.2,
		"grip": 6.0,
		"desc": "Unmatched steering response. Master of drifts."
	}
]

func _ready():
	$CenterContainer/VBoxContainer/NavButtons/ButtonPrev.pressed.connect(_on_prev_pressed)
	$CenterContainer/VBoxContainer/NavButtons/ButtonNext.pressed.connect(_on_next_pressed)
	$CenterContainer/VBoxContainer/ButtonConfirm.pressed.connect(_on_confirm_pressed)
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
	
	# Instantiate preview model
	if rotating_model:
		rotating_model.queue_free()
		rotating_model = null
		
	var scene = load(preset.model_path)
	if scene:
		rotating_model = scene.instantiate()
		model_pivot.add_child(rotating_model)
		# Position/orient preview model
		rotating_model.transform = Transform3D(Basis(Vector3(0, 1, 0), PI) * 1.5, Vector3(0, -0.4, 0))
		# Hide wheels on preview too
		_hide_preview_wheels(rotating_model)

func _hide_preview_wheels(model: Node3D):
	# Match our dynamic wheel hiding from PlayerCart.gd
	# FL/FR/RL/RR wheel coordinates in local space
	var wheel_locs = [
		Vector3(0.26, 0.09, 0.40),
		Vector3(-0.26, 0.09, 0.40),
		Vector3(0.26, 0.09, -0.27),
		Vector3(-0.26, 0.09, -0.27)
	]
	for child in model.get_children():
		if child is Node3D:
			var is_wheel = false
			for w_loc in wheel_locs:
				if child.position.distance_to(w_loc) < 0.2:
					is_wheel = true
					break
			if is_wheel:
				child.visible = false

func _on_prev_pressed():
	current_car_index = (current_car_index - 1 + CAR_PRESETS.size()) % CAR_PRESETS.size()
	update_car_selection()

func _on_next_pressed():
	current_car_index = (current_car_index + 1) % CAR_PRESETS.size()
	update_car_selection()

func _on_confirm_pressed():
	NetworkManager.local_car_index = current_car_index
	car_selected.emit(current_car_index)
	hide()
