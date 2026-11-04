extends "res://YardKit.gd"
## Harbor Pier's port (regenerate_harbor_pier.gd): Bloombay's harbour built through a PropKit at life size, grown by
## the caller (PROP_SCALE, 1.6, like Bloombay's seafront and the Lakeside paddock). YardKit's helpers and materials
## (brick, concrete, slate and corrugated iron in the hut shaders, the vertex-colour steel, glass and lamps) and a few
## of the port's own keys: "container" (shipping_container.gdshader: corrugation, doors, lettering and rust from UVs in
## metres), "quay" and "pile" (harbor_quay.gdshader, the quays' concrete with the tide line), "rubber".
##
## Frames: a prop's origin is the middle of its foot on the ground (or the deck), y up; a building's front faces +z.

const HarborQuay = preload("res://harbor_quay.gdshader")
const CampKit = preload("res://CampKit.gd")

## A container's outside (x along, y up, z across): ISO 20ft and 40ft.
const BOX_20 := Vector3(6.06, 2.59, 2.44)
const BOX_40 := Vector3(12.19, 2.59, 2.44)
## The boxes' paints: the lines' colours (made up), faded a little.
const BOX_PAINTS := [Color(0.16, 0.36, 0.62), Color(0.62, 0.16, 0.13), Color(0.80, 0.42, 0.12), Color(0.18, 0.46, 0.30),
		Color(0.84, 0.70, 0.20), Color(0.86, 0.86, 0.84), Color(0.42, 0.44, 0.46), Color(0.48, 0.24, 0.40),
		Color(0.12, 0.42, 0.50), Color(0.55, 0.32, 0.20), Color(0.20, 0.24, 0.32), Color(0.66, 0.22, 0.20)]

const BRICK_RED := Color(0.56, 0.28, 0.20)
const BRICK_DARK := Color(0.42, 0.22, 0.17)
const SANDSTONE := Color(0.80, 0.72, 0.58)
const IRON_GREY := Color(0.52, 0.54, 0.55)
const PAINT_GREEN := Color(0.16, 0.32, 0.26)
const BOLLARD_BLACK := Color(0.09, 0.09, 0.10)
const SAFETY_YELLOW := Color(0.92, 0.70, 0.10)

static var _port_mats := {}


static func port_material(key: String) -> Material:
	match key:
		"container":
			var m := ShaderMaterial.new()
			m.shader = load("res://shipping_container.gdshader")
			return m
		"quay", "pile":
			var q := ShaderMaterial.new()
			q.shader = HarborQuay
			q.set_shader_parameter("mode", 0 if key == "quay" else 1)
			q.set_shader_parameter("concrete_tex", load("res://materials/concrete.png"))
			q.set_shader_parameter("concrete_nrm", load("res://materials/concrete_normal.png"))
			return q
		"rubber":
			var r := CampKit.make_material("rubber")
			return r
		"stonetrim", "slatetrim", "copper":
			# The cathedral's mouldings, tracery and copper (no UVs): plain vertex colour.
			var t := CampKit.make_material("matte")
			t.roughness = 0.6 if key == "copper" else 0.9
			t.metallic = 0.2 if key == "copper" else 0.0
			return t
		"hull":
			var h := CampKit.make_material("gloss")
			h.roughness = 0.45
			h.metallic = 0.1
			return h
	return make_material(key)


## A kit whose materials are the port's (shared through `_port_mats`; the generator saves them).
static func new_port_kit(scale: float) -> PropKit:
	var pk := PropKit.new()
	pk.material_for = func(k: String) -> Material:
		if not _port_mats.has(k):
			_port_mats[k] = port_material(k)
		return _port_mats[k]
	pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * scale), Vector3.ZERO))
	uvk = scale
	return pk


## Commits a kit with tangents where a shader reads a normal map (the containers' corrugation too).
static func commit_port(pk: PropKit, kit: Dictionary) -> ArrayMesh:
	for key in TANGENT_KEYS + ["container"]:
		if kit.has(key):
			var st: SurfaceTool = kit[key]
			st.index()
			st.generate_tangents()
	return pk.commit(kit)


# ======================================================================================
#  Containers
# ======================================================================================

## A container standing on `c` (the middle of its floor), turned `yaw` about y, `size` BOX_20 or BOX_40, painted
## `col`; `seed` (0..1) varies its wear and lettering. The walls are flat quads that the shader corrugates (UV.x
## carries the face: 100 times its id plus the metres across it); the corner posts, rails and castings stand proud, and
## the door end has its four locking bars. `simple` leaves the small parts out (far stacks, the ship's deck load).
static func container(pk: PropKit, kit: Dictionary, c: Vector3, yaw: float, size: Vector3, col: Color, seed_v: float, simple := false) -> void:
	var b := Basis(Vector3.UP, yaw)
	var hl := size.x * 0.5
	var hw := size.z * 0.5
	var h := size.y
	var ax: Vector3 = b * Vector3.RIGHT
	var az: Vector3 = b * Vector3.BACK
	var paint := Color(col.r, col.g, col.b, seed_v)
	var frame := col.darkened(0.25)
	var inset := 0.04
	var P := func(x: float, y: float, z: float) -> Vector3:
		return c + ax * x + Vector3(0, y, 0) + az * z
	# Side walls (face 0): u along the box.
	for sz in [-1.0, 1.0]:
		var z: float = sz * (hw - inset)
		var pts := [P.call(-hl, 0.0, z), P.call(hl, 0.0, z), P.call(hl, h, z), P.call(-hl, h, z)]
		pk.quad(kit, "container", pts, az * sz, paint, [Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, h), Vector2(0, h)])
	# The door end (+x, face 1) and the closed end (-x, face 2): u across the box.
	for sx in [-1.0, 1.0]:
		var x: float = sx * (hl - inset)
		var f: float = 100.0 if sx > 0.0 else 200.0
		var pts2 := [P.call(x, 0.0, -hw), P.call(x, 0.0, hw), P.call(x, h, hw), P.call(x, h, -hw)]
		pk.quad(kit, "container", pts2, ax * sx, paint, [Vector2(f, 0), Vector2(f + size.z, 0), Vector2(f + size.z, h), Vector2(f, h)])
	# Roof (face 3).
	var roof := [P.call(-hl, h - 0.02, -hw), P.call(hl, h - 0.02, -hw), P.call(hl, h - 0.02, hw), P.call(-hl, h - 0.02, hw)]
	pk.quad(kit, "container", roof, Vector3.UP, paint, [Vector2(300, 0), Vector2(300 + size.x, 0), Vector2(300 + size.x, size.z), Vector2(300, size.z)])
	# Top and bottom side rails, end rails (far boxes keep only the top rails).
	var bb := Basis(ax, Vector3.UP, az)
	for sz2 in [-1.0, 1.0]:
		pk.box(kit, "steel", Transform3D(bb, P.call(0.0, h - 0.08, sz2 * (hw - 0.05))), Vector3(size.x - 0.02, 0.16, 0.1), frame)
	if simple:
		return
	for sz2 in [-1.0, 1.0]:
		pk.box(kit, "steel", Transform3D(bb, P.call(0.0, 0.09, sz2 * (hw - 0.05))), Vector3(size.x - 0.02, 0.18, 0.1), frame.darkened(0.2))
	for sx2 in [-1.0, 1.0]:
		pk.box(kit, "steel", Transform3D(bb, P.call(sx2 * (hl - 0.05), h - 0.1, 0.0)), Vector3(0.1, 0.2, size.z - 0.02), frame)
		pk.box(kit, "steel", Transform3D(bb, P.call(sx2 * (hl - 0.05), 0.1, 0.0)), Vector3(0.1, 0.2, size.z - 0.02), frame.darkened(0.2))
	# Corner posts and castings.
	for sx3 in [-1.0, 1.0]:
		for sz3 in [-1.0, 1.0]:
			pk.box(kit, "steel", Transform3D(bb, P.call(sx3 * (hl - 0.08), h * 0.5, sz3 * (hw - 0.08))), Vector3(0.16, h - 0.3, 0.16), frame)
			for y in [0.09, h - 0.09]:
				pk.box(kit, "steel", Transform3D(bb, P.call(sx3 * (hl - 0.09), y, sz3 * (hw - 0.09))), Vector3(0.19, 0.18, 0.19), frame.darkened(0.35))
	# The doors' locking bars: four rods with handles, keepers top and bottom.
	var xd: float = hl - inset + 0.04
	for k in range(4):
		var zz: float = [-0.85, -0.42, 0.42, 0.85][k] * hw
		var a: Vector3 = P.call(xd, 0.25, zz)
		var t: Vector3 = P.call(xd, h - 0.25, zz)
		pk.tube(kit, "steel", a, t, 0.025, 0.025, 6, frame.darkened(0.1), false)
		pk.beam(kit, "steel", P.call(xd + 0.03, 1.1, zz), P.call(xd + 0.03, 1.1, zz + (0.28 if k % 2 == 0 else -0.28)), 0.04, 0.03, frame.darkened(0.1))
		for y2 in [0.28, h - 0.28]:
			pk.box(kit, "steel", Transform3D(bb, P.call(xd, y2, zz)), Vector3(0.06, 0.08, 0.1), frame.darkened(0.3))


