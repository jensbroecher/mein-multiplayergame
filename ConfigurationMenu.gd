extends Control

signal back_pressed

@onready var check_fps = $Panel/MarginContainer/VBoxContainer/ScrollContainer/SettingsList/LeftColumn/VideoSettings/FPSBox/CheckFPS
@onready var option_window_mode = $Panel/MarginContainer/VBoxContainer/ScrollContainer/SettingsList/LeftColumn/VideoSettings/WindowModeBox/OptionWindowMode
@onready var option_resolution = $Panel/MarginContainer/VBoxContainer/ScrollContainer/SettingsList/LeftColumn/VideoSettings/ResolutionBox/OptionResolution
@onready var check_vsync = $Panel/MarginContainer/VBoxContainer/ScrollContainer/SettingsList/LeftColumn/VideoSettings/VSyncBox/CheckVSync

@onready var btn_throttle = $Panel/MarginContainer/VBoxContainer/ScrollContainer/SettingsList/LeftColumn/InputSettings/RemapThrottle/BtnThrottle
@onready var btn_brake = $Panel/MarginContainer/VBoxContainer/ScrollContainer/SettingsList/LeftColumn/InputSettings/RemapBrake/BtnBrake
@onready var btn_steer_left = $Panel/MarginContainer/VBoxContainer/ScrollContainer/SettingsList/LeftColumn/InputSettings/RemapSteerLeft/BtnSteerLeft
@onready var btn_steer_right = $Panel/MarginContainer/VBoxContainer/ScrollContainer/SettingsList/LeftColumn/InputSettings/RemapSteerRight/BtnSteerRight
@onready var btn_boost = $Panel/MarginContainer/VBoxContainer/ScrollContainer/SettingsList/LeftColumn/InputSettings/RemapBoost/BtnBoost
@onready var btn_discard = $Panel/MarginContainer/VBoxContainer/ScrollContainer/SettingsList/LeftColumn/InputSettings/RemapDiscard/BtnDiscard

@onready var btn_back = $Panel/MarginContainer/VBoxContainer/BtnBack

var is_waiting_for_key: bool = false
var waiting_action: String = ""

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Configure option window mode items
	option_window_mode.clear()
	option_window_mode.add_item("Windowed")
	option_window_mode.add_item("Fullscreen")
	
	# Configure option resolution items
	option_resolution.clear()
	option_resolution.add_item("1280 x 720 (720p)")
	option_resolution.add_item("1920 x 1080 (1080p)")
	option_resolution.add_item("2560 x 1440 (2K)")
	option_resolution.add_item("3840 x 2160 (4K)")
	
	# Load current display values from MusicManager
	check_fps.button_pressed = MusicManager.show_fps
	option_window_mode.selected = MusicManager.window_mode
	option_resolution.selected = MusicManager.resolution_index
	check_vsync.button_pressed = MusicManager.vsync
	
	# Connect signals
	check_fps.toggled.connect(_on_fps_toggled)
	option_window_mode.item_selected.connect(_on_window_mode_selected)
	option_resolution.item_selected.connect(_on_resolution_selected)
	check_vsync.toggled.connect(_on_vsync_toggled)
	btn_back.pressed.connect(_on_back_pressed)
	
	# Connect remapping buttons
	btn_throttle.pressed.connect(func(): start_remapping("throttle", btn_throttle))
	btn_brake.pressed.connect(func(): start_remapping("brake", btn_brake))
	btn_steer_left.pressed.connect(func(): start_remapping("steer_left", btn_steer_left))
	btn_steer_right.pressed.connect(func(): start_remapping("steer_right", btn_steer_right))
	btn_boost.pressed.connect(func(): start_remapping("boost", btn_boost))
	btn_discard.pressed.connect(func(): start_remapping("discard_item", btn_discard))
	
	update_keybind_buttons()

func update_keybind_buttons():
	btn_throttle.text = MusicManager.get_action_key_text("throttle")
	btn_brake.text = MusicManager.get_action_key_text("brake")
	btn_steer_left.text = MusicManager.get_action_key_text("steer_left")
	btn_steer_right.text = MusicManager.get_action_key_text("steer_right")
	btn_boost.text = MusicManager.get_action_key_text("boost")
	btn_discard.text = MusicManager.get_action_key_text("discard_item")

func start_remapping(action_name: String, button: Button):
	if is_waiting_for_key:
		update_keybind_buttons()
		
	is_waiting_for_key = true
	waiting_action = action_name
	button.text = "[Press Any Key...]"
	button.grab_focus()

func _unhandled_input(event: InputEvent):
	if is_waiting_for_key and event is InputEventKey and event.pressed:
		is_waiting_for_key = false
		var keycode = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		if keycode != KEY_ESCAPE:
			MusicManager.save_action_key(waiting_action, keycode)
		update_keybind_buttons()
		get_viewport().set_input_as_handled()

func _on_fps_toggled(toggled_val: bool):
	MusicManager.set_show_fps(toggled_val)

func _on_window_mode_selected(index: int):
	MusicManager.set_window_mode(index)

func _on_resolution_selected(index: int):
	MusicManager.set_resolution(index)

func _on_vsync_toggled(toggled_val: bool):
	MusicManager.set_vsync(toggled_val)

func _on_back_pressed():
	is_waiting_for_key = false
	back_pressed.emit()
	hide()
