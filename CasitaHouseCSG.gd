extends RefCounted
## Canyon Chasm's Southwest desert casita house (CasitaHouse), modelled in CSG at life size
## (metres, y up, ground at y = 0, front facing +z toward the road):
## A 24.4m x 12.6m x 22.8m warm cream-adobe casita inspired by classic Sonoran / Spanish-Pueblo
## architecture:
## - Soft rounded adobe walls with sculpted stepped side parapet wing walls rising above the roof
## - Spanish terracotta barrel-tile gable roof (`hut_masonry.gdshader` style 5) extending down over
##   a left-hand entrance porch supported by a chamfered dark timber corner post with carved corbel
##   brackets (`zapata`), heavy timber lintel beams, and exposed rafter tails (`canes`)
## - Four protruding round dark-wood vigas under the right eave
## - A deeply recessed carved coffered-panel Spanish oak front door under the porch
## - Two deeply recessed round-arched window alcoves on the right front facade with dark wood
##   double-casement windows, iron grilles, and sunlit plastered arch tympanums
## - A front flagstone courtyard enclosed by low rounded adobe patio walls with a central entry
##   walkway, a rustic wooden bench, and three terracotta planter pots with blue agave rosettes.
##
## regenerate_chasm_houses.gd builds the tree (`build`), lets the CSG update, and bakes it (`bake`)
## into generated/casita_house.res, which CasitaHouse.tscn draws at scale 1.0.

const SINK := 5.5

const COL_STUCCO := Color(0.95, 0.89, 0.79)
const COL_PARAPET := Color(0.92, 0.85, 0.74)
const COL_PATIO_WALL := Color(0.82, 0.65, 0.52)
const COL_FLAGSTONE := Color(0.76, 0.66, 0.55)
const COL_TILE := Color(0.72, 0.44, 0.30)
const COL_TILE_TRIM := Color(0.66, 0.39, 0.26)
const COL_TIMBER := Color(0.36, 0.25, 0.17)
const COL_TIMBER_DARK := Color(0.25, 0.17, 0.11)
const COL_DOOR := Color(0.46, 0.28, 0.15)
const COL_BENCH := Color(0.48, 0.38, 0.29)
const COL_IRON := Color(0.12, 0.12, 0.13)
const COL_GLASS := Color(0.09, 0.11, 0.13)
const COL_POT := Color(0.68, 0.36, 0.22)
const COL_AGAVE := Color(0.30, 0.46, 0.36)

static var _placeholder_mats := {}
static var _final_mats := {}


