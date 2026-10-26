extends Control
## The title card the game opens with: the 3D RC VIBE GP logo (generated/logo/RcVibeLogo.tscn) hanging over
## a polished floor, with five of the cars skidding in below it in their factory paint. Main plays it once
## a launch, over the menu, and swipes to the menu when it `finished`; any key, click or button skips it.
##
## It builds itself (SplashScreen.tscn is only the root) in a SubViewport of its own, like the car select
## screen's showroom. Every motion is a function of the clock (`_apply(t)`), not a tween, so
## `scratch/splash_shots.gd` can jump to any moment. The clock waits, behind black, for the first frames:
## shaders compile in the background and draw nothing until they're ready, and the cars would otherwise
## arrive missing.
##
## The stage: z is toward the camera, the floor y = 0. The cars come in on the floor from far away, brake
## and swing round into place in a clutter of dust; the logo's plates (rim, then body) arrive under them
## and its letters fly in one by one from the camera's side and land, the last with a hit: the camera
## jolts, a ring of light spreads over the floor and a highlight sweeps across the letters. Cars and logo
## also stand mirrored below the floor (`_mirror`), which the floor shows through (splash_floor.gdshader).

signal finished

const LOGO_PATH := "res://generated/logo/RcVibeLogo.tscn"
const CarPaint = preload("res://CarPaint.gd")
const SKY_SHADER = preload("res://splash_sky.gdshader")
const FLOOR_SHADER = preload("res://splash_floor.gdshader")
const BURST_SHADER = preload("res://splash_burst.gdshader")
const VIGNETTE_SHADER = preload("res://splash_vignette.gdshader")

## Once a launch: a restart of the menu doesn't replay it.
static var played := false

# ---- Timeline (seconds) ----
const DURATION := 5.9
const FADE_IN := 0.5
## A key in the first moments doesn't skip (it may be the one that started the game).
const SKIP_AFTER := 0.5
## Frames the clock waits for the shaders.
const WARMUP_FRAMES := 24
const T_PLATE := 0.85
const T_FACES := 1.2
const FACE_STAGGER := 0.075
const FACE_TIME := 0.62
const T_PROMPT := 2.9

# ---- The logo ----
const LOGO_POS := Vector3(0.0, 4.9, -8.0)
const LOGO_SCALE := 1.45
## How far in front of its place, in the logo's own metres, a letter starts, and how big.
const FACE_FLY := 6.5
const FACE_START_SCALE := 1.7

# ---- The cars ----
## In the order they arrive. `from` (x, z) is where each comes in from, `to` where it comes to rest, `yaw`
## the way it ends up facing (degrees: 0 at the camera, positive toward +x), `drift` how far past that its
## tail swings on the way.
const CARS := [
	{"name": "Phantom", "from": Vector2(-26.0, -16.0), "to": Vector2(-5.9, -1.6), "yaw": 24.0, "drift": -16.0, "t0": 0.05},
	{"name": "Vortex", "from": Vector2(26.0, -15.0), "to": Vector2(6.1, -1.8), "yaw": -24.0, "drift": 16.0, "t0": 0.17},
	{"name": "Interceptor", "from": Vector2(-10.0, -26.0), "to": Vector2(-3.3, 1.9), "yaw": 18.0, "drift": 22.0, "t0": 0.32},
	{"name": "Apex", "from": Vector2(10.0, -25.0), "to": Vector2(3.5, 1.7), "yaw": -19.0, "drift": -22.0, "t0": 0.44},
	{"name": "Inferno", "from": Vector2(0.6, -28.0), "to": Vector2(0.1, 3.4), "yaw": -4.0, "drift": 20.0, "t0": 0.58},
]
const CAR_SCALE := 2.0
const ARRIVE_TIME := 1.5
## Per level of the Detail Level setting (MusicManager.grass_quality_index, Off to Ultra): the share of
## the dust and the sparks that is drawn, and from which level the floor has its mirror.
const PARTICLES := [0.35, 0.55, 0.8, 1.0, 1.0]
const MIRROR_FROM := 2
const WHEELS := ["Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"]
## A wheel's radius in the cars' own frame, for how fast it turns.
const WHEEL_RADIUS := 0.26

