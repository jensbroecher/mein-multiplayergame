extends SceneTree
## Saves NiederrheinKit's pieces as .res files (life size, scale 1) for the mesh checkers, e.g. scratch/zfight_scan.gd:
##   Godot --path . -s res://scratch/niederrhein_dump.gd -- <out_dir>
##   Godot --headless --path . -s res://scratch/zfight_scan.gd -- <out_dir>/windmill.res ... tol=0.003
## Run it windowed: on the dummy renderer a saved mesh can come out empty. Prints each piece's triangles.

const N = preload("res://NiederrheinKit.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/niederrhein_dump"
	DirAccess.make_dir_recursive_absolute(out)
	var jobs: Array = [
		["windmill", func(pk, kit, rng, labels): N.tower_windmill(pk, kit, labels)],
		["sails", func(pk, kit, rng, labels): N.windmill_sails(pk, kit)],
		["farmhouse", func(pk, kit, rng, labels): N.farmhouse(pk, kit, labels, 0)],
		["barn", func(pk, kit, rng, labels): N.farmhouse(pk, kit, labels, 1)],
		["cart_shed", func(pk, kit, rng, labels): N.farmhouse(pk, kit, labels, 2)],
		["shepherd_cart", func(pk, kit, rng, labels): N.shepherd_cart(pk, kit, labels)],
		["bales", func(pk, kit, rng, labels): N.silage_bales(pk, kit, rng, 6)],
		["fence", func(pk, kit, rng, labels): N.paddock_fence(pk, kit, PackedVector3Array([Vector3(0, 0, 0), Vector3(10, 0, 0), Vector3(14, 0, 5)]))],
		["gate", func(pk, kit, rng, labels): N.field_gate(pk, kit)],
		["tractor", func(pk, kit, rng, labels): N.tractor(pk, kit, 0)],
		["hay_wagon", func(pk, kit, rng, labels): N.hay_wagon(pk, kit)],
		["power_station", func(pk, kit, rng, labels): N.power_station(pk, kit, labels)],
	]
	for j in jobs:
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var pk = N.new_kit(1.0)
		var kit := {}
		var labels: Array = []
		(j[1] as Callable).call(pk, kit, rng, labels)
		var mesh: ArrayMesh = N.commit(pk, kit)
		var path: String = out.path_join("%s.res" % j[0])
		ResourceSaver.save(mesh, path)
		var t := 0
		for k in mesh.get_surface_count():
			var idx = mesh.surface_get_arrays(k)[Mesh.ARRAY_INDEX]
			t += (idx as PackedInt32Array).size() / 3 if idx != null else (mesh.surface_get_arrays(k)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		print("%s: %d triangles, %d surfaces -> %s" % [j[0], t, mesh.get_surface_count(), path])
	quit()
