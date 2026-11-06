extends Node3D
## Rheinufer's travelling Ferris wheel, the Kronenrad (RheinStadtKit.ferris_wheel_base / _rotor / _gondola). The node
## stands at the hub, the axle along its local z (FerrisWheel.gd's layout). It turns its child "Rotor" about z on the wall
## clock, as a fair's wheel does: it stands `wait` seconds for boarding, speeds up, turns `turns` times and one gondola's
## step more (so the next gondola stops at the platform), slows and stops again; LAN peers see the same without syncing.
## The gondolas hang level under their mounts, `cabin_radius` from the hub: every child MultiMeshInstance3D named
## "Cabins..." holds some of them, instance j on mount `cabin_offset + j * cabin_stride` (its metas; 0 and 1 by default,
## so a single "Cabins" MultiMesh works as on FerrisWheel.gd), so gondolas of several colours can take turns round the rim.
## They swing a little in the wheel's plane as it speeds up, slows and turns (the pull toward the hub at speed).
## The numbers are life size (the node's scale grows them). Nothing moves on a headless server. `clock_override` (>= 0)
## holds the clock.
##
## The cabins' MultiMeshes are marked `skip_dressing_colliders` here; DressingColliders leaves meshes under a script that
## moves them alone, so keep the base (its legs and platform) outside this node or give it colliders of its own.

const KirmesRide = preload("res://KirmesRide.gd")

@export var cabin_radius := 21.0
@export var cabins := 36
@export var wait := 16.0
@export var spin_up := 6.0
@export var run := 75.0
@export var spin_down := 7.0
@export var turns := 2
@export var phase := 0.0
@export var clock_override := -1.0

const G := 9.81

var _rotor: Node3D
var _mms: Array = []    # [MultiMesh, offset, stride]


func _ready() -> void:
	_rotor = get_node_or_null("Rotor") as Node3D
	for c in get_children():
		var mmi := c as MultiMeshInstance3D
		if mmi and String(mmi.name).begins_with("Cabins"):
			mmi.set_meta(&"skip_dressing_colliders", true)
			_mms.append([mmi.multimesh, int(mmi.get_meta(&"cabin_offset", 0)), maxi(int(mmi.get_meta(&"cabin_stride", 1)), 1)])
	if DisplayServer.get_name() == "headless":
		set_physics_process(false)
		return
	_update()


# On the physics tick: with physics interpolation on, a MultiMesh's instances are interpolated between ticks.
func _physics_process(_delta: float) -> void:
	_update()


## Full speed (rad/s): `turns` turns and one gondola's step over the cycle's moving part.
func speed() -> float:
	var total: float = float(turns) * TAU + TAU / float(maxi(cabins, 1))
	return total / maxf(spin_up * 0.5 + run + spin_down * 0.5, 0.001)


func _update() -> void:
	var t: float = clock_override if clock_override >= 0.0 else Time.get_unix_time_from_system() + phase
	var st: Vector3 = KirmesRide.cycle(t, wait, spin_up, run, spin_down, speed())
	var a: float = st.x
	if _rotor:
		_rotor.rotation = Vector3(0.0, 0.0, -a)
	for m in _mms:
		var mm: MultiMesh = m[0]
		if mm == null:
			continue
		var off: int = m[1]
		var stride: int = m[2]
		for j in range(mm.instance_count):
			var i: int = off + j * stride
			if i >= cabins:
				break
			var b: float = TAU * float(i) / float(cabins) - a
			# The pivot's acceleration across (tangential, and toward the hub at speed); the gondola hangs against it.
			var ax: float = st.z * cabin_radius * sin(b) - st.y * st.y * cabin_radius * cos(b)
			var sway: float = -atan(ax / G)
			mm.set_instance_transform(j, Transform3D(Basis(Vector3(0, 0, 1), sway), Vector3(cos(b), sin(b), 0.0) * cabin_radius))
