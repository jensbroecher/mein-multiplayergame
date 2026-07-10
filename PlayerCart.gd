extends RigidBody3D

@export var player_name: String = "Player":
	set(value):
		player_name = value
		if is_inside_tree() and $Visuals/NameTag:
			$Visuals/NameTag.text = value

@export var car_index: int = 0

const CAR_PRESETS = [
	{
		"name": "Viper",
		"model_path": "res://models/cars/Viper.tscn",
		"model_y_rotation": PI,       # native FBX faces backward, flip 180°
		"max_speed": 30.0,
		"acceleration": 50.0,
		"steer_speed": 2.5,
		"grip": 5.0,
		"braking": 40.0,
		"offroad": 6.0,
		# Wheel part names inside the FBX, keyed by corner
		"wheel_parts": {"FL": "part_5", "FR": "part_2", "RL": "part_0", "RR": "part_6"}
	},
	{
		"name": "Shadow",
		"model_path": "res://models/cars/Shadow.tscn",
		"model_y_rotation": PI,
		"max_speed": 30.5,
		"acceleration": 40.0,
		"steer_speed": 2.2,
		"grip": 4.5,
		"braking": 30.0,
		"offroad": 4.0,
		"wheel_parts": {"FL": "part_3", "FR": "part_0", "RL": "part_4", "RR": "part_2"}
	},
	{
		"name": "Strikeforce",
		"model_path": "res://models/cars/Strikeforce.tscn",
		"model_y_rotation": PI * 1.5, # FBX native orientation requires 270° rotation
		"max_speed": 28.0,
		"acceleration": 65.0,
		"steer_speed": 2.7,
		"grip": 5.5,
		"braking": 55.0,
		"offroad": 8.0,
		"wheel_parts": {"FL": "part_10", "FR": "part_7", "RL": "part_11", "RR": "part_9"}
	},
	{
		"name": "Apex",
		"model_path": "res://models/cars/Apex.tscn",
		"model_y_rotation": PI,
		"max_speed": 29.0,
		"acceleration": 55.0,
		"steer_speed": 3.2,
		"grip": 6.0,
		"braking": 48.0,
		"offroad": 5.0,
		"wheel_parts": {"FL": "part_0", "FR": "part_1", "RL": "part_4", "RR": "part_2"}
	},
	{
		"name": "Interceptor",
		"model_path": "res://models/cars/Interceptor.tscn",
		"model_y_rotation": PI,
		"max_speed": 32.0,
		"acceleration": 45.0,
		"steer_speed": 2.0,
		"grip": 4.0,
		"braking": 35.0,
		"offroad": 3.0,
		"wheel_parts": {"FL": "part_6", "FR": "part_3", "RL": "part_4", "RR": "part_5"}
	},
	{
		"name": "Mudrunner",
		"model_path": "res://models/cars/Mudrunner.tscn",
		"model_y_rotation": PI,
		"max_speed": 27.0,
		"acceleration": 55.0,
		"steer_speed": 2.4,
		"grip": 5.0,
		"braking": 45.0,
		"offroad": 9.5,
		"wheel_parts": {"FL": "part_0", "FR": "part_3", "RL": "part_2", "RR": "part_4"}
	},
	{
		"name": "Phantom",
		"model_path": "res://models/cars/Phantom.tscn",
		"model_y_rotation": PI * 0.5,
		"max_speed": 29.5,
		"acceleration": 50.0,
		"steer_speed": 3.5,
		"grip": 3.5,
		"braking": 40.0,
		"offroad": 4.0,
		"wheel_parts": {"FL": "part_4", "FR": "part_0", "RL": "part_3", "RR": "part_2"}
	},
	{
		"name": "Centurion",
		"model_path": "res://models/cars/Centurion.tscn",
		"model_y_rotation": PI,
		"max_speed": 29.5,
		"acceleration": 60.0,
		"steer_speed": 2.6,
		"grip": 5.5,
		"braking": 50.0,
		"offroad": 6.5,
		"wheel_parts": {"FL": "part_0", "FR": "part_5", "RL": "part_2", "RR": "part_3"}
	}
]

var max_speed = 30.0
var reverse_speed = 15.0
var acceleration = 50.0
var braking = 40.0
var steer_speed = 2.5
var grip = 5.0

const GRAVITY = 30.0 # extra gravity so it falls faster

# Wheel/collision alignment constants
const WHEEL_RADIUS = 0.4
const WHEEL_Y_OFFSET = -0.021691  # Match the actual WheelPivot Y position to prevent hovering
const COLLISION_Y_OFFSET = 0.0  # Collision sphere center relative to body center
const COLLISION_RADIUS = WHEEL_RADIUS + 0.1  # Match wheel contact height to prevent hovering off-road

# Preload item scenes
const MISSILE_SCENE = preload("res://Missile.tscn")
const BOMB_SCENE = preload("res://Bomb.tscn")
const WATER_SPLASH_SCENE = preload("res://WaterSplash.tscn")

const DEEP_SPLASH_SOUNDS = [
	preload("res://sounds/deep_water_splash_#1-1781728153794.wav"),
	preload("res://sounds/deep_water_splash_#2-1781728156705.wav"),
	preload("res://sounds/deep_water_splash_#3-1781728161657.wav"),
	preload("res://sounds/deep_water_splash_#4-1781728165962.wav")
]

const REGULAR_SPLASH_SOUNDS = [
	preload("res://sounds/water_splash_#2-1781728133304.wav"),
	preload("res://sounds/water_splash_#3-1781728129266.wav"),
	preload("res://sounds/water_splash_#4-1781728106730.wav")
]

const BOMB_EXPLOSION_SOUNDS = [
	preload("res://sounds/bomb_explosion_#2-1781728320398.wav"),
	preload("res://sounds/bomb_explosion_#4-1781728322907.wav"),
	preload("res://sounds/bomb_explosion_with__#1-1781728361227.wav"),
	preload("res://sounds/bomb_explosion_with__#3-1781728366899.wav"),
	preload("res://sounds/bomb_explosion_with__#4-1781728370769.wav")
]

const LANDING_SOUNDS = [
	preload("res://sounds/freesound_community-bonk-46000.mp3"),
	preload("res://sounds/crash.mp3")
]

@onready var visuals = $Visuals
@onready var camera_pivot = $Visuals/CameraPivot
@onready var camera = $Visuals/CameraPivot/Camera3D
@onready var name_tag = $Visuals/NameTag
@onready var engine_sound = $Visuals/EngineSound
@onready var ground_ray = $GroundRay


var race_ui
var avg_wheel_y: float = -0.02
var last_respawn_time: float = -999.0

@onready var sfx_nitro_start = $Visuals/SFX_NitroStart
@onready var sfx_rocket_loop = $Visuals/SFX_RocketLoop
@onready var sfx_release_pop = $Visuals/SFX_ReleasePop
@onready var sfx_double_beep = $Visuals/SFX_DoubleBeep
@onready var sfx_beep_warning = $Visuals/SFX_BeepWarning
@onready var sfx_explosion = $Visuals/SFX_Explosion
@onready var sfx_fire_loop = $Visuals/SFX_FireLoop
@onready var boost_particles = $Visuals/BoostParticles
@onready var explosion_particles = $Visuals/ExplosionParticles
@onready var burning_particles = $Visuals/BurningParticles
@onready var burning_smoke_particles = $Visuals/BurningSmokeParticles
@onready var fire_sprite_particles = $Visuals/FireSpriteParticles
@onready var fire_sprite_particles_2 = $Visuals/FireSpriteParticles2
@onready var sfx_wind_loop = $Visuals/SFX_WindLoop
@onready var sfx_shield_loop = $Visuals/SFX_ShieldLoop
@onready var sfx_landing_bonk = $Visuals/SFX_LandingBonk
@onready var shield_mesh = $Visuals/ShieldMesh
@onready var shockwave_visual = $Visuals/ShockwaveVisual

var playback: AudioStreamGeneratorPlayback
var sample_rate: float

var is_local_player = false
var can_move = false
var can_control = true
@export var is_ai: bool = false
var smoothed_speed: float = 0.0
var stuck_timer: float = 0.0
var ai_item_timer: float = 0.0
var ai_lane_offset: float = 0.0
var ai_target_lane_offset: float = 0.0
var ai_lane_change_timer: float = 0.0
var ai_stuck_position_timer: float = 0.0
var ai_last_stuck_position: Vector3 = Vector3.ZERO
var track_path: Path3D = null
var alternative_paths: Array[Path3D] = []
var active_path: Path3D = null
var on_alternative_path: bool = false
var alt_path_decisions: Dictionary = {} # Path3D -> bool


var is_exploding = false
var boost_time = 0.0
var boost_timer = 0.0
var is_boosting = false
var is_pad_boosting = false
var pad_boost_timer = 0.0

@onready var sfx_brake_drift = $Visuals/SFX_BrakeDrift
var is_drifting: bool = false
var was_on_ground: bool = true
var air_time: float = 0.0
var ignore_next_landing_sound: bool = false
var wheel_rotation: float = 0.0
var is_teleporting: bool = false
var is_shielded: bool = false
var was_shocked: bool = false
var camera_look_at: Vector3 = Vector3.ZERO
var camera_clip_distance_mult: float = 1.0
var camera_clip_distance_mult_iso: float = 1.0
var is_isometric: bool = true
var is_intro_active: bool = false
var intro_time: float = 0.0
const INTRO_DURATION: float = 3.5
var intro_orbit_center: Vector3 = Vector3.ZERO
var engine_phase: float = 0.0
var hop_cooldown: float = 0.0
var drift_mode: bool = false
var drift_right: bool = false
var drift_particles = []
@export var sync_emit_drift: bool = false
var dirt_particles = []
@export var sync_emit_dirt: bool = false
var offroad_penalty: float = 1.0
var offroad_target_penalty: float = 1.0
var offroad_timer: float = 0.0
var is_offroad: bool = false
var visual_offset_y: float = 0.0

var stage_has_water: bool = true
var is_underwater: bool = false
const WATER_LEVEL = -10.0
var water_timer: float = 0.0
var last_splash_time: float = -999.0
var is_drowned: bool = false
var _drown_tween: Tween = null
var original_wheel_transforms: Dictionary = {}
var original_cart_model_transform: Transform3D
var part_velocities: Dictionary = {}
var part_rotations: Dictionary = {}
var explosion_time: float = 0.0
var respawn_indicator_time: float = 0.0
var original_body_part_transforms: Dictionary = {}
var part_on_ground: Dictionary = {}

# Remote interpolation tuning
const REMOTE_LERP_SPEED: float = 18.0

enum ItemType { NONE, BOOST, MISSILE, GUIDED_MISSILE, SHIELD, SHOCKWAVE, BOMB, LIGHTNING }
var current_item = ItemType.NONE
var current_item_2 = ItemType.NONE
var is_landing: bool = false
var slow_timer: float = 0.0
var _original_albedo_colors: Dictionary = {}

var last_checkpoint_transform: Transform3D

var sync_position: Vector3
var sync_rotation: Vector3
var sync_velocity: Vector3
var sync_steer: float = 0.0
var sync_rotation_quat: Quaternion = Quaternion.IDENTITY

# Visual alignment variables
var target_mesh_transform := Transform3D.IDENTITY
var current_steer: float = 0.0

# RC Antenna variables
@onready var antenna = $Visuals/Antenna
var antenna_tilt: Vector3 = Vector3.ZERO
var antenna_velocity: Vector3 = Vector3.ZERO
var antenna_accel_smooth: Vector3 = Vector3.ZERO
var last_velocity_local: Vector3 = Vector3.ZERO

func has_physics_authority() -> bool:
	return is_local_player or (is_ai and (multiplayer.multiplayer_peer == null or is_multiplayer_authority()))

func on_race_started():
	var has_physics_authority = has_physics_authority()
	if has_physics_authority:
		can_move = true
		freeze = false

