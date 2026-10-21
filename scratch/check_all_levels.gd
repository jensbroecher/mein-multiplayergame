extends SceneTree

func _init():
	var dir = DirAccess.open("res://levels")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tscn"):
				var path = "res://levels/" + file_name
				var scn = load(path)
				if scn:
					var inst = scn.instantiate()
					var in_group = inst.is_in_group("level")
					print(file_name, ": name='", inst.name, "', in_group('level')=", in_group)
					inst.free()
			file_name = dir.get_next()
	quit()
