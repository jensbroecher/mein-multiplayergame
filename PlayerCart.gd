extends VehicleBody3D

@export var player_name: String = "Player":
	set(value):
		player_name = value
		if is_inside_tree() and $Visuals/NameTag:
			$Visuals/NameTag.text = value

const SPEED = 25.0
const REVERSE_SPEED = 12.0
const STEER_SPEED = 0.6
const ENGINE_FORCE = 4000.0
const BRAKE_FORCE = 300.0
const HANDBRAKE_FORCE = 500.0

const GRAVITY = 9.8

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

var playback: AudioStreamGeneratorPlayback
var sample_rate: float

var bounce_y = 0.0
var bounce_vel = 0.0
var frame_bump_y = 0.0
var frame_bump_vel = 0.0

var is_local_player = false
var can_move = false
var can_control = true

var is_exploding = false
var heat = 0.0
var boost_time = 0.0
var boost_timer = 0.0
var is_boosting = false
var is_waiting_to_explode = false

var tumble_velocity: Vector3 = Vector3.ZERO
var warning_beep_timer: float = 0.0

@onready var sfx_brake_drift = $Visuals/SFX_BrakeDrift
var is_drifting: bool = false
var wheel_rotation: float = 0.0
var is_teleporting: bool = false
var is_shielded: bool = false
var wheel_pivots: Dictionary = {}

var is_underwater: bool = false
const WATER_LEVEL = -10.0
var water_timer: float = 0.0

enum ItemType { NONE, BOOST, MISSILE, GUIDED_MISSILE, SHIELD, SHOCKWAVE, BOMB }
var current_item = ItemType.NONE

var last_checkpoint_transform: Transform3D

var sync_position: Vector3
var sync_rotation: Vector3
var sync_velocity: Vector3
var sync_steer: float = 0.0

var visual_steer: float = 0.0
var was_on_floor: bool = false


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

	name_tag.text = player_name
	last_checkpoint_transform = global_transform

	visuals.top_level = true

	if engine_sound.stream is AudioStreamGenerator:
		sample_rate = engine_sound.stream.mix_rate
		playback = engine_sound.get_stream_playback()
		if not engine_sound.playing:
			engine_sound.play()
	
	# Setup new car wheels
	_setup_new_car_wheels()
	
	if is_local_player:
		camera.current = true
		camera_pivot.top_level = true
	else:
		camera.current = false
		if has_node("Visuals/CameraPivot/Camera3D/AudioListener3D"):
			get_node("Visuals/CameraPivot/Camera3D/AudioListener3D").current = false

	visuals.global_transform = global_transform
	visuals.top_level = true


func _enter_tree():
	_update_authority()


func _update_authority():
	var id = name.to_int()
	if id > 0:
		$MultiplayerSynchronizer.set_multiplayer_authority(id)
	is_local_player = is_multiplayer_authority()


func _process(delta):
	if not is_local_player:
		return

	# Smooth visual follow
	visuals.global_transform = visuals.global_transform.interpolate_with(global_transform, 15.0 * delta)

	# Camera follows vehicle
	var cam_dist = lerp(3.5, 6.0, clamp(boost_time / 4.0, 0.0, 1.0))
	var cam_offset = Vector3(0, 1.5, cam_dist)
	target_cam_pos = global_transform * cam_offset
	camera_pivot.global_position = camera_pivot.global_position.lerp(target_cam_pos, 12.0 * delta)
	camera_pivot.look_at(global_position, Vector3.UP)

	# Speedometer
	if race_ui:
		race_ui.update_speed(linear_velocity.length() * 1.8)

	# Procedural engine sound
	if engine_sound.stream is AudioStreamGenerator and engine_sound.playing:
		_fill_audio_buffer()


