extends TextureRect
## A main menu tile's picture as a small live 3D scene (MainMenu._add_tile with a `scene:<kind>` file):
## its own World3D in a SubViewport whose texture this TextureRect draws, built in code, every motion a
## function of the clock (`seek`). The cars are the game's own (generated/cars/*.tscn, factory paint); the
## Mudrunner, the game's "main character", is in every scene with cars.
##
## Kinds: single, splitscreen, multiplayer, spectator, inspect (the drone, no cars), options (a laptop, a
## pro transmitter and the Mudrunner on a set-up stand), grand_prix (the podium), time_trial (a ghost car),
## vs (two cars side by side).
##
## The cars stand still on a road that slides under them (`menu_tile_road.gdshader`'s `scroll`), so a scene
## loops for ever with nothing to wrap but the roadside posts and bushes. The viewport is sized to the
## tile's pixels on screen (`_fit_viewport`), capped at MAX_WIDTH. At Detail Level Off the scene renders
## for WARMUP frames and then holds still.

const CarPaint = preload("res://CarPaint.gd")
const PropKit = preload("res://PropKit.gd")
const MenuPropKit = preload("res://MenuPropKit.gd")
const DroneScript = preload("res://Drone.gd")
const ROAD_SHADER = preload("res://menu_tile_road.gdshader")
const GHOST_SHADER = preload("res://menu_ghost.gdshader")
const SKY_SHADER = preload("res://sky_tropical_cumulus.gdshader")

const CAR_SCALE := 2.0
const MAX_WIDTH := 1400.0
const WARMUP := 45
## How often a tile not under the pointer or focus renders, by Detail Level (Off holds a still).
const IDLE_EVERY := [1, 4, 3, 2, 2]
static var _slots := 0
const WHEELS := ["Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"]
## Wheels turn no faster than this on screen (rad/s): at a real 16 m/s a rim's spokes strobe backwards.
const WHEEL_SPIN_MAX := 13.0
const ROAD_HALF := 8.0
const KERB_W := 1.0
const POST_STEP := 14.0
const POST_COUNT := 24
const BUSH_COUNT := 60
const BUSH_SPAN := 340.0
const TREE_MESHES := ["res://generated/harbor_tree_oak_0.res", "res://generated/harbor_tree_lime_0.res",
	"res://generated/harbor_tree_birch_0.res", "res://generated/harbor_tree_oak_1.res"]
const TREES_EACH := 10

## Bench switches (scratch/menu_tile_bench.gd): what each part of a tile costs.
static var dbg := {"sky": true, "far_trees": true, "msaa": -1, "glow": true, "shadows": true, "trees": true, "scale": 1.0}

var kind := "single"
var accent := Color(0.15, 0.75, 0.92)
## Seconds to start from (the scene is the same at any `t`, so shots can pick a moment).
var start_time := 0.0
## Run the clock (false: hold at start_time, for still shots).
var animate := true

var _t := 0.0
var _frames := 0
var _vps: Array[SubViewport] = []
var _views: Array[TextureRect] = []
var _world: Node3D
var _cams: Array[Camera3D] = []
var _road_mat: ShaderMaterial
var _speed := 0.0
var _cars: Array = []
var _posts: MultiMeshInstance3D
var _bushes: MultiMeshInstance3D
var _bush_spots: Array = []
var _trees: Array = []
var _extra := {}
var _built := false
var _slot := 0


func setup(tile_kind: String, tile_accent: Color) -> void:
	kind = tile_kind
	accent = tile_accent


func _ready() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_t = start_time
	_slot = _slots
	_slots += 1
	_build()
	resized.connect(_fit_viewport)
	_fit_viewport()
	_apply(_t)


func _process(delta: float) -> void:
	if not _built:
		return
	if animate:
		_t += delta
	if not is_visible_in_tree():
		return
	_frames += 1
	if _still():
		if _frames < WARMUP:
			_render()
		return
	# Every tile has a fixed cost (about 2ms of an M1's GPU, whatever its size), so the one under the pointer
	# or the focus renders every frame and the others take turns (`IDLE_EVERY` by Detail Level).
	var every := 1 if _active() else int(IDLE_EVERY[_detail()])
	if (_frames + _slot) % every == 0 or _frames < 3:
		_render()


func _render() -> void:
	_apply(_t)
	for vp in _vps:
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _active() -> bool:
	var tile := get_parent() as BaseButton
	return tile != null and (tile.is_hovered() or tile.has_focus())


## Jumps the scene to `t` seconds.
func seek(t: float) -> void:
	_t = t
	_apply(_t)


func _still() -> bool:
	return not OS.has_feature("mobile") and MusicManager.grass_quality_index <= 0


func _detail() -> int:
	return 1 if OS.has_feature("mobile") else clampi(MusicManager.grass_quality_index, 0, 4)


# --- building ---------------------------------------------------------------------------------------

