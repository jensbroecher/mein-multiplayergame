extends SceneTree
## Look-dev for Rheinufer's promenade and fun fair kit (RheinStadtKit.gd): builds a set in memory on flat ground at the stage's
## PROP_SCALE (1.6) under a low early-evening sun with shadows, with stand-in people (2.9m) and an RC car (a 2.2m box) for
## scale, prints each asset's triangles and saves a PNG per camera. Windowed:
##   Godot --path . --resolution 1400x850 -s res://scratch/rhein_stadt_preview.gd -- <out_dir>
##       [set=houses|corner|hotel|steps|promenade|wheel|swing|stalls|tent|kirmes|all] [seed=N] [clock=<s>] [far=1] [keys=1]
##       name:x,y,z:tx,ty,tz[:fov] ...
## Without cameras each set has its own. Buildings stand along +x with their fronts toward +z; the street lies in front of
## them (z 4..14). `far=1` (houses) builds the far versions too, 320m along x, and shoots both rows from the same angles. `clock=` holds the rides' clocks (the
## wheel and the chain swing) at that many seconds into their cycle.

const PS := 1.6
static var K: Object = null

var _root: Node3D
var _assets: Array = []    # [name, MeshInstance3D, origin, size (world)]
var _clock := 30.0


func _init() -> void:
	K = load("res://RheinStadtKit.gd")
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/rhein_preview"
	DirAccess.make_dir_recursive_absolute(out)
	var which := "houses"
	var seed_v := 7
	var far := false
	var shots: Array = []
	for a in args.slice(1):
		if a.begins_with("set="):
			which = a.substr(4)
		elif a.begins_with("seed="):
			seed_v = int(a.substr(5))
		elif a.begins_with("clock="):
			_clock = float(a.substr(6))
		elif a == "far=1":
			far = true
		elif a.contains(":"):
			var parts := String(a).split(":")
			if parts.size() >= 3:
				var p := parts[1].split_floats(",")
				var t := parts[2].split_floats(",")
				shots.append([parts[0], Vector3(p[0], p[1], p[2]), Vector3(t[0], t[1], t[2]), float(parts[3]) if parts.size() > 3 else 50.0])
	_setup_world()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var defaults: Array = []
	match which:
		"houses":
			defaults = _set_houses(rng, far)
		"corner":
			defaults = _set_corner(rng)
		"hotel":
			defaults = _set_hotel()
		"steps":
			defaults = _set_steps()
		"promenade":
			defaults = _set_promenade()
		"wheel":
			defaults = _set_wheel(Vector3.ZERO)
		"swing":
			defaults = _set_swing(Vector3.ZERO)
		"stalls":
			defaults = _set_stalls()
		"tent":
			defaults = _set_tent()
		"kirmes":
			defaults = _set_kirmes()
		"all":
			defaults = _set_houses(rng, false)
			_set_kirmes_at(Vector3(0, 0, 160))
			defaults = [["all", Vector3(-60, 60, 260), Vector3(60, 10, 60), 50.0]]
	var tris := 0
	for a in _assets:
		var mi: MeshInstance3D = a[1]
		var t := _tris(mi.mesh)
		tris += t
		print("  %s: %d surfaces, %d triangles, size %s (life %s)" % [a[0], mi.mesh.get_surface_count(), t, str((a[3] as Vector3).snapped(Vector3.ONE * 0.1)),
				str(((a[3] as Vector3) / PS).snapped(Vector3.ONE * 0.1))])
	print("triangles ", tris)
	if args.has("keys=1"):
		for a in _assets:
			var m: Mesh = (a[1] as MeshInstance3D).mesh
			var parts: Array = []
			for si in m.get_surface_count():
				var idx = m.surface_get_arrays(si)[Mesh.ARRAY_INDEX]
				parts.append("%s:%d" % [str(m.surface_get_name(si)), (idx as PackedInt32Array).size() / 3])
			print("    ", a[0], " ", ", ".join(parts))
	if shots.is_empty():
		shots = defaults
	var cam := Camera3D.new()
	cam.far = 3000.0
	cam.near = 0.1
	_root.add_child(cam)
	cam.current = true
	for i in range(45):
		await process_frame
	for s in shots:
		cam.fov = s[3]
		cam.look_at_from_position(s[1], s[2])
		for i in range(6):
			await process_frame
		await RenderingServer.frame_post_draw
		var path: String = out.path_join("%s.png" % s[0])
		get_root().get_texture().get_image().save_png(path)
		print("SHOT ", path)
	quit()