func _physics_process(delta):
	if is_teleporting:
		return

	# Audio buffer
	if engine_sound.stream is AudioStreamGenerator and playback:
		_fill_audio_buffer()

	# Reset if fallen too far
	if global_position.y < -50:
		respawn()

	# Explosion physics
	if is_exploding:
		apply_central_force(Vector3.UP * 5.0)
		apply_torque(Vector3(randf()-0.5, randf()-0.5, randf()-0.5) * 20.0)

		if sfx_fire_loop.playing:
			sfx_fire_loop.volume_db = lerp(sfx_fire_loop.volume_db, -10.0, 2.0 * delta)

		burning_particles.global_position = global_position + Vector3(0, 0.5, 0)
		burning_smoke_particles.global_position = global_position + Vector3(0, 0.5, 0)

		_move_and_sync()
		return

	# Water detection
	var currently_underwater = global_position.y < WATER_LEVEL
	if currently_underwater != is_underwater:
		if currently_underwater:
			sfx_landing_bonk.play()
			_apply_water_drag()
		is_underwater = currently_underwater
		water_timer = 0.0

	if is_underwater:
		water_timer += delta
		if water_timer > 2.0:
			explode()

	_apply_water_buoyancy(delta)

	if not can_move:
		brake = 1.0
		_apply_finish_deceleration(delta)
		_move_and_sync()
		return

	# Item usage
	if Input.is_action_just_pressed("boost"):
		_use_item()

	# Input
	var input_dir = Vector2.ZERO
	input_dir.x = Input.get_axis("steer_left", "steer_right")
	input_dir.y = Input.get_axis("throttle", "brake")

	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()

	# Apply input to vehicle
	_steer_input = -input_dir.x * STEER_SPEED

	# Acceleration / braking
	if input_dir.y < -0.1:
		# Throttle forward
		var force = ENGINE_FORCE
		if boost_timer > 0:
			force *= 2.0
			boost_timer -= delta
			is_boosting = true
			if not sfx_rocket_loop.playing:
				sfx_rocket_loop.play()
		else:
			is_boosting = false
			if sfx_rocket_loop.playing:
				sfx_rocket_loop.stop()

		engine_force = -force
		boost_time += delta

	elif input_dir.y > 0.1:
		# Brake or Reverse
		var forward_speed = -linear_velocity.dot(global_transform.basis.z)
		if forward_speed > 0.5:
			# Still moving forward: Brake
			engine_force = 0.0
			brake = BRAKE_FORCE * input_dir.y
		else:
			# Stopped or already moving back: Reverse
			brake = 0.0
			engine_force = ENGINE_FORCE * 0.5 * input_dir.y # Positive force for reverse in this setup
		
		boost_time = 0.0

		# Handbrake drift
		if abs(input_dir.x) > 0.5 and linear_velocity.length() > 10.0:
			brake = HANDBRAKE_FORCE
			if not sfx_brake_drift.playing:
				sfx_brake_drift.play()
			is_drifting = true
		else:
			if sfx_brake_drift.playing:
				sfx_brake_drift.stop()
			is_drifting = false
	else:
		# No input - coast
		engine_force = 0.0
		brake = 0.0
		boost_time = 0.0
		if sfx_rocket_loop.playing:
			sfx_rocket_loop.stop()
		if sfx_brake_drift.playing:
			sfx_brake_drift.stop()
		is_drifting = false

	# Wind sound
	var speed = linear_velocity.length()
	# Check if any wheel is on ground
	var on_ground = $WheelFL.is_in_contact() or $WheelFR.is_in_contact() or $WheelRL.is_in_contact() or $WheelRR.is_in_contact()
	if speed > 20.0 and on_ground:
		if not sfx_wind_loop.playing:
			sfx_wind_loop.play()
		sfx_wind_loop.volume_db = lerp(sfx_wind_loop.volume_db, -10.0, 2.0 * delta)
	else:
		sfx_wind_loop.volume_db = lerp(sfx_wind_loop.volume_db, -40.0, 5.0 * delta)
		if sfx_wind_loop.volume_db < -35.0:
			sfx_wind_loop.stop()

	# Update sync vars
	sync_steer = move_toward(sync_steer, _steer_input, 10.0 * delta)
	steering = sync_steer

	# Visual wheel rotation
	_update_wheel_visuals(delta)

	# Sync position for multiplayer
	_move_and_sync()


var target_cam_pos: Vector3
var _steer_input: float = 0.0
var _prev_flat_vel: Vector2 = Vector2.ZERO


func _fill_audio_buffer():
	if not playback:
		return

	var available = playback.get_frames_available()
	if available == 0:
		return

	var freq = 120.0 + abs(linear_velocity.dot(-global_transform.basis.z)) * 8.0
	if is_boosting:
		freq *= 1.5

	for i in range(available):
		var t = float(i) / sample_rate
		var sample = sin(t * freq * TAU) * 0.3
		sample += sin(t * freq * 2.0 * TAU) * 0.1
		playback.push_frame(Vector2(sample, sample))


