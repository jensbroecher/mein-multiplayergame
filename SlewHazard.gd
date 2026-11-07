extends Node3D
## A machine's upper slewing back and forth on the wall clock (Quer durch Kronburg: the scrapyard's material handler
## swinging a magnet with a scrap car low across a lane, the building site's excavator sweeping its bucket over the
## road's edge, the tower crane turning its jib), so every LAN peer sees it in the same place without syncing. This node
## is the slew pivot, at the machine's slew ring: it turns itself about its y axis. It holds the upper's mesh (and, for
## the handler, a hanging node `hang` that lags a little behind the slewing, as a load on chains does).
##
## The cycle: dwell at `centre_deg + amplitude_deg`, slew to `centre_deg - amplitude_deg` over `move` seconds (eased in
## and out), dwell, slew back. With `hits`, a box (`hit_centre`, `hit_half`, in this node's turning frame, or in the
## hanging node's frame when `hang` is set) throws a cart it meets: along the slewing, up, spinning (apply_blast_impulse).
## `cover_intervals(gate)` (for HazardGate.gd) says when in the cycle the box is over the road.

@export var centre_deg := 0.0
@export var amplitude_deg := 45.0
@export var move := 5.0
@export var dwell := 3.0
@export var phase := 0.0
@export var hits := false
@export var hit_centre := Vector3.ZERO
@export var hit_half := Vector3.ONE
## A node (a child of this one) the load hangs from: it swings about its x and z axes with the slewing's acceleration.
@export var hang: NodePath
@export var hang_lag := 0.35
@export var throw_speed := 14.0
@export var throw_up := 7.0
@export var motor: AudioStream
@export var motor_db := -12.0
@export var motor_unit := 25.0
@export var clang: AudioStream
@export var clang_db := -2.0
## Seconds into the day; set to hold it still for tests and shots (negative: the wall clock).
@export var clock_override := -1.0

signal cart_hit(cart: Node)

var period := 16.0
var _hang: Node3D
var _prev_pos := {}
var _cooldown := {}
var _intervals := {}
var _motor_player: AudioStreamPlayer3D
var _clang_player: AudioStreamPlayer3D
var _headless := false
var _base_basis := Basis()


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	period = 2.0 * (move + dwell)
	_hang = get_node_or_null(hang) as Node3D
	# Its heading before it ever turned: _apply turns it at once, and a level saved by its generator keeps that turned basis
	# (at whatever the clock said then), so it is kept in a meta the first time and read back from it after.
	if has_meta(&"base_basis"):
		_base_basis = get_meta(&"base_basis")
	else:
		_base_basis = transform.basis.orthonormalized()
		set_meta(&"base_basis", _base_basis)
	if not _headless:
		if motor != null:
			_motor_player = AudioStreamPlayer3D.new()
			_motor_player.name = "Motor"
			_motor_player.stream = motor
			_motor_player.volume_db = motor_db
			_motor_player.unit_size = motor_unit
			_motor_player.max_distance = 400.0
			_motor_player.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
			add_child(_motor_player, false, Node.INTERNAL_MODE_BACK)
		if clang != null:
			_clang_player = AudioStreamPlayer3D.new()
			_clang_player.name = "Clang"
			_clang_player.stream = clang
			_clang_player.volume_db = clang_db
			_clang_player.unit_size = 30.0
			_clang_player.max_distance = 400.0
			_clang_player.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
			add_child(_clang_player, false, Node.INTERNAL_MODE_BACK)
	_apply(_clock())


func _clock() -> float:
	if clock_override >= 0.0:
		return clock_override
	return fmod(Time.get_unix_time_from_system(), 86400.0)


func cycle_time() -> float:
	return fposmod(_clock() - phase, period)


