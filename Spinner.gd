extends Node3D
## Turns this node about its own `axis` at `degrees_per_second` on the wall clock (so LAN peers see the same angle):
## Rheinufer's tower windmill's sails. Holds still on a headless server.

@export var axis := Vector3(0, 0, 1)
@export var degrees_per_second := 12.0

var _rest: Basis


func _ready() -> void:
	_rest = transform.basis
	if DisplayServer.get_name() == "headless":
		set_process(false)


func _process(_delta: float) -> void:
	var t: float = fposmod(Time.get_unix_time_from_system(), 86400.0)
	var ang: float = deg_to_rad(fposmod(t * degrees_per_second, 360.0))
	transform.basis = _rest * Basis(axis.normalized(), ang)
