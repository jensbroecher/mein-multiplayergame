extends RefCounted
## The menu tiles' props (MenuTileStage.gd), built through a PropKit: the road's marker posts, cones and a
## start gantry at game scale, and the Options tile's workbench at life size (metres; the bench top at y 0):
## an anti-static mat, a 16-inch laptop open on the car's settings (a live page drawn on its screen in 3D), a pro pistol-grip transmitter
## (graphite and the tile's colour, a foam wheel, a trigger, a colour touchscreen), a set-up stand for the
## car, hex drivers and a LiPo pack. Vertex-colour materials by key (`material`).

const PropKit = preload("res://PropKit.gd")

static var _mats := {}


## A vertex-colour material, cached by its roughness (and metal).
static func vc_material(rough: float, metal := 0.0) -> StandardMaterial3D:
	var key := "%.2f_%.2f" % [rough, metal]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = rough
	m.metallic = metal
	_mats[key] = m
	return m


## The bench's keys: matte plastic and rubber, gloss paint, anodised metal, glass, glowing LEDs.
static func material(key: String) -> Material:
	match key:
		"rubber":
			return vc_material(0.92)
		"matte":
			return vc_material(0.62)
		"gloss":
			return vc_material(0.22)
		"metal":
			return vc_material(0.3, 0.85)
		"glass":
			return vc_material(0.06, 0.2)
		"led":
			if not _mats.has("led"):
				var m := StandardMaterial3D.new()
				m.vertex_color_use_as_albedo = true
				m.vertex_color_is_srgb = true
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				_mats["led"] = m
			return _mats["led"]
	return vc_material(0.6)


# --- the road's furniture (game scale) ------------------------------------------------------------

## A white marker post with a red reflector band, 1.6m (a delineator at the race's scale).
static func marker_post(pk: PropKit, kit: Dictionary) -> void:
	pk.box(kit, "m", Transform3D(Basis(), Vector3(0, 0.8, 0)), Vector3(0.22, 1.6, 0.16), Color(0.92, 0.92, 0.9))
	pk.box(kit, "m", Transform3D(Basis(), Vector3(0, 1.32, 0.0)), Vector3(0.225, 0.22, 0.165), Color(0.85, 0.1, 0.06))
	pk.box(kit, "m", Transform3D(Basis(), Vector3(0, 1.6, 0)), Vector3(0.24, 0.04, 0.18), Color(0.1, 0.1, 0.1))


## A traffic cone, 0.45m at life size (the caller grows it), orange with a white band.
static func cone(pk: PropKit, kit: Dictionary) -> void:
	pk.box(kit, "m", Transform3D(Basis(), Vector3(0, 0.015, 0)), Vector3(0.36, 0.03, 0.36), Color(0.85, 0.32, 0.05))
	pk.lathe(kit, "m", Vector3.ZERO, [Vector2(0.15, 0.03), Vector2(0.105, 0.2)], 14, Color(1.0, 0.42, 0.06))
	pk.lathe(kit, "m", Vector3.ZERO, [Vector2(0.105, 0.2), Vector2(0.075, 0.3)], 14, Color(0.95, 0.95, 0.93))
	pk.lathe(kit, "m", Vector3.ZERO, [Vector2(0.075, 0.3), Vector2(0.03, 0.45), Vector2(0.0, 0.45)], 14, Color(1.0, 0.42, 0.06))


## A truss gantry across the road at `c`, `half` either side of the middle, `h` high, its banner in `col`.
static func gantry(pk: PropKit, kit: Dictionary, c: Vector3, half: float, h: float, col: Color) -> void:
	var alu := Color(0.78, 0.8, 0.82)
	for s in [-1.0, 1.0]:
		var x: float = c.x + s * half
		for dz in [-0.4, 0.4]:
			for dx in [-0.4, 0.4]:
				pk.tube(kit, "m", Vector3(x + dx, 0.0, c.z + dz), Vector3(x + dx, h, c.z + dz), 0.07, 0.07, 8, alu)
		for k in 8:
			var y0 := h * float(k) / 8.0
			var y1 := h * float(k + 1) / 8.0
			pk.tube(kit, "m", Vector3(x - 0.4, y0, c.z + 0.4), Vector3(x + 0.4, y1, c.z + 0.4), 0.03, 0.03, 6, alu, false)
		pk.box(kit, "m", Transform3D(Basis(), Vector3(x, 0.2, c.z)), Vector3(1.4, 0.4, 1.4), Color(0.3, 0.31, 0.33))
	for dy in [h - 0.4, h + 0.4]:
		for dz in [-0.4, 0.4]:
			pk.tube(kit, "m", Vector3(c.x - half, dy, c.z + dz), Vector3(c.x + half, dy, c.z + dz), 0.07, 0.07, 8, alu)
	pk.box(kit, "m", Transform3D(Basis(), Vector3(c.x, h - 1.4, c.z - 0.5)), Vector3(half * 1.6, 1.6, 0.08), col.darkened(0.15))
	pk.box(kit, "m", Transform3D(Basis(), Vector3(c.x, h - 1.4, c.z - 0.55)), Vector3(half * 1.62, 0.18, 0.06), Color(0.95, 0.95, 0.95))


