extends SceneTree

# Look-dev for the 3D logo (generated/logo/RcVibeLogo.tscn): renders it from named cameras in the logo's
# frame (metres, the origin its centre, the front toward +Z), in the showroom's studio sky over a dark
# backdrop. Run windowed:
#   Godot --path . --resolution 1600x900 -s res://scratch/logo_preview.gd -- <out_dir> [yaw=0] [pitch=0]
#       [sheen=-1] [fov=35] [key=1.6] [amb=1.0] [flat=1] name:x,y,z:tx,ty,tz[:fov] ...
# yaw and pitch turn the logo (degrees); sheen puts the sweeping highlight at 0 to 1 across; flat=1 lights
# it from the front only (to read the colours).
const SKY_SHADER = preload("res://showroom_sky.gdshader")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var yaw := 0.0
	var pitch := 0.0
	var sheen := -1.0
	var fov := 35.0
	var key_energy := 1.6
	var amb := 1.0
	var flat := false
	var shots := []
	for a in args.slice(1):
		if a.begins_with("yaw="):
			yaw = float(a.substr(4))
		elif a.begins_with("pitch="):
			pitch = float(a.substr(6))
		elif a.begins_with("sheen="):
			sheen = float(a.substr(6))
		elif a.begins_with("fov="):
			fov = float(a.substr(4))
		elif a.begins_with("key="):
			key_energy = float(a.substr(4))
		elif a.begins_with("amb="):
			amb = float(a.substr(4))
		elif a.begins_with("flat="):
			flat = a.substr(5) == "1"
		else:
			shots.append(a)
	_setup_world(key_energy, amb, flat)
	var logo := (load("res://generated/logo/RcVibeLogo.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(logo)
	logo.rotation_degrees = Vector3(pitch, yaw, 0.0)
	var mat := (logo.get_node("Rim") as MeshInstance3D).mesh.surface_get_material(0) as ShaderMaterial
	mat.set_shader_parameter("sheen", sheen)
	print("logo size ", logo.get_meta("logo_size"))
	var cam := Camera3D.new()
	cam.fov = fov
	cam.near = 0.05
	cam.far = 200.0
	root.add_child(cam)
	cam.make_current()
	# New shaders compile in the background and draw nothing until ready: give them time.
	for i in 40:
		await process_frame
	for a in shots:
		var parts := (a as String).split(":")
		var p := parts[1].split(",")
		var t := parts[2].split(",")
		cam.fov = float(parts[3]) if parts.size() > 3 else fov
		cam.global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		cam.look_at(Vector3(float(t[0]), float(t[1]), float(t[2])), Vector3.UP)
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [out, parts[0]])
		print("SHOT ", parts[0])
	quit()


func _setup_world(key_energy: float, amb: float, flat: bool) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.045, 0.09)
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = amb
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_energy = key_energy
	key.light_color = Color(1.0, 0.96, 0.9)
	key.rotation_degrees = Vector3(0.0, 0.0, 0.0) if flat else Vector3(-35.0, -28.0, 0.0)
	key.shadow_enabled = not flat
	root.add_child(key)
	if not flat:
		var rim := DirectionalLight3D.new()
		rim.light_energy = 1.2
		rim.light_color = Color(0.55, 0.75, 1.0)
		rim.rotation_degrees = Vector3(-18.0, 150.0, 0.0)
		root.add_child(rim)
