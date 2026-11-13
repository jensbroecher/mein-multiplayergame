extends Node3D
## Air taxis (electric multicopters, an original design) flying loops over a stage, on the wall clock (every LAN peer sees
## them in the same place). The Yunhai GP's: a generator adds the node with its `routes`; the taxis are built at runtime.
##
## A taxi is built in code at life size (nose toward -z, y up, its skids at y 0) and grown by `scale_factor`: a lofted
## teardrop cabin in white with a wraparound dark canopy and a coloured stripe, skids on struts, two booms on pylons over
## the roof carrying six ducted rotors (each duct ringed with light), red and green nav lights, a white strobe, a lit TAXI
## box on the roof, headlamps, underglow in its livery's colour. The rotors spin (blades and a faint disc). Meshes are
## built once per livery and shared (static cache).
##
## `routes`: Array of {"points": PackedVector3Array (a closed loop, smoothed through its points), "speed": m/s,
## "count": taxis on it, evenly spaced}. Each taxi banks into turns by the turn's tightness and its speed, noses down a
## little in cruise and bobs. Its motors (`engine_sound`, levelled from `engine_rms` to `engine_level` at `sound_unit`
## metres) are pitched by the Doppler shift from its velocity and the camera's. Nothing is solid; no sound on a headless
## server.

@export var routes: Array = []
@export var scale_factor := 1.6
@export var engine_sound: AudioStream
@export var engine_rms := -20.0
@export var engine_level := -18.0
@export var sound_unit := 30.0

const WHITE := Color(0.94, 0.95, 0.96)
const BELLY := Color(0.55, 0.57, 0.62)
const GLASS := Color(0.04, 0.06, 0.09)
const DARK := Color(0.13, 0.14, 0.16)
const ACCENTS: Array = [Color(0.15, 0.85, 1.0), Color(1.0, 0.3, 0.75), Color(1.0, 0.72, 0.2)]
const ROTORS: Array = [Vector3(-2.7, 2.22, -2.5), Vector3(2.7, 2.22, -2.5), Vector3(-2.7, 2.22, 0.0), Vector3(2.7, 2.22, 0.0),
	Vector3(-2.7, 2.22, 2.5), Vector3(2.7, 2.22, 2.5)]

static var _meshes := {}

var _taxis: Array = []
var _curves: Array = []


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var headless: bool = DisplayServer.get_name() == "headless"
	var n := 0
	for r in routes:
		var rd: Dictionary = r
		var c := _loop_curve(rd.get("points", PackedVector3Array()))
		_curves.append(c)
		var count: int = int(rd.get("count", 1))
		for k in range(count):
			var accent: int = n % ACCENTS.size()
			if not _meshes.has("body_%d" % accent):
				_meshes["body_%d" % accent] = _build_body(ACCENTS[accent])
			if not _meshes.has("rotor"):
				_meshes["rotor"] = _build_rotor()
			var root := Node3D.new()
			root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			add_child(root, false, Node.INTERNAL_MODE_BACK)
			var body := MeshInstance3D.new()
			body.mesh = _meshes["body_%d" % accent]
			body.scale = Vector3.ONE * scale_factor
			body.set_meta(&"skip_dressing_colliders", true)
			root.add_child(body)
			var rotors: Array = []
			for i in range(ROTORS.size()):
				var rm := MeshInstance3D.new()
				rm.mesh = _meshes["rotor"]
				rm.position = ROTORS[i]
				rm.set_meta(&"skip_dressing_colliders", true)
				rm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				body.add_child(rm)
				rotors.append(rm)
			for sx in [-1.0, 1.0]:
				var l := Label3D.new()
				l.text = "AIR TAXI  %02d" % (n + 1)
				l.font_size = 64
				l.pixel_size = 0.2 / 44.8
				l.modulate = Color(0.12, 0.16, 0.3)
				l.outline_size = 0
				l.double_sided = false
				l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
				l.transform = Transform3D(Basis.looking_at(Vector3(-sx, 0, 0), Vector3.UP), Vector3(sx * 0.94, 0.95, 0.9))
				body.add_child(l)
			var player: AudioStreamPlayer3D = null
			if not headless and engine_sound != null:
				player = AudioStreamPlayer3D.new()
				player.stream = engine_sound
				player.volume_db = engine_level - engine_rms
				player.unit_size = sound_unit
				player.max_distance = 700.0
				player.attenuation_filter_cutoff_hz = 7000.0
				player.attenuation_filter_db = -8.0
				player.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
				root.add_child(player)
			_taxis.append({"node": root, "rotors": rotors, "route": _curves.size() - 1, "speed": float(rd.get("speed", 24.0)),
				"offset": float(k) / float(count) + 0.137 * float(n), "player": player, "pitch": 1.0, "phase": float(n) * 1.7})
			n += 1
	for t in _taxis:
		var p: AudioStreamPlayer3D = t["player"]
		if p:
			p.play(randf() * maxf(engine_sound.get_length() - 0.1, 0.0))
	_place(0.0)


