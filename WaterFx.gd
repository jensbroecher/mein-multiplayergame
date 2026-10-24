extends Node3D
## Deep-water effects for PlayerCart, built in code:
##   - spawn_splash(): what a cart throws up when it falls into deep water from a height (off the
##     long bridge): a column of water, a crown of spray thrown out round it, mist that hangs and a
##     ring of white foam (water_foam.gdshader) that spreads over the surface and breaks up.
##   - spawn_bubbles(): air rising from a cart sinking with its engine flooded, a column of bubbles
##     under water (water_bubble.gdshader, cut off at the surface) and fizz popping on top, which is
##     what the chase camera sees from the air. The node follows the cart until stop().
## The draw materials are shared, and FxWarmup holds stand-ins (warmup_nodes) so their shaders are
## compiled before the first cart goes in.

const DROP_TEX := preload("res://materials/water_particle.png")
const SPRAY_TEX := preload("res://materials/water_particle_2.png")
const MIST_TEX := preload("res://materials/water_particle_3.png")

static var _mats := {}

var target: Node3D
var surface_y := 0.0
var _column: GPUParticles3D
var _fizz: GPUParticles3D
var _stopped := false


## A splash for a fall into deep water at `pos` (on the surface). `strength` 1 is a fall at about
## 12 m/s; it grows with the fall to 2.
static func spawn_splash(root: Node, pos: Vector3, strength: float) -> void:
	var s := clampf(strength, 0.6, 2.0)
	var fx := Node3D.new()
	fx.name = "BigSplash"
	root.add_child(fx)
	fx.global_position = pos
	# The column: thrown straight up, falling back.
	fx.add_child(_burst(int(70 * s), 1.6, Vector2(6.0, 11.0) * sqrt(s), 12.0, 0.8 * s, Vector2(0.7, 1.5) * s, -16.0, 0.0, "drop"))
	# The crown: spray out to the sides.
	fx.add_child(_burst(int(110 * s), 1.3, Vector2(4.0, 8.5) * sqrt(s), 58.0, 1.5 * s, Vector2(0.45, 1.0) * s, -14.0, 0.4, "spray"))
	# Mist hanging over it.
	fx.add_child(_burst(int(20 * s), 2.8, Vector2(0.8, 2.6), 80.0, 1.6 * s, Vector2(2.6, 4.8) * s, -0.4, 1.6, "mist"))
	# Foam on the water, spreading and breaking up.
	var foam := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	foam.mesh = plane
	foam.material_override = _material("foam")
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	foam.position = Vector3(0.0, 0.05, 0.0)
	foam.scale = Vector3.ONE * 2.2 * s
	foam.set_instance_shader_parameter(&"seed", randf() * 10.0)
	fx.add_child(foam)
	var tw := fx.create_tween()
	tw.set_parallel(true)
	tw.tween_method(func(a: float): foam.set_instance_shader_parameter(&"age", a), 0.0, 1.0, 6.0)
	tw.tween_property(foam, "scale", Vector3.ONE * 7.5 * s, 6.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	fx.get_tree().create_timer(6.3).timeout.connect(fx.queue_free)


## Bubbles from `cart`, sinking under water whose surface is at `surface`.
static func spawn_bubbles(root: Node, cart: Node3D, surface: float) -> Node3D:
	var fx: Node3D = load("res://WaterFx.gd").new()
	fx.name = "SinkingBubbles"
	fx.target = cart
	fx.surface_y = surface
	root.add_child(fx)
	return fx


func _ready() -> void:
	if target == null:
		return
	_column = _stream(60, 2.2, "bubble")
	var pm := _column.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.7
	pm.spread = 25.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 2.4
	pm.gravity = Vector3(0.0, 2.2, 0.0)
	pm.scale_min = 0.18
	pm.scale_max = 0.5
	_column.set_instance_shader_parameter(&"surface_y", surface_y)
	add_child(_column)
	_fizz = _stream(40, 1.1, "fizz")
	var fm := _fizz.process_material as ParticleProcessMaterial
	fm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	fm.emission_box_extents = Vector3(0.9, 0.0, 0.9)
	fm.spread = 180.0
	fm.flatness = 1.0
	fm.initial_velocity_min = 0.1
	fm.initial_velocity_max = 0.5
	fm.gravity = Vector3.ZERO
	fm.scale_min = 0.5
	fm.scale_max = 1.3
	fm.scale_curve = _curve_texture([Vector2(0.0, 0.3), Vector2(1.0, 1.0)])
	add_child(_fizz)
	_follow()


func _process(_delta: float) -> void:
	if not _stopped:
		if not is_instance_valid(target) or not target.is_inside_tree():
			stop()
		else:
			_follow()


func _follow() -> void:
	var p := target.global_position
	_column.global_position = p + Vector3(0.0, 0.2, 0.0)
	# Over the water's ripples, or they hide it.
	_fizz.global_position = Vector3(p.x, surface_y + 0.12, p.z)


## Stops emitting; the node frees itself once the last bubbles have risen.
func stop() -> void:
	if _stopped:
		return
	_stopped = true
	if _column:
		_column.emitting = false
	if _fizz:
		_fizz.emitting = false
	get_tree().create_timer(2.5).timeout.connect(queue_free)


## Hidden stand-ins for FxWarmup: every draw material and a particle system of each kind.
static func warmup_nodes() -> Array[Node]:
	var out: Array[Node] = []
	for key in ["drop", "spray", "mist"]:
		var b := _burst(1, 1.0, Vector2.ONE, 10.0, 1.0, Vector2.ONE, -9.8, 0.0, key)
		b.emitting = false
		out.append(b)
	for key in ["bubble", "fizz"]:
		var st := _stream(1, 1.0, key)
		st.emitting = false
		out.append(st)
	var foam := MeshInstance3D.new()
	foam.mesh = PlaneMesh.new()
	foam.material_override = _material("foam")
	out.append(foam)
	return out


## A one-shot burst: `amount` particles living `life` s, thrown up at `vel` m/s within `spread`
## degrees from a ring of `radius`, `size` metres, under `gravity`, slowed by `damp`.
static func _burst(amount: int, life: float, vel: Vector2, spread: float, radius: float, size: Vector2, gravity: float,
		damp: float, key: String) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = maxi(amount, 1)
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.9
	p.randomness = 0.4
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-14, -3, -14), Vector3(28, 34, 28))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = radius
	pm.emission_ring_inner_radius = radius * 0.3
	pm.emission_ring_height = 0.2
	pm.direction = Vector3.UP
	pm.spread = spread
	pm.initial_velocity_min = vel.x
	pm.initial_velocity_max = vel.y
	pm.gravity = Vector3(0.0, gravity, 0.0)
	pm.damping_min = damp
	pm.damping_max = damp * 1.5
	pm.scale_min = size.x
	pm.scale_max = size.y
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.scale_curve = _curve_texture([Vector2(0.0, 0.5), Vector2(0.25, 1.0), Vector2(1.0, 0.6 if key == "mist" else 0.2)])
	pm.color_ramp = _fade_ramp(0.95 if key != "mist" else 0.6)
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = _material(key)
	p.draw_pass_1 = quad
	return p


