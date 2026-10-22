from PIL import Image
import numpy as np

img = Image.open("models/ramps/1f92b579825d1652d7ab8d760b289672_0.png")
print("Size:", img.size, "Mode:", img.mode)

# Resize to small thumbnail to inspect color distribution
small = img.resize((64, 64))
arr = np.array(small)
mean_col = arr.mean(axis=(0, 1))
print("Mean RGB:", mean_col)
print("Min RGB:", arr.min(axis=(0, 1)))
print("Max RGB:", arr.max(axis=(0, 1)))

# Save a preview thumbnail
small_preview = img.resize((512, 512))
small_preview.save("scratch/ramp_tex_preview.jpg", quality=85)
print("Saved scratch/ramp_tex_preview.jpg")
