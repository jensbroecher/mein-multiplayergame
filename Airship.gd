extends Node3D
## The airship over the Lakeside Meadows (regenerate_lakeside.gd, _build_airship): it flies an ellipse round the course
## (`centre`, `radii`, at `altitude`) at `speed`, placed from the wall clock (Time.get_unix_time_from_system) like
## SeaBoat.gd's boats, so every LAN peer sees it in the same place. It banks a little into its turn, its nose rises
## and falls slowly, and its propellers (children named "Prop*", ParkKit.ship_prop, turning about z) spin. The
## generator saves its meshes and labels as children; this only moves them.

@export var centre := Vector3.ZERO
@export var radii := Vector2(500.0, 400.0)
@export var altitude := 150.0
@export var speed := 12.0
## Where on its round it is at the epoch (radians).
@export var phase := 0.0
## Clockwise seen from above (true) or not.
@export var clockwise := true
@export var prop_spin := 9.0

var _props: Array[Node3D] = []


func _ready() -> void:
	for c in get_children():
		if String(c.name).begins_with("Prop") and c is Node3D:
			_props.append(c)
	_place()


func _process(_delta: float) -> void:
	_place()


## The ellipse's point and heading at angle `a` (radians).
func _at(a: float) -> Vector3:
	return centre + Vector3(cos(a) * radii.x, 0.0, sin(a) * radii.y)


func _place() -> void:
	var now := Time.get_unix_time_from_system()
	# An ellipse's perimeter (Ramanujan), so the speed along it is about `speed`.
	var a := radii.x
	var b := radii.y
	var h := pow(a - b, 2.0) / pow(a + b, 2.0)
	var perimeter := PI * (a + b) * (1.0 + 3.0 * h / (10.0 + sqrt(4.0 - 3.0 * h)))
	var turns: float = fmod(float(now) * speed / perimeter, 1.0)
	var ang: float = phase + TAU * turns * (-1.0 if clockwise else 1.0)
	var p := _at(ang)
	var ahead := _at(ang + 0.01 * (-1.0 if clockwise else 1.0))
	var fwd := (ahead - p).normalized()
	var t := float(fmod(now, 3600.0))
	p.y = altitude + sin(t * 0.21) * 1.6
	var basis := Basis.looking_at(fwd, Vector3.UP)
	# A gentle bank into the turn and a slow pitch.
	var bank := 0.05 * (1.0 if clockwise else -1.0)
	basis = basis * Basis(Vector3.BACK, bank) * Basis(Vector3.RIGHT, sin(t * 0.13) * 0.025)
	global_transform = Transform3D(basis, p)
	var spin := fmod(t * prop_spin, TAU)
	for pr in _props:
		pr.rotation = Vector3(0.0, 0.0, spin)
