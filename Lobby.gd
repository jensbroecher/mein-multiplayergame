extends Control

@onready var line_edit_name = $CenterContainer/VBoxContainer/LineEditName
@onready var button_host = $CenterContainer/VBoxContainer/ButtonHost
@onready var server_list = $CenterContainer/VBoxContainer/ServerList

var server_buttons = {}

func _ready():
	button_host.pressed.connect(_on_host_pressed)
	LANDiscovery.server_found.connect(_on_server_found)
	LANDiscovery.server_lost.connect(_on_server_lost)
	
	LANDiscovery.start_listening()
	
	# Load saved player name
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		var saved_name = config.get_value("player", "name", "")
		if not saved_name.is_empty():
			line_edit_name.text = saved_name
			
	visibility_changed.connect(_on_visibility_changed)
	line_edit_name.text_changed.connect(_save_player_name)

func _on_visibility_changed():
	if visible and line_edit_name:
		var config = ConfigFile.new()
		if config.load("user://settings.cfg") == OK:
			var saved_name = config.get_value("player", "name", "")
			if not saved_name.is_empty():
				line_edit_name.text = saved_name

func _save_player_name(p_name: String):
	var config = ConfigFile.new()
	config.load("user://settings.cfg") # Load existing if it exists
	config.set_value("player", "name", p_name)
	config.save("user://settings.cfg")


func _on_host_pressed():
	var p_name = line_edit_name.text
	if p_name.is_empty():
		p_name = "HostRacer"
	else:
		_save_player_name(p_name)
	
	var err = NetworkManager.create_server(p_name)
	if err == OK:
		start_game(true)

func _on_server_found(ip: String, info: Dictionary):
	if server_buttons.has(ip):
		return
		
	var btn = Button.new()
	var s_name = info.get("name", "Unknown")
	var s_port = info.get("port", NetworkManager.DEFAULT_PORT)
	btn.text = "Join " + s_name + " (" + ip + ")"
	
	# Godot 4 lambda binding issue can pop up if not careful, passing args through bind or inline capture
	btn.pressed.connect(func(): _on_join_pressed(ip, s_port))
	
	server_list.add_child(btn)
	server_buttons[ip] = btn

func _on_server_lost(ip: String):
	if server_buttons.has(ip):
		server_buttons[ip].queue_free()
		server_buttons.erase(ip)

func _on_join_pressed(ip: String, port: int):
	var p_name = line_edit_name.text
	if p_name.is_empty():
		p_name = "GuestRacer"
	else:
		_save_player_name(p_name)
		
	var err = NetworkManager.join_server(ip, port, p_name)
	if err == OK:
		start_game(false)

func start_game(is_host: bool):
	hide()
	var main = get_parent()
	if main and main.has_method("start_game"):
		main.start_game(is_host)