func _build() -> void:
	var vp := _make_viewport()
	vp.own_world_3d = true
	_world = Node3D.new()
	_world.name = "World"
	vp.add_child(_world)
	_build_environment(vp)
	_build_lights()
	match kind:
		"single":
			_build_road(15.0)
			_add_car("Mudrunner", Vector3(-2.2, 0, 0))
			_add_camera(vp, 34.0)
		"splitscreen":
			_build_road(15.0)
			_add_car("Mudrunner", Vector3(-3.4, 0, 0))
			_add_car("Apex", Vector3(3.4, 0, 0))
			_add_camera(vp, 45.0)
			var vp2 := _make_viewport()
			vp2.world_3d = vp.find_world_3d()
			_add_camera(vp2, 45.0)
			_split_views()
		"multiplayer":
			_build_road(15.0)
			# Seen from behind: the Mudrunner (you, P1) nearest, chasing the other three.
			_add_car("Mudrunner", Vector3(0.6, 0, -9.0))
			_add_car("Interceptor", Vector3(-4.3, 0, -4.4))
			_add_car("Fulmine", Vector3(4.2, 0, -5.2))
			_add_car("Titan", Vector3(-0.4, 0, 0.0))
			_add_tags(["P1", "P2", "P3", "P4"], [Color(0.25, 0.85, 0.72), Color(0.35, 0.6, 1.0),
				Color(1.0, 0.45, 0.2), Color(0.95, 0.85, 0.2)])
			_add_camera(vp, 36.0)
		"spectator":
			_build_road(15.0)
			_add_car("Mudrunner", Vector3(-1.5, 0, 0))
			_add_car("Samurai", Vector3(3.0, 0, -4.0))
			_add_car("Basilisk", Vector3(-4.5, 0, -8.0))
			_add_car("Vortex", Vector3(1.5, 0, -12.0))
			_add_camera(vp, 30.0)
			_live_badge()
		"vs":
			_build_road(15.0)
			_add_car("Mudrunner", Vector3(-2.6, 0, 0))
			_add_car("Inferno", Vector3(2.6, 0, 0))
			_add_camera(vp, 36.0)
		"time_trial":
			_build_road(15.0)
			_add_car("Mudrunner", Vector3(-2.6, 0, 0))
			_add_car("Mudrunner", Vector3(2.6, 0, 5.0), true)
			_add_camera(vp, 36.0)
			_timer_label()
		"grand_prix":
			_build_podium()
			_add_camera(vp, 34.0)
		"inspect":
			_build_road(0.0)
			_build_inspect()
			_add_camera(vp, 38.0)
		"options":
			_build_bench()
			_add_camera(vp, 32.0)
	if _views.is_empty():
		texture = vp.get_texture()
	_built = true


func _make_viewport() -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(640, 384)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.audio_listener_enable_3d = false
	var mode: int = MusicManager.anti_aliasing if not OS.has_feature("mobile") else 4
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_4X, Viewport.MSAA_DISABLED][clampi(mode, 0, 4)]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if mode == 4 else Viewport.SCREEN_SPACE_AA_DISABLED
	if int(dbg["msaa"]) >= 0:
		vp.msaa_3d = int(dbg["msaa"])
	vp.scaling_3d_scale = float(dbg["scale"])
	add_child(vp)
	_vps.append(vp)
	return vp


## The viewports at the tile's size in screen pixels (the window's stretch scale applied), so the picture
## is as sharp as the screen; each half of a split tile at half the width.
func _fit_viewport() -> void:
	if _vps.is_empty() or size.x < 4.0 or size.y < 4.0:
		return
	var px: Vector2 = size * get_viewport().get_final_transform().get_scale()
	if px.x > MAX_WIDTH:
		px *= MAX_WIDTH / px.x
	var each := px
	if _views.size() == 2:
		each.x = px.x * 0.5 - 1.0
	for vp in _vps:
		vp.size = Vector2i(maxi(int(each.x), 16), maxi(int(each.y), 16))
	for vp in _vps:
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _build_environment(vp: SubViewport) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	var dusk := false
	var night := kind in ["grand_prix", "options"]
	if dusk:
		sky_mat.set_shader_parameter("sky_top", Color(0.10, 0.16, 0.36))
		sky_mat.set_shader_parameter("sky_horizon", Color(0.95, 0.56, 0.36))
		sky_mat.set_shader_parameter("horizon_haze", Color(0.86, 0.55, 0.42))
		sky_mat.set_shader_parameter("sun_horizon_glow", 0.7)
		sky_mat.set_shader_parameter("cloud_lit", Color(1.0, 0.72, 0.58))
		sky_mat.set_shader_parameter("cloud_shade", Color(0.36, 0.30, 0.42))
	elif night:
		sky_mat.set_shader_parameter("sky_top", Color(0.012, 0.018, 0.05))
		sky_mat.set_shader_parameter("sky_horizon", Color(0.06, 0.07, 0.13))
		sky_mat.set_shader_parameter("horizon_haze", Color(0.07, 0.08, 0.14))
		sky_mat.set_shader_parameter("ground_horizon", Color(0.04, 0.045, 0.06))
		sky_mat.set_shader_parameter("ground_bottom", Color(0.02, 0.02, 0.03))
		sky_mat.set_shader_parameter("cloud_coverage", 0.0)
		sky_mat.set_shader_parameter("sun_glow", 0.0)
		sky_mat.set_shader_parameter("sun_disc_degrees", 0.0)
	else:
		sky_mat.set_shader_parameter("cloud_coverage", 0.55 if kind == "spectator" else 0.42)
		sky_mat.set_shader_parameter("sun_horizon_glow", 0.25)
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.sky = sky
	if not dbg["sky"]:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.6, 0.7, 0.8)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	if night:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.32, 0.36, 0.46)
		env.ambient_light_energy = 0.7
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.fog_enabled = kind != "options"
	env.fog_light_color = Color(0.86, 0.55, 0.42) if dusk else (Color(0.05, 0.06, 0.1) if night else Color(0.70, 0.78, 0.80))
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.0
	env.glow_enabled = dbg["glow"]
	env.glow_intensity = 0.4
	env.glow_hdr_threshold = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	_extra["env"] = env


