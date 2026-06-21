extends CharacterBody3D

const MISSILE_EXPLOSION_SOUNDS = [
	preload("res://sounds/missile_explosion_wi_#1-1781728385875.wav"),
	preload("res://sounds/missile_explosion_wi_#2-1781728388962.wav"),
	preload("res://sounds/missile_explosion_wi_#3-1781728394157.wav"),
	preload("res://sounds/missile_explosion_wi_#4-1781728398285.wav")
]

const FLIGHT_SOUND = preload("res://sounds/774270__thelittlecrow__rocket-launch-boost-and-burning-version-b.wav")

@export var speed: float = 33.0   # Starts slightly above car top speed
const SPEED_MAX: float = 50.0     # Gradually accelerates to this
const SPEED_ACCEL: float = 8.0    # m/s² acceleration
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
var lifetime = 5.0
var search_timer = 0.0
var spawn_safety_timer = 0.3
var start_position: Vector3 = Vector3.ZERO
@export var max_range: float = 75.0
var homing_delay: float = 0.5

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
	
	start_position = global_position
	if is_guided:
		lifetime = 8.0
		max_range = 100.0
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
		lifetime = 5.0
		max_range = 75.0
		
	_find_target()
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		sync_position = global_position
		sync_rotation = global_rotation

func _find_target():
	var nearest_dist = 500.0
	var best_target: Node3D = null
	var players = get_tree().get_nodes_in_group("player_carts")
	var forward = -global_transform.basis.z
	for p in players:
		if p.name.to_int() == owner_id: continue
		var dir_to_target = (p.global_position - global_position).normalized()
		# Only lock target if it is in front of the missile (not behind)
		if forward.dot(dir_to_target) > 0.1:
			var dist = global_position.distance_to(p.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				best_target = p
	target = best_target

func _physics_process(delta):
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
		if search_timer > 0.5:
			_find_target()
			search_timer = 0.0

		if homing_delay > 0.0:
			homing_delay -= delta
		else:
			if target and is_instance_valid(target):
				var dir = (target.global_position - global_position).normalized()
				var forward = -global_transform.basis.z
				if forward.dot(dir) > -0.2:
					if abs(dir.dot(Vector3.UP)) < 0.99:
						var target_basis = Basis.looking_at(dir, Vector3.UP)
						var turn_speed = 3.5 if is_guided else 0.3
						global_basis = global_basis.slerp(target_basis, turn_speed * delta).orthonormalized()
				else:
					# Target went too far behind, break the lock
					target = null

		# Gradually accelerate from start speed to max
		speed = min(speed + SPEED_ACCEL * delta, SPEED_MAX)

		var forward = -transform.basis.z
		velocity = forward * speed
		move_and_slide()
		
		sync_position = global_position
		sync_rotation = global_rotation


func _process(delta):
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
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server(): return
	if body.is_in_group("player_carts"):
		# Trigger explosion. We do NOT check for owner_id here because if the missile directly hits any cart (including the owner if they run into it),
		# it should detonate. The blast damage loop will handle hitting any nearby carts including the owner.
		_explode()
	elif body is StaticBody3D or body is CSGShape3D or body is GridMap:
		if spawn_safety_timer <= 0.0:
			_explode()

func _explode():
	if not is_instance_valid(self): return

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
	# Disable collisions immediately on client
	var area_col = get_node_or_null("Area3D/CollisionShape3D")
	if area_col: area_col.disabled = true
	
	var scene_root = get_tree().current_scene
	var expl_pos = global_position
	
	# Play a random missile explosion sound
	var sound_stream = MISSILE_EXPLOSION_SOUNDS[randi() % MISSILE_EXPLOSION_SOUNDS.size()]
	if sound_stream:
		var ap = AudioStreamPlayer3D.new()
		ap.stream = sound_stream
		ap.max_distance = 80.0
		ap.unit_size = 10.0
		scene_root.add_child(ap)
		ap.global_position = expl_pos
		ap.play()
		get_tree().create_timer(sound_stream.get_length() + 0.5).timeout.connect(ap.queue_free)

	# Stop and detach the fire trail so it fades out naturally
	if is_instance_valid(fire_trail):
		var trail_pos = fire_trail.global_position
		remove_child(fire_trail)
		scene_root.add_child(fire_trail)
		fire_trail.global_position = trail_pos
		fire_trail.emitting = false
		get_tree().create_timer(fire_trail.lifetime + 0.2).timeout.connect(
			func(): if is_instance_valid(fire_trail): fire_trail.queue_free()
		)

	# Detach and fire explosion particles so they outlive the missile node
	for ps in [explosion_particles, smoke_particles, fire_sprite_particles, fire_sprite_particles_2]:
		if is_instance_valid(ps):
			var ps_pos = global_position
			remove_child(ps)
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
	scene_root.add_child(expl_mesh)
	expl_mesh.global_position = expl_pos
	expl_mesh.scale = Vector3(0.1, 0.1, 0.1)
	var tween = get_tree().create_tween()
	if tween:
		tween.tween_property(expl_mesh, "scale", Vector3(5.0, 5.0, 5.0), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): if is_instance_valid(expl_mesh): expl_mesh.queue_free())
	
	queue_free()
