extends RefCounted
## The Lakeside Course's rowing boat, modelled in CSG at life size (metres, bow toward -z, y up, the
## waterline at y = 0, amidships at z = 0): a 4.1m clinker-style skiff with a pointed bow and a raked
## transom, white topsides over a red boot top, a green rubbing strake, a buff-painted inside, three
## thwarts, floorboards, a little foredeck, a keel, oarlocks and a pair of oars with their blades on the
## water. It replaced a Hunyuan FBX. regenerate_lakeside.gd builds the tree (`build`), lets the CSG
## update for a frame, and bakes it to one mesh (`bake`): the level holds no CSG.
##
## The hull is primitives meeting: two upright cylinders whose overlap is the lens of the plan (pointed
## at the bow; the transom cuts its tail), an elliptic cylinder along the boat for the bilges and the
## flare of the sides, two tilted boxes for the V of the bottom, a long cylinder across the boat for the
## rocker of the keel, and another above it for the sheer (subtracted: the top edge rises to the bow).
## `_hull` builds that solid grown outward by `g`, so the same construction gives the planking's outside,
## its inside (the cavity), the boot top's skin, the strake and the keel.
##
## Faces take the material of the primitive that made them. The materials here are placeholders named
## "key:colour"; `bake` swaps in the level's material for the key and writes the colour into the vertex
## colours, with UVs in metres laid along the boat for the planks (hut_wood.gdshader).

const PLAN_R := 5.055        # the plan's two cylinders: half beam 0.72, the bow's point at z -2.15
const PLAN_DX := 4.335
const PLAN_Z := 0.45
const SEC_Y := 0.55          # the section's ellipse: widest at the sheer, the bilges rounding under it
const SEC_AX := 0.74
const SEC_AY := 0.75
const KEEL_Y := -0.15
const DEADRISE := 0.21       # the bottom's V, 12 degrees
const ROCK_R := 9.0          # the keel's rocker: a long arc rising 0.43m to the forefoot
const ROCK_Z := 0.6
const SHEER_R := 12.0        # the sheer: 0.5m amidships, 0.75 at the bow, 0.61 at the transom
const SHEER_Z := 0.3
const SHEER_Y := 0.5
const TRANSOM_Z := 1.95
const RAKE := 0.2
const T := 0.025             # the planking's thickness
const FLOOR_Y := 0.07        # the inside's flat floor, over the waterline (the bilge under it is solid)
const BOOT_Y := 0.05         # top of the red bottom paint
const OARLOCK_Z := 0.55

const WHITE := Color(0.93, 0.92, 0.88)
const BOOT := Color(0.55, 0.13, 0.09)
const STRAKE := Color(0.10, 0.30, 0.22)
const INSIDE := Color(0.80, 0.72, 0.58)
const WOOD := Color(0.62, 0.47, 0.32)
const OAR := Color(0.78, 0.66, 0.48)
const IRON := Color(0.20, 0.20, 0.21)

static var _mats := {}


