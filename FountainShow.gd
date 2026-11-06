extends Node3D
## The roundabout fountain's show (Marina Nights): the basin's water, a tall central jet, a ring of jets arching in
## toward the middle, water falling from the bowls' lips, all lit in colours that change, the jets rising and falling
## in a sequence. The node stands at the island's middle on the ground; the stone (ArabianKit.fountain) is the
## generator's mesh beside it. Everything here is built at _ready (a level stores only the node and its exports).
## The show runs on the wall clock, so LAN peers see the same; nothing is synced. Nothing here is solid.
## Headless (a server), only the water is built.

@export var basin_radius := 15.6        # the water's radius (metres)
@export var water_y := 0.95             # its height over the node
@export var ring_jets := 20
@export var ring_radius := 13.5
@export var centre_height := 26.0       # the central jet's height (metres)
@export var base_y := 0.0               # the bowls' heights (and the jets') stand this much higher (the basin's floor)

const PALETTE := [Color(1.0, 0.75, 0.35), Color(0.25, 0.85, 1.0), Color(1.0, 0.35, 0.75), Color(0.45, 0.55, 1.0),
	Color(1.0, 1.0, 1.0), Color(0.35, 1.0, 0.65)]
const STEP := 7.0                        # seconds a colour holds

var _water_mat: ShaderMaterial
var _drop_mat: StandardMaterial3D
var _centre: GPUParticles3D
var _ring: Array = []                    # GPUParticles3D
var _lights: Array = []                  # OmniLight3D
var _falls: Array = []
var _last_phase := -1


func _ready() -> void:
	_build_water()
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_drop_mat = StandardMaterial3D.new()
	_drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_drop_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_drop_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_drop_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_drop_mat.vertex_color_use_as_albedo = true
	_drop_mat.albedo_texture = _dot()
	_drop_mat.disable_fog = true
	_centre = _jet(Vector3(0, 11.5 + base_y, 0), Vector3.UP, 600, 1.6)
	for i in range(ring_jets):
		var a: float = TAU * i / ring_jets
		var p := Vector3(cos(a), 0, sin(a)) * ring_radius + Vector3(0, water_y, 0)
		# Arching in toward the middle.
		var dir := (-Vector3(cos(a), 0, sin(a)) * 0.45 + Vector3.UP).normalized()
		_ring.append(_jet(p, dir, 70, 1.4))
	# Sheets falling from the three bowls' lips (a ring emitter each).
	for t in [[2.2, 6.0], [5.8, 3.8], [9.4, 2.2]]:
		var f := _jet(Vector3(0, float(t[0]) + base_y, 0), Vector3.DOWN, 260, 0.9)
		var pm: ParticleProcessMaterial = f.process_material
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pm.emission_ring_axis = Vector3.UP
		pm.emission_ring_radius = float(t[1]) + 0.1
		pm.emission_ring_inner_radius = float(t[1])
		pm.emission_ring_height = 0.05
		pm.initial_velocity_min = 0.3
		pm.initial_velocity_max = 0.8
		pm.spread = 8.0
		_falls.append(f)
	for i in range(4):
		var l := OmniLight3D.new()
		var a: float = TAU * (float(i) + 0.5) / 4.0
		l.position = Vector3(cos(a), 0, sin(a)) * ring_radius * 0.6 + Vector3(0, 6.0, 0)
		l.omni_range = 34.0
		l.omni_attenuation = 1.2
		l.light_energy = 2.4
		l.shadow_enabled = false
		l.set_meta(&"no_shadow", true)
		l.distance_fade_enabled = true
		l.distance_fade_begin = 220.0
		l.distance_fade_length = 50.0
		add_child(l)
		_lights.append(l)


func _build_water() -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = basin_radius
	disc.bottom_radius = basin_radius
	disc.height = 0.02
	disc.radial_segments = 48
	var mi := MeshInstance3D.new()
	mi.mesh = disc
	mi.position = Vector3(0, water_y, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = load("res://fountain_water.gdshader")
	_water_mat.set_shader_parameter("mode", 0)
	_water_mat.set_shader_parameter("fall_r", 6.0)
	mi.material_override = _water_mat
	add_child(mi)


var _dot_tex: Texture2D

func _dot() -> Texture2D:
	if _dot_tex:
		return _dot_tex
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.9))
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


func _jet(at: Vector3, dir: Vector3, amount: int, life: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.position = at
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.local_coords = true
	p.visibility_aabb = AABB(Vector3(-20, -14, -20), Vector3(40, 50, 40))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.direction = dir
	pm.spread = 3.0
	pm.gravity = Vector3(0, -12.0, 0)
	pm.initial_velocity_min = 12.0
	pm.initial_velocity_max = 13.0
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.9))
	g.add_point(0.7, Color(1, 1, 1, 0.6))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.45, 0.45)
	q.material = _drop_mat
	p.draw_pass_1 = q
	add_child(p)
	return p


func _process(_delta: float) -> void:
	var t: float = Time.get_unix_time_from_system()
	var k: int = int(floor(t / STEP))
	var f: float = fposmod(t, STEP) / STEP
	var c0: Color = PALETTE[k % PALETTE.size()]
	var c1: Color = PALETTE[(k + 1) % PALETTE.size()]
	var col: Color = c0.lerp(c1, smoothstep(0.8, 1.0, f))
	# Brighter than 1 so the glow blooms it.
	_drop_mat.albedo_color = Color(col.r * 2.2, col.g * 2.2, col.b * 2.2, 1.0)
	_water_mat.set_shader_parameter("shallow", col.lerp(Color(0.3, 0.6, 0.65), 0.35))
	for l in _lights:
		(l as OmniLight3D).light_color = col
	# The sequence, repeating every four colours: all up; a chase round the ring; the ring low and the centre tall;
	# the ring pulsing together.
	var phase: int = k % 4
	var h_centre: float = centre_height
	for i in range(_ring.size()):
		var pm: ParticleProcessMaterial = (_ring[i] as GPUParticles3D).process_material
		var v := 11.0
		match phase:
			1:
				v = 6.0 + 7.0 * maxf(0.0, sin(TAU * (f * 3.0 - float(i) / _ring.size())))
			2:
				v = 5.0
			3:
				v = 7.0 + 5.0 * maxf(0.0, sin(TAU * f * 4.0))
		pm.initial_velocity_min = v
		pm.initial_velocity_max = v + 0.6
	if phase == 2:
		h_centre *= 1.25
	elif phase == 1:
		h_centre *= 0.6
	var cv: float = sqrt(2.0 * 12.0 * h_centre)
	var cpm: ParticleProcessMaterial = _centre.process_material
	cpm.initial_velocity_min = cv
	cpm.initial_velocity_max = cv + 1.0
	# Setting the lifetime restarts the jet: only when the phase changes (the drops vanish as they fall back to it).
	if phase != _last_phase:
		_last_phase = phase
		_centre.lifetime = cv / 12.0 * 2.0
