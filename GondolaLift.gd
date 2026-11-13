extends Node3D
## A gondola lift (Shuangjiang, regenerate_shuangjiang.gd): little cabins going round a loop of rope between two
## stations, up one rope and down the other, `spacing` metres apart at a steady `speed`, round a bullwheel at each end.
## `a` and `b` are the stations' rope ends (in this node's space, the ropes running from a to b), sagging `sag` metres
## in the middle, the two ropes `gauge` apart (up on the left seen from `a`, down on the right). Every cabin's place is
## a function of the wall clock (seconds into the UTC day, as CableCar.gd's), so every LAN peer sees the same. A cabin is
## `cabin` (a mesh: its hanger's top at the origin, hanging down -y, its length along z). Nothing collides.

@export var a := Vector3.ZERO
@export var b := Vector3(0, 40, -300)
@export var sag := 6.0
@export var gauge := 7.0
@export var speed := 4.0
@export var spacing := 28.0
@export var cabin: Mesh
@export var clock_override := -1.0

var _cabins: Array[Node3D] = []
var _span := 0.0
var _loop := 0.0


func _ready() -> void:
	_span = Vector2(b.x - a.x, b.z - a.z).length()
	_loop = 2.0 * _span + PI * gauge
	var n: int = maxi(int(_loop / spacing), 2)
	for i in range(n):
		var pivot := Node3D.new()
		var mi := MeshInstance3D.new()
		mi.mesh = cabin
		pivot.add_child(mi)
		add_child(pivot)
		_cabins.append(pivot)
	_place(_clock())


func _process(_dt: float) -> void:
	_place(_clock())


func _clock() -> float:
	if clock_override >= 0.0:
		return clock_override
	return fmod(Time.get_unix_time_from_system(), 86400.0)


## The rope's point at u metres round the loop and the way the cabin faces there.
func _at(u: float) -> Array:
	var fwd := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	var left := Vector3(fwd.z, 0.0, -fwd.x)
	var r: float = gauge * 0.5
	u = fposmod(u, _loop)
	if u < _span:
		var f: float = u / _span
		return [a.lerp(b, f) - Vector3(0, sag * 4.0 * f * (1.0 - f), 0) + left * r, fwd]
	u -= _span
	var half_turn: float = PI * r
	if u < half_turn:
		var th: float = u / r
		return [b + left * r * cos(th) + fwd * r * sin(th), (fwd * cos(th) - left * sin(th)).normalized()]
	u -= half_turn
	if u < _span:
		var f2: float = 1.0 - u / _span
		return [a.lerp(b, f2) - Vector3(0, sag * 4.0 * f2 * (1.0 - f2), 0) - left * r, -fwd]
	u -= _span
	var th2: float = u / r
	return [a - left * r * cos(th2) - fwd * r * sin(th2), (-fwd * cos(th2) + left * sin(th2)).normalized()]


func _place(t: float) -> void:
	var n: int = _cabins.size()
	for i in range(n):
		var e: Array = _at(t * speed + _loop * float(i) / float(n))
		var p: Vector3 = e[0]
		var d: Vector3 = e[1]
		_cabins[i].position = p
		_cabins[i].basis = Basis.looking_at(d, Vector3.UP, true) if d.length() > 0.01 else Basis()