var _t := 0.0
var _frames := 0
var _done := false
## false: the clock stands still (the screenshot tool sets the time itself).
var autoplay := true

var _stage: SubViewport
var _world: Node3D
var _mirror: Node3D
var _camera: Camera3D
var _floor_mat: ShaderMaterial
var _burst_mat: ShaderMaterial
var _logo_mat: ShaderMaterial
var _logo: Array = []            # [real pivot, mirrored pivot]
var _plates: Array = []          # [{real, mirror}] for the rim and the body
var _faces: Array = []           # [{real, mirror, home}] in the order they arrive
var _cars: Array = []
var _veil: ColorRect
var _flash: ColorRect
var _prompt: Label


## Does the game open with the title card? Once a launch, when Main is the running scene (a test that
## instantiates Main isn't), with a window to show it in, and not with `nosplash` on the command line.
static func should_play(main: Node) -> bool:
	if played:
		return false
	if DisplayServer.get_name() == "headless":
		return false
	if OS.get_cmdline_user_args().has("nosplash"):
		return false
	return main.get_tree().current_scene == main


func _ready() -> void:
	played = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not ResourceLoader.exists(LOGO_PATH):
		push_warning("SplashScreen: %s is missing (run regenerate_logo.tscn), skipping" % LOGO_PATH)
		finish.call_deferred()
		return
	_build_stage()
	_build_overlay()
	_apply(0.0)


func _process(delta: float) -> void:
	_frames += 1
	if _frames <= WARMUP_FRAMES:
		_apply(0.0)
		return
	if autoplay:
		_t += delta
	_apply(_t)
	_spin_wheels(delta)
	if _t >= DURATION:
		finish()


func _input(event: InputEvent) -> void:
	if _done or _t < SKIP_AFTER:
		return
	var pressed := false
	if event is InputEventKey:
		pressed = event.pressed and not event.echo
	elif event is InputEventMouseButton or event is InputEventJoypadButton or event is InputEventScreenTouch:
		pressed = event.is_pressed()
	if pressed:
		get_viewport().set_input_as_handled()
		finish()


## Ends the title card (Main takes it from there).
func finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()


## Jumps the clock to `t` seconds (the screenshot tool's way in); the clock stays there.
func seek(t: float) -> void:
	autoplay = false
	_frames = WARMUP_FRAMES + 1
	_t = t
	_apply(t)


# ---- Building ----------------------------------------------------------------------------------------

func _build_stage() -> void:
	var holder := SubViewportContainer.new()
	holder.name = "Stage"
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_stage = SubViewport.new()
	_stage.own_world_3d = true
	_apply_anti_aliasing(_stage)
	_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	holder.add_child(_stage)

	_world = Node3D.new()
	_world.name = "World"
	_stage.add_child(_world)
	# The reflection: the same things again, upside down, below the floor.
	_mirror = Node3D.new()
	_mirror.name = "Mirror"
	_mirror.scale = Vector3(1.0, -1.0, 1.0)
	_mirror.visible = _detail() >= MIRROR_FROM
	_stage.add_child(_mirror)

	_build_environment()
	_build_lights()
	_build_floor()
	_build_burst()
	_build_logo()
	_build_cars()
	_build_motes()
	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.fov = 36.0
	_camera.near = 0.1
	_camera.far = 4500.0
	_stage.add_child(_camera)
	_camera.current = true


## The player's anti-aliasing choice (MusicManager.set_anti_aliasing does the same for the game's own
## viewport); a phone gets FXAA.
func _apply_anti_aliasing(vp: SubViewport) -> void:
	var mode: int = MusicManager.anti_aliasing if not OS.has_feature("mobile") else 4
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X, Viewport.MSAA_DISABLED][clampi(mode, 0, 4)]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if mode == 4 else Viewport.SCREEN_SPACE_AA_DISABLED


