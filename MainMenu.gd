extends Control

signal start_pressed

@onready var music_slider = $CenterContainer/VBoxContainer/MusicBox/MusicSlider
@onready var sfx_slider = $CenterContainer/VBoxContainer/SFXBox/SFXSlider
@onready var button_start = $CenterContainer/VBoxContainer/ButtonStart
@onready var button_quit = $CenterContainer/VBoxContainer/ButtonQuit

func _ready():
	button_start.pressed.connect(_on_start_pressed)
	button_quit.pressed.connect(_on_quit_pressed)
	
	# Sync UI with saved settings
	music_slider.value = MusicManager.music_volume
	sfx_slider.value = MusicManager.sfx_volume
	
	music_slider.value_changed.connect(_on_music_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)

func _on_start_pressed():
	start_pressed.emit()
	hide()

func _on_quit_pressed():
	get_tree().quit()

func _on_music_volume_changed(value: float):
	MusicManager.set_music_volume(value)

func _on_sfx_volume_changed(value: float):
	MusicManager.set_sfx_volume(value)
