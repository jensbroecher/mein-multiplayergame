# regenerate_glacier_highway.gd
# Generates levels/GlacierHighwayLevel.tscn for the Arctic Cup:
# - Longer track (~2150m circuit)
# - Concrete highway design with PBR concrete road deck, highway lane striping shader
# - Continuous concrete Jersey side barriers along all roads, ramps, and viaducts
# - 3 Multi-divergence zones with on- and off-ramps (Express Flyover, Gorge Service Cut, Twin Overpass)
# - Track self-intersection: cars go through an illuminated mountain tunnel directly underneath the elevated highway overpass
# - Checkpoint sequence, starting grid, boost pads, item boxes, and highway infrastructure
extends Node

func _ready() -> void:
	print("=== Glacier Highway Grand Prix Level Generation ===")
	print("Building multi-tier arctic concrete expressway with tunnel underpass and ramps...")

	var level_scene := Node3D.new()
	level_scene.name = "GlacierHighwayLevel"

	var level_script: Script = load("res://levels/Level.gd")
	level_scene.set_script(level_script)

	# 0. Core Nodes (must exist before entering tree for @onready variables)
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

	# 1. Environment & Lighting (Crisp High-Arctic Atmosphere)
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.48, 0.88)
	sky_mat.sky_horizon_color = Color(0.70, 0.82, 0.94)
	sky_mat.ground_bottom_color = Color(0.86, 0.91, 0.97)
	sky_mat.ground_horizon_color = Color(0.76, 0.86, 0.95)
	sky_mat.sun_angle_max = 30.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.55
	env.ambient_light_color = Color(0.85, 0.92, 1.0)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.22
	env.glow_bloom = 0.10
	env_node.environment = env
	level_scene.add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = Vector3(-42.0, 38.0, 0.0)
	sun.light_color = Color(1.0, 0.96, 0.91)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 550.0
	sun.directional_shadow_split_1 = 0.10
	sun.directional_shadow_split_2 = 0.25
	sun.directional_shadow_split_3 = 0.55
	level_scene.add_child(sun)

	# Ambient Winter Wind Audio
	var wind_stream = load("res://sounds/dragon-studio-winter-wind-402331.mp3")
	if wind_stream:
		var wind_player := AudioStreamPlayer.new()
		wind_player.name = "WinterWindAudio"
		wind_player.stream = wind_stream
		wind_player.volume_db = -11.0
		wind_player.autoplay = true
		level_scene.add_child(wind_player)

	# Falling Snow Particles
	var snow_particles := GPUParticles3D.new()
	snow_particles.name = "FallingSnow"
	var falling_snow_script = load("res://FallingSnow.gd")
	if falling_snow_script:
		snow_particles.set_script(falling_snow_script)
	snow_particles.amount = 2600
	snow_particles.lifetime = 3.5
	snow_particles.speed_scale = 0.55
	snow_particles.randomness = 0.8
	snow_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	snow_particles.visibility_aabb = AABB(Vector3(-60, -40, -60), Vector3(120, 60, 120))

	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(45.0, 1.0, 45.0)
	pmat.direction = Vector3(0.25, -1.0, 0.15)
	pmat.spread = 16.0
	pmat.initial_velocity_min = 2.0
	pmat.initial_velocity_max = 6.5
	pmat.gravity = Vector3(0, -3.2, 0)
	pmat.scale_min = 0.7
	pmat.scale_max = 1.3
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

	# 2. Main TrackPath & Curve3D (~2150m closed circuit)
	# Clockwise circuit:
	# - Starts on South glacier floor (X=-65, Y=2.8, Z=180) heading North
	# - Divergence 1: Approaches on-ramp to Express Viaduct Flyover
	# - Tunnel Underpass: Crosses through mountain tunnel (Z=-170 to Z=-240, Y=2.8)
	# - Divergence 2: Gorge cut off-ramp splits left into glacier bed
	# - Alpine Summit Climb: Sweeps around eastern mountain flank (Y up to 16.5m)
	# - Overpass Viaduct: Crosses high overhead at Z=-205m directly above the tunnel underpass!
	# - Divergence 3: Twin Viaduct split descending west mountain ridge
	# - Sweeps south across glacier valley and straightens smoothly into Finish Line
	var track_path := Path3D.new()
	track_path.name = "TrackPath"
	var curve := Curve3D.new()
	curve.bake_interval = 0.25

	var curve_pts = [
		# --- SECTION 0: START / FINISH STRAIGHT (Heading North, Y = 2.8m) ---
		[Vector3(0, 0, 45), Vector3(0, 0, -45), Vector3(-85.0, 2.8, 280.0)],    # 0 Finish Line
		[Vector3(0, 0, 40), Vector3(0, 0, -40), Vector3(-85.0, 2.8, 160.0)],    # 1 South straight
		[Vector3(0, 0, 35), Vector3(2, 0, -35), Vector3(-82.0, 2.8, 30.0)],     # 2 Pre-Divergence 1 (Express On-Ramp)

		# --- SECTION 1: VALLEY MEANDER & MERGE ---
		[Vector3(-12, 0, 35), Vector3(12, 0, -35), Vector3(-55.0, 2.8, -50.0)], # 3 Lower glacier curve
		[Vector3(-10, 0, 25), Vector3(5, 0, -25), Vector3(-18.0, 2.8, -115.0)], # 4 Post-Divergence 1 Rejoin
		[Vector3(0, 0, 20), Vector3(0, 0, -20), Vector3(0.0, 2.8, -150.0)],    # 5 Tunnel Approach Straight (Aligning to X = 0)

		# --- SECTION 2: THE TUNNEL UNDERPASS (Crossing Directly Under High Overpass at Z = -180m) ---
		[Vector3(0, 0, 15), Vector3(0, 0, -15), Vector3(0.0, 2.8, -180.0)],    # 6 Tunnel Entrance Portal & Crossover Apex (Z = -180, Y = 2.8)
		[Vector3(0, 0, 15), Vector3(0, 0, -15), Vector3(0.0, 2.8, -210.0)],    # 7 Tunnel Underpass Midpoint (Z = -210, Y = 2.8)
		[Vector3(0, 0, 15), Vector3(0, 0, -15), Vector3(0.0, 2.8, -240.0)],    # 8 Tunnel Exit Portal (Z = -240, Y = 2.8)
		[Vector3(0, 0, 15), Vector3(0, 0, -25), Vector3(0.0, 2.8, -270.0)],    # 9 North Basin Runout Straight

		# --- SECTION 3: NORTH GLACIER BASIN & DIVERGENCE 2 ---
		[Vector3(-10, -0.2, 20), Vector3(12, 0.4, -25), Vector3(30.0, 3.8, -320.0)], # 10 Pre-Divergence 2 (Gorge Cut Off-Ramp)
		[Vector3(-18, -0.4, 20), Vector3(22, 0.6, -20), Vector3(80.0, 5.8, -370.0)], # 11 North Rim broad curve
		[Vector3(-22, -0.6, 12), Vector3(20, 0.8, -12), Vector3(140.0, 8.5, -370.0)],# 12 Post-Divergence 2 Rejoin

		# --- SECTION 4: ALPINE EAST FLANK CLIMB ---
		[Vector3(-20, -0.8, -16), Vector3(18, 0.8, 16), Vector3(195.0, 12.0, -320.0)],# 13 East flank climb
		[Vector3(-6, -0.8, -25), Vector3(6, 0.8, 25), Vector3(210.0, 15.0, -240.0)],  # 14 Eastern summit traverse
		[Vector3(0, 0, -25), Vector3(0, 0, 25), Vector3(180.0, 16.5, -180.0)],        # 15 Summit vista bend
		[Vector3(25, 0, 0), Vector3(-25, 0, 0), Vector3(135.0, 16.5, -180.0)],        # 16 East Overpass Approach Straight

		# --- SECTION 5: THE HIGH OVERPASS VIADUCT (Soaring Directly Across Z = -180m Over Lower Highway!) ---
		[Vector3(20, 0, 0), Vector3(-20, 0, 0), Vector3(70.0, 16.5, -180.0)],   # 17 High East viaduct span
		[Vector3(20, 0, 0), Vector3(-20, 0, 0), Vector3(0.0, 16.5, -180.0)],    # 18 OVERPASS CROSSING APEX (Z = -180, Y = 16.5m directly above Pt 6!)
		[Vector3(20, 0, 0), Vector3(-20, 0, 0), Vector3(-70.0, 16.5, -180.0)],  # 19 High West viaduct span / Pre-Divergence 3
		[Vector3(25, 0, 15), Vector3(-25, 0, -15), Vector3(-130.0, 16.5, -160.0)],# 20 West Overpass Abutment

		# --- SECTION 6: WEST RIDGE DESCENT & DIVERGENCE 3 REJOIN ---
		[Vector3(12, 0.8, -24), Vector3(-12, -0.8, 24), Vector3(-155.0, 13.0, -100.0)],# 21 Mountain viaduct descent
		[Vector3(6, 0.8, -26), Vector3(-6, -0.8, 26), Vector3(-160.0, 9.0, -20.0)],   # 22 Outer shelf sweep
		[Vector3(-4, 0.8, -25), Vector3(4, -0.6, 25), Vector3(-145.0, 5.5, 60.0)],   # 23 Post-Divergence 3 Rejoin
		[Vector3(-8, 0.6, -22), Vector3(8, -0.2, 24), Vector3(-120.0, 3.8, 140.0)],  # 24 Valley landing

		# --- SECTION 7: SOUTH GLACIER SWEEPER & HOME STRAIGHT ---
		[Vector3(-6, 0.2, -25), Vector3(6, 0.0, 25), Vector3(-110.0, 2.8, 220.0)],  # 25 South sweeper
		[Vector3(-16, 0, -10), Vector3(16, 0, 10), Vector3(-95.0, 2.8, 330.0)],    # 26 Turnaround loop
		[Vector3(-15, 0, 12), Vector3(15, 0, -12), Vector3(-70.0, 2.8, 350.0)],    # 27 Loop apex
		[Vector3(-4, 0, 25), Vector3(4, 0, -25), Vector3(-65.0, 2.8, 320.0)],     # 28 Aligning into home straight
		[Vector3(0, 0, 45), Vector3(0, 0, -45), Vector3(-85.0, 2.8, 280.0)],      # 29 Closed back to start
	]

	for pt in curve_pts:
		curve.add_point(pt[2], pt[0], pt[1])

	track_path.curve = curve
	level_scene.add_child(track_path)

	# 3. Terrain & Mountains
	var terrain_container := Node3D.new()
	terrain_container.name = "TerrainEnvironment"
	level_scene.add_child(terrain_container)
	_build_arctic_mountain_landscape(terrain_container)

	# 4. Materials setup
	var concrete_tex: Texture2D = load("res://materials/concrete.png") as Texture2D
	var concrete_norm: Texture2D = load("res://materials/concrete_normal.png") as Texture2D
	var concrete_rough: Texture2D = load("res://materials/concrete_roughness.png") as Texture2D

	var highway_shader = load("res://concrete_highway.gdshader")
	var highway_mat := ShaderMaterial.new()
	highway_mat.shader = highway_shader
	if concrete_tex:
		highway_mat.set_shader_parameter("concrete_texture", concrete_tex)
	if concrete_norm:
		highway_mat.set_shader_parameter("concrete_normal", concrete_norm)
	if concrete_rough:
		highway_mat.set_shader_parameter("concrete_roughness", concrete_rough)
	highway_mat.set_shader_parameter("concrete_color", Color(0.88, 0.90, 0.93))
	highway_mat.set_shader_parameter("stripe_color", Color(0.97, 0.98, 1.0))
	highway_mat.set_shader_parameter("uv_scale", 0.22)

	var barrier_mat := StandardMaterial3D.new()
	if concrete_tex:
		barrier_mat.albedo_texture = concrete_tex
	if concrete_norm:
		barrier_mat.normal_enabled = true
		barrier_mat.normal_texture = concrete_norm
		barrier_mat.normal_scale = 0.8
	if concrete_rough:
		barrier_mat.roughness_texture = concrete_rough
	barrier_mat.albedo_color = Color(0.80, 0.82, 0.85)
	barrier_mat.roughness = 0.88
	barrier_mat.uv1_scale = Vector3(0.3, 0.3, 0.3)
	barrier_mat.uv1_triplanar = true
	barrier_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var girder_mat := StandardMaterial3D.new()
	girder_mat.albedo_color = Color(0.38, 0.40, 0.44)
	girder_mat.roughness = 0.85
	girder_mat.uv1_scale = Vector3(0.2, 0.2, 0.2)
	girder_mat.uv1_triplanar = true
	girder_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# 5. Build Main Highway Road Mesh & Side Barriers (Full ~2000m circuit)
	# Barrier gap intervals where alternative routes split off and merge (40m openings with smooth tapers):
	var main_left_gaps = [
		Vector2(425.0, 472.0),   # Alt 1 Merge (Flyover off-ramp rejoins on left)
		Vector2(1240.0, 1288.0), # Alt 3 Split (Bypass on-ramp splits on left)
		Vector2(1542.0, 1590.0)  # Alt 3 Merge (Bypass off-ramp rejoins on left)
	]
	var main_right_gaps = [
		Vector2(232.0, 280.0),   # Alt 1 Split (Flyover on-ramp splits on right)
		Vector2(555.0, 602.0),   # Alt 2 Split (Gorge Cut on-ramp splits on right)
		Vector2(742.0, 790.0)    # Alt 2 Merge (Gorge Cut off-ramp rejoins on right)
	]
	_build_highway_road_mesh(level_scene, curve, 16.0, "MainHighway", highway_mat, barrier_mat, girder_mat, true, true, main_left_gaps, main_right_gaps)

	# Add glowing direction arrows at the splits to make alternative paths clear
	_add_junction_arrows(level_scene, curve, main_left_gaps, main_right_gaps)

	# 6. Build the Tunnel Underpass System (Z = -180m to Z = -240m, X = 0m, Y = 2.8m, Length = 60m)
	_build_tunnel_underpass(level_scene, Vector3(0, 2.8, -210.0), 60.0, 18.5, barrier_mat, girder_mat)

	# 7. Build Alternative Routes (Multiple Divergences with On- and Off-Ramps)
	var alt_container := Node3D.new()
	alt_container.name = "AlternativePaths"
	level_scene.add_child(alt_container)

	# --- DIVERGENCE 1: Summit Viaduct Express Flyover (On-Ramp -> Elevated Deck -> Off-Ramp) ---
	var alt1_path := Path3D.new()
	alt1_path.name = "AlternativePath_ViaductExpress"
	var alt1_curve := Curve3D.new()
	alt1_curve.bake_interval = 0.25
	var alt1_pts = [
		[Vector3(0, 0, 12), Vector3(6, 0.8, -20), Vector3(-78.0, 2.8, 25.0)],     # 0: On-ramp split
		[Vector3(-6, -0.8, 20), Vector3(6, 0.8, -22), Vector3(-58.0, 6.8, -25.0)], # 1: Incline ramp
		[Vector3(-8, -0.2, 22), Vector3(6, 0.0, -22), Vector3(-40.0, 9.8, -80.0)], # 2: High deck (+7.0m above main road)
		[Vector3(-6, 0.6, 20), Vector3(4, -0.8, -20), Vector3(-20.0, 6.2, -120.0)],# 3: Off-ramp descent
		[Vector3(-4, 0.8, 16), Vector3(0, 0, -12), Vector3(-4.0, 2.8, -148.0)]    # 4: Rejoining main road
	]
	for p in alt1_pts:
		alt1_curve.add_point(p[2], p[0], p[1])
	alt1_path.curve = alt1_curve
	alt_container.add_child(alt1_path)
	_build_highway_road_mesh(level_scene, alt1_curve, 11.5, "ExpressFlyoverRoad", highway_mat, barrier_mat, girder_mat, true, true)

	# --- DIVERGENCE 2: Glacier Gorge Service Cut (Off-Ramp -> Frozen Canyon -> On-Ramp) ---
	var alt2_path := Path3D.new()
	alt2_path.name = "AlternativePath_GorgeCut"
	var alt2_curve := Curve3D.new()
	alt2_curve.bake_interval = 0.25
	var alt2_pts = [
		[Vector3(0, 0, 12), Vector3(-6, -0.8, -18), Vector3(6.0, 2.8, -276.0)],   # 0: Off-ramp split
		[Vector3(8, 0.8, 18), Vector3(-4, -0.2, -20), Vector3(18.0, -1.5, -320.0)],# 1: Canyon descent
		[Vector3(-6, 0.0, 20), Vector3(14, 0.2, -18), Vector3(42.0, -2.0, -375.0)],# 2: Deep canyon floor (Ice cut)
		[Vector3(-18, -0.4, -6), Vector3(18, 0.8, 6), Vector3(95.0, 2.8, -390.0)], # 3: Ascending on-ramp
		[Vector3(-18, -0.8, 6), Vector3(12, 0.2, -6), Vector3(140.0, 8.5, -370.0)] # 4: Rejoining highway
	]
	for p in alt2_pts:
		alt2_curve.add_point(p[2], p[0], p[1])
	alt2_path.curve = alt2_curve
	alt_container.add_child(alt2_path)
	_build_highway_road_mesh(level_scene, alt2_curve, 11.5, "GorgeServiceRoad", highway_mat, barrier_mat, girder_mat, true, false)

	# --- DIVERGENCE 3: Twin Overpass Ridge Bypass (Outer Scenic Viaduct) ---
	var alt3_path := Path3D.new()
	alt3_path.name = "AlternativePath_RidgeBypass"
	var alt3_curve := Curve3D.new()
	alt3_curve.bake_interval = 0.25
	var alt3_pts = [
		[Vector3(12, 0, -4), Vector3(-14, 0.0, 8), Vector3(-75.0, 16.5, -180.0)],   # 0: Split start at Overpass
		[Vector3(14, 0.2, -15), Vector3(-10, -0.6, 20), Vector3(-130.0, 15.5, -135.0)],# 1: Outer ridge flyover
		[Vector3(8, 0.6, -22), Vector3(-6, -0.8, 22), Vector3(-160.0, 11.0, -50.0)],  # 2: Outer scenic sweep
		[Vector3(6, 0.8, -20), Vector3(-4, -0.6, 18), Vector3(-152.0, 7.5, 10.0)],   # 3: Descending ramp
		[Vector3(-4, 0.6, -15), Vector3(4, -0.2, 12), Vector3(-145.0, 5.5, 60.0)]    # 4: Rejoining highway
	]
	for p in alt3_pts:
		alt3_curve.add_point(p[2], p[0], p[1])
	alt3_path.curve = alt3_curve
	alt_container.add_child(alt3_path)
	_build_highway_road_mesh(level_scene, alt3_curve, 11.5, "RidgeBypassRoad", highway_mat, barrier_mat, girder_mat, true, true)

	# 8. Finish Line & Starting Grid
	var gate_scene: PackedScene = load("res://CheckpointGate.tscn")
	var spawn_scene: PackedScene = load("res://SpawnIndicator.tscn")

	var fl_pos := curve.sample_baked(2.0)
	var fl_next := curve.sample_baked(3.0)
	var fl_fwd := (fl_next - fl_pos).normalized()
	var fl_rot_y := rad_to_deg(atan2(-fl_fwd.x, -fl_fwd.z))

	var finish_line = gate_scene.instantiate()
	finish_line.name = "FinishLine"
	finish_line.position = fl_pos + Vector3(0, 0.06, 0)
	finish_line.rotation_degrees = Vector3(0, fl_rot_y, 0)
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

	# 9. Checkpoints Container (8 curve-aligned checkpoints on trunk sections + Finish Line)
	# NOTE: NO checkpoints inside the tunnel underpass per user specification!
	var checkpoints_container := Node3D.new()
	checkpoints_container.name = "Checkpoints"
	level_scene.add_child(checkpoints_container)

	var track_len: float = curve.get_baked_length()
	var target_cp_positions = [
		Vector3(-85.0, 2.8, 160.0),    # CP 1: South Straight
		Vector3(0.0, 2.8, -135.0),     # CP 2: Pre-Tunnel Highway Approach (45m before tunnel entrance)
		Vector3(0.0, 2.8, -270.0),     # CP 3: North Basin Runout (30m after tunnel exit - NO CP INSIDE TUNNEL)
		Vector3(80.0, 5.8, -370.0),    # CP 4: North Rim Curve
		Vector3(205.0, 13.5, -270.0),  # CP 5: High East Alpine Climb
		Vector3(0.0, 16.5, -180.0),    # CP 6: Overpass Viaduct Apex
		Vector3(-155.0, 11.0, -60.0),  # CP 7: West Ridge Shelf
		Vector3(-110.0, 2.8, 220.0)    # CP 8: South Sweeper before Home Straight
	]

	# Find exact baked distance for each checkpoint by closest sample along curve
	var sample_step := 1.0
	var sample_count := int(track_len / sample_step)
	var milestone_offsets = []
	for target in target_cp_positions:
		var best_dist: float = 0.0
		var best_d2: float = 1e9
		for s in range(sample_count):
			var d_eval: float = s * sample_step
			var pt_eval := curve.sample_baked(d_eval)
			var d2 = pt_eval.distance_squared_to(target)
			if d2 < best_d2:
				best_d2 = d2
				best_dist = d_eval
		milestone_offsets.append(best_dist)

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

	# 10. Boost Pads
	var boost_scene: PackedScene = load("res://BoostPad.tscn")
	var boost_container := Node3D.new()
	boost_container.name = "BoostPads"
	level_scene.add_child(boost_container)

	if boost_scene:
		var bp_defs = [
			# South Straight Launch Boosters
			["Boost_Start_L", Vector3(-87.5, 2.8, 160.0), 0.0],
			["Boost_Start_R", Vector3(-82.5, 2.8, 160.0), 0.0],
			# Express Flyover Boosters (Divergence 1 Reward)
			["Boost_Express_1", Vector3(-52.0, 7.5, -45.0), -22.0],
			["Boost_Express_2", Vector3(-38.0, 9.8, -90.0), -15.0],
			# Gorge Service Cut Incline Booster (Divergence 2)
			["Boost_Gorge_Launch", Vector3(50.0, -1.8, -365.0), 75.0],
			# High Overpass Viaduct Boosters (Section 5 Crossing)
			["Boost_Overpass_L", Vector3(5.0, 16.5, -178.0), -90.0],
			["Boost_Overpass_R", Vector3(5.0, 16.5, -182.0), -90.0],
			# West Ridge Descent Booster
			["Boost_RidgeDescent", Vector3(-155.0, 8.5, 0.0), 160.0]
		]
		for bp_info in bp_defs:
			var bp = boost_scene.instantiate()
			bp.name = bp_info[0]
			bp.position = bp_info[1]
			bp.rotation_degrees = Vector3(0, bp_info[2], 0)
			boost_container.add_child(bp)

	# 11. Item Boxes
	var item_scene: PackedScene = load("res://ItemBox.tscn")
	var item_container := Node3D.new()
	item_container.name = "ItemBoxes"
	level_scene.add_child(item_container)

	if item_scene:
		var item_rows = [
			# Row 1: South Straight (Z = 120m)
			[Vector3(-88.0, 3.4, 120.0), Vector3(-85.0, 3.4, 120.0), Vector3(-82.0, 3.4, 120.0)],
			# Row 2: Pre-Tunnel Highway (Z = -135m)
			[Vector3(-4.0, 3.4, -135.0), Vector3(0.0, 3.4, -135.0), Vector3(4.0, 3.4, -135.0)],
			# Row 3: Gorge Cut Secret Cache (Z = -365m)
			[Vector3(38.0, -1.3, -365.0), Vector3(42.0, -1.3, -365.0)],
			# Row 4: High East Ridge Vista (Z = -220m)
			[Vector3(208.0, 15.6, -220.0), Vector3(205.0, 15.6, -220.0), Vector3(202.0, 15.6, -220.0)],
			# Row 5: Valley Landing Sweeper (Z = 160m)
			[Vector3(-118.0, 3.8, 160.0), Vector3(-115.0, 3.8, 160.0), Vector3(-112.0, 3.8, 160.0)]
		]
		var item_idx := 1
		for row in item_rows:
			for pos in row:
				var ib = item_scene.instantiate()
				ib.name = "ItemBox_%d" % item_idx
				ib.position = pos
				item_container.add_child(ib)
				item_idx += 1

	# 12. Highway Overhead Gantries & Streetlights
	var props_container := Node3D.new()
	props_container.name = "HighwayProps"
	level_scene.add_child(props_container)
	_build_highway_gantries(props_container)
	_build_highway_streetlights(props_container, curve)

	# 15. Setup Checkpoints & Level wiring
	level_scene.set("track_path", track_path)
	level_scene._setup_checkpoints()

	# 16. Scene Ownership
	_set_owner_recursive(level_scene, level_scene)

	# 17. Save Packed Scene
	remove_child(level_scene)
	var target_path := "res://levels/GlacierHighwayLevel.tscn"
	var packed_scene := PackedScene.new()
	var pack_err = packed_scene.pack(level_scene)
	if pack_err != OK:
		push_error("Failed to pack GlacierHighwayLevel.tscn: %d" % pack_err)
		get_tree().quit(1)
		return

	var save_err = ResourceSaver.save(packed_scene, target_path)
	if save_err != OK:
		push_error("Failed to save GlacierHighwayLevel.tscn: %d" % save_err)
		get_tree().quit(1)
		return

	print("Successfully generated and saved res://levels/GlacierHighwayLevel.tscn!")
	get_tree().quit(0)


