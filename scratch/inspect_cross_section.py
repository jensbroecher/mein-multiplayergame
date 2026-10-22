def main():
    verts = []
    with open("scratch/fbx_footbridge.obj") as f:
        for line in f:
            if line.startswith("v "):
                verts.append([float(x) for x in line.split()[1:]])

    import numpy as np
    pts = np.array(verts)

    # Let's inspect points near X = 0 (say |X| < 1.0)
    pts_mid = pts[np.abs(pts[:, 0]) < 1.0]
    
    # Let's plot or print out (Z, Y) points
    # Round to 1 decimal place to see distinct profile points
    zy_pts = sorted(list(set([(round(p[2], 2), round(p[1], 2)) for p in pts_mid])))
    print("Cross section at X=0 (Z, Y):")
    for z, y in sorted(zy_pts, key=lambda p: (p[0], p[1])):
        print(f"Z={z:6.2f}, Y={y:6.2f}")

if __name__ == "__main__":
    main()
