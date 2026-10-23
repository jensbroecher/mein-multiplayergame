@tool
extends SceneTree

func _init() -> void:
	# Check original rotor mesh
	var mesh: Mesh = load("res://generated/lakeside_turbine_rotor.res")
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(mesh, 0)
	print("Checking rotor mesh faces...")
	# Spinner was faces 0 to 287.
	# Blades start at face 288.
	print("Face 288 (blade root):")
	for f in [288, 289, 290, 291, 292, 293, 294, 295]:
		var v0 = mdt.get_vertex(mdt.get_face_vertex(f, 0))
		var v1 = mdt.get_vertex(mdt.get_face_vertex(f, 1))
		var v2 = mdt.get_vertex(mdt.get_face_vertex(f, 2))
		var geom_n = (v1 - v0).cross(v2 - v0).normalized()
		var center = (v0 + v1 + v2) / 3.0
		print("  Face ", f, " geom_n: ", geom_n, " center: ", center)
	quit()
