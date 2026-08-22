extends RigidBody3D

@export var player_name: String = "Player":
	set(value):
		player_name = value
		_refresh_name_tag()

@export var race_place: int = 0:
	set(value):
		if race_place == value:
			return
		race_place = value
		_refresh_name_tag()

@export var car_index: int = 0

const CAR_PRESETS = [
	{
		"name": "Viper",
		"model_path": "res://models/cars/Viper.tscn",
		"model_y_rotation": PI,       # native FBX faces backward, flip 180°
		"max_speed": 40.0,
		"acceleration": 65.0,
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
		"max_speed": 41.0,
		"acceleration": 52.0,
		"steer_speed": 2.2,
		"grip": 4.5,
		"braking": 32.0,
		"offroad": 4.0,
		"wheel_parts": {"FL": "part_3", "FR": "part_0", "RL": "part_4", "RR": "part_2"}
	},
	{
		"name": "Strikeforce",
		"model_path": "res://models/cars/Strikeforce.tscn",
		"model_y_rotation": PI * 1.5, # FBX native orientation requires 270° rotation
		"max_speed": 37.5,
		"acceleration": 82.0,
		"steer_speed": 2.7,
		"grip": 5.5,
		"braking": 52.0,
		"offroad": 8.0,
		"wheel_parts": {"FL": "part_10", "FR": "part_7", "RL": "part_11", "RR": "part_9"}
	},
	{
		"name": "Apex",
		"model_path": "res://models/cars/Apex.tscn",
		"model_y_rotation": PI,
		"max_speed": 39.0,
		"acceleration": 70.0,
		"steer_speed": 3.2,
		"grip": 6.0,
		"braking": 46.0,
		"offroad": 5.0,
		"wheel_parts": {"FL": "part_0", "FR": "part_1", "RL": "part_4", "RR": "part_2"}
	},
	{
		"name": "Interceptor",
		"model_path": "res://models/cars/Interceptor.tscn",
		"model_y_rotation": PI,
		"max_speed": 43.0,
		"acceleration": 58.0,
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
		"max_speed": 36.0,
		"acceleration": 68.0,
		"steer_speed": 2.4,
		"grip": 5.0,
		"braking": 44.0,
		"offroad": 9.5,
		"wheel_parts": {"FL": "part_0", "FR": "part_3", "RL": "part_2", "RR": "part_4"}
	},
	{
		"name": "Phantom",
		"model_path": "res://models/cars/Phantom.tscn",
		"model_y_rotation": PI * 0.5,
		"max_speed": 39.5,
		"acceleration": 64.0,
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
		"max_speed": 39.5,
		"acceleration": 76.0,
		"steer_speed": 2.6,
		"grip": 5.5,
		"braking": 48.0,
		"offroad": 6.5,
		"wheel_parts": {"FL": "part_0", "FR": "part_5", "RL": "part_2", "RR": "part_3"}
	}
]

var max_speed = 40.0
var reverse_speed = 19.0
var acceleration = 65.0
var braking = 40.0
var steer_speed = 2.5
var grip = 5.0

const GRAVITY = 30.0 # extra gravity so it falls faster

# Wheel/collision alignment constants
const WHEEL_RADIUS = 0.4
const WHEEL_Y_OFFSET = -0.021691  # Match the actual WheelPivot Y position to prevent hovering
const COLLISION_Y_OFFSET = 0.0  # Collision sphere center relative to body center
var collision_radius: float = 0.75
var _ground_grace: float = 0.0

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
	preload("res://sounds/freesound_community-bonk-46000.mp3")
]
const CRASH_SOUND = preload("res://sounds/crash.mp3")
const LIGHTNING_SOUND = preload("res://sounds/electric_lightning_a_#1-1782053835008.wav")
const TELEPORT_SPARK = preload("res://sprites/energy_spark.png")

@onready var visuals = $Visuals
@onready var camera_pivot = $Visuals/CameraPivot
@onready var camera = $Visuals/CameraPivot/Camera3D
@onready var name_tag = $Visuals/NameTag
@onready var engine_sound = $Visuals/EngineSound
@onready var ground_ray = $GroundRay
@onready var blob_shadow: Decal = $Visuals.get_node_or_null("BlobShadow")


var race_ui
var injected_race_ui = null  # set by Level for LOCAL_COOP; overrides scene-tree lookup
var device_id: int = -1      # -1 = keyboard, 0+ = gamepad joypad index
var splitscreen_camera: Camera3D = null  # SubViewport camera that mirrors this cart's view
var input_prefix: String = "p1_"
var _p2_prev_boost: bool = false
var _p2_prev_discard: bool = false
var _p2_prev_respawn: bool = false
var avg_wheel_y: float = -0.02
var min_wheel_bottom_y: float = -0.73
var last_respawn_time: float = -999.0

@onready var sfx_nitro_start = $Visuals/SFX_NitroStart
@onready var sfx_rocket_loop = $Visuals/SFX_RocketLoop
@onready var sfx_release_pop = $Visuals/SFX_ReleasePop
@onready var sfx_double_beep = $Visuals/SFX_DoubleBeep
@onready var sfx_beep_warning = $Visuals/SFX_BeepWarning
@onready var sfx_explosion = $Visuals/SFX_Explosion
@onready var sfx_fire_loop = $Visuals/SFX_FireLoop
@onready var boost_particles_l = $Visuals/BoostParticlesL
@onready var boost_particles_r = $Visuals/BoostParticlesR
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

var is_local_player = false
var can_move = false
var can_control = true
@export var is_ai: bool = false
var is_finished_race: bool = false
var spectate_target_cart: Node3D = null
var spectate_timer: float = 0.0
var spectate_index: int = 0
var finish_spectate_delay: float = 0.0
var spectator_zoom: float = 1.0
var _kb_brake_amount: float = 0.0
var smoothed_speed: float = 0.0
var stuck_timer: float = 0.0
var race_start_time: float = 0.0
var _ai_avoid_force: float = 0.0
var _ai_offtrack_timer: float = 0.0
var _ai_unstuck_dir: float = 0.0
var ai_item_timer: float = 0.0
var ai_lane_offset: float = 0.0
var ai_target_lane_offset: float = 0.0
var ai_lane_change_timer: float = 0.0
var ai_stuck_position_timer: float = 0.0
var ai_last_stuck_position: Vector3 = Vector3.ZERO
var _ai_want_drift: bool = false
var _ai_upcoming_turn_angle: float = 0.0
var _ai_upcoming_turn_dist: float = 40.0
var _ai_upcoming_turn_dir: float = 0.0
## AI Personality parameters
var ai_aggression: float = 0.45
var ai_shortcut_chance: float = 0.35
var ai_lane_span: float = 2.0
var ai_corner_speed_factor: float = 1.0
var ai_brake_dist_bias: float = 0.0
var ai_lookahead_mult: float = 1.0
var ai_racing_line_weight: float = 0.75
var ai_drift_threshold: float = 0.32
var ai_overtake_bias: float = 0.0
var _ai_overtake_lock_timer: float = 0.0
var _ai_start_grid_lane: float = 0.0
var _ai_may_overshoot: bool = false
var _ai_recovering: bool = false
var _ai_recover_to_checkpoint: bool = false
var _ai_recover_goal: Vector3 = Vector3.ZERO
var _ai_recover_refresh: float = 0.0
var _ai_no_progress_timer: float = 0.0
var _ai_progress_sample_pos: Vector3 = Vector3.ZERO
var _ai_fall_origin: Vector3 = Vector3.ZERO
var _ai_last_ontrack_offset: float = 0.0
## Obstacle stuck detection — tracks when the bot is pushing against a prop/rock
var _ai_obstacle_stuck_timer: float = 0.0
var _ai_obstacle_reverse_timer: float = 0.0
var _ai_obstacle_steer_dir: float = 0.0
var _ai_last_speed_sample: float = 0.0
var _ai_speed_stall_timer: float = 0.0
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
## Active pad boost multiplier (from the pad that last triggered us). 1.0 = default.
var pad_boost_strength: float = 1.0

## Maximum slope normal Y on offroad/terrain (approx 41.4°). Steeper slopes/cliffs cannot be climbed.
const MAX_DRIVABLE_SLOPE_NORMAL_Y: float = 0.75

## Mid-air tumbling angular velocity (rad/s in world space).
var air_angular_velocity: Vector3 = Vector3.ZERO
## True while smoothing the car back onto its wheels after an inverted/tilted landing.
var is_righting_on_ground: bool = false

@onready var sfx_brake_drift = $Visuals/SFX_BrakeDrift
var is_drifting: bool = false
var was_on_ground: bool = true
var air_time: float = 0.0
var ignore_next_landing_sound: bool = false
var last_crash_sound_time: float = -999.0
var wheel_rotation: float = 0.0
var is_teleporting: bool = false
var _teleport_tween: Tween = null
var _teleport_fx: CPUParticles3D = null
var _teleport_base_scales: Dictionary = {}
var is_shielded: bool = false
var was_shocked: bool = false
var camera_look_at: Vector3 = Vector3.ZERO
var camera_clip_distance_mult: float = 1.0
var camera_clip_distance_mult_iso: float = 1.0
## Loaded from MusicManager so stage changes keep the player's camera choice.
var is_isometric: bool = true
var is_intro_active: bool = false
var intro_time: float = 0.0
const INTRO_DURATION: float = 3.5
var intro_orbit_center: Vector3 = Vector3.ZERO
var hop_cooldown: float = 0.0
var drift_mode: bool = false
var drift_right: bool = false
var drift_particles = []
@export var sync_emit_drift: bool = false
var dirt_particles = []
@export var sync_emit_dirt: bool = false
var _current_dust_color: Color = Color(0.92, 0.90, 0.88)
var _is_dust_active: bool = false
var _trail_particles_ready: bool = false
static var _dust_radial_texture: Texture2D = null
var offroad_penalty: float = 1.0
var offroad_target_penalty: float = 1.0
var offroad_timer: float = 0.0
var is_offroad: bool = false
var visual_offset_y: float = 0.0

var stage_has_water: bool = false
var _harbor_stage: bool = false
var _mountain_stage: bool = false
var _wadi_stage: bool = false
var is_underwater: bool = false
const WATER_LEVEL = -10.0
## Effective surface Y used for splash/drown (may be chasm pit water, not global ocean).
var water_surface_y: float = WATER_LEVEL
## If true, only count as water when inside water_bounds_min/max on XZ.
var water_bounds_active: bool = false
var water_bounds_min: Vector2 = Vector2.ZERO # (x, z)
var water_bounds_max: Vector2 = Vector2.ZERO
## TerrainGenerator for desert_wadi influence-shaped water (optional).
var _wadi_water_tg: Node = null
var water_timer: float = 0.0
var shallow_water_timer: float = 0.0
var last_splash_time: float = -999.0
## Tracks wet/dry transitions for entry splash + hit slowdown.
var _was_in_water_zone: bool = false
var _wake_particles: GPUParticles3D = null
var is_drowned: bool = false
var _drown_tween: Tween = null
var original_wheel_transforms: Dictionary = {}
var original_cart_model_transform: Transform3D
var part_velocities: Dictionary = {}
var part_rotations: Dictionary = {}
var explosion_time: float = 0.0
var respawn_indicator_time: float = 0.0
var original_body_part_transforms: Dictionary = {}
var part_world_positions: Dictionary = {}
var part_on_ground: Dictionary = {}

# Remote interpolation tuning
const REMOTE_LERP_SPEED: float = 18.0

enum ItemType { NONE, BOOST, MISSILE, GUIDED_MISSILE, SHIELD, SHOCKWAVE, BOMB, LIGHTNING }
var current_item = ItemType.NONE
var current_item_2 = ItemType.NONE
var is_landing: bool = true
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
var _smooth_visual_up: Vector3 = Vector3.UP

# RC Antenna variables
@onready var antenna = $Visuals/Antenna
var antenna_tilt: Vector3 = Vector3.ZERO
var antenna_velocity: Vector3 = Vector3.ZERO
var antenna_accel_smooth: Vector3 = Vector3.ZERO
var last_velocity_local: Vector3 = Vector3.ZERO

# ── Performance caches ──────────────────────────────────────────────────────
# Excludes array for camera / raycast queries — rebuilt every ~90 frames
var _camera_excludes: Array = []
var _camera_excludes_counter: int = 0
const _EXCLUDES_REBUILD_INTERVAL: int = 90
# Frame counters so expensive raycasts don't run every frame
var _camera_raycast_frame: int = 0   # camera clip raycasts – every 3 render frames
var _align_raycast_frame: int = 0    # slope-alignment raycasts – every 2 render frames
var _ai_obstacle_frame: int = 0      # AI obstacle raycasts – every 3 physics frames
# Cached results from slope raycasts (reused between frames)
var _cached_align_res_front = null
var _cached_align_res_rear = null
# Cached level node reference (avoids get_first_node_in_group every frame)
var _cached_level: Node = null
# Cached camera clip state (reused when raycasts are skipped)
var _cached_iso_clip_ratio: float = 1.0
var _cached_cam_below_terrain: bool = false
var _cached_follow_clip_ratio: float = 1.0
# Shared performance tuning (phone + PC — keeps multiplayer physics cadence aligned)
var _camera_raycast_interval: int = 6
var _align_raycast_interval: int = 1
var _camera_ray_attempts: int = 2
## GeometryInstance3D nodes made semi-transparent while occluding the car.
var _xray_meshes: Dictionary = {} # instance_id -> GeometryInstance3D
var _xray_target: Dictionary = {} # instance_id -> target transparency 0..1
const _XRAY_TRANSPARENCY: float = 0.62
const _XRAY_FADE_SPEED: float = 8.0
const _ISO_CAM_CLEARANCE: float = 1.25

# AI closest offset calculation throttling
var _ai_closest_offset_frame: int = 0
var _ai_cached_offset: float = -1.0

func _refresh_name_tag() -> void:
	if not is_inside_tree():
		return
	var tag: Label3D = name_tag if name_tag != null else get_node_or_null("Visuals/NameTag")
	if tag == null:
		return
	if race_place > 0:
		tag.text = "%d. %s" % [race_place, player_name]
	else:
		tag.text = player_name

func has_physics_authority() -> bool:
	return is_local_player or (is_ai and (multiplayer.multiplayer_peer == null or is_multiplayer_authority()))

func on_race_started():
	race_start_time = Time.get_ticks_msec() / 1000.0
	ai_lane_change_timer = randf_range(3.0, 6.0)
	_ai_avoid_force = 0.0
	_ai_overtake_lock_timer = 0.0
	
	_ai_cached_offset = -1.0
	_ai_recovering = false
	_ai_recover_refresh = 0.0
	_ai_last_ontrack_offset = 0.0
	# Determine initial starting grid lane offset from world position relative to track
	if is_ai:
		var path_to_use = active_path if active_path else track_path
		if path_to_use == null:
			var lvl = get_tree().get_first_node_in_group("level")
			if lvl and "track_path" in lvl:
				path_to_use = lvl.track_path
		if path_to_use and path_to_use.curve:
			var curve = path_to_use.curve
			var local_pos = path_to_use.to_local(global_position)
			var offset = curve.get_closest_offset(local_pos)
			_ai_last_ontrack_offset = offset
			var track_center = curve.sample_baked(offset)
			var next_offset = fmod(offset + 1.0, curve.get_baked_length())
			var tangent = (curve.sample_baked(next_offset) - track_center).normalized()
			var right_vec = Vector3(-tangent.z, 0, tangent.x).normalized()
			var to_car = local_pos - track_center
			var lat_dist = right_vec.dot(to_car)
			_ai_start_grid_lane = clampf(lat_dist, -ai_lane_span, ai_lane_span)
			ai_lane_offset = _ai_start_grid_lane
			ai_target_lane_offset = _ai_start_grid_lane
		else:
			_ai_start_grid_lane = ai_lane_offset

	var has_physics_authority = has_physics_authority()
	if has_physics_authority:
		can_move = true
		freeze = false
		ignore_next_landing_sound = true  # suppress the bump when freeze releases at race start


func set_finished_race(finished: bool = true) -> void:
	is_finished_race = finished
	can_move = true
	if finished:
		finish_spectate_delay = 4.0
		current_item = ItemType.NONE
		current_item_2 = ItemType.NONE
		if is_local_player and race_ui:
			race_ui.update_items("NONE", "NONE")


@rpc("any_peer", "call_local", "reliable")
func set_finished_race_rpc(finished: bool = true) -> void:
	set_finished_race(finished)


## Called by Tornado after it spits the cart out.
func _tornado_restore_control() -> void:
	# Keep tumbling in the air briefly, then fully reset pose.
	# If we re-lock angular axes while the body is still tilted, the sphere can
	# rest permanently "hovered" / off ground for the rest of the race.
	await get_tree().create_timer(0.55).timeout
	if not is_instance_valid(self) or is_exploding or is_drowned:
		return
	if not has_physics_authority():
		return

	_reset_post_tornado_pose()

	var level = get_tree().get_first_node_in_group("level") if get_tree() else null
	var racing := true
	if level and "race_state" in level:
		# Level.RaceState.RACING == 1
		racing = int(level.race_state) == 1
	can_move = racing
	freeze = false
	sleeping = false


## Upright rigidbody, restore angular locks, clear visual hover offset.
func _reset_post_tornado_pose() -> void:
	var origin := global_position
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.0001:
		fwd = -Vector3.FORWARD
	else:
		fwd = fwd.normalized()
	# Upright transform (Y-up) before locking angular axes again
	global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), origin)

	axis_lock_angular_x = true
	axis_lock_angular_y = true
	axis_lock_angular_z = true
	angular_velocity = Vector3.ZERO

	# Clear wheel visual hover accumulated while spinning mid-air
	visual_offset_y = 0.0
	if is_instance_valid(visuals):
		visuals.top_level = true
		visuals.global_transform = global_transform

	# Nudge slightly up so we don't spawn interpenetrating the floor after uprighting
	global_position = origin + Vector3.UP * 0.15
	if linear_velocity.y < -2.0:
		linear_velocity.y = -2.0

func _ready():
	# Lock rotation so we handle it manually, preventing physics rolling at start
	axis_lock_angular_x = true
	axis_lock_angular_y = true
	axis_lock_angular_z = true

	# Trigger spawn-in drop-landing effect at start
	if has_physics_authority() and not can_move:
		is_landing = true
		freeze = false

	# Prevent rare high-speed floor tunneling at 60 Hz physics without raising tick rate.
	continuous_cd = true

	# Set initial visuals position/rotation to match spawn point transform
	# before any process frame runs, preventing wrong starting direction
	visuals.global_transform = global_transform
	visuals.top_level = true

	add_to_group("player_carts")
	_update_authority()

	if is_ai:
		_init_ai_personality()
		ai_lane_offset = randf_range(-ai_lane_span, ai_lane_span)
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

	ground_ray.add_exception(self)
	_refresh_name_tag()
	# Always draw names over water / crates / piers (especially spectator 3/4 view).
	name_tag.no_depth_test = true
	name_tag.render_priority = 32
	name_tag.outline_render_priority = 31
	name_tag.sorting_offset = 16.0
	name_tag.outline_size = 14
	name_tag.outline_modulate = Color(0, 0, 0, 0.82)
	name_tag.font_size = 40
	last_checkpoint_transform = global_transform
	camera_look_at = global_position

	# Ride height from the chassis sphere (rolls over small props; visuals plant on it)
	var collision_shape = get_node_or_null("CollisionShape3D")
	if collision_shape and collision_shape.shape is SphereShape3D:
		var s_factor: float = collision_shape.scale.y
		var base_r: float = collision_shape.shape.radius if collision_shape.shape.radius > 0.01 else 0.5
		collision_radius = base_r * s_factor
		collision_shape.transform.origin = Vector3(0, COLLISION_Y_OFFSET, 0)
	ground_ray.target_position = Vector3(0, -(collision_radius + 1.2), 0)
	
	_remove_collisions_recursive(visuals)
	_setup_new_car_wheels()
	_setup_blob_shadow()
	# Shadows follow options menu (MusicManager.shadows_enabled)
	apply_shadow_setting(MusicManager.shadows_enabled)

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

	# Looping engine sample (pitch/volume driven by speed — no procedural CPU synthesis)
	_setup_engine_sound()

	await get_tree().process_frame
	var level = get_tree().get_first_node_in_group("level")
	if level:
		_cached_level = level  # Cache for hot-path use in _process
		if "track_path" in level and level.track_path:
			track_path = level.track_path
			if active_path == null:
				active_path = track_path
		if "alternative_paths" in level and level.alternative_paths:
			alternative_paths = level.alternative_paths
		if injected_race_ui:
			race_ui = injected_race_ui  # Directly injected (LOCAL_COOP)
		elif level.has_node("RaceUI"):
			race_ui = level.get_node("RaceUI")
		var tg = level.get_node_or_null("TerrainGenerator")
		if tg and str(tg.get("level_prefix")) == "canyon_chasm":
			# Local pit water under the first jump (not full-stage ocean).
			stage_has_water = true
			water_surface_y = -1.8
			water_bounds_active = true
			water_bounds_min = Vector2(150.0 - 45.0, -90.0 - 58.0)
			water_bounds_max = Vector2(150.0 + 45.0, -90.0 + 58.0)
			var pit = tg.get_node_or_null("ChasmPitWater")
			if pit:
				if pit.has_meta("water_surface_y"):
					water_surface_y = float(pit.get_meta("water_surface_y"))
				if pit.has_meta("water_bounds_min") and pit.has_meta("water_bounds_max"):
					water_bounds_min = pit.get_meta("water_bounds_min")
					water_bounds_max = pit.get_meta("water_bounds_max")
				elif pit.has_meta("water_half_xz"):
					var half: Vector2 = pit.get_meta("water_half_xz")
					var c: Vector3 = pit.global_position
					water_bounds_min = Vector2(c.x - half.x, c.z - half.y)
					water_bounds_max = Vector2(c.x + half.x, c.z + half.y)
		elif tg and str(tg.get("level_prefix")) == "mountain":
			_mountain_stage = true
			stage_has_water = false
			water_bounds_active = false
		elif tg and str(tg.get("level_prefix")) == "harbor_pier":
			stage_has_water = true
			_harbor_stage = true
			water_surface_y = 1.55
			water_bounds_active = false
			var harbor_water = tg.get_node_or_null("HarborWater")
			if harbor_water and harbor_water.has_meta("water_surface_y"):
				water_surface_y = float(harbor_water.get_meta("water_surface_y"))
		elif tg and str(tg.get("level_prefix")) == "desert_wadi":
			# Local river + valley lake in desert_wadi.
			_wadi_stage = true
			stage_has_water = true
			water_surface_y = 1.70
			water_bounds_active = true
			water_bounds_min = Vector2(0.0, -360.0)
			water_bounds_max = Vector2(400.0, -60.0)
			_wadi_water_tg = tg
			var river = tg.get_node_or_null("WadiRiverWater")
			if river:
				if river.has_meta("water_surface_y"):
					water_surface_y = float(river.get_meta("water_surface_y"))
				if river.has_meta("water_bounds_min") and river.has_meta("water_bounds_max"):
					var bmin: Vector2 = river.get_meta("water_bounds_min")
					var bmax: Vector2 = river.get_meta("water_bounds_max")
					water_bounds_min = Vector2(minf(bmin.x, 0.0), minf(bmin.y, -360.0))
					water_bounds_max = Vector2(maxf(bmax.x, 400.0), maxf(bmax.y, -60.0))
		elif tg and "no_water" in tg:
			stage_has_water = not tg.no_water
			water_surface_y = WATER_LEVEL
			water_bounds_active = false
		else:
			stage_has_water = false

	if is_local_player:
		var is_coop = NetworkManager.current_game_mode == NetworkManager.GameMode.LOCAL_COOP
		camera.current = not is_coop  # SubViewport cameras handle rendering in co-op
		camera_pivot.top_level = true

		# Restore preferred camera across stages / races
		is_isometric = MusicManager.use_isometric_camera
		if not MusicManager.camera_mode_changed.is_connected(_on_camera_mode_setting_changed):
			MusicManager.camera_mode_changed.connect(_on_camera_mode_setting_changed)
		
		# Set initial top-view camera settings
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 35.0 if is_isometric else 75.0
		
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
			var fwd0 = -visuals.global_transform.basis.z
			camera_pivot.global_position = visuals.global_position - fwd0 * 4.5 + Vector3(0, 2.4, 0)
			camera_pivot.look_at(visuals.global_position + fwd0 * 4.0, Vector3.UP)
		
		if has_node("AudioListener3D"):
			var listener = get_node("AudioListener3D")
			listener.current = true
			listener.make_current()
			listener.global_position = global_position
	else:
		camera.current = false
		if has_node("AudioListener3D"):
			get_node("AudioListener3D").current = false

	_create_drift_particles("RL")
	_create_drift_particles("RR")
	_create_dirt_particles("RL")
	_create_dirt_particles("RR")
	_current_dust_color = _get_current_surface_dust_color()
	_apply_dust_particle_colors(_current_dust_color)
	_update_boost_particle_positions()

	# Move all car meshes to Visual Layer 2 so they do not receive Decal projections
	# (Decals are configured to only project onto Visual Layer 1)
	_set_layers_recursive(visuals, 2)

	# Trigger spawn-in drop-landing effect at start
	if has_physics_authority():
		is_landing = true
		freeze = false

	# Flush the first-emit MultiMesh / shader compile puff while the car is still spawning.
	await _prime_wheel_trail_particles()

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
		
	if NetworkManager.current_game_mode == NetworkManager.GameMode.LOCAL_COOP:
		is_local_player = not is_ai
		if id == 2:
			input_prefix = "p2_"
		else:
			input_prefix = "p1_"
	elif multiplayer.multiplayer_peer != null:
		is_local_player = (id == multiplayer.get_unique_id())
		input_prefix = "p1_"
	else:
		is_local_player = not is_ai
		input_prefix = "p1_"
	
	if is_local_player:
		contact_monitor = true
		max_contacts_reported = 4
		if not body_entered.is_connected(_on_body_entered):
			body_entered.connect(_on_body_entered)
		if has_node("AudioListener3D"):
			var listener = get_node("AudioListener3D")
			listener.current = true
			listener.make_current()
	else:
		if has_node("AudioListener3D"):
			get_node("AudioListener3D").current = false
	
	var has_physics_authority = has_physics_authority()
	if not has_physics_authority:
		freeze = true
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	elif not can_move and not is_landing:
		freeze = true
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC

