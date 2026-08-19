extends Control

signal back_pressed

const COL_TEAL := Color(0.15, 0.75, 0.92)
const COL_ORANGE := Color(1.0, 0.55, 0.16)
const COL_GOLD := Color(1.0, 0.78, 0.22)

const ACTION_LABELS := {
	"throttle": "Throttle / Forward",
	"brake": "Brake / Reverse",
	"steer_left": "Steer Left",
	"steer_right": "Steer Right",
	"boost": "Use Item / Boost",
	"discard_item": "Discard Item",
	"respawn": "Respawn Cart",
	"toggle_camera": "Change Camera"
}

const CATEGORIES := [
	{"id": "graphics", "label": "GRAPHICS"},
	{"id": "sound", "label": "SOUND"},
	{"id": "input", "label": "INPUT"},
	{"id": "gameplay", "label": "GAMEPLAY"},
]

@onready var btn_back: Button = $Root/VBox/Header/BtnBack
@onready var category_list: VBoxContainer = $Root/VBox/Body/CategoryList
@onready var pages_host: Control = $Root/VBox/Body/ContentPanel/ContentMargin/Pages

var category_buttons: Dictionary = {}
var pages: Dictionary = {}
var current_category: String = "graphics"

var check_fps: CheckButton
var option_window_mode: OptionButton
var option_resolution: OptionButton
var check_vsync: CheckButton
var option_anti_aliasing: OptionButton
var option_shadows: OptionButton
var option_render_scale: OptionButton
var option_renderer: OptionButton
var option_fsr_mode: OptionButton
var slider_fsr_sharpness: HSlider
var label_fsr_sharpness: Label
var label_renderer_status: Label
var btn_renderer_restart: Button
var fsr_section: Control
var renderer_restart_dialog: ConfirmationDialog
var _pending_renderer: String = ""
var option_anisotropic: OptionButton
var option_max_fps: OptionButton
var option_camera_mode: OptionButton
var slider_music: HSlider
var slider_sfx: HSlider
var label_music_value: Label
var label_sfx_value: Label
var remap_banner: Label

var is_waiting_for_key: bool = false
var waiting_action: String = ""
var p1_buttons: Dictionary = {}
var p2_buttons: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_style_content_panel()
	_style_back_button()
	_build_category_nav()
	_build_pages()
	_load_values_from_manager()
	_connect_setting_signals()
	btn_back.pressed.connect(_on_back_pressed)
	visibility_changed.connect(_on_visibility_changed)
	_show_category("graphics")


func _on_visibility_changed() -> void:
	if visible:
		is_waiting_for_key = false
		_load_values_from_manager()
		update_keybind_buttons()
		if remap_banner:
			remap_banner.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		if is_waiting_for_key:
			is_waiting_for_key = false
			update_keybind_buttons()
			if remap_banner:
				remap_banner.visible = false
		else:
			_on_back_pressed()
		get_viewport().set_input_as_handled()


func _style_content_panel() -> void:
	var panel: PanelContainer = $Root/VBox/Body/ContentPanel
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.1, 0.14, 0.96)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.2, 0.24, 0.32, 1)
	panel.add_theme_stylebox_override("panel", sb)


func _style_back_button() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.14, 0.2, 1)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.28, 0.34, 0.44, 1)
	var hover: StyleBoxFlat = sb.duplicate() as StyleBoxFlat
	hover.border_color = COL_GOLD
	hover.bg_color = Color(0.16, 0.2, 0.28, 1)
	btn_back.add_theme_stylebox_override("normal", sb)
	btn_back.add_theme_stylebox_override("hover", hover)
	btn_back.add_theme_stylebox_override("pressed", hover)
	btn_back.add_theme_stylebox_override("focus", hover)


func _build_category_nav() -> void:
	for cat in CATEGORIES:
		var btn := Button.new()
		btn.text = cat["label"]
		btn.custom_minimum_size = Vector2(0, 56)
		btn.add_theme_font_size_override("font_size", 20)
		btn.toggle_mode = true
		btn.focus_mode = Control.FOCUS_ALL
		_style_category_button(btn, false)
		var cat_id: String = cat["id"]
		btn.pressed.connect(_show_category.bind(cat_id))
		category_list.add_child(btn)
		category_buttons[cat_id] = btn


