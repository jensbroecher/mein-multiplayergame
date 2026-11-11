extends Node3D
## A grey heron standing in the shallows (Yoshino Rapids' ford, regenerate_yoshino_rapids.gd): it stands with its neck
## drawn in, now and then stabs at a fish; when a cart comes within `scare_radius` of where it stands it jumps, flaps up
## with slow deep beats, neck folded and legs trailing, and flies the loop `flight` (world points, away along the river
## and back), round again while carts are still near, then glides in and lands where it stood. Built in code as internal
## children (a level stores the transform and the exports), `size` times life size (the level's wildlife is about twice
## life size, to suit the carts). Local scenery, not synced; it stands still on a headless server and in the generator.

@export var scare_radius := 34.0
@export var size := 1.9
## The flight's loop in world space; it starts and ends where the heron stands (that is added).
@export var flight := PackedVector3Array()
@export var fly_speed := 10.0

const GREY := Color(0.55, 0.58, 0.62)
const GREY_DARK := Color(0.30, 0.32, 0.36)
const WHITE := Color(0.90, 0.90, 0.88)
const BLACK := Color(0.06, 0.06, 0.07)
const BEAK := Color(0.88, 0.68, 0.22)
const LEG := Color(0.55, 0.46, 0.28)

var _home: Transform3D
var _model: Node3D
var _neck: Node3D
var _wing_l: Node3D
var _wing_r: Node3D
var _legs: Node3D
var _state := 0
var _t := 0.0
var _next_strike := 4.0
var _strike_t := -1.0
var _check := 0.0
var _curve: Curve3D
var _dist := 0.0
var _laps := 0
var _active := true


func _ready() -> void:
	_build()
	_home = global_transform
	if Engine.is_editor_hint() or DisplayServer.get_name() == "headless" or _in_generator():
		_active = false
		set_process(false)
		return
	_curve = Curve3D.new()
	_curve.bake_interval = 0.5
	var pts := PackedVector3Array([_home.origin])
	pts.append_array(flight)
	pts.append(_home.origin)
	for i in range(pts.size()):
		var a: Vector3 = pts[maxi(i - 1, 0)]
		var c: Vector3 = pts[mini(i + 1, pts.size() - 1)]
		var h: Vector3 = (c - a) / 6.0
		_curve.add_point(pts[i], -h, h)
	_next_strike = randf_range(3.0, 9.0)


func _in_generator() -> bool:
	for child in get_tree().root.get_children():
		if "regenerate" in str(child.name).to_lower():
			return true
	return false


func _cart_near() -> bool:
	for c in get_tree().get_nodes_in_group("player_carts"):
		if c is Node3D and (c as Node3D).global_position.distance_to(_home.origin) < scare_radius:
			return true
	return false


func _process(delta: float) -> void:
	_t += delta
	_check -= delta
	if _state == 0:
		_stand(delta)
		if _check <= 0.0:
			_check = 0.25
			if _cart_near():
				_state = 1
				_dist = 0.0
				_laps = 0
	else:
		_fly(delta)


## Standing: a slow breathing sway, the neck drawn in; now and then a stab down at the water.
func _stand(delta: float) -> void:
	global_transform = _home
	_wings(0.0, 0.0)
	_legs.rotation = Vector3.ZERO
	var stab := 0.0
	_next_strike -= delta
	if _next_strike <= 0.0 and _strike_t < 0.0:
		_strike_t = 0.0
	if _strike_t >= 0.0:
		_strike_t += delta
		# Out fast, a moment down there, back slowly.
		stab = smoothstep(0.0, 0.18, _strike_t) * (1.0 - smoothstep(0.5, 1.1, _strike_t))
		if _strike_t > 1.1:
			_strike_t = -1.0
			_next_strike = randf_range(5.0, 14.0)
	_neck.rotation = Vector3(stab * 1.15 + 0.03 * sin(_t * 0.7), 0.0, 0.0)
	_neck.position = Vector3(0.0, 0.70, 0.12) + Vector3(0.0, -0.06, 0.12) * stab
	_model.position.y = 0.006 * sin(_t * 1.6)


