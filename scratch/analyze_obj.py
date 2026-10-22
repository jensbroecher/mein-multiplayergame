import sys

def main():
    verts = []
    faces = []
    with open("scratch/fbx_ramp.obj", "r") as f:
        for line in f:
            if line.startswith("v "):
                verts.append([float(x) for x in line.strip().split()[1:]])
            elif line.startswith("f "):
                faces.append([int(x.split("/")[0]) - 1 for x in line.strip().split()[1:]])
    
    print(f"Loaded {len(verts)} vertices, {len(faces)} faces.")
    xs = [v[0] for v in verts]
    ys = [v[1] for v in verts]
    zs = [v[2] for v in verts]
    print(f"X: [{min(xs):.2f}, {max(xs):.2f}] (len {max(xs)-min(xs):.2f})")
    print(f"Y: [{min(ys):.2f}, {max(ys):.2f}] (height {max(ys)-min(ys):.2f})")
    print(f"Z: [{min(zs):.2f}, {max(zs):.2f}] (width {max(zs)-min(zs):.2f})")
    
    # Check what features exist:
    # 1. Back wall: what is at X > 8.0?
    back_faces = []
    for f_idx, f in enumerate(faces):
        fv = [verts[i] for i in f]
        avg_x = sum(v[0] for v in fv) / len(fv)
        if avg_x > 8.0:
            back_faces.append(fv)
    print(f"Faces at X > 8.0: {len(back_faces)}")
    
    # Check if there is an arch/opening under the ramp:
    # Let's check Y range of faces near Z=0 for various X:
    for x_test in [-10, -5, 0, 5, 7.5]:
        mid_ys = [v[1] for v in verts if abs(v[0] - x_test) < 0.5 and abs(v[2]) < 1.0]
        if mid_ys:
            print(f"At X={x_test:4.1f}, Z~0: Y in [{min(mid_ys):.2f}, {max(mid_ys):.2f}]")

    # Let's inspect side walls (at Z min and Z max)
    left_ys = [v[1] for v in verts if v[2] < -4.0]
    right_ys = [v[1] for v in verts if v[2] > 4.0]
    print(f"Left side (Z < -4.0) Y range: [{min(left_ys):.2f}, {max(left_ys):.2f}]")
    print(f"Right side (Z > 4.0) Y range: [{min(right_ys):.2f}, {max(right_ys):.2f}]")
    
    # Check if underside of ramp has an open tunnel or solid
    # A tunnel would have faces pointing down around Z~0 at Y > 0.5
    under_faces = 0
    for f in faces:
        fv = [verts[i] for i in f]
        # compute normal
        e1 = [fv[1][j] - fv[0][j] for j in range(3)]
        e2 = [fv[2][j] - fv[0][j] for j in range(3)]
        nx = e1[1]*e2[2] - e1[2]*e2[1]
        ny = e1[2]*e2[0] - e1[0]*e2[2]
        nz = e1[0]*e2[1] - e1[1]*e2[0]
        avg_y = sum(v[1] for v in fv) / 3.0
        avg_x = sum(v[0] for v in fv) / 3.0
        avg_z = sum(v[2] for v in fv) / 3.0
        if ny < -0.3 and avg_y > 1.0 and abs(avg_z) < 2.0:
            under_faces += 1
    print(f"Downward faces in center with Y > 1.0: {under_faces}")

if __name__ == "__main__":
    main()
