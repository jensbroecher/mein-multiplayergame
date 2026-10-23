@tool
extends SceneTree

func _init() -> void:
	var script = load("res://scratch/test_complete_builder.gd")
	var rotor: Mesh = script.build_rotor()
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(rotor, 0)
	print("Checking rotor faces: total = ", mdt.get_face_count())
	# Spinner faces:
	# disc = 24
	# 4 steps * 24 segs * 2 = 192 faces
	# tip fan = 24
	# Total spinner faces = 240
	var spinner_bad = 0
	for f in range(240):
		var v0 := mdt.get_vertex(mdt.get_face_vertex(f, 0))
		var v1 := mdt.get_vertex(mdt.get_face_vertex(f, 1))
		var v2 := mdt.get_vertex(mdt.get_face_vertex(f, 2))
		var geom_n := (v1 - v0).cross(v2 - v0).normalized()
		var vert_n := (mdt.get_vertex_normal(mdt.get_face_vertex(f, 0)) +
					  mdt.get_vertex_normal(mdt.get_face_vertex(f, 1)) +
					  mdt.get_vertex_normal(mdt.get_face_vertex(f, 2))) / 3.0
		vert_n = vert_n.normalized()
		if geom_n.dot(vert_n) < 0.2:
			spinner_bad += 1
	print("Spinner bad faces: ", spinner_bad, " / 240")
	
	var blade_bad = 0
	for f in range(240, mdt.get_face_count()):
		var v0 := mdt.get_vertex(mdt.get_face_vertex(f, 0))
		var v1 := mdt.get_vertex(mdt.get_face_vertex(f, 1))
		var v2 := mdt.get_vertex(mdt.get_face_vertex(f, 2))
		var geom_n := (v1 - v0).cross(v2 - v0).normalized()
		var vert_n := (mdt.get_vertex_normal(mdt.get_face_vertex(f, 0)) +
					  mdt.get_vertex_normal(mdt.get_face_vertex(f, 1)) +
					  mdt.get_vertex_normal(mdt.get_face_vertex(f, 2))) / 3.0
		vert_n = vert_n.normalized()
		if geom_n.dot(vert_n) < 0.2:
			blade_bad += 1
	print("Blade bad faces: ", blade_bad, " / ", mdt.get_face_count() - 240)
	quit()
