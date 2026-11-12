extends RefCounted
## Tianqiao's buildings and fittings (regenerate_tianqiao.gd, the Yunhai GP's megacity at night): towers, roofs and
## parapets, LED lines, glass balustrades, neon signs, lanterns, the mall's interior, the aquarium's rocks. Unlike the
## other kits it builds in GAME metres and in world space (the stage calls it through `_add_prop_game` with an identity
## frame), since its towers are hundreds of metres tall and their facades are drawn by `megacity_tower.gdshader` from UVs
## in metres: a wall's UV is (metres along it + 1000 x the building's number, metres up from the street). Its keys:
##   "tower"   megacity_tower.gdshader: the facade's style in COLOR.a (STYLE_* / 8), its tint in COLOR.rgb
##   "led"     megacity_led.gdshader: self-lit strips, a chase running along them (COLOR.a: how much rainbow)
##   "neon"    neon_emissive.gdshader: neon tubes, lanterns, lit panels
##   "glass"   a clear balustrade's glass (see-through: DressingColliders makes nothing of it, the stage adds boxes)
##   "acrylic" the aquarium tunnel's tube
##   "tank"    aquarium_tank.gdshader: what lies in the tanks
##   anything else: YardKit's (CampKit's vertex-colour keys "paint", "matte", "metal", "steel", "chrome", ...)
## Everything is fictional: the city, its towers, its shops' names.

const PropKit = preload("res://PropKit.gd")
const YK = preload("res://YardKit.gd")

const STYLE_OFFICE := 0
const STYLE_FLATS := 1
const STYLE_MEDIA := 2
const STYLE_SHOPS := 3
const STYLE_INTERIOR := 4
const STYLE_CONCRETE := 5
const STYLE_CLADDING := 6

static var _mats := {}


static func new_kit(scale: float) -> PropKit:
	YK.uvk = scale
	var pk := PropKit.new()
	pk.material_for = func(key: String) -> Material: return material(key)
	return pk


static func commit(pk: PropKit, kit: Dictionary) -> ArrayMesh:
	return pk.commit(kit)


static func material(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m: Material
	match key:
		"tower":
			var sm := ShaderMaterial.new()
			sm.shader = load("res://megacity_tower.gdshader")
			m = sm
		"led":
			var sm2 := ShaderMaterial.new()
			sm2.shader = load("res://megacity_led.gdshader")
			m = sm2
		"neon":
			var sm3 := ShaderMaterial.new()
			sm3.shader = load("res://neon_emissive.gdshader")
			sm3.set_shader_parameter("energy", 4.0)
			m = sm3
		"glass", "acrylic":
			var g := StandardMaterial3D.new()
			g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			g.cull_mode = BaseMaterial3D.CULL_DISABLED
			g.albedo_color = Color(0.55, 0.75, 0.85, 0.16) if key == "glass" else Color(0.45, 0.75, 0.9, 0.1)
			g.roughness = 0.05
			g.metallic = 0.3
			g.metallic_specular = 0.8
			m = g
		"tank":
			var sm4 := ShaderMaterial.new()
			sm4.shader = load("res://aquarium_tank.gdshader")
			m = sm4
		_:
			m = YK.make_material(key)
	_mats[key] = m
	return m


static func _style_col(tint: Color, style: int) -> Color:
	return Color(tint.r, tint.g, tint.b, float(style) / 8.0)


## A wall from a to b in plan (y ignored), y0 to y1, facing `out`; its UV from `u0` metres along (plus the building's
## number x 1000).
static func wall(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, y0: float, y1: float, out: Vector3, tint: Color, style: int, id: int,
		u0 := 0.0) -> void:
	var l: float = Vector2(b.x - a.x, b.z - a.z).length()
	var o: float = float(id % 64) * 1000.0 + u0
	pk.quad(kit, "tower", [Vector3(a.x, y0, a.z), Vector3(b.x, y0, b.z), Vector3(b.x, y1, b.z), Vector3(a.x, y1, a.z)], out, _style_col(tint, style),
			[Vector2(o, y0), Vector2(o + l, y0), Vector2(o + l, y1), Vector2(o, y1)])


## An upright prism over a convex or concave plan polygon (Vector2 x, z, either winding) from y0 to y1: its walls, a
## concrete roof (if `roof`), and nothing underneath.
static func prism(pk: PropKit, kit: Dictionary, plan: PackedVector2Array, y0: float, y1: float, tint: Color, style: int, id: int, roof := true,
		roof_tint := Color(0.36, 0.36, 0.38)) -> void:
	var n: int = plan.size()
	var area := 0.0
	for i in range(n):
		var p: Vector2 = plan[i]
		var q: Vector2 = plan[(i + 1) % n]
		area += p.x * q.y - q.x * p.y
	var ccw: bool = area > 0.0
	var u := 0.0
	for i in range(n):
		var p2: Vector2 = plan[i]
		var q2: Vector2 = plan[(i + 1) % n]
		var e: Vector2 = q2 - p2
		var out2 := Vector2(e.y, -e.x).normalized() if ccw else Vector2(-e.y, e.x).normalized()
		# Going round so the wall reads left to right from outside.
		wall(pk, kit, Vector3(p2.x, 0, p2.y), Vector3(q2.x, 0, q2.y), y0, y1, Vector3(out2.x, 0, out2.y), tint, style, id, u)
		u += e.length()
	if roof:
		flat(pk, kit, plan, y1, Vector3.UP, roof_tint, STYLE_CONCRETE)


## A flat polygon at height y (plan Vector2 x, z) facing up or down; UV world XZ.
static func flat(pk: PropKit, kit: Dictionary, plan: PackedVector2Array, y: float, n: Vector3, tint: Color, style: int) -> void:
	var idx: PackedInt32Array = Geometry2D.triangulate_polygon(plan)
	var col: Color = _style_col(tint, style)
	for t in range(0, idx.size(), 3):
		var a: Vector2 = plan[idx[t]]
		var b: Vector2 = plan[idx[t + 1]]
		var c: Vector2 = plan[idx[t + 2]]
		pk.tri(kit, "tower", Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), Vector3(c.x, y, c.y), n, n, n, col, n, a, b, c)


