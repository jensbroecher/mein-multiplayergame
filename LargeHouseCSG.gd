extends RefCounted
## Canyon Chasm's large Mediterranean stucco house (LargeHouse), modelled in CSG at life size
## (metres, y up, ground at y = 0, front facing +z toward the road):
## A 37.2m x 37.8m whitewashed villa under a Spanish terracotta barrel-tile gable roof, with a
## protruding left cross-gable entrance bay (arched oak door, limestone step, two wrought-iron coach
## lanterns, and a quatrefoil gable vent), a recessed front veranda on the right (double French doors,
## casement window, and segmental-arch multi-pane window), a lower left side shed wing with its own
## window, and a whitewashed stucco chimney with a rain cap.
##
## It replaces the 500k-triangle Hunyuan FBX (models/desert/2f1728e226824507fc3188405c2c7935.fbx,
## imported at scale 45) and keeps its exact frame: LargeHouse in CanyonChasmLevel.tscn keeps its
## position and rotation, with scale 1 instead of 45.
## regenerate_chasm_houses.gd builds the tree (`build`), lets the CSG update, and bakes it (`bake`)
## into generated/large_house.res, which LargeHouse.tscn draws; the level holds no runtime CSG.

const SINK := 2.5

const COL_STUCCO := Color(0.95, 0.94, 0.92)
const COL_SOFFIT := Color(0.86, 0.85, 0.83)
const COL_STONE := Color(0.84, 0.80, 0.72)
const COL_TILE := Color(0.70, 0.49, 0.37)
const COL_TILE_TRIM := Color(0.72, 0.47, 0.34)
const COL_DOOR := Color(0.42, 0.25, 0.14)
const COL_FRAME := Color(0.24, 0.15, 0.09)
const COL_IRON := Color(0.11, 0.12, 0.13)
const COL_GLASS := Color(0.08, 0.11, 0.14)
const COL_LANTERN_GLASS := Color(0.76, 0.80, 0.84)

static var _placeholder_mats := {}
static var _final_mats := {}


