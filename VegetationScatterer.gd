@tool
class_name VegetationScatterer
extends Node3D

@export_group("Scatter Settings")
@export var size: Vector2 = Vector2(50.0, 50.0):
	set(val):
		size = val
		_update_boundary()

@export var tree_count: int = 10
@export var flower_count: int = 25
@export var grass_count: int = 150

@export_group("Actions")
@export var trigger_scatter: bool = false:
	set(val):
		trigger_scatter = false
		if Engine.is_editor_hint():
			scatter()

@export var trigger_clear: bool = false:
	set(val):
		trigger_clear = false
		if Engine.is_editor_hint():
			clear_vegetation()

# Paths to the models
const TREE_PATHS = [
	"res://models/trees/tree.glb",
	"res://models/trees/tree_2.glb",
	"res://models/trees/tree_3.glb",
	"res://models/trees/tree_4.glb"
]

const FLOWER_PATHS = [
	"res://models/trees/flower_blue.glb",
	"res://models/trees/flower_white.glb"
]

const GRASS_PATH = "res://models/trees/grass.glb"

func _ready():
	_update_boundary()
	if not Engine.is_editor_hint():
		# Hide boundary helper during game play
		var helper = get_node_or_null("BoundaryHelper")
		if helper:
			helper.visible = false

func _update_boundary():
	# Only show boundary helper in editor
	if not Engine.is_editor_hint():
		return
		
	var helper = get_node_or_null("BoundaryHelper")
	if not helper:
		helper = MeshInstance3D.new()
		helper.name = "BoundaryHelper"
		add_child(helper)
		
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = size.x / 2.0
	cylinder.bottom_radius = size.x / 2.0
	cylinder.height = 0.1
	helper.mesh = cylinder
	
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.25, 0.85, 0.25, 0.15) # Semi-transparent green
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	helper.material_override = mat
	helper.position = Vector3.ZERO

func clear_vegetation():
	var container = get_node_or_null("VegetationContainer")
	if container:
		container.free()
	print("Vegetation cleared!")

func scatter():
	clear_vegetation()
	
	var root = get_tree().edited_scene_root if get_tree() else null
	if not root:
		printerr("Cannot scatter: No edited scene root found.")
		return
		
	var container = Node3D.new()
	container.name = "VegetationContainer"
	add_child(container)
	container.owner = root
	
	# Create green material for grass using a shader to correctly mask transparency
	var shader = Shader.new()
	shader.code = "shader_type spatial;\nrender_mode cull_disabled;\n\nuniform vec4 albedo : source_color = vec4(0.2, 0.52, 0.15, 1.0);\nuniform sampler2D albedo_texture : source_color, filter_nearest_mipmap;\nuniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.1;\n\nvoid fragment() {\n\tvec4 tex_color = texture(albedo_texture, UV);\n\tALBEDO = albedo.rgb;\n\tfloat alpha = tex_color.a;\n\tif (tex_color.a >= 0.99) {\n\t\talpha = tex_color.r;\n\t}\n\tALPHA = alpha;\n\tALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;\n}"
	
	var grass_mat = ShaderMaterial.new()
	grass_mat.shader = shader
	grass_mat.set_shader_parameter("albedo", Color(0.28, 0.68, 0.15))
	
	var tex_path = "res://models/trees/grass_tall-grass-png-44173_bw.webp"
	if ResourceLoader.exists(tex_path):
		var tex = load(tex_path)
		grass_mat.set_shader_parameter("albedo_texture", tex)
	
	var space_state = get_world_3d().direct_space_state
	if not space_state:
		printerr("Cannot scatter: Physics space state not available.")
		return

	# Load resources
	var tree_scenes = []
	for p in TREE_PATHS:
		if ResourceLoader.exists(p):
			tree_scenes.append(load(p))
			
	var flower_scenes = []
	for p in FLOWER_PATHS:
		if ResourceLoader.exists(p):
			flower_scenes.append(load(p))
			
	var grass_scene = load(GRASS_PATH) if ResourceLoader.exists(GRASS_PATH) else null
	
	if tree_scenes.is_empty() and flower_scenes.is_empty() and not grass_scene:
		printerr("No vegetation models found in models/trees!")
		return

	# Spawn grass
	if grass_scene and grass_count > 0:
		_scatter_group(grass_scene, grass_count, false, 0.45, 0.95, grass_mat, container, root, space_state)
		
	# Spawn flowers
	if not flower_scenes.is_empty() and flower_count > 0:
		_scatter_group_multi(flower_scenes, flower_count, false, 0.7, 1.25, null, container, root, space_state)

	# Spawn trees
	if not tree_scenes.is_empty() and tree_count > 0:
		_scatter_group_multi(tree_scenes, tree_count, true, 0.65, 1.35, null, container, root, space_state)
		
	print("Vegetation scattering completed successfully!")

