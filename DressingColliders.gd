extends Node
## Makes every plant and object a level draws as MultiMesh instances solid, near the road or far off it,
## and lets the smaller plants wobble when a cart runs into them. Level.gd adds it once its own runtime
## colliders are built, on every course, so no level needs regenerating for it.
##
## Each mesh's shape is worked out once from its vertices: something tall and slender (a tree, a
## saguaro, a palm, a post) gets a cylinder round its trunk, anything else a box round its lower part
## (what a cart can reach). Instances drawn twice (a near and a far MultiMesh of the same instances)
## are made solid once. Skipped: ground cover (grass, meadow tufts, flowers, pebbles: under MIN_HEIGHT
## or named in SOFT), the crowd, flags and tyre stacks (SpringProps), knockable props (KnockableProps),
## icicles, skid marks and shadow-only stand-ins.
##
## The colliders go into one StaticBody3D per CELL, split into rock and plant bodies (their `surface`
## meta), shapes added through shape owners rather than as thousands of nodes. An instance the Detail
## Level hides (CanyonDetail.gd and the others draw only the first N of a MultiMesh) has its collider
## off, so a cart never hits a plant it can't see.
##
## Wobble: plants up to WOBBLE_MAX_HEIGHT (not rocks) tip away from a cart that touches them and swing
## back on a damped spring about their foot, like SpringProps' flags; local scenery, not synced.

const CELL := 64.0
## Lower than this (scaled), it's ground cover: driven over, not into.
const MIN_HEIGHT := 0.5
## Not solid at all: what these names say.
const SOFT := ["grass", "groundcover", "meadow", "crowd", "flag", "stack", "lounger", "parasol", "coolbox",
	"cone", "icicle", "skid", "shadow", "giraffe", "hole", "fx", "warmup", "cloud", "particle", "spark", "water"]
## Scenery that knocks over or springs by itself (rigid bodies or springs of its own).
const SELF_MOVING := ["res://KnockablePoles.gd", "res://KnockableIce.gd", "res://KnockableProps.gd", "res://SpringProps.gd"]
## Rigid: rocks and built things (they never wobble).
const ROCKY := ["rock", "boulder", "block", "stone", "scree", "pebble", "mound", "ridge", "divider", "lamp",
	"butte", "spire", "hoodoo", "formation", "slab", "crate", "barrier"]
const WOBBLE_MAX_HEIGHT := 5.5
## Brush (ferns, by their mesh's file name; not tree ferns): not solid. A cart drives through it, bends
## it right over and loses BRUSH_DRAG of its speed entering each one.
const BRUSH := ["fern"]
const BRUSH_NOT := ["tree_fern", "treefern"]
const BRUSH_LEAN := 1.05
const BRUSH_KICK := 0.25
const BRUSH_DRAG := 0.035
## The spring: stiffness, damping, how far it can lean (radians), how hard a cart's speed kicks it.
const SPRING_K := 55.0
const SPRING_DAMP := 4.5
const MAX_LEAN := 0.38
const KICK := 0.07
const CART_RADIUS := 1.2

## mesh instance id -> {kind, r, h, centre, size} in the mesh's own frame (see _mesh_shape).
var _mesh_info := {}
var _shape_cache := {}
var _bodies := {}
## Per MultiMesh that owns instances: [mmi, [[body, owner id] per instance index or null], last count].
var _owned: Array = []
## Wobbling plants: entries [mmis (Array), index, rest Transform3D, foot Vector3, radius, axis, angle, speed,
## brush bool];
## the cells hold indices into it, and so does the set of those moving (an Array as a key hashes by
## its contents, which change as it swings).
var _wobble: Array = []
var _wobble_cells := {}
var _moving := {}
var _cart_prev := {}
## Cart instance id -> {wobble index: true} of the brush it was inside last tick (drag on entering).
var _brush_in := {}
var _vis_timer := 0.0
var shapes_made := 0