func _style_category_button(btn: Button, selected: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	if selected:
		sb.bg_color = Color(0.16, 0.22, 0.3, 1)
		sb.border_color = COL_GOLD
	else:
		sb.bg_color = Color(0.1, 0.11, 0.16, 1)
		sb.border_color = Color(0.22, 0.26, 0.34, 1)
	var hover: StyleBoxFlat = sb.duplicate() as StyleBoxFlat
	hover.border_color = COL_TEAL
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_color_override("font_color", Color.WHITE if selected else Color(0.78, 0.82, 0.88))


func _show_category(cat_id: String) -> void:
	if is_waiting_for_key:
		is_waiting_for_key = false
		update_keybind_buttons()
		if remap_banner:
			remap_banner.visible = false
	current_category = cat_id
	for id in category_buttons:
		var selected: bool = (id == cat_id)
		category_buttons[id].set_pressed_no_signal(selected)
		_style_category_button(category_buttons[id], selected)
	for id in pages:
		pages[id].visible = (id == cat_id)


func _build_pages() -> void:
	pages["graphics"] = _build_graphics_page()
	pages["sound"] = _build_sound_page()
	pages["input"] = _build_input_page()
	pages["gameplay"] = _build_gameplay_page()
	for id in pages:
		var page: Control = pages[id]
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		page.visible = false
		pages_host.add_child(page)


func _make_scroll_page() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return scroll


func _make_page_body(scroll: ScrollContainer) -> VBoxContainer:
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	return body


func _add_section_title(parent: Control, text: String, color: Color = COL_TEAL) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 20)
	parent.add_child(lbl)


