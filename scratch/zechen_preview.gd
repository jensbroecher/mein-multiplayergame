extends SceneTree
## Look-dev for Zeche Kronprinz's colliery kit (ZechenKit.gd): builds a set in memory at SCALE 1.6 on a flat ground under a
## low morning sun with shadows, waits for the shaders to compile, and saves a PNG per camera. Windowed:
##   Godot --path . --resolution 1400x850 -s res://scratch/zechen_preview.gd -- <out_dir>
##       [set=malakoff|headframe|houses|washer|gallery|bunker|carts|landmark|misc|plants|all] [sun=<pitch>,<yaw>] [notext=1]
##       [save=<dir>] name:x,y,z:tx,ty,tz[:fov] ...
## Positions are in game metres (life x 1.6). Each set stands at its own spot (SPOTS, game metres); with no cameras given it
## shoots that set's default views (relative to the spot). A 2.2m RC car box (red) and a 2.9m person stand-in (blue) stand
## by each set for scale; the washer gets the lap's road through its passage, a car in it and the race's views through it.
## Prints each piece's triangle count; `save=<dir>` also saves each piece's mesh as <dir>/<name>.res (for zfight_scan).

const ZK = preload("res://ZechenKit.gd")

const SCALE := 1.6

const SPOTS := {
	"malakoff": Vector3(0, 0, 0),
	"headframe": Vector3(300, 0, 0),
	"houses": Vector3(-400, 0, 0),
	"washer": Vector3(0, 0, 400),
	"gallery": Vector3(400, 0, 400),
	"bunker": Vector3(-400, 0, 400),
	"carts": Vector3(200, 0, -300),
	"landmark": Vector3(-300, 0, -350),
	"misc": Vector3(0, 0, -400),
	"plants": Vector3(400, 0, -350),
}

var save_dir := ""


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/zechen"
	DirAccess.make_dir_recursive_absolute(out)
	var which := "malakoff"
	var sun_rot := Vector2(-16.0, 95.0)
	var notext := false
	var shots: Array = []
	for a in args.slice(1):
		if a.begins_with("set="):
			which = a.substr(4)
		elif a.begins_with("sun="):
			var sv := a.substr(4).split_floats(",")
			sun_rot = Vector2(sv[0], sv[1])
		elif a.begins_with("notext="):
			notext = a.substr(7) == "1"
		elif a.begins_with("save="):
			save_dir = a.substr(5)
			DirAccess.make_dir_recursive_absolute(save_dir)
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


