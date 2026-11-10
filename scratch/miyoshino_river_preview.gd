extends SceneTree
## Look-dev for MiyoshinoRiverKit.gd (the Miyoshino GP's rafts, forestry, sawmill, boats, bridges, cliff walk). Windowed:
##   Godot --path . --resolution 1400x850 -s res://scratch/miyoshino_river_preview.gd -- <out_dir>
##       [set=rafts|forestry|sawmill|boats|bridge0|bridge1|suspension|ledge|chute|all] [hw=6] [span=60] [save=<dir>]
##       [name:x,y,z:tx,ty,tz[:fov] ...]   (cameras relative to the set's origin; without any each set shoots its own)
## Life-size props are built with new_kit(1.6), Part B with new_kit(1.0) over a fake valley (banks at y 20, 9m deep) or on
## a 45-degree slope, with a grey strip where the generator's ribbon goes. Blue capsules are 2.9m people, red boxes
## 2.2 x 1.3m RC cars. Prints each piece's triangles and the corridor checks; `save=` writes the meshes as .res (for
## scratch/zfight_scan.gd).

const K = preload("res://MiyoshinoRiverKit.gd")
const PS := 1.6
const ORIGINS := {"rafts": 0.0, "forestry": 400.0, "sawmill": 800.0, "boats": 1200.0, "bridge0": 1600.0, "bridge1": 2000.0, "suspension": 2400.0,
		"ledge": 2800.0, "chute": 3200.0}

var _save_dir := ""
var _hw := 6.0
var _span := 60.0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/miyoshino_river"
	DirAccess.make_dir_recursive_absolute(out)
	var which := "all"
	var shots: Array = []
	for a in args.slice(1):
		if a.begins_with("set="):
			which = a.substr(4)
		elif a.begins_with("save="):
			_save_dir = a.substr(5)
			DirAccess.make_dir_recursive_absolute(_save_dir)
		elif a.begins_with("hw="):
			_hw = float(a.substr(3))
		elif a.begins_with("span="):
			_span = float(a.substr(5))
		else:
			shots.append(a)
	_setup_world()
	var sets: Array = ORIGINS.keys() if which == "all" else Array(which.split(","))
	var user_shots := not shots.is_empty()
	var total := 0
	for s in sets:
		total += _build_set(s)
		if not user_shots:
			shots.append_array(_default_shots(s))
	print("TOTAL triangles ", total)
	var cam := Camera3D.new()
	cam.near = 0.1
	cam.far = 3000.0
	root.add_child(cam)
	cam.make_current()
	for i in 45:
		await process_frame
	var o := Vector3(float(ORIGINS[sets[0]]), 0, 0)
	for a in shots:
		var parts := (a as String).split(":")
		var p := parts[1].split_floats(",")
		var t := parts[2].split_floats(",")
		cam.fov = float(parts[3]) if parts.size() > 3 else 55.0
		var off: Vector3 = o if user_shots else Vector3.ZERO
		cam.global_position = Vector3(p[0], p[1], p[2]) + off
		cam.look_at(Vector3(t[0], t[1], t[2]) + off, Vector3.UP)
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [out, parts[0]])
		print("SHOT ", parts[0])
	quit()


func deck_y(t: float) -> float:
	var u: float = clampf(t / _span, 0.0, 1.0)
	return 20.0 + 1.2 * (1.0 - pow(2.0 * u - 1.0, 2.0))


func valley_y(_x: float, t: float) -> float:
	var u: float = t / _span
	return 20.0 - 9.0 * maxf(0.0, 1.0 - pow(2.0 * u - 1.0, 2.0))


func ledge_pts() -> Array:
	var pts := PackedVector3Array()
	var rts := PackedVector3Array()
	for k in 31:
		var s: float = 2.0 * float(k)
		pts.append(Vector3(_ledge_x(s), 30.0 + 0.08 * s, -s))
	for k in 31:
		var f: Vector3 = (pts[mini(k + 1, 30)] - pts[maxi(k - 1, 0)])
		rts.append(Vector3(f.x, 0, f.z).normalized().cross(Vector3.UP).normalized())
	return [pts, rts]


static func _ledge_x(s: float) -> float:
	return 5.0 * sin(s / 60.0 * PI * 0.9)


func slope_y(x: float, z: float) -> float:
	var s: float = clampf(-z, -20.0, 80.0)
	return 30.0 + 0.08 * s + (_ledge_x(s) - 1.5 - x)