func _add_hint(parent: Control, text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_color", Color(0.68, 0.72, 0.8, 1))
	lbl.add_theme_font_size_override("font_size", 15)
	parent.add_child(lbl)
	return lbl


func _add_check_row(parent: Control, label_text: String) -> CheckButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(240, 0)
	lbl.add_theme_font_size_override("font_size", 18)
	row.add_child(lbl)
	var check := CheckButton.new()
	row.add_child(check)
	return check


func _add_option_row(parent: Control, label_text: String) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(240, 0)
	lbl.add_theme_font_size_override("font_size", 18)
	row.add_child(lbl)
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.custom_minimum_size = Vector2(0, 40)
	opt.add_theme_font_size_override("font_size", 16)
	row.add_child(opt)
	return opt


func _add_slider_row(parent: Control, label_text: String) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(240, 0)
	lbl.add_theme_font_size_override("font_size", 18)
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(200, 28)
	row.add_child(slider)
	var value_lbl := Label.new()
	value_lbl.custom_minimum_size = Vector2(56, 0)
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_lbl.add_theme_font_size_override("font_size", 16)
	row.add_child(value_lbl)
	return [slider, value_lbl]


func _build_graphics_page() -> Control:
	var scroll := _make_scroll_page()
	var body := _make_page_body(scroll)

	_add_section_title(body, "DISPLAY")
	option_window_mode = _add_option_row(body, "Window Mode")
	option_window_mode.add_item("Windowed")
	option_window_mode.add_item("Fullscreen")
	option_resolution = _add_option_row(body, "Resolution")
	option_resolution.add_item("1280 x 720 (720p)")
	option_resolution.add_item("1920 x 1080 (1080p)")
	option_resolution.add_item("2560 x 1440 (2K)")
	option_resolution.add_item("3840 x 2160 (4K)")
	check_vsync = _add_check_row(body, "VSync")
	option_max_fps = _add_option_row(body, "Max FPS")
	option_max_fps.add_item("30")
	option_max_fps.add_item("60")
	option_max_fps.add_item("120")
	option_max_fps.add_item("Unlimited")
	check_fps = _add_check_row(body, "Show FPS Counter")

	body.add_child(HSeparator.new())
	_add_section_title(body, "RENDERER")
	_add_hint(body, "Forward+ enables FSR upscaling. Switching renderer restarts the game.")
	option_renderer = _add_option_row(body, "3D Renderer")
	option_renderer.add_item("Mobile")
	option_renderer.add_item("Forward+")
	label_renderer_status = _add_hint(body, "Currently running Mobile.")
	btn_renderer_restart = Button.new()
	btn_renderer_restart.text = "Restart to apply renderer"
	btn_renderer_restart.custom_minimum_size = Vector2(280, 40)
	btn_renderer_restart.add_theme_font_size_override("font_size", 16)
	btn_renderer_restart.visible = false
	btn_renderer_restart.pressed.connect(_on_renderer_restart_button_pressed)
	body.add_child(btn_renderer_restart)

	fsr_section = VBoxContainer.new()
	fsr_section.add_theme_constant_override("separation", 14)
	body.add_child(fsr_section)
	_add_section_title(fsr_section, "FSR UPSCALING")
	_add_hint(fsr_section, "Available with Forward+. Best when 3D Quality is below 100%. Lower sharpness is sharper.")
	option_fsr_mode = _add_option_row(fsr_section, "Upscale Method")
	option_fsr_mode.add_item("Bilinear")
	option_fsr_mode.add_item("FSR 1.0")
	option_fsr_mode.add_item("FSR 2.2")
	var sharpness_row: Array = _add_slider_row(fsr_section, "FSR Sharpness")
	slider_fsr_sharpness = sharpness_row[0] as HSlider
	label_fsr_sharpness = sharpness_row[1] as Label
	slider_fsr_sharpness.min_value = 0.0
	slider_fsr_sharpness.max_value = 2.0
	slider_fsr_sharpness.step = 0.05

	body.add_child(HSeparator.new())
	_add_section_title(body, "QUALITY")
	option_render_scale = _add_option_row(body, "3D Quality")
	option_render_scale.add_item("Low (50%)")
	option_render_scale.add_item("Medium (75%)")
	option_render_scale.add_item("High (100%)")
	option_render_scale.add_item("Ultra (125%)")
	option_shadows = _add_option_row(body, "Shadows")
	option_shadows.add_item("Off")
	option_shadows.add_item("Low")
	option_shadows.add_item("Medium")
	option_shadows.add_item("High")
	option_anti_aliasing = _add_option_row(body, "Anti-Aliasing")
	option_anti_aliasing.add_item("Disabled")
	option_anti_aliasing.add_item("2x MSAA")
	option_anti_aliasing.add_item("4x MSAA")
	option_anti_aliasing.add_item("8x MSAA")
	option_anti_aliasing.add_item("FXAA")
	option_anisotropic = _add_option_row(body, "Anisotropic Filter")
	option_anisotropic.add_item("Off")
	option_anisotropic.add_item("2x")
	option_anisotropic.add_item("4x")
	option_anisotropic.add_item("8x")
	option_anisotropic.add_item("16x")
	return scroll


func _build_sound_page() -> Control:
	var scroll := _make_scroll_page()
	var body := _make_page_body(scroll)
	_add_section_title(body, "VOLUME")
	_add_hint(body, "Music is the race playlist. Sound effects are engines, items, and collisions.")
	var music_row: Array = _add_slider_row(body, "Music Volume")
	slider_music = music_row[0] as HSlider
	label_music_value = music_row[1] as Label
	var sfx_row: Array = _add_slider_row(body, "Sound Effects")
	slider_sfx = sfx_row[0] as HSlider
	label_sfx_value = sfx_row[1] as Label
	return scroll


func _build_gameplay_page() -> Control:
	var scroll := _make_scroll_page()
	var body := _make_page_body(scroll)
	_add_section_title(body, "CAMERA")
	_add_hint(body, "Isometric is the classic top-down view. Follower sits behind the cart.")
	option_camera_mode = _add_option_row(body, "Race Camera")
	option_camera_mode.add_item("Isometric")
	option_camera_mode.add_item("Follower")
	return scroll


func _build_input_page() -> Control:
	var scroll := _make_scroll_page()
	var body := _make_page_body(scroll)
	body.add_theme_constant_override("separation", 16)

	_add_section_title(body, "CONTROLS", COL_GOLD)
	_add_hint(body, "Player 1 is used in every mode (single player, splitscreen, and online). Player 2 is only used in splitscreen. Click a binding, then press a key, button, or stick.")

	remap_banner = Label.new()
	remap_banner.visible = false
	remap_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	remap_banner.add_theme_font_size_override("font_size", 18)
	remap_banner.add_theme_color_override("font_color", COL_GOLD)
	remap_banner.text = "Waiting for input..."
	body.add_child(remap_banner)

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 22)
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cards)

	var p1_card := _make_player_card(
		1,
		"PLAYER 1",
		"Used in every game mode",
		"Keyboard default: WASD  •  Boost: Space",
		COL_TEAL,
		"p1_",
		p1_buttons
	)
	var p2_card := _make_player_card(
		2,
		"PLAYER 2",
		"Splitscreen only",
		"Keyboard default: Arrow keys  •  Boost: Numpad 0",
		COL_ORANGE,
		"p2_",
		p2_buttons
	)
	cards.add_child(p1_card)
	cards.add_child(p2_card)
	return scroll


