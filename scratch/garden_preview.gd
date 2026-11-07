extends SceneTree
## Look-dev for the Kronburg GP finale's Botanischer Garten kit (GardenKit.gd): builds a set in memory at SCALE 1.6 on a
## flat lawn under a late-morning sun with shadows, waits for the shaders to compile, and saves a PNG per camera.
## Windowed:
##   Godot --path . --resolution 1600x900 -s res://scratch/garden_preview.gd -- <out_dir>
##       [set=palmhouse|gate|fence|beds|roses|bridge|alpine|belvedere|terrace|fountain|small|all] [sun=<pitch>,<yaw>]
##       [notext=1] [save=<dir>] name:x,y,z:tx,ty,tz[:fov] ...
## Headless (`--headless ... -- headless=1 [set=...]`): builds every piece once, prints its triangles and checks the
## clearances the generator relies on (the Palmenhaus's corridor, the gate's and the rose arch's undersides, the
## bridges' decks), then quits.
## Positions are in game metres (life x 1.6). Each set stands at its own spot (SPOTS); with no cameras given it shoots that
## set's default views (relative to the spot). A 2.2m RC car box (red) and a 2.9m person stand-in (blue) stand by each set.

const GK = preload("res://GardenKit.gd")

const SCALE := 1.6

const SPOTS := {
	"palmhouse": Vector3(0, 0, 0),
	"gate": Vector3(300, 0, 0),
	"fence": Vector3(300, 0, 120),
	"beds": Vector3(-300, 0, 0),
	"roses": Vector3(0, 0, 300),
	"bridge": Vector3(300, 0, 300),
	"alpine": Vector3(-300, 0, 300),
	"belvedere": Vector3(0, 0, -300),
	"terrace": Vector3(300, 0, -300),
	"fountain": Vector3(-300, 0, -300),
	"small": Vector3(600, 0, 0),
}

