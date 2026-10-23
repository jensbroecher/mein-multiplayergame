extends SceneTree

const WindTurbineBuilder = preload("res://WindTurbineBuilder.gd")

func _init() -> void:
	print("--- Testing WindTurbineBuilder ---")
	var turbine = WindTurbineBuilder.build_turbine(45.0, 30.0, 0.0)
	print("Turbine built successfully!")
	print("Children: ")
	for c in turbine.get_children():
		print(" - ", c.name, " (", c.get_class(), ")")
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			var m = (c as MeshInstance3D).mesh
			print("    mesh faces: ", m.get_faces().size() / 3)
		if c.name == "RotorPivot":
			for rc in c.get_children():
				print("    * ", rc.name, " (", rc.get_class(), ")")
				if rc is MeshInstance3D and (rc as MeshInstance3D).mesh != null:
					var m = (rc as MeshInstance3D).mesh
					print("       rotor faces: ", m.get_faces().size() / 3)

	quit()