## Builds the 3D concrete highway road mesh, Jersey crash barriers, and viaduct piers along a Curve3D.
func _build_highway_road_mesh(parent: Node, curve: Curve3D, width: float, node_name: String, road_mat: Material, barrier_mat: Material, girder_mat: Material, has_barriers: bool, has_piers: bool, left_gaps: Array = [], right_gaps: Array = []) -> void:
	var baked := curve.get_baked_points()
	if baked.size() < 2:
		return

	var total_len: float = curve.get_baked_length()
	var half_w: float = width * 0.5
	var barrier_w: float = 0.45
	var barrier_h: float = 1.25
	var girder_depth: float = 0.90

	var st_road := SurfaceTool.new()
	st_road.begin(Mesh.PRIMITIVE_TRIANGLES)

	var st_barrier := SurfaceTool.new()
	st_barrier.begin(Mesh.PRIMITIVE_TRIANGLES)

	var st_girder := SurfaceTool.new()
	st_girder.begin(Mesh.PRIMITIVE_TRIANGLES)

	var cum_dist: float = 0.0
	var pier_root := Node3D.new()
	pier_root.name = node_name + "_Pylons"
	parent.add_child(pier_root)

	var last_pier_dist: float = -100.0
	var is_ramp := node_name.contains("Flyover") or node_name.contains("Gorge") or node_name.contains("Bypass")

	var left_factors: Array[float] = []
	var right_factors: Array[float] = []

	for i in range(baked.size()):
		var p: Vector3 = baked[i]
		var fwd := Vector3.FORWARD
		if i < baked.size() - 1:
			fwd = (baked[i + 1] - p).normalized()
		elif i > 0:
			fwd = (p - baked[i - 1]).normalized()

		var right := Vector3(-fwd.z, 0, fwd.x).normalized()
		var up := Vector3.UP

		if i > 0:
			cum_dist += p.distance_to(baked[i - 1])

		# Determine barrier suppression factors (1.0 = full barrier, 0.0 = completely open / no barrier):
		var left_factor: float = 1.0
		var right_factor: float = 1.0

		if is_ramp:
			# General taper at the very ends of the outer barrier:
			var t_in: float = clampf(cum_dist / 6.0, 0.0, 1.0)
			var t_out: float = clampf((total_len - cum_dist) / 6.0, 0.0, 1.0)
			var general_taper: float = minf(t_in, t_out)

			if node_name.contains("Flyover"):
				# Ramp 1: Starts branching right (Left side touches main road)
				if cum_dist < 22.0:
					left_factor = 0.0
				elif cum_dist < 42.0:
					left_factor = minf(general_taper, (cum_dist - 22.0) / 20.0)
				else:
					left_factor = general_taper
				
				# Ends merging from left (Right side touches main road)
				if (total_len - cum_dist) < 22.0:
					right_factor = 0.0
				elif (total_len - cum_dist) < 42.0:
					right_factor = minf(general_taper, ((total_len - cum_dist) - 22.0) / 20.0)
				else:
					right_factor = general_taper

			elif node_name.contains("Gorge"):
				# Ramp 2: Starts branching right, Ends merging from right (Left side touches main road for both)
				if cum_dist < 22.0 or (total_len - cum_dist) < 22.0:
					left_factor = 0.0
				elif cum_dist < 42.0:
					left_factor = minf(general_taper, (cum_dist - 22.0) / 20.0)
				elif (total_len - cum_dist) < 42.0:
					left_factor = minf(general_taper, ((total_len - cum_dist) - 22.0) / 20.0)
				else:
					left_factor = general_taper
				right_factor = general_taper

			elif node_name.contains("Bypass"):
				# Ramp 3: Starts branching left, Ends merging from left (Right side touches main road)
				left_factor = general_taper
				if cum_dist < 22.0 or (total_len - cum_dist) < 22.0:
					right_factor = 0.0
				elif cum_dist < 42.0:
					right_factor = minf(general_taper, (cum_dist - 22.0) / 20.0)
				elif (total_len - cum_dist) < 42.0:
					right_factor = minf(general_taper, ((total_len - cum_dist) - 22.0) / 20.0)
				else:
					right_factor = general_taper
		else:
			# MainHighway: Check gap intervals
			for gap in left_gaps:
				var g_start: float = gap.x
				var g_end: float = gap.y
				if cum_dist >= g_start and cum_dist <= g_end:
					left_factor = 0.0
					break
				elif cum_dist > g_start - 6.0 and cum_dist < g_start:
					left_factor = minf(left_factor, (g_start - cum_dist) / 6.0)
				elif cum_dist > g_end and cum_dist < g_end + 6.0:
					left_factor = minf(left_factor, (cum_dist - g_end) / 6.0)

			for gap in right_gaps:
				var g_start: float = gap.x
				var g_end: float = gap.y
				if cum_dist >= g_start and cum_dist <= g_end:
					right_factor = 0.0
					break
				elif cum_dist > g_start - 6.0 and cum_dist < g_start:
					right_factor = minf(right_factor, (g_start - cum_dist) / 6.0)
				elif cum_dist > g_end and cum_dist < g_end + 6.0:
					right_factor = minf(right_factor, (cum_dist - g_end) / 6.0)

		left_factors.append(left_factor)
		right_factors.append(right_factor)

		var cur_lb_h: float = barrier_h * left_factor
		var cur_rb_h: float = barrier_h * right_factor
		var uv_y: float = cum_dist

		# --- 1. ROAD DECK VERTICES (5 points across road: 0=L edge, 1=L lane, 2=center, 3=R lane, 4=R edge) ---
		st_road.set_uv(Vector2(0.0, uv_y))
		st_road.add_vertex(p - right * half_w)

		st_road.set_uv(Vector2(0.25, uv_y))
		st_road.add_vertex(p - right * (half_w * 0.5))

		st_road.set_uv(Vector2(0.50, uv_y))
		st_road.add_vertex(p + up * 0.04) # subtle center crown

		st_road.set_uv(Vector2(0.75, uv_y))
		st_road.add_vertex(p + right * (half_w * 0.5))

		st_road.set_uv(Vector2(1.0, uv_y))
		st_road.add_vertex(p + right * half_w)

		# --- 2. JERSEY SAFETY BARRIER VERTICES (8 points: 4 on left, 4 on right) ---
		# Left barrier profile
		var lb_base_out := p - right * (half_w + barrier_w * left_factor)
		var lb_flange := p - right * (half_w + 0.12 * left_factor) + up * (0.35 * left_factor)
		var lb_stem := p - right * (half_w + 0.08 * left_factor) + up * (1.15 * left_factor)
		var lb_top := p - right * (half_w + 0.38 * left_factor) + up * cur_lb_h

		st_barrier.set_uv(Vector2(0.0, uv_y * 0.3))
		st_barrier.add_vertex(lb_base_out)
		st_barrier.set_uv(Vector2(0.3, uv_y * 0.3))
		st_barrier.add_vertex(lb_flange)
		st_barrier.set_uv(Vector2(0.7, uv_y * 0.3))
		st_barrier.add_vertex(lb_stem)
		st_barrier.set_uv(Vector2(1.0, uv_y * 0.3))
		st_barrier.add_vertex(lb_top)

		# Right barrier profile
		var rb_base_out := p + right * (half_w + barrier_w * right_factor)
		var rb_flange := p + right * (half_w + 0.12 * right_factor) + up * (0.35 * right_factor)
		var rb_stem := p + right * (half_w + 0.08 * right_factor) + up * (1.15 * right_factor)
		var rb_top := p + right * (half_w + 0.38 * right_factor) + up * cur_rb_h

		st_barrier.set_uv(Vector2(0.0, uv_y * 0.3))
		st_barrier.add_vertex(rb_base_out)
		st_barrier.set_uv(Vector2(0.3, uv_y * 0.3))
		st_barrier.add_vertex(rb_flange)
		st_barrier.set_uv(Vector2(0.7, uv_y * 0.3))
		st_barrier.add_vertex(rb_stem)
		st_barrier.set_uv(Vector2(1.0, uv_y * 0.3))
		st_barrier.add_vertex(rb_top)

		# --- 3. UNDER-DECK BOX GIRDER (4 points: 0=gt_l, 1=gb_l, 2=gb_r, 3=gt_r) ---
		# Form an open U-girder strictly BELOW the deck to prevent any Z-fighting with the road surface!
		var box_drop: float = girder_depth if p.y > 4.5 else clampf(p.y - 0.5, 0.25, girder_depth)
		var gt_l := p - right * half_w - up * 0.12
		var gb_l := p - right * (half_w - 0.2) - up * box_drop
		var gb_r := p + right * (half_w - 0.2) - up * box_drop
		var gt_r := p + right * half_w - up * 0.12

		st_girder.set_uv(Vector2(0.0, uv_y * 0.2))
		st_girder.add_vertex(gt_l)
		st_girder.set_uv(Vector2(0.3, uv_y * 0.2))
		st_girder.add_vertex(gb_l)
		st_girder.set_uv(Vector2(0.7, uv_y * 0.2))
		st_girder.add_vertex(gb_r)
		st_girder.set_uv(Vector2(1.0, uv_y * 0.2))
		st_girder.add_vertex(gt_r)

		# --- 4. VIADUCT PYLONS & CROSSHEAD BEAMS ---
		# Exclude piers right in front of or directly above the lower highway corridor
		var over_lower_road: bool = absf(p.x) < 13.0 and absf(p.z - (-180.0)) < 20.0
		if has_piers and p.y > 6.0 and not over_lower_road and (cum_dist - last_pier_dist >= 24.0):
			last_pier_dist = cum_dist
			_build_viaduct_pier(pier_root, p, fwd, right, half_w, p.y, barrier_mat)

	# For MainHighway, explicitly place two monumental viaduct bridge piers flanking the tunnel entrance
	if node_name == "MainHighway":
		var fwd_overpass := Vector3(-1, 0, 0)
		var right_overpass := Vector3(0, 0, -1)
		_build_viaduct_pier(pier_root, Vector3(-15.5, 16.5, -180.0), fwd_overpass, right_overpass, half_w, 16.5, barrier_mat)
		_build_viaduct_pier(pier_root, Vector3(15.5, 16.5, -180.0), fwd_overpass, right_overpass, half_w, 16.5, barrier_mat)

	# Connect Road Triangles (4 quads = 8 tris per segment)
	for i in range(baked.size() - 1):
		var r0 = i * 5
		var r1 = (i + 1) * 5
		for c in range(4):
			var a = r0 + c
			var b = r0 + c + 1
			var c_idx = r1 + c
			var d = r1 + c + 1
			st_road.add_index(a); st_road.add_index(c_idx); st_road.add_index(b)
			st_road.add_index(b); st_road.add_index(c_idx); st_road.add_index(d)

	# Connect Barrier Triangles (3 quads left, 3 quads right = 12 tris per segment)
	# ONLY generate triangles when barrier height > 0.05 to leave wide-open, collision-free openings!
	for i in range(baked.size() - 1):
		var b0 = i * 8
		var b1 = (i + 1) * 8
		# Left barrier (faces inner toward road)
		if left_factors[i] > 0.05 or left_factors[i + 1] > 0.05:
			for c in range(3):
				var a = b0 + c
				var b = b0 + c + 1
				var c_idx = b1 + c
				var d = b1 + c + 1
				st_barrier.add_index(a); st_barrier.add_index(b); st_barrier.add_index(c_idx)
				st_barrier.add_index(b); st_barrier.add_index(d); st_barrier.add_index(c_idx)
		# Right barrier (faces inner toward road)
		if right_factors[i] > 0.05 or right_factors[i + 1] > 0.05:
			for c in range(3):
				var a = b0 + 4 + c
				var b = b0 + 4 + c + 1
				var c_idx = b1 + 4 + c
				var d = b1 + 4 + c + 1
				st_barrier.add_index(a); st_barrier.add_index(c_idx); st_barrier.add_index(b)
				st_barrier.add_index(b); st_barrier.add_index(c_idx); st_barrier.add_index(d)

	# Connect Girder Triangles (3 quads = 6 tris per segment):
	# Quad 0 (c=0): connects 0 (gt_l) to 1 (gb_l) -> Left vertical drop face
	# Quad 1 (c=1): connects 1 (gb_l) to 2 (gb_r) -> Bottom horizontal soffit plate
	# Quad 2 (c=2): connects 2 (gb_r) to 3 (gt_r) -> Right vertical rise face
	# NOTICE: No connection between 3 and 0! The top is completely open and sits under the road deck.
	for i in range(baked.size() - 1):
		var g0 = i * 4
		var g1 = (i + 1) * 4
		for c in range(3):
			var a = g0 + c
			var b = g0 + c + 1
			var c_idx = g1 + c
			var d = g1 + c + 1
			st_girder.add_index(a); st_girder.add_index(c_idx); st_girder.add_index(b)
			st_girder.add_index(b); st_girder.add_index(c_idx); st_girder.add_index(d)

	st_road.generate_normals()
	st_road.generate_tangents()
	var road_mesh: ArrayMesh = st_road.commit()

	st_barrier.generate_normals()
	st_barrier.generate_tangents()
	var barrier_mesh: ArrayMesh = st_barrier.commit()

	st_girder.generate_normals()
	st_girder.generate_tangents()
	var girder_mesh: ArrayMesh = st_girder.commit()

	# StaticBody3D with collision for the road, barriers, and under-deck
	var static_body := StaticBody3D.new()
	static_body.name = node_name + "_Collision"
	static_body.add_to_group("track_surface", true)

	var road_inst := MeshInstance3D.new()
	road_inst.name = node_name + "_DeckMesh"
	road_inst.mesh = road_mesh
	road_inst.material_override = road_mat
	static_body.add_child(road_inst)

	var barrier_inst := MeshInstance3D.new()
	barrier_inst.name = node_name + "_BarrierMesh"
	barrier_inst.mesh = barrier_mesh
	barrier_inst.material_override = barrier_mat
	static_body.add_child(barrier_inst)

	var girder_inst := MeshInstance3D.new()
	girder_inst.name = node_name + "_GirderMesh"
	girder_inst.mesh = girder_mesh
	girder_inst.material_override = girder_mat
	static_body.add_child(girder_inst)

	# Add TriMesh collision shapes for precise driving and barrier bounces
	var col_shape := CollisionShape3D.new()
	col_shape.name = "DeckCollision"
	var r_trimesh = road_mesh.create_trimesh_shape()
	if r_trimesh is ConcavePolygonShape3D:
		(r_trimesh as ConcavePolygonShape3D).backface_collision = true
	col_shape.shape = r_trimesh
	static_body.add_child(col_shape)

	var col_barrier := CollisionShape3D.new()
	col_barrier.name = "BarrierCollision"
	var b_trimesh = barrier_mesh.create_trimesh_shape()
	if b_trimesh is ConcavePolygonShape3D:
		(b_trimesh as ConcavePolygonShape3D).backface_collision = true
	col_barrier.shape = b_trimesh
	static_body.add_child(col_barrier)

	parent.add_child(static_body)


