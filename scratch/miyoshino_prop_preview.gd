extends SceneTree
## Look-dev for the Miyoshino GP's prop kit (MiyoshinoPropKit.gd): builds a set of its props in memory on flat ground at
## the stages' PROP_SCALE (1.6) with stand-in people (2.9m) and an RC car (2.2m) for scale, prints each prop's triangles
## and life size, and saves a PNG per camera. Windowed:
##   Godot --path . --resolution 1400x850 -s res://scratch/miyoshino_prop_preview.gd -- <out_dir>
##       [set=shrine|lanterns|road|hanami|fences|nice|koi|all] [night=1] [each=1] [only=<name part>] [seed=N]
##       name:x,y,z:tx,ty,tz[:fov] ...
## Without cameras a set gets an overview; `each=1` adds a three-quarter close-up of every prop (`only=` just those whose
## name holds the text). `night=1` sets MiyoshinoKit.night before the first kit and renders under a dusk sky, so the
## "washi" glow can be judged. Props stand in a row along +x, their fronts toward +z.

const K = preload("res://MiyoshinoPropKit.gd")
const PS := 1.6

var _root: Node3D
var _assets: Array = []    # [name, MeshInstance3D, origin]
var _x := 0.0
var _night := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/miyoshino_props"
	DirAccess.make_dir_recursive_absolute(out)
	var which := "shrine"
	var each := false
	var only := ""
	var seed_v := 7
	var shots: Array = []
	for a in args.slice(1):
		if a.begins_with("set="):
			which = a.substr(4)
		elif a.begins_with("night="):
			_night = a.substr(6) == "1"
		elif a.begins_with("each="):
			each = a.substr(5) == "1"
		elif a.begins_with("only="):
			only = a.substr(5)
		elif a.begins_with("seed="):
			seed_v = int(a.substr(5))
		else:
			var parts := String(a).split(":")
			if parts.size() >= 3:
				var p := parts[1].split_floats(",")
				var t := parts[2].split_floats(",")
				shots.append([parts[0], Vector3(p[0], p[1], p[2]), Vector3(t[0], t[1], t[2]), float(parts[3]) if parts.size() > 3 else 50.0])
	K.night = _night
	_setup_world()
	for s in (["shrine", "lanterns", "road", "fences", "hanami", "nice"] if which == "all" else [which]):
		_build_set(s, seed_v)
	var total := 0
	for a in _assets:
		var mi: MeshInstance3D = a[1]
		var t := _tris(mi.mesh)
		total += t
		var bb: AABB = mi.mesh.get_aabb()
		var o: Vector3 = a[2]
		print("  %s: %d triangles, life size %s, from %s to %s" % [a[0], t, str((bb.size / PS).snapped(Vector3.ONE * 0.01)),
				str(((bb.position - o) / PS).snapped(Vector3.ONE * 0.01)), str(((bb.end - o) / PS).snapped(Vector3.ONE * 0.01))])
	print("triangles ", total)
	if shots.is_empty():
		shots.append([which, Vector3(_x * 0.5 - _x * 0.35, 5.0 + _x * 0.12, 10.0 + _x * 0.42), Vector3(_x * 0.5, 2.0, 0), 55.0])
	if each:
		for a in _assets:
			if only != "" and not String(a[0]).contains(only):
				continue
			var bb: AABB = (a[1] as MeshInstance3D).mesh.get_aabb()
			var c: Vector3 = bb.get_center()
			c.y = maxf(c.y, bb.end.y * 0.5)
			var r: float = maxf(Vector3(bb.size.x, bb.end.y, bb.size.z).length() * 0.5, 0.8)
			shots.append([a[0], c + Vector3(-0.5, 0.3, 1.0).normalized() * r * 2.5, c, 42.0])
	var cam := Camera3D.new()
	cam.far = 3000.0
	cam.near = 0.05
	_root.add_child(cam)
	cam.current = true
	for i in range(40):
		await process_frame
	for s in shots:
		cam.fov = s[3]
		cam.look_at_from_position(s[1], s[2])
		for i in range(6):
			await process_frame
		await RenderingServer.frame_post_draw
		var path: String = out.path_join("%s%s.png" % [s[0], "_night" if _night else ""])
		get_root().get_texture().get_image().save_png(path)
		print("SHOT ", path)
	quit()


