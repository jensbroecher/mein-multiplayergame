extends SceneTree
## Saves MiyoshinoPropKit's props as .res files (life size, scale 1) for scratch/zfight_scan.gd. Windowed (on the dummy
## renderer a saved mesh can come out empty):
##   Godot --path . -s res://scratch/miyoshino_prop_dump.gd -- <out_dir>
##   Godot --headless --path . -s res://scratch/zfight_scan.gd -- <out_dir>/torii_0.res ... tol=0.004

const K = preload("res://MiyoshinoPropKit.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/miyoshino_dump"
	DirAccess.make_dir_recursive_absolute(out)
	var a := Vector3(-4, 0, 0)
	var b := Vector3(4, 0.5, 0)
	var jobs: Array = [
		["torii_0", func(pk, kit, rng, l): K.torii(pk, kit, 0)], ["torii_1", func(pk, kit, rng, l): K.torii(pk, kit, 1)],
		["torii_2", func(pk, kit, rng, l): K.torii(pk, kit, 2)], ["torii_grand", func(pk, kit, rng, l): K.torii(pk, kit, 0, 11.0, 7.5)],
		["stone_lantern_0", func(pk, kit, rng, l): K.stone_lantern(pk, kit, 0)], ["stone_lantern_1", func(pk, kit, rng, l): K.stone_lantern(pk, kit, 1)],
		["chochin", func(pk, kit, rng, l): K.chochin(pk, kit, Vector3(0, 2, 0))],
		["chochin_string", func(pk, kit, rng, l): K.chochin_string(pk, kit, Vector3(-3, 3, 0), Vector3(3, 3, 0), 6)],
		["bonbori", func(pk, kit, rng, l): K.bonbori(pk, kit)], ["wood_lantern_post", func(pk, kit, rng, l): K.wood_lantern_post(pk, kit)],
		["utility_pole_1", func(pk, kit, rng, l): K.utility_pole(pk, kit, 9.5, 1)], ["utility_pole_2", func(pk, kit, rng, l): K.utility_pole(pk, kit, 9.5, 2)],
		["guardrail", func(pk, kit, rng, l): K.guardrail(pk, kit, a, b)], ["curve_mirror", func(pk, kit, rng, l): K.curve_mirror(pk, kit, true)],
		["sign_rocks", func(pk, kit, rng, l): K.road_sign(pk, kit, "falling_rocks", l)], ["sign_slip", func(pk, kit, rng, l): K.road_sign(pk, kit, "slippery", l)],
		["sign_wind", func(pk, kit, rng, l): K.road_sign(pk, kit, "winding", l)], ["sign_40", func(pk, kit, rng, l): K.road_sign(pk, kit, "speed40", l)],
		["sign_stop", func(pk, kit, rng, l): K.road_sign(pk, kit, "stop", l)], ["sign_tourist", func(pk, kit, rng, l): K.road_sign(pk, kit, "tourist", l, "X")],
		["nobori", func(pk, kit, rng, l): K.nobori(pk, kit, K.VERMILION)],
		["jizo_row", func(pk, kit, rng, l): K.jizo_row(pk, kit, 5, rng)], ["komainu", func(pk, kit, rng, l): K.komainu(pk, kit)],
		["stone_marker", func(pk, kit, rng, l): K.stone_marker(pk, kit, 1.5, "A", l)], ["cairn", func(pk, kit, rng, l): K.cairn(pk, kit, rng)],
		["hokora", func(pk, kit, rng, l): K.hokora(pk, kit)], ["rope_ring", func(pk, kit, rng, l): K.rope_ring(pk, kit, 0.5, 1.5)],
		["koran", func(pk, kit, rng, l): K.koran(pk, kit, a, b)], ["chain_fence", func(pk, kit, rng, l): K.chain_fence(pk, kit, a, b)],
		["rope_fence", func(pk, kit, rng, l): K.rope_fence(pk, kit, a, b)], ["bamboo_fence", func(pk, kit, rng, l): K.bamboo_fence(pk, kit, a, b)],
		["hanami_0", func(pk, kit, rng, l): K.hanami_set(pk, kit, 0, rng)], ["hanami_1", func(pk, kit, rng, l): K.hanami_set(pk, kit, 1, rng)],
		["hanami_2", func(pk, kit, rng, l): K.hanami_set(pk, kit, 2, rng)], ["red_bench", func(pk, kit, rng, l): K.red_bench(pk, kit)],
		["sake_barrels", func(pk, kit, rng, l): K.sake_barrels(pk, kit, 2, 2)], ["vending", func(pk, kit, rng, l): K.vending_machine(pk, kit, 0)],
		["arched_bridge", func(pk, kit, rng, l): K.arched_bridge(pk, kit)], ["summit_shrine", func(pk, kit, rng, l): K.summit_shrine(pk, kit, l, "TOP")],
		["ema_rack", func(pk, kit, rng, l): K.ema_rack(pk, kit)], ["chozuya", func(pk, kit, rng, l): K.chozuya(pk, kit)],
		["stone_steps", func(pk, kit, rng, l): K.stone_steps(pk, kit, 2.0, 6)], ["kei_truck", func(pk, kit, rng, l): K.kei_truck(pk, kit)],
	]
	for j in jobs:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var pk = K.new_kit(1.0)
		var kit := {}
		var labels: Array = []
		(j[1] as Callable).call(pk, kit, rng, labels)
		var mesh: ArrayMesh = K.commit(pk, kit)
		ResourceSaver.save(mesh, out.path_join("%s.res" % j[0]))
	print("SAVED ", jobs.size(), " meshes to ", out)
	quit()
