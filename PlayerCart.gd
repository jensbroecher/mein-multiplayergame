extends RigidBody3D

@export var player_name: String = "Player":
	set(value):
		player_name = value
		if is_inside_tree() and $Visuals/NameTag:
			$Visuals/NameTag.text = value

# Vehicle Parameters
const MAX_SPEED = 30.0
const REVERSE_SPEED = 15.0
const ACCELERATION = 50.0
const BRAKING = 40.0
const STEER_SPEED = 2.5
const GRIP = 5.0

const GRAVITY = 30.0 # extra gravity so it falls faster

# Wheel/collision alignment constants
const WHEEL_RADIUS = 0.4
const WHEEL_Y_OFFSET = -0.021691  # Match the actual WheelPivot Y position to prevent hovering
const COLLISION_Y_OFFSET = 0.0  # Collision sphere center relative to body center
const COLLISION_RADIUS = WHEEL_RADIUS + 0.2  # Slightly larger to prevent tunneling without CCD

# Preload item scenes
const MISSILE_SCENE = preload("res://Missile.tscn")
const BOMB_SCENE = preload("res://Bomb.tscn")

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
@onready var sfx_wind_loop = $Visuals/SFX_WindLoop
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
var wheel_rotation: float = 0.0
var is_teleporting: bool = false
var is_shielded: bool = false
var camera_look_at: Vector3 = Vector3.ZERO
var is_isometric: bool = false
var engine_phase: float = 0.0
var hop_cooldown: float = 0.0

var is_underwater: bool = false
const WATER_LEVEL = -10.0
var water_timer: float = 0.0

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

func on_race_started():
	if is_local_player:
		can_move = true

func _ready():
	add_to_group("player_carts")
	_update_authority()

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
		
		# Lock rotation so we handle it manually
		axis_lock_angular_x = true
		axis_lock_angular_y = true
		axis_lock_angular_z = true

		if not InputMap.has_action("toggle_camera"):
			InputMap.add_action("toggle_camera")
			var ev = InputEventKey.new()
			ev.physical_keycode = KEY_C
			InputMap.action_add_event("toggle_camera", ev)
	else:
		camera.current = false
		if has_node("Visuals/CameraPivot/Camera3D/AudioListener3D"):
			get_node("Visuals/CameraPivot/Camera3D/AudioListener3D").current = false

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
	if is_local_player:
		_update_visuals_alignment(delta)

		if Input.is_action_just_pressed("toggle_camera"):
			is_isometric = not is_isometric
			if is_isometric:
				camera.projection = Camera3D.PROJECTION_ORTHOGONAL
				camera.size = 22.0
				camera.far = 150.0
				camera.near = 0.1
			else:
				camera.projection = Camera3D.PROJECTION_PERSPECTIVE
				camera.far = 4000.0
				camera.near = 0.05

		if is_isometric:
			var iso_offset = Vector3(-20, 20, 20)
			var target_cam_pos = visuals.global_position + iso_offset
			
			# Avoid clipping through bridge/terrain
			var space_state = get_world_3d().direct_space_state
			var ray_start = visuals.global_position + Vector3.UP * 1.0
			var query = PhysicsRayQueryParameters3D.create(ray_start, target_cam_pos)
			query.exclude = [self.get_rid()]
			var result = space_state.intersect_ray(query)
			if result:
				target_cam_pos = result.position - (target_cam_pos - ray_start).normalized() * 0.5
				
			camera_pivot.global_position = camera_pivot.global_position.lerp(target_cam_pos, 10.0 * delta)
			camera_pivot.look_at(visuals.global_position, Vector3.UP)
		else:
			var cam_dist = lerp(3.5, 6.0, clamp(boost_time / 4.0, 0.0, 1.0))
			
			# Smooth camera trailing
			var visual_forward = -visuals.global_transform.basis.z
			var target_cam_pos = visuals.global_position - visual_forward * cam_dist + Vector3(0, 1.5, 0)
			
			# Avoid clipping through bridge/terrain
			var space_state = get_world_3d().direct_space_state
			var ray_start = visuals.global_position + Vector3.UP * 1.0
			var query = PhysicsRayQueryParameters3D.create(ray_start, target_cam_pos)
			query.exclude = [self.get_rid()]
			var result = space_state.intersect_ray(query)
			if result:
				target_cam_pos = result.position - (target_cam_pos - ray_start).normalized() * 0.5
				
			camera_pivot.global_position = camera_pivot.global_position.lerp(target_cam_pos, 10.0 * delta)
			
			camera_look_at = camera_look_at.lerp(visuals.global_position + visual_forward * 5.0, 12.0 * delta)
			camera_pivot.look_at(camera_look_at, Vector3.UP)

		if race_ui:
			race_ui.update_speed(linear_velocity.length() * 1.8)

		if engine_sound.stream is AudioStreamGenerator and engine_sound.playing:
			_fill_audio_buffer()
	else:
		_interpolate_remote(delta)

