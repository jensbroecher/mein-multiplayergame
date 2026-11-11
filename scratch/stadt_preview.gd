extends SceneTree
## Look-dev for the Kronburg finale's city kit (StadtKit.gd): builds a set in memory at SCALE 1.6 on a flat ground under a
## late-morning sun with shadows, waits for the shaders to compile, and saves a PNG per camera. Windowed:
##   Godot --path . --resolution 1600x900 -s res://scratch/stadt_preview.gd -- <out_dir>
##       [set=furniture|fountain|ring|ubahn|stand|vehicles|kaufhaus|hbf|brauerei|all] [sun=<pitch>,<yaw>] [notext=1] [solids=1]
##       name:x,y,z:tx,ty,tz[:fov] ...
## Headless (`--headless ... -- headless=1 [set=...]`): builds every prop of the set(s), prints each one's triangles, surfaces
## and AABB (game metres) and quits.
## Positions are in game metres (life x 1.6). Each set stands at its own spot (SPOTS, game metres); with no cameras given it
## shoots that set's default views (relative to the spot). A 2.2m RC car box (red) and a 2.9m person stand-in (blue) stand
## by each set for scale. `solids=1` draws the `*_solids` boxes as translucent green; the grandstand's seats show as red
## dots, the road corridor the generator keeps clear (where a set has one) as a translucent magenta box.

const SK = preload("res://StadtKit.gd")

const SCALE := 1.6

const SPOTS := {
	"furniture": Vector3(0, 0, 0),
	"fountain": Vector3(200, 0, 0),
	"ring": Vector3(400, 0, 0),
	"ubahn": Vector3(600, 0, 0),
	"stand": Vector3(0, 0, 300),
	"vehicles": Vector3(300, 0, 300),
	"kaufhaus": Vector3(0, 0, -400),
	"hbf": Vector3(600, 0, -500),
	"brauerei": Vector3(-600, 0, 400),
}

