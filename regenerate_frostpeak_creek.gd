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
	tg.set("road_width", 14.0)
	tg.set("sand_width", 18.0)
	tg.set("road_y_offset", 0.06)
	tg.set("curb_y_offset", 0.06)
	tg.set("terrain_recession_collision", 0.12)
	tg.set("terrain_recession_visual", 0.18)
	tg.set("no_water", false)
	tg.set("no_grass", true)
	tg.set("terrain_grass_count", 0)

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

	# Alternative shortcut branch: splits at (56, 8.5, -175), plunges through inner snow ravine, merges at (48, 6.0, -280)
	var alt_pts = [
		[Vector3(0, 0, 10), Vector3(-4, -0.4, -12), Vector3(56.0, 8.5, -175.0)],   # 0: Fork start
		[Vector3(4, 0.4, 12), Vector3(-2, -0.3, -14), Vector3(44.0, 7.2, -210.0)], # 1: Inner canyon descent
		[Vector3(2, 0.2, 12), Vector3(2, -0.2, -12), Vector3(38.0, 6.2, -245.0)],  # 2: Mid shortcut (Snowdrift zone)
		[Vector3(-2, -0.2, 10), Vector3(2, 0.2, -10), Vector3(48.0, 6.0, -280.0)], # 3: Merge rejoin
	]
	for p in alt_pts:
		alt_curve.add_point(p[2], p[0], p[1])
	alt_path.curve = alt_curve
	alt_container.add_child(alt_path)

	# Generate 3D road mesh & collision for the alternative route
	_build_ribbon_road(level_scene, alt_curve, 12.0, "AlternativeRoad_Mesh", asphalt_tex)

	# 5. Alpine Timber Bridge across Creek (Crossing 2: X = -24m to +24m at Z = -305, Y = 4.8m)
	_build_alpine_bridge(level_scene, Vector3(0.0, 4.8, -305.0), 48.0, 14.0)

	# 6. Snow-Covered Sections on the Road (Meshes with group "snow" & meta "is_snow")
	var snow_sections := Node3D.new()
	snow_sections.name = "SnowCoveredRoadSections"
	level_scene.add_child(snow_sections)

	# Section A: Pre-Jump 1 In-run Snowdrift (X=-32, Y=5.8, Z=-52)
	_create_snow_drift(snow_sections, "SnowDrift_Jump1Approach", Vector3(-32.0, 5.85, -52.0), Vector3(14.0, 0.35, 18.0), 20.0)
	# Section B: Eastern Flank Glade (X=45, Y=6.8, Z=-145)
	_create_snow_drift(snow_sections, "SnowDrift_EastGlade", Vector3(45.0, 6.85, -145.0), Vector3(14.0, 0.30, 16.0), -16.0)
	# Section C: Deep Snow on Alternative Shortcut Route (X=38, Y=6.3, Z=-245)
	_create_snow_drift(snow_sections, "SnowDrift_AltRouteCut", Vector3(38.0, 6.35, -245.0), Vector3(12.5, 0.38, 22.0), 5.0)
	# Section D: High Summit Ridge Snowdrift (X=-98, Y=17.6, Z=-80)
	_create_snow_drift(snow_sections, "SnowDrift_SummitRidge", Vector3(-98.0, 17.65, -80.0), Vector3(14.0, 0.32, 20.0), 0.0)
	# Section E: Pre-Jump 2 Summit Snowdrift (X=-45, Y=15.6, Z=100)
	_create_snow_drift(snow_sections, "SnowDrift_Jump2Approach", Vector3(-45.0, 15.65, 100.0), Vector3(14.0, 0.34, 16.0), -35.0)

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

	# 10. Checkpoints Container (Evenly spaced, clean sequential ordering)
	var checkpoints_container := Node3D.new()
	checkpoints_container.name = "Checkpoints"
	level_scene.add_child(checkpoints_container)

	# Sequential checkpoints placed cleanly along the racing line with generous spacing:
	# Checkpoint 5 is right before the fork, Checkpoint 6 is right after the merge!
	var cp_definitions = [
		Vector3(-45.0, 1.2, 50.0),    # CP 1: Mid valley straight
		Vector3(-45.0, 2.0, -10.0),   # CP 2: Approach to Turn 1
		Vector3(-35.0, 5.5, -50.0),   # CP 3: Jump 1 takeoff approach
		Vector3(26.0, 4.5, -112.0),   # CP 4: Jump 1 landing terrace
		Vector3(56.0, 8.5, -175.0),   # CP 5: RIGHT BEFORE FORK
		Vector3(48.0, 6.0, -280.0),   # CP 6: RIGHT AFTER MERGE
		Vector3(-24.0, 4.8, -305.0),  # CP 7: Exit of Alpine Bridge
		Vector3(-82.0, 11.5, -260.0), # CP 8: West mountain ridge climb
		Vector3(-98.0, 17.5, -80.0),  # CP 9: High summit overlook
		Vector3(-92.0, 17.0, 10.0),   # CP 10: High ridge south traverse
		Vector3(-22.0, 15.5, 125.0),  # CP 11: Jump 2 takeoff lip
		Vector3(30.0, 5.5, 168.0),    # CP 12: Jump 2 landing terrace
		Vector3(5.0, 2.2, 245.0),     # CP 13: South meadow apex
		Vector3(-45.0, 0.9, 180.0),   # CP 14: Final home straight entry
	]

	for i in range(cp_definitions.size()):
		var p = cp_definitions[i]
		var next_p = cp_definitions[(i + 1) % cp_definitions.size()] if i < cp_definitions.size() - 1 else finish_line.position
		var forward = (next_p - p).normalized()
		var rot_y = rad_to_deg(atan2(-forward.x, -forward.z))

		var gate = gate_scene.instantiate()
		gate.name = "Checkpoint_%d" % (i + 1)
		gate.position = p + Vector3(0, 0.1, 0)
		gate.rotation_degrees = Vector3(0, rot_y, 0)
		checkpoints_container.add_child(gate)

	# 11. Jump Launch Ramps (Crossing 1 and Crossing 3)
	var ramp_container := Node3D.new()
	ramp_container.name = "JumpRamps"
	level_scene.add_child(ramp_container)

	var ramp_scene: PackedScene = load("res://models/ramps/ramp.glb")
	if not ramp_scene:
		ramp_scene = load("res://models/ramps/woodramp.fbx")

	# Jump 1 (West to East Creek Leap): (-16.0, 8.56, -72.0), launches North-East (314 deg)
	# Jump 2 (West to East Creek Super-Leap): (-22.0, 15.56, 125.0), launches South-East (220 deg)
	var ramp_placements = [
		[Vector3(-16.0, 8.56, -72.0), Vector3(0, 314.0, 0), Vector3(2.8, 2.4, 2.8)],
		[Vector3(-22.0, 15.56, 125.0), Vector3(0, 220.0, 0), Vector3(3.0, 2.6, 3.0)]
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

	# 14. Alpine Winter Pines & Snowy Boulders
	var veg_container := Node3D.new()
	veg_container.name = "Vegetation"
	level_scene.add_child(veg_container)

	var pine_models = [
		load("res://models/trees/pine.glb"),
		load("res://models/trees/pine_2.glb")
	]

	var rng = RandomNumberGenerator.new()
	rng.seed = 112233

	var baked_pts: PackedVector3Array = curve.get_baked_points()
	var get_2d_road_dist = func(px: float, pz: float) -> float:
		var min_d := 1.0e9
		for bp in baked_pts:
			var d = Vector2(px - bp.x, pz - bp.z).length()
			if d < min_d:
				min_d = d
		return min_d

	var get_ground_y = func(px: float, pz: float) -> float:
		return float(tg.call("_sample_cached_height", px, pz))

	# Jump flight corridors to strictly keep clear of trees
	var jump_segments = [
		[Vector2(-16.0, -72.0), Vector2(26.0, -112.0), 28.0], # Jump 1 corridor
		[Vector2(-22.0, 125.0), Vector2(30.0, 168.0), 28.0],  # Jump 2 corridor
		[Vector2(24.0, -305.0), Vector2(-24.0, -305.0), 24.0] # Bridge corridor
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

	var tree_count := 0
	var tree_attempts := 0
	while tree_count < 150 and tree_attempts < 700:
		tree_attempts += 1
		var px = rng.randf_range(-340.0, 340.0)
		var pz = rng.randf_range(-300.0, 300.0)

		# Road clearance: minimum 18m from road
		if get_2d_road_dist.call(px, pz) < 18.0:
			continue
		if is_in_jump_corridor.call(px, pz):
			continue

		var py = get_ground_y.call(px, pz)
		# Skip creek gorge floor (keep creek clear)
		if py < -1.0:
			continue

		var chosen_packed = pine_models[rng.randi() % pine_models.size()]
		if chosen_packed:
			var tree_inst = chosen_packed.instantiate()
			tree_count += 1
			tree_inst.name = "Pine_%d" % tree_count
			tree_inst.position = Vector3(px, py - 0.25, pz)
			var sc = rng.randf_range(1.4, 2.5)
			tree_inst.scale = Vector3(sc, sc, sc)
			tree_inst.rotation_degrees = Vector3(0, rng.randf_range(0, 360), 0)
			veg_container.add_child(tree_inst)

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


func _create_snow_drift(parent: Node, drift_name: String, pos: Vector3, size: Vector3, yaw_deg: float) -> void:
	var body := StaticBody3D.new()
	body.name = drift_name
	body.position = pos
	body.rotation_degrees = Vector3(0, yaw_deg, 0)
	body.add_to_group("snow", true)
	body.set_meta("is_snow", true)

	var cshape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	cshape.shape = box_shape
	body.add_child(cshape)

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = drift_name + "_Mesh"
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_inst.mesh = box_mesh

	var drift_mat := StandardMaterial3D.new()
	drift_mat.albedo_color = Color(0.96, 0.98, 1.0)
	drift_mat.roughness = 0.95
	mesh_inst.material_override = drift_mat

	body.add_child(mesh_inst)
	parent.add_child(body)


func _build_alpine_bridge(parent: Node, center: Vector3, length: float, width: float) -> void:
	var bridge_root := Node3D.new()
	bridge_root.name = "AlpineTimberBridge"
	bridge_root.position = center

	# Timber Deck
	var deck_body := StaticBody3D.new()
	deck_body.name = "BridgeDeck"
	deck_body.add_to_group("track_surface", true)
	var deck_col := CollisionShape3D.new()
	var deck_shape := BoxShape3D.new()
	deck_shape.size = Vector3(length, 0.6, width)
	deck_col.shape = deck_shape
	deck_body.add_child(deck_col)

	var deck_mesh := MeshInstance3D.new()
	deck_mesh.name = "BridgeDeck_Mesh"
	var box_m := BoxMesh.new()
	box_m.size = deck_shape.size
	deck_mesh.mesh = box_m

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.42, 0.28, 0.18)
	wood_mat.roughness = 0.85
	deck_mesh.material_override = wood_mat
	deck_body.add_child(deck_mesh)
	bridge_root.add_child(deck_body)

	# Side Guardrails (North and South edges)
	var rail_mat := StandardMaterial3D.new()
	rail_mat.albedo_color = Color(0.35, 0.22, 0.14)
	rail_mat.roughness = 0.9

	for side in [-1.0, 1.0]:
		var rail_body := StaticBody3D.new()
		rail_body.name = "Guardrail_" + ("N" if side < 0 else "S")
		var rail_z: float = side * (width * 0.5 - 0.4)
		rail_body.position = Vector3(0, 0.75, rail_z)

		var rail_col := CollisionShape3D.new()
		var rail_shape := BoxShape3D.new()
		rail_shape.size = Vector3(length, 1.2, 0.5)
		rail_col.shape = rail_shape
		rail_body.add_child(rail_col)

		var rail_mesh := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = rail_shape.size
		rail_mesh.mesh = rm
		rail_mesh.material_override = rail_mat
		rail_body.add_child(rail_mesh)
		bridge_root.add_child(rail_body)

	# Timber Support Piers rooted into creek bed
	for x_offset in [-14.0, 0.0, 14.0]:
		var pier := StaticBody3D.new()
		pier.name = "Pillar_%d" % int(x_offset)
		pier.position = Vector3(x_offset, -2.8, 0)
		var p_col := CollisionShape3D.new()
		var p_shape := BoxShape3D.new()
		p_shape.size = Vector3(2.4, 6.0, width - 2.0)
		p_col.shape = p_shape
		pier.add_child(p_col)

		var p_mesh := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = p_shape.size
		p_mesh.mesh = pm
		p_mesh.material_override = wood_mat
		pier.add_child(p_mesh)
		bridge_root.add_child(pier)

	parent.add_child(bridge_root)


func _build_ribbon_road(parent: Node, curve: Curve3D, width: float, node_name: String, asphalt_tex: Texture2D) -> void:
	var baked = curve.get_baked_points()
	if baked.size() < 2:
		return

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var road_mat := StandardMaterial3D.new()
	if asphalt_tex:
		road_mat.albedo_texture = asphalt_tex
	road_mat.albedo_color = Color(0.85, 0.88, 0.92)
	road_mat.roughness = 0.8
	road_mat.uv1_scale = Vector3(0.2, 0.2, 0.2)

	var half_w = width * 0.5
	var cum_dist: float = 0.0

	for i in range(baked.size()):
		var p = baked[i]
		var forward = Vector3.FORWARD
		if i < baked.size() - 1:
			forward = (baked[i + 1] - p).normalized()
		elif i > 0:
			forward = (p - baked[i - 1]).normalized()

		var right = Vector3(-forward.z, 0, forward.x).normalized()
		var up = Vector3.UP

		if i > 0:
			cum_dist += p.distance_to(baked[i - 1])

		var v_left = p - right * half_w + up * 0.06
		var v_right = p + right * half_w + up * 0.06

		st.set_normal(up)
		st.set_uv(Vector2(0.0, cum_dist * 0.1))
		st.add_vertex(v_left)

		st.set_normal(up)
		st.set_uv(Vector2(1.0, cum_dist * 0.1))
		st.add_vertex(v_right)

	for i in range(baked.size() - 1):
		var i0 = i * 2
		var i1 = i * 2 + 1
		var i2 = (i + 1) * 2
		var i3 = (i + 1) * 2 + 1

		st.add_index(i0)
		st.add_index(i2)
		st.add_index(i1)

		st.add_index(i1)
		st.add_index(i2)
		st.add_index(i3)

	st.generate_tangents()
	var arr_mesh = st.commit()

	var static_body := StaticBody3D.new()
	static_body.name = node_name + "_Collision"
	static_body.add_to_group("track_surface", true)

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = node_name
	mesh_inst.mesh = arr_mesh
	mesh_inst.material_override = road_mat
	static_body.add_child(mesh_inst)

	var col_shape := CollisionShape3D.new()
	col_shape.shape = arr_mesh.create_trimesh_shape()
	static_body.add_child(col_shape)

	parent.add_child(static_body)


func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	if node != scene_root:
		node.owner = scene_root
	for child in node.get_children():
		if child.owner != null and child.owner != scene_root:
			continue
		_set_owner_recursive(child, scene_root)
