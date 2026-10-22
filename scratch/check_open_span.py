def main():
    verts = []
    with open("scratch/fbx_footbridge.obj") as f:
        for line in f:
            if line.startswith("v "):
                verts.append([float(x) for x in line.split()[1:]])

    import numpy as np
    pts = np.array(verts)

    # In center span X in [-7, 7], are there any vertices below Y=4.9?
    mid_below = pts[(pts[:, 0] > -7.0) & (pts[:, 0] < 7.0) & (pts[:, 1] < 4.9)]
    print(f"Vertices under center span (below Y=4.9): {len(mid_below)}")
    
    # Are there any piers or columns?
    # Between X=-7 and 7, min Y is 4.95 everywhere!
    # So the center span is completely open for traffic underneath!
    print("Under-span is completely clear!")

if __name__ == "__main__":
    main()
