extends CanvasLayer

@onready var lobby_panel = $LobbyPanel
@onready var player_list = $LobbyPanel/VBoxContainer/PlayerList
@onready var btn_ready = $LobbyPanel/VBoxContainer/ButtonReady
@onready var btn_start = $LobbyPanel/VBoxContainer/ButtonStart

@onready var hud_panel = $HUDPanel
@onready var label_pos = $HUDPanel/LabelPosition
@onready var label_lap = $HUDPanel/LabelLap
@onready var label_msg = $HUDPanel/LabelMessage
@onready var heat_bar = $HUDPanel/HeatBar

@onready var end_panel = $EndPanel
@onready var end_timer_label = $EndPanel/VBoxContainer/LabelTimer

signal ready_pressed(is_ready: bool)
signal start_pressed()

var local_ready = false

func _ready():
	btn_ready.pressed.connect(_on_ready_pressed)
	btn_start.pressed.connect(_on_start_pressed)
	
	if not multiplayer.is_server():
		btn_start.hide()

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
	label_pos.text = "Pos: %d/%d" % [pos, total]
	label_lap.text = "Lap: %d/%d" % [lap, max_laps]

func show_message(msg: String, duration: float = 0.0):
	label_msg.text = msg
	if duration > 0:
		var tw = create_tween()
		tw.tween_interval(duration)
		tw.tween_callback(func(): if label_msg.text == msg: label_msg.text = "")

func update_heat(val: float):
	if heat_bar:
		heat_bar.value = val
		
		# Create a unique stylebox to avoid shared resource issues
		var style = StyleBoxFlat.new()
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_right = 4
		style.corner_radius_bottom_left = 4
		
		if val > 80:
			style.bg_color = Color(1, 0, 0) # Red
		elif val > 50:
			style.bg_color = Color(1, 0.5, 0) # Orange
		else:
			style.bg_color = Color(0, 0.8, 1) # Cyan/Blue
			
		heat_bar.add_theme_stylebox_override("fill", style)

func show_end_screen():
	end_panel.show()

func update_end_timer(time_left: int):
	end_timer_label.text = "Waiting for others: %d s" % time_left
