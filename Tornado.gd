extends Node3D
## Wandering desert tornado / twister:
## Spins with dynamic vortex shader (warm terracotta/sand gradient, serpentine sway,
## spiral wind bands), churns desert dust at touchdown, creates aerodynamic suction
## on approaching cars, whirls captured cars upward, and spits them out with dramatic SFX.

const VORTEX_SHADER: Shader = preload("res://tornado_vortex.gdshader")

@export_group("Visuals")
@export var mesh_path: NodePath = NodePath("Mesh")
@export var spin_speed_deg: float = 220.0
@export var mesh_alpha: float = 0.92
@export var base_dust_color: Color = Color(0.62, 0.35, 0.20, 0.98)
@export var mid_dust_color: Color = Color(0.76, 0.48, 0.29, 0.94)
@export var top_dust_color: Color = Color(0.72, 0.54, 0.39, 0.90)

@export_group("Wander")
@export var wander_radius: float = 55.0
@export var wander_speed: float = 6.0
@export var retarget_time_min: float = 2.5
@export var retarget_time_max: float = 5.5
@export var ground_ray_height: float = 80.0

@export_group("Suction")
## Outer aerodynamic influence radius where cars feel an inward and swirling pull.
@export var suction_radius: float = 38.0
## Inward pull force acceleration (scaled by distance factor and cart mass).
@export var suction_force: float = 30.0
## Ratio of tangential crosswind to inward suction (creates cyclonic swirl).
@export var suction_tangential_ratio: float = 0.55

@export_group("Pickup")
@export var pickup_radius: float = 18.0
@export var capture_duration: float = 2.4
@export var orbit_radius_start: float = 10.0
@export var orbit_radius_end: float = 3.5
@export var lift_height: float = 22.0
@export var spin_orbit_speed: float = 5.5
@export var spit_speed: float = 38.0
@export var spit_up_speed: float = 16.0
@export var cooldown_after_spit: float = 18.0

@export_group("Audio")
@export var wind_volume_db: float = 3.0
@export var wind_pitch_scale: float = 0.80
@export var eject_volume_db: float = 4.0

var _mesh: Node3D
var _home: Vector3
var _wander_target: Vector3
var _retarget_timer: float = 0.0
var _captured: Dictionary = {} # cart instance_id -> capture state
var _cooldown: Dictionary = {} # cart instance_id -> time left

# VFX and Audio child elements (rescaled to 1:1 world meters)
var _effects_root: Node3D
var _ground_dust: GPUParticles3D
var _vortex_wisps: GPUParticles3D
var _debris_particles: GPUParticles3D
var _ejection_burst: CPUParticles3D
var _audio_wind: AudioStreamPlayer3D
var _audio_eject: AudioStreamPlayer3D

static var _cached_dust_tex: Texture2D
static var _cached_grit_tex: Texture2D


func _ready() -> void:
	add_to_group("tornados")
	_home = global_position
	_wander_target = _home
	_mesh = get_node_or_null(mesh_path)
	if _mesh == null:
		# FBX root is often the only child
		for c in get_children():
			if c is Node3D and c != _effects_root:
				_mesh = c
				break
	_apply_transparency(_mesh if _mesh else self)
	_setup_effects()
	_pick_new_wander_target()
	set_physics_process(true)


