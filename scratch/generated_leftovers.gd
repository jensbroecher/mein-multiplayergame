extends SceneTree
## Lists files under res://generated/ starting with a prefix that one level no longer depends on (directly or through
## the resources it loads): what its generator left behind from earlier runs. Prints them; deletes nothing.
## (scratch/unused_generated.gd does the same for every scene in the project.)
##   Godot --headless --path . -s res://scratch/generated_leftovers.gd -- res://levels/X.tscn <prefix> [<dir> ...]
## e.g. -- res://levels/MarinaNightsLevel.tscn marina_nights_ res://generated/ res://generated/marina_nights_chunks/

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var level: String = args[0]
	var prefix: String = args[1]
	var dirs: Array = args.slice(2) if args.size() > 2 else ["res://generated/"]
	var seen := {}
	var stack: Array = [level]
	while not stack.is_empty():
		var p: String = stack.pop_back()
		if seen.has(p):
			continue
		seen[p] = true
		for dep in ResourceLoader.get_dependencies(p):
			# "uid://...::::res://path" or a plain path.
			var path: String = dep.get_slice("::", 2) if dep.contains("::") else dep
			if path == "":
				path = dep
			if path.begins_with("uid://"):
				var id := ResourceUID.text_to_id(path)
				if ResourceUID.has_id(id):
					path = ResourceUID.get_id_path(id)
			if path.begins_with("res://") and not seen.has(path):
				stack.append(path)
	var unused := 0
	for dir in dirs:
		var da := DirAccess.open(dir)
		if da == null:
			continue
		for f in da.get_files():
			if not f.begins_with(prefix) or f.ends_with(".import"):
				continue
			var full: String = dir.path_join(f)
			if not seen.has(full):
				print("UNUSED ", full)
				unused += 1
	print("dependencies: ", seen.size(), "  unused: ", unused)
	quit()
