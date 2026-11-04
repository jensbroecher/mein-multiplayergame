# Fixes a cruise liner's Blender file (models/boats/*_CruiseShip.blend) for Harbor Pier and re-exports its .glb.
# Run with Blender, headless:
#   Blender -b models/boats/AuroraPearl_CruiseShip.blend --python scratch/cruise_ship_fix.py -- [backup=<dir>] [dry=1]
# What it does, found by measuring the file (scratch/cruise_ship_audit.py lists the same problems):
#   1. Duplicates: two objects with the same materials, faces and box (to 3cm) in one place are drawn twice and fight;
#      the later one is deleted (the bow's TerraceRail_01_Bow and its cap copied Balustrade_02_Bow).
#   2. Railings (TerraceRail_*, Balustrade_*, Slide_Launch_Rail_*): each stood 6cm over its deck, the stepped aft ones
#      8-10cm out past the deck's edge in the air, and every cap 3cm over its rail. A rail is set 3cm down into the
#      deck under it and drawn 6cm inside the deck's edge; its cap comes down onto it.
#   3. Floating parts (the mast between the funnels stood 1.4m over nothing): anything touching nothing whose lowest
#      vertices have something within 5m under them is stretched down onto it.
#   4. Flush details: where two parts' faces lie in one plane (under 1cm apart, facing the same way, overlapping), the
#      smaller part (by surface area) is moved as a whole 3cm along those faces' normal, in rounds until nothing is
#      flush: the hull's accent stripes, the bridge-front headers and spandrels, the balcony bases, glass panes on
#      their frames, curtains, cap rails. Coplanar faces z-fought on the Mobile renderer. (Inflating a part along all
#      its normals moved its hidden back faces too, onto the glass behind the mullions.)
# The original .blend is copied to `backup` before it is saved. The .glb is every mesh but the Environment collection
# (the sea, lights and cameras), modifiers applied, as the original export was.

import bpy, bmesh, sys, os, shutil, collections
from mathutils import Vector

ARGS = {}
if "--" in sys.argv:
	for a in sys.argv[sys.argv.index("--") + 1:]:
		if "=" in a:
			k, v = a.split("=", 1)
			ARGS[k] = v
DRY = ARGS.get("dry") == "1"
PUSH = 0.03
SINK = 0.03
EDGE_IN = 0.06

dg = bpy.context.evaluated_depsgraph_get()
env = bpy.data.collections.get("Environment")
env_objs = set(env.objects) if env else set()


def meshes():
	return [o for o in bpy.data.objects if o.type == 'MESH' and o not in env_objs]


def world_box(o):
	ev = o.evaluated_get(bpy.context.evaluated_depsgraph_get())
	me = ev.to_mesh()
	pts = [o.matrix_world @ v.co for v in me.vertices]
	ev.to_mesh_clear()
	if not pts:
		return Vector((0, 0, 0)), Vector((0, 0, 0))
	return Vector([min(p[i] for p in pts) for i in range(3)]), Vector([max(p[i] for p in pts) for i in range(3)])


def base(name):
	return name.split(".")[0]


def make_real(o):
	"""Applies the object's modifiers into its own (single-user) mesh."""
	if o.data.users > 1:
		o.data = o.data.copy()
	if o.modifiers:
		ev = o.evaluated_get(bpy.context.evaluated_depsgraph_get())
		me = bpy.data.meshes.new_from_object(ev)
		old = o.data
		o.modifiers.clear()
		o.data = me
		if old.users == 0:
			bpy.data.meshes.remove(old)


def translate(o, d):
	o.matrix_world.translation += d


log = []

# --- 1. duplicates
boxes = {o.name: world_box(o) for o in meshes()}
groups = collections.defaultdict(list)
removed = []
for o in sorted(meshes(), key=lambda x: x.name):
	mats = tuple(sorted(s.material.name for s in o.material_slots if s.material))
	key = (mats, len(o.data.polygons))
	lo, hi = boxes[o.name]
	twin = None
	for other in groups[key]:
		l2, h2 = boxes[other]
		if all(abs(lo[i] - l2[i]) < 0.03 and abs(hi[i] - h2[i]) < 0.03 for i in range(3)):
			twin = other
			break
	if twin is not None:
		removed.append((o.name, twin))
	else:
		groups[key].append(o.name)
for name, twin in removed:
	log.append("duplicate %s of %s: deleted" % (name, twin))
	# Its cap goes with it (the twin keeps its own).
	cap = bpy.data.objects.get(base(name) + "_Cap")
	if cap is not None and cap.name != name:
		log.append("duplicate's cap %s: deleted" % cap.name)
	if not DRY:
		bpy.data.objects.remove(bpy.data.objects[name], do_unlink=True)
		if cap is not None:
			bpy.data.objects.remove(cap, do_unlink=True)
boxes = {o.name: world_box(o) for o in meshes()}

# --- 2. railings onto their decks
def is_cap(n):
	return "Cap" in base(n)


def is_rail(n):
	b = base(n)
	return (b.startswith("TerraceRail") or b.startswith("Balustrade") or b.startswith("Slide_Launch_Rail")) and not is_cap(n)


