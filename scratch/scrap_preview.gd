extends SceneTree
## Look-dev for the Kronburg finale's dock kit (ScrapKit.gd): builds a set in memory at SCALE 1.6 on a flat ground under a
## late-morning sun with shadows, waits for the shaders to compile, and saves a PNG per camera. Windowed:
##   Godot --path . --resolution 1600x900 -s res://scratch/scrap_preview.gd -- <out_dir>
##       [set=demolition|heaps|handler|yard|all] [swing=<deg>] [slew=<deg>] [storeys=7] [sun=<pitch>,<yaw>] [notext=1] [solids=1]
##       name:x,y,z:tx,ty,tz[:fov] ...
## Headless (`--headless ... -- headless=1 [set=...]`): builds every prop of the set(s), prints each one's triangles, surfaces
## and AABB and quits.
## Positions are in game metres (life x 1.6). Each set stands at its own spot (SPOTS); with no cameras given it shoots that
## set's default views (relative to the spot). A 2.2m RC car box (red) and a 2.9m person (blue) stand by each set for scale.
## The moving parts are put on as the level does: the wrecking ball (a life-size mesh grown 1.6) hangs from CRANE_TIP, turned
## `swing` degrees about x toward the ruin (+ toward it); the handler's upper turns `slew` degrees on its ring at HANDLER_RING_Y
## with the magnet hanging at HANDLER_TIP. `solids=1` draws the `*_solids` boxes translucent green and the hazards' hit volumes
## red; the road strips are where the generator's route runs past each prop.

var SK: Script = load("res://ScrapKit.gd")

const SCALE := 1.6
const ROAD_HALF := 7.5

const SPOTS := {
	"demolition": Vector3(0, 0, 0),
	"heaps": Vector3(300, 0, 0),
	"handler": Vector3(-300, 0, 0),
	"yard": Vector3(0, 0, 300),
}

var swing_deg := 0.0
var slew_deg := 0.0
var storeys := 7
var show_solids := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = "/tmp/scrap"
	var which := "all"
	var sun_rot := Vector2(-48.0, 150.0)
	var notext := false
	var headless := false
	var shots: Array = []
	for a in args:
		if a.begins_with("set="):
			which = a.substr(4)
		elif a.begins_with("sun="):
			var sv := a.substr(4).split_floats(",")
			sun_rot = Vector2(sv[0], sv[1])
		elif a.begins_with("notext="):
			notext = a.substr(7) == "1"
		elif a.begins_with("headless="):
			headless = a.substr(9) == "1"
		elif a.begins_with("solids="):
			show_solids = a.substr(7) == "1"
		elif a.begins_with("swing="):
			swing_deg = float(a.substr(6))
		elif a.begins_with("slew="):
			slew_deg = float(a.substr(5))
		elif a.begins_with("storeys="):
			storeys = int(a.substr(8))
		elif a.contains(":"):
			shots.append(a)
		else:
			out = a
	if not headless:
		DirAccess.make_dir_recursive_absolute(out)
		_setup_world(sun_rot)
	var sets: Array = SPOTS.keys() if which == "all" else Array(which.split(","))
	var total := 0
	for s in sets:
		total += _build_set(s, notext)
	print("TOTAL triangles ", total)
	if headless:
		quit()
		return
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


## The ruin's front (z, game metres, from the spot) and the road's line: as the generator lays them, the crane's tip over the
## road and the ruin RUIN_GAP (ROAD_HALF + 10) beyond it, the crane's boom toward -z.
func _tip() -> Vector3:
	return _k("CRANE_TIP") * SCALE


