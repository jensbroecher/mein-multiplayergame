extends Node3D
## A Kirmes ride turning its child "Rotor" about its local y on the wall clock (Rheinufer's chain swing ride, the
## Kettenkarussell: RheinStadtKit.chair_swing_base / chair_swing_rotor / chair_swing_chair). Every `wait + spin_up + run +
## spin_down` seconds it stands for `wait` (boarding), speeds up, turns at `max_speed` rad/s and slows to a stop, so LAN peers
## see the same without syncing. The chairs are the MultiMesh "Chairs" under the Rotor, one per hang point (`chairs` of
## them round `hang_radius`, at the Rotor's y = 0): each swings out on its `chain_length` as the speed asks (a conical
## pendulum, tan(a) = w^2 (r + L sin a) / g), trails a little while the ride speeds up or slows, and wobbles a touch. With
## `lift` the Rotor rides up its column by that much at full speed. The node's scale (PROP_SCALE) grows it all; the numbers
## here are life size. Nothing moves on a headless server. `clock_override` (>= 0) holds the clock (look-dev, tests).
##
## Its MultiMesh is marked `skip_dressing_colliders` here, and DressingColliders leaves meshes under a script that moves them
## alone: give the ride's base its own colliders (or leave it outside this node).

@export var wait := 25.0
@export var spin_up := 8.0
@export var run := 45.0
@export var spin_down := 10.0
## Full speed, rad/s (1.05: the chairs swing out about 45 degrees).
@export var max_speed := 1.05
@export var hang_radius := 5.2
@export var chain_length := 5.0
@export var chairs := 32
@export var lift := 0.0
@export var phase := 0.0
@export var clock_override := -1.0

const G := 9.81

var _rotor: Node3D
var _mm: MultiMesh
var _rest_y := 0.0
var _swing := 0.0
var _lag := 0.0
var _first := true


func _ready() -> void:
	_rotor = get_node_or_null("Rotor") as Node3D
	if _rotor:
		_rest_y = _rotor.position.y
		var c := _rotor.get_node_or_null("Chairs") as MultiMeshInstance3D
		if c:
			c.set_meta(&"skip_dressing_colliders", true)
			_mm = c.multimesh
	if DisplayServer.get_name() == "headless":
		set_physics_process(false)
		return
	_update(0.0)


# On the physics tick: with physics interpolation on, a MultiMesh's instances are interpolated between ticks.
func _physics_process(delta: float) -> void:
	_update(delta)


## The ride's state at clock `t` for a cycle of (wait, up, run, down) seconds at full speed `w`: x the angle turned (wrapped,
## worked in doubles), y the speed (rad/s), z the angular acceleration.
static func cycle(t: float, wait_s: float, up: float, run_s: float, down: float, w: float) -> Vector3:
	var period: float = wait_s + up + run_s + down
	var per_cycle: float = w * (up * 0.5 + run_s + down * 0.5)
	var n: float = floor(t / period)
	var tau: float = t - n * period
	var base: float = fmod(n * per_cycle, TAU)
	var ang := 0.0
	var spd := 0.0
	var acc := 0.0
	if tau < wait_s:
		pass
	elif tau < wait_s + up:
		var s: float = tau - wait_s
		spd = w * s / up
		ang = w * s * s / (2.0 * up)
		acc = w / up
	elif tau < wait_s + up + run_s:
		var s2: float = tau - wait_s - up
		spd = w
		ang = w * up * 0.5 + w * s2
	else:
		var s3: float = tau - wait_s - up - run_s
		spd = w * (1.0 - s3 / down)
		ang = w * up * 0.5 + w * run_s + w * (s3 - s3 * s3 / (2.0 * down))
		acc = -w / down
	return Vector3(fmod(base + ang, TAU), spd, acc)


func _clock() -> float:
	return clock_override if clock_override >= 0.0 else Time.get_unix_time_from_system() + phase


func _update(delta: float) -> void:
	if _rotor == null:
		return
	var t: float = _clock()
	var st := cycle(t, wait, spin_up, run, spin_down, max_speed)
	_rotor.rotation = Vector3(0.0, -st.x, 0.0)
	var share: float = clampf(st.y / maxf(max_speed, 0.001), 0.0, 1.0)
	_rotor.position.y = _rest_y + lift * share * share * (3.0 - 2.0 * share)
	# The swing out: a conical pendulum at this speed; the lag: the chairs trail the arms' acceleration.
	var a := 0.0
	for i in range(6):
		a = atan(st.y * st.y * (hang_radius + chain_length * sin(a)) / G)
	var lag: float = atan(st.z * (hang_radius + chain_length * sin(a)) / G)
	if _first or clock_override >= 0.0:
		_swing = a
		_lag = lag
		_first = false
	else:
		var k: float = 1.0 - exp(-2.2 * delta)
		_swing = lerpf(_swing, a, k)
		_lag = lerpf(_lag, lag, k)
	if _mm == null:
		return
	var n: int = mini(chairs, _mm.instance_count)
	for i in range(n):
		var phi: float = TAU * float(i) / float(n)
		var r := Vector3(cos(phi), 0.0, sin(phi))
		var tg := Vector3(-sin(phi), 0.0, cos(phi))
		var wob: float = 0.03 * share * sin(t * 1.7 + float(i) * 1.3)
		var b := Basis(r, Vector3.UP, tg)
		b = Basis(tg, _swing + wob) * b
		b = Basis(r, _lag) * b
		_mm.set_instance_transform(i, Transform3D(b, r * hang_radius))