func _process(delta: float) -> void:
	_place(delta)


var _cam_prev := Vector3.ZERO
var _cam_vel := Vector3.ZERO
var _cam_ok := false


## A closed curve smoothed through the points (Catmull-Rom handles).
static func _loop_curve(pts: PackedVector3Array) -> Curve3D:
	var c := Curve3D.new()
	c.bake_interval = 1.0
	var n: int = pts.size()
	for i in range(n + 1):
		var p: Vector3 = pts[i % n]
		var hd: Vector3 = (pts[(i + 1) % n] - pts[(i - 1 + n) % n]) / 6.0
		c.add_point(p, -hd, hd)
	return c


func _place(delta: float) -> void:
	var now: float = Time.get_unix_time_from_system()
	var t := float(fmod(now, 7200.0))
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam and delta > 0.0:
		var lp: Vector3 = cam.global_position
		if _cam_ok:
			var lv: Vector3 = (lp - _cam_prev) / delta
			_cam_vel = _cam_vel.lerp(lv, clampf(delta * 6.0, 0.0, 1.0)) if lv.length() < 150.0 else Vector3.ZERO
		_cam_prev = lp
		_cam_ok = true
	for tx in _taxis:
		var c: Curve3D = _curves[int(tx["route"])]
		var length: float = c.get_baked_length()
		if length < 10.0:
			continue
		var v: float = tx["speed"]
		var s: float = fposmod(float(fmod(now * v, length)) + float(tx["offset"]) * length, length)
		var p: Vector3 = c.sample_baked(s, true)
		var pa: Vector3 = c.sample_baked(fposmod(s - 6.0, length), true)
		var pb: Vector3 = c.sample_baked(fposmod(s + 6.0, length), true)
		var f0: Vector3 = (p - pa).normalized()
		var f1: Vector3 = (pb - p).normalized()
		var fwd: Vector3 = (f0 + f1).normalized()
		var flat0 := Vector3(f0.x, 0, f0.z).normalized()
		var flat1 := Vector3(f1.x, 0, f1.z).normalized()
		var k: float = flat0.angle_to(flat1) / 6.0
		var inward: Vector3 = flat1 - flat0
		inward = inward.normalized() if inward.length() > 1e-5 else Vector3.ZERO
		var bank: float = clampf(atan(v * v * k / 9.81), 0.0, deg_to_rad(24.0))
		var ph: float = tx["phase"]
		p.y += sin(t * 0.7 + ph) * 0.5
		# Nose down a little in cruise (the rotors pull it along), less climbing.
		var look: Vector3 = (fwd - Vector3(0, 0.08, 0)).normalized()
		var up: Vector3 = (Vector3.UP + inward * tan(bank)).normalized()
		var node: Node3D = tx["node"]
		node.global_transform = Transform3D(Basis.looking_at(look, up), p)
		var rotors: Array = tx["rotors"]
		for i in range(rotors.size()):
			(rotors[i] as Node3D).rotation = Vector3(0, fmod(t * (19.0 + float(i) * 0.7), TAU) * (1.0 if i % 2 == 0 else -1.0), 0)
		var player: AudioStreamPlayer3D = tx["player"]
		if player and cam and delta > 0.0:
			var u: Vector3 = (cam.global_position - p).normalized()
			var dop: float = clampf((343.0 - _cam_vel.dot(u)) / maxf(343.0 - (fwd * v).dot(u), 1.0), 0.75, 1.3)
			tx["pitch"] = lerpf(float(tx["pitch"]), dop, clampf(delta * 5.0, 0.0, 1.0))
			player.pitch_scale = tx["pitch"]


