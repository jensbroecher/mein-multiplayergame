extends Node3D

const PLAYER_CART = preload("res://PlayerCart.tscn")
const RACE_UI_SCENE = preload("res://RaceUI.tscn")
const ITEM_BOX_SCENE = preload("res://ItemBox.tscn")

@export var checkpoints: Array[Area3D] = []
@export var track_path: Path3D

enum RaceState {LOBBY, RACING, FINISHED}
var race_state: int = RaceState.LOBBY

@onready var spawn_points = $SpawnPoints.get_children()
@onready var players_container = $Players
@onready var player_spawner = $PlayerSpawner

var race_ui
var player_stats = {} # id -> {"laps": 0, "next_checkpoint_idx": 0, "finished": false, "pos": 0}
var end_timer = 0.0

func _ready():
	add_to_group("level")
	player_spawner.spawn_function = _spawn_custom
	race_ui = RACE_UI_SCENE.instantiate()
	add_child(race_ui)
	
	_setup_checkpoints()
	_spawn_item_boxes()
	
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
	# If no checkpoints assigned, try to find any Area3Ds in a "Checkpoints" node
	if checkpoints.is_empty():
		var cp_container = get_node_or_null("Checkpoints")
		if cp_container:
			var container_cps = []
			for child in cp_container.get_children():
				if child is Area3D:
					container_cps.append(child)
			checkpoints.append_array(container_cps)
			
		# ALWAYS append the FinishLine as the absolute final checkpoint of the lap
		var fl = get_node_or_null("FinishLine")
		if fl and not checkpoints.has(fl):
			checkpoints.append(fl)
		elif not fl and checkpoints.is_empty():
			# Fallback for old scenes
			var hw = get_node_or_null("Halfway")
			if hw: checkpoints.append(hw)
	
	if multiplayer.is_server():
		for i in range(checkpoints.size()):
			var cp = checkpoints[i]
			cp.body_entered.connect(_on_checkpoint_entered.bind(i))

func _on_checkpoint_entered(body: Node3D, cp_idx: int):
	if race_state != RaceState.RACING: return
	var id = body.name.to_int()
	if id > 0 and player_stats.has(id):
		var stats = player_stats[id]
		if stats["finished"]: return
		
		# Players must hit checkpoints in order
		if cp_idx == stats["next_checkpoint_idx"]:
			# Progress to next checkpoint
			stats["next_checkpoint_idx"] += 1
			
			# Inform the player cart of its last passed checkpoint for respawn purposes
			var cp = checkpoints[cp_idx]
			_sync_checkpoint_to_player.rpc_id(id, cp.global_transform)
			
			# If they hit the last checkpoint (Finish Line), complete a lap
			if stats["next_checkpoint_idx"] >= checkpoints.size():
				stats["laps"] += 1
				stats["next_checkpoint_idx"] = 0 # Loop back to first checkpoint
				_check_finish(id)

func _check_finish(id: int):
	var stats = player_stats[id]
	if stats["laps"] >= NetworkManager.max_laps and not stats["finished"]:
		stats["finished"] = true
		show_player_finished_rpc.rpc_id(id)
		
		# Start 30s timer if this is the first finisher
		if end_timer <= 0.0:
			end_timer = 30.0

@rpc("authority", "call_local", "reliable")
func show_player_finished_rpc():
	race_ui.show_message("You Finished!", 5.0)
	_disable_local_cart()

@rpc("authority", "call_local", "reliable")
func _sync_checkpoint_to_player(checkpoint_transform: Transform3D):
	var local_cart = get_tree().get_nodes_in_group("player_carts").filter(func(node): return node.is_multiplayer_authority())
	if local_cart.size() > 0:
		local_cart[0].last_checkpoint_transform = checkpoint_transform

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
		player_stats[id] = {"laps": 0, "next_checkpoint_idx": 0, "finished": false, "pos": 0}
		
		# ALIGN SPAWN TO TRACK:
		# Calculate the orientation based on the track curve
		var spawn_transform = spawn_points[idx].global_transform
		if track_path:
			var curve = track_path.curve
			var pos = spawn_transform.origin
			var offset = curve.get_closest_offset(pos)
			var curve_pos = curve.sample_baked(offset)
			
			# Find tangent at this point
			var next_offset = min(offset + 0.5, curve.get_baked_length())
			var tangent = (curve.sample_baked(next_offset) - curve_pos).normalized()
			if tangent.length() < 0.01:
				tangent = Vector3.BACK # Fallback
				
			var up = Vector3.UP
			var right = tangent.cross(up).normalized()
			# Re-calculate UP to be perfectly orthogonal to tangent and right
			up = right.cross(tangent).normalized()
			
			# Create a new basis facing along the tangent
			# forward = -z in Godot
			spawn_transform.basis = Basis(right, up, -tangent)
			
			# LIFT SLIGHTLY: Prevent spawning stuck in road (y_offset=0.15 for road)
			spawn_transform.origin.y += 0.2
		
		var data = {
			"id": id,
			"name": p_name,
			"transform": spawn_transform
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
		
		# If they finished, give them a massive score boost so they stay top
		var score = 0.0
		if pinfo["finished"]:
			score = 1000000.0 + (3 - pinfo["pos"]) * 1000 # keep their position
		else:
			var dist = 0.0
			var next_idx = pinfo["next_checkpoint_idx"]
			if not checkpoints.is_empty():
				dist = cart.global_position.distance_to(checkpoints[next_idx].global_position)
			
			# Score = Laps * 100000 + CheckpointIndex * 10000 - distance
			score = pinfo["laps"] * 100000.0
			score += next_idx * 1000.0
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
		update_hud_rpc.rpc_id(id, pos, ranking.size(), mini(l + 1, NetworkManager.max_laps), NetworkManager.max_laps)

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

func on_player_exploded(is_local: bool):
	if is_local:
		race_ui.show_message("WRECKED", 3.0)

func _spawn_item_boxes():
	if track_path:
		var curve = track_path.curve
		var length = curve.get_baked_length()
		var step = 150.0 # Standard spacing
		# If the track is small, reduce step
		if length < 500: step = 50.0
		
		for d in range(0, int(length), int(step)):
			# MUST use global position!
			var local_pos = curve.sample_baked(d)
			var global_pos = track_path.to_global(local_pos)
			global_pos.y += 1.0 # Float above road
			
			var box = ITEM_BOX_SCENE.instantiate()
			add_child(box) # Add first to set global_transform correctly
			box.global_position = global_pos
	elif not checkpoints.is_empty():
		# Fallback: Spawn items at each checkpoint
		for cp in checkpoints:
			var box = ITEM_BOX_SCENE.instantiate()
			add_child(box)
			box.global_position = cp.global_position + Vector3(0, 1.5, 0)
