extends MultiMeshInstance3D
## Loose chunks of broken ice that carts can knock about (the rubble round the Thin Ice holes on
## Northlight Caverns).
##
## Drawn as one MultiMesh like KnockablePoles.gd, with a light rigid body per chunk built at runtime,
## frozen until a cart comes within RELEASE_RADIUS. The chunks are scaled unevenly and a rigid body
## can't carry a scale, so each body gets its own convex hull with the chunk's size baked into it,
## and the MultiMesh draws body transform * scale. The level stores only `chunk_transforms` and the
## unit hull `chunk_points`.
##
## A chunk is mostly lower than the cart's sphere is round, so in a plain contact the sphere rolls
## over it and presses it into the ice. A cart passing within KICK_REACH of one kicks it instead: on
## at about the cart's speed, a little out to the side and up, spinning. The cart's speed is read
## from how far it moved, so remote carts (interpolated, not simulated here) kick chunks as well.
##
## Same layer as the poles: carts hit them, AI obstacle rays and mask-1 queries don't see them.
## Chunks also knock each other. Local scenery, not synced over the network.

const CHUNK_LAYER := 1 << 4
## Cart sphere (1.35m) + a chunk (up to 0.55m) + one physics step of travel at top speed.
const RELEASE_RADIUS := 3.6
## Kilograms per cubic metre of hull: porous, broken lake ice, light enough to scatter.
const DENSITY := 260.0
## How close (plan distance, centre to chunk edge) a cart's centre has to pass to kick a chunk: its
## sphere's 1.35m and a bit for the body.
const KICK_REACH := 1.5
## Slowest a cart can be going and still kick a chunk.
const KICK_MIN_SPEED := 3.0
const BONK := preload("res://sounds/freesound_community-bonk-46000.mp3")

@export var chunk_transforms: Array[Transform3D] = []
## The unit chunk's convex hull, before each chunk's scale.
@export var chunk_points := PackedVector3Array()
## Below this a chunk has gone into a hole: it stops there, out of sight under the water.
@export var sink_y := -10.0

var _bodies: Array[RigidBody3D] = []
var _scales: Array[Basis] = []
var _released := PackedByteArray()
## Half the plan size of each chunk.
var _radii := PackedFloat32Array()
## Each cart's position last physics frame, by instance id, for its speed.
var _cart_last := {}
var _bonk: AudioStreamPlayer3D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for i in range(chunk_transforms.size()):
		var t: Transform3D = chunk_transforms[i]
		var s: Vector3 = t.basis.get_scale()
		var pts := PackedVector3Array()
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		for p in chunk_points:
			var q: Vector3 = p * s
			pts.append(q)
			lo = lo.min(q)
			hi = hi.max(q)
		var shape := ConvexPolygonShape3D.new()
		shape.points = pts
		var size: Vector3 = hi - lo
		var b := RigidBody3D.new()
		b.name = "IceChunk_%d" % i
		b.collision_layer = CHUNK_LAYER
		b.collision_mask = 1 | CHUNK_LAYER
		# About half the bounding box is ice.
		b.mass = clampf(DENSITY * size.x * size.y * size.z * 0.5, 3.0, 40.0)
		b.continuous_cd = true
		b.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		b.freeze = true
		var cs := CollisionShape3D.new()
		cs.shape = shape
		b.add_child(cs)
		b.transform = Transform3D(t.basis.orthonormalized(), t.origin)
		# Internal: built fresh on every load, never saved into the level.
		add_child(b, false, Node.INTERNAL_MODE_BACK)
		_bodies.append(b)
		_scales.append(Basis.from_scale(s))
		_radii.append(0.5 * maxf(size.x, size.z))
	_released.resize(_bodies.size())
	_released.fill(0)
	multimesh.instance_count = chunk_transforms.size()
	for i in range(chunk_transforms.size()):
		multimesh.set_instance_transform(i, chunk_transforms[i])
	_bonk = AudioStreamPlayer3D.new()
	_bonk.stream = BONK
	_bonk.bus = &"SFX"
	_bonk.volume_db = -12.0
	_bonk.unit_size = 5.0
	_bonk.max_distance = 50.0
	add_child(_bonk, false, Node.INTERNAL_MODE_BACK)


func _physics_process(delta: float) -> void:
	var carts: Array[Vector3] = []
	var cart_vel: Array[Vector3] = []
	var now := {}
	for c in get_tree().get_nodes_in_group("player_carts"):
		var p: Vector3 = (c as Node3D).global_position
		var id: int = c.get_instance_id()
		carts.append(p)
		# A cart that teleported (respawn) shows a huge speed for one frame: ignore anything silly.
		var v: Vector3 = (p - _cart_last.get(id, p)) / maxf(delta, 1e-4)
		cart_vel.append(v if v.length() < 80.0 else Vector3.ZERO)
		now[id] = p
	_cart_last = now
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
		_kick(i, carts, cart_vel)
		if _released[i] == 1 and b.linear_velocity.length() > 2.5:
			_released[i] = 2
			_bonk.global_position = b.global_position
			_bonk.pitch_scale = randf_range(1.5, 2.0)
			_bonk.play()
		if b.freeze or b.sleeping:
			continue
		if b.global_position.y < sink_y:
			b.freeze = true
		multimesh.set_instance_transform(i, Transform3D(b.transform.basis * _scales[i], b.transform.origin))


## Sends chunk `i` flying if a cart is driving through it.
func _kick(i: int, carts: Array[Vector3], cart_vel: Array[Vector3]) -> void:
	var b: RigidBody3D = _bodies[i]
	var o: Vector3 = b.global_position
	for k in range(carts.size()):
		var v: Vector3 = cart_vel[k]
		var flat := Vector3(v.x, 0.0, v.z)
		var speed: float = flat.length()
		if speed < KICK_MIN_SPEED:
			continue
		var rel := Vector3(o.x - carts[k].x, 0.0, o.z - carts[k].z)
		if rel.length() > KICK_REACH + _radii[i] or absf(o.y - carts[k].y) > 2.0:
			continue
		# Already going faster than the cart that reached it: it was kicked a frame ago.
		if Vector3(b.linear_velocity.x, 0.0, b.linear_velocity.z).length() >= speed * 0.8:
			continue
		var side: Vector3 = rel - flat / speed * rel.dot(flat / speed)
		side = side.normalized() if side.length() > 0.01 else Vector3.ZERO
		b.sleeping = false
		b.linear_velocity = flat * randf_range(0.85, 1.15) + side * speed * randf_range(0.15, 0.35) \
				+ Vector3.UP * (1.5 + speed * randf_range(0.08, 0.16))
		b.angular_velocity = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * speed * 0.5
		return
