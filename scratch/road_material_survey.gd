extends SceneTree

# Prints, per level, the material (albedo texture or shader) on each road-like mesh, to tell asphalt
# from dirt when classifying surfaces. Headless:
#   Godot --headless --path . -s res://scratch/road_material_survey.gd -- [res://levels/X.tscn ...]

func _init() -> void:
	var levels: Array = OS.get_cmdline_user_args()
	if levels.is_empty():
		for f in DirAccess.get_files_at("res://levels"):
			if f.ends_with(".tscn"):
				levels.append("res://levels/" + f)
	for path in levels:
		var root: Node = (load(path) as PackedScene).instantiate()
		print("== ", path.get_file())
		var seen := {}
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			var p := str(root.get_path_to(mi)).to_lower()
			if not (p.contains("road") or p.contains("track") or p.contains("deck") or p.contains("pier") or p.contains("curb") or p.contains("highway")):
				continue
			var key := p.rstrip("0123456789_")
			if seen.has(key):
				continue
			seen[key] = true
			var mat: Material = mi.material_override
			if mat == null and mi.mesh and mi.mesh.get_surface_count() > 0:
				mat = mi.mesh.surface_get_material(0)
			var desc := "none"
			if mat is ShaderMaterial:
				desc = "shader " + str((mat as ShaderMaterial).shader.resource_path.get_file() if (mat as ShaderMaterial).shader else "?")
				for prm in ["albedo_texture", "road_tex", "asphalt_tex", "tex", "albedo"]:
					var v = (mat as ShaderMaterial).get_shader_parameter(prm)
					if v is Texture2D:
						desc += " %s=%s" % [prm, v.resource_path.get_file()]
			elif mat is BaseMaterial3D:
				var t: Texture2D = (mat as BaseMaterial3D).albedo_texture
				desc = "std " + (t.resource_path.get_file() if t else str((mat as BaseMaterial3D).albedo_color))
			print("  %s : %s" % [str(root.get_path_to(mi)), desc])
		root.free()
	quit()
