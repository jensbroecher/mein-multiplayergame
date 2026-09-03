extends CharacterBody3D

const MISSILE_EXPLOSION_SOUNDS = [
	preload("res://sounds/missile_explosion_wi_#1-1781728385875.wav"),
	preload("res://sounds/missile_explosion_wi_#2-1781728388962.wav"),
	preload("res://sounds/missile_explosion_wi_#3-1781728394157.wav"),
	preload("res://sounds/missile_explosion_wi_#4-1781728398285.wav")
]

const FLIGHT_SOUND = preload("res://sounds/774270__thelittlecrow__rocket-launch-boost-and-burning-version-b.wav")

@export var speed: float = 52.0   # Starts well above car top speed (cars reach ~40-43 m/s)
const SPEED_MAX: float = 75.0     # Accelerates up to 75 m/s
const SPEED_ACCEL: float = 16.0   # m/s² acceleration
@export var owner_id: int
@export var is_guided: bool = false
var sync_position: Vector3
var sync_rotation: Vector3

@onready var area = $Area3D
@onready var visuals = $Visuals
@onready var fire_trail = $FireTrail
@onready var explosion_particles = $ExplosionParticles
@onready var smoke_particles = $SmokeParticles
@onready var fire_sprite_particles = $FireSpriteParticles
@onready var fire_sprite_particles_2 = $FireSpriteParticles2
var target: Node3D = null
var lifetime = 8.0
var search_timer = 0.0
var spawn_safety_timer = 0.04
var start_position: Vector3 = Vector3.ZERO
@export var max_range: float = 180.0
var homing_delay: float = 0.0
var is_exploding: bool = false
var has_exploded: bool = false

func _ready():
	add_to_group("missiles")
	area.body_entered.connect(_on_body_entered)
	
	# Play flight sound looping/starting at launch
	var flight_audio = AudioStreamPlayer3D.new()
	flight_audio.name = "FlightAudio"
	flight_audio.stream = FLIGHT_SOUND
	flight_audio.autoplay = true
	flight_audio.unit_size = 20.0
	flight_audio.max_distance = 100.0
	add_child(flight_audio)
	
	if is_instance_valid(fire_trail):
		fire_trail.emitting = true
	if start_position == Vector3.ZERO:
		start_position = global_position
	if is_guided:
		speed = 56.0
		lifetime = 12.0
		max_range = 240.0
		# Blue/purple tint for the nose cone of guided missiles
		var nose_cone = get_node_or_null("Visuals/NoseCone")
		if nose_cone:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.05, 0.35, 0.95, 1) # Vibrant blue
			mat.roughness = 0.2
			mat.metallic = 0.4
			mat.emission_enabled = true
			mat.emission = Color(0.02, 0.15, 0.9, 1) # Blue emission
			mat.emission_energy_multiplier = 0.8
			nose_cone.material_override = mat
			
		# Also tint the nozzle glow to match the blue theme
		var nozzle = get_node_or_null("Visuals/Nozzle")
		if nozzle:
			var nm = StandardMaterial3D.new()
			nm.albedo_color = Color(0.1, 0.1, 0.35, 1)
			nm.metallic = 0.9
			nm.emission_enabled = true
			nm.emission = Color(0.05, 0.15, 0.85, 1) # Blue exhaust glow
			nm.emission_energy_multiplier = 3.0
			nozzle.material_override = nm
	else:
		lifetime = 8.0
		max_range = 180.0
		
	_find_target()
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		sync_position = global_position
		sync_rotation = global_rotation