def cap_of(n):
	"""A rail's cap: TerraceRail_03_Aft -> TerraceRail_03_Aft_Cap, Balustrade_02_Bow -> BalustradeCap_02_Bow."""
	b = base(n)
	for c in [b + "_Cap", b.replace("Balustrade_", "BalustradeCap_", 1)]:
		if c != b and bpy.data.objects.get(c) is not None:
			return bpy.data.objects[c]
	return None


def support_under(lo, hi, exclude):
	"""The highest top among parts under a box's footprint (within 0.4m of it in plan), from 0.4m above its bottom
	down to 1.5m below: [top, box] or None."""
	best = None
	for n, (l2, h2) in boxes.items():
		if n in exclude or is_rail(n) or is_cap(n):
			continue
		if l2[0] > hi[0] + 0.4 or h2[0] < lo[0] - 0.4 or l2[1] > hi[1] + 0.4 or h2[1] < lo[1] - 0.4:
			continue
		top = h2[2]
		if top > lo[2] + 0.4 or top < lo[2] - 1.5:
			continue
		# A deck, not a thin post: it must be wider than the rail is thick.
		if min(h2[0] - l2[0], h2[1] - l2[1]) < 1.0:
			continue
		if best is None or top > best[0]:
			best = [top, (l2, h2), n]
	return best


rails = [n for n in boxes if is_rail(n)]
moved = 0
for n in rails:
	lo, hi = boxes[n]
	sup = support_under(lo, hi, {n})
	if sup is None:
		continue
	top, (l2, h2), sname = sup
	d = Vector((0, 0, 0))
	gap = lo[2] - top
	if -0.25 < gap and gap > -SINK + 0.005:
		d.z = (top - SINK) - lo[2]
	# Pull a rail standing past its deck's edge back inside it (its thin axis only).
	thin = 0 if (hi[0] - lo[0]) < (hi[1] - lo[1]) else 1
	if hi[thin] > h2[thin] - EDGE_IN and lo[thin] > h2[thin] - 1.0:
		d[thin] = (h2[thin] - EDGE_IN) - hi[thin]
	elif lo[thin] < l2[thin] + EDGE_IN and hi[thin] < l2[thin] + 1.0:
		d[thin] = (l2[thin] + EDGE_IN) - lo[thin]
	if d.length < 0.005:
		continue
	if abs(d[thin]) > 0.6 or abs(d.z) > 0.6:
		log.append("rail %s: move %s looks wrong (support %s), left" % (n, tuple(round(x, 3) for x in d), sname))
		continue
	moved += 1
	cap = cap_of(n)
	if not DRY:
		translate(bpy.data.objects[n], d)
		if cap is not None:
			cl, ch = boxes[cap.name]
			dc = Vector(d)
			# The cap down onto the rail's new top (1cm into it).
			dc.z = (hi[2] + d.z - 0.01) - cl[2]
			translate(cap, dc)
	log.append("rail %s on %s: moved %s" % (n, sname, tuple(round(x, 3) for x in d)))
boxes = {o.name: world_box(o) for o in meshes()}

# --- 3. floating parts stretched down
def touches(n):
	lo, hi = boxes[n]
	for m, (l2, h2) in boxes.items():
		if m != n and all(lo[i] - 0.02 <= h2[i] and l2[i] - 0.02 <= hi[i] for i in range(3)):
			return True
	return False


scene = bpy.context.scene
for n in list(boxes.keys()):
	if is_rail(n) or is_cap(n) or touches(n):
		continue
	o = bpy.data.objects[n]
	lo, hi = boxes[n]
	c = Vector(((lo[0] + hi[0]) * 0.5, (lo[1] + hi[1]) * 0.5, lo[2] - 0.01))
	hit, loc, nrm, idx, hob, mtx = scene.ray_cast(bpy.context.evaluated_depsgraph_get(), c, Vector((0, 0, -1)), distance=20.0)
	if not hit or hob is None or hob.name == n:
		log.append("floating %s: nothing within 20m under it, left" % n)
		continue
	drop = lo[2] - loc.z + 0.05
	log.append("floating %s: stretched %.2fm down onto %s" % (n, drop, hob.name))
	if DRY:
		continue
	make_real(o)
	inv = o.matrix_world.inverted()
	low_local = min((v.co for v in o.data.vertices), key=lambda v: (o.matrix_world @ v).z)
	z_cut = (o.matrix_world @ low_local).z + 0.02
	for v in o.data.vertices:
		w = o.matrix_world @ v.co
		if w.z <= z_cut:
			w.z -= drop
			v.co = inv @ w
	o.data.update()
boxes = {o.name: world_box(o) for o in meshes()}

# --- 4. flush details pushed proud
def triangles(o):
	ev = o.evaluated_get(bpy.context.evaluated_depsgraph_get())
	me = ev.to_mesh()
	me.calc_loop_triangles()
	out = []
	area = 0.0
	for t in me.loop_triangles:
		p = [o.matrix_world @ me.vertices[i].co for i in t.vertices]
		nv = (p[1] - p[0]).cross(p[2] - p[0])
		a = nv.length * 0.5
		area += a
		if a < 0.02:
			continue
		nv.normalize()
		mi = t.material_index
		mat = o.material_slots[mi].material.name if mi < len(o.material_slots) and o.material_slots[mi].material else "none"
		out.append((mat, nv, nv.dot(p[0]), p))
	ev.to_mesh_clear()
	return out, area


