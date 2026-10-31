extends MultiMeshInstance3D
## Props that give when a cart hits them and settle again, without being knocked flying:
##   - flags on spring bases (feather and chequered flags): a cart drives through, the flag bends over
##     away from it and wobbles back upright, and the cart loses a little speed; with `deflect` it is also
##     thrown off to the side, and with `boing` the pole boings;
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
## Flags: a cart that runs into the pole is thrown off to the side it hit it on (m/s sideways per m/s of
## its speed, at most `deflect_max`), with a little hop so its tyres don't grip it straight back.
@export var deflect := 0.0
@export var deflect_max := 9.0
## Flags: a spring's boing as the pole whips over (synthesized once, `_boing_stream`).
@export var boing := false

const BOING_PLAYERS := 3
static var _boing_stream: AudioStreamWAV
var _boing_players: Array[AudioStreamPlayer3D] = []
var _boing_next := 0

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
	if boing:
		if _boing_stream == null:
			_boing_stream = _make_boing()
		for k in range(BOING_PLAYERS):
			var pl := AudioStreamPlayer3D.new()
			pl.stream = _boing_stream
			pl.bus = &"SFX"
			pl.unit_size = 7.0
			pl.max_distance = 70.0
			add_child(pl)
			_boing_players.append(pl)


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
				var authority: bool = cart.has_method("has_physics_authority") and cart.has_physics_authority()
				if drag > 0.0 and authority:
					cart.linear_velocity *= 1.0 - drag
				if deflect > 0.0 and authority:
					_throw_aside(cart, global_transform.basis * Vector3(dx, 0.0, dz))
				if boing and into > 1.5:
					_play_boing(global_transform * (foot + Vector3(0, 1.5, 0)), into)
			else:
				# Held over while the cart is still in it.
				_tip_vel[i] += dir * into * tip_per_speed * spring * delta * 4.0
				_active[i] = true
	for i in _active.keys():
		_step(i, delta)


## Throws `cart` off the pole, sideways to its travel, toward the side its middle passed (`off`: from the
## pole's foot to the cart, flat).
func _throw_aside(cart: RigidBody3D, off: Vector3) -> void:
	var v := cart.linear_velocity
	var hv := Vector3(v.x, 0.0, v.z)
	var speed := hv.length()
	if speed < 3.0:
		return
	var fwd := hv / speed
	var side := Vector3(-fwd.z, 0.0, fwd.x)
	var sgn := signf(side.dot(off))
	if sgn == 0.0:
		sgn = 1.0 if randf() < 0.5 else -1.0
	var push := minf(speed * deflect, deflect_max)
	cart.linear_velocity = v + side * (sgn * push) + Vector3.UP * minf(push * 0.35, 3.0)


func _play_boing(at: Vector3, speed: float) -> void:
	if _boing_players.is_empty():
		return
	var pl := _boing_players[_boing_next]
	_boing_next = (_boing_next + 1) % _boing_players.size()
	pl.global_position = at
	pl.pitch_scale = randf_range(0.85, 1.2)
	pl.volume_db = lerpf(-14.0, -3.0, clampf(speed / 25.0, 0.0, 1.0))
	pl.play()


## A spring doorstop's boing: a low tone that wobbles in pitch as the spring sways and dies away, over a
## brief metallic ping. 0.8s, made once.
static func _make_boing() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.8)
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := 0.0
	var ph2 := 0.0
	for i in range(n):
		var t := float(i) / rate
		var f := 185.0 * (1.0 + 0.32 * sin(TAU * 7.5 * t) * exp(-2.2 * t)) * (1.0 + 0.25 * exp(-30.0 * t))
		ph += TAU * f / rate
		ph2 += TAU * f * 2.76 / rate
		var env := (1.0 - exp(-t * 400.0)) * exp(-4.2 * t)
		var sample := sin(ph) * 0.75 + sin(ph * 2.0) * 0.18 * exp(-6.0 * t) + sin(ph2) * 0.3 * exp(-14.0 * t)
		data.encode_s16(i * 2, int(clampf(sample * env * 0.8, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w


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
