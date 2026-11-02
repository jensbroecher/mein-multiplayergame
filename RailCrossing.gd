extends Node3D
## A level crossing (Freight Line): flashing lights, a bell and a barrier arm across each side of the road,
## driven by the timetable of the Train that runs over it. The node stands on the road where the rails cross
## it, turned like a checkpoint gate (-z the way of travel, +x right), at the rails' top height.
##
## The lights start `warn_lead` seconds before the first car (with the horn), the arms are down
## `arm_delay` seconds after that, and everything stays on until `hold` seconds after the last car. The
## barriers are not solid: a cart that runs one is judged by the train alone. Warning is worked out from the
## same wall clock as the train, so every peer sees and hears it at the same moment, and the AI asks
## `is_closed_for(eta)` to decide whether to stop (PlayerCart._ai_rail_crossing_override).
##
## The masts, arms and signs are internal children built on load: the level stores the transform and the
## exports.

const PropKit = preload("res://PropKit.gd")
const FreightKit = preload("res://FreightKit.gd")

@export var train_path: NodePath
## Every train that runs over the crossing (node paths as strings, from this node): a line may carry a freight
## train and an express. `train_path` alone still works.
@export var train_paths := PackedStringArray()
## Metres along the train's path where this crossing lies.
@export var train_s := 0.0
@export var road_half := 7.0
@export var warn_lead := 6.5
@export var arm_delay := 1.5
@export var lower_time := 1.6
@export var hold := 1.2
## The train's length either side of a car counted as blocking (a cart's size).
@export var pad := 2.5
## Metres either side of the rail the arms stand.
@export var arm_offset := 5.2
## How far short of the crossing a bot stops for a train (further where a kicker lies before it).
@export var ai_stop_short := 15.0

const OPEN_ANGLE := deg_to_rad(82.0)
const ARM_LEN := 9.2
const MAST_H := 5.4

var _trains: Array = []
var _arms: Array[Node3D] = []
var _lamp_mats: Array[StandardMaterial3D] = []
var _bell: AudioStreamPlayer3D
var _horn: AudioStreamPlayer3D
var _arm := 0.0
var _was_warning := false
var warning := false


func _ready() -> void:
	add_to_group("rail_crossings")
	_build()
	_resolve_trains()


func _resolve_trains() -> void:
	_trains.clear()
	var paths: Array = []
	if train_path != NodePath():
		paths.append(train_path)
	for p in train_paths:
		paths.append(NodePath(p))
	for p in paths:
		var t: Node = get_node_or_null(p)
		if t != null and t.has_method("pass_window"):
			_trains.append(t)


