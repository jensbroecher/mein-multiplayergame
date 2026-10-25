extends SceneTree

# Lists the files in generated/ (and its subfolders) whose names start with a prefix that no scene in
# the project depends on, directly or through other resources (ResourceLoader.get_dependencies,
# followed recursively from every .tscn). Headless:
#   Godot --headless --path . -s res://scratch/unused_generated.gd -- canyon_ [canyonfar_ ...]

var _deps := {}

func _init() -> void:
	var prefixes: PackedStringArray = OS.get_cmdline_user_args()
	var scenes: Array = []
	_collect(scenes, "res://", ".tscn")
	for sc in scenes:
		_walk(sc)
	var files: Array = []
	_collect(files, "res://generated", "")
	for f in files:
		var name: String = String(f).get_file()
		var dir_name: String = String(f).get_base_dir().get_file()
		var match_prefix := false
		for p in prefixes:
			if name.begins_with(p) or dir_name.begins_with(p):
				match_prefix = true
		if match_prefix and not name.ends_with(".import") and not name.ends_with(".uid") and not _deps.has(f):
			print("UNUSED ", f)
	quit()


func _walk(path: String) -> void:
	if _deps.has(path):
		return
	_deps[path] = true
	for d in ResourceLoader.get_dependencies(path):
		# Entries look like "uid://...::Type::res://path" or a bare path.
		var p: String = d.get_slice("::", 2) if d.contains("::") else d
		if p.begins_with("uid://"):
			p = ResourceUID.get_id_path(ResourceUID.text_to_id(p))
		if p.begins_with("res://"):
			_walk(p)


func _collect(out: Array, dir: String, ext: String) -> void:
	for f in DirAccess.get_files_at(dir):
		if ext.is_empty() or f.ends_with(ext):
			out.append(dir.path_join(f))
	for sub in DirAccess.get_directories_at(dir):
		if sub.begins_with("."):
			continue
		_collect(out, dir.path_join(sub), ext)