func _setup_effects() -> void:
	# Effects root cancels parent scale so all particles, radiuses and speeds are in 1:1 world meters
	_effects_root = Node3D.new()
	_effects_root.name = "TornadoEffects"
	var sx := maxf(0.001, absf(scale.x))
	var sy := maxf(0.001, absf(scale.y))
	var sz := maxf(0.001, absf(scale.z))
	_effects_root.scale = Vector3(1.0 / sx, 1.0 / sy, 1.0 / sz)
	add_child(_effects_root)

	var dust_atlas := _create_soft_dust_texture()
	var grit_tex := _create_grit_chip_texture()

	# Shared puff expansion curve: starts compact at lift-off, billows wide as it rises
	var puff_curve := Curve.new()
	puff_curve.add_point(Vector2(0.0, 0.42))
	puff_curve.add_point(Vector2(0.35, 0.92))
	puff_curve.add_point(Vector2(1.0, 1.38))
	var puff_curve_tex := CurveTexture.new()
	puff_curve_tex.curve = puff_curve

	# Shared colour variation ramp so puffs vary between sunlit ochre and deeper canyon terracotta
	var init_shade := Gradient.new()
	init_shade.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	init_shade.colors = PackedColorArray([
		Color(0.76, 0.68, 0.62, 1.0),
		Color(0.94, 0.88, 0.82, 1.0),
		Color(1.0, 0.98, 0.94, 1.0)
	])
	var init_shade_tex := GradientTexture1D.new()
	init_shade_tex.gradient = init_shade

	# 1. Ground contact dust plume: wide, billowing clouds of canyon dust hugging the touchdown foot
	_ground_dust = GPUParticles3D.new()
	_ground_dust.name = "GroundDust"
	_ground_dust.position = Vector3(0, 1.0, 0)
	_ground_dust.amount = 135
	_ground_dust.lifetime = 2.2
	_ground_dust.preprocess = 2.0
	_ground_dust.local_coords = true
	_ground_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ground_dust.visibility_aabb = AABB(Vector3(-35, -8, -35), Vector3(70, 35, 70))

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3(0, 1, 0)
	pm.emission_ring_radius = 4.6
	pm.emission_ring_inner_radius = 0.6
	pm.emission_ring_height = 1.0
	pm.direction = Vector3(0, 0.75, 0)
	pm.spread = 38.0
	pm.initial_velocity_min = 2.2
	pm.initial_velocity_max = 5.2
	pm.gravity = Vector3(0, 1.0, 0)
	pm.tangential_accel_min = 12.0
	pm.tangential_accel_max = 20.0
	pm.radial_accel_min = -9.0
	pm.radial_accel_max = -2.5
	pm.damping_min = 3.2
	pm.damping_max = 5.5
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -38.0
	pm.angular_velocity_max = 38.0
	pm.scale_min = 6.5
	pm.scale_max = 13.5
	pm.scale_curve = puff_curve_tex
	pm.anim_offset_min = 0.0
	pm.anim_offset_max = 1.0
	pm.color_initial_ramp = init_shade_tex

	var alpha_grad := Gradient.new()
	alpha_grad.offsets = PackedFloat32Array([0.0, 0.18, 0.58, 1.0])
	alpha_grad.colors = PackedColorArray([
		Color(1, 1, 1, 0.0),
		Color(1, 1, 1, 0.92),
		Color(1, 1, 1, 0.62),
		Color(1, 1, 1, 0.0)
	])
	var alpha_tex := GradientTexture1D.new()
	alpha_tex.gradient = alpha_grad
	pm.color_ramp = alpha_tex
	_ground_dust.process_material = pm

	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var dmat := StandardMaterial3D.new()
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dmat.billboard_keep_scale = true
	dmat.particles_anim_h_frames = 2
	dmat.particles_anim_v_frames = 2
	dmat.particles_anim_loop = false
	dmat.vertex_color_use_as_albedo = true
	dmat.albedo_texture = dust_atlas
	dmat.albedo_color = Color(0.68, 0.42, 0.25, 0.44)
	dmat.proximity_fade_enabled = true
	dmat.proximity_fade_distance = 2.2
	quad.material = dmat
	_ground_dust.draw_pass_1 = quad
	_effects_root.add_child(_ground_dust)

	# 2. Rising vortex dust wisps: large, soft dust clouds spiraling up the lower-to-mid trunk
	_vortex_wisps = GPUParticles3D.new()
	_vortex_wisps.name = "VortexWisps"
	_vortex_wisps.position = Vector3(0, 1.4, 0)
	_vortex_wisps.amount = 95
	_vortex_wisps.lifetime = 2.3
	_vortex_wisps.preprocess = 2.0
	_vortex_wisps.local_coords = true
	_vortex_wisps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vortex_wisps.visibility_aabb = AABB(Vector3(-30, -4, -30), Vector3(60, 42, 60))

	var wpm := ParticleProcessMaterial.new()
	wpm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	wpm.emission_ring_axis = Vector3(0, 1, 0)
	wpm.emission_ring_radius = 3.8
	wpm.emission_ring_inner_radius = 1.0
	wpm.emission_ring_height = 2.0
	wpm.direction = Vector3(0, 1, 0)
	wpm.spread = 12.0
	wpm.initial_velocity_min = 6.5
	wpm.initial_velocity_max = 11.5
	wpm.gravity = Vector3(0, 1.2, 0)
	wpm.tangential_accel_min = 16.0
	wpm.tangential_accel_max = 26.0
	wpm.radial_accel_min = -13.0
	wpm.radial_accel_max = -5.5
	wpm.damping_min = 2.6
	wpm.damping_max = 4.2
	wpm.angle_min = -180.0
	wpm.angle_max = 180.0
	wpm.angular_velocity_min = -45.0
	wpm.angular_velocity_max = 45.0
	wpm.scale_min = 4.8
	wpm.scale_max = 9.5
	wpm.scale_curve = puff_curve_tex
	wpm.anim_offset_min = 0.0
	wpm.anim_offset_max = 1.0
	wpm.color_initial_ramp = init_shade_tex
	wpm.color_ramp = alpha_tex
	_vortex_wisps.process_material = wpm

	var w_quad := QuadMesh.new()
	w_quad.size = Vector2(1.0, 1.0)
	var wmat := dmat.duplicate() as StandardMaterial3D
	wmat.albedo_color = Color(0.72, 0.45, 0.27, 0.30)
	w_quad.material = wmat
	_vortex_wisps.draw_pass_1 = w_quad
	_effects_root.add_child(_vortex_wisps)

	# 3. Funnel debris particles: small, sharp canyon grit/clod fragments whipping in the wind
	_debris_particles = GPUParticles3D.new()
	_debris_particles.name = "FunnelDebris"
	_debris_particles.position = Vector3(0, 0.8, 0)
	_debris_particles.amount = 85
	_debris_particles.lifetime = 1.8
	_debris_particles.preprocess = 1.5
	_debris_particles.local_coords = true
	_debris_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_debris_particles.visibility_aabb = AABB(Vector3(-25, -2, -25), Vector3(50, 40, 50))

	var dpm := ParticleProcessMaterial.new()
	dpm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	dpm.emission_ring_axis = Vector3(0, 1, 0)
	dpm.emission_ring_radius = 4.4
	dpm.emission_ring_inner_radius = 1.2
	dpm.emission_ring_height = 1.5
	dpm.direction = Vector3(0, 1, 0)
	dpm.spread = 16.0
	dpm.initial_velocity_min = 8.0
	dpm.initial_velocity_max = 14.0
	dpm.gravity = Vector3(0, -1.5, 0)
	dpm.tangential_accel_min = 20.0
	dpm.tangential_accel_max = 32.0
	dpm.radial_accel_min = -15.0
	dpm.radial_accel_max = -6.0
	dpm.damping_min = 2.0
	dpm.damping_max = 3.5
	dpm.angle_min = -180.0
	dpm.angle_max = 180.0
	dpm.angular_velocity_min = -480.0
	dpm.angular_velocity_max = 480.0
	dpm.scale_min = 0.55
	dpm.scale_max = 1.45
	dpm.color_initial_ramp = init_shade_tex

	var d_alpha_grad := Gradient.new()
	d_alpha_grad.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0)])
	d_alpha_grad.offsets = PackedFloat32Array([0.0, 0.12, 0.78, 1.0])
	var d_alpha_tex := GradientTexture1D.new()
	d_alpha_tex.gradient = d_alpha_grad
	dpm.color_ramp = d_alpha_tex
	_debris_particles.process_material = dpm

	var d_quad := QuadMesh.new()
	d_quad.size = Vector2(0.16, 0.16)
	var deb_mat := StandardMaterial3D.new()
	deb_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	deb_mat.alpha_scissor_threshold = 0.45
	deb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	deb_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	deb_mat.billboard_keep_scale = true
	deb_mat.vertex_color_use_as_albedo = true
	deb_mat.albedo_texture = grit_tex
	deb_mat.albedo_color = Color(0.42, 0.25, 0.15, 1.0)
	d_quad.material = deb_mat
	_debris_particles.draw_pass_1 = d_quad
	_effects_root.add_child(_debris_particles)

	# 4. Ejection burst (one-shot dust puff on cart fling or boost escape)
	_ejection_burst = CPUParticles3D.new()
	_ejection_burst.name = "EjectionBurst"
	_ejection_burst.emitting = false
	_ejection_burst.one_shot = true
	_ejection_burst.explosiveness = 0.92
	_ejection_burst.amount = 32
	_ejection_burst.lifetime = 1.2
	_ejection_burst.spread = 180.0
	_ejection_burst.initial_velocity_min = 10.0
	_ejection_burst.initial_velocity_max = 22.0
	_ejection_burst.damping_min = 8.0
	_ejection_burst.damping_max = 16.0
	_ejection_burst.angle_min = -180.0
	_ejection_burst.angle_max = 180.0
	_ejection_burst.angular_velocity_min = -45.0
	_ejection_burst.angular_velocity_max = 45.0
	_ejection_burst.scale_amount_min = 3.5
	_ejection_burst.scale_amount_max = 7.0
	_ejection_burst.scale_amount_curve = puff_curve
	_ejection_burst.anim_offset_min = 0.0
	_ejection_burst.anim_offset_max = 1.0
	_ejection_burst.color_ramp = alpha_grad
	var b_quad := QuadMesh.new()
	b_quad.size = Vector2(1.0, 1.0)
	var b_mat := dmat.duplicate() as StandardMaterial3D
	b_mat.albedo_color = Color(0.74, 0.46, 0.28, 0.42)
	b_quad.material = b_mat
	_ejection_burst.mesh = b_quad
	_effects_root.add_child(_ejection_burst)

	# 5. Continuous 3D roaring wind audio
	_audio_wind = AudioStreamPlayer3D.new()
	_audio_wind.name = "AudioWind"
	var wind_stream := load("res://sounds/winter_wind_loop.mp3") as AudioStream
	if wind_stream:
		var dup_stream: AudioStream = wind_stream.duplicate()
		if dup_stream is AudioStreamMP3:
			(dup_stream as AudioStreamMP3).loop = true
		_audio_wind.stream = dup_stream
	_audio_wind.volume_db = wind_volume_db
	_audio_wind.pitch_scale = wind_pitch_scale
	_audio_wind.unit_size = 22.0
	_audio_wind.max_distance = 250.0
	_audio_wind.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	_audio_wind.autoplay = true
	_effects_root.add_child(_audio_wind)
	_audio_wind.play()

	# 6. Ejection whoosh SFX player
	_audio_eject = AudioStreamPlayer3D.new()
	_audio_eject.name = "AudioEject"
	_audio_eject.stream = load("res://sounds/teleport_swoosh.mp3")
	_audio_eject.volume_db = eject_volume_db
	_audio_eject.unit_size = 28.0
	_audio_eject.max_distance = 220.0
	_effects_root.add_child(_audio_eject)


