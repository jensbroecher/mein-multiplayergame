extends Node3D
## The arena football's effects (a child ArenaGame.gd adds on every peer, driven by its `_ball_fx_rpc`): a goal
## (confetti out of the goal's mouth in the scorer's colour, a ring of light along its line), the ball bursting in
## the net a moment later (a shell of light, sparks, a flash), the ball coming in at a kick-off (a column of light
## down onto the pitch, a ring running out under it, sparkles round the ball), and the poof where a stranded ball is
## taken away.
##
## Everything is made once in `_ready` and reused: the light shapes are plain meshes in arena_fx.gdshader grown and
## faded through instance uniforms (`_pulse`), the sparks and confetti one-shot GPU particles, the flash one light.
## Made up front, their shaders compile under the loading screen, not at the first goal (CLAUDE.md, first-use
## freezes). Nothing here flashes the whole screen: the light stays where the ball is.

const SHADER := preload("res://arena_fx.gdshader")
const SOUND_BURST := "res://sounds/arena/goal_burst.wav"
const SOUND_HORN := "res://sounds/arena/goal_horn.wav"
const SOUND_SPAWN := "res://sounds/arena/ball_spawn.wav"
const SOUND_RESET := "res://sounds/arena/ball_reset.wav"
## Each clip's gain: its loudest second (scratch/measure_clip_rms.gd) brought to about -17 dBFS for the burst, -20
## for the horn (the stands' cheer plays over it) and the kick-off, -22 for the poof.
const DB_BURST := -1.0
const DB_HORN := -7.0
const DB_SPAWN := 5.0
const DB_RESET := 2.0
const BALL_R := 0.95
const BEAM_H := 30.0

var _mats: Array = []
var _meshes: Array = []
## Running pulses: [node, age, life, scale from, scale to, strength, hold (the share of its life at full strength)].
var _pulses: Array = []
var _free: Array = [[], [], []]
var _sparks: Array = []
var _confetti: Array = []
var _next_spark := 0
var _next_confetti := 0
var _light: OmniLight3D
var _light_t := 0.0
var _light_life := 1.0
var _light_energy := 0.0


func _ready() -> void:
	# Placed afresh each time: interpolated, a reused shape would sweep in from where it last was.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	var beam := CylinderMesh.new()
	beam.top_radius = 1.0
	beam.bottom_radius = 1.0
	beam.height = 1.0
	beam.radial_segments = 28
	beam.rings = 1
	beam.cap_top = false
	beam.cap_bottom = false
	var ring := PlaneMesh.new()
	ring.size = Vector2(2.0, 2.0)
	_meshes = [sphere, beam, ring]
	for mode in 3:
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("mode", mode)
		m.render_priority = 4
		_mats.append(m)
		# A stand-in of each, drawn nowhere, so its pipeline exists before the first goal.
		for k in 3:
			_free[mode].append(_new_shape(mode))
	for k in 3:
		_sparks.append(_make_sparks())
	for k in 2:
		_confetti.append(_make_confetti())
	_light = OmniLight3D.new()
	_light.omni_range = 34.0
	_light.omni_attenuation = 1.4
	_light.shadow_enabled = false
	_light.light_energy = 0.0
	_light.visible = false
	_light.set_meta(&"no_shadow", true)
	add_child(_light)


func _new_shape(mode: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes[mode]
	mi.material_override = _mats[mode]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	mi.set_meta(&"mode", mode)
	add_child(mi)
	mi.top_level = true
	return mi


func _soft_dot() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 32
	t.height = 32
	return t


func _shrink_curve() -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 1.0))
	c.add_point(Vector2(0.55, 0.8))
	c.add_point(Vector2(1.0, 0.0))
	var t := CurveTexture.new()
	t.curve = c
	return t


func _make_sparks() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 110
	p.lifetime = 1.15
	p.one_shot = true
	p.explosiveness = 0.96
	p.emitting = false
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-40, -20, -40), Vector3(80, 60, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = BALL_R
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 6.0
	pm.initial_velocity_max = 24.0
	pm.gravity = Vector3(0, -15.0, 0)
	pm.damping_min = 1.5
	pm.damping_max = 5.0
	pm.scale_min = 0.5
	pm.scale_max = 1.4
	pm.scale_curve = _shrink_curve()
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.34, 0.34)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(2.2, 2.2, 2.2)
	m.albedo_texture = _soft_dot()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.disable_fog = true
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	p.top_level = true
	return p