# --- the Options tile's bench (life size) -------------------------------------------------------------

## The whole bench under one node, for a car at the game's prop scale (about 1.4m long: the garage's size) on a
## stand `stand_h` high turned `car_yaw`. Metas: "stand_top" (where the car's origin goes), "wheel" (the
## transmitter's wheel node, turned by `animate_bench`), "ui" (the laptop screen's controls).
const WALL_Z := -1.45
const STAND_AT := Vector3(0.3, 0.0, -0.55)

static func build_bench(accent: Color, stand_h := 0.2, car_yaw := 0.55) -> Node3D:
	var root := Node3D.new()
	root.name = "Bench"
	var pk := PropKit.new()
	pk.material_for = func(k: String) -> Material: return material(k)
	var kit := {}

	# The bench top (walnut-dark) and the mat on it.
	pk.box(kit, "matte", Transform3D(Basis(), Vector3(0.0, -0.025, (WALL_Z + 0.7) * 0.5)), Vector3(14.0, 0.05, 0.7 - WALL_Z), Color(0.16, 0.11, 0.08))
	var mat_mi := MeshInstance3D.new()
	var mat_plane := PlaneMesh.new()
	mat_plane.size = Vector2(2.0, 1.25)
	mat_mi.mesh = mat_plane
	mat_mi.position = Vector3(0.0, 0.0015, -0.25)
	var mat_shader := ShaderMaterial.new()
	mat_shader.shader = preload("res://menu_bench_mat.gdshader")
	mat_shader.set_shader_parameter("line", accent)
	mat_shader.set_shader_parameter("size", mat_plane.size)
	mat_mi.material_override = mat_shader
	root.add_child(mat_mi)

	# The car's stand: an anodised block on a foot under the chassis, a rubber pad on top, so the wheels hang
	# a few centimetres clear of the mat and steer freely.
	var anod := accent.darkened(0.25)
	pk.set_frame(Transform3D(Basis.from_euler(Vector3(0, car_yaw, 0)), STAND_AT))
	pk.box(kit, "metal", Transform3D(Basis(), Vector3(0, 0.012, 0)), Vector3(0.4, 0.024, 0.62), anod)
	pk.box(kit, "metal", Transform3D(Basis(), Vector3(0, stand_h * 0.5, 0)), Vector3(0.22, stand_h - 0.02, 0.4), anod.lightened(0.08))
	pk.box(kit, "rubber", Transform3D(Basis(), Vector3(0, stand_h - 0.008, 0)), Vector3(0.24, 0.016, 0.44), Color(0.05, 0.05, 0.05))
	pk.reset_frame()
	root.set_meta("stand_top", STAND_AT + Vector3(0.0, stand_h, 0.0))

	_workshop_wall(pk, kit, accent)
	_laptop(pk, kit, Transform3D(Basis.from_euler(Vector3(0, -0.42, 0)), Vector3(-0.62, 0.0, -0.12)), root)
	_hex_drivers(pk, kit, Vector3(-0.95, 0.0, -0.3), accent)
	_lipo(pk, kit, Transform3D(Basis.from_euler(Vector3(0, -0.5, 0)), Vector3(-0.3, 0.0, 0.12)))
	pk.reset_frame()

	var mi := MeshInstance3D.new()
	mi.name = "Props"
	mi.mesh = pk.commit(kit)
	root.add_child(mi)

	var tx := _transmitter(accent)
	tx.transform = Transform3D(Basis.from_euler(Vector3(0, -2.2, 0)), Vector3(-0.12, 0.0, 0.06))
	root.add_child(tx)
	root.set_meta("wheel", tx.get_node("Wheel"))
	root.set_meta("trigger", tx.get_node("Trigger"))
	root.set_meta("tx_ui", tx.get_meta("ui"))
	return root


