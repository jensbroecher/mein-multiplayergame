extends MeshInstance3D
## A hot-air balloon drifting in a slow circle over the plain on Mara Crossing, rising and
## sinking a little as it goes. Scenery only: nothing collides with it and nothing is synced.

@export var centre := Vector3.ZERO
@export var radius := 150.0
## Radians per second around the circle (negative: the other way round).
@export var angular_speed := 0.01
@export var phase := 0.0

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	var a: float = phase + _t * angular_speed
	position = centre + Vector3(cos(a) * radius, sin(_t * 0.21 + phase) * 6.0, sin(a) * radius)
	rotation.y = sin(_t * 0.05 + phase) * 0.6
