extends Control

signal start_pressed
signal options_pressed

const TILE_DIR := "res://images/menu/"

const COL_TEAL := Color(0.15, 0.75, 0.92)
const COL_ORANGE := Color(1.0, 0.55, 0.16)
const COL_MAGENTA := Color(0.86, 0.38, 0.86)
const COL_GOLD := Color(1.0, 0.78, 0.22)
const COL_CYAN := Color(0.25, 0.88, 0.92)
const COL_GREEN := Color(0.35, 0.82, 0.45)
const COL_BRONZE := Color(0.86, 0.58, 0.24)
const COL_LAKE := Color(0.28, 0.72, 0.55)
const COL_HARBOR := Color(0.18, 0.55, 0.78)
const COL_MOUNTAIN := Color(0.92, 0.68, 0.32)
const COL_CANYON := Color(0.92, 0.42, 0.22)
const COL_CHASM := Color(0.72, 0.28, 0.22)
const COL_WADI := Color(0.9, 0.74, 0.38)

@onready var name_edit: LineEdit = $Root/VBox/TopBar/NameBox/NameEdit
@onready var screen_title: Label = $Root/VBox/TopBar/TitleRow/ScreenTitle
@onready var screen_subtitle: Label = $Root/VBox/TopBar/TitleRow/ScreenSubtitle
@onready var extra_row: HBoxContainer = $Root/VBox/ExtraRow
@onready var tile_grid: GridContainer = $Root/VBox/TileScroll/TileGrid
@onready var btn_back: Button = $Root/VBox/Footer/BtnBack
@onready var btn_quit: Button = $Root/VBox/Footer/BtnQuit

var name_edit_p2: LineEdit
var current_screen: String = "main"


