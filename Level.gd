@tool
extends Node3D

const PLAYER_CART = preload("res://PlayerCart.tscn")
const RACE_UI_SCENE = preload("res://RaceUI.tscn")
const ITEM_BOX_SCENE = preload("res://ItemBox.tscn")

@export var checkpoints: Array[Area3D] = []
@export var track_path: Path3D
@export var alternative_paths: Array[Path3D] = []



@export_group("Editor Tools")
@export var redistribute_checkpoints: bool:
	set(val):
		if val:
			redistribute_checkpoints = false
			if Engine.is_editor_hint():
				_rebuild_checkpoints()

@export var align_checkpoints: bool:
	set(val):
		if val:
			align_checkpoints = false
			if Engine.is_editor_hint():
				_align_checkpoints_to_track()

@export var align_spawn_points: bool:
	set(val):
		if val:
			align_spawn_points = false
			if Engine.is_editor_hint():
				_align_start_and_spawns_to_track()

enum RaceState {LOBBY, RACING, FINISHED}
var race_state: int = RaceState.LOBBY

var spawn_points: Array = []
@onready var players_container = $Players
@onready var player_spawner = $PlayerSpawner

var race_ui
var player_stats = {} # id -> {"laps": 0, "next_checkpoint_idx": 0, "finished": false, "pos": 0}
var end_timer = 0.0

var cp_offsets: Array[float] = []
var track_length: float = 0.0

func _ready():
	# @tool makes _ready() run in the editor too; skip all game/multiplayer
	# setup in that context — editor tools use the export-var setters instead.
	if Engine.is_editor_hint():
		return

	if not track_path:
		track_path = get_node_or_null("TrackPath")

	var alt_paths_container = get_node_or_null("AlternativePaths")
	if alt_paths_container:
		for child in alt_paths_container.get_children():
			if child is Path3D and not alternative_paths.has(child):
				alternative_paths.append(child)


	add_to_group("level")
	player_spawner.spawn_function = _spawn_custom
	race_ui = RACE_UI_SCENE.instantiate()
	add_child(race_ui)

	_rebuild_checkpoints()
	_align_start_and_spawns_to_track()
	_align_checkpoints_to_track()
	_setup_checkpoints()
	_spawn_item_boxes_deferred()

	# Automatically add collisions to checkpoints, finish line, and ramps at runtime
	_add_collisions_to_matching_nodes(self)
	for cp in checkpoints:
		_add_collisions_to_node(cp, true)

	# Automatically add collisions to environmental props/assets
	for prop_node_name in ["Props", "Environment", "Obstacles", "Buildings", "Vegetation"]:
		var node = get_node_or_null(prop_node_name)
		if node:
			_add_collisions_to_node(node, true)

	# Automatically build collisions for any node manually placed in the collision groups
	_add_collisions_for_group_nodes(self)

	# Align dynamically generated or editor-loaded road collision height to Visual_Road's Y position
	var tg = get_node_or_null("TerrainGenerator")
	if tg:
		var road = tg.get_node_or_null("Visual_Road")
		if road:
			for child in tg.get_children():
				if child is StaticBody3D and child.name != "Unified_World_Collision":
					child.position.y = road.position.y



	if multiplayer.is_server():
		NetworkManager.player_connected.connect(_on_server_player_connected)
		NetworkManager.player_disconnected.connect(_on_server_player_disconnected)

		if NetworkManager.current_game_mode == NetworkManager.GameMode.SINGLE_PLAYER_GP:
			var bot_names = ["Viper Bot", "Shadow Bot", "Apex Bot", "Blaze Bot", "Nova Bot"]
			var bot_cars = [1, 2, 3, 0, 1]
			for i in range(5):
				var bot_id = 100 + i
				NetworkManager.players[bot_id] = {
					"name": bot_names[i],
					"car_index": bot_cars[i],
					"ready": true,
					"is_ai": true
				}

		# Spawn existing players (host first, then bots if GP)
		for id in NetworkManager.players:
			var info = NetworkManager.players[id]
			_add_player(id, info["name"])

	NetworkManager.player_ready_changed.connect(_on_player_ready_changed)
	NetworkManager.player_connected.connect(_on_player_list_changed)
	NetworkManager.player_disconnected.connect(_on_player_list_changed)

	race_ui.update_lobby(NetworkManager.players)
	race_ui.ready_pressed.connect(_on_local_ready_pressed)
	race_ui.start_pressed.connect(_on_host_start_pressed)
	
	if NetworkManager.current_game_mode != NetworkManager.GameMode.MULTIPLAYER:
		_run_singleplayer_countdown()

