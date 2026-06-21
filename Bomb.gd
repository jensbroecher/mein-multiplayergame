extends RigidBody3D

const BOMB_EXPLOSION_SOUNDS = [
	preload("res://sounds/bomb_explosion_#2-1781728320398.wav"),
	preload("res://sounds/bomb_explosion_#4-1781728322907.wav"),
	preload("res://sounds/bomb_explosion_with__#1-1781728361227.wav"),
	preload("res://sounds/bomb_explosion_with__#3-1781728366899.wav"),
	preload("res://sounds/bomb_explosion_with__#4-1781728370769.wav")
]

const BOMB_FIZZLE_SOUNDS = [
	preload("res://sounds/tnt_fizzle_#3-1781732688592.wav"),
	preload("res://sounds/tnt_fizzle_#4-1781732701868.wav")
]

const FIRE_PARTICLE_TEXTURE = preload("res://materials/fire_particle.png")

@onready var area = $Area3D
@onready var visuals = $Visuals
@onready var explosion_particles = $ExplosionParticles
@onready var smoke_particles = $SmokeParticles
@onready var fire_sprite_particles = $FireSpriteParticles
@onready var fire_sprite_particles_2 = $FireSpriteParticles2
@export var owner_id: int

var pulse_time = 0.0
var lifetime = 5.0           # Explodes after 5 seconds
var owner_safety_timer = 1.0 # Owner immune for the first second
var is_exploding = false

var fizzle_player: AudioStreamPlayer3D = null
var spark_particles: CPUParticles3D = null

func _ready():
	add_to_group("bombs")
	area.body_entered.connect(_on_body_entered)
	
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		freeze = true
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	else:
		# Freeze after 2 seconds so it settles on the road
		get_tree().create_timer(2.0).timeout.connect(func(): 
			if is_instance_valid(self): 
				freeze = true
				freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
				var limit = deg_to_rad(15.0)
				var target_rot = Vector3(
					clamp(global_rotation.x, -limit, limit),
					global_rotation.y,
					clamp(global_rotation.z, -limit, limit)
				)
				var tween = create_tween()
				if tween:
					tween.tween_property(self, "global_rotation", target_rot, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		)

	_setup_sparks()
	_play_fizzle_sound()

func _play_fizzle_sound():
	fizzle_player = AudioStreamPlayer3D.new()
	var sound_stream = BOMB_FIZZLE_SOUNDS[randi() % BOMB_FIZZLE_SOUNDS.size()]
	fizzle_player.stream = sound_stream
	fizzle_player.max_distance = 60.0
	fizzle_player.unit_size = 5.0
	add_child(fizzle_player)
	fizzle_player.play()
	fizzle_player.finished.connect(_on_fizzle_finished)

func _on_fizzle_finished():
	if not is_exploding and is_instance_valid(fizzle_player):
		var current_stream = fizzle_player.stream
		var next_stream = BOMB_FIZZLE_SOUNDS[0] if current_stream == BOMB_FIZZLE_SOUNDS[1] else BOMB_FIZZLE_SOUNDS[1]
		fizzle_player.stream = next_stream
		fizzle_player.play()

func _setup_sparks():
	spark_particles = CPUParticles3D.new()
	spark_particles.name = "FuseSparks"
	spark_particles.position = Vector3(0.0, 0.47, 0.0) # Aligns with the yellow fuse mesh
	
	spark_particles.amount = 25
	spark_particles.lifetime = 0.4
	spark_particles.explosiveness = 0.0
	spark_particles.randomness = 1.0
	
	spark_particles.direction = Vector3(0, 1, 0)
	spark_particles.spread = 75.0
	spark_particles.initial_velocity_min = 2.0
	spark_particles.initial_velocity_max = 5.0
	spark_particles.gravity = Vector3(0, -9.8, 0)
	
	var gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 0.5, 1.0),
		Color(1.0, 0.6, 0.0, 0.9),
		Color(0.8, 0.1, 0.0, 0.6),
		Color(0.2, 0.0, 0.0, 0.0)
	])
	spark_particles.color_ramp = gradient
	
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	spark_particles.scale_amount_curve = curve
	
	var draw_mat = StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.billboard_mode = StandardMaterial3D.BILLBOARD_PARTICLES
	draw_mat.billboard_keep_scale = true
	draw_mat.albedo_texture = FIRE_PARTICLE_TEXTURE
	
	# Try to duplicate the working material from the scene node if possible
	var source_particles = get_node_or_null("FireSpriteParticles")
	if source_particles and source_particles.draw_pass_1:
		var source_mat = source_particles.draw_pass_1.material
		if source_mat is StandardMaterial3D:
			draw_mat = source_mat.duplicate()
	
	var quad_mesh = QuadMesh.new()
	quad_mesh.material = draw_mat
	quad_mesh.size = Vector2(0.5, 0.5) # Increased size to accommodate the soft fire_particle texture alpha fade
	spark_particles.mesh = quad_mesh
	
	# Explicitly assign material override on the particle system as well
	spark_particles.material_override = draw_mat
	
	visuals.add_child(spark_particles)
	spark_particles.emitting = true

