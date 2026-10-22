extends SceneTree

func _init() -> void:
	# Original transform from LakesideLevel:
	var t_orig := Transform3D(
		Vector3(17.037151, 0, -42.916008),
		Vector3(0, 34.0, 0),
		Vector3(27.108961, 0, 10.761939),
		Vector3(67.77796, 2.818687, -410.94803)
	)
	
	# Normalized transform:
	var t_norm := Transform3D(
		Vector3(0.368976, 0, -0.929439),
		Vector3(0, 1, 0),
		Vector3(0.929439, 0, 0.368976),
		Vector3(67.77796, 2.818687, -410.94803)
	)
	
	print("Normalized scale: ", t_norm.basis.get_scale())
	print("Normalized det: ", t_norm.basis.determinant())
	
	# Let's test a local point on the bridge, e.g. center of road clearance (0, 4.96, 0)
	var world_orig := t_orig * Vector3(0, 4.96 / 34.0, 0) # FBX scaled Y was 34
	var world_norm := t_norm * Vector3(0, 4.96, 0)
	print("Road clearance world pos (orig): ", world_orig)
	print("Road clearance world pos (norm): ", world_norm)
	print("Delta: ", (world_norm - world_orig).length())
	
	# Test leg end point:
	# Local point: (25.8, 0, 0)
	var end_orig := t_orig * Vector3(25.8 / 46.17411, 0, 0)
	var end_norm := t_norm * Vector3(25.8, 0, 0)
	print("Leg end world pos (orig): ", end_orig)
	print("Leg end world pos (norm): ", end_norm)
	print("Delta: ", (end_norm - end_orig).length())
	
	quit(0)