func _build_lights() -> void:
	var key := DirectionalLight3D.new()
	key.name = "Sun"
	key.light_energy = 1.25
	key.light_color = Color(1.0, 0.93, 0.82)
	key.rotation_degrees = Vector3(-38.0, -150.0, 0.0)
	key.shadow_enabled = dbg["shadows"]
	key.shadow_bias = 0.03
	key.shadow_normal_bias = 1.2
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 60.0
	_world.add_child(key)
	_extra["sun"] = key
	# A rim in the tile's colour from behind, low: the cars' edges glint in it.
	var rim := DirectionalLight3D.new()
	rim.name = "Rim"
	rim.light_energy = 0.7
	rim.light_color = accent.lerp(Color.WHITE, 0.55)
	rim.rotation_degrees = Vector3(-14.0, 20.0, 0.0)
	_world.add_child(rim)
	_extra["rim"] = rim


## The road and its grass, `speed` m/s under the cars, with marker posts along both kerbs and bushes out on
## the grass sliding with it.
func _build_road(speed: float) -> void:
	_speed = speed
	var mi := MeshInstance3D.new()
	mi.name = "Road"
	var plane := PlaneMesh.new()
	plane.size = Vector2(420.0, 700.0)
	mi.mesh = plane
	mi.position = Vector3(0.0, 0.0, 200.0)
	_road_mat = ShaderMaterial.new()
	_road_mat.shader = ROAD_SHADER
	_road_mat.set_shader_parameter("road_half", ROAD_HALF)
	_road_mat.set_shader_parameter("kerb_w", KERB_W)
	mi.material_override = _road_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(mi)

	var pk := PropKit.new()
	pk.material_for = func(_k: String) -> Material: return MenuPropKit.vc_material(0.6)
	var kit := {}
	MenuPropKit.marker_post(pk, kit)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = POST_COUNT * 2
	mm.mesh = pk.commit(kit)
	_posts = MultiMeshInstance3D.new()
	_posts.name = "Posts"
	_posts.multimesh = mm
	_world.add_child(_posts)

	# Bushes: a few lumpy dark green balls out on the grass, both sides, each its own size.
	var bush := SphereMesh.new()
	bush.radius = 1.0
	bush.height = 1.5
	bush.radial_segments = 12
	bush.rings = 6
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.10, 0.2, 0.06)
	bmat.roughness = 0.95
	bush.material = bmat
	var bm := MultiMesh.new()
	bm.transform_format = MultiMesh.TRANSFORM_3D
	bm.instance_count = BUSH_COUNT
	bm.mesh = bush
	_bushes = MultiMeshInstance3D.new()
	_bushes.name = "Bushes"
	_bushes.multimesh = bm
	_world.add_child(_bushes)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in BUSH_COUNT:
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * rng.randf_range(ROAD_HALF + 7.0, 70.0)
		_bush_spots.append({"x": x, "z": rng.randf() * BUSH_SPAN, "s": rng.randf_range(0.5, 1.4),
			"yaw": rng.randf() * TAU})

	# Trees in clumps out on the grass (the woods' own oak, lime and birch, as Harbor Pier saved them).
	for path in TREE_MESHES:
		if not ResourceLoader.exists(path) or not dbg["trees"]:
			continue
		var tm := MultiMesh.new()
		tm.transform_format = MultiMesh.TRANSFORM_3D
		tm.instance_count = TREES_EACH
		tm.mesh = load(path.replace(".res", "_far.res") if dbg["far_trees"] else path)
		var tmi := MultiMeshInstance3D.new()
		tmi.name = "Trees"
		tmi.multimesh = tm
		_world.add_child(tmi)
		var spots: Array = []
		for k in TREES_EACH:
			var side := -1.0 if k % 2 == 0 else 1.0
			spots.append({"x": side * rng.randf_range(ROAD_HALF + 24.0, 120.0), "z": rng.randf() * BUSH_SPAN,
				"s": rng.randf_range(0.8, 1.25), "yaw": rng.randf() * TAU})
		_trees.append({"mmi": tmi, "spots": spots})
	_build_hills()


