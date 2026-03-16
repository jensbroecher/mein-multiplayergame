extends CharacterBody3D

@export var player_name: String = "Player":
	set(value):
		player_name = value
		if is_inside_tree() and $NameTag:
			$NameTag.text = value

const SPEED = 22.0
const REVERSE_SPEED = 10.0
const STEER_SPEED = 2.5
const ACCELERATION = 12.0
const FRICTION = 5.0
const GRAVITY = 25.0

@onready var visuals = $Visuals
@onready var camera = $Visuals/CameraPivot/Camera3D
@onready var name_tag = $Visuals/NameTag
@onready var engine_sound = $Visuals/EngineSound

var playback: AudioStreamGeneratorPlayback
var sample_rate: float
var phase: float = 0.0
var phase2: float = 0.0
var phase3: float = 0.0
var time_accum: float = 0.0
var current_base_freq: float = 30.0

var is_local_player = false
var can_move = false

# Network sync targets
var sync_position: Vector3
var sync_rotation: Vector3
var sync_velocity: Vector3

func on_race_started():
	if is_local_player:
		can_move = true

func _ready():
	add_to_group("player_carts")
	_update_authority()
	
	name_tag.text = player_name
	
	# Initialize procedural engine sound
	if engine_sound.stream is AudioStreamGenerator:
		sample_rate = engine_sound.stream.mix_rate
		playback = engine_sound.get_stream_playback()
		if not engine_sound.playing:
			engine_sound.play()
		print("PlayerCart: Procedural engine sound initialized.")
	
	if is_local_player:
		camera.current = true
		if has_node("Visuals/CameraPivot/Camera3D/AudioListener3D"):
			get_node("Visuals/CameraPivot/Camera3D/AudioListener3D").make_current()
	else:
		camera.current = false
		if has_node("Visuals/CameraPivot/Camera3D/AudioListener3D"):
			get_node("Visuals/CameraPivot/Camera3D/AudioListener3D").current = false
	
	# Initial visual snap
	visuals.global_transform = global_transform
	# Always top_level to ensure smooth, independent visual-only rotation/leaning
	visuals.top_level = true

func _enter_tree():
	_update_authority()

func _update_authority():
	var id = name.to_int()
	$MultiplayerSynchronizer.set_multiplayer_authority(id)
	is_local_player = (id == multiplayer.get_unique_id())

func _process(delta):
	# SMOOTH VISUALS:
	# We smoothly lerp the 'Visuals' container to follow the physics body.
	# We also align its orientation to the ground normal for leaning.
	var target_basis = Basis.IDENTITY
	var forward = -global_transform.basis.z
	var up = Vector3.UP
	
	if is_on_floor():
		up = get_floor_normal()
	
	# Fix for mirrored controls: Use looking_at to correctly align visuals
	# to the floor normal while facing the movement direction (-Z is forward).
	target_basis = Basis.looking_at(forward, up)
	
	var target_transform = Transform3D(target_basis, global_position)
	
	# Buttery smooth lerp for both position and rotation (leaning)
	visuals.global_transform = visuals.global_transform.interpolate_with(target_transform, 15.0 * delta)
	
	# Keep visuals pinned if they drift too far (emergency snap)
	if visuals.global_position.distance_to(global_position) > 10.0:
		visuals.global_position = global_position
	
	# PROCEDURAL AUDIO SYNTHESIS:
	if playback:
		_fill_audio_buffer()
	
	# Ensure sound is playing (especially important if it was paused or failed to start)
	if not engine_sound.playing:
		engine_sound.play()
	
	# Modulate engine sound pitch based on speed
	var speed = velocity.length()
	# Base volume calculation for HUD/Audio
	var target_vol_linear = 1.5 + (speed / SPEED) * 2.0
	
	# Apply overall volume (DB)
	var target_db = linear_to_db(target_vol_linear)
	engine_sound.volume_db = lerp(engine_sound.volume_db, target_db, 10.0 * delta)
	
	# Increased unit_size baseline significantly to ensure it's heard across the scene
	engine_sound.unit_size = lerp(engine_sound.unit_size, 20.0 + (speed / SPEED) * 30.0, 10.0 * delta)

