extends SceneTree

func _init() -> void:
	var lvl = (load("res://levels/LakesideLevel.tscn") as PackedScene).instantiate()
	var path = lvl.get_node("TrackPath") as Path3D
	var curve = path.curve
	var tg = lvl.get_node("TerrainGenerator")
	var water = tg.get_node_or_null("Water_Surface")
	
	print("=== Lakeside Inspection ===")
	print("Track total length: ", curve.get_baked_length())
	if water:
		print("Water surface pos: ", water.position, " rot: ", water.rotation)
		print("Water mesh: ", water.mesh)
		if water.mesh is PlaneMesh:
			print("Water PlaneMesh size: ", (water.mesh as PlaneMesh).size)
		if water.material_override is ShaderMaterial:
			var sm = water.material_override as ShaderMaterial
			print("Water shader params:")
			for p in ["water_color", "shallow_color", "sky_tint", "enable_water_edge_fade", "water_fade_start", "water_fade_end"]:
				print("  ", p, " = ", sm.get_shader_parameter(p))

	print("\nSampling track around large bridge (s = 900 to 2100):")
	for s in range(800, 2200, 100):
		var p = curve.sample_baked(float(s))
		print("s = %4d: world pos = (%.1f, %.1f, %.1f)" % [s, p.x, p.y, p.z])

	quit()
