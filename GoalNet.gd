@tool
extends Node3D
## A football goal's net that gives: the ball (any KickBall, group "kick_balls") sinks into it and is caught, a cart
## pushes it out of shape and drives on through (it has no collider: soft, like the brush). The frame (posts, crossbar,
## the net's bars) is the level's own mesh; this node draws only the net, as an internal child, so a level stores the
## transform and the sizes.
##
## The node's frame: x across the mouth (-half_width..half_width), y up, z back into the goal (0 on the goal line). The
## net is four faces: the top from the crossbar back `top_depth`, the back sloping from there down to `depth` at the
## ground, two sides. Each face's cords are tied to the frame, so how far a point can move (UV2.x) is 0 at its edges.
##
## Where something presses a face it makes a "poke" (up to POKES): a point on the face, the way the face bulges (out of
## the goal for something inside it, in for something behind), and how far. While the ball or a cart presses it, the
## poke follows its penetration; let go, it springs back (POKE_K, POKE_DAMP) and wobbles out. `goal_net.gdshader` moves
## the vertices by the pokes (a gaussian of POKE_R round each). The ball also feels the net: a spring that stops it within
## MAX_STRETCH and gives back little of its speed (the net soaks it up), so it drops into the goal.
##
## Whether something is in the goal is kept per body and changes only where it crosses the open mouth: a ball pressing
## the back of the net from inside is past the back's plane, and a plain volume test would have flipped it outside.
## Local scenery: every peer runs its own from what it sees (the balls are local too). Nothing is synced.

const SHADER := preload("res://goal_net.gdshader")
const POKES := 4
const POKE_R := 0.95
const POKE_K := 70.0
const POKE_DAMP := 7.0
const MAX_STRETCH := 1.25
## The ball against the net: spring, damping while it stretches the net, and the share of the spring it feels on its way
## back (the rest the net soaks up).
const BALL_K := 260.0
const BALL_DAMP := 14.0
const BALL_RETURN := 0.12
## The cords dragging on the ball while it is in them (per second): it drops, it doesn't fly back out.
const BALL_DRAG := 4.0
const CART_R := 1.0
const CART_GIVE := 1.3
## How near (m) a body must be to the goal's middle before it is looked at.
const NEAR := 12.0
const GRID := 0.32

@export var half_width := 5.86:
	set(v):
		half_width = v
		_rebuild()
@export var height := 3.9:
	set(v):
		height = v
		_rebuild()
@export var top_depth := 1.6:
	set(v):
		top_depth = v
		_rebuild()
@export var depth := 3.2:
	set(v):
		depth = v
		_rebuild()

var _mesh: MeshInstance3D
var _mat: ShaderMaterial
var _faces: Array = []
## Per slot: {pos, dir, amp, vel, held}; held is the key of whoever presses it ("" when free).
var _pokes: Array = []
## Per body (instance id): whether it is in the goal.
var _inside := {}
var _prev := {}
var _quiet := true
var _sfx: AudioStreamPlayer3D
static var _swish: AudioStreamWAV


func _ready() -> void:
	_rebuild()
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	for i in range(POKES):
		_pokes.append({"pos": Vector3.ZERO, "dir": Vector3.UP, "amp": 0.0, "vel": 0.0, "held": ""})
	if DisplayServer.get_name() != "headless":
		_sfx = AudioStreamPlayer3D.new()
		_sfx.stream = _swish_stream()
		_sfx.unit_size = 14.0
		_sfx.max_distance = 140.0
		_sfx.position = Vector3(0, height * 0.5, depth * 0.6)
		add_child(_sfx, false, Node.INTERNAL_MODE_FRONT)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	_build_faces()
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		_mesh.name = "Net"
		_mesh.set_meta(&"skip_dressing_colliders", true)
		add_child(_mesh, false, Node.INTERNAL_MODE_FRONT)
		_mat = ShaderMaterial.new()
		_mat.shader = SHADER
	_mesh.mesh = _net_mesh()
	_mesh.material_override = _mat
	_mesh.visibility_range_end = 700.0
	var box: AABB = _mesh.mesh.get_aabb().grow(MAX_STRETCH + 0.3)
	_mesh.custom_aabb = box
	_send()


## The faces: [plane point, outward normal, kind] (kind 0 top, 1 back, 2 the left side (-x), 3 the right).
func _build_faces() -> void:
	var nb := Vector3(0.0, depth - top_depth, height).normalized()
	_faces = [
		[Vector3(0, height, 0), Vector3.UP, 0],
		[Vector3(0, height, top_depth), nb, 1],
		[Vector3(-half_width, 0, 0), Vector3.LEFT, 2],
		[Vector3(half_width, 0, 0), Vector3.RIGHT, 3],
	]


func _depth_at(y: float) -> float:
	return lerpf(depth, top_depth, clampf(y / height, 0.0, 1.0))


## Whether a point projected onto face `f` lies on it (with `m` to spare inward).
func _on_face(f: Array, p: Vector3, m: float) -> bool:
	match int(f[2]):
		0:
			return absf(p.x) < half_width - m and p.z > m and p.z < top_depth - m
		1:
			return absf(p.x) < half_width - m and p.y > m and p.y < height - m
		_:
			return p.y > m and p.y < height - m and p.z > m and p.z < _depth_at(p.y) - m


