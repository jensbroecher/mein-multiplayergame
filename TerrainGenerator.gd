@tool
extends Node3D

func _get_terrain_height(px: float, pz: float, noise: FastNoiseLite, curve: Curve3D, for_collision: bool) -> float:
	var h_noise = noise.get_noise_2d(px, pz) * hill_height

	var closest_pos = curve.get_closest_point(Vector3(px, 0.0, pz))
	var dist = Vector2(px, pz).distance_to(Vector2(closest_pos.x, closest_pos.z))

	var sand_edge = sand_width / 2.0
	var blend_dist = 60.0

	var clearing_blend = 1.0 - smoothstep(sand_edge - 2.0, sand_edge + blend_dist, dist)
	var road_h = closest_pos.y
	var height = lerp(h_noise, road_h, clearing_blend)

	var basin_blend = 1.0 - smoothstep(sand_edge - 2.0, sand_edge, dist)
	if for_collision:
		height = lerp(height, road_h - terrain_recession_collision, basin_blend)
	else:
		height = lerp(height, road_h - terrain_recession_visual, basin_blend)

	var world_pos = Vector2(px, pz)
	var noise_val = noise.get_noise_2d(px * 0.1, pz * 0.1) * 200.0
	var dist_from_center = world_pos.length() + noise_val

	var falloff_start = terrain_size.x * 0.25
	var falloff_end = terrain_size.x * 0.45
	var edge_falloff = 1.0 - clamp((dist_from_center - falloff_start) / (falloff_end - falloff_start), 0.0, 1.0)
	height = lerp(-20.0, height, edge_falloff)

	var lake_center = Vector2(-450, -500)
	var lake_radius = 200.0
	var dist_to_lake = Vector2(px, pz).distance_to(lake_center)
	if dist_to_lake < lake_radius:
		var depth = -15.0
		var lake_blend = clamp((lake_radius - dist_to_lake) / 40.0, 0.0, 1.0)
		height = lerp(height, depth, lake_blend)

	return height


@export var generate_now: bool:
	set(val):
		if val:
			generate_now = false
			if Engine.is_editor_hint():
				generate_world()

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

@export var create_longer_track: bool:
	set(val):
		if val:
			create_longer_track = false
			if Engine.is_editor_hint():
				_rebuild_longer_track()

@export var grass_material: Material
@export var road_material: Material
@export var save_to_files: bool = true


func _ready():
	# Terrain and Track are now saved in the scene file and external .res files.
	# We no longer need to regenerate at runtime, preventing the game from hanging on load.
	pass

func generate_world():
	if not track_path: return

	# IMPORTANT: Use free() in editor for immediate cleanup to prevent 'ghost' nodes
	# queue_free() is too slow for tool scripts and causes scene-save bloat
	for child in get_children():
		remove_child(child)
		child.free()

	# 1. Create Data Meshes
	var collision_mesh = _generate_mesh(true) # Flat under road for smooth driving
	var visual_mesh = _generate_mesh(false)   # Recessed under road to prevent leaking

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
	var trimesh_shape = collision_mesh.create_trimesh_shape()
	collision_shape.shape = _save_resource(trimesh_shape, "terrain_collision_shape")
	static_body.add_child(collision_shape)

	# 4. Visual Overlays
	_generate_road_and_sand()

	# 5. Water Surface
	_generate_water()

	# 6. Procedural Hill Grass
	_generate_terrain_grass()

	if Engine.is_editor_hint():
		_set_owner_recursive(self)

func _save_resource(res: Resource, res_name: String) -> Resource:
	if not save_to_files:
		return res

	var dir_path = "res://generated/"
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_absolute(dir_path)

	var extension = ".res"
	var file_path = dir_path + res_name + extension
	
	# Crucial: take over the path in the resource cache so that the editor 
	# uses this new mesh immediately instead of serving the old cached one.
	res.take_over_path(file_path)
	ResourceSaver.save(res, file_path)
	
	return res