func _default_shots(s: String) -> Array:
	var o: Vector3 = SPOTS.get(s, Vector3.ZERO)
	var list: Array = []
	var tip := _tip()
	var rz: float = tip.z - (ROAD_HALF + 10.0)
	match s:
		"demolition":
			list = [["demo_wide", Vector3(70, 30, 40), Vector3(0, 18, tip.z - 6), 55.0], ["demo_road_east", Vector3(-55, 4, tip.z + 2), Vector3(0, 8, rz - 8), 60.0],
					["demo_crane", Vector3(35, 12, 30), Vector3(0, 8, 0), 55.0], ["demo_ruin_cut", Vector3(-48, 22, rz + 26), Vector3(-18, 14, rz - 10), 55.0],
					["demo_crater", Vector3(-8, 4, rz + 14), Vector3(0, 3.5, rz), 55.0], ["demo_ball", Vector3(10, 8, tip.z + 14), Vector3(0, 5, tip.z - 6), 50.0],
					["demo_ruin_front", Vector3(15, 14, rz + 45), Vector3(6, 16, rz), 55.0], ["demo_cab", Vector3(-9, 6, -10), Vector3(-3.5, 5, -3), 55.0],
					["demo_head", Vector3(-14, tip.y + 2, tip.z + 6), Vector3(0, tip.y - 1, tip.z + 1), 50.0], ["demo_back", Vector3(-30, 25, rz - 60), Vector3(0, 12, rz - 12), 55.0]]
		"heaps":
			list = [["heaps_wide", Vector3(0, 22, 55), Vector3(0, 2, 0), 60.0], ["heaps_scrap", Vector3(-30, 9, 32), Vector3(-30, 4, 0), 55.0],
					["heaps_rubble", Vector3(30, 7, 26), Vector3(30, 2, 0), 55.0], ["heaps_bales", Vector3(-6, 3.5, 34), Vector3(4, 2.2, 20), 55.0],
					["heaps_small", Vector3(12, 5, 44), Vector3(16, 1.5, 32), 55.0], ["heaps_skip", Vector3(-24, 4, 44), Vector3(-30, 1.5, 34), 50.0]]
		"handler":
			list = [["handler_road", Vector3(-40, 4, -22), Vector3(0, 6, -16), 60.0], ["handler_side", Vector3(-30, 14, 10), Vector3(0, 9, -10), 55.0],
					["handler_magnet", Vector3(-12, 4, -12), Vector3(0, 3, -24), 55.0], ["handler_base", Vector3(9, 5, 12), Vector3(0, 4, 0), 55.0],
					["handler_top", Vector3(20, 30, 20), Vector3(0, 5, -10), 55.0]]
		"yard":
			list = [["yard_press", Vector3(0, 10, 32), Vector3(0, 3, 0), 55.0], ["yard_press_side", Vector3(-24, 7, 10), Vector3(-6, 3, 0), 55.0],
					["yard_office", Vector3(-84, 7, 74), Vector3(-60, 4, 60), 55.0], ["yard_weigh", Vector3(-82, 6, 112), Vector3(-60, 2, 100), 55.0],
					["yard_fence", Vector3(25, 5, 75), Vector3(30, 3, 60), 55.0], ["yard_fence_in", Vector3(35, 4, 52), Vector3(30, 3, 60), 55.0]]
	var outl: Array = []
	for sh in list:
		var p: Vector3 = (sh[1] as Vector3) + o
		var t: Vector3 = (sh[2] as Vector3) + o
		outl.append("%s:%f,%f,%f:%f,%f,%f:%f" % [sh[0], p.x, p.y, p.z, t.x, t.y, t.z, sh[3]])
	return outl


func _k(n: String) -> Variant:
	return SK.get_script_constant_map()[n]


func _has(fn: String) -> bool:
	for m in (SK as Script).get_script_method_list():
		if m["name"] == fn:
			return true
	print("  (no %s yet)" % fn)
	return false


