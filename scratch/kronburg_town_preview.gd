extends SceneTree
## Look-dev for Kronburg's town kit (KronburgTownKit.gd): builds a set of its buildings and street furniture in memory on a
## flat ground at the stage's PROP_SCALE (1.6) under a sunny sky with shadows, with stand-in people (2.9m) and an RC car
## (a 2.2m box) for scale, prints each asset's triangles and saves a PNG per camera. Windowed:
##   Godot --path . --resolution 1400x850 -s res://scratch/kronburg_town_preview.gd -- <out_dir>
##       [set=houses|church|rathaus|gate|fountain|terrace|kiosk|street|castle|misc|all] [seed=N] [sheet=1]
##       name:x,y,z:tx,ty,tz[:fov] ...
## Without cameras each set has its own. `sheet=1` (houses) also renders every house from the same three-quarter view and
## lays the shots out as one contact sheet (houses_sheet.png). Assets stand along +x, their fronts toward +z.

const K = preload("res://KronburgTownKit.gd")
const PS := 1.6
static var KK: Object = null

var _root: Node3D
var _assets: Array = []    # [name, MeshInstance3D, origin, size (world)]


func _init() -> void:
	KK = load("res://KronburgTownKit.gd")
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/kronburg_preview"
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
		else:
			var parts := String(a).split(":")
			if parts.size() >= 3:
				var p := parts[1].split_floats(",")
				var t := parts[2].split_floats(",")
				shots.append([parts[0], Vector3(p[0], p[1], p[2]), Vector3(t[0], t[1], t[2]), float(parts[3]) if parts.size() > 3 else 50.0])
	_setup_world()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var defaults: Array = []
	match which:
		"houses":
			defaults = _set_houses(rng)
		"church":
			_build("church", Vector3.ZERO, func(pk, kit, labels): KK.call("church", pk, kit, labels))
			defaults = [["church", Vector3(-70, 30, 95), Vector3(0, 30, -40), 50.0], ["church_front", Vector3(-12, 6, 50), Vector3(0, 22, 0), 55.0],
					["church_side", Vector3(85, 18, -60), Vector3(0, 22, -55), 50.0], ["church_spire", Vector3(-20, 60, 40), Vector3(0, 80, -10), 45.0]]
		"rathaus":
			_build("rathaus", Vector3.ZERO, func(pk, kit, labels): KK.call("rathaus", pk, kit, labels))
			defaults = [["rathaus", Vector3(-12, 12, 70), Vector3(17, 14, -8), 50.0], ["rathaus_close", Vector3(8, 3.5, 14), Vector3(17, 5, -2), 60.0],
					["rathaus_back", Vector3(60, 25, -60), Vector3(17, 12, -10), 50.0]]
		"gate":
			_build("gate", Vector3.ZERO, func(pk, kit, labels): KK.call("town_gate", pk, kit, labels))
			defaults = [["gate", Vector3(-30, 10, 60), Vector3(0, 16, 0), 55.0], ["gate_road", Vector3(0, 4, 45), Vector3(0, 9, 0), 60.0],
					["gate_through", Vector3(2, 5, 14), Vector3(0, 7, -20), 70.0], ["gate_back", Vector3(40, 30, -55), Vector3(0, 14, 0), 50.0]]
		"fountain":
			_build("fountain", Vector3.ZERO, func(pk, kit, labels): KK.call("market_fountain", pk, kit))
			defaults = [["fountain", Vector3(-10, 6, 14), Vector3(0, 3, 0), 55.0], ["fountain_top", Vector3(3, 18, 6), Vector3(0, 1, 0), 50.0]]
		"terrace":
			defaults = _set_terrace(rng)
		"kiosk":
			_build("trinkhalle", Vector3.ZERO, func(pk, kit, labels): KK.call("trinkhalle", pk, kit, labels))
			_build("litfass", Vector3(14, 0, 4), func(pk, kit, labels): KK.call("litfass", pk, kit))
			defaults = [["kiosk", Vector3(-6, 4, 14), Vector3(5, 2.5, -2), 55.0], ["kiosk_side", Vector3(22, 5, 12), Vector3(8, 2.5, 0), 55.0]]
		"street":
			defaults = _set_street(rng)
		"castle":
			_build("castle", Vector3.ZERO, func(pk, kit, labels): KK.call("castle_ruin", pk, kit))
			defaults = [["castle", Vector3(-80, 35, 90), Vector3(0, 12, 0), 50.0], ["castle_low", Vector3(-30, 4, 50), Vector3(0, 14, 0), 55.0],
					["castle_above", Vector3(50, 90, 60), Vector3(0, 0, 0), 50.0]]
		"misc":
			defaults = _set_misc(rng)
		"all":
			defaults = _set_all(rng)
		_:
			defaults = _set_houses(rng)
	var tris := 0
	for a in _assets:
		var mi: MeshInstance3D = a[1]
		var t := _tris(mi.mesh)
		tris += t
		print("  %s: %d surfaces, %d triangles, size %s (life %s)" % [a[0], mi.mesh.get_surface_count(), t, str((a[3] as Vector3).snapped(Vector3.ONE * 0.1)),
				str(((a[3] as Vector3) / PS).snapped(Vector3.ONE * 0.1))])
	print("triangles ", tris)
	if OS.get_cmdline_user_args().has("keys=1"):
		for a in _assets:
			var m: Mesh = (a[1] as MeshInstance3D).mesh
			var parts: Array = []
			for si in m.get_surface_count():
				var idx = m.surface_get_arrays(si)[Mesh.ARRAY_INDEX]
				var mat: Material = m.surface_get_material(si)
				var key: String = str(m.surface_get_name(si))
				parts.append("%s:%d" % [key if key != "" else str(si), (idx as PackedInt32Array).size() / 3])
			print("    ", a[0], " ", ", ".join(parts))
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
		var path: String = out.path_join("%s.png" % s[0])
		get_root().get_texture().get_image().save_png(path)
		print("SHOT ", path)
	if sheet and which == "houses":
		await _sheet(cam, out)
	quit()


