extends RefCounted
## Bloombay's buildings for a skyline seen from a stage (the Lakeside Meadows' horizon, regenerate_lakeside.gd): boxes
## whose facades city_building.gdshader draws (UV.x metres along a wall stretched to whole bays, UV.y metres up from
## the street; UV2.x the shop fronts, UV2.y the window style; COLOR.a 0 windows, 0.7 plain, 1 glass), hipped roofs in
## vertex colour (terracotta or slate), and downtown's blue glass towers (a podium, a shaft square, chamfered, octagonal
## or round, stepping back once or twice, a plain crown, some with a mast), as on Harbor Pier. Call `begin()`, add
## buildings, then `commit()` into one mesh with two surfaces (walls, roofs).

const STOREY := 5.0
const BAY := 5.6
const SHOP_H := 6.4
const WALL_PAINTS := [Color(0.93, 0.88, 0.76), Color(0.94, 0.93, 0.90), Color(0.86, 0.72, 0.48), Color(0.80, 0.52, 0.40),
		Color(0.72, 0.80, 0.84), Color(0.74, 0.84, 0.76), Color(0.90, 0.74, 0.70), Color(0.74, 0.72, 0.68), Color(0.90, 0.84, 0.62)]
const TOWER_GLASS := [Color(0.36, 0.54, 0.76), Color(0.30, 0.48, 0.72), Color(0.44, 0.60, 0.80), Color(0.26, 0.42, 0.62), Color(0.40, 0.62, 0.74)]
const STONE := [Color(0.82, 0.80, 0.76), Color(0.70, 0.72, 0.74), Color(0.86, 0.84, 0.78)]

var walls := SurfaceTool.new()
var roofs := SurfaceTool.new()
var count := 0


func begin() -> void:
	walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	roofs.begin(Mesh.PRIMITIVE_TRIANGLES)
	count = 0


## A building of `storeys` over the street at `ground` (its walls run on 2m down), `w` x `d`, turned `yaw`, with a
## hipped roof (`roof` 0 terracotta, 1 slate) or a flat one (2).
func building(x: float, z: float, ground: float, w: float, d: float, yaw: float, storeys: int, col: Color, roof: int, style: int) -> void:
	var plan := PackedVector2Array([Vector2(-w, -d) * 0.5, Vector2(w, -d) * 0.5, Vector2(w, d) * 0.5, Vector2(-w, d) * 0.5])
	var top: float = ground + float(storeys) * STOREY + 1.2
	prism(x, z, plan, yaw, ground - 2.0, top, ground, col, 0.0, style, roof != 2)
	if roof != 2:
		var rc: Color = Color(0.74, 0.40, 0.27) if roof == 0 else Color(0.40, 0.42, 0.46)
		hip_roof(Vector3(x, top, z), w + 0.8, d + 0.8, yaw, 0.55 if roof == 0 else 0.8, rc)
	count += 1


