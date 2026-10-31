extends Node


const DEFAULT_PORT = 10567
## Six carts per race (the level grids have six slots): the host plus five clients.
const MAX_PLAYERS = 6
const MAX_CLIENTS = MAX_PLAYERS - 1

var peer: ENetMultiplayerPeer

signal player_connected(id: int, info: Dictionary)
signal player_disconnected(id: int)
signal server_disconnected
signal player_ready_changed(id: int, is_ready: bool)
signal player_car_changed(id: int, car_index: int)
signal max_laps_changed(laps: int)
signal multiplayer_mode_changed(mode: int, cup_name: String)
signal stage_votes_updated(votes: Dictionary)
signal stage_voting_started()
signal stage_voting_concluded(winning_stage: String)

# Fixed to 3 laps always
const max_laps: int = 3

const CarPaint = preload("res://CarPaint.gd")

# format: { id: { "name": "PlayerName", "car_index": 0, "paint": {...}, "ready": false } }
# "paint" is the player's paint job for their car (CarPaint.gd), empty for the factory paint.
var players = {}
var local_car_index: int = 0
var local_p2_car_index: int = 0
var local_paint: Dictionary = {}
var local_p2_paint: Dictionary = {}
var local_p2_name: String = "Player 2"
var is_coop_gp: bool = false

enum GameMode { MULTIPLAYER, SINGLE_PLAYER_GP, SINGLE_PLAYER_TIME_TRIAL, LOCAL_COOP, SPECTATOR }
var current_game_mode: int = GameMode.MULTIPLAYER

enum MultiplayerMode { SINGLE_STAGES, GRAND_PRIX }
var multiplayer_mode: int = MultiplayerMode.SINGLE_STAGES
var selected_mp_cup: String = "Bloombay GP"
var current_single_stage: String = "res://levels/LakesideLevel.tscn"

var current_gp_name: String = ""
var current_gp_stage: int = 0
## Whether the Grand Prix under way started from its first stage, so its podium earns a trophy
## (Trophies.gd). The menu's GP TEST jumps in at any stage and clears it.
var gp_trophy_eligible: bool = true
var gp_standings: Dictionary = {} # racer_name -> points
var gp_last_pos: Dictionary = {} # racer_name -> finishing place in the latest race (breaks ties on points)
var time_trial_stage: String = "res://levels/LakesideLevel.tscn"

var stage_votes: Dictionary = {} # peer_id -> stage_path or "random"
var is_voting_active: bool = false

const ALL_STAGES = [
	{"name": "Meadow Circuit", "path": "res://levels/LakesideLevel.tscn"},
	{"name": "Pinecrest Ridge", "path": "res://levels/PinecrestRidgeLevel.tscn"},
	{"name": "Frostpeak Creek", "path": "res://levels/FrostpeakCreekLevel.tscn"},
	{"name": "Glacier Highway", "path": "res://levels/GlacierHighwayLevel.tscn"},
	{"name": "Northlight Caverns", "path": "res://levels/NorthlightCavernsLevel.tscn"},
	{"name": "Frostfall Gorge", "path": "res://levels/FrostfallGorgeLevel.tscn"},
	{"name": "Harbor Pier", "path": "res://levels/HarborPierLevel.tscn"},
	{"name": "Mountain Pass", "path": "res://levels/MountainLevel.tscn"},
	{"name": "Arco del Viento", "path": "res://levels/CanyonLevel.tscn"},
	{"name": "Tolvanera Gulch", "path": "res://levels/CanyonChasmLevel.tscn"},
	{"name": "Desert Wadi", "path": "res://levels/DesertWadiLevel.tscn"},
	{"name": "South Beach", "path": "res://levels/BloombayDunesLevel.tscn"},
	{"name": "Mara Crossing", "path": "res://levels/MaraCrossingLevel.tscn"},
	{"name": "Nyota Stadium", "path": "res://levels/NyotaStadiumLevel.tscn"},
	{"name": "Msitu Falls", "path": "res://levels/MsituFallsLevel.tscn"},
	{"name": "Mtaa Nights", "path": "res://levels/MtaaNightsLevel.tscn"},
]

