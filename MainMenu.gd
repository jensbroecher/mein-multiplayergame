extends Control

## Both leave the menu on screen: Main swipes to the next screen and hides this one behind it.
signal start_pressed
signal options_pressed
signal garage_pressed
signal quit_pressed

## Dev jump-in for Grand Prix stages. Set false (or delete the tile) before shipping.
const SHOW_GP_TEST_MENU := true

const TILE_DIR := "res://images/menu/"
## A page's tiles cascade in (`_cascade_in`) and the last page fades out (`_fade_out`); seconds and pixels.
const CASCADE_STEP := 0.06
const CASCADE_SPAN := 0.6
const CASCADE_FADE := 0.32
const CASCADE_MOVE := 0.42
const CASCADE_RISE := 18.0
const FADE_OUT_TIME := 0.16
const FADE_OUT_RISE := 10.0
## The tile frame's corners (`_apply_tile_styles`) and its picture's, 4px inside it.
const TILE_RADIUS := 16
const TILE_INNER_RADIUS := 12
const MenuTileStage = preload("res://MenuTileStage.gd")
const MenuTileDrift = preload("res://MenuTileDrift.gd")

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
const COL_FREIGHT := Color(0.86, 0.62, 0.20)
const COL_WADI := Color(0.9, 0.74, 0.38)
const COL_SNOW := Color(0.45, 0.82, 0.98)
const COL_BEACH := Color(0.96, 0.78, 0.40)
const COL_SAVANNA := Color(0.95, 0.47, 0.22)
const COL_JUNGLE := Color(0.32, 0.80, 0.42)
const COL_KRONBURG := Color(0.88, 0.36, 0.26)
const COL_MIYOSHINO := Color(0.98, 0.62, 0.74)
const COL_YUNHAI := Color(0.95, 0.30, 0.78)

