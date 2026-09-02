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

## Soft darken when camera is deep under terrain — lerped to avoid black-screen flashes.
var _terrain_clip_target: float = 0.0
var _terrain_clip_alpha: float = 0.0
const _TERRAIN_CLIP_MAX_ALPHA: float = 0.35
const _TERRAIN_CLIP_FADE_SPEED: float = 4.0

func set_underwater(is_underwater: bool):
	if underwater_overlay:
		underwater_overlay.visible = is_underwater

func set_terrain_clipped(is_clipped: bool):
	_terrain_clip_target = 1.0 if is_clipped else 0.0
	if terrain_clip_overlay and not is_clipped and _terrain_clip_alpha <= 0.001:
		terrain_clip_overlay.visible = false

func _process(delta: float) -> void:
	if terrain_clip_overlay == null:
		return
	if absf(_terrain_clip_alpha - _terrain_clip_target) < 0.001 and _terrain_clip_target <= 0.0:
		if terrain_clip_overlay.visible:
			terrain_clip_overlay.visible = false
		return
	_terrain_clip_alpha = move_toward(_terrain_clip_alpha, _terrain_clip_target, _TERRAIN_CLIP_FADE_SPEED * delta)
	if _terrain_clip_alpha <= 0.001:
		_terrain_clip_alpha = 0.0
		terrain_clip_overlay.visible = false
	else:
		terrain_clip_overlay.visible = true
		# Soft darken, never full opaque black (that caused hard flashes)
		terrain_clip_overlay.color = Color(0.02, 0.03, 0.04, _terrain_clip_alpha * _TERRAIN_CLIP_MAX_ALPHA)

@onready var end_panel = $EndPanel
@onready var end_timer_label = $EndPanel/VBoxContainer/LabelTimer

var standings_panel: PanelContainer
var standings_list: VBoxContainer
var _standings_sig: String = ""

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

var voting_panel: PanelContainer = null
var voting_timer_label: Label = null
var vote_buttons: Dictionary = {}
var vote_timer_seconds: int = 15
var local_vote_choice: String = ""
var _is_voting_ticking: bool = false
var local_ready = false

func _ready():
	_init_styleboxes()
	_setup_standings_list()
	
	NetworkManager.stage_votes_updated.connect(_on_stage_votes_updated)
	NetworkManager.stage_voting_concluded.connect(_on_stage_voting_concluded)
	NetworkManager.stage_voting_started.connect(_on_stage_voting_started)
	
	if lobby_panel:
		lobby_panel.hide()
	show_hud()
	
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