static func build() -> CSGCombiner3D:
	var root := CSGCombiner3D.new()
	root.name = "CasitaHouseCSG"

	var m_stucco := _mat("stucco", COL_STUCCO)
	var m_parapet := _mat("stucco", COL_PARAPET)
	var m_patio_wall := _mat("adobe", COL_PATIO_WALL)
	var m_stone := _mat("stone", COL_FLAGSTONE)
	var m_roof_z := _mat("roof_z", COL_TILE)
	var m_trim := _mat("timber", COL_TILE_TRIM)
	var m_timber := _mat("timber", COL_TIMBER)
	var m_timber_dark := _mat("timber", COL_TIMBER_DARK)
	var m_door := _mat("wood_v", COL_DOOR)
	var m_bench := _mat("wood_h", COL_BENCH)
	var m_iron := _mat("iron", COL_IRON)
	var m_glass := _mat("glass", COL_GLASS)
	var m_pot := _mat("adobe", COL_POT)
	var m_agave := _mat("foliage", COL_AGAVE)

	# ------------------------------------------------------------------
	# 1. Cream-Adobe Casita Body & Sculpted Wing Parapet Walls
	# ------------------------------------------------------------------
	var walls := CSGCombiner3D.new()
	walls.name = "CasitaWalls"

	# A. Main central gabled house block: X [-10.20 .. +10.20], Z [-8.80 .. +4.40]
	# Profile in (Z, Y): eaves at Y = 8.15, ridge at Z = -2.10, Y = 11.75
	var main_prof := PackedVector2Array([
		Vector2(-8.80, -SINK),
		Vector2(-8.80, 8.15),
		Vector2(-2.10, 11.75),
		Vector2(4.40, 8.15),
		Vector2(4.40, -SINK),
	])
	_add(walls, _extrude_x(main_prof, -10.20, 10.20, m_stucco), CSGShape3D.OPERATION_UNION)

	# B. Sculpted Left Wing Parapet & Porch Buttress Wall: X [-11.45 .. -9.85]
	# Rises above the tile roof to Y = 12.45 at the ridge, steps forward along the left porch
	# to Z = +8.60 (Y = 6.75), and rounds smoothly into the front courtyard wall.
	var left_wing_prof := PackedVector2Array([
		Vector2(-9.05, -SINK),
		Vector2(-9.05, 8.55),
		Vector2(-8.20, 9.10),
		Vector2(-2.60, 12.42),
		Vector2(-1.50, 12.42),
		Vector2(4.20, 8.85),
		Vector2(5.10, 8.55),
		Vector2(8.35, 6.75),
		Vector2(8.75, 6.10),
		Vector2(9.10, 2.30),
		Vector2(9.10, -SINK),
	])
	_add(walls, _extrude_x(left_wing_prof, -11.45, -9.85, m_parapet), CSGShape3D.OPERATION_UNION)
	# Rounded adobe crown cap along the left parapet top
	_add(walls, _beam(Vector3(-10.65, 12.42, -2.05), Vector3(-10.65, 8.75, 4.45), 1.56, 0.55, m_parapet, Vector3.RIGHT), CSGShape3D.OPERATION_UNION)
	_add(walls, _beam(Vector3(-10.65, 12.42, -2.05), Vector3(-10.65, 8.65, -8.85), 1.56, 0.55, m_parapet, Vector3.RIGHT), CSGShape3D.OPERATION_UNION)

	# C. Sculpted Right Wing Parapet Wall: X [+9.85 .. +11.45]
	# Rises above the right gable end to Y = 12.45 at the ridge and steps down at the front eave (Z = +4.65)
	var right_wing_prof := PackedVector2Array([
		Vector2(-9.05, -SINK),
		Vector2(-9.05, 8.55),
		Vector2(-8.20, 9.10),
		Vector2(-2.60, 12.42),
		Vector2(-1.50, 12.42),
		Vector2(3.85, 8.95),
		Vector2(4.75, 8.65),
		Vector2(4.95, 2.30),
		Vector2(4.95, -SINK),
	])
	_add(walls, _extrude_x(right_wing_prof, 9.85, 11.45, m_parapet), CSGShape3D.OPERATION_UNION)
	_add(walls, _beam(Vector3(10.65, 12.42, -2.05), Vector3(10.65, 8.70, 4.65), 1.56, 0.55, m_parapet, Vector3.RIGHT), CSGShape3D.OPERATION_UNION)
	_add(walls, _beam(Vector3(10.65, 12.42, -2.05), Vector3(10.65, 8.65, -8.85), 1.56, 0.55, m_parapet, Vector3.RIGHT), CSGShape3D.OPERATION_UNION)

	# D. Carve Deep Front Doorway Recess under Left Porch: X = -5.65, Y [0.24 .. 5.30], Z = +4.40
	_add(walls, _box(Vector3(-5.65, 2.77, 4.10), Vector3(3.24, 5.06, 0.95), m_stucco), CSGShape3D.OPERATION_SUBTRACTION)

	# E. Carve Twin Round-Arched Window Alcove Niches on Right Front Wall (+Z = 4.40):
	# Centered at X = +2.35 and X = +7.15, sill Y = 1.95, spring Y = 4.55, width = 2.68 (arch top Y = 5.89)
	for wx in [2.35, 7.15]:
		_add(walls, _arched_prism(wx, 1.95, 2.68, 4.55, 3.68, 4.65, 16, m_stucco), CSGShape3D.OPERATION_SUBTRACTION)

	# F. Carve Side & Rear Arched Window Niches so all 4 elevations look authentic:
	# Right (+X = 11.45) arched window at Z = -2.20
	_add(walls, _box(Vector3(11.15, 3.55, -2.20), Vector3(0.90, 3.20, 2.50), m_stucco), CSGShape3D.OPERATION_SUBTRACTION)
	# Left (-X = -11.45) window at Z = -2.20
	_add(walls, _box(Vector3(-11.15, 3.55, -2.20), Vector3(0.90, 3.20, 2.50), m_stucco), CSGShape3D.OPERATION_SUBTRACTION)
	# Rear (-Z = -8.80) two arched window niches at X = -4.80 and X = +4.80
	for rwx in [-4.80, 4.80]:
		_add(walls, _arched_prism(rwx, 2.05, 2.50, 4.45, -9.05, -8.15, 14, m_stucco), CSGShape3D.OPERATION_SUBTRACTION)

	_add(root, walls, CSGShape3D.OPERATION_UNION)

	# ------------------------------------------------------------------
	# 2. Spanish Terracotta Barrel-Tile Roof (Main + Extended Left Porch)
	# ------------------------------------------------------------------
	var roofs := CSGCombiner3D.new()
	roofs.name = "TerracottaRoofs"

	# A. Rear Roof Slope (full width between parapet walls: X [-9.95 .. +9.95], Z [-9.15 .. -2.10])
	# Plus Right-Hand Front Roof Slope (X [-1.05 .. +9.95], Z [-2.10 .. +4.82])
	var right_roof_prof := PackedVector2Array([
		Vector2(-9.15, 7.95),
		Vector2(-9.15, 8.35),
		Vector2(-2.10, 12.05),
		Vector2(4.82, 8.35),
		Vector2(4.82, 7.95),
		Vector2(-2.10, 11.62),
	])
	_add(roofs, _extrude_x(right_roof_prof, -1.05, 9.95, m_roof_z), CSGShape3D.OPERATION_UNION)

	# B. Left-Hand Roof Slope with Continuous Extended Front Porch Sweep:
	# Spans X [-9.95 .. -0.65], from rear eave (Z = -9.15) over ridge (Z = -2.10) all the way down
	# to the front porch eave at Z = +8.72, Y = 5.95!
	var left_roof_prof := PackedVector2Array([
		Vector2(-9.15, 7.95),
		Vector2(-9.15, 8.35),
		Vector2(-2.10, 12.05),
		Vector2(4.40, 8.58),
		Vector2(8.72, 6.28),
		Vector2(8.72, 5.90),
		Vector2(4.40, 8.18),
		Vector2(-2.10, 11.62),
	])
	_add(roofs, _extrude_x(left_roof_prof, -9.95, -0.65, m_roof_z), CSGShape3D.OPERATION_UNION)

	_add(root, roofs, CSGShape3D.OPERATION_UNION)

	# C. Terracotta Ridge Cap & Step-Tile Eave Trim
	_add(root, _beam(Vector3(-9.95, 12.08, -2.10), Vector3(9.95, 12.08, -2.10), 0.48, 0.28, m_trim), CSGShape3D.OPERATION_UNION)
	# Exposed step edge where left porch roof extends past right main eave (X = -0.65, Z [+4.40 .. +8.72])
	_add(root, _beam(Vector3(-0.72, 8.42, 4.40), Vector3(-0.72, 6.12, 8.72), 0.26, 0.34, m_trim, Vector3.RIGHT), CSGShape3D.OPERATION_UNION)

	# ------------------------------------------------------------------
	# 3. Exposed Wooden Vigas & Left Porch Post / Corbel Timberwork
	# ------------------------------------------------------------------
	var timber := CSGCombiner3D.new()
	timber.name = "Timberwork"

	# A. Four Protruding Round Wooden Vigas under Right Front Eave (+Z = 4.40, Y = 7.25)
	for vx in [0.65, 3.25, 5.85, 8.45]:
		_add(timber, _viga_z(vx, 7.25, 3.90, 5.38, 0.30, m_timber_dark), CSGShape3D.OPERATION_UNION)
	# Rear (-Z = -8.80, Y = 7.25) vigas
	for vx in [-7.80, -4.60, -1.40, 1.80, 5.00, 8.20]:
		_add(timber, _viga_z(vx, 7.25, -9.68, -8.30, 0.28, m_timber_dark), CSGShape3D.OPERATION_UNION)

	# B. Left Entrance Porch Timber Structure (X [-9.95 .. -0.85], Z [+4.40 .. +8.55]):
	#    1) Stout square dark-timber corner post at X = -1.35, Z = +7.95 (from patio Y = 0.24 to Y = 5.75)
	_add(timber, _box(Vector3(-1.35, 0.42, 7.95), Vector3(0.68, 0.36, 0.68), m_stone), CSGShape3D.OPERATION_UNION)
	_add(timber, _box(Vector3(-1.35, 3.05, 7.95), Vector3(0.48, 5.42, 0.48), m_timber), CSGShape3D.OPERATION_UNION)
	#    2) Carved wooden corbel bracket (zapata) crowning the corner post (Y = 5.52..5.82)
	_add(timber, _box(Vector3(-1.35, 5.56, 7.95), Vector3(1.55, 0.24, 0.54), m_timber_dark), CSGShape3D.OPERATION_UNION)
	_add(timber, _box(Vector3(-1.35, 5.74, 7.95), Vector3(2.10, 0.22, 0.58), m_timber_dark), CSGShape3D.OPERATION_UNION)
	#    3) Front porch main horizontal header beam (Z = +7.95, Y = 5.96, X [-9.95 .. -0.80])
	_add(timber, _box(Vector3(-5.38, 5.96, 7.95), Vector3(9.15, 0.38, 0.44), m_timber_dark), CSGShape3D.OPERATION_UNION)
	#    4) Side return tie beam (X = -1.35, Z [+4.30 .. +8.15], Y = 5.96)
	_add(timber, _box(Vector3(-1.35, 5.96, 6.22), Vector3(0.40, 0.36, 3.85), m_timber_dark), CSGShape3D.OPERATION_UNION)
	#    5) Sloped porch rafters & exposed rafter tails (canes) projecting to Z = +8.68
	for rx in [-9.10, -7.25, -5.40, -3.55, -1.70]:
		_add(timber, _beam(Vector3(rx, 8.15, 4.35), Vector3(rx, 5.88, 8.68), 0.22, 0.24, m_timber_dark), CSGShape3D.OPERATION_UNION)

	_add(root, timber, CSGShape3D.OPERATION_UNION)

	# ------------------------------------------------------------------
	# 4. Carved Spanish Wooden Door & Recessed Arched Casement Windows
	# ------------------------------------------------------------------
	# A. Front Door under Porch (X = -5.65, Y [0.24 .. 5.30], Z = +4.40)
	# Stone threshold step
	_add(root, _box(Vector3(-5.65, 0.34, 4.42), Vector3(3.48, 0.20, 0.96), m_stone), CSGShape3D.OPERATION_UNION)
	# Heavy timber door frame & lintel
	_add(root, _box(Vector3(-5.65, 5.38, 4.22), Vector3(3.86, 0.34, 0.68), m_timber_dark), CSGShape3D.OPERATION_UNION)
	_add(root, _box(Vector3(-5.65, 2.77, 3.82), Vector3(3.24, 5.06, 0.18), m_timber_dark), CSGShape3D.OPERATION_UNION)
	# Warm carved oak door leaf
	_add(root, _box(Vector3(-5.65, 2.77, 3.92), Vector3(2.84, 4.76, 0.12), m_door), CSGShape3D.OPERATION_UNION)
	# Coffered geometric Spanish panels (2 columns x 4 rows) + central stile + iron ring knocker
	_add(root, _box(Vector3(-5.65, 2.77, 3.99), Vector3(0.18, 4.76, 0.06), m_timber_dark), CSGShape3D.OPERATION_UNION)
	for py in [0.95, 2.15, 3.35, 4.55]:
		_add(root, _box(Vector3(-5.65, py, 3.99), Vector3(2.84, 0.16, 0.06), m_timber_dark), CSGShape3D.OPERATION_UNION)
	for py in [1.55, 2.75, 3.95]:
		for px in [-6.32, -4.98]:
			_add(root, _box(Vector3(px, py, 4.00), Vector3(0.82, 0.72, 0.06), m_door), CSGShape3D.OPERATION_UNION)
			_add(root, _box(Vector3(px, py, 4.04), Vector3(0.48, 0.42, 0.05), m_timber_dark), CSGShape3D.OPERATION_UNION)
	# Iron latch & ring handle
	_add(root, _box(Vector3(-4.52, 2.55, 4.02), Vector3(0.16, 0.44, 0.06), m_iron), CSGShape3D.OPERATION_UNION)

	# B. Twin Front Arched Alcove Windows (X = +2.35 and X = +7.15, Z = +4.40)
	for wx in [2.35, 7.15]:
		# Stone sill inside niche (Y = 1.95)
		_add(root, _box(Vector3(wx, 1.92, 4.18), Vector3(2.74, 0.16, 0.62), m_stone), CSGShape3D.OPERATION_UNION)
		# Rectangular dark timber window frame set in the lower part of the arched alcove (Y [2.00 .. 4.52])
		# leaving the sunlit plastered arch tympanum open above Y = 4.52!
		_add(root, _box(Vector3(wx, 4.54, 4.05), Vector3(2.72, 0.20, 0.48), m_timber_dark), CSGShape3D.OPERATION_UNION)
		_add(root, _box(Vector3(wx, 3.26, 3.84), Vector3(2.68, 2.52, 0.16), m_timber_dark), CSGShape3D.OPERATION_UNION)
		# Dark window glass & casement shutters/mullions
		_add(root, _box(Vector3(wx, 3.26, 3.92), Vector3(2.34, 2.22, 0.08), m_glass), CSGShape3D.OPERATION_UNION)
		# Central vertical stile & two casement sub-frames
		for sx in [-0.58, 0.0, 0.58]:
			_add(root, _box(Vector3(wx + sx, 3.26, 3.97), Vector3(0.11, 2.26, 0.06), m_timber), CSGShape3D.OPERATION_UNION)
		for sy in [2.72, 3.26, 3.80]:
			_add(root, _box(Vector3(wx, sy, 3.97), Vector3(2.38, 0.08, 0.05), m_timber), CSGShape3D.OPERATION_UNION)
		# Wrought-iron vertical grille bars across lower half of niche (Z = 4.18)
		_add(root, _box(Vector3(wx, 3.10, 4.18), Vector3(2.62, 0.06, 0.06), m_iron), CSGShape3D.OPERATION_UNION)
		for gx in [-0.96, -0.48, 0.0, 0.48, 0.96]:
			_add(root, _box(Vector3(wx + gx, 2.55, 4.18), Vector3(0.05, 1.12, 0.05), m_iron), CSGShape3D.OPERATION_UNION)

	# C. Side & Rear Windows
	for side_x: float in [-11.45, 11.45]:
		var sign_x: float = 1.0 if side_x > 0.0 else -1.0
		var wx_in: float = side_x - sign_x * 0.45
		_add(root, _box(Vector3(side_x - sign_x * 0.22, 1.92, -2.20), Vector3(0.52, 0.16, 2.62), m_stone), CSGShape3D.OPERATION_UNION)
		_add(root, _box(Vector3(wx_in, 3.55, -2.20), Vector3(0.16, 3.20, 2.50), m_timber_dark), CSGShape3D.OPERATION_UNION)
		_add(root, _box(Vector3(wx_in + sign_x * 0.06, 3.55, -2.20), Vector3(0.08, 2.86, 2.16), m_glass), CSGShape3D.OPERATION_UNION)
		_add(root, _box(Vector3(wx_in + sign_x * 0.10, 3.55, -2.20), Vector3(0.06, 2.90, 0.12), m_timber), CSGShape3D.OPERATION_UNION)
	for rwx in [-4.80, 4.80]:
		_add(root, _box(Vector3(rwx, 2.02, -8.58), Vector3(2.56, 0.16, 0.56), m_stone), CSGShape3D.OPERATION_UNION)
		_add(root, _box(Vector3(rwx, 3.25, -8.30), Vector3(2.50, 2.40, 0.16), m_timber_dark), CSGShape3D.OPERATION_UNION)
		_add(root, _box(Vector3(rwx, 3.25, -8.38), Vector3(2.16, 2.10, 0.08), m_glass), CSGShape3D.OPERATION_UNION)
		_add(root, _box(Vector3(rwx, 3.25, -8.43), Vector3(0.12, 2.14, 0.06), m_timber), CSGShape3D.OPERATION_UNION)

	# ------------------------------------------------------------------
	# 5. Flagstone Courtyard, Rounded Adobe Patio Walls, Bench & Planters
	# ------------------------------------------------------------------
	var patio := CSGCombiner3D.new()
	patio.name = "Courtyard"

	# A. Courtyard Adobe Foundation (-SINK .. 0.04) & Flagstone Paving Slab (0.04 .. 0.24)
	var patio_plan := _rounded_rect(-11.35, 4.20, 11.35, 11.55, 0.65, 5)
	_add(patio, _extrude_y(patio_plan, -SINK, 0.04, m_patio_wall), CSGShape3D.OPERATION_UNION)
	var paving_plan := _rounded_rect(-10.85, 4.30, 10.85, 11.05, 0.45, 4)
	_add(patio, _extrude_y(paving_plan, 0.04, 0.24, m_stone), CSGShape3D.OPERATION_UNION)

	# B. Low Rounded Adobe Courtyard Perimeter Walls (Y [-SINK .. +1.95], bullnose cap at Y = 1.95):
	#    1) Left courtyard wall (X [-11.35 .. -10.15], Z [+4.40 .. +11.35])
	_add(patio, _box(Vector3(-10.75, (1.92 - SINK) * 0.5, 7.88), Vector3(1.20, 1.92 + SINK, 6.96), m_patio_wall), CSGShape3D.OPERATION_UNION)
	_add(patio, _viga_z(-10.75, 1.92, 4.40, 11.15, 0.60, m_patio_wall), CSGShape3D.OPERATION_UNION)
	#    2) Front-left courtyard wall return (X [-11.35 .. -3.10], Z [+10.25 .. +11.45])
	_add(patio, _box(Vector3(-7.225, (1.92 - SINK) * 0.5, 10.85), Vector3(8.25, 1.92 + SINK, 1.20), m_patio_wall), CSGShape3D.OPERATION_UNION)
	_add(patio, _viga_x(-10.85, -3.10, 1.92, 10.85, 0.60, m_patio_wall), CSGShape3D.OPERATION_UNION)
	#    3) Right courtyard wall (X [+10.15 .. +11.35], Z [+4.40 .. +11.35])
	_add(patio, _box(Vector3(10.75, (1.92 - SINK) * 0.5, 7.88), Vector3(1.20, 1.92 + SINK, 6.96), m_patio_wall), CSGShape3D.OPERATION_UNION)
	_add(patio, _viga_z(10.75, 1.92, 4.40, 11.15, 0.60, m_patio_wall), CSGShape3D.OPERATION_UNION)
	#    4) Front-right courtyard wall return (X [+2.10 .. +11.35], Z [+10.25 .. +11.45])
	_add(patio, _box(Vector3(6.725, (1.92 - SINK) * 0.5, 10.85), Vector3(9.25, 1.92 + SINK, 1.20), m_patio_wall), CSGShape3D.OPERATION_UNION)
	_add(patio, _viga_x(2.10, 10.85, 1.92, 10.85, 0.60, m_patio_wall), CSGShape3D.OPERATION_UNION)

	# C. Rustic Wooden Bench between Front Windows (X = +4.75, Z = +5.15, Y = 0.24..1.08)
	_add(patio, _box(Vector3(4.75, 1.04, 5.15), Vector3(3.10, 0.12, 0.72), m_bench), CSGShape3D.OPERATION_UNION)
	for blx in [3.50, 6.00]:
		_add(patio, _box(Vector3(blx, 0.62, 5.15), Vector3(0.16, 0.76, 0.62), m_timber_dark), CSGShape3D.OPERATION_UNION)
	_add(patio, _box(Vector3(4.75, 0.58, 5.15), Vector3(2.40, 0.10, 0.12), m_timber_dark), CSGShape3D.OPERATION_UNION)

	# D. Three Terracotta Planter Pots with Agave Rosettes on the Courtyard Patio
	for spot in [Vector3(-8.45, 0.24, 5.45), Vector3(0.15, 0.24, 5.25), Vector3(8.95, 0.24, 5.65)]:
		_build_planter_pot(patio, spot, m_pot, m_agave)

	_add(root, patio, CSGShape3D.OPERATION_UNION)

	return root


