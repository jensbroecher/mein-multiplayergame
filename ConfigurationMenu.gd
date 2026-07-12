extends Control

signal back_pressed

@onready var check_fps = $Panel/MarginContainer/VBoxContainer/ScrollContainer/SettingsList/LeftColumn/VideoSettings/FPSBox/CheckFPS
@onready var option_window_mode = $Panel/MarginContainer/VBoxContainer/ScrollContainer/SettingsList/LeftColumn/VideoSettings/WindowModeBox/OptionWindowMode
@onready var option_resolution = $Panel/MarginContainer/VBoxContainer/ScrollContainer/SettingsList/LeftColumn/VideoSettings/ResolutionBox/OptionResolution
@onready var check_vsync = $Panel/MarginContainer/VBoxContainer/ScrollContainer/SettingsList/LeftColumn/VideoSettings/VSyncBox/CheckVSync
@onready var option_anti_aliasing = $Panel/MarginContainer/VBoxContainer/ScrollContainer/SettingsList/LeftColumn/VideoSettings/AntiAliasingBox/OptionAntiAliasing

@onready var btn_back = $Panel/MarginContainer/VBoxContainer/BtnBack

var is_waiting_for_key: bool = false
var waiting_action: String = ""

var p1_buttons = {}
var p2_buttons = {}

const ACTION_LABELS = {
	"throttle": "Throttle / Forward",
	"brake": "Brake / Reverse",
	"steer_left": "Steer Left",
	"steer_right": "Steer Right",
	"boost": "Use Item / Boost",
	"discard_item": "Discard Item",
	"respawn": "Respawn Cart",
	"toggle_camera": "Change Camera"
}

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Configure option window mode items
	option_window_mode.clear()
	option_window_mode.add_item("Windowed")
	option_window_mode.add_item("Fullscreen")
	
	# Configure option resolution items
	option_resolution.clear()
	option_resolution.add_item("1280 x 720 (720p)")
	option_resolution.add_item("1920 x 1080 (1080p)")
	option_resolution.add_item("2560 x 1440 (2K)")
	option_resolution.add_item("3840 x 2160 (4K)")
	
	# Configure option anti-aliasing items
	option_anti_aliasing.clear()
	option_anti_aliasing.add_item("Disabled")
	option_anti_aliasing.add_item("2x MSAA")
	option_anti_aliasing.add_item("4x MSAA")
	option_anti_aliasing.add_item("8x MSAA")
	option_anti_aliasing.add_item("FXAA")
	
	# Load current display values from MusicManager
	check_fps.button_pressed = MusicManager.show_fps
	option_window_mode.selected = MusicManager.window_mode
	option_resolution.selected = MusicManager.resolution_index
	check_vsync.button_pressed = MusicManager.vsync
	option_anti_aliasing.selected = MusicManager.anti_aliasing
	
	# Connect signals
	check_fps.toggled.connect(_on_fps_toggled)
	option_window_mode.item_selected.connect(_on_window_mode_selected)
	option_resolution.item_selected.connect(_on_resolution_selected)
	check_vsync.toggled.connect(_on_vsync_toggled)
	option_anti_aliasing.item_selected.connect(_on_anti_aliasing_selected)
	btn_back.pressed.connect(_on_back_pressed)
	
	_build_input_ui()
	update_keybind_buttons()

func _build_input_ui():
	# Hide old keyboard controls from LeftColumn
	var controls_label = $Panel/MarginContainer/VBoxContainer/ScrollContainer/SettingsList/LeftColumn.get_node_or_null("ControlsLabel")
	if controls_label: controls_label.hide()
	var input_settings = $Panel/MarginContainer/VBoxContainer/ScrollContainer/SettingsList/LeftColumn.get_node_or_null("InputSettings")
	if input_settings: input_settings.hide()
	
	# Hide old gamepad card from RightColumn
	var controller_label = $Panel/MarginContainer/VBoxContainer/ScrollContainer/SettingsList/RightColumn.get_node_or_null("ControllerLabel")
	if controller_label: controller_label.hide()
	var controller_card = $Panel/MarginContainer/VBoxContainer/ScrollContainer/SettingsList/RightColumn.get_node_or_null("ControllerCard")
	if controller_card: controller_card.hide()
	
	# Create Player 1 controls in LeftColumn
	var p1_container = VBoxContainer.new()
	p1_container.name = "P1InputContainer"
	p1_container.add_theme_constant_override("separation", 8)
	$Panel/MarginContainer/VBoxContainer/ScrollContainer/SettingsList/LeftColumn.add_child(p1_container)
	
	var p1_title = Label.new()
	p1_title.text = "PLAYER 1 BINDINGS"
	p1_title.add_theme_color_override("font_color", Color(0, 0.8, 1, 1))
	p1_title.add_theme_font_size_override("font_size", 18)
	p1_container.add_child(p1_title)
	
	# P1 Default Quick-Map Buttons
	var p1_quick = HBoxContainer.new()
	p1_quick.add_theme_constant_override("separation", 10)
	p1_container.add_child(p1_quick)
	
	var p1_btn_kb = Button.new()
	p1_btn_kb.text = "Set Keyboard Defaults"
	p1_btn_kb.pressed.connect(func():
		MusicManager.set_default_keyboard_bindings(1)
		update_keybind_buttons()
	)
	p1_quick.add_child(p1_btn_kb)
	
	var p1_btn_gp = Button.new()
	p1_btn_gp.text = "Set Gamepad Defaults"
	p1_btn_gp.pressed.connect(func():
		MusicManager.set_default_controller_bindings(1)
		update_keybind_buttons()
	)
	p1_quick.add_child(p1_btn_gp)
	
	_add_action_rows("p1_", p1_container, p1_buttons)
	
	# Create Player 2 controls in RightColumn
	var p2_container = VBoxContainer.new()
	p2_container.name = "P2InputContainer"
	p2_container.add_theme_constant_override("separation", 8)
	$Panel/MarginContainer/VBoxContainer/ScrollContainer/SettingsList/RightColumn.add_child(p2_container)
	
	var p2_title = Label.new()
	p2_title.text = "PLAYER 2 BINDINGS"
	p2_title.add_theme_color_override("font_color", Color(0, 0.8, 1, 1))
	p2_title.add_theme_font_size_override("font_size", 18)
	p2_container.add_child(p2_title)
	
	# P2 Default Quick-Map Buttons
	var p2_quick = HBoxContainer.new()
	p2_quick.add_theme_constant_override("separation", 10)
	p2_container.add_child(p2_quick)
	
	var p2_btn_kb = Button.new()
	p2_btn_kb.text = "Set Keyboard Defaults"
	p2_btn_kb.pressed.connect(func():
		MusicManager.set_default_keyboard_bindings(2)
		update_keybind_buttons()
	)
	p2_quick.add_child(p2_btn_kb)
	
	var p2_btn_gp = Button.new()
	p2_btn_gp.text = "Set Gamepad Defaults"
	p2_btn_gp.pressed.connect(func():
		MusicManager.set_default_controller_bindings(2)
		update_keybind_buttons()
	)
	p2_quick.add_child(p2_btn_gp)
	
	_add_action_rows("p2_", p2_container, p2_buttons)