func _ready():
	# Lock rotation so we handle it manually, preventing physics rolling at start
	axis_lock_angular_x = true
	axis_lock_angular_y = true
	axis_lock_angular_z = true

	# Set initial visuals position/rotation to match spawn point transform
	# before any process frame runs, preventing wrong starting direction
	visuals.global_transform = global_transform
	visuals.top_level = true

	add_to_group("player_carts")
	_update_authority()

	if is_ai:
		ai_lane_offset = randf_range(-2.0, 2.0)
		ai_target_lane_offset = ai_lane_offset
		ai_lane_change_timer = randf_range(3.0, 6.0)

	# Load the correct model mesh
	var preset = CAR_PRESETS[car_index]
	max_speed = preset.max_speed
	acceleration = preset.acceleration
	steer_speed = preset.steer_speed
	grip = preset.grip
	braking = preset.get("braking", 40.0)
	
	# Replace default model with selected model
	var cart_model = get_node_or_null("Visuals/CartModel")
	if cart_model:
		cart_model.name = "OldCartModel"
		cart_model.queue_free()
	
	var new_model_scene = load(preset.model_path)
	if new_model_scene:
		var new_model = new_model_scene.instantiate()
		new_model.name = "CartModel"
		$Visuals.add_child(new_model)
		$Visuals.move_child(new_model, 0)
		new_model.transform = Transform3D(Basis(Vector3(0, 1, 0), preset.get("model_y_rotation", PI)) * 2.0, Vector3(0, -0.6072377, 0))
		
		# Look for an AntennaPlacement node to reposition the dynamic antenna
		var antenna_placement = new_model.get_node_or_null("AntennaPlacement")
		if not antenna_placement:
			antenna_placement = _find_node_by_name(new_model, "AntennaPlacement")
		if antenna_placement:
			antenna.position = visuals.to_local(antenna_placement.global_position)

	await get_tree().process_frame
	var level = get_tree().get_first_node_in_group("level")
	if level:
		if level.has_node("RaceUI"):
			race_ui = level.get_node("RaceUI")
		var tg = level.get_node_or_null("TerrainGenerator")
		if tg and "no_water" in tg:
			stage_has_water = not tg.no_water

	ground_ray.add_exception(self)

	name_tag.text = player_name
	last_checkpoint_transform = global_transform
	camera_look_at = global_position

	# Setup collision shape to match wheel positions
	var collision_shape = $CollisionShape3D
	if collision_shape and collision_shape.shape is SphereShape3D:
		collision_shape.shape.radius = COLLISION_RADIUS
		collision_shape.transform.origin = Vector3(0, COLLISION_Y_OFFSET, 0)

	# Adjust ground ray to reach just below collision sphere (with buffer for steep slopes)
	ground_ray.target_position = Vector3(0, -(COLLISION_RADIUS + 0.35), 0)
	
	_remove_collisions_recursive(visuals)
	_setup_new_car_wheels()
	_enable_shadows_recursive(visuals)

	# Setup unique material for shockwave visual to prevent sharing/crashing
	if shockwave_visual:
		var mat = StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 1.0, 1.0, 0.5)
		shockwave_visual.material_override = mat

	# Setup unique material for shield visual to allow independent animations
	if shield_mesh:
		var mat = shield_mesh.get_active_material(0)
		if mat:
			shield_mesh.material_override = mat.duplicate()
		else:
			var new_mat = StandardMaterial3D.new()
			new_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			new_mat.albedo_color = Color(0.0, 0.6, 1.0, 0.4)
			new_mat.emission_enabled = true
			new_mat.emission = Color(0.0, 0.4, 1.0, 1.0)
			shield_mesh.material_override = new_mat

	# Route all sound effects under visuals to the SFX bus
	for child in visuals.get_children():
		if child is AudioStreamPlayer3D:
			child.bus = &"SFX"

	if engine_sound.stream is AudioStreamGenerator:
		sample_rate = engine_sound.stream.mix_rate
		playback = engine_sound.get_stream_playback()
		if not engine_sound.playing:
			engine_sound.play()

	if is_local_player:
		camera.current = true
		camera_pivot.top_level = true
		
		# Set initial top-view camera settings
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 35.0
		
		# Rotation is already locked globally at startup

		if not InputMap.has_action("toggle_camera"):
			InputMap.add_action("toggle_camera")
			var ev = InputEventKey.new()
			ev.physical_keycode = KEY_C
			InputMap.action_add_event("toggle_camera", ev)

		if not InputMap.has_action("respawn"):
			InputMap.add_action("respawn")
			var ev = InputEventKey.new()
			ev.physical_keycode = KEY_R
			InputMap.action_add_event("respawn", ev)

		# Position camera immediately at start to avoid sliding in
		if is_isometric:
			var iso_offset = Vector3(-26, 26, 26)
			camera_pivot.global_position = visuals.global_position + iso_offset
			camera_pivot.look_at(visuals.global_position, Vector3.UP)
	else:
		camera.current = false
		if has_node("Visuals/CameraPivot/Camera3D/AudioListener3D"):
			get_node("Visuals/CameraPivot/Camera3D/AudioListener3D").current = false

	_create_drift_particles("RL")
	_create_drift_particles("RR")
	_create_dirt_particles("RL")
	_create_dirt_particles("RR")

	# Move all car meshes to Visual Layer 2 so they do not receive Decal projections
	# (Decals are configured to only project onto Visual Layer 1)
	_set_layers_recursive(visuals, 2)

	# Trigger spawn-in drop-landing effect at start
	if has_physics_authority():
		is_landing = true
		freeze = false

func _enter_tree():
	_update_authority()
	call_deferred("_update_all_carts_lod")

func _update_authority():
	var id = name.to_int()
	var is_real_player = NetworkManager.players.has(id) and not NetworkManager.players[id].get("is_ai", false)
	
	if id > 0 and is_real_player:
		set_multiplayer_authority(id)
		$MultiplayerSynchronizer.set_multiplayer_authority(id)
	else:
		set_multiplayer_authority(1)
		$MultiplayerSynchronizer.set_multiplayer_authority(1)
		
	if multiplayer.multiplayer_peer != null:
		is_local_player = (id == multiplayer.get_unique_id())
	else:
		is_local_player = not is_ai
	
	if is_local_player:
		contact_monitor = true
		max_contacts_reported = 4
		if not body_entered.is_connected(_on_body_entered):
			body_entered.connect(_on_body_entered)
	
	var has_physics_authority = has_physics_authority()
	if not has_physics_authority:
		freeze = true
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	elif not can_move and not is_landing:
		freeze = true
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC

func _on_body_entered(_body: Node):
	if not is_local_player:
		return
	var speed = linear_velocity.length()
	if speed > 2.0:
		var magnitude = clamp(speed / max_speed, 0.15, 0.8)
		for device in Input.get_connected_joypads():
			Input.start_joy_vibration(device, magnitude * 0.4, magnitude * 0.7, 0.2)

func _process(delta):
	_update_visual_states(delta)
	_update_antenna(delta)
	
	if slow_timer > 0.0:
		if randf() < delta * 6.0:
			_spawn_sparks(global_position + Vector3(randf_range(-0.5, 0.5), randf_range(0.2, 0.8), randf_range(-0.5, 0.5)))
	
	var has_physics_authority = has_physics_authority()
	if has_physics_authority:
		_update_visuals_alignment(delta)
		
	if is_local_player:

		if Input.is_action_just_pressed("toggle_camera"):
			is_isometric = not is_isometric
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			if not is_isometric:
				camera_clip_distance_mult = 1.0
			else:
				camera_clip_distance_mult_iso = 1.0

		if Input.is_action_just_pressed("respawn"):
			respawn_rpc.rpc()

		var visual_forward = -visuals.global_transform.basis.z
		var speed_factor = clamp(linear_velocity.length() / max_speed, 0.0, 1.0)
		var look_ahead_dist = (8.0 + speed_factor * 8.0) if is_isometric else (4.0 + speed_factor * 6.0)

		var excludes = [self.get_rid()]
		var level = get_tree().get_first_node_in_group("level")
		if level:
			for cp in level.checkpoints:
				excludes.append(cp.get_rid())
				for sb in cp.find_children("*", "StaticBody3D", true, false):
					excludes.append(sb.get_rid())
		for cart in get_tree().get_nodes_in_group("player_carts"):
			excludes.append(cart.get_rid())

		if is_intro_active:
			intro_time -= delta
			if intro_time <= 0.0:
				is_intro_active = false
				camera_look_at = visuals.global_position
			else:
				_update_intro_camera(delta)
		
		if not is_intro_active:
			if name_tag:
				name_tag.pixel_size = 0.00035 if is_isometric else 0.00065
				
			if is_isometric:
				var iso_offset = Vector3(-26, 26, 26)
				var target_cam_pos = visuals.global_position + iso_offset
				
				# Avoid clipping through terrain (ignoring other assets like tunnels/trees)
				var target_ratio = 1.0
				var space_state = get_world_3d().direct_space_state
				var ray_start = visuals.global_position + Vector3.UP * 1.0
				
				# Recursive raycast to step past smaller obstacles/collisions to find actual terrain
				var query_start = ray_start
				var current_excludes = excludes.duplicate()
				var hit_terrain = false
				var hit_dist = 0.0
				var max_dist = ray_start.distance_to(target_cam_pos)
				
				for attempt in range(5):
					var query = PhysicsRayQueryParameters3D.create(query_start, target_cam_pos)
					query.exclude = current_excludes
					var result = space_state.intersect_ray(query)
					if not result:
						break
					if result.collider and (result.collider.name.contains("Unified_World_Collision") or result.collider.name.contains("Terrain") or result.collider.name.contains("Static")):
						hit_terrain = true
						hit_dist = ray_start.distance_to(result.position)
						break
					current_excludes.append(result.rid)
					query_start = result.position + (target_cam_pos - query_start).normalized() * 0.1
				
				if hit_terrain and max_dist > 0.01:
					# Keep camera 0.5m in front of terrain collision
					target_ratio = clamp((hit_dist - 0.5) / max_dist, 0.1, 1.0)
				
				# Lerp multiplier: faster to zoom in to avoid clipping, slower to zoom out to prevent jumps
				var lerp_speed = 15.0 if target_ratio < camera_clip_distance_mult_iso else 3.0
				camera_clip_distance_mult_iso = lerp(camera_clip_distance_mult_iso, target_ratio, lerp_speed * delta)
				
				# Position target_cam_pos at the smoothed distance
				target_cam_pos = ray_start + (target_cam_pos - ray_start) * camera_clip_distance_mult_iso
				
				camera_pivot.global_position = camera_pivot.global_position.lerp(target_cam_pos, 10.0 * delta)
				
				# Prevent camera clipping inside/under terrain by checking actual terrain height at camera location
				var cam_actual_pos = camera_pivot.global_position
				var vert_query = PhysicsRayQueryParameters3D.create(cam_actual_pos + Vector3(0, 15, 0), cam_actual_pos + Vector3(0, -15, 0))
				vert_query.exclude = excludes
				var vert_result = space_state.intersect_ray(vert_query)
				var cam_below_terrain = false
				if vert_result and vert_result.collider and (vert_result.collider.name.contains("Unified_World_Collision") or vert_result.collider.name.contains("Terrain")):
					var terrain_y = vert_result.position.y
					if cam_actual_pos.y < terrain_y + 0.5:
						# Push camera up to avoid clipping inside the terrain
						camera_pivot.global_position.y = terrain_y + 0.5
						cam_below_terrain = cam_actual_pos.y < terrain_y # Darken screen if camera is fully below terrain surface
				
				if race_ui:
					race_ui.set_terrain_clipped(cam_below_terrain)
				
				camera_look_at = camera_look_at.lerp(visuals.global_position + visual_forward * look_ahead_dist, 10.0 * delta)
				camera_pivot.look_at(camera_look_at, Vector3.UP)
			else:
				var cam_dist = lerp(3.5, 6.0, clamp(boost_time / 4.0, 0.0, 1.0))
				
				# Smooth camera trailing (steeper and higher)
				var target_cam_pos = visuals.global_position - visual_forward * cam_dist + Vector3(0, 2.4, 0)
				
				# Avoid clipping through terrain (ignoring other assets like tunnels/trees)
				var target_ratio = 1.0
				var space_state = get_world_3d().direct_space_state
				var ray_start = visuals.global_position + Vector3.UP * 1.0
				var query = PhysicsRayQueryParameters3D.create(ray_start, target_cam_pos)
				query.exclude = excludes
				var result = space_state.intersect_ray(query)
				if result and result.collider and (result.collider.name.contains("Unified_World_Collision") or result.collider.name.contains("Terrain")):
					var hit_pos = result.position
					var max_dist = ray_start.distance_to(target_cam_pos)
					if max_dist > 0.01:
						var hit_dist = ray_start.distance_to(hit_pos)
						# Keep camera 0.5m in front of terrain collision
						target_ratio = clamp((hit_dist - 0.5) / max_dist, 0.1, 1.0)
				
				# Lerp multiplier: faster to zoom in to avoid clipping, slower to zoom out to prevent jumps
				var lerp_speed = 15.0 if target_ratio < camera_clip_distance_mult else 3.0
				camera_clip_distance_mult = lerp(camera_clip_distance_mult, target_ratio, lerp_speed * delta)
				
				# Position target_cam_pos at the smoothed distance
				target_cam_pos = ray_start + (target_cam_pos - ray_start) * camera_clip_distance_mult
				
				camera_pivot.global_position = camera_pivot.global_position.lerp(target_cam_pos, 10.0 * delta)
				
				if race_ui:
					race_ui.set_terrain_clipped(false)
				
				camera_look_at = camera_look_at.lerp(visuals.global_position + visual_forward * (look_ahead_dist + 0.5), 12.0 * delta)
				camera_pivot.look_at(camera_look_at, Vector3.UP)
		
		# Smoothly lerp camera FOV based on is_isometric and is_boosting/is_pad_boosting
		var target_fov = 35.0 if is_isometric else 75.0
		if is_boosting:
			target_fov += 10.0 if is_isometric else 15.0 # Zoom out when boosting!
		elif is_pad_boosting:
			target_fov += 6.0 if is_isometric else 9.0 # Zoom out slightly less when pad boosting!
		camera.fov = lerp(camera.fov, target_fov, 8.0 * delta)

		if race_ui:
			smoothed_speed = lerp(smoothed_speed, linear_velocity.length() * 1.8, 10.0 * delta)
			race_ui.update_speed(smoothed_speed)
			
			var cam_underwater = false
			if camera and camera.is_inside_tree():
				cam_underwater = camera.global_position.y < WATER_LEVEL
			race_ui.set_underwater(cam_underwater)

		var throttle_input = Input.get_axis("throttle", "brake")
		var wants_to_play = can_move and not is_exploding and abs(throttle_input) > 0.1
		
		if wants_to_play:
			if not engine_sound.playing:
				engine_sound.play()
				playback = engine_sound.get_stream_playback()
				engine_sound.volume_db = -5.0
			var speed_ratio = clamp(linear_velocity.length() / max_speed, 0.0, 1.0)
			var target_vol = lerp(-5.0, -12.0, speed_ratio)
			engine_sound.volume_db = move_toward(engine_sound.volume_db, target_vol, 80.0 * delta)
			if engine_sound.stream is AudioStreamGenerator and engine_sound.playing:
				_fill_audio_buffer()
		else:
			if engine_sound.playing:
				engine_sound.volume_db = move_toward(engine_sound.volume_db, -45.0, 15.0 * delta)
				if engine_sound.volume_db <= -44.9:
					engine_sound.stop()
					playback = null
				elif engine_sound.stream is AudioStreamGenerator:
					_fill_audio_buffer()
	elif not has_physics_authority:
		_interpolate_remote_visual(delta)

	# Update top-level drift particle emitters to follow their target wheel pivots
	for p in drift_particles:
		if is_instance_valid(p) and p is CPUParticles3D:
			var pivot = p.get_meta("pivot", null)
			if is_instance_valid(pivot):
				p.global_rotation = pivot.global_rotation
				if p.name.ends_with("_Skid"):
					var local_offset = Vector3(0, WHEEL_Y_OFFSET + 0.02, 0)
					p.global_position = pivot.global_position + pivot.global_transform.basis * local_offset
				else:
					p.global_position = pivot.global_position

	for p in dirt_particles:
		if is_instance_valid(p) and p is CPUParticles3D:
			var pivot = p.get_meta("pivot", null)
			if is_instance_valid(pivot):
				p.global_rotation = pivot.global_rotation
				p.global_position = pivot.global_position

