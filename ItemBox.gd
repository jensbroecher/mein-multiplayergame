extends Node3D

@onready var area = $Area3D
@onready var visuals = $Visuals
@onready var sfx_pickup = $SFX_Pickup

var is_active = true
var respawn_timer = 0.0
const RESPAWN_TIME = 5.0

func _ready():
	area.body_entered.connect(_on_body_entered)
	if sfx_pickup:
		sfx_pickup.bus = &"SFX"

func _process(delta):
	# Animation for everyone
	visuals.rotate_y(delta * 2.0)
	visuals.position.y = 0.5 + sin(Time.get_ticks_msec() * 0.003) * 0.2
	
	if not multiplayer.is_server(): return
	
	if not is_active:
		respawn_timer -= delta
		if respawn_timer <= 0:
			_activate_rpc.rpc()

func _on_body_entered(body):
	if not multiplayer.is_server(): return
	if not is_active: return
	
	if body.is_in_group("player_carts"):
		if body.has_method("give_item"):
			# Only give item if player doesn't have one
			if body.current_item == body.ItemType.NONE:
				body.give_item(body._get_random_item_rpc()) # Kart decides which item locally or via RPC
				_deactivate_rpc.rpc()

@rpc("authority", "call_local", "reliable")
func _deactivate_rpc():
	is_active = false
	visuals.visible = false
	if multiplayer.is_server():
		respawn_timer = RESPAWN_TIME
	if sfx_pickup: sfx_pickup.play()

@rpc("authority", "call_local", "reliable")
func _activate_rpc():
	is_active = true
	visuals.visible = true
	# area.set_deferred("monitoring", true)