func _on_body_entered(body: Node):
	if not is_local_player:
		return
	var speed = linear_velocity.length()
	if speed > 2.0:
		var magnitude = clamp(speed / max_speed, 0.15, 0.8)
		var dev = 1 if input_prefix == "p2_" else 0
		if dev in Input.get_connected_joypads():
			Input.start_joy_vibration(dev, magnitude * 0.4, magnitude * 0.7, 0.2)

func _integrate_forces(state: PhysicsDirectBodyState3D):
	if is_exploding:
		return
	_dampen_ground_bounce(state)
	if not is_local_player or not can_move:
		return
	var speed = state.linear_velocity.length()
	if speed < 8.0:
		return
	var now = Time.get_ticks_msec() / 1000.0
	if now - last_crash_sound_time < 0.6:
		return
	# Check contact normals: ground points UP (y~1), walls point sideways (y~0)
	for i in range(state.get_contact_count()):
		var normal = state.get_contact_local_normal(i)
		if abs(normal.y) < 0.5:
			# This contact is mostly horizontal = wall / obstacle / barrier
			last_crash_sound_time = now
			_play_crash_sound()
			return


func _dampen_ground_bounce(state: PhysicsDirectBodyState3D) -> void:
	# Multiple sphere colliders on bumpy trimesh inject tiny upward pops.
	# Kill those so the kart settles instead of buzzing in place.
	if hop_cooldown > 1.0:
		return
	var floor_n := Vector3.ZERO
	var floors := 0
	for i in range(state.get_contact_count()):
		var n_local: Vector3 = state.get_contact_local_normal(i)
		var n: Vector3 = (state.transform.basis * n_local).normalized()
		if n.y > 0.45:
			floor_n += n
			floors += 1
	if floors == 0:
		return
	floor_n = floor_n.normalized()
	var v: Vector3 = state.linear_velocity
	var vn: float = v.dot(floor_n)
	if vn > 0.04:
		if vn < 0.45:
			v -= floor_n * vn
		elif vn < 3.2:
			var idle: bool = v.length() < 2.2
			v -= floor_n * vn * (0.9 if idle else 0.5)
		state.linear_velocity = v
	if v.length() < 0.16:
		state.linear_velocity = Vector3.ZERO

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
		# Camera toggle (persists across stages via MusicManager)
		if Input.is_action_just_pressed(input_prefix + "toggle_camera"):
			_set_isometric_camera(not is_isometric, true)

		# Action buttons
		if Input.is_action_just_pressed(input_prefix + "respawn") and not is_finished_race:
			respawn_rpc.rpc()

		var visual_forward = -visuals.global_transform.basis.z
		var speed_factor = clamp(linear_velocity.length() / max_speed, 0.0, 1.0)
		var look_ahead_dist = (8.0 + speed_factor * 8.0) if is_isometric else (6.0 + speed_factor * 5.0)
		if splitscreen_camera != null:
			look_ahead_dist *= 0.4 # Keep camera closer to car in splitscreen to prevent going off-screen

		# Rebuild the excludes list every ~90 frames instead of every frame.
		# find_children() is a full tree traversal – doing it 60×/s was a major CPU cost.
		_camera_excludes_counter += 1
		if _camera_excludes_counter >= _EXCLUDES_REBUILD_INTERVAL or _camera_excludes.is_empty():
			_camera_excludes_counter = 0
			_camera_excludes = [self.get_rid()]
			var lvl = _cached_level if is_instance_valid(_cached_level) else get_tree().get_first_node_in_group("level")
			if lvl:
				for cp in lvl.checkpoints:
					_camera_excludes.append(cp.get_rid())
					for sb in cp.find_children("*", "StaticBody3D", true, false):
						_camera_excludes.append(sb.get_rid())
			for cart in get_tree().get_nodes_in_group("player_carts"):
				_camera_excludes.append(cart.get_rid())
		var excludes = _camera_excludes

		if is_intro_active:
			intro_time -= delta
			if intro_time <= 0.0:
				is_intro_active = false
				camera_look_at = visuals.global_position
			else:
				_update_intro_camera(delta)
		
		if not is_intro_active:
			if name_tag:
				# Follow cam sits closer; bump size so names stay readable behind the car.
				name_tag.pixel_size = 0.00035 if is_isometric or is_finished_race else 0.00095
				
			if is_finished_race and finish_spectate_delay <= 0.0:
				# Bird's-eye overview camera: Follow cars still in the race, cycling every ~10s and moving smoothly between them
				var all_carts = get_tree().get_nodes_in_group("player_carts")
				var active_racing_carts: Array[Node3D] = []
				for c in all_carts:
					if is_instance_valid(c) and c is Node3D:
						if not c.get("is_finished_race"):
							active_racing_carts.append(c)
				
				spectate_timer -= delta
				if active_racing_carts.size() > 0:
					if spectate_timer <= 0.0 or spectate_target_cart == null or not is_instance_valid(spectate_target_cart) or spectate_target_cart.get("is_finished_race"):
						spectate_timer = 10.0
						spectate_index = (spectate_index + 1) % active_racing_carts.size()
						spectate_target_cart = active_racing_carts[spectate_index]
				else:
					# All cars finished — focus on self or winner
					spectate_target_cart = self
				
				var focus_cart: Node3D = spectate_target_cart if (spectate_target_cart and is_instance_valid(spectate_target_cart)) else self
				var focus_pos: Vector3 = focus_cart.global_position
				
				# 3/4 broadcast angle (same as debug SpectatorCamera) with zoom factor
				var desired_cam_pos = focus_pos + Vector3(-42.0, 28.0, 48.0) * spectator_zoom
				var target_cam_pos = _raise_point_above_terrain(desired_cam_pos, excludes)
				
				# Smoothly glide camera between cars
				camera_pivot.global_position = camera_pivot.global_position.lerp(target_cam_pos, 2.2 * delta)
				camera_pivot.global_position = _raise_point_above_terrain(camera_pivot.global_position, excludes)
				
				var look_fwd := Vector3.FORWARD
				var focus_visuals: Node = focus_cart.get_node_or_null("Visuals")
				if focus_visuals is Node3D:
					look_fwd = -(focus_visuals as Node3D).global_transform.basis.z
					look_fwd.y = 0.0
					if look_fwd.length_squared() > 0.001:
						look_fwd = look_fwd.normalized()
					else:
						look_fwd = Vector3.FORWARD
				var target_look = focus_pos + look_fwd * 10.0 + Vector3(0, 0.8, 0)
				camera_look_at = camera_look_at.lerp(target_look, 3.5 * delta)
				camera_pivot.look_at(camera_look_at, Vector3.UP)
				
				_fade_out_all_xray(delta)
				if race_ui:
					race_ui.set_terrain_clipped(false)
				
				# Position audio listener at the spectated car so its 3D audio is heard
				if has_node("AudioListener3D"):
					var listener = get_node("AudioListener3D")
					listener.global_position = focus_pos
					if not listener.current:
						listener.current = true
						listener.make_current()
			elif is_isometric:
				var iso_offset = Vector3(-26, 26, 26)
				var desired_cam_pos = visuals.global_position + iso_offset
				var ray_start = visuals.global_position + Vector3.UP * 1.0
				
				# Throttle expensive clip raycasts
				_camera_raycast_frame += 1
				if _camera_raycast_frame >= _camera_raycast_interval:
					_camera_raycast_frame = 0
					var target_ratio = 1.0
					var space_state = get_world_3d().direct_space_state
					var query_start = ray_start
					var current_excludes = excludes.duplicate()
					var hit_block = false
					var hit_dist = 0.0
					var max_dist = ray_start.distance_to(desired_cam_pos)
					for attempt in range(_camera_ray_attempts):
						var query = PhysicsRayQueryParameters3D.create(query_start, desired_cam_pos)
						query.exclude = current_excludes
						var result = space_state.intersect_ray(query)
						if not result:
							break
						# Pull in for terrain and solid world geometry (props handled via x-ray)
						if result.collider and _is_world_collider(result.collider):
							hit_block = true
							hit_dist = ray_start.distance_to(result.position)
							break
						current_excludes.append(result.rid)
						query_start = result.position + (desired_cam_pos - query_start).normalized() * 0.1
					if hit_block and max_dist > 0.01:
						target_ratio = clamp((hit_dist - _ISO_CAM_CLEARANCE) / max_dist, 0.12, 1.0)
					_cached_iso_clip_ratio = target_ratio

				# Lerp pull-in, then clamp target above terrain so we never lerp underground
				var lerp_speed = 15.0 if _cached_iso_clip_ratio < camera_clip_distance_mult_iso else 3.0
				camera_clip_distance_mult_iso = lerp(camera_clip_distance_mult_iso, _cached_iso_clip_ratio, lerp_speed * delta)
				var target_cam_pos = ray_start + (desired_cam_pos - ray_start) * camera_clip_distance_mult_iso
				target_cam_pos = _raise_point_above_terrain(target_cam_pos, excludes)
				camera_pivot.global_position = camera_pivot.global_position.lerp(target_cam_pos, 10.0 * delta)
				# Final safety clamp after lerp (prevents clipping mid-transition)
				camera_pivot.global_position = _raise_point_above_terrain(camera_pivot.global_position, excludes)

				# Soft x-ray for props / rocks still blocking the car (not a black full-screen flash)
				_update_camera_xray(camera_pivot.global_position, visuals.global_position + Vector3.UP * 0.8, excludes, delta)
				if race_ui:
					# Only a gentle darken if still deeply under surface — smooth, never binary black
					race_ui.set_terrain_clipped(_cached_cam_below_terrain)

				var cam_fwd = Vector3(visual_forward.x, 0.0, visual_forward.z)
				if cam_fwd.length_squared() < 0.01:
					cam_fwd = Vector3.FORWARD
				else:
					cam_fwd = cam_fwd.normalized()
				camera_look_at = camera_look_at.lerp(visuals.global_position + cam_fwd * look_ahead_dist, 10.0 * delta)
				camera_pivot.look_at(camera_look_at, Vector3.UP)
			else:
				var cam_dist = lerp(5.2, 6.8, clamp(boost_time / 4.0, 0.0, 1.0))
				
				# Camera horizontal orientation: ignore mid-air tumble/pitch so camera stays stably behind the car
				var cam_fwd = Vector3(visual_forward.x, 0.0, visual_forward.z)
				if cam_fwd.length_squared() < 0.01:
					cam_fwd = Vector3.FORWARD
				else:
					cam_fwd = cam_fwd.normalized()
				
				# Downhill pitch compensation: when the car goes down a steep road (nose pointed down),
				# raise the camera up significantly so the camera is not super close to the uphill road surface behind the car.
				var downhill_amount: float = clampf(-visual_forward.y, 0.0, 0.85)
				var cam_height: float = 2.2 + downhill_amount * 3.6
				
				# Smooth camera trailing (steeper and higher when heading downhill)
				var target_cam_pos = visuals.global_position - cam_fwd * cam_dist + Vector3(0, cam_height, 0)
				
				# Throttle clip raycast (longer interval on mobile).
				_camera_raycast_frame += 1
				var ray_start = visuals.global_position + Vector3.UP * (1.0 + downhill_amount * 1.0)
				if _camera_raycast_frame >= _camera_raycast_interval:
					_camera_raycast_frame = 0
					var target_ratio = 1.0
					var space_state = get_world_3d().direct_space_state
					var query = PhysicsRayQueryParameters3D.create(ray_start, target_cam_pos)
					query.exclude = excludes
					var result = space_state.intersect_ray(query)
					if result and result.collider and _is_world_collider(result.collider):
						var hit_pos = result.position
						var max_dist = ray_start.distance_to(target_cam_pos)
						if max_dist > 0.01:
							var hit_dist = ray_start.distance_to(hit_pos)
							target_ratio = clamp((hit_dist - 0.5) / max_dist, 0.1, 1.0)
					_cached_follow_clip_ratio = target_ratio
				# Apply cached clip ratio every frame for smooth lerping
				var lerp_speed = 15.0 if _cached_follow_clip_ratio < camera_clip_distance_mult else 3.0
				camera_clip_distance_mult = lerp(camera_clip_distance_mult, _cached_follow_clip_ratio, lerp_speed * delta)
				target_cam_pos = ray_start + (target_cam_pos - ray_start) * camera_clip_distance_mult
				target_cam_pos = _raise_point_above_terrain(target_cam_pos, excludes)
				camera_pivot.global_position = camera_pivot.global_position.lerp(target_cam_pos, 10.0 * delta)
				_update_camera_xray(camera_pivot.global_position, visuals.global_position + Vector3.UP * 0.8, excludes, delta)
				if race_ui:
					race_ui.set_terrain_clipped(false)
				var target_look = visuals.global_position + cam_fwd * (look_ahead_dist + 0.5) + Vector3(0, 0.6 + downhill_amount * 0.4, 0)
				camera_look_at = camera_look_at.lerp(target_look, 12.0 * delta)
				camera_pivot.look_at(camera_look_at, Vector3.UP)
		else:
			_fade_out_all_xray(delta)
		
		# Smoothly lerp camera FOV based on is_isometric, is_finished_race, and is_boosting/is_pad_boosting
		var target_fov = 75.0
		if is_finished_race and finish_spectate_delay <= 0.0:
			target_fov = 52.0
		elif is_isometric:
			target_fov = 35.0
		else:
			target_fov = 75.0
			if is_boosting:
				target_fov += 15.0 # Zoom out when boosting!
			elif is_pad_boosting:
				target_fov += 9.0 # Zoom out slightly less when pad boosting!
		camera.fov = lerp(camera.fov, target_fov, 8.0 * delta)

		if (not is_finished_race or finish_spectate_delay > 0.0) and has_node("AudioListener3D"):
			var listener = get_node("AudioListener3D")
			listener.global_position = global_position
			if not listener.current:
				listener.current = true
				listener.make_current()

		# Mirror camera into SubViewport (LOCAL_COOP splitscreen)
		if splitscreen_camera and is_instance_valid(splitscreen_camera):
			splitscreen_camera.global_transform = camera.global_transform
			splitscreen_camera.fov = camera.fov

		if race_ui:
			smoothed_speed = lerp(smoothed_speed, linear_velocity.length() * 1.8, 10.0 * delta)
			race_ui.update_speed(smoothed_speed)
			
			var cam_underwater = false
			if camera and camera.is_inside_tree() and stage_has_water:
				var cam_pos: Vector3 = camera.global_position
				var over_water := true
				if water_bounds_active:
					over_water = cam_pos.x >= water_bounds_min.x and cam_pos.x <= water_bounds_max.x \
							and cam_pos.z >= water_bounds_min.y and cam_pos.z <= water_bounds_max.y
				cam_underwater = over_water and cam_pos.y < water_surface_y
			race_ui.set_underwater(cam_underwater)

		# Engine loop — same input path as driving (p1_/p2_), not the bare "throttle" action
		var throttle_input: float
		if device_id == -1:
			throttle_input = Input.get_axis(input_prefix + "throttle", input_prefix + "brake")
		else:
			var t = Input.get_joy_axis(device_id, JOY_AXIS_TRIGGER_RIGHT)
			var b = Input.get_joy_axis(device_id, JOY_AXIS_TRIGGER_LEFT)
			throttle_input = b - t
		# Play when throttling/braking OR moving so coasting still has engine presence
		var wants_to_play = can_move and not is_exploding and (
			abs(throttle_input) > 0.08 or linear_velocity.length() > 1.5
		)
		
		if wants_to_play:
			if engine_sound.stream == null:
				_setup_engine_sound()
			if not engine_sound.playing:
				engine_sound.play()
				engine_sound.volume_db = -32.0
			var speed_ratio = clamp(linear_velocity.length() / max_speed, 0.0, 1.0)
			var target_vol = lerp(-32.0, -22.0, speed_ratio)
			if is_boosting:
				target_vol += 2.0
			engine_sound.volume_db = move_toward(engine_sound.volume_db, target_vol, 25.0 * delta)
			var target_pitch = lerp(0.80, 1.35, speed_ratio)
			if is_boosting:
				target_pitch *= 1.12
			elif is_pad_boosting:
				target_pitch *= 1.06
			engine_sound.pitch_scale = move_toward(engine_sound.pitch_scale, target_pitch, 2.5 * delta)
		else:
			if engine_sound.playing:
				engine_sound.volume_db = move_toward(engine_sound.volume_db, -45.0, 15.0 * delta)
				engine_sound.pitch_scale = move_toward(engine_sound.pitch_scale, 0.8, 1.5 * delta)
				if engine_sound.volume_db <= -44.9:
					engine_sound.stop()
	elif not has_physics_authority:
		_interpolate_remote_visual(delta)

	# Update top-level drift and dirt particle emitters continuously so transforms are always fresh
	for p in drift_particles:
		if is_instance_valid(p) and p is CPUParticles3D:
			if not p.emitting:
				_update_idle_trail_emitter(p)
				continue
			_clear_trail_stopped_meta(p)
			var pivot = p.get_meta("pivot", null)
			if is_instance_valid(pivot):
				if p.name.ends_with("_Skid"):
					# Raycast directly beneath this specific wheel to get exact road/terrain surface and normal
					var n: Vector3 = Vector3.UP
					var mark_pos: Vector3 = pivot.global_position + pivot.global_transform.basis * Vector3(0, 0, 0.12)
					mark_pos.y = pivot.global_position.y + WHEEL_Y_OFFSET + 0.03
					
					var space_state = get_world_3d().direct_space_state
					if space_state:
						var query = PhysicsRayQueryParameters3D.create(
							pivot.global_position + Vector3(0, 0.4, 0),
							pivot.global_position + Vector3(0, -1.2, 0)
						)
						query.exclude = [get_rid()]
						query.collision_mask = 1
						var hit = space_state.intersect_ray(query)
						if hit:
							n = hit.normal.normalized()
							mark_pos = hit.position + n * 0.025
					
					# Compute motion velocity of the wheel contact point
					var vel: Vector3 = linear_velocity
					if not has_physics_authority and sync_velocity.length_squared() > 0.5:
						vel = sync_velocity
					var wheel_offset: Vector3 = mark_pos - global_position
					var wheel_vel: Vector3 = vel
					if has_physics_authority and angular_velocity.length_squared() > 0.01:
						wheel_vel += angular_velocity.cross(wheel_offset)
					
					# Project wheel motion onto the ground surface normal
					var move_on_ground: Vector3 = wheel_vel - n * wheel_vel.dot(n)
					var fwd_plane: Vector3
					if move_on_ground.length_squared() >= 0.25:
						# Align skid mark quad with the wheel's actual path of motion across the ground
						fwd_plane = move_on_ground.normalized()
					else:
						# Fallback for stationary or near-zero speed (e.g. burnout / standing still)
						var fwd_sk: Vector3 = -visuals.global_transform.basis.z
						fwd_plane = fwd_sk - n * fwd_sk.dot(n)
						if fwd_plane.length_squared() < 0.0001:
							fwd_plane = -visuals.global_transform.basis.z
						else:
							fwd_plane = fwd_plane.normalized()
					
					var right_sk: Vector3 = n.cross(fwd_plane)
					if right_sk.length_squared() < 0.0001:
						p.global_rotation = Vector3(0.0, visuals.global_rotation.y, 0.0)
					else:
						right_sk = right_sk.normalized()
						fwd_plane = right_sk.cross(n).normalized()
						p.global_transform.basis = Basis(right_sk, n, -fwd_plane)
					p.global_position = mark_pos
				else:
					# Smoke behind tire contact patch
					p.global_rotation = pivot.global_rotation
					p.global_position = pivot.global_position + pivot.global_transform.basis * Vector3(0, -0.22, 0.16)

	for p in dirt_particles:
		if is_instance_valid(p) and p is CPUParticles3D:
			if not p.emitting:
				_update_idle_trail_emitter(p)
				continue
			_clear_trail_stopped_meta(p)
			var pivot = p.get_meta("pivot", null)
			if is_instance_valid(pivot):
				_attach_dirt_emitter(p, pivot)