func _physics_process(delta):
	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			slow_timer = 0.0

	if hop_cooldown > 0:
		hop_cooldown -= delta

	if is_teleporting:
		return

	if global_position.y < -50:
		if multiplayer.multiplayer_peer != null and multiplayer.is_server():
			respawn_rpc.rpc()
		elif is_local_player or (is_ai and multiplayer.multiplayer_peer == null):
			respawn() # single-player / host fallback

	var has_physics_authority = has_physics_authority()

	# AI Stuck Detection (Checks if distance traveled over 4.0 seconds is less than 3.0 meters)
	if is_ai and can_move and not is_exploding and respawn_indicator_time <= 0.0 and has_physics_authority:
		ai_stuck_position_timer += delta
		if ai_stuck_position_timer >= 4.0:
			ai_stuck_position_timer = 0.0
			var dist = global_position.distance_to(ai_last_stuck_position)
			if dist < 3.0:
				print("AI Cart ", name, " detected stuck (distance traveled in 4s: ", dist, "m). Respawning.")
				if multiplayer.multiplayer_peer != null and multiplayer.is_server():
					respawn_rpc.rpc()
				else:
					respawn()
			ai_last_stuck_position = global_position
	else:
		ai_stuck_position_timer = 0.0
		ai_last_stuck_position = global_position

	if is_exploding:
		if not is_drowned:
			if has_physics_authority:
				apply_central_force(Vector3.UP * 5.0)
			
			if sfx_fire_loop.playing:
				sfx_fire_loop.volume_db = lerp(sfx_fire_loop.volume_db, -10.0, 2.0 * delta)

			burning_particles.global_position = global_position + Vector3(0, 0.5, 0)
			burning_smoke_particles.global_position = global_position + Vector3(0, 0.5, 0)
		
		if has_physics_authority:
			_move_and_sync()
		else:
			_interpolate_remote_physics(delta)
		return

	if stage_has_water:
		# Use hysteresis to prevent rapid underwater state toggling at the boundary
		var entry_threshold = WATER_LEVEL - 0.25
		var exit_threshold = WATER_LEVEL + 0.25
		var currently_underwater = is_underwater
		if is_underwater:
			if global_position.y > exit_threshold:
				currently_underwater = false
		else:
			if global_position.y < entry_threshold:
				currently_underwater = true

		if currently_underwater != is_underwater:
			if currently_underwater:
				# --- Water Impact (Big Splash) ---
				var current_time = Time.get_ticks_msec() / 1000.0
				if current_time - last_splash_time > 0.2:
					last_splash_time = current_time
					
					var impact_speed = linear_velocity.length()
					var splash_stream: AudioStream = null
					if impact_speed > 15.0:
						splash_stream = DEEP_SPLASH_SOUNDS[randi() % DEEP_SPLASH_SOUNDS.size()]
					else:
						splash_stream = REGULAR_SPLASH_SOUNDS[randi() % REGULAR_SPLASH_SOUNDS.size()]
					
					if splash_stream:
						var ap = AudioStreamPlayer3D.new()
						ap.stream = splash_stream
						ap.bus = &"SFX"
						ap.max_distance = 80.0
						ap.unit_size = 15.0
						ap.volume_db = 10.0
						get_tree().current_scene.add_child(ap)
						ap.global_position = global_position
						ap.play()
						get_tree().create_timer(splash_stream.get_length() + 0.5).timeout.connect(ap.queue_free)
						
					# Strong velocity kill simulating hitting dense water
					linear_velocity *= 0.18
					if linear_velocity.y < 0:
						linear_velocity.y = 0.0
					
					var splash_pos = Vector3(global_position.x, WATER_LEVEL, global_position.z)
					_spawn_splash(splash_pos, 1.0)
			else:
				# --- Exit Water (Small Splash) ---
				var current_time = Time.get_ticks_msec() / 1000.0
				last_splash_time = current_time
				var splash_pos = Vector3(global_position.x, WATER_LEVEL, global_position.z)
				_spawn_splash(splash_pos, 0.4) # Spawn a small splash on exit
			is_underwater = currently_underwater
			water_timer = 0.0

		# --- Puddles / Shallow Water periodic small splashes ---
		var on_flat_ground = false
		if ground_ray.is_colliding() and ground_ray.get_collision_normal().y >= 0.55:
			on_flat_ground = true
		if on_flat_ground and not is_underwater and global_position.y >= WATER_LEVEL and global_position.y < WATER_LEVEL + 0.6 and linear_velocity.length() > 3.0:
			var current_time = Time.get_ticks_msec() / 1000.0
			if current_time - last_splash_time > 0.35:
				last_splash_time = current_time
				var splash_pos = Vector3(global_position.x, WATER_LEVEL, global_position.z)
				_spawn_splash(splash_pos, 0.35)

		if is_underwater:
			water_timer += delta
			if water_timer > 0.8: # Drown faster (0.8 seconds underwater triggers drown)
				if multiplayer.multiplayer_peer != null and multiplayer.is_server():
					drown_rpc.rpc()
				elif multiplayer.multiplayer_peer == null:
					drown()
			# Strong water drag: cap horizontal speed and dampen movement heavily
			var underwater_max_speed = max_speed * 0.35
			var h_vel = Vector3(linear_velocity.x, 0, linear_velocity.z)
			if h_vel.length() > underwater_max_speed:
				var damped = h_vel.normalized() * underwater_max_speed
				linear_velocity.x = lerp(linear_velocity.x, damped.x, 8.0 * delta)
				linear_velocity.z = lerp(linear_velocity.z, damped.z, 8.0 * delta)
			# Slow sink: upward buoyancy force (weaker than gravity so car still sinks slowly)
			apply_central_force(Vector3.UP * 15.0)

	if not has_physics_authority:
		_interpolate_remote_physics(delta)
		return

	# Align ground ray with visual orientation so it points along the vehicle's local down axis.
	if is_instance_valid(ground_ray):
		ground_ray.global_transform.basis = visuals.global_transform.basis

	# Apply extra gravity
	apply_central_force(Vector3.DOWN * GRAVITY * mass)

	# Continuous boost timer check for the local player
	if boost_timer > 0.0:
		boost_timer -= delta
		if boost_timer <= 0.0:
			boost_timer = 0.0
	is_boosting = boost_timer > 0.0

	if pad_boost_timer > 0.0:
		pad_boost_timer -= delta
		if pad_boost_timer <= 0.0:
			pad_boost_timer = 0.0
	is_pad_boosting = pad_boost_timer > 0.0

	# Landing detection when dropping from spawn/respawn
	if is_landing and has_physics_authority:
		if ground_ray.is_colliding() and ground_ray.get_collision_normal().y >= 0.55:
			is_landing = false
			# Play landing sound only for gameplay respawns, not during initial start countdown
			if can_move:
				play_landing_sound_rpc(1.5)
			# Freeze if the race hasn't started yet
			if not can_move:
				freeze = true
				freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC

	if not can_move and not is_landing:
		linear_velocity = linear_velocity.lerp(Vector3.ZERO, 3.0 * delta)
		_move_and_sync()
		return

	if is_local_player:
		if Input.is_action_just_pressed("boost"):
			_use_item()
		if Input.is_action_just_pressed("discard_item"):
			_discard_item()

	var input_dir = Vector2.ZERO
	if can_move:
		if is_ai:
			input_dir = _get_ai_input(delta)
			_process_ai_items(delta)
		else:
			input_dir.x = Input.get_axis("steer_left", "steer_right")
			input_dir.y = Input.get_axis("throttle", "brake")

	var on_ground = false
	var ground_normal = Vector3.UP
	if ground_ray.is_colliding():
		var norm = ground_ray.get_collision_normal()
		if norm.y >= 0.55:
			on_ground = true
			ground_normal = norm

	if not on_ground:
		air_time += delta
	else:
		if not was_on_ground:
			var time_since_respawn = (Time.get_ticks_msec() / 1000.0) - last_respawn_time
			if time_since_respawn < 1.0 or ignore_next_landing_sound:
				ignore_next_landing_sound = false
			else:
				play_landing_sound_rpc.rpc(air_time)
		air_time = 0.0
	was_on_ground = on_ground

	is_offroad = false
	if on_ground:
		var collider = ground_ray.get_collider()
		if collider and (collider.name.contains("Unified_World_Collision") or collider.name.contains("Terrain")):
			is_offroad = true

	if is_offroad:
		offroad_timer += delta
		if offroad_timer > 0.15:
			offroad_timer = 0.0
			# Offroad capability strength determines offroad penalty
			var preset = CAR_PRESETS[car_index]
			var offroad_stat = preset.get("offroad", 5.0)
			var offroad_factor = clamp((offroad_stat - 1.0) / 9.0, 0.0, 1.0)
			var penalty_min = lerp(0.55, 0.96, offroad_factor)
			var penalty_max = lerp(0.65, 1.00, offroad_factor)
			offroad_target_penalty = randf_range(penalty_min, penalty_max)
		offroad_penalty = lerp(offroad_penalty, offroad_target_penalty, 5.0 * delta)
	else:
		offroad_penalty = lerp(offroad_penalty, 1.0, 10.0 * delta)

	var fwd = -visuals.global_transform.basis.z
	var right = visuals.global_transform.basis.x

	current_steer = lerp(current_steer, input_dir.x, 10.0 * delta)

	# Handle acceleration/braking even when slightly airborne for better control
	var current_speed = linear_velocity.dot(fwd)

	# Tap-to-drift logic (evaluate early so drift_mode is active during the braking/physics forces block)
	if on_ground and Input.is_action_just_pressed("brake") and abs(input_dir.x) > 0.2 and current_speed > 5.0:
		drift_mode = true
		drift_right = input_dir.x > 0.0

	# Auto-hop over small obstacles/bumps
	if on_ground and input_dir.y < -0.1 and linear_velocity.length() < 15.0 and hop_cooldown <= 0.0:
		var space_state = get_world_3d().direct_space_state
		var ray_start = global_position + fwd * 0.5 + Vector3.UP * 0.1
		var ray_end = global_position + fwd * 1.1 - Vector3.UP * 0.1
		var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
		query.exclude = [self.get_rid()]
		var result = space_state.intersect_ray(query)
		if result:
			var local_hit = global_transform.inverse() * result.position
			# If obstacle is low (below bumper/axle height), jump over it
			if local_hit.y > -0.5 and local_hit.y < 0.1:
				apply_central_impulse(Vector3.UP * 4.5 * mass + fwd * 2.0 * mass)
				hop_cooldown = 0.8 # Cooldown to prevent double jumps

	var slow_mult = 1.0
	if slow_timer > 0.0:
		slow_mult = 0.6

	if is_boosting:
		var max_sp = max_speed * 1.5 * slow_mult
		var accel_force = acceleration * 2.0 * slow_mult
		if is_offroad and on_ground and ground_normal.y < 0.85 and fwd.dot(Vector3.UP) > 0.05:
			accel_force = 0.0
		if current_speed < max_sp:
			apply_central_force(fwd * accel_force * mass)
		boost_time += delta
	elif is_pad_boosting:
		# Pad boost: faster (closer to the boost item)
		var max_sp = max_speed * 1.4 * slow_mult
		var accel_force = acceleration * 1.8 * slow_mult
		if is_offroad and on_ground and ground_normal.y < 0.85 and fwd.dot(Vector3.UP) > 0.05:
			accel_force = 0.0
		if current_speed < max_sp:
			apply_central_force(fwd * accel_force * mass)
		boost_time += delta
	
	if input_dir.y < -0.1: # Forward input
		if not is_boosting:
			var input_scale = abs(input_dir.y)
			var accel_force = acceleration * slow_mult * input_scale
			if is_offroad and on_ground and ground_normal.y < 0.85 and fwd.dot(Vector3.UP) > 0.05:
				accel_force = 0.0
			if current_speed < max_speed * offroad_penalty * slow_mult * input_scale:
				apply_central_force(fwd * accel_force * mass)
			boost_time += delta
	elif input_dir.y > 0.1: # Brake / Reverse input
		boost_time = 0.0
		var input_scale = abs(input_dir.y)
		if not on_ground:
			# Ignore braking and reversing while airborne
			pass
		elif is_boosting:
			# If boosting, braking just reduces the boost effectiveness a bit
			apply_central_force(-fwd * braking * 0.5 * mass * input_scale)
		elif drift_mode:
			# If drifting, preserve forward momentum by not applying heavy brakes
			var speed_ratio = clamp(linear_velocity.length() / max_speed, 0.0, 1.0)
			if speed_ratio < 0.85:
				apply_central_force(fwd * acceleration * 0.8 * mass * input_scale)
			else:
				apply_central_force(fwd * acceleration * 0.3 * mass * input_scale)
		else:
			if current_speed > 1.0:
				apply_central_force(-fwd * braking * mass * input_scale)
			elif current_speed < -0.5:
				if current_speed > -reverse_speed * offroad_penalty * input_scale:
					var accel_force = acceleration * 0.5 * input_scale
					if is_offroad and on_ground and ground_normal.y < 0.85 and (-fwd).dot(Vector3.UP) > 0.05:
						accel_force = 0.0
					apply_central_force(-fwd * accel_force * mass)
			else:
				if current_speed > -reverse_speed * offroad_penalty * input_scale:
					var accel_force = acceleration * 0.7 * input_scale
					if is_offroad and on_ground and ground_normal.y < 0.85 and (-fwd).dot(Vector3.UP) > 0.05:
						accel_force = 0.0
					apply_central_force(-fwd * accel_force * mass)
	else: # No throttle/brake input (coasting or stationary)
		if not is_boosting:
			boost_time = 0.0
			is_boosting = false
			if sfx_rocket_loop.playing: sfx_rocket_loop.stop()
			if drift_mode:
				# Keep forward speed by offsetting friction/drag to preserve momentum
				apply_central_force(fwd * acceleration * 0.45 * mass)
			else:
				if linear_velocity.length() < 0.3:
					linear_velocity = Vector3.ZERO
				else:
					apply_central_force(-linear_velocity * 0.5 * mass)

	# Steering (works on ground and slightly airborne)
	if on_ground or linear_velocity.length() > 0.5:
		if linear_velocity.length() > 1.0:
			# Exit drift mode if:
			# - they release brake (input_dir.y < 0.1)
			# - car comes to a stop (current_speed < 3.0)
			if drift_mode:
				if input_dir.y < 0.1 or current_speed < 3.0:
					drift_mode = false
			
			var turn_speed = steer_speed
			is_drifting = drift_mode
			
			var play_brake_sfx = on_ground and (is_drifting or (input_dir.y > 0.2 and current_speed > 5.0))
			if play_brake_sfx:
				if not sfx_brake_drift.playing: sfx_brake_drift.play()
			else:
				if sfx_brake_drift.playing: sfx_brake_drift.stop()
			
			if is_drifting:
				turn_speed *= 1.8 # Tighter turn
			
			var steer_amount = -current_steer * turn_speed * (min(linear_velocity.length() / 10.0, 1.0)) * delta
			visuals.global_rotate(ground_normal, steer_amount)
			
			# Kill lateral velocity (adds grip)
			var lat_vel = linear_velocity.dot(right)
			var grip_factor = grip
			if is_drifting: grip_factor *= 0.22 # Low grip factor for sliding momentum
			if is_offroad and on_ground and ground_normal.y < 0.85:
				# Scale grip down as the slope gets steeper, causing the cart to slide down cliffs/steep hills
				var slope_factor = clamp((ground_normal.y - 0.5) / (0.85 - 0.5), 0.0, 1.0)
				grip_factor *= slope_factor
			apply_central_force(-right * lat_vel * mass * grip_factor)
			
			# Emit skidmark and smoke particles when drifting or braking (only on ground)
			var emit_drift = on_ground and (is_drifting or (input_dir.y > 0.2 and current_speed > 5.0))
			_set_drift_emitting(emit_drift)
			sync_emit_drift = emit_drift
	else:
		is_boosting = false
		if sfx_rocket_loop.playing: sfx_rocket_loop.stop()
		if sfx_brake_drift.playing: sfx_brake_drift.stop()
		is_drifting = false
		_set_drift_emitting(false)
		sync_emit_drift = false
		
		# Slight air control
		visuals.global_rotate(Vector3.UP, -current_steer * steer_speed * 0.5 * delta)

	# Wind sound (only while airborne)
	if not on_ground and linear_velocity.length() > 5.0:
		if not sfx_wind_loop.playing:
			sfx_wind_loop.play()
		sfx_wind_loop.volume_db = lerp(sfx_wind_loop.volume_db, -10.0, 2.0 * delta)
	else:
		sfx_wind_loop.volume_db = lerp(sfx_wind_loop.volume_db, -40.0, 5.0 * delta)
		if sfx_wind_loop.volume_db < -35.0:
			sfx_wind_loop.stop()

	# Dampen speed if exceeding offroad max speed
	var effective_max = max_speed * offroad_penalty * slow_mult
	if on_ground and not is_boosting and current_speed > effective_max:
		var excess_ratio = (current_speed - effective_max) / max_speed
		apply_central_force(-fwd * excess_ratio * acceleration * 8.0 * mass)

	# Emit dirt particles when offroad and moving
	var emit_dirt = is_offroad and on_ground and linear_velocity.length() > 2.0
	_set_dirt_emitting(emit_dirt)
	sync_emit_dirt = emit_dirt

	sync_steer = current_steer
	_move_and_sync()

