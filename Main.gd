extends Node

const LEVEL_SCENE = preload("res://Level.tscn")

@onready var lobby = $Lobby
@onready var main_menu = $MainMenu
@onready var car_selection = $CarSelection

func _ready():
	main_menu.start_pressed.connect(_on_menu_start_pressed)
	car_selection.car_selected.connect(_on_car_selected)

func _on_menu_start_pressed():
	car_selection.show()

func _on_car_selected(car_index: int):
	lobby.show()

func start_game(is_host: bool):
	if is_host:
		var level = LEVEL_SCENE.instantiate()
		add_child(level)
	# Clients will get the level spawned automatically by MultiplayerSpawner
