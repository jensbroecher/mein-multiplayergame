extends Node3D
## Fireworks over the sea (Marina Nights): shells rise from barges on the water and burst into spheres of stars
## (peony), rings, willows that droop and crackle, now and then a volley. The show runs on the wall clock, so LAN
## peers see the same bursts at the same moments; nothing is synced. Each burst is a GPUParticles3D from a small pool,
## restarted where and when the clock says (one_shot, all at once), the rising shell a second one. Each burst lights
## the water and the quays under it briefly (a pooled OmniLight), and its boom arrives after the distance's delay
## (synthesised, no recording). `area` is the box (local) the bursts fill, `barges` where the shells rise from.
## Nothing here is solid; DressingColliders skips it (no meshes of its own).

@export var area := AABB(Vector3(-500, 70, -40), Vector3(1000, 90, 120))
@export var interval := 1.6          # mean seconds between shells
@export var volley_every := 26.0     # seconds between volleys (8 shells together)
@export var seed_base := 4242

const POOL := 12
const COLOURS := [Color(1.0, 0.25, 0.2), Color(1.0, 0.75, 0.25), Color(0.35, 0.65, 1.0), Color(0.45, 1.0, 0.45),
	Color(1.0, 0.4, 0.9), Color(1.0, 0.95, 0.85), Color(0.7, 0.4, 1.0), Color(0.2, 0.95, 0.9)]
const RISE := 1.6                    # seconds from launch to burst

var _bursts: Array = []              # GPUParticles3D
var _shells: Array = []              # GPUParticles3D (the rising trail)
var _lights: Array = []              # OmniLight3D
var _players: Array = []             # AudioStreamPlayer3D
var _next := 0
var _last_slot := -1
var _boom: AudioStreamWAV
var _pending: Array = []             # [time, kind, args]
var _light_t: Array = []


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_boom = _make_boom()
	for i in range(POOL):
		_bursts.append(_make_burst())
		_shells.append(_make_shell())
		var l := OmniLight3D.new()
		l.light_energy = 0.0
		l.omni_range = 160.0
		l.omni_attenuation = 1.6
		l.shadow_enabled = false
		l.set_meta(&"no_shadow", true)
		add_child(l)
		_lights.append(l)
		_light_t.append(-100.0)
		var p := AudioStreamPlayer3D.new()
		p.stream = _boom
		p.unit_size = 120.0
		p.max_db = 0.0
		p.volume_db = -8.0
		p.attenuation_filter_db = -6.0
		p.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
		add_child(p)
		_players.append(p)


func _now() -> float:
	return Time.get_unix_time_from_system()


## The shells of slot `k` (one per `interval` seconds): how many, and each one's place, colour and kind, from a hash
## of the slot, so every peer draws the same.
func _slot(k: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(k * 7919 + seed_base)
	var out: Array = []
	var volley: bool = int(k * interval / volley_every) != int((k - 1) * interval / volley_every)
	var n: int = 8 if volley else (1 if rng.randf() < 0.75 else 2)
	for i in range(n):
		var p := Vector3(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y),
				rng.randf_range(area.position.z, area.end.z))
		out.append([p, rng.randi() % COLOURS.size(), rng.randi() % 3, rng.randf() * (0.6 if volley else 0.0)])
	return out


func _process(_delta: float) -> void:
	var t: float = _now()
	var slot: int = int(floor(t / interval))
	if _last_slot < 0:
		_last_slot = slot - 1
	while _last_slot < slot:
		_last_slot += 1
		var base: float = float(_last_slot) * interval
		for s in _slot(_last_slot):
			_pending.append([base + float(s[3]), "launch", s])
			_pending.append([base + float(s[3]) + RISE, "burst", s])
	var keep: Array = []
	for e in _pending:
		if t >= float(e[0]):
			if e[1] == "launch":
				_launch(e[2])
			else:
				_burst(e[2])
		else:
			keep.append(e)
	_pending = keep
	# The flashes fade.
	for i in range(_lights.size()):
		var age: float = t - float(_light_t[i])
		(_lights[i] as OmniLight3D).light_energy = maxf(0.0, 5.0 * (1.0 - age / 0.9)) if age < 0.9 else 0.0


func _launch(s: Array) -> void:
	var i: int = _next % POOL
	var sh: GPUParticles3D = _shells[i]
	var top: Vector3 = s[0]
	sh.position = Vector3(top.x, 0.5, top.z)
	var pm: ParticleProcessMaterial = sh.process_material
	pm.initial_velocity_min = top.y / RISE
	pm.initial_velocity_max = top.y / RISE
	sh.restart()
	sh.emitting = true


