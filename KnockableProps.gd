extends MultiMeshInstance3D
## Loose props carts can shove out of the way: beach loungers, cool boxes, parasols.
##
## Drawn as one MultiMesh. At runtime each prop gets a rigid body made of `boxes`, frozen where it
## stands. A cart that comes within RELEASE_RADIUS faster than `push_speed` frees it, so the hit
## knocks it away and costs the cart the momentum it hands over (a lounger weighs a tenth of a cart). A slower cart finds it frozen and stops against it, as against anything solid.
## The MultiMesh follows the bodies that move. The level stores only `prop_transforms`: the dummy
## renderer used to generate levels can't be read back from a MultiMesh.
##
## Frozen, a prop is on layer 1 like any wall: Jolt's static bodies don't look for contacts themselves,
## so on a layer outside the carts' mask a slow cart drove straight through it. Knocked loose, it moves
## to its own layer, which carts still collide with (its mask has layer 1) but AI obstacle rays and
## the carts' ground probes don't see. Like KnockablePoles.gd, they're local scenery: nothing is
## synced over the network.

const PROP_LAYER := 1 << 4
const BONK := preload("res://sounds/crate_crash.mp3")

@export var prop_transforms: Array[Transform3D] = []
## Collision boxes in the prop's frame: [centre, size] pairs.
@export var boxes: Array = []
@export var prop_mass := 120.0
## Sliding friction on the sand: low, so a shoved prop skids and tumbles clear instead of dragging
## against the cart.
@export var prop_friction := 0.35
@export var push_speed := 9.0
@export var release_radius := 5.0
## Height of the centre of mass above the prop's origin, or below zero to work it out from the shapes.
## Parasols keep theirs in the weighted base so they stand until hit.
@export var centre_of_mass_y := -1.0

var _bodies: Array[RigidBody3D] = []
var _state: PackedByteArray = PackedByteArray()   # 0 frozen, 1 released, 2 knocked (sound played)
var _bonk: AudioStreamPlayer3D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("knockable_props")
	var shapes: Array = []
	for b in boxes:
		var shape := BoxShape3D.new()
		shape.size = b[1]
		shapes.append([b[0], shape])
	for i in range(prop_transforms.size()):
		var body := RigidBody3D.new()
		body.name = "Prop_%d" % i
		body.add_to_group("knockable_props")
		body.collision_layer = 1 | PROP_LAYER
		body.collision_mask = 1 | PROP_LAYER
		if centre_of_mass_y >= 0.0:
			body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
			body.center_of_mass = Vector3(0.0, centre_of_mass_y, 0.0)
		body.mass = prop_mass
		var pm := PhysicsMaterial.new()
		pm.friction = prop_friction
		pm.bounce = 0.15
		body.physics_material_override = pm
		body.continuous_cd = true
		body.linear_damp = 0.4
		body.angular_damp = 1.5
		body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		body.freeze = true
		for s in shapes:
			var cs := CollisionShape3D.new()
			cs.shape = s[1]
			cs.position = s[0]
			body.add_child(cs)
		body.transform = prop_transforms[i]
		# Internal: built fresh on every load, never saved into the level.
		add_child(body, false, Node.INTERNAL_MODE_BACK)
		_bodies.append(body)
	_state.resize(_bodies.size())
	_state.fill(0)
	multimesh.instance_count = prop_transforms.size()
	for i in range(prop_transforms.size()):
		multimesh.set_instance_transform(i, prop_transforms[i])
	_bonk = AudioStreamPlayer3D.new()
	_bonk.stream = BONK
	_bonk.bus = &"SFX"
	_bonk.volume_db = -10.0
	_bonk.unit_size = 8.0
	_bonk.max_distance = 70.0
	add_child(_bonk, false, Node.INTERNAL_MODE_BACK)


func _physics_process(_delta: float) -> void:
	var carts: Array = []
	for c in get_tree().get_nodes_in_group("player_carts"):
		var rb := c as RigidBody3D
		if rb:
			carts.append([rb.global_position, rb.linear_velocity.length()])
	var r2 := release_radius * release_radius
	for i in range(_bodies.size()):
		var b: RigidBody3D = _bodies[i]
		if _state[i] == 0:
			var o: Vector3 = b.global_position
			for c in carts:
				if (c[0] as Vector3).distance_squared_to(o) < r2 and float(c[1]) > push_speed:
					b.freeze = false
					b.collision_layer = PROP_LAYER
					_state[i] = 1
					break
			continue
		if _state[i] == 1 and b.linear_velocity.length() > 2.0:
			_state[i] = 2
			_bonk.global_position = b.global_position
			_bonk.pitch_scale = randf_range(0.85, 1.15)
			_bonk.play()
		if b.sleeping:
			continue
		if b.global_position.y < -40.0:
			b.freeze = true
			continue
		multimesh.set_instance_transform(i, b.transform)
