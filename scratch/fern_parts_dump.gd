extends SceneTree

# Lists a fern mesh's surfaces and how it splits into connected pieces (its fronds), for DressingColliders' fern
# shredding. Headless:
#   Godot --headless --path . -s res://scratch/fern_parts_dump.gd -- [res://generated/msitu_fern_0.res ...]

func _init() -> void:
	var paths: PackedStringArray = OS.get_cmdline_user_args()
	if paths.is_empty():
		paths = ["res://generated/msitu_fern_0.res", "res://generated/msitu_fern_1.res",
			"res://generated/msitu_fern_cover_0.res", "res://generated/msitu_fern_cover_1.res"]
	var FS = load("res://FernShreds.gd")
	for p in paths:
		var mesh: Mesh = load(p)
		print("%s: aabb %s, %d surfaces" % [p, str(mesh.get_aabb()), mesh.get_surface_count()])
		for si in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(si)
			var mat: Material = mesh.surface_get_material(si)
			print("  surface %d: %d verts, indexed %s, material %s" % [si, (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(),
				arr[Mesh.ARRAY_INDEX] != null, str(mat.resource_path if mat else "none")])
		if FS:
			var parts: Array = FS.split(mesh)
			var sizes := PackedStringArray()
			for part in parts:
				sizes.append("%d tris @%s" % [int(part["tris"]), str((part["centre"] as Vector3).snappedf(0.01))])
			print("  %d pieces: %s" % [parts.size(), ", ".join(sizes)])
	quit()