## Builds a 256x256 2x2 atlas of domain-warped FBM dust cloud wisps (no hard spherical core).
static func _create_soft_dust_texture() -> Texture2D:
	if _cached_dust_tex != null:
		return _cached_dust_tex

	var cell := 96
	var size := cell * 2
	var img := Image.create(size, size, true, Image.FORMAT_RGBA8)

	var warp_noise := FastNoiseLite.new()
	warp_noise.seed = 419
	warp_noise.frequency = 0.024
	warp_noise.fractal_octaves = 3

	var fbm_noise := FastNoiseLite.new()
	fbm_noise.seed = 877
	fbm_noise.frequency = 0.030
	fbm_noise.fractal_octaves = 3

	# Four asymmetric multi-lobe offsets per quadrant so puffs never look like round balls
	var lobe_sets := [
		[Vector3(-0.18, 0.04, 0.62), Vector3(0.22, -0.06, 0.58), Vector3(0.02, 0.16, 0.54)],
		[Vector3(0.16, 0.08, 0.60), Vector3(-0.22, -0.08, 0.56), Vector3(-0.04, -0.18, 0.52)],
		[Vector3(-0.14, -0.12, 0.61), Vector3(0.20, 0.10, 0.58), Vector3(0.05, -0.02, 0.56)],
		[Vector3(0.18, -0.06, 0.60), Vector3(-0.18, 0.12, 0.58), Vector3(0.0, 0.08, 0.54)],
	]

	for fy in range(2):
		for fx in range(2):
			var frame_idx := fy * 2 + fx
			var lobes: Array = lobe_sets[frame_idx]
			var seed_off := Vector2(fx * 137.0, fy * 251.0)
			for py in range(cell):
				for px in range(cell):
					# Normalized cell coords in [-1, 1]
					var nx := ((float(px) + 0.5) / float(cell)) * 2.0 - 1.0
					var ny := ((float(py) + 0.5) / float(cell)) * 2.0 - 1.0

					# Radial safety border so quad edges never clip sharply
					var edge_r := sqrt(nx * nx + ny * ny)
					if edge_r >= 0.96:
						img.set_pixel(fx * cell + px, fy * cell + py, Color(1, 1, 1, 0))
						continue

					var wx := warp_noise.get_noise_2d(px + seed_off.x, py + seed_off.y) * 0.28
					var wy := warp_noise.get_noise_2d(px + seed_off.x + 71.0, py + seed_off.y + 93.0) * 0.28
					var qx := nx + wx
					var qy := ny + wy

					# Combine 3 overlapping elliptical cloud lobes smoothly (soft union)
					var lobe_val := 0.0
					for l in lobes:
						var lv: Vector3 = l
						var dx := (qx - lv.x) / (lv.z * 1.18)
						var dy := (qy - lv.y) / (lv.z * 0.92)
						var d2 := dx * dx + dy * dy
						var w := clampf(1.0 - d2, 0.0, 1.0)
						lobe_val = 1.0 - (1.0 - lobe_val) * (1.0 - w * w)

					# Modulate with smooth FBM billows so the cloud is creamy silt with wispy edges
					var n1 := fbm_noise.get_noise_2d(px + seed_off.x, py + seed_off.y) * 0.5 + 0.5
					var n2 := fbm_noise.get_noise_2d(px * 1.6 + seed_off.x + 43.0, py * 1.6 + seed_off.y) * 0.5 + 0.5
					var wisp := clampf(n1 * 0.70 + n2 * 0.30, 0.0, 1.0)

					var border_fade := 1.0 - smoothstep(0.58, 0.95, edge_r)
					var alpha := pow(lobe_val, 1.35) * smoothstep(0.10, 0.68, wisp) * border_fade

					# Soft internal cloud shading: warmer sunlit upper wisps, deeper lower folds
					var shade := clampf(0.90 - ny * 0.14 + (n1 - 0.5) * 0.18, 0.72, 1.06)
					img.set_pixel(
						fx * cell + px,
						fy * cell + py,
						Color(clampf(shade, 0.0, 1.0), clampf(shade * 0.97, 0.0, 1.0), clampf(shade * 0.93, 0.0, 1.0), clampf(alpha, 0.0, 1.0))
					)

	img.generate_mipmaps()
	_cached_dust_tex = ImageTexture.create_from_image(img)
	return _cached_dust_tex


