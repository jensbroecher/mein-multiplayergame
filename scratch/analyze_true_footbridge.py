def main():
    verts = []
    with open("scratch/fbx_footbridge_true.obj") as f:
        for line in f:
            if line.startswith("v "):
                verts.append([float(x) for x in line.split()[1:]])

    import numpy as np
    pts = np.array(verts)
    
    xs = pts[:, 0]
    ys = pts[:, 1]
    zs = pts[:, 2]

    print(f"X range: [{min(xs):.3f}, {max(xs):.3f}] (span: {max(xs)-min(xs):.3f})")
    print(f"Y range: [{min(ys):.3f}, {max(ys):.3f}] (height: {max(ys)-min(ys):.3f})")
    print(f"Z range: [{min(zs):.3f}, {max(zs):.3f}] (width: {max(zs)-min(zs):.3f})")

    # Center span
    center = pts[np.abs(pts[:, 0]) < 2.0]
    print(f"Under-bridge road clearance: {min(center[:, 1]):.3f} meters")
    
    # Deck surface in center
    deck_v = center[center[:, 1] > 6.0]
    print(f"Deck surface Y: {min(deck_v[:, 1]):.3f} meters")
    print(f"Parapet top Y: {max(deck_v[:, 1]):.3f} meters")
    
    # Parapet and deck widths
    deck_pts = center[np.abs(center[:, 1] - min(deck_v[:, 1])) < 0.2]
    print(f"Walkway deck Z range: [{min(deck_pts[:, 2]):.3f}, {max(deck_pts[:, 2]):.3f}] (width: {max(deck_pts[:, 2])-min(deck_pts[:, 2]):.3f}m)")

    # Parapet outer Z
    print(f"Overall bridge width (Z): [{min(zs):.3f}, {max(zs):.3f}] (width: {max(zs)-min(zs):.3f}m)")

    # Slope legs along X
    print("\n--- X PROFILE ---")
    for tx in np.linspace(min(xs), max(xs), 21):
        m = np.abs(xs - tx) < 0.5
        if np.any(m):
            sub = pts[m]
            print(f"X = {tx:6.2f}: Y in [{min(sub[:, 1]):.2f}, {max(sub[:, 1]):.2f}]")

if __name__ == "__main__":
    main()
