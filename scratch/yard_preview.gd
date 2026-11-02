extends SceneTree

# Look-dev for Freight Line's yard buildings (YardKit.gd, FactoryKit.gd): builds the station, the goods shed, the
# platform and the grain complex on a flat pad in memory and renders them from named cameras, without generating the
# level. Run windowed:
#   Godot --path . --resolution 1400x850 -s res://scratch/yard_preview.gd -- <out_dir> [set=station|factory|all]
#       [stock=1] name:x,y,z:tx,ty,tz[:fov] ...
# The station's origin (its west end, front) is the world's origin, the platform track runs along x at z = -37.2 (the
# platform lies between it and the building, as in the level) and the factory's origin sits at FACTORY_AT.
const YardKit = preload("res://YardKit.gd")
const FactoryKit = preload("res://FactoryKit.gd")
const FreightKit = preload("res://FreightKit.gd")
const TrainKit = preload("res://TrainKit.gd")
const Train = preload("res://Train.gd")

const SCALE := 1.6
const TRACK_Z := -37.2
const FACTORY_AT := Vector3(150.0, 0.0, -150.0)


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var which := "all"
	var stock := false
	var shots := []
	for a in args.slice(1):
		if a.begins_with("set="):
			which = a.substr(4)
		elif a.begins_with("stock="):
			stock = a.substr(6) == "1"
		else:
			shots.append(a)
	_setup_world()
	var labels: Array = []
	if which == "station" or which == "all":
		var pk := YardKit.new_kit(SCALE)
		var kit := {}
		var z_edge: float = (TRACK_Z + 2.6) / SCALE
		YardKit.station(pk, kit, labels)
		YardKit.platform(pk, kit, -32.0, 46.0, -12.0, z_edge, true, true, labels)
		YardKit.goods_shed(pk, kit, -30.0, -4.0, labels)
		_show(YardKit.commit(pk, kit), Vector3.ZERO, "Station")
		for l in labels:
			_label(l, Vector3.ZERO)
		# The platform track.
		var pts: Array = []
		var bed: Array = []
		var x := -140.0
		while x <= 180.0:
			pts.append(Vector3(x, 0.6, TRACK_Z))
			if pts.size() > 1:
				bed.append(true)
			x += 5.0
		_show(FreightKit.track_piece(pts, bed, 3), Vector3.ZERO, "Track")
		if stock:
			_stock()
	if which == "factory" or which == "all":
		var pk2 := YardKit.new_kit(SCALE)
		var kit2 := {}
		var labels2: Array = []
		FactoryKit.factory(pk2, kit2, labels2)
		_show(YardKit.commit(pk2, kit2), FACTORY_AT, "Factory")
		for l in labels2:
			_label(l, FACTORY_AT)
		var pts2: Array = []
		var bed2: Array = []
		var z: float = FACTORY_AT.z + FactoryKit.TRACK_Z * SCALE
		var x2 := FACTORY_AT.x - 120.0
		while x2 <= FACTORY_AT.x + 140.0:
			pts2.append(Vector3(x2, 0.6, z))
			if pts2.size() > 1:
				bed2.append(true)
			x2 += 5.0
		_show(FreightKit.track_piece(pts2, bed2, 4), Vector3.ZERO, "TrackF")
	var tris := 0
	for c in root.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is ArrayMesh:
			var m: ArrayMesh = (c as MeshInstance3D).mesh
			var t := 0
			for s in m.get_surface_count():
				t += (m.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			if t > 0:
				print("  %s: %d surfaces, %d triangles" % [c.name, m.get_surface_count(), t])
				tris += t
	print("triangles ", tris)
	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.near = 0.1
	cam.far = 3000.0
	root.add_child(cam)
	cam.make_current()
	for i in 40:
		await process_frame
	for a in shots:
		var parts := (a as String).split(":")
		var p := parts[1].split(",")
		var t := parts[2].split(",")
		cam.fov = float(parts[3]) if parts.size() > 3 else 55.0
		cam.global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		cam.look_at(Vector3(float(t[0]), float(t[1]), float(t[2])), Vector3.UP)
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [out, parts[0]])
		print("SHOT ", parts[0])
	quit()


func _show(mesh: Mesh, at: Vector3, node_name: String) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = at
	root.add_child(mi)


## A Label3D from [text, position (kit units), outward normal, letter height, colour] in the building's frame.
func _label(l: Array, origin: Vector3) -> void:
	var lab := Label3D.new()
	lab.text = l[0]
	lab.font_size = 64
	lab.pixel_size = float(l[3]) * SCALE / 44.8
	lab.modulate = l[4]
	lab.outline_size = 8
	lab.outline_size = 0
	var n: Vector3 = l[2]
	var basis := Basis.looking_at(-n, Vector3.UP)
	lab.transform = Transform3D(basis, origin + (l[1] as Vector3) * SCALE)
	root.add_child(lab)


## The stabled express beside the platform: a diesel and two coaches, and the yard loco with grain hoppers under the
## loadout (the generator's own placements).
func _stock() -> void:
	var curve := Curve3D.new()
	curve.add_point(Vector3(-400, 0.6, TRACK_Z))
	curve.add_point(Vector3(400, 0.6, TRACK_Z))
	var train := Train.new()
	train.path = curve
	train.consist = PackedStringArray(["coach", "coach", "ploco"])
	train.speed = 20.0
	train.period = 100.0
	train.clock_override = 140.0 / 20.0
	train.kills = false
	root.add_child(train)


func _setup_world() -> void:
	var gm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1200, 1200)
	gm.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.66, 0.54, 0.41)
	gmat.roughness = 1.0
	pm.material = gmat
	gm.position = Vector3(0, -0.02, -100)
	root.add_child(gm)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.28, 0.50, 0.85)
	sm.sky_horizon_color = Color(0.80, 0.84, 0.88)
	sm.ground_bottom_color = Color(0.45, 0.42, 0.38)
	sm.ground_horizon_color = Color(0.72, 0.70, 0.66)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, 215.0, 0.0)
	sun.light_energy = 1.3
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 400.0
	root.add_child(sun)