## The wall behind the bench: painted block, a pegboard with tools hung on it, a shelf of spare wheels and a
## strip light along under the shelf.
static func _workshop_wall(pk: PropKit, kit: Dictionary, accent: Color) -> void:
	# Laid out with the wall's face at z -0.595, moved back to WALL_Z.
	pk.set_frame(Transform3D(Basis(), Vector3(0.0, 0.0, WALL_Z + 0.62)))
	pk.box(kit, "matte", Transform3D(Basis(), Vector3(0.0, 1.8, -0.62)), Vector3(14.0, 3.7, 0.05), Color(0.24, 0.25, 0.28))
	var board := Color(0.36, 0.3, 0.22)
	pk.box(kit, "matte", Transform3D(Basis(), Vector3(-0.15, 0.42, -0.585)), Vector3(1.2, 0.7, 0.012), board)
	for i in 30:
		for j in 17:
			pk.box(kit, "matte", Transform3D(Basis(), Vector3(-0.73 + 0.04 * i, 0.1 + 0.04 * j, -0.5785)), Vector3(0.008, 0.008, 0.001), Color(0.12, 0.1, 0.08))
	# Tools on the board: wrenches, pliers, a file, a hammer.
	var steel := Color(0.62, 0.64, 0.68)
	for k in 6:
		var x := -0.62 + 0.045 * k
		var l := 0.12 + 0.02 * k
		pk.box(kit, "metal", Transform3D(Basis(), Vector3(x, 0.6 - l * 0.5, -0.575)), Vector3(0.016, l, 0.006), steel)
		pk.box(kit, "metal", Transform3D(Basis(), Vector3(x, 0.6, -0.575)), Vector3(0.032, 0.028, 0.006), steel)
	for s in [-1.0, 1.0]:
		pk.beam(kit, "metal", Vector3(-0.25 + s * 0.015, 0.62, -0.575), Vector3(-0.25 - s * 0.02, 0.45, -0.575), 0.012, 0.006, steel)
		pk.beam(kit, "rubber", Vector3(-0.25 - s * 0.02, 0.45, -0.574), Vector3(-0.25 - s * 0.03, 0.32, -0.574), 0.016, 0.008, accent.darkened(0.2))
	pk.beam(kit, "matte", Vector3(0.0, 0.62, -0.574), Vector3(0.0, 0.34, -0.574), 0.03, 0.01, Color(0.15, 0.1, 0.06))
	pk.box(kit, "metal", Transform3D(Basis(), Vector3(0.0, 0.62, -0.57)), Vector3(0.1, 0.035, 0.03), Color(0.3, 0.31, 0.33))
	# The shelf above with spare wheels and a tub of parts; a strip light under it.
	pk.box(kit, "matte", Transform3D(Basis(), Vector3(0.2, 0.9, -0.5)), Vector3(1.6, 0.025, 0.24), Color(0.22, 0.16, 0.1))
	for k in 4:
		var c := Vector3(-0.3 + 0.13 * k, 0.913 + 0.055, -0.5)
		pk.tyre(kit, "rubber", c, 0.03, 0.055, 0.045, 24, Color(0.05, 0.05, 0.05), Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)))
		pk.lathe(kit, "metal", c + Vector3(0, 0, 0), [Vector2(0.032, -0.02), Vector2(0.032, 0.02)], 18, Color(0.78, 0.8, 0.83), false,
			Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)))
	pk.box(kit, "gloss", Transform3D(Basis(), Vector3(0.55, 0.96, -0.5)), Vector3(0.22, 0.1, 0.16), accent.darkened(0.3))
	pk.box(kit, "led", Transform3D(Basis(), Vector3(0.2, 0.884, -0.42)), Vector3(1.4, 0.008, 0.02), Color(1.0, 0.93, 0.8))
	# The side wall closing the corner on the right (the camera looks along the bench toward it): a band in the
	# tile's colour, a shelf of spare bodies' wheels and a strip light.
	var side_x := 1.75
	var side_z := 0.615   # where the shelf is centred, in this frame (moved back with the wall)
	pk.box(kit, "matte", Transform3D(Basis(), Vector3(side_x, 1.8, 3.2)), Vector3(0.05, 3.7, 7.2), Color(0.22, 0.23, 0.26))
	pk.box(kit, "gloss", Transform3D(Basis(), Vector3(side_x - 0.03, 0.42, 3.2)), Vector3(0.01, 0.06, 7.2), accent.darkened(0.5))
	# The workshop's floor under the bench, dark concrete.
	pk.box(kit, "matte", Transform3D(Basis(), Vector3(0.0, -0.92, 3.0)), Vector3(14.0, 0.04, 8.0), Color(0.12, 0.125, 0.13))
	pk.box(kit, "matte", Transform3D(Basis(), Vector3(side_x - 0.13, 0.85, side_z - 0.4)), Vector3(0.24, 0.025, 1.2), Color(0.22, 0.16, 0.1))
	for k in 5:
		var c := Vector3(side_x - 0.13, 0.863 + 0.055, side_z - 0.9 + 0.25 * k)
		pk.tyre(kit, "rubber", c, 0.03, 0.055, 0.045, 24, Color(0.05, 0.05, 0.05), Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1)))
	pk.box(kit, "led", Transform3D(Basis(), Vector3(side_x - 0.05, 0.834, side_z - 0.4)), Vector3(0.02, 0.008, 1.1), Color(1.0, 0.93, 0.8))