## The Detail Level setting, 0 (Off) to 4 (Ultra); a phone is held to Low.
func _detail() -> int:
	return 1 if OS.has_feature("mobile") else clampi(MusicManager.grass_quality_index, 0, 4)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.65
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	# The far floor goes into the dark at the horizon.
	env.fog_enabled = true
	env.fog_light_color = Color(0.10, 0.05, 0.06)
	env.fog_density = 0.0085
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.3
	var we := WorldEnvironment.new()
	we.environment = env
	_stage.add_child(we)


func _build_lights() -> void:
	# A warm key from high on the camera's left, a cool rim from behind on the right, an orange one
	# from behind on the left: the cars and the letters get a bright edge on both sides.
	var key := DirectionalLight3D.new()
	key.light_energy = 1.15
	key.light_color = Color(1.0, 0.95, 0.88)
	key.rotation_degrees = Vector3(-36.0, -34.0, 0.0)
	key.shadow_enabled = MusicManager.shadows_enabled
	key.shadow_bias = 0.04
	key.shadow_normal_bias = 1.5
	key.directional_shadow_max_distance = 45.0
	_world.add_child(key)
	# The rims leave the floor alone (it is on layer 2): on a polished floor they would glint as two
	# enormous coloured sheets.
	var rim_blue := DirectionalLight3D.new()
	rim_blue.light_energy = 1.7
	rim_blue.light_color = Color(0.45, 0.68, 1.0)
	rim_blue.rotation_degrees = Vector3(-22.0, 155.0, 0.0)
	rim_blue.light_cull_mask = 1
	_world.add_child(rim_blue)
	var rim_orange := DirectionalLight3D.new()
	rim_orange.light_energy = 1.4
	rim_orange.light_color = Color(1.0, 0.55, 0.2)
	rim_orange.rotation_degrees = Vector3(-20.0, 205.0, 0.0)
	rim_orange.light_cull_mask = 1
	_world.add_child(rim_orange)


func _build_floor() -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Floor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(4000.0, 4000.0)
	mi.mesh = plane
	_floor_mat = ShaderMaterial.new()
	_floor_mat.shader = FLOOR_SHADER
	_floor_mat.set_shader_parameter("pool_centre", Vector3(LOGO_POS.x, 0.0, LOGO_POS.z + 1.5))
	mi.material_override = _floor_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = 2
	_world.add_child(mi)


func _build_burst() -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Burst"
	var quad := QuadMesh.new()
	quad.size = Vector2(40.0, 40.0)
	mi.mesh = quad
	_burst_mat = ShaderMaterial.new()
	_burst_mat.shader = BURST_SHADER
	_burst_mat.render_priority = -3
	mi.material_override = _burst_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(LOGO_POS.x, LOGO_POS.y + 0.4, LOGO_POS.z - 6.0)
	_world.add_child(mi)


func _build_logo() -> void:
	var packed := load(LOGO_PATH) as PackedScene
	var pivots: Array = []
	for parent in [_world, _mirror]:
		var pivot := Node3D.new()
		pivot.name = "LogoPivot"
		parent.add_child(pivot)
		var logo := packed.instantiate() as Node3D
		pivot.add_child(logo)
		_no_shadow(logo, parent == _mirror)
		pivots.append([pivot, logo])
	_logo = [pivots[0][0], pivots[1][0]]
	for name in ["Rim", "Body"]:
		_plates.append({"real": pivots[0][1].get_node(name), "mirror": pivots[1][1].get_node(name)})
	var real_faces: Node = pivots[0][1].get_node("Faces")
	var mirror_faces: Node = pivots[1][1].get_node("Faces")
	for face in real_faces.get_children():
		_faces.append({"real": face, "mirror": mirror_faces.get_node(NodePath(face.name)), "home": (face as Node3D).position})
	_logo_mat = (_plates[0]["real"].mesh as Mesh).surface_get_material(0) as ShaderMaterial
	_logo_mat.set_shader_parameter("clearcoat_amount", 0.7)


