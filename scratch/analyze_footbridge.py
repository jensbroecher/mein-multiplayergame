def main():
    verts = []
    with open("scratch/fbx_footbridge.obj") as f:
        for line in f:
            if line.startswith("v "):
                verts.append([float(x) for x in line.split()[1:]])

    xs = [v[0] for v in verts]
    ys = [v[1] for v in verts]
    zs = [v[2] for v in verts]
    print(f"X range: [{min(xs):.2f}, {max(xs):.2f}] (span: {max(xs)-min(xs):.2f})")
    print(f"Y range: [{min(ys):.2f}, {max(ys):.2f}] (height: {max(ys)-min(ys):.2f})")
    print(f"Z range: [{min(zs):.2f}, {max(zs):.2f}] (width: {max(zs)-min(zs):.2f})")

    # Let's inspect along X (span axis):
    # What are the Y values across X?
    for test_x in [-17, -14, -10, -7, -4, 0, 4, 7, 10, 14, 17]:
        slice_v = [v for v in verts if abs(v[0] - test_x) < 0.4]
        if slice_v:
            y_in_slice = [v[1] for v in slice_v]
            z_in_slice = [v[2] for v in slice_v]
            print(f"X = {test_x:5.1f}: Y in [{min(y_in_slice):.2f}, {max(y_in_slice):.2f}], Z in [{min(z_in_slice):.2f}, {max(z_in_slice):.2f}]")

    # Let's inspect the center span (X between -5 and +5):
    center_v = [v for v in verts if abs(v[0]) < 2.0]
    print("\nCenter span (X near 0):")
    # Find distinct Y levels in center:
    c_ys = sorted(list(set(round(v[1], 1) for v in center_v)))
    print("Distinct Y levels near center:", c_ys)
    # Underside clearance:
    min_center_y = min(v[1] for v in center_v)
    print(f"Under-bridge road clearance: {min_center_y:.2f} meters")

    # Walkway deck width and parapet height in center:
    top_center_v = [v for v in center_v if v[1] > min_center_y + 1.0]
    top_ys = sorted(list(set(round(v[1], 2) for v in top_center_v)))
    print("Top deck & parapet Y levels:", top_ys)
    
    # Parapet outer Z vs inner Z:
    # Walkway surface is at some Y, railings rise above it
    deck_y = min(top_ys)
    rail_y = max(top_ys)
    print(f"Deck surface Y = {deck_y:.2f}, Parapet rail top Y = {rail_y:.2f} (rail height = {rail_y - deck_y:.2f}m)")

    walkway_v = [v for v in center_v if abs(v[1] - deck_y) < 0.3]
    w_zs = [v[2] for v in walkway_v]
    print(f"Walkway Z in [{min(w_zs):.2f}, {max(w_zs):.2f}] (width: {max(w_zs)-min(w_zs):.2f}m)")

    rail_v = [v for v in center_v if abs(v[1] - rail_y) < 0.3]
    r_zs = [v[2] for v in rail_v]
    print(f"Railings Z in [{min(r_zs):.2f}, {max(r_zs):.2f}] (total bridge width: {max(r_zs)-min(r_zs):.2f}m)")

if __name__ == "__main__":
    main()
