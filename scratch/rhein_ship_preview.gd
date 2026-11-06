extends SceneTree
## Look-dev for Rheinufer's river (RheinShipKit.gd): builds the ships and the bank furniture in memory at SCALE 1.6 on a
## flat dark green-grey water plane at y 0 (a grassy bank along -x, and a sloped bank for the furniture) under a low
## evening sun from the west-south-west, waits for the shaders to compile, and saves a PNG per camera. Windowed:
##   Godot --path . --resolution 1400x850 -s res://scratch/rhein_ship_preview.gd -- <out_dir>
##       [set=cargo|tanker|convoy|excursion|ferry|furniture|all] [raised=1] [notext=1] [sun=<pitch>,<yaw>] [save=<dir>]
##       [shots=0] name:x,y,z:tx,ty,tz[:fov] ...
## Positions are in game metres (life x 1.6). Each piece stands at its own spot (printed); with no cameras given it shoots
## each piece's default views: from the bank 60-150m off at 3-10m up, bow and stern quarters, close looks at the quarters
## and the bow, and from 40m (25m life) above, as from a bridge. A 2.2m RC car box (red) and a 2.9m person stand-in (blue)
## stand on the bank and the decks for scale. Prints each piece's triangles and its size (life metres); `save=` writes
## the meshes as .res for scratch/zfight_scan.gd.

const RheinShipKit = preload("res://RheinShipKit.gd")

const SCALE := 1.6

var _raised := false
var _notext := false
var _save_dir := ""


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/rhein"
	DirAccess.make_dir_recursive_absolute(out)
	var which := "cargo"
	var sun_rot := Vector2(-16.0, -64.0)
	var shots: Array = []
	var default_shots := true
	for a in args.slice(1):
		if a.begins_with("set="):
			which = a.substr(4)
		elif a.begins_with("raised="):
			_raised = a.substr(7) == "1"
		elif a.begins_with("notext="):
			_notext = a.substr(7) == "1"
		elif a.begins_with("save="):
			_save_dir = a.substr(5)
			DirAccess.make_dir_recursive_absolute(_save_dir)
		elif a.begins_with("shots="):
			default_shots = a.substr(6) != "0"
		elif a.begins_with("sun="):
			var sv := a.substr(4).split_floats(",")
			sun_rot = Vector2(sv[0], sv[1])
		else:
			shots.append(a)
	_setup_world(sun_rot)
	var sets: Array = ["cargo", "tanker", "convoy", "excursion", "ferry", "furniture"] if which == "all" else Array(which.split(","))
	var total := 0
	var auto: Array = []
	for s in sets:
		var r: Array = _build_set(s)
		total += int(r[0])
		auto.append_array(r[1])
	print("TOTAL triangles ", total)
	if shots.is_empty() and default_shots:
		shots = auto
	var cam := Camera3D.new()
	cam.near = 0.1
	cam.far = 5000.0
	root.add_child(cam)
	cam.make_current()
	for i in 45:
		await process_frame
	for a in shots:
		var parts := (a as String).split(":")
		var p := parts[1].split_floats(",")
		var t := parts[2].split_floats(",")
		cam.fov = float(parts[3]) if parts.size() > 3 else 50.0
		cam.global_position = Vector3(p[0], p[1], p[2])
		cam.look_at(Vector3(t[0], t[1], t[2]), Vector3.UP)
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [out, parts[0]])
		print("SHOT ", parts[0])
	quit()