func _physics_process(delta):
	if hop_cooldown > 0:
		hop_cooldown -= delta

	if is_teleporting:
		return

	if global_position.y < -50:
		respawn()

	if is_exploding:
		if is_local_player:
			apply_central_force(Vector3.UP * 5.0)
		
		if sfx_fire_loop.playing:
			sfx_fire_loop.volume_db = lerp(sfx_fire_loop.volume_db, -10.0, 2.0 * delta)

		burning_particles.global_position = global_position + Vector3(0, 0.5, 0)
		burning_smoke_particles.global_position = global_position + Vector3(0, 0.5, 0)
		if is_local_player:
			_move_and_sync()
		return

	var currently_underwater = global_position.y < WATER_LEVEL
	if currently_underwater != is_underwater:
		if currently_underwater:
			sfx_landing_bonk.play()
			linear_velocity *= 0.5
		is_underwater = currently_underwater
		water_timer = 0.0

	if is_underwater:
		water_timer += delta
		if water_timer > 2.0:
			explode()
		apply_central_force(Vector3.UP * 15.0)

	if not is_local_player:
		return

	# Apply extra gravity
	apply_central_force(Vector3.DOWN * GRAVITY * mass)

	if not can_move:
		linear_velocity = linear_velocity.lerp(Vector3.ZERO, 3.0 * delta)
		_move_and_sync()
		return

	# DEBUG: Print input state
	if Input.is_action_just_pressed("boost"):
		print("DEBUG: Boost pressed, current_item = ", current_item, " (", ItemType.keys()[current_item] if current_item < ItemType.keys().size() else "invalid", ")")
		_use_item()

	var input_dir = Vector2.ZERO
	input_dir.x = Input.get_axis("steer_left", "steer_right")
	input_dir.y = Input.get_axis("throttle", "brake")

	# DEBUG: Print input_dir occasionally
	if abs(input_dir.y) > 0.1 or abs(input_dir.x) > 0.1:
		print("DEBUG: input_dir = ", input_dir, " on_ground check...")

	var on_ground = ground_ray.is_colliding()
	var ground_normal = Vector3.UP
	if on_ground:
		ground_normal = ground_ray.get_collision_normal()

	# DEBUG
	if not on_ground:
		print("DEBUG: NOT on ground! ground_ray target: ", ground_ray.target_position, " global_pos: ", global_position)

	var fwd = -visuals.global_transform.basis.z
	var right = visuals.global_transform.basis.x

	current_steer = lerp(current_steer, input_dir.x, 10.0 * delta)

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

	# Handle acceleration/braking even when slightly airborne for better control
	var current_speed = linear_velocity.dot(fwd)
	var accel_force = 0.0
	
	if input_dir.y < -0.1: # Forward
		var max_sp = MAX_SPEED
		if boost_timer > 0:
			max_sp *= 1.5
			accel_force = ACCELERATION * 2.0
			boost_timer -= delta
			is_boosting = true
			if not sfx_rocket_loop.playing: sfx_rocket_loop.play()
		else:
			is_boosting = false
			accel_force = ACCELERATION
			if sfx_rocket_loop.playing: sfx_rocket_loop.stop()
		
		if current_speed < max_sp:
			apply_central_force(fwd * accel_force * mass)
		boost_time += delta
		
	elif input_dir.y > 0.1: # Brake / Reverse
		boost_time = 0.0
		is_boosting = false
		if sfx_rocket_loop.playing: sfx_rocket_loop.stop()
		
		if current_speed > 1.0:
			# Brake hard when moving forward
			apply_central_force(-fwd * BRAKING * mass)
		elif current_speed < -0.5:
			# Already moving backward, apply reverse acceleration (more speed)
			if current_speed > -REVERSE_SPEED:
				apply_central_force(-fwd * (ACCELERATION * 0.5) * mass)
		else:
			# Stationary or very slow - initiate reverse
			if current_speed > -REVERSE_SPEED:
				apply_central_force(-fwd * (ACCELERATION * 0.7) * mass)
	else:
		boost_time = 0.0
		is_boosting = false
		if sfx_rocket_loop.playing: sfx_rocket_loop.stop()
		# Natural friction
		apply_central_force(-linear_velocity * 0.5 * mass)

	# Steering (works on ground and slightly airborne)
	if on_ground or linear_velocity.length() > 0.5:
		if linear_velocity.length() > 1.0:
			var turn_speed = STEER_SPEED
			if abs(input_dir.x) > 0.1 and input_dir.y > 0.1 and current_speed > 5.0:
				# Drifting (handbrake)
				turn_speed *= 1.5
				if not sfx_brake_drift.playing: sfx_brake_drift.play()
				is_drifting = true
			else:
				if sfx_brake_drift.playing: sfx_brake_drift.stop()
				is_drifting = false
			
			var steer_amount = -current_steer * turn_speed * (min(linear_velocity.length() / 10.0, 1.0)) * delta
			visuals.global_rotate(ground_normal, steer_amount)
			
			# Kill lateral velocity (adds grip)
			var lat_vel = linear_velocity.dot(right)
			var grip_factor = GRIP
			if is_drifting: grip_factor *= 0.3
			apply_central_force(-right * lat_vel * mass * grip_factor)
	else:
		is_boosting = false
		if sfx_rocket_loop.playing: sfx_rocket_loop.stop()
		if sfx_brake_drift.playing: sfx_brake_drift.stop()
		is_drifting = false
		
		# Slight air control
		visuals.global_rotate(Vector3.UP, -current_steer * STEER_SPEED * 0.5 * delta)

	# Wind sound
	var speed = linear_velocity.length()
	if speed > 20.0 and on_ground:
		if not sfx_wind_loop.playing:
			sfx_wind_loop.play()
		sfx_wind_loop.volume_db = lerp(sfx_wind_loop.volume_db, -10.0, 2.0 * delta)
	else:
		sfx_wind_loop.volume_db = lerp(sfx_wind_loop.volume_db, -40.0, 5.0 * delta)
		if sfx_wind_loop.volume_db < -35.0:
			sfx_wind_loop.stop()

	sync_steer = current_steer
	_move_and_sync()