## Builds the colliders for everything under `level`.
func build(level: Node) -> void:
	var t0 := Time.get_ticks_msec()
	var mmis: Array = level.find_children("*", "MultiMeshInstance3D", true, false)
	# Near versions first, so the instance that owns a collider is the one drawn up close.
	mmis.sort_custom(func(a, b) -> bool: return _far_rank(a) < _far_rank(b))
	var seen := {}
	for node in mmis:
		var mmi := node as MultiMeshInstance3D
		if mmi.multimesh == null or mmi.multimesh.mesh == null or mmi.multimesh.instance_count == 0:
			continue
		if _soft(mmi):
			continue
		var info: Dictionary = _mesh_shape(mmi.multimesh.mesh)
		if info.is_empty():
			continue
		var rocky: bool = _named(mmi, ROCKY)
		var brush: bool = not rocky and _brush(mmi.multimesh.mesh)
		var mm: MultiMesh = mmi.multimesh
		var to_world: Transform3D = mmi.global_transform
		var owned: Array = []
		owned.resize(mm.instance_count)
		var any := false
		# From the buffer: the dummy renderer (a headless server, where the bots still drive into
		# things) keeps it, but answers get_instance_transform() with zeros.
		var buf: PackedFloat32Array = mm.buffer
		var stride: int = 12 + (4 if mm.use_colors else 0) + (4 if mm.use_custom_data else 0)
		if mm.transform_format != MultiMesh.TRANSFORM_3D or buf.size() < stride * mm.instance_count:
			continue
		for i in range(mm.instance_count):
			var local: Transform3D = _buffer_transform(buf, i * stride)
			var xf: Transform3D = to_world * local
			var key := Vector3i(roundi(xf.origin.x * 20.0), roundi(xf.origin.y * 20.0), roundi(xf.origin.z * 20.0))
			if seen.has(key):
				# The same plant drawn again (its far version): wobble that one too.
				var e = seen[key]
				if e is Array and (e as Array).size() > 0:
					(e[0] as Array).append(mmi)
				continue
			var sc: Vector3 = xf.basis.get_scale()
			var height: float = float(info["h"]) * sc.y
			if height < MIN_HEIGHT:
				seen[key] = []
				continue
			if brush:
				var be: Array = [[mmi], i, local, xf.origin, float(info["r"]) * maxf(sc.x, sc.z), Vector3.ZERO, 0.0, 0.0, true]
				_add_wobbler(be)
				seen[key] = be
				continue
			var shape: Shape3D = _shape_for(mmi.multimesh.mesh, info, sc)
			var basis: Basis = xf.basis.orthonormalized()
			var centre: Vector3 = xf.origin + basis * (Vector3(info["centre"]) * sc)
			var body: StaticBody3D = _body_at(level, xf.origin, rocky)
			var owner_id: int = body.create_shape_owner(body)
			body.shape_owner_add_shape(owner_id, shape)
			body.shape_owner_set_transform(owner_id, body.global_transform.affine_inverse() * Transform3D(basis if info["kind"] == "box" else Basis(), centre))
			owned[i] = [body, owner_id]
			shapes_made += 1
			any = true
			if not rocky and height <= WOBBLE_MAX_HEIGHT:
				var entry: Array = [[mmi], i, local, xf.origin, float(info["r"]) * maxf(sc.x, sc.z), Vector3.ZERO, 0.0, 0.0, false]
				_add_wobbler(entry)
				seen[key] = entry
			else:
				seen[key] = []
		if any:
			_owned.append([mmi, owned, -2, true])
	_sync_visibility()
	var brush_count := 0
	for e in _wobble:
		if e[8]:
			brush_count += 1
	print("[DressingColliders] %d colliders, %d plants wobble, %d of them brush driven through (%d ms)" % [
		shapes_made, _wobble.size(), brush_count, Time.get_ticks_msec() - t0])
	_cover_meshes.call_deferred(level)


