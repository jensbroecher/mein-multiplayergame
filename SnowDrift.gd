@tool
class_name SnowDrift
extends Area3D

## SnowDrift
## A deformable drift of loose snow lying on the road.
##
## - Shape: the drift is a height field laid over a strip of road, defined row by row along the road
##   (row_centres / row_rights), so it follows the road through a bend and stops at the road edges
##   instead of hanging over them. Without that data it falls back to a flat rectangle of `size`,
##   which is what a drift placed by hand in the editor uses.
## - Driving: only the top of the drift is loose powder. A packed layer (PACKED_FRACTION of the local
##   depth) is solid, so cars ride up onto it and sit *in* the snow rather than passing through it.
##   PlayerCart reads snow_depth_at() for how much loose snow is in front of the car and slows down
##   accordingly -- fresh powder is heavy going, a rut someone already cut is much easier.
## - Deformation: every car inside carves the powder down to the packed layer under its tyres and
##   chassis, banking a little of it up beside the ruts, and the snow it hits is thrown up as spray.
##   This is cosmetic and runs on every peer from the synced car positions.

@export_group("Dimensions")
## Base size of a hand-placed drift (Width = X, Height = Y, Length = Z) in metres. For a drift laid
## along a road only Y (peak height) is used; the footprint comes from the road rows.
@export var size: Vector3 = Vector3(15.0, 1.2, 18.0):
	set(val):
		size = Vector3(maxf(val.x, 1.0), maxf(val.y, 0.1), maxf(val.z, 1.0))
		_queue_rebuild()

@export_group("Road Footprint")
## Centre of each cross-section row of the drift, in this node's local space, from one end to the
## other. Set by level generators; leave empty for a hand-placed rectangular drift.
@export var row_centres: PackedVector3Array = PackedVector3Array():
	set(val):
		row_centres = val
		_queue_rebuild()
## Unit, horizontal "right" vector of each row (same count as row_centres).
@export var row_rights: PackedVector3Array = PackedVector3Array():
	set(val):
		row_rights = val
		_queue_rebuild()
## Half width of the drift across the road, in metres. The snow thins out to nothing at this edge.
@export var drift_half_width: float = 6.0:
	set(val):
		drift_half_width = maxf(val, 0.5)
		_queue_rebuild()

## Height the road surface rises at its centreline above the row centres, falling linearly to 0 at
## the drift edges. Matches a crowned deck so the thin edges of the drift do not float above it.
@export var base_crown: float = 0.0:
	set(val):
		base_crown = val
		_queue_rebuild()

@export_group("Drift Shape")
## Maximum height multiplier for the drift mound.
@export_range(0.2, 3.0, 0.05) var mound_height_ratio: float = 1.0:
	set(val):
		mound_height_ratio = val
		_queue_rebuild()
## Seed offset for organic variation between multiple drifts.
@export var seed_offset: float = 0.0:
	set(val):
		seed_offset = val
		_queue_rebuild()
## Asymmetry factor: shifts peak mound towards one side (+X or -X) like a wind-blown bank.
@export_range(-1.0, 1.0, 0.05) var bank_asymmetry: float = 0.25:
	set(val):
		bank_asymmetry = val
		_queue_rebuild()

@export_group("Material")
@export var snow_color: Color = Color(0.97, 0.985, 1.0):
	set(val):
		snow_color = val
		_queue_rebuild()
## Tint of snow that has been driven over and compacted.
@export var packed_color: Color = Color(0.70, 0.78, 0.90):
	set(val):
		packed_color = val
		_queue_rebuild()
@export_range(0.0, 1.0, 0.05) var roughness: float = 0.85:
	set(val):
		roughness = val
		_queue_rebuild()

@export_group("Editor Tools")
## Drop this snow drift onto the road or terrain directly below it.
@export_tool_button("Snap To Ground") var snap_to_ground_btn: Callable = snap_to_ground

## Peak depth of the packed layer, as a fraction of the drift's peak height.
const PACKED_FRACTION := 0.28
## How far in from the drift ends / road edges the packed layer takes to reach full depth, as a
## fraction of the half length / half width. Much gentler than the powder's own faces: the packed
## layer is what the car physically drives on, and when it copied the mound's steep ends (0.4m in
## under 2m) it launched cars off the front of every drift.
const PACKED_RAMP_ALONG := 0.45
const PACKED_RAMP_ACROSS := 0.35
## Grid spacing of the height field, metres. Fine enough for a tyre to leave a visible rut.
const CELL := 0.25
## Snow never thins to exactly nothing at the edges, so the drift does not z-fight the road.
const MIN_DEPTH := 0.02
## Tyre contact patch radius and the width of the bank pushed up beside a rut.
const WHEEL_RADIUS := 0.34
const BERM_WIDTH := 0.35
## Minimum time between mesh rebuilds while cars are carving.
const REBUILD_INTERVAL := 0.05

