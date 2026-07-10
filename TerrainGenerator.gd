@tool
extends Node3D

enum TrackLayoutType { DEFAULT, MOUNTAIN, CANYON }

# Used to determine terrain shape (canyon walls, mountain slope, flat desert).
# Change this in the Inspector to match the level — it does NOT overwrite your custom path.
@export var track_layout_type: TrackLayoutType = TrackLayoutType.DEFAULT
@export var level_prefix: String = ""
@export var no_water: bool = false
@export var no_grass: bool = false

func _is_in_gap_pos(pos: Vector3) -> bool:
	# Gaps removed to keep the road continuous
	return false

func _get_terrain_height(px: float, pz: float, noise: FastNoiseLite, curve: Curve3D, for_collision: bool) -> float:
	var h_noise = noise.get_noise_2d(px, pz) * hill_height
	
	# --- Mountain base shape ---
	var radial_offset = 0.0
	if track_layout_type == TrackLayoutType.MOUNTAIN:
		var dist_from_center = Vector2(px, pz).length()
		var mountain_height = 145.0
		var mountain_base = 350.0
		var mountain_shape = clamp(1.0 - (dist_from_center / mountain_base), 0.0, 1.0)
		mountain_shape = mountain_shape * mountain_shape * (3.0 - 2.0 * mountain_shape)
		radial_offset = mountain_shape * mountain_height

	var base_terrain_height: float
	if track_layout_type == TrackLayoutType.MOUNTAIN:
		base_terrain_height = radial_offset + h_noise
		# Cap valley floor height near start gate area to prevent hills from blocking the bridge crossover
		if px > -110.0 and px < 60.0 and pz > -370.0 and pz < -230.0:
			base_terrain_height = min(base_terrain_height, 10.0)
	elif track_layout_type == TrackLayoutType.CANYON:
		# Canyon plateau: low flat ground with gentle noise ripples (lowered to 24.0 so camera doesn't clip/occlude in isometric mode)
		base_terrain_height = 24.0 + h_noise * 0.4
	else:
		base_terrain_height = h_noise

	var closest_pos = curve.get_closest_point(Vector3(px, base_terrain_height, pz))
	var dist = Vector2(px, pz).distance_to(Vector2(closest_pos.x, closest_pos.z))
	var road_h = closest_pos.y

	var height: float

	if track_layout_type == TrackLayoutType.CANYON:
		var sand_edge = sand_width / 2.0
		
		# Zone 1: Road surface — flat at road height
		var road_inner = sand_edge - 2.0
		# Zone 2: Canyon floor just beyond curb — stays low briefly
		var floor_edge = sand_edge + 5.0
		# Zone 3: Canyon wall rise — ramps gently up to low plateau
		var wall_top = sand_edge + 30.0
		
		if dist < road_inner:
			# On the road itself
			height = road_h
		elif dist < floor_edge:
			# Canyon floor (still at road level)
			var t = (dist - road_inner) / (floor_edge - road_inner)
			height = lerp(road_h, road_h + 1.0, t)
		elif dist < wall_top:
			# Steep canyon wall rising to plateau
			var t = (dist - floor_edge) / (wall_top - floor_edge)
			var smooth_t = t * t * (3.0 - 2.0 * t)  # smoothstep
			height = lerp(road_h + 1.0, base_terrain_height, smooth_t)
		else:
			# Canyon rim plateau with noise
			height = base_terrain_height
		
		# Basin recession under road for collision mesh
		var basin_blend = 1.0 - smoothstep(road_inner - 2.0, road_inner, dist)
		if for_collision:
			height = lerp(height, road_h - terrain_recession_collision, basin_blend)
		else:
			height = lerp(height, road_h - terrain_recession_visual, basin_blend)
	else:
		# Original blending for DEFAULT and MOUNTAIN
		var sand_edge = sand_width / 2.0
		var blend_dist = 60.0
		var clearing_blend = 1.0 - smoothstep(sand_edge - 2.0, sand_edge + blend_dist, dist)
		height = lerp(base_terrain_height, road_h, clearing_blend)

		var basin_blend = 1.0 - smoothstep(sand_edge - 2.0, sand_edge, dist)
		if for_collision:
			height = lerp(height, road_h - terrain_recession_collision, basin_blend)
		else:
			height = lerp(height, road_h - terrain_recession_visual, basin_blend)

	# Edge falloff (all track types — drops to abyss at map edges)
	var world_pos = Vector2(px, pz)
	var noise_val = noise.get_noise_2d(px * 0.1, pz * 0.1) * 200.0
	var dist_from_center_val = world_pos.length() + noise_val
	var falloff_start = terrain_size.x * 0.25
	var falloff_end = terrain_size.x * 0.45
	var edge_falloff = 1.0 - clamp((dist_from_center_val - falloff_start) / (falloff_end - falloff_start), 0.0, 1.0)
	var falloff_y = -60.0 if (track_layout_type == TrackLayoutType.MOUNTAIN or track_layout_type == TrackLayoutType.CANYON) else -20.0
	height = lerp(falloff_y, height, edge_falloff)

	if not no_water:
		var lake_center = Vector2(-450, -500)
		var lake_radius = 200.0
		var dist_to_lake = Vector2(px, pz).distance_to(lake_center)
		if dist_to_lake < lake_radius:
			var depth = -15.0
			var lake_blend = clamp((lake_radius - dist_to_lake) / 40.0, 0.0, 1.0)
			height = lerp(height, depth, lake_blend)

	return height