func _update_visuals_alignment(delta):
	var on_ground = ground_ray.is_colliding()
	var normal = Vector3.UP
	if on_ground:
		normal = ground_ray.get_collision_normal()
		
	# Smoothly align the visual mesh normal
	var current_basis = visuals.global_transform.basis
	var forward = -current_basis.z
	var right = current_basis.x

	var target_up = normal
	var target_right = forward.cross(target_up).normalized()
	var target_forward = target_up.cross(target_right).normalized()

	var target_basis = Basis(target_right, target_up, -target_forward)
	visuals.global_transform.basis = current_basis.slerp(target_basis, 8.0 * delta)

	# Position visuals so wheels sit on ground (collision sphere bottom aligns with ground)
	# collision sphere center is at global_position + COLLISION_Y_OFFSET
	# collision sphere bottom is at global_position.y + COLLISION_Y_OFFSET - COLLISION_RADIUS
	# wheels visual center should be at that height + WHEEL_RADIUS (so wheel bottom touches ground)
	# visual origin needs to be at: wheel_center_y - WHEEL_Y_OFFSET
	var wheel_visual_y = global_position.y + COLLISION_Y_OFFSET - COLLISION_RADIUS + WHEEL_RADIUS
	visuals.global_position = Vector3(global_position.x, wheel_visual_y - WHEEL_Y_OFFSET, global_position.z)

	_update_wheel_visuals(delta)

