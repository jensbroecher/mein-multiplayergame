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
	
	print("--- POINTS AT X > 7.0 and Y < 2.0 ---")
	for i in range(mdt.get_vertex_count()):
		var v := mdt.get_vertex(i) * scale_factor
		var n := mdt.get_vertex_normal(i)
		if v.x > 7.0 and v.y < 2.0:
			print("v: ", v, " n: ", n)

	print("\n--- POINTS AT X > 8.0 ---")
	for i in range(mdt.get_vertex_count()):
		var v := mdt.get_vertex(i) * scale_factor
		var n := mdt.get_vertex_normal(i)
		if v.x > 8.0:
			print("v: ", v, " n: ", n)
			
	quit(0)
