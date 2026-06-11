@tool
extends Node3D

@export var generate_now: bool:
	set(val):
		generate_now = false
		if Engine.is_editor_hint():
			generate_world()

@export var track_path: Path3D
@export var terrain_size: Vector2 = Vector2(2000, 2000)
@export var terrain_resolution: int = 300 # Balanced for performance and file size
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
@export var regenerate: bool:
	set(val):
		regenerate = false
		if Engine.is_editor_hint():
			generate_world()

@export var create_longer_track: bool:
	set(val):
		create_longer_track = false
		if Engine.is_editor_hint():
			_rebuild_longer_track()

@export var grass_material: Material
@export var road_material: Material
@export var sand_material: Material
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
		child.free()

	# 1. Create Data Meshes
	var collision_mesh = _generate_mesh(true) # Flat under road for smooth driving
	var visual_mesh = _generate_mesh(false)   # Recessed under road to prevent leaking

	# 2. Visual Terrain
	var terrain_instance = MeshInstance3D.new()
	terrain_instance.name = "Terrain_Visual"
	terrain_instance.mesh = _save_resource(visual_mesh, "terrain_visual")
	terrain_instance.material_override = grass_material
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
	ResourceSaver.save(res, file_path)
	# Important: Load the resource back from disk to ensure it's treated as an external dependency
	return load(file_path)

func _set_owner_recursive(node: Node):

	if not Engine.is_editor_hint(): return
	var root = get_tree().edited_scene_root if get_tree() else null
	if not root: return
	for child in node.get_children():
		child.owner = root
		_set_owner_recursive(child)