## A stack of boxes on a row: `n_x` along x by `n_z` across, `levels` high (each column's own height, 1..levels),
## starting at `c` (the middle of the row's first box's floor), turned `yaw`. 40ft boxes unless `twenty`. The random
## stream picks the paints and the gaps. Returns the footprint corners' extent (x, z) for a collider.
static func stack(pk: PropKit, kit: Dictionary, rng: RandomNumberGenerator, c: Vector3, yaw: float, n_x: int, n_z: int, levels: int,
		twenty := false, simple := false, full := 0.75) -> Vector2:
	var size: Vector3 = BOX_20 if twenty else BOX_40
	var b := Basis(Vector3.UP, yaw)
	var gap_x := 0.4
	var gap_z := 0.25
	for i in range(n_x):
		for j in range(n_z):
			var tall: int = levels if rng.randf() < full else rng.randi_range(1, levels)
			for l in range(tall):
				var p: Vector3 = c + b * Vector3(float(i) * (size.x + gap_x), float(l) * size.y, float(j) * (size.z + gap_z))
				# A box above sits a little off the one under it, as stacked by a crane.
				var wobble := Vector3(rng.randf_range(-0.04, 0.04), 0.0, rng.randf_range(-0.03, 0.03)) if l > 0 else Vector3.ZERO
				var col: Color = BOX_PAINTS[rng.randi() % BOX_PAINTS.size()]
				container(pk, kit, p + b * wobble, yaw + rng.randf_range(-0.004, 0.004), size, col, rng.randf(), simple)
	return Vector2(n_x * (size.x + gap_x) - gap_x, n_z * (size.z + gap_z) - gap_z)


# ======================================================================================
#  Quay furniture
# ======================================================================================

## A cast-iron mooring bollard (a squat post with a flared head), painted black, `col` to override.
static func bollard(pk: PropKit, kit: Dictionary, p: Vector3, col := BOLLARD_BLACK) -> void:
	pk.lathe(kit, "steel", p, [Vector2(0.001, 0.0), Vector2(0.27, 0.0), Vector2(0.27, 0.05), Vector2(0.2, 0.08), Vector2(0.17, 0.2),
			Vector2(0.16, 0.42), Vector2(0.24, 0.5), Vector2(0.25, 0.56), Vector2(0.18, 0.6), Vector2(0.001, 0.62)], 14, col)
	# Four bolts round the base plate.
	for k in 4:
		var a: float = TAU * (float(k) + 0.5) / 4.0
		pk.lathe(kit, "steel", p + Vector3(cos(a) * 0.23, 0.04, sin(a) * 0.23), [Vector2(0.001, 0.0), Vector2(0.03, 0.0), Vector2(0.03, 0.03), Vector2(0.001, 0.035)], 6, col.darkened(0.2))


## A rubber D-fender hung on a quay wall: `top` the middle of its top on the wall's face, `out` the face's normal.
static func wall_fender(pk: PropKit, kit: Dictionary, top: Vector3, out: Vector3, length := 1.6) -> void:
	var across: Vector3 = out.cross(Vector3.UP).normalized()
	var b := Basis(across, Vector3.UP, out)
	pk.box(kit, "rubber", Transform3D(b, top + Vector3(0, -length * 0.5, 0) + out * 0.12), Vector3(0.34, length, 0.24), Color(0.07, 0.07, 0.075))
	pk.box(kit, "rubber", Transform3D(b, top + Vector3(0, -length * 0.5, 0) + out * 0.255), Vector3(0.22, length - 0.06, 0.04), Color(0.09, 0.09, 0.095))
	for y in [-0.12, -length + 0.12]:
		pk.box(kit, "steel", Transform3D(b, top + Vector3(0, y, 0) + out * 0.04), Vector3(0.46, 0.1, 0.08), Color(0.25, 0.22, 0.2))


## A quay ladder: two rails and rungs from `top` (on the coping's edge) down the wall into the water, `out` the wall's
## normal, with grab hoops over the coping.
static func quay_ladder(pk: PropKit, kit: Dictionary, top: Vector3, out: Vector3, down := 2.6) -> void:
	var across: Vector3 = out.cross(Vector3.UP).normalized()
	var col := Color(0.86, 0.66, 0.12)
	for sx in [-1.0, 1.0]:
		var o: Vector3 = across * (sx * 0.22)
		pk.beam(kit, "steel", top + o + out * 0.12 + Vector3(0, -down, 0), top + o + out * 0.12, 0.05, 0.05, col)
		# The hoop over the edge, onto the deck.
		pk.beam(kit, "steel", top + o + out * 0.12, top + o + out * 0.12 + Vector3(0, 0.9, 0), 0.05, 0.05, col)
		pk.beam(kit, "steel", top + o + out * 0.12 + Vector3(0, 0.9, 0), top + o - out * 0.35 + Vector3(0, 0.9, 0), 0.05, 0.05, col)
		pk.beam(kit, "steel", top + o - out * 0.35 + Vector3(0, 0.9, 0), top + o - out * 0.35, 0.05, 0.05, col)
	var y := -down + 0.2
	while y < -0.1:
		pk.beam(kit, "steel", top + across * -0.22 + out * 0.16 + Vector3(0, y, 0), top + across * 0.22 + out * 0.16 + Vector3(0, y, 0), 0.035, 0.035, col)
		y += 0.3


## A harbour floodlight mast: a tapered galvanised pole on a plinth, a cross-arm with two floodlights aimed down,
## a ladder of steps up one side. `aim` is the way the lights look (horizontal).
static func light_mast(pk: PropKit, kit: Dictionary, p: Vector3, aim: Vector3, height := 9.0) -> void:
	var galv := Color(0.62, 0.64, 0.65)
	pk.block(kit, "concrete", p + Vector3(-0.35, 0.0, -0.35), p + Vector3(0.35, 0.3, 0.35), Color(0.7, 0.69, 0.66), uvk)
	pk.lathe(kit, "steel", p + Vector3(0, 0.3, 0), [Vector2(0.001, 0.0), Vector2(0.24, 0.0), Vector2(0.24, 0.04), Vector2(0.14, 0.06), Vector2(0.001, 0.06)], 10, galv.darkened(0.2))
	pk.tube(kit, "steel", p + Vector3(0, 0.33, 0), p + Vector3(0, height, 0), 0.12, 0.07, 10, galv, true)
	var across: Vector3 = aim.cross(Vector3.UP).normalized()
	var top: Vector3 = p + Vector3(0, height - 0.1, 0)
	pk.beam(kit, "steel", top - across * 0.75, top + across * 0.75, 0.08, 0.08, galv.darkened(0.1), Vector3.UP)
	for sx in [-1.0, 1.0]:
		var hp: Vector3 = top + across * (sx * 0.62) + aim * 0.15 + Vector3(0, -0.15, 0)
		var hb := Basis(across, Vector3.UP, aim).rotated(across, deg_to_rad(28.0))
		pk.box(kit, "steel", Transform3D(hb, hp), Vector3(0.5, 0.36, 0.16), Color(0.2, 0.21, 0.22))
		pk.box(kit, "lamp", Transform3D(hb, hp + hb * Vector3(0, 0, 0.085)), Vector3(0.42, 0.28, 0.02), Color(1.0, 0.95, 0.82))
	# Step pegs up the pole.
	var y := 2.4
	while y < height - 0.6:
		var side: Vector3 = across if int(y / 0.4) % 2 == 0 else -across
		var r: float = lerpf(0.12, 0.07, y / height)
		pk.beam(kit, "steel", p + Vector3(0, y, 0) + side * r, p + Vector3(0, y, 0) + side * (r + 0.2), 0.025, 0.025, galv.darkened(0.15))
		y += 0.4


## A lifebuoy on a post with its box: `out` the way it faces.
static func lifebuoy_stand(pk: PropKit, kit: Dictionary, p: Vector3, out: Vector3) -> void:
	var across: Vector3 = out.cross(Vector3.UP).normalized()
	var b := Basis(across, Vector3.UP, out)
	pk.box(kit, "timber", Transform3D(b, p + Vector3(0, 0.75, 0)), Vector3(0.1, 1.5, 0.1), Color(0.86, 0.84, 0.8))
	pk.box(kit, "painted", Transform3D(b, p + Vector3(0, 1.32, 0.07)), Vector3(0.82, 0.62, 0.04), Color(0.86, 0.84, 0.80))
	# The ring, red and white quarters.
	var ring_c: Vector3 = p + Vector3(0, 1.3, 0) + out * 0.13
	for q in range(8):
		var a0: float = TAU * float(q) / 8.0
		var a1: float = TAU * float(q + 1) / 8.0
		var col := Color(0.85, 0.16, 0.10) if q % 2 == 0 else Color(0.95, 0.94, 0.9)
		var d0: Vector3 = across * cos(a0) + Vector3.UP * sin(a0)
		var d1: Vector3 = across * cos(a1) + Vector3.UP * sin(a1)
		pk.tube(kit, "plastic", ring_c + d0 * 0.27, ring_c + d1 * 0.27, 0.06, 0.06, 6, col, false)


## A mooring line from a bollard's head `a` to a hull's fairlead `b`, sagging `sag` in the middle (a few segments).
static func rope(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, sag := 0.6, r := 0.045) -> void:
	var n := 8
	var prev := a
	for i in range(1, n + 1):
		var t: float = float(i) / float(n)
		var p: Vector3 = a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
		pk.tube(kit, "matte", prev, p, r, r, 5, Color(0.70, 0.62, 0.42), false)
		prev = p


# ======================================================================================
#  Warehouses
# ======================================================================================

