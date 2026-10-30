extends SceneTree

# Look-dev for Ridgecrest's buildings (RidgecrestKit.gd): builds them in memory and renders them on a
# lawn, life size, fronts toward -z. Run windowed:
#   Godot --path . --resolution 1400x900 -s res://scratch/ridgecrest_preview.gd -- <out_dir> [only=chalet,...]
#       [fov=40] name:x,y,z:tx,ty,tz ...
# Laid out along x, 32m apart, in this order: chalet (variants 0, 1, 2), hotel, chapel, villa_cube
# (variants 0, 1), villa_gable (0, 1), pavilion, gate. Prints each one's triangles.
const RidgecrestKit = preload("res://RidgecrestKit.gd")
const PropKit = preload("res://PropKit.gd")

const BUILDINGS := [
	["chalet", 0], ["chalet", 1], ["chalet", 2], ["hotel", 0], ["chapel", 0],
	["villa_cube", 0], ["villa_cube", 1], ["villa_gable", 0], ["villa_gable", 1], ["pavilion", 0], ["gate", 0],
]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var fov := 40.0
	var only := PackedStringArray()
	var shots := []
	for a in args.slice(1):
		if a.begins_with("fov="):
			fov = float(a.substr(4))
		elif a.begins_with("only="):
			only = a.substr(5).split(",")
		else:
			shots.append(a)
	var gm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(600, 200)
	gm.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.36, 0.52, 0.24)
	gmat.roughness = 0.95
	pm.material = gmat
	root.add_child(gm)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.20, 0.42, 0.80)
	sm.sky_horizon_color = Color(0.70, 0.82, 0.93)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.64
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, 35.0, 0.0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	root.add_child(sun)
	var kit := PropKit.new()
	var mats := {}
	kit.material_for = func(key: String) -> Material:
		if not mats.has(key):
			mats[key] = RidgecrestKit.make_material(key)
		return mats[key]
	var rk := RidgecrestKit.new(kit)
	var rng := RandomNumberGenerator.new()
	var x := 0.0
	for b in BUILDINGS:
		var kind: String = b[0]
		if not only.is_empty() and not only.has(kind):
			x += 32.0
			continue
		var t0 := Time.get_ticks_msec()
		rng.seed = 11 + int(x)
		var shell := {}
		var fine := {}
		kit.set_frame(Transform3D(Basis(), Vector3(x, 0, 0)))
		var res: Dictionary
		match kind:
			"chalet":
				res = rk.chalet(shell, fine, rng, int(b[1]))
			"hotel":
				res = rk.hotel(shell, fine, rng)
			"chapel":
				res = rk.chapel(shell, fine, rng)
			"villa_cube":
				res = rk.villa_cube(shell, fine, rng, int(b[1]))
			"villa_gable":
				res = rk.villa_gable(shell, fine, rng, int(b[1]))
			"pavilion":
				res = rk.pavilion(shell, fine, rng)
			"gate":
				res = rk.estate_gate(shell, fine)
		var tris := 0
		for k in [shell, fine]:
			kit.reset_frame()
			var mesh: ArrayMesh = rk.finish(k)
			for s in range(mesh.get_surface_count()):
				tris += (mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			root.add_child(mi)
		for lb in res["labels"]:
			var l := Label3D.new()
			l.text = lb[0]
			l.pixel_size = float(lb[3]) / 64.0
			l.font_size = 64
			l.outline_size = 0
			l.modulate = lb[4] if lb.size() > 4 else Color(0.95, 0.92, 0.84)
			l.shaded = lb.size() > 4
			var n: Vector3 = lb[2]
			l.transform = Transform3D(Basis(Vector3.UP, atan2(n.x, n.z)), (lb[1] as Vector3) + Vector3(x, 0, 0) + n * 0.02)
			root.add_child(l)
		print("%s %d at x %.0f: %d triangles, %d boxes, %.2fs" % [kind, int(b[1]), x, tris, (res["boxes"] as Array).size(), (Time.get_ticks_msec() - t0) / 1000.0])
		x += 32.0
	var cam := Camera3D.new()
	cam.fov = fov
	cam.near = 0.05
	cam.far = 1500.0
	root.add_child(cam)
	cam.make_current()
	for i in 40:
		await process_frame
	for a in shots:
		var parts := (a as String).split(":")
		var p := parts[1].split(",")
		var t := parts[2].split(",")
		cam.global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		cam.look_at(Vector3(float(t[0]), float(t[1]), float(t[2])), Vector3.UP)
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [out, parts[0]])
		print("SHOT ", parts[0])
	quit()
