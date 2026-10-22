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
	
	var file := FileAccess.open("res://scratch/fbx_ramp.obj", FileAccess.WRITE)
	file.store_line("# FBX ConcreteRamp exported at world scale")
	for i in range(mdt.get_vertex_count()):
		var v := mdt.get_vertex(i) * scale_factor
		file.store_line("v %f %f %f" % [v.x, v.y, v.z])
	for i in range(mdt.get_face_count()):
		file.store_line("f %d %d %d" % [
			mdt.get_face_vertex(i, 0) + 1,
			mdt.get_face_vertex(i, 1) + 1,
			mdt.get_face_vertex(i, 2) + 1
		])
	file.close()
	print("Exported scratch/fbx_ramp.obj with ", mdt.get_vertex_count(), " vertices and ", mdt.get_face_count(), " faces.")
	quit(0)