static func _build_planter_pot(parent: CSGShape3D, base: Vector3, m_pot: Material, m_agave: Material) -> void:
	var pot := CSGCylinder3D.new()
	pot.radius = 0.72
	pot.height = 1.05
	pot.sides = 12
	pot.position = base + Vector3(0, 0.525, 0)
	pot.material = m_pot
	_add(parent, pot, CSGShape3D.OPERATION_UNION)

	var rim := CSGCylinder3D.new()
	rim.radius = 0.80
	rim.height = 0.18
	rim.sides = 12
	rim.position = base + Vector3(0, 0.98, 0)
	rim.material = m_pot
	_add(parent, rim, CSGShape3D.OPERATION_UNION)

	# Sculpted spiky agave rosette leaves radiating from pot top
	var center := base + Vector3(0, 1.05, 0)
	for i in 8:
		var a := TAU * float(i) / 8.0 + 0.2
		var dir := Vector3(cos(a), 0.58, sin(a)).normalized()
		_add(parent, _beam(center, center + dir * 1.15, 0.28, 0.12, m_agave), CSGShape3D.OPERATION_UNION)
	for i in 5:
		var a := TAU * float(i) / 5.0 + 0.55
		var dir := Vector3(cos(a) * 0.45, 0.89, sin(a) * 0.45).normalized()
		_add(parent, _beam(center, center + dir * 1.05, 0.24, 0.12, m_agave), CSGShape3D.OPERATION_UNION)


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