## A port warehouse at life size: `w` along x (the front, +z), `d` deep, walls `h` to the eaves, a pitched roof in
## corrugated iron along x. Brick on a concrete plinth, pilasters between the bays with stone caps, a corbelled band
## under the eaves, stone-coped gables at both ends with a round vent; `doors` roller doors along the front (and half
## as many at the back) under their drums, a steel canopy along the front if `canopy`, high windows between the doors,
## a painted sign band over them (its middle and width go into `labels` for the generator's lettering), gutters and
## downpipes, a lamp over each door. `shutter` is the doors' paint.
static func warehouse(pk: PropKit, kit: Dictionary, w: float, d: float, h: float, doors: int, labels: Array, sign_text: String,
		shutter := Color(0.36, 0.44, 0.48), brick := BRICK_RED, canopy := true, roof_col := IRON_GREY) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	var pitch := 0.42
	var ridge_h: float = h + hd * pitch
	# Plinth and walls.
	blk(pk, kit, "concrete", Vector3(-hw - 0.08, 0.0, -hd - 0.08), Vector3(hw + 0.08, 0.6, hd + 0.08), Color(0.64, 0.63, 0.60))
	wall(pk, kit, "brick", Vector3(-hw, 0, hd), Vector3(hw, 0, hd), 0.6, h, brick, Vector3.BACK)
	wall(pk, kit, "brick", Vector3(hw, 0, -hd), Vector3(-hw, 0, -hd), 0.6, h, brick, Vector3.FORWARD)
	wall(pk, kit, "brick", Vector3(hw, 0, hd), Vector3(hw, 0, -hd), 0.6, h, brick, Vector3.RIGHT)
	wall(pk, kit, "brick", Vector3(-hw, 0, -hd), Vector3(-hw, 0, hd), 0.6, h, brick, Vector3.LEFT)
	# Gables.
	gable(pk, kit, "brick", Vector3(hw, h, hd), Vector3(hw, h, -hd), Vector3(hw, ridge_h, 0), brick, Vector3.RIGHT)
	gable(pk, kit, "brick", Vector3(-hw, h, -hd), Vector3(-hw, h, hd), Vector3(-hw, ridge_h, 0), brick, Vector3.LEFT)
	# Gable copings (stone, standing proud of the roof) and kneelers.
	for sx in [-1.0, 1.0]:
		var x: float = sx * (hw - 0.05)
		for sz in [-1.0, 1.0]:
			var a := Vector3(x, h - 0.05, sz * (hd + 0.25))
			var t := Vector3(x, ridge_h + 0.1, 0.0)
			pk.beam(kit, "plaster", a + Vector3(0, 0.18, 0), t + Vector3(0, 0.18, 0), 0.5, 0.22, SANDSTONE, Vector3.UP)
			blk(pk, kit, "plaster", Vector3(x - 0.3, h - 0.35, sz * (hd + 0.25) - 0.3), Vector3(x + 0.3, h + 0.2, sz * (hd + 0.25) + 0.3), SANDSTONE)
		# A round vent in each gable: a stone ring and dark louvres.
		var vc := Vector3(sx * (hw + 0.02), h + hd * pitch * 0.45, 0.0)
		var vb := Basis(Vector3.BACK, Vector3.UP, Vector3.RIGHT * sx)
		for q in range(12):
			var a0: float = TAU * float(q) / 12.0
			var a1: float = TAU * float(q + 1) / 12.0
			pk.beam(kit, "plaster", vc + vb * Vector3(cos(a0), sin(a0), 0) * 0.62, vc + vb * Vector3(cos(a1), sin(a1), 0) * 0.62, 0.16, 0.08, SANDSTONE)
		for q2 in range(5):
			var yy: float = -0.4 + 0.2 * float(q2)
			var half: float = sqrt(maxf(0.36 - yy * yy, 0.0))
			pk.beam(kit, "steel", vc + vb * Vector3(-half, yy, 0.0), vc + vb * Vector3(half, yy, 0.0), 0.12, 0.03, Color(0.12, 0.13, 0.13), Vector3.UP)
	# Roof: two slopes with an overhang at the eaves, a ridge cap.
	var ov := 0.35
	var e_y: float = h - ov * pitch
	roof(pk, kit, "iron", Vector3(-hw - 0.2, e_y, hd + ov), Vector3(hw + 0.2, e_y, hd + ov), Vector3(hw + 0.2, ridge_h, 0.0), Vector3(-hw - 0.2, ridge_h, 0.0), roof_col, Vector3(0, 1, pitch).normalized())
	roof(pk, kit, "iron", Vector3(hw + 0.2, e_y, -hd - ov), Vector3(-hw - 0.2, e_y, -hd - ov), Vector3(-hw - 0.2, ridge_h, 0.0), Vector3(hw + 0.2, ridge_h, 0.0), roof_col, Vector3(0, 1, -pitch).normalized())
	pk.beam(kit, "steel", Vector3(-hw - 0.2, ridge_h + 0.04, 0), Vector3(hw + 0.2, ridge_h + 0.04, 0), 0.4, 0.12, roof_col.darkened(0.25), Vector3.BACK)
	# Rooflights: pale panels in the iron, along each slope.
	var n_rl: int = maxi(int(w / 6.0), 1)
	for i in range(n_rl):
		var x0: float = -hw + (float(i) + 0.3) * w / float(n_rl)
		var x1: float = x0 + w / float(n_rl) * 0.35
		for sz in [-1.0, 1.0]:
			var z0: float = sz * hd * 0.25
			var z1: float = sz * hd * 0.65
			var y0: float = ridge_h - absf(z0) * pitch + 0.025
			var y1: float = ridge_h - absf(z1) * pitch + 0.025
			pk.quad(kit, "plastic", [Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y0, z0), Vector3(x0, y0, z0)], Vector3(0, 1, sz * pitch).normalized(), Color(0.74, 0.78, 0.76))
	# Brick band under the eaves and pilasters with stone caps.
	for side in [1.0, -1.0]:
		var z0: float = side * hd
		var z1: float = side * (hd + 0.12)
		blk(pk, kit, "brick", Vector3(-hw - 0.12, h - 0.75, minf(z0, z1)), Vector3(hw + 0.12, h - 0.35, maxf(z0, z1)), brick.darkened(0.1))
	var bays: int = maxi(doors * 2, 2)
	for i in range(bays + 1):
		var x: float = -hw + w * float(i) / float(bays)
		for side in [1.0, -1.0]:
			var z: float = side * (hd + 0.07)
			blk(pk, kit, "brick", Vector3(x - 0.3, 0.6, z - 0.07), Vector3(x + 0.3, h - 0.75, z + 0.07), brick.darkened(0.05))
			blk(pk, kit, "plaster", Vector3(x - 0.36, h - 0.95, z - 0.1), Vector3(x + 0.36, h - 0.75, z + 0.1), SANDSTONE)
			blk(pk, kit, "plaster", Vector3(x - 0.36, 0.6, z - 0.1), Vector3(x + 0.36, 0.8, z + 0.1), SANDSTONE)
	# Doors on the front (every other bay) and the back, windows in the bays between.
	var door_w: float = minf(4.2, w / float(bays) - 1.0)
	var door_h := minf(4.6, h - 4.2)
	var top: float = 0.6 + door_h
	for side in [1.0, -1.0]:
		var n: int = doors if side > 0.0 else maxi(doors / 2, 1)
		var out := Vector3(0, 0, side)
		for i in range(bays):
			var x: float = -hw + w * (float(i) + 0.5) / float(bays)
			var is_door: bool = (i % 2 == 0) if side > 0.0 else (i % (bays / n) == 0)
			if is_door:
				roller_door(pk, kit, Vector3(x, 0.0, side * hd), out, door_w, door_h, shutter)
				# A lamp over it.
				var lp := Vector3(x, top + 0.7, side * (hd + 0.05))
				pk.beam(kit, "steel", lp, lp + out * 0.55 + Vector3(0, 0.15, 0), 0.04, 0.04, CAST)
				pk.box(kit, "steel", Transform3D(Basis(), lp + out * 0.6 + Vector3(0, 0.08, 0)), Vector3(0.36, 0.08, 0.3), Color(0.14, 0.32, 0.24))
				pk.box(kit, "lamp", Transform3D(Basis(), lp + out * 0.6 + Vector3(0, 0.03, 0)), Vector3(0.24, 0.03, 0.2), Color(1.0, 0.92, 0.75))
			else:
				var ww: float = minf(1.4, w / float(bays) - 1.2)
				window(pk, kit, Vector3(x, 3.2, side * hd), out, ww, 2.0)
				# A high window over the canopy where there is room under the eaves band.
				if (not canopy or side < 0.0) and top + 2.3 < h - 0.9:
					window(pk, kit, Vector3(x, top + 1.3, side * hd), out, ww, 1.4)
	# Sign band on the front over the doors: painted render, the letters are Label3Ds.
	var sy0: float = top + (1.35 if canopy else 0.9)
	var sy1: float = minf(sy0 + 1.1, h - 0.95)
	if sign_text != "" and sy1 > sy0 + 0.5:
		var sw: float = minf(w * 0.55, 16.0)
		blk(pk, kit, "painted", Vector3(-sw * 0.5, sy0, hd + 0.1), Vector3(sw * 0.5, sy1, hd + 0.2), Color(0.92, 0.89, 0.80))
		labels.append([sign_text, Vector3(0, (sy0 + sy1) * 0.5, hd + 0.23), Vector3.BACK, (sy1 - sy0) * 0.55, Color(0.12, 0.2, 0.28), sw - 0.6])
	# A canopy over the front doors: steel brackets and a corrugated sheet.
	if canopy:
		var cd := 3.2
		var cy: float = top + 1.0
		roof(pk, kit, "iron", Vector3(-hw + 0.4, cy - 0.35, hd + cd), Vector3(hw - 0.4, cy - 0.35, hd + cd), Vector3(hw - 0.4, cy, hd + 0.02), Vector3(-hw + 0.4, cy, hd + 0.02), roof_col.darkened(0.1), Vector3(0, 1, 0.11).normalized())
		for i in range(bays + 1):
			var x: float = clampf(-hw + w * float(i) / float(bays), -hw + 0.6, hw - 0.6)
			pk.beam(kit, "steel", Vector3(x, cy - 1.4, hd + 0.08), Vector3(x, cy - 0.36, hd + cd - 0.2), 0.08, 0.12, PAINT_GREEN)
			pk.beam(kit, "steel", Vector3(x, cy - 0.04, hd + 0.08), Vector3(x, cy - 0.36, hd + cd - 0.2), 0.06, 0.1, PAINT_GREEN)
	# Gutters and downpipes at the corners.
	for side in [1.0, -1.0]:
		var gz: float = side * (hd + ov - 0.05)
		pk.beam(kit, "steel", Vector3(-hw - 0.2, e_y - 0.06, gz), Vector3(hw + 0.2, e_y - 0.06, gz), 0.16, 0.14, Color(0.22, 0.24, 0.24), Vector3.UP)
		for sx in [-1.0, 1.0]:
			var px: float = sx * (hw - 0.45)
			pk.tube(kit, "steel", Vector3(px, e_y - 0.1, gz), Vector3(px, e_y - 0.5, side * (hd + 0.12)), 0.06, 0.06, 6, Color(0.22, 0.24, 0.24), false)
			pk.tube(kit, "steel", Vector3(px, e_y - 0.5, side * (hd + 0.12)), Vector3(px, 0.3, side * (hd + 0.12)), 0.06, 0.06, 6, Color(0.22, 0.24, 0.24), false)


