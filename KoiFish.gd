extends MultiMeshInstance3D
## Koi in Yoshino Rapids' garden (regenerate_yoshino_rapids.gd, _build_koi): one MultiMesh of fish (koi.gdshader swishes
## their tails), each on a swim of its own on the wall clock, so LAN peers see the same. A swim is a row of `swims`:
##   kind 0, a circle in the pool: a = its centre (y the fish's depth), b.x its radius, b.y the speed (m/s); clockwise
##        when the speed is negative
##   kind 1, a beat in the stream: a = the upstream end, b = the downstream end (the fish holds station between them,
##        drifting back and pushing up again, nose upstream), speed how fast it beats
## and `sizes` the fish's scales. Still on a headless server and in the generator.
##
## They take fright: a cart that comes into the water near one (any cart this peer sees, from how far it moved) sends
## it darting away (`SCARE_*`), its tail beating hard (the instance's custom alpha) and turned along its dash, before it
## eases back into its swim. Local to every peer.

@export var kinds := PackedInt32Array()
@export var a_pts := PackedVector3Array()
@export var b_pts := PackedVector3Array()
@export var speeds := PackedFloat32Array()
@export var phases := PackedFloat32Array()
@export var sizes := PackedFloat32Array()
## Where the fish are (the instances are in world space, the node at the origin): they swim only while a camera is
## within `visibility_range_end` of it.
@export var centre := Vector3.ZERO

var _active := true

## A cart within this (plan) of a fish and at most `SCARE_UP` over it frightens it.
const SCARE_R := 5.0
const SCARE_UP := 2.2
## How hard it darts (m/s^2 at the closest), how fast its dash dies away and how far it may stray from its swim.
const SCARE_ACCEL := 26.0
const SCARE_DAMP := 2.2
const SCARE_RETURN := 0.35
const SCARE_MAX := 3.2
const SCARE_SPEED := 4.5

var _off: Array = []         # each fish's offset from its swim (Vector3)
var _vel: Array = []         # its dash (Vector3)
var _fear := PackedFloat32Array()
var _base_custom: Array = []
var _cart_last := {}         # instance id -> last position (for the carts' speeds)


func _ready() -> void:
	if Engine.is_editor_hint() or DisplayServer.get_name() == "headless" or _in_generator():
		_active = false
		set_process(false)
		return
	# Moved every drawn frame (from _process), not on the physics tick: the project's physics interpolation would warn
	# and lag them.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _in_generator() -> bool:
	for child in get_tree().root.get_children():
		if "regenerate" in str(child.name).to_lower():
			return true
	return false


## The fish's place and heading at time t (seconds).
func pose_at(i: int, t: float) -> Transform3D:
	var a: Vector3 = a_pts[i]
	var b: Vector3 = b_pts[i]
	var sp: float = speeds[i]
	var ph: float = phases[i]
	var pos: Vector3
	var fwd: Vector3
	if kinds[i] == 0:
		var r: float = b.x
		var ang: float = ph + t * sp / maxf(r, 0.1)
		var wob: float = r * (1.0 + 0.12 * sin(t * 0.37 + ph * 3.0))
		pos = a + Vector3(cos(ang) * wob, 0.04 * sin(t * 0.8 + ph), sin(ang) * wob)
		fwd = Vector3(-sin(ang), 0.0, cos(ang)) * signf(sp)
	else:
		var u: float = 0.5 + 0.5 * sin(t * sp + ph)
		var along: Vector3 = (a - b)
		along.y = 0.0
		fwd = along.normalized()
		var side := Vector3(-fwd.z, 0.0, fwd.x)
		pos = b.lerp(a, u) + side * 0.25 * sin(t * 0.51 + ph * 2.0)
		# A little yaw as it works against the current.
		fwd = (fwd + side * 0.15 * sin(t * 1.3 + ph)).normalized()
	var x: Vector3 = Vector3.UP.cross(fwd).normalized()
	return Transform3D(Basis(x, Vector3.UP, fwd).scaled(Vector3.ONE * sizes[i]), pos)