func _in_volume(p: Vector3) -> bool:
	return p.z > 0.0 and absf(p.x) < half_width and p.y < height and p.z < _depth_at(p.y)


# ------------------------------------------------------------------------------------------------
#  The mesh: each face a grid of quads, UV the cords' place in metres, UV2.x how free the point is
# ------------------------------------------------------------------------------------------------

func _net_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corner := func(f: Array, u: float, v: float) -> Vector3:
		# u along the face's width (x, or z on a side), v up it (from its fixed front edge or the ground).
		match int(f[2]):
			0:
				return Vector3(lerpf(-half_width, half_width, u), height, v * top_depth)
			1:
				return Vector3(lerpf(-half_width, half_width, u), height * (1.0 - v), lerpf(top_depth, depth, v))
			_:
				var x: float = -half_width if int(f[2]) == 2 else half_width
				var y: float = v * height
				return Vector3(x, y, u * _depth_at(y))
	for f in _faces:
		var a0: Vector3 = corner.call(f, 0.0, 0.0)
		var a1: Vector3 = corner.call(f, 1.0, 0.0)
		var b0: Vector3 = corner.call(f, 0.0, 1.0)
		var nu: int = maxi(int(ceil(a0.distance_to(a1) / GRID)), 2)
		var nv: int = maxi(int(ceil(a0.distance_to(b0) / GRID)), 2)
		var n: Vector3 = f[1]
		for i in range(nu):
			for j in range(nv):
				var q: Array = []
				for c in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
					var u: float = float(c[0]) / float(nu)
					var v: float = float(c[1]) / float(nv)
					q.append([corner.call(f, u, v), u, v])
				# Wound so the face's front is outward: (c - a) x (b - a) along n.
				var tri := [q[0], q[1], q[2], q[0], q[2], q[3]]
				var fn: Vector3 = ((q[2][0] as Vector3) - (q[0][0] as Vector3)).cross((q[1][0] as Vector3) - (q[0][0] as Vector3))
				if fn.dot(n) < 0.0:
					tri = [q[0], q[2], q[1], q[0], q[3], q[2]]
				for t in tri:
					var p: Vector3 = t[0]
					var w: float = sin(PI * float(t[1])) * sin(PI * float(t[2]))
					st.set_normal(n)
					# The cords' pattern in metres across the face.
					var uv := Vector2(p.x, p.y + p.z) if int(f[2]) < 2 else Vector2(p.z, p.y)
					st.set_uv(uv)
					st.set_uv2(Vector2(w, float(f[2])))
					st.add_vertex(p)
	return st.commit()


# ------------------------------------------------------------------------------------------------
#  The bodies against the net
# ------------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _pokes.is_empty():
		return
	var mid: Vector3 = global_transform * Vector3(0, height * 0.5, depth * 0.5)
	var inv: Transform3D = global_transform.affine_inverse()
	var basis_inv: Basis = inv.basis
	var touched := {}
	for ball in get_tree().get_nodes_in_group("kick_balls"):
		var rb := ball as RigidBody3D
		if rb == null or rb.global_position.distance_to(mid) > NEAR:
			continue
		var r: float = float(rb.get("_p").get("radius", 0.36)) if rb.get("_p") is Dictionary else 0.36
		var lp: Vector3 = inv * rb.global_position
		var key := "b%d" % rb.get_instance_id()
		var ins: bool = _side(key, lp)
		var lv: Vector3 = basis_inv * rb.linear_velocity
		var hit := false
		for f in _faces:
			var pen: float = _penetration(f, lp, r, ins)
			if pen <= 0.0:
				continue
			var n: Vector3 = (f[1] as Vector3) * (1.0 if ins else -1.0)
			var vn: float = lv.dot(n)
			if pen > MAX_STRETCH:
				lp -= n * (pen - MAX_STRETCH)
				pen = MAX_STRETCH
				if vn > 0.0:
					lv -= n * vn
					vn = 0.0
			var acc: float = BALL_K * pen
			if vn > 0.0:
				acc += BALL_DAMP * vn
				if vn > 6.0 and _sfx != null and not _sfx.playing:
					_sfx.volume_db = linear_to_db(clampf(vn / 25.0, 0.15, 1.0)) - 4.0
					_sfx.pitch_scale = randf_range(0.9, 1.1)
					_sfx.play()
			else:
				acc *= BALL_RETURN
			lv -= n * acc * delta
			lv *= exp(-BALL_DRAG * delta)
			hit = true
			_hold(key + str(f[2]), _contact(f, lp), n, pen, delta)
			touched[key + str(f[2])] = true
		if hit:
			rb.global_position = global_transform * lp
			rb.linear_velocity = global_transform.basis * lv
	for cart in get_tree().get_nodes_in_group("player_carts"):
		var c3 := cart as Node3D
		if c3 == null or c3.global_position.distance_to(mid) > NEAR:
			continue
		var lp: Vector3 = inv * c3.global_position
		var key := "c%d" % c3.get_instance_id()
		var ins: bool = _side(key, lp)
		for f in _faces:
			var pen: float = _penetration(f, lp, CART_R, ins)
			if pen <= 0.0 or pen > CART_R + CART_GIVE:
				continue
			var n: Vector3 = (f[1] as Vector3) * (1.0 if ins else -1.0)
			_hold(key + str(f[2]), _contact(f, lp), n, minf(pen, CART_GIVE), delta)
			touched[key + str(f[2])] = true
	_spring(touched, delta)


