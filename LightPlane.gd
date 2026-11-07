extends Node3D
## A small four-seat high-wing touring aeroplane (an original design, not a real type) flying loops over a stage: the
## Kronburg GP's (the generators add the node through `add_to`; it builds everything else itself, so a level stores only
## the node).
##
## The plane is built in code at life size (nose toward -z, y up, the wing's root on the cabin roof) and grown by
## `scale_factor`: a lofted fuselage in white with a red cheatline and a blue pinstripe, a cabin with side windows and a
## raked windscreen, a strut-braced high wing with red tips, the tailplane and a swept fin in the stripes' colours, fixed
## tricycle gear with wheel fairings, nav lights, a two-bladed propeller that spins, the registration on both sides. The
## meshes are built once and shared (static cache).
##
## It flies an ellipse on the wall clock (every LAN peer sees it in the same place): fitted round the level's TrackPath
## (`radii` zero) or given (`centre`, `radii`), at `altitude` over the lap's highest point, climbing and sinking a little,
## banked into its turns by the turn's tightness and its speed (a coordinated turn: tan(bank) = v^2 k / g). Its engine
## (`engine_sound`, levelled from its RMS to `engine_level` at `sound_unit` metres) is pitched by the Doppler shift from
## its velocity and the camera's. Nothing is solid; nothing runs on a headless server but the placing.

@export var centre := Vector3.ZERO
## Half the ellipse's extents in x and z; zero: fitted round the TrackPath (its half extents times `fit_share` plus
## `fit_margin`, each kept between `fit_min` and `fit_max`).
@export var radii := Vector2.ZERO
@export var fit_share := 0.7
@export var fit_margin := 140.0
@export var fit_min := 280.0
@export var fit_max := 850.0
## Over the lap's highest point (or, with `centre` given, over its y).
@export var altitude := 150.0
@export var speed := 42.0
@export var phase := 0.0
@export var clockwise := false
@export var scale_factor := 1.6
@export var registration := "D-EKRB"
@export var engine_sound: AudioStream
@export var engine_rms := -17.0
@export var engine_level := -16.0
@export var sound_unit := 70.0

var _body: MeshInstance3D
var _prop: MeshInstance3D
var _player: AudioStreamPlayer3D
var _base_y := 0.0
var _perimeter := 1.0
var _listener_prev := Vector3.ZERO
var _listener_vel := Vector3.ZERO
var _listener_ok := false
var _pitch := 1.0

static var _meshes := {}

const WHITE := Color(0.95, 0.95, 0.94)
const RED := Color(0.78, 0.09, 0.08)
const BLUE := Color(0.10, 0.20, 0.48)
const BELLY := Color(0.80, 0.81, 0.82)
const GLASS := Color(0.08, 0.11, 0.15)
const DARK := Color(0.12, 0.12, 0.13)
const TYRE := Color(0.07, 0.07, 0.07)
const METAL := Color(0.62, 0.63, 0.64)


func _ready() -> void:
	_fit()
	if not _meshes.has("body"):
		_meshes["body"] = _build_body()
		_meshes["prop"] = _build_prop()
	_body = MeshInstance3D.new()
	_body.mesh = _meshes["body"]
	_body.scale = Vector3.ONE * scale_factor
	_body.set_meta(&"skip_dressing_colliders", true)
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_body, false, Node.INTERNAL_MODE_BACK)
	_prop = MeshInstance3D.new()
	_prop.mesh = _meshes["prop"]
	_prop.position = Vector3(0, 0.0, -4.12)
	_prop.set_meta(&"skip_dressing_colliders", true)
	_body.add_child(_prop, false, Node.INTERNAL_MODE_BACK)
	for sx in [-1.0, 1.0]:
		var l := Label3D.new()
		l.text = registration
		l.font_size = 64
		l.pixel_size = 0.34 / 44.8
		l.modulate = BLUE
		l.outline_size = 0
		l.double_sided = false
		l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		l.transform = Transform3D(Basis.looking_at(Vector3(-sx, 0, 0), Vector3.UP), Vector3(sx * 0.52, 0.42, 1.55))
		_body.add_child(l, false, Node.INTERNAL_MODE_BACK)
	if DisplayServer.get_name() != "headless" and engine_sound != null:
		_player = AudioStreamPlayer3D.new()
		_player.stream = engine_sound
		_player.volume_db = engine_level - engine_rms
		_player.unit_size = sound_unit
		_player.max_distance = 1800.0
		_player.attenuation_filter_cutoff_hz = 6000.0
		_player.attenuation_filter_db = -6.0
		_player.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
		add_child(_player, false, Node.INTERNAL_MODE_BACK)
		_player.play(randf() * maxf(engine_sound.get_length() - 0.1, 0.0))
	_place(0.0)


