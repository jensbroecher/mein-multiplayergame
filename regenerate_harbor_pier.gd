# regenerate_harbor_pier.gd
# Regenerates levels/HarborPierLevel.tscn with the extended harbor circuit,
# elevated skyway viaduct, solid dock platforms, gapless corner junctions,
# 3D curve path, and checkpoints.
extends Node

const PortKit = preload("res://PortKit.gd")
const ShipKit = preload("res://ShipKit.gd")
const PropKit = preload("res://PropKit.gd")

func _ready() -> void:
	print("=== Regenerating Harbor Pier Level ===")
	
	var level_scene := Node3D.new()
	level_scene.name = "HarborPierLevel"
	
	var level_script: Script = load("res://levels/Level.gd")
	level_scene.set_script(level_script)

	# 1. Sky, sun and haze: a clear late afternoon (the weather controller's overcast washed it all out).
	_build_sky(level_scene)

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
		[Vector3(0, -0.6, -10), Vector3(0, 0.6, 10), Vector3(185, 5.55, -10.0)],# 8 Viaduct Incline mid
		[Vector3(0, -0.2, -10), Vector3(0, 0, 10), Vector3(185, 7.55, 10.0)], # 9 High Skyway entry
		[Vector3(0, 0, -10), Vector3(0, 0, 10), Vector3(185, 7.55, 30.0)],    # 10 High Skyway midpoint
		[Vector3(0, 0, -10), Vector3(0, -0.2, 10), Vector3(185, 7.55, 50.0)], # 11 High Skyway exit
		[Vector3(0, 0.6, -10), Vector3(0, -0.6, 10), Vector3(185, 5.55, 70.0)],# 12 Viaduct Descent mid
		[Vector3(0, 0.2, -8), Vector3(0, 0, 8), Vector3(185, 3.55, 95.0)],    # 13 Viaduct Landing / SE entry
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
		[Vector3(8, 0, 0), Vector3(-8, 0.35, 0), Vector3(-85, 3.55, 125)],     # 25 Jump 2 Takeoff ramp
		[Vector3(5, -0.35, 0), Vector3(-5, -0.35, 0), Vector3(-105, 5.4, 125)],# 26 Jump 2 Apex in air
		[Vector3(6, 0.35, 0), Vector3(-8, 0, 0), Vector3(-127, 3.55, 125)],   # 27 Jump 2 Landing ramp
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
	finish_line.rotation_degrees = Vector3(0, -90, 0)
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
		["Checkpoint_1", Vector3(185.0, 3.55, -55.0), 180.0],  # East Pier approach to elevated viaduct (traveling South)
		["Checkpoint_2", Vector3(145.0, 3.55, 125.0), 90.0],   # South Pier after viaduct descent (traveling West)
		["Checkpoint_3", Vector3(20.0, 3.55, 35.0), 90.0],     # Inner Basin Cross-Channel Bridge (traveling West)
		["Checkpoint_4", Vector3(-175.0, 3.55, 40.0), 0.0],    # West Pier after Jump 2 runway (traveling North)
	]

	var cp_node_paths: Array[NodePath] = []
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
			["BoostPad_Start", Vector3(20.0, 3.6, -95.0), -90.0],
			["BoostPad_AfterJumpE", Vector3(185.0, 3.6, -78.9), 180.0],
			["BoostPad_Skyway", Vector3(185.0, 7.60, 30.0), 180.0],
			["BoostPad_InnerBridge", Vector3(20.0, 3.6, 35.0), 90.0],
			["BoostPad_SouthPier", Vector3(-62.0, 3.6, 125.0), 90.0],
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

	# 10. The port round the circuit: buildings, cargo, quay furniture, the harbour's shores and its city.
	_build_scenery(level_scene, tg)

	# 11. Save Scene
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


# ======================================================================================
#  Sky, sun and haze
# ======================================================================================

## The haze along the horizon, the fog's colour and the far shore's: warm, the sun being low.
const HAZE := Color(0.80, 0.77, 0.70)
## Depth fog: clear over the harbour, the far shore and the sea's horizon hazed.
const FOG := Vector2(320.0, 1900.0)

func _build_sky(level_scene: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://sky_tropical_cumulus.gdshader")
	sm.set_shader_parameter("sky_top", Color(0.19, 0.40, 0.74))
	sm.set_shader_parameter("sky_horizon", Color(0.80, 0.81, 0.80))
	sm.set_shader_parameter("ground_horizon", HAZE)
	sm.set_shader_parameter("ground_bottom", Color(0.10, 0.20, 0.22))
	sm.set_shader_parameter("sky_curve", 0.34)
	sm.set_shader_parameter("horizon_haze", HAZE)
	sm.set_shader_parameter("haze_strength", 0.7)
	sm.set_shader_parameter("haze_height", 0.15)
	sm.set_shader_parameter("sun_tint", Color(1.0, 0.90, 0.74))
	sm.set_shader_parameter("sun_disc_degrees", 1.1)
	sm.set_shader_parameter("sun_glow", 0.55)
	sm.set_shader_parameter("sun_horizon_tint", Color(1.0, 0.76, 0.50))
	sm.set_shader_parameter("sun_horizon_glow", 0.35)
	sm.set_shader_parameter("sun_horizon_height", 0.24)
	sm.set_shader_parameter("cloud_lit", Color(1.0, 0.94, 0.84))
	sm.set_shader_parameter("cloud_shade", Color(0.50, 0.54, 0.64))
	sm.set_shader_parameter("cloud_coverage", 0.40)
	sm.set_shader_parameter("cloud_opacity", 0.94)
	sm.set_shader_parameter("cloud_scale", 1.8)
	sm.set_shader_parameter("wind_dir", Vector2(0.82, 0.57))
	sm.set_shader_parameter("cloud_seed", 63.1)
	sky.sky_material = _save_res(sm, "sky_mat")
	env.sky = _save_res(sky, "sky")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_bloom = 0.06
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = HAZE
	env.fog_sun_scatter = 0.25
	env.fog_density = 1.0
	env.fog_depth_begin = FOG.x
	env.fog_depth_end = FOG.y
	env.fog_depth_curve = 1.3
	env.fog_sky_affect = 0.05
	env.fog_aerial_perspective = 0.3
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = _save_res(env, "env")
	level_scene.add_child(we)
	we.owner = level_scene
	# Low in the west-south-west at 17:24: behind the grid on the start straight, glittering down the basin.
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = Vector3(-24.0, -67.5, 0.0)
	sun.light_color = Color(1.0, 0.88, 0.72)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 320.0
	level_scene.add_child(sun)
	sun.owner = level_scene


const RES_PREFIX := "harbor_"

func _save_res(res: Resource, res_name: String) -> Resource:
	var path := "res://generated/" + RES_PREFIX + res_name + ".res"
	res.take_over_path(path)
	ResourceSaver.save(res, path)
	return load(path)


# ======================================================================================
#  The port: what stands round the circuit
# ======================================================================================
# Everything here is under "PortScenery" (no track word in any name: PlayerCart counts "harbor", "pier", "deck", ...
# as road, and DressingColliders skips any mesh with "pier" in its path, so nothing here is made solid by it: every
# prop gets its own colliders). People-sized things are built at life size in PortKit and grown by PROP_SCALE, like
# Bloombay's seafront.

const PROP_SCALE := 1.6
const DECK_Y := 3.55
const WATER_Y := 1.55

var _decks: Array = []      # [Rect2 in x-z, name]: every surface a cart drives on at quay level
var _rails: Array = []      # Rect2: the crash barriers and the skyway's rails, in plan
var _junctions: Array = []  # Vector2: the corner blocks' middles (the racing line cuts their inside)
var _ramps: Array = []      # Rect2: the jump ramps
var _keep_clear: Array = [] # [Vector2, radius]: gates, boost pads, the grid
var _bridge_boxes: Array[AABB] = []  # the steel channel bridges' decks (BridgeRumble)
var _mats := {}


func _build_scenery(level_scene: Node3D, tg: Node3D) -> void:
	_read_quays(tg, level_scene)
	var root := Node3D.new()
	root.name = "PortScenery"
	# The Detail Level scales the trees, the armour and the props' draw distances (High is what's built here).
	root.set_script(load("res://HarborDetail.gd"))
	level_scene.add_child(root)
	# The steel bridges drum under the wheels (BridgeRumble.gd, synthesised: no recording).
	var rumble := Node3D.new()
	rumble.name = "BridgeRumble"
	rumble.set_script(load("res://BridgeRumble.gd"))
	rumble.set("decks", _bridge_boxes)
	root.add_child(rumble)
	print("  bridge rumble: %d steel decks" % _bridge_boxes.size())
	_build_wharf_buildings(root)
	_build_wharf_cargo(root)
	_build_quay_furniture(root)
	_build_shores(root)
	_build_breakwaters(root)
	_build_terminal(root)
	_build_marina(root)
	_build_boats(root)
	_build_gulls(root)
	_build_city(root)
	_set_owner_recursive(root, level_scene)
	root.owner = level_scene


## The quays as TerrainGenerator built them: deck rectangles, barriers, corner blocks and ramps, read off its bodies
## (nothing is in the tree yet, so transforms are composed by hand: HarborPiers and TerrainGenerator are at the origin).
func _read_quays(tg: Node3D, level_scene: Node3D) -> void:
	var piers := tg.get_node("HarborPiers")
	for c in piers.get_children():
		var nm := String(c.name)
		if not (c is StaticBody3D):
			continue
		var box := _body_box(c as StaticBody3D)
		if box.size == Vector3.ZERO:
			continue
		var r := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
		if nm.begins_with("Rail_") or nm.begins_with("Viaduct_Rail") or nm.contains("_Rail"):
			_rails.append(r)
		elif nm.begins_with("HarborRamp_"):
			_ramps.append(r)
		elif nm.begins_with("HarborPier_") or nm.begins_with("Junction_") or nm.begins_with("Platform_") \
				or nm.begins_with("HarborBridge_") or nm == "Viaduct_ContinuousDeck":
			if nm.contains("Pillar"):
				continue
			_decks.append([r, nm])
			if nm.begins_with("HarborBridge_"):
				_bridge_boxes.append(box)
	for c2 in piers.get_children():
		if String(c2.name).begins_with("Junction_") and String(c2.name).ends_with("_Hull"):
			var mi := c2 as MeshInstance3D
			_junctions.append(Vector2(mi.position.x, mi.position.z))
	# Gates, pads and the grid: nothing stands near them.
	for n in level_scene.get_children():
		if n.name == "FinishLine":
			_keep_clear.append([Vector2(n.position.x, n.position.z), 12.0])
			_keep_clear.append([Vector2(n.position.x - 12.0, n.position.z), 12.0])
		elif n.name == "Checkpoints" or n.name == "BoostPads":
			for g in n.get_children():
				_keep_clear.append([Vector2(g.position.x, g.position.z), 10.0 if n.name == "Checkpoints" else 5.0])
	print("  quays: %d decks, %d barriers, %d corners, %d ramps" % [_decks.size(), _rails.size(), _junctions.size(), _ramps.size()])


## A body's box in its parent's frame: its first mesh's AABB through the body's transform.
func _body_box(body: StaticBody3D) -> AABB:
	for ch in body.get_children():
		if ch is MeshInstance3D and (ch as MeshInstance3D).mesh:
			return body.transform * ((ch as MeshInstance3D).transform * (ch as MeshInstance3D).mesh.get_aabb())
	for ch2 in body.get_children():
		if ch2 is CollisionShape3D and (ch2 as CollisionShape3D).shape is BoxShape3D:
			var sz: Vector3 = ((ch2 as CollisionShape3D).shape as BoxShape3D).size
			return body.transform * ((ch2 as CollisionShape3D).transform * AABB(-sz * 0.5, sz))
	return AABB()


func _on_deck(p: Vector2, grow := 0.0) -> bool:
	for d in _decks:
		if (d[0] as Rect2).grow(grow).has_point(p):
			return true
	return false


func _near_rail(p: Vector2, r: float) -> bool:
	for rr in _rails:
		if (rr as Rect2).grow(r).has_point(p):
			return true
	return false


func _clear_spot(p: Vector2) -> bool:
	for j in _junctions:
		if absf(p.x - j.x) < 17.0 and absf(p.y - j.y) < 17.0:
			return false
	for r in _ramps:
		if (r as Rect2).grow(7.0).has_point(p):
			return false
	for k in _keep_clear:
		if p.distance_to(k[0]) < float(k[1]):
			return false
	return true


## The free quay edges: runs along every deck's sides where water lies beyond, with no barrier on it and away from
## corners, ramps, gates and pads. Each run is [start, end, outward normal] in plan, on the edge itself.
func _free_edges() -> Array:
	var runs: Array = []
	for d in _decks:
		var r: Rect2 = d[0]
		if String(d[1]).begins_with("HarborBridge_"):
			continue
		var sides := [
			[Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), Vector2(0, -1)],
			[Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), Vector2(0, 1)],
			[Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.end.y), Vector2(-1, 0)],
			[Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y), Vector2(1, 0)],
		]
		for sd in sides:
			var a: Vector2 = sd[0]
			var b: Vector2 = sd[1]
			var n: Vector2 = sd[2]
			var length: float = a.distance_to(b)
			var dir: Vector2 = (b - a) / length
			var run_start := -1.0
			var t := 0.0
			while t <= length:
				var q: Vector2 = a + dir * t
				var free: bool = not _on_deck(q + n * 1.5) and not _near_rail(q, 1.2) and _clear_spot(q)
				if free and run_start < 0.0:
					run_start = t
				if (not free or t + 1.0 > length) and run_start >= 0.0:
					var t_end: float = t if not free else t
					if t_end - run_start >= 6.0:
						runs.append([a + dir * run_start, a + dir * t_end, n])
					run_start = -1.0
				t += 1.0
	return runs


## Saved materials of a kit, so every mesh of the level shares them.
func _commit_kit(pk: PropKit, kit: Dictionary, res_name: String) -> ArrayMesh:
	var mesh := PortKit.commit_port(pk, kit)
	for i in range(mesh.get_surface_count()):
		var m := mesh.surface_get_material(i)
		var key := ""
		for k in PortKit._port_mats.keys():
			if PortKit._port_mats[k] == m:
				key = k
		if key != "":
			if not _mats.has(key):
				_mats[key] = _save_res(m, "mat_" + key)
			mesh.surface_set_material(i, _mats[key])
	return _save_res(mesh, res_name) as ArrayMesh


