extends RefCounted
## One spectator for Nyota Stadium's crowd, as a single mesh in the rest pose: standing, feet on y = 0, facing
## +z, arms hanging, at 1.86 times life size like the stands (a 3.3m person, a 1.65m hip). stadium_person.gdshader
## bends the joints for each pose and shows or hides the hair, clothes and props each spectator has; the mesh
## carries everything every spectator might need.
##
## Vertex data, read by that shader:
##   COLOR.r  part / 16   COLOR.g  region / 16   COLOR.b  style / 16   COLOR.a  aux (a flag cloth's wave)
##   UV, UV2  a limb's joints: UV = the first joint's (x, y) (shoulder, hip), UV2 = the second's (elbow, knee).
##            A head part's UV = its position in head units ((p - HEAD_C) / HEAD_R).xy and UV2.x = the z.
## The joints all lie in the plane z = 0, which is why two (x, y) pairs describe them.
## Left is +x. The numbers below are repeated in stadium_person.gdshader.

const P_BODY := 0
const P_HEAD := 1
const P_ARM_UP_L := 2
const P_ARM_LO_L := 3
const P_ARM_UP_R := 4
const P_ARM_LO_R := 5
const P_LEG_UP_L := 6
const P_LEG_LO_L := 7
const P_LEG_UP_R := 8
const P_LEG_LO_R := 9

const R_SKIN := 0
const R_SHIRT := 1
const R_SLEEVE := 2   ## shirt with long sleeves, bare arm without
const R_TROUSERS := 3
const R_SHIN := 4     ## trousers when they are long, bare leg in shorts
const R_SHOE := 5
const R_HAIR := 6
const R_ACC := 7      ## a cap or a headscarf
const R_PROP := 8
const R_FLAG := 9
const R_DRESS := 10
const R_THIGH := 11   ## trousers, bare leg under a dress

const S_ALWAYS := 0
const S_HAIR_SHORT := 1
const S_HAIR_AFRO := 2
const S_HAIR_LONG := 3
const S_CAP := 4
const S_SCARF := 5
const S_DRESS := 6
const S_PHONE := 7
const S_BOTTLE := 8
const S_FLAG := 9

const HIP_Y := 1.65
const KNEE_Y := 0.88
const ANKLE_Y := 0.17
const SHOULDER_Y := 2.64
const ELBOW_Y := 2.06
const WRIST_Y := 1.56
const SHOULDER_X := 0.40
const HIP_X := 0.16
const NECK_Y := 2.80
const HEAD_C := Vector3(0.0, 3.07, 0.02)
const HEAD_R := Vector3(0.200, 0.245, 0.215)

var _pos := PackedVector3Array()
var _nrm := PackedVector3Array()
var _col := PackedColorArray()
var _uv := PackedVector2Array()
var _uv2 := PackedVector2Array()
var _idx := PackedInt32Array()


func build() -> ArrayMesh:
	_pos.clear()
	_nrm.clear()
	_col.clear()
	_uv.clear()
	_uv2.clear()
	_idx.clear()
	_build_body()
	_build_head()
	_build_arms()
	_build_legs()
	_build_props()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _pos
	arrays[Mesh.ARRAY_NORMAL] = _nrm
	arrays[Mesh.ARRAY_COLOR] = _col
	arrays[Mesh.ARRAY_TEX_UV] = _uv
	arrays[Mesh.ARRAY_TEX_UV2] = _uv2
	arrays[Mesh.ARRAY_INDEX] = _idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# ---------------------------------------------------------------------------------------------
#  Primitives
# ---------------------------------------------------------------------------------------------

func _vert(p: Vector3, n: Vector3, part: int, region: int, style: int, aux: float, uv: Vector2, uv2: Vector2) -> int:
	_pos.append(p)
	_nrm.append(n.normalized())
	_col.append(Color(float(part) / 16.0, float(region) / 16.0, float(style) / 16.0, aux))
	_uv.append(uv)
	_uv2.append(uv2)
	return _pos.size() - 1