func _get_ground_visual_offset() -> float:
	if not is_instance_valid(ground_ray):
		return 0.0
	
	# Align ground ray with visual orientation so it points along the vehicle's local down axis.
	ground_ray.global_transform.basis = visuals.global_transform.basis
	# Force immediate raycast update to get accurate collision info
	ground_ray.force_raycast_update()
	if ground_ray.is_colliding():
		var contact_normal = ground_ray.get_collision_normal()
		if contact_normal.y >= 0.55:
			var contact_pt = ground_ray.get_collision_point()
			var current_height_normal = (global_position - contact_pt).dot(contact_normal)
			
			# Mathematically align wheels to ground: offset visuals relative to body center
			var target_offset = current_height_normal + (avg_wheel_y - 0.24)
			# Clamp to prevent extreme visual displacement during severe physics bounces
			return clamp(target_offset, -0.6, 0.6)
	
	# Default visual offset in air (keeps wheels at their resting position)
	return COLLISION_RADIUS + (avg_wheel_y - 0.24)

func _update_visuals_alignment(delta):
	if is_exploding:
		if is_drowned:
			# While fading out underwater, keep the visual's current orientation.
			# (Don't copy the physics body's locked/upright transform, which would snap
			# the car to a default pose and ignore where it actually landed.)
			visuals.global_position = global_position
			return
		# Normal explosion: body parts fly, so follow the physics transform
		visuals.global_transform = global_transform
		return

	# Align ground ray with visual orientation so it points along the vehicle's local down axis.
	if is_instance_valid(ground_ray):
		ground_ray.global_transform.basis = visuals.global_transform.basis

	var on_ground = false
	var target_up = Vector3.UP
	
	# Perform auxiliary front/rear raycasts to handle ramps and uneven terrain
	var normals: Array[Vector3] = []
	var res_front = null
	var res_rear = null
	var space_state = get_world_3d().direct_space_state
	if space_state and visuals:
		var excludes = [self.get_rid()]
		var fwd_dir = -visuals.global_transform.basis.z.normalized()
		
		# Cast from above the cart center to well below to prevent starting inside rising ramp surfaces
		var front_origin = global_position + fwd_dir * 1.0 + Vector3.UP * 1.5
		var rear_origin = global_position - fwd_dir * 1.0 + Vector3.UP * 1.5
		var down_vec = Vector3.DOWN * 3.5
		
		var query_front = PhysicsRayQueryParameters3D.create(front_origin, front_origin + down_vec)
		query_front.exclude = excludes
		query_front.collision_mask = 1 # road/terrain/ramp
		res_front = space_state.intersect_ray(query_front)
		if res_front and res_front.normal.y >= 0.45:
			normals.append(res_front.normal)
			
		var query_rear = PhysicsRayQueryParameters3D.create(rear_origin, rear_origin + down_vec)
		query_rear.exclude = excludes
		query_rear.collision_mask = 1
		res_rear = space_state.intersect_ray(query_rear)
		if res_rear and res_rear.normal.y >= 0.45:
			normals.append(res_rear.normal)
			
	if ground_ray.is_colliding():
		var norm = ground_ray.get_collision_normal()
		if norm.y >= 0.55:
			normals.append(norm)
			
	if not normals.is_empty():
		on_ground = true
		var sum = Vector3.ZERO
		for n in normals:
			sum += n
		target_up = (sum / normals.size()).normalized()
		
	if not on_ground:
		# If in air or on a steep wall/curb, slowly return to global UP instead of snapping
		target_up = visuals.global_transform.basis.y.lerp(Vector3.UP, 1.0 - exp(-2.0 * delta)).normalized()
		
	# Smoothly align the visual mesh normal
	var current_basis = visuals.global_transform.basis
	var forward = -current_basis.z
	var right = current_basis.x
 
	var target_right = Vector3.ZERO
	var target_forward = Vector3.ZERO
	
	var has_two_points = false
	if res_front and res_rear:
		if res_front.normal.y >= 0.45 and res_rear.normal.y >= 0.45:
			var front_pt = res_front.position
			var rear_pt = res_rear.position
			var slope_fwd = (front_pt - rear_pt).normalized()
			
			# Use the slope vector to determine exact pitch
			target_forward = slope_fwd
			target_right = target_forward.cross(target_up).normalized()
			target_up = target_right.cross(target_forward).normalized()
			has_two_points = true
			
	if not has_two_points:
		# Fallback to normal-only alignment
		target_right = forward.cross(target_up).normalized()
		target_forward = target_up.cross(target_right).normalized()
 
	var target_basis = Basis(target_right, target_up, -target_forward)
	if is_drifting:
		var drift_angle = -0.35 if drift_right else 0.35
		target_basis = target_basis.rotated(target_up, drift_angle)
	visuals.global_transform.basis = current_basis.slerp(target_basis, 1.0 - exp(-8.0 * delta))
 
	var target_offset = _get_ground_visual_offset()
	visual_offset_y = lerp(visual_offset_y, target_offset, 1.0 - exp(-10.0 * delta))
	var target_pos = get_global_transform_interpolated().origin - target_up * visual_offset_y
 
	# Align visuals position directly to eliminate visual lag/pulsing
	visuals.global_position = target_pos

	_update_wheel_visuals(delta)

func _fill_audio_buffer():
	if not playback: return
	var available = playback.get_frames_available()
	if available == 0: return

	# Electric RC motor frequency mapping - made less high-pitched (deeper base and slower rise)
	# Add organic frequency fluctuation (LFO)
	var fluctuation = sin(Time.get_ticks_msec() * 0.03) * 1.5
	var freq = 80.0 + linear_velocity.length() * 12.0 + fluctuation
	if is_boosting: freq *= 1.4
	elif is_pad_boosting: freq *= 1.25

	# Fade out high harmonics at high speeds to avoid harsh whines
	var speed_ratio = clamp(linear_velocity.length() / max_speed, 0.0, 1.0)
	var high_harmonic_fade = clamp(1.0 - speed_ratio * 0.85, 0.15, 1.0)

	for i in range(available):
		engine_phase += freq / sample_rate
		if engine_phase > 1.0:
			engine_phase -= 1.0
		
		# Electric RC motor sound: high pitch whine + sub-harmonic for deep rumble + harmonics
		var sample = sin(engine_phase * TAU) * 0.25
		sample += sin(engine_phase * 0.5 * TAU) * 0.15 # Deep sub-harmonic rumble
		sample += sin(engine_phase * 2.0 * TAU) * 0.10 * high_harmonic_fade
		sample += sin(engine_phase * 3.0 * TAU) * 0.05 * high_harmonic_fade
		playback.push_frame(Vector2(sample, sample))

func _update_wheel_visuals(delta):
	if is_exploding: return
	var speed = linear_velocity.length()
	var fwd_dot = linear_velocity.dot(-visuals.global_transform.basis.z)
	var rot_speed = speed * sign(fwd_dot) / 0.4 # approx radius
	wheel_rotation -= rot_speed * delta

	for wheel in ["FL", "FR", "RL", "RR"]:
		var pivot = get_node_or_null("Visuals/WheelPivot" + wheel)
		if not pivot:
			continue
		# Steering: rotate the pivot on its Y axis for front wheels
		if wheel == "FL" or wheel == "FR":
			var steer_direction = 1.0 if fwd_dot >= -1.0 else -1.0
			pivot.rotation.y = -sync_steer * 0.5 * steer_direction
		# Spin: find the wheel mesh child and rotate on its X axis
		var mesh_node = pivot.get_node_or_null("WheelMesh")
		if mesh_node:
			mesh_node.rotation.x = wheel_rotation

func _interpolate_remote_physics(delta: float):
	var t = 1.0 - exp(-REMOTE_LERP_SPEED * delta)
	global_position = global_position.lerp(sync_position, t)

	var current_quat := Quaternion.from_euler(rotation)
	var target_quat := sync_rotation_quat
	if target_quat == Quaternion.IDENTITY:
		target_quat = Quaternion.from_euler(sync_rotation)

	var rot_t = 1.0 - exp(-REMOTE_LERP_SPEED * 0.65 * delta)
	var new_quat := current_quat.slerp(target_quat, rot_t)
	rotation = new_quat.get_euler()

	linear_velocity = linear_velocity.lerp(sync_velocity, 0.6)

func _interpolate_remote_visual(delta: float):
	if is_exploding:
		visuals.global_transform = global_transform
		return

	var target_quat := sync_rotation_quat
	if target_quat == Quaternion.IDENTITY:
		target_quat = Quaternion.from_euler(sync_rotation)

	# Smoothly follow visual rotation to prevent remote visual jittering at high refresh rates
	var current_visual_quat: Quaternion = visuals.global_transform.basis.get_rotation_quaternion()
	var rot_t = 1.0 - exp(-REMOTE_LERP_SPEED * 0.65 * delta)
	var new_visual_quat: Quaternion = current_visual_quat.slerp(target_quat, rot_t)
	
	visuals.global_transform.basis = Basis(new_visual_quat)
	var target_up = visuals.global_transform.basis.y.normalized()
	var target_offset = _get_ground_visual_offset()
	visual_offset_y = lerp(visual_offset_y, target_offset, 1.0 - exp(-10.0 * delta))
	var target_pos = get_global_transform_interpolated().origin - target_up * visual_offset_y

	# Align visuals position directly to eliminate visual lag/pulsing
	visuals.global_position = target_pos

	var speed := sync_velocity.length()
	var wheel_spin_rate := speed / 0.4
	wheel_rotation -= wheel_spin_rate * delta

	var remote_fwd_dot = sync_velocity.dot(-visuals.global_transform.basis.z)
	var steer_direction = 1.0 if remote_fwd_dot >= -1.0 else -1.0

	for wheel in ["FL", "FR", "RL", "RR"]:
		var pivot = get_node_or_null("Visuals/WheelPivot" + wheel)
		if not pivot:
			continue
		if wheel == "FL" or wheel == "FR":
			pivot.rotation.y = -sync_steer * 0.5 * steer_direction
		var mesh_node = pivot.get_node_or_null("WheelMesh")
		if mesh_node:
			mesh_node.rotation.x = wheel_rotation

	# Visual particle/sound effects for remote player carts
	_set_drift_emitting(sync_emit_drift)
	_set_dirt_emitting(sync_emit_dirt)
	if sync_emit_drift:
		if not sfx_brake_drift.playing:
			sfx_brake_drift.play()
	else:
		if sfx_brake_drift.playing:
			sfx_brake_drift.stop()

func _setup_new_car_wheels():
	var cart_model = get_node_or_null("Visuals/CartModel")
	if not cart_model:
		return
	
	var preset = CAR_PRESETS[car_index]
	var wheel_parts: Dictionary = preset.get("wheel_parts", {})
	
	for corner in ["FL", "FR", "RL", "RR"]:
		var pivot = get_node_or_null("Visuals/WheelPivot" + corner)
		if not pivot:
			continue
		
		# Free old GLB wheel children (the wheel.glb instances placed in the scene file)
		for old_child in pivot.get_children():
			old_child.queue_free()
		
		var part_name: String = wheel_parts.get(corner, "")
		if part_name.is_empty():
			continue
		
		# Find the wheel part node inside the loaded FBX model
		var wheel_part = cart_model.get_node_or_null(part_name)
		if not wheel_part:
			wheel_part = _find_node_by_name(cart_model, part_name)
		if not wheel_part:
			print("PlayerCart: could not find wheel part '", part_name, "' for corner ", corner)
			continue
		
		# FBX parts often have their node ORIGIN at the scene root (0,0,0),
		# not at the wheel's visual center. Using wheel_part.global_position would
		# place the pivot at the car center, causing the wheel mesh to orbit wildly.
		# Instead we compute the true visual center via the mesh geometry's AABB.
		var wheel_center = _get_mesh_aabb_world_center(wheel_part)
		
		# Move the WheelPivot to the wheel's true visual center so steering and
		# spin both happen around the correct axis.
		pivot.global_position = wheel_center
		
		# Create a WheelMesh container — _update_wheel_visuals rotates THIS for spinning.
		# Because WheelMesh sits at wheel_center (= pivot origin), and the wheel geometry
		# is also centered at wheel_center in WheelMesh local space, rotating
		# WheelMesh.rotation.x spins the mesh in place.
		var wheel_mesh_node = Node3D.new()
		wheel_mesh_node.name = "WheelMesh"
		pivot.add_child(wheel_mesh_node)
		
		# Reparent the actual FBX wheel part into WheelMesh, keeping world transform.
		wheel_part.reparent(wheel_mesh_node, true)
		
		# Override the wheel material to remove baked lighting from the rubber texture.
		_apply_wheel_material(wheel_part)

	original_wheel_transforms.clear()
	for corner in ["FL", "FR", "RL", "RR"]:
		var pivot = get_node_or_null("Visuals/WheelPivot" + corner)
		if pivot:
			original_wheel_transforms[corner] = pivot.transform

	# Calculate average wheel local Y position relative to Visuals origin
	var wheel_y_sum = 0.0
	var wheel_count = 0
	for corner in ["FL", "FR", "RL", "RR"]:
		var pivot = get_node_or_null("Visuals/WheelPivot" + corner)
		if pivot:
			wheel_y_sum += pivot.position.y
			wheel_count += 1
	if wheel_count > 0:
		avg_wheel_y = wheel_y_sum / wheel_count
	else:
		avg_wheel_y = -0.02

	if cart_model:
		original_cart_model_transform = cart_model.transform

