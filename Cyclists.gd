extends Node3D
## Cyclists riding the Lakeside Meadows' bike path (regenerate_lakeside.gd, _build_trails). Each rides a closed route
## (`routes`, points about a metre apart on the path's surface) at its own speed on the wall clock
## (Time.get_unix_time_from_system), so every LAN peer sees them in the same places without syncing, as SeaBoat.gd's
## boats. The parts are ParkKit's (life size, grown by `prop_scale`): the frame and the rider's body, two wheels rolling
## with the distance, the cranks turning with them (ParkKit.BIKE_GEAR), and each leg's thigh and shin set by two-bone
## IK from the hip to its pedal every frame, so they pedal. A rider leans into bends (the heading's turn per metre at its
## speed) and keeps to the right of the path (`lane`). Each is an AnimatableBody3D with a box round it, so a cart that
## runs into one stops (layer 1, as the frozen knockable props: AI obstacle rays see it). The level stores only this
## node's data; the riders are built as internal children at load. Each rider rolls (`roll_sounds`, one each in turn)
## and pedals (`pedal_sound`), both loops on players riding with it, pitched with its speed; not on a headless server.

const ParkKit = preload("res://ParkKit.gd")

## Closed routes, points on the path's surface.
@export var routes: Array[PackedVector3Array] = []
## One per rider: x the route, y where it starts (metres along), z its speed (m/s; negative rides the route
## backwards), w its lane (metres right of its way).
@export var riders: Array[Vector4] = []
## One per rider: the frame and body, a thigh, a shin (ParkKit's parts, in that rider's colours).
@export var body_meshes: Array[Mesh] = []
@export var thigh_meshes: Array[Mesh] = []
@export var shin_meshes: Array[Mesh] = []
@export var wheel_mesh: Mesh
@export var crank_mesh: Mesh
@export var prop_scale := 1.6
## The tyres on the path and the pedalling, loops, with the gains that bring each to its level at `sound_unit` metres.
@export var roll_sounds: Array[AudioStream] = []
@export var roll_db: Array[float] = []
@export var pedal_sound: AudioStream
@export var pedal_db := 0.0
@export var sound_unit := 7.0
@export var sound_reach := 70.0

var _lengths: Array = []           # per route: cumulative metres at each point
var _riders: Array = []            # per rider: {body, model, wheels, crank, thighs, shins}


func _ready() -> void:
	for r in routes:
		var cum := PackedFloat32Array()
		cum.resize(r.size() + 1)
		var acc := 0.0
		for i in range(r.size()):
			cum[i] = acc
			acc += r[i].distance_to(r[(i + 1) % r.size()])
		cum[r.size()] = acc
		_lengths.append(cum)
	for i in range(riders.size()):
		_riders.append(_build_rider(i))
	_update(true)


func _build_rider(i: int) -> Dictionary:
	var body := AnimatableBody3D.new()
	body.name = "Rider_%d" % i
	body.sync_to_physics = false
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 1.7, 1.75) * prop_scale
	cs.shape = box
	cs.position = Vector3(0.0, 0.85 * prop_scale, 0.0)
	body.add_child(cs)
	add_child(body, false, Node.INTERNAL_MODE_BACK)
	var model := Node3D.new()
	model.scale = Vector3.ONE * prop_scale
	body.add_child(model)
	var frame := MeshInstance3D.new()
	frame.mesh = body_meshes[i % body_meshes.size()]
	model.add_child(frame)
	var wheels: Array = []
	for z in [ParkKit.BIKE_REAR_Z, ParkKit.BIKE_FRONT_Z]:
		var w := MeshInstance3D.new()
		w.mesh = wheel_mesh
		w.position = Vector3(0.0, ParkKit.BIKE_WHEEL_R, z)
		model.add_child(w)
		wheels.append(w)
	var crank := MeshInstance3D.new()
	crank.mesh = crank_mesh
	crank.position = ParkKit.BIKE_BB
	model.add_child(crank)
	var thighs: Array = []
	var shins: Array = []
	for s in range(2):
		var t := MeshInstance3D.new()
		t.mesh = thigh_meshes[i % thigh_meshes.size()]
		model.add_child(t)
		thighs.append(t)
		var sh := MeshInstance3D.new()
		sh.mesh = shin_meshes[i % shin_meshes.size()]
		model.add_child(sh)
		shins.append(sh)
	var players: Array = []
	if DisplayServer.get_name() != "headless":
		var streams: Array = []
		if not roll_sounds.is_empty():
			var k := i % roll_sounds.size()
			streams.append([roll_sounds[k], roll_db[k] if k < roll_db.size() else 0.0])
		if pedal_sound:
			streams.append([pedal_sound, pedal_db])
		for sd in streams:
			var pl := AudioStreamPlayer3D.new()
			pl.stream = sd[0]
			pl.volume_db = float(sd[1])
			pl.unit_size = sound_unit
			pl.max_distance = sound_reach
			pl.bus = &"SFX"
			pl.position = Vector3(0.0, 0.6 * prop_scale, 0.0)
			body.add_child(pl)
			pl.play(randf() * maxf((sd[0] as AudioStream).get_length() - 0.1, 0.0))
			players.append(pl)
	return {"body": body, "wheels": wheels, "crank": crank, "thighs": thighs, "shins": shins, "players": players}


func _physics_process(_delta: float) -> void:
	_update(false)