func _physics_process(delta):
	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			slow_timer = 0.0

	if hop_cooldown > 0:
		hop_cooldown -= delta

	if is_teleporting:
		return

	if global_position.y < -50 and not is_finished_race:
		if multiplayer.multiplayer_peer != null and multiplayer.is_server():
			respawn_rpc.rpc()
		elif is_local_player or (is_ai and multiplayer.multiplayer_peer == null):
			respawn() # single-player / host fallback

	var has_physics_authority = has_physics_authority()
	# Safety net for discrete physics steps: recover if we punched through terrain while falling.
	if has_physics_authority and not is_exploding and not is_teleporting:
		_prevent_floor_tunneling(delta)

	# AI Stuck & Off-Track Fall Detection
	if is_ai and can_move and not is_exploding and not is_finished_race and respawn_indicator_time <= 0.0 and has_physics_authority:
		ai_stuck_position_timer += delta
		if ai_stuck_position_timer >= 2.8:
			ai_stuck_position_timer = 0.0
			var dist = global_position.distance_to(ai_last_stuck_position)
			# While recovering, keep circling — don't warp out just for sitting near a pillar.
			if dist < 2.5 and not _ai_recovering:
				print("AI Cart ", name, " detected stuck (distance traveled in 2.8s: ", dist, "m). Respawning.")
				if multiplayer.multiplayer_peer != null and multiplayer.is_server():
					respawn_rpc.rpc()
				else:
					respawn()
			ai_last_stuck_position = global_position
		
		# Check if cart has fallen off track (e.g. fallen down a cliff, bridge or ravine)
		var check_path = active_path if active_path else track_path
		if check_path == null:
			var lvl = get_tree().get_first_node_in_group("level")
			if lvl and "track_path" in lvl:
				check_path = lvl.track_path
		if check_path and check_path.curve:
			var curve = check_path.curve
			var cur_off: float = _ai_last_ontrack_offset if _ai_last_ontrack_offset >= 0.0 else curve.get_closest_offset(check_path.to_local(global_position))
			var track_pt = check_path.to_global(curve.sample_baked(cur_off))
			var height_below = track_pt.y - global_position.y
			var dist_xz = Vector2(global_position.x - track_pt.x, global_position.z - track_pt.z).length()
			var is_fallen_off: bool = height_below > 10.0 and (is_offroad or air_time > 0.8 or dist_xz > 16.0)
			if is_fallen_off:
				if _ai_offtrack_timer <= 0.001:
					_ai_fall_origin = global_position
				_ai_offtrack_timer += delta
				if global_position.distance_to(_ai_progress_sample_pos) > 4.0:
					_ai_progress_sample_pos = global_position
					_ai_no_progress_timer = 0.0
				else:
					_ai_no_progress_timer += delta
				var stray: float = Vector2(global_position.x - _ai_fall_origin.x, global_position.z - _ai_fall_origin.z).length()
				# Don't tour the hills. If they wandered far from the fall, teleport back.
				var no_progress: bool = _ai_no_progress_timer > 4.5 and linear_velocity.length() < 2.0
				# Keep trying toward the next gate; only give up if stuck or truly lost.
				var too_far: bool = stray > 70.0 and no_progress
				var recover_limit: float = 14.0 if _ai_recovering else 8.0
				if too_far or (_ai_offtrack_timer > recover_limit and no_progress):
					print("AI Cart ", name, " fallen off course (dist xz: ", dist_xz, "m, height below: ", height_below, "m). Respawning.")
					_ai_offtrack_timer = 0.0
					_ai_no_progress_timer = 0.0
					_ai_recovering = false
					if multiplayer.multiplayer_peer != null and multiplayer.is_server():
						respawn_rpc.rpc()
					else:
						respawn()
			else:
				_ai_offtrack_timer = 0.0
				_ai_no_progress_timer = 0.0
				_ai_recovering = false
	else:
		ai_stuck_position_timer = 0.0
		_ai_offtrack_timer = 0.0
		ai_last_stuck_position = global_position

	if is_exploding:
		if not is_drowned:
			if has_physics_authority:
				# Apply realistic game gravity to bring the tumbling wreck down
				apply_central_force(Vector3.DOWN * GRAVITY * mass)

				# Ground contact check beneath the tumbling wreck
				var on_ground = false
				if is_instance_valid(ground_ray):
					ground_ray.global_transform.basis = Basis.IDENTITY
					if ground_ray.is_colliding() and ground_ray.get_collision_normal().y >= 0.15:
						on_ground = true
				if not on_ground:
					var space_state = get_world_3d().direct_space_state
					if space_state:
						var query = PhysicsRayQueryParameters3D.create(
							global_position,
							global_position + Vector3.DOWN * (collision_radius + 0.6)
						)
						query.exclude = [get_rid()]
						query.collision_mask = 1
						var hit = space_state.intersect_ray(query)
						if hit and hit.normal.y >= 0.15:
							on_ground = true

				# Momentum loss: high ground friction vs moderate air drag
				if on_ground:
					linear_velocity.x = move_toward(linear_velocity.x, 0.0, 22.0 * delta)
					linear_velocity.z = move_toward(linear_velocity.z, 0.0, 22.0 * delta)
					angular_velocity = angular_velocity.move_toward(Vector3.ZERO, 14.0 * delta)
					if linear_velocity.length() < 0.2:
						linear_velocity = Vector3.ZERO
						angular_velocity = Vector3.ZERO
				else:
					linear_velocity.x = move_toward(linear_velocity.x, 0.0, 3.0 * delta)
					linear_velocity.z = move_toward(linear_velocity.z, 0.0, 3.0 * delta)
					angular_velocity = angular_velocity.move_toward(Vector3.ZERO, 1.5 * delta)

			var under_water_now := false
			if stage_has_water and _is_over_water_volume():
				var w_depth: float = water_surface_y - global_position.y
				if w_depth > 0.2:
					under_water_now = true
			if is_underwater or under_water_now:
				if burning_particles.emitting:
					burning_particles.emitting = false
				if burning_smoke_particles.emitting:
					burning_smoke_particles.emitting = false
				if fire_sprite_particles.emitting:
					fire_sprite_particles.emitting = false
				if fire_sprite_particles_2.emitting:
					fire_sprite_particles_2.emitting = false
				if sfx_fire_loop.playing:
					sfx_fire_loop.stop()
			else:
				if sfx_fire_loop.playing:
					sfx_fire_loop.volume_db = lerp(sfx_fire_loop.volume_db, -10.0, 2.0 * delta)
				burning_particles.global_position = global_position + Vector3(0, 0.4, 0)
				burning_smoke_particles.global_position = global_position + Vector3(0, 0.5, 0)

		if has_physics_authority:
			_move_and_sync()
		else:
			_interpolate_remote_physics(delta)
		return

	if stage_has_water:
		# Depth relative to surface: positive = below surface (submerged)
		var water_depth: float = water_surface_y - global_position.y
		var in_water_xz := _is_over_water_volume()
		# True contact with water: car's wheels touch water surface (tires reach down to ~ -0.80m from body origin)
		var in_water_contact := in_water_xz and water_depth >= -0.80
		# Shallow / ford: touching or wading through water — spray and light drag
		var in_shallow_water := in_water_contact and water_depth < 0.75
		# Deep water only (hull submerged): can eventually drown
		var in_deep_water := in_water_contact and water_depth >= 0.75
		# Hysteresis for "underwater" VFX / deep state
		var currently_underwater = is_underwater
		if is_underwater:
			if not in_water_xz or water_depth < 0.70:
				currently_underwater = false
		else:
			if in_deep_water:
				currently_underwater = true

		var entered_water_zone := false
		if currently_underwater != is_underwater:
			if currently_underwater:
				entered_water_zone = true
			else:
				# --- Exit deep water ---
				var current_time = Time.get_ticks_msec() / 1000.0
				last_splash_time = current_time
				var splash_pos = Vector3(global_position.x, water_surface_y, global_position.z)
				_spawn_splash(splash_pos, 0.4)
			is_underwater = currently_underwater
			if not is_underwater:
				water_timer = 0.0

		var boosting_in_water := boost_timer > 0.0 or pad_boost_timer > 0.0

		# First contact with any water (shallow ford or deep dive) — splash + hit
		if in_water_contact and not _was_in_water_zone:
			entered_water_zone = true
		if entered_water_zone:
			var current_time2 = Time.get_ticks_msec() / 1000.0
			if current_time2 - last_splash_time > 0.15:
				last_splash_time = current_time2
				var impact_speed = linear_velocity.length()
				var splash_stream: AudioStream = null
				if impact_speed > 12.0 or in_deep_water:
					splash_stream = DEEP_SPLASH_SOUNDS[randi() % DEEP_SPLASH_SOUNDS.size()]
				else:
					splash_stream = REGULAR_SPLASH_SOUNDS[randi() % REGULAR_SPLASH_SOUNDS.size()]
				if splash_stream:
					var ap = AudioStreamPlayer3D.new()
					ap.stream = splash_stream
					ap.bus = &"SFX"
					ap.max_distance = 80.0
					ap.unit_size = 15.0
					ap.volume_db = 2.0
					get_tree().current_scene.add_child(ap)
					ap.global_position = global_position
					ap.play()
					get_tree().create_timer(splash_stream.get_length() + 0.5).timeout.connect(ap.queue_free)
				# Heavy entry slowdown only for deep water (shallow fords maintain drivability)
				if in_deep_water and not boosting_in_water:
					linear_velocity *= 0.08
					if linear_velocity.y < 0.0:
						linear_velocity.y = 0.0
				var splash_pos2 = Vector3(global_position.x, water_surface_y, global_position.z)
				_spawn_splash(splash_pos2, 1.15 if in_deep_water else 0.55)
		_was_in_water_zone = in_water_contact

		# --- Spray while moving through water + wake trail ---
		var on_flat_ground = false
		if ground_ray.is_colliding() and ground_ray.get_collision_normal().y >= 0.55:
			on_flat_ground = true
		var wet_moving := in_water_contact and not in_deep_water and water_depth < 0.70 and linear_velocity.length() > 2.5
		if wet_moving:
			var spray_interval: float = 0.16 if linear_velocity.length() > 12.0 else 0.26
			if boosting_in_water:
				spray_interval *= 0.65
			var current_time3 = Time.get_ticks_msec() / 1000.0
			if current_time3 - last_splash_time > spray_interval:
				last_splash_time = current_time3
				var splash_scale: float = 0.32 if in_shallow_water else 0.45
				if boosting_in_water:
					splash_scale *= 1.35
				# Side sprays from wheel positions
				var right_vec: Vector3 = visuals.global_transform.basis.x
				var back_vec: Vector3 = visuals.global_transform.basis.z
				var base_p: Vector3 = Vector3(global_position.x, water_surface_y, global_position.z)
				_spawn_splash(base_p - right_vec * 0.55 + back_vec * 0.2, splash_scale)
				_spawn_splash(base_p + right_vec * 0.55 + back_vec * 0.2, splash_scale * 0.9)
		_update_water_wake(wet_moving, delta)

		# Continuous water drag — not applied while boosting
		if in_water_contact and not boosting_in_water:
			var water_speed_cap: float = max_speed * (0.22 if in_deep_water else 0.55)
			var h_vel = Vector3(linear_velocity.x, 0.0, linear_velocity.z)
			if h_vel.length() > water_speed_cap:
				var damped = h_vel.normalized() * water_speed_cap
				var drag_lerp: float = 12.0 if in_deep_water else 6.0
				linear_velocity.x = lerp(linear_velocity.x, damped.x, drag_lerp * delta)
				linear_velocity.z = lerp(linear_velocity.z, damped.z, drag_lerp * delta)
			linear_velocity.x *= (1.0 - clampf((2.8 if in_deep_water else 1.2) * delta, 0.0, 0.35))
			linear_velocity.z *= (1.0 - clampf((2.8 if in_deep_water else 1.2) * delta, 0.0, 0.35))

		if in_deep_water:
			water_timer += delta
			shallow_water_timer = 0.0
			# Drown after sustained deep submersion
			if water_timer > 2.5 and not is_finished_race:
				if multiplayer.multiplayer_peer != null and multiplayer.is_server():
					drown_rpc.rpc()
				elif multiplayer.multiplayer_peer == null:
					drown()
			apply_central_force(Vector3.UP * 12.0)
		elif in_water_contact:
			water_timer = maxf(0.0, water_timer - delta * 1.5)
			# If a car stands / is stuck longer than 5 seconds in shallow water, trigger drown respawn
			if linear_velocity.length() < 2.5:
				shallow_water_timer += delta
				if shallow_water_timer > 5.0 and not is_finished_race:
					if multiplayer.multiplayer_peer != null and multiplayer.is_server():
						drown_rpc.rpc()
					elif multiplayer.multiplayer_peer == null:
						drown()
			else:
				shallow_water_timer = maxf(0.0, shallow_water_timer - delta * 1.5)
		else:
			water_timer = 0.0
			shallow_water_timer = 0.0

	if not has_physics_authority:
		_interpolate_remote_physics(delta)
		return

	# Align ground ray with visual orientation so it points along the vehicle's local down axis.
	if is_instance_valid(ground_ray):
		ground_ray.global_transform.basis = visuals.global_transform.basis

	# Apply extra gravity (reduced / cancelled while stuck in a loop so inverted sections work)
	if not (ground_ray.is_colliding() and _is_loop_surface(ground_ray.get_collider())):
		apply_central_force(Vector3.DOWN * GRAVITY * mass)
	else:
		# Stick into the loop surface (centripetal + contact glue)
		var loop_n: Vector3 = ground_ray.get_collision_normal()
		var spd: float = linear_velocity.length()
		var stick: float = mass * (spd * spd / 14.0 + 28.0)
		apply_central_force(-loop_n * stick)
		# Soft world-gravity while inverted so cars don't peel off mid-loop
		var invert: float = clampf(1.0 - loop_n.y, 0.0, 1.0)
		apply_central_force(Vector3.DOWN * GRAVITY * mass * (1.0 - invert * 0.85))

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
		if ground_ray.is_colliding() and (ground_ray.get_collision_normal().y >= 0.15 or _is_loop_surface(ground_ray.get_collider())):
			var hit_point: Vector3 = ground_ray.get_collision_point()
			var dist_to_hit: float = ground_ray.global_position.distance_to(hit_point)
			# Only consider landed when the collision sphere has actually reached the ground
			if dist_to_hit <= collision_radius + 0.08:
				is_landing = false
				var ground_norm: Vector3 = ground_ray.get_collision_normal()
				# Snap to exact ground contact level to eliminate floating on start grid
				global_position = hit_point + ground_norm * collision_radius
				linear_velocity = Vector3.ZERO
				angular_velocity = Vector3.ZERO
				# Play landing sound only for gameplay respawns, not during initial start countdown
				if can_move:
					play_landing_sound_rpc(1.5)
				# Freeze if the race hasn't started yet so car rests firmly on the starting grid
				if not can_move:
					freeze = true
					freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC

	if is_finished_race and finish_spectate_delay > 0.0:
		finish_spectate_delay -= delta

	if is_local_player and not is_finished_race:
		if Input.is_action_just_pressed(input_prefix + "boost"):
			_use_item()
		if Input.is_action_just_pressed(input_prefix + "discard_item"):
			_discard_item()

	if not can_move and not is_landing:
		linear_velocity = linear_velocity.lerp(Vector3.ZERO, 3.0 * delta)
		_move_and_sync()
		return

	var input_dir = Vector2.ZERO
	if can_move:
		if is_ai or is_finished_race:
			input_dir = _get_ai_input(delta)
			if not is_finished_race:
				_process_ai_items(delta)
		else:
			input_dir.x = Input.get_axis(input_prefix + "steer_left", input_prefix + "steer_right")
			
			var raw_throttle: float = Input.get_action_strength(input_prefix + "throttle")
			var raw_brake: float = Input.get_action_strength(input_prefix + "brake")
			
			# If using gamepad with analog trigger, use raw_brake directly.
			# If using keyboard (device_id == -1 or digital button), ramp up brake force gradually.
			if device_id != -1 and raw_brake > 0.0 and raw_brake < 0.99:
				_kb_brake_amount = raw_brake
			else:
				if raw_brake > 0.05:
					if _kb_brake_amount < 0.20:
						_kb_brake_amount = 0.20 # gentle initial bite for fine adjustments
					_kb_brake_amount = move_toward(_kb_brake_amount, 1.0, 1.65 * delta)
				else:
					_kb_brake_amount = move_toward(_kb_brake_amount, 0.0, 6.0 * delta)
			
			var effective_brake: float = _kb_brake_amount if raw_brake > 0.05 else 0.0
			input_dir.y = effective_brake - raw_throttle

	var on_ground = false
	var on_loop = false
	var ground_normal = Vector3.UP
	var ground_collider: Object = null

	# Check ground ray along vehicle local down with strict tire contact distance
	if ground_ray.is_colliding():
		var hit_pt = ground_ray.get_collision_point()
		var dist_to_ground = global_position.distance_to(hit_pt)
		var norm = ground_ray.get_collision_normal()
		var col = ground_ray.get_collider()
		var loop = _is_loop_surface(col)
		# Generous slop so crests / steep roads do not flicker to "airborne"
		if dist_to_ground <= (collision_radius + 0.38) and (norm.y >= 0.12 or loop):
			on_ground = true
			on_loop = loop
			ground_normal = norm
			ground_collider = col

	# If local ground_ray didn't hit (e.g. car is tilted or flipped on its back),
	# check world-down ray to detect ground contact beneath the sphere
	if not on_ground:
		var space_state = get_world_3d().direct_space_state
		if space_state:
			var query = PhysicsRayQueryParameters3D.create(
				global_position,
				global_position + Vector3.DOWN * (collision_radius + 0.45)
			)
			query.exclude = [get_rid()]
			query.collision_mask = 1
			var hit = space_state.intersect_ray(query)
			if hit:
				var hit_pos: Vector3 = hit.position
				var dist_down = global_position.distance_to(hit_pos)
				var norm: Vector3 = hit.normal
				var col = hit.get("collider")
				var loop = _is_loop_surface(col)
				if dist_down <= (collision_radius + 0.38) and (norm.y >= 0.12 or loop):
					on_ground = true
					on_loop = loop
					ground_normal = norm
					ground_collider = col

	if on_ground:
		_ground_grace = 0.22
	else:
		_ground_grace = maxf(0.0, _ground_grace - delta)
	var drive_grounded: bool = on_ground or _ground_grace > 0.0

	if not on_ground:
		air_time += delta
		if was_on_ground:
			_set_dirt_emitting(false)
			_set_drift_emitting(false)
		# Mid-air tumbling / flips (free 3D rotation, never clamped horizontal in air)
		if air_angular_velocity.length_squared() > 0.001:
			var rot_axis = air_angular_velocity.normalized()
			var rot_angle = air_angular_velocity.length() * delta
			visuals.global_rotate(rot_axis, rot_angle)
			air_angular_velocity = air_angular_velocity.lerp(Vector3.ZERO, 0.5 * delta)
		is_righting_on_ground = false
	else:
		if not was_on_ground:
			var time_since_respawn = (Time.get_ticks_msec() / 1000.0) - last_respawn_time
			var is_descending = linear_velocity.y < -1.0 or linear_velocity.dot(-ground_normal) > 1.0
			if not can_move or is_landing or time_since_respawn < 0.6 or ignore_next_landing_sound or air_time < 0.15 or not is_descending:
				ignore_next_landing_sound = false
			else:
				if multiplayer.multiplayer_peer != null:
					play_landing_sound_rpc.rpc(air_time)
				else:
					play_landing_sound_rpc(air_time)
		air_time = 0.0

		# Auto-righting: if car lands on its back or heavily tilted, smoothly turn/flip back onto wheels
		var cur_up = visuals.global_transform.basis.y
		var up_dot = cur_up.dot(ground_normal)
		if up_dot < 0.92:
			if not is_righting_on_ground and up_dot < 0.2:
				# Gentle hop when flipped upside down so wheels clear ground to roll over
				apply_central_impulse(Vector3.UP * mass * 3.5)
			is_righting_on_ground = true
			air_angular_velocity = Vector3.ZERO
			var fwd_cand = -visuals.global_transform.basis.z
			var proj_fwd = fwd_cand - ground_normal * fwd_cand.dot(ground_normal)
			if proj_fwd.length_squared() < 0.01:
				var r_cand = visuals.global_transform.basis.x
				var proj_r = (r_cand - ground_normal * r_cand.dot(ground_normal)).normalized()
				proj_fwd = ground_normal.cross(proj_r).normalized()
			else:
				proj_fwd = proj_fwd.normalized()
			var target_r = proj_fwd.cross(ground_normal).normalized()
			var target_f = ground_normal.cross(target_r).normalized()
			var upright_basis = Basis(target_r, ground_normal, -target_f)
			# Smooth roll recovery animation over ~0.6s
			var recovery_speed: float = 3.8
			visuals.global_transform.basis = visuals.global_transform.basis.slerp(upright_basis, 1.0 - exp(-recovery_speed * delta))
		else:
			is_righting_on_ground = false
	was_on_ground = on_ground

	is_offroad = false
	if on_ground and not on_loop:
		var collider = ground_collider if ground_collider else ground_ray.get_collider()
		if collider:
			is_offroad = not _is_track_surface(collider)

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

	# Slope direction calculations
	var downhill_vec = Vector3.DOWN - ground_normal * Vector3.DOWN.dot(ground_normal)
	var downhill_dir = Vector3.ZERO
	if downhill_vec.length_squared() > 0.0001:
		downhill_dir = downhill_vec.normalized()
	var uphill_dir = -downhill_dir
	var heading_uphill: float = fwd.dot(uphill_dir) if downhill_dir != Vector3.ZERO else 0.0

	# Slope gravity slide: smooth slide down steep offroad hills/cliffs (only when truly offroad and on ground)
	if is_offroad and on_ground and not on_loop and ground_normal.y < 0.85 and downhill_dir != Vector3.ZERO:
		var slope_steepness = clampf((0.85 - ground_normal.y) / 0.85, 0.0, 1.0)
		var slide_force_mag = GRAVITY * mass * slope_steepness * 1.2
		apply_central_force(downhill_dir * slide_force_mag)

	# Offroad steep cliff classification (only offroad, on ground, steep rock face > 65°):
	# Dunes / drivable slopes: Normal.y >= 0.45 -> Drivable
	# Sheer vertical cliffs: Normal.y < 0.45 -> Engine power cut when driving straight into it
	var is_steep_cliff: bool = is_offroad and on_ground and not on_loop and ground_normal.y < 0.45
	var uphill_power_factor: float = 1.0
	var uphill_speed_cap_factor: float = 1.0
	if is_offroad and on_ground and not on_loop and ground_normal.y < 0.78:
		if ground_normal.y < 0.45:
			uphill_power_factor = 0.0
			uphill_speed_cap_factor = 0.0
		else:
			var t_slope = (ground_normal.y - 0.45) / (0.78 - 0.45)
			uphill_power_factor = lerpf(0.2, 1.0, t_slope)
			uphill_speed_cap_factor = lerpf(0.4, 1.0, t_slope)

	current_steer = lerp(current_steer, input_dir.x, 10.0 * delta)

	# Handle acceleration/braking even when slightly airborne for better control
	var current_speed = linear_velocity.dot(fwd)

	# Tap-to-drift logic (evaluate early so drift_mode is active during the braking/physics forces block)
	if on_ground and Input.is_action_just_pressed("brake") and abs(input_dir.x) > 0.2 and current_speed > 5.0:
		drift_mode = true
		drift_right = input_dir.x > 0.0
	elif is_ai and _ai_want_drift and on_ground and abs(input_dir.x) > 0.22 and current_speed > 6.0:
		drift_mode = true
		drift_right = input_dir.x > 0.0

	# Auto-hop over small props/steps only when nearly stuck offroad — completely disabled on road/track/ramps.
	if is_offroad and on_ground and not on_loop and input_dir.y < -0.5 and hop_cooldown <= 0.0:
		var hop_speed: float = linear_velocity.length()
		# Only when stalled / blocked offroad against an obstacle (never normal road driving)
		if hop_speed >= 0.1 and hop_speed <= 3.0:
			var space_state = get_world_3d().direct_space_state
			if space_state:
				# Short bumper ray, slightly above ground so flat terrain rarely hits
				var ray_start = global_position + fwd * 0.55 + Vector3.UP * 0.22
				var ray_end = global_position + fwd * 1.05 + Vector3.UP * 0.08
				var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
				query.exclude = [self.get_rid()]
				var result = space_state.intersect_ray(query)
				if result:
					var col = result.collider
					var is_drive_surface := _is_track_surface(col)
					if not is_drive_surface:
						var hit_n: Vector3 = result.normal
						# Need a wall-ish face in front of us (not a gentle slope)
						var faces_us: float = -hit_n.dot(fwd)
						var upright: float = 1.0 - clampf(hit_n.y, 0.0, 1.0)
						var local_hit = global_transform.inverse() * result.position
						# Low curb/prop lip only (wheel/bumper band)
						var height_ok: bool = local_hit.y > -0.35 and local_hit.y < 0.38
						if height_ok and faces_us > 0.45 and upright > 0.45 and hit_n.y < 0.60:
							var up_kick: float = 2.0
							apply_central_impulse(Vector3.UP * up_kick * mass + fwd * 0.8 * mass)
							hop_cooldown = 1.5

	var slow_mult = 1.0
	if slow_timer > 0.0:
		slow_mult = 0.6

	var cliff_block = is_offroad and on_ground and not on_loop and is_steep_cliff and heading_uphill > 0.15

	if is_boosting:
		# Boost cap: fixed absolute speed ceiling (58.0 m/s) so faster cars benefit less
		var boost_cap = 58.0
		var max_sp = min(max_speed * 1.5, boost_cap) * slow_mult
		var accel_force = acceleration * 2.0 * slow_mult
		if cliff_block:
			accel_force = 0.0
		elif is_offroad and heading_uphill > 0.05:
			accel_force *= lerpf(1.0, uphill_power_factor, clampf(heading_uphill * 1.5, 0.0, 1.0))
		if current_speed < max_sp:
			var fwd_vec = fwd if drive_grounded else Vector3(fwd.x, 0.0, fwd.z).normalized()
			apply_central_force(fwd_vec * accel_force * mass)
		boost_time += delta
	elif is_pad_boosting:
		# Pad boost: strength comes from the BoostPad that triggered us (inspector).
		var str_m: float = maxf(pad_boost_strength, 0.1)
		var boost_cap = 54.0 * str_m
		var max_sp = min(max_speed * (1.0 + 0.4 * str_m), boost_cap) * slow_mult
		var accel_force = acceleration * 1.8 * str_m * slow_mult
		if cliff_block:
			accel_force = 0.0
		elif is_offroad and heading_uphill > 0.05:
			accel_force *= lerpf(1.0, uphill_power_factor, clampf(heading_uphill * 1.5, 0.0, 1.0))
		if current_speed < max_sp:
			var fwd_vec = fwd if drive_grounded else Vector3(fwd.x, 0.0, fwd.z).normalized()
			apply_central_force(fwd_vec * accel_force * mass)
		boost_time += delta
	
	if input_dir.y < -0.1: # Forward input
		if not is_boosting:
			var input_scale = abs(input_dir.y)
			var accel_force = acceleration * slow_mult * input_scale
			if drift_mode:
				# Power-slide: keep pushing while rear is loose
				accel_force *= 1.08
				var side_sign: float = 1.0 if drift_right else -1.0
				apply_central_force(right * side_sign * acceleration * 0.18 * mass * input_scale)
			var speed_cap: float = max_speed * offroad_penalty * slow_mult * input_scale
			if is_offroad and heading_uphill > 0.05:
				accel_force *= lerpf(1.0, uphill_power_factor, clampf(heading_uphill * 1.5, 0.0, 1.0))
				speed_cap *= lerpf(1.0, uphill_speed_cap_factor, clampf(heading_uphill * 1.5, 0.0, 1.0))
			if cliff_block:
				accel_force = 0.0
				speed_cap = 0.0
			if drift_mode:
				speed_cap *= 0.92
			if current_speed < speed_cap:
				var fwd_vec = fwd if drive_grounded else Vector3(fwd.x, 0.0, fwd.z).normalized()
				apply_central_force(fwd_vec * accel_force * mass)
			boost_time += delta
	elif input_dir.y > 0.1: # Brake / Reverse input
		boost_time = 0.0
		var input_scale = abs(input_dir.y)
		if not on_ground:
			# Ignore braking and reversing while airborne
			pass
		elif is_boosting:
			# If boosting, braking just reduces the boost effectiveness a bit
			apply_central_force(-fwd * braking * 0.4 * mass * input_scale)
		elif drift_mode:
			# Brake-hold drift: light scrub only — keep slide momentum
			apply_central_force(-fwd * braking * 0.18 * mass * input_scale)
			var side_sign: float = 1.0 if drift_right else -1.0
			apply_central_force(right * side_sign * acceleration * 0.12 * mass * input_scale)
		else:
			if is_finished_race:
				if current_speed > 0.3:
					apply_central_force(-fwd * braking * 1.25 * mass * input_scale)
				elif current_speed < -0.3:
					apply_central_force(fwd * braking * 1.25 * mass * input_scale)
				else:
					linear_velocity = Vector3.ZERO
					angular_velocity = Vector3.ZERO
			elif current_speed > 1.0:
				# Softer brakes + progressive (less grab at high speed)
				var spd_t: float = clampf(current_speed / maxf(max_speed, 1.0), 0.0, 1.0)
				var brake_mul: float = lerpf(0.78, 0.62, spd_t)
				apply_central_force(-fwd * braking * brake_mul * mass * input_scale)
			elif current_speed < -0.5:
				if current_speed > -reverse_speed * offroad_penalty * input_scale:
					var accel_force = acceleration * 0.5 * input_scale
					var rev_uphill = (-fwd).dot(uphill_dir)
					var rev_cliff_block = is_offroad and on_ground and not on_loop and is_steep_cliff and rev_uphill > 0.15
					if rev_cliff_block:
						accel_force = 0.0
					elif is_offroad and rev_uphill > 0.05:
						accel_force *= lerpf(1.0, uphill_power_factor, clampf(rev_uphill * 1.5, 0.0, 1.0))
					apply_central_force(-fwd * accel_force * mass)
			else:
				if current_speed > -reverse_speed * offroad_penalty * input_scale:
					var accel_force = acceleration * 0.7 * input_scale
					var rev_uphill = (-fwd).dot(uphill_dir)
					var rev_cliff_block = is_offroad and on_ground and not on_loop and is_steep_cliff and rev_uphill > 0.15
					if rev_cliff_block:
						accel_force = 0.0
					elif is_offroad and rev_uphill > 0.05:
						accel_force *= lerpf(1.0, uphill_power_factor, clampf(rev_uphill * 1.5, 0.0, 1.0))
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
				var spd = linear_velocity.length()
				# Shallow slope threshold (normal.y >= 0.95 = slope angle < ~18 degrees)
				# Coast naturally with gentle rolling resistance, locking only when nearly stopped
				if ground_normal.y >= 0.95 or not is_offroad:
					if spd < 0.15:
						linear_velocity = Vector3.ZERO
						angular_velocity = Vector3.ZERO
					elif spd < 0.7:
						linear_velocity = linear_velocity.move_toward(Vector3.ZERO, 6.0 * delta)
					else:
						# Gentle natural rolling resistance for smooth roll-out
						apply_central_force(-linear_velocity * 0.45 * mass)
				else:
					# Steep offroad slopes: allow natural downhill slide with light drag
					apply_central_force(-linear_velocity * 0.20 * mass)

	# Steering (works on ground and airborne)
	if on_ground or linear_velocity.length() > 0.5:
		if linear_velocity.length() > 1.0:
			# Exit drift mode if:
			# - they release brake (input_dir.y < 0.1)
			# - car comes to a stop (current_speed < 3.0)
			if drift_mode:
				# Keep power-slide when brake→accel with steer held
				if current_speed < 2.5:
					drift_mode = false
				elif abs(input_dir.x) < 0.12 and input_dir.y < -0.1:
					drift_mode = false
				elif abs(input_dir.x) < 0.15 and abs(input_dir.y) <= 0.1:
					drift_mode = false
			
			var turn_speed = steer_speed
			is_drifting = drift_mode
			
			var play_brake_sfx = on_ground and (is_drifting or (input_dir.y > 0.2 and current_speed > 5.0))
			if play_brake_sfx:
				if not sfx_brake_drift.playing: sfx_brake_drift.play()
			else:
				if sfx_brake_drift.playing: sfx_brake_drift.stop()
			
			if is_drifting:
				if input_dir.y > 0.1:
					turn_speed *= 1.85
				else:
					turn_speed *= 1.55
			
			var steer_speed_factor: float
			if current_speed < -0.1:
				# Reversing: invert steering yaw direction so turning right swings rear right & nose left
				steer_speed_factor = clampf(abs(current_speed) / 3.0, 0.5, 1.0)
				turn_speed = -turn_speed * 1.2
			elif current_speed < 3.0:
				# Low speed forward maneuver (pulling away from stop/obstacle): maintain minimum responsiveness
				steer_speed_factor = clampf(current_speed / 8.0, 0.4, 1.0)
			else:
				steer_speed_factor = minf(current_speed / 10.0, 1.0)

			var steer_amount = -current_steer * turn_speed * steer_speed_factor * delta
			var rot_axis = ground_normal if on_ground else Vector3.UP
			visuals.global_rotate(rot_axis, steer_amount)
			
			# Lateral grip and steering redirection
			if on_ground:
				# On asphalt, cancel gravity's sideways pull so steep roads track straight
				# instead of sliding downhill until speed builds.
				if not is_offroad and not on_loop:
					var g_accel: float = GRAVITY + float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
					var lat_g: float = Vector3.DOWN.dot(right) * g_accel
					apply_central_force(-right * lat_g * mass)
				var lat_vel = linear_velocity.dot(right)
				var grip_factor = grip
				if is_drifting:
					if input_dir.y < -0.1:
						grip_factor *= 0.30 # Power-slide
					else:
						grip_factor *= 0.20 # Brake drift
				if is_offroad and ground_normal.y < 0.82:
					# Scale grip down as the slope gets steeper; drops to 0.15 on cliffs so car slides down
					if ground_normal.y < 0.55:
						grip_factor *= 0.15
					else:
						var slope_factor = clampf((ground_normal.y - 0.55) / (0.82 - 0.55), 0.15, 1.0)
						grip_factor *= slope_factor
				apply_central_force(-right * lat_vel * mass * grip_factor)
			else:
				# Air control: strictly horizontal trajectory redirection (zero vertical lift)
				var right_h = Vector3(right.x, 0.0, right.z)
				if right_h.length_squared() > 0.001:
					right_h = right_h.normalized()
					var lat_vel_h = linear_velocity.dot(right_h)
					apply_central_force(-right_h * lat_vel_h * mass * (grip * 0.35))
			
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
		
		# No air steering — car cannot rotate mid-air
		pass

	# Wind sound (only after a real jump — not crest flicker)
	if can_move and not on_ground and air_time > 0.45 and linear_velocity.length() > 5.0:
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

	# Emit dirt particles when offroad, moving, and NOT in water
	var in_water_now := stage_has_water and (is_underwater or (water_surface_y - global_position.y >= -0.80 and _is_over_water_volume()))
	var emit_dirt = is_offroad and on_ground and linear_velocity.length() > 2.0 and not in_water_now
	_set_dirt_emitting(emit_dirt)
	sync_emit_dirt = emit_dirt

	sync_steer = current_steer
	if on_ground and not on_loop and hop_cooldown <= 1.0:
		var vn: float = linear_velocity.dot(ground_normal)
		if vn > 0.04 and vn < 2.2:
			var idle_drive: bool = absf(input_dir.x) < 0.1 and absf(input_dir.y) < 0.1 and not is_boosting and not is_pad_boosting
			linear_velocity -= ground_normal * vn * (0.85 if idle_drive else 0.28)
		if absf(input_dir.x) < 0.08 and absf(input_dir.y) < 0.08 and not is_boosting and not is_pad_boosting:
			if linear_velocity.length() < 0.85:
				linear_velocity = linear_velocity.move_toward(Vector3.ZERO, 8.0 * delta)
			if linear_velocity.length() < 0.18:
				linear_velocity = Vector3.ZERO
				angular_velocity = Vector3.ZERO
	_move_and_sync()