func _mesh_node(parent: Node3D, node_name: String, mesh: Mesh, xf := Transform3D.IDENTITY, shadows := true, range_end := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.transform = xf
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if range_end > 0.0:
		mi.visibility_range_end = range_end
		mi.visibility_range_end_margin = range_end * 0.1
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		# HarborDetail.gd scales this by the Detail Level.
		mi.set_meta(&"base_range", range_end)
	parent.add_child(mi)
	return mi


## A static body of shapes: [shape, transform] pairs (world).
func _solid(parent: Node3D, node_name: String, shapes: Array, surface := "") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	if surface != "":
		body.set_meta("surface", surface)
	parent.add_child(body)
	for sh in shapes:
		var cs := CollisionShape3D.new()
		cs.shape = sh[0]
		cs.transform = sh[1]
		body.add_child(cs)
	return body


func _box_shape(size: Vector3, xf: Transform3D) -> Array:
	var b := BoxShape3D.new()
	b.size = size
	return [b, xf]


func _cyl_shape(r: float, h: float, base: Vector3) -> Array:
	var c := CylinderShape3D.new()
	c.radius = r
	c.height = h
	return [c, Transform3D(Basis(), base + Vector3(0, h * 0.5, 0))]


func _fit_pixel(text: String, font_size: int, pixel: float, max_w: float) -> float:
	if max_w <= 0.0:
		return pixel
	var w: float = ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if w * pixel <= max_w:
		return pixel
	return max_w / maxf(w, 1.0)


## Letters for a prop's signs: `labels` are [text, position, outward normal, cap height, colour, board width] in the
## kit's own units, placed through the prop's transform (`xf`, PROP_SCALE in it).
func _labels(parent: Node3D, labels: Array, xf: Transform3D, scale := PROP_SCALE) -> void:
	for l in labels:
		var lab := Label3D.new()
		lab.text = l[0]
		lab.font_size = 64
		lab.pixel_size = _fit_pixel(l[0], 64, float(l[3]) * scale / 44.8, float(l[5]) * scale if l.size() > 5 else 0.0)
		lab.modulate = l[4]
		lab.outline_size = 0
		lab.double_sided = false
		# Cut, not blended: blended letters sorted against the water and the glass and lost pieces of themselves.
		lab.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		var n: Vector3 = xf.basis.orthonormalized() * (l[2] as Vector3)
		lab.transform = Transform3D(Basis.looking_at(-n, Vector3.UP), xf * (l[1] as Vector3))
		parent.add_child(lab)


# --------------------------------------------------------------------------------------
#  The wharves' buildings and cargo
# --------------------------------------------------------------------------------------

## [middle (x, z), yaw, width, depth, eave height (life size), doors, sign, variant]
const WAREHOUSES := [
	[Vector2(-135.0, -118.0), 0.0, 14.0, 10.0, 9.0, 2, "SHED 1", 0],
	[Vector2(-85.0, -118.0), 0.0, 14.0, 10.0, 9.0, 2, "SHED 2", 1],
	[Vector2(-30.0, -118.0), 0.0, 14.0, 10.0, 9.0, 2, "SHED 3", 0],
	[Vector2(25.0, -118.0), 0.0, 14.0, 10.0, 9.0, 2, "SHED 4", 1],
	[Vector2(127.0, 44.0), -PI * 0.5, 13.0, 9.0, 8.5, 2, "BAY CARGO", 2],
	[Vector2(127.0, 71.0), -PI * 0.5, 13.0, 9.0, 8.5, 2, "COLD STORE", 2],
	[Vector2(-5.0, -36.0), 0.0, 14.0, 7.5, 7.5, 2, "FISH MARKET", 3],
]
const WAREHOUSE_LOOKS := [
	[Color(0.36, 0.44, 0.48), PortKit.BRICK_RED, PortKit.IRON_GREY],
	[Color(0.30, 0.42, 0.30), PortKit.BRICK_DARK, Color(0.46, 0.30, 0.24)],
	[Color(0.58, 0.18, 0.14), Color(0.62, 0.40, 0.28), Color(0.40, 0.44, 0.46)],
	[Color(0.22, 0.34, 0.52), Color(0.66, 0.56, 0.44), Color(0.30, 0.42, 0.46)],
]

func _build_wharf_buildings(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Sheds"
	root.add_child(node)
	var meshes := {}
	var shapes: Array = []
	for i in range(WAREHOUSES.size()):
		var w: Array = WAREHOUSES[i]
		var key := "%d_%d_%d_%d" % [int(w[2] * 10), int(w[3] * 10), int(w[4] * 10), int(w[7])]
		var labels: Array = []
		if not meshes.has(key):
			var pk := PortKit.new_port_kit(1.0)
			var kit := {}
			var look: Array = WAREHOUSE_LOOKS[int(w[7])]
			PortKit.warehouse(pk, kit, w[2], w[3], w[4], w[5], labels, "X", look[0], look[1], true, look[2])
			meshes[key] = _commit_kit(pk, kit, "shed_" + key)
		else:
			# The sign's place is the same on every copy: work it out without building.
			var pk2 := PortKit.new_port_kit(1.0)
			PortKit.warehouse(pk2, {}, w[2], w[3], w[4], w[5], labels, "X")
		for l in labels:
			l[0] = w[6]
		var c: Vector2 = w[0]
		var xf := Transform3D(Basis(Vector3.UP, w[1]).scaled(Vector3.ONE * PROP_SCALE), Vector3(c.x, DECK_Y, c.y))
		_mesh_node(node, "Shed_%d" % i, meshes[key], xf, true, 700.0)
		_labels(node, labels, xf)
		var size := Vector3(w[2], w[4], w[3]) * PROP_SCALE
		shapes.append(_box_shape(size, Transform3D(Basis(Vector3.UP, w[1]), Vector3(c.x, DECK_Y + size.y * 0.5, c.y))))
	_solid(node, "ShedWalls", shapes)


## Container stacks on the wharves: [first box's floor middle (x, z), yaw, along, across, levels, 20ft]
const STACKS := [
	[Vector2(-110.0, -129.0), 0.0, 1, 3, 3, false],
	[Vector2(-63.0, -129.0), 0.0, 1, 3, 2, false],
	[Vector2(-47.5, -129.0), 0.0, 1, 3, 3, true],
	[Vector2(-3.0, -129.0), 0.0, 1, 3, 3, false],
	[Vector2(43.5, -129.0), 0.0, 1, 3, 2, true],
	[Vector2(-153.5, -129.0), 0.0, 1, 2, 1, true],
	[Vector2(108.0, 35.0), -PI * 0.5, 1, 2, 3, false],
	[Vector2(108.0, 61.0), -PI * 0.5, 1, 2, 2, false],
	[Vector2(108.0, 82.0), -PI * 0.5, 1, 2, 3, true],
	[Vector2(-84.5, 25.0), 0.0, 2, 4, 3, false],
	[Vector2(-84.5, 52.0), 0.0, 2, 4, 2, false],
]

func _build_wharf_cargo(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Cargo"
	root.add_child(node)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2207
	var shapes: Array = []
	for i in range(STACKS.size()):
		var st: Array = STACKS[i]
		var pk := PortKit.new_port_kit(PROP_SCALE)
		var kit := {}
		var c: Vector2 = st[0]
		var origin := Vector3(c.x, DECK_Y, c.y)
		# The stack in its own frame at the origin, the node placed: each stack culls by itself.
		var foot: Vector2 = PortKit.stack(pk, kit, rng, Vector3.ZERO, 0.0, st[2], st[3], st[4], st[5])
		var mesh := _commit_kit(pk, kit, "cargo_%d" % i)
		var basis := Basis(Vector3.UP, st[1])
		_mesh_node(node, "Stack_%d" % i, mesh, Transform3D(basis, origin), true, 600.0)
		var size := Vector3(foot.x, float(st[4]) * PortKit.BOX_40.y, foot.y) * PROP_SCALE
		var box_size: Vector3 = (PortKit.BOX_20 if st[5] else PortKit.BOX_40) * PROP_SCALE
		var mid := Vector3(size.x * 0.5 - box_size.x * 0.5, size.y * 0.5, size.z * 0.5 - box_size.z * 0.5)
		shapes.append(_box_shape(size, Transform3D(basis, origin + basis * mid)))
	_solid(node, "CargoSolid", shapes)


# --------------------------------------------------------------------------------------
#  Quay furniture along the free edges
# --------------------------------------------------------------------------------------

const BOLLARD_EVERY := 14.0
const FENDER_EVERY := 9.0
const LADDER_EVERY := 70.0
const MAST_EVERY := 52.0

func _build_quay_furniture(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "QuayFurniture"
	root.add_child(node)
	var runs := _free_edges()
	var pk := PortKit.new_port_kit(PROP_SCALE)
	var kit := {}
	var shapes: Array = []
	var counts := [0, 0, 0, 0]
	for run in runs:
		var a: Vector2 = run[0]
		var b: Vector2 = run[1]
		var n: Vector2 = run[2]
		var length: float = a.distance_to(b)
		var dir: Vector2 = (b - a) / length
		var out := Vector3(n.x, 0, n.y)
		var along := Vector3(dir.x, 0, dir.y)
		# Bollards, set back from the edge, evenly over the run.
		var nb: int = int(floor(length / BOLLARD_EVERY))
		for i in range(nb):
			var t: float = (float(i) + 0.5) * length / float(maxi(nb, 1))
			var q: Vector2 = a + dir * t - n * 0.8
			var p := Vector3(q.x, DECK_Y, q.y)
			pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * PROP_SCALE), p))
			PortKit.bollard(pk, kit, Vector3.ZERO, PortKit.BOLLARD_BLACK if i % 5 != 2 else PortKit.SAFETY_YELLOW)
			shapes.append(_cyl_shape(0.44, 1.0, p))
			counts[0] += 1
		# Rubber fenders on the wall.
		var nf: int = int(floor(length / FENDER_EVERY))
		for i in range(nf):
			var t: float = (float(i) + 0.5) * length / float(maxi(nf, 1))
			var q: Vector2 = a + dir * t
			pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * PROP_SCALE), Vector3(q.x, DECK_Y - 0.35, q.y)))
			PortKit.wall_fender(pk, kit, Vector3.ZERO, out, 1.2)
			counts[1] += 1
		# Ladders, between the bollards.
		var nl: int = int(floor(length / LADDER_EVERY))
		for i in range(nl):
			var t: float = (float(i) + 0.5) * length / float(maxi(nl, 1)) + BOLLARD_EVERY * 0.5
			if t > length - 2.0:
				continue
			var q: Vector2 = a + dir * t
			pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * PROP_SCALE), Vector3(q.x, DECK_Y, q.y)))
			PortKit.quay_ladder(pk, kit, Vector3.ZERO, out, 2.2)
			var lb := Basis(Vector3(-out.z, 0, out.x), Vector3.UP, out)
			shapes.append(_box_shape(Vector3(0.9, 1.5, 0.9), Transform3D(lb, Vector3(q.x, DECK_Y + 0.75, q.y) - out * 0.2)))
			counts[2] += 1
		# Floodlight masts, looking back over the quay.
		var nm: int = int(floor(length / MAST_EVERY))
		for i in range(nm):
			var t: float = (float(i) + 0.5) * length / float(maxi(nm, 1)) + 3.5
			if t > length - 2.0:
				continue
			var q: Vector2 = a + dir * t - n * 1.1
			var p := Vector3(q.x, DECK_Y, q.y)
			pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * PROP_SCALE), p))
			PortKit.light_mast(pk, kit, Vector3.ZERO, -out, 9.0)
			shapes.append(_cyl_shape(0.6, 0.5, p))
			shapes.append(_cyl_shape(0.2, 14.0, p))
			counts[3] += 1
	var mesh := _commit_kit(pk, kit, "quay_furniture")
	_mesh_node(node, "Furniture", mesh)
	_solid(node, "FurnitureSolid", shapes)
	print("  quay furniture: %d edge runs, %d bollards, %d fenders, %d ladders, %d masts" % [runs.size(), counts[0], counts[1], counts[2], counts[3]])


# --------------------------------------------------------------------------------------
#  The shores: Bloombay's mainland to the north, the old town's hill to the west, the container terminal to the east
# --------------------------------------------------------------------------------------
# The land is everything north of the north quay (z < QUAY_N_Z), west of the west quay down to WEST_S_Z, and east of
# the terminal's quay down to EAST_S_Z; the rest is sea, the harbour opening to the south between the breakwaters.
# Quays are vertical concrete walls; the land behind them is flat for a while (the quaysides, the terminal's yard)
# and then rises into the city's hills. One heightfield on a grid whose lines run along every quay, cut into tiles.

const QUAY_N_Z := -142.0
const QUAY_W_X := -352.0
const QUAY_E_X := 268.0
const WEST_S_Z := 205.0
const EAST_S_Z := 150.0
const LAND_EDGE := 2300.0
const SEABED_Y := -7.5
const LAND_TILE := 450.0

var _hills: FastNoiseLite
var _hills_fine: FastNoiseLite


## Metres inland (negative: out at sea).
func _land_d(x: float, z: float) -> float:
	var dn := QUAY_N_Z - z
	var dw := minf(QUAY_W_X - x, WEST_S_Z - z)
	var de := minf(x - QUAY_E_X, EAST_S_Z - z)
	return maxf(dn, maxf(dw, de))


## How far the flat quayside runs inland before the ground rises: the old town climbs straight from its quay, the
## terminal's yard is wide.
func _flat_run(x: float, z: float) -> float:
	var w_w: float = smoothstep(-330.0, -430.0, x)
	var w_e: float = smoothstep(250.0, 380.0, x)
	var base: float = lerpf(170.0, 45.0, w_w)
	return lerpf(base, 560.0, w_e * (1.0 - smoothstep(900.0, 1100.0, x)))


func _land_h(x: float, z: float) -> float:
	var d := _land_d(x, z)
	if d < 0.0:
		return SEABED_Y
	var u: float = d - _flat_run(x, z)
	if u <= 0.0:
		return DECK_Y
	var ue: float = u * u / (u + 80.0)
	var top: float = 95.0 + 55.0 * _hills.get_noise_2d(x * 0.6, z * 0.6)
	var h: float = top * (1.0 - exp(-ue / 520.0)) + ue * 0.015
	h += _hills.get_noise_2d(x, z) * 38.0 * clampf(ue / 400.0, 0.0, 1.0)
	h += _hills_fine.get_noise_2d(x, z) * 6.0 * clampf(ue / 150.0, 0.0, 1.0)
	return DECK_Y + maxf(h, 0.0)


## The town: 1 where streets and buildings are, falling to 0 in the countryside.
func _urban(x: float, z: float) -> float:
	var d := _land_d(x, z)
	if d < 0.0:
		return 0.0
	var u: float = d - _flat_run(x, z)
	if x > QUAY_E_X + 40.0 and z > QUAY_N_Z - 40.0:
		return 0.0  # the terminal: its own yard
	var reach: float = 520.0
	if x < QUAY_W_X:
		reach = 300.0
	var city: float = 1.0 - smoothstep(reach * 0.7, reach, u)
	city *= 1.0 - smoothstep(1000.0, 1300.0, absf(x - 0.0))
	return clampf(city, 0.0, 1.0)


func _axis(lo: float, hi: float, fine_lo: float, fine_hi: float, fine: float, coarse: float, extra: Array) -> PackedFloat64Array:
	var vals: Array = []
	var v := lo
	while v < fine_lo:
		vals.append(v)
		v += coarse
	v = fine_lo
	while v < fine_hi:
		vals.append(v)
		v += fine
	v = fine_hi
	while v <= hi + 0.01:
		vals.append(v)
		v += coarse
	vals.append_array(extra)
	vals.sort()
	var out := PackedFloat64Array()
	for x in vals:
		if out.is_empty() or float(x) - out[out.size() - 1] > 1.5:
			out.append(float(x))
	return out