## A rectangle's plan, chamfered at its corners by `ch` (0: square).
static func rect_plan(c: Vector2, hx: float, hz: float, ch := 0.0) -> PackedVector2Array:
	if ch <= 0.0:
		return PackedVector2Array([c + Vector2(-hx, -hz), c + Vector2(hx, -hz), c + Vector2(hx, hz), c + Vector2(-hx, hz)])
	return PackedVector2Array([c + Vector2(-hx + ch, -hz), c + Vector2(hx - ch, -hz), c + Vector2(hx, -hz + ch), c + Vector2(hx, hz - ch),
		c + Vector2(hx - ch, hz), c + Vector2(-hx + ch, hz), c + Vector2(-hx, hz - ch), c + Vector2(-hx, -hz + ch)])


## A tower: a podium of shops (to `podium` metres, if over 0), the shaft in `style` to `top`, a roof, a parapet with an
## LED line, rooftop plant; `led_corners` runs LED strips up its corners (`led_col`).
static func tower(pk: PropKit, kit: Dictionary, c: Vector2, hx: float, hz: float, y0: float, top: float, tint: Color, style: int, id: int,
		ch := 0.0, podium := 0.0, led_corners := false, led_col := Color(0.3, 0.8, 1.0, 0.0), plant := true, roof_parapet := true) -> void:
	var plan := rect_plan(c, hx, hz, ch)
	if podium > 0.0:
		prism(pk, kit, rect_plan(c, hx + 3.0, hz + 3.0, ch), y0, y0 + podium, Color(0.55, 0.5, 0.45), STYLE_SHOPS, id, true)
		prism(pk, kit, plan, y0 + podium, top, tint, style, id, false)
	else:
		prism(pk, kit, plan, y0, top, tint, style, id, false)
	flat(pk, kit, plan, top, Vector3.UP, Color(0.32, 0.32, 0.34), STYLE_CONCRETE)
	if roof_parapet:
		parapet(pk, kit, plan, top, 1.3, 0.4, Color(0.2, 0.21, 0.24))
	if led_corners:
		for p in plan:
			led_line(pk, kit, Vector3(p.x, y0 + podium + 2.0, p.y), Vector3(p.x, top + 1.3, p.y), led_col, 0.35)
	if plant:
		_roof_plant(pk, kit, c, minf(hx, hz), top, id)