## Fits the ellipse round the TrackPath when no radii are given, and the cruising height over its highest point.
func _fit() -> void:
	var path: Path3D = get_parent().get_node_or_null("TrackPath") as Path3D if get_parent() else null
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	if path != null and path.curve != null:
		var pts: PackedVector3Array = path.curve.get_baked_points()
		for i in range(0, pts.size(), 8):
			var p: Vector3 = path.global_transform * pts[i] if path.is_inside_tree() else path.transform * pts[i]
			lo = lo.min(p)
			hi = hi.max(p)
	if radii == Vector2.ZERO:
		if lo.x < INF:
			centre = Vector3((lo.x + hi.x) * 0.5, 0.0, (lo.z + hi.z) * 0.5)
			radii = Vector2(clampf((hi.x - lo.x) * 0.5 * fit_share + fit_margin, fit_min, fit_max),
					clampf((hi.z - lo.z) * 0.5 * fit_share + fit_margin, fit_min, fit_max))
		else:
			radii = Vector2(500.0, 400.0)
	_base_y = (hi.y if lo.x < INF else centre.y) + altitude
	var a := radii.x
	var b := radii.y
	var h := pow(a - b, 2.0) / pow(a + b, 2.0)
	_perimeter = PI * (a + b) * (1.0 + 3.0 * h / (10.0 + sqrt(4.0 - 3.0 * h)))


func _process(delta: float) -> void:
	_place(delta)


func _at(a: float) -> Vector3:
	return centre + Vector3(cos(a) * radii.x, 0.0, sin(a) * radii.y)


func _place(delta: float) -> void:
	var now := Time.get_unix_time_from_system()
	var dir: float = -1.0 if clockwise else 1.0
	var ang: float = phase + TAU * fmod(float(now) * speed / _perimeter, 1.0) * dir
	var p := _at(ang)
	# The heading and the turn from the ellipse's neighbouring points (about 4m either side).
	var da: float = 4.0 / maxf(radii.x, radii.y) * dir
	var pa := _at(ang - da)
	var pb := _at(ang + da)
	var f0 := (p - pa).normalized()
	var f1 := (pb - p).normalized()
	var fwd := (f0 + f1).normalized()
	var k: float = f0.angle_to(f1) / maxf(p.distance_to(pb), 0.01)
	var inward := (f1 - f0)
	inward = inward.normalized() if inward.length() > 1e-6 else Vector3.ZERO
	var t := float(fmod(now, 7200.0))
	var y: float = _base_y + sin(t * 0.045 + phase) * 22.0
	var climb: float = cos(t * 0.045 + phase) * 22.0 * 0.045
	p.y = y
	var v3 := fwd * speed + Vector3(0, climb, 0)
	var bank: float = clampf(atan(speed * speed * k / 9.81), 0.0, deg_to_rad(32.0))
	var up := (Vector3.UP + inward * tan(bank)).normalized()
	var look := v3.normalized()
	global_transform = Transform3D(Basis.looking_at(look, up), p)
	if _prop:
		_prop.rotation = Vector3(0, 0, fmod(t * 42.0, TAU))
	if _player and delta > 0.0:
		var cam := get_viewport().get_camera_3d()
		if cam:
			var lp: Vector3 = cam.global_position
			if _listener_ok:
				var lv: Vector3 = (lp - _listener_prev) / delta
				_listener_vel = _listener_vel.lerp(lv, clampf(delta * 6.0, 0.0, 1.0)) if lv.length() < 150.0 else Vector3.ZERO
			_listener_prev = lp
			_listener_ok = true
			var u: Vector3 = (lp - p).normalized()
			var dop: float = clampf((343.0 - _listener_vel.dot(u)) / maxf(343.0 - v3.dot(u), 1.0), 0.7, 1.4)
			_pitch = lerpf(_pitch, dop, clampf(delta * 5.0, 0.0, 1.0))
			_player.pitch_scale = _pitch