## Small angular rock/clod chip texture for flying desert grit.
static func _create_grit_chip_texture() -> Texture2D:
	if _cached_grit_tex != null:
		return _cached_grit_tex
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 913
	noise.frequency = 0.35
	for y in range(16):
		for x in range(16):
			var nx := (x + 0.5) / 16.0 - 0.5
			var ny := (y + 0.5) / 16.0 - 0.5
			var r := sqrt(nx * nx + ny * ny) * 2.0 + noise.get_noise_2d(x, y) * 0.38
			var a := 1.0 - smoothstep(0.58, 0.76, r)
			var lit := clampf(0.86 - (nx + ny) * 0.55, 0.55, 1.0)
			img.set_pixel(x, y, Color(lit, lit, lit, a))
	_cached_grit_tex = ImageTexture.create_from_image(img)
	return _cached_grit_tex


## Called when a cart explodes/drowns/respawns while captured.
func force_release_cart(cart: Object) -> void:
	if cart == null or not is_instance_valid(cart):
		return
	var id := cart.get_instance_id()
	if not _captured.has(id):
		return
	_captured.erase(id)
	_cooldown[id] = cooldown_after_spit
	if cart is RigidBody3D:
		var rb := cart as RigidBody3D
		rb.freeze = false
		rb.sleeping = false
		if "axis_lock_angular_x" in rb:
			rb.axis_lock_angular_x = true
			rb.axis_lock_angular_y = true
			rb.axis_lock_angular_z = true
		# Do not restore can_move — explode/respawn owns that flag