const GP_CUPS = {
	"Bloombay GP": {
		"name": "Bloombay GP",
		"stages": [
			"res://levels/LakesideLevel.tscn",
			"res://levels/PinecrestRidgeLevel.tscn",
			"res://levels/HarborPierLevel.tscn",
			"res://levels/BloombayDunesLevel.tscn",
		]
	},
	"Svartfjell GP": {
		"name": "Svartfjell GP",
		"stages": [
			"res://levels/FrostpeakCreekLevel.tscn",
			"res://levels/GlacierHighwayLevel.tscn",
			"res://levels/NorthlightCavernsLevel.tscn",
			"res://levels/FrostfallGorgeLevel.tscn",
		]
	},
	"Al-Raihana GP": {
		"name": "Al-Raihana GP",
		"stages": [
			"res://levels/MountainLevel.tscn",
			"res://levels/DesertWadiLevel.tscn",
		]
	},
	"Sierra del Viento GP": {
		"name": "Sierra del Viento GP",
		"stages": [
			"res://levels/CanyonLevel.tscn",
			"res://levels/CanyonChasmLevel.tscn",
		]
	},
	"Matumaini GP": {
		"name": "Matumaini GP",
		"stages": [
			"res://levels/MaraCrossingLevel.tscn",
			"res://levels/NyotaStadiumLevel.tscn",
			"res://levels/MsituFallsLevel.tscn",
			"res://levels/MtaaNightsLevel.tscn",
		]
	}
}

## The final order of the Grand Prix, best first: points, then the latest race's finishing place. Each
## entry has what the podium needs to stand the car up (name, points, car_index, paint, is_bot).
func build_gp_ranking() -> Array:
	var rows: Array = []
	for racer_name in gp_standings:
		var info: Dictionary = {}
		for id in players:
			if str(players[id].get("name", "")) == racer_name:
				info = players[id]
				break
		rows.append({
			"name": racer_name,
			"points": int(gp_standings[racer_name]),
			"car_index": int(info.get("car_index", 0)),
			"paint": info.get("paint", {}),
			"is_bot": bool(info.get("is_ai", false)),
		})
	rows.sort_custom(func(a, b):
		if a["points"] != b["points"]:
			return a["points"] > b["points"]
		var pa: int = int(gp_last_pos.get(a["name"], 99))
		var pb: int = int(gp_last_pos.get(b["name"], 99))
		if pa != pb:
			return pa < pb
		return str(a["name"]) < str(b["name"]))
	return rows


## Host only: everyone, the host included, goes to the podium. Main.show_gp_podium unloads the race.
func announce_gp_podium() -> void:
	var cup_name: String = current_gp_name if not current_gp_name.is_empty() else selected_mp_cup
	gp_show_podium.rpc(cup_name, build_gp_ranking())


@rpc("authority", "call_local", "reliable")
func gp_show_podium(cup_name: String, ranking: Array) -> void:
	var main := get_tree().current_scene
	if main and main.has_method("show_gp_podium"):
		main.show_gp_podium(cup_name, ranking)


static func get_gp_cup(cup_name: String) -> Dictionary:
	if GP_CUPS.has(cup_name):
		return GP_CUPS[cup_name]
	if cup_name == "Starter Cup":
		return GP_CUPS["Bloombay GP"]
	if cup_name == "Arctic Cup":
		return GP_CUPS["Svartfjell GP"]
	if cup_name == "Desert Cup" or cup_name == "Mountain GP":
		return GP_CUPS["Al-Raihana GP"]
	if cup_name == "Sierra del Viento":
		return GP_CUPS["Sierra del Viento GP"]
	return {}

## Course after `stage_path` in the course menu's order (cups in order, then the courses outside
## a cup), wrapping round to the first.
static func get_next_course(stage_path: String) -> String:
	var order: Array = []
	for cup_name in GP_CUPS:
		for path in GP_CUPS[cup_name]["stages"]:
			if not order.has(path):
				order.append(path)
	for st in ALL_STAGES:
		if not order.has(st["path"]):
			order.append(st["path"])
	var idx := order.find(stage_path)
	return order[(idx + 1) % order.size()]


func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	process_mode = Node.PROCESS_MODE_ALWAYS

func create_server(player_name: String):
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(DEFAULT_PORT, MAX_CLIENTS)
	if error != OK:
		printerr("NetworkManager: Failed to create server! Error code: ", error)
		return error
	
	multiplayer.multiplayer_peer = peer
	players.clear()
	players[1] = {"name": player_name, "car_index": local_car_index, "paint": local_paint, "ready": true}
	gp_standings.clear()
	gp_last_pos.clear()
	stage_votes.clear()
	is_voting_active = false
	
	LANDiscovery.start_broadcasting(player_name, DEFAULT_PORT)
	print("NetworkManager: Server created on port ", DEFAULT_PORT)
	return OK