func _apply_wheel_material(node: Node):
	if node is MeshInstance3D:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.08, 0.08, 0.08)
		mat.roughness = 0.9
		mat.metallic = 0.0
		node.material_override = mat
	for child in node.get_children():
		_apply_wheel_material(child)

# Computes the world-space center of all mesh geometry under a node tree.
# This is the correct spin pivot for FBX parts whose node origin may be at scene root.
func _get_mesh_aabb_world_center(node: Node) -> Vector3:
	var centers: Array = []
	_collect_mesh_world_centers(node, centers)
	if centers.is_empty():
		return node.global_position  # fallback if no meshes found
	var sum = Vector3.ZERO
	for c in centers:
		sum += c
	return sum / centers.size()

func _collect_mesh_world_centers(node: Node, centers: Array):
	if node is MeshInstance3D:
		# get_aabb() returns local-space AABB; transform center to world space
		var local_center: Vector3 = node.get_aabb().get_center()
		centers.append(node.global_transform * local_center)
	for child in node.get_children():
		_collect_mesh_world_centers(child, centers)


func _move_and_sync():
	sync_position = global_position
	# Store visual rotation, not rigid body rotation (which is locked)
	sync_rotation = visuals.rotation
	sync_velocity = linear_velocity
	sync_rotation_quat = Quaternion.from_euler(visuals.rotation)

func _use_item():
	if current_item == ItemType.NONE: return
	var item_to_use = current_item
	
	# Shift backup item to active slot
	current_item = current_item_2
	current_item_2 = ItemType.NONE
	
	if is_local_player and race_ui:
		var item1_name = ItemType.keys()[current_item]
		var item2_name = ItemType.keys()[current_item_2]
		race_ui.update_items(item1_name, item2_name)
	
	if is_ai or multiplayer.multiplayer_peer == null or multiplayer.is_server():
		_execute_use_item(item_to_use)
	else:
		request_use_item.rpc_id(1, item_to_use)

func _discard_item():
	if current_item == ItemType.NONE: return
	
	# Shift backup item to active slot
	current_item = current_item_2
	current_item_2 = ItemType.NONE
	
	if is_local_player and race_ui:
		var item1_name = ItemType.keys()[current_item]
		var item2_name = ItemType.keys()[current_item_2]
		race_ui.update_items(item1_name, item2_name)

@rpc("any_peer", "call_local", "reliable")
func request_use_item(item_to_use: int):
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server(): return
	_execute_use_item(item_to_use)

func _execute_use_item(type: int):
	match type:
		ItemType.BOOST:
			var is_real_peer = name.to_int() > 0 and not is_ai
			if is_real_peer:
				client_start_boost.rpc_id(name.to_int())
			else:
				client_start_boost()
		ItemType.MISSILE:
			_fire_missile(false)
		ItemType.GUIDED_MISSILE:
			_fire_missile(true)
		ItemType.SHIELD:
			var is_real_peer = name.to_int() > 0 and not is_ai
			if is_real_peer:
				client_start_shield.rpc_id(name.to_int())
			else:
				client_start_shield()
		ItemType.SHOCKWAVE:
			_activate_shockwave()
		ItemType.BOMB:
			_drop_bomb()
		ItemType.LIGHTNING:
			_activate_lightning()

@rpc("any_peer", "call_local", "unreliable")
func play_landing_sound_rpc(p_air_time: float):
	if LANDING_SOUNDS.is_empty(): return
	var sound = LANDING_SOUNDS[randi() % LANDING_SOUNDS.size()]
	sfx_landing_bonk.stream = sound
	# Map air_time to volume_db [-14.0, 4.0] (cap air_time at 1.0 second)
	var volume = lerp(-14.0, 4.0, clamp(p_air_time / 1.0, 0.0, 1.0))
	sfx_landing_bonk.volume_db = volume
	sfx_landing_bonk.play()

@rpc("any_peer", "call_local", "reliable")
func client_start_boost():
	boost_timer = 2.0
	is_boosting = true
	sfx_nitro_start.play()
	boost_particles.emitting = true

@rpc("any_peer", "call_local", "reliable")
func client_start_pad_boost():
	pad_boost_timer = 2.0
	is_pad_boosting = true
	
	# Play swoosh sound (stereogenicstudio-swish-swoosh-woosh-sfx-47-357152.mp3)
	var ap = AudioStreamPlayer3D.new()
	ap.stream = preload("res://sounds/stereogenicstudio-swish-swoosh-woosh-sfx-47-357152.mp3")
	ap.bus = &"SFX"
	ap.volume_db = 0.0
	ap.unit_size = 20.0
	$Visuals.add_child(ap)
	ap.play()
	ap.finished.connect(ap.queue_free)

@rpc("any_peer", "call_local", "reliable")
func client_start_shield():
	_activate_shield()

@rpc("any_peer", "call_local", "reliable")
func client_break_shield():
	is_shielded = false
	shield_mesh.visible = false
	shield_mesh.scale = Vector3.ONE

func _update_visual_states(delta):
	# Sync shield visual and audio
	if shield_mesh.visible != is_shielded:
		shield_mesh.visible = is_shielded
		if not is_shielded:
			shield_mesh.scale = Vector3.ONE
	
	if not is_shielded:
		if sfx_shield_loop.playing:
			sfx_shield_loop.stop()
	
	if is_shielded:
		var time = Time.get_ticks_msec() * 0.001
		# Buzzing scale oscillation
		var scale_osc = 1.0 + 0.04 * sin(time * 25.0) + 0.015 * cos(time * 47.0)
		shield_mesh.scale = Vector3(scale_osc, scale_osc, scale_osc)
		
		# Modulate the duplicated material
		var mat = shield_mesh.material_override as StandardMaterial3D
		if mat:
			var alpha_osc = 0.35 + 0.15 * sin(time * 35.0)
			mat.albedo_color.a = alpha_osc
			
			var energy_osc = 1.2 + 0.4 * sin(time * 30.0) + 0.2 * cos(time * 60.0)
			mat.emission_energy_multiplier = energy_osc

		# Play and modulate shield sound — deep low hum with very slow wobble
		if not sfx_shield_loop.playing:
			sfx_shield_loop.play()
		sfx_shield_loop.pitch_scale = 0.28 + 0.04 * sin(time * 2.5)
		sfx_shield_loop.volume_db = 4.0 + 1.5 * cos(time * 3.0)
	
	# Explosion visual details (parts physics and fade out)
	if is_exploding:
		explosion_time += delta
		if not is_drowned:
			# Simulate parts physics locally
			for part in part_velocities.keys():
				if is_instance_valid(part):
					if part_on_ground.get(part, false):
						continue
						
					part_velocities[part].y -= 9.8 * delta # gravity
					part.position += part_velocities[part] * delta
					
					var ground_y = _get_ground_height(part.global_position)
					if ground_y != -999.0 and part.global_position.y <= ground_y:
						part_on_ground[part] = true
						part_velocities[part] = Vector3.ZERO
						part_rotations[part] = Vector3.ZERO
						var g_target = part.global_position
						g_target.y = ground_y
						part.global_position = g_target
					else:
						part.rotate_x(part_rotations[part].x * delta)
						part.rotate_y(part_rotations[part].y * delta)
						part.rotate_z(part_rotations[part].z * delta)
			
			# Fade out in the last second
			if explosion_time > 2.0:
				var alpha = clamp(1.0 - (explosion_time - 2.0), 0.0, 1.0)
				_set_visuals_alpha(alpha)
				if name_tag:
					name_tag.modulate.a = alpha
	else:
		if explosion_time > 0.0:
			# Reset explosion/drown visuals when transitioning from exploding -> not exploding
			explosion_time = 0.0
			is_drowned = false
			if _drown_tween:
				_drown_tween.kill()
				_drown_tween = null
			visuals.visible = true
			_set_visuals_alpha(1.0)
			if name_tag:
				name_tag.modulate.a = 1.0
			# Restore scattered wheel/part transforms
			for corner in original_wheel_transforms.keys():
				var pivot = get_node_or_null("Visuals/WheelPivot" + corner)
				if pivot:
					pivot.transform = original_wheel_transforms[corner]
			for child in original_body_part_transforms.keys():
				if is_instance_valid(child):
					child.transform = original_body_part_transforms[child]
			part_velocities.clear()
			part_rotations.clear()
			part_on_ground.clear()
			original_body_part_transforms.clear()

	# Respawn blinking indicator
	if respawn_indicator_time > 0.0:
		respawn_indicator_time -= delta
		if respawn_indicator_time <= 0.0:
			respawn_indicator_time = 0.0
			_set_visuals_respawn_effect(false, false)
		else:
			var blink_on = int(respawn_indicator_time / 0.06) % 2 == 0
			_set_visuals_respawn_effect(true, blink_on)

	# Shock blinking / blue tinting indicator
	if slow_timer > 0.0:
		was_shocked = true
		var blink_on = int(slow_timer / 0.1) % 2 == 0
		_set_visuals_shock_effect(true, blink_on)
	elif was_shocked:
		was_shocked = false
		_set_visuals_shock_effect(false, false)

	# Sync boost particles
	if boost_particles.emitting != is_boosting:
		boost_particles.emitting = is_boosting
		
	# Sync rocket sound
	if is_boosting:
		if not sfx_rocket_loop.playing:
			sfx_rocket_loop.play()
	else:
		if sfx_rocket_loop.playing:
			sfx_rocket_loop.stop()

func on_hit(attacker_id: int = 0):
	if is_shielded:
		is_shielded = false
		var is_real_peer = name.to_int() > 0 and not get("is_ai")
		if multiplayer.multiplayer_peer != null and multiplayer.is_server() and is_real_peer:
			client_break_shield.rpc_id(name.to_int())
		else:
			shield_mesh.visible = false
			shield_mesh.scale = Vector3.ONE
		return
	# Server triggers the explosion for all clients
	if multiplayer.multiplayer_peer != null and multiplayer.is_server():
		explode_rpc.rpc(attacker_id)
	else:
		explode(attacker_id) # fallback for local-only / single-player

@rpc("any_peer", "call_local", "reliable")
func explode_rpc(attacker_id: int = 0):
	explode(attacker_id)

