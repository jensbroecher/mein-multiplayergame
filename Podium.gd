extends Control
## The Grand Prix ceremony: the top three cars on a podium with a gold, silver and bronze trophy
## each, confetti, and the final standings. Built in code, like CarSelection; Podium.tscn is only
## the root.
##
## Main.gd instances it with setup(cup_name, ranking) once the last race is unloaded (ranking is
## NetworkManager.build_gp_ranking(): best first, each {name, points, car_index, paint, is_bot}),
## then calls start() when the loading screen has gone. `finished` fires on Continue.

signal finished

const CarPaint = preload("res://CarPaint.gd")
const SKY_SHADER = preload("res://showroom_sky.gdshader")
const FLOOR_SHADER = preload("res://showroom_floor.gdshader")
## The same car list PlayerCart races with (model_path, model_y_rotation, name).
const CAR_PRESETS = preload("res://PlayerCart.gd").CAR_PRESETS

const CAR_SCALE := 2.0            # what PlayerCart scales a car's scene by

# The stage, in metres. The camera looks along -Z; first place stands in the middle.
const BLOCK_W := 3.6
const BLOCK_D := 3.4
const BLOCK_H := [1.5, 1.05, 0.7]
const BLOCK_X := [0.0, -3.9, 3.9]
const CAR_YAW := [0.12, 0.55, -0.55]   # turned toward the middle
const TROPHY_SCALE := [1.2, 0.95, 0.85]
const MEDAL := [Color(1.0, 0.78, 0.26), Color(0.84, 0.87, 0.92), Color(0.86, 0.52, 0.26)]
const PLACE_TEXT := ["1", "2", "3"]
## Reveal order: third place first.
const REVEAL_ORDER := [2, 1, 0]
const REVEAL_FIRST := 0.4
const REVEAL_GAP := 1.35

const CAMERA_FOV := 34.0
const CAMERA_POS := Vector3(0.0, 4.4, 19.0)
const CAMERA_LOOK := Vector3(0.0, 1.5, 0.0)
## Shifts the picture left, leaving the right for the standings card.
const CAMERA_H_OFFSET := 1.4

# The main menu's palette.
const COL_TEAL := Color(0.15, 0.75, 0.92)
const COL_ORANGE := Color(1.0, 0.55, 0.16)
const COL_TEXT := Color(0.93, 0.95, 0.98)
const COL_DIM := Color(0.60, 0.66, 0.76)
const COL_CARD := Color(0.045, 0.052, 0.075, 0.82)

var _cup_name := ""
var _ranking: Array = []
var _local_names: Array = []

var _stage: SubViewport
var _camera: Camera3D
var _env_sky: Sky
var _podium: Array = []          # per place: {block, car, trophy, plate, light, yaw}
var _confetti: CPUParticles3D
var _burst: CPUParticles3D
var _glow: TextureRect
var _time := 0.0
var _started := false
var _scene_cache := {}

var _font_bold: FontVariation
var _font_title: FontVariation
var _title_box: Control
var _result_label: Label
var _standings_card: Control
var _continue: Button


func setup(cup_name: String, ranking: Array) -> void:
	_cup_name = cup_name
	_ranking = ranking


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_local_names = _find_local_names()
	_make_fonts()
	_build_backdrop()
	_build_stage()
	_build_podium()
	_build_ui()
	_pose_hidden()
	# Waiting for start(): the ceremony begins under a loading screen.
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	_glow.modulate.a = (0.0 if not _started else 0.5 + 0.1 * sin(_time * 1.3)) * _glow.get_meta("fade", 0.0)
	for i in _podium.size():
		var p: Dictionary = _podium[i]
		var trophy: Node3D = p["trophy"]
		trophy.rotation.y += delta * (0.9 if i == 0 else 0.6)
		# Cars idle with a slow sway; the winner's is bigger.
		var car: Node3D = p["car"]
		var sway := (0.16 if i == 0 else 0.07) * sin(_time * (0.9 if i == 0 else 0.6) + i)
		car.rotation.y = PI + float(CAR_YAW[i]) + sway
	if _started:
		var t := _time - _start_time
		var push := clampf(t / 7.0, 0.0, 1.0)
		var pos := CAMERA_POS.lerp(CAMERA_POS + Vector3(0.0, -0.5, -2.2), push * push * (3.0 - 2.0 * push))
		pos.x += sin(t * 0.28) * 1.1
		_camera.look_at_from_position(pos, CAMERA_LOOK + Vector3(sin(t * 0.28) * 0.3, 0.0, 0.0), Vector3.UP)