func chute_pts() -> Array:
	var pts := PackedVector3Array()
	var rts := PackedVector3Array()
	for k in 31:
		var s: float = 2.0 * float(k)
		pts.append(Vector3(3.0 * sin(s / 60.0 * PI), 40.0 - 0.2 * s, -s))
	for k in 31:
		var f: Vector3 = (pts[mini(k + 1, 30)] - pts[maxi(k - 1, 0)])
		rts.append(Vector3(f.x, 0, f.z).normalized().cross(Vector3.UP).normalized())
	return [pts, rts]


func chute_ground(x: float, z: float) -> float:
	var s: float = clampf(-z, -20.0, 80.0)
	return 40.0 - 0.2 * s - 0.15 - 5.0 * pow(sin(clampf(s / 60.0, 0.0, 1.0) * PI), 2.0) - 0.08 * (x - 3.0 * sin(s / 60.0 * PI))


func _default_shots(s: String) -> Array:
	var o := Vector3(float(ORIGINS[s]), 0, 0)
	var list: Array = []
	var d := 21.0
	var sp := _span
	match s:
		"rafts":
			list = [["rafts_a", Vector3(14, 7, 16), Vector3(0, 0.5, -2), 50.0], ["rafts_close", Vector3(5, 2.6, 9.5), Vector3(0, 0.6, 3), 50.0],
					["rafts_cargo0", Vector3(-6, 3.5, -8), Vector3(0, 1.2, -13), 50.0], ["rafts_cargo2", Vector3(7, 3, -20), Vector3(0, 1.0, -27), 55.0],
					["rafts_top", Vector3(0.1, 22, 0), Vector3(0, 0, -1), 50.0]]
		"forestry":
			list = [["forestry_a", Vector3(12, 6, 16), Vector3(4, 1, 0), 55.0], ["stack_close", Vector3(-5, 2.5, 8.5), Vector3(-9, 1.5, 0), 50.0],
					["pile_close", Vector3(5, 3, 7), Vector3(2, 0.6, 0), 50.0], ["planks_close", Vector3(14, 2.6, 6), Vector3(11, 1.2, 0), 50.0],
					["kinma", Vector3(24, 2.5, 6), Vector3(20, 0.8, 0), 50.0]]
		"sawmill":
			list = [["sawmill_front", Vector3(13, 6, 26), Vector3(13, 4, -7), 50.0], ["sawmill_wheel", Vector3(-9, 5, 6), Vector3(3, 4.5, -8), 50.0],
					["sawmill_inside", Vector3(12, 3.2, 3.5), Vector3(13, 2.6, -8), 60.0], ["sawmill_back", Vector3(4, 9, -30), Vector3(12, 4, -8), 50.0],
					["sawmill_office", Vector3(30, 4, 8), Vector3(22, 3, -4), 50.0], ["sawmill_under", Vector3(9, 1.6, -1.2), Vector3(13, 6.5, -8), 65.0]]
		"boats":
			list = [["boats_a", Vector3(8, 5, 14), Vector3(2, 0.5, 0), 50.0], ["boat0", Vector3(-9, 2.5, 7), Vector3(-6, 0.4, 0), 45.0],
					["boat2", Vector3(10, 2.6, 8), Vector3(6, 1.2, 0), 45.0], ["boat1", Vector3(3, 2.6, 8), Vector3(0, 0.6, 0), 45.0],
					["yana", Vector3(38, 6, 14), Vector3(29, 1, 2), 50.0], ["yana_hut", Vector3(42, 3, -2), Vector3(37, 3.5, 4), 50.0]]
		"bridge0", "bridge1":
			list = [[s + "_side", Vector3(55, d + 4, -sp * 0.2), Vector3(0, d - 3, -sp * 0.5), 55.0], [s + "_drive", Vector3(0, d + 3.2, 8), Vector3(0, d + 1.5, -30), 65.0],
					[s + "_under", Vector3(24, d - 5.5, -sp * 0.5 + 9), Vector3(0, d - 3, -sp * 0.5 - 4), 65.0], [s + "_end", Vector3(13, d + 3, 9), Vector3(4, d + 1, -3), 55.0],
					[s + "_rail", Vector3(3, d + 2.4, -18), Vector3(8, d + 1.6, -25), 50.0], [s + "_far", Vector3(-70, d + 20, 40), Vector3(0, d - 2, -sp * 0.5), 45.0]]
		"suspension":
			list = [["susp_side", Vector3(60, d + 8, -sp * 0.15), Vector3(0, d + 2, -sp * 0.5), 55.0], ["susp_drive", Vector3(0, d + 3.2, 10), Vector3(0, d + 4, -30), 70.0],
					["susp_under", Vector3(24, d - 5.5, -sp * 0.5 + 9), Vector3(0, d - 1, -sp * 0.5 - 4), 65.0], ["susp_tower", Vector3(16, d + 5, 16), Vector3(0, d + 8, 0), 60.0],
					["susp_net", Vector3(2, d + 2.2, -24), Vector3(8, d + 1.2, -31), 50.0], ["susp_far", Vector3(-75, d + 30, 50), Vector3(0, d + 2, -sp * 0.5), 45.0]]
		"ledge":
			list = [["ledge_side", Vector3(40, 34, -10), Vector3(2, 30, -30), 55.0], ["ledge_drive", Vector3(0.5, 33.5, 6), Vector3(4, 33, -25), 65.0],
					["ledge_under", Vector3(22, 24, -20), Vector3(5, 31, -32), 50.0], ["ledge_rail", Vector3(2, 34.4, -16), Vector3(11, 33, -24), 50.0],
					["ledge_far", Vector3(45, 55, 30), Vector3(3, 31, -30), 45.0]]
		"chute":
			list = [["chute_side", Vector3(34, 40, -10), Vector3(2, 33, -30), 55.0], ["chute_drive", Vector3(0, 43.4, 6), Vector3(2, 36, -25), 65.0],
					["chute_under", Vector3(18, 29, -22), Vector3(2, 32, -32), 50.0], ["chute_wall", Vector3(1, 37.4, -16), Vector3(8, 34.5, -24), 50.0]]
	var outl: Array = []
	for sh in list:
		var p: Vector3 = (sh[1] as Vector3) + o
		var t: Vector3 = (sh[2] as Vector3) + o
		outl.append("%s:%f,%f,%f:%f,%f,%f:%f" % [sh[0], p.x, p.y, p.z, t.x, t.y, t.z, sh[3]])
	return outl