## The boat as a CSG tree (add it to the scene tree and wait a frame before `bake`).
static func build() -> CSGCombiner3D:
	var root := CSGCombiner3D.new()
	root.name = "RowboatCSG"
	# The planking's outside, its top edge cut along the sheer (green, like the strake it tops).
	var white := _group([_hull(0.0, _mat("painted", WHITE)), _sheer(0.0, _mat("painted", STRAKE), CSGShape3D.OPERATION_SUBTRACTION)])
	_add(root, white, CSGShape3D.OPERATION_UNION)
	# Bottom paint: a skin 6mm proud below the boot top.
	var boot := _group([_hull(0.006, _mat("painted", BOOT)),
			_box(Vector3(0.0, BOOT_Y - 1.0, 0.0), Vector3(4.0, 2.0, 8.0), Basis(), _mat("painted", BOOT), CSGShape3D.OPERATION_INTERSECTION)])
	_add(root, boot, CSGShape3D.OPERATION_UNION)
	# The rubbing strake: 2.5cm proud, in a band 8cm deep under the sheer.
	var strake := _group([_hull(0.025, _mat("painted", STRAKE)),
			_sheer(0.08, _mat("painted", STRAKE), CSGShape3D.OPERATION_INTERSECTION),
			_sheer(0.0, _mat("painted", STRAKE), CSGShape3D.OPERATION_SUBTRACTION)])
	_add(root, strake, CSGShape3D.OPERATION_UNION)
	# The keel and stem: a bar down the middle of the hull grown 6cm.
	var keel := _group([_hull(0.06, _mat("timber", WOOD.darkened(0.25))),
			_box(Vector3(0.0, 0.0, 0.0), Vector3(0.07, 4.0, 8.0), Basis(), _mat("timber", WOOD), CSGShape3D.OPERATION_INTERSECTION),
			_sheer(-0.03, _mat("timber", WOOD), CSGShape3D.OPERATION_SUBTRACTION)])
	_add(root, keel, CSGShape3D.OPERATION_UNION)
	# Hollow it out: the inside of the planking above the floor.
	_add(root, _cavity(-T), CSGShape3D.OPERATION_SUBTRACTION)
	# Thwarts, the stern seat and the foredeck, ends let into the planking.
	var seats := CSGCombiner3D.new()
	var wood := _mat("timber", WOOD)
	for z in [-1.15, 0.12]:
		_add(seats, _box(Vector3(0.0, 0.36, z), Vector3(2.0, 0.035, 0.24), Basis(), wood, CSGShape3D.OPERATION_UNION), CSGShape3D.OPERATION_UNION)
	_add(seats, _box(Vector3(0.0, 0.38, 1.55), Vector3(2.0, 0.035, 0.72), Basis(), wood, CSGShape3D.OPERATION_UNION), CSGShape3D.OPERATION_UNION)
	_add(seats, _box(Vector3(0.0, 0.68, -1.95), Vector3(2.0, 0.035, 0.6), Basis(Vector3.RIGHT, 0.19), wood, CSGShape3D.OPERATION_UNION), CSGShape3D.OPERATION_UNION)
	# Floorboards: three slats along the middle, their undersides just into the floor.
	for x in [-0.2, 0.0, 0.2]:
		_add(seats, _box(Vector3(x, FLOOR_Y + 0.008, 0.15), Vector3(0.15, 0.024, 2.9), Basis(), _mat("timber", WOOD.lightened(0.1)), CSGShape3D.OPERATION_UNION), CSGShape3D.OPERATION_UNION)
	_add(seats, _hull(-T * 0.5, wood), CSGShape3D.OPERATION_INTERSECTION)
	_add(root, seats, CSGShape3D.OPERATION_UNION)
	# Oarlocks on the gunwale, and the oars resting in them with their blades on the water.
	for side in [-1.0, 1.0]:
		var ys := sheer_y(OARLOCK_Z)
		var pin := Vector3(side * (half_beam(OARLOCK_Z, ys) - T * 0.5), ys, OARLOCK_Z)
		_add(root, _rod(pin, pin + Vector3(0, 0.1, 0), 0.02, 12, _mat("iron", IRON)), CSGShape3D.OPERATION_UNION)
		_add(root, _oar(pin + Vector3(0, 0.07, 0), Vector3(side * 1.45, -0.55, 0.6).normalized()), CSGShape3D.OPERATION_UNION)
	return root


## The sheer's height at z.
static func sheer_y(z: float) -> float:
	return SHEER_Y + SHEER_R - sqrt(SHEER_R * SHEER_R - (z - SHEER_Z) * (z - SHEER_Z))


## Half the hull's width at z and height y (the plan's lens or the section's ellipse, the narrower).
static func half_beam(z: float, y: float) -> float:
	var plan := sqrt(maxf(PLAN_R * PLAN_R - (z - PLAN_Z) * (z - PLAN_Z), 0.0)) - PLAN_DX
	var sec := SEC_AX * sqrt(maxf(1.0 - pow((y - SEC_Y) / SEC_AY, 2.0), 0.0))
	return minf(plan, sec)