static func build() -> CSGCombiner3D:
	var root := CSGCombiner3D.new()
	root.name = "LargeHouseCSG"

	var m_stucco := _mat("stucco", COL_STUCCO)
	var m_soffit := _mat("stucco", COL_SOFFIT)
	var m_stone := _mat("stucco", COL_STONE)
	var m_roof_z := _mat("roof_z", COL_TILE)
	var m_roof_x := _mat("roof_x", COL_TILE)
	var m_trim := _mat("timber", COL_TILE_TRIM)
	var m_door := _mat("wood_v", COL_DOOR)
	var m_frame := _mat("timber", COL_FRAME)
	var m_iron := _mat("iron", COL_IRON)
	var m_glass := _mat("glass", COL_GLASS)
	var m_lglass := _mat("iron", COL_LANTERN_GLASS)

	# ------------------------------------------------------------------
	# 1. Stucco Walls (unioned and carved in one combiner so interior cuts drop out)
	# ------------------------------------------------------------------
	var walls := CSGCombiner3D.new()
	walls.name = "StuccoWalls"

	# A. Main gabled house body: X [-14.8 .. +18.55], Z [-19.9 .. +16.1]
	# Extruded along X: profile in (Z, Y) has eaves at Y=7.65 and ridge at Z=-1.7, Y=12.10.
	var main_prof := PackedVector2Array([
		Vector2(-19.90, -SINK),
		Vector2(-19.90, 7.65),
		Vector2(-1.70, 12.10),
		Vector2(16.10, 7.65),
		Vector2(16.10, -SINK),
	])
	_add(walls, _extrude_x(main_prof, -14.80, 18.55, m_stucco), CSGShape3D.OPERATION_UNION)

	# B. Protruding left entrance cross-gable bay: X [-14.80 .. -1.40], Z [-1.70 .. +16.45]
	# Extruded along Z: profile in (X, Y) has eaves at Y=7.65 and ridge at X=-8.10, Y=10.45.
	var front_gable_prof := PackedVector2Array([
		Vector2(-14.80, -SINK),
		Vector2(-14.80, 7.65),
		Vector2(-8.10, 10.45),
		Vector2(-1.40, 7.65),
		Vector2(-1.40, -SINK),
	])
	_add(walls, _extrude_z(front_gable_prof, -1.70, 16.45, m_stucco), CSGShape3D.OPERATION_UNION)

	# C. Left side shed wing: X [-18.20 .. -14.70], Z [-19.90 .. +12.40]
	var shed_prof := PackedVector2Array([
		Vector2(-18.20, -SINK),
		Vector2(-18.20, 6.20),
		Vector2(-14.70, 7.20),
		Vector2(-14.70, -SINK),
	])
	_add(walls, _extrude_z(shed_prof, -19.90, 12.40, m_stucco), CSGShape3D.OPERATION_UNION)

	# D. Whitewashed stucco chimney on left (-X) side: X [-17.98 .. -14.92], Z [-3.25 .. +1.15]
	_add(walls, _box(Vector3(-16.45, (13.48 - SINK) * 0.5, -1.05), Vector3(3.06, 13.48 + SINK, 4.40), m_stucco), CSGShape3D.OPERATION_UNION)
	# Subtle chimney crown collar
	_add(walls, _box(Vector3(-16.45, 13.42, -1.05), Vector3(3.22, 0.22, 4.56), m_stucco), CSGShape3D.OPERATION_UNION)

	# E. Carve recessed front veranda / porch on +Z right side: X [-1.40 .. +17.35], Y [-SINK-0.1 .. 7.12], Z [+7.95 .. +16.60]
	_add(walls, _box(Vector3(7.975, (7.12 - SINK - 0.1) * 0.5, 12.275), Vector3(18.75, 7.12 + SINK + 0.1, 8.65), m_soffit), CSGShape3D.OPERATION_SUBTRACTION)

	# F. Carve arched front doorway recess in left gable bay: centered at X = -7.95, Z = +16.45
	var arch_cut := _arched_prism(-7.95, 0.46, 3.44, 4.30, 15.82, 16.70, 16, m_stucco)
	_add(walls, arch_cut, CSGShape3D.OPERATION_SUBTRACTION)

	# G. Carve quatrefoil / keyhole vent above arched door: centered at X = -7.95, Y = 8.45, Z = +16.45
	_add(walls, _quatrefoil_cut(Vector3(-7.95, 8.45, 16.30), 0.70, m_stucco), CSGShape3D.OPERATION_SUBTRACTION)

	# H. Carve small circular attic vent on -X upper gable wall beside chimney (X = -14.80, Y = 9.05, Z = -6.20)
	var side_vent := CSGCylinder3D.new()
	side_vent.radius = 0.28
	side_vent.height = 0.70
	side_vent.sides = 14
	side_vent.rotation_degrees.z = 90.0
	side_vent.position = Vector3(-14.65, 9.05, -6.20)
	side_vent.material = m_iron
	_add(walls, side_vent, CSGShape3D.OPERATION_SUBTRACTION)

	# I. Carve porch back wall recesses (Z = 7.95):
	#    1) Double French doors (X = 4.10, Y [0.22 .. 5.38], W = 3.20)
	_add(walls, _box(Vector3(4.10, 2.80, 7.80), Vector3(3.20, 5.16, 0.70), m_stucco), CSGShape3D.OPERATION_SUBTRACTION)
	#    2) Middle casement window (X = 9.85, Y [1.80 .. 5.25], W = 2.65)
	_add(walls, _box(Vector3(9.85, 3.525, 7.80), Vector3(2.65, 3.45, 0.70), m_stucco), CSGShape3D.OPERATION_SUBTRACTION)
	#    3) Right segmental-arched multi-pane window (X = 14.80, Y [1.70 .. 5.35], W = 3.05)
	_add(walls, _segmental_arch_prism(14.80, 1.70, 3.05, 3.25, 0.40, 7.45, 8.20, 12, m_stucco), CSGShape3D.OPERATION_SUBTRACTION)

	# J. Carve left shed wing front window recess (X = -16.50, Y [2.25 .. 5.10], Z = 12.40, W = 1.65)
	_add(walls, _box(Vector3(-16.50, 3.675, 12.25), Vector3(1.65, 2.85, 0.70), m_stucco), CSGShape3D.OPERATION_SUBTRACTION)

	_add(root, walls, CSGShape3D.OPERATION_UNION)

	# Chimney pot and rain cap on top of the chimney (X = -16.45, Z = -1.05, Y = 13.50..13.94)
	var pot := CSGCylinder3D.new()
	pot.radius = 0.56
	pot.height = 0.34
	pot.sides = 12
	pot.position = Vector3(-16.45, 13.65, -1.05)
	pot.material = m_stucco
	_add(root, pot, CSGShape3D.OPERATION_UNION)
	var pot_cap := CSGCylinder3D.new()
	pot_cap.radius = 0.70
	pot_cap.height = 0.12
	pot_cap.sides = 12
	pot_cap.position = Vector3(-16.45, 13.88, -1.05)
	pot_cap.material = m_stucco
	_add(root, pot_cap, CSGShape3D.OPERATION_UNION)

	# ------------------------------------------------------------------
	# 2. Spanish Terracotta Barrel-Tile Roofs & Ridge / Rake Trim
	# ------------------------------------------------------------------
	var roofs := CSGCombiner3D.new()
	roofs.name = "TerracottaRoofs"

	# A. Main Gable Roof (ridge at Z = -1.70, Y = 12.32; rear eave Z = -20.17, Y = 7.55; front eave Z = +16.48, Y = 7.55)
	# Rear slope and right-side front slope span X [-15.10 .. +18.82].
	var main_roof_prof := PackedVector2Array([
		Vector2(-20.17, 7.45),
		Vector2(-20.17, 7.82),
		Vector2(-1.70, 12.42),
		Vector2(16.48, 7.82),
		Vector2(16.48, 7.45),
		Vector2(-1.70, 12.02),
	])
	_add(roofs, _extrude_x(main_roof_prof, -15.10, 18.82, m_roof_z), CSGShape3D.OPERATION_UNION)

	# Trim away the portion of the main roof that sits underneath the front cross-gable roof
	# before unioning the cross-gable roof on top, so they meet cleanly along the two diagonal valleys.
	var cross_under_prof := PackedVector2Array([
		Vector2(-15.16, 0.0),
		Vector2(-15.16, 7.62),
		Vector2(-8.10, 10.60),
		Vector2(-1.04, 7.62),
		Vector2(-1.04, 0.0),
	])
	_add(roofs, _extrude_z(cross_under_prof, -1.70, 16.90, m_stucco), CSGShape3D.OPERATION_SUBTRACTION)

	# B. Left Entrance Cross-Gable Roof (ridge at X = -8.10, Y = 10.76; eaves at X = -15.15 and -1.05, Y = 7.60)
	# Runs from Z = +4.70 (merging inside main roof front slope) forward to Z = +16.82.
	var cross_roof_prof := PackedVector2Array([
		Vector2(-15.15, 7.42),
		Vector2(-15.15, 7.78),
		Vector2(-8.10, 10.76),
		Vector2(-1.05, 7.78),
		Vector2(-1.05, 7.42),
		Vector2(-8.10, 10.36),
	])
	_add(roofs, _extrude_z(cross_roof_prof, 4.70, 16.82, m_roof_x), CSGShape3D.OPERATION_UNION)

	# C. Left Side Shed Wing Roof (X [-18.43 .. -14.70], Z [-20.15 .. +12.68])
	var shed_roof_prof := PackedVector2Array([
		Vector2(-18.43, 6.08),
		Vector2(-18.43, 6.40),
		Vector2(-14.70, 7.40),
		Vector2(-14.70, 7.08),
	])
	_add(roofs, _extrude_z(shed_roof_prof, -20.15, 12.68, m_roof_x), CSGShape3D.OPERATION_UNION)

	# Keep chimney clear of the shed/main roof tiles
	_add(roofs, _box(Vector3(-16.45, 10.0, -1.05), Vector3(3.08, 8.0, 4.42), m_stucco), CSGShape3D.OPERATION_SUBTRACTION)

	_add(root, roofs, CSGShape3D.OPERATION_UNION)

	# D. Raised Terracotta Ridge Caps & Gable Rake Trim
	# Main ridge cap along X (Z = -1.70, Y = 12.44)
	_add(root, _beam(Vector3(-15.12, 12.44, -1.70), Vector3(18.84, 12.44, -1.70), 0.46, 0.28, m_trim), CSGShape3D.OPERATION_UNION)
	# Cross-gable ridge cap along Z (X = -8.10, Y = 10.78, Z [+4.85 .. +16.86])
	_add(root, _beam(Vector3(-8.10, 10.78, 4.85), Vector3(-8.10, 10.78, 16.86), 0.44, 0.26, m_trim), CSGShape3D.OPERATION_UNION)
	# Front cross-gable rake trim boards
	_add(root, _beam(Vector3(-15.15, 7.62, 16.68), Vector3(-8.10, 10.72, 16.68), 0.26, 0.34, m_trim, Vector3.BACK), CSGShape3D.OPERATION_UNION)
	_add(root, _beam(Vector3(-8.10, 10.72, 16.68), Vector3(-1.05, 7.62, 16.68), 0.26, 0.34, m_trim, Vector3.BACK), CSGShape3D.OPERATION_UNION)
	# Right gable (+X = 18.70) rake trim boards
	_add(root, _beam(Vector3(18.70, 7.65, -20.17), Vector3(18.70, 12.40, -1.70), 0.26, 0.34, m_trim, Vector3.RIGHT), CSGShape3D.OPERATION_UNION)
	_add(root, _beam(Vector3(18.70, 12.40, -1.70), Vector3(18.70, 7.65, 16.48), 0.26, 0.34, m_trim, Vector3.RIGHT), CSGShape3D.OPERATION_UNION)
	# Left shed outer edge trim (-X = -18.35)
	_add(root, _beam(Vector3(-18.35, 6.26, -20.15), Vector3(-18.35, 6.26, 12.68), 0.28, 0.28, m_trim), CSGShape3D.OPERATION_UNION)

	# ------------------------------------------------------------------
	# 3. Doors, Windows, Stone Step, Quatrefoil Backing & Coach Lanterns
	# ------------------------------------------------------------------
	# A. Limestone Front Step under arched door: X [-10.20 .. -5.70], Y [-0.35 .. 0.48], Z [16.30 .. 17.70]
	_add(root, _box(Vector3(-7.95, 0.015, 16.96), Vector3(4.42, 0.73, 1.32), m_stone), CSGShape3D.OPERATION_UNION)
	_add(root, _box(Vector3(-7.95, 0.43, 17.00), Vector3(4.56, 0.12, 1.40), m_stone), CSGShape3D.OPERATION_UNION)

	# B. Arched Oak Front Door + Frame + Wrought-Iron Hinges & Ring Handle (at X = -7.95, Z = 15.96)
	_add(root, _arched_prism(-7.95, 0.46, 3.44, 4.30, 15.80, 15.98, 16, m_frame), CSGShape3D.OPERATION_UNION)
	_add(root, _arched_prism(-7.95, 0.48, 3.08, 4.12, 15.92, 16.06, 16, m_door), CSGShape3D.OPERATION_UNION)
	# Vertical plank battens & iron strap hinges on the arched door
	for px in [-9.0, -8.3, -7.6, -6.9]:
		_add(root, _box(Vector3(px, 2.85, 16.08), Vector3(0.06, 4.55, 0.04), m_frame), CSGShape3D.OPERATION_UNION)
	for hy in [1.45, 3.85]:
		_add(root, _box(Vector3(-8.95, hy, 16.10), Vector3(0.95, 0.11, 0.05), m_iron), CSGShape3D.OPERATION_UNION)
	# Iron latch plate & ring handle on right of door
	_add(root, _box(Vector3(-6.75, 2.55, 16.10), Vector3(0.16, 0.42, 0.05), m_iron), CSGShape3D.OPERATION_UNION)
	_add(root, _box(Vector3(-6.75, 2.45, 16.15), Vector3(0.22, 0.22, 0.06), m_iron), CSGShape3D.OPERATION_UNION)

	# C. Quatrefoil Vent Dark Backing & Louver Bars (X = -7.95, Y = 8.45, Z = 16.05)
	_add(root, _box(Vector3(-7.95, 8.45, 16.02), Vector3(1.60, 1.60, 0.12), m_iron), CSGShape3D.OPERATION_UNION)
	for ly in [8.15, 8.45, 8.75]:
		_add(root, _box(Vector3(-7.95, ly, 16.14), Vector3(1.10, 0.07, 0.08), m_frame), CSGShape3D.OPERATION_UNION)

	# D. Two Wrought-Iron Coach Lanterns flanking the Arched Door (X = -11.10 and -4.80, Y = 5.10, Z = 16.45..17.08)
	for lx in [-11.10, -4.80]:
		_build_coach_lantern(root, Vector3(lx, 5.10, 16.45), m_iron, m_lglass)

	# E. Porch Back Wall: Double French Doors (X = 4.10, Y [0.22 .. 5.38], Z = 7.62)
	_add(root, _box(Vector3(4.10, 2.80, 7.56), Vector3(3.24, 5.20, 0.14), m_frame), CSGShape3D.OPERATION_UNION)
	for sx in [-0.72, 0.72]:
		_add(root, _box(Vector3(4.10 + sx, 2.82, 7.64), Vector3(1.16, 4.65, 0.08), m_glass), CSGShape3D.OPERATION_UNION)
		for ry in [1.4, 2.8, 4.2]:
			_add(root, _box(Vector3(4.10 + sx, ry, 7.69), Vector3(1.20, 0.07, 0.05), m_frame), CSGShape3D.OPERATION_UNION)
	_add(root, _box(Vector3(4.10, 2.80, 7.70), Vector3(0.16, 5.05, 0.08), m_frame), CSGShape3D.OPERATION_UNION)

	# F. Porch Back Wall: Middle Casement Window (X = 9.85, Y [1.80 .. 5.25], Z = 7.62)
	_add(root, _box(Vector3(9.85, 1.74, 7.82), Vector3(2.88, 0.16, 0.44), m_stone), CSGShape3D.OPERATION_UNION)
	_add(root, _box(Vector3(9.85, 3.525, 7.56), Vector3(2.68, 3.48, 0.14), m_frame), CSGShape3D.OPERATION_UNION)
	_add(root, _box(Vector3(9.85, 3.525, 7.64), Vector3(2.32, 3.12, 0.08), m_glass), CSGShape3D.OPERATION_UNION)
	_add(root, _box(Vector3(9.85, 3.525, 7.69), Vector3(0.12, 3.20, 0.06), m_frame), CSGShape3D.OPERATION_UNION)
	for ry in [2.68, 3.525, 4.37]:
		_add(root, _box(Vector3(9.85, ry, 7.69), Vector3(2.36, 0.07, 0.05), m_frame), CSGShape3D.OPERATION_UNION)

	# G. Porch Back Wall: Right Segmental-Arched Multi-Pane Window (X = 14.80, Y [1.70 .. 5.35], Z = 7.62)
	_add(root, _box(Vector3(14.80, 1.64, 7.82), Vector3(3.28, 0.16, 0.44), m_stone), CSGShape3D.OPERATION_UNION)
	_add(root, _segmental_arch_prism(14.80, 1.70, 3.08, 3.25, 0.40, 7.48, 7.64, 12, m_frame), CSGShape3D.OPERATION_UNION)
	_add(root, _segmental_arch_prism(14.80, 1.84, 2.74, 2.98, 0.36, 7.58, 7.68, 12, m_glass), CSGShape3D.OPERATION_UNION)
	for mx in [13.90, 14.80, 15.70]:
		_add(root, _box(Vector3(mx, 3.45, 7.70), Vector3(0.09, 3.30, 0.06), m_frame), CSGShape3D.OPERATION_UNION)
	for my in [2.62, 3.52, 4.42]:
		_add(root, _box(Vector3(14.80, my, 7.70), Vector3(2.78, 0.08, 0.06), m_frame), CSGShape3D.OPERATION_UNION)

	# H. Left Shed Wing Front Window (X = -16.50, Y [2.25 .. 5.10], Z = 12.06)
	_add(root, _box(Vector3(-16.50, 2.19, 12.28), Vector3(1.86, 0.15, 0.42), m_stone), CSGShape3D.OPERATION_UNION)
	_add(root, _box(Vector3(-16.50, 3.675, 12.00), Vector3(1.68, 2.88, 0.14), m_frame), CSGShape3D.OPERATION_UNION)
	_add(root, _box(Vector3(-16.50, 3.675, 12.08), Vector3(1.36, 2.54, 0.08), m_glass), CSGShape3D.OPERATION_UNION)
	_add(root, _box(Vector3(-16.50, 3.675, 12.13), Vector3(0.09, 2.58, 0.05), m_frame), CSGShape3D.OPERATION_UNION)
	for my in [3.05, 3.675, 4.30]:
		_add(root, _box(Vector3(-16.50, my, 12.13), Vector3(1.40, 0.07, 0.05), m_frame), CSGShape3D.OPERATION_UNION)

	return root