const ENGINE_SOUND_PATH := "res://sounds/freesound_community-engine-6000_edited.wav"

func _setup_engine_sound() -> void:
	if engine_sound == null:
		return
	var base_stream: AudioStream = engine_sound.stream
	if base_stream == null and ResourceLoader.exists(ENGINE_SOUND_PATH):
		base_stream = load(ENGINE_SOUND_PATH) as AudioStream
	if base_stream == null:
		push_warning("PlayerCart: engine sound missing at ", ENGINE_SOUND_PATH)
		return
	var engine_stream: AudioStream = base_stream.duplicate()
	if engine_stream is AudioStreamWAV:
		var wav := engine_stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		# loop_end is in frames; -1 is unreliable after compress/import on some builds
		var bytes_per_sample := 2
		match wav.format:
			AudioStreamWAV.FORMAT_8_BITS:
				bytes_per_sample = 1
			AudioStreamWAV.FORMAT_16_BITS:
				bytes_per_sample = 2
			_:
				bytes_per_sample = 2
		if wav.stereo:
			bytes_per_sample *= 2
		if wav.data.size() > 0 and bytes_per_sample > 0:
			wav.loop_end = int(wav.data.size() / bytes_per_sample)
	elif engine_stream is AudioStreamMP3:
		(engine_stream as AudioStreamMP3).loop = true
	elif engine_stream is AudioStreamOggVorbis:
		(engine_stream as AudioStreamOggVorbis).loop = true
	engine_sound.stream = engine_stream
	engine_sound.pitch_scale = 1.0
	engine_sound.volume_db = -32.0
	engine_sound.unit_size = 6.0
	engine_sound.max_distance = 45.0
	engine_sound.attenuation_filter_cutoff_hz = 16000.0
	engine_sound.bus = &"SFX"


func _is_blocking_prop(collider: Object) -> bool:
	if collider == null or not (collider is Node):
		return false
	if collider.is_in_group("player_carts"):
		return true
	var current: Node = collider as Node
	while current:
		var nm := str(current.name).to_lower()
		# Track, roads, bridges, ramps, unified terrain and decks are never blocking props!
		if current.is_in_group("track_surface") or current.is_in_group("loop_track") or current.is_in_group("ramps"):
			return false
		if nm.contains("road") or nm.contains("track") or nm.contains("bridge") or nm.contains("ramp") or nm.contains("terrain") or nm.contains("unified_world") or nm.contains("deck") or nm.contains("pier") or nm.contains("dock"):
			return false
		if nm.contains("rock") or nm.contains("tree") or nm.contains("cactus") or nm.contains("prop") \
				or nm.contains("crate") or nm.contains("barrel") or nm.contains("boulder") \
				or nm.contains("log") or nm.contains("statue") or nm.contains("vegetation") \
				or nm.contains("foliage") or nm.contains("plant") or nm.contains("bush") \
				or nm.contains("palm") or nm.contains("pillar") or nm.contains("column") \
				or nm.contains("wall") or nm.contains("barrier") or nm.contains("fence") \
				or nm.contains("building") or nm.contains("house") or nm.contains("windmill") \
				or nm.contains("staticbody"):
			return true
		current = current.get_parent()
	return false


func _is_world_terrain_collider(collider: Object) -> bool:
	if collider == null or not (collider is Node):
		return false
	var current: Node = collider as Node
	while current:
		var nm := str(current.name).to_lower()
		if nm.contains("unified_world") or nm.contains("terrain_visual") \
				or nm.contains("terrain_collision") or nm == "terraingenerator":
			return true
		current = current.get_parent()
	return false


func _is_track_surface(collider: Object) -> bool:
	if collider == null:
		return false
	if not (collider is Node):
		return false
	# Props sitting on the asphalt are not the road — even when the car is on-track.
	if _is_blocking_prop(collider):
		return false
	var n: Node = collider as Node
	var current: Node = n
	while current:
		if current.is_in_group("loop_track") or current.is_in_group("track_surface") or current.is_in_group("ramps"):
			return true
		var nm := str(current.name).to_lower()
		if nm.contains("track") or nm.contains("road") \
				or nm.contains("ramp") or nm.contains("bridge") \
				or nm.contains("loop") or nm.contains("deck") \
				or nm.contains("jump") or nm.contains("curb") \
				or nm.contains("pier") or nm.contains("harbor") \
				or nm.contains("dune") or nm.contains("checkpoint") \
				or nm.contains("finishline") or nm.contains("gate"):
			return true
		current = current.get_parent()

	# Terrain/dirt on top of a buried road is still off-road (dust, penalty).
	if _is_world_terrain_collider(n):
		return false

	return false


func _get_track_outer_half_width() -> float:
	var lvl: Node = _cached_level if is_instance_valid(_cached_level) else get_tree().get_first_node_in_group("level")
	if lvl:
		var tg = lvl.get_node_or_null("TerrainGenerator")
		if tg:
			if "track_layout_type" in tg and int(tg.track_layout_type) == 2:
				# Canyon: rounded shoulder extends past asphalt.
				var rw: float = float(tg.road_width) if "road_width" in tg else 15.0
				return rw * 0.5 + 2.6
			if "sand_width" in tg:
				return float(tg.sand_width) * 0.5
			if "road_width" in tg:
				return float(tg.road_width) * 0.5
	return 8.5


func _is_loop_surface(collider: Object) -> bool:
	if collider == null:
		return false
	if not (collider is Node):
		return false
	var n: Node = collider as Node
	var current: Node = n
	while current:
		if current.is_in_group("loop_track"):
			return true
		var nm := str(current.name)
		if nm.contains("LoopPiece") or nm.contains("LoopCSG") or nm.contains("LoopTube"):
			return true
		current = current.get_parent()
	return false


func _is_over_water_volume() -> bool:
	if not stage_has_water:
		return false
	if not water_bounds_active:
		return true
	var p := global_position
	if not (p.x >= water_bounds_min.x and p.x <= water_bounds_max.x \
			and p.z >= water_bounds_min.y and p.z <= water_bounds_max.y):
		return false
	# Desert wadi: check if ground is below water surface or influence test
	if is_instance_valid(_wadi_water_tg):
		if _wadi_water_tg.has_method("is_wadi_water_at") and _wadi_water_tg.call("is_wadi_water_at", p.x, p.z):
			return true
		# Fallback check: terrain height below or near water surface
		var th: float = _get_ground_height(p)
		if th > -900.0 and th <= water_surface_y + 0.20:
			return true
		return false
	return true


func _prevent_floor_tunneling(delta: float) -> void:
	# Soft terminal fall speed so discrete steps (60 Hz) stay within CCD range.
	const MAX_FALL_SPEED := 48.0
	if linear_velocity.y < -MAX_FALL_SPEED:
		linear_velocity.y = -MAX_FALL_SPEED

	# Only run the recovery ray on hard falls while airborne — cheap early-out.
	# If already on ground driving along a road/slope, never zero downward speed!
	if linear_velocity.y > -12.0 or was_on_ground or air_time < 0.1:
		return
	var world = get_world_3d()
	if world == null:
		return
	var space = world.direct_space_state
	if space == null:
		return

	# Sweep from where we roughly were last step, down through the sphere bottom.
	var step = maxf(delta, 1.0 / 60.0)
	var travel = absf(linear_velocity.y) * step
	var start = global_position + Vector3.UP * (collision_radius + 0.5 + travel)
	var end = global_position + Vector3.DOWN * (collision_radius + 0.6 + travel * 0.25)
	var query = PhysicsRayQueryParameters3D.create(start, end)
	query.exclude = [get_rid()]
	query.collision_mask = 1
	var hit = space.intersect_ray(query)
	if hit.is_empty():
		return
	var n: Vector3 = hit.normal
	if n.y < 0.35 and not _is_loop_surface(hit.get("collider")):
		return # steep wall / junk hit — leave alone

	var min_center_y = hit.position.y + collision_radius + 0.04
	if global_position.y >= min_center_y:
		return

	# Snap out of penetration and cancel only the velocity directed INTO the surface normal,
	# preserving tangential downhill velocity.
	global_position.y = min_center_y
	var vel_into_normal: float = linear_velocity.dot(n)
	if vel_into_normal < 0.0:
		linear_velocity -= n * vel_into_normal


func _get_ground_visual_offset() -> float:
	# Fixed visual offset: mathematically anchors wheels to the bottom of the collision sphere
	# with a 1.5cm ground contact planting offset so tires are firmly grounded without gaps
	const GROUND_PLANT_OFFSET = 0.015
	return collision_radius + min_wheel_bottom_y + GROUND_PLANT_OFFSET

func _update_visuals_alignment(delta: float) -> void:
	if is_exploding:
		if is_drowned:
			visuals.global_position = global_position
			return
		visuals.global_transform = global_transform
		return

	var fixed_offset = _get_ground_visual_offset()

	# Determine ground normal from primary ground ray
	var on_ground = false
	var target_up = Vector3.UP
	var on_loop_vis = false

	if is_instance_valid(ground_ray):
		ground_ray.global_transform.basis = visuals.global_transform.basis
		if ground_ray.is_colliding():
			var norm = ground_ray.get_collision_normal()
			var col = ground_ray.get_collider()
			on_loop_vis = _is_loop_surface(col)
			if norm.y >= 0.15 or on_loop_vis:
				on_ground = true
				target_up = norm

	# Soft spring: ease ride height instead of snapping every bump
	var compress: float = 0.0
	if on_ground:
		compress = clampf(linear_velocity.y * -0.035, -0.07, 0.10)
	visual_offset_y = lerpf(visual_offset_y, fixed_offset + compress, 1.0 - exp(-11.0 * delta))

	if on_ground:
		_smooth_visual_up = _smooth_visual_up.slerp(target_up, 1.0 - exp(-8.0 * delta))
		if _smooth_visual_up.length_squared() > 0.001:
			target_up = _smooth_visual_up.normalized()
		else:
			target_up = Vector3.UP
	else:
		_smooth_visual_up = Vector3.UP
		target_up = Vector3.UP

	if not on_ground:
		# In air: do not clamp horizontal! Visual orientation is free to tumble / flip.
		var target_pos_air = get_global_transform_interpolated().origin - visuals.global_transform.basis.y * visual_offset_y
		visuals.global_position = target_pos_air
		_update_wheel_visuals(delta)
		return

	# If currently auto-righting from an inverted landing, let the recovery slerp take precedence
	if is_righting_on_ground:
		var target_pos_rec = get_global_transform_interpolated().origin - visuals.global_transform.basis.y * visual_offset_y
		visuals.global_position = target_pos_rec
		_update_wheel_visuals(delta)
		return

	# Smoothly align the visual mesh normal to terrain slope (no horizontal clamp!)
	var current_basis = visuals.global_transform.basis
	var forward = -current_basis.z

	var target_forward = (forward - target_up * forward.dot(target_up)).normalized()
	if target_forward.length_squared() < 0.001:
		target_forward = -current_basis.z
	var target_right = target_forward.cross(target_up).normalized()
	target_forward = target_up.cross(target_right).normalized()

	var target_basis = Basis(target_right, target_up, -target_forward)
	if is_drifting:
		var drift_angle = -0.35 if drift_right else 0.35
		var up_axis = target_up.normalized()
		if up_axis.length_squared() > 0.5:
			target_basis = target_basis.rotated(up_axis, drift_angle)
	visuals.global_transform.basis = current_basis.slerp(target_basis, 1.0 - exp(-9.0 * delta))

	var target_pos = get_global_transform_interpolated().origin - target_up * visual_offset_y
	visuals.global_position = target_pos

	_update_wheel_visuals(delta)

func _wheel_steer_sign(along_fwd: float) -> float:
	# In reverse the visual turn must flip so wheels point with the path.
	return -1.0 if along_fwd < -0.35 else 1.0


func _update_wheel_visuals(delta):
	if is_exploding: return
	var speed = linear_velocity.length()
	var fwd_dot = linear_velocity.dot(-visuals.global_transform.basis.z)
	var rot_speed = speed * sign(fwd_dot) / 0.4 # approx radius
	wheel_rotation -= rot_speed * delta

	for corner in ["FL", "FR", "RL", "RR"]:
		var pivot = get_node_or_null("Visuals/WheelPivot" + corner)
		if not pivot:
			continue
		# Steering: rotate the pivot on its Y axis for front wheels
		if corner == "FL" or corner == "FR":
			pivot.rotation.y = -current_steer * 0.5 * _wheel_steer_sign(fwd_dot)
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
	visual_offset_y = lerp(visual_offset_y, target_offset, 1.0 - exp(-16.0 * delta))
	var target_pos = get_global_transform_interpolated().origin - target_up * visual_offset_y

	# Align visuals position directly to eliminate visual lag/pulsing
	visuals.global_position = target_pos

	var speed := sync_velocity.length()
	var wheel_spin_rate := speed / 0.4
	wheel_rotation -= wheel_spin_rate * delta

	var remote_fwd_dot = sync_velocity.dot(-visuals.global_transform.basis.z)

	for wheel in ["FL", "FR", "RL", "RR"]:
		var pivot = get_node_or_null("Visuals/WheelPivot" + wheel)
		if not pivot:
			continue
		if wheel == "FL" or wheel == "FR":
			pivot.rotation.y = -sync_steer * 0.5 * _wheel_steer_sign(remote_fwd_dot)
		var mesh_node = pivot.get_node_or_null("WheelMesh")
		if mesh_node:
			mesh_node.rotation.x = wheel_rotation

	_update_blob_shadow()
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

	# Compute exact lowest wheel geometry Y in Visuals-local coordinates
	var lowest_y: float = 999.0
	var found_lowest: bool = false
	for corner in ["FL", "FR", "RL", "RR"]:
		var pivot = get_node_or_null("Visuals/WheelPivot" + corner)
		if pivot:
			var mesh_node = pivot.get_node_or_null("WheelMesh")
			if mesh_node:
				var wheel_min_y = _get_node_hierarchy_lowest_y(mesh_node, visuals)
				if not found_lowest or wheel_min_y < lowest_y:
					lowest_y = wheel_min_y
					found_lowest = true
	if found_lowest:
		min_wheel_bottom_y = lowest_y
	else:
		min_wheel_bottom_y = avg_wheel_y - 0.28

	if cart_model:
		original_cart_model_transform = cart_model.transform

	_update_boost_particle_positions()

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

# Finds the lowest Y position in ref_node's local space among all meshes under node
func _get_node_hierarchy_lowest_y(node: Node, ref_node: Node3D) -> float:
	var lowest_points: Array = []
	_collect_mesh_lowest_points(node, ref_node, lowest_points)
	if lowest_points.is_empty():
		return ref_node.to_local(node.global_position).y
	var min_val: float = lowest_points[0]
	for p in lowest_points:
		if p < min_val:
			min_val = p
	return min_val

func _collect_mesh_lowest_points(node: Node, ref_node: Node3D, points: Array):
	if node is MeshInstance3D and node.mesh:
		var aabb = node.get_aabb()
		var pos = aabb.position
		var sz = aabb.size
		var corners = [
			pos,
			pos + Vector3(sz.x, 0, 0),
			pos + Vector3(0, sz.y, 0),
			pos + Vector3(0, 0, sz.z),
			pos + Vector3(sz.x, sz.y, 0),
			pos + Vector3(sz.x, 0, sz.z),
			pos + Vector3(0, sz.y, sz.z),
			pos + sz
		]
		for c in corners:
			var world_c = node.global_transform * c
			var ref_c = ref_node.to_local(world_c)
			points.append(ref_c.y)
	for child in node.get_children():
		_collect_mesh_lowest_points(child, ref_node, points)


func _move_and_sync():
	sync_position = global_position
	# Store visual rotation, not rigid body rotation (which is locked)
	sync_rotation = visuals.global_rotation
	sync_velocity = linear_velocity
	sync_rotation_quat = visuals.global_transform.basis.get_rotation_quaternion()
	_update_blob_shadow()

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
			var is_real_peer = name.to_int() > 0 and not is_ai and NetworkManager.current_game_mode == NetworkManager.GameMode.MULTIPLAYER
			if is_real_peer:
				client_start_boost.rpc_id(name.to_int())
			else:
				client_start_boost()
			for tornado in get_tree().get_nodes_in_group("tornados"):
				if tornado and is_instance_valid(tornado) and tornado.has_method("escape_cart_with_boost"):
					tornado.escape_cart_with_boost(self)
		ItemType.MISSILE:
			_fire_missile(false)
		ItemType.GUIDED_MISSILE:
			_fire_missile(true)
		ItemType.SHIELD:
			var is_real_peer = name.to_int() > 0 and not is_ai and NetworkManager.current_game_mode == NetworkManager.GameMode.MULTIPLAYER
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