var show_solids := false
## The kit as a plain Script (for its constants and the builders called by name).
var sks: Script = load("res://StadtKit.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = "/tmp/stadt"
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
	match s:
		"furniture":
			list = [["furn", Vector3(0, 7, 16), Vector3(0, 1, 0), 55.0], ["furn_cafe", Vector3(-12, 3, 9), Vector3(-12, 1.2, 0), 55.0],
					["furn_plant", Vector3(6, 2.5, 6), Vector3(6, 1.5, 0), 55.0], ["furn_bikes", Vector3(14, 2.5, 6), Vector3(16, 0.8, 0), 55.0]]
		"fountain":
			list = [["fountain", Vector3(-12, 6, 14), Vector3(0, 3, 0), 55.0], ["fountain_low", Vector3(0, 2, 13), Vector3(0, 3, 0), 60.0]]
		"ring":
			list = [["ring", Vector3(-30, 14, 34), Vector3(0, 5, 0), 55.0], ["ring_mast", Vector3(-6, 9, 8), Vector3(0, 10, 0), 55.0],
					["ring_light", Vector3(26, 6, 18), Vector3(20, 6, 0), 55.0], ["ring_stop", Vector3(-30, 5, 16), Vector3(-30, 2, -2), 55.0],
					["ring_stop2", Vector3(-24, 3, 7), Vector3(-30, 2.5, 0), 60.0]]
		"ubahn":
			list = [["ubahn", Vector3(12, 6, 14), Vector3(0, 2.5, 0), 55.0], ["ubahn_front", Vector3(3, 3, 15), Vector3(0, 1.5, 0), 55.0],
					["ubahn_back", Vector3(-12, 5, -12), Vector3(0, 2.5, 0), 55.0]]
		"stand":
			list = [["stand", Vector3(0, 6, 30), Vector3(0, 3.5, -6), 60.0], ["stand_end", Vector3(36, 5, 12), Vector3(22, 3, -6), 55.0],
					["stand_back", Vector3(-20, 8, -30), Vector3(0, 3, -6), 55.0], ["stand_close", Vector3(-15, 4, 7), Vector3(-20, 4, -5), 60.0]]
		"vehicles":
			list = [["veh", Vector3(-30, 14, 40), Vector3(0, 2, 0), 55.0], ["veh_tram", Vector3(-12, 5, -40), Vector3(-6, 3, -20), 55.0],
					["veh_bus", Vector3(12, 4, -18), Vector3(6, 2.5, 0), 55.0], ["veh_cars", Vector3(30, 4, -10), Vector3(22, 1, 2), 55.0],
					["veh_back", Vector3(30, 5, 30), Vector3(14, 2, 6), 55.0]]
		"kaufhaus":
			list = [["kh", Vector3(-40, 12, 45), Vector3(0, 18, -20), 60.0], ["kh_street", Vector3(25, 3, 20), Vector3(0, 6, 0), 60.0],
					["kh_side", Vector3(70, 25, -30), Vector3(0, 18, -30), 55.0], ["kh_door", Vector3(0, 3, 9), Vector3(0, 3, 0), 60.0]]
		"brauerei":
			# BreweryKit's Kronburger Brauerei (game metres; the Hafenstraße runs along x about 40m in front of it).
			list = [["br_road", Vector3(75, 3, 46), Vector3(0, 12, 0), 60.0], ["br_front", Vector3(0, 9, 75), Vector3(2, 14, 0), 62.0],
					["br_bottle", Vector3(36, 5, 26), Vector3(29.6, 15, 3), 60.0], ["br_tower", Vector3(62, 28, 34), Vector3(42, 36, -4), 55.0],
					["br_gate", Vector3(-38, 4, 34), Vector3(-32, 6, 0), 60.0], ["br_garden", Vector3(9, 3.2, 22), Vector3(0, 3.5, 6), 65.0],
					["br_gable", Vector3(4, 22, 22), Vector3(0, 28, 0), 55.0], ["br_back", Vector3(-40, 45, -100), Vector3(0, 10, -30), 55.0],
					["br_north", Vector3(80, 10, -40), Vector3(46, 18, -12), 60.0]]
		"hbf":
			list = [["hbf", Vector3(-80, 22, 110), Vector3(0, 18, -40), 60.0], ["hbf_front", Vector3(0, 4, 40), Vector3(0, 16, 0), 65.0],
					["hbf_side", Vector3(140, 40, -60), Vector3(0, 15, -80), 55.0], ["hbf_top", Vector3(-60, 60, -10), Vector3(0, 14, -90), 55.0],
					["hbf_platform", Vector3(-60, 18, -88), Vector3(0, 16, -95), 65.0], ["hbf_back", Vector3(80, 30, -220), Vector3(0, 15, -100), 55.0]]
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
	match s:
		"furniture":
			for i in 3:
				var sd: int = [11, 22, 34][i]
				parts.append(["Planter%d" % i, Transform3D(Basis(), Vector3(2.0 + 1.9 * i, 0, 0)), func(pk, kit, _labels): SK.planter(pk, kit, sd), []])
			parts.append(["Cafe0", Transform3D(Basis(), Vector3(-7.5, 0, 0)), func(pk, kit, _labels): SK.cafe_terrace(pk, kit, 5.5, 2.6, 7), []])
			parts.append(["Cafe1", Transform3D(Basis(), Vector3(-14.0, 0, 0)), func(pk, kit, _labels): SK.cafe_terrace(pk, kit, 5.5, 2.6, 12), []])
			parts.append(["Bikes", Transform3D(Basis(), Vector3(10.0, 0, 0)), func(pk, kit, _labels): SK.bike_rack(pk, kit, 5), []])
			parts.append(["Bollard", Transform3D(Basis(), Vector3(0.0, 0, 2)), func(pk, kit, _labels): SK.bollard(pk, kit), []])
			parts.append(["PedLight", Transform3D(Basis(), Vector3(-2.0, 0, 2)), func(pk, kit, _labels): SK.pedestrian_light(pk, kit), []])
			_scale_figures(o + Vector3(0, 0, 6))
		"fountain":
			parts.append(["Fountain", Transform3D.IDENTITY, func(pk, kit, _labels): SK.city_fountain(pk, kit), SK.city_fountain_solids()])
			_scale_figures(o + Vector3(-9, 0, 6))
		"ring":
			# The median's masts (+-5 game metres from the Ring's middle, as _build_catenary), the wires between, a light at a corner.
			var reach: float = (5.0 - 2.4) / SCALE
			for zi in 2:
				var z: float = -12.0 + 25.0 * zi
				parts.append(["MastE%d" % zi, Transform3D(Basis(), Vector3(5.0 / SCALE, 0, z / SCALE)), func(pk, kit, _labels): SK.catenary_mast(pk, kit, reach, 6.0), []])
				parts.append(["MastW%d" % zi, Transform3D(Basis(Vector3.UP, PI), Vector3(-5.0 / SCALE, 0, z / SCALE)),
						func(pk, kit, _labels): SK.catenary_mast(pk, kit, reach, 6.0), []])
			for tx in [2.4, -2.4]:
				_wire(o + Vector3(tx, 9.6, -12.0), o + Vector3(tx, 9.6, 13.0))
				_wire(o + Vector3(tx, 10.7, -12.0), o + Vector3(tx, 10.7, 13.0))
			# A corner light at x 17.9 game, its arm toward -x (over the lanes), heads facing +z.
			var lb := Basis(Vector3.UP, PI)
			parts.append(["Light", Transform3D(Basis(Vector3(-1, 0, 0), Vector3.UP, Vector3(0, 0, -1)), Vector3(17.9 / SCALE, 0, 0)),
					func(pk, kit, _labels): SK.traffic_light(pk, kit, 7.0), []])
			parts.append(["Light2", Transform3D(Basis(Vector3(-1, 0, 0), Vector3.UP, Vector3(0, 0, -1)), Vector3(17.9 / SCALE, 0, -14.0 / SCALE)),
					func(pk, kit, _labels): SK.traffic_light(pk, kit, 7.0), []])
			# The tram stop on the west pavement: its frame faces +x (toward the road); along it is world z.
			parts.append(["Stop", Transform3D(Basis(Vector3(0, 0, -1), Vector3.UP, Vector3(1, 0, 0)), Vector3(-20.1 / SCALE, 0, 0)),
					func(pk, kit, labels): SK.tram_stop(pk, kit, labels, 22.0, "Botanischer Garten"), SK.tram_stop_solids(22.0)])
			_road(o + Vector3(0, 0, 0), 33.4, 80.0)
			_road(o + Vector3(0, 0.005, 0), 11.0, 80.0, Color(0.32, 0.33, 0.32))
			_scale_figures(o + Vector3(-12, 0, 6), true)
		"ubahn":
			parts.append(["UBahn", Transform3D.IDENTITY, func(pk, kit, labels): SK.u_bahn_entrance(pk, kit, labels), SK.u_bahn_entrance_solids()])
			_scale_figures(o + Vector3(6, 0, 6))
		"stand":
			parts.append(["Stand", Transform3D.IDENTITY, func(pk, kit, labels): SK.temp_grandstand(pk, kit, labels, 8, 50.0), SK.temp_grandstand_solids(8, 50.0)])
			_seats(o, SK.temp_grandstand_seats(8, 50.0))
			_scale_figures(o + Vector3(-6, 0, 5))
		"vehicles":
			parts.append(["Tram0", Transform3D(Basis(), Vector3(-6.0 / SCALE, 0, 0)), func(pk, kit, _labels): print("tram size ", _k("tram", [pk, kit, 0])), []])
			parts.append(["Tram1", Transform3D(Basis(Vector3.UP, PI), Vector3(-1.2 / SCALE, 0, 0)), func(pk, kit, _labels): print("tram size ", _k("tram", [pk, kit, 1])), []])
			parts.append(["Bus", Transform3D(Basis(), Vector3(6.0 / SCALE, 0, 0)), func(pk, kit, _labels): print("bus size ", _k("city_bus", [pk, kit, 0])), []])
			parts.append(["Truck0", Transform3D(Basis(), Vector3(12.0 / SCALE, 0, -6.0 / SCALE)), func(pk, kit, _labels): print("truck size ", _k("box_truck", [pk, kit, 0])), []])
			parts.append(["Truck1", Transform3D(Basis(Vector3.UP, PI), Vector3(12.0 / SCALE, 0, 14.0 / SCALE)), func(pk, kit, _labels): _k("box_truck", [pk, kit, 1]), []])
			parts.append(["Van", Transform3D(Basis(), Vector3(17.0 / SCALE, 0, -4.0 / SCALE)), func(pk, kit, _labels): print("van size ", _k("delivery_van", [pk, kit, Color(0.92, 0.92, 0.9)])), []])
			parts.append(["Hatch", Transform3D(Basis(), Vector3(21.0 / SCALE, 0, -2.0 / SCALE)), func(pk, kit, _labels): print("hatch size ", _k("hatchback", [pk, kit, Color(0.78, 0.10, 0.08)])), []])
			parts.append(["Saloon", Transform3D(Basis(), Vector3(25.0 / SCALE, 0, -2.0 / SCALE)), func(pk, kit, _labels): print("saloon size ", _k("saloon", [pk, kit, Color(0.16, 0.16, 0.17), false])), []])
			parts.append(["Taxi", Transform3D(Basis(Vector3.UP, PI), Vector3(25.0 / SCALE, 0, 10.0 / SCALE)), func(pk, kit, _labels): _k("saloon", [pk, kit, Color(0.93, 0.90, 0.80), true]), []])
			parts.append(["Hatch2", Transform3D(Basis(Vector3.UP, PI), Vector3(21.0 / SCALE, 0, 10.0 / SCALE)), func(pk, kit, _labels): _k("hatchback", [pk, kit, Color(0.12, 0.22, 0.42)]), []])
			_road(o + Vector3(8, 0, 0), 40.0, 90.0)
			_scale_figures(o + Vector3(30, 0, 6), true)
		"kaufhaus":
			parts.append(["Kaufhaus", Transform3D.IDENTITY, func(pk, kit, labels): _k("department_store", [pk, kit, labels, 60.0, 40.0]), _k("department_store_solids", [60.0, 40.0])])
			# The pedestrian zone's corridor: the store's front 18 game metres off the route's line, the corridor 10.9 from it.
			_clear_box(o + Vector3(0, 0, 18.0), 10.9, 140.0)
			_scale_figures(o + Vector3(8, 0, 8))
		"brauerei":
			var bk: Script = load("res://BreweryKit.gd")
			parts.append(["Brauerei", Transform3D.IDENTITY, func(pk, kit, labels): bk.brewery(pk, kit, labels), bk.brewery_solids()])
			parts.append(["Biergarten", Transform3D.IDENTITY, func(pk, kit, labels): bk.garden(pk, kit, labels, 4711), bk.garden_solids()])
			_scale_figures(o + Vector3(6, 0, 30))
		"hbf":
			parts.append(["Hauptbahnhof", Transform3D.IDENTITY, func(pk, kit, labels): _k("hauptbahnhof", [pk, kit, labels]), _k("hauptbahnhof_solids", [])])
			# The Kaiserstraße's corridor: its centre line `HBF_STREET` game metres in front of the facade.
			var tz: Array = sks.get_script_constant_map().get("TRACKS_Z", [])
			var mid: float = (float(tz[1]) + float(tz[2])) * 0.5 if tz.size() >= 4 else ((float(tz[0]) + float(tz[-1])) * 0.5 if tz.size() >= 2 else -62.0)
			# The generator puts the facade at RAIL_Z - mid * 1.6 (RAIL_Z -130), the street's line at z = 0.
			var sz: float = 130.0 + mid * SCALE
			print("hbf facade %.1f game metres from the street's line" % sz)
			_clear_box(o + Vector3(0, 0, sz), 10.9, 300.0, true)
			_scale_figures(o + Vector3(30, 0, 14))
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
		mi.transform = Transform3D(lt.basis, o + lt.origin * SCALE)
		root.add_child(mi)
		var t := _tris(mesh)
		var keys: PackedStringArray = []
		for k in mesh.get_surface_count():
			keys.append(mesh.surface_get_name(k))
		print("%s: %d triangles, %d surfaces %s, aabb %s, %d labels (%d ms)" % [part[0], t, mesh.get_surface_count(), ",".join(keys), mesh.get_aabb(), labels.size(),
				Time.get_ticks_msec() - t0])
		tris += t
		if not notext:
			for l in labels:
				_label(l, mi.transform)
		if show_solids and part.size() > 3:
			for sb in part[3]:
				_solid_box(sb, mi.transform)
	return tris


## A StadtKit builder by name (so the preview parses whichever builders exist yet).
func _k(fn: String, args: Array) -> Variant:
	for m in sks.get_script_method_list():
		if m["name"] == fn:
			return sks.callv(fn, args)
	print("MISSING ", fn)
	return []


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


## A solid box [Transform3D (life), size] drawn translucent green in a piece's frame.
func _solid_box(sb: Array, xf: Transform3D) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = (sb[1] as Vector3) * SCALE
	mi.mesh = bm
	bm.material = _trans_mat(Color(0.1, 0.95, 0.3, 0.25))
	var t: Transform3D = sb[0]
	mi.transform = xf * Transform3D(t.basis, t.origin * SCALE)
	root.add_child(mi)


func _trans_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## The grandstand's seats (life, its frame) as little red dots.
func _seats(o: Vector3, seats: Array) -> void:
	if not show_solids:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.1, 0.1)
	sm.material = m
	mm.mesh = sm
	mm.instance_count = seats.size()
	for i in seats.size():
		mm.set_instance_transform(i, Transform3D(Basis(), o + (seats[i] as Vector3) * SCALE))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	root.add_child(mmi)
	print("seats ", seats.size())