func _add_wobbler(entry: Array) -> void:
	var foot: Vector3 = entry[3]
	var ck := Vector2i(floori(foot.x / 8.0), floori(foot.z / 8.0))
	if not _wobble_cells.has(ck):
		_wobble_cells[ck] = []
	_wobble_cells[ck].append(_wobble.size())
	_wobble.append(entry)


static func _brush(mesh: Mesh) -> bool:
	var file := mesh.resource_path.get_file().to_lower()
	for w in BRUSH_NOT:
		if file.contains(w):
			return false
	for w in BRUSH:
		if file.contains(w):
			return true
	return false


## Whether the Detail Level draws instance `index` of `mmi` (brush it doesn't draw doesn't slow anyone).
static func _drawn(mmi: MultiMeshInstance3D, index: int) -> bool:
	if not is_instance_valid(mmi) or not mmi.is_visible_in_tree():
		return false
	var count: int = mmi.multimesh.visible_instance_count
	return count < 0 or index < count


## Names of meshes that get no collider here: the ground and roads and whatever is driven on (decks,
## ramps, kickers, piers, gates: their own bodies say they are track, a second collider would read as
## off-road), water, sky, effects, decals and markings.
const MESH_SKIP := ["terrain", "road", "curb", "ground", "water", "river", "sea", "ocean", "lake", "pool", "sky",
	"cloud", "decal", "skid", "fx", "warmup", "particle", "spark", "shadow", "glow", "beam", "light", "flare",
	"grass", "meadow", "fog", "mist", "spray", "foam", "splash", "trail", "wake", "marking", "line", "chunk_", "label",
	"deck", "ramp", "jump", "kicker", "track", "pier", "gate", "checkpoint", "finish"]

## Single meshes (props placed one by one): every one gets a collider, a trimesh of its own triangles
## if it is over 5m across (a camp, a dune: driven over), else its convex hull.
var _level: Node = null

func _cover_meshes(level: Node) -> void:
	_level = level
	for i in 3:
		await get_tree().physics_frame
	if not is_instance_valid(level) or not level.is_inside_tree():
		return
	var t0 := Time.get_ticks_msec()
	var body := StaticBody3D.new()
	body.name = "DressingSolid_Props"
	body.set_meta(&"surface", "rock")
	add_child(body)
	var added := 0
	var names := PackedStringArray()
	for node in level.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree() or _under_body(mi) or _named_path(mi, MESH_SKIP):
			continue
		if mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY or _see_through(mi):
			continue
		var box: AABB = mi.global_transform * mi.mesh.get_aabb()
		if box.size.y < 0.4 or box.size.x > 400.0 or box.size.z > 400.0:
			continue
		# Something big is many things in one mesh (a camp's tents and vans) or a landform (a dune): its
		# own triangles, solid from both sides. Something small: its convex hull. Where it had colliders
		# already the overlap does no harm.
		var big: bool = maxf(box.size.x, box.size.z) > 5.0
		var shape: Shape3D
		var sc: Vector3 = mi.global_transform.basis.get_scale()
		if big:
			shape = mi.mesh.create_trimesh_shape()
			if shape:
				(shape as ConcavePolygonShape3D).backface_collision = true
		else:
			shape = mi.mesh.create_convex_shape(true, true)
		if shape == null:
			continue
		# Shapes can't be scaled: bake the node's scale into the points.
		if shape is ConvexPolygonShape3D:
			var pts := PackedVector3Array()
			for q in (shape as ConvexPolygonShape3D).points:
				pts.append(q * sc)
			(shape as ConvexPolygonShape3D).points = pts
		elif shape is ConcavePolygonShape3D:
			var faces := PackedVector3Array()
			for q in (shape as ConcavePolygonShape3D).get_faces():
				faces.append(q * sc)
			(shape as ConcavePolygonShape3D).set_faces(faces)
		var owner_id: int = body.create_shape_owner(body)
		body.shape_owner_add_shape(owner_id, shape)
		body.shape_owner_set_transform(owner_id, body.global_transform.affine_inverse() * Transform3D(mi.global_transform.basis.orthonormalized(), mi.global_transform.origin))
		added += 1
		if names.size() < 40:
			names.append(String(level.get_path_to(mi)))
	print("[DressingColliders] %d props made solid (%d ms)%s" % [added, Time.get_ticks_msec() - t0, ("\n   " + "\n   ".join(names)) if added > 0 else ""])


