@tool
extends SceneTree

func _init() -> void:
	print("--- VERIFYING WORLD ALIGNMENT IN LAKESIDE ---")
	
	# FBX transform:
	var t_fbx := Transform3D(
		Vector3(16.444656, 0, 11.383026),
		Vector3(0, 20, 0),
		Vector3(-11.383026, 0, 16.444656),
		Vector3(167.59178, 6.9242396, -80.37636)
	)
	
	# CSG transform (scale 1.0, exact same rotation and position):
	var t_csg := Transform3D(
		Vector3(0.8222328, 0, 0.5691513),
		Vector3(0, 1, 0),
		Vector3(-0.5691513, 0, 0.8222328),
		Vector3(167.59178, 6.9242396, -80.37636)
	)
	
	# Let's check the launch lip center:
	# In FBX: node_0 was scaled by 100, so local X was ~0.405 (scaled by 20 -> 8.10)
	# Local lip center in world:
	# FBX local vertex at lip center: Vector3(0.405, 0.406, 0.0) -> scaled by 20 = (8.10, 8.12, 0.0)
	var fbx_lip_world = t_fbx * Vector3(0.405, 0.406, 0.0)
	var csg_lip_world = t_csg * Vector3(8.10, 8.12, 0.0)
	print("FBX lip in world: ", fbx_lip_world)
	print("CSG lip in world: ", csg_lip_world)
	print("Distance between lips: ", fbx_lip_world.distance_to(csg_lip_world), " meters")
	
	# Let's check the entrance toe center:
	var fbx_toe_world = t_fbx * Vector3(-0.6184, 0.0, 0.0)
	var csg_toe_world = t_csg * Vector3(-12.37, 0.0, 0.0)
	print("FBX toe in world: ", fbx_toe_world)
	print("CSG toe in world: ", csg_toe_world)
	print("Distance between toes: ", fbx_toe_world.distance_to(csg_toe_world), " meters")

	quit(0)