## A triangle wound so its front face (clockwise, (c - a) x (b - a)) looks along the vertices' normals.
func _tri(a: int, b: int, c: int) -> void:
	var gn := (_pos[c] - _pos[a]).cross(_pos[b] - _pos[a])
	var n := _nrm[a] + _nrm[b] + _nrm[c]
	if gn.dot(n) < 0.0:
		_idx.append_array([a, c, b])
	else:
		_idx.append_array([a, b, c])


## UV pair of a vertex: a limb's joints, or a head part's head-unit coordinates.
func _joint_uv(part: int, p: Vector3, ja: Vector2, jb: Vector2) -> Array:
	if part == P_HEAD:
		var h := (p - HEAD_C) / HEAD_R
		return [Vector2(h.x, h.y), Vector2(h.z, 0.0)]
	return [ja, jb]


## A vertical loft: rings of [y, rx, rz, cx, cz] (bottom to top), `segs` round each, closed at the ends
## when `cap_bottom` / `cap_top` are set. `region_fn` (y) -> region lets one loft change region along it.
func _loft(rings: Array, segs: int, part: int, region_fn: Callable, style: int, ja: Vector2, jb: Vector2, cap_bottom := false, cap_top := false) -> void:
	var grid: Array = []
	for r in rings:
		var row: Array = []
		for s in range(segs):
			var a := TAU * float(s) / float(segs)
			var p := Vector3(float(r[3]) + float(r[1]) * sin(a), float(r[0]), float(r[4]) + float(r[2]) * cos(a))
			row.append(p)
		grid.append(row)
	for i in range(rings.size() - 1):
		var r0: Array = rings[i]
		var r1: Array = rings[i + 1]
		var region: int = region_fn.call((float(r0[0]) + float(r1[0])) * 0.5)
		for s in range(segs):
			var s2 := (s + 1) % segs
			var verts: Array = []
			for pair in [[i, s], [i, s2], [i + 1, s2], [i + 1, s]]:
				var ring: Array = rings[pair[0]]
				var p: Vector3 = grid[pair[0]][pair[1]]
				var a := TAU * float(pair[1]) / float(segs)
				var n := Vector3(sin(a) / maxf(float(ring[1]), 0.001), 0.0, cos(a) / maxf(float(ring[2]), 0.001))
				# Lean the normal with the loft's taper.
				var dy := float(r1[0]) - float(r0[0])
				var dr := (float(r1[1]) + float(r1[2]) - float(r0[1]) - float(r0[2])) * 0.5
				n = n.normalized() + Vector3(0.0, -dr / maxf(absf(dy), 0.001) * 0.5, 0.0)
				var uvp := _joint_uv(part, p, ja, jb)
				verts.append(_vert(p, n, part, region, style, 0.0, uvp[0], uvp[1]))
			_tri(verts[0], verts[1], verts[2])
			_tri(verts[0], verts[2], verts[3])
	for cap in [[cap_bottom, 0, -1.0], [cap_top, rings.size() - 1, 1.0]]:
		if not cap[0]:
			continue
		var ring: Array = rings[cap[1]]
		var c := Vector3(float(ring[3]), float(ring[0]), float(ring[4]))
		var region: int = region_fn.call(float(ring[0]))
		var n := Vector3(0.0, float(cap[2]), 0.0)
		var uvc := _joint_uv(part, c, ja, jb)
		var ci := _vert(c, n, part, region, style, 0.0, uvc[0], uvc[1])
		for s in range(segs):
			var p0: Vector3 = grid[cap[1]][s]
			var p1: Vector3 = grid[cap[1]][(s + 1) % segs]
			var u0 := _joint_uv(part, p0, ja, jb)
			var u1 := _joint_uv(part, p1, ja, jb)
			var i0 := _vert(p0, n, part, region, style, 0.0, u0[0], u0[1])
			var i1 := _vert(p1, n, part, region, style, 0.0, u1[0], u1[1])
			_tri(ci, i0, i1)