static func _extrude_z(poly: PackedVector2Array, z0: float, z1: float, mat: Material) -> CSGPolygon3D:
	var p := CSGPolygon3D.new()
	p.polygon = poly
	p.depth = z1 - z0
	p.position = Vector3(0.0, 0.0, z1)
	p.material = mat
	return p


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


static func _viga_z(x: float, y: float, z0: float, z1: float, r: float, mat: Material) -> CSGCylinder3D:
	var c := CSGCylinder3D.new()
	c.radius = r
	c.height = z1 - z0
	c.sides = 10
	c.rotation_degrees.x = 90.0
	c.position = Vector3(x, y, (z0 + z1) * 0.5)
	c.material = mat
	return c


static func _viga_x(x0: float, x1: float, y: float, z: float, r: float, mat: Material) -> CSGCylinder3D:
	var c := CSGCylinder3D.new()
	c.radius = r
	c.height = x1 - x0
	c.sides = 10
	c.rotation_degrees.z = 90.0
	c.position = Vector3((x0 + x1) * 0.5, y, z)
	c.material = mat
	return c


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
			sm.set_shader_parameter("moss", 0.0)
			m = sm
		"adobe":
			var sm := ShaderMaterial.new()
			sm.shader = load("res://hut_masonry.gdshader")
			sm.set_shader_parameter("style", 3)
			sm.set_shader_parameter("moss", 0.0)
			m = sm
		"stone":
			var sm := ShaderMaterial.new()
			sm.shader = load("res://hut_masonry.gdshader")
			sm.set_shader_parameter("style", 0)
			sm.set_shader_parameter("moss", 0.0)
			m = sm
		"roof":
			var sm := ShaderMaterial.new()
			sm.shader = load("res://hut_masonry.gdshader")
			sm.set_shader_parameter("style", 5)
			sm.set_shader_parameter("moss", 0.0)
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
			sm.set_shader_parameter("weathering", 0.42)
			m = sm
		"iron":
			var sm := StandardMaterial3D.new()
			sm.vertex_color_use_as_albedo = true
			sm.vertex_color_is_srgb = true
			sm.metallic = 0.55
			sm.roughness = 0.52
			m = sm
		"glass":
			var sm := StandardMaterial3D.new()
			sm.vertex_color_use_as_albedo = true
			sm.vertex_color_is_srgb = true
			sm.metallic = 0.25
			sm.roughness = 0.14
			m = sm
		"foliage":
			var sm := StandardMaterial3D.new()
			sm.vertex_color_use_as_albedo = true
			sm.vertex_color_is_srgb = true
			sm.roughness = 0.72
			m = sm
		_:
			var sm := StandardMaterial3D.new()
			sm.vertex_color_use_as_albedo = true
			sm.vertex_color_is_srgb = true
			m = sm
	_final_mats[group_key] = m
	return m