func _make_player_card(player_index: int, title: String, role: String, defaults_hint: String, accent: Color, prefix: String, buttons_map: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.1, 1)
	sb.set_corner_radius_all(12)
	sb.border_width_left = 6
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = accent
	card.add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	card.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	var header := Label.new()
	header.text = title
	header.add_theme_color_override("font_color", accent)
	header.add_theme_font_size_override("font_size", 24)
	col.add_child(header)

	var role_lbl := Label.new()
	role_lbl.text = role
	role_lbl.add_theme_color_override("font_color", Color(0.9, 0.92, 0.96, 1))
	role_lbl.add_theme_font_size_override("font_size", 15)
	col.add_child(role_lbl)

	var hint := Label.new()
	hint.text = defaults_hint
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.66, 0.7, 0.78, 1))
	hint.add_theme_font_size_override("font_size", 13)
	col.add_child(hint)

	var quick := HBoxContainer.new()
	quick.add_theme_constant_override("separation", 8)
	col.add_child(quick)

	var btn_kb := Button.new()
	btn_kb.text = "Keyboard Defaults"
	btn_kb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_kb.custom_minimum_size = Vector2(0, 36)
	btn_kb.pressed.connect(func():
		MusicManager.set_default_keyboard_bindings(player_index)
		update_keybind_buttons()
	)
	quick.add_child(btn_kb)

	var btn_gp := Button.new()
	btn_gp.text = "Gamepad Defaults"
	btn_gp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_gp.custom_minimum_size = Vector2(0, 36)
	btn_gp.pressed.connect(func():
		MusicManager.set_default_controller_bindings(player_index)
		update_keybind_buttons()
	)
	quick.add_child(btn_gp)

	col.add_child(HSeparator.new())

	for suffix_key in ACTION_LABELS:
		var suffix: String = String(suffix_key)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		col.add_child(row)

		var lbl := Label.new()
		lbl.text = ACTION_LABELS[suffix]
		lbl.custom_minimum_size = Vector2(170, 0)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 15)
		row.add_child(lbl)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(200, 36)
		btn.add_theme_font_size_override("font_size", 14)
		var full_action: String = prefix + suffix
		btn.pressed.connect(func(): start_remapping(full_action, btn))
		row.add_child(btn)
		buttons_map[suffix] = btn

	return card


func _load_values_from_manager() -> void:
	if check_fps:
		check_fps.button_pressed = MusicManager.show_fps
	if option_window_mode:
		option_window_mode.selected = MusicManager.window_mode
	if option_resolution:
		option_resolution.selected = MusicManager.resolution_index
	if check_vsync:
		check_vsync.button_pressed = MusicManager.vsync
	if option_anti_aliasing:
		option_anti_aliasing.selected = MusicManager.anti_aliasing
	if option_shadows:
		option_shadows.selected = MusicManager.shadow_quality_index
	if option_render_scale:
		option_render_scale.selected = MusicManager.render_scale_index
	if option_renderer:
		option_renderer.set_block_signals(true)
		option_renderer.selected = 1 if MusicManager.renderer_method == "forward_plus" else 0
		option_renderer.set_block_signals(false)
	if option_fsr_mode:
		option_fsr_mode.selected = MusicManager.scaling_3d_mode_index
	if slider_fsr_sharpness:
		slider_fsr_sharpness.set_block_signals(true)
		slider_fsr_sharpness.value = MusicManager.fsr_sharpness
		slider_fsr_sharpness.set_block_signals(false)
		_update_fsr_sharpness_label(MusicManager.fsr_sharpness)
	_update_fsr_section_visibility()
	_update_renderer_status()
	if option_anisotropic:
		option_anisotropic.selected = MusicManager.anisotropic_index
	if option_max_fps:
		option_max_fps.selected = MusicManager.max_fps_index
	if option_camera_mode:
		option_camera_mode.selected = 0 if MusicManager.use_isometric_camera else 1
	if slider_music:
		slider_music.value = MusicManager.music_volume
		_update_volume_label(label_music_value, MusicManager.music_volume)
	if slider_sfx:
		slider_sfx.value = MusicManager.sfx_volume
		_update_volume_label(label_sfx_value, MusicManager.sfx_volume)