## Builds a heavy concrete viaduct bent with crosshead beam and dual cylindrical columns.
func _build_viaduct_pier(parent: Node, pos: Vector3, fwd: Vector3, right: Vector3, half_w: float, height: float, mat: Material) -> void:
	var pier := Node3D.new()
	pier.name = "Pier_%d_%d" % [int(pos.x), int(pos.z)]
	pier.position = pos

	var rot_y := rad_to_deg(atan2(-fwd.x, -fwd.z))
	pier.rotation_degrees = Vector3(0, rot_y, 0)

	# Crosshead Cap Beam under the deck
	var beam_inst := MeshInstance3D.new()
	beam_inst.name = "CrossheadBeam"
	var bm := BoxMesh.new()
	bm.size = Vector3(half_w * 2.2, 1.2, 2.2)
	beam_inst.mesh = bm
	beam_inst.material_override = mat
	beam_inst.position = Vector3(0, -1.1, 0)
	pier.add_child(beam_inst)

	# Dual Heavy Concrete Columns extending down to ground level
	var col_h = maxf(height - 1.2, 1.0)
	var col_r = 1.0
	for side in [-1.0, 1.0]:
		var col_x = side * (half_w * 0.55)
		var col_inst := MeshInstance3D.new()
		col_inst.name = "Column_" + ("L" if side < 0 else "R")
		var cm := CylinderMesh.new()
		cm.top_radius = col_r
		cm.bottom_radius = col_r * 1.15
		cm.height = col_h
		cm.radial_segments = 16
		col_inst.mesh = cm
		col_inst.material_override = mat
		col_inst.position = Vector3(col_x, -1.2 - col_h * 0.5, 0)
		pier.add_child(col_inst)

		# Column Footing
		var foot_inst := MeshInstance3D.new()
		foot_inst.name = "Footing_" + ("L" if side < 0 else "R")
		var fm := BoxMesh.new()
		fm.size = Vector3(3.2, 1.0, 3.2)
		foot_inst.mesh = fm
		foot_inst.material_override = mat
		foot_inst.position = Vector3(col_x, -height + 0.5, 0)
		pier.add_child(foot_inst)

	parent.add_child(pier)