## A steady stream for the bubbles: billboards (bubble) or flat discs on the water (fizz).
static func _stream(amount: int, life: float, key: String) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.randomness = 0.5
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-4, -6, -4), Vector3(8, 14, 8))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.color_ramp = _fade_ramp(0.9)
	p.process_material = pm
	if key == "fizz":
		var disc := PlaneMesh.new()
		disc.size = Vector2.ONE
		disc.material = _material(key)
		p.draw_pass_1 = disc
	else:
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		quad.material = _material(key)
		p.draw_pass_1 = quad
	return p


static func _material(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m: Material
	match key:
		"bubble":
			var sm := ShaderMaterial.new()
			sm.shader = load("res://water_bubble.gdshader")
			m = sm
		"foam":
			var fm := ShaderMaterial.new()
			fm.shader = load("res://water_foam.gdshader")
			fm.render_priority = 1
			m = fm
		_:
			var std := StandardMaterial3D.new()
			std.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			std.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			std.vertex_color_use_as_albedo = true
			std.cull_mode = BaseMaterial3D.CULL_DISABLED
			match key:
				"drop":
					std.albedo_texture = DROP_TEX
					std.albedo_color = Color(0.9, 0.96, 1.0, 0.95)
				"spray":
					std.albedo_texture = SPRAY_TEX
					std.albedo_color = Color(0.96, 0.98, 1.0, 0.9)
				"mist":
					std.albedo_texture = MIST_TEX
					std.albedo_color = Color(0.95, 0.97, 1.0, 0.55)
				"fizz":
					std.albedo_texture = _ring_texture()
					std.albedo_color = Color(0.95, 0.98, 1.0, 0.9)
			if key != "fizz":
				std.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
				std.billboard_keep_scale = true
			m = std
	_mats[key] = m
	return m


## A white ring with a broken edge, for the bubbles popping on the surface.
static func _ring_texture() -> Texture2D:
	const N := 64
	var img := Image.create(N, N, true, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 77
	noise.frequency = 0.15
	for y in range(N):
		for x in range(N):
			var p := Vector2(x + 0.5, y + 0.5) / N * 2.0 - Vector2.ONE
			var r := p.length()
			var ring := 1.0 - smoothstep(0.0, 0.16, absf(r - 0.7))
			var dots := smoothstep(0.35, 0.6, noise.get_noise_2d(x, y)) * (1.0 - smoothstep(0.5, 0.95, r))
			var a := clampf(maxf(ring * (0.6 + 0.4 * noise.get_noise_2d(x * 2.0, y * 2.0)), dots * 0.6), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _fade_ramp(alpha: float) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, alpha), Color(1, 1, 1, alpha), Color(1, 1, 1, alpha * 0.6), Color(1, 1, 1, 0.0)])
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


static func _curve_texture(points: Array) -> CurveTexture:
	var c := Curve.new()
	for pt in points:
		c.add_point(pt)
	var t := CurveTexture.new()
	t.curve = c
	return t
