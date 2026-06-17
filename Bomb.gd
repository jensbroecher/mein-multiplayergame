extends RigidBody3D

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

func _ready():
	add_to_group("bombs")
	area.body_entered.connect(_on_body_entered)
	
	if not multiplayer.is_server():
		freeze = true
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	else:
		# Freeze after 2 seconds so it settles on the road
		get_tree().create_timer(2.0).timeout.connect(func(): if is_instance_valid(self): freeze = true)

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

func _physics_process(delta):
	if not multiplayer.is_server(): return
	if is_exploding: return
	
	if owner_safety_timer > 0.0:
		owner_safety_timer -= delta
	
	lifetime -= delta
	if lifetime <= 0.0:
		_explode()

func _on_body_entered(body):
	if not multiplayer.is_server(): return
	if is_exploding: return
	
	if body.is_in_group("player_carts"):
		if body.name.to_int() == owner_id and owner_safety_timer > 0.0:
			return
		_explode()

func _explode():
	if is_exploding: return
	is_exploding = true
	
	# Server-side blast radius check
	if multiplayer.is_server():
		var blast_radius = 8.0
		var players = get_tree().get_nodes_in_group("player_carts")
		for p in players:
			var dist = global_position.distance_to(p.global_position)
			if dist <= blast_radius:
				if p.has_method("on_hit"):
					var was_shielded = p.is_shielded
					p.on_hit()
					if was_shielded:
						continue
					
					var dir = (p.global_position - global_position).normalized()
					if dir.length_squared() < 0.01:
						dir = Vector3.UP
					var impulse = dir * 8.0 * p.mass + Vector3.UP * 4.0 * p.mass
					if p.has_method("apply_blast_impulse"):
						p.apply_blast_impulse.rpc_id(p.name.to_int(), impulse)
					else:
						p.apply_central_impulse(impulse)
					
	_explode_rpc.rpc()

@rpc("authority", "call_local", "reliable")
func _explode_rpc():
	is_exploding = true
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
	var bomb_sounds = [
		"res://sounds/bomb_explosion_#2-1781728320398.wav",
		"res://sounds/bomb_explosion_#4-1781728322907.wav",
		"res://sounds/bomb_explosion_with__#1-1781728361227.wav",
		"res://sounds/bomb_explosion_with__#3-1781728366899.wav",
		"res://sounds/bomb_explosion_with__#4-1781728370769.wav"
	]
	var selected_sound = bomb_sounds[randi() % bomb_sounds.size()]
	var sound_stream = load(selected_sound)
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
