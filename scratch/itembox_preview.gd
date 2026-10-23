extends Node

# Look-dev for the item box (ItemBox.tscn): a row of boxes over a flat road, a cart for scale. A scene, not
# an -s script, because ItemBox.gd uses the NetworkManager autoload. Run windowed:
#   Godot --path . --resolution 1376x768 res://scratch/itembox_preview.tscn -- <out_dir> [boxes=3]
#       [spacing=3.5] [car=0] [fov=75] [sun=<pitch>,<yaw>] [sky=<hex top>,<hex horizon>]
#       name:x,y,z:tx,ty,tz[:frames[:gap]] | pop=<i> | respawn=<i> | wait=<s> | param=<part>:<name>:<value> ...
# Boxes stand in a row across the road (x), 1.2m over it as Level spawns them; the road runs along z and
# carts come from +z. Arguments run in order: `pop=1` takes box 1 (its burst and the ground ring
# charging run on from there), `respawn=1` brings it back early, `wait=0.5` lets time pass, and
# `param=glyph:glow:0.8` sets a shader parameter on a part's shared material (shell, glyph, sparks,
# glow; a colour as a hex string). A shot with
# frames > 1 saves name_00.png, name_01.png, ... `gap` seconds apart (default 0.1).

const CART_MODEL := "res://generated/cars/Viper.tscn"
const CarPaint = preload("res://CarPaint.gd")

var boxes: Array[Node3D] = []


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var count := 3
	var spacing := 3.5
	var car := true
	var fov := 75.0
	var sun_rot := Vector3(-40.0, -35.0, 0.0)
	var sky_cols := [Color(0.24, 0.47, 0.85), Color(0.72, 0.82, 0.92)]
	var steps := []
	for a in args.slice(1):
		if a.begins_with("boxes="):
			count = int(a.substr(6))
		elif a.begins_with("spacing="):
			spacing = float(a.substr(8))
		elif a.begins_with("car="):
			car = a.substr(4) != "0"
		elif a.begins_with("fov="):
			fov = float(a.substr(4))
		elif a.begins_with("sun="):
			var f := a.substr(4).split(",")
			sun_rot = Vector3(float(f[0]), float(f[1]), 0.0)
		elif a.begins_with("sky="):
			var f := a.substr(4).split(",")
			sky_cols = [Color(f[0]), Color(f[1])]
		else:
			steps.append(a)
	_setup_world(sun_rot, sky_cols)
	var scene: PackedScene = load("res://ItemBox.tscn")
	for i in count:
		var box: Node3D = scene.instantiate()
		box.name = "ItemBox_%d" % i
		add_child(box)
		box.global_position = Vector3((i - (count - 1) * 0.5) * spacing, 1.2, 0.0)
		boxes.append(box)
	if car:
		var cart: Node3D = load(CART_MODEL).instantiate()
		CarPaint.apply(cart, CarPaint.factory("Viper"))
		add_child(cart)
		cart.global_transform = Transform3D(Basis().rotated(Vector3.UP, PI).scaled(Vector3.ONE * 2.0), Vector3(0.6, 0.0, 6.0))
	var cam := Camera3D.new()
	cam.fov = fov
	cam.near = 0.05
	cam.far = 2000.0
	add_child(cam)
	cam.make_current()
	# Shaders compile in the background and draw nothing until ready; the boxes build in over 0.6s.
	for i in 60:
		await get_tree().process_frame
	for a in steps:
		var s := a as String
		if s.begins_with("pop="):
			boxes[int(s.substr(4))]._deactivate_rpc()
			continue
		if s.begins_with("respawn="):
			boxes[int(s.substr(8))]._activate_rpc()
			continue
		if s.begins_with("param="):
			var f := s.substr(6).split(":")
			var mat: ShaderMaterial = boxes[0]._materials[f[0]]
			mat.set_shader_parameter(f[1], Color(f[2]) if f[2].is_valid_html_color() and not f[2].is_valid_float() else float(f[2]))
			continue
		if s.begins_with("wait="):
			await get_tree().create_timer(float(s.substr(5))).timeout
			continue
		var parts := s.split(":")
		var p := parts[1].split(",")
		var t := parts[2].split(",")
		cam.global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		cam.look_at(Vector3(float(t[0]), float(t[1]), float(t[2])), Vector3.UP)
		var frames := int(parts[3]) if parts.size() > 3 else 1
		var gap := float(parts[4]) if parts.size() > 4 else 0.1
		for f in frames:
			if f > 0:
				await get_tree().create_timer(gap).timeout
			else:
				for i in 4:
					await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var file := parts[0] if frames == 1 else "%s_%02d" % [parts[0], f]
			get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, file])
			print("SHOT ", file)
	get_tree().quit()


func _setup_world(sun_rot: Vector3, sky_cols: Array) -> void:
	# Grass, a 9m road along z, and a body under both for the boxes' ground ray.
	for spec in [[Vector2(400, 400), Color(0.24, 0.42, 0.14), 0.0], [Vector2(9, 400), Color(0.19, 0.19, 0.2), 0.01]]:
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = spec[0]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = spec[1]
		mat.roughness = 0.95
		pm.material = mat
		mi.mesh = pm
		mi.position.y = spec[2]
		add_child(mi)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 400)
	shape.shape = box
	shape.position.y = -0.5
	body.add_child(shape)
	add_child(body)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = sky_cols[0]
	sm.sky_horizon_color = sky_cols[1]
	sm.ground_bottom_color = Color(0.2, 0.25, 0.15)
	sm.ground_horizon_color = sky_cols[1]
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	# As the race levels: ACES, a little glow.
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_bloom = 0.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = sun_rot
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)
