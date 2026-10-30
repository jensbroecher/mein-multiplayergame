extends SceneTree

const MirageBuilder = preload("res://MirageBuilder.gd")
const CB = preload("res://CarBuilder.gd")

class TestMirageBuilder extends MirageBuilder:
	func _side_parts(b) -> void:
		var knuckle_x := 0.475
		var k_fwd := AXLE_F
		b.tube(PackedVector3Array([Vector3(0.14, 0.255, k_fwd - 0.14), Vector3(knuckle_x - 0.01, 0.235, k_fwd)]), 0.012, 8, CB.M_DARK, C_STEEL, true, true)
		b.tube(PackedVector3Array([Vector3(0.14, 0.255, k_fwd + 0.14), Vector3(knuckle_x - 0.01, 0.235, k_fwd)]), 0.012, 8, CB.M_DARK, C_STEEL, true, true)
		b.tube(PackedVector3Array([Vector3(0.16, 0.385, k_fwd - 0.10), Vector3(knuckle_x - 0.01, 0.360, k_fwd)]), 0.010, 8, CB.M_DARK, C_STEEL, true, true)
		b.tube(PackedVector3Array([Vector3(0.16, 0.385, k_fwd + 0.10), Vector3(knuckle_x - 0.01, 0.360, k_fwd)]), 0.010, 8, CB.M_DARK, C_STEEL, true, true)
		b.rbox(Transform3D(Basis(), Vector3(knuckle_x, HUB_Y, k_fwd)), Vector3(0.018, 0.075, 0.032), 0.008, 1, CB.M_DARK, C_STEEL)
		b.tube(PackedVector3Array([Vector3(knuckle_x, HUB_Y, k_fwd), Vector3(WHEEL_X - 0.02, HUB_Y, k_fwd)]), 0.016, 10, CB.M_ALLOY, C_ALLOY_DARK, false, true)
		b.tube(PackedVector3Array([Vector3(0.12, 0.280, k_fwd), Vector3(knuckle_x - 0.01, HUB_Y, k_fwd)]), 0.012, 8, CB.M_DARK, C_STEEL, false, false)
		b.tube(PackedVector3Array([Vector3(0.15, 0.300, k_fwd + 0.10), Vector3(knuckle_x - 0.01, 0.290, k_fwd + 0.06)]), 0.008, 6, CB.M_ALLOY, C_ALLOY_DARK, false, false)
		coilover(b, Vector3(0.365, 0.245, k_fwd - 0.015), Vector3(0.200, 0.540, k_fwd + 0.025), 0.018, 0.030, 7.5, C_ALLOY, C_ALLOY_DARK, C_CHROME, C_DARK)

		var k_rear := AXLE_R
		b.tube(PackedVector3Array([Vector3(0.16, 0.265, k_rear - 0.25), Vector3(knuckle_x - 0.01, 0.245, k_rear)]), 0.013, 8, CB.M_DARK, C_STEEL, true, true)
		b.tube(PackedVector3Array([Vector3(0.16, 0.265, k_rear + 0.12), Vector3(knuckle_x - 0.01, 0.245, k_rear)]), 0.013, 8, CB.M_DARK, C_STEEL, true, true)
		b.tube(PackedVector3Array([Vector3(0.18, 0.420, k_rear - 0.10), Vector3(knuckle_x - 0.01, 0.370, k_rear)]), 0.011, 8, CB.M_DARK, C_STEEL, true, true)
		b.rbox(Transform3D(Basis(), Vector3(knuckle_x, HUB_Y, k_rear)), Vector3(0.018, 0.076, 0.034), 0.008, 1, CB.M_DARK, C_STEEL)
		b.tube(PackedVector3Array([Vector3(knuckle_x, HUB_Y, k_rear), Vector3(WHEEL_X - 0.02, HUB_Y, k_rear)]), 0.016, 10, CB.M_ALLOY, C_ALLOY_DARK, false, true)
		b.tube(PackedVector3Array([Vector3(0.14, 0.290, k_rear), Vector3(knuckle_x - 0.01, HUB_Y, k_rear)]), 0.013, 8, CB.M_DARK, C_STEEL, false, false)
		coilover(b, Vector3(0.375, 0.255, k_rear + 0.025), Vector3(0.220, 0.555, k_rear - 0.025), 0.019, 0.032, 8.0, C_ALLOY, C_ALLOY_DARK, C_CHROME, C_DARK)

		_build_floating_winglet(b, AXLE_F, 0.250, 0.570, 0.550, 0.018, true)
		_build_floating_winglet(b, AXLE_R, 0.280, 0.585, 0.580, 0.020, false)

		# 4. Razor-Sharp Slanted Chevron Headlight Blade (Cleanly layered: blade 5mm proud of housing)
		var hl_pos := Vector3(0.190, 0.410, -1.042)
		var hl_dir := Vector3(0.15, -0.06, -0.99).normalized()
		var hl_basis := facing(hl_dir)
		# Dark housing: depth 0.010 -> front face at local z = +0.010, height 0.022 easily covers chevron blade
		b.rbox(Transform3D(hl_basis, hl_pos), Vector3(0.058, 0.022, 0.010), 0.004, 1, CB.M_DARK, C_DARKER)
		# Piercing horizontal LED blade: center +0.010, depth 0.005 -> front face at +0.015 (5mm proud of housing)
		b.rbox(Transform3D(hl_basis, hl_pos + hl_basis.z * 0.010), Vector3(0.044, 0.006, 0.005), 0.003, 1, CB.M_HEADLAMP, Color(1, 1, 1))
		# Angled outer chevron accent blade: center +0.010, depth 0.005 -> front face at +0.015 (5mm proud of housing)
		b.rbox(Transform3D(hl_basis * Basis(Vector3.FORWARD, 0.42), hl_pos + hl_basis.x * 0.040 + hl_basis.z * 0.010), Vector3(0.006, 0.018, 0.005), 0.002, 1, CB.M_HEADLAMP, Color(1, 1, 1))

		var mirror_c := Vector3(0.360, 0.595, -0.210)
		b.tube(PackedVector3Array([Vector3(0.320, 0.565, -0.210), mirror_c]), 0.008, 8, CB.M_DARK, C_CARBON, true, false)
		var mir_xf := Transform3D(Basis(Vector3.UP, -0.18) * Basis(Vector3.RIGHT, 0.06), mirror_c + Vector3(0.038, 0.012, 0.0))
		b.rbox(mir_xf, Vector3(0.036, 0.018, 0.022), 0.007, 2, CB.M_PAINT, Color(1, 1, 1))
		b.rbox(mir_xf * Transform3D(Basis(), Vector3(0.0, 0.0, 0.018)), Vector3(0.030, 0.014, 0.003), 0.003, 1, CB.M_CHROME, C_CHROME)

		b.rbox(Transform3D(Basis(), Vector3(0.380, 0.290, -0.06)), Vector3(0.020, 0.018, 0.280), 0.006, 1, CB.M_DARK, C_CARBON)

		var ex_c := Vector3(0.110, 0.425, 0.985)
		b.tube(PackedVector3Array([ex_c + Vector3(0, 0, -0.07), ex_c + Vector3(0, 0, 0.035)]), 0.020, 14, CB.M_ALLOY, C_ALLOY, false, false)
		b.tube(PackedVector3Array([ex_c + Vector3(0, 0, -0.06), ex_c + Vector3(0, 0, 0.036)]), 0.016, 12, CB.M_DARK, C_DARKER, false, false)
		b.rbox(Transform3D(Basis(), Vector3(0.325, 0.540, 0.940)), Vector3(0.006, 0.045, 0.060), 0.004, 1, CB.M_DARK, C_CARBON)

	func _centre_parts(b) -> void:
		var skid_angle := 0.32
		var skid_xf := Transform3D(Basis(Vector3.RIGHT, skid_angle), Vector3(0.0, 0.295, -1.040))
		b.rbox(skid_xf, Vector3(0.180, 0.007, 0.100), 0.005, 1, CB.M_ALLOY, C_ALLOY)
		var mesh_c := Vector3(0.0, 0.340, -1.065)
		b.rbox(Transform3D(Basis(), mesh_c), Vector3(0.140, 0.026, 0.016), 0.005, 1, CB.M_DARK, C_DARKER)
		for k in 4:
			bar(b, mesh_c + Vector3(0, -0.016 + 0.011 * k, 0.010), Vector3(0.130, 0.002, 0.002), CB.M_DARK, C_CARBON)

		b.tube(_rounded([
			Vector3(-0.16, 0.310, -1.02), Vector3(-0.13, 0.340, -1.07),
			Vector3( 0.13, 0.340, -1.07), Vector3( 0.16, 0.310, -1.02)
		], 0.03), 0.012, 8, CB.M_ALLOY, C_ALLOY, true, true)

		for sx in [-1.0, 1.0]:
			b.rbox(Transform3D(Basis(), Vector3(0.08 * sx, 0.300, -1.060)), Vector3(0.010, 0.014, 0.022), 0.004, 1, CB.M_ANODISED, Color(1, 1, 1))

		for sx in [-1.0, 1.0]:
			var vent_pos := Vector3(0.110 * sx, 0.465, -0.780)
			var vent_xf := Transform3D(Basis(Vector3.RIGHT, 0.22), vent_pos)
			b.rbox(vent_xf, Vector3(0.040, 0.004, 0.055), 0.003, 1, CB.M_DARK, C_CARBON)
			for k in 2:
				bar(b, vent_pos + vent_xf.basis * Vector3(0.0, 0.003, -0.025 + 0.030 * k), Vector3(0.034, 0.002, 0.003), CB.M_DARK, C_DARKER)

		for k in 4:
			var lz: float = 0.360 + 0.085 * k
			var ly: float = 0.710 - 0.022 * k
			b.rbox(Transform3D(Basis(Vector3.RIGHT, 0.26), Vector3(0.0, ly, lz)), Vector3(0.120 - 0.014 * k, 0.005, 0.018), 0.003, 1, CB.M_DARK, C_CARBON)

		# 4. Full-Width Sharp Red LED Rear Light Blade & Recessed Black Fascia (Zero Z-fighting)
		var tail_y := 0.575
		var tail_z := 0.998
		var tb_len := 0.270
		# Recessed dark matte fascia plate covering rear center (front at 0.990, rear face at 1.006)
		b.rbox(Transform3D(Basis(), Vector3(0.0, tail_y - 0.03, tail_z)), Vector3(tb_len + 0.015, 0.065, 0.008), 0.005, 1, CB.M_DARK, C_DARKER)
		# Continuous red emissive LED blade (front at 1.003, rear face at 1.011 -> 5mm proud of fascia, 11mm proud of body)
		b.rbox(Transform3D(Basis(), Vector3(0.0, tail_y, tail_z + 0.009)), Vector3(tb_len, 0.008, 0.004), 0.003, 1, CB.M_TAILLAMP, C_TAILLAMP)

		var sp_path := PackedVector3Array([
			Vector3(-0.270, 0.665, 0.985),
			Vector3( 0.000, 0.680, 1.000),
			Vector3( 0.270, 0.665, 0.985)
		])
		b.tube(sp_path, 0.007, 6, CB.M_PAINT, Color(1, 1, 1), true, true)

		var diff_angle := -0.24
		var diff_c := Vector3(0.0, 0.315, 0.920)
		var diff_xf := Transform3D(Basis(Vector3.RIGHT, diff_angle), diff_c)
		b.rbox(diff_xf, Vector3(0.260, 0.008, 0.110), 0.006, 1, CB.M_DARK, C_CARBON)
		for x in [-0.17, -0.055, 0.055, 0.17]:
			b.rbox(diff_xf * Transform3D(Basis(), Vector3(x, -0.022, 0.0)), Vector3(0.004, 0.022, 0.100), 0.002, 1, CB.M_DARK, C_DARK)
		b.rbox(Transform3D(Basis(), Vector3(0.0, 0.275, 0.790)), Vector3(0.150, 0.008, 0.130), 0.006, 1, CB.M_ALLOY, C_ALLOY_DARK)