func _rng(seed_v: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	return r


## Builds one set; returns its triangles.
func _build_set(s: String) -> int:
	var o := Vector3(float(ORIGINS[s]), 0, 0)
	var parts: Array = []   # [name, transform, kit scale, builder, check]
	var hw := _hw
	var sp := _span
	match s:
		"rafts":
			_water(o, 90.0)
			var rl: float = 7.5 * PS + 0.6
			for i in 4:
				var z: float = -rl * float(i)
				parts.append(["Raft%d" % i, Transform3D(Basis(), o + Vector3(0, 0, z)), PS, func(pk, kit, _l): K.log_raft(pk, kit, 10, 7.5, _rng(5 + i)), ""])
				if i > 0:
					parts.append(["Cargo%d" % (i - 1), Transform3D(Basis(), o + Vector3(0, 0, z)), PS, func(pk, kit, _l): K.raft_cargo(pk, kit, i - 1, _rng(3)), ""])
			parts.append(["Raft6", Transform3D(Basis(Vector3.UP, 0.4), o + Vector3(-11, 0, 3)), PS, func(pk, kit, _l): K.log_raft(pk, kit, 6, 5.0, _rng(9)), ""])
			_car(o + Vector3(0.5, 0.3 * PS, 1.5), PI * 0.5)
			_person(o + Vector3(3.5, 0.3 * PS, -rl * 3.0))
			_person(o + Vector3(-1.6, 0.3 * PS, -rl - 4.0))
		"forestry":
			parts.append(["LogStack", Transform3D(Basis(), o + Vector3(-9, 0, 0)), PS, func(pk, kit, _l): K.log_stack(pk, kit, 6, 6.0, _rng(2)), ""])
			parts.append(["LogPile", Transform3D(Basis(), o + Vector3(2, 0, 0)), PS, func(pk, kit, _l): K.log_pile(pk, kit, 9, 4.0, _rng(4)), ""])
			parts.append(["PlankStack", Transform3D(Basis(), o + Vector3(11, 0, 0)), PS, func(pk, kit, _l): K.plank_stack(pk, kit), ""])
			parts.append(["Kinma", Transform3D(Basis(), o + Vector3(20, 0, 0)), PS, func(pk, kit, _l): K.kinma_sled(pk, kit, _rng(6)), ""])
			_person(o + Vector3(-3.5, 0, 2))
			_car(o + Vector3(7, 0, 3), 0.0)
		"sawmill":
			parts.append(["Sawmill", Transform3D(Basis(), o), PS, func(pk, kit, labels): K.sawmill(pk, kit, labels), ""])
			parts.append(["Wheel", Transform3D(Basis(Vector3.RIGHT, 0.2), o + K.sawmill_wheel_at() * PS), PS, func(pk, kit, _l): K.water_wheel(pk, kit), ""])
			_person(o + Vector3(15, 0, 2))
			_person(o + Vector3(7.5, 0, -5))
			_car(o + Vector3(20, 0, 4), 0.0)
		"boats":
			_water(o + Vector3(15, 0, 0), 110.0)
			for v in 3:
				parts.append(["Boat%d" % v, Transform3D(Basis(Vector3.UP, 0.2 * float(v - 1)), o + Vector3(-6.0 + 6.0 * float(v), 0, 0)), PS, func(pk, kit, _l): K.river_boat(pk, kit, v), ""])
			parts.append(["Yana", Transform3D(Basis(), o + Vector3(28, 0, 0)), PS, func(pk, kit, _l): K.yana(pk, kit), ""])
			_person(o + Vector3(-3, 0.05, 1))
			_person(o + Vector3(28, 1.0 * PS, 5))
		"bridge0", "bridge1":
			var st: int = 0 if s == "bridge0" else 1
			parts.append([s.capitalize(), Transform3D(Basis(), o), 1.0, func(pk, kit, _l): K.road_bridge(pk, kit, sp, hw, deck_y, valley_y, st), "bridge"])
			_valley(o, hw)
		"suspension":
			parts.append(["Tsuribashi", Transform3D(Basis(), o), 1.0, func(pk, kit, _l): K.suspension_bridge(pk, kit, sp, hw, deck_y, valley_y), "bridge"])
			_valley(o, hw)
		"ledge":
			var lp: Array = ledge_pts()
			var pts := PackedVector3Array()
			for p in (lp[0] as PackedVector3Array):
				pts.append(p + o)
			var gfn := func(x: float, z: float) -> float: return slope_y(x - o.x, z)
			parts.append(["Kakehashi", Transform3D.IDENTITY, 1.0, func(pk, kit, _l): K.ledge_walk(pk, kit, pts, lp[1], hw, 1.0, gfn), ["path", pts, lp[1]]])
			_grid(o, -45.0, 45.0, -80.0, 20.0, 2.0, func(x: float, z: float) -> float: return slope_y(x, z), Color(0.45, 0.43, 0.40))
			_path_strip(pts, lp[1], hw)
			_car(pts[6] + Vector3(1, 0, 0), PI * 0.5)
			_person(pts[10] + Vector3(-3, 0, 0))
		"chute":
			var cp: Array = chute_pts()
			var cpts := PackedVector3Array()
			for p in (cp[0] as PackedVector3Array):
				cpts.append(p + o)
			var cfn := func(x: float, z: float) -> float: return chute_ground(x - o.x, z)
			parts.append(["Shura", Transform3D.IDENTITY, 1.0, func(pk, kit, _l): K.timber_chute(pk, kit, cpts, cp[1], hw, cfn), ["path", cpts, cp[1]]])
			_grid(o, -45.0, 45.0, -80.0, 20.0, 2.0, func(x: float, z: float) -> float: return chute_ground(x, z), Color(0.36, 0.44, 0.26))
			_path_strip(cpts, cp[1], hw)
			_car(cpts[6] + Vector3(1, 0, 0), PI * 0.5)
			_person(cpts[10] + Vector3(-2, 0, 0))
	var tris := 0
	for part in parts:
		var pk = K.new_kit(float(part[2]))
		var kit := {}
		var labels: Array = []
		var t0 := Time.get_ticks_msec()
		(part[3] as Callable).call(pk, kit, labels)
		var check = part[4]
		if check is String and check == "bridge":
			print("CORRIDOR %s: %d triangles inside %s" % [part[0], K.check_corridor(kit, sp, hw, deck_y), K.corridor_notes])
		elif check is Array:
			print("CORRIDOR %s: %d triangles inside %s" % [part[0], K.check_path_corridor(kit, check[1], check[2], hw), K.corridor_notes])
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
		print("%s: %d triangles, aabb %s (%d ms)  [%s]" % [part[0], t, mesh.get_aabb(), Time.get_ticks_msec() - t0, ", ".join(per)])
		tris += t
		if _save_dir != "":
			ResourceSaver.save(mesh, "%s/%s.res" % [_save_dir, part[0]])
		for l in labels:
			_label(l, mi.transform, float(part[2]))
	return tris


func _valley(o: Vector3, hw: float) -> void:
	_grid(o, -70.0, 70.0, -_span - 45.0, 45.0, 1.5, func(x: float, z: float) -> float: return valley_y(x, -z), Color(0.36, 0.44, 0.26))
	var wm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(140, _span)
	wm.mesh = pm
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.16, 0.30, 0.30)
	wmat.roughness = 0.08
	wmat.metallic = 0.3
	pm.material = wmat
	wm.position = o + Vector3(0, 12.2, -_span * 0.5)
	root.add_child(wm)
	var pts := PackedVector3Array()
	var rts := PackedVector3Array()
	var t := -40.0
	while t <= _span + 40.0:
		pts.append(o + Vector3(0, deck_y(t), -t))
		rts.append(Vector3.RIGHT)
		t += 2.0
	_path_strip(pts, rts, hw)
	_car(o + Vector3(-hw * 0.4, deck_y(14.0), -14.0), PI * 0.5)
	_car(o + Vector3(hw - 0.9, deck_y(30.0), -30.0), PI * 0.5)
	_person(o + Vector3(hw - 0.6, deck_y(22.0), -22.0))