var save_dir := ""
var headless := false
var failures := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = "/tmp/garden"
	var which := "palmhouse"
	var sun_rot := Vector2(-48.0, 150.0)
	var notext := false
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
		print("CHECKS: %s" % ("all passed" if failures == 0 else "%d FAILED" % failures))
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
		"palmhouse":
			list = [["ph_front", Vector3(-40, 22, 95), Vector3(0, 12, 0), 55.0], ["ph_chase", Vector3(0, 10, 78), Vector3(0, 6, 40), 65.0],
					["ph_portal", Vector3(6, 6, 64), Vector3(0, 12, 50), 60.0], ["ph_inside", Vector3(0, 10, 36), Vector3(0, 9, 0), 70.0],
					["ph_dome_in", Vector3(0, 10, 14), Vector3(0, 26, -6), 75.0], ["ph_side", Vector3(90, 30, 20), Vector3(0, 14, 0), 50.0],
					["ph_far", Vector3(-180, 60, 200), Vector3(0, 15, 0), 35.0], ["ph_wing_in", Vector3(-1, 8, -22), Vector3(4, 7, -50), 70.0]]
		"gate":
			list = [["gate_front", Vector3(-8, 8, 40), Vector3(0, 8, 0), 60.0], ["gate_chase", Vector3(0, 10, 30), Vector3(0, 6, -5), 65.0],
					["gate_close", Vector3(14, 4, 10), Vector3(11, 6, 0), 55.0]]
		"fence":
			list = [["fence", Vector3(-5, 4, 14), Vector3(15, 2, 0), 55.0], ["fence_close", Vector3(18, 2.5, 4), Vector3(18, 2, 0), 55.0]]
		"beds":
			list = [["beds_chase", Vector3(0, 16, 40), Vector3(0, 0, -6), 60.0], ["beds_close", Vector3(-6, 5, 14), Vector3(-8, 0, 0), 55.0],
					["beds_far", Vector3(0, 30, 80), Vector3(0, 0, -6), 45.0], ["beds_border", Vector3(30, 5, 14), Vector3(26, 0.5, -2), 55.0]]
		"roses":
			list = [["roses_chase", Vector3(0, 16, 50), Vector3(0, 8, 0), 60.0], ["roses_in", Vector3(2, 6, 18), Vector3(0, 9, -20), 70.0],
					["roses_side", Vector3(-30, 10, 20), Vector3(0, 7, -10), 55.0], ["rosebed", Vector3(30, 5, 15), Vector3(26, 0.5, -2), 55.0]]
		"bridge":
			list = [["bridge_side", Vector3(-60, 6, 45), Vector3(0, 2, 0), 55.0], ["bridge_chase", Vector3(0, 17, 60), Vector3(0, 7, 10), 65.0],
					["bridge_under", Vector3(-28, 2.5, 10), Vector3(0, 3, -2), 60.0], ["bridge_deck", Vector3(4, 10, 26), Vector3(0, 7, 0), 65.0],
					["bridge_pond", Vector3(-38, 6, -72), Vector3(0, 3, -100), 55.0], ["bridge_pond_deck", Vector3(3, 8, -76), Vector3(0, 5, -100), 65.0]]
		"alpine":
			list = [["alpine", Vector3(-6, 5, 16), Vector3(0, 0.5, 0), 60.0], ["alpine_close", Vector3(-12, 3, 2), Vector3(-6, 0.8, -4), 55.0],
					["alpine_far", Vector3(-20, 14, 30), Vector3(0, 0, 0), 50.0]]
		"belvedere":
			list = [["belvedere", Vector3(-20, 8, 30), Vector3(0, 7, 0), 55.0], ["belvedere_far", Vector3(-50, 25, 60), Vector3(0, 6, 0), 45.0],
					["belvedere_in", Vector3(0, 4.2, 9), Vector3(0, 9, -2), 70.0], ["belvedere_back", Vector3(25, 12, -30), Vector3(0, 8, 0), 50.0]]
		"terrace":
			list = [["terrace", Vector3(-10, 9, 45), Vector3(0, 3, 0), 60.0], ["terrace_steps", Vector3(-8, 5, 30), Vector3(-19.5, 2.5, 6), 55.0],
					["terrace_wall", Vector3(28, 4, 16), Vector3(30, 4, 0), 55.0]]
		"fountain":
			list = [["fountain", Vector3(-14, 10, 22), Vector3(0, 3, 0), 55.0], ["fountain_close", Vector3(-6, 4, 12), Vector3(0, 3.5, 0), 55.0],
					["topiary", Vector3(2, 3.5, 26), Vector3(4, 2, 14), 55.0]]
		"small":
			list = [["small", Vector3(0, 8, 30), Vector3(4, 2, 0), 55.0], ["small_close", Vector3(-6, 3, 16), Vector3(-6, 2, 3), 55.0],
					["statue", Vector3(7, 4, 10), Vector3(4.8, 3.5, 3.2), 45.0], ["greenhouse", Vector3(10, 7, 22), Vector3(22, 3, 0), 55.0],
					["greenhouse_in", Vector3(17, 3, 2), Vector3(29, 1.5, 0), 70.0], ["hedge", Vector3(-24, 4, 6), Vector3(-10, 1, -6.4), 50.0]]
	var outl: Array = []
	for sh in list:
		var p: Vector3 = (sh[1] as Vector3) + o
		var t: Vector3 = (sh[2] as Vector3) + o
		outl.append("%s:%f,%f,%f:%f,%f,%f:%f" % [sh[0], p.x, p.y, p.z, t.x, t.y, t.z, sh[3]])
	return outl


