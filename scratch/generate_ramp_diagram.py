import math

def main():
    verts = []
    faces = []
    with open("scratch/fbx_ramp.obj", "r") as f:
        for line in f:
            if line.startswith("v "):
                verts.append([float(x) for x in line.strip().split()[1:]])
            elif line.startswith("f "):
                faces.append([int(x.split("/")[0]) - 1 for x in line.strip().split()[1:]])

    # Side view (X vs Y) and End view (Z vs Y)
    # Collect unique edges
    edges = set()
    for f in faces:
        for i in range(len(f)):
            j = (i + 1) % len(f)
            e = tuple(sorted([f[i], f[j]]))
            edges.add(e)

    # Generate an SVG with 3 views:
    # 1. Side view (X horizontal, Y vertical)
    # 2. Front/Lip view (Z horizontal, Y vertical)
    # 3. Top view (X horizontal, Z vertical)
    
    svg_lines = [
        '<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="900" viewBox="0 0 1200 900" style="background:#1e1e24">',
        '<style>line { stroke: #00d2ff; stroke-width: 0.5; stroke-opacity: 0.35; } text { fill: #e0e0e0; font-family: monospace; font-size: 14px; }</style>',
        '<text x="50" y="40">Side View (X vs Y)</text>',
        '<text x="650" y="40">Front / Lip View (Z vs Y)</text>',
        '<text x="50" y="480">Top View (X vs Z)</text>'
    ]

    # Side view: X in [-13, 9] -> map to [50, 550], Y in [0, 9] -> map to [400, 80]
    def map_side(x, y):
        sx = 50 + (x - (-13)) / 22.0 * 500
        sy = 400 - (y / 9.0 * 320)
        return sx, sy

    # Front view: Z in [-5, 5] -> map to [700, 1100], Y in [0, 9] -> map to [400, 80]
    def map_front(z, y):
        fx = 700 + (z - (-5)) / 10.0 * 400
        fy = 400 - (y / 9.0 * 320)
        return fx, fy

    # Top view: X in [-13, 9] -> map to [50, 550], Z in [-5, 5] -> map to [540, 840]
    def map_top(x, z):
        tx = 50 + (x - (-13)) / 22.0 * 500
        tz = 690 + (z / 5.0 * 150)
        return tx, tz

    for u, v in edges:
        p1 = verts[u]
        p2 = verts[v]
        # Only draw if not degenerate
        sx1, sy1 = map_side(p1[0], p1[1])
        sx2, sy2 = map_side(p2[0], p2[1])
        svg_lines.append(f'<line x1="{sx1:.1f}" y1="{sy1:.1f}" x2="{sx2:.1f}" y2="{sy2:.1f}" />')

        fx1, fy1 = map_front(p1[2], p1[1])
        fx2, fy2 = map_front(p2[2], p2[1])
        svg_lines.append(f'<line x1="{fx1:.1f}" y1="{fy1:.1f}" x2="{fx2:.1f}" y2="{fy2:.1f}" />')

        tx1, tz1 = map_top(p1[0], p1[2])
        tx2, tz2 = map_top(p2[0], p2[2])
        svg_lines.append(f'<line x1="{tx1:.1f}" y1="{tz1:.1f}" x2="{tx2:.1f}" y2="{tz2:.1f}" />')

    svg_lines.append('</svg>')
    with open("scratch/ramp_wireframe.svg", "w") as f:
        f.write("\n".join(svg_lines))
    print("Wrote scratch/ramp_wireframe.svg")

if __name__ == "__main__":
    main()
