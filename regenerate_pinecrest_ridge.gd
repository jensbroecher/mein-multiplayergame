# regenerate_pinecrest_ridge.gd
# Builds PinecrestRidgeLevel.tscn:
# Grand-scale alpine forest hillclimb in the Lakehill style for the Starter Cup.
# Features a massive 85m mountain with 5 multi-tiered switchbacks on the south face,
# huge elevation changes, 3 massive air jumps, clear camera sightlines, item boxes, and boost pads.
extends Node

func _ready() -> void:
	print("=== Pinecrest Ridge Grand Prix Level Generation ===")
	print("Building high-elevation mountain switchback course. Please wait...")

	var level_scene := Node3D.new()
	level_scene.name = "PinecrestRidgeLevel"

	var level_script: Script = load("res://levels/Level.gd")
	level_scene.set_script(level_script)
	add_child(level_scene)

	# 1. Environment & Lighting
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.35, 0.60, 0.95)
	sky_mat.sky_horizon_color = Color(0.70, 0.82, 0.92)
	sky_mat.ground_bottom_color = Color(0.20, 0.35, 0.18)
	sky_mat.ground_horizon_color = Color(0.60, 0.75, 0.85)
	sky_mat.sun_angle_max = 30.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.5
	env.ambient_light_color = Color(0.85, 0.90, 0.95)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.15
	env_node.environment = env
	level_scene.add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = Vector3(-42.0, 35.0, 0.0)
	sun.light_color = Color(1.0, 0.98, 0.90)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 450.0
	sun.directional_shadow_split_1 = 0.1
	sun.directional_shadow_split_2 = 0.25
	sun.directional_shadow_split_3 = 0.55
	level_scene.add_child(sun)

	# 2. TrackPath & Curve3D (~1650m full-scale circuit)
	var track_path := Path3D.new()
	track_path.name = "TrackPath"
	var curve := Curve3D.new()
	curve.bake_interval = 0.25

	# Multi-tiered mountain switchback curve ascending to +78m on the south face and returning down
	var curve_pts = [
		# --- TIER 0: VALLEY FLOOR & PADDOCK SPRINT (Y = 0m -> 4m) ---
		# 0: Start / Finish Line
		[Vector3(0, 0, 30), Vector3(0, 0, -35), Vector3(0.0, 0.0, 160.0)],
		# 1: High-speed valley straight
		[Vector3(0, 0, 35), Vector3(0, 0, -35), Vector3(0.0, 0.0, 80.0)],
		# 2: Left sweep around the valley lake shore
		[Vector3(18, 0, 25), Vector3(-20, 0.5, -25), Vector3(-40.0, 1.5, 25.0)],
		# 3: Foot of the hill - road begins steep incline
		[Vector3(-10, -0.5, 22), Vector3(10, 1.8, -22), Vector3(-62.0, 5.5, -15.0)],

		# --- TIER 1: JUMP 1 (Forest Ravine Leap, Y = 10m -> 20m) ---
		# 4: Jump 1 Takeoff Ramp (Z=-50, Y=10m)
		[Vector3(-2, -0.5, 15), Vector3(2, 2.5, -18), Vector3(-70.0, 10.0, -50.0)],
		# 5: Jump 1 Landing Terrace Shelf (Z=-90, Y=20m)
		[Vector3(0, 2.0, 18), Vector3(0, 0.8, -18), Vector3(-75.0, 20.0, -90.0)],

		# --- TIER 2: SERPENTINE SWITCHBACKS (Climbing south mountain face) ---
		# 6: Approach to Switchback 1 (Z=-125, Y=25m)
		[Vector3(0, -0.8, 18), Vector3(2, 1.2, -18), Vector3(-80.0, 25.0, -125.0)],
		# 7: Switchback 1 Apex (160 deg sharp right hairpin into rocky slope, Z=-155, Y=31m)
		[Vector3(-16, -1.0, 2), Vector3(22, 1.0, -2), Vector3(-50.0, 31.0, -155.0)],
		# 8: Ascending traverse across the south mountain face (Z=-145, Y=37m)
		[Vector3(-25, -1.0, -5), Vector3(25, 1.0, 5), Vector3(5.0, 37.0, -145.0)],
		# 9: Approach to Switchback 2 on east flank (Z=-140, Y=44m)
		[Vector3(-20, -1.0, 5), Vector3(18, 1.0, -10), Vector3(65.0, 44.0, -140.0)],
		# 10: Switchback 2 Apex (155 deg sharp left hairpin climbing higher, Z=-170, Y=52m)
		[Vector3(12, -1.2, 18), Vector3(-14, 1.2, -20), Vector3(85.0, 52.0, -170.0)],
		# 11: High traverse climbing west to the upper terrace (Z=-195, Y=60m)
		[Vector3(25, -1.0, 8), Vector3(-25, 1.0, -8), Vector3(30.0, 60.0, -195.0)],
		# 12: Approach to Switchback 3 (Z=-205, Y=68m)
		[Vector3(20, -1.0, 5), Vector3(-18, 1.0, -10), Vector3(-35.0, 68.0, -205.0)],
		# 13: Switchback 3 Apex (150 deg sharp right hairpin into alpine rock, Z=-235, Y=74m)
		[Vector3(-15, -1.0, 4), Vector3(20, 0.8, -4), Vector3(-65.0, 74.0, -235.0)],

		# --- TIER 3: SUMMIT RIDGE & JUMP 2 (High Vista Super-Jump, Y = 78m -> 58m) ---
		# 14: Summit Crest Road (Highest point +78m overlooking all lower tiers & valley)
		[Vector3(-20, -0.5, 5), Vector3(25, 0.0, -5), Vector3(-15.0, 78.0, -245.0)],
		# 15: Summit Ridge straightaway leading to Jump 2 takeoff (Z=-225, Y=77m)
		[Vector3(-18, 0.0, -4), Vector3(18, -0.5, 8), Vector3(35.0, 77.0, -225.0)],
		# 16: Jump 2 Takeoff Ramp launching south off the summit ridge (Z=-195, Y=75m)
		[Vector3(-2, 0.8, -14), Vector3(2, -3.5, 22), Vector3(55.0, 75.0, -195.0)],
		# 17: Jump 2 Landing Terrace (Z=-150, Y=56m)
		[Vector3(0, 4.0, -20), Vector3(4, -1.2, 20), Vector3(65.0, 56.0, -150.0)],

		# --- TIER 4: DOWNHILL SERPENTINE DESCENT (Y = 54m -> 16m) ---
		# 18: High-speed downhill sweep (Z=-115, Y=48m)
		[Vector3(-15, 1.2, -15), Vector3(15, -1.2, 15), Vector3(75.0, 48.0, -115.0)],
		# 19: Switchback 4 (Sharp Right Downhill Hairpin, Z=-80, Y=40m)
		[Vector3(15, 1.2, -5), Vector3(-18, -1.2, 5), Vector3(50.0, 40.0, -80.0)],
		# 20: Technical downhill chicane through mountain wall (Z=-45, Y=32m)
		[Vector3(14, 1.0, -14), Vector3(-14, -1.0, 14), Vector3(10.0, 32.0, -45.0)],
		# 21: Switchback 5 (Sharp Left Downhill Hairpin, Z=-15, Y=24m)
		[Vector3(-15, 1.0, -5), Vector3(18, -1.0, 5), Vector3(30.0, 24.0, -15.0)],
		# 22: Downhill sprint towards Jump 3 (Z=25, Y=17m)
		[Vector3(-8, 1.0, -15), Vector3(6, -0.8, 18), Vector3(62.0, 17.0, 25.0)],

		# --- TIER 5: JUMP 3 (Forest Creek Launch Ramp & Valley Sprint) ---
		# 23: Jump 3 Takeoff Ramp launching over valley creek (Z=60, Y=14m)
		[Vector3(-2, 0.8, -12), Vector3(0, 2.2, 18), Vector3(68.0, 14.0, 60.0)],
		# 24: Jump 3 Landing Zone in valley meadow (Z=105, Y=1.5m)
		[Vector3(0, 3.0, -16), Vector3(-6, -0.5, 18), Vector3(62.0, 1.5, 105.0)],
		# 25: Sweeping right turn around the valley meadow (Z=155, Y=0m)
		[Vector3(16, 0.0, -18), Vector3(-18, 0.0, 18), Vector3(35.0, 0.0, 155.0)],
		# 26: Return to Start/Finish Straight (Z=160, Y=0m)
		[Vector3(20, 0.0, -4), Vector3(-15, 0.0, 4), Vector3(-4.0, 0.0, 160.0)]
	]

	for pt in curve_pts:
		curve.add_point(pt[2], pt[0], pt[1])

	track_path.curve = curve
	level_scene.add_child(track_path)

	# 3. TerrainGenerator Setup
	var tg := Node3D.new()
	tg.name = "TerrainGenerator"
	var tg_script: Script = load("res://TerrainGenerator.gd")
	tg.set_script(tg_script)
	tg.set("level_prefix", "pinecrest_ridge")
	tg.set("track_layout_type", 0)
	tg.set("terrain_resolution", 450)
	tg.set("terrain_size", Vector2(950.0, 950.0))
	tg.set("hill_height", 14.0)
	tg.set("road_width", 14.0)
	tg.set("sand_width", 18.0)
	tg.set("road_y_offset", 0.06)
	tg.set("curb_y_offset", 0.06)
	tg.set("terrain_recession_collision", 0.12)
	tg.set("terrain_recession_visual", 0.18)
	tg.set("no_water", false)
	tg.set("no_grass", false)
	tg.set("terrain_grass_count", 0)

	var grass_tex: Texture2D = load("res://materials/grass.png") as Texture2D
	var asphalt_tex: Texture2D = load("res://materials/asphalt.png") as Texture2D
	if grass_tex:
		var grass_mat := StandardMaterial3D.new()
		grass_mat.albedo_texture = grass_tex
		grass_mat.albedo_color = Color(0.85, 1.05, 0.85)
		grass_mat.uv1_scale = Vector3(0.12, 0.12, 0.12)
		grass_mat.uv1_triplanar = true
		grass_mat.roughness = 0.9
		tg.set("grass_material", grass_mat)
	if asphalt_tex:
		var road_mat := StandardMaterial3D.new()
		road_mat.albedo_texture = asphalt_tex
		road_mat.albedo_color = Color(0.92, 0.92, 0.92)
		road_mat.uv1_scale = Vector3(0.2, 0.2, 0.2)
		road_mat.roughness = 0.75
		tg.set("road_material", road_mat)

	level_scene.add_child(tg)
	tg.set("track_path", track_path)
	tg.call("generate_world")

	# 4. Players node
	var players_node := Node3D.new()
	players_node.name = "Players"
	level_scene.add_child(players_node)

	# 5. Finish Line & Starting Grid
	var gate_scene: PackedScene = load("res://CheckpointGate.tscn")
	var spawn_scene: PackedScene = load("res://SpawnIndicator.tscn")

	var finish_line = gate_scene.instantiate()
	finish_line.name = "FinishLine"
	finish_line.position = Vector3(0.0, 0.06, 160.0)
	finish_line.rotation_degrees = Vector3(0, 180, 0)
	finish_line.set("is_finish_line", true)
	level_scene.add_child(finish_line)

	var spawn_points := Node3D.new()
	spawn_points.name = "SpawnPoints"
	finish_line.add_child(spawn_points)

	var grid_coords = [
		Vector3(-2.8, 0.05, 5.0),
		Vector3(2.8, 0.05, 5.0),
		Vector3(-2.8, 0.05, 12.0),
		Vector3(2.8, 0.05, 12.0),
		Vector3(-2.8, 0.05, 19.0),
		Vector3(2.8, 0.05, 19.0)
	]
	for i in range(grid_coords.size()):
		var sp := Marker3D.new()
		sp.name = "Spawn%d" % (i + 1)
		sp.position = grid_coords[i]
		sp.gizmo_extents = 0.3
		spawn_points.add_child(sp)

		if spawn_scene:
			var si = spawn_scene.instantiate()
			si.name = "SpawnIndicator"
			sp.add_child(si)

	# 6. Multiplayer Spawners
	var p_spawner := MultiplayerSpawner.new()
	p_spawner.name = "PlayerSpawner"
	p_spawner.set("_spawnable_scenes", PackedStringArray(["uid://cart123"]))
	p_spawner.spawn_path = NodePath("../Players")
	p_spawner.spawn_limit = 6
	level_scene.add_child(p_spawner)

	var proj_spawner := MultiplayerSpawner.new()
	proj_spawner.name = "ProjectileSpawner"
	proj_spawner.spawn_path = NodePath(".")
	level_scene.add_child(proj_spawner)

	# 7. Checkpoints Container
	var checkpoints_container := Node3D.new()
	checkpoints_container.name = "Checkpoints"
	level_scene.add_child(checkpoints_container)

	# Place 18 checkpoint gates evenly along the 1650m track
	var track_len: float = curve.get_baked_length()
	var cp_count := 18
	var cp_step := track_len / float(cp_count + 1)
	for i in range(cp_count):
		var dist_along := cp_step * float(i + 1)
		var cp_pos := curve.sample_baked(dist_along)
		var next_pos := curve.sample_baked(minf(track_len, dist_along + 1.0))
		var forward := (next_pos - cp_pos).normalized()
		var rot_y := rad_to_deg(atan2(-forward.x, -forward.z))

		var gate = gate_scene.instantiate()
		gate.name = "Checkpoint_%d" % (i + 1)
		gate.position = cp_pos + Vector3(0, 0.1, 0)
		gate.rotation_degrees = Vector3(0, rot_y, 0)
		checkpoints_container.add_child(gate)

	# 8. Jumps & Ramps
	var ramp_container := Node3D.new()
	ramp_container.name = "JumpRamps"
	level_scene.add_child(ramp_container)

	var ramp_scene: PackedScene = load("res://models/ramps/ramp.glb")
	if not ramp_scene:
		ramp_scene = load("res://models/ramps/woodramp.fbx")

	# Jump 1 (Forest Ravine Leap): (-70, 10, -50)
	# Jump 2 (Summit Overlook Super-Jump): (55, 75, -195)
	# Jump 3 (Forest Creek Mega-Launch): (68, 14, 60)
	var ramp_placements = [
		[Vector3(-70.0, 10.06, -50.0), Vector3(0, 165, 0), Vector3(2.6, 2.2, 2.6)],
		[Vector3(55.0, 75.06, -195.0), Vector3(0, 15, 0), Vector3(3.2, 2.8, 3.2)],
		[Vector3(68.0, 14.06, 60.0), Vector3(0, 0, 0), Vector3(2.8, 2.4, 2.8)]
	]

	if ramp_scene:
		for idx in range(ramp_placements.size()):
			var r_info = ramp_placements[idx]
			var ramp_inst = ramp_scene.instantiate()
			ramp_inst.name = "JumpRamp_%d" % (idx + 1)
			ramp_inst.position = r_info[0]
			ramp_inst.rotation_degrees = r_info[1]
			ramp_inst.scale = r_info[2]
			ramp_container.add_child(ramp_inst)

	# 9. Boost Pads
	var boost_scene: PackedScene = load("res://BoostPad.tscn")
	var boost_container := Node3D.new()
	boost_container.name = "BoostPads"
	level_scene.add_child(boost_container)

	if boost_scene:
		var bp_defs = [
			# Jump 1 Takeoff pair
			["Boost_Jump1_L", Vector3(-67.0, 10.1, -48.0), 165.0],
			["Boost_Jump1_R", Vector3(-73.0, 10.1, -48.0), 165.0],
			# Jump 2 Summit Super-Jump trio
			["Boost_Jump2_L", Vector3(51.0, 75.1, -197.0), 15.0],
			["Boost_Jump2_M", Vector3(55.0, 75.1, -197.0), 15.0],
			["Boost_Jump2_R", Vector3(59.0, 75.1, -197.0), 15.0],
			# Jump 3 Downhill Creek Launch pair
			["Boost_Jump3_L", Vector3(65.0, 14.1, 58.0), 0.0],
			["Boost_Jump3_R", Vector3(71.0, 14.1, 58.0), 0.0],
			# Straightaway Boosters
			["Boost_StartStraight", Vector3(0.0, 0.08, 110.0), 180.0],
			["Boost_MidClimb", Vector3(10.0, 37.5, -145.0), -80.0],
			["Boost_SummitRidge", Vector3(-10.0, 78.1, -245.0), -90.0]
		]
		for bp_info in bp_defs:
			var bp = boost_scene.instantiate()
			bp.name = bp_info[0]
			bp.position = bp_info[1]
			bp.rotation_degrees = Vector3(0, bp_info[2], 0)
			boost_container.add_child(bp)

	# 10. Item Boxes
	var item_scene: PackedScene = load("res://ItemBox.tscn")
	var item_container := Node3D.new()
	item_container.name = "ItemBoxes"
	level_scene.add_child(item_container)

	if item_scene:
		var item_rows = [
			# Row 1: Valley Straight (Z = 60)
			[Vector3(-4.0, 1.2, 60.0), Vector3(0.0, 1.2, 60.0), Vector3(4.0, 1.2, 60.0)],
			# Row 2: Mid-Mountain Traverse (Z = -145, Y = 38m)
			[Vector3(2.0, 38.2, -145.0), Vector3(6.0, 38.2, -145.0), Vector3(10.0, 38.2, -145.0)],
			# Row 3: Summit Vista Ridge before Jump 2 (Z = -235, Y = 78m)
			[Vector3(15.0, 78.5, -235.0), Vector3(20.0, 78.5, -235.0), Vector3(25.0, 78.5, -235.0)],
			# Row 4: Downhill sprint before Jump 3 (Z = 20, Y = 18m)
			[Vector3(58.0, 18.5, 20.0), Vector3(62.0, 18.5, 20.0), Vector3(66.0, 18.5, 20.0)]
		]
		var item_idx := 1
		for row in item_rows:
			for pos in row:
				var ib = item_scene.instantiate()
				ib.name = "ItemBox_%d" % item_idx
				ib.position = pos
				item_container.add_child(ib)
				item_idx += 1

	# 11. Pine Forest & Vegetation WITH STRICT CAMERA CLEARANCE
	# Tall pines placed at least 25m away from the road so the camera and driving view are never blocked!
	var veg_container := Node3D.new()
	veg_container.name = "Vegetation"
	level_scene.add_child(veg_container)

	var pine_models = [
		load("res://models/trees/pine.glb"),
		load("res://models/trees/pine_2.glb")
	]
	var tree_models = [
		load("res://models/trees/tree.glb"),
		load("res://models/trees/tree_2.glb"),
		load("res://models/trees/tree_3.glb"),
		load("res://models/trees/tree_4.glb")
	]
	var bush_model = load("res://models/trees/bush.glb")
	var flower_blue_model = load("res://models/trees/flower_blue.glb")
	var flower_white_model = load("res://models/trees/flower_white.glb")

	var rng = RandomNumberGenerator.new()
	rng.seed = 98765

	var baked_pts: PackedVector3Array = curve.get_baked_points()
	var get_2d_road_dist = func(px: float, pz: float) -> float:
		var min_d := 1.0e9
		for bp in baked_pts:
			var d = Vector2(px - bp.x, pz - bp.z).length()
			if d < min_d:
				min_d = d
		return min_d

	var get_tree_y = func(px: float, pz: float) -> float:
		var hill_progress: float = clampf((-pz + 80.0) / 380.0, 0.0, 1.0)
		var hill_shape: float = hill_progress * hill_progress * (3.0 - 2.0 * hill_progress)
		var x_falloff: float = clampf(1.0 - (absf(px) / 380.0), 0.0, 1.0)
		x_falloff = x_falloff * x_falloff * (3.0 - 2.0 * x_falloff)
		var hill_elevation: float = hill_shape * x_falloff * 90.0
		var min_d := 1.0e9
		var best_y := hill_elevation
		for bp in baked_pts:
			var d = Vector2(px - bp.x, pz - bp.z).length()
			if d < min_d:
				min_d = d
				best_y = bp.y
		if min_d < 45.0:
			var blend = 1.0 - (min_d / 45.0)
			return lerpf(hill_elevation, best_y, blend * 0.85)
		return hill_elevation

	# Tall trees placed in dense background forests (MIN 26.0m from road!)
	var tree_count := 0
	for i in range(160):
		var px = rng.randf_range(-340.0, 340.0)
		var pz = rng.randf_range(-340.0, 220.0)

		var dist_to_road = get_2d_road_dist.call(px, pz)
		# STRICT CLEARANCE: 26.0m clearance ensures camera NEVER collides with or gets blocked by pine trees!
		if dist_to_road < 26.0:
			continue

		var py = get_tree_y.call(px, pz)
		var is_high_hill = (pz < -40.0)

		var chosen_packed = null
		if is_high_hill or rng.randf() < 0.75:
			chosen_packed = pine_models[rng.randi() % pine_models.size()]
		else:
			chosen_packed = tree_models[rng.randi() % tree_models.size()]

		if chosen_packed:
			var tree_inst = chosen_packed.instantiate()
			tree_count += 1
			tree_inst.name = "Tree_%d" % tree_count
			tree_inst.position = Vector3(px, py, pz)
			var sc = rng.randf_range(1.3, 2.3)
			tree_inst.scale = Vector3(sc, sc, sc)
			tree_inst.rotation_degrees = Vector3(0, rng.randf_range(0, 360), 0)
			veg_container.add_child(tree_inst)

	# Low-profile bushes placed along roadsides (scaled small so view remains unobstructed)
	if bush_model:
		var bush_count := 0
		for i in range(50):
			var t_offset = rng.randf_range(10.0, curve.get_baked_length() - 10.0)
			var path_pt = curve.sample_baked(t_offset)
			var side_sign = -1.0 if rng.randf() < 0.5 else 1.0
			var side_dist = rng.randf_range(13.0, 20.0)
			var bush_pos = path_pt + Vector3(side_sign * side_dist, 0.0, rng.randf_range(-2.0, 2.0))
			bush_pos.y = get_tree_y.call(bush_pos.x, bush_pos.z)

			var bush_inst = bush_model.instantiate()
			bush_count += 1
			bush_inst.name = "Bush_%d" % bush_count
			bush_inst.position = bush_pos
			var sc = rng.randf_range(0.6, 1.0) # Small low-lying bushes
			bush_inst.scale = Vector3(sc, sc, sc)
			bush_inst.rotation_degrees = Vector3(0, rng.randf_range(0, 360), 0)
			veg_container.add_child(bush_inst)

	# Wildflowers in the meadows
	var flower_models = [flower_blue_model, flower_white_model]
	var flower_count := 0
	for i in range(50):
		var f_packed = flower_models[rng.randi() % flower_models.size()]
		if f_packed:
			var px = rng.randf_range(-160.0, 160.0)
			var pz = rng.randf_range(30.0, 200.0)
			if get_2d_road_dist.call(px, pz) < 10.0:
				continue
			var py = get_tree_y.call(px, pz)
			var f_inst = f_packed.instantiate()
			flower_count += 1
			f_inst.name = "Flowers_%d" % flower_count
			f_inst.position = Vector3(px, py, pz)
			var sc = rng.randf_range(1.2, 1.8)
			f_inst.scale = Vector3(sc, sc, sc)
			veg_container.add_child(f_inst)

	# 12. Additional Containers
	for c_name in ["Props", "AlternativePaths"]:
		var c := Node3D.new()
		c.name = c_name
		level_scene.add_child(c)

	# 13. Rebuild Checkpoints Array & Offsets on Level
	level_scene.set("track_path", track_path)
	level_scene._setup_checkpoints()

	# 14. Set Scene Owners Recursively for all nodes
	_set_owner_recursive(level_scene, level_scene)

	# 15. Save Scene
	remove_child(level_scene)
	var target_path := "res://levels/PinecrestRidgeLevel.tscn"
	var packed_scene := PackedScene.new()
	var pack_err = packed_scene.pack(level_scene)
	if pack_err != OK:
		push_error("Failed to pack PinecrestRidgeLevel.tscn: %d" % pack_err)
		get_tree().quit(1)
		return

	var save_err = ResourceSaver.save(packed_scene, target_path)
	if save_err != OK:
		push_error("Failed to save PinecrestRidgeLevel.tscn: %d" % save_err)
		get_tree().quit(1)
		return

	print("Successfully generated and saved res://levels/PinecrestRidgeLevel.tscn!")
	get_tree().quit(0)


func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	if node != scene_root:
		node.owner = scene_root
	for child in node.get_children():
		_set_owner_recursive(child, scene_root)
