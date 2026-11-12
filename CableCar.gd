extends Node3D
## An aerial cableway (Wangjiang, regenerate_wangjiang.gd): two cabins hung from a track rope between `a` and `b` (the
## ropes' ends, in this node's space), sagging `sag` metres in the middle, shuttling on the wall clock (seconds into the
## UTC day, as Train.gd's and Monorail.gd's), so every LAN peer sees them in the same place without syncing. One cabin
## leaves each end at once and they pass in the middle (a jig-back ropeway): each speeds up at `accel` to `cruise`,
## brakes into the far station, waits `dwell` and comes back. The two ropes stand `gauge` apart; cabin 0 runs on the
## left rope (seen from `a`), cabin 1 on the right. A cabin is `cabin` (a mesh: its hanger's top at the origin, hanging
## down -y, its length along z), swinging a little fore and aft as it speeds up and brakes. Nothing collides.

@export var a := Vector3.ZERO
@export var b := Vector3(0, 0, 500)
@export var sag := 20.0
@export var gauge := 12.0
@export var cruise := 8.0
@export var accel := 0.5
@export var dwell := 25.0
@export var cabin: Mesh
@export var clock_override := -1.0

var _cabins: Array[Node3D] = []
var _length := 0.0


func _ready() -> void:
	_length = Vector2(b.x - a.x, b.z - a.z).length()
	for i in 2:
		var pivot := Node3D.new()
		pivot.name = "Cabin%d" % i
		var mi := MeshInstance3D.new()
		mi.mesh = cabin
		pivot.add_child(mi)
		add_child(pivot, false, Node.INTERNAL_MODE_BACK)
		_cabins.append(pivot)
	_place(_now())


func _process(_delta: float) -> void:
	_place(_now())


func _now() -> float:
	if clock_override >= 0.0:
		return clock_override
	return fmod(Time.get_unix_time_from_system(), 86400.0)


## Where on the rope (0 at a, 1 at b) a cabin that left a at the start of the cycle is at time t, and its speed's sign.
func _travel(t: float) -> Array:
	var ta: float = cruise / accel
	var da: float = 0.5 * accel * ta * ta
	var run: float
	if 2.0 * da >= _length:
		ta = sqrt(_length / accel)
		run = 2.0 * ta
	else:
		run = 2.0 * ta + (_length - 2.0 * da) / cruise
	var period: float = 2.0 * (run + dwell)
	var u: float = fposmod(t, period)
	var leg := 0
	if u > run + dwell:
		u -= run + dwell
		leg = 1
	var d: float
	var v: float
	if u >= run:
		d = _length
		v = 0.0
	elif u < ta:
		d = 0.5 * accel * u * u
		v = accel * u
	elif u > run - ta:
		var r: float = run - u
		d = _length - 0.5 * accel * r * r
		v = accel * r
	else:
		d = 0.5 * accel * ta * ta + cruise * (u - ta)
		v = cruise
	var f: float = clampf(d / maxf(_length, 0.001), 0.0, 1.0)
	if leg == 1:
		return [1.0 - f, -v]
	return [f, v]


func _rope_point(f: float, side: float) -> Vector3:
	var p: Vector3 = a.lerp(b, f) - Vector3(0, sag * 4.0 * f * (1.0 - f), 0)
	var across: Vector3 = Vector3.UP.cross(b - a).normalized()
	return p + across * side * gauge * 0.5


func _place(t: float) -> void:
	if _cabins.is_empty():
		return
	var tr: Array = _travel(t)
	var fwd: Vector3 = Vector3(b.x - a.x, 0, b.z - a.z).normalized()
	for i in 2:
		var f: float = tr[0] if i == 0 else 1.0 - float(tr[0])
		var side: float = -1.0 if i == 0 else 1.0
		var p: Vector3 = _rope_point(f, side)
		var cab: Node3D = _cabins[i]
		cab.position = p
		# A small swing with the speed's change near the stations.
		var near_end: float = 1.0 - smoothstep(0.0, 0.08, minf(f, 1.0 - f))
		var swing: float = 0.06 * near_end * signf(float(tr[1])) * (1.0 if i == 0 else -1.0)
		cab.basis = Basis.looking_at(fwd, Vector3.UP).rotated(Vector3.UP.cross(fwd).normalized(), swing) if fwd.length() > 0.5 else Basis()