func _default_shots(s: String) -> Array:
	var o: Vector3 = SPOTS.get(s, Vector3.ZERO)
	var list: Array = []
	match s:
		"malakoff":
			list = [["malakoff_front", Vector3(-34, 12, 70), Vector3(0, 24, 0), 55.0], ["malakoff_race", Vector3(10, 4, 42), Vector3(0, 20, 0), 65.0],
					["malakoff_back", Vector3(48, 30, -66), Vector3(0, 26, 0), 55.0], ["malakoff_far", Vector3(-170, 45, 230), Vector3(0, 26, 0), 40.0],
					["malakoff_top", Vector3(-30, 70, 30), Vector3(0, 46, 0), 55.0]]
		"headframe":
			list = [["headframe_side", Vector3(150, 40, 40), Vector3(0, 50, 0), 55.0], ["headframe_front", Vector3(40, 22, 120), Vector3(0, 50, 0), 55.0],
					["headframe_race", Vector3(36, 4, 55), Vector3(0, 40, 0), 70.0], ["headframe_top", Vector3(26, 102, 30), Vector3(0, 92, 0), 55.0],
					["headframe_far", Vector3(320, 70, 200), Vector3(0, 50, 0), 35.0]]
		"houses":
			list = [["wh0_front", Vector3(-34, 12, 70), Vector3(0, 13, 15), 55.0], ["wh0_back", Vector3(40, 18, -80), Vector3(0, 14, -10), 55.0],
					["wh1", Vector3(95, 10, 50), Vector3(70, 12, 0), 55.0], ["lohnhalle", Vector3(-30, 14, 260), Vector3(32, 16, 144), 55.0],
					["lohnhalle_portal", Vector3(40, 5, 196), Vector3(32, 14, 160), 60.0], ["lohnhalle_back", Vector3(120, 40, 40), Vector3(32, 18, 144), 50.0]]
		"washer":
			list = [["washer_approach", Vector3(4, 10, 80), Vector3(0, 6, 0), 70.0], ["washer_inside", Vector3(0, 6.5, 22), Vector3(0, 9, -24), 72.0],
					["washer_ceiling", Vector3(3, 4, 10), Vector3(0, 13.5, -14), 75.0], ["washer_ext", Vector3(-80, 34, 90), Vector3(0, 24, 0), 55.0],
					["washer_back", Vector3(90, 40, -80), Vector3(0, 24, 0), 55.0], ["washer_far", Vector3(220, 70, 300), Vector3(0, 28, 0), 35.0]]
		"gallery":
			list = [["gallery", Vector3(-30, 20, 70), Vector3(40, 18, 25), 55.0], ["gallery_under", Vector3(50, 3, 40), Vector3(40, 22, 0), 65.0],
					["gallery_steep", Vector3(-60, 30, 40), Vector3(-40, 22, -32), 55.0]]
		"bunker":
			list = [["bunker", Vector3(-55, 20, 70), Vector3(0, 18, 0), 55.0], ["bunker_track", Vector3(2, 5, 50), Vector3(0, 9, 0), 70.0],
					["bunker_end", Vector3(25, 22, -75), Vector3(0, 24, -20), 55.0]]
		"carts":
			list = [["carts", Vector3(5, 3.5, 32), Vector3(0, 1, 12), 50.0], ["carts_close", Vector3(3.5, 2.2, 6), Vector3(0, 1, 2), 55.0]]
		"landmark":
			list = [["landmark", Vector3(-45, 22, 60), Vector3(0, 26, 0), 55.0], ["landmark_race", Vector3(18, 3.5, 32), Vector3(0, 26, 0), 70.0],
					["landmark_deck", Vector3(4, 38, 6), Vector3(-2, 44, -8), 70.0], ["landmark_far", Vector3(-160, 50, 180), Vector3(0, 28, 0), 35.0]]
		"misc":
			list = [["misc", Vector3(-10, 8, 30), Vector3(14, 6, 0), 55.0], ["misc_board", Vector3(-12, 3.5, 9), Vector3(-12, 3.2, 0), 50.0],
					["misc_mast", Vector3(36, 20, 30), Vector3(24, 24, 0), 55.0]]
		"plants":
			list = [["plants", Vector3(0, 4, 14), Vector3(0, 2, 0), 50.0], ["plants_close", Vector3(-2, 2.6, 5), Vector3(-2.5, 2.4, 0), 55.0],
					["plants_far", Vector3(0, 10, 40), Vector3(0, 2, 0), 45.0]]
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
		"malakoff":
			parts.append(["Malakoff", Transform3D.IDENTITY, func(pk, kit, labels): ZK.malakoff_tower(pk, kit, labels)])
			_scale_figures(o + Vector3(-6, 0, 24), false)
		"headframe":
			parts.append(["Headframe", Transform3D.IDENTITY, func(pk, kit, labels): ZK.headframe(pk, kit, labels)])
			var hubs: Array = ZK.headframe_sheave_hubs()
			for i in hubs.size():
				parts.append(["Sheave%d" % i, Transform3D(Basis(Vector3.RIGHT, 0.3 * i), hubs[i]), func(pk, kit, _labels): ZK.headframe_sheave(pk, kit)])
			_scale_figures(o + Vector3(-8, 0, 30), false)
		"houses":
			parts.append(["WindingHouse0", Transform3D.IDENTITY, func(pk, kit, labels): ZK.winding_house(pk, kit, labels, 0)])
			parts.append(["WindingHouse1", Transform3D(Basis(), Vector3(44, 0, 0)), func(pk, kit, labels): ZK.winding_house(pk, kit, labels, 1)])
			parts.append(["Lohnhalle", Transform3D(Basis(), Vector3(20, 0, 90)), func(pk, kit, labels): ZK.lohnhalle(pk, kit, labels)])
			_scale_figures(o + Vector3(-6, 0, 30), false)
			_scale_figures(o + Vector3(32, 0, 172), false)
		"washer":
			parts.append(["CoalWasher", Transform3D.IDENTITY, func(pk, kit, labels): ZK.coal_washer(pk, kit, labels)])
			_road(o, 8.8 * SCALE, 200.0)
			_clearance_box(o)
			_scale_figures(o + Vector3(0, 0, 0), true)
			_scale_figures(o + Vector3(-1.5, 0, 40), true)
		"gallery":
			var fy := func(p: Vector3) -> float: return 0.0
			parts.append(["Gallery", Transform3D.IDENTITY, func(pk, kit, _labels): ZK.conveyor_gallery(pk, kit, Vector3(0, 3, 0), Vector3(58, 21, 34), 3.2, fy)])
			parts.append(["GallerySteep", Transform3D.IDENTITY, func(pk, kit, _labels): ZK.conveyor_gallery(pk, kit, Vector3(0, 3, -20), Vector3(-52, 27.2, -20), 3.2, fy)])
			_scale_figures(o + Vector3(40, 0, 20), false)
		"bunker":
			parts.append(["Bunker", Transform3D.IDENTITY, func(pk, kit, labels): ZK.coal_bunker(pk, kit, labels)])
			_road(o, 1.5 * SCALE, 160.0, Color(0.25, 0.23, 0.22))
			_wagon(o)
			_scale_figures(o + Vector3(-12, 0, 38), false)
		"carts":
			parts.append(["Track", Transform3D.IDENTITY, func(pk, kit, _labels): ZK.narrow_gauge(pk, kit, 14.0)])
			for i in 4:
				var v: int = [0, 1, 2, 0][i]
				parts.append(["Cart%d" % i, Transform3D(Basis(), Vector3(0, ZK.NG_RAIL_TOP, 1.5 + 2.4 * i)), func(pk, kit, _labels): ZK.mine_cart(pk, kit, v)])
			_scale_figures(o + Vector3(-4, 0, 6), false)
		"landmark":
			parts.append(["Kronprinzenblick", Transform3D.IDENTITY, func(pk, kit, labels): ZK.summit_landmark(pk, kit, labels, false)])
			parts.append(["SummitWheel", Transform3D(Basis(Vector3.RIGHT, 0.2), ZK.summit_wheel_hub()), func(pk, kit, _labels): ZK.summit_wheel(pk, kit)])
			_scale_figures(o + Vector3(-6, 0, 20), false)
		"misc":
			parts.append(["Fence", Transform3D(Basis(), Vector3(0, 0, -6)), func(pk, kit, _labels): ZK.industrial_fence(pk, kit, 30.0)])
			parts.append(["Mast", Transform3D(Basis(), Vector3(15, 0, -3)), func(pk, kit, _labels): ZK.floodlight_mast(pk, kit, false)])
			parts.append(["Board", Transform3D(Basis(), Vector3(-7.5, 0, 0)), func(pk, kit, labels): ZK.plaque_board(pk, kit, labels,
					"ZECHE KRONPRINZ · SCHACHT I\nDer Malakoffturm wurde 1871 über Schacht I errichtet.\nSeine Mauern sind bis zu 2,5 m stark.\nBis 1986 wurde hier Steinkohle gefördert.")])
			parts.append(["Skip", Transform3D(Basis(), Vector3(4, 0, 2)), func(pk, kit, _labels): ZK.rust_skip(pk, kit)])
			parts.append(["Drum", Transform3D(Basis(), Vector3(9, 0, 3)), func(pk, kit, _labels): ZK.cable_drum(pk, kit)])
			_scale_figures(o + Vector3(-3, 0, 6), false)
		"plants":
			var mi_tris := 0
			for i in 6:
				var m: ArrayMesh = ZK.buddleia_mesh(100 + i)
				mi_tris += _place_mesh("Buddleia%d" % i, m, o + Vector3(-10.0 + 4.0 * i, 0, -3), 0.7 * i)
			for i in 10:
				var m2: ArrayMesh = ZK.goldenrod_mesh(200 + i)
				mi_tris += _place_mesh("Goldenrod%d" % i, m2, o + Vector3(-11.0 + 2.4 * i, 0, 3.0 + (i % 2) * 1.6), 1.1 * i)
			_scale_figures(o + Vector3(8, 0, 6), false)
			return mi_tris
	var tris := 0
	for part in parts:
		var pk = ZK.new_kit(SCALE)
		var kit := {}
		var labels: Array = []
		var t0 := Time.get_ticks_msec()
		(part[2] as Callable).call(pk, kit, labels)
		var mesh: ArrayMesh = ZK.commit(pk, kit)
		var mi := MeshInstance3D.new()
		mi.name = part[0]
		mi.mesh = mesh
		var lt: Transform3D = part[1]
		mi.transform = Transform3D(lt.basis, o + lt.origin * SCALE)
		root.add_child(mi)
		var t := _tris(mesh)
		print("%s: %d triangles, %d surfaces, aabb %s (%d ms)" % [part[0], t, mesh.get_surface_count(), mesh.get_aabb(), Time.get_ticks_msec() - t0])
		tris += t
		if save_dir != "":
			ResourceSaver.save(mesh, "%s/%s.res" % [save_dir, part[0]])
		if not notext:
			for l in labels:
				_label(l, mi.transform)
	return tris


