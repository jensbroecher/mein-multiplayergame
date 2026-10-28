@tool
class_name ChasmRock
extends Node3D
## Canyon Chasm's rocks: sandstone slabs stacked into a shape, as the four Hunyuan FBX models they replaced
## were, but modelled as a distance field so they flow together like real rock. Each slab is a rounded
## prism (an irregular outline extruded down from its top, its edges rounded off), each boulder a squashed
## sphere; they are merged with a smooth union (`BLEND`: a fillet where two pieces meet, so a stack reads as
## one weathered mass with grooves between its beds, not shapes stuck together), roughened by a noise
## stretched along the beds, and cut flat `SINK` under the origin. The field is sampled on a `VOXEL` grid
## and meshed by surface nets (`_mesh`: a vertex in each cell the surface crosses, a quad across each grid
## edge it crosses), with normals from the field's gradient and LODs from ImporterMesh.
##
##   CLUSTER  two tall block stacks, a lower one, a big boulder and small ones round them (32 x 12 x 31m)
##   TOR      a mesa of pancake slabs stepping up and back, with a lower stack beside it (23 x 15 x 19m)
##   ARCH     two stacked legs and a lintel of slab courses laid round a flat arc (31 x 21 x 12m, along x)
##   MOSSY    grey limestone pillars leaning together on low ledges, moss on what faces up (18 x 14 x 18m)
##
## Building one takes seconds, so the mesh is baked: regenerate_canyon_chasm_rocks.gd builds every rock in
## the level into `bake_path()`, a file named by the rock's kind, seed and stretch, which the rock loads. The
## level stores only those three (re-saving the level from a generator flattened its instanced scenes and
## dropped its UIDs). A rock with no bake for its settings (a new one, or one edited in the editor) builds
## its mesh itself; run the baker again after changing the builder, or the old bakes stay in use.
##
## The origin is the middle of the base on the ground. `stretch` scales the layout (positions and sizes,
## not the rounding), so the node and its collider's body stay unscaled. Drawn by canyon_rock.gdshader
## (the Canyon Course's sandstone beds, by world height); the collider is the mesh's own triangles, surface
## meta "rock".

enum Kind { CLUSTER, TOR, ARCH, MOSSY }

const VOXEL := 0.32
const SINK := 1.0
const BLEND := 0.9           # the smooth union's reach (m): how far a fillet runs between two pieces
const MARGIN := 2.2          # a piece is stamped this far round its bounds: over the widest blend and a voxel
const FAR := 2.5             # the field where no piece reaches
const ROUGH := 0.26          # the weathering noise's depth (m)

## Pieces: [SLAB, inverse transform, rx, rz, depth, round, blend, a2, p2, a3, p3, a5, p5, aabb] or
## [BALL, inverse transform, radii, blend, aabb].
enum { SLAB, BALL }

@export var kind: Kind = Kind.CLUSTER:
	set(v):
		kind = v
		_changed()
@export var stretch := Vector3.ONE:
	set(v):
		stretch = v
		_changed()
@export var rock_seed := 1:
	set(v):
		rock_seed = v
		_changed()

const BAKE_DIR := "res://generated/canyon_chasm_rocks/"
const KIND_NAMES := ["cluster", "tor", "arch", "mossy"]

static var _materials := {}
var _rng := RandomNumberGenerator.new()
var _pieces: Array = []

func _ready() -> void:
	set_meta(&"surface", "rock")
	_show()

## Edited in the editor: show the bake for the new settings, or build it.
func _changed() -> void:
	if is_inside_tree():
		_show()

## Where the baked mesh for this kind, seed and stretch lives.
func bake_path() -> String:
	return BAKE_DIR + "%s_s%d_%d_%d_%d.res" % [KIND_NAMES[kind], rock_seed,
		roundi(stretch.x * 1000.0), roundi(stretch.y * 1000.0), roundi(stretch.z * 1000.0)]

func _show() -> void:
	for c in get_children(true):
		if c.get_meta(&"rock_part", false):
			remove_child(c)
			c.free()
	var shown: ArrayMesh
	if ResourceLoader.exists(bake_path()):
		shown = load(bake_path())
	else:
		if not Engine.is_editor_hint():
			push_warning("ChasmRock %s has no bake (%s): building it; run regenerate_canyon_chasm_rocks.tscn" % [name, bake_path()])
		shown = build_mesh()
	# The drawn mesh sits under its body, so DressingColliders doesn't give it a second collider.
	var body := StaticBody3D.new()
	body.set_meta(&"rock_part", true)
	add_child(body, false, Node.INTERNAL_MODE_FRONT)
	var shape := CollisionShape3D.new()
	shape.shape = shown.create_trimesh_shape()
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	mi.mesh = shown
	mi.material_override = _material(kind == Kind.MOSSY)
	body.add_child(mi)

