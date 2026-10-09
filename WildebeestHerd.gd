extends Node3D
## The great migration crossing the road on Mara Crossing: a stream of galloping wildebeest that
## runs across the track in waves, so a racer either times the gap or threads the herd.
##
## The herd moves on a fixed schedule: every animal's place is a function of the wall clock
## alone, so every machine in a LAN race sees the same herd at the same moment without any
## network traffic. (Machines' clocks agree to well under the time it takes an animal to cover
## its own length.)
##
## A cart that runs into an animal is knocked aside and loses most of its speed. That is checked
## here, for the carts this machine simulates, rather than left to the physics engine: a cart at
## 40 m/s meeting a solid body stops dead or gets launched. The animals still get kinematic
## bodies, but only on ANIMAL_LAYER, which carts do not collide with and the AI's obstacle rays
## do see, so bots steer round them.
##
## The animals are instances of `animal_scene`, a rigged model with a looping run cycle (the
## wildebeest in models/animals/wildebeest), scaled up to the RC carts' world. Each plays the run
## cycle at the pace that keeps its hooves with the ground.
##
## The generator stores the stream, the ground under it (rows of heights across the stream) and
## the dust emitters. The animals, their bodies and the audio are built on load.

const ANIMAL_LAYER := 1 << 2
## The cart's collision sphere, added to an animal's half extents for the bump test.
const CART_REACH := 1.0
const HIT_COOLDOWN := 0.9
## Speed a cart keeps after hitting an animal, and how hard it is shoved.
const HIT_KEEP := 0.38
const HIT_SHOVE := 7.0
const HIT_HOP := 4.0
## Metres at either end of the stream over which animals fade in and out of view.
const EDGE_FADE := 18.0
## Model half width, half length and back height at scale 1 (the wildebeest model's body; its
## legs and horns stick out a little further).
const MODEL_HALF_X := 0.15
const MODEL_HALF_Z := 0.5
const MODEL_BACK_Y := 0.62

@export var path_start := Vector3.ZERO
@export var path_end := Vector3(0, 0, -300)
@export var half_width := 11.0
@export var speed := 10.0
@export var clusters := 3
@export var per_cluster := 14
@export var cluster_length := 36.0
## Distance along the stream after which the pattern repeats; at least the stream's length.
@export var loop_length := 330.0
@export var rng_seed := 1977
## A rigged animal facing +Z with its hooves at y = 0, and its looping run animation.
@export var animal_scene: PackedScene
@export var run_animation := &"Run"
@export var animal_scale := 5.0
## Ground a hoof covers per run cycle at scale 1, so the gait keeps pace with `speed`.
@export var run_stride := 1.0
## Two animals' centres stay at least this far apart (x across, y along the stream).
@export var spacing := Vector2(2.8, 7.0)
## Ground under the stream: `ground_cols` heights across it per row, one row every
## `ground_step` metres along it. Column 0 is at -half_width - ground_step.
@export var ground_rows := PackedFloat32Array()
@export var ground_cols := 0
@export var ground_step := 2.0
@export var rumble_stream: AudioStream

var _dir := Vector3.FORWARD
var _right := Vector3.RIGHT
var _length := 1.0
var _count := 0
var _s_off := PackedFloat32Array()
var _lat := PackedFloat32Array()
var _wob_amp := PackedFloat32Array()
## Each cluster weaves as one, so neighbours keep their spacing.
var _wob_phase := PackedFloat32Array()
var _gait := PackedFloat32Array()
var _scale := PackedFloat32Array()
## Local knock-aside offsets: animals hit by a cart stagger out of line for a moment.
var _knock: Array[Vector3] = []
var _xforms: Array[Transform3D] = []
var _visible := PackedByteArray()
var _bodies: Array[AnimatableBody3D] = []
var _animals: Array[Node3D] = []
var _players: Array[AnimationPlayer] = []
var _hit_half := Vector3.ONE
var _dust: Array[GPUParticles3D] = []
var _rumble: Array[AudioStreamPlayer3D] = []
var _cooldown := {}
## Carts knocked by an animal since load (read by scratch/mara_test.gd).
var bump_count := 0


