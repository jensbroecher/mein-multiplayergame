@tool
extends Control

const PaintEngine = preload("res://addons/surface_painter/paint_engine.gd")

signal paint_mode_toggled(active: bool)
signal layer_selected(layer: int)
signal brush_mode_changed(mode: int)
signal radius_changed(radius: float)
signal strength_changed(strength: float)
signal hardness_changed(hardness: float)
signal setup_target_requested()
signal save_splatmap_requested()
signal clear_layer_requested()

var paint_toggle_btn: Button
var target_info_label: Label
var setup_mat_btn: Button

var layer_group: ButtonGroup
var layer_buttons: Array[Button] = []

var mode_paint_btn: Button
var mode_erase_btn: Button
var mode_smooth_btn: Button

var radius_slider: HSlider
var radius_spin: SpinBox
var strength_slider: HSlider
var strength_spin: SpinBox
var hardness_slider: HSlider
var hardness_spin: SpinBox

var save_btn: Button
var clear_btn: Button

var is_active: bool = false


func _init():
	custom_minimum_size = Vector2(280, 480)
	_build_ui()


func _build_ui():
	# Root scroll container
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var root_box = VBoxContainer.new()
	root_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.add_theme_constant_override("separation", 8)
	scroll.add_child(root_box)

	# --- Title & Main Toggle ---
	var title_lbl = Label.new()
	title_lbl.text = "🎨 Surface Painter"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 16)
	root_box.add_child(title_lbl)

	paint_toggle_btn = Button.new()
	paint_toggle_btn.text = "🖌️ Enable Paint Mode"
	paint_toggle_btn.toggle_mode = true
	paint_toggle_btn.custom_minimum_size = Vector2(0, 36)
	paint_toggle_btn.toggled.connect(_on_paint_toggle)
	root_box.add_child(paint_toggle_btn)

	# --- Target Info Section ---
	var target_box = PanelContainer.new()
	var target_vbox = VBoxContainer.new()
	target_box.add_child(target_vbox)
	root_box.add_child(target_box)

	target_info_label = Label.new()
	target_info_label.text = "Target: Select a Mesh or CSG node"
	target_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	target_vbox.add_child(target_info_label)

	setup_mat_btn = Button.new()
	setup_mat_btn.text = "⚡ Setup Painting on Node"
	setup_mat_btn.pressed.connect(func(): setup_target_requested.emit())
	target_vbox.add_child(setup_mat_btn)

	root_box.add_child(HSeparator.new())

	# --- Layer Palette Section ---
	var layers_header = Label.new()
	layers_header.text = "Materials / Layers:"
	root_box.add_child(layers_header)

	layer_group = ButtonGroup.new()
	var layer_grid = GridContainer.new()
	layer_grid.columns = 2
	root_box.add_child(layer_grid)

	var layer_defs = [
		{"id": 0, "name": "Layer 0: Base (Ground)", "color": Color(0.9, 0.85, 0.7)},
		{"id": 1, "name": "Layer 1: Rock (Cliffs)", "color": Color(0.85, 0.35, 0.25)},
		{"id": 2, "name": "Layer 2: Dirt / Path", "color": Color(0.45, 0.75, 0.3)},
		{"id": 3, "name": "Layer 3: Gravel / Stone", "color": Color(0.4, 0.6, 0.9)}
	]

	for item in layer_defs:
		var btn = Button.new()
		btn.text = item["name"]
		btn.toggle_mode = true
		btn.button_group = layer_group
		btn.custom_minimum_size = Vector2(130, 32)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if item["id"] == 1:
			btn.button_pressed = true # Default to Layer 1 (Rock)
		var layer_id = item["id"]
		btn.toggled.connect(func(pressed: bool):
			if pressed:
				layer_selected.emit(layer_id)
		)
		layer_grid.add_child(btn)
		layer_buttons.append(btn)

	root_box.add_child(HSeparator.new())

	# --- Brush Mode Section ---
	var mode_header = Label.new()
	mode_header.text = "Brush Tool:"
	root_box.add_child(mode_header)

	var mode_hbox = HBoxContainer.new()
	root_box.add_child(mode_hbox)

	var mode_group = ButtonGroup.new()

	mode_paint_btn = Button.new()
	mode_paint_btn.text = "🖌️ Paint"
	mode_paint_btn.toggle_mode = true
	mode_paint_btn.button_group = mode_group
	mode_paint_btn.button_pressed = true
	mode_paint_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_paint_btn.toggled.connect(func(p): if p: brush_mode_changed.emit(PaintEngine.BrushMode.PAINT))
	mode_hbox.add_child(mode_paint_btn)

	mode_erase_btn = Button.new()
	mode_erase_btn.text = "🧹 Erase"
	mode_erase_btn.toggle_mode = true
	mode_erase_btn.button_group = mode_group
	mode_erase_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_erase_btn.toggled.connect(func(p): if p: brush_mode_changed.emit(PaintEngine.BrushMode.ERASE))
	mode_hbox.add_child(mode_erase_btn)

	mode_smooth_btn = Button.new()
	mode_smooth_btn.text = "💧 Smooth"
	mode_smooth_btn.toggle_mode = true
	mode_smooth_btn.button_group = mode_group
	mode_smooth_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_smooth_btn.toggled.connect(func(p): if p: brush_mode_changed.emit(PaintEngine.BrushMode.SMOOTH))
	mode_hbox.add_child(mode_smooth_btn)

	root_box.add_child(HSeparator.new())

	# --- Brush Parameters (Radius, Strength, Hardness) ---
	root_box.add_child(_create_slider_row("Brush Radius (m):", 1.0, 150.0, 12.0, 0.5, func(val):
		radius_changed.emit(val)
	, "radius"))

	root_box.add_child(_create_slider_row("Strength / Flow:", 0.05, 1.0, 0.35, 0.05, func(val):
		strength_changed.emit(val)
	, "strength"))

	root_box.add_child(_create_slider_row("Hardness / Falloff:", 0.0, 1.0, 0.40, 0.05, func(val):
		hardness_changed.emit(val)
	, "hardness"))

	root_box.add_child(HSeparator.new())

	# --- Actions Section ---
	save_btn = Button.new()
	save_btn.text = "💾 Save Splatmap PNG"
	save_btn.custom_minimum_size = Vector2(0, 32)
	save_btn.pressed.connect(func(): save_splatmap_requested.emit())
	root_box.add_child(save_btn)

	clear_btn = Button.new()
	clear_btn.text = "🗑️ Clear Active Layer"
	clear_btn.pressed.connect(func(): clear_layer_requested.emit())
	root_box.add_child(clear_btn)


