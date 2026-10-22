def main():
    verts = []
    faces = []
    with open("scratch/fbx_footbridge.obj") as f:
        for line in f:
            if line.startswith("v "):
                verts.append([float(x) for x in line.split()[1:]])
            elif line.startswith("f "):
                faces.append([int(x.split("/")[0]) - 1 for x in line.split()[1:]])

    import numpy as np
    pts = np.array(verts)

    # Let's inspect faces where all vertices have X in [8, 14] and |Z| < 2.0 and Y > 0.5
    stair_faces = []
    for f in faces:
        fv = pts[f]
        if np.all(fv[:, 0] > 7.5) and np.all(fv[:, 0] < 15.5) and np.all(np.abs(fv[:, 2]) < 2.0) and np.all(fv[:, 1] > 0.5):
            stair_faces.append(f)
            
    print(f"Found {len(stair_faces)} faces on walkway in leg [7.5, 15.5]")
    # Check normals
    for f in stair_faces[:10]:
        v0, v1, v2 = pts[f[0]], pts[f[1]], pts[f[2]]
        norm = np.cross(v1 - v0, v2 - v0)
        norm = norm / np.linalg.norm(norm)
        print(f"Face normal: [{norm[0]:.2f}, {norm[1]:.2f}, {norm[2]:.2f}], avg Y: {np.mean(pts[f, 1]):.2f}, avg X: {np.mean(pts[f, 0]):.2f}")

if __name__ == "__main__":
    main()