func _ready() -> void:
	_style_chrome_buttons()
	_load_player_name()
	name_edit.text_changed.connect(_on_name_changed)
	btn_back.pressed.connect(_on_back_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	_create_coop_name_row()
	visibility_changed.connect(_on_visibility_changed)
	resized.connect(_relayout_tiles)
	show_sub_menu("main")


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		if current_screen != "main":
			_on_back_pressed()
			get_viewport().set_input_as_handled()


func _on_visibility_changed() -> void:
	if visible:
		_load_player_name()
		if name_edit_p2:
			_load_p2_name()


func _load_player_name() -> void:
	var config := ConfigFile.new()
	var saved_name := "Player"
	if config.load("user://settings.cfg") == OK:
		saved_name = String(config.get_value("player", "name", "Player"))
	if name_edit:
		name_edit.text = saved_name


func _load_p2_name() -> void:
	var config := ConfigFile.new()
	var saved_name := "Player 2"
	if config.load("user://settings.cfg") == OK:
		saved_name = String(config.get_value("player", "name_p2", "Player 2"))
	name_edit_p2.text = saved_name
	NetworkManager.local_p2_name = saved_name


func _on_name_changed(new_name: String) -> void:
	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	config.set_value("player", "name", new_name)
	config.save("user://settings.cfg")


func _create_coop_name_row() -> void:
	var label := Label.new()
	label.text = "PLAYER 2 NAME"
	label.add_theme_color_override("font_color", COL_ORANGE)
	label.add_theme_font_size_override("font_size", 16)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	extra_row.add_child(label)

	name_edit_p2 = LineEdit.new()
	name_edit_p2.placeholder_text = "Enter Player 2 Name..."
	name_edit_p2.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_edit_p2.custom_minimum_size = Vector2(280, 44)
	name_edit_p2.max_length = 16
	name_edit_p2.add_theme_font_size_override("font_size", 20)
	name_edit_p2.text_changed.connect(_on_p2_name_changed)
	extra_row.add_child(name_edit_p2)
	_load_p2_name()


func _on_p2_name_changed(new_name: String) -> void:
	NetworkManager.local_p2_name = new_name
	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	config.set_value("player", "name_p2", new_name)
	config.save("user://settings.cfg")


func show_sub_menu(menu_name: String) -> void:
	current_screen = menu_name
	_clear_tiles()
	extra_row.visible = false
	btn_back.visible = menu_name != "main"
	btn_quit.visible = menu_name == "main"

	match menu_name:
		"main":
			screen_title.text = "SELECT MODE"
			screen_subtitle.text = "Choose how you want to race"
			tile_grid.columns = 2
			_add_tile("SINGLE PLAYER", "Grand Prix or Time Trial against the clock", "tile_single_player.jpg", COL_TEAL, func():
				NetworkManager.current_game_mode = NetworkManager.GameMode.SINGLE_PLAYER_TIME_TRIAL
				show_sub_menu("sp_modes")
			)
			_add_tile("SPLITSCREEN", "Two racers, one screen", "tile_splitscreen.jpg", COL_ORANGE, func():
				show_sub_menu("coop_config")
			)
			_add_tile("MULTIPLAYER", "Host or join a LAN race", "tile_multiplayer.jpg", COL_MAGENTA, _on_multiplayer_pressed)
			_add_tile("SPECTATOR", "Watch 6 AI racers — pick any course", "tile_grand_prix.jpg", COL_CYAN, func():
				NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
				show_sub_menu("stage_select")
			)
			_add_tile("OPTIONS", "Graphics, sound, and controls", "tile_options.jpg", COL_GOLD, _on_options_pressed)
		"sp_modes":
			screen_title.text = "SINGLE PLAYER"
			screen_subtitle.text = "Pick a championship or a single course"
			tile_grid.columns = 2
			_add_tile("GRAND PRIX", "Race a cup of tracks against bots", "tile_grand_prix.jpg", COL_GOLD, func():
				show_sub_menu("cup_select")
			)
			_add_tile("TIME TRIAL", "Solo laps on any course", "tile_time_trial.jpg", COL_CYAN, func():
				show_sub_menu("stage_select")
			)
		"coop_config":
			screen_title.text = "SPLITSCREEN"
			screen_subtitle.text = "Set Player 2's name, then pick a mode"
			extra_row.visible = true
			tile_grid.columns = 2
			_add_tile("GRAND PRIX", "Share a cup with bots in the field", "tile_grand_prix.jpg", COL_GOLD, _on_coop_gp_pressed)
			_add_tile("VS RACE", "Head-to-head on a single course", "tile_time_trial.jpg", COL_ORANGE, _on_coop_vs_pressed)
		"cup_select":
			screen_title.text = "SELECT CUP"
			screen_subtitle.text = "Each cup is a series of courses"
			tile_grid.columns = 2
			_add_tile("STARTER CUP", "Lakeside Course  •  Harbor Pier", "tile_starter_cup.jpg", COL_GREEN, func():
				_on_cup_selected("Starter Cup")
			)
			_add_tile("DESERT CUP", "Mountain  •  Canyon  •  Chasm  •  Wadi", "tile_desert_cup.jpg", COL_BRONZE, func():
				_on_cup_selected("Desert Cup")
			)
		"stage_select":
			if NetworkManager.current_game_mode == NetworkManager.GameMode.SPECTATOR:
				screen_title.text = "SPECTATOR"
				screen_subtitle.text = "Pick a course to watch — 6 AI racers, you stay off the grid"
			else:
				screen_title.text = "SELECT COURSE"
				screen_subtitle.text = "Pick a track to race"
			tile_grid.columns = 3
			_add_tile("LAKESIDE COURSE", "Hills, lake, and the long bridge", "tile_lakeside.jpg", COL_LAKE, func():
				_on_stage_selected("res://levels/Level.tscn")
			)
			_add_tile("HARBOR PIER", "Piers, crates, and dark water", "tile_harbor.jpg", COL_HARBOR, func():
				_on_stage_selected("res://levels/HarborPierLevel.tscn")
			)
			_add_tile("MOUNTAIN COURSE", "Dunes and high desert ridges", "tile_mountain.jpg", COL_MOUNTAIN, func():
				_on_stage_selected("res://levels/MountainLevel.tscn")
			)
			_add_tile("CANYON COURSE", "Red rock walls and mesa turns", "tile_canyon.jpg", COL_CANYON, func():
				_on_stage_selected("res://levels/CanyonLevel.tscn")
			)
			_add_tile("CANYON CHASM", "A narrow run over the drop", "tile_canyon_chasm.jpg", COL_CHASM, func():
				_on_stage_selected("res://levels/CanyonChasmLevel.tscn")
			)
			_add_tile("DESERT WADI", "Dry riverbed sand and heat", "tile_desert_wadi.jpg", COL_WADI, func():
				_on_stage_selected("res://levels/DesertWadiLevel.tscn")
			)
	call_deferred("_relayout_tiles")


func _relayout_tiles() -> void:
	if tile_grid == null or tile_grid.get_child_count() == 0:
		return
	var scroll: Control = tile_grid.get_parent()
	var area: Vector2 = scroll.size
	if area.x < 8.0 or area.y < 8.0:
		return
	var cols: int = max(tile_grid.columns, 1)
	var count: int = tile_grid.get_child_count()
	var rows: int = int(ceil(float(count) / float(cols)))
	var hsep: int = 22
	var vsep: int = 22
	var tw: float = (area.x - float(hsep * (cols - 1))) / float(cols)
	var th: float = (area.y - float(vsep * (rows - 1))) / float(rows)
	tw = maxf(tw, 280.0)
	th = maxf(th, 190.0)
	for child in tile_grid.get_children():
		if child is Control:
			(child as Control).custom_minimum_size = Vector2(tw, th)


func _on_back_pressed() -> void:
	match current_screen:
		"sp_modes":
			show_sub_menu("main")
		"coop_config":
			show_sub_menu("main")
		"cup_select":
			if NetworkManager.current_game_mode == NetworkManager.GameMode.LOCAL_COOP:
				show_sub_menu("coop_config")
			else:
				show_sub_menu("sp_modes")
		"stage_select":
			if NetworkManager.current_game_mode == NetworkManager.GameMode.LOCAL_COOP:
				show_sub_menu("coop_config")
			elif NetworkManager.current_game_mode == NetworkManager.GameMode.SPECTATOR:
				show_sub_menu("main")
			else:
				show_sub_menu("sp_modes")
		_:
			show_sub_menu("main")


func _clear_tiles() -> void:
	for child in tile_grid.get_children():
		tile_grid.remove_child(child)
		child.queue_free()


func _add_tile(title: String, subtitle: String, file_name: String, accent: Color, on_press: Callable) -> void:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(320, 220)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn.clip_contents = true
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.focus_mode = Control.FOCUS_ALL
	_apply_tile_styles(btn, accent)

	var tex := TextureRect.new()
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex.offset_left = 4
	tex.offset_top = 4
	tex.offset_right = -4
	tex.offset_bottom = -4
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex_path := TILE_DIR + file_name
	if ResourceLoader.exists(tex_path):
		tex.texture = load(tex_path)
	btn.add_child(tex)

	var fade := ColorRect.new()
	fade.color = Color(0.03, 0.035, 0.05, 0.78)
	fade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	fade.anchor_top = 0.52
	fade.offset_left = 4
	fade.offset_top = 0
	fade.offset_right = -4
	fade.offset_bottom = -4
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(fade)

	var accent_bar := ColorRect.new()
	accent_bar.color = accent
	accent_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	accent_bar.offset_left = 4
	accent_bar.offset_top = -8
	accent_bar.offset_right = -4
	accent_bar.offset_bottom = -4
	accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(accent_bar)

	var caption := VBoxContainer.new()
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_left = 18
	caption.offset_right = -18
	caption.offset_top = -96
	caption.offset_bottom = -16
	caption.add_theme_constant_override("separation", 2)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(caption)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 26)
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	title_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	title_lbl.add_theme_constant_override("shadow_offset_y", 2)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = subtitle
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_lbl.add_theme_font_size_override("font_size", 15)
	sub_lbl.add_theme_color_override("font_color", Color(0.86, 0.9, 0.94, 0.92))
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_child(sub_lbl)

	btn.pressed.connect(on_press)
	tile_grid.add_child(btn)