## A 16-inch laptop at `xf`, its back toward -z, the lid open ~110 degrees; the screen is a live 2D
## settings page (`_settings_page`).
static func _laptop(pk: PropKit, kit: Dictionary, xf: Transform3D, root: Node3D) -> void:
	pk.set_frame(xf)
	var shell := Color(0.18, 0.19, 0.21)
	# A 16-inch machine (16:10 panel): 35.6 x 24.8cm, 1.7cm thick.
	var w := 0.356
	var d := 0.248
	var t := 0.017
	pk.box(kit, "metal", Transform3D(Basis(), Vector3(0, t * 0.5, 0)), Vector3(w, t, d), shell)
	pk.box(kit, "rubber", Transform3D(Basis(), Vector3(0, 0.0015, 0)), Vector3(w - 0.02, 0.003, d - 0.02), Color(0.04, 0.04, 0.04))
	# The keyboard: a well and rows of keys (the last a space bar between modifiers); the trackpad below.
	var well_z := -d * 0.15
	var well_d := d * 0.47
	pk.box(kit, "matte", Transform3D(Basis(), Vector3(0, t + 0.0003, well_z)), Vector3(w * 0.88, 0.0008, well_d), Color(0.06, 0.06, 0.07))
	var kw := w * 0.85 / 14.0
	var pitch := well_d / 6.0
	var key_col := Color(0.11, 0.115, 0.13)
	var rows := [14, 14, 13, 12, 11]
	for r in rows.size():
		var n: int = rows[r]
		var row_w := float(n) * kw
		var z := well_z - well_d * 0.5 + pitch * (float(r) + 0.75)
		for k in n:
			var x := -row_w * 0.5 + kw * (float(k) + 0.5)
			pk.box(kit, "matte", Transform3D(Basis(), Vector3(x, t + 0.0015, z)), Vector3(kw - 0.003, 0.0018, pitch - 0.003), key_col)
	var bottom_z := well_z - well_d * 0.5 + pitch * 5.75
	pk.box(kit, "matte", Transform3D(Basis(), Vector3(0, t + 0.0015, bottom_z)), Vector3(kw * 5.5, 0.0018, pitch - 0.003), key_col)
	for side in [-1.0, 1.0]:
		for k in 3:
			var x: float = side * (kw * 2.75 + kw * (float(k) + 0.5) + 0.002)
			pk.box(kit, "matte", Transform3D(Basis(), Vector3(x, t + 0.0015, bottom_z)), Vector3(kw - 0.003, 0.0018, pitch - 0.003), key_col)
	pk.box(kit, "glass", Transform3D(Basis(), Vector3(0, t + 0.0004, d * 0.31)), Vector3(w * 0.36, 0.0008, d * 0.27), Color(0.24, 0.25, 0.27))
	# The lid, hinged at the back edge.
	var hinge := Vector3(0, t, -d * 0.5)
	var lid := Basis.from_euler(Vector3(-0.32, 0, 0))   # leaning back from upright
	var lid_xf := Transform3D(lid, hinge)
	pk.box(kit, "metal", lid_xf * Transform3D(Basis(), Vector3(0, d * 0.5, -0.004)), Vector3(w, d, 0.007), shell)
	pk.box(kit, "matte", lid_xf * Transform3D(Basis(), Vector3(0, d * 0.5, -0.0002)), Vector3(w - 0.004, d - 0.004, 0.0008), Color(0.02, 0.02, 0.025))
	pk.tube(kit, "metal", hinge + Vector3(-w * 0.42, 0, 0), hinge + Vector3(w * 0.42, 0, 0), 0.006, 0.006, 10, shell.darkened(0.2))
	# The screen: a dark panel with the settings page laid on it in 3D (`_settings_page`). As a SubViewport's
	# texture the page flickered while the tile under the pointer drew every frame (grey, or drawn into a corner).
	var screen := MeshInstance3D.new()
	screen.name = "LaptopScreen"
	var q := QuadMesh.new()
	q.size = Vector2(w - 0.022, (w - 0.022) * 10.0 / 16.0)
	screen.mesh = q
	screen.material_override = _flat(Color(0.055, 0.065, 0.085))
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	screen.transform = xf * lid_xf * Transform3D(Basis(), Vector3(0, d * 0.5 + 0.004, 0.0025))
	root.add_child(screen)
	var page := _settings_page(q.size)
	screen.add_child(page["node"])
	root.set_meta("ui", page)
	pk.reset_frame()


# --- pages drawn on the screens in 3D ------------------------------------------------------------------------
# A page is laid out in design pixels (x right, y down from the top left, as a 2D screen would be) and drawn as
# flat quads, Label3Ds and ribbons a fraction of a millimetre over its screen, `k` metres a pixel. Layers stand
# PAGE_LAYER apart, the text above them all.

const PAGE_LAYER := 0.00035
static var _unit_quad: QuadMesh


## An unshaded flat colour (the pages' panels), cached by colour.
static func _flat(col: Color) -> StandardMaterial3D:
	var key := "flat_" + col.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	_mats[key] = m
	return m


static func _new_page(design: Vector2, screen: Vector2) -> Node3D:
	var page := Node3D.new()
	page.name = "Page"
	page.set_meta("k", screen.x / design.x)
	page.set_meta("design", design)
	return page


