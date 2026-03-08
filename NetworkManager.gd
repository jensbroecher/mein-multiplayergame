extends Node

const DEFAULT_PORT = 10567
const MAX_CLIENTS = 4

var peer: ENetMultiplayerPeer

signal player_connected(id: int, info: Dictionary)
signal player_disconnected(id: int)
signal server_disconnected

# We can store player info like names here
# format: { id: { "name": "PlayerName" } }
var players = {}

func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	# To make sure this script keeps running in background even during scene load
	process_mode = Node.PROCESS_MODE_ALWAYS

func create_server(player_name: String):
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(DEFAULT_PORT, MAX_CLIENTS)
	if error != OK:
		printerr("NetworkManager: Failed to create server! Error code: ", error)
		return error
	
	multiplayer.multiplayer_peer = peer
	players[1] = {"name": player_name}
	
	# Broadcast ourselves on LAN
	LANDiscovery.start_broadcasting(player_name, DEFAULT_PORT)
	
	print("NetworkManager: Server created on port ", DEFAULT_PORT)
	return OK

var local_player_name = ""

func join_server(ip: String, port: int, player_name: String):
	local_player_name = player_name
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip, port)
	if error != OK:
		printerr("NetworkManager: Failed to create client! Error code: ", error)
		return error
	
	multiplayer.multiplayer_peer = peer
	LANDiscovery.stop_all() # No longer need to discover
	
	# We will register once we are actually connected to peer 1
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	
	print("NetworkManager: Connecting to ", ip, ":", port)
	return OK

func _on_connected_to_server():
	print("NetworkManager: Connected to server!")
	register_player.rpc_id(1, {"name": local_player_name})

func disconnect_peer():
	if peer:
		peer.close()
	multiplayer.multiplayer_peer = null
	players.clear()
	LANDiscovery.stop_all()

func _on_player_connected(id: int):
	print("NetworkManager: Player connected ", id)

func _on_player_disconnected(id: int):
	print("NetworkManager: Player disconnected ", id)
	if players.has(id):
		players.erase(id)
	player_disconnected.emit(id)

func _on_server_disconnected():
	print("NetworkManager: Server disconnected")
	players.clear()
	server_disconnected.emit()

# RPC to register a new player
@rpc("any_peer", "call_local", "reliable")
func register_player(info: Dictionary):
	var id = multiplayer.get_remote_sender_id()
	players[id] = info
	player_connected.emit(id, info)
	print("NetworkManager: Player registered ", id, ", info: ", info)