func _generate_mesh(for_collision: bool) -> ArrayMesh:
	var noise = FastNoiseLite.new()
	noise.frequency = noise_frequency
	noise.seed = 12345

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var step_x = terrain_size.x / terrain_resolution
	var step_y = terrain_size.y / terrain_resolution
	var start_x = -terrain_size.x / 2.0
	var start_y = -terrain_size.y / 2.0

	var curve = track_path.curve

	for y in range(terrain_resolution + 1):
		for x in range(terrain_resolution + 1):
			var px = start_x + x * step_x
			var pz = start_y + y * step_y

			var h_noise = noise.get_noise_2d(px, pz) * hill_height

			var closest_pos = curve.get_closest_point(Vector3(px, 0.0, pz))
			var dist = Vector2(px, pz).distance_to(Vector2(closest_pos.x, closest_pos.z))

			var sand_edge = sand_width / 2.0
			var blend_dist = 60.0 # Tighter clearing for better mountain-road integration

			# Use smoothstep for the clearing transition to prevent floating-point "jagged" edges
			var clearing_blend = 1.0 - smoothstep(sand_edge - 2.0, sand_edge + blend_dist, dist)

			var road_h = curve.get_closest_point(Vector3(px, 0.0, pz)).y

			# Blend the natural hill noise with the road's elevation
			var height = lerp(h_noise, road_h, clearing_blend)

			# Apply the road basin (recession) with a smooth falloff to avoid gaps
			var basin_blend = 1.0 - smoothstep(sand_edge - 2.0, sand_edge, dist)
			if for_collision:
				height = lerp(height, road_h - terrain_recession_collision, basin_blend)
			else:
				height = lerp(height, road_h - terrain_recession_visual, basin_blend)


			# ORGANIC COASTLINE LOGIC:
			var world_pos = Vector2(px, pz)
			# Add noise to the distance to break the "round" shape
			var noise_val = noise.get_noise_2d(px * 0.1, pz * 0.1) * 200.0
			var dist_from_center = world_pos.length() + noise_val

			var falloff_start = terrain_size.x * 0.25
			var falloff_end = terrain_size.x * 0.45
			var edge_falloff = 1.0 - clamp((dist_from_center - falloff_start) / (falloff_end - falloff_start), 0.0, 1.0)

			# LAKE AND EDGE LOGIC COMBO:
			height *= edge_falloff

			var lake_center = Vector2(-450, -500)
			var lake_radius = 200.0
			var dist_to_lake = Vector2(px, pz).distance_to(lake_center)
			if dist_to_lake < lake_radius:
				var depth = -15.0
				var lake_blend = clamp((lake_radius - dist_to_lake) / 40.0, 0.0, 1.0)
				height = lerp(height, depth, lake_blend)

			if dist_from_center > falloff_end:
				height = -20.0

			st.set_uv(Vector2(px, pz))
			st.add_vertex(Vector3(px, height, pz))

	# Fixed Winding Order (CCW - Facing UP)
	for y in range(terrain_resolution):
		for x in range(terrain_resolution):
			var i = y * (terrain_resolution + 1) + x
			# Triangle 1 (v0, v1, v2)
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + terrain_resolution + 1)
			# Triangle 2 (v1, v3, v2)
			st.add_index(i + 1)
			st.add_index(i + terrain_resolution + 2)
			st.add_index(i + terrain_resolution + 1)

	st.generate_normals()
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

		var right = tangent.cross(Vector3.UP).normalized() * half_w

		# EXPLICIT LOOP SNAPPING:
		# If this is the last vertex of a loop, force it to match the first vertex exactly
		var final_pos = pos
		if is_loop and i == point_count:
			# Re-calculate first pos for perfect match
			final_pos = curve.sample_baked(0.0)

		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0, offset))
		st.add_vertex(final_pos - right + Vector3(0, y_offset, 0))

		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(width, offset)) # Use width instead of 1 to prevent texture stretching
		st.add_vertex(final_pos + right + Vector3(0, y_offset, 0))

	# INDEX LOOP (CCW - Facing UP)
	for i in range(point_count):
		var v0 = i * 2
		var v1 = v0 + 1
		var v2 = (i + 1) * 2
		var v3 = v2 + 1

		# T1: Left i, Left i+1, Right i
		st.add_index(v0); st.add_index(v2); st.add_index(v1)
		# T2: Right i, Left i+1, Right i+1
		st.add_index(v1); st.add_index(v2); st.add_index(v3)

		# --- ADD UNDERSIDE (Visibility from below) ---
		# Reversed winding order for bottom faces
		st.add_index(v0); st.add_index(v1); st.add_index(v2)
		st.add_index(v1); st.add_index(v3); st.add_index(v2)


	# REMOVED: Manual Loop Closure.
	# Since the track path starts and ends at (0,0,0), the naturally generated triangles already close the visual gap.
	# Adding extra faces created overlapping/degenerate triangles.


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
		var right = tangent.cross(Vector3.UP).normalized() * half_w

		var final_pos = pos
		if is_loop and i == point_count:
			final_pos = curve.sample_baked(0.0)

		var tl = final_pos - right + Vector3(0, y_offset, 0)
		var tr = final_pos + right + Vector3(0, y_offset, 0)
		var bl = tl - Vector3(0, thickness, 0)
		var br = tr - Vector3(0, thickness, 0)

		st.add_vertex(tl) # 4*i + 0
		st.add_vertex(tr) # 4*i + 1
		st.add_vertex(bl) # 4*i + 2
		st.add_vertex(br) # 4*i + 3

	for i in range(point_count):
		var base = i * 4
		var nxt = (i + 1) * 4

		# Top Face
		st.add_index(base + 0); st.add_index(nxt + 0); st.add_index(base + 1)
		st.add_index(base + 1); st.add_index(nxt + 0); st.add_index(nxt + 1)

		# Bottom Face (Reverse winding)
		st.add_index(base + 2); st.add_index(base + 3); st.add_index(nxt + 2)
		st.add_index(base + 3); st.add_index(nxt + 3); st.add_index(nxt + 2)

		# Left Side
		st.add_index(base + 0); st.add_index(base + 2); st.add_index(nxt + 0)
		st.add_index(base + 2); st.add_index(nxt + 2); st.add_index(nxt + 0)

		# Right Side
		st.add_index(base + 1); st.add_index(nxt + 1); st.add_index(base + 3)
		st.add_index(base + 3); st.add_index(nxt + 1); st.add_index(nxt + 3)

	# REMOVED: Manual Collision Loop Closure.
	# Path naturally loops at (0,0,0). Manual closure was creating degenerate geometry.

	var track_mesh = st.commit()
	var static_body = StaticBody3D.new()
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

		var top_l = pos - right + Vector3(0, y_offset, 0)
		var top_r = pos + right + Vector3(0, y_offset, 0)
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