func _play_crash_sound() -> void:
	if sfx_landing_bonk == null: return
	sfx_landing_bonk.stream = CRASH_SOUND
	sfx_landing_bonk.unit_size = 40.0
	sfx_landing_bonk.max_distance = 180.0
	sfx_landing_bonk.volume_db = 6.0
	sfx_landing_bonk.play()

@rpc("any_peer", "call_local", "unreliable")
func play_landing_sound_rpc(p_air_time: float):
	if LANDING_SOUNDS.is_empty(): return
	var sound = LANDING_SOUNDS[0]
	sfx_landing_bonk.stream = sound
	sfx_landing_bonk.unit_size = 35.0
	sfx_landing_bonk.max_distance = 150.0
	# Map descent impact to punchy volume_db [2.0, 9.0]
	var volume = lerpf(2.0, 9.0, clampf(p_air_time / 0.6, 0.0, 1.0))
	sfx_landing_bonk.volume_db = volume
	sfx_landing_bonk.play()

@rpc("any_peer", "call_local", "reliable")
func client_start_boost():
	boost_timer = 2.0
	is_boosting = true
	sfx_nitro_start.play()
	_set_boost_emitting(true)
	for tornado in get_tree().get_nodes_in_group("tornados"):
		if tornado and is_instance_valid(tornado) and tornado.has_method("escape_cart_with_boost"):
			tornado.escape_cart_with_boost(self)

@rpc("any_peer", "call_local", "reliable")
func client_start_pad_boost(strength: float = 1.0, duration: float = 2.0):
	pad_boost_strength = maxf(strength, 0.1)
	pad_boost_timer = maxf(duration, 0.1)
	is_pad_boosting = true
	for tornado in get_tree().get_nodes_in_group("tornados"):
		if tornado and is_instance_valid(tornado) and tornado.has_method("escape_cart_with_boost"):
			tornado.escape_cart_with_boost(self)
	
	# Play swoosh sound (stereogenicstudio-swish-swoosh-woosh-sfx-47-357152.mp3)
	var ap = AudioStreamPlayer3D.new()
	ap.stream = preload("res://sounds/stereogenicstudio-swish-swoosh-woosh-sfx-47-357152.mp3")
	ap.bus = &"SFX"
	ap.volume_db = -8.0
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
			# Simulate detached wheels in world space
			for part in part_velocities.keys():
				if is_instance_valid(part):
					if part_on_ground.get(part, false):
						part.global_position = part_world_positions.get(part, part.global_position)
						continue

					part_velocities[part].y -= GRAVITY * delta
					part_velocities[part].x = move_toward(part_velocities[part].x, 0.0, 2.0 * delta)
					part_velocities[part].z = move_toward(part_velocities[part].z, 0.0, 2.0 * delta)
					var cur_pos: Vector3 = part_world_positions.get(part, part.global_position) + part_velocities[part] * delta
					part_world_positions[part] = cur_pos

					var ground_y = _get_ground_height(cur_pos)
					if ground_y != -999.0 and cur_pos.y <= ground_y + 0.15:
						part_on_ground[part] = true
						part_velocities[part] = Vector3.ZERO
						part_rotations[part] = Vector3.ZERO
						cur_pos.y = ground_y + 0.15
						part_world_positions[part] = cur_pos
					else:
						part.rotate_x(part_rotations[part].x * delta)
						part.rotate_y(part_rotations[part].y * delta)
						part.rotate_z(part_rotations[part].z * delta)
					part.global_position = cur_pos

			# Fade out in the last second (3.2s to 4.2s)
			if explosion_time > 3.2:
				var alpha = clampf(1.0 - (explosion_time - 3.2), 0.0, 1.0)
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
			part_world_positions.clear()
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
	_set_boost_emitting(is_boosting)
		
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
		var is_real_peer = name.to_int() > 0 and not get("is_ai") and NetworkManager.current_game_mode == NetworkManager.GameMode.MULTIPLAYER
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
	# Eagle/tornado must drop us immediately (bomb + missile share this path)
	_clear_external_captures()
	# Eagle freeze would block explosion tumble + leave freeze stuck after respawn
	if has_physics_authority():
		freeze = false
		sleeping = false
	
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

	var in_water_already := is_underwater
	if stage_has_water and _is_over_water_volume():
		if water_surface_y - global_position.y > 0.2:
			in_water_already = true

	if not in_water_already:
		sfx_fire_loop.play()
		burning_particles.emitting = true
		burning_smoke_particles.emitting = true
		fire_sprite_particles.emitting = true
		fire_sprite_particles_2.emitting = true
	else:
		burning_particles.emitting = false
		burning_smoke_particles.emitting = false
		fire_sprite_particles.emitting = false
		fire_sprite_particles_2.emitting = false
		sfx_fire_loop.stop()

	explosion_particles.emitting = true
	if engine_sound.playing: engine_sound.stop()
	
	visuals.visible = true
	_set_visuals_alpha(1.0)
	if name_tag:
		name_tag.modulate.a = 1.0
		
	var has_phys_auth = has_physics_authority()
	if has_phys_auth:
		freeze = false
		sleeping = false
		axis_lock_angular_x = false
		axis_lock_angular_y = false
		axis_lock_angular_z = false

		# Impulse: keep most forward momentum + add a moderate upward tumble
		var current_speed = linear_velocity.length()
		var forward_component = -visuals.global_transform.basis.z * minf(current_speed * 0.6, 18.0)
		var blast_dir = Vector3(randf_range(-0.4, 0.4), 1.0, randf_range(-0.4, 0.4)).normalized()
		linear_velocity = forward_component + blast_dir * randf_range(5.0, 8.0)
		angular_velocity = Vector3(
			randf_range(-7.0, 7.0),
			randf_range(-4.0, 4.0),
			randf_range(-7.0, 7.0)
		)

	if is_local_player:
		var dev = 1 if input_prefix == "p2_" else 0
		if dev in Input.get_connected_joypads():
			Input.start_joy_vibration(dev, 0.6, 0.9, 0.5)

	# Setup detached wheels in world space
	part_velocities.clear()
	part_rotations.clear()
	part_world_positions.clear()
	part_on_ground.clear()
	original_body_part_transforms.clear()

	for corner in ["FL", "FR", "RL", "RR"]:
		var pivot = get_node_or_null("Visuals/WheelPivot" + corner)
		if pivot:
			var local_dir = Vector3.ZERO
			match corner:
				"FL": local_dir = Vector3(1.2, 1.1, 0.8)
				"FR": local_dir = Vector3(-1.2, 1.1, 0.8)
				"RL": local_dir = Vector3(1.2, 1.1, -0.8)
				"RR": local_dir = Vector3(-1.2, 1.1, -0.8)
			var world_dir = (visuals.global_transform.basis * local_dir + Vector3(randf_range(-0.3, 0.3), randf_range(0.2, 0.6), randf_range(-0.3, 0.3))).normalized()
			part_velocities[pivot] = world_dir * randf_range(6.0, 11.0)
			part_rotations[pivot] = Vector3(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0), randf_range(-14.0, 14.0))
			part_world_positions[pivot] = pivot.global_position

	if multiplayer.multiplayer_peer != null and multiplayer.is_server():
		get_tree().create_timer(4.2).timeout.connect(func():
			if is_instance_valid(self) and not is_finished_race:
				respawn_rpc.rpc()
		)
	elif multiplayer.multiplayer_peer == null:
		get_tree().create_timer(4.2).timeout.connect(func():
			if is_instance_valid(self) and not is_finished_race:
				respawn()
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
	# Same as explode: drop eagle/tornado so freeze/can_move aren't left stuck
	_clear_external_captures()
	
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
	_drown_tween.tween_callback(func():
		if is_instance_valid(visuals):
			visuals.visible = false
	)
	
	if multiplayer.multiplayer_peer != null and multiplayer.is_server():
		get_tree().create_timer(1.2).timeout.connect(func():
			if is_instance_valid(self) and not is_finished_race:
				respawn_rpc.rpc()
		)
	elif multiplayer.multiplayer_peer == null:
		get_tree().create_timer(1.2).timeout.connect(func():
			if is_instance_valid(self) and not is_finished_race:
				respawn()
		)

@rpc("any_peer", "call_local", "reliable")
func respawn_rpc():
	respawn()

func respawn():
	# Finished racers must not snap back to the finish gate (last checkpoint).
	if is_finished_race or is_teleporting:
		return
	_start_respawn_teleport()


func _start_respawn_teleport() -> void:
	is_teleporting = true
	can_move = false
	if has_physics_authority():
		freeze = true
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
	if _teleport_tween:
		_teleport_tween.kill()
	_teleport_tween = create_tween()
	var skip_vanish: bool = is_drowned or not visuals.visible
	if skip_vanish:
		_teleport_tween.tween_callback(_teleport_appear)
	else:
		_capture_teleport_scales()
		_burst_teleport_fx(global_position)
		MusicManager.play_sfx("res://sounds/stereogenicstudio-swish-swoosh-woosh-sfx-47-357152.mp3", -10.0, 1.15)
		_teleport_tween.tween_method(_teleport_vanish_step, 0.0, 1.0, 0.40)
		_teleport_tween.tween_callback(_teleport_appear)


func _teleport_vanish_step(t: float) -> void:
	if _teleport_base_scales.is_empty():
		_capture_teleport_scales()
	_set_body_visual_scale(lerpf(1.0, 0.05, t * t))
	_set_teleport_glow(t)
	_set_visuals_alpha(lerpf(1.0, 0.2, t))


func _teleport_appear() -> void:
	_apply_respawn_pose()
	# Keep the scales captured before vanish. Recapturing here stored the
	# already-shrunk chassis and left only the restored wheels at full size.
	if _teleport_base_scales.is_empty():
		_capture_teleport_scales()
	_set_body_visual_scale(0.05)
	_set_teleport_glow(1.0)
	_set_visuals_alpha(0.25)
	visuals.visible = true
	_burst_teleport_fx(global_position)
	if _teleport_tween:
		_teleport_tween.kill()
	_teleport_tween = create_tween()
	_teleport_tween.tween_method(_teleport_appear_step, 0.0, 1.0, 0.45)
	_teleport_tween.tween_callback(_teleport_finish)


func _teleport_appear_step(t: float) -> void:
	var s: float = lerpf(0.05, 1.0, t * t * (3.0 - 2.0 * t))
	_set_body_visual_scale(s)
	_set_teleport_glow(1.0 - t)
	_set_visuals_alpha(lerpf(0.25, 1.0, t))


func _teleport_finish() -> void:
	_set_body_visual_scale(1.0)
	_set_teleport_glow(0.0)
	_set_visuals_alpha(1.0)
	_teleport_base_scales.clear()
	is_teleporting = false
	var finished := false
	var level = get_tree().get_first_node_in_group("level")
	var id = name.to_int()
	if level and level.player_stats.has(id):
		finished = level.player_stats[id]["finished"]
	can_move = not finished
	if has_physics_authority():
		freeze = false
		sleeping = false
	respawn_indicator_time = 0.7


func _capture_teleport_scales() -> void:
	_teleport_base_scales.clear()
	if visuals == null:
		return
	for child in visuals.get_children():
		if child == camera_pivot or child == name_tag or child == blob_shadow or child is Decal or child is AudioStreamPlayer3D or child is AudioStreamPlayer:
			continue
		if child is Node3D:
			_teleport_base_scales[child] = (child as Node3D).scale


func _set_body_visual_scale(s: float) -> void:
	if visuals == null:
		return
	if _teleport_base_scales.is_empty():
		_capture_teleport_scales()
	var k: float = maxf(s, 0.02)
	for child in _teleport_base_scales:
		if not is_instance_valid(child):
			continue
		var base: Vector3 = _teleport_base_scales[child]
		child.scale = base * k


func _set_teleport_glow(amount: float) -> void:
	_set_teleport_glow_recursive(visuals, amount)


func _set_teleport_glow_recursive(node: Node, amount: float) -> void:
	if node is MeshInstance3D:
		if node == shield_mesh or node == shockwave_visual:
			pass
		else:
			var mat = node.material_override as StandardMaterial3D
			if not mat:
				var base_mat = node.get_active_material(0)
				if base_mat:
					mat = base_mat.duplicate()
					node.material_override = mat
			if mat:
				if amount > 0.02:
					mat.emission_enabled = true
					mat.emission = Color(0.35, 0.85, 1.0)
					mat.emission_energy_multiplier = lerpf(0.0, 8.0, amount)
				else:
					mat.emission_enabled = false
					mat.emission_energy_multiplier = 1.0
	for child in node.get_children():
		_set_teleport_glow_recursive(child, amount)


func _burst_teleport_fx(at: Vector3) -> void:
	if _teleport_fx == null or not is_instance_valid(_teleport_fx):
		_teleport_fx = CPUParticles3D.new()
		_teleport_fx.emitting = false
		_teleport_fx.one_shot = true
		_teleport_fx.explosiveness = 0.92
		_teleport_fx.amount = 48
		_teleport_fx.lifetime = 0.55
		_teleport_fx.local_coords = false
		_teleport_fx.direction = Vector3.UP
		_teleport_fx.spread = 180.0
		_teleport_fx.initial_velocity_min = 3.0
		_teleport_fx.initial_velocity_max = 11.0
		_teleport_fx.gravity = Vector3(0, 2.0, 0)
		_teleport_fx.scale_amount_min = 0.08
		_teleport_fx.scale_amount_max = 0.22
		_teleport_fx.color = Color(0.4, 0.9, 1.0, 0.95)
		var spark_mat := StandardMaterial3D.new()
		spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		spark_mat.vertex_color_use_as_albedo = true
		if TELEPORT_SPARK:
			spark_mat.albedo_texture = TELEPORT_SPARK
		spark_mat.albedo_color = Color(0.45, 0.9, 1.0, 1.0)
		var spark_mesh := QuadMesh.new()
		spark_mesh.size = Vector2(0.22, 0.22)
		spark_mesh.material = spark_mat
		_teleport_fx.mesh = spark_mesh
		add_child(_teleport_fx)
	_teleport_fx.global_position = at + Vector3.UP * 0.4
	_teleport_fx.restart()
	_teleport_fx.emitting = true


func _apply_respawn_pose() -> void:
	is_exploding = false
	is_drowned = false
	is_underwater = false
	water_timer = 0.0
	_was_in_water_zone = false
	last_splash_time = -999.0
	was_on_ground = true
	air_time = 0.0
	on_alternative_path = false
	active_path = track_path
	alt_path_decisions.clear()

	ignore_next_landing_sound = true
	last_respawn_time = Time.get_ticks_msec() / 1000.0
	stuck_timer = 0.0
	_ai_avoid_force = 0.0
	_ai_offtrack_timer = 0.0
	_ai_unstuck_dir = 0.0
	_ai_recovering = false
	_ai_recover_refresh = 0.0
	_ai_no_progress_timer = 0.0
	_ai_progress_sample_pos = global_position
	_ai_fall_origin = Vector3.ZERO
	_ai_cached_offset = -1.0
	# Initialize offset from actual respawn position instead of hardcoded 0
	var _resp_path = active_path if active_path else track_path
	if _resp_path == null:
		var _resp_lvl = get_tree().get_first_node_in_group("level")
		if _resp_lvl and "track_path" in _resp_lvl:
			_resp_path = _resp_lvl.track_path
	if _resp_path and _resp_path.curve:
		_ai_last_ontrack_offset = _resp_path.curve.get_closest_offset(_resp_path.to_local(global_position))
	else:
		_ai_last_ontrack_offset = 0.0
	ai_lane_offset = 0.0
	ai_target_lane_offset = 0.0
	ai_lane_change_timer = randf_range(3.0, 6.0)
	ai_stuck_position_timer = 0.0
	ai_last_stuck_position = global_position
	_ai_start_grid_lane = 0.0
	_ai_overtake_lock_timer = 0.0
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
	part_world_positions.clear()
	part_on_ground.clear()
	original_body_part_transforms.clear()
	
	_set_visuals_alpha(1.0)
	if name_tag:
		name_tag.modulate.a = 1.0
		
	respawn_indicator_time = 0.0
	can_move = false
	is_boosting = false
	is_pad_boosting = false
	boost_time = 0.0
	boost_timer = 0.0
	pad_boost_timer = 0.0
	pad_boost_strength = 1.0
	slow_timer = 0.0
	is_landing = false
	is_drifting = false
	drift_mode = false
	_is_dust_active = false
	
	# Clear inventory items and active powerups on respawn
	current_item = ItemType.NONE
	current_item_2 = ItemType.NONE
	if is_local_player and race_ui:
		race_ui.update_items("NONE", "NONE")
	
	explosion_particles.emitting = false
	burning_particles.emitting = false
	burning_smoke_particles.emitting = false
	fire_sprite_particles.emitting = false
	fire_sprite_particles_2.emitting = false
	sfx_fire_loop.stop()
	sfx_rocket_loop.stop()
	sfx_nitro_start.stop()
	sfx_brake_drift.stop()
	
	_set_drift_emitting(false)
	_set_dirt_emitting(false)
	_set_boost_emitting(false)

	# Safety: if eagle/tornado still thinks it owns us, force drop
	_clear_external_captures()

	var has_physics_authority = has_physics_authority()
	if has_physics_authority:
		# Stay frozen until the grow animation finishes, then drop in.
		freeze = true
		sleeping = false
		axis_lock_angular_x = true
		axis_lock_angular_y = true
		axis_lock_angular_z = true
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		visual_offset_y = 0.0
		sync_velocity = Vector3.ZERO

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
		_ai_last_ontrack_offset = offset
		
		var next_offset = fmod(offset + 1.0, curve.get_baked_length())
		var p1 = curve.sample_baked(offset)
		var p2 = curve.sample_baked(next_offset)
		var tangent = (target_path.to_global(p2) - target_path.to_global(p1)).normalized()
		if tangent.length() > 0.01:
			forward_dir = tangent

	# Behind the gate, lifted so the grow-in can drop onto the road.
	var target_basis = Basis.looking_at(forward_dir, Vector3.UP)
	spawn_pos = spawn_pos - forward_dir * 5.0 + target_basis.y * 3.4
	global_transform = Transform3D(target_basis, spawn_pos)
	visuals.global_transform = Transform3D(target_basis, spawn_pos)
	air_angular_velocity = Vector3.ZERO
	is_righting_on_ground = false
	sync_position = global_position
	sync_rotation = visuals.global_rotation
	sync_rotation_quat = target_basis.get_rotation_quaternion()

	if has_physics_authority:
		PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, global_transform)
		PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
		PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)


## Drop eagle grab (and tornado, if present) so freeze/can_move aren't left stuck after death.
func _clear_external_captures() -> void:
	if not get_tree():
		return
	for eagle in get_tree().get_nodes_in_group("eagles"):
		if eagle and is_instance_valid(eagle) and eagle.has_method("force_release_cart"):
			eagle.force_release_cart(self)
	# Tornado keeps a capture map — release if a helper exists
	for tornado in get_tree().get_nodes_in_group("tornados"):
		if tornado and is_instance_valid(tornado) and tornado.has_method("force_release_cart"):
			tornado.force_release_cart(self)

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
		# Add rotational tumble so blast waves and explosions flip the car
		air_angular_velocity = Vector3(
			randf_range(-7.0, 7.0),
			randf_range(-3.5, 3.5),
			randf_range(-7.0, 7.0)
		)

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
					var is_real_peer = p.name.to_int() > 0 and not p.get("is_ai") and NetworkManager.current_game_mode == NetworkManager.GameMode.MULTIPLAYER
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

		# Knock eagles away (and force them to drop any carried car)
		var eagles = get_tree().get_nodes_in_group("eagles")
		for e in eagles:
			if e == null or not is_instance_valid(e):
				continue
			var edist: float = global_position.distance_to(e.global_position)
			if edist < 22.0 and e.has_method("apply_shockwave_push"):
				e.apply_shockwave_push(global_position)
		
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
					var is_real_peer = p.name.to_int() > 0 and not p.get("is_ai") and NetworkManager.current_game_mode == NetworkManager.GameMode.MULTIPLAYER
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
		
		var random_target = Vector3.ZERO
		if hit_players.is_empty():
			var fwd = -visuals.global_transform.basis.z
			var right = visuals.global_transform.basis.x
			var dist = randf_range(14.0, 24.0)
			var side_offset = randf_range(-12.0, 12.0)
			var ground_target = global_position + fwd * dist + right * side_offset
			var ground_y = _get_ground_height(ground_target)
			if ground_y != -999.0:
				ground_target.y = ground_y
			else:
				ground_target.y = global_position.y
			random_target = ground_target

		# Play visual for all clients
		if multiplayer.multiplayer_peer != null:
			client_play_lightning.rpc(hit_players, random_target)
		else:
			client_play_lightning(hit_players, random_target)

@rpc("authority", "call_local", "reliable")
func apply_lightning_slow_multicast():
	slow_timer = 2.5

@rpc("any_peer", "call_local", "reliable")
func client_play_lightning(hit_player_names: Array, random_target: Vector3 = Vector3.ZERO):
	var sound_player = AudioStreamPlayer3D.new()
	sound_player.stream = LIGHTNING_SOUND
	sound_player.pitch_scale = 1.0
	sound_player.volume_db = -6.0
	sound_player.bus = &"SFX"
	get_tree().current_scene.add_child(sound_player)
	sound_player.global_position = global_position
	sound_player.play()
	get_tree().create_timer(1.5).timeout.connect(sound_player.queue_free)

	var origin_getter = func():
		if is_instance_valid(self) and is_instance_valid(visuals):
			return global_position + visuals.global_transform.basis.y * -0.15
		return global_position

	if not hit_player_names.is_empty():
		for name_str in hit_player_names:
			var target = null
			for c in get_tree().get_nodes_in_group("player_carts"):
				if c.name == name_str:
					target = c
					break
			if target:
				var target_getter = func():
					if is_instance_valid(target) and is_instance_valid(target.visuals):
						return target.global_position + target.visuals.global_transform.basis.y * -0.15
					return Vector3.ZERO
				_create_dynamic_lightning_arc(origin_getter, target_getter)
				_spawn_sparks(target.global_position + target.visuals.global_transform.basis.y * 0.05)
	else:
		var strike_pos = random_target
		if strike_pos == Vector3.ZERO:
			var fwd = -visuals.global_transform.basis.z
			var right = visuals.global_transform.basis.x
			strike_pos = global_position + fwd * 18.0 + right * randf_range(-8.0, 8.0)
		var static_target = strike_pos + Vector3(0, 0.2, 0)
		var static_getter = func():
			return static_target
		_create_dynamic_lightning_arc(origin_getter, static_getter)
		_spawn_sparks(static_target)