@export var generate_now: bool = false:
	set(val):
		if val:
			generate_now = false
			if Engine.is_editor_hint():
				generate_world()
			notify_property_list_changed()

@export var track_path: Path3D
@export var terrain_size: Vector2 = Vector2(2000, 2000)
@export var terrain_resolution: int = 800 # Higher resolution for rounder, more organic hills
@export var noise_frequency: float = 0.008 # Detailed hills
@export var hill_height: float = 50.0 # Taller hills

@export_group("Layout")
@export var is_loop: bool = true

@export var road_width: float = 14.0
@export var sand_width: float = 16.0

@export_group("Visual Offsets")
@export var road_y_offset: float = 0.05
@export var curb_y_offset: float = 0.10
@export var terrain_recession_visual: float = 0.20
@export var terrain_recession_collision: float = 0.10

@export_group("Procedural Generation")
@export var terrain_grass_count: int = 12000
@export var grass_grid_size: int = 10
@export var grass_visibility_range: float = 200.0

# To regenerate a level, run its dedicated scene:
#   regenerate_canyon.tscn  — Canyon level only (preserves your custom path)
#   regenerate_mountain.tscn — Mountain level only
#   regenerate_desert.tscn  — Desert/oval level only
#   regenerate_all.tscn     — All three levels at once

@export var grass_material: Material
@export var road_material: Material
@export var save_to_files: bool = true



func _ready():
	# Terrain and Track are now saved in the scene file and external .res files.
	# We no longer need to regenerate at runtime, preventing the game from hanging on load.
	pass

func generate_world():
	if not track_path: return
	
	# Set high-resolution bake interval to prevent segmented road overlaps
	track_path.curve.bake_interval = 0.25

	# IMPORTANT: Use free() in editor for immediate cleanup to prevent 'ghost' nodes
	# queue_free() is too slow for tool scripts and causes scene-save bloat
	for child in get_children():
		remove_child(child)
		child.free()

	# 1. Create Data Meshes
	var collision_mesh = _generate_mesh(true) # Flat under road for smooth driving
	var visual_mesh = _generate_mesh(false)   # Recessed under road to prevent leaking
	var trimesh_shape = collision_mesh.create_trimesh_shape()

	# 2. Visual Terrain
	var terrain_instance = MeshInstance3D.new()
	terrain_instance.name = "Terrain_Visual"
	terrain_instance.mesh = _save_resource(visual_mesh, "terrain_visual")
	if grass_material:
		terrain_instance.material_override = grass_material
	else:
		var terrain_mat = StandardMaterial3D.new()
		terrain_mat.albedo_color = Color(0.2, 0.6, 0.2)
		terrain_mat.roughness = 1.0
		terrain_instance.material_override = terrain_mat
	terrain_instance.lod_bias = 10.0
	terrain_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(terrain_instance)


	# 3. Unified Collision
	var static_body = StaticBody3D.new()
	static_body.name = "Unified_World_Collision"
	add_child(static_body)
	var collision_shape = CollisionShape3D.new()
	collision_shape.shape = _save_resource(trimesh_shape, "terrain_collision_shape")
	static_body.add_child(collision_shape)

	# 4. Visual Overlays
	_generate_road_and_sand()

	# 5. Water Surface
	if not no_water:
		_generate_water()

	# 6. Procedural Hill Grass
	if not no_grass:
		_generate_terrain_grass()

	if Engine.is_editor_hint():
		_set_owner_recursive(self)


# Returns a Curve3D whose points are in TerrainGenerator-local space (= world space
# when TerrainGenerator is at the scene root with no transform offset).
# This corrects a mismatch that occurred when the Path3D node was moved in the
# scene: the raw curve points are relative to Path3D's own origin, so sampling
# them directly produced road/terrain geometry at the wrong world position.
#
# When is_loop is true, the first control point is also appended at the end so that
# get_closest_point() covers the closing segment (last → first) for terrain shaping.
func _get_world_curve() -> Curve3D:
	var src: Curve3D = track_path.curve
	var world_curve := Curve3D.new()
	world_curve.bake_interval = src.bake_interval
	# The transform that maps Path3D-local positions into TerrainGenerator-local space
	var to_local: Transform3D = global_transform.affine_inverse() * track_path.global_transform
	for i in range(src.point_count):
		var pos   = to_local * src.get_point_position(i)
		var p_in  = to_local.basis * src.get_point_in(i)   # tangent handles are direction vectors
		var p_out = to_local.basis * src.get_point_out(i)
		world_curve.add_point(pos, p_in, p_out)
	# For loops: append the first point at the end so the closing segment is
	# included in get_closest_point() queries (used by terrain height sampling).
	if is_loop and src.point_count > 1:
		var pos   = to_local * src.get_point_position(0)
		var p_in  = to_local.basis * src.get_point_in(0)
		var p_out = to_local.basis * src.get_point_out(0)
		world_curve.add_point(pos, p_in, p_out)
	return world_curve


func _save_resource(res: Resource, res_name: String, sub_dir: String = "") -> Resource:
	if not save_to_files:
		return res

	var dir_path = "res://generated/"
	if sub_dir != "":
		dir_path += sub_dir + "/"

	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_absolute(dir_path)

	var extension = ".res"
	var actual_name = res_name
	if not level_prefix.is_empty():
		actual_name = level_prefix + "_" + res_name
	var file_path = dir_path + actual_name + extension
	
	# Crucial: take over the path in the resource cache so that the editor 
	# uses this new mesh immediately instead of serving the old cached one.
	res.take_over_path(file_path)
	ResourceSaver.save(res, file_path)
	
	return load(file_path)


