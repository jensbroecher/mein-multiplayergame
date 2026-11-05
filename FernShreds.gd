extends Node3D
## A fern a cart tears through comes apart into its fronds: DressingColliders hides the fern's instance and calls
## `shred`, and each frond flies off on its own (out from the fern's middle, along the cart's travel, up), tumbling,
## slowed by the air, and shrinks away (LIFE). Local scenery, like the brush's bend: each peer shreds the ferns it
## sees carts tear through; nothing is synced.
##
## A fern's mesh is split once into its connected pieces (`split`: triangles sharing a corner, or a corner's
## position, are one piece) and the pieces grouped by their bearing from the fern's middle into fronds (at most
## MAX_PIECES), each re-centred on its own middle. Every piece is drawn through a MultiMesh of POOL instances in the
## fern's own material, so the fronds use the very pipeline the ferns do (a MeshInstance3D would compile another
## variant of the leaf shader the first time a fern is torn up, mid-race). Spare instances sit collapsed at zero size.

const POOL := 8
const MAX_PIECES := 16
## Seconds a frond flies; it shrinks away over the last SHRINK share of it.
const LIFE := Vector2(0.9, 1.5)
const SHRINK := 0.6
const GRAVITY := 9.0
const DRAG := 2.6
## m/s: out from the fern's middle, up, and the share of the cart's velocity a frond takes.
const OUT_SPEED := Vector2(2.0, 5.0)
const UP_SPEED := Vector2(2.0, 5.5)
const CARRY := 0.35
## rad/s
const SPIN := Vector2(4.0, 11.0)

## Source mesh instance id -> {pieces: [{mmi, centre, next}]}.
var _kinds := {}
## Flying fronds: [mmi, slot, pos, vel, axis, angle, spin, age, life, basis0].
var _flying: Array = []
var _rng := RandomNumberGenerator.new()
var shredded := 0


func _ready() -> void:
	_rng.randomize()
	set_process(false)


## Tears the fern drawn with `mesh` (in `material`) at world transform `xf` into its fronds, the cart moving at `cart_vel`.
func shred(mesh: Mesh, material: Material, xf: Transform3D, cart_vel: Vector3) -> void:
	var kind: Dictionary = _kind(mesh, material)
	if kind.is_empty():
		return
	shredded += 1
	var centre: Vector3 = xf.origin
	for piece in kind["pieces"]:
		var mmi: MultiMeshInstance3D = piece["mmi"]
		var slot: int = int(piece["next"])
		piece["next"] = (slot + 1) % POOL
		# Reusing a slot still flying: drop the old one.
		for i in range(_flying.size() - 1, -1, -1):
			if _flying[i][0] == mmi and int(_flying[i][1]) == slot:
				_flying.remove_at(i)
		var pos: Vector3 = xf * (piece["centre"] as Vector3)
		var out := Vector3(pos.x - centre.x, 0.0, pos.z - centre.z)
		out = out.normalized() if out.length_squared() > 0.0001 else Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
		var vel: Vector3 = out * _rng.randf_range(OUT_SPEED.x, OUT_SPEED.y) + Vector3.UP * _rng.randf_range(UP_SPEED.x, UP_SPEED.y) \
			+ Vector3(cart_vel.x, 0.0, cart_vel.z) * CARRY * _rng.randf_range(0.6, 1.2)
		var axis := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.4, 0.4), _rng.randf_range(-1, 1)).normalized()
		if axis.length_squared() < 0.01:
			axis = Vector3.RIGHT
		_flying.append([mmi, slot, pos, vel, axis, 0.0, _rng.randf_range(SPIN.x, SPIN.y) * (1.0 if _rng.randf() < 0.5 else -1.0),
			0.0, _rng.randf_range(LIFE.x, LIFE.y), xf.basis])
	set_process(true)


func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.05)
	var drag: float = exp(-DRAG * dt)
	for i in range(_flying.size() - 1, -1, -1):
		var f: Array = _flying[i]
		var mmi: MultiMeshInstance3D = f[0]
		if not is_instance_valid(mmi):
			_flying.remove_at(i)
			continue
		var age: float = float(f[7]) + dt
		var life: float = f[8]
		if age >= life:
			mmi.multimesh.set_instance_transform(int(f[1]), _collapsed())
			_flying.remove_at(i)
			continue
		var vel: Vector3 = f[3]
		vel = vel * drag + Vector3.DOWN * GRAVITY * dt
		var pos: Vector3 = f[2] + vel * dt
		var angle: float = float(f[5]) + float(f[6]) * dt
		f[2] = pos
		f[3] = vel
		f[5] = angle
		f[7] = age
		var shrink: float = clampf((life - age) / (life * SHRINK), 0.0, 1.0)
		shrink = shrink * shrink * (3.0 - 2.0 * shrink)
		var b: Basis = Basis(f[4] as Vector3, angle) * (f[9] as Basis)
		mmi.multimesh.set_instance_transform(int(f[1]), Transform3D(b.scaled(Vector3.ONE * maxf(shrink, 0.0001)), pos))
	if _flying.is_empty():
		set_process(false)


