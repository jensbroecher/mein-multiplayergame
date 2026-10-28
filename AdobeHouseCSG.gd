extends RefCounted
## Canyon Chasm's two-story desert adobe pueblo house (House), modelled in CSG at life size
## (metres, y up, ground at y = 0, front facing +z):
## A 31.5m x 23.5m x 22.8m mud-plastered adobe structure with weathered stone cobble patches,
## rounded vertical corners, contoured saddle-curved roof parapets, protruding round wooden vigas
## (ceiling beams), a lower one-story side wing with a roof terrace and a wooden slatted pergola
## on stilts with knee braces, recessed plank doors under heavy timber lintels, stone threshold
## steps, shuttered windows, and upper dark recessed alcoves.
##
## It replaces the 50k-triangle Hunyuan FBX (models/desert/49ac41a0567226438249fc402b0d629c.fbx,
## imported at scale 35) and keeps its exact frame: House in CanyonChasmLevel.tscn keeps its
## position and rotation, with scale 1 instead of 35.
## regenerate_chasm_houses.gd builds the tree (`build`), lets the CSG update, and bakes it (`bake`)
## into generated/adobe_house.res, which AdobeHouse.tscn draws; the level holds no runtime CSG.

const SINK := 2.5

const COL_ADOBE := Color(0.84, 0.74, 0.60)
const COL_ADOBE_ROOF := Color(0.78, 0.68, 0.54)
const COL_STONE := Color(0.80, 0.74, 0.64)
const COL_TIMBER := Color(0.50, 0.41, 0.33)
const COL_TIMBER_DARK := Color(0.36, 0.29, 0.22)
const COL_DOOR := Color(0.46, 0.38, 0.30)
const COL_CANOPY := Color(0.56, 0.47, 0.38)
const COL_DARK := Color(0.08, 0.07, 0.06)

static var _placeholder_mats := {}
static var _final_mats := {}


