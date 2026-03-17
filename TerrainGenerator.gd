@tool
extends Node3D

@export var generate_now: bool:
	set(val):
		generate_now = false
		if Engine.is_editor_hint():
			generate_world()

@export var track_path: Path3D
@export var terrain_size: Vector2 = Vector2(1000, 1000)
@export var terrain_resolution: int = 300 # Balanced for performance and file size
@export var noise_frequency: float = 0.008 # Detailed hills
@export var hill_height: float = 50.0 # Taller hills

@export var road_width: float = 14.0
@export var sand_width: float = 20.0

@export var grass_material: Material
@export var road_material: Material
@export var sand_material: Material

func _ready():
	if not track_path: return
	generate_world()

func generate_world():
	if not track_path: return
	
	for child in get_children():
		child.queue_free()

	# 1. Create Data Meshes
	var collision_mesh = _generate_mesh(true) # Flat under road for smooth driving
	var visual_mesh = _generate_mesh(false)     # Recessed under road to prevent leaking

	# 2. Visual Terrain
	var terrain_instance = MeshInstance3D.new()
	terrain_instance.name = "Terrain_Visual"
	terrain_instance.mesh = visual_mesh
	terrain_instance.material_override = grass_material
	terrain_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(terrain_instance)
	
	# 3. Unified Collision
	var static_body = StaticBody3D.new()
	static_body.name = "Unified_World_Collision"
	add_child(static_body)
	var collision_shape = CollisionShape3D.new()
	collision_shape.shape = collision_mesh.create_trimesh_shape()
	static_body.add_child(collision_shape)

	# 4. Visual Overlays
	_generate_road_and_sand()
	
	if Engine.is_editor_hint():
		_set_owner_recursive(self)

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
			var blend_dist = 30.0
			var blend = clamp((dist - sand_edge) / blend_dist, 0.0, 1.0)
			
			var height = h_noise * blend
			
			if dist < sand_edge:
				var road_edge = road_width / 2.0
				if for_collision:
					if dist < road_edge:
						height = 0.15 # Road height
					else:
						height = 0.08 # Sand height
				else:
					height = -0.2 # Recess visuals
			
			# Raw world UVs for shader
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
	var points_count = int(length / 0.8)
	
	_create_path_visual(points_count, sand_width, sand_material, 0.08, "Visual_Sand")
	_create_path_visual(points_count, road_width, road_material, 0.15, "Visual_Road")

func _create_path_visual(point_count: int, width: float, mat: Material, y_offset: float, node_name: String):
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var curve = track_path.curve
	var half_w = width / 2.0
	var length = curve.get_baked_length()
	
	var mat_dup = mat.duplicate()
	if node_name.contains("Road"):
		mat_dup.render_priority = 2
	else:
		mat_dup.render_priority = 1
	
	# VERTEX LOOP
	for i in range(point_count + 1):
		var offset = (float(i) / point_count) * length
		var pos = curve.sample_baked(offset)
		
		# Forced Flat Orientation
		var next_pos = curve.sample_baked(min(offset + 0.5, length))
		var tangent = (next_pos - pos).normalized()
		if tangent.length() < 0.01:
			tangent = (pos - curve.sample_baked(max(offset - 0.5, 0.0))).normalized()
		var right = tangent.cross(Vector3.UP).normalized() * half_w
		
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0, offset))
		st.add_vertex(pos - right + Vector3(0, y_offset, 0))
		
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(1, offset))
		st.add_vertex(pos + right + Vector3(0, y_offset, 0))
		
	# INDEX LOOP (CCW - Facing UP)
	for i in range(point_count):
		var v0 = i * 2; var v1 = v0 + 1; var v2 = v0 + 2; var v3 = v0 + 3
		# T1: Left0, Left1, Right0
		st.add_index(v0)
		st.add_index(v2)
		st.add_index(v1)
		# T2: Right0, Left1, Right1
		st.add_index(v1)
		st.add_index(v2)
		st.add_index(v3)
		
	st.generate_tangents()
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.mesh = st.commit()
	mesh_instance.material_override = mat_dup
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