func _build() -> void:
	var pk := FreightKit.new_kit()
	var white := Color(0.92, 0.91, 0.88)
	var red := Color(0.80, 0.09, 0.07)
	# Two lamp materials that take turns.
	for k in 2:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.25, 0.02, 0.02)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.06, 0.04)
		m.emission_energy_multiplier = 0.0
		m.roughness = 0.3
		_lamp_mats.append(m)
	for side in 2:
		var sgn: float = 1.0 if side == 0 else -1.0
		# side 0 stands before the rails (z +), on the right of the road for the lap's traffic; side 1 mirrors it.
		var z: float = arm_offset * sgn
		var x: float = (road_half + 1.9) * sgn
		var mast := Node3D.new()
		mast.name = "Mast%d" % side
		mast.position = Vector3(x, 0.0, z)
		# Faces the traffic it warns: side 0's light faces +z, side 1's -z.
		mast.basis = Basis(Vector3.UP, 0.0 if side == 0 else PI)
		add_child(mast, false, Node.INTERNAL_MODE_BACK)

		var mast_body := StaticBody3D.new()
		mast_body.name = "Collider"
		mast_body.set_meta(&"surface", "metal")
		var base_col := CollisionShape3D.new()
		var base_box := BoxShape3D.new()
		base_box.size = Vector3(1.0, 0.6, 1.0)
		base_col.shape = base_box
		base_col.position = Vector3(0, 0.3, 0)
		mast_body.add_child(base_col)
		var pole_col := CollisionShape3D.new()
		var pole_cyl := CylinderShape3D.new()
		pole_cyl.radius = 0.28
		pole_cyl.height = MAST_H
		pole_col.shape = pole_cyl
		pole_col.position = Vector3(0, MAST_H * 0.5, 0)
		mast_body.add_child(pole_col)
		mast.add_child(mast_body)
		var kit := {}
		pk.set_frame(Transform3D.IDENTITY)
		pk.beam(kit, "steel", Vector3(0, 0, 0), Vector3(0, MAST_H, 0), 0.36, 0.36, Color(0.86, 0.86, 0.84))
		pk.beam(kit, "steel", Vector3(0, 0, 0), Vector3(0, 0.5, 0), 0.9, 0.9, Color(0.35, 0.35, 0.35))
		# The crossbuck: two white boards crossed, edged red.
		var cb := Vector3(0, MAST_H - 0.9, 0.25)
		for ang in [0.62, -0.62]:
			var d := Vector3(sin(ang), cos(ang) * 0.0 + 0.0, 0.0)
			var a: Vector3 = cb + Vector3(-1.5 * cos(ang), -1.5 * sin(ang), 0.0)
			var b: Vector3 = cb + Vector3(1.5 * cos(ang), 1.5 * sin(ang), 0.0)
			pk.beam(kit, "paint", a, b, 0.62, 0.1, white, Vector3(0, 0, 1))
			pk.beam(kit, "paint", a, b, 0.4, 0.14, red, Vector3(0, 0, 1))
			pk.beam(kit, "paint", a, b, 0.26, 0.16, white, Vector3(0, 0, 1))
		# The light bar and its two lamps, a black backing disc each.
		var bar_y: float = MAST_H - 2.35
		pk.beam(kit, "steel", Vector3(-1.2, bar_y, 0.0), Vector3(1.2, bar_y, 0.0), 0.2, 0.2, Color(0.12, 0.12, 0.12))
		for lx in [-1.2, 1.2]:
			pk.tube(kit, "steel", Vector3(lx, bar_y, 0.02), Vector3(lx, bar_y, 0.3), 0.62, 0.62, 14, Color(0.07, 0.07, 0.07))
		var mi := MeshInstance3D.new()
		mi.name = "Mast"
		mi.mesh = pk.commit(kit)
		mast.add_child(mi)
		for li in 2:
			var lamp := MeshInstance3D.new()
			lamp.name = "Lamp%d" % li
			var sph := SphereMesh.new()
			sph.radius = 0.42
			sph.height = 0.5
			sph.radial_segments = 14
			sph.rings = 6
			lamp.mesh = sph
			lamp.material_override = _lamp_mats[li]
			lamp.position = Vector3(-1.2 if li == 0 else 1.2, bar_y, 0.34)
			lamp.scale = Vector3(1, 1, 0.55)
			mast.add_child(lamp)
		# The barrier arm: red and white stripes along +x from its pivot, which opens upward.
		var pivot := Node3D.new()
		pivot.name = "ArmPivot%d" % side
		pivot.position = Vector3(x, 2.1, z)
		# +x of the pivot points at the road's centre.
		pivot.basis = Basis(Vector3.UP, PI if side == 0 else 0.0)
		add_child(pivot, false, Node.INTERNAL_MODE_BACK)
		var ak := {}
		var seg := 0.92
		var n := int(ARM_LEN / seg)
		for k in range(n):
			var c: Color = red if k % 2 == 0 else white
			pk.beam(ak, "paint", Vector3(float(k) * seg, 0, 0), Vector3(float(k + 1) * seg, 0, 0), 0.34, 0.34, c)
		pk.beam(ak, "steel", Vector3(-0.5, 0, 0), Vector3(0.7, 0, 0), 0.5, 0.5, Color(0.2, 0.2, 0.2))
		pk.beam(ak, "steel", Vector3(-0.9, 0, 0), Vector3(-0.2, 0, 0), 0.7, 0.7, Color(0.12, 0.12, 0.12))
		var arm := MeshInstance3D.new()
		arm.name = "Arm"
		arm.mesh = pk.commit(ak)
		pivot.add_child(arm)
		_arms.append(arm)
	_bell = AudioStreamPlayer3D.new()
	_bell.stream = FreightKit.bell()
	_bell.bus = &"SFX"
	_bell.volume_db = 2.0
	_bell.unit_size = 22.0
	_bell.max_distance = 300.0
	add_child(_bell, false, Node.INTERNAL_MODE_BACK)
	_horn = AudioStreamPlayer3D.new()
	_horn.stream = FreightKit.horn()
	_horn.bus = &"SFX"
	_horn.volume_db = 4.0
	_horn.unit_size = 45.0
	_horn.max_distance = 700.0
	_horn.position = Vector3(0, 6.0, 0)
	add_child(_horn, false, Node.INTERNAL_MODE_BACK)
	_set_arm(0.0)


