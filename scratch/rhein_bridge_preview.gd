extends SceneTree
## Look-dev for Rheinufer's bridges and motorway furniture (RheinBridgeKit.gd). Windowed:
##   Godot --path . --resolution 1400x850 -s res://scratch/rhein_bridge_preview.gd -- <out_dir>
##       [set=old|harp|piers|furniture|towers|all] [sun=<pitch>,<yaw>] [notext=1] [save=<dir>] name:x,y,z:tx,ty,tz[:fov] ...
## The two bridges stand where the stage puts them (the old one along x at world z +200, the motorway bridge's median at
## world z -360), over a river (water y 0, x -180..180, bed -6) between flat banks (the west floodplain +3 and its dyke,
## crown +10 at x -345; the east promenade +3.5, the town +9 from x 200), with flat stand-in road strips where the generator's
## ribbons go and red RC-car boxes (2.2m) on them; blue 2.9m capsules are people. The game-metre builders are built with
## new_kit(1.0), the life-size ones with new_kit(1.6), on flat ground round x 1600 (SET_O). Prints each piece's triangles and
## the clearance checks (RheinBridgeKit.check_clearance); `save=<dir>` writes each mesh as .res (for scratch/zfight_scan.gd).
## Without cameras each set shoots its own views.

const K = preload("res://RheinBridgeKit.gd")
const PS := 1.6
const OLD_Z := 200.0
const HARP_Z := -360.0
const SET_O := Vector3(1650, 0, 0)

var _save_dir := ""


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/rhein_bridges"
	DirAccess.make_dir_recursive_absolute(out)
	var which := "old"
	var sun_rot := Vector2(-30.0, -60.0)
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
			_save_dir = a.substr(5)
			DirAccess.make_dir_recursive_absolute(_save_dir)
		else:
			shots.append(a)
	_setup_world(sun_rot)
	var sets: Array = ["old", "harp", "piers", "furniture", "towers"] if which == "all" else Array(which.split(","))
	var total := 0
	for s in sets:
		total += _build_set(s, notext)
	print("TOTAL triangles ", total)
	if shots.is_empty():
		for s in sets:
			shots.append_array(_default_shots(s))
	var cam := Camera3D.new()
	cam.near = 0.1
	cam.far = 4500.0
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


static func old_deck(x: float) -> float:
	if x >= 0.0:
		return 15.5 - 6.5 * pow(x / 202.0, 2.0)
	return 15.5 - 5.5 * pow(x / 310.0, 2.0)


static func harp_deck(x: float) -> float:
	if x >= -180.0:
		return 23.0 - 2.0 * pow(x / 180.0, 2.0)
	return lerpf(21.0, 17.0, (-180.0 - x) / 165.0)


static func ground(x: float) -> float:
	if x > 1350.0:
		return 0.0
	if x > 200.0:
		return 9.0
	if x > 180.0:
		return 3.5
	if x < -180.0:
		var g: float = 3.0 if x > -345.0 else 4.5
		var dk: float = absf(x + 345.0)
		return maxf(g, 10.0 - maxf(dk - 3.0, 0.0) / 3.0)
	var e: float = minf(x + 180.0, 180.0 - x)
	return maxf(-6.0, 1.5 - e * 0.4)


