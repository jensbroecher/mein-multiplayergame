@tool
extends SceneTree

func _init() -> void:
	var scene: PackedScene = load("res://models/ramps/1f92b579825d1652d7ab8d760b289672.fbx")
	var inst: Node = scene.instantiate()
	var mi := inst.get_child(0) as MeshInstance3D
	var arr_mesh: ArrayMesh = mi.mesh
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(arr_mesh, 0)
	
	var scale_factor := 2000.0
	
	# Let's inspect the road surface profile along the centerline (Z around 0)
	print("--- ROAD SURFACE CENTERLINE PROFILE (Z within [-0.5, 0.5]) ---")
	var center_pts: Array[Vector3] = []
	for i in range(mdt.get_vertex_count()):
		var v := mdt.get_vertex(i) * scale_factor
		var n := mdt.get_vertex_normal(i)
		if abs(v.z) < 0.3 and n.y > 0.5:
			center_pts.append(v)
	center_pts.sort_custom(func(a, b): return a.x < b.x)
	var prev_x := -999.0
	for p in center_pts:
		if abs(p.x - prev_x) > 0.5:
			print("X = %6.2f -> Y = %5.2f" % [p.x, p.y])
			prev_x = p.x

	# Let's inspect the side profile (curbs/walls)
	print("\n--- LEFT SIDE PROFILE (Z near -4.0) ---")
	var left_pts: Array[Vector3] = []
	for i in range(mdt.get_vertex_count()):
		var v := mdt.get_vertex(i) * scale_factor
		if v.z < -3.8 and v.z > -4.5 and mdt.get_vertex_normal(i).y > 0.3:
			left_pts.append(v)
	left_pts.sort_custom(func(a, b): return a.x < b.x)
	prev_x = -999.0
	for p in left_pts:
		if abs(p.x - prev_x) > 1.0:
			print("X = %6.2f, Z = %5.2f -> Y = %5.2f" % [p.x, p.z, p.y])
			prev_x = p.x

	# What is underneath the ramp? Let's check Y range at various X for all points
	print("\n--- UNDERSIDE / BASE PROFILE ---")
	for tx in [-10.0, -5.0, 0.0, 5.0, 8.0]:
		var y_at_x: Array[float] = []
		for i in range(mdt.get_vertex_count()):
			var v := mdt.get_vertex(i) * scale_factor
			if abs(v.x - tx) < 0.4:
				y_at_x.append(v.y)
		y_at_x.sort()
		if y_at_x.size() > 0:
			print("At X = %5.1f: Lowest Y = %5.2f, Highest Y = %5.2f, total pts in slice = %d" % [
				tx, y_at_x[0], y_at_x[y_at_x.size() - 1], y_at_x.size()
			])

	quit(0)