## A roller door in a wall facing `out`: `c` the middle of its foot on the wall's face. The curtain's slats are the
## corrugated iron (its ribs laid across), in a steel frame, the drum's box over it.
static func roller_door(pk: PropKit, kit: Dictionary, c: Vector3, out: Vector3, w: float, h: float, col: Color) -> void:
	var across: Vector3 = out.cross(Vector3.UP).normalized()
	var b := Basis(across, Vector3.UP, out)
	# 6cm proud of the wall (10cm at the game's scale): 2cm flickered against the brick from across the harbour.
	var f: Vector3 = c + out * 0.06
	var p0: Vector3 = f - across * (w * 0.5) + Vector3(0, 0.6, 0)
	var p1: Vector3 = f + across * (w * 0.5) + Vector3(0, 0.6, 0)
	var top: float = 0.6 + h
	# Ribs across: u up the door, v along it.
	pk.quad(kit, "iron", [p0, p0 + Vector3(0, h, 0), p1 + Vector3(0, h, 0), p1], out, col,
			[Vector2(0, 0), Vector2(h * uvk, 0), Vector2(h * uvk, w * uvk), Vector2(0, w * uvk)])
	for sx in [-1.0, 1.0]:
		pk.box(kit, "steel", Transform3D(b, c + across * (sx * (w * 0.5 + 0.08)) + Vector3(0, 0.6 + h * 0.5, 0.0) + out * 0.09), Vector3(0.16, h, 0.18), col.darkened(0.3))
	pk.box(kit, "steel", Transform3D(b, c + Vector3(0, top + 0.28, 0) + out * 0.2), Vector3(w + 0.4, 0.56, 0.4), col.darkened(0.15))
	pk.box(kit, "steel", Transform3D(b, c + Vector3(0, 0.62, 0) + out * 0.1), Vector3(w, 0.06, 0.1), Color(0.1, 0.1, 0.1))
	# A painted kerb either side, scuffed by forklifts.
	for sx2 in [-1.0, 1.0]:
		pk.box(kit, "painted", Transform3D(b, c + across * (sx2 * (w * 0.5 + 0.35)) + Vector3(0, 0.45, 0) + out * 0.18), Vector3(0.24, 0.9, 0.24), SAFETY_YELLOW)


# ======================================================================================
#  Harbour lights and breakwater armour
# ======================================================================================

## A harbour-entrance light at life size: a concrete drum on the breakwater's head, a round tower banded white and
## `band` (red to port coming in, green to starboard), a gallery with a railing, the lantern (its glass glowing) under a
## domed roof and vent ball, a door and a ladder up the drum.
static func harbour_light(pk: PropKit, kit: Dictionary, p: Vector3, band: Color, labels: Array, text: String) -> void:
	var white := Color(0.93, 0.92, 0.88)
	pk.lathe(kit, "concrete", p, [Vector2(0.001, 0.0), Vector2(3.4, 0.0), Vector2(3.4, 1.8), Vector2(3.2, 2.0), Vector2(0.001, 2.0)], 24, Color(0.7, 0.69, 0.66))
	var ty := 2.0
	var tower_h := 10.5
	var r0 := 1.55
	var r1 := 1.15
	var bands := 6
	for i in range(bands):
		var y0: float = ty + tower_h * float(i) / float(bands)
		var y1: float = ty + tower_h * float(i + 1) / float(bands)
		var ra: float = lerpf(r0, r1, float(i) / float(bands))
		var rb: float = lerpf(r0, r1, float(i + 1) / float(bands))
		pk.tube(kit, "painted", p + Vector3(0, y0, 0), p + Vector3(0, y1, 0), ra, rb, 20, band if i % 2 == 1 else white, false)
	var gy: float = ty + tower_h
	pk.lathe(kit, "concrete", p + Vector3(0, gy, 0), [Vector2(0.001, 0.0), Vector2(r1 + 0.1, 0.0), Vector2(2.0, 0.25), Vector2(2.0, 0.42), Vector2(0.001, 0.42)], 20, white)
	# The railing round the gallery.
	var gr := 1.9
	for k in range(16):
		var a: float = TAU * float(k) / 16.0
		var a2: float = TAU * float(k + 1) / 16.0
		var q: Vector3 = p + Vector3(cos(a) * gr, gy + 0.42, sin(a) * gr)
		var q2: Vector3 = p + Vector3(cos(a2) * gr, gy + 0.42, sin(a2) * gr)
		pk.beam(kit, "steel", q, q + Vector3(0, 1.0, 0), 0.04, 0.04, CAST)
		pk.beam(kit, "steel", q + Vector3(0, 1.0, 0), q2 + Vector3(0, 1.0, 0), 0.05, 0.05, CAST)
		pk.beam(kit, "steel", q + Vector3(0, 0.5, 0), q2 + Vector3(0, 0.5, 0), 0.035, 0.035, CAST)
	# The lantern: a glowing glass drum in a frame of astragals, a base course under it.
	var ly: float = gy + 0.42
	pk.tube(kit, "painted", p + Vector3(0, ly, 0), p + Vector3(0, ly + 0.6, 0), 0.95, 0.95, 16, band, true)
	pk.tube(kit, "lamp", p + Vector3(0, ly + 0.6, 0), p + Vector3(0, ly + 2.0, 0), 0.85, 0.85, 16, Color(1.0, 0.9, 0.7), false)
	for k in range(8):
		var a: float = TAU * float(k) / 8.0
		pk.beam(kit, "steel", p + Vector3(cos(a) * 0.88, ly + 0.6, sin(a) * 0.88), p + Vector3(cos(a) * 0.88, ly + 2.0, sin(a) * 0.88), 0.05, 0.05, CAST)
	pk.lathe(kit, "painted", p + Vector3(0, ly + 2.0, 0), [Vector2(0.001, 0.0), Vector2(1.08, 0.0), Vector2(1.0, 0.18), Vector2(0.8, 0.55), Vector2(0.45, 0.82),
			Vector2(0.16, 0.92), Vector2(0.001, 0.94)], 16, band)
	pk.lathe(kit, "steel", p + Vector3(0, ly + 2.9, 0), [Vector2(0.001, 0.0), Vector2(0.06, 0.0), Vector2(0.06, 0.3), Vector2(0.2, 0.42), Vector2(0.2, 0.52), Vector2(0.001, 0.64)], 10, CAST)
	# The door at the tower's foot, facing +z, and a ladder up the drum to it.
	var dz: float = r0 + 0.04
	pk.box(kit, "painted", Transform3D(Basis(), p + Vector3(0, ty + 1.05, dz)), Vector3(0.9, 1.9, 0.08), Color(0.2, 0.24, 0.22))
	ladder(pk, kit, p + Vector3(0.0, 0.0, 3.4), p + Vector3(0.0, 2.0, 3.4), Vector3.BACK)
	if text != "":
		labels.append([text, Vector3(0, 1.0, 3.42), Vector3.BACK, 0.34, Color(0.1, 0.1, 0.1), 4.6])


## A tetrapod (the breakwater's armour): four legs out of the middle along the corners of a tetrahedron, each a cone
## cut off flat, at life size about 2.5m across. Built round the origin (the instances turn it).
static func tetrapod(pk: PropKit, kit: Dictionary, s := 1.0) -> void:
	var dirs := [Vector3(0, 1, 0), Vector3(0.9428, -0.3333, 0), Vector3(-0.4714, -0.3333, 0.8165), Vector3(-0.4714, -0.3333, -0.8165)]
	for d in dirs:
		pk.tube(kit, "pile", Vector3.ZERO, (d as Vector3) * 1.25 * s, 0.55 * s, 0.34 * s, 10, Color(0.74, 0.72, 0.68), true)
	pk.lathe(kit, "pile", Vector3(0, -0.45 * s, 0), [Vector2(0.001, 0.0), Vector2(0.5 * s, 0.15 * s), Vector2(0.62 * s, 0.45 * s), Vector2(0.5 * s, 0.75 * s), Vector2(0.001, 0.9 * s)], 10, Color(0.74, 0.72, 0.68))


# ======================================================================================
#  The container terminal's cranes (built in world metres: the kit's scale is 1)
# ======================================================================================

const CRANE_WHITE := Color(0.90, 0.90, 0.87)
const CRANE_BLUE := Color(0.14, 0.30, 0.55)

