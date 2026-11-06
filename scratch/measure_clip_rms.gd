extends SceneTree
## A WAV file's level, read straight from the file (16-bit PCM, any channels), not through the import: its length,
## RMS and peak in dBFS, and the RMS of its loudest second. To level a new clip by its measured RMS, as StageAmbience's
## CLIP_DB and the others are. Headless:
##   Godot --headless --path . -s res://scratch/measure_clip_rms.gd -- res://sounds/x.wav ...

func _init() -> void:
	for path in OS.get_cmdline_user_args():
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			print("%s: can't open" % path)
			continue
		var bytes := f.get_buffer(f.get_length())
		var channels := 1
		var rate := 44100
		var bits := 16
		var pos := 12
		var data_at := -1
		var data_len := 0
		while pos + 8 <= bytes.size():
			var id := bytes.slice(pos, pos + 4).get_string_from_ascii()
			var size := bytes.decode_u32(pos + 4)
			if id == "fmt ":
				channels = bytes.decode_u16(pos + 10)
				rate = bytes.decode_u32(pos + 12)
				bits = bytes.decode_u16(pos + 22)
			elif id == "data":
				data_at = pos + 8
				data_len = mini(size, bytes.size() - data_at)
				break
			pos += 8 + size + (size & 1)
		if data_at < 0 or bits != 16:
			print("%s: not 16-bit PCM (%d bits)" % [path, bits])
			continue
		var frames: int = data_len / (2 * channels)
		var sum := 0.0
		var peak := 0.0
		var best := 0.0
		var win_sum := 0.0
		var win: int = rate
		var hist := PackedFloat32Array()
		hist.resize(frames)
		for i in range(frames):
			var acc := 0.0
			for c in range(channels):
				var v: float = float(bytes.decode_s16(data_at + (i * channels + c) * 2)) / 32768.0
				acc += v * v
				peak = maxf(peak, absf(v))
			acc /= float(channels)
			hist[i] = acc
			sum += acc
			win_sum += acc
			if i >= win:
				win_sum -= hist[i - win]
			if i >= win - 1:
				best = maxf(best, win_sum / float(win))
		var rms: float = sqrt(sum / maxf(float(frames), 1.0))
		print("%s: %.2fs, %d ch, %d Hz, RMS %.1f dBFS, peak %.1f dBFS, loudest second %.1f dBFS" % [path, float(frames) / float(rate), channels, rate,
				linear_to_db(rms), linear_to_db(peak), linear_to_db(sqrt(best))])
	quit()
