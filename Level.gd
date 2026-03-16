extends Node3D

const PLAYER_CART = preload("res://PlayerCart.tscn")
const RACE_UI_SCENE = preload("res://RaceUI.tscn")

@export var finish_line: Area3D
@export var halfway_checkpoint: Area3D

enum RaceState {LOBBY, RACING, FINISHED}
var race_state: int = RaceState.LOBBY

@onready var spawn_points = $SpawnPoints.get_children()
@onready var players_container = $Players
@onready var player_spawner = $PlayerSpawner

var race_ui
var player_stats = {} # id -> {"laps": 0, "next_checkpoint": 1, "finished": false, "pos": 0}
var end_timer = 0.0

func _ready():
	player_spawner.spawn_function = _spawn_custom
	race_ui = RACE_UI_SCENE.instantiate()
	add_child(race_ui)
	
	_setup_checkpoints()
	
	if multiplayer.is_server():
		NetworkManager.player_connected.connect(_on_server_player_connected)
		NetworkManager.player_disconnected.connect(_on_server_player_disconnected)
		
		# Spawn existing players (host first)
		for id in NetworkManager.players:
			var info = NetworkManager.players[id]
			_add_player(id, info["name"])
			
	NetworkManager.player_ready_changed.connect(_on_player_ready_changed)
	NetworkManager.player_connected.connect(_on_player_list_changed)
	NetworkManager.player_disconnected.connect(_on_player_list_changed)
	
	race_ui.update_lobby(NetworkManager.players)
	race_ui.ready_pressed.connect(_on_local_ready_pressed)
	race_ui.start_pressed.connect(_on_host_start_pressed)

func _setup_checkpoints():
	# If not assigned in inspector, try to find by name as fallback
	if not finish_line:
		finish_line = get_node_or_null("FinishLine")
	if not halfway_checkpoint:
		halfway_checkpoint = get_node_or_null("Halfway")
	
	if multiplayer.is_server():
		if finish_line:
			finish_line.body_entered.connect(_on_finish_line_entered)
		if halfway_checkpoint:
			halfway_checkpoint.body_entered.connect(_on_halfway_entered)

func _on_finish_line_entered(body: Node3D):
	if race_state != RaceState.RACING: return
	var id = body.name.to_int()
	if id > 0 and player_stats.has(id):
		var stats = player_stats[id]
		if stats["next_checkpoint"] == 0 and not stats["finished"]:
			stats["laps"] += 1
			stats["next_checkpoint"] = 1
			_check_finish(id)

func _on_halfway_entered(body: Node3D):
	if race_state != RaceState.RACING: return
	var id = body.name.to_int()
	if id > 0 and player_stats.has(id):
		var stats = player_stats[id]
		if stats["next_checkpoint"] == 1 and not stats["finished"]:
			stats["next_checkpoint"] = 0

func _check_finish(id: int):
	var stats = player_stats[id]
	if stats["laps"] >= 3 and not stats["finished"]:
		stats["finished"] = true
		show_player_finished_rpc.rpc_id(id)
		
		# Start 30s timer if this is the first finisher
		if end_timer <= 0.0:
			end_timer = 30.0

@rpc("authority", "call_local", "reliable")
func show_player_finished_rpc():
	race_ui.show_message("You Finished!", 5.0)
	_disable_local_cart()

func _disable_local_cart():
	var carts = get_tree().get_nodes_in_group("player_carts")
	for c in carts:
		if c.is_local_player:
			c.can_move = false

func _on_player_list_changed(_id = 0, _info = {}):
	race_ui.update_lobby(NetworkManager.players)

func _on_player_ready_changed(_id, _is_ready):
	race_ui.update_lobby(NetworkManager.players)

func _on_server_player_connected(id: int, info: Dictionary):
	if multiplayer.is_server():
		_add_player(id, info["name"])