func _build_shores(root: Node3D) -> void:
	_hills = FastNoiseLite.new()
	_hills.seed = 811
	_hills.frequency = 0.0016
	_hills.fractal_octaves = 4
	_hills_fine = FastNoiseLite.new()
	_hills_fine.seed = 812
	_hills_fine.frequency = 0.012
	_hills_fine.fractal_octaves = 3
	var node := Node3D.new()
	node.name = "Shores"
	root.add_child(node)
	var xs := _axis(-LAND_EDGE, LAND_EDGE, -1000.0, 1100.0, 10.0, 50.0, [QUAY_W_X, QUAY_E_X, 300.0])
	var zs := _axis(-LAND_EDGE, 600.0, -1200.0, 260.0, 10.0, 50.0, [QUAY_N_Z, WEST_S_Z, EAST_S_Z])
	var nx := xs.size()
	var nz := zs.size()
	var hts := PackedFloat32Array()
	hts.resize(nx * nz)
	for j in range(nz):
		for i in range(nx):
			hts[j * nx + i] = _land_h(xs[i], zs[j])
	var mat := _quay_land_mat()
	var tiles := {}
	for j in range(nz - 1):
		for i in range(nx - 1):
			var cx: float = (xs[i] + xs[i + 1]) * 0.5
			var cz: float = (zs[j] + zs[j + 1]) * 0.5
			if _land_d(cx, cz) < 0.0:
				continue
			var key := Vector2i(int(floor(cx / LAND_TILE)), int(floor(cz / LAND_TILE)))
			if not tiles.has(key):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				tiles[key] = st
			var stt: SurfaceTool = tiles[key]
			var c := [Vector3(xs[i], hts[j * nx + i], zs[j]), Vector3(xs[i + 1], hts[j * nx + i + 1], zs[j]),
					Vector3(xs[i + 1], hts[(j + 1) * nx + i + 1], zs[j + 1]), Vector3(xs[i], hts[(j + 1) * nx + i], zs[j + 1])]
			# Split along the diagonal joining the closer heights (no sawtooth on slopes).
			var tris: Array = [[0, 1, 2], [0, 2, 3]] if absf(c[0].y - c[2].y) <= absf(c[1].y - c[3].y) else [[0, 1, 3], [1, 2, 3]]
			for t in tris:
				var a: Vector3 = c[t[0]]
				var b: Vector3 = c[t[1]]
				var e: Vector3 = c[t[2]]
				var nrm := (e - a).cross(b - a).normalized()
				if nrm.y < 0.0:
					var tmp := b
					b = e
					e = tmp
					nrm = -nrm
				for v in [a, b, e]:
					stt.set_color(_land_colour(v, nrm))
					stt.set_normal(nrm)
					stt.add_vertex(v)
	var count := 0
	for key in tiles.keys():
		var stt: SurfaceTool = tiles[key]
		stt.index()
		var mesh := stt.commit()
		mesh.surface_set_material(0, mat)
		_mesh_node(node, "Land_%d_%d" % [key.x, key.y], _save_res(mesh, "land_%d_%d" % [key.x + 10, key.y + 10]), Transform3D.IDENTITY, true)
		count += 1
	# The quay walls down to the bed, in the quays' own concrete.
	var walls := SurfaceTool.new()
	walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	for seg in [[Vector2(QUAY_W_X, QUAY_N_Z), Vector2(QUAY_E_X, QUAY_N_Z), Vector2(0, 1)],
			[Vector2(QUAY_W_X, QUAY_N_Z), Vector2(QUAY_W_X, WEST_S_Z), Vector2(1, 0)],
			[Vector2(QUAY_E_X, QUAY_N_Z), Vector2(QUAY_E_X, EAST_S_Z), Vector2(-1, 0)],
			[Vector2(QUAY_E_X, EAST_S_Z), Vector2(300.0, EAST_S_Z), Vector2(0, 1)]]:
		var a2: Vector2 = seg[0]
		var b2: Vector2 = seg[1]
		var n2: Vector2 = seg[2]
		var out := Vector3(n2.x, 0, n2.y)
		var p := [Vector3(a2.x, SEABED_Y - 1.0, a2.y), Vector3(b2.x, SEABED_Y - 1.0, b2.y), Vector3(b2.x, DECK_Y, b2.y), Vector3(a2.x, DECK_Y, a2.y)]
		var tri_sets := [[p[0], p[1], p[2]], [p[0], p[2], p[3]]]
		for tset in tri_sets:
			var ta: Vector3 = tset[0]
			var tb: Vector3 = tset[1]
			var tc: Vector3 = tset[2]
			if (tc - ta).cross(tb - ta).dot(out) < 0.0:
				var tt := tb
				tb = tc
				tc = tt
			for v2 in [ta, tb, tc]:
				walls.set_normal(out)
				walls.add_vertex(v2)
	var wmesh := walls.commit()
	wmesh.surface_set_material(0, _quay_mat(0))
	_mesh_node(node, "QuayWalls", _save_res(wmesh, "quay_walls"))
	# Ground under a cart that gets ashore: the flat quaysides and the terminal's yard (the hills are out of reach).
	var shapes: Array = []
	shapes.append(_box_shape(Vector3(QUAY_E_X - QUAY_W_X, 4.0, 160.0), Transform3D(Basis(), Vector3((QUAY_W_X + QUAY_E_X) * 0.5, DECK_Y - 2.0, QUAY_N_Z - 80.0))))
	shapes.append(_box_shape(Vector3(60.0, 4.0, WEST_S_Z - QUAY_N_Z), Transform3D(Basis(), Vector3(QUAY_W_X - 30.0, DECK_Y - 2.0, (QUAY_N_Z + WEST_S_Z) * 0.5))))
	shapes.append(_box_shape(Vector3(520.0, 4.0, EAST_S_Z - QUAY_N_Z), Transform3D(Basis(), Vector3(QUAY_E_X + 260.0, DECK_Y - 2.0, (QUAY_N_Z + EAST_S_Z) * 0.5))))
	_solid(node, "ShoreGround", shapes, "asphalt")
	# Furniture along the mainland's quays.
	_shore_furniture(node)
	print("  shores: %d land tiles (%d x %d grid)" % [count, nx, nz])


func _land_colour(v: Vector3, n: Vector3) -> Color:
	var d := _land_d(v.x, v.z)
	var u: float = d - _flat_run(v.x, v.z)
	var paved := 0.0
	if u < 6.0:
		paved = 1.0
	else:
		paved = clampf(_urban(v.x, v.z) * 1.3 - 0.15 + 0.4 * _hills_fine.get_noise_2d(v.x * 0.5, v.z * 0.5), 0.0, 1.0)
	# Alpha: 0 grown, 0.5 paved in asphalt, 1 paved in concrete slabs (the terminal's yard and the quaysides).
	var a: float = paved * 0.5
	if u < 6.0 and (v.x > QUAY_E_X - 1.0 or _land_d(v.x, v.z) < 26.0):
		a = 1.0
	return Color(1, 1, 1, a)


func _quay_mat(mode: int) -> ShaderMaterial:
	var key := "quay_mode_%d" % mode
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://harbor_quay.gdshader")
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("concrete_tex", load("res://materials/concrete.png"))
	m.set_shader_parameter("concrete_nrm", load("res://materials/concrete_normal.png"))
	m.set_shader_parameter("water_y", WATER_Y)
	m.set_shader_parameter("deck_y", DECK_Y)
	_mats[key] = _save_res(m, key)
	return _mats[key]


func _quay_land_mat() -> ShaderMaterial:
	return _quay_mat(5)


## Bollards, fenders and ladders along the mainland's quays, as on the piers.
func _shore_furniture(node: Node3D) -> void:
	var pk := PortKit.new_port_kit(PROP_SCALE)
	var kit := {}
	var shapes: Array = []
	for seg in [[Vector2(QUAY_W_X + 6.0, QUAY_N_Z), Vector2(QUAY_E_X - 6.0, QUAY_N_Z), Vector2(0, 1)],
			[Vector2(QUAY_E_X, QUAY_N_Z + 6.0), Vector2(QUAY_E_X, EAST_S_Z - 4.0), Vector2(-1, 0)]]:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var n: Vector2 = seg[2]
		var out := Vector3(n.x, 0, n.y)
		var length: float = a.distance_to(b)
		var dir: Vector2 = (b - a) / length
		var t := 4.0
		var k := 0
		while t < length:
			var q: Vector2 = a + dir * t
			pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * PROP_SCALE), Vector3(q.x, DECK_Y, q.y) - out * 0.8))
			PortKit.bollard(pk, kit, Vector3.ZERO)
			shapes.append(_cyl_shape(0.44, 1.0, Vector3(q.x, DECK_Y, q.y) - out * 0.8))
			pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * PROP_SCALE), Vector3(q.x + dir.x * 6.0, DECK_Y - 0.35, q.y + dir.y * 6.0)))
			PortKit.wall_fender(pk, kit, Vector3.ZERO, out, 1.6)
			if k % 6 == 3:
				pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * PROP_SCALE), Vector3(q.x + dir.x * 3.0, DECK_Y, q.y + dir.y * 3.0)))
				PortKit.quay_ladder(pk, kit, Vector3.ZERO, out, 2.2)
			k += 1
			t += 18.0
	_mesh_node(node, "ShoreFurniture", _commit_kit(pk, kit, "shore_furniture"), Transform3D.IDENTITY, true, 900.0)
	_solid(node, "ShoreFurnitureSolid", shapes)


# --------------------------------------------------------------------------------------
#  Breakwaters
# --------------------------------------------------------------------------------------
# Rubble mounds: the west breakwater runs from the old town's shore along the harbour's south side to its head by
# the entrance (a red light: port hand coming in), the east mole from the terminal's corner south and round to its
# own head (green). Each is a lumpy mound of granite, a crown wall on its seaward side over a walkway, tetrapods piled
# on the seaward slope and boulders on the harbour side. The same mound runs along the shores' southern edges outside
# the harbour.

const WEST_BREAKWATER := [Vector2(-1500.0, 211.0), Vector2(-700.0, 214.0), Vector2(QUAY_W_X - 20.0, 214.0), Vector2(140.0, 214.0)]
const EAST_MOLE := [Vector2(1500.0, 156.0), Vector2(600.0, 156.0), Vector2(304.0, 156.0), Vector2(304.0, 238.0), Vector2(220.0, 238.0)]
const MOUND_CREST := 6.4
const MOUND_HALF := 7.0

func _build_breakwaters(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Breakwaters"
	root.add_child(node)
	var rock := ShaderMaterial.new()
	rock.shader = load("res://granite_rock.gdshader")
	rock.set_shader_parameter("dust_color", Color(0.20, 0.23, 0.18))
	rock = _save_res(rock, "mat_mound_rock")
	var noise := FastNoiseLite.new()
	noise.seed = 77
	noise.frequency = 0.35
	noise.fractal_octaves = 3
	var tetra_xf: Array = []
	var boulder_xf: Array = []
	var shapes: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 6061
	var walls_pk := PortKit.new_port_kit(1.0)
	var walls_kit := {}
	for line_def in [[WEST_BREAKWATER, -1.0], [EAST_MOLE, 1.0]]:
		var line: Array = line_def[0]
		# Which side is the sea: south of the west breakwater (its left walking toward the head), east and south of
		# the mole (its right walking toward the head).
		var sea_side: float = line_def[1]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		# Walk the line in steps, a profile across at each.
		var pts: Array = []
		for k in range(line.size() - 1):
			var a: Vector2 = line[k]
			var b: Vector2 = line[k + 1]
			var n_steps: int = maxi(int(a.distance_to(b) / 3.0), 1)
			for i in range(n_steps):
				pts.append(a.lerp(b, float(i) / float(n_steps)))
		pts.append(line[line.size() - 1])
		# The profile: (lateral, height) from the harbour's toe to the sea's toe; lateral is to the left of travel.
		var prof := [Vector2(-MOUND_HALF - 16.0, SEABED_Y), Vector2(-MOUND_HALF - 6.0, WATER_Y - 1.0), Vector2(-MOUND_HALF - 1.5, MOUND_CREST - 1.8),
				Vector2(-MOUND_HALF + 0.5, MOUND_CREST - 1.2), Vector2(MOUND_HALF - 0.5, MOUND_CREST - 1.2), Vector2(MOUND_HALF + 2.0, MOUND_CREST - 1.5),
				Vector2(MOUND_HALF + 9.0, WATER_Y - 0.4), Vector2(MOUND_HALF + 22.0, SEABED_Y)]
		var rings: Array = []
		for i in range(pts.size()):
			var p: Vector2 = pts[i]
			var dir: Vector2 = ((pts[mini(i + 1, pts.size() - 1)] as Vector2) - (pts[maxi(i - 1, 0)] as Vector2)).normalized()
			var left := Vector2(dir.y, -dir.x)
			var ring: Array = []
			for pr in prof:
				# Profile x < 0 is the harbour side; `left` times sea_side points out to sea.
				var q: Vector2 = p + left * (pr.x * sea_side)
				var y: float = pr.y + noise.get_noise_2d(q.x, q.y) * 0.9 * (1.0 if pr.y > SEABED_Y + 0.1 else 0.0)
				ring.append(Vector3(q.x, y, q.y))
			rings.append(ring)
			# Armour along it, every couple of metres.
			if i % 2 == 0 and i > 0 and i < pts.size() - 1:
				for row in range(3):
					var lat2: float = MOUND_HALF + 2.5 + float(row) * 3.4 + rng.randf_range(-0.6, 0.6)
					var q2: Vector2 = p + left * (lat2 * sea_side) + dir * rng.randf_range(-1.0, 1.0)
					var y2: float = lerpf(MOUND_CREST - 1.2, WATER_Y - 0.6, float(row) / 2.6) + rng.randf_range(-0.3, 0.4)
					var basis := Basis(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized(), rng.randf() * TAU)
					tetra_xf.append(Transform3D(basis.scaled(Vector3.ONE * PROP_SCALE * rng.randf_range(0.9, 1.15)), Vector3(q2.x, y2, q2.y)))
				var lat3: float = -(MOUND_HALF + rng.randf_range(1.0, 4.5))
				var q3: Vector2 = p + left * (lat3 * sea_side)
				var sc: float = rng.randf_range(1.2, 2.4)
				boulder_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).rotated(Vector3.RIGHT, rng.randf_range(-0.3, 0.3)).scaled(Vector3(sc, sc * 0.7, sc * 1.1)),
						Vector3(q3.x, MOUND_CREST - 2.0 - (absf(lat3) - MOUND_HALF) * 0.45, q3.y)))
		for i in range(rings.size() - 1):
			var r0: Array = rings[i]
			var r1: Array = rings[i + 1]
			for k in range(prof.size() - 1):
				var quad := [r0[k], r0[k + 1], r1[k + 1], r1[k]]
				var nrm: Vector3 = ((quad[2] as Vector3) - (quad[0] as Vector3)).cross((quad[1] as Vector3) - (quad[0] as Vector3)).normalized()
				if nrm.y < 0.0:
					quad = [r0[k], r1[k], r1[k + 1], r0[k + 1]]
				for t in [[0, 1, 2], [0, 2, 3]]:
					var va: Vector3 = quad[t[0]]
					var vb: Vector3 = quad[t[1]]
					var vc: Vector3 = quad[t[2]]
					if (vc - va).cross(vb - va).y < 0.0:
						var tmp := vb
						vb = vc
						vc = tmp
					for v in [va, vb, vc]:
						st.set_color(Color(0.85 + 0.15 * noise.get_noise_2d(v.x * 3.0, v.z * 3.0), clampf((v.y - WATER_Y) / 2.5, 0.0, 1.0), 0, 1))
						st.add_vertex(v)
		st.index()
		st.generate_normals()
		var mesh := st.commit()
		mesh.surface_set_material(0, rock)
		var nm: String = "WestBreakwater" if sea_side < 0.0 else "EastMole"
		_mesh_node(node, nm, _save_res(mesh, nm.to_snake_case()))
		# Crown wall and walkway on the crest (life-size kit units are metres here: the kit's scale is 1).
		for k in range(line.size() - 1):
			var a: Vector2 = line[k]
			var b: Vector2 = line[k + 1]
			var dir2: Vector2 = (b - a).normalized()
			var left2 := Vector2(dir2.y, -dir2.x)
			var sea2: Vector2 = left2 * sea_side
			var wa: Vector2 = a + sea2 * (MOUND_HALF - 1.0)
			var wb: Vector2 = b + sea2 * (MOUND_HALF - 1.0)
			# The crown wall stops at the head's block (it had run on to the very end, past the light's foot).
			if k == line.size() - 2:
				wb -= dir2 * HEAD_R * 0.75
			walls_pk.beam(walls_kit, "quay", Vector3(wa.x, MOUND_CREST + 0.6, wa.y), Vector3(wb.x, MOUND_CREST + 0.6, wb.y), 1.6, 3.6, Color(0.72, 0.7, 0.66), Vector3(sea2.x, 0, sea2.y))
			walls_pk.beam(walls_kit, "quay", Vector3(a.x, MOUND_CREST - 0.9, a.y), Vector3(b.x, MOUND_CREST - 0.9, b.y), 10.0, 1.2, Color(0.68, 0.66, 0.62), Vector3(left2.x, 0, left2.y))
			var mid := (a + b) * 0.5
			var len_ab: float = a.distance_to(b)
			shapes.append(_box_shape(Vector3(len_ab, MOUND_CREST - SEABED_Y, MOUND_HALF * 2.0), Transform3D(Basis(Vector3.UP, atan2(-dir2.y, dir2.x)), Vector3(mid.x, (MOUND_CREST + SEABED_Y) * 0.5, mid.y))))
	_mesh_node(node, "CrownWalls", _commit_kit(walls_pk, walls_kit, "crown_walls"))
	# Tetrapods and boulders.
	var tpk := PortKit.new_port_kit(1.0)
	var tkit := {}
	PortKit.tetrapod(tpk, tkit)
	var tmesh := _commit_kit(tpk, tkit, "tetrapod")
	_multimesh_cells(node, "Tetrapods", tmesh, tetra_xf, 200.0, 650.0)
	var bmesh: ArrayMesh = PortKit.rock_mesh(31, Vector3(1.0, 0.8, 1.2), rock)
	_multimesh_cells(node, "Boulders", _save_res(bmesh, "mound_boulder"), boulder_xf, 200.0, 650.0)
	_solid(node, "BreakwaterSolid", shapes, "rock")
	# The heads: a roundhead of rubble and tetrapods round each end, a concrete block on it, the light on that.
	var head_xf: Array = []
	var hpk := PortKit.new_port_kit(1.0)
	var hkit := {}
	for hd in [[WEST_BREAKWATER, -1.0], [EAST_MOLE, 1.0]]:
		var hl: Array = hd[0]
		var tip: Vector2 = hl[hl.size() - 1]
		var back: Vector2 = ((hl[hl.size() - 2] as Vector2) - tip).normalized()
		_roundhead(node, rock, noise, tip, back, head_xf, rng, hpk, hkit)
		shapes.append(_cyl_shape(HEAD_R, MOUND_CREST - SEABED_Y, Vector3(tip.x, SEABED_Y, tip.y)))
	_multimesh_cells(node, "Tetrapods_head", tmesh, head_xf, 200.0, 650.0)
	_mesh_node(node, "HeadBlocks", _commit_kit(hpk, hkit, "head_blocks"))
	_solid(node, "HeadSolid", shapes.slice(shapes.size() - 2), "rock")
	# The lights at the heads.
	for head in [[WEST_BREAKWATER[WEST_BREAKWATER.size() - 1], Color(0.78, 0.12, 0.10), "BLOOMBAY  W"], [EAST_MOLE[EAST_MOLE.size() - 1], Color(0.12, 0.52, 0.24), "BLOOMBAY  E"]]:
		var hp: Vector2 = head[0]
		var lpk := PortKit.new_port_kit(PROP_SCALE)
		var lkit := {}
		var labels: Array = []
		PortKit.harbour_light(lpk, lkit, Vector3.ZERO, head[1], labels, head[2])
		var xf := Transform3D(Basis(Vector3.UP, PI if hp.x > 0.0 else 0.0).scaled(Vector3.ONE * PROP_SCALE), Vector3(hp.x, HEAD_TOP, hp.y))
		lpk.set_frame(Transform3D.IDENTITY)
		_mesh_node(node, "HarbourLight_%s" % ("E" if hp.x > 200.0 else "W"), _commit_kit(lpk, lkit, "harbour_light_%d" % int(hp.x)), xf)
		_labels(node, labels, xf)
		_solid(node, "HarbourLightSolid_%d" % int(hp.x), [_cyl_shape(3.4 * PROP_SCALE, 18.0 * PROP_SCALE, Vector3(hp.x, HEAD_TOP, hp.y))])
	print("  breakwaters: %d tetrapods, %d boulders" % [tetra_xf.size(), boulder_xf.size()])