## Every course's tile: title, one-line description, picture and accent colour.
const STAGE_INFO := {
	"res://levels/LakesideLevel.tscn": {"title": "LAKESIDE MEADOWS", "subtitle": "Hills, lake, and the long bridge", "file": "tile_lakeside.jpg", "color": COL_LAKE},
	"res://levels/PinecrestRidgeLevel.tscn": {"title": "PINECREST RIDGE", "subtitle": "Forest hillclimb, sharp switchbacks, and big jumps", "file": "tile_pinecrest.jpg", "color": COL_GREEN},
	"res://levels/HarborPierLevel.tscn": {"title": "HARBOR PIER", "subtitle": "Piers, crates, and dark water", "file": "tile_harbor.jpg", "color": COL_HARBOR},
	"res://levels/BloombayDunesLevel.tscn": {"title": "SOUTH BEACH", "subtitle": "Ocean coastline, rolling waves, and beach sand dunes", "file": "tile_bloombay_dunes.jpg", "color": COL_BEACH},
	"res://levels/FrostpeakCreekLevel.tscn": {"title": "FROSTPEAK CREEK", "subtitle": "Snow drifts, creek leaps, and the alpine bridge", "file": "tile_frostpeak_creek.jpg", "color": COL_SNOW},
	"res://levels/GlacierHighwayLevel.tscn": {"title": "GLACIER HIGHWAY", "subtitle": "Multi-tier concrete expressway, tunnels, and icy on-ramps", "file": "tile_glacier_highway.jpg", "color": COL_SNOW},
	"res://levels/NorthlightCavernsLevel.tscn": {"title": "NORTHLIGHT CAVERNS", "subtitle": "Night race under the aurora, through a glacier and over an ice arch", "file": "tile_northlight_caverns.jpg", "color": COL_SNOW},
	"res://levels/FrostfallGorgeLevel.tscn": {"title": "FROSTFALL GORGE", "subtitle": "Off-road along a river gorge: gully jumps, a frozen waterfall, and a mega-jump", "file": "tile_frostfall_gorge.jpg", "color": COL_SNOW},
	"res://levels/MountainLevel.tscn": {"title": "JEBEL SAHAR", "subtitle": "A lamplit road spirals up the jebel past watchtowers to the fort on the summit, then plunges back to the oasis", "file": "tile_mountain.jpg", "color": COL_MOUNTAIN},
	"res://levels/CanyonLevel.tscn": {"title": "ARCO DEL VIENTO", "subtitle": "A truss bridge, a shelf road up the canyon wall, a knife-edge ridge, a slot canyon and a ford", "file": "tile_canyon.jpg", "color": COL_CANYON},
	"res://levels/CanyonChasmLevel.tscn": {"title": "TOLVANERA GULCH", "subtitle": "A narrow run over the drop, where a dust devil roams", "file": "tile_canyon_chasm.jpg", "color": COL_CHASM},
	"res://levels/FreightLevel.tscn": {"title": "ESTACIÓN SECA", "subtitle": "Two railways cross the lap: wait for the gap, jump the flatcars, or lose the race to a train", "file": "tile_freight_line.jpg", "color": COL_FREIGHT},
	"res://levels/MinaLevel.tscn": {"title": "MINA DEL VIENTO", "subtitle": "A downhill rally sprint: the radio array, the dawn balloon fiesta, the haboob, and the open-pit copper mine", "file": "tile_mina_del_viento.jpg", "color": COL_CANYON},
	"res://levels/DesertWadiLevel.tscn": {"title": "WADI AL-GHAF", "subtitle": "Off-road rally piste through the dunes: the date palm oasis, the ford and the fort over the valley", "file": "tile_desert_wadi.jpg", "color": COL_WADI},
	"res://levels/RamlatHamraLevel.tscn": {"title": "RAMLAT HAMRA", "subtitle": "Sunset in the red sands: salt flats between 50m dunes, over two saddles and a crest jump, past Qasr al-Hamra and the camel herds", "file": "tile_ramlat_hamra.jpg", "color": COL_WADI},
	"res://levels/MarinaNightsLevel.tscn": {"title": "MARINA NIGHTS", "subtitle": "The finale at night in the city: the corniche, the towers, the arch over the creek and its dhows, the souk's lanes, fireworks over the sea", "file": "tile_marina_nights.jpg", "color": COL_MAGENTA},
	"res://levels/MaraCrossingLevel.tscn": {"title": "MARA CROSSING", "subtitle": "Murram road across the savanna: the migration, Pride Rock, and the croc jump", "file": "tile_mara_crossing.jpg", "color": COL_SAVANNA},
	"res://levels/NyotaStadiumLevel.tscn": {"title": "NYOTA STADIUM", "subtitle": "Stadium supercross: doubles, whoops and a triple, a lap of the streets, and the Drop-In", "file": "tile_nyota_stadium.jpg", "color": COL_SAVANNA},
	"res://levels/MtaaNightsLevel.tscn": {"title": "MTAA NIGHTS", "subtitle": "Evening in the city: market streets, murram back roads, the park and Club Kilele's dancefloor. Tarmac or dirt: pick your route", "file": "tile_mtaa_nights.jpg", "color": COL_MAGENTA},
	"res://levels/KronburgLevel.tscn": {"title": "KRONBURGER HÜTTE", "subtitle": "The canal, through the steelworks' rolling mill hall and round the blast furnace, up through the colliery estate into the half-timbered old town and over its cobbled market square", "file": "tile_kronburg.jpg", "color": COL_KRONBURG},
	"res://levels/RheinuferLevel.tscn": {"title": "RHEINUFER", "subtitle": "Down the Rhine promenade, over the old steel-arch bridge, along the dyke past the sheep and the fun fair, round the Autobahn's loop ramp and back over the river on the cable-stayed bridge", "file": "tile_rheinufer.jpg", "color": COL_KRONBURG},
	"res://levels/StadtrallyeLevel.tscn": {"title": "QUER DURCH KRONBURG", "subtitle": "The finale, one run across town: over the moat bridge, through the pedestrian zone, across the Ring between cars and trams, through the Palmenhaus and up the botanical garden's Alpinum, past the wrecking ball, the scrapyard's magnet and the building site to the old gasworks", "file": "tile_stadtrallye.jpg", "color": COL_KRONBURG},
	"res://levels/ZecheLevel.tscn": {"title": "ZECHE KRONPRINZ", "subtitle": "Off-road through the old colliery: under the coal washer, past the coke ovens and the steaming quench tower, up the spoil heap, a leap off its plateau, through the birch scrub and the settling ponds, over the pit railway", "file": "tile_zeche.jpg", "color": COL_KRONBURG},
	"res://levels/SenbonSakuraLevel.tscn": {"title": "SENBON SAKURA PASS", "subtitle": "A mountain road through a thousand cherry trees in bloom: from the hanami park up the hairpins, under the tunnel of torii, along the ridge past the teahouse, down through the cedars over the vermilion bridge", "file": "tile_senbon_sakura.jpg", "color": COL_MIYOSHINO},
	"res://levels/YoshinoRapidsLevel.tscn": {"title": "YOSHINO RAPIDS", "subtitle": "Round the emerald river: the riverside village, the timber bridge, the sawmill's yard, a forest road through the cedars, down the log slide and through the ford; a raft train lies across the pool for the bold", "file": "tile_yoshino_rapids.jpg", "color": COL_MIYOSHINO},
	"res://levels/MonzenmachiLevel.tscn": {"title": "MONZENMACHI", "subtitle": "The temple town at dusk under its paper lanterns: down the shop street, through the great gate, up the stone steps past the hall and the pagoda, the back street's slope and the bamboo grove's chicane", "file": "tile_monzenmachi.jpg", "color": COL_MIYOSHINO},
	"res://levels/TianqiaoLevel.tscn": {"title": "TIANQIAO", "subtitle": "Yunhai at night: from the roof of the supertall along the sky gallery, a leap to the next tower, down the spiral, through the mall's atrium and the aquarium's tunnel to the park at street level", "file": "tile_tianqiao.jpg", "color": COL_YUNHAI},
	"res://levels/PanlongLevel.tscn": {"title": "PANLONG INTERCHANGE", "subtitle": "Laps of a five-level motorway knot at the blue hour: up round the coil, over and under your own road, across the unfinished ramp's gap, the ring expressway's traffic streaming overhead", "file": "tile_panlong.jpg", "color": COL_YUNHAI},
	"res://levels/YamabushiLevel.tscn": {"title": "YAMABUSHI TRAIL", "subtitle": "The finale, one run up the pilgrims' mountain at dawn: from the cedar forest over the gorge's suspension bridge, through the cloud, along plank walks chained to the cliffs to the shrine on the summit", "file": "tile_yamabushi.jpg", "color": COL_MIYOSHINO},
	"res://levels/TestTrackLevel.tscn": {"title": "TEST TRACK", "subtitle": "Try the cars: a 580m top-speed straight, a hairpin, a table-top, a chicane, a strip of every surface (sand, snow, ice, mud, grass, gravel, dirt, wood, cobbles) and a hill with a crest jump", "file": "tile_test_track.jpg", "color": COL_GOLD},
	"res://levels/MsituFallsLevel.tscn": {"title": "MSITU FALLS", "subtitle": "Rainforest hairpins, a mud bend, a rope bridge over the brink, behind the falls, and tropical downpours", "file": "tile_msitu_falls.jpg", "color": COL_JUNGLE},
}
## Section header colour per cup on the course lists (same accents as the cup tiles).
const CUP_COLORS := {"Bloombay GP": COL_GREEN, "Svartfjell GP": COL_SNOW, "Al-Raihana GP": COL_BRONZE, "Sierra del Viento GP": COL_CANYON, "Matumaini GP": COL_SAVANNA, "Kronburg GP": COL_KRONBURG, "Miyoshino GP": COL_MIYOSHINO, "Yunhai GP": COL_YUNHAI}
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
var _tile_scroll: ScrollContainer
var _fade_layer: Control
var _cascade: Array[Tween] = []
var _cascade_serial := 0
var _page_serial := 0
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


