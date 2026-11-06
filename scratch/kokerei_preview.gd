extends SceneTree
## Look-dev for Kokerei Kronprinz (KokereiKit.gd): builds a set in memory at SCALE 1.6 on a flat ground under a sky with a
## shadowed sun, waits for the shaders to compile, and saves a PNG per camera. Windowed:
##   Godot --path . --resolution 1400x850 -s res://scratch/kokerei_preview.gd -- <out_dir>
##       [set=battery|machines|tower|quench|wharf|byproduct|flare|rails|all] [ovens=50] [sun=<pitch>,<yaw>] [notext=1]
##       [fog=1] name:x,y,z:tx,ty,tz[:fov] ...
## Positions are game metres (life x 1.6). Each set stands at its own spot (SPOTS); with no cameras given it shoots the set's
## default views. A 2.2m RC car box (red) and a 2.9m person (blue) stand on the race road for scale: the road runs along
## the battery's coke side (life z 21..30 in the battery's frame: ROAD_Z0, the edge the report recommends). "all" lays the
## whole plant out as the report recommends (KokereiKit's header). Prints each piece's triangles.

const KokereiKit = preload("res://KokereiKit.gd")
const SteelworksKit = preload("res://SteelworksKit.gd")

const SCALE := 1.6
## The race road's near edge and far edge in the battery frame (life z).
const ROAD_Z0 := 21.0
const ROAD_Z1 := 30.0

const SPOTS := {
	"battery": Vector3(0, 0, 0),
	"machines": Vector3(0, 0, 600),
	"tower": Vector3(-500, 0, 600),
	"quench": Vector3(600, 0, 600),
	"wharf": Vector3(600, 0, 0),
	"byproduct": Vector3(0, 0, -600),
	"flare": Vector3(-500, 0, -600),
	"rails": Vector3(-500, 0, 0),
	"all": Vector3(0, 0, 0),
}

var ovens := 50


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/kokerei"
	DirAccess.make_dir_recursive_absolute(out)
	var which := "battery"
	var sun_rot := Vector2(-38.0, 150.0)
	var notext := false
	var fog := false
	var shots: Array = []
	for a in args.slice(1):
		if a.begins_with("set="):
			which = a.substr(4)
		elif a.begins_with("ovens="):
			ovens = int(a.substr(6))
		elif a.begins_with("sun="):
			var sv := a.substr(4).split_floats(",")
			sun_rot = Vector2(sv[0], sv[1])
		elif a.begins_with("notext="):
			notext = a.substr(7) == "1"
		elif a.begins_with("fog="):
			fog = a.substr(4) == "1"
		else:
			shots.append(a)
	_setup_world(sun_rot, fog, which)
	var sets: Array = Array(which.split(","))
	var total := 0
	for s in sets:
		total += _build_set(s, notext)
	print("TOTAL triangles ", total)
	if shots.is_empty():
		for s in sets:
			shots.append_array(_default_shots(s))
	var cam := Camera3D.new()
	cam.near = 0.1
	cam.far = 4000.0
	root.add_child(cam)
	cam.make_current()
	for i in 45:
		await process_frame
	for a in shots:
		var parts := (a as String).split(":")
		var p := parts[1].split_floats(",")
		var t := parts[2].split_floats(",")
		cam.fov = float(parts[3]) if parts.size() > 3 else 55.0
		cam.global_position = Vector3(p[0], p[1], p[2])
		cam.look_at(Vector3(t[0], t[1], t[2]), Vector3.UP)
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [out, parts[0]])
		print("SHOT ", parts[0])
	quit()