func _process(delta: float) -> void:
	if not _active or multimesh == null or not is_visible_in_tree():
		return
	var cam := get_viewport().get_camera_3d()
	if cam and visibility_range_end > 0.0 and cam.global_position.distance_to(centre) > visibility_range_end + 40.0:
		return
	var t: float = fposmod(Time.get_unix_time_from_system(), 86400.0)
	var n: int = mini(multimesh.instance_count, kinds.size())
	if _off.size() != n:
		_off.resize(n)
		_vel.resize(n)
		_fear.resize(n)
		_base_custom.resize(n)
		for i in range(n):
			_off[i] = Vector3.ZERO
			_vel[i] = Vector3.ZERO
			_fear[i] = 0.0
			_base_custom[i] = multimesh.get_instance_custom_data(i) if multimesh.use_custom_data else Color()
	var carts: Array = _carts_near(delta)
	var dt: float = minf(delta, 0.05)
	for i in range(n):
		var pose: Transform3D = pose_at(i, t)
		var off: Vector3 = _off[i]
		var vel: Vector3 = _vel[i]
		var fear: float = _fear[i]
		var at: Vector3 = pose.origin + off
		var threat := false
		for c in carts:
			var cp: Vector3 = c[0]
			var away := Vector3(at.x - cp.x, 0.0, at.z - cp.z)
			var d: float = away.length()
			if d > SCARE_R or cp.y - at.y > SCARE_UP or cp.y < at.y - 1.5:
				continue
			threat = true
			var k: float = (1.0 - d / SCARE_R) * clampf(0.4 + float(c[1]) / 8.0, 0.4, 1.4)
			var dir: Vector3 = away / maxf(d, 0.05) if d > 0.05 else pose.basis.z.normalized()
			# In a stream the fish shoots along it: up or down whichever way leads away.
			if kinds[i] == 1:
				var along: Vector3 = (a_pts[i] - b_pts[i])
				along.y = 0.0
				along = along.normalized()
				dir = along * (1.0 if dir.dot(along) >= 0.0 else -1.0) + dir * 0.25
			vel += dir.normalized() * SCARE_ACCEL * k * dt
			fear = maxf(fear, minf(1.0, k * 1.6))
		if vel.length() > SCARE_SPEED:
			vel = vel.normalized() * SCARE_SPEED
		vel *= exp(-SCARE_DAMP * dt)
		off += vel * dt
		if not threat:
			off = off.lerp(Vector3.ZERO, 1.0 - exp(-SCARE_RETURN * dt))
		# Never out of its water: a stream fish only along the stream, a pool fish within its pool.
		if kinds[i] == 1:
			var ax: Vector3 = (a_pts[i] - b_pts[i])
			ax.y = 0.0
			ax = ax.normalized()
			var along_o: float = clampf(off.dot(ax), -SCARE_MAX, SCARE_MAX)
			var side := Vector3(-ax.z, 0.0, ax.x)
			off = ax * along_o + side * clampf(off.dot(side), -0.3, 0.3)
		else:
			var r: float = (b_pts[i] as Vector3).x
			var flat := Vector3(pose.origin.x + off.x - (a_pts[i] as Vector3).x, 0.0, pose.origin.z + off.z - (a_pts[i] as Vector3).z)
			var lim: float = r + 0.5
			if flat.length() > lim:
				off -= flat.normalized() * (flat.length() - lim)
			off = off.limit_length(SCARE_MAX)
		off.y = 0.0
		fear = maxf(0.0, fear - dt * 0.5)
		_off[i] = off
		_vel[i] = vel
		_fear[i] = fear
		var xf := Transform3D(pose.basis, pose.origin + off)
		if vel.length() > 0.4:
			# Turned along its dash.
			var fwd: Vector3 = Vector3(vel.x, 0.0, vel.z).normalized()
			var cur: Vector3 = pose.basis.z.normalized()
			var mix_fwd: Vector3 = cur.slerp(fwd, clampf(vel.length() / 2.0, 0.0, 0.9)).normalized()
			var x_axis: Vector3 = Vector3.UP.cross(mix_fwd).normalized()
			xf.basis = Basis(x_axis, Vector3.UP, mix_fwd).scaled(Vector3.ONE * sizes[i])
		multimesh.set_instance_transform(i, xf)
		if multimesh.use_custom_data:
			var c0: Color = _base_custom[i]
			multimesh.set_instance_custom_data(i, Color(c0.r, c0.g, c0.b, maxf(c0.a, fear)))


## The carts near the fish: [position, speed] for each this peer sees (speed from how far it moved since last frame).
func _carts_near(delta: float) -> Array:
	var out: Array = []
	var reach: float = SCARE_R + 60.0
	for c in get_tree().get_nodes_in_group("player_carts"):
		var n3 := c as Node3D
		if n3 == null or not n3.is_inside_tree():
			continue
		var p: Vector3 = n3.global_position
		var id: int = n3.get_instance_id()
		var last: Vector3 = _cart_last.get(id, p)
		_cart_last[id] = p
		if Vector2(p.x - centre.x, p.z - centre.z).length() > reach + visibility_range_end:
			continue
		out.append([p, last.distance_to(p) / maxf(delta, 0.001)])
	return out