## A ScrollContainer takes a single child, so the tiles live in a VBox that can also hold section headers and
## their grids. Each page gets a fresh VBox and grid (`_new_tile_page`), so the last one can fade out whole.
func _create_tile_sections() -> void:
	_tile_scroll = tile_grid.get_parent() as ScrollContainer
	_tile_scroll.remove_child(tile_grid)
	tile_grid.queue_free()
	_new_tile_page()
	# Lay the tiles out again whenever the area changes (the window going fullscreen at start-up, the Player 2
	# name row showing), once the containers have sorted.
	_tile_scroll.resized.connect(_relayout_tiles)
	# Where the last page's tiles fade out, over the tile area and clipped to it.
	_fade_layer = Control.new()
	_fade_layer.name = "TileFadeOut"
	_fade_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.clip_contents = true
	add_child(_fade_layer)


func _new_tile_page() -> void:
	tile_sections = VBoxContainer.new()
	tile_sections.name = "TileSections"
	tile_sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_sections.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tile_sections.add_theme_constant_override("separation", 14)
	tile_sections.alignment = BoxContainer.ALIGNMENT_CENTER
	tile_grid = GridContainer.new()
	tile_grid.name = "TileGrid"
	tile_grid.columns = 2
	tile_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile_grid.add_theme_constant_override("h_separation", 22)
	tile_grid.add_theme_constant_override("v_separation", 22)
	tile_sections.add_child(tile_grid)
	_tile_scroll.add_child(tile_sections)