## Where on route `r` the point `s` metres along it lies: [position, direction of increasing s].
func _sample(r: int, s: float) -> Array:
	var pts: PackedVector3Array = routes[r]
	var cum: PackedFloat32Array = _lengths[r]
	var total: float = cum[pts.size()]
	s = fposmod(s, total)
	var lo := 0
	var hi := pts.size()
	while hi - lo > 1:
		var mid := (lo + hi) >> 1
		if cum[mid] <= s:
			lo = mid
		else:
			hi = mid
	var a: Vector3 = pts[lo]
	var b: Vector3 = pts[(lo + 1) % pts.size()]
	var seg: float = maxf(cum[lo + 1] - cum[lo], 1e-4)
	var t: float = (s - cum[lo]) / seg
	return [a.lerp(b, t), (b - a) / seg]


func _update(_first: bool) -> void:
	var now := Time.get_unix_time_from_system()
	for i in range(_riders.size()):
		var rd: Vector4 = riders[i]
		var r := int(rd.x)
		if r < 0 or r >= routes.size():
			continue
		var total: float = (_lengths[r] as PackedFloat32Array)[routes[r].size()]
		# Metres ridden since the epoch (a double: exact enough for years).
		var dist: float = float(now) * absf(rd.z)
		var s: float = rd.y + fmod(dist, total) * signf(rd.z)
		var here := _sample(r, s)
		var ahead := _sample(r, s + 3.0 * signf(rd.z))
		var behind := _sample(r, s - 3.0 * signf(rd.z))
		var fwd: Vector3 = ((ahead[0] as Vector3) - (behind[0] as Vector3))
		if fwd.length_squared() < 1e-6:
			continue
		fwd = fwd.normalized()
		var flat := Vector3(fwd.x, 0.0, fwd.z).normalized()
		var right := Vector3(-flat.z, 0.0, flat.x)
		# The turn per metre ahead, signed (positive: to the right), for the lean.
		var f0 := Vector3((here[0] as Vector3) - (behind[0] as Vector3))
		var f1 := Vector3((ahead[0] as Vector3) - (here[0] as Vector3))
		f0.y = 0.0
		f1.y = 0.0
		var turn := 0.0
		if f0.length_squared() > 1e-6 and f1.length_squared() > 1e-6:
			turn = f0.normalized().signed_angle_to(f1.normalized(), Vector3.DOWN) / 3.0
		var lean := clampf(atan(rd.z * rd.z * turn / 9.8), -0.4, 0.4)
		var pos: Vector3 = (here[0] as Vector3) + right * rd.w
		var basis := Basis.looking_at(fwd, Vector3.UP)
		# Rotating about the way ahead by +lean tips the top to the right: into a right-hander.
		basis = Basis(fwd, lean) * basis
		var info: Dictionary = _riders[i]
		(info["body"] as AnimatableBody3D).global_transform = Transform3D(basis, pos)
		# Wheels and cranks by the distance ridden.
		# Wrapped in doubles before they become float rotations (a float of the raw angle has no precision left).
		var wheel_turn: float = -fmod(dist / (ParkKit.BIKE_WHEEL_R * prop_scale), TAU)
		for w in info["wheels"]:
			(w as Node3D).rotation = Vector3(wheel_turn, 0.0, 0.0)
		var c: float = -fmod(dist / (ParkKit.BIKE_WHEEL_R * prop_scale * ParkKit.BIKE_GEAR), TAU)
		for pl in info["players"]:
			(pl as AudioStreamPlayer3D).pitch_scale = clampf(absf(rd.z) / 6.25, 0.8, 1.2)
		(info["crank"] as Node3D).rotation = Vector3(c, 0.0, 0.0)
		# Legs: the right pedal is at the crank's -z end at angle 0 (ParkKit.bike_crank).
		for side in range(2):
			var sg: float = 1.0 if side == 0 else -1.0
			var pedal := ParkKit.BIKE_BB + Vector3(sg * ParkKit.BIKE_PEDAL_X, sg * ParkKit.BIKE_CRANK * sin(c), -sg * ParkKit.BIKE_CRANK * cos(c))
			var ankle := pedal + Vector3(0.0, 0.075, 0.03)
			var hip := ParkKit.BIKE_HIP + Vector3(sg * ParkKit.BIKE_HIP_X, 0.0, 0.0)
			var knee := _knee(hip, ankle, ParkKit.BIKE_THIGH, ParkKit.BIKE_SHIN)
			(info["thighs"][side] as Node3D).transform = _bone(hip, knee)
			(info["shins"][side] as Node3D).transform = _bone(knee, ankle)


## Two-bone IK: the knee between hip and ankle, bending forward (-z) and up.
static func _knee(hip: Vector3, ankle: Vector3, l1: float, l2: float) -> Vector3:
	var d := ankle - hip
	var dist := clampf(d.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.002)
	var v := d.normalized()
	var a := (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
	var h := sqrt(maxf(l1 * l1 - a * a, 0.0))
	var hint := Vector3(0.0, 0.35, -1.0)
	var perp := (hint - v * hint.dot(v)).normalized()
	return hip + v * a + perp * h


## A part hanging from `top` down its -y to `bottom` (ParkKit's thigh and shin), its x kept across the bike.
static func _bone(top: Vector3, bottom: Vector3) -> Transform3D:
	var y := (top - bottom).normalized()
	var x := (Vector3.RIGHT - y * Vector3.RIGHT.dot(y)).normalized()
	var z := x.cross(y)
	return Transform3D(Basis(x, y, z), top)