func _find_target():
	if not is_guided:
		target = null
		return

	var players = get_tree().get_nodes_in_group("player_carts")
	var forward: Vector3 = -global_transform.basis.z
	var right: Vector3 = global_transform.basis.x
	
	# Tier 1: Car directly in front on the course ahead
	var best_in_front_dist: float = 9999.0
	var best_in_front_target: Node3D = null
	
	# Tier 2: Broader search if no car is directly in front
	var best_search_score: float = 9999.0
	var best_search_target: Node3D = null
	
	for p in players:
		if p == null or not is_instance_valid(p):
			continue
		if p.name.to_int() == owner_id:
			continue
		if p.get("is_exploding") == true or p.get("is_drowned") == true:
			continue
			
		var to_p: Vector3 = p.global_position - global_position
		var dist: float = to_p.length()
		if dist < 0.5 or dist > max_range:
			continue
			
		var dir_to_target: Vector3 = to_p / dist
		var fwd_dot: float = forward.dot(dir_to_target)
		var fwd_dist: float = forward.dot(to_p)
		var side_dist: float = absf(right.dot(to_p))
		var height_dist: float = absf(to_p.y)
		
		# Reject carts that are behind or nearly perpendicular (sideways)
		if fwd_dot < 0.38 or fwd_dist <= 1.5:
			continue
			
		# Reject carts that are very far to the left or right
		if side_dist > 35.0 or (side_dist > fwd_dist * 1.1):
			continue
			
		# Reject carts that are very far above or below (e.g. overpasses, bridges, or chasms)
		if height_dist > 14.0 or (height_dist > fwd_dist * 0.75):
			continue
			
		# Tier 1: Directly in front (narrow forward corridor, tight lateral cushion, close height)
		if fwd_dot >= 0.65 and side_dist <= 18.0 and height_dist <= 9.0:
			if dist < best_in_front_dist:
				best_in_front_dist = dist
				best_in_front_target = p
		else:
			# Tier 2: Broader search candidate (penalize off-axis lateral and vertical distances)
			var score: float = dist + side_dist * 2.5 + height_dist * 3.0
			if score < best_search_score:
				best_search_score = score
				best_search_target = p
				
	# Prioritize the car in front; if none, use broader candidate
	if best_in_front_target:
		target = best_in_front_target
	else:
		target = best_search_target

func _physics_process(delta):
	if is_exploding or has_exploded:
		return

	# Decrement lifetime on all peers to prevent stuck/phantom projectiles if RPC is lost
	lifetime -= delta
	if lifetime <= 0:
		_explode()
		return

	# Check maximum flight range
	if global_position.distance_to(start_position) >= max_range:
		_explode()
		return

	if multiplayer.multiplayer_peer == null or multiplayer.is_server():
		if spawn_safety_timer > 0.0:
			spawn_safety_timer -= delta

		search_timer += delta
		if search_timer > 0.25:
			_find_target()
			search_timer = 0.0

		if homing_delay > 0.0:
			homing_delay -= delta
		elif is_guided and target and is_instance_valid(target):
			var to_target: Vector3 = target.global_position - global_position
			var dist: float = to_target.length()
			var forward: Vector3 = -global_transform.basis.z
			var right: Vector3 = global_transform.basis.x
			var dir: Vector3 = to_target.normalized()
			var fwd_dot: float = forward.dot(dir)
			var side_dist: float = absf(right.dot(to_target))
			var height_dist: float = absf(to_target.y)
			
			# Break lock if target goes behind, or too far sideways/vertically
			if fwd_dot < 0.25 or side_dist > 45.0 or height_dist > 18.0 or dist > max_range \
					or target.get("is_exploding") == true or target.get("is_drowned") == true:
				target = null
			else:
				# Clamp vertical pitch so missile does not dive straight down or pitch vertically straight up
				var clamped_dir: Vector3 = dir
				clamped_dir.y = clampf(clamped_dir.y, -0.55, 0.55)
				clamped_dir = clamped_dir.normalized()
				
				if absf(clamped_dir.dot(Vector3.UP)) < 0.98:
					var target_basis: Basis = Basis.looking_at(clamped_dir, Vector3.UP)
					var turn_speed: float = 4.2
					global_basis = global_basis.slerp(target_basis, turn_speed * delta).orthonormalized()

		# Gradually accelerate from start speed to max
		speed = min(speed + SPEED_ACCEL * delta, SPEED_MAX)

		var forward = -global_transform.basis.z

		# Sweep raycast to prevent tunneling at high velocity (52-75 m/s) and detect cars immediately in front
		var space_state = get_world_3d().direct_space_state
		if space_state:
			var step_dist = maxf(speed * delta + 0.6, 1.2)
			var query = PhysicsRayQueryParameters3D.create(global_position, global_position + forward * step_dist)
			query.exclude = [self.get_rid()]
			query.collision_mask = 1 | 2 # Layer 1 (carts/terrain), Layer 2 (props)
			var hit = space_state.intersect_ray(query)
			if hit and hit.collider:
				var col = hit.collider
				if col.is_in_group("player_carts"):
					if not (col.name.to_int() == owner_id and spawn_safety_timer > 0.0):
						_explode()
						return
				elif col is StaticBody3D or col is CSGShape3D or col is GridMap:
					_explode()
					return

		# Check overlapping bodies in Area3D in case target was already touching at launch
		if is_instance_valid(area):
			for body in area.get_overlapping_bodies():
				if body.is_in_group("player_carts"):
					if not (body.name.to_int() == owner_id and spawn_safety_timer > 0.0):
						_explode()
						return
				elif body is StaticBody3D or body is CSGShape3D or body is GridMap:
					_explode()
					return

		velocity = forward * speed
		move_and_slide()
		
		# Check slide collisions after movement
		for i in range(get_slide_collision_count()):
			var collision = get_slide_collision(i)
			var col = collision.get_collider()
			if col:
				if col.is_in_group("player_carts"):
					if not (col.name.to_int() == owner_id and spawn_safety_timer > 0.0):
						_explode()
						return
				elif col is StaticBody3D or col is CSGShape3D or col is GridMap:
					_explode()
					return
		
		sync_position = global_position
		sync_rotation = global_rotation


