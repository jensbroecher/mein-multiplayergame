extends Node3D
## The scrapyard's material handler (Quer durch Kronburg) dropping a scrap car on the road, on the wall clock so every LAN
## peer sees the same thing without syncing. This node is the slew pivot, at the machine's slew ring: it turns itself about
## its y axis. It holds the upper's mesh and the hanging node `hang` (at the stick's tip, the magnet on it), and under that
## the car (`car`, built in the hanging node's frame, its roof against the magnet).
##
## The cycle: the car hangs on the magnet out over the yard at `pile_deg` for `dwell` seconds; the upper slews to
## `centre_deg` (over the road) over `move` seconds (eased in and out), hovers `hover`, lets go: the car falls `drop` metres
## onto the road under `fall_gravity`, lies there `lie` seconds, and the magnet pulls it back up over `lift` seconds; then
## the upper slews back out. While the car lies on the road (and as it is lifted) it is solid: a box (`car_centre`,
## `car_half`, in the car's frame) on an AnimatableBody3D that follows it, on layer 1 only then. A cart the falling car
## lands on, or that meets it in the air, is destroyed (this peer's carts only), as the Ring's traffic does.
## `cover_intervals(gate)` (for HazardGate.gd) says when in the cycle the car is over the road and low enough to matter.

@export var centre_deg := 0.0
@export var pile_deg := 85.0
@export var move := 5.0
@export var dwell := 3.0
@export var hover := 0.8
@export var drop := 5.0
@export var fall_gravity := 24.0
@export var lie := 3.5
@export var lift := 1.6
@export var phase := 0.0
@export var hang: NodePath
@export var car: NodePath
## The car's box in its own frame (centre, half size), game metres.
@export var car_centre := Vector3.ZERO
@export var car_half := Vector3.ONE
## How far over the road (its height at the drop) the car still counts as low enough to hit a cart passing under.
@export var low_reach := 3.2
@export var kills := true
@export var hang_lag := 0.35
@export var motor: AudioStream
@export var motor_db := -12.0
@export var motor_unit := 25.0
@export var clang: AudioStream
@export var clang_db := -2.0
@export var crash: AudioStream
@export var crash_db := 0.0
## Seconds into the day; set to hold it still for tests and shots (negative: the wall clock).
@export var clock_override := -1.0

signal cart_hit(cart: Node)

var period := 20.0
var _hang: Node3D
var _car: Node3D
var _body: AnimatableBody3D
var _base_basis := Basis()
var _prev_pos := {}
var _intervals := {}
var _motor_player: AudioStreamPlayer3D
var _clang_player: AudioStreamPlayer3D
var _crash_player: AudioStreamPlayer3D
var _headless := false
var _last_stage := -1


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	period = 2.0 * move + dwell + hover + _fall_time() + lie + lift
	_hang = get_node_or_null(hang) as Node3D
	_car = get_node_or_null(car) as Node3D
	# Its heading before it ever turned: _apply turns it at once, and a level saved by its generator keeps that turned basis
	# (at whatever the clock said then), so it is kept in a meta the first time and read back from it after.
	if has_meta(&"base_basis"):
		_base_basis = get_meta(&"base_basis")
	else:
		_base_basis = transform.basis.orthonormalized()
		set_meta(&"base_basis", _base_basis)
	if _car != null:
		_body = AnimatableBody3D.new()
		_body.name = "CarBody"
		_body.sync_to_physics = false
		_body.set_meta(&"surface", "rock")
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = car_half * 2.0
		cs.shape = box
		cs.position = car_centre
		_body.add_child(cs)
		_body.collision_layer = 0
		_body.collision_mask = 0
		_car.add_child(_body, false, Node.INTERNAL_MODE_BACK)
	if not _headless:
		_motor_player = _player("Motor", motor, motor_db, motor_unit)
		_clang_player = _player("Clang", clang, clang_db, 30.0)
		_crash_player = _player("Crash", crash, crash_db, 35.0)
	_apply(_clock())


