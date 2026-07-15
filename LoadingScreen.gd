extends CanvasLayer

## Fullscreen loading overlay used during race load / stage swaps.

var _label: Label
var _status: Label
var _bar: ProgressBar
var _anim_time: float = 0.0
var _base_status: String = "Loading"
var _progress: float = 0.0

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.05, 0.08, 0.94)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(vbox)

	_label = Label.new()
	_label.name = "Title"
	_label.text = "RC VIBE GP"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 42)
	_label.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0, 1.0))
	vbox.add_child(_label)

	_status = Label.new()
	_status.name = "Status"
	_status.text = "Loading..."
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 22)
	_status.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95, 0.9))
	vbox.add_child(_status)

	_bar = ProgressBar.new()
	_bar.name = "Bar"
	_bar.custom_minimum_size = Vector2(320, 14)
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.value = 0.0
	_bar.show_percentage = false
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.0, 0.8, 1.0, 1.0)
	fill.set_corner_radius_all(6)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.14, 0.18, 0.95)
	bg.set_corner_radius_all(6)
	bg.border_color = Color(0.0, 0.8, 1.0, 0.25)
	bg.set_border_width_all(1)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", bg)
	vbox.add_child(_bar)

	set_process(false)


func show_loading(message: String = "Loading...") -> void:
	_base_status = message
	_status.text = message
	_progress = 0.05
	_bar.value = _progress
	visible = true
	set_process(true)
	# Ensure a frame paints before heavy work continues.
	await get_tree().process_frame


func set_status(message: String) -> void:
	_base_status = message
	_status.text = message


func set_progress(amount: float) -> void:
	_progress = clampf(amount, 0.0, 1.0)
	if _bar:
		_bar.value = _progress


func hide_loading() -> void:
	_progress = 1.0
	if _bar:
		_bar.value = 1.0
	# Brief beat so the bar can hit full before fade-out.
	await get_tree().process_frame
	visible = false
	set_process(false)
	_progress = 0.0
	if _bar:
		_bar.value = 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_anim_time += delta
	# Animated ellipsis
	var dots := int(_anim_time * 3.0) % 4
	_status.text = _base_status + ".".repeat(dots)
	# Creep the bar slowly so it never looks frozen during long loads.
	if _progress < 0.9:
		_progress = minf(0.9, _progress + delta * 0.12)
		_bar.value = _progress