static func _build_coach_lantern(parent: CSGShape3D, wall_pt: Vector3, m_iron: Material, m_glass: Material) -> void:
	# Wall backplate
	_add(parent, _box(wall_pt + Vector3(0, 0, 0.04), Vector3(0.42, 1.15, 0.08), m_iron), CSGShape3D.OPERATION_UNION)
	# Bracket arm
	_add(parent, _box(wall_pt + Vector3(0, -0.18, 0.22), Vector3(0.12, 0.14, 0.42), m_iron), CSGShape3D.OPERATION_UNION)
	# Lantern cage body + warm glass core
	var lc := wall_pt + Vector3(0, 0.05, 0.38)
	_add(parent, _box(lc, Vector3(0.46, 0.72, 0.42), m_glass), CSGShape3D.OPERATION_UNION)
	# Cage top & bottom collars + corner bars
	_add(parent, _box(lc + Vector3(0, 0.40, 0), Vector3(0.62, 0.10, 0.56), m_iron), CSGShape3D.OPERATION_UNION)
	_add(parent, _box(lc + Vector3(0, 0.52, 0), Vector3(0.38, 0.16, 0.36), m_iron), CSGShape3D.OPERATION_UNION)
	_add(parent, _box(lc + Vector3(0, 0.66, 0), Vector3(0.16, 0.16, 0.16), m_iron), CSGShape3D.OPERATION_UNION)
	_add(parent, _box(lc + Vector3(0, -0.40, 0), Vector3(0.54, 0.10, 0.48), m_iron), CSGShape3D.OPERATION_UNION)
	_add(parent, _box(lc + Vector3(0, -0.52, 0), Vector3(0.20, 0.16, 0.20), m_iron), CSGShape3D.OPERATION_UNION)
	for sx in [-0.23, 0.23]:
		for sz in [-0.21, 0.21]:
			_add(parent, _box(lc + Vector3(sx, 0, sz), Vector3(0.07, 0.76, 0.07), m_iron), CSGShape3D.OPERATION_UNION)


