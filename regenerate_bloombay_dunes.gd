# regenerate_bloombay_dunes.gd
# Builds BloombayDunesLevel.tscn:
# Coastal Grand Prix circuit featuring a high-speed section along the beach with rolling surf waves,
# a technical climb through wind-sculpted sand dunes, a big dune-crest jump, and a fast beachfront straight.
extends Node

func _ready() -> void:
	print("=== Bloombay Dunes Grand Prix Level Generation ===")
	print("Building coastal dunes & beach circuit with rolling waves. Please wait...")

	var level_scene := Node3D.new()
	level_scene.name = "BloombayDunesLevel"

	var level_script: Script = load("res://levels/Level.gd")
	level_scene.set_script(level_script)

	var players_node := Node3D.new()
	players_node.name = "Players"
	level_scene.add_child(players_node)

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

	add_child(level_scene)

	# 1. Environment & Lighting (Tropical coastal sun & azure sky)
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.58, 0.95)
	sky_mat.sky_horizon_color = Color(0.72, 0.86, 0.96)
	sky_mat.ground_bottom_color = Color(0.78, 0.70, 0.52)
	sky_mat.ground_horizon_color = Color(0.85, 0.80, 0.70)
	sky_mat.sun_angle_max = 32.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.55
	env.ambient_light_color = Color(0.90, 0.95, 1.0)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.20
	env_node.environment = env
	level_scene.add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = Vector3(-38.0, 55.0, 0.0)
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 500.0
	sun.directional_shadow_split_1 = 0.1
	sun.directional_shadow_split_2 = 0.25
	sun.directional_shadow_split_3 = 0.55
	level_scene.add_child(sun)

	# 2. TrackPath & Curve3D (~1700m coastal & roller-coaster dunes circuit)
	var track_path := Path3D.new()
	track_path.name = "TrackPath"
	var curve := Curve3D.new()
	curve.bake_interval = 0.25

	var curve_pts = [
		# in, out, pos
		# --- SECTOR 1: BEACHFRONT SURF & START/FINISH STRAIGHT (X < -24.0, pure beach sand, offroad) ---
		# 0: Start / Finish Line (Heading North, facing -Z)
		[Vector3(0, 0, 22), Vector3(0, 0, -22), Vector3(-42.0, 0.70, 160.0)],
		# 1: Coastal beach straight heading North
		[Vector3(0, 0, 25), Vector3(0, 0, -25), Vector3(-44.0, 0.60, 70.0)],

		# --- SECTOR 2: ALONG THE OCEAN WATER & BREAKING SURF WAVES (X < -24.0) ---
		# 2: Deep shoreline curve right alongside rolling surf waves
		[Vector3(1, 0, 25), Vector3(-1, 0, -25), Vector3(-46.0, 0.55, -20.0)],
		# 3: Ocean surf shoreline straight with majestic waves rolling in from the west
		[Vector3(0, 0, 25), Vector3(0, 0, -25), Vector3(-47.0, 0.50, -110.0)],
		# 4: North tidal beach straight
		[Vector3(-2, 0, 25), Vector3(2, 0, -25), Vector3(-45.0, 0.60, -200.0)],
		# 5: North beach sweeping right turn apex
		[Vector3(-8, 0, 20), Vector3(8, 0.2, -20), Vector3(-36.0, 0.85, -270.0)],

		# --- SECTOR 3: INLAND DUNE CLIMB & ROLLER-COASTER PLUNGE 1 (Road starts at X >= -24.0) ---
		# 6: Crossing onto inland asphalt road into the dune canyon
		[Vector3(-14, -0.2, 10), Vector3(14, 0.3, -10), Vector3(-15.0, 1.80, -305.0)],
		# 7: Steep climb through golden sand dune bluffs
		[Vector3(-16, -0.6, -4), Vector3(16, 0.6, 4), Vector3(25.0, 6.50, -315.0)],
		# 8: Ascending the high north dune ridge
		[Vector3(-18, -1.0, -8), Vector3(18, 1.0, 8), Vector3(80.0, 15.0, -295.0)],
		# 9: DUNE CREST 1 — Summit with ocean vista (+24.0m)
		[Vector3(-16, -0.8, -14), Vector3(16, 0.8, 14), Vector3(135.0, 24.0, -250.0)],
		# 10: Roller-coaster plunge down the dune ridge slope
		[Vector3(-12, 1.0, -16), Vector3(12, -1.0, 16), Vector3(175.0, 16.0, -185.0)],
		# 11: DUNE VALLEY 1 — Compression dip into deep dune bowl (+7.0m)
		[Vector3(-6, 1.2, -18), Vector3(6, -1.2, 18), Vector3(195.0, 7.0, -115.0)],

		# --- SECTOR 4: SECOND CLIMB TO SUMMIT & BIG AIR CREST JUMP ---
		# 12: Powering up the eastern dune wall
		[Vector3(-4, -1.2, -18), Vector3(4, 1.2, 18), Vector3(215.0, 17.5, -45.0)],
		# 13: DUNE CREST 2 — High summit sweeping hairpin (+27.5m)
		[Vector3(-8, -0.8, -16), Vector3(8, 0.8, 16), Vector3(205.0, 27.5, 35.0)],
		# 14: Jump Takeoff Ramp on high ridge (+26.0m)
		[Vector3(-4, -0.4, -12), Vector3(4, 1.8, 12), Vector3(180.0, 26.0, 95.0)],
		# 15: Jump Landing slope into dune amphitheater (+13.5m)
		[Vector3(-4, 1.8, -12), Vector3(4, -0.8, 12), Vector3(155.0, 13.5, 145.0)],

		# --- SECTOR 5: DUNE BASIN CHICANE & THIRD DUNE CREST ---
		# 16: DUNE BASIN 2 — Low basin drift sweep (+6.5m)
		[Vector3(6, 1.0, -14), Vector3(-6, -0.6, 14), Vector3(120.0, 6.5, 185.0)],
		# 17: Carving right around golden dune pillars
		[Vector3(12, -0.4, -14), Vector3(-12, 0.4, 14), Vector3(90.0, 11.0, 240.0)],
		# 18: DUNE CREST 3 — Overlook ridge (+21.0m)
		[Vector3(-10, -1.0, -14), Vector3(10, 1.0, 14), Vector3(125.0, 21.0, 285.0)],
		# 19: High dune crest sweeping towards coastal horizon (+19.5m)
		[Vector3(-8, 0.2, -14), Vector3(8, -0.2, 14), Vector3(150.0, 19.5, 340.0)],

		# --- SECTOR 6: DOWNHILL ROLLER-COASTER RETURN TO BEACH ---
		# 20: Sweeping downhill curve carving through dune pass
		[Vector3(14, 1.0, -8), Vector3(-14, -1.0, 8), Vector3(100.0, 12.0, 375.0)],
		# 21: Plunging descent through dune valley cut
		[Vector3(18, 1.0, 2), Vector3(-18, -1.0, -2), Vector3(35.0, 5.5, 360.0)],
		# 22: Coastal approach curve re-entering beach (X < -24.0)
		[Vector3(16, 0.4, 8), Vector3(-16, -0.4, -8), Vector3(-10.0, 2.0, 310.0)],
		# 23: Swooping onto beach sand
		[Vector3(10, 0.2, 14), Vector3(-6, -0.2, -14), Vector3(-36.0, 0.85, 245.0)],
		# 24: Straightening onto finish straight
		[Vector3(4, 0.05, 14), Vector3(-2, -0.05, -14), Vector3(-40.0, 0.70, 205.0)],
		# 25: Closing back to Point 0
		[Vector3(0, 0, 22), Vector3(0, 0, -22), Vector3(-42.0, 0.65, 160.0)]
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
	tg.set("level_prefix", "bloombay_dunes")
	tg.set("track_layout_type", 0)
	tg.set("terrain_resolution", 420)
	tg.set("terrain_size", Vector2(950.0, 950.0))
	tg.set("hill_height", 14.0)
	tg.set("road_width", 15.0)
	tg.set("curb_outer_width", 17.0)
	tg.set("road_y_offset", 0.06)
	tg.set("curb_y_offset", 0.06)
	tg.set("terrain_recession_collision", 0.12)
	tg.set("terrain_recession_visual", 0.18)
	tg.set("no_water", false)
	tg.set("no_grass", true)
	tg.set("terrain_grass_count", 0)

	var sand_tex: Texture2D = load("res://materials/sand.png") as Texture2D
	var sand_norm: Texture2D = load("res://materials/sand_normal.png") as Texture2D
	var asphalt_tex: Texture2D = load("res://materials/asphalt.png") as Texture2D
	if sand_tex:
		var sand_mat := StandardMaterial3D.new()
		sand_mat.albedo_texture = sand_tex
		sand_mat.albedo_color = Color(1.0, 0.96, 0.88)
		sand_mat.uv1_scale = Vector3(0.12, 0.12, 0.12)
		sand_mat.uv1_triplanar = true
		sand_mat.roughness = 0.92
		if sand_norm:
			sand_mat.normal_enabled = true
			sand_mat.normal_texture = sand_norm
			sand_mat.normal_scale = 0.85
		tg.set("grass_material", sand_mat)

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

	# 4. Finish Line & Starting Grid
	var gate_scene: PackedScene = load("res://CheckpointGate.tscn")
	var spawn_scene: PackedScene = load("res://SpawnIndicator.tscn")

	var finish_line = gate_scene.instantiate()
	finish_line.name = "FinishLine"
	finish_line.position = Vector3(-42.0, 0.76, 160.0)
	finish_line.rotation_degrees = Vector3(0, 0, 0)
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

	# 5. Checkpoints Container (5 milestones + finish line = 6 gates)
	var checkpoints_container := Node3D.new()
	checkpoints_container.name = "Checkpoints"
	level_scene.add_child(checkpoints_container)

	var cp_defs = [
		# name, dist_ratio
		["Checkpoint_1", 0.16],  # Tidal beach straight (along the rolling surf)
		["Checkpoint_2", 0.33],  # Turn inland into dune canyon climb
		["Checkpoint_3", 0.50],  # Dune summit 1 & roller-coaster plunge
		["Checkpoint_4", 0.67],  # Ridge jump landing slope into amphitheater
		["Checkpoint_5", 0.83]   # Third dune crest & coastal descent
	]

	var track_len: float = curve.get_baked_length()
	for cp_info in cp_defs:
		var dist_along := track_len * float(cp_info[1])
		var cp_pos := curve.sample_baked(dist_along)
		var next_pos := curve.sample_baked(minf(track_len, dist_along + 1.5))
		var forward := (next_pos - cp_pos).normalized()
		var rot_y := rad_to_deg(atan2(-forward.x, -forward.z))

		var gate = gate_scene.instantiate()
		gate.name = str(cp_info[0])
		gate.position = cp_pos + Vector3(0, 0.1, 0)
		gate.rotation_degrees = Vector3(0, rot_y, 0)
		checkpoints_container.add_child(gate)

	# 6. Boost Pads
	var boost_scene: PackedScene = load("res://BoostPad.tscn")
	var boost_container := Node3D.new()
	boost_container.name = "BoostPads"
	level_scene.add_child(boost_container)

	if boost_scene:
		var bp_defs = [
			# pos, rot_y_deg
			[Vector3(-47.0, 0.55, -80.0), 0.0],    # Beachfront tidal straight speed boost
			[Vector3(35.0, 7.80, -310.0), -70.0],  # Dune climb launcher
			[Vector3(200.0, 9.50, -90.0), -20.0],  # Valley plunge exit into ridge 2
			[Vector3(180.0, 26.05, 95.0), -22.0],  # Takeoff ramp big jump launch boost
			[Vector3(145.0, 20.20, 320.0), 35.0]   # Basin exit towards coastal descent
		]
		for i in range(bp_defs.size()):
			var bp = boost_scene.instantiate()
			bp.name = "BoostPad_%d" % (i + 1)
			bp.position = bp_defs[i][0]
			bp.rotation_degrees = Vector3(0, bp_defs[i][1], 0)
			boost_container.add_child(bp)

	# 7. Scenery Props & Vegetation Containers (empty so user can add custom trees/plants)
	var veg_container := Node3D.new()
	veg_container.name = "Vegetation"
	level_scene.add_child(veg_container)

	# 8. Additional Containers
	for c_name in ["Props", "AlternativePaths", "Environment"]:
		var c := Node3D.new()
		c.name = c_name
		level_scene.add_child(c)

	# 9. Setup Level script connections
	level_scene.set("track_path", track_path)
	level_scene._setup_checkpoints()

	# 10. Set Scene Owners Recursively
	_set_owner_recursive(level_scene, level_scene)

	# 11. Save PackedScene
	remove_child(level_scene)
	var target_path := "res://levels/BloombayDunesLevel.tscn"
	var packed_scene := PackedScene.new()
	var pack_err = packed_scene.pack(level_scene)
	if pack_err != OK:
		push_error("Failed to pack BloombayDunesLevel.tscn: %d" % pack_err)
		get_tree().quit(1)
		return

	var save_err = ResourceSaver.save(packed_scene, target_path)
	if save_err != OK:
		push_error("Failed to save BloombayDunesLevel.tscn: %d" % save_err)
		get_tree().quit(1)
		return

	print("Successfully generated and saved res://levels/BloombayDunesLevel.tscn!")
	get_tree().quit(0)


func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	if node != scene_root:
		node.owner = scene_root
	for child in node.get_children():
		if child.owner != null and child.owner != scene_root:
			continue
		_set_owner_recursive(child, scene_root)