## Where each set's pieces stand (game metres): [name, spot, life length or 0, builder(pk, kit, labels)].
func _pieces(s: String) -> Array:
	var r := _raised
	match s:
		"cargo":
			return [
				["Cargo0", Vector3(0, 0, 0), 110.0, func(pk, kit, labels): RheinShipKit.cargo_ship(pk, kit, labels, 0, "MARIANNE", r, "KRONBURG")],
				["Cargo1", Vector3(0, 0, -260), 110.0, func(pk, kit, labels): RheinShipKit.cargo_ship(pk, kit, labels, 1, "VENNA", r, "MEERSLOOT", true)],
				["Cargo2", Vector3(0, 0, -520), 110.0, func(pk, kit, labels): RheinShipKit.cargo_ship(pk, kit, labels, 2, "GERDA H", r, "ALTRHEDE")],
			]
		"tanker":
			return [["Tanker", Vector3(500, 0, 0), 86.0, func(pk, kit, labels): RheinShipKit.tanker(pk, kit, labels, "ROSALIE", r)]]
		"convoy":
			return [
				["Convoy2", Vector3(1000, 0, 0), RheinShipKit.convoy_length(2), func(pk, kit, labels): RheinShipKit.push_convoy(pk, kit, labels, 2, r)],
				["Convoy1", Vector3(1000, 0, -420), RheinShipKit.convoy_length(1), func(pk, kit, labels): RheinShipKit.push_convoy(pk, kit, labels, 1, r)],
			]
		"excursion":
			return [["Excursion", Vector3(1500, 0, 0), 70.0, func(pk, kit, labels): RheinShipKit.excursion_ship(pk, kit, labels, "STADT KRONBURG", r)]]
		"ferry":
			return [["Ferry", Vector3(2000, 0, 0), 45.0, func(pk, kit, labels): RheinShipKit.car_ferry(pk, kit, labels)]]
		"furniture":
			var o := Vector3(2500, 0, 0)
			return [
				["Stage", o, 0.0, func(pk, kit, labels): RheinShipKit.landing_stage(pk, kit, labels, 32.0, 5.1)],
				["KmBoard", o + Vector3(-30, 6, -27) * SCALE, 0.0, func(pk, kit, labels): RheinShipKit.km_board(pk, kit, labels, 752)],
				["HalfKm", o + Vector3(-42, 6, -27) * SCALE, 0.0, func(pk, kit, _labels): RheinShipKit.half_km_mark(pk, kit)],
				["BuoyRed", o + Vector3(-22, 0, 30) * SCALE, 0.0, func(pk, kit, _labels): RheinShipKit.fairway_buoy(pk, kit, true)],
				["BuoyGreen", o + Vector3(14, 0, 42) * SCALE, 0.0, func(pk, kit, _labels): RheinShipKit.fairway_buoy(pk, kit, false)],
				["Groyne", o + Vector3(55, 1.0, -11.5) * SCALE, 0.0, func(pk, kit, _labels): RheinShipKit.groyne(pk, kit, 36.0, 1.6)],
				["Pegel", o + Vector3(28, 2.4, -15) * SCALE, 0.0, func(pk, kit, labels): RheinShipKit.pegel(pk, kit, labels)],
				["LifeRing", o + Vector3(-18, 6, -26) * SCALE, 0.0, func(pk, kit, _labels): RheinShipKit.life_ring_post(pk, kit)],
				["Bollard", o + Vector3(-12, 6, -25.2) * SCALE, 0.0, func(pk, kit, _labels): RheinShipKit.mooring_bollard(pk, kit)],
			]
	return []


