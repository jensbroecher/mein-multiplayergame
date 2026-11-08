#!/usr/bin/env python3
"""Readies the garage's lift and line-up sounds (sounds/garage/, made with tools/elevenlabs, jobs garage_*) for
Garage.gd, in place: mixed down to mono, the one-shots' silent lead-in cut (to a few milliseconds before the first
sound, with a 3ms fade-in, so a clunk plays when it is called and not a beat later) and every clip raised: the one-shots
to a peak of -1 dBFS, the loops to an RMS of -16 dBFS (never past -1 peak). ElevenLabs made them 25-45 dB under that.
Garage.gd's LIFT_SOUNDS levels are set for the files as this leaves them. Run it again on a fresh take (it only cuts
silence and raises, so a second run changes nothing); then import (the loops' .import: loop_mode 2, PCM).
The lock clack isn't one of them: scratch/garage_lock_click.py synthesises it, ready.
Usage: python3 scratch/garage_sound_prep.py [file.wav ...]   (default: the seven garage clips)"""
import sys, wave, math
import numpy as np

ONE_SHOTS = ["lift_top", "lift_release", "lift_bottom", "lineup_on", "lineup_off"]
LOOPS = ["lift_motor_loop", "lift_lower_loop"]
ONSET_DB = -30.0   # the first sample this far under the clip's peak is where it starts
LEAD = 0.006       # kept before it
FADE_IN = 0.003


def db(x):
    return 20 * math.log10(max(x, 1e-9))


def prep(path, loop):
    with wave.open(path, "rb") as w:
        ch, sr, n = w.getnchannels(), w.getframerate(), w.getnframes()
        assert w.getsampwidth() == 2, path + " is not 16-bit PCM"
        a = np.frombuffer(w.readframes(n), dtype=np.int16).reshape(-1, ch).astype(np.float64).mean(axis=1) / 32768.0
    before = (db(np.sqrt(np.mean(a ** 2))), db(np.abs(a).max()), len(a) / sr)
    if not loop:
        peak = np.abs(a).max()
        onset = int(np.argmax(np.abs(a) > peak * 10 ** (ONSET_DB / 20)))
        start = max(0, onset - int(LEAD * sr))
        a = a[start:].copy()
        f = min(len(a), int(FADE_IN * sr))
        if start > 0:
            a[:f] *= np.linspace(0.0, 1.0, f)
        gain = 10 ** (-1.0 / 20) / max(np.abs(a).max(), 1e-9)
    else:
        rms = np.sqrt(np.mean(a ** 2))
        gain = min(10 ** (-16.0 / 20) / max(rms, 1e-9), 10 ** (-1.0 / 20) / max(np.abs(a).max(), 1e-9))
    a = np.clip(a * gain, -1.0, 32767 / 32768)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes((a * 32768).round().astype(np.int16).tobytes())
    after = (db(np.sqrt(np.mean(a ** 2))), db(np.abs(a).max()), len(a) / sr)
    print("%-36s %s  RMS %6.1f -> %6.1f  peak %6.1f -> %6.1f  %.3fs -> %.3fs" % (
        path, "loop" if loop else "shot", before[0], after[0], before[1], after[1], before[2], after[2]))


files = sys.argv[1:] or ["sounds/garage/%s.wav" % c for c in ONE_SHOTS + LOOPS]
for p in files:
    prep(p, any(l in p for l in LOOPS))
