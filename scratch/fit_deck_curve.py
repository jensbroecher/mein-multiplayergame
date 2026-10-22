import numpy as np

with open("scratch/fbx_ramp.obj") as f:
    verts = [list(map(float, l.split()[1:])) for l in f if l.startswith("v ")]

# Get top deck surface points: Z in [-3.0, 3.0], Y > 0.1
deck_pts = [v for v in verts if abs(v[2]) < 2.5 and v[1] > 0.1]
# Group by X with 0.5m spacing
x_dict = {}
for p in deck_pts:
    kx = round(p[0] * 2.0) / 2.0
    x_dict.setdefault(kx, []).append(p[1])

xs = sorted(x_dict.keys())
ys = [max(x_dict[x]) for x in xs]

print("X and Max Y along deck center:")
for x, y in zip(xs, ys):
    print(f"X = {x:5.1f} -> Y = {y:5.2f}")

# Fit a 2nd degree polynomial: y = a*x^2 + b*x + c
poly = np.polyfit(xs, ys, 2)
print(f"\nFitted quadratic: Y = {poly[0]:.6f}*X^2 + {poly[1]:.6f}*X + {poly[2]:.6f}")

# Evaluate fit error
max_err = max(abs(y - np.polyval(poly, x)) for x, y in zip(xs, ys))
print(f"Max error with quadratic: {max_err:.3f} m")

# Fit cubic
poly3 = np.polyfit(xs, ys, 3)
max_err3 = max(abs(y - np.polyval(poly3, x)) for x, y in zip(xs, ys))
print(f"Max error with cubic: {max_err3:.3f} m")
