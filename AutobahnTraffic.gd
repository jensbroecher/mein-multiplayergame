extends Node3D
## Traffic on a straight road along this node's -z (Kronburger Hütte's Autobahn viaduct, Rheinufer's A 58 and A 47):
## `meshes` (vehicles, nose toward -z) driven along `lanes` (x offsets; positive lanes run toward -z, negative ones back
## toward +z) over `length` metres, on the wall clock so every peer sees the same traffic, each vehicle at its own speed
## and spacing. A vehicle shrinks to nothing over `fade` metres at either end. One MultiMesh per vehicle kind; nothing is
## drawn on a headless server.
##
## With `kills` (Rheinufer's A 47 westbound, which the race may take against the traffic) touching a vehicle destroys a
## cart, as CrossTraffic's do: no collision bodies (a cart closing at 70 m/s moves more than a metre a step), each cart
## this peer drives is tested against every vehicle's box (from its mesh's AABB), swept over the tick. Without it the
## vehicles are scenery and carts pass through them.

@export var meshes: Array[Mesh] = []
@export var lanes := PackedFloat32Array([5.0, -5.0])
@export var length := 1000.0
@export var per_lane := 7
@export var speeds := Vector2(26.0, 42.0)
@export var fade := 40.0
## Optional: the road's height (over this node's y) every `height_step` metres along its length (Rheinufer's A 47 rises
## over the Rhine; Kronburger Hütte's viaduct is level and leaves it empty). Vehicles follow it and pitch with it.
@export var heights := PackedFloat32Array()
@export var height_step := 10.0
@export var kills := false
## A fraction of the cart's radius that has to reach into a vehicle's box to count as a hit.
@export var hit_share := 0.85
## Seconds into the day; set to hold the traffic still for tests and shots (negative: the wall clock).
@export var clock_override := -1.0
@export_group("Sound")
## Engine loops (no Doppler of their own) and, per sound, its measured RMS in dBFS: each is levelled to `engine_level`
## at `sound_unit` metres. `kind_engine` picks a vehicle kind's loop (by its index in `meshes`; -1 or missing: none).
@export var engine_sounds: Array[AudioStream] = []
@export var engine_rms := PackedFloat32Array()
@export var kind_engine := PackedInt32Array()
@export var engine_level := -20.0
## Horns (one-shots) with their loudest second's RMS, levelled to `horn_level`. A vehicle honks at a cart in its lane
## ahead of it (not every time: `honk_share`, then not again for `honk_gap` seconds), and now and then one near the
## listener honks at nothing in particular (every `ambient_honk` seconds or so).
@export var horns: Array[AudioStream] = []
@export var horn_rms := PackedFloat32Array()
@export var horn_level := -12.0
@export var honk_share := 0.55
@export var honk_gap := 14.0
@export var ambient_honk := 35.0
@export var sound_unit := 22.0
@export var sound_reach := 230.0
## How many vehicles nearest the listener are heard at once.
@export var voices := 6

signal cart_hit(cart: Node)

var _mmis: Array[MultiMeshInstance3D] = []
## Per vehicle: [kind, index in its kind, lane x, direction (+1 toward -z), speed, phase].
var _cars: Array = []
## Per kind: the mesh's AABB (the hit box).
var _boxes: Array[AABB] = []
var _headless := false
var _prev_pos := {}

## A voice: an engine loop and a horn that follow one vehicle (`car`, -1 free), pitched by the Doppler shift.
class Voice:
	var engine: AudioStreamPlayer3D
	var horn: AudioStreamPlayer3D
	var car := -1
	var pitch := 1.0
	var base_db := 0.0

