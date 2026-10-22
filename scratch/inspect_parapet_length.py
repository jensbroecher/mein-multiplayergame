def main():
    verts = []
    with open("scratch/fbx_footbridge.obj") as f:
        for line in f:
            if line.startswith("v "):
                verts.append([float(x) for x in line.split()[1:]])

    import numpy as np
    pts = np.array(verts)

    # Let's inspect parapet profile (Z > 5.5, e.g. outer wall)
    p_pts = pts[pts[:, 2] > 6.0]
    print("--- PARAPET PROFILE (Z > 6.0) ---")
    xs = sorted(list(set(np.round(p_pts[:, 0], 1))))
    for x in np.linspace(-18, 18, 37):
        mask = np.abs(p_pts[:, 0] - x) < 0.3
        if np.any(mask):
            ys = p_pts[mask, 1]
            print(f"X = {x:5.1f}: Y in [{np.min(ys):.2f}, {np.max(ys):.2f}]")

    print("\n--- BASE / FOUNDATION (Lowest Y points along X) ---")
    for x in np.linspace(-18, 18, 37):
        mask = np.abs(pts[:, 0] - x) < 0.3
        if np.any(mask):
            ys = pts[mask, 1]
            print(f"X = {x:5.1f}: min Y = {np.min(ys):.2f}")

if __name__ == "__main__":
    main()