func _tris(mesh: ArrayMesh) -> int:
	var t := 0
	for k in mesh.get_surface_count():
		var arr: Array = mesh.surface_get_arrays(k)
		var idx = arr[Mesh.ARRAY_INDEX]
		t += int((idx as PackedInt32Array).size() / 3.0) if idx != null else int((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3.0)
	return t


func _place_mesh(n: String, m: ArrayMesh, p: Vector3, yaw: float) -> int:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = m
	mi.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * SCALE), p)
	root.add_child(mi)
	var t := _tris(m)
	print("%s: %d triangles, aabb %s" % [n, t, m.get_aabb()])
	if save_dir != "":
		ResourceSaver.save(m, "%s/%s.res" % [save_dir, n])
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
	var basis := Basis.looking_at(-n, Vector3.UP if absf(n.y) < 0.95 else Vector3.BACK)
	lab.transform = Transform3D(basis, xf * ((l[1] as Vector3) * SCALE))
	if l.size() > 5 and float(l[5]) > 0.0:
		var font: Font = ThemeDB.fallback_font
		var w: float = font.get_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x * lab.pixel_size
		var max_w: float = float(l[5]) * SCALE
		if w > max_w:
			lab.pixel_size *= max_w / w
	root.add_child(lab)


## A strip (a road, a track bed) along z through `o`, `w` wide (game metres), `len` long.
func _road(o: Vector3, w: float, length: float, col := Color(0.16, 0.16, 0.17)) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(w, length)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
	pm.material = m
	mi.position = o + Vector3(0, 0.03, 0)
	root.add_child(mi)


