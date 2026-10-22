@tool
extends SceneTree

func _init() -> void:
	var scene: PackedScene = load("res://models/concrete/8203ec9089a546140a4fa6915ed558b1.fbx")
	var inst: Node = scene.instantiate()
	var mi := inst.get_child(0) as MeshInstance3D
	var arr_mesh: ArrayMesh = mi.mesh
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(arr_mesh, 0)
	
	# Scale of node_0 is 100
	# In LakesideLevel, scale is (32.01812, 34.0, 44.24481)
	# So world multiplier:
	# X: 100 * 32.01812 = 3201.812
	# Y: 100 * 34.0     = 3400.0
	# Z: 100 * 44.24481 = 4424.481
	
	# Let's export normalized at scale 100 (FBX scene units in meters):
	var file := FileAccess.open("res://scratch/fbx_footbridge.obj", FileAccess.WRITE)
	file.store_line("# FBX ConcreteFootbridge exported at 1:1 scale (Lakeside basis applied)")
	for i in range(mdt.get_vertex_count()):
		var v := mdt.get_vertex(i)
		# apply scale 100 on node_0, and Lakeside basis scale
		var wx := v.x * 3201.812
		var wy := v.y * 3400.0
		var wz := v.z * 4424.481
		file.store_line("v %f %f %f" % [wx, wy, wz])
	for i in range(mdt.get_face_count()):
		file.store_line("f %d %d %d" % [
			mdt.get_face_vertex(i, 0) + 1,
			mdt.get_face_vertex(i, 1) + 1,
			mdt.get_face_vertex(i, 2) + 1
		])
	file.close()
	print("Exported scratch/fbx_footbridge.obj with ", mdt.get_vertex_count(), " vertices and ", mdt.get_face_count(), " faces.")
	quit(0)