## A translucent box over a road corridor (|z - centre| < half, all along x) the generator keeps clear, in front of a building.
func _clear_box(c: Vector3, half: float, length: float, also_road := false) -> void:
	if also_road:
		_road(c, length, half * 2.0, Color(0.25, 0.25, 0.26), true)
	if not show_solids:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(length, 22.0, half * 2.0)
	mi.mesh = bm
	bm.material = _trans_mat(Color(0.9, 0.2, 0.9, 0.12))
	mi.position = c + Vector3(0, 11.0, 0)
	root.add_child(mi)


## A thin wire from a to b (game metres).
func _wire(a: Vector3, b: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.05, a.distance_to(b))
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.24, 0.18)
	bm.material = m
	mi.mesh = bm
	mi.transform = Transform3D(Basis.looking_at(b - a, Vector3.UP), (a + b) * 0.5)
	root.add_child(mi)


## A strip of road through `o`: `w` wide along x, `length` along z (or swapped with `along_x`).
func _road(o: Vector3, w: float, length: float, col := Color(0.2, 0.2, 0.21), along_x := false) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(w, length) if not along_x else Vector2(w, length)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
	pm.material = m
	mi.position = o + Vector3(0, 0.02, 0)
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
	gmat.albedo_color = Color(0.45, 0.44, 0.41)
	gmat.roughness = 1.0
	pm.material = gmat
	gm.position = Vector3(0, -0.07, 0)
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
	env.fog_density = 0.0006
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