## Cars and logo go into the world and, again, into the mirror.
func _build_cars() -> void:
	for i in CARS.size():
		var spec: Dictionary = CARS[i]
		var path := "res://generated/cars/%s.tscn" % spec["name"]
		var packed := load(path) as PackedScene
		var pair: Array = []
		for parent in [_world, _mirror]:
			var car := packed.instantiate() as Node3D
			parent.add_child(car)
			if CarPaint.is_paintable(car):
				CarPaint.apply(car, CarPaint.factory(spec["name"]))
			_no_shadow(car, parent == _mirror)
			pair.append(car)
		var wheels: Array = []
		for w in WHEELS:
			wheels.append([pair[0].get_node("Model/" + w), pair[1].get_node("Model/" + w)])
		var dust := _make_dust()
		pair[0].add_child(dust)
		# At the rear axle, on the ground; the car's frame is CAR_SCALE times the world's, so the emitter
		# is scaled back down to keep the cloud's sizes and speeds in metres.
		dust.position = Vector3(0.0, 0.05, -0.3)
		dust.scale = Vector3.ONE / CAR_SCALE
		_make_blob(pair[0])
		_cars.append({"spec": spec, "real": pair[0], "mirror": pair[1], "wheels": wheels, "dust": dust, "spin": 0.0, "speed": 0.0})


## The mirrored copies cast no shadow (the real ones do).
func _no_shadow(node: Node, mirrored: bool) -> void:
	if mirrored and node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in node.get_children():
		_no_shadow(c, mirrored)


## The cloud a car raises: soft sand-coloured puffs that grow and fade, in world space (they stay where
## they were thrown while the car moves on).
func _make_dust() -> CPUParticles3D:
	var dust := CPUParticles3D.new()
	dust.name = "Dust"
	dust.emitting = false
	dust.amount = int(110.0 * PARTICLES[_detail()])
	dust.lifetime = 1.5
	dust.randomness = 0.4
	dust.lifetime_randomness = 0.35
	dust.local_coords = false
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(0.55, 0.04, 0.12)
	var quad := QuadMesh.new()
	dust.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = _soft_dot()
	mat.albedo_color = Color(0.62, 0.46, 0.34)
	mat.disable_fog = true
	mat.render_priority = 2
	dust.material_override = mat
	dust.direction = Vector3(0.0, 0.55, -1.0)
	dust.spread = 38.0
	dust.gravity = Vector3(0.0, 0.5, 0.0)
	dust.initial_velocity_min = 2.0
	dust.initial_velocity_max = 5.5
	dust.damping_min = 1.2
	dust.damping_max = 2.6
	dust.scale_amount_min = 0.9
	dust.scale_amount_max = 2.0
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.15))
	grow.add_point(Vector2(0.4, 0.6))
	grow.add_point(Vector2(1.0, 1.0))
	dust.scale_amount_curve = grow
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.12, 0.5, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.38), Color(1, 1, 1, 0.16), Color(1, 1, 1, 0.0)])
	dust.color_ramp = ramp
	return dust


## A soft blob of shadow under a car (in the car's own frame, which is CAR_SCALE times the world's).
func _make_blob(car: Node3D) -> MeshInstance3D:
	var blob := MeshInstance3D.new()
	blob.name = "Shadow"
	var quad := PlaneMesh.new()
	quad.size = Vector2(0.95, 1.55)
	blob.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _soft_dot()
	mat.albedo_color = Color(0.0, 0.0, 0.0, 0.85)
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.render_priority = 1
	blob.material_override = mat
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blob.position = Vector3(0.0, 0.012, 0.0)
	car.add_child(blob)
	return blob


static var _dot_texture: Texture2D

func _soft_dot() -> Texture2D:
	if _dot_texture != null:
		return _dot_texture
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2((x + 0.5) / 64.0 - 0.5, (y + 0.5) / 64.0 - 0.5).length() * 2.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a * (3.0 - 2.0 * a)))
	_dot_texture = ImageTexture.create_from_image(img)
	return _dot_texture


