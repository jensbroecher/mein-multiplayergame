extends CanvasLayer

@onready var lobby_panel = $LobbyPanel
@onready var player_list = $LobbyPanel/VBoxContainer/PlayerList
@onready var btn_ready = $LobbyPanel/VBoxContainer/ButtonReady
@onready var btn_start = $LobbyPanel/VBoxContainer/ButtonStart

@onready var hud_panel = $HUDPanel
@onready var label_pos = $HUDPanel/PositionContainer/LabelPosition
@onready var label_pos_total = $HUDPanel/PositionContainer/LabelPositionTotal
@onready var label_lap = $HUDPanel/LabelLap
@onready var label_msg = $HUDPanel/LabelMessage
@onready var label_speed = $HUDPanel/LabelSpeed
@onready var label_item = $HUDPanel/LabelItem
@onready var underwater_overlay = $UnderwaterOverlay

func set_underwater(is_underwater: bool):
	if underwater_overlay:
		underwater_overlay.visible = is_underwater

@onready var end_panel = $EndPanel
@onready var end_timer_label = $EndPanel/VBoxContainer/LabelTimer

signal ready_pressed(is_ready: bool)
signal start_pressed()

var style_blue = StyleBoxFlat.new()
var style_orange = StyleBoxFlat.new()
var style_red = StyleBoxFlat.new()

var laps_spinbox: SpinBox
var local_ready = false

func _ready():
	_init_styleboxes()
	_setup_lap_settings()
	
	NetworkManager.max_laps_changed.connect(_on_network_max_laps_changed)
	
	btn_ready.pressed.connect(_on_ready_pressed)
	btn_start.pressed.connect(_on_start_pressed)
	
	if not multiplayer.is_server():
		btn_start.hide()

func _init_styleboxes():
	for s in [style_blue, style_orange, style_red]:
		s.corner_radius_top_left = 4
		s.corner_radius_top_right = 4
		s.corner_radius_bottom_right = 4
		s.corner_radius_bottom_left = 4
	
	style_blue.bg_color = Color(0, 0.8, 1) # Cyan/Blue
	style_orange.bg_color = Color(1, 0.5, 0) # Orange
	style_red.bg_color = Color(1, 0, 0) # Red

func _setup_lap_settings():
	var laps_container = HBoxContainer.new()
	var label = Label.new()
	label.text = "Laps: "
	laps_container.add_child(label)
	
	laps_spinbox = SpinBox.new()
	laps_spinbox.min_value = 1
	laps_spinbox.max_value = 20
	laps_spinbox.value = NetworkManager.max_laps
	laps_spinbox.editable = multiplayer.is_server()
	laps_spinbox.value_changed.connect(_on_laps_changed)
	laps_container.add_child(laps_spinbox)
	
	$LobbyPanel/VBoxContainer.add_child(laps_container)
	# Place it after player list but before buttons
	# PlayerList is child 2 (0: Title, 1: HSep, 2: PlayerList)
	$LobbyPanel/VBoxContainer.move_child(laps_container, 3)

func _on_laps_changed(value: float):
	if multiplayer.is_server():
		NetworkManager.set_max_laps(int(value))

func _on_network_max_laps_changed(laps: int):
	if laps_spinbox:
		laps_spinbox.set_value_no_signal(laps)

func update_lobby(players: Dictionary):
	# Clear list
	for c in player_list.get_children():
		c.queue_free()
		
	var all_ready = true
	var count = 0
	for id in players:
		var info = players[id]
		var label = Label.new()
		var p_name = info.get("name", "Unknown")
		var is_ready = info.get("ready", false)
		label.text = p_name + (" (Ready)" if is_ready else " (Not Ready)")
		player_list.add_child(label)
		
		if not is_ready:
			all_ready = false
		count += 1
			
	if multiplayer.is_server():
		# Can only start if all ready and more than 0 players
		btn_start.disabled = not (all_ready and count > 0)

func _on_ready_pressed():
	local_ready = not local_ready
	btn_ready.text = "Unready" if local_ready else "Ready Up"
	ready_pressed.emit(local_ready)

func _on_start_pressed():
	start_pressed.emit()

func show_hud():
	lobby_panel.hide()
	hud_panel.show()

func update_hud(pos: int, total: int, lap: int, max_laps: int):
	label_pos.text = "%d" % pos
	label_pos_total.text = "/ %d" % total
	label_lap.text = "Lap: %d/%d" % [lap, max_laps]

func show_message(msg: String, duration: float = 0.0):
	label_msg.text = msg
	if duration > 0:
		var tw = create_tween()
		tw.tween_interval(duration)
		tw.tween_callback(func(): if label_msg.text == msg: label_msg.text = "")

func update_item(item_name: String):
	if label_item:
		label_item.text = "ITEM: " + item_name

func show_end_screen():
	end_panel.show()

func update_end_timer(time_left: int):
	end_timer_label.text = "Waiting for others: %d s" % time_left

func update_speed(val_kmh: float):
	if label_speed:
		label_speed.text = "%d KM/H" % int(val_kmh)
