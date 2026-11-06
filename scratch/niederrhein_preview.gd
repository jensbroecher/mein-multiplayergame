extends SceneTree
## Look-dev for Rheinufer's west bank (NiederrheinKit.gd, SheepFlock.gd): builds a set in memory at SCALE 1.6 on a flat
## meadow (with a collider, so the sheep stand on it) under a low early-evening sun from the west-south-west, waits for the
## shaders to compile and saves a PNG per camera. Windowed:
##   Godot --path . --resolution 1400x850 -s res://scratch/niederrhein_preview.gd -- <out_dir>
##       [set=windmill|farm|power|misc|sheep|all] [spin=<deg>] [sun=<pitch>,<yaw>] [notext=1] [clock=<s>] [wait=<frames>]
##       name:x,y,z:tx,ty,tz[:fov] ...
## Positions are in game metres (life x 1.6). Each set stands at its own spot (SPOTS); with no cameras given it shoots the
## set's default views. A 2.2m RC car box (red) and a 2.9m person stand-in (blue) stand by each set for scale. Prints each
## piece's triangles. `spin` turns the sails; `clock` sets the sheep's clock_offset (seconds) so a crossing can be shot.

const NiederrheinKit = preload("res://NiederrheinKit.gd")
const SteelworksKit = preload("res://SteelworksKit.gd")

const SCALE := 1.6

const SPOTS := {
	"windmill": Vector3(0, 0, 0),
	"farm": Vector3(300, 0, 0),
	"misc": Vector3(-300, 0, 0),
	"sheep": Vector3(0, 0, 300),
	"power": Vector3(0, 0, -1600),
}

var _spin := 20.0
var _clock := NAN


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/niederrhein"
	DirAccess.make_dir_recursive_absolute(out)
	var which := "windmill"
	var sun_rot := Vector2(-24.0, 248.0)
	var notext := false
	var wait := 40
	var shots: Array = []
	for a in args.slice(1):
		if a.begins_with("set="):
			which = a.substr(4)
		elif a.begins_with("spin="):
			_spin = float(a.substr(5))
		elif a.begins_with("sun="):
			var sv := a.substr(4).split_floats(",")
			sun_rot = Vector2(sv[0], sv[1])
		elif a.begins_with("notext="):
			notext = a.substr(7) == "1"
		elif a.begins_with("clock="):
			_clock = float(a.substr(6))
		elif a.begins_with("wait="):
			wait = int(a.substr(5))
		else:
			shots.append(a)
	_setup_world(sun_rot)
	var sets: Array = SPOTS.keys() if which == "all" else Array(which.split(","))
	var total := 0
	for s in sets:
		total += _build_set(s, notext)
	print("TOTAL triangles ", total)
	if shots.is_empty():
		for s in sets:
			shots.append_array(_default_shots(s))
	var cam := Camera3D.new()
	cam.near = 0.1
	cam.far = 5000.0
	root.add_child(cam)
	cam.make_current()
	for i in wait:
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