static func build() -> CSGCombiner3D:
	var root := CSGCombiner3D.new()
	root.name = "AdobeHouseCSG"

	var m_adobe := _mat("adobe", COL_ADOBE)
	var m_roof := _mat("adobe", COL_ADOBE_ROOF)
	var m_stone := _mat("stucco", COL_STONE)
	var m_timber := _mat("timber", COL_TIMBER)
	var m_timber_dark := _mat("timber", COL_TIMBER_DARK)
	var m_door := _mat("wood_v", COL_DOOR)
	var m_shutter := _mat("wood_h", COL_DOOR)
	var m_canopy := _mat("wood_h", COL_CANOPY)
	var m_dark := _mat("dark", COL_DARK)

	# ------------------------------------------------------------------
	# 1. Adobe Pueblo Masses & Contoured Roof Parapets
	# ------------------------------------------------------------------
	var adobe := CSGCombiner3D.new()
	adobe.name = "AdobeWalls"

	# A. Left 2-Story Tower Block (in its own combiner so its saddle cuts stay local):
	#    X [-13.68 .. +4.10], Z [-9.40 .. +11.28], Y [-SINK .. 22.84]
	var tower := CSGCombiner3D.new()
	tower.name = "TowerMass"
	var tower_plan := _rounded_rect(-13.68, -9.40, 4.10, 11.28, 1.15, 6)
	_add(tower, _extrude_y(tower_plan, -SINK, 22.84, m_adobe), CSGShape3D.OPERATION_UNION)
	# Carve 2-story roof deck basin inside the tower parapet (leaving 1.15m parapet wall)
	var tower_basin := _rounded_rect(-12.52, -8.24, 2.94, 10.12, 0.65, 5)
	_add(tower, _extrude_y(tower_basin, 21.05, 23.60, m_roof), CSGShape3D.OPERATION_SUBTRACTION)
	# Saddle-curve the tower's parapet top so corners rise to 22.84m and mid-walls dip gently to ~22.05m
	_add(tower, _saddle_cyl_z(Vector3(-4.79, 22.05 + 52.0, 0.94), 52.0, 24.0, m_adobe), CSGShape3D.OPERATION_SUBTRACTION)
	_add(tower, _saddle_cyl_x(Vector3(-4.79, 22.05 + 68.0, 0.94), 68.0, 20.0, m_adobe), CSGShape3D.OPERATION_SUBTRACTION)
	_add(adobe, tower, CSGShape3D.OPERATION_UNION)

	# B. Right 1-Story Wing (in its own combiner so its parapet saddle cuts never touch the 2-story tower):
	#    X [+2.80 .. +16.28], Z [-9.42 .. +0.30], Y [-SINK .. 12.68]
	var wing := CSGCombiner3D.new()
	wing.name = "WingMass"
	var wing_plan := _rounded_rect(2.80, -9.42, 16.28, 0.30, 0.95, 6)
	_add(wing, _extrude_y(wing_plan, -SINK, 12.68, m_adobe), CSGShape3D.OPERATION_UNION)
	# Carve 1-story wing roof terrace basin (leaving 1.05m parapet around X [+4.05..+15.22], Z [-8.36..-0.76])
	var wing_basin := _rounded_rect(4.05, -8.36, 15.22, -0.76, 0.55, 5)
	_add(wing, _extrude_y(wing_basin, 11.18, 13.40, m_roof), CSGShape3D.OPERATION_SUBTRACTION)
	# Gentle saddle dip along the 1-story wing parapet
	_add(wing, _saddle_cyl_z(Vector3(10.20, 12.02 + 42.0, -4.56), 42.0, 12.0, m_adobe), CSGShape3D.OPERATION_SUBTRACTION)
	_add(wing, _saddle_cyl_x(Vector3(10.20, 12.04 + 34.0, -4.56), 34.0, 16.0, m_adobe), CSGShape3D.OPERATION_SUBTRACTION)
	_add(adobe, wing, CSGShape3D.OPERATION_UNION)

	# F. Carve Door, Window & Upper Alcove Recesses into the Adobe Walls:
	#    1) Front (+Z = 11.28) ground-floor entrance door recess (X = -3.80, Y [0.46 .. 6.20], W = 3.16)
	_add(adobe, _box(Vector3(-3.80, 3.33, 11.02), Vector3(3.16, 5.74, 0.90), m_adobe), CSGShape3D.OPERATION_SUBTRACTION)
	#    2) Front (+Z = 11.28) upper-left window recess (X = -10.50, Y [13.50 .. 17.55], W = 2.40)
	_add(adobe, _box(Vector3(-10.50, 15.525, 11.05), Vector3(2.40, 4.05, 0.80), m_adobe), CSGShape3D.OPERATION_SUBTRACTION)
	#    3) Front (+Z = 11.28) upper-center rounded alcove opening (X = -6.20, Y [15.55 .. 17.85], W = 2.15)
	_add(adobe, _alcove_cut_z(-6.20, 15.55, 2.15, 2.30, 10.45, 11.50, m_dark), CSGShape3D.OPERATION_SUBTRACTION)
	#    4) Right (+X = 4.10) upper terrace door recess (Z = -3.35, Y [11.18 .. 16.80], W = 2.35)
	_add(adobe, _box(Vector3(3.88, 13.99, -3.35), Vector3(0.85, 5.62, 2.35), m_adobe), CSGShape3D.OPERATION_SUBTRACTION)
	#    5) Right (+X = 16.28) 1-story wing window recess (Z = -4.50, Y [3.80 .. 7.80], W = 2.50)
	_add(adobe, _box(Vector3(16.06, 5.80, -4.50), Vector3(0.85, 4.00, 2.50), m_adobe), CSGShape3D.OPERATION_SUBTRACTION)
	#    6) Back (-Z = -9.40) twin ground-floor door recesses (X = -8.40 and -4.60, Y [0.35 .. 6.10], W = 2.35)
	for bx in [-8.40, -4.60]:
		_add(adobe, _box(Vector3(bx, 3.225, -9.15), Vector3(2.35, 5.75, 0.90), m_adobe), CSGShape3D.OPERATION_SUBTRACTION)
	#    7) Back (-Z = -9.40) upper-center rounded alcove opening (X = -7.20, Y [14.20 .. 16.40], W = 2.10)
	_add(adobe, _alcove_cut_z(-7.20, 14.20, 2.10, 2.20, -9.65, -8.60, m_dark), CSGShape3D.OPERATION_SUBTRACTION)
	#    8) Left (-X = -13.68) ground-floor & upper shuttered openings (Z = +0.80)
	_add(adobe, _box(Vector3(-13.45, 3.10, 0.80), Vector3(0.85, 5.40, 2.40), m_adobe), CSGShape3D.OPERATION_SUBTRACTION)
	_add(adobe, _box(Vector3(-13.45, 14.80, 0.80), Vector3(0.85, 4.00, 2.30), m_adobe), CSGShape3D.OPERATION_SUBTRACTION)

	_add(root, adobe, CSGShape3D.OPERATION_UNION)

	# ------------------------------------------------------------------
	# 2. Protruding Round Wooden Roof Beams (Vigas)
	# ------------------------------------------------------------------
	var vigas := CSGCombiner3D.new()
	vigas.name = "Vigas"

	# Front (+Z) upper tier (Y = 20.40) and mid tier (Y = 10.75)
	for vx in [-11.75, -7.25, -2.75, -1.25, 2.00]:
		_add(vigas, _viga_z(vx, 20.40, 10.50, 12.23, 0.34, m_timber), CSGShape3D.OPERATION_UNION)
	for vx in [-11.75, -7.25, -1.25, 1.85]:
		_add(vigas, _viga_z(vx, 10.75, 10.50, 12.05, 0.34, m_timber), CSGShape3D.OPERATION_UNION)

	# Back (-Z) upper tier (Y = 20.40) and mid tier across tower + wing (Y = 10.75)
	for vx in [-11.75, -7.25, -2.75, -1.25, 2.00]:
		_add(vigas, _viga_z(vx, 20.40, -10.38, -8.70, 0.34, m_timber), CSGShape3D.OPERATION_UNION)
	for vx in [-12.60, -7.25, -1.25, 0.35, 7.80, 13.30]:
		_add(vigas, _viga_z(vx, 10.75, -10.38, -8.70, 0.34, m_timber), CSGShape3D.OPERATION_UNION)

	# Left (-X) upper tier (Y = 20.40) and mid tier (Y = 10.75)
	for vz in [-5.80, 0.80, 7.40]:
		_add(vigas, _viga_x(-14.47, -12.90, 20.40, vz, 0.34, m_timber), CSGShape3D.OPERATION_UNION)
		_add(vigas, _viga_x(-14.47, -12.90, 10.75, vz, 0.34, m_timber), CSGShape3D.OPERATION_UNION)

	# Right (+X) 2-story upper vigas (Y = 20.40) and 1-story wing vigas (Y = 10.45)
	for vz in [-6.20, 7.20]:
		_add(vigas, _viga_x(3.40, 4.90, 20.40, vz, 0.34, m_timber), CSGShape3D.OPERATION_UNION)
	for vz in [-6.40, -4.50, -2.60]:
		_add(vigas, _viga_x(15.50, 17.02, 10.45, vz, 0.34, m_timber), CSGShape3D.OPERATION_UNION)

	_add(root, vigas, CSGShape3D.OPERATION_UNION)

	# ------------------------------------------------------------------
	# 3. Wooden Slatted Pergola / Awning on Stilts (X [4.05 .. 15.80], Z [0.20 .. 4.88])
	# ------------------------------------------------------------------
	var pergola := CSGCombiner3D.new()
	pergola.name = "Pergola"

	# Front header beam (Z = 4.56, Y = 6.62) & back ledger beam (Z = 0.42, Y = 6.84)
	_add(pergola, _box(Vector3(9.92, 6.62, 4.56), Vector3(11.75, 0.32, 0.34), m_timber_dark), CSGShape3D.OPERATION_UNION)
	_add(pergola, _box(Vector3(9.92, 6.84, 0.42), Vector3(11.75, 0.30, 0.28), m_timber_dark), CSGShape3D.OPERATION_UNION)

	# Three vertical wooden posts from ground (-SINK) up to Y = 6.62 at X = 4.65, 10.25, 15.45
	for px in [4.65, 10.25, 15.45]:
		var post := CSGCylinder3D.new()
		post.radius = 0.19
		post.height = 6.62 + SINK
		post.sides = 10
		post.position = Vector3(px, (6.62 - SINK) * 0.5, 4.56)
		post.material = m_timber_dark
		_add(pergola, post, CSGShape3D.OPERATION_UNION)
		# Post capital collar
		_add(pergola, _box(Vector3(px, 6.42, 4.56), Vector3(0.46, 0.18, 0.46), m_timber_dark), CSGShape3D.OPERATION_UNION)

	# Back wall post at X = 4.65, Z = 0.52 (seen in house_three_q1.png)
	var back_post := CSGCylinder3D.new()
	back_post.radius = 0.17
	back_post.height = 6.84 + SINK
	back_post.sides = 10
	back_post.position = Vector3(4.65, (6.84 - SINK) * 0.5, 0.52)
	back_post.material = m_timber_dark
	_add(pergola, back_post, CSGShape3D.OPERATION_UNION)

	# Diagonal knee braces on outer posts
	_add(pergola, _beam(Vector3(4.65, 5.15, 4.56), Vector3(6.05, 6.58, 4.56), 0.16, 0.16, m_timber_dark), CSGShape3D.OPERATION_UNION)
	_add(pergola, _beam(Vector3(15.45, 5.15, 4.56), Vector3(14.05, 6.58, 4.56), 0.16, 0.16, m_timber_dark), CSGShape3D.OPERATION_UNION)
	_add(pergola, _beam(Vector3(15.45, 5.25, 4.56), Vector3(15.45, 6.68, 3.15), 0.16, 0.16, m_timber_dark), CSGShape3D.OPERATION_UNION)
	_add(pergola, _beam(Vector3(4.65, 5.25, 4.56), Vector3(4.65, 6.68, 3.15), 0.16, 0.16, m_timber_dark), CSGShape3D.OPERATION_UNION)

	# Cross rafters & sloped plank canopy roof (Z [0.22 .. 4.88], X [4.05 .. 15.80])
	for rx in [4.55, 7.40, 10.25, 12.90, 15.55]:
		_add(pergola, _beam(Vector3(rx, 6.86, 0.25), Vector3(rx, 6.64, 4.85), 0.20, 0.22, m_timber_dark), CSGShape3D.OPERATION_UNION)
	_add(pergola, _beam(Vector3(9.92, 6.98, 0.22), Vector3(9.92, 6.76, 4.88), 11.78, 0.16, m_canopy, Vector3.RIGHT), CSGShape3D.OPERATION_UNION)

	_add(root, pergola, CSGShape3D.OPERATION_UNION)

	# ------------------------------------------------------------------
	# 4. Doors, Shuttered Windows, Timber Lintels & Stone Steps
	# ------------------------------------------------------------------
	# A. Front (+Z = 11.28) Ground-Floor Door, Stone Step & Heavy Timber Lintel
	_add(root, _box(Vector3(-3.80, 0.015, 11.92), Vector3(4.10, 0.73, 1.48), m_stone), CSGShape3D.OPERATION_UNION)
	_add(root, _box(Vector3(-3.80, 0.43, 11.96), Vector3(4.26, 0.12, 1.56), m_stone), CSGShape3D.OPERATION_UNION)
	# Projecting timber lintel
	_add(root, _box(Vector3(-3.80, 6.36, 11.12), Vector3(4.10, 0.36, 0.72), m_timber_dark), CSGShape3D.OPERATION_UNION)
	# Door frame & plank leaf with cross-buck / Z-brace timbers
	_add(root, _box(Vector3(-3.80, 3.33, 10.72), Vector3(3.16, 5.74, 0.18), m_timber_dark), CSGShape3D.OPERATION_UNION)
	_add(root, _box(Vector3(-3.80, 3.33, 10.82), Vector3(2.76, 5.42, 0.12), m_door), CSGShape3D.OPERATION_UNION)
	for ry in [1.15, 3.30, 5.45]:
		_add(root, _box(Vector3(-3.80, ry, 10.91), Vector3(2.78, 0.22, 0.08), m_timber_dark), CSGShape3D.OPERATION_UNION)
	_add(root, _beam(Vector3(-5.05, 1.25, 10.91), Vector3(-2.55, 3.20, 10.91), 0.18, 0.08, m_timber_dark, Vector3(-0.6, 0.8, 0).normalized()), CSGShape3D.OPERATION_UNION)

	# B. Front (+Z = 11.28) Upper-Left Shuttered Window (X = -10.50, Y [13.50 .. 17.55])
	_add(root, _box(Vector3(-10.50, 17.70, 11.10), Vector3(3.10, 0.32, 0.66), m_timber_dark), CSGShape3D.OPERATION_UNION)
	_add(root, _box(Vector3(-10.50, 13.40, 11.12), Vector3(2.75, 0.22, 0.58), m_stone), CSGShape3D.OPERATION_UNION)
	_add(root, _box(Vector3(-10.50, 15.525, 10.82), Vector3(2.40, 4.05, 0.16), m_timber_dark), CSGShape3D.OPERATION_UNION)
	_add(root, _box(Vector3(-10.50, 15.525, 10.92), Vector3(2.04, 3.68, 0.10), m_shutter), CSGShape3D.OPERATION_UNION)
	for ry in [14.35, 15.525, 16.70]:
		_add(root, _box(Vector3(-10.50, ry, 10.99), Vector3(2.08, 0.16, 0.06), m_timber_dark), CSGShape3D.OPERATION_UNION)

	# C. Right (+X = 4.10) Upper Terrace Door (Z = -3.35, Y [11.18 .. 16.80])
	_add(root, _box(Vector3(3.92, 16.96, -3.35), Vector3(0.68, 0.32, 3.05), m_timber_dark), CSGShape3D.OPERATION_UNION)
	_add(root, _box(Vector3(3.62, 13.99, -3.35), Vector3(0.16, 5.62, 2.35), m_timber_dark), CSGShape3D.OPERATION_UNION)
	_add(root, _box(Vector3(3.72, 13.99, -3.35), Vector3(0.10, 5.30, 1.98), m_door), CSGShape3D.OPERATION_UNION)
	for ry in [12.10, 13.99, 15.88]:
		_add(root, _box(Vector3(3.79, ry, -3.35), Vector3(0.06, 0.18, 2.02), m_timber_dark), CSGShape3D.OPERATION_UNION)

	# D. Right (+X = 16.28) 1-Story Wing Window (Z = -4.50, Y [3.80 .. 7.80])
	_add(root, _box(Vector3(16.12, 7.95, -4.50), Vector3(0.64, 0.30, 3.15), m_timber_dark), CSGShape3D.OPERATION_UNION)
	_add(root, _box(Vector3(16.14, 3.70, -4.50), Vector3(0.56, 0.22, 2.85), m_stone), CSGShape3D.OPERATION_UNION)
	_add(root, _box(Vector3(15.82, 5.80, -4.50), Vector3(0.16, 4.00, 2.50), m_timber_dark), CSGShape3D.OPERATION_UNION)
	_add(root, _box(Vector3(15.92, 5.80, -4.50), Vector3(0.10, 3.64, 2.12), m_shutter), CSGShape3D.OPERATION_UNION)
	_add(root, _box(Vector3(15.99, 5.80, -4.50), Vector3(0.06, 0.18, 2.16), m_timber_dark), CSGShape3D.OPERATION_UNION)

	# E. Back (-Z = -9.40) Twin Ground-Floor Doors (X = -8.40 and -4.60, Y [0.35 .. 6.10])
	for bx in [-8.40, -4.60]:
		_add(root, _box(Vector3(bx, -0.015, -9.85), Vector3(2.85, 0.67, 1.10), m_stone), CSGShape3D.OPERATION_UNION)
		_add(root, _box(Vector3(bx, 6.26, -9.24), Vector3(3.05, 0.32, 0.68), m_timber_dark), CSGShape3D.OPERATION_UNION)
		_add(root, _box(Vector3(bx, 3.225, -8.88), Vector3(2.35, 5.75, 0.16), m_timber_dark), CSGShape3D.OPERATION_UNION)
		_add(root, _box(Vector3(bx, 3.225, -8.98), Vector3(1.98, 5.42, 0.10), m_door), CSGShape3D.OPERATION_UNION)
		for ry in [1.20, 3.225, 5.25]:
			_add(root, _box(Vector3(bx, ry, -9.05), Vector3(2.02, 0.18, 0.06), m_timber_dark), CSGShape3D.OPERATION_UNION)

	# F. Left (-X = -13.68) Ground-Floor & Upper Shuttered Windows/Doors (Z = +0.80)
	for pair in [[3.10, 5.40, 2.40], [14.80, 4.00, 2.30]]:
		var cy: float = pair[0]
		var h: float = pair[1]
		var w: float = pair[2]
		_add(root, _box(Vector3(-13.52, cy + h * 0.5 + 0.15, 0.80), Vector3(0.64, 0.30, w + 0.65), m_timber_dark), CSGShape3D.OPERATION_UNION)
		_add(root, _box(Vector3(-13.20, cy, 0.80), Vector3(0.16, h, w), m_timber_dark), CSGShape3D.OPERATION_UNION)
		_add(root, _box(Vector3(-13.30, cy, 0.80), Vector3(0.10, h - 0.36, w - 0.36), m_shutter), CSGShape3D.OPERATION_UNION)
		_add(root, _box(Vector3(-13.37, cy, 0.80), Vector3(0.06, 0.18, w - 0.32), m_timber_dark), CSGShape3D.OPERATION_UNION)

	return root


