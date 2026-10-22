def main():
    verts = []
    with open("scratch/fbx_footbridge_true.obj") as f:
        for line in f:
            if line.startswith("v "):
                verts.append([float(x) for x in line.split()[1:]])

    import numpy as np
    pts = np.array(verts)

    print("--- UNDERSIDE PROFILE (along X) ---")
    # For underside, look at pts with |Z| < 2.0 and Y < 5.5
    under = pts[(np.abs(pts[:, 2]) < 2.0) & (pts[:, 1] < 5.5)]
    under_by_x = {}
    for p in under:
        kx = round(p[0] * 2.0) / 2.0
        under_by_x.setdefault(kx, []).append(p[1])
    for kx in sorted(under_by_x.keys()):
        print(f"X = {kx:5.1f}: min Y = {min(under_by_x[kx]):.2f}")

    print("\n--- WALKWAY DECK PROFILE (along X) ---")
    # For deck, look at pts with |Z| < 2.0 and Y > 0.0
    deck = pts[(np.abs(pts[:, 2]) < 2.0) & (pts[:, 1] >= 0.0)]
    deck_by_x = {}
    for p in deck:
        kx = round(p[0] * 2.0) / 2.0
        deck_by_x.setdefault(kx, []).append(p[1])
    for kx in sorted(deck_by_x.keys()):
        # Deck top is usually the highest point inside |Z| < 2.0
        print(f"X = {kx:5.1f}: deck Y = {max(deck_by_x[kx]):.2f}")

    print("\n--- PARAPET TOP PROFILE (along X) ---")
    parapet = pts[pts[:, 1] > 0.5]
    par_by_x = {}
    for p in parapet:
        kx = round(p[0] * 2.0) / 2.0
        par_by_x.setdefault(kx, []).append(p[1])
    for kx in sorted(par_by_x.keys()):
        print(f"X = {kx:5.1f}: parapet top Y = {max(par_by_x[kx]):.2f}")

if __name__ == "__main__":
    main()