## The mesh of a built tree that has updated, with the level's materials (`material_for(key)`), the
## colour of each placeholder in the vertex colours, and UVs in metres: along the boat on the sides and
## bottom, across it on the transom (each triangle by its own facing, so a face never mixes them).
static func bake(root: CSGShape3D, material_for: Callable) -> ArrayMesh:
	var src: ArrayMesh = root.bake_static_mesh()
	var out := ArrayMesh.new()
	if src == null:
		push_error("RowboatCSG: the CSG hasn't built its mesh yet")
		return out
	for si in range(src.get_surface_count()):
		var arr := src.surface_get_arrays(si)
		var tag: PackedStringArray = src.surface_get_material(si).resource_name.split(":")
		var col := Color(tag[1])
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := idx.size() if not idx.is_empty() else v.size()
		var pv := PackedVector3Array()
		var pn := PackedVector3Array()
		var pu := PackedVector2Array()
		var pc := PackedColorArray()
		for t in range(0, count - 2, 3):
			var ids := [t, t + 1, t + 2]
			if not idx.is_empty():
				ids = [idx[t], idx[t + 1], idx[t + 2]]
			var a: Vector3 = v[ids[0]]
			var fn := (v[ids[2]] - a).cross(v[ids[1]] - a).abs()
			for i in ids:
				var p: Vector3 = v[i]
				pv.append(p)
				pn.append(n[i])
				pc.append(col)
				if fn.z > fn.x and fn.z > fn.y:
					pu.append(Vector2(p.y, p.x))
				elif fn.x >= fn.y:
					pu.append(Vector2(p.y, p.z))
				else:
					pu.append(Vector2(p.x, p.z))
		var na := []
		na.resize(Mesh.ARRAY_MAX)
		na[Mesh.ARRAY_VERTEX] = pv
		na[Mesh.ARRAY_NORMAL] = pn
		na[Mesh.ARRAY_TEX_UV] = pu
		na[Mesh.ARRAY_COLOR] = pc
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, na)
		out.surface_set_material(out.get_surface_count() - 1, material_for.call(tag[0]))
	return out


# ======================================================================================
#  Parts
# ======================================================================================

## The hull's solid, grown `g` outward: plan lens, section ellipse, the bottom's V and the keel's rocker
## meeting, cut square by the raked transom. No sheer: the caller cuts the top where it needs it.
static func _hull(g: float, mat: Material) -> CSGCombiner3D:
	var c := CSGCombiner3D.new()
	for sx in [-1.0, 1.0]:
		_add(c, _cylinder(Vector3(sx * PLAN_DX, 0.4, PLAN_Z), Basis(Vector3(PLAN_R + g, 0, 0), Vector3(0, 3.0, 0), Vector3(0, 0, PLAN_R + g)), 192, mat),
				CSGShape3D.OPERATION_INTERSECTION)
	_add(c, _cylinder(Vector3(0, SEC_Y, 0), Basis(Vector3(SEC_AX + g, 0, 0), Vector3(0, 0, 6.0), Vector3(0, -(SEC_AY + g), 0)), 64, mat),
			CSGShape3D.OPERATION_INTERSECTION)
	for sx in [-1.0, 1.0]:
		# A box whose underside is the plane through the keel at the deadrise, rising toward this side.
		var b := Basis(Vector3.BACK, sx * DEADRISE)
		var keel := Vector3(0, KEEL_Y - g, 0)
		_add(c, _box(keel + b * Vector3(0, 2.0, 0), Vector3(4.0, 4.0, 8.0), b, mat, CSGShape3D.OPERATION_INTERSECTION), CSGShape3D.OPERATION_INTERSECTION)
	_add(c, _cylinder(Vector3(0, KEEL_Y + ROCK_R, ROCK_Z), Basis(Vector3(0, 0, ROCK_R + g), Vector3(4.0, 0, 0), Vector3(0, ROCK_R + g, 0)), 256, mat),
			CSGShape3D.OPERATION_INTERSECTION)
	var tb := Basis(Vector3.RIGHT, RAKE)
	_add(c, _box(Vector3(0, 0.3, TRANSOM_Z + g) + tb * Vector3(0, 0, 2.0), Vector3(4.0, 4.0, 4.0), tb, mat, CSGShape3D.OPERATION_SUBTRACTION),
			CSGShape3D.OPERATION_SUBTRACTION)
	return c


