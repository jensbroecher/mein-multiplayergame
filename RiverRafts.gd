extends Node3D
## Yoshino Rapids' log rafts (regenerate_yoshino_rapids.gd). Children named "Moored_*" are the raft train lying across
## the pool: they bob and sway a little where they are (their collision is a row of still boxes of its own, so the
## cars' footing never moves). Children named "Drift_*" are rafts floating down the river: they follow `drift_path`
## (points along the river's line, y the water's level) at `drift_speed`, evenly spaced, round and round, turning with
## the stream. All on the wall clock, so LAN peers see the same; nothing moves on a headless server.

@export var drift_path: PackedVector3Array = PackedVector3Array()
@export var drift_speed := 2.6
@export var bob := 0.05
@export var sway := 0.14

var _moored: Array = []
var _rest: Array = []
var _drift: Array = []
var _lengths := PackedFloat32Array()
var _total := 0.0


func _ready() -> void:
	if Engine.is_editor_hint() or DisplayServer.get_name() == "headless" or _in_generator():
		set_process(false)
		return
	for c in get_children():
		if c is Node3D and str(c.name).begins_with("Moored_"):
			_moored.append(c)
			_rest.append((c as Node3D).transform)
		elif c is Node3D and str(c.name).begins_with("Drift_"):
			_drift.append(c)
	_lengths.resize(drift_path.size())
	for i in range(1, drift_path.size()):
		_total += drift_path[i - 1].distance_to(drift_path[i])
		_lengths[i] = _total


func _in_generator() -> bool:
	for child in get_tree().root.get_children():
		if "regenerate" in str(child.name).to_lower():
			return true
	return false


func _at(d: float) -> Transform3D:
	d = fposmod(d, _total)
	var lo := 0
	var hi: int = _lengths.size() - 1
	while hi - lo > 1:
		var mid: int = (lo + hi) >> 1
		if _lengths[mid] <= d:
			lo = mid
		else:
			hi = mid
	var a: Vector3 = drift_path[lo]
	var b: Vector3 = drift_path[hi]
	var t: float = (d - _lengths[lo]) / maxf(_lengths[hi] - _lengths[lo], 0.001)
	var fwd: Vector3 = (b - a)
	fwd.y = 0.0
	fwd = fwd.normalized()
	return Transform3D(Basis(Vector3.UP.cross(fwd).normalized(), Vector3.UP, fwd), a.lerp(b, t))


func _process(_delta: float) -> void:
	var t: float = fposmod(Time.get_unix_time_from_system(), 86400.0)
	for i in range(_moored.size()):
		var rest: Transform3D = _rest[i]
		var ph: float = float(i) * 1.7
		var up: float = sin(t * 1.3 + ph) * bob
		var side: float = sin(t * 0.45 + ph * 0.6) * sway
		var roll := Basis(rest.basis.z.normalized(), sin(t * 1.1 + ph) * 0.012)
		(_moored[i] as Node3D).transform = Transform3D(roll * rest.basis, rest.origin + Vector3(0, up, 0) + rest.basis.x.normalized() * side)
	if _total < 1.0:
		return
	for i in range(_drift.size()):
		var d: float = t * drift_speed + _total * float(i) / float(_drift.size())
		var xf: Transform3D = _at(d)
		var n: Node3D = _drift[i]
		var s: Vector3 = n.scale
		var ph2: float = float(i) * 2.3
		xf.origin.y += sin(t * 1.2 + ph2) * bob
		xf.basis = Basis(Vector3.UP, sin(t * 0.2 + ph2) * 0.25) * xf.basis
		n.transform = Transform3D(xf.basis.scaled(s), xf.origin)