## Default views (game metres, relative to the set's spot).
func _default_shots(s: String) -> Array:
	var o: Vector3 = SPOTS.get(s, Vector3.ZERO)
	var L: float = KokereiKit.battery_length(ovens) * SCALE
	var rz: float = (ROAD_Z0 + 1.5) * SCALE
	var list: Array = []
	match s:
		"battery":
			list = [
				["bat_road_low", Vector3(8, 1.5, rz), Vector3(60, 7, 14), 60.0],
				["bat_road_high", Vector3(8, 6, rz + 2), Vector3(70, 9, 8), 60.0],
				["bat_face", Vector3(L * 0.5, 3, rz + 4), Vector3(L * 0.5, 9, 10), 55.0],
				["bat_end", Vector3(-38, 16, 44), Vector3(18, 9, 0), 55.0],
				["bat_far_end", Vector3(L + 40, 14, 30), Vector3(L - 10, 9, -4), 55.0],
				["bat_top", Vector3(40, 34, 30), Vector3(66, 15, -4), 55.0],
				["bat_pusher", Vector3(L * 0.65, 8, -62), Vector3(L * 0.45, 11, -8), 60.0],
				["bat_afar", Vector3(-140, 80, 210), Vector3(L * 0.5, 10, 0), 50.0],
			]
		"machines":
			list = [
				["mach_coke", Vector3(26, 6, 52), Vector3(14, 8, 16), 55.0],
				["mach_coke_low", Vector3(-6, 1.5, rz), Vector3(14, 6, 18), 60.0],
				["mach_pusher", Vector3(34, 10, -58), Vector3(14, 8, -26), 55.0],
				["mach_top", Vector3(-12, 30, 24), Vector3(14, 19, 0), 55.0],
				["mach_guide_close", Vector3(24, 9, 30), Vector3(15, 9, 16), 55.0],
			]
		"tower":
			list = [["tower_road", Vector3(30, 4, 70), Vector3(-10, 36, 0), 55.0], ["tower_end", Vector3(-70, 30, 60), Vector3(0, 38, 0), 55.0],
					["tower_deck", Vector3(26, 22, 26), Vector3(4, 18, 0), 60.0]]
		"quench":
			list = [["quench_road", Vector3(-30, 1.5, 32), Vector3(0, 22, 0), 60.0], ["quench_high", Vector3(-55, 10, 70), Vector3(0, 32, 0), 50.0],
					["quench_stairs", Vector3(40, 22, -60), Vector3(0, 28, -6), 55.0], ["quench_passage", Vector3(-26, 3, 2), Vector3(0, 5, 0), 60.0]]
		"wharf":
			list = [["wharf_road", Vector3(-20, 9, 40), Vector3(40, 2, -6), 55.0], ["wharf_yard", Vector3(30, 3, -50), Vector3(48, 5, -6), 60.0],
					["wharf_above", Vector3(10, 30, 30), Vector3(48, 2, -6), 55.0]]
		"byproduct":
			list = [["bp_afar", Vector3(-110, 50, 120), Vector3(0, 12, 0), 55.0], ["bp_low", Vector3(80, 3, 80), Vector3(20, 18, 20), 60.0],
					["bp_tanks", Vector3(30, 14, -95), Vector3(0, 6, -28), 55.0], ["bp_hall", Vector3(30, 8, 62), Vector3(0, 10, 24), 60.0]]
		"flare":
			list = [["flare", Vector3(-30, 14, 40), Vector3(0, 26, 0), 55.0], ["flare_tip", Vector3(-10, 52, 14), Vector3(0, 47, 0), 55.0]]
		"rails":
			list = [["rails", Vector3(-6, 2, 6), Vector3(10, 0, 0), 60.0]]
		"all":
			var qz: float = KokereiKit.QUENCH_Z * SCALE
			list = [
				["all_road_low", Vector3(10, 1.5, rz), Vector3(70, 8, 12), 62.0],
				["all_road_high", Vector3(30, 6, rz + 2), Vector3(110, 12, 6), 60.0],
				["all_road_quench", Vector3(L + 0.0, 1.5, rz + 3), Vector3(L + 48, 22, qz), 62.0],
				["all_road_quench_hi", Vector3(L + 10.0, 6, rz + 4), Vector3(L + 60, 18, qz), 60.0],
				["all_road_wharf", Vector3(L + 70, 6, rz + 6), Vector3(L + 125, 1, qz - 8), 60.0],
				["all_road_back", Vector3(L + 150, 1.5, rz + 3), Vector3(L - 20, 10, 10), 55.0],
				["all_afar", Vector3(-220, 120, 300), Vector3(L * 0.7, 10, -40), 50.0],
				["all_afar_pusher", Vector3(L + 250, 110, -260), Vector3(L * 0.4, 10, -60), 50.0],
				["all_halde", Vector3(L * 0.6, 70, 260), Vector3(L * 0.6, 10, -20), 50.0],
			]
	var outl: Array = []
	for sh in list:
		var p: Vector3 = (sh[1] as Vector3) + o
		var t: Vector3 = (sh[2] as Vector3) + o
		outl.append("%s:%f,%f,%f:%f,%f,%f:%f" % [sh[0], p.x, p.y, p.z, t.x, t.y, t.z, sh[3]])
	return outl


