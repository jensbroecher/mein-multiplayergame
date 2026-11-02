extends Node

# Look-dev script to generate and preview new sagebrush variants

const PropKit = preload("res://PropKit.gd")
const FreightKit = preload("res://FreightKit.gd")

static func _add_foliage_spray(st: SurfaceTool, pos: Vector3, cluster_r: float, rng: RandomNumberGenerator, sage_deep: Color, sage_mid: Color, sage_tip: Color) -> void:
	# 4-way crossed fans per cluster for volumetric density
	for fan_idx in 4:
		var fan_ang: float = float(fan_idx) * PI / 4.0 + rng.randf_range(-0.15, 0.15)
		var fan_dir := Vector3(cos(fan_ang), 0.0, sin(fan_ang))
		var fan_tilt := rng.randf_range(-0.35, 0.35)
		var fan_up := Vector3(0, 1, 0).rotated(fan_dir, fan_tilt)
		var fan_right := fan_dir.cross(fan_up).normalized()
		
		var fan_base: Vector3 = pos + Vector3(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.03, 0.03), rng.randf_range(-0.03, 0.03))
		var normal: Vector3 = (fan_base.normalized() + Vector3.UP * 0.7).normalized()
		
		# 3-toothed serrated tridentate fan
		for lobe in 3:
			var lobe_offset: float = (float(lobe) - 1.0) * cluster_r * 0.5
			var lobe_h: float = cluster_r * (1.2 if lobe == 1 else 0.95) * rng.randf_range(0.9, 1.1)
			var lobe_w: float = cluster_r * 0.34
			
			var v0 := fan_base + fan_right * (lobe_offset * 0.3)
			var v1 := fan_base + fan_right * (lobe_offset - lobe_w * 0.5) + fan_up * (lobe_h * 0.55)
			var v2 := fan_base + fan_right * (lobe_offset + lobe_w * 0.5) + fan_up * (lobe_h * 0.55)
			var v3 := fan_base + fan_right * lobe_offset + fan_up * lobe_h
			
			# Natural dusty sagebrush colors with sun-bleached tips
			var c_base: Color = sage_deep.lerp(sage_mid, rng.randf_range(0.15, 0.35))
			var c_mid: Color = sage_mid * rng.randf_range(0.95, 1.05)
			var c_tip: Color = sage_tip.lerp(sage_mid, rng.randf_range(0.0, 0.3)) * rng.randf_range(0.98, 1.05)
			
			# Triangle 1: v0, v1, v2
			st.set_normal(normal)
			st.set_color(c_base)
			st.add_vertex(v0)
			st.set_color(c_mid)
			st.add_vertex(v1)
			st.set_color(c_mid)
			st.add_vertex(v2)
			
			# Triangle 2: v1, v3, v2
			st.set_normal(normal)
			st.set_color(c_mid)
			st.add_vertex(v1)
			st.set_color(c_tip)
			st.add_vertex(v3)
			st.set_color(c_mid)
			st.add_vertex(v2)

	# Fluffy horizontal cap triangles
	for cap in 3:
		var cap_r: float = cluster_r * 0.8
		var cap_c: Vector3 = pos + Vector3(rng.randf_range(-0.04, 0.04), cluster_r * 0.45, rng.randf_range(-0.04, 0.04))
		var cap_ang: float = rng.randf() * TAU
		for t in 3:
			var a0: float = cap_ang + float(t) * TAU / 3.0
			var a1: float = a0 + TAU / 3.0
			var p_c: Vector3 = cap_c
			var p_a: Vector3 = cap_c + Vector3(cos(a0), rng.randf_range(-0.03, 0.03), sin(a0)) * cap_r
			var p_b: Vector3 = cap_c + Vector3(cos(a1), rng.randf_range(-0.03, 0.03), sin(a1)) * cap_r
			
			st.set_normal(Vector3.UP)
			st.set_color(sage_mid)
			st.add_vertex(p_c)
			st.set_color(sage_tip)
			st.add_vertex(p_a)
			st.set_color(sage_tip)
			st.add_vertex(p_b)


