extends SceneTree
## Look-dev for the Kronburg finale's building site kit (BaustelleKit.gd): builds a set in memory at SCALE 1.6 on a flat ground
## under a late-morning sun with shadows, waits for the shaders to compile, and saves a PNG per camera. Windowed:
##   Godot --path . --resolution 1600x900 -s res://scratch/baustelle_preview.gd -- <out_dir>
##       [set=crane|excavator|roller|site|small|vehicles|carpark|all] [slew=<deg>] [sun=<pitch>,<yaw>] [notext=1] [solids=1]
##       [save=<dir>] name:x,y,z:tx,ty,tz[:fov] ...
## Headless (`--headless ... -- headless=1 [set=...]`): builds every prop of the set(s), prints each one's triangles, surfaces
## and AABB (life metres times 1.6) and quits.
## Positions are in game metres (life x 1.6). Each set stands at its own spot (SPOTS, game metres); with no cameras given it
## shoots that set's default views (relative to the spot). A 2.2m RC car box (red) and a 2.9m person stand-in (blue) stand
## by each set for scale. The crane's top and the excavator's upper are put on as the level's scripts will (turned by
## `slew`), the roller on its own. `solids=1` draws the `*_solids` boxes as translucent green.

const BK = preload("res://BaustelleKit.gd")

const SCALE := 1.6
const CRANE_H := 42.0
const CP_LEN := 60.0
const CP_WIDTH := 40.0
const CP_ROAD_HALF := 4.5

const SPOTS := {
	"crane": Vector3(0, 0, 0),
	"excavator": Vector3(300, 0, 0),
	"roller": Vector3(-300, 0, 0),
	"site": Vector3(0, 0, 300),
	"small": Vector3(300, 0, 300),
	"vehicles": Vector3(-300, 0, 300),
	"carpark": Vector3(0, 0, -300),
}

var save_dir := ""
var slew_deg := 25.0
var show_solids := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = "/tmp/baustelle"
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
		elif a.begins_with("slew="):
			slew_deg = float(a.substr(5))
		elif a.begins_with("save="):
			save_dir = a.substr(5)
			DirAccess.make_dir_recursive_absolute(save_dir)
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