func _clear_grass_directory():
	var dir_path = "res://generated/grass/"
	if DirAccess.dir_exists_absolute(dir_path):
		var dir = DirAccess.open(dir_path)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir():
					dir.remove(file_name)
				file_name = dir.get_next()
			dir.list_dir_end()

func _set_owner_recursive(node: Node):

	if not Engine.is_editor_hint(): return
	var root = get_tree().edited_scene_root if is_inside_tree() else null
	if not root: return
	for child in node.get_children():
		child.owner = root
		_set_owner_recursive(child)

func _generate_mesh(for_collision: bool) -> ArrayMesh:
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = noise_frequency
	noise.seed = 12345
	noise.fractal_octaves = 4

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0) 

	var step_x = terrain_size.x / terrain_resolution
	var step_y = terrain_size.y / terrain_resolution
	var start_x = -terrain_size.x / 2.0
	var start_y = -terrain_size.y / 2.0

	var curve = _get_world_curve()

	for y in range(terrain_resolution + 1):
		for x in range(terrain_resolution + 1):
			var px = start_x + x * step_x
			var pz = start_y + y * step_y

			# Get the exact height at this point
			var height = _get_terrain_height(px, pz, noise, curve, for_collision)

			# Calculate analytical/sampled smooth normal
			var eps = 1.0
			var h_L = _get_terrain_height(px - eps, pz, noise, curve, for_collision)
			var h_R = _get_terrain_height(px + eps, pz, noise, curve, for_collision)
			var h_D = _get_terrain_height(px, pz - eps, noise, curve, for_collision)
			var h_U = _get_terrain_height(px, pz + eps, noise, curve, for_collision)
			var normal = Vector3(h_L - h_R, 2.0 * eps, h_D - h_U).normalized()

			st.set_normal(normal)
			st.set_uv(Vector2(px, pz))
			st.add_vertex(Vector3(px, height, pz))

	# Winding Order (CCW - Facing UP)
	for y in range(terrain_resolution):
		for x in range(terrain_resolution):
			var i = y * (terrain_resolution + 1) + x
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + terrain_resolution + 1)
			
			st.add_index(i + 1)
			st.add_index(i + terrain_resolution + 2)
			st.add_index(i + terrain_resolution + 1)

	# IMPORTANT: We do NOT call st.generate_normals() because we manually calculated 
	# them above to eliminate the polygon/faceted look.
	st.generate_tangents()
	return st.commit()

func _generate_road_and_sand():
	var curve = _get_world_curve()
	var length = curve.get_baked_length()
	var points_count = int(length / 0.2) # Even higher resolution (one segment every 20cm)

	# 1. Create a ShaderMaterial for the striped curbs (top surface)
	var curb_mat = ShaderMaterial.new()
	curb_mat.shader = load("res://curb_stripes.gdshader")
	curb_mat.set_shader_parameter("stripe_length", 1.5) # 1.5m per color step

	# 2. Create a Concrete Material for the vertical sides
	var concrete_mat = StandardMaterial3D.new()
	concrete_mat.albedo_color = Color(0.45, 0.45, 0.45) # Classic concrete grey
	concrete_mat.roughness = 0.95
	concrete_mat.metallic = 0.0

	# 3. Visual Overlays: Curbs and Road
	if track_layout_type != TrackLayoutType.CANYON:
		_create_path_visual(points_count, sand_width, curb_mat, concrete_mat, curb_y_offset, "Visual_Curbs")
	_create_path_visual(points_count, road_width, road_material, null, road_y_offset, "Visual_Road")

	# Create ONE unified collision surface for EVERYTHING (Road + Border)
	var col_width = road_width if track_layout_type == TrackLayoutType.CANYON else sand_width
	_create_track_collision(points_count, col_width, "Visual_Road")