func _setup_standings_list() -> void:
	if hud_panel == null:
		return
	standings_panel = PanelContainer.new()
	standings_panel.name = "StandingsPanel"
	standings_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	standings_panel.position = Vector2(16, 126)
	standings_panel.custom_minimum_size = Vector2(196, 0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.07, 0.58)
	style.border_color = Color(0.0, 0.8, 1.0, 0.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	standings_panel.add_theme_stylebox_override("panel", style)

	standings_list = VBoxContainer.new()
	standings_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	standings_list.add_theme_constant_override("separation", 1)
	standings_panel.add_child(standings_list)
	hud_panel.add_child(standings_panel)

func update_standings(rows: Array, highlight_id: int = 0) -> void:
	if standings_list == null:
		return
	var sig := "%d|" % highlight_id
	for r in rows:
		sig += "%s:%s:%s|" % [str(r.get("pos", 0)), str(r.get("name", "")), str(r.get("finished", false))]
	if sig == _standings_sig:
		return
	_standings_sig = sig

	var needed: int = rows.size()
	while standings_list.get_child_count() > needed:
		var extra = standings_list.get_child(standings_list.get_child_count() - 1)
		standings_list.remove_child(extra)
		extra.queue_free()
	while standings_list.get_child_count() < needed:
		standings_list.add_child(_make_standings_row())

	for i in range(needed):
		var r: Dictionary = rows[i]
		var row: HBoxContainer = standings_list.get_child(i)
		var pos_lbl: Label = row.get_child(0)
		var name_lbl: Label = row.get_child(1)
		var place: int = int(r.get("pos", i + 1))
		var r_name: String = str(r.get("name", "Racer"))
		if r_name.length() > 14:
			r_name = r_name.substr(0, 13) + "."
		pos_lbl.text = str(place)
		name_lbl.text = r_name

		var is_you: bool = int(r.get("id", 0)) == highlight_id
		var finished: bool = bool(r.get("finished", false))
		var col := Color(0.92, 0.94, 0.96, 0.92)
		if is_you:
			col = Color(1.0, 0.82, 0.2, 1.0)
		elif finished:
			col = Color(0.7, 0.78, 0.82, 0.7)
		elif place == 1:
			col = Color(0.55, 0.92, 1.0, 0.95)
		pos_lbl.modulate = col
		name_lbl.modulate = col

func _make_standings_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)

	var pos_lbl := Label.new()
	pos_lbl.custom_minimum_size = Vector2(22, 0)
	pos_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pos_lbl.add_theme_font_size_override("font_size", 14)
	row.add_child(pos_lbl)

	var name_lbl := Label.new()
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name_lbl)
	return row

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
	
	end_timer_label.hide()
	
	var is_gp: bool = NetworkManager.current_game_mode == NetworkManager.GameMode.SINGLE_PLAYER_GP \
			or (NetworkManager.current_game_mode == NetworkManager.GameMode.LOCAL_COOP and NetworkManager.is_coop_gp) \
			or (NetworkManager.current_game_mode == NetworkManager.GameMode.MULTIPLAYER and NetworkManager.multiplayer_mode == NetworkManager.MultiplayerMode.GRAND_PRIX)

	var is_mp_single_stages: bool = NetworkManager.current_game_mode == NetworkManager.GameMode.MULTIPLAYER \
			and NetworkManager.multiplayer_mode == NetworkManager.MultiplayerMode.SINGLE_STAGES

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
	
	if is_gp:
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
		
		if is_gp:
			var r_pts = Label.new()
			r_pts.text = "+%d" % r.get("round_points", 0)
			r_pts.custom_minimum_size = Vector2(80, 0)
			r_pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(r_pts)
			
			var r_total = Label.new()
			r_total.text = "%d" % r.get("total_points", 0)
			r_total.custom_minimum_size = Vector2(80, 0)
			r_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(r_total)
			
		results_container.add_child(row)
		
	# Post-race track voting for multiplayer single stages:
	if is_mp_single_stages:
		_setup_track_voting_panel(vbox)
		
	if action_button == null:
		action_button = Button.new()
		action_button.custom_minimum_size = Vector2(0, 45)
		vbox.add_child(action_button)
		action_button.pressed.connect(_on_action_button_pressed)
	else:
		action_button.disabled = false
		vbox.move_child(action_button, vbox.get_child_count() - 1)
		
	if is_gp:
		var gp_name = NetworkManager.current_gp_name
		if gp_name.is_empty():
			gp_name = NetworkManager.selected_mp_cup
		var gp_data = NetworkManager.GP_CUPS.get(gp_name)
		var next_stage = NetworkManager.current_gp_stage + 1
		if multiplayer.is_server():
			if gp_data and next_stage < gp_data["stages"].size():
				action_button.text = "NEXT STAGE"
				action_button.disabled = false
			else:
				action_button.text = "FINISH GRAND PRIX"
				action_button.disabled = false
		else:
			action_button.text = "WAITING FOR HOST..."
			action_button.disabled = true
	elif is_mp_single_stages:
		action_button.text = "RETURN TO LOBBY"
		action_button.disabled = false
	elif NetworkManager.current_game_mode == NetworkManager.GameMode.SINGLE_PLAYER_TIME_TRIAL:
		action_button.text = "RETURN TO MENU"
		action_button.disabled = false
	else:
		action_button.text = "RETURN TO MENU"
		action_button.disabled = false

func _setup_track_voting_panel(vbox: VBoxContainer):
	if voting_panel != null:
		voting_panel.queue_free()
		voting_panel = null
	vote_buttons.clear()
	local_vote_choice = ""
	
	voting_panel = PanelContainer.new()
	voting_panel.custom_minimum_size = Vector2(460, 0)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.95)
	style.border_color = Color(0.15, 0.72, 0.92, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	voting_panel.add_theme_stylebox_override("panel", style)
	
	var panel_vbox = VBoxContainer.new()
	panel_vbox.add_theme_constant_override("separation", 8)
	voting_panel.add_child(panel_vbox)
	
	voting_timer_label = Label.new()
	voting_timer_label.text = "VOTE FOR NEXT TRACK (15s)"
	voting_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	voting_timer_label.add_theme_font_size_override("font_size", 16)
	voting_timer_label.add_theme_color_override("font_color", Color(0.2, 0.85, 0.95))
	panel_vbox.add_child(voting_timer_label)
	
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	panel_vbox.add_child(grid)
	
	for stage in NetworkManager.ALL_STAGES:
		var stg_path: String = stage["path"]
		var stg_name: String = stage["name"]
		var btn = Button.new()
		btn.text = "%s (0)" % stg_name
		btn.custom_minimum_size = Vector2(210, 34)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func(): _on_vote_button_pressed(stg_path))
		grid.add_child(btn)
		vote_buttons[stg_path] = btn
		
	var btn_rand = Button.new()
	btn_rand.text = "🎲 Random Track (0)"
	btn_rand.custom_minimum_size = Vector2(210, 34)
	btn_rand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_rand.pressed.connect(func(): _on_vote_button_pressed("random"))
	grid.add_child(btn_rand)
	vote_buttons["random"] = btn_rand
	
	vbox.add_child(voting_panel)
	vbox.move_child(voting_panel, vbox.get_child_count() - 2)
	
	if multiplayer.is_server():
		NetworkManager.start_stage_voting()