## Builds one set at its spot; returns its triangles.
func _build_set(s: String, notext: bool) -> int:
	var o: Vector3 = SPOTS.get(s, Vector3.ZERO)
	var parts: Array = []   # [name, local transform (life units, battery frame), builder Callable]
	var n := ovens
	var L: float = KokereiKit.battery_length(n)
	match s:
		"battery":
			parts.append(["Koksofenbatterie", Transform3D.IDENTITY, func(pk, kit, labels): KokereiKit.coke_battery(pk, kit, labels, n, 3, 3)])
			parts.append(["KokereiGleis", Transform3D(Basis(), Vector3(-20, 0, KokereiKit.QUENCH_Z)), func(pk, kit, _l): KokereiKit.kokerei_rails(pk, kit, L + 40.0)])
			_road(o, -60.0, L + 60.0)
			_scale_figures(o + Vector3(30, 0, (ROAD_Z0 + 3.0) * SCALE))
		"machines":
			var m := 8
			var L8: float = KokereiKit.battery_length(m)
			var oi := 4
			var ox: float = KokereiKit.oven_x(oi)
			parts.append(["Koksofenbatterie", Transform3D.IDENTITY, func(pk, kit, labels): KokereiKit.coke_battery(pk, kit, labels, m, 3, 3, oi)])
			parts.append(["Ausdrueckmaschine", Transform3D(Basis(), Vector3(ox, 0, 0)), func(pk, kit, _l): KokereiKit.pusher_machine(pk, kit, true)])
			parts.append(["Koksfuehrungswagen", Transform3D(Basis(), Vector3(ox, 0, 0)), func(pk, kit, _l): KokereiKit.coke_guide_car(pk, kit, true, true)])
			parts.append(["Loeschwagen", Transform3D(Basis(), Vector3(ox, 0, KokereiKit.QUENCH_Z)), func(pk, kit, _l): KokereiKit.quench_car(pk, kit, 1)])
			parts.append(["Fuellwagen", Transform3D(Basis(), Vector3(KokereiKit.oven_x(1), 0, 0)), func(pk, kit, _l): KokereiKit.larry_car(pk, kit)])
			parts.append(["KokereiGleis", Transform3D(Basis(), Vector3(-20, 0, KokereiKit.QUENCH_Z)), func(pk, kit, _l): KokereiKit.kokerei_rails(pk, kit, L8 + 40.0)])
			_road(o, -40.0, L8 + 40.0)
			_scale_figures(o + Vector3(10, 0, (ROAD_Z0 + 3.0) * SCALE))
		"tower":
			parts.append(["Kohlenturm", Transform3D.IDENTITY, func(pk, kit, labels): KokereiKit.coal_tower(pk, kit, labels)])
			parts.append(["Fuellwagen", Transform3D(Basis(), Vector3(0, 0, 0)), func(pk, kit, _l): KokereiKit.larry_car(pk, kit)])
			_scale_figures(o + Vector3(14, 0, 30))
		"quench":
			parts.append(["Loeschturm", Transform3D.IDENTITY, func(pk, kit, labels): KokereiKit.quench_tower(pk, kit, labels)])
			parts.append(["KokereiGleis", Transform3D(Basis(), Vector3(-40, 0, 0)), func(pk, kit, _l): KokereiKit.kokerei_rails(pk, kit, 80.0)])
			parts.append(["Loeschwagen", Transform3D(Basis(), Vector3(3.0, 0, 0)), func(pk, kit, _l): KokereiKit.quench_car(pk, kit, 2)])
			_scale_figures(o + Vector3(-20, 0, 18))
		"wharf":
			# The wharf's frame 4.6m under the track's ground: an embankment box carries the track in the preview.
			parts.append(["Kokskai", Transform3D.IDENTITY, func(pk, kit, _l): KokereiKit.coke_wharf(pk, kit, 60.0)])
			var ty: float = KokereiKit.WHARF_TRACK_Y
			parts.append(["KokereiGleis", Transform3D(Basis(), Vector3(-20, ty, KokereiKit.WHARF_TRACK_Z)), func(pk, kit, _l): KokereiKit.kokerei_rails(pk, kit, 100.0)])
			parts.append(["Loeschwagen", Transform3D(Basis(), Vector3(30.0, ty, KokereiKit.WHARF_TRACK_Z)), func(pk, kit, _l): KokereiKit.quench_car(pk, kit, 2)])
			_slab(o + Vector3(-20, 0, 1.0) * SCALE, Vector3(100, ty, 8.0) * SCALE, Color(0.40, 0.38, 0.34))
			_scale_figures(o + Vector3(30, 0, -24))
		"byproduct":
			parts.append(["Nebengewinnung", Transform3D.IDENTITY, func(pk, kit, labels): KokereiKit.byproduct_plant(pk, kit, labels)])
			_scale_figures(o + Vector3(20, 0, 50))
		"flare":
			parts.append(["Notfackel", Transform3D.IDENTITY, func(pk, kit, _l): KokereiKit.gas_flare(pk, kit)])
			_scale_figures(o + Vector3(-8, 0, 10))
		"rails":
			parts.append(["KokereiGleis", Transform3D.IDENTITY, func(pk, kit, _l): KokereiKit.kokerei_rails(pk, kit, 30.0)])
			_scale_figures(o + Vector3(4, 0, 5))
		"all":
			var oi2 := 30
			var ox2: float = KokereiKit.oven_x(oi2)
			var qz: float = KokereiKit.QUENCH_Z
			var xq: float = L + 30.0
			var xw: float = L + 52.0
			parts.append(["Koksofenbatterie", Transform3D.IDENTITY, func(pk, kit, labels): KokereiKit.coke_battery(pk, kit, labels, n, 3, 3, oi2)])
			parts.append(["Kohlenturm", Transform3D(Basis(), Vector3(KokereiKit.COAL_TOWER_X, 0, 0)), func(pk, kit, labels): KokereiKit.coal_tower(pk, kit, labels)])
			parts.append(["Fuellwagen", Transform3D(Basis(), Vector3(KokereiKit.oven_x(12), 0, 0)), func(pk, kit, _l): KokereiKit.larry_car(pk, kit)])
			parts.append(["Ausdrueckmaschine", Transform3D(Basis(), Vector3(ox2, 0, 0)), func(pk, kit, _l): KokereiKit.pusher_machine(pk, kit, true)])
			parts.append(["Koksfuehrungswagen", Transform3D(Basis(), Vector3(ox2, 0, 0)), func(pk, kit, _l): KokereiKit.coke_guide_car(pk, kit, true, true)])
			parts.append(["Loeschwagen", Transform3D(Basis(), Vector3(ox2, 0, qz)), func(pk, kit, _l): KokereiKit.quench_car(pk, kit, 1)])
			parts.append(["KokereiGleis", Transform3D(Basis(), Vector3(-30, 0, qz)), func(pk, kit, _l): KokereiKit.kokerei_rails(pk, kit, xw + 60.0 + 30.0 + 20.0)])
			parts.append(["Loeschturm", Transform3D(Basis(), Vector3(xq, 0, qz)), func(pk, kit, labels): KokereiKit.quench_tower(pk, kit, labels)])
			parts.append(["Kokskai", Transform3D(Basis(), Vector3(xw, -KokereiKit.WHARF_TRACK_Y, qz - KokereiKit.WHARF_TRACK_Z)), func(pk, kit, _l): KokereiKit.coke_wharf(pk, kit, 60.0)])
			var bpo := Vector3(L * 0.5 + 10.0, 0, -75.0)
			parts.append(["Nebengewinnung", Transform3D(Basis(), bpo), func(pk, kit, labels): KokereiKit.byproduct_plant(pk, kit, labels)])
			parts.append(["Notfackel", Transform3D(Basis(), Vector3(L + 30.0, 0, -62.0)), func(pk, kit, _l): KokereiKit.gas_flare(pk, kit)])
			var off: Array = KokereiKit.gas_offtake(n)
			var p0: Vector3 = off[0]
			var inlet: Vector3 = bpo + KokereiKit.byproduct_gas_inlet()
			parts.append(["Saugleitung", Transform3D.IDENTITY, func(pk, kit, _l): SteelworksKit.pipe_run(pk, kit, PackedVector3Array([p0, Vector3(p0.x, p0.y, inlet.z),
					Vector3(inlet.x + 2.0, p0.y, inlet.z), Vector3(inlet.x + 2.0, inlet.y, inlet.z), inlet]), 0.75)])
			_road(o, -80.0, L + 200.0)
			_scale_figures(o + Vector3(40, 0, (ROAD_Z0 + 3.0) * SCALE))
			_scale_figures(o + Vector3((L + 30) * SCALE, 0, (ROAD_Z0 + 3.0) * SCALE))
	var tris := 0
	for part in parts:
		var pk = KokereiKit.new_kit(SCALE)
		var kit := {}
		var labels: Array = []
		var t0 := Time.get_ticks_msec()
		(part[2] as Callable).call(pk, kit, labels)
		var mesh: ArrayMesh = KokereiKit.commit(pk, kit)
		var mi := MeshInstance3D.new()
		mi.name = part[0]
		mi.mesh = mesh
		var lt: Transform3D = part[1]
		mi.transform = Transform3D(lt.basis, o + lt.origin * SCALE)
		root.add_child(mi)
		var t := 0
		for k in mesh.get_surface_count():
			var idx = mesh.surface_get_arrays(k)[Mesh.ARRAY_INDEX]
			t += int((idx as PackedInt32Array).size() / 3.0) if idx != null else int((mesh.surface_get_arrays(k)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3.0)
		print("%s: %d triangles, %d surfaces, aabb %s (%d ms)" % [part[0], t, mesh.get_surface_count(), mesh.get_aabb(), Time.get_ticks_msec() - t0])
		tris += t
		if not notext:
			for l in labels:
				_label(l, mi.transform)
	return tris


## A Label3D from [text, position (kit units), outward normal, cap height, colour, width] in a piece's frame.
func _label(l: Array, xf: Transform3D) -> void:
	var lab := Label3D.new()
	lab.text = l[0]
	lab.font_size = 64
	lab.pixel_size = float(l[3]) * SCALE / 44.8
	lab.modulate = l[4]
	lab.outline_size = 0
	lab.double_sided = false
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


## The race road along the coke side (life z ROAD_Z0..ROAD_Z1 in the battery's frame), a dirt track with pale edges.
func _road(o: Vector3, x0: float, x1: float) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2((x1 - x0) * SCALE, (ROAD_Z1 - ROAD_Z0) * SCALE)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.36, 0.31, 0.26)
	m.roughness = 0.95
	pm.material = m
	mi.position = o + Vector3((x0 + x1) * 0.5 * SCALE, 0.03, (ROAD_Z0 + ROAD_Z1) * 0.5 * SCALE)
	root.add_child(mi)
	for z in [ROAD_Z0, ROAD_Z1]:
		var line := MeshInstance3D.new()
		var lm := PlaneMesh.new()
		lm.size = Vector2((x1 - x0) * SCALE, 0.3)
		line.mesh = lm
		var mm := StandardMaterial3D.new()
		mm.albedo_color = Color(0.85, 0.82, 0.74)
		lm.material = mm
		line.position = o + Vector3((x0 + x1) * 0.5 * SCALE, 0.04, z * SCALE)
		root.add_child(line)


