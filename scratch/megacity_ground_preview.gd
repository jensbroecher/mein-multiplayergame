extends SceneTree
## Renders megacity_ground.gdshader on a made-up piece of ground in daylight: flat streets at 8m, a bank falling to a
## river at 0, a steep hill rising behind, to see how the streets give way on slopes.
##   godot --path . -s res://scratch/megacity_ground_preview.gd -- <out_dir> [shore_y=-1000] [slope_grass=0]
func _h(x: float, z: float) -> float:
	var h: float = lerpf(-6.0, 8.0, smoothstep(-40.0, -12.0, z))
	h += 40.0 * smoothstep(60.0, 110.0, z) + 6.0 * sin(x * 0.03) * smoothstep(60.0, 110.0, z)
	h += 18.0 * smoothstep(20.0, 45.0, x) * smoothstep(-10.0, 20.0, z)
	return h

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var m := ShaderMaterial.new()
	m.shader = load("res://megacity_ground.gdshader")
	m.set_shader_parameter("grid_origin", Vector2(-11, 9))
	m.set_shader_parameter("asphalt_tex", load("res://materials/asphalt.png"))
	m.set_shader_parameter("grass_tex", load("res://materials/grass.png"))
	m.set_shader_parameter("concrete_tex", load("res://materials/concrete.png"))
	m.set_shader_parameter("lamp_energy", 0.2)
	for a in args.slice(1):
		var kv: PackedStringArray = a.split("=")
		m.set_shader_parameter(kv[0], float(kv[1]))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 120
	var step := 2.0
	for i in n:
		for j in n:
			var x0 := -120.0 + i * step
			var z0 := -80.0 + j * step
			var q := [Vector3(x0, _h(x0, z0), z0), Vector3(x0 + step, _h(x0 + step, z0), z0), Vector3(x0 + step, _h(x0 + step, z0 + step), z0 + step),
				Vector3(x0, _h(x0, z0 + step), z0 + step)]
			for t in [[0, 1, 2], [0, 2, 3]]:
				for k in t:
					st.add_vertex(q[k])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	root.add_child(mi)
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(600, 600)
	water.mesh = pm
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.2, 0.21, 0.17)
	wm.roughness = 0.2
	water.material_override = wm
	root.add_child(water)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 40, 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.7, 0.75, 0.82)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	root.add_child(env)
	var cam := Camera3D.new()
	root.add_child(cam)
	await process_frame
	for shot in [["river", Vector3(-30, 10, -75), Vector3(0, 4, 0)], ["hill", Vector3(-70, 20, 10), Vector3(20, 25, 90)]]:
		cam.look_at_from_position(shot[1], shot[2])
		for f in 4:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png(out.path_join(shot[0] + ".png"))
	quit()
