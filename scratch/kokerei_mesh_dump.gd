extends SceneTree
## Builds KokereiKit's pieces at life size (scale 1), prints their triangles and saves them as .res meshes into <dir>, for
## scratch/zfight_scan.gd:
##   Godot --headless --path . -s res://scratch/kokerei_mesh_dump.gd -- <dir> [only=battery,pusher,...] [ovens=50]
const KokereiKit = preload("res://KokereiKit.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else "/tmp/kokerei_dump"
	var only: Array = []
	var ovens := 50
	for a in args.slice(1):
		if a.begins_with("only="):
			only = Array(a.substr(5).split(","))
		elif a.begins_with("ovens="):
			ovens = int(a.substr(6))
	DirAccess.make_dir_recursive_absolute(dir)
	var builds := {
		"battery": func(pk, kit, l): KokereiKit.coke_battery(pk, kit, l, ovens, 3, 3, 30),
		"pusher": func(pk, kit, _l): KokereiKit.pusher_machine(pk, kit, true),
		"guide": func(pk, kit, _l): KokereiKit.coke_guide_car(pk, kit, true, true),
		"quench_car": func(pk, kit, _l): KokereiKit.quench_car(pk, kit, 1),
		"larry": func(pk, kit, _l): KokereiKit.larry_car(pk, kit),
		"coal_tower": func(pk, kit, l): KokereiKit.coal_tower(pk, kit, l),
		"quench_tower": func(pk, kit, l): KokereiKit.quench_tower(pk, kit, l),
		"wharf": func(pk, kit, _l): KokereiKit.coke_wharf(pk, kit, 60.0),
		"byproduct": func(pk, kit, l): KokereiKit.byproduct_plant(pk, kit, l),
		"rails": func(pk, kit, _l): KokereiKit.kokerei_rails(pk, kit, 100.0),
		"flare": func(pk, kit, _l): KokereiKit.gas_flare(pk, kit),
	}
	for k in builds:
		if not only.is_empty() and not only.has(k):
			continue
		var pk = KokereiKit.new_kit(1.0)
		var kit := {}
		var labels: Array = []
		(builds[k] as Callable).call(pk, kit, labels)
		var mesh: ArrayMesh = KokereiKit.commit(pk, kit)
		var t := 0
		var per: Array = []
		for s in mesh.get_surface_count():
			var n: int = (mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			t += n
			per.append("%s %d" % [mesh.surface_get_name(s), n])
		ResourceSaver.save(mesh, "%s/%s.res" % [dir, k])
		print("%s: %d triangles, aabb %s, %d labels  [%s]" % [k, t, mesh.get_aabb(), labels.size(), ", ".join(per)])
	quit()