## An ellipsoid (`lat` rings, `lon` round), keeping only the quads `keep` accepts (it gets the quad's
## centre in head units, or the ellipsoid's own unit direction when `head_units` is false).
func _ellipsoid(c: Vector3, r: Vector3, lat: int, lon: int, part: int, region: int, style: int, ja: Vector2, jb: Vector2, keep := Callable(), head_units := true, aux_fn := Callable()) -> void:
	var grid: Array = []
	for i in range(lat + 1):
		var th := PI * float(i) / float(lat)
		var row: Array = []
		for j in range(lon):
			var ph := TAU * float(j) / float(lon)
			var u := Vector3(sin(th) * sin(ph), cos(th), sin(th) * cos(ph))
			row.append(u)
		grid.append(row)
	for i in range(lat):
		for j in range(lon):
			var j2 := (j + 1) % lon
			var us: Array = [grid[i][j], grid[i][j2], grid[i + 1][j2], grid[i + 1][j]]
			var centre := Vector3.ZERO
			for u in us:
				centre += u as Vector3
			centre = (c + (centre / 4.0) * r)
			if keep.is_valid():
				var q: Vector3 = (centre - HEAD_C) / HEAD_R if head_units else (centre - c) / r
				if not keep.call(q):
					continue
			var verts: Array = []
			for u in us:
				var p: Vector3 = c + (u as Vector3) * r
				var n := Vector3((u as Vector3).x / r.x, (u as Vector3).y / r.y, (u as Vector3).z / r.z)
				var uvp := _joint_uv(part, p, ja, jb)
				var aux := 0.0
				if aux_fn.is_valid():
					aux = aux_fn.call(p)
				verts.append(_vert(p, n, part, region, style, aux, uvp[0], uvp[1]))
			_tri(verts[0], verts[1], verts[2])
			_tri(verts[0], verts[2], verts[3])


## A box with its own region; faces flat.
func _box(lo: Vector3, hi: Vector3, part: int, region: int, style: int, ja: Vector2, jb: Vector2) -> void:
	var c := (lo + hi) * 0.5
	var h := (hi - lo) * 0.5
	var axes := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	for a in range(3):
		for sgn in [-1.0, 1.0]:
			var n: Vector3 = (axes[a] as Vector3) * sgn
			var u: Vector3 = axes[(a + 1) % 3]
			var v: Vector3 = axes[(a + 2) % 3]
			var fc: Vector3 = c + n * h
			var pts := [fc - u * h - v * h, fc + u * h - v * h, fc + u * h + v * h, fc - u * h + v * h]
			var ids: Array = []
			for p in pts:
				var uvp := _joint_uv(part, p, ja, jb)
				ids.append(_vert(p, n, part, region, style, 0.0, uvp[0], uvp[1]))
			_tri(ids[0], ids[1], ids[2])
			_tri(ids[0], ids[2], ids[3])


# ---------------------------------------------------------------------------------------------
#  The figure
# ---------------------------------------------------------------------------------------------

func _build_body() -> void:
	# Torso: trousers to the hem at 1.80, shirt above, a neck.
	var torso := [
		[1.50, 0.23, 0.17, 0.0, 0.0], [1.64, 0.29, 0.20, 0.0, 0.0], [1.80, 0.27, 0.19, 0.0, 0.0],
		[2.20, 0.30, 0.21, 0.0, 0.0], [2.48, 0.35, 0.21, 0.0, 0.0], [2.62, 0.34, 0.18, 0.0, 0.0],
		[2.72, 0.22, 0.14, 0.0, 0.0], [2.80, 0.10, 0.10, 0.0, 0.0],
	]
	_loft(torso, 9, P_BODY, func(y: float) -> int: return R_TROUSERS if y < 1.80 else R_SHIRT, S_ALWAYS, Vector2.ZERO, Vector2.ZERO, true, false)
	var neck := [[2.76, 0.085, 0.085, 0.0, 0.01], [2.90, 0.078, 0.078, 0.0, 0.015], [3.02, 0.076, 0.076, 0.0, 0.015]]
	_loft(neck, 7, P_BODY, func(_y: float) -> int: return R_SKIN, S_ALWAYS, Vector2.ZERO, Vector2.ZERO)
	# A dress: a flared skirt from the waist to the knee.
	var skirt := [[1.10, 0.40, 0.38, 0.0, 0.0], [1.45, 0.35, 0.31, 0.0, 0.0], [1.92, 0.28, 0.21, 0.0, 0.0]]
	_loft(skirt, 9, P_BODY, func(_y: float) -> int: return R_DRESS, S_DRESS, Vector2.ZERO, Vector2.ZERO)