## Low wooded hills round the horizon (still: far enough that they wouldn't slide), hazed by the fog.
func _build_hills() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 11
	noise.frequency = 0.9
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 160
	var radii := [260.0, 330.0, 420.0, 560.0]
	var rows: Array = []
	for r in radii.size():
		var row: Array = []
		for j in segs + 1:
			var a := TAU * float(j) / segs
			var ridge := 0.5 + 0.5 * noise.get_noise_2d(cos(a) * 3.0, sin(a) * 3.0 + float(r) * 1.7)
			var h: float = [0.0, 26.0, 48.0, 30.0][r] * (0.35 + ridge)
			row.append(Vector3(cos(a) * float(radii[r]), h - 1.0, sin(a) * float(radii[r]) + 120.0))
		rows.append(row)
	for r in radii.size() - 1:
		for j in segs:
			var p00: Vector3 = rows[r][j]
			var p01: Vector3 = rows[r][j + 1]
			var p10: Vector3 = rows[r + 1][j]
			var p11: Vector3 = rows[r + 1][j + 1]
			for tri in [[p00, p10, p11], [p00, p11, p01]]:
				var n: Vector3 = (tri[2] - tri[0]).cross(tri[1] - tri[0]).normalized()
				if n.y < 0.0:
					n = -n
				for v in tri:
					st.set_normal(n)
					var shade := clampf(v.y / 60.0, 0.0, 1.0)
					st.set_color(Color(0.16, 0.27, 0.12).lerp(Color(0.23, 0.33, 0.18), shade))
					st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.name = "Hills"
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(mi)


## Places the posts and bushes for the road having slid `scroll` metres.
func _place_roadside(scroll: float) -> void:
	if _posts == null:
		return
	var span := POST_STEP * POST_COUNT
	var back := 60.0
	for i in POST_COUNT:
		var z := fposmod(float(i) * POST_STEP - scroll, span) - back
		for s in 2:
			var x := (ROAD_HALF + KERB_W + 2.2) * (-1.0 if s == 0 else 1.0)
			_posts.multimesh.set_instance_transform(i * 2 + s, Transform3D(Basis.from_euler(Vector3(0, float(s) * PI, 0)), Vector3(x, 0.0, z)))
	for i in _bush_spots.size():
		var b: Dictionary = _bush_spots[i]
		var z := fposmod(float(b["z"]) - scroll, BUSH_SPAN) - back
		var sc: float = b["s"]
		_bushes.multimesh.set_instance_transform(i, Transform3D(
			Basis.from_euler(Vector3(0, b["yaw"], 0)).scaled(Vector3(sc, sc * 0.8, sc)), Vector3(b["x"], sc * 0.35, z)))
	for tr in _trees:
		var mm: MultiMesh = (tr["mmi"] as MultiMeshInstance3D).multimesh
		var spots: Array = tr["spots"]
		for i in spots.size():
			var b: Dictionary = spots[i]
			var z := fposmod(float(b["z"]) - scroll, BUSH_SPAN) - back
			mm.set_instance_transform(i, Transform3D(Basis.from_euler(Vector3(0, b["yaw"], 0)).scaled(Vector3.ONE * float(b["s"])), Vector3(b["x"], 0.0, z)))


## A car of the game at race size, in its factory paint (a ghost: in the hologram material), its wheels and
## their radii noted. `home` is where it drives (x across the road, z along it).
func _add_car(car_name: String, home: Vector3, ghost := false) -> Dictionary:
	var path := "res://generated/cars/%s.tscn" % car_name
	if not ResourceLoader.exists(path):
		push_warning("MenuTileStage: no car " + path)
		return {}
	var car := (load(path) as PackedScene).instantiate() as Node3D
	car.name = car_name + ("Ghost" if ghost else "")
	_world.add_child(car)
	if CarPaint.is_paintable(car):
		CarPaint.apply(car, CarPaint.factory(car_name))
	if ghost:
		_ghostify(car)
	var wheels: Array = []
	var radii: Array = []
	for w in WHEELS:
		var node := car.get_node_or_null("Model/" + w) as MeshInstance3D
		wheels.append(node)
		radii.append(maxf(node.mesh.get_aabb().size.y * 0.5, 0.1) if node and node.mesh else 0.35)
	var entry := {"node": car, "home": home, "wheels": wheels, "radii": radii, "rolled": 0.0,
		"seed": float(_cars.size()) * 1.73 + 0.4, "ghost": ghost}
	if _speed > 0.0 and not ghost and _detail() >= 1:
		entry["dust"] = _make_dust(car)
	_cars.append(entry)
	return entry


func _ghostify(node: Node) -> void:
	if node is GeometryInstance3D:
		var mat := ShaderMaterial.new()
		mat.shader = GHOST_SHADER
		mat.set_shader_parameter("tint", Color(1.0, 0.62, 0.18))
		(node as GeometryInstance3D).material_override = mat
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in node.get_children():
		_ghostify(c)


## Dust thrown back off the rear tyres: soft puffs in the car's frame, flying back at the road's speed.
func _make_dust(car: Node3D) -> CPUParticles3D:
	var dust := CPUParticles3D.new()
	dust.name = "Dust"
	dust.amount = 24
	dust.lifetime = 0.9
	dust.lifetime_randomness = 0.4
	dust.local_coords = false
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(0.9, 0.05, 0.1)
	var quad := QuadMesh.new()
	dust.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _soft_dot()
	mat.albedo_color = Color(0.72, 0.72, 0.74)
	mat.disable_fog = true
	mat.render_priority = 2
	dust.material_override = mat
	dust.direction = Vector3(0.0, 0.35, -1.0)
	dust.spread = 18.0
	dust.gravity = Vector3(0.0, 0.4, 0.0)
	dust.initial_velocity_min = _speed * 0.85
	dust.initial_velocity_max = _speed * 1.0
	dust.damping_min = 2.0
	dust.damping_max = 4.0
	dust.scale_amount_min = 0.5
	dust.scale_amount_max = 1.0
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.25))
	grow.add_point(Vector2(1.0, 1.0))
	dust.scale_amount_curve = grow
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.1), Color(1, 1, 1, 0.0)])
	dust.color_ramp = ramp
	_world.add_child(dust)
	return dust