func _ready() -> void:
	var d := path_end - path_start
	d.y = 0.0
	_length = maxf(d.length(), 1.0)
	_dir = d / _length
	_right = Vector3(-_dir.z, 0.0, _dir.x)
	_count = clusters * per_cluster
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var lat_room: float = half_width - MODEL_HALF_X * animal_scale - 1.4
	for k in range(clusters):
		var phase: float = rng.randf() * TAU
		var placed: Array[Vector2] = []
		for j in range(per_cluster):
			# Denser toward the middle of each cluster, ragged at its ends; never on top of a
			# neighbour (the closest of a few tries wins if the cluster is crowded).
			var best := Vector2.ZERO
			var best_d := -1.0
			for attempt in range(40):
				var u: float = (rng.randf() + rng.randf()) * 0.5
				var c := Vector2(rng.randf_range(-1.0, 1.0) * lat_room, u * cluster_length)
				var nearest := 1e9
				for q in placed:
					nearest = minf(nearest, ((c - q) / spacing).length())
				if nearest > best_d:
					best_d = nearest
					best = c
				if nearest >= 1.0:
					break
			placed.append(best)
			_s_off.append(best.y)
			_lat.append(best.x)
			_wob_amp.append(rng.randf_range(0.9, 1.25))
			_wob_phase.append(phase)
			_gait.append(rng.randf())
			_scale.append(rng.randf_range(0.9, 1.08))
			_knock.append(Vector3.ZERO)
			_xforms.append(Transform3D())
	_visible.resize(_count)
	# Marked visible so the first update parks every animal that starts off the stream.
	_visible.fill(1)
	_hit_half = Vector3(MODEL_HALF_X, MODEL_BACK_Y, MODEL_HALF_Z) * animal_scale + Vector3(CART_REACH, 1.0, CART_REACH)
	for c in get_children():
		if c is GPUParticles3D:
			_dust.append(c)
	if Engine.is_editor_hint():
		return
	if animal_scene:
		for i in range(_count):
			var a: Node3D = animal_scene.instantiate()
			add_child(a, false, Node.INTERNAL_MODE_BACK)
			_animals.append(a)
			var players: Array[Node] = a.find_children("*", "AnimationPlayer", true, false)
			var ap: AnimationPlayer = players[0] if not players.is_empty() else null
			_players.append(ap)
			if ap and ap.has_animation(run_animation):
				ap.play(run_animation)
				var anim_len: float = ap.get_animation(run_animation).length
				ap.seek(_gait[i] * anim_len, true)
				# Cycles per second that keep the hooves with the ground, times the cycle's length.
				ap.speed_scale = speed / maxf(run_stride * animal_scale * _scale[i], 0.01) * anim_len
	var shape := CapsuleShape3D.new()
	shape.radius = MODEL_HALF_X * animal_scale * 1.2
	shape.height = MODEL_HALF_Z * animal_scale * 2.0
	for i in range(_count):
		var b := AnimatableBody3D.new()
		b.sync_to_physics = false
		b.collision_layer = ANIMAL_LAYER
		b.collision_mask = 0
		var cs := CollisionShape3D.new()
		cs.shape = shape
		# Capsule along the body (Z), at shoulder height.
		cs.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, MODEL_BACK_Y * animal_scale * 0.7, 0))
		b.add_child(cs)
		add_child(b, false, Node.INTERNAL_MODE_BACK)
		_bodies.append(b)
	if rumble_stream:
		for k in range(clusters):
			var ap := AudioStreamPlayer3D.new()
			ap.stream = rumble_stream
			ap.bus = &"SFX"
			ap.volume_db = 4.0
			ap.unit_size = 22.0
			ap.max_distance = 220.0
			ap.autoplay = false
			add_child(ap, false, Node.INTERNAL_MODE_BACK)
			_rumble.append(ap)
	_update_herd(0.0)


## Seconds on a clock every machine shares.
func _clock() -> float:
	return fmod(Time.get_unix_time_from_system(), 86400.0)


## Ground height at (along, across) the stream, from the baked rows.
func _ground(s: float, lat: float) -> float:
	if ground_cols < 2 or ground_rows.is_empty():
		return path_start.y
	var rows: int = ground_rows.size() / ground_cols
	var fs: float = clampf(s / ground_step, 0.0, float(rows - 1) - 0.001)
	var fl: float = clampf((lat + half_width + ground_step) / ground_step, 0.0, float(ground_cols - 1) - 0.001)
	var r0: int = int(fs)
	var c0: int = int(fl)
	var ts: float = fs - r0
	var tl: float = fl - c0
	var h00: float = ground_rows[r0 * ground_cols + c0]
	var h01: float = ground_rows[r0 * ground_cols + c0 + 1]
	var h10: float = ground_rows[(r0 + 1) * ground_cols + c0]
	var h11: float = ground_rows[(r0 + 1) * ground_cols + c0 + 1]
	return lerpf(lerpf(h00, h01, tl), lerpf(h10, h11, tl), ts)


func _physics_process(delta: float) -> void:
	_update_herd(delta)
	if Engine.is_editor_hint():
		return
	_check_carts()


