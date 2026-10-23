extends SceneTree

func _init() -> void:
	print("--- Verifying LakesideLevel.tscn ---")
	var lvl: Node3D = (load("res://levels/LakesideLevel.tscn") as PackedScene).instantiate()
	
	# 1. Check Water_Surface
	var water := lvl.get_node_or_null("TerrainGenerator/Water_Surface") as MeshInstance3D
	if not water:
		printerr("FAIL: Water_Surface not found!")
	else:
		print("Water_Surface found:")
		print("  Position: ", water.position)
		if water.mesh is PlaneMesh:
			var pm = water.mesh as PlaneMesh
			print("  PlaneMesh size: ", pm.size)
			if pm.size.x >= 10000.0 and pm.size.y >= 10000.0:
				print("  -> Water surface successfully enlarged to 12000x12000!")
			else:
				printerr("  FAIL: PlaneMesh size is only ", pm.size)
		if water.material_override is ShaderMaterial:
			var sm = water.material_override as ShaderMaterial
			print("  Water edge fade enabled: ", sm.get_shader_parameter("enable_water_edge_fade"))
			print("  Water fade range: ", sm.get_shader_parameter("water_fade_start"), " -> ", sm.get_shader_parameter("water_fade_end"))
			print("  Water sky_tint: ", sm.get_shader_parameter("sky_tint"))

	# 2. Check WindTurbines under LakesideDressing
	var turbines_container := lvl.get_node_or_null("LakesideDressing/WindTurbines")
	if not turbines_container:
		printerr("FAIL: LakesideDressing/WindTurbines not found!")
	else:
		print("LakesideDressing/WindTurbines found with ", turbines_container.get_child_count(), " children:")
		for t in turbines_container.get_children():
			print("  * ", t.name, " at global_position ", t.global_position, " yaw=", t.rotation_degrees.y)
			var script = t.get_script()
			print("    script: ", script.resource_path if script else "NONE")
			print("    spin_speed: ", t.get("spin_speed"), " initial_angle: ", t.get("initial_angle"))
			var rotor = t.get_node_or_null("RotorPivot")
			if rotor:
				print("    RotorPivot found, rotor mesh: ", rotor.get_node("Rotor").mesh.resource_path)
			var tower = t.get_node_or_null("Tower")
			if tower:
				print("    Tower found, tower mesh: ", tower.mesh.resource_path)
			var nacelle = t.get_node_or_null("Nacelle")
			if nacelle:
				print("    Nacelle found, nacelle mesh: ", nacelle.mesh.resource_path)

	quit()