static func build_sage_test(seed_v: int) -> ArrayMesh:
	var pk := FreightKit.new_kit()
	var kit := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	
	var wood_col := Color(0.38, 0.32, 0.24)
	var leaf_st: SurfaceTool = pk.st(kit, "sage_leaf")
	
	# Dusty desert sagebrush palette (silvery-grey green with straw highlights)
	var sage_deep := Color(0.32, 0.38, 0.28)
	var sage_mid := Color(0.48, 0.55, 0.42)
	var sage_tip := Color(0.66, 0.65, 0.48)
	
	# 9 to 12 main gnarled woody branches radiating out into a compact, bushy dome
	var num_branches := rng.randi_range(9, 12)
	var foliage_spots: Array = []
	
	for b in num_branches:
		var ang := TAU * float(b) / float(num_branches) + rng.randf_range(-0.2, 0.2)
		var reach := rng.randf_range(0.45, 0.82)
		var h := rng.randf_range(0.38, 0.68)
		
		var p0 := Vector3(rng.randf_range(-0.08, 0.08), -0.02, rng.randf_range(-0.08, 0.08))
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var mid_reach := reach * rng.randf_range(0.42, 0.58)
		var p1 := p0 + dir * mid_reach + Vector3(0, h * rng.randf_range(0.45, 0.6), 0) + Vector3(rng.randf_range(-0.06, 0.06), 0, rng.randf_range(-0.06, 0.06))
		var p2 := p0 + dir * reach + Vector3(0, h, 0)
		
		# Gnarled stem
		pk.tube(kit, "wood", p0, p1, 0.042, 0.026, 4, wood_col, true)
		pk.tube(kit, "wood", p1, p2, 0.026, 0.015, 3, wood_col.lightened(0.08), true)
		
		# Foliage along branch: both at mid and at tip!
		foliage_spots.append({"pos": p1 + Vector3(0, 0.05, 0), "r": rng.randf_range(0.24, 0.32)})
		foliage_spots.append({"pos": p2, "r": rng.randf_range(0.26, 0.36)})
		
		# Secondary twigs branching out
		for tw in range(rng.randi_range(1, 2)):
			var tw_ang := ang + rng.randf_range(-0.7, 0.7)
			var tw_dir := Vector3(cos(tw_ang), 0.0, sin(tw_ang))
			var tw_reach := reach * rng.randf_range(0.7, 1.05)
			var tw_h := h * rng.randf_range(0.65, 0.95)
			var tw_tip := p1 + tw_dir * (tw_reach - mid_reach) + Vector3(0, tw_h - p1.y, 0)
			pk.tube(kit, "wood", p1, tw_tip, 0.02, 0.01, 3, wood_col.lightened(0.12), true)
			foliage_spots.append({"pos": tw_tip, "r": rng.randf_range(0.22, 0.30)})
			
			# Occasional dry stick protruding
			if rng.randf() < 0.4:
				var stick_tip := tw_tip + (tw_dir + Vector3(0, 0.6, 0)).normalized() * rng.randf_range(0.12, 0.22)
				pk.tube(kit, "wood", tw_tip, stick_tip, 0.01, 0.004, 3, wood_col.lightened(0.22), true)
	
	# Center crown foliage to fill the core dome
	for c_idx in 4:
		var c_ang := TAU * float(c_idx) / 4.0 + rng.randf_range(-0.3, 0.3)
		var c_dist := rng.randf_range(0.08, 0.22)
		var c_pos := Vector3(cos(c_ang) * c_dist, rng.randf_range(0.35, 0.55), sin(c_ang) * c_dist)
		foliage_spots.append({"pos": c_pos, "r": rng.randf_range(0.28, 0.38)})

	# Build all foliage sprays
	for spot in foliage_spots:
		_add_foliage_spray(leaf_st, spot["pos"], spot["r"], rng, sage_deep, sage_mid, sage_tip)

	return pk.commit(kit)

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.size = Vector2i(1280, 800)
	var vp := get_viewport()
	vp.msaa_3d = Viewport.MSAA_4X
	
	# Create environment
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.90, 0.92, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.65, 0.60)
	var env_node := WorldEnvironment.new()
	env_node.environment = env
	add_child(env_node)
	
	# Sunlight
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, 45.0, 0.0)
	sun.light_color = Color(1.0, 0.97, 0.90)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	
	# Sand ground
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(30, 30)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.92, 0.85, 0.70)
	gmat.roughness = 0.9
	var ground := MeshInstance3D.new()
	ground.mesh = ground_mesh
	ground.material_override = gmat
	add_child(ground)
	
	# Old Sage on the left
	var old_mesh = FreightKit.sage(100)
	var old_inst := MeshInstance3D.new()
	old_inst.mesh = old_mesh
	old_inst.position = Vector3(-1.8, 0, 0)
	add_child(old_inst)
	
	# New Sage in the middle and right
	var new_mesh1 = build_sage_test(100)
	var new_inst1 := MeshInstance3D.new()
	new_inst1.mesh = new_mesh1
	new_inst1.position = Vector3(0.0, 0, 0)
	add_child(new_inst1)
	
	var new_mesh2 = build_sage_test(101)
	var new_inst2 := MeshInstance3D.new()
	new_inst2.mesh = new_mesh2
	new_inst2.position = Vector3(1.8, 0, 0)
	add_child(new_inst2)
	
	# Camera
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 1.4, 2.8)
	cam.look_at(Vector3(0, 0.45, 0), Vector3.UP)
	cam.make_current()
	
	for i in 15:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	
	var img := vp.get_texture().get_image()
	img.save_png("res://scratch/sage_comparison.png")
	print("Saved scratch/sage_comparison.png")
	get_tree().quit()