func _update_herd(delta: float) -> void:
	var t: float = _clock()
	var gap: float = loop_length / float(maxi(clusters, 1))
	var centre_sum: Array[Vector3] = []
	var centre_n: Array[int] = []
	for k in range(clusters):
		centre_sum.append(Vector3.ZERO)
		centre_n.append(0)
	for i in range(_count):
		var k: int = floori(float(i) / float(per_cluster))
		var s: float = fposmod(t * speed + float(k) * gap + _s_off[i], loop_length)
		var fade: float = smoothstep(0.0, EDGE_FADE, s) * smoothstep(_length, _length - EDGE_FADE, s)
		if s > _length or fade <= 0.001:
			if _visible[i] == 1:
				_visible[i] = 0
				if i < _animals.size():
					_animals[i].visible = false
					if _players[i]:
						_players[i].pause()
				if i < _bodies.size():
					_bodies[i].global_transform = Transform3D(Basis(), path_start + Vector3.DOWN * 50.0)
			continue
		if _visible[i] == 0 and i < _animals.size():
			_animals[i].visible = true
			if _players[i]:
				_players[i].play()
		_visible[i] = 1
		# Each cluster weaves a little across the stream as it runs.
		var w: float = sin(t * 0.7 + _wob_phase[i]) * _wob_amp[i]
		var lat: float = clampf(_lat[i] + w, -half_width + 1.0, half_width - 1.0)
		var dlat: float = cos(t * 0.7 + _wob_phase[i]) * _wob_amp[i] * 0.7 / maxf(speed, 0.1)
		if _knock[i].length_squared() > 0.0001:
			_knock[i] = _knock[i].lerp(Vector3.ZERO, clampf(delta * 1.6, 0.0, 1.0))
		var p: Vector3 = path_start + _dir * s + _right * lat + _knock[i]
		p.y = _ground(s, lat + _knock[i].dot(_right))
		var heading: Vector3 = (_dir + _right * dlat).normalized()
		# Pitch with the slope under it.
		var ahead: float = _ground(s + 1.5, lat) - _ground(s - 1.5, lat)
		var fwd: Vector3 = (heading + Vector3.UP * ahead / 3.0).normalized()
		# The model faces +Z.
		var basis := Basis.looking_at(fwd, Vector3.UP, true).scaled(Vector3.ONE * animal_scale * _scale[i] * maxf(fade, 0.05))
		var xf := Transform3D(basis, p - Vector3.UP * (1.0 - fade) * MODEL_BACK_Y * animal_scale)
		_xforms[i] = xf
		if i < _animals.size():
			_animals[i].global_transform = xf
		if i < _bodies.size():
			_bodies[i].global_transform = Transform3D(Basis.looking_at(heading, Vector3.UP), p)
		centre_sum[k] += p
		centre_n[k] += 1
	for k in range(clusters):
		var on: bool = float(centre_n[k]) > float(per_cluster) / 3.0
		var c: Vector3 = centre_sum[k] / float(maxi(centre_n[k], 1))
		if k < _dust.size():
			_dust[k].emitting = on
			if on:
				_dust[k].global_position = c - _dir * 6.0
		if k < _rumble.size():
			if on:
				_rumble[k].global_position = c
				if not _rumble[k].playing:
					_rumble[k].play(randf() * 2.0)
			elif _rumble[k].playing:
				_rumble[k].stop()


func _check_carts() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	for node in get_tree().get_nodes_in_group("player_carts"):
		var cart := node as RigidBody3D
		if cart == null or not is_instance_valid(cart):
			continue
		if cart.has_method("has_physics_authority") and not cart.has_physics_authority():
			continue
		var cp: Vector3 = cart.global_position
		# Cheap reject: carts away from the stream.
		var rel: Vector3 = cp - path_start
		var along: float = rel.dot(_dir)
		if along < -4.0 or along > _length + 4.0 or absf(rel.dot(_right)) > half_width + 4.0:
			continue
		var id: int = cart.get_instance_id()
		if now < float(_cooldown.get(id, 0.0)):
			continue
		for i in range(_count):
			if _visible[i] == 0:
				continue
			var xf: Transform3D = _xforms[i]
			var local: Vector3 = xf.basis.orthonormalized().inverse() * (cp - xf.origin)
			if absf(local.x) > _hit_half.x or absf(local.z) > _hit_half.z or local.y < -1.5 or local.y > _hit_half.y:
				continue
			_bump(cart, i, xf)
			_cooldown[id] = now + HIT_COOLDOWN
			break


func _bump(cart: RigidBody3D, i: int, xf: Transform3D) -> void:
	var away: Vector3 = cart.global_position - xf.origin
	away.y = 0.0
	away = away.normalized() if away.length_squared() > 0.0001 else -_dir
	# Shoved mostly the way the herd is running, partly straight off the animal.
	var shove: Vector3 = (_dir * 0.7 + away * 0.6).normalized() * HIT_SHOVE
	var v: Vector3 = cart.linear_velocity
	var hv := Vector3(v.x, 0.0, v.z)
	cart.linear_velocity = hv * HIT_KEEP + shove + Vector3.UP * HIT_HOP
	bump_count += 1
	if cart.has_method("_play_crash_sound"):
		cart.call("_play_crash_sound")
	# The animal staggers out of line, away from the cart.
	_knock[i] = -away * 2.2