func _default_shots(s: String) -> Array:
	var o: Vector3 = SPOTS.get(s, Vector3.ZERO)
	var list: Array = []
	match s:
		"windmill":
			list = [["mill_front", Vector3(-30, 8, 70), Vector3(0, 22, 0), 55.0], ["mill_back", Vector3(45, 14, -60), Vector3(0, 20, 0), 55.0],
					["mill_low", Vector3(14, 2.5, 26), Vector3(0, 12, 0), 70.0], ["mill_far", Vector3(-160, 12, 180), Vector3(0, 20, 0), 40.0],
					["mill_stage", Vector3(-12, 12.5, 12), Vector3(0, 13, -2), 65.0]]
		"farm":
			list = [["farm_front", Vector3(-20, 6, 50), Vector3(12, 7, -10), 60.0], ["farm_back", Vector3(60, 14, -90), Vector3(10, 6, -20), 55.0],
					["farm_door", Vector3(11, 3, 18), Vector3(11, 5, 0), 60.0], ["farm_far", Vector3(-150, 20, 160), Vector3(10, 5, -20), 40.0],
					["farm_shed", Vector3(-26, 4, 6), Vector3(-26, 3, -18), 65.0], ["barn_side", Vector3(50, 5, 40), Vector3(54, 5, 0), 60.0],
					["barn_gable", Vector3(8, 6, 4), Vector3(38, 7, 0), 60.0], ["farm_roof", Vector3(-10, 22, 30), Vector3(11, 10, -15), 60.0]]
		"misc":
			list = [["misc_all", Vector3(-4, 12, 40), Vector3(0, 1, -6), 60.0], ["misc_cart", Vector3(-7, 3, 9), Vector3(0, 2.6, 0), 60.0],
					["misc_tractor", Vector3(-16, 3, 6), Vector3(-10, 1.8, -8), 55.0], ["misc_wagon", Vector3(36, 5, -2), Vector3(22, 2.5, -13), 55.0],
					["misc_gate", Vector3(10, 2.5, 16), Vector3(10, 1, 6), 60.0], ["misc_bales", Vector3(14, 3, 2), Vector3(12, 1, -12), 55.0],
					["misc_cart_back", Vector3(4, 2.5, -9), Vector3(0, 2.4, 0), 60.0], ["misc_tractor2", Vector3(-26, 2.5, -10), Vector3(-19, 1.5, -19), 55.0]]
		"sheep":
			list = [["sheep_road", Vector3(10, 4, 34), Vector3(-10, 1, 0), 55.0], ["sheep_high", Vector3(0, 40, 80), Vector3(0, 0, 0), 55.0],
					["sheep_close", Vector3(-30, 2.5, 22), Vector3(-42, 1, 6), 55.0]]
		"power":
			list = [["power_far", Vector3(-700, 40, 1300), Vector3(-40, 90, 0), 40.0], ["power_mid", Vector3(-500, 30, 650), Vector3(-60, 70, 0), 50.0],
					["power_east", Vector3(1300, 30, 600), Vector3(100, 90, 60), 40.0], ["power_close", Vector3(-150, 20, 330), Vector3(-30, 50, 40), 60.0],
					["power_south", Vector3(200, 40, -700), Vector3(0, 80, -100), 45.0], ["power_yard", Vector3(-520, 25, 130), Vector3(-380, 10, 30), 55.0]]
	var outl: Array = []
	for sh in list:
		var p: Vector3 = (sh[1] as Vector3) + o
		var t: Vector3 = (sh[2] as Vector3) + o
		outl.append("%s:%f,%f,%f:%f,%f,%f:%f" % [sh[0], p.x, p.y, p.z, t.x, t.y, t.z, sh[3]])
	return outl


