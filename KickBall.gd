@tool
class_name KickBall
extends RigidBody3D

const CartWeight = preload("res://CartWeight.gd")
## A ball the carts kick about: Nyota Stadium's football (Style.FOOTBALL), Bloombay's beach balls
## (Style.BEACH). It builds its sphere and shape as internal children from STYLES, so a level stores
## only its transform, its style and its water.
##
## Carts never touch it through the physics: their 1.5m sphere would ride up over a 0.4m ball (a hop)
## and press it into the ground. Every cart gets a collision exception, and the ball looks for carts
## itself, against a box round the car's body (CAR_HALF, in the cart's own frame: the body never
## rolls). A cart closing on it kicks it off along the contact's normal at `kick` times the closing
## speed, lofted by `lift`, and the cart this peer drives loses `slow` of that closing speed: a
## football costs a head-on cart about a seventh of its speed, a beach ball hardly anything.
## Like KnockableProps.gd it is local scenery: each peer runs its own ball from every cart it sees
## (their velocity from how far they moved, so remote carts kick it too). Nothing is synced.
## On water (water_y) it floats `float_share` under and drifts by `drift` (the surf washing a beach
## ball back ashore). Lost (fallen out of the world, or left at rest away from where it started with
## no cart near for RESET_IDLE seconds, or adrift far out) it comes back to where it started.

enum Style { FOOTBALL, BEACH }

const SHADER := preload("res://kick_ball.gdshader")
const LAYER := 1 << 5
## Half extents of a car's body round the cart's origin (the sphere's centre, 0.75m over the ground):
## x across, z along; y from the ground (it reaches on down: nothing passes under) to the roof.
const CAR_HALF := Vector2(0.62, 1.12)
const CAR_Y := Vector2(-0.75, 0.55)
const RESET_IDLE := 30.0
const RESET_CLEAR := 25.0
const ADRIFT := 70.0
const KICK_GAP := 0.15

## radius (m), mass, gravity_scale, linear and angular damp, bounce, friction, kick, lift, slow,
## float_share, top speed, air drag (per metre: a beach ball slows hard in the air), rolling resistance
## (a deceleration in m/s^2 while it rolls slowly along the ground: a beach ball sits in the sand, where
## the beach's slope pulls at it with about 0.45, instead of rolling off down into the sea).
const STYLES := {
	# A size 5 football (22cm) at the stadium's scale (its people are 1.86 times life size), grown again
	# by 1.75 (0.72m across): at 0.41m it was hard to see from the chase camera and easy to miss.
	Style.FOOTBALL: {"radius": 0.36, "mass": 5.0, "gravity": 2.6, "damp": 0.45, "spin_damp": 0.6,
		"bounce": 0.62, "friction": 0.7, "kick": 1.5, "lift": 0.16, "slow": 0.1, "float": 0.5,
		"top": 62.0, "drag": 0.0, "roll": 0.25, "pitch": 1.0},
	# A 56cm beach ball at Bloombay's PROP_SCALE (1.6).
	Style.BEACH: {"radius": 0.45, "mass": 0.8, "gravity": 0.85, "damp": 0.5, "spin_damp": 0.8,
		"bounce": 0.78, "friction": 0.5, "kick": 1.25, "lift": 0.42, "slow": 0.03, "float": 0.12,
		"top": 38.0, "drag": 0.035, "roll": 0.9, "pitch": 1.0},
}

@export var style: Style = Style.FOOTBALL:
	set(v):
		style = v
		if is_inside_tree():
			_build()
## The water's surface it floats on; under -999, none.
@export var water_y := -1000.0
## Acceleration while afloat (m/s^2): the surf carrying it back to the beach.
@export var drift := Vector3.ZERO

static var _meshes := {}
static var _materials := {}
static var _sounds := {}
## The carts as this physics frame sees them, shared by every ball: [cart, position, velocity, basis].
static var _cart_frame := -1
static var _carts: Array = []
static var _cart_prev := {}

var _p: Dictionary
var _home: Transform3D
var _mesh: MeshInstance3D
var _shape: CollisionShape3D
var _sfx: AudioStreamPlayer3D
var _excepted := {}
var _last_kick := {}
var _idle := 0.0
var _g := 9.8
var _afloat := false


func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		freeze = true
		return
	add_to_group("kick_balls")
	_home = global_transform
	_g = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	collision_layer = LAYER
	collision_mask = 1 | LAYER
	continuous_cd = true
	can_sleep = true
	_sfx = AudioStreamPlayer3D.new()
	_sfx.stream = _thump(style)
	_sfx.bus = &"SFX"
	_sfx.unit_size = 6.0
	_sfx.max_distance = 90.0
	add_child(_sfx, false, Node.INTERNAL_MODE_BACK)