var _mesh_inst: MeshInstance3D
var _col_shape: CollisionShape3D
var _packed_body: StaticBody3D
var _material: StandardMaterial3D

## Height-field layout: _rows x _cols vertices, row-major. _base is the road surface under each
## vertex (local space); _top the untouched snow depth; _cur the current depth after carving.
var _rows: int = 0
var _cols: int = 0
var _base: PackedVector3Array = PackedVector3Array()
var _top: PackedFloat32Array = PackedFloat32Array()
var _cur: PackedFloat32Array = PackedFloat32Array()
var _packed: PackedFloat32Array = PackedFloat32Array()
var _uvs: PackedVector2Array = PackedVector2Array()
var _indices: PackedInt32Array = PackedInt32Array()
## Row frames used to map a local point back onto the grid.
var _row_c: PackedVector3Array = PackedVector3Array()
var _row_r: PackedVector3Array = PackedVector3Array()
var _row_f: PackedVector3Array = PackedVector3Array()
var _half_w: float = 0.0

var _rebuild_queued := false
var _dirty := false
var _since_rebuild := 0.0
## Cars currently inside, each with its spray emitter: {body: CPUParticles3D}.
var _bodies: Dictionary = {}


func _enter_tree() -> void:
	add_to_group("snow", true)
	set_meta("is_snow", true)


func _ready() -> void:
	_rebuild()
	if not Engine.is_editor_hint():
		if not body_entered.is_connected(_on_body_entered):
			body_entered.connect(_on_body_entered)
		if not body_exited.is_connected(_on_body_exited):
			body_exited.connect(_on_body_exited)


func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


# ---------------------------------------------------------------------------------------------
# Building
# ---------------------------------------------------------------------------------------------

func _rebuild() -> void:
	_rebuild_queued = false
	_ensure_nodes()
	_build_rows()
	_build_heights()
	_build_indices()
	_update_mesh()
	_update_packed_collision()
	_update_trigger()


func _ensure_nodes() -> void:
	# The snow mesh and the packed layer are rebuilt from the exported inputs every time the drift
	# enters the tree, so they are added as *internal* children: never saved into the level file
	# (a 4k-vertex height field per drift) and invisible to get_children() walkers such as the
	# generators' owner pass. The scene's own MeshInstance3D child is left empty.
	var legacy := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if legacy:
		legacy.mesh = null
	_mesh_inst = get_node_or_null("SnowMesh") as MeshInstance3D
	if _mesh_inst == null:
		_mesh_inst = MeshInstance3D.new()
		_mesh_inst.name = "SnowMesh"
		add_child(_mesh_inst, false, Node.INTERNAL_MODE_FRONT)
	_col_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if _col_shape == null:
		_col_shape = CollisionShape3D.new()
		_col_shape.name = "CollisionShape3D"
		add_child(_col_shape)
	if not (_col_shape.shape is BoxShape3D):
		_col_shape.shape = BoxShape3D.new()
	_packed_body = get_node_or_null("PackedSnow") as StaticBody3D
	if _packed_body == null:
		_packed_body = StaticBody3D.new()
		_packed_body.name = "PackedSnow"
		# A track surface, so the car is not treated as offroad; the snow group/meta make it snow.
		_packed_body.add_to_group("track_surface", true)
		_packed_body.add_to_group("snow", true)
		_packed_body.set_meta("is_snow", true)
		var cs := CollisionShape3D.new()
		cs.name = "Shape"
		_packed_body.add_child(cs)
		add_child(_packed_body, false, Node.INTERNAL_MODE_FRONT)


