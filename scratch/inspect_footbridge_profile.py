def main():
    verts = []
    with open("scratch/fbx_footbridge.obj") as f:
        for line in f:
            if line.startswith("v "):
                verts.append([float(x) for x in line.split()[1:]])

    # 1. Side profile: look at points near Z = -7.0 (outer railing face), Z = 0.0 (center of walkway)
    print("--- SIDE PROFILE AT Z near 0.0 (walkway centerline) ---")
    center_pts = [v for v in verts if abs(v[2]) < 1.0]
    # Sample along X
    for tx in [-17.5, -15, -12, -9, -7.5, -5, 0, 5, 7.5, 9, 12, 15, 17.5]:
        sv = [v for v in center_pts if abs(v[0] - tx) < 0.5]
        if sv:
            ys = sorted([v[1] for v in sv])
            print(f"X = {tx:5.1f}: Y in [{min(ys):.2f}, {max(ys):.2f}] (samples: {[round(y,2) for y in ys]})")

    print("\n--- CROSS SECTION AT X near 0.0 (center of bridge span) ---")
    mid_x_pts = [v for v in verts if abs(v[0]) < 0.5]
    mid_x_pts.sort(key=lambda v: (round(v[2], 1), round(v[1], 1)))
    z_dict = {}
    for p in mid_x_pts:
        kz = round(p[2] * 2.0) / 2.0
        z_dict.setdefault(kz, []).append(p[1])
    for kz in sorted(z_dict.keys()):
        ys = sorted(z_dict[kz])
        print(f"Z = {kz:5.1f}: Y in [{min(ys):.2f}, {max(ys):.2f}] (samples: {[round(y, 2) for y in ys[:6]]})")

if __name__ == "__main__":
    main()
