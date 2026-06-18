extends Control

signal start_pressed
signal options_pressed

@onready var button_start = $CenterContainer/VBoxContainer/ButtonStart
@onready var button_options = $CenterContainer/VBoxContainer/ButtonOptions
@onready var button_quit = $CenterContainer/VBoxContainer/ButtonQuit

func _ready():
	button_start.pressed.connect(_on_start_pressed)
	button_options.pressed.connect(_on_options_pressed)
	button_quit.pressed.connect(_on_quit_pressed)

func _on_start_pressed():
	start_pressed.emit()
	hide()

func _on_options_pressed():
	options_pressed.emit()

func _on_quit_pressed():
	get_tree().quit()