func _build_head() -> void:
	var none := Vector2.ZERO
	_ellipsoid(HEAD_C, HEAD_R, 6, 12, P_HEAD, R_SKIN, S_ALWAYS, none, none)
	# Short hair: a shell over the crown and round the sides, the forehead left bare. Long hair has it too.
	var short_keep := func(q: Vector3) -> bool:
		return q.y > -0.10 and not (q.z > 0.30 and absf(q.x) < 0.80 and q.y < 0.60)
	_ellipsoid(HEAD_C + Vector3(0.0, 0.006, -0.004), HEAD_R * 1.06, 5, 10, P_HEAD, R_HAIR, S_HAIR_SHORT, none, none, short_keep)
	# An afro: a big round head of hair, open at the face.
	var afro_keep := func(q: Vector3) -> bool:
		return q.y > -0.55 and not (q.z > 0.28 and absf(q.x) < 0.95 and q.y < 0.66)
	_ellipsoid(HEAD_C + Vector3(0.0, 0.03, -0.03), HEAD_R * Vector3(1.42, 1.30, 1.32), 5, 10, P_HEAD, R_HAIR, S_HAIR_AFRO, none, none, afro_keep)
	# Long hair: a curtain down the back to the shoulders.
	var curtain := [[2.42, 0.24, 0.09, 0.0, -0.21], [2.80, 0.24, 0.10, 0.0, -0.21], [3.20, 0.21, 0.10, 0.0, -0.17]]
	_loft(curtain, 8, P_HEAD, func(_y: float) -> int: return R_HAIR, S_HAIR_LONG, none, none, true, true)
	# A cap: a dome with a brim.
	var cap_keep := func(q: Vector3) -> bool:
		return q.y > 0.16
	_ellipsoid(HEAD_C + Vector3(0.0, 0.012, -0.004), HEAD_R * 1.10, 5, 10, P_HEAD, R_ACC, S_CAP, none, none, cap_keep)
	_box(Vector3(-0.17, 3.085, 0.17), Vector3(0.17, 3.118, 0.48), P_HEAD, R_ACC, S_CAP, none, none)
	# A headscarf: wrapped round the head, the face open, and a roll round the neck.
	var scarf_keep := func(q: Vector3) -> bool:
		return not (q.z > 0.10 and absf(q.x) < 0.72 and q.y > -0.60 and q.y < 0.64)
	_ellipsoid(HEAD_C + Vector3(0.0, 0.0, -0.01), HEAD_R * 1.15, 5, 10, P_HEAD, R_ACC, S_SCARF, none, none, scarf_keep)
	var wrap := [[2.70, 0.13, 0.13, 0.0, 0.01], [2.86, 0.15, 0.14, 0.0, 0.0], [2.98, 0.13, 0.12, 0.0, 0.0]]
	_loft(wrap, 8, P_HEAD, func(_y: float) -> int: return R_ACC, S_SCARF, none, none)


func _build_arms() -> void:
	for side in [1.0, -1.0]:
		var left: bool = side > 0.0
		var up_part := P_ARM_UP_L if left else P_ARM_UP_R
		var lo_part := P_ARM_LO_L if left else P_ARM_LO_R
		var sh := Vector2(side * SHOULDER_X, SHOULDER_Y)
		var el := Vector2(side * SHOULDER_X, ELBOW_Y)
		var x: float = side * SHOULDER_X
		# Upper arm: the sleeve to y = 2.30, then bare or long sleeve.
		var upper := [[2.62, 0.100, 0.100, x, 0.0], [2.45, 0.098, 0.098, x, 0.0], [2.30, 0.092, 0.092, x, 0.0], [2.06, 0.080, 0.080, x, 0.0]]
		_loft(upper, 7, up_part, func(y: float) -> int: return R_SHIRT if y > 2.30 else R_SLEEVE, S_ALWAYS, sh, el, false, false)
		_ellipsoid(Vector3(x, 2.60, 0.0), Vector3(0.102, 0.102, 0.102), 3, 7, up_part, R_SHIRT, S_ALWAYS, sh, el, Callable(), false)
		# Forearm and hand.
		var fore := [[2.06, 0.080, 0.080, x, 0.0], [1.80, 0.071, 0.071, x, 0.0], [WRIST_Y, 0.058, 0.058, x, 0.0]]
		_loft(fore, 7, lo_part, func(_y: float) -> int: return R_SLEEVE, S_ALWAYS, sh, el)
		_ellipsoid(Vector3(x, 1.47, 0.02), Vector3(0.070, 0.115, 0.055), 3, 6, lo_part, R_SKIN, S_ALWAYS, sh, el, Callable(), false)
		_ellipsoid(Vector3(x, 2.06, 0.0), Vector3(0.085, 0.085, 0.085), 3, 6, lo_part, R_SLEEVE, S_ALWAYS, sh, el, Callable(), false)