## Builds the reinforced concrete tunnel underpass with portals, vaulted ceiling, and interior lighting.
func _build_tunnel_underpass(parent: Node, center: Vector3, length: float, width: float, mat: Material, dark_mat: Material) -> void:
	var tunnel_root := Node3D.new()
	tunnel_root.name = "GlacierTunnelUnderpass"
	tunnel_root.position = center

	var half_len: float = length * 0.5
	var half_w: float = width * 0.5
	var wall_h: float = 6.2
	var wall_th: float = 1.2

	# 1. Left and Right Tunnel Walls
	for side in [-1.0, 1.0]:
		var wall_body := StaticBody3D.new()
		wall_body.name = "TunnelWall_" + ("L" if side < 0 else "R")
		wall_body.position = Vector3(side * (half_w + wall_th * 0.5), wall_h * 0.5, 0)

		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(wall_th, wall_h, length)
		col.shape = shape
		wall_body.add_child(col)

		var mesh_inst := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = shape.size
		mesh_inst.mesh = bm
		mesh_inst.material_override = mat
		wall_body.add_child(mesh_inst)
		tunnel_root.add_child(wall_body)

	# 2. Vaulted Arch Ceiling
	var ceiling_body := StaticBody3D.new()
	ceiling_body.name = "TunnelCeiling"
	ceiling_body.position = Vector3(0, wall_h + 0.4, 0)

	var c_col := CollisionShape3D.new()
	var c_shape := BoxShape3D.new()
	c_shape.size = Vector3(width + wall_th * 2.0, 0.8, length)
	c_col.shape = c_shape
	ceiling_body.add_child(c_col)

	var c_mesh := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = c_shape.size
	c_mesh.mesh = cm
	c_mesh.material_override = dark_mat
	ceiling_body.add_child(c_mesh)
	tunnel_root.add_child(ceiling_body)

	# 3. Portals at Entrance (South, Z = +half_len) and Exit (North, Z = -half_len)
	for p_end in [-1.0, 1.0]:
		var p_z = p_end * half_len
		var portal_name = "Portal_" + ("North" if p_end < 0 else "South")

		var portal_node := Node3D.new()
		portal_node.name = portal_name
		portal_node.position = Vector3(0, 0, p_z)

		# Portal Arch Header
		var header := MeshInstance3D.new()
		header.name = "ArchHeader"
		var hm := BoxMesh.new()
		hm.size = Vector3(width + 4.5, 2.8, 3.5)
		header.mesh = hm
		header.material_override = mat
		header.position = Vector3(0, wall_h + 1.2, 0)
		portal_node.add_child(header)

		# Portal Side Buttresses
		for side in [-1.0, 1.0]:
			var buttress := MeshInstance3D.new()
			buttress.name = "Buttress_" + ("L" if side < 0 else "R")
			var btm := BoxMesh.new()
			btm.size = Vector3(3.2, wall_h + 2.5, 3.5)
			buttress.mesh = btm
			buttress.material_override = mat
			buttress.position = Vector3(side * (half_w + 1.8), (wall_h + 2.5) * 0.5, 0)
			portal_node.add_child(buttress)

			# Wing-wall flaring into snow mountain
			var wing := MeshInstance3D.new()
			wing.name = "WingWall_" + ("L" if side < 0 else "R")
			var wm := BoxMesh.new()
			wm.size = Vector3(4.5, wall_h + 1.5, 2.0)
			wing.mesh = wm
			wing.material_override = mat
			wing.position = Vector3(side * (half_w + 4.2), (wall_h + 1.5) * 0.5, p_end * 1.5)
			wing.rotation_degrees = Vector3(0, side * 32.0, 0)
			portal_node.add_child(wing)

		# Overhead Illuminated Portal Sign Board
		var sign_inst := MeshInstance3D.new()
		sign_inst.name = "PortalSign"
		var sm := BoxMesh.new()
		sm.size = Vector3(14.0, 1.4, 0.25)
		sign_inst.mesh = sm
		var sign_mat := StandardMaterial3D.new()
		sign_mat.albedo_color = Color(0.08, 0.16, 0.32)
		sign_mat.emission_enabled = true
		sign_mat.emission = Color(0.12, 0.45, 0.85)
		sign_mat.emission_energy_multiplier = 0.8
		sign_inst.material_override = sign_mat
		sign_inst.position = Vector3(0, wall_h + 1.5, p_end * 1.8)
		portal_node.add_child(sign_inst)

		tunnel_root.add_child(portal_node)

	# 4. Interior Tunnel LED Strip Lights (6 pairs casting warm amber glow)
	var light_z_steps = [-24.0, -15.0, -6.0, 6.0, 15.0, 24.0]
	for lz in light_z_steps:
		for side in [-1.0, 1.0]:
			var lamp_x = side * (half_w - 1.2)
			var omni := OmniLight3D.new()
			omni.name = "TunnelLight_%d_%s" % [int(lz), "L" if side < 0 else "R"]
			omni.position = Vector3(lamp_x, wall_h - 0.3, lz)
			omni.light_color = Color(1.0, 0.84, 0.55) # warm sodium/amber tunnel glow
			omni.light_energy = 1.3
			omni.omni_range = 16.0
			omni.omni_attenuation = 0.9
			tunnel_root.add_child(omni)

			# Emissive lamp fixture mesh
			var fixture := MeshInstance3D.new()
			fixture.name = "Fixture_%d_%s" % [int(lz), "L" if side < 0 else "R"]
			var fm := BoxMesh.new()
			fm.size = Vector3(0.5, 0.2, 1.8)
			fixture.mesh = fm
			var f_mat := StandardMaterial3D.new()
			f_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			f_mat.albedo_color = Color(1.0, 0.90, 0.65)
			fixture.material_override = f_mat
			fixture.position = Vector3(lamp_x, wall_h - 0.1, lz)
			tunnel_root.add_child(fixture)

	parent.add_child(tunnel_root)