var _voices: Array[Voice] = []
## Per vehicle: its pitch (a little different for each) and when it may honk next.
var _car_pitch := PackedFloat32Array()
var _honk_at := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()
var _listener_prev := Vector3.ZERO
var _listener_vel := Vector3.ZERO
var _listener_ok := false
var _next_ambient := 0.0
const SOUND_C := 343.0


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	if meshes.is_empty():
		set_process(false)
		set_physics_process(false)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 4747
	var counts: Array[int] = []
	counts.resize(meshes.size())
	counts.fill(0)
	for li in range(lanes.size()):
		var lane_speed: float = rng.randf_range(speeds.x, speeds.y) * (1.12 if absf(lanes[li]) < 8.0 else 0.92)
		for k in range(per_lane):
			var kind: int = rng.randi_range(0, meshes.size() - 1)
			var phase: float = (float(k) + rng.randf_range(-0.3, 0.3)) / float(per_lane) * length
			# One speed for the whole lane: each at its own speed, faster ones drove into the ones ahead.
			_cars.append([kind, counts[kind], lanes[li], 1.0 if lanes[li] > 0.0 else -1.0, lane_speed, phase])
			counts[kind] += 1
	for m in meshes:
		_boxes.append(m.get_aabb() if m != null else AABB(Vector3(-1.2, 0, -2.5), Vector3(2.4, 2.0, 5.0)))
	set_physics_process(kills)
	if _headless:
		set_process(false)
		return
	_setup_sound()
	for i in range(meshes.size()):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[i]
		mm.instance_count = counts[i]
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		# The vehicles move: DressingColliders would freeze a collider (and its wobble, drawing the car) where each stood at load.
		mmi.set_meta(&"skip_dressing_colliders", true)
		var top := 12.0
		for h in heights:
			top = maxf(top, h + 12.0)
		mmi.custom_aabb = AABB(Vector3(-20, -2, -length - 20), Vector3(40, top, length + 40))
		add_child(mmi, false, Node.INTERNAL_MODE_BACK)
		_mmis.append(mmi)


func _clock() -> float:
	if clock_override >= 0.0:
		return clock_override
	return fposmod(Time.get_unix_time_from_system(), 86400.0)


## A vehicle's place at time t: [its transform in this node's frame, the distance from the road's start (0..length)].
func _place(c: Array, t: float) -> Array:
	var speed: float = c[4]
	var s: float = fposmod(t * speed + float(c[5]), length)
	var dir: float = c[3]
	var z: float = -s if dir > 0.0 else -(length - s)
	var sc: float = clampf(minf(s, length - s) / fade, 0.0, 1.0)
	var basis := Basis() if dir > 0.0 else Basis(Vector3.UP, PI)
	var y := 0.0
	if heights.size() > 1:
		var d: float = -z
		y = _height(d)
		var slope: float = (_height(d + 2.0) - _height(d - 2.0)) / 4.0
		basis = basis * Basis(Vector3.RIGHT, atan(slope) * dir)
	return [Transform3D(basis.scaled(Vector3.ONE * maxf(sc, 0.001)), Vector3(c[2], y, z)), sc]


func _process(delta: float) -> void:
	var t: float = _clock()
	var placed: Array = []
	for c in _cars:
		var pl: Array = _place(c, t)
		_mmis[c[0]].multimesh.set_instance_transform(c[1], pl[0])
		placed.append(pl)
	if not _voices.is_empty():
		_update_sound(placed, delta)


# ======================================================================================
#  Sound: engines with the Doppler shift, horns
# ======================================================================================

func _setup_sound() -> void:
	if engine_sounds.is_empty() and horns.is_empty():
		return
	_rng.seed = 9191
	_car_pitch.resize(_cars.size())
	_honk_at.resize(_cars.size())
	for i in _cars.size():
		_car_pitch[i] = _rng.randf_range(0.9, 1.1)
		_honk_at[i] = 0.0
	for v in voices:
		var vo := Voice.new()
		vo.engine = _player("Engine%d" % v)
		vo.horn = _player("Horn%d" % v)
		_voices.append(vo)
	_next_ambient = _rng.randf_range(0.5, 1.5) * ambient_honk


