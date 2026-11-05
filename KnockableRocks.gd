extends MultiMeshInstance3D

const CartWeight = preload("res://CartWeight.gd")
## Rock clusters that carts can push through: the rocks get pushed aside and tumble away,
## while significantly slowing the cart down through momentum loss and heavy drag.
##
## Drawn as a MultiMesh. At runtime, each rock gets a RigidBody3D frozen in place.
## A cart approaching or contacting the rock frees it, pushing it aside with stone impact audio.
## Plowing through the rocks imposes heavy drag on the cart, slowing it significantly.

const PROP_LAYER := 1 << 4
const BONK_SOUND := preload("res://sounds/collision_bonk.mp3")

@export var rock_transforms: Array[Transform3D] = []
@export var rock_radii: Array[float] = []
## Additional drag applied to carts plowing through this rock cluster.
@export var cluster_drag := 7.5
@export var push_distance := 2.5

var _bodies: Array[RigidBody3D] = []
var _state: PackedByteArray = PackedByteArray()   # 0 frozen, 1 free, 2 recently struck
var _bonk: AudioStreamPlayer3D
var _sound_cooldown := 0.0
var _cluster_center := Vector3.ZERO
var _cluster_radius := 6.0
var _active_count := 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("knockable_rocks")

	# Ensure the rock material uses local object-space coordinates so rolling/pushing rocks
	# don't suffer from world-space texture sliding (parallax scrolling).
	if multimesh and multimesh.mesh and multimesh.mesh.surface_get_material(0) is ShaderMaterial:
		var orig_mat = multimesh.mesh.surface_get_material(0) as ShaderMaterial
		var dyn_mat := orig_mat.duplicate() as ShaderMaterial
		dyn_mat.set_shader_parameter("local_coords", true)
		material_override = dyn_mat

	var n := rock_transforms.size()
	multimesh.instance_count = n

	var center := Vector3.ZERO
	for i in range(n):
		var xf := rock_transforms[i]
		center += xf.origin
		multimesh.set_instance_transform(i, xf)
		var r: float = rock_radii[i] if i < rock_radii.size() else 0.5
		var body := RigidBody3D.new()
		body.name = "Rock_%d" % i
		body.add_to_group("knockable_rocks")
		body.collision_layer = 1 | PROP_LAYER
		body.collision_mask = 1 | PROP_LAYER

		# Real sandstone rock mass: 320kg for 0.4m stone up to 950kg for 0.8m boulder
		body.mass = clampf(r * r * r * 2200.0, 320.0, 950.0)
		var pm := PhysicsMaterial.new()
		pm.friction = 0.95
		pm.bounce = 0.06
		body.physics_material_override = pm
		body.continuous_cd = true
		body.linear_damp = 3.5
		body.angular_damp = 3.5
		body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		body.freeze = true

		var cs := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = r * 0.85
		cs.shape = sphere
		cs.position = Vector3(0.0, r * 0.85, 0.0)
		body.add_child(cs)

		body.transform = xf
		add_child(body, false, Node.INTERNAL_MODE_BACK)
		_bodies.append(body)

	if n > 0:
		_cluster_center = center / float(n)
		_cluster_radius = 4.0
		for xf in rock_transforms:
			_cluster_radius = maxf(_cluster_radius, _cluster_center.distance_to(xf.origin) + 2.0)

	_state.resize(n)
	_state.fill(0)

	_bonk = AudioStreamPlayer3D.new()
	_bonk.stream = BONK_SOUND
	_bonk.bus = &"SFX"
	_bonk.unit_size = 18.0
	_bonk.max_distance = 150.0
	add_child(_bonk, false, Node.INTERNAL_MODE_BACK)