## Builds surrounding arctic mountains, snow ridges, and frozen valley floor.
func _build_arctic_mountain_landscape(parent: Node) -> void:
	var terrain_root := Node3D.new()
	terrain_root.name = "AlpineMountains"

	var snow_tex: Texture2D = load("res://materials/sand_normal.png") as Texture2D
	var rock_tex: Texture2D = load("res://materials/dark_canyon_rock.png") as Texture2D
	var rock_norm: Texture2D = load("res://materials/dark_canyon_rock_normal.png") as Texture2D

	var snow_mat := StandardMaterial3D.new()
	snow_mat.albedo_color = Color(0.96, 0.98, 1.0)
	snow_mat.roughness = 0.92
	if snow_tex:
		snow_mat.normal_enabled = true
		snow_mat.normal_texture = snow_tex
		snow_mat.normal_scale = 0.4
		snow_mat.uv1_scale = Vector3(0.12, 0.12, 0.12)
		snow_mat.uv1_triplanar = true

	var rock_mat := StandardMaterial3D.new()
	if rock_tex:
		rock_mat.albedo_texture = rock_tex
		rock_mat.albedo_color = Color(0.72, 0.75, 0.80)
	if rock_norm:
		rock_mat.normal_enabled = true
		rock_mat.normal_texture = rock_norm
		rock_mat.normal_scale = 0.9
	rock_mat.roughness = 0.88
	rock_mat.uv1_scale = Vector3(0.18, 0.18, 0.18)
	rock_mat.uv1_triplanar = true

	# 1. Broad Valley Snow Floor (radius 480m)
	var floor_body := StaticBody3D.new()
	floor_body.name = "GlacierValleyFloor"
	floor_body.position = Vector3(0, 0.0, 0)
	var f_col := CollisionShape3D.new()
	var f_shape := BoxShape3D.new()
	f_shape.size = Vector3(900.0, 1.0, 900.0)
	f_col.shape = f_shape
	floor_body.add_child(f_col)

	var f_mesh := MeshInstance3D.new()
	var fm := PlaneMesh.new()
	fm.size = Vector2(900.0, 900.0)
	fm.subdivide_width = 8
	fm.subdivide_depth = 8
	f_mesh.mesh = fm
	f_mesh.material_override = snow_mat
	floor_body.add_child(f_mesh)
	terrain_root.add_child(floor_body)

	# 2. Alpine Mountain Ridge Flanking the Tunnel (HOLLOW tunnel corridor at |X| < 10.0!)
	# NOTE: Kept strictly below Y = 9.8m and Z between -188m and -232m so the upper overpass at Z = -180m, Y = 16.5m has 100% open sky!
	# West Mountain Bluff (X from -10 to -120, Z from -188 to -232, Y from 0 to 9.6m)
	var west_bluff := StaticBody3D.new()
	west_bluff.name = "MountainBluff_West"
	west_bluff.position = Vector3(-65.0, 4.8, -210.0)
	var wb_col := CollisionShape3D.new()
	var wb_shape := BoxShape3D.new()
	wb_shape.size = Vector3(110.0, 9.6, 44.0)
	wb_col.shape = wb_shape
	west_bluff.add_child(wb_col)
	var wb_mesh := MeshInstance3D.new()
	var wbm := BoxMesh.new()
	wbm.size = wb_shape.size
	wb_mesh.mesh = wbm
	wb_mesh.material_override = rock_mat
	west_bluff.add_child(wb_mesh)
	terrain_root.add_child(west_bluff)

	# East Mountain Bluff (X from +10 to +120, Z from -188 to -232, Y from 0 to 9.6m)
	var east_bluff := StaticBody3D.new()
	east_bluff.name = "MountainBluff_East"
	east_bluff.position = Vector3(65.0, 4.8, -210.0)
	var eb_col := CollisionShape3D.new()
	var eb_shape := BoxShape3D.new()
	eb_shape.size = wb_shape.size
	eb_col.shape = eb_shape
	east_bluff.add_child(eb_col)
	var eb_mesh := MeshInstance3D.new()
	var ebm := BoxMesh.new()
	ebm.size = eb_shape.size
	eb_mesh.mesh = ebm
	eb_mesh.material_override = rock_mat
	east_bluff.add_child(eb_mesh)
	terrain_root.add_child(east_bluff)

	# Over-Tunnel Mountain Cap (Connecting East and West above the tunnel ceiling Y = 9.0 to 9.6m)
	var roof_body := StaticBody3D.new()
	roof_body.name = "TunnelMountainRoof"
	roof_body.position = Vector3(0.0, 9.3, -210.0)
	var r_col := CollisionShape3D.new()
	var r_shape := BoxShape3D.new()
	r_shape.size = Vector3(22.0, 0.6, 44.0)
	r_col.shape = r_shape
	roof_body.add_child(r_col)
	var r_mesh := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = r_shape.size
	r_mesh.mesh = rm
	r_mesh.material_override = rock_mat
	roof_body.add_child(r_mesh)
	terrain_root.add_child(roof_body)

	# 3. Perimeter Alpine Mountain Peaks (Set back far outside track perimeter: 60m+ clearance everywhere)
	var peak_defs = [
		# Far North Amphitheater Peaks (Behind North Basin at Z < -500m)
		[Vector3(0.0, 80.0, -560.0), Vector3(420.0, 160.0, 180.0), 0.0],
		[Vector3(260.0, 70.0, -520.0), Vector3(260.0, 140.0, 160.0), -20.0],
		[Vector3(-240.0, 70.0, -520.0), Vector3(260.0, 140.0, 160.0), 20.0],
		# Far East Alpine Ridge Peaks (Behind East Climb at X > 360m)
		[Vector3(370.0, 75.0, -260.0), Vector3(180.0, 150.0, 320.0), 15.0],
		[Vector3(380.0, 70.0, -60.0), Vector3(180.0, 140.0, 280.0), -10.0],
		# Far South Meadow Ridge Peaks (Behind South Loop at Z > 500m)
		[Vector3(-100.0, 60.0, 520.0), Vector3(320.0, 120.0, 180.0), 0.0],
		[Vector3(160.0, 55.0, 480.0), Vector3(260.0, 110.0, 160.0), -12.0],
		# Far West Mountain Peaks (Behind West Shelf at X < -320m)
		[Vector3(-330.0, 75.0, -140.0), Vector3(180.0, 150.0, 320.0), -15.0],
		[Vector3(-320.0, 65.0, 80.0), Vector3(180.0, 130.0, 280.0), 18.0]
	]

	for i in range(peak_defs.size()):
		var p_info = peak_defs[i]
		var peak_inst := MeshInstance3D.new()
		peak_inst.name = "MountainPeak_%d" % (i + 1)
		var p_prism := PrismMesh.new()
		p_prism.size = p_info[1]
		peak_inst.mesh = p_prism
		peak_inst.material_override = snow_mat
		peak_inst.position = p_info[0]
		peak_inst.rotation_degrees = Vector3(0, p_info[2], 0)
		terrain_root.add_child(peak_inst)

	parent.add_child(terrain_root)


