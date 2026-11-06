extends SceneTree
## Look-dev for the Kronburger Hütte's set pieces (SteelworksKit.gd): builds a set in memory at SCALE 1.6 on a flat
## concrete ground under a sunny sky with shadows, waits for the shaders to compile, and saves a PNG per camera. Windowed:
##   Godot --path . --resolution 1400x850 -s res://scratch/steelworks_preview.gd -- <out_dir>
##       [set=hall|furnace|cowpers|gasometer|stacks|pipes|headframe|torpedo|gate|crown|harbour|all] [length=150]
##       [sun=<pitch>,<yaw>] [notext=1] name:x,y,z:tx,ty,tz[:fov] ...
## Positions are in game metres (life x 1.6). Each set stands at its own spot (SPOTS, game metres); with no cameras
## given it shoots that set's default views (DEFAULT_SHOTS). A 2.2m RC car box (red) and a 2.9m person stand-in (blue) stand
## by each set for scale; the hall gets a road through it, a car on it and the race camera's view.
## Prints each piece's triangle count.

const SteelworksKit = preload("res://SteelworksKit.gd")

const SCALE := 1.6

## Where each set stands (game metres) and where its scale figures go (relative to it).
const SPOTS := {
	"hall": Vector3(0, 0, 0),
	"furnace": Vector3(400, 0, 0),
	"cowpers": Vector3(400, 0, 200),
	"gasometer": Vector3(-300, 0, 0),
	"stacks": Vector3(-300, 0, 250),
	"pipes": Vector3(200, 0, 300),
	"headframe": Vector3(-600, 0, 0),
	"torpedo": Vector3(200, 0, -400),
	"gate": Vector3(0, 0, 200),
	"crown": Vector3(-600, 0, 300),
	"harbour": Vector3(700, 0, -300),
}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/steelworks"
	DirAccess.make_dir_recursive_absolute(out)
	var which := "hall"
	var length := 150.0
	var sun_rot := Vector2(-52.0, 215.0)
	var notext := false
	var shots: Array = []
	for a in args.slice(1):
		if a.begins_with("set="):
			which = a.substr(4)
		elif a.begins_with("length="):
			length = float(a.substr(7))
		elif a.begins_with("sun="):
			var sv := a.substr(4).split_floats(",")
			sun_rot = Vector2(sv[0], sv[1])
		elif a.begins_with("notext="):
			notext = a.substr(7) == "1"
		else:
			shots.append(a)
	_setup_world(sun_rot)
	var sets: Array = SPOTS.keys() if which == "all" else Array(which.split(","))
	var total := 0
	for s in sets:
		total += _build_set(s, length, notext)
	print("TOTAL triangles ", total)
	if shots.is_empty():
		for s in sets:
			shots.append_array(_default_shots(s, length))
	var cam := Camera3D.new()
	cam.near = 0.1
	cam.far = 4000.0
	root.add_child(cam)
	cam.make_current()
	for i in 40:
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


