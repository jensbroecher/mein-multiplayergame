extends SceneTree
## Look-dev for the Miyoshino GP's building kit (MiyoshinoTownKit.gd): builds a set of its buildings in memory on flat
## ground at the stages' PROP_SCALE (1.6) with stand-in people (2.9m) and an RC car (2.2m), prints each asset's triangles
## and size and saves a PNG per camera. Windowed:
##   Godot --path . --resolution 1400x850 -s res://scratch/miyoshino_town_preview.gd -- <out_dir>
##       [set=houses|gate|hall|pagoda|misc|nice|all] [seed=N] [sheet=1] [night=1] [dump=<dir>] name:x,y,z:tx,ty,tz[:fov] ...
## `sheet=1` (houses) lays every machiya out as one contact sheet; `night=1` sets MiyoshinoKit.night before the first kit
## and renders under a dusk sky, so the washi's glow can be judged; `dump=<dir>` also saves each asset at scale 1 as
## <dir>/<name>.res for scratch/zfight_scan.gd and scratch/miyoshino_town_check.gd.

const PS := 1.6
var KK: Object = null
var _root: Node3D
var _assets: Array = []    # [name, MeshInstance3D, origin]
var _night := false
var _dump := ""


func _init() -> void:
	KK = load("res://MiyoshinoTownKit.gd")
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/miyoshino_preview"
	DirAccess.make_dir_recursive_absolute(out)
	var which := "houses"
	var seed_v := 11
	var sheet := false
	var shots: Array = []
	for a in args.slice(1):
		if a.begins_with("set="):
			which = a.substr(4)
		elif a.begins_with("seed="):
			seed_v = int(a.substr(5))
		elif a.begins_with("sheet="):
			sheet = a.substr(6) == "1"
		elif a.begins_with("night="):
			_night = a.substr(6) == "1"
		elif a.begins_with("dump="):
			_dump = a.substr(5)
			DirAccess.make_dir_recursive_absolute(_dump)
		else:
			var parts := String(a).split(":")
			if parts.size() >= 3:
				var p := parts[1].split_floats(",")
				var t := parts[2].split_floats(",")
				shots.append([parts[0], Vector3(p[0], p[1], p[2]), Vector3(t[0], t[1], t[2]), float(parts[3]) if parts.size() > 3 else 50.0])
	load("res://MiyoshinoKit.gd").set("night", _night)
	_setup_world()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var defaults: Array = []
	match which:
		"gate":
			_build("gate", Vector3.ZERO, func(pk, kit, labels): KK.call("great_gate", pk, kit, labels))
			_people_row(Vector3(-4, 0, 9), 3, 1.3)
			_car(Vector3(1.5, 0, 12), 0.1)
			defaults = [["gate", Vector3(-24, 9, 44), Vector3(0, 13, 0), 50.0], ["gate_road", Vector3(0, 2.5, 34), Vector3(0, 11, 0), 60.0],
					["gate_through", Vector3(1, 3, 13), Vector3(0, 11, -6), 75.0], ["gate_side", Vector3(40, 14, 4), Vector3(0, 13, 0), 50.0],
					["gate_back", Vector3(22, 22, -40), Vector3(0, 12, 0), 50.0], ["gate_nio", Vector3(-3, 4, 16), Vector3(-10, 5, 3), 55.0]]
		"hall":
			_build("hall", Vector3.ZERO, func(pk, kit, labels): KK.call("main_hall", pk, kit, labels))
			_people_row(Vector3(-8, 0, 9), 4, 1.5)
			_car(Vector3(10, 0, 14), 0.4)
			defaults = [["hall", Vector3(-36, 12, 48), Vector3(0, 9, -12), 50.0], ["hall_front", Vector3(0, 4, 40), Vector3(0, 9, -5), 55.0],
					["hall_steps", Vector3(-9, 4.5, 14), Vector3(0, 5, -4), 60.0], ["hall_side", Vector3(52, 12, -10), Vector3(0, 9, -15), 50.0],
					["hall_back", Vector3(30, 26, -62), Vector3(0, 8, -15), 50.0], ["hall_eave", Vector3(-22, 3, 6), Vector3(-10, 10, -6), 60.0]]
		"pagoda":
			_build("pagoda", Vector3.ZERO, func(pk, kit, labels): KK.call("pagoda", pk, kit, 3))
			_build("pagoda5", Vector3(34, 0, 0), func(pk, kit, labels): KK.call("pagoda", pk, kit, 5))
			_people_row(Vector3(-3, 0, 9), 3, 1.2)
			defaults = [["pagoda", Vector3(-20, 9, 34), Vector3(0, 13, 0), 50.0], ["pagoda_low", Vector3(-9, 2.5, 15), Vector3(0, 10, 0), 65.0],
					["pagoda_top", Vector3(14, 30, 22), Vector3(0, 24, 0), 45.0], ["pagoda_both", Vector3(10, 16, 70), Vector3(17, 18, 0), 50.0]]
		"misc":
			defaults = _set_misc(rng)
		"nice":
			defaults = _set_nice(rng)
		"all":
			defaults = _set_all(rng)
		_:
			which = "houses"
			defaults = _set_houses(rng)
	var tris := 0
	for a in _assets:
		var mi: MeshInstance3D = a[1]
		var t := _tris(mi.mesh)
		tris += t
		var ab: AABB = mi.mesh.get_aabb()
		var lo: Vector3 = (ab.position - (a[2] as Vector3)) / PS
		var hi: Vector3 = (ab.end - (a[2] as Vector3)) / PS
		print("  %s: %d triangles, life x %.2f..%.2f  y %.2f..%.2f  z %.2f..%.2f" % [a[0], t, lo.x, hi.x, lo.y, hi.y, lo.z, hi.z])
	print("triangles ", tris)
	if shots.is_empty():
		shots = defaults
	var cam := Camera3D.new()
	cam.far = 3000.0
	cam.near = 0.1
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
	if sheet and which == "houses":
		await _sheet(cam, out)
	quit()


