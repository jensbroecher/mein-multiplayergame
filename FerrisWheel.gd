extends Node3D
## The ferris wheel on its island off Marina Nights' shore (regenerate_marina_nights.gd, _build_wheel). The node stands at
## the hub, the axle along its local z. It turns its child "Rotor" (rims, spokes, hub: MarinaKit.wheel_rotor) once every
## `period` seconds on the wall clock, so LAN peers see the same, and keeps the cabins (the MultiMesh "Cabins", one per
## mount, `cabin_radius` from the hub) hanging level under their mounts as they go round. Nothing is synced. On a
## headless server it stands still.

@export var period := 420.0
@export var cabin_radius := 63.0
@export var cabins := 36

var _rotor: Node3D
var _mm: MultiMesh


func _ready() -> void:
	_rotor = get_node_or_null("Rotor") as Node3D
	var c := get_node_or_null("Cabins") as MultiMeshInstance3D
	if c:
		_mm = c.multimesh
	if DisplayServer.get_name() == "headless":
		set_physics_process(false)
		return
	_update()


# On the physics tick: with physics interpolation on, a MultiMesh's instances are interpolated between ticks.
func _physics_process(_delta: float) -> void:
	_update()


func _update() -> void:
	# The wall clock wraps by the period in doubles before it becomes an angle.
	var a: float = TAU * fposmod(Time.get_unix_time_from_system(), period) / period
	if _rotor:
		_rotor.rotation = Vector3(0.0, 0.0, -a)
	if _mm:
		for i in range(mini(cabins, _mm.instance_count)):
			var b: float = TAU * float(i) / float(cabins) - a
			_mm.set_instance_transform(i, Transform3D(Basis(), Vector3(cos(b), sin(b), 0.0) * cabin_radius))