func _make_confetti() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 150
	p.lifetime = 2.6
	p.one_shot = true
	p.explosiveness = 0.9
	p.emitting = false
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-40, -10, -50), Vector3(80, 50, 70))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(6.0, 1.6, 0.4)
	pm.direction = Vector3(0, 0.75, -1.0)
	pm.spread = 30.0
	pm.initial_velocity_min = 8.0
	pm.initial_velocity_max = 19.0
	pm.gravity = Vector3(0, -7.5, 0)
	pm.damping_min = 1.2
	pm.damping_max = 2.6
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -420.0
	pm.angular_velocity_max = 420.0
	pm.scale_min = 0.7
	pm.scale_max = 1.3
	pm.scale_curve = _shrink_curve()
	pm.color_initial_ramp = GradientTexture1D.new()
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.24, 0.4)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	p.top_level = true
	return p


## A light shape of `mode` at `xf`, growing from `s0` to `s1` over `life` and fading out after `hold` of it.
func _pulse(mode: int, xf: Transform3D, col: Color, life: float, s0: Vector3, s1: Vector3, strength := 1.0, hold := 0.0) -> void:
	var mi: MeshInstance3D = (_free[mode] as Array).pop_back() if not (_free[mode] as Array).is_empty() else _new_shape(mode)
	mi.global_transform = Transform3D(xf.basis.orthonormalized().scaled(s0), xf.origin)
	mi.set_instance_shader_parameter(&"tint", col)
	mi.set_instance_shader_parameter(&"fade", strength)
	mi.set_instance_shader_parameter(&"phase", 0.0)
	mi.visible = true
	_pulses.append([mi, 0.0, life, s0, s1, strength, hold, xf])


func _flash(at: Vector3, col: Color, energy: float, life: float) -> void:
	_light.global_position = at
	_light.light_color = col.lerp(Color(1, 1, 1), 0.35)
	_light_energy = energy
	_light_life = life
	_light_t = life
	_light.light_energy = energy
	_light.visible = true


func _fire_sparks(at: Vector3, col: Color, speed := 1.0, amount_share := 1.0) -> void:
	var p: GPUParticles3D = _sparks[_next_spark % _sparks.size()]
	_next_spark += 1
	p.global_position = at
	var pm := p.process_material as ParticleProcessMaterial
	pm.color = col.lerp(Color(1, 1, 1), 0.25)
	pm.initial_velocity_min = 6.0 * speed
	pm.initial_velocity_max = 24.0 * speed
	p.amount_ratio = clampf(amount_share, 0.1, 1.0)
	p.restart()
	p.emitting = true


func _process(delta: float) -> void:
	var i := _pulses.size() - 1
	while i >= 0:
		var pu: Array = _pulses[i]
		pu[1] = float(pu[1]) + delta
		var k := clampf(float(pu[1]) / float(pu[2]), 0.0, 1.0)
		var mi: MeshInstance3D = pu[0]
		if k >= 1.0:
			mi.visible = false
			(_free[int(mi.get_meta(&"mode"))] as Array).append(mi)
			_pulses.remove_at(i)
		else:
			var e := 1.0 - pow(1.0 - k, 3.0)
			var xf: Transform3D = pu[7]
			mi.global_transform = Transform3D(xf.basis.orthonormalized().scaled((pu[3] as Vector3).lerp(pu[4], e)), xf.origin)
			var hold: float = pu[6]
			var out := clampf((k - hold) / maxf(1.0 - hold, 0.001), 0.0, 1.0)
			mi.set_instance_shader_parameter(&"fade", float(pu[5]) * pow(1.0 - out, 1.6))
			mi.set_instance_shader_parameter(&"phase", k)
		i -= 1
	if _light_t > 0.0:
		_light_t = maxf(0.0, _light_t - delta)
		var lk := _light_t / _light_life
		_light.light_energy = _light_energy * lk * lk
		if _light_t <= 0.0:
			_light.visible = false