## A downtown tower: a stone podium, a glass shaft `storeys` high stepping back, a crown, maybe a mast.
func tower(x: float, z: float, ground: float, w: float, storeys: int, rng: RandomNumberGenerator) -> void:
	var yaw: float = (0.0 if rng.randf() < 0.6 else PI * 0.25) + rng.randf_range(-0.05, 0.05)
	var col: Color = TOWER_GLASS[rng.randi() % TOWER_GLASS.size()]
	var stone: Color = STONE[rng.randi() % STONE.size()]
	var pod: float = w * rng.randf_range(1.25, 1.5)
	var pod_h: float = SHOP_H + STOREY * float(rng.randi_range(1, 3))
	prism(x, z, plan_shape(0, pod * 0.5), yaw, ground - 2.0, ground + pod_h, ground, stone, 0.0, rng.randi() % 4)
	var shape: int = rng.randi() % 4
	var r: float = w * 0.5
	var y0: float = ground + pod_h
	var total: float = float(storeys) * STOREY
	var tiers: int = rng.randi_range(1, 3)
	var shares: Array = [1.0] if tiers == 1 else ([0.72, 0.28] if tiers == 2 else [0.6, 0.25, 0.15])
	for k in range(tiers):
		var y1: float = y0 + total * float(shares[k])
		prism(x, z, plan_shape(shape, r), yaw, y0, y1, ground, col, 1.0, 0)
		prism(x, z, plan_shape(shape, r + 0.4), yaw, y1 - 0.9, y1, ground, stone, 0.7, 0)
		y0 = y1
		r *= rng.randf_range(0.72, 0.85)
	prism(x, z, plan_shape(shape, r * 0.8), yaw, y0, y0 + 4.5, ground, stone.darkened(0.1), 0.7, 0)
	if rng.randf() < 0.45:
		prism(x, z, plan_shape(1, 0.7), yaw, y0 + 4.5, y0 + 4.5 + rng.randf_range(14.0, 34.0), ground, Color(0.75, 0.76, 0.78), 0.7, 0)
	count += 1


## A plan: 0 a square, 1 a chamfered square, 2 an octagon, 3 a round drum (12 sides), `r` its half width.
static func plan_shape(kind: int, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match kind:
		0:
			pts = PackedVector2Array([Vector2(-r, -r), Vector2(r, -r), Vector2(r, r), Vector2(-r, r)])
		1:
			var c := r * 0.3
			pts = PackedVector2Array([Vector2(-r + c, -r), Vector2(r - c, -r), Vector2(r, -r + c), Vector2(r, r - c), Vector2(r - c, r), Vector2(-r + c, r), Vector2(-r, r - c), Vector2(-r, -r + c)])
		_:
			var n: int = 8 if kind == 2 else 12
			for i in range(n):
				var a := TAU * (float(i) + 0.5) / float(n)
				pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


## A prism of a plan polygon between y0 and y1 (walls in the facade convention, `kind` the COLOR.a), and a flat top
## unless `open_top` (a hipped roof goes on it).
func prism(x: float, z: float, plan: PackedVector2Array, yaw: float, y0: float, y1: float, street: float, col: Color, kind: float, style: int,
		open_top := false) -> void:
	var b := Basis(Vector3.UP, yaw)
	var n := plan.size()
	var c := col
	c.a = kind
	var pts: Array = []
	for p in plan:
		pts.append(b * Vector3(p.x, 0, p.y) + Vector3(x, 0, z))
	var u := 0.0
	for i in range(n):
		var a: Vector3 = pts[i]
		var e: Vector3 = pts[(i + 1) % n]
		var mid: Vector3 = (a + e) * 0.5
		var out := Vector3(mid.x - x, 0, mid.z - z).normalized()
		var edge := Vector3(e.x - a.x, 0, e.z - a.z)
		var nrm := edge.cross(Vector3.UP).normalized()
		if nrm.dot(out) < 0.0:
			nrm = -nrm
		var length: float = edge.length()
		var ul: float = maxf(1.0, round(length / (BAY * 0.5))) * BAY * 0.5
		var s1: float = maxf(1.0, round(length / (BAY * 1.5))) * BAY * 1.5
		quad(walls, [Vector3(a.x, y0, a.z), Vector3(e.x, y0, e.z), Vector3(e.x, y1, e.z), Vector3(a.x, y1, a.z)],
				[Vector2(u, y0 - street), Vector2(u + ul, y0 - street), Vector2(u + ul, y1 - street), Vector2(u, y1 - street)],
				[Vector2(0, style), Vector2(s1, style), Vector2(s1, style), Vector2(0, style)], nrm, c)
		u += ul
	if open_top:
		return
	var rc := col.darkened(0.25)
	rc.a = 0.0
	var centre := Vector3(x, y1, z)
	var z4 := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	for i in range(n):
		var a2: Vector3 = pts[i]
		var e2: Vector3 = pts[(i + 1) % n]
		quad(walls, [centre, Vector3(a2.x, y1, a2.z), Vector3(e2.x, y1, e2.z), centre], z4, z4, Vector3.UP, rc)


func hip_roof(at: Vector3, w: float, d: float, yaw: float, pitch: float, col: Color) -> void:
	var b := Basis(Vector3.UP, yaw)
	if d > w:
		b = Basis(Vector3.UP, yaw + PI * 0.5)
		var tmp := w
		w = d
		d = tmp
	var hw := w * 0.5
	var hd := d * 0.5
	var rh: float = hd * pitch
	var e := [Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd), Vector3(hw, 0, hd), Vector3(-hw, 0, hd)]
	var r0 := Vector3(-hw + hd, rh, 0)
	var r1 := Vector3(hw - hd, rh, 0)
	for f in [[[e[3], e[2], r1, r0], Vector3(0, 1, pitch)], [[e[1], e[0], r0, r1], Vector3(0, 1, -pitch)],
			[[e[2], e[1], r1], Vector3(pitch, 1, 0)], [[e[0], e[3], r0], Vector3(-pitch, 1, 0)]]:
		var ps: Array = f[0]
		var nrm: Vector3 = (b * (f[1] as Vector3)).normalized()
		var wp: Array = []
		for pp in ps:
			wp.append(at + b * (pp as Vector3))
		var tris: Array = [[0, 1, 2], [0, 2, 3]] if wp.size() == 4 else [[0, 1, 2]]
		for t in tris:
			tri(roofs, wp[t[0]], wp[t[1]], wp[t[2]], nrm, col)


