extends SceneTree
# -s headless: prints ImporterMesh's add_surface / generate_lods / get_mesh signatures on this Godot build
# (they changed between 4.x releases) and the size of materials/dirt.png.
func _initialize():
	for m in ClassDB.class_get_method_list("ImporterMesh"):
		if m.name in ["generate_lods", "add_surface", "get_mesh"]:
			print(m.name, " ", m.args.map(func(a): return a.name), " defaults=", m.default_args)
	var img = load("res://materials/dirt.png").get_image()
	print("dirt ", img.get_size())
	quit()
