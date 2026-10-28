extends Node3D
## Wandering desert tornado / twister:
## Spins with dynamic vortex shader (warm terracotta/sand gradient, serpentine sway,
## spiral wind bands), churns desert dust at touchdown, creates aerodynamic suction
## on approaching cars, whirls captured cars upward, and spits them out with dramatic SFX.

const VORTEX_SHADER: Shader = preload("res://tornado_vortex.gdshader")

@export_group("Visuals")
@export var mesh_path: NodePath = NodePath("Mesh")
@export var spin_speed_deg: float = 220.0
@export var mesh_alpha: float = 0.65
@export var base_dust_color: Color = Color(0.72, 0.42, 0.24, 0.88)
@export var mid_dust_color: Color = Color(0.86, 0.60, 0.36, 0.75)
@export var top_dust_color: Color = Color(0.82, 0.76, 0.70, 0.50)

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
var _debris_particles: GPUParticles3D
var _ejection_burst: CPUParticles3D
var _audio_wind: AudioStreamPlayer3D
var _audio_eject: AudioStreamPlayer3D


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

	var soft_tex := _create_soft_dust_texture()

	# 1. Ground contact dust blast / churning ring where vortex meets terrain
	_ground_dust = GPUParticles3D.new()
	_ground_dust.name = "GroundDust"
	_ground_dust.position = Vector3(0, 0.4, 0)
	_ground_dust.amount = 95
	_ground_dust.lifetime = 2.0
	_ground_dust.local_coords = false
	_ground_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ground_dust.visibility_aabb = AABB(Vector3(-30, -5, -30), Vector3(60, 30, 60))

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3(0, 1, 0)
	pm.emission_ring_radius = 5.5
	pm.emission_ring_inner_radius = 0.8
	pm.emission_ring_height = 0.4
	pm.direction = Vector3(0, 0.6, 0)
	pm.spread = 45.0
	pm.initial_velocity_min = 4.0
	pm.initial_velocity_max = 8.5
	pm.gravity = Vector3(0, 0.8, 0)
	pm.tangential_accel_min = 18.0
	pm.tangential_accel_max = 32.0
	pm.radial_accel_min = 3.0
	pm.radial_accel_max = 7.0
	pm.damping_min = 2.0
	pm.damping_max = 4.0
	pm.scale_min = 3.5
	pm.scale_max = 7.5

	var alpha_grad := Gradient.new()
	alpha_grad.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	alpha_grad.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
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
	dmat.vertex_color_use_as_albedo = true
	dmat.albedo_texture = soft_tex
	dmat.albedo_color = Color(0.78, 0.48, 0.30, 0.45)
	dmat.proximity_fade_enabled = true
	dmat.proximity_fade_distance = 1.8
	quad.material = dmat
	_ground_dust.draw_pass_1 = quad
	_effects_root.add_child(_ground_dust)

	# 2. Funnel debris particles (dark grit / sand grains orbiting up the column)
	_debris_particles = GPUParticles3D.new()
	_debris_particles.name = "FunnelDebris"
	_debris_particles.position = Vector3(0, 1.0, 0)
	_debris_particles.amount = 80
	_debris_particles.lifetime = 2.2
	_debris_particles.local_coords = false
	_debris_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_debris_particles.visibility_aabb = AABB(Vector3(-25, -2, -25), Vector3(50, 40, 50))

	var dpm := ParticleProcessMaterial.new()
	dpm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	dpm.emission_ring_axis = Vector3(0, 1, 0)
	dpm.emission_ring_radius = 4.2
	dpm.emission_ring_inner_radius = 0.5
	dpm.emission_ring_height = 1.0
	dpm.direction = Vector3(0, 1, 0)
	dpm.spread = 15.0
	dpm.initial_velocity_min = 14.0
	dpm.initial_velocity_max = 24.0
	dpm.tangential_accel_min = 28.0
	dpm.tangential_accel_max = 48.0
	dpm.radial_accel_min = -2.0
	dpm.radial_accel_max = 5.0
	dpm.scale_min = 0.4
	dpm.scale_max = 1.4

	var d_alpha_grad := Gradient.new()
	d_alpha_grad.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	d_alpha_grad.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	var d_alpha_tex := GradientTexture1D.new()
	d_alpha_tex.gradient = d_alpha_grad
	dpm.color_ramp = d_alpha_tex
	_debris_particles.process_material = dpm

	var d_quad := QuadMesh.new()
	d_quad.size = Vector2(0.8, 0.8)
	var deb_mat := StandardMaterial3D.new()
	deb_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	deb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	deb_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	deb_mat.vertex_color_use_as_albedo = true
	deb_mat.albedo_texture = soft_tex
	deb_mat.albedo_color = Color(0.48, 0.30, 0.18, 0.75)
	d_quad.material = deb_mat
	_debris_particles.draw_pass_1 = d_quad
	_effects_root.add_child(_debris_particles)

	# 3. Ejection burst (one-shot dust puff on cart fling or boost escape)
	_ejection_burst = CPUParticles3D.new()
	_ejection_burst.name = "EjectionBurst"
	_ejection_burst.emitting = false
	_ejection_burst.one_shot = true
	_ejection_burst.explosiveness = 0.92
	_ejection_burst.amount = 32
	_ejection_burst.lifetime = 1.2
	_ejection_burst.spread = 180.0
	_ejection_burst.initial_velocity_min = 12.0
	_ejection_burst.initial_velocity_max = 24.0
	_ejection_burst.damping_min = 8.0
	_ejection_burst.damping_max = 16.0
	_ejection_burst.scale_amount_min = 2.0
	_ejection_burst.scale_amount_max = 4.5
	var b_quad := QuadMesh.new()
	b_quad.size = Vector2(1.0, 1.0)
	var b_mat := StandardMaterial3D.new()
	b_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	b_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	b_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	b_mat.albedo_texture = soft_tex
	b_mat.albedo_color = Color(0.85, 0.58, 0.38, 0.65)
	b_quad.material = b_mat
	_ejection_burst.mesh = b_quad
	_effects_root.add_child(_ejection_burst)

	# 4. Continuous 3D roaring wind audio
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

	# 5. Ejection whoosh SFX player
	_audio_eject = AudioStreamPlayer3D.new()
	_audio_eject.name = "AudioEject"
	_audio_eject.stream = load("res://sounds/teleport_swoosh.mp3")
	_audio_eject.volume_db = eject_volume_db
	_audio_eject.unit_size = 28.0
	_audio_eject.max_distance = 220.0
	_effects_root.add_child(_audio_eject)


static func _create_soft_dust_texture() -> Texture2D:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	return tex


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
