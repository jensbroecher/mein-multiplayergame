extends SceneTree

const MirageBuilder = preload("res://MirageBuilder.gd")
const CB = preload("res://CarBuilder.gd")

func _init() -> void:
	var builder = MirageBuilder.new()
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

	print("=== MirageBuilder Lamp Z-fighting Audit ===")
	print("  Total lamp triangles: %d, other triangles: %d" % [lamp_tris.size(), other_tris.size()])
	print("  AABB-overlapping COPLANAR triangle pairs: %d (HL: %d, TL: %d)" % [coplanar, hl_coplanar, tl_coplanar])
	if coplanar == 0:
		print("  [SUCCESS] ZERO coplanar overlapping triangle pairs detected on Mirage lamps!")
	else:
		push_error("FAILED: Found %d coplanar overlapping triangle pairs!" % coplanar)

	quit(0 if coplanar == 0 else 1)