# ======================================================================================
#  The model (life size, nose toward -z)
# ======================================================================================

class Builder:
	var st := SurfaceTool.new()

	func _init() -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	## A triangle facing away from `hint` (a point inside the solid it bounds), flat shaded.
	func tri(a: Vector3, b: Vector3, c: Vector3, col: Color, inside: Vector3) -> void:
		var n: Vector3 = (c - a).cross(b - a)
		if n.length_squared() < 1e-12:
			return
		var mid: Vector3 = (a + b + c) / 3.0
		if n.dot(mid - inside) < 0.0:
			var t := b
			b = c
			c = t
			n = -n
		n = n.normalized()
		for v in [a, b, c]:
			st.set_normal(n)
			st.set_color(col)
			st.add_vertex(v)

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, inside: Vector3) -> void:
		tri(a, b, c, col, inside)
		tri(a, c, d, col, inside)

	## A closed loft through rings (each the same point count), its ends capped, coloured per quad by `col_fn(mid)`.
	func loft(rings: Array, col_fn: Callable, axis_pts: Array) -> void:
		var nr: int = rings.size()
		var np: int = (rings[0] as Array).size()
		for i in range(nr - 1):
			var ci: Vector3 = (axis_pts[i] + axis_pts[i + 1]) * 0.5
			for j in range(np):
				var j2: int = (j + 1) % np
				var a: Vector3 = rings[i][j]
				var b: Vector3 = rings[i][j2]
				var c: Vector3 = rings[i + 1][j2]
				var d: Vector3 = rings[i + 1][j]
				var col: Color = col_fn.call((a + b + c + d) * 0.25)
				quad(a, b, c, d, col, ci)
		for e in [0, nr - 1]:
			var ring: Array = rings[e]
			var cen: Vector3 = axis_pts[e]
			var inside: Vector3 = cen + Vector3(0, 0, 0.5 if e == 0 else -0.5)
			for j in range(np):
				tri(cen, ring[j], ring[(j + 1) % np], col_fn.call(cen), inside)

	## A box from `a` to `b` (its middle line), `w` wide across `side`, `h` across the other.
	func beam(a: Vector3, b: Vector3, w: float, h: float, col: Color, side := Vector3.RIGHT) -> void:
		var f: Vector3 = (b - a).normalized()
		var s: Vector3 = (side - f * side.dot(f)).normalized()
		if s.length_squared() < 1e-6:
			s = f.cross(Vector3.UP).normalized()
		var u: Vector3 = f.cross(s).normalized()
		var cs: Array = []
		for k in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
			cs.append(s * (w * 0.5 * k[0]) + u * (h * 0.5 * k[1]))
		var mid: Vector3 = (a + b) * 0.5
		for k in 4:
			var k2: int = (k + 1) % 4
			quad(a + cs[k], a + cs[k2], b + cs[k2], b + cs[k], col, mid)
		quad(a + cs[0], a + cs[1], a + cs[2], a + cs[3], col, mid)
		quad(b + cs[0], b + cs[1], b + cs[2], b + cs[3], col, mid)

	## A cylinder (a tube with closed ends) from a to b of radius r.
	func cyl(a: Vector3, b: Vector3, r: float, col: Color, n := 12) -> void:
		var f: Vector3 = (b - a).normalized()
		var s: Vector3 = f.cross(Vector3.UP if absf(f.y) < 0.9 else Vector3.RIGHT).normalized()
		var u: Vector3 = f.cross(s)
		var mid: Vector3 = (a + b) * 0.5
		for k in n:
			var a0: float = TAU * float(k) / float(n)
			var a1: float = TAU * float(k + 1) / float(n)
			var o0: Vector3 = (s * cos(a0) + u * sin(a0)) * r
			var o1: Vector3 = (s * cos(a1) + u * sin(a1)) * r
			quad(a + o0, a + o1, b + o1, b + o0, col, mid)
			tri(a, a + o0, a + o1, col, mid)
			tri(b, b + o1, b + o0, col, mid)

	func commit() -> ArrayMesh:
		var m: ArrayMesh = st.commit()
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.vertex_color_is_srgb = true
		mat.roughness = 0.38
		m.surface_set_material(0, mat)
		return m


