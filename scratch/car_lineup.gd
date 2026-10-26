extends SceneTree

# Contact sheet of the cars in their factory paint: every saved car (generated/cars/*.tscn) in a row or
# grid on a grey yard, nose toward the camera (+Z), placed the way the splash screen places them. Run windowed:
#   Godot --path . --resolution 1800x1000 -s res://scratch/car_lineup.gd -- <out_dir> [cars=Apex,Inferno,...]
#       [cols=5] [yaw=-28] [fov=34] [dist=26] [height=2.6]
const CarPaint = preload("res://CarPaint.gd")
const ALL := ["Trailblazer", "Shadow", "Strikeforce", "Apex", "Interceptor", "Mudrunner", "Phantom", "Centurion",
	"Mirage", "Inferno", "Nocturne", "Vortex", "Zephyr", "Viper"]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var names: Array = ALL.duplicate()
	var cols := 5
	var yaw := -28.0
	var fov := 34.0
	var dist := 26.0
	var height := 2.6
	for a in args.slice(1):
		if a.begins_with("cars="):
			names = a.substr(5).split(",")
		elif a.begins_with("cols="):
			cols = int(a.substr(5))
		elif a.begins_with("yaw="):
			yaw = float(a.substr(4))
		elif a.begins_with("fov="):
			fov = float(a.substr(4))
		elif a.begins_with("dist="):
			dist = float(a.substr(5))
		elif a.begins_with("height="):
			height = float(a.substr(7))
	_setup_world()
	var spacing := 4.4
	var shown := 0
	for car_name in names:
		var path := "res://generated/cars/%s.tscn" % car_name
		if not ResourceLoader.exists(path):
			print("no scene for ", car_name)
			continue
		var car := (load(path) as PackedScene).instantiate() as Node3D
		root.add_child(car)
		var col := shown % cols
		var row := shown / cols
		car.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)) * 2.0,
			Vector3((col - (cols - 1) * 0.5) * spacing, 0.0, -row * 6.0))
		if CarPaint.is_paintable(car):
			CarPaint.apply(car, CarPaint.factory(car_name))
		var label := Label3D.new()
		label.text = car_name
		label.font_size = 48
		label.pixel_size = 0.006
		label.position = car.position + Vector3(0, 1.9, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		root.add_child(label)
		shown += 1
	var rows := (shown + cols - 1) / cols
	var cam := Camera3D.new()
	cam.fov = fov
	cam.far = 200.0
	root.add_child(cam)
	cam.make_current()
	cam.look_at_from_position(Vector3(0, height + rows * 1.5, dist + rows * 4.0), Vector3(0, 0.7, -(rows - 1) * 3.0), Vector3.UP)
	for i in 50:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/lineup_%s.png" % [out, "_".join(names).substr(0, 40)])
	print("SHOT lineup, %d cars" % shown)
	quit()


func _setup_world() -> void:
	var gm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(120, 120)
	gm.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.30, 0.31, 0.34)
	gmat.roughness = 0.9
	pm.material = gmat
	root.add_child(gm)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.50, 0.58)
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.30, 0.50, 0.80)
	sm.sky_horizon_color = Color(0.72, 0.80, 0.88)
	sm.ground_bottom_color = Color(0.25, 0.24, 0.22)
	sm.ground_horizon_color = Color(0.55, 0.56, 0.55)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, 35.0, 0.0)
	sun.light_energy = 1.3
	root.add_child(sun)
