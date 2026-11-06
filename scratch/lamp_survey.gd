extends SceneTree
## Which levels have lamps that give off no light: a StandardMaterial3D with emission on, operator MULTIPLY and no
## emission texture (its default is black, so it emits nothing: CampKit's and MatatuKit's "lamp"). Per level: the sun's
## elevation and energy (to tell night and dusk from day), how many surfaces use such a material, and in what files.
##   Godot --headless --path . -s res://scratch/lamp_survey.gd -- [res://levels/X.tscn ...]   (none: every level)

func _broken(m: Material) -> bool:
	var sm := m as StandardMaterial3D
	return sm != null and sm.emission_enabled and sm.emission_operator == BaseMaterial3D.EMISSION_OP_MULTIPLY and sm.emission_texture == null


func _init() -> void:
	var levels: Array = OS.get_cmdline_user_args()
	if levels.is_empty():
		for f in DirAccess.get_files_at("res://levels/"):
			if f.ends_with("Level.tscn"):
				levels.append("res://levels/" + f)
	for lp in levels:
		var ps := load(lp) as PackedScene
		if ps == null:
			continue
		var root := ps.instantiate()
		var sun := "no sun"
		var stack: Array = [root]
		var surfaces := 0
		var files := {}
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			for c in n.get_children():
				stack.append(c)
			if n is DirectionalLight3D and sun == "no sun":
				var dl := n as DirectionalLight3D
				var dir: Vector3 = -dl.global_transform.basis.z if dl.is_inside_tree() else -dl.transform.basis.z
				sun = "sun %s elev %.0f deg energy %.2f col %s" % [String(dl.name), rad_to_deg(asin(clampf(-dir.y, -1.0, 1.0))), dl.light_energy, dl.light_color.to_html(false)]
			var meshes: Array = []
			if n is MeshInstance3D and (n as MeshInstance3D).mesh:
				var mi := n as MeshInstance3D
				meshes.append(mi.mesh)
				if mi.material_override and _broken(mi.material_override):
					surfaces += 1
					files["override in " + lp] = true
			elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh and (n as MultiMeshInstance3D).multimesh.mesh:
				meshes.append((n as MultiMeshInstance3D).multimesh.mesh)
			for mesh in meshes:
				var m: Mesh = mesh
				for i in range(m.get_surface_count()):
					var mat := m.surface_get_material(i)
					if mat and _broken(mat):
						surfaces += 1
						var where: String = mat.resource_path if mat.resource_path != "" and not mat.resource_path.contains("::") else "in " + (m.resource_path if m.resource_path != "" else lp)
						files[where.get_slice("::", 0)] = true
		print("%-48s %-60s broken lamp surfaces %4d in %d files" % [lp.get_file(), sun, surfaces, files.size()])
		if OS.get_cmdline_user_args().size() > 0:
			for f in files:
				print("    ", f)
		root.free()
	quit()
