extends SceneTree

func _init() -> void:
	var CB = load("res://CarBuilder.gd")
	var b = CB.new()
	var builder = load("res://ZephyrBuilder.gd").new()
	builder.build_body(b)

	print("Total vertices: ", b.vertex_count(), " indices: ", b.index_count())

	# Check liner normals: vertices with M_DARK and y around 0.4..0.6 and x around 0.4..0.6
	var f_liner_up := 0
	var f_liner_down := 0
	for k in b.vertex_count():
		var p = b._v[k]
		var n = b._n[k]
		var m = int(b._uv2[k].x)
		if m == CB.M_DARK and p.x > 0.35 and p.z < -0.45 and p.z > -0.85:
			if n.y > 0.0:
				f_liner_up += 1
			else:
				f_liner_down += 1
	print("Front wheel liner normals: up=%d, down=%d" % [f_liner_up, f_liner_down])
	quit()