func _fill_audio_buffer():
	var speed = velocity.length()
	# Target RPM frequency: 30Hz at idle, up to 100Hz at full speed
	var target_freq = 30.0 + (speed / SPEED) * 70.0
	
	# Smoothly interpolate the frequency to prevent clicks from sudden speed changes
	current_base_freq = lerp(current_base_freq, target_freq, 0.2)
	
	# VARIETY: Add a subtle fluctuation to the frequency at higher speeds
	# This creates a more "organic" engine sound that isn't perfectly static
	var high_speed_variety = 0.0
	if speed > SPEED * 0.7:
		time_accum += 1.0 / sample_rate
		high_speed_variety = sin(time_accum * 4.0) * 2.0
	
	var base_freq = current_base_freq + high_speed_variety
	var frames_available = playback.get_frames_available()
	
	for i in range(frames_available):
		# PHASE ACCUMULATION: 
		# We increment phases individually per harmonic to ensure smooth transitions
		phase += base_freq / sample_rate
		phase2 += (base_freq * 0.5) / sample_rate
		phase3 += (base_freq * 1.5) / sample_rate
		
		# Wrap phases to keep precision
		phase = fmod(phase, 1.0)
		phase2 = fmod(phase2, 1.0)
		phase3 = fmod(phase3, 1.0)
		
		var pulse = 0.0
		# Main explosion pulse
		if phase < 0.12: pulse = 1.0
		# Sub-harmonic rumble
		if phase2 < 0.06: pulse += 0.4
		# Mid-harmonic for fullness
		if phase3 < 0.04: pulse += 0.2
			
		# Very low noise floor for mechanical finish
		var noise = (randf() * 2.0 - 1.0) * 0.03
		
		var sample = (pulse + noise) * 0.4
		sample = clamp(sample, -1.0, 1.0)
		
		playback.push_frame(Vector2(sample, sample))

func _physics_process(delta):
	# Handle movement for non-local players via interpolation
	if not is_local_player:
		var prev_pos = position
		
		# SPAWN SNAPPING: Prevent flying in from origin when joining
		if position.distance_squared_to(sync_position) > 25.0: # > 5 units away
			position = sync_position
			rotation = sync_rotation
			velocity = Vector3.ZERO
		else:
			# DEAD RECKONING: Extrapolate the sync position based on the last known velocity
			# This keeps the cart moving even if we haven't received a new packet yet
			sync_position += sync_velocity * delta
			
			# Interpolate smoothly towards the extrapolated network transform
			position = position.lerp(sync_position, 15.0 * delta)
			rotation.y = lerp_angle(rotation.y, sync_rotation.y, 15.0 * delta)
			rotation.x = lerp_angle(rotation.x, sync_rotation.x, 15.0 * delta)
			rotation.z = lerp_angle(rotation.z, sync_rotation.z, 15.0 * delta)
			
			# Calculate a "visual velocity" so the engine sound still works on remote clients
			# We use the actual movement from this frame
			velocity = (position - prev_pos) / delta
			
			# SPEED CLAMPING: Prevent network catch-up spikes from causing extreme engine pitches
			# Limit remote visual speed slightly above max normal speed
			var max_visual_speed = SPEED * 1.2
			if velocity.length() > max_visual_speed:
				velocity = velocity.normalized() * max_visual_speed
		
		# Removed manual sync_position override to allow clean dead reckoning extrapolation
		return

	# Gravity and Terrain Alignment - Reverted physics rotation to fix jitter
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Only local player processes physics input from here down
	if not can_move:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0, FRICTION * delta)
		move_and_slide()
		
		sync_position = position
		sync_rotation = rotation
		sync_velocity = velocity
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
	sync_velocity = velocity
