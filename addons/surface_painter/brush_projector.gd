@tool
extends Node3D
class_name BrushProjector

var ring_mesh_instance: MeshInstance3D
var inner_ring_mesh_instance: MeshInstance3D
var normal_arrow_instance: MeshInstance3D
var ring_material: StandardMaterial3D
var inner_material: StandardMaterial3D

var current_radius: float = 10.0
var current_hardness: float = 0.5
var current_color: Color = Color(1.0, 0.25, 0.25, 0.85)

func _init():
	name = "SurfacePainter_BrushProjector"
	visible = false

	# Outer Ring
	ring_mesh_instance = MeshInstance3D.new()
	ring_mesh_instance.name = "OuterRing"
	ring_material = StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.albedo_color = current_color
	ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring_material.no_depth_test = true
	ring_mesh_instance.material_override = ring_material
	add_child(ring_mesh_instance)

	# Inner Hardness Ring
	inner_ring_mesh_instance = MeshInstance3D.new()
	inner_ring_mesh_instance.name = "InnerRing"
	inner_material = StandardMaterial3D.new()
	inner_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	inner_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	inner_material.albedo_color = Color(current_color.r, current_color.g, current_color.b, 0.45)
	inner_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	inner_material.no_depth_test = true
	inner_ring_mesh_instance.material_override = inner_material
	add_child(inner_ring_mesh_instance)

	_rebuild_mesh()


func update_brush(hit_pos: Vector3, hit_normal: Vector3, radius: float, hardness: float, color: Color):
	visible = true
	global_position = hit_pos + hit_normal * 0.05 # slight offset to avoid z-fighting

	# Orient ring flat to surface normal
	var norm = hit_normal.normalized()
	if abs(norm.dot(Vector3.UP)) > 0.999:
		# Nearly vertical normal
		var up_ref = Vector3.FORWARD if norm.y > 0 else Vector3.BACK
		look_at(global_position + norm, up_ref)
	else:
		look_at(global_position + norm, Vector3.UP)

	if abs(radius - current_radius) > 0.01 or abs(hardness - current_hardness) > 0.01:
		current_radius = radius
		current_hardness = hardness
		_rebuild_mesh()

	if color != current_color:
		current_color = color
		ring_material.albedo_color = current_color
		inner_material.albedo_color = Color(current_color.r, current_color.g, current_color.b, 0.4)


func hide_brush():
	visible = false


func _rebuild_mesh():
	# Build Outer Ring
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINE_STRIP)
	var segments = 64
	for i in range(segments + 1):
		var angle = (float(i) / float(segments)) * TAU
		var x = cos(angle) * current_radius
		var y = sin(angle) * current_radius
		st.add_vertex(Vector3(x, y, 0.0))
	ring_mesh_instance.mesh = st.commit()

	# Build Inner Hardness Ring
	var inner_radius = current_radius * clamp(current_hardness, 0.05, 0.99)
	var st_inner = SurfaceTool.new()
	st_inner.begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in range(segments + 1):
		var angle = (float(i) / float(segments)) * TAU
		var x = cos(angle) * inner_radius
		var y = sin(angle) * inner_radius
		st_inner.add_vertex(Vector3(x, y, 0.0))
	inner_ring_mesh_instance.mesh = st_inner.commit()