static func _arched_prism(cx: float, y0: float, w: float, spring_y: float, z0: float, z1: float, segs: int, mat: Material) -> CSGPolygon3D:
	var rx := w * 0.5
	var pts := PackedVector2Array([
		Vector2(cx - rx, y0),
		Vector2(cx + rx, y0),
		Vector2(cx + rx, spring_y),
	])
	for i in range(1, segs):
		var a := PI * float(i) / float(segs)
		pts.append(Vector2(cx + cos(a) * rx, spring_y + sin(a) * rx))
	pts.append(Vector2(cx - rx, spring_y))
	return _extrude_z(pts, z0, z1, mat)


static func _segmental_arch_prism(cx: float, y0: float, w: float, h_side: float, arch_rise: float, z0: float, z1: float, segs: int, mat: Material) -> CSGPolygon3D:
	var rx := w * 0.5
	var y_spring := y0 + h_side
	var pts := PackedVector2Array([
		Vector2(cx - rx, y0),
		Vector2(cx + rx, y0),
		Vector2(cx + rx, y_spring),
	])
	for i in range(1, segs):
		var t := float(i) / float(segs)
		var x := lerpf(cx + rx, cx - rx, t)
		var u := (x - cx) / rx
		var y := y_spring + arch_rise * (1.0 - u * u)
		pts.append(Vector2(x, y))
	pts.append(Vector2(cx - rx, y_spring))
	return _extrude_z(pts, z0, z1, mat)