func _multimesh(parent: Node3D, node_name: String, mesh: Mesh, xfs: Array, range_end := 0.0, shadows := true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	mm.buffer = PropKit.transform_buffer(xfs)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if range_end > 0.0:
		mmi.visibility_range_end = range_end
	parent.add_child(mmi)
	return mmi


## Instances grouped into square cells (each MultiMesh round its own middle), so each cell culls and fades by itself.
func _multimesh_cells(parent: Node3D, node_name: String, mesh: Mesh, xfs: Array, cell: float, range_end: float, shadows := true) -> void:
	var groups := {}
	for t in xfs:
		var o: Vector3 = (t as Transform3D).origin
		var key := Vector2i(int(floor(o.x / cell)), int(floor(o.z / cell)))
		if not groups.has(key):
			groups[key] = []
		groups[key].append(t)
	for key in groups.keys():
		var list: Array = groups[key]
		var mid := Vector3((float(key.x) + 0.5) * cell, 0.0, (float(key.y) + 0.5) * cell)
		var local: Array = []
		for t in list:
			local.append(Transform3D((t as Transform3D).basis, (t as Transform3D).origin - mid))
		# Shuffled, so drawing the first N (HarborDetail.gd) thins the cell evenly.
		var srng := RandomNumberGenerator.new()
		srng.seed = hash(node_name) ^ (key.x * 7919 + key.y * 104729)
		for i in range(local.size() - 1, 0, -1):
			var j := srng.randi_range(0, i)
			var tmp: Transform3D = local[i]
			local[i] = local[j]
			local[j] = tmp
		var mmi := _multimesh(parent, "%s_%d_%d" % [node_name, key.x, key.y], mesh, local, range_end, shadows)
		mmi.position = mid
		mmi.visibility_range_end_margin = range_end * 0.1
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		mmi.set_meta(&"base_range", range_end)


# --------------------------------------------------------------------------------------
#  The town: Bloombay's harbour front, the city on the rising ground behind it, the old town on the west hill
# --------------------------------------------------------------------------------------
# Buildings are boxes whose facades city_building.gdshader draws (storeys of windows over shop fronts; glass curtain
# walls on the downtown towers), under hipped roofs of terracotta tile or slate (hut_masonry), merged per tile of the
# land so each tile culls by itself. Each building stands on the lowest ground under it, its walls running down past
# the street on a slope.

const STOREY := 5.0
const BAY := 5.6
const SHOP_H := 6.4
const WALL_PAINTS := [Color(0.93, 0.88, 0.76), Color(0.94, 0.93, 0.90), Color(0.86, 0.72, 0.48), Color(0.80, 0.52, 0.40),
		Color(0.72, 0.80, 0.84), Color(0.74, 0.84, 0.76), Color(0.90, 0.74, 0.70), Color(0.74, 0.72, 0.68), Color(0.64, 0.36, 0.28),
		Color(0.90, 0.84, 0.62)]
const OLD_TOWN_PAINTS := [Color(0.95, 0.82, 0.52), Color(0.92, 0.62, 0.48), Color(0.62, 0.78, 0.86), Color(0.94, 0.92, 0.86),
		Color(0.78, 0.86, 0.66), Color(0.92, 0.70, 0.74), Color(0.86, 0.56, 0.36), Color(0.96, 0.88, 0.70)]

var _town_tiles := {}
var _occupied := {}

func _build_city(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Town"
	root.add_child(node)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4451
	seed(4452)
	var n := 0
	# Mainland sheds along the north quay, facing the water.
	n += _mainland_sheds(node)
	# The harbour front: a row of tall houses and offices facing the water behind the quayside.
	var x := QUAY_W_X + 12.0
	while x < QUAY_E_X - 20.0:
		var w: float = rng.randf_range(14.0, 26.0)
		if rng.randf() < 0.12:
			x += 13.0  # a street up into the town
		var d: float = rng.randf_range(16.0, 22.0)
		var storeys: int = rng.randi_range(4, 7)
		var col: Color = WALL_PAINTS[rng.randi() % WALL_PAINTS.size()]
		_add_building(x + w * 0.5, -202.0 - d * 0.5 + 8.0, w, d, 0.0, storeys, col, rng.randi() % 2, rng.randi() % 4, false)
		x += w + rng.randf_range(0.0, 1.5)
		n += 1
	# The city: blocks between streets, taller toward downtown (north-east), thinning out up the hills.
	var bx := -980.0
	while bx < 980.0:
		var bz := -240.0
		while bz > -1300.0:
			var cx := bx + 36.0
			var cz := bz - 28.0
			var urb := _urban(cx, cz)
			if urb > 0.05 and rng.randf() < urb * 1.15 and _land_d(cx, cz) > 30.0:
				var dt: float = exp(-pow((cx - 380.0) / 260.0, 2.0) - pow((cz + 620.0) / 220.0, 2.0))
				var lots: int = rng.randi_range(2, 4)
				for row in range(2):
					for l in range(lots):
						if rng.randf() < 0.12:
							continue
						var lw: float = 72.0 / float(lots)
						var lx: float = bx + lw * (float(l) + 0.5)
						var lz: float = bz - 14.0 - 28.0 * float(row)
						var tall: bool = rng.randf() < dt * 0.8
						if tall:
							if row == 0 and l == 0:
								_add_tower(bx + 36.0, bz - 28.0, rng.randf_range(24.0, 34.0), rng.randi_range(12, 30), rng)
								n += 1
							continue
						var storeys2: int = rng.randi_range(3, 6) - (1 if urb < 0.5 else 0)
						var col2: Color = WALL_PAINTS[rng.randi() % WALL_PAINTS.size()]
						_add_building(lx, lz, lw - rng.randf_range(1.5, 4.0), rng.randf_range(20.0, 25.0), 0.0, maxi(storeys2, 2), col2,
								rng.randi() % 2, rng.randi() % 4, false)
						n += 1
			bz -= 70.0
		bx += 86.0
	# The cathedral, halfway up the west hill, its towers over the old town's roofs.
	_build_cathedral(node)
	n += 1
	# The old town: small, bright houses packed up the west hill, their rows following the slope.
	var oz := QUAY_N_Z - 60.0
	while oz < WEST_S_Z - 6.0:
		var ox := QUAY_W_X - 14.0
		while ox > -1050.0:
			var w3: float = rng.randf_range(9.0, 15.0)
			var d3: float = rng.randf_range(10.0, 14.0)
			var urb3 := _urban(ox, oz)
			if urb3 > 0.05 and rng.randf() < urb3 * 1.2:
				var col3: Color = OLD_TOWN_PAINTS[rng.randi() % OLD_TOWN_PAINTS.size()]
				_add_building(ox - w3 * 0.5, oz + rng.randf_range(-2.0, 2.0), w3, d3, PI * 0.5 + rng.randf_range(-0.12, 0.12), rng.randi_range(2, 4), col3, 0, rng.randi() % 4, false)
				n += 1
			ox -= w3 + rng.randf_range(0.5, 3.0) + (10.0 if rng.randf() < 0.1 else 0.0)
		oz += rng.randf_range(16.0, 21.0)
	# Commit the tiles.
	var wall_mat := _city_wall_mat()
	var tile_mat := _roof_mat("tile")
	var slate_mat := _roof_mat("slate")
	for key in _town_tiles.keys():
		var t: Dictionary = _town_tiles[key]
		var mesh := ArrayMesh.new()
		for pair in [["walls", wall_mat], ["tile", tile_mat], ["slate", slate_mat]]:
			var st: SurfaceTool = t[pair[0]]
			if t["count_" + pair[0]] == 0:
				continue
			st.index()
			if pair[0] != "walls":
				st.generate_tangents()
			st.commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, pair[1])
		_mesh_node(node, "Town_%d_%d" % [key.x, key.y], _save_res(mesh, "town_%d_%d" % [key.x + 10, key.y + 10]), Transform3D.IDENTITY, true)
	print("  town: %d buildings in %d tiles" % [n, _town_tiles.size()])
	_build_trees(node)


func _town_tile(x: float, z: float) -> Dictionary:
	var key := Vector2i(int(floor(x / LAND_TILE)), int(floor(z / LAND_TILE)))
	if not _town_tiles.has(key):
		var t := {}
		for k in ["walls", "tile", "slate"]:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			t[k] = st
			t["count_" + k] = 0
		_town_tiles[key] = t
	return _town_tiles[key]


## One building: `w` along its own x, `d` deep, turned `yaw`, `storeys` high over the lowest ground under it; `roof` 0
## a terracotta hip, 1 a slate hip, 2 flat; `style` the windows (city_building's UV2.y); `glass` a curtain wall.
func _add_building(x: float, z: float, w: float, d: float, yaw: float, storeys: int, col: Color, roof: int, style: int, glass: bool) -> void:
	var b := Basis(Vector3.UP, yaw)
	var hw := w * 0.5
	var hd := d * 0.5
	var corners := [Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd), Vector3(hw, 0, hd), Vector3(-hw, 0, hd)]
	var g_lo := INF
	var g_hi := -INF
	for c in corners:
		var wc: Vector3 = b * (c as Vector3) + Vector3(x, 0, z)
		var g := _land_h(wc.x, wc.z)
		g_lo = minf(g_lo, g)
		g_hi = maxf(g_hi, g)
	if g_lo < DECK_Y - 0.5:
		return
	# Keep buildings off each other (and off the sheds and the terminal).
	var cells := _footprint_cells(x, z, w, d, yaw)
	for c2 in cells:
		if _occupied.has(c2):
			return
	for c2 in cells:
		_occupied[c2] = true
	var base: float = g_lo - 2.0
	var street: float = g_lo
	var top: float = g_hi + float(storeys) * STOREY + 1.2
	var t := _town_tile(x, z)
	var walls: SurfaceTool = t["walls"]
	var kind: float = 1.0 if glass else 0.0
	for i in range(4):
		var a: Vector3 = b * (corners[i] as Vector3) + Vector3(x, 0, z)
		var e: Vector3 = b * (corners[(i + 1) % 4] as Vector3) + Vector3(x, 0, z)
		var out: Vector3 = (b * (((corners[i] as Vector3) + (corners[(i + 1) % 4] as Vector3)) * 0.5)).normalized()
		var length: float = Vector2(e.x - a.x, e.z - a.z).length()
		var u1: float = maxf(1.0, round(length / BAY)) * BAY
		var s1: float = maxf(1.0, round(length / (BAY * 1.5))) * BAY * 1.5
		var shade := col.darkened(0.05 * float(i % 2))
		shade.a = kind
		var q := [Vector3(a.x, base, a.z), Vector3(e.x, base, e.z), Vector3(e.x, top, e.z), Vector3(a.x, top, a.z)]
		var uv := [Vector2(0, base - street), Vector2(u1, base - street), Vector2(u1, top - street), Vector2(0, top - street)]
		var uv2 := [Vector2(0, style), Vector2(s1, style), Vector2(s1, style), Vector2(0, style)]
		_wall_quad(walls, q, uv, uv2, out, shade)
		t["count_walls"] += 1
	if roof == 2 or glass:
		var rq := []
		for c in corners:
			rq.append(b * (c as Vector3) + Vector3(x, top, z))
		var rc := col.darkened(0.2)
		rc.a = 0.0
		_wall_quad(walls, rq, [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO], [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO], Vector3.UP, rc)
		# A plant room on the bigger flat roofs.
		if w > 14.0 and d > 14.0:
			_box_building(walls, Vector3(x, top, z), minf(w * 0.35, 10.0), minf(d * 0.35, 8.0), 4.0, yaw, col.darkened(0.1))
		return
	var key := "tile" if roof == 0 else "slate"
	var pitch := 0.55 if roof == 0 else 0.8
	var roof_col: Color = Color(0.74, 0.40, 0.27) if roof == 0 else Color(0.40, 0.42, 0.46)
	roof_col = roof_col.lerp(Color(0.6, 0.55, 0.5), randf() * 0.25)
	_hip_roof(t[key], Vector3(x, top, z), w + 0.8, d + 0.8, yaw, pitch, roof_col)
	t["count_" + key] += 1