## Builds the rock's surface (seconds: the field is sampled in GDScript).
func build_mesh() -> ArrayMesh:
	_rng.seed = rock_seed * 7919 + int(kind)
	_pieces.clear()
	match kind:
		Kind.CLUSTER: _cluster()
		Kind.TOR: _tor()
		Kind.ARCH: _arch()
		Kind.MOSSY: _mossy()
	return _mesh()

# --- The layouts, in the shape's own frame (before `stretch`) -------------------------------------

## A slab lying level with its top at `y`, down to `bottom`.
func _slab(x: float, z: float, y: float, bottom: float, rx: float, rz: float, blend := BLEND) -> void:
	var top := Transform3D(Basis(Vector3.UP, _rng.randf_range(-0.4, 0.4)), Vector3(x, y, z))
	_add_slab(top, rx, rz, y - bottom, blend)

## A stack of slabs from the ground to `height`, each `thick` give or take, drifting a little.
func _stack(x: float, z: float, height: float, rx: float, rz: float, thick: float, taper := 0.0) -> void:
	var y := 0.0
	var prev := -SINK
	while y < height - 0.3:
		y = minf(y + thick * _rng.randf_range(0.75, 1.25), height)
		var k := 1.0 - taper * y / height
		x += _rng.randf_range(-0.35, 0.35)
		z += _rng.randf_range(-0.35, 0.35)
		_slab(x, z, y, prev - 0.15, rx * k * _rng.randf_range(0.9, 1.08), rz * k * _rng.randf_range(0.9, 1.08))
		prev = y

func _cluster() -> void:
	_stack(-2.5, -3.5, 12.2, 5.0, 3.6, 1.7)
	_stack(-7.0, -5.0, 11.2, 3.6, 3.2, 1.6)
	_stack(7.5, -1.5, 8.0, 5.2, 4.2, 1.5, 0.15)
	_ball(Vector3(1.5, 3.6, 3.5), Vector3(5.4, 4.6, 5.0), 1.3)
	for i in 16:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(7.0, 12.5)
		var r := _rng.randf_range(1.1, 2.8)
		_ball(Vector3(cos(a) * d, r * 0.45, sin(a) * d), Vector3(r * 1.25, r * 0.85, r), 0.6)

func _tor() -> void:
	# [top, rx, rz, x, z]
	var main := [[3.2, 9.5, 8.0, 1.0, 1.0], [5.0, 8.4, 7.0, 1.4, -0.4], [7.0, 7.4, 6.2, 2.0, -1.0],
		[9.0, 6.4, 5.4, 2.5, -1.4], [11.4, 5.6, 4.6, 3.0, -2.0], [13.2, 4.6, 3.8, 3.4, -2.4], [14.6, 2.9, 2.6, 3.8, -2.2]]
	var side := [[4.0, 4.8, 4.2, -6.0, 2.5], [6.5, 4.0, 3.4, -6.4, 2.0], [8.4, 3.2, 2.7, -6.6, 1.6], [10.0, 2.3, 2.0, -6.4, 1.4]]
	for run in [main, side]:
		var prev := -SINK
		for l in run:
			_slab(l[3] * 1.15, l[4] * 1.15, l[0], prev - 0.15, l[1] * 1.2, l[2] * 1.2)
			prev = l[0]

func _arch() -> void:
	_stack(-11.5, 0.0, 8.4, 3.9, 5.2, 1.7, 0.1)
	_stack(11.8, 0.4, 8.0, 4.2, 5.6, 1.5, 0.1)
	# The lintel: thick slabs laid round a flat arc from leg to leg, overlapping so they fuse into one band,
	# then a second, shorter course on its crown. Its ends blend wide into the legs' tops.
	_course(Vector3(0, -2.0, 0), 16.4, 146.0, 34.0, 13, 3.2, 3.0)
	_course(Vector3(0, -2.0, 0), 18.6, 118.0, 62.0, 7, 2.4, 2.2)

