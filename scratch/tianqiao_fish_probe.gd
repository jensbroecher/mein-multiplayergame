extends SceneTree
# Prints Tianqiao's fish MultiMeshes: instance count, the first instance's place and custom data, the mesh's size.
func _init() -> void:
	for n in ["small", "blue", "ray", "whaleshark"]:
		var mm: MultiMesh = load("res://generated/tianqiaofish_fish_%s.res" % n)
		print(n, " count=", mm.instance_count, " custom=", mm.use_custom_data, " colors=", mm.use_colors,
			" mesh=", mm.mesh, " aabb=", mm.mesh.get_aabb() if mm.mesh else null)
		if mm.instance_count > 0:
			print("  t0=", mm.get_instance_transform(0).origin, " c0=", mm.get_instance_custom_data(0), " buf=", mm.buffer.size())
	quit()
