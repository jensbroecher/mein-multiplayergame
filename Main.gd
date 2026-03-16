extends Node

const LEVEL_SCENE = preload("res://Level.tscn")

@onready var lobby = $Lobby
@onready var main_menu = $MainMenu

func _ready():
	main_menu.start_pressed.connect(_on_menu_start_pressed)

func _on_menu_start_pressed():
	lobby.show()

func start_game(is_host: bool):
	if is_host:
		var level = LEVEL_SCENE.instantiate()
		add_child(level)
	# Clients will get the level spawned automatically by MultiplayerSpawner
