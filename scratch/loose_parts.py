#!/usr/bin/env python3
"""Finds parts of a generated car body that float: every primitive the builder adds is its own connected piece of the
mesh, so a piece that touches nothing else (or a group of pieces touching only each other) hangs in the air.

    godot --headless --path . -s res://scratch/mesh_dump.gd -- res://generated/cars/x_body.res /tmp/x.json
    python3 scratch/loose_parts.py /tmp/x.json [cell=0.005] [step=0.003]

Samples each piece's surface every `step` metres and drops the samples into cells `cell` wide (twice, the second grid
offset by half a cell); two pieces with samples in one cell touch (they come within about a cell of each other). Prints
every group of pieces not joined to the biggest group: its bounds and how far it is from everything else."""
import json
import sys

import numpy as np
from scipy.spatial import cKDTree

path = sys.argv[1]
cell = 0.005
step = 0.003
for a in sys.argv[2:]:
    k, v = a.split("=")
    if k == "cell":
        cell = float(v)
    if k == "step":
        step = float(v)

surfs = json.load(open(path))
vs, ts, off = [], [], 0
for s in surfs:
    v = np.array(s["v"], dtype=np.float64).reshape(-1, 3)
    i = np.array(s["i"], dtype=np.int64).reshape(-1, 3)
    vs.append(v)
    ts.append(i + off)
    off += len(v)
V = np.concatenate(vs)
T = np.concatenate(ts)
# Weld by position, then find the connected pieces.
_, weld = np.unique(np.round(V / 1e-5).astype(np.int64), axis=0, return_inverse=True)
weld = weld.reshape(-1)
T = weld[T]
Vw = np.zeros((weld.max() + 1, 3))
Vw[weld] = V


def uf_make(n):
    return np.arange(n)


def uf_find(p, x):
    r = x
    while p[r] != r:
        r = p[r]
    while p[x] != r:
        p[x], x = r, p[x]
    return r


par = uf_make(len(Vw))
for a, b, c in T:
    ra = uf_find(par, a)
    par[uf_find(par, b)] = ra
    par[uf_find(par, c)] = ra
root = np.array([uf_find(par, t[0]) for t in T])
_, piece = np.unique(root, return_inverse=True)
npieces = piece.max() + 1
tris_per = np.bincount(piece, minlength=npieces)

# Samples: each triangle on a barycentric grid of m steps (m from its longest edge), vectorised per m.
A, B, C = Vw[T[:, 0]], Vw[T[:, 1]], Vw[T[:, 2]]
longest = np.max(np.stack([np.linalg.norm(B - A, axis=1), np.linalg.norm(C - A, axis=1),
                           np.linalg.norm(C - B, axis=1)]), axis=0)
ms = np.clip(np.ceil(longest / step).astype(int), 1, 400)
P_list, O_list = [], []
for m in np.unique(ms):
    sel = np.nonzero(ms == m)[0]
    uw = np.array([(u / m, w / m) for u in range(m + 1) for w in range(m + 1 - u)])
    for chunk in np.array_split(sel, max(1, len(sel) * len(uw) // 2_000_000 + 1)):
        a, b, c = A[chunk], B[chunk], C[chunk]
        pts = a[:, None, :] + (b - a)[:, None, :] * uw[None, :, 0:1] + (c - a)[:, None, :] * uw[None, :, 1:2]
        P_list.append(pts.reshape(-1, 3).astype(np.float32))
        O_list.append(np.repeat(piece[chunk], len(uw)).astype(np.int32))
P = np.concatenate(P_list)
O = np.concatenate(O_list)

gpar = uf_make(npieces)
for shift in (0.0, 0.5):
    q = np.floor(P / cell + shift).astype(np.int64)
    key = (q[:, 0] + 100000) * 10_000_000_000 + (q[:, 1] + 100000) * 100000 + (q[:, 2] + 50000)
    kc = np.unique(np.stack([key, O.astype(np.int64)], 1), axis=0)
    same = kc[1:, 0] == kc[:-1, 0]
    for x, y in zip(kc[:-1][same, 1], kc[1:][same, 1]):
        rx, ry = uf_find(gpar, x), uf_find(gpar, y)
        if rx != ry:
            gpar[rx] = ry
groups = {}
for c in range(npieces):
    groups.setdefault(uf_find(gpar, c), []).append(c)
main = max(groups, key=lambda g: tris_per[groups[g]].sum())
print(f"{len(P)} samples, {npieces} pieces, {len(groups)} groups; the main group has {len(groups[main])} pieces")
for g, cs in sorted(groups.items(), key=lambda kv: -tris_per[kv[1]].sum()):
    if g == main:
        continue
    mask = np.isin(O, cs)
    sub = P[mask]
    d, _ = cKDTree(P[~mask][::3]).query(sub[::3])
    lo, hi = sub.min(0), sub.max(0)
    print(f"LOOSE {len(cs)} piece(s), {tris_per[cs].sum()} tris: centre {np.round((lo + hi) / 2, 3)}, "
          f"size {np.round(hi - lo, 3)}, nearest other part {d.min() * 1000:.1f} mm")