func explode(attacker_id: int = 0):
	if is_exploding: return
	is_exploding = true
	can_move = false
	is_drowned = false
	explosion_time = 0.0
	
	if attacker_id > 0:
		var attacker_name = "Someone"
		var found_attacker = false
		for c in get_tree().get_nodes_in_group("player_carts"):
			if c.name.to_int() == attacker_id:
				attacker_name = c.player_name
				found_attacker = true
				break
		
		var msg = ""
		if attacker_id == name.to_int():
			msg = "%s blew themselves up!" % player_name
		else:
			msg = "%s blew up %s!" % [attacker_name, player_name]
			
		var local_cart = null
		for c in get_tree().get_nodes_in_group("player_carts"):
			if c.is_local_player:
				local_cart = c
				break
		if local_cart and local_cart.race_ui:
			local_cart.race_ui.show_message(msg, 2.5)
	
	# Play a random bomb explosion sound
	var selected_bomb_sound = BOMB_EXPLOSION_SOUNDS[randi() % BOMB_EXPLOSION_SOUNDS.size()]
	sfx_explosion.stream = selected_bomb_sound
	sfx_explosion.play()
	sfx_fire_loop.play()
	explosion_particles.emitting = true
	burning_particles.emitting = true
	burning_smoke_particles.emitting = true
	fire_sprite_particles.emitting = true
	fire_sprite_particles_2.emitting = true
	if engine_sound.playing: engine_sound.stop()
	
	visuals.visible = true
	_set_visuals_alpha(1.0)
	if name_tag:
		name_tag.modulate.a = 1.0
		
	if is_local_player:
		linear_velocity += Vector3(randf()-0.5, 10.0, randf()-0.5).normalized() * 15.0
		angular_velocity = Vector3(
			randf_range(-10.0, 10.0),
			randf_range(-5.0, 5.0),
			randf_range(-10.0, 10.0)
		)
		for device in Input.get_connected_joypads():
			Input.start_joy_vibration(device, 0.6, 0.9, 0.5)
		
	# Setup disintegrating parts
	part_velocities.clear()
	part_rotations.clear()
	part_on_ground.clear()
	original_body_part_transforms.clear()
	
	for corner in ["FL", "FR", "RL", "RR"]:
		var pivot = get_node_or_null("Visuals/WheelPivot" + corner)
		if pivot:
			var dir = Vector3.ZERO
			match corner:
				"FL": dir = Vector3(1.0, 1.2, 1.0)
				"FR": dir = Vector3(-1.0, 1.2, 1.0)
				"RL": dir = Vector3(1.0, 1.2, -1.0)
				"RR": dir = Vector3(-1.0, 1.2, -1.0)
			dir = (dir + Vector3(randf_range(-0.5, 0.5), randf_range(-0.2, 0.4), randf_range(-0.5, 0.5))).normalized()
			part_velocities[pivot] = dir * randf_range(5.0, 9.0)
			part_rotations[pivot] = Vector3(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
			
	var cart_model = get_node_or_null("Visuals/CartModel")
	if cart_model:
		var body_parent = cart_model
		var preset = CAR_PRESETS[car_index]
		for corner in ["FL", "FR", "RL", "RR"]:
			var part_name = preset.wheel_parts.get(corner, "")
			if not part_name.is_empty():
				var wheel_part = _find_node_by_name(cart_model, part_name)
				if wheel_part:
					body_parent = wheel_part.get_parent()
					break
		
		for child in body_parent.get_children():
			if child is Node3D:
				if child.name == "AntennaPlacement":
					continue
				original_body_part_transforms[child] = child.transform
				var dir = Vector3(randf_range(-1.0, 1.0), randf_range(0.2, 1.5), randf_range(-1.0, 1.0)).normalized()
				part_velocities[child] = dir * randf_range(4.0, 8.0)
				part_rotations[child] = Vector3(randf_range(-15.0, 15.0), randf_range(-15.0, 15.0), randf_range(-15.0, 15.0))

	if multiplayer.multiplayer_peer != null and multiplayer.is_server():
		get_tree().create_timer(3.0).timeout.connect(
			func(): if is_instance_valid(self): respawn_rpc.rpc()
		)
	elif multiplayer.multiplayer_peer == null:
		get_tree().create_timer(3.0).timeout.connect(
			func(): if is_instance_valid(self): respawn()
		)

@rpc("any_peer", "call_local", "reliable")
func drown_rpc():
	drown()

func drown():
	if is_exploding: return
	is_exploding = true
	is_drowned = true
	can_move = false
	if engine_sound.playing: engine_sound.stop()
	
	# Force-clear the shield — it must not persist into the respawn
	is_shielded = false
	shield_mesh.visible = false
	shield_mesh.scale = Vector3.ONE
	sfx_shield_loop.stop()
	
	var has_physics_authority = has_physics_authority()
	if has_physics_authority:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
	
	# Fade the car out over ~1 second instead of instantly hiding it
	_set_visuals_alpha(1.0)
	if _drown_tween:
		_drown_tween.kill()
	_drown_tween = create_tween()
	var fade_duration = 1.0
	# Animate alpha from 1 → 0
	_drown_tween.tween_method(
		func(a: float): _set_visuals_alpha(a),
		1.0, 0.0, fade_duration
	)
	# Also fade the name tag
	if name_tag:
		_drown_tween.parallel().tween_property(name_tag, "modulate:a", 0.0, fade_duration)
	_drown_tween.tween_callback(func(): visuals.visible = false)
	
	if multiplayer.multiplayer_peer != null and multiplayer.is_server():
		get_tree().create_timer(1.2).timeout.connect(
			func(): if is_instance_valid(self): respawn_rpc.rpc()
		)
	elif multiplayer.multiplayer_peer == null:
		get_tree().create_timer(1.2).timeout.connect(
			func(): if is_instance_valid(self): respawn()
		)

@rpc("any_peer", "call_local", "reliable")
func respawn_rpc():
	respawn()

func respawn():
	is_exploding = false
	is_drowned = false
	is_underwater = false
	water_timer = 0.0
	last_splash_time = -999.0
	was_on_ground = true
	air_time = 0.0
	on_alternative_path = false
	active_path = track_path
	alt_path_decisions.clear()

	ignore_next_landing_sound = true
	last_respawn_time = Time.get_ticks_msec() / 1000.0
	ai_stuck_position_timer = 0.0
	ai_last_stuck_position = global_position
	# Kill any in-flight drown fade tween so it can't overwrite the restored alpha
	if _drown_tween:
		_drown_tween.kill()
		_drown_tween = null
	# Directly restore visibility and alpha regardless of tween state
	visuals.visible = true
	# Clear shield in case it was active when the player drowned
	is_shielded = false
	shield_mesh.visible = false
	shield_mesh.scale = Vector3.ONE
	sfx_shield_loop.stop()
	
	# Reset parts positions/rotations
	for corner in original_wheel_transforms.keys():
		var pivot = get_node_or_null("Visuals/WheelPivot" + corner)
		if pivot:
			pivot.transform = original_wheel_transforms[corner]
			
	for child in original_body_part_transforms.keys():
		if is_instance_valid(child):
			child.transform = original_body_part_transforms[child]
			
	part_velocities.clear()
	part_rotations.clear()
	part_on_ground.clear()
	original_body_part_transforms.clear()
	
	_set_visuals_alpha(1.0)
	if name_tag:
		name_tag.modulate.a = 1.0
		
	# Start blinking respawn indicator
	respawn_indicator_time = 1.5
	
	var level = get_tree().get_first_node_in_group("level")
	var id = name.to_int()
	var finished = false
	if level and level.player_stats.has(id):
		finished = level.player_stats[id]["finished"]
	
	can_move = not finished
	is_boosting = false
	boost_time = 0.0
	
	explosion_particles.emitting = false
	burning_particles.emitting = false
	burning_smoke_particles.emitting = false
	fire_sprite_particles.emitting = false
	fire_sprite_particles_2.emitting = false
	sfx_fire_loop.stop()

	var has_physics_authority = has_physics_authority()
	if has_physics_authority:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO

		var target_path = active_path
		if target_path == null:
			target_path = track_path
		if target_path == null:
			var lvl = get_tree().get_first_node_in_group("level")
			if lvl and "track_path" in lvl:
				target_path = lvl.track_path

		var spawn_pos = last_checkpoint_transform.origin
		var forward_dir = -last_checkpoint_transform.basis.z.normalized() # fallback

		if target_path:
			var curve = target_path.curve
			var local_pos = target_path.to_local(spawn_pos)
			var offset = curve.get_closest_offset(local_pos)
			
			var next_offset = fmod(offset + 1.0, curve.get_baked_length())
			var p1 = curve.sample_baked(offset)
			var p2 = curve.sample_baked(next_offset)
			var tangent = (target_path.to_global(p2) - target_path.to_global(p1)).normalized()
			if tangent.length() > 0.01:
				forward_dir = tangent

		# Position the spawn 5 meters behind the checkpoint origin along the track tangent, lifted by 1.5m along local up axis to prevent underground clipping
		var target_basis = Basis.looking_at(forward_dir, Vector3.UP)
		spawn_pos = spawn_pos - forward_dir * 5.0 + target_basis.y * 1.5
		global_transform = Transform3D(target_basis, spawn_pos)

		visuals.global_position = global_position
		visuals.look_at(global_position + forward_dir * 10.0, Vector3.UP)

func _set_visuals_alpha(alpha: float):
	_set_alpha_recursive(visuals, alpha)

func _set_alpha_recursive(node: Node, alpha: float):
	if node is MeshInstance3D:
		if node == shield_mesh or node == shockwave_visual:
			return
		var mat = node.material_override as StandardMaterial3D
		if not mat:
			var base_mat = node.get_active_material(0)
			if base_mat:
				mat = base_mat.duplicate()
				node.material_override = mat
		if mat:
			if alpha >= 0.99:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				mat.render_priority = 0
			else:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				# Set a negative render priority so it renders BEFORE the water surface (priority 0)
				# This ensures transparent/fading carts are still tinted correctly by the transparent water.
				mat.render_priority = -1
			mat.albedo_color.a = alpha
	
	for child in node.get_children():
		_set_alpha_recursive(child, alpha)

func _set_visuals_respawn_effect(enabled: bool, blink_on: bool):
	_set_respawn_effect_recursive(visuals, enabled, blink_on)

func _set_respawn_effect_recursive(node: Node, enabled: bool, blink_on: bool):
	if node is MeshInstance3D:
		if node == shield_mesh or node == shockwave_visual:
			return
		var mat = node.material_override as StandardMaterial3D
		if not mat:
			var base_mat = node.get_active_material(0)
			if base_mat:
				mat = base_mat.duplicate()
				node.material_override = mat
		if mat:
			if enabled and blink_on:
				mat.emission_enabled = true
				mat.emission = Color(1.0, 1.0, 1.0, 1.0)
				mat.emission_energy_multiplier = 6.0
			else:
				mat.emission_enabled = false
	
	for child in node.get_children():
		_set_respawn_effect_recursive(child, enabled, blink_on)


func _set_visuals_shock_effect(enabled: bool, blink_on: bool):
	_set_shock_effect_recursive(visuals, enabled, blink_on)

func _set_shock_effect_recursive(node: Node, enabled: bool, blink_on: bool):
	if node is MeshInstance3D:
		if node == shield_mesh or node == shockwave_visual:
			return
		var mat = node.material_override as StandardMaterial3D
		if not mat:
			var base_mat = node.get_active_material(0)
			if base_mat:
				mat = base_mat.duplicate()
				node.material_override = mat
		if mat:
			var node_id = node.get_instance_id()
			if not _original_albedo_colors.has(node_id):
				_original_albedo_colors[node_id] = mat.albedo_color
			
			if enabled and blink_on:
				var current_alpha = mat.albedo_color.a
				mat.albedo_color = Color(0.1, 0.5, 1.0, current_alpha)
				mat.emission_enabled = true
				mat.emission = Color(0.1, 0.5, 1.0)
				mat.emission_energy_multiplier = 4.0
			else:
				var current_alpha = mat.albedo_color.a
				var orig_color = _original_albedo_colors[node_id]
				mat.albedo_color = Color(orig_color.r, orig_color.g, orig_color.b, current_alpha)
				mat.emission_enabled = false
				
	for child in node.get_children():
		_set_shock_effect_recursive(child, enabled, blink_on)


func give_item(type: int):
	var item_type = type as ItemType
	if current_item == ItemType.NONE:
		current_item = item_type
	elif current_item_2 == ItemType.NONE:
		current_item_2 = item_type
	else:
		# Both slots are full! Drop the item in slot 1.
		# Shift slot 2 to slot 1, and place new item in slot 2.
		current_item = current_item_2
		current_item_2 = item_type
	
	if is_local_player and race_ui:
		var item1_name = ItemType.keys()[current_item]
		var item2_name = ItemType.keys()[current_item_2]
		race_ui.update_items(item1_name, item2_name)

@rpc("any_peer", "call_local", "reliable")
func give_item_rpc(type: int):
	give_item(type)

func _get_random_item_rpc() -> int:
	var id = name.to_int()
	var level = get_tree().get_first_node_in_group("level")
	if level and level.get("player_stats") and level.player_stats.has(id):
		var stats = level.player_stats[id]
		if level.player_stats.size() > 1:
			if stats.get("pos", 0) == level.player_stats.size():
				return ItemType.BOOST

	# Weighted list of items: BOOST has 3x weight compared to others
	var items = [
		ItemType.BOOST, ItemType.BOOST, ItemType.BOOST,
		ItemType.MISSILE,
		ItemType.GUIDED_MISSILE,
		ItemType.SHIELD,
		ItemType.SHOCKWAVE,
		ItemType.BOMB,
		ItemType.LIGHTNING
	]
	return items[randi() % items.size()]

func _remove_collisions_recursive(node: Node):
	if node == null: return
	for child in node.get_children():
		_remove_collisions_recursive(child)
	if node is CollisionObject3D or node is CollisionShape3D:
		node.free()

# Item implementations
func _fire_missile(guided: bool):
	# Projectile instantiation now happens only on the server
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server(): return
	var forward = -global_transform.basis.z
	var pos = global_position
	var rot = global_rotation
	if visuals and visuals.is_inside_tree():
		forward = -visuals.global_transform.basis.z
		rot = visuals.global_rotation
	
	var spawn_pos = pos + (forward * 2.0) + Vector3(0, 1.0, 0)
	if multiplayer.multiplayer_peer != null:
		_spawn_missile_rpc.rpc(spawn_pos, rot, name.to_int(), guided)
	else:
		_spawn_missile_rpc(spawn_pos, rot, name.to_int(), guided)

@rpc("any_peer", "call_local", "reliable")
func _spawn_missile_rpc(spawn_pos: Vector3, spawn_rot: Vector3, shooter_id: int, guided: bool):
	var missile = MISSILE_SCENE.instantiate()
	missile.owner_id = shooter_id
	missile.is_guided = guided
	var level = get_tree().get_first_node_in_group("level")
	if level:
		level.add_child(missile)
	else:
		get_tree().root.add_child(missile)
	missile.global_position = spawn_pos
	missile.global_rotation = spawn_rot
	missile.start_position = spawn_pos
	if multiplayer.multiplayer_peer != null and multiplayer.is_server():
		missile.set_multiplayer_authority(1)

func _activate_shield():
	is_shielded = true
	shield_mesh.visible = true
	# Shield lasts 10 seconds
	get_tree().create_timer(10.0).timeout.connect(_on_shield_timeout.bind())

func _on_shield_timeout():
	is_shielded = false
	shield_mesh.visible = false

@rpc("any_peer", "call_local", "reliable")
func apply_blast_impulse(impulse: Vector3):
	if is_local_player or (is_ai and (multiplayer.multiplayer_peer == null or multiplayer.is_server())):
		apply_central_impulse(impulse)

func _activate_shockwave():
	# Apply force to nearby players (only on server)
	if multiplayer.multiplayer_peer == null or multiplayer.is_server():
		var players = get_tree().get_nodes_in_group("player_carts")
		for p in players:
			if p == self: continue
			var dist = global_position.distance_to(p.global_position)
			if dist < 15.0:
				if p.is_shielded:
					p.is_shielded = false
					var is_real_peer = p.name.to_int() > 0 and not p.get("is_ai")
					if multiplayer.multiplayer_peer != null and multiplayer.is_server() and is_real_peer:
						p.client_break_shield.rpc_id(p.name.to_int())
					else:
						p.shield_mesh.visible = false
						p.shield_mesh.scale = Vector3.ONE
					continue
				
				var dir = (p.global_position - global_position).normalized()
				var impulse = dir * 54.0 * p.mass + Vector3.UP * 27.0 * p.mass
				if p.has_method("apply_blast_impulse"):
					var is_real_peer = p.name.to_int() > 0 and not p.get("is_ai")
					if multiplayer.multiplayer_peer != null and is_real_peer:
						p.apply_blast_impulse.rpc_id(p.name.to_int(), impulse)
					else:
						p.apply_blast_impulse(impulse)
				else:
					p.apply_central_impulse(impulse)
		
		# Play visual for all clients
		if multiplayer.multiplayer_peer != null:
			client_play_shockwave.rpc()
		else:
			client_play_shockwave()

@rpc("any_peer", "call_local", "reliable")
func client_play_shockwave():
	shockwave_visual.visible = true
	shockwave_visual.scale = Vector3(0.1, 0.1, 0.1)
	if shockwave_visual.material_override:
		shockwave_visual.material_override.albedo_color.a = 0.5
	
	var tween = create_tween()
	if tween:
		# Run scale and alpha in parallel so the sphere is always fading as it expands.
		# Previously they were sequential — fully opaque giant sphere, then fade — which
		# caused the white distortion bloom on surrounding terrain.
		var t1 = tween.tween_property(shockwave_visual, "scale", Vector3(15.0, 15.0, 15.0), 0.5)
		if t1:
			t1.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
		var t2 = tween.parallel().tween_property(shockwave_visual, "material_override:albedo_color:a", 0.0, 0.45)
		if t2:
			t2.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			
		tween.tween_callback(func(): shockwave_visual.visible = false)
	
	sfx_release_pop.play()

func _activate_lightning():
	if multiplayer.multiplayer_peer == null or multiplayer.is_server():
		var players = get_tree().get_nodes_in_group("player_carts")
		var hit_players: Array[String] = []
		
		for p in players:
			if p == self: continue
			var dist = global_position.distance_to(p.global_position)
			if dist < 25.0:
				if p.is_shielded:
					p.is_shielded = false
					var is_real_peer = p.name.to_int() > 0 and not p.get("is_ai")
					if multiplayer.multiplayer_peer != null and multiplayer.is_server() and is_real_peer:
						p.client_break_shield.rpc_id(p.name.to_int())
					else:
						p.shield_mesh.visible = false
						p.shield_mesh.scale = Vector3.ONE
					continue
				
				# Slow down target player
				if p.has_method("apply_lightning_slow_multicast"):
					if multiplayer.multiplayer_peer != null:
						p.apply_lightning_slow_multicast.rpc()
					else:
						p.apply_lightning_slow_multicast()
				
				hit_players.append(p.name)
		
		# Play visual for all clients
		if multiplayer.multiplayer_peer != null:
			client_play_lightning.rpc(hit_players)
		else:
			client_play_lightning(hit_players)

@rpc("authority", "call_local", "reliable")
func apply_lightning_slow_multicast():
	slow_timer = 2.5

@rpc("any_peer", "call_local", "reliable")
func client_play_lightning(hit_player_names: Array):
	var sound_player = AudioStreamPlayer3D.new()
	sound_player.stream = load("res://sounds/electric_lightning_a_#1-1782053835008.wav")
	sound_player.pitch_scale = 1.0
	sound_player.volume_db = 2.0
	sound_player.bus = &"SFX"
	get_tree().current_scene.add_child(sound_player)
	sound_player.global_position = global_position
	sound_player.play()
	get_tree().create_timer(1.5).timeout.connect(sound_player.queue_free)

	for name_str in hit_player_names:
		var target = null
		for c in get_tree().get_nodes_in_group("player_carts"):
			if c.name == name_str:
				target = c
				break
		if target:
			_create_lightning_arc(global_position + Vector3(0, 0.8, 0), target.global_position + Vector3(0, 0.8, 0))
			_spawn_sparks(target.global_position + Vector3(0, 0.8, 0))

func _create_lightning_arc(start: Vector3, end: Vector3):
	var mesh_instance = MeshInstance3D.new()
	var imm_mesh = ImmediateMesh.new()
	mesh_instance.mesh = imm_mesh
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.2, 0.8, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.8, 1.0)
	mat.emission_energy_multiplier = 6.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.material_override = mat
	
	get_tree().current_scene.add_child(mesh_instance)
	
	imm_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var steps = 12
	var points = []
	points.append(start)
	
	var dir = end - start
	var length = dir.length()
	var step_vector = dir / steps
	
	var perp1 = dir.cross(Vector3.UP).normalized()
	if perp1.length() < 0.1:
		perp1 = dir.cross(Vector3.FORWARD).normalized()
	var perp2 = dir.cross(perp1).normalized()
	
	for i in range(1, steps):
		var base_pt = start + step_vector * i
		var offset_scale = length * 0.04
		var offset = perp1 * randf_range(-offset_scale, offset_scale) + perp2 * randf_range(-offset_scale, offset_scale)
		points.append(base_pt + offset)
		
	points.append(end)
	
	for i in range(points.size() - 1):
		var segment_dir = (points[i+1] - points[i]).normalized()
		var side = segment_dir.cross(Vector3.UP).normalized() * 0.15
		if side.length() < 0.01:
			side = segment_dir.cross(Vector3.FORWARD).normalized() * 0.15
			
		var p1 = points[i] - side
		var p2 = points[i] + side
		var p3 = points[i+1] + side
		var p4 = points[i+1] - side
		
		# Triangle 1
		imm_mesh.surface_add_vertex(p1)
		imm_mesh.surface_add_vertex(p2)
		imm_mesh.surface_add_vertex(p3)
		
		# Triangle 2
		imm_mesh.surface_add_vertex(p1)
		imm_mesh.surface_add_vertex(p3)
		imm_mesh.surface_add_vertex(p4)
		
	imm_mesh.surface_end()
	
	var tween = create_tween()
	if tween:
		tween.tween_interval(0.25)
		tween.tween_callback(mesh_instance.queue_free)

