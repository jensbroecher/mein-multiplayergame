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
##
## Touching a car anywhere destroys a cart: the roof and a flatcar's deck count. There is no collision
## body (a cart at 60 m/s moves a metre a step): `_check_hits` tests every cart this peer drives
## against each car's box, swept between the last tick and this one in the cars' own frames.
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
## A fraction of the cart's radius that has to reach into a car's box to count as a hit.
@export var hit_share := 0.85
## The locomotive's diesel and the clatter of the wheels, in 3D on the train (off for tests and shots).
@export var sounds := true
## Seconds into the day; set to hold the train still for tests and shots (negative: the wall clock).
@export var clock_override := -1.0

signal cart_hit(cart: Node)

class Car:
	var kind := ""
	var solid := true
	var offset := 0.0     # from the head back to the car's front
	var length := 0.0
	var height := 0.0
	var half_width := 0.0
	var node: MeshInstance3D
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
			mi.mesh = TrainKit.build(kind, variant)
			mi.visible = false
			add_child(mi, false, Node.INTERNAL_MODE_BACK)
			car.node = mi
		off += car.length
		cars.append(car)
	train_length = off
	if period * speed < _path_length + train_length:
		push_warning("Train %s: period %.0fs at %.0f m/s is too short to clear a %.0fm path with a %.0fm train" % [name, period, speed, _path_length, train_length])
	if sounds:
		_add_sounds()
	_place(_clock())


func _add_sounds() -> void:
	var loco: Car = null
	var mid: Car = null
	for car in cars:
		if car.node == null:
			continue
		if car.kind == "loco" and loco == null:
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
	if kills:
		_check_hits()


func _clock() -> float:
	if clock_override >= 0.0:
		return clock_override
	return fmod(Time.get_unix_time_from_system(), 86400.0)


## Where the head is along the path, `t` seconds into the day (negative before it enters).
func head_at(t: float) -> float:
	return fposmod(t - phase, period) * speed


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


## A point `s` metres along the path, running on past either end along its end tangents.
func _point(s: float) -> Vector3:
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
		car.present = s_front > 0.0 and s_back < _path_length
		if car.node == null:
			continue
		car.node.visible = car.present
		if not car.present:
			continue
		var pf := _point(_along(s_front))
		var pb := _point(_along(s_back))
		var dir := pf - pb
		if dir.length_squared() < 1e-6:
			continue
		var mid := (pf + pb) * 0.5
		car.xf = Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP), mid)
		car.node.transform = car.xf
		if not car.prev_present:
			car.prev_xf = car.xf
	_update_sounds()


func _update_sounds() -> void:
	for pair in [[_engine_audio, "loco"], [_clatter_audio, ""]]:
		var pl: AudioStreamPlayer3D = pair[0]
		if pl == null:
			continue
		var node := pl.get_parent() as MeshInstance3D
		var on: bool = node != null and node.visible
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