## A ship-to-shore container crane. Frame: the waterside rail at x = 0 on the quay, the landside rail at x = `gauge`,
## z along the quay, the boom over the water toward -x. Four box legs on bogies, sill beams along each rail, portal
## beams across at the top, the boom's two box girders over them from the backreach (x = gauge + 18) to the tip
## (`outreach` past the waterside rail), raised about its hinge by `raise` (radians, 0 working), the A-frame with fore-
## and backstays, the machinery house on the backreach, the trolley with its cab and the spreader hanging `drop` metres
## under the boom. `labels` gets the name on the machinery house.
static func sts_crane(pk: PropKit, kit: Dictionary, labels: Array, gauge := 30.0, outreach := 56.0, trolley := 24.0, drop := 26.0, raise := 0.0, text := "BLOOMBAY PORT") -> void:
	var leg_top := 40.0
	var lz := 9.0
	var white := CRANE_WHITE
	# Bogies and legs.
	for x in [0.0, gauge]:
		for z in [-lz, lz]:
			pk.box(kit, "steel", Transform3D(Basis(), Vector3(x, 0.9, z)), Vector3(1.6, 1.4, 7.0), Color(0.86, 0.66, 0.12))
			for k in range(4):
				pk.tube(kit, "steel", Vector3(x - 0.9, 0.45, z - 2.6 + 1.73 * float(k)), Vector3(x + 0.9, 0.45, z - 2.6 + 1.73 * float(k)), 0.45, 0.45, 8, Color(0.1, 0.1, 0.1))
			pk.box(kit, "steel", Transform3D(Basis(), Vector3(x, (1.6 + leg_top) * 0.5, z)), Vector3(1.5, leg_top - 1.6, 1.5), white)
		# The sill beam joining the legs on this rail, and the knee braces up into the portal.
		pk.box(kit, "steel", Transform3D(Basis(), Vector3(x, 2.4, 0)), Vector3(1.2, 1.4, lz * 2.0), white)
		for sz in [-1.0, 1.0]:
			pk.beam(kit, "steel", Vector3(x, 26.0, sz * lz), Vector3(x, leg_top - 1.0, 0.0), 0.8, 0.8, white)
	for z in [-lz, lz]:
		pk.box(kit, "steel", Transform3D(Basis(), Vector3(gauge * 0.5, leg_top, z)), Vector3(gauge + 1.5, 2.2, 1.6), white)
		# Diagonal bracing across the landside portal (the waterside one stays open for the hatch covers).
		pk.beam(kit, "steel", Vector3(gauge, 6.0, z), Vector3(gauge * 0.55, leg_top - 1.1, z), 0.6, 0.6, white)
	pk.box(kit, "steel", Transform3D(Basis(), Vector3(gauge * 0.5, leg_top - 0.3, 0)), Vector3(1.2, 1.2, lz * 2.0), white)
	# The boom: two girders, the backreach fixed, the outreach hinged at the waterside legs.
	var by := leg_top + 2.6
	var bz := 4.6
	var back := gauge + 18.0
	var hinge := Vector3(-2.0, by, 0)
	var rb := Basis(Vector3.BACK, -raise)
	var tip: Vector3 = hinge + rb * Vector3(-(outreach - 2.0), 0, 0)
	for sz in [-1.0, 1.0]:
		pk.beam(kit, "steel", Vector3(back, by, sz * bz), Vector3(hinge.x, by, sz * bz), 1.3, 2.8, white, Vector3.BACK)
		pk.beam(kit, "steel", hinge + Vector3(0, 0, sz * bz), tip + Vector3(0, 0, sz * bz), 1.3, 2.8, white, Vector3.BACK)
		# Red and white bands at the tip.
		for k in range(3):
			var t0: float = 1.0 - 0.06 * float(k + 1)
			var t1: float = t0 + 0.03
			pk.beam(kit, "steel", hinge.lerp(tip, t0) + Vector3(0, 0, sz * bz * 1.02), hinge.lerp(tip, t1) + Vector3(0, 0, sz * bz * 1.02), 1.36, 2.86, Color(0.78, 0.12, 0.1), Vector3.BACK)
		# Walkway rail along the girder's top.
		pk.beam(kit, "steel", Vector3(back, by + 2.4, sz * (bz + 0.5)), Vector3(hinge.x, by + 2.4, sz * (bz + 0.5)), 0.05, 0.05, Color(0.85, 0.66, 0.12), Vector3.UP)
	# Cross girts along the boom.
	var x := back
	while x > hinge.x:
		pk.beam(kit, "steel", Vector3(x, by + 1.0, -bz), Vector3(x, by + 1.0, bz), 0.5, 0.5, white)
		x -= 7.0
	for k in range(1, 8):
		var p: Vector3 = hinge.lerp(tip, float(k) / 8.0)
		pk.beam(kit, "steel", p + Vector3(0, 1.0, -bz), p + Vector3(0, 1.0, bz), 0.5, 0.5, white)
	# The A-frame and its stays.
	var apex := Vector3(gauge * 0.32, by + 26.0, 0.0)
	for sz in [-1.0, 1.0]:
		pk.beam(kit, "steel", Vector3(0.0, by + 1.2, sz * bz), apex + Vector3(0, 0, sz * 0.6), 1.0, 1.0, white)
		pk.beam(kit, "steel", Vector3(gauge, by + 1.2, sz * bz), apex + Vector3(0, 0, sz * 0.6), 1.0, 1.0, white)
		for t in [0.45, 0.85]:
			pk.beam(kit, "steel", apex + Vector3(0, 0, sz * 0.5), hinge.lerp(tip, t) + Vector3(0, 1.4, sz * bz), 0.35, 0.35, white.darkened(0.15))
		pk.beam(kit, "steel", apex + Vector3(0, 0, sz * 0.5), Vector3(back - 1.0, by + 1.4, sz * bz), 0.35, 0.35, white.darkened(0.15))
	pk.box(kit, "steel", Transform3D(Basis(), apex + Vector3(0, 0.6, 0)), Vector3(2.0, 1.6, 2.6), white)
	pk.box(kit, "lamp", Transform3D(Basis(), apex + Vector3(0, 1.6, 0)), Vector3(0.5, 0.5, 0.5), Color(1.0, 0.2, 0.1))
	# The machinery house on the backreach.
	blk(pk, kit, "steel", Vector3(gauge + 3.0, by + 1.4, -bz - 1.2), Vector3(back - 0.5, by + 7.5, bz + 1.2), CRANE_BLUE)
	blk(pk, kit, "steel", Vector3(gauge + 2.8, by + 7.5, -bz - 1.4), Vector3(back - 0.3, by + 7.8, bz + 1.4), CRANE_BLUE.darkened(0.3))
	labels.append([text, Vector3((gauge + 3.0 + back) * 0.5, by + 4.6, bz + 1.22), Vector3.BACK, 1.6, CRANE_WHITE, back - gauge - 5.0])
	labels.append([text, Vector3((gauge + 3.0 + back) * 0.5, by + 4.6, -bz - 1.22), Vector3.FORWARD, 1.6, CRANE_WHITE, back - gauge - 5.0])
	# The trolley, its cab and the spreader with a box under it (only when working).
	if raise == 0.0:
		var tx: float = -trolley
		blk(pk, kit, "steel", Vector3(tx - 3.0, by - 1.9, -bz + 0.6), Vector3(tx + 3.0, by + 0.2, bz - 0.6), white.darkened(0.08))
		blk(pk, kit, "steel", Vector3(tx - 1.6, by - 4.6, -bz + 0.4), Vector3(tx + 1.6, by - 1.9, -bz + 3.2), white)
		pk.box(kit, "glass", Transform3D(Basis(), Vector3(tx, by - 3.3, -bz + 0.38)), Vector3(2.8, 1.8, 0.05), Color(0.08, 0.12, 0.16, 0.95))
		var sy: float = by - drop
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				pk.beam(kit, "steel", Vector3(tx + sx * 1.0, by - 1.9, sz * 1.5), Vector3(tx + sx * 1.0, sy + 0.8, sz * 1.5), 0.06, 0.06, Color(0.15, 0.15, 0.15))
		pk.box(kit, "steel", Transform3D(Basis(), Vector3(tx, sy + 0.4, 0)), Vector3(3.9, 0.8, 19.6), Color(0.86, 0.66, 0.12))
	# A caged ladder up a landside leg.
	ladder(pk, kit, Vector3(gauge + 0.76, 3.2, lz), Vector3(gauge + 0.76, leg_top - 1.2, lz), Vector3.RIGHT, true, Color(0.85, 0.66, 0.12))


## A rubber-tyred gantry crane over a yard block: `span` across (x), 4 legs on tyred bogies, girders along x at the top,
## a trolley, the diesel house on one leg. Frame: the block's middle on the ground, x across it.
static func rtg(pk: PropKit, kit: Dictionary, span := 36.0, height := 26.0) -> void:
	var hs := span * 0.5
	var yellow := Color(0.92, 0.72, 0.12)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := Vector3(sx * hs, 0, sz * 4.5)
			pk.box(kit, "steel", Transform3D(Basis(), p + Vector3(0, height * 0.5 + 1.0, 0)), Vector3(1.2, height - 2.0, 1.2), yellow)
			for k in [-1.0, 1.0]:
				pk.tube(kit, "rubber", p + Vector3(-0.6, 1.1, k * 1.4), p + Vector3(0.6, 1.1, k * 1.4), 1.1, 1.1, 10, Color(0.06, 0.06, 0.06))
		pk.box(kit, "steel", Transform3D(Basis(), Vector3(sx * hs, 2.3, 0)), Vector3(1.4, 1.2, 9.6), yellow)
		pk.beam(kit, "steel", Vector3(sx * hs, 4.0, -4.5), Vector3(sx * hs, height - 1.0, 4.5), 0.5, 0.5, yellow)
	for sz in [-1.0, 1.0]:
		pk.box(kit, "steel", Transform3D(Basis(), Vector3(0, height + 0.5, sz * 4.5)), Vector3(span + 1.6, 2.0, 1.2), yellow)
	pk.box(kit, "steel", Transform3D(Basis(), Vector3(hs * 0.3, height - 0.2, 0)), Vector3(5.0, 2.4, 9.0), yellow.darkened(0.1))
	blk(pk, kit, "steel", Vector3(hs - 0.6, 4.0, -4.2), Vector3(hs + 3.0, 7.5, 4.2), CRANE_WHITE)


