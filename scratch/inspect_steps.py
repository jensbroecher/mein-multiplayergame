def main():
    verts = []
    with open("scratch/fbx_footbridge.obj") as f:
        for line in f:
            if line.startswith("v "):
                verts.append([float(x) for x in line.split()[1:]])

    import numpy as np
    pts = np.array(verts)

    # Let's inspect the walkway surface in X in [7, 17], |Z| < 2.0
    mask = (pts[:, 0] > 7.0) & (pts[:, 0] < 17.0) & (np.abs(pts[:, 2]) < 2.0) & (pts[:, 1] > 0.1)
    pts_leg = pts[mask]
    
    # Sort by X
    pts_leg = pts_leg[np.argsort(pts_leg[:, 0])]
    print("X, Y, Z of walkway surface points along one ramp/stair leg:")
    for p in pts_leg:
        # print if it's near top of the local surface
        print(f"X={p[0]:6.2f}, Y={p[1]:6.2f}, Z={p[2]:6.2f}")

if __name__ == "__main__":
    main()
