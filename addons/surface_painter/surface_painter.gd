@tool
extends EditorPlugin

const PaintEngine = preload("res://addons/surface_painter/paint_engine.gd")
const BrushProjector = preload("res://addons/surface_painter/brush_projector.gd")
const PainterDock = preload("res://addons/surface_painter/painter_dock.gd")

const SHADER_PATH = "res://addons/surface_painter/shaders/surface_paint.gdshader"
const DOCK_NAME = "Surface Painter"

var dock: PainterDock
var brush_projector: BrushProjector
var paint_engine: PaintEngine

var is_paint_mode_active: bool = false
var current_target_node: Node3D = null
var current_target_material: ShaderMaterial = null

var viewport_toolbar_btn: Button
var temporary_erase_mode: bool = false
var saved_brush_mode: int = 0


func _enter_tree():
	# 1. Initialize Engine & Brush Projector
	paint_engine = PaintEngine.new()
	brush_projector = BrushProjector.new()
	get_editor_interface().get_editor_main_screen().add_child(brush_projector)

	# 2. Build Dock UI
	dock = PainterDock.new()
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, dock)

	# 3. Viewport 3D Toolbar Button
	viewport_toolbar_btn = Button.new()
	viewport_toolbar_btn.text = "🎨 Paint Surface"
	viewport_toolbar_btn.toggle_mode = true
	viewport_toolbar_btn.flat = true
	viewport_toolbar_btn.toggled.connect(_on_toolbar_toggle)
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, viewport_toolbar_btn)

	# 4. Connect Dock Signals
	dock.paint_mode_toggled.connect(_on_paint_mode_toggled)
	dock.layer_selected.connect(_on_layer_selected)
	dock.brush_mode_changed.connect(_on_brush_mode_changed)
	dock.radius_changed.connect(_on_radius_changed)
	dock.strength_changed.connect(_on_strength_changed)
	dock.hardness_changed.connect(_on_hardness_changed)
	dock.setup_target_requested.connect(_on_setup_target_requested)
	dock.save_splatmap_requested.connect(_on_save_splatmap_requested)
	dock.clear_layer_requested.connect(_on_clear_layer_requested)

	# 5. Connect Editor Selection
	get_editor_interface().get_selection().selection_changed.connect(_on_selection_changed)
	_on_selection_changed()

	print("Surface Painter Plugin v1.0.0 enabled successfully.")


func _exit_tree():
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()
	if viewport_toolbar_btn:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, viewport_toolbar_btn)
		viewport_toolbar_btn.queue_free()
	if brush_projector and is_instance_valid(brush_projector):
		brush_projector.queue_free()


func _handles(object: Object) -> bool:
	# Plugin handles 3D nodes when paint mode is active
	return is_paint_mode_active


func _forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
	if not is_paint_mode_active or not viewport_camera:
		if brush_projector:
			brush_projector.hide_brush()
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	# --- Keyboard Shortcuts (Brush resize with [ and ], Shift for quick erase) ---
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed:
			if key_event.keycode == KEY_BRACKETLEFT:
				var new_r = max(paint_engine.brush_radius - 2.0, 1.0)
				paint_engine.brush_radius = new_r
				dock.set_brush_radius(new_r)
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			elif key_event.keycode == KEY_BRACKETRIGHT:
				var new_r = min(paint_engine.brush_radius + 2.0, 200.0)
				paint_engine.brush_radius = new_r
				dock.set_brush_radius(new_r)
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			elif key_event.keycode == KEY_SHIFT and not temporary_erase_mode:
				temporary_erase_mode = true
				saved_brush_mode = paint_engine.brush_mode
				paint_engine.brush_mode = PaintEngine.BrushMode.ERASE
		elif not key_event.pressed and key_event.keycode == KEY_SHIFT and temporary_erase_mode:
			temporary_erase_mode = false
			paint_engine.brush_mode = saved_brush_mode as PaintEngine.BrushMode

	# --- Mouse Raycasting & Painting ---
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		var mouse_pos: Vector2 = event.position
		var hit = _raycast_surface(viewport_camera, mouse_pos)

		if hit["has_hit"]:
			var hit_pos: Vector3 = hit["position"]
			var hit_normal: Vector3 = hit["normal"]
			var brush_color = _get_current_brush_color()

			brush_projector.update_brush(hit_pos, hit_normal, paint_engine.brush_radius, paint_engine.brush_hardness, brush_color)

			if event is InputEventMouseButton:
				var mb := event as InputEventMouseButton
				if mb.button_index == MOUSE_BUTTON_LEFT:
					if mb.pressed:
						paint_engine.begin_stroke()
						paint_engine.paint_at_world(hit_pos)
						return EditorPlugin.AFTER_GUI_INPUT_STOP
					else:
						if paint_engine.is_painting_stroke:
							paint_engine.end_stroke(get_undo_redo())
							return EditorPlugin.AFTER_GUI_INPUT_STOP

			elif event is InputEventMouseMotion:
				var mm := event as InputEventMouseMotion
				if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
					if not paint_engine.is_painting_stroke:
						paint_engine.begin_stroke()
					paint_engine.paint_at_world(hit_pos)
					return EditorPlugin.AFTER_GUI_INPUT_STOP
		else:
			brush_projector.hide_brush()
			if event is InputEventMouseButton:
				var mb := event as InputEventMouseButton
				if not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and paint_engine.is_painting_stroke:
					paint_engine.end_stroke(get_undo_redo())

	return EditorPlugin.AFTER_GUI_INPUT_PASS