func _create_dynamic_lightning_arc(start_getter: Callable, end_getter: Callable):
	var mesh_instance = MeshInstance3D.new()
	var imm_mesh = ImmediateMesh.new()
	mesh_instance.mesh = imm_mesh
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.85, 0.95, 1.0, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.75, 1.0)
	mat.emission_energy_multiplier = 14.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.material_override = mat
	
	get_tree().current_scene.add_child(mesh_instance)
	
	var duration: float = 0.24
	
	var redraw_arc = func():
		if not is_instance_valid(mesh_instance) or not is_instance_valid(imm_mesh):
			return
		var start_pt: Vector3 = start_getter.call()
		var end_pt: Vector3 = end_getter.call()
		if start_pt == Vector3.ZERO or end_pt == Vector3.ZERO:
			return
		
		imm_mesh.clear_surfaces()
		imm_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		
		var dir = end_pt - start_pt
		var length = dir.length()
		if length < 0.1:
			imm_mesh.surface_end()
			return
			
		var steps = clamp(int(length * 1.4), 14, 32)
		var perp1 = dir.cross(Vector3.UP).normalized()
		if perp1.length_squared() < 0.01:
			perp1 = dir.cross(Vector3.FORWARD).normalized()
		var perp2 = dir.cross(perp1).normalized()
		
		var points: Array[Vector3] = []
		for i in range(steps + 1):
			var t: float = float(i) / float(steps)
			var base_pt = start_pt.lerp(end_pt, t)
			var arc_up = sin(t * PI) * (length * 0.18 + 2.2)
			base_pt.y += arc_up
			var jitter_strength = sin(t * PI) * (length * 0.04 + 0.25)
			var offset = perp1 * randf_range(-jitter_strength, jitter_strength) + perp2 * randf_range(-jitter_strength, jitter_strength)
			points.append(base_pt + offset)
		
		var n_pts = points.size()
		var width: float = 0.18
		
		var left_pts: Array[Vector3] = []
		var right_pts: Array[Vector3] = []
		var top_pts: Array[Vector3] = []
		var bottom_pts: Array[Vector3] = []
		
		for i in range(n_pts):
			var tangent: Vector3
			if i == 0:
				tangent = (points[1] - points[0]).normalized()
			elif i == n_pts - 1:
				tangent = (points[n_pts - 1] - points[n_pts - 2]).normalized()
			else:
				tangent = (points[i + 1] - points[i - 1]).normalized()
				
			var side_h = tangent.cross(Vector3.UP).normalized() * width
			if side_h.length_squared() < 0.001:
				side_h = tangent.cross(Vector3.FORWARD).normalized() * width
			var side_v = tangent.cross(side_h).normalized() * width
			
			left_pts.append(points[i] - side_h)
			right_pts.append(points[i] + side_h)
			top_pts.append(points[i] + side_v)
			bottom_pts.append(points[i] - side_v)
		
		for i in range(n_pts - 1):
			# Horizontal quad
			imm_mesh.surface_add_vertex(left_pts[i])
			imm_mesh.surface_add_vertex(right_pts[i])
			imm_mesh.surface_add_vertex(right_pts[i + 1])
			
			imm_mesh.surface_add_vertex(left_pts[i])
			imm_mesh.surface_add_vertex(right_pts[i + 1])
			imm_mesh.surface_add_vertex(left_pts[i + 1])
			
			# Vertical quad
			imm_mesh.surface_add_vertex(top_pts[i])
			imm_mesh.surface_add_vertex(bottom_pts[i])
			imm_mesh.surface_add_vertex(bottom_pts[i + 1])
			
			imm_mesh.surface_add_vertex(top_pts[i])
			imm_mesh.surface_add_vertex(bottom_pts[i + 1])
			imm_mesh.surface_add_vertex(top_pts[i + 1])
			
		imm_mesh.surface_end()

	redraw_arc.call()
	
	var tween = create_tween()
	if tween:
		tween.tween_method(func(_v: float):
			redraw_arc.call()
		, 0.0, 1.0, duration)
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
	var backward_dir = visuals.global_transform.basis.z.normalized()
	var spawn_pos = global_position + visuals.global_transform.basis.y * 1.35 + backward_dir * 0.4
	var spawn_vel = linear_velocity * 0.45 + backward_dir * 2.0 + Vector3.UP * 1.5
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
	
	# Add collision exception so bomb doesn't bump the shooter cart
	for cart in get_tree().get_nodes_in_group("player_carts"):
		if cart.name.to_int() == shooter_id:
			bomb.add_collision_exception_with(cart)
			break
	
	if multiplayer.multiplayer_peer != null and multiplayer.is_server():
		bomb.set_multiplayer_authority(1)

func _setup_blob_shadow():
	if not is_instance_valid(visuals):
		return
	if not is_instance_valid(blob_shadow):
		blob_shadow = visuals.get_node_or_null("BlobShadow")
	if not blob_shadow:
		blob_shadow = Decal.new()
		blob_shadow.name = "BlobShadow"
		blob_shadow.size = Vector3(1.7, 4.0, 2.7)
		blob_shadow.transform.origin = Vector3(0, 0.2, 0)
		var tex_path = "res://materials/blob_shadow.png"
		if ResourceLoader.exists(tex_path):
			blob_shadow.texture_albedo = load(tex_path)
		blob_shadow.albedo_mix = 0.75
		blob_shadow.cull_mask = 1
		blob_shadow.upper_fade = 0.2
		blob_shadow.lower_fade = 0.7
		blob_shadow.distance_fade_enabled = true
		blob_shadow.distance_fade_begin = 50.0
		blob_shadow.distance_fade_length = 20.0
		visuals.add_child(blob_shadow)

func _update_blob_shadow() -> void:
	if not is_instance_valid(blob_shadow) or not blob_shadow.visible or not is_instance_valid(visuals):
		return
	var origin: Vector3 = visuals.global_position + Vector3.UP * 0.8
	var ground_y: float = visuals.global_position.y - 0.65
	var space = get_world_3d().direct_space_state
	if space:
		var q := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * 10.0)
		q.exclude = [get_rid()]
		q.collision_mask = 1
		var hit = space.intersect_ray(q)
		if not hit.is_empty():
			ground_y = float(hit.position.y)
	var height: float = clampf(visuals.global_position.y - ground_y, 0.15, 6.0)
	# Project along world -Y so the blob sits on the ground instead of floating with the chassis.
	var fwd: Vector3 = -visuals.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.0001:
		fwd = Vector3.FORWARD
	else:
		fwd = fwd.normalized()
	var right: Vector3 = Vector3.UP.cross(fwd).normalized()
	blob_shadow.global_transform = Transform3D(Basis(right, Vector3.UP, -fwd), Vector3(visuals.global_position.x, ground_y + height * 0.5, visuals.global_position.z))
	blob_shadow.size = Vector3(1.7, maxf(2.4, height + 1.2), 2.7)
	blob_shadow.upper_fade = 0.08
	blob_shadow.lower_fade = 0.35

func apply_shadow_setting(enabled: bool = true):
	if is_instance_valid(visuals):
		_set_shadows_recursive(visuals, enabled)
	if not is_instance_valid(blob_shadow) and is_instance_valid(visuals):
		blob_shadow = visuals.get_node_or_null("BlobShadow")
	if is_instance_valid(blob_shadow):
		blob_shadow.visible = not enabled

func _set_shadows_recursive(node: Node, enabled: bool):
	if node == null: return
	if node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_set_shadows_recursive(child, enabled)

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

func _configure_trail_particle_draw(p: CPUParticles3D) -> void:
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	p.visibility_aabb = AABB(Vector3(-10, -6, -10), Vector3(20, 12, 20))
	if p.mesh is PrimitiveMesh and p.material_override is Material:
		(p.mesh as PrimitiveMesh).material = p.material_override


func _collect_trail_particles() -> Array:
	var all := []
	for p in dirt_particles:
		if is_instance_valid(p) and p is CPUParticles3D:
			all.append(p)
	for p in drift_particles:
		if is_instance_valid(p) and p is CPUParticles3D:
			all.append(p)
	return all


func _prime_wheel_trail_particles() -> void:
	var all: Array = _collect_trail_particles()
	if all.is_empty():
		_trail_particles_ready = true
		return

	# Tiny on-screen proxies compile the particle shader variants before gameplay.
	# The first real emit is otherwise the first draw, which shows a dark MultiMesh puff.
	var dummies := []
	var seen_mats := {}
	for p in all:
		var mat = p.material_override
		if mat == null or seen_mats.has(mat):
			continue
		seen_mats[mat] = true
		var dummy := MeshInstance3D.new()
		dummy.mesh = p.mesh if p.mesh else QuadMesh.new()
		dummy.material_override = mat
		dummy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dummy.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		dummy.layers = p.layers
		dummy.scale = Vector3(0.001, 0.001, 0.001)
		visuals.add_child(dummy)
		dummy.global_position = p.global_position
		dummies.append(dummy)

	for p in all:
		# Hide the uninitialized MultiMesh (identity transforms, default black instance colors)
		# while still allowing the first process/draw to allocate and fill the buffer.
		p.transparency = 1.0
		p.emitting = true
		p.restart()
		if p.has_method("request_particles_process"):
			p.request_particles_process(p.lifetime + 0.05, p.lifetime + 0.05)
		else:
			p.preprocess = p.lifetime + 0.05

	if is_inside_tree():
		await get_tree().process_frame
		await RenderingServer.frame_post_draw

	if not is_inside_tree():
		return

	# Stop emission and age remaining particles out while still invisible.
	for p in all:
		if not is_instance_valid(p):
			continue
		p.emitting = false
		p.preprocess = 0.0
		if p.has_method("request_particles_process"):
			p.request_particles_process(0.0, p.lifetime + 0.05)

	if is_inside_tree():
		await get_tree().process_frame

	if not is_inside_tree():
		return

	for p in all:
		if not is_instance_valid(p):
			continue
		p.transparency = 0.0
		_park_trail_emitter(p)

	for dummy in dummies:
		if is_instance_valid(dummy):
			dummy.queue_free()

	_trail_particles_ready = true


func _create_drift_particles(wheel_name: String):
	var pivot = get_node_or_null("Visuals/WheelPivot" + wheel_name)
	if not pivot: return

	# Brake / drift smoke
	var smoke = CPUParticles3D.new()
	smoke.name = wheel_name + "_Smoke"
	smoke.emitting = false
	smoke.amount = 12
	smoke.lifetime = 0.28
	smoke.explosiveness = 0.0
	smoke.randomness = 0.4
	smoke.mesh = QuadMesh.new()
	smoke.local_coords = false
	smoke.top_level = true
	smoke.set_meta("pivot", pivot)
	smoke.set_meta("kind", "smoke")

	visuals.add_child(smoke)
	drift_particles.append(smoke)

	if pivot.is_inside_tree():
		smoke.global_position = pivot.global_position + pivot.global_transform.basis * Vector3(0, -0.22, 0.16)
		smoke.global_rotation = pivot.global_rotation

	var mat_smoke = StandardMaterial3D.new()
	mat_smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_smoke.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_smoke.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat_smoke.vertex_color_use_as_albedo = true
	mat_smoke.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat_smoke.albedo_texture = _get_radial_dust_texture()
	mat_smoke.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	smoke.material_override = mat_smoke

	smoke.direction = Vector3(0.0, 0.8, 1.0).normalized()
	smoke.spread = 45.0
	smoke.gravity = Vector3(0.0, 0.4, 0.0)
	smoke.initial_velocity_min = 1.5
	smoke.initial_velocity_max = 3.5
	smoke.scale_amount_min = 0.08
	smoke.scale_amount_max = 0.26

	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.15))
	scale_curve.add_point(Vector2(0.40, 0.65))
	scale_curve.add_point(Vector2(1.0, 1.0))
	smoke.scale_amount_curve = scale_curve

	var grad = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.15, 0.55, 1.0])
	grad.colors = PackedColorArray([
		Color(0.90, 0.90, 0.90, 0.0),
		Color(0.88, 0.88, 0.88, 0.10),
		Color(0.85, 0.85, 0.85, 0.04),
		Color(0.80, 0.80, 0.80, 0.0)
	])
	smoke.color_ramp = grad
	_configure_trail_particle_draw(smoke)

	# Skidmarks — continuous deep dark rubber tire tracks on road surface
	var skid = CPUParticles3D.new()
	skid.name = wheel_name + "_Skid"
	skid.emitting = false
	skid.amount = 140
	skid.lifetime = 1.8
	skid.explosiveness = 0.0
	skid.randomness = 0.0
	skid.fixed_fps = 60
	skid.mesh = QuadMesh.new()
	skid.mesh.orientation = PlaneMesh.FACE_Y
	skid.mesh.size = Vector2(0.26, 0.60)

	var mat_skid = StandardMaterial3D.new()
	mat_skid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_skid.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_skid.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	mat_skid.vertex_color_use_as_albedo = true
	mat_skid.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat_skid.render_priority = 3
	skid.material_override = mat_skid

	var skid_grad = Gradient.new()
	# Fade-in from alpha 0 over first 2% of lifetime (~36ms) so the very first
	# particles spawned when the emitter initialises are invisible, preventing
	# the dark "disc" artifact that appears on first contact with the surface.
	skid_grad.offsets = PackedFloat32Array([0.0, 0.02, 0.55, 0.85, 1.0])
	skid_grad.colors = PackedColorArray([
		Color(0.01, 0.01, 0.01, 0.0),  # Invisible at birth
		Color(0.01, 0.01, 0.01, 0.95), # Rich deep black rubber
		Color(0.01, 0.01, 0.01, 0.80),
		Color(0.01, 0.01, 0.01, 0.35),
		Color(0.01, 0.01, 0.01, 0.0)
	])
	skid.color_ramp = skid_grad

	skid.gravity = Vector3.ZERO
	skid.direction = Vector3.ZERO
	skid.spread = 0.0
	skid.initial_velocity_min = 0.0
	skid.initial_velocity_max = 0.0
	skid.local_coords = false
	skid.top_level = true
	skid.set_meta("pivot", pivot)
	skid.set_meta("kind", "skid")

	visuals.add_child(skid)
	drift_particles.append(skid)

	if pivot.is_inside_tree():
		var local_offset = Vector3(0, WHEEL_Y_OFFSET + 0.02, 0)
		skid.global_position = pivot.global_position + pivot.global_transform.basis * local_offset
		var yaw: float = visuals.global_rotation.y if is_instance_valid(visuals) else 0.0
		skid.global_rotation = Vector3(0.0, yaw, 0.0)
	_configure_trail_particle_draw(skid)

func _set_drift_emitting(emitting: bool):
	if not _trail_particles_ready:
		return
	var speed: float = linear_velocity.length()
	var time_since_respawn = (Time.get_ticks_msec() / 1000.0) - last_respawn_time
	for p in drift_particles:
		if not is_instance_valid(p) or not (p is CPUParticles3D):
			continue
		var kind: String = str(p.get_meta("kind", ""))
		if kind == "skid" or p.name.ends_with("_Skid"):
			# Skidmarks emit only during active drift or hard braking on roads (never offroad on terrain)
			var skid_on: bool = emitting and speed > 6.5 and not is_landing and can_move and air_time < 0.02 and time_since_respawn > 0.5 and not is_offroad
			p.emitting = skid_on
			if skid_on and "amount_ratio" in p:
				p.amount_ratio = clampf((speed - 5.0) / 16.0, 0.25, 1.0)
		else:
			# Smoke emits during drift or hard braking at speed
			var smoke_on: bool = emitting and speed > 5.0 and not is_landing and can_move and air_time < 0.02 and time_since_respawn > 0.5
			p.emitting = smoke_on
			if smoke_on and "amount_ratio" in p:
				p.amount_ratio = clampf(speed / 20.0, 0.15, 0.65)

func _set_boost_emitting(emitting: bool) -> void:
	if is_instance_valid(boost_particles_l) and boost_particles_l.emitting != emitting:
		boost_particles_l.emitting = emitting
	if is_instance_valid(boost_particles_r) and boost_particles_r.emitting != emitting:
		boost_particles_r.emitting = emitting

func _update_boost_particle_positions() -> void:
	var pivot_rl = get_node_or_null("Visuals/WheelPivotRL")
	var pivot_rr = get_node_or_null("Visuals/WheelPivotRR")
	var under_wheel_y: float = min_wheel_bottom_y + 0.05
	if pivot_rl and is_instance_valid(boost_particles_l):
		boost_particles_l.position = Vector3(pivot_rl.position.x, under_wheel_y, pivot_rl.position.z + 0.12)
	if pivot_rr and is_instance_valid(boost_particles_r):
		boost_particles_r.position = Vector3(pivot_rr.position.x, under_wheel_y, pivot_rr.position.z + 0.12)

func _get_radial_dust_texture() -> Texture2D:
	if _dust_radial_texture != null:
		return _dust_radial_texture
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in range(32):
		for x in range(32):
			var nx := (x + 0.5) / 32.0 - 0.5
			var ny := (y + 0.5) / 32.0 - 0.5
			var dist := sqrt(nx * nx + ny * ny) * 2.0
			var a := clampf(1.0 - dist, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a) # smoothstep
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_dust_radial_texture = ImageTexture.create_from_image(img)
	return _dust_radial_texture

func _create_dirt_particles(wheel_name: String):
	var pivot = get_node_or_null("Visuals/WheelPivot" + wheel_name)
	if not pivot: return
	
	var dirt = CPUParticles3D.new()
	dirt.name = wheel_name + "_Dirt"
	dirt.emitting = false
	dirt.amount = 36
	dirt.lifetime = 0.35
	dirt.explosiveness = 0.0
	dirt.randomness = 0.35
	dirt.lifetime_randomness = 0.2
	dirt.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	dirt.emission_sphere_radius = 0.04
	dirt.mesh = QuadMesh.new()
	dirt.local_coords = false
	dirt.top_level = true
	dirt.set_meta("pivot", pivot)
	
	visuals.add_child(dirt)
	dirt_particles.append(dirt)
	
	if pivot.is_inside_tree():
		dirt.global_position = pivot.global_position + pivot.global_transform.basis * Vector3(0, -0.24, 0.16)
		dirt.global_rotation = pivot.global_rotation
	
	var mat_dirt = StandardMaterial3D.new()
	mat_dirt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_dirt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_dirt.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat_dirt.vertex_color_use_as_albedo = true
	mat_dirt.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat_dirt.albedo_texture = _get_radial_dust_texture()
	mat_dirt.albedo_color = _current_dust_color
	dirt.material_override = mat_dirt
	
	dirt.direction = Vector3(0.0, 0.6, 1.4).normalized()
	dirt.spread = 22.0
	dirt.gravity = Vector3(0, -3.5, 0)
	dirt.initial_velocity_min = 1.6
	dirt.initial_velocity_max = 3.8
	dirt.scale_amount_min = 0.06
	dirt.scale_amount_max = 0.22
	
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.08)) # Starts small at tire contact
	scale_curve.add_point(Vector2(0.35, 0.50))
	scale_curve.add_point(Vector2(1.0, 0.95)) # Expands softly into air
	dirt.scale_amount_curve = scale_curve
	
	var grad = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.15, 0.55, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.0),
		Color(1.0, 1.0, 1.0, 0.08),
		Color(1.0, 1.0, 1.0, 0.03),
		Color(1.0, 1.0, 1.0, 0.0)
	])
	dirt.color_ramp = grad
	_configure_trail_particle_draw(dirt)


func _get_current_surface_dust_color() -> Color:
	var lvl = _cached_level if is_instance_valid(_cached_level) else get_tree().get_first_node_in_group("level")
	var lvl_name = ""
	if lvl:
		lvl_name = str(lvl.name).to_lower()
	
	if not is_offroad:
		# Driving on asphalt / pavement
		return Color(0.92, 0.90, 0.88)
	
	# Check steep rock cliffs
	if ground_ray and ground_ray.is_colliding() and ground_ray.get_collision_normal().y < 0.60:
		return Color(0.76, 0.74, 0.70) # Rocky cliff light grey
		
	if lvl_name.contains("canyon"):
		return Color(0.90, 0.68, 0.50) # Terracotta sandstone
	elif lvl_name.contains("desert") or lvl_name.contains("wadi"):
		return Color(0.95, 0.88, 0.70) # Warm golden sand
	elif lvl_name.contains("mountain"):
		return Color(0.88, 0.82, 0.72) # Mountain sand & gravel
	elif lvl_name.contains("harbor"):
		return Color(0.70, 0.68, 0.62) # Dry concrete / dock dust
	else:
		return Color(0.75, 0.85, 0.60) # Meadow grass & loam


func _apply_dust_particle_colors(base_color: Color) -> void:
	for p in dirt_particles:
		if is_instance_valid(p) and p is CPUParticles3D:
			var mat = p.material_override as StandardMaterial3D
			if mat:
				mat.albedo_color = base_color


func _attach_dirt_emitter(p: CPUParticles3D, pivot: Node3D) -> void:
	p.global_rotation = pivot.global_rotation
	p.global_position = pivot.global_position + pivot.global_transform.basis * Vector3(0, -0.24, 0.16)


func _clear_trail_stopped_meta(p: CPUParticles3D) -> void:
	if p.has_meta("trail_stopped_at"):
		p.remove_meta("trail_stopped_at")


func _update_idle_trail_emitter(p: CPUParticles3D) -> void:
	# Leave the emitter at its last ground pose so already-spawned skid / dust
	# particles can finish their lifetime. Parking on the same frame as
	# emitting=false teleports those live quads away (trails vanish on release).
	if not p.has_meta("trail_stopped_at"):
		p.set_meta("trail_stopped_at", Time.get_ticks_msec() * 0.001)
	var stopped_at: float = float(p.get_meta("trail_stopped_at"))
	if Time.get_ticks_msec() * 0.001 - stopped_at >= p.lifetime + 0.05:
		_park_trail_emitter(p)


func _park_trail_emitter(p: CPUParticles3D) -> void:
	# Unused MultiMesh slots draw at the emitter origin. After remaining
	# particles have died, park far away so a leftover quad does not ride the tire.
	if p.global_position.y > -400.0:
		p.global_position = Vector3(0.0, -500.0, 0.0)


func _set_dirt_emitting(emitting: bool):
	if not _trail_particles_ready:
		return
	var in_water := stage_has_water and (is_underwater or (water_surface_y - global_position.y >= -0.80 and _is_over_water_volume()))
	var speed: float = linear_velocity.length()
	var time_since_respawn = (Time.get_ticks_msec() / 1000.0) - last_respawn_time
	
	# Hysteresis gating to prevent blinking / jittering when speed hovers near cutoff
	if _is_dust_active:
		if not emitting or speed < 4.0 or is_landing or not can_move or air_time >= 0.03 or in_water or time_since_respawn < 0.5:
			_is_dust_active = false
	else:
		if emitting and speed > 5.5 and not is_landing and can_move and air_time < 0.03 and not in_water and time_since_respawn > 0.5:
			_is_dust_active = true
			
	var on: bool = _is_dust_active
	if on:
		var target_col: Color = _get_current_surface_dust_color()
		_current_dust_color = _current_dust_color.lerp(target_col, 0.25)
		_apply_dust_particle_colors(_current_dust_color)
	for p in dirt_particles:
		if is_instance_valid(p) and p is CPUParticles3D:
			if on:
				var pivot = p.get_meta("pivot", null)
				if is_instance_valid(pivot):
					_attach_dirt_emitter(p, pivot)
				p.emitting = true
				if "amount_ratio" in p:
					p.amount_ratio = clampf((speed - 4.0) / 14.0, 0.20, 1.0)
			else:
				p.emitting = false

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

		# Play high-pitched, quieter splash sound for splashes (rate-limited)
		if not REGULAR_SPLASH_SOUNDS.is_empty() and randf() < 0.3:
			var stream = REGULAR_SPLASH_SOUNDS[randi() % REGULAR_SPLASH_SOUNDS.size()]
			if stream:
				var ap = AudioStreamPlayer3D.new()
				ap.stream = stream
				ap.bus = &"SFX"
				ap.max_distance = 50.0
				ap.unit_size = 5.0
				ap.volume_db = lerp(-15.0, -9.0, clampf(size_scale, 0.0, 1.0))
				ap.pitch_scale = lerp(1.35, 1.0, clampf(size_scale, 0.0, 1.0))
				get_tree().current_scene.add_child(ap)
				ap.global_position = pos
				ap.play()
				get_tree().create_timer(stream.get_length() + 0.3).timeout.connect(ap.queue_free)


func _ensure_water_wake() -> void:
	if _wake_particles != null and is_instance_valid(_wake_particles):
		return
	_wake_particles = GPUParticles3D.new()
	_wake_particles.name = "WaterWake"
	_wake_particles.amount = 48
	_wake_particles.lifetime = 0.85
	_wake_particles.explosiveness = 0.0
	_wake_particles.randomness = 0.35
	_wake_particles.visibility_aabb = AABB(Vector3(-4, -1, -6), Vector3(8, 4, 12))
	_wake_particles.local_coords = false
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(0.7, 0.04, 0.35)
	mat.direction = Vector3(0, 0.55, 1)
	mat.spread = 28.0
	mat.initial_velocity_min = 1.2
	mat.initial_velocity_max = 3.8
	mat.gravity = Vector3(0, -2.5, 0)
	mat.damping_min = 1.0
	mat.damping_max = 2.5
	mat.scale_min = 0.35
	mat.scale_max = 0.95
	mat.color = Color(0.75, 0.9, 1.0, 0.55)
	_wake_particles.process_material = mat
	var draw := QuadMesh.new()
	draw.size = Vector2(0.55, 0.55)
	var draw_mat := StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw_mat.albedo_color = Color(0.7, 0.88, 1.0, 0.5)
	var wake_tex = load("res://materials/water_particle.png")
	if wake_tex:
		draw_mat.albedo_texture = wake_tex
	draw.material = draw_mat
	_wake_particles.draw_pass_1 = draw
	_wake_particles.emitting = false
	if is_instance_valid(visuals):
		visuals.add_child(_wake_particles)
		_wake_particles.position = Vector3(0, 0.05, 1.15)
	else:
		add_child(_wake_particles)


func _update_water_wake(active: bool, _delta: float) -> void:
	_ensure_water_wake()
	if _wake_particles == null:
		return
	_wake_particles.emitting = active and linear_velocity.length() > 2.0
	if active:
		# Keep wake on the water surface behind the car
		var back: Vector3 = visuals.global_transform.basis.z if is_instance_valid(visuals) else global_transform.basis.z
		var wake_pos: Vector3 = global_position + back * 1.2
		wake_pos.y = water_surface_y + 0.05
		_wake_particles.global_position = wake_pos
		var speed_ratio: float = clampf(linear_velocity.length() / maxf(max_speed, 1.0), 0.2, 1.0)
		_wake_particles.amount_ratio = lerpf(0.35, 1.0, speed_ratio)