func _set_owner_recursive(node: Node):

	if not Engine.is_editor_hint(): return
	var root = get_tree().edited_scene_root if get_tree() else null
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

	var curve = track_path.curve

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
	var curve = track_path.curve
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
	_create_path_visual(points_count, sand_width, curb_mat, concrete_mat, curb_y_offset, "Visual_Curbs")
	_create_path_visual(points_count, road_width, road_material, null, road_y_offset, "Visual_Road")

	# Create ONE unified collision surface for EVERYTHING (Road + Border)
	_create_track_collision(points_count, sand_width, "Visual_Road")

func _create_path_visual(point_count: int, width: float, mat: Material, side_mat: Material, y_offset: float, node_name: String):
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var curve = track_path.curve
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
		if is_curb:
			var base = i * 4
			var nxt = (i + 1) * 4
			
			# Left slope
			st.add_index(base + 0); st.add_index(nxt + 0); st.add_index(base + 1)
			st.add_index(base + 1); st.add_index(nxt + 0); st.add_index(nxt + 1)
			
			# Center flat
			st.add_index(base + 1); st.add_index(nxt + 1); st.add_index(base + 2)
			st.add_index(base + 2); st.add_index(nxt + 1); st.add_index(nxt + 2)
			
			# Right slope
			st.add_index(base + 2); st.add_index(nxt + 2); st.add_index(base + 3)
			st.add_index(base + 3); st.add_index(nxt + 2); st.add_index(nxt + 3)
			
			# --- UNDERSIDE ---
			# Left slope Underside
			st.add_index(base + 0); st.add_index(base + 1); st.add_index(nxt + 0)
			st.add_index(base + 1); st.add_index(nxt + 1); st.add_index(nxt + 0)
			# Center flat Underside
			st.add_index(base + 1); st.add_index(base + 2); st.add_index(nxt + 1)
			st.add_index(base + 2); st.add_index(nxt + 2); st.add_index(nxt + 1)
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
	var curve = track_path.curve
	var length = curve.get_baked_length()
	var half_w = width / 2.0
	var y_offset = road_y_offset # Match road height exactly
	var thickness = 5.0 # Increased thickness for better underground anchoring

	var inner_w = road_width / 2.0
	var outer_w = half_w
	var curb_slope = 0.15

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
	var curve = track_path.curve
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

func _rebuild_longer_track():
	if not track_path: return

	var curve = track_path.curve
	curve.clear_points()

	# Create a much more complex "Grand Prix" style track with ELEVATION
	# Added intermediate points for smoother 90-degree turns
	# Improved "Grand Prix" track with additional smoothing points for steep corners
	# Improved "Grand Prix" track with additional smoothing points for steep corners
	var pts = [
		Vector3(0, 0, 0),             # Start Line
		Vector3(60, 2, -25),          # Added intermediate start smoothing
		Vector3(120, 5, -50),
		Vector3(250, 10, -150),
		Vector3(300, 5, -350),
		Vector3(280, 4, -420),        # Smoothing point for turn
		Vector3(220, 2, -450),
		Vector3(150, 2, -420),        # Smoothing point
		Vector3(100, 2, -400),
		Vector3(0, 5, -440),          # Early turn start
		Vector3(-80, 10, -480),
		Vector3(-250, 15, -550),
		Vector3(-450, 20, -650),      # BRIDGE OVER LAKE
		Vector3(-580, 20, -620),      # Gentler bridge turn
		Vector3(-700, 18, -480),      # Smooth descent
		Vector3(-650, 12, -350),
		Vector3(-550, 8, -250),
		Vector3(-400, 4, -100),
		Vector3(-450, 12, 10),
		Vector3(-350, 8, 150),
		Vector3(-200, 4, 300),
		Vector3(-100, 3, 290),         # Added intermediate end smoothing
		Vector3(100, 2, 280),         # Gentle final turn
		Vector3(50, 1, 200),
		Vector3(20, 0.5, 100),         # Final approach smoothing
		Vector3(0, 0, 0) if is_loop else Vector3(0, 0, 50) # Home or Gap
	]



	# Automatic smoothing
	for p in pts:
		curve.add_point(p)

	# Adjust handles for smoothness - Improved for loops
	for i in range(curve.point_count):
		var p = curve.get_point_position(i)
		var prev_idx = (i - 1 + curve.point_count) % curve.point_count
		var next_idx = (i + 1) % curve.point_count

		# For non-loops, don't wrap handles at ends
		if not is_loop:
			if i == 0: prev_idx = 0
			if i == curve.point_count - 1: next_idx = curve.point_count - 1

		var prev = curve.get_point_position(prev_idx)
		var next = curve.get_point_position(next_idx)

		# Proportional handles to avoid "broken" sharp geometry
		var dir: Vector3
		if is_loop and (i == 0 or i == curve.point_count - 1):
			# If loop, use the actual circuit points for average tangent
			var p_start = curve.get_point_position(0)
			var p_end = curve.get_point_position(curve.point_count - 1)
			if p_start.distance_to(p_end) < 0.1:
				dir = (curve.get_point_position(1) - curve.get_point_position(curve.point_count - 2)).normalized()
			else:
				dir = (next - prev).normalized()
		else:
			dir = (next - prev).normalized()

		var d_prev = p.distance_to(prev)
		var d_next = p.distance_to(next)
		var handle_dist = min(d_prev, d_next) * 0.25 # Much shorter handles for safer sharp turns

		if i == 0 and not is_loop:
			curve.set_point_in(i, Vector3.ZERO)
			curve.set_point_out(i, dir * handle_dist)
		elif i == curve.point_count - 1 and not is_loop:
			curve.set_point_in(i, -dir * handle_dist)
			curve.set_point_out(i, Vector3.ZERO)
		else:
			curve.set_point_in(i, -dir * handle_dist)
			curve.set_point_out(i, dir * handle_dist)

	print("New longer track generated!")
	generate_world()

