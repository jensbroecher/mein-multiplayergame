@tool
extends SceneTree

func _init() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tip_apex := Vector3.UP * 21.0
	var r := 20.5
	var p0 := Vector3(0.5, r, 0)
	var p1 := Vector3(0, r, 0.5)
	
	# Test tip_apex, p0, p1 vs tip_apex, p1, p0
	st.add_vertex(tip_apex)
	st.add_vertex(p0)
	st.add_vertex(p1)
	
	var m := st.commit()
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(m, 0)
	var fn := mdt.get_face_normal(0)
	print("Blade tip normal: ", fn, " dot UP: ", fn.dot(Vector3.UP))
	quit()