func _machiya(i: int, v: int, at: Vector3, rng: RandomNumberGenerator, floors := -1) -> float:
	var def: Vector3 = KK.call("machiya_default", v)
	var hr := RandomNumberGenerator.new()
	hr.seed = rng.seed + i * 17
	var fl: int = int(def.z) if floors < 0 else floors
	_build("house_%d_v%d_f%d" % [i, v, fl], at, func(pk, kit, labels): KK.call("machiya", pk, kit, def.x, def.y, fl, v, hr, labels))
	return def.x


## Every machiya variant in a row, then a second row of other draws and storeys.
func _set_houses(rng: RandomNumberGenerator) -> Array:
	var x := 0.0
	for v in range(6):
		x += _machiya(v, v, Vector3(x, 0, 0), rng) * PS + 3.0
	x = 0.0
	var second: Array = [[0, 1], [1, 1], [0, 2], [2, 2], [4, 2], [3, 2], [0, 2]]
	for i in range(second.size()):
		x += _machiya(6 + i, second[i][0], Vector3(x, 0, -34), rng, second[i][1]) * PS + 0.7
	_people_row(Vector3(2, 0, 4.2), 8, 4.0)
	_car(Vector3(14, 0, 8), 0.3)
	return [["houses", Vector3(-18, 13, 44), Vector3(36, 5, -6), 50.0], ["houses_close", Vector3(-5, 2.6, 13), Vector3(8, 4.5, 0), 62.0],
			["houses_mid", Vector3(26, 3, 15), Vector3(38, 4.5, 0), 62.0], ["houses_end", Vector3(52, 3, 15), Vector3(64, 5, 0), 62.0],
			["houses_row2", Vector3(-12, 8, -12), Vector3(34, 4, -36), 50.0], ["houses_back", Vector3(80, 18, -40), Vector3(40, 5, -10), 50.0],
			["houses_above", Vector3(30, 40, 30), Vector3(34, 0, -10), 50.0]]


func _set_misc(rng: RandomNumberGenerator) -> Array:
	_build("chaya", Vector3(0, 0, 0), func(pk, kit, labels): KK.call("chaya", pk, kit, labels))
	for v in range(4):
		var yr := RandomNumberGenerator.new()
		yr.seed = rng.seed + v * 13
		_build("yatai_%d" % v, Vector3(22 + 7.0 * float(v), 0, 0), func(pk, kit, labels): KK.call("yatai", pk, kit, v, yr, labels))
	_build("wall", Vector3(0, 0, -22), func(pk, kit, labels): KK.call("temple_wall", pk, kit, Vector3(0, 0, 0), Vector3(14, 0, 0)))
	_build("wall_gate", Vector3(25.5, 0, -22), func(pk, kit, labels): KK.call("wall_gate", pk, kit, 3.2, labels))
	_build("wall2", Vector3(28.5, 0, -22), func(pk, kit, labels): KK.call("temple_wall", pk, kit, Vector3(0, 0, 0), Vector3(12, 1.5, 0)))
	_people_row(Vector3(2, 0, 5), 8, 2.2)
	_car(Vector3(16, 0, 6), 0.3)
	return [["misc", Vector3(-8, 12, 34), Vector3(24, 3, -8), 50.0], ["chaya", Vector3(-4, 3.5, 15), Vector3(7, 3, -3), 60.0], ["chaya_side", Vector3(24, 5, 10), Vector3(7, 3, -4), 55.0],
			["yatai", Vector3(30, 3, 11), Vector3(34, 2.5, 0), 55.0], ["yatai_b", Vector3(44, 3, 11), Vector3(46, 2.5, 0), 55.0],
			["wall", Vector3(8, 3, -8), Vector3(24, 3, -22), 60.0], ["wall_gate", Vector3(22, 3, -12), Vector3(26, 3.5, -22), 55.0], ["wall_back", Vector3(40, 7, -36), Vector3(26, 3, -22), 55.0]]