# ======================================================================================
#  Sets
# ======================================================================================

## A row of houses along a street: each variant at 4 and 5 storeys, widths 11 to 17m, with a car and people in front.
func _set_houses(rng: RandomNumberGenerator, far: bool) -> Array:
	_street(Vector3(-20, 0, 0), 260.0)
	var specs: Array = [[14.0, 5, 0], [12.0, 4, 1], [16.0, 5, 2], [13.0, 5, 3], [11.5, 4, 0], [15.0, 5, 1], [13.5, 4, 3], [17.0, 5, 2]]
	var x := 0.0
	for i in range(specs.size()):
		var sp: Array = specs[i]
		var w: float = sp[0]
		var hr := RandomNumberGenerator.new()
		hr.seed = rng.seed * 31 + i * 7
		_build("house_%d_v%d_f%d" % [i, sp[2], sp[1]], Vector3(x, 0, 0), func(pk, kit, labels): K.call("gruenderzeit_house", pk, kit, labels, w, sp[1], sp[2], hr, 13.0, 11 + i * 2, true))
		if far:
			var hr2 := RandomNumberGenerator.new()
			hr2.seed = rng.seed * 31 + i * 7
			_build("far_%d" % i, Vector3(x + 320.0, 0, 0), func(pk, kit, labels): K.call("gruenderzeit_house_far", pk, kit, w, sp[1], sp[2], hr2, 13.0))
		x += w * PS
	_people_row(Vector3(4, 0, 5.0), 10, 60.0)
	_car(Vector3(30, 0, 9), 1.57)
	_car(Vector3(70, 0, 11), 1.57)
	if far:
		_street(Vector3(300, 0, 0), 260.0)
		return [["near_cmp", Vector3(-30, 14, 70), Vector3(60, 14, 0), 50.0], ["far_cmp", Vector3(290, 14, 70), Vector3(380, 14, 0), 50.0],
				["near_cmp_far", Vector3(-80, 30, 240), Vector3(80, 15, 0), 30.0], ["far_cmp_far", Vector3(240, 30, 240), Vector3(400, 15, 0), 30.0]]
	return [["houses", Vector3(-30, 14, 70), Vector3(60, 14, 0), 50.0], ["houses_low", Vector3(10, 4, 26), Vector3(45, 12, 0), 60.0],
			["houses_close", Vector3(14, 3.5, 14), Vector3(26, 9, 0), 60.0], ["houses_up", Vector3(60, 30, 40), Vector3(80, 22, 0), 50.0],
			["houses_back", Vector3(120, 30, -70), Vector3(80, 15, -20), 50.0], ["houses_far", Vector3(-80, 30, 220), Vector3(80, 15, 0), 40.0]]


func _set_corner(rng: RandomNumberGenerator) -> Array:
	_street(Vector3(-20, 0, 0), 120.0)
	var hr := RandomNumberGenerator.new()
	hr.seed = rng.seed + 3
	_build("corner", Vector3(0, 0, 0), func(pk, kit, labels): K.call("corner_house", pk, kit, labels, 18.0, 16.0, 5, hr))
	var hr2 := RandomNumberGenerator.new()
	hr2.seed = rng.seed + 5
	_build("corner_left", Vector3(-40, 0, 0), func(pk, kit, labels): K.call("corner_house", pk, kit, labels, 15.0, 14.0, 4, hr2, true))
	_people_row(Vector3(-10, 0, 5), 8, 30.0)
	_car(Vector3(10, 0, 9), 1.57)
	return [["corner", Vector3(55, 12, 45), Vector3(22, 14, -8), 50.0], ["corner_low", Vector3(40, 3, 20), Vector3(25, 12, -5), 60.0],
			["corner_top", Vector3(40, 45, 30), Vector3(25, 30, -10), 50.0], ["corner_left", Vector3(-70, 12, 45), Vector3(-30, 14, -8), 50.0]]