## Sparks drifting up through the light: a few hundred small additive points, orange and blue.
func _build_motes() -> void:
	for kind in 2:
		var motes := CPUParticles3D.new()
		motes.name = "Motes"
		motes.amount = int(60.0 * PARTICLES[_detail()])
		motes.lifetime = 7.0
		motes.preprocess = 7.0
		motes.randomness = 1.0
		motes.local_coords = false
		motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		motes.emission_box_extents = Vector3(11.0, 0.5, 8.0)
		motes.position = Vector3(0.0, 0.2, -1.0)
		var quad := QuadMesh.new()
		quad.size = Vector2(0.07, 0.07)
		motes.mesh = quad
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.vertex_color_use_as_albedo = true
		mat.albedo_texture = _soft_dot()
		mat.albedo_color = Color(1.0, 0.6, 0.22) if kind == 0 else Color(0.4, 0.7, 1.0)
		mat.disable_fog = true
		mat.render_priority = 3
		motes.material_override = mat
		motes.direction = Vector3.UP
		motes.spread = 25.0
		motes.gravity = Vector3.ZERO
		motes.initial_velocity_min = 0.25
		motes.initial_velocity_max = 0.7
		motes.scale_amount_min = 0.5
		motes.scale_amount_max = 1.6
		var ramp := Gradient.new()
		ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
		ramp.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.0)])
		motes.color_ramp = ramp
		_world.add_child(motes)


func _build_overlay() -> void:
	_veil = ColorRect.new()
	_veil.name = "Vignette"
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = VIGNETTE_SHADER
	_veil.material = mat
	add_child(_veil)
	_flash = ColorRect.new()
	_flash.name = "Flash"
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1.0, 0.92, 0.78, 0.0)
	add_child(_flash)
	_prompt = Label.new()
	_prompt.name = "Prompt"
	_prompt.text = "PRESS ANY BUTTON" if not Input.get_connected_joypads().is_empty() else "PRESS ANY KEY"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt.anchor_left = 0.0
	_prompt.anchor_right = 1.0
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_left = 0.0
	_prompt.offset_right = 0.0
	_prompt.offset_top = -66.0
	_prompt.offset_bottom = -30.0
	_prompt.add_theme_font_size_override("font_size", 24)
	_prompt.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0))
	_prompt.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.06, 0.9))
	_prompt.add_theme_constant_override("outline_size", 8)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.modulate.a = 0.0
	add_child(_prompt)


# ---- The clock ---------------------------------------------------------------------------------------

func _apply(t: float) -> void:
	if _stage == null:
		return
	_apply_logo(t)
	for i in _cars.size():
		_apply_car(i, t)
	_apply_floor(t)
	_apply_camera(t)
	_apply_overlay(t)


