# regenerate_harbor_pier.gd
# Regenerates levels/HarborPierLevel.tscn with the extended harbor circuit,
# elevated skyway viaduct, solid dock platforms, gapless corner junctions,
# 3D curve path, and checkpoints.
extends Node

func _ready() -> void:
	print("=== Regenerating Harbor Pier Level ===")
	
	var level_scene := Node3D.new()
	level_scene.name = "HarborPierLevel"
	
	var level_script: Script = load("res://levels/Level.gd")
	level_scene.set_script(level_script)

	# 1. Weather Controller
	var weather_packed: PackedScene = load("res://addons/GodotWeatherSystem/weather_controller.tscn")
	if weather_packed:
		var wc = weather_packed.instantiate()
		wc.name = "WeatherController"
		wc.set("time_of_day_hours", 17.4)
		wc.set("selected_weather", 1)
		level_scene.add_child(wc)
		wc.owner = level_scene

	# 2. TerrainGenerator
	var tg := Node3D.new()
	tg.name = "TerrainGenerator"
	var tg_script: Script = load("res://TerrainGenerator.gd")
	tg.set_script(tg_script)
	tg.set("level_prefix", "harbor_pier")
	tg.set("no_water", false)
	level_scene.add_child(tg)
	tg.owner = level_scene

	# 3. TrackPath
	var track_path := Path3D.new()
	track_path.name = "TrackPath"
	var curve := Curve3D.new()
	curve.bake_interval = 0.25

	# Add all 3D curve points
	var curve_pts = [
		# in, out, pos
		[Vector3(-18, 0, 0), Vector3(18, 0, 0), Vector3(-50, 3.55, -95)],      # 0 Finish line straight
		[Vector3(-16, 0, 0), Vector3(16, 0, 0), Vector3(40, 3.55, -95)],       # 1 Pre-jump straight
		[Vector3(-10, 0, 0), Vector3(8, 0.4, 0), Vector3(70, 3.55, -95)],      # 2 Jump 1 Takeoff ramp
		[Vector3(-6, -0.4, 0), Vector3(6, -0.4, 0), Vector3(82, 6.2, -95)],    # 3 Jump 1 Apex in air
		[Vector3(-8, 0.4, 0), Vector3(10, 0, 0), Vector3(94, 3.55, -95)],      # 4 Jump 1 Landing ramp
		[Vector3(-14, 0, 0), Vector3(10, 0, 0), Vector3(165, 3.55, -95)],     # 5 NE corner approach
		[Vector3(0, 0, -12), Vector3(0, 0, 12), Vector3(185, 3.55, -75)],     # 6 NE corner apex
		[Vector3(0, 0, -12), Vector3(0, 0, 10), Vector3(185, 3.55, -35)],     # 7 Pre-viaduct straight
		[Vector3(0, -1.0, -10), Vector3(0, 1.0, 10), Vector3(185, 7.0, -7.5)],# 8 Viaduct Incline mid
		[Vector3(0, -0.4, -12), Vector3(0, 0, 12), Vector3(185, 10.55, 20)],  # 9 High Skyway entry
		[Vector3(0, 0, -12), Vector3(0, 0, 12), Vector3(185, 10.55, 37.5)],   # 10 High Skyway midpoint
		[Vector3(0, 0, -12), Vector3(0, -0.4, 12), Vector3(185, 10.55, 55)],  # 11 High Skyway exit
		[Vector3(0, 1.0, -10), Vector3(0, -1.0, 10), Vector3(185, 7.0, 80)],  # 12 Viaduct Descent mid
		[Vector3(0, 0, -10), Vector3(0, 0, 10), Vector3(185, 3.55, 105)],     # 13 Viaduct Landing / SE entry
		[Vector3(0, 0, -12), Vector3(0, 0, 8), Vector3(185, 3.55, 115)],      # 14 SE corner apex
		[Vector3(12, 0, 0), Vector3(-12, 0, 0), Vector3(165, 3.55, 125)],     # 15 SE turn exit
		[Vector3(12, 0, 0), Vector3(-10, 0, 0), Vector3(105, 3.55, 125)],     # 16 South pier approach to basin
		[Vector3(0, 0, 12), Vector3(0, 0, -12), Vector3(80, 3.55, 105)],      # 17 Turn North into Basin
		[Vector3(0, 0, 12), Vector3(0, 0, -12), Vector3(80, 3.55, 65)],       # 18 Central Basin Finger straight
		[Vector3(0, 0, 10), Vector3(-10, 0, 0), Vector3(70, 3.55, 35)],       # 19 Turn West into Cross-Channel
		[Vector3(12, 0, 0), Vector3(-12, 0, 0), Vector3(20, 3.55, 35)],       # 20 Cross-Channel bridge straight
		[Vector3(10, 0, 0), Vector3(0, 0, 10), Vector3(-30, 3.55, 35)],       # 21 West Central corner turn South
		[Vector3(0, 0, -12), Vector3(0, 0, 12), Vector3(-40, 3.55, 65)],      # 22 West Central Finger Southbound
		[Vector3(0, 0, -12), Vector3(0, 0, 10), Vector3(-40, 3.55, 105)],     # 23 Approach to South Pier
		[Vector3(0, 0, -10), Vector3(-10, 0, 0), Vector3(-50, 3.55, 125)],    # 24 Turn West onto South Pier
		[Vector3(10, 0, 0), Vector3(-8, 0.4, 0), Vector3(-70, 3.55, 125)],     # 25 Jump 2 Takeoff ramp
		[Vector3(6, -0.4, 0), Vector3(-6, -0.4, 0), Vector3(-96, 6.2, 125)],   # 26 Jump 2 Apex in air
		[Vector3(8, 0.4, 0), Vector3(-10, 0, 0), Vector3(-124, 3.55, 125)],   # 27 Jump 2 Landing ramp
		[Vector3(12, 0, 0), Vector3(-10, 0, 0), Vector3(-155, 3.55, 125)],    # 28 SW corner approach
		[Vector3(0, 0, 12), Vector3(0, 0, -12), Vector3(-175, 3.55, 105)],    # 29 SW corner apex
		[Vector3(0, 0, 12), Vector3(0, 0, -12), Vector3(-175, 3.55, 4)],      # 30 West Pier Channel Bridge
		[Vector3(0, 0, 12), Vector3(0, 0, -12), Vector3(-175, 3.55, -75)],    # 31 NW corner apex
		[Vector3(-10, 0, 0), Vector3(12, 0, 0), Vector3(-155, 3.55, -95)],    # 32 NW turn exit
		[Vector3(-18, 0, 0), Vector3(18, 0, 0), Vector3(-50, 3.55, -95)]      # 33 Closed back to start
	]

	for pt in curve_pts:
		curve.add_point(pt[2], pt[0], pt[1])

	track_path.curve = curve
	level_scene.add_child(track_path)
	track_path.owner = level_scene

	# Link TrackPath to TerrainGenerator & generate harbor world
	tg.set("track_path", track_path)
	tg.call("generate_world")

	# Set owners for all generated children under TerrainGenerator
	_set_owner_recursive(tg, level_scene)

	# 4. Players node
	var players_node := Node3D.new()
	players_node.name = "Players"
	level_scene.add_child(players_node)
	players_node.owner = level_scene

	# 5. Finish Line & Spawn Points
	var gate_scene: PackedScene = load("res://CheckpointGate.tscn")
	var spawn_scene: PackedScene = load("res://SpawnIndicator.tscn")

	var finish_line = gate_scene.instantiate()
	finish_line.name = "FinishLine"
	finish_line.position = Vector3(-50.0, 3.55, -95.0)
	finish_line.rotation_degrees = Vector3(0, 90, 0)
	finish_line.set("is_finish_line", true)
	level_scene.add_child(finish_line)
	finish_line.owner = level_scene

	var spawn_points := Node3D.new()
	spawn_points.name = "SpawnPoints"
	finish_line.add_child(spawn_points)
	spawn_points.owner = level_scene

	var grid_coords = [
		Vector3(-3, 0.45, 6.0),
		Vector3(3, 0.45, 6.0),
		Vector3(-3, 0.45, 12.0),
		Vector3(3, 0.45, 12.0),
		Vector3(-3, 0.45, 18.0),
		Vector3(3, 0.45, 18.0)
	]
	for i in range(grid_coords.size()):
		var sp := Marker3D.new()
		sp.name = "Spawn%d" % (i + 1)
		sp.position = grid_coords[i]
		sp.gizmo_extents = 0.3
		spawn_points.add_child(sp)
		sp.owner = level_scene

		if spawn_scene:
			var si = spawn_scene.instantiate()
			si.name = "SpawnIndicator"
			sp.add_child(si)
			si.owner = level_scene

	# 6. Multiplayer Spawners
	var p_spawner := MultiplayerSpawner.new()
	p_spawner.name = "PlayerSpawner"
	p_spawner.set("_spawnable_scenes", PackedStringArray(["uid://cart123"]))
	p_spawner.spawn_path = NodePath("../Players")
	p_spawner.spawn_limit = 6
	level_scene.add_child(p_spawner)
	p_spawner.owner = level_scene

	var proj_spawner := MultiplayerSpawner.new()
	proj_spawner.name = "ProjectileSpawner"
	proj_spawner.spawn_path = NodePath(".")
	level_scene.add_child(proj_spawner)
	proj_spawner.owner = level_scene

	# 7. Checkpoints Container & Gates
	var checkpoints_container := Node3D.new()
	checkpoints_container.name = "Checkpoints"
	level_scene.add_child(checkpoints_container)
	checkpoints_container.owner = level_scene

	var cp_defs = [
		# name, pos, rot_y_deg
		["Halfway2", Vector3(185.0, 3.55, -55.0), 180.0],
		["Halfway3", Vector3(185.0, 10.55, 37.5), 180.0],  # On Elevated Skyway Viaduct!
		["Halfway4", Vector3(145.0, 3.55, 125.0), -90.0],
		["Halfway5", Vector3(80.0, 3.55, 75.0), 0.0],      # Central Basin Finger
		["Halfway6", Vector3(20.0, 3.55, 35.0), -90.0],    # Inner Basin Bridge
		["Halfway7", Vector3(-40.0, 3.55, 80.0), 180.0],   # West Central Finger
		["Halfway8", Vector3(-60.0, 3.55, 125.0), -90.0],  # South Pier before jump
		["Halfway9", Vector3(-175.0, 3.55, 40.0), 0.0],    # West Pier
		["Halfway10", Vector3(-110.0, 3.55, -95.0), 90.0]  # Home straight approach
	]

	var cp_node_paths: Array[NodePath] = [NodePath("")] # index 0 is placeholder
	for cp_info in cp_defs:
		var gate = gate_scene.instantiate()
		gate.name = cp_info[0]
		gate.position = cp_info[1]
		gate.rotation_degrees = Vector3(0, cp_info[2], 0)
		checkpoints_container.add_child(gate)
		gate.owner = level_scene
		cp_node_paths.append(NodePath("Checkpoints/" + cp_info[0]))

	# Final checkpoint is the FinishLine
	cp_node_paths.append(NodePath("FinishLine"))

	level_scene.set("checkpoints", cp_node_paths)
	level_scene.set("track_path", NodePath("TrackPath"))

	# 8. Boost Pads
	var boost_scene: PackedScene = load("res://BoostPad.tscn")
	var boost_container := Node3D.new()
	boost_container.name = "BoostPads"
	level_scene.add_child(boost_container)
	boost_container.owner = level_scene

	if boost_scene:
		var bp_defs = [
			["BoostPad_Start", Vector3(20.0, 3.6, -95.0), 90.0],
			["BoostPad_AfterJumpE", Vector3(185.0, 3.6, -78.9), 180.0],
			["BoostPad_Skyway", Vector3(185.0, 10.6, 37.5), 180.0],
			["BoostPad_InnerBridge", Vector3(20.0, 3.6, 35.0), -90.0],
			["BoostPad_WestPier", Vector3(-175.0, 3.6, 85.0), 0.0]
		]
		for bp_info in bp_defs:
			var bp = boost_scene.instantiate()
			bp.name = bp_info[0]
			bp.position = bp_info[1]
			bp.rotation_degrees = Vector3(0, bp_info[2], 0)
			boost_container.add_child(bp)
			bp.owner = level_scene

	# 9. Additional containers
	for c_name in ["AlternativePaths", "Props", "Environment", "Vegetation", "Buildings"]:
		var c := Node3D.new()
		c.name = c_name
		level_scene.add_child(c)
		c.owner = level_scene

	# 10. Save Scene
	var packed_scene := PackedScene.new()
	var pack_err = packed_scene.pack(level_scene)
	if pack_err != OK:
		push_error("Failed to pack scene: %d" % pack_err)
		get_tree().quit(1)
		return

	var save_err = ResourceSaver.save(packed_scene, "res://levels/HarborPierLevel.tscn")
	if save_err != OK:
		push_error("Failed to save scene: %d" % save_err)
		get_tree().quit(1)
		return

	print("Successfully generated and saved res://levels/HarborPierLevel.tscn!")
	get_tree().quit(0)


func _set_owner_recursive(node: Node, new_owner: Node) -> void:
	for child in node.get_children():
		child.owner = new_owner
		_set_owner_recursive(child, new_owner)