func _init_ai_personality() -> void:
	var rng := RandomNumberGenerator.new()
	var seed_src: String = player_name if not player_name.is_empty() else str(get_instance_id())
	rng.seed = hash(seed_src + ":" + str(car_index))
	var roll: float = rng.randf()
	if roll < 0.28:
		# AGGRESSIVE "Attacker": Late braking, inside apex cuts, frequent drifts, bold passes
		ai_aggression = rng.randf_range(0.75, 1.0)
		ai_corner_speed_factor = rng.randf_range(1.02, 1.12)
		ai_brake_dist_bias = rng.randf_range(-5.0, -2.5) # Brakes later
		ai_lookahead_mult = rng.randf_range(0.95, 1.08)
		ai_racing_line_weight = rng.randf_range(0.70, 0.95)
		ai_drift_threshold = rng.randf_range(0.22, 0.30)
		ai_lane_span = rng.randf_range(2.2, 3.4)
	elif roll < 0.65:
		# PRECISION "Technical": Out-in-out racing line, smooth braking, clean apexes
		ai_aggression = rng.randf_range(0.45, 0.70)
		ai_corner_speed_factor = rng.randf_range(0.96, 1.04)
		ai_brake_dist_bias = rng.randf_range(-2.0, 1.5)
		ai_lookahead_mult = rng.randf_range(1.0, 1.15)
		ai_racing_line_weight = rng.randf_range(0.80, 1.0)
		ai_drift_threshold = rng.randf_range(0.30, 0.40)
		ai_lane_span = rng.randf_range(1.8, 2.8)
	elif roll < 0.88:
		# BALANCED "Competitor": Adaptive lane shifts, balanced corner speeds
		ai_aggression = rng.randf_range(0.30, 0.50)
		ai_corner_speed_factor = rng.randf_range(0.92, 1.00)
		ai_brake_dist_bias = rng.randf_range(0.5, 3.0)
		ai_lookahead_mult = rng.randf_range(0.90, 1.05)
		ai_racing_line_weight = rng.randf_range(0.50, 0.75)
		ai_drift_threshold = rng.randf_range(0.35, 0.45)
		ai_lane_span = rng.randf_range(1.5, 2.4)
	else:
		# CAUTIOUS "Rookie": Early braking, stays near comfort zone, patient following
		ai_aggression = rng.randf_range(0.08, 0.28)
		ai_corner_speed_factor = rng.randf_range(0.85, 0.93)
		ai_brake_dist_bias = rng.randf_range(2.5, 5.0) # Brakes earlier
		ai_lookahead_mult = rng.randf_range(0.85, 0.98)
		ai_racing_line_weight = rng.randf_range(0.30, 0.55)
		ai_drift_threshold = rng.randf_range(0.42, 0.55)
		ai_lane_span = rng.randf_range(1.1, 1.8)

	ai_shortcut_chance = clampf(lerpf(0.10, 0.75, ai_aggression) * rng.randf_range(0.85, 1.15), 0.05, 0.80)
	ai_overtake_bias = rng.randf_range(-1.0, 1.0)
	# A minority still fly the summit hairpin; everyone else gets extra braking.
	_ai_may_overshoot = rng.randf() < (0.07 + ai_aggression * 0.14)


func _ai_evaluate_traffic(_delta: float, fwd_3d: Vector3, right_3d: Vector3) -> Dictionary:
	var traffic_result = {
		"throttle_mult": 1.0,
		"cushion_force": 0.0
	}
	
	if is_finished_race or not can_move:
		return traffic_result
		
	var carts = get_tree().get_nodes_in_group("player_carts")
	if carts.is_empty():
		return traffic_result

	var my_pos = global_position
	var closest_fwd_dist: float = 999.0
	var closest_cart: Node3D = null
	var closest_lat_dist: float = 0.0
	var closest_side: float = 0.0
	
	var is_start_phase: bool = (Time.get_ticks_msec() / 1000.0 - race_start_time) < 3.0

	for cart in carts:
		if cart == self or not is_instance_valid(cart):
			continue
		if cart.get("is_exploding") == true:
			continue
			
		var to_cart = cart.global_position - my_pos
		var fwd_dist = fwd_3d.dot(to_cart)
		var side_dist = right_3d.dot(to_cart)
		var abs_side = absf(side_dist)
		
		# Side-by-side wheel-to-wheel cushion (applies to cars alongside us)
		if absf(fwd_dist) < 3.2 and abs_side < 2.4:
			var push_dir = -signf(side_dist) if abs_side > 0.05 else (1.0 if ai_overtake_bias >= 0.0 else -1.0)
			var cushion_strength = (1.0 - (abs_side / 2.4)) * 0.35
			traffic_result["cushion_force"] += push_dir * cushion_strength
		
		# Look for carts ahead within a 28m forward corridor
		if fwd_dist > 0.8 and fwd_dist < 28.0 and abs_side < 4.5:
			if fwd_dist < closest_fwd_dist:
				closest_fwd_dist = fwd_dist
				closest_cart = cart
				closest_lat_dist = abs_side
				closest_side = side_dist

	# If a car is ahead of us
	if closest_cart != null:
		# If tailgating closely (< 4.0m) and directly behind (lat < 1.6m), slightly modulate throttle to avoid ramming
		if closest_fwd_dist < 4.0 and closest_lat_dist < 1.6 and not is_start_phase:
			var other_speed = closest_cart.linear_velocity.length()
			var my_speed = linear_velocity.length()
			if my_speed > other_speed:
				traffic_result["throttle_mult"] = clampf(other_speed / maxf(my_speed, 1.0), 0.75, 0.95)

		# Overtaking decision (when closing in or blocked ahead)
		if not is_start_phase and closest_fwd_dist < 20.0 and _ai_overtake_lock_timer <= 0.0:
			_ai_overtake_lock_timer = randf_range(1.5, 3.5) # Don't twitch lane back and forth rapidly
			var pass_side: float = 0.0
			if closest_lat_dist > 0.4:
				# Other car is on one side of our lane -> pass on the other side
				pass_side = -signf(closest_side)
			else:
				# Directly in front -> choose side with more room on track or use overtake bias
				if absf(ai_lane_offset) > 1.0:
					pass_side = -signf(ai_lane_offset) # Move toward open center/other side
				else:
					pass_side = 1.0 if ai_overtake_bias >= 0.0 else -1.0
			
			var pass_offset = pass_side * clampf(ai_lane_span * 0.85, 1.2, 3.2)
			if _harbor_stage:
				pass_offset = clampf(pass_offset, -0.45, 0.45)
			ai_target_lane_offset = pass_offset
			ai_lane_change_timer = randf_range(3.0, 5.0)

	return traffic_result


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

	if not _harbor_stage:
		var tg_ai = null
		var lvl_ai = _cached_level if is_instance_valid(_cached_level) else get_tree().get_first_node_in_group("level")
		if lvl_ai:
			tg_ai = lvl_ai.get_node_or_null("TerrainGenerator")
		if tg_ai and str(tg_ai.get("level_prefix")) == "harbor_pier":
			_harbor_stage = true
			ai_target_lane_offset = clampf(ai_target_lane_offset, -0.45, 0.45)
			ai_lane_offset = clampf(ai_lane_offset, -0.55, 0.55)
		elif tg_ai and str(tg_ai.get("level_prefix")) == "mountain":
			_mountain_stage = true
		elif tg_ai and str(tg_ai.get("level_prefix")) == "desert_wadi":
			_wadi_stage = true

	var curve = active_path.curve
	var curve_length = maxf(curve.get_baked_length(), 1.0)
	var local_pos = active_path.to_local(global_position)
	var speed = linear_velocity.length()
	var is_airborne := not was_on_ground or air_time > 0.0
	var is_start_phase: bool = (Time.get_ticks_msec() / 1000.0 - race_start_time) < 3.2

	# Robust localized offset tracking: searches in a window around _ai_last_ontrack_offset
	# to prevent snapping to overpass bridges, chasms, or stacked mountain loops.
	var current_offset: float = _ai_last_ontrack_offset
	if _ai_recovering:
		# Frozen offset while in the pit — do not retarget a far stretch of track.
		current_offset = _ai_last_ontrack_offset
	elif _ai_last_ontrack_offset < 0.0 or is_start_phase:
		current_offset = curve.get_closest_offset(local_pos)
		_ai_last_ontrack_offset = current_offset
	else:
		var search_back = 16.0
		var search_fwd = maxf(38.0, speed * 1.5)
		var min_d_sq = INF
		var best_off = current_offset
		var step = 2.0
		var num_steps = int((search_back + search_fwd) / step)
		for s in range(num_steps + 1):
			var test_off = fmod(_ai_last_ontrack_offset - search_back + s * step + curve_length * 4.0, curve_length)
			var p = curve.sample_baked(test_off)
			var d_sq = p.distance_squared_to(local_pos)
			if d_sq < min_d_sq:
				min_d_sq = d_sq
				best_off = test_off
		
		if min_d_sq < 900.0:
			var sample_world: Vector3 = active_path.to_global(curve.sample_baked(best_off))
			var height_err: float = sample_world.y - global_position.y
			var xz_err: float = Vector2(global_position.x - sample_world.x, global_position.z - sample_world.z).length()
			# Don't snap onto a stacked loop / jump road sitting above the pit.
			if height_err > 7.0 or xz_err > 28.0:
				current_offset = _ai_last_ontrack_offset
			else:
				current_offset = best_off
				_ai_last_ontrack_offset = current_offset
		else:
			current_offset = _ai_last_ontrack_offset
	
	# If on an alternative path, check if we've reached the end of it
	if on_alternative_path:
		if curve_length - current_offset < 6.0:
			on_alternative_path = false
			active_path = track_path
			curve = active_path.curve
			curve_length = maxf(curve.get_baked_length(), 1.0)
			local_pos = active_path.to_local(global_position)
			current_offset = curve.get_closest_offset(local_pos)
			_ai_last_ontrack_offset = current_offset
	
	var style: float = 0.0 if _harbor_stage else ai_aggression

	# Evaluate traffic (overtaking, drafting, side-by-side cushion, tailgating modulation)
	var fwd_3d = -visuals.global_transform.basis.z
	var right_3d = visuals.global_transform.basis.x
	var traffic_info = _ai_evaluate_traffic(delta, fwd_3d, right_3d)

	# Periodically change target lane offset if not currently locked in an overtake maneuver
	if _ai_overtake_lock_timer > 0.0:
		_ai_overtake_lock_timer -= delta
	else:
		ai_lane_change_timer -= delta
		if ai_lane_change_timer <= 0.0 and not is_start_phase:
			ai_lane_change_timer = randf_range(lerpf(6.0, 3.0, style), lerpf(11.0, 6.0, style))
			if _harbor_stage:
				ai_target_lane_offset = randf_range(-0.45, 0.45)
			elif _mountain_stage:
				ai_target_lane_offset = randf_range(-1.2, 1.2)
			else:
				ai_target_lane_offset = randf_range(-ai_lane_span, ai_lane_span)
	
	# Smoothly interpolate to target lane offset
	ai_lane_offset = lerpf(ai_lane_offset, ai_target_lane_offset, 2.0 * delta)
	if _harbor_stage:
		ai_lane_offset = clampf(ai_lane_offset, -0.55, 0.55)
	
	var turn_info: Dictionary = _ai_measure_upcoming_turn(curve, current_offset, speed)
	_ai_upcoming_turn_angle = float(turn_info.get("angle", 0.0))
	_ai_upcoming_turn_dist = float(turn_info.get("dist", 40.0))
	_ai_upcoming_turn_dir = float(turn_info.get("dir", 0.0))
	var corner_factor: float = clampf(_ai_upcoming_turn_angle / 1.15, 0.0, 1.0)

	var look_ahead = lerp(lerpf(10.0, 14.0, style), lerpf(22.0, 26.0, style), clampf(speed / maxf(max_speed, 1.0), 0.0, 1.0)) * ai_lookahead_mult
	# In a tight nearby bend, aim closer so the car follows the road instead of cutting into walls
	if corner_factor > lerpf(0.55, 0.78, style) and _ai_upcoming_turn_dist < 16.0:
		look_ahead = minf(look_ahead, lerpf(11.0, 16.0, style))
	var near_ang: float = float(turn_info.get("near_angle", 0.0))
	var is_hairpin: bool = near_ang > 1.25
	if is_hairpin and not _ai_may_overshoot:
		look_ahead = minf(look_ahead, clampf(_ai_upcoming_turn_dist * 0.55, 8.0, 12.0))
	if _mountain_stage:
		look_ahead = minf(look_ahead, 16.0)
	if _harbor_stage:
		look_ahead = lerpf(11.0, 15.0, clampf(speed / maxf(max_speed, 1.0), 0.0, 1.0))
		if corner_factor > 0.45:
			look_ahead = minf(look_ahead, 12.0)
	# Follow the ribbon through corners instead of cutting the inside (e.g. chasm start/finish).
	if corner_factor > 0.28:
		look_ahead = minf(look_ahead, maxf(8.0, _ai_upcoming_turn_dist * 0.42))
	var target_offset = current_offset + look_ahead
	target_offset = fmod(target_offset, curve_length)
	
	var target_local_pos = curve.sample_baked(target_offset)
	
	# Compute perpendicular offset (lane offset) along the track tangent
	var tangent_offset = fmod(target_offset + 1.0, curve_length)
	var tangent_local_pos = curve.sample_baked(tangent_offset)
	var tangent = (tangent_local_pos - target_local_pos).normalized()
	var right_vec = Vector3(-tangent.z, 0, tangent.x).normalized()
	
	# Dynamic Racing Line (Out-In-Out Cornering)
	var racing_line_offset: float = 0.0
	if not _harbor_stage and not on_alternative_path and not is_start_phase and corner_factor > 0.15:
		var turn_side = -_ai_upcoming_turn_dir
		var max_line_span = clampf(ai_lane_span * 0.9, 1.5, 3.2) * ai_racing_line_weight
		if _ai_upcoming_turn_dist > 18.0:
			var t_entry = clampf((_ai_upcoming_turn_dist - 18.0) / 20.0, 0.0, 1.0)
			racing_line_offset = -turn_side * max_line_span * corner_factor * (1.0 - t_entry * 0.3)
		else:
			var t_apex = clampf((18.0 - _ai_upcoming_turn_dist) / 18.0, 0.0, 1.0)
			var entry_target = -turn_side * max_line_span * corner_factor * 0.7
			var apex_target = turn_side * max_line_span * corner_factor
			racing_line_offset = lerpf(entry_target, apex_target, t_apex)

	var combined_offset = ai_lane_offset + racing_line_offset
	var max_safe_span: float = 1.6 if _harbor_stage else (2.0 if _mountain_stage else 3.2)
	if corner_factor > 0.4:
		max_safe_span = minf(max_safe_span, 2.2)
	var actual_lane_offset = clampf(combined_offset, -max_safe_span, max_safe_span)

	if is_finished_race:
		actual_lane_offset = 0.0
	elif is_airborne:
		actual_lane_offset *= 0.25
	elif is_offroad:
		actual_lane_offset *= 0.20
	elif on_alternative_path:
		actual_lane_offset *= 0.20
	elif _harbor_stage:
		actual_lane_offset = clampf(actual_lane_offset * 0.35, -0.55, 0.55)
	
	var p_now = curve.sample_baked(current_offset)
	var p_ahead = curve.sample_baked(fmod(current_offset + 8.0, curve_length))
	var elev_delta = absf(p_ahead.y - p_now.y)
	if elev_delta > 1.0 and not is_hairpin:
		actual_lane_offset *= 0.1
	if is_hairpin and not _ai_may_overshoot:
		actual_lane_offset *= 0.4
	target_local_pos += right_vec * actual_lane_offset

	_ai_update_recovery(delta, current_offset)
	
	var target_global_pos = active_path.to_global(target_local_pos)
	if _ai_recovering:
		# Aim toward the next correct checkpoint, blended with a curve-adjacent point.
		var cp_goal: Vector3 = _ai_checkpoint_recovery_goal()
		var alongside_goal: Vector3 = _ai_alongside_goal()
		if cp_goal != Vector3.ZERO and alongside_goal != Vector3.ZERO:
			# Blend: mostly aim at the checkpoint gate, but avoid walls via alongside.
			target_global_pos = alongside_goal.lerp(cp_goal, 0.45)
		elif cp_goal != Vector3.ZERO:
			target_global_pos = cp_goal
		elif alongside_goal != Vector3.ZERO:
			target_global_pos = alongside_goal
		# else: keep the default track-following target

	# Item Box Seeking
	var wants_item := (current_item == ItemType.NONE or current_item_2 == ItemType.NONE) and not is_finished_race and (not is_offroad or _wadi_stage) and not _ai_recovering
	if wants_item:
		var best_box: Node3D = null
		var best_dist: float = 38.0
		for box in get_tree().get_nodes_in_group("item_boxes"):
			if not is_instance_valid(box) or not box.get("is_active"):
				continue
			var to_box = box.global_position - global_position
			var fwd_dist = fwd_3d.dot(to_box)
			if fwd_dist > 4.0 and fwd_dist < best_dist:
				var side_dist = absf(visuals.global_transform.basis.x.dot(to_box))
				if side_dist < 6.5:
					best_dist = fwd_dist
					best_box = box
		if best_box:
			var blend_factor = clampf(1.0 - (best_dist / 40.0), 0.5, 0.95)
			target_global_pos = target_global_pos.lerp(best_box.global_position, blend_factor)

	var target_vec = visuals.global_transform.inverse() * target_global_pos
	var dir_flat = Vector2(target_vec.x, -target_vec.z).normalized()
	
	input.x = clamp(dir_flat.x * (1.8 if is_airborne else 2.2), -1.0, 1.0)
	if is_finished_race:
		_ai_want_drift = false
		if speed > 0.5:
			input.x = clamp(dir_flat.x * 1.5, -0.6, 0.6)
			input.y = 0.95
		else:
			input.x = 0.0
			input.y = 0.0
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO
	else:
		_ai_want_drift = false
		var min_corner_speed: float = 0.28 if _harbor_stage else lerpf(0.38, 0.82, style)
		min_corner_speed *= ai_corner_speed_factor
		var safe_speed: float = lerpf(max_speed, max_speed * min_corner_speed, corner_factor)
		var brake_window: float = (34.0 if _harbor_stage else lerpf(26.0, 12.0, style)) + ai_brake_dist_bias
		brake_window = maxf(brake_window, 8.0)
		if is_hairpin and not _ai_may_overshoot:
			min_corner_speed = minf(min_corner_speed, 0.34)
			safe_speed = lerpf(max_speed, max_speed * min_corner_speed, corner_factor)
			brake_window = maxf(brake_window, 30.0)
		
		if is_boosting or is_pad_boosting:
			safe_speed *= 0.88

		var react_corner: float = 0.16 if _harbor_stage else lerpf(0.16, 0.48, style)
		if is_hairpin and not _ai_may_overshoot:
			react_corner = minf(react_corner, 0.14)
		if _ai_upcoming_turn_dist < brake_window and corner_factor > react_corner:
			var t_dist = clampf((brake_window - _ai_upcoming_turn_dist) / maxf(brake_window - 6.0, 1.0), 0.0, 1.0)
			var target_corner_speed = lerpf(max_speed, safe_speed, t_dist)
			
			if speed > target_corner_speed + 1.0:
				var overspeed = speed - target_corner_speed
				input.y = clampf(overspeed / 6.5, 0.15, 0.85)
				
				# Drift decision
				if (not _harbor_stage) and (not is_hairpin or _ai_may_overshoot) and speed > 11.0 and corner_factor > ai_drift_threshold and abs(input.x) > 0.24 and _ai_upcoming_turn_dist < 22.0:
					_ai_want_drift = true
					input.y = maxf(input.y, 0.40)
			else:
				input.y = -clampf(1.0 - (corner_factor * 0.22), 0.65, 1.0)
		else:
			input.y = -1.0 + abs(input.x) * 0.18
			var th_mult = float(traffic_info.get("throttle_mult", 1.0))
			if th_mult < 1.0:
				input.y = maxf(input.y, -th_mult)

		if _harbor_stage:
			_ai_want_drift = false
			if input.y > 0.55:
				input.y = 0.55
		
		if speed < 4.0 and input.y > -0.2:
			input.y = -0.80

		if _ai_recovering:
			_ai_want_drift = false
			input.y = -1.0
	
	# 9-Ray Obstacle Avoidance — rocks/props/vegetation/barriers
	var space_state = get_world_3d().direct_space_state
	var target_avoid_force: float = float(traffic_info.get("cushion_force", 0.0))
	var fwd_dir = -visuals.global_transform.basis.z
	var right_dir = visuals.global_transform.basis.x
	var _prop_directly_ahead: bool = false
	var _closest_obstacle_side: float = 0.0  # -1 left, +1 right
	var closest_prop_dist: float = 99.0
	if space_state:
		var my_pos = global_position + visuals.global_transform.basis.y * 0.32
		var low_pos = global_position + visuals.global_transform.basis.y * 0.16
		var bumper_pos = global_position + visuals.global_transform.basis.y * 0.25 + fwd_dir * 0.5
		var rays = [
			# Forward center — long range early detection
			{"start": my_pos, "end": my_pos + fwd_dir * 22.0, "weight": 1.5, "side": 0.0},
			# Forward center low — catches low rocks/stumps
			{"start": low_pos, "end": low_pos + fwd_dir * 12.0, "weight": 1.6, "side": 0.0},
			# Bumper feeler — point blank obstacle contact
			{"start": bumper_pos, "end": bumper_pos + fwd_dir * 2.5, "weight": 2.5, "side": 0.0},
			# Narrow angled — main steering guidance
			{"start": my_pos, "end": my_pos + (fwd_dir - right_dir * 0.40).normalized() * 16.0, "weight": 1.2, "side": -1.0},
			{"start": my_pos, "end": my_pos + (fwd_dir + right_dir * 0.40).normalized() * 16.0, "weight": 1.2, "side": 1.0},
			# Wide angled — peripheral awareness
			{"start": my_pos, "end": my_pos + (fwd_dir - right_dir * 0.85).normalized() * 11.0, "weight": 0.9, "side": -1.0},
			{"start": my_pos, "end": my_pos + (fwd_dir + right_dir * 0.85).normalized() * 11.0, "weight": 0.9, "side": 1.0},
			# Near-side feelers — very close obstacle detection for last-second dodge
			{"start": my_pos, "end": my_pos + (fwd_dir - right_dir * 1.3).normalized() * 6.0, "weight": 0.7, "side": -1.0},
			{"start": my_pos, "end": my_pos + (fwd_dir + right_dir * 1.3).normalized() * 6.0, "weight": 0.7, "side": 1.0}
		]
		var is_start_grid_phase: bool = (Time.get_ticks_msec() / 1000.0 - race_start_time) < 3.0
		var obstacle_count = 0
		for ray in rays:
			var query = PhysicsRayQueryParameters3D.create(ray["start"], ray["end"])
			query.exclude = [self.get_rid()]
			query.collision_mask = 1 | 4
			var result = space_state.intersect_ray(query)
			if result:
				var collider = result.collider
				var is_prop: bool = _is_blocking_prop(collider)
				var is_other_cart: bool = collider.is_in_group("player_carts") or (collider is RigidBody3D and collider != self)
				if not is_prop and not is_other_cart:
					# Steep placed ramps have normal.y around 0.4–0.6; don't treat them as walls.
					if result.normal.y >= 0.32:
						continue
					if _is_track_surface(collider) or _is_world_terrain_collider(collider):
						continue
				if is_other_cart and (is_start_grid_phase or speed < 3.0):
					continue
				var dist = ray["start"].distance_to(result.position)
				if is_prop:
					closest_prop_dist = minf(closest_prop_dist, dist)
					if ray["side"] == 0.0 and dist < 6.5:
						_prop_directly_ahead = true
				var max_reach = 22.0 if ray["side"] == 0.0 else 16.0
				var intensity = clampf(1.0 - (dist / max_reach), 0.15, 1.0) * ray["weight"]
				if is_other_cart:
					var side_dir: float = -ray["side"] if ray["side"] != 0.0 else (-signf(dir_flat.x) if absf(dir_flat.x) > 0.05 else (1.0 if ai_overtake_bias >= 0.0 else -1.0))
					target_avoid_force += side_dir * 0.45 * intensity
					obstacle_count += 1
				else:
					var side_dir: float
					if ray["side"] == 0.0:
						var left_clear := _ai_clearance_ahead(space_state, my_pos + (-right_dir) * 3.0, fwd_dir, 14.0)
						var right_clear := _ai_clearance_ahead(space_state, my_pos + right_dir * 3.0, fwd_dir, 14.0)
						if absf(left_clear - right_clear) > 0.4:
							side_dir = -1.0 if left_clear > right_clear else 1.0
						else:
							var local_hit = visuals.global_transform.inverse() * result.position
							side_dir = -signf(local_hit.x) if absf(local_hit.x) > 0.08 else (1.0 if ai_overtake_bias >= 0.0 else -1.0)
					else:
						side_dir = -ray["side"]
					_closest_obstacle_side = side_dir
					# Much stronger avoidance for close props — exponentially stronger as distance shrinks
					var base_boost: float = 3.2 if is_prop else 2.0
					if dist < 5.0 and is_prop:
						base_boost = lerpf(6.0, 3.2, dist / 5.0)
					target_avoid_force += side_dir * base_boost * intensity
					obstacle_count += 1
		if obstacle_count > 0:
			if _harbor_stage:
				target_avoid_force *= 0.35
			# Slow down for close obstacles — brake harder the closer they are
			if closest_prop_dist < 12.0:
				var brake_t: float = clampf(1.0 - closest_prop_dist / 12.0, 0.0, 1.0)
				input.y = maxf(input.y, lerpf(0.05, 0.85, brake_t * brake_t))
		else:
			target_avoid_force = float(traffic_info.get("cushion_force", 0.0))

	_ai_avoid_force = lerpf(_ai_avoid_force, target_avoid_force, 14.0 * delta)
	
	# If an obstacle is close (< 7m), let avoidance steering dominate over track-seeking
	if closest_prop_dist < 7.0 and absf(_closest_obstacle_side) > 0.1:
		var steer_override = _closest_obstacle_side * clampf(2.0 - closest_prop_dist / 4.0, 0.8, 1.0)
		input.x = clampf(lerpf(input.x, steer_override, 0.75) + _ai_avoid_force * 0.5, -1.0, 1.0)
	else:
		input.x = clampf(input.x + _ai_avoid_force, -1.0, 1.0)
	
	# ── AI Obstacle Stuck Detection & Recovery ──────────────────────────────────
	# Detect when the bot is grinding against an obstacle (throttle on but barely moving)
	var is_actively_reversing: bool = _ai_obstacle_reverse_timer > 0.0
	var speed_stalling: bool = speed < 2.8 and input.y < -0.15 and not is_finished_race and can_move and not is_exploding
	var grinding_obstacle: bool = speed_stalling and (closest_prop_dist < 4.5 or _prop_directly_ahead)
	
	if is_actively_reversing:
		# Currently executing the back-off and drive sideways maneuver
		_ai_obstacle_reverse_timer -= delta
		if _ai_obstacle_reverse_timer > 0.0:
			var total_time: float = 1.5
			var reverse_phase_time: float = 0.8  # First 0.8s: back up with steering
			var elapsed: float = total_time - _ai_obstacle_reverse_timer
			if elapsed < reverse_phase_time:
				# Phase 1: Back off (reverse) while steering nose away from obstacle
				input.y = 0.85  # reverse throttle
				# In reverse physics, steering in _ai_obstacle_steer_dir swings the nose away
				input.x = _ai_obstacle_steer_dir * 0.95
			else:
				# Phase 2: Drive sideways & forward to clear the obstacle
				input.y = -0.9  # forward throttle
				input.x = _ai_obstacle_steer_dir * 1.0
			_ai_want_drift = false
		else:
			_ai_obstacle_reverse_timer = 0.0
			_ai_obstacle_stuck_timer = 0.0
			_ai_speed_stall_timer = 0.0
	elif grinding_obstacle:
		_ai_obstacle_stuck_timer += delta
		# React quickly after 0.4s of grinding against obstacle
		if _ai_obstacle_stuck_timer > 0.4:
			# Pick escape direction: check clearance on left vs right side
			if space_state:
				var my_pos = global_position + visuals.global_transform.basis.y * 0.32
				var left_clear := _ai_clearance_ahead(space_state, my_pos + (-right_dir) * 3.5, fwd_dir, 12.0)
				var right_clear := _ai_clearance_ahead(space_state, my_pos + right_dir * 3.5, fwd_dir, 12.0)
				if absf(left_clear - right_clear) > 0.5:
					_ai_obstacle_steer_dir = -1.0 if left_clear > right_clear else 1.0
				elif absf(_closest_obstacle_side) > 0.1:
					_ai_obstacle_steer_dir = _closest_obstacle_side
				elif absf(dir_flat.x) > 0.1:
					_ai_obstacle_steer_dir = signf(dir_flat.x)
				else:
					_ai_obstacle_steer_dir = 1.0 if randf() > 0.5 else -1.0
			else:
				_ai_obstacle_steer_dir = _closest_obstacle_side if absf(_closest_obstacle_side) > 0.1 else 1.0
			
			_ai_obstacle_reverse_timer = 1.5
			_ai_obstacle_stuck_timer = 0.0
	else:
		# Not grinding — decay the stuck timer
		if speed > 4.0:
			_ai_obstacle_stuck_timer = 0.0
		else:
			_ai_obstacle_stuck_timer = maxf(_ai_obstacle_stuck_timer - delta * 2.0, 0.0)

	# Speed stall fallback: if speed stays very low for a while (stuck on geometry the rays don't see)
	if speed < 1.5 and input.y < -0.1 and can_move and not is_exploding and not is_finished_race and not is_actively_reversing:
		_ai_speed_stall_timer += delta
		if _ai_speed_stall_timer > 0.6 and _ai_unstuck_dir == 0.0:
			_ai_unstuck_dir = signf(dir_flat.x) if absf(dir_flat.x) > 0.1 else (1.0 if randf() > 0.5 else -1.0)
		if _ai_speed_stall_timer > 3.8:
			# Really stuck — respawn
			_ai_speed_stall_timer = 0.0
			_ai_unstuck_dir = 0.0
			stuck_timer = 0.0
			if multiplayer.multiplayer_peer != null and multiplayer.is_server():
				respawn_rpc.rpc()
			else:
				respawn()
		elif _ai_speed_stall_timer > 1.6:
			# Reverse with steering
			input.y = 0.75
			input.x = _ai_unstuck_dir * 0.9
		elif _ai_speed_stall_timer > 0.6:
			# Brake then reverse gently
			input.y = 0.95
			input.x = clampf(-_ai_unstuck_dir * 0.6, -0.8, 0.8)
	else:
		if speed >= 3.0:
			_ai_speed_stall_timer = 0.0
			_ai_unstuck_dir = 0.0
			stuck_timer = 0.0

	return input