func _build_rows() -> void:
	_row_c = PackedVector3Array()
	_row_r = PackedVector3Array()
	if row_centres.size() >= 2 and row_rights.size() == row_centres.size():
		_row_c = row_centres.duplicate()
		_row_r = row_rights.duplicate()
		_half_w = drift_half_width
	else:
		# Hand-placed drift: a flat rectangle along local Z.
		var n: int = maxi(int(size.z / CELL), 2) + 1
		for i in range(n):
			_row_c.append(Vector3(0.0, 0.0, lerpf(-size.z * 0.5, size.z * 0.5, float(i) / float(n - 1))))
			_row_r.append(Vector3.RIGHT)
		_half_w = size.x * 0.5
	_rows = _row_c.size()
	_cols = maxi(int(_half_w * 2.0 / CELL), 2) + 1
	_row_f = PackedVector3Array()
	_row_f.resize(_rows)
	for i in range(_rows):
		var a: Vector3 = _row_c[maxi(i - 1, 0)]
		var b: Vector3 = _row_c[mini(i + 1, _rows - 1)]
		var f: Vector3 = b - a
		f.y = 0.0
		_row_f[i] = f.normalized() if f.length() > 1e-5 else Vector3.BACK


func _build_heights() -> void:
	var n: int = _rows * _cols
	_base.resize(n)
	_top.resize(n)
	_packed.resize(n)
	_uvs.resize(n)
	var h: float = size.y * mound_height_ratio
	var along := 0.0
	for i in range(_rows):
		if i > 0:
			along += _row_c[i].distance_to(_row_c[i - 1])
		var v: float = float(i) / float(_rows - 1) * 2.0 - 1.0
		for j in range(_cols):
			var u: float = float(j) / float(_cols - 1) * 2.0 - 1.0
			var k: int = i * _cols + j
			_base[k] = _row_c[i] + _row_r[i] * (u * _half_w) + Vector3(0.0, base_crown * (1.0 - absf(u)), 0.0)
			# Natural snow mound envelope: rises from the road edges and both ends.
			var fade_u: float = smoothstep(0.0, 0.32, 1.0 - absf(u))
			var fade_v: float = smoothstep(0.0, 0.20, 1.0 - absf(v))
			var env: float = pow(fade_u * fade_v, 0.75)
			# Wind bank asymmetry and natural powder ripples
			var bank: float = 0.90 + bank_asymmetry * sin(u * 1.5 + seed_offset)
			var ripple: float = 0.06 * sin(v * 8.0 + u * 3.0 + seed_offset) + 0.03 * cos(v * 16.0 - u * 5.0)
			_top[k] = maxf(MIN_DEPTH, h * env * (bank + ripple))
			var soft: float = smoothstep(0.0, PACKED_RAMP_ALONG, 1.0 - absf(v)) * smoothstep(0.0, PACKED_RAMP_ACROSS, 1.0 - absf(u))
			_packed[k] = minf(_top[k], h * PACKED_FRACTION * soft)
			_uvs[k] = Vector2(u * _half_w * 0.25, along * 0.25)
	_cur = _top.duplicate()


func _build_indices() -> void:
	_indices = PackedInt32Array()
	for i in range(_rows - 1):
		for j in range(_cols - 1):
			var a: int = i * _cols + j
			var b: int = a + 1
			var c: int = a + _cols
			var d: int = c + 1
			# Godot front faces wind clockwise seen from the front (here: from above). Which order
			# that is depends on the handedness of (right, forward); fixed per drift in _winding().
			if _winding():
				_indices.append_array([a, b, c, b, d, c])
			else:
				_indices.append_array([a, c, b, b, c, d])


func _winding() -> bool:
	if _rows < 2:
		return true
	# right x forward points down for a clockwise-from-above (a, b, c) triangle
	return _row_r[0].cross(_row_f[0]).y < 0.0


func _packed_depth(k: int) -> float:
	return _packed[k]