## Builds one set at its spot; returns its triangles. Parts are [name, transform (game metres, local to the spot), builder,
## solids or [], scale (1.6 for props, 1.0 for the moving parts' life-size meshes under a node grown 1.6)].
func _build_set(s: String, notext: bool) -> int:
	var o: Vector3 = SPOTS.get(s, Vector3.ZERO)
	var parts: Array = []
	match s:
		"demolition":
			var tip := _tip()
			var rz: float = tip.z - (ROAD_HALF + 10.0)
			if _has("crawler_crane"):
				parts.append(["Crane", Transform3D.IDENTITY, func(pk, kit, labels): SK.callv("crawler_crane", [pk, kit, labels]), SK.callv("crawler_crane_solids", [])])
			if _has("ruin_building"):
				parts.append(["Ruin", Transform3D(Basis(), Vector3(0, 0, rz)), func(pk, kit, labels): SK.callv("ruin_building", [pk, kit, labels, storeys]), SK.callv("ruin_building_solids", [storeys])])
			if _has("wrecking_ball"):
				var length: float = tip.y - 2.2
				var chain_life: float = length / SCALE - _k("BALL_H") * 0.5
				var swing := Node3D.new()
				swing.position = o + tip
				swing.rotation = Vector3(-deg_to_rad(-swing_deg), 0, 0)
				root.add_child(swing)
				var pk = SK.new_kit(1.0)
				var kit := {}
				SK.callv("wrecking_ball", [pk, kit, chain_life])
				var mi := MeshInstance3D.new()
				mi.mesh = SK.commit(pk, kit)
				mi.scale = Vector3.ONE * SCALE
				swing.add_child(mi)
				print("Ball: %d triangles, line %.1fm (chain_life %.2f)" % [_tris(mi.mesh), length, chain_life])
				if show_solids:
					_hit_sphere(swing, Vector3(0, -length, 0), _k("BALL_R") * SCALE)
			_road(o + Vector3(0, 0, tip.z), 300.0, ROAD_HALF * 2.0, true)
			_scale_figures(o + Vector3(-20, 0, tip.z + 3))
		"heaps":
			if _has("scrap_heap"):
				parts.append(["ScrapHeap", Transform3D(Basis(), Vector3(-30, -0.2, 0)), func(pk, kit, _l): SK.callv("scrap_heap", [pk, kit, 22.0, 14.0, 7.0, 5]),
						SK.callv("scrap_heap_solids", [22.0, 14.0, 7.0, 5])])
			if _has("rubble_heap"):
				parts.append(["Rubble", Transform3D(Basis(Vector3.UP, 0.4), Vector3(30, -0.2, 0)), func(pk, kit, _l): SK.callv("rubble_heap", [pk, kit, 16.0, 12.0, 4.5, 3]), []])
			if _has("bale_wall"):
				parts.append(["Bales", Transform3D(Basis(), Vector3(-5, 0, 20)), func(pk, kit, _l): SK.callv("bale_wall", [pk, kit, 15.0, 4, 9]), []])
				parts.append(["Bales2", Transform3D(Basis(), Vector3(20, 0, 20)), func(pk, kit, _l): SK.callv("bale_wall", [pk, kit, 9.0, 3, 10]), []])
			if _has("skip"):
				for k in 3:
					parts.append(["Skip%d" % k, Transform3D(Basis(Vector3.UP, 0.2 * k), Vector3(-34 + 7 * k, 0, 34)), func(pk, kit, _l): SK.callv("skip", [pk, kit, k + 1]), []])
			for fn in ["sorting_bin", "drum_stack", "tyre_pile"]:
				if _has(fn):
					var fx: float = {"sorting_bin": 8.0, "drum_stack": 16.0, "tyre_pile": 24.0}[fn]
					parts.append([fn, Transform3D(Basis(), Vector3(fx, 0, 32)), func(pk, kit, _l): SK.callv(fn, [pk, kit, 4]), []])
			_scale_figures(o + Vector3(0, 0, 40))
		"handler":
			if _has("material_handler"):
				parts.append(["Handler", Transform3D.IDENTITY, func(pk, kit, labels): SK.callv("material_handler", [pk, kit, labels]), SK.callv("material_handler_solids", [])])
			var slew := Node3D.new()
			slew.position = o + Vector3(0, _k("HANDLER_RING_Y") * SCALE, 0)
			slew.rotation = Vector3(0, deg_to_rad(slew_deg), 0)
			root.add_child(slew)
			if _has("material_handler_upper"):
				var pk = SK.new_kit(1.0)
				var kit := {}
				SK.callv("material_handler_upper", [pk, kit])
				var mi := MeshInstance3D.new()
				mi.mesh = SK.commit(pk, kit)
				mi.scale = Vector3.ONE * SCALE
				slew.add_child(mi)
				print("Upper: %d triangles, aabb %s" % [_tris(mi.mesh), mi.mesh.get_aabb()])
			var hang := Node3D.new()
			hang.position = _k("HANDLER_TIP") * SCALE
			slew.add_child(hang)
			if _has("scrap_magnet"):
				var pk2 = SK.new_kit(1.0)
				var kit2 := {}
				SK.callv("scrap_magnet", [pk2, kit2, 3])
				var mi2 := MeshInstance3D.new()
				mi2.mesh = SK.commit(pk2, kit2)
				mi2.scale = Vector3.ONE * SCALE
				hang.add_child(mi2)
				print("Magnet: %d triangles, aabb %s" % [_tris(mi2.mesh), mi2.mesh.get_aabb()])
				if show_solids:
					_hit_box(hang, _k("MAGNET_HIT_C") * SCALE, _k("MAGNET_HIT_HALF") * 2.0 * SCALE)
			# The lane: its line 22m north (-z) of the handler.
			_road(o + Vector3(0, 0, -22.0), 200.0, ROAD_HALF * 2.0, true)
			_scale_figures(o + Vector3(-12, 0, -22))
		"yard":
			if _has("car_press"):
				parts.append(["Press", Transform3D.IDENTITY, func(pk, kit, labels): SK.callv("car_press", [pk, kit, labels]), SK.callv("car_press_solids", [])])
			# The office and the weighbridge face -x (the road) as the generator turns them.
			var face := Basis(Vector3(0, 0, 1), Vector3.UP, Vector3(-1, 0, 0))
			if _has("scrapyard_office"):
				parts.append(["Office", Transform3D(face, Vector3(-60, 0, 60)), func(pk, kit, labels): SK.callv("scrapyard_office", [pk, kit, labels]), SK.callv("scrapyard_office_solids", [])])
			if _has("weighbridge"):
				parts.append(["Weigh", Transform3D(face, Vector3(-60, 0, 100)), func(pk, kit, labels): SK.callv("weighbridge", [pk, kit, labels]), SK.callv("weighbridge_solids", [])])
			if _has("scrap_fence"):
				parts.append(["Fence", Transform3D(Basis(), Vector3(20, 0, 60)), func(pk, kit, _l): SK.callv("scrap_fence", [pk, kit, 12.5]), []])
				parts.append(["Fence2", Transform3D(Basis(), Vector3(40, 0, 60)), func(pk, kit, _l): SK.callv("scrap_fence", [pk, kit, 12.5]), []])
			# The press's lane south of it, the road west of the office.
			_road(o + Vector3(0, 0, 28.0), 120.0, ROAD_HALF * 2.0, true)
			_road(o + Vector3(-60 - 21.5, 0, 80), ROAD_HALF * 2.0, 120.0, true)
			_scale_figures(o + Vector3(-10, 0, 22))
	var tris := 0
	for part in parts:
		var pk = SK.new_kit(SCALE)
		var kit := {}
		var labels: Array = []
		var t0 := Time.get_ticks_msec()
		(part[2] as Callable).call(pk, kit, labels)
		var mesh: ArrayMesh = SK.commit(pk, kit)
		var mi := MeshInstance3D.new()
		mi.name = part[0]
		mi.mesh = mesh
		var lt: Transform3D = part[1]
		mi.transform = Transform3D(lt.basis, o + lt.origin)
		root.add_child(mi)
		var t := _tris(mesh)
		var keys: PackedStringArray = []
		for k in mesh.get_surface_count():
			keys.append(mesh.surface_get_name(k))
		print("%s: %d triangles, %d surfaces %s, aabb (life) %s, %d labels (%d ms)" % [part[0], t, mesh.get_surface_count(), ",".join(keys),
				AABB(mesh.get_aabb().position / SCALE, mesh.get_aabb().size / SCALE), labels.size(), Time.get_ticks_msec() - t0])
		tris += t
		if not notext:
			for l in labels:
				_label(l, mi.transform)
		if show_solids and part.size() > 3:
			for sb in part[3]:
				_solid_box(sb, mi.transform)
	return tris