func quad(st: SurfaceTool, q: Array, uv: Array, uv2: Array, out: Vector3, col: Color) -> void:
	for t in [[0, 1, 2], [0, 2, 3]]:
		var ia: int = t[0]
		var ib: int = t[1]
		var ic: int = t[2]
		if ((q[ic] as Vector3) - (q[ia] as Vector3)).cross((q[ib] as Vector3) - (q[ia] as Vector3)).dot(out) < 0.0:
			var tmp := ib
			ib = ic
			ic = tmp
		for k in [ia, ib, ic]:
			st.set_color(col)
			st.set_normal(out)
			st.set_uv(uv[k])
			st.set_uv2(uv2[k])
			st.add_vertex(q[k])


static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3, col: Color) -> void:
	if (c - a).cross(b - a).dot(out) < 0.0:
		var t := b
		b = c
		c = t
	for v in [a, b, c]:
		st.set_color(col)
		st.set_normal(out)
		st.add_vertex(v)


## The walls' material: city_building.gdshader, its made-up reflections set to the stage's sky, the far glass blue.
static func wall_material(sky_top: Color, horizon: Color, ground: Color, cloud: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://city_building.gdshader")
	m.set_shader_parameter("concrete_tex", load("res://materials/concrete.png"))
	m.set_shader_parameter("storey", STOREY)
	m.set_shader_parameter("bay", BAY)
	m.set_shader_parameter("shop_h", SHOP_H)
	m.set_shader_parameter("refl_top", sky_top)
	m.set_shader_parameter("refl_horizon", horizon)
	m.set_shader_parameter("refl_ground", ground)
	m.set_shader_parameter("refl_cloud", cloud)
	m.set_shader_parameter("sky_reflect", Color(0.36, 0.54, 0.80))
	m.set_shader_parameter("glass_dark", Color(0.08, 0.14, 0.26))
	m.set_shader_parameter("refl_base", 0.16)
	return m


static func roof_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.85
	return m


func commit(wall_mat: Material, roof_mat: Material) -> ArrayMesh:
	walls.index()
	var mesh := walls.commit()
	mesh.surface_set_material(0, wall_mat)
	roofs.index()
	roofs.generate_normals()
	roofs.commit(mesh)
	mesh.surface_set_material(mesh.get_surface_count() - 1, roof_mat)
	return mesh