func _kind(mesh: Mesh, material: Material) -> Dictionary:
	var id: int = mesh.get_instance_id()
	if _kinds.has(id):
		return _kinds[id]
	var kind := {}
	var parts: Array = split(mesh)
	if parts.is_empty():
		_kinds[id] = kind
		return kind
	var pieces: Array = []
	for part in parts:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = part["mesh"]
		mm.instance_count = POOL
		for k in POOL:
			mm.set_instance_transform(k, _collapsed())
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "FernShred_%d" % pieces.size()
		mmi.multimesh = mm
		if material:
			mmi.material_override = material
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# The pieces fly anywhere round the plants: the box is the whole level's.
		mmi.custom_aabb = AABB(Vector3(-5000, -500, -5000), Vector3(10000, 1500, 10000))
		add_child(mmi)
		pieces.append({"mmi": mmi, "centre": part["centre"], "next": 0})
	kind["pieces"] = pieces
	_kinds[id] = kind
	return kind


static func _collapsed() -> Transform3D:
	return Transform3D(Basis().scaled(Vector3.ONE * 0.0001), Vector3(0.0, -1000.0, 0.0))


## Splits a mesh's first surface into its fronds: connected pieces (shared corners or corner positions), grouped
## by their bearing from the mesh's middle into at most MAX_PIECES, each re-centred on its own middle.
## [{mesh, centre (in the mesh's frame), tris}].
static func split(mesh: Mesh) -> Array:
	if mesh == null or mesh.get_surface_count() == 0:
		return []
	var arr: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if idx.is_empty():
		idx.resize(verts.size())
		for i in verts.size():
			idx[i] = i
	var parent := PackedInt32Array()
	parent.resize(verts.size())
	for i in verts.size():
		parent[i] = i
	var weld := {}
	for i in verts.size():
		var q: Vector3 = verts[i]
		var key := Vector3i(roundi(q.x * 1000.0), roundi(q.y * 1000.0), roundi(q.z * 1000.0))
		if weld.has(key):
			_union(parent, i, int(weld[key]))
		else:
			weld[key] = i
	for t in range(0, idx.size() - 2, 3):
		_union(parent, idx[t], idx[t + 1])
		_union(parent, idx[t], idx[t + 2])
	# Pieces: their triangles and middles.
	var piece_tris := {}
	var piece_sum := {}
	for t in range(0, idx.size() - 2, 3):
		var r: int = _find(parent, idx[t])
		# (A packed array in a Dictionary is copied on write: append to it and put it back.)
		var pt: PackedInt32Array = piece_tris.get(r, PackedInt32Array())
		pt.append(t)
		piece_tris[r] = pt
		piece_sum[r] = piece_sum.get(r, Vector3.ZERO) + (verts[idx[t]] + verts[idx[t + 1]] + verts[idx[t + 2]]) / 3.0
	# Grouped by bearing (a frond's pinnae are pieces of their own): as many bins as fronds, at most MAX_PIECES.
	var roots: Array = piece_tris.keys()
	var bins: int = mini(roots.size(), MAX_PIECES)
	var groups := {}
	for r in roots:
		var c: Vector3 = piece_sum[r] / float((piece_tris[r] as PackedInt32Array).size())
		var b: int = clampi(int(floor((atan2(c.z, c.x) + PI) / TAU * bins)), 0, bins - 1)
		var gt: PackedInt32Array = groups.get(b, PackedInt32Array())
		gt.append_array(piece_tris[r])
		groups[b] = gt
	var out: Array = []
	for b in groups:
		var tris: PackedInt32Array = groups[b]
		var remap := {}
		var order := PackedInt32Array()
		var centre := Vector3.ZERO
		for t in tris:
			for k in 3:
				var v: int = idx[t + k]
				if not remap.has(v):
					remap[v] = order.size()
					order.append(v)
					centre += verts[v]
		centre /= float(maxi(order.size(), 1))
		var na: Array = []
		na.resize(Mesh.ARRAY_MAX)
		for a in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
			if arr[a] == null:
				continue
			na[a] = _pick(arr[a], order, 4 if a == Mesh.ARRAY_TANGENT else 1)
		var pv: PackedVector3Array = na[Mesh.ARRAY_VERTEX]
		for i in pv.size():
			pv[i] -= centre
		na[Mesh.ARRAY_VERTEX] = pv
		var ni := PackedInt32Array()
		for t in tris:
			for k in 3:
				ni.append(int(remap[idx[t + k]]))
		na[Mesh.ARRAY_INDEX] = ni
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, na)
		am.surface_set_material(0, mesh.surface_get_material(0))
		out.append({"mesh": am, "centre": centre, "tris": tris.size()})
	return out


static func _pick(src, order: PackedInt32Array, width: int):
	if src is PackedVector3Array:
		var o := PackedVector3Array()
		for v in order:
			o.append(src[v])
		return o
	if src is PackedVector2Array:
		var o2 := PackedVector2Array()
		for v in order:
			o2.append(src[v])
		return o2
	if src is PackedColorArray:
		var oc := PackedColorArray()
		for v in order:
			oc.append(src[v])
		return oc
	var of := PackedFloat32Array()
	for v in order:
		for k in width:
			of.append(src[v * width + k])
	return of


static func _find(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


static func _union(parent: PackedInt32Array, a: int, b: int) -> void:
	var ra: int = _find(parent, a)
	var rb: int = _find(parent, b)
	if ra != rb:
		parent[ra] = rb