def coplanar_pairs(tol):
	"""Pairs of parts with faces facing the same way under `tol` apart and overlapping: {(small, big): [area, normal
	sum (area weighted, of the small part's flush faces)]}."""
	tris = []
	areas = {}
	for o in meshes():
		ts, a = triangles(o)
		areas[o.name] = a
		for t in ts:
			tris.append((o.name,) + t)
	buckets = collections.defaultdict(list)
	for i, t in enumerate(tris):
		nv = t[2]
		buckets[(round(nv.x * 25), round(nv.y * 25), round(nv.z * 25))].append(i)
	out = {}
	for idx in buckets.values():
		idx.sort(key=lambda i: tris[i][3])
		for a_i in range(len(idx)):
			oi, mi, ni, di, pi = tris[idx[a_i]]
			ax = Vector((1, 0, 0)) if abs(ni.x) < 0.9 else Vector((0, 1, 0))
			u = ni.cross(ax).normalized()
			v = ni.cross(u)
			ui = [q.dot(u) for q in pi]
			vi = [q.dot(v) for q in pi]
			for b_i in range(a_i + 1, len(idx)):
				oj, mj, nj, dj, pj = tris[idx[b_i]]
				if dj - di > tol:
					break
				if oi == oj or ni.dot(nj) < 0.995:
					continue
				uj = [q.dot(u) for q in pj]
				vj = [q.dot(v) for q in pj]
				ou = min(max(ui), max(uj)) - max(min(ui), min(uj))
				ov = min(max(vi), max(vj)) - max(min(vi), min(vj))
				if ou > 0.05 and ov > 0.05:
					small, big = (oi, oj) if areas[oi] <= areas[oj] else (oj, oi)
					e = out.setdefault((small, big), [0.0, Vector((0, 0, 0))])
					e[0] += ou * ov
					e[1] += ni * (ou * ov)
	return out


def is_sheet(o):
	"""An open surface: most of its edges are boundary edges or it encloses nothing (one-sided)."""
	bm = bmesh.new()
	bm.from_mesh(o.data)
	boundary = sum(1 for e in bm.edges if e.is_boundary)
	total = max(len(bm.edges), 1)
	bm.free()
	return boundary > total * 0.15 and not o.modifiers


def offset_along_normals(o, dist):
	make_real(o)
	bm = bmesh.new()
	bm.from_mesh(o.data)
	bm.normal_update()
	m3 = o.matrix_world.to_3x3()
	inv = m3.inverted()
	nm = m3.inverted().transposed()
	for v in bm.verts:
		wn = (nm @ v.normal).normalized()
		v.co += inv @ (wn * dist)
	bm.to_mesh(o.data)
	bm.free()
	o.data.update()


# Each round moves the smaller part of every flush pair (faces under 1cm apart, overlapping, facing the same way) as a
# whole by PUSH along the flush faces' normal, so its face stands in front of the other's; a move can land a part flush
# on something else, so the check runs again.
for rnd in range(4):
	pairs = coplanar_pairs(0.01)
	pairs = {k: v for k, v in pairs.items() if v[0] >= 0.3}
	log.append("round %d: flush pairs %d" % (rnd + 1, len(pairs)))
	if not pairs or DRY and rnd > 0:
		break
	moves = collections.defaultdict(lambda: Vector((0, 0, 0)))
	for (small, big), (area, nsum) in pairs.items():
		moves[small] += nsum
	for n, nsum in moves.items():
		if nsum.length < 1e-6:
			continue
		o = bpy.data.objects[n]
		if is_sheet(o):
			# An open sheet (a stripe laid on the curved hull, a name board) has no back faces: offset along its own
			# normals, which follows the curve (moved as a whole, its ends stayed flush where the hull turns).
			log.append("  offset sheet %s %.0fcm" % (n, PUSH * 100.0))
			if not DRY:
				offset_along_normals(o, PUSH)
			continue
		d = nsum.normalized() * PUSH
		log.append("  move %s %s" % (n, tuple(round(x, 3) for x in d)))
		if not DRY:
			translate(o, d)

for line in log:
	print("FIX", line)

if not DRY:
	src = bpy.data.filepath
	bdir = ARGS.get("backup")
	if bdir:
		os.makedirs(bdir, exist_ok=True)
		dst = os.path.join(bdir, os.path.basename(src))
		if not os.path.exists(dst):
			shutil.copy2(src, dst)
			print("FIX backup", dst)
	bpy.ops.wm.save_mainfile(filepath=src)
	glb = os.path.splitext(src)[0] + ".glb"
	bpy.ops.object.select_all(action='DESELECT')
	for o in meshes():
		o.select_set(True)
	bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', use_selection=True, export_apply=True, export_cameras=False, export_lights=False)
	print("FIX saved", src, "and exported", glb)