func _setup_checkpoints():
	# Rebuild checkpoints list from scene tree to prevent inspector array desync
	var cp_container = get_node_or_null("Checkpoints")
	if cp_container:
		checkpoints.clear()
		var container_cps = []
		for child in cp_container.get_children():
			if child is Area3D:
				container_cps.append(child)
		
		# Sort checkpoints dynamically based on their distance along the track curve
		if track_path:
			var curve = track_path.curve
			container_cps.sort_custom(func(a, b):
				var a_local = track_path.to_local(a.global_position)
				var b_local = track_path.to_local(b.global_position)
				var a_offset = curve.get_closest_offset(a_local)
				var b_offset = curve.get_closest_offset(b_local)
				return a_offset < b_offset
			)
		
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
		if track_path:
			track_length = track_path.curve.get_baked_length()
			cp_offsets.clear()
			for cp in checkpoints:
				var local_pos = track_path.to_local(cp.global_position)
				cp_offsets.append(track_path.curve.get_closest_offset(local_pos))
				
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
			var cart = players_container.get_node_or_null(str(id))
			
			var is_finish_lap = false
			if cp_idx == checkpoints.size() - 1:
				if stats["laps"] + 1 >= NetworkManager.max_laps:
					is_finish_lap = true
			
			if cart and cart.get("is_ai"):
				cart.last_checkpoint_transform = cp.global_transform
			else:
				_sync_checkpoint_to_player.rpc_id(id, cp.global_transform, is_finish_lap)

			# If they hit the last checkpoint (Finish Line), complete a lap
			if stats["next_checkpoint_idx"] >= checkpoints.size():
				stats["laps"] += 1
				stats["next_checkpoint_idx"] = 0 # Loop back to first checkpoint
				_check_finish(id)

func _check_finish(id: int):
	var stats = player_stats[id]
	if stats["laps"] >= NetworkManager.max_laps and not stats["finished"]:
		stats["finished"] = true
		
		var cart = players_container.get_node_or_null(str(id))
		if cart and cart.get("is_ai"):
			cart.can_move = false
		else:
			show_player_finished_rpc.rpc_id(id)

		# Start 30s timer if this is the first finisher
		if end_timer <= 0.0:
			end_timer = 30.0

@rpc("authority", "call_local", "reliable")
func show_player_finished_rpc():
	race_ui.show_message("You Finished!", 5.0)
	_disable_local_cart()

@rpc("authority", "call_local", "reliable")
func _sync_checkpoint_to_player(checkpoint_transform: Transform3D, play_finish_sound: bool = false):
	var local_cart = get_tree().get_nodes_in_group("player_carts").filter(func(node): return node.is_multiplayer_authority())
	if local_cart.size() > 0:
		local_cart[0].last_checkpoint_transform = checkpoint_transform
		if play_finish_sound:
			MusicManager.play_sfx("res://sounds/finish.mp3")
		else:
			MusicManager.play_sfx("res://sounds/checkpoint.mp3")

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
	cart.car_index = data.get("car_index", 0)
	cart.global_transform = data["transform"]
	cart.is_ai = data.get("is_ai", false)

	# If race is already started (e.g. late join), enable movement if local
	if race_state == RaceState.RACING:
		cart.can_move = true

	return cart

