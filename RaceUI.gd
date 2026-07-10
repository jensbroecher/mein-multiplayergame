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
@onready var slot1_panel = $HUDPanel/ItemSlots/Slot1
@onready var slot1_icon = $HUDPanel/ItemSlots/Slot1/Icon
@onready var slot2_panel = $HUDPanel/ItemSlots/Slot2
@onready var slot2_icon = $HUDPanel/ItemSlots/Slot2/Icon
@onready var underwater_overlay = $UnderwaterOverlay
@onready var terrain_clip_overlay = $TerrainClipOverlay

func set_underwater(is_underwater: bool):
	if underwater_overlay:
		underwater_overlay.visible = is_underwater

func set_terrain_clipped(is_clipped: bool):
	if terrain_clip_overlay:
		terrain_clip_overlay.visible = is_clipped

@onready var end_panel = $EndPanel
@onready var end_timer_label = $EndPanel/VBoxContainer/LabelTimer

signal ready_pressed(is_ready: bool)
signal start_pressed()

var style_blue = StyleBoxFlat.new()
var style_orange = StyleBoxFlat.new()
var style_red = StyleBoxFlat.new()

var style_slot_empty = StyleBoxFlat.new()
var style_slot_active = StyleBoxFlat.new()
var style_slot_backup = StyleBoxFlat.new()

var ITEM_ICONS = {
	"BOOST": load("res://sprites/icon_boost.png"),
	"MISSILE": load("res://sprites/icon_missile.png"),
	"GUIDED_MISSILE": load("res://sprites/icon_guided_missile.png"),
	"SHIELD": load("res://sprites/icon_shield.png"),
	"SHOCKWAVE": load("res://sprites/icon_shockwave.png"),
	"BOMB": load("res://sprites/icon_bomb.png"),
	"LIGHTNING": load("res://sprites/icon_lightning.png")
}

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
		
	if slot1_panel: slot1_panel.add_theme_stylebox_override("panel", style_slot_empty)
	if slot2_panel: slot2_panel.add_theme_stylebox_override("panel", style_slot_empty)

func _init_styleboxes():
	for s in [style_blue, style_orange, style_red]:
		s.corner_radius_top_left = 4
		s.corner_radius_top_right = 4
		s.corner_radius_bottom_right = 4
		s.corner_radius_bottom_left = 4
	
	style_blue.bg_color = Color(0, 0.8, 1) # Cyan/Blue
	style_orange.bg_color = Color(1, 0.5, 0) # Orange
	style_red.bg_color = Color(1, 0, 0) # Red

	# Style for empty slots (transparent gray border)
	for s in [style_slot_empty, style_slot_active, style_slot_backup]:
		s.corner_radius_top_left = 8
		s.corner_radius_top_right = 8
		s.corner_radius_bottom_right = 8
		s.corner_radius_bottom_left = 8
		s.set_border_width_all(2)

	style_slot_empty.bg_color = Color(0.1, 0.1, 0.1, 0.4)
	style_slot_empty.border_color = Color(0.3, 0.3, 0.3, 0.5)

	# Style for active Slot 1 (thick gold border)
	style_slot_active.bg_color = Color(0.12, 0.12, 0.12, 0.75)
	style_slot_active.border_color = Color(1.0, 0.7, 0.0, 0.95)
	style_slot_active.set_border_width_all(3)

	# Style for backup Slot 2 (cyan border)
	style_slot_backup.bg_color = Color(0.1, 0.1, 0.1, 0.7)
	style_slot_backup.border_color = Color(0.0, 0.8, 1.0, 0.8)

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

func update_items(item1_name: String, item2_name: String):
	# Update Slot 1 (Active)
	if slot1_panel and slot1_icon:
		if item1_name == "NONE" or not ITEM_ICONS.has(item1_name):
			slot1_icon.texture = null
			slot1_panel.add_theme_stylebox_override("panel", style_slot_empty)
		else:
			slot1_icon.texture = ITEM_ICONS[item1_name]
			slot1_panel.add_theme_stylebox_override("panel", style_slot_active)

	# Update Slot 2 (Backup)
	if slot2_panel and slot2_icon:
		if item2_name == "NONE" or not ITEM_ICONS.has(item2_name):
			slot2_icon.texture = null
			slot2_panel.add_theme_stylebox_override("panel", style_slot_empty)
		else:
			slot2_icon.texture = ITEM_ICONS[item2_name]
			slot2_panel.add_theme_stylebox_override("panel", style_slot_backup)

