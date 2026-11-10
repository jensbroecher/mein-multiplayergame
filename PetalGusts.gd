extends Node3D
## Cherry blossom in the air on the Miyoshino GP's stages: petals drifting down round the camera all the time, and at
## set places gusts that blow a cloud of them across the road and nudge the cars sideways (Senbon Sakura Pass's
## corners; the Yamabushi Trail's ridge with `mist` set: wisps of cloud instead of petals).
##
## Everything is built here as internal children, so a level stores only this node and its exports. Gusts run on the
## wall clock (seconds into the UTC day), so LAN peers see them together without syncing; only carts this peer has
## physics authority over are pushed. Nothing is made in the generator or on a headless server.

## Gust places: [position on the road (Vector3), the wind's way (Vector3, level, unit: across the road), half length
## along the road (m), period (s), phase (s)].
@export var spots: Array = []
## How long a gust blows, and its peak sideways push (m/s^2: a cart's grip is about 5, so 14 slides it about a
## lane's width).
@export var gust_seconds := 3.6
@export var push_accel := 14.0
@export var petal_color := Color(1.0, 0.80, 0.86)
## Petals falling round the camera (0 for none).
@export var falling := 260
## Wisps of cloud in the gusts instead of petals (the trail's ridge).
@export var mist := false
@export var sound_path := "res://sounds/Strong_wind_blowing.wav"
@export var sound_db := -16.0

var _fall: GPUParticles3D
var _gusts: Array = []     # [GPUParticles3D, AudioStreamPlayer3D]
var _petal_mesh: QuadMesh


func _ready() -> void:
	if Engine.is_editor_hint() or _in_generator() or DisplayServer.get_name() == "headless":
		set_process(false)
		if spots.is_empty() or Engine.is_editor_hint() or _in_generator():
			set_physics_process(false)
		return
	_petal_mesh = QuadMesh.new()
	_petal_mesh.size = Vector2(0.16, 0.12) if not mist else Vector2(7.0, 4.0)
	_petal_mesh.material = _material()
	if falling > 0 and not mist:
		_fall = GPUParticles3D.new()
		_fall.name = "FallingPetals"
		_fall.amount = falling
		_fall.lifetime = 8.0
		_fall.preprocess = 8.0
		_fall.local_coords = false
		_fall.visibility_aabb = AABB(Vector3(-40, -30, -40), Vector3(80, 60, 80))
		_fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(26.0, 5.0, 26.0)
		pm.direction = Vector3(0.4, -1.0, 0.2)
		pm.spread = 25.0
		pm.initial_velocity_min = 0.6
		pm.initial_velocity_max = 1.6
		pm.gravity = Vector3(0.5, -0.9, 0.25)
		pm.angle_min = -180.0
		pm.angle_max = 180.0
		pm.angular_velocity_min = -160.0
		pm.angular_velocity_max = 160.0
		pm.scale_min = 0.6
		pm.scale_max = 1.3
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 0.6
		pm.turbulence_noise_scale = 3.0
		pm.turbulence_influence_min = 0.05
		pm.turbulence_influence_max = 0.2
		_fall.process_material = pm
		_fall.draw_pass_1 = _petal_mesh
		_fall.top_level = true
		add_child(_fall, false, Node.INTERNAL_MODE_BACK)
	for sp in spots:
		var pos: Vector3 = sp[0]
		var dir: Vector3 = (sp[1] as Vector3).normalized()
		var half: float = sp[2]
		var along := Vector3(-dir.z, 0.0, dir.x)
		var g := GPUParticles3D.new()
		g.amount = 420 if not mist else 36
		g.lifetime = 3.2 if not mist else 5.0
		g.emitting = false
		g.local_coords = false
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.visibility_aabb = AABB(Vector3(-80, -10, -80), Vector3(160, 40, 160))
		var gm := ParticleProcessMaterial.new()
		gm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		# The box lies along the road, upwind of it.
		gm.emission_box_extents = Vector3(half, 3.2 if not mist else 5.0, 5.0)
		gm.direction = Vector3(0, 0.08, 1)
		gm.spread = 14.0
		gm.initial_velocity_min = 11.0 if not mist else 8.0
		gm.initial_velocity_max = 19.0 if not mist else 13.0
		gm.gravity = Vector3(0, -1.2 if not mist else 0.2, 0)
		gm.angle_min = -180.0
		gm.angle_max = 180.0
		gm.angular_velocity_min = -300.0 if not mist else -12.0
		gm.angular_velocity_max = 300.0 if not mist else 12.0
		gm.scale_min = 0.7
		gm.scale_max = 1.5
		if mist:
			var grad := Gradient.new()
			grad.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
			grad.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
			var gt := GradientTexture1D.new()
			gt.gradient = grad
			gm.color_ramp = gt
		g.process_material = gm
		g.draw_pass_1 = _petal_mesh
		# Its z is the wind's way, its x along the road; it stands upwind of the road and a little up.
		g.transform = Transform3D(Basis(along, Vector3.UP, dir), pos - dir * 16.0 + Vector3(0, 3.6, 0))
		add_child(g, false, Node.INTERNAL_MODE_BACK)
		var snd: AudioStreamPlayer3D = null
		if ResourceLoader.exists(sound_path):
			snd = AudioStreamPlayer3D.new()
			snd.stream = load(sound_path)
			snd.volume_db = -60.0
			snd.unit_size = 26.0
			snd.max_distance = 160.0
			snd.bus = &"SFX"
			snd.position = pos + Vector3(0, 2, 0)
			add_child(snd, false, Node.INTERNAL_MODE_BACK)
		_gusts.append([g, snd])