# ======================================================================================
#  The model (life size, nose toward -z, skids at y 0)
# ======================================================================================

class Builder:
	var sts: Array = []

	func _init(n: int) -> void:
		for i in range(n):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			sts.append(st)

	## A triangle facing away from `inside`, flat shaded, into surface `si`.
	func tri(si: int, a: Vector3, b: Vector3, c: Vector3, col: Color, inside: Vector3) -> void:
		var n: Vector3 = (c - a).cross(b - a)
		if n.length_squared() < 1e-14:
			return
		if n.dot((a + b + c) / 3.0 - inside) < 0.0:
			var tp := b
			b = c
			c = tp
			n = -n
		n = n.normalized()
		var st: SurfaceTool = sts[si]
		for vv in [a, b, c]:
			st.set_normal(n)
			st.set_color(col)
			st.add_vertex(vv)

	func quad(si: int, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, inside: Vector3) -> void:
		tri(si, a, b, c, col, inside)
		tri(si, a, c, d, col, inside)

	func beam(si: int, a: Vector3, b: Vector3, w: float, h: float, col: Color, side := Vector3.RIGHT) -> void:
		var f: Vector3 = (b - a).normalized()
		var sd: Vector3 = side - f * side.dot(f)
		if sd.length_squared() < 1e-6:
			sd = f.cross(Vector3.UP)
		sd = sd.normalized()
		var u: Vector3 = f.cross(sd).normalized()
		var cs: Array = []
		for k in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
			cs.append(sd * (w * 0.5 * k[0]) + u * (h * 0.5 * k[1]))
		var mid: Vector3 = (a + b) * 0.5
		for k in 4:
			var k2: int = (k + 1) % 4
			quad(si, a + cs[k], a + cs[k2], b + cs[k2], b + cs[k], col, mid)
		quad(si, a + cs[0], a + cs[1], a + cs[2], a + cs[3], col, mid)
		quad(si, b + cs[0], b + cs[1], b + cs[2], b + cs[3], col, mid)

	func cyl(si: int, a: Vector3, b: Vector3, r: float, col: Color, n := 10) -> void:
		var f: Vector3 = (b - a).normalized()
		var sd: Vector3 = f.cross(Vector3.UP if absf(f.y) < 0.9 else Vector3.RIGHT).normalized()
		var u: Vector3 = f.cross(sd)
		var mid: Vector3 = (a + b) * 0.5
		for k in n:
			var a0: float = TAU * float(k) / float(n)
			var a1: float = TAU * float(k + 1) / float(n)
			var o0: Vector3 = (sd * cos(a0) + u * sin(a0)) * r
			var o1: Vector3 = (sd * cos(a1) + u * sin(a1)) * r
			quad(si, a + o0, a + o1, b + o1, b + o0, col, mid)
			tri(si, a, a + o0, a + o1, col, mid)
			tri(si, b, b + o1, b + o0, col, mid)

	func commit(mats: Array) -> ArrayMesh:
		var m := ArrayMesh.new()
		for i in range(sts.size()):
			var st: SurfaceTool = sts[i]
			var arr: Array = st.commit_to_arrays()
			if arr.is_empty() or (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
				continue
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			m.surface_set_material(m.get_surface_count() - 1, mats[i])
		return m


static func _body_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.28
	mat.metallic = 0.15
	return mat


## A superellipse cabin section at z: half width hw, from yb to yt, exponent e, n points.
static func _section(z: float, hw: float, yb: float, yt: float, e := 2.4, n := 28) -> Array:
	var out: Array = []
	var yc: float = (yb + yt) * 0.5
	var hh: float = (yt - yb) * 0.5
	for k in n:
		var a: float = TAU * float(k) / float(n)
		var c: float = cos(a)
		var s: float = sin(a)
		out.append(Vector3(hw * signf(c) * pow(absf(c), 2.0 / e), yc + hh * signf(s) * pow(absf(s), 2.0 / e), z))
	return out


static func _build_body(accent: Color) -> ArrayMesh:
	var bd := Builder.new(2)
	# The cabin: a teardrop pod, its tail rising.
	var secs: Array = [[-2.58, 0.06, 0.95, 1.05], [-2.38, 0.42, 0.62, 1.32], [-1.98, 0.72, 0.45, 1.62], [-1.3, 0.9, 0.38, 1.82],
		[-0.4, 0.95, 0.36, 1.88], [0.6, 0.92, 0.38, 1.85], [1.5, 0.78, 0.48, 1.72], [2.2, 0.5, 0.66, 1.55], [2.7, 0.24, 0.86, 1.42],
		[2.95, 0.06, 1.0, 1.3]]
	var rings: Array = []
	var axis: Array = []
	for sc in secs:
		rings.append(_section(sc[0], sc[1], sc[2], sc[3]))
		axis.append(Vector3(0, (float(sc[2]) + float(sc[3])) * 0.5, sc[0]))
	var colour := func(m: Vector3) -> Color:
		if m.y > 1.78 and m.z > -1.0:
			return WHITE
		if m.y > 1.0 and m.z < 0.25:
			return GLASS
		if m.y > 1.1 and m.y < 1.62 and m.z > 0.45 and m.z < 1.65:
			return GLASS
		if m.y > 0.6 and m.y < 0.76:
			return accent
		if m.y < 0.5:
			return BELLY
		return WHITE
	var nr: int = rings.size()
	var np: int = (rings[0] as Array).size()
	for i in range(nr - 1):
		var ci: Vector3 = (axis[i] + axis[i + 1]) * 0.5
		for j in range(np):
			var j2: int = (j + 1) % np
			var a: Vector3 = rings[i][j]
			var b: Vector3 = rings[i][j2]
			var c: Vector3 = rings[i + 1][j2]
			var d: Vector3 = rings[i + 1][j]
			bd.quad(0, a, b, c, d, colour.call((a + b + c + d) * 0.25), ci)
	for e in [0, nr - 1]:
		for j in range(np):
			bd.tri(0, axis[e], rings[e][j], rings[e][(j + 1) % np], WHITE, axis[e] + Vector3(0, 0, 0.3 if e == 0 else -0.3))
	# Skids on struts, their front ends turned up.
	for sx in [-1.0, 1.0]:
		var x: float = sx * 0.78
		bd.cyl(0, Vector3(x, 0.07, -1.6), Vector3(x, 0.07, 1.7), 0.06, DARK, 8)
		bd.cyl(0, Vector3(x, 0.07, -1.6), Vector3(x, 0.28, -1.95), 0.06, DARK, 8)
		for zz in [-1.0, 1.1]:
			bd.cyl(0, Vector3(x, 0.07, zz), Vector3(sx * 0.62, 0.48, zz - 0.05), 0.05, DARK, 8)
	# Pylons from the roof to two cross beams, booms along each side, a motor pod at each rotor and its duct.
	for zz in [-0.75, 1.1]:
		bd.beam(0, Vector3(-2.7, 2.06, zz), Vector3(2.7, 2.06, zz), 0.16, 0.12, WHITE, Vector3(0, 0, 1))
		for px in [-0.42, 0.42]:
			bd.beam(0, Vector3(px * 0.9, 1.7, zz), Vector3(px * 1.6, 2.06, zz), 0.14, 0.18, WHITE, Vector3(0, 0, 1))
	for sx in [-1.0, 1.0]:
		bd.beam(0, Vector3(sx * 2.7, 2.06, -2.5), Vector3(sx * 2.7, 2.06, 2.5), 0.16, 0.14, WHITE, Vector3.UP)
	for rp in ROTORS:
		var c3: Vector3 = rp
		bd.cyl(0, c3 - Vector3(0, 0.3, 0), c3 - Vector3(0, 0.02, 0), 0.16, DARK, 10)
		# The duct: a ring of short beams round the blades, a line of light round its outer face.
		var segs := 20
		for k in range(segs):
			var a0: float = TAU * float(k) / float(segs)
			var a1: float = TAU * float(k + 1) / float(segs)
			var p0: Vector3 = c3 + Vector3(cos(a0), 0, sin(a0)) * 1.2
			var p1: Vector3 = c3 + Vector3(cos(a1), 0, sin(a1)) * 1.2
			bd.beam(0, p0, p1, 0.07, 0.26, WHITE, Vector3(cos(a0 + PI / float(segs)), 0, sin(a0 + PI / float(segs))))
			var g0: Vector3 = c3 + Vector3(cos(a0), 0, sin(a0)) * 1.245
			var g1: Vector3 = c3 + Vector3(cos(a1), 0, sin(a1)) * 1.245
			bd.beam(1, g0, g1, 0.025, 0.06, accent, Vector3(cos(a0 + PI / float(segs)), 0, sin(a0 + PI / float(segs))))
		# Two spokes holding the duct to the boom's line.
		bd.beam(0, c3 + Vector3(0, -0.05, -1.2), c3 + Vector3(0, -0.05, 1.2), 0.05, 0.05, DARK, Vector3.RIGHT)
	# Lights: nav (red on the left, green on the right, at the front booms' ends), a white strobe on the tail, headlamps,
	# a lit TAXI box on the roof, underglow along the belly in the livery's colour.
	bd.cyl(1, Vector3(-2.7, 2.06, -2.55), Vector3(-2.7, 2.06, -2.75), 0.08, Color(1.0, 0.1, 0.08), 8)
	bd.cyl(1, Vector3(2.7, 2.06, -2.55), Vector3(2.7, 2.06, -2.75), 0.08, Color(0.1, 1.0, 0.35), 8)
	bd.cyl(1, Vector3(0, 1.15, 2.95), Vector3(0, 1.15, 3.08), 0.07, Color(1, 1, 1), 8)
	for sx in [-1.0, 1.0]:
		bd.cyl(1, Vector3(sx * 0.3, 0.92, -2.3), Vector3(sx * 0.3, 0.9, -2.42), 0.08, Color(1.0, 0.97, 0.9), 10)
		bd.beam(1, Vector3(sx * 0.82, 0.44, -1.5), Vector3(sx * 0.8, 0.46, 1.5), 0.04, 0.04, accent, Vector3.UP)
	bd.beam(1, Vector3(0, 1.88, -0.55), Vector3(0, 1.88, -0.05), 0.75, 0.24, Color(1.0, 0.82, 0.3), Vector3.RIGHT)
	return bd.commit([_body_material(), preload("res://LampGlow.gd").material(3.0)])


static func _build_rotor() -> ArrayMesh:
	var bd := Builder.new(2)
	bd.cyl(0, Vector3(0, -0.03, 0), Vector3(0, 0.08, 0), 0.12, DARK, 10)
	for k in range(3):
		var a: float = TAU * float(k) / 3.0
		var d := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-d.z, 0, d.x)
		bd.beam(0, d * 0.1, d * 1.12, 0.16, 0.025, DARK, (side + Vector3(0, 0.25, 0)).normalized())
	# The faint disc the blades sweep.
	var n := 24
	for k in range(n):
		var a0: float = TAU * float(k) / float(n)
		var a1: float = TAU * float(k + 1) / float(n)
		var p0 := Vector3(cos(a0), 0, sin(a0)) * 1.14
		var p1 := Vector3(cos(a1), 0, sin(a1)) * 1.14
		bd.tri(1, Vector3(0, 0.01, 0), p0, p1, Color(0.8, 0.82, 0.86, 0.045), Vector3(0, -1, 0))
	var disc := StandardMaterial3D.new()
	disc.vertex_color_use_as_albedo = true
	disc.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc.cull_mode = BaseMaterial3D.CULL_DISABLED
	return bd.commit([_body_material(), disc])