## A plain box (an embankment, a step in the ground) from `p` (its low corner) sized `s` (game metres).
func _slab(p: Vector3, s: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = s
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 1.0
	bm.material = m
	mi.position = p + s * 0.5
	root.add_child(mi)


## A 2.2m RC car (a red box) and a 2.9m person stand-in (a blue capsule) at `p`.
func _scale_figures(p: Vector3) -> void:
	var car := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.2, 0.7, 1.2)
	car.mesh = bm
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.85, 0.1, 0.08)
	bm.material = cm
	car.position = p + Vector3(0, 0.6, 0)
	root.add_child(car)
	var man := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 2.9
	man.mesh = cap
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.15, 0.3, 0.85)
	cap.material = mm
	man.position = p + Vector3(4.0, 1.45, 0)
	root.add_child(man)


func _setup_world(sun_rot: Vector2, fog: bool, which: String) -> void:
	var L: float = KokereiKit.battery_length(ovens) * SCALE
	if which == "all":
		# The wharf's lower yard: the ground at its foot 4.6m (life) down, the rest of the plain round it.
		var xa: float = (L / SCALE + 51.5) * SCALE
		var xb: float = (L / SCALE + 112.5) * SCALE
		var za: float = -6.0 * SCALE
		var zb: float = (KokereiKit.QUENCH_Z - KokereiKit.WHARF_TRACK_Z) * SCALE
		var ylo: float = -KokereiKit.WHARF_TRACK_Y * SCALE
		_ground_rect(-2000.0, 2000.0, -2000.0, za, 0.0)
		_ground_rect(-2000.0, 2000.0, zb, 2000.0, 0.0)
		_ground_rect(-2000.0, xa, za, zb, 0.0)
		_ground_rect(xb, 2000.0, za, zb, 0.0)
		_ground_rect(xa, xb, za, zb, ylo)
		_slab(Vector3(xa, ylo, za - 0.6), Vector3(xb - xa, -ylo, 0.6), Color(0.55, 0.54, 0.51))
	else:
		_ground_rect(-2000.0, 2000.0, -2000.0, 2000.0, 0.0)
		if which.contains("wharf"):
			pass
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.36, 0.52, 0.78)
	sm.sky_horizon_color = Color(0.80, 0.82, 0.84)
	sm.ground_bottom_color = Color(0.40, 0.39, 0.36)
	sm.ground_horizon_color = Color(0.70, 0.70, 0.68)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.75
	env.ambient_light_color = Color(0.62, 0.6, 0.56)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_hdr_threshold = 1.2
	if fog:
		env.fog_enabled = true
		env.fog_light_color = Color(0.78, 0.79, 0.80)
		env.fog_density = 0.0035
		env.fog_sky_affect = 0.2
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(sun_rot.x, sun_rot.y, 0.0)
	sun.light_energy = 1.3
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 700.0
	root.add_child(sun)


func _ground_rect(x0: float, x1: float, z0: float, z1: float, y: float) -> void:
	var gm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(x1 - x0, z1 - z0)
	gm.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.40, 0.42, 0.33)
	gmat.roughness = 1.0
	pm.material = gmat
	gm.position = Vector3((x0 + x1) * 0.5, y - 0.05, (z0 + z1) * 0.5)
	root.add_child(gm)
