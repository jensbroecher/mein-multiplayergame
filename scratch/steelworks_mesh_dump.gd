extends SceneTree
## Saves SteelworksKit's pieces at life size (scale 1) as .res meshes into <dir>, for scratch/zfight_scan.gd:
##   Godot --headless --path . -s res://scratch/steelworks_mesh_dump.gd -- <dir> [only=hall,furnace,...]
const SteelworksKit = preload("res://SteelworksKit.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0]
	var only: Array = []
	for a in args.slice(1):
		if a.begins_with("only="):
			only = Array(a.substr(5).split(","))
	DirAccess.make_dir_recursive_absolute(dir)
	var builds := {
		"hall": func(pk, kit, l): SteelworksKit.rolling_hall(pk, kit, 150.0, l),
		"furnace": func(pk, kit, l): SteelworksKit.blast_furnace(pk, kit, l),
		"cowpers": func(pk, kit, _l): SteelworksKit.cowpers(pk, kit, 4),
		"gasometer": func(pk, kit, l): SteelworksKit.gasometer(pk, kit, l),
		"chimney0": func(pk, kit, _l): SteelworksKit.chimney(pk, kit, 70.0, 0),
		"chimney1": func(pk, kit, _l): SteelworksKit.chimney(pk, kit, 60.0, 1),
		"cooling": func(pk, kit, _l): SteelworksKit.cooling_tower(pk, kit),
		"pipebridge": func(pk, kit, _l): SteelworksKit.pipe_bridge(pk, kit, 20.0, 11.0, 4),
		"headframe": func(pk, kit, l): SteelworksKit.headframe(pk, kit, l),
		"torpedo": func(pk, kit, _l): SteelworksKit.torpedo_car(pk, kit),
		"gate": func(pk, kit, l): SteelworksKit.works_gate(pk, kit, l),
		"crown": func(pk, kit, _l): SteelworksKit.steel_crown(pk, kit),
		"orecrane": func(pk, kit, _l): SteelworksKit.ore_crane(pk, kit),
		"barge": func(pk, kit, l): SteelworksKit.barge(pk, kit, 85.0, l),
		"stockpile": func(pk, kit, _l): SteelworksKit.stockpile(pk, kit),
	}
	for k in builds:
		if not only.is_empty() and not only.has(k):
			continue
		var pk = SteelworksKit.new_kit(1.0)
		var kit := {}
		(builds[k] as Callable).call(pk, kit, [])
		var mesh: ArrayMesh = SteelworksKit.commit(pk, kit)
		var t := 0
		for s in mesh.get_surface_count():
			t += (mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		ResourceSaver.save(mesh, "%s/%s.res" % [dir, k])
		print("%s: %d triangles" % [k, t])
	quit()
