extends SceneTree

# scratch/test_tornado_csg_build.gd
# Tests building TornadoCSG and baking it to generated/tornado.res

func _initialize():
	print("--- BUILDING TORNADO CSG ---")
	var root := CSGCombiner3D.new()
	root.name = "TornadoCSG"

	# 1. Outer Funnel Trumpet
	var outer_poly := CSGPolygon3D.new()
	outer_poly.name = "OuterFunnel"
	outer_poly.mode = CSGPolygon3D.MODE_SPIN
	outer_poly.spin_degrees = 360.0
	outer_poly.spin_sides = 36
	outer_poly.smooth_faces = true

	var outer_pts := PackedVector2Array()
	var h_steps := 28
	var total_h := 34.0
	var r_base := 0.85
	var r_top := 19.8
	var thickness := 0.45

	# Outer surface going UP
	for i in range(h_steps + 1):
		var t := float(i) / float(h_steps)
		var y := t * total_h
		var r := r_base + (r_top - r_base) * pow(t, 1.65)
		outer_pts.append(Vector2(r, y))

	# Rounded top rim curve
	for a in range(1, 5):
		var ang := float(a) / 4.0 * PI
		var rim_r := r_top - (thickness * 0.5) + cos(ang) * (thickness * 0.5)
		var rim_y := total_h + sin(ang) * 0.4
		outer_pts.append(Vector2(rim_r, rim_y))

	# Inner surface going DOWN
	for i in range(h_steps, -1, -1):
		var t := float(i) / float(h_steps)
		var y := t * total_h
		var r_outer := r_base + (r_top - r_base) * pow(t, 1.65)
		var r_inner := maxf(0.3, r_outer - thickness * (0.8 + 0.4 * t))
		outer_pts.append(Vector2(r_inner, y))

	outer_poly.polygon = outer_pts
	root.add_child(outer_poly)

	# 2. Inner Core Column (gives depth and density to the eye of the storm)
	var core_poly := CSGPolygon3D.new()
	core_poly.name = "InnerCore"
	core_poly.mode = CSGPolygon3D.MODE_SPIN
	core_poly.spin_degrees = 360.0
	core_poly.spin_sides = 24
	core_poly.smooth_faces = true

	var core_pts := PackedVector2Array()
	var core_h := 29.0
	var core_steps := 18
	var cr_base := 0.45
	var cr_top := 8.2
	var c_thick := 0.35

	for i in range(core_steps + 1):
		var t := float(i) / float(core_steps)
		var y := t * core_h
		var r := cr_base + (cr_top - cr_base) * pow(t, 1.4)
		core_pts.append(Vector2(r, y))

	for i in range(core_steps, -1, -1):
		var t := float(i) / float(core_steps)
		var y := t * core_h
		var r_outer := cr_base + (cr_top - cr_base) * pow(t, 1.4)
		var r_inner := maxf(0.15, r_outer - c_thick)
		core_pts.append(Vector2(r_inner, y))

	core_poly.polygon = core_pts
	root.add_child(core_poly)

	# Add to tree to allow CSG compilation
	var w := Node3D.new()
	self.root.add_child(w)
	w.add_child(root)

	for i in 3:
		await process_frame

	var mesh: ArrayMesh = root.bake_static_mesh()
	if mesh == null:
		push_error("Failed to bake CSG mesh!")
		quit(1)
		return

	var tris := 0
	for s in mesh.get_surface_count():
		var idx_len = mesh.surface_get_array_index_len(s)
		tris += idx_len / 3 if idx_len > 0 else mesh.surface_get_array_len(s) / 3
	print("CSG Bake successful! Surfaces=%d, Tris=%d, AABB=%s" % [mesh.get_surface_count(), tris, mesh.get_aabb()])

	# Save test bake to generated/tornado.res
	var out_path := "res://generated/tornado.res"
	var err := ResourceSaver.save(mesh, out_path, ResourceSaver.FLAG_COMPRESS)
	if err == OK:
		print("Successfully saved ", out_path)
	else:
		push_error("Failed to save ", out_path, ": ", err)

	quit()
