extends RefCounted
## Canyon Chasm's chevron arrow sign, modelled in CSG at life size (metres, y up, the ground at y = 0, the
## arrow pointing +x, its faces toward ±z): a 10.3m board on a steel post, a swallow-tailed white board
## with two red chevrons (">" bands at 45 degrees, running through the edges too) ending in a big red
## arrowhead. It replaced a Hunyuan FBX (models/signs/300e3a6c...fbx, imported at scale 10) and keeps its
## frame: the level's ArrowSign keeps its rotation and position, only without the scale.
## regenerate_arrow_sign.gd builds the tree (`build`), lets the CSG update for a frame and bakes it to one
## mesh (`bake`) in generated/arrow_sign.res, which ArrowSign.tscn draws: the level holds no CSG.
##
## Each colour band is the sign's outline (with rounded outer corners) intersected with that band's
## chevron prism, which is deeper than the board: the faces and edges then come from the outline in the
## band's own material, and the bands' cut faces meet inside the union and drop out.

const YC := 5.6              # the board's centre line
const H := 1.0               # half the board's height
const HEAD_H := 2.0          # half the arrowhead's height
const TAIL_X := -4.9         # the tail's corners; its notch runs parallel to the chevrons
const HEAD_X := 2.05         # the arrowhead's back
const TIP_X := 5.44
const SLANT := 1.0           # how far a chevron's point runs ahead of its ends (45 degrees over H)
const DEPTH := 0.32          # the board's thickness
const ROUND := 0.14          # the outline's outer corners
const POST_X := -0.73
const POST_R := 0.24
const POST_SINK := 0.5       # the post runs this far under its foot, for uneven ground
## Band edges, where each crosses the board's top edge (white, red, white, red, white, then the red head).
const BANDS := [-4.15, -2.8, -1.55, 0.15, HEAD_X]

const WHITE := Color(0.86, 0.86, 0.84)
const RED := Color(0.64, 0.09, 0.08)
const STEEL := Color(0.46, 0.46, 0.48)

static var _mats := {}


## The sign as a CSG tree (add it to the scene tree and wait a frame before `bake`).
static func build() -> CSGCombiner3D:
	var root := CSGCombiner3D.new()
	root.name = "ArrowSignCSG"
	var edges: Array = [-100.0] + BANDS + [100.0]
	for i in edges.size() - 1:
		var mat := _mat(WHITE if i % 2 == 0 else RED, 0.0, 0.45)
		var band := CSGCombiner3D.new()
		band.add_child(_prism(_outline(), DEPTH, mat))
		var cut := _prism(_band(edges[i], edges[i + 1]), DEPTH + 1.0, mat)
		cut.operation = CSGShape3D.OPERATION_INTERSECTION
		band.add_child(cut)
		root.add_child(band)
	var post := CSGCylinder3D.new()
	post.radius = POST_R
	post.height = YC - H + POST_SINK + 0.02
	post.sides = 20
	post.smooth_faces = true
	post.position = Vector3(POST_X, (YC - H + 0.02 - POST_SINK) * 0.5, 0.0)
	post.material = _mat(STEEL, 0.6, 0.4)
	root.add_child(post)
	return root


## The mesh of a built tree that has updated: one surface per material, the materials included.
static func bake(root: CSGShape3D) -> ArrayMesh:
	var mesh: ArrayMesh = root.bake_static_mesh()
	if mesh == null:
		push_error("ArrowSignCSG: the CSG hasn't built its mesh yet")
	return mesh


## The sign's silhouette: the swallow-tailed board and the arrowhead, clockwise from the tail's top.
static func _outline() -> PackedVector2Array:
	# [point, rounded]: the outer corners are rounded, the inner ones (notch, head's shoulders) sharp.
	var pts := [
		[Vector2(TAIL_X, YC + H), true],
		[Vector2(HEAD_X, YC + H), false],
		[Vector2(HEAD_X, YC + HEAD_H), true],
		[Vector2(TIP_X, YC), true],
		[Vector2(HEAD_X, YC - HEAD_H), true],
		[Vector2(HEAD_X, YC - H), false],
		[Vector2(TAIL_X, YC - H), true],
		[Vector2(TAIL_X + SLANT, YC), false],
	]
	var out := PackedVector2Array()
	for i in pts.size():
		var p: Vector2 = pts[i][0]
		if not pts[i][1]:
			out.append(p)
			continue
		# A fillet of radius ROUND between the edges in and out of p.
		var a: Vector2 = pts[(i - 1 + pts.size()) % pts.size()][0]
		var b: Vector2 = pts[(i + 1) % pts.size()][0]
		var da := (a - p).normalized()
		var db := (b - p).normalized()
		var half := acos(clampf(da.dot(db), -1.0, 1.0)) * 0.5
		var back := ROUND / tan(half)
		var centre := p + (da + db).normalized() * ROUND / sin(half)
		var p0 := p + da * back
		var p1 := p + db * back
		var a0 := (p0 - centre).angle()
		var sweep := wrapf((p1 - centre).angle() - a0, -PI, PI)
		for s in 7:
			out.append(centre + Vector2.from_angle(a0 + sweep * s / 6.0) * ROUND)
	return out


## The chevron band between the edges crossing the board's top at `a` and `b`, reaching well past the
## board above and below (the outline trims it).
static func _band(a: float, b: float) -> PackedVector2Array:
	var reach := 3.0
	var back := SLANT * (reach / H - 1.0)   # how far the edge has fallen back at YC ± reach
	return PackedVector2Array([
		Vector2(a - back, YC + reach), Vector2(b - back, YC + reach), Vector2(b + SLANT, YC),
		Vector2(b - back, YC - reach), Vector2(a - back, YC - reach), Vector2(a + SLANT, YC)])


## `poly` (in x, y) extruded `depth` along z, centred on z = 0.
static func _prism(poly: PackedVector2Array, depth: float, mat: Material) -> CSGPolygon3D:
	var p := CSGPolygon3D.new()
	p.polygon = poly
	p.depth = depth
	p.position = Vector3(0, 0, depth * 0.5)
	p.material = mat
	return p


static func _mat(col: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var key := col.to_html(false)
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.resource_name = "arrow_sign_" + key
		m.albedo_color = col
		m.metallic = metallic
		m.roughness = roughness
		_mats[key] = m
	return _mats[key]
