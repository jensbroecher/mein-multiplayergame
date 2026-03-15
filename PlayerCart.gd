extends CharacterBody3D

@export var player_name: String = "Player":
	set(value):
		player_name = value
		if is_inside_tree() and $NameTag:
			$NameTag.text = value

const SPEED = 15.0
const REVERSE_SPEED = 8.0
const STEER_SPEED = 2.5
const ACCELERATION = 10.0
const FRICTION = 5.0
const GRAVITY = 20.0

@onready var visuals = $Visuals
@onready var camera = $Visuals/CameraPivot/Camera3D
@onready var name_tag = $Visuals/NameTag
@onready var engine_sound = $Visuals/EngineSound

var is_local_player = false
var can_move = false

# Network sync targets
var sync_position: Vector3
var sync_rotation: Vector3

func on_race_started():
	if is_local_player:
		can_move = true

func _ready():
	add_to_group("player_carts")
	_update_authority()
	
	name_tag.text = player_name
	
	# Ensure engine sound loops and is playing
	if engine_sound.stream is AudioStreamMP3:
		engine_sound.stream.loop = true
	if not engine_sound.playing:
		engine_sound.play()
	
	if is_local_player:
		camera.current = true
	else:
		camera.current = false
	
	# Initial visual snap
	visuals.global_transform = global_transform

func _enter_tree():
	_update_authority()

func _update_authority():
	var id = name.to_int()
	$MultiplayerSynchronizer.set_multiplayer_authority(id)
	is_local_player = (id == multiplayer.get_unique_id())

func _process(delta):
	# SMOOTH VISUALS:
	# The physics body (CharacterBody3D) moves in chunks in _physics_process.
	# We smoothly lerp the 'Visuals' container to follow it in _process (rendered frames).
	var target_transform = global_transform
	
	# If we are remote, we are already lerping 'position/rotation' in physics_process 
	# (which is acceptable for remote players), but for local player this makes it buttery smooth.
	visuals.global_transform = visuals.global_transform.interpolate_with(target_transform, 25.0 * delta)
	
	# Modulate engine sound pitch based on speed
	# We use the current velocity (which is synced for remote players too)
	var speed = velocity.length()
	# Base pitch 1.0 at idle, increases with speed. max 2.5
	var target_pitch = 1.0 + (speed / SPEED) * 1.5
	var target_volume = 1.0 + (speed / SPEED) * 2.0
	
	# AUDIO SMOOTHING: Use lerp to prevent DJ-scratching artifacts from jittery network updates
	engine_sound.pitch_scale = lerp(engine_sound.pitch_scale, target_pitch, 10.0 * delta)
	# Increased unit_size baseline to 10.0 so host/solo can hear it (1.0 was too quiet)
	engine_sound.unit_size = lerp(engine_sound.unit_size, 10.0 + (speed / SPEED) * 20.0, 10.0 * delta)

func _physics_process(delta):
	# Handle movement for non-local players via interpolation
	if not is_local_player:
		var prev_pos = position
		# Interpolate smoothly towards the network synced transforms
		position = position.lerp(sync_position, 15.0 * delta)
		rotation.y = lerp_angle(rotation.y, sync_rotation.y, 15.0 * delta)
		rotation.x = lerp_angle(rotation.x, sync_rotation.x, 15.0 * delta)
		rotation.z = lerp_angle(rotation.z, sync_rotation.z, 15.0 * delta)
		
		# Calculate a "visual velocity" so the engine sound still works on remote clients
		# This prevents gravity from accumulating in velocity.y indefinitely
		velocity = (position - prev_pos) / delta
		
		sync_position = position
		sync_rotation = rotation
		return

	# Gravity - Only for local player (remote players follow synced position)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Only local player processes physics input from here down
	if not can_move:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0, FRICTION * delta)
		move_and_slide()
		
		sync_position = position
		sync_rotation = rotation
		return

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# Add WASD support
	if Input.is_key_pressed(KEY_W): input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S): input_dir.y += 1.0
	if Input.is_key_pressed(KEY_A): input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D): input_dir.x += 1.0
	input_dir = input_dir.normalized()
	
	# Steering - Lowered threshold to 0.1 to prevent stutter at low speeds
	if input_dir.x != 0 and velocity.length() > 0.1:
		var steer_dir = -1.0 if velocity.dot(transform.basis.z) > 0 else 1.0
		var steer_amount = input_dir.x * STEER_SPEED * delta * steer_dir
		rotate_y(-steer_amount)
		# MOMENTUM ALIGNMENT: Rotate velocity vector so it stays aligned with the car's orientation
		# This prevents the "sideways skid" feel when turning while coasting
		velocity = velocity.rotated(Vector3.UP, -steer_amount)

	# Acceleration / Braking
	var forward_dir = - transform.basis.z
	var target_speed = 0.0
	
	if input_dir.y < 0: # Forward
		target_speed = SPEED
	elif input_dir.y > 0: # Backward
		target_speed = - REVERSE_SPEED
		
	if target_speed != 0:
		velocity.x = move_toward(velocity.x, forward_dir.x * target_speed, ACCELERATION * delta)
		velocity.z = move_toward(velocity.z, forward_dir.z * target_speed, ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0, FRICTION * delta)

	move_and_slide()
	
	sync_position = position
	sync_rotation = rotation
