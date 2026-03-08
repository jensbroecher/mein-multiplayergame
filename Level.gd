extends Node3D

const PLAYER_CART = preload("res://PlayerCart.tscn")

@onready var spawn_points = $SpawnPoints.get_children()
@onready var players_container = $Players

func _ready():
	if multiplayer.is_server():
		NetworkManager.player_connected.connect(_on_player_connected)
		NetworkManager.player_disconnected.connect(_on_player_disconnected)
		
		# Spawn existing players (host first)
		for id in NetworkManager.players:
			var info = NetworkManager.players[id]
			_add_player(id, info["name"])
			
func _on_player_connected(id: int, info: Dictionary):
	if multiplayer.is_server():
		_add_player(id, info["name"])

func _on_player_disconnected(id: int):
	if multiplayer.is_server():
		var p = players_container.get_node_or_null(str(id))
		if p:
			p.queue_free()

func _add_player(id: int, p_name: String):
	var cart = PLAYER_CART.instantiate()
	cart.name = str(id) # Name must be string of network ID for syncing
	
	# Pass the player name to the cart
	cart.player_name = p_name
	
	# Decide spawn point
	var idx = players_container.get_child_count() % spawn_points.size()
	cart.global_transform = spawn_points[idx].global_transform
	
	players_container.add_child(cart)
