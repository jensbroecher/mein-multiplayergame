extends Control

signal back_pressed

@onready var music_slider = $Panel/MarginContainer/VBoxContainer/ScrollContainer/SettingsList/MusicVolumeBox/MusicSlider
@onready var sfx_slider = $Panel/MarginContainer/VBoxContainer/ScrollContainer/SettingsList/SFXVolumeBox/SFXSlider
@onready var check_fps = $Panel/MarginContainer/VBoxContainer/ScrollContainer/SettingsList/FPSBox/CheckFPS
@onready var option_window_mode = $Panel/MarginContainer/VBoxContainer/ScrollContainer/SettingsList/WindowModeBox/OptionWindowMode
@onready var check_vsync = $Panel/MarginContainer/VBoxContainer/ScrollContainer/SettingsList/VSyncBox/CheckVSync
@onready var btn_back = $Panel/MarginContainer/VBoxContainer/BtnBack

func _ready():
	# Configure option window mode items
	option_window_mode.clear()
	option_window_mode.add_item("Windowed")
	option_window_mode.add_item("Fullscreen")
	
	# Load current values from MusicManager
	music_slider.value = MusicManager.music_volume
	sfx_slider.value = MusicManager.sfx_volume
	check_fps.button_pressed = MusicManager.show_fps
	option_window_mode.selected = MusicManager.window_mode
	check_vsync.button_pressed = MusicManager.vsync
	
	# Connect signals
	music_slider.value_changed.connect(_on_music_value_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	check_fps.toggled.connect(_on_fps_toggled)
	option_window_mode.item_selected.connect(_on_window_mode_selected)
	check_vsync.toggled.connect(_on_vsync_toggled)
	btn_back.pressed.connect(_on_back_pressed)

func _on_music_value_changed(value: float):
	MusicManager.set_music_volume(value)

func _on_sfx_volume_changed(value: float):
	MusicManager.set_sfx_volume(value)

func _on_fps_toggled(toggled_val: bool):
	MusicManager.set_show_fps(toggled_val)

func _on_window_mode_selected(index: int):
	MusicManager.set_window_mode(index)

func _on_vsync_toggled(toggled_val: bool):
	MusicManager.set_vsync(toggled_val)

func _on_back_pressed():
	back_pressed.emit()
	hide()