func _create_path_visual(point_count: int, width: float, mat: Material, side_mat: Material, y_offset: float, node_name: String):
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var curve = _get_world_curve()
	var half_w = width / 2.0
	var length = curve.get_baked_length()
	
	var is_curb = node_name.contains("Curbs")
	var inner_w = road_width / 2.0
	var outer_w = half_w
	var curb_slope = 0.15

	# Ensure we have a high priority to avoid any conflict with terrain
	var mat_dup = mat.duplicate()
	if node_name.contains("Road"):
		if mat_dup is StandardMaterial3D:
			mat_dup.render_priority = 5 # Absolute top
	else:
		if mat_dup is ShaderMaterial or mat_dup is StandardMaterial3D:
			mat_dup.render_priority = 2 # Above terrain

	# VERTEX LOOP
	for i in range(point_count + 1):
		var offset = (float(i) / point_count) * length
		var pos = curve.sample_baked(offset)

		# Robust Tangent Calculation
		var tangent: Vector3
		if i == 0:
			if is_loop:
				# Sample forward and backward at the loop point for a perfect average tangent
				var p_next = curve.sample_baked(0.2)
				var p_prev = curve.sample_baked(max(0.0, length - 0.2))
				tangent = (p_next - p_prev).normalized()
			else:
				# Simple forward difference at start
				var p_next = curve.sample_baked(0.2)
				tangent = (p_next - pos).normalized()
		elif i == point_count:
			if is_loop:
				var p_next = curve.sample_baked(0.2)
				var p_prev = curve.sample_baked(max(0.0, length - 0.2))
				tangent = (p_next - p_prev).normalized()
			else:
				# Simple backward difference at end
				var p_prev = curve.sample_baked(max(0.0, length - 0.2))
				tangent = (pos - p_prev).normalized()
		else:
			var p_next = curve.sample_baked(min(length, offset + 0.2))
			tangent = (p_next - pos).normalized()

		var right_dir = tangent.cross(Vector3.UP).normalized()
		var right = right_dir * half_w

		# EXPLICIT LOOP SNAPPING:
		# If this is the last vertex of a loop, force it to match the first vertex exactly
		var final_pos = pos
		if is_loop and i == point_count:
			# Re-calculate first pos for perfect match
			final_pos = curve.sample_baked(0.0)

		if is_curb:
			var p_lo = final_pos - right_dir * outer_w + Vector3(0, y_offset - curb_slope, 0)
			var p_li = final_pos - right_dir * inner_w + Vector3(0, y_offset, 0)
			var p_ri = final_pos + right_dir * inner_w + Vector3(0, y_offset, 0)
			var p_ro = final_pos + right_dir * outer_w + Vector3(0, y_offset - curb_slope, 0)
			
			var left_normal = (right_dir * curb_slope + Vector3.UP * (outer_w - inner_w)).normalized()
			var right_normal = (-right_dir * curb_slope + Vector3.UP * (outer_w - inner_w)).normalized()
			
			st.set_normal(left_normal)
			st.set_uv(Vector2(0, offset))
			st.add_vertex(p_lo)
			
			st.set_normal(left_normal)
			st.set_uv(Vector2(0.25, offset))
			st.add_vertex(p_li)
			
			st.set_normal(right_normal)
			st.set_uv(Vector2(0.75, offset))
			st.add_vertex(p_ri)
			
			st.set_normal(right_normal)
			st.set_uv(Vector2(1.0, offset))
			st.add_vertex(p_ro)
		else:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(0, offset))
			st.add_vertex(final_pos - right + Vector3(0, y_offset, 0))

			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(width, offset)) # Use width instead of 1 to prevent texture stretching
			st.add_vertex(final_pos + right + Vector3(0, y_offset, 0))

	# INDEX LOOP (CCW - Facing UP)
	for i in range(point_count):
		var offset = (float(i) / point_count) * length
		var pos = curve.sample_baked(offset)
		if _is_in_gap_pos(pos):
			continue

		if is_curb:
			var base = i * 4
			var nxt = (i + 1) * 4
			
			# Left slope
			st.add_index(base + 0); st.add_index(nxt + 0); st.add_index(base + 1)
			st.add_index(base + 1); st.add_index(nxt + 0); st.add_index(nxt + 1)
			
			# Right slope
			st.add_index(base + 2); st.add_index(nxt + 2); st.add_index(base + 3)
			st.add_index(base + 3); st.add_index(nxt + 2); st.add_index(nxt + 3)
			
			# --- UNDERSIDE ---
			# Left slope Underside
			st.add_index(base + 0); st.add_index(base + 1); st.add_index(nxt + 0)
			st.add_index(base + 1); st.add_index(nxt + 1); st.add_index(nxt + 0)
			# Right slope Underside
			st.add_index(base + 2); st.add_index(base + 3); st.add_index(nxt + 2)
			st.add_index(base + 3); st.add_index(nxt + 3); st.add_index(nxt + 2)
		else:
			var v0 = i * 2
			var v1 = v0 + 1
			var v2 = (i + 1) * 2
			var v3 = v2 + 1

			# T1: Left i, Left i+1, Right i
			st.add_index(v0); st.add_index(v2); st.add_index(v1)
			# T2: Right i, Left i+1, Right i+1
			st.add_index(v1); st.add_index(v2); st.add_index(v3)

			# --- ADD UNDERSIDE (Visibility from below) ---
			st.add_index(v0); st.add_index(v1); st.add_index(v2)
			st.add_index(v1); st.add_index(v3); st.add_index(v2)



	st.generate_tangents()
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.mesh = _save_resource(st.commit(), node_name)
	mesh_instance.material_override = mat_dup
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON # Enable shadows to prevent shadow leaking under bridges
	add_child(mesh_instance)


	# --- ADD DEPTH (Thickness) ---
	# For curbs, use the explicit concrete material. For road, duplicate its material.
	var final_side_mat = side_mat if side_mat else mat_dup
	_create_path_sides(point_count, width, final_side_mat, y_offset, node_name + "_Sides")

	# REMOVED: Separate collision shapes here as they cause sticking.
	# We now use the unified _create_track_collision call.

