@tool
extends RefCounted
class_name PaintEngine

enum BrushMode {
	PAINT,
	ERASE,
	SMOOTH
}

enum PaintLayer {
	BASE = 0,
	LAYER_1_RED = 1,
	LAYER_2_GREEN = 2,
	LAYER_3_BLUE = 3
}

# --- Painting Settings ---
var brush_mode: BrushMode = BrushMode.PAINT
var active_layer: PaintLayer = PaintLayer.LAYER_1_RED
var brush_radius: float = 12.0       # World units (e.g. meters)
var brush_strength: float = 0.35    # 0.0 to 1.0
var brush_hardness: float = 0.40    # 0.0 (soft Gaussian) to 1.0 (hard)
var brush_spacing: float = 0.25     # Fractional step of radius

# --- World Bounds for World-Space Splatmap ---
var world_bounds_origin: Vector2 = Vector2(-1000.0, -1000.0)
var world_bounds_size: Vector2 = Vector2(2000.0, 2000.0)

# --- Active Splatmap Image & Texture ---
var target_material: ShaderMaterial
var splatmap_image: Image
var splatmap_texture: ImageTexture
var splatmap_file_path: String = ""

# --- Stroke Tracking ---
var is_painting_stroke: bool = false
var has_last_pos: bool = false
var last_paint_pos: Vector2 = Vector2.ZERO
var stroke_initial_image: Image
var is_dirty: bool = false


func setup_splatmap(mat: ShaderMaterial, initial_image: Image = null, file_path: String = ""):
	target_material = mat
	splatmap_file_path = file_path

	if mat:
		if mat.get_shader_parameter("world_bounds_origin") != null:
			world_bounds_origin = mat.get_shader_parameter("world_bounds_origin")
		if mat.get_shader_parameter("world_bounds_size") != null:
			world_bounds_size = mat.get_shader_parameter("world_bounds_size")

	if initial_image:
		splatmap_image = initial_image
		if splatmap_image.get_format() != Image.FORMAT_RGBA8:
			splatmap_image.convert(Image.FORMAT_RGBA8)
	else:
		# Create default blank 1024x1024 RGBA image (0,0,0,0 = 100% Base Layer)
		splatmap_image = Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
		splatmap_image.fill(Color(0.0, 0.0, 0.0, 0.0))

	splatmap_texture = ImageTexture.create_from_image(splatmap_image)
	if target_material:
		target_material.set_shader_parameter("splatmap_texture", splatmap_texture)


func begin_stroke():
	if not splatmap_image:
		return
	is_painting_stroke = true
	has_last_pos = false
	stroke_initial_image = Image.new()
	stroke_initial_image.copy_from(splatmap_image)


func end_stroke(undo_redo: EditorUndoRedoManager = null):
	if not is_painting_stroke:
		return
	is_painting_stroke = false
	has_last_pos = false

	if undo_redo and stroke_initial_image and splatmap_image and is_dirty:
		var img_before = Image.new()
		img_before.copy_from(stroke_initial_image)
		var img_after = Image.new()
		img_after.copy_from(splatmap_image)

		undo_redo.create_action("Surface Paint Stroke")
		undo_redo.add_do_method(self, "_apply_image_state", img_after)
		undo_redo.add_undo_method(self, "_apply_image_state", img_before)
		undo_redo.commit_action(false)

	stroke_initial_image = null
	is_dirty = false


func _apply_image_state(img: Image):
	if not splatmap_image or not img:
		return
	splatmap_image.copy_from(img)
	flush_texture()


func paint_at_world(world_pos_3d: Vector3):
	if not splatmap_image:
		return

	var current_pos_2d = Vector2(world_pos_3d.x, world_pos_3d.z)

	if not has_last_pos:
		stamp_world(current_pos_2d)
		last_paint_pos = current_pos_2d
		has_last_pos = true
	else:
		var dist = last_paint_pos.distance_to(current_pos_2d)
		var step_dist = max(brush_radius * brush_spacing, 0.5)
		if dist >= step_dist:
			var steps = int(floor(dist / step_dist))
			for i in range(1, steps + 1):
				var p = last_paint_pos.lerp(current_pos_2d, float(i) / float(steps))
				stamp_world(p)
			last_paint_pos = current_pos_2d
		elif dist > 0.001:
			stamp_world(current_pos_2d)
			last_paint_pos = current_pos_2d

	flush_texture()


func stamp_world(world_xz: Vector2):
	if not splatmap_image:
		return

	var img_w = splatmap_image.get_width()
	var img_h = splatmap_image.get_height()

	# Convert world coordinates to UV (0.0 to 1.0)
	var uv_x = (world_xz.x - world_bounds_origin.x) / max(world_bounds_size.x, 0.001)
	var uv_y = (world_xz.y - world_bounds_origin.y) / max(world_bounds_size.y, 0.001)

	# Convert to pixel space
	var center_px = uv_x * float(img_w)
	var center_py = uv_y * float(img_h)

	# Radius in pixel space
	var radius_px = (brush_radius / max(world_bounds_size.x, 0.001)) * float(img_w)
	if radius_px < 1.0:
		radius_px = 1.0

	_rasterize_brush(center_px, center_py, radius_px)


