extends SceneTree

# Saves a car's detail map (and a UV-position preview of it) as PNGs for inspection. The detail map
# is 1024x512: R glass, G panel gaps, B chrome, A black. Run headless:
#   Godot --headless --path . -s res://scratch/car_detail_dump.gd -- <BuilderName> <out_dir>


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var builder_path: String = "res://%sBuilder.gd" % args[0]
	var out_dir: String = args[1]
	var design = load(builder_path).new()
	var img: Image = design.build_detail_map(1024, 512)
	img.save_png(out_dir + "/detail.png")
	print("saved detail map to ", out_dir, "/detail.png")
	quit()
