#!/usr/bin/env python3
"""Synthesises the garage lifts' safety lock clack, sounds/garage/lift_lock_click.wav (mono, 44.1kHz, peak -1 dBFS): a
steel pawl dropping into its notch as a lift's carriage rises past it (Garage.gd plays one every LOCK_STEP of the rise).
Modal synthesis: a 2ms burst of noise strikes a handful of damped resonators, a steel part's inharmonic modes ringing
for 10-50ms and a low thunk of the post, then the pawl bounces once, quieter, 17ms later. ElevenLabs gave five takes of
smeared half-second noise for this, not a clack. Usage: python3 scratch/garage_lock_click.py [out.wav]"""
import sys, wave
import numpy as np

SR = 44100
LENGTH = 0.22
# Mode frequency (Hz), level, decay time constant (s).
MODES = [(212.0, 0.55, 0.020), (1430.0, 1.0, 0.040), (2365.0, 0.65, 0.028), (3710.0, 0.42, 0.018),
         (5180.0, 0.30, 0.010), (7020.0, 0.18, 0.006)]
BOUNCE_AT = 0.017
BOUNCE_LEVEL = 0.32


def strike(n, rng):
    """The excitation: a 2ms burst of noise, falling off fast."""
    e = np.zeros(n)
    k = int(0.002 * SR)
    e[:k] = rng.uniform(-1.0, 1.0, k) * np.exp(-np.arange(k) / (0.0006 * SR))
    return e


def ring(e):
    out = np.zeros_like(e)
    for f, level, tau in MODES:
        r = np.exp(-1.0 / (tau * SR))
        c = 2.0 * r * np.cos(2.0 * np.pi * f / SR)
        r2 = r * r
        y1 = y2 = 0.0
        y = np.empty_like(e)
        for i, x in enumerate(e):
            v = c * y1 - r2 * y2 + x
            y[i] = v
            y2, y1 = y1, v
        y /= max(np.abs(y).max(), 1e-9)
        out += y * level
    return out


def main():
    rng = np.random.default_rng(7)
    n = int(LENGTH * SR)
    e = strike(n, rng)
    b = strike(n, rng) * BOUNCE_LEVEL
    k = int(BOUNCE_AT * SR)
    e[k:] += b[: n - k]
    a = ring(e)
    a += e * 0.35   # the strike's own tick on top
    fade = int(0.02 * SR)
    a[-fade:] *= np.linspace(1.0, 0.0, fade)
    a *= 10 ** (-1.0 / 20) / np.abs(a).max()
    path = sys.argv[1] if len(sys.argv) > 1 else "sounds/garage/lift_lock_click.wav"
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((a * 32767).round().astype(np.int16).tobytes())
    print("%s: %.3fs, peak -1.0 dBFS, RMS %.1f dBFS" % (path, LENGTH, 20 * np.log10(np.sqrt(np.mean(a ** 2)))))


main()