## Builds a set; returns [triangles, default shots].
func _build_set(s: String) -> Array:
	var tris := 0
	var shots: Array = []
	for pc in _pieces(s):
		var name: String = pc[0]
		var spot: Vector3 = pc[1]
		var pk = RheinShipKit.new_kit(SCALE)
		var kit := {}
		var labels: Array = []
		var t0 := Time.get_ticks_msec()
		(pc[3] as Callable).call(pk, kit, labels)
		var mesh: ArrayMesh = RheinShipKit.commit(pk, kit)
		var mi := MeshInstance3D.new()
		mi.name = name
		mi.mesh = mesh
		mi.position = spot
		root.add_child(mi)
		var t := 0
		for k in mesh.get_surface_count():
			var idx = mesh.surface_get_arrays(k)[Mesh.ARRAY_INDEX]
			t += int((idx as PackedInt32Array).size() / 3.0) if idx != null else int((mesh.surface_get_arrays(k)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3.0)
		var ab: AABB = mesh.get_aabb()
		print("%s: %d triangles, %d surfaces, life size %s from %s (%d ms) at %s" % [name, t, mesh.get_surface_count(), ab.size / SCALE, ab.position / SCALE,
				Time.get_ticks_msec() - t0, spot])
		tris += t
		if _save_dir != "":
			ResourceSaver.save(mesh, "%s/%s.res" % [_save_dir, name])
		if not _notext:
			for l in labels:
				_label(l, mi.transform)
		var L: float = float(pc[2]) * SCALE
		if L > 0.0:
			shots.append_array(_ship_shots(name, spot, L))
			_scale_figures(spot + Vector3(-82, 1.0, 0))
			_person(spot + Vector3(5.2, 1.25, 4.0) * SCALE)
	if s == "furniture":
		var o := Vector3(2500, 0, 0)
		_bank(o)
		_scale_figures(o + Vector3(-6, 6, -28) * SCALE)
		_person(o + Vector3(-4, 0.92, 2) * SCALE)
		for sh in [["fur_bank", Vector3(-60, 14, 75), Vector3(10, 2, -10), 55.0], ["fur_stage", Vector3(-30, 9, 45), Vector3(0, 4, -12), 55.0],
				["fur_gangway", Vector3(25, 12, -10), Vector3(-4, 6, -32), 55.0], ["fur_groyne", Vector3(55, 10, 105), Vector3(90, 0, 10), 50.0],
				["fur_pegel", Vector3(62, 8, 10), Vector3(48, 6, -28), 50.0], ["fur_boards", Vector3(-38, 13, -8), Vector3(-55, 9, -42), 55.0],
				["fur_buoys", Vector3(-5, 6, 120), Vector3(-15, 0, 55), 50.0], ["fur_above", Vector3(10, 60, 80), Vector3(10, 0, -5), 60.0]]:
			var p: Vector3 = o + (sh[1] as Vector3)
			var tg: Vector3 = o + (sh[2] as Vector3)
			shots.append("%s:%f,%f,%f:%f,%f,%f:%f" % [sh[0], p.x, p.y, p.z, tg.x, tg.y, tg.z, sh[3]])
	return [tris, shots]


func _ship_shots(name: String, o: Vector3, L: float) -> Array:
	var n := name.to_lower()
	var list: Array = [
		[n + "_bow", Vector3(-100, 7, L * 0.5 + 45), Vector3(0, 4, L * 0.22), 45.0],
		[n + "_stern", Vector3(-85, 5, -L * 0.5 - 40), Vector3(0, 4, -L * 0.28), 45.0],
		[n + "_side", Vector3(-150, 9, 0), Vector3(0, 3, 0), 50.0],
		[n + "_aft", Vector3(-38, 9, -L * 0.36), Vector3(0, 5, -L * 0.42), 50.0],
		[n + "_fore", Vector3(-34, 7, L * 0.45), Vector3(0, 3, L * 0.42), 50.0],
		[n + "_above", Vector3(-30, 40, L * 0.2), Vector3(0, 0, -L * 0.05), 55.0],
	]
	var outl: Array = []
	for sh in list:
		var p: Vector3 = (sh[1] as Vector3) + o
		var t: Vector3 = (sh[2] as Vector3) + o
		outl.append("%s:%f,%f,%f:%f,%f,%f:%f" % [sh[0], p.x, p.y, p.z, t.x, t.y, t.z, sh[3]])
	return outl


## A Label3D from [text, position (kit units), outward normal, cap height, colour, width] in a piece's frame.
func _label(l: Array, xf: Transform3D) -> void:
	var lab := Label3D.new()
	lab.text = l[0]
	lab.font_size = 64
	lab.pixel_size = float(l[3]) * SCALE / 44.8
	lab.modulate = l[4]
	lab.outline_size = 4
	lab.outline_modulate = Color(0.05, 0.05, 0.05)
	lab.double_sided = false
	lab.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	var n: Vector3 = xf.basis * (l[2] as Vector3)
	var basis := Basis.looking_at(-n, Vector3.UP if absf(n.y) < 0.95 else Vector3.BACK)
	lab.transform = Transform3D(basis, xf * ((l[1] as Vector3) * SCALE))
	if l.size() > 5 and float(l[5]) > 0.0:
		var font: Font = ThemeDB.fallback_font
		var w: float = font.get_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x * lab.pixel_size
		var max_w: float = float(l[5]) * SCALE
		if w > max_w:
			lab.pixel_size *= max_w / w
	root.add_child(lab)


## The furniture's bank: water at y 0 to z -6 (life), a slope from -9 (y 0) up to -24 (y 6), the promenade beyond.
func _bank(o: Vector3) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prof: Array = [Vector2(-4.0, -2.0), Vector2(-9.0, 0.0), Vector2(-24.0, 6.0), Vector2(-90.0, 6.0)]
	var x0 := -120.0
	var x1 := 140.0
	for k in range(prof.size() - 1):
		var a: Vector2 = prof[k]
		var b: Vector2 = prof[k + 1]
		var col: Color = Color(0.36, 0.42, 0.24) if k > 0 else Color(0.40, 0.36, 0.28)
		if k == 2:
			col = Color(0.62, 0.60, 0.56)
		var n := Vector3(0, a.x - b.x, b.y - a.y).normalized()
		if n.y < 0.0:
			n = -n
		var q := [Vector3(x0, a.y, a.x), Vector3(x1, a.y, a.x), Vector3(x1, b.y, b.x), Vector3(x0, b.y, b.x)]
		for idx in [0, 2, 1, 0, 3, 2]:
			st.set_color(col)
			st.set_normal(n)
			st.add_vertex((q[idx] as Vector3) * SCALE)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.position = o
	root.add_child(mi)


## A 2.2m RC car (a red box) and a 2.9m person stand-in (a blue capsule) at `p`.
func _scale_figures(p: Vector3) -> void:
	var car := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.2, 0.7, 2.2)
	car.mesh = bm
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.85, 0.1, 0.08)
	bm.material = cm
	car.position = p + Vector3(0, 0.6, 0)
	root.add_child(car)
	_person(p + Vector3(2.5, 0, 0))