func _process(delta):
	if is_exploding: return
	# Pulse speed and size urgency increases as countdown nears zero
	var urgency = clamp(1.0 - (lifetime / 5.0), 0.0, 1.0)
	pulse_time += delta * (5.0 + urgency * 15.0)
	var s = 1.0 + sin(pulse_time) * (0.1 + urgency * 0.2)
	visuals.scale = Vector3(s, s, s)
	
	# Fuse glows brighter as it gets close
	var fuse = get_node_or_null("Visuals/Fuse")
	if fuse and fuse.get_surface_override_material(0) == null:
		var mat = fuse.mesh.material as StandardMaterial3D
		if mat:
			mat.emission_energy_multiplier = 2.0 + urgency * 8.0
			
	# Update sparks speed and velocity scale based on urgency
	if is_instance_valid(spark_particles):
		spark_particles.speed_scale = 1.0 + urgency * 1.5
		spark_particles.initial_velocity_min = 2.0 + urgency * 3.0
		spark_particles.initial_velocity_max = 5.0 + urgency * 5.0

func _physics_process(delta):
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server(): return
	if is_exploding: return
	
	if owner_safety_timer > 0.0:
		owner_safety_timer -= delta
	
	lifetime -= delta
	if lifetime <= 0.0:
		_explode()

func _on_body_entered(body):
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server(): return
	if is_exploding: return
	
	if body.is_in_group("player_carts"):
		if body.name.to_int() == owner_id and owner_safety_timer > 0.0:
			return
		_explode()

func _explode():
	if is_exploding: return
	is_exploding = true
	
	# Server-side blast radius check
	if multiplayer.multiplayer_peer == null or multiplayer.is_server():
		var blast_radius = 8.0
		var players = get_tree().get_nodes_in_group("player_carts")
		for p in players:
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
							p.apply_blast_impulse(impulse)
					else:
						p.apply_central_impulse(impulse)
					
	if multiplayer.multiplayer_peer != null:
		_explode_rpc.rpc()
	else:
		_explode_rpc()

@rpc("authority", "call_local", "reliable")
func _explode_rpc():
	is_exploding = true
	
	if is_instance_valid(fizzle_player):
		fizzle_player.stop()
		fizzle_player.queue_free()
	if is_instance_valid(spark_particles):
		spark_particles.emitting = false
		spark_particles.queue_free()
		
	# Disable collisions immediately
	var col = get_node_or_null("CollisionShape3D")
	if col: col.disabled = true
	var area_col = get_node_or_null("Area3D/CollisionShape3D")
	if area_col: area_col.disabled = true
	
	# CRITICAL: reparent particles to scene root BEFORE freeing the bomb.
	# top_level=true only affects transform, NOT lifetime — children still die with parent.
	var scene_root = get_tree().current_scene
	var expl_pos = global_position
	
	# Play a random bomb explosion sound
	var sound_stream = BOMB_EXPLOSION_SOUNDS[randi() % BOMB_EXPLOSION_SOUNDS.size()]
	if sound_stream:
		var ap = AudioStreamPlayer3D.new()
		ap.stream = sound_stream
		ap.max_distance = 80.0
		ap.unit_size = 10.0
		scene_root.add_child(ap)
		ap.global_position = expl_pos
		ap.play()
		get_tree().create_timer(sound_stream.get_length() + 0.5).timeout.connect(ap.queue_free)
	
	# Create spherical explosion visual
	var expl_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	expl_mesh.mesh = sphere
	
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.5, 0.1, 0.8) # Vibrant orange/fire
	expl_mesh.material_override = mat
	
	scene_root.add_child(expl_mesh)
	expl_mesh.global_position = expl_pos
	expl_mesh.scale = Vector3(0.1, 0.1, 0.1)
	
	var tween = get_tree().create_tween()
	if tween:
		var t1 = tween.tween_property(expl_mesh, "scale", Vector3(8.0, 8.0, 8.0), 0.45)
		if t1:
			t1.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
		var t2 = tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.45)
		if t2:
			t2.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			
		tween.finished.connect(func(): if is_instance_valid(expl_mesh): expl_mesh.queue_free())
	
	if is_instance_valid(explosion_particles):
		var ep = explosion_particles
		remove_child(ep)
		scene_root.add_child(ep)
		ep.global_position = expl_pos
		ep.emitting = true
		get_tree().create_timer(ep.lifetime + 0.5).timeout.connect(
			func(): if is_instance_valid(ep): ep.queue_free()
		)
	
	if is_instance_valid(smoke_particles):
		var sp = smoke_particles
		remove_child(sp)
		scene_root.add_child(sp)
		sp.global_position = expl_pos
		sp.emitting = true
		get_tree().create_timer(sp.lifetime + 0.5).timeout.connect(
			func(): if is_instance_valid(sp): sp.queue_free()
		)
	
	if is_instance_valid(fire_sprite_particles):
		var fsp = fire_sprite_particles
		remove_child(fsp)
		scene_root.add_child(fsp)
		fsp.global_position = expl_pos
		fsp.emitting = true
		get_tree().create_timer(fsp.lifetime + 0.5).timeout.connect(
			func(): if is_instance_valid(fsp): fsp.queue_free()
		)

	if is_instance_valid(fire_sprite_particles_2):
		var fsp2 = fire_sprite_particles_2
		remove_child(fsp2)
		scene_root.add_child(fsp2)
		fsp2.global_position = expl_pos
		fsp2.emitting = true
		get_tree().create_timer(fsp2.lifetime + 0.5).timeout.connect(
			func(): if is_instance_valid(fsp2): fsp2.queue_free()
		)
	
	queue_free()