# ---- What ArenaGame asks for ---------------------------------------------------------------------------------------

## A goal: confetti out of the goal's mouth toward the pitch, a ring of light off its line, the horn.
func goal(goal_node: Node3D, half: float, height: float, col: Color) -> void:
	var p: GPUParticles3D = _confetti[_next_confetti % _confetti.size()]
	_next_confetti += 1
	var gt := goal_node.global_transform
	p.global_transform = Transform3D(gt.basis.orthonormalized(), gt * Vector3(0, height * 0.45, -0.6))
	var pm := p.process_material as ParticleProcessMaterial
	pm.emission_box_extents = Vector3(half * 0.9, height * 0.3, 0.4)
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	# Mostly the scorer's colour, kept under white (the bowl's bloom washed brighter paper out), some gold and white.
	var deep := Color(col.r * 0.78, col.g * 0.78, col.b * 0.78)
	g.set_color(0, deep)
	g.set_color(1, Color(0.95, 0.74, 0.16))
	g.add_point(0.45, deep.lightened(0.18))
	g.add_point(0.7, Color(0.86, 0.86, 0.86))
	g.add_point(0.84, Color(0.95, 0.74, 0.16))
	(pm.color_initial_ramp as GradientTexture1D).gradient = g
	p.restart()
	p.emitting = true
	var line := Transform3D(gt.basis.orthonormalized(), gt * Vector3(0, 0.08, -1.0))
	_pulse(2, line, Color(col.r, col.g, col.b, 2.2), 1.1, Vector3(half * 0.4, 1, half * 0.4), Vector3(half * 2.6, 1, half * 2.6))
	MusicManager.play_sfx(SOUND_HORN, DB_HORN)


## The ball bursting where it is, in `col`: two shells of light, sparks, a flash.
func burst(at: Vector3, col: Color) -> void:
	var xf := Transform3D(Basis(), at)
	_pulse(0, xf, Color(1, 1, 1, 2.6), 0.32, Vector3.ONE * BALL_R, Vector3.ONE * 3.4)
	_pulse(0, xf, Color(col.r, col.g, col.b, 2.4), 0.75, Vector3.ONE * BALL_R * 1.1, Vector3.ONE * 9.0)
	_fire_sparks(at, col)
	_flash(at + Vector3(0, 1.0, 0), col, 5.0, 0.6)
	MusicManager.play_sfx(SOUND_BURST, DB_BURST)


## The ball coming in at `at` over the pitch at `floor_y`: a column of light down to the pitch, a ring running out
## under it, a shell closing in on the ball and a few sparkles.
func spawn(at: Vector3, floor_y: float, col: Color) -> void:
	var foot := Vector3(at.x, floor_y + 0.06, at.z)
	var mid := Transform3D(Basis(), Vector3(at.x, floor_y + BEAM_H * 0.5, at.z))
	_pulse(1, mid, Color(col.r, col.g, col.b, 1.5), 1.25, Vector3(1.5, BEAM_H, 1.5), Vector3(0.5, BEAM_H, 0.5), 1.0, 0.3)
	_pulse(2, Transform3D(Basis(), foot), Color(col.r, col.g, col.b, 1.8), 1.2, Vector3.ONE * 1.5, Vector3(9.0, 1, 9.0))
	_pulse(0, Transform3D(Basis(), at), Color(1, 1, 1, 2.0), 0.5, Vector3.ONE * 4.2, Vector3.ONE * BALL_R * 1.05)
	_fire_sparks(at, col, 0.45, 0.4)
	_flash(at, col, 2.6, 0.5)
	MusicManager.play_sfx(SOUND_SPAWN, DB_SPAWN)


## A stranded ball taken away: a small pale puff where it lay.
func poof(at: Vector3) -> void:
	_pulse(0, Transform3D(Basis(), at), Color(0.85, 0.95, 1.0, 1.6), 0.45, Vector3.ONE * BALL_R, Vector3.ONE * 2.6)
	_fire_sparks(at, Color(0.8, 0.95, 1.0), 0.4, 0.3)
	MusicManager.play_sfx(SOUND_RESET, DB_RESET)
