extends Node3D
## Wandering tornado: spins, semi-transparent, drifts near its home, then
## picks up cars, whirls them upward, and spits them out.

@export var mesh_path: NodePath = NodePath("Mesh")
@export var spin_speed_deg: float = 220.0
@export var mesh_alpha: float = 0.48

@export_group("Wander")
@export var wander_radius: float = 55.0
@export var wander_speed: float = 6.0
@export var retarget_time_min: float = 2.5
@export var retarget_time_max: float = 5.5
@export var ground_ray_height: float = 80.0

@export_group("Pickup")
@export var pickup_radius: float = 18.0
@export var capture_duration: float = 2.4
@export var orbit_radius_start: float = 10.0
@export var orbit_radius_end: float = 3.5
@export var lift_height: float = 22.0
@export var spin_orbit_speed: float = 5.5
@export var spit_speed: float = 38.0
@export var spit_up_speed: float = 16.0
@export var cooldown_after_spit: float = 1.2

var _mesh: Node3D
var _home: Vector3
var _wander_target: Vector3
var _retarget_timer: float = 0.0
var _captured: Dictionary = {} # cart instance_id -> capture state
var _cooldown: Dictionary = {} # cart instance_id -> time left

func _ready() -> void:
	_home = global_position
	_wander_target = _home
	_mesh = get_node_or_null(mesh_path)
	if _mesh == null:
		# FBX root is often the only child
		for c in get_children():
			if c is Node3D:
				_mesh = c
				break
	_apply_transparency(_mesh if _mesh else self)
	_pick_new_wander_target()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_spin_visual(delta)
	# Visual spin on all peers; movement + captures driven by host / offline
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

		_start_capture(cart)


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

	# Cart uprights + re-locks axes after a short tumble (prevents permanent hover)
	if cart.has_method("_tornado_restore_control"):
		cart._tornado_restore_control()


func _apply_transparency(root: Node) -> void:
	if root == null:
		return
	if root is MeshInstance3D:
		var mi := root as MeshInstance3D
		# Override materials to semi-transparent
		var mat_count := mi.get_surface_override_material_count()
		if mi.mesh:
			var surfaces := mi.mesh.get_surface_count()
			for s in range(surfaces):
				var base: Material = mi.get_active_material(s)
				var mat: Material = base.duplicate() if base else StandardMaterial3D.new()
				if mat is StandardMaterial3D:
					var sm := mat as StandardMaterial3D
					sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					sm.cull_mode = BaseMaterial3D.CULL_DISABLED
					var c := sm.albedo_color
					c.a = mesh_alpha
					sm.albedo_color = c
					# Keep some shine so it reads as dusty air
					sm.roughness = minf(sm.roughness, 0.85)
				elif mat is ShaderMaterial:
					# Best-effort alpha if the shader exposes it
					var sh := mat as ShaderMaterial
					if sh.shader:
						pass
					# Fallback overlay
					var sm2 := StandardMaterial3D.new()
					sm2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					sm2.albedo_color = Color(0.7, 0.7, 0.65, mesh_alpha)
					sm2.cull_mode = BaseMaterial3D.CULL_DISABLED
					mat = sm2
				mi.set_surface_override_material(s, mat)
		if mi.material_override:
			var mo: Material = mi.material_override.duplicate()
			if mo is StandardMaterial3D:
				(mo as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				var c2 := (mo as StandardMaterial3D).albedo_color
				c2.a = mesh_alpha
				(mo as StandardMaterial3D).albedo_color = c2
			mi.material_override = mo

	for c in root.get_children():
		_apply_transparency(c)
