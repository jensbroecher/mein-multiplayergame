extends Control

@onready var music_slider = $Panel/MarginContainer/VBoxContainer/SettingsList/MusicVolumeBox/MusicSlider
@onready var sfx_slider = $Panel/MarginContainer/VBoxContainer/SettingsList/SFXVolumeBox/SFXSlider
@onready var btn_resume = $Panel/MarginContainer/VBoxContainer/BtnResume
@onready var btn_restart = $Panel/MarginContainer/VBoxContainer/BtnRestart
@onready var btn_exit = $Panel/MarginContainer/VBoxContainer/BtnExit

var option_camera_mode: OptionButton

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Load current values from MusicManager
	music_slider.value = MusicManager.music_volume
	sfx_slider.value = MusicManager.sfx_volume
	_build_camera_option()
	
	# Connect signals
	music_slider.value_changed.connect(_on_music_value_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	btn_resume.pressed.connect(_on_resume_pressed)
	btn_restart.pressed.connect(_on_restart_pressed)
	btn_exit.pressed.connect(_on_exit_pressed)

func _build_camera_option() -> void:
	var settings_list = $Panel/MarginContainer/VBoxContainer/SettingsList
	var row = HBoxContainer.new()
	row.name = "CameraModeBox"
	settings_list.add_child(row)
	var lbl = Label.new()
	lbl.text = "Race Camera"
	lbl.custom_minimum_size = Vector2(160, 0)
	row.add_child(lbl)
	option_camera_mode = OptionButton.new()
	option_camera_mode.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option_camera_mode.add_item("Isometric")
	option_camera_mode.add_item("Follower")
	option_camera_mode.selected = 0 if MusicManager.use_isometric_camera else 1
	option_camera_mode.item_selected.connect(_on_camera_mode_selected)
	row.add_child(option_camera_mode)

func show_pause_menu():
	# Sync sliders
	music_slider.value = MusicManager.music_volume
	sfx_slider.value = MusicManager.sfx_volume
	if option_camera_mode:
		option_camera_mode.selected = 0 if MusicManager.use_isometric_camera else 1
	
	# Hide/show restart button based on game mode
	if NetworkManager.current_game_mode == NetworkManager.GameMode.MULTIPLAYER:
		btn_restart.hide()
	else:
		btn_restart.show()
	
	show()

func _on_music_value_changed(value: float):
	MusicManager.set_music_volume(value)

func _on_sfx_volume_changed(value: float):
	MusicManager.set_sfx_volume(value)

func _on_camera_mode_selected(index: int) -> void:
	MusicManager.set_use_isometric_camera(index == 0)

func _on_resume_pressed():
	hide()

func _on_restart_pressed():
	hide()
	var main = get_tree().current_scene
	if main and main.has_method("restart_race"):
		main.restart_race()

func _on_exit_pressed():
	hide()
	var main = get_tree().current_scene
	if main and main.has_method("_on_server_disconnected"):
		main._on_server_disconnected()