func _scatter_group(scene: PackedScene, count: int, is_tree: bool, scale_min: float, scale_max: float, mat_override: Material, container: Node3D, root: Node, space_state: PhysicsDirectSpaceState3D):
	for i in range(count):
		var local_pos = _get_random_point_in_circle(size.x / 2.0)
		var global_pos = global_transform * local_pos
		
		# Raycast down to find ground
		var start = global_pos + Vector3(0, 300.0, 0)
		var end = global_pos + Vector3(0, -300.0, 0)
		var query = PhysicsRayQueryParameters3D.create(start, end)
		query.collision_mask = 1 # Collide with terrain
		var result = space_state.intersect_ray(query)
		
		if result:
			# Skip underwater spots
			if result.position.y < -9.5:
				continue
				
			var instance = scene.instantiate()
			container.add_child(instance)
			instance.owner = root
			
			# Position
			instance.global_position = result.position
			
			# Rotation / alignment
			var basis = Basis()
			if is_tree:
				var fwd = Vector3.FORWARD.rotated(Vector3.UP, randf_range(0, PI * 2))
				basis = Basis.looking_at(fwd, Vector3.UP)
			else:
				var up = result.normal
				var fwd = Vector3.FORWARD
				if abs(up.dot(fwd)) > 0.99:
					fwd = Vector3.UP
				var right = fwd.cross(up).normalized()
				fwd = up.cross(right).normalized()
				basis = Basis(right, up, -fwd)
				basis = basis.rotated(up, randf_range(0, PI * 2))
				
			instance.global_transform.basis = basis
			
			# Scale
			var s = randf_range(scale_min, scale_max)
			instance.scale = Vector3(s, s, s)
			
			# Material override (for grass)
			if mat_override:
				_apply_material_override(instance, mat_override)
				
			# Add collisions for trees (as siblings in container to ensure correct serialization)
			if is_tree:
				var static_body = StaticBody3D.new()
				static_body.name = "StaticBody_" + instance.name + "_" + str(i)
				container.add_child(static_body)
				static_body.owner = root
				
				# Position at the exact same location/rotation/scale as the tree instance
				static_body.global_transform = instance.global_transform
				
				var collision_shape = CollisionShape3D.new()
				collision_shape.name = "CollisionShape3D"
				var shape = CylinderShape3D.new()
				shape.radius = 0.35
				shape.height = 4.0
				collision_shape.shape = shape
				collision_shape.position = Vector3(0, 2.0, 0)
				static_body.add_child(collision_shape)
				collision_shape.owner = root

func _scatter_group_multi(scenes: Array, count: int, is_tree: bool, scale_min: float, scale_max: float, mat_override: Material, container: Node3D, root: Node, space_state: PhysicsDirectSpaceState3D):
	for i in range(count):
		var local_pos = _get_random_point_in_circle(size.x / 2.0)
		var global_pos = global_transform * local_pos
		
		# Raycast down to find ground
		var start = global_pos + Vector3(0, 300.0, 0)
		var end = global_pos + Vector3(0, -300.0, 0)
		var query = PhysicsRayQueryParameters3D.create(start, end)
		query.collision_mask = 1 # Collide with terrain
		var result = space_state.intersect_ray(query)
		
		if result:
			if result.position.y < -9.5:
				continue
				
			var scene = scenes[randi() % scenes.size()]
			var instance = scene.instantiate()
			container.add_child(instance)
			instance.owner = root
			
			# Position
			instance.global_position = result.position
			
			# Rotation / alignment
			var basis = Basis()
			if is_tree:
				var fwd = Vector3.FORWARD.rotated(Vector3.UP, randf_range(0, PI * 2))
				basis = Basis.looking_at(fwd, Vector3.UP)
			else:
				var up = result.normal
				var fwd = Vector3.FORWARD
				if abs(up.dot(fwd)) > 0.99:
					fwd = Vector3.UP
				var right = fwd.cross(up).normalized()
				fwd = up.cross(right).normalized()
				basis = Basis(right, up, -fwd)
				basis = basis.rotated(up, randf_range(0, PI * 2))
				
			instance.global_transform.basis = basis
			
			# Scale
			var s = randf_range(scale_min, scale_max)
			instance.scale = Vector3(s, s, s)
			
			if mat_override:
				_apply_material_override(instance, mat_override)
				
			# Add collisions for trees (as siblings in container to ensure correct serialization)
			if is_tree:
				var static_body = StaticBody3D.new()
				static_body.name = "StaticBody_" + instance.name + "_" + str(i)
				container.add_child(static_body)
				static_body.owner = root
				
				# Position at the exact same location/rotation/scale as the tree instance
				static_body.global_transform = instance.global_transform
				
				var collision_shape = CollisionShape3D.new()
				collision_shape.name = "CollisionShape3D"
				var shape = CylinderShape3D.new()
				shape.radius = 0.35
				shape.height = 4.0
				collision_shape.shape = shape
				collision_shape.position = Vector3(0, 2.0, 0)
				static_body.add_child(collision_shape)
				collision_shape.owner = root

func _apply_material_override(node: Node, mat: Material):
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_apply_material_override(child, mat)

func _get_random_point_in_circle(radius: float) -> Vector3:
	while true:
		var rx = randf_range(-radius, radius)
		var rz = randf_range(-radius, radius)
		var dist = sqrt(rx * rx + rz * rz)
		if dist <= radius:
			# Linear density falloff: higher chance to spawn at the center, fading to 0 at the edge
			var prob = 1.0 - (dist / radius)
			if randf() < prob:
				return Vector3(rx, 0.0, rz)
	return Vector3.ZERO