## The page's tiles (and a course list's section headers) come in one after another: each fades in while its
## picture rises into its frame, CASCADE_STEP apart (less on a long course list, so the last is in by
## CASCADE_SPAN), after `start` seconds.
func _cascade_in(start := 0.0) -> void:
	_kill_cascade()
	var items: Array = []
	for c in tile_sections.get_children():
		if c is GridContainer:
			if c.visible:
				items.append_array(c.get_children())
		elif c is Control:
			items.append(c)
	if items.is_empty():
		return
	for n in items:
		(n as Control).modulate.a = 0.0
		var content := (n as Control).get_node_or_null("Content") as Control
		if content:
			content.position.y = CASCADE_RISE
	# The tweens start a frame later: the frame a page is built in is a long one, and the next frame's step would
	# carry the first tiles most of the way in at once.
	_cascade_serial += 1
	var serial := _cascade_serial
	await get_tree().process_frame
	if serial != _cascade_serial:
		return
	var step := minf(CASCADE_STEP, CASCADE_SPAN / float(items.size()))
	for i in items.size():
		var n := items[i] as Control
		if not is_instance_valid(n) or not n.is_inside_tree():
			continue
		var d := start + step * float(i)
		var tw := n.create_tween().set_parallel(true)
		tw.tween_property(n, "modulate:a", 1.0, CASCADE_FADE).set_delay(d).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		var content := n.get_node_or_null("Content") as Control
		if content:
			tw.tween_property(content, "position:y", 0.0, CASCADE_MOVE).set_delay(d).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_cascade.append(tw)


func _kill_cascade() -> void:
	_cascade_serial += 1
	for tw in _cascade:
		if tw.is_valid():
			tw.kill()
	_cascade.clear()
	if tile_sections:
		for c in tile_sections.find_children("*", "Control", false, false):
			(c as Control).modulate.a = 1.0
		for b in tile_sections.find_children("Content", "Control", true, false):
			(b as Control).position.y = 0.0