func _burst(s: Array) -> void:
	var i: int = _next % POOL
	_next += 1
	var b: GPUParticles3D = _bursts[i]
	var col: Color = COLOURS[int(s[1])]
	var kind: int = s[2]
	b.position = s[0]
	var pm: ParticleProcessMaterial = b.process_material
	pm.color = col
	match kind:
		0:   # peony: a full sphere of stars
			pm.direction = Vector3.UP
			pm.spread = 180.0
			pm.initial_velocity_min = 26.0
			pm.initial_velocity_max = 32.0
			pm.gravity = Vector3(0, -5.0, 0)
			pm.damping_min = 9.0
			pm.damping_max = 11.0
			b.lifetime = 2.2
		1:   # ring: a flat circle, tilted
			pm.direction = Vector3(0, 0, 1)
			pm.spread = 180.0
			pm.flatness = 1.0
			pm.initial_velocity_min = 30.0
			pm.initial_velocity_max = 30.0
			pm.gravity = Vector3(0, -4.0, 0)
			pm.damping_min = 10.0
			pm.damping_max = 10.0
			b.lifetime = 2.0
		2:   # willow: slow, gold, drooping a long way
			pm.direction = Vector3.UP
			pm.spread = 180.0
			pm.flatness = 0.0
			pm.initial_velocity_min = 18.0
			pm.initial_velocity_max = 24.0
			pm.gravity = Vector3(0, -9.0, 0)
			pm.damping_min = 4.0
			pm.damping_max = 5.0
			pm.color = Color(1.0, 0.78, 0.35)
			b.lifetime = 3.6
	if kind != 1:
		pm.flatness = 0.0
	b.rotation = Vector3(randf() * PI, randf() * TAU, 0.0) if kind == 1 else Vector3.ZERO
	b.restart()
	b.emitting = true
	var l: OmniLight3D = _lights[i]
	l.position = b.position
	l.light_color = col
	_light_t[i] = _now()
	# The boom, after the time sound takes to come from there (it's 3D, so it falls off with distance too).
	var cam := get_viewport().get_camera_3d()
	var delay: float = 0.0
	if cam:
		delay = cam.global_position.distance_to(global_transform * b.position) / 343.0
	var p: AudioStreamPlayer3D = _players[i]
	p.position = b.position
	p.pitch_scale = randf_range(0.8, 1.15)
	if delay < 0.05:
		p.play()
	else:
		get_tree().create_timer(delay).timeout.connect(p.play)


func _star_material(size: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _dot()
	m.disable_fog = true
	# Over 1, so the glow blooms them.
	m.albedo_color = Color(3.0, 3.0, 3.0)
	q.material = m
	return q


var _dot_tex: Texture2D

func _dot() -> Texture2D:
	if _dot_tex:
		return _dot_tex
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.add_point(0.35, Color(1, 1, 1, 0.6))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 32
	t.height = 32
	_dot_tex = t
	return t


func _fade_ramp() -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.add_point(0.6, Color(1, 1, 1, 0.8))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


func _make_burst() -> GPUParticles3D:
	var b := GPUParticles3D.new()
	b.amount = 220
	b.one_shot = true
	b.explosiveness = 1.0
	b.lifetime = 2.2
	b.emitting = false
	b.visibility_aabb = AABB(Vector3(-90, -110, -90), Vector3(180, 200, 180))
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	pm.color_ramp = _fade_ramp()
	pm.scale_min = 0.8
	pm.scale_max = 1.3
	# Stars twinkle out at the end (the ramp), and leave a short trail of sparks (the trail draw pass is a cost; the
	# second pass of small dots that lag is cheaper).
	b.process_material = pm
	b.draw_pass_1 = _star_material(1.6)
	add_child(b)
	return b


func _make_shell() -> GPUParticles3D:
	var s := GPUParticles3D.new()
	s.amount = 40
	s.one_shot = true
	s.explosiveness = 0.0
	s.lifetime = RISE
	s.emitting = false
	s.local_coords = true
	s.visibility_aabb = AABB(Vector3(-20, -5, -20), Vector3(40, 200, 40))
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 1.5
	pm.gravity = Vector3.ZERO
	pm.color = Color(1.0, 0.8, 0.5)
	pm.color_ramp = _fade_ramp()
	pm.scale_min = 0.4
	pm.scale_max = 0.6
	s.process_material = pm
	s.draw_pass_1 = _star_material(0.9)
	add_child(s)
	return s


## A firework's boom: a thump with a rumbling tail and a crackle, 2.5s.
static func _make_boom() -> AudioStreamWAV:
	const RATE := 22050
	var n: int = int(RATE * 2.5)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var low := 0.0
	var low2 := 0.0
	for i in range(n):
		var t: float = float(i) / RATE
		var w: float = rng.randf_range(-1.0, 1.0)
		low += (w - low) * 0.06
		low2 += (low - low2) * 0.08
		var env: float = exp(-t * 3.2) * minf(1.0, t * 400.0)
		var thump: float = sin(TAU * 48.0 * t * exp(-t * 2.0)) * exp(-t * 9.0)
		var crackle: float = (w if rng.randf() < 0.02 else 0.0) * smoothstep(0.3, 0.6, t) * exp(-(t - 0.6) * 2.5) * 0.6
		var v: float = clampf(low2 * 7.0 * env + thump * 0.8 + crackle, -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = data
	return s