func _set_nice(rng: RandomNumberGenerator) -> Array:
	_build("bell_tower", Vector3(0, 0, 0), func(pk, kit, labels): KK.call("bell_tower", pk, kit))
	_build("shrine_hall", Vector3(22, 0, 0), func(pk, kit, labels): KK.call("shrine_hall", pk, kit, labels))
	var kr := RandomNumberGenerator.new()
	kr.seed = rng.seed + 3
	_build("kominka", Vector3(40, 0, 0), func(pk, kit, labels): KK.call("kominka", pk, kit, 12.0, 7.5, kr))
	_build("mountain_hut", Vector3(68, 0, 0), func(pk, kit, labels): KK.call("mountain_hut", pk, kit, labels))
	_people_row(Vector3(2, 0, 6), 10, 2.6)
	return [["nice", Vector3(10, 14, 48), Vector3(40, 3, -4), 50.0], ["bell", Vector3(-8, 4, 13), Vector3(0, 5, 0), 55.0], ["shrine", Vector3(13, 4, 16), Vector3(22, 4, -4), 55.0],
			["kominka", Vector3(38, 5, 20), Vector3(50, 4, -5), 55.0], ["hut", Vector3(64, 4, 16), Vector3(75, 3.5, -4), 55.0], ["nice_back", Vector3(60, 16, -40), Vector3(40, 3, -4), 50.0]]


## A little temple town: a street of machiya both sides leading to the gate, the hall and the pagoda behind it.
func _set_all(rng: RandomNumberGenerator) -> Array:
	var z := 30.0
	for i in range(7):
		var v: int = [1, 0, 2, 4, 3, 5, 0][i]
		var def: Vector3 = KK.call("machiya_default", v)
		var hr := RandomNumberGenerator.new()
		hr.seed = rng.seed + i * 5
		var w: float = def.x
		# West side faces east (+x): the kit's +z turned to +x.
		_build_xf("house_w%d" % i, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-9, 0, z + w * PS)), func(pk, kit, labels): KK.call("machiya", pk, kit, w, def.y, int(def.z), v, hr, labels))
		var v2: int = [0, 3, 1, 0, 2, 4, 1][i]
		var def2: Vector3 = KK.call("machiya_default", v2)
		var hr2 := RandomNumberGenerator.new()
		hr2.seed = rng.seed + i * 5 + 77
		_build_xf("house_e%d" % i, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(9, 0, z)), func(pk, kit, labels): KK.call("machiya", pk, kit, def2.x, def2.y, int(def2.z), v2, hr2, labels))
		z += maxf(w, def2.x) * PS + 0.5
	_build("gate", Vector3(0, 0, 10), func(pk, kit, labels): KK.call("great_gate", pk, kit, labels))
	_build("hall", Vector3(0, 0, -45), func(pk, kit, labels): KK.call("main_hall", pk, kit, labels))
	_build("pagoda", Vector3(42, 0, -40), func(pk, kit, labels): KK.call("pagoda", pk, kit, 3))
	_build("wall_l", Vector3(0, 0, 10), func(pk, kit, labels): KK.call("temple_wall", pk, kit, Vector3(-40, 0, 0), Vector3(-8.2, 0, 0)))
	_build("wall_r", Vector3(0, 0, 10), func(pk, kit, labels): KK.call("temple_wall", pk, kit, Vector3(8.2, 0, 0), Vector3(40, 0, 0)))
	_build("bell_tower", Vector3(-38, 0, -30), func(pk, kit, labels): KK.call("bell_tower", pk, kit))
	_car(Vector3(1, 0, 40), 0.0)
	_people_row(Vector3(-5, 0, 34), 4, 1.2)
	return [["all", Vector3(-70, 55, 150), Vector3(0, 8, 0), 50.0], ["all_street", Vector3(1, 2.5, 100), Vector3(0, 9, 10), 60.0], ["all_street2", Vector3(-3, 3, 60), Vector3(0, 10, 10), 65.0],
			["all_court", Vector3(-25, 8, 0), Vector3(15, 10, -50), 60.0], ["all_above", Vector3(60, 70, 60), Vector3(0, 0, 0), 50.0]]


func _build(asset_name: String, at: Vector3, fn: Callable) -> void:
	_build_xf(asset_name, Transform3D(Basis(), at), fn)