## A rectangle of the page at (x, y), w x h design pixels, on `layer`.
static func _page_rect(page: Node3D, x: float, y: float, w: float, h: float, col: Color, layer: int) -> MeshInstance3D:
	if _unit_quad == null:
		_unit_quad = QuadMesh.new()
		_unit_quad.size = Vector2.ONE
	var mi := MeshInstance3D.new()
	mi.mesh = _unit_quad
	mi.material_override = _flat(col)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("layer", layer)
	page.add_child(mi)
	_set_page_rect(page, mi, x, y, w, h)
	return mi


static func _set_page_rect(page: Node3D, mi: MeshInstance3D, x: float, y: float, w: float, h: float) -> void:
	var k: float = page.get_meta("k")
	var design: Vector2 = page.get_meta("design")
	mi.scale = Vector3(maxf(w, 0.01) * k, maxf(h, 0.01) * k, 1.0)
	mi.position = Vector3((x + w * 0.5 - design.x * 0.5) * k, (design.y * 0.5 - y - h * 0.5) * k,
		float(mi.get_meta("layer")) * PAGE_LAYER)


## Text with its top left at (x, y), `size` design pixels tall.
static func _page_label(page: Node3D, text: String, x: float, y: float, size: int, col: Color) -> Label3D:
	var k: float = page.get_meta("k")
	var design: Vector2 = page.get_meta("design")
	var l := Label3D.new()
	l.text = text
	l.font_size = size * 4
	l.pixel_size = k / 4.0
	l.outline_size = 0
	l.modulate = col
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.double_sided = false
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	l.position = Vector3((x - design.x * 0.5) * k, (design.y * 0.5 - y) * k, 5.0 * PAGE_LAYER)
	page.add_child(l)
	return l


