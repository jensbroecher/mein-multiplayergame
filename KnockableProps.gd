extends MultiMeshInstance3D

const CartWeight = preload("res://CartWeight.gd")
## Loose props carts can shove out of the way: beach loungers, cool boxes, parasols, sand toys.
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
## Knocked loose, a prop sounds as what it is (Sound, `bonk_sound`, by default from the node's name):
## a wooden crash for loungers, a hollow plastic tok-tok-tok tumbling away for cones, cool boxes and sand
## toys, a canvas whump and a pole's ping for parasols. The two made ones are synthesised once
## (_synth). They carry like a cart's knock (unit_size 20): at -10dB and unit_size 8 they were lost
## under the engine from the chase camera.

const PROP_LAYER := 1 << 4
const BONK := preload("res://sounds/crate_crash.mp3")
enum Sound { CRATE, PLASTIC, PARASOL }
## Name fragments that pick a sound when bonk_sound is -1.
const PLASTIC_NAMES := ["cone", "coolbox", "bucket", "spade", "swimring"]

static var _synth := {}

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
## The knock (Sound): -1 picks it from the node's name.
@export var bonk_sound := -1

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
	var kind := _sound_kind()
	_bonk.stream = BONK if kind == Sound.CRATE else _synth_sound(kind)
	_bonk.bus = &"SFX"
	_bonk.volume_db = 0.0 if kind == Sound.CRATE else -2.0
	_bonk.unit_size = 20.0
	_bonk.max_distance = 140.0
	add_child(_bonk, false, Node.INTERNAL_MODE_BACK)


func _physics_process(_delta: float) -> void:
	var carts: Array = []
	for c in get_tree().get_nodes_in_group("player_carts"):
		var rb := c as RigidBody3D
		if rb:
			carts.append([rb.global_position, rb.linear_velocity.length(), CartWeight.push_share(rb)])
	var r2 := release_radius * release_radius
	for i in range(_bodies.size()):
		var b: RigidBody3D = _bodies[i]
		if _state[i] == 0:
			var o: Vector3 = b.global_position
			for c in carts:
				# A heavy car frees it at a lower speed (CartWeight); the contact itself is physics, by the masses.
				if (c[0] as Vector3).distance_squared_to(o) < r2 and float(c[1]) > push_speed / float(c[2]):
					b.freeze = false
					b.collision_layer = PROP_LAYER
					_state[i] = 1
					break
			continue
		if _state[i] == 1 and b.linear_velocity.length() > 2.0:
			_state[i] = 2
			_bonk.global_position = b.global_position
			_bonk.pitch_scale = randf_range(0.85, 1.15)
			# Louder the harder it was hit.
			_bonk.volume_db = (0.0 if _bonk.stream == BONK else -2.0) + clampf((b.linear_velocity.length() - 8.0) * 0.25, -6.0, 3.0)
			_bonk.play()
		if b.sleeping:
			continue
		if b.global_position.y < -40.0:
			b.freeze = true
			continue
		multimesh.set_instance_transform(i, b.transform)


func _sound_kind() -> int:
	if bonk_sound >= 0:
		return bonk_sound
	var n := String(name).to_lower()
	for w in PLASTIC_NAMES:
		if n.contains(w):
			return Sound.PLASTIC
	if n.contains("parasol"):
		return Sound.PARASOL
	return Sound.CRATE


## A knock made once per kind: struck hollow plastic (modes of a thin shell, a click, then two smaller
## bounces as it tumbles), or a parasol (its canopy's whump, the pole's ring, the thud as it lands).
static func _synth_sound(kind: int) -> AudioStreamWAV:
	if _synth.has(kind):
		return _synth[kind]
	var rate := 22050
	# Hits: [time, amplitude, modes [[Hz, decay s, amplitude]], click decay, click amplitude, noise low-pass].
	var hits: Array
	var length: float
	if kind == Sound.PARASOL:
		length = 0.6
		hits = [[0.0, 1.0, [[95.0, 0.07, 0.5]], 0.09, 0.9, 0.08],
			[0.04, 0.6, [[1870.0, 0.16, 0.5], [4730.0, 0.07, 0.25], [2960.0, 0.1, 0.2]], 0.002, 0.2, 0.9],
			[0.3, 0.55, [[85.0, 0.06, 0.8], [240.0, 0.03, 0.3]], 0.03, 0.6, 0.15]]
	else:
		length = 0.5
		var modes := [[390.0, 0.045, 0.7], [930.0, 0.026, 0.5], [1680.0, 0.016, 0.35], [2750.0, 0.01, 0.2]]
		hits = [[0.0, 1.0, modes, 0.004, 0.8, 0.7], [0.15, 0.45, modes, 0.003, 0.5, 0.7], [0.26, 0.22, modes, 0.003, 0.4, 0.7]]
	var n := int(rate * length)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31 + kind
	for h in hits:
		var i0 := int(float(h[0]) * rate)
		var amp: float = h[1]
		var lp := 0.0
		var detune := rng.randf_range(0.96, 1.05)
		for i in range(i0, n):
			var t := float(i - i0) / rate
			var v := 0.0
			for m in h[2]:
				v += sin(TAU * float(m[0]) * detune * t) * exp(-t / float(m[1])) * float(m[2])
			lp += (rng.randf_range(-1.0, 1.0) - lp) * float(h[5])
			v += lp * float(h[4]) * exp(-t / float(h[3])) * minf(t / 0.004, 1.0)
			buf[i] += v * amp * minf(t / 0.0008, 1.0)
	var peak := 0.001
	for v in buf:
		peak = maxf(peak, absf(v))
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(buf[i] / peak * 0.9, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	_synth[kind] = wav
	return wav