## Builds one asset in the frame `xf` (world, unscaled) through `fn(pk, kit, labels)`, its labels as the generator makes them.
func _build_xf(asset_name: String, xf: Transform3D, fn: Callable) -> void:
	var pk = KK.call("new_kit", PS)
	pk.set_frame(Transform3D(xf.basis.scaled(Vector3.ONE * PS), xf.origin))
	var kit := {}
	var labels: Array = []
	fn.call(pk, kit, labels)
	if kit.is_empty():
		print("  %s: nothing built" % asset_name)
		return
	var mesh: ArrayMesh = KK.call("commit", pk, kit)
	var mi := MeshInstance3D.new()
	mi.name = asset_name
	mi.mesh = mesh
	_root.add_child(mi)
	_assets.append([asset_name, mi, xf.origin])
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
		lab.outline_size = 0
		lab.double_sided = false
		var n: Vector3 = xf.basis * (l[2] as Vector3)
		lab.transform = Transform3D(Basis.looking_at(-n, Vector3.UP), xf * ((l[1] as Vector3) * PS))
		lab.set_meta("asset", asset_name)
		_root.add_child(lab)
	if _dump != "":
		var pk1 = KK.call("new_kit", 1.0)
		var kit1 := {}
		# The same draws again: the callable's rng has moved on, so a dumped house is another of its kind.
		fn.call(pk1, kit1, [])
		ResourceSaver.save(KK.call("commit", pk1, kit1), _dump.path_join("%s.res" % asset_name))
		KK.call("new_kit", PS)


func _tris(mesh: Mesh) -> int:
	var t := 0
	for s in mesh.get_surface_count():
		var idx = mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
		if idx != null and (idx as PackedInt32Array).size() > 0:
			t += (idx as PackedInt32Array).size() / 3
		else:
			t += (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return t


## Each house alone from the same three-quarter view, laid out as one sheet.
func _sheet(cam: Camera3D, out: String) -> void:
	var tiles: Array = []
	var others: Array = []
	for c in _root.get_children():
		if (c is MeshInstance3D and not (c.mesh is PlaneMesh)) or c is Label3D:
			others.append(c)
	for a in _assets:
		if not String(a[0]).begins_with("house"):
			continue
		var mi: MeshInstance3D = a[1]
		for h in others:
			h.visible = h == mi or (h is Label3D and h.get_meta("asset", "") == a[0])
		var aabb: AABB = mi.mesh.get_aabb()
		var c: Vector3 = aabb.get_center()
		var r: float = aabb.size.length() * 0.55
		cam.fov = 45.0
		cam.look_at_from_position(c + Vector3(-0.5, 0.22, 1.0).normalized() * r * 2.1, c, Vector3.UP)
		for i in range(5):
			await process_frame
		await RenderingServer.frame_post_draw
		var img := get_root().get_texture().get_image()
		img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_LANCZOS)
		tiles.append(img)
	if tiles.is_empty():
		return
	var tw: int = tiles[0].get_width()
	var th: int = tiles[0].get_height()
	var colsn := 4
	var rows: int = int(ceil(float(tiles.size()) / float(colsn)))
	var sheet := Image.create(tw * colsn, th * rows, false, tiles[0].get_format())
	for i in range(tiles.size()):
		sheet.blit_rect(tiles[i], Rect2i(0, 0, tw, th), Vector2i((i % colsn) * tw, (i / colsn) * th))
	var path: String = out.path_join("houses_sheet%s.png" % ("_night" if _night else ""))
	sheet.save_png(path)
	print("SHOT ", path)


func _people_row(at: Vector3, n: int, step: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.35, 0.7)
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.85, 0.66, 0.52)
	for i in range(n):
		var p: Vector3 = at + Vector3(step * float(i) * 3.0, 0, 0)
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
	gmat.albedo_color = Color(0.50, 0.49, 0.44) if not _night else Color(0.30, 0.29, 0.28)
	gmat.roughness = 1.0
	pm.material = gmat
	gm.position = Vector3(0, -0.02, 0)
	_root.add_child(gm)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	if _night:
		sm.sky_top_color = Color(0.06, 0.08, 0.20)
		sm.sky_horizon_color = Color(0.62, 0.36, 0.30)
		sm.ground_bottom_color = Color(0.05, 0.05, 0.07)
		sm.ground_horizon_color = Color(0.40, 0.26, 0.24)
		env.glow_enabled = true
		env.glow_intensity = 0.6
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
	sun.rotation_degrees = Vector3(-42.0, -35.0, 0.0) if not _night else Vector3(-9.0, -60.0, 0.0)
	sun.light_energy = 1.35 if not _night else 0.35
	sun.light_color = Color(1.0, 0.96, 0.88) if not _night else Color(1.0, 0.6, 0.45)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 300.0
	_root.add_child(sun)