func _add_action_rows(prefix: String, parent_container: Control, buttons_map: Dictionary):
	for suffix in ACTION_LABELS:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		parent_container.add_child(row)
		
		var lbl = Label.new()
		lbl.text = ACTION_LABELS[suffix]
		lbl.custom_minimum_size = Vector2(160, 0)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(180, 35)
		btn.add_theme_font_size_override("font_size", 14)
		
		var full_action = prefix + suffix
		btn.pressed.connect(func(): start_remapping(full_action, btn))
		
		row.add_child(btn)
		buttons_map[suffix] = btn

func update_keybind_buttons():
	for suffix in p1_buttons:
		p1_buttons[suffix].text = MusicManager.get_action_friendly_text("p1_" + suffix)
	for suffix in p2_buttons:
		p2_buttons[suffix].text = MusicManager.get_action_friendly_text("p2_" + suffix)

func start_remapping(action_name: String, button: Button):
	if is_waiting_for_key:
		update_keybind_buttons()
		
	is_waiting_for_key = true
	waiting_action = action_name
	button.text = "[Press Any Key/Button...]"
	
	# Release focus so that UI navigation and accept triggers (Space/Enter/Joy A/Dpad)
	# don't interfere with or double-trigger remapping!
	button.release_focus()

func _find_button_for_action(action_name: String) -> Button:
	var suffix = action_name.substr(3) # remove "p1_" or "p2_"
	if action_name.begins_with("p1_"):
		return p1_buttons.get(suffix, null)
	else:
		return p2_buttons.get(suffix, null)

func _input(event: InputEvent):
	if not is_waiting_for_key: return
	
	var is_valid_input = false
	var captured_event = null
	
	if event is InputEventKey and event.pressed:
		if event.physical_keycode != KEY_ESCAPE:
			captured_event = InputEventKey.new()
			captured_event.physical_keycode = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		is_valid_input = true
	elif event is InputEventJoypadButton and event.pressed:
		captured_event = InputEventJoypadButton.new()
		captured_event.device = event.device
		captured_event.button_index = event.button_index
		is_valid_input = true
	elif event is InputEventJoypadMotion:
		if abs(event.axis_value) > 0.6:
			captured_event = InputEventJoypadMotion.new()
			captured_event.device = event.device
			captured_event.axis = event.axis
			captured_event.axis_value = 1.0 if event.axis_value > 0 else -1.0
			is_valid_input = true
			
	if is_valid_input:
		is_waiting_for_key = false
		if captured_event:
			MusicManager.save_action_event(waiting_action, captured_event)
		update_keybind_buttons()
		get_viewport().set_input_as_handled()
		
		# Restore focus to the button after remapping is complete
		var btn = _find_button_for_action(waiting_action)
		if btn:
			btn.grab_focus()

func _on_fps_toggled(toggled_val: bool):
	MusicManager.set_show_fps(toggled_val)

func _on_window_mode_selected(index: int):
	MusicManager.set_window_mode(index)

func _on_resolution_selected(index: int):
	MusicManager.set_resolution(index)

func _on_vsync_toggled(toggled_val: bool):
	MusicManager.set_vsync(toggled_val)

func _on_anti_aliasing_selected(index: int):
	MusicManager.set_anti_aliasing(index)

func _on_back_pressed():
	is_waiting_for_key = false
	back_pressed.emit()
	hide()