## Every house variant (0..4 at three storeys), then a second row with other widths and storeys, along x.
func _set_houses(rng: RandomNumberGenerator) -> Array:
	var x := 0.0
	var specs: Array = [[7.0, 10.0, 3, 0], [6.5, 11.0, 3, 1], [7.5, 10.0, 3, 2], [7.0, 11.0, 3, 3], [12.0, 9.0, 3, 4],
			[6.0, 9.0, 2, 0], [8.5, 12.0, 4, 1], [6.0, 9.5, 2, 2], [8.0, 10.0, 2, 3], [10.0, 9.0, 2, 4],
			[7.0, 10.0, 3, 3], [7.0, 10.0, 3, 3], [7.0, 10.0, 3, 3]]
	for i in range(specs.size()):
		var sp: Array = specs[i]
		var w: float = sp[0]
		var row: int = 0 if i < 5 else (1 if i < 10 else 2)
		if i == 5 or i == 10:
			x = 0.0
		var z: float = -40.0 * float(row)
		var hr := RandomNumberGenerator.new()
		hr.seed = rng.seed + i * 17
		_build("house_%d_v%d_f%d" % [i, sp[3], sp[2]], Vector3(x, 0, z), func(pk, kit, labels): K.fachwerk_house(pk, kit, w, sp[1], sp[2], sp[3], hr, labels))
		x += w * PS + 5.0
	_people_row(Vector3(0, 0, 5), 12, 14.0)
	_car(Vector3(20, 0, 9), 0.3)
	return [["houses", Vector3(-25, 16, 55), Vector3(45, 10, -10), 50.0], ["houses_close", Vector3(-6, 3, 18), Vector3(8, 9, 0), 60.0],
			["houses_row2", Vector3(-20, 14, 15), Vector3(40, 10, -45), 50.0], ["houses_back", Vector3(80, 25, -80), Vector3(40, 10, -20), 50.0]]