func _build() -> void:
	_p = STYLES[style]
	var r: float = _p["radius"]
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		add_child(_mesh, false, Node.INTERNAL_MODE_BACK)
		_shape = CollisionShape3D.new()
		add_child(_shape, false, Node.INTERNAL_MODE_BACK)
	if not _meshes.has(style):
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 2.0
		sm.radial_segments = 40
		sm.rings = 20
		_meshes[style] = sm
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("style", int(style))
		_materials[style] = mat
	_mesh.mesh = _meshes[style]
	_mesh.material_override = _materials[style]
	var shape := SphereShape3D.new()
	shape.radius = r
	_shape.shape = shape
	mass = _p["mass"]
	gravity_scale = _p["gravity"]
	linear_damp = _p["damp"]
	angular_damp = _p["spin_damp"]
	var pm := PhysicsMaterial.new()
	pm.bounce = _p["bounce"]
	pm.friction = _p["friction"]
	physics_material_override = pm


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_update_carts(delta)
	var r: float = _p["radius"]
	var pos := global_position
	var vel := linear_velocity
	var nearest := INF
	for c in _carts:
		var cart: RigidBody3D = c[0]
		if not is_instance_valid(cart):
			continue
		if not _excepted.has(cart):
			add_collision_exception_with(cart)
			_excepted[cart] = true
		var cpos: Vector3 = c[1]
		var d2 := Vector2(pos.x - cpos.x, pos.z - cpos.z).length()
		nearest = minf(nearest, d2)
		if d2 > 3.0 or absf(pos.y - cpos.y) > 3.0:
			continue
		var b: Basis = c[3]
		var local := b.inverse() * (pos - cpos)
		# The body reaches down to the ground: nothing passes under a car.
		if local.y < CAR_Y.x - 0.6:
			continue
		var closest := Vector3(clampf(local.x, -CAR_HALF.x, CAR_HALF.x), minf(local.y, CAR_Y.y),
				clampf(local.z, -CAR_HALF.y, CAR_HALF.y))
		var off := local - closest
		if off.length() >= r:
			continue
		var cvel: Vector3 = c[2]
		# The contact's normal, out of the car's body. A fast car swallows the ball's centre in one
		# frame: then it is the face the ball came in through, the one it crossed most recently going
		# by the speed it closes on each.
		var n_local: Vector3
		if off.length() > 0.01:
			n_local = off.normalized()
		else:
			n_local = _entry_face(local, b.inverse() * (vel - cvel))
		var n := (b * n_local).normalized()
		var closing := (cvel - vel).dot(n)
		var id := cart.get_instance_id()
		var now := Time.get_ticks_msec() * 0.001
		# Out of the body whatever happens, so a ball resting against a cart isn't kicked every frame.
		global_position = cpos + b * (closest + n_local * (r + 0.03))
		if closing < 0.4 or now - float(_last_kick.get(id, -10.0)) < KICK_GAP:
			continue
		_last_kick[id] = now
		_kick(cart, n, cvel, closing)
		vel = linear_velocity
	_float(delta, pos, r)
	_drag(delta)
	_watch_lost(delta, nearest)


## Of the body's sides and roof, the one a ball at `local` moving at `rel` (both in the cart's frame)
## came in through: the least time since it crossed.
func _entry_face(local: Vector3, rel: Vector3) -> Vector3:
	var best := Vector3(signf(local.x) if local.x != 0.0 else 1.0, 0.0, 0.0)
	var best_t := INF
	for f in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(0, 1, 0)]:
		var depth: float
		if f.y > 0.0:
			depth = CAR_Y.y - local.y
		elif f.x != 0.0:
			depth = CAR_HALF.x - local.x * f.x
		else:
			depth = CAR_HALF.y - local.z * f.z
		var inward := -rel.dot(f)
		if inward <= 0.05:
			continue
		var t := depth / inward
		if t < best_t:
			best_t = t
			best = f
	return best


## The ball goes off along n at `kick` times the closing speed, lofted, taking a little of the car's
## sideways speed and a spin to match; the cart this peer drives loses `slow` of the closing speed.
func _kick(cart: RigidBody3D, n: Vector3, cvel: Vector3, closing: float) -> void:
	var vel := linear_velocity
	var rel_t := (cvel - vel) - n * (cvel - vel).dot(n)
	# A heavy car kicks it further and is checked less (CartWeight).
	var push: float = CartWeight.push_share(cart)
	vel += n * closing * float(_p["kick"]) * push + rel_t * 0.25 + Vector3.UP * closing * float(_p["lift"]) * push
	var top: float = _p["top"]
	if vel.length() > top:
		vel = vel.normalized() * top
	sleeping = false
	linear_velocity = vel
	var flat := Vector3(vel.x, 0.0, vel.z)
	angular_velocity = Vector3.UP.cross(flat) / float(_p["radius"]) * 0.6 + Vector3(randf_range(-4, 4), randf_range(-6, 6), randf_range(-4, 4))
	if cart.has_method("has_physics_authority") and cart.has_physics_authority():
		var nh := Vector3(n.x, 0.0, n.z)
		if nh.length() > 0.2:
			nh = nh.normalized()
			var along := cart.linear_velocity.dot(nh)
			if along > 0.0:
				cart.linear_velocity -= nh * minf(along, closing) * float(_p["slow"]) * CartWeight.loss_share(cart)
	_sfx.volume_db = clampf(-24.0 + closing * 0.55, -24.0, -3.0)
	_sfx.pitch_scale = float(_p["pitch"]) * randf_range(0.9, 1.1)
	_sfx.play()


