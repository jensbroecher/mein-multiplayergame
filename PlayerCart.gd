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
		"model_path": "res://models/cars/20260505221030_500312d9.fbx",
		"model_y_rotation": PI,       # native FBX faces backward, flip 180°
		"max_speed": 30.0,
		"acceleration": 50.0,
		"steer_speed": 2.5,
		"grip": 5.0,
		# Wheel part names inside the FBX, keyed by corner
		"wheel_parts": {"FL": "part_5", "FR": "part_2", "RL": "part_0", "RR": "part_6"}
	},
	{
		"name": "Lightning",
		"model_path": "res://models/cars/20260505210312_305e4d34.fbx",
		"model_y_rotation": PI,
		"max_speed": 35.0,
		"acceleration": 40.0,
		"steer_speed": 2.2,
		"grip": 4.5,
		"wheel_parts": {"FL": "part_3", "FR": "part_0", "RL": "part_4", "RR": "part_2"}
	},
	{
		"name": "Strikeforce",
		"model_path": "res://models/cars/20260505211857_6fc2a5d6.fbx",
		"model_y_rotation": PI * 1.5, # FBX native orientation requires 270° rotation
		"max_speed": 28.0,
		"acceleration": 65.0,
		"steer_speed": 2.7,
		"grip": 5.5,
		"wheel_parts": {"FL": "part_10", "FR": "part_7", "RL": "part_11", "RR": "part_9"}
	},
	{
		"name": "Apex",
		"model_path": "res://models/cars/20260505221804_6590f061.fbx",
		"model_y_rotation": PI,
		"max_speed": 29.0,
		"acceleration": 55.0,
		"steer_speed": 3.2,
		"grip": 6.0,
		"wheel_parts": {"FL": "part_0", "FR": "part_1", "RL": "part_3", "RR": "part_2"}
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
const COLLISION_RADIUS = WHEEL_RADIUS + 0.2  # Slightly larger to prevent tunneling without CCD

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

var is_exploding = false
var boost_time = 0.0
var boost_timer = 0.0
var is_boosting = false

@onready var sfx_brake_drift = $Visuals/SFX_BrakeDrift
var is_drifting: bool = false
var was_on_ground: bool = true
var air_time: float = 0.0
var wheel_rotation: float = 0.0
var is_teleporting: bool = false
var is_shielded: bool = false
var camera_look_at: Vector3 = Vector3.ZERO
var is_isometric: bool = true
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

enum ItemType { NONE, BOOST, MISSILE, GUIDED_MISSILE, SHIELD, SHOCKWAVE, BOMB }
var current_item = ItemType.NONE

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

func on_race_started():
	if is_local_player:
		can_move = true

func _ready():
	add_to_group("player_carts")
	_update_authority()

	# Load the correct model mesh
	var preset = CAR_PRESETS[car_index]
	max_speed = preset.max_speed
	acceleration = preset.acceleration
	steer_speed = preset.steer_speed
	grip = preset.grip
	
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

	await get_tree().process_frame
	var level = get_tree().get_first_node_in_group("level")
	if level and level.has_node("RaceUI"):
		race_ui = level.get_node("RaceUI")

	ground_ray.add_exception(self)

	name_tag.text = player_name
	last_checkpoint_transform = global_transform
	camera_look_at = global_position

	# Setup collision shape to match wheel positions
	var collision_shape = $CollisionShape3D
	if collision_shape and collision_shape.shape is SphereShape3D:
		collision_shape.shape.radius = COLLISION_RADIUS
		collision_shape.transform.origin = Vector3(0, COLLISION_Y_OFFSET, 0)

	# Adjust ground ray to reach just below collision sphere
	ground_ray.target_position = Vector3(0, -(COLLISION_RADIUS + 0.2), 0)

	visuals.global_transform = global_transform
	visuals.top_level = true
	
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
		
		# Lock rotation so we handle it manually
		axis_lock_angular_x = true
		axis_lock_angular_y = true
		axis_lock_angular_z = true

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
			var iso_offset = Vector3(-20, 20, 20)
			camera_pivot.global_position = visuals.global_position + iso_offset
			camera_pivot.look_at(visuals.global_position, Vector3.UP)
	else:
		camera.current = false
		if has_node("Visuals/CameraPivot/Camera3D/AudioListener3D"):
			get_node("Visuals/CameraPivot/Camera3D/AudioListener3D").current = false

	# Initialize drift/skidmark particles for rear wheels
	_create_drift_particles("RL")
	_create_drift_particles("RR")
	_create_dirt_particles("RL")
	_create_dirt_particles("RR")

func _enter_tree():
	_update_authority()

func _update_authority():
	var id = name.to_int()
	if id > 0:
		set_multiplayer_authority(id)
		$MultiplayerSynchronizer.set_multiplayer_authority(id)
	is_local_player = is_multiplayer_authority()
	
	if not is_local_player:
		freeze = true
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC

func _process(delta):
	_update_visual_states(delta)
	_update_antenna(delta)
	if is_local_player:
		_update_visuals_alignment(delta)

		if Input.is_action_just_pressed("toggle_camera"):
			is_isometric = not is_isometric
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE

		if Input.is_action_just_pressed("respawn"):
			respawn_rpc.rpc()

		var visual_forward = -visuals.global_transform.basis.z
		var speed_factor = clamp(linear_velocity.length() / max_speed, 0.0, 1.0)
		var look_ahead_dist = 4.0 + speed_factor * 6.0

		var excludes = [self.get_rid()]
		var level = get_tree().get_first_node_in_group("level")
		if level:
			for cp in level.checkpoints:
				excludes.append(cp.get_rid())
				for sb in cp.find_children("*", "StaticBody3D", true, false):
					excludes.append(sb.get_rid())
		for cart in get_tree().get_nodes_in_group("player_carts"):
			excludes.append(cart.get_rid())

		if is_isometric:
			var iso_offset = Vector3(-20, 20, 20)
			var target_cam_pos = visuals.global_position + iso_offset
			
			# Avoid clipping through bridge/terrain
			var space_state = get_world_3d().direct_space_state
			var ray_start = visuals.global_position + Vector3.UP * 1.0
			var query = PhysicsRayQueryParameters3D.create(ray_start, target_cam_pos)
			query.exclude = excludes
			var result = space_state.intersect_ray(query)
			if result:
				target_cam_pos = result.position - (target_cam_pos - ray_start).normalized() * 0.5
				
			camera_pivot.global_position = camera_pivot.global_position.lerp(target_cam_pos, 10.0 * delta)
			camera_look_at = camera_look_at.lerp(visuals.global_position + visual_forward * look_ahead_dist, 10.0 * delta)
			camera_pivot.look_at(camera_look_at, Vector3.UP)
		else:
			var cam_dist = lerp(3.5, 6.0, clamp(boost_time / 4.0, 0.0, 1.0))
			
			# Smooth camera trailing
			var target_cam_pos = visuals.global_position - visual_forward * cam_dist + Vector3(0, 1.5, 0)
			
			# Avoid clipping through bridge/terrain
			var space_state = get_world_3d().direct_space_state
			var ray_start = visuals.global_position + Vector3.UP * 1.0
			var query = PhysicsRayQueryParameters3D.create(ray_start, target_cam_pos)
			query.exclude = excludes
			var result = space_state.intersect_ray(query)
			if result:
				target_cam_pos = result.position - (target_cam_pos - ray_start).normalized() * 0.5
				
			camera_pivot.global_position = camera_pivot.global_position.lerp(target_cam_pos, 10.0 * delta)
			
			camera_look_at = camera_look_at.lerp(visuals.global_position + visual_forward * (look_ahead_dist + 2.0), 12.0 * delta)
			camera_pivot.look_at(camera_look_at, Vector3.UP)
		
		# Smoothly lerp camera FOV based on is_isometric and is_boosting
		var target_fov = 35.0 if is_isometric else 75.0
		if is_boosting:
			target_fov += 10.0 if is_isometric else 15.0 # Zoom out when boosting!
		camera.fov = lerp(camera.fov, target_fov, 8.0 * delta)

		if race_ui:
			race_ui.update_speed(linear_velocity.length() * 1.8)

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
	else:
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
	if hop_cooldown > 0:
		hop_cooldown -= delta

	if is_teleporting:
		return

	if global_position.y < -50:
		if multiplayer.is_server():
			respawn_rpc.rpc()
		elif is_local_player:
			respawn() # single-player / host fallback

	if is_exploding:
		if not is_drowned:
			if is_local_player:
				apply_central_force(Vector3.UP * 5.0)
			
			if sfx_fire_loop.playing:
				sfx_fire_loop.volume_db = lerp(sfx_fire_loop.volume_db, -10.0, 2.0 * delta)

			burning_particles.global_position = global_position + Vector3(0, 0.5, 0)
			burning_smoke_particles.global_position = global_position + Vector3(0, 0.5, 0)
		
		if is_local_player:
			_move_and_sync()
		else:
			_interpolate_remote_physics(delta)
		return

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
					ap.max_distance = 60.0
					ap.unit_size = 6.0
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
	if ground_ray.is_colliding() and not is_underwater and global_position.y >= WATER_LEVEL and global_position.y < WATER_LEVEL + 0.6 and linear_velocity.length() > 3.0:
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - last_splash_time > 0.35:
			last_splash_time = current_time
			var splash_pos = Vector3(global_position.x, WATER_LEVEL, global_position.z)
			_spawn_splash(splash_pos, 0.35)

	if is_underwater:
		water_timer += delta
		if water_timer > 0.8: # Drown faster (0.8 seconds underwater triggers drown)
			if multiplayer.is_server():
				drown_rpc.rpc()
			elif not multiplayer.has_multiplayer_peer():
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

	if not is_local_player:
		_interpolate_remote_physics(delta)
		return

	# Apply extra gravity
	apply_central_force(Vector3.DOWN * GRAVITY * mass)

	# Continuous boost timer check for the local player
	if boost_timer > 0.0:
		boost_timer -= delta
		if boost_timer <= 0.0:
			boost_timer = 0.0
	is_boosting = boost_timer > 0.0

	if not can_move:
		linear_velocity = linear_velocity.lerp(Vector3.ZERO, 3.0 * delta)
		_move_and_sync()
		return

	if Input.is_action_just_pressed("boost"):
		_use_item()

	var input_dir = Vector2.ZERO
	input_dir.x = Input.get_axis("steer_left", "steer_right")
	input_dir.y = Input.get_axis("throttle", "brake")

	var on_ground = ground_ray.is_colliding()
	if not on_ground:
		air_time += delta
	else:
		if not was_on_ground:
			play_landing_sound_rpc.rpc(air_time)
		air_time = 0.0
	was_on_ground = on_ground

	var is_offroad = false
	if on_ground:
		var collider = ground_ray.get_collider()
		if collider and (collider.name.contains("Unified_World_Collision") or collider.name.contains("Terrain")):
			is_offroad = true

	if is_offroad:
		offroad_timer += delta
		if offroad_timer > 0.15:
			offroad_timer = 0.0
			offroad_target_penalty = randf_range(0.90, 0.95)
		offroad_penalty = lerp(offroad_penalty, offroad_target_penalty, 5.0 * delta)
	else:
		offroad_penalty = lerp(offroad_penalty, 1.0, 10.0 * delta)

	var ground_normal = Vector3.UP
	if on_ground:
		ground_normal = ground_ray.get_collision_normal()

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

	if is_boosting:
		var max_sp = max_speed * 1.5
		var accel_force = acceleration * 2.0
		if on_ground and ground_normal.y < 0.85 and fwd.dot(Vector3.UP) > 0.05:
			accel_force = 0.0
		if current_speed < max_sp:
			apply_central_force(fwd * accel_force * mass)
		boost_time += delta
	
	if input_dir.y < -0.1: # Forward input
		if not is_boosting:
			var accel_force = acceleration
			if on_ground and ground_normal.y < 0.85 and fwd.dot(Vector3.UP) > 0.05:
				accel_force = 0.0
			if current_speed < max_speed * offroad_penalty:
				apply_central_force(fwd * accel_force * mass)
			boost_time += delta
	elif input_dir.y > 0.1: # Brake / Reverse input
		boost_time = 0.0
		if not on_ground:
			# Ignore braking and reversing while airborne
			pass
		elif is_boosting:
			# If boosting, braking just reduces the boost effectiveness a bit
			apply_central_force(-fwd * braking * 0.5 * mass)
		elif drift_mode:
			# If drifting, preserve forward momentum by not applying heavy brakes
			var speed_ratio = clamp(linear_velocity.length() / max_speed, 0.0, 1.0)
			if speed_ratio < 0.85:
				apply_central_force(fwd * acceleration * 0.8 * mass)
			else:
				apply_central_force(fwd * acceleration * 0.3 * mass)
		else:
			if current_speed > 1.0:
				apply_central_force(-fwd * braking * mass)
			elif current_speed < -0.5:
				if current_speed > -reverse_speed * offroad_penalty:
					var accel_force = acceleration * 0.5
					if on_ground and ground_normal.y < 0.85 and (-fwd).dot(Vector3.UP) > 0.05:
						accel_force = 0.0
					apply_central_force(-fwd * accel_force * mass)
			else:
				if current_speed > -reverse_speed * offroad_penalty:
					var accel_force = acceleration * 0.7
					if on_ground and ground_normal.y < 0.85 and (-fwd).dot(Vector3.UP) > 0.05:
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
			if on_ground and ground_normal.y < 0.85:
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
	var effective_max = max_speed * offroad_penalty
	if on_ground and not is_boosting and current_speed > effective_max:
		var excess_ratio = (current_speed - effective_max) / max_speed
		apply_central_force(-fwd * excess_ratio * acceleration * 8.0 * mass)

	# Emit dirt particles when offroad and moving
	var emit_dirt = is_offroad and on_ground and linear_velocity.length() > 2.0
	_set_dirt_emitting(emit_dirt)
	sync_emit_dirt = emit_dirt

	sync_steer = current_steer
	_move_and_sync()

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

	var on_ground = ground_ray.is_colliding()
	var target_up = Vector3.UP
	if on_ground:
		target_up = ground_ray.get_collision_normal()
	else:
		# If in air, slowly return to global UP instead of snapping
		target_up = visuals.global_transform.basis.y.lerp(Vector3.UP, 2.0 * delta).normalized()
		
	# Smoothly align the visual mesh normal
	var current_basis = visuals.global_transform.basis
	var forward = -current_basis.z
	var right = current_basis.x

	var target_right = forward.cross(target_up).normalized()
	var target_forward = target_up.cross(target_right).normalized()

	var target_basis = Basis(target_right, target_up, -target_forward)
	if is_drifting:
		var drift_angle = -0.35 if drift_right else 0.35
		target_basis = target_basis.rotated(target_up, drift_angle)
	visuals.global_transform.basis = current_basis.slerp(target_basis, 8.0 * delta)

	# Allow the user to place wheels/body themselves in the scene editor
	visuals.global_position = global_position

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
	var t = clamp(REMOTE_LERP_SPEED * delta, 0.0, 1.0)
	global_position = global_position.lerp(sync_position, t)

	var current_quat := Quaternion.from_euler(rotation)
	var target_quat := sync_rotation_quat
	if target_quat == Quaternion.IDENTITY:
		target_quat = Quaternion.from_euler(sync_rotation)

	var rot_t = clamp(REMOTE_LERP_SPEED * 0.65 * delta, 0.0, 1.0)
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
	var rot_t = clamp(REMOTE_LERP_SPEED * 0.65 * delta, 0.0, 1.0)
	var new_visual_quat: Quaternion = current_visual_quat.slerp(target_quat, rot_t)
	
	visuals.global_transform.basis = Basis(new_visual_quat)
	visuals.global_position = global_position

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
	current_item = ItemType.NONE # Clear locally so it replicates to server immediately
	if race_ui:
		race_ui.update_item("NONE")
	# Request server to execute item use so it is authority-approved and spawned correctly on all clients
	request_use_item.rpc_id(1, item_to_use)

@rpc("any_peer", "call_local", "reliable")
func request_use_item(item_to_use: int):
	if not multiplayer.is_server(): return
	_execute_use_item(item_to_use)

func _execute_use_item(type: int):
	match type:
		ItemType.BOOST:
			client_start_boost.rpc_id(name.to_int())
		ItemType.MISSILE:
			_fire_missile(false)
		ItemType.GUIDED_MISSILE:
			_fire_missile(true)
		ItemType.SHIELD:
			client_start_shield.rpc_id(name.to_int())
		ItemType.SHOCKWAVE:
			_activate_shockwave()
		ItemType.BOMB:
			_drop_bomb()

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

func on_hit():
	if is_shielded:
		is_shielded = false
		if multiplayer.is_server() and name.to_int() > 0:
			client_break_shield.rpc_id(name.to_int())
		else:
			shield_mesh.visible = false
			shield_mesh.scale = Vector3.ONE
		return
	# Server triggers the explosion for all clients
	if multiplayer.is_server():
		explode_rpc.rpc()
	else:
		explode() # fallback for local-only / single-player

@rpc("any_peer", "call_local", "reliable")
func explode_rpc():
	explode()

func explode():
	if is_exploding: return
	is_exploding = true
	can_move = false
	is_drowned = false
	explosion_time = 0.0
	
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
		for child in cart_model.get_children():
			if child is Node3D:
				original_body_part_transforms[child] = child.transform
				var dir = Vector3(randf_range(-1.0, 1.0), randf_range(0.2, 1.5), randf_range(-1.0, 1.0)).normalized()
				part_velocities[child] = dir * randf_range(4.0, 8.0)
				part_rotations[child] = Vector3(randf_range(-15.0, 15.0), randf_range(-15.0, 15.0), randf_range(-15.0, 15.0))

	if multiplayer.is_server():
		get_tree().create_timer(3.0).timeout.connect(
			func(): if is_instance_valid(self): respawn_rpc.rpc()
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
	
	if is_local_player:
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
	
	if multiplayer.is_server():
		get_tree().create_timer(1.2).timeout.connect(
			func(): if is_instance_valid(self): respawn_rpc.rpc()
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

	if is_local_player:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO

		var spawn_pos = last_checkpoint_transform.origin + (last_checkpoint_transform.basis.z * 5.0) + Vector3(0, 2.0, 0)
		global_position = spawn_pos

		visuals.global_position = global_position

		var look_target = last_checkpoint_transform.origin
		look_target.y = spawn_pos.y
		if look_target.distance_to(spawn_pos) > 0.01:
			visuals.look_at(look_target, Vector3.UP)

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
			else:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
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


func give_item(type: int):
	current_item = type as ItemType
	if is_local_player and race_ui:
		var item_name = ItemType.keys()[type]
		race_ui.update_item(item_name)

@rpc("any_peer", "call_local", "reliable")
func give_item_rpc(type: int):
	give_item(type)

func _get_random_item_rpc() -> int:
	# Returns a random item type (excluding NONE)
	var item_keys = ItemType.keys()
	var valid_items = []
	for key in item_keys:
		if key != "NONE":
			valid_items.append(ItemType[key])
	return valid_items[randi() % valid_items.size()]

func _remove_collisions_recursive(node: Node):
	if node == null: return
	for child in node.get_children():
		_remove_collisions_recursive(child)
	if node is CollisionObject3D or node is CollisionShape3D:
		node.free()

# Item implementations
func _fire_missile(guided: bool):
	# Projectile instantiation now happens only on the server
	if not multiplayer.is_server(): return
	var forward = -global_transform.basis.z
	var pos = global_position
	var rot = global_rotation
	if visuals and visuals.is_inside_tree():
		forward = -visuals.global_transform.basis.z
		rot = visuals.global_rotation
	
	var spawn_pos = pos + (forward * 2.0) + Vector3(0, 1.0, 0)
	_spawn_missile_rpc.rpc(spawn_pos, rot, name.to_int(), guided)

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
	if multiplayer.is_server():
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
	if is_local_player:
		apply_central_impulse(impulse)

func _activate_shockwave():
	# Apply force to nearby players (only on server)
	if multiplayer.is_server():
		var players = get_tree().get_nodes_in_group("player_carts")
		for p in players:
			if p == self: continue
			var dist = global_position.distance_to(p.global_position)
			if dist < 15.0:
				if p.is_shielded:
					p.is_shielded = false
					if multiplayer.is_server() and p.name.to_int() > 0:
						p.client_break_shield.rpc_id(p.name.to_int())
					else:
						p.shield_mesh.visible = false
						p.shield_mesh.scale = Vector3.ONE
					continue
				
				var dir = (p.global_position - global_position).normalized()
				var impulse = dir * 54.0 * p.mass + Vector3.UP * 27.0 * p.mass
				if p.has_method("apply_blast_impulse"):
					p.apply_blast_impulse.rpc_id(p.name.to_int(), impulse)
				else:
					p.apply_central_impulse(impulse)
		
		# Play visual for all clients
		client_play_shockwave.rpc()

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

func _drop_bomb():
	# Projectile instantiation now happens only on the server
	if not multiplayer.is_server(): return
	var spawn_pos = global_position - (visuals.global_transform.basis.z * 2.0) + Vector3(0, 1.0, 0)
	var spawn_vel = linear_velocity * 0.5
	_spawn_bomb_rpc.rpc(spawn_pos, spawn_vel, name.to_int())

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
	
	if multiplayer.is_server():
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