func _set_hotel() -> Array:
	_street(Vector3(-20, 0, 0), 140.0)
	_build("hotel", Vector3.ZERO, func(pk, kit, labels): K.call("hotel", pk, kit, labels))
	_people_row(Vector3(0, 0, 14), 10, 30.0)
	_car(Vector3(40, 0, 18), 1.57)
	return [["hotel", Vector3(-25, 16, 85), Vector3(35, 14, 0), 50.0], ["hotel_low", Vector3(20, 3, 32), Vector3(30, 6, 0), 60.0],
			["hotel_wg", Vector3(-15, 5, 25), Vector3(8, 4, 5), 60.0], ["hotel_top", Vector3(35, 40, 50), Vector3(35, 25, -10), 50.0],
			["hotel_back", Vector3(100, 30, -90), Vector3(35, 12, -15), 50.0]]


func _set_steps() -> Array:
	# The upper promenade 4m over the lower one (the ground here): a block behind the quay wall.
	var drop := 4.0
	var gm := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(160, drop * PS, 40)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.53, 0.50)
	bm.material = mat
	gm.mesh = bm
	gm.position = Vector3(40, drop * PS * 0.5 - 0.01, -20.05)
	_root.add_child(gm)
	var up := Vector3(0, drop * PS, 0)
	_build("quay_wall_a", up + Vector3(-40, 0, 0), func(pk, kit, labels): K.call("quay_wall", pk, kit, 40.0 / PS, drop, labels))
	_build("steps", up, func(pk, kit, labels): K.call("rhine_steps", pk, kit, 22.0, drop, 9.0))
	_build("quay_wall_b", up + Vector3(22.0 * PS, 0, 0), func(pk, kit, labels): K.call("quay_wall", pk, kit, 60.0 / PS, drop, labels, true))
	_people_row(Vector3(0, 0, 18), 8, 20.0)
	_people_row(Vector3(0, drop * PS, -3), 6, 20.0)
	_car(Vector3(20, 0, 22), 1.57)
	return [["steps", Vector3(-15, 12, 50), Vector3(18, 2, 5), 50.0], ["steps_low", Vector3(30, 2, 30), Vector3(15, 3, 5), 60.0],
			["steps_top", Vector3(10, 12, -8), Vector3(18, 2, 12), 60.0], ["quay", Vector3(60, 3, 22), Vector3(85, 3, 0), 55.0]]


func _set_promenade() -> Array:
	_street(Vector3(-30, 0, -14), 120.0)
	_build("pavilion", Vector3(0, 0, 0), func(pk, kit, labels): K.call("pavilion_cafe", pk, kit, labels))
	_build("kiosk_eis", Vector3(36, 0, 6), func(pk, kit, labels): K.call("kiosk", pk, kit, labels, "eis"))
	_build("kiosk_drinks", Vector3(48, 0, 6), func(pk, kit, labels): K.call("kiosk", pk, kit, labels, "getraenke"))
	_build("kiosk_bike", Vector3(60, 0, 6), func(pk, kit, labels): K.call("kiosk", pk, kit, labels, "fahrrad"))
	for i in range(4):
		var x: float = -10.0 + 22.0 * float(i)
		_build("lamp_%d" % i, Vector3(x, 0, 24), func(pk, kit, labels): K.call("promenade_lamp", pk, kit))
		_build("tree_guard_%d" % i, Vector3(x + 11.0, 0, 24), func(pk, kit, labels): K.call("plane_tree_guard", pk, kit))
		_trunk(Vector3(x + 11.0, 0, 24))
		_build("bench_%d" % i, Vector3(x + 5.0, 0, 26), func(pk, kit, labels): K.call("bench", pk, kit))
		_build("bin_%d" % i, Vector3(x + 7.5, 0, 26.5), func(pk, kit, labels): K.call("bin", pk, kit))
	_people_row(Vector3(-5, 0, 30), 8, 30.0)
	_car(Vector3(20, 0, 34), 1.57)
	return [["promenade", Vector3(-20, 12, 60), Vector3(25, 3, 10), 50.0], ["pavilion", Vector3(-6, 4, 32), Vector3(12, 4, 2), 60.0],
			["kiosks", Vector3(44, 4, 26), Vector3(50, 3, 6), 55.0], ["furniture", Vector3(8, 3, 36), Vector3(16, 2, 24), 55.0],
			["pavilion_back", Vector3(40, 15, -30), Vector3(12, 3, 0), 50.0]]