func _ai_alongside_goal() -> Vector3:
	# Aim at the next stretch of tarmac that is actually at our height (the landing),
	# not the jump heading — that points into the hills.
	# Biased toward the next checkpoint offset when recovering.
	if track_path == null or track_path.curve == null:
		return global_position
	var curve: Curve3D = track_path.curve
	var length: float = maxf(curve.get_baked_length(), 1.0)
	var start: float = _ai_last_ontrack_offset

	# Bias the search toward the next checkpoint's curve offset
	var next_cp_off: float = -1.0
	var lvl_ag: Node = _cached_level if is_instance_valid(_cached_level) else get_tree().get_first_node_in_group("level")
	if lvl_ag and "cp_offsets" in lvl_ag and "player_stats" in lvl_ag:
		var my_id: int = name.to_int()
		if lvl_ag.player_stats.has(my_id):
			var ncp: int = int(lvl_ag.player_stats[my_id]["next_checkpoint_idx"])
			if ncp >= 0 and ncp < lvl_ag.cp_offsets.size():
				next_cp_off = float(lvl_ag.cp_offsets[ncp])

	var best: Vector3 = Vector3.ZERO
	var best_score: float = INF
	var d: float = 8.0
	while d <= 100.0:
		var sample_off: float = fmod(start + d, length)
		var p: Vector3 = track_path.to_global(curve.sample_baked(sample_off))
		var dy: float = p.y - global_position.y
		if dy > 6.0:
			d += 6.0
			continue
		var xz: float = Vector2(global_position.x - p.x, global_position.z - p.z).length()
		if xz > 55.0:
			d += 6.0
			continue
		var score: float = xz + maxf(dy, 0.0) * 2.0
		# Bonus for being close to the next checkpoint's curve offset
		if next_cp_off >= 0.0:
			var cp_dist: float = absf(sample_off - next_cp_off)
			if cp_dist > length * 0.5:
				cp_dist = length - cp_dist  # wrap distance
			score += cp_dist * 0.08  # favor points near the checkpoint
		if score < best_score:
			best_score = score
			best = p
		d += 6.0
	if best != Vector3.ZERO:
		var to: Vector3 = best - global_position
		to.y = 0.0
		var space = get_world_3d().direct_space_state
		if space and to.length() > 1.5:
			var origin: Vector3 = global_position + Vector3.UP * 0.7
			var q := PhysicsRayQueryParameters3D.create(origin, origin + to.normalized() * minf(to.length(), 8.0))
			q.exclude = [get_rid()]
			q.collision_mask = 1 | 4
			var hit = space.intersect_ray(q)
			if not hit.is_empty() and float(hit.normal.y) < 0.45:
				# Bank in the way: stay put / creep along our current heading, don't climb the wall.
				return global_position + (-visuals.global_transform.basis.z) * 4.0
		return best
	# No reachable tarmac nearby — don't invent a heading into the desert.
	return global_position


## Returns the world-space position of the next expected checkpoint gate.
## Used during recovery so the bot navigates toward the correct gate.
func _ai_checkpoint_recovery_goal() -> Vector3:
	var lvl: Node = _cached_level if is_instance_valid(_cached_level) else get_tree().get_first_node_in_group("level")
	if lvl == null:
		return Vector3.ZERO
	if not ("checkpoints" in lvl and "player_stats" in lvl):
		return Vector3.ZERO
	var my_id: int = name.to_int()
	if not lvl.player_stats.has(my_id):
		return Vector3.ZERO
	var next_idx: int = int(lvl.player_stats[my_id]["next_checkpoint_idx"])
	if next_idx < 0 or next_idx >= lvl.checkpoints.size():
		return Vector3.ZERO
	var cp: Node3D = lvl.checkpoints[next_idx]
	if cp == null or not is_instance_valid(cp):
		return Vector3.ZERO
	return cp.global_position


func _ai_clearance_ahead(space_state: PhysicsDirectSpaceState3D, origin: Vector3, fwd: Vector3, reach: float) -> float:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + fwd * reach)
	query.exclude = [get_rid()]
	query.collision_mask = 1 | 4
	var hit = space_state.intersect_ray(query)
	if hit:
		if _is_blocking_prop(hit.collider) or hit.collider.is_in_group("player_carts"):
			return origin.distance_to(hit.position)
		if hit.normal.y < 0.55 and not _is_track_surface(hit.collider):
			return origin.distance_to(hit.position)
	return reach


func _ai_update_recovery(_delta: float, current_offset: float) -> void:
	if is_finished_race or on_alternative_path or track_path == null or track_path.curve == null:
		_ai_recovering = false
		return
	var track_pt: Vector3 = track_path.to_global(track_path.curve.sample_baked(current_offset))
	var height_below: float = track_pt.y - global_position.y
	var dist_xz: float = Vector2(global_position.x - track_pt.x, global_position.z - track_pt.z).length()

	# Per-stage thresholds: narrow tracks detect off-track sooner
	var xz_ok_thresh: float = 10.0
	var height_ok_thresh: float = 4.0
	var fall_height_thresh: float = 6.0
	var fall_xz_thresh: float = 12.0
	if _harbor_stage:
		xz_ok_thresh = 7.0
		height_ok_thresh = 3.0
		fall_height_thresh = 4.0
		fall_xz_thresh = 8.0
	elif _wadi_stage:
		# Wide open desert — be more lenient
		xz_ok_thresh = 14.0
		height_ok_thresh = 6.0
		fall_height_thresh = 10.0
		fall_xz_thresh = 18.0
	elif _mountain_stage:
		xz_ok_thresh = 9.0
		height_ok_thresh = 4.0
		fall_height_thresh = 7.0
		fall_xz_thresh = 12.0

	if dist_xz < xz_ok_thresh and height_below < height_ok_thresh:
		_ai_last_ontrack_offset = current_offset
		_ai_recovering = false
		return

	# Trigger recovery if fallen off (height drop) or strayed too far laterally
	var fallen: bool = (height_below > fall_height_thresh and (is_offroad or air_time > 0.8 or dist_xz > fall_xz_thresh)) \
		or (dist_xz > fall_xz_thresh * 1.5 and is_offroad)
	if not fallen:
		_ai_recovering = false
		return
	if not _ai_recovering:
		_ai_progress_sample_pos = global_position
		_ai_no_progress_timer = 0.0
		_ai_fall_origin = global_position
	_ai_recovering = true


func _ai_measure_upcoming_turn(curve: Curve3D, offset: float, speed: float) -> Dictionary:
	var length: float = maxf(curve.get_baked_length(), 1.0)
	var look: float = clampf(speed * 1.2, 18.0, 56.0)
	if _mountain_stage:
		look = minf(look, 28.0)
	var p0: Vector3 = curve.sample_baked(offset)
	var p0b: Vector3 = curve.sample_baked(fmod(offset + 1.5, length))
	var h0: Vector3 = p0b - p0
	h0.y = 0.0
	if h0.length_squared() < 1e-6:
		return {"angle": 0.0, "dir": 0.0, "dist": look, "near_angle": 0.0}
	h0 = h0.normalized()

	var worst_ang: float = 0.0
	var worst_dir: float = 0.0
	var worst_dist: float = look
	var near_ang: float = 0.0
	var d: float = 4.0
	while d <= look:
		var o1: float = fmod(offset + d, length)
		var p1: Vector3 = curve.sample_baked(o1)
		var p1b: Vector3 = curve.sample_baked(fmod(o1 + 1.5, length))
		var h1: Vector3 = p1b - p1
		h1.y = 0.0
		if h1.length_squared() > 1e-6:
			h1 = h1.normalized()
			var ang: float = h0.signed_angle_to(h1, Vector3.UP)
			if absf(ang) > absf(worst_ang):
				worst_ang = ang
				worst_dir = signf(ang)
				worst_dist = d
			if d <= 16.0 and absf(ang) > absf(near_ang):
				near_ang = ang
		d += 4.0
	return {"angle": absf(worst_ang), "dir": worst_dir, "dist": worst_dist, "near_angle": absf(near_ang)}


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
			# Only fire boosts on a real straight — never into a dock corner or while already turning.
			var boost_ang: float = 0.32
			var boost_dist: float = 26.0
			var boost_steer: float = 0.16
			if _harbor_stage:
				boost_ang = 0.18
				boost_dist = 34.0
			else:
				boost_ang = lerpf(0.32, 0.60, ai_aggression)
				boost_dist = lerpf(26.0, 11.0, ai_aggression)
				boost_steer = lerpf(0.16, 0.34, ai_aggression)
			var upcoming_ok: bool = _ai_upcoming_turn_angle < boost_ang and _ai_upcoming_turn_dist > boost_dist
			if abs(sync_steer) < boost_steer and upcoming_ok and linear_velocity.length() > 6.0:
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


func _on_camera_mode_setting_changed(iso: bool) -> void:
	if not is_local_player:
		return
	_set_isometric_camera(iso, false)


func _set_isometric_camera(iso: bool, persist: bool) -> void:
	if is_isometric == iso:
		if persist:
			MusicManager.set_use_isometric_camera(iso)
		return
	is_isometric = iso
	if camera:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	if not is_isometric:
		camera_clip_distance_mult = 1.0
	else:
		camera_clip_distance_mult_iso = 1.0
	_clear_camera_xray_immediate()
	_cached_cam_below_terrain = false
	if race_ui:
		race_ui.set_terrain_clipped(false)
	if persist:
		MusicManager.set_use_isometric_camera(is_isometric)


func _is_world_collider(collider: Object) -> bool:
	if collider == null:
		return false
	var n := str(collider.name)
	if n.contains("Unified_World_Collision") or n.contains("Terrain") or n.contains("Static"):
		return true
	# Generated track/prop collision bodies often sit under level nodes
	if collider is CollisionObject3D:
		var p: Node = (collider as Node).get_parent()
		if p and (str(p.name).contains("Terrain") or str(p.name).contains("Track") or str(p.name).contains("World")):
			return true
	return false


func _is_terrain_collider(collider: Object) -> bool:
	if collider == null:
		return false
	var n := str(collider.name)
	return n.contains("Unified_World_Collision") or n.contains("Terrain") or n.contains("track_collision") or n.contains("terrain")


func _get_water_surface_y_at(pos: Vector3) -> float:
	if not stage_has_water:
		return -9999.0
	if water_bounds_active:
		if not (pos.x >= water_bounds_min.x and pos.x <= water_bounds_max.x \
				and pos.z >= water_bounds_min.y and pos.z <= water_bounds_max.y):
			return -9999.0
	if is_instance_valid(_wadi_water_tg) and _wadi_water_tg.has_method("is_wadi_water_at"):
		if not bool(_wadi_water_tg.call("is_wadi_water_at", pos.x, pos.z)):
			return -9999.0
	return water_surface_y


func _raise_point_above_terrain(pos: Vector3, excludes: Array) -> Vector3:
	var space_state = get_world_3d().direct_space_state
	if space_state != null:
		# Cast from well above down through the camera point
		var from := pos + Vector3(0.0, 40.0, 0.0)
		var to := pos + Vector3(0.0, -25.0, 0.0)
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = excludes
		var result = space_state.intersect_ray(query)
		_cached_cam_below_terrain = false
		if result and result.collider and _is_terrain_collider(result.collider):
			var terrain_y: float = result.position.y
			var min_y: float = terrain_y + maxf(_ISO_CAM_CLEARANCE, 1.8)
			if pos.y < min_y:
				# Still considered "deep" only if substantially under surface after clamp intent
				_cached_cam_below_terrain = pos.y < terrain_y - 0.25
				pos.y = min_y

	# Follower camera must never go underwater — clamp safely above water surface
	var water_y = _get_water_surface_y_at(pos)
	if water_y > -9000.0:
		var min_water_cam_y = water_y + 1.3
		if pos.y < min_water_cam_y:
			pos.y = min_water_cam_y

	return pos


func _find_geometry_for_collider(collider: Object) -> Array:
	var out: Array = []
	if collider == null or not (collider is Node):
		return out
	var root := collider as Node
	# Prefer geometry under the collision body; also check siblings under shared parent (FBX)
	var candidates: Array = [root]
	if root.get_parent():
		candidates.append(root.get_parent())
	for node in candidates:
		if node is GeometryInstance3D:
			out.append(node)
		for c in node.get_children():
			if c is GeometryInstance3D:
				out.append(c)
			elif c is Node3D:
				for c2 in c.get_children():
					if c2 is GeometryInstance3D:
						out.append(c2)
	return out


func _update_camera_xray(cam_pos: Vector3, car_pos: Vector3, excludes: Array, delta: float) -> void:
	var space_state = get_world_3d().direct_space_state
	if space_state == null:
		_fade_out_all_xray(delta)
		return
	var seen: Dictionary = {}
	var dir: Vector3 = car_pos - cam_pos
	var max_dist: float = dir.length()
	if max_dist < 0.5:
		_fade_out_all_xray(delta)
		return
	dir /= max_dist
	var excl: Array = excludes.duplicate()
	var cursor: Vector3 = cam_pos
	for _i in range(5):
		var query := PhysicsRayQueryParameters3D.create(cursor, car_pos)
		query.exclude = excl
		var result = space_state.intersect_ray(query)
		if not result:
			break
		excl.append(result.rid)
		var hit_dist: float = cam_pos.distance_to(result.position)
		# Ignore the last bit near the car body
		if hit_dist > max_dist - 0.6:
			break
		# Terrain: do not ghost the whole landscape — camera raise handles it
		if result.collider and _is_terrain_collider(result.collider):
			cursor = result.position + dir * 0.2
			continue
		for gi in _find_geometry_for_collider(result.collider):
			if gi == null or not is_instance_valid(gi):
				continue
			# Never x-ray the player cart visuals
			if visuals and (gi == visuals or visuals.is_ancestor_of(gi) or gi.is_ancestor_of(visuals)):
				continue
			var id: int = gi.get_instance_id()
			seen[id] = true
			_xray_meshes[id] = gi
			_xray_target[id] = _XRAY_TRANSPARENCY
		cursor = result.position + dir * 0.2

	# Fade targets for meshes no longer occluding
	for id in _xray_target.keys():
		if not seen.has(id):
			_xray_target[id] = 0.0

	_apply_xray_fade(delta)


func _fade_out_all_xray(delta: float) -> void:
	for id in _xray_target.keys():
		_xray_target[id] = 0.0
	_apply_xray_fade(delta)


func _apply_xray_fade(delta: float) -> void:
	var to_remove: Array = []
	for id in _xray_meshes.keys():
		var gi = _xray_meshes[id]
		if gi == null or not is_instance_valid(gi):
			to_remove.append(id)
			continue
		var target_t: float = float(_xray_target.get(id, 0.0))
		var cur: float = gi.transparency
		var next_t: float = move_toward(cur, target_t, _XRAY_FADE_SPEED * delta)
		gi.transparency = next_t
		if target_t <= 0.001 and next_t <= 0.001:
			gi.transparency = 0.0
			to_remove.append(id)
	for id in to_remove:
		_xray_meshes.erase(id)
		_xray_target.erase(id)


func _clear_camera_xray_immediate() -> void:
	for id in _xray_meshes.keys():
		var gi = _xray_meshes[id]
		if gi != null and is_instance_valid(gi):
			gi.transparency = 0.0
	_xray_meshes.clear()
	_xray_target.clear()


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
	_clear_camera_xray_immediate()
	if MusicManager.camera_mode_changed.is_connected(_on_camera_mode_setting_changed):
		MusicManager.camera_mode_changed.disconnect(_on_camera_mode_setting_changed)
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

func _unhandled_input(event: InputEvent) -> void:
	if not is_local_player or not is_finished_race or finish_spectate_delay > 0.0:
		return
		
	# Spectator zoom controls (+ / - and Mouse Wheel)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			spectator_zoom = clampf(spectator_zoom - 0.12, 0.45, 2.2)
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			spectator_zoom = clampf(spectator_zoom + 0.12, 0.45, 2.2)
			get_viewport().set_input_as_handled()
			return
			
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_PLUS, KEY_EQUAL, KEY_KP_ADD:
				spectator_zoom = clampf(spectator_zoom - 0.12, 0.45, 2.2)
				get_viewport().set_input_as_handled()
				return
			KEY_MINUS, KEY_UNDERSCORE, KEY_KP_SUBTRACT:
				spectator_zoom = clampf(spectator_zoom + 0.12, 0.45, 2.2)
				get_viewport().set_input_as_handled()
				return
			KEY_BRACKETLEFT, KEY_COMMA, KEY_Q:
				_cycle_spectate(-1)
				get_viewport().set_input_as_handled()
				return
			KEY_BRACKETRIGHT, KEY_PERIOD, KEY_E:
				_cycle_spectate(1)
				get_viewport().set_input_as_handled()
				return
			KEY_1, KEY_KP_1:
				_select_spectate_slot(0)
				get_viewport().set_input_as_handled()
				return
			KEY_2, KEY_KP_2:
				_select_spectate_slot(1)
				get_viewport().set_input_as_handled()
				return
			KEY_3, KEY_KP_3:
				_select_spectate_slot(2)
				get_viewport().set_input_as_handled()
				return
			KEY_4, KEY_KP_4:
				_select_spectate_slot(3)
				get_viewport().set_input_as_handled()
				return
			KEY_5, KEY_KP_5:
				_select_spectate_slot(4)
				get_viewport().set_input_as_handled()
				return
			KEY_6, KEY_KP_6:
				_select_spectate_slot(5)
				get_viewport().set_input_as_handled()
				return

func _cycle_spectate(dir: int) -> void:
	var all_carts = get_tree().get_nodes_in_group("player_carts")
	var active_racing_carts: Array[Node3D] = []
	for c in all_carts:
		if is_instance_valid(c) and c is Node3D and not c.get("is_finished_race"):
			active_racing_carts.append(c)
	if active_racing_carts.is_empty():
		for c in all_carts:
			if is_instance_valid(c) and c is Node3D:
				active_racing_carts.append(c)
	if active_racing_carts.is_empty():
		return
	spectate_index = posmod(spectate_index + dir, active_racing_carts.size())
	spectate_target_cart = active_racing_carts[spectate_index]
	spectate_timer = 10.0
	if race_ui and race_ui.has_method("show_message"):
		var r_name = str(spectate_target_cart.get("player_name"))
		if r_name.is_empty(): r_name = spectate_target_cart.name
		race_ui.show_message("Spectating: %s" % r_name, 1.5)

func _select_spectate_slot(slot: int) -> void:
	var all_carts: Array[Node3D] = []
	for c in get_tree().get_nodes_in_group("player_carts"):
		if is_instance_valid(c) and c is Node3D:
			all_carts.append(c)
	if slot < 0 or slot >= all_carts.size():
		return
	spectate_target_cart = all_carts[slot]
	spectate_index = slot
	spectate_timer = 10.0
	if race_ui and race_ui.has_method("show_message"):
		var r_name = str(spectate_target_cart.get("player_name"))
		if r_name.is_empty(): r_name = spectate_target_cart.name
		race_ui.show_message("Spectating: %s" % r_name, 1.5)
