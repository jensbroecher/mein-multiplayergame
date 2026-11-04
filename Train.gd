extends Node3D
## A freight train running along `path` (the rail-head line, in this node's space), on the wall clock
## like Monorail.gd and WildebeestHerd.gd, so every LAN peer sees the same cars in the same place
## without syncing. Every `period` seconds (shifted by `phase`) the head enters the path's start and
## runs through at `speed`; the cars are TrainKit's, placed by the chord between each end of the car,
## so they follow a curve. Between passes it is hidden.
##
## `consist` lists the cars from the head: "loco", "box" ("box:1" a colourway), "tank", "flat",
## "flat_load", "caboose", and "gap:14" for an uncoupled cut: an opening 14m wide in game metres,
## with nothing in it. The gaps are what a cart can drive through when it catches the right moment.
## A "~" before a car turns it round (a second diesel at the tail, nose outward).
##
## With `legs` the train keeps a timetable of its own instead of running through at `speed`: it pulls
## away, runs, slows and stops, stands, and may back up the way it came (Freight Line's local into the
## station). `pass_windows` then gives each of its passes over a point separately.
##
## Touching a moving car anywhere destroys a cart: the roof and a flatcar's deck count. There is no
## collision body then (a cart at 60 m/s moves a metre a step): `_check_hits` tests every cart this peer
## drives against each car's box, swept between the last tick and this one in the cars' own frames. A
## train standing still (under STAND_SPEED: parked stock, the local at the platform) destroys nobody and
## is solid instead: each car has a box body (`Car.body`) that only collides while it stands.
##
## The cars move in _physics_process, so physics interpolation draws them between ticks: one that comes
## into view (or goes out of it) has its interpolation reset, or for a frame it was drawn somewhere
## between where it left the path and where it came back, a ghost car flashing by the tunnels.
##
## `blocked_intervals(s, clear_height)` says when the train covers a point on the path, so crossings
## can warn and the AI can brake. A car lower than `clear_height` (a flatcar, for a kicker that clears
## it) doesn't count.

const TrainKit = preload("res://TrainKit.gd")
const FreightKit = preload("res://FreightKit.gd")

@export var path: Curve3D
@export var consist := PackedStringArray(["loco", "box", "box", "flat", "flat", "gap:16", "tank", "tank", "box", "caboose"])
@export var speed := 24.0
@export var period := 60.0
@export var phase := 0.0
## Runs from the path's end to its start.
@export var reverse := false
@export var kills := true
## A closed path (its last point back on its first): the train circles it for ever at `speed`, never leaving it
## (`period` is the lap's time then, worked out from the path), as on Mina del Viento's rail loop.
@export var looped := false
## A fraction of the cart's radius that has to reach into a car's box to count as a hit.
@export var hit_share := 0.85
## The locomotive's diesel and the clatter of the wheels, in 3D on the train (off for tests and shots).
@export var sounds := true
## Seconds into the day; set to hold the train still for tests and shots (negative: the wall clock).
@export var clock_override := -1.0
## A timetable of its own: legs of [start, end (seconds into the cycle), from, to (metres of the head along the
## path), ramp (seconds to reach its pace, and to stop)], flattened, in order. Between legs (and from the last leg's
## end round to the first's start) it stands where the last one left it. `to` < `from` backs it up.
@export var legs := PackedFloat32Array()

signal cart_hit(cart: Node)

## Below this speed (m/s) a train counts as standing: solid, and harmless.
const STAND_SPEED := 1.0

class Car:
	var kind := ""
	var flip := false
	var solid := true
	var body: AnimatableBody3D
	var offset := 0.0     # from the head back to the car's front
	var length := 0.0
	var height := 0.0
	var half_width := 0.0
	var node: MeshInstance3D
	## [MeshInstance3D, z along the car (+ toward its back)]: each set on the rails on its own (_place).
	var bogies: Array = []
	var xf := Transform3D.IDENTITY
	var prev_xf := Transform3D.IDENTITY
	var present := false
	var prev_present := false

var cars: Array[Car] = []
## Metres, head to tail.
var train_length := 0.0
var _path_length := 0.0
var _prev_pos := {}      # cart instance id -> position at the last tick
var _engine_audio: AudioStreamPlayer3D
var _clatter_audio: AudioStreamPlayer3D


