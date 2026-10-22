import numpy as np

# Sample the deck points from fbx_ramp.obj
with open("scratch/fbx_ramp.obj") as f:
    verts = [list(map(float, l.split()[1:])) for l in f if l.startswith("v ")]

deck_pts = [v for v in verts if abs(v[2]) < 2.0 and v[1] > 0.05 and v[0] < 8.15]
x_dict = {}
for p in deck_pts:
    kx = round(p[0] * 2.0) / 2.0
    x_dict.setdefault(kx, []).append(p[1])

xs = sorted(x_dict.keys())
ys = [max(x_dict[x]) for x in xs]

# Add start at -12.37, y = 0.0 and end at 8.10, y = 8.12
xs = [-12.37] + xs + [8.10]
ys = [0.0] + ys + [8.12]

# Fit smooth spline/polynomial
p = np.polyfit(xs, ys, 3)

# Generate smooth points every ~0.5m
eval_xs = np.linspace(-12.37, 8.10, 35)
eval_ys = np.polyval(p, eval_xs)
eval_ys[0] = 0.0
eval_ys[-1] = 8.12

print("Deck polygon points:")
print("PackedVector2Array([")
# Top curve points
for x, y in zip(eval_xs, eval_ys):
    print(f"\tVector2({x:.3f}, {y:.3f}),")
# Back wall down to bottom
print(f"\tVector2(8.10, 0.0),")
# Foundation skirt down to -0.6 to ensure no terrain gap
print(f"\tVector2(8.10, -0.6),")
print(f"\tVector2(-12.37, -0.6),")
print("])")
