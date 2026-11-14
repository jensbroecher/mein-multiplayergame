extends MeshInstance3D
## A part of a car that steers with its front wheels (the Tuk-Tuk's fork, mudguard and handlebars: regenerate_cars.gd's
## STEERED_PARTS): turned about its own y (its rest basis's up, which a raked steering column tilts back) by the angle
## PlayerCart turns the front wheels' pivots (`_update_wheel_visuals`, the remote carts' too), times `gain`. The car's
## Model frame is its Visuals' (the root's half turn and x2 undone inside), so the angle carries over as it is. On a car
## with no cart over it (the car select's turntable, the garage, the title card, a time trial's ghost) it stands still.
## Looks only: nothing synced.

@export var gain := 1.0
## The most it turns either way (radians): an exploding cart flings its wheel pivots about.
@export var limit := 0.75

var _rest := Basis()
var _pivot: Node3D


func _ready() -> void:
	_rest = transform.basis
	var n: Node = get_parent()
	while n != null:
		if n is RigidBody3D:
			_pivot = n.get_node_or_null("Visuals/WheelPivotFR") as Node3D
			break
		n = n.get_parent()
	set_process(_pivot != null)


func _process(_delta: float) -> void:
	if not is_instance_valid(_pivot):
		set_process(false)
		return
	var a: float = clampf(wrapf(_pivot.rotation.y, -PI, PI) * gain, -limit, limit)
	transform.basis = _rest * Basis(Vector3.UP, a)