func _update_mesh() -> void:
	if _rows < 2 or _mesh_inst == null:
		return
	var n: int = _rows * _cols
	var verts := PackedVector3Array()
	verts.resize(n)
	var colors := PackedColorArray()
	colors.resize(n)
	for k in range(n):
		verts[k] = _base[k] + Vector3(0.0, _cur[k], 0.0)
		var packed: float = _packed_depth(k)
		var loose: float = maxf(_top[k] - packed, 0.001)
		var compaction: float = clampf(1.0 - (_cur[k] - packed) / loose, 0.0, 1.0)
		colors[k] = snow_color.lerp(packed_color, compaction * 0.85)
	var normals := PackedVector3Array()
	normals.resize(n)
	for i in range(_rows):
		for j in range(_cols):
			var k: int = i * _cols + j
			var l: Vector3 = verts[i * _cols + maxi(j - 1, 0)]
			var r: Vector3 = verts[i * _cols + mini(j + 1, _cols - 1)]
			var bk: Vector3 = verts[maxi(i - 1, 0) * _cols + j]
			var fw: Vector3 = verts[mini(i + 1, _rows - 1) * _cols + j]
			var nrm: Vector3 = (fw - bk).cross(r - l)
			if nrm.y < 0.0:
				nrm = -nrm
			normals[k] = nrm.normalized() if nrm.length() > 1e-6 else Vector3.UP
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_INDEX] = _indices
	var mesh := _mesh_inst.mesh as ArrayMesh
	if mesh == null:
		mesh = ArrayMesh.new()
		_mesh_inst.mesh = mesh
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_inst.material_override = _get_material()
	_mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _get_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		var sand_norm: Texture2D = load("res://materials/sand_normal.png") as Texture2D
		if sand_norm:
			_material.normal_enabled = true
			_material.normal_texture = sand_norm
			_material.normal_scale = 0.35
			_material.uv1_scale = Vector3(0.25, 0.25, 0.25)
			_material.uv1_triplanar = true
		_material.vertex_color_use_as_albedo = true
		_material.metallic = 0.01
	_material.albedo_color = Color.WHITE
	_material.roughness = roughness
	return _material


func _update_packed_collision() -> void:
	if _rows < 2 or _packed_body == null:
		return
	var faces := PackedVector3Array()
	for t in range(0, _indices.size(), 3):
		for q in range(3):
			var k: int = _indices[t + q]
			faces.append(_base[k] + Vector3(0.0, _packed_depth(k), 0.0))
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	(_packed_body.get_node("Shape") as CollisionShape3D).shape = shape


func _update_trigger() -> void:
	if _rows < 2 or _col_shape == null:
		return
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for k in range(_base.size()):
		lo = lo.min(_base[k])
		hi = hi.max(_base[k] + Vector3(0.0, _top[k], 0.0))
	var box := _col_shape.shape as BoxShape3D
	# Reaches above the drift so a car rolling over the packed layer is still inside it.
	box.size = (hi - lo) + Vector3(1.0, 2.5, 1.0)
	_col_shape.position = (lo + hi) * 0.5 + Vector3(0.0, 1.0, 0.0)
	_col_shape.scale = Vector3.ONE


# ---------------------------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------------------------

## Grid coordinates (row, column, as floats) of a local-space point, or Vector2(-1, -1) if it is not
## over the drift.
func _grid_coords(lp: Vector3) -> Vector2:
	if _rows < 2:
		return Vector2(-1, -1)
	# Walk the rows for the pair the point falls between along the road.
	for i in range(_rows - 1):
		var d0: float = (lp - _row_c[i]).dot(_row_f[i])
		var d1: float = (lp - _row_c[i + 1]).dot(_row_f[i + 1])
		if d0 >= 0.0 and d1 < 0.0:
			var t: float = d0 / maxf(d0 - d1, 1e-5)
			var c: Vector3 = _row_c[i].lerp(_row_c[i + 1], t)
			var r: Vector3 = _row_r[i].lerp(_row_r[i + 1], t).normalized()
			var lat: float = (lp - c).dot(r)
			if absf(lat) > _half_w:
				return Vector2(-1, -1)
			return Vector2(float(i) + t, (lat / _half_w * 0.5 + 0.5) * float(_cols - 1))
	return Vector2(-1, -1)


func _sample(arr: PackedFloat32Array, g: Vector2) -> float:
	var i0: int = clampi(int(g.x), 0, _rows - 2)
	var j0: int = clampi(int(g.y), 0, _cols - 2)
	var fi: float = clampf(g.x - float(i0), 0.0, 1.0)
	var fj: float = clampf(g.y - float(j0), 0.0, 1.0)
	var a: float = lerpf(arr[i0 * _cols + j0], arr[i0 * _cols + j0 + 1], fj)
	var b: float = lerpf(arr[(i0 + 1) * _cols + j0], arr[(i0 + 1) * _cols + j0 + 1], fj)
	return lerpf(a, b, fi)


## Loose (not yet packed) snow depth at a world position, in metres. 0 off the drift.
func snow_depth_at(world_pos: Vector3) -> float:
	var g := _grid_coords(to_local(world_pos))
	if g.x < 0.0:
		return 0.0
	return maxf(_sample(_cur, g) - _sample(_packed, g), 0.0)