## Builds highway overhead gantry signs spanning across the 4-lane concrete highway.
func _build_highway_gantries(parent: Node) -> void:
	var gantry_defs = [
		[Vector3(-85.0, 2.8, 220.0), 0.0, "GLACIER HIGHWAY GP • SPEED LIMIT: NONE"],
		[Vector3(-82.0, 2.8, 50.0), 0.0, "RIGHT LANE: EXPRESS FLYOVER ↗ • ELEVATED BYPASS"],
		[Vector3(0.0, 2.8, -145.0), 0.0, "TUNNEL APPROACH • CLEARANCE 6.0M • LOW BEAM LIGHTS"],
		[Vector3(0.0, 16.5, -180.0), -90.0, "GLACIER OVERPASS VIADUCT • HIGH SUMMIT CROSSING"]
	]

	var steel_mat := StandardMaterial3D.new()
	steel_mat.albedo_color = Color(0.42, 0.45, 0.49)
	steel_mat.metallic = 0.85
	steel_mat.roughness = 0.35

	for i in range(gantry_defs.size()):
		var g_info = gantry_defs[i]
		var g_pos: Vector3 = g_info[0]
		var g_yaw: float = g_info[1]

		var gantry := Node3D.new()
		gantry.name = "HighwayGantry_%d" % (i + 1)
		gantry.position = g_pos
		gantry.rotation_degrees = Vector3(0, g_yaw, 0)

		# Horizontal Truss Span across road (width = 19m, clearance height = 6.2m)
		var span := MeshInstance3D.new()
		span.name = "TrussSpan"
		var sm := BoxMesh.new()
		sm.size = Vector3(19.0, 1.1, 1.2)
		span.mesh = sm
		span.material_override = steel_mat
		span.position = Vector3(0, 6.2, 0)
		gantry.add_child(span)

		# Left and Right Vertical Support Columns
		for side in [-1.0, 1.0]:
			var col := MeshInstance3D.new()
			col.name = "Support_" + ("L" if side < 0 else "R")
			var cm := CylinderMesh.new()
			cm.top_radius = 0.40
			cm.bottom_radius = 0.45
			cm.height = 6.8
			col.mesh = cm
			col.material_override = steel_mat
			col.position = Vector3(side * 9.2, 3.4, 0)
			gantry.add_child(col)

		# Overhead Green Interstate Sign Board
		var sign_board := MeshInstance3D.new()
		sign_board.name = "SignBoard"
		var sbm := BoxMesh.new()
		sbm.size = Vector3(14.0, 1.8, 0.20)
		sign_board.mesh = sbm
		var sign_mat := StandardMaterial3D.new()
		sign_mat.albedo_color = Color(0.04, 0.32, 0.16) # Interstate highway green
		sign_mat.emission_enabled = true
		sign_mat.emission = Color(0.08, 0.42, 0.22)
		sign_mat.emission_energy_multiplier = 0.4
		sign_board.material_override = sign_mat
		sign_board.position = Vector3(0, 6.2, 0.65)
		gantry.add_child(sign_board)

		parent.add_child(gantry)