## The cylinder over the sheer, lowered by `drop`: subtracted it cuts the top edge, intersected it
## keeps what is above the lowered line.
static func _sheer(drop: float, mat: Material, op: int) -> CSGCylinder3D:
	var r := SHEER_R + drop
	var cyl := _cylinder(Vector3(0, SHEER_Y + SHEER_R, SHEER_Z), Basis(Vector3(0, 0, r), Vector3(4.0, 0, 0), Vector3(0, r, 0)), 360, mat)
	cyl.operation = op
	return cyl


## The inside of the planking (the hull grown by `g` < 0) above the floor: what hollowing subtracts.
static func _cavity(g: float) -> CSGCombiner3D:
	var inside := _mat("painted", INSIDE)
	return _group([_hull(g, inside),
			_box(Vector3(0, FLOOR_Y + 2.0, 0), Vector3(4.0, 4.0, 8.0), Basis(), inside, CSGShape3D.OPERATION_INTERSECTION)])


## An oar from its pivot in the oarlock along `d`: the handle and loom inboard, a leather sleeve at the
## oarlock, the shaft out to a flat blade.
static func _oar(pivot: Vector3, d: Vector3) -> CSGCombiner3D:
	var c := CSGCombiner3D.new()
	var wood := _mat("timber", OAR)
	_add(c, _rod(pivot - d * 0.78, pivot - d * 0.6, 0.018, 12, wood), CSGShape3D.OPERATION_UNION)
	_add(c, _rod(pivot - d * 0.6, pivot + d * 1.5, 0.026, 12, wood), CSGShape3D.OPERATION_UNION)
	_add(c, _rod(pivot - d * 0.12, pivot + d * 0.2, 0.031, 12, _mat("painted", Color(0.36, 0.24, 0.14))), CSGShape3D.OPERATION_UNION)
	var x := d.cross(Vector3.UP).normalized()
	var b := Basis(x, d.cross(x), d)
	_add(c, _box(pivot + d * 1.74, Vector3(0.15, 0.014, 0.56), b, wood, CSGShape3D.OPERATION_UNION), CSGShape3D.OPERATION_UNION)
	return c


static func _rod(a: Vector3, b: Vector3, r: float, sides: int, mat: Material) -> CSGCylinder3D:
	var d := b - a
	var y := d.normalized()
	var x := y.cross(Vector3.UP)
	if x.length_squared() < 1e-6:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y)
	return _cylinder((a + b) * 0.5, Basis(x * r, d, z * r), sides, mat)


## A unit cylinder (radius 1, height 1 along its y) set by `b`: its columns are the two radii and the length.
static func _cylinder(at: Vector3, b: Basis, sides: int, mat: Material) -> CSGCylinder3D:
	var cyl := CSGCylinder3D.new()
	cyl.radius = 1.0
	cyl.height = 1.0
	cyl.sides = sides
	cyl.smooth_faces = true
	cyl.material = mat
	cyl.transform = Transform3D(b, at)
	return cyl


static func _box(at: Vector3, size: Vector3, b: Basis, mat: Material, op: int) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.size = size
	box.material = mat
	box.transform = Transform3D(b, at)
	box.operation = op
	return box


## A combiner of `shapes` in order: the first is the base, each later one applies its own operation.
static func _group(shapes: Array) -> CSGCombiner3D:
	var c := CSGCombiner3D.new()
	for s in shapes:
		c.add_child(s)
	(shapes[0] as CSGShape3D).operation = CSGShape3D.OPERATION_UNION
	return c


static func _add(parent: CSGShape3D, child: CSGShape3D, op: int) -> void:
	child.operation = op if parent.get_child_count() > 0 else CSGShape3D.OPERATION_UNION
	parent.add_child(child)


## A placeholder material for `key` in `col`: one per pair, so faces of one paint share a surface.
static func _mat(key: String, col: Color) -> StandardMaterial3D:
	var tag := "%s:%s" % [key, col.to_html(false)]
	if not _mats.has(tag):
		var m := StandardMaterial3D.new()
		m.resource_name = tag
		m.albedo_color = col
		_mats[tag] = m
	return _mats[tag]