static func _named_path(n: Node, words: Array) -> bool:
	var s := String(n.name).to_lower()
	var p := n.get_parent()
	for k in range(3):
		if p == null:
			break
		s += " " + String(p.name).to_lower()
		p = p.get_parent()
	for w in words:
		if s.contains(w):
			return true
	return false


## Under a body (it has its own collision) or under something that moves itself (a script that
## processes: the eagle, item boxes, carts, the monorail): a collider frozen where it stood would be wrong.
func _under_body(n: Node) -> bool:
	var p := n.get_parent()
	while p and p != _level:
		if p is CollisionObject3D:
			return true
		if p.is_in_group("player_carts") or p.name == "Players":
			return true
		if p.get_script() != null and (p.has_method("_process") or p.has_method("_physics_process")):
			return true
		p = p.get_parent()
	return false


static func _see_through(mi: MeshInstance3D) -> bool:
	var mat: Material = mi.material_override
	if mat == null and mi.mesh.get_surface_count() > 0:
		mat = mi.get_active_material(0)
	if mat is BaseMaterial3D:
		return (mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	if mat is ShaderMaterial and (mat as ShaderMaterial).shader:
		var code: String = (mat as ShaderMaterial).shader.code
		return code.contains("blend_add") or code.contains("unshaded") and code.contains("ALPHA")
	return false




static func _buffer_transform(buf: PackedFloat32Array, o: int) -> Transform3D:
	return Transform3D(Vector3(buf[o], buf[o + 4], buf[o + 8]), Vector3(buf[o + 1], buf[o + 5], buf[o + 9]),
		Vector3(buf[o + 2], buf[o + 6], buf[o + 10]), Vector3(buf[o + 3], buf[o + 7], buf[o + 11]))


static func _far_rank(n: Node) -> int:
	var s := String(n.name).to_lower()
	return 1 if s.contains("far") or (s.begins_with("plants_") or s.begins_with("rocks_") or s.begins_with("tall_")) else 0


static func _named(n: Node, words: Array) -> bool:
	var s := (String(n.name) + " " + String(n.get_parent().name if n.get_parent() else "")).to_lower()
	for w in words:
		if s.contains(w):
			return true
	return false


func _soft(mmi: MultiMeshInstance3D) -> bool:
	if _named(mmi, SOFT):
		return true
	# Their own bodies are their collision, and they move their own instances: a static collider and
	# a wobble here stopped the poles dead and fought their rigid bodies for the transforms.
	var scr: Script = mmi.get_script()
	if scr != null and SELF_MOVING.has(scr.resource_path):
		return true
	# Shadow-only stand-ins draw nothing.
	return mmi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


## What a mesh needs: a trunk cylinder or a box round its lower part, from its vertices.
func _mesh_shape(mesh: Mesh) -> Dictionary:
	var id := mesh.get_instance_id()
	if _mesh_info.has(id):
		return _mesh_info[id]
	var aabb: AABB = mesh.get_aabb()
	var foot: float = maxf(aabb.position.y, 0.0)
	var h: float = aabb.end.y - foot
	var info := {}
	if h <= 0.01:
		_mesh_info[id] = info
		return info
	# How far out the lower band of the mesh reaches (the median: leaves hanging low don't count).
	var band := PackedFloat32Array()
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var reach_top: float = foot + minf(h, 2.6)
	for si in range(mesh.get_surface_count()):
		var arr := mesh.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var step: int = maxi(1, v.size() / 6000)
		for k in range(0, v.size(), step):
			var q: Vector3 = v[k]
			# The band that decides it: a tree's lower trunk; for anything up to 6m, what a cart meets
			# (a shrub's stems are thin, but its leaves hang at the cart's height).
			var b0: float = foot + (h * 0.04 if h > 6.0 else minf(0.3, h * 0.3))
			var b1: float = foot + (h * 0.22 if h > 6.0 else minf(1.8, h))
			if q.y >= b0 and q.y <= b1:
				band.append(Vector2(q.x, q.z).length())
			if q.y <= reach_top:
				lo = lo.min(q)
				hi = hi.max(q)
	if band.is_empty() or lo.x == INF:
		_mesh_info[id] = info
		return info
	band.sort()
	var r_med: float = band[band.size() / 2]
	var horiz: float = maxf(hi.x - lo.x, hi.z - lo.z) * 0.5
	if h > 4.0 * maxf(r_med, 0.01) and r_med < horiz * 0.7:
		# Tall and slender: the trunk, up to where a cart could reach (6m).
		var ch: float = minf(h, 6.0)
		info = {"kind": "cyl", "r": maxf(r_med * 0.9, 0.05), "h": h, "ch": ch, "centre": Vector3(0.0, foot + ch * 0.5, 0.0)}
	else:
		var size: Vector3 = hi - lo
		size.x *= 0.85
		size.z *= 0.85
		info = {"kind": "box", "r": horiz * 0.85, "h": h, "size": size, "centre": (lo + hi) * 0.5}
	_mesh_info[id] = info
	return info


func _shape_for(mesh: Mesh, info: Dictionary, sc: Vector3) -> Shape3D:
	var key := "%d:%d:%d" % [mesh.get_instance_id(), roundi(sc.x * 20.0), roundi(sc.y * 20.0)]
	if _shape_cache.has(key):
		return _shape_cache[key]
	var shape: Shape3D
	if info["kind"] == "cyl":
		var cyl := CylinderShape3D.new()
		cyl.radius = maxf(float(info["r"]) * maxf(sc.x, sc.z), 0.08)
		cyl.height = float(info["ch"]) * sc.y
		shape = cyl
	else:
		var box := BoxShape3D.new()
		box.size = (Vector3(info["size"]) * sc).max(Vector3(0.1, 0.1, 0.1))
		shape = box
	_shape_cache[key] = shape
	return shape


func _body_at(level: Node, p: Vector3, rocky: bool) -> StaticBody3D:
	var key := Vector3i(floori(p.x / CELL), floori(p.z / CELL), 1 if rocky else 0)
	if _bodies.has(key):
		return _bodies[key]
	var body := StaticBody3D.new()
	# No "road", "track", "ramp", "bridge"... in the name: PlayerCart would count it as track.
	body.name = "DressingSolid_%s_%d_%d" % ["Rock" if rocky else "Plant", key.x, key.y]
	body.set_meta(&"surface", "rock" if rocky else "grass")
	add_child(body)
	_bodies[key] = body
	return body


## Colliders follow what the Detail Level draws: an instance past a MultiMesh's visible count (or of a
## hidden one) is switched off.
func _sync_visibility() -> void:
	for o in _owned:
		var mmi: MultiMeshInstance3D = o[0]
		if not is_instance_valid(mmi):
			continue
		var count: int = mmi.multimesh.visible_instance_count
		if not mmi.is_visible_in_tree():
			count = 0
		elif count < 0:
			count = mmi.multimesh.instance_count
		if count == int(o[2]):
			continue
		o[2] = count
		var owned: Array = o[1]
		for i in range(owned.size()):
			var e = owned[i]
			if e == null:
				continue
			(e[0] as StaticBody3D).shape_owner_set_disabled(int(e[1]), i >= count)


func _physics_process(delta: float) -> void:
	_vis_timer -= delta
	if _vis_timer <= 0.0:
		_vis_timer = 0.5
		_sync_visibility()
	if _wobble.is_empty():
		return
	# A cart's touch: its speed from how far it moved, so remote carts count too.
	for cart in get_tree().get_nodes_in_group("player_carts"):
		var c := cart as Node3D
		if c == null:
			continue
		var pos: Vector3 = c.global_position
		var prev: Vector3 = _cart_prev.get(c.get_instance_id(), pos)
		_cart_prev[c.get_instance_id()] = pos
		var vel: Vector3 = (pos - prev) / maxf(delta, 0.001)
		var speed: float = Vector2(vel.x, vel.z).length()
		var cid: int = c.get_instance_id()
		var was_in: Dictionary = _brush_in.get(cid, {})
		var now_in := {}
		if speed < 1.0 or speed > 90.0:
			_brush_in[cid] = was_in if speed < 1.0 else now_in
			continue
		var drags: bool = c.has_method("has_physics_authority") and c.has_physics_authority()
		var ck := Vector2i(floori(pos.x / 8.0), floori(pos.z / 8.0))
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				for idx in _wobble_cells.get(ck + Vector2i(dx, dz), []):
					var e: Array = _wobble[idx]
					var foot: Vector3 = e[3]
					var d := Vector2(foot.x - pos.x, foot.z - pos.z)
					if d.length() > float(e[4]) + CART_RADIUS or absf(pos.y - foot.y) > 4.0:
						continue
					var brush: bool = e[8]
					if brush:
						if not _drawn(e[0][0], int(e[1])):
							continue
						now_in[idx] = true
						if drags and not was_in.has(idx):
							(c as RigidBody3D).linear_velocity *= 1.0 - BRUSH_DRAG
					# Tip away from the cart, about the horizontal axis across the push; brush goes over
					# along the cart's travel, the way a cart flattens it.
					var push := Vector3(d.x, 0.0, d.y).normalized() if d.length() > 0.05 else Vector3(vel.x, 0.0, vel.z).normalized()
					if brush:
						push = (push + Vector3(vel.x, 0.0, vel.z) / speed * 2.0).normalized()
					var axis: Vector3 = Vector3.UP.cross(push).normalized()
					var kick: float = BRUSH_KICK if brush else KICK
					if float(e[7]) * (axis.dot(e[5]) if (e[5] as Vector3).length() > 0.5 else 1.0) < speed * kick * 0.5:
						e[5] = axis
						e[7] = float(e[7]) + speed * kick
						_moving[idx] = true
		_brush_in[cid] = now_in
	var done: Array = []
	for idx in _moving:
		var e: Array = _wobble[idx]
		var ang: float = float(e[6])
		var spd: float = float(e[7])
		spd += (-SPRING_K * ang - SPRING_DAMP * spd) * delta
		var lean: float = BRUSH_LEAN if e[8] else MAX_LEAN
		ang = clampf(ang + spd * delta, -lean, lean)
		e[6] = ang
		e[7] = spd
		var rest: Transform3D = e[2]
		var axis: Vector3 = e[5]
		var xf := rest
		if absf(ang) > 0.0005 and axis.length() > 0.5:
			# The axis is in the world; turn it into the MultiMesh's frame.
			var mm_axis: Vector3 = ((e[0][0] as MultiMeshInstance3D).global_transform.basis.inverse() * axis).normalized()
			xf = Transform3D(Basis(mm_axis, ang) * rest.basis, rest.origin)
		for m in e[0]:
			if is_instance_valid(m):
				(m as MultiMeshInstance3D).multimesh.set_instance_transform(int(e[1]), xf)
		if absf(ang) < 0.0005 and absf(spd) < 0.002:
			done.append(idx)
	for idx in done:
		var e: Array = _wobble[idx]
		var rest: Transform3D = e[2]
		for m in e[0]:
			if is_instance_valid(m):
				(m as MultiMeshInstance3D).multimesh.set_instance_transform(int(e[1]), rest)
		_moving.erase(idx)
