# regenerate_frostpeak_creek.gd
# Builds FrostpeakCreekLevel.tscn:
# Alpine winter Grand Prix circuit with rolling elevation changes, a winding central creek,
# two big jump leaps over the water, an alpine timber bridge crossing,
# snow-covered road sections with slowdown and snow powder VFX, and a branching alternative shortcut.
extends Node

func _ready() -> void:
	print("=== Frostpeak Creek Grand Prix Level Generation ===")
	print("Building alpine snow circuit with central creek and branching route. Please wait...")

	var level_scene := Node3D.new()
	level_scene.name = "FrostpeakCreekLevel"

	var level_script: Script = load("res://levels/Level.gd")
	level_scene.set_script(level_script)
	add_child(level_scene)

	# 1. Environment & Lighting (Crisp Winter Atmosphere)
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.28, 0.55, 0.92)
	sky_mat.sky_horizon_color = Color(0.72, 0.84, 0.94)
	sky_mat.ground_bottom_color = Color(0.85, 0.90, 0.96)
	sky_mat.ground_horizon_color = Color(0.78, 0.88, 0.95)
	sky_mat.sun_angle_max = 28.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.6
	env.ambient_light_color = Color(0.88, 0.93, 1.0)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_bloom = 0.12
	env_node.environment = env
	level_scene.add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = Vector3(-46.0, 42.0, 0.0)
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 480.0
	sun.directional_shadow_split_1 = 0.1
	sun.directional_shadow_split_2 = 0.25
	sun.directional_shadow_split_3 = 0.55
	level_scene.add_child(sun)

	# Ambient winter wind audio
	var wind_stream = load("res://sounds/dragon-studio-winter-wind-402331.mp3")
	if wind_stream:
		var wind_player := AudioStreamPlayer.new()
		wind_player.name = "WinterWindAudio"
		wind_player.stream = wind_stream
		wind_player.volume_db = -12.0
		wind_player.autoplay = true
		level_scene.add_child(wind_player)

	# Atmospheric Falling Snow Particles
	var snow_particles := GPUParticles3D.new()
	snow_particles.name = "FallingSnow"
	var falling_snow_script = load("res://FallingSnow.gd")
	if falling_snow_script:
		snow_particles.set_script(falling_snow_script)
	snow_particles.amount = 2500
	snow_particles.lifetime = 3.2
	snow_particles.speed_scale = 0.5
	snow_particles.randomness = 0.8
	snow_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	snow_particles.visibility_aabb = AABB(Vector3(-45, -35, -45), Vector3(90, 45, 90))

	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(35.0, 1.0, 35.0)
	pmat.direction = Vector3(0.2, -1.0, 0.1)
	pmat.spread = 18.0
	pmat.initial_velocity_min = 2.0
	pmat.initial_velocity_max = 6.0
	pmat.gravity = Vector3(0, -3.5, 0)
	pmat.scale_min = 0.8
	pmat.scale_max = 1.4
	snow_particles.process_material = pmat

	var snow_quad := QuadMesh.new()
	snow_quad.size = Vector2(0.12, 0.12)
	var fall_snow_mat := StandardMaterial3D.new()
	fall_snow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fall_snow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fall_snow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fall_snow_mat.vertex_color_use_as_albedo = true
	fall_snow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 0.95), Color(1.0, 1.0, 1.0, 0.0)])
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.width = 32
	grad_tex.height = 32
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(0.5, 0.0)
	fall_snow_mat.albedo_texture = grad_tex
	fall_snow_mat.albedo_color = Color(0.96, 0.98, 1.0, 0.9)

	snow_quad.material = fall_snow_mat
	snow_particles.draw_pass_1 = snow_quad
	level_scene.add_child(snow_particles)

	# 2. TrackPath & Curve3D (~1350m closed circuit with undulating elevations)
	# Central creek meanders near X=0 from Z=+175 to Z=-370.
	var track_path := Path3D.new()
	track_path.name = "TrackPath"
	var curve := Curve3D.new()
	curve.bake_interval = 0.25

	# Clockwise circuit:
	# - Starts on West bank (X=-45m, Y=0.8m) heading North
	# - JUMP 1 over central creek from West bank to East bank
	# - East Ridge climb with branching route (Standard Route A vs Inner Canyon Shortcut B)
	# - Merged road crosses ALPINETIMBERBRIDGE from East bank to West bank
	# - Climbs high Western mountain ridge (Y up to 17.5m)
	# - JUMP 2 Super-Leap over central creek from West bank to East bank
	# - Sweeps through southern meadow glade on solid ground and aligns smoothly into Finish straight!
	var curve_pts = [
		# --- SECTION 0: START / FINISH STRAIGHT (West bank, X = -45m, Y = 0.8m, heading North towards -Z) ---
		# 0: Finish Line / Starting Grid
		[Vector3(0, 0, 25), Vector3(0, 0, -25), Vector3(-45.0, 0.8, 120.0)],
		# 1: High-speed valley straight
		[Vector3(0, 0, 25), Vector3(0, 0, -25), Vector3(-45.0, 1.2, 50.0)],
		# 2: Approach to Turn 1
		[Vector3(0, -0.3, 20), Vector3(0, 0.5, -20), Vector3(-45.0, 2.0, -10.0)],

		# --- SECTION 1: CROSSING 1 (JUMP 1 OVER CENTRAL CREEK: WEST TO EAST) ---
		# 3: Jump 1 In-run Embankment Climb
		[Vector3(-6, -1.0, 15), Vector3(6, 1.0, -15), Vector3(-35.0, 5.5, -50.0)],
		# 4: Jump 1 Takeoff Lip (X=-16m, Y=8.5m, launching North-East across creek)
		[Vector3(-10, -0.8, 12), Vector3(14, 1.8, -16), Vector3(-16.0, 8.5, -72.0)],
		# 5: Jump 1 Landing Terrace on East bank (X=+26m, Y=4.5m)
		[Vector3(-14, 1.5, 16), Vector3(8, -0.5, -12), Vector3(26.0, 4.5, -112.0)],

		# --- SECTION 2: EAST FLANK CLIMB & THE FORK (BRANCHING PATH) ---
		# 6: Sweeping along eastern snowy terrace
		[Vector3(-8, -0.5, 12), Vector3(8, 0.6, -14), Vector3(42.0, 6.5, -140.0)],
		# 7: Pre-Fork Approach (Checkpoint 5 placed here right before the split)
		[Vector3(-6, -0.5, 15), Vector3(6, 0.5, -15), Vector3(56.0, 8.5, -175.0)],
		# 8: Standard Route (Route A): Wide outer scenic bluff overlooking valley
		[Vector3(-12, -0.5, 16), Vector3(8, 0.3, -18), Vector3(82.0, 10.5, -215.0)],
		# 9: Standard Route: High vista sweep
		[Vector3(6, 0.3, 16), Vector3(-8, -0.4, -16), Vector3(80.0, 9.5, -255.0)],
		# 10: Re-merging point where Standard and Alternative routes rejoin (Checkpoint 6 placed here)
		[Vector3(12, 0.5, 12), Vector3(-14, -0.3, -10), Vector3(48.0, 6.0, -280.0)],

		# --- SECTION 3: CROSSING 2 (ALPINE TIMBER BRIDGE OVER CREEK: EAST TO WEST) ---
		# 11: East entrance approach to Alpine Bridge
		[Vector3(10, 0.2, 8), Vector3(-10, 0, 0), Vector3(24.0, 4.8, -305.0)],
		# 12: Alpine Timber Bridge Center (X = 0m, Z = -305m, Y = 4.8m)
		[Vector3(10, 0, 0), Vector3(-10, 0, 0), Vector3(0.0, 4.8, -305.0)],
		# 13: West exit of Alpine Bridge (Checkpoint 7 placed here)
		[Vector3(10, 0, 0), Vector3(-10, 0.2, -6), Vector3(-24.0, 4.8, -305.0)],

		# --- SECTION 4: HIGH WESTERN RIDGE OVERLOOK (CLIMB TO SUMMIT) ---
		# 14: Ascending western snowy knoll
		[Vector3(12, -0.5, -6), Vector3(-12, 0.8, 10), Vector3(-55.0, 7.5, -295.0)],
		# 15: Hairpin turn climbing high western ridge
		[Vector3(6, -0.8, -14), Vector3(-4, 0.8, 18), Vector3(-82.0, 11.5, -260.0)],
		# 16: High western ridge traverse overlooking the whole valley
		[Vector3(2, -0.6, -20), Vector3(-2, 0.5, 22), Vector3(-96.0, 15.0, -180.0)],
		# 17: High peak summit traverse
		[Vector3(0, -0.2, -25), Vector3(0, 0.2, 25), Vector3(-98.0, 17.5, -80.0)],
		# 18: High ridge continuing south along mountain crest
		[Vector3(-2, 0.2, -22), Vector3(2, -0.2, 22), Vector3(-92.0, 17.0, 10.0)],
		# 19: Crest turn heading East towards creek (Approach to Jump 2)
		[Vector3(-8, 0.3, -18), Vector3(12, -0.1, 16), Vector3(-68.0, 15.5, 80.0)],

		# --- SECTION 5: CROSSING 3 (JUMP 2 SUPER-LEAP: WEST TO EAST OVER CREEK) ---
		# 20: Jump 2 Takeoff Lip (X=-22m, Y=15.5m, Z=125m, launching South-East across creek)
		[Vector3(-14, 0.2, -10), Vector3(18, 1.8, 12), Vector3(-22.0, 15.5, 125.0)],
		# 21: Jump 2 Landing Terrace on East bank (X=+30m, Y=5.5m, Z=168m)
		[Vector3(-16, 2.0, -12), Vector3(10, -0.6, 10), Vector3(30.0, 5.5, 168.0)],

		# --- SECTION 6: SOUTH MEADOW LOOP & RETURN TO FINISH STRAIGHT ---
		# 22: Sweeping around southern alpine forest (solid ground south of creek)
		[Vector3(-6, 0.4, -14), Vector3(-6, -0.3, 14), Vector3(38.0, 3.5, 215.0)],
		# 23: Southern meadow crossing
		[Vector3(14, 0.3, 0), Vector3(-16, -0.2, 0), Vector3(5.0, 2.2, 245.0)],
		# 24: Turn rounding back toward home straight
		[Vector3(12, 0.2, 10), Vector3(-10, -0.2, -12), Vector3(-35.0, 1.4, 225.0)],
		# 25: Aligning smoothly onto Start / Finish straight
		[Vector3(4, 0.2, 16), Vector3(0, -0.1, -20), Vector3(-45.0, 0.9, 180.0)],
		# 26: Return to Start / Finish Line (smooth loop closure)
		[Vector3(0, 0.1, 20), Vector3(0, 0, -25), Vector3(-45.0, 0.8, 120.0)],
	]

	for pt in curve_pts:
		curve.add_point(pt[2], pt[0], pt[1])

	track_path.curve = curve
	level_scene.add_child(track_path)

	# 3. TerrainGenerator Setup (Frostpeak Creek Snow World)
	var tg := Node3D.new()
	tg.name = "TerrainGenerator"
	var tg_script: Script = load("res://TerrainGenerator.gd")
	tg.set_script(tg_script)
	tg.set("level_prefix", "frostpeak_creek")
	tg.set("track_layout_type", 0)
	tg.set("terrain_resolution", 420)
	tg.set("terrain_size", Vector2(900.0, 900.0))
	tg.set("hill_height", 16.0)
	tg.set("road_width", 15.0)
	tg.set("curb_outer_width", 17.0)
	tg.set("road_y_offset", 0.06)
	tg.set("curb_y_offset", 0.06)
	tg.set("terrain_recession_collision", 0.12)
	tg.set("terrain_recession_visual", 0.18)
	tg.set("no_water", false)
	tg.set("no_grass", true)
	tg.set("terrain_grass_count", 0)
	tg.set("generate_bridge_supports", false)

	# Snow Terrain Material (Pure crisp alpine snow PBR)
	var sand_norm: Texture2D = load("res://materials/sand_normal.png") as Texture2D
	var snow_mat := StandardMaterial3D.new()
	snow_mat.albedo_color = Color(0.97, 0.98, 1.0)
	snow_mat.roughness = 0.92
	snow_mat.metallic = 0.02
	if sand_norm:
		snow_mat.normal_enabled = true
		snow_mat.normal_texture = sand_norm
		snow_mat.normal_scale = 0.4
		snow_mat.uv1_scale = Vector3(0.15, 0.15, 0.15)
		snow_mat.uv1_triplanar = true
	tg.set("grass_material", snow_mat)

	# Asphalt road material with subtle cool winter hue
	var asphalt_tex: Texture2D = load("res://materials/asphalt.png") as Texture2D
	if asphalt_tex:
		var road_mat := StandardMaterial3D.new()
		road_mat.albedo_texture = asphalt_tex
		road_mat.albedo_color = Color(0.88, 0.90, 0.94)
		road_mat.uv1_scale = Vector3(0.2, 0.2, 0.2)
		road_mat.roughness = 0.78
		tg.set("road_material", road_mat)

	level_scene.add_child(tg)
	tg.set("track_path", track_path)
	tg.call("generate_world")

	# 4. Alternative Route (Branching Shortcut Path)
	var alt_container := Node3D.new()
	alt_container.name = "AlternativePaths"
	level_scene.add_child(alt_container)

	var alt_path := Path3D.new()
	alt_path.name = "AlternativePath_CanyonCut"
	var alt_curve := Curve3D.new()
	alt_curve.bake_interval = 0.25

	# Alternative shortcut branch: splits at inner curb (47.5, 8.1, -183), plunges through inner snow ravine, merges at inner curb (45.0, 6.2, -272)
	var alt_pts = [
		[Vector3(0, 0, 8), Vector3(-2.5, -0.4, -12), Vector3(47.5, 8.1, -183.0)],   # 0: Fork start off inner curb
		[Vector3(3, 0.3, 12), Vector3(-2, -0.3, -14), Vector3(44.0, 7.2, -210.0)], # 1: Inner canyon descent
		[Vector3(2, 0.2, 12), Vector3(2, -0.2, -12), Vector3(38.0, 6.2, -245.0)],  # 2: Mid shortcut (Snowdrift zone)
		[Vector3(-2, -0.2, 10), Vector3(2, 0.2, -8), Vector3(45.0, 6.2, -272.0)],  # 3: Merge rejoin at inner curb
	]
	for p in alt_pts:
		alt_curve.add_point(p[2], p[0], p[1])
	alt_path.curve = alt_curve
	alt_container.add_child(alt_path)

	# Generate 3D cobblestone road mesh, curbs, solid stone embankment & collision for the alternative route
	_build_cobblestone_road(level_scene, alt_curve, 11.5, "AlternativeRoad")

	# 5. Alpine Timber Bridge across Creek (Crossing 2: X = -27m to +27m at Z = -305, Y = 4.8m)
	_build_detailed_alpine_bridge(level_scene, Vector3(0.0, 4.8, -305.0), 54.0, 17.6)

	# 6. Natural Snow-Covered Sections on Road (Organic surface drifts with "snow" group & "is_snow" meta)
	var snow_sections := Node3D.new()
	snow_sections.name = "SnowCoveredRoadSections"
	level_scene.add_child(snow_sections)

	# Section A: Pre-Jump 1 In-run Snowdrift (X=-32, Y=5.68, Z=-52)
	_create_natural_snow_drift(snow_sections, "SnowDrift_Jump1Approach", Vector3(-32.0, 5.68, -52.0), Vector3(15.0, 1.15, 18.0), 20.0, 0.0)
	# Section B: Eastern Flank Glade (X=45, Y=6.68, Z=-145)
	_create_natural_snow_drift(snow_sections, "SnowDrift_EastGlade", Vector3(45.0, 6.68, -145.0), Vector3(15.0, 1.05, 16.0), -16.0, 1.8)
	# Section C: Deep Snow on Alternative Shortcut Route (X=38, Y=6.18, Z=-245)
	_create_natural_snow_drift(snow_sections, "SnowDrift_AltRouteCut", Vector3(38.0, 6.18, -245.0), Vector3(12.5, 1.30, 22.0), 5.0, 3.5)
	# Section D: High Summit Ridge Snowdrift (X=-98, Y=17.56, Z=-80)
	_create_natural_snow_drift(snow_sections, "SnowDrift_SummitRidge", Vector3(-98.0, 17.56, -80.0), Vector3(15.0, 1.10, 20.0), 0.0, 5.2)
	# Section E: Pre-Jump 2 Summit Snowdrift (X=-45, Y=15.56, Z=100)
	_create_natural_snow_drift(snow_sections, "SnowDrift_Jump2Approach", Vector3(-45.0, 15.56, 100.0), Vector3(15.0, 1.20, 16.0), -35.0, 7.1)

	# 7. Players node
	var players_node := Node3D.new()
	players_node.name = "Players"
	level_scene.add_child(players_node)

	# 8. Finish Line & Starting Grid
	var gate_scene: PackedScene = load("res://CheckpointGate.tscn")
	var spawn_scene: PackedScene = load("res://SpawnIndicator.tscn")

	var finish_line = gate_scene.instantiate()
	finish_line.name = "FinishLine"
	finish_line.position = Vector3(-45.0, 0.86, 120.0)
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

	# 9. Multiplayer Spawners
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

	# 10. Checkpoints Container (6 curve-aligned milestone checkpoints + Finish Line)
	var checkpoints_container := Node3D.new()
	checkpoints_container.name = "Checkpoints"
	level_scene.add_child(checkpoints_container)

	var track_len: float = curve.get_baked_length()
	# 6 milestone checkpoints spaced along the 1350m track, avoiding mid-air jump gaps:
	# CP 1: 130m - Valley floor straight before Jump 1 in-run
	# CP 2: 330m - East bank climb before the branching fork
	# CP 3: 490m - Post-merge approach right before the Alpine Timber Bridge
	# CP 4: 700m - Western mountain climb shelf heading South
	# CP 5: 900m - High summit ridge overlook before Jump 2 approach
	# CP 6: 1180m - Southern meadow glade before curve into finish straight
	var milestone_offsets = [130.0, 330.0, 490.0, 700.0, 900.0, 1180.0]

	for i in range(milestone_offsets.size()):
		var dist_along: float = milestone_offsets[i]
		var cp_pos := curve.sample_baked(dist_along)
		var next_pos := curve.sample_baked(minf(track_len, dist_along + 1.0))
		var forward := (next_pos - cp_pos).normalized()
		var rot_y := rad_to_deg(atan2(-forward.x, -forward.z))

		var gate = gate_scene.instantiate()
		gate.name = "Checkpoint_%d" % (i + 1)
		gate.position = cp_pos + Vector3(0, 0.1, 0)
		gate.rotation_degrees = Vector3(0, rot_y, 0)
		checkpoints_container.add_child(gate)


	# 12. Boost Pads
	var boost_scene: PackedScene = load("res://BoostPad.tscn")
	var boost_container := Node3D.new()
	boost_container.name = "BoostPads"
	level_scene.add_child(boost_container)

	if boost_scene:
		var bp_defs = [
			# Jump 1 Takeoff pair
			["Boost_Jump1_L", Vector3(-24.0, 7.5, -64.0), 314.0],
			["Boost_Jump1_R", Vector3(-20.0, 7.5, -60.0), 314.0],
			# Jump 2 Takeoff pair
			["Boost_Jump2_L", Vector3(-30.0, 15.5, 118.0), 220.0],
			["Boost_Jump2_R", Vector3(-26.0, 15.5, 114.0), 220.0],
			# Valley Straight Booster
			["Boost_StartStraight", Vector3(-45.0, 1.0, 80.0), 180.0],
			# Alternative Shortcut Boosters (Reward for taking technical cut)
			["Boost_AltShortcut_1", Vector3(42.0, 6.8, -225.0), 180.0],
			["Boost_AltShortcut_2", Vector3(40.0, 6.2, -260.0), 180.0],
			# High Summit Ridge Overlook
			["Boost_SummitStraight", Vector3(-98.0, 17.5, -40.0), 0.0]
		]
		for bp_info in bp_defs:
			var bp = boost_scene.instantiate()
			bp.name = bp_info[0]
			bp.position = bp_info[1]
			bp.rotation_degrees = Vector3(0, bp_info[2], 0)
			boost_container.add_child(bp)

	# 13. Item Boxes
	var item_scene: PackedScene = load("res://ItemBox.tscn")
	var item_container := Node3D.new()
	item_container.name = "ItemBoxes"
	level_scene.add_child(item_container)

	if item_scene:
		var item_rows = [
			# Row 1: Valley Straight (Z = 90)
			[Vector3(-48.0, 1.4, 90.0), Vector3(-45.0, 1.4, 90.0), Vector3(-42.0, 1.4, 90.0)],
			# Row 2: Standard Route Bluff (Z = -235)
			[Vector3(84.0, 10.8, -235.0), Vector3(81.0, 10.8, -235.0), Vector3(78.0, 10.8, -235.0)],
			# Row 3: Approach to Alpine Timber Bridge (Z = -305)
			[Vector3(16.0, 5.4, -305.0), Vector3(12.0, 5.4, -305.0)],
			# Row 4: High Summit Ridge before Jump 2 (Z = 40)
			[Vector3(-94.0, 17.8, 40.0), Vector3(-91.0, 17.8, 40.0), Vector3(-88.0, 17.8, 40.0)]
		]
		var item_idx := 1
		for row in item_rows:
			for pos in row:
				var ib = item_scene.instantiate()
				ib.name = "ItemBox_%d" % item_idx
				ib.position = pos
				item_container.add_child(ib)
				item_idx += 1

	# 14. Vegetation Container (Kept empty - ready for manual tree placement)
	var veg_container := Node3D.new()
	veg_container.name = "Vegetation"
	level_scene.add_child(veg_container)

	# 15. Rebuild Checkpoints Array & Wire up Level
	level_scene.set("track_path", track_path)
	level_scene._setup_checkpoints()

	# 16. Scene Ownership
	_set_owner_recursive(level_scene, level_scene)

	# 17. Save Packed Scene
	remove_child(level_scene)
	var target_path := "res://levels/FrostpeakCreekLevel.tscn"
	var packed_scene := PackedScene.new()
	var pack_err = packed_scene.pack(level_scene)
	if pack_err != OK:
		push_error("Failed to pack FrostpeakCreekLevel.tscn: %d" % pack_err)
		get_tree().quit(1)
		return

	var save_err = ResourceSaver.save(packed_scene, target_path)
	if save_err != OK:
		push_error("Failed to save FrostpeakCreekLevel.tscn: %d" % save_err)
		get_tree().quit(1)
		return

	print("Successfully generated and saved res://levels/FrostpeakCreekLevel.tscn!")
	get_tree().quit(0)


