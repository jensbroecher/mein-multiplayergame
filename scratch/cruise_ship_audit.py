# Audits a cruise liner's Blender file: coplanar faces of different parts within 5cm (z-fighting), parts touching
# nothing (floating) and transparent materials. Blender -b models/boats/X.blend --python scratch/cruise_ship_audit.py
# (scratch/cruise_ship_fix.py fixes what it finds.)
import bpy, bmesh, collections, math
from mathutils import Vector
dg = bpy.context.evaluated_depsgraph_get()
objs = [o for o in bpy.data.objects if o.type == 'MESH' and o.visible_get()]
tris = []      # (obj, mat, n, d, pts)
boxes = {}
for o in objs:
    ev = o.evaluated_get(dg)
    me = ev.to_mesh()
    mw = o.matrix_world
    me.calc_loop_triangles()
    lo = Vector((1e9,)*3); hi = Vector((-1e9,)*3)
    for v in me.vertices:
        w = mw @ v.co
        lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
    boxes[o.name] = (lo, hi)
    for t in me.loop_triangles:
        p = [mw @ me.vertices[i].co for i in t.vertices]
        n = (p[1]-p[0]).cross(p[2]-p[0])
        a = n.length * 0.5
        if a < 0.02: continue
        n.normalize()
        mi = t.material_index
        mat = o.material_slots[mi].material.name if mi < len(o.material_slots) and o.material_slots[mi].material else "none"
        tris.append((o.name, mat, n, n.dot(p[0]), p, a))
    ev.to_mesh_clear()
print("TRIS", len(tris))
# --- coplanar / near-coplanar overlaps between different objects (or materials)
buckets = collections.defaultdict(list)
for i, (on, mat, n, d, p, a) in enumerate(tris):
    k = (round(n.x*25), round(n.y*25), round(n.z*25))
    buckets[k].append(i)
pairs = collections.defaultdict(float)
closest = {}
def bb2(p, n):
    ax = Vector((1,0,0)) if abs(n.x) < 0.9 else Vector((0,1,0))
    u = n.cross(ax).normalized(); v = n.cross(u)
    us = [q.dot(u) for q in p]; vs = [q.dot(v) for q in p]
    return min(us), max(us), min(vs), max(vs), u, v
for k, idx in buckets.items():
    idx.sort(key=lambda i: tris[i][3])
    for a_i in range(len(idx)):
        i = idx[a_i]; oi, mi, ni, di, pi, ai = tris[i]
        for b_i in range(a_i+1, len(idx)):
            j = idx[b_i]; oj, mj, nj, dj, pj, aj = tris[j]
            if dj - di > 0.05: break
            if oi == oj and mi == mj: continue
            if ni.dot(nj) < 0.995: continue
            u0,u1,v0,v1,u,v = bb2(pi, ni)
            us = [q.dot(u) for q in pj]; vs = [q.dot(v) for q in pj]
            ou = min(u1, max(us)) - max(u0, min(us)); ov = min(v1, max(vs)) - max(v0, min(vs))
            if ou > 0.05 and ov > 0.05:
                key = tuple(sorted([(oi.rstrip("0123456789.").rstrip("_"), mi), (oj.rstrip("0123456789.").rstrip("_"), mj)]))
                pairs[key] += ou*ov
                closest[key] = min(closest.get(key, 9.0), dj - di)
flush = {k: v for k, v in pairs.items() if closest[k] < 0.01}
print("PARALLEL pairs within 5cm: %d; FLUSH (under 1cm apart, these z-fight): %d" % (len(pairs), len(flush)))
for k, area in sorted(flush.items(), key=lambda kv: -kv[1])[:45]:
    print("  %.1f m2, %.1fcm apart  %s  <->  %s" % (area, closest[k] * 100.0, k[0], k[1]))
# --- floating: objects whose box touches no other object's box (2cm tolerance)
names = list(boxes.keys())
float_list = []
for a in names:
    lo, hi = boxes[a]
    touch = False
    for b in names:
        if a == b: continue
        lo2, hi2 = boxes[b]
        if all(lo[i] - 0.02 <= hi2[i] and lo2[i] - 0.02 <= hi[i] for i in range(3)):
            touch = True; break
    if not touch:
        float_list.append((a, tuple(round(x,1) for x in lo), tuple(round(x,1) for x in hi)))
print("FLOATING (touching nothing):", len(float_list))
for f in float_list[:60]:
    print("  ", f)
# --- materials' blend modes
for m in bpy.data.materials:
    if m.blend_method != 'OPAQUE' or (m.use_nodes and any(n.type=='BSDF_PRINCIPLED' and n.inputs['Alpha'].default_value < 1.0 for n in m.node_tree.nodes)):
        print("TRANSPARENT", m.name, m.blend_method)