func _apply_logo(t: float) -> void:
	var landed := T_FACES + FACE_STAGGER * (_faces.size() - 1) + FACE_TIME
	var float_in := smoothstep(landed - 0.2, landed + 1.0, t)
	var bob := sin(t * 1.35) * 0.07 * float_in
	var sway := sin(t * 0.7) * deg_to_rad(2.6) * float_in
	var xf := Transform3D(Basis.from_euler(Vector3(deg_to_rad(-2.5) * float_in, sway, 0.0)).scaled(Vector3.ONE * LOGO_SCALE),
		LOGO_POS + Vector3(0.0, bob, 0.0))
	for pivot in _logo:
		(pivot as Node3D).transform = xf

	# The rim and the body rise out of the floor's dark behind the letters.
	var up := clampf((t - T_PLATE) / 0.7, 0.0, 1.0)
	var rise := _ease_out_back(up, 1.2)
	var plate_xf := Transform3D(Basis.from_scale(Vector3(lerpf(0.88, 1.0, rise), lerpf(0.88, 1.0, rise), 1.0)),
		Vector3(0.0, lerpf(-0.7, 0.0, rise), lerpf(-1.6, 0.0, rise)))
	for plate in _plates:
		for side in ["real", "mirror"]:
			var mi := plate[side] as MeshInstance3D
			mi.visible = up > 0.0
			mi.transform = plate_xf
			mi.set_instance_shader_parameter("fade", smoothstep(0.0, 0.5, up))
	# The letters fly in from the camera's side, big and turning, and land.
	for i in _faces.size():
		var f: Dictionary = _faces[i]
		var u := clampf((t - T_FACES - FACE_STAGGER * i) / FACE_TIME, 0.0, 1.0)
		var home: Vector3 = f["home"]
		var e := _ease_out_back(u, 1.0)
		var fly := 1.0 - _ease_out_cubic(u)
		var spin := (-1.0 if i % 2 == 0 else 1.0) * deg_to_rad(38.0) * fly
		var face_xf := Transform3D(Basis.from_euler(Vector3(deg_to_rad(18.0) * fly, spin, 0.0)).scaled(Vector3.ONE * lerpf(FACE_START_SCALE, 1.0, e)),
			home + Vector3(0.0, 0.5 * fly, FACE_FLY * fly))
		for side in ["real", "mirror"]:
			var mi := f[side] as MeshInstance3D
			mi.visible = u > 0.0
			mi.transform = face_xf
			mi.set_instance_shader_parameter("fade", smoothstep(0.0, 0.12, u))
	# The highlight sweeping the letters, twice.
	var sweep := -1.0
	for start in [landed + 0.05, landed + 2.1]:
		if t >= start and t <= start + 1.1:
			sweep = (t - start) / 1.1
	_logo_mat.set_shader_parameter("sheen", sweep)


func _apply_car(i: int, t: float) -> void:
	var c: Dictionary = _cars[i]
	var spec: Dictionary = c["spec"]
	var from: Vector2 = spec["from"]
	var to: Vector2 = spec["to"]
	var u := clampf((t - float(spec["t0"])) / ARRIVE_TIME, 0.0, 1.0)
	var along := 1.0 - (1.0 - u) * (1.0 - u)
	var p := from.lerp(to, along)
	var travel := to - from
	var path_yaw := atan2(travel.x, travel.y)
	var final_yaw := deg_to_rad(float(spec["yaw"]))
	# The nose swings round to its place in the second half, the tail sliding out past it and back.
	var w := clampf((u - 0.4) / 0.6, 0.0, 1.0)
	var yaw := lerp_angle(path_yaw, final_yaw, smoothstep(0.0, 1.0, w)) + deg_to_rad(float(spec["drift"])) * sin(PI * w) * (1.0 - w * 0.3)
	var speed := 2.0 * (1.0 - u) * travel.length() / ARRIVE_TIME if u < 1.0 else 0.0
	c["speed"] = speed
	# On the brakes the nose dips and the body rolls into the slide; once stopped it settles on its springs.
	var since := maxf(t - (float(spec["t0"]) + ARRIVE_TIME), 0.0)
	var settle := exp(-since * 4.2) * cos(since * 15.0) if u >= 1.0 else 1.0
	var braking := smoothstep(0.3, 0.9, u) * (1.0 - smoothstep(0.9, 1.0, u)) if u < 1.0 else 0.0
	var pitch := deg_to_rad(3.0) * (braking + (settle * 0.55 if u >= 1.0 else 0.0))
	var roll := deg_to_rad(float(spec["drift"])) * 0.12 * sin(PI * w) if u < 1.0 else 0.0
	if u >= 1.0:
		# Parked, an engine idling: the body rocks on its springs a little.
		pitch += deg_to_rad(0.35) * sin(t * 2.3 + float(i) * 1.3)
		roll += deg_to_rad(0.25) * sin(t * 1.7 + float(i) * 2.1)
	var idle := sin(t * 21.0 + float(i) * 1.7) * 0.0035 if u >= 1.0 else 0.0
	var basis := Basis.from_euler(Vector3(pitch, yaw, roll)).scaled(Vector3.ONE * CAR_SCALE)
	var xf := Transform3D(basis, Vector3(p.x, idle, p.y))
	(c["real"] as Node3D).transform = xf
	(c["mirror"] as Node3D).transform = xf
	# Front wheels steer into the slide.
	var steer := deg_to_rad(float(spec["drift"])) * -0.9 * sin(PI * w) if u < 1.0 else 0.0
	for k in 4:
		var pair: Array = c["wheels"][k]
		for node in pair:
			(node as Node3D).rotation = Vector3(float(c["spin"]), steer if k < 2 else 0.0, 0.0)
	var dust: CPUParticles3D = c["dust"]
	dust.emitting = speed > 3.0 and _frames > WARMUP_FRAMES
	# The dust thrown back off the tyres while running; out to the side of the slide on the brakes.
	var side := -signf(float(spec["drift"])) * smoothstep(0.35, 0.8, u)
	dust.direction = Vector3(side * 0.9, 0.55, -1.0 + 0.9 * smoothstep(0.6, 1.0, u)).normalized()


