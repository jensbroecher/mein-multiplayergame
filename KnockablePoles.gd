extends MultiMeshInstance3D
## Trailside poles that carts can knock over.
##
## They are drawn as one MultiMesh, so a few hundred of them cost one draw call. At runtime each
## pole gets a light rigid body, frozen in place until a cart comes within RELEASE_RADIUS; then it
## is released so the impact knocks it over, and the MultiMesh follows the bodies that move. (Left
## free, a thin pole on a snow slope topples by itself the moment physics starts.) The level stores only `pole_transforms` (the dummy renderer used to
## generate levels cannot be read back from a MultiMesh, so the transforms are kept here as well).
##
## Poles sit on their own physics layer: carts (mask 1) still hit them because the pole's mask
## includes layer 1, but AI obstacle rays and other mask-1 queries do not see them, so a pole is
## never treated as a wall to steer around. They are local scenery: each player knocks over their
## own copy, nothing is synced over the network.

const POLE_LAYER := 1 << 4
## Cart sphere (1.35m) + pole (0.15m) + one physics step of travel at top speed.
const RELEASE_RADIUS := 3.5
const BONK := preload("res://sounds/freesound_community-bonk-46000.mp3")

@export var pole_transforms: Array[Transform3D] = []
@export var pole_height := 2.4
@export var pole_mass := 4.0

var _bodies: Array[RigidBody3D] = []
var _released: PackedByteArray = PackedByteArray()
var _bonk: AudioStreamPlayer3D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("knockable_props")
	var shape := CylinderShape3D.new()
	# A little fatter than the drawn pole, so a fast cart cannot slip past between physics steps.
	shape.radius = 0.15
	shape.height = pole_height - 0.25
	for i in range(pole_transforms.size()):
		var b := RigidBody3D.new()
		b.name = "Pole_%d" % i
		b.add_to_group("knockable_props")
		b.collision_layer = POLE_LAYER
		b.collision_mask = 1
		b.mass = pole_mass
		b.continuous_cd = true
		b.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		b.freeze = true
		var cs := CollisionShape3D.new()
		cs.shape = shape
		# The drawn pole is sunk 10cm into the snow; the collider starts at ground level.
		cs.position.y = 0.125
		b.add_child(cs)
		b.transform = pole_transforms[i]
		# Internal: built fresh on every load, never saved into the level (this also runs while the
		# generator assembles the scene).
		add_child(b, false, Node.INTERNAL_MODE_BACK)
		_bodies.append(b)
	_released.resize(_bodies.size())
	_released.fill(0)
	multimesh.instance_count = pole_transforms.size()
	for i in range(pole_transforms.size()):
		multimesh.set_instance_transform(i, pole_transforms[i])
	_bonk = AudioStreamPlayer3D.new()
	_bonk.stream = BONK
	_bonk.bus = &"SFX"
	_bonk.volume_db = -8.0
	_bonk.unit_size = 6.0
	_bonk.max_distance = 60.0
	add_child(_bonk, false, Node.INTERNAL_MODE_BACK)


func _physics_process(_delta: float) -> void:
	var carts: Array[Vector3] = []
	for c in get_tree().get_nodes_in_group("player_carts"):
		carts.append((c as Node3D).global_position)
	for i in range(_bodies.size()):
		var b: RigidBody3D = _bodies[i]
		if _released[i] == 0:
			var o: Vector3 = b.global_position
			for p in carts:
				if p.distance_squared_to(o) < RELEASE_RADIUS * RELEASE_RADIUS:
					b.freeze = false
					_released[i] = 1
					break
			continue
		if _released[i] == 1 and b.linear_velocity.length() > 2.0:
			_released[i] = 2
			_bonk.global_position = b.global_position
			_bonk.pitch_scale = randf_range(0.9, 1.25)
			_bonk.play()
		if b.sleeping:
			continue
		# A pole knocked off a cliff is gone for good.
		if b.global_position.y < -40.0:
			b.freeze = true
			continue
		multimesh.set_instance_transform(i, b.transform)
