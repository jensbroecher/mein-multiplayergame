from PIL import Image
import math

# Load the logo with black background
src_path = "images/logo_black_bg.png"
im = Image.open(src_path).convert("RGBA")

# Tight bounding box from previous check: 283, 358, 2530, 1218
bbox = (283, 358, 2530, 1218)
cropped = im.crop(bbox)
w, h = cropped.size

# Check pixel values
pixels = cropped.load()
for y in range(h):
    for x in range(w):
        r, g, b, a = pixels[x, y]
        br = max(r, g, b)
        if br <= 3:
            pixels[x, y] = (0, 0, 0, 0)
        elif br < 25:
            # Smooth anti-aliased transition at the edges
            alpha = int(255 * (br - 3) / (25 - 3))
            # Rescale RGB so it's not darkened by pre-multiplied black
            scale = 255.0 / max(alpha, 1)
            nr = min(255, int(r * scale))
            ng = min(255, int(g * scale))
            nb = min(255, int(b * scale))
            pixels[x, y] = (nr, ng, nb, alpha)
        else:
            pixels[x, y] = (r, g, b, 255)

out_path = "images/logo_transparent.png"
cropped.save(out_path)
print(f"Saved {out_path} with size {cropped.size}")