func _default_shots(s: String) -> Array:
	var list: Array = []
	match s:
		"old":
			var oz := OLD_Z
			list = [
				["old_drive3", Vector3(178, old_deck(178) + 3, oz - 3.75), Vector3(60, old_deck(60) + 3, oz - 3.75), 70.0],
				["old_drive9", Vector3(140, old_deck(140) + 9, oz), Vector3(30, old_deck(30) + 6, oz), 70.0],
				["old_under_arch", Vector3(70, old_deck(70) + 3, oz + 3.5), Vector3(-10, old_deck(-10) + 18, oz), 72.0],
				["old_east_entry", Vector3(245, 12.5, oz - 4), Vector3(170, 17, oz), 60.0],
				["old_bank_east", Vector3(192, 6, oz + 75), Vector3(70, 22, oz), 55.0],
				["old_bank_west", Vector3(-268, 6, oz - 75), Vector3(-165, 14, oz), 55.0],
				["old_river", Vector3(30, 2.5, oz - 170), Vector3(0, 22, oz), 55.0],
				["old_far", Vector3(430, 110, oz + 560), Vector3(-40, 15, oz), 45.0],
				["old_walkway", Vector3(92, old_deck(92) + 2.9, oz + 11.2), Vector3(-10, old_deck(-10) + 3, oz + 11.2), 65.0],
				["old_towers_west", Vector3(-168, old_deck(-168) + 3, oz - 2), Vector3(-205, old_deck(-205) + 17, oz), 62.0],
				["old_flood", Vector3(-255, 4.6, oz + 48), Vector3(-262, 9, oz), 60.0],
				["old_pier", Vector3(135, 5, oz + 38), Vector3(110, 8, oz + 6), 55.0],
			]
		"harp":
			var hz := HARP_Z
			list = [
				["harp_drive3", Vector3(-292, harp_deck(-292) + 3, hz + 13), Vector3(-170, harp_deck(-170) + 7, hz + 13), 70.0],
				["harp_drive9", Vector3(-60, harp_deck(-60) + 9, hz + 13), Vector3(60, harp_deck(60) + 5, hz + 13), 70.0],
				["harp_pylon", Vector3(-188, harp_deck(-188) + 2.5, hz + 9), Vector3(-150, 62, hz), 66.0],
				["harp_bank_east", Vector3(206, 10.5, hz + 170), Vector3(-60, 30, hz), 50.0],
				["harp_river", Vector3(-40, 2, hz - 120), Vector3(-150, 30, hz), 55.0],
				["harp_far", Vector3(-650, 130, hz + 800), Vector3(-60, 30, hz), 45.0],
				["harp_under", Vector3(-95, 3, hz + 45), Vector3(-30, 14, hz), 62.0],
				["harp_west_end", Vector3(-300, 9, hz + 60), Vector3(-345, 12, hz), 55.0],
			]
		"piers":
			list = [["piers", SET_O + Vector3(-50, 14, 70), SET_O + Vector3(95, 9, 0), 55.0],
					["piers_close", SET_O + Vector3(-22, 6, 26), SET_O + Vector3(0, 9, 0), 60.0]]
		"furniture":
			var f: Vector3 = SET_O + Vector3(0, 0, 300)
			list = [["furniture", f + Vector3(-45, 16, 70), f + Vector3(0, 6, 0), 55.0],
					["gantry_drive", f + Vector3(3, 4.5, 75), f + Vector3(0, 9, 0), 62.0],
					["closure", f + Vector3(14, 4, 40), f + Vector3(6, 2, 18), 60.0],
					["roadside", f + Vector3(22, 3.5, -45), f + Vector3(16, 2, -20), 60.0]]
		"towers":
			var tw: Vector3 = SET_O + Vector3(0, 0, 700)
			list = [["towers", tw + Vector3(-260, 40, -120), tw + Vector3(0, 50, 260), 50.0],
					["tower_close", tw + Vector3(-45, 12, -40), tw + Vector3(0, 42, 0), 55.0],
					["tower_crossing", tw + Vector3(-140, 30, 470), tw + Vector3(0, 120, 680), 50.0]]
	var outl: Array = []
	for sh in list:
		var p: Vector3 = sh[1]
		var t: Vector3 = sh[2]
		outl.append("%s:%f,%f,%f:%f,%f,%f:%f" % [sh[0], p.x, p.y, p.z, t.x, t.y, t.z, sh[3]])
	return outl


