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

## The camera feed's "signal lost" (SignalLostOverlay.gd), made on first use under the HUD: `signal_lost` runs the cut
## and returns when the cart should be moved (the static is up by then); `set_signal_weak` breaks the picture up a little.
const SignalLostOverlay = preload("res://SignalLostOverlay.gd")
var _signal_overlay: Control = null

func _signal_overlay_node() -> Control:
	if _signal_overlay == null:
		_signal_overlay = SignalLostOverlay.new()
		_signal_overlay.name = "SignalLost"
		add_child(_signal_overlay)
		move_child(_signal_overlay, 0)
	return _signal_overlay

func signal_lost(camera_label := "CAM 1") -> float:
	var o := _signal_overlay_node()
	o.set("camera_label", camera_label)
	o.call("cut")
	return SignalLostOverlay.RESPAWN_AT

func set_signal_weak(amount: float) -> void:
	if _signal_overlay == null and amount <= 0.0:
		return
	_signal_overlay_node().call("weak", amount)

func set_terrain_clipped(is_clipped: bool):
	_terrain_clip_target = 1.0 if is_clipped else 0.0
	if terrain_clip_overlay and not is_clipped and _terrain_clip_alpha <= 0.001:
		terrain_clip_overlay.visible = false

func _process(delta: float) -> void:
	_update_timing()
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
## The "RACE ENDING" countdown: a slim panel at the top of the screen, so the road stays visible.
## The score table (RACE FINISHED) is end_panel, in the middle, and only shows once the race is over.
@onready var end_countdown = $EndCountdown
@onready var end_countdown_label = $EndCountdown/HBoxContainer/LabelCount
## How far "You Finished!" and the other messages step down while the countdown is up.
const END_COUNTDOWN_MESSAGE_SHIFT := 72.0
var _msg_top: float = 0.0
var _msg_bottom: float = 0.0

var standings_panel: PanelContainer
var standings_list: VBoxContainer
var _standings_sig: String = ""
var killfeed_container: VBoxContainer

signal ready_pressed(is_ready: bool)
signal start_pressed()

var style_blue = StyleBoxFlat.new()
var style_orange = StyleBoxFlat.new()
var style_red = StyleBoxFlat.new()

var style_slot_empty = StyleBoxFlat.new()
var style_slot_active = StyleBoxFlat.new()
var style_slot_backup = StyleBoxFlat.new()

## The items' symbols (ItemSymbols.gd, drawn by ItemSymbolIcon.gd): the same white outlines the
## item boxes show, in the item slots and the kill feed.
const ItemSymbolIcon = preload("res://ItemSymbolIcon.gd")
## Fonts, outlines and the panels' look, shared with the pause menu (HudStyle.gd).
const HS = preload("res://HudStyle.gd")
const ItemSymbols = preload("res://ItemSymbols.gd")
var slot1_symbol: Control
var slot2_symbol: Control

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
	_setup_killfeed()
	_msg_top = label_msg.offset_top
	_msg_bottom = label_msg.offset_bottom
	_style_screens()

	NetworkManager.stage_votes_updated.connect(_on_stage_votes_updated)
	NetworkManager.stage_voting_concluded.connect(_on_stage_voting_concluded)
	NetworkManager.stage_voting_started.connect(_on_stage_voting_started)
	
	if lobby_panel:
		lobby_panel.hide()
	show_hud()
	
	if slot1_panel: slot1_panel.add_theme_stylebox_override("panel", style_slot_empty)
	if slot2_panel: slot2_panel.add_theme_stylebox_override("panel", style_slot_empty)
	slot1_symbol = _slot_symbol(slot1_icon)
	slot2_symbol = _slot_symbol(slot2_icon)


## An item symbol filling a slot's icon area, in place of the old pictures.
func _slot_symbol(icon: TextureRect) -> Control:
	if icon == null:
		return null
	icon.texture = null
	var sym := ItemSymbolIcon.new()
	sym.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.add_child(sym)
	return sym


func _item_symbol(item_name: String, side: float) -> Control:
	var sym := ItemSymbolIcon.new()
	sym.item = item_name
	sym.custom_minimum_size = Vector2(side, side)
	return sym

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

func update_hud(pos: int, total: int, lap: int, max_laps: int, progress: float = -1.0):
	if pos != _place_shown:
		_place_shown = pos
		label_pos.text = "%d" % pos
		var col: Color = PLACE_COLORS[pos - 1] if pos >= 1 and pos <= PLACE_COLORS.size() else Color.WHITE
		label_pos.add_theme_color_override("font_color", col)
		if _pos_suffix:
			_pos_suffix.text = _ordinal(pos)
			_pos_suffix.add_theme_color_override("font_color", col)
	label_pos_total.text = "/ %d" % total
	if max_laps <= 1:
		if progress >= 0.0:
			label_lap.text = "STAGE %d%%" % int(clampf(progress * 100.0, 0.0, 100.0))
		else:
			label_lap.text = "STAGE"
	else:
		label_lap.text = "LAP %d/%d" % [lap, max_laps]


## The HUD's place colours: gold, silver and bronze for the podium, white below it.
const PLACE_COLORS := [Color(1.0, 0.8, 0.25), Color(0.84, 0.88, 0.94), Color(0.93, 0.6, 0.32)]
var _place_shown := -1
var _pos_suffix: Label = null
## The speed in three fixed cells (Russo One's digits differ in width, and a right-aligned number jittered).
var _speed_digits: Array[Label] = []
var _speed_shown := -1
var _end_dim: ColorRect = null
var _end_buttons_sep: HSeparator = null


func _ordinal(n: int) -> String:
	if n % 100 >= 11 and n % 100 <= 13:
		return "TH"
	match n % 10:
		1: return "ST"
		2: return "ND"
		3: return "RD"
	return "TH"


