extends MultiMeshInstance3D
## Props that give when a cart hits them and settle again, without being knocked flying:
##   - flags on spring bases (feather and chequered flags): a cart drives through, the flag bends over
##     away from it and wobbles back upright, and the cart loses a little speed;
##   - tyre stacks: the wall's own colliders still stop the cart; the stacks it hits are shoved a little
##     (and stay shoved, up to `max_shove` from where they stood) and rock back onto their feet.
## One MultiMesh per design. Each prop is a tip about its foot (a damped spring) and, for stacks, a
## slide; only props that are moving are written back to the MultiMesh. Carts' speeds are taken from
## how far they moved, so remote carts count too. Like KnockableProps.gd, it's local scenery: each peer
## animates its own, and nothing is synced. The level stores `rest`, since a MultiMesh can't be read
## back on the dummy renderer that generators run on.

## Where each prop stands (also its MultiMesh transform at rest).
@export var rest: Array[Transform3D] = []
## A cart touches a prop when its centre comes within `reach` of the prop's foot (flat), between
## the foot and `height` above it.
@export var reach := 1.6
@export var height := 4.0
## How much a hit tips it (radians per m/s of the cart's speed toward it), and how far it can go.
@export var tip_per_speed := 0.05
@export var max_tip := 1.1
## The tip's spring: natural frequency (rad/s) and damping ratio.
@export var spring := 8.0
@export var damping := 0.2
## Stacks: how far a hit shoves the foot (m per m/s), how far from where it stood it can end up, and
## how quickly the slide stops (1/s).
@export var shove_per_speed := 0.0
@export var max_shove := 0.0
@export var slide_friction := 5.0
## The share of its speed a cart loses driving through one (flags).
@export var drag := 0.0

var _tip: PackedVector2Array      # lean (x, z) in radians
var _tip_vel: PackedVector2Array
var _shove: PackedVector2Array
var _shove_vel: PackedVector2Array
var _active: Dictionary = {}       # prop index -> true while it moves
var _touching: Dictionary = {}     # Vector2i(prop, cart id) -> true while a cart is in it
var _last_pos: Dictionary = {}     # cart instance id -> position last physics frame
var _bounds: AABB


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var n := rest.size()
	_tip.resize(n)
	_tip_vel.resize(n)
	_shove.resize(n)
	_shove_vel.resize(n)
	if n > 0:
		_bounds = AABB(rest[0].origin, Vector3.ZERO)
		for t in rest:
			_bounds = _bounds.expand(t.origin)
		_bounds = _bounds.grow(reach + height)
		custom_aabb = AABB(_bounds.position - global_position, _bounds.size)


func _physics_process(delta: float) -> void:
	if rest.is_empty() or delta <= 0.0:
		return
	for c in get_tree().get_nodes_in_group("player_carts"):
		var cart := c as RigidBody3D
		if cart == null:
			continue
		var id := cart.get_instance_id()
		var p := cart.global_position
		var last: Vector3 = _last_pos.get(id, p)
		_last_pos[id] = p
		if not _bounds.has_point(p):
			continue
		var vel := (p - last) / delta
		vel.y = 0.0
		if vel.length() > 80.0:
			continue   # a respawn or teleport, not driving
		var local := global_transform.affine_inverse() * p
		for i in range(rest.size()):
			var foot := rest[i].origin + Vector3(_shove[i].x, 0.0, _shove[i].y)
			var dx := local.x - foot.x
			var dz := local.z - foot.z
			var key := Vector2i(i, id)
			var inside := dx * dx + dz * dz < reach * reach and local.y > foot.y - 1.0 and local.y < foot.y + height
			if not inside:
				_touching.erase(key)
				continue
			# Pushed away from the cart, harder the faster it comes at the prop.
			var away := Vector2(-dx, -dz)
			var into := maxf(Vector2(vel.x, vel.z).dot(away.normalized()) if away.length_squared() > 1e-4 else vel.length(), 0.0)
			var dir := Vector2(vel.x, vel.z).normalized() if vel.length() > 0.5 else away.normalized()
			if not _touching.has(key):
				_touching[key] = true
				_tip_vel[i] += dir * into * tip_per_speed * spring
				_shove_vel[i] += dir * into * shove_per_speed * slide_friction
				_active[i] = true
				if drag > 0.0 and cart.has_method("has_physics_authority") and cart.has_physics_authority():
					cart.linear_velocity *= 1.0 - drag
			else:
				# Held over while the cart is still in it.
				_tip_vel[i] += dir * into * tip_per_speed * spring * delta * 4.0
				_active[i] = true
	for i in _active.keys():
		_step(i, delta)


func _step(i: int, delta: float) -> void:
	var t := _tip[i]
	var v := _tip_vel[i]
	# A damped spring back upright.
	v += (-spring * spring * t - 2.0 * damping * spring * v) * delta
	t += v * delta
	if t.length() > max_tip:
		t = t.normalized() * max_tip
		v -= t.normalized() * maxf(v.dot(t.normalized()), 0.0)
	_tip[i] = t
	_tip_vel[i] = v
	var s := _shove[i]
	var sv := _shove_vel[i] * exp(-slide_friction * delta)
	s += sv * delta
	if s.length() > max_shove:
		s = s.normalized() * max_shove
		sv = Vector2.ZERO
	_shove[i] = s
	_shove_vel[i] = sv
	var xf := rest[i]
	var basis := xf.basis
	if t.length() > 1e-4:
		var lean := Vector3(t.x, 0.0, t.y)
		basis = Basis(Vector3.UP.cross(lean.normalized()).normalized(), t.length()) * basis
	xf = Transform3D(basis, xf.origin + Vector3(s.x, 0.0, s.y))
	multimesh.set_instance_transform(i, xf)
	if t.length() < 0.002 and v.length() < 0.01 and sv.length() < 0.01:
		_active.erase(i)