func _create_track_collision(point_count: int, width: float, node_name: String):
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var curve = _get_world_curve()
	var length = curve.get_baked_length()
	var half_w = width / 2.0
	var y_offset = road_y_offset # Match road height exactly
	var thickness = 5.0 # Increased thickness for better underground anchoring

	var inner_w = road_width / 2.0
	var outer_w = half_w
	var curb_slope = 0.15

	if track_layout_type == TrackLayoutType.CANYON:
		inner_w = half_w
		curb_slope = 0.0

	# Create Top and Bottom vertices
	for i in range(point_count + 1):
		var offset = (float(i) / point_count) * length
		var pos = curve.sample_baked(offset)

		var tangent: Vector3
		if i == 0:
			if is_loop:
				var p_next = curve.sample_baked(0.2)
				var p_prev = curve.sample_baked(max(0.0, length - 0.2))
				tangent = (p_next - p_prev).normalized()
			else:
				tangent = (curve.sample_baked(0.2) - pos).normalized()
		elif i == point_count:
			if is_loop:
				var p_next = curve.sample_baked(0.2)
				var p_prev = curve.sample_baked(max(0.0, length - 0.2))
				tangent = (p_next - p_prev).normalized()
			else:
				tangent = (pos - curve.sample_baked(max(0.0, length - 0.2))).normalized()
		else:
			var next_pos = curve.sample_baked(min(offset + 0.5, length))
			tangent = (next_pos - pos).normalized()

		if tangent.length() < 0.01:
			tangent = (pos - curve.sample_baked(max(offset - 0.5, 0.0))).normalized()
		var right_dir = tangent.cross(Vector3.UP).normalized()

		var final_pos = pos
		if is_loop and i == point_count:
			final_pos = curve.sample_baked(0.0)

		# Top vertices
		var p_lo = final_pos - right_dir * outer_w + Vector3(0, y_offset - curb_slope, 0)
		var p_li = final_pos - right_dir * inner_w + Vector3(0, y_offset, 0)
		var p_ri = final_pos + right_dir * inner_w + Vector3(0, y_offset, 0)
		var p_ro = final_pos + right_dir * outer_w + Vector3(0, y_offset - curb_slope, 0)
		
		# Bottom vertices
		var p_lob = p_lo - Vector3(0, thickness, 0)
		var p_lib = p_li - Vector3(0, thickness, 0)
		var p_rib = p_ri - Vector3(0, thickness, 0)
		var p_rob = p_ro - Vector3(0, thickness, 0)

		st.add_vertex(p_lo)  # 8*i + 0
		st.add_vertex(p_li)  # 8*i + 1
		st.add_vertex(p_ri)  # 8*i + 2
		st.add_vertex(p_ro)  # 8*i + 3
		st.add_vertex(p_lob) # 8*i + 4
		st.add_vertex(p_lib) # 8*i + 5
		st.add_vertex(p_rib) # 8*i + 6
		st.add_vertex(p_rob) # 8*i + 7

	for i in range(point_count):
		var offset = (float(i) / point_count) * length
		var pos = curve.sample_baked(offset)
		if _is_in_gap_pos(pos):
			continue

		var base = i * 8
		var nxt = (i + 1) * 8

		# Top Faces
		# Left slope
		st.add_index(base + 0); st.add_index(nxt + 0); st.add_index(base + 1)
		st.add_index(base + 1); st.add_index(nxt + 0); st.add_index(nxt + 1)
		
		# Center flat
		st.add_index(base + 1); st.add_index(nxt + 1); st.add_index(base + 2)
		st.add_index(base + 2); st.add_index(nxt + 1); st.add_index(nxt + 2)
		
		# Right slope
		st.add_index(base + 2); st.add_index(nxt + 2); st.add_index(base + 3)
		st.add_index(base + 3); st.add_index(nxt + 2); st.add_index(nxt + 3)

		# Bottom Faces (Reverse winding)
		# Left slope bottom
		st.add_index(base + 4); st.add_index(base + 5); st.add_index(nxt + 4)
		st.add_index(base + 5); st.add_index(nxt + 5); st.add_index(nxt + 4)
		
		# Center flat bottom
		st.add_index(base + 5); st.add_index(base + 6); st.add_index(nxt + 5)
		st.add_index(base + 6); st.add_index(nxt + 6); st.add_index(nxt + 5)
		
		# Right slope bottom
		st.add_index(base + 6); st.add_index(base + 7); st.add_index(nxt + 6)
		st.add_index(base + 7); st.add_index(nxt + 7); st.add_index(nxt + 6)

		# Left Side Wall
		st.add_index(base + 0); st.add_index(base + 4); st.add_index(nxt + 0)
		st.add_index(base + 4); st.add_index(nxt + 4); st.add_index(nxt + 0)

		# Right Side Wall
		st.add_index(base + 3); st.add_index(nxt + 3); st.add_index(base + 7)
		st.add_index(base + 7); st.add_index(nxt + 3); st.add_index(nxt + 7)


	var track_mesh = st.commit()
	var static_body = StaticBody3D.new()
	static_body.name = "Track_Collision"
	add_child(static_body)
	var col_shape = CollisionShape3D.new()
	var trimesh_shape = track_mesh.create_trimesh_shape()
	col_shape.shape = _save_resource(trimesh_shape, "track_collision_shape")
	static_body.add_child(col_shape)

	# If this is the road, generate bridge supports if high above ground
	if node_name.contains("Road"):
		_generate_bridge_supports(point_count)

