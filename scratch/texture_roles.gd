extends SceneTree

# Writes, for every model in the given folders, which of its texture files its materials use and
# as what (albedo, normal, roughness, ...), as JSON for scratch/stream_textures.py. Headless:
#   Godot --headless --path . -s res://scratch/texture_roles.gd -- <out.json> res://models/plants ...

const ROLES := {
	"albedo_texture": "albedo", "normal_texture": "normal", "roughness_texture": "roughness",
	"metallic_texture": "metallic", "ao_texture": "ao", "emission_texture": "emission",
	"orm_texture": "orm", "detail_albedo": "albedo", "detail_normal": "normal",
}

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var roles := {}
	for dir in args.slice(1):
		for f in DirAccess.get_files_at(dir):
			if not (f.ends_with(".fbx") or f.ends_with(".glb")):
				continue
			var ps: PackedScene = load(dir.path_join(f))
			if ps == null:
				continue
			var root: Node = ps.instantiate()
			for mi in root.find_children("*", "MeshInstance3D", true, false):
				var mesh: Mesh = mi.mesh
				if mesh == null:
					continue
				for s in mesh.get_surface_count():
					var mat: Material = mi.get_surface_override_material(s)
					if mat == null:
						mat = mesh.surface_get_material(s)
					if not (mat is BaseMaterial3D):
						continue
					for prop in ROLES:
						var t = mat.get(prop)
						if t is Texture2D and not (t as Texture2D).resource_path.is_empty():
							var path: String = (t as Texture2D).resource_path
							var r: Array = roles.get(path, [])
							if not r.has(ROLES[prop]):
								r.append(ROLES[prop])
							roles[path] = r
			root.free()
	var fa := FileAccess.open(args[0], FileAccess.WRITE)
	fa.store_string(JSON.stringify(roles, "\t"))
	fa.close()
	print("roles for %d textures -> %s" % [roles.size(), args[0]])
	quit()