func _build_set(which: String, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	match which:
		"rocks":
			for k in 6:
				var rr: float = [0.5, 0.7, 0.9, 1.2, 0.6, 1.5][k]
				_add("garden_rock_%d" % k, rr * 2.6 + 1.0, func(pk, kit, labels): K.garden_rock(pk, kit, rr, rr * 0.65, k * 13 + 5))
		"koi":
			_add("koinobori_pole", 16.0, func(pk, kit, labels): K.koinobori_pole(pk, kit, 9.0, 2, Vector3(0, 0, 1), rng))
			_add("koinobori_line", 30.0, func(pk, kit, labels): K.koinobori_line(pk, kit, Vector3(-8, 0, -2), Vector3(8, 0, -2), 7, Vector3(0, 0, 1), 1.3, rng, 8.0))
		"shrine":
			_add("torii_0", 9.0, func(pk, kit, labels): K.torii(pk, kit, 0))
			_add("torii_1", 9.0, func(pk, kit, labels): K.torii(pk, kit, 1))
			_add("torii_2", 9.0, func(pk, kit, labels): K.torii(pk, kit, 2))
			_add("torii_grand", 21.0, func(pk, kit, labels): K.torii(pk, kit, 0, 11.0, 7.5))
			_add("komainu", 3.0, func(pk, kit, labels): K.komainu(pk, kit, false))
			_add("komainu_m", 3.0, func(pk, kit, labels): K.komainu(pk, kit, true))
			_add("jizo_row", 5.5, func(pk, kit, labels): K.jizo_row(pk, kit, 6, rng))
			_add("stone_marker", 2.0, func(pk, kit, labels): K.stone_marker(pk, kit, 1.5, "YOSHINO", labels))
			_add("cairn", 2.5, func(pk, kit, labels): K.cairn(pk, kit, rng, 1.0))
			_add("hokora", 3.0, func(pk, kit, labels): K.hokora(pk, kit))
			_add("rope_ring", 3.0, func(pk, kit, labels):
				pk.tube(kit, "matte", Vector3(0, -0.5, 0), Vector3(0, 4.0, 0), 0.5, 0.45, 12, Color(0.3, 0.22, 0.16), false)
				K.rope_ring(pk, kit, 0.49, 1.5))
			_add("shimenawa", 6.0, func(pk, kit, labels):
				for sx in [-1.0, 1.0]:
					pk.tube(kit, "matte", Vector3(sx * 1.6, -0.5, 0), Vector3(sx * 1.6, 2.6, 0), 0.08, 0.08, 8, Color(0.3, 0.22, 0.16), true)
				K.shimenawa(pk, kit, Vector3(-1.6, 2.3, 0.09), Vector3(1.6, 2.3, 0.09)))
		"lanterns":
			_add("stone_lantern_0", 3.0, func(pk, kit, labels): K.stone_lantern(pk, kit, 0))
			_add("stone_lantern_1", 3.5, func(pk, kit, labels): K.stone_lantern(pk, kit, 1))
			_add("chochin", 2.5, func(pk, kit, labels):
				pk.tube(kit, "matte", Vector3(0, -0.5, -0.3), Vector3(0, 2.4, -0.3), 0.04, 0.04, 6, Color(0.2, 0.2, 0.2), true)
				pk.tube(kit, "matte", Vector3(0, 2.3, -0.3), Vector3(0, 2.3, 0.05), 0.02, 0.02, 4, Color(0.2, 0.2, 0.2), true)
				K.chochin(pk, kit, Vector3(0, 1.85, 0)))
			_add("chochin_string", 9.0, func(pk, kit, labels):
				for sx in [-1.0, 1.0]:
					pk.tube(kit, "matte", Vector3(sx * 3.5, -0.5, 0), Vector3(sx * 3.5, 3.6, 0), 0.05, 0.05, 6, Color(0.2, 0.2, 0.2), true)
				K.chochin_string(pk, kit, Vector3(-3.5, 3.5, 0), Vector3(3.5, 3.5, 0), 8))
			_add("bonbori", 2.5, func(pk, kit, labels): K.bonbori(pk, kit))
			_add("wood_lantern_post", 2.5, func(pk, kit, labels): K.wood_lantern_post(pk, kit))
			_add("vending_0", 2.6, func(pk, kit, labels): K.vending_machine(pk, kit, 0))
			_add("vending_1", 2.6, func(pk, kit, labels): K.vending_machine(pk, kit, 1))
			_add("vending_2", 2.6, func(pk, kit, labels): K.vending_machine(pk, kit, 2))
		"road":
			_add("utility_pole_0", 4.0, func(pk, kit, labels):
				K.utility_pole(pk, kit, 9.5, 0)
				K.pole_wires(pk, kit, Vector3(0, 9.5 - K.POLE_WIRE_HIGH, 0.16), Vector3(0, 9.5 - K.POLE_WIRE_HIGH, -14.0), 0.6, 3)
				K.pole_wires(pk, kit, Vector3(0, 9.5 - K.POLE_WIRE_LOW, 0.16), Vector3(0, 9.5 - K.POLE_WIRE_LOW, -14.0), 0.5, 2))
			_add("utility_pole_1", 4.0, func(pk, kit, labels): K.utility_pole(pk, kit, 9.5, 1))
			_add("utility_pole_2", 4.0, func(pk, kit, labels): K.utility_pole(pk, kit, 9.5, 2))
			_add("guardrail", 14.0, func(pk, kit, labels): K.guardrail(pk, kit, Vector3(-6, 0, 0), Vector3(6, 0.8, 0)))
			_add("curve_mirror", 3.0, func(pk, kit, labels): K.curve_mirror(pk, kit, false))
			_add("curve_mirror_twin", 3.5, func(pk, kit, labels): K.curve_mirror(pk, kit, true))
			for kind in ["curve_l", "curve_r", "winding", "falling_rocks", "slippery", "speed40", "stop"]:
				_add("sign_" + kind, 2.2, func(pk, kit, labels): K.road_sign(pk, kit, kind, labels))
			_add("sign_tourist", 3.5, func(pk, kit, labels): K.road_sign(pk, kit, "tourist", labels, "SENBON SAKURA"))
			_add("nobori_a", 2.2, func(pk, kit, labels): K.nobori(pk, kit, K.VERMILION))
			_add("nobori_b", 2.2, func(pk, kit, labels): K.nobori(pk, kit, K.INDIGO))
			_add("nobori_c", 2.2, func(pk, kit, labels): K.nobori(pk, kit, K.PAPER_PINK))
		"fences":
			_add("koran", 9.0, func(pk, kit, labels): K.koran(pk, kit, Vector3(-4, 0, 0), Vector3(4, 0.6, 0)))
			_add("chain_fence", 10.0, func(pk, kit, labels): K.chain_fence(pk, kit, Vector3(-4.5, 0, 0), Vector3(4.5, 0.5, 0)))
			_add("rope_fence", 9.0, func(pk, kit, labels): K.rope_fence(pk, kit, Vector3(-3.75, 0, 0), Vector3(3.75, 0, 0)))
			_add("bamboo_fence", 8.0, func(pk, kit, labels): K.bamboo_fence(pk, kit, Vector3(-3.6, 0, 0), Vector3(3.6, 0.3, 0)))
		"hanami":
			for v in range(3):
				_add("hanami_%d" % v, 7.5, func(pk, kit, labels): K.hanami_set(pk, kit, v, rng))
			_add("red_bench", 5.5, func(pk, kit, labels): K.red_bench(pk, kit, true))
			_add("sake_barrels", 5.5, func(pk, kit, labels): K.sake_barrels(pk, kit))
		"nice":
			var kk: Object = load("res://MiyoshinoPropKit.gd")
			var jobs: Array = [["arched_bridge", 22.0, []], ["summit_shrine", 10.0, ["L", "OMINE"]], ["ema_rack", 5.0, []], ["chozuya", 6.5, []],
					["stone_steps", 5.0, [2.0, 12]], ["kei_truck", 5.0, []]]
			for j in jobs:
				if not kk.has_method(j[0]):
					print("  (no ", j[0], ")")
					continue
				_add(j[0], j[1], func(pk, kit, labels):
					var argv: Array = [pk, kit]
					for v in j[2]:
						argv.append(labels if (v is String and v == "L") else v)
					kk.callv(j[0], argv))
	_people_row(Vector3(0, 0, 5.5), int(_x / 9.0) + 2, _x)
	_car(Vector3(4.0, 0, 8.0), 0.3)


## Builds one prop through `fn(pk, kit, labels)`, `width` (world) of the row to itself.
func _add(asset_name: String, width: float, fn: Callable) -> void:
	var at := Vector3(_x + width * 0.5, 0, 0)
	_x += width
	var pk = K.new_kit(PS)
	pk.set_frame(Transform3D(Basis().scaled(Vector3.ONE * PS), at))
	var kit := {}
	var labels: Array = []
	fn.call(pk, kit, labels)
	var mesh: ArrayMesh = K.commit(pk, kit)
	var mi := MeshInstance3D.new()
	mi.name = asset_name
	mi.mesh = mesh
	_root.add_child(mi)
	_assets.append([asset_name, mi, at])
	for l in labels:
		var lab := Label3D.new()
		lab.text = l[0]
		lab.font_size = 64
		var pixel: float = float(l[3]) * PS / 44.8
		if l.size() > 5 and float(l[5]) > 0.0:
			var tw: float = ThemeDB.fallback_font.get_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x
			if tw * pixel > float(l[5]) * PS:
				pixel = float(l[5]) * PS / maxf(tw, 1.0)
		lab.pixel_size = pixel
		lab.modulate = l[4]
		lab.double_sided = false
		var n: Vector3 = l[2]
		lab.transform = Transform3D(Basis.looking_at(-n, Vector3.UP), at + (l[1] as Vector3) * PS)
		_root.add_child(lab)


func _tris(mesh: Mesh) -> int:
	var t := 0
	for s in mesh.get_surface_count():
		var idx = mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
		if idx != null and (idx as PackedInt32Array).size() > 0:
			t += (idx as PackedInt32Array).size() / 3
		else:
			t += (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return t


func _people_row(at: Vector3, n: int, span: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.35, 0.7)
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.85, 0.66, 0.52)
	for i in range(n):
		var p: Vector3 = at + Vector3(span * float(i) / float(maxi(n - 1, 1)), 0, 0)
		var body := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.32
		cm.height = 2.45
		cm.material = mat
		body.mesh = cm
		body.position = p + Vector3(0, 1.22, 0)
		_root.add_child(body)
		var head := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.2
		sm.height = 0.42
		sm.material = hm
		head.mesh = sm
		head.position = p + Vector3(0, 2.68, 0)
		_root.add_child(head)


func _car(at: Vector3, yaw: float) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.1, 0.9, 2.2)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.12, 0.1)
	bm.material = m
	mi.mesh = bm
	mi.position = at + Vector3(0, 0.45, 0)
	mi.rotation.y = yaw
	_root.add_child(mi)