## Whether the body `key` is in the goal: it changes only where the body crosses the mouth (z = 0 within the posts).
func _side(key: String, lp: Vector3) -> bool:
	if not _inside.has(key):
		_inside[key] = _in_volume(lp)
	elif _prev.has(key):
		var pp: Vector3 = _prev[key]
		if (pp.z < 0.0) != (lp.z < 0.0) and absf(lp.x) < half_width and lp.y < height:
			_inside[key] = lp.z >= 0.0
	_prev[key] = lp
	return _inside[key]


## How far a sphere at `lp` presses face `f` from its side (inside: outward), or 0 if it is off the face.
func _penetration(f: Array, lp: Vector3, r: float, ins: bool) -> float:
	var d: float = (lp - (f[0] as Vector3)).dot(f[1] as Vector3)
	var pen: float = (d + r) if ins else (r - d)
	if pen <= 0.0 or pen > r + MAX_STRETCH + 0.5:
		return 0.0
	if not _on_face(f, _contact(f, lp), r * 0.3):
		return 0.0
	return pen


func _contact(f: Array, lp: Vector3) -> Vector3:
	var n: Vector3 = f[1]
	return lp - n * (lp - (f[0] as Vector3)).dot(n)


## The poke a body holds: found by its key, else the quietest free slot.
func _hold(key: String, pos: Vector3, dir: Vector3, amp: float, delta: float) -> void:
	var slot := -1
	for i in range(POKES):
		if _pokes[i]["held"] == key:
			slot = i
			break
	if slot < 0:
		var best := INF
		for i in range(POKES):
			var p: Dictionary = _pokes[i]
			if p["held"] != "":
				continue
			var e: float = absf(p["amp"]) + absf(p["vel"]) * 0.1
			if e < best:
				best = e
				slot = i
		if slot < 0:
			return
		_pokes[slot]["amp"] = 0.0
	var pk: Dictionary = _pokes[slot]
	pk["vel"] = (amp - float(pk["amp"])) / maxf(delta, 1e-4)
	pk["amp"] = amp
	pk["pos"] = pos
	pk["dir"] = dir
	pk["held"] = key
	_quiet = false


func _spring(touched: Dictionary, delta: float) -> void:
	if _quiet:
		return
	var moving := false
	for p in _pokes:
		if p["held"] != "" and not touched.has(p["held"]):
			p["held"] = ""
			p["vel"] = clampf(p["vel"], -12.0, 12.0)
		if p["held"] == "":
			var a: float = p["amp"]
			var v: float = p["vel"]
			v += (-POKE_K * a - POKE_DAMP * v) * delta
			a += v * delta
			if absf(a) < 0.002 and absf(v) < 0.02:
				a = 0.0
				v = 0.0
			p["amp"] = a
			p["vel"] = v
		if p["amp"] != 0.0 or p["held"] != "":
			moving = true
	_send()
	_quiet = not moving


func _send() -> void:
	if _mat == null:
		return
	var pos := PackedVector4Array()
	var vec := PackedVector4Array()
	for i in range(POKES):
		if i < _pokes.size():
			var p: Dictionary = _pokes[i]
			var at: Vector3 = p["pos"]
			var d: Vector3 = (p["dir"] as Vector3) * float(p["amp"])
			pos.append(Vector4(at.x, at.y, at.z, POKE_R))
			vec.append(Vector4(d.x, d.y, d.z, 0.0))
		else:
			pos.append(Vector4(0, 0, 0, POKE_R))
			vec.append(Vector4.ZERO)
	_mat.set_shader_parameter(&"poke_pos", pos)
	_mat.set_shader_parameter(&"poke_vec", vec)


## A soft swish of cord taking the ball: filtered noise under a quick swell, made once.
static func _swish_stream() -> AudioStreamWAV:
	if _swish != null:
		return _swish
	var rate := 22050
	var n: int = int(rate * 0.55)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lp := 0.0
	var lp2 := 0.0
	for i in range(n):
		var t: float = float(i) / float(rate)
		var env: float = (1.0 - exp(-t * 60.0)) * exp(-t * 7.5)
		var x: float = rng.randf_range(-1.0, 1.0)
		lp += (x - lp) * 0.35
		lp2 += (lp - lp2) * 0.5
		var s: float = (lp - lp2 * 0.6) * env * 0.9
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	_swish = AudioStreamWAV.new()
	_swish.format = AudioStreamWAV.FORMAT_16_BITS
	_swish.mix_rate = rate
	_swish.data = data
	return _swish