func _create_natural_snow_drift(parent: Node, drift_name: String, pos: Vector3, size: Vector3, yaw_deg: float, seed_offset: float = 0.0) -> void:
	var drift_scene: PackedScene = load("res://SnowDrift.tscn")
	var drift = drift_scene.instantiate()
	drift.name = drift_name
	drift.position = pos
	drift.rotation_degrees = Vector3(0, yaw_deg, 0)
	drift.set("size", size)
	drift.set("seed_offset", seed_offset)
	parent.add_child(drift)


func _build_detailed_alpine_bridge(parent: Node, center: Vector3, length: float, width: float) -> void:
	var bridge_root := Node3D.new()
	bridge_root.name = "AlpineTimberBridge"
	bridge_root.position = center

	# 1. PBR Materials
	var wood_mat := StandardMaterial3D.new()
	var wood_tex: Texture2D = load("res://materials/wood_planks.png") as Texture2D
	var wood_norm: Texture2D = load("res://materials/wood_planks_normal.png") as Texture2D
	var wood_rough: Texture2D = load("res://materials/wood_planks_roughness.png") as Texture2D
	if wood_tex:
		wood_mat.albedo_texture = wood_tex
	if wood_norm:
		wood_mat.normal_enabled = true
		wood_mat.normal_texture = wood_norm
		wood_mat.normal_scale = 1.0
	if wood_rough:
		wood_mat.roughness_texture = wood_rough
	wood_mat.roughness = 0.82
	wood_mat.uv1_scale = Vector3(0.35, 0.35, 0.35)
	wood_mat.uv1_triplanar = true

	# Darker heavy timber for railings, girders & trusses
	var timber_mat := StandardMaterial3D.new()
	if wood_tex:
		timber_mat.albedo_texture = wood_tex
		timber_mat.albedo_color = Color(0.72, 0.68, 0.65)
	if wood_norm:
		timber_mat.normal_enabled = true
		timber_mat.normal_texture = wood_norm
		timber_mat.normal_scale = 0.8
	timber_mat.roughness = 0.88
	timber_mat.uv1_scale = Vector3(0.5, 0.5, 0.5)
	timber_mat.uv1_triplanar = true

	# Stone masonry for piers & abutments
	var stone_mat := StandardMaterial3D.new()
	var stone_tex: Texture2D = load("res://materials/dark_canyon_rock.png") as Texture2D
	var stone_norm: Texture2D = load("res://materials/dark_canyon_rock_normal.png") as Texture2D
	if stone_tex:
		stone_mat.albedo_texture = stone_tex
	if stone_norm:
		stone_mat.normal_enabled = true
		stone_mat.normal_texture = stone_norm
		stone_mat.normal_scale = 0.9
	stone_mat.roughness = 0.90
	stone_mat.uv1_scale = Vector3(0.25, 0.25, 0.25)
	stone_mat.uv1_triplanar = true

	# 2. Driving Deck (spanning length=54m from X=-27 to +27, full 17.6m width to cover road and curbs)
	var deck_body := StaticBody3D.new()
	deck_body.name = "BridgeDeck"
	deck_body.add_to_group("track_surface", true)
	deck_body.position = Vector3(0, -0.12, 0)

	var deck_col := CollisionShape3D.new()
	var deck_shape := BoxShape3D.new()
	deck_shape.size = Vector3(length, 0.40, width)
	deck_col.shape = deck_shape
	deck_body.add_child(deck_col)

	var deck_mesh := MeshInstance3D.new()
	deck_mesh.name = "BridgeDeck_Mesh"
	var dm := BoxMesh.new()
	dm.size = Vector3(length, 0.38, width)
	deck_mesh.mesh = dm
	deck_mesh.material_override = wood_mat
	deck_body.add_child(deck_mesh)
	bridge_root.add_child(deck_body)

	# 3. Heavy Timber Wheel-Guard Curbs (left & right deck edges)
	var curb_h := 0.32
	var curb_w := 0.40
	for side in [-1.0, 1.0]:
		var curb_z = side * (width * 0.5 - curb_w * 0.5)
		var curb_inst := MeshInstance3D.new()
		curb_inst.name = "WheelGuard_" + ("N" if side < 0 else "S")
		var cm := BoxMesh.new()
		cm.size = Vector3(length, curb_h, curb_w)
		curb_inst.mesh = cm
		curb_inst.material_override = timber_mat
		curb_inst.position = Vector3(0, 0.16, curb_z)
		bridge_root.add_child(curb_inst)

	# 4. Massive Stone Shore Abutments (East & West banks, sealing ALL gaps)
	for side in [-1.0, 1.0]:
		var x_pos = side * 26.0
		var abut := StaticBody3D.new()
		abut.name = "StoneAbutment_" + ("E" if side > 0 else "W")
		abut.add_to_group("track_surface", true)
		abut.position = Vector3(x_pos, -3.5, 0)

		var a_col := CollisionShape3D.new()
		var a_shape := BoxShape3D.new()
		a_shape.size = Vector3(6.5, 7.5, width + 4.0)
		a_col.shape = a_shape
		abut.add_child(a_col)

		var a_mesh := MeshInstance3D.new()
		a_mesh.name = "Abutment_Mesh"
		var am := BoxMesh.new()
		am.size = a_shape.size
		a_mesh.mesh = am
		a_mesh.material_override = stone_mat
		abut.add_child(a_mesh)
		bridge_root.add_child(abut)

		# Stone Wing Walls that flare into the mountain bank
		for wing_side in [-1.0, 1.0]:
			var wing := MeshInstance3D.new()
			wing.name = "WingWall_" + ("E" if side > 0 else "W") + ("_N" if wing_side < 0 else "_S")
			var wm := BoxMesh.new()
			wm.size = Vector3(5.0, 6.5, 2.5)
			wing.mesh = wm
			wing.material_override = stone_mat
			wing.position = Vector3(x_pos + side * 1.5, -3.0, wing_side * (width * 0.5 + 2.0))
			wing.rotation_degrees = Vector3(0, side * wing_side * 22.0, 0)
			bridge_root.add_child(wing)

	# 5. Longitudinal Under-Deck Girders (4 heavy timber stringers)
	for g_idx in range(4):
		var gz = -width * 0.40 + g_idx * (width * 0.80 / 3.0)
		var girder := MeshInstance3D.new()
		girder.name = "Girder_%d" % g_idx
		var gm := BoxMesh.new()
		gm.size = Vector3(length - 4.0, 0.70, 0.50)
		girder.mesh = gm
		girder.material_override = timber_mat
		girder.position = Vector3(0, -0.65, gz)
		bridge_root.add_child(girder)

	# 6. Detailed Alpine Timber Truss Railings (North and South)
	var rail_z_dist := width * 0.5 - 0.20
	var post_spacing := 3.6
	var post_count := int((length - 4.0) / post_spacing)
	var start_x := - (post_count * post_spacing) * 0.5

	for side in [-1.0, 1.0]:
		var rail_side_name = "N" if side < 0 else "S"
		var rz = side * rail_z_dist

		# Solid Railing Collision Wall
		var rail_col_body := StaticBody3D.new()
		rail_col_body.name = "GuardrailCol_" + rail_side_name
		rail_col_body.position = Vector3(0, 0.80, rz)
		var r_col := CollisionShape3D.new()
		var r_shape := BoxShape3D.new()
		r_shape.size = Vector3(length, 1.60, 0.40)
		r_col.shape = r_shape
		rail_col_body.add_child(r_col)
		bridge_root.add_child(rail_col_body)

		# Top Handrail Beam
		var top_rail := MeshInstance3D.new()
		top_rail.name = "TopRail_" + rail_side_name
		var trm := BoxMesh.new()
		trm.size = Vector3(length, 0.28, 0.40)
		top_rail.mesh = trm
		top_rail.material_override = timber_mat
		top_rail.position = Vector3(0, 1.45, rz)
		bridge_root.add_child(top_rail)

		# Mid Rail Beam
		var mid_rail := MeshInstance3D.new()
		mid_rail.name = "MidRail_" + rail_side_name
		var mrm := BoxMesh.new()
		mrm.size = Vector3(length, 0.22, 0.25)
		mid_rail.mesh = mrm
		mid_rail.material_override = timber_mat
		mid_rail.position = Vector3(0, 0.85, rz)
		bridge_root.add_child(mid_rail)

		# Vertical Posts and Diagonal X-Braces
		for p_idx in range(post_count + 1):
			var px = start_x + p_idx * post_spacing
			var post := MeshInstance3D.new()
			post.name = "Post_" + rail_side_name + "_%d" % p_idx
			var post_m := BoxMesh.new()
			post_m.size = Vector3(0.36, 1.55, 0.36)
			post.mesh = post_m
			post.material_override = timber_mat
			post.position = Vector3(px, 0.75, rz)
			bridge_root.add_child(post)

			# Transverse floor cross-beam under deck at each post
			if side > 0:
				var floor_beam := MeshInstance3D.new()
				floor_beam.name = "FloorBent_%d" % p_idx
				var fbm := BoxMesh.new()
				fbm.size = Vector3(0.40, 0.50, width + 0.6)
				floor_beam.mesh = fbm
				floor_beam.material_override = timber_mat
				floor_beam.position = Vector3(px, -0.45, 0)
				bridge_root.add_child(floor_beam)

			# Diagonal X-Bracing between adjacent posts
			if p_idx < post_count:
				var next_px = px + post_spacing
				var mid_x = (px + next_px) * 0.5
				var brace_len = sqrt(post_spacing * post_spacing + 0.65 * 0.65)
				var brace_angle = rad_to_deg(atan2(0.65, post_spacing))

				var b1 := MeshInstance3D.new()
				b1.name = "XBrace1_" + rail_side_name + "_%d" % p_idx
				var bm1 := BoxMesh.new()
				bm1.size = Vector3(brace_len, 0.14, 0.14)
				b1.mesh = bm1
				b1.material_override = timber_mat
				b1.position = Vector3(mid_x, 1.15, rz)
				b1.rotation_degrees = Vector3(0, 0, brace_angle)
				bridge_root.add_child(b1)

				var b2 := MeshInstance3D.new()
				b2.name = "XBrace2_" + rail_side_name + "_%d" % p_idx
				var bm2 := BoxMesh.new()
				bm2.size = Vector3(brace_len, 0.14, 0.14)
				b2.mesh = bm2
				b2.material_override = timber_mat
				b2.position = Vector3(mid_x, 1.15, rz)
				b2.rotation_degrees = Vector3(0, 0, -brace_angle)
				bridge_root.add_child(b2)

	# 7. Creek Bed Heavy Timber Trestle Bents with Stone Cutwaters
	for x_bent in [-10.0, 10.0]:
		var bent_root := Node3D.new()
		bent_root.name = "TrestleBent_%d" % int(x_bent)
		bent_root.position = Vector3(x_bent, 0, 0)

		# Stone Pier Base / Cutwater in creek bed
		var stone_pier := StaticBody3D.new()
		stone_pier.name = "StonePier"
		stone_pier.position = Vector3(0, -4.5, 0)
		var sp_col := CollisionShape3D.new()
		var sp_shape := BoxShape3D.new()
		sp_shape.size = Vector3(3.2, 5.0, width - 2.0)
		sp_col.shape = sp_shape
		stone_pier.add_child(sp_col)

		var sp_mesh := MeshInstance3D.new()
		var spm := BoxMesh.new()
		spm.size = sp_shape.size
		sp_mesh.mesh = spm
		sp_mesh.material_override = stone_mat
		stone_pier.add_child(sp_mesh)
		bent_root.add_child(stone_pier)

		# 4 Battered Timber Piles
		for pile_idx in range(4):
			var pile_z = - (width - 4.0) * 0.5 + pile_idx * ((width - 4.0) / 3.0)
			var pile := MeshInstance3D.new()
			pile.name = "Pile_%d" % pile_idx
			var pm := BoxMesh.new()
			pm.size = Vector3(0.55, 3.2, 0.55)
			pile.mesh = pm
			pile.material_override = timber_mat
			pile.position = Vector3(0, -1.2, pile_z)
			bent_root.add_child(pile)

		# Transverse Cap Beam
		var cap_beam := MeshInstance3D.new()
		cap_beam.name = "CapBeam"
		var cbm := BoxMesh.new()
		cbm.size = Vector3(1.2, 0.65, width - 1.0)
		cap_beam.mesh = cbm
		cap_beam.material_override = timber_mat
		cap_beam.position = Vector3(0, -0.65, 0)
		bent_root.add_child(cap_beam)

		bridge_root.add_child(bent_root)

	parent.add_child(bridge_root)