func _in_generator() -> bool:
	for child in get_tree().root.get_children():
		if "regenerate" in str(child.name).to_lower():
			return true
	return false


func _material() -> Material:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if not mist else BaseMaterial3D.SHADING_MODE_PER_VERTEX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _texture()
	if mist:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.93, 0.94, 0.96)
		m.disable_receive_shadows = true
	else:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.albedo_color = petal_color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## A petal (a notched ellipse, paler toward its base) or, for mist, a soft ragged puff.
func _texture() -> Texture2D:
	var n := 48 if not mist else 96
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var nz := FastNoiseLite.new()
	nz.frequency = 0.05
	for y in range(n):
		for x in range(n):
			var u: float = (float(x) + 0.5) / float(n) * 2.0 - 1.0
			var v: float = (float(y) + 0.5) / float(n) * 2.0 - 1.0
			var a := 0.0
			var c := Color(1, 1, 1)
			if mist:
				a = clampf(1.0 - Vector2(u, v).length(), 0.0, 1.0)
				a = a * a * (3.0 - 2.0 * a) * clampf(0.6 + 0.8 * nz.get_noise_2d(x, y), 0.0, 1.0)
			else:
				# An ellipse pinched toward one end (the base) with a small notch at the other.
				var w: float = 0.62 + 0.3 * u
				var inside: bool = u * u + (v / maxf(w, 0.05)) * (v / maxf(w, 0.05)) < 0.92
				var notch: bool = Vector2(u - 1.0, v).length() < 0.22
				a = 1.0 if inside and not notch else 0.0
				c = Color(1.0, 0.86 + 0.14 * (0.5 - u * 0.5), 0.9 + 0.1 * (0.5 - u * 0.5))
			img.set_pixel(x, y, Color(c.r, c.g, c.b, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _clock() -> float:
	return fmod(Time.get_unix_time_from_system(), 86400.0)


## How hard the gust at spot i blows now (0..1): a swell and a fade inside its window.
func strength(i: int, t: float) -> float:
	var sp: Array = spots[i]
	var ph: float = fposmod(t + float(sp[4]), float(sp[3]))
	if ph > gust_seconds:
		return 0.0
	return sin(ph / gust_seconds * PI)


func _process(_delta: float) -> void:
	var vp := get_viewport()
	var cam: Camera3D = vp.get_camera_3d() if vp else null
	if _fall and cam:
		_fall.global_position = cam.global_position + Vector3(0.0, 7.0, 0.0) - cam.global_basis.z * 10.0
	var t: float = _clock()
	for i in range(_gusts.size()):
		var s: float = strength(i, t)
		var g: GPUParticles3D = _gusts[i][0]
		var on: bool = s > 0.02
		if g.emitting != on:
			g.emitting = on
		var snd: AudioStreamPlayer3D = _gusts[i][1]
		if snd:
			if on and not snd.playing:
				snd.play(randf() * 2.0)
			elif not on and snd.playing and snd.volume_db < -50.0:
				snd.stop()
			snd.volume_db = lerpf(snd.volume_db, sound_db if on else -60.0, 0.08)


func _physics_process(_delta: float) -> void:
	if spots.is_empty():
		return
	var t: float = _clock()
	for i in range(spots.size()):
		var s: float = strength(i, t)
		if s <= 0.02:
			continue
		var sp: Array = spots[i]
		var pos: Vector3 = sp[0]
		var dir: Vector3 = sp[1]
		var half: float = sp[2]
		var along := Vector3(-dir.z, 0.0, dir.x)
		for cart in get_tree().get_nodes_in_group("player_carts"):
			if not (cart is RigidBody3D):
				continue
			if cart.has_method("has_physics_authority") and not cart.has_physics_authority():
				continue
			if not cart.get("can_move") or cart.get("is_exploding"):
				continue
			var body := cart as RigidBody3D
			var rel: Vector3 = body.global_position - pos
			if absf(rel.y) > 8.0 or absf(rel.dot(along)) > half or absf(rel.dot(dir)) > 16.0:
				continue
			var edge: float = 1.0 - smoothstep(half * 0.7, half, absf(rel.dot(along)))
			body.apply_central_force(dir * push_accel * s * edge * body.mass)