## A line through design-pixel points, `width` pixels wide, as a ribbon on the page (redrawn by `_draw_line`).
static func _page_line(page: Node3D, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = ImmediateMesh.new()
	mi.material_override = _flat(col)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	page.add_child(mi)
	return mi


static func _draw_line(page: Node3D, mi: MeshInstance3D, points: PackedVector2Array, width: float) -> void:
	var k: float = page.get_meta("k")
	var design: Vector2 = page.get_meta("design")
	var im := mi.mesh as ImmediateMesh
	im.clear_surfaces()
	if points.size() < 2:
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in points.size():
		var a := points[maxi(i - 1, 0)]
		var b := points[mini(i + 1, points.size() - 1)]
		var dir := (b - a).normalized()
		var n := Vector2(-dir.y, dir.x) * width * 0.5
		for sgn in [1.0, -1.0]:
			var p: Vector2 = points[i] + n * sgn
			im.surface_set_normal(Vector3(0, 0, 1))
			im.surface_add_vertex(Vector3((p.x - design.x * 0.5) * k, (design.y * 0.5 - p.y) * k, 4.0 * PAGE_LAYER))
	im.surface_end()


## The laptop's page: a dark settings app on the car's set-up, its sliders and a live telemetry trace, laid out at
## 800 x 500. The moving parts are in the returned dictionary for `animate_bench`.
static func _settings_page(screen: Vector2) -> Dictionary:
	var page := _new_page(Vector2(800, 500), screen)
	_page_rect(page, 0, 0, 200, 500, Color(0.085, 0.1, 0.13), 1)
	var teal := Color(0.18, 0.8, 0.7)
	var items := ["GRAPHICS", "AUDIO", "CONTROLS", "CAR SETUP", "TELEMETRY"]
	for i in items.size():
		var y := 70.0 + float(i) * 52.0
		if i == 3:
			_page_rect(page, 0, y - 8, 200, 44, Color(0.12, 0.3, 0.3), 2)
			_page_rect(page, 0, y - 8, 5, 44, teal, 3)
		_page_label(page, items[i], 26, y, 22, Color(0.92, 0.95, 0.97) if i == 3 else Color(0.55, 0.6, 0.68))
	_page_label(page, "RC VIBE  SETUP", 26, 18, 18, teal)
	_page_label(page, "MUDRUNNER  •  #53", 232, 22, 30, Color(0.95, 0.97, 1.0))
	var sliders: Array = []
	var names := ["STEERING RATE", "THROTTLE EXPO", "BRAKE BIAS", "DIFF LOCK"]
	for i in names.size():
		var y := 92.0 + float(i) * 56.0
		_page_label(page, names[i], 232, y, 17, Color(0.62, 0.68, 0.76))
		_page_rect(page, 232, y + 30, 420, 6, Color(0.16, 0.18, 0.23), 1)
		var fill := _page_rect(page, 232, y + 30, 200, 6, teal if i != 2 else Color(1.0, 0.55, 0.16), 2)
		var knob := _page_rect(page, 425, y + 23, 14, 20, Color(0.95, 0.97, 1.0), 3)
		var val := _page_label(page, "50%", 672, y + 20, 17, Color(0.92, 0.95, 0.97))
		sliders.append({"fill": fill, "knob": knob, "value": val, "x": 232.0, "w": 420.0, "y": y + 30.0})
	# Telemetry: steering (teal) and throttle (orange) over the last few seconds.
	_page_rect(page, 232, 330, 540, 150, Color(0.07, 0.085, 0.11), 1)
	for g in 4:
		_page_rect(page, 232, 330 + 30 * (g + 1), 540, 1.5, Color(0.13, 0.15, 0.19), 2)
	var steer_line := _page_line(page, teal)
	var throttle_line := _page_line(page, Color(1.0, 0.55, 0.16))
	_page_label(page, "TELEMETRY  •  LIVE", 244, 336, 15, Color(0.55, 0.6, 0.68))
	return {"node": page, "sliders": sliders, "steer": steer_line, "throttle": throttle_line,
		"graph": Rect2(232, 330, 540, 150)}


## Three hex drivers in a holder block: aluminium handles in the tile's colour, steel tips.
static func _hex_drivers(pk: PropKit, kit: Dictionary, c: Vector3, accent: Color) -> void:
	pk.set_frame(Transform3D(Basis.from_euler(Vector3(0, -0.3, 0)), c))
	pk.box(kit, "matte", Transform3D(Basis(), Vector3(0, 0.012, 0)), Vector3(0.11, 0.024, 0.035), Color(0.08, 0.08, 0.09))
	for i in 3:
		var x := -0.035 + 0.035 * float(i)
		var col: Color = [accent, Color(0.85, 0.15, 0.12), Color(0.75, 0.77, 0.8)][i]
		pk.tube(kit, "metal", Vector3(x, 0.024, 0), Vector3(x, 0.03, 0), 0.0035, 0.0035, 8, Color(0.6, 0.62, 0.65))
		pk.tube(kit, "metal", Vector3(x, 0.03, 0), Vector3(x, 0.12, 0), 0.0075, 0.0075, 14, col)
		pk.tube(kit, "rubber", Vector3(x, 0.07, 0), Vector3(x, 0.105, 0), 0.0082, 0.0082, 14, Color(0.06, 0.06, 0.06), false)
	pk.reset_frame()


## A hard-case LiPo pack with its leads.
static func _lipo(pk: PropKit, kit: Dictionary, xf: Transform3D) -> void:
	pk.set_frame(xf)
	pk.box(kit, "gloss", Transform3D(Basis(), Vector3(0, 0.0125, 0)), Vector3(0.138, 0.025, 0.047), Color(0.06, 0.06, 0.07))
	pk.box(kit, "gloss", Transform3D(Basis(), Vector3(0, 0.0252, 0)), Vector3(0.1, 0.0006, 0.03), Color(0.9, 0.75, 0.15))
	pk.box(kit, "matte", Transform3D(Basis(), Vector3(-0.012, 0.0256, 0)), Vector3(0.04, 0.0004, 0.018), Color(0.08, 0.08, 0.09))
	for s in [-1.0, 1.0]:
		pk.tube(kit, "rubber", Vector3(0.069, 0.012, s * 0.008), Vector3(0.11, 0.004, s * 0.012 + 0.01), 0.0028, 0.0028, 6,
			Color(0.75, 0.08, 0.06) if s > 0.0 else Color(0.05, 0.05, 0.05))
	pk.box(kit, "matte", Transform3D(Basis(), Vector3(0.118, 0.006, 0.01)), Vector3(0.018, 0.012, 0.02), Color(0.9, 0.75, 0.15))
	pk.reset_frame()


## A pro pistol-grip transmitter standing on its grip, its front toward -z, the wheel on its right (+x):
## graphite body with an accent band, rubber grip, chrome trigger, a foam wheel on an alloy hub, a colour
## touchscreen tilted back at the top, trim switches, the antenna stub. "Wheel" and "Trigger" are nodes of
## their own; "ui" (meta) the screen's bars.
static func _transmitter(accent: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Transmitter"
	var pk := PropKit.new()
	pk.material_for = func(k: String) -> Material: return material(k)
	var kit := {}
	var graphite := Color(0.13, 0.135, 0.15)
	var rubber := Color(0.05, 0.05, 0.055)
	var hw := 0.028   # half width of the body
	# Side profiles in (z, y), extruded across x through a frame that turns the outline's x into z.
	var side_frame := Transform3D(Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(1, 0, 0)), Vector3.ZERO)
	pk.set_frame(side_frame)
	# The grip: a slanted bar from the base up into the body.
	var grip := PackedVector2Array([Vector2(0.018, 0.0), Vector2(0.062, 0.0), Vector2(0.07, 0.03), Vector2(0.066, 0.13),
		Vector2(0.03, 0.13), Vector2(0.012, 0.06)])
	pk.extrude(kit, "rubber", grip, -0.021, 0.021, 0.006, rubber)
	# A flared foot so it stands.
	var foot := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.085, 0.0), Vector2(0.08, 0.012), Vector2(0.006, 0.012)])
	pk.extrude(kit, "matte", foot, -0.03, 0.03, 0.004, graphite)
	# The body: a long rounded head over the grip, nose forward (-z) for the wheel's mount.
	var body := PackedVector2Array([Vector2(-0.085, 0.125), Vector2(0.0, 0.118), Vector2(0.09, 0.122), Vector2(0.105, 0.16),
		Vector2(0.098, 0.2), Vector2(0.05, 0.215), Vector2(-0.04, 0.205), Vector2(-0.092, 0.175), Vector2(-0.098, 0.145)])
	pk.extrude(kit, "gloss", body, -hw, hw, 0.009, graphite)
	# The accent band round its waist.
	var band := PackedVector2Array([Vector2(-0.092, 0.152), Vector2(0.1, 0.152), Vector2(0.1, 0.162), Vector2(-0.094, 0.162)])
	pk.extrude(kit, "gloss", band, -hw - 0.0012, hw + 0.0012, 0.0, accent)
	pk.reset_frame()
	# The touchscreen in a bezel at the top back, tilted toward the driver (+z).
	var tilt := Basis.from_euler(Vector3(-0.85, 0, 0))
	var scr_c := Vector3(0.0, 0.214, 0.05)
	pk.box(kit, "matte", Transform3D(tilt, scr_c), Vector3(0.05, 0.066, 0.008), rubber)
	# The wheel's mount: a boss on the right side of the nose.
	var hub_c := Vector3(hw + 0.006, 0.168, -0.055)
	var side_axis := Basis(Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1))
	pk.lathe(kit, "metal", Vector3(hw - 0.002, 0.168, -0.055), [Vector2(0.016, 0.0), Vector2(0.016, 0.01), Vector2(0.0, 0.01)], 18,
		Color(0.4, 0.42, 0.45), false, side_axis)
	# Switches and buttons on top: trims, aux buttons in the accent colour, the power slider.
	for i in 3:
		pk.box(kit, "matte", Transform3D(Basis(), Vector3(-0.012 + 0.012 * float(i), 0.207, -0.045)), Vector3(0.007, 0.004, 0.012), Color(0.25, 0.26, 0.28))
	for i in 2:
		pk.lathe(kit, "gloss", Vector3(-0.012 + 0.024 * float(i), 0.206, -0.02), [Vector2(0.0045, 0.0), Vector2(0.0045, 0.004), Vector2(0.0, 0.0045)], 12, accent)
	pk.box(kit, "metal", Transform3D(Basis(), Vector3(-hw - 0.0015, 0.185, 0.02)), Vector3(0.003, 0.008, 0.02), Color(0.7, 0.72, 0.75))
	# The antenna stub at the top back.
	pk.tube(kit, "rubber", Vector3(0.0, 0.205, 0.088), Vector3(0.0, 0.29, 0.1), 0.0055, 0.0045, 10, rubber)
	pk.lathe(kit, "rubber", Vector3(0.0, 0.2, 0.087), [Vector2(0.009, 0.0), Vector2(0.008, 0.012), Vector2(0.0055, 0.016)], 12, rubber)
	var mi := MeshInstance3D.new()
	mi.name = "Shell"
	mi.mesh = pk.commit(kit)
	root.add_child(mi)

	# The wheel: a foam tyre on a five-spoke alloy hub, turning about x.
	var wpk := PropKit.new()
	wpk.material_for = func(k: String) -> Material: return material(k)
	var wkit := {}
	wpk.tyre(wkit, "rubber", Vector3.ZERO, 0.033, 0.048, 0.022, 32, Color(0.07, 0.07, 0.075), side_axis)
	wpk.lathe(wkit, "metal", Vector3(-0.009, 0, 0), [Vector2(0.034, 0.0), Vector2(0.034, 0.016), Vector2(0.0, 0.018)], 28,
		Color(0.72, 0.74, 0.77), false, side_axis)
	for k in 5:
		var a := TAU * float(k) / 5.0
		var dir := Vector3(0, cos(a), sin(a))
		wpk.beam(wkit, "metal", Vector3(0.008, 0, 0) + dir * 0.008, Vector3(0.008, 0, 0) + dir * 0.032, 0.007, 0.004, Color(0.8, 0.82, 0.85), Vector3(1, 0, 0))
	wpk.lathe(wkit, "gloss", Vector3(0.011, 0, 0), [Vector2(0.008, 0.0), Vector2(0.007, 0.004), Vector2(0.0, 0.005)], 14, accent, false, side_axis)
	var wheel := MeshInstance3D.new()
	wheel.name = "Wheel"
	wheel.mesh = wpk.commit(wkit)
	wheel.position = hub_c + Vector3(0.008, 0, 0)
	root.add_child(wheel)

	# The trigger: a curved chrome paddle in front of the grip, pivoting about x.
	var tpk := PropKit.new()
	tpk.material_for = func(k: String) -> Material: return material(k)
	var tkit := {}
	tpk.set_frame(side_frame)
	var paddle := PackedVector2Array([Vector2(-0.004, 0.0), Vector2(0.004, 0.0), Vector2(-0.006, -0.035), Vector2(-0.012, -0.05),
		Vector2(-0.02, -0.052), Vector2(-0.014, -0.034)])
	tpk.extrude(tkit, "metal", paddle, -0.007, 0.007, 0.002, Color(0.78, 0.8, 0.83))
	var trigger := MeshInstance3D.new()
	trigger.name = "Trigger"
	trigger.mesh = tpk.commit(tkit)
	trigger.position = Vector3(0.0, 0.122, 0.006)
	root.add_child(trigger)

	# The screen: a small live page laid on it in 3D (signal, battery, the steering and throttle bars).
	var screen := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.042, 0.056)
	screen.mesh = q
	screen.material_override = _flat(Color(0.05, 0.07, 0.1))
	screen.transform = Transform3D(tilt, scr_c + tilt * Vector3(0, 0, 0.0058))
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(screen)
	var page := _tx_page(accent, q.size)
	screen.add_child(page["node"])
	root.set_meta("ui", page)
	return root


