#!/usr/bin/env python3
"""The Typhoon's engine loop, synthesised (no recording, no ElevenLabs): a twin-cylinder aero engine turning a
three-bladed ducted propeller.

    python3 scratch/synth_engine_typhoon.py [out.wav] [--rms=-18.0]

Everything repeats exactly every LOOP seconds (every frequency a whole number of cycles in it; the noise made in the
frequency domain; every filter circular), so the loop has no seam. Kept warm and round, never shrill: the firing
pulses are soft, the mix is low-passed (a gentle fourth-order roll-off from LP_HZ) and anything over 4 kHz is cut, so
even pitched up 1.5x (PlayerCart's top with a boost) it stays under about 6 kHz.

The engine at its loop pitch fires F0 times a second (a twin four-stroke: once per crank turn, about 5,000 rpm), the
two cylinders a little unequal (a lope at F0/2); the prop, geared down, passes a blade BLADE_HZ times a second: a soft
hum and the airflow's whoosh pulsing with it. A slow drift in the firing (a whole number of wobbles per loop) keeps it
from sounding like a buzzer. Levelled by RMS (`--rms`, dBFS); the preset's engine_gain_db is -9.7 minus that.
"""
import sys
import wave

import numpy as np

RATE = 44100
LOOP = 2.0
F0 = 83.0
BLADE_HZ = 100.0
LP_HZ = 1300.0
CUT_HZ = 4000.0


def lowpass(x, fc, order=4, cut=None):
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / RATE)
    resp = 1.0 / np.sqrt(1.0 + (f / fc) ** (2 * order))
    if cut:
        resp *= np.clip((cut * 1.15 - f) / (cut * 0.15), 0.0, 1.0)
    return np.fft.irfft(spec * resp, len(x))


def band_noise(n, lo, hi, rng):
    f = np.fft.rfftfreq(n, 1.0 / RATE)
    mag = ((f > lo) & (f < hi)).astype(float)
    mag *= 1.0 / np.maximum(f, 1.0) ** 0.5
    phase = rng.uniform(0, 2 * np.pi, len(f))
    spec = mag * np.exp(1j * phase)
    x = np.fft.irfft(spec, n)
    return x / (np.abs(x).max() + 1e-9)


def main():
    out = "sounds/enginesounds/engine_typhoon_loop.wav"
    rms_db = -18.0
    for a in sys.argv[1:]:
        if a.startswith("--rms="):
            rms_db = float(a[6:])
        else:
            out = a
    n = int(RATE * LOOP)
    t = np.arange(n) / RATE
    rng = np.random.default_rng(7)

    # Firing: soft pulses (a damped low tone) at F0, the times drifting a little (periodic in LOOP).
    drift = 0.0018 * np.sin(2 * np.pi * 0.5 * t) + 0.0009 * np.sin(2 * np.pi * 1.5 * t + 1.0)
    phase = (t + drift) * F0
    k_of = np.floor(phase)
    tau = (phase - k_of) / F0
    cyl = (k_of.astype(int) % 2)
    amp = np.where(cyl == 0, 1.0, 0.82)
    pulse = amp * np.exp(-tau / 0.0045) * np.sin(2 * np.pi * 165.0 * tau) \
        + 0.55 * amp * np.exp(-tau / 0.0022) * np.sin(2 * np.pi * 420.0 * tau)
    # The block's ring under it: low harmonics of the firing, the lope at F0/2.
    body = np.zeros(n)
    for h, a in [(0.5, 0.18), (1, 0.55), (2, 0.38), (3, 0.22), (4, 0.12), (6, 0.05)]:
        body += a * np.sin(2 * np.pi * F0 * h * t + h * 0.7)
    engine = lowpass(pulse * 0.9 + body * 0.6, LP_HZ, 4, CUT_HZ)

    # The prop: a hum at the blade rate and its next two harmonics, and the air through the duct pulsing with it.
    hum = 0.5 * np.sin(2 * np.pi * BLADE_HZ * t) + 0.18 * np.sin(2 * np.pi * 2 * BLADE_HZ * t + 0.4) \
        + 0.06 * np.sin(2 * np.pi * 3 * BLADE_HZ * t + 1.1)
    air = band_noise(n, 90.0, 900.0, rng) * (0.75 + 0.25 * np.sin(2 * np.pi * BLADE_HZ * t))
    prop = lowpass(hum * 0.5 + air * 0.55, 900.0, 4, CUT_HZ)

    mix = engine * 1.0 + prop * 0.7
    mix -= mix.mean()
    rms = np.sqrt(np.mean(mix ** 2))
    mix *= 10 ** (rms_db / 20.0) / rms
    peak = np.abs(mix).max()
    if peak > 0.89:
        mix *= 0.89 / peak
    data = (np.clip(mix, -1, 1) * 32767).astype(np.int16)
    with wave.open(out, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    rms_out = 20 * np.log10(np.sqrt(np.mean((data / 32767.0) ** 2)))
    peak_out = 20 * np.log10(np.abs(data).max() / 32767.0)
    seam = abs(int(data[0]) - int(data[-1])) / 32767.0
    spec = np.abs(np.fft.rfft(data / 32767.0))
    f = np.fft.rfftfreq(n, 1.0 / RATE)
    hi_share = 10 * np.log10(np.sum(spec[f > 3000] ** 2) / np.sum(spec ** 2) + 1e-12)
    print(f"{out}: {LOOP}s, RMS {rms_out:.1f} dBFS, peak {peak_out:.1f} dBFS, seam step {seam:.4f}, "
          f"energy over 3 kHz {hi_share:.1f} dB; engine_gain_db {-9.7 - rms_out:.1f}")


if __name__ == "__main__":
    main()