func _fill_audio_buffer():
	if not playback: return
	var available = playback.get_frames_available()
	if available == 0: return

	# Electric RC motor frequency mapping
	var freq = 200.0 + linear_velocity.length() * 25.0
	if is_boosting: freq *= 1.5

	for i in range(available):
		engine_phase += freq / sample_rate
		if engine_phase > 1.0:
			engine_phase -= 1.0
		
		# Electric RC motor sound: high pitch whine + first harmonic + gear whine
		var sample = sin(engine_phase * TAU) * 0.25
		sample += sin(engine_phase * 2.0 * TAU) * 0.15
		sample += sin(engine_phase * 3.0 * TAU) * 0.08
		playback.push_frame(Vector2(sample, sample))

func _update_wheel_visuals(delta):
	var speed = linear_velocity.length()
	var fwd_dot = linear_velocity.dot(-visuals.global_transform.basis.z)
	var rot_speed = speed * sign(fwd_dot) / 0.4 # approx radius
	wheel_rotation -= rot_speed * delta

	for wheel in ["FL", "FR", "RL", "RR"]:
		var w_node = get_node_or_null("Visuals/WheelPivot" + wheel)
		if w_node:
			if wheel == "FL" or wheel == "FR":
				# Rotate on Y for steering
				w_node.rotation.y = -sync_steer * 0.5
			
			var wrapper = w_node.get_node_or_null(wheel + "_Wrapper")
			if wrapper:
				var y_rot = PI / 2 if (wheel == "FL" or wheel == "RL") else -PI / 2
				var z_rot = -wheel_rotation if (wheel == "FL" or wheel == "RL") else wheel_rotation
				wrapper.rotation = Vector3(0, y_rot, z_rot)

func _interpolate_remote(delta: float):
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

	# Remotes also need their visuals to follow the rigid body with proper wheel alignment
	visuals.global_transform.basis = Basis(new_quat)
	
	# Position visuals so wheels sit on ground (same as local player)
	var wheel_visual_y = global_position.y + COLLISION_Y_OFFSET - COLLISION_RADIUS + WHEEL_RADIUS
	visuals.global_position = Vector3(global_position.x, wheel_visual_y - WHEEL_Y_OFFSET, global_position.z)

	var speed := sync_velocity.length()
	var wheel_spin_rate := speed / 0.4
	wheel_rotation -= wheel_spin_rate * delta

	for wheel in ["FL", "FR", "RL", "RR"]:
		var w_node = get_node_or_null("Visuals/WheelPivot" + wheel)
		if w_node:
			if wheel == "FL" or wheel == "FR":
				w_node.rotation.y = -sync_steer * 0.5
			
			var wrapper = w_node.get_node_or_null(wheel + "_Wrapper")
			if wrapper:
				var y_rot = PI / 2 if (wheel == "FL" or wheel == "RL") else -PI / 2
				var z_rot = -wheel_rotation if (wheel == "FL" or wheel == "RL") else wheel_rotation
				wrapper.rotation = Vector3(0, y_rot, z_rot)

func _setup_new_car_wheels():
	# Hide FBX wheel parts (part_0, part_2, part_5, part_6) and use the glb wheel instances at pivots
	var fbx_wheel_paths = ["CartModel/part_0", "CartModel/part_2", "CartModel/part_5", "CartModel/part_6"]
	for path in fbx_wheel_paths:
		var node = get_node_or_null("Visuals/" + path)
		if node:
			node.visible = false
	
	# The glb wheel instances at WheelPivotFL/FR/RL/RR are already positioned correctly
	# Just ensure they're visible and have proper material
	for wheel in ["FL", "FR", "RL", "RR"]:
		var pivot_node = get_node_or_null("Visuals/WheelPivot" + wheel)
		if pivot_node:
			pivot_node.visible = true
			if pivot_node.get_child_count() > 0:
				var wheel_mesh = pivot_node.get_child(0)
				
				# Create a wrapper node to act as the clean center of rotation
				var wrapper = Node3D.new()
				wrapper.name = wheel + "_Wrapper"
				pivot_node.add_child(wrapper)
				
				# Reparent wheel_mesh under the wrapper, preserving its local transform from the editor
				wheel_mesh.reparent(wrapper, false)
				
				# Position wrapper at pivot origin (0, 0, 0)
				wrapper.position = Vector3.ZERO
				
				if wheel_mesh is MeshInstance3D:
					var dark_mat = StandardMaterial3D.new()
					dark_mat.albedo_color = Color(0.12, 0.12, 0.12)
					dark_mat.roughness = 0.85
					wheel_mesh.material_override = dark_mat