func _generate_bridge_supports(point_count: int):
	if track_layout_type == TrackLayoutType.MOUNTAIN or track_layout_type == TrackLayoutType.CANYON:
		return

	var curve = _get_world_curve()
	var length = curve.get_baked_length()
	var step = 30.0 # Support every 30m

	var support_mat = StandardMaterial3D.new()
	support_mat.albedo_color = Color(0.3, 0.3, 0.3)

	for d in range(0, int(length), int(step)):
		var pos = curve.sample_baked(d)
		# Only spawn if high above "ground" or in lake area
		if pos.y > 5.0 or Vector2(pos.x, pos.z).distance_to(Vector2(-450, -500)) < 220.0:
			var support = MeshInstance3D.new()
			support.name = "BridgeSupport_" + str(d)
			var box = BoxMesh.new()
			box.size = Vector3(4.0, pos.y + 30.0, 4.0) # Tall pillar
			support.mesh = box
			support.position = pos + Vector3(0, -box.size.y/2.0, 0)
			support.material_override = support_mat
			add_child(support)

			# Add collision to the bridge supports
			var static_body = StaticBody3D.new()
			support.add_child(static_body)
			var collision_shape = CollisionShape3D.new()
			var shape = BoxShape3D.new()
			shape.size = box.size
			collision_shape.shape = shape
			static_body.add_child(collision_shape)

# (track rebuild functions removed — edit the Path3D curve directly in the scene editor,
#  then run the dedicated regenerate_*.tscn scene to rebuild terrain/road geometry)
func _create_path_sides(point_count: int, width: float, mat: Material, y_offset: float, node_name: String):
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var curve = _get_world_curve()
	var length = curve.get_baked_length()
	var half_w = width / 2.0
	var depth = 2.5 # Thickness of the road hull

	var side_y_offset = y_offset
	if node_name.contains("Curbs"):
		side_y_offset = y_offset - 0.15

	# 1. VERTEX GENERATION
	for i in range(point_count + 1):
		var offset = (float(i) / point_count) * length
		var pos = curve.sample_baked(offset)

		var tangent: Vector3
		if i == 0:
			if is_loop:
				tangent = (curve.sample_baked(0.1) - curve.sample_baked(length - 0.1)).normalized()
			else:
				tangent = (curve.sample_baked(0.1) - pos).normalized()
		elif i == point_count:
			if is_loop:
				tangent = (curve.sample_baked(0.1) - curve.sample_baked(length - 0.1)).normalized()
			else:
				tangent = (pos - curve.sample_baked(max(0, length - 0.1))).normalized()
		else:
			var next_offset = offset + 0.1
			if next_offset >= length:
				next_offset = 0.1
			var next_pos = curve.sample_baked(next_offset)
			tangent = (next_pos - pos).normalized()

		if tangent.length() < 0.01:
			tangent = (pos - curve.sample_baked(max(0, offset - 0.1))).normalized()

		var right = tangent.cross(Vector3.UP).normalized() * half_w

		# Snap the closing row to the start position so the loop connects perfectly
		var final_pos = pos
		if is_loop and i == point_count:
			final_pos = curve.sample_baked(0.0)

		var top_l = final_pos - right + Vector3(0, side_y_offset, 0)
		var top_r = final_pos + right + Vector3(0, side_y_offset, 0)
		var bot_l = top_l - Vector3(0, depth, 0)
		var bot_r = top_r - Vector3(0, depth, 0)
		if track_layout_type == TrackLayoutType.CANYON:
			bot_l = top_l - right * 1.5 - Vector3(0, 60.0, 0)
			bot_r = top_r + right * 1.5 - Vector3(0, 60.0, 0)

		var uv_y = offset * 0.2

		st.set_uv(Vector2(0, uv_y))
		st.add_vertex(top_l) # 4*i + 0
		st.set_uv(Vector2(0.5, uv_y))
		st.add_vertex(bot_l) # 4*i + 1
		st.set_uv(Vector2(1.0, uv_y))
		st.add_vertex(top_r) # 4*i + 2
		st.set_uv(Vector2(1.5, uv_y))
		st.add_vertex(bot_r) # 4*i + 3

	# 2. INDEX GENERATION
	for i in range(point_count):
		var offset = (float(i) / point_count) * length
		var pos = curve.sample_baked(offset)
		if _is_in_gap_pos(pos):
			continue

		var base = i * 4
		var nxt = (i + 1) * 4

		# Left Side
		st.add_index(base + 0); st.add_index(base + 1); st.add_index(nxt + 1)
		st.add_index(base + 0); st.add_index(nxt + 1); st.add_index(nxt + 0)

		# Right Side
		st.add_index(base + 2); st.add_index(nxt + 2); st.add_index(base + 3)
		st.add_index(base + 3); st.add_index(nxt + 2); st.add_index(nxt + 3)

		# Bottom Surface
		st.add_index(base + 1); st.add_index(base + 3); st.add_index(nxt + 3)
		st.add_index(base + 1); st.add_index(nxt + 3); st.add_index(nxt + 1)


	st.generate_normals()
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.mesh = _save_resource(st.commit(), node_name)

	var final_side_mat = mat.duplicate()
	if not node_name.contains("Curbs") and final_side_mat is StandardMaterial3D:
		final_side_mat.albedo_color = final_side_mat.albedo_color.darkened(0.3)
	
	if track_layout_type == TrackLayoutType.CANYON and not node_name.contains("Curbs"):
		# Create a beautiful StandardMaterial3D with triplanar mapping and rock texture for the canyon sides
		var rock_mat = StandardMaterial3D.new()
		rock_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		var rock_tex = load("res://materials/dark_canyon_rock.png")
		var rock_normal = load("res://materials/dark_canyon_rock_normal.png")
		if rock_tex:
			rock_mat.albedo_texture = rock_tex
		if rock_normal:
			rock_mat.roughness = 0.9
			rock_mat.normal_enabled = true
			rock_mat.normal_texture = rock_normal
			rock_mat.normal_scale = 1.5
		rock_mat.uv1_scale = Vector3(0.08, 0.08, 0.08)
		rock_mat.uv1_triplanar = true
		final_side_mat = rock_mat
		
		# Also add a StaticBody3D and CollisionShape3D for physics collision on the canyon road sides embankment!
		var static_body = StaticBody3D.new()
		static_body.name = node_name + "_Collision"
		mesh_instance.add_child(static_body)
		
		var collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		var trimesh_shape = mesh_instance.mesh.create_trimesh_shape()
		collision_shape.shape = _save_resource(trimesh_shape, node_name + "_collision_shape")
		static_body.add_child(collision_shape)
	elif track_layout_type == TrackLayoutType.CANYON and final_side_mat is ShaderMaterial:
		final_side_mat.set_shader_parameter("use_world_uv", false)
		final_side_mat.set_shader_parameter("uv_scale", 4.0)

	mesh_instance.material_override = final_side_mat
	add_child(mesh_instance)

