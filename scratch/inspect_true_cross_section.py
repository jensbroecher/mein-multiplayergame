def main():
    verts = []
    with open("scratch/fbx_footbridge_true.obj") as f:
        for line in f:
            if line.startswith("v "):
                verts.append([float(x) for x in line.split()[1:]])

    import numpy as np
    pts = np.array(verts)
    center = pts[np.abs(pts[:, 0]) < 1.0]
    
    # Sort by Z
    unique_zy = sorted(list(set([(round(p[2], 2), round(p[1], 2)) for p in center])))
    print("True Cross section at X=0 (Z, Y):")
    for z, y in unique_zy:
        print(f"Z={z:6.2f}, Y={y:6.2f}")

if __name__ == "__main__":
    main()