## Builds highway streetlights along the outer barrier edges with illuminating spotlights.
func _build_highway_streetlights(parent: Node, curve: Curve3D) -> void:
	var total_len := curve.get_baked_length()
	var step_dist := 65.0
	var count := int(total_len / step_dist)

	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.65, 0.68, 0.72)
	pole_mat.metallic = 0.75
	pole_mat.roughness = 0.4

	for i in range(count):
		var dist = i * step_dist
		var p := curve.sample_baked(dist)
		# Skip lights inside the tunnel underpass (it has its own interior LED strip lights)
		if p.z < -165.0 and p.z > -245.0 and p.y < 5.0:
			continue

		var next_p := curve.sample_baked(minf(total_len, dist + 1.0))
		var fwd := (next_p - p).normalized()
		var right := Vector3(-fwd.z, 0, fwd.x).normalized()

		# Place alternating on left or right barrier
		var side := 1.0 if (i % 2 == 0) else -1.0
		var pole_pos = p + right * (side * 8.8)

		var light_node := Node3D.new()
		light_node.name = "Streetlight_%d" % i
		light_node.position = pole_pos

		var rot_y := rad_to_deg(atan2(-fwd.x, -fwd.z))
		light_node.rotation_degrees = Vector3(0, rot_y + (90.0 if side > 0 else -90.0), 0)

		# Vertical Pole (height = 8.5m)
		var pole := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.12
		pm.bottom_radius = 0.22
		pm.height = 8.5
		pole.mesh = pm
		pole.material_override = pole_mat
		pole.position = Vector3(0, 4.25, 0)
		light_node.add_child(pole)

		# Horizontal Overhanging Arm
		var arm := MeshInstance3D.new()
		var am := CylinderMesh.new()
		am.top_radius = 0.08
		am.bottom_radius = 0.10
		am.height = 3.2
		arm.mesh = am
		arm.material_override = pole_mat
		arm.position = Vector3(1.4, 8.2, 0)
		arm.rotation_degrees = Vector3(0, 0, 80.0)
		light_node.add_child(arm)

		# LED Luminaire Head
		var head := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(0.9, 0.2, 0.4)
		head.mesh = hm
		var head_mat := StandardMaterial3D.new()
		head_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		head_mat.albedo_color = Color(0.92, 0.96, 1.0)
		head.material_override = head_mat
		head.position = Vector3(2.8, 8.4, 0)
		light_node.add_child(head)

		# SpotLight illuminating the concrete highway road surface
		var spot := SpotLight3D.new()
		spot.name = "Spot"
		spot.position = Vector3(2.8, 8.3, 0)
		spot.rotation_degrees = Vector3(-80, 0, 0)
		spot.light_color = Color(0.88, 0.94, 1.0) # Cool winter LED
		spot.light_energy = 1.6
		spot.spot_range = 22.0
		spot.spot_angle = 50.0
		spot.spot_attenuation = 1.1
		light_node.add_child(spot)

		parent.add_child(light_node)


