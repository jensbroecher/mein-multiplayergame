extends SceneTree
## Renders MarinaKit's yachts (the 44m superyacht and the 24m motor yacht, every paint) on a flat sea at dusk in a second
## or two, without building Marina Nights. Windowed:
##   Godot --path . --resolution 1600x900 -s res://scratch/yacht_preview.gd -- <dir> [length=44] [style=0] [night=1]
##       name:x,y,z:tx,ty,tz ...
## In metres, the bow toward +z, the waterline y = 0. Prints the mesh's triangles. night=1 lights it as Marina Nights is.

const MarinaKit = preload("res://MarinaKit.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := args[0] if args.size() > 0 else "/tmp/yacht"
	DirAccess.make_dir_recursive_absolute(dir)
	var length := 44.0
	var style := 0
	var night := false
	var shots: Array = []
	for a in args.slice(1):
		if a.begins_with("length="):
			length = float(a.substr(7))
		elif a.begins_with("style="):
			style = int(a.substr(6))
		elif a == "night=1":
			night = true
		else:
			var parts := String(a).split(":")
			if parts.size() >= 3:
				var p := parts[1].split_floats(",")
				var t := parts[2].split_floats(",")
				shots.append([parts[0], Vector3(p[0], p[1], p[2]), Vector3(t[0], t[1], t[2])])
	var k: float = length / 44.0
	if shots.is_empty():
		shots = [["side", Vector3(-48, 6, 2) * k, Vector3(0, 5, 0) * k], ["bow", Vector3(-26, 12, 40) * k, Vector3(0, 5, 2) * k],
				["stern", Vector3(22, 10, -42) * k, Vector3(0, 4, -4) * k], ["above", Vector3(-20, 34, -16) * k, Vector3(0, 4, 2) * k]]
	var root := Node3D.new()
	get_root().add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	var sky := ProceduralSkyMaterial.new()
	if night:
		sky.sky_top_color = Color(0.01, 0.02, 0.06)
		sky.sky_horizon_color = Color(0.2, 0.14, 0.18)
		sky.ground_horizon_color = Color(0.1, 0.08, 0.1)
		sky.ground_bottom_color = Color(0.02, 0.02, 0.03)
	env.sky.sky_material = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR if night else Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.16, 0.18, 0.30)
	env.ambient_light_energy = 0.35 if night else 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = night
	env.glow_intensity = 0.75
	env.glow_bloom = 0.12
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(-140.0), 0.0)
	sun.light_energy = 0.22 if night else 1.2
	sun.light_color = Color(0.62, 0.70, 0.95) if night else Color(1, 0.97, 0.92)
	sun.shadow_enabled = true
	root.add_child(sun)
	if night:
		var om := OmniLight3D.new()
		om.position = Vector3(18, 9, 10) * k
		om.omni_range = 40.0 * k
		om.light_energy = 2.0
		om.light_color = Color(1.0, 0.82, 0.58)
		root.add_child(om)
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	water.mesh = plane
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.03, 0.08, 0.12, 0.85) if night else Color(0.14, 0.28, 0.40, 0.8)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.08
	wm.metallic = 0.4
	water.material_override = wm
	root.add_child(water)
	var pk := MarinaKit.new_kit(1.0)
	var kit := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	MarinaKit.yacht(pk, kit, rng, length, style)
	var mesh := MarinaKit.commit(pk, kit)
	var tris := 0
	for si in range(mesh.get_surface_count()):
		var arr := mesh.surface_get_arrays(si)
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		tris += (idx.size() if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	print("yacht %.0fm style %d: %d surfaces, %d triangles, AABB %s" % [length, style, mesh.get_surface_count(), tris, mesh.get_aabb()])
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	root.add_child(mi)
	var cam := Camera3D.new()
	cam.fov = 40.0
	root.add_child(cam)
	cam.current = true
	for i in range(40):
		await process_frame
	for s in shots:
		cam.look_at_from_position(s[1], s[2])
		for i in range(4):
			await process_frame
		var img := get_root().get_texture().get_image()
		var path: String = dir.path_join("%s.png" % s[0])
		img.save_png(path)
		print("SHOT ", path)
	quit()