func show_end_screen():
	end_panel.show()

func update_end_timer(time_left: int):
	end_timer_label.text = "Waiting for others: %d s" % time_left

func update_speed(val_kmh: float):
	if label_speed:
		label_speed.text = "%d KM/H" % int(val_kmh)


var results_container: VBoxContainer = null
var action_button: Button = null

func display_race_results(results_data: Array):
	show_end_screen()
	
	if NetworkManager.current_game_mode != NetworkManager.GameMode.MULTIPLAYER:
		end_timer_label.hide()
	
	var vbox = $EndPanel/VBoxContainer
	if results_container == null:
		results_container = VBoxContainer.new()
		results_container.add_theme_constant_override("separation", 8)
		vbox.add_child(results_container)
		vbox.move_child(results_container, 1)
	else:
		for child in results_container.get_children():
			child.queue_free()
			
	var header = HBoxContainer.new()
	header.custom_minimum_size = Vector2(400, 0)
	
	var h_pos = Label.new()
	h_pos.text = "POS"
	h_pos.custom_minimum_size = Vector2(50, 0)
	h_pos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(h_pos)
	
	var h_name = Label.new()
	h_name.text = "NAME"
	h_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(h_name)
	
	if NetworkManager.current_game_mode == NetworkManager.GameMode.SINGLE_PLAYER_GP:
		var h_pts = Label.new()
		h_pts.text = "PTS"
		h_pts.custom_minimum_size = Vector2(80, 0)
		h_pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		header.add_child(h_pts)
		
		var h_total = Label.new()
		h_total.text = "TOTAL"
		h_total.custom_minimum_size = Vector2(80, 0)
		h_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		header.add_child(h_total)
		
	results_container.add_child(header)
	
	var sep = HSeparator.new()
	results_container.add_child(sep)
	
	for r in results_data:
		var row = HBoxContainer.new()
		
		var r_pos = Label.new()
		r_pos.text = "%d" % r["pos"]
		r_pos.custom_minimum_size = Vector2(50, 0)
		r_pos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(r_pos)
		
		var r_name = Label.new()
		r_name.text = r["name"]
		r_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(r_name)
		
		if NetworkManager.current_game_mode == NetworkManager.GameMode.SINGLE_PLAYER_GP:
			var r_pts = Label.new()
			r_pts.text = "+%d" % r["round_points"]
			r_pts.custom_minimum_size = Vector2(80, 0)
			r_pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(r_pts)
			
			var r_total = Label.new()
			r_total.text = "%d" % r["total_points"]
			r_total.custom_minimum_size = Vector2(80, 0)
			r_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(r_total)
			
		results_container.add_child(row)
		
	if action_button == null:
		action_button = Button.new()
		action_button.custom_minimum_size = Vector2(0, 45)
		vbox.add_child(action_button)
		action_button.pressed.connect(_on_action_button_pressed)
		
	if NetworkManager.current_game_mode == NetworkManager.GameMode.SINGLE_PLAYER_GP:
		var gp_data = NetworkManager.GP_CUPS.get(NetworkManager.current_gp_name)
		var next_stage = NetworkManager.current_gp_stage + 1
		if gp_data and next_stage < gp_data["stages"].size():
			action_button.text = "NEXT STAGE"
		else:
			action_button.text = "FINISH GRAND PRIX"
	elif NetworkManager.current_game_mode == NetworkManager.GameMode.SINGLE_PLAYER_TIME_TRIAL:
		action_button.text = "RETURN TO MENU"
	else:
		action_button.text = "RETURN TO MENU"

func _on_action_button_pressed():
	if NetworkManager.current_game_mode == NetworkManager.GameMode.SINGLE_PLAYER_GP:
		var gp_data = NetworkManager.GP_CUPS.get(NetworkManager.current_gp_name)
		var next_stage = NetworkManager.current_gp_stage + 1
		if gp_data and next_stage < gp_data["stages"].size():
			var main = get_tree().current_scene
			if main and main.has_method("load_gp_stage"):
				main.load_gp_stage(next_stage)
				return
				
	var main = get_tree().current_scene
	if main and main.has_method("_on_server_disconnected"):
		main._on_server_disconnected()

