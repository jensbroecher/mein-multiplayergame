@tool
extends SceneTree

func _init() -> void:
	print("--- INSPECTING CONCRETE FOOTBRIDGE FBX ---")
	var scene: PackedScene = load("res://models/concrete/8203ec9089a546140a4fa6915ed558b1.fbx")
	if not scene:
		print("Error: Could not load footbridge FBX")
		quit(1)
		return
		
	var inst: Node = scene.instantiate()
	_print_node(inst, 0)
	
	# Transform in LakesideLevel:
	# Transform3D(17.037151, 0, 27.108961, 0, 34, 0, -42.916008, 0, 10.761939, 67.77796, 2.818687, -410.94803)
	var t := Transform3D(
		Vector3(17.037151, 0, 27.108961),
		Vector3(0, 34, 0),
		Vector3(-42.916008, 0, 10.761939),
		Vector3(67.77796, 2.818687, -410.94803)
	)
	print("\n--- Lakeside Transform Analysis ---")
	print("Basis X: ", t.basis.x, " length: ", t.basis.x.length())
	print("Basis Y: ", t.basis.y, " length: ", t.basis.y.length())
	print("Basis Z: ", t.basis.z, " length: ", t.basis.z.length())
	print("Scale: ", t.basis.get_scale())
	print("Rotation Y (deg): ", rad_to_deg(t.basis.get_euler().y))
	print("Origin: ", t.origin)
	
	# Analyze mesh geometry
	var mdt := MeshDataTool.new()
	var arr_mesh: ArrayMesh = null
	for c in inst.get_children():
		if c is MeshInstance3D and c.mesh:
			arr_mesh = c.mesh
			break
	if arr_mesh:
		mdt.create_from_surface(arr_mesh, 0)
		var v_count := mdt.get_vertex_count()
		print("\nVertex count: ", v_count)
		var min_v := Vector3.INF
		var max_v := -Vector3.INF
		for i in range(v_count):
			var v := mdt.get_vertex(i) * 100.0 # FBX node scale is usually 100
			min_v = min_v.min(v)
			max_v = max_v.max(v)
		print("FBX Model (scale 100):")
		print("  Min: ", min_v)
		print("  Max: ", max_v)
		print("  Size: ", max_v - min_v)
		
		# World bounds in LakesideLevel
		var w_min := Vector3.INF
		var w_max := -Vector3.INF
		for i in range(v_count):
			var v := mdt.get_vertex(i) * 100.0 # scale 100 on child node
			var wv := t * v
			w_min = w_min.min(wv)
			w_max = w_max.max(wv)
		print("In Lakeside Level (world coords):")
		print("  World Min: ", w_min)
		print("  World Max: ", w_max)
		print("  World Size: ", w_max - w_min)
	
	quit(0)

func _print_node(n: Node, depth: int) -> void:
	var indent := "  ".repeat(depth)
	var info := "%s- %s (%s)" % [indent, n.name, n.get_class()]
	if n is Node3D:
		info += " pos=%s rot=%s scale=%s" % [n.position, n.rotation_degrees, n.scale]
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh:
			var aabb: AABB = mi.mesh.get_aabb()
			info += " aabb_pos=%s aabb_size=%s" % [aabb.position, aabb.size]
			info += " surfaces=%d" % mi.mesh.get_surface_count()
			for s in range(mi.mesh.get_surface_count()):
				var mat: Material = mi.get_surface_override_material(s)
				if not mat:
					mat = mi.mesh.surface_get_material(s)
				if mat:
					info += "\n%s    [surface %d mat: %s (%s)]" % [indent, s, mat.resource_name, mat.get_class()]
					if mat is StandardMaterial3D:
						var sm := mat as StandardMaterial3D
						info += " albedo_col=%s albedo_tex=%s roughness=%s metallic=%s normal=%s" % [
							sm.albedo_color,
							sm.albedo_texture.resource_path if sm.albedo_texture else "none",
							sm.roughness,
							sm.metallic,
							sm.normal_texture.resource_path if sm.normal_texture else "none"
						]
	print(info)
	for c in n.get_children():
		_print_node(c, depth + 1)