## The race's look (HudStyle.gd): the theme on every screen, outlined display numbers over the 3D view, and the end
## panel dressed as the pause menu (its panel, a dim behind it, the title in the display font, separators).
func _style_screens() -> void:
	for c in [hud_panel, end_panel, end_countdown, lobby_panel]:
		if c:
			c.theme = HS.theme()
	# The place: the number with its ordinal beside it, "/ N" under them.
	var pc := label_pos.get_parent() as VBoxContainer
	pc.add_theme_constant_override("separation", -14)
	var row := HBoxContainer.new()
	row.name = "PlaceRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 3)
	pc.add_child(row)
	pc.move_child(row, 0)
	label_pos.reparent(row, false)
	HS.outline(label_pos, HS.display(), 76, 13)
	_pos_suffix = Label.new()
	_pos_suffix.name = "LabelOrdinal"
	_pos_suffix.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	HS.outline(_pos_suffix, HS.display(), 30, 8)
	var sup := MarginContainer.new()
	sup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sup.add_theme_constant_override("margin_top", 14)
	sup.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	sup.add_child(_pos_suffix)
	row.add_child(sup)
	HS.outline(label_pos_total, HS.bold(), 24, 7, Color(0.88, 0.91, 0.96))
	label_pos_total.text = "/ 1"
	_place_shown = -1
	update_hud(1, 1, 1, 3)
	HS.outline(label_lap, HS.bold(), 28, 8)
	HS.outline(label_msg, HS.display(), 36, 10)
	# The speed: three digit cells and the unit.
	label_speed.hide()
	var speedo := HBoxContainer.new()
	speedo.name = "Speedo"
	speedo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speedo.anchor_left = 1.0
	speedo.anchor_right = 1.0
	speedo.anchor_top = 1.0
	speedo.anchor_bottom = 1.0
	speedo.offset_left = -24.0
	speedo.offset_right = -24.0
	speedo.offset_top = -12.0
	speedo.offset_bottom = -12.0
	speedo.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	speedo.grow_vertical = Control.GROW_DIRECTION_BEGIN
	speedo.add_theme_constant_override("separation", 0)
	var size := 60
	var cell := ceilf(HS.display().get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x) + 2.0
	for i in 3:
		var d := Label.new()
		d.custom_minimum_size = Vector2(cell, 0)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		HS.outline(d, HS.display(), size, 12)
		speedo.add_child(d)
		_speed_digits.append(d)
	var unit := Label.new()
	unit.text = "KM/H"
	unit.size_flags_vertical = Control.SIZE_SHRINK_END
	HS.outline(unit, HS.bold(), 24, 7, Color(0.88, 0.91, 0.96))
	var um := MarginContainer.new()
	um.mouse_filter = Control.MOUSE_FILTER_IGNORE
	um.size_flags_vertical = Control.SIZE_SHRINK_END
	um.add_theme_constant_override("margin_left", 8)
	um.add_theme_constant_override("margin_bottom", 10)
	um.add_child(unit)
	speedo.add_child(um)
	hud_panel.add_child(speedo)
	update_speed(0.0)
	# The countdown's panel.
	var ending := end_countdown.get_node("HBoxContainer/LabelEnding") as Label
	ending.add_theme_font_override("font", HS.bold())
	end_countdown_label.add_theme_font_override("font", HS.display())
	end_countdown_label.add_theme_font_size_override("font_size", 64)
	# The end panel: the pause menu's panel and title, over a dim.
	end_panel.add_theme_stylebox_override("panel", HS.panel_style())
	var vb := end_panel.get_node("VBoxContainer") as VBoxContainer
	vb.add_theme_constant_override("separation", 15)
	var title := vb.get_node("LabelFinished") as Label
	HS.title(title)
	title.text = "RACE FINISHED"
	var sep := HSeparator.new()
	vb.add_child(sep)
	vb.move_child(sep, 1)
	_end_buttons_sep = HSeparator.new()
	vb.add_child(_end_buttons_sep)
	_end_buttons_sep.hide()
	_end_dim = ColorRect.new()
	_end_dim.name = "EndDim"
	_end_dim.color = Color(0.039, 0.039, 0.059, 0.5)
	_end_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_dim.visible = false
	add_child(_end_dim)
	move_child(_end_dim, end_panel.get_index())

func _setup_standings_list() -> void:
	if hud_panel == null:
		return
	standings_panel = PanelContainer.new()
	standings_panel.name = "StandingsPanel"
	standings_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	standings_panel.position = Vector2(16, 140)
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
		sig += "%s:%s:%s:%s|" % [str(r.get("pos", 0)), str(r.get("name", "")), str(r.get("finished", false)), str(r.get("dq", false))]
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
		pos_lbl.text = "DQ" if r.get("dq", false) else str(place)
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


func _setup_killfeed() -> void:
	if hud_panel == null:
		return
	killfeed_container = VBoxContainer.new()
	killfeed_container.name = "KillFeedContainer"
	killfeed_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	killfeed_container.anchors_preset = Control.PRESET_CENTER_TOP
	killfeed_container.anchor_left = 0.5
	killfeed_container.anchor_right = 0.5
	killfeed_container.offset_top = 64.0
	killfeed_container.offset_left = -260.0
	killfeed_container.offset_right = 260.0
	killfeed_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	killfeed_container.alignment = BoxContainer.ALIGNMENT_CENTER
	killfeed_container.add_theme_constant_override("separation", 6)
	hud_panel.add_child(killfeed_container)


func show_combat_notice(attacker_name: String, victim_name: String, attacker_id: int = 0, victim_id: int = 0, weapon: String = "") -> void:
	show_explosion_notice(attacker_name, victim_name, attacker_id, victim_id, weapon)