## A box for a plant room or a stair head on a flat roof (plain concrete: alpha 0.7).
func _box_building(st: SurfaceTool, at: Vector3, w: float, d: float, h: float, yaw: float, col: Color) -> void:
	var b := Basis(Vector3.UP, yaw)
	var c := [Vector3(-w, 0, -d) * 0.5, Vector3(w, 0, -d) * 0.5, Vector3(w, 0, d) * 0.5, Vector3(-w, 0, d) * 0.5]
	var pc := col
	pc.a = 0.7
	for i in range(4):
		var a: Vector3 = at + b * (c[i] as Vector3)
		var e: Vector3 = at + b * (c[(i + 1) % 4] as Vector3)
		var out: Vector3 = (b * (((c[i] as Vector3) + (c[(i + 1) % 4] as Vector3)) * 0.5)).normalized()
		_wall_quad(st, [a, e, e + Vector3(0, h, 0), a + Vector3(0, h, 0)], [Vector2(0, 0), Vector2(1, 0), Vector2(1, h), Vector2(0, h)], [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO], out, pc)
	var top := []
	for cc in c:
		top.append(at + b * (cc as Vector3) + Vector3(0, h, 0))
	pc.a = 0.0
	_wall_quad(st, top, [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO], [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO], Vector3.UP, pc)


func _wall_quad(st: SurfaceTool, q: Array, uv: Array, uv2: Array, out: Vector3, col: Color) -> void:
	for tri in [[0, 1, 2], [0, 2, 3]]:
		var ia: int = tri[0]
		var ib: int = tri[1]
		var ic: int = tri[2]
		if ((q[ic] as Vector3) - (q[ia] as Vector3)).cross((q[ib] as Vector3) - (q[ia] as Vector3)).dot(out) < 0.0:
			var tmp := ib
			ib = ic
			ic = tmp
		for k in [ia, ib, ic]:
			st.set_color(col)
			st.set_normal(out)
			st.set_uv(uv[k])
			st.set_uv2(uv2[k])
			st.add_vertex(q[k])


## A hipped roof over a w x d rectangle at height `at.y`: two trapezoids along the longer side, two triangles at the
## ends, UVs in metres (u along each eave, v up its slope) for the tile and slate shaders.
func _hip_roof(st: SurfaceTool, at: Vector3, w: float, d: float, yaw: float, pitch: float, col: Color) -> void:
	var b := Basis(Vector3.UP, yaw)
	if d > w:
		b = Basis(Vector3.UP, yaw + PI * 0.5)
		var tmp := w
		w = d
		d = tmp
	var hw := w * 0.5
	var hd := d * 0.5
	var rh: float = hd * pitch
	var e := [Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd), Vector3(hw, 0, hd), Vector3(-hw, 0, hd)]
	var r0 := Vector3(-hw + hd, rh, 0)
	var r1 := Vector3(hw - hd, rh, 0)
	var slope_len: float = sqrt(hd * hd + rh * rh)
	var faces := [
		[[e[3], e[2], r1, r0], Vector3(0, 1, pitch)],
		[[e[1], e[0], r0, r1], Vector3(0, 1, -pitch)],
		[[e[2], e[1], r1], Vector3(pitch, 1, 0)],
		[[e[0], e[3], r0], Vector3(-pitch, 1, 0)],
	]
	for f in faces:
		var pts: Array = f[0]
		var nrm: Vector3 = (b * (f[1] as Vector3)).normalized()
		var eave_a: Vector3 = pts[0]
		var eave_b: Vector3 = pts[1]
		var edir: Vector3 = (eave_b - eave_a).normalized()
		var uvs: Array = []
		for pp in pts:
			var p3: Vector3 = pp
			uvs.append(Vector2((p3 - eave_a).dot(edir), p3.y / maxf(rh, 0.01) * slope_len))
		var wp: Array = []
		for pp in pts:
			wp.append(at + b * (pp as Vector3))
		var tris: Array = [[0, 1, 2], [0, 2, 3]] if pts.size() == 4 else [[0, 1, 2]]
		for tri in tris:
			var ia: int = tri[0]
			var ib: int = tri[1]
			var ic: int = tri[2]
			if ((wp[ic] as Vector3) - (wp[ia] as Vector3)).cross((wp[ib] as Vector3) - (wp[ia] as Vector3)).dot(nrm) < 0.0:
				var tmp2 := ib
				ib = ic
				ic = tmp2
			for k in [ia, ib, ic]:
				st.set_color(col)
				st.set_normal(nrm)
				st.set_uv(uvs[k])
				st.add_vertex(wp[k])


func _city_wall_mat() -> ShaderMaterial:
	if _mats.has("city_walls"):
		return _mats["city_walls"]
	var m := ShaderMaterial.new()
	m.shader = load("res://city_building.gdshader")
	m.set_shader_parameter("concrete_tex", load("res://materials/concrete.png"))
	m.set_shader_parameter("storey", STOREY)
	m.set_shader_parameter("bay", BAY)
	m.set_shader_parameter("shop_h", SHOP_H)
	m.set_shader_parameter("refl_top", Color(0.19, 0.40, 0.74))
	m.set_shader_parameter("refl_horizon", Color(0.80, 0.81, 0.80))
	m.set_shader_parameter("refl_ground", Color(0.30, 0.31, 0.30))
	m.set_shader_parameter("refl_cloud", Color(1.0, 0.94, 0.84))
	# The towers' glass from afar: blue, as Bloombay's skyline looks across the bay from South Beach.
	m.set_shader_parameter("sky_reflect", Color(0.36, 0.54, 0.80))
	m.set_shader_parameter("glass_dark", Color(0.08, 0.14, 0.26))
	m.set_shader_parameter("refl_base", 0.16)
	_mats["city_walls"] = _save_res(m, "mat_city_walls")
	return _mats["city_walls"]


func _roof_mat(key: String) -> Material:
	var mk := "roof_" + key
	if _mats.has(mk):
		return _mats[mk]
	var m: Material = PortKit.make_material(key)
	_mats[mk] = _save_res(m, "mat_" + mk)
	return _mats[mk]


## Mainland sheds on the north quay, facing the water across the gap behind the wharf.
const MAINLAND_SHEDS := [
	[Vector2(-300.0, -170.0), 18.0, 11.0, 10.0, 3, "BLOOMBAY HARBOUR BOARD", 1],
	[Vector2(-215.0, -170.0), 16.0, 11.0, 9.0, 2, "SHED 7", 0],
	[Vector2(110.0, -170.0), 16.0, 11.0, 9.0, 2, "SHED 8", 2],
	[Vector2(190.0, -170.0), 18.0, 11.0, 10.0, 3, "SHIP CHANDLERY", 3],
]

func _mainland_sheds(node: Node3D) -> int:
	var shapes: Array = []
	for i in range(MAINLAND_SHEDS.size()):
		var w: Array = MAINLAND_SHEDS[i]
		var pk := PortKit.new_port_kit(1.0)
		var kit := {}
		var labels: Array = []
		var look: Array = WAREHOUSE_LOOKS[int(w[6])]
		PortKit.warehouse(pk, kit, w[1], w[2], w[3], w[4], labels, w[5], look[0], look[1], true, look[2])
		var c: Vector2 = w[0]
		var xf := Transform3D(Basis.from_scale(Vector3.ONE * PROP_SCALE), Vector3(c.x, DECK_Y, c.y))
		_mesh_node(node, "MainlandShed_%d" % i, _commit_kit(pk, kit, "mainland_shed_%d" % i), xf, true, 1100.0)
		_labels(node, labels, xf)
		var size := Vector3(w[1], w[3], w[2]) * PROP_SCALE
		shapes.append(_box_shape(size, Transform3D(Basis(), Vector3(c.x, DECK_Y + size.y * 0.5, c.y))))
		for c2 in _footprint_cells(c.x, c.y, size.x + 4.0, size.z + 12.0, 0.0):
			_occupied[c2] = true
	_solid(node, "MainlandShedWalls", shapes)
	return MAINLAND_SHEDS.size()


## Trees on the hills and in the town's gaps: WoodlandBuilder's oak, lime, birch and spruce (the Lakeside Course's
## woods: bark tubes carrying leaf-spray cards), each a detailed tree near the camera crossfading into its stand-in (a
## few big cards) round JungleDetail's TREE_NEAR, wherever the ground is grown, not steep, and no building stands. The
## near cells, their shadow proxies and the far cells hold the same instances in the same shuffled order, so the
## Detail Level (HarborDetail.gd) thins all three alike. Spruce up on the heights, birch and lime in the town.
const TREE_KINDS := ["oak", "lime", "birch", "spruce"]
const TREE_CELL := 300.0
const TREE_FAR_RANGE := 1700.0

func _build_trees(parent: Node3D) -> void:
	var t0 := Time.get_ticks_msec()
	var node := Node3D.new()
	node.name = "Woodland"
	parent.add_child(node)
	var w = load("res://WoodlandBuilder.gd").new()
	w.save_res = func(res: Resource, n: String) -> Resource: return _save_res(res, n)
	var leaf_near: ShaderMaterial = _save_res(w.leaf_material(1, 0.14, 18.0), "leaf_near")
	var leaf_far: ShaderMaterial = _save_res(w.leaf_material(2, 0.14, 18.0), "leaf_far")
	var lod_mats: Array[ShaderMaterial] = [leaf_near, leaf_far]
	var near_meshes: Array = []
	var far_meshes: Array = []
	for kind in TREE_KINDS:
		var bn: ShaderMaterial = _save_res(w.bark_material(kind, 1), "bark_%s_near" % kind)
		var bf: ShaderMaterial = _save_res(w.bark_material(kind, 2), "bark_%s_far" % kind)
		lod_mats.append(bn)
		lod_mats.append(bf)
		# One shape per kind (scale, lean and turn vary them): eight would split every cell eight ways, a draw each.
		for v in range(1):
			var nm: ArrayMesh
			var fm: ArrayMesh
			if kind == "spruce":
				nm = w.spruce_mesh(v, 0, bn, leaf_near)
				fm = w.spruce_mesh(v, 1, bf, leaf_far)
			else:
				nm = w.broadleaf_mesh(kind, v, 0, bn, leaf_near)
				fm = w.broadleaf_mesh(kind, v, 1, bf, leaf_far)
			near_meshes.append(_save_res(nm, "tree_%s_%d" % [kind, v]))
			far_meshes.append(_save_res(fm, "tree_%s_%d_far" % [kind, v]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 9031
	var woods := FastNoiseLite.new()
	woods.seed = 9032
	woods.frequency = 0.004
	woods.fractal_octaves = 3
	var kind_noise := FastNoiseLite.new()
	kind_noise.seed = 9033
	kind_noise.frequency = 0.008
	kind_noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	var cells := {}
	var counts := {"oak": 0, "lime": 0, "birch": 0, "spruce": 0}
	var step := 13.0
	var x := -1500.0
	while x < 1500.0:
		var z := -1500.0
		while z < WEST_S_Z:
			var px := x + rng.randf_range(-0.45, 0.45) * step
			var pz := z + rng.randf_range(-0.45, 0.45) * step
			var roll := rng.randf()
			z += step
			var d := _land_d(px, pz)
			if d < 25.0:
				continue
			var r := Vector2(px, pz + 300.0).length()
			if r > 1500.0:
				continue
			var urb := _urban(px, pz)
			# Ultra draws all of them; High leaves out a fifth (HarborDetail.TREE_SHARE).
			var dens: float = (smoothstep(-0.15, 0.3, woods.get_noise_2d(px, pz)) * 0.75 * (1.0 - urb) + 0.05 * urb) * 1.25
			if px > QUAY_E_X - 20.0 and _land_d(px, pz) - _flat_run(px, pz) < 20.0:
				continue  # the terminal's yard
			if roll > dens:
				continue
			if _occupied.has(Vector2i(int(floor(px / 3.0)), int(floor(pz / 3.0)))):
				continue
			var g := _land_h(px, pz)
			var slope := Vector2(_land_h(px + 3.0, pz) - g, _land_h(px, pz + 3.0) - g).length() / 3.0
			if slope > 0.8:
				continue
			var kn: float = kind_noise.get_noise_2d(px, pz)
			var kind := "lime"
			if (g > 85.0 and kn > -0.15) or kn > 0.55:
				kind = "spruce"
			elif urb > 0.4:
				kind = "birch" if rng.randf() < 0.4 else "lime"
			elif kn < -0.1 or rng.randf() < 0.35:
				kind = "oak"
			elif rng.randf() < 0.2:
				kind = "birch"
			var mi: int = TREE_KINDS.find(kind)
			var sc := rng.randf_range(1.0, 1.35)
			var lean := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.04))
			var xf := Transform3D(lean * Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.92, 1.1), sc)),
					Vector3(px, g - 0.25 - minf(slope * 1.2, 1.0), pz))
			var key := Vector3i(int(floor(px / TREE_CELL)), int(floor(pz / TREE_CELL)), mi)
			if not cells.has(key):
				cells[key] = []
			cells[key].append(xf)
			counts[kind] += 1
		x += step
	var cell_r: float = TREE_CELL * 0.72
	var near_end: float = 135.0 + 20.0 + 12.0 + cell_r
	var total := 0
	for key in cells.keys():
		var list: Array = cells[key]
		var mid := Vector3((float(key.x) + 0.5) * TREE_CELL, 0.0, (float(key.y) + 0.5) * TREE_CELL)
		var local: Array = []
		for t in list:
			local.append(Transform3D((t as Transform3D).basis, (t as Transform3D).origin - mid))
		var srng := RandomNumberGenerator.new()
		srng.seed = key.x * 7919 + key.y * 104729 + key.z * 31
		for i in range(local.size() - 1, 0, -1):
			var j := srng.randi_range(0, i)
			var tmp: Transform3D = local[i]
			local[i] = local[j]
			local[j] = tmp
		total += local.size()
		var near_mmi := _multimesh(node, "Tree_%d_%d_%d" % [key.x, key.y, key.z], near_meshes[key.z], local, near_end, false)
		near_mmi.position = mid
		near_mmi.visibility_range_end_margin = 10.0
		var proxy := _multimesh(node, "TreeShadow_%d_%d_%d" % [key.x, key.y, key.z], far_meshes[key.z], local, near_end, true)
		proxy.position = mid
		proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		var far_mmi := _multimesh(node, "Trees_far_%d_%d_%d" % [key.x, key.y, key.z], far_meshes[key.z], local, TREE_FAR_RANGE, false)
		far_mmi.position = mid
		far_mmi.visibility_range_end_margin = TREE_FAR_RANGE * 0.1
		far_mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		far_mmi.set_meta(&"base_range", TREE_FAR_RANGE)
	var detail := Node3D.new()
	detail.name = "JungleDetail"
	detail.set_script(load("res://JungleDetail.gd"))
	detail.set("lod_materials", lod_mats)
	detail.set("tree_fade", 40.0)
	detail.set("tree_fade_jitter", 12.0)
	detail.set("forest_cell", TREE_CELL)
	node.add_child(detail)
	print("  trees: %d %s in %d cells (%.1fs)" % [total, str(counts), cells.size(), (Time.get_ticks_msec() - t0) / 1000.0])