func _connect_setting_signals() -> void:
	check_fps.toggled.connect(func(v): MusicManager.set_show_fps(v))
	option_window_mode.item_selected.connect(func(i): MusicManager.set_window_mode(i))
	option_resolution.item_selected.connect(func(i): MusicManager.set_resolution(i))
	check_vsync.toggled.connect(func(v): MusicManager.set_vsync(v))
	option_anti_aliasing.item_selected.connect(func(i): MusicManager.set_anti_aliasing(i))
	option_shadows.item_selected.connect(func(i): MusicManager.set_shadow_quality(i))
	option_render_scale.item_selected.connect(func(i): MusicManager.set_render_scale(i))
	option_renderer.item_selected.connect(_on_renderer_selected)
	option_fsr_mode.item_selected.connect(_on_fsr_mode_selected)
	slider_fsr_sharpness.value_changed.connect(func(v):
		MusicManager.set_fsr_sharpness(v)
		_update_fsr_sharpness_label(v)
	)
	option_anisotropic.item_selected.connect(func(i): MusicManager.set_anisotropic(i))
	option_max_fps.item_selected.connect(func(i): MusicManager.set_max_fps(i))
	option_camera_mode.item_selected.connect(func(i): MusicManager.set_use_isometric_camera(i == 0))
	slider_music.value_changed.connect(func(v):
		MusicManager.set_music_volume(v)
		_update_volume_label(label_music_value, v)
	)
	slider_sfx.value_changed.connect(func(v):
		MusicManager.set_sfx_volume(v)
		_update_volume_label(label_sfx_value, v)
	)


func _update_volume_label(lbl: Label, value: float) -> void:
	if lbl:
		lbl.text = "%d%%" % int(round(value * 100.0))


func _update_fsr_sharpness_label(value: float) -> void:
	if label_fsr_sharpness:
		label_fsr_sharpness.text = "%.2f" % value


func _update_fsr_section_visibility() -> void:
	if fsr_section:
		fsr_section.visible = MusicManager.is_forward_plus()
	if slider_fsr_sharpness:
		slider_fsr_sharpness.editable = MusicManager.is_forward_plus() and MusicManager.scaling_3d_mode_index > 0


func _renderer_display_name(method: String) -> String:
	return "Forward+" if method == "forward_plus" else "Mobile"


func _update_renderer_status() -> void:
	var current := MusicManager.get_current_rendering_method()
	var wanted := MusicManager.renderer_method
	var mismatch: bool = wanted != current
	if label_renderer_status:
		if mismatch:
			label_renderer_status.text = "Currently running %s. Restart to apply %s." % [
				_renderer_display_name(current), _renderer_display_name(wanted)
			]
		else:
			label_renderer_status.text = "Currently running %s." % _renderer_display_name(current)
	if btn_renderer_restart:
		btn_renderer_restart.visible = mismatch
		btn_renderer_restart.text = "Restart to apply %s" % _renderer_display_name(wanted)


func _on_fsr_mode_selected(index: int) -> void:
	MusicManager.set_scaling_3d_mode(index)
	_update_fsr_section_visibility()


func _on_renderer_restart_button_pressed() -> void:
	_pending_renderer = MusicManager.renderer_method
	_prompt_renderer_restart(_pending_renderer)