func _create_slider_row(label_text: String, min_val: float, max_val: float, default_val: float, step_val: float, callback: Callable, prop_key: String) -> VBoxContainer:
	var vbox = VBoxContainer.new()
	var lbl = Label.new()
	lbl.text = label_text
	vbox.add_child(lbl)

	var hbox = HBoxContainer.new()
	vbox.add_child(hbox)

	var slider = HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.value = default_val
	slider.step = step_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(slider)

	var spin = SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.value = default_val
	spin.step = step_val
	spin.custom_minimum_size = Vector2(70, 0)
	hbox.add_child(spin)

	slider.value_changed.connect(func(v):
		spin.set_value_no_signal(v)
		callback.call(v)
	)
	spin.value_changed.connect(func(v):
		slider.set_value_no_signal(v)
		callback.call(v)
	)

	match prop_key:
		"radius":
			radius_slider = slider
			radius_spin = spin
		"strength":
			strength_slider = slider
			strength_spin = spin
		"hardness":
			hardness_slider = slider
			hardness_spin = spin

	return vbox


func _on_paint_toggle(pressed: bool):
	is_active = pressed
	paint_toggle_btn.text = "🛑 Exit Paint Mode" if is_active else "🖌️ Enable Paint Mode"
	paint_mode_toggled.emit(is_active)


func set_target_info(node_name: String, has_paint_mat: bool, path: String = ""):
	if node_name == "":
		target_info_label.text = "Target: None selected (Select a Mesh/CSG node)"
		setup_mat_btn.visible = false
	elif has_paint_mat:
		target_info_label.text = "Target: %s\n✓ Paint Material Ready" % node_name
		if path != "":
			target_info_label.text += "\nMap: %s" % path.get_file()
		setup_mat_btn.visible = false
	else:
		target_info_label.text = "Target: %s\n⚠ Needs Paint Material" % node_name
		setup_mat_btn.visible = true


func set_paint_active(active: bool):
	is_active = active
	paint_toggle_btn.set_pressed_no_signal(active)
	paint_toggle_btn.text = "🛑 Exit Paint Mode" if is_active else "🖌️ Enable Paint Mode"


func set_brush_radius(r: float):
	if radius_slider:
		radius_slider.set_value_no_signal(r)
	if radius_spin:
		radius_spin.set_value_no_signal(r)


func get_brush_radius() -> float:
	return radius_slider.value if radius_slider else 12.0


func get_brush_strength() -> float:
	return strength_slider.value if strength_slider else 0.35


func get_brush_hardness() -> float:
	return hardness_slider.value if hardness_slider else 0.40