func _add_player(id: int, p_name: String):
	if not player_stats.has(id):
		var idx = player_stats.size() % spawn_points.size()
		player_stats[id] = {"laps": 0, "next_checkpoint_idx": 0, "finished": false, "pos": 0}

		# ALIGN SPAWN TO TRACK:
		# Use the track tangent to align orientation, fallback to editor placement
		var spawn_transform = spawn_points[idx].global_transform
		if track_path:
			var curve = track_path.curve
			var local_spawn_pos = track_path.to_local(spawn_points[idx].global_position)
			var offset = curve.get_closest_offset(local_spawn_pos)
			
			var next_offset = fmod(offset + 1.0, curve.get_baked_length())
			var p1 = curve.sample_baked(offset)
			var p2 = curve.sample_baked(next_offset)
			var global_tangent = (track_path.to_global(p2) - track_path.to_global(p1)).normalized()
			
			if global_tangent.length() > 0.01:
				spawn_transform.basis = Basis.looking_at(global_tangent, Vector3.UP)
		
		# LIFT SLIGHTLY: Prevent spawning stuck in road
		spawn_transform.origin.y += 1.5

		var car_idx = 0
		var is_ai = false
		if NetworkManager.players.has(id):
			car_idx = NetworkManager.players[id].get("car_index", 0)
			is_ai = NetworkManager.players[id].get("is_ai", false)

		var data = {
			"id": id,
			"name": p_name,
			"transform": spawn_transform,
			"car_index": car_idx,
			"is_ai": is_ai
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
	if race_ui:
		race_ui.show_hud()
		var lp = race_ui.get_node_or_null("LobbyPanel")
		if lp: lp.hide()
		var hp = race_ui.get_node_or_null("HUDPanel")
		if hp: hp.show()

	# Start camera intro on all carts
	get_tree().call_group("player_carts", "start_intro_animation")

	# Wait for intro animation (3.5 seconds)
	await get_tree().create_timer(3.5).timeout

	# Start countdown
	if race_ui:
		race_ui.show_message("3", 1.0)
	MusicManager.play_sfx("res://sounds/3.mp3")
	await get_tree().create_timer(1.0).timeout
	if race_ui:
		race_ui.show_message("2", 1.0)
	MusicManager.play_sfx("res://sounds/2.mp3")
	await get_tree().create_timer(1.0).timeout
	if race_ui:
		race_ui.show_message("1", 1.0)
	MusicManager.play_sfx("res://sounds/1.mp3")
	await get_tree().create_timer(1.0).timeout

	# Now actually start the race and allow movement!
	if race_ui:
		race_ui.show_message("GO!", 2.0)
	MusicManager.play_sfx("res://sounds/Go.mp3")
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
			score = 10000000.0 + (3 - pinfo["pos"]) * 1000 # keep their position
		else:
			var offset = 0.0
			if track_path and cp_offsets.size() > 0:
				var curve = track_path.curve
				var local_pos = track_path.to_local(cart.global_position)
				
				var next_idx = pinfo["next_checkpoint_idx"]
				var prev_idx = next_idx - 1
				if prev_idx < 0:
					prev_idx = cp_offsets.size() - 1
					
				if next_idx >= cp_offsets.size():
					next_idx = cp_offsets.size() - 1
					
				var start_off = cp_offsets[prev_idx]
				var end_off = cp_offsets[next_idx]
				
				var segment_length = end_off - start_off
				if segment_length < 0:
					segment_length += track_length
					
				var min_dist = 9999999.0
				var best_t = 0.0
				var step = 5.0
				var num_steps = int(segment_length / step) + 1
				
				var start_i = -int(num_steps * 0.2)
				var end_i = num_steps + int(num_steps * 0.2)
				
				for i in range(start_i, end_i + 1):
					var t = float(i) / max(1, num_steps)
					var sample_off = fmod(start_off + t * segment_length + track_length * 2.0, track_length)
					var p = curve.sample_baked(sample_off)
					var d = p.distance_squared_to(local_pos)
					if d < min_dist:
						min_dist = d
						best_t = t
				
				offset = best_t * segment_length

			# Score = Laps * 1000000 + CheckpointIndex * 50000 + offset
			score = pinfo["laps"] * 1000000.0
			score += pinfo["next_checkpoint_idx"] * 50000.0
			score += offset

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
		if NetworkManager.players.has(id) and not NetworkManager.players[id].get("is_ai", false):
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
	
	# Build results array
	var results = []
	var final_rankings = []
	for id in player_stats:
		var stats = player_stats[id]
		var p_name = "Bot"
		var is_bot = true
		if NetworkManager.players.has(id):
			p_name = NetworkManager.players[id]["name"]
			is_bot = NetworkManager.players[id].get("is_ai", false)
		else:
			var cart = players_container.get_node_or_null(str(id))
			if cart:
				p_name = cart.player_name
				
		final_rankings.append({
			"id": id,
			"name": p_name,
			"pos": stats["pos"],
			"is_bot": is_bot
		})
	final_rankings.sort_custom(func(a, b): return a["pos"] < b["pos"])
	
	var points_map = [10, 8, 6, 4]
	for i in range(final_rankings.size()):
		var racer = final_rankings[i]
		var round_pts = points_map[mini(i, points_map.size() - 1)]
		
		if NetworkManager.current_game_mode == NetworkManager.GameMode.SINGLE_PLAYER_GP:
			var current_total = NetworkManager.gp_standings.get(racer["name"], 0)
			NetworkManager.gp_standings[racer["name"]] = current_total + round_pts
			
		results.append({
			"name": racer["name"],
			"pos": racer["pos"],
			"round_points": round_pts,
			"total_points": NetworkManager.gp_standings.get(racer["name"], round_pts)
		})
		
	end_race_rpc.rpc(results)

@rpc("authority", "call_local", "reliable")
func end_race_rpc(results_data: Array):
	race_ui.show_message("Race Over!", 5.0)
	_disable_local_cart()
	if race_ui.has_method("display_race_results"):
		race_ui.display_race_results(results_data)

func _run_singleplayer_countdown():
	await get_tree().process_frame
	if multiplayer.is_server():
		start_race.rpc()

func on_player_exploded(is_local: bool):
	if is_local:
		race_ui.show_message("WRECKED", 3.0)

func _spawn_item_boxes_deferred():
	await get_tree().physics_frame
	await get_tree().physics_frame
	_spawn_item_boxes()

func _spawn_item_boxes():
	# Spawn a row of 3 items across each checkpoint gate and the finish line
	var cp_idx = 0
	for cp in checkpoints:
		var right_dir = cp.global_transform.basis.x.normalized()
		var spacing = 3.5
		var offsets = [-spacing, 0.0, spacing]
		for offset_idx in range(offsets.size()):
			var offset = offsets[offset_idx]
			var box = ITEM_BOX_SCENE.instantiate()
			box.name = "ItemBox_%d_%d" % [cp_idx, offset_idx]
			add_child(box)
			box.global_position = cp.global_position + right_dir * offset + Vector3(0, 1.5, 0)
		cp_idx += 1
	
	# Spawn 15 additional random item boxes along the track
	_spawn_random_item_boxes(15)

func _spawn_random_item_boxes(count: int):
	if not track_path: return
	var curve = track_path.curve
	var length = curve.get_baked_length()
	var space_state = get_world_3d().direct_space_state
	if not space_state: return

	var spawned_count = 0
	var attempts = 0
	var max_attempts = count * 25
	
	while spawned_count < count and attempts < max_attempts:
		attempts += 1
		var offset = randf_range(10.0, length - 10.0) # Avoid spawning directly on the start line
		var local_pos = curve.sample_baked(offset)
		var global_pos = track_path.to_global(local_pos)
		
		# Compute track tangent and right vector to offset left/right randomly
		var next_offset = fmod(offset + 1.0, length)
		var p1 = curve.sample_baked(offset)
		var p2 = curve.sample_baked(next_offset)
		var tangent = (track_path.to_global(p2) - track_path.to_global(p1)).normalized()
		if tangent.length() < 0.01:
			continue
		var right_vec = tangent.cross(Vector3.UP).normalized()
		
		var lateral_offset = randf_range(-4.0, 4.0)
		var spawn_pos = global_pos + right_vec * lateral_offset + Vector3(0, 10.0, 0)
		
		# Raycast down to find the road surface
		var query = PhysicsRayQueryParameters3D.create(spawn_pos, spawn_pos - Vector3(0, 20.0, 0))
		query.collision_mask = 1 # road/terrain
		var result = space_state.intersect_ray(query)
		if not result:
			continue
			
		var hit_pos = result.position
		var final_pos = hit_pos + Vector3(0, 1.2, 0)
		
		# Perform a sphere shape overlap check to make sure it doesn't intersect obstacles or other objects
		var shape_query = PhysicsShapeQueryParameters3D.new()
		var sphere = SphereShape3D.new()
		sphere.radius = 1.5
		shape_query.shape = sphere
		shape_query.transform = Transform3D(Basis.IDENTITY, final_pos)
		shape_query.collision_mask = 1 | 2 | 4
		
		var overlaps = space_state.intersect_shape(shape_query)
		var is_obstructed = false
		for overlap in overlaps:
			var collider = overlap.collider
			if collider:
				var c_name = collider.name.to_lower()
				var is_road_or_terrain = c_name.contains("road") or c_name.contains("terrain") or c_name.contains("track") or c_name.contains("unified_world") or c_name.contains("gate") or c_name.contains("finishline") or c_name.contains("checkpoint") or c_name.contains("halfway") or c_name.contains("ramp")
				if not is_road_or_terrain or c_name.contains("itembox") or c_name.contains("cart") or c_name.contains("player"):
					is_obstructed = true
					break
		
		if not is_obstructed:
			var box = ITEM_BOX_SCENE.instantiate()
			box.name = "RandomItemBox_%d" % spawned_count
			add_child(box)
			box.global_position = final_pos
			spawned_count += 1

func _rebuild_checkpoints():
	if not track_path: return
	var cp_container = get_node_or_null("Checkpoints")
	if not cp_container: return

	var curve = track_path.curve
	var length = curve.get_baked_length()
	var children = cp_container.get_children()
	if children.is_empty(): return

	for i in range(children.size()):
		var child = children[i]
		if child is Node3D:
			var offset = (float(i + 1) / (children.size() + 1)) * length
			var pos = curve.sample_baked(offset)
			child.global_position = track_path.to_global(pos)

			# Orient to track
			var next_offset = min(offset + 1.0, length)
			var tangent = (curve.sample_baked(next_offset) - pos).normalized()
			if tangent.length() > 0.01:
				child.look_at(child.global_position + tangent, Vector3.UP)

	print("Checkpoints redistributed along track!")

func _align_checkpoints_to_track():
	if not track_path: return
	var cp_container = get_node_or_null("Checkpoints")
	if not cp_container: return

	var curve = track_path.curve
	var length = curve.get_baked_length()
	var children = cp_container.get_children()
	if children.is_empty(): return

	for child in children:
		if child is Node3D:
			# Find closest offset along the track curve
			var local_pos = track_path.to_local(child.global_position)
			var offset = curve.get_closest_offset(local_pos)
			var snapped_local_pos = curve.sample_baked(offset)
			
			child.global_position = track_path.to_global(snapped_local_pos)

			# Orient to track tangent at this offset
			var next_offset = fmod(offset + 1.0, length)
			var tangent_local = (curve.sample_baked(next_offset) - snapped_local_pos).normalized()
			if tangent_local.length() > 0.01:
				var tangent_global = (track_path.to_global(snapped_local_pos + tangent_local) - child.global_position).normalized()
				child.look_at(child.global_position + tangent_global, Vector3.UP)

	print("Checkpoints aligned and oriented to track curve!")

func _create_primitive_shape_from_mesh(mesh: Mesh, type: String) -> Shape3D:
	if not mesh: return null
	var aabb = mesh.get_aabb()
	var size = aabb.size
	
	match type:
		"box":
			var shape = BoxShape3D.new()
			shape.size = size
			return shape
		"sphere":
			var shape = SphereShape3D.new()
			shape.radius = max(size.x, max(size.y, size.z)) * 0.5
			return shape
		"cylinder":
			var shape = CylinderShape3D.new()
			shape.radius = max(size.x, size.z) * 0.5
			shape.height = size.y
			return shape
		"capsule":
			var shape = CapsuleShape3D.new()
			shape.radius = max(size.x, size.z) * 0.5
			shape.height = size.y
			return shape
	return null


func _add_collisions_to_node(root_node: Node, use_trimesh: bool = false):
	if root_node == null: return
	
	if root_node is MeshInstance3D:
		# Check group overrides
		var force_none = _is_node_or_ancestor_in_group(root_node, "collision_none")
		if force_none:
			return # Skip building collision for this node
			
		var mesh = root_node.mesh
		if mesh:
			var name_key = "Col_" + str(root_node.get_path()).replace("/", "_")
			
			# Find a parent that is a Node3D but NOT an Area3D to avoid overlapping triggers
			var target_parent = root_node.get_parent()
			while target_parent and (target_parent is Area3D or not (target_parent is Node3D)):
				target_parent = target_parent.get_parent()
			
			var already_has_collision = false
			if target_parent and target_parent.has_node(name_key):
				already_has_collision = true
			elif not target_parent:
				var level_root = get_tree().get_first_node_in_group("level")
				if level_root and level_root.has_node(name_key):
					already_has_collision = true
				
			if not already_has_collision:
				var shape
				
				# Get vertex count of the mesh for fallback and performance checks
				var vertex_count = 0
				for s in range(mesh.get_surface_count()):
					var arrays = mesh.surface_get_arrays(s)
					if arrays.size() > Mesh.ARRAY_VERTEX:
						var vertices = arrays[Mesh.ARRAY_VERTEX]
						if vertices:
							vertex_count += vertices.size()
				
				# Check explicit group collision overrides
				var force_convex = _is_node_or_ancestor_in_group(root_node, "collision_convex")
				var force_trimesh = _is_node_or_ancestor_in_group(root_node, "collision_trimesh")
				var force_box = _is_node_or_ancestor_in_group(root_node, "collision_box")
				var force_sphere = _is_node_or_ancestor_in_group(root_node, "collision_sphere")
				var force_cylinder = _is_node_or_ancestor_in_group(root_node, "collision_cylinder")
				var force_capsule = _is_node_or_ancestor_in_group(root_node, "collision_capsule")
				var force_decomposition = _is_node_or_ancestor_in_group(root_node, "collision_decomposition")
				
				if force_decomposition:
					var decomp_name = name_key + "_decomp"
					var already_decomposed = false
					if target_parent and target_parent.has_node(decomp_name):
						already_decomposed = true
					elif not target_parent:
						var level_root = get_tree().get_first_node_in_group("level")
						if level_root and level_root.has_node(decomp_name):
							already_decomposed = true
							
					if not already_decomposed:
						var static_body = StaticBody3D.new()
						static_body.name = decomp_name
						if target_parent:
							print("[COLLISION BUILDER] Performing convex decomposition on ", root_node.name, ", adding static body ", static_body.name, " to parent ", target_parent.name)
							target_parent.add_child(static_body)
						else:
							print("[COLLISION BUILDER] Performing convex decomposition on ", root_node.name, ", adding static body ", static_body.name, " to level root")
							add_child(static_body)
						
						var original_parent = root_node.get_parent()
						root_node.reparent(static_body)
						root_node.create_multiple_convex_collisions()
						root_node.reparent(original_parent)
						
						var t = root_node.global_transform
						t.basis = t.basis.orthonormalized()
						static_body.global_transform = t
				else:
					var use_trimesh_actual = use_trimesh
					if force_convex:
						use_trimesh_actual = false
					elif force_trimesh:
						use_trimesh_actual = true
					else:
						# High-poly meshes should fallback to convex collision to prevent Jolt failures and lag,
						# EXCEPT for gates/arches (like checkpoints and finish lines) which need concave trimesh to keep their openings clear.
						var path_lower = str(root_node.get_path()).to_lower()
						var is_gate = path_lower.contains("gate") or path_lower.contains("checkpoint") or path_lower.contains("finish")
						if use_trimesh and vertex_count > 10000 and not is_gate:
							print("[COLLISION BUILDER] Mesh ", root_node.name, " has high vertex count (", vertex_count, "), falling back to convex shape for stability.")
							use_trimesh_actual = false
					
					if force_box:
						shape = _create_primitive_shape_from_mesh(mesh, "box")
					elif force_sphere:
						shape = _create_primitive_shape_from_mesh(mesh, "sphere")
					elif force_cylinder:
						shape = _create_primitive_shape_from_mesh(mesh, "cylinder")
					elif force_capsule:
						shape = _create_primitive_shape_from_mesh(mesh, "capsule")
					elif use_trimesh_actual:
						shape = mesh.create_trimesh_shape()
						if shape is ConcavePolygonShape3D and shape.data.is_empty():
							print("[COLLISION BUILDER] WARNING: Trimesh shape for ", root_node.name, " has 0 faces/triangles (untriangulated or invalid geometry). Falling back to convex shape for safety.")
							shape = mesh.create_convex_shape(true, true)
					else:
						shape = mesh.create_convex_shape(true, true)
						
					if shape:
						# Bake the global scale into the shape's vertices/points/dimensions to prevent Jolt degenerate shape failures on scaled models
						var global_scale = root_node.global_transform.basis.get_scale()
						if global_scale != Vector3.ONE:
							if shape is BoxShape3D:
								shape.size = shape.size * global_scale
							elif shape is SphereShape3D:
								shape.radius = shape.radius * max(global_scale.x, max(global_scale.y, global_scale.z))
							elif shape is CylinderShape3D or shape is CapsuleShape3D:
								shape.radius = shape.radius * max(global_scale.x, global_scale.z)
								shape.height = shape.height * global_scale.y
							elif shape is ConcavePolygonShape3D:
								var scaled_faces = PackedVector3Array()
								for vertex in shape.data:
									scaled_faces.append(vertex * global_scale)
								shape.data = scaled_faces
							elif shape is ConvexPolygonShape3D:
								var scaled_points = PackedVector3Array()
								for pt in shape.points:
									scaled_points.append(pt * global_scale)
								shape.points = scaled_points
	 
						var static_body = StaticBody3D.new()
						static_body.name = name_key
						var collision_shape = CollisionShape3D.new()
						collision_shape.shape = shape
						static_body.add_child(collision_shape)
						
						if target_parent:
							print("[COLLISION BUILDER] Adding collision static body ", static_body.name, " to parent ", target_parent.name)
							target_parent.add_child(static_body)
						else:
							print("[COLLISION BUILDER] Adding collision static body ", static_body.name, " to level root")
							add_child(static_body)
						
						# Align static body exactly to the mesh, but orthonormalize to remove scale (since we baked it into the shape)
						var t = root_node.global_transform
						t.basis = t.basis.orthonormalized()
						static_body.global_transform = t
					
	for child in root_node.get_children():
		_add_collisions_to_node(child, use_trimesh)
 
func _add_collisions_to_matching_nodes(node: Node):
	if node == null: return
	
	if node.name.to_lower().contains("ramp"):
		print("[COLLISION BUILDER] Matching ramp node found: ", node.name, " (", node.get_class(), ")")
		if node is CSGPolygon3D or node is CSGPrimitive3D:
			if "use_collision" in node:
				node.use_collision = true
		_add_collisions_to_node(node, true)
		
	for child in node.get_children():
		_add_collisions_to_matching_nodes(child)
 
func _add_collisions_for_group_nodes(node: Node):
	if node == null: return
	
	if node.is_in_group("collision_trimesh"):
		_add_collisions_to_node(node, true)
	elif node.is_in_group("collision_convex"):
		_add_collisions_to_node(node, false)
	elif node.is_in_group("collision_box") or node.is_in_group("collision_sphere") or node.is_in_group("collision_cylinder") or node.is_in_group("collision_capsule"):
		_add_collisions_to_node(node, false)
		
	for child in node.get_children():
		_add_collisions_for_group_nodes(child)
 
func _is_node_or_ancestor_in_group(node: Node, group_name: String) -> bool:
	var current = node
	while current and current != self:
		if current.is_in_group(group_name):
			return true
		current = current.get_parent()
	return false

func _align_start_and_spawns_to_track():
	var fl = get_node_or_null("FinishLine")
	if not fl: return
	
	# Delete old root-level SpawnPoints if they exist to clean up the scene tree
	var old_sp = get_node_or_null("SpawnPoints")
	if old_sp:
		old_sp.free()
		
	# Find or create a SpawnPoints container under the FinishLine node
	var spawn_container = fl.get_node_or_null("SpawnPoints")
	if not spawn_container:
		spawn_container = Node3D.new()
		spawn_container.name = "SpawnPoints"
		fl.add_child(spawn_container)
		if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
			spawn_container.owner = get_tree().edited_scene_root
			
	# Reset container local transform to align with the FinishLine
	spawn_container.transform = Transform3D.IDENTITY
	
	var spawns = []
	for i in range(1, 7):
		var name = "Spawn" + str(i)
		var sp = spawn_container.get_node_or_null(name)
		if not sp:
			sp = Marker3D.new()
			sp.name = name
			spawn_container.add_child(sp)
			if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
				sp.owner = get_tree().edited_scene_root
			
			var indicator = preload("res://SpawnIndicator.tscn").instantiate()
			sp.add_child(indicator)
			if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
				indicator.owner = get_tree().edited_scene_root
				for child in indicator.get_children():
					child.owner = get_tree().edited_scene_root
		spawns.append(sp)
		
	# Layout relative to FinishLine: 3 rows of 2 spawns
	# local Z is positive (behind) in Godot's coordinates
	var local_zs = [6.0, 6.0, 12.0, 12.0, 18.0, 18.0]
	var local_xs = [-3.0, 3.0, -3.0, 3.0, -3.0, 3.0]
	
	for idx in range(spawns.size()):
		var spawn = spawns[idx]
		if spawn:
			spawn.transform = Transform3D.IDENTITY
			spawn.position = Vector3(local_xs[idx], 0.5, local_zs[idx])
			
	spawn_points = spawns