func _default_shots(s: String) -> Array:
	var o: Vector3 = SPOTS.get(s, Vector3.ZERO)
	var list: Array = []
	var h: float = CRANE_H * SCALE
	match s:
		"crane":
			list = [["crane", Vector3(-70, 30, 95), Vector3(0, h * 0.62, -20), 55.0], ["crane_top", Vector3(-22, h + 12, 26), Vector3(0, h + 2, -10), 60.0],
					["crane_hook", Vector3(-30, h - 18, -12), Vector3(0, h - 24, -48), 45.0], ["crane_foot", Vector3(-9, 4, 14), Vector3(0, 6, 0), 60.0],
					["crane_far", Vector3(-160, 40, 160), Vector3(0, h * 0.7, -20), 40.0]]
		"excavator":
			list = [["exc_side", Vector3(-22, 5, -4), Vector3(0, 3, -6), 50.0], ["exc_front", Vector3(-10, 4, -28), Vector3(0, 3, -6), 55.0],
					["exc_back", Vector3(14, 6, 16), Vector3(0, 3, -4), 55.0], ["exc_bucket", Vector3(-7, 2.5, -12), Vector3(0, 1.5, -13), 50.0],
					["exc_race", Vector3(-6, 9, 18), Vector3(-3, 1, -10), 70.0]]
		"roller":
			list = [["roller", Vector3(-6, 3.5, -7), Vector3(0, 2, 0), 50.0], ["roller_back", Vector3(6, 4, 7), Vector3(0, 2, 0), 50.0],
					["roller_side", Vector3(-9, 2.2, 0.5), Vector3(0, 2, 0), 50.0]]
		"site":
			list = [["site", Vector3(-14, 7, 30), Vector3(4, 3, 0), 55.0], ["site_cabin", Vector3(8, 4, 16), Vector3(14, 3, 0), 55.0],
					["site_fence", Vector3(-30, 2.5, 8), Vector3(-30, 1.8, 0), 60.0], ["site_sign", Vector3(-12, 4, 10), Vector3(-12, 4.5, 0), 55.0],
					["site_back", Vector3(10, 9, -20), Vector3(0, 2, 0), 55.0]]
		"small":
			list = [["small", Vector3(0, 9, 26), Vector3(0, 1, 0), 55.0], ["small_close", Vector3(-10, 3, 9), Vector3(-6, 1, 0), 55.0],
					["small_right", Vector3(12, 3.5, 9), Vector3(10, 1, 0), 55.0], ["small_bake", Vector3(-15, 1.8, 4), Vector3(-15, 1.2, 0), 50.0],
					["small_scaffold", Vector3(20, 9, 14), Vector3(22, 6, -4), 55.0]]
		"vehicles":
			list = [["mixer", Vector3(-10, 5, -12), Vector3(0, 2.5, 0), 55.0], ["mixer_back", Vector3(9, 5, 12), Vector3(0, 3, 2), 55.0],
					["dumper", Vector3(10, 3.5, -8), Vector3(14, 1.6, 0), 50.0], ["dumper_back", Vector3(19, 4, 6), Vector3(14, 2, 0), 50.0]]
		"carpark":
			var L: float = CP_LEN * SCALE
			list = [["cp_drive", Vector3(0, 3.0, 12), Vector3(0, 2.5, -40), 70.0], ["cp_race", Vector3(0, 16, 22), Vector3(0, 0, -6), 72.0],
					["cp_aerial", Vector3(-70, 55, 40), Vector3(0, 0, -L * 0.5), 55.0], ["cp_core", Vector3(45, 18, -L - 25), Vector3(26, 6, -L + 6), 55.0],
					["cp_inside", Vector3(-6, 2.5, -30), Vector3(-16, 3, -48), 70.0], ["cp_deck", Vector3(-26, 9, -10), Vector3(-18, 5, -40), 60.0]]
	var outl: Array = []
	for sh in list:
		var p: Vector3 = (sh[1] as Vector3) + o
		var t: Vector3 = (sh[2] as Vector3) + o
		outl.append("%s:%f,%f,%f:%f,%f,%f:%f" % [sh[0], p.x, p.y, p.z, t.x, t.y, t.z, sh[3]])
	return outl


