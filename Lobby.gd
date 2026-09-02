extends Control

signal start_race_requested()
signal back_to_menu_requested()
signal change_car_requested()

@onready var connection_view = $ConnectionView
@onready var room_view = $RoomView

# Connection View controls
@onready var line_edit_name = $ConnectionView/Panel/Margin/VBox/NameRow/LineEditName
@onready var button_host = $ConnectionView/Panel/Margin/VBox/ButtonHost
@onready var line_edit_ip = $ConnectionView/Panel/Margin/VBox/DirectIPRow/LineEditIP
@onready var button_direct_join = $ConnectionView/Panel/Margin/VBox/DirectIPRow/ButtonDirectJoin
@onready var server_list = $ConnectionView/Panel/Margin/VBox/ScrollServers/ServerList
@onready var no_servers_label = $ConnectionView/Panel/Margin/VBox/ScrollServers/ServerList/NoServersLabel
@onready var button_back_menu = $ConnectionView/Panel/Margin/VBox/ButtonBackToMenu

# Room View controls
@onready var room_title = $RoomView/Panel/Margin/VBox/HeaderRow/RoomTitle
@onready var room_status = $RoomView/Panel/Margin/VBox/HeaderRow/RoomStatus
@onready var host_mode_controls = $RoomView/Panel/Margin/VBox/ModeSection/HostModeControls
@onready var option_mode = $RoomView/Panel/Margin/VBox/ModeSection/HostModeControls/OptionMode
@onready var option_cup = $RoomView/Panel/Margin/VBox/ModeSection/HostModeControls/OptionCup
@onready var client_mode_label = $RoomView/Panel/Margin/VBox/ModeSection/ClientModeLabel
@onready var label_count = $RoomView/Panel/Margin/VBox/PlayersHeader/LabelCount
@onready var player_list = $RoomView/Panel/Margin/VBox/ScrollPlayers/PlayerList
@onready var button_leave = $RoomView/Panel/Margin/VBox/ActionBar/ButtonLeave
@onready var button_change_car = $RoomView/Panel/Margin/VBox/ActionBar/ButtonChangeCar
@onready var button_ready = $RoomView/Panel/Margin/VBox/ActionBar/ButtonReady
@onready var button_start = $RoomView/Panel/Margin/VBox/ActionBar/ButtonStart

const CAR_NAMES = ["Viper", "Shadow", "Strikeforce", "Apex", "Interceptor", "Mudrunner", "Phantom", "Centurion"]

var server_buttons = {}
var is_in_room = false
var is_local_ready = false

func _ready():
	# Connection view connections
	button_host.pressed.connect(_on_host_pressed)
	button_direct_join.pressed.connect(_on_direct_join_pressed)
	button_back_menu.pressed.connect(_on_back_to_menu_pressed)
	
	# Room view connections
	button_leave.pressed.connect(_on_leave_room_pressed)
	button_change_car.pressed.connect(_on_change_car_pressed)
	button_ready.pressed.connect(_on_ready_pressed)
	button_start.pressed.connect(_on_start_race_pressed)
	
	option_mode.item_selected.connect(_on_mode_selected)
	option_cup.item_selected.connect(_on_cup_selected)
	
	_setup_mode_options()
	
	# LAN discovery
	LANDiscovery.server_found.connect(_on_server_found)
	LANDiscovery.server_lost.connect(_on_server_lost)
	LANDiscovery.start_listening()
	
	# NetworkManager signals
	NetworkManager.player_connected.connect(_on_player_list_changed)
	NetworkManager.player_disconnected.connect(_on_player_list_changed)
	NetworkManager.player_ready_changed.connect(_on_player_ready_changed)
	NetworkManager.player_car_changed.connect(_on_player_car_changed)
	NetworkManager.multiplayer_mode_changed.connect(_on_multiplayer_mode_changed)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	
	# Load saved player name
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		var saved_name = config.get_value("player", "name", "")
		if not saved_name.is_empty():
			line_edit_name.text = saved_name
			
	line_edit_name.text_changed.connect(_save_player_name)
	show_connection_view()

func _setup_mode_options():
	option_mode.clear()
	option_mode.add_item("Single Stages (Vote Next Track)", NetworkManager.MultiplayerMode.SINGLE_STAGES)
	option_mode.add_item("Full Grand Prix (Championship)", NetworkManager.MultiplayerMode.GRAND_PRIX)
	option_mode.select(0)
	
	option_cup.clear()
	var cup_idx = 0
	for cup_name in NetworkManager.GP_CUPS:
		option_cup.add_item(cup_name, cup_idx)
		cup_idx += 1
	option_cup.select(0)
	option_cup.visible = false

func show_connection_view():
	is_in_room = false
	connection_view.show()
	room_view.hide()
	is_local_ready = false

func enter_room_view():
	is_in_room = true
	connection_view.hide()
	room_view.show()
	
	var is_host = multiplayer.is_server()
	host_mode_controls.visible = is_host
	client_mode_label.visible = not is_host
	button_start.visible = is_host
	button_ready.visible = not is_host
	
	if is_host:
		room_title.text = "HOST LOBBY"
		room_status.text = "Hosting match"
		button_start.text = "START GRAND PRIX" if NetworkManager.multiplayer_mode == NetworkManager.MultiplayerMode.GRAND_PRIX else "START RACE"
	else:
		room_title.text = "RACE LOBBY"
		room_status.text = "Connected to Host"
		is_local_ready = false
		button_ready.text = "Ready"
		_update_client_mode_label()
		
	update_roster()

func _save_player_name(p_name: String):
	var config = ConfigFile.new()
	config.load("user://settings.cfg")
	config.set_value("player", "name", p_name)
	config.save("user://settings.cfg")