## Called when a cart uses boost while inside the tornado to break free.
func escape_cart_with_boost(cart: Object) -> void:
	if cart == null or not is_instance_valid(cart):
		return
	var id := cart.get_instance_id()
	if not _captured.has(id):
		return
	_captured.erase(id)
	_cooldown[id] = cooldown_after_spit * 2.0

	if cart is RigidBody3D:
		var rb := cart as RigidBody3D
		rb.freeze = false
		rb.sleeping = false
		if "axis_lock_angular_x" in rb:
			rb.axis_lock_angular_x = true
			rb.axis_lock_angular_y = true
			rb.axis_lock_angular_z = true
		if "can_move" in rb:
			rb.set("can_move", true)

		var fwd := -rb.global_transform.basis.z
		if "visuals" in rb and is_instance_valid(rb.get("visuals")):
			fwd = -(rb.get("visuals") as Node3D).global_transform.basis.z
		fwd.y = 0.12
		fwd = fwd.normalized()
		rb.linear_velocity = fwd * 46.0
		rb.angular_velocity = Vector3.ZERO
		if rb.has_method("_reset_post_tornado_pose"):
			rb._reset_post_tornado_pose()

		# Trigger escape audio and burst effect
		if _audio_eject and is_instance_valid(_audio_eject):
			_audio_eject.global_position = rb.global_position
			_audio_eject.pitch_scale = randf_range(1.15, 1.30)
			_audio_eject.play()
		if _ejection_burst and is_instance_valid(_ejection_burst):
			_ejection_burst.global_position = rb.global_position
			_ejection_burst.restart()