func _set_arm(v: float) -> void:
	# Eased: the arm drops under its own weight, so it moves faster at first.
	var e: float = 1.0 - pow(1.0 - v, 2.0)
	var angle: float = OPEN_ANGLE * (1.0 - e)
	for a in _arms:
		a.rotation = Vector3(0, 0, angle)


func _physics_process(delta: float) -> void:
	if _trains.is_empty():
		_resolve_trains()
		return
	# The warning: any of any train's passes, from `warn_lead` before its first car to `hold` after its last, and
	# how long the earliest of those has been on. A train that comes back the way it went (Freight Line's local)
	# passes twice a cycle, each pass its own window.
	warning = false
	var since := 0.0
	var tt := 0.0
	for t in _trains:
		tt = t.cycle_time()
		var period: float = t.period
		for win in _windows(t):
			for x in [tt, tt - period, tt + period]:
				if x >= float(win[0]) - warn_lead and x <= float(win[1]) + hold:
					warning = true
					since = maxf(since, x - (float(win[0]) - warn_lead))
	var target: float = 1.0 if warning and since >= arm_delay else 0.0
	_arm = move_toward(_arm, target, delta / lower_time)
	_set_arm(_arm)
	if warning:
		var flash: float = fmod(Time.get_unix_time_from_system(), 86400.0)
		var on: bool = int(floor(flash * 2.2)) % 2 == 0
		_lamp_mats[0].emission_energy_multiplier = 5.0 if on else 0.15
		_lamp_mats[1].emission_energy_multiplier = 0.15 if on else 5.0
		if not _bell.playing:
			_bell.play()
		if not _was_warning and since < 1.0 and not _horn.playing:
			_horn.play()
	else:
		_lamp_mats[0].emission_energy_multiplier = 0.0
		_lamp_mats[1].emission_energy_multiplier = 0.0
		if _bell.playing:
			_bell.stop()
	_was_warning = warning


## Whether a cart that reaches the crossing `eta` seconds from now would meet the train: the pass, widened a
## little for the cart's own length and the time it takes to cross.
func is_closed_for(eta: float, margin := 1.0) -> bool:
	for t in _trains:
		var tt: float = t.cycle_time()
		var period: float = t.period
		for win in _windows(t):
			for x in [tt + eta, tt + eta - period, tt + eta + period]:
				if x >= float(win[0]) - margin and x <= float(win[1]) + margin:
					return true
	return false


## A train's passes over this crossing, each as [start, end] in its cycle.
func _windows(t: Node) -> Array:
	if t.has_method("pass_windows"):
		return t.pass_windows(train_s, pad)
	var win: Array = t.pass_window(train_s, pad)
	return [] if win.is_empty() else [win]