func _rasterize_brush(center_px: float, center_py: float, radius_px: float):
	var img_w = splatmap_image.get_width()
	var img_h = splatmap_image.get_height()

	var min_x = int(clamp(floor(center_px - radius_px), 0, img_w - 1))
	var max_x = int(clamp(ceil(center_px + radius_px), 0, img_w - 1))
	var min_y = int(clamp(floor(center_py - radius_px), 0, img_h - 1))
	var max_y = int(clamp(ceil(center_py + radius_px), 0, img_h - 1))

	var rad_sq = radius_px * radius_px
	var hardness = clamp(brush_hardness, 0.0, 0.999)

	for y in range(min_y, max_y + 1):
		var dy = float(y) - center_py
		var dy_sq = dy * dy
		for x in range(min_x, max_x + 1):
			var dx = float(x) - center_px
			var dist_sq = dx * dx + dy_sq
			if dist_sq <= rad_sq:
				var dist = sqrt(dist_sq)
				var norm_dist = dist / radius_px
				
				# Smooth falloff based on hardness
				var falloff: float
				if norm_dist <= hardness:
					falloff = 1.0
				else:
					var t = (norm_dist - hardness) / (1.0 - hardness)
					falloff = 1.0 - (t * t * (3.0 - 2.0 * t)) # Hermite smoothstep
				
				var alpha = clamp(falloff * brush_strength, 0.0, 1.0)
				if alpha <= 0.001:
					continue

				var current_col = splatmap_image.get_pixel(x, y)
				var new_col = _blend_color(current_col, alpha, x, y)
				splatmap_image.set_pixel(x, y, new_col)
				is_dirty = true


func _blend_color(current: Color, alpha: float, px: int, py: int) -> Color:
	match brush_mode:
		BrushMode.PAINT:
			match active_layer:
				PaintLayer.BASE:
					# Painting base layer reduces layers 1, 2, 3
					var r = lerp(current.r, 0.0, alpha)
					var g = lerp(current.g, 0.0, alpha)
					var b = lerp(current.b, 0.0, alpha)
					return Color(r, g, b, 0.0)

				PaintLayer.LAYER_1_RED:
					var target_r = lerp(current.r, 1.0, alpha)
					# Reduce other layers proportionally if sum > 1.0
					var excess = max((target_r + current.g + current.b) - 1.0, 0.0)
					var g = max(current.g - excess * 0.5, 0.0)
					var b = max(current.b - excess * 0.5, 0.0)
					return Color(target_r, g, b, 0.0)

				PaintLayer.LAYER_2_GREEN:
					var target_g = lerp(current.g, 1.0, alpha)
					var excess = max((current.r + target_g + current.b) - 1.0, 0.0)
					var r = max(current.r - excess * 0.5, 0.0)
					var b = max(current.b - excess * 0.5, 0.0)
					return Color(r, target_g, b, 0.0)

				PaintLayer.LAYER_3_BLUE:
					var target_b = lerp(current.b, 1.0, alpha)
					var excess = max((current.r + current.g + target_b) - 1.0, 0.0)
					var r = max(current.r - excess * 0.5, 0.0)
					var g = max(current.g - excess * 0.5, 0.0)
					return Color(r, g, target_b, 0.0)

		BrushMode.ERASE:
			# Erase the active layer or reduce all paint layers
			match active_layer:
				PaintLayer.LAYER_1_RED:
					return Color(lerp(current.r, 0.0, alpha), current.g, current.b, 0.0)
				PaintLayer.LAYER_2_GREEN:
					return Color(current.r, lerp(current.g, 0.0, alpha), current.b, 0.0)
				PaintLayer.LAYER_3_BLUE:
					return Color(current.r, current.g, lerp(current.b, 0.0, alpha), 0.0)
				PaintLayer.BASE:
					return Color(lerp(current.r, 0.0, alpha), lerp(current.g, 0.0, alpha), lerp(current.b, 0.0, alpha), 0.0)

		BrushMode.SMOOTH:
			# Blur with 4-neighborhood
			var img_w = splatmap_image.get_width()
			var img_h = splatmap_image.get_height()
			var left = splatmap_image.get_pixel(max(px - 1, 0), py)
			var right = splatmap_image.get_pixel(min(px + 1, img_w - 1), py)
			var up = splatmap_image.get_pixel(px, max(py - 1, 0))
			var down = splatmap_image.get_pixel(px, min(py + 1, img_h - 1))
			var avg = (current + left + right + up + down) * 0.2
			return current.lerp(avg, alpha)

	return current


func flush_texture():
	if not splatmap_image:
		return
	if not splatmap_texture:
		splatmap_texture = ImageTexture.create_from_image(splatmap_image)
		if target_material:
			target_material.set_shader_parameter("splatmap_texture", splatmap_texture)
	else:
		splatmap_texture.update(splatmap_image)


func clear_all(layer: PaintLayer = PaintLayer.BASE):
	if not splatmap_image:
		return
	match layer:
		PaintLayer.BASE:
			splatmap_image.fill(Color(0.0, 0.0, 0.0, 0.0))
		PaintLayer.LAYER_1_RED:
			splatmap_image.fill(Color(1.0, 0.0, 0.0, 0.0))
		PaintLayer.LAYER_2_GREEN:
			splatmap_image.fill(Color(0.0, 1.0, 0.0, 0.0))
		PaintLayer.LAYER_3_BLUE:
			splatmap_image.fill(Color(0.0, 0.0, 1.0, 0.0))
	flush_texture()


func save_to_disk(custom_path: String = "") -> Error:
	if not splatmap_image:
		return ERR_UNCONFIGURED

	var save_path = custom_path if custom_path != "" else splatmap_file_path
	if save_path == "":
		save_path = "res://terrain/paint_maps/splatmap_saved.png"

	# Ensure folder exists
	var dir_path = save_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir_path)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))

	var err = splatmap_image.save_png(save_path)
	if err == OK:
		splatmap_file_path = save_path
		print("SurfacePainter: Splatmap saved successfully to ", save_path)
	else:
		push_error("SurfacePainter: Failed to save splatmap to " + save_path + " (Error: " + str(err) + ")")
	return err