static var _dot: Texture2D

static func _soft_dot() -> Texture2D:
	if _dot != null:
		return _dot
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2((x + 0.5) / 32.0 - 0.5, (y + 0.5) / 32.0 - 0.5).length() * 2.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a * (3.0 - 2.0 * a)))
	_dot = ImageTexture.create_from_image(img)
	return _dot


func _add_camera(vp: SubViewport, fov: float) -> Camera3D:
	var cam := Camera3D.new()
	cam.fov = fov
	cam.near = 0.05 if kind == "options" else 0.2
	cam.far = 900.0
	vp.add_child(cam)
	cam.current = true
	_cams.append(cam)
	return cam


## Floating name tags over the cars (multiplayer): coloured, always facing the camera.
func _add_tags(names: Array, colours: Array) -> void:
	for i in mini(names.size(), _cars.size()):
		var tag := Label3D.new()
		tag.text = names[i]
		tag.font_size = 96
		tag.pixel_size = 0.009
		tag.outline_size = 22
		tag.outline_modulate = Color(0, 0, 0, 0.75)
		tag.modulate = colours[i]
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.fixed_size = false
		tag.render_priority = 5
		_world.add_child(tag)
		_cars[i]["tag"] = tag


# --- overlays ---------------------------------------------------------------------------------------

## Splitscreen: the two players' views side by side, a dark seam with the tile's colour between them.
func _split_views() -> void:
	for i in 2:
		var view := TextureRect.new()
		view.texture = _vps[i].get_texture()
		view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		view.stretch_mode = TextureRect.STRETCH_SCALE
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.anchor_left = 0.5 * i
		view.anchor_right = 0.5 * (i + 1)
		view.anchor_bottom = 1.0
		view.offset_left = 1.5 if i == 1 else 0.0
		view.offset_right = -1.5 if i == 0 else 0.0
		add_child(view)
		_views.append(view)
		var badge := _badge("P%d" % (i + 1), Color(0.25, 0.85, 0.72) if i == 0 else Color(1.0, 0.55, 0.16))
		view.add_child(badge)
		badge.position = Vector2(12, 10)
	var seam := ColorRect.new()
	seam.color = Color(0.03, 0.035, 0.05)
	seam.anchor_left = 0.5
	seam.anchor_right = 0.5
	seam.anchor_bottom = 1.0
	seam.offset_left = -1.5
	seam.offset_right = 1.5
	seam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(seam)


func _badge(text: String, colour: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.035, 0.05, 0.72)
	sb.border_color = colour
	sb.set_border_width_all(0)
	sb.border_width_left = 3
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", colour.lerp(Color.WHITE, 0.25))
	panel.add_child(lbl)
	return panel


## Spectator: a broadcast's LIVE badge (its dot pulsing) and the lap counter.
func _live_badge() -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(14, 12)
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var live := _badge("●  LIVE", Color(1.0, 0.22, 0.2))
	row.add_child(live)
	row.add_child(_badge("LAP 2 / 3", Color(0.85, 0.9, 0.95)))
	_extra["live"] = live


## Time trial: the running lap time and the gap to the ghost, top right.
func _timer_label() -> void:
	var box := VBoxContainer.new()
	box.anchor_left = 1.0
	box.anchor_right = 1.0
	box.offset_left = -190
	box.offset_right = -14
	box.offset_top = 10
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	add_child(box)
	var time := Label.new()
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time.add_theme_font_size_override("font_size", 30)
	time.add_theme_color_override("font_color", Color.WHITE)
	time.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	time.add_theme_constant_override("shadow_offset_y", 2)
	box.add_child(time)
	var delta := Label.new()
	delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	delta.add_theme_font_size_override("font_size", 18)
	delta.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	delta.add_theme_constant_override("shadow_offset_y", 1)
	box.add_child(delta)
	_extra["time"] = time
	_extra["delta"] = delta


# --- the set pieces ---------------------------------------------------------------------------------