func _player(n: String) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = n
	p.unit_size = sound_unit
	p.max_distance = sound_reach
	p.bus = &"Master"
	p.attenuation_filter_cutoff_hz = 9000.0
	p.attenuation_filter_db = -8.0
	add_child(p, false, Node.INTERNAL_MODE_BACK)
	return p


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _update_sound(placed: Array, delta: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var lp: Vector3 = cam.global_position
	if _listener_ok and delta > 0.0:
		var v: Vector3 = (lp - _listener_prev) / delta
		# A cut or a respawn is no speed.
		if v.length() < 150.0:
			_listener_vel = _listener_vel.lerp(v, clampf(delta * 6.0, 0.0, 1.0))
		else:
			_listener_vel = Vector3.ZERO
	_listener_prev = lp
	_listener_ok = true
	var gx: Transform3D = global_transform
	var fwd: Vector3 = -gx.basis.z.normalized()
	# The nearest vehicles within reach.
	var near: Array = []
	var reach2: float = sound_reach * sound_reach
	for i in _cars.size():
		if float(placed[i][1]) < 0.3:
			continue
		var wp: Vector3 = gx * (placed[i][0] as Transform3D).origin
		var d2: float = wp.distance_squared_to(lp)
		if d2 < reach2:
			near.append([d2, i, wp])
	near.sort_custom(func(a, b): return a[0] < b[0])
	if near.size() > _voices.size():
		near.resize(_voices.size())
	var wanted := {}
	for n in near:
		wanted[n[1]] = n[2]
	# Keep each voice on its vehicle while it stays among the nearest; free the rest, then give the new ones a voice.
	for vo in _voices:
		if vo.car >= 0 and not wanted.has(vo.car):
			vo.car = -1
			vo.engine.stop()
	for n in near:
		var i: int = n[1]
		var has := false
		for vo in _voices:
			if vo.car == i:
				has = true
		if has:
			continue
		for vo in _voices:
			if vo.car < 0:
				_bind(vo, i)
				break
	var now: float = _now()
	var carts: Array = get_tree().get_nodes_in_group("player_carts")
	for vo in _voices:
		if vo.car < 0:
			continue
		var c: Array = _cars[vo.car]
		var wp2: Vector3 = wanted[vo.car]
		var at: Vector3 = wp2 + Vector3(0, 1.2, 0)
		vo.engine.global_position = at
		vo.horn.global_position = at
		var vel: Vector3 = fwd * (float(c[3]) * float(c[4]))
		var u: Vector3 = lp - at
		var dist: float = u.length()
		u = u / maxf(dist, 0.01)
		var dop: float = clampf((SOUND_C - _listener_vel.dot(u)) / maxf(SOUND_C - vel.dot(u), 1.0), 0.55, 1.8)
		var target: float = _car_pitch[vo.car] * (0.9 + float(c[4]) / 300.0) * dop
		vo.pitch = lerpf(vo.pitch, target, clampf(delta * 10.0, 0.0, 1.0))
		vo.engine.pitch_scale = vo.pitch
		vo.horn.pitch_scale = clampf(dop, 0.7, 1.4)
		_maybe_honk(vo, c, at, vel, carts, now)
	if now > _next_ambient and not near.is_empty():
		_next_ambient = now + _rng.randf_range(0.6, 1.6) * ambient_honk
		var pick: Voice = _voices[_rng.randi_range(0, _voices.size() - 1)]
		if pick.car >= 0 and now > _honk_at[pick.car]:
			_honk(pick, now)


func _bind(vo: Voice, i: int) -> void:
	vo.car = i
	vo.pitch = _car_pitch[i]
	var kind: int = _cars[i][0]
	var e: int = kind_engine[kind] if kind < kind_engine.size() else -1
	if e < 0 or e >= engine_sounds.size() or engine_sounds[e] == null:
		return
	vo.engine.stream = engine_sounds[e]
	var rms: float = engine_rms[e] if e < engine_rms.size() else -20.0
	vo.engine.volume_db = engine_level - rms
	vo.engine.play(_rng.randf_range(0.0, maxf(engine_sounds[e].get_length() - 0.1, 0.0)))


## Honks at a cart this peer drives ahead of it in its lane (closing on it), now and then.
func _maybe_honk(vo: Voice, c: Array, at: Vector3, vel: Vector3, carts: Array, now: float) -> void:
	if now < _honk_at[vo.car] or vo.horn.playing or horns.is_empty():
		return
	var dir: Vector3 = vel.normalized()
	for cn in carts:
		var cart := cn as Node3D
		if cart == null or not is_instance_valid(cart):
			continue
		if cart.has_method("has_physics_authority") and not cart.has_physics_authority():
			continue
		var rel: Vector3 = cart.global_position - at
		var ahead: float = rel.dot(dir)
		var side: float = (rel - dir * ahead).length()
		# In its lane (not beside it on the hard shoulder) and in front of it.
		if ahead > 8.0 and ahead < 75.0 and side < 2.4:
			_honk_at[vo.car] = now + honk_gap
			if _rng.randf() < honk_share:
				_honk(vo, now)
			return


func _honk(vo: Voice, now: float) -> void:
	var h: int = _rng.randi_range(0, horns.size() - 1)
	if horns[h] == null:
		return
	vo.horn.stream = horns[h]
	vo.horn.volume_db = horn_level - (horn_rms[h] if h < horn_rms.size() else -15.0)
	vo.horn.play()
	_honk_at[vo.car] = now + honk_gap


func _height(d: float) -> float:
	var f: float = clampf(d / height_step, 0.0, float(heights.size() - 1))
	var i: int = mini(int(f), heights.size() - 2)
	return lerpf(heights[i], heights[i + 1], f - float(i))


# ======================================================================================
#  Hits (kills)
# ======================================================================================

func _physics_process(_delta: float) -> void:
	var carts := get_tree().get_nodes_in_group("player_carts")
	if carts.is_empty():
		return
	var wide: float = 4.0
	for l in lanes:
		wide = maxf(wide, absf(l) + 4.0)
	var inv: Transform3D = global_transform.affine_inverse()
	var t: float = -1.0
	var placed: Array = []
	for cn in carts:
		var cart := cn as Node3D
		if cart == null or not is_instance_valid(cart):
			continue
		var id := cart.get_instance_id()
		var pos: Vector3 = inv * cart.global_position
		var prev: Vector3 = _prev_pos.get(id, pos)
		_prev_pos[id] = pos
		# A respawn's jump is no sweep.
		if prev.distance_to(pos) > 12.0:
			prev = pos
		if absf(pos.x) > wide + 3.0 and absf(prev.x) > wide + 3.0:
			continue
		if pos.z > 5.0 or pos.z < -length - 5.0:
			continue
		if not _cart_can_die(cart):
			continue
		if t < 0.0:
			t = _clock()
			for c in _cars:
				placed.append(_place(c, t))
		var r: float = float(cart.get("collision_radius")) * hit_share
		for k in 5:
			var p: Vector3 = prev.lerp(pos, k / 4.0)
			var hit: int = _vehicle_at(p, r, placed)
			if hit >= 0:
				_kill(cart)
				break


## The index of a vehicle whose box (in its own frame, scaled as drawn) the sphere at p with radius r reaches into, or -1.
func _vehicle_at(p: Vector3, r: float, placed: Array) -> int:
	for i in _cars.size():
		var c: Array = _cars[i]
		if absf(p.x - float(c[2])) > 4.0 + r:
			continue
		var sc: float = placed[i][1]
		if sc < 0.5:
			continue
		var xf: Transform3D = placed[i][0]
		var ab: AABB = _boxes[c[0]]
		var q: Vector3 = xf.affine_inverse() * p
		var lo: Vector3 = ab.position
		var hi: Vector3 = ab.end
		var d := Vector3(maxf(maxf(lo.x - q.x, q.x - hi.x), 0.0), maxf(maxf(lo.y - 0.6 - q.y, q.y - hi.y), 0.0), maxf(maxf(lo.z - q.z, q.z - hi.z), 0.0))
		if d.length() * sc < r:
			return i
	return -1


func _cart_can_die(cart: Node) -> bool:
	if not cart.has_method("has_physics_authority") or not cart.has_physics_authority():
		return false
	for flag in ["is_exploding", "is_finished_race", "is_teleporting", "is_drowned"]:
		if cart.get(flag):
			return false
	return true


func _kill(cart: Node) -> void:
	print("AutobahnTraffic %s: a vehicle hit cart %s" % [name, cart.name])
	cart_hit.emit(cart)
	if multiplayer.multiplayer_peer != null:
		cart.explode_rpc.rpc(0, "traffic")
	else:
		cart.explode(0, "traffic")
	_prev_pos.erase(cart.get_instance_id())