## Flying the loop: up off the water with hard beats, cruising with slow ones, gliding in to land.
func _fly(delta: float) -> void:
	var total: float = _curve.get_baked_length()
	var takeoff: float = clampf(_dist / 18.0, 0.0, 1.0)
	var landing: float = clampf((total - _dist) / 22.0, 0.0, 1.0)
	var spd: float = fly_speed * lerpf(0.45, 1.0, takeoff) * lerpf(0.35, 1.0, landing)
	_dist += spd * delta
	if _dist >= total:
		_laps += 1
		if _cart_near() and _laps < 4:
			_dist = 18.0
		else:
			_state = 0
			_check = 1.5
			global_transform = _home
			return
	var p: Vector3 = _curve.sample_baked(_dist)
	var q: Vector3 = _curve.sample_baked(minf(_dist + 2.0, total))
	var fwd: Vector3 = q - p
	var flat := Vector3(fwd.x, 0.0, fwd.z)
	if flat.length() < 0.01:
		flat = -_home.basis.z
	flat = flat.normalized()
	var x: Vector3 = Vector3.UP.cross(flat).normalized()
	var pitch: float = clampf(fwd.y / maxf(fwd.length(), 0.01), -0.5, 0.5) * 0.6
	var b := Basis(x, Vector3.UP, flat).rotated(x, -pitch)
	global_transform = Transform3D(b.scaled(Vector3.ONE * size), p)
	# Beats: hard and quick leaving the water, slow and deep cruising, the wings held out gliding in.
	var rate: float = lerpf(4.2, 2.2, takeoff)
	var depth: float = lerpf(0.9, 0.6, takeoff) * smoothstep(0.0, 0.6, landing)
	_wings(1.0, sin(_t * rate * TAU) * depth)
	_neck.rotation = Vector3(-0.55, 0.0, 0.0)
	_neck.position = Vector3(0.0, 0.66, 0.05)
	_legs.rotation = Vector3(1.35 * takeoff * minf(landing * 1.5, 1.0), 0.0, 0.0)
	_model.position.y = 0.0


## The wings: `spread` 0 folded along the body, 1 out; `flap` the beat's angle (radians, positive up).
func _wings(spread: float, flap: float) -> void:
	for side in [-1.0, 1.0]:
		var w: Node3D = _wing_r if side > 0.0 else _wing_l
		var fold := Basis(Vector3.UP, side * lerpf(1.45, 0.0, spread))
		var droop := Basis(Vector3.BACK, side * (lerpf(-0.25, 0.0, spread) + flap))
		w.basis = droop * fold


# ======================================================================================
#  The bird, built in code
# ======================================================================================

func _material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.85
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _ellipsoid(st: SurfaceTool, c: Vector3, r: Vector3, basis: Basis, col: Color, col_low: Color, rings := 6, segs := 8) -> void:
	for i in range(rings):
		for j in range(segs):
			var quad: Array = []
			for d in [[0, 0], [1, 0], [1, 1], [0, 1]]:
				var th: float = PI * float(i + d[0]) / float(rings)
				var ph: float = TAU * float(j + d[1]) / float(segs)
				var n := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
				quad.append([c + basis * (n * r), (basis * (n / r)).normalized(), col.lerp(col_low, smoothstep(0.2, -0.6, n.y))])
			for tri in [[0, 1, 2], [0, 2, 3]]:
				for k in tri:
					st.set_color(quad[k][2])
					st.set_normal(quad[k][1])
					st.add_vertex(quad[k][0])