static func _quatrefoil_cut(c: Vector3, depth: float, mat: Material) -> CSGCombiner3D:
	var g := CSGCombiner3D.new()
	for off in [Vector2(0, 0.24), Vector2(0, -0.24), Vector2(-0.22, 0), Vector2(0.22, 0)]:
		var cyl := CSGCylinder3D.new()
		cyl.radius = 0.28
		cyl.height = depth
		cyl.sides = 12
		cyl.rotation_degrees.x = 90.0
		cyl.position = c + Vector3(off.x, off.y, 0.0)
		cyl.material = mat
		_add(g, cyl, CSGShape3D.OPERATION_UNION)
	return g


## Extrudes a 2D polygon in (X, Y) from z0 to z1 along Z.
static func _extrude_z(poly: PackedVector2Array, z0: float, z1: float, mat: Material) -> CSGPolygon3D:
	var p := CSGPolygon3D.new()
	p.polygon = poly
	p.depth = z1 - z0
	p.position = Vector3(0.0, 0.0, z1)
	p.material = mat
	return p


## Extrudes a 2D polygon in (Z, Y) from x0 to x1 along X.
static func _extrude_x(poly_zy: PackedVector2Array, x0: float, x1: float, mat: Material) -> CSGPolygon3D:
	var pts := PackedVector2Array()
	for v in poly_zy:
		pts.append(Vector2(-v.x, v.y))
	var p := CSGPolygon3D.new()
	p.polygon = pts
	p.depth = x1 - x0
	p.rotation_degrees.y = 90.0
	p.position = Vector3(x1, 0.0, 0.0)
	p.material = mat
	return p


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
	var group_key := "roof" if (key == "roof_z" or key == "roof_x") else key
	if _final_mats.has(group_key):
		return _final_mats[group_key]
	var m: Material
	match group_key:
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
		"roof":
			var sm := ShaderMaterial.new()
			sm.shader = load("res://hut_masonry.gdshader")
			sm.set_shader_parameter("style", 5)
			m = sm
		"wood_v":
			var sm := ShaderMaterial.new()
			sm.shader = load("res://hut_wood.gdshader")
			sm.set_shader_parameter("style", 0)
			sm.set_shader_parameter("weathering", 0.35)
			m = sm
		"wood_h":
			var sm := ShaderMaterial.new()
			sm.shader = load("res://hut_wood.gdshader")
			sm.set_shader_parameter("style", 1)
			sm.set_shader_parameter("weathering", 0.35)
			m = sm
		"timber":
			var sm := ShaderMaterial.new()
			sm.shader = load("res://hut_wood.gdshader")
			sm.set_shader_parameter("style", 2)
			sm.set_shader_parameter("weathering", 0.35)
			m = sm
		"iron":
			var sm := StandardMaterial3D.new()
			sm.vertex_color_use_as_albedo = true
			sm.metallic = 0.55
			sm.roughness = 0.52
			m = sm
		"glass":
			var sm := StandardMaterial3D.new()
			sm.vertex_color_use_as_albedo = true
			sm.metallic = 0.25
			sm.roughness = 0.14
			m = sm
		_:
			var sm := StandardMaterial3D.new()
			sm.vertex_color_use_as_albedo = true
			m = sm
	_final_mats[group_key] = m
	return m