func _spawn_sparks(pos: Vector3):
	var sparks = CPUParticles3D.new()
	sparks.amount = 15
	sparks.lifetime = 0.5
	sparks.one_shot = true
	sparks.explosiveness = 0.8
	sparks.emitting = true
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = load("res://sprites/energy_spark.png")
	mat.albedo_color = Color(0.3, 0.8, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.8, 1.0)
	mat.emission_texture = load("res://sprites/energy_spark.png")
	mat.emission_energy_multiplier = 4.0
	sparks.material_override = mat
	
	var quad = QuadMesh.new()
	quad.size = Vector2(0.4, 0.4)
	sparks.mesh = quad
	
	sparks.direction = Vector3.UP
	sparks.spread = 180.0
	sparks.initial_velocity_min = 3.0
	sparks.initial_velocity_max = 6.0
	sparks.gravity = Vector3(0, -6.0, 0)
	sparks.angle_min = -180.0
	sparks.angle_max = 180.0
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 1.2
	
	get_tree().current_scene.add_child(sparks)
	sparks.global_position = pos
	
	get_tree().create_timer(0.6).timeout.connect(sparks.queue_free)

func _drop_bomb():
	# Projectile instantiation now happens only on the server
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server(): return
	var spawn_pos = global_position - (visuals.global_transform.basis.z * 2.0) + Vector3(0, 1.0, 0)
	var spawn_vel = linear_velocity * 0.5
	if multiplayer.multiplayer_peer != null:
		_spawn_bomb_rpc.rpc(spawn_pos, spawn_vel, name.to_int())
	else:
		_spawn_bomb_rpc(spawn_pos, spawn_vel, name.to_int())

@rpc("any_peer", "call_local", "reliable")
func _spawn_bomb_rpc(spawn_pos: Vector3, spawn_vel: Vector3, shooter_id: int):
	var bomb = BOMB_SCENE.instantiate()
	bomb.owner_id = shooter_id
	var level = get_tree().get_first_node_in_group("level")
	if level:
		level.add_child(bomb)
	else:
		get_tree().root.add_child(bomb)
	
	bomb.position = spawn_pos
	bomb.linear_velocity = spawn_vel
	
	if multiplayer.multiplayer_peer != null and multiplayer.is_server():
		bomb.set_multiplayer_authority(1)

func _enable_shadows_recursive(node: Node):
	if node == null: return
	if node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for child in node.get_children():
		_enable_shadows_recursive(child)

func _update_antenna(delta):
	if not antenna or not visuals or not visuals.is_inside_tree(): return
	
	# Velocity in the car's own local space
	var vel_local = visuals.global_transform.basis.inverse() * linear_velocity
	
	# Raw per-frame acceleration (noisy — will be smoothed below)
	var raw_accel = Vector3.ZERO
	if delta > 0.0001:
		raw_accel = (vel_local - last_velocity_local) / delta
	last_velocity_local = vel_local
	raw_accel = raw_accel.clamp(Vector3(-120.0, -120.0, -120.0), Vector3(120.0, 120.0, 120.0))
	
	# Smooth the signal to reduce per-frame noise while staying responsive
	antenna_accel_smooth = antenna_accel_smooth.lerp(raw_accel, clamp(delta * 12.0, 0.0, 1.0))
	
	# --- Inertia targets ---
	# The antenna TIP lags behind the car body:
	#   Accelerating forward (accel.z < 0 in local -Z forward space)
	#   → tip hangs back → rotation.x positive (tip toward +Z = backward)
	#   → target_x = -accel.z * factor  (positive when accelerating forward)
	var target_x = clamp(-antenna_accel_smooth.z * 0.014, -0.65, 0.65)
	
	#   Turning right (centripetal accel.x > 0)
	#   → tip hangs to outside (left) → rotation.z positive (rod tilts toward -X)
	#   → target_z = +accel.x * factor
	var target_z = clamp(antenna_accel_smooth.x * 0.011, -0.55, 0.55)
	
	# --- Speed-based micro-vibration (two offset sine waves = more organic feel) ---
	var speed = linear_velocity.length()
	var t = Time.get_ticks_msec() * 0.001
	var vib_scale = clamp(speed * 0.0009, 0.0, 0.013)
	target_x += sin(t * 13.7) * vib_scale
	target_z += sin(t * 11.3 + 1.4) * vib_scale * 0.7
	
	# --- Underdamped spring: stiff but lightly damped → oscillates like flexible wire ---
	# Damping ratio ζ = DAMPING / (2*sqrt(STIFFNESS)) ≈ 2.5/(2*√40) ≈ 0.20
	# The antenna rings ~3-4 times before settling, just like a steel RC antenna
	const STIFFNESS = 40.0
	const DAMPING = 2.5
	
	var err_x = target_x - antenna_tilt.x
	var err_z = target_z - antenna_tilt.z
	
	antenna_velocity.x += (err_x * STIFFNESS - antenna_velocity.x * DAMPING) * delta
	antenna_velocity.z += (err_z * STIFFNESS - antenna_velocity.z * DAMPING) * delta
	
	antenna_tilt.x += antenna_velocity.x * delta
	antenna_tilt.z += antenna_velocity.z * delta
	antenna_tilt = antenna_tilt.clamp(Vector3(-0.70, -0.70, -0.70), Vector3(0.70, 0.70, 0.70))
	
	# Apply: X rotation = forward/back bend, Z rotation = side bend
	antenna.rotation.x = antenna_tilt.x
	antenna.rotation.z = antenna_tilt.z

func _create_drift_particles(wheel_name: String):
	var pivot = get_node_or_null("Visuals/WheelPivot" + wheel_name)
	if not pivot: return
	
	# Smoke
	var smoke = CPUParticles3D.new()
	smoke.name = wheel_name + "_Smoke"
	smoke.emitting = false
	smoke.amount = 30
	smoke.lifetime = 0.6
	smoke.mesh = QuadMesh.new()
	smoke.local_coords = false # Emit in global coordinates so it trails behind the wheel rather than rotating with it
	smoke.top_level = true
	smoke.set_meta("pivot", pivot)
	
	pivot.add_child(smoke)
	drift_particles.append(smoke)
	
	if pivot.is_inside_tree():
		smoke.global_position = pivot.global_position
		smoke.global_rotation = pivot.global_rotation
	
	var mat_smoke = StandardMaterial3D.new()
	mat_smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_smoke.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_smoke.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat_smoke.vertex_color_use_as_albedo = true # Crucial for color_ramp to fade out the particles
	
	var grad_tex = GradientTexture2D.new()
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(0.5, 0.0)
	
	var smoke_grad = Gradient.new()
	smoke_grad.set_color(0, Color(0.8, 0.8, 0.8, 0.25))
	smoke_grad.set_color(1, Color(0.8, 0.8, 0.8, 0.0))
	grad_tex.gradient = smoke_grad
	
	mat_smoke.albedo_texture = grad_tex
	smoke.material_override = mat_smoke
	
	smoke.direction = Vector3.UP + Vector3.BACK * 0.5
	smoke.spread = 30.0
	smoke.gravity = Vector3(0, 1.0, 0)
	smoke.initial_velocity_min = 1.0
	smoke.initial_velocity_max = 3.0
	smoke.scale_amount_min = 0.2
	smoke.scale_amount_max = 0.6
	
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.2))
	scale_curve.add_point(Vector2(1.0, 1.0))
	smoke.scale_amount_curve = scale_curve
	
	var grad = Gradient.new()
	grad.set_color(0, Color(0.8, 0.8, 0.8, 0.15))
	grad.set_color(1, Color(0.8, 0.8, 0.8, 0.0))
	smoke.color_ramp = grad
	
	# Skidmarks
	var skid = CPUParticles3D.new()
	skid.name = wheel_name + "_Skid"
	skid.emitting = false
	skid.amount = 4000
	skid.lifetime = 15.0
	skid.mesh = QuadMesh.new()
	
	skid.mesh.orientation = PlaneMesh.FACE_Y
	skid.mesh.size = Vector2(0.35, 0.35)
	
	var mat_skid = StandardMaterial3D.new()
	mat_skid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_skid.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_skid.albedo_color = Color(0.1, 0.1, 0.1, 0.35)
	mat_skid.vertex_color_use_as_albedo = true
	skid.material_override = mat_skid
	
	var skid_grad = Gradient.new()
	skid_grad.offsets = PackedFloat32Array([0.0, 0.85, 1.0])
	skid_grad.colors = PackedColorArray([
		Color(0.1, 0.1, 0.1, 0.35),
		Color(0.1, 0.1, 0.1, 0.35),
		Color(0.1, 0.1, 0.1, 0.0)
	])
	skid.color_ramp = skid_grad
	
	skid.gravity = Vector3.ZERO
	skid.direction = Vector3.ZERO
	skid.spread = 0.0
	skid.local_coords = false
	skid.top_level = true
	skid.set_meta("pivot", pivot)
	
	pivot.add_child(skid)
	drift_particles.append(skid)
	
	if pivot.is_inside_tree():
		var local_offset = Vector3(0, WHEEL_Y_OFFSET + 0.02, 0)
		skid.global_position = pivot.global_position + pivot.global_transform.basis * local_offset
		skid.global_rotation = pivot.global_rotation

func _set_drift_emitting(emitting: bool):
	for p in drift_particles:
		if is_instance_valid(p) and p is CPUParticles3D:
			p.emitting = emitting