func start_single_player(player_name: String):
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	players[1] = {"name": player_name, "ready": false, "car_index": local_car_index, "paint": local_paint}
	LANDiscovery.stop_all()
	print("NetworkManager: Started single player mode")
	return OK

## SPECTATOR mode with no racers at all: Level flies a free camera round the empty course.
var inspect_mode := false

func start_inspect() -> int:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	LANDiscovery.stop_all()
	print("NetworkManager: Started inspection mode")
	return OK

func start_spectator() -> int:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	var bot_names = ["Viper", "Shadow", "Apex", "Blaze", "Nova", "Storm"]
	var bot_cars = [0, 1, 2, 3, 1, 2]
	var paint_rng := RandomNumberGenerator.new()
	paint_rng.randomize()
	for i in range(6):
		players[100 + i] = {
			"name": bot_names[i],
			"car_index": bot_cars[i],
			"paint": CarPaint.random(paint_rng, ""),
			"ready": true,
			"is_ai": true
		}
	LANDiscovery.stop_all()
	print("NetworkManager: Started spectator debug race")
	return OK

func start_local_coop(p1_name: String, p2_name: String):
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	players[1] = {"name": p1_name, "ready": false, "car_index": local_car_index, "paint": local_paint}
	players[2] = {"name": p2_name, "ready": false, "car_index": local_p2_car_index, "paint": local_p2_paint}
	LANDiscovery.stop_all()
	print("NetworkManager: Started splitscreen mode")
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
	LANDiscovery.stop_all()
	
	multiplayer.connected_to_server.connect(_on_connected_to_server, CONNECT_ONE_SHOT)
	print("NetworkManager: Connecting to ", ip, ":", port)
	return OK

func _on_connected_to_server():
	print("NetworkManager: Connected to server!")
	register_player.rpc_id(1, {"name": local_player_name, "car_index": local_car_index, "paint": local_paint, "ready": false})

func disconnect_peer():
	if peer:
		peer.close()
	multiplayer.multiplayer_peer = null
	players.clear()
	stage_votes.clear()
	is_voting_active = false
	LANDiscovery.stop_all()

func _on_player_connected(id: int):
	print("NetworkManager: Player connected ", id)

func _on_player_disconnected(id: int):
	print("NetworkManager: Player disconnected ", id)
	if players.has(id):
		players.erase(id)
	if stage_votes.has(id):
		stage_votes.erase(id)
		if multiplayer.is_server() and is_voting_active:
			sync_stage_votes.rpc(stage_votes)
	player_disconnected.emit(id)

func _on_server_disconnected():
	print("NetworkManager: Server disconnected")
	players.clear()
	stage_votes.clear()
	is_voting_active = false
	server_disconnected.emit()

# RPC to register a new player
@rpc("any_peer", "call_local", "reliable")
func register_player(info: Dictionary):
	if not multiplayer.is_server(): return
	
	var id = multiplayer.get_remote_sender_id()
	
	# Send existing players to the new player first
	for existing_id in players:
		register_player_on_client.rpc_id(id, existing_id, players[existing_id])
		
	# Broadcast the new player to everyone
	info["ready"] = false
	info["paint"] = CarPaint.clean(info.get("paint", {}))
	register_player_on_client.rpc(id, info)
	
	# Also send current multiplayer mode & cup to the new client
	sync_multiplayer_mode.rpc_id(id, multiplayer_mode, selected_mp_cup)
	print("NetworkManager: Server registered player ", id, ", info: ", info)

@rpc("authority", "call_local", "reliable")
func register_player_on_client(id: int, info: Dictionary):
	players[id] = info
	player_connected.emit(id, info)
	print("NetworkManager: Client registered player ", id, ", info: ", info)

# Ready State
@rpc("any_peer", "call_local", "reliable")
func cmd_set_ready(is_ready: bool):
	var id = multiplayer.get_remote_sender_id()
	if id == 0:
		id = multiplayer.get_unique_id() if multiplayer.multiplayer_peer else 1
	if players.has(id):
		players[id]["ready"] = is_ready
	if multiplayer.is_server():
		sync_player_ready.rpc(id, is_ready)