func _get_player_name() -> String:
	var p_name = line_edit_name.text.strip_edges()
	if p_name.is_empty():
		p_name = "Racer_%d" % (randi() % 900 + 100)
	_save_player_name(p_name)
	return p_name

func _on_host_pressed():
	var p_name = _get_player_name()
	var err = NetworkManager.create_server(p_name)
	if err == OK:
		enter_room_view()

func _on_direct_join_pressed():
	var ip = line_edit_ip.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	var p_name = _get_player_name()
	var err = NetworkManager.join_server(ip, NetworkManager.DEFAULT_PORT, p_name)
	if err == OK:
		enter_room_view()

func _on_server_found(ip: String, info: Dictionary):
	if server_buttons.has(ip):
		return
	if is_instance_valid(no_servers_label):
		no_servers_label.hide()
		
	var btn = Button.new()
	var s_name = info.get("name", "Unknown")
	var s_port = info.get("port", NetworkManager.DEFAULT_PORT)
	btn.text = "Join %s (%s)" % [s_name, ip]
	btn.custom_minimum_size = Vector2(0, 36)
	btn.pressed.connect(func(): _on_join_server(ip, s_port))
	
	server_list.add_child(btn)
	server_buttons[ip] = btn

func _on_server_lost(ip: String):
	if server_buttons.has(ip):
		server_buttons[ip].queue_free()
		server_buttons.erase(ip)
	if server_buttons.is_empty() and is_instance_valid(no_servers_label):
		no_servers_label.show()

func _on_join_server(ip: String, port: int):
	var p_name = _get_player_name()
	var err = NetworkManager.join_server(ip, port, p_name)
	if err == OK:
		enter_room_view()

func _on_back_to_menu_pressed():
	back_to_menu_requested.emit()

func _on_leave_room_pressed():
	NetworkManager.disconnect_peer()
	show_connection_view()

func _on_change_car_pressed():
	change_car_requested.emit()

func _on_ready_pressed():
	is_local_ready = not is_local_ready
	button_ready.text = "Cancel Ready" if is_local_ready else "Ready"
	NetworkManager.cmd_set_ready.rpc(is_local_ready)

func _on_start_race_pressed():
	if not multiplayer.is_server():
		return
	start_race_requested.emit()

func _on_mode_selected(index: int):
	var mode = option_mode.get_item_id(index)
	option_cup.visible = (mode == NetworkManager.MultiplayerMode.GRAND_PRIX)
	button_start.text = "START GRAND PRIX" if mode == NetworkManager.MultiplayerMode.GRAND_PRIX else "START RACE"
	var cup_name = option_cup.get_item_text(option_cup.selected)
	NetworkManager.set_multiplayer_mode(mode, cup_name)

func _on_cup_selected(index: int):
	var cup_name = option_cup.get_item_text(index)
	NetworkManager.set_multiplayer_mode(NetworkManager.multiplayer_mode, cup_name)

func _on_multiplayer_mode_changed(mode: int, cup_name: String):
	if multiplayer.is_server():
		return
	_update_client_mode_label()

func _update_client_mode_label():
	if NetworkManager.multiplayer_mode == NetworkManager.MultiplayerMode.GRAND_PRIX:
		client_mode_label.text = "Mode: Grand Prix - %s" % NetworkManager.selected_mp_cup
	else:
		client_mode_label.text = "Mode: Single Stages (Vote Next Track)"

func _on_player_list_changed(_id: int = 0, _info: Dictionary = {}):
	if is_in_room:
		update_roster()

func _on_player_ready_changed(_id: int, _is_ready: bool):
	if is_in_room:
		update_roster()

func _on_player_car_changed(_id: int, _car_index: int):
	if is_in_room:
		update_roster()

func _on_server_disconnected():
	show_connection_view()

func update_roster():
	for child in player_list.get_children():
		child.queue_free()
		
	var players = NetworkManager.players
	label_count.text = "%d / %d" % [players.size(), NetworkManager.MAX_CLIENTS]
	
	for id in players:
		var p = players[id]
		var p_name = str(p.get("name", "Racer"))
		var car_idx = int(p.get("car_index", 0))
		var is_ready = bool(p.get("ready", false))
		var is_host = (id == 1)
		
		var row = HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 36)
		row.add_theme_constant_override("separation", 10)
		
		# Host indicator
		if is_host:
			var crown = Label.new()
			crown.text = "👑"
			row.add_child(crown)
			
		# Player name
		var name_label = Label.new()
		name_label.text = p_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if id == (multiplayer.get_unique_id() if multiplayer.multiplayer_peer else 1):
			name_label.add_theme_color_override("font_color", Color(0.15, 0.75, 0.95))
		row.add_child(name_label)
		
		# Car name
		var car_name = CAR_NAMES[clampi(car_idx, 0, CAR_NAMES.size() - 1)]
		var car_label = Label.new()
		car_label.text = "🚗 " + car_name
		car_label.custom_minimum_size = Vector2(120, 0)
		car_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
		row.add_child(car_label)
		
		# Ready badge
		var ready_badge = Label.new()
		ready_badge.custom_minimum_size = Vector2(90, 0)
		ready_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if is_host:
			ready_badge.text = "[HOST]"
			ready_badge.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
		elif is_ready:
			ready_badge.text = "✔ READY"
			ready_badge.add_theme_color_override("font_color", Color(0.2, 0.85, 0.4))
		else:
			ready_badge.text = "⏳ WAITING"
			ready_badge.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
		row.add_child(ready_badge)
		
		player_list.add_child(row)
