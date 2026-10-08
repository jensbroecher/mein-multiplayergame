extends Control

signal start_pressed
signal options_pressed

## Dev jump-in for Grand Prix stages. Set false (or delete the tile) before shipping.
const SHOW_GP_TEST_MENU := true

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
const COL_SNOW := Color(0.45, 0.82, 0.98)
const COL_BEACH := Color(0.96, 0.78, 0.40)

## Every course's tile: title, one-line description, picture and accent colour.
const STAGE_INFO := {
	"res://levels/Level.tscn": {"title": "LAKESIDE COURSE", "subtitle": "Hills, lake, and the long bridge", "file": "tile_lakeside.jpg", "color": COL_LAKE},
	"res://levels/PinecrestRidgeLevel.tscn": {"title": "PINECREST RIDGE", "subtitle": "Forest hillclimb, sharp switchbacks, and big jumps", "file": "tile_pinecrest.jpg", "color": COL_GREEN},
	"res://levels/HarborPierLevel.tscn": {"title": "HARBOR PIER", "subtitle": "Piers, crates, and dark water", "file": "tile_harbor.jpg", "color": COL_HARBOR},
	"res://levels/BloombayDunesLevel.tscn": {"title": "BLOOMBAY DUNES", "subtitle": "Ocean coastline, rolling waves, and beach sand dunes", "file": "tile_bloombay_dunes.jpg", "color": COL_BEACH},
	"res://levels/FrostpeakCreekLevel.tscn": {"title": "FROSTPEAK CREEK", "subtitle": "Snow drifts, creek leaps, and the alpine bridge", "file": "tile_frostpeak_creek.jpg", "color": COL_SNOW},
	"res://levels/GlacierHighwayLevel.tscn": {"title": "GLACIER HIGHWAY", "subtitle": "Multi-tier concrete expressway, tunnels, and icy on-ramps", "file": "tile_glacier_highway.jpg", "color": COL_SNOW},
	"res://levels/NorthlightCavernsLevel.tscn": {"title": "NORTHLIGHT CAVERNS", "subtitle": "Night race under the aurora, through a glacier and over an ice arch", "file": "tile_northlight_caverns.jpg", "color": COL_SNOW},
	"res://levels/FrostfallGorgeLevel.tscn": {"title": "FROSTFALL GORGE", "subtitle": "Off-road along a river gorge: gully jumps, a frozen waterfall, and a mega-jump", "file": "tile_frostfall_gorge.jpg", "color": COL_SNOW},
	"res://levels/MountainLevel.tscn": {"title": "MOUNTAIN COURSE", "subtitle": "Dunes and high desert ridges", "file": "tile_mountain.jpg", "color": COL_MOUNTAIN},
	"res://levels/CanyonLevel.tscn": {"title": "CANYON COURSE", "subtitle": "Red rock walls and mesa turns", "file": "tile_canyon.jpg", "color": COL_CANYON},
	"res://levels/CanyonChasmLevel.tscn": {"title": "CANYON CHASM", "subtitle": "A narrow run over the drop", "file": "tile_canyon_chasm.jpg", "color": COL_CHASM},
	"res://levels/DesertWadiLevel.tscn": {"title": "DESERT WADI", "subtitle": "Dry riverbed sand and heat", "file": "tile_desert_wadi.jpg", "color": COL_WADI},
}
## Section header colour per cup on the course lists (same accents as the cup tiles).
const CUP_COLORS := {"Bloombay GP": COL_GREEN, "Arctic Cup": COL_SNOW, "Al-Raihana GP": COL_BRONZE}
## Tiles per row in a cup section: one cup per row.
const SECTION_COLUMNS := 4

