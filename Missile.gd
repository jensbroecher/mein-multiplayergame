extends CharacterBody3D

@export var speed: float = 33.0   # Starts slightly above car top speed
const SPEED_MAX: float = 50.0     # Gradually accelerates to this
const SPEED_ACCEL: float = 8.0    # m/s² acceleration
@export var owner_id: int
@export var is_guided: bool = false
@onready var area = $Area3D
@onready var visuals = $Visuals
@onready var smoke_trail = $SmokeTrail

var target: Node3D = null
var lifetime = 5.0
var search_timer = 0.0
var spawn_safety_timer = 0.3

func _ready():
	add_to_group("missiles")
	area.body_entered.connect(_on_body_entered)
	
	if is_guided:
		lifetime = 8.0
		# Purple tint for guided missiles
		var mesh_inst = get_node_or_null("Visuals/Mesh")
		if mesh_inst:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.5, 0.0, 0.9, 1)
			mat.emission_enabled = true
			mat.emission = Color(0.4, 0.0, 0.8, 1)
			mat.emission_energy_multiplier = 2.0
			mesh_inst.set_surface_override_material(0, mat)
	else:
		lifetime = 5.0
		
	_find_target()

func _find_target():
	var nearest_dist = 500.0
	var players = get_tree().get_nodes_in_group("player_carts")
	for p in players:
		if p.name.to_int() == owner_id: continue
		var dist = global_position.distance_to(p.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			target = p

func _physics_process(delta):
	# Decrement lifetime on all peers to prevent stuck/phantom projectiles if RPC is lost
	lifetime -= delta
	if lifetime <= 0:
		_explode()
		return

	if multiplayer.is_server():
		if spawn_safety_timer > 0.0:
			spawn_safety_timer -= delta

		search_timer += delta
		if search_timer > 0.5:
			_find_target()
			search_timer = 0.0

		if target and is_instance_valid(target):
			var dir = (target.global_position - global_position).normalized()
			var target_basis = Basis.looking_at(dir, Vector3.UP)
			var turn_speed = 5.0 if is_guided else 1.0
			global_basis = global_basis.slerp(target_basis, turn_speed * delta).orthonormalized()

		# Gradually accelerate from start speed to max
		speed = min(speed + SPEED_ACCEL * delta, SPEED_MAX)

		var forward = -transform.basis.z
		velocity = forward * speed
		move_and_slide()

func _on_body_entered(body):
	if not multiplayer.is_server(): return
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
	if multiplayer.is_server():
		var blast_radius = 7.0
		var players = get_tree().get_nodes_in_group("player_carts")
		for p in players:
			# Notice there is no owner exclusion, so the owner can be hit if close to the blast!
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
	# Disable collisions immediately on client
	var area_col = get_node_or_null("Area3D/CollisionShape3D")
	if area_col: area_col.disabled = true
	
	# Stop trail emitting — reparent it so it lingers in world space
	if is_instance_valid(smoke_trail):
		var scene_root = get_tree().current_scene
		var trail_pos = smoke_trail.global_position
		remove_child(smoke_trail)
		scene_root.add_child(smoke_trail)
		smoke_trail.global_position = trail_pos
		smoke_trail.emitting = false
		get_tree().create_timer(smoke_trail.lifetime + 0.2).timeout.connect(
			func(): if is_instance_valid(smoke_trail): smoke_trail.queue_free()
		)
		
	# Create spherical explosion visual (exactly like Bomb.gd)
	var scene_root = get_tree().current_scene
	var expl_pos = global_position
	
	var expl_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	expl_mesh.mesh = sphere
	
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.45, 0.05, 0.8) # Vibrant orange flame
	expl_mesh.material_override = mat
	
	scene_root.add_child(expl_mesh)
	expl_mesh.global_position = expl_pos
	expl_mesh.scale = Vector3(0.1, 0.1, 0.1)
	
	var tween = get_tree().create_tween()
	if tween:
		var t1 = tween.tween_property(expl_mesh, "scale", Vector3(7.0, 7.0, 7.0), 0.45)
		if t1:
			t1.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
		var t2 = tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.45)
		if t2:
			t2.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			
		tween.finished.connect(func(): if is_instance_valid(expl_mesh): expl_mesh.queue_free())
		
	queue_free()