func _set_terrace(rng: RandomNumberGenerator) -> Array:
	var x := 0.0
	for i in range(3):
		var units: int = 4 if i == 1 else 2
		var hr := RandomNumberGenerator.new()
		hr.seed = rng.seed + 101 * i
		_build("terrace_%d" % i, Vector3(x, 0, 0), func(pk, kit, labels): KK.call("brick_terrace", pk, kit, units, i, hr))
		x += float(units) * 7.0 * PS + 8.0
	_people_row(Vector3(0, 0, 3), 6, 18.0)
	_car(Vector3(14, 0, 6), 0.0)
	return [["terrace", Vector3(-15, 14, 50), Vector3(40, 4, -10), 50.0], ["terrace_close", Vector3(4, 3, 16), Vector3(14, 4, -8), 60.0],
			["terrace_back", Vector3(70, 20, -70), Vector3(40, 3, -20), 50.0]]


func _set_street(_rng: RandomNumberGenerator) -> Array:
	var items: Array = [
		["ortsschild", func(pk, kit, labels): KK.call("ortsschild", pk, kit, labels, "Kronburg", "Kreis Ruhr-Ost")],
		["peitschen", func(pk, kit, labels): KK.call("peitschen_lamp", pk, kit)],
		["lantern", func(pk, kit, labels): KK.call("old_lantern_post", pk, kit)],
		["bus_stop", func(pk, kit, labels): KK.call("bus_stop", pk, kit, labels)],
		["bollard", func(pk, kit, labels): KK.call("bollard", pk, kit)],
		["bench", func(pk, kit, labels): KK.call("street_bench", pk, kit)],
		["bike_rack", func(pk, kit, labels): KK.call("bike_rack", pk, kit)],
		["glass", func(pk, kit, labels): KK.call("glass_containers", pk, kit)],
		["crates", func(pk, kit, labels): KK.call("beer_crates", pk, kit, 5)],
	]
	var x := 0.0
	for it in items:
		_build(it[0], Vector3(x, 0, 0), it[1])
		x += 9.0
	_people_row(Vector3(0, 0, 4), 6, 12.0)
	return [["street", Vector3(-6, 6, 22), Vector3(30, 2.5, 0), 55.0], ["street_b", Vector3(36, 6, 24), Vector3(50, 2.5, 0), 55.0],
			["street_sign", Vector3(2, 3, 9), Vector3(0, 3, 0), 50.0], ["street_bus", Vector3(30, 3, 12), Vector3(27, 2.5, -1), 55.0]]


func _set_misc(rng: RandomNumberGenerator) -> Array:
	var r1 := RandomNumberGenerator.new()
	r1.seed = rng.seed + 5
	var r2 := RandomNumberGenerator.new()
	r2.seed = rng.seed + 9
	_build("allotment", Vector3(0, 0, 0), func(pk, kit, labels): KK.call("allotment", pk, kit, 14.0, 18.0, r1))
	_build("beer_garden", Vector3(34, 0, 0), func(pk, kit, labels): KK.call("beer_garden", pk, kit, 18.0, 14.0, r2))
	_build("maibaum", Vector3(70, 0, -10), func(pk, kit, labels): KK.call("maibaum", pk, kit))
	_people_row(Vector3(0, 0, 4), 6, 16.0)
	return [["misc", Vector3(-10, 20, 45), Vector3(40, 3, -14), 50.0], ["allotment", Vector3(-8, 8, 12), Vector3(10, 1, -12), 55.0],
			["beer_garden", Vector3(30, 9, 16), Vector3(48, 1, -10), 55.0], ["maibaum", Vector3(55, 10, 20), Vector3(70, 18, -10), 50.0]]