func _process(delta):
	if is_exploding or has_exploded:
		return

	# If we are a client, smoothly interpolate position and rotation to synced values
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		# Client-side dead reckoning prediction
		# 1. Update client-side speed approximation (so it accelerates like the server)
		speed = min(speed + SPEED_ACCEL * delta, SPEED_MAX)
		
		# 2. Predict next position by moving forward along current orientation
		var forward = -global_transform.basis.z
		global_position += forward * speed * delta
		
		# 3. Blend toward the actual network-synchronized position to correct errors
		var t = 1.0 - exp(-15.0 * delta)
		global_position = global_position.lerp(sync_position, t)
		
		var current_quat = global_transform.basis.get_rotation_quaternion()
		var target_quat = Quaternion.from_euler(sync_rotation)
		global_transform.basis = Basis(current_quat.slerp(target_quat, t))


func _on_body_entered(body):
	if is_exploding or has_exploded: return
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server(): return
	if body.is_in_group("player_carts"):
		# If it's the shooter, prevent immediate self-detonation for a split second (using spawn_safety_timer)
		if body.name.to_int() == owner_id and spawn_safety_timer > 0.0:
			return
		_explode()
	elif body is StaticBody3D or body is CSGShape3D or body is GridMap:
		_explode()

func _explode():
	if is_exploding or has_exploded or not is_instance_valid(self): return
	is_exploding = true

	# Disable collision area immediately
	if is_instance_valid(area):
		area.set_deferred("monitoring", false)
		area.set_deferred("monitorable", false)

	# Server-side blast radius damage logic (similar to Bomb.gd)
	if multiplayer.multiplayer_peer == null or multiplayer.is_server():
		var blast_radius = 7.0
		var players = get_tree().get_nodes_in_group("player_carts")
		for p in players:
			# Notice there is no owner exclusion, so the owner can be hit if close to the blast!
			var dist = global_position.distance_to(p.global_position)
			if dist <= blast_radius:
				if p.has_method("on_hit"):
					var was_shielded = p.is_shielded
					p.on_hit(owner_id)
					if was_shielded:
						continue
					
					var dir = (p.global_position - global_position).normalized()
					if dir.length_squared() < 0.01:
						dir = Vector3.UP
					var impulse = dir * 8.0 * p.mass + Vector3.UP * 4.0 * p.mass
					var is_real_peer = p.name.to_int() > 0 and not p.get("is_ai")
					if p.has_method("apply_blast_impulse"):
						if multiplayer.multiplayer_peer != null and is_real_peer:
							p.apply_blast_impulse.rpc_id(p.name.to_int(), impulse)
						else:
							p.apply_central_impulse(impulse)
					else:
						p.apply_central_impulse(impulse)

	if multiplayer.multiplayer_peer != null:
		_explode_rpc.rpc()
	else:
		_explode_rpc()