func _set_wheel(at: Vector3) -> Array:
	_build("wheel_base", at, func(pk, kit, labels): K.call("ferris_wheel_base", pk, kit, labels))
	var hub_y: float = K.get("WHEEL_HUB_Y")
	var wheel := Node3D.new()
	wheel.set_script(load("res://KirmesWheel.gd"))
	wheel.position = at + Vector3(0, hub_y * PS, 0)
	wheel.scale = Vector3.ONE * PS
	wheel.set("cabin_radius", K.get("WHEEL_PIVOT_R"))
	wheel.set("cabins", K.get("WHEEL_CABINS"))
	wheel.set("clock_override", _clock)
	var rotor := Node3D.new()
	rotor.name = "Rotor"
	wheel.add_child(rotor)
	var rmi := _mesh_of("wheel_rotor", func(pk, kit, labels): K.call("ferris_wheel_rotor", pk, kit), 1.0)
	rotor.add_child(rmi)
	var n: int = K.get("WHEEL_CABINS")
	var colours: int = K.get("WHEEL_GONDOLA_COLOURS")
	for c in range(colours):
		var gm := _mesh_of("gondola_%d" % c, func(pk, kit, labels): K.call("ferris_wheel_gondola", pk, kit, c), 1.0)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = gm.mesh
		mm.instance_count = n / colours
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Cabins%d" % c
		mmi.multimesh = mm
		mmi.set_meta(&"cabin_offset", c)
		mmi.set_meta(&"cabin_stride", colours)
		wheel.add_child(mmi)
	_root.add_child(wheel)
	_people_row(at + Vector3(-12, 0, 18), 8, 16.0)
	_car(at + Vector3(10, 0, 22), 0.3)
	return [["wheel", at + Vector3(-60, 20, 110), at + Vector3(0, 38, 0), 50.0], ["wheel_low", at + Vector3(-25, 3, 40), at + Vector3(0, 14, 0), 60.0],
			["wheel_side", at + Vector3(90, 25, 25), at + Vector3(0, 35, 0), 50.0], ["wheel_hub", at + Vector3(-12, 42, 30), at + Vector3(0, 41, 0), 50.0],
			["wheel_base", at + Vector3(-14, 6, 28), at + Vector3(0, 4, 0), 60.0]]