func _default_shots(s: String, length: float) -> Array:
	var o: Vector3 = SPOTS.get(s, Vector3.ZERO)
	var L: float = length * SCALE
	var list: Array = []
	match s:
		"hall":
			list = [
				["hall_entry", Vector3(-40, 22, 70), Vector3(0, 14, -20), 55.0],
				["hall_side", Vector3(95, 30, -L * 0.4), Vector3(0, 16, -L * 0.5), 60.0],
				["hall_chase", Vector3(0, 10, -86), Vector3(0, 2.5, -110), 70.0],
				["hall_chase2", Vector3(0, 10, -44), Vector3(0, 2.5, -68), 70.0],
				["hall_inside_up", Vector3(-6, 3, -40), Vector3(6, 22, -110), 70.0],
				["hall_mill", Vector3(-4, 5, -60), Vector3(16, 3, -110), 60.0],
				["hall_west", Vector3(4, 5, -70), Vector3(-18, 4, -150), 60.0],
				["hall_exit", Vector3(30, 18, -L - 60), Vector3(0, 12, -L), 55.0],
				["hall_aerial", Vector3(-110, 110, 60), Vector3(0, 10, -L * 0.5), 50.0],
			]
		"furnace":
			list = [["furnace_front", Vector3(-150, 60, 120), Vector3(0, 55, 0), 55.0], ["furnace_side", Vector3(160, 40, -90), Vector3(0, 50, 20), 55.0],
					["furnace_cast", Vector3(80, 12, 40), Vector3(30, 10, 0), 60.0]]
		"cowpers":
			list = [["cowpers", Vector3(-110, 40, 90), Vector3(10, 35, 0), 55.0]]
		"gasometer":
			list = [["gasometer", Vector3(-120, 30, 150), Vector3(0, 45, 0), 55.0], ["gasometer_top", Vector3(60, 120, 60), Vector3(0, 90, 0), 55.0]]
		"stacks":
			list = [["stacks", Vector3(-80, 40, 180), Vector3(40, 50, 0), 55.0]]
		"pipes":
			list = [["pipes", Vector3(-40, 14, 50), Vector3(0, 14, 0), 60.0]]
		"headframe":
			list = [["headframe", Vector3(-120, 40, 90), Vector3(0, 40, 40), 55.0], ["headframe_back", Vector3(110, 30, 160), Vector3(0, 35, 40), 55.0]]
		"torpedo":
			list = [["torpedo", Vector3(-22, 8, 26), Vector3(0, 3, 0), 55.0]]
		"gate":
			list = [["gate", Vector3(-12, 6, 50), Vector3(0, 8, 0), 60.0], ["gate_side", Vector3(40, 10, 20), Vector3(10, 5, 0), 55.0]]
		"crown":
			list = [["crown", Vector3(-40, 20, 45), Vector3(0, 14, 0), 55.0], ["crown_inside", Vector3(3, 15, 3), Vector3(-10, 20, -10), 75.0]]
		"harbour":
			list = [["harbour", Vector3(-90, 30, 110), Vector3(10, 10, 0), 55.0], ["barge", Vector3(70, 14, 60), Vector3(40, 3, 0), 55.0]]
	var outl: Array = []
	for sh in list:
		var p: Vector3 = (sh[1] as Vector3) + o
		var t: Vector3 = (sh[2] as Vector3) + o
		outl.append("%s:%f,%f,%f:%f,%f,%f:%f" % [sh[0], p.x, p.y, p.z, t.x, t.y, t.z, sh[3]])
	return outl


## Builds one set at its spot; returns its triangles.
func _build_set(s: String, length: float, notext: bool) -> int:
	var o: Vector3 = SPOTS.get(s, Vector3.ZERO)
	var parts: Array = []   # [name, local transform (life units), builder Callable]
	match s:
		"hall":
			parts.append(["Walzwerk", Transform3D.IDENTITY, func(pk, kit, labels): SteelworksKit.rolling_hall(pk, kit, length, labels)])
			_road(o, length)
			_scale_figures(o + Vector3(0, 0, -100), true)
			_scale_figures(o + Vector3(0, 0, 30), false)
		"furnace":
			parts.append(["Hochofen", Transform3D.IDENTITY, func(pk, kit, labels): SteelworksKit.blast_furnace(pk, kit, labels)])
			_scale_figures(o + Vector3(-20, 0, 40), false)
		"cowpers":
			parts.append(["Cowper", Transform3D.IDENTITY, func(pk, kit, _labels): SteelworksKit.cowpers(pk, kit, 4)])
			_scale_figures(o + Vector3(-20, 0, 20), false)
		"gasometer":
			parts.append(["Gasometer", Transform3D.IDENTITY, func(pk, kit, labels): SteelworksKit.gasometer(pk, kit, labels)])
			_scale_figures(o + Vector3(-45, 0, 30), false)
		"stacks":
			parts.append(["Chimney0", Transform3D(Basis(), Vector3(0, 0, 0)), func(pk, kit, _labels): SteelworksKit.chimney(pk, kit, 70.0, 0)])
			parts.append(["Chimney1", Transform3D(Basis(), Vector3(25, 0, 0)), func(pk, kit, _labels): SteelworksKit.chimney(pk, kit, 60.0, 1)])
			parts.append(["CoolingTower", Transform3D(Basis(), Vector3(70, 0, -10)), func(pk, kit, _labels): SteelworksKit.cooling_tower(pk, kit)])
			_scale_figures(o + Vector3(-12, 0, 20), false)
		"pipes":
			parts.append(["PipeBridge", Transform3D.IDENTITY, func(pk, kit, _labels): SteelworksKit.pipe_bridge(pk, kit, 22.0, 11.0, 4)])
			parts.append(["PipeRun", Transform3D.IDENTITY, func(pk, kit, _labels): SteelworksKit.pipe_run(pk, kit,
					PackedVector3Array([Vector3(-30, 1.5, 10), Vector3(-30, 1.5, -5), Vector3(-45, 1.5, -5), Vector3(-45, 5.0, -20)]), 0.6)])
			_road(o, 40.0, Vector3(0, 0, 30))
			_scale_figures(o + Vector3(0, 0, 8), true)
		"headframe":
			parts.append(["Headframe", Transform3D.IDENTITY, func(pk, kit, labels): SteelworksKit.headframe(pk, kit, labels)])
			_scale_figures(o + Vector3(-25, 0, -10), false)
		"torpedo":
			parts.append(["Torpedo", Transform3D.IDENTITY, func(pk, kit, _labels): SteelworksKit.torpedo_car(pk, kit)])
			_scale_figures(o + Vector3(-6, 0, 8), false)
		"gate":
			parts.append(["Werkstor", Transform3D.IDENTITY, func(pk, kit, labels): SteelworksKit.works_gate(pk, kit, labels)])
			_road(o, 60.0, Vector3(0, 0, 50))
			_scale_figures(o + Vector3(0, 0, 14), true)
		"crown":
			parts.append(["Krone", Transform3D.IDENTITY, func(pk, kit, _labels): SteelworksKit.steel_crown(pk, kit)])
			_scale_figures(o + Vector3(-22, 0, 15), false)
		"harbour":
			parts.append(["OreCrane", Transform3D.IDENTITY, func(pk, kit, _labels): SteelworksKit.ore_crane(pk, kit)])
			parts.append(["Barge", Transform3D(Basis(), Vector3(26, 0, -10)), func(pk, kit, labels): SteelworksKit.barge(pk, kit, 85.0, labels)])
			parts.append(["Ore", Transform3D(Basis(), Vector3(-38, 0, 0)), func(pk, kit, _labels): SteelworksKit.stockpile(pk, kit)])
			_water(o + Vector3(28, 0, 0))
			_scale_figures(o + Vector3(-12, 0, 20), false)
	var tris := 0
	for part in parts:
		var pk = SteelworksKit.new_kit(SCALE)
		var kit := {}
		var labels: Array = []
		var t0 := Time.get_ticks_msec()
		(part[2] as Callable).call(pk, kit, labels)
		var mesh: ArrayMesh = SteelworksKit.commit(pk, kit)
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