## A translucent box showing the washer's promised clear passage (|x| <= 7.5, y <= 7.0 life) for the shots.
func _clearance_box(o: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(15.0, 7.0, 34.0) * SCALE
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.1, 0.9, 0.3, 0.06)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	bm.material = m
	mi.position = o + Vector3(0, 3.5 * SCALE, 0)
	mi.visible = OS.get_environment("ZK_CLEAR") == "1"
	root.add_child(mi)


## A wagon stand-in on the bunker's track (life 2.9 wide, 4.0 tall: inside the 2.6/5.6 clearance).
func _wagon(o: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.9, 4.0, 12.0) * SCALE
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.35, 0.2, 0.15)
	bm.material = m
	mi.position = o + Vector3(0, 2.0 * SCALE + 0.4, 4.0)
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
	gmat.albedo_color = Color(0.40, 0.42, 0.33)
	gmat.roughness = 1.0
	pm.material = gmat
	gm.position = Vector3(0, -0.05, 0)
	root.add_child(gm)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.42, 0.56, 0.78)
	sm.sky_horizon_color = Color(0.86, 0.84, 0.80)
	sm.ground_bottom_color = Color(0.40, 0.39, 0.36)
	sm.ground_horizon_color = Color(0.74, 0.72, 0.68)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.75
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_hdr_threshold = 1.2
	env.fog_enabled = true
	env.fog_light_color = Color(0.82, 0.82, 0.80)
	env.fog_density = 0.0012
	env.fog_sky_affect = 0.2
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(sun_rot.x, sun_rot.y, 0.0)
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.9, 0.78)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 700.0
	root.add_child(sun)