func _player(n: String, stream: AudioStream, db: float, unit: float) -> AudioStreamPlayer3D:
	if stream == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.name = n
	p.stream = stream
	p.volume_db = db
	p.unit_size = unit
	p.max_distance = 400.0
	p.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	add_child(p, false, Node.INTERNAL_MODE_BACK)
	return p


func _clock() -> float:
	if clock_override >= 0.0:
		return clock_override
	return fmod(Time.get_unix_time_from_system(), 86400.0)


func cycle_time() -> float:
	return fposmod(_clock() - phase, period)


func _fall_time() -> float:
	return sqrt(2.0 * maxf(drop, 0.01) / maxf(fall_gravity, 0.1))


static func _smoother(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * u * (u * (u * 6.0 - 15.0) + 10.0)


## The stages' start times: dwell, slew in, hover, fall, lie, lift, slew out.
func _marks() -> Array:
	var t1: float = dwell
	var t2: float = t1 + move
	var t3: float = t2 + hover
	var t4: float = t3 + _fall_time()
	var t5: float = t4 + lie
	var t6: float = t5 + lift
	return [0.0, t1, t2, t3, t4, t5, t6, t6 + move]


## Which stage `tc` is in (0 dwell, 1 slew in, 2 hover, 3 fall, 4 lie, 5 lift, 6 slew out).
func _stage(tc: float) -> int:
	var m: Array = _marks()
	for i in range(6, -1, -1):
		if tc >= float(m[i]):
			return i
	return 0


## The slew angle (degrees) `tc` seconds into the cycle.
func angle_at(tc: float) -> float:
	var m: Array = _marks()
	var st: int = _stage(tc)
	if st == 0:
		return pile_deg
	if st == 1:
		return lerpf(pile_deg, centre_deg, _smoother((tc - float(m[1])) / move))
	if st == 6:
		return lerpf(centre_deg, pile_deg, _smoother((tc - float(m[6])) / move))
	return centre_deg


## How far the car hangs under its place on the magnet (metres, >= 0) `tc` seconds into the cycle.
func car_drop_at(tc: float) -> float:
	var m: Array = _marks()
	var st: int = _stage(tc)
	if st == 3:
		var u: float = tc - float(m[3])
		return minf(0.5 * fall_gravity * u * u, drop)
	if st == 4:
		return drop
	if st == 5:
		return drop * (1.0 - _smoother((tc - float(m[5])) / lift))
	return 0.0


func _apply(t: float) -> void:
	var tc: float = fposmod(t - phase, period)
	var ang: float = angle_at(tc)
	transform.basis = _base_basis * Basis(Vector3.UP, deg_to_rad(ang))
	var w0: float = angle_at(fposmod(tc - 0.1, period))
	var w2: float = angle_at(fposmod(tc + 0.1, period))
	var rate: float = (w2 - w0) / 0.2
	var accel: float = (w2 - 2.0 * ang + w0) / 0.01
	if _hang != null:
		# The load trails the slewing a little and swings out with it.
		_hang.rotation = Vector3(0.0, 0.0, deg_to_rad(clampf(-accel * hang_lag * 0.02, -9.0, 9.0)))
	var st: int = _stage(tc)
	if _car != null:
		_car.position = Vector3(0.0, -car_drop_at(tc), 0.0)
	if _body != null:
		# Solid while it lies on the road and as it is lifted off (layer 1: the carts' mask).
		var solid: bool = st == 4 or st == 5
		_body.collision_layer = 1 if solid else 0
	if st != _last_stage and _last_stage >= 0 and not _headless:
		if st == 3 and _clang_player != null:
			_clang_player.position = to_local(_car.global_position) if _car != null else Vector3.ZERO
			_clang_player.play()
		elif st == 4 and _crash_player != null:
			_crash_player.position = to_local(_car.global_position) if _car != null else Vector3.ZERO
			_crash_player.play()
		elif st == 5 and _clang_player != null:
			_clang_player.position = to_local(_car.global_position) if _car != null else Vector3.ZERO
			_clang_player.play()
	_last_stage = st
	if _motor_player != null:
		var busy: float = clampf(absf(rate) / maxf(absf(pile_deg - centre_deg) / move, 1.0) * 0.8, 0.0, 1.0)
		if st == 5:
			busy = 0.7
		if busy > 0.05 and not _motor_player.playing:
			_motor_player.play()
		_motor_player.volume_db = motor_db + lerpf(-14.0, 0.0, busy)
		_motor_player.pitch_scale = lerpf(0.85, 1.1, busy)


func _physics_process(_delta: float) -> void:
	var t: float = _clock()
	_apply(t)
	if kills:
		_check_hits(t)


## The car's box frame in the world (its centre and axes).
func _box_xf() -> Transform3D:
	var base: Transform3D = _car.global_transform if _car != null else global_transform
	return base * Transform3D(Basis(), car_centre)


func _check_hits(t: float) -> void:
	var tc: float = fposmod(t - phase, period)
	var st: int = _stage(tc)
	# Only a car in the air hurts: lying or being lifted off the road it is a solid obstacle instead.
	if st == 4 or st == 5:
		return
	var xf: Transform3D = _box_xf()
	var inv: Transform3D = xf.affine_inverse()
	for c in get_tree().get_nodes_in_group("player_carts"):
		var cart := c as RigidBody3D
		if cart == null or not is_instance_valid(cart):
			continue
		var id := cart.get_instance_id()
		var pos: Vector3 = cart.global_position
		var prev: Vector3 = _prev_pos.get(id, pos)
		_prev_pos[id] = pos
		if pos.distance_to(xf.origin) > car_half.length() + 12.0:
			continue
		if not cart.has_method("has_physics_authority") or not cart.has_physics_authority():
			continue
		if cart.get("is_finished_race") or cart.get("is_exploding") or cart.get("is_teleporting"):
			continue
		var r: float = float(cart.get("collision_radius")) * 0.85
		var hit := false
		for k in 5:
			var p: Vector3 = inv * prev.lerp(pos, k / 4.0)
			var q := Vector3(maxf(absf(p.x) - car_half.x, 0.0), maxf(absf(p.y) - car_half.y, 0.0), maxf(absf(p.z) - car_half.z, 0.0))
			if q.length() < r:
				hit = true
				break
		if not hit:
			continue
		print("CarDropCrane %s: the scrap car hit cart %s" % [name, cart.name])
		cart_hit.emit(cart)
		if multiplayer.multiplayer_peer != null:
			cart.explode_rpc.rpc(0, "scrap_car")
		else:
			cart.explode(0, "scrap_car")


## When in the cycle the car is over the road at `gate` (HazardGate.gd) and low enough to hit a cart there (falling,
## lying, being lifted, or swinging past under `low_reach` over the road), as [start, end] pairs; worked out once per gate.
func cover_intervals(gate: Node) -> Array:
	var key: int = gate.get_instance_id()
	if _intervals.has(key):
		return _intervals[key]
	var out: Array = []
	var start := -1.0
	var tc := 0.0
	var parent_xf: Transform3D = get_parent_node_3d().global_transform if get_parent_node_3d() != null else Transform3D.IDENTITY
	var local0: Transform3D = Transform3D(_base_basis, transform.origin)
	var hang_local: Vector3 = _hang.position if _hang != null else Vector3.ZERO
	var pad: float = maxf(car_half.x, car_half.z)
	var road_y: float = (gate as Node3D).global_position.y
	while tc <= period:
		var xf: Transform3D = parent_xf * local0 * Transform3D(Basis(Vector3.UP, deg_to_rad(angle_at(tc))), Vector3.ZERO)
		var c: Vector3 = xf * (hang_local + Vector3(0.0, -car_drop_at(tc), 0.0) + car_centre)
		var st: int = _stage(tc)
		var low: bool = st >= 3 and st <= 5 or c.y - car_half.y < road_y + low_reach
		var on: bool = low and gate.on_road(c, pad)
		if on and start < 0.0:
			start = tc
		elif not on and start >= 0.0:
			out.append([start, tc])
			start = -1.0
		tc += 0.05
	if start >= 0.0:
		out.append([start, period])
	_intervals[key] = out
	return out
