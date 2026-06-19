extends Node3D

@onready var area = $Area3D
@onready var visuals = $Visuals
@onready var sfx_pickup = $SFX_Pickup

var is_active = true
var respawn_timer = 0.0
const RESPAWN_TIME = 5.0
var current_scale: float = 0.0

const SFX_PICKUP_SOUND = preload("res://sounds/game_bonus_collected_#3-1781737105214.wav")

func _ready():
	area.body_entered.connect(_on_body_entered)
	if sfx_pickup:
		sfx_pickup.bus = &"SFX"
		sfx_pickup.stream = SFX_PICKUP_SOUND
	visuals.scale = Vector3.ZERO
	current_scale = 0.0

func _process(delta):
	# Animation for everyone
	visuals.rotate_y(delta * 2.0)
	visuals.position.y = 0.5 + sin(Time.get_ticks_msec() * 0.003) * 0.2
	
	# Scale animation
	if is_active:
		if current_scale < 1.0:
			current_scale = move_toward(current_scale, 1.0, delta * 3.0)
			visuals.scale = Vector3.ONE * current_scale
	else:
		if current_scale > 0.0:
			current_scale = move_toward(current_scale, 0.0, delta * 8.0)
			visuals.scale = Vector3.ONE * current_scale
			if current_scale == 0.0:
				visuals.visible = false
				
	if not multiplayer.is_server(): return
	
	if not is_active:
		respawn_timer -= delta
		if respawn_timer <= 0:
			_activate_rpc.rpc()

func _on_body_entered(body):
	if not is_active: return
	
	if body.is_in_group("player_carts"):
		var is_colliding_racer = body.is_local_player or (body.get("is_ai") and multiplayer.is_server())
		if is_colliding_racer:
			if body.has_method("give_item_rpc"):
				if multiplayer.is_server():
					_server_process_pickup(body)
				else:
					request_pickup.rpc_id(1, body.name.to_int())

@rpc("any_peer", "call_local", "reliable")
func request_pickup(player_id: int):
	if not multiplayer.is_server(): return
	if not is_active: return
	
	var body = null
	for cart in get_tree().get_nodes_in_group("player_carts"):
		if cart.name == str(player_id):
			body = cart
			break
			
	if body and body.has_method("give_item_rpc"):
		_server_process_pickup(body)

func _server_process_pickup(body):
	if body.has_method("give_item_rpc"):
		var item_type = body._get_random_item_rpc()
		if body.get("is_ai"):
			body.give_item(item_type)
		else:
			body.give_item_rpc.rpc_id(body.name.to_int(), item_type)
		_deactivate_rpc.rpc()

@rpc("authority", "call_local", "reliable")
func _deactivate_rpc():
	is_active = false
	if multiplayer.is_server():
		respawn_timer = RESPAWN_TIME
	if sfx_pickup: sfx_pickup.play()

@rpc("authority", "call_local", "reliable")
func _activate_rpc():
	is_active = true
	visuals.visible = true
	current_scale = 0.0
	visuals.scale = Vector3.ZERO
