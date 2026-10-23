@tool
extends SceneTree

func _init() -> void:
	print("--- INSPECTING TOWER, NACELLE, ROTOR MESHES ---")
	var tower: Mesh = load("res://generated/lakeside_turbine_tower.res")
	var nacelle: Mesh = load("res://generated/lakeside_turbine_nacelle.res")
	var rotor: Mesh = load("res://generated/lakeside_turbine_rotor.res")
	
	print("Tower surfaces:", tower.get_surface_count())
	print("Nacelle surfaces:", nacelle.get_surface_count())
	print("Rotor surfaces:", rotor.get_surface_count())
	
	# Check materials and flags
	for name_str in ["Tower", "Nacelle", "Rotor"]:
		var m: Mesh = tower if name_str == "Tower" else (nacelle if name_str == "Nacelle" else rotor)
		var mat = m.surface_get_material(0)
		if mat is StandardMaterial3D:
			print(name_str, " mat: cull_mode=", mat.cull_mode, " transparency=", mat.transparency, " depth_draw_mode=", mat.depth_draw_mode)
		else:
			print(name_str, " mat is: ", mat)
			
	quit()