func _build_cobblestone_road(parent: Node, curve: Curve3D, width: float, node_name: String) -> void:
	var baked = curve.get_baked_points()
	if baked.size() < 2:
		return

	var total_len: float = curve.get_baked_length()
	var half_w: float = width * 0.5
	var curb_w: float = 0.5
	var max_curb_h: float = 0.22
	var deck_crown: float = 0.08
	var max_wall_drop: float = 3.8

	# 1. Cobblestone Road Deck Material (High-res PBR cobblestone)
	var cobble_mat := StandardMaterial3D.new()
	var cobble_tex: Texture2D = load("res://materials/cobblestone.png") as Texture2D
	var cobble_norm: Texture2D = load("res://materials/cobblestone_normal.png") as Texture2D
	var cobble_rough: Texture2D = load("res://materials/cobblestone_roughness.png") as Texture2D
	if cobble_tex:
		cobble_mat.albedo_texture = cobble_tex
	if cobble_norm:
		cobble_mat.normal_enabled = true
		cobble_mat.normal_texture = cobble_norm
		cobble_mat.normal_scale = 1.0
	if cobble_rough:
		cobble_mat.roughness_texture = cobble_rough
	cobble_mat.roughness = 0.85
	cobble_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# 2. Retaining Wall / Embankment Material (Alpine dark canyon rock)
	var wall_mat := StandardMaterial3D.new()
	var rock_tex: Texture2D = load("res://materials/dark_canyon_rock.png") as Texture2D
	var rock_norm: Texture2D = load("res://materials/dark_canyon_rock_normal.png") as Texture2D
	if rock_tex:
		wall_mat.albedo_texture = rock_tex
	if rock_norm:
		wall_mat.normal_enabled = true
		wall_mat.normal_texture = rock_norm
		wall_mat.normal_scale = 0.85
	wall_mat.roughness = 0.90
	wall_mat.uv1_scale = Vector3(0.25, 0.25, 0.25)
	wall_mat.uv1_triplanar = true
	wall_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var st_deck := SurfaceTool.new()
	st_deck.begin(Mesh.PRIMITIVE_TRIANGLES)

	var st_wall := SurfaceTool.new()
	st_wall.begin(Mesh.PRIMITIVE_TRIANGLES)

	var cum_dist: float = 0.0
	const DECK_VERTS := 7

	for i in range(baked.size()):
		var p = baked[i]
		var fwd = Vector3.FORWARD
		if i < baked.size() - 1:
			fwd = (baked[i + 1] - p).normalized()
		elif i > 0:
			fwd = (p - baked[i - 1]).normalized()

		var right = Vector3(-fwd.z, 0, fwd.x).normalized()
		var up = Vector3.UP

		if i > 0:
			cum_dist += p.distance_to(baked[i - 1])

		# Taper curbs and embankment smoothly at junctions with main track (first and last 8 meters)
		var taper_in: float = clampf(cum_dist / 8.0, 0.0, 1.0)
		var taper_out: float = clampf((total_len - cum_dist) / 8.0, 0.0, 1.0)
		var taper: float = minf(taper_in, taper_out)

		# Quadratic ease-in so at the junction it is completely flat (0.0 curb, 0.0 drop)
		var curb_h: float = max_curb_h * (taper * taper)
		var wall_drop: float = max_wall_drop * (taper * taper)

		var uv_y: float = cum_dist * 0.40

		# --- DECK MESH VERTICES (7 points across road) ---
		# 0: Left Curb Outer Lip
		st_deck.set_uv(Vector2(0.0, uv_y))
		st_deck.add_vertex(p - right * half_w + up * (0.05 + curb_h))
		# 1: Left Curb Inner Lip
		st_deck.set_uv(Vector2(0.3, uv_y))
		st_deck.add_vertex(p - right * (half_w - curb_w) + up * (0.05 + curb_h))
		# 2: Left Deck Gutter
		st_deck.set_uv(Vector2(0.4, uv_y))
		st_deck.add_vertex(p - right * (half_w - curb_w) + up * 0.05)
		# 3: Center Deck Crown
		st_deck.set_uv(Vector2(2.5, uv_y))
		st_deck.add_vertex(p + up * (0.05 + deck_crown * taper))
		# 4: Right Deck Gutter
		st_deck.set_uv(Vector2(4.6, uv_y))
		st_deck.add_vertex(p + right * (half_w - curb_w) + up * 0.05)
		# 5: Right Curb Inner Lip
		st_deck.set_uv(Vector2(4.7, uv_y))
		st_deck.add_vertex(p + right * (half_w - curb_w) + up * (0.05 + curb_h))
		# 6: Right Curb Outer Lip
		st_deck.set_uv(Vector2(5.0, uv_y))
		st_deck.add_vertex(p + right * half_w + up * (0.05 + curb_h))

		# --- WALL MESH VERTICES (4 points: left base/top, right top/base) ---
		var wall_uv_y: float = cum_dist * 0.25
		# 0: Left Embankment Base
		st_wall.set_uv(Vector2(0.0, wall_uv_y))
		st_wall.add_vertex(p - right * (half_w + 0.35 * taper) - up * wall_drop)
		# 1: Left Embankment Top
		st_wall.set_uv(Vector2(1.0, wall_uv_y))
		st_wall.add_vertex(p - right * half_w + up * (0.05 + curb_h))
		# 2: Right Embankment Top
		st_wall.set_uv(Vector2(1.0, wall_uv_y))
		st_wall.add_vertex(p + right * half_w + up * (0.05 + curb_h))
		# 3: Right Embankment Base
		st_wall.set_uv(Vector2(0.0, wall_uv_y))
		st_wall.add_vertex(p + right * (half_w + 0.35 * taper) - up * wall_drop)

	# Connect Deck Quads
	for i in range(baked.size() - 1):
		var r0 = i * DECK_VERTS
		var r1 = (i + 1) * DECK_VERTS
		for c in range(DECK_VERTS - 1):
			var a = r0 + c
			var b = r0 + c + 1
			var c_idx = r1 + c
			var d = r1 + c + 1
			st_deck.add_index(a); st_deck.add_index(c_idx); st_deck.add_index(b)
			st_deck.add_index(b); st_deck.add_index(c_idx); st_deck.add_index(d)

	# Connect Left and Right Walls
	for i in range(baked.size() - 1):
		var w0 = i * 4
		var w1 = (i + 1) * 4
		# Left Wall
		var lb0 = w0 + 0; var lt0 = w0 + 1
		var lb1 = w1 + 0; var lt1 = w1 + 1
		st_wall.add_index(lb0); st_wall.add_index(lt0); st_wall.add_index(lb1)
		st_wall.add_index(lt0); st_wall.add_index(lt1); st_wall.add_index(lb1)
		# Right Wall
		var rt0 = w0 + 2; var rb0 = w0 + 3
		var rt1 = w1 + 2; var rb1 = w1 + 3
		st_wall.add_index(rt0); st_wall.add_index(rb0); st_wall.add_index(rt1)
		st_wall.add_index(rb0); st_wall.add_index(rb1); st_wall.add_index(rt1)

	st_deck.generate_normals()
	st_deck.generate_tangents()
	var deck_mesh: ArrayMesh = st_deck.commit()

	st_wall.generate_normals()
	st_wall.generate_tangents()
	var wall_mesh: ArrayMesh = st_wall.commit()

	var static_body := StaticBody3D.new()
	static_body.name = node_name + "_Collision"
	static_body.add_to_group("track_surface", true)

	var deck_inst := MeshInstance3D.new()
	deck_inst.name = node_name + "_Deck"
	deck_inst.mesh = deck_mesh
	deck_inst.material_override = cobble_mat
	static_body.add_child(deck_inst)

	var wall_inst := MeshInstance3D.new()
	wall_inst.name = node_name + "_Embankment"
	wall_inst.mesh = wall_mesh
	wall_inst.material_override = wall_mat
	static_body.add_child(wall_inst)

	var col_shape := CollisionShape3D.new()
	col_shape.name = "CollisionShape3D"
	var r_trimesh = deck_mesh.create_trimesh_shape()
	if r_trimesh is ConcavePolygonShape3D:
		(r_trimesh as ConcavePolygonShape3D).backface_collision = true
	col_shape.shape = r_trimesh
	static_body.add_child(col_shape)

	var col_wall_shape := CollisionShape3D.new()
	col_wall_shape.name = "CollisionShape3D_Embankment"
	var r_wall_trimesh = wall_mesh.create_trimesh_shape()
	if r_wall_trimesh is ConcavePolygonShape3D:
		(r_wall_trimesh as ConcavePolygonShape3D).backface_collision = true
	col_wall_shape.shape = r_wall_trimesh
	static_body.add_child(col_wall_shape)

	parent.add_child(static_body)


func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	if node != scene_root:
		node.owner = scene_root
	for child in node.get_children():
		if child.owner != null and child.owner != scene_root:
			continue
		_set_owner_recursive(child, scene_root)