## Bakes the CSG tree into an ArrayMesh with world-metre UVs, vertex colours, and tangents.
static func bake(root: CSGShape3D) -> ArrayMesh:
	var src: ArrayMesh = root.bake_static_mesh()
	var out := ArrayMesh.new()
	if src == null:
		push_error("LargeHouseCSG: CSG has not built its mesh yet")
		return out
	var tools := {}
	var order: Array[String] = []
	for si in range(src.get_surface_count()):
		var mat := src.surface_get_material(si)
		var tag := mat.resource_name.split(":") if mat and mat.resource_name.contains(":") else PackedStringArray(["stucco", "f2f0eb"])
		var key: String = tag[0]
		var col := Color(tag[1])
		var group_key := "roof" if (key == "roof_z" or key == "roof_x") else key
		if not tools.has(group_key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[group_key] = st
			order.append(group_key)
		var st: SurfaceTool = tools[group_key]
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
			for i in ids:
				var p: Vector3 = v[i]
				var uv: Vector2
				if key == "roof_z":
					# Main roof slopes along Z: u across X, v up the Z slope
					var dir_z := -1.0 if raw_n.z >= 0.0 else 1.0
					uv = Vector2(p.x, p.z * dir_z * 1.05)
				elif key == "roof_x":
					# Cross-gable & shed roof slopes along X: u across Z, v up the X slope
					var dir_x := -1.0 if raw_n.x >= 0.0 else 1.0
					uv = Vector2(p.z, p.x * dir_x * 1.12)
				elif fn.z >= fn.x and fn.z >= fn.y:
					uv = Vector2(p.x, maxf(p.y, 0.0))
				elif fn.x >= fn.y:
					uv = Vector2(p.z, maxf(p.y, 0.0))
				else:
					uv = Vector2(p.x, p.z)
				st.set_color(col)
				st.set_normal(n[i])
				st.set_uv(uv)
				st.add_vertex(p)
	for group_key in order:
		var st: SurfaceTool = tools[group_key]
		st.generate_tangents()
		st.index()
		st.commit(out)
		out.surface_set_material(out.get_surface_count() - 1, _final_material(group_key))
	return out