func _ready() -> void:
	if path == null or path.point_count < 2:
		return
	_path_length = path.get_baked_length()
	var off := 0.0
	for entry in consist:
		var parts := String(entry).split(":")
		var kind := parts[0]
		var car := Car.new()
		if kind.begins_with("~"):
			kind = kind.substr(1)
			car.flip = true
		car.kind = kind
		car.offset = off
		if kind == "gap":
			car.solid = false
			car.length = float(parts[1]) if parts.size() > 1 else 14.0
		else:
			var variant := int(parts[1]) if parts.size() > 1 else 0
			car.length = TrainKit.car_length(kind)
			car.height = TrainKit.car_height(kind)
			car.half_width = TrainKit.car_half_width(kind)
			var mi := MeshInstance3D.new()
			mi.name = "Car%d_%s" % [cars.size(), kind]
			mi.mesh = TrainKit.build(kind, variant, false)
			mi.visible = false
			add_child(mi, false, Node.INTERNAL_MODE_BACK)
			car.node = mi
			for b in TrainKit.bogies(kind, variant):
				var bm := MeshInstance3D.new()
				bm.name = "Car%d_bogie%d" % [cars.size(), car.bogies.size()]
				bm.mesh = TrainKit.bogie_mesh(b[1])
				bm.visible = false
				add_child(bm, false, Node.INTERNAL_MODE_BACK)
				car.bogies.append([bm, float(b[0])])
			car.body = _car_body(car)
		off += car.length
		cars.append(car)
	train_length = off
	if looped:
		period = _path_length / maxf(speed, 0.01)
	elif legs.is_empty() and period * speed < _path_length + train_length:
		push_warning("Train %s: period %.0fs at %.0f m/s is too short to clear a %.0fm path with a %.0fm train" % [name, period, speed, _path_length, train_length])
	if sounds:
		_add_sounds()
	_place(_clock())


## The box a standing car is solid as: its length (less the couplers' gap), its width, from 30cm over the rail to
## its roof. Off (no layer) until the car stands in view (_update_bodies).
func _car_body(car: Car) -> AnimatableBody3D:
	var body := AnimatableBody3D.new()
	body.name = "Solid"
	# Follows the car node (synced to physics, it stayed at the origin).
	body.sync_to_physics = false
	body.collision_layer = 0
	body.collision_mask = 0
	body.set_meta(&"surface", "rock")
	var shape := BoxShape3D.new()
	var y0 := 0.3
	shape.size = Vector3(car.half_width * 2.0, car.height - y0, maxf(car.length - 0.8, 1.0))
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0.0, y0 + (car.height - y0) * 0.5, 0.0)
	body.add_child(cs)
	car.node.add_child(body)
	return body


## Whether the train is moving at more than STAND_SPEED (one on `legs` stands between them).
func is_moving() -> bool:
	if legs.is_empty():
		return speed > STAND_SPEED
	var tc := cycle_time()
	return absf(_leg_head(tc) - _leg_head(fposmod(tc - 0.25, period))) > STAND_SPEED * 0.25


## Standing cars in view are solid; moving ones are not (they destroy what touches them instead).
func _update_bodies(moving: bool) -> void:
	for car in cars:
		if car.body == null:
			continue
		var layer: int = 0 if moving or not car.present else 1
		if car.body.collision_layer != layer:
			car.body.collision_layer = layer


func _add_sounds() -> void:
	var loco: Car = null
	var mid: Car = null
	for car in cars:
		if car.node == null:
			continue
		if (car.kind == "loco" or car.kind == "ploco") and loco == null:
			loco = car
		if car.offset > train_length * 0.45 and mid == null:
			mid = car
	if loco != null:
		_engine_audio = _player(FreightKit.diesel(), -3.0, 30.0)
		_engine_audio.position = Vector3(0, 3.0, 0)
		loco.node.add_child(_engine_audio)
	if mid != null:
		_clatter_audio = _player(FreightKit.clatter(), -2.0, 40.0)
		_clatter_audio.position = Vector3(0, 1.0, 0)
		mid.node.add_child(_clatter_audio)


