extends Control

signal start_pressed
signal options_pressed

@onready var button_start = $CenterContainer/VBoxContainer/ButtonStart
@onready var button_options = $CenterContainer/VBoxContainer/ButtonOptions
@onready var button_quit = $CenterContainer/VBoxContainer/ButtonQuit
@onready var vbox_container = $CenterContainer/VBoxContainer

# Dynamic UI containers
var main_buttons_container: VBoxContainer
var sp_modes_container: VBoxContainer
var cup_select_container: VBoxContainer
var name_edit: LineEdit

func _ready():
	# Hide original buttons to use dynamic menu
	button_start.hide()
	button_options.hide()
	button_quit.hide()
	
	_create_name_input()
	_create_main_menu()
	_create_sp_modes_menu()
	_create_cup_select_menu()
	
	# Show main menu by default
	show_sub_menu("main")

func _create_name_input():
	var label = Label.new()
	label.text = "Racer Name:"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	vbox_container.add_child(label)
	
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Enter Name..."
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_edit.custom_minimum_size = Vector2(0, 45)
	name_edit.max_length = 16
	name_edit.add_theme_font_size_override("font_size", 20)
	
	# Load saved player name
	var config = ConfigFile.new()
	var saved_name = "Player"
	if config.load("user://settings.cfg") == OK:
		saved_name = config.get_value("player", "name", "Player")
	name_edit.text = saved_name
	
	name_edit.text_changed.connect(_on_name_changed)
	vbox_container.add_child(name_edit)
	
	# Spacing separator
	var sep = HSeparator.new()
	vbox_container.add_child(sep)

func _on_name_changed(new_name: String):
	var config = ConfigFile.new()
	config.load("user://settings.cfg")
	config.set_value("player", "name", new_name)
	config.save("user://settings.cfg")

func _create_main_menu():
	main_buttons_container = VBoxContainer.new()
	main_buttons_container.add_theme_constant_override("separation", 15)
	vbox_container.add_child(main_buttons_container)
	
	var btn_single = _add_menu_button(main_buttons_container, "SINGLE PLAYER")
	btn_single.pressed.connect(func(): show_sub_menu("sp_modes"))
	
	var btn_multi = _add_menu_button(main_buttons_container, "MULTIPLAYER")
	btn_multi.pressed.connect(_on_multiplayer_pressed)
	
	var btn_opts = _add_menu_button(main_buttons_container, "OPTIONS")
	btn_opts.pressed.connect(_on_options_pressed)
	
	var btn_q = _add_menu_button(main_buttons_container, "QUIT")
	btn_q.pressed.connect(_on_quit_pressed)

func _create_sp_modes_menu():
	sp_modes_container = VBoxContainer.new()
	sp_modes_container.add_theme_constant_override("separation", 15)
	vbox_container.add_child(sp_modes_container)
	
	var label = Label.new()
	label.text = "SELECT MODE"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	sp_modes_container.add_child(label)
	
	var btn_gp = _add_menu_button(sp_modes_container, "GRAND PRIX (GP)")
	btn_gp.pressed.connect(func(): show_sub_menu("cup_select"))
	
	var btn_tt = _add_menu_button(sp_modes_container, "TIME TRIAL")
	btn_tt.pressed.connect(_on_time_trial_pressed)
	
	var btn_back = _add_menu_button(sp_modes_container, "BACK")
	btn_back.pressed.connect(func(): show_sub_menu("main"))

func _create_cup_select_menu():
	cup_select_container = VBoxContainer.new()
	cup_select_container.add_theme_constant_override("separation", 15)
	vbox_container.add_child(cup_select_container)
	
	var label = Label.new()
	label.text = "SELECT CUP"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	cup_select_container.add_child(label)
	
	var btn_starter = _add_menu_button(cup_select_container, "STARTER CUP")
	btn_starter.pressed.connect(func(): _on_cup_selected("Starter Cup"))
	
	var btn_desert = _add_menu_button(cup_select_container, "DESERT CUP")
	btn_desert.pressed.connect(func(): _on_cup_selected("Desert Cup"))
	
	var btn_back = _add_menu_button(cup_select_container, "BACK")
	btn_back.pressed.connect(func(): show_sub_menu("sp_modes"))

func _add_menu_button(parent: Node, label_text: String) -> Button:
	var btn = Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(0, 50)
	btn.add_theme_font_size_override("font_size", 24)
	parent.add_child(btn)
	return btn

func show_sub_menu(menu_name: String):
	main_buttons_container.visible = (menu_name == "main")
	sp_modes_container.visible = (menu_name == "sp_modes")
	cup_select_container.visible = (menu_name == "cup_select")

func _on_multiplayer_pressed():
	NetworkManager.current_game_mode = NetworkManager.GameMode.MULTIPLAYER
	start_pressed.emit()
	hide()

func _on_time_trial_pressed():
	NetworkManager.current_game_mode = NetworkManager.GameMode.SINGLE_PLAYER_TIME_TRIAL
	start_pressed.emit()
	hide()

func _on_cup_selected(cup_name: String):
	NetworkManager.current_game_mode = NetworkManager.GameMode.SINGLE_PLAYER_GP
	NetworkManager.current_gp_name = cup_name
	NetworkManager.current_gp_stage = 0
	NetworkManager.gp_standings.clear()
	start_pressed.emit()
	hide()

func _on_options_pressed():
	options_pressed.emit()

func _on_quit_pressed():
	get_tree().quit()


