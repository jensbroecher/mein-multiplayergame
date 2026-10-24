extends Node3D

# The seven item boxes, each showing its item's symbol (ItemSymbols.gd), in a row over a flat ground,
# with the HUD's symbols (ItemSymbolIcon.gd, in slot-sized panels) underneath. Windowed:
#   Godot --path . --resolution 1600x900 res://scratch/item_symbols_preview.tscn -- <out_dir> [wait=2.0]

const ItemSymbols = preload("res://ItemSymbols.gd")
const ItemSymbolIcon = preload("res://ItemSymbolIcon.gd")

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0]
	var wait := 2.0
	for a in args.slice(1):
		if a.begins_with("wait="): wait = float(a.substr(5))
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.42, 0.6, 0.85)
	e.ambient_light_color = Color(0.7, 0.75, 0.8)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 30)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.32, 0.34, 0.36)
	ground.material_override = gm
	add_child(ground)
	var n := ItemSymbols.NAMES.size()
	for i in n:
		var box: Node3D = load("res://ItemBox.tscn").instantiate()
		add_child(box)
		box.position = Vector3((i - (n - 1) * 0.5) * 2.6, 1.5, 0.0)
		box._show_item(i + 1)
	var cam := Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.position = Vector3(0, 2.6, 13.5)
	cam.look_at(Vector3(0, 1.5, 0))
	var layer := CanvasLayer.new()
	add_child(layer)
	var row := HBoxContainer.new()
	row.position = Vector2(60, get_viewport().get_visible_rect().size.y - 130)
	row.add_theme_constant_override("separation", 24)
	layer.add_child(row)
	for name in ItemSymbols.NAMES:
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(96, 96)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.12, 0.12, 0.75)
		sb.border_color = Color(1.0, 0.7, 0.0, 0.95)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(8)
		panel.add_theme_stylebox_override("panel", sb)
		var sym := ItemSymbolIcon.new()
		sym.item = name
		sym.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.add_child(sym)
		row.add_child(panel)
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/item_symbols.png" % out_dir)
	print("SHOT item_symbols")
	get_tree().quit()