## A course of `n` slabs round an arc about `c` (in x, y), their tops at radius `r_out`, from angle `a0`
## to `a1` (degrees), each `thick` deep and about `half` metres half across the arch.
func _course(c: Vector3, r_out: float, a0: float, a1: float, n: int, thick: float, half: float) -> void:
	for i in n:
		var t := lerpf(deg_to_rad(a0), deg_to_rad(a1), (i + 0.5) / n)
		var dir := Vector3(cos(t), sin(t), 0)
		# Local y points out of the arc, x along it.
		var basis := Basis(Vector3.BACK, t - PI * 0.5) * Basis(Vector3.UP, _rng.randf_range(-0.08, 0.08))
		var at := c + dir * (r_out + _rng.randf_range(-0.25, 0.3)) + Vector3(0, 0, _rng.randf_range(-0.4, 0.4))
		var along := r_out * deg_to_rad(absf(a1 - a0)) / n * 0.75
		var end := i == 0 or i == n - 1
		_add_slab(Transform3D(basis, at), along, half * _rng.randf_range(1.1, 1.4), thick, 1.8 if end else 1.1)

func _mossy() -> void:
	# Ledges stepping up round the pillars, then the pillars leaning together out of them.
	_slab(-4.5, 3.0, 3.0, -SINK, 5.4, 6.0)
	_slab(5.0, -1.5, 4.6, -SINK, 4.6, 5.8)
	_slab(-3.5, -5.0, 6.2, -SINK, 4.2, 3.6)
	_slab(-6.0, 4.0, 5.2, 2.8, 3.6, 3.4)
	for i in 11:
		var pos := Vector3(_rng.randf_range(-3.5, 3.5), 0, _rng.randf_range(-4.5, 4.5))
		var h := _rng.randf_range(8.5, 13.6)
		var lean := Basis(Vector3.FORWARD, _rng.randf_range(0.1, 0.3)) * Basis(Vector3.RIGHT, _rng.randf_range(-0.12, 0.12))
		var r := _rng.randf_range(1.9, 2.8)
		_add_slab(Transform3D(lean, pos + lean.y * h), r, r * _rng.randf_range(0.7, 1.0), h + SINK + 1.0, 1.0)

# --- Pieces ---------------------------------------------------------------------------------------

## `top` and the sizes in the shape's frame; `stretch` turns them into the rock's.
func _placed(top: Transform3D, size: Vector3) -> Array:
	var axes := [stretch * top.basis.x, stretch * top.basis.y, stretch * top.basis.z]
	var lens := Vector3(axes[0].length(), axes[1].length(), axes[2].length())
	var basis := Basis(axes[0] / lens.x, axes[1] / lens.y, axes[2] / lens.z).orthonormalized()
	return [Transform3D(basis, stretch * top.origin), size * lens]

func _add_slab(top: Transform3D, rx: float, rz: float, depth: float, blend: float) -> void:
	var p := _placed(top, Vector3(rx, depth, rz))
	var xf: Transform3D = p[0]
	var s: Vector3 = p[1]
	var a2 := _rng.randf_range(0.03, 0.09)
	var a3 := _rng.randf_range(0.02, 0.07)
	var a5 := _rng.randf_range(0.01, 0.04)
	var grow := 1.0 + a2 + a3 + a5
	var box := xf * AABB(Vector3(-s.x * grow, -s.y, -s.z * grow), Vector3(s.x * grow * 2.0, s.y, s.z * grow * 2.0))
	var rnd := clampf(s.y * 0.42, 0.12, 0.75)
	_pieces.append([SLAB, xf.affine_inverse(), s.x, s.z, s.y, rnd, blend,
		a2, _rng.randf() * TAU, a3, _rng.randf() * TAU, a5, _rng.randf() * TAU, box.grow(MARGIN)])

func _ball(c: Vector3, radii: Vector3, blend: float) -> void:
	var rot := Basis.from_euler(Vector3(_rng.randf_range(-0.2, 0.2), _rng.randf() * TAU, _rng.randf_range(-0.2, 0.2)))
	var p := _placed(Transform3D(rot, c), radii)
	var xf: Transform3D = p[0]
	var r: Vector3 = p[1]
	var box := xf * AABB(-r, r * 2.0)
	_pieces.append([BALL, xf.affine_inverse(), r, blend, box.grow(MARGIN)])