## The wheels turn with the car's speed (the wheel's own frame is the cart's: forward is down the angle).
func _spin_wheels(delta: float) -> void:
	for c in _cars:
		c["spin"] = float(c["spin"]) - float(c["speed"]) * delta / (WHEEL_RADIUS * CAR_SCALE)


func _apply_floor(t: float) -> void:
	var landed := T_FACES + FACE_STAGGER * (_faces.size() - 1) + FACE_TIME
	var since := t - landed
	var ring := since * 17.0 if since >= 0.0 and since < 0.9 else -1.0
	_floor_mat.set_shader_parameter("ring_radius", ring)
	_floor_mat.set_shader_parameter("ring_alpha", clampf(1.0 - since / 0.9, 0.0, 1.0) if ring >= 0.0 else 0.0)
	var glow := smoothstep(T_PLATE - 0.2, landed + 0.4, t)
	_floor_mat.set_shader_parameter("pool", 0.32 * glow + 0.5 * exp(-maxf(since, 0.0) * 3.0) * float(since >= 0.0))
	# The light behind the logo comes up with it, and flares as the last letter lands.
	var burst := 0.9 * smoothstep(T_PLATE - 0.3, landed, t) + 0.9 * exp(-maxf(since, 0.0) * 3.5) * float(since >= 0.0)
	_burst_mat.set_shader_parameter("strength", burst)


func _apply_camera(t: float) -> void:
	# A slow push in with a drift across, low, looking up at the logo.
	var k := smoothstep(0.0, DURATION, t)
	# Each letter that lands knocks the camera a little, the last one hard; it settles in a moment.
	var jolt := 0.0
	for i in _faces.size():
		var since := t - (T_FACES + FACE_STAGGER * i + FACE_TIME)
		if since >= 0.0:
			jolt += (0.22 if i == _faces.size() - 1 else 0.035) * exp(-since * 7.0)
	var shake := Vector3(sin(t * 61.0), cos(t * 53.0) * 0.8, sin(t * 47.0 + 1.0) * 0.5) * jolt
	var pos := Vector3(lerpf(-1.0, 0.7, k), lerpf(1.6, 1.95, k), lerpf(16.5, 14.6, k)) + shake
	var target := Vector3(0.0, lerpf(2.9, 3.2, k), -6.0) + shake * 0.4
	_camera.look_at_from_position(pos, target, Vector3.UP)


func _apply_overlay(t: float) -> void:
	var dim := 1.0 - smoothstep(0.0, FADE_IN, t)
	(_veil.material as ShaderMaterial).set_shader_parameter("dim", dim)
	var landed := T_FACES + FACE_STAGGER * (_faces.size() - 1) + FACE_TIME
	var since := t - landed
	_flash.color.a = 0.3 * exp(-since * 8.0) if since >= 0.0 else 0.0
	var show := smoothstep(T_PROMPT, T_PROMPT + 0.6, t)
	_prompt.modulate.a = show * (0.65 + 0.35 * sin(t * 3.4))


# ---- Easing ------------------------------------------------------------------------------------------

func _ease_out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


## Overshoots and settles; `s` is how far.
func _ease_out_back(x: float, s: float) -> float:
	var c1 := 1.70158 * s
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)