func _on_renderer_selected(index: int) -> void:
	var wanted: String = "forward_plus" if index == 1 else "mobile"
	if wanted == MusicManager.get_current_rendering_method():
		MusicManager.set_renderer_method(wanted)
		_update_renderer_status()
		return
	_prompt_renderer_restart(wanted)


func _prompt_renderer_restart(wanted: String) -> void:
	_pending_renderer = wanted
	_ensure_renderer_restart_dialog()
	var from_name := _renderer_display_name(MusicManager.get_current_rendering_method())
	var to_name := _renderer_display_name(wanted)
	renderer_restart_dialog.dialog_text = "Switching from %s to %s requires restarting the game.\nRestart now?" % [from_name, to_name]
	renderer_restart_dialog.popup_centered()


func _ensure_renderer_restart_dialog() -> void:
	if renderer_restart_dialog:
		return
	var dlg := ConfirmationDialog.new()
	dlg.title = "Restart Required"
	dlg.dialog_text = "Switching renderer requires restarting the game.\nRestart now?"
	dlg.ok_button_text = "Restart"
	dlg.cancel_button_text = "Cancel"
	dlg.unresizable = true
	dlg.exclusive = true
	dlg.confirmed.connect(_on_renderer_restart_confirmed)
	dlg.canceled.connect(_on_renderer_restart_canceled)
	add_child(dlg)
	renderer_restart_dialog = dlg


func _on_renderer_restart_confirmed() -> void:
	if _pending_renderer != "mobile" and _pending_renderer != "forward_plus":
		_revert_renderer_dropdown()
		return
	MusicManager.set_renderer_method(_pending_renderer)
	MusicManager.restart_with_renderer(_pending_renderer)


func _on_renderer_restart_canceled() -> void:
	_pending_renderer = ""
	_revert_renderer_dropdown()
	_update_renderer_status()


func _revert_renderer_dropdown() -> void:
	if option_renderer == null:
		return
	option_renderer.set_block_signals(true)
	option_renderer.selected = 1 if MusicManager.renderer_method == "forward_plus" else 0
	option_renderer.set_block_signals(false)


func update_keybind_buttons() -> void:
	for suffix in p1_buttons:
		p1_buttons[suffix].text = MusicManager.get_action_friendly_text("p1_" + suffix)
	for suffix in p2_buttons:
		p2_buttons[suffix].text = MusicManager.get_action_friendly_text("p2_" + suffix)


func start_remapping(action_name: String, button: Button) -> void:
	if is_waiting_for_key:
		update_keybind_buttons()
	is_waiting_for_key = true
	waiting_action = action_name
	button.text = "Press key or button..."
	button.release_focus()
	if remap_banner:
		var player_label := "PLAYER 1" if action_name.begins_with("p1_") else "PLAYER 2"
		var suffix := action_name.substr(3)
		var action_label: String = ACTION_LABELS.get(suffix, suffix)
		remap_banner.text = "Listening for %s  —  %s   (Esc to cancel)" % [player_label, action_label]
		remap_banner.add_theme_color_override("font_color", COL_TEAL if action_name.begins_with("p1_") else COL_ORANGE)
		remap_banner.visible = true


func _find_button_for_action(action_name: String) -> Button:
	var suffix := action_name.substr(3)
	if action_name.begins_with("p1_"):
		return p1_buttons.get(suffix, null)
	return p2_buttons.get(suffix, null)


func _input(event: InputEvent) -> void:
	if not visible or not is_waiting_for_key:
		return

	var is_valid_input := false
	var captured_event: InputEvent = null

	if event is InputEventKey and event.pressed:
		if event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE:
			is_waiting_for_key = false
			update_keybind_buttons()
			if remap_banner:
				remap_banner.visible = false
			get_viewport().set_input_as_handled()
			return
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
		if remap_banner:
			remap_banner.visible = false
		get_viewport().set_input_as_handled()
		var btn := _find_button_for_action(waiting_action)
		if btn:
			btn.grab_focus()


func _on_back_pressed() -> void:
	is_waiting_for_key = false
	if remap_banner:
		remap_banner.visible = false
	back_pressed.emit()
	hide()