## Grand Prix: the podium on a dark stage at dusk, the Mudrunner on the top step behind the trophy, two
## more on the lower steps, confetti falling through the spotlights.
func _build_podium() -> void:
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(300, 300)
	floor_mi.mesh = plane
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.07, 0.075, 0.09)
	fmat.roughness = 0.35
	fmat.metallic = 0.2
	floor_mi.material_override = fmat
	_world.add_child(floor_mi)
	var heights := [1.5, 1.0, 0.65]
	var xs := [0.0, -4.0, 4.0]
	var names := ["Mudrunner", "Fulmine", "Titan"]
	var medal := [Color(1.0, 0.78, 0.26), Color(0.84, 0.87, 0.92), Color(0.86, 0.52, 0.26)]
	for i in 3:
		var block := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(3.7, heights[i], 3.4)
		block.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.92, 0.93, 0.95)
		mat.roughness = 0.4
		block.material_override = mat
		block.position = Vector3(xs[i], heights[i] * 0.5, 0.0)
		_world.add_child(block)
		var band := MeshInstance3D.new()
		var band_mesh := BoxMesh.new()
		band_mesh.size = Vector3(3.72, 0.16, 3.42)
		band.mesh = band_mesh
		var band_mat := StandardMaterial3D.new()
		band_mat.albedo_color = medal[i]
		band_mat.metallic = 0.7
		band_mat.roughness = 0.3
		band.material_override = band_mat
		band.position = Vector3(xs[i], heights[i] - 0.14, 0.0)
		_world.add_child(band)
		var num := Label3D.new()
		num.text = str(i + 1)
		num.font_size = 160
		num.pixel_size = 0.006
		num.modulate = medal[i].darkened(0.15)
		num.position = Vector3(xs[i], heights[i] * 0.45, 1.72)
		_world.add_child(num)
		var car := _add_car(names[i], Vector3(xs[i] - (0.45 if i == 0 else 0.0), heights[i], -0.2))
		if not car.is_empty():
			car["yaw"] = [0.0, 0.5, -0.5][i]
	# Behind it a dark wall with a chequered banner across it and a band of light in the tile's colour.
	var pk := PropKit.new()
	pk.material_for = func(k: String) -> Material: return MenuPropKit.material(k)
	var kit := {}
	pk.box(kit, "matte", Transform3D(Basis(), Vector3(0, 5.0, -5.5)), Vector3(40.0, 10.0, 0.4), Color(0.025, 0.03, 0.06))
	for col_i in 40:
		for row in 2:
			var black := (col_i + row) % 2 == 0
			pk.box(kit, "matte", Transform3D(Basis(), Vector3(-16.0 + 0.8 * col_i, 4.3 + 0.8 * row, -5.25)), Vector3(0.8, 0.8, 0.05),
				Color(0.03, 0.03, 0.035) if black else Color(0.92, 0.92, 0.9))
	pk.box(kit, "led", Transform3D(Basis(), Vector3(0, 3.75, -5.26)), Vector3(40.0, 0.12, 0.04), accent * 1.6)
	pk.box(kit, "led", Transform3D(Basis(), Vector3(0, 6.25, -5.26)), Vector3(40.0, 0.12, 0.04), accent * 1.6)
	var wall := MeshInstance3D.new()
	wall.mesh = pk.commit(kit)
	_world.add_child(wall)
	var cup := MeshInstance3D.new()
	cup.mesh = load("res://Podium.gd")._trophy_mesh()
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = medal[0]
	cmat.metallic = 0.85
	cmat.roughness = 0.25
	cmat.emission_enabled = true
	cmat.emission = medal[0]
	cmat.emission_energy_multiplier = 0.2
	cmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cup.material_override = cmat
	cup.scale = Vector3.ONE * 0.85
	cup.position = Vector3(1.25, 1.5, 0.95)
	_world.add_child(cup)
	_extra["cup"] = cup
	for i in 2:
		var spot := SpotLight3D.new()
		spot.light_energy = 14.0
		spot.light_color = Color(1.0, 0.97, 0.93) if i == 0 else accent.lerp(Color.WHITE, 0.5)
		spot.spot_range = 30.0
		spot.spot_angle = 16.0
		spot.position = Vector3(-6.0 + 12.0 * i, 11.0, 7.0)
		spot.look_at_from_position(spot.position, Vector3(0, 1.5, 0))
		_world.add_child(spot)
	(_extra["sun"] as DirectionalLight3D).light_energy = 0.9
	(_extra["sun"] as DirectionalLight3D).light_color = Color(0.85, 0.9, 1.0)
	var confetti := CPUParticles3D.new()
	confetti.amount = 160 if _detail() >= 2 else 70
	confetti.lifetime = 4.0
	confetti.preprocess = 4.0
	confetti.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	confetti.emission_box_extents = Vector3(9.0, 0.2, 4.0)
	confetti.position = Vector3(0, 9.0, 0.5)
	confetti.direction = Vector3(0, -1, 0)
	confetti.spread = 25.0
	confetti.gravity = Vector3(0, -1.6, 0)
	confetti.initial_velocity_min = 0.5
	confetti.initial_velocity_max = 1.5
	confetti.angular_velocity_min = -360.0
	confetti.angular_velocity_max = 360.0
	confetti.angle_min = 0.0
	confetti.angle_max = 360.0
	var cq := QuadMesh.new()
	cq.size = Vector2(0.14, 0.09)
	confetti.mesh = cq
	var cm := StandardMaterial3D.new()
	cm.vertex_color_use_as_albedo = true
	cm.cull_mode = BaseMaterial3D.CULL_DISABLED
	cm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	cm.particles_anim_h_frames = 1
	cm.emission_enabled = true
	cm.emission = Color(0.25, 0.25, 0.25)
	confetti.material_override = cm
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8])
	g.colors = PackedColorArray([Color(1.0, 0.8, 0.2), Color(0.2, 0.8, 0.95), Color(1.0, 0.35, 0.3),
		Color(0.4, 0.95, 0.5), Color(0.9, 0.4, 1.0)])
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	confetti.color_initial_ramp = g
	_world.add_child(confetti)