## The last page fades out whole where it stood (over the new one's start), its tiles no longer pressable, and
## is freed.
func _fade_out(old: Control, at: Vector2, old_size: Vector2) -> void:
	_fade_layer.position = _tile_scroll.global_position - global_position
	_fade_layer.size = _tile_scroll.size
	_fade_layer.add_child(old)
	old.position = at - _tile_scroll.global_position
	old.size = old_size
	for b in old.find_children("*", "BaseButton", true, false):
		(b as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		(b as Control).focus_mode = Control.FOCUS_NONE
	var tw := old.create_tween().set_parallel(true)
	tw.tween_property(old, "modulate:a", 0.0, FADE_OUT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(old, "position:y", old.position.y - FADE_OUT_RISE, FADE_OUT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(old.queue_free)


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
		# The menu comes back behind the screen swipe: the tiles cascade in as it clears.
		_cascade_in(0.3)
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


## Shows a page: the last one fades out first (FADE_OUT_TIME), then this one is built and its tiles cascade in.
## Built after the fade, not during it: building a page (its cars, its 3D scenes) takes one long frame, and the
## fade's tween jumped across it. `current_screen` changes at once.
func show_sub_menu(menu_name: String) -> void:
	current_screen = menu_name
	_page_serial += 1
	var serial := _page_serial
	if _clear_tiles():
		await get_tree().create_timer(FADE_OUT_TIME).timeout
		if serial != _page_serial or not is_inside_tree():
			return
	_build_page(menu_name)


func _build_page(menu_name: String) -> void:
	extra_row.visible = false
	btn_back.visible = menu_name != "main"
	btn_quit.visible = menu_name == "main"

	match menu_name:
		"main":
			screen_title.text = "SELECT MODE"
			screen_subtitle.text = "Choose how you want to race"
			tile_grid.columns = 2
			_add_tile("SINGLE PLAYER", "Grand Prix or Time Trial against the clock", "scene:single", COL_TEAL, func():
				NetworkManager.current_game_mode = NetworkManager.GameMode.SINGLE_PLAYER_TIME_TRIAL
				show_sub_menu("sp_modes")
			)
			_add_tile("SPLITSCREEN", "Two racers, one screen", "scene:splitscreen", COL_ORANGE, func():
				show_sub_menu("coop_config")
			)
			_add_tile("MULTIPLAYER", "Host or join a LAN race", "scene:multiplayer", COL_MAGENTA, _on_multiplayer_pressed)
			_add_tile("GARAGE", "Walk your collection, pick the line-up, see your trophies", "tile_garage.jpg", COL_BRONZE, func():
				garage_pressed.emit()
			)
			_add_tile("SPECTATOR", "Watch 6 AI racers — pick any course", "scene:spectator", COL_CYAN, func():
				NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
				NetworkManager.inspect_mode = false
				show_sub_menu("stage_select")
			)
			_add_tile("INSPECT", "No cars — fly a free camera round any course", "scene:inspect", COL_TEAL, func():
				NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
				NetworkManager.inspect_mode = true
				show_sub_menu("stage_select")
			)
			_add_tile("OPTIONS", "Graphics, sound, and controls", "scene:options", COL_GOLD, _on_options_pressed)
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
			_add_tile("GRAND PRIX", "Race a cup of tracks against bots", "scene:grand_prix", COL_GOLD, func():
				show_sub_menu("cup_select")
			)
			_add_tile("TIME TRIAL", "Solo laps on any course", "scene:time_trial", COL_CYAN, func():
				show_sub_menu("stage_select")
			)
		"coop_config":
			screen_title.text = "SPLITSCREEN"
			screen_subtitle.text = "Set Player 2's name, then pick a mode"
			extra_row.visible = true
			tile_grid.columns = 2
			_add_tile("GRAND PRIX", "Share a cup with bots in the field", "scene:grand_prix", COL_GOLD, _on_coop_gp_pressed)
			_add_tile("VS RACE", "Head-to-head on a single course", "scene:vs", COL_ORANGE, _on_coop_vs_pressed)
		"cup_select":
			screen_title.text = "SELECT CUP"
			screen_subtitle.text = "Each cup is a series of courses"
			tile_grid.columns = 2
			_add_tile("BLOOMBAY GP", "Lakeside  •  Pinecrest  •  Harbor  •  South Beach", "tile_bloombay_gp.jpg", COL_GREEN, func():
				_on_cup_selected("Bloombay GP")
			)
			_add_tile("SVARTFJELL GP", "Frostpeak  •  Glacier Highway  •  Northlight  •  Frostfall Gorge", "tile_svartfjell_gp.jpg", COL_SNOW, func():
				_on_cup_selected("Svartfjell GP")
			)
			_add_tile("AL-RAIHANA GP", "Jebel Sahar  •  Wadi al-Ghaf  •  Ramlat Hamra  •  Marina Nights", "tile_al_raihana_gp.jpg", COL_BRONZE, func():
				_on_cup_selected("Al-Raihana GP")
			)
			_add_tile("SIERRA DEL VIENTO GP", "Arco del Viento  •  Tolvanera Gulch  •  Estación Seca  •  Mina del Viento", "tile_sierra_del_viento_gp.jpg", COL_CANYON, func():
				_on_cup_selected("Sierra del Viento GP")
			)
			_add_tile("MATUMAINI GP", "Mara Crossing  •  Nyota Stadium  •  Msitu Falls", "tile_matumaini_gp.jpg", COL_SAVANNA, func():
				_on_cup_selected("Matumaini GP")
			)
			_add_tile("KRONBURG GP", "Kronburger Hütte  •  Rheinufer  •  Zeche Kronprinz  •  Quer durch Kronburg", "tile_kronburg_gp.jpg", COL_KRONBURG, func():
				_on_cup_selected("Kronburg GP")
			)
			_add_tile("MIYOSHINO GP", "Senbon Sakura Pass  •  Yoshino Rapids  •  Monzenmachi  •  Yamabushi Trail", "tile_miyoshino_gp.jpg", COL_MIYOSHINO, func():
				_on_cup_selected("Miyoshino GP")
			)
			_add_tile("YUNHAI GP", "Tianqiao  •  Panlong Interchange", "tile_yunhai_gp.jpg", COL_YUNHAI, func():
				_on_cup_selected("Yunhai GP")
			)
		"stage_select":
			if NetworkManager.current_game_mode == NetworkManager.GameMode.SPECTATOR:
				if NetworkManager.inspect_mode:
					screen_title.text = "INSPECT"
					screen_subtitle.text = "Pick a course to explore — no cars, fly anywhere"
				else:
					screen_title.text = "SPECTATOR"
					screen_subtitle.text = "Pick a course to watch — 6 AI racers, you stay off the grid"
			else:
				screen_title.text = "SELECT COURSE"
				screen_subtitle.text = "Pick a track to race"
			_fill_stages_by_cup(func(_cup: String, _i: int, path: String):
				_on_stage_selected(path)
			, false)
	# Sized at once (the scroll area is known) so the first tiles don't show at their default size for a frame,
	# and again once the containers have sorted.
	_relayout_tiles()
	call_deferred("_relayout_tiles")
	if is_visible_in_tree():
		_cascade_in(0.0)


func _relayout_tiles() -> void:
	if tile_grid == null or (tile_grid.get_child_count() == 0 and section_grids.is_empty()):
		return
	# The ScrollContainer's own size: the VBox inside it (tile_grid's parent) is as big as its content, which is
	# the last page's tiles, so measuring it sized each page from the one before (small at start-up, the two tiles
	# under Single Player taller than the screen).
	var scroll: Control = tile_sections.get_parent() if tile_sections else tile_grid.get_parent()
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
	# No taller than about 5:3, centred in the area: two tiles side by side had filled the screen's height.
	th = clampf(th, 190.0, maxf(tw * 0.6, 190.0))
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


## Takes the page's tiles away, fading them out where they stood if the menu is on screen; true if it fades.
func _clear_tiles() -> bool:
	_kill_cascade()
	section_grids.clear()
	var old := tile_sections
	if old:
		var at := old.global_position
		var old_size := old.size
		var had_tiles := old.find_children("*", "BaseButton", true, false).size() > 0
		_tile_scroll.remove_child(old)
		_new_tile_page()
		if had_tiles and is_visible_in_tree():
			_fade_out(old, at, old_size)
			return true
		old.queue_free()
		return false
	_new_tile_page()
	return false


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

	# Everything inside the frame is under "Content" (the cascade slides it up into the frame). The picture's
	# area is 4px inside the border, a Panel drawing a rounded rectangle that its children are clipped to
	# (`clip_children`), so the picture, the caption's shade and the colour bar follow the frame's round corners.
	# "scene:<kind>" is a live 3D scene (MenuTileStage.gd); any other file a picture that drifts and zooms slowly
	# (MenuTileDrift.gd).
	var content := Control.new()
	content.name = "Content"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(content)
	var holder := Panel.new()
	holder.name = "Picture"
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.offset_left = 4
	holder.offset_top = 4
	holder.offset_right = -4
	holder.offset_bottom = -4
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mask := StyleBoxFlat.new()
	mask.bg_color = Color.WHITE
	mask.set_corner_radius_all(TILE_INNER_RADIUS)
	mask.anti_aliasing = true
	holder.add_theme_stylebox_override("panel", mask)
	holder.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	var tex: TextureRect
	if file_name.begins_with("scene:"):
		tex = MenuTileStage.new()
		(tex as MenuTileStage).setup(file_name.substr(6), accent)
	else:
		tex = MenuTileDrift.new()
		(tex as MenuTileDrift).phase = float(hash(file_name) % 6283) * 0.001
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex_path := TILE_DIR + file_name
	if not file_name.begins_with("scene:") and ResourceLoader.exists(tex_path):
		tex.texture = load(tex_path)
	holder.add_child(tex)
	content.add_child(holder)

	var fade := ColorRect.new()
	fade.color = Color(0.03, 0.035, 0.05, 0.78)
	fade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	fade.anchor_top = 0.52
	fade.offset_top = 0
	fade.offset_bottom = 0
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(fade)

	var accent_bar := ColorRect.new()
	accent_bar.color = accent
	accent_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	accent_bar.offset_top = -4
	accent_bar.offset_bottom = 0
	accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(accent_bar)

	var caption := VBoxContainer.new()
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_left = 18
	caption.offset_right = -18
	caption.offset_top = -96
	caption.offset_bottom = -16
	caption.add_theme_constant_override("separation", 2)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(caption)

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
	normal.set_corner_radius_all(TILE_RADIUS)
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


func _on_stage_selected(stage_path: String) -> void:
	if NetworkManager.current_game_mode != NetworkManager.GameMode.LOCAL_COOP \
			and NetworkManager.current_game_mode != NetworkManager.GameMode.SPECTATOR:
		NetworkManager.current_game_mode = NetworkManager.GameMode.SINGLE_PLAYER_TIME_TRIAL
	NetworkManager.time_trial_stage = stage_path
	start_pressed.emit()


func _on_cup_selected(cup_name: String) -> void:
	if NetworkManager.current_game_mode != NetworkManager.GameMode.LOCAL_COOP:
		NetworkManager.current_game_mode = NetworkManager.GameMode.SINGLE_PLAYER_GP
	NetworkManager.current_gp_name = cup_name
	NetworkManager.current_gp_stage = 0
	NetworkManager.gp_trophy_eligible = true
	NetworkManager.gp_standings.clear()
	NetworkManager.gp_last_pos.clear()
	NetworkManager.gp_bot_roster.clear()
	start_pressed.emit()


func _on_gp_test_stage_selected(cup_name: String, stage_idx: int) -> void:
	NetworkManager.current_game_mode = NetworkManager.GameMode.SINGLE_PLAYER_GP
	NetworkManager.is_coop_gp = false
	NetworkManager.current_gp_name = cup_name
	NetworkManager.current_gp_stage = stage_idx
	NetworkManager.gp_trophy_eligible = stage_idx == 0
	NetworkManager.gp_standings.clear()
	NetworkManager.gp_last_pos.clear()
	NetworkManager.gp_bot_roster.clear()
	start_pressed.emit()


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
	quit_pressed.emit()