func _player(stream: AudioStream, db: float, unit: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = &"SFX"
	p.volume_db = db
	p.unit_size = unit
	p.max_distance = 500.0
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	return p


func _physics_process(_delta: float) -> void:
	if cars.is_empty():
		return
	_place(_clock())
	var moving := is_moving()
	_update_bodies(moving)
	if kills and moving:
		_check_hits()


func _clock() -> float:
	if clock_override >= 0.0:
		return clock_override
	return fmod(Time.get_unix_time_from_system(), 86400.0)


## Where the head is along the path, `t` seconds into the day (negative before it enters).
func head_at(t: float) -> float:
	if looped:
		return fposmod((t - phase) * speed, _path_length)
	if not legs.is_empty():
		return _leg_head(fposmod(t - phase, period))
	return fposmod(t - phase, period) * speed


## The head's place `tc` seconds into the cycle, from `legs`.
func _leg_head(tc: float) -> float:
	var n: int = floori(legs.size() / 5.0)
	var head := legs[(n - 1) * 5 + 3]
	for k in n:
		var t0 := legs[k * 5]
		var t1 := legs[k * 5 + 1]
		if tc < t0:
			return head
		var s0 := legs[k * 5 + 2]
		var s1 := legs[k * 5 + 3]
		if tc <= t1:
			return s0 + (s1 - s0) * _ramped((tc - t0) / maxf(t1 - t0, 0.001), legs[k * 5 + 4] / maxf(t1 - t0, 0.001))
		head = s1
	return head


## The share of a leg run `u` of the way through it, pulling away and stopping with an even acceleration over the
## first and last `a` of it and at a steady pace between.
static func _ramped(u: float, a: float) -> float:
	a = clampf(a, 0.001, 0.5)
	if u <= a:
		return u * u / (2.0 * a) / (1.0 - a)
	if u >= 1.0 - a:
		return 1.0 - (1.0 - u) * (1.0 - u) / (2.0 * a) / (1.0 - a)
	return (u - a * 0.5) / (1.0 - a)


## Seconds into the train's cycle (0 as the head enters the path).
func cycle_time() -> float:
	return fposmod(_clock() - phase, period)


## When the first and the last solid car cover the point `s` (seconds into the cycle, widened by `pad` metres
## of the train): [start, end], or [] with no solid car.
func pass_window(s: float, pad := 0.0) -> Array:
	var ivs := blocked_intervals(s, 0.0, pad)
	if ivs.is_empty():
		return []
	return [ivs[0][0], ivs[-1][1]]


## Each pass of the train over the point `s` as its own [start, end] window (seconds into the cycle, widened by
## `pad` metres): one for a train that runs straight through, two for one that comes back the way it went.
func pass_windows(s: float, pad := 0.0) -> Array:
	var ivs := blocked_intervals(s, 0.0, pad)
	var out: Array = []
	for iv in ivs:
		if not out.is_empty() and float(iv[0]) - float(out[-1][1]) < PASS_GAP:
			out[-1][1] = maxf(float(out[-1][1]), float(iv[1]))
		else:
			out.append([float(iv[0]), float(iv[1])])
	return out

## Two blocked intervals closer than this are one pass (the openings between a train's cars).
const PASS_GAP := 12.0


## A point `s` metres along the path, running on past either end along its end tangents.
func _point(s: float) -> Vector3:
	if looped:
		return path.sample_baked(fposmod(s, _path_length))
	if s >= 0.0 and s <= _path_length:
		return path.sample_baked(s)
	var end_s := 0.0 if s < 0.0 else _path_length
	var inner := path.sample_baked(1.0 if s < 0.0 else _path_length - 1.0)
	var edge := path.sample_baked(end_s)
	var dir := (edge - inner).normalized()
	return edge + dir * absf(s - end_s)


## The path's own distance for a train distance (a train running the other way measures from the end).
func _along(s: float) -> float:
	return _path_length - s if reverse else s


func _place(t: float) -> void:
	var head := head_at(t)
	for car in cars:
		car.prev_xf = car.xf
		car.prev_present = car.present
		var s_front := head - car.offset
		var s_back := s_front - car.length
		car.present = looped or (s_front > 0.0 and s_back < _path_length)
		if car.node == null:
			continue
		car.node.visible = car.present
		for b in car.bogies:
			(b[0] as MeshInstance3D).visible = car.present
		if not car.present:
			continue
		var pf := _point(_along(s_front))
		var pb := _point(_along(s_back))
		# On its bogies: each stands on the rails at its own place along the path, turned along them there, and the
		# body hangs between the outermost two's pivots (the chord between the car's ends left the bogies off the
		# rails on a curve, swung out under the body).
		var s_mid: float = s_front - car.length * 0.5
		var sgn: float = -1.0 if car.flip else 1.0
		if car.bogies.size() >= 2:
			var z_front: float = 1e9
			var z_back: float = -1e9
			for b in car.bogies:
				var bz: float = float(b[1]) * sgn
				z_front = minf(z_front, bz)
				z_back = maxf(z_back, bz)
				var sb: float = s_mid - bz
				var pa := _point(_along(sb + 0.6))
				var pc := _point(_along(sb - 0.6))
				var bnode: MeshInstance3D = b[0]
				var tang := pa - pc
				if tang.length_squared() > 1e-6:
					bnode.transform = Transform3D(Basis.looking_at(tang.normalized(), Vector3.UP), _point(_along(sb)))
				if not car.prev_present:
					bnode.reset_physics_interpolation()
			var pivot_f := _point(_along(s_mid - z_front))
			var pivot_b := _point(_along(s_mid - z_back))
			var span: float = z_back - z_front
			var ddir := pivot_f - pivot_b
			if ddir.length_squared() > 1e-6 and span > 0.1:
				var mid2: Vector3 = (pivot_f + pivot_b) * 0.5 + ddir.normalized() * ((z_front + z_back) * -0.5)
				pf = mid2 + ddir.normalized() * car.length * 0.5
				pb = mid2 - ddir.normalized() * car.length * 0.5
		var dir := pf - pb
		if dir.length_squared() < 1e-6:
			continue
		var mid := (pf + pb) * 0.5
		car.xf = Transform3D(Basis.looking_at(-dir.normalized() if car.flip else dir.normalized(), Vector3.UP), mid)
		car.node.transform = car.xf
		if not car.prev_present:
			car.prev_xf = car.xf
			# Back in view: drawn from here, not from where it left the path.
			car.node.reset_physics_interpolation()
	_update_sounds()


func _update_sounds() -> void:
	# A train on a timetable of its own that is standing still idles: its diesel, but no wheels.
	var rolling := true
	if not legs.is_empty():
		var tc := cycle_time()
		rolling = absf(_leg_head(tc) - _leg_head(fposmod(tc - 0.5, period))) > 0.5
	for pair in [[_engine_audio, "loco"], [_clatter_audio, ""]]:
		var pl: AudioStreamPlayer3D = pair[0]
		if pl == null:
			continue
		var node := pl.get_parent() as MeshInstance3D
		var on: bool = node != null and node.visible and (rolling or pl == _engine_audio)
		if on and not pl.playing:
			pl.play()
		elif not on and pl.playing:
			pl.stop()


# ======================================================================================
#  Hits
# ======================================================================================

func _check_hits() -> void:
	var carts := get_tree().get_nodes_in_group("player_carts")
	var seen := {}
	for c in carts:
		var cart := c as Node3D
		if cart == null or not is_instance_valid(cart):
			continue
		var id := cart.get_instance_id()
		seen[id] = true
		var pos := cart.global_position
		var prev: Vector3 = _prev_pos.get(id, pos)
		_prev_pos[id] = pos
		if not _cart_can_die(cart):
			continue
		if _swept_hit(prev, pos, float(cart.get("collision_radius"))):
			_kill(cart)
	for id in _prev_pos.keys():
		if not seen.has(id):
			_prev_pos.erase(id)


func _cart_can_die(cart: Node) -> bool:
	if not cart.has_method("has_physics_authority") or not cart.has_physics_authority():
		return false
	for flag in ["is_exploding", "is_finished_race", "is_teleporting", "is_drowned"]:
		if cart.get(flag):
			return false
	return true


## Whether a sphere of `radius` moving from `a` to `b` this tick (in the world) met a car, in the
## frames the cars had at each end of the tick.
func _swept_hit(a: Vector3, b: Vector3, radius: float) -> bool:
	var reach := radius * hit_share
	for car in cars:
		if not car.solid or not car.present:
			continue
		for k in 5:
			var f := k / 4.0
			var xf := car.prev_xf.interpolate_with(car.xf, f)
			var local := xf.affine_inverse() * to_local(a.lerp(b, f))
			if _box_distance(local, car) < reach:
				return true
	return false


## Distance from a point in a car's frame to the car's box (zero inside).
func _box_distance(p: Vector3, car: Car) -> float:
	var q := Vector3(
		maxf(absf(p.x) - car.half_width, 0.0),
		maxf(maxf(-1.2 - p.y, p.y - car.height), 0.0),
		maxf(absf(p.z) - car.length * 0.5, 0.0))
	return q.length()


func _kill(cart: Node) -> void:
	print("Train %s hit cart %s at %s" % [name, cart.name, str((cart as Node3D).global_position)])
	cart_hit.emit(cart)
	if multiplayer.multiplayer_peer != null:
		cart.explode_rpc.rpc(0, "train")
	else:
		cart.explode(0, "train")


# ======================================================================================
#  The timetable
# ======================================================================================

## When the train covers the point `s` metres along the path, as [start, end] pairs in seconds into
## its cycle (0 at `phase`), widened by `pad` metres of the train's length either side. Cars lower
## than `clear_height` are ignored. Merged: a run of boxcars is one interval, a gap splits it.
func blocked_intervals(s: float, clear_height := 0.0, pad := 0.0) -> Array:
	var train_s := _path_length - s if reverse else s
	if not legs.is_empty():
		return _leg_intervals(train_s, clear_height, pad)
	var out: Array = []
	for car in cars:
		if not car.solid or car.height <= clear_height:
			continue
		var t0 := (train_s + car.offset - pad) / speed
		var t1 := (train_s + car.offset + car.length + pad) / speed
		out.append([t0, t1])
	out.sort_custom(func(x, y): return x[0] < y[0])
	var merged: Array = []
	for iv in out:
		if not merged.is_empty() and iv[0] <= merged[-1][1] + 0.001:
			merged[-1][1] = maxf(merged[-1][1], iv[1])
		else:
			merged.append([iv[0], iv[1]])
	return merged


## blocked_intervals for a train on `legs`: the cycle stepped through a tenth of a second at a time (once per point,
## then kept: the crossings and the AI ask about the same few points every frame).
var _leg_cache := {}

func _leg_intervals(train_s: float, clear_height: float, pad: float) -> Array:
	var key := Vector3(train_s, clear_height, pad)
	if _leg_cache.has(key):
		return _leg_cache[key]
	var out: Array = []
	var start := -1.0
	var tc := 0.0
	while tc <= period:
		var head := _leg_head(tc)
		var covered := false
		for car in cars:
			if not car.solid or car.height <= clear_height:
				continue
			var front := head - car.offset + pad
			if train_s <= front and train_s >= front - car.length - 2.0 * pad:
				covered = true
				break
		if covered and start < 0.0:
			start = tc
		elif not covered and start >= 0.0:
			out.append([start, tc])
			start = -1.0
		tc += 0.1
	if start >= 0.0:
		out.append([start, period])
	_leg_cache[key] = out
	return out


## Seconds from now until the point `s` is next covered (0 while it is), and until it is next clear
## (0 while it is). -1 when it never is within two cycles.
func seconds_until_blocked(s: float, clear_height := 0.0, pad := 0.0, t := -1.0) -> float:
	return _next_edge(s, clear_height, pad, t, true)


func seconds_until_clear(s: float, clear_height := 0.0, pad := 0.0, t := -1.0) -> float:
	return _next_edge(s, clear_height, pad, t, false)


func _next_edge(s: float, clear_height: float, pad: float, t: float, want_blocked: bool) -> float:
	var now := _clock() if t < 0.0 else t
	var ivs := blocked_intervals(s, clear_height, pad)
	var tt := fposmod(now - phase, period)
	for iv in ivs:
		if tt >= iv[0] and tt <= iv[1]:
			return 0.0 if want_blocked else iv[1] - tt
	if not want_blocked:
		return 0.0
	for iv in ivs:
		if iv[0] > tt:
			return iv[0] - tt
	if ivs.is_empty():
		return -1.0
	return ivs[0][0] + period - tt