func _set_swing(at: Vector3) -> Array:
	_build("swing_base", at, func(pk, kit, labels): K.call("chair_swing_base", pk, kit, labels))
	var ride := Node3D.new()
	ride.set_script(load("res://KirmesRide.gd"))
	ride.position = at
	ride.scale = Vector3.ONE * PS
	ride.set("clock_override", _clock)
	var rotor := Node3D.new()
	rotor.name = "Rotor"
	rotor.position = Vector3(0, K.get("SWING_HANG_Y"), 0)
	ride.add_child(rotor)
	rotor.add_child(_mesh_of("swing_rotor", func(pk, kit, labels): K.call("chair_swing_rotor", pk, kit), 1.0))
	var cm := _mesh_of("swing_chair", func(pk, kit, labels): K.call("chair_swing_chair", pk, kit), 1.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cm.mesh
	mm.instance_count = K.get("SWING_CHAIRS")
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Chairs"
	mmi.multimesh = mm
	rotor.add_child(mmi)
	ride.set("hang_radius", K.get("SWING_HANG_R"))
	ride.set("chain_length", K.get("SWING_CHAIN"))
	ride.set("chairs", K.get("SWING_CHAIRS"))
	_root.add_child(ride)
	_people_row(at + Vector3(-10, 0, 22), 8, 12.0)
	_car(at + Vector3(8, 0, 26), 0.3)
	return [["swing", at + Vector3(-35, 12, 50), at + Vector3(0, 8, 0), 50.0], ["swing_low", at + Vector3(-16, 3, 30), at + Vector3(0, 7, 0), 60.0],
			["swing_top", at + Vector3(10, 30, 30), at + Vector3(0, 10, 0), 50.0]]


func _set_stalls() -> Array:
	var kinds: Array = ["bratwurst", "mandeln", "lebkuchen", "lose", "schiess", "crepes", "getraenke"]
	var x := 0.0
	for k in kinds:
		_build("stall_" + k, Vector3(x, 0, 0), func(pk, kit, labels): K.call("stall", pk, kit, labels, k))
		x += 13.0
	_build("bunting", Vector3.ZERO, func(pk, kit, labels): K.call("bunting", pk, kit, Vector3(-5, 4.5, 6), Vector3(40, 4.5, 6), 0.6))
	_build("fence", Vector3(-10, 0, -14), func(pk, kit, labels): K.call("kirmes_fence", pk, kit, 60.0))
	_people_row(Vector3(-4, 0, 8), 10, 30.0)
	_car(Vector3(20, 0, 14), 1.57)
	return [["stalls", Vector3(-15, 9, 34), Vector3(30, 3, 0), 50.0], ["stalls_close", Vector3(4, 3, 12), Vector3(12, 3, 0), 60.0],
			["stalls_b", Vector3(50, 4, 16), Vector3(62, 3, 0), 60.0], ["stalls_c", Vector3(75, 4, 16), Vector3(84, 3, 0), 60.0],
			["stalls_back", Vector3(60, 12, -30), Vector3(40, 2, 0), 50.0]]


func _set_tent() -> Array:
	_build("tent", Vector3.ZERO, func(pk, kit, labels): K.call("beer_tent", pk, kit, labels))
	_build("bumper", Vector3(70, 0, 0), func(pk, kit, labels): K.call("bumper_cars", pk, kit, labels))
	_people_row(Vector3(-15, 0, 14), 8, 16.0)
	_car(Vector3(10, 0, 18), 0.3)
	return [["tent", Vector3(-40, 12, 50), Vector3(0, 5, -15), 50.0], ["tent_door", Vector3(0, 3, 22), Vector3(0, 4, -10), 60.0],
			["tent_inside", Vector3(-3, 3, 4), Vector3(0, 2, -40), 70.0], ["bumper", Vector3(45, 10, 40), Vector3(70, 3, -8), 50.0],
			["bumper_close", Vector3(60, 3.5, 16), Vector3(70, 2.5, -8), 65.0]]


func _set_kirmes() -> Array:
	return _set_kirmes_at(Vector3.ZERO)


func _set_kirmes_at(at: Vector3) -> Array:
	_set_wheel(at + Vector3(0, 0, -40))
	_set_swing(at + Vector3(-70, 0, 10))
	_build("bumper", at + Vector3(55, 0, 20), func(pk, kit, labels): K.call("bumper_cars", pk, kit, labels))
	_build("tent", at + Vector3(-60, 0, 90), func(pk, kit, labels): K.call("beer_tent", pk, kit, labels), PI * 0.5)
	var kinds: Array = ["bratwurst", "mandeln", "lebkuchen", "lose", "schiess", "crepes", "getraenke"]
	for i in range(kinds.size()):
		_build("stall_%d" % i, at + Vector3(-25 + 13.0 * float(i), 0, 60), func(pk, kit, labels): K.call("stall", pk, kit, labels, kinds[i]), PI)
	_build("bunting_a", at, func(pk, kit, labels): K.call("bunting", pk, kit, Vector3(-30, 4.5, 30), Vector3(60, 4.5, 30), 0.7))
	_build("fence", at + Vector3(-90, 0, 110), func(pk, kit, labels): K.call("kirmes_fence", pk, kit, 110.0))
	_people_row(at + Vector3(-30, 0, 40), 12, 40.0)
	_car(at + Vector3(0, 0, 50), 1.0)
	return [["kirmes", at + Vector3(-120, 50, 190), at + Vector3(0, 10, 20), 50.0], ["kirmes_low", at + Vector3(-40, 4, 130), at + Vector3(0, 15, 0), 60.0],
			["kirmes_high", at + Vector3(150, 90, 150), at + Vector3(0, 0, 20), 45.0]]


# ======================================================================================
#  Building
# ======================================================================================

## Builds one asset at `at` (world), turned `yaw` about y, through `fn(pk, kit, labels)`, its labels as the generator makes them.
func _build(asset_name: String, at: Vector3, fn: Callable, yaw := 0.0) -> void:
	var mi := _mesh_of(asset_name, fn, PS, Transform3D(Basis(Vector3.UP, yaw), at))
	_root.add_child(mi)
	_assets.append([asset_name, mi, at, mi.mesh.get_aabb().size])


## A MeshInstance3D of the builder's kit at scale `s` in the frame `xf` (labels added to the root in world space).
func _mesh_of(asset_name: String, fn: Callable, s: float, xf := Transform3D.IDENTITY) -> MeshInstance3D:
	var pk = K.call("new_kit", s)
	pk.set_frame(xf * Transform3D(Basis().scaled(Vector3.ONE * s), Vector3.ZERO))
	var kit := {}
	var labels: Array = []
	fn.call(pk, kit, labels)
	var mesh: ArrayMesh = K.call("commit", pk, kit)
	var mi := MeshInstance3D.new()
	mi.name = asset_name
	mi.mesh = mesh
	if s == 1.0:
		_assets.append([asset_name, mi, Vector3.ZERO, mesh.get_aabb().size * PS])
	for l in labels:
		var lab := Label3D.new()
		lab.text = l[0]
		lab.font_size = 64
		var pixel: float = float(l[3]) * PS / 44.8
		if l.size() > 5 and float(l[5]) > 0.0:
			var tw: float = ThemeDB.fallback_font.get_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x
			if tw * pixel > float(l[5]) * PS:
				pixel = float(l[5]) * PS / maxf(tw, 1.0)
		lab.pixel_size = pixel
		lab.modulate = l[4]
		lab.outline_size = 4
		lab.outline_modulate = Color(0.05, 0.05, 0.05)
		lab.double_sided = false
		var n: Vector3 = xf.basis * (l[2] as Vector3)
		lab.transform = Transform3D(Basis.looking_at(-n, Vector3.UP), xf * ((l[1] as Vector3) * PS))
		_root.add_child(lab)
	return mi


func _tris(mesh: Mesh) -> int:
	var t := 0
	for s in mesh.get_surface_count():
		var idx = mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
		if idx != null and (idx as PackedInt32Array).size() > 0:
			t += (idx as PackedInt32Array).size() / 3
		else:
			t += (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return t


## A street in front of the buildings: a pavement (z 0..4), a kerb, asphalt (z 4..14).
func _street(at: Vector3, length: float) -> void:
	for spec in [[Vector3(length * 0.5, 0.0, 2.0), Vector3(length, 0.12, 4.0), Color(0.62, 0.60, 0.56)], [Vector3(length * 0.5, -0.01, 9.0), Vector3(length, 0.1, 10.0),
			Color(0.20, 0.20, 0.21)]]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = spec[1]
		var m := StandardMaterial3D.new()
		m.albedo_color = spec[2]
		m.roughness = 0.95
		bm.material = m
		mi.mesh = bm
		mi.position = at + spec[0] - Vector3(0, 0.05, 0)
		_root.add_child(mi)


## A stand-in plane tree's trunk (a 0.6m grey-brown cylinder, 9m) at `at`.
func _trunk(at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.42
	cm.bottom_radius = 0.55
	cm.height = 9.0
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.52, 0.45)
	cm.material = m
	mi.mesh = cm
	mi.position = at + Vector3(0, 4.5, 0)
	_root.add_child(mi)


## Stand-in people (2.9m: a body, a head) in a row from `at` along x, `n` of them over `span`.
func _people_row(at: Vector3, n: int, span: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.35, 0.7)
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.85, 0.66, 0.52)
	for i in range(n):
		var p: Vector3 = at + Vector3(span * float(i) / float(maxi(n - 1, 1)), 0, 0)
		var body := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.32
		cm.height = 2.45
		cm.material = mat
		body.mesh = cm
		body.position = p + Vector3(0, 1.22, 0)
		_root.add_child(body)
		var head := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.2
		sm.height = 0.42
		sm.material = hm
		head.mesh = sm
		head.position = p + Vector3(0, 2.68, 0)
		_root.add_child(head)


## A stand-in RC car: a 2.2 x 0.9 x 1.1m red box.
func _car(at: Vector3, yaw: float) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.1, 0.9, 2.2)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.12, 0.1)
	bm.material = m
	mi.mesh = bm
	mi.position = at + Vector3(0, 0.45, 0)
	mi.rotation.y = yaw
	_root.add_child(mi)


func _setup_world() -> void:
	_root = Node3D.new()
	get_root().add_child(_root)
	var gm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2000, 2000)
	gm.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.40, 0.50, 0.30)
	gmat.roughness = 1.0
	pm.material = gmat
	gm.position = Vector3(0, -0.02, 0)
	_root.add_child(gm)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.32, 0.50, 0.80)
	sm.sky_horizon_color = Color(0.86, 0.80, 0.70)
	sm.ground_bottom_color = Color(0.40, 0.40, 0.36)
	sm.ground_horizon_color = Color(0.72, 0.68, 0.62)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	_root.add_child(we)
	# A warm sun low in the west-south-west (early evening), lighting the fronts (+z) from the side.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-24.0, -55.0, 0.0)
	sun.light_energy = 1.4
	sun.light_color = Color(1.0, 0.90, 0.76)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 350.0
	_root.add_child(sun)