## Total snow depth (packed + loose) at a world position, for visuals that want the surface height.
func snow_surface_y(world_pos: Vector3) -> float:
	var lp := to_local(world_pos)
	var g := _grid_coords(lp)
	if g.x < 0.0:
		return -INF
	var i0: int = clampi(int(g.x), 0, _rows - 1)
	var j0: int = clampi(int(round(g.y)), 0, _cols - 1)
	return to_global(_base[i0 * _cols + j0] + Vector3(0.0, _sample(_cur, g), 0.0)).y


# ---------------------------------------------------------------------------------------------
# Runtime: carving and spray
# ---------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _bodies.is_empty():
		return
	for body in _bodies.keys():
		if not is_instance_valid(body):
			_drop_body(body)
			continue
		_carve_for(body as Node3D)
		_update_spray(body as Node3D, _bodies[body] as CPUParticles3D)
	_since_rebuild += delta
	if _dirty and _since_rebuild >= REBUILD_INTERVAL:
		_since_rebuild = 0.0
		_dirty = false
		_update_mesh()


## Contact points of a car: its four wheel pivots if it has them, else its origin.
func _wheel_points(body: Node3D) -> Array:
	var pts: Array = []
	var vis := body.get_node_or_null("Visuals") as Node3D
	if vis:
		for nm in ["WheelPivotFL", "WheelPivotFR", "WheelPivotRL", "WheelPivotRR"]:
			var p := vis.get_node_or_null(nm) as Node3D
			if p:
				pts.append(p.global_position)
	if pts.is_empty():
		pts.append(body.global_position)
	return pts


func _carve_for(body: Node3D) -> void:
	var vis := body.get_node_or_null("Visuals") as Node3D
	var basis: Basis = (vis.global_transform.basis if vis else body.global_transform.basis).orthonormalized()
	# Wheels press the powder down to the packed layer.
	for wp in _wheel_points(body):
		_carve_disc(to_local(wp), WHEEL_RADIUS, 0.0)
	# The chassis plows a trench a little above the packed layer: the snow cannot stand inside the
	# car's underbody, which sits roughly a hand's width above where the tyres run.
	var fwd: Vector3 = -basis.z
	for s in [-0.7, -0.2, 0.3]:
		_carve_disc(to_local(body.global_position + fwd * float(s)), 0.55, 0.12)


## Lowers the snow within `radius` of local point `lp` to the packed layer plus `clearance`, and
## banks a share of what was removed onto a ring just outside it.
func _carve_disc(lp: Vector3, radius: float, clearance: float) -> void:
	var g := _grid_coords(lp)
	if g.x < 0.0:
		return
	var reach: int = int(ceil((radius + BERM_WIDTH) / CELL)) + 1
	var ci: int = int(round(g.x))
	var cj: int = int(round(g.y))
	var removed := 0.0
	var berm_cells: Array[int] = []
	for i in range(maxi(ci - reach, 0), mini(ci + reach, _rows - 1) + 1):
		for j in range(maxi(cj - reach, 0), mini(cj + reach, _cols - 1) + 1):
			var k: int = i * _cols + j
			var off: Vector3 = _base[k] - lp
			off.y = 0.0
			var dist: float = off.length()
			if dist <= radius:
				var floor_h: float = _packed_depth(k) + clearance
				if _cur[k] > floor_h:
					removed += _cur[k] - floor_h
					_cur[k] = floor_h
					_dirty = true
			elif dist <= radius + BERM_WIDTH:
				berm_cells.append(k)
	if removed > 0.0 and not berm_cells.is_empty():
		# About a third of the displaced powder ends up in the berms; the rest is thrown as spray.
		var add: float = removed * 0.33 / float(berm_cells.size())
		for k in berm_cells:
			_cur[k] = minf(_cur[k] + add, _top[k] * 1.25 + 0.05)


func _make_spray() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "SnowSpray"
	p.emitting = false
	p.amount = 90
	p.lifetime = 0.9
	p.explosiveness = 0.0
	p.randomness = 0.5
	p.lifetime_randomness = 0.35
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.6, 0.1, 0.2)
	p.direction = Vector3(0.0, 1.0, -0.6)
	p.spread = 55.0
	p.gravity = Vector3(0.0, -9.0, 0.0)
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 4.5
	p.damping_min = 1.0
	p.damping_max = 2.5
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.7
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.35))
	sc.add_point(Vector2(0.4, 1.0))
	sc.add_point(Vector2(1.0, 1.3))
	p.scale_amount_curve = sc
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.12, 0.6, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.0)])
	p.color_ramp = grad
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	p.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(0.97, 0.98, 1.0)
	mat.albedo_texture = _puff_texture()
	p.material_override = mat
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