@rpc("authority", "call_local", "reliable")
func sync_player_ready(id: int, is_ready: bool):
	if players.has(id):
		players[id]["ready"] = is_ready
	player_ready_changed.emit(id, is_ready)

# Car Change (the car and its paint job travel together; set local_paint first)
func set_local_car(car_index: int):
	local_car_index = car_index
	var my_id = multiplayer.get_unique_id() if multiplayer.multiplayer_peer else 1
	if players.has(my_id):
		players[my_id]["car_index"] = car_index
		players[my_id]["paint"] = local_paint
	cmd_update_player_car.rpc(car_index, local_paint)

@rpc("any_peer", "call_local", "reliable")
func cmd_update_player_car(car_index: int, paint: Dictionary):
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id() if multiplayer.multiplayer_peer else 1
	var clean_paint: Dictionary = CarPaint.clean(paint)
	if players.has(sender_id):
		players[sender_id]["car_index"] = car_index
		players[sender_id]["paint"] = clean_paint
	if multiplayer.is_server():
		sync_player_car.rpc(sender_id, car_index, clean_paint)

@rpc("authority", "call_local", "reliable")
func sync_player_car(id: int, car_index: int, paint: Dictionary):
	if players.has(id):
		players[id]["car_index"] = car_index
		players[id]["paint"] = CarPaint.clean(paint)
	player_car_changed.emit(id, car_index)

# Mode & Cup Selection
func set_multiplayer_mode(mode: int, cup_name: String = "Bloombay GP"):
	if multiplayer.is_server():
		multiplayer_mode = mode
		selected_mp_cup = cup_name
		sync_multiplayer_mode.rpc(mode, cup_name)

@rpc("authority", "call_local", "reliable")
func sync_multiplayer_mode(mode: int, cup_name: String):
	multiplayer_mode = mode
	selected_mp_cup = cup_name
	multiplayer_mode_changed.emit(mode, cup_name)

# Stage Voting System (Single Stages Mode)
func start_stage_voting():
	if not multiplayer.is_server(): return
	stage_votes.clear()
	is_voting_active = true
	sync_stage_voting_started.rpc()

@rpc("authority", "call_local", "reliable")
func sync_stage_voting_started():
	stage_votes.clear()
	is_voting_active = true
	stage_voting_started.emit()
	stage_votes_updated.emit(stage_votes)

func vote_stage(choice: String):
	submit_stage_vote.rpc(choice)

@rpc("any_peer", "call_local", "reliable")
func submit_stage_vote(choice: String):
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id() if multiplayer.multiplayer_peer else 1
	if not is_voting_active:
		return
	stage_votes[sender_id] = choice
	if multiplayer.is_server():
		sync_stage_votes.rpc(stage_votes)

@rpc("authority", "call_local", "reliable")
func sync_stage_votes(votes: Dictionary):
	stage_votes = votes
	stage_votes_updated.emit(stage_votes)

func resolve_and_launch_voted_stage() -> String:
	if not multiplayer.is_server(): return ""
	is_voting_active = false
	
	# Tally votes
	var counts: Dictionary = {}
	var random_votes: int = 0
	for p_id in stage_votes:
		var choice = str(stage_votes[p_id])
		if choice == "random":
			random_votes += 1
		else:
			counts[choice] = counts.get(choice, 0) + 1
	
	var candidates: Array = []
	var max_votes: int = -1
	for stg in counts:
		if counts[stg] > max_votes:
			max_votes = counts[stg]
			candidates = [stg]
		elif counts[stg] == max_votes:
			candidates.append(stg)
			
	var winning_stage: String = ""
	# If random won or tied for highest, or if no specific votes cast:
	if random_votes > max_votes or candidates.is_empty():
		var pool: Array = []
		for s in ALL_STAGES:
			if s["path"] != current_single_stage:
				pool.append(s["path"])
		if pool.is_empty():
			for s in ALL_STAGES:
				pool.append(s["path"])
		winning_stage = pool[randi() % pool.size()]
	else:
		winning_stage = candidates[randi() % candidates.size()]
		
	current_single_stage = winning_stage
	sync_stage_voting_winner.rpc(winning_stage)
	return winning_stage

@rpc("authority", "call_local", "reliable")
func sync_stage_voting_winner(winning_stage: String):
	is_voting_active = false
	current_single_stage = winning_stage
	stage_voting_concluded.emit(winning_stage)