@onready var name_edit: LineEdit = $Root/VBox/TopBar/NameBox/NameEdit
@onready var screen_title: Label = $Root/VBox/TopBar/TitleRow/ScreenTitle
@onready var screen_subtitle: Label = $Root/VBox/TopBar/TitleRow/ScreenSubtitle
@onready var extra_row: HBoxContainer = $Root/VBox/ExtraRow
@onready var tile_grid: GridContainer = $Root/VBox/TileScroll/TileGrid
@onready var btn_back: Button = $Root/VBox/Footer/BtnBack
@onready var btn_quit: Button = $Root/VBox/Footer/BtnQuit

var name_edit_p2: LineEdit
var current_screen: String = "main"
## Holds tile_grid on ordinary screens, and the per-cup sections on the course lists.
var tile_sections: VBoxContainer
var section_grids: Array[GridContainer] = []


func _ready() -> void:
	_style_chrome_buttons()
	_load_player_name()
	name_edit.text_changed.connect(_on_name_changed)
	btn_back.pressed.connect(_on_back_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	_create_coop_name_row()
	_create_tile_sections()
	visibility_changed.connect(_on_visibility_changed)
	resized.connect(_relayout_tiles)
	show_sub_menu("main")


## A ScrollContainer takes a single child, so tile_grid moves into a VBox that can also hold
## section headers and their grids.
func _create_tile_sections() -> void:
	var scroll: Control = tile_grid.get_parent()
	tile_sections = VBoxContainer.new()
	tile_sections.name = "TileSections"
	tile_sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_sections.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tile_sections.add_theme_constant_override("separation", 14)
	scroll.remove_child(tile_grid)
	scroll.add_child(tile_sections)
	tile_sections.add_child(tile_grid)


## Adds a titled section (header line plus its own tile grid) and returns the grid to fill.
func _add_section(title: String, accent: Color) -> GridContainer:
	tile_grid.visible = false
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	if not section_grids.is_empty():
		header.custom_minimum_size.y = 52
	header.alignment = BoxContainer.ALIGNMENT_BEGIN
	var lbl := Label.new()
	lbl.text = title.to_upper()
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", accent)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_END
	header.add_child(lbl)
	var line := ColorRect.new()
	line.color = Color(accent.r, accent.g, accent.b, 0.45)
	line.custom_minimum_size = Vector2(0, 3)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(line)
	tile_sections.add_child(header)
	var grid := GridContainer.new()
	grid.columns = SECTION_COLUMNS
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 22)
	tile_sections.add_child(grid)
	section_grids.append(grid)
	return grid


## Course list grouped by Grand Prix, in cup order, with any course outside a cup at the end.
## `on_pick` is called with the cup name ("" outside a cup), stage index and scene path.
func _fill_stages_by_cup(on_pick: Callable, numbered: bool) -> void:
	var listed := {}
	for cup_name in NetworkManager.GP_CUPS.keys():
		var stages: Array = NetworkManager.GP_CUPS[cup_name].get("stages", [])
		var grid := _add_section(str(cup_name), CUP_COLORS.get(cup_name, COL_GOLD))
		for i in range(stages.size()):
			var path: String = str(stages[i])
			listed[path] = true
			_add_stage_tile(grid, path, str(cup_name), i, stages.size(), on_pick, numbered)
	var others: Array = []
	for st in NetworkManager.ALL_STAGES:
		if not listed.has(st["path"]):
			others.append(st["path"])
	if not others.is_empty():
		var grid2 := _add_section("Other Courses", COL_GOLD)
		for path in others:
			_add_stage_tile(grid2, path, "", 0, 0, on_pick, false)