func _on_stage_voting_started():
	vote_timer_seconds = 15
	if not _is_voting_ticking:
		_start_voting_countdown()

func _start_voting_countdown():
	_is_voting_ticking = true
	_tick_voting_timer()

func _tick_voting_timer():
	if not is_instance_valid(voting_timer_label):
		_is_voting_ticking = false
		return
	voting_timer_label.text = "VOTE FOR NEXT TRACK (%d s)" % vote_timer_seconds
	if vote_timer_seconds <= 0:
		_is_voting_ticking = false
		if multiplayer.is_server():
			NetworkManager.resolve_and_launch_voted_stage()
		return
	await get_tree().create_timer(1.0).timeout
	vote_timer_seconds -= 1
	_tick_voting_timer()

func _on_vote_button_pressed(choice: String):
	local_vote_choice = choice
	NetworkManager.vote_stage(choice)
	_refresh_vote_button_styles()

func _on_stage_votes_updated(votes: Dictionary):
	var counts: Dictionary = {}
	for p_id in votes:
		var c = str(votes[p_id])
		counts[c] = counts.get(c, 0) + 1
		
	for stg_path in vote_buttons:
		var btn: Button = vote_buttons[stg_path]
		var count = counts.get(stg_path, 0)
		var base_title = "🎲 Random Track" if stg_path == "random" else _get_stage_name(stg_path)
		btn.text = "%s (%d)" % [base_title, count]
		
	_refresh_vote_button_styles()

func _get_stage_name(stage_path: String) -> String:
	for s in NetworkManager.ALL_STAGES:
		if s["path"] == stage_path:
			return s["name"]
	return "Track"

func _refresh_vote_button_styles():
	for choice in vote_buttons:
		var btn: Button = vote_buttons[choice]
		if choice == local_vote_choice:
			btn.add_theme_color_override("font_color", Color(0.15, 0.9, 1.0))
		else:
			btn.remove_theme_color_override("font_color")

func _on_stage_voting_concluded(winning_stage: String):
	var stage_name = _get_stage_name(winning_stage)
	if is_instance_valid(voting_timer_label):
		voting_timer_label.text = "NEXT TRACK: %s! LOADING..." % stage_name.to_upper()
		voting_timer_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	for choice in vote_buttons:
		var btn: Button = vote_buttons[choice]
		btn.disabled = true

func _on_action_button_pressed():
	if action_button:
		action_button.disabled = true

	var is_gp = NetworkManager.current_game_mode == NetworkManager.GameMode.SINGLE_PLAYER_GP \
			or (NetworkManager.current_game_mode == NetworkManager.GameMode.LOCAL_COOP and NetworkManager.is_coop_gp) \
			or (NetworkManager.current_game_mode == NetworkManager.GameMode.MULTIPLAYER and NetworkManager.multiplayer_mode == NetworkManager.MultiplayerMode.GRAND_PRIX)

	if is_gp:
		var gp_name = NetworkManager.current_gp_name
		if gp_name.is_empty():
			gp_name = NetworkManager.selected_mp_cup
		var gp_data = NetworkManager.GP_CUPS.get(gp_name)
		var next_stage = NetworkManager.current_gp_stage + 1
		if gp_data and next_stage < gp_data["stages"].size():
			var main = get_tree().current_scene
			if main and main.has_method("load_gp_stage"):
				main.load_gp_stage(next_stage)
				return
		else:
			# GP Finished: return to lobby
			var main = get_tree().current_scene
			if main and main.has_method("return_to_lobby"):
				main.return_to_lobby()
				return

	var main = get_tree().current_scene
	if main and main.has_method("return_to_lobby") and NetworkManager.current_game_mode == NetworkManager.GameMode.MULTIPLAYER:
		main.call_deferred("return_to_lobby")
	elif main and main.has_method("_on_server_disconnected"):
		main.call_deferred("_on_server_disconnected")

func _input(event: InputEvent):
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		var main = get_tree().current_scene
		if main and main.has_method("_input"):
			main._input(event)