static func bake(root: CSGShape3D) -> ArrayMesh:
	var src: ArrayMesh = root.bake_static_mesh()
	var out := ArrayMesh.new()
	if src == null:
		push_error("CasitaHouseCSG: CSG has not built its mesh yet")
		return out
	var tools := {}
	var order: Array[String] = []
	for si in range(src.get_surface_count()):
		var mat := src.surface_get_material(si)
		var tag := mat.resource_name.split(":") if mat and mat.resource_name.contains(":") else PackedStringArray(["stucco", "f2e3c9"])
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
					var dir_z := -1.0 if raw_n.z >= 0.0 else 1.0
					uv = Vector2(p.x, p.z * dir_z * 1.05)
				elif fn.z >= fn.x and fn.z >= fn.y:
					uv = Vector2(p.x, p.y + SINK)
				elif fn.x >= fn.y:
					uv = Vector2(p.z, p.y + SINK)
				else:
					uv = Vector2(p.x, p.z)
				# Keep stone cobble flaking in style 3 confined to flat above-ground wall faces
				var alpha := 1.0
				if group_key == "adobe" and (p.y > 1.75 or p.y < 0.15 or (fn.y > fn.x and fn.y > fn.z)):
					alpha = 0.0
				st.set_color(Color(col.r, col.g, col.b, alpha))
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