func _tris(mesh: ArrayMesh) -> int:
	var t := 0
	for k in mesh.get_surface_count():
		var arr: Array = mesh.surface_get_arrays(k)
		var idx = arr[Mesh.ARRAY_INDEX]
		t += int((idx as PackedInt32Array).size() / 3.0) if idx != null else int((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3.0)
	return t


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


func _translucent(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## A solid box [Transform3D (life), size] drawn translucent green in a piece's frame.
func _solid_box(sb: Array, xf: Transform3D) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = (sb[1] as Vector3) * SCALE
	bm.material = _translucent(Color(0.1, 0.95, 0.3, 0.25))
	mi.mesh = bm
	var t: Transform3D = sb[0]
	mi.transform = xf * Transform3D(t.basis, t.origin * SCALE)
	root.add_child(mi)


func _hit_box(parent: Node3D, c: Vector3, size: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = _translucent(Color(0.95, 0.1, 0.1, 0.3))
	mi.mesh = bm
	mi.position = c
	parent.add_child(mi)


func _hit_sphere(parent: Node3D, c: Vector3, r: float) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.material = _translucent(Color(0.95, 0.1, 0.1, 0.3))
	mi.mesh = sm
	mi.position = c
	parent.add_child(mi)


## A strip of road centred on `c` (game metres), `lx` along x by `lz` along z; `edges` paints its edges white.
func _road(c: Vector3, lx: float, lz: float, edges := false) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(lx, lz)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.2, 0.21)
	m.roughness = 0.9
	pm.material = m
	mi.position = c + Vector3(0, 0.02, 0)
	root.add_child(mi)
	if not edges:
		return
	for sd in [-1.0, 1.0]:
		var e := MeshInstance3D.new()
		var em := PlaneMesh.new()
		em.size = Vector2(lx, 0.3) if lx > lz else Vector2(0.3, lz)
		var wm := StandardMaterial3D.new()
		wm.albedo_color = Color(0.9, 0.9, 0.88)
		em.material = wm
		e.mesh = em
		e.position = c + Vector3(0, 0.03, 0) + (Vector3(0, 0, sd * (lz * 0.5 - 0.3)) if lx > lz else Vector3(sd * (lx * 0.5 - 0.3), 0, 0))
		root.add_child(e)


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
	pm.size = Vector2(4000, 4000)
	gm.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.42, 0.40, 0.35)
	gmat.roughness = 1.0
	pm.material = gmat
	gm.position = Vector3(0, -0.02, 0)
	root.add_child(gm)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.36, 0.55, 0.82)
	sm.sky_horizon_color = Color(0.80, 0.85, 0.90)
	sm.ground_bottom_color = Color(0.40, 0.39, 0.36)
	sm.ground_horizon_color = Color(0.74, 0.72, 0.68)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.75
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_hdr_threshold = 1.3
	env.fog_enabled = true
	env.fog_light_color = Color(0.82, 0.85, 0.88)
	env.fog_density = 0.0008
	env.fog_sky_affect = 0.15
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
