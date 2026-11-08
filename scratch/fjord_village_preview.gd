extends SceneTree

# Look-dev for Svartvik's buildings (FjordVillageKit.gd): builds a house of each paint, the church, two rorbuer, a
# boathouse, the quay, a drying rack, kick-sleds and a woodpile on a flat snowfield in memory and renders them from
# named cameras, without generating the level. Run windowed:
#   Godot --path . --resolution 1400x850 -s res://scratch/fjord_village_preview.gd -- <out_dir> name:x,y,z:tx,ty,tz[:fov] ...
# Life size at SCALE (1.6, the level's). The houses stand in a row along x at z 0 facing +z, 28m apart from x -70
# (storeys 1, 1.5, 2, 1, 1.5, 2);
# the church at (0, 0, -45); the rorbuer, boathouse, quay and rack along z 40.
const FjordVillageKit = preload("res://FjordVillageKit.gd")

const SCALE := 1.6


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	_setup_world()
	var pk := FjordVillageKit.new_village_kit(SCALE)
	var kit := {}
	for i in range(6):
		pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * SCALE), Vector3(-70.0 + 28.0 * float(i), 0, 0)))
		FjordVillageKit.house(pk, kit, 9.0 + float(i % 3), 6.5 + float(i % 2) * 0.8, [1.0, 1.5, 2.0][i % 3], FjordVillageKit.PAINTS[i], 1.0, 0.15 * float(i % 3 - 1), i)
	pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * SCALE), Vector3(0, 0, -45)))
	FjordVillageKit.church(pk, kit, 1.0)
	for i in range(2):
		pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * SCALE), Vector3(-40.0 + 12.0 * float(i), 1.5, 40)))
		FjordVillageKit.rorbu(pk, kit, 5.0, 7.0, FjordVillageKit.PAINTS[1] if i == 0 else FjordVillageKit.PAINTS[2], 2.5, i)
	pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * SCALE), Vector3(-10, 0, 40)))
	FjordVillageKit.naust(pk, kit, 5.5, 8.0, 0.6)
	pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * SCALE), Vector3(25, 0, 45)))
	FjordVillageKit.quay(pk, kit, 24.0, 4.0, 1.2, 2.0)
	pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * SCALE), Vector3(25, 0, 25)))
	FjordVillageKit.hjell(pk, kit, 14.0, 3)
	pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * SCALE), Vector3(-44, 0, 6)))
	FjordVillageKit.spark(pk, kit)
	pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * SCALE), Vector3(-36, 0, -11)))
	FjordVillageKit.woodpile(pk, kit, 3.0, 2)
	var mi := MeshInstance3D.new()
	mi.mesh = FjordVillageKit.commit(pk, kit)
	root.add_child(mi)
	var t := 0
	for s in mi.mesh.get_surface_count():
		t += (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	print("triangles ", t)
	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.near = 0.1
	cam.far = 3000.0
	root.add_child(cam)
	cam.make_current()
	for i in 40:
		await process_frame
	for a in args.slice(1):
		var parts := (a as String).split(":")
		var p := parts[1].split(",")
		var tg := parts[2].split(",")
		cam.fov = float(parts[3]) if parts.size() > 3 else 55.0
		cam.global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		cam.look_at(Vector3(float(tg[0]), float(tg[1]), float(tg[2])), Vector3.UP)
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [out, parts[0]])
		print("SHOT ", parts[0])
	quit()


func _setup_world() -> void:
	var gm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1200, 1200)
	gm.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.85, 0.88, 0.93)
	gmat.roughness = 0.9
	pm.material = gmat
	gm.position = Vector3(0, -0.02, 0)
	root.add_child(gm)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.32, 0.55, 0.88)
	sm.sky_horizon_color = Color(0.80, 0.86, 0.93)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46.0, 42.0, 0.0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 300.0
	root.add_child(sun)