var _start_time := 0.0


## Begins the reveal: third place first, the winner last, then the confetti and the standings.
func start() -> void:
	if _started:
		return
	_started = true
	_start_time = _time
	_play_music()
	var tw := create_tween()
	tw.tween_property(_title_box, "modulate:a", 1.0, 0.7)
	for n in REVEAL_ORDER.size():
		var place: int = REVEAL_ORDER[n]
		if place >= _podium.size():
			continue
		var at := REVEAL_FIRST + n * REVEAL_GAP
		get_tree().create_timer(at).timeout.connect(_reveal.bind(place))
	var end_at := REVEAL_FIRST + REVEAL_ORDER.size() * REVEAL_GAP
	get_tree().create_timer(end_at).timeout.connect(_celebrate)
	get_tree().create_timer(end_at + 1.0).timeout.connect(_show_standings)


func _play_music() -> void:
	MusicManager._load_playlist("res://music/festival/")
	MusicManager.play_next()


func _reveal(place: int) -> void:
	if not is_inside_tree():
		return
	var p: Dictionary = _podium[place]
	var block: Node3D = p["block"]
	var car: Node3D = p["car"]
	var trophy: Node3D = p["trophy"]
	var plate: Node3D = p["plate"]
	var h: float = BLOCK_H[place]
	block.visible = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(block, "scale:y", 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# The car drops onto the block with a bounce.
	car.visible = true
	car.position.y = h + 5.0
	tw.tween_property(car, "position:y", h, 0.7).set_delay(0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	trophy.visible = true
	trophy.scale = Vector3.ZERO
	tw.tween_property(trophy, "scale", Vector3.ONE * float(TROPHY_SCALE[place]), 0.55).set_delay(0.7) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	plate.visible = true
	plate.scale = Vector3.ZERO
	tw.tween_property(plate, "scale", Vector3.ONE, 0.4).set_delay(0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var light: SpotLight3D = p["light"]
	light.visible = true
	# The announcer calls each place as it is revealed.
	MusicManager.play_place_voice(place + 1)


func _celebrate() -> void:
	if not is_inside_tree():
		return
	_burst.restart()
	_burst.emitting = true
	_confetti.emitting = true
	create_tween().tween_method(func(v: float): _glow.set_meta("fade", v), 0.0, 1.0, 1.2)
	create_tween().tween_property(_result_label, "modulate:a", 1.0, 0.8)


func _show_standings() -> void:
	if not is_inside_tree():
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_standings_card, "modulate:a", 1.0, 0.7)
	tw.tween_property(_standings_card, "position:x", _standings_card.position.x, 0.7) \
			.from(_standings_card.position.x + 60.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_continue.modulate.a = 0.0
	_continue.show()
	tw.tween_property(_continue, "modulate:a", 1.0, 0.6).set_delay(0.5)
	get_tree().create_timer(0.5).timeout.connect(func(): _continue.grab_focus())


func _on_continue_pressed() -> void:
	_continue.disabled = true
	finished.emit()


## Anyone enabled to read the standings as "you": the host's own name, or both split-screen players.
func _find_local_names() -> Array:
	var names: Array = []
	if NetworkManager.current_game_mode == NetworkManager.GameMode.LOCAL_COOP:
		for id in NetworkManager.players:
			if not NetworkManager.players[id].get("is_ai", false):
				names.append(str(NetworkManager.players[id].get("name", "")))
	else:
		var me: int = multiplayer.get_unique_id()
		if NetworkManager.players.has(me):
			names.append(str(NetworkManager.players[me].get("name", "")))
	return names


# ============================================================================================
#  Stage
# ============================================================================================

func _build_backdrop() -> void:
	var bg := TextureRect.new()
	bg.name = "Backdrop"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([Color(0.025, 0.03, 0.055), Color(0.07, 0.09, 0.15), Color(0.02, 0.024, 0.04)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 8
	tex.height = 256
	bg.texture = tex
	add_child(bg)

	# A warm pool of light behind the winner, pulsing once they are crowned.
	_glow = TextureRect.new()
	_glow.name = "Glow"
	_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gg := Gradient.new()
	gg.colors = PackedColorArray([Color(1.0, 0.72, 0.3, 0.55), Color(1.0, 0.72, 0.3, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = gg
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.42, 0.55)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 256
	gt.height = 256
	_glow.texture = gt
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add_mat
	_glow.modulate.a = 0.0
	add_child(_glow)


func _build_stage() -> void:
	var holder := SubViewportContainer.new()
	holder.name = "Stage"
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_stage = SubViewport.new()
	_stage.own_world_3d = true
	_stage.transparent_bg = true
	_stage.msaa_3d = Viewport.MSAA_4X
	_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	holder.add_child(_stage)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	_env_sky = Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	_env_sky.sky_material = sky_mat
	env.sky = _env_sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.3
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	_stage.add_child(we)

	var key := DirectionalLight3D.new()
	key.light_energy = 1.5
	key.light_color = Color(1.0, 0.96, 0.9)
	key.shadow_enabled = true
	key.shadow_bias = 0.04
	key.shadow_normal_bias = 2.4
	key.shadow_blur = 1.0
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 18.0
	key.directional_shadow_pancake_size = 15.0
	key.rotation = Vector3(deg_to_rad(-52.0), deg_to_rad(-22.0), 0.0)
	_stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_energy = 1.0
	rim.light_color = Color(0.70, 0.84, 1.0)
	rim.rotation = Vector3(deg_to_rad(-22.0), deg_to_rad(165.0), 0.0)
	_stage.add_child(rim)

	_camera = Camera3D.new()
	_camera.fov = CAMERA_FOV
	_camera.h_offset = CAMERA_H_OFFSET
	_camera.near = 0.1
	_camera.far = 80.0
	_stage.add_child(_camera)
	_camera.look_at_from_position(CAMERA_POS, CAMERA_LOOK, Vector3.UP)
	_camera.current = true

	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 60.0)
	floor_mi.mesh = plane
	var floor_mat := ShaderMaterial.new()
	floor_mat.shader = FLOOR_SHADER
	floor_mat.set_shader_parameter("radius", 20.0)
	floor_mi.material_override = floor_mat
	floor_mi.position.y = -0.005
	floor_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stage.add_child(floor_mi)

	# Confetti: a slow rain from above, and a burst from the winner's block.
	_confetti = _make_confetti(false)
	_confetti.position = Vector3(0.0, 9.0, 1.0)
	_stage.add_child(_confetti)
	_burst = _make_confetti(true)
	_burst.position = Vector3(0.0, float(BLOCK_H[0]) + 1.0, 1.2)
	_stage.add_child(_burst)


func _make_confetti(burst: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = burst
	p.amount = 140 if burst else 160
	p.lifetime = 3.2 if burst else 6.0
	p.explosiveness = 0.95 if burst else 0.0
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.16)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_is_srgb = true
	quad.material = mat
	p.mesh = quad
	var colors := Gradient.new()
	colors.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	colors.offsets = PackedFloat32Array([0.0, 0.17, 0.34, 0.51, 0.68, 0.85])
	colors.colors = PackedColorArray([Color(1.0, 0.82, 0.25), Color(0.25, 0.8, 1.0), Color(1.0, 0.35, 0.45),
			Color(0.5, 1.0, 0.55), Color(1.0, 1.0, 1.0), Color(0.75, 0.5, 1.0)])
	p.color_initial_ramp = colors
	p.angle_max = 360.0
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	if burst:
		p.direction = Vector3(0.0, 1.0, 0.0)
		p.spread = 55.0
		p.initial_velocity_min = 6.0
		p.initial_velocity_max = 12.0
		p.gravity = Vector3(0.0, -7.0, 0.0)
		p.damping_min = 0.6
		p.damping_max = 1.4
	else:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(8.0, 0.3, 3.0)
		p.direction = Vector3(0.0, -1.0, 0.0)
		p.spread = 12.0
		p.initial_velocity_min = 0.5
		p.initial_velocity_max = 1.5
		p.gravity = Vector3(0.0, -1.2, 0.0)
		p.damping_min = 0.2
		p.damping_max = 0.6
	return p


func _car_scene(path: String) -> PackedScene:
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path)
	return _scene_cache[path]


## The bounds of every visible mesh under `node`, in `space`'s frame.
static func _bounds(node: Node, space: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var to_space: Transform3D = space.global_transform.affine_inverse()
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and (n as MeshInstance3D).visible:
			var mi := n as MeshInstance3D
			var b: AABB = to_space * mi.global_transform * mi.mesh.get_aabb()
			box = b if first else box.merge(b)
			first = false
		stack.append_array(n.get_children())
	return box


func _metal(color: Color, rough: float, metallic := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = rough
	return m


func _build_podium() -> void:
	var body_mat := _metal(Color(0.10, 0.115, 0.15), 0.38, 0.45)
	for place in mini(3, _ranking.size()):
		var entry: Dictionary = _ranking[place]
		var medal: Color = MEDAL[place]
		var h: float = BLOCK_H[place]
		var x: float = BLOCK_X[place]
		var root := Node3D.new()
		root.name = "Place%d" % (place + 1)
		root.position = Vector3(x, 0.0, 0.0)
		_stage.add_child(root)

		# The block: a dark body with a medal-coloured top plate and numeral. It grows from the
		# floor, so its pivot is at the bottom.
		var block := Node3D.new()
		block.name = "Block"
		root.add_child(block)
		var body := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(BLOCK_W, h, BLOCK_D)
		body.mesh = bm
		body.position.y = h * 0.5
		body.material_override = body_mat
		block.add_child(body)
		var top := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(BLOCK_W + 0.08, 0.07, BLOCK_D + 0.08)
		top.mesh = tm
		top.position.y = h + 0.035
		var top_mat := _metal(medal, 0.35, 0.6)
		top.material_override = top_mat
		top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		block.add_child(top)
		var numeral := Label3D.new()
		numeral.text = PLACE_TEXT[place]
		numeral.font = _font_title
		numeral.font_size = 200
		numeral.pixel_size = 0.55 * h / (0.72 * 200.0)
		numeral.modulate = medal
		numeral.outline_size = 0
		numeral.shaded = false
		numeral.double_sided = false
		numeral.position = Vector3(-0.75, h * 0.5, BLOCK_D * 0.5 + 0.03)
		block.add_child(numeral)

		# The car.
		var car := Node3D.new()
		car.name = "Car"
		car.position = Vector3(0.0, h, 0.0)
		root.add_child(car)
		_add_car(car, entry)

		# The trophy, standing in front of the block, right of the numeral.
		var trophy := Node3D.new()
		trophy.name = "Trophy"
		trophy.position = Vector3(1.05, 0.0, BLOCK_D * 0.5 + 1.0)
		root.add_child(trophy)
		_add_trophy(trophy, medal)

		# Name and points over the car.
		var plate := Node3D.new()
		plate.name = "Plate"
		plate.position = Vector3(0.0, h + 2.0, 0.0)
		root.add_child(plate)
		var name_l := Label3D.new()
		name_l.text = str(entry["name"]).to_upper()
		name_l.font = _font_bold
		name_l.font_size = 72
		name_l.pixel_size = 0.0042
		name_l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		name_l.no_depth_test = true
		name_l.outline_size = 16
		name_l.outline_modulate = Color(0, 0, 0, 0.85)
		name_l.modulate = Color(1, 1, 1)
		name_l.position.y = 0.16
		plate.add_child(name_l)
		var pts_l := Label3D.new()
		pts_l.text = "%d PTS" % int(entry["points"])
		pts_l.font = _font_bold
		pts_l.font_size = 52
		pts_l.pixel_size = 0.0042
		pts_l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		pts_l.no_depth_test = true
		pts_l.outline_size = 14
		pts_l.outline_modulate = Color(0, 0, 0, 0.85)
		pts_l.modulate = medal
		pts_l.position.y = -0.12
		plate.add_child(pts_l)

		# A spotlight in the medal's colour.
		var light := SpotLight3D.new()
		light.light_color = medal.lerp(Color.WHITE, 0.45)
		light.light_energy = 5.0 if place == 0 else 3.5
		light.spot_range = 20.0
		light.spot_angle = 24.0
		light.spot_attenuation = 0.6
		light.position = Vector3(0.0, h + 9.0, 4.5)
		root.add_child(light)
		light.look_at(root.global_position + Vector3(0.0, h + 0.5, 0.0), Vector3.UP)

		_podium.append({"block": block, "car": car, "trophy": trophy, "plate": plate, "light": light, "root": root})


func _add_car(holder: Node3D, entry: Dictionary) -> void:
	var idx: int = clampi(int(entry.get("car_index", 0)), 0, CAR_PRESETS.size() - 1)
	var preset: Dictionary = CAR_PRESETS[idx]
	var scene: PackedScene = _car_scene(preset.model_path)
	if scene == null:
		return
	var model: Node3D = scene.instantiate()
	holder.add_child(model)
	model.transform = Transform3D(Basis(Vector3.UP, preset.get("model_y_rotation", PI)) * CAR_SCALE, Vector3.ZERO)
	if CarPaint.is_paintable(model):
		CarPaint.apply(model, CarPaint.sanitize(entry.get("paint", {}), preset.name))
	# Centre it on the block and stand it on the top.
	var box: AABB = _bounds(model, holder)
	if box.size != Vector3.ZERO:
		var centre: Vector3 = box.get_center()
		model.position -= Vector3(centre.x, box.position.y, centre.z)


## A cup on a base with two handles, lathed from a profile; `color` is the metal.
func _add_trophy(holder: Node3D, color: Color) -> void:
	var mat := _metal(color, 0.3, 0.8)
	# The studio sky is dark: a little self-light keeps the metal from going black.
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.25
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cup := MeshInstance3D.new()
	cup.mesh = _trophy_mesh()
	cup.material_override = mat
	cup.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	holder.add_child(cup)
	for side in [-1.0, 1.0]:
		var handle := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.1
		torus.outer_radius = 0.16
		torus.rings = 24
		torus.ring_segments = 10
		handle.mesh = torus
		handle.rotation.x = PI * 0.5
		handle.scale = Vector3(1.0, 1.0, 1.5)
		handle.position = Vector3(side * 0.43, 0.8, 0.0)
		handle.material_override = mat
		holder.add_child(handle)


## The cup's profile (radius, height) from the bottom of the base, up the outside, over the rim and
## down the inside: one lathe. Hard corners get their own vertices so they stay crisp.
static func _trophy_profile() -> Array:
	return [
		Vector2(0.0, 0.0), Vector2(0.36, 0.0), Vector2(0.36, 0.05), Vector2(0.31, 0.09),
		Vector2(0.31, 0.15), Vector2(0.21, 0.18), Vector2(0.075, 0.25), Vector2(0.055, 0.34),
		Vector2(0.055, 0.44), Vector2(0.10, 0.48), Vector2(0.10, 0.52), Vector2(0.06, 0.54),
		Vector2(0.16, 0.57), Vector2(0.28, 0.64), Vector2(0.36, 0.75), Vector2(0.40, 0.88),
		Vector2(0.41, 1.0),
		Vector2(0.385, 1.0), Vector2(0.37, 0.88), Vector2(0.32, 0.77), Vector2(0.22, 0.69),
		Vector2(0.10, 0.65), Vector2(0.0, 0.63),
	]


static func _trophy_mesh() -> ArrayMesh:
	var profile: Array = _trophy_profile()
	var segs := 40
	# Split the polyline into smooth runs at corners sharper than ~50 degrees.
	var runs: Array = []
	var run: Array = [profile[0]]
	for i in range(1, profile.size()):
		run.append(profile[i])
		if i < profile.size() - 1:
			var a: Vector2 = (profile[i] - profile[i - 1]).normalized()
			var b: Vector2 = (profile[i + 1] - profile[i]).normalized()
			if a.dot(b) < 0.64:
				runs.append(run)
				run = [profile[i]]
	runs.append(run)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in runs:
		var pts: Array = r
		# Outward normal of each profile point in (radius, height): the segment's (dy, -dr) averaged.
		var norms: Array = []
		for i in pts.size():
			var d := Vector2.ZERO
			if i > 0:
				d += (pts[i] - pts[i - 1]).normalized()
			if i < pts.size() - 1:
				d += (pts[i + 1] - pts[i]).normalized()
			d = d.normalized()
			norms.append(Vector2(d.y, -d.x))
		for i in range(pts.size() - 1):
			for s in segs:
				var a0 := TAU * s / segs
				var a1 := TAU * (s + 1) / segs
				var v := [_lathe(pts[i], a0), _lathe(pts[i + 1], a0), _lathe(pts[i + 1], a1), _lathe(pts[i], a1)]
				var n := [_lathe_normal(norms[i], a0), _lathe_normal(norms[i + 1], a0),
						_lathe_normal(norms[i + 1], a1), _lathe_normal(norms[i], a1)]
				for tri in [[0, 1, 2], [0, 2, 3]]:
					var pa: Vector3 = v[tri[0]]
					var pb: Vector3 = v[tri[1]]
					var pc: Vector3 = v[tri[2]]
					var order: Array = tri
					# Godot's front faces wind clockwise: (c - a) x (b - a) is the front normal.
					var fn: Vector3 = (pc - pa).cross(pb - pa)
					var want: Vector3 = (n[tri[0]] as Vector3) + (n[tri[1]] as Vector3) + (n[tri[2]] as Vector3)
					if fn.dot(want) < 0.0:
						order = [tri[0], tri[2], tri[1]]
					for k in order:
						st.set_normal(n[k])
						st.add_vertex(v[k])
	return st.commit()


static func _lathe(p: Vector2, angle: float) -> Vector3:
	return Vector3(cos(angle) * p.x, p.y, sin(angle) * p.x)


static func _lathe_normal(n: Vector2, angle: float) -> Vector3:
	return Vector3(cos(angle) * n.x, n.y, sin(angle) * n.x).normalized()


## Everything starts hidden; start() reveals it.
func _pose_hidden() -> void:
	for p in _podium:
		(p["block"] as Node3D).visible = false
		(p["block"] as Node3D).scale.y = 0.001
		(p["car"] as Node3D).visible = false
		(p["trophy"] as Node3D).visible = false
		(p["plate"] as Node3D).visible = false
		(p["light"] as Node3D).visible = false
	_title_box.modulate.a = 0.0
	_result_label.modulate.a = 0.0
	_standings_card.modulate.a = 0.0
	_continue.hide()


# ============================================================================================
#  Screen layout
# ============================================================================================

func _make_fonts() -> void:
	_font_bold = FontVariation.new()
	_font_bold.base_font = ThemeDB.fallback_font
	_font_bold.variation_embolden = 0.7
	_font_bold.spacing_glyph = 1
	_font_title = FontVariation.new()
	_font_title.base_font = ThemeDB.fallback_font
	_font_title.variation_embolden = 1.1
	_font_title.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(0.22, 1.0), Vector2.ZERO)


func _label(text: String, size: int, color: Color, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_ui() -> void:
	# Title, top centre.
	var title := VBoxContainer.new()
	title.name = "Title"
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.offset_left = -450.0
	title.offset_right = 450.0
	title.offset_top = 40.0
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_constant_override("separation", 2)
	var kicker := _label("GRAND PRIX COMPLETE", 20, COL_TEAL, _font_bold)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_child(kicker)
	var cup := _label(_cup_name.to_upper(), 54, COL_TEXT, _font_title)
	cup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_child(cup)
	add_child(title)
	_title_box = title

	# Result line, under the podium.
	_result_label = _label(_result_text(), 28, MEDAL[0], _font_bold)
	_result_label.name = "Result"
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.anchor_left = 0.5
	_result_label.anchor_right = 0.5
	_result_label.anchor_top = 1.0
	_result_label.anchor_bottom = 1.0
	_result_label.offset_left = -450.0
	_result_label.offset_right = 450.0
	_result_label.offset_top = -150.0
	_result_label.offset_bottom = -110.0
	add_child(_result_label)

	# Final standings, right.
	var card := PanelContainer.new()
	card.name = "Standings"
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_CARD
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(2)
	sb.border_color = Color(COL_TEAL, 0.55)
	sb.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", sb)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.anchor_left = 1.0
	card.anchor_right = 1.0
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_right = -28.0
	card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.custom_minimum_size = Vector2(300, 0)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vb)
	vb.add_child(_label("FINAL STANDINGS", 18, COL_TEAL, _font_bold))
	var line := ColorRect.new()
	line.color = Color(COL_TEAL, 0.6)
	line.custom_minimum_size = Vector2(0, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(line)
	for i in _ranking.size():
		var e: Dictionary = _ranking[i]
		var mine: bool = _local_names.has(str(e["name"]))
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var col: Color = MEDAL[i] if i < 3 else COL_DIM
		var pos := _label(str(i + 1), 22, col, _font_bold)
		pos.custom_minimum_size = Vector2(32, 0)
		row.add_child(pos)
		var nm := _label(str(e["name"]) + ("  (YOU)" if mine else ""), 20, COL_ORANGE if mine else COL_TEXT, _font_bold)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		row.add_child(nm)
		var pts := _label("%d" % int(e["points"]), 20, col if i < 3 else COL_TEXT, _font_bold)
		pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pts.custom_minimum_size = Vector2(48, 0)
		row.add_child(pts)
		vb.add_child(row)
	add_child(card)
	_standings_card = card

	# Continue, bottom centre.
	_continue = Button.new()
	_continue.name = "Continue"
	_continue.text = "CONTINUE"
	_continue.add_theme_font_override("font", _font_bold)
	_continue.add_theme_font_size_override("font_size", 22)
	_continue.anchor_left = 0.5
	_continue.anchor_right = 0.5
	_continue.anchor_top = 1.0
	_continue.anchor_bottom = 1.0
	_continue.offset_left = -130.0
	_continue.offset_right = 130.0
	_continue.offset_top = -84.0
	_continue.offset_bottom = -30.0
	for state in ["normal", "hover", "pressed", "focus"]:
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(10)
		s.bg_color = COL_ORANGE if state != "normal" else Color(0.12, 0.14, 0.2)
		s.set_border_width_all(2)
		s.border_color = COL_ORANGE
		_continue.add_theme_stylebox_override(state, s)
	_continue.add_theme_color_override("font_color", COL_TEXT)
	_continue.add_theme_color_override("font_hover_color", Color.BLACK)
	_continue.add_theme_color_override("font_focus_color", Color.BLACK)
	_continue.pressed.connect(_on_continue_pressed)
	_continue.set_meta(&"ui_important", true)
	add_child(_continue)


func _result_text() -> String:
	if _ranking.is_empty():
		return ""
	var winner: String = str(_ranking[0]["name"])
	for i in _ranking.size():
		if _local_names.has(str(_ranking[i]["name"])):
			if i == 0:
				return "%s WINS THE CUP!" % winner.to_upper() if _local_names.size() > 1 else "YOU WIN THE CUP!"
			var places := ["", "2ND", "3RD"]
			var place: String = places[i] if i < 3 else "%dTH" % (i + 1)
			return "YOU FINISHED %s  ·  %s TAKES THE CUP" % [place, winner.to_upper()]
	return "%s TAKES THE CUP" % winner.to_upper()