## Builds one set at its spot; returns its triangles. Parts are [name, transform (life metres, local to the spot), builder,
## solids or []].
func _build_set(s: String, notext: bool) -> int:
	var o: Vector3 = SPOTS.get(s, Vector3.ZERO)
	var parts: Array = []
	var slew: float = deg_to_rad(slew_deg)
	match s:
		"crane":
			parts.append(["CraneMast", Transform3D.IDENTITY, func(pk, kit, _labels): BK.tower_crane_mast(pk, kit, CRANE_H), BK.tower_crane_mast_solids(CRANE_H)])
			parts.append(["CraneTop", Transform3D(Basis(Vector3.UP, slew), Vector3(0, CRANE_H, 0)), func(pk, kit, labels): BK.tower_crane_top(pk, kit, labels), []])
			parts.append(["CraneTopSkip", Transform3D(Basis(Vector3.UP, slew + 2.4), Vector3(150, CRANE_H, 0)),
					func(pk, kit, labels): BK.tower_crane_top(pk, kit, labels, "skip"), []])
			parts.append(["CraneMast2", Transform3D(Basis(), Vector3(150, 0, 0)), func(pk, kit, _labels): BK.tower_crane_mast(pk, kit, CRANE_H), []])
			_scale_figures(o + Vector3(-6, 0, 10))
		"excavator":
			parts.append(["Excavator", Transform3D.IDENTITY, func(pk, kit, labels): BK.excavator(pk, kit, labels), BK.excavator_solids()])
			parts.append(["ExcavatorUpper", Transform3D(Basis(Vector3.UP, slew), Vector3(0, BK.EXC_RING_Y, 0)),
					func(pk, kit, _labels): BK.excavator_upper(pk, kit), []])
			_hit_box(o, slew)
			_road(o + Vector3(-9.5, 0, -6), 9.0, 40.0)
			_scale_figures(o + Vector3(-9, 0, -14))
		"roller":
			parts.append(["Roller", Transform3D.IDENTITY, func(pk, kit, _labels): print("roller size ", BK.road_roller(pk, kit)), BK.road_roller_solids()])
			_scale_figures(o + Vector3(-4, 0, 4))
		"site":
			parts.append(["Fence", Transform3D(Basis(), Vector3(-40, 0, 0)), func(pk, kit, labels): BK.site_fence(pk, kit, 24.0, 3, labels, 0), BK.site_fence_solids(24.0)])
			parts.append(["Cabin", Transform3D(Basis(), Vector3(14, 0, -3)), func(pk, kit, labels): BK.site_cabin(pk, kit, labels, true), BK.site_cabin_solids(true)])
			parts.append(["Cabin1", Transform3D(Basis(Vector3.UP, 0.3), Vector3(1, 0, -6)), func(pk, kit, labels): BK.site_cabin(pk, kit, labels, false), []])
			parts.append(["Sign", Transform3D(Basis(), Vector3(-12, 0, 2)), func(pk, kit, labels): BK.site_sign(pk, kit, labels), BK.site_sign_solids()])
			_scale_figures(o + Vector3(-4, 0, 8))
		"small":
			parts.append(["Skip", Transform3D(Basis(), Vector3(-8, 0, 0)), func(pk, kit, _labels): BK.skip(pk, kit, 0), BK.skip_solids()])
			parts.append(["Skip2", Transform3D(Basis(Vector3.UP, 0.4), Vector3(-8, 0, -6)), func(pk, kit, _labels): BK.skip(pk, kit, 1), []])
			parts.append(["Toilet", Transform3D(Basis(), Vector3(-3, 0, 0)), func(pk, kit, _labels): BK.portable_toilet(pk, kit), BK.portable_toilet_solids()])
			parts.append(["Rebar", Transform3D(Basis(), Vector3(2, 0, 2)), func(pk, kit, _labels): BK.rebar_stack(pk, kit, 6.0), BK.rebar_stack_solids(6.0)])
			parts.append(["Formwork", Transform3D(Basis(), Vector3(8, 0, 2)), func(pk, kit, _labels): BK.formwork_stack(pk, kit), BK.formwork_stack_solids()])
			parts.append(["Bricks", Transform3D(Basis(), Vector3(2, 0, -3)), func(pk, kit, _labels): BK.brick_pallets(pk, kit, 4), BK.brick_pallets_solids(4)])
			parts.append(["Pipes", Transform3D(Basis(), Vector3(12, 0, -2)), func(pk, kit, _labels): BK.concrete_pipes(pk, kit, 5), BK.concrete_pipes_solids(5)])
			parts.append(["Drum", Transform3D(Basis(), Vector3(-3, 0, -5)), func(pk, kit, _labels): BK.cable_drum(pk, kit), BK.cable_drum_solids()])
			parts.append(["Sand", Transform3D(Basis(), Vector3(-15, 0, -8)), func(pk, kit, _labels): BK.sand_pile(pk, kit, 4.0, 1.8), []])
			for i in 4:
				parts.append(["Bake%d" % i, Transform3D(Basis(Vector3.UP, 0.1 * i), Vector3(-17 + 1.2 * i, 0, 0)), func(pk, kit, _labels): BK.leitbake(pk, kit),
						BK.leitbake_solids() if i == 0 else []])
				parts.append(["Lamp%d" % i, Transform3D(Basis(Vector3.UP, 0.1 * i), Vector3(-17 + 1.2 * i, BK.LEITBAKE_TOP, 0)), func(pk, kit, _labels): BK.warning_lamp(pk, kit), []])
			parts.append(["Scaffold", Transform3D(Basis(), Vector3(16, 0, -6)), func(pk, kit, _labels): BK.scaffold(pk, kit, 10.0, 8.0, 0.8), BK.scaffold_solids(10.0, 8.0, 0.8)])
			_wall(o + Vector3(16, 0, -6) * Vector3(SCALE, 1, SCALE), 10.0 * SCALE, 9.0 * SCALE)
			_scale_figures(o + Vector3(-1, 0, 8))
		"vehicles":
			parts.append(["Mixer", Transform3D.IDENTITY, func(pk, kit, _labels): BK.mixer_truck(pk, kit), BK.mixer_truck_solids()])
			parts.append(["Dumper", Transform3D(Basis(Vector3.UP, 0.5), Vector3(9, 0, 0)), func(pk, kit, _labels): BK.dumper(pk, kit), BK.dumper_solids()])
			_scale_figures(o + Vector3(-5, 0, 6))
		"carpark":
			parts.append(["CarPark", Transform3D.IDENTITY, func(pk, kit, labels): BK.carpark_frame(pk, kit, labels, CP_LEN, CP_WIDTH, CP_ROAD_HALF),
					BK.carpark_frame_solids(CP_LEN, CP_WIDTH, CP_ROAD_HALF)])
			_road(o + Vector3(0, 0, -CP_LEN * SCALE * 0.5), CP_ROAD_HALF * 2.0 * SCALE, CP_LEN * SCALE + 80.0)
			_clear_box(o, CP_ROAD_HALF + BK.CP_OPEN, CP_LEN)
			_scale_figures(o + Vector3(0, 0, -20), true)
	var tris := 0
	for part in parts:
		var pk = BK.new_kit(SCALE)
		var kit := {}
		var labels: Array = []
		var t0 := Time.get_ticks_msec()
		(part[2] as Callable).call(pk, kit, labels)
		var mesh: ArrayMesh = BK.commit(pk, kit)
		var mi := MeshInstance3D.new()
		mi.name = part[0]
		mi.mesh = mesh
		var lt: Transform3D = part[1]
		mi.transform = Transform3D(lt.basis, o + lt.origin * SCALE)
		root.add_child(mi)
		var t := _tris(mesh)
		var keys: PackedStringArray = []
		for k in mesh.get_surface_count():
			keys.append(mesh.surface_get_name(k))
		print("%s: %d triangles, %d surfaces %s, aabb %s, %d labels (%d ms)" % [part[0], t, mesh.get_surface_count(), ",".join(keys), mesh.get_aabb(), labels.size(),
				Time.get_ticks_msec() - t0])
		tris += t
		if save_dir != "":
			ResourceSaver.save(mesh, "%s/%s.res" % [save_dir, part[0]])
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