## Builds one set at its spot; returns its triangles.
func _build_set(s: String, notext: bool) -> int:
	var o: Vector3 = SPOTS.get(s, Vector3.ZERO)
	var parts: Array = []   # [name, local transform (life units), builder Callable]
	match s:
		"windmill":
			parts.append(["Windmill", Transform3D.IDENTITY, func(pk, kit, labels): NiederrheinKit.tower_windmill(pk, kit, labels)])
			var sx: Transform3D = NiederrheinKit.mill_sails_transform()
			sx = sx * Transform3D(Basis(Vector3.BACK, deg_to_rad(_spin)), Vector3.ZERO)
			parts.append(["Sails", sx, func(pk, kit, _labels): NiederrheinKit.windmill_sails(pk, kit)])
			_scale_figures(o + Vector3(14, 0, 14), false)
		"farm":
			parts.append(["Hallenhaus", Transform3D.IDENTITY, func(pk, kit, labels): NiederrheinKit.farmhouse(pk, kit, labels, 0)])
			parts.append(["Barn", Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(24, 0, -6)), func(pk, kit, labels): NiederrheinKit.farmhouse(pk, kit, labels, 1)])
			parts.append(["CartShed", Transform3D(Basis(), Vector3(-22, 0, -12)), func(pk, kit, labels): NiederrheinKit.farmhouse(pk, kit, labels, 2)])
			_scale_figures(o + Vector3(8, 0, 14), false)
		"misc":
			parts.append(["ShepherdCart", Transform3D(Basis(Vector3.UP, 0.5), Vector3(0, 0, 0)), func(pk, kit, labels): NiederrheinKit.shepherd_cart(pk, kit, labels)])
			parts.append(["Bales", Transform3D(Basis(), Vector3(6, 0, -6)), func(pk, kit, _labels):
				var rng := RandomNumberGenerator.new()
				rng.seed = 3
				NiederrheinKit.silage_bales(pk, kit, rng, 7)])
			parts.append(["BalesGreen", Transform3D(Basis(Vector3.UP, 0.3), Vector3(6, 0, -10)), func(pk, kit, _labels):
				var rng := RandomNumberGenerator.new()
				rng.seed = 6
				NiederrheinKit.silage_bales(pk, kit, rng, 4)])
			parts.append(["Fence", Transform3D.IDENTITY, func(pk, kit, _labels): NiederrheinKit.paddock_fence(pk, kit,
					PackedVector3Array([Vector3(-12, 0, 6), Vector3(-2, 0, 6), Vector3(4, 0, 4)]))])
			parts.append(["FenceB", Transform3D.IDENTITY, func(pk, kit, _labels): NiederrheinKit.paddock_fence(pk, kit,
					PackedVector3Array([Vector3(8.3, 0, 4), Vector3(18, 0, 4), Vector3(22, 0, -2)]))])
			parts.append(["Gate", Transform3D(Basis(Vector3.UP, -atan2(0.0, 1.0)), Vector3(4, 0, 4)), func(pk, kit, _labels): NiederrheinKit.field_gate(pk, kit)])
			parts.append(["TractorGreen", Transform3D(Basis(Vector3.UP, 2.4), Vector3(-6, 0, -4)), func(pk, kit, _labels): NiederrheinKit.tractor(pk, kit, 0)])
			parts.append(["TractorRed", Transform3D(Basis(Vector3.UP, -0.6), Vector3(-12, 0, -12)), func(pk, kit, _labels): NiederrheinKit.tractor(pk, kit, 1)])
			parts.append(["HayWagon", Transform3D(Basis(Vector3.UP, 1.2), Vector3(14, 0, -8)), func(pk, kit, _labels): NiederrheinKit.hay_wagon(pk, kit)])
			_scale_figures(o + Vector3(2, 0, 16), false)
		"power":
			parts.append(["PowerStation", Transform3D.IDENTITY, func(pk, kit, labels): NiederrheinKit.power_station(pk, kit, labels)])
			parts.append(["Chimney", Transform3D(Basis(), NiederrheinKit.POWER_CHIMNEY_AT), func(pk, kit, _labels): SteelworksKit.chimney(pk, kit, NiederrheinKit.POWER_CHIMNEY_H, 1)])
			for k in range(2):
				var tw: Vector3 = NiederrheinKit.POWER_TOWERS[k]
				parts.append(["CoolingTower%d" % k, Transform3D(Basis.from_scale(Vector3.ONE * NiederrheinKit.POWER_TOWER_SCALE), tw), func(pk, kit, _labels): SteelworksKit.cooling_tower(pk, kit)])
			_scale_figures(o + Vector3(0, 0, 200), false)
		"sheep":
			# A flock grazing either side of a farm road along z (game metres), with the shepherd's cart and a gate; `clock=`
			# picks the moment (seconds; 0 = the gather before a crossing begins, 26 the walk across).
			_road(o + Vector3(0, 0, -200), o + Vector3(0, 0, 200), 7.0)
			var flock := Node3D.new()
			flock.name = "SheepFlock"
			flock.set_script(load("res://SheepFlock.gd"))
			flock.position = o
			flock.set("clock_override", (220.0 + (_clock if not is_nan(_clock) else -20.0)))
			root.add_child(flock)
			parts.append(["ShepherdCart", Transform3D(Basis(Vector3.UP, 1.2), Vector3(-30, 0, 14)), func(pk, kit, labels): NiederrheinKit.shepherd_cart(pk, kit, labels)])
			parts.append(["Fence", Transform3D.IDENTITY, func(pk, kit, _labels): NiederrheinKit.paddock_fence(pk, kit,
					PackedVector3Array([Vector3(-3.5, 0, -30), Vector3(-3.5, 0, -6), Vector3(-6, 0, -6)]))])
			_scale_figures(o + Vector3(4, 0, 20), true)
	return _build_parts(parts, o, notext)


