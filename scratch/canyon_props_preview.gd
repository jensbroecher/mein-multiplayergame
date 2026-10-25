extends SceneTree

# Renders the Canyon Course's procedural props in memory, on a flat stretch of desert at the height of
# the valley floors (the rock's beds come from the world height): SandstoneKit's blocks, pebbles and
# formations, and CactusKit's species. Uses the level's saved rock material, so regenerate the level
# once first. Windowed:
#   Godot --path . --resolution 1600x1000 -s res://scratch/canyon_props_preview.gd -- <dir> [set=rocks|cacti|forms]
#       [far=1] name:x,y,z:tx,ty,tz ...
# Rocks stand along +x every 4m from x = 0, cacti every 3m, formations every 40m; the ground is at y = 12.

const SandstoneKit = preload("res://SandstoneKit.gd")
const GROUND_Y := 12.0

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0]
	var which := "rocks"
	var far := false
	for a in args.slice(1):
		if a.begins_with("set="):
			which = a.substr(4)
		elif a == "far=1":
			far = true
	var scene := Node3D.new()
	root.add_child(scene)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.25, 0.45, 0.78)
	sky_mat.sky_horizon_color = Color(0.8, 0.8, 0.82)
	sky_mat.ground_bottom_color = Color(0.5, 0.42, 0.38)
	sky_mat.ground_horizon_color = Color(0.75, 0.7, 0.66)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	scene.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, -60, 0)
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	scene.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(800, 800)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.72, 0.48, 0.34)
	gm.roughness = 0.95
	ground.material_override = gm
	ground.position = Vector3(0, GROUND_Y, 0)
	scene.add_child(ground)
	var rock_mat: Material = load("res://generated/canyon_rock_material.res")
	if which == "rocks":
		for k in range(8):
			var mi := MeshInstance3D.new()
			mi.mesh = SandstoneKit.block(4100 + k, 2 if far else 7, rock_mat)
			var sc: float = [1.0, 1.6, 2.4, 3.2, 1.3, 2.0, 4.5, 0.8][k]
			mi.transform = Transform3D(Basis().scaled(Vector3.ONE * sc), Vector3(k * 4.0 + (sc - 1.0) * 1.5, GROUND_Y - sc * 0.12, 0))
			scene.add_child(mi)
		for k in range(3):
			var mi := MeshInstance3D.new()
			mi.mesh = SandstoneKit.pebbles(5100 + k, 11, 1 if far else 2, rock_mat)
			mi.position = Vector3(k * 4.0, GROUND_Y, 6.0)
			scene.add_child(mi)
	elif which == "forms":
		var b1 := MeshInstance3D.new()
		b1.mesh = SandstoneKit.butte(7001, 18.0, 24.0, 56, rock_mat)
		b1.position = Vector3(0, GROUND_Y - 1.0, 0)
		scene.add_child(b1)
		var b2 := MeshInstance3D.new()
		b2.mesh = SandstoneKit.spires(7002, 5, 22.0, 12, rock_mat)
		b2.position = Vector3(45, GROUND_Y - 0.6, 0)
		scene.add_child(b2)
		var b3 := MeshInstance3D.new()
		b3.mesh = SandstoneKit.balanced(7003, 13.0, 14, 6, rock_mat)
		b3.position = Vector3(80, GROUND_Y - 0.6, 0)
		scene.add_child(b3)
	elif which == "cacti":
		var CactusKit = load("res://CactusKit.gd")
		var kit = CactusKit.new()
		var mat: Material = kit.material()
		var x := 0.0
		for sp in kit.SPECIES:
			for v in range(int(kit.VARIANTS[sp])):
				var mi := MeshInstance3D.new()
				mi.mesh = kit.build(sp, v, 1 if far else 0, mat)
				var w: float = mi.mesh.get_aabb().size.x
				x += maxf(w * 0.5, 1.0) + 0.8
				mi.position = Vector3(x, GROUND_Y - 0.05, 0)
				x += maxf(w * 0.5, 1.0) + 0.8
				scene.add_child(mi)
				print("CACTUS %s %d at x=%.1f: %d triangles, %.1fm tall" % [sp, v, mi.position.x, mi.mesh.get_faces().size() / 3, mi.mesh.get_aabb().size.y])
	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.far = 3000.0
	scene.add_child(cam)
	cam.make_current()
	_shoot(cam, out_dir, args)


func _shoot(cam: Camera3D, out_dir: String, args: PackedStringArray) -> void:
	await process_frame
	root.size = Vector2i(1600, 1000)
	for i in 40:
		await process_frame
	for a in args.slice(1):
		if a.count(":") < 2:
			continue
		var parts := a.split(":")
		var p := parts[1].split(",")
		var t := parts[2].split(",")
		cam.position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		cam.look_at(Vector3(float(t[0]), float(t[1]), float(t[2])), Vector3.UP)
		for i in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, parts[0]])
		print("SHOT ", parts[0])
	quit()