func _person(p: Vector3) -> void:
	var man := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 2.9
	man.mesh = cap
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.15, 0.3, 0.85)
	cap.material = mm
	man.position = p + Vector3(0, 1.45, 0)
	root.add_child(man)


func _setup_world(sun_rot: Vector2) -> void:
	# The river: a dark green-grey plane at y 0.
	var wm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8000, 4000)
	wm.mesh = pm
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.13, 0.18, 0.16)
	wmat.roughness = 0.12
	wmat.metallic = 0.2
	pm.material = wmat
	wm.position = Vector3(1500, 0, 0)
	root.add_child(wm)
	# A grassy bank along -x for the ships' sets.
	var gm := MeshInstance3D.new()
	var gp := PlaneMesh.new()
	gp.size = Vector2(320, 4000)
	gm.mesh = gp
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.32, 0.40, 0.22)
	gmat.roughness = 1.0
	gp.material = gmat
	gm.position = Vector3(-235, 1.0, 0)
	root.add_child(gm)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.22, 0.42, 0.78)
	sm.sky_horizon_color = Color(0.80, 0.80, 0.78)
	sm.sky_curve = 0.12
	sm.ground_bottom_color = Color(0.30, 0.32, 0.28)
	sm.ground_horizon_color = Color(0.66, 0.64, 0.58)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.75
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.fog_enabled = true
	env.fog_light_color = Color(0.82, 0.80, 0.74)
	env.fog_density = 0.00035
	env.fog_sky_affect = 0.08
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(sun_rot.x, sun_rot.y, 0.0)
	sun.light_energy = 1.35
	sun.light_color = Color(1.0, 0.90, 0.76)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 700.0
	root.add_child(sun)