func _create_path_sides(point_count: int, width: float, mat: Material, y_offset: float, node_name: String):
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var curve = track_path.curve
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

		var top_l = pos - right + Vector3(0, side_y_offset, 0)
		var top_r = pos + right + Vector3(0, side_y_offset, 0)
		var bot_l = top_l - Vector3(0, depth, 0)
		var bot_r = top_r - Vector3(0, depth, 0)

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
	
	var curve = track_path.curve
	
	# --- CRITICAL: Match noise settings exactly to the terrain mesh (seed 12345, octaves 4) ---
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = noise_frequency
	noise.seed = 12345
	noise.fractal_octaves = 4
	
	var grass_mesh = _create_grass_mesh()
	# Dynamic grass shader with distance fade-out (collapses far away grass vertices to 0 for maximum performance, no wind sway)
	var shader = Shader.new()
	shader.code = "shader_type spatial;\nrender_mode cull_disabled, diffuse_toon, specular_disabled, depth_draw_opaque;\n\nuniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;\nuniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);\n\nvarying float height_val;\n\nvoid vertex() {\n\theight_val = VERTEX.y;\n\tvec3 view_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;\n\tfloat dist = length(view_pos);\n\tfloat max_dist = 100.0;\n\tfloat fade_r = 30.0;\n\tif (dist > max_dist) {\n\t\tVERTEX = vec3(0.0);\n\t\theight_val = 0.0;\n\t} else {\n\t\tif (dist > max_dist - fade_r) {\n\t\t\tfloat fade = (max_dist - dist) / fade_r;\n\t\t\tVERTEX *= fade;\n\t\t}\n\t}\n}\n\nvoid fragment() {\n\tvec4 tex_color = texture(albedo_texture, UV);\n\tALBEDO = tex_color.rgb * albedo_tint.rgb;\n\tALPHA = tex_color.a;\n\tALPHA_SCISSOR_THRESHOLD = 0.4;\n\tROUGHNESS = 1.0;\n\tEMISSION = ALBEDO * 0.12;\n}"
	
	var mat = ShaderMaterial.new()
	mat.shader = shader
	
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
	
	var transforms: Array[Transform3D] = []
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
		
		transforms.append(Transform3D(basis, pos))
		placed += 1
		
	if transforms.is_empty():
		return
		
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Procedural_Terrain_Grass"
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = false
	mm.use_custom_data = false
	mm.mesh = grass_mesh
	mm.instance_count = transforms.size()
	
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
		
	mmi.multimesh = _save_resource(mm, "terrain_grass_multimesh")
	mmi.material_override = mat