## A parapet round a roof's plan: `h` high, `th` thick, inside the outline; its top edge an LED line.
static func parapet(pk: PropKit, kit: Dictionary, plan: PackedVector2Array, y: float, h: float, th: float, tint: Color, led := Color(0.25, 0.8, 1.0, 0.0),
		skip := []) -> void:
	var n: int = plan.size()
	var area := 0.0
	for i in range(n):
		area += plan[i].x * plan[(i + 1) % n].y - plan[(i + 1) % n].x * plan[i].y
	var ccw: bool = area > 0.0
	for i in range(n):
		if skip.has(i):
			continue
		var p: Vector2 = plan[i]
		var q: Vector2 = plan[(i + 1) % n]
		var e: Vector2 = q - p
		var out2 := Vector2(e.y, -e.x).normalized() if ccw else Vector2(-e.y, e.x).normalized()
		var inn: Vector2 = -out2 * th
		wall(pk, kit, Vector3(p.x, 0, p.y), Vector3(q.x, 0, q.y), y - 0.02, y + h, Vector3(out2.x, 0, out2.y), tint, STYLE_CLADDING, 0)
		wall(pk, kit, Vector3(q.x + inn.x, 0, q.y + inn.y), Vector3(p.x + inn.x, 0, p.y + inn.y), y, y + h, Vector3(-out2.x, 0, -out2.y), tint, STYLE_CONCRETE, 0)
		pk.quad(kit, "tower", [Vector3(p.x, y + h, p.y), Vector3(q.x, y + h, q.y), Vector3(q.x + inn.x, y + h, q.y + inn.y), Vector3(p.x + inn.x, y + h, p.y + inn.y)],
				Vector3.UP, _style_col(tint.lightened(0.2), STYLE_CONCRETE), [p, q, q + inn, p + inn])
		led_line(pk, kit, Vector3(p.x, y + h + 0.06, p.y) + Vector3(inn.x, 0, inn.y) * 0.5, Vector3(q.x, y + h + 0.06, q.y) + Vector3(inn.x, 0, inn.y) * 0.5, led, 0.12)


## A self-lit LED strip from a to b, `w` wide and as thick (the chase runs along it; COLOR.a rainbow).
static func led_line(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, col: Color, w := 0.12) -> void:
	if a.distance_to(b) < 0.05:
		return
	pk.beam(kit, "led", a, b, w, w, col)


## A neon tube (a thin self-lit beam).
static func neon_tube(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, col: Color, r := 0.09) -> void:
	if a.distance_to(b) < 0.05:
		return
	pk.beam(kit, "neon", a, b, r * 2.0, r * 2.0, col)


## A glass balustrade from a to b on the floor at their heights, `h` high: glass with a steel top rail, an LED strip
## along its foot (`led`).
static func glass_rail(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, h: float, led := Color(0.3, 0.8, 1.0, 0.0)) -> void:
	var up := Vector3(0, h, 0)
	var d: Vector3 = b - a
	var side: Vector3 = Vector3.UP.cross(d).normalized()
	pk.quad(kit, "glass", [a + Vector3(0, 0.1, 0), b + Vector3(0, 0.1, 0), b + up, a + up], side, Color(1, 1, 1))
	pk.beam(kit, "steel", a + up, b + up, 0.09, 0.12, Color(0.6, 0.62, 0.66), Vector3.UP)
	pk.beam(kit, "steel", a + Vector3(0, 0.05, 0), b + Vector3(0, 0.05, 0), 0.14, 0.1, Color(0.25, 0.26, 0.28), Vector3.UP)
	led_line(pk, kit, a + Vector3(0, 0.12, 0) - side * 0.09, b + Vector3(0, 0.12, 0) - side * 0.09, led, 0.06)


## A neon sign: a dark board `w` x `h` facing `out` (centre `c`), a neon tube round its edge, the text in a Label3D lit
## in `col` (HDR, so it blooms). `vertical` stacks the characters one under the other.
static func neon_sign(pk: PropKit, kit: Dictionary, labels: Array, c: Vector3, out: Vector3, w: float, h: float, text: String, col: Color,
		vertical := false, depth := 0.3) -> void:
	var o: Vector3 = Vector3(out.x, 0, out.z).normalized()
	var side: Vector3 = Vector3.UP.cross(o).normalized()
	var bx := Transform3D(Basis(side, Vector3.UP, o), c - o * depth * 0.5)
	pk.box(kit, "paint", bx, Vector3(w, h, depth), Color(0.06, 0.06, 0.08))
	var f: Vector3 = c + o * 0.04
	var hw: float = w * 0.5 - 0.15
	var hh: float = h * 0.5 - 0.15
	var p0: Vector3 = f - side * hw - Vector3(0, hh, 0)
	var p1: Vector3 = f + side * hw - Vector3(0, hh, 0)
	var p2: Vector3 = f + side * hw + Vector3(0, hh, 0)
	var p3: Vector3 = f - side * hw + Vector3(0, hh, 0)
	for e in [[p0, p1], [p1, p2], [p2, p3], [p3, p0]]:
		neon_tube(pk, kit, e[0], e[1], col, 0.06)
	var t: String = text
	if vertical:
		var chars: PackedStringArray = []
		for i in range(text.length()):
			chars.append(text[i])
		t = "\n".join(chars)
	var cap: float = (h - 0.6) / float(maxi(text.length(), 1)) * 0.78 if vertical else (h - 0.5) * 0.62
	labels.append([t, f + o * 0.03, o, cap, Color(col.r * 3.0, col.g * 3.0, col.b * 3.0, 1.0), (w - 0.5) if not vertical else 0.0])