func _tube(st: SurfaceTool, pts: Array, radii: Array, col: Color, segs := 6) -> void:
	for i in range(pts.size() - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var d: Vector3 = (b - a).normalized()
		var ref: Vector3 = Vector3.RIGHT if absf(d.x) < 0.9 else Vector3.FORWARD
		var u: Vector3 = d.cross(ref).normalized()
		var v: Vector3 = d.cross(u)
		for j in range(segs):
			var a0: float = TAU * float(j) / float(segs)
			var a1: float = TAU * float(j + 1) / float(segs)
			var n0: Vector3 = u * cos(a0) + v * sin(a0)
			var n1: Vector3 = u * cos(a1) + v * sin(a1)
			var ra: float = radii[i]
			var rb: float = radii[i + 1]
			for q in [[a + n0 * ra, n0], [b + n0 * rb, n0], [b + n1 * rb, n1], [a + n0 * ra, n0], [b + n1 * rb, n1], [a + n1 * ra, n1]]:
				st.set_color(col)
				st.set_normal(q[1])
				st.add_vertex(q[0])


func _part(node_name: String, parent: Node3D, build: Callable) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	build.call(st)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = st.commit()
	mi.material_override = _material()
	# It flies: DressingColliders must not leave a collider where it stood.
	mi.set_meta(&"skip_dressing_colliders", true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi, false, Node.INTERNAL_MODE_FRONT)
	return mi


func _build() -> void:
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model, false, Node.INTERNAL_MODE_FRONT)
	scale = Vector3.ONE * size
	# The body, tilted up toward the chest, the short tail, the dark shoulder.
	_part("Body", _model, func(st: SurfaceTool) -> void:
		var tilt := Basis(Vector3.RIGHT, -0.35)
		_ellipsoid(st, Vector3(0.0, 0.66, 0.0), Vector3(0.11, 0.12, 0.27), tilt, GREY, WHITE.darkened(0.1))
		_ellipsoid(st, Vector3(0.0, 0.58, -0.25), Vector3(0.07, 0.04, 0.12), Basis(Vector3.RIGHT, 0.2), GREY_DARK, GREY)
		_ellipsoid(st, Vector3(0.0, 0.73, 0.14), Vector3(0.085, 0.07, 0.08), Basis(), WHITE, GREY))
	# The legs, a pivot at the hip so they trail behind in flight.
	_legs = Node3D.new()
	_legs.name = "Legs"
	_legs.position = Vector3(0.0, 0.58, -0.02)
	_model.add_child(_legs, false, Node.INTERNAL_MODE_FRONT)
	_part("LegMesh", _legs, func(st: SurfaceTool) -> void:
		for sx in [-1.0, 1.0]:
			_tube(st, [Vector3(sx * 0.04, 0.0, 0.0), Vector3(sx * 0.045, -0.28, 0.03), Vector3(sx * 0.05, -0.58, 0.02)], [0.018, 0.012, 0.011], LEG)
			for toe in [-0.5, 0.0, 0.5]:
				_tube(st, [Vector3(sx * 0.05, -0.58, 0.02), Vector3(sx * 0.05 + sin(toe) * 0.09, -0.585, 0.02 + cos(toe) * 0.09)], [0.008, 0.005], LEG, 4))
	# The neck in an S, the head with its black crest and stripe, the dagger of a beak; a pivot at the neck's foot.
	_neck = Node3D.new()
	_neck.name = "Neck"
	_neck.position = Vector3(0.0, 0.70, 0.12)
	_model.add_child(_neck, false, Node.INTERNAL_MODE_FRONT)
	_part("NeckMesh", _neck, func(st: SurfaceTool) -> void:
		var spine: Array = [Vector3(0, 0.0, 0.0), Vector3(0, 0.08, 0.08), Vector3(0, 0.16, 0.06), Vector3(0, 0.24, 0.0), Vector3(0, 0.31, 0.03), Vector3(0, 0.35, 0.09)]
		_tube(st, spine, [0.05, 0.042, 0.036, 0.033, 0.032, 0.03], WHITE)
		var head := Vector3(0.0, 0.37, 0.11)
		_ellipsoid(st, head, Vector3(0.035, 0.035, 0.055), Basis(), WHITE, WHITE.darkened(0.1), 5, 7)
		_tube(st, [head + Vector3(0.0, 0.025, -0.02), head + Vector3(0.0, 0.03, -0.12), head + Vector3(0.0, 0.0, -0.2)], [0.012, 0.008, 0.002], BLACK, 4)
		for sx in [-1.0, 1.0]:
			_ellipsoid(st, head + Vector3(sx * 0.03, 0.012, 0.0), Vector3(0.008, 0.012, 0.04), Basis(), BLACK, BLACK, 3, 5)
		_tube(st, [head + Vector3(0.0, -0.005, 0.045), head + Vector3(0.0, -0.01, 0.13), head + Vector3(0.0, -0.015, 0.2)], [0.017, 0.01, 0.0015], BEAK, 6)
		_tube(st, [Vector3(0.0, 0.2, 0.08), Vector3(0.0, 0.08, 0.13)], [0.012, 0.006], GREY_DARK, 4))
	# The wings, each hinged at its shoulder: span out along x, the black flight feathers at the tip and trailing edge.
	for side in [-1.0, 1.0]:
		var w := Node3D.new()
		w.name = "WingR" if side > 0.0 else "WingL"
		w.position = Vector3(side * 0.09, 0.72, 0.06)
		_model.add_child(w, false, Node.INTERNAL_MODE_FRONT)
		var sgn: float = side
		_part("WingMesh", w, func(st: SurfaceTool) -> void:
			var span := 0.85
			var outline: Array = [Vector2(0.0, 0.08), Vector2(span * 0.45, 0.10), Vector2(span * 0.8, 0.05), Vector2(span, -0.04), Vector2(span * 0.95, -0.2), Vector2(span * 0.6, -0.26), Vector2(span * 0.25, -0.24), Vector2(0.0, -0.18)]
			var c := Vector2(span * 0.4, -0.08)
			for i in range(outline.size()):
				var a: Vector2 = outline[i]
				var b: Vector2 = outline[(i + 1) % outline.size()]
				for v in [c, a, b]:
					var vv: Vector2 = v
					var dark: bool = vv.x > span * 0.7 or vv.y < -0.2
					st.set_color(BLACK.lerp(GREY_DARK, 0.3) if dark else GREY)
					st.set_normal(Vector3.UP)
					st.add_vertex(Vector3(sgn * vv.x, 0.0, vv.y)))
		if side > 0.0:
			_wing_r = w
		else:
			_wing_l = w
	_wings(0.0, 0.0)