func _generate_water():
	var water = MeshInstance3D.new()
	water.name = "Water_Surface"
	var plane = PlaneMesh.new()
	plane.size = terrain_size * 2.0
	water.mesh = plane
	water.position = Vector3(0, -10.0, 0) # Water level (below terrain base)

	# Create a high-quality water shader material
	var mat = ShaderMaterial.new()
	mat.shader = load("res://water.gdshader")

	# Create a FastNoiseLite texture for the waves
	var noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.02
	var noise_tex = NoiseTexture2D.new()
	noise_tex.seamless = true
	noise_tex.as_normal_map = true
	noise_tex.noise = noise

	mat.set_shader_parameter("noise_tex", noise_tex)
	mat.set_shader_parameter("water_color", Color(0.1, 0.3, 0.6))
	mat.set_shader_parameter("transparency", 0.7)

	water.material_override = mat
	add_child(water)

func _create_grass_mesh() -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var w := 0.75 # half width
	var h := 0.95 # height
	var base_y := -0.2

	# Single Plane (along X-axis)
	var v0 := Vector3(-w, base_y, 0.0)
	var v1 := Vector3(w, base_y, 0.0)
	var v2 := Vector3(w, h + base_y, 0.0)
	var v3 := Vector3(-w, h + base_y, 0.0)

	# Front face
	st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(v0)
	st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(v1)
	st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(v2)

	st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(v0)
	st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(v2)
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(v3)



	st.generate_normals()
	st.generate_tangents()
	return st.commit()

## ------------------------------------------------------------------
## Fast grass helpers
## ------------------------------------------------------------------