func _update_wheel_visuals(delta):
	# Update average RPM for spinning
	var avg_rpm = ($WheelFL.get_rpm() + $WheelFR.get_rpm() + $WheelRL.get_rpm() + $WheelRR.get_rpm()) / 4.0
	wheel_rotation -= (avg_rpm / 60.0) * TAU * delta

	if not wheel_pivots.is_empty():
		# Steering visuals for front wheels
		if wheel_pivots.has("FL"): wheel_pivots["FL"].rotation.y = steering
		if wheel_pivots.has("FR"): wheel_pivots["FR"].rotation.y = steering
		
		# Rotation visuals for all wheels
		for key in wheel_pivots:
			wheel_pivots[key].rotation.x = wheel_rotation
	else:
		# Fallback to old pivots if they exist and are visible
		if $Visuals/WheelPivotFL.visible:
			$Visuals/WheelPivotFL.rotation.y = steering
			$Visuals/WheelPivotFR.rotation.y = steering
			$Visuals/WheelPivotFL/WheelFL.rotation.x = wheel_rotation
			$Visuals/WheelPivotFR/WheelFR.rotation.x = wheel_rotation
			$Visuals/WheelPivotRL/WheelRL.rotation.x = wheel_rotation
			$Visuals/WheelPivotRR/WheelRR.rotation.x = wheel_rotation


func _setup_new_car_wheels():
	var wheels_config = {
		"FL": "CartModel/part_5",
		"FR": "CartModel/part_2",
		"RL": "CartModel/part_6",
		"RR": "CartModel/part_0"
	}
	
	for key in wheels_config:
		var path = wheels_config[key]
		var node = get_node_or_null("Visuals/" + path)
		if node and node is MeshInstance3D:
			# Create a pivot at the wheel's geometric center
			var aabb = node.get_mesh().get_aabb()
			var center = aabb.get_center()
			
			var pivot = Node3D.new()
			pivot.name = "Pivot" + key
			node.get_parent().add_child(pivot)
			
			# Position pivot at the wheel center (relative to parent)
			pivot.transform = node.transform
			pivot.translate(center)
			
			# Reparent wheel to pivot and center it
			node.reparent(pivot, false)
			node.transform = Transform3D.IDENTITY
			node.translate(-center)
			
			wheel_pivots[key] = pivot


func _apply_water_drag():
	linear_velocity *= 0.5


func _apply_water_buoyancy(delta):
	if is_underwater:
		apply_central_force(Vector3.UP * 15.0)


func _apply_finish_deceleration(delta):
	linear_velocity = linear_velocity.lerp(Vector3.ZERO, 5.0 * delta)
	angular_velocity = angular_velocity.lerp(Vector3.ZERO, 3.0 * delta)


func _move_and_sync():
	sync_position = global_position
	sync_rotation = rotation
	sync_velocity = linear_velocity


func _use_item():
	if current_item == ItemType.NONE:
		return

	match current_item:
		ItemType.BOOST:
			boost_timer = 2.0
			sfx_nitro_start.play()
			boost_particles.emitting = true

	current_item = ItemType.NONE


func _on_body_entered(body):
	pass


func explode():
	if is_exploding:
		return
	print("PlayerCart: EXPLODING!")
	is_exploding = true
	can_move = false

	sfx_explosion.play()
	sfx_fire_loop.play()
	explosion_particles.emitting = true
	burning_particles.emitting = true
	burning_smoke_particles.emitting = true

	if engine_sound.playing:
		engine_sound.stop()

	linear_velocity += Vector3(randf()-0.5, 10.0, randf()-0.5).normalized() * 15.0

	respawn_timer = 0.0


func respawn():
	print("PlayerCart: RESPAWNING!")
	is_exploding = false

	var level = get_tree().get_first_node_in_group("level")
	var id = name.to_int()
	var finished = false
	if level and level.player_stats.has(id):
		finished = level.player_stats[id]["finished"]

	can_move = not finished
	is_boosting = false
	heat = 0.0
	boost_time = 0.0
	is_waiting_to_explode = false

	explosion_particles.emitting = false
	burning_particles.emitting = false
	burning_smoke_particles.emitting = false
	sfx_fire_loop.stop()

	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	var spawn_pos = last_checkpoint_transform.origin + (last_checkpoint_transform.basis.z * 5.0) + Vector3(0, 2.0, 0)
	global_position = spawn_pos

	var look_target = last_checkpoint_transform.origin
	look_target.y = spawn_pos.y
	look_at(look_target, Vector3.UP)

	if not engine_sound.playing:
		engine_sound.play()


func give_item(type: int):
	current_item = type
	if is_local_player and race_ui:
		var item_name = ItemType.keys()[type]
		race_ui.update_item(item_name)


func _get_random_item_rpc() -> int:
	# Randomly pick from available items (excluding NONE)
	var items = [ItemType.BOOST, ItemType.MISSILE, ItemType.SHIELD, ItemType.SHOCKWAVE, ItemType.BOMB]
	return items[randi() % items.size()]


var respawn_timer: float = 0.0