## Builds one set at its spot; returns its triangles.
func _build_set(s: String, notext: bool) -> int:
	var o: Vector3 = SPOTS.get(s, Vector3.ZERO)
	var parts: Array = []   # [name, local transform (life units), builder Callable, check Callable or null]
	match s:
		"palmhouse":
			parts.append(["Palmenhaus", Transform3D.IDENTITY, func(pk, kit, labels): GK.palm_house(pk, kit, labels), Callable(self, "_check_palm_house")])
			_road(o, 10.0 * SCALE, 150.0)
			_scale_figures(o + Vector3(0, 0, 60), true)
			_scale_figures(o + Vector3(-2, 0, 30), true)
		"gate":
			parts.append(["Gate", Transform3D.IDENTITY, func(pk, kit, labels): GK.garden_gate(pk, kit, labels), Callable(self, "_check_gate")])
			_road(o, 7.5 * 2.0, 120.0)
			_scale_figures(o + Vector3(0, 0, 18), true)
		"fence":
			parts.append(["Fence", Transform3D.IDENTITY, func(pk, kit, _labels): GK.garden_fence(pk, kit, 24.0), null])
		"beds":
			parts.append(["BedRings", Transform3D(Basis(), Vector3(-8, 0, 0)), func(pk, kit, _labels): GK.flower_bed(pk, kit, 9.5, 3.6, 0, 0, 3), null])
			parts.append(["BedBorder", Transform3D(Basis(), Vector3(8, 0, 0)), func(pk, kit, _labels): GK.flower_bed(pk, kit, 9.5, 3.6, 3, 1, 4), null])
		"roses":
			for k in range(3):
				var b: float = 6.0 if k < 2 else 0.0
				parts.append(["RoseArch%d" % k, Transform3D(Basis(), Vector3(0, 0, -6.0 * k)), func(pk, kit, _labels): GK.rose_arch(pk, kit, 13.0, b, k + 1), null])
			parts.append(["RoseBed", Transform3D(Basis(), Vector3(16, 0, -6)), func(pk, kit, _labels): GK.rose_bed(pk, kit, 12.0, 3.0, 2), null])
			_road(o, 15.0, 80.0)
		"bridge":
			# The moat bridge (style 0) 4m (game) over the lawn, so its water shows; the pond bridge (style 1) 100m behind it.
			parts.append(["MoatBridge", Transform3D(Basis(), Vector3(0, 4.0 / SCALE, 0)), func(pk, kit, _labels): GK.stone_bridge(pk, kit, 40.0, 2.2, 6.8, -2.125, 0),
					func(kit): _check_bridge(kit, 40.0, 2.2, 6.8, 0)])
			parts.append(["PondBridge", Transform3D(Basis(), Vector3(0, 3.0 / SCALE, -100.0 / SCALE)), func(pk, kit, _labels): GK.stone_bridge(pk, kit, 24.0, 1.0, 4.9, -1.125, 1),
					func(kit): _check_bridge(kit, 24.0, 1.0, 4.9, 1)])
			if not headless:
				_bridge_scene(o + Vector3(0, 4.0, 0), 40.0, 2.2, 6.8125, -2.125)
				_bridge_scene(o + Vector3(0, 3.0, -100.0), 24.0, 1.0, 4.6875, -1.125)
				_scale_figures(o + Vector3(0, 4.0 + 2.2 * SCALE, 0), true)
				_scale_figures(o + Vector3(0, 3.0 + 1.0 * SCALE, -100.0), true)
		"alpine":
			var rng := RandomNumberGenerator.new()
			rng.seed = 77
			for i in range(5):
				for j in range(4):
					var r: float = lerpf(0.5, 1.6, float(i * 4 + j) / 19.0)
					var sv: int = rng.randi()
					parts.append(["Stone%d_%d" % [i, j], Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(-9.0 + 4.5 * i, 0, -6.0 + 4.0 * j)),
							func(pk, kit, _labels): GK.rockery_stone(pk, kit, r, sv), null])
					var cr: float = rng.randf_range(0.35, 0.8)
					var cs: int = rng.randi()
					parts.append(["Cushion%d_%d" % [i, j], Transform3D(Basis(), Vector3(-7.5 + 4.5 * i, 0, -5.0 + 4.0 * j)), func(pk, kit, _labels): GK.alpine_cushion(pk, kit, cr, cs), null])
		"belvedere":
			parts.append(["Belvedere", Transform3D.IDENTITY, func(pk, kit, labels): GK.belvedere(pk, kit, labels), Callable(self, "_check_belvedere")])
			_scale_figures(o + Vector3(14, 0, 14), false)
		"terrace":
			# As the generator lays them out: the terrace's top 5m (game) over the lawn, the road along z on x = 0 dropping off
			# it at z = 0, the walls from 7.8m either side outward 34m (life 21.25), the steps 19.5m to the right (-x).
			var hl: float = 5.0 / SCALE
			var top: float = 5.0 / SCALE
			var x0: float = 7.8 / SCALE
			var ll: float = 34.0 / SCALE
			parts.append(["TerraceWallA", Transform3D(Basis(), Vector3(x0, top, 0)), func(pk, kit, _labels): GK.terrace_wall(pk, kit, ll, hl), func(kit): _check_xrange(kit, "terrace wall", 0.0, ll)])
			parts.append(["TerraceWallB", Transform3D(Basis(), Vector3(-x0 - ll, top, 0)), func(pk, kit, _labels): GK.terrace_wall(pk, kit, ll, hl), null])
			parts.append(["BalustradeA", Transform3D(Basis(), Vector3(x0 + 2.0 / SCALE, top + 0.02 / SCALE, 0)), func(pk, kit, _labels): GK.balustrade(pk, kit, (34.0 - 4.0) / SCALE), null])
			parts.append(["BalustradeB", Transform3D(Basis(), Vector3(-x0 - ll + 2.0 / SCALE, top + 0.02 / SCALE, 0)), func(pk, kit, _labels): GK.balustrade(pk, kit, (34.0 - 4.0) / SCALE), null])
			parts.append(["TerraceSteps", Transform3D(Basis(), Vector3(-19.5 / SCALE, top, 0)), func(pk, kit, _labels): GK.terrace_steps(pk, kit, 4.0, hl), func(kit): _check_xrange(kit, "terrace steps", -2.5, 2.5)])
			if not headless:
				_box_mesh(o + Vector3(0, 2.5, -40.5), Vector3(140, 5.0, 80), Color(0.30, 0.42, 0.18))
				_road(o + Vector3(0, 5.0, -40), 15.0, 80.0, Color(0.20, 0.20, 0.21), 0.05)
				_road(o + Vector3(0, 0, 40), 15.0, 80.0)
				_scale_figures(o + Vector3(0, 0, 14), true)
		"fountain":
			parts.append(["Fountain", Transform3D.IDENTITY, func(pk, kit, _labels): GK.parterre_fountain(pk, kit), null])
			var kinds: Array = ["cone", "ball", "spiral", "column"]
			for k in range(4):
				var kind: String = kinds[k]
				var sz: float = 1.6 if kind == "ball" else 2.4
				parts.append(["Topiary_" + kind, Transform3D(Basis(), Vector3(-6.0 + 4.0 * k, 0, 9.0)), func(pk, kit, _labels): GK.topiary(pk, kit, kind, sz), null])
			parts.append(["Urn", Transform3D(Basis(), Vector3(10.0, 0, 9.0)), func(pk, kit, _labels): GK.urn(pk, kit), null])
			parts.append(["Sundial", Transform3D(Basis(), Vector3(13.0, 0, 9.0)), func(pk, kit, _labels): GK.sundial(pk, kit), null])
			_scale_figures(o + Vector3(12, 0, 6), false)
		"small":
			parts.append(["Greenhouse", Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(14.0, 0, 0)), func(pk, kit, labels): GK.greenhouse_small(pk, kit, labels), null])
			parts.append(["Lamp", Transform3D(Basis(), Vector3(-4.0, 0, 4.0)), func(pk, kit, _labels): GK.park_lamp(pk, kit), null])
			parts.append(["Bench", Transform3D(Basis(), Vector3(-2.0, 0, 3.0)), func(pk, kit, _labels): GK.park_bench(pk, kit), null])
			parts.append(["Label", Transform3D(Basis(), Vector3(0.5, 0, 4.5)), func(pk, kit, labels): GK.plant_label(pk, kit, labels, "Gentiana acaulis"), null])
			parts.append(["Plan", Transform3D(Basis(), Vector3(-8.0, 0, 1.0)), func(pk, kit, labels): GK.garden_sign(pk, kit, labels,
					["BOTANISCHER GARTEN", "Palmenhaus  >", "Rosengarten  >", "Alpinum  >", "Belvedere  >"]), null])
			parts.append(["Statue", Transform3D(Basis(), Vector3(3.0, 0, 2.0)), func(pk, kit, _labels): GK.statue(pk, kit), null])
			parts.append(["Hedge", Transform3D(Basis(), Vector3(-12.0, 0, -4.0)), func(pk, kit, _labels): GK.hedge(pk, kit, 16.0, 1.1, 0.8), null])
			parts.append(["UrnSmall", Transform3D(Basis(), Vector3(6.0, 0, 4.0)), func(pk, kit, _labels): GK.urn(pk, kit), null])
			_scale_figures(o + Vector3(0, 0, 12), false)
	var tris := 0
	for part in parts:
		var pk = GK.new_kit(SCALE)
		var kit := {}
		var labels: Array = []
		var t0 := Time.get_ticks_msec()
		(part[2] as Callable).call(pk, kit, labels)
		if part.size() > 3 and part[3] is Callable and (part[3] as Callable).is_valid():
			(part[3] as Callable).call(kit)
		var t: int = int(PropKit_triangles(kit).size() / 3.0)
		var mesh: ArrayMesh = GK.commit(pk, kit)
		print("%s: %d triangles, %d surfaces, aabb %s (%d ms)" % [part[0], t, mesh.get_surface_count(), mesh.get_aabb(), Time.get_ticks_msec() - t0])
		for k in mesh.get_surface_count():
			var arr: Array = mesh.surface_get_arrays(k)
			var idx = arr[Mesh.ARRAY_INDEX]
			var st: int = int((idx as PackedInt32Array).size() / 3.0) if idx != null else int((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3.0)
			print("    %s: %d" % [mesh.surface_get_name(k), st])
		tris += t
		if save_dir != "":
			ResourceSaver.save(mesh, "%s/%s.res" % [save_dir, part[0]])
		if headless:
			continue
		var mi := MeshInstance3D.new()
		mi.name = part[0]
		mi.mesh = mesh
		var lt: Transform3D = part[1]
		mi.transform = Transform3D(lt.basis, o + lt.origin * SCALE)
		root.add_child(mi)
		if not notext:
			for l in labels:
				_label(l, mi.transform)
	return tris


## The kit's triangles in life metres (its frame divided by SCALE), as an array of [a, b, c, surface key].
func _life_tris(kit: Dictionary, skip: Array = []) -> Array:
	var out: Array = []
	for key in kit.keys():
		if key in skip:
			continue
		var one := {key: kit[key]}
		var tv: PackedVector3Array = PropKit_triangles(one)
		for i in range(0, tv.size(), 3):
			out.append([tv[i] / SCALE, tv[i + 1] / SCALE, tv[i + 2] / SCALE, key])
	return out


func PropKit_triangles(kit: Dictionary) -> PackedVector3Array:
	return preload("res://PropKit.gd").kit_triangles(kit)


## Points spread over a triangle (its corners, edges' middles, its middle and more).
func _samples(a: Vector3, b: Vector3, c: Vector3) -> Array:
	var out: Array = [a, b, c]
	for i in range(0, 5):
		for j in range(0, 5 - i):
			var u: float = float(i) / 4.0
			var v: float = float(j) / 4.0
			out.append(a + (b - a) * u + (c - a) * v)
	return out


func _fail(msg: String) -> void:
	failures += 1
	print("FAIL: ", msg)


## The Palmenhaus's corridor: nothing in |x| <= 5 below 9 m, nothing in |x| <= 6.2 below 9 m but the kerb (<= 0.2 m),
## for |z| <= 34 (life metres).
func _check_palm_house(kit: Dictionary) -> void:
	var bad := 0
	var worst := ""
	for t in _life_tris(kit):
		for p in _samples(t[0], t[1], t[2]):
			var q: Vector3 = p
			if absf(q.z) > 34.0 or q.y >= 9.0 - 1e-3:
				continue
			if absf(q.x) < 5.0 - 1e-3 or (absf(q.x) < 6.2 - 1e-3 and q.y > 0.2 + 1e-3):
				bad += 1
				if worst == "":
					worst = "%s at %s" % [t[3], q]
				break
	if bad > 0:
		_fail("palm house corridor: %d triangles inside it (first: %s)" % [bad, worst])
	else:
		print("ok: palm house corridor clear")


## A bridge's roadway: nothing at |x| < half (life) over the deck's road line (bridge_deck_y) on the bridge, nothing under the
## ribbon's half width within 1.5cm under it (it would fight the ribbon), and the deck's top within 1cm of BRIDGE_UNDER.
func _check_bridge(kit: Dictionary, length: float, rise: float, half: float, style: int) -> void:
	var rib: float = minf(float(GK.BRIDGE_RIBBON[style]), half)
	var over := 0
	var fight := 0
	var worst := ""
	var deck_seen := 0
	for t in _life_tris(kit):
		for p in _samples(t[0], t[1], t[2]):
			var q: Vector3 = p
			if absf(q.z) > length * 0.5 - 0.01:
				continue
			var ry: float = GK.bridge_deck_y(q.z, length, rise)
			if absf(q.x) < half - 1e-3 and q.y > ry - 0.005:
				over += 1
				if worst == "":
					worst = "%s at %s (road %.3f)" % [t[3], q, ry]
				break
			if absf(q.x) < rib - 1e-3 and q.y > ry - 0.015 and q.y <= ry - 0.005:
				fight += 1
				break
			if absf(q.x) < rib - 0.1 and absf(q.y - (ry - GK.BRIDGE_UNDER)) < 0.01:
				deck_seen += 1
	if over > 0:
		_fail("bridge (style %d): %d triangles over the road (first: %s)" % [style, over, worst])
	elif fight > 0:
		_fail("bridge (style %d): %d triangles within 1.5cm under the ribbon" % [style, fight])
	else:
		print("ok: bridge style %d: nothing over the road inside |x| < %.2f; deck samples at road - %.2f: %d" % [style, half, GK.BRIDGE_UNDER, deck_seen])


## The gate: its open leaves and pillars keep |x| >= 6.44 under the overthrow (GATE_ARCH_Y), the urns on the caps.
func _check_gate(kit: Dictionary) -> void:
	var bad := 0
	var worst := ""
	for t in _life_tris(kit):
		for p in _samples(t[0], t[1], t[2]):
			var q: Vector3 = p
			if q.y < GK.GATE_ARCH_Y - 0.05 and absf(q.x) < 6.44 and absf(q.z) < 8.0:
				bad += 1
				if worst == "":
					worst = "%s at %s" % [t[3], q]
				break
	if bad > 0:
		_fail("gate: %d triangles in the road's opening (first: %s)" % [bad, worst])
	else:
		print("ok: gate opening clear")


## A piece keeps to x in [x0, x1] (life).
func _check_xrange(kit: Dictionary, what: String, x0: float, x1: float) -> void:
	var lo := INF
	var hi := -INF
	for t in _life_tris(kit):
		for k in 3:
			lo = minf(lo, (t[k] as Vector3).x)
			hi = maxf(hi, (t[k] as Vector3).x)
	if lo < x0 - 1e-3 or hi > x1 + 1e-3:
		_fail("%s: x %.3f..%.3f outside %.3f..%.3f" % [what, lo, hi, x0, x1])
	else:
		print("ok: %s within x %.3f..%.3f (%.3f..%.3f)" % [what, x0, x1, lo, hi])


## The belvedere keeps to x, z +-5.45 but its stair (|x| <= 2.35, z to 7.6).
func _check_belvedere(kit: Dictionary) -> void:
	var bad := 0
	var worst := ""
	var hi_y := -INF
	for t in _life_tris(kit):
		for k in 3:
			var q: Vector3 = t[k]
			hi_y = maxf(hi_y, q.y)
			var inside: bool = (absf(q.x) <= 5.45 and absf(q.z) <= 5.45) or (absf(q.x) <= 2.35 and q.z > 0.0 and q.z <= 7.6)
			if not inside:
				bad += 1
				if worst == "":
					worst = "%s at %s" % [t[3], q]
	if bad > 0:
		_fail("belvedere: %d corners outside its footprint (first: %s)" % [bad, worst])
	else:
		print("ok: belvedere within its footprint, %.2fm tall" % hi_y)


## The water, a ribbon at the bridge's road line and embankments at its ends, for a bridge whose frame is at `o` (game m).
func _bridge_scene(o: Vector3, length: float, rise: float, rib: float, wy: float) -> void:
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(160, length * SCALE - 8.0)
	water.mesh = pm
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.10, 0.22, 0.24)
	wm.roughness = 0.08
	wm.metallic_specular = 0.9
	pm.material = wm
	water.position = o + Vector3(0, wy * SCALE, 0)
	root.add_child(water)
	for e in [-1.0, 1.0]:
		_box_mesh(o + Vector3(0, -2.5, e * (length * SCALE * 0.5 + 18.0)), Vector3(160, 5.0 - 0.07, 36.0), Color(0.30, 0.42, 0.18))
		_road(o + Vector3(0, 0, e * (length * SCALE * 0.5 + 18.0)), rib * 2.0 * SCALE, 36.0, Color(0.20, 0.20, 0.21), 0.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 80
	for k in range(n):
		var za: float = lerpf(-length * 0.5, length * 0.5, float(k) / n)
		var zb: float = lerpf(-length * 0.5, length * 0.5, float(k + 1) / n)
		var ya: float = GK.bridge_deck_y(za, length, rise) * SCALE
		var yb: float = GK.bridge_deck_y(zb, length, rise) * SCALE
		var w: float = rib * SCALE
		var a := Vector3(-w, ya, za * SCALE)
		var b := Vector3(w, ya, za * SCALE)
		var c := Vector3(w, yb, zb * SCALE)
		var d := Vector3(-w, yb, zb * SCALE)
		st.set_normal(Vector3.UP)
		# Godot's front faces wind clockwise seen from the front (above).
		for v in [a, b, c, a, c, d]:
			st.add_vertex(o + v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.22, 0.22, 0.23)
	m.roughness = 0.9
	mi.material_override = m
	root.add_child(mi)


func _box_mesh(c: Vector3, size: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 1.0
	bm.material = m
	mi.position = c
	root.add_child(mi)


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


## A strip of road along z through `o`, `w` wide (game metres), `length` long.
func _road(o: Vector3, w: float, length: float, col := Color(0.20, 0.20, 0.21), lift := 0.03) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(w, length)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
	pm.material = m
	mi.position = o + Vector3(0, lift, 0)
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
	man.position = p + Vector3(4.5 if on_road else 2.5, 1.45, 0)
	root.add_child(man)


func _setup_world(sun_rot: Vector2) -> void:
	var gm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(4000, 4000)
	gm.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.30, 0.42, 0.18)
	gmat.roughness = 1.0
	pm.material = gmat
	gm.position = Vector3(0, -0.02, 0)
	root.add_child(gm)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.30, 0.50, 0.82)
	sm.sky_horizon_color = Color(0.78, 0.84, 0.90)
	sm.ground_bottom_color = Color(0.30, 0.33, 0.26)
	sm.ground_horizon_color = Color(0.70, 0.74, 0.70)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.8
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_hdr_threshold = 1.3
	env.fog_enabled = true
	env.fog_light_color = Color(0.80, 0.84, 0.88)
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
	sun.directional_shadow_max_distance = 400.0
	root.add_child(sun)