## A grey strip where the generator's ribbon goes, with white edge lines.
func _path_strip(pts: PackedVector3Array, rts: PackedVector3Array, hw: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in pts.size() - 1:
		for band in [[-hw, hw, Color(0.33, 0.33, 0.35), 0.0], [-hw + 0.15, -hw + 0.3, Color(0.9, 0.9, 0.85), 0.006], [hw - 0.3, hw - 0.15, Color(0.9, 0.9, 0.85), 0.006]]:
			var a0: Vector3 = pts[i] + rts[i] * float(band[0]) + Vector3(0, band[3], 0)
			var a1: Vector3 = pts[i] + rts[i] * float(band[1]) + Vector3(0, band[3], 0)
			var b0: Vector3 = pts[i + 1] + rts[i + 1] * float(band[0]) + Vector3(0, band[3], 0)
			var b1: Vector3 = pts[i + 1] + rts[i + 1] * float(band[1]) + Vector3(0, band[3], 0)
			st.set_color(band[2])
			st.set_normal(Vector3.UP)
			for p in [a0, a1, b1, a0, b1, b0]:
				st.add_vertex(p)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	root.add_child(mi)


## A ground mesh of fn(x, z) over a grid at `o`.
func _grid(o: Vector3, x0: float, x1: float, z0: float, z1: float, step: float, fn: Callable, col: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx: int = int((x1 - x0) / step)
	var nz: int = int((z1 - z0) / step)
	for i in nx:
		for j in nz:
			var xa: float = x0 + step * float(i)
			var za: float = z0 + step * float(j)
			var q: Array = []
			for c in [[0, 0], [1, 0], [1, 1], [0, 1]]:
				var x: float = xa + step * float(c[0])
				var z: float = za + step * float(c[1])
				q.append(Vector3(x, fn.call(x, z), z))
			var nrm: Vector3 = ((q[3] as Vector3) - (q[0] as Vector3)).cross((q[1] as Vector3) - (q[0] as Vector3)).normalized()
			if nrm.y < 0.0:
				nrm = -nrm
			st.set_color(col.darkened(0.25 * clampf(1.0 - nrm.y, 0.0, 1.0)))
			st.set_normal(nrm)
			for k in [0, 1, 2, 0, 2, 3]:
				st.add_vertex((q[k] as Vector3) + o)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	root.add_child(mi)


func _water(o: Vector3, size: float) -> void:
	var wm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	wm.mesh = pm
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.14, 0.30, 0.32)
	wmat.roughness = 0.1
	wmat.metallic = 0.3
	pm.material = wmat
	wm.position = o
	root.add_child(wm)


func _label(l: Array, xf: Transform3D, s: float) -> void:
	var lab := Label3D.new()
	lab.text = l[0]
	lab.font_size = 64
	lab.pixel_size = float(l[3]) * s / 44.8
	lab.modulate = l[4]
	lab.outline_size = 0
	lab.double_sided = false
	var n: Vector3 = xf.basis * (l[2] as Vector3)
	lab.transform = Transform3D(Basis.looking_at(-n, Vector3.UP), xf * ((l[1] as Vector3) * s))
	if l.size() > 5 and float(l[5]) > 0.0:
		var w: float = ThemeDB.fallback_font.get_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x * lab.pixel_size
		if w > float(l[5]) * s:
			lab.pixel_size *= float(l[5]) * s / w
	root.add_child(lab)


## A 2.2 x 1.3m RC car (a red box) on the surface at `p`, its length along x turned by `yaw`.
func _car(p: Vector3, yaw: float) -> void:
	var car := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.2, 0.7, 1.3)
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


func _setup_world() -> void:
	var gm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(9000, 2000)
	gm.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.36, 0.44, 0.26)
	gmat.roughness = 1.0
	pm.material = gmat
	gm.position = Vector3(1500, -0.02, 0)
	root.add_child(gm)
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
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, -50.0, 0.0)
	sun.light_energy = 1.35
	sun.light_color = Color(1.0, 0.94, 0.84)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 250.0
	root.add_child(sun)