## The signed distance (roughly: exact along the slab's radius and its height) from piece `pc` to `p`.
static func _distance(pc: Array, p: Vector3) -> float:
	var q: Vector3 = pc[1] * p
	if pc[0] == BALL:
		var r: Vector3 = pc[2]
		var k0 := (q / r).length()
		var k1 := (q / (r * r)).length()
		return k0 * (k0 - 1.0) / maxf(k1, 1e-5)
	var rx: float = pc[2]
	var rz: float = pc[3]
	var depth: float = pc[4]
	var rnd: float = pc[5]
	var ex := q.x / rx
	var ez := q.z / rz
	var rho := sqrt(ex * ex + ez * ez)
	var th := atan2(ez, ex)
	var m: float = 1.0 + pc[7] * cos(2.0 * th + pc[8]) + pc[9] * cos(3.0 * th + pc[10]) + pc[11] * cos(5.0 * th + pc[12])
	var d2: float
	if rho > 1e-4:
		d2 = sqrt(q.x * q.x + q.z * q.z) * (1.0 - m / rho)
	else:
		d2 = -m * minf(rx, rz)
	var half := depth * 0.5
	var dy := absf(q.y + half) - half
	var a := d2 + rnd
	var b := dy + rnd
	return Vector2(maxf(a, 0.0), maxf(b, 0.0)).length() + minf(maxf(a, b), 0.0) - rnd

# --- The field and its surface ----------------------------------------------------------------------

func _mesh() -> ArrayMesh:
	var bounds: AABB = _pieces[0][-1]
	for pc in _pieces:
		bounds = bounds.merge(pc[-1])
	var g0 := bounds.position
	var nx := int(ceil(bounds.size.x / VOXEL)) + 1
	var ny := int(ceil(bounds.size.y / VOXEL)) + 1
	var nz := int(ceil(bounds.size.z / VOXEL)) + 1
	var sxy := nx * ny
	var f := PackedFloat32Array()
	f.resize(nx * ny * nz)
	f.fill(FAR)
	# Stamp each piece over its own bounds, merging smoothly.
	for pc in _pieces:
		var box: AABB = pc[-1]
		var blend: float = pc[6] if pc[0] == SLAB else pc[3]
		var i0 := maxi(int((box.position.x - g0.x) / VOXEL), 0)
		var j0 := maxi(int((box.position.y - g0.y) / VOXEL), 0)
		var k0 := maxi(int((box.position.z - g0.z) / VOXEL), 0)
		var i1 := mini(int(ceil((box.end.x - g0.x) / VOXEL)), nx - 1)
		var j1 := mini(int(ceil((box.end.y - g0.y) / VOXEL)), ny - 1)
		var k1 := mini(int(ceil((box.end.z - g0.z) / VOXEL)), nz - 1)
		for k in range(k0, k1 + 1):
			for j in range(j0, j1 + 1):
				var row := j * nx + k * sxy
				for i in range(i0, i1 + 1):
					var d := minf(_distance(pc, g0 + Vector3(i, j, k) * VOXEL), FAR)
					var o := f[row + i]
					var h := maxf(blend - absf(o - d), 0.0) / blend
					f[row + i] = minf(o, d) - h * h * blend * 0.25
	# Weathering near the surface, the bumps stretched along the beds (limestone: round), and the cut
	# under the ground.
	var noise := FastNoiseLite.new()
	noise.seed = rock_seed * 31 + int(kind)
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.24
	noise.fractal_octaves = 3
	var squash := 1.0 if kind == Kind.MOSSY else 2.4
	for k in nz:
		for j in ny:
			var y := g0.y + j * VOXEL
			var row := j * nx + k * sxy
			for i in nx:
				var v := f[row + i]
				if absf(v) < ROUGH * 3.0 + VOXEL:
					var x := g0.x + i * VOXEL
					var z := g0.z + k * VOXEL
					v += ROUGH * noise.get_noise_3d(x, y * squash, z)
				f[row + i] = maxf(v, -(y + SINK))
	return _surface(f, g0, nx, ny, nz)

