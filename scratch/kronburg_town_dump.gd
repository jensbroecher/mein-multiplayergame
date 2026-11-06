extends SceneTree
## Saves KronburgTownKit's assets as .res files (life size, scale 1) for the mesh checkers, e.g. scratch/zfight_scan.gd:
##   Godot --path . -s res://scratch/kronburg_town_dump.gd -- <out_dir> [seed=11]
##   Godot --headless --path . -s res://scratch/zfight_scan.gd -- <out_dir>/house_v0.res ... tol=0.003
## Every house variant at three storeys, the church, town hall, fountain, gate, a terrace of two, the kiosk, the column,
## the street furniture and the castle ruin. Run it windowed: on the dummy renderer a saved mesh can come out empty.

const K = preload("res://KronburgTownKit.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/kronburg_dump"
	var seed_v := 11
	for a in args.slice(1):
		if a.begins_with("seed="):
			seed_v = int(a.substr(5))
	DirAccess.make_dir_recursive_absolute(out)
	var KK: Object = load("res://KronburgTownKit.gd")
	var jobs: Array = []
	for v in range(5):
		jobs.append(["house_v%d" % v, func(pk, kit, rng, labels): K.fachwerk_house(pk, kit, 7.5 if v != 4 else 11.0, 10.0, 3, v, rng, labels)])
	jobs.append(["church", func(pk, kit, rng, labels): KK.call("church", pk, kit, labels)])
	jobs.append(["rathaus", func(pk, kit, rng, labels): KK.call("rathaus", pk, kit, labels)])
	jobs.append(["fountain", func(pk, kit, rng, labels): KK.call("market_fountain", pk, kit)])
	jobs.append(["gate", func(pk, kit, rng, labels): KK.call("town_gate", pk, kit, labels)])
	jobs.append(["terrace", func(pk, kit, rng, labels): KK.call("brick_terrace", pk, kit, 2, 0, rng)])
	jobs.append(["trinkhalle", func(pk, kit, rng, labels): KK.call("trinkhalle", pk, kit, labels)])
	jobs.append(["litfass", func(pk, kit, rng, labels): KK.call("litfass", pk, kit)])
	jobs.append(["bus_stop", func(pk, kit, rng, labels): KK.call("bus_stop", pk, kit, labels)])
	jobs.append(["castle", func(pk, kit, rng, labels): KK.call("castle_ruin", pk, kit)])
	for j in jobs:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_v
		var pk = K.new_kit(1.0)
		var kit := {}
		var labels: Array = []
		(j[1] as Callable).call(pk, kit, rng, labels)
		var mesh: ArrayMesh = K.commit(pk, kit)
		var path: String = out.path_join("%s.res" % j[0])
		ResourceSaver.save(mesh, path)
		print("SAVED ", path, " ", mesh.get_aabb())
	quit()
