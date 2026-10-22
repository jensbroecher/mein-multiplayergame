@tool
extends SceneTree

func _init() -> void:
	print("--- INSPECTING CONCRETE RAMP FBX ---")
	var scene: PackedScene = load("res://models/ramps/1f92b579825d1652d7ab8d760b289672.fbx")
	if not scene:
		print("Error: Could not load FBX scene")
		quit(1)
		return
	
	var inst: Node = scene.instantiate()
	var mdt := MeshDataTool.new()
	var arr_mesh: ArrayMesh
	if inst.get_child(0) is MeshInstance3D:
		var mi := inst.get_child(0) as MeshInstance3D
		arr_mesh = mi.mesh
	if arr_mesh:
		mdt.create_from_surface(arr_mesh, 0)
		var v_count := mdt.get_vertex_count()
		print("Vertex count: ", v_count)
		var min_v := Vector3.INF
		var max_v := -Vector3.INF
		for i in range(v_count):
			var v := mdt.get_vertex(i) * 100.0 # scale of node_0
			min_v = min_v.min(v)
			max_v = max_v.max(v)
		print("FBX Model (scale 100 applied):")
		print("  Min: ", min_v)
		print("  Max: ", max_v)
		print("  Size: ", max_v - min_v)
		print("In Lakeside Level (scale 20 applied):")
		print("  Min: ", min_v * 20.0)
		print("  Max: ", max_v * 20.0)
		print("  Size: ", (max_v - min_v) * 20.0)
		
		# Profile along X (scaled by 20 for world size)
		var bins := {}
		for i in range(v_count):
			var v := mdt.get_vertex(i) * 2000.0 # 100 * 20
			var n := mdt.get_vertex_normal(i)
			# Find upward facing vertices
			if n.y > 0.3:
				var x_bin := snappedf(v.x, 1.0)
				if not bins.has(x_bin):
					bins[x_bin] = {"min_y": v.y, "max_y": v.y, "min_z": v.z, "max_z": v.z, "count": 0}
				bins[x_bin]["min_y"] = minf(bins[x_bin]["min_y"], v.y)
				bins[x_bin]["max_y"] = maxf(bins[x_bin]["max_y"], v.y)
				bins[x_bin]["min_z"] = minf(bins[x_bin]["min_z"], v.z)
				bins[x_bin]["max_z"] = maxf(bins[x_bin]["max_z"], v.z)
				bins[x_bin]["count"] += 1
		
		print("\n--- Profile of upward faces along X (world meters): ---")
		var keys := bins.keys()
		keys.sort()
		for k in keys:
			var b = bins[k]
			print("X = %5.1f: Y=[%4.2f, %4.2f] Z_range=[%4.2f, %4.2f]" % [k, b["min_y"], b["max_y"], b["min_z"], b["max_z"]])
			
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