## Afloat: lifted by how deep it sits (weight balanced at float_share under), slowed by the water,
## carried by `drift`, bobbing on a slow swell.
func _float(delta: float, pos: Vector3, r: float) -> void:
	_afloat = false
	if water_y < -999.0:
		return
	var surface := water_y + 0.12 * sin(Time.get_ticks_msec() * 0.00084 + pos.z * 0.05)
	var sub := clampf((surface - (pos.y - r)) / (2.0 * r), 0.0, 1.0)
	if sub <= 0.0:
		return
	_afloat = true
	sleeping = false
	var weight := mass * _g * gravity_scale
	apply_central_force(Vector3.UP * weight * sub / float(_p["float"]) + drift * mass * minf(sub * 4.0, 1.0))
	var k := exp(-2.2 * delta * minf(sub * 3.0, 1.0))
	linear_velocity *= k
	angular_velocity *= k


## Air drag growing with speed (a beach ball's), on top of the linear damping; and rolling slowly along
## the ground (hardly rising or falling, not afloat), rolling resistance.
func _drag(delta: float) -> void:
	if sleeping:
		return
	var v := linear_velocity
	var drag: float = _p["drag"]
	if drag > 0.0:
		v /= 1.0 + drag * v.length() * delta
	var speed := v.length()
	if speed < 3.0 and absf(v.y) < 0.4 and speed > 0.0 and not _afloat:
		var slowed := maxf(speed - float(_p["roll"]) * delta, 0.0)
		v *= slowed / speed
		angular_velocity *= slowed / speed
	linear_velocity = v


func _watch_lost(delta: float, nearest: float) -> void:
	var pos := global_position
	if pos.y < _home.origin.y - 50.0:
		_reset()
		return
	_idle = _idle + delta if linear_velocity.length() < 0.4 or sleeping else 0.0
	var away := pos.distance_to(_home.origin)
	var afloat := water_y > -999.0 and pos.y < water_y + float(_p["radius"])
	if nearest < RESET_CLEAR:
		return
	if (_idle > RESET_IDLE and away > 4.0) or (afloat and away > ADRIFT):
		_reset()


func _reset() -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = _home
	reset_physics_interpolation()
	_idle = 0.0


## Every cart once a physics frame: its position, velocity (its own if this peer drives it, else from
## how far it moved; a respawn's jump is no velocity) and heading.
static func _refresh(tree: SceneTree, delta: float) -> void:
	_carts.clear()
	var seen := {}
	for node in tree.get_nodes_in_group("player_carts"):
		var cart := node as RigidBody3D
		if cart == null:
			continue
		var id := cart.get_instance_id()
		var pos := cart.global_position
		var vel: Vector3
		if cart.has_method("has_physics_authority") and cart.has_physics_authority():
			vel = cart.linear_velocity
		else:
			vel = (pos - _cart_prev.get(id, pos)) / maxf(delta, 0.001)
			if vel.length() > 95.0:
				vel = Vector3.ZERO
		_cart_prev[id] = pos
		seen[id] = true
		_carts.append([cart, pos, vel, cart.global_transform.basis.orthonormalized()])
	for id in _cart_prev.keys():
		if not seen.has(id):
			_cart_prev.erase(id)


func _update_carts(delta: float) -> void:
	var frame := Engine.get_physics_frames()
	if frame != _cart_frame:
		_cart_frame = frame
		_refresh(get_tree(), delta)


## The sound of a kick, made once: a football's thump (a falling low note and the leather's slap),
## a beach ball's hollow bwong.
static func _thump(s: int) -> AudioStreamWAV:
	if _sounds.has(s):
		return _sounds[s]
	var rate := 22050
	var beach := s == Style.BEACH
	var length := 0.3 if beach else 0.18
	var n := int(rate * length)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + s
	var phase := 0.0
	var phase2 := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		var v := 0.0
		if beach:
			var f := lerpf(250.0, 170.0, minf(t / 0.08, 1.0))
			phase += TAU * f / rate
			phase2 += TAU * f * 2.71 / rate
			v = (sin(phase) * 0.8 + sin(phase2) * 0.25) * exp(-t / 0.075)
			lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.3
			v += lp * 0.5 * exp(-t / 0.01)
		else:
			var f := lerpf(150.0, 62.0, minf(t / 0.06, 1.0))
			phase += TAU * f / rate
			v = sin(phase) * exp(-t / 0.04)
			lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.45
			v += lp * 0.9 * exp(-t / 0.006)
		v *= minf(t / 0.0015, 1.0)
		data.encode_s16(i * 2, int(clampf(v * 0.8, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	_sounds[s] = wav
	return wav