func _physics_process(delta: float) -> void:
	if _bodies.is_empty() or delta <= 0.0:
		return
	_sound_cooldown = maxf(0.0, _sound_cooldown - delta)

	var carts: Array = []
	for c in get_tree().get_nodes_in_group("player_carts"):
		var rb := c as RigidBody3D
		if rb and is_instance_valid(rb):
			carts.append(rb)

	if carts.is_empty():
		return

	# Only simulate if a cart is in the vicinity of this cluster or rocks are actively moving
	var near_any := false
	for cart in carts:
		if cart.global_position.distance_squared_to(_cluster_center) < (_cluster_radius + 7.0) * (_cluster_radius + 7.0):
			near_any = true
			break

	if not near_any and _active_count == 0:
		return

	for cart in carts:
		var cpos: Vector3 = cart.global_position
		var cvel: Vector3 = cart.linear_velocity
		var cspeed: float = cvel.length()
		var in_cluster := false

		for i in range(_bodies.size()):
			var b: RigidBody3D = _bodies[i]
			var bpos: Vector3 = b.global_position
			var r: float = rock_radii[i] if i < rock_radii.size() else 0.5
			var dist := cpos.distance_to(bpos)

			# If cart is within pushing range of this rock
			if dist < r + push_distance and absf(cpos.y - bpos.y) < 2.0:
				in_cluster = true
				if _state[i] == 0:
					b.freeze = false
					b.collision_layer = 1 | PROP_LAYER
					_state[i] = 1
					_active_count += 1
					# Heavy immediate momentum loss on striking a solid stone
					var has_auth: bool = not cart.has_method("has_physics_authority") or cart.has_physics_authority()
					if has_auth and cspeed > 3.0:
						# A heavy car loses less to it (CartWeight).
						var hit_loss: float = 1.0 - clampf((b.mass / 1200.0) * 0.42, 0.18, 0.35) * CartWeight.loss_share(cart)
						cart.linear_velocity *= hit_loss
						cart.angular_velocity += Vector3(randf_range(-1.5, 1.5), randf_range(-0.8, 0.8), randf_range(-1.5, 1.5))

				# Push rock aside (heavy stone rolling, not flying away)
				var push_dir := (bpos - cpos)
				push_dir.y = 0.12
				push_dir = push_dir.normalized()
				var push_force: float = clampf(cspeed * 0.28, 1.2, 5.5) * CartWeight.push_share(cart)
				b.apply_central_impulse(push_dir * (b.mass * push_force * delta * 15.0) + Vector3.UP * (b.mass * 0.2))

				# Sound on hard impact
				if _sound_cooldown <= 0.0 and cspeed > 3.0 and _state[i] == 1:
					_state[i] = 2
					_sound_cooldown = 0.10
					_bonk.global_position = bpos
					_bonk.pitch_scale = randf_range(0.80, 1.05)
					_bonk.volume_db = clampf((cspeed - 12.0) * 0.3, -4.0, 4.0)
					_bonk.play()

		# Significant slowdown and resistance when pushing through the heavy rock cluster
		if in_cluster and cspeed > 1.5:
			var has_auth: bool = not cart.has_method("has_physics_authority") or cart.has_physics_authority()
			if has_auth:
				# Heavy drag resistance
				var drag: float = clampf(cluster_drag * delta * CartWeight.loss_share(cart), 0.0, 0.85)
				cart.linear_velocity *= (1.0 - drag)
				# Opposing deceleration force from plowing heavy rocks
				cart.apply_central_force(-cvel.normalized() * cart.mass * 36.0 * CartWeight.loss_share(cart))
			if cart.has_method("jolt"):
				cart.jolt(randf_range(-0.45, 0.55), randf_range(-0.35, 0.35), randf_range(-0.4, 0.4))
			if cart.has_method("jolt"):
				cart.jolt(randf_range(-0.35, 0.45), randf_range(-0.25, 0.25), randf_range(-0.3, 0.3))

	# Update visual MultiMesh transforms for moving rocks
	var moving_count := 0
	for i in range(_bodies.size()):
		var b: RigidBody3D = _bodies[i]
		if _state[i] == 0 or b.sleeping:
			continue
		if b.global_position.y < -40.0:
			b.freeze = true
			continue
		moving_count += 1
		multimesh.set_instance_transform(i, b.transform)
	_active_count = moving_count
