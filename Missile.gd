extends CharacterBody3D

@export var speed = 80.0
@export var owner_id: int
@export var is_guided: bool = false
@onready var area = $Area3D
@onready var visuals = $Visuals

var target: Node3D = null
var lifetime = 5.0
var search_timer = 0.0

func _ready():
	add_to_group("missiles")
	area.body_entered.connect(_on_body_entered)
	
	if is_guided:
		lifetime = 8.0 # Guided missiles last longer
		_find_target()
		# Change visual for guided
		var mesh_inst = $Visuals/Mesh
		if mesh_inst:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.6, 0, 1) # Purple
			mat.emission_enabled = true
			mat.emission = Color(0.4, 0, 0.8)
			mesh_inst.set_surface_override_material(0, mat)

func _find_target():
	var nearest_dist = 50.0 # Search radius
	var players = get_tree().get_nodes_in_group("player_carts")
	for p in players:
		if p.name.to_int() == owner_id: continue
		var dist = global_position.distance_to(p.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			target = p

func _physics_process(delta):
	if multiplayer.is_server():
		if is_guided:
			search_timer += delta
			if search_timer > 0.5: # Re-evaluate target every 0.5s
				_find_target()
				search_timer = 0.0
				
			if target and is_instance_valid(target):
				var target_pos = target.global_position
				var dir = (target_pos - global_position).normalized()
				var target_basis = Basis.looking_at(-dir, Vector3.UP)
				# Smoothly rotate towards target
				global_basis = global_basis.slerp(target_basis, 5.0 * delta).orthonormalized()
		
		var forward = -transform.basis.z
		velocity = forward * speed
		move_and_slide()
		
		lifetime -= delta
		if lifetime <= 0:
			_explode()
			
	# Everyone else syncs position/rotation (MultiplayerSynchronizer should handle it)

func _on_body_entered(body):
	if not multiplayer.is_server(): return
	
	if body.is_in_group("player_carts"):
		if body.name.to_int() != owner_id:
			if body.has_method("on_hit"):
				body.on_hit()
				_explode()
	elif body is StaticBody3D or body is CSGShape3D or body is GridMap:
		# Hit wall/terrain
		_explode()

func _explode():
	# Emit particles or play sound via RPC?
	# For now just queue_free
	queue_free()
