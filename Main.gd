extends Node

const LEVEL_SCENE = preload("res://Level.tscn")
const CONFIGURATION_MENU_SCENE = preload("res://ConfigurationMenu.tscn")
const PAUSE_MENU_SCENE = preload("res://PauseMenu.tscn")

@onready var lobby = $Lobby
@onready var main_menu = $MainMenu
@onready var car_selection = $CarSelection

var configuration_menu
var pause_menu

func _ready():
	main_menu.start_pressed.connect(_on_menu_start_pressed)
	main_menu.options_pressed.connect(_on_menu_options_pressed)
	car_selection.car_selected.connect(_on_car_selected)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	
	configuration_menu = CONFIGURATION_MENU_SCENE.instantiate()
	configuration_menu.visible = false
	add_child(configuration_menu)
	configuration_menu.back_pressed.connect(func(): main_menu.show())
	
	pause_menu = PAUSE_MENU_SCENE.instantiate()
	pause_menu.visible = false
	add_child(pause_menu)

func _on_menu_start_pressed():
	car_selection.show()

func _on_menu_options_pressed():
	main_menu.hide()
	configuration_menu.show()

func _on_car_selected(car_index: int):
	NetworkManager.local_car_index = car_index
	if NetworkManager.current_game_mode == NetworkManager.GameMode.MULTIPLAYER:
		lobby.show()
	else:
		car_selection.hide()
		# Load saved player name
		var p_name = "SoloRacer"
		var config = ConfigFile.new()
		if config.load("user://settings.cfg") == OK:
			var saved_name = config.get_value("player", "name", "")
			if not saved_name.is_empty():
				p_name = saved_name
				
		NetworkManager.start_single_player(p_name)
		start_game(true)

func start_game(is_host: bool):
	if is_host:
		var level_scene = LEVEL_SCENE
		if NetworkManager.current_game_mode == NetworkManager.GameMode.SINGLE_PLAYER_GP:
			var gp_data = NetworkManager.GP_CUPS.get(NetworkManager.current_gp_name)
			if gp_data:
				var stage_idx = NetworkManager.current_gp_stage
				if stage_idx < gp_data["stages"].size():
					level_scene = load(gp_data["stages"][stage_idx])
		
		var level = level_scene.instantiate()
		add_child(level)
	# Clients will get the level spawned automatically by MultiplayerSpawner

func load_gp_stage(stage_idx: int):
	var level = get_node_or_null("Level")
	if level:
		level.name = "OldLevel"
		level.queue_free()
		await get_tree().process_frame
		
	var gp_data = NetworkManager.GP_CUPS.get(NetworkManager.current_gp_name)
	if gp_data and stage_idx < gp_data["stages"].size():
		NetworkManager.current_gp_stage = stage_idx
		var stage_path = gp_data["stages"][stage_idx]
		var next_level_scene = load(stage_path)
		var next_level = next_level_scene.instantiate()
		add_child(next_level)
	else:
		# GP Finished!
		_on_server_disconnected()


func _on_server_disconnected():
	var level = get_node_or_null("Level")
	if level:
		level.queue_free()
	
	NetworkManager.disconnect_peer()
	
	lobby.hide()
	car_selection.hide()
	main_menu.show()
	MusicManager.stop_music()

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		if has_node("Level"):
			if pause_menu.visible:
				pause_menu.hide()
			else:
				pause_menu.show_pause_menu()
			get_viewport().set_input_as_handled()

func restart_race():
	var level = get_node_or_null("Level")
	if level:
		level.name = "OldLevel"
		level.queue_free()
		await get_tree().process_frame
	
	start_game(true)

