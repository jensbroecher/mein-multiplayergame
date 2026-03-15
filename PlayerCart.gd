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

@onready var camera = $CameraPivot/Camera3D
@onready var name_tag = $NameTag

var is_local_player = false
var can_move = false

func on_race_started():
	if is_local_player:
		can_move = true

func _ready():
	add_to_group("player_carts")
	_update_authority()
	
	name_tag.text = player_name
	
	if is_local_player:
		camera.current = true
		
		# Now that we're spawned, if we are the new client spawning our cart locally, 
		# we need to tell NetworkManager to register us so others know our name.
		# But name is synced via MultiplayerSynchronizer (spawn=true), so it should arrive automatically.
	else:
		camera.current = false

func _enter_tree():
	_update_authority()

func _update_authority():
	var id = name.to_int()
	$MultiplayerSynchronizer.set_multiplayer_authority(id)
	is_local_player = (id == multiplayer.get_unique_id())

func _physics_process(delta):
	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Only the local player controls this cart
	if not is_local_player:
		return

	if not can_move:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0, FRICTION * delta)
		move_and_slide()
		return

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# Steering
	if input_dir.x != 0 and velocity.length() > 0.5:
		var steer_dir = -1.0 if velocity.dot(transform.basis.z) > 0 else 1.0
		# Reverse steering direction if going backwards
		var steer_amount = input_dir.x * STEER_SPEED * delta * steer_dir
		rotate_y(-steer_amount)

	# Acceleration / Braking
	var forward_dir = - transform.basis.z
	var target_speed = 0.0
	
	if input_dir.y < 0: # Forward (ui_up is -1)
		target_speed = SPEED
	elif input_dir.y > 0: # Backward (ui_down is 1)
		target_speed = - REVERSE_SPEED
		
	if target_speed != 0:
		# Accelerate
		velocity.x = move_toward(velocity.x, forward_dir.x * target_speed, ACCELERATION * delta)
		velocity.z = move_toward(velocity.z, forward_dir.z * target_speed, ACCELERATION * delta)
	else:
		# Friction
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0, FRICTION * delta)

	move_and_slide()
