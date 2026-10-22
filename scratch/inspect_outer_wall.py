def main():
    verts = []
    with open("scratch/fbx_footbridge.obj") as f:
        for line in f:
            if line.startswith("v "):
                verts.append([float(x) for x in line.split()[1:]])

    import numpy as np
    pts = np.array(verts)

    # Let's check points with Z > 7.1
    outer = pts[pts[:, 2] > 7.1]
    print(f"Total vertices with Z > 7.1: {len(outer)}")
    # Distinct X coords
    xs = sorted(list(set(np.round(outer[:, 0], 2))))
    print(f"Unique X coords on outer wall: {len(xs)}")
    for x in xs:
        ys = outer[np.abs(outer[:, 0] - x) < 0.05, 1]
        print(f"X={x:6.2f}: Ys={sorted(list(set(np.round(ys, 2))))}")

if __name__ == "__main__":
    main()