## The 3m cells whose middles lie inside a w x d rectangle at (x, z) turned yaw (the town's occupancy grid).
func _footprint_cells(x: float, z: float, w: float, d: float, yaw: float) -> Array:
	var out: Array = []
	var inv := Basis(Vector3.UP, yaw).inverse()
	var r: float = sqrt(w * w + d * d) * 0.5
	var i0: int = int(floor((x - r) / 3.0))
	var i1: int = int(floor((x + r) / 3.0))
	var j0: int = int(floor((z - r) / 3.0))
	var j1: int = int(floor((z + r) / 3.0))
	for i in range(i0, i1 + 1):
		for j in range(j0, j1 + 1):
			var lp: Vector3 = inv * Vector3((float(i) + 0.5) * 3.0 - x, 0, (float(j) + 0.5) * 3.0 - z)
			if absf(lp.x) < w * 0.5 + 0.5 and absf(lp.z) < d * 0.5 + 0.5:
				out.append(Vector2i(i, j))
	return out


# --------------------------------------------------------------------------------------
#  The container terminal: a feeder ship alongside, three ship-to-shore cranes, the yard
# --------------------------------------------------------------------------------------

## The ship's middle on the water, its bow toward -z (north), its starboard side alongside the terminal's quay.
const SHIP_AT := Vector3(250.0, WATER_Y, -20.0)
const CRANE_X := 272.0
## [z, boom raised (radians), trolley out from the waterside rail, spreader drop]
const CRANES := [[-80.0, 0.0, 23.0, 25.0], [-22.0, 0.0, 31.0, 31.0], [42.0, 1.32, 0.0, 0.0]]
## Yard blocks: [middle (x, z), boxes along x, rows across z, tiers]
const YARD := [
	[Vector2(372.0, -112.0), 3, 7, 3], [Vector2(372.0, -66.0), 3, 7, 4], [Vector2(372.0, -20.0), 3, 7, 2], [Vector2(372.0, 26.0), 3, 7, 3],
	[Vector2(372.0, 72.0), 3, 7, 3], [Vector2(450.0, -112.0), 3, 7, 2], [Vector2(450.0, -66.0), 3, 7, 3], [Vector2(450.0, -20.0), 3, 7, 4],
	[Vector2(450.0, 26.0), 3, 7, 3], [Vector2(450.0, 72.0), 3, 7, 2], [Vector2(528.0, -66.0), 3, 7, 3], [Vector2(528.0, 26.0), 3, 7, 2],
]

func _build_terminal(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Terminal"
	root.add_child(node)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7007
	# The ship.
	var spk := ShipKit.new_port_kit(1.0)
	var skit := {}
	var slabels: Array = []
	var leads: Array = ShipKit.container_ship(spk, skit, rng, slabels, "BLOOMBAY STAR")
	var sxf := Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * PROP_SCALE), SHIP_AT)
	_mesh_node(node, "FeederShip", _commit_kit(spk, skit, "feeder_ship"), sxf)
	_labels(node, slabels, sxf)
	var ship_box := AABB(Vector3(-ShipKit.SHIP_HALF, -6.0, -ShipKit.SHIP_L * 0.5), Vector3(ShipKit.SHIP_HALF * 2.0, 6.0 + ShipKit.SHIP_FB + 2.4, ShipKit.SHIP_L))
	_solid(node, "FeederShipHull", [_box_shape(ship_box.size * PROP_SCALE, Transform3D(Basis(Vector3.UP, PI), sxf * ship_box.get_center()))])
	# Mooring lines from her starboard fairleads to the quay's bollards (the nearest one ahead or astern of each).
	var rpk := PortKit.new_port_kit(1.0)
	var rkit := {}
	for i in range(leads.size()):
		var l: Vector3 = leads[i]
		var fair: Vector3 = sxf * Vector3(-l.x, l.y, l.z)
		var lead_z: float = fair.z + (-14.0 if i == 0 else (14.0 if i == 1 else (8.0 if i == 2 else -8.0)))
		var bol := Vector3(QUAY_E_X - 0.8, DECK_Y + 0.55 * PROP_SCALE, lead_z)
		PortKit.rope(rpk, rkit, fair, bol, 1.4, 0.09)
	_mesh_node(node, "MooringLines", _commit_kit(rpk, rkit, "mooring_lines"))
	# The cranes on their rails.
	var cpk := PortKit.new_port_kit(1.0)
	var shapes: Array = []
	var crane_meshes := {}
	for i in range(CRANES.size()):
		var c: Array = CRANES[i]
		var key := "%d_%d_%d" % [int(c[1] * 100.0), int(c[2]), int(c[3])]
		var clabels: Array = []
		if not crane_meshes.has(key):
			var ckit := {}
			PortKit.sts_crane(cpk, ckit, clabels, 30.0, 56.0, c[2], c[3], c[1])
			crane_meshes[key] = _commit_kit(cpk, ckit, "sts_crane_%d" % i)
		else:
			PortKit.sts_crane(cpk, {}, clabels, 30.0, 56.0, c[2], c[3], c[1])
		var xf := Transform3D(Basis(), Vector3(CRANE_X, DECK_Y, c[0]))
		_mesh_node(node, "Crane_%d" % i, crane_meshes[key], xf)
		_labels(node, clabels, xf, 1.0)
		for lx in [0.0, 30.0]:
			for lz in [-9.0, 9.0]:
				shapes.append(_box_shape(Vector3(2.0, 40.0, 7.0), Transform3D(Basis(), Vector3(CRANE_X + lx, DECK_Y + 20.0, c[0] + lz))))
	# The crane rails along the quay.
	var rlk := {}
	for lx in [0.0, 30.0]:
		rpk.beam(rlk, "steel", Vector3(CRANE_X + lx, DECK_Y + 0.05, QUAY_N_Z + 4.0), Vector3(CRANE_X + lx, DECK_Y + 0.05, EAST_S_Z - 4.0), 0.5, 0.12, Color(0.32, 0.30, 0.28), Vector3.UP)
	# The yard: blocks of boxes, two gantries over them, floodlight masts.
	var ypk := PortKit.new_port_kit(PROP_SCALE)
	var ykit := {}
	for b in YARD:
		var c2: Vector2 = b[0]
		var n_x: int = b[1]
		var n_z: int = b[2]
		var size_x: float = (float(n_x) * (PortKit.BOX_40.x + 0.4) - 0.4) * PROP_SCALE
		var size_z: float = (float(n_z) * (PortKit.BOX_40.z + 0.25) - 0.25) * PROP_SCALE
		var first := Vector3(c2.x - size_x * 0.5 + PortKit.BOX_40.x * PROP_SCALE * 0.5, DECK_Y, c2.y - size_z * 0.5 + PortKit.BOX_40.z * PROP_SCALE * 0.5)
		ypk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * PROP_SCALE), first))
		PortKit.stack(ypk, ykit, rng, Vector3.ZERO, 0.0, n_x, n_z, b[3], false, true, 0.6)
		shapes.append(_box_shape(Vector3(size_x, float(b[3]) * PortKit.BOX_40.y * PROP_SCALE, size_z), Transform3D(Basis(), Vector3(c2.x, DECK_Y + float(b[3]) * PortKit.BOX_40.y * PROP_SCALE * 0.5, c2.y))))
	ypk.reset_frame()
	for g in [[Vector2(372.0, -66.0)], [Vector2(450.0, 26.0)]]:
		var gp: Vector2 = g[0]
		ypk.set_frame(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(gp.x + 12.0, DECK_Y, gp.y)))
		PortKit.rtg(ypk, ykit, 40.0, 26.0)
	for m in [Vector2(300.0, -110.0), Vector2(300.0, 10.0), Vector2(300.0, 128.0), Vector2(412.0, -132.0), Vector2(490.0, 120.0)]:
		ypk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * PROP_SCALE), Vector3(m.x, DECK_Y, m.y)))
		PortKit.light_mast(ypk, ykit, Vector3.ZERO, Vector3(-1, 0, 0), 22.0)
	_mesh_node(node, "Yard", _commit_kit(ypk, ykit, "terminal_yard"), Transform3D.IDENTITY, true, 1400.0)
	_mesh_node(node, "CraneRails", _commit_kit(rpk, rlk, "crane_rails"))
	_solid(node, "TerminalSolid", shapes)
	# The terminal's offices by its gate.
	_add_building(700.0, -100.0, 40.0, 18.0, 0.0, 4, Color(0.86, 0.86, 0.84), 2, 1, false)
	_add_building(720.0, 60.0, 28.0, 22.0, PI * 0.5, 2, Color(0.70, 0.72, 0.74), 2, 2, false)
	print("  terminal: ship, %d cranes, %d yard blocks" % [CRANES.size(), YARD.size()])


# --------------------------------------------------------------------------------------
#  The marina below the old town, and the fishing boats at the market
# --------------------------------------------------------------------------------------

const PONTOONS_Z := [-104.0, -52.0, 0.0, 52.0, 104.0, 156.0]
const PONTOON_LEN := 74.0
const PONTOON_W := 4.2
const FINGER_EVERY := 12.8

func _build_marina(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Marina"
	root.add_child(node)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3313
	# The boats' meshes: three yachts, two trawlers (life size; placed at PROP_SCALE).
	var kinds := {}
	for k in [["sail_blue", Color(0.12, 0.24, 0.48)], ["sail_red", Color(0.62, 0.14, 0.12)], ["sail_green", Color(0.14, 0.38, 0.30)]]:
		var bpk := ShipKit.new_port_kit(1.0)
		var bkit := {}
		ShipKit.sailboat(bpk, bkit, k[1])
		kinds[k[0]] = _commit_kit(bpk, bkit, "boat_" + String(k[0]))
	for k2 in [["fishing_red", Color(0.66, 0.14, 0.10), Color(0.93, 0.92, 0.88)], ["fishing_blue", Color(0.14, 0.30, 0.52), Color(0.92, 0.86, 0.62)]]:
		var fpk := ShipKit.new_port_kit(1.0)
		var fkit := {}
		ShipKit.fishing_boat(fpk, fkit, k2[1], k2[2])
		kinds[k2[0]] = _commit_kit(fpk, fkit, "boat_" + String(k2[0]))
	var tpk := ShipKit.new_port_kit(1.0)
	var tkit := {}
	ShipKit.tug(tpk, tkit)
	kinds["tug"] = _commit_kit(tpk, tkit, "boat_tug")
	_boat_meshes = kinds
	# Pontoons: a timber walkway on black floats, finger berths both sides, piles, a gangway down from the quay.
	var pk := PortKit.new_port_kit(1.0)
	var kit := {}
	var deck_y: float = WATER_Y + 0.55
	var shapes: Array = []
	var x0: float = QUAY_W_X
	var x1: float = QUAY_W_X + PONTOON_LEN
	for pz in PONTOONS_Z:
		PortKit.blk(pk, kit, "timber", Vector3(x0 + 6.0, deck_y - 0.12, pz - PONTOON_W * 0.5), Vector3(x1, deck_y, pz + PONTOON_W * 0.5), Color(0.56, 0.46, 0.34))
		PortKit.blk(pk, kit, "rubber", Vector3(x0 + 6.2, WATER_Y - 0.5, pz - PONTOON_W * 0.5 + 0.2), Vector3(x1 - 0.2, deck_y - 0.12, pz + PONTOON_W * 0.5 - 0.2), Color(0.1, 0.1, 0.11))
		# The gangway down from the quay, with handrails.
		var g0 := Vector3(x0 - 0.5, DECK_Y, pz)
		var g1 := Vector3(x0 + 7.0, deck_y, pz)
		pk.beam(kit, "timber", g0, g1, 1.8, 0.1, Color(0.5, 0.42, 0.32), Vector3(0, 0, 1))
		for sz in [-1.0, 1.0]:
			pk.beam(kit, "steel", g0 + Vector3(0, 1.0, sz * 0.9), g1 + Vector3(0, 1.0, sz * 0.9), 0.05, 0.05, Color(0.7, 0.72, 0.74))
			pk.beam(kit, "steel", g0 + Vector3(0, 0.0, sz * 0.9), g0 + Vector3(0, 1.0, sz * 0.9), 0.05, 0.05, Color(0.7, 0.72, 0.74))
			pk.beam(kit, "steel", g1 + Vector3(0, 0.0, sz * 0.9), g1 + Vector3(0, 1.0, sz * 0.9), 0.05, 0.05, Color(0.7, 0.72, 0.74))
		# Piles.
		var px: float = x0 + 14.0
		while px < x1:
			for sz in [-1.0, 1.0]:
				pk.tube(kit, "pile", Vector3(px, SEABED_Y, pz + sz * (PONTOON_W * 0.5 + 0.35)), Vector3(px, deck_y + 2.2, pz + sz * (PONTOON_W * 0.5 + 0.35)), 0.3, 0.3, 8, Color(0.72, 0.7, 0.66), true)
			px += 24.0
		# Finger berths and the boats in them.
		var fx: float = x0 + 12.0
		var berth := 0
		while fx < x1 - 4.0:
			for sz in [-1.0, 1.0]:
				var f0 := Vector3(fx - 0.8, deck_y - 0.1, pz + sz * PONTOON_W * 0.5)
				PortKit.blk(pk, kit, "timber", Vector3(fx - 0.8, deck_y - 0.1, minf(pz + sz * PONTOON_W * 0.5, pz + sz * (PONTOON_W * 0.5 + 9.6))),
						Vector3(fx + 0.8, deck_y, maxf(pz + sz * PONTOON_W * 0.5, pz + sz * (PONTOON_W * 0.5 + 9.6))), Color(0.56, 0.46, 0.34))
				PortKit.bollard(pk, kit, f0 + Vector3(0.0, 0.1, sz * 8.6), PortKit.BOLLARD_BLACK)
				# A boat in the berth past this finger (most are taken).
				if fx + FINGER_EVERY < x1 and rng.randf() < 0.82:
					var kind: String = ["sail_blue", "sail_red", "sail_green", "sail_blue", "fishing_red", "fishing_blue"][rng.randi() % 6]
					if pz == PONTOONS_Z[0] and sz < 0.0:
						continue
					# Trawlers only on a pontoon's south side: two moored stern to stern across a gap overlapped.
					if kind.begins_with("fishing") and sz < 0.0:
						kind = ["sail_blue", "sail_red", "sail_green"][rng.randi() % 3]
					var length: float = (ShipKit.TRAWLER["L"] if kind.begins_with("fishing") else ShipKit.YACHT["L"]) * PROP_SCALE
					var bz: float = pz + sz * (PONTOON_W * 0.5 + 0.8 + length * 0.5)
					var yaw: float = PI if sz > 0.0 else 0.0
					var xf := Transform3D(Basis(Vector3.UP, yaw + rng.randf_range(-0.03, 0.03)).scaled(Vector3.ONE * PROP_SCALE), Vector3(fx + FINGER_EVERY * 0.5, WATER_Y, bz))
					_mesh_node(node, "Moored_%d_%d" % [int(pz), berth], kinds[kind], xf, true, 700.0)
					berth += 1
			fx += FINGER_EVERY
		shapes.append(_box_shape(Vector3(PONTOON_LEN, 1.0, PONTOON_W), Transform3D(Basis(), Vector3((x0 + x1) * 0.5, deck_y - 0.5, pz))))
	_mesh_node(node, "Pontoons", _commit_kit(pk, kit, "pontoons"), Transform3D.IDENTITY, true, 900.0)
	_solid(node, "PontoonSolid", shapes, "wood")
	# Trawlers at the fish market's quay and a tug at the terminal's south end.
	for fb in [[Vector2(-28.0, -53.5), PI * 0.5, "fishing_red"], [Vector2(8.0, -53.5), PI * 0.5, "fishing_blue"], [Vector2(-38.0, -16.5), -PI * 0.5, "fishing_blue"]]:
		var c: Vector2 = fb[0]
		_mesh_node(node, "MarketBoat_%d" % int(c.x), kinds[fb[2]], Transform3D(Basis(Vector3.UP, fb[1]).scaled(Vector3.ONE * PROP_SCALE), Vector3(c.x, WATER_Y, c.y)), true, 700.0)
	_mesh_node(node, "TugAlongside", kinds["tug"], Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * PROP_SCALE), Vector3(QUAY_E_X - 9.0, WATER_Y, 118.0)), true, 900.0)


