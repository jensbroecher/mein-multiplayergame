extends Node
## The arena levels' shared generator (regenerate_arena_hexbowl.gd, regenerate_arena_ctf.gd): the level's frame (Level.gd,
## Players, PlayerSpawner, SpawnPoints, the ArenaGame node), the sky and light, solid boxes and meshes with their
## bodies (the driven ones in the "track_surface" group with a `surface` meta, so PlayerCart counts them as track),
## resources saved to generated/<stem>_*, and the save. A subclass sets `level_name`, `level_path`, `stem` in
## `_configure()` and builds in `_build(root)`; `_ready` runs it and quits.

var level_name := "ArenaLevel"
var level_path := "res://levels/ArenaLevel.tscn"
var stem := "arena"
var t0 := 0

var root: Node3D
var game: Node3D
var spawns: Node3D


func _ready() -> void:
	t0 = Time.get_ticks_msec()
	_configure()
	print("=== %s (arena) Level Generation ===" % level_name)
	_clear_generated()
	root = Node3D.new()
	root.name = level_name
	root.set_script(load("res://levels/Level.gd"))
	var players := Node3D.new()
	players.name = "Players"
	root.add_child(players)
	var sp := MultiplayerSpawner.new()
	sp.name = "PlayerSpawner"
	sp.set("_spawnable_scenes", PackedStringArray(["uid://cart123"]))
	sp.spawn_path = NodePath("../Players")
	sp.spawn_limit = 6
	root.add_child(sp)
	spawns = Node3D.new()
	spawns.name = "SpawnPoints"
	root.add_child(spawns)
	game = Node3D.new()
	game.name = "ArenaGame"
	game.set_script(load("res://ArenaGame.gd"))
	root.add_child(game)
	_build(root)
	_set_owner_recursive(root, root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("pack failed: %d" % err)
		get_tree().quit(1)
		return
	err = ResourceSaver.save(packed, level_path)
	if err != OK:
		push_error("save failed: %d" % err)
		get_tree().quit(1)
		return
	print("Saved %s in %.1fs" % [level_path, (Time.get_ticks_msec() - t0) * 0.001])
	root.free()
	get_tree().quit(0)


func _configure() -> void:
	pass


func _build(_root: Node3D) -> void:
	pass


func _clear_generated() -> void:
	var d := DirAccess.open("res://generated/")
	if d == null:
		DirAccess.make_dir_absolute("res://generated/")
		return
	var n := 0
	for f in d.get_files():
		if f.begins_with(stem + "_"):
			d.remove(f)
			n += 1
	print("  cleared %d old files" % n)


func _save_res(res: Resource, res_name: String) -> Resource:
	var file_path := "res://generated/" + stem + "_" + res_name + ".res"
	res.take_over_path(file_path)
	ResourceSaver.save(res, file_path)
	return load(file_path)


func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	if node != scene_root:
		node.owner = scene_root
	for child in node.get_children():
		if child.owner != null and child.owner != scene_root:
			continue
		# Scenes placed whole (bumpers built as internal children, item boxes, goal nets) keep their own insides.
		if child.scene_file_path != "" and child != scene_root:
			child.owner = scene_root
			continue
		_set_owner_recursive(child, scene_root)


# ======================================================================================
#  Sky and light
# ======================================================================================

func _environment(p: Dictionary) -> void:
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://sky_tropical_cumulus.gdshader")
	sm.set_shader_parameter("sky_top", p["sky_top"])
	sm.set_shader_parameter("sky_horizon", p["sky_horizon"])
	sm.set_shader_parameter("ground_horizon", p["haze"])
	sm.set_shader_parameter("ground_bottom", p["ground_bottom"])
	sm.set_shader_parameter("sky_curve", 0.45)
	sm.set_shader_parameter("horizon_haze", p["haze"])
	sm.set_shader_parameter("haze_strength", 0.9)
	sm.set_shader_parameter("haze_height", 0.16)
	sm.set_shader_parameter("sun_tint", p["sun_color"])
	sm.set_shader_parameter("sun_disc_degrees", 1.1)
	sm.set_shader_parameter("sun_glow", p.get("sun_glow", 0.4))
	sm.set_shader_parameter("sun_horizon_tint", p["sun_color"])
	sm.set_shader_parameter("sun_horizon_glow", 0.0)
	sm.set_shader_parameter("cloud_lit", p["cloud_lit"])
	sm.set_shader_parameter("cloud_shade", p["cloud_shade"])
	sm.set_shader_parameter("cloud_coverage", p.get("cloud_coverage", 0.35))
	sm.set_shader_parameter("cloud_opacity", 0.85)
	sm.set_shader_parameter("cloud_scale", 1.2)
	sm.set_shader_parameter("cloud_seed", p.get("cloud_seed", 7.7))
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = p["ambient"]
	env.ambient_light_color = p.get("ambient_color", Color(1, 1, 1))
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = p.get("exposure", 1.05)
	env.glow_enabled = true
	env.glow_intensity = p.get("glow", 0.4)
	env.glow_bloom = p.get("bloom", 0.05)
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = p["haze"]
	env.fog_light_energy = 1.0
	env.fog_density = 1.0
	env.fog_depth_begin = p["fog_begin"]
	env.fog_depth_end = p["fog_end"]
	env.fog_depth_curve = 1.4
	env.fog_sky_affect = p.get("fog_sky", 0.1)
	env.fog_aerial_perspective = 0.3
	env_node.environment = env
	root.add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = Vector3(p["sun_pitch"], p["sun_yaw"], 0.0)
	sun.light_color = p["sun_color"]
	sun.light_energy = p["sun_energy"]
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = p.get("shadow_distance", 260.0)
	sun.directional_shadow_split_1 = 0.08
	sun.directional_shadow_split_2 = 0.22
	sun.directional_shadow_split_3 = 0.5
	root.add_child(sun)


# ======================================================================================
#  Materials, bodies, meshes
# ======================================================================================

var _mats := {}


func mat(key: String, col: Color, rough := 0.7, metal := 0.0, emit := 0.0) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	if col.a < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m


func tex_mat(key: String, tex_path: String, tint: Color, scale: float, rough := 0.85) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(tex_path)
	m.albedo_color = tint
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / scale
	m.roughness = rough
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mats[key] = m
	return m


## A solid box (its mesh and body together): `track` makes it driven-on ground (group "track_surface").
func box(parent: Node, n: String, size: Vector3, xf: Transform3D, m: Material, surface := "rock", track := false,
		visible_mesh := true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = n
	body.transform = xf
	body.set_meta(&"surface", surface)
	if track:
		body.add_to_group(&"track_surface", true)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	if visible_mesh:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		mi.material_override = m
		body.add_child(mi)
	parent.add_child(body)
	return body


## A box mesh with no body (dressing out of reach, or under a body of its own).
func deco_box(parent: Node, size: Vector3, xf: Transform3D, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.transform = xf
	mi.material_override = m
	parent.add_child(mi)
	return mi


func cyl(parent: Node, top: float, bottom: float, h: float, xf: Transform3D, m: Material, segs := 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = h
	cm.radial_segments = segs
	mi.mesh = cm
	mi.transform = xf
	mi.material_override = m
	parent.add_child(mi)
	return mi


## A transform at `at` whose -z looks at `look` in the plan.
func facing(at: Vector3, look: Vector3) -> Transform3D:
	var d := look - at
	d.y = 0.0
	if d.length() < 0.01:
		d = Vector3(0, 0, -1)
	return Transform3D(Basis.looking_at(d.normalized(), Vector3.UP), at)


## A spawn point (the order the players are placed in: Level._add_player).
func spawn(at: Vector3, look: Vector3) -> void:
	var m := Marker3D.new()
	m.name = "Spawn%d" % (spawns.get_child_count() + 1)
	m.transform = facing(at, look)
	spawns.add_child(m)


func bumper(parent: Node, n: String, xf: Transform3D, radius := 1.7, bar := 0.0, col := Color(1.0, 0.3, 0.75), kick := 17.0) -> Node3D:
	var b := Node3D.new()
	b.name = n
	b.set_script(load("res://ArenaBumper.gd"))
	b.set("radius", radius)
	b.set("bar_length", bar)
	b.set("color", col)
	b.set("kick", kick)
	b.transform = xf
	parent.add_child(b)
	return b


func fan(parent: Node, n: String, xf: Transform3D, launch := 21.0, push := 0.0, radius := 3.4, col := Color(0.3, 0.9, 1.0)) -> Node3D:
	var f := Node3D.new()
	f.name = n
	f.set_script(load("res://ArenaFan.gd"))
	f.set("radius", radius)
	f.set("launch", launch)
	f.set("push", push)
	f.set("color", col)
	f.transform = xf
	parent.add_child(f)
	return f


func item_spot(at: Vector3) -> void:
	var holder := game.get_node_or_null("ItemSpots")
	if holder == null:
		holder = Node3D.new()
		holder.name = "ItemSpots"
		game.add_child(holder)
	var m := Marker3D.new()
	m.name = "Spot%d" % (holder.get_child_count() + 1)
	m.position = at - game.position
	holder.add_child(m)


func boost_pad(parent: Node, n: String, at: Vector3, look: Vector3) -> void:
	var b: Node3D = (load("res://BoostPad.tscn") as PackedScene).instantiate()
	b.name = n
	b.transform = facing(at + Vector3(0, 0.05, 0), look)
	parent.add_child(b)


func kicker(parent: Node, n: String, toe: Vector3, look: Vector3, length := 9.0, height := 2.2, width := 9.0, curve := 0.45) -> void:
	var j: Node3D = (load("res://WoodenRamp.tscn") as PackedScene).instantiate()
	j.name = n
	j.transform = facing(toe, look)
	j.set("length", length)
	j.set("height", height)
	j.set("width", width)
	j.set("curve", curve)
	j.set("face_lap", false)
	parent.add_child(j)