func _setup_world() -> void:
	_root = Node3D.new()
	get_root().add_child(_root)
	var gm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1600, 1600)
	gm.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.46, 0.50, 0.40)
	gmat.roughness = 1.0
	pm.material = gmat
	gm.position = Vector3(0, -0.02, 0)
	_root.add_child(gm)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	if _night:
		sm.sky_top_color = Color(0.05, 0.07, 0.16)
		sm.sky_horizon_color = Color(0.45, 0.28, 0.30)
		sm.ground_bottom_color = Color(0.04, 0.04, 0.05)
		sm.ground_horizon_color = Color(0.3, 0.2, 0.2)
		sm.energy_multiplier = 0.45
		env.glow_enabled = true
	else:
		sm.sky_top_color = Color(0.30, 0.52, 0.86)
		sm.sky_horizon_color = Color(0.78, 0.84, 0.90)
		sm.ground_bottom_color = Color(0.40, 0.42, 0.38)
		sm.ground_horizon_color = Color(0.70, 0.72, 0.70)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	_root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -35.0, 0.0) if not _night else Vector3(-12.0, -60.0, 0.0)
	sun.light_energy = 1.35 if not _night else 0.25
	sun.light_color = Color(1.0, 0.96, 0.88) if not _night else Color(1.0, 0.6, 0.45)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 300.0
	_root.add_child(sun)