func show_explosion_notice(attacker_name: String, victim_name: String, attacker_id: int = 0, victim_id: int = 0, weapon: String = "") -> void:
	if hud_panel == null or killfeed_container == null:
		return
	
	# Is this HUD's own player involved? Only a human driven on this peer counts: in a single race every cart (the bots
	# too) holds the one RaceUI as its `race_ui`, so "the first cart whose race_ui is this" picked whichever came first
	# in the group, often a bot, and the feed called that bot "(YOU)". In split screen each player's RaceUI is injected.
	var my_id := 0
	var my_name := ""
	for c in get_tree().get_nodes_in_group("player_carts"):
		if c.get("is_ai") == true or c.get("is_local_player") != true:
			continue
		var injected = c.get("injected_race_ui")
		if injected != null and injected != self:
			continue
		my_id = c.name.to_int()
		if c.get("player_name"):
			my_name = str(c.get("player_name"))
		break

	# Ids decide; the name only when a notice came without them (a bot can share a human's name).
	var is_local_attacker := (attacker_id > 0 and attacker_id == my_id) or (attacker_id <= 0 and my_name != "" and attacker_name == my_name)
	var is_local_victim := (victim_id > 0 and victim_id == my_id) or (victim_id <= 0 and my_name != "" and victim_name == my_name)
	var is_self_blowup := (attacker_id == victim_id or attacker_id <= 0 or attacker_name == victim_name or attacker_name == "" or attacker_name == "Someone")
	
	var weapon_norm := weapon.to_upper().strip_edges()
	var is_lightning := (weapon_norm == "LIGHTNING")
	var is_guided := (weapon_norm == "GUIDED_MISSILE")
	var is_missile := (weapon_norm == "MISSILE")
	var is_bomb := (weapon_norm == "BOMB")

	# Cap active notices to avoid screen clutter
	while killfeed_container.get_child_count() >= 3:
		var oldest = killfeed_container.get_child(0)
		killfeed_container.remove_child(oldest)
		oldest.queue_free()
	
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	# Card Style - rich glassmorphism pill with glowing accent border
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.13, 0.90)
	style.set_corner_radius_all(10)
	style.set_border_width_all(1)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 6
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	
	if is_local_attacker:
		if is_lightning:
			# You zapped someone: Glowing Electric Cyan / Neon Arc
			style.border_color = Color(0.2, 0.95, 1.0, 0.95)
			style.shadow_color = Color(0.1, 0.8, 1.0, 0.35)
		else:
			# You scored an explosive hit: Neon Cyan glow
			style.border_color = Color(0.15, 0.85, 1.0, 0.95)
			style.shadow_color = Color(0.1, 0.7, 0.9, 0.3)
	elif is_local_victim:
		if is_lightning:
			# You got zapped: Shocking Golden Warning glow
			style.border_color = Color(1.0, 0.84, 0.2, 0.95)
			style.shadow_color = Color(0.9, 0.65, 0.1, 0.35)
		else:
			# You got blown up: Crimson Warning glow
			style.border_color = Color(1.0, 0.25, 0.2, 0.95)
			style.shadow_color = Color(0.9, 0.1, 0.1, 0.35)
	else:
		# Combat between other racers
		if is_lightning:
			# Electric blue arc
			style.border_color = Color(0.3, 0.75, 1.0, 0.85)
			style.shadow_color = Color(0.1, 0.45, 0.8, 0.25)
		elif is_guided:
			# High-tech targeting magenta / violet
			style.border_color = Color(0.8, 0.45, 1.0, 0.85)
			style.shadow_color = Color(0.55, 0.2, 0.8, 0.25)
		elif is_bomb:
			# Deep bomb ember
			style.border_color = Color(1.0, 0.38, 0.18, 0.85)
			style.shadow_color = Color(0.8, 0.2, 0.1, 0.25)
		else:
			# Classic missile / explosion orange
			style.border_color = Color(1.0, 0.52, 0.16, 0.8)
			style.shadow_color = Color(0.8, 0.35, 0.05, 0.2)
	
	card.add_theme_stylebox_override("panel", style)
	
	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 8)
	card.add_child(hbox)
	
	# 1. Leading Type Icon
	var icon_lbl := Label.new()
	if is_lightning:
		icon_lbl.text = "⚡"
	elif is_guided:
		icon_lbl.text = "🎯"
	elif is_missile:
		icon_lbl.text = "🚀"
	elif is_bomb:
		icon_lbl.text = "💣"
	else:
		icon_lbl.text = "💥"
	icon_lbl.add_theme_font_size_override("font_size", 16)
	hbox.add_child(icon_lbl)
	
	var _setup_label = func(lbl: Label, text: String, color: Color, size: int) -> void:
		lbl.text = text
		lbl.add_theme_font_size_override("font_size", size)
		lbl.modulate = color
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		lbl.add_theme_constant_override("shadow_offset_x", 1)
		lbl.add_theme_constant_override("shadow_offset_y", 1)
	
	if is_self_blowup:
		var name_lbl := Label.new()
		var n_text := victim_name + (" (YOU)" if is_local_victim else "")
		var n_col := Color(1.0, 0.4, 0.35) if is_local_victim else Color(1.0, 0.85, 0.45)
		_setup_label.call(name_lbl, n_text, n_col, 16)
		hbox.add_child(name_lbl)
		
		var badge_panel := PanelContainer.new()
		badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var b_style := StyleBoxFlat.new()
		b_style.bg_color = Color(1.0, 0.25, 0.15, 0.22)
		b_style.border_color = Color(1.0, 0.35, 0.2, 0.6)
		b_style.set_border_width_all(1)
		b_style.set_corner_radius_all(4)
		b_style.content_margin_left = 7
		b_style.content_margin_right = 7
		b_style.content_margin_top = 1
		b_style.content_margin_bottom = 1
		badge_panel.add_theme_stylebox_override("panel", b_style)

		var badge_hbox := HBoxContainer.new()
		badge_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_hbox.add_theme_constant_override("separation", 5)
		badge_panel.add_child(badge_hbox)

		if weapon_norm in ItemSymbols.NAMES:
			badge_hbox.add_child(_item_symbol(weapon_norm, 16.0))

		var badge := Label.new()
		var self_text := "BLEW THEMSELVES UP"
		if is_bomb:
			self_text = "SELF BOMB"
		elif is_missile or is_guided:
			self_text = "CAUGHT BLAST"
		_setup_label.call(badge, self_text, Color(1.0, 0.55, 0.3), 12)
		badge_hbox.add_child(badge)
		hbox.add_child(badge_panel)
	else:
		# Attacker label
		var atk_lbl := Label.new()
		var a_text := attacker_name + (" (YOU)" if is_local_attacker else "")
		var a_col := Color(0.2, 0.92, 1.0) if is_local_attacker else Color(0.95, 0.96, 1.0)
		_setup_label.call(atk_lbl, a_text, a_col, 16)
		hbox.add_child(atk_lbl)
		
		# Middle action badge: e.g. "MISSILE", "GUIDED MISSILE", "BOMB", "ZAPPED"
		var badge_panel := PanelContainer.new()
		badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var b_style := StyleBoxFlat.new()
		b_style.set_border_width_all(1)
		b_style.set_corner_radius_all(4)
		b_style.content_margin_left = 7
		b_style.content_margin_right = 7
		b_style.content_margin_top = 1
		b_style.content_margin_bottom = 1

		var action_text := "BLEW UP"
		var text_color := Color(1.0, 0.68, 0.22)

		if is_lightning:
			action_text = "ZAPPED"
			text_color = Color(0.35, 0.95, 1.0)
			b_style.bg_color = Color(0.1, 0.42, 0.7, 0.35)
			b_style.border_color = Color(0.3, 0.85, 1.0, 0.8)
		elif is_guided:
			action_text = "GUIDED MISSILE"
			text_color = Color(0.88, 0.6, 1.0)
			b_style.bg_color = Color(0.35, 0.12, 0.55, 0.35)
			b_style.border_color = Color(0.75, 0.45, 0.95, 0.8)
		elif is_missile:
			action_text = "MISSILE"
			text_color = Color(1.0, 0.72, 0.28)
			b_style.bg_color = Color(0.8, 0.32, 0.1, 0.3)
			b_style.border_color = Color(1.0, 0.55, 0.2, 0.8)
		elif is_bomb:
			action_text = "BOMB"
			text_color = Color(1.0, 0.42, 0.22)
			b_style.bg_color = Color(0.85, 0.18, 0.12, 0.32)
			b_style.border_color = Color(1.0, 0.35, 0.2, 0.8)
		else:
			b_style.bg_color = Color(1.0, 0.4, 0.1, 0.25)
			b_style.border_color = Color(1.0, 0.5, 0.15, 0.7)

		badge_panel.add_theme_stylebox_override("panel", b_style)

		var badge_hbox := HBoxContainer.new()
		badge_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_hbox.add_theme_constant_override("separation", 5)
		badge_panel.add_child(badge_hbox)

		if weapon_norm in ItemSymbols.NAMES:
			badge_hbox.add_child(_item_symbol(weapon_norm, 16.0))

		var badge_lbl := Label.new()
		_setup_label.call(badge_lbl, action_text, text_color, 12)
		badge_hbox.add_child(badge_lbl)
		hbox.add_child(badge_panel)
		
		# Victim label
		var vic_lbl := Label.new()
		var v_text := victim_name + (" (YOU)" if is_local_victim else "")
		var v_col := Color(1.0, 0.35, 0.35) if is_local_victim else Color(1.0, 0.85, 0.45)
		_setup_label.call(vic_lbl, v_text, v_col, 16)
		hbox.add_child(vic_lbl)
	
	killfeed_container.add_child(card)
	
	# Entrance animation: smooth scale bounce and alpha fade
	card.modulate.a = 0.0
	card.scale = Vector2(0.85, 0.85)
	card.pivot_offset = Vector2(card.size.x * 0.5, card.size.y * 0.5)
	
	var tw = card.create_tween().set_parallel(true)
	tw.tween_property(card, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Micro-shake effect if local player got blown up or zapped
	if is_local_victim:
		var shake_tw = card.create_tween()
		shake_tw.tween_property(card, "position:x", card.position.x + 6, 0.04)
		shake_tw.tween_property(card, "position:x", card.position.x - 5, 0.04)
		shake_tw.tween_property(card, "position:x", card.position.x + 3, 0.04)
		shake_tw.tween_property(card, "position:x", card.position.x, 0.04)
	
	# Exit animation after 2.8 seconds
	var exit_tw = card.create_tween()
	exit_tw.tween_interval(2.8)
	exit_tw.tween_property(card, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	exit_tw.parallel().tween_property(card, "position:y", card.position.y - 12, 0.25)
	exit_tw.tween_callback(card.queue_free)

func update_items(item1_name: String, item2_name: String):
	# Slot 1 (active), slot 2 (backup).
	for slot in [[slot1_panel, slot1_symbol, item1_name, style_slot_active], [slot2_panel, slot2_symbol, item2_name, style_slot_backup]]:
		if slot[0] == null or slot[1] == null:
			continue
		var held: bool = slot[2] in ItemSymbols.NAMES
		slot[1].item = slot[2] if held else ""
		slot[0].add_theme_stylebox_override("panel", slot[3] if held else style_slot_empty)

## The score table. It replaces the countdown.
func show_end_screen():
	hide_end_countdown()
	if _end_dim:
		_end_dim.show()
	end_panel.show()

## Seconds until the race is called, from the first finisher on. Shows the countdown.
func update_end_timer(time_left: int):
	if end_panel.visible:
		return
	end_countdown_label.text = "%d" % time_left
	if not end_countdown.visible:
		end_countdown.show()
		_shift_message(END_COUNTDOWN_MESSAGE_SHIFT)

func hide_end_countdown():
	if end_countdown.visible:
		end_countdown.hide()
		_shift_message(0.0)

func _shift_message(down: float) -> void:
	label_msg.offset_top = _msg_top + down
	label_msg.offset_bottom = _msg_bottom + down

func update_speed(val_kmh: float):
	var v := clampi(int(absf(val_kmh)), 0, 999)
	if v == _speed_shown:
		return
	_speed_shown = v
	if label_speed:
		label_speed.text = "%d KM/H" % v
	var s := str(v)
	for i in _speed_digits.size():
		var k := i - (_speed_digits.size() - s.length())
		_speed_digits[i].text = s[k] if k >= 0 else ""


var results_container: VBoxContainer = null
var action_button: Button = null
## Second end-screen button, shown under NEXT RACE outside multiplayer.
var menu_button: Button = null

func display_race_results(results_data: Array):
	show_end_screen()

	var is_gp: bool = NetworkManager.current_game_mode == NetworkManager.GameMode.SINGLE_PLAYER_GP \
			or (NetworkManager.current_game_mode == NetworkManager.GameMode.LOCAL_COOP and NetworkManager.is_coop_gp) \
			or (NetworkManager.current_game_mode == NetworkManager.GameMode.MULTIPLAYER and NetworkManager.multiplayer_mode == NetworkManager.MultiplayerMode.GRAND_PRIX)

	var is_arena: bool = not results_data.is_empty() and bool((results_data[0] as Dictionary).get("arena", false))
	var is_mp_single_stages: bool = NetworkManager.current_game_mode == NetworkManager.GameMode.MULTIPLAYER \
			and NetworkManager.multiplayer_mode == NetworkManager.MultiplayerMode.SINGLE_STAGES
	if is_arena:
		is_gp = false

	var vbox = $EndPanel/VBoxContainer
	if results_container == null:
		results_container = VBoxContainer.new()
		results_container.add_theme_constant_override("separation", 2)
		vbox.add_child(results_container)
		vbox.move_child(results_container, 2)
	else:
		for child in results_container.get_children():
			child.queue_free()
			
	if is_arena:
		_build_arena_results(results_data)
	elif NetworkManager.current_game_mode == NetworkManager.GameMode.SINGLE_PLAYER_TIME_TRIAL:
		_build_tt_results(results_data)
	else:
		var end_title := get_node_or_null("EndPanel/VBoxContainer/LabelFinished") as Label
		if end_title:
			end_title.text = "RACE FINISHED"
		_build_results_table(results_data, is_gp)

	# Post-race track voting for multiplayer single stages (not after an arena match):
	if is_mp_single_stages and not is_arena:
		_setup_track_voting_panel(vbox)
		
	if action_button == null:
		action_button = Button.new()
		action_button.custom_minimum_size = Vector2(0, 45)
		vbox.add_child(action_button)
		action_button.pressed.connect(_on_action_button_pressed)
		action_button.set_meta(&"ui_important", true)
	else:
		action_button.disabled = false
		vbox.move_child(action_button, vbox.get_child_count() - 1)
		
	if is_gp:
		var gp_name = NetworkManager.current_gp_name
		if gp_name.is_empty():
			gp_name = NetworkManager.selected_mp_cup
		var gp_data = NetworkManager.get_gp_cup(gp_name)
		var next_stage = NetworkManager.current_gp_stage + 1
		if multiplayer.is_server():
			if gp_data and next_stage < gp_data["stages"].size():
				action_button.text = "NEXT STAGE"
				action_button.disabled = false
			else:
				action_button.text = "TO THE PODIUM"
				action_button.disabled = false
		else:
			action_button.text = "WAITING FOR HOST..."
			action_button.disabled = true
	elif is_mp_single_stages:
		action_button.text = "RETURN TO LOBBY"
		action_button.disabled = false
	elif _is_offline_single_race():
		action_button.text = "PLAY AGAIN" if is_arena else "NEXT RACE"
		action_button.disabled = false
	else:
		action_button.text = "RETURN TO MENU"
		action_button.disabled = false

	if _is_offline_single_race():
		if menu_button == null:
			menu_button = Button.new()
			menu_button.custom_minimum_size = Vector2(0, 45)
			menu_button.text = "RETURN TO MENU"
			vbox.add_child(menu_button)
			menu_button.pressed.connect(_on_menu_button_pressed)
		menu_button.disabled = false
		menu_button.show()
		vbox.move_child(menu_button, vbox.get_child_count() - 1)
	elif menu_button != null:
		menu_button.hide()
	# A rule between the table (and the vote) and the buttons, as in the pause menu.
	if _end_buttons_sep:
		_end_buttons_sep.show()
		var at := action_button.get_index()
		if _end_buttons_sep.get_index() < at:
			at -= 1
		vbox.move_child(_end_buttons_sep, at)

## A one-course race outside multiplayer (time trial, splitscreen VS, spectator): the end screen
## offers the next course.
func _is_offline_single_race() -> bool:
	var mode: int = NetworkManager.current_game_mode
	return mode == NetworkManager.GameMode.SINGLE_PLAYER_TIME_TRIAL \
			or mode == NetworkManager.GameMode.SPECTATOR \
			or (mode == NetworkManager.GameMode.LOCAL_COOP and not NetworkManager.is_coop_gp)

func _on_menu_button_pressed():
	action_button.disabled = true
	menu_button.disabled = true
	var main = get_tree().current_scene
	if main and main.has_method("_on_server_disconnected"):
		main.call_deferred("_on_server_disconnected")

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
		var gp_data = NetworkManager.get_gp_cup(gp_name)
		var next_stage = NetworkManager.current_gp_stage + 1
		if gp_data and next_stage < gp_data["stages"].size():
			var main = get_tree().current_scene
			if main and main.has_method("load_gp_stage"):
				main.load_gp_stage(next_stage)
				return
		elif multiplayer.is_server():
			# GP finished: the podium ceremony, on every peer. Its Continue button goes on to the
			# lobby or the menu.
			NetworkManager.announce_gp_podium()
			return

	if _is_offline_single_race():
		if menu_button:
			menu_button.disabled = true
		var main_scene = get_tree().current_scene
		if main_scene and main_scene.has_method("restart_race"):
			# An arena game again on the same arena; after a race, the next course.
			if NetworkManager.arena.is_empty():
				NetworkManager.time_trial_stage = NetworkManager.get_next_course(NetworkManager.time_trial_stage)
			main_scene.restart_race()
			return

	var main = get_tree().current_scene
	if main and main.has_method("return_to_lobby") and NetworkManager.current_game_mode == NetworkManager.GameMode.MULTIPLAYER:
		main.call_deferred("return_to_lobby")
	elif main and main.has_method("_on_server_disconnected"):
		main.call_deferred("_on_server_disconnected")

func _input(event: InputEvent):
	var is_pause := event.is_action_pressed("ui_cancel")
	if not is_pause and event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_ESCAPE or key_event.physical_keycode == KEY_ESCAPE or key_event.key_label == KEY_ESCAPE \
				or key_event.keycode == KEY_BACKSPACE or key_event.physical_keycode == KEY_BACKSPACE or key_event.key_label == KEY_BACKSPACE \
				or key_event.keycode == KEY_BACK or key_event.physical_keycode == KEY_BACK or key_event.key_label == KEY_BACK:
			is_pause = true
	if is_pause:
		var main = get_tree().current_scene
		if main == null or not main.has_method("_input"):
			main = get_tree().root.get_node_or_null("Main")
		if main and main.has_method("_input"):
			main._input(event)



# ============================================================================================
#  The lap timer (Level.gd feeds it: timing_start at the green light, then a gate's split, a lap, the finish)
# ============================================================================================

const TTR = preload("res://TimeTrialRecords.gd")
const COL_T_TEXT := Color(0.93, 0.95, 0.98)
const COL_T_DIM := Color(0.62, 0.68, 0.76)
const COL_T_GOLD := Color(1.0, 0.8, 0.25)
const COL_T_FAST := Color(0.35, 0.95, 0.5)
const COL_T_SLOW := Color(1.0, 0.38, 0.32)
## How long a split or lap delta stays up (ms).
const T_DELTA_SHOW := 3500

var timing_panel: PanelContainer = null
var _t_clock: Label
var _t_delta: Label
var _t_tag: Label
var _t_rows := {}            # name -> value Label
var _t_running := false
var _t_finished := false
var _t_lap_start := 0        # ticks msec, this machine's clock
var _t_go := 0
var _t_cp_count := 0
var _t_laps := 1
var _t_tt := false
var _t_record := 0           # the stage's lap record (any mode)
var _t_best := 0             # this session's best clean lap
var _t_ref_lap := 0          # the lap the splits are against: the best of the record's and the session's
var _t_ref_splits: Array = []
var _t_best_run := 0         # time trial: the best run before this one
var _t_delta_until := 0
var _t_lap_times: Array = []
var _t_lap_clean: Array = []
var _t_total := 0


## The lights went green. `tt` is the time trial's records for the stage (TimeTrialRecords.stage), or empty.
func timing_start(cp_count: int, laps: int, record_ms: int, tt: Dictionary, is_tt: bool) -> void:
	_t_cp_count = cp_count
	_t_laps = maxi(1, laps)
	_t_tt = is_tt
	_t_record = record_ms
	_t_best = 0
	_t_ref_lap = 0
	_t_ref_splits = []
	_t_best_run = int(tt.get("run_ms", 0)) if int(tt.get("run_laps", 0)) == _t_laps else 0
	var tt_lap := int(tt.get("lap_ms", 0))
	var tt_splits: Array = tt.get("lap_splits", [])
	if tt_lap > 0 and tt_splits.size() == cp_count:
		_t_ref_lap = tt_lap
		_t_ref_splits = tt_splits.duplicate()
	_t_lap_times = []
	_t_lap_clean = []
	_t_total = 0
	_t_finished = false
	_t_go = Time.get_ticks_msec()
	_t_lap_start = _t_go
	_t_running = true
	_t_delta_until = 0
	_build_timing_panel()
	# Only a time trial shows the lap timer: in a Grand Prix or a single race the place matters, not the clock (the race
	# still times every lap, for the end screen and the records).
	timing_panel.visible = is_tt
	# One racer against the clock: no place to show.
	var pos_box := get_node_or_null("HUDPanel/PositionContainer") as Control
	if pos_box:
		pos_box.visible = not is_tt
	if standings_panel:
		standings_panel.visible = not is_tt
	_refresh_timing_rows()


## A gate counted, `split_ms` into the lap: its split against the reference lap's at that gate.
func timing_gate(cp_idx: int, split_ms: int) -> void:
	if cp_idx >= 0 and cp_idx < _t_ref_splits.size() and int(_t_ref_splits[cp_idx]) > 0:
		_show_delta(split_ms - int(_t_ref_splits[cp_idx]), "GATE %d" % (cp_idx + 1))


## A lap ended (the server's time for it). `splits` are its gates' times, the line's last.
func timing_lap(lap_ms: int, clean: bool, splits: Array) -> void:
	var now := Time.get_ticks_msec()
	_t_lap_start = now
	_t_lap_times.append(lap_ms)
	_t_lap_clean.append(clean)
	var tag := "LAP %d" % _t_lap_times.size() if _t_laps > 1 else "STAGE"
	if not clean:
		_show_delta_text("MISSED GATE", COL_T_SLOW, tag)
	elif _t_record <= 0 or lap_ms < _t_record:
		_show_delta_text("RECORD " + TTR.format_delta(lap_ms - _t_record) if _t_record > 0 else "LAP RECORD", COL_T_GOLD, tag)
	elif _t_ref_lap > 0:
		_show_delta(lap_ms - _t_ref_lap, tag)
	if clean:
		if _t_best <= 0 or lap_ms < _t_best:
			_t_best = lap_ms
		if _t_record <= 0 or lap_ms < _t_record:
			_t_record = lap_ms
		if (_t_ref_lap <= 0 or lap_ms < _t_ref_lap) and splits.size() == _t_cp_count and not splits.has(-1):
			_t_ref_lap = lap_ms
			_t_ref_splits = splits.duplicate()
	_refresh_timing_rows()


## The run is over: `total_ms` from the green light; `prev_best` the best run before it (time trial, 0 none).
func timing_finish(total_ms: int, prev_best: int, clean: bool) -> void:
	_t_running = false
	_t_finished = true
	_t_total = total_ms
	if _t_clock:
		_t_clock.text = TTR.format_ms(total_ms)
		_t_clock.modulate = COL_T_GOLD
	if _t_tt:
		var text := "FINISH  " + TTR.format_ms(total_ms)
		if clean and (prev_best <= 0 or total_ms < prev_best):
			_show_delta_text("BEST RUN" + ("  " + TTR.format_delta(total_ms - prev_best) if prev_best > 0 else ""), COL_T_GOLD, "RUN")
			text += "\nNEW BEST RUN!"
			_t_delta_until = Time.get_ticks_msec() + 600000
		elif prev_best > 0:
			_show_delta(total_ms - prev_best, "RUN")
			_t_delta_until = Time.get_ticks_msec() + 600000
		show_message(text, 6.0)
		if clean and (_t_best_run <= 0 or total_ms < _t_best_run):
			_t_best_run = total_ms
	_refresh_timing_rows()


func _show_delta(ms: int, tag: String) -> void:
	_show_delta_text(TTR.format_delta(ms), COL_T_FAST if ms < 0 else COL_T_SLOW, tag)


func _show_delta_text(text: String, col: Color, tag: String) -> void:
	if _t_delta == null:
		return
	_t_delta.text = text
	_t_delta.modulate = col
	_t_tag.text = tag
	_t_delta_until = Time.get_ticks_msec() + T_DELTA_SHOW


func _update_timing() -> void:
	if timing_panel == null or not timing_panel.visible:
		return
	var now := Time.get_ticks_msec()
	if _t_running:
		_t_clock.text = TTR.format_ms(maxi(1, now - _t_lap_start))
		if _t_rows.has("RUN"):
			(_t_rows["RUN"] as Label).text = TTR.format_ms(maxi(1, now - _t_go))
	var show := now < _t_delta_until
	_t_delta.visible = show
	_t_tag.visible = show


func _refresh_timing_rows() -> void:
	if timing_panel == null:
		return
	var last: int = int(_t_lap_times[-1]) if not _t_lap_times.is_empty() else 0
	_set_row("LAST", TTR.format_ms(last), COL_T_TEXT if _t_lap_clean.is_empty() or _t_lap_clean[-1] else COL_T_SLOW)
	_set_row("BEST", TTR.format_ms(_t_best), COL_T_FAST if _t_best > 0 and _t_best <= _t_record else COL_T_TEXT)
	_set_row("RECORD", TTR.format_ms(_t_record), COL_T_GOLD)
	if _t_rows.has("RUN") and _t_finished:
		_set_row("RUN", TTR.format_ms(_t_total), COL_T_GOLD)
	if _t_rows.has("BEST RUN"):
		_set_row("BEST RUN", TTR.format_ms(_t_best_run), COL_T_GOLD)


func _set_row(row_name: String, text: String, col: Color) -> void:
	if _t_rows.has(row_name):
		var l: Label = _t_rows[row_name]
		l.text = text
		l.modulate = col


func _timing_font() -> Font:
	# Titillium Web Bold: its digits are all one width, so the running clock doesn't jitter.
	return HS.bold()


func _build_timing_panel() -> void:
	if timing_panel != null:
		timing_panel.queue_free()
	_t_rows = {}
	var font := _timing_font()
	timing_panel = PanelContainer.new()
	timing_panel.name = "LapTimer"
	timing_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timing_panel.anchor_left = 1.0
	timing_panel.anchor_right = 1.0
	timing_panel.offset_left = -220.0
	timing_panel.offset_right = -20.0
	timing_panel.offset_top = 232.0
	timing_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.07, 0.58)
	style.border_color = Color(1.0, 0.7, 0.15, 0.32) if _t_tt else Color(0.0, 0.8, 1.0, 0.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 8
	timing_panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	timing_panel.add_child(box)
	var head := Label.new()
	head.text = "TIME TRIAL" if _t_tt else ("STAGE TIME" if _t_laps <= 1 else "LAP TIME")
	head.add_theme_font_size_override("font_size", 12)
	head.modulate = COL_T_GOLD if _t_tt else COL_T_DIM
	box.add_child(head)
	_t_clock = Label.new()
	_t_clock.text = TTR.format_ms(0)
	_t_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_t_clock.add_theme_font_override("font", font)
	_t_clock.add_theme_font_size_override("font_size", 34)
	_t_clock.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_t_clock.add_theme_constant_override("outline_size", 4)
	box.add_child(_t_clock)
	var drow := HBoxContainer.new()
	drow.custom_minimum_size = Vector2(0, 24)
	box.add_child(drow)
	_t_tag = Label.new()
	_t_tag.add_theme_font_size_override("font_size", 13)
	_t_tag.modulate = COL_T_DIM
	_t_tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_t_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	drow.add_child(_t_tag)
	_t_delta = Label.new()
	_t_delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_t_delta.add_theme_font_override("font", font)
	_t_delta.add_theme_font_size_override("font_size", 20)
	_t_delta.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_t_delta.add_theme_constant_override("outline_size", 3)
	drow.add_child(_t_delta)
	box.add_child(HSeparator.new())
	var rows: Array = ["LAST", "BEST", "RECORD"] if _t_laps > 1 else ["RECORD"]
	if _t_tt and _t_laps > 1:
		rows = ["RUN", "BEST RUN", "LAST", "BEST", "RECORD"]
	elif _t_tt:
		rows = ["BEST RUN"]
	for r in rows:
		var row := HBoxContainer.new()
		box.add_child(row)
		var k := Label.new()
		k.text = r
		k.add_theme_font_size_override("font_size", 13)
		k.modulate = COL_T_DIM
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(k)
		var v := Label.new()
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.add_theme_font_override("font", font)
		v.add_theme_font_size_override("font_size", 16)
		row.add_child(v)
		_t_rows[r] = v
	hud_panel.add_child(timing_panel)
	_t_delta.visible = false
	_t_tag.visible = false


func _results_label(text: String, width: float, align := HORIZONTAL_ALIGNMENT_RIGHT, col := Color(1, 1, 1, 1),
		size := 0, mono := false) -> Label:
	var l := Label.new()
	l.text = text
	if width > 0.0:
		l.custom_minimum_size = Vector2(width, 0)
	else:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.horizontal_alignment = align
	l.modulate = col
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	if mono:
		l.add_theme_font_override("font", _timing_font())
	return l


## The race's table: place, name, time (the winner's, then the gap), best lap, and in a Grand Prix the points.
func _build_results_table(results_data: Array, is_gp: bool) -> void:
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(640 if is_gp else 520, 0)
	header.add_child(_results_label("POS", 50, HORIZONTAL_ALIGNMENT_CENTER, COL_T_DIM))
	header.add_child(_results_label("NAME", 0, HORIZONTAL_ALIGNMENT_LEFT, COL_T_DIM))
	header.add_child(_results_label("TIME", 120, HORIZONTAL_ALIGNMENT_RIGHT, COL_T_DIM))
	header.add_child(_results_label("BEST LAP", 120, HORIZONTAL_ALIGNMENT_RIGHT, COL_T_DIM))
	if is_gp:
		header.add_child(_results_label("PTS", 60, HORIZONTAL_ALIGNMENT_RIGHT, COL_T_DIM))
		header.add_child(_results_label("TOTAL", 70, HORIZONTAL_ALIGNMENT_RIGHT, COL_T_DIM))
	results_container.add_child(header)
	results_container.add_child(HSeparator.new())

	var winner_ms := 0
	var fastest := 0
	for r in results_data:
		if int(r.get("time_ms", 0)) > 0 and not r.get("dq", false) and (winner_ms <= 0 or int(r["time_ms"]) < winner_ms):
			winner_ms = int(r["time_ms"])
		var b := _best_of(r.get("laps_ms", []))
		if b > 0 and (fastest <= 0 or b < fastest):
			fastest = b
	var me := multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 1
	for r in results_data:
		var row := HBoxContainer.new()
		var dq: bool = r.get("dq", false)
		var col := Color(1, 1, 1, 1)
		if not bool(r.get("is_bot", true)) and NetworkManager.players.has(me) and str(NetworkManager.players[me].get("name", "")) == str(r["name"]):
			col = COL_T_GOLD
		row.add_child(_results_label("DQ" if dq else "%d" % r["pos"], 50, HORIZONTAL_ALIGNMENT_CENTER, col))
		row.add_child(_results_label(str(r["name"]), 0, HORIZONTAL_ALIGNMENT_LEFT, col))
		var t := int(r.get("time_ms", 0))
		var t_text := "DQ" if dq else ("DNF" if t <= 0 else (TTR.format_ms(t) if t == winner_ms else TTR.format_delta(t - winner_ms)))
		row.add_child(_results_label(t_text, 120, HORIZONTAL_ALIGNMENT_RIGHT, col, 0, true))
		var b := _best_of(r.get("laps_ms", []))
		row.add_child(_results_label(TTR.format_ms(b) if b > 0 else "-", 120, HORIZONTAL_ALIGNMENT_RIGHT,
				COL_T_FAST if b > 0 and b == fastest else col, 0, true))
		if is_gp:
			row.add_child(_results_label("+%d" % r.get("round_points", 0), 60, HORIZONTAL_ALIGNMENT_RIGHT, col))
			row.add_child(_results_label("%d" % r.get("total_points", 0), 70, HORIZONTAL_ALIGNMENT_RIGHT, col))
		_add_result_row(row, results_container.get_child_count(), col == COL_T_GOLD)


## An arena match's table (ArenaGame.gd's results): place, name, team, the score and what earned it (goals or bases
## claimed), the winning team's line first in a team game.
func _build_arena_results(results_data: Array) -> void:
	var first: Dictionary = results_data[0]
	# An arena game is a match, not a race (the panel's title is otherwise RACE FINISHED).
	var title := get_node_or_null("EndPanel/VBoxContainer/LabelFinished") as Label
	if title:
		title.text = "MATCH FINISHED"
	if str(first.get("headline", "")) != "":
		var head := _results_label(str(first["headline"]), 0, HORIZONTAL_ALIGNMENT_CENTER, COL_T_GOLD)
		head.add_theme_font_size_override("font_size", 26)
		results_container.add_child(head)
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(600, 0)
	header.add_child(_results_label("POS", 50, HORIZONTAL_ALIGNMENT_CENTER, COL_T_DIM))
	header.add_child(_results_label("NAME", 0, HORIZONTAL_ALIGNMENT_LEFT, COL_T_DIM))
	header.add_child(_results_label("TEAM", 90, HORIZONTAL_ALIGNMENT_LEFT, COL_T_DIM))
	header.add_child(_results_label(str(first.get("stat_name", "GOALS")), 90, HORIZONTAL_ALIGNMENT_RIGHT, COL_T_DIM))
	header.add_child(_results_label("SCORE", 90, HORIZONTAL_ALIGNMENT_RIGHT, COL_T_DIM))
	results_container.add_child(header)
	results_container.add_child(HSeparator.new())
	var me := multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 1
	for r in results_data:
		var row := HBoxContainer.new()
		var col := Color(1, 1, 1, 1)
		if not bool(r.get("is_bot", true)) and NetworkManager.players.has(me) and str(NetworkManager.players[me].get("name", "")) == str(r["name"]):
			col = COL_T_GOLD
		var team_col: Color = r.get("team_color", Color(1, 1, 1))
		row.add_child(_results_label("%d" % int(r["pos"]), 50, HORIZONTAL_ALIGNMENT_CENTER, col))
		row.add_child(_results_label(str(r["name"]), 0, HORIZONTAL_ALIGNMENT_LEFT, col))
		row.add_child(_results_label(str(r.get("team_name", "")), 90, HORIZONTAL_ALIGNMENT_LEFT, team_col))
		row.add_child(_results_label("%d" % int(r.get("stat", 0)), 90, HORIZONTAL_ALIGNMENT_RIGHT, col, 0, true))
		row.add_child(_results_label("%d" % int(r.get("score", 0)), 90, HORIZONTAL_ALIGNMENT_RIGHT, col, 0, true))
		_add_result_row(row, results_container.get_child_count(), col == COL_T_GOLD)


## A table row on a faint stripe (every other row), the local player's row tinted gold.
func _add_result_row(row: HBoxContainer, index: int, mine: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.8, 0.25, 0.13) if mine else Color(1, 1, 1, 0.04 if index % 2 == 0 else 0.0)
	sb.set_corner_radius_all(5)
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	results_container.add_child(p)


func _best_of(laps: Array) -> int:
	var best := 0
	for v in laps:
		if int(v) > 0 and (best <= 0 or int(v) < best):
			best = int(v)
	return best


## A time trial's sheet: each lap (the fastest marked) and the total, against the stage's records as they are now.
func _build_tt_results(results_data: Array) -> void:
	var r: Dictionary = {}
	for row in results_data:
		if not bool(row.get("is_bot", false)):
			r = row
			break
	if r.is_empty() and not results_data.is_empty():
		r = results_data[0]
	var stage_path: String = NetworkManager.time_trial_stage
	var stage_name := stage_path.get_file().get_basename()
	for st in NetworkManager.ALL_STAGES:
		if st["path"] == stage_path:
			stage_name = st["name"]
	var title := get_node_or_null("EndPanel/VBoxContainer/LabelFinished") as Label
	if title:
		title.text = "TIME TRIAL · %s" % stage_name.to_upper()
	var key := TTR.key_of(stage_path)
	var rec: Dictionary = TTR.stage(key)
	var cfg := ConfigFile.new()
	cfg.load("user://lap_records.cfg")
	var lap_record := int(cfg.get_value("records", key, 0))

	var laps: Array = r.get("laps_ms", [])
	var total := int(r.get("time_ms", 0))
	var best := _best_of(laps)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(460, 0)
	box.add_theme_constant_override("separation", 4)
	results_container.add_child(box)
	if bool(r.get("dq", false)):
		box.add_child(_results_label("DISQUALIFIED: two gates missed in a row", 0, HORIZONTAL_ALIGNMENT_CENTER, COL_T_SLOW, 20))
	if laps.size() > 1:
		for i in laps.size():
			var row := HBoxContainer.new()
			var v := int(laps[i])
			row.add_child(_results_label("LAP %d" % (i + 1), 90, HORIZONTAL_ALIGNMENT_LEFT, COL_T_DIM, 20))
			row.add_child(_results_label(TTR.format_ms(v), 0, HORIZONTAL_ALIGNMENT_RIGHT,
					COL_T_FAST if v == best else Color(1, 1, 1, 1), 22, true))
			var note := ""
			if v == best and v > 0 and v <= lap_record:
				note = "LAP RECORD"
			elif v == best:
				note = "FASTEST"
			row.add_child(_results_label(note, 130, HORIZONTAL_ALIGNMENT_RIGHT, COL_T_GOLD if note == "LAP RECORD" else COL_T_FAST, 14))
			box.add_child(row)
		box.add_child(HSeparator.new())
	var trow := HBoxContainer.new()
	trow.add_child(_results_label("TOTAL", 90, HORIZONTAL_ALIGNMENT_LEFT, COL_T_GOLD, 22))
	trow.add_child(_results_label(TTR.format_ms(total) if total > 0 else "DNF", 0, HORIZONTAL_ALIGNMENT_RIGHT, COL_T_GOLD, 30, true))
	var prev := int(r.get("prev_run_ms", 0))
	var tnote := ""
	var tcol := COL_T_DIM
	if total > 0 and not bool(r.get("run_clean", true)):
		tnote = "GATE MISSED"
		tcol = COL_T_SLOW
	elif total > 0 and (prev <= 0 or total < prev):
		tnote = "NEW BEST RUN" + ("\n" + TTR.format_delta(total - prev) if prev > 0 else "")
		tcol = COL_T_GOLD
	elif total > 0 and prev > 0:
		tnote = TTR.format_delta(total - prev) + "\nVS BEST RUN"
		tcol = COL_T_SLOW
	trow.add_child(_results_label(tnote, 130, HORIZONTAL_ALIGNMENT_RIGHT, tcol, 14))
	box.add_child(trow)
	box.add_child(HSeparator.new())
	var recs := HBoxContainer.new()
	recs.add_child(_results_label("BEST RUN  %s" % TTR.format_ms(int(rec["run_ms"])), 0, HORIZONTAL_ALIGNMENT_LEFT, COL_T_DIM, 15, true))
	recs.add_child(_results_label("LAP RECORD  %s" % TTR.format_ms(lap_record), 0, HORIZONTAL_ALIGNMENT_RIGHT, COL_T_DIM, 15, true))
	box.add_child(recs)
	var runs := int(rec["runs"])
	var sub := "%d RUN%s ON THIS STAGE  ·  RECORDS IN THE HEADQUARTERS' HALL OF FAME" % [runs, "" if runs == 1 else "S"]
	box.add_child(_results_label(sub, 0, HORIZONTAL_ALIGNMENT_CENTER, Color(COL_T_DIM, 0.75), 12))
