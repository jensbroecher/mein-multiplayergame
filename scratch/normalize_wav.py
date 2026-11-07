#!/usr/bin/env python3
"""Raises a quiet 16-bit PCM WAV toward a target RMS, in place, never past a peak ceiling (default -16 dBFS RMS, peak
-1 dBFS). Godot's AudioStreamPlayer3D caps a voice's level at max_db (+3 dB, +6 at most), so a clip levelled by its RMS
that needs more gain than that came out too quiet (the Ring's city engines, the tram, the light plane). Prints each
file's RMS and peak before and after. Usage: python3 scratch/normalize_wav.py [--rms=-16] [--peak=-1] file.wav ..."""
import sys, wave, array, math

def levels(samples):
    if not samples:
        return -120.0, -120.0
    rms = math.sqrt(sum(s * s for s in samples) / len(samples)) / 32768.0
    peak = max(abs(s) for s in samples) / 32768.0
    return 20 * math.log10(max(rms, 1e-9)), 20 * math.log10(max(peak, 1e-9))

target, ceiling, files = -16.0, -1.0, []
for a in sys.argv[1:]:
    if a.startswith("--rms="):
        target = float(a[6:])
    elif a.startswith("--peak="):
        ceiling = float(a[7:])
    else:
        files.append(a)
for f in files:
    with wave.open(f, "rb") as w:
        params = w.getparams()
        if params.sampwidth != 2:
            print(f, "is not 16-bit PCM, skipped")
            continue
        data = array.array("h", w.readframes(params.nframes))
    rms, peak = levels(data)
    gain_db = min(target - rms, ceiling - peak)
    if gain_db <= 0.05:
        print("%s: RMS %.1f peak %.1f dBFS, left as it is" % (f, rms, peak))
        continue
    g = 10 ** (gain_db / 20)
    out = array.array("h", (max(-32768, min(32767, int(round(s * g)))) for s in data))
    with wave.open(f, "wb") as w:
        w.setparams(params)
        w.writeframes(out.tobytes())
    r2, p2 = levels(out)
    print("%s: RMS %.1f -> %.1f, peak %.1f -> %.1f dBFS (+%.1f dB)" % (f, rms, r2, peak, p2, gain_db))