var _boat_meshes := {}

## Boats under way (SeaBoat.gd: placed from the wall clock, so peers agree): [name, kind, loop middle (x, z), the
## straights' bearing (degrees), straight length, turn radius, speed, phase, heel, box top]
const BOATS_UNDER_WAY := [
	# Between the south pier and the breakwater, clear of the marina's last pontoon (it ends at x -278).
	["TrawlerInner", "fishing_red", Vector2(-110.0, 166.0), 90.0, 200.0, 13.0, 4.0, 0.0, 0.0, 4.5],
	["TugOutside", "tug", Vector2(120.0, 380.0), 90.0, 320.0, 50.0, 3.5, 150.0, 0.0, 6.0],
	["TrawlerOut", "fishing_blue", Vector2(-300.0, 320.0), 90.0, 300.0, 40.0, 5.0, 300.0, 0.0, 4.5],
	["YachtWest", "sail_blue", Vector2(-650.0, 460.0), 80.0, 500.0, 50.0, 4.0, 0.0, 8.0, 3.0],
	["YachtEast", "sail_red", Vector2(600.0, 420.0), 100.0, 400.0, 60.0, 4.5, 380.0, 8.0, 3.0],
]

## The cruise liners (models/boats/*_CruiseShip.glb, 360m long, bows toward -z in the files): one at anchor off the
## harbour mouth, broadside to the course, one cruising past further out. [name, model, middle (x, z), bearing
## (degrees), straight length, turn radius, speed, phase, swing at anchor (degrees)]
const CRUISE_SHIPS := [
	["AuroraPearl", "res://models/boats/AuroraPearl_CruiseShip.glb", Vector2(-150.0, 570.0), 90.0, 0.0, 0.0, 0.0, 0.0, 4.0],
	["MeridianAstra", "res://models/boats/MeridianAstra_CruiseShip.glb", Vector2(300.0, 900.0), 90.0, 1200.0, 180.0, 6.0, 900.0, 0.0],
]
## The waterline over the models' keel: in the boot-topping band (navy below it, white above).
const CRUISE_DRAFT := 10.8
## The far version leaves out parts smaller than this (loungers, cushions, mullions, planters), drawn past CRUISE_NEAR.
const CRUISE_SMALL := 3.0
const CRUISE_NEAR := 700.0

func _build_boats(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "BoatsUnderWay"
	root.add_child(node)
	var script: Script = load("res://SeaBoat.gd")
	for b in BOATS_UNDER_WAY:
		var scene := _boat_scene(b[1])
		var boat := Node3D.new()
		boat.set_script(script)
		boat.name = b[0]
		var c: Vector2 = b[2]
		boat.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(b[3])), Vector3(c.x, WATER_Y, c.y))
		boat.set("model", scene)
		boat.set("model_scale", PROP_SCALE)
		boat.set("draft", 0.0)
		boat.set("length", b[4])
		boat.set("turn_radius", b[5])
		boat.set("speed", b[6])
		boat.set("phase", b[7])
		boat.set("heel_deg", b[8])
		boat.set("wind", Vector3(0.82, 0, 0.57))
		boat.set("body_top", b[9])
		_boat_sounds(boat, String(b[1]))
		node.add_child(boat)
	for cs in CRUISE_SHIPS:
		var scene := _cruise_scene(cs[1], String(cs[0]).to_snake_case())
		var ship := Node3D.new()
		ship.set_script(script)
		ship.name = cs[0]
		var c2: Vector2 = cs[2]
		ship.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(cs[3])), Vector3(c2.x, WATER_Y, c2.y))
		ship.set("model", scene)
		ship.set("model_scale", 1.0)
		ship.set("draft", CRUISE_DRAFT)
		ship.set("length", cs[4])
		ship.set("turn_radius", cs[5])
		ship.set("speed", cs[6])
		ship.set("phase", cs[7])
		ship.set("swing_deg", cs[8])
		# A liner hardly moves on a harbour's swell.
		ship.set("bob_height", 0.06)
		ship.set("roll_deg", 0.15)
		ship.set("pitch_deg", 0.05)
		ship.set("body_top", 30.0)
		if float(cs[6]) > 0.0:
			# The liner under way sounds her horn now and then: the tug's, an octave and more down, heard across the bay.
			ship.set("horns", [load(TUG_HORNS[0]), load(TUG_HORNS[1])] as Array[AudioStream])
			ship.set("horn_db", PackedFloat32Array([HORN_LEVEL - TUG_HORN_RMS[0] + 4.0, HORN_LEVEL - TUG_HORN_RMS[1] + 4.0]))
			ship.set("horn_unit", 400.0)
			ship.set("wake_width", 34.0)
			ship.set("wake_spread", 1.6)
			ship.set("wake_seconds", 40.0)
			ship.set("horn_pitch", 0.48)
			ship.set("horn_gap", Vector2(100.0, 190.0))
			ship.set("horn_y", 60.0)
		node.add_child(ship)
	# The tug alongside the terminal idles.
	var idle := AudioStreamPlayer3D.new()
	idle.name = "TugAlongsideEngine"
	idle.stream = load(DIESEL)
	idle.bus = &"SFX"
	idle.volume_db = ENGINE_LEVEL - DIESEL_RMS - 4.0
	idle.unit_size = 35.0
	idle.max_distance = 500.0
	idle.pitch_scale = 0.72
	idle.autoplay = true
	idle.position = Vector3(QUAY_E_X - 9.0, WATER_Y + 3.0, 118.0)
	node.add_child(idle)


## A liner's model merged into one mesh per material, turned so its bow is along +z (SeaBoat's convention): the
## files hold about 1,500 meshes each, a draw call apiece. A second mesh leaves out the small parts for the distance.
## Both are saved in a scene for SeaBoat (`harbor_cruise_<name>.tscn`).
func _cruise_scene(model_path: String, key: String) -> PackedScene:
	var src: Node3D = (load(model_path) as PackedScene).instantiate()
	var turn := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	var groups := [{}, {}]
	var mats := {}
	for mi in src.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		var t := Transform3D.IDENTITY
		var c: Node = m
		while c != src and c != null:
			if c is Node3D:
				t = (c as Node3D).transform * t
			c = c.get_parent()
		t = turn * t
		var box: AABB = t * m.mesh.get_aabb()
		var small: bool = maxf(box.size.x, maxf(box.size.y, box.size.z)) < CRUISE_SMALL
		var nb: Basis = t.basis.inverse().transposed()
		for i in m.mesh.get_surface_count():
			var mat: Material = m.get_active_material(i)
			var mk: String = String(mat.resource_name) if mat else "none"
			mats[mk] = mat
			var arr: Array = m.mesh.surface_get_arrays(i)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var norms = arr[Mesh.ARRAY_NORMAL]
			var idx = arr[Mesh.ARRAY_INDEX]
			for g in ([0] if small else [0, 1]):
				if not groups[g].has(mk):
					groups[g][mk] = [PackedVector3Array(), PackedVector3Array(), PackedInt32Array()]
				var dst: Array = groups[g][mk]
				var base: int = (dst[0] as PackedVector3Array).size()
				for k in range(verts.size()):
					dst[0].append(t * verts[k])
					dst[1].append((nb * (norms[k] as Vector3)).normalized() if norms != null and (norms as PackedVector3Array).size() > k else Vector3.UP)
				if idx != null and (idx as PackedInt32Array).size() > 0:
					for k2 in (idx as PackedInt32Array):
						dst[2].append(base + k2)
				else:
					for k3 in range(verts.size()):
						dst[2].append(base + k3)
	src.free()
	var root := Node3D.new()
	root.name = "Liner"
	for g in range(2):
		var mesh := ArrayMesh.new()
		var keys: Array = groups[g].keys()
		keys.sort()
		for mk in keys:
			var d: Array = groups[g][mk]
			var a := []
			a.resize(Mesh.ARRAY_MAX)
			a[Mesh.ARRAY_VERTEX] = d[0]
			a[Mesh.ARRAY_NORMAL] = d[1]
			a[Mesh.ARRAY_INDEX] = d[2]
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
			mesh.surface_set_material(mesh.get_surface_count() - 1, mats[mk])
		var mi2 := MeshInstance3D.new()
		mi2.name = "Near" if g == 0 else "Far"
		mi2.mesh = _save_res(mesh, "cruise_%s_%s" % [key, mi2.name.to_lower()])
		mi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if g == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if g == 0:
			mi2.visibility_range_end = CRUISE_NEAR
			mi2.visibility_range_end_margin = 40.0
		else:
			mi2.visibility_range_begin = CRUISE_NEAR
			mi2.visibility_range_begin_margin = 40.0
		mi2.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		root.add_child(mi2)
		mi2.owner = root
		print("  %s %s: %d surfaces" % [key, mi2.name, mesh.get_surface_count()])
	var ps := PackedScene.new()
	ps.pack(root)
	var path := "res://generated/" + RES_PREFIX + "cruise_" + key + ".tscn"
	ResourceSaver.save(ps, path)
	root.free()
	return load(path)


var _boat_scenes := {}

## A boat's mesh as a scene of its own (SeaBoat instantiates its model), saved beside the meshes.
func _boat_scene(kind: String) -> PackedScene:
	if _boat_scenes.has(kind):
		return _boat_scenes[kind]
	var r := Node3D.new()
	r.name = "Boat"
	var mi := MeshInstance3D.new()
	mi.name = "Hull"
	mi.mesh = _boat_meshes[kind]
	r.add_child(mi)
	mi.owner = r
	var ps := PackedScene.new()
	ps.pack(r)
	var path := "res://generated/" + RES_PREFIX + "boat_" + kind + ".tscn"
	ResourceSaver.save(ps, path)
	r.free()
	_boat_scenes[kind] = load(path)
	return _boat_scenes[kind]


# --------------------------------------------------------------------------------------
#  Gulls (BirdFlock.gd, Bloombay Dunes' gulls and their calls)
# --------------------------------------------------------------------------------------

const GULL_MODEL := "res://models/animals/seagull/source/Sketchfab_2022_02_14_15_08_30.blend"
const GULL_TEXTURE := "res://models/animals/seagull/textures/Seagull-Base_Color.png"
const GULL_SCALE := 0.3
const GULL_CALLS := ["res://sounds/beach/Seagulls_1.wav", "res://sounds/beach/Seagulls_2.wav",
		"res://sounds/beach/Seagulls_3.wav", "res://sounds/beach/Seagulls_4.wav", "res://sounds/beach/Seagulls_5.wav"]
const GULL_CALL_RMS := [-30.7, -28.9, -37.5, -39.5, -21.4]
const GULL_CALL_LEVEL := -23.0
const GULL_CALL_UNIT := 30.0
## [middle (x, z), height, radius, speed, clockwise, gulls]: over the fish market, the inner basin, the ship and the
## marina's boats.
const GULL_FLOCKS := [
	[Vector2(-5.0, -40.0), 26.0, 40.0, 8.5, false, 5],
	[Vector2(20.0, 85.0), 30.0, 70.0, 9.5, true, 4],
	[Vector2(250.0, -20.0), 58.0, 80.0, 10.0, false, 5],
	[Vector2(-310.0, 30.0), 30.0, 60.0, 9.0, true, 4],
]