func _build_parts(parts: Array, o: Vector3, notext: bool) -> int:
	var tris := 0
	for part in parts:
		var pk = NiederrheinKit.new_kit(SCALE)
		var kit := {}
		var labels: Array = []
		var t0 := Time.get_ticks_msec()
		(part[2] as Callable).call(pk, kit, labels)
		var mesh: ArrayMesh = NiederrheinKit.commit(pk, kit)
		var mi := MeshInstance3D.new()
		mi.name = part[0]
		mi.mesh = mesh
		var lt: Transform3D = part[1]
		mi.transform = Transform3D(lt.basis, o + lt.origin * SCALE)
		if lt.basis.get_scale().x > 1.01:
			# A part grown on top of the kit's scale (the cooling towers): its own kit at the bigger scale.
			pk = NiederrheinKit.new_kit(SCALE * lt.basis.get_scale().x)
			kit = {}
			labels = []
			(part[2] as Callable).call(pk, kit, labels)
			mesh = NiederrheinKit.commit(pk, kit)
			mi.mesh = mesh
			mi.transform = Transform3D(Basis(), o + lt.origin * SCALE)
		root.add_child(mi)
		var t := _tris(mesh)
		print("%s: %d triangles, %d surfaces, aabb %s (%d ms)" % [part[0], t, mesh.get_surface_count(), mesh.get_aabb(), Time.get_ticks_msec() - t0])
		tris += t
		if not notext:
			for l in labels:
				_label(l, mi.transform)
	return tris


static func _tris(mesh: Mesh) -> int:
	var t := 0
	for k in mesh.get_surface_count():
		var idx = mesh.surface_get_arrays(k)[Mesh.ARRAY_INDEX]
		t += int((idx as PackedInt32Array).size() / 3.0) if idx != null else int((mesh.surface_get_arrays(k)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3.0)
	return t


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
	var basis := Basis.looking_at(-n, Vector3.UP if absf(n.normalized().y) < 0.95 else Vector3.BACK)
	lab.transform = Transform3D(basis, xf * ((l[1] as Vector3) * SCALE))
	if l.size() > 5 and float(l[5]) > 0.0:
		var font: Font = ThemeDB.fallback_font
		var w: float = font.get_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x * lab.pixel_size
		var max_w: float = float(l[5]) * SCALE
		if w > max_w:
			lab.pixel_size *= max_w / w
	root.add_child(lab)


## An asphalt strip from `a` to `b` (game metres), 7m wide: the dyke road or a farm lane.
func _road(a: Vector3, b: Vector3, width := 7.0) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(width, a.distance_to(b))
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.16, 0.17)
	m.roughness = 0.9
	pm.material = m
	var dir: Vector3 = (b - a).normalized()
	mi.transform = Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z)), (a + b) * 0.5 + Vector3(0, 0.04, 0))
	root.add_child(mi)


## A 2.2m RC car (a red box) and a 2.9m person stand-in (a blue capsule) at `p`.
func _scale_figures(p: Vector3, on_road: bool) -> void:
	var car := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.2, 0.7, 2.2)
	car.mesh = bm
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.85, 0.1, 0.08)
	bm.material = cm
	car.position = p + Vector3(0, 0.4 + (0.05 if on_road else 0.0), 0)
	root.add_child(car)
	var man := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 2.9
	man.mesh = cap
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.15, 0.3, 0.85)
	cap.material = mm
	man.position = p + Vector3(2.5, 1.45, 0)
	root.add_child(man)


func _setup_world(sun_rot: Vector2) -> void:
	var gm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6000, 6000)
	gm.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_texture = load("res://materials/grass.png")
	gmat.uv1_scale = Vector3(600, 600, 1)
	gmat.albedo_color = Color(0.72, 0.74, 0.62)
	gmat.roughness = 1.0
	pm.material = gmat
	gm.position = Vector3(0, -0.02, 0)
	root.add_child(gm)
	# A collider for the ground, so SheepFlock's rays find it.
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6000, 2, 6000)
	cs.shape = box
	cs.position = Vector3(0, -1.0, 0)
	body.add_child(cs)
	root.add_child(body)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.32, 0.50, 0.80)
	sm.sky_horizon_color = Color(0.86, 0.82, 0.74)
	sm.ground_bottom_color = Color(0.30, 0.32, 0.24)
	sm.ground_horizon_color = Color(0.70, 0.70, 0.62)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.75
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.80, 0.80, 0.78)
	env.fog_depth_begin = 600.0
	env.fog_depth_end = 5000.0
	env.fog_density = 0.4
	env.fog_sky_affect = 0.0
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