## Inspect: no cars, a drone hovering over the course; cones along the kerb and a gantry down the road.
func _build_inspect() -> void:
	var drone := DroneScript.new()
	drone.name = "Drone"
	drone.livery = accent
	drone.auto_animate = false
	_world.add_child(drone)
	_extra["drone"] = drone
	var pk := PropKit.new()
	pk.material_for = func(_k: String) -> Material: return MenuPropKit.vc_material(0.55)
	var kit := {}
	for i in 7:
		pk.set_frame(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 1.6), Vector3(-ROAD_HALF + 1.2, 0.0, 6.0 + float(i) * 6.0)))
		MenuPropKit.cone(pk, kit)
	pk.reset_frame()
	MenuPropKit.gantry(pk, kit, Vector3(0.0, 0.0, 70.0), ROAD_HALF + KERB_W + 1.0, 8.0, accent)
	var mi := MeshInstance3D.new()
	mi.mesh = pk.commit(kit)
	_world.add_child(mi)


## Options: a workbench; the laptop open on the car's settings, the pro transmitter beside it, the
## Mudrunner on its set-up stand behind, its front wheels steering as the transmitter's wheel turns.
func _build_bench() -> void:
	var bench := MenuPropKit.build_bench(accent)
	_world.add_child(bench)
	_extra["bench"] = bench
	# The car at RC scale (about 45cm long) on the stand.
	var car := _add_car("Mudrunner", Vector3.ZERO)
	if not car.is_empty():
		var aabb := _bounds(car["node"])
		car["rc_scale"] = 0.46 / maxf(aabb.size.z, 0.1)
		car["home"] = bench.get_meta("stand_top")
	(_extra["sun"] as DirectionalLight3D).directional_shadow_max_distance = 4.0
	(_extra["sun"] as DirectionalLight3D).light_energy = 0.9
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.86, 0.68)
	lamp.light_energy = 2.2
	lamp.omni_range = 3.0
	lamp.position = Vector3(-0.3, 0.75, 0.45)
	_world.add_child(lamp)


