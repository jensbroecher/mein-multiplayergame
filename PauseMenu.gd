extends Control

@onready var music_slider = $Panel/MarginContainer/VBoxContainer/SettingsList/MusicVolumeBox/MusicSlider
@onready var sfx_slider = $Panel/MarginContainer/VBoxContainer/SettingsList/SFXVolumeBox/SFXSlider
@onready var btn_resume = $Panel/MarginContainer/VBoxContainer/BtnResume
@onready var btn_restart = $Panel/MarginContainer/VBoxContainer/BtnRestart
@onready var btn_exit = $Panel/MarginContainer/VBoxContainer/BtnExit

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Load current values from MusicManager
	music_slider.value = MusicManager.music_volume
	sfx_slider.value = MusicManager.sfx_volume
	
	# Connect signals
	music_slider.value_changed.connect(_on_music_value_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	btn_resume.pressed.connect(_on_resume_pressed)
	btn_restart.pressed.connect(_on_restart_pressed)
	btn_exit.pressed.connect(_on_exit_pressed)

func show_pause_menu():
	# Sync sliders
	music_slider.value = MusicManager.music_volume
	sfx_slider.value = MusicManager.sfx_volume
	
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