static var _puff_tex: Texture2D

static func _puff_texture() -> Texture2D:
	if _puff_tex == null:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in range(32):
			for x in range(32):
				var d: float = Vector2((x + 0.5) / 32.0 - 0.5, (y + 0.5) / 32.0 - 0.5).length() * 2.0
				var a: float = clampf(1.0 - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a * a * (3.0 - 2.0 * a)))
		_puff_tex = ImageTexture.create_from_image(img)
	return _puff_tex


func _update_spray(body: Node3D, spray: CPUParticles3D) -> void:
	if spray == null:
		return
	var vel: Vector3 = body.get("linear_velocity") if "linear_velocity" in body else Vector3.ZERO
	var flat := Vector3(vel.x, 0.0, vel.z)
	var speed: float = flat.length()
	var vis := body.get_node_or_null("Visuals") as Node3D
	var basis: Basis = (vis.global_transform.basis if vis else body.global_transform.basis).orthonormalized()
	var fwd: Vector3 = -basis.z
	var front: Vector3 = body.global_position + fwd * 0.9
	var depth: float = snow_depth_at(front)
	var on: bool = speed > 2.0 and depth > 0.04
	if on:
		# Thrown forward and up off the bow, harder the faster and deeper the car is ploughing.
		var flat_fwd := Vector3(fwd.x, 0.0, fwd.z)
		flat_fwd = flat_fwd.normalized() if flat_fwd.length() > 0.1 else Vector3.FORWARD
		# Emitter -Z along the car's heading, so the local (0, 1, -0.6) direction is up and ahead.
		spray.global_transform = Transform3D(Basis.looking_at(flat_fwd, Vector3.UP), front + Vector3.UP * 0.1)
		var strength: float = clampf(speed / 20.0, 0.2, 1.0) * clampf(depth / 0.5, 0.3, 1.0)
		spray.initial_velocity_min = 1.0 + 3.0 * strength
		spray.initial_velocity_max = 2.5 + 7.0 * strength
		spray.scale_amount_max = 0.4 + 0.5 * strength
	spray.emitting = on


func _on_body_entered(body: Node3D) -> void:
	if not (body is RigidBody3D or body is CharacterBody3D):
		return
	if not _bodies.has(body):
		var spray := _make_spray()
		add_child(spray, false, Node.INTERNAL_MODE_FRONT)
		spray.top_level = true
		_bodies[body] = spray
	if body.has_method("enter_snow_drift"):
		body.enter_snow_drift(self)
	elif "is_in_snow" in body:
		body.set("is_in_snow", true)


func _on_body_exited(body: Node3D) -> void:
	_drop_body(body)
	if is_instance_valid(body):
		if body.has_method("exit_snow_drift"):
			body.exit_snow_drift(self)
		elif "is_in_snow" in body:
			body.set("is_in_snow", false)


func _drop_body(body: Object) -> void:
	if not _bodies.has(body):
		return
	var spray := _bodies[body] as CPUParticles3D
	_bodies.erase(body)
	if is_instance_valid(spray):
		spray.emitting = false
		# Let the last puffs finish before removing the emitter.
		get_tree().create_timer(spray.lifetime + 0.2).timeout.connect(spray.queue_free)


# ---------------------------------------------------------------------------------------------
# Editor
# ---------------------------------------------------------------------------------------------

## Snaps this snow drift to the road or terrain surface directly underneath it.
func snap_to_ground() -> bool:
	if not is_inside_tree():
		return false
	var world := get_world_3d()
	if not world:
		return false
	if Engine.is_editor_hint() and world.space.is_valid():
		PhysicsServer3D.space_set_active(world.space, true)
	var space := world.direct_space_state
	if not space:
		return false
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 50.0, 0), global_position - Vector3(0, 100.0, 0))
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var excl: Array[RID] = [get_rid()]
	if _packed_body:
		excl.append(_packed_body.get_rid())
	query.exclude = excl
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return false
	global_position = hit.position
	return true
