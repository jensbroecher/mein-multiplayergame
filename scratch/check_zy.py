with open("scratch/fbx_ramp.obj") as f:
    verts = [list(map(float, l.split()[1:])) for l in f if l.startswith("v ")]

for target_x in [0.0, 4.0]:
    pts = [v for v in verts if abs(v[0] - target_x) < 0.25]
    print(f"\n================ Slice at X = {target_x} ================")
    # Sort by Z, then print (Z, Y)
    pts.sort(key=lambda v: (round(v[2], 1), round(v[1], 1)))
    # print grouped by Z
    z_groups = {}
    for p in pts:
        zg = round(p[2] * 2.0) / 2.0
        z_groups.setdefault(zg, []).append(p[1])
    for zg in sorted(z_groups.keys()):
        ys = sorted(z_groups[zg])
        print(f"Z={zg:5.1f} -> Y in [{min(ys):.2f}, {max(ys):.2f}] (samples: {[round(y, 2) for y in ys[:5]]})")