## A breakwater rock (for granite_rock.gdshader: vertex colour r the occlusion, g the height over the foot), a noisy
## twice-subdivided icosahedron, flattened underneath, stretched by `stretch`, its foot at y = 0.
static func rock_mesh(seed_v: int, stretch: Vector3, mat: Material) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = seed_v
	noise.frequency = 0.7
	noise.fractal_octaves = 3
	var t := (1.0 + sqrt(5.0)) / 2.0
	var verts: Array = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t),
		Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var faces: Array = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	for i in range(verts.size()):
		verts[i] = (verts[i] as Vector3).normalized()
	for _sd in range(1):
		var cache := {}
		var nf: Array = []
		for f in faces:
			var m: Array = []
			for e in [[f[0], f[1]], [f[1], f[2]], [f[2], f[0]]]:
				var key := Vector2i(mini(e[0], e[1]), maxi(e[0], e[1]))
				if not cache.has(key):
					verts.append(((verts[e[0]] as Vector3) + (verts[e[1]] as Vector3)).normalized())
					cache[key] = verts.size() - 1
				m.append(cache[key])
			nf.append([f[0], m[0], m[2]])
			nf.append([f[1], m[1], m[0]])
			nf.append([f[2], m[2], m[1]])
			nf.append([m[0], m[1], m[2]])
		faces = nf
	# Quarried armour stone: blocky (pulled toward a box), lumpy, with flat faces and sharp arrises.
	var pts := PackedVector3Array()
	var lo := INF
	for v in verts:
		var d: Vector3 = v
		var boxy: Vector3 = d / maxf(absf(d.x), maxf(absf(d.y), absf(d.z)))
		var r: float = 1.0 + 0.3 * noise.get_noise_3dv(d * 0.8) + 0.1 * noise.get_noise_3dv(d * 2.4 + Vector3(7, 0, 0))
		var p: Vector3 = d.lerp(boxy * 0.82, 0.55) * r
		p.y = maxf(p.y, -0.45)
		p *= stretch
		pts.append(p)
		lo = minf(lo, p.y)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in faces:
		var a: Vector3 = pts[f[0]]
		var b: Vector3 = pts[f[1]]
		var c: Vector3 = pts[f[2]]
		if (c - a).cross(b - a).dot((a + b + c) / 3.0) < 0.0:
			var tmp := b
			b = c
			c = tmp
		var fn: Vector3 = (c - a).cross(b - a).normalized()
		for p in [a, b, c]:
			var occ: float = clampf(0.85 + 0.3 * noise.get_noise_3dv(p * 2.0 + Vector3(0, 11, 0)), 0.55, 1.0)
			st.set_color(Color(occ, clampf((p.y - lo) / 0.6, 0.0, 1.0), 0.0))
			st.set_normal(fn)
			st.add_vertex(Vector3(p.x, p.y - lo, p.z))
	var mesh := st.commit()
	mesh.surface_set_material(0, mat)
	return mesh


# ======================================================================================
#  The old town's cathedral
# ======================================================================================

const CATH_STONE := Color(0.86, 0.79, 0.66)
const CATH_COPPER := Color(0.42, 0.66, 0.56)
const CATH_SLATE := Color(0.36, 0.38, 0.42)

## A pointed window in a wall facing `out`: `c` the middle of its foot on the face, `w` by `h` to the springing, the
## point above it; dark glass (or coloured with `tint`) in a stone surround with a sill and a mullion.
static func lancet(pk: PropKit, kit: Dictionary, c: Vector3, out: Vector3, w: float, h: float, tint := Color(0.10, 0.13, 0.20, 0.95)) -> void:
	var across: Vector3 = out.cross(Vector3.UP).normalized()
	var b := Basis(across, Vector3.UP, out)
	var g: Vector3 = c + out * 0.05
	pk.box(kit, "glass", Transform3D(b, g + Vector3(0, h * 0.5, 0)), Vector3(w, h, 0.04), tint)
	var top: Vector3 = g + Vector3(0, h, 0)
	pk.tri(kit, "glass", top - across * (w * 0.5), top + across * (w * 0.5), top + Vector3(0, w * 0.75, 0), out, out, out, tint, out)
	var s: Vector3 = c + out * 0.12
	for sx in [-1.0, 1.0]:
		pk.beam(kit, "stonetrim", s + across * (sx * (w * 0.5 + 0.12)), s + across * (sx * (w * 0.5 + 0.12)) + Vector3(0, h, 0), 0.24, 0.2, CATH_STONE.darkened(0.06), out)
		pk.beam(kit, "stonetrim", s + across * (sx * (w * 0.5 + 0.12)) + Vector3(0, h, 0), s + Vector3(0, h + w * 0.8, 0), 0.24, 0.2, CATH_STONE.darkened(0.06), out)
	pk.beam(kit, "stonetrim", s - across * (w * 0.5 + 0.3), s + across * (w * 0.5 + 0.3), 0.2, 0.3, CATH_STONE.darkened(0.1), Vector3.UP)
	if w > 1.4:
		pk.beam(kit, "stonetrim", s + Vector3(0, 0, 0), s + Vector3(0, h + w * 0.45, 0), 0.14, 0.12, CATH_STONE.darkened(0.06), out)


## A rose window facing `out`: coloured glass in a stone ring with spokes and a ring of foils.
static func rose_window(pk: PropKit, kit: Dictionary, c: Vector3, out: Vector3, r: float) -> void:
	var across: Vector3 = out.cross(Vector3.UP).normalized()
	var cols := [Color(0.16, 0.24, 0.55, 0.95), Color(0.55, 0.14, 0.16, 0.95), Color(0.70, 0.55, 0.16, 0.95), Color(0.14, 0.40, 0.30, 0.95)]
	var n := 16
	for i in range(n):
		var a0: float = TAU * float(i) / float(n)
		var a1: float = TAU * float(i + 1) / float(n)
		var p0: Vector3 = c + out * 0.06 + (across * cos(a0) + Vector3.UP * sin(a0)) * r
		var p1: Vector3 = c + out * 0.06 + (across * cos(a1) + Vector3.UP * sin(a1)) * r
		pk.tri(kit, "glass", c + out * 0.06, p0, p1, out, out, out, cols[i % 4], out)
		pk.beam(kit, "stonetrim", c + out * 0.14 + (across * cos(a0) + Vector3.UP * sin(a0)) * (r + 0.2), c + out * 0.14 + (across * cos(a1) + Vector3.UP * sin(a1)) * (r + 0.2), 0.45, 0.3, CATH_STONE, out)
		pk.beam(kit, "stonetrim", c + out * 0.12, c + out * 0.12 + (across * cos(a0) + Vector3.UP * sin(a0)) * r, 0.12, 0.1, CATH_STONE.darkened(0.05), out)
		var mid: float = (a0 + a1) * 0.5
		pk.beam(kit, "stonetrim", c + out * 0.12 + (across * cos(a0) + Vector3.UP * sin(a0)) * (r * 0.55), c + out * 0.12 + (across * cos(mid) + Vector3.UP * sin(mid)) * (r * 0.7), 0.1, 0.1, CATH_STONE.darkened(0.05), out)
		pk.beam(kit, "stonetrim", c + out * 0.12 + (across * cos(mid) + Vector3.UP * sin(mid)) * (r * 0.7), c + out * 0.12 + (across * cos(a1) + Vector3.UP * sin(a1)) * (r * 0.55), 0.1, 0.1, CATH_STONE.darkened(0.05), out)
	pk.lathe(kit, "stonetrim", c + out * 0.1, [Vector2(0.001, 0.0), Vector2(r * 0.22, 0.0), Vector2(r * 0.18, 0.12), Vector2(0.001, 0.14)], 12, CATH_STONE, false, Basis(across, out, -Vector3.UP).orthonormalized())


## A recessed portal in a wall facing `out`: a dark door under a pointed arch, framed by stepped orders and a gable.
static func portal(pk: PropKit, kit: Dictionary, c: Vector3, out: Vector3, w: float, h: float) -> void:
	var across: Vector3 = out.cross(Vector3.UP).normalized()
	var b := Basis(across, Vector3.UP, out)
	pk.box(kit, "timber", Transform3D(b, c + out * 0.03 + Vector3(0, h * 0.5, 0)), Vector3(w, h, 0.06), Color(0.30, 0.18, 0.10))
	pk.tri(kit, "glass", c + out * 0.05 + Vector3(0, h, 0) - across * (w * 0.5), c + out * 0.05 + Vector3(0, h, 0) + across * (w * 0.5), c + out * 0.05 + Vector3(0, h + w * 0.7, 0), out, out, out, Color(0.55, 0.42, 0.18, 0.95), out)
	for k in range(3):
		var o: float = w * 0.5 + 0.3 + 0.45 * float(k)
		var d: float = 0.2 + 0.25 * float(k)
		for sx in [-1.0, 1.0]:
			pk.beam(kit, "stonetrim", c + out * d + across * (sx * o), c + out * d + across * (sx * o) + Vector3(0, h, 0), 0.4, 0.4, CATH_STONE.darkened(0.04 * float(k)), out)
			pk.beam(kit, "stonetrim", c + out * d + across * (sx * o) + Vector3(0, h, 0), c + out * d + Vector3(0, h + o * 1.4, 0), 0.4, 0.4, CATH_STONE.darkened(0.04 * float(k)), out)
	var go: float = w * 0.5 + 1.6
	var gy: float = h + go * 1.4 + 0.6
	pk.beam(kit, "stonetrim", c + out * 0.9 - across * go + Vector3(0, h, 0), c + out * 0.9 + Vector3(0, gy, 0), 0.5, 0.5, CATH_STONE)
	pk.beam(kit, "stonetrim", c + out * 0.9 + across * go + Vector3(0, h, 0), c + out * 0.9 + Vector3(0, gy, 0), 0.5, 0.5, CATH_STONE)