static func _bounds(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var inv := root.global_transform.affine_inverse() if root.is_inside_tree() else Transform3D.IDENTITY
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh:
			var mi := n as MeshInstance3D
			var box := (inv * mi.global_transform) * mi.mesh.get_aabb()
			out = box if first else out.merge(box)
			first = false
		for c in n.get_children():
			stack.append(c)
	return out


# --- motion -----------------------------------------------------------------------------------------

func _apply(t: float) -> void:
	var scroll := t * _speed
	if _road_mat:
		_road_mat.set_shader_parameter("scroll", scroll)
	_place_roadside(scroll)
	for i in _cars.size():
		_apply_car(_cars[i], t)
	match kind:
		"single":
			var c: Node3D = _cars[0]["node"]
			_frame(0, c.position + Vector3(0.0, 0.8, 0.2), 2.5, 0.95, 38.0 + sin(t * 0.21) * 6.0, 11.0)
		"splitscreen":
			for i in 2:
				var c: Node3D = _cars[i]["node"]
				_frame(i, c.position + Vector3(0.0, 0.8, 0.6), 2.2, 1.0, 180.0 + (12.0 if i == 0 else -12.0) + sin(t * 0.2 + i) * 4.0, 15.0)
		"multiplayer":
			_frame(0, Vector3(0.0, 1.0, -6.0), 5.6, 2.3, 200.0 + sin(t * 0.17) * 6.0, 17.0)
			for c in _cars:
				if c.has("tag"):
					(c["tag"] as Label3D).position = (c["node"] as Node3D).position + Vector3(0, 2.2, 0)
		"spectator":
			_frame(0, Vector3(0.0, 1.0, -5.5), 6.5, 2.6, -62.0 + sin(t * 0.13) * 4.0, 28.0)
			var live: Control = _extra.get("live")
			if live:
				live.modulate.a = 0.8 + 0.2 * cos(t * 3.0)
		"vs":
			_frame(0, Vector3(0.0, 0.85, 0.5), 5.2, 1.3, sin(t * 0.19) * 8.0, 9.0)
		"time_trial":
			_frame(0, Vector3(0.0, 0.9, 2.5), 5.4, 1.5, -38.0 + sin(t * 0.2) * 5.0, 12.0)
			var lap := fposmod(t + 41.3, 75.0)
			(_extra["time"] as Label).text = "%d:%06.3f" % [int(lap / 60.0), fmod(lap, 60.0)]
			var gap := -0.214 - 0.06 * sin(t * 0.4)
			var dl: Label = _extra["delta"]
			dl.text = "%+.3f" % gap
			dl.add_theme_color_override("font_color", Color(0.35, 0.95, 0.45) if gap < 0.0 else Color(1.0, 0.35, 0.3))
		"grand_prix":
			_frame(0, Vector3(0.0, 2.2, 0.0), 6.6, 2.3, sin(t * 0.18) * 12.0, 12.0)
			var cup: Node3D = _extra["cup"]
			cup.rotation.y = t * 0.6
		"inspect":
			var drone: Node3D = _extra["drone"]
			drone.position = Vector3(1.0 + sin(t * 0.4) * 0.6, 4.2 + sin(t * 0.9) * 0.25, 6.0 + sin(t * 0.27) * 0.8)
			drone.rotation = Vector3(-0.06 + 0.03 * sin(t * 0.8), 0.25 * sin(t * 0.3), 0.04 * sin(t * 0.55))
			drone.call("animate", t)
			_frame(0, drone.position + Vector3(0, -0.02, 0), 0.85, 0.32, 150.0 + sin(t * 0.12) * 18.0, 16.0)
		"options":
			var bench: Node3D = _extra["bench"]
			var steer := sin(t * 0.9) * 0.45 + sin(t * 2.3) * 0.08
			MenuPropKit.animate_bench(bench, t, steer)
			if not _cars.is_empty():
				for k in 2:
					var w: Node3D = _cars[0]["wheels"][k]
					if w:
						w.rotation = Vector3(0, -steer * 0.6, 0)
			_frame(0, Vector3(0.06, 0.12, -0.02), 0.52, 0.17, 22.0 + sin(t * 0.15) * 6.0, 24.0)


## Frames camera `i` on what it shows (`centre`, `rx` across and `ry` up from it on screen) seen from `yaw_deg` (round from +z toward +x) and
## `pitch_deg` up: as near as it fits the part of the tile above its caption, whatever the tile's
## shape (from 4:1 on the main screen to nearly square), then tipped down so its middle sits a
## quarter of the way down the picture.
func _frame(i: int, centre: Vector3, rx: float, ry: float, yaw_deg: float, pitch_deg: float) -> void:
	if i >= _cams.size():
		return
	var cam := _cams[i]
	var vs: Vector2i = _vps[i].size
	var aspect := float(vs.x) / maxf(float(vs.y), 1.0)
	var tv := tan(deg_to_rad(cam.fov * 0.5))
	var th := tv * aspect
	var dist := maxf(ry / (tv * 0.47), rx / (th * 0.9))
	var yaw := deg_to_rad(yaw_deg)
	var pitch := deg_to_rad(pitch_deg)
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	cam.position = centre + dir * dist
	cam.look_at(centre, Vector3.UP)
	cam.rotate_object_local(Vector3.RIGHT, -atan(0.48 * tv))


## A car's place at `t`: its home, weaving a little across its lane and gaining and losing a little along it,
## the body bobbing and rolling into the weave, wheels turning and steering with it.
func _apply_car(c: Dictionary, t: float) -> void:
	var car: Node3D = c["node"]
	var home: Vector3 = c["home"]
	var s: float = c["seed"]
	if c.has("rc_scale"):
		car.transform = Transform3D(Basis.from_euler(Vector3(0, 0.55, 0)).scaled(Vector3.ONE * float(c["rc_scale"])), home)
		return
	var moving := _speed > 0.0
	var weave := 0.0
	var lead := 0.0
	if moving:
		weave = sin(t * 0.55 + s) * 0.9 + sin(t * 1.3 + s * 2.0) * 0.25
		lead = sin(t * 0.31 + s * 1.7) * 1.6
		if kind == "spectator" or kind == "vs":
			lead = sin(t * 0.37 + s * 2.3) * 2.4
	var dx_dt := (cos(t * 0.55 + s) * 0.55 * 0.9 + cos(t * 1.3 + s * 2.0) * 1.3 * 0.25) if moving else 0.0
	var yaw := float(c.get("yaw", 0.0)) + atan2(dx_dt, maxf(_speed, 1.0)) * 1.4
	var bob := sin(t * 9.0 + s * 3.0) * 0.012 if moving else sin(t * 2.1 + s) * 0.004
	var pitch := sin(t * 5.3 + s) * 0.006 if moving else 0.0
	var roll := -dx_dt * 0.05
	var pos := home + Vector3(weave, bob, lead)
	car.transform = Transform3D(Basis.from_euler(Vector3(pitch, yaw, roll)).scaled(Vector3.ONE * CAR_SCALE), pos)
	var spin: float = minf(_speed, WHEEL_SPIN_MAX * 0.35)
	c["rolled"] = t * spin
	for k in 4:
		var w: Node3D = c["wheels"][k]
		if w == null:
			continue
		var angle := -float(c["rolled"]) / float(c["radii"][k]) if moving else 0.0
		w.rotation = Vector3(angle, (dx_dt * 0.25) if k < 2 else 0.0, 0.0)
	if c.has("dust"):
		var dust: CPUParticles3D = c["dust"]
		var rear := Vector3(0, 0, -0.5)
		if c["wheels"][2]:
			var model := car.get_node("Model") as Node3D
			rear = model.transform * (c["wheels"][2] as Node3D).position
		# The car's frame is CAR_SCALE times the world's: its basis carries a point of it into the world.
		dust.position = pos + car.basis * Vector3(0.0, 0.0, rear.z)
		dust.position.y = 0.1
		dust.emitting = _frames > 6
