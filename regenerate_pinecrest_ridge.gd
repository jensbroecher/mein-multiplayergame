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

	# 11. Pine Forest, Bushes, Wildflowers & Grass WITH STRICT ROAD CLEARANCE
	# Tall pines placed at least 28m away from the road so the camera and driving view are never blocked!
	# Roadside bushes placed strictly along the track normal (11.5m to 17.5m out), never encroaching into the road or curbs!
	# All vegetation heights sampled directly from the terrain generator's cached height grid and seated properly into the ground.
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
	var grass_model = load("res://models/trees/grass.glb")
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

	# Exact ground height directly from the terrain generator's cached visual height grid
	var get_ground_y = func(px: float, pz: float) -> float:
		return float(tg.call("_sample_cached_height", px, pz))

	# Jump flight trajectories to keep completely clear of tall trees:
	# Jump 1 (Ravine Leap): (-70, 10, -50) to (-75, 20, -90)
	# Jump 2 (Summit Super-Jump): (55, 75, -195) to (65, 56, -150)
	# Jump 3 (Creek Launch): (68, 14, 60) to (62, 1.5, 105)
	var jump_segments = [
		[Vector2(-70.0, -50.0), Vector2(-75.0, -90.0), 30.0],
		[Vector2(55.0, -195.0), Vector2(65.0, -150.0), 35.0],
		[Vector2(68.0, 60.0), Vector2(62.0, 105.0), 30.0]
	]
	var is_in_jump_corridor = func(px: float, pz: float) -> bool:
		var p = Vector2(px, pz)
		for seg in jump_segments:
			var a: Vector2 = seg[0]
			var b: Vector2 = seg[1]
			var radius: float = seg[2]
			var ab = b - a
			var l2 = ab.length_squared()
			var t = clampf((p - a).dot(ab) / maxf(l2, 0.001), 0.0, 1.0)
			var proj = a + ab * t
			if p.distance_to(proj) < radius:
				return true
		return false

	# A. Tall trees placed in dense background forests (MIN 28.0m from road, clear of flight corridors)
	var tree_count := 0
	var tree_attempts := 0
	while tree_count < 140 and tree_attempts < 600:
		tree_attempts += 1
		var px = rng.randf_range(-340.0, 340.0)
		var pz = rng.randf_range(-340.0, 220.0)

		# Strict clearance: 28m ensures trees never block driving line or camera sightlines
		if get_2d_road_dist.call(px, pz) < 28.0:
			continue
		if is_in_jump_corridor.call(px, pz):
			continue

		var py = get_ground_y.call(px, pz)
		# Skip submerged spots in the lake basin
		if py < -1.8:
			continue

		# Skip sheer cliff faces (>50 deg slope) so trees only sit on stable ground
		var h_x = get_ground_y.call(px + 2.0, pz)
		var h_z = get_ground_y.call(px, pz + 2.0)
		var max_grad = maxf(absf(h_x - py), absf(h_z - py)) / 2.0
		if max_grad > 1.20:
			continue

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
			# Sink trunk by 0.25m so base roots sit solidly on slopes with zero floating gaps
			tree_inst.position = Vector3(px, py - 0.25, pz)
			var sc = rng.randf_range(1.3, 2.3)
			tree_inst.scale = Vector3(sc, sc, sc)
			tree_inst.rotation_degrees = Vector3(0, rng.randf_range(0, 360), 0)
			veg_container.add_child(tree_inst)

	# B. Low-profile bushes placed along roadsides (strictly along normal outside curb, min 11.5m, max 17.5m)
	if bush_model:
		var bush_count := 0
		var bush_attempts := 0
		track_len = curve.get_baked_length()
		while bush_count < 50 and bush_attempts < 400:
			bush_attempts += 1
			var t_offset = rng.randf_range(12.0, track_len - 12.0)
			var path_pt = curve.sample_baked(t_offset)
			var next_pt = curve.sample_baked(minf(track_len, t_offset + 0.5))
			var prev_pt = curve.sample_baked(maxf(0.0, t_offset - 0.5))
			var tangent = (next_pt - prev_pt).normalized()
			if tangent.length_squared() < 0.001:
				tangent = Vector3.FORWARD
			# Horizontal normal perpendicular to tangent
			var normal = Vector3(-tangent.z, 0.0, tangent.x).normalized()

			var side_sign = -1.0 if rng.randf() < 0.5 else 1.0
			var side_dist = rng.randf_range(11.5, 17.5)
			var bush_pos = path_pt + normal * (side_sign * side_dist)

			# Strict check against ALL points of the road: must never be within 11.0m
			var min_dist_all = get_2d_road_dist.call(bush_pos.x, bush_pos.z)
			if min_dist_all < 11.0:
				continue
			if is_in_jump_corridor.call(bush_pos.x, bush_pos.z):
				continue

			var ground_h = get_ground_y.call(bush_pos.x, bush_pos.z)
			if ground_h < -1.8:
				continue

			# Reject steep cliff cuts between switchback tiers (slope > 50 deg)
			var b_hx = get_ground_y.call(bush_pos.x + 1.5, bush_pos.z)
			var b_hz = get_ground_y.call(bush_pos.x, bush_pos.z + 1.5)
			var b_grad = maxf(absf(b_hx - ground_h), absf(b_hz - ground_h)) / 1.5
			if b_grad > 1.15:
				continue

			bush_pos.y = ground_h - 0.12

			var bush_inst = bush_model.instantiate()
			bush_count += 1
			bush_inst.name = "Bush_%d" % bush_count
			bush_inst.position = bush_pos
			var sc = rng.randf_range(0.65, 1.05)
			bush_inst.scale = Vector3(sc, sc, sc)
			bush_inst.rotation_degrees = Vector3(0, rng.randf_range(0, 360), 0)
			veg_container.add_child(bush_inst)

	# C. Wildflowers in the meadows and along gentle slopes
	var flower_models = [flower_blue_model, flower_white_model]
	var flower_count := 0
	var flower_attempts := 0
	while flower_count < 50 and flower_attempts < 300:
		flower_attempts += 1
		var f_packed = flower_models[rng.randi() % flower_models.size()]
		if f_packed:
			var px = rng.randf_range(-180.0, 180.0)
			var pz = rng.randf_range(20.0, 210.0)
			if get_2d_road_dist.call(px, pz) < 11.0:
				continue
			var py = get_ground_y.call(px, pz)
			if py < -1.8:
				continue

			# Reject steep slopes for delicate flowers
			var f_hx = get_ground_y.call(px + 1.5, pz)
			var f_hz = get_ground_y.call(px, pz + 1.5)
			var f_grad = maxf(absf(f_hx - py), absf(f_hz - py)) / 1.5
			if f_grad > 1.15:
				continue

			var f_inst = f_packed.instantiate()
			flower_count += 1
			f_inst.name = "Flowers_%d" % flower_count
			f_inst.position = Vector3(px, py - 0.08, pz)
			var sc = rng.randf_range(1.2, 1.8)
			f_inst.scale = Vector3(sc, sc, sc)
			f_inst.rotation_degrees = Vector3(0, rng.randf_range(0, 360), 0)
			veg_container.add_child(f_inst)

	# D. Grass clumps scattered in meadows and along slopes
	if grass_model:
		var grass_count := 0
		var grass_attempts := 0
		while grass_count < 60 and grass_attempts < 300:
			grass_attempts += 1
			var px = rng.randf_range(-220.0, 220.0)
			var pz = rng.randf_range(-120.0, 210.0)
			if get_2d_road_dist.call(px, pz) < 11.0:
				continue
			var py = get_ground_y.call(px, pz)
			if py < -1.8:
				continue

			# Reject steep cliff cuts for grass clumps
			var g_hx = get_ground_y.call(px + 1.5, pz)
			var g_hz = get_ground_y.call(px, pz + 1.5)
			var g_grad = maxf(absf(g_hx - py), absf(g_hz - py)) / 1.5
			if g_grad > 1.15:
				continue

			var g_inst = grass_model.instantiate()
			grass_count += 1
			g_inst.name = "Grass_%d" % grass_count
			g_inst.position = Vector3(px, py - 0.08, pz)
			var sc = rng.randf_range(0.75, 1.3)
			g_inst.scale = Vector3(sc, sc, sc)
			g_inst.rotation_degrees = Vector3(0, rng.randf_range(0, 360), 0)
			veg_container.add_child(g_inst)

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
		# If child was already owned by an instantiated sub-scene, preserve its internal encapsulation
		if child.owner != null and child.owner != scene_root:
			continue
		_set_owner_recursive(child, scene_root)