func _physics_process(delta: float) -> void:
	_spin_visual(delta)
	# Suction pull runs on all peers for carts they have physics authority over
	_apply_suction(delta)

	# Movement & captures driven by host / offline authority
	var authority := multiplayer.multiplayer_peer == null or multiplayer.is_server()
	if not authority:
		return

	_wander(delta)
	_update_cooldowns(delta)
	_try_capture_nearby()
	_update_captures(delta)


func _spin_visual(delta: float) -> void:
	if _mesh and is_instance_valid(_mesh):
		_mesh.rotate_y(deg_to_rad(spin_speed_deg) * delta)
	else:
		rotate_y(deg_to_rad(spin_speed_deg) * delta)


## Applies aerodynamic suction and swirling cyclonic crosswind to nearby carts.
func _apply_suction(_delta: float) -> void:
	var carts := get_tree().get_nodes_in_group("player_carts")
	for cart in carts:
		if cart == null or not is_instance_valid(cart):
			continue
		if not (cart is RigidBody3D):
			continue
		var id := cart.get_instance_id()
		if _captured.has(id) or _cooldown.has(id):
			continue
		if cart.get("is_exploding") == true or cart.get("is_drowned") == true:
			continue
		if cart.has_method("has_physics_authority") and not cart.has_physics_authority():
			continue

		var rb := cart as RigidBody3D
		var to_tornado: Vector3 = global_position - rb.global_position
		to_tornado.y = 0.0
		var dist: float = to_tornado.length()
		if dist <= pickup_radius or dist > suction_radius:
			continue

		var radial: Vector3 = to_tornado.normalized()
		# Tangential swirling force (matching the tornado spin direction)
		var spin_dir: float = signf(spin_speed_deg)
		var tangent: Vector3 = Vector3(-radial.z, 0.0, radial.x) * spin_dir
		var pull_factor: float = smoothstep(suction_radius, pickup_radius, dist)
		var combined: Vector3 = (radial + tangent * suction_tangential_ratio).normalized()
		var mass: float = rb.mass if "mass" in rb else 1.0
		var force_vec: Vector3 = combined * (suction_force * pull_factor * mass)
		rb.apply_central_force(force_vec)