func _check_intersections(builder, label: String) -> void:
	print("--- %s ---" % label)
	var body = CB.new()
	builder.build_body(body)

	var lamp_tris := []
	var other_tris := []
	for i in range(0, body._i.size(), 3):
		var i0 = body._i[i]
		var i1 = body._i[i + 1]
		var i2 = body._i[i + 2]
		var m0 = int(round(body._uv2[i0].x))
		var v0 = body._v[i0]
		var v1 = body._v[i1]
		var v2 = body._v[i2]
		if m0 == CB.M_HEADLAMP or m0 == CB.M_TAILLAMP:
			lamp_tris.append([m0, v0, v1, v2])
		else:
			other_tris.append([m0, v0, v1, v2])

	var coplanar := 0
	var hl_coplanar := 0
	var tl_coplanar := 0
	for lt in lamp_tris:
		var n_l = (lt[2] - lt[1]).cross(lt[3] - lt[1]).normalized()
		var p_l = lt[1]
		var l_min = lt[1].min(lt[2]).min(lt[3])
		var l_max = lt[1].max(lt[2]).max(lt[3])
		for ot in other_tris:
			var o_min = ot[1].min(ot[2]).min(ot[3])
			var o_max = ot[1].max(ot[2]).max(ot[3])
			if l_min.x > o_max.x or l_max.x < o_min.x or \
			   l_min.y > o_max.y or l_max.y < o_min.y or \
			   l_min.z > o_max.z or l_max.z < o_min.z:
				continue
			var n_o = (ot[2] - ot[1]).cross(ot[3] - ot[1]).normalized()
			if absf(n_l.dot(n_o)) > 0.98 and absf(n_l.dot(ot[1] - p_l)) < 0.001:
				coplanar += 1
				if lt[0] == CB.M_HEADLAMP: hl_coplanar += 1
				if lt[0] == CB.M_TAILLAMP: tl_coplanar += 1

	print("  Lamp triangles: %d, other triangles: %d" % [lamp_tris.size(), other_tris.size()])
	print("  AABB-overlapping COPLANAR triangle pairs (Z-fighting!): %d (HL: %d, TL: %d)" % [coplanar, hl_coplanar, tl_coplanar])

func _init() -> void:
	_check_intersections(MirageBuilder.new(), "ORIGINAL MirageBuilder")
	_check_intersections(TestMirageBuilder.new(), "FIXED TestMirageBuilder")
	quit(0)