## Builds one set; returns its triangles.
func _build_set(s: String, notext: bool) -> int:
	var parts: Array = []   # [name, transform (world), kit scale, builder Callable, check]
	match s:
		"old":
			parts.append(["AlteRheinbruecke", Transform3D(Basis(), Vector3(0, 0, OLD_Z)), 1.0,
					func(pk, kit, labels): K.old_bridge(pk, kit, labels, old_deck, ground), "old"])
			_road_strip(-345.0, 262.0, OLD_Z, [[-7.5, 7.5]], _old_road_y)
			_block(Vector3(-345, 0, OLD_Z - 13.5), Vector3(-310, 10.0 - 0.06, OLD_Z + 13.5), Color(0.33, 0.45, 0.22))
			for c in [[165.0, -3.75], [62.0, 3.75], [0.0, -3.75], [-80.0, 3.75], [-250.0, -3.75]]:
				_car(Vector3(c[0], old_deck(c[0]), OLD_Z + c[1]), 0.0)
			for p in [[100.0, 11.2], [-240.0, -11.0], [70.0, -11.3]]:
				_person(Vector3(p[0], old_deck(p[0]) + 0.18, OLD_Z + p[1]))
		"harp":
			parts.append(["A47Rheinbruecke", Transform3D(Basis(), Vector3(0, 0, HARP_Z)), 1.0,
					func(pk, kit, labels): K.harp_bridge(pk, kit, labels, harp_deck, ground), "harp"])
			_road_strip(-430.0, 262.0, HARP_Z, [[5.5, 20.5], [-20.5, -5.5]], _harp_road_y)
			_block(Vector3(-440, 0, HARP_Z - 24), Vector3(-346.6, 17.0 - 0.06, HARP_Z + 24), Color(0.33, 0.45, 0.22))
			for c in [[-300.0, 9.0], [-160.0, 13.0], [-100.0, 17.0], [60.0, 9.0], [150.0, 13.0], [-60.0, -9.0], [40.0, -15.0]]:
				_car(Vector3(c[0], harp_deck(c[0]), HARP_Z + c[1]), 0.0)
		"piers":
			parts.append(["Pfeiler0", Transform3D(Basis(), SET_O), 1.0, func(pk, kit, _l): K.viaduct_pier(pk, kit, 14.0, 0.0, 9.0, 0), ""])
			parts.append(["Pfeiler1", Transform3D(Basis(), SET_O + Vector3(55, 0, 0)), 1.0, func(pk, kit, _l): K.viaduct_pier(pk, kit, 12.0, 0.0, 8.0, 1), ""])
			parts.append(["Widerlager0", Transform3D(Basis(), SET_O + Vector3(110, 0, 0)), 1.0, func(pk, kit, _l): K.abutment(pk, kit, 9.0, 10.0, 0.0, 14.0), ""])
			parts.append(["Widerlager1", Transform3D(Basis(), SET_O + Vector3(165, 0, 0)), 1.0, func(pk, kit, _l): K.abutment(pk, kit, 8.0, 8.0, 0.0, 12.0, 2.4, 1), ""])
			# Stand-in girders on the bearings.
			_block(SET_O + Vector3(-6.0, 14.4, -14), SET_O + Vector3(6.0, 16.8, 14), Color(0.62, 0.62, 0.6))
			_block(SET_O + Vector3(55 - 5.5, 12.4, -14), SET_O + Vector3(55 + 5.5, 14.8, 14), Color(0.62, 0.62, 0.6))
			_block(SET_O + Vector3(110 - 6.0, 10.4, 0.05), SET_O + Vector3(110 + 6.0, 12.8, 22), Color(0.62, 0.62, 0.6))
			_block(SET_O + Vector3(165 - 5.5, 8.4, 0.05), SET_O + Vector3(165 + 5.5, 10.8, 20), Color(0.62, 0.62, 0.6))
			_person(SET_O + Vector3(8, 0, 6))
			_car(SET_O + Vector3(12, 0, 8), PI * 0.5)
		"furniture":
			var f: Vector3 = SET_O + Vector3(0, 0, 300)
			# A carriageway along z: 3 lanes and a shoulder (life 13.5m), the median barrier on its -x side.
			var hw: float = 6.75 * PS
			_road_strip_z(f, -120.0, 120.0, -hw, hw)
			parts.append(["Schilderbruecke", Transform3D(Basis(), f), PS, func(pk, kit, labels): K.sign_gantry(pk, kit, labels, 7.6, 5.4,
					[[-3.4, 5.6, "A 47 Marlbrück", "Weidenhoven", "vv"], [3.0, 4.4, "A 58 Oberhorst", "Kronburg-Rheinufer", "/"]]), ""])
			parts.append(["Ausfahrt", Transform3D(Basis(), f + Vector3(hw + 4.0, 0, -30)), PS, func(pk, kit, labels): K.exit_sign(pk, kit, labels, 12, "Kronburg-Rheinufer"), ""])
			parts.append(["Notrufsaeule", Transform3D(Basis(Vector3.UP, -PI * 0.5), f + Vector3(hw + 2.5, 0, -12)), PS, func(pk, kit, _l): K.notrufsaeule(pk, kit), ""])
			parts.append(["Laermschutzwand", Transform3D(Basis(Vector3.UP, PI * 0.5), f + Vector3(hw + 8.0, 0, 60)), PS, func(pk, kit, _l): K.noise_wall(pk, kit, 60.0, 4.5, 0.34), ""])
			parts.append(["Betonschutzwand", Transform3D(Basis(Vector3.UP, PI * 0.5), f + Vector3(-hw - 1.0, 0, 70)), PS, func(pk, kit, _l): K.concrete_barrier(pk, kit, 90.0), ""])
			parts.append(["Schutzplanke", Transform3D(Basis(Vector3.UP, PI * 0.5), f + Vector3(hw + 1.2, 0, 70)), PS, func(pk, kit, _l): K.guardrail(pk, kit, 90.0), ""])
			parts.append(["Vollsperrung", Transform3D(Basis(), f + Vector3(0, 0, 18)), PS, func(pk, kit, labels): K.race_closure(pk, kit, labels, 13.0), ""])
			parts.append(["KmTafel", Transform3D(Basis(Vector3.UP, -PI * 0.5), f + Vector3(hw + 2.6, 0, -40)), PS, func(pk, kit, labels): K.kilometre_board(pk, kit, labels, 12.4), ""])
			_car(f + Vector3(-3.0, 0, 40), PI * 0.5)
			_person(f + Vector3(hw + 4.0, 0, -14))
		"towers":
			var tw: Vector3 = SET_O + Vector3(0, 0, 700)
			var spots: Array = [[tw, 0, 52.0], [tw + Vector3(0, 0, 330), 0, 52.0], [tw + Vector3(0, 0, 680), 1, 135.0]]
			for i in spots.size():
				var sp: Array = spots[i]
				var h: float = sp[2]
				var st: int = sp[1]
				parts.append(["Strommast%d" % i, Transform3D(Basis(), sp[0]), PS, func(pk, kit, _l): K.transmission_tower(pk, kit, h, st), ""])
			parts.append(["Leiterseile", Transform3D.IDENTITY, 1.0, func(pk, kit, _l): _conductors(pk, kit, spots), ""])
			_person(tw + Vector3(-12, 0, -8))
			_car(tw + Vector3(-16, 0, -10), 0.0)
	var tris := 0
	for part in parts:
		var pk = K.new_kit(float(part[2]))
		var kit := {}
		var labels: Array = []
		var t0 := Time.get_ticks_msec()
		(part[3] as Callable).call(pk, kit, labels)
		var check: String = part[4]
		if check == "old":
			var r: Array = K.check_clearance(kit, old_deck, K.OB_BANDS, K.OB_WEST, K.OB_EAST)
			print("CLEARANCE old: %d triangles in the road's box %s" % [r[0], r[1]])
		elif check == "harp":
			var r2: Array = K.check_clearance(kit, harp_deck, K.HB_BANDS, K.HB_X0, K.HB_X1)
			print("CLEARANCE harp: %d triangles in the road's box %s" % [r2[0], r2[1]])
		var mesh: ArrayMesh = K.commit(pk, kit)
		var mi := MeshInstance3D.new()
		mi.name = part[0]
		mi.mesh = mesh
		mi.transform = part[1]
		root.add_child(mi)
		var t := 0
		var per := PackedStringArray()
		for k in mesh.get_surface_count():
			var arr: Array = mesh.surface_get_arrays(k)
			var idx = arr[Mesh.ARRAY_INDEX]
			var n: int = int((idx as PackedInt32Array).size() / 3.0) if idx != null else int((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3.0)
			t += n
			per.append("%s %d" % [mesh.surface_get_name(k), n])
		print("%s: %d triangles, %d surfaces, aabb %s (%d ms)  [%s]" % [part[0], t, mesh.get_surface_count(), mesh.get_aabb(), Time.get_ticks_msec() - t0, ", ".join(per)])
		tris += t
		if _save_dir != "":
			ResourceSaver.save(mesh, "%s/%s.res" % [_save_dir, part[0]])
		if not notext:
			for l in labels:
				_label(l, mi.transform, float(part[2]))
	return tris


static func _old_road_y(x: float) -> float:
	return 9.04 if x > 202.0 else (10.0 if x < -310.0 else old_deck(x))


static func _harp_road_y(x: float) -> float:
	return 17.0 if x < -345.0 else harp_deck(x)


## The conductors and earth wires between consecutive towers [origin, style, h] (game metres).
static func _conductors(pk, kit: Dictionary, spots: Array) -> void:
	for i in spots.size() - 1:
		var a: Array = spots[i]
		var b: Array = spots[i + 1]
		var pa: Array = K.conductor_points(float(a[2]), int(a[1]))
		var pb: Array = K.conductor_points(float(b[2]), int(b[1]))
		for k in mini(pa.size(), pb.size()):
			var p0: Vector3 = (a[0] as Vector3) + (pa[k] as Vector3) * PS
			var p1: Vector3 = (b[0] as Vector3) + (pb[k] as Vector3) * PS
			K.conductor(pk, kit, p0, p1, p0.distance_to(p1) * 0.035, 0.07)
		var ea: Array = K.earthwire_points(float(a[2]), int(a[1]))
		var eb: Array = K.earthwire_points(float(b[2]), int(b[1]))
		for k in maxi(ea.size(), eb.size()):
			var p0: Vector3 = (a[0] as Vector3) + (ea[mini(k, ea.size() - 1)] as Vector3) * PS
			var p1: Vector3 = (b[0] as Vector3) + (eb[mini(k, eb.size() - 1)] as Vector3) * PS
			K.conductor(pk, kit, p0, p1, p0.distance_to(p1) * 0.03, 0.05)


## A Label3D from [text, position (kit units), outward normal, cap height, colour, width] in a piece's frame; `s` the kit's
## scale (life-size kits' labels are in life units).
func _label(l: Array, xf: Transform3D, s: float) -> void:
	var lab := Label3D.new()
	lab.text = l[0]
	lab.font_size = 64
	lab.pixel_size = float(l[3]) * s / 44.8
	lab.modulate = l[4]
	lab.outline_size = 0
	lab.double_sided = false
	var n: Vector3 = xf.basis * (l[2] as Vector3)
	var basis := Basis.looking_at(-n, Vector3.UP if absf(n.y) < 0.95 else Vector3.BACK)
	lab.transform = Transform3D(basis, xf * ((l[1] as Vector3) * s))
	if l.size() > 5 and float(l[5]) > 0.0:
		var font: Font = ThemeDB.fallback_font
		var w: float = font.get_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x * lab.pixel_size
		var max_w: float = float(l[5]) * s
		if w > max_w:
			lab.pixel_size *= max_w / w
	root.add_child(lab)


## Flat stand-in road strips along x at world z0 + band, following yfn(x), with edge lines and a dashed centre line.
func _road_strip(x0: float, x1: float, z0: float, bands: Array, yfn: Callable) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = int((x1 - x0) / 2.0)
	for b in bands:
		var za: float = z0 + float(b[0])
		var zb: float = z0 + float(b[1])
		var segs: Array = [[za, zb, Color(0.17, 0.17, 0.18), 0.0], [za + 0.25, za + 0.45, Color(0.9, 0.9, 0.86), 0.005], [zb - 0.45, zb - 0.25, Color(0.9, 0.9, 0.86), 0.005]]
		var zm: float = (za + zb) * 0.5
		for i in n:
			var xa: float = lerpf(x0, x1, float(i) / float(n))
			var xb: float = lerpf(x0, x1, float(i + 1) / float(n))
			var ya: float = yfn.call(xa)
			var yb: float = yfn.call(xb)
			var lst: Array = segs.duplicate()
			if i % 6 < 3:
				lst.append([zm - 0.1, zm + 0.1, Color(0.9, 0.9, 0.86), 0.005])
			for sg in lst:
				var c: Color = sg[2]
				var dy: float = sg[3]
				st.set_color(c)
				st.set_normal(Vector3.UP)
				st.add_vertex(Vector3(xa, ya + dy, float(sg[0])))
				st.add_vertex(Vector3(xb, yb + dy, float(sg[1])))
				st.add_vertex(Vector3(xb, yb + dy, float(sg[0])))
				st.add_vertex(Vector3(xa, ya + dy, float(sg[0])))
				st.add_vertex(Vector3(xa, ya + dy, float(sg[1])))
				st.add_vertex(Vector3(xb, yb + dy, float(sg[1])))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	root.add_child(mi)


## A flat carriageway along z (x from xa to xb) at y 0.03, at `o`.
func _road_strip_z(o: Vector3, z0: float, z1: float, xa: float, xb: float) -> void:
	_block(o + Vector3(xa, 0.0, z0), o + Vector3(xb, 0.03, z1), Color(0.17, 0.17, 0.18))
	for x in [xa + 0.3, xb - 0.3]:
		_block(o + Vector3(x - 0.12, 0.03, z0), o + Vector3(x + 0.12, 0.04, z1), Color(0.9, 0.9, 0.86))


func _block(lo: Vector3, hi: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = hi - lo
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.95
	bm.material = m
	mi.position = (lo + hi) * 0.5
	root.add_child(mi)


## A 2.2m RC car (a red box) on the surface at `p`, its length along x turned by `yaw`.
func _car(p: Vector3, yaw: float) -> void:
	var car := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.2, 0.7, 1.2)
	car.mesh = bm
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.85, 0.1, 0.08)
	bm.material = cm
	car.transform = Transform3D(Basis(Vector3.UP, yaw), p + Vector3(0, 0.4, 0))
	root.add_child(car)


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
	# The ground: the profile ground(x) along x, the same at every z.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var xs: Array = []
	var x := -1200.0
	while x <= 2800.0:
		xs.append(x)
		x += 1.0 if absf(x) < 400.0 else 4.0
	var z0 := -1800.0
	var z1 := 1800.0
	for i in xs.size() - 1:
		var xa: float = xs[i]
		var xb: float = xs[i + 1]
		var ya: float = ground(xa)
		var yb: float = ground(xb)
		var c: Color = _ground_col((xa + xb) * 0.5, (ya + yb) * 0.5)
		var nrm := Vector3(-(yb - ya), xb - xa, 0).normalized()
		st.set_color(c)
		st.set_normal(nrm)
		st.add_vertex(Vector3(xa, ya, z0))
		st.add_vertex(Vector3(xb, yb, z1))
		st.add_vertex(Vector3(xb, yb, z0))
		st.add_vertex(Vector3(xa, ya, z0))
		st.add_vertex(Vector3(xa, ya, z1))
		st.add_vertex(Vector3(xb, yb, z1))
	var gm := MeshInstance3D.new()
	gm.mesh = st.commit()
	var gmat := StandardMaterial3D.new()
	gmat.vertex_color_use_as_albedo = true
	gmat.roughness = 1.0
	gmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	gm.material_override = gmat
	root.add_child(gm)
	# The river.
	var wm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(372, 3600)
	wm.mesh = pm
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.13, 0.20, 0.19)
	wmat.roughness = 0.06
	wmat.metallic = 0.35
	pm.material = wmat
	wm.position = Vector3(0, 0.0, 0)
	root.add_child(wm)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.30, 0.48, 0.80)
	sm.sky_horizon_color = Color(0.85, 0.80, 0.72)
	sm.ground_bottom_color = Color(0.40, 0.39, 0.36)
	sm.ground_horizon_color = Color(0.72, 0.70, 0.66)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.75
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.fog_enabled = true
	env.fog_density = 0.00012
	env.fog_sky_affect = 0.0
	env.fog_light_color = Color(0.80, 0.80, 0.80)
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_hdr_threshold = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(sun_rot.x, sun_rot.y, 0.0)
	sun.light_energy = 1.35
	sun.light_color = Color(1.0, 0.92, 0.80)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 900.0
	root.add_child(sun)


func _ground_col(x: float, y: float) -> Color:
	if x > 1350.0:
		return Color(0.47, 0.47, 0.45)
	if x > 200.0:
		return Color(0.55, 0.54, 0.50)
	if x > 180.0:
		return Color(0.62, 0.58, 0.50)
	if y < 1.0:
		return Color(0.42, 0.37, 0.29)
	return Color(0.34, 0.46, 0.22)