## A pinnacle: a square shaft and a pointed top, `p` its foot.
static func pinnacle(pk: PropKit, kit: Dictionary, p: Vector3, s: float, h: float) -> void:
	pk.box(kit, "stonetrim", Transform3D(Basis(), p + Vector3(0, h * 0.35, 0)), Vector3(s, h * 0.7, s), CATH_STONE)
	pk.lathe(kit, "stonetrim", p + Vector3(0, h * 0.7, 0), [Vector2(0.001, 0.0), Vector2(s * 0.75, 0.0), Vector2(0.001, h * 0.5)], 4, CATH_STONE, true, Basis(Vector3.UP, PI * 0.25))


## Bloombay's cathedral at life size. Frame: the west front's middle on the ground at the origin, facing +z, the nave
## running back toward -z. Twin towers with copper spires flanking a rose window over three portals; a nave with
## clerestory lancets over aisles with lean-to roofs, buttresses and flying buttresses with pinnacles; a transept with
## its own rose windows; a dome on a drum over the crossing with a lantern; a round apse; under it all a terraced
## podium with a broad flight of steps to the front, down to `foot` (negative) so it stands out of the slope.
static func cathedral(pk: PropKit, kit: Dictionary, foot: float) -> void:
	var st := CATH_STONE
	var nave_w := 6.0
	var aisle := 12.0
	var nave_h := 23.0
	var aisle_h := 11.5
	var z_end := -66.0
	var tr_z0 := -38.0
	var tr_z1 := -51.0
	var tr_x := 27.0
	# Podium and steps.
	blk(pk, kit, "plaster", Vector3(-tr_x - 4.0, foot, z_end - 12.0), Vector3(tr_x + 4.0, 0.0, 6.0), st.darkened(0.12))
	for k in range(int(ceil(-foot / 0.4))):
		var y: float = -0.4 * float(k + 1)
		if y < foot:
			break
		blk(pk, kit, "plaster", Vector3(-14.0, y, 6.0), Vector3(14.0, y + 0.4, 6.0 + 0.6 * float(k + 1)), st.darkened(0.08))
	# Nave walls, the west front between the towers, clerestory lancets.
	for sx in [-1.0, 1.0]:
		var x: float = sx * nave_w
		wall(pk, kit, "plaster", Vector3(x, 0, -9.0) if sx > 0 else Vector3(x, 0, z_end), Vector3(x, 0, z_end) if sx > 0 else Vector3(x, 0, -9.0), 0.0, nave_h, st, Vector3(sx, 0, 0))
		var z := -14.0
		while z > z_end + 4.0:
			if z < tr_z0 + 1.0 and z > tr_z1 - 1.0:
				z -= 6.0
				continue
			lancet(pk, kit, Vector3(x, aisle_h + 3.6, z), Vector3(sx, 0, 0), 1.8, 4.6)
			z -= 6.0
	wall(pk, kit, "plaster", Vector3(-nave_w, 0, -1.0), Vector3(nave_w, 0, -1.0), 0.0, nave_h, st, Vector3.BACK)
	gable(pk, kit, "plaster", Vector3(-nave_w, nave_h, -1.0), Vector3(nave_w, nave_h, -1.0), Vector3(0, nave_h + nave_w * 1.1, -1.0), st, Vector3.BACK)
	rose_window(pk, kit, Vector3(0, nave_h - 7.5, -1.0), Vector3.BACK, 4.2)
	portal(pk, kit, Vector3(0, 0, -1.0), Vector3.BACK, 3.6, 6.5)
	# Nave roof (slate) along z.
	var ridge: float = nave_h + nave_w * 1.1
	roof(pk, kit, "slate", Vector3(nave_w + 0.4, nave_h - 0.4, -1.0), Vector3(nave_w + 0.4, nave_h - 0.4, z_end), Vector3(0, ridge, z_end), Vector3(0, ridge, -1.0), CATH_SLATE, Vector3(1, 1.1, 0).normalized())
	roof(pk, kit, "slate", Vector3(-nave_w - 0.4, nave_h - 0.4, z_end), Vector3(-nave_w - 0.4, nave_h - 0.4, -1.0), Vector3(0, ridge, -1.0), Vector3(0, ridge, z_end), CATH_SLATE, Vector3(-1, 1.1, 0).normalized())
	# Aisles: outer walls with lancets, lean-to roofs, buttresses with flying buttresses and pinnacles.
	for sx in [-1.0, 1.0]:
		var xo: float = sx * aisle
		wall(pk, kit, "plaster", Vector3(xo, 0, -9.0) if sx > 0 else Vector3(xo, 0, z_end + 2.0), Vector3(xo, 0, z_end + 2.0) if sx > 0 else Vector3(xo, 0, -9.0), 0.0, aisle_h, st, Vector3(sx, 0, 0))
		wall(pk, kit, "plaster", Vector3(xo, 0, z_end + 2.0) if sx > 0 else Vector3(sx * nave_w, 0, z_end + 2.0), Vector3(sx * nave_w, 0, z_end + 2.0) if sx > 0 else Vector3(xo, 0, z_end + 2.0), 0.0, aisle_h, st, Vector3(0, 0, -1))
		roof(pk, kit, "slate", Vector3(xo + sx * 0.4, aisle_h - 0.2, -9.0) if sx > 0 else Vector3(xo + sx * 0.4, aisle_h - 0.2, z_end + 2.0),
				Vector3(xo + sx * 0.4, aisle_h - 0.2, z_end + 2.0) if sx > 0 else Vector3(xo + sx * 0.4, aisle_h - 0.2, -9.0),
				Vector3(sx * nave_w, aisle_h + 2.4, z_end + 2.0) if sx > 0 else Vector3(sx * nave_w, aisle_h + 2.4, -9.0),
				Vector3(sx * nave_w, aisle_h + 2.4, -9.0) if sx > 0 else Vector3(sx * nave_w, aisle_h + 2.4, z_end + 2.0), CATH_SLATE, Vector3(sx * 0.42, 1, 0).normalized())
		var z2 := -11.0
		while z2 > z_end + 3.0:
			var on_transept: bool = z2 < tr_z0 + 2.0 and z2 > tr_z1 - 2.0
			if not on_transept:
				lancet(pk, kit, Vector3(xo, 2.6, z2 - 3.0), Vector3(sx, 0, 0), 2.0, 5.2)
				# A buttress: stepped, its flier reaching up to the clerestory, a pinnacle on top.
				blk(pk, kit, "plaster", Vector3(minf(xo, xo + sx * 1.6), 0.0, z2 - 0.7), Vector3(maxf(xo, xo + sx * 1.6), aisle_h + 2.5, z2 + 0.7), st.darkened(0.04))
				blk(pk, kit, "plaster", Vector3(minf(xo + sx * 1.6, xo + sx * 2.6), 0.0, z2 - 0.6), Vector3(maxf(xo + sx * 1.6, xo + sx * 2.6), 6.0, z2 + 0.6), st.darkened(0.04))
				pk.beam(kit, "stonetrim", Vector3(xo + sx * 0.8, aisle_h + 2.2, z2), Vector3(sx * (nave_w + 0.2), nave_h - 4.0, z2), 0.7, 0.9, st.darkened(0.02))
				pinnacle(pk, kit, Vector3(xo + sx * 0.8, aisle_h + 2.5, z2), 1.0, 4.5)
			z2 -= 6.0
	# The transept: gabled ends with rose windows, slate roof across.
	for sx in [-1.0, 1.0]:
		var xt: float = sx * tr_x
		wall(pk, kit, "plaster", Vector3(xt, 0, tr_z0) if sx > 0 else Vector3(xt, 0, tr_z1), Vector3(xt, 0, tr_z1) if sx > 0 else Vector3(xt, 0, tr_z0), 0.0, nave_h, st, Vector3(sx, 0, 0))
		var hw := (tr_z0 - tr_z1) * 0.5
		var zc := (tr_z0 + tr_z1) * 0.5
		gable(pk, kit, "plaster", Vector3(xt, nave_h, tr_z0) if sx > 0 else Vector3(xt, nave_h, tr_z1), Vector3(xt, nave_h, tr_z1) if sx > 0 else Vector3(xt, nave_h, tr_z0), Vector3(xt, nave_h + hw * 1.1, zc), st, Vector3(sx, 0, 0))
		rose_window(pk, kit, Vector3(xt, nave_h - 7.0, zc), Vector3(sx, 0, 0), 3.6)
		portal(pk, kit, Vector3(xt, 0, zc), Vector3(sx, 0, 0), 2.6, 5.0)
		for side in [[tr_z0, Vector3.BACK], [tr_z1, Vector3.FORWARD]]:
			var zz: float = side[0]
			# From the nave's wall out to the end: from the aisle's wall it left a hole over the aisle roof at each corner.
			wall(pk, kit, "plaster", Vector3(sx * nave_w, 0, zz) if (sx > 0) == (side[1] == Vector3.BACK) else Vector3(xt, 0, zz),
					Vector3(xt, 0, zz) if (sx > 0) == (side[1] == Vector3.BACK) else Vector3(sx * nave_w, 0, zz), 0.0, nave_h, st, side[1])
			lancet(pk, kit, Vector3((sx * aisle + xt) * 0.5, 4.0, zz), side[1], 2.0, 7.0)
			pinnacle(pk, kit, Vector3(xt - sx * 0.6, nave_h, zz), 1.2, 6.0)
		roof(pk, kit, "slate", Vector3(xt + sx * 0.4, nave_h - 0.4, tr_z0 + 0.4) if sx > 0 else Vector3(sx * nave_w, nave_h - 0.4, tr_z0 + 0.4),
				Vector3(sx * nave_w, nave_h - 0.4, tr_z0 + 0.4) if sx > 0 else Vector3(xt + sx * 0.4, nave_h - 0.4, tr_z0 + 0.4),
				Vector3(sx * nave_w, nave_h + hw * 1.1, zc) if sx > 0 else Vector3(xt + sx * 0.4, nave_h + hw * 1.1, zc),
				Vector3(xt + sx * 0.4, nave_h + hw * 1.1, zc) if sx > 0 else Vector3(sx * nave_w, nave_h + hw * 1.1, zc), CATH_SLATE, Vector3(0, 1, 1.1).normalized())
		roof(pk, kit, "slate", Vector3(sx * nave_w, nave_h - 0.4, tr_z1 - 0.4) if sx > 0 else Vector3(xt + sx * 0.4, nave_h - 0.4, tr_z1 - 0.4),
				Vector3(xt + sx * 0.4, nave_h - 0.4, tr_z1 - 0.4) if sx > 0 else Vector3(sx * nave_w, nave_h - 0.4, tr_z1 - 0.4),
				Vector3(xt + sx * 0.4, nave_h + hw * 1.1, zc) if sx > 0 else Vector3(sx * nave_w, nave_h + hw * 1.1, zc),
				Vector3(sx * nave_w, nave_h + hw * 1.1, zc) if sx > 0 else Vector3(xt + sx * 0.4, nave_h + hw * 1.1, zc), CATH_SLATE, Vector3(0, 1, -1.1).normalized())
	# The crossing: an octagonal drum with lancets, a copper dome, a lantern and a cross.
	var cz: float = (tr_z0 + tr_z1) * 0.5
	var cc := Vector3(0, ridge - 0.5, cz)
	var drum_r := 8.0
	# A plain base under the drum, down through the roofs: the drum is wider than the nave and its foot hung in the air
	# over the roof slopes.
	pk.lathe(kit, "stonetrim", Vector3(0, nave_h - 1.5, cz), [Vector2(0.001, 0.0), Vector2(drum_r - 0.1, 0.0), Vector2(drum_r - 0.1, cc.y - nave_h + 1.6), Vector2(0.001, cc.y - nave_h + 1.6)], 8, st.darkened(0.05), true, Basis(Vector3.UP, PI / 8.0))
	pk.lathe(kit, "stonetrim", cc, [Vector2(0.001, 0.0), Vector2(drum_r, 0.0), Vector2(drum_r, 7.0), Vector2(drum_r + 0.5, 7.2), Vector2(drum_r + 0.5, 7.8), Vector2(0.001, 7.8)], 8, st, true, Basis(Vector3.UP, PI / 8.0))
	for k in range(8):
		var a: float = TAU * float(k) / 8.0
		var o := Vector3(cos(a), 0, sin(a))
		lancet(pk, kit, cc + o * (drum_r * 0.924) + Vector3(0, 1.4, 0), o, 1.6, 3.6)
	var dome := [Vector2(drum_r + 0.2, 0.0)]
	for k2 in range(1, 9):
		var t: float = float(k2) / 8.0 * PI * 0.5
		dome.append(Vector2((drum_r + 0.2) * cos(t), 7.5 * sin(t) * 1.25))
	pk.lathe(kit, "copper", cc + Vector3(0, 7.8, 0), dome, 16, CATH_COPPER)
	var top_y: float = 7.8 + 7.5 * 1.25
	pk.lathe(kit, "stonetrim", cc + Vector3(0, top_y - 0.3, 0), [Vector2(0.001, 0.0), Vector2(1.6, 0.0), Vector2(1.6, 3.2), Vector2(0.001, 3.2)], 8, st)
	pk.lathe(kit, "copper", cc + Vector3(0, top_y + 2.9, 0), [Vector2(1.9, 0.0), Vector2(1.2, 1.2), Vector2(0.3, 2.6), Vector2(0.001, 3.0)], 8, CATH_COPPER)
	pk.beam(kit, "steel", cc + Vector3(0, top_y + 5.8, 0), cc + Vector3(0, top_y + 8.6, 0), 0.25, 0.25, Color(0.8, 0.66, 0.3))
	pk.beam(kit, "steel", cc + Vector3(-0.9, top_y + 7.8, 0), cc + Vector3(0.9, top_y + 7.8, 0), 0.25, 0.25, Color(0.8, 0.66, 0.3))
	# The nave's east end over the apse: a wall from the apse's eaves up and its gable (the roof had stood open there).
	wall(pk, kit, "plaster", Vector3(nave_w, 0, z_end), Vector3(-nave_w, 0, z_end), nave_h - 4.5, nave_h, st, Vector3.FORWARD)
	gable(pk, kit, "plaster", Vector3(nave_w, nave_h, z_end), Vector3(-nave_w, nave_h, z_end), Vector3(0, ridge, z_end), st, Vector3.FORWARD)
	# The apse: a half drum of lancets under a cone.
	var ac := Vector3(0, 0, z_end)
	for k3 in range(7):
		var a0: float = PI + PI * float(k3) / 7.0
		var a1: float = PI + PI * float(k3 + 1) / 7.0
		var p0: Vector3 = ac + Vector3(-cos(a0), 0, sin(a0)) * nave_w
		var p1: Vector3 = ac + Vector3(-cos(a1), 0, sin(a1)) * nave_w
		var mid: Vector3 = (p0 + p1) * 0.5
		var o2: Vector3 = (mid - ac).normalized()
		wall(pk, kit, "plaster", p1, p0, 0.0, nave_h - 4.0, st, o2)
		lancet(pk, kit, mid + Vector3(0, 6.0, 0), o2, 1.6, 7.5)
		pk.tri(kit, "slatetrim", p0 + Vector3(0, nave_h - 4.0, 0) + o2 * 0.4, p1 + Vector3(0, nave_h - 4.0, 0) + o2 * 0.4, ac + Vector3(0, ridge - 1.0, 0), o2 + Vector3.UP, o2 + Vector3.UP, o2 + Vector3.UP, CATH_SLATE, o2 + Vector3.UP)
	# The west towers: stages with lancets and belfry openings, corner buttresses, a parapet with pinnacles, copper spires.
	var tw := 9.0
	var th := 38.0
	for sx in [-1.0, 1.0]:
		var tx: float = sx * (nave_w + tw * 0.5)
		var t0 := Vector3(tx, 0, -tw * 0.5)
		blk(pk, kit, "plaster", Vector3(tx - tw * 0.5, 0.0, -tw), Vector3(tx + tw * 0.5, th, 0.0), st)
		for cx in [-1.0, 1.0]:
			blk(pk, kit, "plaster", Vector3(tx + cx * tw * 0.5 - 0.8, 0.0, -0.6), Vector3(tx + cx * tw * 0.5 + 0.8, th - 6.0, 0.9), st.darkened(0.05))
		for band in [9.0, 20.0, 29.0]:
			blk(pk, kit, "plaster", Vector3(tx - tw * 0.5 - 0.2, band, -tw - 0.2), Vector3(tx + tw * 0.5 + 0.2, band + 0.5, 0.2), st.darkened(0.08))
		portal(pk, kit, Vector3(tx, 0, 0.0), Vector3.BACK, 2.4, 4.6)
		lancet(pk, kit, Vector3(tx, 11.5, 0.0), Vector3.BACK, 2.2, 6.0)
		for o3 in [Vector3.BACK, Vector3(sx, 0, 0)]:
			var fc: Vector3 = t0 + Vector3(0, 0, 0) + o3 * (tw * 0.5)
			lancet(pk, kit, Vector3(fc.x, 22.0, fc.z), o3, 1.2, 5.5)
			lancet(pk, kit, Vector3(fc.x, 30.5, fc.z), o3, 2.6, 5.0, Color(0.05, 0.05, 0.06, 0.98))
		for cx2 in [-1.0, 1.0]:
			for cz2 in [-1.0, 1.0]:
				pinnacle(pk, kit, Vector3(tx + cx2 * (tw * 0.5 - 0.6), th, -tw * 0.5 + cz2 * (tw * 0.5 - 0.6)), 1.2, 6.5)
		pk.lathe(kit, "copper", Vector3(tx, th, -tw * 0.5), [Vector2(tw * 0.42, 0.0), Vector2(tw * 0.36, 4.0), Vector2(0.4, 26.0), Vector2(0.001, 27.0)], 8, CATH_COPPER, true, Basis(Vector3.UP, PI / 8.0))
		pk.beam(kit, "steel", Vector3(tx, th + 26.5, -tw * 0.5), Vector3(tx, th + 29.5, -tw * 0.5), 0.2, 0.2, Color(0.8, 0.66, 0.3))
		pk.beam(kit, "steel", Vector3(tx - 0.8, th + 28.6, -tw * 0.5), Vector3(tx + 0.8, th + 28.6, -tw * 0.5), 0.2, 0.2, Color(0.8, 0.66, 0.3))
	# A gallery of statues' niches across the front over the portal.
	for k4 in range(5):
		var nx: float = -nave_w + 1.2 + float(k4) * (nave_w * 2.0 - 2.4) / 4.0
		lancet(pk, kit, Vector3(nx, 8.4, -1.0), Vector3.BACK, 0.9, 2.2, Color(0.30, 0.27, 0.22, 1.0))