static func _smoother(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * u * (u * (u * 6.0 - 15.0) + 10.0)


## The slew angle (degrees) `tc` seconds into the cycle: dwell at +A, move to -A, dwell, move back.
func angle_at(tc: float) -> float:
	var a: float = amplitude_deg
	if tc < dwell:
		return centre_deg + a
	if tc < dwell + move:
		return centre_deg + a - 2.0 * a * _smoother((tc - dwell) / move)
	if tc < 2.0 * dwell + move:
		return centre_deg - a
	return centre_deg - a + 2.0 * a * _smoother((tc - 2.0 * dwell - move) / move)


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
	if _motor_player != null:
		var busy: float = clampf(absf(rate) / maxf(amplitude_deg * 2.0 / move, 1.0) * 1.6, 0.0, 1.0)
		if busy > 0.05 and not _motor_player.playing:
			_motor_player.play()
		_motor_player.volume_db = motor_db + lerpf(-14.0, 0.0, busy)
		_motor_player.pitch_scale = lerpf(0.85, 1.1, busy)


func _physics_process(_delta: float) -> void:
	var t: float = _clock()
	_apply(t)
	if hits:
		_check_hits(t)


## The hit box's frame in the world (its centre and axes).
func _box_xf() -> Transform3D:
	var base: Transform3D = _hang.global_transform if _hang != null else global_transform
	return base * Transform3D(Basis(), hit_centre)


func _check_hits(t: float) -> void:
	var xf: Transform3D = _box_xf()
	var inv: Transform3D = xf.affine_inverse()
	var carts := get_tree().get_nodes_in_group("player_carts")
	for c in carts:
		var cart := c as RigidBody3D
		if cart == null or not is_instance_valid(cart):
			continue
		var id := cart.get_instance_id()
		var pos: Vector3 = cart.global_position
		var prev: Vector3 = _prev_pos.get(id, pos)
		_prev_pos[id] = pos
		if pos.distance_to(xf.origin) > hit_half.length() + 12.0:
			continue
		if not cart.has_method("has_physics_authority") or not cart.has_physics_authority():
			continue
		if cart.get("is_finished_race") or cart.get("is_exploding") or _cooldown.get(id, -10.0) > t:
			continue
		var r: float = float(cart.get("collision_radius")) * 0.85
		var hit := false
		for k in 5:
			var p: Vector3 = inv * prev.lerp(pos, k / 4.0)
			var q := Vector3(maxf(absf(p.x) - hit_half.x, 0.0), maxf(absf(p.y) - hit_half.y, 0.0), maxf(absf(p.z) - hit_half.z, 0.0))
			if q.length() < r:
				hit = true
				break
		if not hit:
			continue
		_cooldown[id] = t + 1.5
		# Along the slewing (the tangent at the box), away from the pivot a little, and up.
		var tc: float = fposmod(t - phase, period)
		var rate: float = angle_at(fposmod(tc + 0.05, period)) - angle_at(fposmod(tc - 0.05, period))
		var radial: Vector3 = xf.origin - global_position
		radial.y = 0.0
		var tangent: Vector3 = Vector3.UP.cross(radial).normalized() * signf(rate if absf(rate) > 0.001 else 1.0)
		var dv: Vector3 = (tangent * 0.8 + radial.normalized() * 0.2).normalized() * throw_speed + Vector3.UP * throw_up
		print("SlewHazard %s hit cart %s" % [name, cart.name])
		cart_hit.emit(cart)
		if cart.has_method("apply_blast_impulse"):
			cart.apply_blast_impulse(dv * cart.mass)
		else:
			cart.apply_central_impulse(dv * cart.mass)
		if _clang_player != null:
			_clang_player.position = to_local(xf.origin)
			_clang_player.play()


## When in the cycle the hit box is over the road at `gate` (HazardGate.gd), as [start, end] pairs; worked out once.
func cover_intervals(gate: Node) -> Array:
	var key: int = gate.get_instance_id()
	if _intervals.has(key):
		return _intervals[key]
	var out: Array = []
	var start := -1.0
	var tc := 0.0
	var parent_xf: Transform3D = get_parent_node_3d().global_transform if get_parent_node_3d() != null else Transform3D.IDENTITY
	var local0: Transform3D = Transform3D(_base_basis, transform.origin)
	var hang_local: Transform3D = (global_transform.affine_inverse() * _hang.global_transform) if _hang != null else Transform3D.IDENTITY
	var pad: float = maxf(hit_half.x, hit_half.z)
	while tc <= period:
		var xf: Transform3D = parent_xf * local0 * Transform3D(Basis(Vector3.UP, deg_to_rad(angle_at(tc))), Vector3.ZERO) * hang_local * Transform3D(Basis(), hit_centre)
		var on: bool = gate.on_road(xf.origin, pad)
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