## A red lantern (denglong) hanging at c: a glowing barrel with gold caps and a tassel, `s` across.
static func lantern(pk: PropKit, kit: Dictionary, c: Vector3, s := 1.0, col := Color(1.0, 0.18, 0.1)) -> void:
	var r: float = 0.5 * s
	pk.lathe(kit, "neon", c, [Vector2(0.001, -0.42 * s), Vector2(r * 0.55, -0.42 * s), Vector2(r * 0.85, -0.3 * s), Vector2(r, 0.0), Vector2(r * 0.85, 0.3 * s),
			Vector2(r * 0.55, 0.42 * s), Vector2(0.001, 0.42 * s)], 12, col)
	for y in [-0.44 * s, 0.44 * s]:
		pk.tube(kit, "paint", c + Vector3(0, y - 0.04 * s, 0), c + Vector3(0, y + 0.04 * s, 0), r * 0.6, r * 0.6, 10, Color(0.85, 0.62, 0.15))
	pk.tube(kit, "paint", c + Vector3(0, -0.48 * s, 0), c + Vector3(0, -0.85 * s, 0), 0.04 * s, 0.07 * s, 6, Color(0.9, 0.2, 0.1))
	pk.tube(kit, "metal", c + Vector3(0, 0.48 * s, 0), c + Vector3(0, 0.9 * s, 0), 0.02, 0.02, 4, Color(0.2, 0.2, 0.2), false)


## Rooftop plant on a tower's roof: cooling towers, plant rooms, a mast with a red light, all clear of the middle.
static func _roof_plant(pk: PropKit, kit: Dictionary, c: Vector2, half: float, y: float, id: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = id * 7919 + 13
	var n: int = rng.randi_range(2, 4)
	for i in range(n):
		var a: float = TAU * float(i) / float(n) + rng.randf() * 0.6
		var r: float = half * rng.randf_range(0.35, 0.65)
		var p := c + Vector2(cos(a), sin(a)) * r
		var sx: float = rng.randf_range(3.0, 6.0)
		var sz: float = rng.randf_range(3.0, 6.0)
		var h: float = rng.randf_range(2.5, 5.0)
		prism(pk, kit, rect_plan(p, sx * 0.5, sz * 0.5), y, y + h, Color(0.4, 0.41, 0.43), STYLE_CONCRETE, id, true)
	if rng.randf() < 0.6:
		var m := Vector3(c.x + half * 0.5, y, c.y - half * 0.5)
		pk.tube(kit, "steel", m, m + Vector3(0, 14.0, 0), 0.25, 0.12, 6, Color(0.5, 0.5, 0.52))
		pk.lathe(kit, "neon", m + Vector3(0, 14.2, 0), [Vector2(0.001, -0.25), Vector2(0.3, 0.0), Vector2(0.001, 0.25)], 8, Color(1.0, 0.1, 0.05))


## The aquarium's rocks: a heap of lumps on the floor at c, `r` across, in the tanks' material.
static func rock_heap(pk: PropKit, kit: Dictionary, c: Vector3, r: float, rng: RandomNumberGenerator, col := Color(0.45, 0.42, 0.36)) -> void:
	var n: int = rng.randi_range(4, 8)
	for i in range(n):
		var a: float = rng.randf() * TAU
		var d: float = rng.randf() * r * 0.6
		var s: float = r * rng.randf_range(0.25, 0.55)
		var p := c + Vector3(cos(a) * d, s * 0.35, sin(a) * d)
		var prof: Array = [Vector2(0.001, -s * 0.5), Vector2(s * 0.8, -s * 0.4), Vector2(s, 0.0), Vector2(s * 0.7, s * 0.45), Vector2(0.001, s * 0.6)]
		pk.lathe(kit, "tank", p, prof, 7, col.lightened(rng.randf_range(-0.15, 0.15)), true, Basis(Vector3.UP, rng.randf() * TAU))


## A coral: a fan of branching tubes from c in `col`.
static func coral(pk: PropKit, kit: Dictionary, c: Vector3, h: float, col: Color, rng: RandomNumberGenerator) -> void:
	for i in range(rng.randi_range(4, 7)):
		var a: float = rng.randf() * TAU
		var tip: Vector3 = c + Vector3(cos(a) * h * 0.45, h * rng.randf_range(0.6, 1.0), sin(a) * h * 0.45)
		pk.tube(kit, "tank", c, tip, 0.12 * h, 0.04 * h, 5, col)
		var mid: Vector3 = c.lerp(tip, 0.55)
		pk.tube(kit, "tank", mid, mid + Vector3(cos(a + 1.0), 0.8, sin(a + 1.0)) * h * 0.35, 0.06 * h, 0.03 * h, 4, col.lightened(0.1))
