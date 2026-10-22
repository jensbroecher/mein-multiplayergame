extends Node

func _ready() -> void:
	var scene := load("res://levels/LakesideLevel.tscn") as PackedScene
	var inst := scene.instantiate()
	var bridge := inst.get_node("LevelDesign/ConcreteFootbridge") as Node3D
	var t: Transform3D = bridge.transform
	
	var mi := bridge.get_child(0) as MeshInstance3D
	var arr_mesh: ArrayMesh = mi.mesh
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(arr_mesh, 0)
	
	# Scale factors:
	var sx: float = t.basis.x.length() * 100.0
	var sy: float = t.basis.y.length() * 100.0
	var sz: float = t.basis.z.length() * 100.0
	print("True local scale factors: sx=%.4f, sy=%.4f, sz=%.4f" % [sx, sy, sz])
	
	var file := FileAccess.open("res://scratch/fbx_footbridge_true.obj", FileAccess.WRITE)
	file.store_line("# FBX ConcreteFootbridge exported at true 1:1 local scale")
	for i in range(mdt.get_vertex_count()):
		var v := mdt.get_vertex(i)
		file.store_line("v %f %f %f" % [v.x * sx, v.y * sy, v.z * sz])
	for i in range(mdt.get_face_count()):
		file.store_line("f %d %d %d" % [
			mdt.get_face_vertex(i, 0) + 1,
			mdt.get_face_vertex(i, 1) + 1,
			mdt.get_face_vertex(i, 2) + 1
		])
	file.close()
	print("Saved scratch/fbx_footbridge_true.obj")
	get_tree().quit(0)