## Surface nets over the field `f` (negative inside).
func _surface(f: PackedFloat32Array, g0: Vector3, nx: int, ny: int, nz: int) -> ArrayMesh:
	var sxy := nx * ny
	var corner_off := PackedInt32Array([0, 1, nx, nx + 1, sxy, sxy + 1, sxy + nx, sxy + nx + 1])
	var corner_pos := [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0),
		Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(0, 1, 1), Vector3(1, 1, 1)]
	var edges := [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]
	var cell_vert := PackedInt32Array()
	cell_vert.resize(nx * ny * nz)
	cell_vert.fill(-1)
	var verts := PackedVector3Array()
	var nrms := PackedVector3Array()
	var cells := PackedInt32Array()
	var c := PackedFloat32Array()
	c.resize(8)
	for k in nz - 1:
		for j in ny - 1:
			for i in nx - 1:
				var base := i + j * nx + k * sxy
				var inside := 0
				for n in 8:
					c[n] = f[base + corner_off[n]]
					if c[n] < 0.0:
						inside += 1
				if inside == 0 or inside == 8:
					continue
				var acc := Vector3.ZERO
				var cnt := 0
				for e in edges:
					var fa: float = c[e[0]]
					var fb: float = c[e[1]]
					if (fa < 0.0) != (fb < 0.0):
						acc += (corner_pos[e[0]] as Vector3).lerp(corner_pos[e[1]], fa / (fa - fb))
						cnt += 1
				var grad := Vector3(c[1] + c[3] + c[5] + c[7] - c[0] - c[2] - c[4] - c[6],
					c[2] + c[3] + c[6] + c[7] - c[0] - c[1] - c[4] - c[5],
					c[4] + c[5] + c[6] + c[7] - c[0] - c[1] - c[2] - c[3])
				cell_vert[base] = verts.size()
				verts.append(g0 + (Vector3(i, j, k) + acc / cnt) * VOXEL)
				nrms.append(grad.normalized())
				cells.append(base)
	# A quad across every grid edge the surface crosses, between the four cells round it, facing out.
	var idx := PackedInt32Array()
	var axes := [[1, nx, sxy], [nx, sxy, 1], [sxy, 1, nx]]   # the edge's step, then the two steps across it
	for base in cells:
		var fa := f[base]
		for a in 3:
			var step: int = axes[a][0]
			var fb := f[base + step]
			if (fa < 0.0) == (fb < 0.0):
				continue
			var u: int = axes[a][1]
			var w: int = axes[a][2]
			var q0 := cell_vert[base - u - w]
			var q1 := cell_vert[base - w]
			var q2 := cell_vert[base]
			var q3 := cell_vert[base - u]
			if q0 < 0 or q1 < 0 or q2 < 0 or q3 < 0:
				continue
			# Godot's front faces wind clockwise: a triangle's normal is (c - a) x (b - a). Taken round the
			# grid (-u-w, -w, 0, -u), q0..q3 face down axis a; flip them when the inside is at `base`. Decided
			# by the grid, not the vertices: a quad folded across a crease would turn a geometric test
			# over, wind it inwards and leave it culled, a hole.
			if fa < 0.0:
				var t := q1
				q1 = q3
				q3 = t
			# Split along the shorter diagonal.
			if verts[q0].distance_squared_to(verts[q2]) <= verts[q1].distance_squared_to(verts[q3]):
				idx.append_array([q0, q1, q2, q0, q2, q3])
			else:
				idx.append_array([q1, q2, q3, q1, q3, q0])
	# Tangents for canyon_rock.gdshader's normal map: level, round the surface.
	var tans := PackedFloat32Array()
	tans.resize(verts.size() * 4)
	for n in nrms.size():
		var t := Vector3.UP.cross(nrms[n])
		t = t.normalized() if t.length_squared() > 1e-4 else Vector3.RIGHT
		tans[n * 4] = t.x
		tans[n * 4 + 1] = t.y
		tans[n * 4 + 2] = t.z
		tans[n * 4 + 3] = 1.0
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = nrms
	arr[Mesh.ARRAY_TANGENT] = tans
	arr[Mesh.ARRAY_INDEX] = idx
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr)
	im.generate_lods(60.0, 25.0, [])
	return im.get_mesh()

static func _material(mossy: bool) -> ShaderMaterial:
	if _materials.has(mossy):
		return _materials[mossy]
	var m := ShaderMaterial.new()
	m.shader = load("res://canyon_rock.gdshader")
	m.set_shader_parameter("sand_tex", load("res://materials/sand.png"))
	m.set_shader_parameter("rock_tex", load("res://materials/dark_rock.png"))
	m.set_shader_parameter("rock_normal", load("res://generated/canyon_rock_normal.res"))
	m.set_shader_parameter("vertex_occlusion", false)
	# The FBX were pale: salmon sandstone, and a near white limestone.
	m.set_shader_parameter("tint_amount", 1.0 if mossy else 0.8)
	m.set_shader_parameter("tint", Color(0.70, 0.68, 0.62) if mossy else Color(0.88, 0.67, 0.55))
	if mossy:
		m.set_shader_parameter("moss", 0.9)
	_materials[mossy] = m
	return m