func _add_stage_tile(grid: GridContainer, path: String, cup_name: String, index: int, count: int,
		on_pick: Callable, numbered: bool) -> void:
	var info: Dictionary = STAGE_INFO.get(path, {"title": path.get_file().get_basename().to_upper(),
			"subtitle": "", "file": "tile_grand_prix.jpg", "color": COL_GOLD})
	var title: String = info["title"]
	var subtitle: String = info["subtitle"]
	if numbered:
		title = "%s  %d/%d" % [title, index + 1, count]
		subtitle = "%s  •  GP stage %d" % [cup_name, index + 1]
	_add_tile(title, subtitle, str(info["file"]), info["color"], func():
		on_pick.call(cup_name, index, path)
	, grid)


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
			if SHOW_GP_TEST_MENU:
				_add_tile("GP TEST", "Dev: play any GP stage with bots", "tile_grand_prix.jpg", COL_GOLD, func():
					show_sub_menu("gp_test")
				)
		"gp_test":
			screen_title.text = "GP TEST"
			screen_subtitle.text = "Dev jump-in: full GP rules (bots, grid, next stage). Hide with SHOW_GP_TEST_MENU."
			_fill_stages_by_cup(func(cup_name: String, stage_i: int, _path: String):
				_on_gp_test_stage_selected(cup_name, stage_i)
			, true)
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
			_add_tile("BLOOMBAY GP", "Lakeside  •  Pinecrest  •  Harbor  •  Bloombay Dunes", "tile_bloombay_gp.jpg", COL_GREEN, func():
				_on_cup_selected("Bloombay GP")
			)
			_add_tile("ARCTIC CUP", "Frostpeak  •  Glacier Highway  •  Northlight  •  Frostfall Gorge", "tile_arctic_cup.jpg", COL_SNOW, func():
				_on_cup_selected("Arctic Cup")
			)
			_add_tile("AL-RAIHANA GP", "Mountain  •  Canyon  •  Chasm  •  Wadi", "tile_al_raihana_gp.jpg", COL_BRONZE, func():
				_on_cup_selected("Al-Raihana GP")
			)
		"stage_select":
			if NetworkManager.current_game_mode == NetworkManager.GameMode.SPECTATOR:
				screen_title.text = "SPECTATOR"
				screen_subtitle.text = "Pick a course to watch — 6 AI racers, you stay off the grid"
			else:
				screen_title.text = "SELECT COURSE"
				screen_subtitle.text = "Pick a track to race"
			_fill_stages_by_cup(func(_cup: String, _i: int, path: String):
				_on_stage_selected(path)
			, false)
	call_deferred("_relayout_tiles")


func _relayout_tiles() -> void:
	if tile_grid == null or (tile_grid.get_child_count() == 0 and section_grids.is_empty()):
		return
	var scroll: Control = tile_grid.get_parent()
	var area: Vector2 = scroll.size
	if area.x < 8.0 or area.y < 8.0:
		return
	if not section_grids.is_empty():
		# Course lists: fixed-width rows, one cup per row, scrolling if they do not all fit.
		var sw: float = (area.x - 22.0 * float(SECTION_COLUMNS - 1) - 12.0) / float(SECTION_COLUMNS)
		var tile_size := Vector2(maxf(sw, 220.0), maxf(sw * 0.6, 170.0))
		for grid in section_grids:
			for tile in grid.get_children():
				(tile as Control).custom_minimum_size = tile_size
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
		"gp_test":
			show_sub_menu("main")
		_:
			show_sub_menu("main")


func _clear_tiles() -> void:
	for child in tile_grid.get_children():
		tile_grid.remove_child(child)
		child.queue_free()
	if tile_sections:
		for child in tile_sections.get_children():
			if child != tile_grid:
				tile_sections.remove_child(child)
				child.queue_free()
	section_grids.clear()
	tile_grid.visible = true


func _add_tile(title: String, subtitle: String, file_name: String, accent: Color, on_press: Callable,
		grid: GridContainer = null) -> void:
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
	(grid if grid else tile_grid).add_child(btn)


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


func _on_gp_test_stage_selected(cup_name: String, stage_idx: int) -> void:
	NetworkManager.current_game_mode = NetworkManager.GameMode.SINGLE_PLAYER_GP
	NetworkManager.is_coop_gp = false
	NetworkManager.current_gp_name = cup_name
	NetworkManager.current_gp_stage = stage_idx
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
