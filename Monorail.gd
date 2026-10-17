extends Node3D
## A monorail train shuttling along `path` (a beam's top line, in this node's space). It runs from
## stop to stop in `stops` (arc lengths along the path, in the order of one full cycle), waiting
## `dwells` seconds at each, accelerating and braking at `accel` up to `cruise`. Where it is comes from
## the wall clock (like WildebeestHerd.gd), so every LAN peer sees it in the same place without syncing.
##
## Three cars: the middle one centred on the train's position, an end car either side `car_pitch`
## away, noses pointing outward (the end car mesh has its nose at -z). Each car carries an
## AnimatableBody3D box, so carts that get up there collide with it. Cars and bodies are internal
## children, built on load: the level stores only this node's settings.
##
## `chime` plays at `chime_at` (the station) `chime_lead` seconds before the train stops at any of
## `chime_stops` (indices into `stops`).

@export var path: Curve3D
@export var end_car: Mesh
@export var mid_car: Mesh
@export var stops := PackedFloat32Array()
@export var dwells := PackedFloat32Array()
@export var car_pitch := 12.6
@export var cruise := 15.0
@export var accel := 1.0
## The cars' collision box: [centre, size] in the car's frame.
@export var car_box_centre := Vector3(0, 1.6, 0)
@export var car_box_size := Vector3(3.0, 3.6, 12.0)
@export var chime: AudioStream
@export var chime_stops := PackedInt32Array()
@export var chime_at := Vector3.ZERO
@export var chime_lead := 3.0

var _cars: Array[Node3D] = []
var _bodies: Array[AnimatableBody3D] = []
var _period := 0.0
var _chime_player: AudioStreamPlayer3D
var _chimed_for := -1


func _ready() -> void:
	if path == null or stops.is_empty():
		return
	for i in 3:
		var mi := MeshInstance3D.new()
		mi.name = "Car%d" % i
		mi.mesh = mid_car if i == 1 else end_car
		add_child(mi, false, Node.INTERNAL_MODE_BACK)
		_cars.append(mi)
		var body := AnimatableBody3D.new()
		body.name = "CarBody%d" % i
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = car_box_size
		cs.shape = box
		cs.position = car_box_centre
		body.add_child(cs)
		add_child(body, false, Node.INTERNAL_MODE_BACK)
		_bodies.append(body)
	_period = 0.0
	for i in stops.size():
		_period += dwells[i] + _leg_time(absf(stops[(i + 1) % stops.size()] - stops[i]))
	if chime:
		_chime_player = AudioStreamPlayer3D.new()
		_chime_player.stream = chime
		_chime_player.bus = &"SFX"
		_chime_player.volume_db = 2.0
		_chime_player.unit_size = 30.0
		_chime_player.max_distance = 260.0
		_chime_player.position = chime_at
		add_child(_chime_player, false, Node.INTERNAL_MODE_BACK)
	_place(_now())


func _physics_process(_delta: float) -> void:
	if _cars.is_empty():
		return
	var t := _now()
	_place(t)
	_check_chime(t)


func _now() -> float:
	return fmod(Time.get_unix_time_from_system(), 86400.0)


func _place(t: float) -> void:
	var s := _s_at(t)
	var length := path.get_baked_length()
	for i in 3:
		var cs := clampf(s + (1 - i) * car_pitch, 0.0, length)
		var p := path.sample_baked(cs)
		var dir := path.sample_baked(minf(cs + 1.0, length)) - path.sample_baked(maxf(cs - 1.0, 0.0))
		dir.y = 0.0
		var b := Basis.looking_at(dir.normalized(), Vector3.UP)
		# The car behind faces the other way: its nose leads when the train reverses.
		if i == 2:
			b = b * Basis(Vector3.UP, PI)
		var xf := Transform3D(b, p)
		_cars[i].transform = xf
		_bodies[i].transform = xf


## Rings the chime once per arrival at a chime stop, `chime_lead` seconds before the train stops.
func _check_chime(t: float) -> void:
	if _chime_player == null:
		return
	var tt := fposmod(t, _period)
	var cycle := int(floor(t / _period))
	var n := stops.size()
	for i in n:
		tt -= dwells[i]
		if tt < 0.0:
			return
		var leg := _leg_time(absf(stops[(i + 1) % n] - stops[i]))
		if tt < leg:
			var target := (i + 1) % n
			var key := cycle * n + target
			if leg - tt <= chime_lead and target in chime_stops and _chimed_for != key:
				_chimed_for = key
				_chime_player.play()
			return
		tt -= leg


## Where along the path the middle car is, `t` seconds into the day.
func _s_at(t: float) -> float:
	var tt := fposmod(t, _period)
	var n := stops.size()
	for i in n:
		if tt < dwells[i]:
			return stops[i]
		tt -= dwells[i]
		var a := stops[i]
		var b := stops[(i + 1) % n]
		var leg := _leg_time(absf(b - a))
		if tt < leg:
			return a + signf(b - a) * _leg_dist(absf(b - a), tt)
		tt -= leg
	return stops[0]


## Time to run `d` metres from a stop to a stop.
func _leg_time(d: float) -> float:
	var ramp := cruise * cruise / accel
	if d >= ramp:
		return 2.0 * cruise / accel + (d - ramp) / cruise
	return 2.0 * sqrt(d / accel)


## Distance covered `t` seconds into a leg of `d` metres.
func _leg_dist(d: float, t: float) -> float:
	var total := _leg_time(d)
	var ramp := cruise * cruise / accel
	var t_up := cruise / accel if d >= ramp else sqrt(d / accel)
	if t < t_up:
		return 0.5 * accel * t * t
	if t > total - t_up:
		var r := total - t
		return d - 0.5 * accel * r * r
	return 0.5 * accel * t_up * t_up + cruise * (t - t_up)