# Pre-bake the track curve into a flat array of XZ positions (Vector2).
# Using a coarse sample interval is fine – we only need to approximate
# the nearest road distance, not follow the curve exactly.
func _bake_path_points(curve: Curve3D, sample_interval: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var length = curve.get_baked_length()
	var t := 0.0
	while t <= length:
		var p = curve.sample_baked(t)
		pts.append(Vector2(p.x, p.z))
		t += sample_interval
	return pts

# Squared distance from point P to the nearest sample in the baked array.
# Returns the squared distance so we can compare against (min_dist^2) cheaply.
func _sq_dist_to_path(px: float, pz: float, baked: PackedVector2Array) -> float:
	var best_sq := INF
	var p2 := Vector2(px, pz)
	for pt in baked:
		var d = p2.distance_squared_to(pt)
		if d < best_sq:
			best_sq = d
	return best_sq

func _generate_terrain_grass():
	if terrain_grass_count <= 0: return
	
	var curve = _get_world_curve()
	
	# --- CRITICAL: Match noise settings exactly to the terrain mesh (seed 12345, octaves 4) ---
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = noise_frequency
	noise.seed = 12345
	noise.fractal_octaves = 4
	
	var grass_mesh = _create_grass_mesh()
	# Dynamic grass shader with distance fade-out (collapses far away grass vertices to 0 for maximum performance, no wind sway)
	var shader = Shader.new()
	shader.code = "shader_type spatial;\nrender_mode cull_disabled, diffuse_toon, specular_disabled, depth_draw_opaque;\n\nuniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;\nuniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);\nuniform float max_dist = 200.0;\nuniform float fade_r = 30.0;\n\nvarying float height_val;\n\nvoid vertex() {\n\theight_val = VERTEX.y;\n\tvec3 view_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;\n\tfloat dist = length(view_pos);\n\tif (dist > max_dist) {\n\t\tVERTEX = vec3(0.0);\n\t\theight_val = 0.0;\n\t} else {\n\t\tif (dist > max_dist - fade_r) {\n\t\t\tfloat fade = (max_dist - dist) / fade_r;\n\t\t\tVERTEX *= fade;\n\t\t}\n\t}\n}\n\nvoid fragment() {\n\tvec4 tex_color = texture(albedo_texture, UV);\n\tALBEDO = tex_color.rgb * albedo_tint.rgb;\n\tALPHA = tex_color.a;\n\tALPHA_SCISSOR_THRESHOLD = 0.4;\n\tROUGHNESS = 1.0;\n\tEMISSION = ALBEDO * 0.12;\n}"
	
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("max_dist", grass_visibility_range)
	mat.set_shader_parameter("fade_r", 30.0)
	
	var tex_path = "res://sprites/grass.png"
	if ResourceLoader.exists(tex_path):
		var tex = load(tex_path)
		mat.set_shader_parameter("albedo_texture", tex)
	
	# ---------------------------------------------------------------
	# OPTIMISATION 1: Pre-bake the curve once (sample every 4 m).
	# This replaces the per-blade curve.get_closest_point() call
	# (which is O(baked_interval_count)) with a simple array scan.
	# ---------------------------------------------------------------
	var baked_path := _bake_path_points(curve, 4.0)
	var min_dist := sand_width / 2.0 + 1.5
	var min_dist_sq := min_dist * min_dist
	
	# ---------------------------------------------------------------
	# OPTIMISATION 2: Scatter uniformly across the whole terrain
	# instead of being anchored to the track.  We simply reject any
	# candidate that is underwater or too close to the road.
	# This gives grass *everywhere* on the map and avoids all the
	# expensive curve.sample_baked() calls in the old loop.
	# ---------------------------------------------------------------
	var half_x := terrain_size.x * 0.5
	var half_z := terrain_size.y * 0.5
	var chunk_w := terrain_size.x / grass_grid_size
	var chunk_d := terrain_size.y / grass_grid_size
	
	var chunk_transforms := []
	chunk_transforms.resize(grass_grid_size * grass_grid_size)
	for i in range(grass_grid_size * grass_grid_size):
		chunk_transforms[i] = []
	
	var attempts := terrain_grass_count * 3  # upper bound to avoid infinite loop
	var placed := 0
	
	for _i in range(attempts):
		if placed >= terrain_grass_count:
			break
		
		var px := randf_range(-half_x, half_x)
		var pz := randf_range(-half_z, half_z)
		
		# ---------------------------------------------------------------
		# OPTIMISATION 3: Height check FIRST (just noise math, very fast).
		# We still need _get_terrain_height which internally calls
		# curve.get_closest_point() – but only for the edge-blending.
		# We avoid the *second* explicit get_closest_point call that
		# previously followed it by reusing our baked array.
		# ---------------------------------------------------------------
		var height := _get_terrain_height(px, pz, noise, curve, false)
		if height < -9.0:
			continue
		
		# Road-exclusion: fast scan through pre-baked 2-D points
		if _sq_dist_to_path(px, pz, baked_path) < min_dist_sq:
			continue
		
		var pos := Vector3(px, height, pz)
		
		# Calculate analytical normal at the grass position to align it with slopes
		var eps = 0.5
		var h_L = _get_terrain_height(px - eps, pz, noise, curve, false)
		var h_R = _get_terrain_height(px + eps, pz, noise, curve, false)
		var h_D = _get_terrain_height(px, pz - eps, noise, curve, false)
		var h_U = _get_terrain_height(px, pz + eps, noise, curve, false)
		var normal = Vector3(h_L - h_R, 2.0 * eps, h_D - h_U).normalized()
		
		var up = normal
		var fwd_vec = Vector3.FORWARD
		if abs(up.dot(fwd_vec)) > 0.99:
			fwd_vec = Vector3.UP
		var right_vec = fwd_vec.cross(up).normalized()
		fwd_vec = up.cross(right_vec).normalized()
		
		var basis := Basis(right_vec, up, -fwd_vec)
		basis = basis.rotated(up, randf() * PI * 2.0)
		
		var sh := randf_range(0.8, 1.4)
		var sw := randf_range(0.8, 1.2)
		basis = basis.scaled(Vector3(sw, sh, sw))
		
		var col = clamp(int((px + half_x) / chunk_w), 0, grass_grid_size - 1)
		var row = clamp(int((pz + half_z) / chunk_d), 0, grass_grid_size - 1)
		var idx = row * grass_grid_size + col
		chunk_transforms[idx].append(Transform3D(basis, pos))
		placed += 1
		
	# Clean up any existing GrassContainer and rebuild structure
	var old_container = get_node_or_null("GrassContainer")
	if old_container:
		remove_child(old_container)
		old_container.free()
		
	var grass_container = Node3D.new()
	grass_container.name = "GrassContainer"
	add_child(grass_container)
	
	if save_to_files:
		_clear_grass_directory()
		
	var start_x := -half_x
	var start_z := -half_z
	
	for r in range(grass_grid_size):
		for c in range(grass_grid_size):
			var idx = r * grass_grid_size + c
			var list = chunk_transforms[idx]
			if list.is_empty():
				continue
				
			var chunk_center_x = start_x + (c + 0.5) * chunk_w
			var chunk_center_z = start_z + (r + 0.5) * chunk_d
			var center_height = _get_terrain_height(chunk_center_x, chunk_center_z, noise, curve, false)
			var chunk_center = Vector3(chunk_center_x, center_height, chunk_center_z)
			
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "GrassChunk_%d_%d" % [c, r]
			mmi.position = chunk_center
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = grass_visibility_range
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			grass_container.add_child(mmi)
			
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = false
			mm.use_custom_data = false
			mm.mesh = grass_mesh
			mm.instance_count = list.size()
			
			for i in range(list.size()):
				var t = list[i]
				t.origin -= chunk_center
				mm.set_instance_transform(i, t)
				
			mmi.multimesh = _save_resource(mm, "chunk_%d_%d" % [c, r], "grass")
			mmi.material_override = mat