func _build_gulls(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "GullFlocks"
	root.add_child(node)
	var script: Script = load("res://BirdFlock.gd")
	var model: PackedScene = load(GULL_MODEL)
	for i in GULL_FLOCKS.size():
		var f: Array = GULL_FLOCKS[i]
		var c: Vector2 = f[0]
		var flock := Node3D.new()
		flock.set_script(script)
		flock.name = "Flock%d" % (i + 1)
		flock.set("model", model)
		flock.set("albedo_texture", load(GULL_TEXTURE))
		flock.set("model_yaw_deg", -90.0)
		flock.set("model_centre", Vector3.ZERO)
		flock.set("drop_nodes", PackedStringArray(["Camera", "Light"]))
		flock.set("animation_name", "ArmatureAction")
		flock.set("bird_scale", GULL_SCALE)
		flock.set("copies", f[5])
		flock.set("spread", Vector3(16.0, 4.0, 16.0))
		flock.set("radius", f[2])
		flock.set("speed", f[3])
		flock.set("clockwise", f[4])
		flock.set("flap_speed", 0.8)
		var calls: Array[AudioStream] = []
		var gains := PackedFloat32Array()
		for k in GULL_CALLS.size():
			calls.append(load(GULL_CALLS[k]))
			gains.append(GULL_CALL_LEVEL - float(GULL_CALL_RMS[k]))
		flock.set("calls", calls)
		flock.set("call_db", gains)
		flock.set("call_unit_size", GULL_CALL_UNIT)
		flock.position = Vector3(c.x, f[1], c.y)
		node.add_child(flock)


# --------------------------------------------------------------------------------------
#  Downtown's towers
# --------------------------------------------------------------------------------------
## Blue glass, as Bloombay's skyline reads from South Beach.
const TOWER_GLASS := [Color(0.36, 0.54, 0.76), Color(0.30, 0.48, 0.72), Color(0.44, 0.60, 0.80), Color(0.26, 0.42, 0.62), Color(0.40, 0.62, 0.74)]

## A tower over a block: a podium of offices (punched windows over shop fronts) and on it a glass shaft whose plan is a
## square, a chamfered square, an octagon or a round drum (12 sides), stepping back once or twice toward the top, a
## plain crown, and on some a mast. `w` across the shaft, `storeys` from the podium's roof.
func _add_tower(x: float, z: float, w: float, storeys: int, rng: RandomNumberGenerator) -> void:
	var g := _land_h(x, z)
	var pod := w * rng.randf_range(1.25, 1.5)
	var cells := _footprint_cells(x, z, pod + 4.0, pod + 4.0, 0.0)
	for c in cells:
		if _occupied.has(c):
			return
	for c in cells:
		_occupied[c] = true
	var t := _town_tile(x, z)
	var walls: SurfaceTool = t["walls"]
	var yaw: float = (0.0 if rng.randf() < 0.6 else PI * 0.25) + rng.randf_range(-0.05, 0.05)
	var col: Color = TOWER_GLASS[rng.randi() % TOWER_GLASS.size()]
	var stone: Color = [Color(0.82, 0.80, 0.76), Color(0.70, 0.72, 0.74), Color(0.86, 0.84, 0.78)][rng.randi() % 3]
	var base: float = g - 2.0
	# The podium.
	var pod_h: float = SHOP_H + STOREY * float(rng.randi_range(1, 3))
	_prism(walls, x, z, _plan_shape(0, pod * 0.5), yaw, base, g + pod_h, g, stone, 0.0, rng.randi() % 4)
	t["count_walls"] += 1
	# The shaft and its setbacks.
	var shape: int = rng.randi() % 4
	var r: float = w * 0.5
	var y0: float = g + pod_h
	var total: float = float(storeys) * STOREY
	var tiers: int = rng.randi_range(1, 3)
	var shares := [1.0] if tiers == 1 else ([0.72, 0.28] if tiers == 2 else [0.6, 0.25, 0.15])
	for k in range(tiers):
		var y1: float = y0 + total * float(shares[k])
		_prism(walls, x, z, _plan_shape(shape, r), yaw, y0, y1, g, col, 1.0, 0)
		# A plain band where it steps back.
		_prism(walls, x, z, _plan_shape(shape, r + 0.4), yaw, y1 - 0.9, y1, g, stone, 0.7, 0)
		y0 = y1
		r *= rng.randf_range(0.72, 0.85)
	# The crown: a plant storey in plain concrete, then a mast with a red light on some.
	_prism(walls, x, z, _plan_shape(shape, r * 0.8), yaw, y0, y0 + 4.5, g, stone.darkened(0.1), 0.7, 0)
	if rng.randf() < 0.45:
		_prism(walls, x, z, _plan_shape(1, 0.7), yaw, y0 + 4.5, y0 + 4.5 + rng.randf_range(14.0, 34.0), g, Color(0.75, 0.76, 0.78), 0.7, 0)


## A tower's plan: 0 a square, 1 a chamfered square, 2 an octagon, 3 a round drum, `r` its half width.
func _plan_shape(kind: int, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match kind:
		0:
			pts = PackedVector2Array([Vector2(-r, -r), Vector2(r, -r), Vector2(r, r), Vector2(-r, r)])
		1:
			var c := r * 0.3
			pts = PackedVector2Array([Vector2(-r + c, -r), Vector2(r - c, -r), Vector2(r, -r + c), Vector2(r, r - c), Vector2(r - c, r), Vector2(-r + c, r), Vector2(-r, r - c), Vector2(-r, -r + c)])
		_:
			var n: int = 8 if kind == 2 else 12
			for i in range(n):
				var a := TAU * (float(i) + 0.5) / float(n)
				pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


## A prism of a plan polygon (local, counter-clockwise) between y0 and y1, turned yaw, at (x, z): walls in the town's
## facade convention (UV.x metres along stretched to whole bays, UV.y up from the street at `street`; COLOR.a the
## facade: 0 windows, 0.7 plain, 1 glass) and a flat roof.
func _prism(st: SurfaceTool, x: float, z: float, plan: PackedVector2Array, yaw: float, y0: float, y1: float, street: float, col: Color, kind: float, style: int) -> void:
	var b := Basis(Vector3.UP, yaw)
	var n := plan.size()
	var c := col
	c.a = kind
	var pts: Array = []
	for p in plan:
		pts.append(b * Vector3(p.x, 0, p.y) + Vector3(x, 0, z))
	var u := 0.0
	for i in range(n):
		var a: Vector3 = pts[i]
		var e: Vector3 = pts[(i + 1) % n]
		var mid: Vector3 = (a + e) * 0.5
		var out := Vector3(mid.x - x, 0, mid.z - z).normalized()
		var edge := Vector3(e.x - a.x, 0, e.z - a.z)
		var nrm := edge.cross(Vector3.UP).normalized()
		if nrm.dot(out) < 0.0:
			nrm = -nrm
		var length: float = edge.length()
		var half_bay: float = BAY * 0.5
		var ul: float = maxf(1.0, round(length / half_bay)) * half_bay
		var q := [Vector3(a.x, y0, a.z), Vector3(e.x, y0, e.z), Vector3(e.x, y1, e.z), Vector3(a.x, y1, a.z)]
		var uv := [Vector2(u, y0 - street), Vector2(u + ul, y0 - street), Vector2(u + ul, y1 - street), Vector2(u, y1 - street)]
		var s1: float = maxf(1.0, round(length / (BAY * 1.5))) * BAY * 1.5
		var uv2 := [Vector2(0, style), Vector2(s1, style), Vector2(s1, style), Vector2(0, style)]
		_wall_quad(st, q, uv, uv2, nrm, c)
		u += ul
	var roof_c := col.darkened(0.25)
	roof_c.a = 0.0
	var centre := Vector3(x, y1, z)
	for i in range(n):
		var a2: Vector3 = pts[i]
		var e2: Vector3 = pts[(i + 1) % n]
		_wall_quad(st, [centre, Vector3(a2.x, y1, a2.z), Vector3(e2.x, y1, e2.z), centre], [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO],
				[Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO], Vector3.UP, roof_c)


# --------------------------------------------------------------------------------------
#  The cathedral
# --------------------------------------------------------------------------------------
## The west front's middle (x, z) and the way it faces: south, over the old town's roofs toward the marina and the south
## pier, where the low sun lights it (facing east it stood dark against the light).
const CATHEDRAL_AT := Vector2(-480.0, 40.0)
const CATHEDRAL_YAW := 0.0

func _build_cathedral(node: Node3D) -> void:
	var b := Basis(Vector3.UP, CATHEDRAL_YAW)
	var front := Vector3(CATHEDRAL_AT.x, 0, CATHEDRAL_AT.y)
	# The floor halfway between the ground at the front and at the apse: the podium stands out of the slope in front
	# (a flight of steps up to the portals), the apse sits into it behind.
	var g_lo := INF
	var g_front := _land_h(front.x, front.z)
	var g_back := _land_h((front + b * Vector3(0, 0, -78.0 * PROP_SCALE)).x, (front + b * Vector3(0, 0, -78.0 * PROP_SCALE)).z)
	for lx in [-31.0, 0.0, 31.0]:
		for lz in [10.0, -36.0, -78.0]:
			var p: Vector3 = front + b * Vector3(lx, 0, lz) * PROP_SCALE
			g_lo = minf(g_lo, _land_h(p.x, p.z))
	var floor_y: float = (g_front + g_back) * 0.5
	var foot: float = (g_lo - floor_y) / PROP_SCALE - 1.5
	var pk := PortKit.new_port_kit(1.0)
	var kit := {}
	PortKit.cathedral(pk, kit, foot)
	var xf := Transform3D(b.scaled(Vector3.ONE * PROP_SCALE), Vector3(front.x, floor_y, front.z))
	_mesh_node(node, "Cathedral", _commit_kit(pk, kit, "cathedral"), xf)
	var mid: Vector3 = front + b * Vector3(0, 0, -36.0) * PROP_SCALE
	for c in _footprint_cells(mid.x, mid.z, 66.0 * PROP_SCALE, 96.0 * PROP_SCALE, CATHEDRAL_YAW):
		_occupied[c] = true
	_solid(node, "CathedralSolid", [_box_shape(Vector3(62.0, 38.0, 72.0) * PROP_SCALE, Transform3D(b, Vector3(mid.x, floor_y + 19.0 * PROP_SCALE, mid.z)))])
	print("  cathedral: floor %.1fm (ground %.1f in front, %.1f behind), towers to %.0fm" % [floor_y, g_front, g_back, floor_y + 67.0 * PROP_SCALE])


# --------------------------------------------------------------------------------------
#  The boats' sounds (sounds/harbor/: SeaBoat plays them on the hull)
# --------------------------------------------------------------------------------------
const DIESEL := "res://sounds/harbor/boat_diesel_engine.wav"
const DIESEL_RMS := -18.4
const TUG_HORNS := ["res://sounds/harbor/tug_boat_horn.wav", "res://sounds/harbor/tug_boat_horn2.wav"]
const TUG_HORN_RMS := [-28.1, -30.2]
## An engine is brought to this RMS at its unit size (about a cart's engine heard from behind), a horn to HORN_LEVEL at its.
const ENGINE_LEVEL := -16.0
const HORN_LEVEL := -10.0

func _boat_sounds(boat: Node3D, kind: String) -> void:
	if kind.begins_with("sail"):
		# Under sail: quiet, a slim wake.
		boat.set("wake_width", 4.0)
		boat.set("wake_spread", 0.45)
		return
	var tug: bool = kind == "tug"
	boat.set("engine_sound", load(DIESEL))
	boat.set("engine_db", ENGINE_LEVEL - DIESEL_RMS + (2.0 if tug else 0.0))
	boat.set("engine_unit", 55.0 if tug else 40.0)
	boat.set("wake_width", 8.0 if tug else 6.0)
	boat.set("wake_spread", 0.7)
	boat.set("engine_pitch", 0.85 if tug else 0.95 + 0.17 * float(absi(hash(String(boat.name))) % 100) / 100.0)
	if tug:
		boat.set("horns", [load(TUG_HORNS[0]), load(TUG_HORNS[1])] as Array[AudioStream])
		boat.set("horn_db", PackedFloat32Array([HORN_LEVEL - TUG_HORN_RMS[0], HORN_LEVEL - TUG_HORN_RMS[1]]))
		boat.set("horn_unit", 160.0)
		boat.set("horn_gap", Vector2(35.0, 80.0))
		boat.set("horn_y", 8.0)


## A breakwater's head: a round concrete block HEAD_R across (its top HEAD_TOP, the light's foot), rising out of the water
## with the tide line on it, a railing round its seaward side, bollards; under it a roundhead of granite rubble wrapping
## the mound's end, with tetrapods piled round the seaward half (`back` points back along the breakwater).
const HEAD_R := 10.0
const HEAD_TOP := MOUND_CREST - 0.3

func _roundhead(node: Node3D, rock: Material, noise: FastNoiseLite, tip: Vector2, back: Vector2, xfs: Array, rng: RandomNumberGenerator, pk: PropKit, kit: Dictionary) -> void:
	# The rubble cone: rings of the mound's own profile, all the way round.
	var prof := [Vector2(MOUND_HALF + 24.0, SEABED_Y), Vector2(MOUND_HALF + 10.0, WATER_Y - 0.6), Vector2(HEAD_R + 2.5, MOUND_CREST - 2.4),
			Vector2(HEAD_R - 0.5, MOUND_CREST - 2.2)]
	var segs := 36
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring := func(i: int, j: int) -> Vector3:
		var a: float = TAU * float(i % segs) / float(segs)
		var pr: Vector2 = prof[j]
		var q := tip + Vector2(cos(a), sin(a)) * pr.x
		var y: float = pr.y + (noise.get_noise_2d(q.x, q.y) * 0.9 if j > 0 else 0.0)
		return Vector3(q.x, y, q.y)
	for i in range(segs):
		for j in range(prof.size() - 1):
			var v00: Vector3 = ring.call(i, j)
			var v10: Vector3 = ring.call(i + 1, j)
			var v01: Vector3 = ring.call(i, j + 1)
			var v11: Vector3 = ring.call(i + 1, j + 1)
			for t in [[v00, v10, v11], [v00, v11, v01]]:
				var va: Vector3 = t[0]
				var vb: Vector3 = t[1]
				var vc: Vector3 = t[2]
				if (vc - va).cross(vb - va).y < 0.0:
					var tmp := vb
					vb = vc
					vc = tmp
				for v in [va, vb, vc]:
					st.set_color(Color(0.85 + 0.15 * noise.get_noise_2d(v.x * 3.0, v.z * 3.0), clampf((v.y - WATER_Y) / 2.5, 0.0, 1.0), 0, 1))
					st.add_vertex(v)
	st.index()
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, rock)
	_mesh_node(node, "Roundhead_%d" % int(tip.x), _save_res(mesh, "roundhead_%d" % int(tip.x + 1000.0)))
	# Tetrapods in three rings round the seaward half and the sides.
	for row in range(3):
		var r: float = HEAD_R + 3.0 + float(row) * 3.6
		var n: int = int(TAU * r / 3.6)
		for k in range(n):
			var a: float = TAU * (float(k) + rng.randf_range(-0.3, 0.3)) / float(n)
			var d := Vector2(cos(a), sin(a))
			if d.dot(back) > 0.55:
				continue
			var q := tip + d * (r + rng.randf_range(-0.6, 0.6))
			var y: float = lerpf(MOUND_CREST - 2.0, WATER_Y - 0.4, float(row) / 2.4) + rng.randf_range(-0.3, 0.4)
			var basis := Basis(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized(), rng.randf() * TAU)
			xfs.append(Transform3D(basis.scaled(Vector3.ONE * PROP_SCALE * rng.randf_range(0.9, 1.15)), Vector3(q.x, y, q.y)))
	# The block: a drum of concrete from under the water to the light's foot, a coping, its deck.
	var c := Vector3(tip.x, 0, tip.y)
	pk.lathe(kit, "pile", c + Vector3(0, WATER_Y - 3.0, 0), [Vector2(0.001, 0.0), Vector2(HEAD_R + 0.4, 0.0), Vector2(HEAD_R + 0.4, 0.6), Vector2(HEAD_R, 0.8),
			Vector2(HEAD_R, HEAD_TOP - WATER_Y + 2.6), Vector2(HEAD_R + 0.3, HEAD_TOP - WATER_Y + 2.7), Vector2(HEAD_R + 0.3, HEAD_TOP - WATER_Y + 3.0),
			Vector2(0.001, HEAD_TOP - WATER_Y + 3.0)], 40, Color(0.74, 0.72, 0.68), false)
	# A railing round the seaward side, bollards on the harbour side, a ladder down to the water.
	var ring_r: float = HEAD_R - 0.4
	var prev := Vector3.ZERO
	var had := false
	for k in range(41):
		var a: float = TAU * float(k) / 40.0
		var d := Vector2(cos(a), sin(a))
		var p := Vector3(tip.x + d.x * ring_r, HEAD_TOP, tip.y + d.y * ring_r)
		if d.dot(back) > 0.45:
			had = false
			continue
		pk.tube(kit, "steel", p, p + Vector3(0, 1.7, 0), 0.05, 0.05, 6, Color(0.86, 0.66, 0.12), false)
		if had:
			pk.tube(kit, "steel", prev + Vector3(0, 1.7, 0), p + Vector3(0, 1.7, 0), 0.05, 0.05, 6, Color(0.86, 0.66, 0.12), false)
			pk.tube(kit, "steel", prev + Vector3(0, 0.85, 0), p + Vector3(0, 0.85, 0), 0.04, 0.04, 6, Color(0.86, 0.66, 0.12), false)
		prev = p
		had = true
	var side := Vector2(back.y, -back.x)
	for sgn in [-1.0, 1.0]:
		var bp: Vector2 = tip + (side * sgn + back * 0.35).normalized() * (HEAD_R - 1.4)
		pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * PROP_SCALE), Vector3(bp.x, HEAD_TOP, bp.y)))
		PortKit.bollard(pk, kit, Vector3.ZERO)
	pk.reset_frame()
