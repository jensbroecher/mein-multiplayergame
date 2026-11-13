extends MeshInstance3D
## A wheel on an axle the game doesn't drive (the Hexapod's middle pair, regenerate_cars.gd's EXTRA_WHEELS): it turns
## with the sibling wheel node named `follow` (its spin, not its place), and hides when that one does (torn off in an
## explosion). Looks only.

@export var follow := "Wheel_RL"

var _src: Node3D


func _ready() -> void:
	_src = get_parent().get_node_or_null(follow) as Node3D
	set_process(_src != null)


func _process(_delta: float) -> void:
	if not is_instance_valid(_src):
		set_process(false)
		return
	transform.basis = _src.transform.basis
	visible = _src.visible
