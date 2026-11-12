extends MeshInstance3D
## A part of a car that spins (the Typhoon's propeller, regenerate_cars.gd's "Prop" node): about its own z, slowly at
## rest, faster with the cart's speed (the nearest RigidBody3D above it: PlayerCart), easing between. On a car with no
## cart over it (the car select's turntable, the garage, the title card) it idles. Looks only: nothing synced.

@export var idle_rate := 9.0
## Radians a second added per metre a second of the cart's speed.
@export var speed_rate := 1.1
@export var max_rate := 52.0

var _body: RigidBody3D
var _rate := 0.0


func _ready() -> void:
	var n: Node = get_parent()
	while n != null:
		if n is RigidBody3D:
			_body = n
			break
		n = n.get_parent()
	_rate = idle_rate


func _process(delta: float) -> void:
	var want := idle_rate
	if is_instance_valid(_body):
		want = minf(idle_rate + _body.linear_velocity.length() * speed_rate, max_rate)
	_rate = lerpf(_rate, want, 1.0 - exp(-delta * 2.5))
	rotate_object_local(Vector3.BACK, _rate * delta)