func _move_and_sync():
	sync_position = global_position
	# Store visual rotation, not rigid body rotation (which is locked)
	sync_rotation = visuals.rotation
	sync_velocity = linear_velocity
	sync_rotation_quat = Quaternion.from_euler(visuals.rotation)

func _use_item():
	if current_item == ItemType.NONE: return
	match current_item:
		ItemType.BOOST:
			boost_timer = 2.0
			sfx_nitro_start.play()
			boost_particles.emitting = true
		ItemType.MISSILE:
			_fire_missile(false)
		ItemType.GUIDED_MISSILE:
			_fire_missile(true)
		ItemType.SHIELD:
			_activate_shield()
		ItemType.SHOCKWAVE:
			_activate_shockwave()
		ItemType.BOMB:
			_drop_bomb()
	current_item = ItemType.NONE

func explode():
	if is_exploding: return
	is_exploding = true
	can_move = false
	sfx_explosion.play()
	sfx_fire_loop.play()
	explosion_particles.emitting = true
	burning_particles.emitting = true
	burning_smoke_particles.emitting = true
	if engine_sound.playing: engine_sound.stop()
	linear_velocity += Vector3(randf()-0.5, 10.0, randf()-0.5).normalized() * 15.0

func respawn():
	is_exploding = false
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
	sfx_fire_loop.stop()

	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	var spawn_pos = last_checkpoint_transform.origin + (last_checkpoint_transform.basis.z * 5.0) + Vector3(0, 2.0, 0)
	global_position = spawn_pos

	# Reset visuals position to align wheels with ground
	var wheel_visual_y = global_position.y + COLLISION_Y_OFFSET - COLLISION_RADIUS + WHEEL_RADIUS
	visuals.global_position = Vector3(global_position.x, wheel_visual_y - WHEEL_Y_OFFSET, global_position.z)

	var look_target = last_checkpoint_transform.origin
	look_target.y = spawn_pos.y
	visuals.look_at(look_target, Vector3.UP)

	if not engine_sound.playing: engine_sound.play()

func give_item(type: int):
	current_item = type as ItemType
	if is_local_player and race_ui:
		var item_name = ItemType.keys()[type]
		race_ui.update_item(item_name)

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
	if not is_local_player: return
	var missile = MISSILE_SCENE.instantiate()
	missile.owner_id = name.to_int()
	missile.is_guided = guided
	missile.global_position = global_position + (-visuals.global_transform.basis.z * 2.0) + Vector3(0, 1.0, 0)
	missile.global_rotation = visuals.global_rotation
	get_tree().root.add_child(missile)
	if multiplayer.is_server():
		missile.set_multiplayer_authority(1)

func _activate_shield():
	if not is_local_player: return
	is_shielded = true
	shield_mesh.visible = true
	# Shield lasts 10 seconds
	get_tree().create_timer(10.0).timeout.connect(_on_shield_timeout.bind())

func _on_shield_timeout():
	is_shielded = false
	shield_mesh.visible = false

func _activate_shockwave():
	if not is_local_player: return
	# Create shockwave visual
	shockwave_visual.visible = true
	shockwave_visual.scale = Vector3(0.1, 0.1, 0.1)
	var tween = create_tween()
	tween.tween_property(shockwave_visual, "scale", Vector3(15.0, 15.0, 15.0), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(shockwave_visual, "material:albedo_color:a", 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func(): shockwave_visual.visible = false)
	
	# Apply force to nearby players
	if multiplayer.is_server():
		var players = get_tree().get_nodes_in_group("player_carts")
		for p in players:
			if p == self: continue
			var dist = global_position.distance_to(p.global_position)
			if dist < 15.0:
				var dir = (p.global_position - global_position).normalized()
				p.apply_central_force(dir * 2000.0 + Vector3.UP * 500.0)

func _drop_bomb():
	if not is_local_player: return
	var bomb = BOMB_SCENE.instantiate()
	bomb.owner_id = name.to_int()
	bomb.global_position = global_position + Vector3(0, 1.0, 0)
	bomb.linear_velocity = linear_velocity * 0.5
	get_tree().root.add_child(bomb)
	if multiplayer.is_server():
		bomb.set_multiplayer_authority(1)

func _enable_shadows_recursive(node: Node):
	if node == null: return
	if node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for child in node.get_children():
		_enable_shadows_recursive(child)