with open("scratch/fbx_ramp.obj") as f:
    verts = [list(map(float, l.split()[1:])) for l in f if l.startswith("v ")]

# Look at side view:
# What are the lines bounding the object?
# Let's find distinct Y levels along X for a few slices:
for x in [-12, -8, -4, 0, 4, 8]:
    slice_v = [v for v in verts if abs(v[0] - x) < 0.2]
    # cluster Y values
    ys = sorted([v[1] for v in slice_v])
    clusters = []
    for y in ys:
        if not clusters or abs(clusters[-1] - y) > 0.3:
            clusters.append(y)
    print(f"X={x:3d}: Y clusters = {[round(c, 2) for c in clusters]}")
