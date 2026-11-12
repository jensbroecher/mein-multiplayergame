extends SceneTree

# Contact sheet of every car's wheels seen from outside and from inside (the side toward the car), to find
# wheels that are hollow or plain from one side. Each saved car's right wheel (generated/cars/<prefix>_wheel_r.res,
# and the rear one where the car has its own): "out" shows its +x face, "in" its -x face. Run windowed:
#   Godot --path . --resolution 1800x2400 -s res://scratch/wheel_sides_sheet.gd -- <out.png> [cars=Apex,...] [cols=8]
const CARS := ["mudrunner", "phantom", "strikeforce", "centurion", "shadow", "interceptor", "viper", "apex", "mirage",
	"inferno", "nocturne", "vortex", "zephyr", "titan", "sandstorm", "obsidian", "fulmine", "basilisk", "bootlegger",
	"meteor", "kugelblitz", "sandpiper", "samurai", "ninja", "crimson", "typhoon"]
const STEP := 1.0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var cars: Array = CARS.duplicate()
	var cols := 8
	for a in args.slice(1):
		if a.begins_with("cars="):
			cars = Array(a.substr(5).to_lower().split(","))
		elif a.begins_with("cols="):
			cols = int(a.substr(5))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.6, 0.66)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.7, 0.75)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30.0, 20.0, 0.0)
	sun.light_energy = 1.3
	root.add_child(sun)
	var tiles: Array = []
	for c in cars:
		for which in ["wheel_r", "rear_wheel_r"]:
			var p := "res://generated/cars/%s_%s.res" % [c, which]
			if not ResourceLoader.exists(p):
				continue
			for side in ["out", "in"]:
				tiles.append([load(p), "%s %s %s" % [c, "R" if which.begins_with("rear") else "F", side], side == "out"])
	var rows: int = ceili(float(tiles.size()) / cols)
	for i in tiles.size():
		var t: Array = tiles[i]
		var x: float = (i % cols) * STEP
		var y: float = -(i / cols) * STEP
		var mi := MeshInstance3D.new()
		mi.mesh = t[0]
		# Turn the face we want toward the camera (+z).
		mi.rotation.y = -PI * 0.5 if t[2] else PI * 0.5
		mi.rotation.x = 0.0
		var r: float = mi.mesh.get_aabb().size.y * 0.5
		var s: float = 0.36 / maxf(r, 0.01)
		mi.scale = Vector3.ONE * s
		mi.position = Vector3(x, y, 0.0)
		root.add_child(mi)
		var l := Label3D.new()
		l.text = t[1]
		l.pixel_size = 0.0018
		l.font_size = 48
		l.outline_size = 8
		l.position = Vector3(x, y - 0.44, 0.5)
		root.add_child(l)
	# A magenta card behind the wheels: whatever shows magenta is see-through (the reflections stay grey).
	var card := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(cols * STEP + 4.0, rows * STEP + 4.0)
	card.mesh = qm
	var cmat := StandardMaterial3D.new()
	cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cmat.albedo_color = Color(1.0, 0.0, 0.85)
	card.material_override = cmat
	card.position = Vector3((cols - 1) * STEP * 0.5, -(rows - 1) * STEP * 0.5, -3.0)
	root.add_child(card)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = rows * STEP + 0.2
	cam.position = Vector3((cols - 1) * STEP * 0.5, -(rows - 1) * STEP * 0.5, 10.0)
	root.add_child(cam)
	cam.current = true
	var w: int = cols * 200
	var h: int = rows * 200
	root.size = Vector2i(w, h)
	for k in 60:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("SAVED ", out, " tiles=", tiles.size())
	quit()
