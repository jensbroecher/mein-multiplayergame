extends Node

const LEVEL_SCENE = preload("res://Level.tscn")

@onready var lobby = $Lobby
@onready var main_menu = $MainMenu
@onready var car_selection = $CarSelection
@onready var options_menu = $OptionsMenu

func _ready():
	main_menu.start_pressed.connect(_on_menu_start_pressed)
	main_menu.options_pressed.connect(_on_menu_options_pressed)
	car_selection.car_selected.connect(_on_car_selected)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)

func _on_menu_start_pressed():
	car_selection.show()

func _on_menu_options_pressed():
	options_menu.show()

func _on_car_selected(car_index: int):
	lobby.show()

func start_game(is_host: bool):
	if is_host:
		var level = LEVEL_SCENE.instantiate()
		add_child(level)
	# Clients will get the level spawned automatically by MultiplayerSpawner

func _on_server_disconnected():
	var level = get_node_or_null("Level")
	if level:
		level.queue_free()
	
	NetworkManager.disconnect_peer()
	
	lobby.hide()
	car_selection.hide()
	main_menu.show()

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		if options_menu.visible:
			options_menu.hide()
		else:
			options_menu.show()
		get_viewport().set_input_as_handled()