func _wander(delta: float) -> void:
	_retarget_timer -= delta
	if _retarget_timer <= 0.0:
		_pick_new_wander_target()

	var pos := global_position
	var flat_target := Vector3(_wander_target.x, pos.y, _wander_target.z)
	var to := flat_target - Vector3(pos.x, pos.y, pos.z)
	to.y = 0.0
	if to.length() > 0.4:
		var step: Vector3 = to.normalized() * wander_speed * delta
		if step.length() > to.length():
			step = to
		pos += step

	# Stay within wander_radius of home on XZ
	var from_home := Vector3(pos.x - _home.x, 0.0, pos.z - _home.z)
	if from_home.length() > wander_radius:
		var clamped: Vector3 = from_home.normalized() * wander_radius
		pos.x = _home.x + clamped.x
		pos.z = _home.z + clamped.z
		_pick_new_wander_target()

	# Keep feet near ground
	pos.y = _sample_ground_y(pos) + 0.2
	global_position = pos


func _pick_new_wander_target() -> void:
	var angle := randf() * TAU
	var dist := randf() * wander_radius * 0.92
	_wander_target = _home + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
	_retarget_timer = randf_range(retarget_time_min, retarget_time_max)


func _sample_ground_y(at: Vector3) -> float:
	var space := get_world_3d().direct_space_state if get_world_3d() else null
	if space == null:
		return _home.y
	var from := Vector3(at.x, at.y + ground_ray_height, at.z)
	var to := Vector3(at.x, at.y - ground_ray_height * 2.0, at.z)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	var hit := space.intersect_ray(q)
	if hit:
		return hit.position.y
	return _home.y


func _update_cooldowns(delta: float) -> void:
	var done: Array = []
	for id in _cooldown.keys():
		_cooldown[id] = float(_cooldown[id]) - delta
		if _cooldown[id] <= 0.0:
			done.append(id)
	for id in done:
		_cooldown.erase(id)


func _try_capture_nearby() -> void:
	var carts := get_tree().get_nodes_in_group("player_carts")
	for cart in carts:
		if cart == null or not is_instance_valid(cart):
			continue
		if not (cart is RigidBody3D):
			continue
		var id := cart.get_instance_id()
		if _captured.has(id) or _cooldown.has(id):
			continue
		if cart.get("is_exploding") == true or cart.get("is_drowned") == true:
			continue
		# Prefer physics authority carts (host AI + local / server)
		if cart.has_method("has_physics_authority") and not cart.has_physics_authority():
			continue

		var flat := Vector3(cart.global_position.x - global_position.x, 0.0, cart.global_position.z - global_position.z)
		if flat.length() > pickup_radius:
			continue

		# Shield blocks tornado grab (consumes the shield like a hit).
		if cart.get("is_shielded") == true:
			_break_cart_shield(cart)
			_cooldown[id] = cooldown_after_spit
			continue

		_start_capture(cart)


func _break_cart_shield(cart: Object) -> void:
	if cart == null:
		return
	cart.set("is_shielded", false)
	var cart_id: int = str(cart.name).to_int()
	var is_ai: bool = cart.get("is_ai") == true
	var is_real_peer: bool = cart_id > 0 and not is_ai
	if multiplayer.multiplayer_peer != null and multiplayer.is_server() and is_real_peer \
			and NetworkManager.current_game_mode == NetworkManager.GameMode.MULTIPLAYER:
		if cart.has_method("client_break_shield"):
			cart.client_break_shield.rpc_id(cart_id)
			return
	if cart.get("shield_mesh") != null:
		cart.shield_mesh.visible = false
		cart.shield_mesh.scale = Vector3.ONE
	elif cart.has_method("client_break_shield"):
		cart.client_break_shield()


func _start_capture(cart: RigidBody3D) -> void:
	var id := cart.get_instance_id()
	var offset := cart.global_position - global_position
	var angle := atan2(offset.z, offset.x)
	_captured[id] = {
		"cart": cart,
		"time": 0.0,
		"angle": angle,
		"height": maxf(1.5, cart.global_position.y - global_position.y),
	}

	# Freeze physics and take over pose while whirling
	cart.freeze = true
	cart.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	cart.linear_velocity = Vector3.ZERO
	cart.angular_velocity = Vector3.ZERO
	if "can_move" in cart:
		cart.set("can_move", false)
	if "axis_lock_angular_x" in cart:
		cart.axis_lock_angular_x = false
		cart.axis_lock_angular_y = false
		cart.axis_lock_angular_z = false