func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	if node != scene_root:
		node.owner = scene_root
	for child in node.get_children():
		if child.owner != null and child.owner != scene_root:
			continue
		_set_owner_recursive(child, scene_root)


func _add_junction_arrows(parent: Node, curve: Curve3D, left_gaps: Array, right_gaps: Array) -> void:
	var arrows_tex = load("res://sprites/decals/arrows.png")
	if not arrows_tex:
		return
		
	var arrows_parent = Node3D.new()
	arrows_parent.name = "JunctionArrows"
	parent.add_child(arrows_parent)
	
	# Only place at splits, not merges, to guide players into alternative routes
	# main_left_gaps[1] is Alt 3 Split
	_spawn_arrow_decal(arrows_parent, curve, left_gaps[1].x + 12.0, arrows_tex, true)
	
	# main_right_gaps[0] is Alt 1 Split
	_spawn_arrow_decal(arrows_parent, curve, right_gaps[0].x + 12.0, arrows_tex, false)
	# main_right_gaps[1] is Alt 2 Split
	_spawn_arrow_decal(arrows_parent, curve, right_gaps[1].x + 12.0, arrows_tex, false)

func _spawn_arrow_decal(parent: Node, curve: Curve3D, dist: float, tex: Texture2D, is_left: bool) -> void:
	var pos = curve.sample_baked(dist)
	var next_pos = curve.sample_baked(dist + 2.0)
	var fwd = (next_pos - pos).normalized()
	var right = Vector3(-fwd.z, 0, fwd.x).normalized()
	
	# Offset towards the side of the split
	var offset = -5.5 if is_left else 5.5
	pos += right * offset
	pos.y += 0.25 # Slightly above ground to project downwards
	
	var decal = Decal.new()
	decal.texture_albedo = tex
	decal.size = Vector3(6.0, 4.0, 6.0)
	decal.position = pos
	
	# Point the decal arrow diagonally towards the split
	var rot_y = rad_to_deg(atan2(-fwd.x, -fwd.z))
	if is_left:
		rot_y += 25.0
	else:
		rot_y -= 25.0
		
	decal.rotation_degrees = Vector3(0, rot_y, 0)
	decal.albedo_mix = 1.0
	decal.modulate = Color(1.0, 0.8, 0.1, 0.9) # Bright glowing yellow/orange
	
	parent.add_child(decal)