## Adds a plane to a level being generated (its name `node_name`, where on its round it starts, which way it flies);
## everything else is worked out at runtime from the level's TrackPath.
static func add_to(level: Node, node_name: String, start_phase: float, cw: bool) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	n.set_script(load("res://LightPlane.gd"))
	n.set("phase", start_phase)
	n.set("clockwise", cw)
	n.set("engine_sound", load("res://sounds/kronburg/light_plane_loop.wav"))
	level.add_child(n)
	return n


## A superellipse section at z: half width hw, from yb to yt, exponent e (2 an ellipse, higher squarer), n points.
static func _section(z: float, hw: float, yb: float, yt: float, e := 2.6, n := 24) -> Array:
	var out: Array = []
	var yc: float = (yb + yt) * 0.5
	var hh: float = (yt - yb) * 0.5
	for k in n:
		var a: float = TAU * float(k) / float(n)
		var c: float = cos(a)
		var s: float = sin(a)
		out.append(Vector3(hw * signf(c) * pow(absf(c), 2.0 / e), yc + hh * signf(s) * pow(absf(s), 2.0 / e), z))
	return out


## A wing (or tailplane) panel along x from x0 to x1: an airfoil of chord `chord` (leading edge at z = le, tapering to
## `tip_chord` at the tip) at height y (+ dihedral), thickness `t` of the chord.
static func _wing(bd: Builder, x0: float, x1: float, le: float, chord: float, tip_chord: float, y: float, dihedral: float, t: float, tip_col: Color, tip_from: float) -> void:
	var prof: Array = [Vector2(0.0, 0.0), Vector2(0.04, 0.45), Vector2(0.18, 0.85), Vector2(0.38, 1.0), Vector2(0.7, 0.62), Vector2(1.0, 0.06),
		Vector2(1.0, -0.02), Vector2(0.7, -0.12), Vector2(0.38, -0.25), Vector2(0.18, -0.28), Vector2(0.04, -0.2)]
	var stations: Array = []
	var n: int = 12
	for k in range(n + 1):
		stations.append(lerpf(x0, x1, float(k) / float(n)))
	var rings: Array = []
	var axis: Array = []
	for x in stations:
		var span_t: float = absf(float(x)) / maxf(absf(x1), absf(x0))
		var c: float = lerpf(chord, tip_chord, span_t)
		var lz: float = le + (chord - c) * 0.25
		var yy: float = y + absf(float(x)) * tan(dihedral)
		var ring: Array = []
		for p in prof:
			ring.append(Vector3(float(x), yy + p.y * c * t * 0.5, lz + p.x * c))
		rings.append(ring)
		axis.append(Vector3(float(x), yy + c * t * 0.15, lz + c * 0.4))
	bd.loft(rings, func(m: Vector3) -> Color: return tip_col if absf(m.x) > tip_from else WHITE, axis)