func _update_captures(delta: float) -> void:
	var finished: Array = []
	for id in _captured.keys():
		var state: Dictionary = _captured[id]
		var cart: RigidBody3D = state["cart"]
		if cart == null or not is_instance_valid(cart):
			finished.append(id)
			continue

		# Bomb/missile/drown while spinning: drop freeze ownership immediately
		if cart.get("is_exploding") == true or cart.get("is_drowned") == true:
			if cart is RigidBody3D:
				var rb := cart as RigidBody3D
				rb.freeze = false
				rb.sleeping = false
				if "axis_lock_angular_x" in rb:
					rb.axis_lock_angular_x = true
					rb.axis_lock_angular_y = true
					rb.axis_lock_angular_z = true
			_cooldown[id] = cooldown_after_spit
			finished.append(id)
			continue

		# Boost used while spinning: escape immediately
		var btimer = cart.get("boost_timer")
		if cart.get("is_boosting") == true or cart.get("is_pad_boosting") == true or (btimer != null and float(btimer) > 0.0):
			escape_cart_with_boost(cart)
			finished.append(id)
			continue

		state["time"] = float(state["time"]) + delta
		var t: float = clampf(float(state["time"]) / capture_duration, 0.0, 1.0)
		# Ease: rise fast mid-way, then hold
		var lift_t: float = smoothstep(0.0, 0.75, t)
		var height: float = lerpf(float(state["height"]), lift_height, lift_t)
		var radius: float = lerpf(orbit_radius_start, orbit_radius_end, t)
		state["angle"] = float(state["angle"]) + spin_orbit_speed * delta * (1.0 + t)

		var ang: float = float(state["angle"])
		var pos := global_position + Vector3(cos(ang) * radius, height, sin(ang) * radius)
		cart.global_position = pos
		# Spin the car wildly
		cart.global_rotate(Vector3.UP, spin_orbit_speed * 1.4 * delta)
		cart.global_rotate(Vector3.RIGHT, spin_orbit_speed * 0.6 * delta)

		_captured[id] = state

		if float(state["time"]) >= capture_duration:
			_spit_out(cart, ang)
			finished.append(id)

	for id in finished:
		_captured.erase(id)


func _spit_out(cart: RigidBody3D, ang: float) -> void:
	var id := cart.get_instance_id()
	_cooldown[id] = cooldown_after_spit

	# Outward + a bit of upward fling
	var outward := Vector3(cos(ang), 0.0, sin(ang)).normalized()
	var spit := outward * spit_speed + Vector3.UP * spit_up_speed
	# Slight random side spray
	spit += Vector3(randf_range(-4.0, 4.0), randf_range(0.0, 5.0), randf_range(-4.0, 4.0))

	cart.freeze = false
	cart.sleeping = false
	cart.linear_velocity = spit
	cart.angular_velocity = Vector3(
		randf_range(-8.0, 8.0),
		randf_range(-10.0, 10.0),
		randf_range(-8.0, 8.0)
	)

	# Sound and burst FX at launch spot
	if _audio_eject and is_instance_valid(_audio_eject):
		_audio_eject.global_position = cart.global_position
		_audio_eject.pitch_scale = randf_range(0.92, 1.08)
		_audio_eject.play()
	if _ejection_burst and is_instance_valid(_ejection_burst):
		_ejection_burst.global_position = cart.global_position
		_ejection_burst.restart()

	# Cart uprights + re-locks axes after a short tumble (prevents permanent hover)
	if cart.has_method("_tornado_restore_control"):
		cart._tornado_restore_control()


func _apply_transparency(root: Node) -> void:
	if root == null:
		return
	if root is MeshInstance3D:
		var mi := root as MeshInstance3D
		var mat := ShaderMaterial.new()
		mat.shader = VORTEX_SHADER
		mat.set_shader_parameter("overall_alpha", mesh_alpha)
		mat.set_shader_parameter("base_dust_color", base_dust_color)
		mat.set_shader_parameter("mid_dust_color", mid_dust_color)
		mat.set_shader_parameter("top_dust_color", top_dust_color)
		if mi.mesh:
			var surfaces := mi.mesh.get_surface_count()
			for s in range(surfaces):
				mi.set_surface_override_material(s, mat)
		if mi.material_override != null or (mi.mesh == null):
			mi.material_override = mat

	for c in root.get_children():
		if c != _effects_root:
			_apply_transparency(c)
