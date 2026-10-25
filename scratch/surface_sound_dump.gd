extends SceneTree

# Writes the baked surface loops (generated/surfaces/*.res) out as .wav files to listen to or
# analyse:  Godot --headless --path . -s res://scratch/surface_sound_dump.gd -- <out_dir>

func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	for f in DirAccess.get_files_at("res://generated/surfaces"):
		if f.ends_with(".res"):
			var wav: AudioStreamWAV = load("res://generated/surfaces/" + f)
			wav.save_to_wav(out.path_join(f.get_basename() + ".wav"))
			print("wrote ", f.get_basename())
	quit()
