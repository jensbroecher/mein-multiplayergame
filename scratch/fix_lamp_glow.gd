extends SceneTree
## Makes a saved level's dead lamps glow (LampGlow.gd) without regenerating it: a dead lamp material saved as a file of
## its own is replaced by lamp_glow (same path), and a mesh file that holds one embedded gets lamp_glow in those surfaces
## and is saved again. Materials embedded in the level's .tscn itself are only reported.
##   Godot --headless --path . -s res://scratch/fix_lamp_glow.gd -- res://levels/X.tscn ... [energy=2.4] [dry=1]
const LampGlow = preload("res://LampGlow.gd")

func _init() -> void:
	var energy := 2.4
	var dry := false
	var levels: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("energy="):
			energy = float(a.substr(7))
		elif a == "dry=1":
			dry = true
		else:
			levels.append(a)
	for lp in levels:
		var root := (load(lp) as PackedScene).instantiate()
		var mat_files := {}
		var mesh_files := {}
		var in_scene := 0
		var stack: Array = [root]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			for c in n.get_children():
				stack.append(c)
			var meshes: Array = []
			if n is MeshInstance3D and (n as MeshInstance3D).mesh:
				meshes.append((n as MeshInstance3D).mesh)
				if LampGlow.is_dead((n as MeshInstance3D).material_override):
					in_scene += 1
			elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh and (n as MultiMeshInstance3D).multimesh.mesh:
				meshes.append((n as MultiMeshInstance3D).multimesh.mesh)
			for mesh in meshes:
				var m: Mesh = mesh
				for i in range(m.get_surface_count()):
					var mat := m.surface_get_material(i)
					if not LampGlow.is_dead(mat):
						continue
					if mat.resource_path != "" and not mat.resource_path.contains("::"):
						mat_files[mat.resource_path] = true
					elif m.resource_path != "" and not m.resource_path.contains("::"):
						mesh_files[m.resource_path] = m
					else:
						in_scene += 1
		root.free()
		print("%s: %d material files, %d mesh files, %d in the scene itself" % [lp.get_file(), mat_files.size(), mesh_files.size(), in_scene])
		for path in mat_files:
			print("  material ", path)
			if not dry:
				var uid := ResourceLoader.get_resource_uid(path)
				var glow := LampGlow.material(energy)
				var err := ResourceSaver.save(glow, path)
				if uid != ResourceUID.INVALID_ID:
					ResourceSaver.set_uid(path, uid)
				print("    saved: ", err)
		for path in mesh_files:
			var mesh: Mesh = load(path)
			var glow2 := LampGlow.material(energy)
			var n := LampGlow.fix_mesh(mesh, glow2)
			print("  mesh %s: %d surfaces" % [path, n])
			if not dry and n > 0:
				print("    saved: ", ResourceSaver.save(mesh, path))
	quit()
