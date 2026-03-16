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
@onready var camera_pivot = $Visuals/CameraPivot
@onready var camera = $Visuals/CameraPivot/Camera3D
@onready var name_tag = $Visuals/NameTag
@onready var engine_sound = $Visuals/EngineSound
@onready var wheel_fl = $Visuals/WheelPivotFL
@onready var wheel_fr = $Visuals/WheelPivotFR
@onready var wheel_rl = $Visuals/WheelPivotRL
@onready var wheel_rr = $Visuals/WheelPivotRR
@onready var ground_ray = $GroundRay

var playback: AudioStreamGeneratorPlayback
var sample_rate: float
var phase: float = 0.0
var phase2: float = 0.0
var phase3: float = 0.0
var time_accum: float = 0.0
var current_base_freq: float = 30.0
var wheel_rotation: float = 0.0
var visual_steer: float = 0.0

# Procedural Animation States
var was_on_floor: bool = true
var bounce_y: float = 0.0
var bounce_vel: float = 0.0

var is_local_player = false
var can_move = false

# Network sync targets
var sync_position: Vector3
var sync_rotation: Vector3
var sync_velocity: Vector3
var sync_steer: float # For wheel steering visuals

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
		camera_pivot.top_level = true
		camera_pivot.global_transform = global_transform * camera_pivot.transform
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
	
	# Use ground ray normal for more robust alignment, falling back to on_floor normal
	if ground_ray.is_colliding():
		up = ground_ray.get_collision_normal()
	elif is_on_floor():
		up = get_floor_normal()
	
	# Use looking_at for robust orientation (fixes mirrored controls)
	target_basis = Basis.looking_at(forward, up)
	
	# DYNAMIC LEANING:
	# Speed-dependent factor: No leaning at low speeds (zero below 2.0, max at 15.0+)
	var speed_lean_factor = clamp((velocity.length() - 2.0) / 13.0, 0.0, 1.0)
	
	# 1. Softened side-lean into turns, now speed-dependent
	var turn_lean = -sync_steer * 0.08 * speed_lean_factor
	# 2. Pitch-lean reinforcement: rotate slightly more based on slope steepness
	# We want the nose to tilt UP when climbing (positive slope)
	var slope_intensity = forward.dot(up)
	var pitch_lean = -slope_intensity * 0.5
	
	target_basis = target_basis.rotated(target_basis.z.normalized(), turn_lean)
	target_basis = target_basis.rotated(target_basis.x.normalized(), pitch_lean)
	
	# GROUNDING: Adjust target position to actual ground height on levels/ramps
	var target_pos = global_position
	if is_on_floor() and ground_ray.is_colliding():
		target_pos.y = ground_ray.get_collision_point().y
	
	# BOUNCE EFFECT: Decimate and apply
	bounce_vel -= bounce_y * 110.0 * delta # Spring
	bounce_vel *= 0.9 # Damping
	bounce_y += bounce_vel * delta
	target_pos.y += bounce_y
	
	var target_transform = Transform3D(target_basis, target_pos)
	
	# Buttery smooth lerp for both position and rotation (leaning)
	visuals.global_transform = visuals.global_transform.interpolate_with(target_transform, 18.0 * delta)
	
	# WHEEL SUSPENSION ANIMATION (Smoothed):
	# Wheels move up/down relative to their pivot to simulate suspension
	# Reduced intensity to 20% of previous value for sublte realism
	# Added speed_lean_factor so wheels don't compress when standing still
	var susp_intensity = sync_steer * 0.08 * 0.2 * speed_lean_factor
	var susp_pitch = pitch_lean * 0.1 * 0.2
	
	var target_fl = 0.228309 + susp_intensity - susp_pitch
	var target_fr = 0.228309 - susp_intensity - susp_pitch
	var target_rl = 0.228309 + susp_intensity + susp_pitch
	var target_rr = 0.228309 - susp_intensity + susp_pitch
	
	# Smoothing speed (~10.0 for fluid but responsive feel)
	var s_speed = 10.0 * delta
	wheel_fl.position.y = lerp(wheel_fl.position.y, target_fl, s_speed)
	wheel_fr.position.y = lerp(wheel_fr.position.y, target_fr, s_speed)
	wheel_rl.position.y = lerp(wheel_rl.position.y, target_rl, s_speed)
	wheel_rr.position.y = lerp(wheel_rr.position.y, target_rr, s_speed)
	
	# DYNAMIC CAMERA FOLLOW:
	if is_local_player:
		# Define target position in global space based on visuals
		# (We use the visuals transform to get a stable but responsive target)
		var cam_offset = Vector3(0, 1.5, 4.0)
		var target_cam_pos = visuals.global_transform * cam_offset
		
		# Define target orientation
		var target_cam_basis = visuals.global_transform.basis
		
		# CURVE LEANING: Tilt the camera slightly based on steering
		var cam_lean = sync_steer * 0.08
		target_cam_basis = target_cam_basis.rotated(target_cam_basis.z.normalized(), cam_lean)
		
		# SMOOTHING: 
		# Position follows relatively fast (12.0)
		# Rotation follows slower (6.0) to create that "lag" feel in corners
		camera_pivot.global_position = camera_pivot.global_position.lerp(target_cam_pos, 12.0 * delta)
		camera_pivot.global_basis = camera_pivot.global_basis.slerp(target_cam_basis, 6.0 * delta)
	
	# Keep visuals pinned if they drift too far (emergency snap)
	if visuals.global_position.distance_to(global_position) > 10.0:
		visuals.global_position = global_position
	
	# WHEEL ANIMATION:
	var wheel_speed = velocity.length()
	# Estimate wheel circumference for realistic spin (approx 2.0 factor)
	wheel_rotation -= wheel_speed * delta * 4.0 
	
	# Smooth out steering visuals (lerp towards sync_steer)
	visual_steer = lerp(visual_steer, sync_steer, 8.0 * delta)
	var steer_angle = visual_steer * 0.4 # Max ~23 degrees
	
	# Rotate all wheels for rolling
	for wheel in [wheel_fl, wheel_fr, wheel_rl, wheel_rr]:
		if wheel:
			wheel.rotation.x = wheel_rotation
			
	# Steer front wheels
	if wheel_fl: wheel_fl.rotation.y = steer_angle
	if wheel_fr: wheel_fr.rotation.y = steer_angle
	
	# PROCEDURAL AUDIO SYNTHESIS:
	if playback:
		_fill_audio_buffer()
	
	# Ensure sound is playing (especially important if it was paused or failed to start)
	if not engine_sound.playing:
		engine_sound.play()
	
	# Modulate engine sound pitch based on speed
	var speed = velocity.length()
	# Base volume calculation for HUD/Audio
	# Base volume calculation for HUD/Audio
	var target_vol_linear = 0.5 + (speed / SPEED) * 1.0
	
	# Apply overall volume (DB)
	var target_db = linear_to_db(target_vol_linear)
	engine_sound.volume_db = lerp(engine_sound.volume_db, target_db, 10.0 * delta)
	
	# Reduced unit_size baseline to make it less overwhelming at distance
	engine_sound.unit_size = lerp(engine_sound.unit_size, 10.0 + (speed / SPEED) * 20.0, 10.0 * delta)

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
	
	# LANDING BOUNCE DETECTION
	if is_on_floor() and not was_on_floor:
		bounce_vel = -velocity.y * 0.02 # Convert downward momentum to bounce
	was_on_floor = is_on_floor()
	
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

	# Acceleration / Braking (ARCADE GRIP)
	var forward_dir = -transform.basis.z
	var current_velocity_y = velocity.y # Preserve gravity
	
	# Project current horizontal velocity onto the forward direction to get signed speed
	var current_forward_speed = Vector2(velocity.x, velocity.z).dot(Vector2(forward_dir.x, forward_dir.z).normalized())
	
	var target_speed = 0.0
	if input_dir.y < 0: # Forward
		target_speed = SPEED
	elif input_dir.y > 0: # Backward
		target_speed = -REVERSE_SPEED
		
	# Apply acceleration/friction to the scalar forward speed
	if target_speed != 0:
		current_forward_speed = move_toward(current_forward_speed, target_speed, ACCELERATION * delta)
	else:
		current_forward_speed = move_toward(current_forward_speed, 0, FRICTION * delta)
		
	# Reconstruct velocity: Keep it strictly in the forward heading
	velocity.x = forward_dir.x * current_forward_speed
	velocity.z = forward_dir.z * current_forward_speed
	velocity.y = current_velocity_y

	move_and_slide()
	
	sync_position = position
	sync_rotation = rotation
	sync_velocity = velocity
	
	# Progressive Steering: Accumulate steer building over time (0.0 to 1.0)
	var target_steer = -input_dir.x if can_move else 0.0
	sync_steer = move_toward(sync_steer, target_steer, 2.5 * delta)