func _raycast_surface(camera: Camera3D, screen_pos: Vector2) -> Dictionary:
	var from = camera.project_ray_origin(screen_pos)
	var dir = camera.project_ray_normal(screen_pos)
	var to = from + dir * 5000.0

	var space_state = camera.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var result = space_state.intersect_ray(query)
	if not result.is_empty():
		return {
			"has_hit": true,
			"position": result["position"],
			"normal": result["normal"]
		}

	# Fallback: Check intersection with target mesh or horizontal XZ plane
	if current_target_node:
		var target_pos = current_target_node.global_position
		var plane = Plane(Vector3.UP, target_pos.y)
		var hit_plane = plane.intersects_ray(from, dir)
		if hit_plane != null:
			return {
				"has_hit": true,
				"position": hit_plane,
				"normal": Vector3.UP
			}

	return {"has_hit": false}


func _on_selection_changed():
	var selection = get_editor_interface().get_selection().get_selected_nodes()
	if selection.is_empty():
		current_target_node = null
		current_target_material = null
		dock.set_target_info("", false)
		return

	var selected = selection[0]
	if selected is Node3D:
		current_target_node = selected as Node3D
		current_target_material = _extract_paint_material(selected)
		var has_paint_mat = current_target_material != null
		var map_path = paint_engine.splatmap_file_path if (has_paint_mat and paint_engine) else ""
		dock.set_target_info(selected.name, has_paint_mat, map_path)

		if has_paint_mat:
			_attach_target_material(current_target_material)


func _extract_paint_material(node: Node) -> ShaderMaterial:
	var candidate_mat: Material = null

	if node is GeometryInstance3D:
		if node.material_override:
			candidate_mat = node.material_override
	if not candidate_mat and node is MeshInstance3D and node.mesh:
		if node.get_surface_override_material(0):
			candidate_mat = node.get_surface_override_material(0)
		elif node.mesh.surface_get_material(0):
			candidate_mat = node.mesh.surface_get_material(0)
	if not candidate_mat and node is CSGShape3D:
		if node.material:
			candidate_mat = node.material
	if not candidate_mat and "grass_material" in node:
		candidate_mat = node.get("grass_material")

	if candidate_mat is ShaderMaterial:
		var sm = candidate_mat as ShaderMaterial
		if sm.shader and (sm.shader.resource_path.contains("surface_paint") or sm.get_shader_parameter("splatmap_texture") != null):
			return sm

	return null


func _attach_target_material(mat: ShaderMaterial):
	current_target_material = mat
	var existing_splat = mat.get_shader_parameter("splatmap_texture")

	var splat_img: Image = null
	var splat_path: String = ""

	if existing_splat is Texture2D:
		if existing_splat.resource_path != "":
			splat_path = existing_splat.resource_path
		splat_img = existing_splat.get_image()

	paint_engine.setup_splatmap(mat, splat_img, splat_path)


func _on_paint_mode_toggled(active: bool):
	is_paint_mode_active = active
	viewport_toolbar_btn.set_pressed_no_signal(active)
	if not active and brush_projector:
		brush_projector.hide_brush()
	update_overlays()


func _on_toolbar_toggle(pressed: bool):
	is_paint_mode_active = pressed
	dock.set_paint_active(pressed)
	if not pressed and brush_projector:
		brush_projector.hide_brush()
	update_overlays()


func _on_layer_selected(layer_id: int):
	paint_engine.active_layer = layer_id as PaintEngine.PaintLayer


func _on_brush_mode_changed(mode_id: int):
	paint_engine.brush_mode = mode_id as PaintEngine.BrushMode


func _on_radius_changed(radius: float):
	paint_engine.brush_radius = radius


func _on_strength_changed(strength: float):
	paint_engine.brush_strength = strength


func _on_hardness_changed(hardness: float):
	paint_engine.brush_hardness = hardness


func _on_clear_layer_requested():
	paint_engine.clear_all(paint_engine.active_layer)


func _on_save_splatmap_requested():
	var default_name = current_target_node.name.to_lower() if current_target_node else "surface"
	var save_path = "res://terrain/paint_maps/%s_splatmap.png" % default_name
	var err = paint_engine.save_to_disk(save_path)
	if err == OK:
		# Reload texture resource and rebind to material
		var reloaded_tex = ResourceLoader.load(save_path, "Texture2D", ResourceLoader.CACHE_MODE_REPLACE)
		if reloaded_tex and current_target_material:
			current_target_material.set_shader_parameter("splatmap_texture", reloaded_tex)
		dock.set_target_info(current_target_node.name if current_target_node else "Target", true, save_path)