static func _tx_page(accent: Color, screen: Vector2) -> Dictionary:
	var page := _new_page(Vector2(180, 240), screen)
	_page_rect(page, 0, 0, 180, 34, accent.darkened(0.35), 1)
	_page_label(page, "MUDRUNNER", 10, 6, 18, Color.WHITE)
	var bars: Array = []
	var labels := ["ST", "TH"]
	for i in 2:
		var y := 70.0 + float(i) * 62.0
		_page_label(page, labels[i], 10, y - 4, 16, Color(0.6, 0.66, 0.74))
		_page_rect(page, 44, y, 122, 14, Color(0.15, 0.17, 0.22), 1)
		_page_rect(page, 104, y - 3, 2, 20, Color(0.4, 0.44, 0.5), 3)
		bars.append({"fill": _page_rect(page, 105, y, 1, 14, accent if i == 0 else Color(1.0, 0.55, 0.16), 2), "y": y})
	_page_label(page, "7.4V  82%", 10, 196, 16, Color(0.4, 0.95, 0.5))
	return {"node": page, "bars": bars}


## Moves the bench at `t`: the transmitter's wheel turned by `steer` (-1..1), the trigger squeezed and
## eased, the laptop's sliders easing between settings and the telemetry trace running.
static func animate_bench(bench: Node3D, t: float, steer: float) -> void:
	var throttle := 0.5 + 0.5 * sin(t * 0.7 + 1.0)
	var wheel: Node3D = bench.get_meta("wheel")
	wheel.rotation = Vector3(steer * 1.1, 0, 0)
	var trig: Node3D = bench.get_meta("trigger")
	trig.rotation = Vector3(-throttle * 0.28, 0, 0)
	var tx_ui: Dictionary = bench.get_meta("tx_ui")
	var tx_page: Node3D = tx_ui["node"]
	for i in 2:
		var v := steer if i == 0 else throttle * 2.0 - 1.0
		var bar: Dictionary = tx_ui["bars"][i]
		var len := absf(v) * 60.0
		_set_page_rect(tx_page, bar["fill"], 105.0 if v >= 0.0 else 105.0 - len, bar["y"], maxf(len, 1.0), 14.0)
	var ui: Dictionary = bench.get_meta("ui")
	var page: Node3D = ui["node"]
	var sliders: Array = ui["sliders"]
	for i in sliders.size():
		var sd: Dictionary = sliders[i]
		var v := 0.5 + 0.32 * sin(t * (0.21 + 0.07 * float(i)) + float(i) * 1.9)
		_set_page_rect(page, sd["fill"], sd["x"], sd["y"], float(sd["w"]) * v, 6.0)
		_set_page_rect(page, sd["knob"], float(sd["x"]) + float(sd["w"]) * v - 7.0, float(sd["y"]) - 7.0, 14.0, 20.0)
		(sd["value"] as Label3D).text = "%d%%" % roundi(v * 100.0)
	var r: Rect2 = ui["graph"]
	var steer_pts := PackedVector2Array()
	var thr_pts := PackedVector2Array()
	for k in 61:
		var u := float(k) / 60.0
		var tt := t - (1.0 - u) * 6.0
		var st := sin(tt * 0.9) * 0.45 + sin(tt * 2.3) * 0.08
		var th := 0.5 + 0.5 * sin(tt * 0.7 + 1.0)
		var x := r.position.x + u * r.size.x
		steer_pts.append(Vector2(x, r.position.y + r.size.y * (0.5 - st * 0.8)))
		thr_pts.append(Vector2(x, r.position.y + r.size.y * (0.92 - th * 0.75)))
	_draw_line(page, ui["steer"], steer_pts, 3.5)
	_draw_line(page, ui["throttle"], thr_pts, 3.5)