func _build_legs() -> void:
	for side in [1.0, -1.0]:
		var left: bool = side > 0.0
		var up_part := P_LEG_UP_L if left else P_LEG_UP_R
		var lo_part := P_LEG_LO_L if left else P_LEG_LO_R
		var hip := Vector2(side * HIP_X, HIP_Y)
		var knee := Vector2(side * HIP_X, KNEE_Y)
		var x: float = side * HIP_X
		var thigh := [[1.62, 0.155, 0.155, x, 0.0], [1.26, 0.132, 0.132, x, 0.0], [KNEE_Y + 0.02, 0.106, 0.106, x, 0.0]]
		_loft(thigh, 7, up_part, func(_y: float) -> int: return R_THIGH, S_ALWAYS, hip, knee)
		var shin := [[KNEE_Y + 0.02, 0.104, 0.104, x, 0.0], [0.52, 0.083, 0.083, x, 0.0], [ANKLE_Y, 0.066, 0.066, x, 0.0]]
		_loft(shin, 7, lo_part, func(_y: float) -> int: return R_SHIN, S_ALWAYS, hip, knee)
		_ellipsoid(Vector3(x, KNEE_Y, 0.01), Vector3(0.112, 0.112, 0.112), 3, 7, lo_part, R_SHIN, S_ALWAYS, hip, knee, Callable(), false)
		_ellipsoid(Vector3(x, 0.088, 0.13), Vector3(0.088, 0.088, 0.225), 3, 7, lo_part, R_SHOE, S_ALWAYS, hip, knee, Callable(), false)


func _build_props() -> void:
	# Props are held in the right hand (the right forearm moves them): a phone, a bottle, a flag.
	var x := -SHOULDER_X
	var sh := Vector2(x, SHOULDER_Y)
	var el := Vector2(x, ELBOW_Y)
	_box(Vector3(x - 0.07, 1.30, 0.05), Vector3(x + 0.07, 1.58, 0.075), P_ARM_LO_R, R_PROP, S_PHONE, sh, el)
	var bottle := [[1.28, 0.050, 0.050, x, 0.05], [1.44, 0.052, 0.052, x, 0.05], [1.58, 0.030, 0.030, x, 0.05], [1.66, 0.022, 0.022, x, 0.05]]
	_loft(bottle, 7, P_ARM_LO_R, func(_y: float) -> int: return R_PROP, S_BOTTLE, sh, el, true, true)
	# A flag: a pole along the arm's line and a cloth at its end, waving in the shader (aux is how far
	# from the pole a vertex is).
	var pole := [[-0.12, 0.016, 0.016, x, 0.03], [0.60, 0.016, 0.016, x, 0.03], [1.62, 0.016, 0.016, x, 0.03]]
	_loft(pole, 5, P_ARM_LO_R, func(_y: float) -> int: return R_PROP, S_FLAG, sh, el, true, true)
	var cols := 5
	for face in [1.0, -1.0]:
		var ids: Array = []
		for ci in range(cols + 1):
			for ri in range(2):
				var t := float(ci) / float(cols)
				var p := Vector3(x - 0.07 - 0.80 * t, 0.12 + 0.46 * float(ri), 0.03 + face * 0.004)
				ids.append(_vert(p, Vector3(0.0, 0.0, face), P_ARM_LO_R, R_FLAG, S_FLAG, t, sh, el))
		for ci in range(cols):
			var a: int = ids[ci * 2]
			var b: int = ids[ci * 2 + 1]
			var c: int = ids[ci * 2 + 3]
			var d: int = ids[ci * 2 + 2]
			_tri(a, b, c)
			_tri(a, c, d)