static func _rounded_rect(x0: float, z0: float, x1: float, z1: float, r: float, segs: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [
		[Vector2(x1 - r, z1 - r), 0.0],
		[Vector2(x0 + r, z1 - r), PI * 0.5],
		[Vector2(x0 + r, z0 + r), PI],
		[Vector2(x1 - r, z0 + r), PI * 1.5],
	]
	for c in corners:
		var center: Vector2 = c[0]
		var a0: float = c[1]
		for s in range(segs + 1):
			var a := a0 + (PI * 0.5) * float(s) / float(segs)
			pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts


static func _extrude_y(poly_xz: PackedVector2Array, y0: float, y1: float, mat: Material) -> CSGPolygon3D:
	var pts := PackedVector2Array()
	for v in poly_xz:
		pts.append(Vector2(v.x, -v.y))
	var p := CSGPolygon3D.new()
	p.polygon = pts
	p.depth = y1 - y0
	p.rotation_degrees.x = -90.0
	p.position = Vector3(0.0, y1, 0.0)
	p.material = mat
	return p


static func _saddle_cyl_z(at: Vector3, r: float, length: float, mat: Material) -> CSGCylinder3D:
	var cyl := CSGCylinder3D.new()
	cyl.radius = r
	cyl.height = length
	cyl.sides = 48
	cyl.rotation_degrees.x = 90.0
	cyl.position = at
	cyl.material = mat
	return cyl


static func _saddle_cyl_x(at: Vector3, r: float, length: float, mat: Material) -> CSGCylinder3D:
	var cyl := CSGCylinder3D.new()
	cyl.radius = r
	cyl.height = length
	cyl.sides = 48
	cyl.rotation_degrees.z = 90.0
	cyl.position = at
	cyl.material = mat
	return cyl


static func _alcove_cut_z(cx: float, y0: float, w: float, h: float, z0: float, z1: float, mat: Material) -> CSGPolygon3D:
	var pts := _rounded_rect(cx - w * 0.5, y0, cx + w * 0.5, y0 + h, 0.45, 5)
	var p := CSGPolygon3D.new()
	p.polygon = pts
	p.depth = z1 - z0
	p.position = Vector3(0.0, 0.0, z1)
	p.material = mat
	return p


static func _viga_z(x: float, y: float, z0: float, z1: float, r: float, mat: Material) -> CSGCylinder3D:
	var cyl := CSGCylinder3D.new()
	cyl.radius = r
	cyl.height = z1 - z0
	cyl.sides = 10
	cyl.rotation_degrees.x = 90.0
	cyl.position = Vector3(x, y, (z0 + z1) * 0.5)
	cyl.material = mat
	return cyl


static func _viga_x(x0: float, x1: float, y: float, z: float, r: float, mat: Material) -> CSGCylinder3D:
	var cyl := CSGCylinder3D.new()
	cyl.radius = r
	cyl.height = x1 - x0
	cyl.sides = 10
	cyl.rotation_degrees.z = 90.0
	cyl.position = Vector3((x0 + x1) * 0.5, y, z)
	cyl.material = mat
	return cyl


static func _box(at: Vector3, size: Vector3, mat: Material, b := Basis()) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.size = size
	box.transform = Transform3D(b, at)
	box.material = mat
	return box


static func _beam(a: Vector3, b: Vector3, w: float, t: float, mat: Material, side := Vector3.ZERO) -> CSGBox3D:
	var d := b - a
	var length := d.length()
	var z := d / maxf(length, 1e-4)
	var x := side
	if x.length_squared() < 1e-6 or absf(x.normalized().dot(z)) > 0.98:
		x = Vector3.UP.cross(z)
		if x.length_squared() < 1e-6:
			x = Vector3.RIGHT
	x = (x - z * x.dot(z)).normalized()
	var y := z.cross(x).normalized()
	return _box((a + b) * 0.5, Vector3(w, t, length), mat, Basis(x, y, z))


static func _add(parent: CSGShape3D, child: CSGShape3D, op: int) -> void:
	child.operation = op if parent.get_child_count() > 0 else CSGShape3D.OPERATION_UNION
	parent.add_child(child)


static func _mat(key: String, col: Color) -> StandardMaterial3D:
	var tag := "%s:%s" % [key, col.to_html(false)]
	if not _placeholder_mats.has(tag):
		var m := StandardMaterial3D.new()
		m.resource_name = tag
		m.albedo_color = col
		_placeholder_mats[tag] = m
	return _placeholder_mats[tag]


static func _final_material(key: String) -> Material:
	if _final_mats.has(key):
		return _final_mats[key]
	var m: Material
	match key:
		"adobe":
			var sm := ShaderMaterial.new()
			sm.shader = load("res://hut_masonry.gdshader")
			sm.set_shader_parameter("style", 3)
			m = sm
		"stucco":
			var sm := ShaderMaterial.new()
			sm.shader = load("res://hut_masonry.gdshader")
			sm.set_shader_parameter("style", 4)
			m = sm
		"stone":
			var sm := ShaderMaterial.new()
			sm.shader = load("res://hut_masonry.gdshader")
			sm.set_shader_parameter("style", 0)
			m = sm
		"wood_v":
			var sm := ShaderMaterial.new()
			sm.shader = load("res://hut_wood.gdshader")
			sm.set_shader_parameter("style", 0)
			sm.set_shader_parameter("weathering", 0.55)
			m = sm
		"wood_h":
			var sm := ShaderMaterial.new()
			sm.shader = load("res://hut_wood.gdshader")
			sm.set_shader_parameter("style", 1)
			sm.set_shader_parameter("weathering", 0.55)
			m = sm
		"timber":
			var sm := ShaderMaterial.new()
			sm.shader = load("res://hut_wood.gdshader")
			sm.set_shader_parameter("style", 2)
			sm.set_shader_parameter("weathering", 0.65)
			m = sm
		"dark":
			var sm := StandardMaterial3D.new()
			sm.vertex_color_use_as_albedo = true
			sm.roughness = 0.95
			m = sm
		_:
			var sm := StandardMaterial3D.new()
			sm.vertex_color_use_as_albedo = true
			m = sm
	_final_mats[key] = m
	return m


## Bakes the CSG tree into an ArrayMesh with world-metre UVs, vertex colours, and tangents.
static func bake(root: CSGShape3D) -> ArrayMesh:
	var src: ArrayMesh = root.bake_static_mesh()
	var out := ArrayMesh.new()
	if src == null:
		push_error("AdobeHouseCSG: CSG has not built its mesh yet")
		return out
	var tools := {}
	var order: Array[String] = []
	for si in range(src.get_surface_count()):
		var mat := src.surface_get_material(si)
		var tag := mat.resource_name.split(":") if mat and mat.resource_name.contains(":") else PackedStringArray(["adobe", "d6bd99"])
		var key: String = tag[0]
		var col := Color(tag[1])
		if not tools.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[key] = st
			order.append(key)
		var st: SurfaceTool = tools[key]
		var arr := src.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := idx.size() if not idx.is_empty() else v.size()
		for t in range(0, count - 2, 3):
			var ids := [t, t + 1, t + 2] if idx.is_empty() else [idx[t], idx[t + 1], idx[t + 2]]
			var a: Vector3 = v[ids[0]]
			var raw_n := (v[ids[2]] - a).cross(v[ids[1]] - a)
			var fn := raw_n.abs()
			var unit_n := raw_n.normalized().abs()
			var flat_fade := 1.0 if (unit_n.y < 0.25 and minf(unit_n.x, unit_n.z) < 0.15) else 0.0
			for i in ids:
				var p: Vector3 = v[i]
				var uv: Vector2
				if fn.z >= fn.x and fn.z >= fn.y:
					uv = Vector2(p.x, maxf(p.y, 0.0))
				elif fn.x >= fn.y:
					uv = Vector2(p.z, maxf(p.y, 0.0))
				else:
					uv = Vector2(p.x, p.z)
				var dx_c := minf(minf(absf(p.x - (-13.68)), absf(p.x - 4.10)), absf(p.x - 16.28))
				var dz_c := minf(minf(absf(p.z - (-9.40)), absf(p.z - 0.30)), absf(p.z - 11.28))
				var d_corner := minf(dx_c, dz_c) if (dx_c < 2.2 and dz_c < 2.2) else 2.2
				var corner_fade := clampf((d_corner - 1.35) / 0.85, 0.0, 1.0)
				var height_fade := clampf((19.2 - p.y) / 1.5, 0.0, 1.0) * clampf((p.y - 1.2) / 1.2, 0.0, 1.0)
				st.set_color(Color(col.r, col.g, col.b, corner_fade * height_fade * flat_fade))
				st.set_normal(n[i])
				st.set_uv(uv)
				st.add_vertex(p)
	for key in order:
		var st: SurfaceTool = tools[key]
		st.generate_tangents()
		st.index()
		st.commit(out)
		out.surface_set_material(out.get_surface_count() - 1, _final_material(key))
	return out