@rpc("authority", "call_local", "reliable")
func _explode_rpc():
	if has_exploded: return
	has_exploded = true
	is_exploding = true
	
	# Disable collisions immediately on client
	var area_col = get_node_or_null("Area3D/CollisionShape3D")
	if area_col: area_col.set_deferred("disabled", true)
	if is_instance_valid(area):
		area.set_deferred("monitoring", false)
		area.set_deferred("monitorable", false)
	
	var scene_root = get_tree().current_scene
	if not scene_root:
		scene_root = get_parent()
	if not scene_root:
		queue_free()
		return

	var expl_pos = global_position
	
	# Play a random missile explosion sound
	var sound_stream = MISSILE_EXPLOSION_SOUNDS[randi() % MISSILE_EXPLOSION_SOUNDS.size()]
	if sound_stream:
		var ap = AudioStreamPlayer3D.new()
		ap.stream = sound_stream
		ap.max_distance = 80.0
		ap.unit_size = 10.0
		ap.position = expl_pos
		scene_root.add_child(ap)
		ap.global_position = expl_pos
		ap.play()
		get_tree().create_timer(sound_stream.get_length() + 0.5).timeout.connect(ap.queue_free)

	# Stop and detach the fire trail so it fades out naturally
	if is_instance_valid(fire_trail) and fire_trail.get_parent() == self:
		var trail_pos = fire_trail.global_position
		remove_child(fire_trail)
		fire_trail.position = trail_pos
		scene_root.add_child(fire_trail)
		fire_trail.global_position = trail_pos
		fire_trail.emitting = false
		get_tree().create_timer(fire_trail.lifetime + 0.2).timeout.connect(
			func(): if is_instance_valid(fire_trail): fire_trail.queue_free()
		)

	# Detach and fire explosion particles so they outlive the missile node
	for ps in [explosion_particles, smoke_particles, fire_sprite_particles, fire_sprite_particles_2]:
		if is_instance_valid(ps) and ps.get_parent() == self:
			var ps_pos = global_position
			remove_child(ps)
			ps.position = ps_pos
			scene_root.add_child(ps)
			ps.global_position = ps_pos
			ps.emitting = true
			get_tree().create_timer(ps.lifetime + 0.3).timeout.connect(
				func(): if is_instance_valid(ps): ps.queue_free()
			)

	# Small bright flash sphere (particles carry the main visual now)
	var expl_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.6
	sphere.height = 1.2
	expl_mesh.mesh = sphere
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.75, 0.15, 0.9)
	expl_mesh.material_override = mat
	expl_mesh.position = expl_pos
	scene_root.add_child(expl_mesh)
	expl_mesh.global_position = expl_pos
	expl_mesh.scale = Vector3(0.1, 0.1, 0.1)
	var tween = get_tree().create_tween()
	if tween:
		tween.tween_property(expl_mesh, "scale", Vector3(5.0, 5.0, 5.0), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): if is_instance_valid(expl_mesh): expl_mesh.queue_free())
	
	queue_free()
