extends SceneTree
## Saves RheinStadtKit's assets as .res files (life size, scale 1) for the mesh checkers, e.g. scratch/zfight_scan.gd:
##   Godot --path . -s res://scratch/rhein_stadt_dump.gd -- <out_dir> [seed=7] [only=house,hotel,...]
##   Godot --headless --path . -s res://scratch/zfight_scan.gd -- <out_dir>/house_v0.res ... tol=0.003
## Every Gründerzeit variant (and its far stand-in), the corner house, the hotel, the steps, the quay wall, the pavilion,
## the kiosks, the street furniture, the wheel's base, rotor and a gondola, the chain swing's base, rotor and chair, the
## bumper cars, every stall, the beer tent, bunting and the fence. Run it windowed: on the dummy renderer a saved mesh can
## come out empty.

const K = preload("res://RheinStadtKit.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/rhein_dump"
	var seed_v := 7
	var only: PackedStringArray = []
	for a in args.slice(1):
		if a.begins_with("seed="):
			seed_v = int(a.substr(5))
		elif a.begins_with("only="):
			only = a.substr(5).split(",")
	DirAccess.make_dir_recursive_absolute(out)
	var jobs: Array = []
	for v in range(4):
		jobs.append(["house_v%d" % v, func(pk, kit, rng, labels): K.gruenderzeit_house(pk, kit, labels, 14.0, 5, v, rng, 13.0, 12)])
		jobs.append(["house_far_v%d" % v, func(pk, kit, rng, labels): K.gruenderzeit_house_far(pk, kit, 14.0, 5, v, rng, 13.0)])
	jobs.append(["corner", func(pk, kit, rng, labels): K.corner_house(pk, kit, labels, 18.0, 16.0, 5, rng)])
	jobs.append(["hotel", func(pk, kit, rng, labels): K.hotel(pk, kit, labels)])
	jobs.append(["steps", func(pk, kit, rng, labels): K.rhine_steps(pk, kit, 20.0, 4.0, 9.0)])
	jobs.append(["quay", func(pk, kit, rng, labels): K.quay_wall(pk, kit, 30.0, 4.0, labels, true)])
	jobs.append(["pavilion", func(pk, kit, rng, labels): K.pavilion_cafe(pk, kit, labels)])
	for kind in ["eis", "getraenke", "fahrrad"]:
		jobs.append(["kiosk_" + kind, func(pk, kit, rng, labels): K.kiosk(pk, kit, labels, kind)])
	jobs.append(["lamp", func(pk, kit, rng, labels): K.promenade_lamp(pk, kit)])
	jobs.append(["tree_guard", func(pk, kit, rng, labels): K.plane_tree_guard(pk, kit)])
	jobs.append(["bench", func(pk, kit, rng, labels): K.bench(pk, kit)])
	jobs.append(["bin", func(pk, kit, rng, labels): K.bin(pk, kit)])
	jobs.append(["wheel_base", func(pk, kit, rng, labels): K.ferris_wheel_base(pk, kit, labels)])
	jobs.append(["wheel_rotor", func(pk, kit, rng, labels): K.ferris_wheel_rotor(pk, kit)])
	jobs.append(["wheel_gondola", func(pk, kit, rng, labels): K.ferris_wheel_gondola(pk, kit, 0)])
	jobs.append(["swing_base", func(pk, kit, rng, labels): K.chair_swing_base(pk, kit, labels)])
	jobs.append(["swing_rotor", func(pk, kit, rng, labels): K.chair_swing_rotor(pk, kit)])
	jobs.append(["swing_chair", func(pk, kit, rng, labels): K.chair_swing_chair(pk, kit)])
	jobs.append(["bumper_cars", func(pk, kit, rng, labels): K.bumper_cars(pk, kit, labels)])
	for kind2 in ["bratwurst", "mandeln", "lebkuchen", "lose", "schiess", "crepes", "getraenke"]:
		jobs.append(["stall_" + kind2, func(pk, kit, rng, labels): K.stall(pk, kit, labels, kind2)])
	jobs.append(["beer_tent", func(pk, kit, rng, labels): K.beer_tent(pk, kit, labels)])
	jobs.append(["bunting", func(pk, kit, rng, labels): K.bunting(pk, kit, Vector3(0, 4, 0), Vector3(20, 4, 0), 0.6)])
	jobs.append(["fence", func(pk, kit, rng, labels): K.kirmes_fence(pk, kit, 20.0, labels)])
	for j in jobs:
		if not only.is_empty():
			var hit := false
			for o in only:
				if String(j[0]).begins_with(o):
					hit = true
			if not hit:
				continue
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_v
		var pk = K.new_kit(1.0)
		var kit := {}
		var labels: Array = []
		(j[1] as Callable).call(pk, kit, rng, labels)
		var mesh: ArrayMesh = K.commit(pk, kit)
		var path: String = out.path_join("%s.res" % j[0])
		ResourceSaver.save(mesh, path)
		print("SAVED ", path, " ", mesh.get_surface_count(), " surfaces")
	quit()
