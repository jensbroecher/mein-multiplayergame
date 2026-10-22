def main():
    verts = []
    with open("scratch/fbx_footbridge.obj") as f:
        for line in f:
            if line.startswith("v "):
                verts.append([float(x) for x in line.split()[1:]])

    # Let's inspect along X in steps of 0.5m
    print("X, min_Y, max_Y, min_Z, max_Z, count")
    import numpy as np
    pts = np.array(verts)
    
    # Let's check the distinct X coordinates if mesh is composed of cross-sections
    xs = sorted(list(set(np.round(pts[:, 0], 2))))
    print(f"Total unique X coordinates (rounded to 2 decimals): {len(xs)}")
    
    # Check bottom profile (lowest Y for each X)
    print("\n--- BOTTOM PROFILE (Underside / Ground) ---")
    x_bins = np.linspace(-18, 18, 37)
    for i in range(len(x_bins)-1):
        mask = (pts[:, 0] >= x_bins[i]) & (pts[:, 0] < x_bins[i+1])
        if np.any(mask):
            bin_pts = pts[mask]
            min_y = np.min(bin_pts[:, 1])
            max_y = np.max(bin_pts[:, 1])
            print(f"X in [{x_bins[i]:5.1f}, {x_bins[i+1]:5.1f}]: Y min={min_y:5.2f}, Y max={max_y:5.2f}")

    # Check walkway surface profile
    # Walkway is in center Z (e.g. |Z| < 3.0)
    print("\n--- WALKWAY PROFILE (|Z| < 2.0) ---")
    w_mask = np.abs(pts[:, 2]) < 2.0
    w_pts = pts[w_mask]
    for i in range(len(x_bins)-1):
        mask = (w_pts[:, 0] >= x_bins[i]) & (w_pts[:, 0] < x_bins[i+1])
        if np.any(mask):
            bin_pts = w_pts[mask]
            min_y = np.min(bin_pts[:, 1])
            max_y = np.max(bin_pts[:, 1])
            unique_ys = sorted(list(set(np.round(bin_pts[:, 1], 2))))
            print(f"X in [{x_bins[i]:5.1f}, {x_bins[i+1]:5.1f}]: Y min={min_y:5.2f}, Y max={max_y:5.2f}, Ys={unique_ys[:4]}")

if __name__ == "__main__":
    main()