func _create_dirt_particles(wheel_name: String):
	var pivot = get_node_or_null("Visuals/WheelPivot" + wheel_name)
	if not pivot: return
	
	var dirt = CPUParticles3D.new()
	dirt.name = wheel_name + "_Dirt"
	dirt.emitting = false
	dirt.amount = 25
	dirt.lifetime = 0.5
	dirt.mesh = QuadMesh.new()
	dirt.local_coords = false
	dirt.top_level = true
	dirt.set_meta("pivot", pivot)
	
	pivot.add_child(dirt)
	dirt_particles.append(dirt)
	
	if pivot.is_inside_tree():
		dirt.global_position = pivot.global_position
		dirt.global_rotation = pivot.global_rotation
	
	var mat_dirt = StandardMaterial3D.new()
	mat_dirt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_dirt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_dirt.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat_dirt.vertex_color_use_as_albedo = true
	
	var grad_tex = GradientTexture2D.new()
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(0.5, 0.0)
	
	var dirt_grad = Gradient.new()
	dirt_grad.set_color(0, Color(0.25, 0.18, 0.1, 0.5))
	dirt_grad.set_color(1, Color(0.25, 0.18, 0.1, 0.0))
	grad_tex.gradient = dirt_grad
	
	mat_dirt.albedo_texture = grad_tex
	dirt.material_override = mat_dirt
	
	dirt.direction = Vector3.UP + Vector3.BACK * 1.5
	dirt.spread = 45.0
	dirt.gravity = Vector3(0, -6.0, 0)
	dirt.initial_velocity_min = 3.0
	dirt.initial_velocity_max = 6.0
	dirt.scale_amount_min = 0.15
	dirt.scale_amount_max = 0.45
	
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.2))
	scale_curve.add_point(Vector2(1.0, 0.8))
	dirt.scale_amount_curve = scale_curve
	
	var grad = Gradient.new()
	grad.set_color(0, Color(0.25, 0.18, 0.1, 0.65))
	grad.set_color(1, Color(0.25, 0.18, 0.1, 0.0))
	dirt.color_ramp = grad

func _set_dirt_emitting(emitting: bool):
	for p in dirt_particles:
		if is_instance_valid(p) and p is CPUParticles3D:
			p.emitting = emitting

func _get_ground_height(global_pos: Vector3) -> float:
	var space_state = get_world_3d().direct_space_state
	# Cast a ray from 5 units above global_pos to 15 units below global_pos
	var start = global_pos + Vector3(0, 5.0, 0)
	var end = global_pos + Vector3(0, -15.0, 0)
	var query = PhysicsRayQueryParameters3D.create(start, end)
	# Exclude the player cart itself so it doesn't collide with its own body shape
	query.exclude = [self.get_rid()]
	# Collide with world environment (layer 1)
	query.collision_mask = 1
	var result = space_state.intersect_ray(query)
	if result:
		return result.position.y
	return -999.0

func _spawn_splash(pos: Vector3, size_scale: float = 1.0):
	if WATER_SPLASH_SCENE:
		var splash_instance = WATER_SPLASH_SCENE.instantiate()
		splash_instance.scale = Vector3(size_scale, size_scale, size_scale)
		# Reduce particle counts on smaller splashes using amount_ratio
		if size_scale < 1.0:
			for child in splash_instance.get_children():
				if child is GPUParticles3D or child is CPUParticles3D:
					if "amount_ratio" in child:
						child.amount_ratio = size_scale
		get_tree().current_scene.add_child(splash_instance)
		splash_instance.global_position = pos

		# Play high-pitched, quieter splash sound for tiny splashes (puddles / exits)
		if size_scale < 1.0 and not REGULAR_SPLASH_SOUNDS.is_empty():
			var stream = REGULAR_SPLASH_SOUNDS[randi() % REGULAR_SPLASH_SOUNDS.size()]
			if stream:
				var ap = AudioStreamPlayer3D.new()
				ap.stream = stream
				ap.bus = &"SFX"
				ap.max_distance = 50.0
				ap.unit_size = 5.0
				ap.volume_db = lerp(-7.0, -1.0, size_scale)
				ap.pitch_scale = lerp(1.35, 1.0, size_scale)
				get_tree().current_scene.add_child(ap)
				ap.global_position = pos
				ap.play()
				get_tree().create_timer(stream.get_length() + 0.5).timeout.connect(ap.queue_free)


func _get_ai_input(delta: float) -> Vector2:
	var input = Vector2.ZERO
	
	if track_path == null:
		var level = get_tree().get_first_node_in_group("level")
		if level:
			if "track_path" in level and level.track_path:
				track_path = level.track_path
			if "alternative_paths" in level and level.alternative_paths:
				alternative_paths = level.alternative_paths
			
	if track_path == null:
		var level = get_tree().get_first_node_in_group("level")
		if level and "checkpoints" in level and not level.checkpoints.is_empty():
			var next_cp_idx = 0
			if level.player_stats.has(name.to_int()):
				next_cp_idx = level.player_stats[name.to_int()]["next_checkpoint_idx"]
			var cp = level.checkpoints[next_cp_idx]
			var local_to_cp = visuals.global_transform.inverse() * cp.global_position
			input.x = clamp(local_to_cp.x * 0.1, -1.0, 1.0)
			input.y = -1.0
		return input
		
	if active_path == null:
		active_path = track_path

	# Alternative path detection and decision logic
	if not on_alternative_path:
		for alt_path in alternative_paths:
			if not is_instance_valid(alt_path): continue
			var alt_curve = alt_path.curve
			if alt_curve.point_count < 2: continue
			
			var start_local = alt_curve.get_point_position(0)
			var start_global = alt_path.to_global(start_local)
			
			var dist = global_position.distance_to(start_global)
			if dist < 12.0:
				if not alt_path_decisions.has(alt_path):
					var take_shortcut = randf() < 0.35
					alt_path_decisions[alt_path] = take_shortcut
					if take_shortcut:
						on_alternative_path = true
						active_path = alt_path
						break
			elif dist > 25.0:
				alt_path_decisions.erase(alt_path)

	var curve = active_path.curve
	var local_pos = active_path.to_local(global_position)
	var current_offset = curve.get_closest_offset(local_pos)
	
	# If on an alternative path, check if we've reached the end of it
	if on_alternative_path:
		var curve_length = curve.get_baked_length()
		if curve_length - current_offset < 6.0:
			on_alternative_path = false
			active_path = track_path
			curve = active_path.curve
			local_pos = active_path.to_local(global_position)
			current_offset = curve.get_closest_offset(local_pos)
	
	# Periodically change target lane offset to simulate realistic lane shifting / overtaking
	ai_lane_change_timer -= delta
	if ai_lane_change_timer <= 0.0:
		ai_lane_change_timer = randf_range(5.0, 10.0)
		ai_target_lane_offset = randf_range(-2.0, 2.0)
	
	# Smoothly interpolate to target lane offset
	ai_lane_offset = lerp(ai_lane_offset, ai_target_lane_offset, 1.5 * delta)
	
	var speed = linear_velocity.length()
	var look_ahead = lerp(8.0, 16.0, speed / max_speed)
	var target_offset = current_offset + look_ahead
	
	var curve_length = curve.get_baked_length()
	target_offset = fmod(target_offset, curve_length)
	
	var target_local_pos = curve.sample_baked(target_offset)
	
	# Compute perpendicular offset (lane offset) along the track tangent
	var tangent_offset = fmod(target_offset + 1.0, curve_length)
	var tangent_local_pos = curve.sample_baked(tangent_offset)
	var tangent = (tangent_local_pos - target_local_pos).normalized()
	var right_vec = Vector3(-tangent.z, 0, tangent.x).normalized()
	
	var actual_lane_offset = ai_lane_offset
	if on_alternative_path:
		actual_lane_offset *= 0.2
	target_local_pos += right_vec * actual_lane_offset
	
	var target_global_pos = active_path.to_global(target_local_pos)
	
	var target_vec = visuals.global_transform.inverse() * target_global_pos
	var dir_flat = Vector2(target_vec.x, -target_vec.z).normalized()
	
	input.x = clamp(dir_flat.x * 2.2, -1.0, 1.0)
	input.y = -1.0 + abs(input.x) * 0.5
	
	# 3-Ray Obstacle Avoidance
	var space_state = get_world_3d().direct_space_state
	if space_state:
		var fwd_dir = -visuals.global_transform.basis.z
		var right_dir = visuals.global_transform.basis.x
		var my_pos = global_position + Vector3.UP * 0.2
		
		# Define three rays: center (12m), left-angled (10m), right-angled (10m)
		var rays = [
			{"end": my_pos + fwd_dir * 12.0, "weight": 1.0, "side": 0.0},
			{"end": my_pos + (fwd_dir - right_dir * 0.25).normalized() * 10.0, "weight": 0.8, "side": -1.0},
			{"end": my_pos + (fwd_dir + right_dir * 0.25).normalized() * 10.0, "weight": 0.8, "side": 1.0}
		]
		
		var avoid_force = 0.0
		var obstacle_count = 0
		
		for ray in rays:
			var query = PhysicsRayQueryParameters3D.create(my_pos, ray["end"])
			query.exclude = [self.get_rid()]
			var result = space_state.intersect_ray(query)
			if result:
				var collider = result.collider
				var c_name = collider.name.to_lower()
				# Exclude the road surface, terrain, halfway markers, checkpoints, gates, and ramps
				var is_road_or_terrain = c_name.contains("road") or c_name.contains("terrain") or c_name.contains("track") or c_name.contains("unified_world") or c_name.contains("gate") or c_name.contains("finishline") or c_name.contains("checkpoint") or c_name.contains("halfway") or c_name.contains("ramp")
				
				if not is_road_or_terrain:
					var dist = my_pos.distance_to(result.position)
					var intensity = clamp(1.0 - (dist / 12.0), 0.1, 1.0) * ray["weight"]
					
					if ray["side"] == 0.0:
						var local_hit = visuals.global_transform.inverse() * result.position
						var side = -sign(local_hit.x) if abs(local_hit.x) > 0.05 else -1.0
						avoid_force += side * 2.0 * intensity
					else:
						# Side hit: steer in the opposite direction
						avoid_force += -ray["side"] * 1.5 * intensity
					obstacle_count += 1
					
		if obstacle_count > 0:
			input.x = clamp(input.x + avoid_force, -1.0, 1.0)
	
	if speed < 1.5 and can_move and not is_exploding:
		stuck_timer += delta
		if stuck_timer > 3.5:
			stuck_timer = 0.0
			respawn()
		elif stuck_timer > 1.2:
			input.y = 1.0
			input.x = -sign(input.x) if input.x != 0 else 1.0
	else:
		stuck_timer = 0.0
		
	return input

func _process_ai_items(delta: float):
	if current_item == ItemType.NONE:
		return
		
	ai_item_timer += delta
	if ai_item_timer < 0.6:
		return
	ai_item_timer = 0.0
	
	var should_use = false
	match current_item:
		ItemType.BOOST:
			if abs(sync_steer) < 0.2:
				should_use = true
		ItemType.MISSILE, ItemType.GUIDED_MISSILE:
			var fwd = -visuals.global_transform.basis.z
			for cart in get_tree().get_nodes_in_group("player_carts"):
				if cart == self: continue
				var to_cart = cart.global_position - global_position
				if to_cart.length() < 40.0 and fwd.dot(to_cart.normalized()) > 0.8:
					should_use = true
					break
		ItemType.BOMB, ItemType.SHOCKWAVE:
			var fwd = -visuals.global_transform.basis.z
			for cart in get_tree().get_nodes_in_group("player_carts"):
				if cart == self: continue
				var to_cart = cart.global_position - global_position
				if to_cart.length() < 18.0 and fwd.dot(to_cart.normalized()) < -0.5:
					should_use = true
					break
		ItemType.SHIELD:
			should_use = true
		ItemType.LIGHTNING:
			for cart in get_tree().get_nodes_in_group("player_carts"):
				if cart == self: continue
				var dist = global_position.distance_to(cart.global_position)
				if dist < 25.0:
					should_use = true
					break
			
	if should_use:
		_use_item()

func start_intro_animation():
	if is_local_player:
		is_intro_active = true
		intro_time = INTRO_DURATION
		intro_orbit_center = visuals.global_position
		_update_intro_camera(0.0)

func _update_intro_camera(_delta: float):
	var progress = (INTRO_DURATION - intro_time) / INTRO_DURATION
	var t = sin(progress * PI / 2.0)
	
	var base_angle = atan2(20.0, -20.0)
	var start_angle = base_angle - PI
	
	var current_angle = lerp(start_angle, base_angle, t)
	var current_dist = lerp(65.0, 28.28, t)
	var current_height = lerp(35.0, 20.0, t)
	
	var offset = Vector3(
		cos(current_angle) * current_dist,
		current_height,
		sin(current_angle) * current_dist
	)
	
	camera_pivot.global_position = intro_orbit_center + offset
	camera_pivot.look_at(intro_orbit_center, Vector3.UP)

func _set_layers_recursive(node: Node, mask: int):
	if node is VisualInstance3D:
		node.layers = mask
	for child in node.get_children():
		_set_layers_recursive(child, mask)

func _find_node_by_name(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	for child in root.get_children():
		var found = _find_node_by_name(child, node_name)
		if found:
			return found
	return null

func _exit_tree():
	var tree = get_tree()
	if tree:
		tree.call_group("player_carts", "update_lod_bias_deferred")

func update_lod_bias_deferred():
	call_deferred("update_lod_bias")

func update_lod_bias():
	if not is_inside_tree():
		return
	var carts = get_tree().get_nodes_in_group("player_carts")
	var active_carts = []
	for cart in carts:
		if is_instance_valid(cart) and cart.is_inside_tree():
			active_carts.append(cart)
	
	var cart_count = active_carts.size()
	
	# Determine lod bias based on how many carts exist in the scene.
	# With 500k polygons per car, multiple cars on screen will tank performance.
	# We dynamically scale lod_bias down to force Godot's auto-generated LODs to kick in much earlier/closer.
	var bias = 1.0
	if cart_count >= 6:
		bias = 0.15
	elif cart_count >= 4:
		bias = 0.3
	elif cart_count >= 2:
		bias = 0.6
		
	_set_lod_bias_recursive(visuals, bias)

func _set_lod_bias_recursive(node: Node, bias: float):
	if node is GeometryInstance3D:
		node.lod_bias = bias
	for child in node.get_children():
		_set_lod_bias_recursive(child, bias)

func _update_all_carts_lod():
	if is_inside_tree():
		get_tree().call_group("player_carts", "update_lod_bias")
	return null