## Everything at once, as a little town: the five house variants along a street, the town hall and the fountain on a
## square, the church behind, the gate at the street's end, a terrace, the kiosk and the column, the street furniture,
## the castle on its own off to the side.
func _set_all(rng: RandomNumberGenerator) -> Array:
	var x := 0.0
	for v in range(5):
		var w: float = 11.0 if v == 4 else 7.0
		var hr := RandomNumberGenerator.new()
		hr.seed = rng.seed + v * 31
		_build("house_v%d" % v, Vector3(x, 0, 0), func(pk, kit, labels): K.fachwerk_house(pk, kit, w, 10.0, 3, v, hr, labels))
		x += w * PS + 2.0
	_build("rathaus", Vector3(-45, 0, 0), func(pk, kit, labels): KK.call("rathaus", pk, kit, labels))
	_build("fountain", Vector3(-27, 0, 32), func(pk, kit, labels): KK.call("market_fountain", pk, kit))
	_build("church", Vector3(40, 0, -40), func(pk, kit, labels): KK.call("church", pk, kit, labels))
	_build("gate", Vector3(110, 0, 25), func(pk, kit, labels): KK.call("town_gate", pk, kit, labels))
	var tr := RandomNumberGenerator.new()
	tr.seed = rng.seed + 7
	_build("terrace", Vector3(-60, 0, 90), func(pk, kit, labels): KK.call("brick_terrace", pk, kit, 4, 0, tr))
	_build("trinkhalle", Vector3(10, 0, 40), func(pk, kit, labels): KK.call("trinkhalle", pk, kit, labels))
	_build("litfass", Vector3(26, 0, 42), func(pk, kit, labels): KK.call("litfass", pk, kit))
	_build("ortsschild", Vector3(70, 0, 40), func(pk, kit, labels): KK.call("ortsschild", pk, kit, labels, "Kronburg", "Kreis Ruhr-Ost"))
	_build("bus_stop", Vector3(40, 0, 40), func(pk, kit, labels): KK.call("bus_stop", pk, kit, labels))
	_build("castle", Vector3(-150, 0, -120), func(pk, kit, labels): KK.call("castle_ruin", pk, kit))
	_people_row(Vector3(0, 0, 8), 10, 20.0)
	return [["all", Vector3(-90, 60, 130), Vector3(10, 5, 0), 50.0], ["all_street", Vector3(-20, 8, 30), Vector3(40, 9, 0), 55.0],
			["all_castle", Vector3(-110, 40, -40), Vector3(-150, 8, -120), 50.0]]


## Builds one asset at `at` (world) through `fn(pk, kit, labels)`, its labels as the generator makes them.
func _build(asset_name: String, at: Vector3, fn: Callable) -> void:
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
	_assets.append([asset_name, mi, at, mesh.get_aabb().size])
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
		lab.outline_size = 4
		lab.outline_modulate = Color(0.05, 0.05, 0.05)
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


## Each house from the same three-quarter view, two rows of shots laid out as one sheet.
func _sheet(cam: Camera3D, out: String) -> void:
	var tiles: Array = []
	# Only the house being shot is shown (and its labels: everything else in the root is hidden too).
	var hidden: Array = []
	for c in _root.get_children():
		if (c is MeshInstance3D and not (c.mesh is PlaneMesh)) or c is Label3D:
			c.visible = false
			hidden.append(c)
	for a in _assets:
		if not String(a[0]).begins_with("house"):
			continue
		var mi: MeshInstance3D = a[1]
		for h in hidden:
			h.visible = false
		mi.visible = true
		for c in _root.get_children():
			if c is Label3D and absf(c.position.x - mi.mesh.get_aabb().get_center().x) < mi.mesh.get_aabb().size.x * 0.6 and absf(c.position.z - mi.mesh.get_aabb().get_center().z) < 20.0:
				c.visible = true
		var aabb: AABB = mi.mesh.get_aabb()
		var c: Vector3 = aabb.get_center()
		var r: float = aabb.size.length() * 0.55
		cam.fov = 45.0
		cam.look_at_from_position(c + Vector3(-0.55, 0.28, 1.0).normalized() * r * 2.2, c, Vector3.UP)
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
	sheet.save_png(out.path_join("houses_sheet.png"))
	print("SHOT ", out.path_join("houses_sheet.png"))


## Stand-in people (2.9m: a body, a head) in a row from `at` along x, `n` of them over `span`.
func _people_row(at: Vector3, n: int, span: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.35, 0.7)
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.85, 0.66, 0.52)
	for i in range(n):
		var p: Vector3 = at + Vector3(span * float(i) / float(maxi(n - 1, 1)) * 3.0, 0, 0)
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


## A stand-in RC car: a 2.2 x 0.9 x 1.1m red box.
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
	sun.rotation_degrees = Vector3(-42.0, -35.0, 0.0)
	sun.light_energy = 1.35
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 300.0
	_root.add_child(sun)