## A solid box [Transform3D (life), size] drawn translucent green in a piece's frame.
func _solid_box(sb: Array, xf: Transform3D) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = (sb[1] as Vector3) * SCALE
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.1, 0.95, 0.3, 0.25)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	bm.material = m
	var t: Transform3D = sb[0]
	mi.transform = xf * Transform3D(t.basis, t.origin * SCALE)
	root.add_child(mi)


## The excavator's hit box (EXC_HIT_C, EXC_HIT_HALF in the upper's frame) drawn translucent red, turned with the upper.
func _hit_box(o: Vector3, slew: float) -> void:
	if not show_solids:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = BK.EXC_HIT_HALF * 2.0 * SCALE
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.1, 0.1, 0.3)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	bm.material = m
	var up := Transform3D(Basis(Vector3.UP, slew), o + Vector3(0, BK.EXC_RING_Y, 0) * SCALE)
	mi.transform = up * Transform3D(Basis(), BK.EXC_HIT_C * SCALE)
	root.add_child(mi)


## A translucent box over the car park's promised clear corridor (|x| < half, every height) for the shots.
func _clear_box(o: Vector3, half: float, length: float) -> void:
	if not show_solids:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(half * 2.0, 14.0, length) * SCALE
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.2, 0.9, 0.12)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	bm.material = m
	mi.position = o + Vector3(0, 7.0, -length * 0.5) * SCALE
	root.add_child(mi)


## A strip of road along z through `o`, `w` wide (game metres), `length` long.
func _road(o: Vector3, w: float, length: float, col := Color(0.2, 0.2, 0.21)) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(w, length)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
	pm.material = m
	mi.position = o + Vector3(0, 0.02, 0)
	root.add_child(mi)


## A plain wall (the scaffold's) at `o`, along +x, `w` long and `h` high, its face on z = 0 of the spot.
func _wall(o: Vector3, w: float, h: float) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, 0.6)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.7, 0.68, 0.64)
	bm.material = m
	mi.position = o + Vector3(w * 0.5, h * 0.5, -0.3)
	root.add_child(mi)


## A 2.2m RC car (a red box) and a 2.9m person stand-in (a blue capsule) at `p`.
func _scale_figures(p: Vector3, on_road := false) -> void:
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
	man.position = p + Vector3(3.0 if on_road else 2.5, 1.45, 0)
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
