extends MultiMeshInstance3D
## Tumbleweeds blowing across Mina del Viento's shelf road in the haboob (regenerate_mina.gd). Each rolls along a path
## of its own (`paths`: start and end, the ground's height at PATH_SAMPLES points between, berms included), bounding
## and spinning, once every `period` seconds on the wall clock, so LAN peers see the same weeds. A cart that runs into
## one sends it flying in pieces of straw and loses a little speed (if this peer drives it); the weed is back on its
## next pass. Local scenery: nothing is synced.

const PATH_SAMPLES := 16
## The weed's radius (the mesh's, as grown), and how far from a cart's middle it is hit.
const RADIUS := 0.72
const HIT_REACH := 2.3
## A hit cart keeps this share of its speed.
const HIT_KEEP := 0.985

## Per weed: start and end (Vector3, y unused), PATH_SAMPLES ground heights, its speed, period and phase.
@export var starts := PackedVector3Array()
@export var ends := PackedVector3Array()
@export var heights := PackedFloat32Array()
@export var speeds := PackedFloat32Array()
@export var periods := PackedFloat32Array()
@export var phases := PackedFloat32Array()

var _kicked: Dictionary = {}   # weed -> [time kicked, cycle, position, velocity, spin axis]
var _last_pos: Dictionary = {} # cart -> position last frame (velocity of carts this peer doesn't drive)


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)


func _clock() -> float:
	return fmod(Time.get_unix_time_from_system(), 86400.0)


## Where weed `i` is at `t` and how far along: [position, distance rolled, cycle, rolling].
func _state(i: int, t: float) -> Array:
	var a: Vector3 = starts[i]
	var b: Vector3 = ends[i]
	var length: float = Vector2(b.x - a.x, b.z - a.z).length()
	var v: float = speeds[i]
	var per: float = periods[i]
	var cyc: float = floor((t + phases[i] * per) / per)
	var u: float = fposmod(t + phases[i] * per, per)
	var d: float = u * v
	if d > length:
		return [Vector3.ZERO, 0.0, cyc, false]
	var f: float = d / length
	var k: float = f * float(PATH_SAMPLES - 1)
	var k0: int = mini(int(floor(k)), PATH_SAMPLES - 2)
	var gy: float = lerpf(heights[i * PATH_SAMPLES + k0], heights[i * PATH_SAMPLES + k0 + 1], k - float(k0))
	# Bounding: a hop every couple of metres, higher now and then.
	var hop: float = absf(sin(d * 0.9 + float(i))) * (0.35 + 0.55 * absf(sin(d * 0.21 + float(i) * 2.0)))
	var p := Vector3(lerpf(a.x, b.x, f), gy + RADIUS + hop, lerpf(a.z, b.z, f))
	return [p, d, cyc, true]


func _process(delta: float) -> void:
	var t: float = _clock()
	var n: int = starts.size()
	if multimesh == null or multimesh.instance_count != n:
		return
	var carts: Array = get_tree().get_nodes_in_group("player_carts")
	var cart_vel := {}
	for c in carts:
		if not (c is Node3D) or not is_instance_valid(c):
			continue
		var cp: Vector3 = (c as Node3D).global_position
		var vel := Vector3.ZERO
		if c is RigidBody3D:
			vel = (c as RigidBody3D).linear_velocity
		if vel.length_squared() < 0.01 and _last_pos.has(c) and delta > 0.0:
			vel = (cp - (_last_pos[c] as Vector3)) / delta
		_last_pos[c] = cp
		cart_vel[c] = vel
	for i in range(n):
		var st: Array = _state(i, t)
		var xf := Transform3D(Basis(), Vector3(0, -1000, 0)).scaled(Vector3.ONE * 0.001)
		if _kicked.has(i):
			var kk: Array = _kicked[i]
			var age: float = t - float(kk[0])
			if float(st[2]) != float(kk[1]) or age > 2.0 or age < 0.0:
				_kicked.erase(i)
			else:
				var pos: Vector3 = (kk[2] as Vector3) + (kk[3] as Vector3) * age + Vector3.DOWN * 9.0 * age * age
				var shrink: float = 1.0 - smoothstep(0.9, 2.0, age)
				xf = Transform3D(Basis(kk[4], age * 14.0).scaled(Vector3.ONE * maxf(shrink, 0.001)), pos)
				multimesh.set_instance_transform(i, xf)
				continue
		if st[3]:
			var p: Vector3 = st[0]
			var dir: Vector3 = (ends[i] - starts[i])
			dir.y = 0.0
			dir = dir.normalized()
			var axis: Vector3 = Vector3.UP.cross(dir).normalized()
			xf = Transform3D(Basis(axis, float(st[1]) / RADIUS) * Basis(Vector3.UP, float(i) * 1.7), p)
			for c in cart_vel:
				var cp2: Vector3 = (c as Node3D).global_position
				var vel2: Vector3 = cart_vel[c]
				if vel2.length() < 4.0 or Vector2(cp2.x - p.x, cp2.z - p.z).length() > HIT_REACH or absf(cp2.y - p.y) > 3.0:
					continue
				var kick: Vector3 = vel2 * 0.85 + Vector3.UP * 7.0 + dir * 3.0
				_kicked[i] = [t, st[2], p, kick, (vel2.cross(Vector3.UP) + Vector3(0.2, 0.1, 0.0)).normalized()]
				if c.has_method("has_physics_authority") and c.has_physics_authority() and c is RigidBody3D:
					(c as RigidBody3D).linear_velocity *= HIT_KEEP
				break
		multimesh.set_instance_transform(i, xf)
