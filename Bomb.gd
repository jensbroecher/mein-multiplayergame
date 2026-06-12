extends RigidBody3D

@onready var area = $Area3D
@onready var visuals = $Visuals
@onready var explosion_particles = $ExplosionParticles
@onready var smoke_particles = $SmokeParticles
@export var owner_id: int

var pulse_time = 0.0
var lifetime = 5.0           # Explodes after 5 seconds
var owner_safety_timer = 1.0 # Owner immune for the first second
var is_exploding = false

func _ready():
	add_to_group("bombs")
	area.body_entered.connect(_on_body_entered)
	
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
		if body.has_method("on_hit"):
			body.on_hit()
		_explode()

func _explode():
	if is_exploding: return
	is_exploding = true
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
	
	queue_free()