func _apply_tile_styles(btn: Button, accent: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.06, 0.07, 0.1, 1)
	normal.set_corner_radius_all(16)
	normal.set_border_width_all(3)
	normal.border_color = Color(accent.r, accent.g, accent.b, 0.5)
	normal.shadow_color = Color(0, 0, 0, 0.4)
	normal.shadow_size = 10
	normal.shadow_offset = Vector2(0, 5)
	normal.content_margin_left = 0
	normal.content_margin_top = 0
	normal.content_margin_right = 0
	normal.content_margin_bottom = 0

	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.border_color = accent
	hover.set_border_width_all(4)
	hover.shadow_color = Color(accent.r, accent.g, accent.b, 0.35)
	hover.shadow_size = 16

	var pressed: StyleBoxFlat = hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.04, 0.045, 0.06, 1)
	pressed.shadow_size = 4

	var focus: StyleBoxFlat = hover.duplicate() as StyleBoxFlat

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", focus)
	btn.add_theme_stylebox_override("disabled", normal)


func _style_chrome_buttons() -> void:
	for btn in [btn_back, btn_quit]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.14, 0.2, 1)
		sb.set_corner_radius_all(8)
		sb.set_border_width_all(2)
		sb.border_color = Color(0.28, 0.34, 0.44, 1)
		var hover: StyleBoxFlat = sb.duplicate() as StyleBoxFlat
		hover.border_color = COL_TEAL
		hover.bg_color = Color(0.16, 0.2, 0.28, 1)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", hover)
		btn.add_theme_stylebox_override("focus", hover)


func _on_multiplayer_pressed() -> void:
	NetworkManager.current_game_mode = NetworkManager.GameMode.MULTIPLAYER
	start_pressed.emit()
	hide()


func _on_stage_selected(stage_path: String) -> void:
	if NetworkManager.current_game_mode != NetworkManager.GameMode.LOCAL_COOP \
			and NetworkManager.current_game_mode != NetworkManager.GameMode.SPECTATOR:
		NetworkManager.current_game_mode = NetworkManager.GameMode.SINGLE_PLAYER_TIME_TRIAL
	NetworkManager.time_trial_stage = stage_path
	start_pressed.emit()
	hide()


func _on_cup_selected(cup_name: String) -> void:
	if NetworkManager.current_game_mode != NetworkManager.GameMode.LOCAL_COOP:
		NetworkManager.current_game_mode = NetworkManager.GameMode.SINGLE_PLAYER_GP
	NetworkManager.current_gp_name = cup_name
	NetworkManager.current_gp_stage = 0
	NetworkManager.gp_standings.clear()
	start_pressed.emit()
	hide()


func _on_coop_gp_pressed() -> void:
	NetworkManager.current_game_mode = NetworkManager.GameMode.LOCAL_COOP
	NetworkManager.is_coop_gp = true
	show_sub_menu("cup_select")


func _on_coop_vs_pressed() -> void:
	NetworkManager.current_game_mode = NetworkManager.GameMode.LOCAL_COOP
	NetworkManager.is_coop_gp = false
	show_sub_menu("stage_select")


func _on_options_pressed() -> void:
	options_pressed.emit()


func _on_quit_pressed() -> void:
	get_tree().quit()