func _on_setup_target_requested():
	if not current_target_node:
		printerr("SurfacePainter: Please select a MeshInstance3D, CSGShape3D, or Terrain node first.")
		return

	var shader = load(SHADER_PATH) as Shader
	if not shader:
		printerr("SurfacePainter: Could not load shader at ", SHADER_PATH)
		return

	var new_mat = ShaderMaterial.new()
	new_mat.shader = shader

	# Load default textures
	var sand_tex = load("res://materials/sand.png") as Texture2D
	var sand_norm = load("res://materials/sand_normal.png") as Texture2D
	var rock_tex = load("res://materials/dark_canyon_rock.png") as Texture2D
	var rock_norm = load("res://materials/dark_canyon_rock_normal.png") as Texture2D
	var dirt_tex = load("res://materials/dirt.png") as Texture2D
	var dirt_norm = load("res://materials/dirt_normal.png") as Texture2D
	var brick_tex = load("res://materials/brick.png") as Texture2D

	if sand_tex:
		new_mat.set_shader_parameter("tex_base", sand_tex)
		new_mat.set_shader_parameter("albedo_base", Color(1.0, 0.98, 0.94, 1.0))
		new_mat.set_shader_parameter("uv_scale_base", 16.0)
		new_mat.set_shader_parameter("roughness_base", 0.94)
		new_mat.set_shader_parameter("use_triplanar_base", true)
		if sand_norm:
			new_mat.set_shader_parameter("use_normal_base", true)
			new_mat.set_shader_parameter("normal_base", sand_norm)
			new_mat.set_shader_parameter("normal_scale_base", 0.85)

	if rock_tex:
		new_mat.set_shader_parameter("tex_layer1", rock_tex)
		new_mat.set_shader_parameter("albedo_layer1", Color(0.9, 0.82, 0.72, 1.0))
		new_mat.set_shader_parameter("uv_scale_layer1", 12.0)
		new_mat.set_shader_parameter("use_triplanar_layer1", true)
		if rock_norm:
			new_mat.set_shader_parameter("use_normal_layer1", true)
			new_mat.set_shader_parameter("normal_layer1", rock_norm)
			new_mat.set_shader_parameter("normal_scale_layer1", 0.75)

	if dirt_tex:
		new_mat.set_shader_parameter("tex_layer2", dirt_tex)
		new_mat.set_shader_parameter("albedo_layer2", Color(0.7, 0.6, 0.5, 1.0))
		new_mat.set_shader_parameter("uv_scale_layer2", 18.0)
		if dirt_norm:
			new_mat.set_shader_parameter("use_normal_layer2", true)
			new_mat.set_shader_parameter("normal_layer2", dirt_norm)

	if brick_tex:
		new_mat.set_shader_parameter("tex_layer3", brick_tex)
		new_mat.set_shader_parameter("uv_scale_layer3", 20.0)

	new_mat.set_shader_parameter("use_world_splatmap", true)
	new_mat.set_shader_parameter("world_bounds_origin", Vector2(-1000.0, -1000.0))
	new_mat.set_shader_parameter("world_bounds_size", Vector2(2000.0, 2000.0))
	new_mat.set_shader_parameter("use_stochastic", true)
	new_mat.set_shader_parameter("enable_edge_fade", true)
	new_mat.set_shader_parameter("edge_fade_start", 550.0)
	new_mat.set_shader_parameter("edge_fade_end", 960.0)

	# Assign to node
	if current_target_node is CSGShape3D:
		current_target_node.material = new_mat
	elif current_target_node is GeometryInstance3D:
		current_target_node.material_override = new_mat
	elif "grass_material" in current_target_node:
		current_target_node.set("grass_material", new_mat)

	# Setup paint engine
	var splat_name = current_target_node.name.to_lower()
	var splat_path = "res://terrain/paint_maps/%s_splatmap.png" % splat_name
	paint_engine.setup_splatmap(new_mat, null, splat_path)
	paint_engine.save_to_disk(splat_path)

	current_target_material = new_mat
	dock.set_target_info(current_target_node.name, true, splat_path)
	print("SurfacePainter: Initialized paint material on ", current_target_node.name)


func _get_current_brush_color() -> Color:
	match paint_engine.brush_mode:
		PaintEngine.BrushMode.ERASE:
			return Color(0.2, 0.9, 1.0, 0.85) # Cyan for Erase
		PaintEngine.BrushMode.SMOOTH:
			return Color(1.0, 0.85, 0.2, 0.85) # Yellow for Smooth
		PaintEngine.BrushMode.PAINT:
			match paint_engine.active_layer:
				PaintEngine.PaintLayer.BASE:
					return Color(1.0, 0.95, 0.8, 0.85) # Tan/Base
				PaintEngine.PaintLayer.LAYER_1_RED:
					return Color(1.0, 0.3, 0.2, 0.85) # Red/Rock
				PaintEngine.PaintLayer.LAYER_2_GREEN:
					return Color(0.3, 0.9, 0.3, 0.85) # Green/Dirt
				PaintEngine.PaintLayer.LAYER_3_BLUE:
					return Color(0.3, 0.5, 1.0, 0.85) # Blue/Stone
	return Color(1.0, 1.0, 1.0, 0.85)