static func _build_body() -> ArrayMesh:
	var bd := Builder.new()
	# The fuselage: [z, half width, bottom, top, exponent], nose to tail.
	var secs: Array = [
		[-3.92, 0.30, -0.28, 0.20, 2.2], [-3.75, 0.42, -0.42, 0.32, 2.4], [-3.3, 0.5, -0.52, 0.4, 2.6], [-2.6, 0.55, -0.58, 0.45, 2.8],
		[-2.25, 0.57, -0.6, 0.62, 2.8], [-1.9, 0.58, -0.6, 0.86, 2.9], [-1.2, 0.58, -0.6, 0.92, 2.9], [-0.2, 0.57, -0.58, 0.92, 2.9],
		[0.6, 0.52, -0.52, 0.88, 2.8], [1.4, 0.42, -0.38, 0.72, 2.6], [2.3, 0.3, -0.18, 0.58, 2.4], [3.2, 0.18, 0.05, 0.48, 2.3],
		[3.95, 0.07, 0.18, 0.42, 2.2],
	]
	# Refined: four rings to each pair of sections, so the livery's lines run smooth along the taper.
	var fine: Array = []
	for i in range(secs.size() - 1):
		for k in 4:
			var t: float = float(k) / 4.0
			var a: Array = secs[i]
			var b: Array = secs[i + 1]
			fine.append([lerpf(a[0], b[0], t), lerpf(a[1], b[1], t), lerpf(a[2], b[2], t), lerpf(a[3], b[3], t), lerpf(a[4], b[4], t)])
	fine.append(secs[secs.size() - 1])
	var rings: Array = []
	var axis: Array = []
	for sc in fine:
		rings.append(_section(sc[0], sc[1], sc[2], sc[3], sc[4], 32))
		axis.append(Vector3(0, (float(sc[2]) + float(sc[3])) * 0.5, sc[0]))
	# The section at z (interpolated), for the livery: how far up the side (0 the keel, 1 the roof) and the half width.
	var sec_at := func(z: float) -> Vector3:
		for i in range(secs.size() - 1):
			var a: Array = secs[i]
			var b: Array = secs[i + 1]
			if z <= float(b[0]) or i == secs.size() - 2:
				var t: float = clampf((z - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001), 0.0, 1.0)
				return Vector3(lerpf(a[1], b[1], t), lerpf(a[2], b[2], t), lerpf(a[3], b[3], t))
		return Vector3(0.3, -0.3, 0.3)
	bd.loft(rings, func(m: Vector3) -> Color:
		var sc: Vector3 = sec_at.call(m.z)
		var f: float = (m.y - sc.y) / maxf(sc.z - sc.y, 0.01)
		var side: bool = absf(m.x) > sc.x * 0.62
		# The windscreen over the cowling, the cabin's side windows, the stripes, a grey belly.
		if m.z > -2.3 and m.z < -1.86 and f > 0.66:
			return GLASS
		if m.z > -1.78 and m.z < 0.45 and f > 0.64 and f < 0.93 and side:
			return GLASS
		if f > 0.40 and f < 0.50 and m.z > -3.6:
			return RED
		if f < 0.12:
			return BELLY
		return WHITE, axis)
	# The high wing on the cabin roof (strut-braced), red tips; ailerons and flaps as dark lines along the trailing edge.
	_wing(bd, -5.5, 5.5, -1.75, 1.6, 1.25, 0.93, deg_to_rad(1.7), 0.14, RED, 4.9)
	for sx in [-1.0, 1.0]:
		bd.beam(Vector3(sx * 0.6, -0.42, -0.95), Vector3(sx * 2.7, 0.95, -1.15), 0.09, 0.05, METAL, Vector3(0, 0, 1))
		bd.beam(Vector3(sx * 1.2, 0.98, -0.2), Vector3(sx * 5.2, 1.07, -0.25), 0.05, 0.02, DARK, Vector3(0, 0, 1))
	# The tailplane and the swept fin with its rudder.
	_wing(bd, -1.75, 1.75, 3.0, 0.95, 0.75, 0.3, 0.0, 0.1, RED, 1.45)
	var fin: Array = [Vector2(2.45, 0.42), Vector2(3.95, 0.42), Vector2(3.95, 1.72), Vector2(3.5, 1.72)]
	var fin_l: Array = []
	var fin_r: Array = []
	for p in fin:
		fin_l.append(Vector3(-0.05, p.y, p.x))
		fin_r.append(Vector3(0.05, p.y, p.x))
	var fc := Vector3(0, 1.0, 3.5)
	for k in 4:
		var k2: int = (k + 1) % 4
		var mid_y: float = (fin_l[k].y + fin_l[k2].y) * 0.5
		bd.quad(fin_l[k], fin_l[k2], fin_r[k2], fin_r[k], RED if mid_y > 1.25 else WHITE, fc)
	for side in [fin_l, fin_r]:
		bd.tri(side[0], side[1], side[2], WHITE, fc)
		bd.tri(side[0], side[2], side[3], WHITE, fc)
	# The fin's stripes: a red band over a blue one, on both faces a little proud.
	for sx in [-1.0, 1.0]:
		var x: float = sx * 0.056
		var band := func(y0: float, y1: float, col: Color) -> void:
			var z0a: float = lerpf(2.45, 3.5, (y0 - 0.42) / 1.3)
			var z0b: float = lerpf(2.45, 3.5, (y1 - 0.42) / 1.3)
			bd.quad(Vector3(x, y0, z0a), Vector3(x, y0, 3.95), Vector3(x, y1, 3.95), Vector3(x, y1, z0b), col, Vector3(0, (y0 + y1) * 0.5, 3.4))
		band.call(1.1, 1.3, RED)
		band.call(0.95, 1.05, BLUE)
	# The gear: the nose leg and wheel, the main legs (sprung steel) with wheel fairings.
	bd.cyl(Vector3(0, -0.5, -3.0), Vector3(0, -1.08, -3.1), 0.05, METAL, 8)
	bd.cyl(Vector3(-0.07, -1.16, -3.1), Vector3(0.07, -1.16, -3.1), 0.17, TYRE, 14)
	for sx in [-1.0, 1.0]:
		bd.beam(Vector3(sx * 0.45, -0.52, -0.6), Vector3(sx * 1.2, -1.05, -0.55), 0.14, 0.05, WHITE, Vector3(0, 0, 1))
		bd.cyl(Vector3(sx * 1.13, -1.16, -0.55), Vector3(sx * 1.32, -1.16, -0.55), 0.21, TYRE, 14)
		var fair: Array = []
		var fax: Array = []
		for zz in [[-1.0, 0.04], [-0.85, 0.11], [-0.55, 0.14], [-0.2, 0.11], [0.0, 0.04]]:
			fair.append(_section(float(zz[0]), float(zz[1]), -1.38, -1.38 + float(zz[1]) * 3.0, 2.0, 12))
			fax.append(Vector3(0, -1.38 + float(zz[1]) * 1.5, float(zz[0])))
		for r in fair:
			for i in r.size():
				r[i] = r[i] + Vector3(sx * 1.225, 0, 0)
		for i in fax.size():
			fax[i] = fax[i] + Vector3(sx * 1.225, 0, 0)
		bd.loft(fair, func(_m: Vector3) -> Color: return WHITE, fax)
	# Nav lights: red on the left tip, green on the right, white on the tail; a beacon on the fin's top.
	var lamp := func(at: Vector3, col: Color) -> void:
		bd.cyl(at - Vector3(0.06, 0, 0), at + Vector3(0.06, 0, 0), 0.06, col, 8)
	lamp.call(Vector3(-5.55, 1.1, -1.2), Color(1.0, 0.1, 0.08))
	lamp.call(Vector3(5.55, 1.1, -1.2), Color(0.1, 0.95, 0.3))
	lamp.call(Vector3(0, 0.38, 3.98), Color(1, 1, 1))
	lamp.call(Vector3(0, 1.76, 3.7), Color(1.0, 0.15, 0.1))
	# The exhaust stub under the cowling and the antennas on the cabin roof.
	bd.cyl(Vector3(0.25, -0.55, -2.8), Vector3(0.25, -0.62, -2.4), 0.04, DARK, 6)
	bd.beam(Vector3(0, 0.92, 0.3), Vector3(0, 1.25, 0.55), 0.03, 0.08, DARK, Vector3(0, 0, 1))
	return bd.commit()


static func _build_prop() -> ArrayMesh:
	var bd := Builder.new()
	# The spinner (a cone to the tip) and two blades, slightly twisted, dark with yellow tips.
	var rings: Array = []
	var axis: Array = []
	for zz in [[0.18, 0.2], [0.0, 0.22], [-0.15, 0.17], [-0.28, 0.08], [-0.33, 0.01]]:
		rings.append(_section(float(zz[0]), float(zz[1]), -float(zz[1]), float(zz[1]), 2.0, 14))
		axis.append(Vector3(0, 0, zz[0]))
	bd.loft(rings, func(_m: Vector3) -> Color: return RED, axis)
	for sd in [-1.0, 1.0]:
		var root := Vector3(0, sd * 0.18, 0.05)
		var tip := Vector3(0, sd * 0.95, 0.05)
		bd.beam(root, tip - Vector3(0, sd * 0.1, 0), 0.13, 0.025, DARK, Vector3(cos(0.35), 0, sin(0.35)))
		bd.beam(tip - Vector3(0, sd * 0.1, 0), tip, 0.1, 0.025, Color(0.95, 0.78, 0.1), Vector3(cos(0.25), 0, sin(0.25)))
	return bd.commit()
