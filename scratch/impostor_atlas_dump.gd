extends SceneTree

# Writes Pinecrest's far-forest impostor atlas (regenerate_pinecrest_impostors.gd) out as PNGs, the
# albedo over grey so the outline shows, and the normals:
#   Godot --headless --path . -s res://scratch/impostor_atlas_dump.gd -- <dir>
func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	for n in ["albedo", "normal"]:
		var img: Image = (load("res://generated/pinecrest_impostor_%s.res" % n) as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		img.clear_mipmaps()
		img.convert(Image.FORMAT_RGBA8)
		if n == "albedo":
			var bg := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
			bg.fill(Color(0.6, 0.6, 0.6))
			bg.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
			img = bg
		img.save_png(out.path_join("impostor_%s.png" % n))
	quit()