## An asphalt strip along -z from `o` (the hall's road), 8.8m (life) wide, and beyond both ends.
func _road(o: Vector3, length: float, ext := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	var L: float = length * SCALE + 120.0
	pm.size = Vector2(8.8 * SCALE, L)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.16, 0.17)
	m.roughness = 0.9
	pm.material = m
	mi.position = o + Vector3(0, 0.03 * SCALE, -length * SCALE * 0.5) + ext
	root.add_child(mi)
	for sx in [-1.0, 1.0]:
		var line := MeshInstance3D.new()
		var lm := PlaneMesh.new()
		lm.size = Vector2(0.2, L)
		line.mesh = lm
		var mm := StandardMaterial3D.new()
		mm.albedo_color = Color(0.9, 0.9, 0.85)
		lm.material = mm
		line.position = o + Vector3(sx * 4.0 * SCALE, 0.03 * SCALE + 0.01, -length * SCALE * 0.5) + ext
		root.add_child(line)


func _water(o: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 400)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.12, 0.2, 0.22)
	m.roughness = 0.08
	m.metallic = 0.3
	pm.material = m
	mi.position = o + Vector3(100, 0.0, 0)
	root.add_child(mi)


## A 2.2m RC car (a red box on four wheels) and a 2.9m person stand-in (a blue capsule) at `p`.
func _scale_figures(p: Vector3, on_road: bool) -> void:
	var car := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.2, 0.7, 2.2)
	car.mesh = bm
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.85, 0.1, 0.08)
	bm.material = cm
	car.position = p + Vector3(0, 0.6 + (0.05 if on_road else 0.0), 0)
	root.add_child(car)
	var man := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 2.9
	man.mesh = cap
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.15, 0.3, 0.85)
	cap.material = mm
	man.position = p + Vector3(5.5 if on_road else 2.5, 1.45, 0)
	root.add_child(man)


func _setup_world(sun_rot: Vector2) -> void:
	var gm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(4000, 4000)
	gm.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.48, 0.47, 0.44)
	gmat.roughness = 1.0
	pm.material = gmat
	gm.position = Vector3(0, -0.05, 0)
	root.add_child(gm)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.30, 0.50, 0.82)
	sm.sky_horizon_color = Color(0.78, 0.83, 0.88)
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
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(sun_rot.x, sun_rot.y, 0.0)
	sun.light_energy = 1.3
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 600.0
	root.add_child(sun)