func _on_server_player_disconnected(id: int):
	if multiplayer.is_server():
		var p = players_container.get_node_or_null(str(id))
		if p:
			p.queue_free()
		player_stats.erase(id)

func _spawn_custom(data: Variant) -> Node:
	var cart = PLAYER_CART.instantiate()
	cart.name = str(data["id"])
	cart.player_name = data["name"]
	cart.global_transform = data["transform"]
	
	# If race is already started (e.g. late join), enable movement if local
	if race_state == RaceState.RACING:
		cart.can_move = true
		
	return cart

func _add_player(id: int, p_name: String):
	if not player_stats.has(id):
		var idx = player_stats.size() % spawn_points.size()
		player_stats[id] = {"laps": 0, "next_checkpoint": 1, "finished": false, "pos": 0}
		
		var data = {
			"id": id,
			"name": p_name,
			"transform": spawn_points[idx].global_transform
		}
		player_spawner.spawn(data)

func _on_local_ready_pressed(is_ready: bool):
	NetworkManager.cmd_set_ready.rpc(is_ready)

func _on_host_start_pressed():
	if multiplayer.is_server():
		start_race.rpc()

@rpc("authority", "call_local", "reliable")
func start_race():
	if race_state != RaceState.LOBBY:
		return
	race_state = RaceState.RACING
	race_ui.show_hud()
	race_ui.show_message("GO!", 2.0)
	
	MusicManager.play_race_music()
	get_tree().call_group("player_carts", "on_race_started")

func _process(delta):
	if multiplayer.is_server():
		if race_state == RaceState.RACING:
			_update_positions()
			
			if end_timer > 0.0:
				end_timer -= delta
				update_timer_rpc.rpc(int(end_timer))
				if end_timer <= 0.0:
					_end_race()

func _update_positions():
	var ranking = []
	for id in player_stats:
		var cart = players_container.get_node_or_null(str(id))
		if cart == null: continue
		var pinfo = player_stats[id]
		var dist = 0.0
		
		# If they finished, give them a massive score boost so they stay top
		var score = 0.0
		if pinfo["finished"]:
			score = 1000000.0 + (3 - pinfo["pos"]) * 1000 # keep their position
		else:
			if pinfo["next_checkpoint"] == 1:
				dist = cart.global_position.distance_to(halfway_checkpoint.global_position if halfway_checkpoint else Vector3(0,0,0))
			else:
				dist = cart.global_position.distance_to(finish_line.global_position if finish_line else Vector3(0,0,0))
			
			score = pinfo["laps"] * 10000.0
			if pinfo["next_checkpoint"] == 0:
				score += 5000.0
			score -= dist
		
		ranking.append({"id": id, "score": score, "laps": pinfo["laps"], "finished": pinfo["finished"]})
		
	ranking.sort_custom(func(a, b): return a["score"] > b["score"])
	
	for i in range(ranking.size()):
		var id = ranking[i]["id"]
		var pos = i + 1
		# Only update pos if not finished, so their finishing pos freezes
		if not player_stats[id]["finished"]:
			player_stats[id]["pos"] = pos
		else:
			pos = player_stats[id]["pos"]
			
		var l = ranking[i]["laps"]
		update_hud_rpc.rpc_id(id, pos, ranking.size(), mini(l + 1, 3), 3)

@rpc("authority", "call_local", "unreliable")
func update_hud_rpc(pos, total, lap, max_laps):
	race_ui.update_hud(pos, total, lap, max_laps)

@rpc("authority", "call_local", "reliable")
func update_timer_rpc(t: int):
	# Don't show end screen for racing players immediately, just update it if they see it
	# Actually wait, everyone should see the timer.
	race_ui.show_end_screen()
	race_ui.update_end_timer(t)

func _end_race():
	race_state = RaceState.FINISHED
	end_race_rpc.rpc()

@rpc("authority", "call_local", "reliable")
func end_race_rpc():
	race_ui.show_message("Race Over!", 5.0)
	_disable_local_cart()
